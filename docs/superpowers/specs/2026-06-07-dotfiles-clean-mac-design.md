# Dotfiles & Clean Mac Setup — Design

**Date:** 2026-06-07
**Goal:** Wipe the laptop and restore an extremely lean, minimal setup from a fresh `~/.dotfiles` repo + NAS backups. Install only what is used. Lose no data.

## Context

- Existing GitHub repo `martin-popov/.dotfiles` is stale (last commit Sept 2024: `.gitconfig`, `.zshrc`, `Brewfile`, `zed/settings.json`). No local clone existed. This repo re-initializes with clean history and force-pushes to the same remote.
- Current shell stack (oh-my-zsh + powerlevel10k) is replaced wholesale.
- Backups: Documents/Desktop/Downloads already on iCloud/NAS. iMessage backup in progress (user-managed). **Nothing else under `~/` carries over** except what this design explicitly copies to the NAS.
- NAS: Synology "SNAS" at `192.168.100.250`, SMB mount `/Volumes/homes`. Migration files go to `/Volumes/homes/martinpopov/MacMigration/2026-06/`.

## Decisions (settled with user)

| Topic | Decision |
|---|---|
| Shell | Vanilla zsh + starship. No oh-my-zsh, no p10k, no zsh-autocomplete. |
| Node | fnm + pnpm (pnpm via standalone installer, NOT brew — brew formula drags in brew node). |
| Python | uv only. No brew python, no pipx. |
| Go | brew `go` (replaces manual `/usr/local/go` install). |
| Rust | Official rustup installer (sh.rustup.rs, `-y --no-modify-path`) — brew's rustup is keg-only, cargo would never reach PATH. |
| bun | Dropped. Reinstall later if a project needs it. |
| nvim | Stock, zero config. Aliased `vim=nvim`. |
| SSH keys | Copy `github_ed25519` + `hetzner_ed25519` (priv+pub) to NAS, restore on new Mac. `ssh/config` tracked in repo. |
| Apps kept | Zed, Zen, Karabiner-Elements, Raycast, iTerm2, TablePlus, Docker, Figma, Affinity (v3 unified), Spotify, Discord, VLC, Stremio, Obsidian, Hidden Bar, AnyDesk, Xcode (+ xcode-build-server), Claude Code. |
| Apps dropped | Gaming/3D (Steam, Minecraft, PCSX2, Whisky, Godot, Unity, Blender), Notion, NordVPN, Viscosity, QMK Toolbox, FL Studio, Claude desktop, Bruno/Postman/Yaak, nmap, dotnet. |
| Mechanism | Plain repo + explicit symlink script (`install.sh`). No stow, no bare repo, no chezmoi. |

## Repo layout

```
~/.dotfiles/
├── README.md          # restore checklist, top to bottom
├── bootstrap.sh       # one-shot new-Mac setup (idempotent)
├── install.sh         # symlinks configs into place (called by bootstrap; --dry-run flag)
├── macos.sh           # system settings via `defaults write` (called by bootstrap)
├── prewipe.sh         # run BEFORE wiping: repo audit + NAS copies
├── Brewfile
├── zsh/
│   ├── .zshrc         # ~35 lines, framework-free
│   └── .zprofile      # brew shellenv only
├── starship/starship.toml
├── git/.gitconfig
├── ssh/config
├── zed/settings.json
├── zed/keymap.json
├── karabiner/karabiner.json
├── claude/settings.json
├── iterm2/com.googlecode.iterm2.plist
└── docs/superpowers/specs/   # this doc + implementation plan
```

### Symlink map (install.sh)

| Repo file | Symlink target |
|---|---|
| `zsh/.zshrc` | `~/.zshrc` |
| `zsh/.zprofile` | `~/.zprofile` |
| `starship/starship.toml` | `~/.config/starship.toml` |
| `git/.gitconfig` | `~/.gitconfig` |
| `ssh/config` | `~/.ssh/config` |
| `zed/settings.json` | `~/.config/zed/settings.json` |
| `zed/keymap.json` | `~/.config/zed/keymap.json` |
| `karabiner/karabiner.json` | `~/.config/karabiner/karabiner.json` |
| `claude/settings.json` | `~/.claude/settings.json` |

