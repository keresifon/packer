output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Private Subnet ID"
  value       = aws_subnet.private.id
}

output "security_group_ids" {
  description = "Security Group ID for Private Instances"
  value       = aws_security_group.private_instances.id
}

output "iam_instance_profile" {
  description = "IAM Instance Profile name for SSM"
  value       = aws_iam_instance_profile.packer_ssm.name
}

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

output "nat_gateway_id" {
  description = "NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "public_subnet_id" {
  description = "Public Subnet ID (NAT Gateway)"
  value       = aws_subnet.public.id
}
