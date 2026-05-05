#!/usr/bin/bash
# Compila e instala btusb_mt7902.ko (Bluetooth) a partir de
# hmtheboy154/mt7902 branch bluetooth_backport.

set -ouex pipefail

KVER="$1"
SHA="$2"
src="$(mktemp -d -t mt7902-bt-XXXXXX)"

git clone --filter=blob:none --no-checkout --branch bluetooth_backport https://github.com/hmtheboy154/mt7902 "${src}"
git -C "${src}" fetch --depth 1 origin "${SHA}"
git -C "${src}" checkout "${SHA}"

make -C "${src}" KVER="${KVER}" KSRC="/lib/modules/${KVER}/build" -j"$(nproc)"
make -C "${src}" KVER="${KVER}" install
make -C "${src}" install_fw

rm -rf "${src}"
