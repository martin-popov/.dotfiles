# Dotfiles & Clean Mac Setup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete `~/.dotfiles` repo (configs, Brewfile, install/macos/prewipe/bootstrap scripts, README) so the laptop can be wiped and restored to a lean setup with zero data loss.

**Architecture:** Plain git repo at `~/.dotfiles` with an explicit symlink script — no stow/chezmoi/bare-repo. Three lifecycle scripts: `prewipe.sh` (old Mac: audit + NAS copies), `bootstrap.sh` (new Mac: one-shot setup), `install.sh` + `macos.sh` (idempotent appliers called by bootstrap). Current machine's configs are copied into the repo verbatim.

**Tech Stack:** bash, zsh, Homebrew/Brewfile, starship, fnm, uv, rustup, dockutil, macOS `defaults`.

**Spec:** `docs/superpowers/specs/2026-06-07-dotfiles-clean-mac-design.md` (approved). The repo already exists at `~/.dotfiles` with the spec committed (branch `main`).

**Verification model:** These are shell scripts and config files, not a library — TDD maps to: write file → syntax-check (`bash -n` / `zsh -n`) → dry-run or real run where safe → commit. Every task ends with a commit. All commands run from `~/.dotfiles` unless stated otherwise.

**Verified facts (checked 2026-06-07 on the old Mac):**
- All cask names exist in brew; Hidden Bar's cask is **`hiddenbar`** (not `hidden-bar`).
- `~/.claude/settings.json` contains no secrets — safe to track.
- NAS mounts at `/Volumes/homes`; migration dir is `/Volumes/homes/martinpopov/MacMigration/2026-06/`.
- Xcode App Store id: `497799835`.

---

### Task 1: Brewfile

**Files:**
- Create: `~/.dotfiles/Brewfile`

- [ ] **Step 1: Write the Brewfile**

```ruby
# CLI
brew "git"
brew "gh"
brew "git-lfs"
brew "ripgrep"
brew "fzf"
brew "tree"
brew "neovim"
# shell
brew "starship"
brew "zsh-autosuggestions"
# toolchains
brew "fnm"
brew "uv"
brew "go"
brew "rustup"
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

mas "Xcode", id: 497799835
```

- [ ] **Step 2: Verify it parses**

Run: `brew bundle list --file ~/.dotfiles/Brewfile`
Expected: prints the formula/cask/mas names, exit 0. Any "Invalid Brewfile" error = typo; fix it.

- [ ] **Step 3: Commit**

```bash
git -C ~/.dotfiles add Brewfile
git -C ~/.dotfiles commit -m "Add Brewfile: 16 formulae, 18 casks, Xcode via mas"
```

---

### Task 2: zsh + starship configs

**Files:**
- Create: `~/.dotfiles/zsh/.zshrc`
- Create: `~/.dotfiles/zsh/.zprofile`
- Create: `~/.dotfiles/starship/starship.toml`

- [ ] **Step 1: Write `zsh/.zshrc`**

```zsh
# vi mode (before plugins so fzf binds into the right keymaps)
bindkey -v

# node (fnm)
eval "$(fnm env --use-on-cd)"

# plugins
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source <(fzf --zsh)

# editor
export EDITOR=nvim
alias vim=nvim

# history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# paths: pnpm, rust, go (default GOPATH), uv tools
export PNPM_HOME="$HOME/Library/pnpm"
export PATH="$PNPM_HOME:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.local/bin:$PATH"

# prompt
eval "$(starship init zsh)"
```

Notes for the implementer: `$HOME/.cargo/bin` is on PATH directly (brew's `rustup` doesn't create `~/.cargo/env`); GOPATH is left at its default `~/go` so no export needed; oh-my-zsh/p10k/pipx/`pip`/`python` aliases are gone by design.

- [ ] **Step 2: Write `zsh/.zprofile`**

```zsh
eval "$(/opt/homebrew/bin/brew shellenv)"
```

- [ ] **Step 3: Write `starship/starship.toml`**

```toml
# Starship prompt — https://starship.rs/config/
# Defaults are good; add overrides here when needed.
command_timeout = 1000
```

- [ ] **Step 4: Syntax-check both zsh files**

Run: `zsh -n ~/.dotfiles/zsh/.zshrc && zsh -n ~/.dotfiles/zsh/.zprofile && echo SYNTAX-OK`
Expected: `SYNTAX-OK`

- [ ] **Step 5: Commit**

