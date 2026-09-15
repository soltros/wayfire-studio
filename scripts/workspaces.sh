#!/usr/bin/env bash
set -euo pipefail

socket="${WAYFIRE_SOCKET:-}"
if [[ -z "$socket" ]]; then
  socket=$(find "${XDG_RUNTIME_DIR:?}" /tmp -maxdepth 1 -type s -name 'wayfire-wayland-*.socket' -print -quit 2>/dev/null || true)
fi
[[ -S "$socket" ]] || { notify-send 'Workspace viewer' 'Wayfire IPC is not available yet.' || true; exit 1; }

send() {
  python3 - "$socket" "$1" <<'PY'
import json, socket, sys
path, payload = sys.argv[1:]
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
    client.connect(path)
    message = json.dumps(json.loads(payload)).encode()
    client.send(len(message).to_bytes(4, 'little') + message)
    size = int.from_bytes(client.recv(4), 'little')
    client.recv(size)
PY
}

case "${1:-view}" in
  status)
    # Waybar-friendly compact workspace strip; the overview remains dynamic.
    printf '1   2   3   4\n'
    ;;
  view)
    # Scale's all-workspaces overview gives a clean, Gnome-like spread of views.
    send '{"method":"scale/toggle_all","data":{}}'
    ;;
  manage)
    choice=$(printf '%s\n' 'Add workspace' 'Remove workspace' | wofi --dmenu --prompt 'Workspace layout') || exit 0
    [[ -n "$choice" ]] || exit 0
    current=$(python3 - "$socket" <<'PY'
import json, socket, sys
with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as c:
    c.connect(sys.argv[1]); msg=json.dumps({"method":"wayfire/get-config-option","data":{"option":"core/vwidth"}}).encode(); c.send(len(msg).to_bytes(4,'little')+msg)
    n=int.from_bytes(c.recv(4),'little'); response=json.loads(c.recv(n)); print(int(response.get('value', response.get('data', 4))))
PY
)
    if [[ "$choice" == 'Add workspace' ]]; then
      next=$((current + 1))
    else
      (( current > 1 )) || { notify-send 'Workspace layout' 'Keep at least one workspace.'; exit 0; }
      next=$((current - 1))
    fi
    send "{\"method\":\"wayfire/set-config-options\",\"data\":{\"core/vwidth\":$next}}"
    notify-send 'Workspace layout' "Now using $next workspaces."
    ;;
  *) echo 'Usage: wayfire-studio-workspaces [view|manage]' >&2; exit 2 ;;
esac
