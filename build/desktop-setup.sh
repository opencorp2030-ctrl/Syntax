#!/bin/bash
# Exécuté dans le chroot : installe l'interface de Syntax OS (dock vertical à droite, lanceur,
# thème sombre, écran de connexion, écran de démarrage). $B = dossier de construction.
set -euo pipefail
B="${B:-/tmp/syntax-build}"
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
step() { printf '\n\033[1;36m--> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mAVERTISSEMENT : %s\033[0m\n' "$*"; }

step "Interface : paquets"
apt-get update

step "Performance : swap compressé en RAM (zram)"
# Évite l'échange sur la carte SD (très lent) quand la mémoire sature avec plusieurs
# applications ouvertes (Electron, Docker, navigateur…) : bien plus rapide, et épargne
# la carte SD.
apt-get install -y --no-install-recommends zram-tools
cat > /etc/default/zramswap <<'Z'
ALGO=zstd
PERCENT=50
PRIORITY=100
Z
systemctl enable zramswap.service

step "Performance : moins de démons en arrière-plan"
# gvfs lance un surveillant de volumes par type d'appareil ; sur un Pi, seuls les
# disques/clés USB (udisks2) servent au quotidien. Les autres tournent en continu pour
# rien et sont désactivés ; une clé USB normale continue de fonctionner.
systemctl --global mask gvfs-mtp-volume-monitor.service gvfs-gphoto2-volume-monitor.service \
    gvfs-goa-volume-monitor.service gvfs-afc-volume-monitor.service 2>/dev/null || true

step "Fiabilité : log2ram et journal en RAM"
# Les journaux système réécrivent sans arrêt sur la carte SD, qui s'use et finit par lâcher.
# log2ram déplace /var/log en RAM (recopié sur la carte seulement une fois par jour, et
# proprement à l'extinction) ; le journal systemd est lui aussi gardé en mémoire plutôt
# que sur disque.
if git clone --quiet --depth 1 https://github.com/azlux/log2ram /tmp/log2ram; then
    (
        cd /tmp/log2ram
        install -m 644 log2ram.service log2ram-daily.service /etc/systemd/system/
        install -m 644 log2ram-daily.timer /etc/systemd/system/
        install -m 755 log2ram /usr/local/bin/log2ram
        sed 's/^SIZE=.*/SIZE=64M/' log2ram.conf > /etc/log2ram.conf
        [ -d /etc/logrotate.d ] && install -m 644 log2ram.logrotate /etc/logrotate.d/log2ram
    )
    systemctl enable log2ram.service log2ram-daily.timer
    rm -rf /tmp/log2ram
else
    warn "log2ram non récupéré."
fi
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/syntax-volatile.conf <<'J'
[Journal]
Storage=volatile
RuntimeMaxUse=48M
J

apt-get install -y --no-install-recommends \
    waybar fuzzel mako-notifier fonts-inter fonts-font-awesome papirus-icon-theme \
    network-manager-applet blueman pavucontrol swaybg wl-clipboard grim slurp wlr-randr \
    libglib2.0-bin cpio foot fonts-jetbrains-mono php-cli zenity policykit-1

