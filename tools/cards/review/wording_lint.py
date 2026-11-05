#!/usr/bin/env python3
# 史实与敏感措辞检查（K13）。只依赖 Python 标准库。同样的输入同样的输出。
#
# K15 发行审核第 6 项的调用方式必须保持不变（合同 §11.4）：
#   python3 tools/cards/review/wording_lint.py <暂存目录>/data/cards/text --scope=text --fail-on=must
# 规则文件按本脚本所在仓库定位（data/cards/rules/wording.json），不从暂存目录读
# ——发行打包会排除 wording.json。
#
# 不给路径时扫 data/cards/**（不含 _examples/）的 brief、演出块里的 brief
# （stage.brief、stage.cast[i].brief、stage.props[i].brief、stage.intro[i].brief、
# stage.after.<键>[i].brief）、data/cards/text/** 的正文、docs/cards/post1949/**。
# 一行一个：
#   LINT MUST <文件>:<牌 id 或键>:<字段> <规则 id> <说明>
# 演出块例：LINT MUST data/cards/era/1938/events.json:ev.1938.police_check:stage.intro[0].brief brief_no_dialogue …
# 按文件、牌 id、字段路径排序。最后一行：LINT DONE <n> must, <n> should, <n> hint
# 给了 --fail-on 且有该级别或更严重的问题，退出码 1。
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import namedtuple

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DEFAULT_RULES = os.path.join(ROOT, "data", "cards", "rules", "wording.json")

Finding = namedtuple("Finding", "level path card_id field rule_id message")

LEVELS = ("hint", "should", "must")
SCOPES = ("brief", "text", "guide_brief", "docs", "all")
GUIDE_TYPES = ("guide_step", "rule_page")
GENERIC_KEYS = {
    "tags", "keys", "cards", "persons", "obs", "rules", "stages",
    "choices", "slots", "lines", "outcomes", "effects",
}
TEXT_KEYS = {
    "title", "body", "label", "name", "desc", "say", "bubble",
    "verse", "gloss", "char", "has", "none", "mortgaged", "use",
    "done", "failed",
}
TEXT_CONTAINERS = {"lines", "outcomes", "choices", "slots"}
SKIP_BEFORE = set(" \t\r\n\"'“”‘’「」『』《》〈〉（）()【】[]「」")
NEGATIONS = ("不描写", "不要写", "不许写", "不写成", "禁止写", "不写", "禁止")
YEAR_RE = re.compile(r"(?<!\d)(19\d{2})(?!\d)")


def load_rules(path=None):
    path = path or DEFAULT_RULES
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict) or not isinstance(data.get("rules"), list):
        raise SystemExit("wording_lint: rules file has no rules array: %s" % path)
    return data


def lint_paths(paths, scope="all", rules=None, skip_examples=False):
    rules = rules if rules is not None else load_rules()
    files = []
    for p in paths:
        files.extend(_files(p, skip_examples))
    found = []
    for path in files:
        found.extend(_lint_file(path, scope, rules))
    return _dedupe(found)


def default_paths():
    roots = [
        (os.path.join(ROOT, "data", "cards"), True),
        (os.path.join(ROOT, "docs", "cards", "post1949"), False),
    ]
    files = []
    for root, skip in roots:
        files.extend(_files(root, skip))
    return files


def format_line(f):
    return "LINT %s %s:%s:%s %s %s" % (
        f.level.upper(), f.path, f.card_id, f.field, f.rule_id, f.message
    )


def summarize(findings):
    n = {lv: 0 for lv in LEVELS}
    for f in findings:
        n[f.level] = n.get(f.level, 0) + 1
    line = "LINT DONE %d must, %d should, %d hint" % (n["must"], n["should"], n["hint"])
    return n, line


def main(argv=None):
    p = argparse.ArgumentParser(prog="wording_lint.py", add_help=True)
    p.add_argument("paths", nargs="*", help="files or directories; default scan if omitted")
    p.add_argument("--scope", default="all", choices=SCOPES)
    p.add_argument("--json", dest="json_out", default="")
    p.add_argument("--fail-on", dest="fail_on", default="", choices=["", "must", "should", "hint"])
    p.add_argument("--rules", default=DEFAULT_RULES)
    args = p.parse_args(argv)
    try:
        rules = load_rules(args.rules)
    except OSError as e:
        print("wording_lint: cannot read rules: %s" % e, file=sys.stderr)
        return 2
    if args.paths:
        files = []
        for raw in args.paths:
            files.extend(_files(raw, False))
    else:
        files = default_paths()
    found = []
    for path in files:
        found.extend(_lint_file(path, args.scope, rules))
    found = _dedupe(found)
    lines = [format_line(f) for f in found]
    _n, done = summarize(found)
    if args.json_out:
        _write_json(args.json_out, found)
    out = "\n".join(lines + [done])
    print(out)
    if args.fail_on:
        thr = LEVELS.index(args.fail_on)
        if any(LEVELS.index(f.level) >= thr for f in found):
            return 1
    return 0


