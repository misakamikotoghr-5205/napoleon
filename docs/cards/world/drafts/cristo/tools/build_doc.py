#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Render ../CRISTO.md from the built JSON drafts (run build_cristo.py first).
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
J = lambda p: json.load(open(os.path.join(ROOT, p), encoding="utf-8"))
SEG = J("data/campaigns/napoleon/cristo.json")
MAP = J("data/campaigns/napoleon/maps/med.json")
BAT = J("data/campaigns/battle_templates_cristo.json")
COM = J("data/campaigns/napoleon/companions_cristo.json")
ART = J("data/hd/art_requests/C_cristo.json")
SUM = J("tools/out/build_summary.json")
TYPE_ZH = {"story": "剧情", "boss": "Boss", "elite": "精英", "battle": "遭遇", "event": "事件", "camp": "营地", "supply": "补给", "shop": "商贩", "slot": "随机槽"}
ROLE_ZH = {"post": "驿站", "muster": "集结", "intel": "密探", "project": "工程", "council": "军议"}


def table(head, rows):
    out = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for r in rows:
        out.append("| " + " | ".join(str(x).replace("|", "\\|") for x in r) + " |")
    return "\n".join(out)


def node_table(sh):
    rows = []
    for n in sh["nodes"]:
        what = n.get("scene") or n.get("event") or ("%s L%d" % (n["template"], n["level"]) if n.get("template") else "")
        if n["type"] == "slot":
            k = n["slot"]["kinds"]
            what = "池 %s；%s" % (n["slot"]["pool"], "、".join("%s %d" % (a, b) for a, b in k.items())) + (("；战斗 L%d" % n["slot"]["level"]) if "level" in n["slot"] else "")
        rows.append([n["id"], n["label"], TYPE_ZH[n["type"]] + ("·" + ROLE_ZH[n["role"]] if n.get("role") else ""), "战役" if n.get("phase") == "campaign" else "积累",
                     n.get("date", ""), what, "、".join(n.get("actions", []))])
    return table(["id", "地名", "类型", "阶段", "日期", "内容", "动作"], rows)


def tpl_block(tid, v):
    t = v["template"]
    lines = ["#### `%s` %s（%s，%d×%d，%s，%d 回合，敌军心 %d，天时 %s）" % (tid, t["name"], t["scale"], t["size"][0], t["size"][1],
             ("L%d" % t["level"]) if "level" in t else ("基准 L%d + 补兵 %s 每 %d 级" % (t["base_level"], t["pad"]["kind"], t["pad"]["every"])),
             t["turn_limit"], t["enemy_morale"], t.get("weather", "clear"))]
    cols = "".join(chr(65 + i) for i in range(t["size"][0]))
    lines.append("```\n   " + cols + "\n" + "\n".join("%2d %s" % (i + 1, r) for i, r in enumerate(t["map"])) + "\n```")
    lines.append("- 命令：%s" % t["order"]["desc"] + (("（退路：%s）" % t["order_fallback"]["desc"]) if "order_fallback" in t else ""))
    lines.append("- 路线：" + "；".join("`%s` %s→%s（%d 格）" % (k, r[0], r[-1], len(r) - 1) for k, r in t["routes"].items()))
    wv = []
    for w in t["waves"]:
        units = []
        for u in w["units"]:
            if isinstance(u, str):
                units.append(u)
            else:
                units.append(u["kind"] + ("[" + ",".join(u.get("tags", [])) + "]" if u.get("tags") else "") + (("≥L%d" % u["lv_min"]) if u.get("lv_min") else ""))
        wv.append("T%d %s：%s" % (w["turn"], w.get("route", "@" + w.get("at", "")), "、".join(units)))
    lines.append("- 来敌：" + "；".join(wv))
    if t.get("events"):
        lines.append("- 地形事件：" + "；".join("打死 %s → %s 变成 %s" % (e["on_kill"], e["cell"], e["terrain"]) for e in t["events"] if "on_kill" in e))
    lines.append("- 说明：" + t["notes"])
    lines.append("- 参考打法（%s 名册）：%s" % (v["plan"]["roster"], v["plan"]["text"]))
    rows = []
    for r in v["evidence"]["rows"]:
        p = r["plan"]
        rows.append(["L%d" % r["L"], r["idle"], r["hero_only"], "%s 军心 %d 漏 %d 倒下 %s 命令 %s" % (p["outcome"], p["morale"], p["leaks"], "、".join(p["fallen"]) or "无", "完成" if p["order_done"] else "未完成"),
                     r["counts"]["enemies"], r["counts"]["hunters"], r["counts"]["elites"], r["counts"]["power"]])
    lines.append(table(["等级", "什么都不做", "只放主角（最好的一格）", "参考打法", "敌数", "猎官", "精英", "敌战力"], rows))
    return "\n".join(lines)


