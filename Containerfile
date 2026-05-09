# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /
COPY signing /signing
COPY system_files /system_files

# Base Image — parametrizada para permitir builds tanto Aurora (KDE) quanto
# Bluefin DX (GNOME) a partir do mesmo Containerfile. Defaults preservam o
# comportamento original do repo (build sem args = aurora-mt7902).
ARG BASE_IMAGE=ghcr.io/ublue-os/aurora:stable
ARG VARIANT=aurora
FROM ${BASE_IMAGE}

# Re-declarar ARGs após FROM para escopo do estágio final.
# MT7902_SIGNING_KEY_B64 é a privada MOK em base64 (vem do secret no GH Actions).
# Se vazia, build.sh pula assinatura — útil para testes locais sem Secure Boot.
ARG VARIANT
ARG MT7902_SIGNING_KEY_B64=""
ENV VARIANT=${VARIANT}

### [IM]MUTABLE /opt
## Some bootable images, like Fedora, have /opt symlinked to /var/opt, in order to
## make it mutable/writable for users. However, some packages write files to this directory,
## thus its contents might be wiped out when bootc deploys an image, making it troublesome for
## some packages. Eg, google-chrome, docker-desktop.
##
## Uncomment the following line if one desires to make /opt immutable and be able to be used
## by the package manager.

# RUN rm /opt && mkdir /opt

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.
##
## MT7902_SIGNING_KEY_B64 é passada inline (não via ENV) para não persistir como
## variável de ambiente nas camadas finais; o /tmp é tmpfs, então arquivos
## temporários da assinatura também não sobrevivem ao RUN.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    MT7902_SIGNING_KEY_B64="${MT7902_SIGNING_KEY_B64}" /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
