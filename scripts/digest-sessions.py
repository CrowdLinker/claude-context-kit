#!/usr/bin/env python3
"""Write a short digest of recent Claude Code sessions for the weekly context refresh.

Reads the session transcripts Claude Code keeps in ~/.claude/projects (they never leave that
folder) and writes, for every session active in the last N days, its title, folder, last
activity and the last few exchanges to <context repo>/.digest/sessions-latest.md.

The digest stays on this machine: .digest/ is git-ignored. Anything that looks like a credential
is replaced with [REDACTED] anyway.

    digest-sessions.py [--days 8] [--out PATH]
"""
import argparse, json, os, re, sys, time
from datetime import datetime

HOME = os.path.expanduser("~")
CONTEXT_DIR = os.environ.get("CONTEXT_DIR", os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROJECTS = os.path.join(os.environ.get("CLAUDE_HOME", os.path.join(HOME, ".claude")), "projects")
TAIL_BYTES = 4 * 1024 * 1024
MAX_TOTAL = 200_000

SECRET = re.compile(
    r"(sk-[A-Za-z0-9_-]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{30,}"
    r"|-----BEGIN [A-Z ]*PRIVATE KEY[\s\S]*?(?:-----END [A-Z ]*PRIVATE KEY-----|$)"
    r"|https://hooks\.slack\.com/services/\S+|AC[0-9a-f]{32}|eyJ[A-Za-z0-9_-]{20,}\.eyJ[A-Za-z0-9_.-]+)")
KEYVAL = re.compile(r"(?i)\b(api[_ -]?key|secret|token|password|passwd|pwd)\b(\s*(?:is|[:=])\s*)(\S{6,})")


def clean(text, limit):
    text = SECRET.sub("[REDACTED]", text)
    text = KEYVAL.sub(lambda m: m.group(1) + m.group(2) + "[REDACTED]", text)
    text = " ".join(text.split())
    return text if len(text) <= limit else text[:limit].rstrip() + " …"


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return " ".join(x.get("text", "") for x in content if isinstance(x, dict) and x.get("type") == "text")
    return ""


def title_of(path):
    """Cheap full pass: only parse the few lines that carry a session title."""
    title = None
    try:
        with open(path, "rb") as fh:
            for line in fh:
                if b'-title"' in line or b'"customTitle"' in line:
                    try:
                        d = json.loads(line)
                    except Exception:
                        continue
                    title = d.get("customTitle") or d.get("title") or d.get("aiTitle") or title
    except OSError:
        pass
    return title


def tail_events(path):
    size = os.path.getsize(path)
    with open(path, "rb") as fh:
        if size > TAIL_BYTES:
            fh.seek(size - TAIL_BYTES)
            fh.readline()                       # drop the partial first line
        raw = fh.read().decode("utf-8", "ignore")
    events, cwd, last_ts = [], None, None
    for line in raw.splitlines():
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("cwd"):
            cwd = d["cwd"]
        ts = d.get("timestamp")
        if ts:
            last_ts = ts
        t = d.get("type")
        msg = d.get("message") or {}
        if t == "user" and not d.get("isMeta") and not d.get("isCompactSummary"):
            txt = text_of(msg.get("content")).strip()
            if txt and not txt.startswith("<"):
                events.append((ts, "U", txt))
        elif t == "assistant":
            txt = text_of(msg.get("content")).strip()
            if txt:
                events.append((ts, "A", txt))
    return events, cwd, last_ts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--days", type=float, default=8)
    ap.add_argument("--out", default=os.path.join(CONTEXT_DIR, ".digest", "sessions-latest.md"))
    a = ap.parse_args()
    cutoff = time.time() - a.days * 86400

    sessions = []
    if os.path.isdir(PROJECTS):
        for proj in sorted(os.listdir(PROJECTS)):
            if "observer-sessions" in proj or "scratchpad" in proj:
                continue
            pdir = os.path.join(PROJECTS, proj)
            if not os.path.isdir(pdir):
                continue
            for name in os.listdir(pdir):
                path = os.path.join(pdir, name)
                if not name.endswith(".jsonl") or not os.path.isfile(path):
                    continue
                try:
                    if os.path.getmtime(path) < cutoff:
                        continue
                    events, cwd, last_ts = tail_events(path)
                except OSError:
                    continue
                if not any(r == "U" for _, r, _ in events):
                    continue
                sessions.append(dict(id=name[:-6], path=path, events=events, cwd=cwd or "?",
                                     last=last_ts or "", title=title_of(path), mb=os.path.getsize(path) / 1e6))
    sessions.sort(key=lambda s: s["last"], reverse=True)

    out = [f"# Claude Code sessions active in the last {a.days:g} days",
           f"_Generated {datetime.now().strftime('%Y-%m-%d %H:%M')} on this machine from ~/.claude/projects. "
           "Local only: never commit or paste this file. Credentials are redacted, but treat it as private._", ""]
    total = 0
    for s in sessions:
        users = [i for i, e in enumerate(s["events"]) if e[1] == "U"]
        start = users[-4] if len(users) >= 4 else users[0]
        block = [f"## {clean(s['title'] or s['events'][users[0]][2], 90)}  ({s['id'][:8]})",
                 f"- Folder: `{s['cwd']}` · last active: {s['last'][:16].replace('T', ' ')} UTC · size: {s['mb']:.0f} MB",
                 f"- Resume: `cd {s['cwd']} && claude --resume {s['id']}`", ""]
        chunk = s["events"][start:]
        for i, (ts, role, txt) in enumerate(chunk):
            nxt = chunk[i + 1][1] if i + 1 < len(chunk) else None
            if role == "U":
                block.append(f"**Me ({(ts or '')[:10]}):** {clean(txt, 500)}")
            elif nxt != "A":                    # only the final assistant text of each turn
                block.append(f"**Claude:** {clean(txt, 1800 if nxt is None else 500)}")
        block.append("")
        text = "\n".join(block)
        if total + len(text) > MAX_TOTAL:
            out.append(f"_… {len(sessions) - sessions.index(s)} older session(s) left out to keep this file small._")
            break
        out.append(text)
        total += len(text)
    if not sessions:
        out.append("_No sessions found in this period._")

    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    tmp = a.out + ".tmp"
    with open(tmp, "w") as fh:
        fh.write("\n".join(out) + "\n")
    os.replace(tmp, a.out)
    print(f"{len(sessions)} session(s) → {a.out}")


if __name__ == "__main__":
    sys.exit(main())
