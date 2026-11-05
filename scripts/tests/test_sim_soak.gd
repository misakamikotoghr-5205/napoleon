extends SceneTree

const Sim = preload("res://scripts/sim/town_sim.gd")
const Pack = preload("res://scripts/sim/town_pack.gd")
const Items = preload("res://scripts/sim/item_gen.gd")
const Ledger = preload("res://scripts/core/ledger.gd")
const Database = preload("res://scripts/core/db.gd")
const World = preload("res://scripts/core/world.gd")
const Session = preload("res://scripts/core/session.gd")
const Mind = preload("res://scripts/core/mind.gd")

# All 4,500 days use the production ledger and world-backed TownSim path.
# The lightweight world avoids loading the persona model 150 times; the real
# World/Session integration below exercises that boundary separately.
class SoakWorld extends RefCounted:
	var db
	var ledger
	var town
	var flags: Dictionary = {}
	var stats: Dictionary = {}
	var npcs: Dictionary = {}
	var notebook: Array = []
	var unlocked: Dictionary = {}
	var day: int = 0
	var slot: int = 0
	var weather: String = ""
	var rice_mod: float = 1.0
	var med_mod: float = 1.0
	var prev_rice_mod: float = 1.0
	var prev_med_mod: float = 1.0

	func note(kind: String, text: String, source: String = "seen", via: String = "", conf: float = 1.0) -> void:
		notebook.append({"day": day, "slot": slot, "kind": kind, "text": text, "source": source, "via": via, "conf": conf})

	func date_text(value: int = -1) -> String:
		return "第%d日" % (day if value < 0 else value)

	func stat(name: String) -> int:
		return int(stats.get(name, 0))

	func price_mod(item: Dictionary) -> float:
		return rice_mod if str(item.get("cat", "")) == "rice" else (med_mod if str(item.get("cat", "")) == "medicine" else 1.0)

	func market_now(item: Dictionary) -> int:
		return int(round(float(item.get("market", 0)) * price_mod(item)))

var failures: Array[String] = []
var failure_count: int = 0
var checks: int = 0
var days_run: int = 0
var visits_checked: int = 0
var transfers_checked: int = 0
var pack: Dictionary = {}
var templates: Dictionary = {}


func _init() -> void:
	pack = Pack.load_pack()
	check(not pack.is_empty(), "production pack loads and validates")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/item_templates.json"))
	check(parsed is Dictionary, "item templates load")
	if not pack.is_empty() and parsed is Dictionary:
		templates = parsed
		_item_templates_and_sessions()
		_rarity_persistence()
		_real_world_integration()
		_soak()
	for failure in failures:
		print("FAIL: ", failure)
	if failure_count > failures.size():
		print("FAIL: ", failure_count - failures.size(), " further failures")
	print("SIM SOAK: ", "PASS" if failure_count == 0 else "FAIL", " (", days_run, " world-backed days, ", visits_checked, " visits, ", transfers_checked, " transfers, ", checks, " checks)")
	Database.shutdown()
	quit(0 if failure_count == 0 else 1)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failure_count += 1
		if failures.size() < 40:
			failures.append(message)


func _make_world(config: Dictionary):
	var world = SoakWorld.new()
	world.db = Database.new()
	world.db.sessions = Database.get_db().sessions.duplicate(true)
	world.ledger = Ledger.new()
	var initial: Dictionary = config.get("initial", {})
	world.flags = initial.get("flags", {}).duplicate(true)
	world.stats = initial.get("stats", {}).duplicate(true)
	var difficulty: Dictionary = config["difficulty"][config["default_difficulty"]]
	world.ledger.open_account("player", int(difficulty["initial_cash"]))
	for id in config["npcs"]:
		var definition: Dictionary = config["npcs"][id]
		world.db.cast[id] = definition.duplicate(true)
		world.npcs[id] = {"id": id, "def": definition, "name": definition.get("name", id), "label": definition.get("label", id), "persona": Mind.make_persona(definition), "rel": {"player": Mind.fresh_rel()}, "location": "", "present": true, "knows": {}, "log": []}
		world.ledger.open_account(str(id), int(definition.get("cash", 0)))
	return world


