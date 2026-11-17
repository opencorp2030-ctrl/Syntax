"""Fonctions partagées de Syntax OS (portail Syntax Connect + commande `syntax`)."""
import json
import os
import pwd
import re
import shutil
import socket
import subprocess
import time

ETC = os.environ.get("SYNTAX_ETC", "/etc/syntax")
LIB = os.environ.get("SYNTAX_LIB", "/usr/lib/syntax")
SHADOW = os.environ.get("SYNTAX_SHADOW", "/etc/shadow")
BOOT_CONF = os.environ.get("SYNTAX_BOOT_CONF", "/boot/firmware/syntax.conf")
CMDLINE = os.environ.get("SYNTAX_CMDLINE", "/boot/firmware/cmdline.txt")

TOKEN_FILE = os.path.join(ETC, "tunnel.token")
CF_DIR = os.path.join(ETC, ".cloudflared")  # = $HOME/.cloudflared de cloudflared
CF_CONFIG = os.path.join(CF_DIR, "config.yml")
CF_CERT = os.path.join(CF_DIR, "cert.pem")
PORTAL_CONF = os.path.join(ETC, "portal.conf")
TUNNEL_UNIT = "syntax-tunnel.service"

HOSTNAME_RE = re.compile(r"^(?=.{4,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")
TOKEN_RE = re.compile(r"eyJ[A-Za-z0-9_=-]{40,}")
HEADLESS_ARG = "video=HDMI-A-1:1920x1080@60D"


# ---------------------------------------------------------------- utilitaires
def run(cmd, timeout=60, env=None, input=None):
    """Exécute une commande, renvoie (code, sortie combinée)."""
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, env=env, input=input, text=True)
        return p.returncode, p.stdout.strip()
    except FileNotFoundError:
        return 127, f"{cmd[0]}: commande introuvable"
    except subprocess.TimeoutExpired:
        return 124, f"{cmd[0]}: délai dépassé"


def read_file(path, default=""):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return default


def write_private(path, content):
    os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(content)


def portal_port():
    m = re.search(r"^\s*PORT\s*=\s*(\d+)", read_file(PORTAL_CONF), re.M)
    return int(m.group(1)) if m else 80


# ------------------------------------------------------------- mots de passe
def default_hash():
    return read_file(os.path.join(LIB, "default-hash")).strip()


def shadow_hash(user):
    for line in read_file(SHADOW).splitlines():
        parts = line.split(":")
        if len(parts) > 1 and parts[0] == user:
            return parts[1]
    return ""


def has_default_password(user):
    d = default_hash()
    return bool(d) and shadow_hash(user) == d


def human_users():
    return [p.pw_name for p in pwd.getpwall()
            if 1000 <= p.pw_uid < 60000 and not p.pw_shell.endswith(("nologin", "false"))]


def any_default_password():
    return any(has_default_password(u) for u in human_users())


def check_new_password(new, old=""):
    """Renvoie un message d'erreur, ou None si le mot de passe est acceptable."""
    if len(new) < 10:
        return "Le mot de passe doit contenir au moins 10 caractères."
    if new == old or new.lower() in ("syntax", "raspberry"):
        return "Choisis un mot de passe différent de l'ancien."
    if len(set(new)) < 5:
        return "Mot de passe trop simple."
    if ":" in new or "\n" in new or "\r" in new:
        return "Caractère non autorisé dans le mot de passe."
    return None


def set_password(user, new):
    code, out = run(["chpasswd"], input=f"{user}:{new}\n")
    return code == 0, out


# ----------------------------------------------------------------- comptes
USERNAME_RE = re.compile(r"^[a-z][a-z0-9-]{0,31}$")
RESERVED_USERS = {"root", "syntax", "satisreader", "vnc", "pi"}


def list_accounts():
    accounts = []
    for name in human_users():
        try:
            p = pwd.getpwnam(name)
        except KeyError:
            continue
        groups = run(["id", "-nG", name])[1].split()
        accounts.append({
            "username": name,
            "admin": "sudo" in groups,
            "default_password": has_default_password(name),
        })
    return sorted(accounts, key=lambda a: a["username"])


