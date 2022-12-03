data "aws_region" "current" {}
data "aws_caller_identity" "current" {}


data "aws_route_table" "private" {
  subnet_id = aws_subnet.private_subnets[0].id
  depends_on = [
    aws_vpc.wordpress_vpc,
    aws_route_table_association.private-rt-as
  ]
}

data "aws_region" "current" {}


resource "aws_security_group" "vpc_endpoint_security_group" {
  vpc_id = aws_vpc.wordpress_vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.wordpress_vpc.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [
    aws_vpc.wordpress_vpc
  ]
}

resource "aws_vpc_endpoint" "efs" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.elasticfilesystem"
  vpc_endpoint_type = "Interface"
  subnet_ids        = aws_subnet.private_subnets.*.id
  security_group_ids = [
    aws_security_group.vpc_endpoint_security_group.id
  ]

  private_dns_enabled = true
}


resource "aws_vpc_endpoint" "logs" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type = "Interface"
  auto_accept       = true
  subnet_ids        = aws_subnet.private_subnets.*.id
  security_group_ids = [
    aws_security_group.vpc_endpoint_security_group.id
  ]
  tags = {
    Name        = "logs-endpoint"
    Environment = "production"
  }
  private_dns_enabled = true
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  auto_accept       = true
  vpc_endpoint_type = "Gateway"
  route_table_ids   = ["${data.aws_route_table.private.id}"]

  tags = {
    Name        = "s3-endpoint"
    Environment = "production"
  }
  depends_on = [
    aws_vpc.wordpress_vpc
  ]
}

resource "aws_vpc_endpoint" "dkr" {
  vpc_id              = aws_vpc.wordpress_vpc.id
  private_dns_enabled = true
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  auto_accept         = true
  vpc_endpoint_type   = "Interface"
  security_group_ids = [
    aws_security_group.vpc_endpoint_security_group.id
  ]
  subnet_ids = aws_subnet.private_subnets.*.id


  tags = {
    Name        = "dkr-endpoint"
    Environment = "production"
  }
  depends_on = [
    aws_vpc.wordpress_vpc
  ]
}

resource "aws_vpc_endpoint" "ecr-api" {
  vpc_id              = aws_vpc.wordpress_vpc.id
  private_dns_enabled = true
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  auto_accept         = true
  vpc_endpoint_type   = "Interface"
  security_group_ids = [
    aws_security_group.vpc_endpoint_security_group.id
  ]
  subnet_ids = aws_subnet.private_subnets.*.id

  tags = {
    Name        = "ecr-api-endpoint"
    Environment = "production"
  }
  depends_on = [
    aws_vpc.wordpress_vpc
  ]
}

resource "aws_vpc_endpoint" "rds" {
  vpc_id              = aws_vpc.wordpress_vpc.id
  private_dns_enabled = true
  service_name        = "com.amazonaws.${data.aws_region.current.name}.rds"
  auto_accept         = true
  vpc_endpoint_type   = "Interface"
  security_group_ids = [
    aws_security_group.vpc_endpoint_security_group.id
  ]
  subnet_ids = aws_subnet.private_subnets.*.id

  tags = {
    Name        = "rds-endpoint"
    Environment = "production"
  }
  depends_on = [
    aws_vpc.wordpress_vpc
  ]
}
