# aurora-mt7902 / bluefin-dx-mt7902

> [English](README.md) · **Português (Brasil)**

Imagens custom Universal Blue com os drivers MediaTek **MT7902** WiFi+Bluetooth pré-compilados, firmware instalado e módulos assinados para Secure Boot...

| Imagem | Base | Desktop | GHCR |
|---|---|---|---|
| `aurora-mt7902` | [`ghcr.io/ublue-os/aurora:stable`](https://github.com/ublue-os/aurora) | KDE Plasma | `ghcr.io/llawli/aurora-mt7902:latest` |
| `bluefin-dx-mt7902` | [`ghcr.io/ublue-os/bluefin-dx:stable`](https://github.com/ublue-os/bluefin) | GNOME (DX/dev tools) | `ghcr.io/llawli/bluefin-dx-mt7902:latest` |

O CI rebuilda diariamente para acompanhar bumps de kernel das bases.

## Drivers inclusos

| Componente | Branch upstream | Módulo |
|---|---|---|
| WiFi | [`hmtheboy154/mt7902@backport`](https://github.com/hmtheboy154/mt7902/tree/backport) | `mt7902e.ko` |
| Bluetooth | [`hmtheboy154/mt7902@bluetooth_backport`](https://github.com/hmtheboy154/mt7902/tree/bluetooth_backport) | `btusb_mt7902.ko` |

Os módulos in-tree `btusb` e `btmtk` estão blacklistados em `/usr/lib/modprobe.d/mt7902-blacklist.conf` (requerido pelo upstream para que o BT funcione).

Versões pinadas em [`build_files/kmod/pins.env`](build_files/kmod/pins.env). Bump via PR.

## Como instalar

### Aurora (KDE) — rebase a partir de uma instalação Aurora existente

```bash
# Passo 1 — confiar na chave pública
sudo wget -O /etc/pki/containers/aurora-mt7902.pub \
  https://raw.githubusercontent.com/LLawli/uBlue-mt7902/main/cosign.pub

# Passo 2 — registrar policy de verificação (uma vez)
sudo tee /etc/containers/registries.d/aurora-mt7902.yaml > /dev/null <<EOF
docker:
  ghcr.io/llawli/aurora-mt7902:
    use-sigstore-attachments: true
EOF

# Passo 3 — rebase
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/llawli/aurora-mt7902:latest
sudo systemctl reboot
```

### Bluefin DX (GNOME) — instalação nova

> **Atenção:** rebase direto de Aurora (KDE) para Bluefin (GNOME) **não é suportado pela uBlue**. Para usar `bluefin-dx-mt7902`, instale primeiro o Bluefin DX vanilla pela ISO oficial uBlue, depois faça o switch.

```bash
# 1) Instalar Bluefin DX vanilla pela ISO oficial:
#    https://projectbluefin.io/  (variant "Bluefin DX")

# 2) Após primeiro boot, fazer rebase
sudo bootc switch ghcr.io/llawli/bluefin-dx-mt7902:latest
sudo systemctl reboot
```

## Secure Boot

Os módulos `mt7902e.ko` e `btusb_mt7902.ko` são assinados no CI com uma MOK própria (chave pública em `signing/mt7902-signing.der`, instalada na imagem em `/etc/pki/mt7902/mt7902-signing.der`).

Para usar com Secure Boot ativo, faça o **enroll unificado** (uBlue akmods + MT7902 numa só operação, uma só senha):

```bash
ujust enroll-secure-boot-key-all
# Senha sugerida: universalblue
sudo systemctl reboot
# No MokManager (boot screen): Enroll MOK → confirme as 2 chaves listadas
# → digite a senha que você acabou de definir → reboot
```

**Validação após reboot:**

```bash
lsmod | grep -E 'mt7902e|btusb_mt7902'
modinfo mt7902e | grep -E '^(signer|sig_id):'   # MT7902 Module Signing
nmcli device status                              # WiFi up
bluetoothctl show                                # BT up
dmesg | grep -iE 'module verification failed'   # vazio
```

Se preferir não usar Secure Boot, pula o enroll — os módulos assinados também carregam em sistemas sem SB (a assinatura vira metadata extra ignorada).

## Build local (opcional)

```bash
# Aurora (default)
just build

# Bluefin DX
IMAGE_NAME=bluefin-dx-mt7902 podman build \
    --build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx:stable \
    --build-arg VARIANT=bluefin \
    --tag bluefin-dx-mt7902:latest .
```

Builds locais sem `MT7902_SIGNING_KEY_B64` definido **não assinam** os módulos — útil para teste em VM sem Secure Boot. Não use essas imagens em sistema com SB ativo.

Requer `just`, `podman`, `bootc-image-builder`. Não é necessário para uso normal — o CI publica automaticamente.

## Setup inicial da MOK do MT7902

Ver [`signing/README.md`](signing/README.md) para gerar o par de chaves uma vez e configurar o secret `MT7902_SIGNING_KEY` no GitHub.

## Licença

Apache-2.0 (mesma do template). Drivers upstream seguem suas próprias licenças (GPL-2.0).
