# Security Group Setup for VPC Endpoints (SSM Session Manager)

This guide explains how to create a security group for Packer builds when using VPC endpoints for SSM access in a private subnet.

## Prerequisites

- **VPC Endpoints** already created for:
  - `com.amazonaws.region.ssm` (SSM service)
  - `com.amazonaws.region.ssmmessages` (SSM messages)
  - `com.amazonaws.region.ec2` (EC2 API)
- **VPC ID**: `vpc-0c680556684d4feed`
- **Region**: `us-east-2`

## Step 1: Get VPC Endpoint Prefix List IDs

VPC endpoints use prefix lists for routing. Get the prefix list IDs:

```bash
REGION="us-east-2"

# Get SSM prefix list
SSM_PREFIX_LIST=$(aws ec2 describe-managed-prefix-lists \
  --filters "Name=prefix-list-name,Values=com.amazonaws.${REGION}.ssm" \
  --region $REGION \
  --query 'PrefixLists[0].PrefixListId' \
  --output text)

# Get SSM Messages prefix list
SSM_MSG_PREFIX_LIST=$(aws ec2 describe-managed-prefix-lists \
  --filters "Name=prefix-list-name,Values=com.amazonaws.${REGION}.ssmmessages" \
  --region $REGION \
  --query 'PrefixLists[0].PrefixListId' \
  --output text)

# Get EC2 prefix list
EC2_PREFIX_LIST=$(aws ec2 describe-managed-prefix-lists \
  --filters "Name=prefix-list-name,Values=com.amazonaws.${REGION}.ec2" \
  --region $REGION \
  --query 'PrefixLists[0].PrefixListId' \
  --output text)

echo "SSM Prefix List: $SSM_PREFIX_LIST"
echo "SSM Messages Prefix List: $SSM_MSG_PREFIX_LIST"
echo "EC2 Prefix List: $EC2_PREFIX_LIST"
```

**Alternative:** If prefix lists don't work, you can use the VPC endpoint network interface security groups or allow HTTPS to the VPC CIDR range.

## Step 2: Create Security Group

Create a security group for Packer builds:

```bash
VPC_ID="vpc-0c680556684d4feed"
REGION="us-east-2"

SG_ID=$(aws ec2 create-security-group \
  --group-name packer-ssm-vpc-endpoints-sg \
  --description "Security group for Packer SSM Session Manager with VPC endpoints" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)

echo "Security Group ID: $SG_ID"
```

## Step 3: Add Outbound HTTPS Rules to VPC Endpoints

### Option A: Using Prefix Lists (Recommended)

```bash
REGION="us-east-2"

# Get prefix list IDs
SSM_PREFIX_LIST=$(aws ec2 describe-managed-prefix-lists \
  --filters "Name=prefix-list-name,Values=com.amazonaws.${REGION}.ssm" \
  --region $REGION \
  --query 'PrefixLists[0].PrefixListId' \
  --output text)

SSM_MSG_PREFIX_LIST=$(aws ec2 describe-managed-prefix-lists \
  --filters "Name=prefix-list-name,Values=com.amazonaws.${REGION}.ssmmessages" \
  --region $REGION \
  --query 'PrefixLists[0].PrefixListId' \
  --output text)

EC2_PREFIX_LIST=$(aws ec2 describe-managed-prefix-lists \
  --filters "Name=prefix-list-name,Values=com.amazonaws.${REGION}.ec2" \
  --region $REGION \
  --query 'PrefixLists[0].PrefixListId' \
  --output text)

# Add outbound HTTPS rules to each prefix list
aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,PrefixListIds=[{PrefixListId=$SSM_PREFIX_LIST}] \
  --region $REGION

aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,PrefixListIds=[{PrefixListId=$SSM_MSG_PREFIX_LIST}] \
  --region $REGION

aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --ip-permissions IpProtocol=tcp,FromPort=443,ToPort=443,PrefixListIds=[{PrefixListId=$EC2_PREFIX_LIST}] \
  --region $REGION

echo "Outbound HTTPS rules added to VPC endpoint prefix lists"
```

### Option B: Using VPC CIDR Range (Simpler, Less Secure)

If prefix lists don't work, allow HTTPS to your VPC CIDR range:

```bash
# Get VPC CIDR block
VPC_CIDR=$(aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID \
  --region $REGION \
  --query 'Vpcs[0].CidrBlock' \
  --output text)

# Add outbound HTTPS rule to VPC CIDR
aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr $VPC_CIDR \
  --region $REGION

echo "Outbound HTTPS rule added to VPC CIDR: $VPC_CIDR"
```

### Option C: Using VPC Endpoint Network Interface IPs (Most Specific)

Get the VPC endpoint network interface IPs and allow HTTPS to them:

