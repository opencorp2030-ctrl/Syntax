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
GROW="${GROW:-8G}"
MARGIN_MB="${MARGIN_MB:-1200}"
IMG="$WORK/syntax-os.img"
MNT="$WORK/mnt"
LOOP=""

[ "$(id -u)" -eq 0 ] || { echo "À lancer en root (sudo)." >&2; exit 1; }
for tool in curl xz losetup sfdisk parted e2fsck resize2fs rsvg-convert file; do
    command -v "$tool" >/dev/null || { echo "Outil manquant : $tool" >&2; exit 1; }
done

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

unmount_all() {
    for d in dev/shm dev/pts dev proc sys run tmp/syntax-build boot/firmware ""; do
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
step "Préparation des fichiers Syntax OS"
STAGE="$WORK/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
"$REPO/build/make-assets.sh" "$REPO" "$STAGE"
echo "$VERSION" > "$STAGE/version"

step "Récupération des applications tierces (poly, SatisCode, SatisDocs, SatisReader, police, curseur)"
"$REPO/build/fetch-apps.sh" "$STAGE"

step "Personnalisation dans le chroot"
mkdir -p "$MNT/tmp/syntax-build"
mount --bind "$STAGE" "$MNT/tmp/syntax-build"
mount -t proc proc "$MNT/proc"
mount -t sysfs sys "$MNT/sys"
mount --bind /dev "$MNT/dev"
mount --bind /dev/pts "$MNT/dev/pts"
mount -t tmpfs tmpfs "$MNT/dev/shm"
mount -t tmpfs tmpfs "$MNT/run"
mv "$MNT/etc/resolv.conf" "$MNT/etc/resolv.conf.syntax-orig" 2>/dev/null || true
cat /etc/resolv.conf > "$MNT/etc/resolv.conf"
chroot "$MNT" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    VERSION="$VERSION" /bin/bash /tmp/syntax-build/chroot-setup.sh
step "Capture du bureau de l'image (rendu sans écran)"
cp "$REPO/ci/headless-shot.sh" "$MNT/tmp/headless-shot.sh"
HOOK='/usr/share/syntax/desktop/bin/launcher & sleep 4; grim /tmp/bureau-lanceur.png; pkill -x fuzzel; sleep 1; pcmanfm >/dev/null 2>&1 & sleep 3; x-terminal-emulator >/dev/null 2>&1 & sleep 7; grim /tmp/bureau-fenetres.png'
chroot "$MNT" /usr/bin/env -i HOME=/root PATH=/usr/sbin:/usr/bin:/sbin:/bin SHOT_HOOK="$HOOK" /bin/bash -c '
    useradd -u 59123 -m -s /bin/bash syntaxshot && bash /tmp/headless-shot.sh syntaxshot /tmp/bureau.png 20
    pkill -u syntaxshot; sleep 1; userdel -r syntaxshot 2>/dev/null; rm -rf /run/user/* /home/syntaxshot' || echo "capture du bureau impossible"
cp "$MNT"/tmp/bureau*.png "$OUT/" 2>/dev/null || true
umount "$MNT/tmp/syntax-build"
find "$MNT/tmp" -mindepth 1 -delete 2>/dev/null || true
rm -f "$MNT/etc/resolv.conf"
mv "$MNT/etc/resolv.conf.syntax-orig" "$MNT/etc/resolv.conf" 2>/dev/null || true

step "Fichiers de la partition de démarrage"
cp "$STAGE/boot/syntax.conf" "$MNT/boot/firmware/syntax.conf"
cp "$MNT/usr/lib/syntax/userconf.txt" "$MNT/boot/firmware/userconf.txt"
rm -f "$MNT/usr/lib/syntax/userconf.txt"
printf 'Syntax OS %s\n' "$VERSION" > "$MNT/boot/firmware/issue.txt"
CMD="$(tr -d '\n' < "$MNT/boot/firmware/cmdline.txt")"
for arg in logo.nologo vt.global_cursor_default=0; do
    case " $CMD " in *" $arg "*) ;; *) CMD="$CMD $arg" ;; esac
done
echo "$CMD" > "$MNT/boot/firmware/cmdline.txt"
grep -q '^disable_splash=1' "$MNT/boot/firmware/config.txt" || printf '\n# Syntax OS : pas d ecran arc-en-ciel au demarrage\ndisable_splash=1\n' >> "$MNT/boot/firmware/config.txt"
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