step "Interface : fichiers"
mkdir -p /usr/share/syntax/desktop /usr/share/themes/Syntax
cp -a "$B/desktop/bin" "$B/desktop/"*.css "$B/desktop/"*.ini "$B/desktop/"*.conf /usr/share/syntax/desktop/
cp -a "$B/desktop/theme/." /usr/share/themes/Syntax/
cp "$B/desktop/logo-connect.svg" /usr/share/syntax/logo-connect.svg
cp "$B/system/portal/static/logo.svg" /usr/share/syntax/logo.svg
cp "$B/wallpaper.jpg" /usr/share/syntax/wallpaper.jpg
mkdir -p /usr/share/syntax/wallpapers
cp "$B"/wallpapers/*.jpg /usr/share/syntax/wallpapers/
cp "$B/logo.png" /usr/share/syntax/logo.png
mkdir -p /usr/share/icons/hicolor/scalable/apps
cp "$B"/desktop/icons/*.svg /usr/share/icons/hicolor/scalable/apps/
chmod 755 /usr/share/syntax/desktop/bin/*
mkdir -p /etc/xdg/foot && cp "$B/desktop/foot.ini" /etc/xdg/foot/foot.ini
update-alternatives --set x-terminal-emulator /usr/bin/foot 2>/dev/null \
    || update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/foot 60

step "Police d'affichage : Space Grotesk (titres, logo)"
if [ -f "$B/apps/fonts/SpaceGrotesk.ttf" ]; then
    mkdir -p /usr/share/fonts/truetype/syntax
    cp "$B/apps/fonts/SpaceGrotesk.ttf" /usr/share/fonts/truetype/syntax/SpaceGrotesk.ttf
    [ -f "$B/apps/fonts/SpaceGrotesk-OFL.txt" ] && cp "$B/apps/fonts/SpaceGrotesk-OFL.txt" /usr/share/fonts/truetype/syntax/LICENSE.txt
    mkdir -p /usr/lib/syntax/portal/static/fonts
    cp "$B/apps/fonts/SpaceGrotesk.ttf" /usr/lib/syntax/portal/static/fonts/SpaceGrotesk.ttf
    fc-cache -f /usr/share/fonts/truetype/syntax >/dev/null
else
    warn "Space Grotesk non récupérée : les titres resteront en Inter."
fi

step "Curseur : Bibata-Modern-Classic"
if [ -d "$B/apps/cursor/Bibata-Modern-Classic" ]; then
    cp -a "$B/apps/cursor/Bibata-Modern-Classic" /usr/share/icons/Bibata-Modern-Classic
    CURSOR_THEME=Bibata-Modern-Classic
else
    warn "Bibata non récupéré : curseur Adwaita conservé."
    CURSOR_THEME=Adwaita
fi

step "Icônes : dossiers Papirus recolorés"
if [ -x "$B/apps/papirus-folders" ]; then
    "$B/apps/papirus-folders" -t Papirus -C orange || warn "papirus-folders (Papirus) a échoué"
    "$B/apps/papirus-folders" -t Papirus-Dark -C orange || warn "papirus-folders (Papirus-Dark) a échoué"
else
    warn "papirus-folders non récupéré : dossiers bleus par défaut."
fi

step "Applications : poly, SatisCode, SatisDocs, SatisReader"
if [ -x "$B/apps/poly" ]; then
    cp "$B/apps/poly" /usr/bin/poly && chmod 755 /usr/bin/poly
    "/usr/bin/poly" version || true
else
    warn "poly non récupéré."
fi
install_electron_app() { # install_electron_app <id> <titre>
    local id="$1"
    local title="$2"
    local src="$B/apps/$id"
    [ -d "$src" ] || { warn "$title non récupéré."; return; }
    rm -rf "/opt/syntax-apps/$id"
    mkdir -p /opt/syntax-apps
    cp -a "$src" "/opt/syntax-apps/$id"
    chmod 755 "/opt/syntax-apps/$id/$id"
    if [ -f "/opt/syntax-apps/$id/chrome-sandbox" ]; then
        chown root:root "/opt/syntax-apps/$id/chrome-sandbox"
        chmod 4755 "/opt/syntax-apps/$id/chrome-sandbox"
    fi
    cat > "/usr/share/applications/$id.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=$title
Exec=/opt/syntax-apps/$id/$id %U
Icon=$id
Categories=Development;
DESK
}
install_electron_app satiscode "SatisCode"
install_electron_app satisdocs "SatisDocs"

if [ -d "$B/apps/satisreader" ]; then
    rm -rf /usr/share/syntax/satisreader
    cp -a "$B/apps/satisreader" /usr/share/syntax/satisreader
    id -u satisreader >/dev/null 2>&1 || useradd --system --no-create-home --home-dir /var/lib/syntax/satisreader \
        --shell /usr/sbin/nologin satisreader
    mkdir -p /var/lib/syntax/satisreader
    chown -R satisreader:satisreader /var/lib/syntax/satisreader
    cat > /etc/systemd/system/syntax-satisreader.service <<'UNIT'
[Unit]
Description=Syntax OS — SatisReader (lecteur de flux RSS/Atom)
After=network.target

[Service]
User=satisreader
Group=satisreader
WorkingDirectory=/var/lib/syntax/satisreader
ExecStart=/usr/bin/php -S 127.0.0.1:8092 -t /usr/share/syntax/satisreader
Restart=on-failure
RestartSec=5
NoNewPrivileges=yes
ProtectSystem=strict
ReadWritePaths=/var/lib/syntax/satisreader

[Install]
WantedBy=multi-user.target
UNIT
    systemctl enable syntax-satisreader.service
    cat > /usr/share/applications/satisreader.desktop <<'DESK'
[Desktop Entry]
Type=Application
Name=SatisReader
Exec=xdg-open http://127.0.0.1:8092/
Icon=satisreader
Categories=Network;News;
DESK
else
    warn "SatisReader non récupéré."
fi

cp "$B/desktop/bin/update-app" /usr/share/syntax/desktop/bin/update-app
chmod 755 /usr/share/syntax/desktop/bin/update-app
cat > /usr/share/applications/syntax-update.desktop <<'DESK'
[Desktop Entry]
Type=Application
Name=Mise à jour Syntax
Comment=Vérifie et installe la dernière version de Syntax OS
Exec=/usr/share/syntax/desktop/bin/update-app
Icon=update
Categories=System;
DESK

python3 "$B/desktop/make-dock.py" /usr/share/syntax/desktop/waybar.json

step "Interface : thème, polices, icônes"
cat > /usr/share/glib-2.0/schemas/90_syntax.gschema.override <<G
[org.gnome.desktop.interface]
gtk-theme='Adwaita-dark'
icon-theme='Papirus-Dark'
cursor-theme='$CURSOR_THEME'
font-name='Inter 11'
document-font-name='Inter 11'
color-scheme='prefer-dark'
G
glib-compile-schemas /usr/share/glib-2.0/schemas
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini <<G
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-cursor-theme-name=$CURSOR_THEME
gtk-application-prefer-dark-theme=1
G
LX=/etc/xdg/lxsession/rpd-labwc/desktop.conf
for f in /etc/xdg/lxsession/*/desktop.conf; do
    sed -i "s|^sNet/ThemeName=.*|sNet/ThemeName=Adwaita-dark|; s|^sNet/IconThemeName=.*|sNet/IconThemeName=Papirus-Dark|; s|^sGtk/FontName=.*|sGtk/FontName=Inter 11|; s|^sGtk/CursorThemeName=.*|sGtk/CursorThemeName=$CURSOR_THEME|; /^sGtk\/ColorScheme=/d" "$f"
