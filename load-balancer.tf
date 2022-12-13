resource "aws_lb" "wordpress_lb" {
  name                       = "wordpress-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.lb_sg.id]
  subnets                    = aws_subnet.public_subnets.*.id
  enable_deletion_protection = false

  tags = {
    Environment = var.env
  }
}

output "lb_dns_name" {
  value = aws_lb.wordpress_lb.dns_name
}

resource "aws_lb_target_group" "wordpress_tg" {
  name_prefix          = "wptg"
  port                 = var.cuple_ae_wordpress_service_container_port
  target_type          = "ip"
  protocol             = "HTTP"
  vpc_id               = aws_vpc.wordpress_vpc.id
  deregistration_delay = 10
  health_check {
    interval            = 30
    port                = var.cuple_ae_wordpress_service_container_port
    path                = var.healthcheck_path
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 3
    matcher             = "200"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http_listner" {
  load_balancer_arn = aws_lb.wordpress_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

