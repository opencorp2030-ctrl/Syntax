#!/bin/bash
# Rassemble dans <stage> tout ce que les scripts exécutés dans l'image utilisent.
# Usage : make-assets.sh <dépôt> <stage>
set -euo pipefail
REPO="$1"; STAGE="$2"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$REPO/system" "$REPO/rootfs" "$REPO/boot" "$REPO/desktop" "$STAGE/"
cp "$REPO/build/chroot-setup.sh" "$REPO/build/desktop-setup.sh" "$STAGE/"
cp "$REPO/branding/wallpaper.jpg" "$STAGE/wallpaper.jpg"
LOGO="$REPO/system/portal/static/logo.svg"
rsvg-convert -w 1920 -h 1080 -b black "$REPO/branding/splash.svg" -o "$STAGE/splash.png"
rsvg-convert -w 256 -h 256 "$LOGO" -o "$STAGE/logo.png"
for s in 16 24 32 48 64 96; do rsvg-convert -w "$s" -h "$s" "$LOGO" -o "$STAGE/logo-$s.png"; done