```bash
git -C ~/.dotfiles add zsh starship
git -C ~/.dotfiles commit -m "Add framework-free zsh config + starship prompt"
```

---

### Task 3: Copy current machine's configs into the repo

**Files:**
- Create: `~/.dotfiles/zed/settings.json`, `~/.dotfiles/zed/keymap.json` (from `~/.config/zed/`)
- Create: `~/.dotfiles/karabiner/karabiner.json` (from `~/.config/karabiner/`)
- Create: `~/.dotfiles/claude/settings.json` (from `~/.claude/`)
- Create: `~/.dotfiles/git/.gitconfig` (from `~/.gitconfig`)
- Create: `~/.dotfiles/ssh/config` (from `~/.ssh/config`)
- Create: `~/.dotfiles/iterm2/com.googlecode.iterm2.plist` (exported)

- [ ] **Step 1: Copy the files**

```bash
cd ~/.dotfiles
mkdir -p zed karabiner claude git ssh iterm2
cp ~/.config/zed/settings.json       zed/settings.json
cp ~/.config/zed/keymap.json         zed/keymap.json
cp ~/.config/karabiner/karabiner.json karabiner/karabiner.json
cp ~/.claude/settings.json           claude/settings.json
cp ~/.gitconfig                      git/.gitconfig
cp ~/.ssh/config                     ssh/config
defaults export com.googlecode.iterm2 iterm2/com.googlecode.iterm2.plist
```

(`defaults export` instead of `cp` for iTerm2 so the cfprefsd cache is flushed and the plist is current. Only `settings.json`/`keymap.json` from zed — `themes/` is empty and `prompts/` is a binary library DB, per spec.)

- [ ] **Step 2: Verify copies are identical**

Run:
```bash
diff ~/.config/zed/settings.json ~/.dotfiles/zed/settings.json \
&& diff ~/.config/zed/keymap.json ~/.dotfiles/zed/keymap.json \
&& diff ~/.config/karabiner/karabiner.json ~/.dotfiles/karabiner/karabiner.json \
&& diff ~/.claude/settings.json ~/.dotfiles/claude/settings.json \
&& diff ~/.gitconfig ~/.dotfiles/git/.gitconfig \
&& diff ~/.ssh/config ~/.dotfiles/ssh/config \
&& echo COPIES-OK
```
Expected: `COPIES-OK` (no diff output). Also `plutil -lint iterm2/com.googlecode.iterm2.plist` → `OK`.

- [ ] **Step 3: Commit**

```bash
git -C ~/.dotfiles add zed karabiner claude git ssh iterm2
git -C ~/.dotfiles commit -m "Import current zed, karabiner, claude, git, ssh, iterm2 configs"
```

---

### Task 4: install.sh (symlinker)

**Files:**
- Create: `~/.dotfiles/install.sh` (mode 755)

- [ ] **Step 1: Write `install.sh`**

```bash
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
```

- [ ] **Step 2: Make executable and syntax-check**

Run: `chmod +x ~/.dotfiles/install.sh && bash -n ~/.dotfiles/install.sh && echo SYNTAX-OK`
Expected: `SYNTAX-OK`

- [ ] **Step 3: Dry-run it**

Run: `~/.dotfiles/install.sh --dry-run`
Expected output (exactly 9 `[dry-run]` lines + `done.`):
```
[dry-run] /Users/martinpopov/.zshrc -> /Users/martinpopov/.dotfiles/zsh/.zshrc
[dry-run] /Users/martinpopov/.zprofile -> /Users/martinpopov/.dotfiles/zsh/.zprofile
... (7 more)
done.
```
It must NOT create or modify anything: `git -C ~/.dotfiles status --porcelain` shows only `install.sh`, and `ls -la ~/.zshrc` still shows a regular file (not a symlink).

- [ ] **Step 4: Commit**

```bash
git -C ~/.dotfiles add install.sh
git -C ~/.dotfiles commit -m "Add install.sh: explicit idempotent symlinker with --dry-run"
```

---

### Task 5: macos.sh (system settings)

**Files:**
- Create: `~/.dotfiles/macos.sh` (mode 755)

- [ ] **Step 1: Write `macos.sh`**

Values were captured from the old Mac on 2026-06-07 (see spec table).

```bash
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
```

- [ ] **Step 2: Make executable and syntax-check**

Run: `chmod +x ~/.dotfiles/macos.sh && bash -n ~/.dotfiles/macos.sh && echo SYNTAX-OK`
Expected: `SYNTAX-OK`. Do NOT run it on the old Mac — the settings already match (they were read from here); it would only churn Dock/Finder.

