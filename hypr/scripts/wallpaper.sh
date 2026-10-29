#!/usr/bin/env bash
# Set the wallpaper and regenerate every app's colors from it with matugen.
# Usage: wallpaper.sh [image]   (default: first image in the repo's wallpapers/)
#        wallpaper.sh --list    (print every image in wallpapers/, one per line)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd -P)"
WALL_DIR="$REPO_DIR/wallpapers"

list() {
  find "$WALL_DIR" -maxdepth 1 -xtype f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | sort
}

if [[ ${1:-} == --list ]]; then
  list
  exit 0
fi

image="${1:-}"
if [[ -z $image ]]; then
  image="$(list | head -n1)"
  [[ -n $image ]] || { echo "No images in $WALL_DIR" >&2; exit 1; }
fi
[[ -f $image ]] || { echo "Not a file: $image" >&2; exit 1; }
image="$(realpath "$image")"

# Swap the wallpaper in place with a fade (awww keeps it across restarts).
awww query >/dev/null 2>&1 || { setsid -f awww-daemon >/dev/null 2>&1; sleep 0.5; }
awww img "$image" --transition-type fade --transition-duration 0.3 --transition-fps 60

# Remember it for the Quickshell selector (WallpaperSelector.qml).
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
mkdir -p "$STATE_DIR"
printf '%s\n' "$image" > "$STATE_DIR/current"

# Black-and-white images have no usable source color, so matugen falls back to
# its default blue (#4285f4); give those a grey scheme instead.
scheme=scheme-tonal-spot
sources="$(matugen image "$image" --show-source-colors 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | tr -d '[:space:]')"
[[ ${sources,,} == "#4285f4" ]] && scheme=scheme-monochrome

matugen image "$image" --mode dark --type "$scheme" --source-color-index 0