done
# Logo du menu et du système dans le thème d'icônes d'origine (au cas où il resterait utilisé).
for size in 16 24 32 48 64 96; do
    for name in start-here distributor-logo rpi; do
        f="/usr/share/icons/PiXtrix/${size}x${size}/places/$name.png"
        [ -f "$f" ] || continue
        dpkg-divert --quiet --add --rename --divert "$f.rpi" "$f"
        cp "$B/logo-$size.png" "$f"
    done
done
for name in start-here distributor-logo rpi; do
    f="/usr/share/icons/PiXtrix/scalable/places/$name.svg"
    [ -f "$f" ] || continue
    dpkg-divert --quiet --add --rename --divert "$f.rpi" "$f"
    cp /usr/share/syntax/logo.svg "$f"
done
mkdir -p /usr/share/icons/hicolor/scalable/apps
cp /usr/share/syntax/logo.svg /usr/share/icons/hicolor/scalable/apps/syntax.svg
gtk-update-icon-cache -q -f /usr/share/icons/hicolor 2>/dev/null || true
gtk-update-icon-cache -q -f /usr/share/icons/PiXtrix 2>/dev/null || true

step "Interface : session labwc"
RC=/etc/xdg/labwc/rc.xml
python3 - "$RC" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
subs = [
    (r"<name>PiXtrix</name>", "<name>Syntax</name>"),
    (r"<cornerRadius>\d+</cornerRadius>", "<cornerRadius>12</cornerRadius>"),
    (r"<name>Nunito Sans</name>", "<name>Inter</name>"),
    (r"<weight>Light</weight>", "<weight>Medium</weight>"),
    (r"<size>12</size>", "<size>11</size>"),
    (r'command="wfpanelctl volumepulse volu"', 'command="wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"'),
    (r'command="wfpanelctl volumepulse vold"', 'command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"'),
    (r'command="wfpanelctl volumepulse mute"', 'command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"'),
    (r'command="wfpanelctl \S*menu menu"', 'command="/usr/share/syntax/desktop/bin/launcher"'),
    (r'command="wfpanelctl netman menu"', 'command="nm-connection-editor"'),
    (r'command="wfpanelctl bluetooth menu"', 'command="blueman-manager"'),
    (r'command="pishutdown"', 'command="/usr/share/syntax/desktop/bin/power-menu"'),
    (r'command="swaylock -p"', 'command="swaylock -f -i /usr/share/syntax/wallpaper.jpg --scaling fill -c 101014"'),
]
for pat, rep in subs:
    s, n = re.subn(pat, rep, s)
    print(f"rc.xml : {n} × {pat}")
