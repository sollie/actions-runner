FROM public.ecr.aws/lts/ubuntu:20.04

LABEL maintainer "Pål Sollie <sollie@sparkz.no>"
LABEL org.opencontainers.image.source https://github.com/sollie/actions-runner

ARG TARGETPLATFORM
ARG RUNNER_VERSION
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=20.10.8
ARG DUMB_INIT_VERSION=1.2.5

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

USER root
ENV DEBIAN_FRONTEND=noninteractive
ENV INSTALLER_SCRIPTS=/virtual-environments/images/linux/scripts/installers
ENV HELPER_SCRIPTS=/virtual-environments/images/linux/scripts/helpers
ADD packages /packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends dpkg apt-utils && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:longsleep/golang-backports && \
    add-apt-repository -y ppa:git-core/ppa && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
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
    zstd && \
    git clone https://github.com/actions/virtual-environments && \
    echo "#!/bin/bash" > $HELPER_SCRIPTS/invoke-tests.sh && \
    chmod +x $HELPER_SCRIPTS/invoke-tests.sh && \
    ln -s $HELPER_SCRIPTS/invoke-tests.sh /usr/local/bin/invoke_tests && \
    for f in $(cat packages); do bash "${INSTALLER_SCRIPTS}/$f.sh"; done && \
    bash ${INSTALLER_SCRIPTS}/dpkg-config.sh && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -rf /var/lib/apt/lists/* && \
    bash ${INSTALLER_SCRIPTS}/cleanup.sh && \
    rm -rf virtual-environments

# arch command on OS X reports "i386" for Intel CPUs regardless of bitness
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) && \
    if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi && \
    if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi && \
    curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} && \
    chmod +x /usr/local/bin/dumb-init

# Docker download supports arm64 as aarch64 & amd64 / i386 as x86_64
RUN set -vx; \
    export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2)  && \
    if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi && \
    if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi && \
    curl -f -L -o docker.tgz https://download.docker.com/linux/static/${DOCKER_CHANNEL}/${ARCH}/docker-${DOCKER_VERSION}.tgz && \
    tar zxvf docker.tgz && \
    install -o root -g root -m 755 docker/docker /usr/local/bin/docker && \
    rm -rf docker docker.tgz && \
    adduser --disabled-password --gecos "" --uid 1000 runner && \
    groupadd docker && \
    usermod -aG sudo runner && \
    usermod -aG docker runner && \
    echo "%sudo   ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers

ENV RUNNER_ASSETS_DIR=/runnertmp
ENV HOME=/home/runner

RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) && \
    if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x64 ; fi && \
    mkdir -p "$RUNNER_ASSETS_DIR" && \
    cd "$RUNNER_ASSETS_DIR" && \
    curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz && \
    tar xzf ./runner.tar.gz && \
    rm runner.tar.gz && \
    ./bin/installdependencies.sh && \
    mv ./externals ./externalstmp && \
    apt-get install -y libyaml-dev && \
    rm -rf /var/lib/apt/lists/*

ENV RUNNER_TOOL_CACHE=/opt/hostedtoolcache
RUN mkdir /opt/hostedtoolcache && \
    chgrp docker /opt/hostedtoolcache && \
    chmod g+rwx /opt/hostedtoolcache

COPY entrypoint.sh /
COPY --chown=runner:docker patched $RUNNER_ASSETS_DIR/patched

# Add the Python "User Script Directory" to the PATH
ENV PATH="${PATH}:${HOME}/.local/bin"
ENV ImageOS=ubuntu20

USER runner

ENTRYPOINT ["/usr/local/bin/dumb-init", "--"]
CMD ["/entrypoint.sh"]
