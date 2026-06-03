# Stage 1: download and install Docker, kubectl and Helm CLI binary
FROM alpine:3.19 AS downloader
RUN apk add --no-cache curl
RUN DOCKER_VERSION="29.5.2" && \
    curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" | tar -xz -C /tmp
RUN KUBECTL_VERSION="v1.36.1" && \
    curl -Lo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x /tmp/kubectl
RUN curl -fsSL https://get.helm.sh/helm-v3.21.0-linux-amd64.tar.gz | tar -xz -C /tmp
# Go-based yq (Mike Farah) to manipulate YAML files
RUN YQ_VERSION="v4.53.2" && \
    curl -Lo /tmp/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" && \
    chmod +x /tmp/yq

# Stage 2: Final Jenkins Image
FROM jenkins/jenkins:lts-jdk21
USER root

COPY --from=downloader /tmp/docker/docker /usr/local/bin/docker
COPY --from=downloader /tmp/kubectl /usr/local/bin/kubectl
COPY --from=downloader /tmp/linux-amd64/helm /usr/local/bin/helm
COPY --from=downloader /tmp/yq /usr/local/bin/yq

RUN git config --system user.name "Jenkins CI" && \
    git config --system user.email "jenkins@my-awesome-devops-company.com"

USER jenkins
