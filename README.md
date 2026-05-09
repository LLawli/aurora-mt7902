# aurora-mt7902 / bluefin-dx-mt7902

> **English** · [Português (Brasil)](README-ptBR.md)

Custom Universal Blue images with the MediaTek **MT7902** WiFi+Bluetooth drivers prebuilt, firmware installed, and modules signed for Secure Boot.

| Image | Base | Desktop | GHCR |
|---|---|---|---|
| `aurora-mt7902` | [`ghcr.io/ublue-os/aurora:stable`](https://github.com/ublue-os/aurora) | KDE Plasma | `ghcr.io/llawli/aurora-mt7902:latest` |
| `bluefin-dx-mt7902` | [`ghcr.io/ublue-os/bluefin-dx:stable`](https://github.com/ublue-os/bluefin) | GNOME (DX/dev tools) | `ghcr.io/llawli/bluefin-dx-mt7902:latest` |

CI rebuilds daily to track kernel bumps from the upstream bases.

## Bundled drivers

| Component | Upstream branch | Module |
|---|---|---|
| WiFi | [`hmtheboy154/mt7902@backport`](https://github.com/hmtheboy154/mt7902/tree/backport) | `mt7902e.ko` |
| Bluetooth | [`hmtheboy154/mt7902@bluetooth_backport`](https://github.com/hmtheboy154/mt7902/tree/bluetooth_backport) | `btusb_mt7902.ko` |

The in-tree `btusb` and `btmtk` modules are blacklisted in `/usr/lib/modprobe.d/mt7902-blacklist.conf` (required by upstream for Bluetooth to work).

Pinned versions live in [`build_files/kmod/pins.env`](build_files/kmod/pins.env). Bump via PR.

## How to install

### Aurora (KDE) — rebase from an existing Aurora install

```bash
# Step 1 — trust the public key
sudo wget -O /etc/pki/containers/aurora-mt7902.pub \
  https://raw.githubusercontent.com/LLawli/aurora-mt7902/main/cosign.pub

# Step 2 — register the verification policy (one-time)
sudo tee /etc/containers/registries.d/aurora-mt7902.yaml > /dev/null <<EOF
docker:
  ghcr.io/llawli/aurora-mt7902:
    use-sigstore-attachments: true
EOF

# Step 3 — rebase
sudo rpm-ostree rebase ostree-image-signed:docker://ghcr.io/llawli/aurora-mt7902:latest
sudo systemctl reboot
```

### Bluefin DX (GNOME) — fresh install

> **Note:** rebasing directly from Aurora (KDE) to Bluefin (GNOME) is **not supported by uBlue**. To use `bluefin-dx-mt7902`, install Bluefin DX vanilla from the official uBlue ISO first, then switch.

```bash
# 1) Install Bluefin DX vanilla from the official ISO:
#    https://projectbluefin.io/  (variant "Bluefin DX")

# 2) After first boot, rebase
sudo bootc switch ghcr.io/llawli/bluefin-dx-mt7902:latest
sudo systemctl reboot
```

## Secure Boot

The `mt7902e.ko` and `btusb_mt7902.ko` modules are signed in CI with a project-owned MOK (public key in `signing/mt7902-signing.der`, installed in the image at `/etc/pki/mt7902/mt7902-signing.der`).

To use with Secure Boot enabled, run the **unified enroll** (uBlue akmods + MT7902 in a single operation, one password):

```bash
ujust enroll-secure-boot-key-all
# Suggested password: universalblue
sudo systemctl reboot
# In MokManager (boot screen): Enroll MOK → confirm both listed keys
# → enter the password you just set → reboot
```

**Verify after reboot:**

```bash
lsmod | grep -E 'mt7902e|btusb_mt7902'
modinfo mt7902e | grep -E '^(signer|sig_id):'   # MT7902 Module Signing
nmcli device status                              # WiFi up
bluetoothctl show                                # BT up
dmesg | grep -iE 'module verification failed'   # empty
```

If you'd rather skip Secure Boot, omit the enroll — signed modules also load on systems without SB (the signature becomes ignored extra metadata).

## Local build (optional)

```bash
# Aurora (default)
just build

# Bluefin DX
IMAGE_NAME=bluefin-dx-mt7902 podman build \
    --build-arg BASE_IMAGE=ghcr.io/ublue-os/bluefin-dx:stable \
    --build-arg VARIANT=bluefin \
    --tag bluefin-dx-mt7902:latest .
```

Local builds without `MT7902_SIGNING_KEY_B64` set **do not sign** the modules — useful for VM testing without Secure Boot. Don't use those images on a system with SB enabled.

Requires `just`, `podman`, `bootc-image-builder`. Not needed for normal use — CI publishes automatically.

## Initial MT7902 MOK setup

See [`signing/README.md`](signing/README.md) to generate the keypair once and configure the `MT7902_SIGNING_KEY` secret on GitHub.

## License

Apache-2.0 (same as the template). Upstream drivers follow their own licenses (GPL-2.0).
