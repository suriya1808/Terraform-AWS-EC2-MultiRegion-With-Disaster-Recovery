# AMI = Amazon Machine Image: a prebuilt template of an operating system
# that an EC2 server boots from.
#
# A "data" block only looks something up in AWS; it never creates anything.
# AMI IDs are different in every region, so we look one up per region.

# Latest Ubuntu 22.04 image in the nonprod region (eu-west-1)
data "aws_ami" "ubuntu_nonprod" {
  provider    = aws.nonprod
  most_recent = true # if several images match, take the newest

  # "name" is a fixed AWS filter key: match on the image's name.
  # The * matches any build date at the end of the name.
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  # HVM = Hardware Virtual Machine, the virtualisation type modern EC2 uses
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  # Safety check: only trust images published by Canonical (the Ubuntu
  # company), so we never boot a look-alike image from someone else.
  # (309956199498 is Red Hat's ID, if you ever want RHEL instead.)
  owners = ["099720109477"]
}

# Same lookup in the prod region (ap-south-1)
data "aws_ami" "ubuntu_prod" {
  provider    = aws.prod
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}
