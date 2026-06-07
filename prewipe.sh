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
