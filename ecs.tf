resource "aws_ecs_cluster" "cuple-ae-wordpress-cluster" {
  name = "cuple-ae-wordpress-cluster" # Naming the cluster
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  depends_on = [
    aws_vpc.wordpress_vpc
  ]
}

resource "aws_ecs_cluster_capacity_providers" "cluster-cp" {

  cluster_name       = aws_ecs_cluster.cuple-ae-wordpress-cluster.name
  capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
  }
  depends_on = [
    aws_ecs_cluster.cuple-ae-wordpress-cluster
  ]
}



# [Data] IAM policy to define S3 permissions

# data "aws_iam_policy_document" "s3_data_bucket_policy" {
#   statement {
#     sid = ""
#     effect = "Allow"
#     actions = [
#       "s3:GetBucketLocation"
#     ]
#     resources = [
#       "arn:aws:s3:::${var.env-s3-bucket}"
#     ]
#   }
#   statement {
#     sid = ""
#     effect = "Allow"
#     actions = [
#       "s3:GetObject"
#     ]
#     resources = [
#       "arn:aws:s3:::${var.env-s3-bucket}/*",
#       "arn:aws:s3:::landsale-service-staging-acc/serviceAccountKey.json"
#     ]
#   }
# }

# # AWS IAM policy

# resource "aws_iam_policy" "s3_policy" {
#   name_prefix  = "ecs-s3-policy"
#   policy = "${data.aws_iam_policy_document.s3_data_bucket_policy.json}"
# }

# # Attaches a managed IAM policy to an IAM role

# resource "aws_iam_role_policy_attachment" "ecs_role_s3_data_bucket_policy_attach" {
#   role       = "${aws_iam_role.ecsTaskExecutionRole.name}"
#   policy_arn = "${aws_iam_policy.s3_policy.arn}"
# }