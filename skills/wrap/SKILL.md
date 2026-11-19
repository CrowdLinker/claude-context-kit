---
name: wrap
description: End-of-session save. Use on /wrap, "wrap", "wrap up", "save this session", "hand off", or before stopping. Rewrites the project's STATE so the next session (in any client) can pick up, writes a log entry, and commits and pushes.
---

# Wrap a session

Goal: the next session, in any client (terminal, desktop chat, cloud), can pick up exactly where
this one stopped, without reading this conversation.

The context repo's path is printed at session start ("Context repo: …"). If it wasn't, look
for it at `~/Code/context`, or ask. In a cloud session it is there only if it was attached as a
second repository (a folder with `AGENTS.md` and `projects/`; look with `ls -d */ ../*/`).

## 1. Gather what happened
- Work out the project slug (argument, `.context` file at the repo root, or ask).
- Review this session: what changed, what was decided, where work stopped, what's next.
- In a code repo: `git status --short`, `git diff --stat`, `git log --oneline` since the
  session started.
- Client: `cloud` in a Claude Code cloud session; `chat` in a desktop chat; otherwise `local`.

## 2. Update STATE: refresh first, then rewrite (don't append)
Another session or client may have changed STATE since you last read it (several terminal tabs,
desktop chats and cloud sessions can all write to it). Before writing:
- **Context repo** (if on disk): run `<context repo>/scripts/sync.sh` (no flags) to commit pending
  local edits and pull GitHub's latest. If it prints or records a problem
  (`<context repo>/.git/context-sync/problem*`), stop and tell the user instead of writing.
  In a cloud session, run `git pull --rebase` in the context repo instead.
- **Code repo** with a committed `docs/STATE.md`: `git pull --rebase` if the branch has an
  upstream and the working tree is clean; if it isn't clean, ask before pulling.
- **Then re-read each STATE file from disk now.** Never write from a copy read earlier in the
  session. Change only the lines this session's work affects (edit in place, not a whole-file
  rewrite from memory) and keep lines other sessions added unless this session's work makes
  them untrue. If `_Last updated_` names another session or client since this one started,
  mention it in the log entry.

Then:
- **Code repo:** rewrite `docs/STATE.md` (in progress, next steps, known issues, how to run,
  recent decisions). Set `_Last updated: <date> by <client>_`.
- **Context repo** (if on disk): rewrite `projects/<slug>/STATE.md` for anything that changed
  outside the code. Leave sections that didn't change alone.
- Rules: describe the present. Delete lines that are no longer true. Under ~60 lines each.
  No secrets.

## 3. Log entry (context repo; skip if it isn't on disk or attached)
Create `projects/<slug>/log/YYYY-MM-DD-<client>-<short-slug>.md` from `templates/log-entry.md`:
Done / Decided / Left off / Next. If a decision would be expensive to reverse, also add a file in
`decisions/` from `templates/decision.md`. Update `NOW.md`: remove items this session closed,
add new blockers.

## 4. Commit and push
- **Context repo:** `git -C <context repo> add -A && git -C <context repo> commit -m "wrap(<slug>): <summary>"`,
  then run `<context repo>/scripts/sync.sh` (rebases onto GitHub and pushes). In a cloud session,
  `git pull --rebase && git push` in the context repo instead. If it isn't attached, say that only
  the code repo was saved.
- **Code repo:** only if `git check-ignore -q docs/STATE.md` fails (the file is not local-only):
  `git commit -m "docs(state): <summary>" -- docs/STATE.md`. In team or client repos the file is
  excluded on purpose; leave it uncommitted. Push a feature branch; ask before pushing `main`.
- In cloud sessions, pushing is what makes the wrap visible to other clients. Don't skip it.

## 5. Confirm in 3 lines
What was saved, where, and the single next step. If anything couldn't be pushed, say so.