open(p, "w", encoding="utf-8").write(s)
PY
cat > /etc/xdg/labwc/autostart <<'A'
/usr/bin/lwrespawn /usr/bin/pcmanfm-pi &
/usr/bin/lwrespawn /usr/share/syntax/desktop/bin/dock &
/usr/bin/kanshi &
/usr/share/syntax/desktop/bin/session-start &
/usr/bin/lxsession-xdg-autostart
A
cat > /etc/xdg/labwc/menu.xml <<'M'
<openbox_menu>
  <menu id="root-menu">
    <item label="Applications…">
      <action name="Execute" command="/usr/share/syntax/desktop/bin/launcher" />
    </item>
    <item label="Terminal">
      <action name="Execute" command="x-terminal-emulator" />
    </item>
    <item label="Fichiers">
      <action name="Execute" command="pcmanfm" />
    </item>
    <item label="Réglages du bureau…">
      <action name="Execute" command="rpcc desktop" />
    </item>
  </menu>
</openbox_menu>
M
sed -i "s/^XCURSOR_THEME=.*/XCURSOR_THEME=$CURSOR_THEME/" /etc/xdg/labwc/environment /etc/xdg/labwc-greeter/environment 2>/dev/null || true
# Les applets réseau / Bluetooth sont lancés par session-start (mode zone de notification).
for f in /etc/xdg/autostart/nm-applet.desktop /etc/xdg/autostart/blueman.desktop; do
    [ -f "$f" ] && { grep -q '^Hidden=' "$f" || echo 'Hidden=true' >> "$f"; }
done

step "Interface : lanceur sans entrées techniques ou en double"
apt-get -s purge rp-bookshelf 2>/dev/null | grep -c '^Purg' | { read -r n; [ "${n:-9}" -le 2 ] && apt-get purge -y rp-bookshelf >/dev/null 2>&1 || true; }
mkdir -p /usr/local/share/applications
for app in userguide gui-runcmd wf-panel-pi openbox org.freedesktop.Xwayland notification-daemon \
           lxsession-logout pishutdown lxterminal foot-server footclient; do
    [ -f "/usr/share/applications/$app.desktop" ] || continue
    printf '[Desktop Entry]\nType=Application\nName=%s\nNoDisplay=true\n' "$app" > "/usr/local/share/applications/$app.desktop"
done
if [ -f /usr/share/applications/foot.desktop ]; then
    sed 's/^Name=.*/Name=Terminal/; /^Name\[/d; s/^GenericName=.*/GenericName=Terminal/' /usr/share/applications/foot.desktop \
        > /usr/local/share/applications/foot.desktop
fi
ls /usr/share/applications | tr '\n' ' '; echo

step "Bluetooth : souris et claviers Bluetooth Low Energy"
# Un périphérique BLE (beaucoup de souris et claviers Bluetooth récents) s'appaire et
# indique « connecté » même quand le profil clavier/souris (HID sur GATT) n'est pas
# activé dans BlueZ — symptôme typique : connecté, mais le curseur ne bouge pas.
# BlueZ (GKeyFile) retient la dernière occurrence de chaque clé : on ajoute notre
# propre bloc à la fin du fichier plutôt que de modifier les lignes d'origine, ce qui
# fonctionne quel que soit le contenu déjà présent.
BTCONF=/etc/bluetooth/main.conf
if [ -f "$BTCONF" ]; then
    cat >> "$BTCONF" <<'BT'

# --- Syntax OS : prise en charge des périphériques Bluetooth Low Energy (BLE) ---
[General]
ControllerMode = dual
FastConnectable = true
Experimental = true
KernelExperimental = true

