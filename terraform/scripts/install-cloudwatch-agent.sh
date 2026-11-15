#!/usr/bin/env bash
set -euxo pipefail

CW_AGENT_SSM_PARAM="${CW_AGENT_SSM_PARAM:-}"

# Configure bounded Docker json-file log rotation so container logs remain
# inspectable locally (`docker logs`) while CloudWatch Agent ships them.
if [[ -d /etc/docker && ! -f /etc/docker/daemon.json ]]; then
  cat <<'EOF' | sudo tee /etc/docker/daemon.json >/dev/null
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
  sudo systemctl restart docker
fi

# Install AWS CloudWatch Agent on Debian if not already installed
if ! command -v amazon-cloudwatch-agent-ctl >/dev/null 2>&1; then
  ARCH="$(dpkg --print-architecture)"
  curl -fsSL "https://s3.amazonaws.com/amazoncloudwatch-agent/debian/${ARCH}/latest/amazon-cloudwatch-agent.deb" -o /tmp/amazon-cloudwatch-agent.deb
  sudo dpkg -i -E /tmp/amazon-cloudwatch-agent.deb
  rm -f /tmp/amazon-cloudwatch-agent.deb
fi

if [[ -z "${CW_AGENT_SSM_PARAM}" ]]; then
  echo "CW_AGENT_SSM_PARAM is empty; skipping CloudWatch Agent SSM configuration."
  exit 0
fi

# Fetch configuration from SSM Parameter Store (retry briefly during initial apply)
CONFIGURED=false
for _ in $(seq 1 18); do
  if sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -s \
    -c "ssm:${CW_AGENT_SSM_PARAM}"; then
    CONFIGURED=true
    break
  fi
  sleep 10
done

if [[ "${CONFIGURED}" != "true" ]]; then
  echo "Failed to fetch CloudWatch Agent configuration from SSM parameter: ${CW_AGENT_SSM_PARAM}" >&2
  exit 1
fi

sudo systemctl enable amazon-cloudwatch-agent
