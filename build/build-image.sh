#!/bin/bash
# Construit l'image Syntax OS (Raspberry Pi 5 / 4 / 400 / Zero 2 W, 64 bits) à partir de
# l'image officielle Raspberry Pi OS Desktop arm64.
# À lancer en root sur une machine Linux arm64 (ou x86_64 avec qemu-user-static + binfmt).
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORK:-$REPO/work}"
OUT="${OUT:-$REPO/out}"
VERSION="${VERSION:-0.1.0}"
BASE_URL="${BASE_URL:-https://downloads.raspberrypi.com/raspios_arm64_latest}"
GROW="${GROW:-6G}"
MARGIN_MB="${MARGIN_MB:-400}"
IMG="$WORK/syntax-os.img"
MNT="$WORK/mnt"
LOOP=""

[ "$(id -u)" -eq 0 ] || { echo "À lancer en root (sudo)." >&2; exit 1; }
for tool in curl xz losetup sfdisk parted e2fsck resize2fs rsvg-convert file; do
    command -v "$tool" >/dev/null || { echo "Outil manquant : $tool" >&2; exit 1; }
done

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

unmount_all() {
    for d in dev/pts dev proc sys run tmp/syntax-build boot/firmware ""; do
        mountpoint -q "$MNT/$d" && umount -R "$MNT/$d" || true
    done
}
cleanup() {
    set +e
    unmount_all
    [ -n "$LOOP" ] && losetup -d "$LOOP" 2>/dev/null
}
trap cleanup EXIT

mount_image() {
    LOOP="$(losetup -fP --show "$IMG")"
    for _ in 1 2 3 4 5; do [ -b "${LOOP}p2" ] && break; sleep 1; partprobe "$LOOP" || true; done
    mount "${LOOP}p2" "$MNT"
    mount "${LOOP}p1" "$MNT/boot/firmware"
}
detach_image() {
    unmount_all
    sync
    losetup -d "$LOOP"
    LOOP=""
}

mkdir -p "$WORK" "$OUT" "$MNT"

step "Téléchargement de l'image de base"
if [ ! -f "$WORK/base.img.xz" ]; then
    curl -fL --retry 5 --retry-delay 5 -o "$WORK/base.img.xz.part" -w 'Source : %{url_effective}\n' "$BASE_URL"
    mv "$WORK/base.img.xz.part" "$WORK/base.img.xz"
fi
xz -dc -T0 "$WORK/base.img.xz" > "$IMG"

step "Agrandissement de la partition système (+$GROW)"
truncate -s "+$GROW" "$IMG"
parted -s "$IMG" resizepart 2 100%
LOOP="$(losetup -fP --show "$IMG")"
sleep 1
e2fsck -fy "${LOOP}p2" || [ $? -le 1 ]
resize2fs "${LOOP}p2"
losetup -d "$LOOP"; LOOP=""

step "Montage"
mount_image
SPLASH_SIZE="$(file "$MNT/usr/share/plymouth/themes/pix/splash.png" | grep -oE '[0-9]+ x [0-9]+' | head -1 || true)"
SPLASH_W="${SPLASH_SIZE%% x *}"; SPLASH_H="${SPLASH_SIZE##* x }"
echo "Écran de démarrage d'origine : ${SPLASH_SIZE:-inconnu}"

step "Préparation des fichiers Syntax OS"
STAGE="$WORK/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$REPO/system" "$REPO/rootfs" "$REPO/boot" "$REPO/build/chroot-setup.sh" "$STAGE/"
rsvg-convert -w 3840 -h 2160 "$REPO/branding/wallpaper.svg" -o "$STAGE/wallpaper.png"
rsvg-convert -w "${SPLASH_W:-1920}" -h "${SPLASH_H:-1080}" -b black "$REPO/branding/splash.svg" -o "$STAGE/splash.png"
rsvg-convert -w 256 -h 256 "$REPO/system/portal/static/logo.svg" -o "$STAGE/logo.png"
echo "$VERSION" > "$STAGE/version"

