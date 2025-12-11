# NAT Gateway Setup for Private Subnet SSM Access

This guide explains how to set up a NAT Gateway to enable SSM Session Manager access for instances in private subnets.

## Prerequisites

Before creating a NAT Gateway, you need:

1. **VPC** - Your VPC ID: `vpc-0c680556684d4feed`
2. **Public Subnet** - A public subnet in the same VPC (for the NAT Gateway)
3. **Private Subnet** - Your private subnet: `subnet-0a21c4c91cd05109e`
4. **Elastic IP** - An Elastic IP address (allocated automatically or manually)
5. **Internet Gateway** - Attached to your VPC (usually already exists)

## Step-by-Step Instructions

### Step 1: Verify Internet Gateway

Check if your VPC has an Internet Gateway attached:

```bash
aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=vpc-0c680556684d4feed" \
  --region us-east-2
```

If no Internet Gateway exists, create one:

```bash
# Create Internet Gateway
IGW_ID=$(aws ec2 create-internet-gateway \
  --region us-east-2 \
  --query 'InternetGateway.InternetGatewayId' \
  --output text)

# Attach to VPC
aws ec2 attach-internet-gateway \
  --internet-gateway-id $IGW_ID \
  --vpc-id vpc-0c680556684d4feed \
  --region us-east-2
```

### Step 2: Identify or Create a Public Subnet

You need a public subnet for the NAT Gateway. Check existing subnets:

```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=vpc-0c680556684d4feed" \
  --region us-east-2 \
  --query 'Subnets[*].[SubnetId,AvailabilityZone,MapPublicIpOnLaunch]' \
  --output table
```

**If you need to create a public subnet:**

```bash
# Get an availability zone (use a different AZ than your private subnet)
AZ=$(aws ec2 describe-availability-zones --region us-east-2 --query 'AvailabilityZones[0].ZoneName' --output text)

# Create public subnet
PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id vpc-0c680556684d4feed \
  --availability-zone $AZ \
  --cidr-block 10.0.1.0/24 \
  --region us-east-2 \
  --query 'Subnet.SubnetId' \
  --output text)

# Enable auto-assign public IP
aws ec2 modify-subnet-attribute \
  --subnet-id $PUBLIC_SUBNET_ID \
  --map-public-ip-on-launch \
  --region us-east-2

# Add route to Internet Gateway in public subnet's route table
ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$PUBLIC_SUBNET_ID" \
  --region us-east-2 \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

aws ec2 create-route \
  --route-table-id $ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id $IGW_ID \
  --region us-east-2
```

### Step 3: Allocate Elastic IP

Allocate an Elastic IP for the NAT Gateway:

```bash
ALLOCATION_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --region us-east-2 \
  --query 'AllocationId' \
  --output text)

echo "Elastic IP Allocation ID: $ALLOCATION_ID"
```

**Note:** Elastic IPs are free when attached to running NAT Gateways, but cost ~$0.005/hour when not in use.

### Step 4: Create NAT Gateway

Create the NAT Gateway in the public subnet:

```bash
# Replace PUBLIC_SUBNET_ID with your actual public subnet ID
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id PUBLIC_SUBNET_ID \
  --allocation-id $ALLOCATION_ID \
  --region us-east-2 \
  --query 'NatGateway.NatGatewayId' \
  --output text)

echo "NAT Gateway ID: $NAT_GW_ID"
echo "Waiting for NAT Gateway to become available (this takes 2-5 minutes)..."

# Wait for NAT Gateway to be available
aws ec2 wait nat-gateway-available \
  --nat-gateway-ids $NAT_GW_ID \
  --region us-east-2

echo "NAT Gateway is now available!"
```

### Step 5: Update Private Subnet Route Table

Add a route to the NAT Gateway in your private subnet's route table:

```bash
# Get the route table for your private subnet
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=subnet-0a21c4c91cd05109e" \
  --region us-east-2 \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

# Add route to NAT Gateway
aws ec2 create-route \
  --route-table-id $PRIVATE_ROUTE_TABLE_ID \
  --destination-cidr-block 0.0.0.0/0 \
  --nat-gateway-id $NAT_GW_ID \
  --region us-east-2

echo "Route added to private subnet route table"
```

### Step 6: Verify Configuration

Verify the setup:

```bash
# Check NAT Gateway status
aws ec2 describe-nat-gateways \
  --nat-gateway-ids $NAT_GW_ID \
  --region us-east-2

# Check route table
aws ec2 describe-route-tables \
  --route-table-ids $PRIVATE_ROUTE_TABLE_ID \
  --region us-east-2 \
  --query 'RouteTables[0].Routes'
```

## Complete Setup Script

Here's a complete script that does everything:

