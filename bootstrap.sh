#!/usr/bin/env bash
# One-shot new-Mac setup. Idempotent — safe to re-run after any failure.
# Usage: curl -fsSL https://raw.githubusercontent.com/martin-popov/.dotfiles/main/bootstrap.sh | bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
NAS="/Volumes/homes/martinpopov"
SRC="$NAS/MacMigration/2026-06"

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

step "Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "Finish the CLT install dialog, then re-run bootstrap.sh."
  exit 1
fi

step "Homebrew"
if ! command -v brew >/dev/null 2>&1 && [[ ! -x /opt/homebrew/bin/brew ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

step "Dotfiles repo"
if [[ ! -d "$DOTFILES/.git" ]]; then
  # HTTPS first — SSH keys aren't restored yet; remote flips to SSH below
  git clone https://github.com/martin-popov/.dotfiles.git "$DOTFILES"
fi

step "Brew bundle"
brew bundle --file "$DOTFILES/Brewfile"

step "Symlinks"
"$DOTFILES/install.sh"
mkdir -p "$HOME/Developer"   # iTerm2 profile's working directory

step "macOS settings"
"$DOTFILES/macos.sh"

step "Toolchains"
rustup default stable
fnm install --lts
fnm default lts-latest
command -v pnpm >/dev/null 2>&1 || curl -fsSL https://get.pnpm.io/install.sh | sh -
uv python install

step "Xcode (App Store)"
echo "If not signed into the App Store yet, sign in now and re-run bootstrap."
mas install 497799835 || echo "mas install failed — install Xcode from the App Store manually."

step "Restore from NAS"
if [[ -d "$SRC" ]]; then
  if [[ -d "$SRC/ssh" ]]; then
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    cp -p "$SRC/ssh/"* "$HOME/.ssh/"
    chmod 600 "$HOME"/.ssh/*_ed25519
    chmod 644 "$HOME"/.ssh/*.pub
    echo "SSH keys restored."
  fi
  if [[ -d "$SRC/claude-memory" ]]; then
    for proj in "$SRC/claude-memory"/*/; do
      name="$(basename "$proj")"
      mkdir -p "$HOME/.claude/projects/$name"
      cp -Rp "$proj/memory" "$HOME/.claude/projects/$name/"
    done
    echo "Claude memory restored."
  fi
  git -C "$DOTFILES" remote set-url origin git@github.com:martin-popov/.dotfiles.git
else
  echo "NAS not mounted ($SRC) — Finder: Cmd-K smb://192.168.100.250, then re-run."
fi

step "Done"
echo "Now work through 'After bootstrap' + 'System Settings' in $DOTFILES/README.md"
