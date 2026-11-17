#!/usr/bin/env python3
"""Syntax Connect — portail web de Syntax OS : écran, terminal et état du Pi dans le navigateur."""
import asyncio
import fcntl
import ipaddress
import json
import logging
import os
import pty
import pwd
import re
import secrets
import signal
import struct
import sys
import termios
import time
from urllib.parse import urlsplit

from aiohttp import WSMsgType, web

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import syntaxlib as lib  # noqa: E402

try:
    import pamauth
except OSError:  # libpam absente (poste de développement)
    pamauth = None

log = logging.getLogger("syntax-connect")
STATIC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "static")
COOKIE = "syntax_session"
SESSION_IDLE = 12 * 3600
SESSION_MAX = 7 * 24 * 3600
MAX_FAILS = 5
FAIL_WINDOW = 600

sessions = {}   # jeton -> {"user", "created", "seen", "csrf"}
failures = {}   # ip -> [horodatages]
login_proc = {"proc": None, "url": "", "output": ""}


# ------------------------------------------------------------------ helpers
def client_ip(request):
    peer = request.remote or ""
    try:
        if ipaddress.ip_address(peer).is_loopback:
            # Derrière cloudflared (qui tourne en local) : IP réelle fournie par Cloudflare.
            fwd = request.headers.get("CF-Connecting-IP")
            if fwd:
                return fwd.strip()[:64]
    except ValueError:
        pass
    return peer


def is_https(request):
    return request.headers.get("X-Forwarded-Proto", "").lower() == "https" or request.secure


def too_many_failures(ip):
    now = time.time()
    lst = [t for t in failures.get(ip, []) if now - t < FAIL_WINDOW]
    if lst:
        failures[ip] = lst
    else:
        failures.pop(ip, None)
    total = sum(len(v) for v in failures.values())
    return len(lst) >= MAX_FAILS or total >= 60


def record_failure(ip):
    failures.setdefault(ip, []).append(time.time())
    if len(failures) > 5000:
        failures.clear()


def valid_user(name):
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", name or ""):
        return False
    try:
        p = pwd.getpwnam(name)
    except KeyError:
        return False
    return 1000 <= p.pw_uid < 60000


def get_session(request):
    tok = request.cookies.get(COOKIE)
    s = sessions.get(tok) if tok else None
    if not s:
        return None
    now = time.time()
    if now - s["seen"] > SESSION_IDLE or now - s["created"] > SESSION_MAX:
        sessions.pop(tok, None)
        return None
    s["seen"] = now
    return s


def same_origin(request):
    origin = request.headers.get("Origin")
    if not origin:
        return request.method == "GET" and "Upgrade" not in request.headers
    return urlsplit(origin).netloc.lower() == request.host.lower()


def jerr(msg, status=400):
    return web.json_response({"ok": False, "error": msg}, status=status)


async def body(request):
    try:
        data = await request.json()
        return data if isinstance(data, dict) else {}
    except (ValueError, UnicodeDecodeError):
        return {}


async def in_thread(fn, *args):
    return await asyncio.get_running_loop().run_in_executor(None, fn, *args)


@web.middleware
async def guard(request, handler):
    path = request.path
    if path.startswith(("/api/", "/ws/")):
        if request.method != "GET" or path.startswith("/ws/"):
            if not same_origin(request):
                return jerr("Origine refusée.", 403)
        if path not in ("/api/login", "/api/session"):
            s = get_session(request)
            if not s:
                return jerr("Non connecté.", 401)
            request["session"] = s
    resp = await handler(request)
    if not isinstance(resp, web.WebSocketResponse):
        resp.headers.setdefault("X-Content-Type-Options", "nosniff")
        resp.headers.setdefault("X-Frame-Options", "DENY")
        resp.headers.setdefault("Referrer-Policy", "no-referrer")
        resp.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; "
            "connect-src 'self' ws: wss:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'")
        if path.startswith("/api/"):
            resp.headers["Cache-Control"] = "no-store"
    return resp


