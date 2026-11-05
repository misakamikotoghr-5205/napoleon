## 测试用的简单确定性打法（test_ui.gd 用它决定按哪个界面控件）。只看公开查询（campaign.battle2 的 view，
## campaign.battle_preview），一次给出一步：抬下濒死的伙伴 → 能放的技能 → 后方调度 → 征发 → 部署（威胁最大的路线先放
## 阻挡，再放炮兵、猎兵）→ 预演说会倒下的伙伴撤下来；什么都不做了就交火。同一个视图永远给同一步。没有 class_name。
## 能不能站某一格一律问规则内核的 can_stand（§8.5：40 种地形、顶层只给猎兵），不再自己列地形表。
extends RefCounted

const Rules = preload("res://scripts/cards/campaign/battle/battle_rules.gd")

const FACE := {[1, 0]: "right", [-1, 0]: "left", [0, -1]: "up", [0, 1]: "down"}
const DIRS := {"right": [1, 0], "left": [-1, 0], "up": [0, -1], "down": [0, 1]}
const LATERAL := {"right": [0, 1], "left": [0, -1], "up": [1, 0], "down": [-1, 0]}
const MELEE := ["grenadier", "line", "hussar", "engineer", "drummer"]
## 出征名单里部队的先后：顶线的先上
const TROOP_ORDER := ["grenadier", "line", "artillery", "jager", "hussar"]


## 出征名单：不带宿命之地的伙伴，伙伴排满上限，部队按 TROOP_ORDER 补满在场上限；主角留守
static func lineup(lu: Dictionary) -> Dictionary:
	var caps: Dictionary = lu.get("caps", {})
	var comps: Array = []
	for c in lu.get("candidates", []):
		if not bool(c.get("fated", false)) and comps.size() < int(caps.get("companions", 0)) and comps.size() < int(caps.get("field", 0)):
			comps.append(str(c["id"]))
	var troops: Array = []
	for cls in TROOP_ORDER:
		for tr in lu.get("troops", []):
			if str(tr["cls"]) == cls and comps.size() + troops.size() < int(caps.get("field", 0)):
				troops.append(str(tr["id"]))
	return {"companions": comps, "troops": troops, "protagonist": false}


static func next_action(v: Dictionary, pv: Dictionary) -> Array:
	var units: Array = v.get("battle_units", [])
	for u in units:
		if bool(u.get("can_carry", false)):
			return ["carry", {"unit": u["uid"]}]
	for u in units:
		if bool(u.get("skill_ready", false)):
			var a := _skill(v, u)
			if not a.is_empty():
				return a
	for b in v.get("deploy_bar", []):
		if bool(b.get("can_dispatch", false)):
			return ["skill", {"unit": b["uid"]}]
	for h in v.get("hand", []):
		if str(h["id"]) == "requisition" and bool(h["playable"]):
			return ["card", {"index": int(h["index"])}]
	var d := _deploy(v)
	if not d.is_empty():
		return d
	if bool(pv.get("ok", false)):
		for uid in pv.get("fallen", []):
			for u in units:
				if str(u["uid"]) == str(uid) and str(u["kind"]) == "companion" and bool(u.get("can_withdraw", false)):
					return ["withdraw", {"unit": uid}]
	return []


static func _cell(v: Dictionary, c: int, r: int) -> Dictionary:
	var g: Dictionary = v["grid"]
	if c < 0 or r < 0 or c >= int(g["cols"]) or r >= int(g["rows"]):
		return {}
	return g["cells"][r * int(g["cols"]) + c]


static func _occupied(v: Dictionary, c: int, r: int) -> bool:
	for u in v.get("battle_units", []):
		if int(u["col"]) == c and int(u["row"]) == r:
			return true
	for e in v.get("enemies", []):
		if int(e["col"]) == c and int(e["row"]) == r:
			return true
	return false


static func _skill(v: Dictionary, u: Dictionary) -> Array:
	match str(u["skill"]):
		"bayonet_charge":
			for e in v.get("enemies", []):
				if str(e["blocked_by"]) == str(u["uid"]):
					return ["skill", {"unit": u["uid"]}]
		"mark_target":
			var best: Array = []
			var best_hp := 999
			for pc in u["pattern"]:
				for e in v.get("enemies", []):
					if int(e["col"]) == int(pc[0]) and int(e["row"]) == int(pc[1]) and int(e["hp"]) < best_hp:
						best_hp = int(e["hp"])
						best = [int(pc[0]), int(pc[1])]
			if not best.is_empty():
				return ["skill", {"unit": u["uid"], "col": best[0], "row": best[1]}]
		"raise_flag":
			if not (v.get("enemies", []) as Array).is_empty():
				return ["skill", {"unit": u["uid"]}]
		"fortify":
			var f: Array = DIRS[str(u["facing"])]
			var c := int(u["col"]) + int(f[0])
			var r := int(u["row"]) + int(f[1])
			var cell := _cell(v, c, r)
			if not cell.is_empty() and Rules.can_stand("barricade", str(cell["terrain"])) and not bool(cell["reserved"]) and not _occupied(v, c, r):
				return ["skill", {"unit": u["uid"], "col": c, "row": r, "mode": "barricade"}]
	return []


static func _label(c: int, r: int) -> String:
	return "%s%d" % [char(65 + c), r + 1]


