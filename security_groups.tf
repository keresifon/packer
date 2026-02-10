# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints (SSM, SSM Messages, EC2 Messages)"
  vpc_id      = aws_vpc.main.id

  # Allow inbound HTTPS from VPC CIDR
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-vpc-endpoints-sg"
  }
}

# Security Group for EC2 Instances in Private Subnets
resource "aws_security_group" "private_instances" {
  name        = "${var.project_name}-private-instances-sg"
  description = "Security group for EC2 instances in private subnets"
  vpc_id      = aws_vpc.main.id

  # Allow outbound HTTPS to VPC endpoints (SSM, SSM Messages, EC2 Messages)
  egress {
    description     = "HTTPS to VPC endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.vpc_endpoints.id]
  }

  # Allow all outbound (packages, downloads, etc. via NAT Gateway for image pipeline)
  egress {
    description = "All outbound via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-private-instances-sg"
  }
}
