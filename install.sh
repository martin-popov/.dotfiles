#!/usr/bin/env bash
# Symlinks dotfiles into place. Idempotent. --dry-run prints the plan only.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

link() {
  local src="$DOTFILES/$1" dst="$2"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[dry-run] $dst -> $src"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    echo "backup:  $dst -> $dst.pre-dotfiles"
    mv "$dst" "$dst.pre-dotfiles"
  fi
  ln -sfn "$src" "$dst"
  echo "linked:  $dst"
}

# ~/.ssh needs restrictive perms before anything lands in it
[[ $DRY_RUN -eq 1 ]] || { mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"; }

link zsh/.zshrc               "$HOME/.zshrc"
link zsh/.zprofile            "$HOME/.zprofile"
link starship/starship.toml   "$HOME/.config/starship.toml"
link git/.gitconfig           "$HOME/.gitconfig"
link ssh/config               "$HOME/.ssh/config"
link zed/settings.json        "$HOME/.config/zed/settings.json"
link zed/keymap.json          "$HOME/.config/zed/keymap.json"
link karabiner/karabiner.json "$HOME/.config/karabiner/karabiner.json"
link claude/settings.json     "$HOME/.claude/settings.json"

# iTerm2 reads/writes its plist straight from the repo (no symlink)
if [[ $DRY_RUN -eq 0 ]]; then
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$DOTFILES/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  echo "iterm2:  prefs folder -> $DOTFILES/iterm2"
fi

echo "done."
