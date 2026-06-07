# .dotfiles

Lean Mac setup. One repo, three scripts, no frameworks.

| File | What |
|---|---|
| `Brewfile` | every formula/cask (Xcode itself is installed by bootstrap via `mas`) |
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
- [ ] Zed: sign into GitHub Copilot again (token lives in Keychain, doesn't survive wipe)
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
