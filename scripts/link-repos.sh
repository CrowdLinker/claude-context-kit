#!/usr/bin/env bash
# Link working folders to their project (reads repos.map). Called by install.sh; safe to re-run.
#   local  (default)  nothing is committed: block goes in CLAUDE.local.md, files are excluded via
#                     .git/info/exclude. Use for team or client repos.
#   commit            block goes in CLAUDE.md and docs/STATE.md is meant to be committed, so
#                     cloud sessions see it. Use for repos that are yours alone.
set -u
CONTEXT_DIR="${CONTEXT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
CODE_DIR="${CODE_DIR:-$(dirname "$CONTEXT_DIR")}"
DRY="${DRY:-0}"
BEGIN='<!-- context:start -->'; END='<!-- context:end -->'
say() { printf '%s\n' "$*"; }

strip_block() {   # remove our block (and trailing blank lines) from a file, in place
  local f="$1" tmp; tmp="$(mktemp)"
  awk -v b="$BEGIN" -v e="$END" 'index($0,b){s=1} !s{l[++n]=$0; if($0!~/^[[:space:]]*$/)k=n} index($0,e){s=0} END{for(i=1;i<=k;i++)print l[i]}' "$f" > "$tmp"
  cat "$tmp" > "$f"; rm -f "$tmp"
}
block() {
  cat <<EOF
$BEGIN
## Session context
Current engineering state (read first, keep current): @docs/STATE.md

Project slug: \`$1\`. Business context lives in my private context repo
(\`projects/$1/\`) and is loaded by a local SessionStart hook.
When this session changes where things stand, run \`/wrap\` or update docs/STATE.md.
$END
EOF
}

while read -r dir slug mode _; do
  case "$dir" in ''|\#*) continue ;; esac
  mode="${mode:-local}"
  case "$dir" in "~/"*) repo="$HOME/${dir#\~/}" ;; /*) repo="$dir" ;; *) repo="$CODE_DIR/$dir" ;; esac
  [ -d "$repo" ] || { say "   – $dir: not found, skipped"; continue; }
  [ -d "$CONTEXT_DIR/projects/$slug" ] || { say "   – $dir: project '$slug' not in projects/, skipped"; continue; }
  if [ "$DRY" = 1 ]; then say "   [dry-run] $dir → $slug ($mode)"; continue; fi

  printf '%s\n' "$slug" > "$repo/.context"
  if [ ! -d "$repo/.git" ]; then say "   ✓ $dir → $slug (not a git repo: .context only)"; continue; fi

  if [ ! -f "$repo/docs/STATE.md" ]; then
    mkdir -p "$repo/docs" && cp "$CONTEXT_DIR/templates/CODE_STATE.md" "$repo/docs/STATE.md"
  fi

  if [ "$mode" = commit ]; then
    if ! grep -qF "$BEGIN" "$repo/CLAUDE.md" 2>/dev/null; then { echo; block "$slug"; } >> "$repo/CLAUDE.md"; fi
    say "   ✓ $dir → $slug (commit: review and commit .context, docs/STATE.md, CLAUDE.md)"
  else
    # Take our block back out of the shared CLAUDE.md if an earlier install put it there.
    if grep -qF "$BEGIN" "$repo/CLAUDE.md" 2>/dev/null; then
      strip_block "$repo/CLAUDE.md"
      [ -s "$repo/CLAUDE.md" ] || rm -f "$repo/CLAUDE.md" 2>/dev/null
    fi
    block "$slug" > "$repo/CLAUDE.local.md"
    ex="$repo/.git/info/exclude"; mkdir -p "$repo/.git/info"; touch "$ex"
    for p in .context /docs/STATE.md CLAUDE.local.md; do grep -qxF "$p" "$ex" || printf '%s\n' "$p" >> "$ex"; done
    left="$(git -C "$repo" --no-optional-locks status --short -- .context docs/STATE.md CLAUDE.md CLAUDE.local.md 2>/dev/null | tr '\n' ' ')"
    say "   ✓ $dir → $slug (local only${left:+; still showing in git status: $left})"
  fi
done < "$CONTEXT_DIR/repos.map"
