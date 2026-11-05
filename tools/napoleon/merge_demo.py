"""Build an isolated trunk-and-first-branch-chapters playtest book.

Keep the complete releases and their maps untouched. Future chapters remain in
the copied definitions for validation/reference, but are beyond this book's
volume and cannot be selected when enforce_chapter_limits is enabled.
"""
from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path


OUT = Path("data/campaigns/napoleon")
OPEN_CHAPTERS = {
    "conquest": {"hundred_days"},
    "cristo": {"marseille"},
    # The original ocean book labels prologue separately from its first part.
    "ocean": {"prologue", "st_helena"},
}
ENDINGS = {
    "conquest": [
        ("demo_k_mercy", "百日之后 · 伤员的名字", {"flags": ["k_wounded_exchanged"]}, [
            "滑铁卢的炮声停了。白旗在夜色里来回，伤员不论军服的颜色，都被送到救护帐篷前。你把他们的名字记在军需簿上，等最后一辆车驶过泥泞的路。",
            "鹰飞分支第一章试玩到此结束。百日王朝的账已经合上，新的同盟与布鲁塞尔的道路留待后续篇章。",
        ]),
        ("demo_k_pursuit", "百日之后 · 北上的火把", {"flags": ["k_pursuit"]}, [
            "追击的骑兵已经出发。你让车队停在岔路口，核对还能行军的人、马匹和军饷，再把下一程的调拨令放进皮包。火把正沿通往布鲁塞尔的道路远去。",
            "鹰飞分支第一章试玩到此结束。是否追得上胜利之后的明天，是下一章的事。",
        ]),
        ("demo_k_first_chapter", "百日之后 · 鹰旗未落", {}, [
            "滑铁卢之夜过去了。皇帝俯身看着欧洲地图，你将最后一笔军饷记进账簿，窗外的营地终于安静下来。",
            "鹰飞分支第一章试玩到此结束。军需簿里留着一页空白，等待新的命令。",
        ]),
    ],
    "cristo": [
        ("demo_m_gerard", "马赛之后 · 检察署的门", {"flags": ["m_gerard_patron"]}, [
            "王家的旗帜重新挂上城门。杰拉尔肯为你留一条进出检察署的路，条件是把另一些名字和问题留在门外。你收好旧密信，没有立即作答。",
            "伊夫堡分支第一章试玩到此结束。马赛的风暴暂时平息，海上的石堡仍在等待下一章。",
        ]),
        ("demo_m_genoa", "马赛之后 · 去热那亚的船", {"flags": ["m_exile_genoa"]}, [
            "离港的船绕过礁石。马赛渐渐消失在身后，怀表和那封未解的信却没有变轻。你在甲板上记下热那亚的航程，等风头过去，也等一个可以返回的理由。",
            "伊夫堡分支第一章试玩到此结束。流亡不是这段故事的终点，余下的来信留待后续篇章。",
        ]),
        ("demo_m_first_chapter", "马赛之后 · 留在旧港", {}, [
            "旧港仍有人搬货、修船、等亲人回家。你借莫雷尔商行的名义留下，重新列出面包、帆布与军需的价目，把那些无人回答的请愿书收在账簿后面。",
            "伊夫堡分支第一章试玩到此结束。唐泰斯的命运尚未写完，这一章先记下你在马赛的选择。",
        ]),
    ],
    "ocean": [
        ("demo_o_costly_escape", "黑岩之后 · 带着代价离港", {"flags": ["escape_costly"]}, [
            "备用转运的船驶入夜色，圣赫勒拿的黑岩渐渐远去。名单上的人都到了，货舱与钱袋却比计划空了许多。你把这些损失照实记下，再点一遍留给下一程的补给。",
            "远洋分支第一章试玩到此结束。皇帝已经离开孤岛，新厄尔巴与更深的海仍在前方。",
        ]),
        ("demo_o_first_chapter", "黑岩之后 · 海上的第一夜", {}, [
            "约定的信号终于从岸上消失。船在夜色中离开圣赫勒拿，你将怀表、人员名册和最后一张转运凭单放在一起。海风吹过空白的航海图，新的补给点还没有名字。",
            "远洋分支第一章试玩到此结束。序曲与黑岩孤岛的航程已经写完，下一片海域留待后续篇章。",
        ]),
    ],
}


def _read(root: Path, relative: str | Path):
    return json.loads((root / relative).read_text(encoding="utf-8"))


def _write(root: Path, relative: Path, value):
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def build(root: Path) -> dict:
    book = deepcopy(_read(root, OUT / "book_volume2.json"))
    book["_doc"] = "独立试玩：主干至厄尔巴分岔；鹰飞、伊夫堡各首章；远洋序曲及第一部圣赫勒拿。后续章保留数据但不开放，完整第二卷另存。"
    book["title"]["sub"] = "主干至厄尔巴分岔，三个分支各体验第一章"
    book["enforce_chapter_limits"] = True
    book["chapter_locked_message"] = "本试玩仅开放各分支的第一章"
    summary = {}
    for segment, allowed in OPEN_CHAPTERS.items():
        spec = book["segments"][segment]
        definition = deepcopy(_read(root, spec["file"].removeprefix("res://")))
        for chapter in definition["chapters"]:
            if chapter["id"] not in allowed:
                chapter["volume"] = int(book["volume"]) + 1
        endings = ENDINGS[segment]
        rules = definition.setdefault("rules", {})
        rules["volume_endings"] = [{"id": id_, "when": when} for id_, _, when, _ in endings[:-1]]
        rules["default_volume_ending"] = endings[-1][0]
        definition["endings"].extend({"id": id_, "title": title, "body": body, "kind": "volume"}
                                     for id_, title, _, body in endings)
        output = OUT / "demo" / (segment + ".json")
        _write(root, output, definition)
        spec["file"] = "res://" + str(output)
        # The title collection must not count inaccessible later endings.
        spec["collection_endings"] = [row[0] for row in endings]
        summary[segment] = {
            "open_chapters": [chapter["id"] for chapter in definition["chapters"] if chapter["id"] in allowed],
            "open_scenes": sum(len(chapter["scene_ids"]) for chapter in definition["chapters"] if chapter["id"] in allowed),
            "volume_endings": spec["collection_endings"],
        }
    _write(root, OUT / "book_demo.json", book)
    return summary
