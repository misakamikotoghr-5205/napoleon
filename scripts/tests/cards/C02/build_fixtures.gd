# 用 Mock 情景拼 C02 夹具：例子集里每种会进手牌或各区的牌一张 CardView，外加同一张牌的几种状态。
# 只调用 mock_scenario，不改它。主人 C02。
extends SceneTree

const Scenario = preload("res://scripts/cards/mock/mock_scenario.gd")

const SPECS: Array = [
	["person", "p.linsao.1938.pawn_hairpin", "hand"],
	["gold_person", "p.brother.1938.farewell", "hand"],
	["self", "self.ruhua", "self"],
	["contact", "ct.ma", "contacts"],
	["event", "ev.1938.police_check", "hand"],
	["fate", "fa.any.fire_next_door", "hand"],
	["big_fate", "bf.wheel", "hand"],
	["demand", "dm.1938.money.t1", "demands"],
	["life", "lf.any.coal_out", "hand"],
	["news", "nw.1938.wangshan_dock", "hand"],
	["kept", "kp.ma_owes", "kept"],
	["estate", "es.jewel_cabinet", "estate"],
	["night", "nt.tidy", "hand"],
	["street", "st.write_letters", "hand"],
	["prison", "pr.cell", "hand"],
	["pawn_ticket", "tk.1938.de196", "hand"],
	["demand_return", "ev.any.demand_return", "hand"],
]


func _initialize() -> void:
	var pack := build_all()
	var dir := "res://scripts/tests/cards/C02/fixtures"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_write(dir + "/all_examples.json", pack["examples"])
	_write(dir + "/states.json", pack["states"])
	var leaks := PackedStringArray()
	for row in pack["examples"]["cards"]:
		leaks.append_array(CardViewModel.leaks(row["view"]))
	for k in pack["states"]["states"].keys():
		leaks.append_array(CardViewModel.leaks(pack["states"]["states"][k]))
	if not leaks.is_empty():
		print("LEAK " + ",".join(leaks))
		quit(1)
		return
	print("C02 fixtures written")
	quit(0)


static func build_all() -> Dictionary:
	var db := CardDB.load_all("res://data/cards", {"only_examples": true})
	var sc = Scenario.new(db, {"seed": 7})
	var cards: Array = []
	var by_key := {}
	for spec in SPECS:
		var view := _view_for(sc, str(spec[1]), str(spec[2]))
		cards.append({"key": str(spec[0]), "view": view})
		by_key[str(spec[0])] = view
	var examples := {
		"_meta": {"owner": "C02", "schema": 1, "brief": "One CardView per example card that can sit in a zone",
			"_provenance": {"by": "ai", "task": "C02", "date": "2026-10-13"}},
		"cards": cards,
	}
	return {"examples": examples, "states": _states(by_key)}


static func _view_for(sc, def_id: String, zone: String) -> Dictionary:
	var uid := ""
	if (sc.st["zones"] as Dictionary).has(zone):
		uid = sc._spawn(def_id, zone)
	else:
		uid = sc._new_uid()
		var d: Dictionary = sc.db.def(def_id)
		sc.st["cards"][uid] = {"def": def_id, "zone": zone, "status": "open", "placed": {}, "choice": "",
			"expires_in": -1, "days_left": int(d.get("due_days", -1)) if d.has("due_days") else -1}
	return sc.card_view(uid, false)


static func _states(by_key: Dictionary) -> Dictionary:
	var base: Dictionary = (by_key["person"] as Dictionary).duplicate(true)
	base["uid"] = "cst01"
	base["gold"] = false
	base["must_resolve"] = true
	base["used_today"] = false
	base["away_days"] = 0
	base["expires_in"] = -1
	base["days_left"] = -1
	base["zone"] = "hand"
	var states := {}
	states["draft"] = base.duplicate(true)
	states["plain"] = base.duplicate(true)
	var used: Dictionary = base.duplicate(true)
	used["used_today"] = true
	states["used_today"] = used
	var away: Dictionary = base.duplicate(true)
	away["away_days"] = 4
	states["away_days"] = away
	var exp: Dictionary = base.duplicate(true)
	exp["expires_in"] = 1
	states["expires_1"] = exp
	var none: Dictionary = base.duplicate(true)
	none["expires_in"] = -1
	states["expires_none"] = none
	var gold: Dictionary = base.duplicate(true)
	gold["gold"] = true
	gold["actions"] = [{"id": "keep", "enabled": true, "reason_key": ""},
		{"id": "open", "enabled": true, "reason_key": ""}]
	states["gold"] = gold
	var must_hand: Dictionary = base.duplicate(true)
	must_hand["must_resolve"] = true
	must_hand["zone"] = "hand"
	states["must_hand"] = must_hand
	var must_other: Dictionary = base.duplicate(true)
	must_other["must_resolve"] = true
	must_other["zone"] = "kept"
	states["must_other"] = must_other
	var keep_on: Dictionary = base.duplicate(true)
	keep_on["gold"] = false
	keep_on["actions"] = [{"id": "keep", "enabled": true, "reason_key": ""}]
	states["keep_on"] = keep_on
	var keep_off: Dictionary = base.duplicate(true)
	keep_off["gold"] = false
	keep_off["actions"] = [{"id": "keep", "enabled": false, "reason_key": "g01.reason.no"}]
	states["keep_off"] = keep_off
	var life: Dictionary = (by_key["life"] as Dictionary).duplicate(true)
	life["uid"] = "cst02"
	life["zone"] = "hand"
	life["days_left"] = 3
	life["expires_in"] = -1
	life["gold"] = false
	life["must_resolve"] = false
	states["life"] = life
	var life_off: Dictionary = life.duplicate(true)
	life_off["zone"] = "kept"
	states["life_offhand"] = life_off
	return {
		"_meta": {"owner": "C02", "schema": 1, "brief": "One card in draft, used, away, expiry, gold, must-resolve, keep",
			"_provenance": {"by": "ai", "task": "C02", "date": "2026-10-13"}},
		"states": states,
	}


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  ") + "\n")
