#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1:-dev}"          # dev|stg|prod
NAME_PREFIX="${2:-terraform-backend}"  # lowercase, hyphen-only
STACK_NAME="${3:-tf-backend-${ENVIRONMENT}}"
TEMPLATE_FILE="${4:-backend.yaml}"

AWS_REGION="${AWS_REGION:-us-east-1}"

echo "Deploying backend stack:"
echo "  Environment   = ${ENVIRONMENT}"
echo "  NamePrefix    = ${NAME_PREFIX}"
echo "  StackName     = ${STACK_NAME}"
echo "  Template      = ${TEMPLATE_FILE}"
echo "  AWS Region    = ${AWS_REGION}"
echo

aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --template-file "${TEMPLATE_FILE}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      Environment="${ENVIRONMENT}" \
      NamePrefix="${NAME_PREFIX}" \
      BucketName="" \
      DynamoDBTableName=""

# Fetch outputs
s3_bucket=$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --output text \
  --query "Stacks[0].Outputs[?OutputKey=='S3Bucket'].OutputValue | [0]")

dynamodb_table=$(aws cloudformation describe-stacks \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --output text \
  --query "Stacks[0].Outputs[?OutputKey=='DynamoDBTable'].OutputValue | [0]")

echo
echo "S3 bucket:      ${s3_bucket}"
echo "DynamoDB Table: ${dynamodb_table}"

# Write a per-env Terraform backend config file:
mkdir -p backend
backend_file="../backend/${ENVIRONMENT}.tfbackend"
cat > "${backend_file}" <<EOF
bucket         = "${s3_bucket}"
key            = "eks/terraform.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "${dynamodb_table}"
encrypt        = true
EOF

echo
echo "Wrote Terraform backend config - ${backend_file}"
echo "*** Use it with: terraform init -reconfigure -backend-config=${backend_file}"


# # DEV
# ./deploy-backend.sh dev terraform-backend tf-backend-dev backend.yaml

# # STG
# ./deploy-backend.sh stg terraform-backend tf-backend-stg backend.yaml

# # PROD
# ./deploy-backend.sh prod terraform-backend tf-backend-prod backend.yaml

