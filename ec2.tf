data "aws_ami" "amzn_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  credentials = {
    db_name        = aws_ssm_parameter.db_name.value
    db_username    = aws_ssm_parameter.db_username.value
    db_password    = aws_ssm_parameter.db_password.value
    db_host        = aws_rds_cluster.wordpress_db_cluster.endpoint
    wp_title       = aws_ssm_parameter.wp_title.value
    wp_username    = aws_ssm_parameter.wp_username.value
    wp_password    = aws_ssm_parameter.wp_password.value
    wp_email       = aws_ssm_parameter.wp_email.value
    site_url       = aws_ssm_parameter.site_url.value
    region         = var.region
    file_system_id = aws_efs_file_system.wordpress_fs.id
    wordpres_dir   = "/usr/share/nginx/wordpress"
  }
}

resource "aws_key_pair" "public_key" {
  key_name   = var.ec2_public_key_name
  public_key = file(var.ec2_public_key_path)
}

resource "aws_launch_template" "bastion_lt" {
  name          = "bastion_lt"
  description   = "Launch Template for the Bastion instances"
  image_id      = data.aws_ami.amzn_linux_2.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_public_key_name

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.bastion-sg.id]
  }
}

resource "aws_autoscaling_group" "bastion_asg" {
  name                = "bastion-asg"
  desired_capacity    = var.ec2_bastion_asg_desired_capacity
  min_size            = var.ec2_bastion_asg_min_capacity
  max_size            = var.ec2_bastion_asg_max_capacity
  vpc_zone_identifier = aws_subnet.public_subnets[*].id

  launch_template {
    id      = aws_launch_template.bastion_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "bastion-asg"
    propagate_at_launch = true
  }
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }
}

resource "aws_launch_template" "wordpress_lt" {
  name          = "wordpress_lt"
  description   = "Launch Template for the WordPress instances"
  image_id      = data.aws_ami.amzn_linux_2.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_public_key_name
  user_data     = base64encode(templatefile("${path.module}/scripts/bootstrap.sh", local.credentials))

  iam_instance_profile {
    name = aws_iam_instance_profile.parameter_store_profile.name
  }

  network_interfaces {
    security_groups = [aws_security_group.wordpress_sg.id]
  }

}

resource "aws_autoscaling_group" "wordpress_asg" {
  name             = "wordpress-asg"
  desired_capacity = var.ec2_bastion_asg_desired_capacity
  min_size         = var.ec2_wordpress_asg_min_capacity
  max_size         = var.ec2_wordpress_asg_max_capacity

  vpc_zone_identifier = aws_subnet.private_subnets[*].id
  target_group_arns   = [aws_lb_target_group.wordpress_tg.arn]
  health_check_type   = "ELB"

  mixed_instances_policy {
      instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 25
      spot_allocation_strategy                 = "capacity-optimized"
    }
  launch_template {
    id      = aws_launch_template.wordpress_lt.id
    # version = "$Latest"
  }
}

  tag {
    key                 = "Name"
    value               = "wordpress-asg"
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }

  depends_on = [
    aws_rds_cluster_instance.wordpress_cluster_instances,
    aws_elasticache_cluster.memcached_cluster
  ]
}
