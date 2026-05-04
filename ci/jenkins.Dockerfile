FROM jenkins/jenkins:lts-jdk17

USER root

ARG KUBECTL_VERSION=v1.30.5
ARG TERRAFORM_VERSION=1.9.8
ARG SONAR_SCANNER_VERSION=6.2.1.4610
ARG HELM_VERSION=v3.16.2

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release unzip git \
        python3 python3-pip python3-venv pipx \
        sshpass rsync jq \
    && rm -rf /var/lib/apt/lists/*

RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
        -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o /tmp/helm.tgz \
    && tar -xzf /tmp/helm.tgz -C /tmp \
    && mv /tmp/linux-amd64/helm /usr/local/bin/helm \
    && rm -rf /tmp/helm.tgz /tmp/linux-amd64

RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
        -o /tmp/tf.zip \
    && unzip /tmp/tf.zip -d /usr/local/bin \
    && rm /tmp/tf.zip

RUN curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
        | sh -s -- -b /usr/local/bin

RUN curl -fsSL "https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-${SONAR_SCANNER_VERSION}-linux-x64.zip" \
        -o /tmp/scanner.zip \
    && unzip -q /tmp/scanner.zip -d /opt \
    && ln -s "/opt/sonar-scanner-${SONAR_SCANNER_VERSION}-linux-x64/bin/sonar-scanner" /usr/local/bin/sonar-scanner \
    && rm /tmp/scanner.zip

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

RUN pip3 install --break-system-packages --no-cache-dir \
        ansible==10.4.0 kubernetes==31.0.0 \
    && ansible-galaxy collection install kubernetes.core community.general

USER jenkins
