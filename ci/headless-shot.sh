#!/bin/bash
# Lance le bureau de l'image dans un compositeur sans écran (rendu logiciel) et prend une capture.
# Usage (dans le chroot, en root) : headless-shot.sh <utilisateur> <sortie.png> [secondes]
U="$1"; OUT="$2"; WAIT="${3:-25}"
UID_N="$(id -u "$U")"
export XDG_RUNTIME_DIR="/run/user/$UID_N"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"; chown "$U" "$XDG_RUNTIME_DIR"
cat > /tmp/session.sh <<'S'
export WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman LIBSEAT_BACKEND=noop
export XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=labwc:wlroots LANG=fr_FR.UTF-8
cd "$HOME"
exec dbus-run-session -- ${SESSION_CMD:-/usr/bin/labwc-pi} > /tmp/session.log 2>&1
S
chmod 755 /tmp/session.sh
runuser -u "$U" -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" SESSION_CMD="$SESSION_CMD" HOME="$(getent passwd "$U" | cut -d: -f6)" bash /tmp/session.sh &
sleep 6
W="$(ls "$XDG_RUNTIME_DIR" | grep -E '^wayland-[0-9]+$' | head -1)"
echo "socket wayland : ${W:-aucune}"
RU() { runuser -u "$U" -- env XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" WAYLAND_DISPLAY="$W" "$@"; }
RU wlr-randr --output HEADLESS-1 --custom-mode 1920x1080 || RU wlr-randr || true
sleep "$WAIT"
RU wlr-randr | head -5 || true
RU grim "$OUT.tmp.png" && mv "$OUT.tmp.png" "$OUT" && echo "capture : $OUT"
[ -n "$SHOT_HOOK" ] && RU bash -c "$SHOT_HOOK"
echo "--- journal de session (fin)"; tail -40 /tmp/session.log
pkill -u "$U" || true
sleep 1
