#!/bin/bash

wordpress_dir=/var/www/html

function installPackages {
    sudo yum remove -y php php-* 
    sudo amazon-linux-extras disable php7.2
    sudo amazon-linux-extras disable lamp-mariadb10.2-php7.2
    sudo amazon-linux-extras enable php7.4
    sudo amazon-linux-extras install php7.4 -y
    sudo yum update -y
    sudo yum install httpd mariadb-server mysql -y
    sudo yum install amazon-efs-utils git gcc-c++ zlib-devel libssl-dev openssl-devel gcc g++ make pkg-config libsasl2-dev php-devel -y
    sudo yum remove openssl-devel.x86_64 -y
    sudo yum autoremove -y
    sudo yum install openssl11-devel php-xml -y
    sudo yum clean all
    sudo rm -rf /var/cache/yum
}

function installMemcachedClient {
    # Install
    curl https://elasticache-downloads.s3.amazonaws.com/ClusterClient/PHP-7.4/latest-64bit-X86 -o latest-64bit-X86
    tar -zxvf latest-64bit-X86
    mv amazon-elasticache-cluster-client.so /usr/local/lib/php/
    echo "extension=amazon-elasticache-cluster-client.so" | tee --append /usr/local/etc/php/conf.d/50-memcached.ini
    rm -rfv latest-64bit-X86 artifact
    # Verify
    php -r "echo((extension_loaded('memcached') ? \"Yes\n\" : \"No\n\"));"
}


#Mount the EFS file system to the wordpress dir
function mountEFS {
    sudo pip3 install botocore
    sudo mkdir -p $wordpress_dir
    sudo mount -t efs ${file_system_id}:/ $wordpress_dir
    sudo echo >> ${file_system_id}:/ $wordpress_dir efs _netdev,noresvport,tls,iam 0 0 /etc/fstab
    # Download the htacess and php.ini directives
    github_raw_url='https://raw.githubusercontent.com/saifaliunity/wordpress-on-aws-with-terraform/master/configurations'
    curl "$github_raw_url/.htaccess" -o $wordpress_dir/.htaccess
    curl "$github_raw_url/.user.ini" -o $wordpress_dir/wp-admin/.user.ini
}


#downloanding and overwriting the  Nginx configuration files 
function configuringNginx {
    echo "Configuring Nginx ........"

    github_raw_url='https://raw.githubusercontent.com/saifaliunity/wordpress-on-aws-with-terraform/master/configurations'
    curl "$github_raw_url/wordpress.conf" -o /etc/nginx/conf.d/wordpress.conf
    curl "$github_raw_url/nginx.conf" > /etc/nginx/nginx.conf
    sed -i '/;cgi.fix_pathinfo=1/c\cgi.fix_pathinfo=0' /etc/php.ini
    systemctl restart nginx
}

function configuringApache {
    sudo systemctl start httpd
    sudo systemctl enable httpd
}

function installWpcli {
    cd $wordpress_dir
    echo "Downloading WP-CLI...."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp 
    github_raw_url='https://raw.githubusercontent.com/saifaliunity/wordpress-on-aws-with-terraform/master/configurations'
    curl "$github_raw_url/.htaccess" -o $wordpress_dir/.htaccess
    curl "$github_raw_url/.user.ini" -o $wordpress_dir/wp-admin/.user.ini
}

function installWordpress {
    cd $wordpress_dir
    echo "Downloading WP-CLI...."
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    mv wp-cli.phar /usr/local/bin/wp

    echo "Downloading Wordpress...."
    wp core download 

    #create wp-config.php
    echo "Generating wp-config.php...."
    wp config create --dbname=${db_name} --dbuser=${db_username} --dbpass=${db_password} --dbhost=${db_host}

    echo "Installing Wordpress...."
    #wp core install --url=${site_url} --title="${wp_title}" --admin_user=${wp_username} --admin_password=${wp_password} --admin_email=${wp_email}
    wp config set --add FS_METHOD direct
    #Install w3-total cache plugin 
    # wp plugin install w3-total-cache --activate
    # Download the htacess and php.ini directives
    github_raw_url='https://raw.githubusercontent.com/saifaliunity/wordpress-on-aws-with-terraform/master/configurations'
    curl "$github_raw_url/.htaccess" -o $wordpress_dir/.htaccess
    curl "$github_raw_url/.user.ini" -o $wordpress_dir/wp-admin/.user.ini

}

function genWpConfig {
    cd $wordpress_dir
    rm -rf wp-config-sample.php
    wp config create --dbname=${db_name} --dbuser=${db_username} --dbpass=${db_password} --dbhost=${db_host}
}

function fixApachePermissionsOnWp {
    sudo chown -R apache:apache $wordpress_dir
    sudo systemctl restart httpd
}


echo "Installing Everything"
installPackages
echo "Mounting EFS"
mountEFS
echo "Installing Memcached"
installMemcachedClient
echo "Configuring Apache"
configuringApache
installWpcli
#Spining everything
systemctl enable --now php-fpm 
# if  mountpoint -q $wordpress_dir; then
#     if [ -d "$wordpress_dir/wp-admin" -a "$wordpress_dir/wp-content" -a "$wordpress_dir/wp-includes" ]; then
#         echo "installing wp cli"
#         installWpcli
#         echo "Fixing apache permissions..."
#         fixApachePermissionsOnWp
#     else
#         echo "Unable to Install WpCli and fix permissions!"
#         exit 1
#     fi
# else
# echo "EFS Was not attached! Please check logs!"
# systemctl restart nginx
# fi