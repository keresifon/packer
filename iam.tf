# IAM Role for SSM
resource "aws_iam_role" "ssm_instance_role" {
  name = "${var.project_name}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-ssm-role"
  }
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  role       = aws_iam_role.ssm_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Inline IAM Policy for CIS Tools S3 Access
resource "aws_iam_role_policy" "cis_tools_s3" {
  name = "${var.project_name}-cis-tools-s3-policy"
  role = aws_iam_role.ssm_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CISToolsS3Access"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::${var.cis_tools_bucket}"
      },
      {
        Sid    = "CISToolsObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::${var.cis_tools_bucket}/*"
      },
      {
        Sid    = "CISReportsUpload"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.cis_tools_bucket}/reports/*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "packer_ssm" {
  name = "${var.project_name}-ssm-instance-profile"
  role = aws_iam_role.ssm_instance_role.name

  tags = {
    Name = "${var.project_name}-ssm-instance-profile"
  }
}
