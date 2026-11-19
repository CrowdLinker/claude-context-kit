#!/usr/bin/env bash
# Set up Claude Code to use this context repo. Run from inside your PRIVATE copy of the repo;
# safe to re-run after every `git pull`.
#   ./install.sh --dry-run      show what it would do
#   ./install.sh                do it
#
#   1. Hooks in ~/.claude/settings.json (a dated backup is made first):
#        SessionStart  load the project's STATE (or the "Waiting on me" list for sessions started from ~)
#        SessionEnd    push the context repo (in the background)
#        Stop          push the context repo at most every 30 minutes, in the background
#      Also sets cleanupPeriodDays to 3650 if it is unset. Claude Code otherwise deletes session
#      transcripts older than 30 days. Lower it in ~/.claude/settings.json if you prefer.
#   2. Claude Code's auto memory for sessions started from your home folder is COPIED into
#      memory/ here, and Claude Code is pointed at the copy (autoMemoryDirectory). The original
#      folder is never changed or deleted. Skip with: SKIP_MEMORY=1 ./install.sh
#   3. /catchup and /wrap skills linked into ~/.claude/skills
#   4. Working folders listed in repos.map linked to their project (scripts/link-repos.sh)

set -euo pipefail
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
CONTEXT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODE_DIR="${CODE_DIR:-$(dirname "$CONTEXT_DIR")}"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
say() { printf '%s\n' "$*"; }

for t in git python3 perl; do command -v "$t" >/dev/null || { say "Needs $t on PATH."; exit 1; }; done
say "Context repo: $CONTEXT_DIR"

# This repo holds your working notes. Refuse to wire it up if GitHub says it is public.
if command -v gh >/dev/null 2>&1 && git -C "$CONTEXT_DIR" remote get-url origin >/dev/null 2>&1; then
  VIS="$(cd "$CONTEXT_DIR" && gh repo view --json visibility -q .visibility 2>/dev/null || true)"
  if [ "$VIS" = "PUBLIC" ]; then
    say "⛔ This repo is PUBLIC on GitHub. Make it private first (Settings → General → Danger Zone), then re-run."
    exit 1
  fi
  [ -n "$VIS" ] && say "GitHub visibility: $VIS"
fi
chmod +x "$CONTEXT_DIR/scripts/"*.sh "$CONTEXT_DIR/scripts/"*.py 2>/dev/null || true

# Claude Code names a project's folder after its path, every non-alphanumeric character turned into -.
MEM_SRC="$CLAUDE_HOME/projects/$(printf '%s' "$HOME" | sed 's/[^A-Za-z0-9]/-/g')/memory"
MEM_DST="$CONTEXT_DIR/memory"
case "$CONTEXT_DIR" in "$HOME"/*) MEM_SETTING="~/${CONTEXT_DIR#"$HOME"/}/memory" ;; *) MEM_SETTING="$MEM_DST" ;; esac
MOVE_MEMORY=1; [ "${SKIP_MEMORY:-0}" = 1 ] && MOVE_MEMORY=0

# --- 1 + 2. settings.json ----------------------------------------------------------
SETTINGS="$CLAUDE_HOME/settings.json"
say "1) Hooks → $SETTINGS"
if [ $DRY -eq 0 ]; then
  mkdir -p "$CLAUDE_HOME"
  [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  if [ $MOVE_MEMORY -eq 1 ] && [ ! -f "$MEM_DST/.moved-from" ]; then
    mkdir -p "$MEM_DST"
    if [ -d "$MEM_SRC" ]; then cp -Rp "$MEM_SRC/." "$MEM_DST/"; fi
    printf '%s  (copied %s; original left in place as a backup)\n' "$MEM_SRC" "$(date '+%Y-%m-%d %H:%M')" > "$MEM_DST/.moved-from"
  fi
  python3 - "$SETTINGS" "$CONTEXT_DIR" "$MOVE_MEMORY" "$MEM_SETTING" <<'PY'
import json, os, sys
path, ctx, move_memory, mem_setting = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
data = {}
if os.path.exists(path):
    with open(path) as f:
        txt = f.read().strip()
        data = json.loads(txt) if txt else {}
hooks = data.setdefault("hooks", {})
def add(event, command):
    groups = hooks.setdefault(event, [])
    for g in groups:
        for h in g.get("hooks", []):
            if h.get("command") == command:
                return "already present"
    groups.append({"hooks": [{"type": "command", "command": command}]})
    return "added"
s = os.path.join(ctx, "scripts")
print("   SessionStart:", add("SessionStart", os.path.join(s, "session-start.sh")))
print("   SessionEnd:  ", add("SessionEnd", os.path.join(s, "session-end.sh")))
print("   Stop:        ", add("Stop", os.path.join(s, "sync.sh") + " --throttle 1800 --background"))
if "cleanupPeriodDays" not in data:
    data["cleanupPeriodDays"] = 3650
    print("   Transcript retention: cleanupPeriodDays set to 3650 (was unset, i.e. the 30-day default)")
else:
    print("   Transcript retention: cleanupPeriodDays is", data["cleanupPeriodDays"], "- left alone")
if move_memory:
    cur = data.get("autoMemoryDirectory")
    if cur in (None, mem_setting):
        data["autoMemoryDirectory"] = mem_setting
        print("2) Claude Code memory →", mem_setting, "(already set)" if cur else "(set)")
    else:
        print("2) ⚠️ autoMemoryDirectory is already", cur, "- left alone")
with open(path, "w") as f:
    json.dump(data, f, indent=2); f.write("\n")
PY
else
  say "  [dry-run] would add SessionStart, SessionEnd and Stop hooks, and set cleanupPeriodDays to 3650 if unset"
  [ $MOVE_MEMORY -eq 1 ] && say "  [dry-run] would copy $MEM_SRC → $MEM_DST and set autoMemoryDirectory to $MEM_SETTING"
fi

# --- 3. Skills ----------------------------------------------------------------------
say "3) Skills → $CLAUDE_HOME/skills"
for s in catchup wrap; do
  target="$CLAUDE_HOME/skills/$s"
  if [ -L "$target" ] || [ ! -e "$target" ]; then
    [ $DRY -eq 1 ] || { mkdir -p "$CLAUDE_HOME/skills"; ln -sfn "$CONTEXT_DIR/skills/$s" "$target"; }
    say "   /$s linked"
  else
    say "   ⚠️ $target exists and isn't a link - left alone"
  fi
done

# --- 4. Working folders ---------------------------------------------------------------
say "4) Working folders (repos.map)"
CONTEXT_DIR="$CONTEXT_DIR" CODE_DIR="$CODE_DIR" DRY="$DRY" bash "$CONTEXT_DIR/scripts/link-repos.sh"

say ""
say "Done. Check it worked:"
say "  • New terminal:  cd ~ && claude   → it should open with your 'Waiting on me' list."
say "  • Ask it: \"Which folder is your memory in?\"  → should be $MEM_SETTING"
say "  • python3 $CONTEXT_DIR/scripts/check-hooks.py  → every SessionStart hook should be fine."
