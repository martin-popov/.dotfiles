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

# -d alone is fooled by a stale local dir under /Volumes; check the mount table
nas_mounted() { mount | grep -q ' on /Volumes/homes (' && [[ -d "$NAS" ]]; }

# regenerable junk: neither audited nor swept to the NAS
CACHE_RE='(^|/)(node_modules|\.next|dist|build|target|vendor|\.venv|__pycache__|\.DS_Store|Library|DerivedData|tmp|\.husky|\.astro)(/|$)|\.tsbuildinfo$|\.xcuserstate$|(^|/)\.lock-waf|(^|/)\.waf3-'

audit_repo() {
  local dir="$1" name="$2" bad=0 out n f src dst swept sfail
  out="$(git -C "$dir" status --porcelain 2>/dev/null)" || { fail "$name: git status failed"; bad=1; }
  [[ -n "$out" ]] && { fail "$name: uncommitted or untracked changes"; bad=1; }
  out="$(git -C "$dir" log --branches --tags HEAD --not --remotes --oneline 2>/dev/null)" || { fail "$name: git log failed"; bad=1; }
  [[ -n "$out" ]] && { fail "$name: unpushed commits or tags (or no remote)"; bad=1; }
  out="$(git -C "$dir" stash list 2>/dev/null)" || { fail "$name: git stash failed"; bad=1; }
  [[ -n "$out" ]] && { fail "$name: stashes present"; bad=1; }
  # gitignored files exist ONLY on this disk — sweep them to the NAS and verify;
  # only a failed/impossible sweep keeps them red
  out="$(git -C "$dir" ls-files --others --ignored --exclude-standard 2>/dev/null \
        | grep -vE "$CACHE_RE")"
  if [[ -n "$out" ]]; then
    n=$(echo "$out" | wc -l | tr -d ' ')
    if ! nas_mounted; then
      fail "$name: $n gitignored-only file(s) NOT swept — NAS unmounted:"
      echo "$out" | head -5 | sed 's/^/      /'
      [[ $n -gt 5 ]] && echo "      ... and $((n-5)) more"
      bad=1
    else
      swept=0 sfail=0
      while IFS= read -r f; do
        src="$dir/$f" dst="$DEST/developer/$name/$f"
        if mkdir -p "$(dirname "$dst")" && cp -Xp "$src" "$dst" && cmp -s "$src" "$dst"; then
          swept=$((swept+1))
        else
          fail "$name: sweep FAILED: $f"; sfail=1; bad=1
        fi
      done <<< "$out"
      [[ $sfail -eq 0 ]] && ok "$name: $swept gitignored file(s) swept + verified -> NAS"
    fi
  fi
  # submodule commits/stashes can be local-only even when the superproject is green
  if [[ -f "$dir/.gitmodules" ]]; then
    out="$(git -C "$dir" submodule foreach --quiet --recursive '
      s=$(git status --porcelain 2>/dev/null)
      u=$(git log --branches --tags HEAD --not --remotes --oneline 2>/dev/null)
      st=$(git stash list 2>/dev/null)
      [ -n "$s$u$st" ] && echo "$displaypath" || :
    ' 2>/dev/null)"
    [[ -n "$out" ]] && { fail "$name: submodule(s) with local-only state: $(echo "$out" | tr '\n' ' ')"; bad=1; }
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
if ! nas_mounted; then
  fail "NAS not mounted at $NAS — Finder: Cmd-K smb://192.168.100.250, then re-run"
else
  if mkdir -p "$DEST/ssh" \
     && cp -Xp "$HOME"/.ssh/github_ed25519 "$HOME"/.ssh/github_ed25519.pub \
              "$HOME"/.ssh/hetzner_ed25519 "$HOME"/.ssh/hetzner_ed25519.pub \
              "$HOME"/.ssh/config.local "$DEST/ssh/" \
     && cmp -s "$HOME/.ssh/github_ed25519" "$DEST/ssh/github_ed25519" \
     && cmp -s "$HOME/.ssh/hetzner_ed25519" "$DEST/ssh/hetzner_ed25519" \
     && cmp -s "$HOME/.ssh/config.local" "$DEST/ssh/config.local"; then
    ok "4 key files + config.local copied + verified -> $DEST/ssh/"
  else
    fail "SSH key copy to NAS FAILED — do not wipe until this is green"
  fi
fi

say "4/5 Claude memory -> NAS"
if ! nas_mounted; then
  fail "NAS not mounted — Claude memory not copied"
else
  copied=0 cpfail=0
  for mem in "$HOME"/.claude/projects/*/memory; do
    [[ -d "$mem" ]] || continue
    proj="$(basename "$(dirname "$mem")")"
    if mkdir -p "$DEST/claude-memory/$proj" && cp -Rp "$mem" "$DEST/claude-memory/$proj/"; then
      copied=$((copied+1))
    else
      fail "Claude memory copy FAILED: $proj"; cpfail=1
    fi
  done
  if [[ $copied -gt 0 && $cpfail -eq 0 ]]; then
    ok "$copied project memory dir(s) -> $DEST/claude-memory/"
  elif [[ $copied -eq 0 ]]; then
    fail "no Claude memory dirs copied — expected at least one"
  fi
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
