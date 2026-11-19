#!/usr/bin/env bash
# Turn a working folder that is not a code repo into a private GitHub repo and keep it pushed.
#   scripts/backup-folder.sh ~/Documents/sales you/sales-backup
# What it does: adds safe .gitignore rules, commits everything else, creates the private repo with
# `gh` and pushes, then lists the folder in backup.map so sync.sh pushes it every 30 minutes with
# the context repo. Safe to run again (for example after the folder moved).
#
# Control files you can put in the folder (see scripts/sync-lib.sh):
#   .sync-include  paths to keep even though .gitignore excludes them (dependencies, an env file)
#   .sync-allow    files exempt from the credential check
# Files over 95 MB are left out (GitHub refuses them) and listed at the end.
set -u
CONTEXT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
[ $# -ge 1 ] || { echo "usage: backup-folder.sh <folder> [owner/repo]"; exit 1; }
case "$1" in "~/"*) DIR="$HOME/${1#\~/}" ;; *) DIR="$1" ;; esac
REPO="${2:-}"
[ -d "$DIR" ] || { echo "Not a folder: $DIR"; exit 1; }
DIR="$(cd "$DIR" && pwd)"; cd "$DIR" || exit 1
. "$CONTEXT_DIR/scripts/sync-lib.sh"

touch .gitignore
for rule in .DS_Store node_modules/ .venv/ venv/ __pycache__/ .vercel/ .next/ '*.log' .env '.env.*' '!.env.example' '*.pem' '*.key'; do
  grep -qxF -- "$rule" .gitignore || printf '%s\n' "$rule" >> .gitignore
done

[ -d .git ] || git init -q -b main
stage_all
HITS="$(secret_hits | sed 's/^/  /')"
if [ -n "$HITS" ]; then
  git reset -q
  printf 'These files look like they contain a password, key or token:\n%s\n' "$HITS"
  echo "Nothing was committed. Remove the secret, add the file to $DIR/.gitignore, or list it in $DIR/.sync-allow if it is meant to be there. Then run this again."
  exit 1
fi
if ! git diff --cached --quiet 2>/dev/null || ! git rev-parse -q --verify HEAD >/dev/null 2>&1; then
  git commit -q -m "Backup: $(date '+%Y-%m-%d %H:%M')" && echo "Committed. The repo now holds $(git ls-files | wc -l | tr -d ' ') files."
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  if [ -n "${BACKUP_REMOTE_URL:-}" ]; then git remote add origin "$BACKUP_REMOTE_URL" && git push -q -u origin HEAD || exit 1
  elif [ -n "$REPO" ] && command -v gh >/dev/null 2>&1; then gh repo create "$REPO" --private --source . --remote origin --push || exit 1
  else echo "Committed locally. To put it on GitHub: run this again with a repo name, e.g. backup-folder.sh $1 <owner>/$(basename "$DIR")"; exit 0; fi
else
  git push -q -u origin HEAD || exit 1
fi

case "$DIR" in "$HOME"/*) ENTRY="~/${DIR#"$HOME"/}" ;; *) ENTRY="$DIR" ;; esac
MAP="$CONTEXT_DIR/backup.map"; touch "$MAP"
# A folder that moved leaves its old line behind: drop lines whose folder no longer exists.
if [ -s "$MAP" ]; then
  TMP="$(mktemp)"
  while IFS= read -r line; do
    case "$line" in ''|\#*) printf '%s\n' "$line" >> "$TMP"; continue ;; esac
    case "$line" in "~/"*) p="$HOME/${line#\~/}" ;; *) p="$line" ;; esac
    if [ -d "$p" ]; then printf '%s\n' "$line" >> "$TMP"; else echo "Removed $line from backup.map (that folder no longer exists)."; rm -f "$CONTEXT_DIR/.git/context-sync/problem-$(basename "$p")"; fi
  done < "$MAP"
  cat "$TMP" > "$MAP"; rm -f "$TMP"
fi
grep -qxF -- "$ENTRY" "$MAP" || printf '%s\n' "$ENTRY" >> "$MAP"
echo "✓ $ENTRY is on GitHub ($(git remote get-url origin)) and will be pushed with every sync."

if [ -n "$SKIPPED_BIG" ]; then
  printf 'Left out because they are over 95 MB (GitHub refuses them):\n'; printf '%s' "$SKIPPED_BIG" | sed 's/^/  /'
fi
NESTED="$(find . -mindepth 2 -name .git -not -path './.git/*' 2>/dev/null | sed 's|^\./||; s|/\.git$||')"
if [ -n "$NESTED" ]; then
  printf 'These subfolders are git repos of their own. Their files are NOT in this backup; push each one to its own remote:\n'; printf '%s\n' "$NESTED" | sed 's/^/  /'
fi
