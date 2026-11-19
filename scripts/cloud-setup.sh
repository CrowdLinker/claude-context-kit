#!/usr/bin/env bash
# Setup script for Claude Code cloud environments (claude.ai/code -> environment settings ->
# "Setup script"). It runs on the cloud machine before Claude Code starts; the result is cached
# and reused by later sessions in the environment.
#
# Why: a cloud session doesn't get your ~/.claude/CLAUDE.md, hooks or local skills, and repo
# hooks don't run when a session has more than one repository. You can attach the context repo
# as a second repository, but nothing tells Claude to read it. This appends a short section to
# the cloud machine's ~/.claude/CLAUDE.md that does.
#
# Before pasting: replace every <owner>/<repo> below with your private context repo.
# Needs no secrets. Best on your own environment. On one your team shares it is still safe: it
# only appends, and the section tells Claude to ignore it unless that repo is attached (teammates
# can see the repo name). If the environment already
# has a setup script, add this to the end of it, before any final "exit 0".
#
# Then attach the context repo as a second repository in each session (repo selector, or a link
# like https://claude.ai/code?repositories=<owner>/<code-repo>,<owner>/<repo>). The Claude GitHub
# app needs access to it.

mkdir -p ~/.claude
grep -q '<owner>/<repo>' ~/.claude/CLAUDE.md 2>/dev/null || cat >> ~/.claude/CLAUDE.md <<'EOF'

# Context repo (<owner>/<repo>)

This applies only when the private repo <owner>/<repo> is attached to this session as a
second repository (a folder with AGENTS.md and a projects/ folder; look with `ls -d */ ../*/`).
If it isn't attached, ignore this section.

- At the start, follow its AGENTS.md: read projects/<slug>/STATE.md and the 2-3 newest files
  in projects/<slug>/log/ for the project you are working on (the slug index is in AGENTS.md).
- At the end ("wrap", "/wrap"): pull first (`git pull --rebase` in the context repo), re-read
  STATE.md, change only what this session's work affects, add
  projects/<slug>/log/YYYY-MM-DD-cloud-<short-slug>.md, commit to main and push. Pushing is what
  makes the work visible to the other clients.
- STATE.md and the code win over anything remembered from elsewhere.
- Never store passwords, keys, tokens or session transcripts in that repo.
EOF
exit 0
