terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform Cloud / HCP Terraform - configured via -backend-config in workflow
  backend "remote" {}
}

provider "aws" {
  region = var.aws_region
}

