#!/usr/bin/env bash
# Install the required packages and symlink this repo's configs into ~/.config.
# Usage: ./install.sh [--dry-run] [--no-packages]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIGS=(hypr quickshell fontconfig ghostty matugen fastfetch theme)
DRY_RUN=0
PACKAGES_STEP=1

# Everything the configs use, all from the official Arch repos.
PACKAGES=(
  # Desktop
  hyprland quickshell ghostty hyprpolkitagent
  # Wallpaper and colors
  awww matugen
  # Screenshots (hypr/scripts/screenshot.sh)
  grim slurp wl-clipboard libnotify
  # Media, volume and brightness keys
  wireplumber playerctl brightnessctl
  # Shell
  zsh zsh-syntax-highlighting fzf starship fastfetch
  # Used by this script (fzf-tab clone, font zips, font cache)
  git libarchive fontconfig
)

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    --no-packages) PACKAGES_STEP=0 ;;
    -h|--help) sed -n '2,3p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

run() {
  if (( DRY_RUN )); then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

is_empty() { [[ ! -e $1 ]] || [[ -d $1 && -z "$(ls -A "$1")" ]]; }

# link <name> [src] [dst]: defaults to repo/<name> -> ~/.config/<name>
link() {
  local name=$1
  local src="${2:-$REPO_DIR/$name}"
  local dst="${3:-$CONFIG_DIR/$name}"

  if [[ -L $dst ]]; then
    if [[ "$(readlink -f "$dst")" == "$src" ]]; then
      info "$name: already linked"
      return
    fi
    warn "$name: replacing symlink -> $(readlink "$dst")"
    run rm "$dst"
  elif [[ -e $dst ]]; then
    if is_empty "$src"; then
      info "$name: adopting existing $dst into repo"
      [[ -d $src ]] && run rmdir "$src"
      run mv "$dst" "$src"
    else
      local backup
      backup="$dst.bak.$(date +%Y%m%d-%H%M%S)"
      warn "$name: backing up $dst -> $backup"
      run mv "$dst" "$backup"
    fi
  fi

  [[ -e $src ]] || run mkdir -p "$src"
  info "$name: linking $dst -> $src"
  run ln -s "$src" "$dst"
}

install_fonts() {
  local font_dir="${XDG_DATA_HOME:-$HOME/.local/share}/fonts"
  local zip name
  shopt -s nullglob
  for zip in "$REPO_DIR"/fonts/*.zip; do
    name="$(basename "$zip" .zip)"
    info "fonts: installing $name -> $font_dir/$name"
    run mkdir -p "$font_dir/$name"
    run bsdtar -xf "$zip" -C "$font_dir/$name" --exclude '__MACOSX' '*.[ot]tf'
  done
  shopt -u nullglob
  if command -v fc-cache >/dev/null; then
    run fc-cache -f "$font_dir"
  fi
}

install_packages() {
  if ! command -v pacman >/dev/null; then
    warn "packages: pacman not found; install these yourself: ${PACKAGES[*]}"
    return
  fi
  local missing
  mapfile -t missing < <(pacman -T "${PACKAGES[@]}" || true)
  if (( ${#missing[@]} == 0 )); then
    info "packages: all installed"
    return
  fi
  info "packages: installing ${missing[*]}"
  run sudo pacman -S --needed "${missing[@]}"
}

(( PACKAGES_STEP )) && install_packages

run mkdir -p "$CONFIG_DIR"
for name in "${CONFIGS[@]}"; do
  link "$name"
done
link zshrc "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
link starship "$REPO_DIR/starship/starship.toml" "$CONFIG_DIR/starship.toml"
install_fonts

# fzf-tab isn't packaged in the Arch repos, so fetch it from GitHub.
FZF_TAB_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins/fzf-tab"
if [[ -d $FZF_TAB_DIR ]]; then
  info "zsh: fzf-tab already installed"
else
  info "zsh: installing fzf-tab -> $FZF_TAB_DIR"
  run git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$FZF_TAB_DIR"
fi

# First install: generate wallpaper + colors (later, run wallpaper.sh yourself).
if [[ ! -e ${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper/current ]]; then
  if command -v matugen >/dev/null; then
    info "matugen: generating colors from wallpapers/"
    run "$REPO_DIR/hypr/scripts/wallpaper.sh"
  else
    warn "matugen not installed; skipping color generation (sudo pacman -S matugen)"
  fi
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  info "Done. Run 'hyprctl reload' and restart quickshell ('qs') to apply."
else
  info "Done."
fi
