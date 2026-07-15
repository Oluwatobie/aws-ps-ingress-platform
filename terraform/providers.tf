terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote State Configuration using your pre-created bucket
  backend "s3" {
    bucket       = "tobi-ps-ingress-tfstate"
    key          = "platform/terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true # Uses native S3 locking instead of DynamoDB
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "Dev"
      Project     = "PublicSectorIngress"
      ManagedBy   = "Terraform"
    }
  }
}