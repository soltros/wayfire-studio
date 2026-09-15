#!/usr/bin/env bash
set -euo pipefail

choice=$(printf '%s\n' 'Open terminal' 'Launch application' 'Open files' 'Switch Soltros mode' 'Show workspace overview' 'Audio settings' 'Lock screen' | wofi --dmenu --prompt 'Command center' --width 520 --height 420 --style '@style@') || exit 0
case "$choice" in
  'Open terminal') exec foot ;;
  'Launch application') exec wayfire-studio-launcher ;;
  'Open files') exec thunar ;;
  'Switch Soltros mode') exec wayfire-studio-profile ;;
  'Show workspace overview') exec wayfire-studio-workspaces view ;;
  'Audio settings') exec pavucontrol ;;
  'Lock screen') exec swaylock -c 071321 ;;
esac
