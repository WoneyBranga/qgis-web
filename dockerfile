FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie

LABEL maintainer="engenharia"
LABEL app="qgis-web"
LABEL source="internal-build"

ENV TITLE="QGIS Web"
ENV START_DOCKER=false
ENV DISABLE_SUDO=true
ENV DISABLE_TERMINALS=true
ENV HARDEN_DESKTOP=true
ENV HARDEN_OPENBOX=true
ENV RESTART_APP=true

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
    \
    echo "Removendo componentes desnecessários para o QGIS" && \
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
    \
    apt-get autoclean && \
    rm -rf \
        /var/lib/apt/lists/* \
        /tmp/* \
        /var/tmp/* \
        /config/.cache

COPY root/ /

