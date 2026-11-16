#!/usr/bin/env bash
# Dedicated AWS SSM Session Manager connection script for Staging EC2 Instance
# Usage: ./scripts/ssm-staging.sh [aws-profile] [aws-region]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
AWS_PROFILE_NAME="${1:-${AWS_PROFILE:-devops}}"
AWS_REGION_NAME="${2:-${AWS_REGION:-ap-south-1}}"

PROFILE_ARGS=()
if [[ -n "${AWS_PROFILE_NAME}" ]]; then
  PROFILE_ARGS=(--profile "${AWS_PROFILE_NAME}")
fi

echo "Looking up running EC2 instance ID for 'staging'..."
STAGING_INSTANCE_ID="$(terraform -chdir="${ROOT_DIR}/terraform/environments/staging" output -raw instance_id 2>/dev/null || true)"

if [[ -z "${STAGING_INSTANCE_ID}" || ! "${STAGING_INSTANCE_ID}" =~ ^i-[0-9a-f]+$ ]]; then
  # Fallback to querying AWS API directly by tag
  STAGING_INSTANCE_ID="$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=devops-assessment-staging-ec2" "Name=instance-state-name,Values=running" \
    --region "${AWS_REGION_NAME}" \
    "${PROFILE_ARGS[@]}" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text 2>/dev/null || true)"
fi

if [[ -z "${STAGING_INSTANCE_ID}" || "${STAGING_INSTANCE_ID}" == "None" ]]; then
  echo "Error: Could not find a running Staging EC2 instance." >&2
  exit 1
fi

echo "=========================================================="
echo " Starting AWS SSM session to Staging (${STAGING_INSTANCE_ID})"
echo " Region: ${AWS_REGION_NAME} | Profile: ${AWS_PROFILE_NAME}"
echo "=========================================================="

exec aws ssm start-session \
  --target "${STAGING_INSTANCE_ID}" \
  --region "${AWS_REGION_NAME}" \
  "${PROFILE_ARGS[@]}"
