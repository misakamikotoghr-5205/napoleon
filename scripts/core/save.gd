# Town saves contain state only. Loaded content, model objects and coroutines
# are rebuilt after validating the entire file, before any live state changes.
class_name TownSave
extends RefCounted

const VERSION: int = 1
const SAVE_PATH: String = "user://town_save.json"
const MAX_BYTES: int = 64 * 1024 * 1024
const WORLD_EXCLUDED: Array = ["db", "ledger", "mind", "town", "_town_ref"]
const DIRECTOR_FIELDS: Array = ["vars", "customer", "brother", "bg", "lamp", "queued_sessions", "done",
	"stop_at", "stopped", "beats_emitted", "current_script", "night_no", "lamps", "_halt", "_action_ok", "_last_expr"]
const SIM_DICTIONARIES: Array = ["pressures", "wheel_last", "unlocked", "flags", "flags_today", "stats", "cash", "npc_cash",
	"tickets", "known", "seen", "influence_spent", "day_report", "player_rumors", "bill_requests", "action_requests",
	"emitted_visits", "npc_locations", "published_news", "spine_done", "summary", "pawn_items", "transfer_requests"]
const SIM_ARRAYS: Array = ["queue", "spawns", "bills", "visits", "pending_events", "news_entries", "player_feed",
	"dev_entries", "invitations", "stock", "cash_journal"]
const SIM_INTEGERS: Array = ["seed", "day", "slot", "minute", "seq", "stolen_stock", "event_seq", "journal_start", "initial_total"]
const Mind = preload("res://scripts/core/mind.gd")
const Database = preload("res://scripts/core/db.gd")

static var last_error: String = ""

static func pack_hash(pack: Dictionary) -> String:
	return JSON.stringify(_encode_state(pack), "", true, true).sha256_text()

static func snapshot(world, town_sim, director, context: Dictionary = {}) -> Dictionary:
	last_error = ""
	if world == null or town_sim == null or director == null or world.ledger == null:
		return _empty("存档需要完整的小镇状态。")
	if not _idle(director):
		return _empty("请等当前对话或交易结束后再存档。")
	var sim_state: Dictionary = town_sim.to_dict()
	var plain_sim: Dictionary = _decode_state(sim_state)
	var position = context.get("player_pos", [0.0, 0.0])
	if position is Vector2 or position is Vector2i:
		position = [position.x, position.y]
	var world_state: Dictionary = world.to_dict() if world.has_method("to_dict") else object_state_to_dict(world, WORLD_EXCLUDED)
	var saved: Dictionary = {"version": VERSION, "pack_hash": pack_hash(town_sim.pack),
		"seed": int(plain_sim.get("seed", world.world_seed)), "day": int(plain_sim.get("day", world.day)),
		"minute": int(context.get("minute", plain_sim.get("minute", 360))),
		"map_id": str(context.get("map_id", "pawnshop")), "player_pos": position,
		"town_sim": sim_state, "world": world_state, "ledger": object_state_to_dict(world.ledger),
		"director_vars": director.vars.duplicate(true), "director_state": _director_state(director)}
	if not _json_safe(saved):
		return _empty("存档状态含有无法保存的运行时对象。")
	saved = _encode_state(saved)
	return saved if _validate(saved, world, director, town_sim.pack) else {}

