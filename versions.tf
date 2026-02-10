terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud { 
    
    organization = "kere-terra" 

    workspaces { 
      name = "packer" 
    } 
  } 
}

provider "aws" {
  region = var.aws_region
}