def main():
    ch_rows = []
    sb = BAT["scene_battles"]
    for c, sh in zip(SEG["chapters"], MAP["sheets"]):
        anchors = " → ".join("%s%s" % (s, ("（%s L%d）" % (sb[s]["template"], sb[s]["level"])) if s in sb else "") for s in c["scene_ids"])
        el = [n for n in sh["nodes"] if n["type"] == "elite"]
        slotL = sorted({n["slot"]["level"] for n in sh["nodes"] if n["type"] == "slot" and "level" in n["slot"]})
        ch_rows.append([c["id"], c["title"], sh["view"], anchors, "、".join("%s L%d" % (n["template"], n["level"]) for n in el) or "—",
                        "L%s" % "/".join(map(str, slotL)), sh["days_max"], sh["interlude"]])
    map_rows = [[m["chapter"], m["view"], m["nodes"], m["links"], m["slots"], m["expected_events"], m["shortest_days"], m["days_max"]] for m in SUM["maps"]]
    en_rows = []
    for k, e in BAT["enemies"].items():
        en_rows.append([k, e["name"], e["hp"], e["atk"], e["def"], e["spd"], e["type"], e["range"], "、".join(e["tags"]), "、".join(e.get("at_terrain", [])), BAT["enemy_notes"][k]["src"], BAT["enemy_notes"][k]["note"]])
    comp_rows = []
    for k, c in COM["companions"].items():
        b = c["battle"]
        comp_rows.append([k, c["name"], "%s %d/%d/%d 阻%d 费%d" % (b["cls"], b["hp"], b["atk"], b["def"], b["block"], b["cost"]), b["skill_title"], "、".join(c["bonds"]),
                          json.dumps(c["recruit"], ensure_ascii=False), c["fated"], c["keep"], c.get("risk", "")])
    for k, c in COM["shared_patch"].items():
        comp_rows.append([k, "（跨段）", "沿用远洋 / 主干数值", "", "、".join(c.get("bonds_by_segment", {}).get("cristo", [])),
                          json.dumps(c.get("recruit_by_segment", {}).get("cristo", "主干携带"), ensure_ascii=False), c.get("fated_by_segment", {}).get("cristo", ""), "", c.get("note", "")])
    ev_rows = [[e["id"], e["pool"], e["title"], e.get("weight"), "、".join(c["label"] for c in e["choices"])] for e in SEG["events"]]
    planned_rows = [[k, p["name"], p["chapter"], p["node"], p["scale"], "%d×%d" % tuple(p["size"]), "L%d" % p["level"], p["turn_limit"], p["weather"],
                     p["objective"]["type"], "、".join(p["enemies"]), p["power_target"] or "—"] for k, p in BAT["planned"].items()]
    curve = " → ".join("%s L%d %s%s" % (c["template"], c["L"], c["power"], "（目标）" if c.get("planned") else "") for c in BAT["boss_curve"])
    art_count = {}
    for a in ART["assets"]:
        art_count[a["kind"]] = art_count.get(a["kind"], 0) + 1
    end_rows = []
    rule = {e["id"]: e["when"] for e in SEG["rules"]["endings"]}
    for e in SEG["endings"]:
        end_rows.append([e["id"], e["title"], json.dumps(rule.get(e["id"], "默认"), ensure_ascii=False), e["body"][0]])

    doc = DOC.format(
        ch_table=table(["章", "标题", "地图视图", "锚点场景（战斗）", "精英（可绕）", "随机遭遇", "天数上限", "幕间"], ch_rows),
        map_table=table(["章", "视图", "节点", "连线", "随机槽", "期望事件", "最短天数", "天数上限"], map_rows),
        node_tables="\n\n".join("#### %s（%s）\n\n起点 `%s`，集结 `%s`，Boss `%s`，驿站印 %d 枚，天数上限 %d。对手：%s。\n\n%s" % (
            sh["chapter"], sh["view"], sh["start"], sh["muster"], sh["boss"], sh["stamps_need"], sh["days_max"],
            "；".join("%s（%s，碰上：%s）" % (r["label"], "→".join(r["path"]), json.dumps(r["meet"], ensure_ascii=False)) for r in sh.get("rivals", [])), node_table(sh)) for sh in MAP["sheets"]),
        enemy_table=table(["id", "名字", "兵力", "攻", "防", "速", "type", "射程", "标签", "at 格", "来源", "说明"], en_rows),
        comp_table=table(["id", "名字", "兵种与数值", "技能", "阵营", "招募", "宿命之地", "留守", "风险 / 备注"], comp_rows),
        pair_table=table(["id", "名字", "两人", "各档"], [[p["id"], p["name"], "%s × %s%s" % (p["a"], p["b"], "（不和）" if p.get("discord") else ""), "；".join("%s：%s" % kv for kv in p["tiers"].items())] for p in COM["pairs"]]),
        faction_table=table(["id", "名字", "标签", "档位", "说明"], [[f["id"], f["name"], f["tag"], f["tiers"], f["desc"]] for f in COM["bond_set_napoleon_add"]]),
        tpl_blocks="\n\n".join(tpl_block(k, v) for k, v in BAT["templates"].items()),
        planned_table=table(["id", "名字", "章", "节点", "规模", "尺寸", "等级", "回合", "天时", "命令", "敌人", "战力目标"], planned_rows),
        curve=curve, ev_table=table(["id", "池", "标题", "权重", "抉择"], ev_rows), end_table=table(["id", "标题", "条件", "第一句"], end_rows),
        art_count="、".join("%s %d" % kv for kv in sorted(art_count.items())), n_art=len(ART["assets"]),
        counts=json.dumps(SUM["counts"], ensure_ascii=False), errors=len(SUM["errors"]),
        files="\n".join("- `%s`" % f for f in SUM["files"]),
        vn_ch1="\n\n".join(vn_scene(s) for s in SEG["scenes"] if s["chapter"] == "marseille"),
        outline="\n".join("- **%s** `%s`（%s，%s）：%s 抉择：%s。" % (s["title"], s["id"], s["date"], s["location"], "".join(s["body"][:2]), " / ".join(c["label"] for c in s["choices"]))
                          for s in SEG["scenes"] if s["chapter"] != "marseille"),
    )
    open(os.path.join(ROOT, "CRISTO.md"), "w", encoding="utf-8").write(doc)
    print("wrote", os.path.join(ROOT, "CRISTO.md"), len(doc))