static func restore(saved: Dictionary, world, town_sim, director, pack: Dictionary, context: Dictionary = {}) -> bool:
	last_error = ""
	if world == null or town_sim == null or director == null or world.ledger == null:
		return _fail("读档需要完整的小镇状态。")
	if not _idle(director):
		return _fail("请等当前对话或交易结束后再读档。")
	if not _validate(saved, world, director, pack):
		return false
	var state: Dictionary = _decode_state(saved)
	# TownSim.from_dict normally synchronizes from its attached World. Detach
	# while loading, otherwise it replaces saved flags, relationships and prices
	# with the target game's state. Preserve integers outside JSON's exact range.
	town_sim.world = null
	town_sim.pack = pack.duplicate(true)
	town_sim.from_dict(_encode_state(state["town_sim"], false))
	object_state_from_dict(world, state["world"], WORLD_EXCLUDED)
	object_state_from_dict(world.ledger, state["ledger"])
	if world.mind == null:
		world.mind = Mind.new(int(state["seed"]))
	else:
		world.mind.world_seed = int(state["seed"])
	world.db = _runtime_database(state)
	town_sim.world = world
	world.town = town_sim
	director.world = world
	director.db = world.db
	for name in state.get("director_state", {}):
		director.set(name, _copy(state["director_state"][name]))
	director.vars = state["director_vars"].duplicate(true)
	if director.ctx != null:
		director.ctx.world = world
		director.ctx.director = director
		director.ctx.session = null
	director.session = null
	if director.has_method("ensure_vm"):
		director.ensure_vm()
	if director.has_method("_town_restore_runtime"):
		director._town_restore_runtime()
	context["minute"] = int(state["minute"])
	context["map_id"] = str(state["map_id"])
	context["player_pos"] = state["player_pos"].duplicate()
	return true

static func write(path: String, world, town_sim, director, context: Dictionary = {}) -> bool:
	var saved: Dictionary = snapshot(world, town_sim, director, context)
	if saved.is_empty():
		return false
	var target: String = SAVE_PATH if path.is_empty() else path
	var temporary: String = target + ".tmp"
	var file = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("无法写入存档。")
	file.store_string(JSON.stringify(saved, "", true, true))
	file.flush()
	var result: Error = file.get_error()
	file.close()
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _fail("存档写入未完成，原存档已保留。")
	# Same-directory rename replaces the previous file in one operation. Never
	# delete the old save first: failure must leave the previous save usable.
	result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(target))
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _fail("无法替换存档，原存档已保留。")
	return true

static func read(path: String, world, town_sim, director, pack: Dictionary, context: Dictionary = {}) -> bool:
	var saved: Dictionary = read_snapshot(path)
	return not saved.is_empty() and restore(saved, world, town_sim, director, pack, context)

static func read_snapshot(path: String = SAVE_PATH) -> Dictionary:
	last_error = ""
	var target: String = SAVE_PATH if path.is_empty() else path
	var file = FileAccess.open(target, FileAccess.READ)
	if file == null:
		return _empty("找不到可读的存档。")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _empty("存档文件过大。")
	var content: String = file.get_as_text()
	file.close()
	var parser: JSON = JSON.new()
	if parser.parse(content) != OK or not parser.data is Dictionary:
		return _empty("存档格式损坏。")
	return parser.data

# Used by World.to_dict/from_dict as well as the save coordinator. Script
# variables are included automatically, so future mutable world fields cannot
# silently disappear from the save. References are explicitly excluded.
static func object_state_to_dict(object, excluded: Array = []) -> Dictionary:
	var result: Dictionary = {}
	for property in object.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = str(property["name"])
		if excluded.has(name):
			continue
		result[name] = _copy(object.get(name))
	return result

static func object_state_from_dict(object, state: Dictionary, excluded: Array = []) -> void:
	for name in object_state_to_dict(object, excluded):
		if state.has(name):
			object.set(name, _copy(state[name]))

static func _director_state(director) -> Dictionary:
	var result: Dictionary = {}
	for name in DIRECTOR_FIELDS:
		if _has_property(director, str(name)):
			result[name] = _copy(director.get(name))
	return result

static func _idle(director) -> bool:
	return director.session == null and str(director.current_script).is_empty()

