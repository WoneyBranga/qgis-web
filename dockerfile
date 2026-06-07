FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

LABEL maintainer="engenharia"
LABEL app="qgis-web"
LABEL source="internal-build"

ENV TITLE="QGIS Web" \
    START_DOCKER=false \
    DISABLE_SUDO=true \
    DISABLE_TERMINALS=true \
    HARDEN_DESKTOP=true \
    HARDEN_OPENBOX=true \
    RESTART_APP=true

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
        qgis \
        qgis-plugin-grass \
        python3-qgis \
        gdal-bin \
        proj-bin \
        postgresql-client \
        ca-certificates \
        fonts-dejavu \
        fonts-liberation \
        locales && \
    apt-get purge -y --autoremove \
        docker-ce \
        docker-ce-cli \
        docker-buildx-plugin \
        docker-compose-plugin \
        containerd.io \
        sudo \
        xterm \
        stterm \
        openssh-client || true && \
    rm -f \
        /etc/ssl/private/ssl-cert-snakeoil.key \
        /etc/ssl/certs/ssl-cert-snakeoil.pem && \
    apt-get autoclean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/*

COPY root/ /
