#!/usr/bin/env python3
"""Génère la configuration du dock (waybar) à partir de /etc/syntax/dock.json.

Appelé au démarrage de la session et après chaque changement fait depuis
« Réglages du dock » (desktop/bin/dock-settings). Si le fichier de configuration
n'existe pas encore, une liste par défaut est écrite pour que l'utilisateur puisse
ensuite la modifier.
"""
import json
import os
import sys

OUT = sys.argv[1]
# Pas sous /etc/syntax : ce dossier est volontairement fermé aux utilisateurs normaux
# (jetons, mots de passe). La configuration du dock ne contient rien de sensible et doit
# rester lisible par tout le monde pour que le réglage fonctionne sans élévation.
DOCK_CONF = os.environ.get("SYNTAX_DOCK_CONF", "/etc/syntax-dock.json")
ICON_DIRS = ["/usr/share/icons/Papirus/64x64/apps", "/usr/share/icons/Papirus/48x48/apps",
             "/usr/share/icons/hicolor/scalable/apps", "/usr/share/icons/hicolor/256x256/apps",
             "/usr/share/icons/hicolor/128x128/apps", "/usr/share/icons/hicolor/48x48/apps",
             "/usr/share/pixmaps"]


def icon(*names):
    for n in names:
        if not n:
            continue
        if n.startswith("/"):
            return n if os.path.exists(n) else "/usr/share/syntax/logo.svg"
        for d in ICON_DIRS:
            for ext in ("svg", "png"):
                p = os.path.join(d, f"{n}.{ext}")
                if os.path.exists(p):
                    return p
    return "/usr/share/syntax/logo.svg"


def have(cmd):
    return any(os.access(os.path.join(d, cmd), os.X_OK) for d in ("/usr/bin", "/usr/local/bin"))


def default_items():
    items = [
        {"id": "browser", "label": "Navigateur", "exec": "x-www-browser",
         "icon_hint": ["chromium", "chromium-browser", "firefox", "web-browser"]},
        {"id": "files", "label": "Fichiers", "exec": "pcmanfm",
         "icon_hint": ["system-file-manager", "org.gnome.Nautilus", "file-manager"]},
        {"id": "terminal", "label": "Terminal", "exec": "x-terminal-emulator",
         "icon_hint": ["utilities-terminal", "foot", "terminal"]},
    ]
    if have("code"):
        items.append({"id": "code", "label": "VS Code", "exec": "code",
                      "icon_hint": ["visual-studio-code", "com.visualstudio.code", "vscode", "code"]})
    if os.path.exists("/opt/syntax-apps/satiscode/satiscode"):
        items.append({"id": "satiscode", "label": "SatisCode", "exec": "/opt/syntax-apps/satiscode/satiscode",
                      "icon_hint": ["satiscode"]})
    if os.path.exists("/opt/syntax-apps/satisdocs/satisdocs"):
        items.append({"id": "satisdocs", "label": "SatisDocs", "exec": "/opt/syntax-apps/satisdocs/satisdocs",
                      "icon_hint": ["satisdocs"]})
    if os.path.exists("/usr/share/syntax/satisreader"):
        items.append({"id": "satisreader", "label": "SatisReader", "exec": "xdg-open http://127.0.0.1:8092/",
                      "icon_hint": ["satisreader"]})
    items.append({"id": "connect", "label": "Syntax Connect", "exec": "xdg-open http://localhost/",
                  "icon_hint": ["/usr/share/syntax/logo-connect.svg"]})
    items.append({"id": "update", "label": "Mise à jour Syntax", "exec": "/usr/share/syntax/desktop/bin/update-app",
                  "icon_hint": ["update"]})
    items.append({"id": "dock-settings", "label": "Réglages du dock", "exec": "/usr/share/syntax/desktop/bin/dock-settings",
                  "icon_hint": ["preferences-desktop", "dock"]})
    items.append({"id": "settings", "label": "Réglages système", "exec": "rpcc",
                  "icon_hint": ["preferences-system", "systemsettings", "gnome-control-center"]})
    return items


def load_config():
    if os.path.exists(DOCK_CONF):
        try:
            with open(DOCK_CONF, encoding="utf-8") as f:
                conf = json.load(f)
            conf.setdefault("icon_size", 38)
            conf.setdefault("items", default_items())
            return conf
        except (json.JSONDecodeError, OSError):
            pass
    conf = {"icon_size": 38, "items": default_items()}
    save_config(conf)
    return conf


def save_config(conf):
    os.makedirs(os.path.dirname(DOCK_CONF), exist_ok=True)
    tmp = DOCK_CONF + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(conf, f, indent=2, ensure_ascii=False)
    os.replace(tmp, DOCK_CONF)


def build(conf):
    size = max(22, min(72, int(conf.get("icon_size", 38))))
    items = conf.get("items", [])
    width = size + 30
    dock_keys = []
    cfg = {
        "layer": "top", "position": "right", "width": width, "exclusive": True, "spacing": 0,
        "margin-top": 14, "margin-bottom": 14, "margin-right": 12, "margin-left": 0,
        "modules-left": ["image#menu", "custom/sep"],
        "modules-right": ["tray", "pulseaudio", "clock", "custom/power"],
        "image#menu": {"path": "/usr/share/syntax/logo.svg", "size": size,
                       "on-click": "/usr/share/syntax/desktop/bin/launcher", "tooltip": False},
        "custom/sep": {"format": " ", "tooltip": False},
        "wlr/taskbar": {"format": "{icon}", "icon-size": max(20, size - 2),
                        "icon-theme": ["Papirus-Dark", "Papirus", "hicolor"],
                        "tooltip-format": "{title}", "on-click": "activate", "on-click-middle": "close",
                        "on-click-right": "minimize"},
        "tray": {"icon-size": max(16, size - 18), "spacing": 12, "show-passive-items": True},
        "pulseaudio": {"format": "{icon}", "format-muted": "",
                       "format-icons": {"default": ["", ""]},
                       "tooltip-format": "Volume : {volume} %", "on-click": "pavucontrol",
                       "on-click-right": "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "scroll-step": 5},
        "clock": {"format": "{:%H\n%M}", "interval": 30, "tooltip-format": "{:%A %d %B %Y}", "justify": "center"},
        "custom/power": {"format": "", "tooltip": False,
                         "on-click": "/usr/share/syntax/desktop/bin/power-menu"},
    }
    for it in items:
        key = f"image#{it['id']}"
        path = icon(it.get("icon"), *it.get("icon_hint", []))
        cfg[key] = {
            "path": path, "size": size, "on-click": it["exec"],
            "tooltip": True, "tooltip-format": it.get("label", it["id"]),
            "on-click-right": "/usr/share/syntax/desktop/bin/dock-settings",
        }
        dock_keys.append(key)
        print(f"dock : {it.get('label', it['id']):22} {path}")
    cfg["modules-left"] += dock_keys + ["custom/sep", "wlr/taskbar"]
    return cfg


if __name__ == "__main__":
    config = load_config()
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(build(config), f, indent=2, ensure_ascii=False)
