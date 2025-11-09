#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║    E-Ren Terraform Bootstrap - One-Time Setup Script      ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

echo -e "${YELLOW}This script creates the terraform-provisioner IAM user.${NC}"
echo -e "${YELLOW}After this, all other IAM resources will be managed via Terraform!${NC}\n"

# Get AWS account ID
echo "Fetching AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Could not fetch AWS account ID.${NC}"
    echo -e "${RED}Make sure AWS CLI is configured with valid credentials.${NC}"
    echo -e "\nRun: ${YELLOW}aws configure${NC}"
    exit 1
fi

echo -e "AWS Account ID: ${GREEN}${AWS_ACCOUNT_ID}${NC}"

# Get current user
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)
echo -e "Current user:   ${GREEN}${CURRENT_USER}${NC}\n"

# Variables
IAM_USER="terraform-provisioner"
POLICY_NAME="TerraformProvisionerPolicy"
POLICY_FILE="$(dirname "$0")/policies/terraform-provisioner.json"

# Check if policy file exists
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}Error: Policy file not found at ${POLICY_FILE}${NC}"
    exit 1
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Step 1/4: Creating IAM Policy${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create IAM policy
echo "Creating policy: ${POLICY_NAME}..."
POLICY_ARN=$(aws iam create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document file://"$POLICY_FILE" \
    --description "Terraform provisioner policy for EKS, RDS, VPC, S3, and other infrastructure" \
    --query 'Policy.Arn' \
    --output text 2>/dev/null || echo "")

if [ -z "$POLICY_ARN" ]; then
    # Policy might already exist, try to get its ARN
    echo -e "${YELLOW}Policy already exists, fetching ARN...${NC}"
    POLICY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${POLICY_NAME}"
fi

echo -e "✓ Policy ARN: ${GREEN}${POLICY_ARN}${NC}\n"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Step 2/4: Creating IAM User${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Create IAM user
echo "Creating user: ${IAM_USER}..."
if aws iam create-user --user-name "$IAM_USER" 2>/dev/null; then
    echo -e "✓ User ${GREEN}${IAM_USER}${NC} created successfully\n"
else
    echo -e "${YELLOW}⚠ User ${IAM_USER} already exists${NC}\n"
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Step 3/4: Attaching Policy to User${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Attach policy to user
echo "Attaching policy to user..."
aws iam attach-user-policy \
    --user-name "$IAM_USER" \
    --policy-arn "$POLICY_ARN"

echo -e "✓ Policy attached to ${GREEN}${IAM_USER}${NC}\n"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Step 4/4: Creating Access Key${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check if user already has access keys
EXISTING_KEYS=$(aws iam list-access-keys --user-name "$IAM_USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text)

if [ -n "$EXISTING_KEYS" ]; then
    echo -e "${YELLOW}⚠ User already has access key(s): ${EXISTING_KEYS}${NC}"
    echo -e "${YELLOW}Skipping access key creation.${NC}"
    echo -e "${YELLOW}If you need new keys, delete the old ones first:${NC}"
    echo -e "  ${BLUE}aws iam delete-access-key --user-name ${IAM_USER} --access-key-id <KEY_ID>${NC}\n"

    echo -e "${GREEN}✓ Bootstrap complete!${NC}"
    echo -e "\n${YELLOW}Use existing access keys or create new ones manually.${NC}"
    exit 0
fi

# Create access key
echo "Creating access key..."
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$IAM_USER" --output json)

ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"AccessKeyId": "[^"]*' | cut -d'"' -f4)
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"SecretAccessKey": "[^"]*' | cut -d'"' -f4)

if [ -z "$ACCESS_KEY_ID" ] || [ -z "$SECRET_ACCESS_KEY" ]; then
    echo -e "${RED}Error: Failed to create access key${NC}"
    exit 1
fi

echo -e "✓ Access key created successfully\n"

# Save credentials to a file (for reference)
CREDENTIALS_FILE="$(dirname "$0")/terraform-credentials.txt"
cat > "$CREDENTIALS_FILE" <<EOF
# ═══════════════════════════════════════════════════════════
#   Terraform Provisioner AWS Credentials
# ═══════════════════════════════════════════════════════════
#
# Created: $(date)
# AWS Account: ${AWS_ACCOUNT_ID}
# IAM User: ${IAM_USER}
#
# IMPORTANT: After storing in Terraform Cloud, DELETE THIS FILE!
#
# ═══════════════════════════════════════════════════════════

AWS_ACCESS_KEY_ID=${ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=${SECRET_ACCESS_KEY}
AWS_REGION=us-east-1

# ═══════════════════════════════════════════════════════════
#   Terraform Cloud Setup Instructions
# ═══════════════════════════════════════════════════════════
#
# 1. Sign up: https://app.terraform.io/signup
# 2. Create organization: "eren-team"
# 3. Create workspace: "eren-prod"
# 4. Go to: Workspace Settings > Variables
# 5. Add these as ENVIRONMENT variables (mark as SENSITIVE):
#
#    Variable Name              Value
#    ─────────────────────────  ─────────────────────────────
#    AWS_ACCESS_KEY_ID          ${ACCESS_KEY_ID}
#    AWS_SECRET_ACCESS_KEY      (paste secret, mark sensitive)
#    AWS_REGION                 us-east-1
#
# 6. Run: terraform login
# 7. Run: terraform init
# 8. DELETE THIS FILE: rm ${CREDENTIALS_FILE}
#
# ═══════════════════════════════════════════════════════════
EOF

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║               ✓ Bootstrap Complete!                       ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

echo -e "${GREEN}AWS Credentials Created:${NC}"
echo -e "  IAM User:          ${YELLOW}${IAM_USER}${NC}"
echo -e "  Access Key ID:     ${YELLOW}${ACCESS_KEY_ID}${NC}"
echo -e "  Secret Access Key: ${YELLOW}${SECRET_ACCESS_KEY:0:10}...${SECRET_ACCESS_KEY: -4}${NC}"
echo ""

echo -e "${BLUE}📄 Credentials saved to: ${YELLOW}${CREDENTIALS_FILE}${NC}"
echo ""

echo -e "${GREEN}Next Steps:${NC}"
echo -e "  ${BLUE}1.${NC} Sign up for Terraform Cloud:"
echo -e "     ${YELLOW}https://app.terraform.io/signup${NC}"
echo ""
echo -e "  ${BLUE}2.${NC} Create organization: ${YELLOW}eren-team${NC}"
echo ""
echo -e "  ${BLUE}3.${NC} Create workspace: ${YELLOW}eren-prod${NC}"
echo ""
echo -e "  ${BLUE}4.${NC} Add environment variables in Terraform Cloud:"
echo -e "     Go to: Workspace Settings > Variables"
echo -e "     Add these as ${YELLOW}ENVIRONMENT${NC} variables (mark as ${YELLOW}SENSITIVE${NC}):"
echo ""
echo -e "     ${YELLOW}AWS_ACCESS_KEY_ID${NC}     = ${ACCESS_KEY_ID}"
echo -e "     ${YELLOW}AWS_SECRET_ACCESS_KEY${NC} = (copy from ${CREDENTIALS_FILE})"
echo -e "     ${YELLOW}AWS_REGION${NC}            = us-east-1"
echo ""
echo -e "  ${BLUE}5.${NC} Configure Terraform backend (we'll create this next)"
echo ""
echo -e "  ${BLUE}6.${NC} Login to Terraform Cloud:"
echo -e "     ${YELLOW}terraform login${NC}"
echo ""
echo -e "  ${BLUE}7.${NC} Initialize Terraform:"
echo -e "     ${YELLOW}cd terraform && terraform init${NC}"
echo ""
echo -e "  ${BLUE}8.${NC} ${RED}IMPORTANT: Delete credentials file after storing in Terraform Cloud!${NC}"
echo -e "     ${YELLOW}rm ${CREDENTIALS_FILE}${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}From now on, manage ALL other IAM users/roles via Terraform!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}Security Notes:${NC}"
echo -e "  • These credentials have broad permissions (EKS, RDS, VPC, etc.)"
echo -e "  • Store them ONLY in Terraform Cloud (encrypted)"
echo -e "  • Never commit to Git (.gitignore is configured)"
echo -e "  • Rotate keys every 90 days (add reminder)"
echo ""
