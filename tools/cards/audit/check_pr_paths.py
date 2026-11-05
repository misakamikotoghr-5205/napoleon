#!/usr/bin/env python3
"""PR path check (CARDS_INTERFACES.md section 11.5). W0 wrote a working first version; K15 owns and extends it.

usage: check_pr_paths.py <base> <head> --author=<github login> [--task=<ID>] [--branch=<head branch>]

* author not in legal/human_authors.json  -> AI line: touching human-only paths fails
  (data/cards/text/**, art/cards/**, audio/cards/**, data/cards/theme/palette.json, legal/**, fonts/**).
  AI asset paths (art/ai/**, audio/ai/**, data/cards/text_ai/**) are writable by AI lines.
  Story packs (packs/<id>/**, docs/cards/PLUGINS.md) are writable by either, except a pack whose pack.json says
  "source": "human" at base or head: an AI line may not touch any file of that pack (same rule as data/cards/text/**).
* task known (from --task, or from a branch cards/<ID>-<slug>) -> every changed path must belong to that task in
  docs/cards/ownership.json (plus the four default-owned paths and ai_paths); a .uid/.import sidecar belongs to its
  file's owner.
* changes come from `git diff --name-status -M` (added, modified, deleted, and BOTH sides of a rename/copy).
  No branch gets a special case (K13 included).
Standard library only. Exit 1 on any violation.

The repository is the current working directory when it contains docs/cards/ownership.json; otherwise the repo that
contains this script. CI runs from the checkout root, so the old invocation is unchanged.
"""
import json
import os
import re
import subprocess
import sys

SCRIPT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
DEFAULT_AI_PATHS = ("art/ai/**", "audio/ai/**", "data/cards/text_ai/**")


def find_root():
    cwd = os.getcwd()
    if os.path.isfile(os.path.join(cwd, "docs", "cards", "ownership.json")):
        return os.path.abspath(cwd)
    return SCRIPT_ROOT


def glob_re(pat):
    out, i = "^", 0
    depth = 0
    while i < len(pat):
        if pat.startswith("**/", i):
            out += "(.*/)?"
            i += 3
            continue
        if pat.startswith("**", i):
            out += ".*"
            i += 2
            continue
        ch = pat[i]
        if ch == "*":
            out += "[^/]*"
        elif ch == "{":
            out += "("
            depth += 1
        elif ch == "}":
            out += ")"
            depth -= 1
        elif ch == "," and depth > 0:
            out += "|"
        else:
            out += re.escape(ch)
        i += 1
    return re.compile(out + "$")


def matches(path, patterns):
    bare = re.sub(r"\.(uid|import)$", "", path)
    return any(glob_re(p).match(path) or glob_re(p).match(bare) for p in patterns)


def changed_paths(root, base, head):
    """Paths touched between base and head, including both sides of a rename or copy."""
    proc = subprocess.run(
        ["git", "diff", "--name-status", "-M", "%s...%s" % (base, head)],
        cwd=root, capture_output=True, text=True)
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "git diff failed").strip()
        raise RuntimeError(err)
    paths = []
    seen = set()
    for line in proc.stdout.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        status = parts[0]
        picked = []
        if status.startswith("R") or status.startswith("C"):
            if len(parts) >= 3:
                picked = [parts[1], parts[2]]
        elif len(parts) >= 2:
            picked = [parts[1]]
        for p in picked:
            p = p.replace("\\", "/")
            if p not in seen:
                seen.add(p)
                paths.append(p)
    return paths


def load_humans(root):
    humans_path = os.path.join(root, "legal", "human_authors.json")
    humans = set()
    if os.path.exists(humans_path):
        data = json.load(open(humans_path, encoding="utf-8"))
        rows = data.get("humans", data) if isinstance(data, dict) else data
        for row in rows:
            humans.add(row["login"] if isinstance(row, dict) else str(row))
    return humans


def load_ai_paths(own):
    if isinstance(own, dict):
        if isinstance(own.get("ai_paths"), list):
            return list(own["ai_paths"])
        paths = own.get("paths")
        if isinstance(paths, dict) and isinstance(paths.get("ai"), list):
            return list(paths["ai"])
    return list(DEFAULT_AI_PATHS)


def pack_source_at(root, rev, pack_id):
    """The "source" of packs/<id>/pack.json at a revision, or None when it is missing or unreadable."""
    proc = subprocess.run(["git", "show", "%s:packs/%s/pack.json" % (rev, pack_id)],
                          cwd=root, capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    try:
        data = json.loads(proc.stdout)
    except ValueError:
        return None
    return data.get("source") if isinstance(data, dict) else None


def human_pack_paths(root, base, head, paths):
    """Changed paths inside a story pack that is human-written at base or at head."""
    found = []
    human = {}
    for p in paths:
        m = re.match(r"^packs/([^/]+)/", p)
        if not m:
            continue
        pack_id = m.group(1)
        if pack_id not in human:
            human[pack_id] = "human" in (pack_source_at(root, base, pack_id), pack_source_at(root, head, pack_id))
        if human[pack_id]:
            found.append(p)
    return found


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(args) != 2 or "author" not in opts:
        print(__doc__)
        return 2
    base, head = args
    root = find_root()
    own = json.load(open(os.path.join(root, "docs/cards/ownership.json"), encoding="utf-8"))
    humans = load_humans(root)
    ai_paths = load_ai_paths(own)
    try:
        diff = changed_paths(root, base, head)
    except RuntimeError as exc:
        print("PATH ERROR: git diff failed: %s" % exc)
        print("PATHS FAILED: 0 files, 1 problems")
        return 1
    errors = []
    if opts["author"] not in humans:
        for p in diff:
            if matches(p, own["human_only"]) and not matches(p, ai_paths):
                errors.append("PATH ERROR: %s is human-only (author %s is not in legal/human_authors.json)" % (p, opts["author"]))
        for p in human_pack_paths(root, base, head, diff):
            errors.append("PATH ERROR: %s is in a human story pack (pack.json source human; author %s is not in "
                          "legal/human_authors.json)" % (p, opts["author"]))
    task = opts.get("task", "")
    branch = opts.get("branch", os.environ.get("GITHUB_HEAD_REF", ""))
    m = re.match(r"^cards/([GCK]\d\d)-", branch)
    if not task and m:
        task = m.group(1)
    if task:
        allowed = (
            list(own["paths"].get(task, []))
            + [p.replace("{ID}", task) for p in own.get("default_owned", [])]
            + ai_paths
        )
        for p in diff:
            if not matches(p, allowed):
                errors.append("PATH ERROR: %s is outside %s's paths (docs/cards/ownership.json)" % (p, task))
    else:
        print("NOTE: no task id (use --task or a cards/<ID>-<slug> branch); ownership check skipped")
    for e in errors:
        print(e)
    print("PATHS %s: %d files, %d problems" % ("OK" if not errors else "FAILED", len(diff), len(errors)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