# ---------------- scan ----------------

def _files(root, skip_examples):
    root = os.path.abspath(root)
    if not os.path.exists(root):
        print("wording_lint: skip missing %s" % root, file=sys.stderr)
        return []
    if os.path.isfile(root):
        return [root]
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        kept = []
        for d in dirnames:
            if d.startswith("."):
                continue
            if skip_examples and d == "_examples":
                continue
            kept.append(d)
        dirnames[:] = kept
        for name in sorted(filenames):
            if name.endswith((".json", ".md", ".txt")):
                out.append(os.path.join(dirpath, name))
    return out


def _lint_file(path, scope, rules):
    disp = _display(path)
    norm = path.replace("\\", "/")
    if norm.endswith(".md") or norm.endswith(".txt"):
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except OSError as e:
            print("wording_lint: skip unreadable %s (%s)" % (disp, e), file=sys.stderr)
            return []
        return _apply(rules, text, [], disp, "-", "body", {"docs"}, scope, path, None)
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print("wording_lint: skip unreadable %s (%s)" % (disp, e), file=sys.stderr)
        return []
    if "/text/" in norm:
        return _lint_text(data, path, disp, scope, rules)
    found = []
    _walk_cards(data, None, path, disp, scope, rules, found, None)
    return found


def _lint_text(data, path, disp, scope, rules):
    found = []
    if not isinstance(data, dict):
        return found
    guide_file = _guide_path(path)
    for key, entry in data.items():
        if str(key).startswith("_") or not isinstance(entry, dict):
            continue
        guide = guide_file or str(key).startswith("gd.") or str(key).startswith("rule.")
        years = _parse_eras(entry.get("era")) or _years_in_text(str(key))
        _walk_text(entry, "", str(key), guide, years, path, disp, scope, rules, found)
    return found


def _walk_text(node, prefix, card_id, guide, years, path, disp, scope, rules, found):
    if not isinstance(node, dict):
        return
    for key, val in node.items():
        if str(key).startswith("_"):
            continue
        field = key if not prefix else prefix + "." + key
        container = field.split(".", 1)[0]
        if isinstance(val, str) and (key in TEXT_KEYS or container in TEXT_CONTAINERS or prefix.split(".", 1)[0] in TEXT_CONTAINERS):
            scopes = {"text", "guide_brief"} if guide else {"text"}
            found.extend(_apply(rules, val, years, disp, card_id, field, scopes, scope, path, None))
        elif isinstance(val, dict) and (key in TEXT_CONTAINERS or key in TEXT_KEYS):
            _walk_text(val, field, card_id, guide, years, path, disp, scope, rules, found)
        elif isinstance(val, list) and key in TEXT_CONTAINERS:
            for i, item in enumerate(val):
                if isinstance(item, str):
                    scopes = {"text", "guide_brief"} if guide else {"text"}
                    found.extend(_apply(rules, item, years, disp, card_id, "%s.%d" % (field, i), scopes, scope, path, None))
                elif isinstance(item, dict):
                    _walk_text(item, "%s.%d" % (field, i), card_id, guide, years, path, disp, scope, rules, found)


