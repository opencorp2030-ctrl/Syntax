#!/usr/bin/env python3
"""Génère la configuration du dock (waybar) en résolvant les icônes disponibles dans l'image."""
import glob
import json
import os
import sys

OUT = sys.argv[1]
ICON_DIRS = ["/usr/share/icons/Papirus/64x64/apps", "/usr/share/icons/Papirus/48x48/apps",
             "/usr/share/icons/hicolor/scalable/apps", "/usr/share/icons/hicolor/256x256/apps",
             "/usr/share/icons/hicolor/128x128/apps", "/usr/share/icons/hicolor/48x48/apps",
             "/usr/share/pixmaps"]


def icon(*names):
    for n in names:
        for d in ICON_DIRS:
            for ext in ("svg", "png"):
                p = os.path.join(d, f"{n}.{ext}")
                if os.path.exists(p):
                    return p
    return "/usr/share/syntax/logo.svg"


def have(cmd):
    return any(os.access(os.path.join(d, cmd), os.X_OK) for d in ("/usr/bin", "/usr/local/bin"))


pinned = [
    ("browser", "x-www-browser", icon("chromium", "chromium-browser", "firefox", "web-browser"), "Navigateur"),
    ("files", "pcmanfm", icon("system-file-manager", "org.gnome.Nautilus", "file-manager"), "Fichiers"),
    ("terminal", "x-terminal-emulator", icon("utilities-terminal", "foot", "terminal"), "Terminal"),
]
if have("code"):
    pinned.append(("code", "code", icon("visual-studio-code", "com.visualstudio.code", "vscode", "code"), "VS Code"))
if os.path.exists("/opt/syntax-apps/satiscode/satiscode"):
    pinned.append(("satiscode", "/opt/syntax-apps/satiscode/satiscode", icon("satiscode"), "SatisCode"))
if os.path.exists("/opt/syntax-apps/satisdocs/satisdocs"):
    pinned.append(("satisdocs", "/opt/syntax-apps/satisdocs/satisdocs", icon("satisdocs"), "SatisDocs"))
if os.path.exists("/usr/share/syntax/satisreader"):
    pinned.append(("satisreader", "xdg-open http://127.0.0.1:8092/", icon("satisreader"), "SatisReader"))
pinned.append(("connect", "xdg-open http://localhost/", "/usr/share/syntax/logo-connect.svg", "Syntax Connect"))
pinned.append(("update", "/usr/share/syntax/desktop/bin/update-app", icon("update"), "Mise à jour Syntax"))
pinned.append(("settings", "rpcc", icon("preferences-system", "systemsettings", "gnome-control-center"), "Réglages"))

cfg = {
    "layer": "top", "position": "right", "width": 68, "exclusive": True, "spacing": 0,
    "margin-top": 14, "margin-bottom": 14, "margin-right": 12, "margin-left": 0,
    "modules-left": ["image#menu", "custom/sep"] + [f"image#{k}" for k, *_ in pinned] + ["custom/sep", "wlr/taskbar"],
    "modules-right": ["tray", "pulseaudio", "clock", "custom/power"],
    "image#menu": {"path": "/usr/share/syntax/logo.svg", "size": 38,
                   "on-click": "/usr/share/syntax/desktop/bin/launcher", "tooltip": False},
    "custom/sep": {"format": " ", "tooltip": False},
    "wlr/taskbar": {"format": "{icon}", "icon-size": 36, "icon-theme": ["Papirus-Dark", "Papirus", "hicolor"],
                    "tooltip-format": "{title}", "on-click": "activate", "on-click-middle": "close",
                    "on-click-right": "minimize"},
    "tray": {"icon-size": 20, "spacing": 12, "show-passive-items": True},
    "pulseaudio": {"format": "{icon}", "format-muted": "",
                   "format-icons": {"default": ["", ""]},
                   "tooltip-format": "Volume : {volume} %", "on-click": "pavucontrol",
                   "on-click-right": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "scroll-step": 5},
    "clock": {"format": "{:%H\n%M}", "interval": 30, "tooltip-format": "{:%A %d %B %Y}", "justify": "center"},
    "custom/power": {"format": "", "tooltip": False,
                     "on-click": "/usr/share/syntax/desktop/bin/power-menu"},
}
for key, cmd, path, label in pinned:
    cfg[f"image#{key}"] = {"path": path, "size": 38, "on-click": cmd, "tooltip": False}
    print(f"dock : {label:15} {path}")
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
