---
name: catchup
description: Start-of-session briefing. Use on /catchup, "catch me up", "where were we", "pick up where we left off", or when work starts on a project without context. Reads the project's STATE and recent logs (context repo + the code repo's docs/STATE.md) and gives a short brief.
---

# Catch up on a project

Goal: in under a minute, say where the project stands and what to do next, using only what's
written down, not guesses.

The context repo's path is printed at session start ("Context repo: …"). If it wasn't, look
for it at `~/Code/context`, or ask.

## 1. Work out the project
- If an argument was given (`/catchup my-app`), use it.
- Else look for a `.context` file at the repo root (one line: the project slug).
- Else, if inside the context repo, ask which project (list the slugs from AGENTS.md).
- For "what's on my plate" across everything, read `NOW.md` and summarise "Waiting on me".

## 2. Read, in this order
1. `<context repo>/projects/<slug>/STATE.md` (skip if the context repo isn't on disk; in a cloud
   session it is there only if it was attached as a second repository).
   Run `git -C <context repo> pull --ff-only` first if it hasn't been pulled this session.
2. The last 3 files in `<context repo>/projects/<slug>/log/` (by filename date).
3. In a code repo: `docs/STATE.md`, `git status --short`, current branch,
   `git log --oneline -10`, and whether the branch is behind its upstream.

## 3. Brief (about 8 lines)
- **Where it stands:** one or two lines.
- **Last session:** what was done, when, and from which client (chat / local / cloud).
- **Next step:** the first unchecked item, or the "Next" from the latest log.
- **Open questions:** only ones that block the next step.
- **Staleness:** flag anything that contradicts itself, e.g. STATE says X is in progress but
  the git log shows it merged; STATE older than the latest commits; repo behind upstream;
  uncommitted changes left over. Say what you'd correct.

Then ask what to work on, or carry on if that's already clear.

Don't rewrite STATE during catchup. Corrections happen at /wrap, or straight away if asked.