# ------------------------------------------------------------------- auth
async def api_login(request):
    ip = client_ip(request)
    if too_many_failures(ip):
        return jerr("Trop de tentatives. Réessaie dans quelques minutes.", 429)
    data = await body(request)
    user = str(data.get("username", "")).strip()
    password = str(data.get("password", ""))
    new_password = data.get("new_password")
    ok = False
    if valid_user(user) and password and len(password) < 512 and pamauth:
        ok = await in_thread(pamauth.authenticate, user, password, "syntax-portal", ip)
    if not ok:
        record_failure(ip)
        log.warning("Échec de connexion pour %r depuis %s", user[:32], ip)
        await asyncio.sleep(1)
        return jerr("Identifiant ou mot de passe incorrect.", 401)
    if lib.has_default_password(user):
        # Le mot de passe d'usine doit être remplacé avant toute ouverture de session.
        if not isinstance(new_password, str):
            return web.json_response({"ok": False, "must_change": True,
                                      "error": "Choisis un nouveau mot de passe pour continuer."}, status=403)
        err = lib.check_new_password(new_password, password)
        if err:
            return web.json_response({"ok": False, "must_change": True, "error": err}, status=403)
        done, out = await in_thread(lib.set_password, user, new_password)
        if not done:
            return jerr("Impossible de changer le mot de passe : " + out, 500)
        log.info("Mot de passe d'usine remplacé pour %s", user)
    failures.pop(ip, None)
    tok = secrets.token_urlsafe(32)
    now = time.time()
    sessions[tok] = {"user": user, "created": now, "seen": now}
    for k in [k for k, v in sessions.items() if now - v["seen"] > SESSION_IDLE]:
        sessions.pop(k, None)
    log.info("Connexion de %s depuis %s", user, ip)
    resp = web.json_response({"ok": True, "user": user})
    resp.set_cookie(COOKIE, tok, httponly=True, samesite="Strict", secure=is_https(request),
                    max_age=SESSION_MAX, path="/")
    return resp


async def api_session(request):
    s = get_session(request)
    return web.json_response({"ok": True, "user": s["user"] if s else None,
                              "hostname": os.uname().nodename})


async def api_logout(request):
    sessions.pop(request.cookies.get(COOKIE), None)
    resp = web.json_response({"ok": True})
    resp.del_cookie(COOKIE, path="/")
    return resp


async def api_password(request):
    data = await body(request)
    user = request["session"]["user"]
    old, new = str(data.get("old", "")), str(data.get("new", ""))
    ip = client_ip(request)
    if too_many_failures(ip):
        return jerr("Trop de tentatives.", 429)
    if not (pamauth and await in_thread(pamauth.authenticate, user, old, "syntax-portal", ip)):
        record_failure(ip)
        return jerr("Mot de passe actuel incorrect.", 403)
    err = lib.check_new_password(new, old)
    if err:
        return jerr(err)
    done, out = await in_thread(lib.set_password, user, new)
    if not done:
        return jerr(out or "Échec.", 500)
    keep = request.cookies.get(COOKIE)
    for k in [k for k, v in sessions.items() if v["user"] == user and k != keep]:
        sessions.pop(k, None)
    return web.json_response({"ok": True})


# ------------------------------------------------------------------ comptes
async def api_accounts(request):
    return web.json_response({"ok": True, "accounts": await in_thread(lib.list_accounts),
                              "you": request["session"]["user"]})


async def api_accounts_create(request):
    data = await body(request)
    ok, msg = await in_thread(lib.create_account, str(data.get("username", "")),
                              str(data.get("password", "")), bool(data.get("admin", True)))
    return web.json_response({"ok": ok, "message" if ok else "error": msg}, status=200 if ok else 400)


async def api_accounts_delete(request):
    data = await body(request)
    username = str(data.get("username", ""))
    if username == request["session"]["user"]:
        return jerr("Impossible de supprimer le compte avec lequel tu es connecté.")
    ok, msg = await in_thread(lib.delete_account, username)
    if ok:
        for k in [k for k, v in sessions.items() if v["user"] == username]:
            sessions.pop(k, None)
    return web.json_response({"ok": ok, "message" if ok else "error": msg}, status=200 if ok else 400)


async def api_accounts_reset(request):
    data = await body(request)
    username = str(data.get("username", ""))
    ok, msg = await in_thread(lib.admin_reset_password, username, str(data.get("password", "")))
    if ok:
        keep = request.cookies.get(COOKIE)
        for k in [k for k, v in sessions.items() if v["user"] == username and k != keep]:
            sessions.pop(k, None)
    return web.json_response({"ok": ok, "message" if ok else "error": msg}, status=200 if ok else 400)


# ------------------------------------------------------------------ système
async def api_status(request):
    st = await in_thread(lib.system_status)
    st["user"] = request["session"]["user"]
    st["screen"] = os.path.exists(screen_socket(request["session"]["user"]))
    return web.json_response(st)


