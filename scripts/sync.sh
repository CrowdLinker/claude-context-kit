#!/usr/bin/env bash
# Commit local changes, rebase onto GitHub, push: for the context repo and for every folder
# listed in backup.map. Safe to call from many sessions at once (lock), cheap to call often
# (throttle).
#   sync.sh                          run now
#   sync.sh --throttle 1800          skip if a sync ran in the last 30 minutes
#   sync.sh --background             detach (used by the Stop hook so it never slows a turn)
# Problems are written to .git/context-sync/problem*; session-start.sh shows them.

set +e
CONTEXT_DIR="${CONTEXT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -d "$CONTEXT_DIR/.git" ] || exit 0
THROTTLE=0; BG=0
while [ $# -gt 0 ]; do
  case "$1" in
    --throttle) THROTTLE="$2"; shift 2 ;;
    --background) BG=1; shift ;;
    *) shift ;;
  esac
done

SYNC_DIR="$CONTEXT_DIR/.git/context-sync"; mkdir -p "$SYNC_DIR"
STAMP="$SYNC_DIR/last"; LOCK="$SYNC_DIR/lock"
NOW_TS=$(date +%s)
if [ "$THROTTLE" -gt 0 ] && [ -f "$STAMP" ]; then
  LAST=$(cat "$STAMP" 2>/dev/null); [ -n "$LAST" ] && [ $((NOW_TS - LAST)) -lt "$THROTTLE" ] && exit 0
fi
if [ "$BG" -eq 1 ]; then
  ( CONTEXT_DIR="$CONTEXT_DIR" nohup "$0" </dev/null >/dev/null 2>&1 & )
  exit 0
fi

# One sync at a time. A lock older than 10 minutes is a crashed run: clear it.
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +10 2>/dev/null)" ]; then rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || exit 0
  else exit 0; fi
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT
echo "$NOW_TS" > "$STAMP"

# Once a day, refresh the local digest of recent Claude Code sessions (read by the weekly refresh).
DIGEST="$CONTEXT_DIR/.digest/sessions-latest.md"
if command -v python3 >/dev/null 2>&1 && [ -z "$(find "$DIGEST" -mmin -1200 2>/dev/null)" ]; then
  ( CONTEXT_DIR="$CONTEXT_DIR" nohup python3 "$CONTEXT_DIR/scripts/digest-sessions.py" </dev/null >/dev/null 2>&1 & )
fi

T="${SYNC_TIMEOUT:-20}"
. "$CONTEXT_DIR/scripts/sync-lib.sh"   # PAT, stage_all, secret_hits, big_not_ignored
with_timeout() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }
in_rebase() { [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || [ -f .git/MERGE_HEAD ]; }

sync_one() {   # sync_one <folder> <problem-file>
  local dir="$1" PROBLEM="$2" HITS="" BIG=""
  if [ ! -d "$dir" ]; then
    echo "$dir: this folder is listed in backup.map but is not there any more, so it is not being backed up. If it moved, change its line in $CONTEXT_DIR/backup.map." > "$PROBLEM"; return 0
  fi
  cd "$dir" 2>/dev/null || return 0
  [ -d .git ] || return 0
  if in_rebase; then
    echo "$dir: a rebase or merge is in progress. Finish or abort it (git rebase --abort)." > "$PROBLEM"; return 0
  fi
  # .sync-include names paths that .gitignore hides from `git status`, so always look when it exists.
  if [ -n "$(git status --porcelain)" ] || [ -s .sync-include ]; then
    stage_all
    BIG="$(big_not_ignored | tr '\n' ' ' | sed 's/ $//')"
    if ! git diff --cached --quiet; then
      # Refuse to commit anything that looks like a credential (.sync-allow lists the exceptions).
      HITS="$(secret_hits | tr '\n' ' ' | sed 's/ $//')"
      if [ -n "$HITS" ]; then
        git reset -q
        echo "$dir: nothing was pushed. These files look like they contain a password, key or token: ${HITS}. Remove it from the file, add the file to .gitignore, or list it in .sync-allow if it is meant to be there. The next sync then goes through." > "$PROBLEM"; return 0
      fi
      git commit -q -m "sync: $(date '+%Y-%m-%d %H:%M') on $(hostname -s)" >/dev/null 2>&1
    fi
  fi
  if git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    GIT_TERMINAL_PROMPT=0 with_timeout "$T" git pull --rebase --quiet >/dev/null 2>&1
    if in_rebase; then
      git rebase --abort >/dev/null 2>&1
      echo "$dir: this machine's copy and GitHub's copy changed the same lines. Local commits are kept but not pushed. Fix: cd $dir && git pull --rebase" > "$PROBLEM"; return 0
    fi
    if [ -n "$(git rev-list '@{u}..HEAD' 2>/dev/null)" ]; then
      GIT_TERMINAL_PROMPT=0 with_timeout "$T" git push -q >/dev/null 2>&1
    fi
  fi
  if [ -n "$BIG" ]; then
    echo "$dir: these files are over 95 MB, which GitHub refuses, so they are NOT backed up: ${BIG}. Keep them somewhere else (Drive), or add them to .gitignore to silence this." > "$PROBLEM"; return 0
  fi
  # Clean and level with GitHub: clear any earlier problem.
  [ -z "$(git status --porcelain)" ] && [ -z "$(git rev-list '@{u}..HEAD' 2>/dev/null)" ] && rm -f "$PROBLEM"
  return 0
}

sync_one "$CONTEXT_DIR" "$SYNC_DIR/problem"

# Other working folders backed up the same way (added by scripts/backup-folder.sh).
if [ -f "$CONTEXT_DIR/backup.map" ]; then
  while IFS= read -r folder; do
    folder="${folder%"${folder##*[![:space:]]}"}"   # trim trailing spaces
    case "$folder" in ''|\#*) continue ;; esac
    case "$folder" in "~/"*) folder="$HOME/${folder#\~/}" ;; esac
    sync_one "$folder" "$SYNC_DIR/problem-$(basename "$folder")"
  done < "$CONTEXT_DIR/backup.map"
fi
exit 0
