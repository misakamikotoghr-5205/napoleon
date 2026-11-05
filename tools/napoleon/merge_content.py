"""Convert the authored campaign drafts to WORLD_MAP_DESIGN section 6.

Drafts stay intact. Runtime JSON is regenerated deterministically; ocean_pawn is
read as the canonical single-segment regression data and is never written here.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path

from volume2_story import expand as expand_volume2


DRAFT = Path("docs/cards/world/drafts")
OUT = Path("data/campaigns/napoleon")
SOURCES = {
    "trunk": "conquest/data/campaigns/napoleon/trunk.json",
    "conquest": "conquest/data/campaigns/napoleon/conquest.json",
    "cristo": "cristo/data/campaigns/napoleon/cristo.json",
}
WORDING = {"账房先生": "军需文书", "经营须知": "行军须知", "典当": "交割", "当铺": "军需所", "当票": "凭证", "流当": "清算", "估值铺": "军需所", "掌柜": "军需官", "挂牌": "挂旗", "柜台": "军需台", "活当": "暂存", "收当": "收存", "盘库": "清点", "鉴定": "查验", "营业": "补给", "当物": "交割物", "赎当": "取回", "押当": "抵押", "典押": "抵押"}
SIGNS = {
    "white": {"daily": {}, "map": {}},
    "red": {"daily": {"heat": 10}, "map": {"pass_supply": 1}},
    "black": {"daily": {"treasury": -10, "heat": -10}, "map": {"mp": -1}},
}


def read(root: Path, path: str | Path):
    return json.loads((root / path).read_text(encoding="utf-8"))


def write(root: Path, path: str | Path, value):
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def normalise(value):
    if isinstance(value, list):
        return [normalise(v) for v in value]
    if isinstance(value, dict):
        out = {k: normalise(v) for k, v in value.items()}
        if isinstance(out.get("boss_mod"), dict) and "turns" in out["boss_mod"]:
            out["boss_mod"]["prep_turn"] = out["boss_mod"].pop("turns")
        if isinstance(out.get("weather"), str):
            out["weather"] = [out["weather"]]
        return out
    if isinstance(value, str):
        value = value.replace("gerard_villefort", "gerard").replace("莫雷尔船长", "莫雷尔船东")
        for old, new in WORDING.items():
            value = value.replace(old, new)
        return value
    if isinstance(value, float):
        if not value.is_integer():
            raise ValueError(f"Non-integer campaign value {value}")
        return int(value)
    return value


def event(ev: dict) -> dict:
    ev = normalise(ev)
    if ev.get("id") == "ev_noirtier_eyes":
        ev["body"] = ["老人一动不动，只有眼睛能回答。他反复望向瓦朗蒂娜，又望向门口，直到你明白：这屋里有人正在伤害她。",
            "瓦朗蒂娜：“爷爷要我向你求援。他说，先让我离开危险，其他的事以后再问。”"]
        for choice in ev.get("choices", []):
            if choice["id"] == "antidote_faria":
                choice["label"] = "请法利亚照料她，先把她转移到安全的住处"
            elif choice["id"] == "count_narcotic":
                choice["label"] = "按伯爵的安排秘密接走她，暂时隐瞒她的下落"
    if "chapter" in ev:
        ev["chapters"] = [ev.pop("chapter")]
    pool = ev.get("pool", "")
    if pool.startswith("interlude:"):
        ev["interlude"] = pool.removeprefix("interlude:")
    if ev.get("interlude") == "camp_night":
        ev.setdefault("offer", min(3, len(ev.get("choices", []))))
    picks = ev.pop("pick_companions", 0)
    for choice in ev.get("choices", []):
        count = choice.pop("bond_pick", picks)
        if count:
            choice.setdefault("rogue", {})["trust"] = {"pick": count, "gain": 1}
        kind = choice.pop("minigame", "")
        if kind:
            clue = ev["id"] + "_" + kind
            ev.setdefault("appraisals", []).append({
                "id": clue, "kind": kind,
                "label": "核对密码表" if kind == "decode" else "核对金库分量",
                "observation": "法利亚把字母藏在数字之间，逐列比对后，信上的路线清楚了。" if kind == "decode" else "各箱的分量与清单逐项相符，账上的金子确实就在这里。",
            })
            choice.setdefault("requires_clues", []).append(clue)
    # Earlier drafts represented an audience as mutually exclusive responses.
    # Preserve those responses, pairing each question with an explicit deferral.
    if ev.get("interlude") == "audience" and "questions" not in ev:
        choices = ev.pop("choices", [])
        if len(choices) == 2:
            ev["questions"] = [{"id": ev["id"] + "_answer", "q": ev.get("title", "召见"), "a": choices[0], "b": choices[1]}]
        else:
            ev["questions"] = [{"id": c["id"], "q": c["label"].split("——")[0], "a": c,
                "b": {"label": "先听他说下去，暂不作答", "effects": {}}} for c in choices]
    for row in ev.get("choices", []):
        row.pop("advance", None)
    return ev


def volume_endings(definition: dict, segment: str):
    if segment == "conquest":
        rows = [
            ("k_vol1_mercy", "胜利之夜", {"flags": ["k_wounded_exchanged"]}, ["白旗在蒙圣让的夜色里来回。一万伤员，不论军服的颜色，都被送到了拉雷的帐篷前。", "皇帝的账上写着一场胜利；你的账上，先写下这些活人的名字。鹰飞第一卷终，布鲁塞尔的道路留待下一卷。"]),
            ("k_vol1_pursuit", "追到布鲁塞尔", {"flags": ["k_pursuit"]}, ["火把把通往布鲁塞尔的路连成一线。军需车跟着疲惫的骑兵继续向北，伤员的呻吟还在身后。", "没人知道下一封战报会写些什么。你重新扣上钱袋，随鹰旗走进没有历史书可循的黎明。鹰飞第一卷终。"]),
            ("k_vol1", "鹰飞·待续", {}, ["缴获的军旗送往巴黎。客栈里，皇帝伏在欧洲地图上，你把最后一笔军饷记进账簿。", "滑铁卢之夜过去了，新的同盟还在远处集结。这一局的百日王朝已经写完，余下的路留待下一卷。"]),
        ]
    elif segment == "cristo":
        rows = [
            ("m_vol1_two", "两个人的海", {"flags": ["m_faria_lives"]}, ["海门后的警钟越来越远。唐泰斯扶着法利亚，两个人的身影在海面上时隐时现。", "半封信、十四年的等待和一张没有写完的地图，终于离开了伊夫堡。蒂布朗岛就在前方。伊夫堡第一卷终。"]),
            ("m_vol1", "伊夫堡·待续", {}, ["麻袋沉进海里。唐泰斯从缝隙间割开一道口子，第一次看见十四年来不受铁窗分割的夜空。", "你留在岸边，把空白的一页夹进旧卷宗。基督山的金子尚在海的另一端，这一夜，先让一个人重获自由。伊夫堡第一卷终。"]),
        ]
    else:
        return
    definition["rules"]["volume_endings"] = [{"id": id_, "when": cond} for id_, _, cond, _ in rows[:-1]]
    definition["rules"]["default_volume_ending"] = rows[-1][0]
    definition["endings"].extend({"id": id_, "title": title, "body": body, "kind": "volume"} for id_, title, _, body in rows)


def definitions(root: Path) -> dict:
    output = {}
    canonical = {row["id"]: row["name"] for row in read(root, "data/campaigns/ocean_pawn.json")["items"]}
    for seg, path in SOURCES.items():
        d = normalise(read(root, DRAFT / path))
        d["version"] = 2
        d["events"] = [event(ev) for ev in d.get("events", [])]
        d["rules"]["signs"] = deepcopy(SIGNS)
        for id_, row in d["rules"].pop("failure_text", {}).items():
            d["endings"].append({"id": id_, **row, "kind": "failure"})
        for row in d["endings"]:
            if row["id"] in ["bankruptcy", "loss", "blockade", "exile"]:
                row["kind"] = "failure"
        for i, chapter in enumerate(d["chapters"]):
            chapter["volume"] = 2 if (seg == "conquest" and i >= 1) or (seg == "cristo" and i >= 2) else 1
        for row in d["items"]:
            if row["id"] in canonical:
                row["name"] = canonical[row["id"]]
        for scene in d["scenes"]:
            scene.setdefault("on_enter", {"demands": []})
            if scene["id"] in ["alps_marengo", "eylau_snow", "wagram_lobau"]:
                scene.setdefault("when", {})["volume"] = 2
            for choice in scene["choices"]:
                if choice["id"] in ["stay_europe", "watch_prussia", "back_to_danube"]:
                    choice.setdefault("requires", {})["volume"] = 2
                if scene["id"] == "elba_1815" and choice["id"] == "carry_the_letter":
                    choice.setdefault("items", []).append("emperor_letter")
        if seg == "trunk" and not any(i["id"] == "emperor_letter" for i in d["items"]):
            cristo = read(root, DRAFT / SOURCES["cristo"])
            d["items"].append(deepcopy(next(i for i in cristo["items"] if i["id"] == "emperor_letter")))
        for fate in d.get("big_fate_extra", []):
            if "label" in fate:
                fate["title"] = fate.pop("label")
            if fate["id"] == "exile_with_emperor":
                fate["when"] = {"not_flags": ["k_petition_returned"]}
        volume_endings(d, seg)
        if seg == "cristo":
            expand_volume2(d)
        echoes = {
            "collapse_fontainebleau": ("t_baptiste_marie_married", ["行军簿里还夹着巴蒂斯特与玛丽的婚礼证词。两个人没有等到和平，只在撤退途中请几个老朋友做了见证。你替他们留好这一页：帝国的年号可以更换，答应彼此的话不该跟着作废。"]),
            "k_waterloo_night": ("k_spada_letter", ["唐泰斯和法利亚一起送来回信，落款不再是伊夫堡的两个号码。法利亚说，斯帕达的遗产不只是一笔钱，也是给获救者重新选择一生的机会。你把信放在伤员交换清单旁边。"]),
            "k_final": ("k_spada_letter", ["你又读了一遍唐泰斯与法利亚联署的那封信。牢房曾经把他们写成两个号码，他们却把自由写成了两个人的名字。桌上的和约、皇冠和辞呈，现在也都需要一个人亲自签名。"]),
        }
        for scene in d["scenes"]:
            if scene["id"] in echoes:
                flag, body = echoes[scene["id"]]
                scene["body_extra"] = [{"when": {"volume": 2, "flags": [flag]}, "body": body}]
        for ending in d["endings"]:
            if ending["id"] == "m_wait_hope":
                ending["body_extra"] = [{"when": {"volume": 2, "flags": ["m_wait_hope_bond"]},
                    "body": ["海黛站在船尾，直到岛上的灯火缩成一粒星。唐泰斯没有再回头数自己的仇人，也没有替她决定下一处港口；他把海图铺开，等她指向愿意去的地方。那封留给岸上人的信已经封好，船上的两个人终于有了不必写进信里的明天。"]}]
        output[seg] = d
        write(root, OUT / (seg + ".json"), d)
    return output


def build(root: Path) -> dict:
    defs = definitions(root)
    for target, source in [("events_common", "conquest/data/campaigns/napoleon/events_common.json"), ("ocean_events", "ocean/ocean_events.json")]:
        draft = read(root, DRAFT / source)
        rows = [event(ev) for ev in draft["events"]]
        if target == "ocean_events":
            chapters = {"ev_o_int_hundred_days": "prologue", "ev_o_int_northumberland": "st_helena", "ev_o_int_lightning": "new_elba", "ev_o_int_organ": "nautilus"}
            for ev in rows:
                if ev["id"] in chapters:
                    ev["chapters"] = [chapters[ev["id"]]]
        write(root, OUT / (target + ".json"), {"events": rows})
    book = read(root, "tools/napoleon/book_structure.json")
    book["_doc"] = ["运行数据由 tools/napoleon/merge_drafts.py 从作者草稿转换，原稿保留在 docs/cards/world/drafts。", "第一卷：主干八章、完整远洋、鹰飞百日、伊夫堡前两章。其余章节标记 volume:2。"]
    conquest = read(root, DRAFT / "conquest/data/campaigns/napoleon/book_conquest_patch.json")
    cristo = read(root, DRAFT / "cristo/data/campaigns/napoleon/book_cristo_patch.json")
    ocean = read(root, DRAFT / "ocean/book_ocean.json")
    defs["ocean"] = read(root, "data/campaigns/ocean_pawn.json")
    for seg in book["segments"]:
        spec = book["segments"][seg]
        battles = {s["id"]: {"template": ""} for s in defs[seg]["scenes"]}
        if seg in ["trunk", "conquest"]:
            additions = conquest["scene_battles"][seg]
        elif seg == "cristo":
            additions = cristo["segments"][seg]["scene_battles"]
        else:
            additions = ocean["segments"][seg]["scene_battles"]
        for id_, row in additions.items():
            battles[id_] = {**spec.get("scene_battles", {}).get(id_, {}), **row}
        spec["scene_battles"] = battles
        if seg == "cristo":
            for id_, flag in cristo["segments"][seg]["order_flags"].items():
                battles[id_]["order_flag"] = flag
    # These battlefields are authored for volume two. Keep their specifications
    # beside the runtime table while the first volume exposes teaser anchors.
    book["_volume2_scene_battles"] = {"trunk": {}}
    for id_ in ["alps_marengo", "eylau_snow", "wagram_lobau"]:
        book["_volume2_scene_battles"]["trunk"][id_] = book["segments"]["trunk"]["scene_battles"][id_]
        book["segments"]["trunk"]["scene_battles"][id_] = {"template": ""}
    book["templates_needed"] = deepcopy(conquest["templates_needed"])
    book["templates_needed"].extend({"id": id_, "volume": 2} for id_ in ["tiboulen_swim", "monte_cristo_cave", "appian_way", "san_sebastiano", "auteuil_garden", "paris_rooftops", "cristo_final"])
    book["shared_flags"] = sorted(set(book["shared_flags"] + conquest["shared_flags_add"] + cristo["shared_flags_add"]))
    book["shared_flags"] = sorted(set(book["shared_flags"] + ["t_baptiste_marie_married", "k_spada_letter", "m_wait_hope_bond"]))
    companion_path = root / OUT / "companions.json"
    if companion_path.exists():
        book["hero"] = deepcopy(read(root, OUT / "companions.json").get("hero", {"bonds": ["italy", "quartermaster", "imperial"]}))
    # Original ocean army allocations are kept; new chapters fill missing ranks
    # using the published reference roster's level-based progression.
    base_army = read(root, "data/campaigns/ocean_battle.json").get("start_troops", {})
    if isinstance(base_army, dict):
        book["start_troops"].update(base_army)
    # Toulon teaches rain and artillery suppression; the opening army needs a gun.
    book["start_troops"]["toulon"] = ["line", "line", "jager", "artillery"]
    levels = read(root, DRAFT / "spec/data/levels_final.json")["plan"]
    troops = ["line", "line", "grenadier", "jager", "hussar", "artillery", "line", "artillery"]
    for seg, chapters in levels.items():
        for chapter in chapters:
            book["start_troops"].setdefault(chapter["chapter"], troops[:min(8, 4 + chapter["boss"][1] // 4)])
    book["debug_carry"]["ocean"]["stages"] = {k: v for k, v in ocean["debug_carry"]["ocean_stages"].items() if not k.startswith("_")}
    base = book["debug_carry"]["branch_point"]
    cq = conquest["debug_carry"]["conquest"]
    book["debug_carry"]["conquest"].update({"flags_add": cq["flags"], "companions": cq["companions"]})
    for stage in range(len(defs["conquest"]["chapters"])):
        book["debug_carry"]["conquest"]["stages"][str(stage)] = {
            "coins": {k: min(20, v + (2 * stage if k != "intel" else 0)) for k, v in base["coins"].items()},
            "companions": {k: min(3, max(1, v) + stage) for k, v in cq["companions"].items()},
            "troops": base["troops"] + ["line"] * stage,
        }
    # Cristo draft stages were human chapter numbers (1..5); normalize to 0..4.
    state = deepcopy(base)
    state["flags_add"] = list(cristo["debug_carry"]["cristo"]["flags_add"])
    for stage in range(len(defs["cristo"]["chapters"])):
        patch = cristo["debug_carry"]["cristo"]["stage_overrides"].get(str(stage + 1), {})
        state["flags_add"] += patch.get("flags_add", [])
        state["companions"].update(patch.get("companions_add", {}))
        state["coins"].update(patch.get("coins", {}))
        book["debug_carry"]["cristo"]["stages"][str(stage)] = deepcopy(state)
    labels = {"march_2": "稳步行军", "march_3": "纵队行军", "forced_4": "强行军", "scout_1": "斥候先行", "wagon_1": "辎重随行", "night_2": "夜行", "fair_wind": "顺风", "dive_3": "潜航"}
    for id_, label in labels.items():
        book["march_cards"][id_]["label"] = label
    write(root, OUT / "book.json", normalise(book))
    full = deepcopy(book)
    full["version"] = 2
    full["volume"] = 2
    full["_doc"] = ["第二卷运行数据：完整主干战区与鹰飞、远洋、伊夫堡三线。源稿保留在 docs/cards/world/drafts。",
        "book.json 保留第一卷入口和门禁；本书使用 maps/volume2 的完整地图。"]
    full["title"]["sub"] = "一七九三 · 土伦 → 鹰飞一八一九 / 远洋 / 基督山一八三八"
    for seg, spec in full["segments"].items():
        spec["map"] = spec["map"].replace("/maps/", "/maps/volume2/")
    full["segments"]["trunk"]["scene_battles"].update(full.pop("_volume2_scene_battles")["trunk"])
    full["templates_needed"] = []
    # The draft wishes overlap existing level bands. Compile a disjoint table
    # because the runtime deliberately takes the first matching level band.
    for seg in ["trunk", "conquest"]:
        by_level = {}
        for band, pool in book["battle_pool"][seg].items():
            low, high = map(int, band.split("-"))
            for level in range(low, high + 1):
                by_level[level] = list(pool)
        for band, pool in conquest["battle_pool_wanted"][seg].items():
            low, high = map(int, band.split("-"))
            for level in range(low, high + 1):
                by_level.setdefault(level, []).extend(t for t in pool if t not in by_level.get(level, []))
        grouped = {}
        levels_sorted = sorted(by_level)
        low = high = levels_sorted[0]
        pool = by_level[low]
        for level in levels_sorted[1:]:
            if level == high + 1 and by_level[level] == pool:
                high = level
                continue
            grouped[f"{low}-{high}"] = pool
            low = high = level
            pool = by_level[level]
        grouped[f"{low}-{high}"] = pool
        full["battle_pool"][seg] = grouped
    write(root, OUT / "book_volume2.json", normalise(full))
    return {"segments": {seg: {"chapters": len(d["chapters"]), "scenes": len(d["scenes"]), "events": len(d.get("events", []))} for seg, d in defs.items()}}