func _soak() -> void:
	var difficulties: Array = ["太平年", "常年", "乱世"]
	check(pack.get("difficulty", {}).size() == difficulties.size(), "three difficulty settings")
	for difficulty in difficulties:
		check(pack["difficulty"].has(difficulty), "difficulty exists: " + difficulty)
		if not pack["difficulty"].has(difficulty):
			continue
		var config: Dictionary = pack.duplicate(true)
		config["default_difficulty"] = difficulty
		for seed_index in range(50):
			var seed_value: int = 19380306 + seed_index
			var world = _make_world(config)
			var sim = Sim.new(config, seed_value, world)
			var zero_streak: int = 0
			for day in range(1, 31):
				var context: String = "%s seed=%d day=%d" % [difficulty, seed_value, day]
				var plan: Dictionary = sim.start_day()
				days_run += 1
				var visits: Array = plan.get("visits", [])
				zero_streak = zero_streak + 1 if visits.is_empty() else 0
				check(not visits.is_empty(), context + ": at least one customer")
				check(zero_streak < 7, context + ": no seven-day empty streak")
				check(int(plan.get("day", -1)) == day and world.day == day, context + ": world date synchronized")
				check(world.weather == str(plan.get("weather", "")) and world.rice_mod == float(sim.s["pressures"]["rice_price"]) and world.med_mod == float(sim.s["pressures"]["med_price"]), context + ": live market synchronized")
				var visit_ids: Dictionary = {}
				for visit in visits:
					visits_checked += 1
					var visit_id: String = str(visit.get("id", ""))
					check(visit_id != "" and not visit_ids.has(visit_id), context + ": unique visit id")
					visit_ids[visit_id] = true
					check(int(visit.get("minute", -1)) >= int(config["time"]["wake_minute"]) and int(visit.get("minute", -1)) <= int(config["time"]["sleep_minute"]), context + ": visit minute in current day")
					var spec: Dictionary = visit.get("session", {})
					if not spec.get("_npc_def", {}).is_empty():
						check(world.ledger.balance(str(spec["npc"])) == int(spec["_npc_def"].get("cash", 0)), context + ": arriving stranger opening funds registered once")
					check(_session_error(spec, world) == "", context + ": " + _session_error(spec, world))
					if str(visit.get("storylet", "")) != "":
						check(world.db.sessions.has(visit["storylet"]) and str(spec.get("id", "")) == str(visit["storylet"]), context + ": authored storylet resolves")
					else:
						check(str(spec.get("id", "")).begins_with("gen_d%d_" % day), context + ": generated session id")
					for id in spec.get("_item_defs", {}):
						var item: Dictionary = spec["_item_defs"][id]
						check(_item_error(item) == "", context + ": " + _item_error(item))
						check(world.db.items.get(id, {}) == item, context + ": definition registered in this world")
				check(world.ledger.check_invariants().is_empty(), context + ": morning ledger invariants")
				# Alternate full payment, partial payment and deliberate arrears. Each
				# successful payment must have a ledger receipt and survive retries.
				if (seed_index + day) % 3 != 0:
					for bill in sim.bills():
						if int(bill["due_day"]) > day or str(bill["status"]) in ["paid", "waived"]:
							continue
						var available: int = world.ledger.balance("player")
						if available <= 0:
							break
						var remaining: int = int(bill["amount"]) - int(bill.get("paid", 0))
						var amount: int = mini(available, maxi(1, remaining / 2) if seed_index % 2 == 0 else remaining)
						var request: String = "%d:%d:%s" % [seed_value, day, str(bill["id"])]
						var receipt: Dictionary = sim.pay_bill(str(bill["id"]), amount, request)
						var after: Dictionary = world.ledger.accounts.duplicate(true)
						var journal_size: int = world.ledger.journal.size()
						check(bool(receipt.get("ok", false)) and str(receipt.get("journal", "")) != "", context + ": payment has ledger receipt")
						check(sim.pay_bill(str(bill["id"]), amount, request) == receipt and world.ledger.accounts == after and world.ledger.journal.size() == journal_size, context + ": payment retry is idempotent")
				var summary: Dictionary = sim.end_day()
				check(int(summary.get("day", -1)) == day and int(summary.get("cash", -1)) == world.ledger.balance("player"), context + ": day summary reflects ledger")
				check(world.ledger.check_invariants().is_empty(), context + ": closing ledger invariants")
				check(world.ledger.total() == world.ledger.initial_total, context + ": every account conserves cash")
			transfers_checked += world.ledger.journal.size()
			world.town = null
			sim.world = null
		print("SIM SOAK progress: ", difficulty, " 50 seeds x 30 days complete")
	check(days_run == 4500, "exactly three difficulties x fifty seeds x thirty days")
	check(transfers_checked > 0, "soak exercises actual ledger transfers")


