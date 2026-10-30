# VPC = Virtual Private Cloud: your own private network inside an AWS region.
# Every server and subnet lives inside a VPC.
#
# Note: these VPCs have no internet gateway, so servers in them are private
# (no internet access in or out).

# Network for dev and qa (eu-west-1)
resource "aws_vpc" "nonprod" {
  provider             = aws.nonprod
  cidr_block           = var.vpc_cidrs["nonprod"] # range of private IPs, 10.0.0.0/16
  enable_dns_support   = true                     # AWS DNS works inside the VPC
  enable_dns_hostnames = true                     # servers get DNS names

  tags = {
    Name = "vpc-nonprod"
  }
}

# Network for prod (ap-south-1)
resource "aws_vpc" "prod" {
  provider             = aws.prod
  cidr_block           = var.vpc_cidrs["prod"] # 10.1.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-prod"
  }
}

# The DR network (ap-southeast-1) is in dr.tf with the rest of disaster recovery.
