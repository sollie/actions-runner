FROM ubuntu:20.04

LABEL maintainer "Pål Sollie <sollie@sparkz.no>"
LABEL org.opencontainers.image.source https://github.com/sollie/actions-runner

ARG TARGETPLATFORM
ARG RUNNER_VERSION
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.2.0
# Docker and Docker Compose arguments
ARG CHANNEL=stable
ARG DOCKER_VERSION=20.10.18
ARG DOCKER_COMPOSE_VERSION=v2.16.0
ARG DUMB_INIT_VERSION=1.2.5

# Use 1001 and 121 for compatibility with GitHub-hosted runners
ARG RUNNER_UID=1000
ARG DOCKER_GID=1001

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

USER root
ARG DEBIAN_FRONTEND=noninteractive
ENV INSTALLER_SCRIPTS=/virtual-environments/images/linux/scripts/installers
ENV HELPER_SCRIPTS=/virtual-environments/images/linux/scripts/helpers
ADD packages /packages
RUN apt-get update \
    && apt-get install -y \
       curl \
       gnupg \
    && apt-get update \
    && apt-get install -y software-properties-common \
    && add-apt-repository -y ppa:longsleep/golang-backports \
    && add-apt-repository -y ppa:git-core/ppa \
    && curl -f -L -o nodesource.gpg.key https://deb.nodesource.com/gpgkey/nodesource.gpg.key \
    && apt-key add nodesource.gpg.key \
    && echo "deb https://deb.nodesource.com/node_16.x focal main" >> /etc/apt/sources.list.d/nodesource.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential \
       ca-certificates \
       dnsutils \
       ftp \
       git \
       golang-go \
       iproute2 \
       iputils-ping \
       jq \
       libunwind8 \
       locales \
       netcat \
       openssh-client \
       parallel \
       python3-pip \
       rsync \
       shellcheck \
       sudo \
       telnet \
       time \
       tzdata \
       unzip \
       upx \
       wget \
       zip \
       zstd \
       nodejs \
    && git clone https://github.com/actions/virtual-environments \
    && echo "#!/bin/bash" > $HELPER_SCRIPTS/invoke-tests.sh \
    && chmod +x $HELPER_SCRIPTS/invoke-tests.sh \
    && ln -s $HELPER_SCRIPTS/invoke-tests.sh /usr/local/bin/invoke_tests \
    && for f in $(cat packages); do bash "${INSTALLER_SCRIPTS}/$f.sh"; done \
    && bash ${INSTALLER_SCRIPTS}/dpkg-config.sh \
    && ln -sf /usr/bin/python3 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip \
    && rm -rf /var/lib/apt/lists/* \
    && bash ${INSTALLER_SCRIPTS}/cleanup.sh \
    && rm -rf virtual-environments

RUN adduser --disabled-password --gecos "" --uid $RUNNER_UID runner \
    && groupadd docker --gid $DOCKER_GID \
    && usermod -aG sudo runner \
    && usermod -aG docker runner \
    && echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" >> /etc/sudoers

ENV HOME=/home/runner

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -fLo /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} \
    && chmod +x /usr/bin/dumb-init

ENV RUNNER_ASSETS_DIR=/runnertmp
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x64 ; fi \
    && mkdir -p "$RUNNER_ASSETS_DIR" \
    && cd "$RUNNER_ASSETS_DIR" \
    && curl -fLo runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && mv ./externals ./externalstmp \
    # libyaml-dev is required for ruby/setup-ruby action.
    # It is installed after installdependencies.sh and before removing /var/lib/apt/lists
    # to avoid rerunning apt-update on its own.
    && apt-get install -y libyaml-dev \
    && rm -rf /var/lib/apt/lists/*

ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache \
    && chgrp docker /opt/hostedtoolcache \
    && chmod g+rwx /opt/hostedtoolcache

RUN cd "$RUNNER_ASSETS_DIR" \
    && curl -fLo runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm -f runner-container-hooks.zip

RUN set -vx; \
    export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -fLo docker.tgz https://download.docker.com/linux/static/${CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz \
    && tar zxvf docker.tgz \
    && install -o root -g root -m 755 docker/docker /usr/bin/docker \
    && rm -rf docker docker.tgz

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) \
    && if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi \
    && if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi \
    && curl -fLo /usr/bin/docker-compose https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${ARCH} \
    && chmod +x /usr/bin/docker-compose

# We place the scripts in `/usr/bin` so that users who extend this image can
# override them with scripts of the same name placed in `/usr/local/bin`.
COPY entrypoint.sh startup.sh logger.sh graceful-stop.sh update-status /usr/bin/

# Copy the docker shim which propagates the docker MTU to underlying networks
# to replace the docker binary in the PATH.
COPY docker-shim.sh /usr/local/bin/docker

# Configure hooks folder structure.
COPY hooks /etc/arc/hooks/

# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin/"
ENV ImageOS=ubuntu20

RUN echo "PATH=${PATH}" > /etc/environment \
    && echo "ImageOS=${ImageOS}" >> /etc/environment

USER runner

ENTRYPOINT ["/bin/bash", "-c"]
CMD ["entrypoint.sh"]