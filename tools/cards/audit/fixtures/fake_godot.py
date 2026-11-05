#!/usr/bin/env python3
"""Stand-in for validate_main.gd --mode=ship.

Scans the staging directory passed after --path. Prints DATA ERROR lines and
exits 1 when ship text is missing. Otherwise the last line is
CARDS TEST PASS audit_ship.

This is not the real validator. It only reproduces the V27 / V37 lines the
audit report has to keep, so the bad-pack fixtures can prove item 2:
  - a guide_step with no human say
  - a closing-list card with a non-empty on_expire and no outcomes.ignored
  - an event / fate / street / big_fate (not bf.wheel) that must be resolved
    and has neither a top-level check nor an effects.on_expire key (V37)
  - a stage beat whose ref has no human text
"""
import json
import os
import re
import sys

EXPIRE_TYPES = {"person", "event", "fate", "big_fate", "street", "life"}
V37_TYPES = {"event", "fate", "street", "big_fate"}
AI_PROV = re.compile(r"^ai:[^:\s]+:[^:\s]+:\d{4}-\d{2}-\d{2}:\S+$")


def _merge_missing_fields(dst, src):
    for key, val in src.items():
        if str(key).startswith("_"):
            continue
        if key not in dst:
            dst[key] = val
        elif isinstance(dst[key], dict) and isinstance(val, dict):
            _merge_missing_fields(dst[key], val)
        elif isinstance(val, str) and (not isinstance(dst[key], str) or dst[key].strip() == ""):
            dst[key] = val


def load_texts(stage, variant="ai-disclosure", problems=None):
    index = {}
    root = os.path.join(stage, "data", "cards", "text")
    if os.path.isdir(root):
        for dirpath, dirs, files in os.walk(root):
            dirs.sort()
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                try:
                    data = json.load(open(os.path.join(dirpath, name), encoding="utf-8"))
                except (OSError, ValueError):
                    continue
                if not isinstance(data, dict):
                    continue
                for key, entry in data.items():
                    if str(key).startswith("_") or key in index:
                        continue
                    index[str(key)] = entry.copy() if isinstance(entry, dict) else {}
    if variant != "ai-disclosure":
        return index
    ai_root = os.path.join(stage, "data", "cards", "text_ai")
    if os.path.isdir(ai_root):
        for dirpath, dirs, files in os.walk(ai_root):
            dirs.sort()
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                full_path = os.path.join(dirpath, name)
                shown = os.path.relpath(full_path, stage)
                try:
                    data = json.load(open(full_path, encoding="utf-8"))
                except (OSError, ValueError):
                    continue
                if not isinstance(data, dict):
                    continue
                meta = data.get("_meta") if isinstance(data.get("_meta"), dict) else {}
                file_prov = str(meta.get("_provenance") or "").strip()
                if not AI_PROV.match(file_prov):
                    if problems is not None:
                        problems.append(
                            "DATA ERROR: %s: _meta: V26 missing or invalid file-level AI _provenance (expected ai:<tool>:<model>:YYYY-MM-DD:<prompt_id>)"
                            % shown
                        )
                    continue
                for key, entry in data.items():
                    if str(key).startswith("_") or not isinstance(entry, dict):
                        continue
                    if "_provenance" in entry and str(entry.get("_provenance") or "").strip() != file_prov:
                        if problems is not None:
                            problems.append(
                                "DATA ERROR: %s: %s: V26 entry _provenance conflicts with file _meta._provenance"
                                % (shown, key)
                            )
                        continue
                    cur = index.setdefault(str(key), {})
                    _merge_missing_fields(cur, entry)
    return index


def field_text(entry, field):
    cur = entry if isinstance(entry, dict) else {}
    for part in str(field).split("."):
        if not isinstance(cur, dict) or part not in cur:
            return ""
        cur = cur[part]
    if not isinstance(cur, str):
        return ""
    return cur.strip()


def beat_refs(stage_block):
    refs = []
    if not isinstance(stage_block, dict):
        return refs

    def take(beats):
        if not isinstance(beats, list):
            return
        for beat in beats:
            if not isinstance(beat, dict):
                continue
            ref = beat.get("ref")
            if isinstance(ref, str) and ref and ref not in refs:
                refs.append(ref)

    take(stage_block.get("intro"))
    after = stage_block.get("after")
    if isinstance(after, dict):
        for key in after:
            take(after.get(key))
    return refs


def must_resolve(card, kind):
    if "must_resolve" in card:
        return bool(card.get("must_resolve"))
    return kind in ("person", "event", "fate", "big_fate", "street", "prison")


def main(argv):
    stage = ""
    if "--path" in argv:
        stage = argv[argv.index("--path") + 1]
    variant = "ai-disclosure"
    for arg in argv:
        if arg.startswith("--variant="):
            raw = arg.split("=", 1)[1].strip().lower().replace("_", "-")
            if raw in ("no-ai", "no-disclosure", "human-only", "human"):
                variant = "no-disclosure"
        elif arg in ("--no-ai", "--no-disclosure", "--human-only"):
            variant = "no-disclosure"
    problems = []
    texts = load_texts(stage, variant=variant, problems=problems)
    root = os.path.join(stage, "data", "cards")
    if os.path.isdir(root):
        for dirpath, dirs, files in os.walk(root):
            dirs.sort()
            for name in sorted(files):
                if not name.endswith(".json"):
                    continue
                path = os.path.join(dirpath, name)
                rel = path.replace("\\", "/")
                if "/text/" in rel or "/text_ai/" in rel:
                    continue
                try:
                    data = json.load(open(path, encoding="utf-8"))
                except (OSError, ValueError):
                    continue
                if not isinstance(data, dict):
                    continue
                shown = os.path.relpath(path, stage)
                for card in data.get("cards") or []:
                    if not isinstance(card, dict):
                        continue
                    kind = str(card.get("type") or "")
                    cid = str(card.get("id") or "")
                    entry = texts.get(cid, {})
                    if kind == "guide_step" and field_text(entry, "say") == "":
                        problems.append(
                            "DATA ERROR: %s: %s: V27 ship build needs human text field 'say'"
                            % (shown, cid))
                    effects = card.get("effects") if isinstance(card.get("effects"), dict) else {}
                    if kind in EXPIRE_TYPES:
                        expire = effects.get("on_expire") if isinstance(effects, dict) else None
                        if isinstance(expire, list) and expire and field_text(entry, "outcomes.ignored") == "":
                            problems.append(
                                "DATA ERROR: %s: %s: V27 ship build needs human text field 'outcomes.ignored'"
                                % (shown, cid))
                    if kind in V37_TYPES and cid != "bf.wheel" and must_resolve(card, kind):
                        has_check = isinstance(card.get("check"), dict)
                        if not has_check and "on_expire" not in effects:
                            problems.append(
                                "DATA ERROR: %s: %s: V37 ignore consequence was never written "
                                "(need a check or effects.on_expire)"
                                % (shown, cid))
                    for ref in beat_refs(card.get("stage")):
                        if field_text(entry, ref) == "":
                            problems.append(
                                "DATA ERROR: %s: %s: V27 ship build needs human text field '%s'"
                                % (shown, cid, ref))
    if problems:
        for line in problems:
            print(line)
        print("CARDS VALID 0 cards, %d errors" % len(problems))
        return 1
    print("CARDS TEST PASS audit_ship")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
