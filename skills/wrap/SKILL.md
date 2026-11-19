---
name: wrap
description: End-of-session save. Use on /wrap, "wrap", "wrap up", "save this session", "hand off", or before stopping. Rewrites the project's STATE so the next session (in any client) can pick up, writes a log entry, and commits and pushes.
---

# Wrap a session

Goal: the next session, in any client (terminal, desktop chat, cloud), can pick up exactly where
this one stopped, without reading this conversation.

The context repo's path is printed at session start ("Context repo: …"). If it wasn't, look
for it at `~/Code/context`, or ask.

## 1. Gather what happened
- Work out the project slug (argument, `.context` file at the repo root, or ask).
- Review this session: what changed, what was decided, where work stopped, what's next.
- In a code repo: `git status --short`, `git diff --stat`, `git log --oneline` since the
  session started.
- Client: `cloud` if the context repo isn't on disk; `chat` in a desktop chat; otherwise `local`.

## 2. Update STATE: rewrite, don't append
- **Code repo:** rewrite `docs/STATE.md` (in progress, next steps, known issues, how to run,
  recent decisions). Set `_Last updated: <date> by <client>_`.
- **Context repo** (if on disk): rewrite `projects/<slug>/STATE.md` for anything that changed
  outside the code. Leave sections that didn't change alone.
- Rules: describe the present. Delete lines that are no longer true. Under ~60 lines each.
  No secrets.

## 3. Log entry (context repo; skip in cloud)
Create `projects/<slug>/log/YYYY-MM-DD-<client>-<short-slug>.md` from `templates/log-entry.md`:
Done / Decided / Left off / Next. If a decision would be expensive to reverse, also add a file in
`decisions/` from `templates/decision.md`. Update `NOW.md`: remove items this session closed,
add new blockers.

## 4. Commit and push
- **Context repo:** `git -C <context repo> add -A && git -C <context repo> commit -m "wrap(<slug>): <summary>"`,
  then run `<context repo>/scripts/sync.sh` (rebases onto GitHub and pushes).
- **Code repo:** only if `git check-ignore -q docs/STATE.md` fails (the file is not local-only):
  `git commit -m "docs(state): <summary>" -- docs/STATE.md`. In team or client repos the file is
  excluded on purpose; leave it uncommitted. Push a feature branch; ask before pushing `main`.
- In cloud sessions, pushing is what makes the wrap visible to other clients. Don't skip it.

## 5. Confirm in 3 lines
What was saved, where, and the single next step. If anything couldn't be pushed, say so.