static func _validate(saved: Dictionary, world, director, pack: Dictionary) -> bool:
	if not _json_safe(saved):
		return _fail("存档数据损坏。")
	var state: Dictionary = _decode_state(saved)
	if not _integer(state.get("version")) or int(state["version"]) != VERSION:
		return _fail("不支持此存档版本。")
	if str(state.get("pack_hash", "")) != pack_hash(pack):
		return _fail("存档与当前小镇数据版本不一致，无法读档。")
	for name in ["seed", "day", "minute"]:
		if not _integer(state.get(name)):
			return _fail("存档时间或种子损坏。")
	if int(state["day"]) < 0 or int(state["minute"]) < 0 or int(state["minute"]) > 1440:
		return _fail("存档时间损坏。")
	if not state.get("map_id") is String or str(state["map_id"]).is_empty():
		return _fail("存档地图损坏。")
	var position = state.get("player_pos")
	if not position is Array or position.size() != 2 or not _number(position[0]) or not _number(position[1]):
		return _fail("存档位置损坏。")
	for name in ["town_sim", "world", "ledger", "director_vars"]:
		if not state.get(name) is Dictionary:
			return _fail("存档缺少完整的小镇状态。")
	if not _object_shape(state["world"], object_state_to_dict(world, WORLD_EXCLUDED)):
		return _fail("存档世界状态损坏。")
	if not _ledger_shape(state["ledger"], world.ledger):
		return _fail("存档账本损坏。")
	var sim: Dictionary = state["town_sim"]
	for name in SIM_DICTIONARIES:
		if not sim.get(name) is Dictionary:
			return _fail("存档模拟状态损坏。")
	for name in SIM_ARRAYS:
		if not sim.get(name) is Array:
			return _fail("存档模拟状态损坏。")
	for name in SIM_INTEGERS:
		if not _integer(sim.get(name)):
			return _fail("存档模拟计数损坏。")
	if not sim.get("day_ended") is bool or not sim.get("weather") is String or not sim.get("difficulty") is String:
		return _fail("存档模拟状态损坏。")
	if sim["seed"] != state["seed"] or sim["day"] != state["day"] or sim["minute"] != state["minute"]:
		return _fail("存档时间不一致。")
	if state["world"]["world_seed"] != state["seed"] or state["world"]["day"] != state["day"]:
		return _fail("存档世界与模拟不一致。")
	if int(sim["slot"]) < 0 or int(sim["slot"]) > 5 or state["world"]["slot"] != sim["slot"]:
		return _fail("存档时段损坏。")
	if sim["cash"] != state["ledger"]["accounts"]:
		return _fail("存档资金状态不一致。")
	for npc in state["world"]["npcs"].values():
		if not npc is Dictionary:
			return _fail("存档人物损坏。")
		for name in ["def", "persona", "rel", "knows"]:
			if not npc.get(name) is Dictionary:
				return _fail("存档人物损坏。")
		if not npc.get("log") is Array:
			return _fail("存档人物损坏。")
		for name in ["id", "name", "label", "location"]:
			if not npc.get(name) is String:
				return _fail("存档人物损坏。")
		if not npc.get("present") is bool:
			return _fail("存档人物损坏。")
		for name in ["traits", "values", "cognition", "motives", "instincts", "emotions", "needs", "memory", "goals", "regulation"]:
			if not _number_map(npc["persona"].get(name)):
				return _fail("存档人物性格损坏。")
		for relation in npc["rel"].values():
			if not _number_map(relation):
				return _fail("存档人物关系损坏。")
	for visit in sim["visits"]:
		if not visit is Dictionary or not _session_shape(visit.get("session", {})):
			return _fail("存档来访损坏。")
	if not _number_map(sim["pressures"]) or not _number_map(sim["stats"]):
		return _fail("存档模拟数值损坏。")
	for bill in sim["bills"]:
		if not bill is Dictionary or not bill.get("id") is String or not bill.get("status") is String:
			return _fail("存档账单损坏。")
		if not _integer(bill.get("amount")) or not _integer(bill.get("due_day")):
			return _fail("存档账单损坏。")
	if state["director_vars"].has("town"):
		var runtime = state["director_vars"]["town"]
		if not runtime is Dictionary:
			return _fail("存档剧情状态损坏。")
		for name in ["generated_defs", "generated_npcs"]:
			if not _definition_map(runtime.get(name, {})):
				return _fail("存档动态定义损坏。")
	if state.has("director_state"):
		if not state["director_state"] is Dictionary or not _object_shape(state["director_state"], _director_state(director)):
			return _fail("存档剧情状态损坏。")
		if not str(state["director_state"].get("current_script", "")).is_empty():
			return _fail("无法恢复正在执行的剧情。")
		if JSON.stringify(_encode_state(state["director_state"].get("vars", {})), "", true, true) != JSON.stringify(_encode_state(state["director_vars"]), "", true, true):
			return _fail("存档剧情变量不一致。")
	return true