[Policy]
AutoEnable=true
BT
    echo "--- $BTCONF (fin)"; tail -n 12 "$BTCONF"
else
    warn "/etc/bluetooth/main.conf introuvable."
fi

step "Interface : traduction des dernières entrées en anglais"
# Corrige à la volée, sans dépendre des noms de fichiers, les entrées du lanceur dont la
# traduction française manque encore dans l'image de base.
declare -A FR_NAMES=(
    ["Add / Remove Software"]="Ajouter / Supprimer des logiciels"
    ["Accessories"]="Accessoires"
    ["Preferences"]="Préférences"
)
for f in /usr/share/applications/*.desktop; do
    [ -f "$f" ] || continue
    EN="$(grep -m1 '^Name=' "$f" | cut -d= -f2-)"
    FR="${FR_NAMES[$EN]:-}"
    [ -n "$FR" ] || continue
    grep -q '^Name\[fr\]=' "$f" && continue
    BASE="$(basename "$f")"
    sed "/^Name=/a Name[fr]=$FR" "$f" > "/usr/local/share/applications/$BASE"
    echo "traduit : $EN -> $FR ($BASE)"
done

step "Interface : bureau et écran de connexion"
for f in /etc/xdg/pcmanfm/default/desktop-items-*.conf; do
    [ -f "$f" ] || continue
    sed -i 's|^wallpaper=.*|wallpaper=/usr/share/syntax/wallpaper.jpg|; s|^wallpaper_mode=.*|wallpaper_mode=crop|; s|^desktop_bg=.*|desktop_bg=#0a0c14|; s|^desktop_fg=.*|desktop_fg=#f5f5f7|; s|^desktop_shadow=.*|desktop_shadow=#000000|; s|^desktop_font=.*|desktop_font=Inter 11|; s|^show_trash=.*|show_trash=0|' "$f"
done
G=/etc/lightdm/pi-greeter.conf
if [ -f "$G" ]; then
    sed -i 's|^default-user-image=.*|default-user-image=/usr/share/syntax/logo.png|; s|^wallpaper=.*|wallpaper=/usr/share/syntax/wallpaper.jpg|; s|^desktop_bg=.*|desktop_bg=#0a0c14|; s|^gtk-theme-name=.*|gtk-theme-name=Adwaita-dark|; s|^gtk-icon-theme-name=.*|gtk-icon-theme-name=Papirus-Dark|; s|^gtk-font-name=.*|gtk-font-name=Inter 11|' "$G"
    cat "$G"
fi
if [ -f /etc/xdg/labwc-greeter/rc.xml ]; then
    sed -i 's|<name>PiXtrix</name>|<name>Syntax</name>|; s|<name>Nunito Sans</name>|<name>Inter</name>|g; s|<weight>Light</weight>|<weight>Medium</weight>|g' /etc/xdg/labwc-greeter/rc.xml
fi

step "Interface : écran de démarrage"
SPL=/usr/share/plymouth/themes/pix/splash.png
if [ -f "$SPL" ]; then
    dpkg-divert --quiet --add --rename --divert "$SPL.rpi" "$SPL" 2>/dev/null || true
    cp "$B/splash.png" "$SPL"
    # Ajout du nouvel écran à l'initramfs d'origine (archive cpio concaténée) : aucune
    # régénération, donc aucun pilote perdu.
    T="$(mktemp -d)"
    mkdir -p "$T/usr/share/plymouth/themes/pix"
    cp "$B/splash.png" "$T/usr/share/plymouth/themes/pix/splash.png"
    ( cd "$T" && find . | cpio --quiet -o -H newc ) > /tmp/syntax-splash.cpio
    for f in /boot/firmware/initramfs8 /boot/firmware/initramfs_2712; do
        [ -f "$f" ] || continue
        if ! tail -c 4096 "$f" | grep -q TRAILER; then
            cat /tmp/syntax-splash.cpio >> "$f"
            echo "splash ajouté à $f ($(stat -c %s "$f") octets)"
        fi
    done
    rm -rf "$T" /tmp/syntax-splash.cpio
fi

step "Interface : résumé"
ls -la /usr/share/syntax /usr/share/syntax/desktop
cat /usr/share/syntax/desktop/waybar.json | head -30
