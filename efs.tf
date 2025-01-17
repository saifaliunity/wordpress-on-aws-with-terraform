resource "aws_efs_file_system" "wordpress_fs" {
  creation_token   = "wordpress-file-system"
  performance_mode = "maxIO"
  encrypted        = true
  lifecycle_policy {
    transition_to_ia = "AFTER_60_DAYS"
  }

  lifecycle {
    prevent_destroy = true
  }
  tags = {
    Name = "Wordpress-EFS-DATA"
  }
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 27
}

resource "aws_efs_backup_policy" "policy" {
  file_system_id = aws_efs_file_system.wordpress_fs.id

  backup_policy {
    status = "ENABLED"
  }
  depends_on = [
    aws_efs_file_system.wordpress_fs
  ]
}

resource "aws_efs_mount_target" "wordpress_mount_targets" {
  count           = length(aws_subnet.private_subnets)
  file_system_id  = aws_efs_file_system.wordpress_fs.id
  subnet_id       = aws_subnet.private_subnets[count.index].id
  security_groups = [aws_security_group.efs_sg.id]
}
