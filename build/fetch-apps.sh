#!/bin/bash
# Récupère et construit, sur la machine qui fabrique l'image (pas dans le chroot Pi), les
# applications tierces embarquées dans Syntax OS : poly (gestionnaire de paquets), SatisCode
# (éditeur), SatisDocs (visionneuse de documentation) et SatisReader (lecteur de flux).
# Usage : fetch-apps.sh <stage>
set -euo pipefail
STAGE="$1"
APPS="$STAGE/apps"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$APPS"
step() { printf '\n\033[1;35m~~> %s\033[0m\n' "$*"; }

clone() { # clone <url> <dossier> [ref]
    GIT_LFS_SKIP_SMUDGE=1 git clone --depth 1 ${3:+-b "$3"} "$1" "$2"
}

step "poly (gestionnaire de paquets en ligne de commande)"
clone https://github.com/opencorp2030-ctrl/poly "$WORK/poly"
( cd "$WORK/poly"
  VERSION="$(git rev-parse --short HEAD)"
  CGO_ENABLED=0 go build -ldflags "-s -w -X poly/cmd.Version=syntax-$VERSION" -o "$APPS/poly" . )
echo "-> $APPS/poly ($("$APPS/poly" --version 2>&1 || true))"

step "SatisCode (éditeur de code)"
clone https://github.com/gtref/satiscode "$WORK/satiscode"
( cd "$WORK/satiscode"
  npm ci --no-audit --no-fund --progress=false
  npm run build
  npx electron-builder --linux dir --arm64 )
mkdir -p "$APPS/satiscode"
cp -a "$WORK/satiscode/dist/linux-arm64-unpacked/." "$APPS/satiscode/"
cp "$WORK/satiscode/assets/satiacode.png" "$APPS/satiscode.png.src"

step "SatisDocs (visionneuse de documentation)"
clone https://github.com/gtref/satisdocs "$WORK/satisdocs"
( cd "$WORK/satisdocs"
  npm ci --no-audit --no-fund --progress=false
  npx electron-builder --linux dir --arm64 )
mkdir -p "$APPS/satisdocs"
cp -a "$WORK/satisdocs/dist/linux-arm64-unpacked/." "$APPS/satisdocs/"

step "SatisReader (lecteur de flux)"
clone https://github.com/SatisCorprperation/satisreader "$WORK/satisreader"
mkdir -p "$APPS/satisreader"
cp -a "$WORK/satisreader/." "$APPS/satisreader/"
rm -rf "$APPS/satisreader/.git"

step "Police Space Grotesk (titres et logo)"
mkdir -p "$APPS/fonts"
for f in SpaceGrotesk; do
    curl -fsSL -o "$APPS/fonts/$f.ttf" \
        "https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf"
done
curl -fsSL -o "$APPS/fonts/SpaceGrotesk-OFL.txt" \
    "https://raw.githubusercontent.com/google/fonts/main/ofl/spacegrotesk/OFL.txt" || true

step "Curseur Bibata"
curl -fsSL -o "$WORK/bibata.tar.xz" \
    "https://github.com/ful1e5/Bibata_Cursor/releases/download/v2.0.7/Bibata-Modern-Classic.tar.xz"
mkdir -p "$APPS/cursor"
tar xf "$WORK/bibata.tar.xz" -C "$APPS/cursor"

step "papirus-folders (recoloration des dossiers)"
curl -fsSL -o "$APPS/papirus-folders" \
    "https://raw.githubusercontent.com/PapirusDevelopmentTeam/papirus-folders/master/papirus-folders"
chmod +x "$APPS/papirus-folders"

step "Résumé"
du -sh "$APPS"/* 2>/dev/null
