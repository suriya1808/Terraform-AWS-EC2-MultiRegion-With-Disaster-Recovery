# Input variables. Change the defaults here, or override them on the command
# line, e.g. terraform apply -var="instance_type=t3.small"
#
# A variable block can only contain: type, description, default, sensitive,
# nullable, ephemeral and validation. Anything else is a syntax error.

variable "instance_type" {
  type        = string
  description = "EC2 instance type for every server (dev, qa, prod and DR)"
  default     = "t3.micro"
}

# One EC2 server (and one subnet) is created per environment.
# "prod" goes to the prod region; every other name goes to the nonprod region.
variable "environment" {
  type        = set(string)
  description = "Deployment environment names"
  default     = ["dev", "qa", "prod"]
}

#-------------------------------------------------------------------
# Networking
#-------------------------------------------------------------------

# One VPC per region: nonprod (eu-west-1), prod (ap-south-1), dr (ap-southeast-1)
variable "vpc_cidrs" {
  type        = map(string)
  description = "CIDR block for each VPC"
  default = {
    nonprod = "10.0.0.0/16"
    prod    = "10.1.0.0/16"
    dr      = "10.2.0.0/16"
  }
}

# One subnet per environment, plus one for DR.
# Each subnet must fall inside its VPC's CIDR, and every name in
# var.environment needs an entry here or terraform plan fails.
variable "subnet_cidrs" {
  type        = map(string)
  description = "CIDR block for each environment's subnet"
  default = {
    dev  = "10.0.1.0/24"
    qa   = "10.0.2.0/24"
    prod = "10.1.1.0/24"
    dr   = "10.2.1.0/24"
  }
}

#-------------------------------------------------------------------
# Disaster Recovery
#-------------------------------------------------------------------

variable "backup_retention_days" {
  type        = number
  description = "Days to keep prod backups in both regions"
  default     = 7
}

# Empty = normal operation (no DR server).
# Set to a backed-up AMI ID in the DR region to fail over, e.g.
#   terraform apply -var="dr_ami_id=ami-0abc123def456"
variable "dr_ami_id" {
  type        = string
  description = "AMI ID in the DR region to launch the recovery server from"
  default     = ""
}