def _walk_cards(node, card, path, disp, scope, rules, found, parent_key):
    if isinstance(node, list):
        for item in node:
            _walk_cards(item, card, path, disp, scope, rules, found, parent_key)
        return
    if not isinstance(node, dict):
        return
    this = card
    if _is_card(node):
        this = node
        _struct(this, path, disp, scope, rules, found)
    for key, val in node.items():
        if str(key).startswith("_") and key != "_meta":
            continue
        if key == "stage" and isinstance(val, dict):
            host = node if _is_card(node) else this
            if _is_card(node):
                cid = str(node.get("id"))
            else:
                cid = _id_of(this, parent_key, node)
            scopes = _brief_scopes(host if isinstance(host, dict) and _is_card(host) else None, path, cid)
            for field, text in _stage_briefs(val):
                years = _word_years(host if isinstance(host, dict) else None, path, text)
                found.extend(_apply(rules, text, years, disp, cid, field, scopes, scope, path, None))
            continue
        if key == "brief" and isinstance(val, str):
            host = node if _is_card(node) else this
            if _is_card(node):
                cid = str(node.get("id"))
            else:
                cid = _id_of(this, parent_key, node)
            years = _word_years(host if isinstance(host, dict) else node, path, val)
            scopes = _brief_scopes(host if _is_card(host) else None, path, cid)
            found.extend(_apply(rules, val, years, disp, cid, "brief", scopes, scope, path, None))
            continue
        if key == "choices" and isinstance(val, list) and (_is_card(node) or this is not None):
            host = node if _is_card(node) else this
            for i, ch in enumerate(val):
                if not isinstance(ch, dict):
                    continue
                cid = str(host.get("id")) if isinstance(host, dict) and host.get("id") else _id_of(host, parent_key, node)
                if isinstance(ch.get("brief"), str):
                    years = _word_years(host, path, ch["brief"])
                    scopes = _brief_scopes(host, path, cid)
                    found.extend(_apply(
                        rules, ch["brief"], years, disp, cid,
                        "choices.%s.brief" % ch.get("id", i), scopes, scope, path, None,
                    ))
                for ck, cv in ch.items():
                    if ck == "brief" or str(ck).startswith("_"):
                        continue
                    _walk_cards(cv, host, path, disp, scope, rules, found, ck)
            continue
        _walk_cards(val, this, path, disp, scope, rules, found, key)


def _stage_briefs(stage):
    """演出块里要扫的 brief。路径形如 stage.intro[0].brief、stage.after.success[0].brief。"""
    if not isinstance(stage, dict):
        return
    top = stage.get("brief")
    if isinstance(top, str):
        yield "stage.brief", top
    for name in ("cast", "props", "intro"):
        arr = stage.get(name)
        if not isinstance(arr, list):
            continue
        for i, item in enumerate(arr):
            if isinstance(item, dict) and isinstance(item.get("brief"), str):
                yield "stage.%s[%d].brief" % (name, i), item["brief"]
    after = stage.get("after")
    if not isinstance(after, dict):
        return
    for akey in sorted(after.keys(), key=str):
        beats = after[akey]
        if not isinstance(beats, list):
            continue
        for i, item in enumerate(beats):
            if isinstance(item, dict) and isinstance(item.get("brief"), str):
                yield "stage.after.%s[%d].brief" % (akey, i), item["brief"]


def _struct(card, path, disp, scope, rules, found):
    years = _parse_eras(card.get("era"))
    norm = path.replace("\\", "/")
    fifties = any(1950 <= y <= 1959 for y in years) or ("post1949" in norm and not years)
    if not fifties:
        return
    for rule in rules.get("rules", []):
        if rule.get("kind") != "fifties_no_punish":
            continue
        if "brief" not in (rule.get("scope") or []):
            continue
        if scope not in ("all", "brief"):
            continue
        if not _is_bad_random(card, rule):
            continue
        msg = rule.get("_struct_message") or "1950 年代不做随机惩罚牌（weight>0 且是坏的命运或事件）"
        found.append(Finding(
            str(rule.get("level") or "must"), disp, str(card.get("id") or "-"), "weight",
            str(rule.get("id")), msg,
        ))


def _is_bad_random(card, rule):
    typ = str(card.get("type", ""))
    if typ not in set(rule.get("_bad_types") or []):
        return False
    w = _num(card.get("weight", 0))
    if w is None or w <= 0:
        return False
    bad_v = str(rule.get("_bad_valence") or "bad")
    tag = str(rule.get("_bad_tag") or "bad_omen")
    valence = str(card.get("valence", ""))
    tags = card.get("tags") if isinstance(card.get("tags"), list) else []
    if typ in ("fate", "big_fate"):
        return valence == bad_v
    if typ == "event":
        return valence == bad_v or tag in [str(t) for t in tags]
    return False