func _item_templates_and_sessions() -> void:
	var categories: Array = ["rice", "clothing", "jewelry", "utensils", "art", "medicine", "documents"]
	check(templates.get("categories", {}).size() == categories.size(), "seven item categories")
	var world = _make_world(pack)
	var sim = Sim.new(pack, 42, world)
	for category in categories:
		check(templates["categories"].has(category), "category exists: " + category)
		if not templates["categories"].has(category):
			continue
		var variants: Array = templates["categories"][category].get("variants", [])
		check(variants.size() >= 3 and variants.size() <= 6, category + ": three to six variants")
		var ids: Dictionary = {}
		for variant in variants:
			check(not ids.has(variant["id"]), category + ": unique variant id")
			ids[variant["id"]] = true
			# Selecting each declared variant explicitly covers rare low-weight rows
			# without making coverage depend on a lucky random sample.
			var selected_templates: Dictionary = templates.duplicate(true)
			selected_templates["categories"][category]["variants"] = [variant.duplicate(true)]
			for intent in ["sell", "pawn", "buy"]:
				var state: Dictionary = {"seed": 42, "day": 3, "pressures": sim.s["pressures"].duplicate(true), "stock": []}
				var independent: Dictionary = state.duplicate(true)
				var visit: Dictionary = {"id": "%s_%s_%s" % [category, str(variant["id"]), intent], "who": "ma", "intent": intent, "item": category}
				if intent == "buy":
					var stock_item: Dictionary = Items.generate(selected_templates, pack, state, ["stock", category, str(variant["id"])], category)
					state["stock"] = [stock_item]
					independent = state.duplicate(true)
					world.ledger.add_item(stock_item, "player", "stock")
				var spec: Dictionary = Items.session(selected_templates, pack, state, visit)
				check(spec == Items.session(selected_templates, pack, independent, visit), category + ": deterministic session " + intent)
				check(str(spec.get("mode", "")) == {"sell": "buy", "pawn": "pawn", "buy": "sell"}[intent], category + ": correct counter mode for " + intent)
				for id in spec.get("_item_defs", {}):
					var item: Dictionary = spec["_item_defs"][id]
					check(str(item.get("template_id", "")) == str(variant["id"]) and _item_error(item) == "", category + ": variant produces complete inspectable item")
				# Register through the coordinator before the existing Session reader.
				sim._register_session(spec)
				check(_session_error(spec, world) == "", category + ": session schema " + _session_error(spec, world))
				var counter = Session.new()
				counter.setup(world, spec)
				check(not counter.item_ids.is_empty(), category + ": existing Session reads " + intent)
				for iid in counter.item_ids:
					var item: Dictionary = world.ledger.items[iid]
					for part in item.get("parts", []):
						check(counter.inspect(str(iid), str(part["id"])) != "", category + ": existing Session inspects " + str(part["id"]))
				check(world.ledger.check_invariants().is_empty(), category + ": session loading retains ledger invariants")
				counter.world = null
	var empty_state: Dictionary = {"seed": 42, "day": 3, "pressures": {}, "stock": []}
	var fallback: Dictionary = Items.session(templates, pack, empty_state, {"id": "empty_stock", "who": "ma", "intent": "buy"})
	check(str(fallback.get("mode", "")) == "pawn" and empty_state["stock"].is_empty(), "empty stock falls back without creating shop stock")
	world.town = null
	sim.world = null


