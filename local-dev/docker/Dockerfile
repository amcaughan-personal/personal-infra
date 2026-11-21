FROM ubuntu:24.04@sha256:9c7f200c07e3d4a03e7249d2c16bf66a51120fb876aa2242cf31451412543289
ENV DEBIAN_FRONTEND=noninteractive

# Pins. Every download below is checked against a SHA-256: from the publisher's SHA256SUMS
# file where one exists, otherwise recorded here when the version was pinned.
ARG TERRAFORM_VERSION=1.17.2
ARG TERRAGRUNT_VERSION=v1.2.2
ARG AWSCLI_VERSION=2.40.3
ARG AWSCLI_SHA256=4770c06c4ecfc8ba94b60d89e6c7018ab7ea2cf5341b1ef05f6f93c5d6e8b705
ARG SSM_PLUGIN_VERSION=1.2.896.0
ARG SSM_PLUGIN_SHA256=53f51fcc67314a4bf85888a38a3967cd41f8d0f28a60a9469a63acf935ba713e

# Basic tools
RUN apt-get update && apt-get install -y \
    apt-utils \
    ca-certificates \
    curl \
    git \
    python3 \
    unzip \
  && rm -rf /var/lib/apt/lists/*

# Non-root user
# uid 1000 matches the usual host user, so mounted files stay writable. (Ubuntu's image
# ships an `ubuntu` user with that uid, so it goes first.)
RUN userdel -r ubuntu 2>/dev/null; useradd -ms /bin/bash -u 1000 dev

# AWS CLI
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" -o /tmp/awscliv2.zip \
  && echo "${AWSCLI_SHA256}  /tmp/awscliv2.zip" | sha256sum -c - \
  && unzip -q /tmp/awscliv2.zip -d /tmp \
  && /tmp/aws/install \
  && rm -rf /tmp/aws /tmp/awscliv2.zip

# Session Manager plugin
RUN curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/${SSM_PLUGIN_VERSION}/ubuntu_64bit/session-manager-plugin.deb" \
    -o /tmp/session-manager-plugin.deb \
  && echo "${SSM_PLUGIN_SHA256}  /tmp/session-manager-plugin.deb" | sha256sum -c - \
  && dpkg -i /tmp/session-manager-plugin.deb \
  && rm -f /tmp/session-manager-plugin.deb

# Terraform
RUN cd /tmp \
  && curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" \
  && curl -fsSLO "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS" \
  && grep "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" "terraform_${TERRAFORM_VERSION}_SHA256SUMS" | sha256sum -c - \
  && unzip -q "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -d /usr/local/bin \
  && rm -f terraform_*

# Terragrunt
RUN cd /tmp \
  && curl -fsSLO "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/terragrunt_linux_amd64" \
  && curl -fsSLO "https://github.com/gruntwork-io/terragrunt/releases/download/${TERRAGRUNT_VERSION}/SHA256SUMS" \
  && grep " terragrunt_linux_amd64$" SHA256SUMS | sha256sum -c - \
  && install -m 0755 terragrunt_linux_amd64 /usr/local/bin/terragrunt \
  && rm -f terragrunt_linux_amd64 SHA256SUMS

USER dev
WORKDIR /workspace
CMD ["/bin/bash"]
