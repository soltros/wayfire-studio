#!/usr/bin/env bash
set -euo pipefail
pids=()
cleanup() {
  trap - EXIT
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
  rm -f "${WAYFIRE_STUDIO_RUNTIME:?}/waybar.pid"
  systemctl --user stop wayfire-studio-session.target || true
  wait || true
}
trap cleanup EXIT
trap 'exit 0' TERM INT
dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE || true
systemctl --user start wayfire-studio-session.target || true
gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' || true
wayfire-studio-background-apps & pids+=("$!")
waybar -b panel -c "${WAYFIRE_STUDIO_RUNTIME:?}/waybar.json" -s '@style@' & pids+=("$!")
printf '%s\n' "$!" > "$WAYFIRE_STUDIO_RUNTIME/waybar.pid"
waybar -b sidebar -c "${WAYFIRE_STUDIO_RUNTIME:?}/waybar.json" -s '@style@' & pids+=("$!")
printf '%s\n' "$!" >> "$WAYFIRE_STUDIO_RUNTIME/waybar.pid"
waybar -b dock -c "${WAYFIRE_STUDIO_RUNTIME:?}/waybar.json" -s '@style@' & pids+=("$!")
printf '%s\n' "$!" >> "$WAYFIRE_STUDIO_RUNTIME/waybar.pid"
swaybg -i '@wallpaper@' -m fill & pids+=("$!")
mako --background-color '#202638ee' --border-color '#8ab4f8' --border-radius 12 --font 'Inter 11' & pids+=("$!")
'@polkit@' & pids+=("$!")
swayidle -w timeout 600 'swaylock -f -c 171c2b' before-sleep 'swaylock -f -c 171c2b' & pids+=("$!")
# Waybar exits when its Wayland display disappears; clean up our children too.
wait "${pids[1]}"