def create_account(username, password, admin=True):
    username = (username or "").strip().lower()
    if not USERNAME_RE.match(username):
        return False, "Identifiant invalide : lettres minuscules, chiffres et tirets, 32 caractères maximum, doit commencer par une lettre."
    if username in RESERVED_USERS:
        return False, "Cet identifiant est réservé."
    if username in human_users():
        return False, "Ce compte existe déjà."
    err = check_new_password(password)
    if err:
        return False, err
    groups = ["sudo"] if admin else []
    for g in ("docker", "plugdev", "video", "audio", "input", "systemd-journal"):
        if run(["getent", "group", g])[0] == 0:
            groups.append(g)
    code, out = run(["useradd", "-m", "-s", "/bin/bash", "-G", ",".join(groups), username])
    if code != 0:
        return False, out or "Échec de la création du compte."
    ok, out = set_password(username, password)
    if not ok:
        run(["userdel", "-r", username])
        return False, out or "Échec de l'initialisation du mot de passe."
    return True, f"Compte « {username} » créé."


def delete_account(username, keep_home=False):
    if username not in human_users():
        return False, "Ce compte n'existe pas."
    if len(human_users()) <= 1:
        return False, "Impossible de supprimer le dernier compte."
    cmd = ["userdel"] if keep_home else ["userdel", "-r"]
    code, out = run(cmd + [username], timeout=30)
    if code != 0:
        return False, out or "Échec de la suppression."
    return True, f"Compte « {username} » supprimé."


def admin_reset_password(username, new):
    if username not in human_users():
        return False, "Ce compte n'existe pas."
    err = check_new_password(new)
    if err:
        return False, err
    ok, out = set_password(username, new)
    return ok, (f"Mot de passe de « {username} » réinitialisé." if ok else (out or "Échec."))


# ----------------------------------------------------------------- système
def system_status():
    st = {"hostname": socket.gethostname(), "time": int(time.time())}
    st["model"] = read_file("/proc/device-tree/model").strip("\x00\n ") or "Inconnu"
    osr = dict(l.split("=", 1) for l in read_file("/etc/os-release").splitlines() if "=" in l)
    st["os"] = osr.get("PRETTY_NAME", "Syntax OS").strip('"')
    st["kernel"] = os.uname().release
    try:
        st["uptime"] = int(float(read_file("/proc/uptime").split()[0]))
    except (IndexError, ValueError):
        st["uptime"] = 0
    try:
        st["load"] = [round(x, 2) for x in os.getloadavg()]
    except OSError:
        st["load"] = [0, 0, 0]
    st["cpus"] = os.cpu_count() or 1
    mem = {}
    for line in read_file("/proc/meminfo").splitlines():
        k, _, v = line.partition(":")
        try:
            mem[k] = int(v.split()[0]) * 1024
        except (IndexError, ValueError):
            pass
    st["mem_total"] = mem.get("MemTotal", 0)
    st["mem_used"] = st["mem_total"] - mem.get("MemAvailable", 0)
    try:
        du = shutil.disk_usage("/")
        st["disk_total"], st["disk_used"] = du.total, du.used
    except OSError:
        st["disk_total"] = st["disk_used"] = 0
    try:
        st["temp"] = round(int(read_file("/sys/class/thermal/thermal_zone0/temp")) / 1000, 1)
    except ValueError:
        st["temp"] = None
    st["ips"] = local_ips()
    return st


def local_ips():
    code, out = run(["ip", "-j", "-4", "addr", "show", "scope", "global"], timeout=5)
    ips = []
    if code == 0:
        try:
            for dev in json.loads(out):
                for a in dev.get("addr_info", []):
                    if not dev.get("ifname", "").startswith(("docker", "br-", "veth")):
                        ips.append({"dev": dev.get("ifname"), "ip": a.get("local")})
        except ValueError:
            pass
    return ips


def power(action):
    if action not in ("reboot", "poweroff"):
        return False
    subprocess.Popen(["systemctl", "--no-block", action])
    return True


# -------------------------------------------------- tunnel Cloudflare (accès Internet)
def cloudflared_installed():
    return shutil.which("cloudflared") is not None


def tunnel_mode():
    if os.path.exists(TOKEN_FILE):
        return "token"
    if os.path.exists(CF_CONFIG):
        return "named"
    return "none"


