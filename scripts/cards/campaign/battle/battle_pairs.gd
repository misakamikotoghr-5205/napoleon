## Named companion bonds. Optional, deterministic state; original battles omit it.
extends RefCounted

const MEMBERS := {"old_friends": ["baptiste", "marie"], "shield": ["muiron", "hero"],
	"rivals": ["lannes", "murat"], "last_square": ["cambronne", "ney"], "two_numbers": ["dantes", "faria"],
	"master_pupil": ["dantes", "faria"], "wait_and_hope": ["dantes", "haydee"], "enemy_name": ["bertuccio", "hero"],
	"old_neighbours": ["caderousse", "dantes"], "father_son": ["morel", "maximilien"], "two_children": ["albert", "haydee"]}


static func validate_setup(setup: Dictionary) -> Array:
	var errors: Array = []
	if setup.has("pairs"):
		if typeof(setup["pairs"]) != TYPE_ARRAY:
			return ["pairs must be an array"]
		var seen := {}
		for pair in setup["pairs"]:
			if typeof(pair) != TYPE_DICTIONARY:
				errors.append("pair must be an object")
				continue
			var id := str(pair.get("id", ""))
			if not MEMBERS.has(id) or seen.has(id):
				errors.append("unknown or duplicate pair")
				continue
			seen[id] = true
			if typeof(pair.get("tier")) != TYPE_INT or int(pair.get("tier", 0)) < 1 or int(pair.get("tier", 0)) > 3:
				errors.append("pair tier must be 1..3")
			if [pair.get("a"), pair.get("b")] != MEMBERS[id]:
				errors.append("pair members do not match its identity")
	for key in ["pair_flags", "reserve_support"]:
		if not setup.has(key):
			continue
		if typeof(setup[key]) != TYPE_DICTIONARY:
			errors.append(key + " must be an object")
			continue
		for value in setup[key].values():
			if key == "pair_flags" and typeof(value) != TYPE_BOOL:
				errors.append("pair flags must be boolean")
			elif key == "reserve_support" and (typeof(value) != TYPE_INT or int(value) < 0 or int(value) > 1):
				errors.append("reserve support must be 0 or 1")
	return errors


static func install(state: Dictionary, setup: Dictionary) -> void:
	if not setup.has("pairs"):
		return
	state["pair_rules"] = (setup["pairs"] as Array).duplicate(true)
	state["pair_flags"] = (setup.get("pair_flags", {}) as Dictionary).duplicate(true)
	state["pair_state"] = {"used": [], "rage": [], "coins": {}, "built": [], "round": -1, "sworn": false}
	state["reserve_support"] = (setup.get("reserve_support", {}) as Dictionary).duplicate(true)
	for row in setup.get("roster", []):
		if row.has("fate_bonus") and state["units"].has(str(row.get("id", ""))):
			state["units"][str(row["id"])]["fate_bonus"] = int(row["fate_bonus"])


static func _pair(state: Dictionary, id: String) -> Dictionary:
	for row in state.get("pair_rules", []):
		if str(row["id"]) == id:
			return row
	return {}


static func _standing(state: Dictionary, id: String, positive_hp: bool = true) -> bool:
	var unit: Dictionary = state.get("units", {}).get(id, {})
	return str(unit.get("kind", "")) in ["companion", "hero"] and str(unit.get("status", "")) == "ok" and (not positive_hp or int(unit.get("hp", 0)) > 0)


static func tier(state: Dictionary, id: String, positive_hp: bool = true) -> int:
	var pair := _pair(state, id)
	if pair.is_empty() or not _standing(state, str(pair["a"]), positive_hp) or not _standing(state, str(pair["b"]), positive_hp):
		return 0
	return int(pair["tier"])


static func _adjacent(state: Dictionary, a: String, b: String) -> bool:
	var first: Dictionary = state["units"].get(a, {})
	var second: Dictionary = state["units"].get(b, {})
	return not first.is_empty() and not second.is_empty() and _distance(first, second) == 1


static func _distance(a: Dictionary, b: Dictionary) -> int:
	return absi(int(a.get("col", -100)) - int(b.get("col", 100))) + absi(int(a.get("row", -100)) - int(b.get("row", 100)))


static func refresh(state: Dictionary) -> void:
	if tier(state, "old_neighbours") >= 2 and bool(state.get("pair_flags", {}).get("caderousse_sworn", false)):
		state["pair_state"]["sworn"] = true


static func attack(state: Dictionary, unit: Dictionary) -> int:
	var id := str(unit["uid"])
	var bonus := 3 if id in state.get("pair_state", {}).get("rage", []) else 0
	if id in ["lannes", "murat"] and tier(state, "rivals") >= 1:
		bonus += 2
	if id == "bertuccio" and tier(state, "enemy_name") >= 1:
		bonus += 2
	if id == "dantes" and tier(state, "master_pupil") >= 2 and _adjacent(state, "dantes", "faria"):
		bonus += 2
	if id == "caderousse" and bool(state.get("pair_state", {}).get("sworn", false)):
		bonus += 2
	if id in ["albert", "haydee"] and tier(state, "two_children") >= 2 and bool(state.get("pair_flags", {}).get("mercedes", false)):
		bonus += 1
	return bonus


