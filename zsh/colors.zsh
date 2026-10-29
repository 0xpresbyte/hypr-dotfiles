# Colors for fzf and zsh-syntax-highlighting, sourced from .zshrc.
#
# These are terminal palette indexes, not hex: matugen sets the Ghostty palette
# from the wallpaper (matugen/templates/ghostty-colors), and Ghostty recolors
# text already on screen when the palette changes, so typed commands follow too.
#
#   0 = surface_container_highest   1 = red      2 = green
#   4 = primary                     5 = tertiary 6 = secondary
#   7 = on_surface_variant          8 = outline  15 = on_surface

export FZF_DEFAULT_OPTS="--color=bg:-1,bg+:0,fg:15,fg+:15,hl:4,hl+:4,info:5,prompt:4,pointer:4,marker:5,spinner:5,header:6,border:8"

typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=4'
ZSH_HIGHLIGHT_STYLES[builtin]='fg=4'
ZSH_HIGHLIGHT_STYLES[alias]='fg=4'
ZSH_HIGHLIGHT_STYLES[function]='fg=4'
ZSH_HIGHLIGHT_STYLES[precommand]='fg=4,italic'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=5'
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=1'
ZSH_HIGHLIGHT_STYLES[path]='fg=15,underline'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=2'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=2'
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=6'
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=6'
ZSH_HIGHLIGHT_STYLES[comment]='fg=8'
