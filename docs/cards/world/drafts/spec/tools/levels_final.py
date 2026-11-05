# Writes spec/data/levels_final.json: per-segment chapter level plan (absolute L) + boss power targets, and checks the rules.
import json, sys
W = sys.argv[1]
plan = {
 "trunk": [
  {"chapter": "toulon", "boss": ["toulon_night", 1], "elite": [], "battle_max": None, "power": 58, "tutorial": True},
  {"chapter": "italy", "boss": ["rivoli_plateau", 3], "elite": [["lodi_bridge", 2], ["arcole_dikes", 2], ["la_favorita", 2]], "battle_max": 1, "power": 111},
  {"chapter": "orient_alps", "boss": ["acre", 5], "elite": [["pyramids", 4]], "battle_max": 3, "power": 150, "vol1_theatre": "t_orient"},
  {"chapter": "austerlitz_jena", "boss": ["austerlitz", 7], "elite": [["ulm", 6]], "battle_max": 5, "power": 172, "vol1_theatre": "t_austerlitz"},
  {"chapter": "iberia_danube", "boss": ["saragossa", 9], "elite": [["somosierra", 8]], "battle_max": 7, "power": 200, "vol1_theatre": "t_spain"},
  {"chapter": "russia", "boss": ["berezina", 10], "elite": [["borodino", 9], ["krasnoi", 9]], "battle_max": 8, "power": 228},
  {"chapter": "collapse", "boss": ["leipzig", 11], "elite": [["dresden", 10], ["hanau", 10]], "battle_max": 9, "power": 262},
  {"chapter": "elba", "boss": ["elba_cove", 12], "elite": [], "battle_max": 10, "power": 300, "power_max": 359},
 ],
 "conquest": [
  {"chapter": "hundred_days", "boss": ["waterloo", 14], "elite": [["ligny", 13], ["quatre_bras", 13]], "battle_max": 12, "anchor_battles": [["charleroi_bridge", 12]], "power": 524},
  {"chapter": "rhine", "boss": ["rhine_crossing", 16], "elite": [["brussels", 15]], "battle_max": 14, "power": 590, "volume": 2},
  {"chapter": "vienna", "boss": ["vienna_streets", 18], "elite": [], "battle_max": 16, "power": 665, "volume": 2},
  {"chapter": "iberia_channel", "boss": ["iberia_return|channel_landing", 20], "elite": [], "battle_max": 18, "power": 750, "volume": 2},
  {"chapter": "niemen", "boss": ["niemen", 22], "elite": [], "battle_max": 20, "power": 845, "volume": 2},
  {"chapter": "last_coalition", "boss": ["coalition_final", 24], "elite": [], "battle_max": 22, "power": 950, "volume": 2},
 ],
 "ocean": [
  {"chapter": "prologue", "boss": ["bellerophon_deck", 13], "elite": [], "battle_max": None, "power": 403},
  {"chapter": "st_helena", "boss": ["longwood_escape", 16], "elite": [["sea_cave", 15], ["deadwood_camp", 15]], "battle_max": 14, "anchor_battles": [["jamestown_streets", 14]], "power": 658},
  {"chapter": "new_elba", "boss": ["skull_reef", 20], "elite": [["viper_boarding", 19]], "battle_max": 18, "anchor_battles": [["shipwreck_beach", 17]], "power": 898},
  {"chapter": "nautilus", "boss": ["thames_estuary", 24], "elite": [["vigo_seabed", 22], ["squid_platform", 23]], "battle_max": 22, "anchor_battles": [["atlantis", 22], ["ice_shelf", 21]], "power": 1432},
 ],
 "cristo": [
  {"chapter": "marseille", "boss": ["marseille_arrest", 14], "elite": [["catalans_cove", 13]], "battle_max": 12, "power": 530},
  {"chapter": "if_years", "boss": ["if_corridors", 16], "elite": [["morgiou_cove", 15], ["janina_lake", 15]], "battle_max": 14, "power": 631},
  {"chapter": "montecristo", "boss": ["monte_cristo_cave", 18], "elite": [["tiboulen_swim", 17]], "battle_max": 16, "power": 710, "volume": 2},
  {"chapter": "mediterranean", "boss": ["san_sebastiano", 21], "elite": [["appian_way", 20]], "battle_max": 19, "power": 830, "volume": 2},
  {"chapter": "paris_1838", "boss": ["cristo_final", 24], "elite": [["auteuil_garden", 22], ["paris_rooftops", 23]], "battle_max": 22, "power": 960, "volume": 2},
 ],
}
err = []
floor = plan["trunk"][-1]["boss"][1]
for seg, chs in plan.items():
    prev = None; prevp = None
    if seg != "trunk":
        prev = floor; prevp = plan["trunk"][-1]["power"]
    for c in chs:
        b = c["boss"][1]
        if prev is not None and b <= prev: err.append("%s %s boss %d not > %d" % (seg, c["chapter"], b, prev))
        if prevp is not None and c["power"] * 100 < prevp * 112: err.append("%s %s power %d < 1.12*%d" % (seg, c["chapter"], c["power"], prevp))
        for t, l in c["elite"]:
            if l > b - 1: err.append("%s elite %s %d > boss-1" % (seg, t, l))
            if seg != "trunk" and l < floor: err.append("%s elite %s below floor" % (seg, t))
        for t, l in c.get("anchor_battles", []):
            if l > b - 2: err.append("%s battle %s %d > boss-2" % (seg, t, l))
            if seg != "trunk" and l < floor: err.append("%s battle %s below floor" % (seg, t))
        if c["battle_max"] is not None and c["battle_max"] > b - 2: err.append("%s %s battle_max" % (seg, c["chapter"]))
        if seg != "trunk" and c["battle_max"] is not None and c["battle_max"] < floor: err.append("%s %s battle_max below floor" % (seg, c["chapter"]))
        prev = b; prevp = c["power"]
print("errors:", err or "none")
json.dump({"_doc": "合成稿定稿：各段各章的绝对等级 L 与 Boss 推荐战力目标（ARCH §3.4 公式）。power 已建模板为实测值，未建为目标；硬约束是 A5（相邻 Boss ×1.12）与 elba_cove ≤ 359。volume=2 的章不在第一卷。", "branch_floor": floor, "plan": plan}, open(W + "/spec/data/levels_final.json", "w"), ensure_ascii=False, indent=1)