step "Personnalisation dans le chroot"
mkdir -p "$MNT/tmp/syntax-build"
mount --bind "$STAGE" "$MNT/tmp/syntax-build"
mount -t proc proc "$MNT/proc"
mount -t sysfs sys "$MNT/sys"
mount --bind /dev "$MNT/dev"
mount --bind /dev/pts "$MNT/dev/pts"
mount -t tmpfs tmpfs "$MNT/run"
mv "$MNT/etc/resolv.conf" "$MNT/etc/resolv.conf.syntax-orig" 2>/dev/null || true
cat /etc/resolv.conf > "$MNT/etc/resolv.conf"
chroot "$MNT" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    VERSION="$VERSION" /bin/bash /tmp/syntax-build/chroot-setup.sh
umount "$MNT/tmp/syntax-build"
find "$MNT/tmp" -mindepth 1 -delete 2>/dev/null || true
rm -f "$MNT/etc/resolv.conf"
mv "$MNT/etc/resolv.conf.syntax-orig" "$MNT/etc/resolv.conf" 2>/dev/null || true

step "Fichiers de la partition de démarrage"
cp "$STAGE/boot/syntax.conf" "$MNT/boot/firmware/syntax.conf"
cp "$MNT/usr/lib/syntax/userconf.txt" "$MNT/boot/firmware/userconf.txt"
rm -f "$MNT/usr/lib/syntax/userconf.txt"
printf 'Syntax OS %s\n' "$VERSION" > "$MNT/boot/firmware/issue.txt"
cat "$MNT/boot/firmware/cmdline.txt"
ls -la "$MNT/boot/firmware" | grep -E 'initramfs|kernel|syntax|userconf|cmdline'
df -h "$MNT" "$MNT/boot/firmware"

step "Réduction de l'image"
START="$(sfdisk -d "$IMG" | awk '/img2/ {gsub(",",""); for(i=1;i<=NF;i++) if($i=="start=") print $(i+1)}')"
detach_image
LOOP="$(losetup -fP --show "$IMG")"; sleep 1
e2fsck -fy "${LOOP}p2" || [ $? -le 1 ]
resize2fs -M "${LOOP}p2"
BLOCKS="$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk -F: '/^Block count/ {gsub(" ","",$2); print $2}')"
BSIZE="$(dumpe2fs -h "${LOOP}p2" 2>/dev/null | awk -F: '/^Block size/ {gsub(" ","",$2); print $2}')"
NEW_BLOCKS=$(( BLOCKS + MARGIN_MB * 1024 * 1024 / BSIZE ))
resize2fs "${LOOP}p2" "$NEW_BLOCKS"
e2fsck -fy "${LOOP}p2" || [ $? -le 1 ]
losetup -d "$LOOP"; LOOP=""
SECTORS=$(( NEW_BLOCKS * BSIZE / 512 ))
echo ",${SECTORS}" | sfdisk --no-reread -N 2 "$IMG"
truncate -s $(( (START + SECTORS) * 512 )) "$IMG"

step "Mise à zéro de l'espace libre (meilleure compression) et vérification"
mount_image
dd if=/dev/zero of="$MNT/.zero" bs=4M status=none 2>/dev/null || true
rm -f "$MNT/.zero"
grep -q "Syntax OS" "$MNT/etc/os-release"
test -x "$MNT/usr/lib/syntax/portal/server.py"
test -f "$MNT/boot/firmware/kernel_2712.img"   # noyau du Raspberry Pi 5
test -f "$MNT/boot/firmware/bcm2712-rpi-5-b.dtb"
test -s "$MNT/boot/firmware/userconf.txt"
grep -q "PARTUUID=$(sfdisk -d "$IMG" | awk '/label-id/ {sub("0x","",$2); print $2}')-02" "$MNT/boot/firmware/cmdline.txt"
df -h "$MNT"
detach_image
sfdisk -d "$IMG"

step "Compression"
NAME="syntax-os-${VERSION}-arm64"
mv "$IMG" "$OUT/$NAME.img"
( cd "$OUT" && rm -f "$NAME.img.xz" && xz -T0 -8 "$NAME.img" && sha256sum "$NAME.img.xz" > "$NAME.img.xz.sha256" && ls -lh )
step "Image prête : $OUT/$NAME.img.xz"