- [ ] **Step 3: Commit**

```bash
git -C ~/.dotfiles add macos.sh
git -C ~/.dotfiles commit -m "Add macos.sh: captured system settings + dockutil Dock layout"
```

---

### Task 6: prewipe.sh (old-Mac audit + NAS copies)

**Files:**
- Create: `~/.dotfiles/prewipe.sh` (mode 755)

- [ ] **Step 1: Write `prewipe.sh`**

```bash
#!/usr/bin/env bash
# Run on the OLD Mac before wiping. Collects ALL problems, then exits
# non-zero if anything is unsafe. Read-only except for copies TO the NAS.
set -uo pipefail   # no -e on purpose: we want the full report, not fail-fast

NAS="/Volumes/homes/martinpopov"
DEST="$NAS/MacMigration/2026-06"
ISSUES=0

say()  { printf '\n\033[1m%s\033[0m\n' "$1"; }
fail() { printf '  \033[31mx %s\033[0m\n' "$1"; ISSUES=$((ISSUES+1)); }
ok()   { printf '  \033[32m+ %s\033[0m\n' "$1"; }

audit_repo() {
  local dir="$1" name="$2" bad=0
  if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
    fail "$name: uncommitted or untracked changes"; bad=1
  fi
  if [[ -n "$(git -C "$dir" log --branches --not --remotes --oneline 2>/dev/null)" ]]; then
    fail "$name: unpushed commits (or no remote)"; bad=1
  fi
  if [[ -n "$(git -C "$dir" stash list 2>/dev/null)" ]]; then
    fail "$name: stashes present"; bad=1
  fi
  [[ $bad -eq 0 ]] && ok "$name"
}

say "1/5 Auditing ~/Developer"
for dir in "$HOME"/Developer/*/; do
  name="$(basename "$dir")"
  if [[ ! -d "$dir/.git" ]]; then
    fail "$name: NOT a git repo — back it up to the NAS or lose it"
    continue
  fi
  audit_repo "$dir" "$name"
done

say "2/5 Auditing ~/.dotfiles itself"
audit_repo "$HOME/.dotfiles" ".dotfiles"

say "3/5 SSH keys -> NAS"
if [[ ! -d "$NAS" ]]; then
  fail "NAS not mounted at $NAS — Finder: Cmd-K smb://192.168.100.250, then re-run"
else
  mkdir -p "$DEST/ssh"
  cp -p "$HOME"/.ssh/github_ed25519 "$HOME"/.ssh/github_ed25519.pub \
        "$HOME"/.ssh/hetzner_ed25519 "$HOME"/.ssh/hetzner_ed25519.pub "$DEST/ssh/"
  ok "4 key files -> $DEST/ssh/"
fi

say "4/5 Claude memory -> NAS"
if [[ -d "$NAS" ]]; then
  copied=0
  for mem in "$HOME"/.claude/projects/*/memory; do
    [[ -d "$mem" ]] || continue
    proj="$(basename "$(dirname "$mem")")"
    mkdir -p "$DEST/claude-memory/$proj"
    cp -Rp "$mem" "$DEST/claude-memory/$proj/"
    copied=$((copied+1))
  done
  ok "$copied project memory dir(s) -> $DEST/claude-memory/"
else
  fail "NAS not mounted — Claude memory not copied"
fi

say "5/5 Manual items (cannot be scripted)"
cat <<'EOF'
  [ ] Raycast: Settings > Advanced > Export -> save .rayconfig to the NAS
  [ ] TablePlus: Connection > Export -> save to the NAS (passwords live in Keychain)
  [ ] Zen: confirm sync is signed in and green
  [ ] iMessage backup finished and verified on the NAS
  [ ] iCloud: Documents/Desktop/Downloads fully synced (no clouds with arrows in Finder)
EOF

echo
if [[ $ISSUES -gt 0 ]]; then
  printf '\033[31m%d issue(s) found — NOT safe to wipe yet.\033[0m\n' "$ISSUES"
  exit 1
fi
printf '\033[32mAll clear (script-checkable items). Work the manual list above, then wipe.\033[0m\n'
```

- [ ] **Step 2: Make executable and syntax-check**

Run: `chmod +x ~/.dotfiles/prewipe.sh && bash -n ~/.dotfiles/prewipe.sh && echo SYNTAX-OK`
Expected: `SYNTAX-OK`

- [ ] **Step 3: Smoke-run it (safe: read-only + NAS copies)**

