terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Backend configuration is provided via:
    # - terraform init -backend-config="bucket=..." -backend-config="key=..." etc.
    # - Or via backend.hcl file
    # - Or via environment variables: TF_BACKEND_BUCKET, TF_BACKEND_KEY, etc.
    # This allows flexibility without hardcoding values
  }
}

provider "aws" {
  region = var.aws_region
}