func _rarity_persistence() -> void:
	var controlled: Dictionary = pack.duplicate(true)
	for field in ["rare_rate", "rare_gain_per_day", "rare_rate_max", "rare_pity_gain"]:
		controlled["balance"]["items"][field] = 0.0
	var limit: int = int(controlled["balance"]["items"]["rare_pity_after"])
	check(limit > 1, "rarity has a configured pity window")
	if limit <= 1:
		return
	var sim = Sim.new(controlled, 19380306)
	var resumed = Sim.new(controlled, 19380306)
	var split_at: int = maxi(1, limit / 2)
	for index in range(limit * 2):
		var key: Array = ["pity", index]
		var item: Dictionary = Items.generate(templates, controlled, sim.s, key, "jewelry")
		var expected_rare: bool = (index + 1) % limit == 0
		check(bool(item.get("rare", false)) == expected_rare, "pity triggers precisely at configured window, item %d" % index)
		check(int(sim.s["item_gen"]["count"]) == index + 1 and int(sim.s["item_gen"]["rare_misses"]) == (index + 1) % limit, "pity counter advances once per new semantic key")
		if index == split_at - 1:
			var serialized = JSON.parse_string(JSON.stringify(sim.to_dict()))
			resumed.from_dict(serialized)
			check(resumed.s["item_gen"] == sim.s["item_gen"], "item cache and pity survive JSON save/load exactly")
		elif index >= split_at:
			check(Items.generate(templates, controlled, resumed.s, key, "jewelry") == item, "post-save generated item exactly matches uninterrupted item")
		var before: Dictionary = sim.s["item_gen"].duplicate(true)
		var replay: Dictionary = Items.generate(templates, controlled, sim.s, key, "jewelry")
		check(replay == item and sim.s["item_gen"] == before, "cached item cannot reroll rarity or consume pity")
		replay["name"] = "changed only in returned copy"
		replay["parts"][0]["text"] = "changed only in returned copy"
		check(Items.generate(templates, controlled, sim.s, key, "jewelry") == item, "returned item edits cannot corrupt stored cache")
	check(resumed.s["item_gen"] == sim.s["item_gen"], "restored pity and generation cache finish exactly equal")
	sim.s["day"] = 100
	var before: Dictionary = sim.s["item_gen"].duplicate(true)
	var original: Dictionary = before["items"].values()[0]
	check(Items.generate(templates, controlled, sim.s, ["pity", 0], "jewelry") == original and sim.s["item_gen"] == before, "later-day revisit cannot reroll a cached decision")


func _real_world_integration() -> void:
	var shared = Database.get_db()
	var baseline_items: Dictionary = shared.items.duplicate(true)
	var baseline_cast: Dictionary = shared.cast.duplicate(true)
	var world = World.new()
	world.setup(42)
	var earlier_world = World.new()
	# No second persona model is needed to check the shared database boundary.
	earlier_world.db = shared
	var sim = Sim.new(pack, 42, world)
	for day in range(1, 4):
		var plan: Dictionary = sim.start_day()
		for visit in plan["visits"]:
			var spec: Dictionary = visit["session"]
			check(world.npcs.has(str(spec.get("npc", ""))), "real world registers generated session customer")
			check(_session_error(spec, world) == "", "real world generated session schema")
			var counter = Session.new()
			counter.setup(world, spec)
			check(not counter.item_ids.is_empty(), "real World and Session consume generated visit")
			counter.world = null
		check(world.ledger.check_invariants().is_empty(), "real world daily ledger invariants")
		sim.end_day()
	check(world.db != shared and world.db != earlier_world.db, "generated definitions use a per-world database")
	check(shared.items == baseline_items and earlier_world.db.items == baseline_items, "generated items do not contaminate shared or earlier world DB")
	check(shared.cast == baseline_cast and earlier_world.db.cast == baseline_cast, "generated strangers do not contaminate shared or earlier world DB")
	world.town = null
	sim.world = null