Run: `~/.dotfiles/prewipe.sh; echo "exit=$?"`
Expected right now: a report listing each `~/Developer` dir, `.dotfiles` flagged (unpushed — remote not set yet), NAS sections succeed if mounted (else flagged), `exit=1`. The point of this run is that the report *format* is sane — a non-zero exit is correct at this stage.

- [ ] **Step 4: Commit**

```bash
git -C ~/.dotfiles add prewipe.sh
git -C ~/.dotfiles commit -m "Add prewipe.sh: repo audit + NAS copies + manual checklist"
```

---

### Task 7: bootstrap.sh (new-Mac one-shot)

**Files:**
- Create: `~/.dotfiles/bootstrap.sh` (mode 755)

- [ ] **Step 1: Write `bootstrap.sh`**

```bash
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
```

- [ ] **Step 2: Make executable and syntax-check**

Run: `chmod +x ~/.dotfiles/bootstrap.sh && bash -n ~/.dotfiles/bootstrap.sh && echo SYNTAX-OK`
Expected: `SYNTAX-OK`. Do NOT run on the old Mac — it's for the fresh machine (it would clone over `~/.dotfiles`, install dropped-by-design brew packages' replacements, etc.).

- [ ] **Step 3: Commit**

```bash
git -C ~/.dotfiles add bootstrap.sh
git -C ~/.dotfiles commit -m "Add bootstrap.sh: idempotent one-shot new-Mac setup"
```

---

### Task 8: README

**Files:**
- Create: `~/.dotfiles/README.md`

- [ ] **Step 1: Write `README.md`**

````markdown
# .dotfiles

Lean Mac setup. One repo, three scripts, no frameworks.

| File | What |
|---|---|
| `Brewfile` | every formula/cask + Xcode via mas |
| `install.sh` | symlinks configs into place (`--dry-run` supported) |
| `macos.sh` | system settings via `defaults write` + Dock via dockutil |
| `prewipe.sh` | OLD Mac: audit repos, copy SSH keys + Claude memory to NAS |
| `bootstrap.sh` | NEW Mac: everything, one shot, idempotent |

Tracked configs: zsh (+starship), git, ssh config (keys via NAS, never in git),
zed, karabiner, claude, iterm2 (via custom-prefs-folder, not symlink).

## New Mac

```sh
curl -fsSL https://raw.githubusercontent.com/martin-popov/.dotfiles/main/bootstrap.sh | bash
```

Re-run it whenever a step fails (App Store sign-in, NAS not mounted) — it picks
up where it left off.

## Before wiping the old Mac

Run `./prewipe.sh` until it prints "All clear", then:

- [ ] Raycast: Settings → Advanced → Export → `.rayconfig` to NAS
- [ ] TablePlus: Connection → Export → file to NAS (passwords are in Keychain — export is the only way)
- [ ] Zen: sync signed in and up to date
- [ ] iMessage backup finished on NAS
- [ ] iCloud Documents/Desktop/Downloads fully synced
- [ ] `git -C ~/.dotfiles push` — this repo itself

## After bootstrap (new Mac)

- [ ] Raycast: import `.rayconfig` from NAS
- [ ] TablePlus: import connections from NAS
- [ ] Sign in: Zen sync, App Store, Docker, Figma, Spotify, Discord
- [ ] Obsidian: vault lives in iCloud — opens once iCloud syncs
- [ ] `claude` → login
- [ ] Karabiner-Elements: launch once, grant input-monitoring permissions
- [ ] `ssh-add --apple-use-keychain ~/.ssh/github_ed25519` (and hetzner)
- [ ] iTerm2: prefs load from `~/.dotfiles/iterm2` automatically (set by install.sh)

## System Settings (manual, not scriptable)

- [ ] Apple ID / iCloud sign-in + **Desktop & Documents sync ON**
- [ ] Spotlight: disable ⌘Space shortcut (Raycast takes it)
- [ ] Default browser → Zen
- [ ] Language & Region: Bulgarian formats + input sources
- [ ] Touch ID, FileVault, screen-lock timing
- [ ] Login items: Karabiner-Elements, Hidden Bar, Raycast

## NAS

Synology "SNAS" `192.168.100.250`, SMB mount `/Volumes/homes`.
Migration files: `/Volumes/homes/martinpopov/MacMigration/2026-06/`
(`ssh/` keys, `claude-memory/`, Raycast + TablePlus exports.)
````

- [ ] **Step 2: Commit**

