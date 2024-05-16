terraform {
  required_version = ">= 1.2.0"

  backend "s3" {
    bucket         = "terraform-backend-tfstate-stage"
    key            = "ap-south-1/stage/eks/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-lock-stage"
    profile        = "personal-aws"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
  default_tags {
    tags = var.common_tags
  }
}
