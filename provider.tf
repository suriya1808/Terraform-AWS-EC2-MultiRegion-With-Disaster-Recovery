# Terraform downloads the AWS provider (the plugin that talks to AWS) from
# the Terraform Registry. "~> 6.0" allows any 6.x version, but not 7.0.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# One provider block per AWS region. The alias is the name resources use to
# pick a region, e.g. provider = aws.prod
# Credentials are not stored here; they come from the AWS CLI login
# (aws login / aws configure) on the machine running Terraform.

# Non-production (dev, qa) - Ireland
provider "aws" {
  region = "eu-west-1"
  alias  = "nonprod"
}

# Production - Mumbai
provider "aws" {
  region = "ap-south-1"
  alias  = "prod"
}

# Disaster Recovery for prod - Singapore
provider "aws" {
  region = "ap-southeast-1"
  alias  = "dr"
}