```bash
git -C ~/.dotfiles add README.md
git -C ~/.dotfiles commit -m "Add README: restore guide + manual checklists"
```

---

### Task 9: Push to GitHub (replaces stale repo)

**Files:** none (git operation)

⚠️ **Confirm with Martin before the force-push** — it permanently discards the Sept-2024 history of `martin-popov/.dotfiles` (4 stale files, superseded by this repo; approved in the spec, but re-confirm at execution time since it's irreversible).

- [ ] **Step 1: Add the remote**

```bash
git -C ~/.dotfiles remote add origin git@github.com:martin-popov/.dotfiles.git
```

- [ ] **Step 2: Force-push clean history**

Run: `git -C ~/.dotfiles push --force --set-upstream origin main`
Expected: `+ ... main -> main (forced update)`

- [ ] **Step 3: Verify**

Run: `gh api repos/martin-popov/.dotfiles/git/trees/HEAD --jq '.tree[].path'`
Expected: lists `Brewfile`, `README.md`, `bootstrap.sh`, `install.sh`, `macos.sh`, `prewipe.sh`, the config dirs, and `docs`.

---

### Task 10: Real prewipe run (the gate before wiping)

**Files:** none (runs `prewipe.sh` for real)

- [ ] **Step 1: Mount the NAS**

Finder → Cmd-K → `smb://192.168.100.250` → mount `homes`. Verify: `ls /Volumes/homes/martinpopov` works.

- [ ] **Step 2: Run prewipe**

Run: `~/.dotfiles/prewipe.sh; echo "exit=$?"`
Expected eventually: `All clear ... exit=0`. First runs will list dirty/unpushed repos and non-git dirs in `~/Developer` (e.g. `Documents`, `Untitled Adventure`, `finance`).

- [ ] **Step 3: Resolve every finding with Martin**

For each flagged item, Martin decides: commit+push it, copy it to the NAS (`/Volumes/homes/martinpopov/MacMigration/2026-06/developer/<name>/`), or consciously abandon it. Re-run Step 2 after each batch until `exit=0`.

- [ ] **Step 4: Verify NAS copies are complete**

```bash
ls -la /Volumes/homes/martinpopov/MacMigration/2026-06/ssh/
ls /Volumes/homes/martinpopov/MacMigration/2026-06/claude-memory/
```
Expected: 4 key files (2 private, 2 `.pub`); at least the `-Users-martinpopov-Developer` memory dir.

- [ ] **Step 5: Hand over to the manual checklist**

Print it for Martin: the "Before wiping" section of `README.md`. The wipe itself is his manual action — nothing in this plan performs it.

---

### Task 11 (optional): Test-drive the lean shell on the old Mac

Skippable — the old Mac gets wiped anyway. Worth doing if Martin wants to feel the new shell before committing to it.

- [ ] **Step 1: Install the new shell's dependencies**

Run: `brew install starship fnm`
(fzf, zsh-autosuggestions, uv already installed.)

- [ ] **Step 2: Apply symlinks for real**

Run: `~/.dotfiles/install.sh`
Expected: `backup: ... .pre-dotfiles` lines for existing real files, `linked:` lines for all 9 targets, iTerm2 prefs message.

- [ ] **Step 3: Open a new terminal tab and verify**

- starship prompt renders (needs a Nerd Font selected in iTerm2 for icons)
- `vim` opens nvim; `echo $EDITOR` → `nvim`
- `fnm --version`, `rg --version`, `fzf --version` all work
- old config recoverable at `~/.zshrc.pre-dotfiles` if anything feels wrong

---

## Self-review (done at write time)

- **Spec coverage:** repo layout ✓ (T1-T8), symlink map ✓ (T4 matches spec table), Brewfile ✓ (T1, `hiddenbar` corrected), zshrc shape ✓ (T2), macos.sh ✓ (T5 matches captured values), prewipe ✓ (T6: repo audit incl. non-git dirs + dotfiles itself, SSH keys, Claude memory, manual list, non-zero exit), bootstrap ✓ (T7: CLT→brew→clone→bundle→install→macos→toolchains→mas→NAS restore), README checklists ✓ (T8), force-push decision ✓ (T9 with re-confirm), validation ✓ (T10).
- **Placeholders:** none — every file's full content is inline.
- **Consistency:** NAS path `MacMigration/2026-06` identical in prewipe/bootstrap/README; `claude-memory/<proj>/memory` layout written by prewipe matches what bootstrap reads; HTTPS-clone→SSH-remote-flip consistent between bootstrap and T9 remote URL.
