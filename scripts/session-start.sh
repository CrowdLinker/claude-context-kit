#!/usr/bin/env bash
# Claude Code SessionStart hook (install.sh adds it to ~/.claude/settings.json).
# Works out which project this session belongs to FIRST, and only then touches git:
#   - inside a linked folder (a .context file names the project) -> that project's STATE + last 3 logs
#   - started from your home folder                             -> the "Waiting on me" list from NOW.md
#   - anything else (unlinked folders, temp folders)            -> nothing, no git
# Whatever this prints is added to Claude's context (Claude Code caps it at 10,000 characters).
# Never blocks, never fails.

set +e
CONTEXT_DIR="${CONTEXT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
[ -d "$CONTEXT_DIR/.git" ] || exit 0     # cloud sessions / other machines: nothing to do

INPUT=""; [ -t 0 ] || INPUT="$(cat)"
SOURCE="$(printf '%s' "$INPUT" | sed -n 's/.*"source"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' | head -n1)"
WORK_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
SHOWN_DIR="$CONTEXT_DIR"; case "$CONTEXT_DIR" in "$HOME"/*) SHOWN_DIR="~/${CONTEXT_DIR#"$HOME"/}" ;; esac

case "$WORK_DIR" in
  /private/tmp/*|/tmp/*|*/.claude-mem*|*/observer-sessions*) exit 0 ;;
esac

find_up() { local d="$1"; while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "$HOME" ]; do
  [ -f "$d/$2" ] && { echo "$d"; return; }; d="$(dirname "$d")"; done; }

MODE=""; SLUG=""
REPO_ROOT="$(find_up "$WORK_DIR" .context)"
if [ -n "$REPO_ROOT" ]; then
  MODE=project; SLUG="$(head -n1 "$REPO_ROOT/.context" | tr -d '[:space:]')"
else
  case "$WORK_DIR" in
    "$CONTEXT_DIR"*) MODE=context ;;
    "$HOME") MODE=home ;;
    *) exit 0 ;;
  esac
fi

# Bring the context repo level with GitHub (short timeouts; skipped if another session just did it).
SYNC_TIMEOUT=8 "$CONTEXT_DIR/scripts/sync.sh" --throttle 120
for PROBLEM in "$CONTEXT_DIR"/.git/context-sync/problem*; do
  [ -f "$PROBLEM" ] && echo "⚠️ Sync problem: $(cat "$PROBLEM")"
done

with_timeout() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }

echo "Context repo: $SHOWN_DIR"
case "$MODE" in
  context)
    echo "This session is inside the context repo. NOW.md lists what is waiting; AGENTS.md has the rules and the project index." ;;
  home)
    echo "=== Waiting on me (from NOW.md) ==="
    awk '/^## Waiting on me/{p=1; next} /^## /{p=0} p' "$CONTEXT_DIR/NOW.md" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -n 25
    echo "Each project has $SHOWN_DIR/projects/<slug>/STATE.md (index in AGENTS.md). Read the one for this session's work before relying on older notes." ;;
  project)
    if [ -n "$REPO_ROOT" ] && git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      GIT_TERMINAL_PROMPT=0 with_timeout 8 git -C "$REPO_ROOT" fetch --quiet >/dev/null 2>&1
      BEHIND="$(git -C "$REPO_ROOT" rev-list --count 'HEAD..@{u}' 2>/dev/null)"
      [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ] && echo "⚠️ This repo is $BEHIND commit(s) behind its upstream. Suggest: git pull."
    fi
    STATE="$CONTEXT_DIR/projects/$SLUG/STATE.md"
    if [ -f "$STATE" ]; then
      echo "=== Project context: $SLUG ==="
      cat "$STATE"
      RECENT="$(ls -1 "$CONTEXT_DIR/projects/$SLUG/log"/*.md 2>/dev/null | sort | tail -n 3)"
      if [ -n "$RECENT" ]; then
        echo; echo "=== Last session logs ==="
        for f in $RECENT; do echo "--- $(basename "$f")"; head -n 25 "$f"; done
      fi
    fi ;;
esac

# Long sessions never "end", so compaction is the checkpoint.
if [ "$SOURCE" = "compact" ]; then
  echo
  echo "Context was just compacted. If this session changed where a project stands, update $SHOWN_DIR/projects/<slug>/STATE.md and NOW.md now (or run /wrap), before continuing."
elif [ "$MODE" != "context" ]; then
  echo "(When this session changes a project's status: /wrap, or edit that STATE.md directly. Changes are pushed automatically.)"
fi
exit 0
