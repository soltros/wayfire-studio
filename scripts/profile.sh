#!/usr/bin/env bash
set -euo pipefail
state="${XDG_STATE_HOME:-$HOME/.local/state}/wayfire-studio"
runtime="${WAYFIRE_STUDIO_RUNTIME:-${XDG_RUNTIME_DIR:?}/wayfire-studio}"
mkdir -p "$state"
profile='@default@'
if [[ -f "$state/profile" ]]; then read -r profile < "$state/profile" || true; fi
case "$profile" in classic|focus|compact) ;; *) profile='@default@' ;; esac
case "${1:-menu}" in
  status) printf '%s\n' "$profile"; exit 0 ;;
  init) ;;
  classic|focus|compact) profile="$1" ;;
  menu)
    profile=$(printf 'classic\nfocus\ncompact\n' | wofi --dmenu --prompt 'Desktop profile') || exit 0
    [[ -n "$profile" ]] || exit 0
    ;;
  *) echo 'Usage: wayfire-studio-profile [classic|focus|compact|status]' >&2; exit 2 ;;
esac
case "$profile" in classic|focus|compact) ;; *) exit 2 ;; esac
[[ -d "$runtime" ]] || { echo 'Start Wayfire Studio before changing profiles.' >&2; exit 1; }
# Replace atomically; Wayfire watches its configuration for changes.
tmp=$(mktemp "$runtime/config.XXXXXX")
cp "@profiles@/$profile.ini" "$tmp"
mv -f "$tmp" "$runtime/wayfire.ini"
wayfire-studio-dock render "@bars@/$profile.json"
printf '%s\n' "$profile" > "$state/profile"
if [[ "${1:-menu}" != init ]]; then
  if [[ -f "$runtime/waybar.pid" ]]; then
    while read -r bar_pid; do
      if [[ "$bar_pid" =~ ^[0-9]+$ ]] && [[ -r "/proc/$bar_pid/cmdline" ]] &&
        tr '\0' '\n' < "/proc/$bar_pid/cmdline" | grep -Fxq "$runtime/waybar.json"; then
        kill -USR2 "$bar_pid" || true
      fi
    done < "$runtime/waybar.pid"
  fi
  notify-send 'Wayfire Studio' "$profile profile applied. Tiling defaults affect new windows." || true
fi
