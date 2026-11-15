#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/ssm-connect.sh [staging|prod] [aws-profile] [aws-region]
ENVIRONMENT="${1:-staging}"
AWS_PROFILE_NAME="${2:-${AWS_PROFILE:-devops}}"
AWS_REGION_NAME="${3:-${AWS_REGION:-ap-south-1}}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_ENV_DIR="${SCRIPT_DIR}/../terraform/environments/${ENVIRONMENT}"

if [[ ! -d "${TF_ENV_DIR}" ]]; then
  echo "Error: Environment directory not found: ${TF_ENV_DIR}" >&2
  exit 1
fi

echo "Fetching EC2 instance ID for '${ENVIRONMENT}'..."
INSTANCE_ID="$(terraform -chdir="${TF_ENV_DIR}" output -raw ec2_instance_id 2>/dev/null || true)"

if [[ -z "${INSTANCE_ID}" ]]; then
  echo "Error: Could not retrieve 'ec2_instance_id' from Terraform outputs in ${TF_ENV_DIR}." >&2
  echo "Make sure 'terraform apply' has completed in that environment." >&2
  exit 1
fi

echo "Starting SSM session to ${INSTANCE_ID} (${ENVIRONMENT} in ${AWS_REGION_NAME})..."
if [[ -n "${AWS_PROFILE_NAME}" ]]; then
  exec aws ssm start-session \
    --target "${INSTANCE_ID}" \
    --region "${AWS_REGION_NAME}" \
    --profile "${AWS_PROFILE_NAME}"
else
  exec aws ssm start-session \
    --target "${INSTANCE_ID}" \
    --region "${AWS_REGION_NAME}"
fi
