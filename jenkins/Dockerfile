FROM alpine:3.19 AS downloader
RUN apk add --no-cache curl
RUN DOCKER_VERSION="29.5.2" && \
    curl -sSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" | tar -xz -C /tmp && \
    \
    KUBECTL_VERSION="1.36.1" && \
    curl -Lo /tmp/kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" && \
    chmod +x /tmp/kubectl && \
    \
    HELM_VERSION="4.2.0" &&\
    curl -sSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar -xz -C /tmp && \
    \
    YQ_VERSION="4.53.2" && \
    curl -Lo /tmp/yq "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64" && \
    chmod +x /tmp/yq && \
    \
    GITLEAKS_VERSION="8.30.1" && \
    curl -sSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" | tar -xz -C /tmp gitleaks && \
    chmod +x /tmp/gitleaks



FROM jenkins/jenkins:lts-jdk21
USER root

COPY --from=downloader /tmp/docker/docker /usr/local/bin/docker
COPY --from=downloader /tmp/kubectl /usr/local/bin/kubectl
COPY --from=downloader /tmp/linux-amd64/helm /usr/local/bin/helm
COPY --from=downloader /tmp/yq /usr/local/bin/yq
COPY --from=downloader /tmp/gitleaks /usr/local/bin/gitleaks

RUN git config --system user.name "Jenkins CI" && \
    git config --system user.email "jenkins@my-awesome-devops-company.com"

USER jenkins