async def api_power(request):
    data = await body(request)
    if not lib.power(str(data.get("action", ""))):
        return jerr("Action inconnue.")
    return web.json_response({"ok": True})


# ------------------------------------------------------------------- tunnel
async def api_tunnel(request):
    st = await in_thread(lib.tunnel_status)
    p = login_proc["proc"]
    st["login"] = {"running": bool(p and p.returncode is None), "url": login_proc["url"],
                   "done": lib.tunnel_logged_in()}
    return web.json_response(st)


async def api_tunnel_token(request):
    data = await body(request)
    ok, msg = await in_thread(lib.tunnel_set_token, str(data.get("token", "")))
    return web.json_response({"ok": ok, "message": msg} if ok else {"ok": False, "error": msg},
                             status=200 if ok else 400)


async def _read_login_output(proc):
    while True:
        line = await proc.stdout.readline()
        if not line:
            break
        text = line.decode("utf-8", "replace")
        login_proc["output"] = (login_proc["output"] + text)[-4000:]
        m = re.search(r"https://dash\.cloudflare\.com/argotunnel\S+", text)
        if m:
            login_proc["url"] = m.group(0)
    await proc.wait()


async def api_tunnel_login_start(request):
    if not lib.cloudflared_installed():
        return jerr("cloudflared n'est pas installé.", 500)
    p = login_proc["proc"]
    if p and p.returncode is None:
        p.terminate()
    cmd, env = lib.tunnel_login_command()
    login_proc.update(url="", output="")
    proc = await asyncio.create_subprocess_exec(
        *cmd, env=env, stdin=asyncio.subprocess.DEVNULL,
        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT)
    login_proc["proc"] = proc
    asyncio.create_task(_read_login_output(proc))
    for _ in range(100):
        if login_proc["url"] or proc.returncode is not None:
            break
        await asyncio.sleep(0.2)
    if not login_proc["url"]:
        return jerr("Cloudflare n'a pas fourni de lien : " + login_proc["output"][-300:], 500)
    return web.json_response({"ok": True, "url": login_proc["url"]})


async def api_tunnel_login_finish(request):
    data = await body(request)
    ok, msg = await in_thread(lib.tunnel_create_named, str(data.get("hostname", "")))
    return web.json_response({"ok": ok, "message": msg} if ok else {"ok": False, "error": msg},
                             status=200 if ok else 400)


async def api_tunnel_disable(request):
    data = await body(request)
    await in_thread(lib.tunnel_reset if data.get("reset") else lib.tunnel_disable)
    return web.json_response({"ok": True})


async def api_tunnel_enable(request):
    if lib.tunnel_mode() == "none":
        return jerr("Aucun tunnel configuré.")
    await in_thread(lib.tunnel_enable)
    return web.json_response({"ok": True})


# ----------------------------------------------------------------- terminal
def _spawn_shell(user):
    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.closerange(3, 4096)
            env = {"TERM": "xterm-256color", "LANG": os.environ.get("LANG", "fr_FR.UTF-8"),
                   "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"}
            if os.geteuid() == 0:
                os.execvpe("su", ["su", "-l", user], env)
            os.execvpe("bash", ["bash", "-l"], env)  # mode développement, sans root
        finally:
            os._exit(127)
    return pid, fd


async def ws_term(request):
    user = request["session"]["user"]
    ws = web.WebSocketResponse(heartbeat=30, max_msg_size=1 << 20)
    await ws.prepare(request)
    loop = asyncio.get_running_loop()
    pid, fd = _spawn_shell(user)
    os.set_blocking(fd, False)
    queue = asyncio.Queue()

    def on_readable():
        try:
            data = os.read(fd, 65536)
        except BlockingIOError:
            return
        except OSError:
            data = b""
        queue.put_nowait(data)
        if not data:
            loop.remove_reader(fd)

    loop.add_reader(fd, on_readable)

    async def pump():
        while True:
            data = await queue.get()
            if not data:
                break
            await ws.send_bytes(data)
        await ws.close()

    task = asyncio.create_task(pump())
    try:
        async for msg in ws:
            if msg.type == WSMsgType.BINARY:
                await loop.run_in_executor(None, _write_all, fd, msg.data)
            elif msg.type == WSMsgType.TEXT:
                try:
                    m = json.loads(msg.data)
                    if m.get("type") == "resize":
                        rows = max(2, min(500, int(m["rows"])))
                        cols = max(2, min(1000, int(m["cols"])))
                        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
                    elif m.get("type") == "input":
                        await loop.run_in_executor(None, _write_all, fd, str(m["data"]).encode())
                except (ValueError, KeyError, TypeError, OSError):
                    pass
            else:
                break
    finally:
        task.cancel()
        try:
            loop.remove_reader(fd)
        except (ValueError, OSError):
            pass
        try:
            os.kill(pid, signal.SIGHUP)
        except ProcessLookupError:
            pass
        os.close(fd)
        loop.run_in_executor(None, _reap, pid)
    return ws