```bash
# Get VPC endpoint IDs
VPC_ENDPOINTS=$(aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'VpcEndpoints[*].VpcEndpointId' \
  --output text)

# For each endpoint, get network interface IPs
for ENDPOINT_ID in $VPC_ENDPOINTS; do
  echo "Processing endpoint: $ENDPOINT_ID"
  # Get network interface IDs
  NETWORK_INTERFACE_IDS=$(aws ec2 describe-vpc-endpoints \
    --vpc-endpoint-ids $ENDPOINT_ID \
    --region $REGION \
    --query 'VpcEndpoints[0].NetworkInterfaceIds[*]' \
    --output text)
  
  # Get private IPs from network interfaces
  for NETWORK_INTERFACE_ID in $NETWORK_INTERFACE_IDS; do
    PRIVATE_IP=$(aws ec2 describe-network-interfaces \
      --network-interface-ids $NETWORK_INTERFACE_ID \
      --region $REGION \
      --query 'NetworkInterfaces[0].PrivateIpAddress' \
      --output text)
    
    echo "  Network Interface: $NETWORK_INTERFACE_ID, IP: $PRIVATE_IP"
    # Add rule for this IP (use /32 for single IP)
    aws ec2 authorize-security-group-egress \
      --group-id $SG_ID \
      --protocol tcp \
      --port 443 \
      --cidr ${PRIVATE_IP}/32 \
      --region $REGION
  done
done
```

## Step 4: Verify Security Group Configuration

Verify the security group was created correctly:

```bash
# View security group details
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $REGION

# View outbound rules
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $REGION \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

## Step 5: Set GitHub Repository Variable

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions** → **Variables**
3. Click **New repository variable**
4. **Name**: `SECURITY_GROUP_IDS`
5. **Value**: `sg-xxxxxxxxx` (your security group ID from Step 2)
6. Click **Add variable**

## Complete Setup Script

Here's a complete script that does everything:

```bash
#!/bin/bash
set -e

VPC_ID="vpc-0c680556684d4feed"
REGION="us-east-2"

echo "=== Step 1: Create Security Group ==="
SG_ID=$(aws ec2 create-security-group \
  --group-name packer-ssm-vpc-endpoints-sg \
  --description "Security group for Packer SSM Session Manager with VPC endpoints" \
  --vpc-id $VPC_ID \
  --region $REGION \
  --query 'GroupId' \
  --output text)
echo "Security Group created: $SG_ID"

echo ""
echo "=== Step 2: Get VPC CIDR Block ==="
VPC_CIDR=$(aws ec2 describe-vpcs \
  --vpc-ids $VPC_ID \
  --region $REGION \
  --query 'Vpcs[0].CidrBlock' \
  --output text)
echo "VPC CIDR: $VPC_CIDR"

echo ""
echo "=== Step 3: Add Outbound HTTPS Rule to VPC CIDR ==="
aws ec2 authorize-security-group-egress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr $VPC_CIDR \
  --region $REGION
echo "Outbound HTTPS rule added"

echo ""
echo "=== Step 4: Verify Configuration ==="
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region $REGION \
  --query 'SecurityGroups[0].IpPermissionsEgress'

echo ""
echo "=== Setup Complete! ==="
echo "Security Group ID: $SG_ID"
echo ""
echo "Next steps:"
echo "1. Set GitHub repository variable: SECURITY_GROUP_IDS=$SG_ID"
echo "2. Verify VPC endpoints are in the same VPC and route table is configured"
echo "3. Run Packer build"
```

## Verify VPC Endpoints Configuration

Make sure your VPC endpoints are properly configured:

```bash
# List all VPC endpoints in your VPC
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' \
  --output table

# Verify route table has routes to VPC endpoints
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-0a21c4c91cd05109e" \
  --region $REGION \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

aws ec2 describe-route-tables \
  --route-table-ids $ROUTE_TABLE_ID \
  --region $REGION \
  --query 'RouteTables[0].Routes'
```

## Troubleshooting

**SSM still not working?**
1. Verify VPC endpoints are in "available" state
2. Check route table has routes to VPC endpoints (pl-xxxxx entries)
3. Verify security group allows outbound HTTPS (443) to VPC endpoints
4. Check VPC endpoint security groups allow inbound HTTPS from your security group
5. Verify IAM instance profile has `AmazonSSMManagedInstanceCore` policy

**Prefix lists not found?**
- Prefix lists are AWS-managed and may take a few minutes to appear after creating VPC endpoints
- Use Option B (VPC CIDR) or Option C (specific IPs) instead

**VPC endpoint security groups:**
- VPC endpoints have their own security groups
- Ensure those security groups allow inbound HTTPS (443) from your Packer security group

## Next Steps

After creating the security group:
1. Set `SECURITY_GROUP_IDS` GitHub repository variable
2. Verify VPC endpoints are properly configured
3. Run Packer build - SSM should work via VPC endpoints

