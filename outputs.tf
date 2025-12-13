output "VPC_ID" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "SUBNET_ID" {
  description = "Private Subnet ID"
  value       = aws_subnet.private.id
}

output "SECURITY_GROUP_IDS" {
  description = "Security Group ID for Private Instances"
  value       = aws_security_group.private_instances.id
}

output "IAM_INSTANCE_PROFILE" {
  description = "IAM Instance Profile name for SSM"
  value       = aws_iam_instance_profile.packer_ssm.name
}

# Additional outputs for reference
output "vpc_endpoints_security_group_id" {
  description = "Security Group ID for VPC Endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "ssm_endpoint_id" {
  description = "SSM VPC Endpoint ID"
  value       = aws_vpc_endpoint.ssm.id
}

output "ssm_messages_endpoint_id" {
  description = "SSM Messages VPC Endpoint ID"
  value       = aws_vpc_endpoint.ssm_messages.id
}

output "ec2_messages_endpoint_id" {
  description = "EC2 Messages VPC Endpoint ID"
  value       = aws_vpc_endpoint.ec2_messages.id
}

output "s3_endpoint_id" {
  description = "S3 VPC Gateway Endpoint ID"
  value       = aws_vpc_endpoint.s3.id
}