iTerm2 is NOT symlinked: iTerm2's "Load preferences from custom folder" preference points at `~/.dotfiles/iterm2/`, so iTerm2 reads/writes the plist in the repo directly. `install.sh` sets the two `defaults write com.googlecode.iterm2` keys (`PrefsCustomFolder`, `LoadPrefsFromCustomFolder`) to automate this.

`install.sh` creates parent dirs as needed, backs up any existing real file to `<name>.pre-dotfiles` before linking, and is idempotent (re-linking an existing correct symlink is a no-op).

### The new .zshrc (shape)

- `eval "$(starship init zsh)"` — prompt
- `eval "$(fnm env --use-on-cd)"` — node versions
- `source $(brew --prefix)/share/zsh-autosuggestions/zsh-autosuggestions.zsh`
- `source <(fzf --zsh)`
- `bindkey -v`, `export EDITOR=nvim`, `alias vim=nvim`
- History: large HISTSIZE/SAVEHIST, `setopt share_history hist_ignore_dups`
- PATH blocks: PNPM_HOME (`~/Library/pnpm`), `~/.cargo/env`, `$(go env GOPATH)/bin`, `~/.local/bin`
- Dropped: oh-my-zsh, p10k, pipx PATH line, `pip`/`python` aliases

`.zshenv` is not tracked; the cargo env line moves into `.zshrc`.

## Brewfile

```ruby
# CLI
brew "git"
brew "gh"
brew "git-lfs"
brew "ripgrep"
brew "fzf"
brew "tree"
brew "neovim"
brew "lazygit"
brew "sql-formatter"
# shell
brew "starship"
brew "zsh-autosuggestions"
# toolchains
brew "fnm"
brew "uv"
brew "go"
# swift/xcode
brew "xcode-build-server"
brew "mas"
# macos setup
brew "dockutil"

# apps
cask "zed"
cask "iterm2"
cask "docker-desktop"
cask "tableplus"
cask "figma"
cask "claude-code"
cask "affinity"
cask "zen"
cask "raycast"
cask "karabiner-elements"
cask "obsidian"
cask "spotify"
cask "discord"
cask "vlc"
cask "stremio"
cask "hiddenbar"
cask "anydesk"
cask "font-jetbrains-mono-nerd-font"
```

Note: verify cask names at implementation time (`brew info --cask <name>`); e.g. `claude-code` falls back to the native installer (`curl -fsSL https://claude.ai/install.sh | bash`) if the cask doesn't exist, and `docker-desktop` is the current name for the old `docker` cask.

## prewipe.sh (run on OLD Mac)

`set -euo pipefail`; every step logs; NAS steps verify `/Volumes/homes/martinpopov` is mounted before copying and fail loudly otherwise. Read-only except for copies TO the NAS.

1. **Repo audit** — for each dir in `~/Developer`:
   - git repo → report uncommitted changes, untracked files, unpushed branches, stashes
   - non-git dir → flag "not on GitHub — back up to NAS or lose"
2. **SSH keys → NAS** — `~/.ssh/{github,hetzner}_ed25519{,.pub}` → `MacMigration/2026-06/ssh/`
3. **Claude memory → NAS** — `~/.claude/projects/*/memory/` → `MacMigration/2026-06/claude-memory/`
4. **Print manual pre-wipe checklist**; exit non-zero if any repo is dirty/unpushed or any non-git dir is unhandled.

## bootstrap.sh (run on NEW Mac)

Idempotent; safe to re-run after a failure.

