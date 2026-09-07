#!/bin/bash
# Uploads sample data to the already-deployed pipeline's input bucket.
# Run this any time you want to (re-)trigger the pipeline without touching
# infrastructure. Requires the stack from deploy.sh to already exist.

set -e

STACK_NAME="csv-pipeline-stack"

INPUT_BUCKET=$(aws cloudformation describe-stacks --stack-name "${STACK_NAME}" \
  --query "Stacks[0].Outputs[?OutputKey=='InputBucketName'].OutputValue" --output text)

if [ -z "${INPUT_BUCKET}" ] || [ "${INPUT_BUCKET}" == "None" ]; then
  echo "Stack '${STACK_NAME}' not found or has no InputBucketName output. Run ./deploy.sh first."
  exit 1
fi

# The S3 event notification only fires on raw/ratings/*.csv uploads (see
# pipeline.yaml) so that the workflow only starts once both movies.csv and
# ratings.csv already exist in S3. Upload movies.csv first.
echo "Uploading to s3://${INPUT_BUCKET} ..."
aws s3 cp sample-data/movies/movies.csv    "s3://${INPUT_BUCKET}/raw/movies/movies.csv"
aws s3 cp sample-data/ratings/ratings.csv  "s3://${INPUT_BUCKET}/raw/ratings/ratings.csv"

echo "Uploaded. The ratings.csv upload above triggers the Glue Workflow automatically."
