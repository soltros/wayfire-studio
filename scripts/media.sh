#!/usr/bin/env bash
set -euo pipefail
case "${1:-status}" in
  prev) playerctl previous >/dev/null 2>&1 || true; exit 0 ;;
  next) playerctl next >/dev/null 2>&1 || true; exit 0 ;;
  toggle) playerctl play-pause >/dev/null 2>&1 || true; exit 0 ;;
esac
status=$(playerctl status 2>/dev/null || true)
title=$(playerctl metadata --format '{{ artist }}  ·  {{ title }}' 2>/dev/null || true)
[[ -n "$title" ]] || { printf '󰝚  No media\n'; exit 0; }
if [[ "$status" == Playing ]]; then printf '󰏤  %s\n' "$title"; else printf '󰐊  %s\n' "$title"; fi
