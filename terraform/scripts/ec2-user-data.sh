#!/usr/bin/env bash
set -euxo pipefail

# Wait for outbound internet connectivity via NAT Gateway
for _ in $(seq 1 30); do
  if curl -fsSLI --connect-timeout 5 https://s3.amazonaws.com >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

# Install and enable AWS SSM Agent on Debian 12/13 if not already active
if ! systemctl is-active --quiet amazon-ssm-agent; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y curl wget ca-certificates
  ARCH="$(dpkg --print-architecture)"
  curl -fsSL "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_${ARCH}/amazon-ssm-agent.deb" -o /tmp/amazon-ssm-agent.deb
  dpkg -i /tmp/amazon-ssm-agent.deb
  rm -f /tmp/amazon-ssm-agent.deb
  systemctl enable --now amazon-ssm-agent
  systemctl restart amazon-ssm-agent
fi