def tunnel_hostname():
    m = re.search(r"^\s*-?\s*hostname:\s*(\S+)", read_file(CF_CONFIG), re.M)
    return m.group(1) if m else ""


def tunnel_status():
    active = run(["systemctl", "is-active", TUNNEL_UNIT], timeout=5)[1]
    enabled = run(["systemctl", "is-enabled", TUNNEL_UNIT], timeout=5)[1]
    mode = tunnel_mode()
    return {
        "installed": cloudflared_installed(),
        "mode": mode,
        "active": active == "active",
        "state": active,
        "enabled": enabled == "enabled",
        "hostname": tunnel_hostname() if mode == "named" else "",
        "blocked_default_password": any_default_password(),
        "port": portal_port(),
    }


def tunnel_enable():
    run(["systemctl", "enable", TUNNEL_UNIT])
    run(["systemctl", "restart", "--no-block", TUNNEL_UNIT])


def tunnel_disable():
    run(["systemctl", "disable", "--now", TUNNEL_UNIT])


def tunnel_set_token(raw):
    """Active le tunnel avec un jeton créé dans le tableau de bord Cloudflare."""
    m = TOKEN_RE.search(raw or "")
    if not m:
        return False, "Jeton invalide : colle le jeton (ou la commande complète) fourni par Cloudflare."
    write_private(TOKEN_FILE, m.group(0) + "\n")
    try:
        os.remove(CF_CONFIG)
    except OSError:
        pass
    tunnel_enable()
    return True, "Tunnel activé."


def tunnel_reset():
    tunnel_disable()
    for p in (TOKEN_FILE, CF_CONFIG):
        try:
            os.remove(p)
        except OSError:
            pass
    return True


def _cf_env():
    env = dict(os.environ)
    env["TUNNEL_ORIGIN_CERT"] = CF_CERT
    env["HOME"] = ETC
    return env


def tunnel_login_command():
    """Commande + environnement pour `cloudflared tunnel login` (affiche une URL d'autorisation)."""
    os.makedirs(CF_DIR, mode=0o700, exist_ok=True)
    try:
        os.remove(CF_CERT)
    except OSError:
        pass
    return ["cloudflared", "tunnel", "login"], _cf_env()


def tunnel_logged_in():
    return os.path.exists(CF_CERT)


def tunnel_create_named(hostname):
    """Après `login` : crée le tunnel, la route DNS et la configuration, puis démarre."""
    hostname = (hostname or "").strip().lower()
    if not HOSTNAME_RE.match(hostname):
        return False, "Nom de domaine invalide (exemple : syntax.mondomaine.fr)."
    if not tunnel_logged_in():
        return False, "Connexion Cloudflare non terminée."
    env = _cf_env()
    name = "syntax-" + re.sub(r"[^a-z0-9-]", "-", socket.gethostname().lower())
    creds = os.path.join(CF_DIR, "credentials.json")
    code, out = run(["cloudflared", "tunnel", "info", name], env=env)
    if code == 0 and not os.path.exists(creds):
        # Un ancien tunnel du même nom existe sans ses identifiants locaux : on le remplace.
        run(["cloudflared", "tunnel", "delete", "-f", name], env=env)
        code = 1
    if code != 0:
        try:
            os.remove(creds)
        except OSError:
            pass
        code, out = run(["cloudflared", "tunnel", "create", "--credentials-file", creds, name],
                        env=env, timeout=120)
        if code != 0:
            return False, "Création du tunnel impossible : " + out[-400:]
    code, out = run(["cloudflared", "tunnel", "route", "dns", "--overwrite-dns", name, hostname],
                    env=env, timeout=120)
    if code != 0:
        return False, "Création de l'enregistrement DNS impossible : " + out[-400:]
    write_private(CF_CONFIG, (
        f"tunnel: {name}\n"
        f"credentials-file: {creds}\n"
        "ingress:\n"
        f"  - hostname: {hostname}\n"
        f"    service: http://127.0.0.1:{portal_port()}\n"
        "  - service: http_status:404\n"))
    try:
        os.remove(TOKEN_FILE)
    except OSError:
        pass
    tunnel_enable()
    return True, f"Tunnel activé : https://{hostname}"