def vn_scene(s):
    lines = ["**%s** `%s` · %s · %s · 主讲 %s" % (s["title"], s["id"], s["date"], s["location"], s["speaker"])]
    lines += ["> " + b for b in s["body"]]
    if s["appraisals"]:
        lines.append("查验：" + "；".join("%s（%s）：%s" % (a["label"], a["kind"], a["observation"]) for a in s["appraisals"]))
    lines.append("抉择：")
    for c in s["choices"]:
        gate = []
        if c.get("requires_clues"):
            gate.append("需查验 " + "、".join(c["requires_clues"]))
        if c.get("requires_flags"):
            gate.append("需旗标 " + "、".join(c["requires_flags"]))
        lines.append("- `%s` %s%s → %s %s %s" % (c["id"], c["label"], ("（" + "；".join(gate) + "）") if gate else "", json.dumps(c["effects"], ensure_ascii=False),
                                            "、".join(c["flags"]), json.dumps(c.get("rogue", {}), ensure_ascii=False) if c.get("rogue") else ""))
    return "\n".join(lines)


DOC = """# 伊夫堡分支（基督山伯爵）设计稿 · CRISTO

> 2026-11-02，标签 cristo。依据 `wm/arch/ARCH.md`（A/B/C 契约）和 `wm/geo/`（地理底图与地名表）。只写草稿，不碰仓库。
> 原著：大仲马《基督山伯爵》（1844—1846，公有领域）。人物、地名、日期都出自原著或史实；本分支自己的发明（主角、面包合同、法利亚活下来、司法宫之夜）在文中标明。不借用任何现代改编。
> 所有 JSON 由 `tools/build_cristo.py` 生成并自检（本次 {errors} 个错误）；本文由 `tools/build_doc.py` 从 JSON 渲染。

## 0 结论速览

1. **入口**：主干终章 `elba_1815` 的第三个抉择「奉命携密信去马赛」（`branch: "cristo"`，旗标 `m_letter_carried`）。可用条件照 ARCH §1.2：`faria_half_letter`（第一幕博洛尼亚的半封信）或 `t_pharaon_known`（土伦的莫雷尔粮船、费拉约港的法老号）。主干已经埋好的 `t_dantes_letter`（你在厄尔巴亲手把信交给了唐泰斯）、`t_morrel_credit`、`t_went_home` 只改开局，不挡门。
2. **主角的位置**：埃德蒙·德·维尔福**不坐牢**。他带着皇帝的第二封信（与唐泰斯身上的是同一封信的两份，收信人都是杰拉尔的父亲努瓦蒂埃），晚到了半天。之后十四年，他在墙外：靠军需官的老本行拿到伊夫堡驻军的**面包合同**，于是能进地牢的厨房、给 27 号送药、给地道送工具。主线张力是姓氏：揭发杰拉尔，就是亲手毁掉维尔福这个姓。
3. **五章**，Boss 等级 L14 / 16 / 18 / 21 / 24（严格递增；章内遭遇 ≤ Boss−2、精英与锚点战 ≤ Boss−1；第一章遭遇战 L12，沿用鹰飞草稿对 ARCH 两条规则冲突的读法）：
   马赛 1815 → 伊夫堡岁月 1816—1829 → 基督山 1829 → 地中海 1829—1838 → 巴黎 1838。
4. **每章一张图**：马赛和巴黎用局部画布图（`marseille_1815`、`paris_1838`），伊夫堡岁月用「左边要塞、右边海岸」的 `if_fortress` 画布图（一张图跨十三年，锚点上标年份），基督山和地中海用 `med` 地理图（加 frames 放大罗马城和基督山岛）。约阿尼纳、君士坦丁堡、突尼斯是远航连线（`voyage_days`）通到的远方节点。
5. **三个固定结局 + 一个默认结局**：慈悲「等待与希望」、清算「伯爵的清单」、保姓「维尔福这个姓」，默认「基督山伯爵」。终场 `c_trial` 的三个抉择分别打开它们；慈悲还要求瓦朗蒂娜得救（`m_valentine_saved`），清算还要求三个仇人都倒下且卷宗 ≥ 100。
6. **战斗**：6 张模板已经画完并用模拟器验过（什么都不做必输、只放主角必输、参考打法能赢），覆盖第一、二章的全部战斗节点和 2 张通用遭遇战；第三到五章 8 张模板给出规格（尺寸、地形、命令、敌人、战力目标），B2 来画。Boss 战力曲线：{curve}（每步 ≥ ×1.12）。
7. **伙伴**：新增 8 人（卡德鲁斯、雅科波、贝尔图乔、海黛、阿里、马克西米利安、万帕、阿尔贝），沿用 6 个跨段的人（唐泰斯、法利亚、莫雷尔与远洋同 id 同数值；巴蒂斯特、科尔索、玛丽由主干带来）。唯一的架空岔口：第二章带着药（`m_faria_medicine`），法利亚就能活过第三次发作，和唐泰斯一起出逃，成为后三章的伙伴（一条命）。
8. **去当铺**：本分支所有玩家可见的文字对 ARCH §6 的词表 0 命中（自检）。

## 1 入口、可用性与携带

- 分岔场景、抉择 id、`requires` 原样沿用 ARCH §1.4 与鹰飞草稿（`book_cristo_patch.json` 只补伊夫堡的内容字段：`scene_battles`、`order_flags`、`reasons`、`offer_text`、`soft_hooks`、`battle_pool`、`debug_carry`）。
- 灰掉时的原因：「你和马赛没有交集：没拿到法利亚的半封信，也没见过莫雷尔或法老号」。
- 软挂钩（只改开局）：

| 主干旗标 | 伊夫堡分支里 |
|---|---|
| `t_dantes_letter` | 开场多一行旁白：唐泰斯身上那封信，是你在费拉约港亲手交给他的（人心 −3，唐泰斯信赖 +1） |
| `t_morrel_credit` | 莫雷尔记得土伦那年的担保：起手金币 +1 |
| `t_went_home` | 1814 年你回过马赛：第一章开局多揭开两个节点 |
| `faria_half_letter` | 第二章「拼上那半封信」可选（藏宝的位置） |

- 携带：用 ARCH §1.6 的通用规则。物品里 `elba_watch`、`faria_half` 随书携带；`emperor_letter` 由分岔抉择发出。
- 调试入口：`game.new {{"campaign":"napoleon","segment":"cristo","stage":N}}`，`debug_carry.cristo.stage_overrides` 给出第 2—5 章的标准旗标与名册（例如第 3 章：法利亚活着、唐泰斯出狱、雅科波入队）。

## 2 章节结构

{ch_table}

**节奏**（ARCH §2.8）：每章「积累（剧情锚点之间自由走图）→ 集结 → 军议 → 精英（可绕）→ 野营 → Boss」；两场会战从不相邻；第一、二章各有一场带仗的锚点（第二章莫尔吉乌是剧情战，不能绕）。幕间插曲五章各不相同：营火夜话 → 破译（法利亚的衬衫书）→ 野营夜 → 伯爵召见 → 过秤（唐格拉尔的金库）。

**为什么是这五章**：任务书给的五段（马赛 / 伊夫堡 / 宝藏与出逃 / 地中海 / 巴黎复仇）里，出逃放在第二章末尾当 Boss：伊夫堡岁月的高潮就是那一夜，而宝藏是出逃之后的事。卡德鲁斯的客栈和莫雷尔获救（1829 年 6 月、9 月）挪到第四章开头，和九年后的罗马串成「伯爵布网」的一章。约阿尼纳（1822 年）按原著时间放进第二章，做成可选的远航节点：主角作为卖火药的承包商亲眼看见费尔南献城——这是第五章贵族院的证据来源。

## 3 世界地图

{map_table}

自检通过的规则：R1（每条通往 Boss 的路上都有营地和补给 / 商贩）、R2（战斗类节点不相邻，含带仗的锚点和可能出仗的随机槽）、R3（随机槽 ≥ 30%，期望事件 ≥ 3）、R4（精英可绕）、R5（集结 → 军议相邻；Boss 前一格是战役段营地）、R6（相邻章幕间不同）、R7（天数上限 ≥ 最短天数 + 3；按每天 3 MP、航程按天数算）。另查：锚点顺序 = `scene_ids`，Boss 是最后一场；所有节点从起点可达；随机槽与对手遭遇的等级 = 本章遭遇战等级。

设计要点：
- **马赛 1815**：旧港在中间，四个锚点（码头 → 雷瑟夫酒家 → 大库尔街 → 梅朗林荫道）分在港口两岸和城东，逼着玩家绕港一圈；渡口有路费，宪兵巡逻队在城东来回走。6 月战役段从勒潘尼耶集结，军议在圣洛朗教堂，可绕的精英是夜里坐船去加泰罗尼亚人的海湾抢运军费。
- **伊夫堡岁月**：一张图跨十三年（`years.marks` 让顶栏显示年份刻度）。左半边是要塞（典狱长办公室、地牢厨房、27 号），右半边是海岸（面包码头、莫雷尔家、面包房的地窖——在这里「工程」= 给地道送工具、莫尔吉乌、卡西斯）。去约阿尼纳要 6 天航程，来回 12 天，换来卖身契和海黛：这是天数预算里的真取舍。
- **基督山 1829**：从蒂布朗岛出发，沿利古里亚海岸到里窝那，再穿过托斯卡纳群岛到基督山岛；热那亚帮的三桅船在卡普拉亚和戈尔戈纳之间巡逻。
- **地中海 1829—1838**：加尔桥 → 马赛（9 月 5 日）→ 热那亚 / 里窝那 → 罗马；君士坦丁堡（买下海黛）在 7 天航程以外。罗马城里六个战役节点相距不到 0.06 度，所以加了 `rome_city` frame。
- **巴黎 1838**：西边香榭丽舍和奥特伊，北边唐格拉尔的银行和蒙莫朗西电报站，南边卢森堡宫，正中西岱岛是终场。

### 3.1 节点表

{node_tables}

## 4 固定结局

{end_table}

- 终场 `c_trial` 是 Boss 战（司法宫之夜）之后的三选一：守住证人让他说完（清算）、在他开口之前带他出国（保姓）、让伯爵停手（慈悲，需要 `m_valentine_saved`）。
- 慈悲要 `m_valentine_saved`：第五章「努瓦蒂埃的眼睛」事件里用法利亚的红药水（法利亚必须活着）或伯爵的假死药（唐泰斯必须活着）。
- 失败结局沿用 bankruptcy / loss / blockade 三个 id，文字由 `rules.failure_text` 给出（伊夫堡口吻：追缉 100 = 检察署的马车来接你，这一次登记簿上写的是你的名字）。
- 段专属大命运 `m_cell_35`：被宪兵逮捕（`arrest` 标签）时可选「关进伊夫堡 35 号」：一年后由莫雷尔担保放出，体力 −20、人心 −8、追缉 −40，地道 +15（你在里面认得路）。

## 5 伙伴、羁绊、一条命

{comp_table}

名羁绊（成对，信赖 1—3；内核还没有，先当数据写着，同鹰飞草稿）：

{pair_table}

阵营（加进 `bond_set_napoleon`）：

{faction_table}

- **一条命的戏**：第二章 Boss 战里唐泰斯从第 9 回合起才能上（他从麻袋里出来），法利亚只有救下来才在；第三章宿命之地是基督山岛的藏宝洞（法利亚）、蒂布朗岛（雅科波）；第五章奥特伊之夜是卡德鲁斯和贝尔图乔的宿命之地（原著里卡德鲁斯死在贝内代托手里）；终场司法宫是海黛、马克西米利安、阿尔贝的宿命之地。该不该把海黛带上终场，是这条分支最难的一道题。
- **提议给 A 的小字段**：`bonds_by_segment`（同一人在不同段属于不同阵营）、`available_from`（第二章唐泰斯和法利亚在牢里：名册里有，只能在 `if_corridors` 第 9 回合起上阵）。A 不采纳时的退路写在 `companions_cristo.json` 的 `_doc` 里。

## 6 敌军（ENEMIES 形状，L1 基线）

{enemy_table}

内核要认识的标签全部来自 ARCH §5（arrest、stealth、ambush、ransom、post、boat、short、sniper、boarder、loot、heavy、hunter、officer、execute、skirmisher）；本分支没有发明新标签。

## 7 战斗

### 7.1 这条分支怎样还是「排兵布阵」

伊夫堡分支里没有大会战，但每一场仍然是 Battle v2 的部署塔防：我方从左边（鹰旗一侧）往格子里放人、定朝向、管阻挡，敌人沿固定路线一波一波压过来。复杂度来自地形，不来自兵多：
- **街巷与房屋**（`S` `B` `R`）：房屋我方能进、敌人不进、挡视线；屋顶只有猎兵类能上、射程 +1。于是马赛的街战是「抢房子、封街口、用屋顶打头目」。
- **牢廊与牢门**（`C` `L` `D`）：牢廊是暗的（射程 −1），牢门是出生格，打死典狱长就把门锁成墙（`on_kill`）。伊夫堡之夜因此有一个明确的中盘目标：先打典狱长。
- **海与浅水、洞穴**（`W` `-` `c` `p`）：敌人从跳板接舷，缉私快艇在海格上开炮（`short`：只打列差 ≤ 4），洞穴挡视线、敌炮不瞄准。走私湾的解法是「洞口当堡垒」。
- **虚空**（`_`）：塌掉的路基、悬崖外的海，射程跳过，冲锋到此停。
- **命令**：除了内核已有的 hold / no_leak，本稿提议三种（都带 `order_fallback` 退回已有类型）：`escape`（指定伙伴某回合站到出口）、`extract`（某格累计站满 N 回合：搬箱子、找人）、`protect`（指定伙伴或 NPC 不倒下）。

### 7.2 已画好的 6 张

验证方法：`tools/battle_sim.py` 是 `battle_rules.gd` 的简化 Python 版（加上 ARCH §3/§4 的等级表、地形表、步耗、视线、顶层、黑暗、天时和新标签），比真人弱：军令牌只自动打「征发、齐射、刺刀、号手、皇帝的命令」，没有佯攻 / 弹幕 / 后撤，没有方阵和撤退。「什么都不做」和「只放主角」两项按 ARCH A4 不打牌、不放技能（被动）；「只放主角」对每一个能站的格子、四个朝向都试一遍，取最好的结果。三项同时成立才算「可解且不白给」。

{tpl_blocks}

### 7.3 规划中的 8 张（B2 画）

{planned_table}

规格细节（地形字符、命令、波次思路）在 `battle_templates_cristo.json.planned`。战力目标按 A5（相邻章 Boss ≥ ×1.12）倒推。

## 8 剧情

### 8.1 第一章全文（VN 可直接用；背景与立绘位见 `vn_cast_cristo.json`）

{vn_ch1}

### 8.2 第二到五章（第二章可直接用，第三到五章是提纲，抉择形状已定）

{outline}

### 8.3 随机事件、军议、幕间

{ev_table}

- 随机池：章池（`marseille`、`if_years`）和段池（`cristo`，任何一章都能抽到）。`fixed` 是挂在固定节点上的（军议、约阿尼纳、君士坦丁堡、电报站），`interlude:*` 是章与章之间的幕间。
- 事件里没有 `branch`、`ending`、`advance`（自检）。

## 9 美术

共 {n_art} 项（{art_count}）。新背景 31 张（每个场景一张，事件共用几张）、地图背景 3 张（`map_marseille_1815` 新增；`map_if_fortress`、`map_paris` 是 ARCH 已列的 id，这里补画面说明）、结局 CG 4 张、新立绘与头像各 21 人、旧立绘的年代变体 5 个（年轻的唐泰斯、囚徒唐泰斯、囚徒法利亚、1815 年的莫雷尔与主角）、战场小人 8 个伙伴 + 31 个敌人。

## 10 待拍板 / 风险

1. **主角不坐牢**是本稿最大的选择。替代方案：让主角也进伊夫堡（35 号，和唐泰斯隔一堵墙），第二章变成「牢中岁月」局部图（ARCH §9.6 的提议）。本稿把它保留成大命运 `m_cell_35`：输了第一章的仗会进去一年。
2. **法利亚活下来**偏离原著。它只在玩家主动选了药才发生，而且把「宝藏」换成了「人」（第二章三选一），代价清楚。
3. **主干最后一场 L12 与分支第一章遭遇战 L12** 的读法与鹰飞草稿一致；A 若坚持 ARCH 原文（分支第一场 ≥ L13），本分支所有等级整体 +1（第一章 Boss L15），模板不用改（通用遭遇战有补兵）。
4. **三种新命令**（escape / extract / protect）需要 B 在内核里加；没加之前退回 hold / no_leak，战斗照样能打。
5. **第三到五章的模板**还没画；第一、二章 + 通用遭遇战已经够一个完整的「马赛 → 出逃」试玩切片。
6. 第五章的贵族院、电报、审判是原著最出名的桥段，本稿只给了提纲；正文要等主创确认语气（原著的复仇很冷，本作的主角是旁观者也是同谋）。

## 11 文件

统计：{counts}

{files}

工具（可重跑）：`tools/build_cristo.py`（生成 + 自检 + 模拟 + 预览图）、`tools/build_doc.py`（本文）、`tools/battle_sim.py` / `battle_lib.py`（模拟器与校验器）、`tools/cristo_*.py`（数据源）。
"""

if __name__ == "__main__":
    main()
