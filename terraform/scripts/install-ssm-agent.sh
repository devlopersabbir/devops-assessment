#!/usr/bin/env bash
# Installs and starts the AWS SSM Agent on Debian 12/13 EC2 instances.
# Shared by every environment (prod ASG instances in private subnets via NAT,
# staging single EC2 in a public subnet via Internet Gateway).
set -euxo pipefail

IMDS="http://169.254.169.254/latest"

# Resolve the instance region from IMDSv2 (used for the regional SSM endpoints/bucket)
IMDS_TOKEN="$(curl -fsS --retry 10 --retry-delay 2 --retry-connrefused -X PUT "${IMDS}/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 300")"
AWS_REGION="$(curl -fsS --retry 10 --retry-delay 2 -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" \
  "${IMDS}/meta-data/placement/region")"

# Wait for outbound internet connectivity (NAT Gateway / Internet Gateway).
# No `-f` here: the SSM endpoint root returns an HTTP 4xx, but ANY HTTP response
# proves the network path works. (Using `-f` made this loop always time out.)
for _ in $(seq 1 30); do
  if curl -sS -o /dev/null --connect-timeout 5 "https://ssm.${AWS_REGION}.amazonaws.com"; then
    break
  fi
  sleep 5
done

# Install and enable the AWS SSM Agent if it is not already active
if ! systemctl is-active --quiet amazon-ssm-agent; then
  ARCH="$(dpkg --print-architecture)"
  curl -fsSL --retry 5 --retry-delay 5 --retry-connrefused \
    "https://s3.${AWS_REGION}.amazonaws.com/amazon-ssm-${AWS_REGION}/latest/debian_${ARCH}/amazon-ssm-agent.deb" \
    -o /tmp/amazon-ssm-agent.deb
  dpkg -i /tmp/amazon-ssm-agent.deb
  rm -f /tmp/amazon-ssm-agent.deb
  systemctl enable --now amazon-ssm-agent
fi
