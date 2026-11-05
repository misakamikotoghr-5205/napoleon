#!/usr/bin/env python3
# Regenerate ASSET_LIST.md and PROPS_NEEDED.md from docs/cards/art/blender/catalog.json.
#   python3 tools/blender/gen_asset_list.py
# catalog.json: {"generated", "source", "items": [per art id], "sets", "props", "characters", "not_blender"}
import collections
import json
import os

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DOC = os.path.join(REPO, "docs", "cards", "art", "blender")
FIT = {"good": "适合", "possible": "可以试", "poor": "不适合"}
KIND = {"scene": "场景", "object": "物件", "character": "人物", "ui": "界面", "other": "其他"}


def cell(s):
    return str(s).replace("|", "/").replace("\n", " ").strip()


def p0(ids, by_id):
    return sum(1 for i in ids if by_id[i]["priority"] == "P0")


def asset_list(cat):
    items = cat["items"]
    by_id = {i["id"]: i for i in items}
    sets = sorted(cat["sets"], key=lambda s: (s["order"], s["title"]))
    in_set = {i for s in sets for i in s["ids"]}
    out = ["# 德厚当 · 图位清单（Blender 用）", "",
           "> 由 `tools/blender/gen_asset_list.py` 从 `catalog.json` 生成，别手改；要改就改 catalog.json 再重新生成。",
           "> %s" % cat["source"],
           "> **“画面内容”“备注”两栏和场景分组是 AI（Claude）写的**，只用来查这个图位是哪张卡、在哪出现、大概要哪些道具；"
           "不能当构图依据。构图由主创给草图或摆放表（`BLENDER_PIPELINE.md` 第 1 节第 2 条）。", "",
           "## 1. 总数", "",
           "| 类别 | 适合 | 可以试 | 不适合 | 合计 |", "|---|---|---|---|---|"]
    by_cat = collections.defaultdict(collections.Counter)
    for i in items:
        by_cat[i["id"].split(".")[0]][i["blender_fit"]] += 1
    tot = collections.Counter()
    for c in sorted(by_cat):
        n = by_cat[c]
        tot.update(n)
        out.append("| %s | %d | %d | %d | %d |" % (c, n["good"], n["possible"], n["poor"], sum(n.values())))
    out.append("| **合计** | **%d** | **%d** | **%d** | **%d** |" % (tot["good"], tot["possible"], tot["poor"], sum(tot.values())))
    out += ["", "## 2. 场景分组和建议顺序", "",
            "同一组的图位在 Blender 里共用一套场景，用不同机位、摆设或灯光（变体）出图。P0 = 每局第 1 天必然看到的（出图单 `GOOGLE_ORDER_2026-10-22.md` 的定义）。", "",
            "| 顺序 | 场景 | family | 图位数 | 其中 P0 | 变体 | 共用道具 |", "|---|---|---|---|---|---|---|"]
    for s in sets:
        out.append("| %d | %s | `%s` | %d | %d | %s | %s |" % (
            s["order"], cell(s["title"]), s["family"], len(s["ids"]), p0(s["ids"], by_id), cell(s["variants"]),
            cell("、".join(s["shared_props"]))))
    out += ["", "## 3. 不走 Blender 的", "", cell(cat["not_blender"]), "",
            "## 4. 逐组明细", ""]
    head = ["| 图位 id | 尺寸 | 画面内容 | 适合度 | 人数 | 变体 | 优先级 | 要的道具 | 备注 |", "|---|---|---|---|---|---|---|---|---|"]

    def row(i):
        return "| `%s` | %s | %s | %s | %d | %s | %s | %s | %s |" % (
            i["id"], i["size"], cell(i["depicts"]), FIT[i["blender_fit"]], i["people"], cell(i["variants"]),
            i["priority"], cell("、".join(i["props"])), cell(i["note"]))

    for s in sets:
        out += ["### %d. %s（`%s`，%d 个）" % (s["order"], cell(s["title"]), s["family"], len(s["ids"])), "",
                cell(s["approach"]), ""] + head
        out += [row(by_id[i]) for i in s["ids"] if i in by_id]
        out.append("")
    rest = [i for i in items if i["id"] not in in_set]
    out += ["### 不在任何场景组里的（%d 个，多为不适合 Blender）" % len(rest), ""]
    groups = collections.defaultdict(list)
    for i in rest:
        groups[i["family"]].append(i)
    for fam in sorted(groups):
        out += ["#### `%s`（%d 个）" % (fam, len(groups[fam])), ""] + head + [row(i) for i in groups[fam]] + [""]
    return "\n".join(out) + "\n"


def props_needed(cat):
    out = ["# 德厚当 · 要建模或要买的道具和人物", "",
           "> 由 `tools/blender/gen_asset_list.py` 从 `catalog.json` 生成。",
           "> A 档 = 第 0 批（P0）要用、或很多图位都要用；B 档 = 常用；C 档 = 少数图位才用。",
           "> “KayKit 替身”= 在正式模型到位之前可以先凑合的 KayKit 模型；空着的表示没有能凑合的。",
           "> 找人建模或买模型时，要求写明：人工制作、不用 AI 生成网格或贴图、许可允许商用；交来的文件登记进 `MODELS.csv`。", ""]
    for tier in ("A", "B", "C"):
        rows = sorted((p for p in cat["props"] if p["tier"] == tier), key=lambda p: (-p["used_by"], p["name"]))
        out += ["## %s 档（%d 件）" % (tier, len(rows)), "",
                "| 道具 | 图位数 | 样子（给建模的人看） | 用在哪些场景 | KayKit 替身 | 别名 |", "|---|---|---|---|---|---|"]
        for p in rows:
            out.append("| %s | %d | %s | %s | %s | %s |" % (
                cell(p["name"]), p["used_by"], cell(p["what"]), cell("、".join("`%s`" % f for f in p["families"])),
                cell(p["kaykit_substitute"]), cell("、".join(p["aliases"]))))
        out.append("")
    out += ["## 人物（%d 个）" % len(cat["characters"]), "",
            "Blender 做人物需要专门的民国人物模型、绑定和姿势，成本比约稿画头像高得多；这里列出来是为了估算，不是建议走 Blender。", "",
            "| 谁 | 涉及图位 | 样子 |", "|---|---|---|"]
    for c in sorted(cat["characters"], key=lambda c: c["who"]):
        out.append("| %s | %s | %s |" % (cell(c["who"]), cell("、".join("`%s`" % i for i in c["ids"])), cell(c["what"])))
    return "\n".join(out) + "\n"


def main():
    cat = json.load(open(os.path.join(DOC, "catalog.json"), encoding="utf-8"))
    for name, text in (("ASSET_LIST.md", asset_list(cat)), ("PROPS_NEEDED.md", props_needed(cat))):
        with open(os.path.join(DOC, name), "w", encoding="utf-8") as f:
            f.write(text)
        print("WROTE", name)


main()
