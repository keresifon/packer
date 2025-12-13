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

variable "terraform_state_bucket" {
  description = "S3 bucket name for Terraform state (optional - can be set via backend config)"
  type        = string
  default     = ""
}

variable "terraform_state_key" {
  description = "S3 key/path for Terraform state file (optional - can be set via backend config)"
  type        = string
  default     = "terraform.tfstate"
}

variable "terraform_state_region" {
  description = "AWS region for Terraform state bucket (optional - can be set via backend config)"
  type        = string
  default     = ""
}

variable "terraform_state_dynamodb_table" {
  description = "DynamoDB table name for Terraform state locking (optional - can be set via backend config)"
  type        = string
  default     = ""
}

