"""Compile the authored Napoleon battle packs into the runtime template library.

The seven original templates and their scene_map remain unchanged.  This module
can run alone or through merge_drafts.py; running it again gives identical data.
"""
from __future__ import annotations

import copy
import json
from pathlib import Path

LEGACY_IDS = ("arcole", "rivoli", "skirmish_a", "skirmish_b", "skirmish_c", "elite_a", "major_a")
# Actual B1 engine sweeps found that the hero's one-time rally can survive the
# final leak in these draft timings.  Bring existing walking waves forward;
# boss power and the original tactical map remain unchanged.
EARLIER_ROUTES = {
    "toulon_night", "montenotte", "skirmish_terraces", "skirmish_mill_ford",
    "skirmish_hamlet", "charleroi_bridge", "skirmish_brabant_farm",
    "skirmish_sunken_lane", "jamestown_streets", "shipwreck_beach", "skull_reef",
    "signal_hill", "beach_landing", "reef_crossing", "ice_shelf",
}
REINFORCE_OPENERS = {
    "skirmish_terraces", "skirmish_mill_ford", "skirmish_hamlet",
    "skirmish_sunken_lane", "shipwreck_beach", "beach_landing",
}


def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def member_spans(text: str, start: int = 0) -> dict:
    """Locate JSON object values while retaining the hand-formatted legacy text."""
    decoder = json.JSONDecoder()
    at = start + 1
    spans = {}
    while True:
        while text[at].isspace():
            at += 1
        if text[at] == "}":
            return spans
        key, at = decoder.raw_decode(text, at)
        while text[at].isspace() or text[at] == ":":
            at += 1
        value_start = at
        _, at = decoder.raw_decode(text, at)
        spans[key] = (value_start, at)
        while text[at].isspace():
            at += 1
        if text[at] == ",":
            at += 1


def object_text(value: dict, original: str, keep: set) -> str:
    spans = member_spans(original)
    rows = []
    for key, row in value.items():
        if key in keep:
            a, b = spans[key]
            rendered = original[a:b]
        else:
            rendered = json.dumps(row, ensure_ascii=False, indent=2).replace("\n", "\n    ")
        rows.append("    " + json.dumps(key) + ": " + rendered)
    return "{\n" + ",\n".join(rows) + "\n  }"


def normalize(template: dict) -> dict:
    out = copy.deepcopy(template)
    if isinstance(out.get("weather"), str):
        out["weather"] = [out["weather"]]
    if out.get("order", {}).get("type") in ("escape", "extract", "protect"):
        out["order_next"] = out.pop("order")
        out["order"] = out.pop("order_fallback")
        # C18: first-volume orders are ordinary hold/no-leak objectives.  The
        # deferred proposal is retained as data, not exposed as an engine note.
        desc = out["order"].get("desc", "")
        if desc.startswith("（") and "）" in desc:
            out["order"]["desc"] = desc.split("）", 1)[1]

    def levels(value):
        if isinstance(value, dict):
            if "act_min" in value:
                value["lv_min"] = 2 * value.pop("act_min") - 1
            for child in value.values():
                levels(child)
        elif isinstance(value, list):
            for child in value:
                levels(child)

    levels(out)
    return out


def calibrate(key: str, template: dict) -> dict:
    if key not in EARLIER_ROUTES:
        return template
    seen = set()
    for wave in template["waves"]:
        if "route" not in wave:
            continue
        wave["turn"] = max(1, wave["turn"] - 2)
        if key in REINFORCE_OPENERS and wave["route"] not in seen:
            wave["units"].append(copy.deepcopy(wave["units"][0]))
            seen.add(wave["route"])
    if key in {"skirmish_mill_ford", "skirmish_sunken_lane"}:
        template["turn_limit"] = 8
        if template.get("order", {}).get("turn") == 7:
            template["order"]["turn"] = 8
            template["order"]["desc"] = template["order"]["desc"].replace("第 7 回合", "第 8 回合")
    template["_integration"] = "第一卷真引擎校准：路线援军提前两回合，实际时序以 waves 为准；检查主角只部署一次随后只交火的全部格位和朝向。"
    if key in REINFORCE_OPENERS:
        template["_integration"] += "各路线首波增补一名同队士兵，避免一次主角振作就能熬过终场。"
    return template


def build(root: Path) -> dict:
    root = Path(root)
    draft = root / "docs/cards/world/drafts"
    target = root / "data/campaigns/battle_templates.json"
    source_text = target.read_text(encoding="utf-8")
    data = read(target)
    original = {key: copy.deepcopy(data["templates"][key]) for key in LEGACY_IDS}
    packs = [
        read(draft / "conquest/data/campaigns/battle_templates_conquest.json"),
        read(draft / "ocean/ocean_battles.json"),
        read(draft / "cristo/data/campaigns/battle_templates_cristo.json"),
    ]
    additions = {}
    for pack in packs:
        for key, entry in pack["templates"].items():
            if key in original or key in additions:
                raise ValueError(f"Duplicate battle template: {key}")
            additions[key] = calibrate(key, normalize(entry.get("template", entry)))
    from trunk_battles import build_templates
    for key, template in build_templates().items():
        if key in original or key in additions:
            raise ValueError(f"Duplicate trunk battle: {key}")
        additions[key] = normalize(template)
    from volume2_battles import build_templates as build_volume2
    for key, template in build_volume2().items():
        if key in original or key in additions:
            raise ValueError(f"Duplicate second-volume battle: {key}")
        additions[key] = normalize(template)
    data["templates"].update(additions)

    conquest = read(draft / "conquest/data/campaigns/napoleon/companions_conquest.json")
    cristo = read(draft / "cristo/data/campaigns/napoleon/companions_cristo.json")
    bonds = copy.deepcopy(conquest["bond_set_napoleon"])
    for row in cristo["bond_set_napoleon_add"]:
        if row["id"] == "bandits":
            continue
        row = copy.deepcopy(row)
        if row["id"] == "marseille_folk":
            row["tiers"] = [2]
            row["desc"] = row["desc"].split("3：", 1)[0].rstrip()
        bonds.append(row)
    data.setdefault("bond_sets", {})["napoleon"] = bonds
    assert all(data["templates"][key] == value for key, value in original.items())
    # Do not reformat the original seven authored templates, scene_map, or ocean
    # bond set: append only the two generated object portions around those spans.
    spans = member_spans(source_text)
    edits = []
    for field, keep in [("templates", set(LEGACY_IDS)), ("bond_sets", {"ocean"})]:
        a, b = spans[field]
        edits.append((a, b, object_text(data[field], source_text[a:b], keep)))
    for a, b, rendered in sorted(edits, reverse=True):
        source_text = source_text[:a] + rendered + source_text[b:]
    target.write_text(source_text, encoding="utf-8")
    return {"templates_added": len(additions), "templates_total": len(data["templates"]), "napoleon_bonds": len(bonds)}


if __name__ == "__main__":
    print(json.dumps(build(Path(__file__).resolve().parents[2]), ensure_ascii=False))
