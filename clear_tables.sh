#!/bin/bash
# clear_tables.sh
# Deletes and recreates fingerprints and MitigationLog tables.
# Run this before each new experiment to keep datasets clean.
# Usage: ./clear_tables.sh

REGION="eu-north-1"

echo "Clearing fingerprints table..."
aws dynamodb delete-table --table-name fingerprints --region $REGION 2>/dev/null
sleep 10
aws dynamodb create-table \
  --table-name fingerprints \
  --attribute-definitions AttributeName=windowStart,AttributeType=S \
  --key-schema AttributeName=windowStart,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION
echo "fingerprints table recreated."

echo ""
echo "Clearing MitigationLog table..."
aws dynamodb delete-table --table-name MitigationLog --region $REGION 2>/dev/null
sleep 10
aws dynamodb create-table \
  --table-name MitigationLog \
  --attribute-definitions AttributeName=timestamp,AttributeType=S \
  --key-schema AttributeName=timestamp,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $REGION
echo "MitigationLog table recreated."

echo ""
echo "Both tables cleared and ready for next experiment."