def _apply(rules, text, years, disp, card_id, field, field_scopes, requested, path, _unused):
    if requested != "all" and requested not in field_scopes:
        return []
    out = []
    for rule in rules.get("rules", []):
        rscopes = set(rule.get("scope") or [])
        if not (rscopes & set(field_scopes)):
            continue
        kind = rule.get("kind")
        level = str(rule.get("level") or "must")
        rid = str(rule.get("id") or "")
        hits = []
        message = ""
        if kind == "require_prefix":
            hits = _prefix_hits(rule, text, years)
            if hits:
                message = (rule.get("_message") or "前面要有“伪”或“汪伪”") + "：" + "、".join(_sorted_hits(hits))
        elif kind == "require_phrase":
            hits = _phrase_hits(rule, text, years)
            if hits:
                message = "要写“%s”，不要只用：%s" % (rule.get("_require") or "", "、".join(_sorted_hits(hits)))
        elif kind == "forbid_terms":
            if rule.get("_only_guide") and "guide_brief" not in field_scopes:
                continue
            ctx_ok = True
            if rule.get("_fifties_only"):
                ctx_ok = _fifties_words(years, text, path)
            if ctx_ok:
                hits = _terms_in(text, rule.get("_terms") or [])
            if hits:
                prefix = rule.get("_message")
                shown = "、".join(_sorted_hits(hits))
                if rule.get("_instead"):
                    message = "要写“%s”，不要写：%s" % (rule.get("_instead"), shown)
                elif prefix:
                    message = "%s：%s" % (prefix, shown)
                else:
                    message = "不要出现：" + shown
        elif kind == "no_dialogue":
            if _dialogue(text, rule):
                hits = ["quote"]
                message = rule.get("_message") or "引号内超过 12 个字或含。！？，像能直接拿去用的对白"
        elif kind == "fifties_no_punish":
            if _fifties_words(years, text, path):
                hits = _terms_in(text, rule.get("_terms") or [])
            if hits:
                message = (rule.get("_message") or "1950 年代不写斗争会和运动场面") + "：" + "、".join(_sorted_hits(hits))
        if hits and message:
            out.append(Finding(level, disp, card_id or "-", field or "-", rid, message))
    return out


def _sorted_hits(hits):
    return sorted(_unique_keep(hits))


def _prefix_hits(rule, text, years):
    prefixes = list(rule.get("_prefixes") or rule.get("_prefix_chars") or ["伪"])
    found = []
    for group in rule.get("_groups") or []:
        lo = group.get("_era_from")
        hi = group.get("_era_to")
        if lo is not None and hi is not None:
            ys = list(years) if years else _years_in_text(text)
            if years:
                ys = sorted(set(years) | set(_years_in_text(text)))
            if not ys or not any(int(lo) <= y <= int(hi) for y in ys):
                continue
        for term in group.get("_terms") or []:
            if _missing_prefix(text, term, prefixes):
                found.append(term)
    # stable, longest-first uniqueness
    return _unique_keep(found)


def _missing_prefix(text, term, prefixes):
    if not term:
        return False
    start = 0
    prefs = sorted(prefixes, key=len, reverse=True)
    while True:
        i = text.find(term, start)
        if i < 0:
            return False
        if not _has_prefix(text, i, prefs):
            return True
        start = i + len(term)


def _has_prefix(text, index, prefixes):
    j = index - 1
    while j >= 0 and text[j] in SKIP_BEFORE:
        j -= 1
    head = text[: j + 1]
    return any(head.endswith(p) for p in prefixes)


def _phrase_hits(rule, text, years):
    want = [int(y) for y in (rule.get("_years") or [])]
    ys = set(years) | set(_years_in_text(text))
    if want and not any(y in ys for y in want):
        return []
    require = rule.get("_require") or ""
    if require and require in text:
        return []
    return _terms_in(text, rule.get("_triggers") or [])


def _terms_in(text, terms):
    occupied = [False] * (len(text) + 1)
    found = []
    for term in sorted((t for t in terms if t), key=len, reverse=True):
        start = 0
        while True:
            i = text.find(term, start)
            if i < 0:
                break
            end = i + len(term)
            if any(occupied[i:end]):
                start = i + 1
                continue
            if _negated(text, i):
                start = end
                continue
            for k in range(i, end):
                occupied[k] = True
            found.append(term)
            start = end
    return _unique_keep(found)


def _negated(text, index):
    window = text[max(0, index - 8): index]
    return any(n in window for n in NEGATIONS)


