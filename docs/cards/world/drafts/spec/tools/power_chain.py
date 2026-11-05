# Cross-package boss power chain using cristo's battle_lib.counts (ARCH §3.4 formula).
import json, sys, importlib.util
W = sys.argv[1]
spec = importlib.util.spec_from_file_location("battle_lib", W + "/cristo/tools/battle_lib.py")
bl = importlib.util.module_from_spec(spec); spec.loader.exec_module(bl)
L = lambda f: json.load(open(f))
en = {}
for src in [L(W + "/conquest/data/campaigns/napoleon/enemies_trunk_conquest.json")["enemies"],
            L(W + "/ocean/ocean_battles.json")["enemies"],
            L(W + "/cristo/data/campaigns/battle_templates_cristo.json")["enemies"]]:
    it = src.items() if isinstance(src, dict) else [(e["id"], e) for e in src]
    for k, e in it:
        en[k] = e
tpl = {}
for k, v in L(W + "/conquest/data/campaigns/battle_templates_conquest.json")["templates"].items():
    tpl[k] = v
for f in [W + "/ocean/ocean_battles.json", W + "/cristo/data/campaigns/battle_templates_cristo.json"]:
    for k, v in L(f)["templates"].items():
        tpl[k] = v.get("template", v)
def P(t, lv):
    x = tpl[t]
    if "base_level" not in x:
        x = dict(x); x["base_level"] = lv
    return bl.counts(x, en, lv)
chains = {
  "trunk(built)": [("toulon_night", 1), ("rivoli_plateau", 3)],
  "conquest ch1": [("charleroi_bridge", 12), ("ligny", 13), ("quatre_bras", 13), ("waterloo", 14)],
  "ocean": [("bellerophon_deck", 13), ("longwood_escape", 16), ("skull_reef", 20), ("thames_estuary", 24)],
  "cristo": [("marseille_arrest", 14), ("if_corridors", 16)],
  "cristo ch1 other": [("catalans_cove", 13), ("alley_ambush", 12), ("coast_road", 12), ("morgiou_cove", 15)],
}
for name, ch in chains.items():
    out = []
    for t, lv in ch:
        c = P(t, lv); out.append("%s@L%d power=%d n=%d hunters=%d elites=%d" % (t, lv, c["power"], c["enemies"], c["hunters"], c["elites"]))
    print(name); [print("   ", o) for o in out]