func _item_error(item: Dictionary) -> String:
	for field in ["id", "def_id", "template_id", "name", "cat", "cat_cn", "market", "claimed", "fake", "grade", "condition", "origin", "stolen", "rarity", "rare", "est", "suggest", "ask_w", "tags", "parts"]:
		if not item.has(field):
			return "item missing " + field
	if str(item["def_id"]) == "" or str(item["name"]) == "" or not templates["categories"].has(item["cat"]):
		return "item identity/category invalid"
	if int(item["market"]) <= 0 or not _range_valid(item["est"]):
		return "item valuation invalid"
	var bounds: Array = pack["balance"]["items"]["condition"]
	if float(item["condition"]) < float(bounds[0]) or float(item["condition"]) > float(bounds[1]):
		return "item condition outside template range"
	if not item["fake"] is bool or not item["stolen"] is bool or not item["rare"] is bool:
		return "item hidden qualities must be booleans"
	if str(item["origin"]) != ("stolen" if item["stolen"] else "normal") or str(item["rarity"]) != ("rare" if item["rare"] else "common"):
		return "item hidden quality labels disagree"
	if not item["parts"] is Array or item["parts"].is_empty():
		return "item has no inspection parts"
	var ids: Dictionary = {}
	for part in item["parts"]:
		if not part is Dictionary:
			return "inspection part is not an object"
		for field in ["id", "label", "text", "tool", "rect"]:
			if not part.has(field):
				return "inspection part missing " + field
		if str(part["id"]) == "" or ids.has(part["id"]) or str(part["label"]) == "" or str(part["text"]) == "":
			return "inspection part identity/text invalid"
		ids[part["id"]] = true
		if not part["rect"] is Array or part["rect"].size() != 4 or int(part["rect"][2]) <= 0 or int(part["rect"][3]) <= 0:
			return "inspection rect invalid"
		if not str(part["tool"]) in ["hand", "magnifier", "scale", "book"]:
			return "unsupported inspection tool"
		if part.has("est") and not _range_valid(part["est"]):
			return "inspection valuation invalid"
	return ""


func _session_error(spec: Dictionary, world) -> String:
	for field in ["id", "npc", "mode", "ask", "floor", "est"]:
		if not spec.has(field):
			return "session missing " + field
	if str(spec["id"]) == "" or not world.npcs.has(str(spec["npc"])) or not world.ledger.accounts.has(str(spec["npc"])):
		return "session customer/id unresolved"
	if not str(spec["mode"]) in ["buy", "sell", "pawn"] or not _range_valid(spec["est"]):
		return "session mode/estimate invalid"
	if int(spec["ask"]) <= 0 or int(spec["floor"]) <= 0:
		return "session has nonpositive prices"
	if str(spec["mode"]) == "sell":
		if int(spec["floor"]) < int(spec["ask"]) or not spec.get("stock", []) is Array or spec.get("stock", []).is_empty():
			return "selling session has invalid stock/prices"
		for id in spec["stock"]:
			if world.ledger.find_item(str(id), "stock") == "":
				return "selling session references missing stock"
	else:
		if int(spec["floor"]) > int(spec["ask"]) or not spec.get("items", []) is Array or spec.get("items", []).is_empty():
			return "incoming session has invalid items/prices"
		for item in spec["items"]:
			if not item is Dictionary or not world.db.items.has(str(item.get("def", ""))):
				return "incoming session definition unresolved"
	if str(spec["mode"]) == "pawn":
		var terms: Dictionary = spec.get("terms", {})
		if int(terms.get("days", 0)) <= 0 or float(terms.get("rate_month", -1.0)) < 0.0 or str(terms.get("condition", "")) == "":
			return "pawn session terms invalid"
	return ""


func _range_valid(value) -> bool:
	return value is Array and value.size() == 2 and (value[0] is int or value[0] is float) and (value[1] is int or value[1] is float) and float(value[0]) >= 0.0 and float(value[0]) <= float(value[1])
