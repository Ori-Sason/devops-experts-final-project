#!/bin/bash
set -e

apt-get update -y
apt-get install -y awscli

K3S_MASTER_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Role,Values=k3s-master" "Name=instance-state-name,Values=running" \
  --query "Reservations[*].Instances[*].PrivateIpAddress" \
  --output text \
  --region "${aws_region}" | head -n 1)

K3S_JOIN_TOKEN=""
echo "Waiting for Master to publish K3s Join Token to SSM..."
while [ -z "$${K3S_JOIN_TOKEN}" ] || [ "$${K3S_JOIN_TOKEN}" == "placeholder" ]; do
  K3S_JOIN_TOKEN=$(aws ssm get-parameter \
    --name "/k3s/cluster-token" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text \
    --region "${aws_region}" \
    2>/dev/null)
  echo "Token not ready yet. Retrying in 5 seconds..."
  sleep 5
done
echo "Token successfully retrieved!"

# Wipe out any stale configuration files (useful in debugging runs)
rm -f /etc/systemd/system/k3s-agent.service.env
rm -rf /var/lib/rancher/k3s/agent/

# Install K3s Agent
curl -sfL https://get.k3s.io | \
  K3S_URL="https://$${K3S_MASTER_IP}:6443" \
  K3S_TOKEN="$${K3S_JOIN_TOKEN}" \
  INSTALL_K3S_EXEC="agent --node-label=role=${node_role_label}" \
  sh -
