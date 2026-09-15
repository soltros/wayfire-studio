#!/usr/bin/env bash
set -euo pipefail
exec wofi --show drun --prompt 'Find an application…' --width 560 --height 440 --style '@style@'