## 每条路线：现有敌人 + 两回合内要来的 − 已有阻挡；需要最多的排前面
static func _threat(v: Dictionary) -> Array:
	var out: Array = []
	for rt in v["grid"]["routes"]:
		var cells: Array = rt["cells"]
		var n := 0
		var nearest := 99
		for e in v.get("enemies", []):
			if str(e["type"]) == "gun":
				continue
			for i in range(cells.size()):
				if int(cells[i][0]) == int(e["col"]) and int(cells[i][1]) == int(e["row"]):
					n += 2 if "heavy" in e.get("battle_tags", []) else 1
					nearest = mini(nearest, cells.size() - 1 - i)
		for w in v.get("waves", []):
			if bool(w["known"]) and int(w["turn"]) <= int(v["turn"]) + 2:
				var gate: Array = cells[0]
				if _label(int(gate[0]), int(gate[1])) == str(w["label"]):
					n += (w["detail"] as Array).size()
		var block := 0
		for u in v.get("battle_units", []):
			if str(u["state"]) != "ok":
				continue
			for c in cells:
				if int(c[0]) == int(u["col"]) and int(c[1]) == int(u["row"]):
					block += int(u["block"])
		out.append({"route": rt, "need": n - block, "nearest": nearest, "n": n})
	out.sort_custom(func(a, b): return a["need"] > b["need"] or (a["need"] == b["need"] and a["nearest"] < b["nearest"]))
	return out


static func _deploy(v: Dictionary) -> Array:
	var bar: Array = []
	for b in v.get("deploy_bar", []):
		if bool(b["deployable"]) and str(b["kind"]) != "hero":
			bar.append(b)
	if bar.is_empty():
		return []
	var threats := _threat(v)
	if threats.is_empty():
		return []
	var top: Dictionary = threats[0]
	var have_enemies := false
	for t in threats:
		if int(t["n"]) > 0:
			have_enemies = true
	if have_enemies and int(top["need"]) > 0:
		for pref in [["grenadier"], ["line"], ["hussar"], ["engineer", "drummer"]]:
			for b in bar:
				if str(b["cls"]) in pref:
					var spot := _block_spot(v, top["route"], str(b["cls"]))
					if not spot.is_empty():
						return ["deploy", {"unit": b["uid"], "col": spot[0], "row": spot[1], "facing": spot[2]}]
	for cls in ["artillery", "jager"]:
		for b in bar:
			if str(b["cls"]) == cls:
				var spot2 := _ranged_spot(v, cls)
				if not spot2.is_empty():
					return ["deploy", {"unit": b["uid"], "col": spot2[0], "row": spot2[1], "facing": spot2[2]}]
	if have_enemies:
		for b in bar:
			if str(b["cls"]) in MELEE:
				var spot3 := _block_spot(v, top["route"], str(b["cls"]))
				if not spot3.is_empty():
					return ["deploy", {"unit": b["uid"], "col": spot3[0], "row": spot3[1], "facing": spot3[2]}]
	return []


## 路线上从鹰旗往外第一个这个兵种站得住的空格，朝向来敌
static func _block_spot(v: Dictionary, rt: Dictionary, cls: String) -> Array:
	var cells: Array = rt["cells"]
	for i in range(cells.size() - 2, 0, -1):
		var c := int(cells[i][0])
		var r := int(cells[i][1])
		var cell := _cell(v, c, r)
		if not Rules.can_stand(cls, str(cell["terrain"])) or bool(cell["reserved"]) or _occupied(v, c, r):
			continue
		var prev: Array = cells[i - 1]
		return [c, r, FACE.get([int(prev[0]) - c, int(prev[1]) - r], "right")]
	return []


static func _route_cells(v: Dictionary) -> Dictionary:
	var out := {}
	for rt in v["grid"]["routes"]:
		var cells: Array = rt["cells"]
		for i in range(1, cells.size() - 1):
			out[[int(cells[i][0]), int(cells[i][1])]] = cells.size() - 1 - i
	return out


static func _pattern(cls: String, c: int, r: int, facing: String, cols: int, rows: int) -> Array:
	var f: Array = DIRS[facing]
	var l: Array = LATERAL[facing]
	var spec: Array = []
	match cls:
		"line": spec = [[1, 0], [2, 0]]
		"jager": spec = [[1, 0], [2, 0], [3, 0]]
		"artillery":
			for dx in range(2, 6):
				for dy in [-1, 0, 1]:
					spec.append([dx, dy])
		_: spec = [[1, 0]]
	var out: Array = []
	for s in spec:
		var cc: int = c + int(f[0]) * int(s[0]) + int(l[0]) * int(s[1])
		var rr: int = r + int(f[1]) * int(s[0]) + int(l[1]) * int(s[1])
		if cc >= 0 and rr >= 0 and cc < cols and rr < rows:
			out.append([cc, rr])
	return out


static func _ranged_spot(v: Dictionary, cls: String) -> Array:
	var rc := _route_cells(v)
	var ec := {}
	for e in v.get("enemies", []):
		var k := [int(e["col"]), int(e["row"])]
		ec[k] = int(ec.get(k, 0)) + 1
	var cols := int(v["grid"]["cols"])
	var rows := int(v["grid"]["rows"])
	var best: Array = []
	var best_s := 0
	for cell in v["grid"]["cells"]:
		if not Rules.can_stand(cls, str(cell["terrain"])) or Rules.terrain_info(str(cell["terrain"]))["stand"] == "ground" or bool(cell["reserved"]):
			continue
		var c := int(cell["col"])
		var r := int(cell["row"])
		if _occupied(v, c, r):
			continue
		for facing in ["right", "down", "up", "left"]:
			var s := 0
			for pc in _pattern(cls, c, r, facing, cols, rows):
				if rc.has(pc):
					s += 10 + (8 - mini(8, int(rc[pc])))
				if ec.has(pc):
					s += 15 * int(ec[pc])
			if s > best_s:
				best_s = s
				best = [c, r, facing]
	return best
