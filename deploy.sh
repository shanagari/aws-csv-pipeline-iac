#!/bin/bash
# Deploys the CSV ingestion pipeline stack.
# Usage: ./deploy.sh [notification-email]
#   notification-email (optional): email to receive Glue job/crawler failure alerts.

set -e

STACK_NAME="csv-pipeline-stack"
TEMPLATE_FILE="pipeline.yaml"
REGION=$(aws configure get region)
NOTIFICATION_EMAIL="${1:-}"

echo "Deploying stack '${STACK_NAME}' to region ${REGION}..."

PARAM_OVERRIDES="NotificationEmail=${NOTIFICATION_EMAIL}"

aws cloudformation deploy \
  --template-file "${TEMPLATE_FILE}" \
  --stack-name "${STACK_NAME}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides ${PARAM_OVERRIDES}

echo "Stack deployed. Fetching output bucket names..."

INPUT_BUCKET=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='InputBucketName'].OutputValue" --output text)
OUTPUT_BUCKET=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='OutputBucketName'].OutputValue" --output text)
SCRIPTS_BUCKET=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='ScriptsBucketName'].OutputValue" --output text)

echo "Uploading Glue ETL script to s3://${SCRIPTS_BUCKET}/scripts/transform.py ..."
aws s3 cp scripts/transform.py "s3://${SCRIPTS_BUCKET}/scripts/transform.py"

echo ""
echo "Done. Input bucket: ${INPUT_BUCKET}"
echo "Run ./upload-data.sh to load the sample data and trigger the pipeline."
