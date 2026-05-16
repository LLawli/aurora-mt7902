#!/usr/bin/bash
# Orquestrador de build das imagens aurora-mt7902 e bluefin-dx-mt7902.
# Compila os módulos out-of-tree mt7902e (WiFi) e btusb_mt7902 (BT) contra o
# kernel exato presente na imagem base, instala firmware, blacklista os módulos
# in-tree conflitantes e assina os módulos com a MOK do MT7902 (se disponível).
#
# VARIANT controla apenas o sanity check final (pacotes do desktop a verificar).
# Toda a lógica do kmod é idêntica entre Aurora (KDE) e Bluefin (GNOME).

set -ouex pipefail

source /ctx/kmod/pins.env

KVER="$(rpm -q kernel-core --queryformat='%{VERSION}-%{RELEASE}.%{ARCH}\n' | head -1)"
echo ">>> Target kernel: ${KVER}"
echo ">>> Variant: ${VARIANT:-aurora}"

# Copia tree de system_files para / (drop-in justfile do enroll MOK, etc).
if [[ -d /ctx/system_files ]]; then
    cp -r /ctx/system_files/. /
fi

# Build deps. kernel-devel pinado à versão exata do kernel-core da imagem base.
# xz/zstd: necessários se algum módulo .ko estiver comprimido (não é o caso
# atual do hmtheboy154/mt7902 mas deixamos disponível para robustez).
# Removidos no fim do mesmo RUN para não inflar a imagem.
dnf5 install -y \
    "kernel-devel-${KVER}" \
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

# Aviso early se o caminho da chave uBlue não existir na imagem base — o ujust
# enroll-secure-boot-key-all assume esse path e quebra silenciosamente sem isso.
# Não falha o build (usuário pode usar fallback enroll-mt7902-key), mas registra.
if [[ ! -f /etc/pki/akmods/certs/akmods-ublue.der ]]; then
    echo "AVISO: /etc/pki/akmods/certs/akmods-ublue.der ausente na imagem base."
    echo "       'ujust enroll-secure-boot-key-all' falhará — use 'enroll-mt7902-key'."
fi

/ctx/kmod/build-mt7902-wifi.sh "${KVER}" "${WIFI_SHA}"
/ctx/kmod/build-mt7902-bt.sh "${KVER}" "${BT_SHA}"

# Blacklist obrigatório: README do upstream do bluetooth_backport diz que
# btusb e btmtk in-tree precisam estar fora para o btusb_mt7902 carregar.
install -Dm644 /ctx/kmod/modprobe-blacklist.conf /usr/lib/modprobe.d/mt7902-blacklist.conf

# Assinatura dos módulos MT7902 com a MOK do projeto.
# Ordem: assinar ANTES de depmod (depmod gera modules.dep com hashes/paths
# atuais; sign-file só altera o conteúdo do .ko, então depmod precisa rodar
# depois para o initramfs/modprobe ver os módulos assinados).
if [[ ! -f /ctx/signing/mt7902-signing.der ]]; then
    echo "AVISO: /ctx/signing/mt7902-signing.der ausente — assinatura desabilitada."
    echo "       Gere par de chaves e commite a pública (ver signing/README.md)."
elif [[ -z "${MT7902_SIGNING_KEY_B64:-}" ]]; then
    echo "AVISO: MT7902_SIGNING_KEY_B64 não definida — módulos NÃO serão assinados."
    echo "       Build local OK; não use esta imagem com Secure Boot ativo."
