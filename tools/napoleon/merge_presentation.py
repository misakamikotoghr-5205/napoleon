"""Merge authored companion and VN drafts without generating art assets.

WORLD_MAP_DESIGN sections 6.5, 11 and decisions C9/C14/C16/C19/C27/C28.
The existing ocean scene directions remain authoritative. New directions use
existing art as explicit placeholders until the C art requests are fulfilled.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
import json
from pathlib import Path
import re


SEGMENTS = ("trunk", "conquest", "ocean", "cristo")
RENAME = {"gerard_villefort": "gerard"}
SHOP_NODES = {
    "rustam": ("trunk", "orient_alps:salheyeh"),
    "desaix": ("trunk", "orient_alps:milan_1800"),
    "maximilien": ("cristo", "paris_1838:palais_royal_shop"),
}
FALLBACK_ART = {
    "bonaparte": "napoleon", "gerard": "palmerston", "noirtier": "rothschild",
    "mercedes": "marie", "renee": "marie", "haydee": "marie", "valentine": "marie",
    "heloise": "marie", "betsy": "pierre", "louis_dantes": "morel",
    "governor": "hudson_lowe", "commissaire": "crawford", "dugommier": "montholon",
    "saliceti": "rothschild", "carnot": "montholon", "berthier": "gourgaud",
    "talleyrand": "palmerston", "besson": "morel", "coffin": "morel",
    "purser": "howard", "signalman": "howard", "pearl_diver": "friday",
    "laffitte": "david_moses", "mayor": "palmerston", "morrel": "morel",
}
CLASS_ART = {
    "line": "morel", "grenadier": "gourgaud", "hussar": "dantes",
    "artillery": "nemo", "engineer": "baptiste", "medic": "omeara",
    "jager": "corso", "drummer": "pierre",
}
EXTRA_SPEAKERS = {
    "carnot": {"name": "卡尔诺"}, "berthier": {"name": "贝尔蒂埃"},
    "muleteer": {"name": "骡夫头子"}, "artillery_captain": {"name": "炮兵上尉"},
    "tutor": {"name": "家庭教师"}, "fulton_pupil": {"name": "工程师"},
    "postmaster": {"name": "驿站长"}, "innkeeper": {"name": "老板"},
}


def read(root: Path, path: str) -> dict:
    return json.loads((root / path).read_text(encoding="utf-8"))


def write(root: Path, path: str, data: dict) -> None:
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def unique(rows: list) -> list:
    result = []
    for row in rows:
        if row not in result:
            result.append(row)
    return result


def definitions(root: Path) -> dict:
    base = "docs/cards/world/drafts/"
    return {
        "trunk": read(root, base + "conquest/data/campaigns/napoleon/trunk.json"),
        "conquest": read(root, base + "conquest/data/campaigns/napoleon/conquest.json"),
        "cristo": read(root, base + "cristo/data/campaigns/napoleon/cristo.json"),
        "ocean": read(root, "data/campaigns/ocean_pawn.json"),
    }


def companion_table(root: Path, defs: dict) -> dict:
    base = "docs/cards/world/drafts/"
    conquest = read(root, base + "conquest/data/campaigns/napoleon/companions_conquest.json")
    cristo = read(root, base + "cristo/data/campaigns/napoleon/companions_cristo.json")
    ocean = read(root, base + "ocean/book_ocean.json")["companions"]
    profiles = read(root, "data/campaigns/ocean_battle.json")["companions"]
    rows = deepcopy(conquest["companions"])
    rows.update(deepcopy(cristo["companions"]))
    for cid, name in {"friday": "星期五", "nemo": "尼摩", "morel": "莫雷尔"}.items():
        rows[cid] = {"name": name, "short": name, "segments": ocean[cid]["segments"],
                     "battle": deepcopy(profiles[cid]), "bonds": ocean[cid]["bonds"]}

    for cid, row in rows.items():
        fated = []
        old_fated = row.pop("fated", None)
        if isinstance(old_fated, str):
            fated.append({"seg": "cristo", "template": old_fated})
        battle = row["battle"]
        nested = battle.pop("fated", {})
        for kind in ("templates", "scenes"):
            for target in nested.get(kind, []):
                # Cambronne's historical fate is the branch's Waterloo battle.
                fated.append({"seg": "conquest" if target == "waterloo" else "trunk",
                              "template" if kind == "templates" else "scene": target})
        if nested:
            row["fated_coins"] = int(nested.get("coins", -2))
        battle.pop("fated_scene", None)
        row.pop("shared_with_ocean", None)
        row.pop("recruit", None)
        row["recruit"] = []
        row["fated"] = fated
        row["gold"] = 3 if cid == "nemo" else 2
        if "risk" in row:
            row["leaves"] = row.pop("risk")
        row["bonds"] = [b for b in row.get("bonds", []) if b != "bandit"]

    # Actual authored rewards are authoritative for which choice recruits whom.
    for seg, definition in defs.items():
        for kind in ("scenes", "events"):
            for scene in definition.get(kind, []):
                for choice in scene.get("choices", []):
                    recruited = choice.get("rogue", {}).get("recruit", [])
                    if isinstance(recruited, str):
                        recruited = [recruited]
                    for cid in recruited:
                        assert cid in rows, (seg, scene["id"], cid)
                        rows[cid]["recruit"].append({"seg": seg,
                            "scene" if kind == "scenes" else "event": scene["id"], "choice": choice["id"]})
    for cid, (seg, node) in SHOP_NODES.items():
        spec = conquest["companions"].get(cid, cristo["companions"].get(cid, {})).get("recruit", {})
        recruit = {"seg": seg, "node": node, "gold": int(spec.get("gold", 2))}
        if spec.get("requires"):
            recruit["requires"] = deepcopy(spec["requires"])
        rows[cid]["recruit"].append(recruit)

    for cid, patch in ocean.items():
        if cid.startswith("_"):
            continue
        row = rows[cid]
        row["segments"] = unique(row["segments"] + patch.get("segments", []))
        row.setdefault("bonds_by_segment", {})["ocean"] = deepcopy(patch["bonds"])
        for seg, spec in patch.get("recruit", {}).items():
            for node in spec.get("nodes", []):
                row["recruit"].append({"seg": seg, "node": node, "gold": int(spec.get("gold", 2))})
        for seg, scene in patch.get("fated", {}).items():
            row["fated"].append({"seg": seg, "scene": scene})
        for hook in patch.get("hooks", []):
            row.setdefault("hooks", []).append({"seg": "ocean", **deepcopy(hook)})
    for cid, patch in cristo["shared_patch"].items():
        row = rows[cid]
        row["segments"] = unique(row["segments"] + patch.get("segments_add", []))
        row.setdefault("bonds_by_segment", {}).update(deepcopy(patch.get("bonds_by_segment", {})))
        for seg, template in patch.get("fated_by_segment", {}).items():
            row["fated"].append({"seg": seg, "template": template})
    for cid in ("dantes", "faria"):
        rows[cid]["available_from"] = {"seg": "cristo", "template": "if_corridors", "turn": 9}
    rows["morel"]["battle"]["role"] = "战列步兵 · 法老号船东"
    for cid, row in rows.items():
        row["segments"] = [seg for seg in SEGMENTS if seg in row["segments"]]
        row["recruit"] = unique(row["recruit"])
        row["fated"] = unique(row["fated"])
        if not row.get("bonds_by_segment"):
            row.pop("bonds_by_segment", None)
        for tag_list in [row["bonds"], *row.get("bonds_by_segment", {}).values()]:
            assert 0 < len(tag_list) <= 3 and "bandit" not in tag_list, cid
        assert all(isinstance(row["battle"][key], int) for key in ("hp", "atk", "def", "block", "cost")), cid
    # Keep authored prose alongside an executable, integer-only contract. The
    # campaign enables these rules only for books whose volume is at least two.
    reserve = {
        "baptiste": {"depot_guard": 1},
        "corso": {"chapter_coins": {"gold": 1}, "chapter_metrics": {"heat": 1}},
        "marie": {"battle_franc": 30}, "muiron": {"march_hand": 1},
        "lannes": {"recruit_discount": 1}, "murat": {"chapter_coins": {"gold": 1}},
        "desaix": {"chapter_metrics": {"heat": -3}}, "larrey": {"heal_scars": 1},
        "rustam": {"hero_fate": 1}, "eble": {"voyage_days": 1},
        "gourgaud": {"forecast": 1}, "pierre": {"chapter_metrics": {"heat": -2}},
        "drouot": {"artillery_discount": 1}, "cambronne": {"chapter_metrics": {"morale": 3}},
        "ney": {"chapter_metrics": {"morale": -2}},
        "dantes": {"chapter_coins": {"gold": 1}}, "faria": {"chapter_coins": {"intel": 1}},
        "caderousse": {"chapter_coins": {"intel": 1}}, "jacopo": {"voyage_days": 1},
        "bertuccio": {"depot_guard": 1}, "haydee": {"chapter_metrics": {"exploration": 10}},
        "ali": {"chapter_metrics": {"vitality": 4}}, "maximilien": {"chapter_metrics": {"morale": 2}},
        "vampa": {"toll_free": 1},
        "albert": {"chapter_metrics": {"treasury": 300}, "chapters": ["paris_1838"]},
    }
    departures = {
        "murat": {"segment": "trunk", "chapter": "collapse", "trust_below": 3},
        "rustam": {"segment": "trunk", "chapter": "elba"},
        "caderousse": {"segment": "cristo", "scene": "c_caderousse", "trust_below": 1, "metrics": {"heat": 20}},
    }
    pairs = []
    for source, segments in [(conquest["pairs"], ["trunk", "conquest", "ocean"]), (cristo["pairs"], ["cristo"])]:
        for original in source:
            pair = {**deepcopy(original), "segments": segments}
            # Descriptions reach the squad/battle panels; runtime flag IDs and
            # draft paragraph identifiers are not player-facing language.
            for tier, text in pair["tiers"].items():
                for source_text, replacement in {
                    "（ib_baptiste_marie 第二段）": "",
                    "（说过实话 m_bertuccio_knows）": "坦白身世后，",
                    "（m_caderousse_sworn）": "发过誓后，",
                    "（m_mercedes_spared）": "放过梅塞苔丝后，",
                    "discord": "隔阂",
                }.items():
                    text = text.replace(source_text, replacement)
                if pair.get("adjacent"):
                    text = "两人相邻时，" + text
                pair["tiers"][tier] = text
            pairs.append(pair)
            for member in (pair["a"], pair["b"]):
                if member in rows:
                    rows[member].setdefault("named_pairs", []).append(deepcopy(pair))
    for cid, row in rows.items():
        if cid in reserve:
            row["reserve"] = reserve[cid]
        if cid in departures:
            row["leave_rule"] = departures[cid]
        if cid == "ney":
            row["reckless"] = {"attack": 1, "fate_coins": -1}
    assert len(rows) == 28
    return {"version": 2, "_doc": "由 tools/napoleon/merge_presentation.py 合并三包草稿。第二卷启用名羁绊、留守、部署年龄和离队；第一卷不改变状态。遗物仍保留原稿说明。",
            "hero": deepcopy(conquest["hero"]), "companions": rows, "pairs": pairs}


def art_requests(root: Path) -> dict:
    base = "docs/cards/world/drafts/"
    sources = [read(root, base + "conquest/data/hd/art_requests/C_conquest.json")["assets"],
               read(root, base + "cristo/data/hd/art_requests/C_cristo.json")["assets"]]
    ocean = read(root, base + "ocean/ocean_art_requests.json")
    sources.append(ocean.get("add", []))
    assets = {}
    for source in sources:
        for value in source:
            row = {k: deepcopy(v) for k, v in value.items() if not k.startswith("_")}
            variants = row.pop("variants", []) if row.get("kind") == "chara" else []
            if row.get("kind") == "chara" and "variant" in row:
                variants.append(row.pop("variant"))
            base_id = RENAME.get(row.get("variant_of", row.get("id", "")), row.get("variant_of", row.get("id", "")))
            for variant in variants or [""]:
                item = deepcopy(row)
                item["id"] = base_id + ("_" + ("1793" if variant == "young" else variant) if variant else "")
                item.pop("variant_of", None)
                item.setdefault("name", item["id"])
                if variant:
                    item["name"] += " · " + str(variant)
                key = (item["kind"], item["id"])
                if key in assets:
                    assets[key]["used_in"] = unique(assets[key].get("used_in", []) + item.get("used_in", []))
                else:
                    assets[key] = item
    updates = [{k: deepcopy(v) for k, v in row.items() if not k.startswith("_")}
               for row in ocean.get("update", [])]
    return {"version": 1, "package": "C", "_doc": "内容包的正式美术需求；本轮沿用已有立绘和背景占位，不生成图像。chara 年代变体均为独立 id（C16）。",
            "assets": list(assets.values()), "update": updates}


def _aliases(name: str) -> list[str]:
    names = [s.strip() for s in re.split(r"[／/（(]", name) if s.strip() and not s.endswith(("）", ")"))]
    for text in list(names):
        for suffix in ("将军", "元帅", "船长", "上尉", "中尉", "上校", "特派员", "先生", "神甫", "中士", "亲王", "国王"):
            if text.endswith(suffix) and len(text) > len(suffix):
                names.append(text[:-len(suffix)])
    return unique(names)


def presentation(root: Path, defs: dict, roster: dict) -> dict:
    base = "docs/cards/world/drafts/"
    cast = read(root, "data/hd/vn_cast.json")
    previous = cast.pop("_generated_napoleon", {})
    for cid in previous.get("chars", []):
        cast["chars"].pop(cid, None)
    for sid in previous.get("scenes", []):
        cast["scenes"].pop(sid, None)
    original_chars = set(cast["chars"])
    original_scenes = set(cast["scenes"])
    assets = read(root, "data/hd/art_list.json")["assets"]
    known_art = {a["id"] for a in assets if a["kind"] == "chara"}
    known_bg = {a["id"] for a in assets if a["kind"] == "bg"}
    conquest = read(root, base + "conquest/data/hd/vn_cast_conquest.json")
    cristo = read(root, base + "cristo/data/hd/vn_cast_cristo.json")
    ocean = read(root, base + "ocean/ocean_events.json")
    common = read(root, base + "conquest/data/campaigns/napoleon/events_common.json")["events"]
    people = deepcopy(EXTRA_SPEAKERS)
    content = []
    for definition in defs.values():
        for person in definition.get("characters", []):
            people[RENAME.get(person["id"], person["id"])] = person
        content.extend(definition.get("scenes", []) + definition.get("events", []))
    content.extend(common + ocean["events"])
    for cid, person in ocean["new_characters"].items():
        if not cid.startswith("_"):
            people[cid] = person
    for cid, spec in cristo["chars"].items():
        row = cast["chars"].setdefault(cid, {})
        row["aliases"] = unique(row.get("aliases", []) + spec.get("aliases", []))
        row.setdefault("art", spec.get("art", cid))
    for scene in content:
        who = RENAME.get(scene.get("speaker", ""), scene.get("speaker", ""))
        if who:
            people.setdefault(who, {"name": who})
    for cid, person in people.items():
        row = cast["chars"].setdefault(cid, {})
        aliases = person.get("aliases", _aliases(person.get("name", cid)))
        if cid == "bonaparte":
            aliases = ["波拿巴", "波拿巴上尉", "波拿巴将军"]
        elif cid == "max_joseph":
            # The king and Morel's son share a given name; keep the royal title.
            aliases = ["马克西米利安国王", "巴伐利亚国王"]
        if cid in roster:
            aliases = aliases + [roster[cid]["short"]]
        if cid == "pierre":
            aliases.append("鼓手")
        row["aliases"] = unique(row.get("aliases", []) + aliases)
        row.setdefault("art", cid)
        if row["art"] not in known_art:
            cls = roster.get(cid, {}).get("battle", {}).get("cls", "")
            row["art"] = FALLBACK_ART.get(cid, CLASS_ART.get(cls, "montholon"))
            row["placeholder_only"] = True
    # All unchanged ocean-only extras also use registered placeholders.
    for cid, row in cast["chars"].items():
        if row.get("art") not in known_art:
            row["art"] = FALLBACK_ART.get(cid, "morel")
            row["placeholder_only"] = True

    staging = deepcopy(conquest["scenes"])
    staging.update(cristo["scenes"])
    staging.update(cristo["events"])
    for scene in content:
        sid = scene["id"]
        if sid in original_scenes:
            continue
        spec = staging.get(sid, {})
        who = RENAME.get(spec.get("speaker", scene.get("speaker", "")), spec.get("speaker", scene.get("speaker", "")))
        requested_bg = spec.get("bg", "camp_tent")
        bg = requested_bg if requested_bg in known_bg else "camp_tent"
        row = {"bg": [{"id": bg, "at": 0}], "cast": []}
        if who:
            assert who in cast["chars"], (sid, who)
            if who != cast.get("protagonist"):
                row["cast"] = [{"who": who, "at": "center"}]
        if requested_bg != bg:
            row["_requested_bg"] = requested_bg
        if spec.get("bg_variant"):
            row["bg"][0]["variant"] = spec["bg_variant"]
        if spec.get("variant"):
            row["art"] = {cid: cast["chars"][cid]["art"] for cid in spec["variant"]}
            row["_requested_art"] = {(RENAME.get(cid, cid)): ("morel" if cid == "morrel" else cid) + "_" + variant
                                     for cid, variant in spec["variant"].items()}
        cast["scenes"][sid] = row
    cast["_generated_napoleon"] = {"chars": sorted(set(cast["chars"]) - original_chars),
                                    "scenes": sorted(set(cast["scenes"]) - original_scenes)}
    for scene in content:
        sid = scene["id"]
        who = RENAME.get(scene.get("speaker", ""), scene.get("speaker", ""))
        assert sid in cast["scenes"], sid
        assert not who or who in cast["chars"], (sid, who)
    assert all(row["art"] in known_art for row in cast["chars"].values())
    return cast


def build(root: Path) -> dict:
    root = Path(root).resolve()
    defs = definitions(root)
    companions = companion_table(root, defs)
    cast = presentation(root, defs, companions["companions"])
    requests = art_requests(root)
    write(root, "data/campaigns/napoleon/companions.json", companions)
    write(root, "data/hd/vn_cast.json", cast)
    write(root, "data/hd/art_requests/C.json", requests)
    return {"companions": len(companions["companions"]), "characters": len(cast["chars"]),
            "vn_scenes_and_events": len(cast["scenes"]), "art_requests": len(requests["assets"])}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    print(json.dumps(build(parser.parse_args().root), ensure_ascii=False))