# ------------------------------------------------------------- mode sans écran
# Avant la 1.3, un réglage forçait un mode vidéo fixe sur HDMI-0 pour les Pi sans
# moniteur. Il a été retiré : forcer un mode peut rester actif même quand un vrai
# moniteur est ensuite branché sur ce port, et si ce mode ne lui convient pas l'image
# disparaît complètement (c'est ce qui est arrivé). labwc fournit déjà, sans aucun
# réglage, une sortie de secours qui ne s'active que lorsqu'il n'y a vraiment aucun
# écran — jamais en plus d'un écran réel.
def headless_enabled():
    return False


def set_headless(_on):
    return True


# ---------------------------------------- configuration déposée sur la partition de boot
def parse_boot_conf(text):
    conf = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        v = v.strip()
        if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
            v = v[1:-1]
        if v:
            conf[k.strip().upper()] = v
    return conf


SECRET_KEYS = ("WIFI_PASSWORD", "CF_TUNNEL_TOKEN")


def scrub_boot_conf(text):
    """Efface les secrets du fichier (la partition de boot est lisible par tous)."""
    out = []
    for line in text.splitlines():
        s = line.strip()
        key = s.split("=", 1)[0].strip().upper() if "=" in s and not s.startswith("#") else ""
        if key in SECRET_KEYS:
            out.append(f"# {key}=  (appliqué puis effacé par Syntax OS)")
        else:
            out.append(line)
    return "\n".join(out) + "\n"


def apply_boot_config(log=print):
    text = read_file(BOOT_CONF)
    conf = parse_boot_conf(text)
    marker = "/var/lib/syntax/wifi-country-set"
    country = conf.get("WIFI_COUNTRY", "")
    if re.fullmatch(r"[A-Za-z]{2}", country) or not os.path.exists(marker):
        country = country.upper() if re.fullmatch(r"[A-Za-z]{2}", country) else "FR"
        log(f"Pays Wi-Fi : {country}")
        run(["raspi-config", "nonint", "do_wifi_country", country])
        run(["rfkill", "unblock", "wifi"])
        os.makedirs(os.path.dirname(marker), exist_ok=True)
        open(marker, "w").close()
    host = conf.get("HOSTNAME", "").lower()
    if host and re.fullmatch(r"[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?", host) and host != socket.gethostname():
        log(f"Nom de la machine : {host}")
        run(["raspi-config", "nonint", "do_hostname", host])
        run(["hostnamectl", "set-hostname", host])
    ssid, psk = conf.get("WIFI_SSID"), conf.get("WIFI_PASSWORD")
    already = run(["nmcli", "-t", "-f", "NAME", "connection", "show"])[1].splitlines()
    # Avec mot de passe : (re)création. Sans mot de passe : réseau ouvert, créé une seule fois.
    if ssid and (psk or ("syntax-wifi" not in already and "WIFI_PASSWORD=  (appliqué" not in text)):
        log(f"Wi-Fi : {ssid}")
        run(["nmcli", "connection", "delete", "syntax-wifi"])
        cmd = ["nmcli", "connection", "add", "type", "wifi", "con-name", "syntax-wifi",
               "ssid", ssid, "connection.autoconnect", "yes"]
        if psk:
            cmd += ["wifi-sec.key-mgmt", "wpa-psk", "wifi-sec.psk", psk]
        code, out = run(cmd)
        if code != 0:
            log("Wi-Fi : échec — " + out)
        else:
            run(["nmcli", "connection", "up", "syntax-wifi"], timeout=45)
    if conf.get("ENABLE_SSH", "").lower() in ("1", "yes", "true", "oui"):
        log("SSH activé")
        run(["systemctl", "enable", "--now", "ssh"])
    if "HEADLESS" in conf:
        log("HEADLESS n'est plus utilisé depuis la 1.3 (sortie de secours automatique sans réglage).")
    if conf.get("CF_TUNNEL_TOKEN"):
        ok, msg = tunnel_set_token(conf["CF_TUNNEL_TOKEN"])
        log("Tunnel Cloudflare : " + msg)
    if any(k in conf for k in SECRET_KEYS):
        try:
            with open(BOOT_CONF, "w", encoding="utf-8") as f:
                f.write(scrub_boot_conf(text))
        except OSError as e:
            log(f"Impossible d'effacer les secrets de {BOOT_CONF} : {e}")