static func defense(state: Dictionary, unit: Dictionary) -> int:
	return -1 if str(unit["uid"]) == "caderousse" and tier(state, "old_neighbours") >= 1 else 0


## Select the actual recipient before armor is applied. Only hunter attacks redirect.
static func target(state: Dictionary, enemy: Dictionary, victim: Dictionary) -> Dictionary:
	if str(victim.get("uid", "")) != "hero" or "hunter" not in enemy.get("tags", []):
		return victim
	if tier(state, "shield") >= 1 and _adjacent(state, "muiron", "hero"):
		return state["units"]["muiron"]
	if tier(state, "enemy_name") >= 3 and bool(state.get("pair_flags", {}).get("auteuil", false)) and "enemy_name_guard" not in state["pair_state"]["used"]:
		state["pair_state"]["used"].append("enemy_name_guard")
		return state["units"]["bertuccio"]
	return victim


## Called before processing a fallen hero. The caller handles the companion's fall.
static func save_hero(state: Dictionary) -> String:
	if tier(state, "shield", false) < 2 or not _standing(state, "muiron") or not _adjacent(state, "muiron", "hero") or "shield_save" in state["pair_state"]["used"]:
		return ""
	state["pair_state"]["used"].append("shield_save")
	state["units"]["hero"]["hp"] = 1
	state["units"]["muiron"]["hp"] = 0
	_add_coin(state, "muiron", -1)
	return "muiron"


static func on_fall(state: Dictionary, unit: Dictionary, skills: Dictionary) -> void:
	if not state.has("pair_state"):
		return
	var id := str(unit["uid"])
	if tier(state, "old_friends", false) >= 2 and id in ["baptiste", "marie"]:
		var other := "marie" if id == "baptiste" else "baptiste"
		if other not in state["pair_state"]["rage"]:
			state["pair_state"]["rage"].append(other)
		if tier(state, "old_friends", false) >= 3:
			_add_once(state, "old_friends_coins", {"baptiste": 1, "marie": 1})
	if tier(state, "master_pupil", false) >= 3 and id == "faria":
		_add_once(state, "master_pupil_coin", {"faria": 1})
	if tier(state, "father_son", false) >= 2 and id in ["morel", "maximilien"]:
		var other := "maximilien" if id == "morel" else "morel"
		_add_once(state, "father_son_" + other, {other: 1})
	if tier(state, "last_square", false) >= 2 and str(state["template"]) == "waterloo" and id in ["cambronne", "ney"]:
		var saved_coins := {}
		for member in ["cambronne", "ney"]:
			if bool(state["units"][member].get("fated", false)):
				saved_coins[member] = 2
		_add_once(state, "last_square_fate", saved_coins)
	if tier(state, "wait_and_hope", false) >= 2 and id == "dantes":
		var haydee: Dictionary = state["units"]["haydee"]
		var skill := str(haydee["skill"])
		if skills.has(skill):
			haydee["charge"] = int(skills[skill]["charge"])


static func _add_coin(state: Dictionary, id: String, amount: int) -> void:
	state["pair_state"]["coins"][id] = int(state["pair_state"]["coins"].get(id, 0)) + amount


static func _add_once(state: Dictionary, token: String, coins: Dictionary) -> void:
	if token in state["pair_state"]["used"]:
		return
	state["pair_state"]["used"].append(token)
	for id in coins:
		_add_coin(state, str(id), int(coins[id]))


static func fate_bonus(state: Dictionary, id: String) -> int:
	var bonus := int(state.get("units", {}).get(id, {}).get("fate_bonus", 0)) + int(state.get("pair_state", {}).get("coins", {}).get(id, 0))
	if id == "hero":
		bonus += int(state.get("reserve_support", {}).get("hero_fate", 0))
	return bonus


static func can_withdraw(state: Dictionary, id: String) -> bool:
	return id not in state.get("pair_state", {}).get("rage", [])


static func morale(state: Dictionary, value: int) -> int:
	if value < 3 and tier(state, "last_square") >= 1 and "last_square_rally" not in state["pair_state"]["used"]:
		state["pair_state"]["used"].append("last_square_rally")
		return 5
	return value


