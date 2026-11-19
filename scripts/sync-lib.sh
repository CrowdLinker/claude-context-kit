#!/usr/bin/env bash
# Shared by sync.sh and backup-folder.sh. Call these from inside a git working folder.
#
# Optional control files in a backed-up folder (one path per line, # starts a comment):
#   .sync-include  paths to commit even though a .gitignore rule (in any subfolder) excludes them.
#                  A folder name takes everything under it. Use for dependencies you want kept
#                  (node_modules, .venv) or a specific env file.
#   .sync-allow    files exempt from the credential check. A line ending in / exempts a folder.
#
# Files over 95 MB are always left out: GitHub refuses them and one would block every later push.

PAT='((^|[^A-Za-z0-9_/-])sk-[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY|hooks\.slack\.com/services/|AC[0-9a-f]{32}|eyJ[A-Za-z0-9_-]{20,}\.eyJ)'
MAX_BYTES=95000000

ctl_lines() {   # ctl_lines <file>: its lines without comments, blanks or a trailing CR
  [ -f "$1" ] && tr -d '\r' < "$1" | sed -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d'
}

oversize_files() {   # working-tree files over MAX_BYTES, as paths relative to the folder
  find . -name .git -prune -o -type f -size +"${MAX_BYTES}"c -print 2>/dev/null | sed 's|^\./||'
}

# Stage everything that should be backed up. Sets SKIPPED_BIG (newline-separated, may be empty).
stage_all() {
  local ex=() f p
  SKIPPED_BIG=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    ex+=(":(exclude,literal)$f"); SKIPPED_BIG="${SKIPPED_BIG}${f}"$'\n'
  done < <(oversize_files)
  git add -A -- . ${ex[@]+"${ex[@]}"} 2>/dev/null
  while IFS= read -r p; do
    [ -e "$p" ] && git add -f -- "$p" ${ex[@]+"${ex[@]}"} 2>/dev/null
  done < <(ctl_lines .sync-include)
  return 0
}

big_not_ignored() {   # the skipped big files that no .gitignore rule covers: these need attention
  printf '%s' "$SKIPPED_BIG" | while IFS= read -r f; do
    [ -n "$f" ] && ! git check-ignore -q -- "$f" 2>/dev/null && printf '%s\n' "$f"
  done
}

not_allowed() {   # stdin: paths. stdout: the ones .sync-allow does not exempt
  local f a ok
  while IFS= read -r f; do
    ok=0
    while IFS= read -r a; do
      case "$a" in
        */) case "$f" in "$a"*) ok=1 ;; esac ;;
        *)  [ "$f" = "$a" ] && ok=1 ;;
      esac
      [ "$ok" = 1 ] && break
    done < <(ctl_lines .sync-allow)
    [ "$ok" = 1 ] || printf '%s\n' "$f"
  done
}

secret_hits() {   # staged, changed files that look like they hold a credential and are not exempt
  git -c core.quotePath=false diff --cached --name-only --diff-filter=AM -z \
    | GIT_LITERAL_PATHSPECS=1 xargs -0 sh -c '[ $# -gt 0 ] && git -c core.quotePath=false grep --cached -lIE -e "$0" -- "$@"' "$PAT" 2>/dev/null \
    | not_allowed
}
