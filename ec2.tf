# EC2 = Elastic Compute Cloud: the virtual servers.
# A "resource" block tells Terraform to create, update and delete real
# infrastructure.
#
# The provider argument must be a fixed name (aws.prod), not an expression,
# so prod and nonprod servers are split into two resource blocks.
# Both use the same for_each filters as subnet.tf, so each server's
# each.key matches its subnet's key.

# dev and qa servers (eu-west-1)
resource "aws_instance" "nonprod" {
  provider = aws.nonprod

  for_each = toset([
    for env in var.environment : env
    if env != "prod"
  ])

  ami           = data.aws_ami.ubuntu_nonprod.id  # Ubuntu image from ami.tf
  instance_type = var.instance_type               # server size (t3.micro)
  subnet_id     = aws_subnet.nonprod[each.key].id # this environment's subnet

  tags = {
    Name        = "ec2-${each.key}" # e.g. ec2-dev
    Environment = "${each.key}-ec2-server"
  }
}

# prod server (ap-south-1). This is the server AWS Backup protects (backup.tf).
resource "aws_instance" "prod" {
  provider = aws.prod

  for_each = toset([
    for env in var.environment : env
    if env == "prod"
  ])

  ami           = data.aws_ami.ubuntu_prod.id
  instance_type = var.instance_type
  subnet_id     = aws_subnet.prod[each.key].id

  tags = {
    Name        = "ec2-${each.key}" # ec2-prod
    Environment = "${each.key}-ec2-server"
  }
}
