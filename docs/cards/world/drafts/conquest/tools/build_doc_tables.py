#!/usr/bin/env python3
"""Fills the generated appendix of CONQUEST.md (between the TABLES markers) from the map and segment JSON.
Run after the builders:  python3 -I tools/build_doc_tables.py"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NAP = os.path.join(ROOT, "data", "campaigns", "napoleon")
DOC = os.path.join(ROOT, "CONQUEST.md")
SB = json.load(open(os.path.join(NAP, "book_conquest_patch.json"), encoding="utf-8"))["scene_battles"]
SB = {**SB["trunk"], **SB["conquest"]}
TYPE = {"story": "剧情", "battle": "遭遇战", "elite": "精英", "boss": "Boss", "event": "事件", "camp": "营地", "supply": "补给",
        "shop": "商贩", "branch": "分岔", "slot": "随机槽"}
ROLE = {"post": "驿站", "muster": "开拔", "port": "港口", "intel": "密探", "project": "工程", "council": "军议"}

def node_row(n):
    t = TYPE[n["type"]] + ("·" + ROLE[n["role"]] if n.get("role") else "")
    extra = []
    if n.get("scene"):
        extra.append("场景 `%s`" % n["scene"])
        if n["scene"] in SB: extra.append("%s L%d" % (SB[n["scene"]]["template"], SB[n["scene"]]["level"]))
    if n.get("template"): extra.append("%s L%d" % (n["template"], n["level"]))
    if n.get("event"): extra.append("事件 `%s`" % n["event"])
    if n["type"] == "slot":
        k = n["slot"]["kinds"]
        extra.append("池 %s：%s" % (n["slot"]["pool"], " ".join("%s%d" % (TYPE.get(a, a), b) for a, b in k.items())) + (" L%d" % n["slot"]["level"] if "level" in n["slot"] else ""))
    if n.get("requires"): extra.append("需 " + json.dumps(n["requires"], ensure_ascii=False))
    if n.get("weather"): extra.append("天时 " + "/".join(n["weather"]))
    ph = "战役" if n.get("phase") == "campaign" else "积累"
    return "| `%s` | %s | %s | %s | %s | %s |" % (n["id"], n["label"], t, ph, n.get("date", ""), "；".join(extra))

def sheet_block(s):
    out = ["#### %s（%d 个节点，days_max %d，驿站印 %d，插曲 %s）" % (s["chapter"], len(s["nodes"]), s["days_max"], s["stamps_need"], s.get("interlude") or "—"),
           "", "镜头：" + "、".join("`%s`%s" % (f["id"], "（%s）" % json.dumps(f["when"], ensure_ascii=False) if f.get("when") else "（默认）") for f in s["frames"]), "",
           "| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |", "|---|---|---|---|---|---|"]
    out += [node_row(n) for n in s["nodes"]]
    links = []
    for l in s["links"]:
        k = "航 %d 天" % l["voyage_days"] if l.get("voyage_days") else "%d" % l["legs"]
        tags = []
        for key, name in (("supply", "军需"), ("toll", "过路费"), ("route", "岔路"), ("rush", "急行"), ("requires", "需")):
            if key in l: tags.append("%s %s" % (name, json.dumps(l[key], ensure_ascii=False) if not isinstance(l[key], (int, bool)) else l[key]))
        links.append("%s–%s %s%s" % (l["a"], l["b"], k, "（" + "，".join(tags) + "）" if tags else ""))
    out += ["", "连线：" + "；".join(links)]
    if s.get("rivals"):
        out += ["", "对手：" + "；".join("%s（%s，路线 %s%s）" % (r["label"], r["id"], "→".join(r["path"]),
                 "，遭遇 %s L%d" % (r["meet"]["battle"]["template"], r["meet"]["battle"]["level"]) if r.get("meet", {}).get("battle") else "") for r in s["rivals"])]
    if s.get("sets"):
        out += ["", "兵站套：" + "；".join("%s = %s" % (x["id"], "+".join(x["nodes"])) for x in s["sets"])]
    return "\n".join(out) + "\n"

def main():
    parts = []
    for fn, title in (("europe.json", "主干 `maps/europe.json`"), ("europe_late.json", "鹰飞 `maps/europe_late.json`")):
        m = json.load(open(os.path.join(NAP, "maps", fn), encoding="utf-8"))
        parts.append("### %s\n" % title)
        for s in m["sheets"]:
            parts.append(sheet_block(s))
    doc = open(DOC, encoding="utf-8").read()
    a, b = "<!-- TABLES:BEGIN -->", "<!-- TABLES:END -->"
    i, j = doc.index(a) + len(a), doc.index(b)
    doc = doc[:i] + "\n\n" + "\n".join(parts) + "\n" + doc[j:]
    open(DOC, "w", encoding="utf-8").write(doc)
    print("tables:", sum(p.count("\n| `") for p in parts), "node rows")

if __name__ == "__main__":
    main()