```bash
#!/bin/bash
set -e

VPC_ID="vpc-0c680556684d4feed"
PRIVATE_SUBNET_ID="subnet-0a21c4c91cd05109e"
REGION="us-east-2"

echo "=== Step 1: Check Internet Gateway ==="
IGW_ID=$(aws ec2 describe-internet-gateways \
  --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
  --region $REGION \
  --query 'InternetGateways[0].InternetGatewayId' \
  --output text)

if [ "$IGW_ID" == "None" ] || [ -z "$IGW_ID" ]; then
  echo "Creating Internet Gateway..."
  IGW_ID=$(aws ec2 create-internet-gateway \
    --region $REGION \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)
  aws ec2 attach-internet-gateway \
    --internet-gateway-id $IGW_ID \
    --vpc-id $VPC_ID \
    --region $REGION
  echo "Internet Gateway created: $IGW_ID"
else
  echo "Internet Gateway exists: $IGW_ID"
fi

echo ""
echo "=== Step 2: Get or Create Public Subnet ==="
# Find a public subnet or create one
PUBLIC_SUBNET_ID=$(aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=map-public-ip-on-launch,Values=true" \
  --region $REGION \
  --query 'Subnets[0].SubnetId' \
  --output text)

if [ "$PUBLIC_SUBNET_ID" == "None" ] || [ -z "$PUBLIC_SUBNET_ID" ]; then
  echo "No public subnet found. Creating one..."
  AZ=$(aws ec2 describe-availability-zones --region $REGION --query 'AvailabilityZones[0].ZoneName' --output text)
  PUBLIC_SUBNET_ID=$(aws ec2 create-subnet \
    --vpc-id $VPC_ID \
    --availability-zone $AZ \
    --cidr-block 10.0.1.0/24 \
    --region $REGION \
    --query 'Subnet.SubnetId' \
    --output text)
  aws ec2 modify-subnet-attribute \
    --subnet-id $PUBLIC_SUBNET_ID \
    --map-public-ip-on-launch \
    --region $REGION
  echo "Public subnet created: $PUBLIC_SUBNET_ID"
else
  echo "Using existing public subnet: $PUBLIC_SUBNET_ID"
fi

echo ""
echo "=== Step 3: Allocate Elastic IP ==="
ALLOCATION_ID=$(aws ec2 allocate-address \
  --domain vpc \
  --region $REGION \
  --query 'AllocationId' \
  --output text)
echo "Elastic IP allocated: $ALLOCATION_ID"

echo ""
echo "=== Step 4: Create NAT Gateway ==="
NAT_GW_ID=$(aws ec2 create-nat-gateway \
  --subnet-id $PUBLIC_SUBNET_ID \
  --allocation-id $ALLOCATION_ID \
  --region $REGION \
  --query 'NatGateway.NatGatewayId' \
  --output text)
echo "NAT Gateway created: $NAT_GW_ID"
echo "Waiting for NAT Gateway to become available (this takes 2-5 minutes)..."
aws ec2 wait nat-gateway-available \
  --nat-gateway-ids $NAT_GW_ID \
  --region $REGION
echo "NAT Gateway is available!"

echo ""
echo "=== Step 5: Update Private Subnet Route Table ==="
PRIVATE_ROUTE_TABLE_ID=$(aws ec2 describe-route-tables \
  --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_ID" \
  --region $REGION \
  --query 'RouteTables[0].RouteTableId' \
  --output text)

# Check if route already exists
EXISTING_ROUTE=$(aws ec2 describe-route-tables \
  --route-table-ids $PRIVATE_ROUTE_TABLE_ID \
  --region $REGION \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" \
  --output text)

if [ "$EXISTING_ROUTE" == "None" ] || [ -z "$EXISTING_ROUTE" ]; then
  aws ec2 create-route \
    --route-table-id $PRIVATE_ROUTE_TABLE_ID \
    --destination-cidr-block 0.0.0.0.0/0 \
    --nat-gateway-id $NAT_GW_ID \
    --region $REGION
  echo "Route added to NAT Gateway"
else
  echo "Route to NAT Gateway already exists"
fi

echo ""
echo "=== Setup Complete! ==="
echo "NAT Gateway ID: $NAT_GW_ID"
echo "Public Subnet: $PUBLIC_SUBNET_ID"
echo "Private Subnet: $PRIVATE_SUBNET_ID"
echo ""
echo "Your private subnet instances can now access the internet via NAT Gateway"
```

## Cost Considerations

**NAT Gateway Costs:**
- **NAT Gateway**: ~$0.045/hour (~$32/month)
- **Data Processing**: $0.045 per GB processed
- **Elastic IP**: Free when attached to NAT Gateway

**Cost Optimization Tips:**
1. Use VPC Endpoints for AWS services (SSM, S3, etc.) to reduce data transfer costs
2. Consider using NAT Instance for lower cost (but less reliable)
3. Delete NAT Gateway when not in use (if temporary)

## Verification

After setup, verify SSM connectivity:

```bash
# Launch a test instance in your private subnet
# Then try to connect via SSM Session Manager
aws ssm start-session --target i-xxxxxxxxx --region us-east-2
```

## Troubleshooting

**NAT Gateway not working?**
1. Verify NAT Gateway status is "available"
2. Check route table has route to NAT Gateway (0.0.0.0/0 → NAT Gateway)
3. Verify security group allows outbound HTTPS (443)
4. Check VPC flow logs for traffic

**High costs?**
- Consider VPC Endpoints for AWS services (SSM, S3)
- Monitor NAT Gateway data transfer in CloudWatch

## Next Steps

After NAT Gateway is set up:
1. Create security group with outbound HTTPS (443) rule
2. Set `SECURITY_GROUP_IDS` GitHub variable
3. Your Packer builds should now work with SSM Session Manager

