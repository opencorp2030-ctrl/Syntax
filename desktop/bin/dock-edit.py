#!/usr/bin/env python3
"""Opérations sur un fichier de configuration du dock (format de make-dock.py).
Utilisé par dock-settings ; ne nécessite aucun privilège (lit/écrit le fichier donné,
jamais /etc/syntax-dock.json directement — ce fichier n'est copié à sa place qu'après
élévation, par dock-apply).
"""
import glob
import json
import os
import re
import sys

APP_DIRS = ["/usr/local/share/applications", "/usr/share/applications"]


def load(path):
    if os.path.exists(path):
        try:
            with open(path, encoding="utf-8") as f:
                conf = json.load(f)
            conf.setdefault("icon_size", 38)
            conf.setdefault("items", [])
            return conf
        except (json.JSONDecodeError, OSError):
            pass
    return {"icon_size": 38, "items": []}


def save(path, conf):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(conf, f, indent=2, ensure_ascii=False)


def parse_desktop(path):
    name = icon = exec_ = None
    no_display = hidden = False
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            in_entry = False
            for line in f:
                line = line.strip()
                if line == "[Desktop Entry]":
                    in_entry = True
                    continue
                if line.startswith("[") and line != "[Desktop Entry]":
                    in_entry = False
                if not in_entry:
                    continue
                if line.startswith("Name=") and name is None:
                    name = line[5:]
                elif line.startswith("Icon="):
                    icon = line[5:]
                elif line.startswith("Exec="):
                    exec_ = line[5:]
                elif line.startswith("NoDisplay=") and "true" in line.lower():
                    no_display = True
                elif line.startswith("Hidden=") and "true" in line.lower():
                    hidden = True
    except OSError:
        return None
    if not name or not exec_ or no_display or hidden:
        return None
    exec_ = re.sub(r"\s+%[a-zA-Z]\b", "", exec_).strip()
    return {"name": name, "icon": icon, "exec": exec_}


def all_apps():
    seen_basenames = set()
    apps = {}
    for d in APP_DIRS:
        for path in sorted(glob.glob(os.path.join(d, "*.desktop"))):
            base = os.path.basename(path)
            if base in seen_basenames:
                continue
            seen_basenames.add(base)
            info = parse_desktop(path)
            if info:
                apps[base] = info
    return apps


def cmd_list_available(conf):
    pinned_execs = {it["exec"] for it in conf["items"]}
    for base, info in sorted(all_apps().items(), key=lambda kv: kv[1]["name"].lower()):
        if info["exec"] in pinned_execs:
            continue
        print(f"{base}\t{info['name']}")


def cmd_add(conf, base):
    apps = all_apps()
    info = apps.get(base)
    if not info:
        sys.exit(f"application introuvable : {base}")
    item_id = re.sub(r"[^a-z0-9]+", "-", info["name"].lower()).strip("-") or "app"
    existing_ids = {it["id"] for it in conf["items"]}
    candidate, n = item_id, 2
    while candidate in existing_ids:
        candidate = f"{item_id}-{n}"
        n += 1
    conf["items"].append({"id": candidate, "label": info["name"], "exec": info["exec"],
                          "icon": info["icon"] or "", "icon_hint": [info["icon"] or ""]})


def cmd_list_current(conf):
    for it in conf["items"]:
        print(f"{it['id']}\t{it.get('label', it['id'])}")


def cmd_remove(conf, item_id):
    conf["items"] = [it for it in conf["items"] if it["id"] != item_id]


def cmd_move(conf, item_id, delta):
    ids = [it["id"] for it in conf["items"]]
    if item_id not in ids:
        return
    i = ids.index(item_id)
    j = i + delta
    if 0 <= j < len(ids):
        conf["items"][i], conf["items"][j] = conf["items"][j], conf["items"][i]


def main():
    if len(sys.argv) < 3:
        sys.exit("usage : dock-edit.py <fichier> <commande> [arguments]")
    path, command = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]
    conf = load(path)

    if command == "get-size":
        print(conf["icon_size"])
        return
    if command == "set-size":
        conf["icon_size"] = max(22, min(72, int(args[0])))
    elif command == "list-current":
        cmd_list_current(conf)
        return
    elif command == "list-available":
        cmd_list_available(conf)
        return
    elif command == "add":
        cmd_add(conf, args[0])
    elif command == "remove":
        cmd_remove(conf, args[0])
    elif command == "move-up":
        cmd_move(conf, args[0], -1)
    elif command == "move-down":
        cmd_move(conf, args[0], 1)
    else:
        sys.exit(f"commande inconnue : {command}")
    save(path, conf)


if __name__ == "__main__":
    main()
