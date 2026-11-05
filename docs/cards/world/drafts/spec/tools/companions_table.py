import json, sys
W = sys.argv[1]; R = sys.argv[2]
L = lambda f: json.load(open(f))
cq = L(W + "/conquest/data/campaigns/napoleon/companions_conquest.json")["companions"]
cr = L(W + "/cristo/data/campaigns/napoleon/companions_cristo.json")
ob = L(R + "/data/campaigns/ocean_battle.json")["companions"]
CLS = {"line": "战列", "grenadier": "掷弹", "jager": "猎兵", "hussar": "骠骑", "artillery": "炮兵", "medic": "军医", "engineer": "工兵", "drummer": "鼓手"}
rows = []
def segs_of(i, base):
    s = list(base)
    if i in ("dantes", "faria", "morel"): s = sorted(set(s) | {"ocean", "cristo"})
    if i in ("gourgaud", "marie", "corso", "baptiste"): s = sorted(set(s) | {"ocean"})
    if i in ("baptiste", "corso", "marie"): s = sorted(set(s) | {"cristo"})
    return s
seen = set()
for i, c in cq.items():
    b = c["battle"] if isinstance(c.get("battle"), dict) else ob.get(i, {})
    if i in ob:
        o = ob[i]
        same = all(o[k] == b[k] for k in ("cls", "hp", "atk", "def", "block", "cost"))
        if not same: print("STAT DIFF", i, b, o)
    rows.append((i, c.get("name", i), b, segs_of(i, c.get("segments", [])), "主干/鹰飞稿"))
    seen.add(i)
for i in ("friday", "nemo", "morel"):
    rows.append((i, ob[i]["short"], ob[i], segs_of(i, ["ocean"]), "远洋（现有）"))
    seen.add(i)
crc = cr["companions"]
for i, c in crc.items():
    if i in seen: continue
    rows.append((i, c.get("name", i), c["battle"], c.get("segments", ["cristo"]), "伊夫堡稿"))
md = ["| id | 名字 | 兵种 | 兵力/攻/防/阻挡 | 费 | 可出现的段 | 来源 |", "|---|---|---|---|---|---|---|"]
for i, n, b, s, src in rows:
    md.append("| `%s` | %s | %s | %d/%d/%d/%d | %d | %s | %s |" % (i, n, CLS[b["cls"]], b["hp"], b["atk"], b["def"], b["block"], b["cost"], "、".join(s), src))
open(W + "/spec/data/companions_table.md", "w").write("\n".join(md) + "\n")
print(len(rows), "companions")
