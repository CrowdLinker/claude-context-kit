#!/usr/bin/env bash
# After a working folder has moved, make its Claude Code session history show up at the new place.
#   scripts/move-sessions.sh ~/old-place/my-project ~/Code/my-project
#   scripts/move-sessions.sh -n <old> <new>      only show what it would do
#
# Claude Code files each session under ~/.claude/projects/<the folder's path, every other character
# turned into ->. After a move, `claude --resume` in the new folder looks under a different name and
# finds nothing. This script COPIES the session files to the name that matches the new path and
# points the copies at the new path. The originals are left exactly as they are, and a file that
# already exists at the new name is never overwritten. If you use the herdr-claude-kit restore
# scripts, it also repoints their records (~/.local/state/claude-resume).
# Sessions started from your home folder are filed under it and are not affected by a move.
set -u
DRY=0; [ "${1:-}" = "-n" ] && { DRY=1; shift; }
[ $# -eq 2 ] || { sed -n '2,4p' "$0"; exit 1; }
abs() { case "$1" in "~/"*) printf '%s' "$HOME/${1#\~/}" ;; /*) printf '%s' "$1" ;; *) printf '%s' "$PWD/$1" ;; esac; }
OLD="$(abs "$1")"; OLD="${OLD%/}"
NEW="$(abs "$2")"; NEW="${NEW%/}"
[ -d "$NEW" ] || { echo "The new folder is not there: $NEW. Move the folder first."; exit 1; }
NEW="$(cd "$NEW" && pwd -P)"
if [ -d "$OLD" ] && [ ! -L "$OLD" ]; then echo "The old folder is still there: $OLD. Move it first (mv \"$OLD\" \"$NEW\")."; exit 1; fi
[ "$OLD" != "$NEW" ] || { echo "Old and new are the same folder."; exit 1; }

PROJ="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects"
enc() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }
OLDENC="$(enc "$OLD")"; NEWENC="$(enc "$NEW")"
export MS_OLD="$OLD" MS_NEW="$NEW" MS_OLDP="$PROJ/$OLDENC" MS_NEWP="$PROJ/$NEWENC"

repoint() {   # repoint <copied file>: the folder a session belongs to, old path -> new path
  perl -pi -e 's{("cwd"\s*:\s*")\Q$ENV{MS_OLD}\E(?=["/])}{$1$ENV{MS_NEW}}g' "$1"
}

copied=0; kept=0; dirs=0
for d in "$PROJ/$OLDENC" "$PROJ/$OLDENC"-*; do
  [ -d "$d" ] || continue
  suffix="${d#"$PROJ/$OLDENC"}"
  if [ -n "$suffix" ]; then
    # A longer name is either a subfolder of the moved folder or an unrelated neighbour
    # (~/my-project-old). Only take it if its sessions really ran under the old folder.
    grep -qsF "\"cwd\":\"$OLD/" "$d"/*.jsonl 2>/dev/null || continue
  fi
  target="$PROJ/$NEWENC$suffix"; dirs=$((dirs + 1))
  echo "$(basename "$d")  ->  $(basename "$target")"
  while IFS= read -r -d '' rel; do
    rel="${rel#./}"; dst="$target/$rel"
    if [ -e "$dst" ]; then kept=$((kept + 1)); continue; fi
    copied=$((copied + 1))
    [ "$DRY" = 1 ] && continue
    mkdir -p "$(dirname "$dst")" && cp -p "$d/$rel" "$dst" || { echo "  could not copy $rel"; exit 1; }
    case "$rel" in
      *.jsonl) repoint "$dst"; touch -r "$d/$rel" "$dst" ;;
      sessions-index.json) repoint "$dst"
        perl -pi -e 's{\Q$ENV{MS_OLDP}\E(?=[/-])}{$ENV{MS_NEWP}}g; s{"\Q$ENV{MS_OLD}\E(?=["/])}{"$ENV{MS_NEW}}g' "$dst" ;;
    esac
  done < <(cd "$d" && find . -type f -print0)
done

# herdr-claude-kit restore records (optional): one small JSON file per terminal, holding the folder and the transcript path.
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/claude-resume"; recs=0
for f in "$STATE"/*.json; do
  [ -f "$f" ] || continue
  grep -qE "\"cwd\":[[:space:]]*\"$(printf '%s' "$OLD" | sed 's/[][\.*^$+?(){}|]/\\&/g')[\"/]" "$f" || continue
  recs=$((recs + 1))
  [ "$DRY" = 1 ] && continue
  mkdir -p "$STATE/.before-move" && cp -p "$f" "$STATE/.before-move/$(basename "$f")" || continue
  repoint "$f"
  perl -pi -e 's{\Q$ENV{MS_OLDP}\E(?=[/-])}{$ENV{MS_NEWP}}g' "$f"
done

did="Copied"; [ "$DRY" = 1 ] && did="Would copy"
if [ "$dirs" -eq 0 ]; then
  echo "No Claude Code sessions were started inside $OLD (nothing under $PROJ/$OLDENC), so there is nothing to carry over."
else
  echo "$did $copied files to the new location; $kept were already there and were left alone."
  echo "Originals untouched: $PROJ/$OLDENC"
fi
[ "$recs" -gt 0 ] && echo "Restore records repointed: $recs (copies of the old ones are in $STATE/.before-move)"
[ "$DRY" = 1 ] || [ "$dirs" -eq 0 ] || echo "Check: cd \"$NEW\" && claude --resume"
exit 0
