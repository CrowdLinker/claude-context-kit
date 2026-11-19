# Set it up by talking to Claude Code

Paste these into Claude Code, one at a time, in a session started from your home folder
(`cd ~ && claude`). Each prompt tells Claude to show you what it will change before it changes
anything. Read what it shows you; you are the one approving changes to your machine.

You need: Claude Code, git, python3, and the GitHub CLI (`gh`) signed in to your account.

---

## 1. Create your private copy and install it

```text
Set up a context repo for me from the template github.com/CrowdLinker/claude-context-kit.

1. Create my own PRIVATE copy and clone it to ~/Code/context:
   gh repo create context --private --template CrowdLinker/claude-context-kit --clone
   (run it from ~/Code; create ~/Code first if it doesn't exist). If the template option
   fails, clone the kit, delete its .git folder, git init, and create the private repo with
   gh repo create context --private --source . --push. The repo must be private: it will hold
   my working notes.
2. Before running anything, read install.sh and every file in scripts/. Tell me in five lines
   what install.sh will change on my machine.
3. Run ./install.sh --dry-run and show me the output. Wait for my OK, then run ./install.sh.
4. Check the result: ~/.claude/settings.json has the SessionStart, SessionEnd and Stop hooks,
   cleanupPeriodDays is set, and autoMemoryDirectory points into the repo. Run
   python3 scripts/check-hooks.py and tell me if any hook is not fine.
5. Tell me to start a new session and ask "Which folder is your memory in?".
```

The answer to that last question should be the `memory` folder inside your new repo.

---

## 2. Fill it with what you already have

```text
Fill my context repo (~/Code/context) with my current projects. Read its AGENTS.md first.

Sources, read-only: the files in memory/ (Claude Code's notes), the folder names, titles and
last-activity dates of my sessions under ~/.claude/projects (never copy transcript text into
the repo: transcripts are plaintext and can contain keys), and the folders in ~/Code with their
git log and README.

1. Propose a list of projects: slug, one line on what it is, its folders. Wait for my changes.
2. For each project I keep, create projects/<slug>/STATE.md from templates/STATE.md. Only write
   facts you can point to (a file, a commit, a memory note). Put anything you're unsure of under
   "Open questions". Set "Last updated" to today.
3. Fill NOW.md: what is waiting on me, what is in flight.
4. Add each code folder to repos.map. Use mode "local" for team and client repos (nothing gets
   committed there) and "commit" only for repos that are mine alone. Ask me which is which.
5. Add the projects to the index table in AGENTS.md.
6. Re-run ./install.sh, then scripts/sync.sh, and show me git log -3.
```

---

## 3. Back up a folder that isn't code

Sales notes, content drafts, client docs: anything that lives only on your laptop.

```text
Back up ~/<folder> to a new private GitHub repo, <my GitHub user>/<folder>-backup, using
~/Code/context/scripts/backup-folder.sh.

Before running it:
1. List what would be committed and what its .gitignore would leave out.
2. List files over 95 MB (GitHub refuses them; they will be skipped).
3. List every file that looks like it contains a password, key or token, and ask me about each
   one. Never add a file to .sync-allow or .sync-include without my explicit OK.
Then run the script and confirm the folder is listed in backup.map.
```

After this, every sync pushes that folder too.

---

## 4. After you move a project folder

Claude Code files each session under a name made from the folder's path. Move the folder and
`claude --resume` in the new place finds nothing.

```text
I moved ~/<old path> to ~/<new path>. Using ~/Code/context/scripts/move-sessions.sh:
1. Run it with -n first and show me what it would copy.
2. Run it for real. It copies; the originals stay.
3. Update the folder's line in ~/Code/context/repos.map and backup.map if it is listed there,
   then re-run ./install.sh.
4. Tell me to run "claude --resume" in the new folder to check.
```

---

## 5. Health check (monthly, or when something looks off)

```text
Check my context setup:
1. Run python3 ~/Code/context/scripts/check-hooks.py and explain anything that isn't fine.
2. Show any files in ~/Code/context/.git/context-sync/ whose name starts with "problem".
3. Show the time of the last commit on GitHub for the context repo and for every folder in
   backup.map, and say if any is more than a week old.
4. Check that cleanupPeriodDays and autoMemoryDirectory are still set in ~/.claude/settings.json.
Change nothing; just report.
```

---

## 6. Use it

- Start work in a linked folder: the project's STATE loads on its own.
- `/catchup` gives a short brief; `/wrap` saves where you stopped.
- Start from your home folder to see everything waiting on you.
- For Claude desktop Projects, paste `chat/PROJECT_INSTRUCTIONS.md` into each Project (it has an
  "only me" version for Projects shared with your team).
- For Claude Code cloud sessions, paste `scripts/cloud-setup.sh` into the environment's setup
  script, and attach the context repo as a second repository in each session.
