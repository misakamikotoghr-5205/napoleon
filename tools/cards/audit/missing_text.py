#!/usr/bin/env python3
"""List human text that the ship build still needs (for authors A and B).

usage: missing_text.py [--src=<repo root>] [--out=<prefix>]

Writes <prefix>.md and <prefix>.json. Default prefix is docs/cards/audit/missing_text
under the source repo. The list is one row per id: which fields are missing, plus
mechanism notes (type, choice ids, slot ids, who, which mechanic, intro_paras).
Brief text is never copied.

Launch eras come from data/cards/rules/stages.json. Cards whose era misses those
eras (and is not "*") are skipped. Example data under data/cards/_examples is not
part of the ship list.

Also listed, still without brief text: outcomes.ignored on cards that enter the
end-of-day list with a non-empty effects.on_expire (person, event, fate,
big_fate, street, life); each stage beat's ref (who, and intro or after.<key>);
the narration keys w0.stage.enter / at_door / leave, owned by A, not the W0
stubs; g0x.end.* interface keys the same way as any other ui key; ex_* names
from data/cards/common/extras.json when that file exists.

Standard library only. Output is deterministic (no timestamps).
"""
import json
import os
import re
import sys

SCRIPT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
HUMAN_A = re.compile(r"^human:A:\d{4}-\d{2}-\d{2}$")
HUMAN_B = re.compile(r"^human:B:\d{4}-\d{2}-\d{2}$")
CARD_DIRS = ("era", "demand", "news", "dossier", "common", "fortune", "guide")
HELP_RE = re.compile(r"c10\.help\.[A-Za-z0-9_.]+")
BEAT_REF_RE = re.compile(r"^(body|lines\.[a-z0-9_]+|outcomes\.[a-z0-9_]+|choices\.[a-z0-9_]+)$")
# Cards that show up on the end-of-day list and need a human "what if ignored" line.
EXPIRE_TYPES = {"person", "event", "fate", "big_fate", "street", "life"}
# Formal narration CardStageScript always uses. Owned by A, not disposable stubs.
STAGE_NARRATION = ("w0.stage.enter", "w0.stage.at_door", "w0.stage.leave")
BASE_FIELDS = {
    "person": ["title", "body", "lines.greet"],
    "self": ["title", "body"],
    "contact": ["title", "body"],
    "event": ["title", "body"],
    "fate": ["title", "body"],
    "big_fate": ["title", "body"],
    "life": ["title", "body"],
    "street": ["title", "body"],
    "prison": ["title", "body"],
    "demand": ["title", "body", "outcomes.success", "outcomes.fail", "lines.issue"],
    "news": ["title", "body"],
    "kept": ["title", "body", "use"],
    "estate": ["title", "body", "mortgaged"],
    "night": ["title", "body"],
    "wheel": ["title"],
    "wheel_segment": ["title", "body"],
    "fortune_lot": ["verse", "gloss"],
    "cezi": ["char", "has", "none"],
    "dossier_page": ["title"],
    "dossier_fragment": ["body"],
    "goal": ["title", "done", "failed"],
    "pawn_ticket": ["body"],
    "guide_step": ["say", "bubble"],
    "rule_page": ["title", "body"],
}
CHOICE_TYPES = {"person", "event", "fate", "big_fate", "life", "street", "prison"}
SLOT_TYPES = {"event", "fate", "big_fate", "life", "street", "prison", "demand"}
CHECK_TYPES = {"event", "fate", "big_fate", "life", "street", "prison"}
A_TYPES = {
    "person", "self", "contact", "event", "fate", "big_fate", "life", "street", "prison",
    "demand", "news", "kept", "estate", "night", "wheel", "wheel_segment", "fortune_lot",
    "cezi", "dossier_page", "dossier_fragment", "goal", "pawn_ticket", "guide_step",
    "rule_page", "stage", "obs", "person_name", "item", "codebook",
}


def parse_options(argv):
    opts = {}
    for a in argv:
        if a.startswith("--") and "=" in a:
            k, v = a[2:].split("=", 1)
            opts[k] = v
        elif not a.startswith("--"):
            print(__doc__)
            return None
    return opts


def load_json(path):
    try:
        return json.load(open(path, encoding="utf-8"))
    except (OSError, UnicodeError, ValueError):
        return None


def rel_of(src, path):
    return os.path.relpath(path, src).replace(os.sep, "/")


