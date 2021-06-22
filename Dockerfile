FROM summerwind/actions-runner:latest

LABEL maintainer "Pål Sollie <sollie@sparkz.no>"
LABEL org.opencontainers.image.source https://github.com/sollie/actions-runner

USER root
ENV DEBIAN_FRONTEND=noninteractive
ENV INSTALLER_SCRIPTS=/virtual-environments/images/linux/scripts/installers
ENV HELPER_SCRIPTS=/virtual-environments/images/linux/scripts/helpers
ADD packages /packages
RUN apt-get remove docker docker-engine docker.io containerd runc && \
    apt-get update && \
    apt-get install -y software-properties-common curl gnupg lsb-release ca-certificates apt-transport-https && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    add-apt-repository -y ppa:longsleep/golang-backports && \
    apt-get install -y golang-go rpl && \
    apt-get install -y docker-ce docker-ce-cli containerd.io && \
    git clone https://github.com/actions/virtual-environments && \
    echo "#!/bin/bash" > $HELPER_SCRIPTS/invoke-tests.sh && \
    chmod +x $HELPER_SCRIPTS/invoke-tests.sh && \
    ln -s $HELPER_SCRIPTS/invoke-tests.sh /usr/local/bin/invoke_tests && \
    bash ${INSTALLER_SCRIPTS}/dpkg-config.sh && \
    for f in $(cat packages); do bash "${INSTALLER_SCRIPTS}/$f.sh"; done && \
    bash ${INSTALLER_SCRIPTS}/cleanup.sh && \
    rm -rf virtual-environments
USER runner
