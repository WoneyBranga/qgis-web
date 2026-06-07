# QGIS Web com Docker + Selkies

Este projeto empacota o **QGIS Desktop** em um container Docker e disponibiliza a interface gráfica diretamente no navegador usando a base **LinuxServer/Selkies**.

A ideia é oferecer uma experiência semelhante aos containers web da LinuxServer, como FileZilla Web, Webtop e outros aplicativos desktop acessíveis via browser.

## Objetivo

Executar o QGIS Desktop em modo web para permitir:

* acesso ao QGIS pelo navegador;
* abertura de projetos `.qgz`;
* upload de arquivos via interface web;
* uso de camadas vetoriais e raster;
* acesso a dados PostGIS, WMS, WFS, GeoPackage, Shapefile e outros formatos suportados pelo QGIS;
* isolamento por container;
* uso em ambiente corporativo/laboratório.

## Arquitetura

```text
Navegador
   |
   | HTTPS / WebSocket
   |
Nginx / Proxy reverso / Autenticação corporativa
   |
   |
Container qgis-web
   |
   ├── Selkies WebRTC
   ├── NGINX interno
   ├── Ambiente gráfico Linux
   ├── QGIS Desktop
   └── Volumes de dados/projetos
```

## Estrutura do projeto

```text
qgis-web/
├── docker-compose.yml
├── Dockerfile
├── README.md
└── root/
    └── defaults/
        └── autostart
```

## Dockerfile

```dockerfile
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
    echo "Removendo componentes desnecessários para o uso do QGIS" && \
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
        /var/tmp/*

COPY root/ /
```

## Arquivo de inicialização

Crie o arquivo:

```text
root/defaults/autostart
```

Conteúdo:

```bash
#!/bin/bash
exec qgis
```

Aplique permissão de execução:

```bash
chmod +x root/defaults/autostart
```

## docker-compose.yml

```yaml
services:
  qgis-web:
    build: .
    container_name: qgis-web
    restart: unless-stopped

    ports:
      - "3001:3001"

    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo

      # Acesso web
      - CUSTOM_USER=admin
      - PASSWORD=troque-esta-senha
      - TITLE=QGIS Web

      # Hardening básico
      - START_DOCKER=false
      - DISABLE_SUDO=true
      - DISABLE_TERMINALS=true
      - HARDEN_DESKTOP=true
      - HARDEN_OPENBOX=true
      - RESTART_APP=true

      # Upload/download de arquivos via Selkies
      - SELKIES_UI_SIDEBAR_SHOW_FILES=true
      - SELKIES_FILE_TRANSFERS=upload,download
      - FILE_MANAGER_PATH=/projetos/uploads

      # Resolução inicial
      - SELKIES_MANUAL_WIDTH=1920
      - SELKIES_MANUAL_HEIGHT=1080
      - MAX_RES=1920x1080

    volumes:
      - ./config:/config
      - ./projetos:/projetos
      - ./dados:/dados:ro

    shm_size: "2gb"
```

## Subindo o ambiente

Crie as pastas locais:

```bash
mkdir -p config projetos/uploads dados
```

Ajuste permissões:

```bash
chown -R 1000:1000 config projetos dados
```

Faça o build:

```bash
docker compose build
```

Suba o container:

```bash
docker compose up -d
```

Acompanhe os logs:

```bash
docker logs -f qgis-web
```

Acesse no navegador:

```text
http://IP_DO_SERVIDOR:3001
```

Usuário e senha padrão definidos no `docker-compose.yml`:

```text
Usuário: admin
Senha: troque-esta-senha
```

## Upload de arquivos

A interface Selkies pode exibir uma área lateral chamada **Files** ou **Arquivos**.

Os arquivos enviados pela interface web serão salvos em:

```text
/projetos/uploads
```

No host, esse caminho corresponde a:

```text
./projetos/uploads
```

Dentro do QGIS, para abrir os arquivos enviados:

```text
Layer > Add Layer > Add Vector Layer
```

ou:

```text
Layer > Add Layer > Add Raster Layer
```

E navegue até:

```text
/projetos/uploads
```

## Volumes

| Volume local | Caminho no container | Uso                                         |
| ------------ | -------------------- | ------------------------------------------- |
| `./config`   | `/config`            | Configurações persistentes do ambiente      |
| `./projetos` | `/projetos`          | Projetos QGIS e arquivos de trabalho        |
| `./dados`    | `/dados`             | Dados de referência em modo somente leitura |

## Recomendações de segurança

Este projeto usa uma base gráfica com acesso via navegador. Por isso, recomenda-se não expor o container diretamente à internet.

Recomendações:

