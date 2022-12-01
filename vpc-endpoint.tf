data "aws_region" "current" { }

resource "aws_vpc_endpoint" "efs" {
  vpc_id            = aws_vpc.wordpress_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.elasticfilesystem"
  vpc_endpoint_type = "Interface"
  subnet_ids = aws_subnet.private_subnets.*.id
  security_group_ids = [
    aws_security_group.cuple-ae-wordpres-service_security_group.id
  ]

  private_dns_enabled = true
}