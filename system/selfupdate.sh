#!/bin/bash
# Mise à jour automatique de Syntax OS : met à jour les paquets du système, puis les
# fichiers propres à Syntax OS (portail, bureau, icônes) depuis la dernière version
# publiée sur GitHub — sans jamais toucher à l'image ni aux données de l'utilisateur.
set -uo pipefail
REPO="opencorp2030-ctrl/Syntax"
LOCK=/run/lock/syntax-selfupdate.lock
LOG=/var/log/syntax-selfupdate.log
VERSION_FILE=/usr/lib/syntax/version

exec 9>"$LOCK"
flock -n 9 || { echo "Une mise à jour est déjà en cours."; exit 0; }

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
notify() {
    for u in /run/user/*; do
        uid="${u##*/}"
        [ -S "$u/bus" ] || continue
        sudo -u "#$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=$u/bus" \
            notify-send -i /usr/share/syntax/logo.png "Syntax OS" "$1" 2>/dev/null || true
    done
}

log "=== Mise à jour automatique ==="

log "Paquets système (apt)"
if apt-get update >>"$LOG" 2>&1 && apt-get -y full-upgrade >>"$LOG" 2>&1; then
    log "apt : à jour."
else
    log "apt : échec (voir $LOG)."
fi
apt-get -y autoremove >>"$LOG" 2>&1 || true

CURRENT="$(cat "$VERSION_FILE" 2>/dev/null || echo 0.0.0)"
log "Version installée des fichiers Syntax : $CURRENT"

RELEASE_JSON="$(curl -fsSL -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$REPO/releases/latest" 2>>"$LOG")" || {
    log "Impossible de joindre GitHub : pas de mise à jour des fichiers Syntax cette fois."
    log "=== Terminé (apt seulement) ==="
    exit 0
}

LATEST="$(printf '%s' "$RELEASE_JSON" | grep -o '"tag_name" *: *"[^"]*"' | head -1 | sed 's/.*"v\?\([^"]*\)"/\1/')"
if [ -z "$LATEST" ]; then
    log "Réponse GitHub inattendue, abandon."
    exit 0
fi
log "Dernière version publiée : $LATEST"

if [ "$LATEST" = "$CURRENT" ]; then
    log "Déjà à jour."
    log "=== Terminé ==="
    exit 0
fi

ASSET_URL="$(printf '%s' "$RELEASE_JSON" \
    | grep -o '"browser_download_url" *: *"[^"]*syntax-update-[^"]*\.tar\.gz"' \
    | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
if [ -z "$ASSET_URL" ]; then
    log "Aucun paquet de mise à jour pour $LATEST (version plus récente mais sans fichiers Syntax à jour) ; abandon pour cette fois."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
log "Téléchargement : $ASSET_URL"
if ! curl -fsSL -o "$WORK/update.tar.gz" "$ASSET_URL" >>"$LOG" 2>&1; then
    log "Échec du téléchargement, abandon (aucun fichier modifié)."
    exit 0
fi
if ! curl -fsSL -o "$WORK/update.sha256" "$ASSET_URL.sha256" >>"$LOG" 2>&1; then
    log "Pas de somme de contrôle disponible, abandon par prudence (aucun fichier modifié)."
    exit 0
fi
EXPECTED="$(awk '{print $1}' "$WORK/update.sha256")"
ACTUAL="$(sha256sum "$WORK/update.tar.gz" | awk '{print $1}')"
if [ "$EXPECTED" != "$ACTUAL" ]; then
    log "Somme de contrôle invalide, abandon sans rien modifier."
    exit 0
fi

log "Somme de contrôle vérifiée, application de la mise à jour."
tar -C / -xzf "$WORK/update.tar.gz" >>"$LOG" 2>&1
echo "$LATEST" > "$VERSION_FILE"

systemctl daemon-reload
systemctl restart syntax-portal.service 2>>"$LOG" || true
if [ -x /usr/lib/syntax/desktop/make-dock.py ] || [ -f /usr/lib/syntax/desktop/make-dock.py ]; then
    python3 /usr/lib/syntax/desktop/make-dock.py /usr/share/syntax/desktop/waybar.json >>"$LOG" 2>&1 || true
    pkill -x waybar 2>/dev/null || true
fi
fc-cache -f /usr/share/fonts/truetype/syntax >/dev/null 2>&1 || true

log "Mise à jour vers $LATEST appliquée."
log "=== Terminé ==="
notify "Mise à jour installée : Syntax OS $LATEST. Reconnecte-toi pour voir tous les changements."