def _dialogue(text, rule):
    max_chars = int(rule.get("_max_chars") or 12)
    punct = rule.get("_punct") or "。！？"
    pairs = rule.get("_pairs") or ["“”", "‘’", "「」", "『』"]
    for pair in pairs:
        if not isinstance(pair, str) or len(pair) != 2:
            continue
        left, right = pair[0], pair[1]
        start = 0
        while True:
            i = text.find(left, start)
            if i < 0:
                break
            j = text.find(right, i + 1)
            if j < 0:
                break
            inner = text[i + 1: j]
            start = j + 1
            if len(inner) > max_chars or any(ch in inner for ch in punct):
                return True
    return False


def _fifties_words(years, text, path):
    if any(1950 <= y <= 1959 for y in years):
        return True
    if any(1950 <= y <= 1959 for y in _years_in_text(text)):
        return True
    return "post1949" in path.replace("\\", "/")


def _word_years(node, path, text):
    years = []
    explicit_star = False
    if isinstance(node, dict) and "era" in node:
        era = node.get("era")
        explicit_star = era in ("*", ["*"])
        years = _parse_eras(era)
    if not years and not explicit_star:
        years = _path_years(path)
    return sorted(set(years) | set(_years_in_text(text)))


def _brief_scopes(card, path, card_id):
    if _is_guide(card, path, card_id):
        return {"brief", "guide_brief"}
    return {"brief"}


def _is_guide(card, path, card_id):
    if isinstance(card, dict) and str(card.get("type", "")) in GUIDE_TYPES:
        return True
    if _guide_path(path):
        return True
    cid = str(card_id or "")
    return cid.startswith("gd.") or cid.startswith("rule.")


def _guide_path(path):
    p = path.replace("\\", "/")
    return "/guide/" in p or p.endswith("/guide")


def _is_card(node):
    return (
        isinstance(node, dict)
        and isinstance(node.get("id"), str)
        and isinstance(node.get("type"), str)
        and node.get("type") != ""
    )


def _id_of(card, parent_key, node):
    if isinstance(card, dict) and isinstance(card.get("id"), str):
        return card["id"]
    if isinstance(node, dict) and _is_card(node):
        return str(node.get("id"))
    if parent_key == "_meta":
        return "_meta"
    if parent_key and str(parent_key) not in GENERIC_KEYS and not str(parent_key).isdigit() and not str(parent_key).startswith("_"):
        return str(parent_key)
    return "-"


def _parse_eras(era):
    if isinstance(era, str):
        tokens = [era]
    elif isinstance(era, list):
        tokens = [str(x) for x in era]
    else:
        return []
    years = []
    for t in tokens:
        t = t.strip()
        if t == "*":
            continue
        m = re.match(r"(\d{4})", t)
        if m:
            years.append(int(m.group(1)))
    return years


def _years_in_text(text):
    return [int(m) for m in YEAR_RE.findall(text or "")]


def _path_years(path):
    return [int(y) for y in re.findall(r"/(19\d{2})/", path.replace("\\", "/"))]


def _num(v):
    if isinstance(v, bool) or not isinstance(v, (int, float)):
        return None
    return v


def _unique_keep(items):
    out = []
    for it in items:
        if it not in out:
            out.append(it)
    return out


def _dedupe(found):
    found = sorted(found, key=lambda f: (f.path, f.card_id, f.field, f.rule_id, f.message))
    out = []
    seen = set()
    for f in found:
        if f not in seen:
            seen.add(f)
            out.append(f)
    return out


def _display(path):
    path = os.path.abspath(path)
    try:
        rel = os.path.relpath(path, os.getcwd())
    except ValueError:
        rel = path
    if rel.startswith(".."):
        try:
            rel2 = os.path.relpath(path, ROOT)
        except ValueError:
            rel2 = rel
        else:
            if not rel2.startswith(".."):
                rel = rel2
    return rel.replace(os.sep, "/")


def _write_json(path, found):
    n, _line = summarize(found)
    payload = {
        "must": n["must"],
        "should": n["should"],
        "hint": n["hint"],
        "items": [
            {
                "level": f.level,
                "file": f.path,
                "id": f.card_id,
                "field": f.field,
                "rule": f.rule_id,
                "message": f.message,
            }
            for f in found
        ],
    }
    parent = os.path.dirname(os.path.abspath(path))
    if parent and not os.path.isdir(parent):
        os.makedirs(parent)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


if __name__ == "__main__":
    sys.exit(main())
