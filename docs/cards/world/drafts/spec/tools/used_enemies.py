import json, sys, collections
W = sys.argv[1]
L = lambda f: json.load(open(f))
tpl = {}
for k, v in L(W + "/conquest/data/campaigns/battle_templates_conquest.json")["templates"].items(): tpl[k] = v
for f in [W + "/ocean/ocean_battles.json", W + "/cristo/data/campaigns/battle_templates_cristo.json"]:
    for k, v in L(f)["templates"].items(): tpl[k] = v.get("template", v)
r1 = ["toulon_night","montenotte","lodi_bridge","arcole_dikes","rivoli_plateau","la_favorita","skirmish_terraces","skirmish_mill_ford","skirmish_hamlet",
      "charleroi_bridge","ligny","quatre_bras","waterloo","skirmish_brabant_farm","skirmish_sunken_lane",
      "bellerophon_deck","jamestown_streets","sea_cave","deadwood_camp","longwood_escape","shipwreck_beach","viper_boarding","skull_reef","atlantis","squid_platform","thames_estuary","signal_hill","beach_landing","reef_crossing","ice_shelf","nautilus_deck_raid","vigo_seabed",
      "catalans_cove","marseille_arrest","morgiou_cove","if_corridors","alley_ambush","coast_road"]
used = collections.Counter(); chars = collections.Counter()
for t in r1:
    x = tpl[t]
    for w in x["waves"]:
        for opt in [w["units"]] + w.get("alt", []):
            for u in opt:
                used[u["kind"] if isinstance(u, dict) else u] += 1
    if x.get("pad"): used[x["pad"]["kind"]] += 1
    for row in x["map"]: chars.update(row)
en = L(W + "/spec/data/enemies_final.json")["enemies"]
print(len(r1), "templates; enemy kinds used:", len(used))
print("unused merged kinds:", sorted(k for k in en if k not in used))
print("terrain chars used in round-1 built templates:", "".join(sorted(chars)))
