# Merge enemy and companion rosters from the three content drafts; emit spec/data/*.json and markdown tables.
import json, sys, collections
W = sys.argv[1]; R = sys.argv[2]
L = lambda f: json.load(open(f))
out = W + "/spec/data"
import os; os.makedirs(out, exist_ok=True)
base = {  # existing battle_rules.gd ENEMIES (repo)
 "whitecoat": ("白衣步兵", 6, 3, 1, 1, "infantry", 0, []), "grenz": ("格伦茨猎兵", 5, 3, 0, 1, "infantry", 2, []),
 "dragoon": ("龙骑兵", 10, 5, 1, 2, "cavalry", 0, ["hunter"]), "hungarian": ("匈牙利掷弹兵", 12, 4, 2, 1, "elite", 0, ["heavy"]),
 "leader": ("纵队长", 10, 3, 2, 1, "leader", 0, ["officer"]), "wagon": ("弹药车", 4, 0, 0, 1, "wagon", 0, []),
 "gun": ("奥军炮", 8, 6, 1, 0, "gun", 99, [])}
srcs = [("trunk/conquest", L(W + "/conquest/data/campaigns/napoleon/enemies_trunk_conquest.json")["enemies"]),
        ("ocean", L(W + "/ocean/ocean_battles.json")["enemies"]),
        ("cristo", L(W + "/cristo/data/campaigns/battle_templates_cristo.json")["enemies"])]
arch_ids = set("mamluk janissary nizam bedouin bey ottoman_gun redcoat rifleman highlander foot_guards scots_grey rocket british_gun brigadier ru_line ru_grenadier ru_jaeger cossack cuirassier opolchenie ru_gun ru_general landwehr fusilier uhlan pr_grenadier pr_gun pr_general guerrillero bandolero es_lancer es_regular partisan_chief marine sailor marine_sharpshooter boatswain pirate pirate_captain coast_gun carronade gunboat raider_captain gendarme mounted_gendarme prison_guard turnkey_chief customs smuggler bandit bandit_marksman vampa assassin benedetto national_guard".split())
merged = collections.OrderedDict(); used_by = collections.defaultdict(set)
for name, s in srcs:
    it = s.items() if isinstance(s, dict) else [(e["id"], e) for e in s]
    for k, e in it:
        used_by[k].add(name.split("/")[0] if name != "trunk/conquest" else "trunk/conquest")
        if k in merged: continue
        row = {"name": e["name"], "hp": e["hp"], "atk": e["atk"], "def": e["def"], "spd": e["spd"], "type": e["type"], "range": e["range"], "tags": list(e.get("tags", []))}
        if e.get("at_terrain"): row["at_terrain"] = list(e["at_terrain"])
        if e.get("move"): row["move"] = e["move"]
        merged[k] = row
# origin classification
def origin(k):
    if k in base: return "现有"
    if k in arch_ids: return "ARCH"
    return "新增(" + "/".join(sorted(used_by[k])) + ")"
# conflicts check
for name, s in srcs:
    it = s.items() if isinstance(s, dict) else [(e["id"], e) for e in s]
    for k, e in it:
        m = merged[k]
        for f in ("hp", "atk", "def", "spd", "type", "range"):
            if m[f] != e[f]: print("CONFLICT", k, f, m[f], e[f])
        if sorted(m["tags"]) != sorted(e.get("tags", [])): print("TAGCONFLICT", k, m["tags"], e.get("tags"))
        if k in base:
            b = base[k]
            if (b[1], b[2], b[3], b[4], b[5], b[6]) != (e["hp"], e["atk"], e["def"], e["spd"], e["type"], e["range"]): print("BASE CONFLICT", k)
groups = [
 ("奥军与意大利战区（第一幕；前 7 种是现有的）", ["whitecoat", "grenz", "dragoon", "hungarian", "leader", "wagon", "gun", "piedmontese", "barbet", "tyrolean", "chevauleger"]),
 ("奥斯曼与马穆鲁克", ["mamluk", "janissary", "nizam", "bedouin", "bey", "ottoman_gun"]),
 ("英军", ["redcoat", "rifleman", "highlander", "foot_guards", "scots_grey", "rocket", "british_gun", "brigadier", "redcoat_grenadier", "mounted_orderly", "navy_captain", "rocket_boat", "steam_sloop", "dutch_belgian", "brunswicker"]),
 ("俄军", ["ru_line", "ru_grenadier", "ru_jaeger", "cossack", "cuirassier", "opolchenie", "ru_gun", "ru_general"]),
 ("普军", ["landwehr", "fusilier", "uhlan", "pr_grenadier", "pr_gun", "pr_general", "blucher"]),
 ("西班牙", ["guerrillero", "bandolero", "es_lancer", "es_regular", "partisan_chief"]),
 ("海上（远洋）", ["marine", "sailor", "marine_sharpshooter", "boatswain", "pirate", "pirate_brute", "pirate_captain", "coast_gun", "coast_sniper", "carronade", "gunboat", "raider_captain"]),
 ("1815 保王党与圣赫勒拿", ["royalist_bravo", "royalist_marksman", "royalist_chief", "chouan", "verdet", "bow_runner", "jack_runner"]),
 ("深海与南极（远洋）", ["diver", "harpoon_diver", "smith_agent", "shark", "great_shark", "squid", "squid_arm", "sealer", "harpooner", "sealer_boss"]),
 ("伊夫堡：马赛与牢狱", ["gendarme", "mounted_gendarme", "national_guard", "ng_grenadier", "prison_guard", "turnkey_chief", "if_soldier", "if_veteran", "wall_sentry", "fort_gun", "customs", "customs_officer", "revenue_cutter", "smuggler", "rival_smuggler_boss", "thug", "thug_marksman", "thug_boss"]),
 ("伊夫堡：罗马、东方与巴黎", ["bandit", "bandit_marksman", "vampa", "papal_carabinier", "papal_dragoon", "sbirro", "arnaut", "assassin", "benedetto", "municipal_guard", "convict", "police_agent"]),
]
listed = set(sum([g[1] for g in groups], []))
missing = [k for k in merged if k not in listed]
extra = [k for k in listed if k not in merged]
print("merged", len(merged), "missing from groups", missing, "listed-not-merged", extra)
TN = {"infantry": "步兵", "cavalry": "骑兵", "elite": "精英", "leader": "纵队长", "wagon": "辎重", "gun": "炮"}
md = []
for title, ids in groups:
    md.append("\n**%s**\n\n| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |\n|---|---|---|---|---|---|---|---|" % title)
    for k in ids:
        if k not in merged: continue
        m = merged[k]
        md.append("| `%s` | %s | %d/%d/%d/%d | %s | %s | %s | %s | %s |" % (k, m["name"], m["hp"], m["atk"], m["def"], m["spd"], TN[m["type"]], ("—" if m["range"] == 0 else ("炮" if m["range"] == 99 else str(m["range"]))), "、".join(m["tags"]) or "—", "、".join(m.get("at_terrain", [])) or "—", origin(k)))
open(out + "/enemies_table.md", "w").write("\n".join(md) + "\n")
json.dump({"_doc": "合成稿定稿的敌军名册（L1 基线，运行时按 LEVELS 缩放）。B 照抄进 battle_rules.gd 的 ENEMIES；现有 7 种字节不变。", "enemies": merged}, open(out + "/enemies_final.json", "w"), ensure_ascii=False, indent=1)
print("types", collections.Counter(m["type"] for m in merged.values()))
print("origin", collections.Counter(origin(k).split("(")[0] for k in merged))
