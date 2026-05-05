#!/usr/bin/bash
# Orquestrador de build da imagem aurora-mt7902.
# Compila os módulos out-of-tree mt7902e (WiFi) e btusb_mt7902 (BT) contra o
# kernel exato presente na imagem base Aurora, instala firmware e blacklista
# os módulos in-tree conflitantes.

set -ouex pipefail

source /ctx/kmod/pins.env

KVER="$(rpm -q kernel-core --queryformat='%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -1)"
echo ">>> Target kernel: ${KVER}"

# Build deps. Removidos no fim do mesmo RUN para não inflar a imagem.
dnf5 install -y \
    "kernel-devel-matching" \
    gcc \
    make \
    git-core \
    findutils \
    kmod \
    diffutils \
    patch \
    xz \
    zstd

# Sanity: kernel-devel precisa apontar para o KVER detectado.
test -d "/lib/modules/${KVER}/build"

/ctx/kmod/build-mt7902-wifi.sh "${KVER}" "${WIFI_SHA}"
/ctx/kmod/build-mt7902-bt.sh "${KVER}" "${BT_SHA}"

# Blacklist obrigatório: README do upstream do bluetooth_backport diz que
# btusb e btmtk in-tree precisam estar fora para o btusb_mt7902 carregar.
install -Dm644 /ctx/kmod/modprobe-blacklist.conf /usr/lib/modprobe.d/mt7902-blacklist.conf

depmod -a "${KVER}"

echo ">>> Validando módulos compilados:"
for ko in /lib/modules/${KVER}/extra/mt7902e.ko* /lib/modules/${KVER}/extra/btusb_mt7902.ko*; do
    test -f "${ko}"
    modinfo "${ko}" | grep -E "^vermagic:" | grep -qF "${KVER}"
    echo "  OK: ${ko}"
done

# Cleanup agressivo na MESMA layer.
dnf5 remove -y \
    kernel-devel-matching \
    gcc \
    make \
    git-core \
    diffutils \
    patch
dnf5 autoremove -y
dnf5 clean all
rm -rf /var/cache/dnf /var/lib/dnf/history.* /var/tmp/* /usr/src/kernels/* /tmp/mt7902-*
