#!/bin/bash
# Exécuté dans le chroot de l'image : transforme Raspberry Pi OS en Syntax OS.
set -euo pipefail
B=/tmp/syntax-build
VERSION="${VERSION:-0.1.0}"
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
step() { printf '\n\033[1;36m--> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mAVERTISSEMENT : %s\033[0m\n' "$*"; }

# Aucun service ne doit démarrer pendant la construction.
printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d; chmod +x /usr/sbin/policy-rc.d

step "Base : $(. /etc/os-release; echo "$PRETTY_NAME") — $(cat /etc/rpi-issue | head -1)"
CODENAME="$(. /etc/os-release; echo "$VERSION_CODENAME")"

step "Paquets"
apt-get update
apt-get install -y --no-install-recommends \
    python3-aiohttp wayvnc curl ca-certificates git fonts-inter avahi-daemon util-linux
for pkg in build-essential python3-venv python3-pip pipx docker.io docker-cli docker-compose \
           code gh jq tmux htop ripgrep sqlite3 firefox-l10n-fr; do
    apt-get install -y --no-install-recommends "$pkg" || warn "paquet non installé : $pkg"
done

step "Node.js LTS"
if curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource.sh && bash /tmp/nodesource.sh \
        && apt-get install -y nodejs; then
    echo "Node.js $(node -v) (NodeSource), npm $(npm -v)"
else
    warn "NodeSource indisponible : Node.js de Debian"
    rm -f /etc/apt/sources.list.d/nodesource.* && apt-get update
    apt-get install -y --no-install-recommends nodejs npm || warn "Node.js non installé"
fi
rm -f /tmp/nodesource.sh

step "cloudflared (tunnel pour l'accès Internet)"
install_cloudflared() {
    for key in cloudflare-public-v2.gpg cloudflare-main.gpg; do
        if curl -fsSL "https://pkg.cloudflare.com/$key" -o /usr/share/keyrings/cloudflare.gpg; then
            echo "deb [signed-by=/usr/share/keyrings/cloudflare.gpg] https://pkg.cloudflare.com/cloudflared any main" \
                > /etc/apt/sources.list.d/cloudflared.list
            if apt-get update && apt-get install -y cloudflared; then
                return 0
            fi
        fi
    done
    rm -f /etc/apt/sources.list.d/cloudflared.list /usr/share/keyrings/cloudflare.gpg
    curl -fsSL -o /tmp/cloudflared.deb \
        https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
    dpkg -i /tmp/cloudflared.deb; rm -f /tmp/cloudflared.deb
}
install_cloudflared
cloudflared --version

step "Outils IA"
if command -v npm >/dev/null; then
    npm install -g --no-fund --no-audit @anthropic-ai/claude-code || warn "Claude Code non installé"
    rm -rf /root/.npm
fi

step "Fichiers Syntax OS"
mkdir -p /usr/lib/syntax /usr/share/syntax /var/lib/syntax
cp -a "$B/system/." /usr/lib/syntax/
cp -a "$B/rootfs/." /
chown -R root:root /usr/lib/syntax /etc/syntax /etc/systemd/system/syntax-*.service
chmod 755 /usr/lib/syntax/cli.py /usr/lib/syntax/portal/server.py /usr/lib/syntax/libexec/*
chmod 750 /etc/syntax
ln -sf /usr/lib/syntax/cli.py /usr/bin/syntax
echo "$VERSION" > /usr/lib/syntax/version
python3 -m compileall -q /usr/lib/syntax

step "Compte d'usine (remplacé obligatoirement à la première connexion au portail)"
HASH="$(openssl passwd -6 syntax)"
echo "$HASH" > /usr/lib/syntax/default-hash
chmod 644 /usr/lib/syntax/default-hash
echo "syntax:$HASH" > /usr/lib/syntax/userconf.txt
FIRST="$(getent passwd 1000 | cut -d: -f1)"
echo "Premier utilisateur de l'image : $FIRST"
getent group docker >/dev/null && usermod -aG docker "$FIRST" || true
# Ouverture automatique de la session graphique : indispensable pour voir le bureau
# à distance sur un Pi sans écran ni clavier (lu par cancel-rename au premier démarrage).
ls -la /var/lib/userconf-pi 2>/dev/null || true
mkdir -p /var/lib/userconf-pi && touch /var/lib/userconf-pi/autologin

step "Identité du système"
dpkg-divert --quiet --add --no-rename --divert /usr/lib/os-release.debian /usr/lib/os-release
cp -a /usr/lib/os-release /usr/lib/os-release.debian
cat > /usr/lib/os-release <<OSR
PRETTY_NAME="Syntax OS $VERSION ($CODENAME)"
NAME="Syntax OS"
VERSION_ID="$(. /usr/lib/os-release.debian; echo "$VERSION_ID")"
VERSION="$VERSION ($CODENAME)"
VERSION_CODENAME=$CODENAME
ID=debian
ID_LIKE=debian
SYNTAX_VERSION=$VERSION
HOME_URL="https://github.com/opencorp2030-ctrl/Syntax"
OSR
[ -L /etc/os-release ] || ln -sf ../usr/lib/os-release /etc/os-release
echo "Syntax OS $VERSION \\n \\l" > /etc/issue
cat > /etc/motd <<'MOTD'

  Syntax OS — bienvenue.
  « syntax »          état du système et adresse du portail
  « syntax connect »  accès par Internet (tunnel Cloudflare)
  « syntax ai »       installer des modèles d'IA locaux (Ollama)

MOTD
echo syntax > /etc/hostname
sed -i 's/\braspberrypi\b/syntax/g' /etc/hosts
grep -q '127.0.1.1' /etc/hosts || echo '127.0.1.1	syntax' >> /etc/hosts

step "Français : langue, clavier, fuseau horaire"
sed -i 's/^# *fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/; s/^# *en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
grep -q '^fr_FR.UTF-8 UTF-8' /etc/locale.gen || echo 'fr_FR.UTF-8 UTF-8' >> /etc/locale.gen
locale-gen
update-locale LANG=fr_FR.UTF-8 LANGUAGE=fr_FR:fr
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo Europe/Paris > /etc/timezone
sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="fr"/; s/^XKBVARIANT=.*/XKBVARIANT=""/' /etc/default/keyboard
timeout 90 raspi-config nonint do_configure_keyboard fr >/dev/null 2>&1 || warn "raspi-config clavier : à vérifier"
cat /etc/default/keyboard | grep -v '^#' | grep .
echo "--- /etc/xdg/labwc/environment"; cat /etc/xdg/labwc/environment || true
if [ -f /etc/xdg/labwc/environment ]; then
    if grep -q '^XKB_DEFAULT_LAYOUT=' /etc/xdg/labwc/environment; then
        sed -i 's/^XKB_DEFAULT_LAYOUT=.*/XKB_DEFAULT_LAYOUT=fr/; s/^XKB_DEFAULT_VARIANT=.*/XKB_DEFAULT_VARIANT=/' /etc/xdg/labwc/environment
    else
        echo 'XKB_DEFAULT_LAYOUT=fr' >> /etc/xdg/labwc/environment
    fi