def walk_json(folder):
    found = []
    if not os.path.isdir(folder):
        return found
    for dirpath, dirnames, files in os.walk(folder):
        dirnames.sort()
        for name in sorted(files):
            if name.endswith(".json"):
                found.append(os.path.join(dirpath, name))
    return found


def unique(seq):
    out = []
    for item in seq:
        if item not in out:
            out.append(item)
    return out


def choice_ids(card):
    ids = []
    for row in card.get("choices") or []:
        if isinstance(row, dict) and row.get("id"):
            ids.append(str(row["id"]))
    return unique(ids)


def slot_ids(card):
    ids = []
    for row in card.get("slots") or []:
        if isinstance(row, dict) and row.get("id"):
            ids.append(str(row["id"]))
    for row in card.get("choices") or []:
        if not isinstance(row, dict):
            continue
        check = row.get("check") if isinstance(row.get("check"), dict) else {}
        for slot in check.get("slots") or []:
            if isinstance(slot, dict) and slot.get("id"):
                ids.append(str(slot["id"]))
    return unique(ids)


def has_check(card):
    if isinstance(card.get("check"), dict):
        return True
    for row in card.get("choices") or []:
        if isinstance(row, dict) and isinstance(row.get("check"), dict):
            return True
    return False


def expire_nonempty(card):
    effects = card.get("effects")
    if not isinstance(effects, dict) or "on_expire" not in effects:
        return False
    expire = effects.get("on_expire")
    return isinstance(expire, list) and len(expire) > 0


def who_label(who):
    if who is None:
        who = ""
    who = str(who)
    if who == "":
        return "旁白"
    if who == "me":
        return "沈如花"
    return who


def take_beats(beats, place, found):
    if not isinstance(beats, list):
        return
    for beat in beats:
        if not isinstance(beat, dict):
            continue
        ref = beat.get("ref")
        if not isinstance(ref, str) or BEAT_REF_RE.match(ref) is None:
            continue
        found.append({
            "ref": ref,
            "who": who_label(beat.get("who", "")),
            "place": place,
        })


def stage_beats(card):
    stage = card.get("stage")
    if not isinstance(stage, dict):
        return []
    found = []
    take_beats(stage.get("intro"), "intro", found)
    after = stage.get("after")
    if isinstance(after, dict):
        for key in after:
            take_beats(after.get(key), "after.%s" % key, found)
    return found


def fields_for(card):
    kind = str(card.get("type") or "")
    if kind not in BASE_FIELDS:
        return ["title", "body"] if kind else []
    fields = list(BASE_FIELDS[kind])
    if kind == "person" and card.get("intent") in ("pawn", "sell", "buy"):
        fields.extend(["lines.accept", "lines.leave", "lines.refused"])
    if kind in CHOICE_TYPES:
        fields.extend("choices.%s" % cid for cid in choice_ids(card))
    if kind in SLOT_TYPES:
        fields.extend("slots.%s" % sid for sid in slot_ids(card))
    if kind in CHECK_TYPES and has_check(card):
        fields.extend(["outcomes.success", "outcomes.fail"])
    if kind in EXPIRE_TYPES and expire_nonempty(card):
        fields.append("outcomes.ignored")
    return unique(fields)


def launches(card, eras):
    era = card.get("era")
    if not isinstance(era, list) or not era:
        return True
    if "*" in era:
        return True
    return any(str(item) in eras for item in era)


def card_files(src):
    root = os.path.join(src, "data", "cards")
    found = []
    for folder in CARD_DIRS:
        base = os.path.join(root, folder)
        for path in walk_json(base):
            if os.path.basename(path) == "stage.json":
                continue
            if "/_examples/" in path.replace(os.sep, "/"):
                continue
            found.append(path)
    extra = os.path.join(root, "minigames", "items.json")
    if os.path.isfile(extra):
        found.append(extra)
    found.sort()
    return found


def text_index(src):
    index = {}
    root = os.path.join(src, "data", "cards", "text")
    for path in walk_json(root):
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        for key, entry in data.items():
            if not str(key).startswith("_") and key not in index:
                index[str(key)] = entry if isinstance(entry, dict) else {}
    return index


def dig(entry, field):
    cur = entry
    for part in str(field).split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def filled(entry, field):
    value = dig(entry, field)
    return isinstance(value, str) and value != ""


def owner_re(owner):
    return HUMAN_A if owner == "A" else HUMAN_B


def needed(entry, fields, owner):
    entry = entry if isinstance(entry, dict) else {}
    prov_ok = owner_re(owner).match(str(entry.get("_provenance", ""))) is not None
    missing = [field for field in fields if not filled(entry, field)]
    if prov_ok and not missing:
        return None
    if not missing:
        missing = list(fields)
    return missing


