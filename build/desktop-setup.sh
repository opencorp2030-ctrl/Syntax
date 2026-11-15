#!/bin/bash
# Exécuté dans le chroot : installe l'interface de Syntax OS (dock vertical à droite, lanceur,
# thème sombre, écran de connexion, écran de démarrage). $B = dossier de construction.
set -euo pipefail
B="${B:-/tmp/syntax-build}"
export DEBIAN_FRONTEND=noninteractive LC_ALL=C.UTF-8
step() { printf '\n\033[1;36m--> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mAVERTISSEMENT : %s\033[0m\n' "$*"; }

step "Interface : paquets"
apt-get install -y --no-install-recommends \
    waybar fuzzel mako-notifier fonts-inter fonts-font-awesome papirus-icon-theme \
    network-manager-applet blueman pavucontrol swaybg wl-clipboard grim slurp wlr-randr \
    libglib2.0-bin cpio

step "Interface : fichiers"
mkdir -p /usr/share/syntax/desktop /usr/share/themes/Syntax
cp -a "$B/desktop/bin" "$B/desktop/"*.css "$B/desktop/"*.ini "$B/desktop/"*.conf /usr/share/syntax/desktop/
cp -a "$B/desktop/theme/." /usr/share/themes/Syntax/
cp "$B/desktop/logo-connect.svg" /usr/share/syntax/logo-connect.svg
cp "$B/system/portal/static/logo.svg" /usr/share/syntax/logo.svg
cp "$B/wallpaper.jpg" /usr/share/syntax/wallpaper.jpg
cp "$B/logo.png" /usr/share/syntax/logo.png
chmod 755 /usr/share/syntax/desktop/bin/*
python3 "$B/desktop/make-dock.py" /usr/share/syntax/desktop/waybar.json

step "Interface : thème, polices, icônes"
cat > /usr/share/glib-2.0/schemas/90_syntax.gschema.override <<'G'
[org.gnome.desktop.interface]
gtk-theme='Adwaita-dark'
icon-theme='Papirus-Dark'
cursor-theme='Adwaita'
font-name='Inter 11'
document-font-name='Inter 11'
color-scheme='prefer-dark'
G
glib-compile-schemas /usr/share/glib-2.0/schemas
mkdir -p /etc/gtk-3.0
cat > /etc/gtk-3.0/settings.ini <<'G'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 11
gtk-cursor-theme-name=Adwaita
gtk-application-prefer-dark-theme=1
G
LX=/etc/xdg/lxsession/rpd-labwc/desktop.conf
for f in /etc/xdg/lxsession/*/desktop.conf; do
    sed -i 's|^sNet/ThemeName=.*|sNet/ThemeName=Adwaita-dark|; s|^sNet/IconThemeName=.*|sNet/IconThemeName=Papirus-Dark|; s|^sGtk/FontName=.*|sGtk/FontName=Inter 11|; s|^sGtk/CursorThemeName=.*|sGtk/CursorThemeName=Adwaita|; /^sGtk\/ColorScheme=/d' "$f"
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
sed -i 's/^XCURSOR_THEME=.*/XCURSOR_THEME=Adwaita/' /etc/xdg/labwc/environment /etc/xdg/labwc-greeter/environment 2>/dev/null || true
# Les applets réseau / Bluetooth sont lancés par session-start (mode zone de notification).
for f in /etc/xdg/autostart/nm-applet.desktop /etc/xdg/autostart/blueman.desktop; do
    [ -f "$f" ] && { grep -q '^Hidden=' "$f" || echo 'Hidden=true' >> "$f"; }
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
