#!/usr/bin/env bash
# Claude Code SessionEnd hook: push anything a session left in the context repo.
# Only touches the context repo, never your code repos.
CONTEXT_DIR="${CONTEXT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
# Detached: Claude Code cancels SessionEnd hooks when it exits quickly (seen Nov 19 after
# `claude plugin update`), and a sync killed half-way through a rebase leaves the repo stuck.
[ -x "$CONTEXT_DIR/scripts/sync.sh" ] && "$CONTEXT_DIR/scripts/sync.sh" --throttle 60 --background
exit 0