def notes_for_card(card):
    teaches = card.get("teaches") if isinstance(card.get("teaches"), list) else []
    return {
        "type": str(card.get("type") or ""),
        "choice_ids": choice_ids(card),
        "slot_ids": slot_ids(card),
        "person": str(card.get("person") or ""),
        "teacher": str(card.get("teacher") or ""),
        "teaches": [str(t) for t in teaches],
        "intent": str(card.get("intent") or ""),
        "intro_paras": None,
    }


def add_entry(rows, row):
    rows.append(row)


def add_ui_row(rows, texts, key, source_file, text_file, task):
    """One interface key. w0.stage.* is A's narration; g0x.end.* stays a normal B key."""
    narration = key in STAGE_NARRATION
    owner = "A" if narration else "B"
    if narration:
        text_file = "data/cards/text/ui/W0.text.json"
    missing = needed(texts.get(key), ["t"], owner)
    if missing is None:
        return
    notes = {
        "type": "ui_key",
        "choice_ids": [],
        "slot_ids": [],
        "person": "",
        "teacher": "",
        "teaches": [],
        "intent": "",
        "intro_paras": None,
        "task": task,
    }
    if narration:
        notes["params"] = ["name"]
    add_entry(rows, {
        "id": key,
        "type": "ui_key",
        "owner": owner,
        "file": source_file,
        "text_file": text_file,
        "fields": missing,
        "w0_stub": key.startswith("w0.") and not narration,
        "notes": notes,
    })


def string_fields(obj, skip):
    fields = []
    if not isinstance(obj, dict):
        return fields
    for key, value in obj.items():
        if key in skip or not isinstance(value, str):
            continue
        fields.append(str(key))
    return fields


def load_template_map(src):
    mapped = {}

    def absorb(path):
        data = load_json(path)
        if not isinstance(data, dict):
            return
        rel = rel_of(src, path)
        for cat, obj in (data.get("categories") or {}).items():
            if not isinstance(obj, dict):
                continue
            for var in obj.get("variants") or []:
                if not isinstance(var, dict) or not var.get("id"):
                    continue
                key = "%s.%s" % (cat, var["id"])
                fields = ["name"]
                for extra in string_fields(var, {"id", "sprite", "name"}):
                    if extra not in fields:
                        fields.append(extra)
                mapped[key] = {"fields": fields, "file": rel}

    town = os.path.join(src, "data", "town", "item_templates.json")
    extra = os.path.join(src, "data", "cards", "items", "templates_extra.json")
    if os.path.isfile(town):
        absorb(town)
    if os.path.isfile(extra):
        absorb(extra)
    return mapped


def launch_items(src):
    mapped = load_template_map(src)
    launch = os.path.join(src, "data", "cards", "items", "launch_items.json")
    data = load_json(launch) if os.path.isfile(launch) else None
    if isinstance(data, dict) and isinstance(data.get("categories"), dict):
        # A full template document named as the launch list replaces the fallback.
        only = {}
        rel = rel_of(src, launch)
        for cat, obj in data["categories"].items():
            if not isinstance(obj, dict):
                continue
            for var in obj.get("variants") or []:
                if isinstance(var, dict) and var.get("id"):
                    key = "%s.%s" % (cat, var["id"])
                    if key in mapped:
                        only[key] = mapped[key]
                    else:
                        only[key] = {"fields": ["name"], "file": rel}
        return only
    if isinstance(data, dict):
        raw = data.get("items") or data.get("templates") or data.get("ids")
        if isinstance(raw, list) and raw:
            only = {}
            for item in raw:
                if isinstance(item, str):
                    key = item
                elif isinstance(item, dict):
                    # K11 rows name the template as "<cat>.<variant>" (contract §4.7.15).
                    key = str(item.get("template") or item.get("id") or "")
                    if item.get("cat") and item.get("variant"):
                        key = "%s.%s" % (item["cat"], item["variant"])
                else:
                    continue
                if key in mapped:
                    only[key] = mapped[key]
                elif key:
                    only[key] = {"fields": ["name"], "file": rel_of(src, launch)}
            return only
    return mapped


