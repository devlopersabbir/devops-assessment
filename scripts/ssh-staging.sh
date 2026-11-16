#!/usr/bin/env bash
# Dedicated SSH connection script for the Staging EC2 Instance
# Usage: ./scripts/ssh-staging.sh [user] [path-to-pem]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/.."
KEY_PATH="${2:-${ROOT_DIR}/devops.pem}"
SSH_USER="${1:-admin}"

if [[ ! -f "${KEY_PATH}" ]]; then
  echo "Error: Key pair file not found at: ${KEY_PATH}" >&2
  exit 1
fi

# Ensure appropriate permissions on the private key file
chmod 400 "${KEY_PATH}" 2>/dev/null || true

# Retrieve staging public IP from terraform outputs or fallback to known Elastic IP
STAGING_IP="$(terraform -chdir="${ROOT_DIR}/terraform/environments/staging" output -raw public_ip 2>/dev/null || echo "3.111.180.6")"

if [[ -z "${STAGING_IP}" || "${STAGING_IP}" == "None" ]]; then
  echo "Error: Unable to determine Staging public IP address." >&2
  exit 1
fi

echo "=========================================================="
echo " Connecting to Staging EC2 Instance (${STAGING_IP})"
echo " User: ${SSH_USER} | Key: ${KEY_PATH}"
echo "=========================================================="

exec ssh -i "${KEY_PATH}" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "${SSH_USER}@${STAGING_IP}"