1. Xcode CLT (`xcode-select --install` if missing) + Homebrew (official installer if missing)
2. Clone `git@github.com:martin-popov/.dotfiles.git` to `~/.dotfiles` (or HTTPS first, switch remote after SSH keys restored)
3. `brew bundle --file ~/.dotfiles/Brewfile`
4. `./install.sh`
5. `./macos.sh` — system settings (see below)
6. Toolchains: official rustup installer (if missing) · `fnm install --lts && fnm default lts-latest` · pnpm static binary → `~/Library/pnpm` · `uv python install`
7. `mas install 497799835` (Xcode; requires App Store sign-in — prompt user first)
8. Restore from NAS (if mounted): SSH keys → `~/.ssh/` with `chmod 600`, Claude memory → `~/.claude/projects/<same-project-dir-name-as-backed-up>/memory/` (the backup preserves the project dir names)
9. Print the manual post-restore checklist

## macos.sh (system settings)

Curated `defaults write` lines reproducing the current machine's non-default settings, ending with `killall Dock Finder`. Values captured 2026-06-07 from the old Mac:

| Domain | Setting | Value |
|---|---|---|
| NSGlobalDomain | `KeyRepeat` / `InitialKeyRepeat` | 2 / 15 (fast repeat) |
| NSGlobalDomain | `AppleKeyboardUIMode` | 2 (keyboard UI navigation) |
| com.apple.dock | `autohide` / `autohide-delay` | true / 0 (instant) |
| com.apple.dock | `tilesize` / `magnification` | 93 / true |
| com.apple.dock | `mru-spaces` | false (don't rearrange Spaces) |
| com.apple.dock | `show-recents` | false |
| com.apple.dock | `minimize-to-application` | true |
| com.apple.dock | `wvous-br-corner` | 1 (bottom-right hot corner disabled) |
| com.apple.finder | `ShowPathbar` | true |
| com.apple.finder | `FXPreferredViewStyle` | `Nlsv` (list view) |
| com.apple.finder | `_FXSortFoldersFirst` | true |
| com.apple.finder | `NewWindowTarget` | `PfDe` (new windows → Desktop) |

Dock contents via dockutil: `dockutil --remove all --no-restart`, then `--add` Zen and Zed.

## Manual checklist (README)

**Before wipe:** run `prewipe.sh` until clean · export Raycast `.rayconfig` → NAS · export TablePlus connections → NAS (passwords live in Keychain; export is the only way to keep them) · confirm Zen sync signed in · finish iMessage backup · confirm iCloud (Documents/Desktop/Downloads) fully synced.

**After bootstrap:** import Raycast config · import TablePlus connections · sign into: Zen sync, App Store, Docker, Figma, Spotify, Discord, Obsidian (vault is in iCloud — opens once iCloud syncs) · `claude` login · launch Karabiner-Elements + grant input permissions · iTerm2 picks up prefs from repo folder automatically (set by install.sh) · add restored SSH key to ssh-agent (`ssh-add --apple-use-keychain`).

**System Settings (manual, not scriptable):** Apple ID / iCloud sign-in + **Desktop & Documents sync ON** (backup philosophy depends on it) · disable Spotlight's ⌘Space shortcut so Raycast can take it · default browser → Zen · Language & Region (Bulgarian formats) + input sources · Touch ID · FileVault · screen-lock timing · login items / start-at-login: Karabiner-Elements, Hidden Bar, Raycast.

## Error handling

- Both scripts: `set -euo pipefail`, step-by-step logging.
- NAS operations check mount before copy; no silent skips.
- `install.sh` never overwrites silently — existing real files are moved to `*.pre-dotfiles`.
- `bootstrap.sh` steps are individually idempotent so a mid-run failure is recoverable by re-running.

## Testing

- `prewipe.sh` is validated by running it for real on the old Mac (it's read-only + NAS copies).
- `install.sh --dry-run` prints the symlink plan without touching anything; can be tested on the old Mac.
- `bootstrap.sh` is validated on the new Mac; idempotency makes partial failures safe.
- Brewfile validated with `brew bundle check`/`brew info` for each cask name before the wipe.

## Out of scope

- Zen profile copying (sync covers it)
- nvim config (stock by decision)
- Photos/iMessage backup pipelines (already handled separately on the NAS)