def help_keys_from_code(src):
    found = []
    root = os.path.join(src, "scripts", "cards")
    if not os.path.isdir(root):
        return found
    for dirpath, dirnames, files in os.walk(root):
        dirnames.sort()
        for name in sorted(files):
            if not name.endswith(".gd"):
                continue
            try:
                text = open(os.path.join(dirpath, name), encoding="utf-8").read()
            except (OSError, UnicodeError):
                continue
            for match in HELP_RE.findall(text):
                if match not in found:
                    found.append(match)
    found.sort()
    return found


def collect(src):
    stages = load_json(os.path.join(src, "data", "cards", "rules", "stages.json")) or {}
    eras = []
    for row in stages.get("stages") or []:
        if isinstance(row, dict) and row.get("era") and str(row["era"]) not in eras:
            eras.append(str(row["era"]))
    texts = text_index(src)
    rows = []

    for path in card_files(src):
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        rel = rel_of(src, path)
        for card in data.get("cards") or []:
            if not isinstance(card, dict) or not card.get("id"):
                continue
            if not launches(card, eras):
                continue
            kind = str(card.get("type") or "")
            fields = fields_for(card)
            beats = stage_beats(card)
            for beat in beats:
                if beat["ref"] not in fields:
                    fields.append(beat["ref"])
            if not fields:
                continue
            owner = "A"
            missing = needed(texts.get(str(card["id"])), fields, owner)
            if missing is None:
                continue
            text_file = "data/cards/text/" + rel[len("data/cards/"):]
            if text_file.endswith(".json"):
                text_file = text_file[:-5] + ".text.json"
            notes = notes_for_card(card)
            if beats:
                notes["beats"] = beats
            add_entry(rows, {
                "id": str(card["id"]),
                "type": kind or "card",
                "owner": owner,
                "file": rel,
                "text_file": text_file,
                "fields": missing,
                "w0_stub": False,
                "notes": notes,
            })

    # UI keys. w0.* stubs are called out; w0.stage.* is A's formal narration instead.
    # g0x.end.* (g01.end.discard, g02.end.leave, …) are listed like any other ui key.
    seen_ui = set()
    ui_dir = os.path.join(src, "data", "cards", "ui_keys")
    if os.path.isdir(ui_dir):
        for name in sorted(os.listdir(ui_dir)):
            if not name.endswith(".json"):
                continue
            path = os.path.join(ui_dir, name)
            data = load_json(path)
            if not isinstance(data, dict):
                continue
            stem = os.path.splitext(name)[0]
            text_file = "data/cards/text/ui/%s.text.json" % stem
            rel = rel_of(src, path)
            for key in (data.get("keys") or {}):
                key = str(key)
                if key in seen_ui:
                    continue
                seen_ui.add(key)
                add_ui_row(rows, texts, key, rel, text_file, stem)
    for key in STAGE_NARRATION:
        if key in seen_ui:
            continue
        seen_ui.add(key)
        add_ui_row(rows, texts, key, "data/cards/ui_keys/W0.json",
                   "data/cards/text/ui/W0.text.json", "W0")

    for key in help_keys_from_code(src):
        if key in seen_ui:
            continue
        seen_ui.add(key)
        missing = needed(texts.get(key), ["t"], "B")
        if missing is None:
            continue
        add_entry(rows, {
            "id": key,
            "type": "ui_key",
            "owner": "B",
            "file": "scripts/cards (c10.help reference)",
            "text_file": "data/cards/text/ui/C10.text.json",
            "fields": missing,
            "w0_stub": False,
            "notes": {
                "type": "ui_key",
                "choice_ids": [],
                "slot_ids": [],
                "person": "",
                "teacher": "",
                "teaches": ["help"],
                "intent": "",
                "intro_paras": None,
                "task": "C10",
            },
        })

    if "c16.settings.guide_hints" not in seen_ui:
        missing = needed(texts.get("c16.settings.guide_hints"), ["t"], "B")
        if missing is not None:
            add_entry(rows, {
                "id": "c16.settings.guide_hints",
                "type": "ui_key",
                "owner": "B",
                "file": "data/cards/ui_keys/C16.json",
                "text_file": "data/cards/text/ui/C16.text.json",
                "fields": missing,
                "w0_stub": False,
                "notes": {
                    "type": "ui_key",
                    "choice_ids": [],
                    "slot_ids": [],
                    "person": "",
                    "teacher": "",
                    "teaches": ["guide_hints"],
                    "intent": "",
                    "intro_paras": None,
                    "task": "C16",
                },
            })

    obs_dir = os.path.join(src, "data", "cards", "minigames", "obs")
    for path in walk_json(obs_dir):
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        kind = str((data.get("_meta") or {}).get("kind") or os.path.splitext(os.path.basename(path))[0])
        for key in data.get("obs") or {}:
            key = str(key)
            missing = needed(texts.get(key), ["t"], "A")
            if missing is None:
                continue
            add_entry(rows, {
                "id": key,
                "type": "obs",
                "owner": "A",
                "file": rel_of(src, path),
                "text_file": "data/cards/text/minigames/obs/%s.text.json" % kind,
                "fields": missing,
                "w0_stub": False,
                "notes": {
                    "type": "obs",
                    "choice_ids": [],
                    "slot_ids": [],
                    "person": "",
                    "teacher": "",
                    "teaches": [kind],
                    "intent": "",
                    "intro_paras": None,
                },
            })

    # Person names: cast.json plus every persons block the ship list reads,
    # including data/cards/common/extras.json (ex_*, even when dossier is false).
    # That file is K09's; if it is not in the tree yet, there is nothing to add.
    persons = []
    cast = load_json(os.path.join(src, "data", "cast.json")) or {}
    for pid in (cast.get("npcs") or {}):
        persons.append((str(pid), "data/cast.json"))
    for path in card_files(src):
        data = load_json(path)
        if not isinstance(data, dict):
            continue
        for pid in data.get("persons") or {}:
            persons.append((str(pid), rel_of(src, path)))
    seen_person = set()
    for pid, origin in persons:
        if pid in seen_person:
            continue
        seen_person.add(pid)
        missing = needed(texts.get(pid), ["name"], "A")
        if missing is None:
            continue
        add_entry(rows, {
            "id": pid,
            "type": "person_name",
            "owner": "A",
            "file": origin,
            "text_file": "data/cards/text/persons.text.json",
            "fields": missing,
            "w0_stub": False,
            "notes": {
                "type": "person_name",
                "choice_ids": [],
                "slot_ids": [],
                "person": pid,
                "teacher": "",
                "teaches": [],
                "intent": "",
                "intro_paras": None,
            },
        })

    items = launch_items(src)
    for key in sorted(items):
        info = items[key]
        text_key = "item." + key
        missing = needed(texts.get(text_key), info["fields"], "A")
        if missing is None:
            continue
        add_entry(rows, {
            "id": text_key,
            "type": "item",
            "owner": "A",
            "file": info["file"],
            "text_file": "data/cards/text/items.text.json",
            "fields": missing,
            "w0_stub": False,
            "notes": {
                "type": "item",
                "choice_ids": [],
                "slot_ids": [],
                "person": "",
                "teacher": "",
                "teaches": [],
                "intent": "",
                "intro_paras": None,
            },
        })

    for era in eras:
        stage_path = os.path.join(src, "data", "cards", "era", era, "stage.json")
        data = load_json(stage_path) if os.path.isfile(stage_path) else None
        count = None
        if isinstance(data, dict) and isinstance(data.get("intro_paras"), int):
            count = data["intro_paras"]
        fields = ["intro.p%d" % (i + 1) for i in range(count)] if count else ["intro.p1"]
        text_key = "stage.%s" % era
        missing = needed(texts.get(text_key), fields, "A")
        if missing is None:
            continue
        add_entry(rows, {
            "id": text_key,
            "type": "stage",
            "owner": "A",
            "file": rel_of(src, stage_path) if os.path.isfile(stage_path) else "data/cards/era/%s/stage.json" % era,
            "text_file": "data/cards/text/era/%s/stage.text.json" % era,
            "fields": missing,
            "w0_stub": False,
            "notes": {
                "type": "stage",
                "choice_ids": [],
                "slot_ids": [],
                "person": "",
                "teacher": "",
                "teaches": [],
                "intent": "",
                "intro_paras": count,
            },
        })

    code_path = os.path.join(src, "data", "cards", "minigames", "codebook.json")
    code = load_json(code_path) if os.path.isfile(code_path) else None
    if isinstance(code, dict):
        for _num, obj in (code.get("codes") or {}).items():
            if not isinstance(obj, dict) or not obj.get("key"):
                continue
            key = str(obj["key"])
            missing = needed(texts.get(key), ["word"], "A")
            if missing is None:
                continue
            add_entry(rows, {
                "id": key,
                "type": "codebook",
                "owner": "A",
                "file": rel_of(src, code_path),
                "text_file": "data/cards/text/codebook.text.json",
                "fields": missing,
                "w0_stub": False,
                "notes": {
                    "type": "codebook",
                    "choice_ids": [],
                    "slot_ids": [],
                    "person": "",
                    "teacher": "",
                    "teaches": ["decode"],
                    "intent": "",
                    "intro_paras": None,
                },
            })

    rows.sort(key=lambda row: (row["owner"], row["w0_stub"], row["type"], row["id"], row["file"]))
    return eras, rows


