#!/bin/bash

#instance type: t3.large (2vCPU, 8GB RAM + storage of 20GB)

DOCKER_VERSION="5:29.5.2-1~ubuntu.26.04~resolute" # To get the version: install docker on t2.nano (until apt-get update, included) and run "apt-cache madison docker-ce"
MINIKUBE_RELEASE="1.38.1"
KUBECTL_VERSION="1.36.1"

HOST_USER=$(id -un 1000 2>/dev/null || echo "ubuntu")


apt-get update
apt-get install -y git curl ca-certificates #ce-certificates required for Docker


echo "#### 1. Installing Docker ####"
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
