#!/bin/bash

#FIX - instance type: t3.large (2vCPU, 8GB RAM + storage of 20GB)

DOCKER_VERSION="5:29.5.2-1~ubuntu.26.04~resolute" # To get the version: install docker on t2.nano (until apt-get update, included) and run "apt-cache madison docker-ce"
MINIKUBE_RELEASE="1.38.1"
KUBECTL_VERSION="1.36.1"

HOST_USER=$(id -un 1000 2>/dev/null || echo "ubuntu")

set -e  # Exit immediately if any command returns a non-zero status

echo "#### 0. Storage Automation (EBS Mount) ####"
echo "Waiting for persistent EBS volume to attach..."
MAX_ATTEMPTS=24 # 24 attempts * 5 seconds = 120 seconds total
ATTEMPT=0

while true; do
    # Search for an NVMe disk that isn't the root OS drive (nvme0n1)
    TARGET_DEVICE=$(lsblk -dno NAME | grep "^nvme" | grep -v "nvme0n1" | head -n 1)

    if [ ! -z "$TARGET_DEVICE" ]; then
        echo "Success: Found persistent EBS volume at /dev/$TARGET_DEVICE after $((ATTEMPT * 5)) seconds."
        DEVICE_PATH="/dev/$TARGET_DEVICE"
        break
    fi

    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo "ERROR: Persistent EBS volume failed to attach within 2 minutes!"
        exit 1
    fi

    echo "Volume not ready yet. Retrying in 5 seconds... (Attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 5
done

# Check filesystem and format if missing
if ! blkid $DEVICE_PATH; then
    mkfs -t ext4 $DEVICE_PATH
fi

mkdir -p /var/lib/docker

# Temporary mount to grab UUID safely
mount $DEVICE_PATH /var/lib/docker
VOLUME_UUID=$(blkid -o value -s UUID $DEVICE_PATH)
umount /var/lib/docker

if ! grep -q "$VOLUME_UUID" /etc/fstab; then
    echo "UUID=$VOLUME_UUID /var/lib/docker ext4 defaults 0 2" >> /etc/fstab
fi

mount -a
echo "EBS Volume successfully mounted to /var/lib/docker"

#### 0b. Automatic BuildKit Metadata Sync ####
# If this is a fresh EC2 instance, the Docker engine isn't installed yet,
# but an old buildKit cache might exist on the re-attached EBS volume.
if [ -d "/var/lib/docker/buildkit" ]; then
    echo "Detected existing Docker build state on attached volume."
    echo "Cleaning old BuildKit metadata and overlay graphs to prevent synchronization errors..."

    # Safely clear only the ghost build caches, while 'volumes/jenkins_home' directory remains completely untouched
    rm -rf /var/lib/docker/buildkit
    rm -rf /var/lib/docker/overlay2

    echo "Metadata sync complete. Safe to proceed with clean Docker initialization."
fi


echo "#### 1. Waiting for Internet connectivity ####"
echo 'Acquire::ForceIPv4 "true";' > /etc/apt/apt.conf.d/99force-ipv4
echo "Waiting for NAT Gateway internet connectivity..."
until curl -s --connect-timeout 3 https://8.8.8.8 > /dev/null; do
    echo "Internet not reachable yet. Retrying in 5 seconds..."
    sleep 5
done
echo "Internet connection established!"


echo "#### 2. Installing Docker ####"
apt-get update
apt-get install -y git curl ca-certificates #ce-certificates required for Docker

install -m 0755 -d /etc/apt/keyrings
curl -sSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

apt-get update
# Install Docker Packages and Docker Compose
apt install -y \
    docker-ce=$DOCKER_VERSION \
    docker-ce-cli=$DOCKER_VERSION \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Permissions
usermod -aG docker $HOST_USER

# FIX - minikube - maybe I won't install minikube
# FIX - if so, update the titles counting
# echo "#### 2. Installing Minikube ####"
# curl -LO https://github.com/kubernetes/minikube/releases/download/v$MINIKUBE_RELEASE/minikube-linux-amd64
# install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64


echo "#### 3. Installing kubectl (if we will want to debug from the host) ####"
curl -LO "https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/amd64/kubectl.sha256"
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check # Validates kubectl binary against the checksum file
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# FIX - minikube + update title, it is incorrect
# echo "#### 4. Running Jenkins container ####"
# mkdir -p /home/$HOST_USER/.minikube /home/$HOST_USER/.kube /home/$HOST_USER/.docker
# chown -R $HOST_USER:$HOST_USER /home/$HOST_USER/.minikube /home/$HOST_USER/.kube /home/$HOST_USER/.docker

# Starting minikube as $HOST_USER
# sudo -i -u $HOST_USER minikube start --driver=docker # FIX - minikube


echo "#### 5. Clone repository and start Jenkins ####"
REPO_DIR="/home/$HOST_USER/devops-experts-final-project"
sudo -i -u $HOST_USER git clone https://github.com/Ori-Sason/devops-experts-final-project "$REPO_DIR"

DOCKER_GID=$(stat -c %g /var/run/docker.sock)
sudo -i -u $HOST_USER bash -c "cd $REPO_DIR && DOCKER_GID=$DOCKER_GID docker compose -f ./jenkins/docker-compose.yaml up -d"
# sudo -i -u $HOST_USER docker network connect minikube jenkins # FIX - minikube

# To view provisioning script inside the instance
# 1. log he instance using SSH
# 2. tail -f /var/log/cloud-init-output.log
