# A subnet is a smaller slice of a VPC's IP range. Each EC2 server is
# placed in one subnet. We create one subnet per environment.
#
# for_each creates one copy of the resource per item in the set, and
# each.key is the current item ("dev", "qa" or "prod").

# Subnets for every environment except prod, in the nonprod VPC
resource "aws_subnet" "nonprod" {
  provider = aws.nonprod

  # Keep every environment name except "prod" -> {"dev", "qa"}
  for_each = toset([
    for env in var.environment : env
    if env != "prod"
  ])

  vpc_id     = aws_vpc.nonprod.id
  cidr_block = var.subnet_cidrs[each.key] # e.g. dev -> 10.0.1.0/24

  tags = {
    Name        = "subnet-${each.key}"
    Environment = each.key
  }
}

# Subnet for prod, in the prod VPC
resource "aws_subnet" "prod" {
  provider = aws.prod

  # Keep only "prod" -> {"prod"}
  for_each = toset([
    for env in var.environment : env
    if env == "prod"
  ])

  vpc_id     = aws_vpc.prod.id
  cidr_block = var.subnet_cidrs[each.key] # 10.1.1.0/24

  tags = {
    Name        = "subnet-${each.key}"
    Environment = each.key
  }
}
