# Disaster Recovery, part 2: the standby site in Singapore (ap-southeast-1).
#
# The network is always there (VPCs and subnets are free), but the server
# is only created during a failover, when you pass a backed-up AMI ID:
#   terraform apply -var="dr_ami_id=ami-0abc123def456"
# Failover is manual: nothing here notices that Mumbai is down.
# See README.md for the full steps.

resource "aws_vpc" "dr" {
  provider             = aws.dr
  cidr_block           = var.vpc_cidrs["dr"] # 10.2.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-dr"
  }
}

resource "aws_subnet" "dr" {
  provider   = aws.dr
  vpc_id     = aws_vpc.dr.id
  cidr_block = var.subnet_cidrs["dr"] # 10.2.1.0/24

  tags = {
    Name        = "subnet-dr"
    Environment = "dr"
  }
}

# The recovery server, built from the prod backup copied to Singapore.
# count = how many to create: 0 when dr_ami_id is empty (normal days),
# 1 when an AMI ID is given (failover). Setting it back to "" deletes it.
resource "aws_instance" "dr" {
  provider = aws.dr
  count    = var.dr_ami_id == "" ? 0 : 1

  ami           = var.dr_ami_id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.dr.id

  tags = {
    Name        = "ec2-prod-dr"
    Environment = "prod-dr-ec2-server"
  }
}