fi

B="$B" bash "$B/desktop-setup.sh"

step "Raspberry Pi Connect remplacé par Syntax Connect"
REMOVED="$(apt-get -s purge rpi-connect rpi-connect-lite 2>/dev/null | grep -c '^Purg' || true)"
if [ "${REMOVED:-99}" -le 4 ]; then
    apt-get purge -y rpi-connect rpi-connect-lite || warn "rpi-connect non retiré"
else
    warn "retrait de rpi-connect ignoré ($REMOVED paquets seraient supprimés)"
    apt-get -s purge rpi-connect rpi-connect-lite | grep '^Purg' || true
fi

step "Services"
systemctl enable syntax-portal.service syntax-setup.service syntax-userguard.service
systemctl enable avahi-daemon.service 2>/dev/null || true
systemctl disable syntax-tunnel.service 2>/dev/null || true
systemctl disable cloudflared.service 2>/dev/null || true
systemd-analyze verify /etc/systemd/system/syntax-*.service 2>&1 | grep -i syntax || true

# L'initramfs n'est volontairement pas régénéré ici : hors d'un vrai Pi (MODULES=dep), il perd
# des pilotes et des firmwares. Le nouvel écran de démarrage y entrera à la prochaine mise à jour
# du noyau faite sur le Pi ; d'ici là, l'écran de démarrage d'origine s'affiche.

step "Auto-tests dans l'image"
python3 -c "import aiohttp; print('aiohttp', aiohttp.__version__)"
wayvnc --version 2>&1 | head -1
wayvnc --help 2>&1 | grep -E -- '--(unix-socket|socket|config|render-cursor)' || { echo "options wayvnc inattendues"; exit 1; }
syntax status
syntax has-default-password && echo "mot de passe d'usine détecté (inattendu ici)" || echo "garde du tunnel : OK"
SYNTAX_PORT=8765 SYNTAX_BIND=127.0.0.1 python3 /usr/lib/syntax/portal/server.py &
SRV=$!
sleep 4
curl -fsS http://127.0.0.1:8765/ | grep -q "Syntax Connect"
curl -fsS http://127.0.0.1:8765/static/vendor/novnc/core/rfb.js >/dev/null
curl -fsS http://127.0.0.1:8765/api/session
echo
CODE="$(curl -s -o /tmp/login.json -w '%{http_code}' -X POST -H 'Origin: http://127.0.0.1:8765' \
    -d '{"username":"'"$FIRST"'","password":"mauvais"}' http://127.0.0.1:8765/api/login)"
cat /tmp/login.json; echo " (HTTP $CODE)"; rm -f /tmp/login.json
kill "$SRV"; wait "$SRV" 2>/dev/null || true
[ "$CODE" = 401 ] || { echo "Le portail n'a pas refusé un mauvais mot de passe"; exit 1; }
for c in node npm docker code git claude gh cloudflared; do
    printf '%-12s %s\n' "$c" "$(command -v "$c" || echo ABSENT)"
done

step "Nettoyage"
apt-get clean
rm -rf /var/lib/apt/lists/* /var/tmp/* /root/.cache /root/.npm /root/.config 2>/dev/null || true
rm -f /usr/sbin/policy-rc.d
find /var/log -type f -exec truncate -s 0 {} + 2>/dev/null || true
df -h / | tail -1