## Returns morale delta for the kernel's ordinary rally/defeat logic to apply.
static func round_end(state: Dictionary) -> int:
	if not state.has("pair_state") or int(state["pair_state"]["round"]) == int(state["turn"]):
		return 0
	state["pair_state"]["round"] = int(state["turn"])
	var delta := 0
	if tier(state, "rivals") >= 1 and _adjacent(state, "lannes", "murat"):
		delta -= 1
	if tier(state, "enemy_name") >= 1 and _adjacent(state, "bertuccio", "hero") and not (tier(state, "enemy_name") >= 2 and bool(state["pair_flags"].get("truth", false))):
		delta -= 1
	if tier(state, "wait_and_hope") >= 1:
		var dantes: Dictionary = state["units"]["dantes"]
		dantes["hp"] = mini(int(dantes["max_hp"]), int(dantes["hp"]) + 2)
	if tier(state, "old_friends") >= 1:
		for unit in state["units"].values():
			if str(unit["kind"]) in ["barricade", "npc"] or str(unit["status"]) != "ok":
				continue
			for cell in state["pair_state"]["built"]:
				if _distance(unit, cell) <= 1 and _built_exists(state, cell):
					unit["hp"] = mini(int(unit["max_hp"]), int(unit["hp"]) + 2)
					break
	return delta


static func _built_exists(state: Dictionary, cell: Dictionary) -> bool:
	if str(state["terrain"][int(cell["row"]) * int(state["cols"]) + int(cell["col"])]) == "earthwork":
		return true
	for unit in state["units"].values():
		if str(unit["kind"]) == "barricade" and str(unit["status"]) == "ok" and _distance(unit, cell) == 0:
			return true
	return false


static func after_skill(state: Dictionary, unit: Dictionary, args: Dictionary, terrain: Dictionary) -> void:
	if not state.has("pair_state"):
		return
	var id := str(unit["uid"])
	if str(unit["skill"]) == "raise_flag" and tier(state, "father_son") >= 1 and int(unit["row"]) == int(state["units"]["morel"]["row"]) and int(state["units"]["morel"]["row"]) == int(state["units"]["maximilien"]["row"]):
		state["fx"]["flags"][-1]["until"] = int(state["turn"]) + 2
	if str(unit["skill"]) != "fortify":
		return
	var built := {"col": int(args["col"]), "row": int(args["row"])}
	if id == "baptiste" and not _pair(state, "old_friends").is_empty() and built not in state["pair_state"]["built"]:
		state["pair_state"]["built"].append(built)
	if id != "faria" or maxi(tier(state, "two_numbers"), tier(state, "master_pupil")) < 1:
		return
	var earthwork := str(args.get("mode", "barricade")) == "earthwork"
	for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var col: int = int(unit["col"]) + offset.x
		var row: int = int(unit["row"]) + offset.y
		if col < 0 or row < 0 or col >= int(state["cols"]) or row >= int(state["rows"]) or (col == int(args["col"]) and row == int(args["row"])):
			continue
		var tr := str(state["terrain"][row * int(state["cols"]) + col])
		if str(terrain.get(tr, {}).get("stand", "")) != "ground" or (earthwork and tr != "plain"):
			continue
		var occupied := false
		for other in state["units"].values():
			occupied = occupied or (int(other["col"]) == col and int(other["row"]) == row and str(other["status"]) in ["ok", "dying"])
		for enemy in state["enemies"]:
			occupied = occupied or (int(enemy["col"]) == col and int(enemy["row"]) == row)
		for wave in state["waves"]:
			occupied = occupied or wave.get("at", []) == [col, row]
		if earthwork:
			for route in state["routes"].values():
				occupied = occupied or [col, row] in route
		if occupied:
			continue
		if earthwork:
			state["terrain"][row * int(state["cols"]) + col] = "earthwork"
		else:
			var source: Dictionary = {}
			for other in state["units"].values():
				if str(other["kind"]) == "barricade" and _distance(other, built) == 0:
					source = other
			if source.is_empty():
				return
			var bar: Dictionary = source.duplicate(true)
			var uid := "barricade_%d" % int(state["next_obj"])
			while state["units"].has(uid):
				state["next_obj"] = int(state["next_obj"]) + 1
				uid = "barricade_%d" % int(state["next_obj"])
			state["next_obj"] = int(state["next_obj"]) + 1
			bar["uid"] = uid
			bar["id"] = uid
			bar["col"] = col
			bar["row"] = row
			state["units"][uid] = bar
			state["order"].append(uid)
		return


static func charge_ignores_slow(state: Dictionary, unit: Dictionary) -> bool:
	return str(unit["uid"]) == "dantes" and tier(state, "master_pupil") >= 3


static func after_charge(state: Dictionary, unit: Dictionary, kills_before: int) -> void:
	if str(unit["uid"]) == "dantes" and tier(state, "two_numbers") >= 2 and int(state["kills"]) > kills_before:
		state["cp"] = mini(20, int(state["cp"]) + 1)


static func forecast(state: Dictionary) -> int:
	return int(state.get("reserve_support", {}).get("forecast", 0))


static func view(state: Dictionary) -> Array:
	var out: Array = []
	for pair in state.get("pair_rules", []):
		var active := tier(state, str(pair["id"])) > 0
		out.append({"id": pair["id"], "name": pair.get("name", pair["id"]), "kind": "pair", "count": 2 if active else 0,
			"tier": int(pair["tier"]) if active else 0, "active": active, "next": 0 if active else 2,
			"desc": str(pair.get("desc", "")), "effect": "named_pair", "tag": "", "cls": ""})
	return out
