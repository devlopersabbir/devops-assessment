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

PROFILE_ARGS=()
if [[ -n "${AWS_PROFILE_NAME}" ]]; then
  PROFILE_ARGS=(--profile "${AWS_PROFILE_NAME}")
fi

echo "Looking up running EC2 instance for '${ENVIRONMENT}'..."
INSTANCE_ID="$(terraform -chdir="${TF_ENV_DIR}" output -raw ec2_instance_id 2>/dev/null || true)"

if [[ -z "${INSTANCE_ID}" ]]; then
  ASG_NAME="$(terraform -chdir="${TF_ENV_DIR}" output -raw asg_name 2>/dev/null || echo "devops-assessment-${ENVIRONMENT}-asg")"
  INSTANCE_ID="$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "${ASG_NAME}" \
    --region "${AWS_REGION_NAME}" \
    "${PROFILE_ARGS[@]}" \
    --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'] | [0].InstanceId" \
    --output text 2>/dev/null || true)"
fi

if [[ -z "${INSTANCE_ID}" || "${INSTANCE_ID}" == "None" ]]; then
  echo "Error: Could not find a running InService EC2 instance for '${ENVIRONMENT}'." >&2
  exit 1
fi

echo "Starting SSM session to ${INSTANCE_ID} (${ENVIRONMENT} in ${AWS_REGION_NAME})..."
exec aws ssm start-session \
  --target "${INSTANCE_ID}" \
  --region "${AWS_REGION_NAME}" \
  "${PROFILE_ARGS[@]}"
