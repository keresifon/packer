variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "packer-vpc-ssm"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (NAT Gateway)"
  type        = string
  default     = "10.0.0.0/24"
}

variable "cis_tools_bucket" {
  description = "S3 bucket name for CIS tools (read) and reports (write)"
  type        = string
  default     = "cis-tools-kere"
}