* usar proxy reverso com TLS;
* proteger com SSO, Keycloak, Authelia, OAuth2 Proxy ou mecanismo corporativo equivalente;
* restringir acesso por VPN ou allowlist de IPs;
* trocar a senha padrão;
* não usar `privileged: true`;
* não montar `/var/run/docker.sock`;
* não executar com `user: "1000:1000"`;
* usar `PUID` e `PGID`;
* manter `START_DOCKER=false`;
* manter `DISABLE_SUDO=true`;
* manter `DISABLE_TERMINALS=true`;
* escanear a imagem antes de publicar em ambiente corporativo.

## Publicação atrás de Nginx

Exemplo básico de proxy reverso:

```nginx
server {
    listen 443 ssl;
    server_name qgis-web.exemplo.local;

    client_max_body_size 2048M;

    location / {
        proxy_pass http://127.0.0.1:3001;

        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600;
        proxy_send_timeout 3600;
    }
}
```

## Auditoria da imagem

### Trivy

```bash
trivy image \
  --scanners vuln,secret \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  qgis-web:latest
```

### Gerar SBOM

```bash
trivy image \
  --format cyclonedx \
  --output sbom-qgis-web.cdx.json \
  qgis-web:latest
```

### Dockle

```bash
dockle qgis-web:latest
```

### Hadolint

```bash
hadolint Dockerfile
```

## Script de validação

Exemplo de `scan.sh`:

```bash
#!/bin/bash
set -e

IMAGE="qgis-web:latest"

echo "Build da imagem..."
docker build -t "$IMAGE" .

echo "Gerando SBOM..."
trivy image --format cyclonedx --output sbom.cdx.json "$IMAGE"

echo "Executando scan de vulnerabilidades..."
trivy image \
  --scanners vuln,secret \
  --severity HIGH,CRITICAL \
  --ignore-unfixed \
  --exit-code 1 \
  "$IMAGE"

echo "Analisando configuração..."
trivy config .

echo "Executando Dockle..."
dockle "$IMAGE"

echo "Validação concluída."
```

Permissão:

```bash
chmod +x scan.sh
```

Execução:

```bash
./scan.sh
```

## Troubleshooting

### Erro: `chown(...) failed: Operation not permitted`

Exemplo:

```text
chown("/var/lib/nginx/body", 33) failed (1: Operation not permitted)
s6-applyuidgid: fatal: unable to set supplementary group list: Operation not permitted
```

Causa provável: uso de `cap_drop: ALL` ou execução com permissões insuficientes.

Solução: remova do `docker-compose.yml`:

```yaml
cap_drop:
  - ALL
```

Também não use:

```yaml
user: "1000:1000"
```

As imagens LinuxServer devem iniciar como `root` para preparar permissões internas e depois ajustar o usuário via `PUID` e `PGID`.

### A área Arquivos/Files não aparece

Confirme se estas variáveis estão no compose:

```yaml
- SELKIES_UI_SIDEBAR_SHOW_FILES=true
- SELKIES_FILE_TRANSFERS=upload,download
- FILE_MANAGER_PATH=/projetos/uploads
```

Se ainda não aparecer, teste temporariamente:

```yaml
- HARDEN_DESKTOP=false
```

### Upload falha com erro 413 no Nginx

Aumente o limite no proxy reverso:

```nginx
client_max_body_size 2048M;
```

### QGIS não abre

Verifique os logs:

```bash
docker logs -f qgis-web
```

Entre no container:

```bash
docker exec -it qgis-web bash
```

Teste o binário:

```bash
qgis --version
```

### Permissão negada nos arquivos enviados

Ajuste permissões no host:

```bash
chown -R 1000:1000 projetos config dados
```

## Atualização da imagem

Para rebuildar:

```bash
docker compose down
docker compose build --no-cache
docker compose up -d
```

## Boas práticas para ambiente corporativo

Para uso interno, recomenda-se o seguinte fluxo:

```text
Imagem base LinuxServer/Selkies
        ↓
Build interno qgis-web
        ↓
Scan de vulnerabilidade
        ↓
Geração de SBOM
        ↓
Publicação em registry interno
        ↓
Deploy controlado
```

Também é recomendável fixar a imagem base por digest em vez de usar apenas a tag:

```dockerfile
FROM ghcr.io/linuxserver/baseimage-selkies@sha256:HASH_DA_IMAGEM
```

Isso evita mudanças inesperadas quando a tag remota for atualizada.

## Limitações

Este projeto não transforma o QGIS em uma aplicação web nativa.

O QGIS continua sendo uma aplicação desktop Linux, executada dentro de um container e transmitida para o navegador por meio do Selkies.

Para múltiplos usuários, recomenda-se usar um container por usuário ou por sessão, evitando compartilhamento do mesmo ambiente gráfico.

## Licença

Este projeto é apenas uma composição Docker para executar o QGIS Desktop em ambiente web.

Consulte as licenças dos projetos utilizados:

* QGIS
* LinuxServer.io
* Selkies
* Debian
* GDAL/OGR
* PROJ

