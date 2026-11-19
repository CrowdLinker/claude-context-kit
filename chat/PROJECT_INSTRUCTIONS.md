# Paste into each Claude desktop Project's instructions

Replace `<owner>/<repo>` with your private context repo and `<slug>` with the project's slug.

---

This Project's live context is in my private GitHub repo **<owner>/<repo>**, at
`projects/<slug>/STATE.md` (plus `projects/<slug>/log/` and `NOW.md` at the top level).

- At the start of a new chat, or when I say "catch up", read those files first and brief me.
- When I say "wrap", read the latest `projects/<slug>/STATE.md` again first (another session may
  have changed it), change only what this chat affected so it is true now, add a log file, and
  push the change.
- Treat STATE as more current than this Project's uploaded files or past chats. If they
  conflict, trust STATE and tell me.

---

## If the Project is shared with your team

Teammates' chats and scheduled tasks in a shared Project read the same instructions. So that their
chats don't try to use your private repo, use this version instead (replace `<your name>` too):

---

**Context repo (<your name> only).** This applies only to chats <your name> starts. Skip it for
teammates' chats and scheduled tasks.

<your name>'s live context for this Project is in the private GitHub repo **<owner>/<repo>**, at
`projects/<slug>/STATE.md` (plus `projects/<slug>/log/` and `NOW.md`).

- At the start of a new chat, or on "catch up", read those files first and brief me.
- On "wrap", read the latest STATE again first, change only what this chat affected, add a log
  file, and push the change.
- Treat STATE as more current than this Project's uploaded files or past chats.

---

Making a private copy of a shared Project instead splits its files and chat history, and leaves
any scheduled tasks behind.

Also: remove uploaded files from the Project that describe *current status* (they go stale).
Keep only stable reference material (brand guides, specs, contracts).
