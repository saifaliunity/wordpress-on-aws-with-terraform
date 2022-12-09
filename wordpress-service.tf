variable "cuple_ae_wordpress_service_container_port" {
  default = 8080
}

variable "cuple_ae_wordpress_service_container_name" {
  default = "cuple-ae-wordpres-service"
}


resource "aws_ecs_task_definition" "cuple-ae-wordpres-service-task-defintion" {
  family                = "cuple-ae-wordpres-service" # Naming our first task
  container_definitions = <<DEFINITION
  [
    {
      "name": "${var.cuple_ae_wordpress_service_container_name}",
      "image": "${var.container_image}",
      "essential": true,
      "logConfiguration": {
        "logDriver": "awslogs",
        "secretOptions": null,
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.cuple-ae-wordpres-service_cw_log_group.name}",
          "awslogs-region": "${var.region}",
          "awslogs-stream-prefix": "ecs"
        }
      },
    "mountPoints": [{
        "containerPath": "${var.efs_mount_dir_in_container}",
        "sourceVolume": "wp-data"
    }],
      "healthCheck": {
          "retries": 3,
          "command": [
              "CMD-SHELL",
              "curl -f http://localhost:${var.cuple_ae_wordpress_service_container_port}/lb.html || exit 1"
          ],
          "timeout": 10,
          "interval": 30,
          "startPeriod": 30
      },
      "portMappings": [
        {
          "containerPort": ${var.cuple_ae_wordpress_service_container_port}
        }
      ],
      "memory": ${var.task_memory},
      "cpu": ${var.task_cpu}
    }
    
  ]
  DEFINITION

  volume {
    name = "wp-data"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.wordpress_fs.id
      root_directory = "wp-content"
    }
  }

  requires_compatibilities = ["FARGATE"]     # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"        # Using awsvpc as our network mode as this is required for Fargate
  memory                   = var.task_memory # Specifying the memory our container requires
  cpu                      = var.task_cpu    # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  depends_on = [
    aws_cloudwatch_log_group.cuple-ae-wordpres-service_cw_log_group,
    aws_efs_file_system.wordpress_fs,
    aws_efs_mount_target.wordpress_mount_targets
  ]
  # lifecycle {
  #   ignore_changes = [container_definitions]
  # }
}


resource "aws_cloudwatch_log_group" "cuple-ae-wordpres-service_cw_log_group" {
  name = "/ecs/cuple-ae-wordpress-cluster/cuple-ae-wordpres-service"
  tags = {
    Environment = var.env
    Application = var.application_tag
  }
}

# resource "aws_lb_target_group" "cuple-ae-wordpres-service_target_group" {
#   name                 = "cuple-ae-wordpress-tg"
#   port                 = 80
#   protocol             = "HTTP"
#   target_type          = "ip"
#   vpc_id               = aws_vpc.wordpress_vpc.id # Referencing the VPC
#   deregistration_delay = 10
#   health_check {
#     path     = var.healthcheck_path
#     port     = var.port
#     protocol = "HTTP"
#     timeout  = 20
#   }
# }

resource "aws_lb_listener_rule" "cuple-ae-wordpress-rule" {
  listener_arn = aws_lb_listener.http_listner.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }

  condition {
    path_pattern {
      values = ["${var.domain_name}/*"]
    }
  }
}

resource "aws_security_group" "cuple-ae-wordpres-service_security_group" {
  vpc_id = aws_vpc.wordpress_vpc.id
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.lb_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_ecs_service" "cuple-ae-wordpres-service" {
  name            = "cuple-ae-wordpres-service"                                          # Naming our first service
  cluster         = aws_ecs_cluster.cuple-ae-wordpress-cluster.id                        # Referencing our created Cluster
  task_definition = aws_ecs_task_definition.cuple-ae-wordpres-service-task-defintion.arn # Referencing the task our service will spin up
  #Place atleast 1 task as OD and for each 1:4 place rest autoscaling for each 1 OD to 4 SPOT
  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 4
  }

  # Break the deployment if new tasks are not able to run and revert back to previous state

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  desired_count                     = 1 # Setting the number of containers to 1
  health_check_grace_period_seconds = 60

  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress_tg.arn # Referencing our target group
    container_name   = aws_ecs_task_definition.cuple-ae-wordpres-service-task-defintion.family
    container_port   = var.cuple_ae_wordpress_service_container_port # Specifying the container port
  }

  network_configuration {
    subnets          = aws_subnet.private_subnets.*.id
    assign_public_ip = false                                                                 # Providing our containers with private IPs
    security_groups  = ["${aws_security_group.cuple-ae-wordpres-service_security_group.id}"] # Setting the security group
  }

  depends_on = [
    aws_ecs_cluster.cuple-ae-wordpress-cluster,
    aws_lb.wordpress_lb,
    aws_lb_listener_rule.cuple-ae-wordpress-rule,
    aws_ecs_cluster_capacity_providers.cluster-cp
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "cuple-ae-wordpres-service_ecs_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cuple-ae-wordpress-cluster.name}/${aws_ecs_service.cuple-ae-wordpres-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = aws_iam_role.ecs-autoscale-role.arn
}


resource "aws_appautoscaling_policy" "ecs_target_cpu-cuple-ae-wordpress" {
  name               = "application-scaling-policy-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 80
  }
  depends_on = [aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target]
}
resource "aws_appautoscaling_policy" "ecs_target_memory-cuple-ae-wordpress" {
  name               = "application-scaling-policy-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80
  }
  depends_on = [aws_appautoscaling_target.cuple-ae-wordpres-service_ecs_target]
}
