#!/bin/bash
set -e

echo "#### 0. Waiting for Internet connectivity ####"
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
echo "Waiting for NAT Gateway internet connectivity..."
until curl -s --connect-timeout 3 https://8.8.8.8 > /dev/null; do
    echo "Internet not reachable yet. Retrying in 5 seconds..."
    sleep 5
done
echo "Internet connection established!"

echo "#### 1. Install dependencies ####"
apt-get update -y
apt-get install -y awscli

# Install K3s Control Plane
# --write-kubeconfig-mode makes the local kubectl usable immediately
curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode 644

echo "#### 2. Wait for K3s to generate the node join token ####"
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 2
done

K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)

echo "#### 3. Upload the real Token to SSM Parameter Store, overwriting the placeholder ####"
aws ssm put-parameter \
  --name "/k3s/cluster-token" \
  --value "$K3S_TOKEN" \
  --type "SecureString" \
  --overwrite \
  --region "${aws_region}"