def counts_of(rows):
    by_type = {}
    owners = {"A": 0, "B": 0}
    for row in rows:
        owners[row["owner"]] = owners.get(row["owner"], 0) + 1
        by_type[row["type"]] = by_type.get(row["type"], 0) + 1
    return {
        "entries": len(rows),
        "A": owners.get("A", 0),
        "B": owners.get("B", 0),
        "by_type": by_type,
    }


def render_md(eras, rows):
    counts = counts_of(rows)
    lines = [
        "# 待写正文",
        "",
        "发行年代：%s。" % ("、".join(eras) if eras else "（stages.json 里没有年代）"),
        "还缺 %d 条。A（剧情、牌面、签、观察、人物、物品、指引、规矩、电码本）%d 条；B（界面、帮助、设置）%d 条。"
        % (counts["entries"], counts["A"], counts["B"]),
        "按类型：" + "、".join("%s %d" % (k, counts["by_type"][k]) for k in sorted(counts["by_type"])) + "。",
        "这份清单不带设计说明原文，只写要补哪些字段和机制要点。例子集不进发行包，不列在这里。",
        "",
    ]

    def emit(title, subset):
        lines.append("## %s" % title)
        lines.append("")
        if not subset:
            lines.append("（没有）")
            lines.append("")
            return
        by_type = {}
        for row in subset:
            by_type.setdefault(row["type"], []).append(row)
        for kind in sorted(by_type):
            lines.append("### %s（%d）" % (kind, len(by_type[kind])))
            lines.append("")
            for row in by_type[kind]:
                note = row["notes"]
                bits = ["要写：" + "、".join(row["fields"])]
                if note.get("teaches"):
                    bits.append("教 " + "、".join(note["teaches"]))
                if note.get("teacher"):
                    bits.append("谁 " + note["teacher"])
                if note.get("person"):
                    bits.append("人物 " + note["person"])
                if note.get("intent"):
                    bits.append("来意 " + note["intent"])
                if note.get("choice_ids"):
                    bits.append("选项 " + "、".join(note["choice_ids"]))
                if note.get("slot_ids"):
                    bits.append("格子 " + "、".join(note["slot_ids"]))
                if note.get("intro_paras") is not None:
                    bits.append("开场 %d 段" % note["intro_paras"])
                if note.get("beats"):
                    shown = []
                    for beat in note["beats"]:
                        shown.append("%s·%s·%s" % (beat["place"], beat["who"], beat["ref"]))
                    bits.append("拍子 " + "；".join(shown))
                if note.get("params"):
                    bits.append("参数 " + "、".join("{%s}" % name for name in note["params"]))
                lines.append("- `%s` · `%s` · %s" % (row["id"], row["file"], " · ".join(bits)))
            lines.append("")

    emit("A · 剧情、牌面、签、观察、人物、物品、指引与规矩、电码本",
         [r for r in rows if r["owner"] == "A"])
    emit("B · 界面文字、F1 帮助、设置",
         [r for r in rows if r["owner"] == "B" and not r["w0_stub"]])
    emit("W0 桩用的键，正式界面换掉后可删",
         [r for r in rows if r["w0_stub"]])
    return "\n".join(lines).rstrip() + "\n"


def main(argv):
    opts = parse_options(argv)
    if opts is None:
        return 2
    src = os.path.abspath(opts.get("src", SCRIPT_ROOT))
    if not os.path.isdir(src):
        print("missing_text: source is not a directory: %s" % src)
        return 2
    out = opts.get("out", os.path.join(src, "docs", "cards", "audit", "missing_text"))
    if out.endswith(".md") or out.endswith(".json"):
        out = os.path.splitext(out)[0]
    eras, rows = collect(src)
    payload = {"launch_eras": eras, "counts": counts_of(rows), "entries": rows}
    folder = os.path.dirname(os.path.abspath(out))
    if folder:
        os.makedirs(folder, exist_ok=True)
    open(out + ".json", "w", encoding="utf-8", newline="\n").write(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
    open(out + ".md", "w", encoding="utf-8", newline="\n").write(render_md(eras, rows))
    counts = payload["counts"]
    print("MISSING TEXT %d entries, A=%d B=%d" % (counts["entries"], counts["A"], counts["B"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
