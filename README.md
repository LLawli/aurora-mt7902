# aurora-mt7902

Imagem custom de [Aurora Linux](https://getaurora.dev/) (Universal Blue, KDE) com os drivers MediaTek **MT7902** WiFi+Bluetooth pré-compilados e firmware instalado.

A base é `ghcr.io/ublue-os/aurora:stable`. O CI rebuilda diariamente para acompanhar bumps de kernel da Aurora.

## Drivers inclusos

| Componente | Branch upstream | Módulo |
|---|---|---|
| WiFi | [`hmtheboy154/mt7902@backport`](https://github.com/hmtheboy154/mt7902/tree/backport) | `mt7902e.ko` |
| Bluetooth | [`hmtheboy154/mt7902@bluetooth_backport`](https://github.com/hmtheboy154/mt7902/tree/bluetooth_backport) | `btusb_mt7902.ko` |

Os módulos in-tree `btusb` e `btmtk` estão blacklistados em `/usr/lib/modprobe.d/mt7902-blacklist.conf` (requerido pelo upstream para que o BT funcione).

Versões pinadas em [`build_files/kmod/pins.env`](build_files/kmod/pins.env). Bump via PR.

## Como fazer rebase a partir de uma instalação Aurora existente

```bash
# Passo 1 — confiar na chave pública
sudo wget -O /etc/pki/containers/aurora-mt7902.pub \
  https://raw.githubusercontent.com/LLawli/aurora-mt7902/main/cosign.pub

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

## Verificação após reboot

```bash
# Módulos carregados
lsmod | grep -E 'mt7902e|btusb_mt7902'

# WiFi up
nmcli device status

# BT up
bluetoothctl show
```

## Build local (opcional)

```bash
just build
just build-qcow2   # gera VM image para teste
```

Requer `just`, `podman`, `bootc-image-builder`. Não é necessário para uso normal — o CI publica automaticamente.

## Licença

Apache-2.0 (mesma do template). Drivers upstream seguem suas próprias licenças (GPL-2.0).
