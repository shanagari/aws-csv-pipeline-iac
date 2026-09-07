#!/bin/bash
# Tears down the CSV ingestion pipeline stack.
# Empties the S3 buckets first since CloudFormation refuses to delete
# non-empty buckets, then deletes the stack.

set -e

STACK_NAME="csv-pipeline-stack"

echo "Fetching bucket names from stack '${STACK_NAME}'..."

INPUT_BUCKET=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='InputBucketName'].OutputValue" --output text)
OUTPUT_BUCKET=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='OutputBucketName'].OutputValue" --output text)
SCRIPTS_BUCKET=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='ScriptsBucketName'].OutputValue" --output text)

for BUCKET in "${INPUT_BUCKET}" "${OUTPUT_BUCKET}" "${SCRIPTS_BUCKET}"; do
  if [ -n "${BUCKET}" ] && [ "${BUCKET}" != "None" ]; then
    echo "Emptying s3://${BUCKET} ..."
    aws s3 rm "s3://${BUCKET}" --recursive || true
  fi
done

echo "Deleting stack '${STACK_NAME}'..."
aws cloudformation delete-stack --stack-name "${STACK_NAME}"

echo "Waiting for deletion to complete (this can take a few minutes)..."
aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}"

echo "Stack deleted."
