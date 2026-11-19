# Context repo — agent instructions

This private repo is the shared memory between every place I work with an AI agent: Claude Code
in the terminal, Claude desktop chats (Projects), cloud sessions, and any other agent. If it isn't
here (or in a code repo's `docs/STATE.md`), the next session won't know it.

## Rules for every session

1. **Start:** read the `STATE.md` for the project you're working on, plus the last 2–3 files in
   its `log/`. If you don't know which project, ask, or read the index below. For "what's on my
   plate" questions, read `NOW.md`.
2. **Trust order when sources disagree:** the code itself > `STATE.md` > log entries > anything
   you remember from elsewhere. If STATE looks wrong, say so; don't silently work around it.
3. **End (when I say "wrap", or run `/wrap`):**
   - Rewrite `STATE.md` so it is true *now*. Overwrite stale lines; don't append history to it.
     Keep it under ~60 lines. History belongs in the log.
   - Add one log file: `log/YYYY-MM-DD-<client>-<slug>.md` (client = `chat`, `local`, `cloud`).
   - Update `NOW.md` if an item there was closed or a new blocker appeared.
   - Record any real decision (one that would be expensive to reverse) in `decisions/`.
   - Push: run `scripts/sync.sh`. Hooks also run it at session start, session end and every
     30 minutes, so an edit to STATE.md is enough on its own.
4. **One writer per project at a time.** If several agents work the same project in parallel,
   only the lead session rewrites `STATE.md`; the others only add log files.
5. **Never store here:** passwords, API keys, tokens, webhook URLs, session transcripts, and
   anything you wouldn't want in a breach. Link to where those live instead. `scripts/sync.sh`
   refuses to push files that look like they contain a credential.

## Project index

| Slug | What it is | Code repo(s) |
|---|---|---|
| `example` | Replace with your first project | — |

## How the pieces fit
- `projects/<slug>/STATE.md` + `NOW.md`: the shared layer. Pushed to GitHub; every client can read it.
- `memory/`: Claude Code's own auto memory (its `autoMemoryDirectory`), pushed with everything else.
- `.digest/` (this machine only, git-ignored): optional digest of recent sessions, written by
  `scripts/digest-sessions.py`, for a scheduled weekly refresh.
- `backup.map`: other working folders (sales, marketing, docs) that `scripts/sync.sh` commits and
  pushes to their own private repos. Add one with `scripts/backup-folder.sh`.
- Code repos: `docs/STATE.md` holds engineering state. In team or client repos it stays local
  (`repos.map` mode `local`: nothing is committed). In your own repos (mode `commit`) it is
  committed so cloud sessions see it.

Adding a project: copy `templates/STATE.md` into `projects/<slug>/`, add a row above, and if it has
a repo, add it to `repos.map` and re-run `install.sh`.
