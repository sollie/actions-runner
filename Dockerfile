FROM ubuntu:20.04

LABEL maintainer "Pål Sollie <sollie@sparkz.no>"
LABEL org.opencontainers.image.source https://github.com/sollie/actions-runner

ARG TARGETPLATFORM
#ARG RUNNER_VERSION=2.280.3
ARG DOCKER_CHANNEL=stable
ARG DOCKER_VERSION=20.10.8
ARG DUMB_INIT_VERSION=1.2.5

RUN test -n "$TARGETPLATFORM" || (echo "TARGETPLATFORM must be set" && false)

USER root
ENV DEBIAN_FRONTEND=noninteractive
ADD packages /packages
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository -y ppa:longsleep/golang-backports && \
    add-apt-repository -y ppa:git-core/ppa && \
    for f in $(cat packages); do bash "${INSTALLER_SCRIPTS}/$f.sh"; done && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    rm -rf /var/lib/apt/lists/* && \

# arch command on OS X reports "i386" for Intel CPUs regardless of bitness
RUN export ARCH=$(echo ${TARGETPLATFORM} | cut -d / -f2) && \
    if [ "$ARCH" = "arm64" ]; then export ARCH=aarch64 ; fi && \
    if [ "$ARCH" = "amd64" ] || [ "$ARCH" = "i386" ]; then export ARCH=x86_64 ; fi && \
    curl -f -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_${ARCH} && \
    chmod +x /usr/local/bin/dumb-init

# Docker download supports arm64 as aarch64 & amd64 / i386 as x86_64
RUN set -vx; && \
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