static func _ledger_shape(state: Dictionary, ledger) -> bool:
	if not _object_shape(state, object_state_to_dict(ledger)):
		return false
	var total: int = 0
	for amount in state["accounts"].values():
		if not _integer(amount) or int(amount) < 0:
			return false
		total += int(amount)
	if total != state["initial_total"]:
		return false
	if int(state["initial_total"]) < 0:
		return false
	for name in ["next_item", "next_ticket", "next_journal"]:
		if int(state[name]) < 1:
			return false
	for item in state["items"].values():
		if not item is Dictionary or not item.get("history") is Array:
			return false
		for name in ["id", "owner", "location", "pledged_to"]:
			if not item.get(name) is String:
				return false
	var pledged: Dictionary = {}
	for contract in state["contracts"].values():
		if not contract is Dictionary or not contract.get("item_ids") is Array:
			return false
		for name in ["principal", "signed_day", "due_day"]:
			if not _integer(contract.get(name)):
				return false
		if not _number(contract.get("rate_month")) or not contract.get("journal") is Array or not contract.get("renewals") is Array:
			return false
		if not contract.get("borrower") is String or not state["accounts"].has(contract["borrower"]) or not contract.get("status") is String:
			return false
		if int(contract["principal"]) < 0 or float(contract["rate_month"]) < 0.0:
			return false
		if not ["active", "overdue", "redeemed", "forfeited", "compensated"].has(contract["status"]):
			return false
		for id in contract["item_ids"]:
			if not state["items"].has(id):
				return false
			if ["active", "overdue"].has(contract["status"]):
				if pledged.has(id):
					return false
				pledged[id] = true
	for debt in state["debts"].values():
		if not debt is Dictionary or not debt.get("payments") is Array or not debt.get("guarantee") is Dictionary:
			return false
		for name in ["principal", "outstanding", "signed_day", "due_day"]:
			if not _integer(debt.get(name)):
				return false
		var paid: int = 0
		for payment in debt["payments"]:
			if not payment is Dictionary or not _integer(payment.get("amount")) or int(payment["amount"]) < 0:
				return false
			paid += int(payment["amount"])
		if int(debt["outstanding"]) < 0 or paid + int(debt["outstanding"]) != int(debt["principal"]):
			return false
		if not ["active", "overdue", "settled"].has(debt.get("status", "")):
			return false
		var guarantee: Dictionary = debt["guarantee"]
		if not guarantee.is_empty():
			if not guarantee.get("guarantor") is String or not state["accounts"].has(guarantee["guarantor"]):
				return false
			if not _integer(guarantee.get("limit")) or not _integer(guarantee.get("paid")):
				return false
			if int(guarantee["paid"]) < 0 or int(guarantee["limit"]) < int(guarantee["paid"]):
				return false
	for row in state["journal"]:
		if not row is Dictionary or not _integer(row.get("amount")) or int(row["amount"]) < 0:
			return false
		for name in ["id", "from", "to", "reason", "ref"]:
			if not row.get(name) is String:
				return false
		if not state["accounts"].has(row["from"]) or not state["accounts"].has(row["to"]):
			return false
	return true

static func _session_shape(session) -> bool:
	if not session is Dictionary:
		return false
	if not _definition_map(session.get("_item_defs", {})) or not session.get("_npc_def", {}) is Dictionary:
		return false
	if session.has("npc") and not session["npc"] is String:
		return false
	return true

static func _definition_map(value) -> bool:
	if not value is Dictionary:
		return false
	for definition in value.values():
		if not definition is Dictionary:
			return false
	return true

