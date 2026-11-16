#!/usr/bin/env python3
"""Commande `syntax` : administration de Syntax OS depuis le terminal."""
import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
import syntaxlib as lib  # noqa: E402


def need_root():
    if os.geteuid() != 0:
        os.execvp("sudo", ["sudo", os.path.realpath(sys.argv[0])] + sys.argv[1:])


def cmd_status(_a):
    s = lib.system_status()
    gb = lambda n: f"{n / 2**30:.1f} Go"  # noqa: E731
    print(f"{s['os']} — {s['hostname']}")
    print(f"  Modèle      : {s['model']}")
    print(f"  Noyau       : {s['kernel']}")
    print(f"  Température : {s['temp']} °C" if s["temp"] is not None else "  Température : –")
    print(f"  Mémoire     : {gb(s['mem_used'])} / {gb(s['mem_total'])}")
    print(f"  Stockage    : {gb(s['disk_used'])} / {gb(s['disk_total'])}")
    port = lib.portal_port()
    suffix = "" if port == 80 else f":{port}"
    for ip in s["ips"]:
        print(f"  Portail     : http://{ip['ip']}{suffix}  ({ip['dev']})")
    print(f"  Portail     : http://{s['hostname']}.local{suffix}")
    if os.geteuid() == 0:
        t = lib.tunnel_status()
        etat = "actif" if t["active"] else ("non configuré" if t["mode"] == "none" else t["state"])
        print(f"  Accès Internet (tunnel Cloudflare) : {etat}" + (f" — https://{t['hostname']}" if t["hostname"] else ""))


def cmd_connect(a):
    need_root()
    if a.action == "status":
        t = lib.tunnel_status()
        for k in ("installed", "mode", "enabled", "state", "hostname", "blocked_default_password"):
            print(f"{k:26}: {t[k]}")
    elif a.action == "token":
        if not a.value:
            sys.exit("Usage : syntax connect token <jeton>")
        ok, msg = lib.tunnel_set_token(a.value)
        print(msg)
        sys.exit(0 if ok else 1)
    elif a.action == "login":
        if not a.value:
            sys.exit("Usage : syntax connect login <adresse, ex. syntax.mondomaine.fr>")
        if not lib.HOSTNAME_RE.match(a.value.lower()):
            sys.exit("Nom de domaine invalide.")
        cmd, env = lib.tunnel_login_command()
        print("Ouvre le lien affiché ci-dessous dans un navigateur et autorise ton domaine :\n")
        if subprocess.call(cmd, env=env) != 0 or not lib.tunnel_logged_in():
            sys.exit("Connexion Cloudflare annulée ou échouée.")
        ok, msg = lib.tunnel_create_named(a.value)
        print(msg)
        sys.exit(0 if ok else 1)
    elif a.action == "on":
        if lib.tunnel_mode() == "none":
            sys.exit("Aucun tunnel configuré : utilise « syntax connect login » ou « syntax connect token ».")
        lib.tunnel_enable()
        print("Tunnel activé.")
    elif a.action == "off":
        lib.tunnel_disable()
        print("Tunnel suspendu.")
    elif a.action == "reset":
        lib.tunnel_reset()
        print("Configuration du tunnel supprimée.")


def cmd_headless(a):
    need_root()
    if a.state in ("on", "off"):
        lib.set_headless(a.state == "on")
        print("Modification appliquée au prochain redémarrage.")
    print("Écran virtuel 1080p :", "activé" if lib.headless_enabled() else "désactivé")


def cmd_ai(_a):
    print("Installation d'Ollama (modèles d'IA locaux)…")
    rc = subprocess.call("curl -fsSL https://ollama.com/install.sh | sh", shell=True)
    if rc == 0:
        print("\nOllama est installé. Exemple :  ollama run gemma3:1b")
        print("Assistant de code dans le terminal :  claude")
    sys.exit(rc)


def cmd_update(_a):
    need_root()
    sys.exit(subprocess.call("apt-get update && apt-get -y full-upgrade", shell=True))


def cmd_self_update(_a):
    need_root()
    sys.exit(subprocess.call(["/usr/lib/syntax/selfupdate.sh"]))


def cmd_apply(_a):
    need_root()
    lib.apply_boot_config()


def cmd_guard(_a):
    # Code 0 si un compte utilise encore le mot de passe d'usine.
    sys.exit(0 if lib.any_default_password() else 1)


def main():
    p = argparse.ArgumentParser(prog="syntax", description="Administration de Syntax OS")
    sub = p.add_subparsers(dest="cmd")
    sub.add_parser("status", help="état du système et adresses du portail").set_defaults(fn=cmd_status)
    c = sub.add_parser("connect", help="accès par Internet (tunnel Cloudflare)")
    c.add_argument("action", choices=["status", "login", "token", "on", "off", "reset"])
    c.add_argument("value", nargs="?")
    c.set_defaults(fn=cmd_connect)
    h = sub.add_parser("headless", help="écran virtuel pour une utilisation sans moniteur")
    h.add_argument("state", nargs="?", choices=["on", "off"])
    h.set_defaults(fn=cmd_headless)
    sub.add_parser("ai", help="installer Ollama pour faire tourner des modèles d'IA en local").set_defaults(fn=cmd_ai)
    sub.add_parser("update", help="mettre à jour le système").set_defaults(fn=cmd_update)
    sub.add_parser("self-update", help="mettre à jour Syntax OS depuis la dernière version GitHub (automatique chaque jour)").set_defaults(fn=cmd_self_update)
    sub.add_parser("apply-boot-config").set_defaults(fn=cmd_apply)
    sub.add_parser("has-default-password").set_defaults(fn=cmd_guard)
    a = p.parse_args()
    if not a.cmd:
        a.fn = cmd_status
    a.fn(a)


if __name__ == "__main__":
    main()
