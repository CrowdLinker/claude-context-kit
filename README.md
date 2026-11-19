# claude-context-kit

Keep Claude Code's memory and your project context in a private GitHub repo instead of only on
your laptop, so every session, on any machine or client, starts from where the last one stopped.

Written up in [How to keep your Claude Code context and memory in GitHub](https://www.crowdlinker.com/blog/claude-code-context-memory-github)
on the Crowdlinker blog.

## Why

Three things about Claude Code's defaults are easy to miss:

- **Transcripts are deleted after 30 days.** Claude Code removes session transcripts older than
  `cleanupPeriodDays` at startup, and the default is 30
  ([docs](https://code.claude.com/docs/en/claude-directory#cleaned-up-automatically)).
- **Auto memory is machine-local.** Claude Code's notes to itself live under
  `~/.claude/projects/<project>/memory/` and "are not shared across machines or cloud
  environments" ([docs](https://code.claude.com/docs/en/memory#auto-memory)).
- **Transcripts are plaintext.** If a tool reads a `.env` file, the value is written to the
  transcript ([docs](https://code.claude.com/docs/en/claude-directory#plaintext-storage)).
  So transcripts should not go to GitHub, even a private repo.

This kit keeps the memory and a short, current STATE per project in a private repo that syncs
itself, keeps transcripts on your machine for ten years instead of thirty days, and never
pushes them.

## What it sets up

| Piece | What it does |
|---|---|
| `projects/<slug>/STATE.md` | One page per project: where it stands now, next steps, open questions. Rewritten, never appended. Under ~60 lines |
| `projects/<slug>/log/` | One short file per session: done, decided, left off, next |
| `NOW.md` | What's waiting on you across all projects |
| `memory/` | Claude Code's auto memory, moved here with `autoMemoryDirectory` |
| SessionStart hook | Loads the right STATE when you start Claude in a linked folder, or `NOW.md` from your home folder |
| SessionEnd + Stop hooks | Commit, rebase and push in the background, at most every 30 minutes |
| `/catchup`, `/wrap` | Skills to brief you at the start and save where you stopped at the end |
| `scripts/backup-folder.sh` | Puts a non-code folder (sales, content, docs) in its own private repo and keeps it pushed |
| `scripts/move-sessions.sh` | After you move a folder, copies its session history to where Claude Code now looks |
| `scripts/check-hooks.py` | Runs every SessionStart hook and names the one that prints broken JSON |
| `scripts/cloud-setup.sh` | Setup-script block that points Claude Code cloud sessions at the context repo |

## Quick start

Open [PROMPTS.md](PROMPTS.md) and paste prompt 1 into Claude Code. It creates your private copy
from this template, reads the scripts, shows you what will change, and installs after you agree.

Doing it by hand instead:

```bash
cd ~/Code
gh repo create context --private --template CrowdLinker/claude-context-kit --clone
cd context && ./install.sh --dry-run && ./install.sh
```

Then start a new session and ask "Which folder is your memory in?". It should name the `memory`
folder inside your repo.

## Cloud sessions

Claude Code cloud sessions (claude.ai/code) run on a fresh machine. They don't get your
`~/.claude/CLAUDE.md`, the hooks or your local skills
([docs](https://code.claude.com/docs/en/cloud-environments#what-carries-over-from-your-setup)),
and a session with more than one repository doesn't run the repos' hooks
([docs](https://code.claude.com/docs/en/settings#settings-in-cloud-sessions)). Skills you enable
on claude.ai do load. To give cloud sessions the same context:

1. Paste [`scripts/cloud-setup.sh`](scripts/cloud-setup.sh) into the environment's setup script
   (replace `<owner>/<repo>` first). It appends a short section to the cloud machine's
   `~/.claude/CLAUDE.md`: read STATE at the start; pull, update and push at the end. This is the
   documented way to add personal instructions to a cloud session
   ([docs](https://code.claude.com/docs/en/cloud-environments#add-personal-preferences-without-committing-to-the-repo)).
   It needs no secrets. The docs suggest your own environment rather than a shared one; on a
   shared one, Claude ignores the section unless the context repo is attached, but teammates can
   see your repo's name.
2. In each session, attach the context repo as a second repository next to the code repo. The
   Claude GitHub app needs access to it, and `/wrap` pushes to its `main` branch, so branch
   protection on that repo would block it.

This part is newer than the rest of the kit and hasn't had as much use yet. In your first cloud
session, run `/context` and check that `/root/.claude/CLAUDE.md` is listed under Memory files.

## Desktop chats

Paste [`chat/PROJECT_INSTRUCTIONS.md`](chat/PROJECT_INSTRUCTIONS.md) into each Claude desktop
Project's instructions. For a Project shared with your team, use the "only me" version in the same
file, so teammates' chats and scheduled tasks don't try to use your private repo.

## Safety

- **Your copy must be private.** `install.sh` stops if GitHub reports the repo as public.
- **Credential check.** Before every commit, `sync.sh` scans the changed files for things that
  look like API keys, tokens, private keys and webhook URLs, and refuses to push them. A file you
  deliberately keep in a private backup repo can be listed in that folder's `.sync-allow`.
- **Transcripts never leave your machine.** The optional `digest-sessions.py` writes a redacted
  summary of recent sessions to `.digest/`, which is git-ignored.
- **Team and client repos stay clean.** In `local` mode, the project link goes in
  `CLAUDE.local.md` and `.git/info/exclude`, so nothing appears in `git status` for your team.
- **Files over 95 MB are skipped,** because GitHub refuses them and one would block every later push.
- **Nothing is deleted.** The memory move is a copy; `move-sessions.sh` copies; `install.sh`
  backs up `settings.json` before editing it.

## What it doesn't do

- It is not a backup of your machine. Transcripts, `~/.claude` and anything not committed still
  need Time Machine or a cloud backup.
- It doesn't merge two people's notes. Keep one writer per project at a time. `/wrap` pulls and
  re-reads STATE before writing and changes only its own lines, so two of your own sessions don't
  undo each other, but it is not a merge tool.
- Notes can go stale like any document. The rules in `AGENTS.md` make sessions rewrite STATE
  rather than add to it, and trust the code over the notes when they disagree.

Tested on macOS with zsh and Claude Code 2.1.327 and 2.1.328. The sync scripts were also tested on
Linux. Claude Code changes quickly: re-run `scripts/check-hooks.py` after updates.

## Uninstall

Remove the three hook entries and `autoMemoryDirectory` from `~/.claude/settings.json` (or
restore one of the `settings.json.bak.*` copies), and delete the `catchup` and `wrap` links in
`~/.claude/skills`. Your original memory folder under `~/.claude/projects` was never touched.

## Licence

MIT. Made by [Crowdlinker](https://www.crowdlinker.com). Companion to
[herdr-claude-kit](https://github.com/CrowdLinker/herdr-claude-kit), which brings long-running
Claude Code sessions back after a reboot.