static func _number_map(value) -> bool:
	if not value is Dictionary:
		return false
	for number in value.values():
		if not _number(number):
			return false
	return true

static func _object_shape(state: Dictionary, expected: Dictionary) -> bool:
	if state.size() != expected.size():
		return false
	for name in expected:
		if not state.has(name):
			return false
		var kind: int = typeof(expected[name])
		if kind == TYPE_FLOAT:
			if not _number(state[name]):
				return false
		elif typeof(state[name]) != kind:
			return false
	return true

static func _runtime_database(state: Dictionary):
	var original = Database.get_db()
	var overlay = original.get_script().new()
	object_state_from_dict(overlay, object_state_to_dict(original))
	for id in state["world"]["npcs"]:
		overlay.cast[id] = state["world"]["npcs"][id]["def"].duplicate(true)
	for visit in state["town_sim"]["visits"]:
		var session: Dictionary = visit.get("session", {})
		for id in session.get("_item_defs", {}):
			overlay.items[id] = session["_item_defs"][id].duplicate(true)
		var id: String = str(session.get("npc", ""))
		if id != "" and session.get("_npc_def", {}) is Dictionary and not session.get("_npc_def", {}).is_empty():
			overlay.cast[id] = session["_npc_def"].duplicate(true)
	for item in state["ledger"]["items"].values():
		var id: String = str(item.get("def_id", ""))
		if id.is_empty() or overlay.items.has(id):
			continue
		var definition: Dictionary = item.duplicate(true)
		for name in ["owner", "location", "pledged_to", "history"]:
			definition.erase(name)
		definition["id"] = id
		overlay.items[id] = definition
	return overlay

static func _has_property(object, name: String) -> bool:
	for property in object.get_property_list():
		if str(property["name"]) == name:
			return true
	return false

static func _copy(value):
	return value.duplicate(true) if value is Dictionary or value is Array else value

# Floats use the same marker as TownSim. Large integer seeds also need a
# marker because Godot's JSON reader otherwise rounds them through doubles.
static func _encode_state(value, encode_large_integers: bool = true):
	if value is float:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, value)
		return {"$town_f64": bytes.hex_encode()}
	if value is int and encode_large_integers and (value > 9007199254740991 or value < -9007199254740991):
		return {"$town_i64": str(value)}
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _encode_state(value[key], encode_large_integers)
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_encode_state(entry, encode_large_integers))
		return result
	return value

static func _decode_state(value):
	if value is Dictionary:
		if value.size() == 1 and value.has("$town_f64"):
			return str(value["$town_f64"]).hex_decode().decode_double(0)
		if value.size() == 1 and value.has("$town_i64"):
			return int(value["$town_i64"])
		var result: Dictionary = {}
		for key in value:
			result[key] = _decode_state(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_decode_state(entry))
		return result
	if value is float and value == floor(value) and absf(value) <= 9007199254740991.0:
		return int(value)
	return value

static func _json_safe(value, depth: int = 0) -> bool:
	if depth > 128:
		return false
	if value is Dictionary:
		if value.size() == 1 and value.has("$town_f64"):
			var marker = value["$town_f64"]
			if not marker is String or marker.length() != 16 or not marker.is_valid_hex_number(false):
				return false
			return is_finite(marker.hex_decode().decode_double(0))
		if value.size() == 1 and value.has("$town_i64"):
			var marker = value["$town_i64"]
			return marker is String and marker.is_valid_int() and str(int(marker)) == marker
		for key in value:
			if not key is String or not _json_safe(value[key], depth + 1):
				return false
		return true
	if value is Array:
		for entry in value:
			if not _json_safe(entry, depth + 1):
				return false
		return true
	return value == null or value is bool or value is int or value is String or (value is float and is_finite(value))

static func _integer(value) -> bool:
	return value is int

static func _number(value) -> bool:
	return value is int or (value is float and is_finite(value))

static func _fail(message: String) -> bool:
	last_error = message
	return false

static func _empty(message: String) -> Dictionary:
	last_error = message
	return {}
