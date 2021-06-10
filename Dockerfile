FROM summerwind/actions-runner:latest

LABEL maintainer "Pål Sollie <sollie@sparkz.no>"
LABEL org.opencontainers.image.source https://github.com/sollie/actions-runner

USER root
ENV DEBIAN_FRONTEND=noninteractive
ENV INSTALLER_SCRIPTS=/virtual-environments/images/linux/scripts/installers
ENV HELPER_SCRIPTS=/virtual-environments/images/linux/scripts/helpers
ADD packages /packages
RUN apt-get update && \
    apt-get install -y software-properties-common && \
    add-apt-repository ppa:longsleep/golang-backports && \
    apt-get install golang-go && \
    git clone https://github.com/actions/virtual-environments && \
    echo "#!/bin/bash" > $HELPER_SCRIPTS/invoke-tests.sh && \
    chmod +x $HELPER_SCRIPTS/invoke-tests.sh && \
    ln -s $HELPER_SCRIPTS/invoke-tests.sh /usr/local/bin/invoke_tests && \
    bash ${INSTALLER_SCRIPTS}/dpkg-config.sh && \
    for f in $(cat packages); do bash "${INSTALLER_SCRIPTS}/$f.sh"; done && \
    bash ${INSTALLER_SCRIPTS}/cleanup.sh && \
    rm -rf virtual-environments
USER runner