else
    PRIV=$(mktemp -p /tmp mt7902-priv.XXXXXX)
    trap 'shred -u "${PRIV}" 2>/dev/null || rm -f "${PRIV}"' EXIT
    echo "${MT7902_SIGNING_KEY_B64}" | base64 -d > "${PRIV}"
    chmod 600 "${PRIV}"

    PUB=/ctx/signing/mt7902-signing.der
    SIGN_FILE="/usr/src/kernels/${KVER}/scripts/sign-file"
    test -x "${SIGN_FILE}"

    for modname in mt7902e btusb_mt7902; do
        ko=$(find "/lib/modules/${KVER}" -name "${modname}.ko*" -print -quit)
        test -n "${ko}"
        case "${ko}" in
            *.ko.xz)  xz -d "${ko}";  ko="${ko%.xz}"  ;;
            *.ko.zst) zstd -d --rm "${ko}"; ko="${ko%.zst}" ;;
        esac
        "${SIGN_FILE}" sha256 "${PRIV}" "${PUB}" "${ko}"
        modinfo "${ko}" | grep -qE "^signer:.*MT7902" \
            || { echo "FALHA: ${ko} não ficou assinado"; exit 1; }
        echo "  Assinado: ${ko}"
    done
fi

# Instala chave pública na imagem para o ujust enroll. Independente de
# assinatura ter rolado: se a pública existe, instalamos para que a receita
# `enroll-secure-boot-key-all` funcione (usuário pode regenerar e reassinar
# em build futuro sem mudar a chave que já enrollou no dispositivo).
if [[ -f /ctx/signing/mt7902-signing.der ]]; then
    install -Dm644 /ctx/signing/mt7902-signing.der /etc/pki/mt7902/mt7902-signing.der
fi

depmod -a "${KVER}"

echo ">>> Validando módulos compilados:"
for modname in mt7902e btusb_mt7902; do
    ko=$(find "/lib/modules/${KVER}" -name "${modname}.ko*" -print -quit)
    test -n "${ko}" || { echo "FALHA: ${modname}.ko não encontrado em /lib/modules/${KVER}"; exit 1; }
    modinfo "${ko}" | grep -E "^vermagic:" | grep -qF "${KVER}"
    echo "  OK: ${ko}"
done

# Cleanup CIRÚRGICO. NÃO usar `dnf5 autoremove` num build derivado de imagem
# ublue completa — ele classifica pacotes do KDE/Plasma (Aurora) ou do GNOME
# (Bluefin) como "weakdeps órfãs" e os remove, deixando o desktop quebrado.
# Removemos APENAS o que instalamos.
#
# Também reconciliamos a SELinux policy store antes do rm -rf, senão o
# ostree-finalize-staged.service falha em "Finalizing SELinux policy: failed
# to run semodule" e o rebase é revertido.
# Removemos APENAS kernel-devel (~200MB, específico da versão e sem reverse-deps).
# gcc/make/git-core/diffutils/patch/xz/zstd são deps reversas de pacotes do
# desktop (KDE no Aurora, GNOME/dev-tools no Bluefin DX); tentar removê-los
# em cascata leva o desktop junto.
dnf5 remove -y "kernel-devel-${KVER}"

# Reconcilia store SELinux e garante policycoreutils presente
dnf5 install -y policycoreutils selinux-policy selinux-policy-targeted libsemanage
semodule -B
restorecon -RF /usr/lib/modules /usr/lib/firmware /usr/lib/modprobe.d /etc/pki/mt7902 || true

dnf5 clean all
# Mantém /etc/selinux, /usr/share/selinux, /var/lib/selinux intactos.
rm -rf /var/cache/dnf /var/tmp/* /usr/src/kernels/* /tmp/mt7902-*

# Sanity final por variant: confirma que pacotes essenciais do desktop NÃO
# foram removidos. Lista varia entre Aurora (KDE) e Bluefin (GNOME).
case "${VARIANT:-aurora}" in
    aurora)  DESKTOP_PKGS=(plasma-workspace plasma-breeze plasma-login-manager) ;;
    bluefin) DESKTOP_PKGS=(gnome-shell gdm) ;;
    *) echo "FALHA: VARIANT desconhecido: ${VARIANT}"; exit 1 ;;
esac
for pkg in "${DESKTOP_PKGS[@]}" policycoreutils NetworkManager; do
    rpm -q "${pkg}" >/dev/null || { echo "FALHA: ${pkg} ausente — build comprometeu desktop"; exit 1; }
done
