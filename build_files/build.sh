#!/usr/bin/bash
# Orquestrador de build da imagem aurora-mt7902.
# Compila os módulos out-of-tree mt7902e (WiFi) e btusb_mt7902 (BT) contra o
# kernel exato presente na imagem base Aurora, instala firmware e blacklista
# os módulos in-tree conflitantes.

set -ouex pipefail

source /ctx/kmod/pins.env

KVER="$(rpm -q kernel-core --queryformat='%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -1)"
echo ">>> Target kernel: ${KVER}"

# Build deps. kernel-devel pinado à versão exata do kernel-core da imagem base.
# Removidos no fim do mesmo RUN para não inflar a imagem.
dnf5 install -y \
    "kernel-devel-${KVER}" \
    gcc \
    make \
    git-core \
    findutils \
    kmod \
    diffutils \
    patch

# Sanity: kernel-devel precisa apontar para o KVER detectado.
test -d "/lib/modules/${KVER}/build"

/ctx/kmod/build-mt7902-wifi.sh "${KVER}" "${WIFI_SHA}"
/ctx/kmod/build-mt7902-bt.sh "${KVER}" "${BT_SHA}"

# Blacklist obrigatório: README do upstream do bluetooth_backport diz que
# btusb e btmtk in-tree precisam estar fora para o btusb_mt7902 carregar.
install -Dm644 /ctx/kmod/modprobe-blacklist.conf /usr/lib/modprobe.d/mt7902-blacklist.conf

depmod -a "${KVER}"

echo ">>> Validando módulos compilados:"
for modname in mt7902e btusb_mt7902; do
    ko=$(find "/lib/modules/${KVER}" -name "${modname}.ko*" -print -quit)
    test -n "${ko}" || { echo "FALHA: ${modname}.ko não encontrado em /lib/modules/${KVER}"; exit 1; }
    modinfo "${ko}" | grep -E "^vermagic:" | grep -qF "${KVER}"
    echo "  OK: ${ko}"
done

# Cleanup CIRÚRGICO. NÃO usar `dnf5 autoremove` num build derivado de imagem
# ublue completa — ele classifica pacotes do KDE/Plasma (Breeze, plasma-workspace,
# kf6-*, qt6-*) como "weakdeps órfãs" e os remove, deixando a imagem com SDDM
# em tema padrão Fedora e desktop quebrado. Removemos APENAS o que instalamos.
#
# Também reconciliamos a SELinux policy store antes do rm -rf, senão o
# ostree-finalize-staged.service falha em "Finalizing SELinux policy: failed
# to run semodule" e o rebase é revertido.
dnf5 remove -y \
    "kernel-devel-${KVER}" \
    gcc \
    make \
    git-core \
    diffutils \
    patch

# Reconcilia store SELinux e garante policycoreutils presente
dnf5 install -y policycoreutils selinux-policy selinux-policy-targeted libsemanage
semodule -B
restorecon -RF /usr/lib/modules /usr/lib/firmware /usr/lib/modprobe.d || true

dnf5 clean all
# Mantém /etc/selinux, /usr/share/selinux, /var/lib/selinux intactos.
rm -rf /var/cache/dnf /var/tmp/* /usr/src/kernels/* /tmp/mt7902-*

# Sanity final: confirma que pacotes essenciais do desktop NÃO foram removidos
for pkg in plasma-workspace plasma-breeze sddm-breeze policycoreutils NetworkManager; do
    rpm -q "${pkg}" >/dev/null || { echo "FALHA: ${pkg} ausente — build comprometeu desktop"; exit 1; }
done
