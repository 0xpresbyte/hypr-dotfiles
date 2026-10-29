#!/usr/bin/env bash
# Take a screenshot, save it, and copy it to the clipboard.
# Usage: screenshot.sh [region|window|screen]   (default: region)
set -euo pipefail

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"
mkdir -p "$DIR"

case "${1:-region}" in
  region)
    command -v slurp >/dev/null || { notify-send "Screenshot" "Install slurp for region capture"; exit 1; }
    geometry="$(slurp)" || exit 0   # Esc cancels
    grim -g "$geometry" "$FILE"
    ;;
  window)
    # "at: X,Y" and "size: W,H" -> "X,Y WxH"
    geometry="$(hyprctl activewindow | awk '/^\tat:/ {at=$2} /^\tsize:/ {sub(",", "x", $2); size=$2} END {print at, size}')"
    grim -g "$geometry" "$FILE"
    ;;
  screen)
    grim "$FILE"
    ;;
  *)
    echo "Usage: $0 [region|window|screen]" >&2
    exit 1
    ;;
esac

wl-copy < "$FILE"
notify-send -i "$FILE" "Screenshot saved" "$FILE" || true
