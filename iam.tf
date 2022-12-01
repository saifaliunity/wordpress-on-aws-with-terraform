# data "aws_iam_policy_document" "instance-assume-role-policy" {
#   statement {
#     actions = ["sts:AssumeRole"]

#     principals {
#       type        = "Service"
#       identifiers = ["ec2.amazonaws.com"]
#     }
#   }
# }

# data "aws_iam_policy_document" "parameter-store-document" {
#   statement {
#     effect    = "Allow"
#     actions   = ["ec2:DescribeAvailabilityZones", "ssm:GetParameters", "ssm:GetParameter", "ssm:GetParametersByPath", "elasticfilesystem:*"]
#     resources = ["*"]
#   }
# }

# resource "aws_iam_policy" "parameter_store_policy" {
#   policy = data.aws_iam_policy_document.parameter-store-document.json
# }

# resource "aws_iam_role" "parameter_store_role" {
#   name               = "parameter_store_role"
#   assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json
# }

# resource "aws_iam_policy_attachment" "parameter-store-attach" {
#   name       = "parameter-store-attach"
#   roles      = [aws_iam_role.parameter_store_role.name]
#   policy_arn = aws_iam_policy.parameter_store_policy.arn
# }

# resource "aws_iam_instance_profile" "parameter_store_profile" {
#   name = "parameter_sotre_profile"
#   role = aws_iam_role.parameter_store_role.name
# }


resource "aws_iam_role" "ecsTaskExecutionRole" {
  name_prefix        = "ecsTaskExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeAvailabilityZones", "ssm:GetParameters", "ssm:GetParameter", "ssm:GetParametersByPath", "elasticfilesystem:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs-autoscale-role" {
  name_prefix = "ecs-scale-application"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "application-autoscaling.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs-autoscale" {
  role       = aws_iam_role.ecs-autoscale-role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}