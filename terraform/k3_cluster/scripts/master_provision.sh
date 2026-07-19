#!/bin/bash
set -e

apt-get update -y
apt-get install -y awscli

# 1. Install K3s Control Plane
# --write-kubeconfig-mode makes the local kubectl usable immediately
curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644

# 2. Wait for K3s to generate the node join token
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 2
done

K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)

# 3. Upload the real Token to SSM Parameter Store, overwriting the placeholder
aws ssm put-parameter \
  --name "/k3s/cluster-token" \
  --value "$K3S_TOKEN" \
  --type "SecureString" \
  --overwrite \
  --region "${aws_region}"
