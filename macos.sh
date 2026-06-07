#!/usr/bin/env bash
# macOS system settings. Run on the new Mac; harmless to re-run.
set -euo pipefail

# keyboard: fast repeat, full keyboard UI navigation
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# dock: autohide instantly, big tiles + magnification, no recents,
# keep Spaces order, minimize into app icon, no bottom-right hot corner
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock tilesize -int 93
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock mru-spaces -bool false
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock wvous-br-corner -int 1

# finder: path bar, list view, folders first, new windows open Desktop
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder _FXSortFoldersFirst -bool true
defaults write com.apple.finder NewWindowTarget -string "PfDe"

# dock contents: Zen + Zed only
if command -v dockutil >/dev/null 2>&1; then
  dockutil --remove all --no-restart
  [[ -d /Applications/Zen.app ]] && dockutil --add /Applications/Zen.app --no-restart
  [[ -d /Applications/Zed.app ]] && dockutil --add /Applications/Zed.app --no-restart
else
  echo "dockutil not installed — skipping Dock contents"
fi

killall Dock Finder
echo "macOS settings applied."
