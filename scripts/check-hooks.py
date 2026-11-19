#!/usr/bin/env python3
"""Find which SessionStart hook makes Claude Code say "hook output looks like a JSON object but is
not valid JSON".

    python3 <your context repo>/scripts/check-hooks.py

Runs every SessionStart hook from ~/.claude/settings.json and from installed plugins the way Claude
Code does (same input on stdin, from the home folder) and reports, for each, whether what it prints
is nothing, plain text, valid JSON, or text that starts like JSON but does not parse. Only the first
few characters of each output are shown. Run it from a normal terminal, not inside a Claude session.
"""
import glob, json, os, shlex, subprocess, sys

HOME = os.path.expanduser("~")
CLAUDE = os.environ.get("CLAUDE_CONFIG_DIR", os.path.join(HOME, ".claude"))
STDIN = json.dumps({
    "session_id": "00000000-0000-0000-0000-000000000000", "transcript_path": "",
    "cwd": HOME, "hook_event_name": "SessionStart", "source": "startup",
})


def load(path):
    try:
        with open(path, encoding="utf8") as f:
            return json.load(f)
    except Exception:
        return None


def session_start_commands(cfg):
    out = []
    for group in ((cfg or {}).get("hooks") or {}).get("SessionStart") or []:
        matcher = group.get("matcher") or ""
        for h in group.get("hooks") or []:
            if h.get("type", "command") == "command" and h.get("command"):
                cmd = h["command"]
                if isinstance(h.get("args"), list):   # some plugins keep the arguments separately
                    cmd += "".join(" " + shlex.quote(str(a)) for a in h["args"])
                out.append((matcher, cmd))
    return out


hooks = []  # (where it comes from, plugin root or None, matcher, command)
for name in ("settings.json", "settings.local.json"):
    for matcher, cmd in session_start_commands(load(os.path.join(CLAUDE, name))):
        hooks.append((name, None, matcher, cmd))

roots = {}
installed = load(os.path.join(CLAUDE, "plugins", "installed_plugins.json")) or {}
for plugin, entries in (installed.get("plugins") or {}).items():
    for e in entries if isinstance(entries, list) else [entries]:
        if isinstance(e, dict) and e.get("installPath"):
            roots[plugin] = e["installPath"]
if not roots:  # older layout: take the newest cached version of each plugin
    for d in sorted(glob.glob(os.path.join(CLAUDE, "plugins", "cache", "*", "*", "*")), key=os.path.getmtime):
        roots[os.path.basename(os.path.dirname(d))] = d
for plugin, root in sorted(roots.items()):
    for matcher, cmd in session_start_commands(load(os.path.join(root, "hooks", "hooks.json"))):
        hooks.append(("plugin " + plugin, root, matcher, cmd))

if not hooks:
    sys.exit("No SessionStart hooks found under " + CLAUDE)

bad = 0
for n, (src, root, matcher, cmd) in enumerate(hooks, 1):
    print("%d. %s%s\n   %s" % (n, src, " (matcher: %s)" % matcher if matcher else "", cmd[:150]))
    env = dict(os.environ, CLAUDE_PROJECT_DIR=HOME)
    if root:
        env["CLAUDE_PLUGIN_ROOT"] = root
        cmd = cmd.replace("${CLAUDE_PLUGIN_ROOT}", root).replace("$CLAUDE_PLUGIN_ROOT", root)
    try:
        r = subprocess.run(cmd, shell=True, input=STDIN.encode(), cwd=HOME, env=env,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
    except subprocess.TimeoutExpired:
        print("   TIMED OUT after 120s\n")
        continue
    text = r.stdout.decode("utf8", "replace")
    t = text.strip()
    verdict = "prints nothing"
    if t:
        verdict = "plain text (fine)"
        if t.startswith("{"):
            try:
                json.loads(t)
                verdict = "valid JSON (fine)"
            except ValueError as e:
                bad += 1
                pos = getattr(e, "pos", 0)
                verdict = "STARTS LIKE JSON BUT DOES NOT PARSE  <-- this is the failing hook\n   %s\n   around the break: %r" % (
                    e, t[max(0, pos - 60):pos + 60])
    print("   exit %d, %d bytes on stdout, %d on stderr: %s" % (r.returncode, len(r.stdout), len(r.stderr), verdict))
    if t:
        print("   starts: %r" % t[:70])
        if not t.startswith("{") and "{" in t:
            print("   note: a { first appears at character %d" % t.index("{"))
    if r.returncode and r.stderr:
        print("   stderr: %r" % r.stderr.decode("utf8", "replace").strip()[:200])
    print()

print("Result: %s" % ("%d hook(s) print broken JSON, marked above." % bad if bad else
                      "no hook printed broken JSON in this run. Paste this output anyway."))