def _write_all(fd, data):
    os.set_blocking(fd, False)
    view = memoryview(data)
    deadline = time.time() + 10
    while view and time.time() < deadline:
        try:
            n = os.write(fd, view)
            view = view[n:]
        except BlockingIOError:
            time.sleep(0.01)
        except OSError:
            return


def _reap(pid):
    for _ in range(50):
        try:
            done, _status = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            return
        if done:
            return
        time.sleep(0.1)
    try:
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
    except (ProcessLookupError, ChildProcessError):
        pass


# -------------------------------------------------------------------- écran
def screen_socket(user):
    override = os.environ.get("SYNTAX_VNC_SOCKET")
    if override:
        return override
    try:
        uid = pwd.getpwnam(user).pw_uid
    except KeyError:
        uid = 0
    return f"/run/user/{uid}/syntax-screen.sock"


async def ws_screen(request):
    """Pont WebSocket <-> wayvnc (socket Unix privée de la session graphique)."""
    path = screen_socket(request["session"]["user"])
    ws = web.WebSocketResponse(protocols=("binary",), heartbeat=30, max_msg_size=8 << 20)
    await ws.prepare(request)
    reader = writer = None
    # wayvnc démarre en quelques secondes après l'ouverture de la session graphique
    # (connexion automatique, ou juste après avoir choisi son compte à l'écran de
    # connexion) : on retente un peu avant d'afficher « indisponible ».
    for attempt in range(10):
        try:
            reader, writer = await asyncio.open_unix_connection(path)
            break
        except OSError:
            if attempt == 9:
                await ws.close(code=1011, message="Session graphique indisponible".encode())
                return ws
            await asyncio.sleep(0.5)

    async def vnc_to_ws():
        try:
            while True:
                data = await reader.read(65536)
                if not data:
                    break
                await ws.send_bytes(data)
        except (ConnectionError, RuntimeError):
            pass
        await ws.close()

    task = asyncio.create_task(vnc_to_ws())
    try:
        async for msg in ws:
            if msg.type == WSMsgType.BINARY:
                writer.write(msg.data)
                await writer.drain()
            elif msg.type != WSMsgType.TEXT:
                break
    except ConnectionError:
        pass
    finally:
        task.cancel()
        writer.close()
    return ws


# --------------------------------------------------------------------- app
async def index(request):
    resp = web.FileResponse(os.path.join(STATIC, "index.html"))
    resp.headers["Cache-Control"] = "no-cache"
    return resp


def make_app():
    app = web.Application(middlewares=[guard], client_max_size=64 * 1024)
    r = app.router
    r.add_get("/", index)
    r.add_post("/api/login", api_login)
    r.add_get("/api/session", api_session)
    r.add_post("/api/logout", api_logout)
    r.add_post("/api/password", api_password)
    r.add_get("/api/accounts", api_accounts)
    r.add_post("/api/accounts/create", api_accounts_create)
    r.add_post("/api/accounts/delete", api_accounts_delete)
    r.add_post("/api/accounts/reset", api_accounts_reset)
    r.add_get("/api/status", api_status)
    r.add_post("/api/power", api_power)
    r.add_get("/api/tunnel", api_tunnel)
    r.add_post("/api/tunnel/token", api_tunnel_token)
    r.add_post("/api/tunnel/login/start", api_tunnel_login_start)
    r.add_post("/api/tunnel/login/finish", api_tunnel_login_finish)
    r.add_post("/api/tunnel/disable", api_tunnel_disable)
    r.add_post("/api/tunnel/enable", api_tunnel_enable)
    r.add_get("/ws/term", ws_term)
    r.add_get("/ws/screen", ws_screen)
    r.add_static("/static/", STATIC)
    return app


def main():
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    port = int(os.environ.get("SYNTAX_PORT") or lib.portal_port())
    host = os.environ.get("SYNTAX_BIND", "0.0.0.0")
    web.run_app(make_app(), host=host, port=port, access_log=None, print=None)


if __name__ == "__main__":
    main()
