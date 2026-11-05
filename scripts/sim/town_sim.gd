# Deterministic town coordinator. All mutable simulation state is JSON-safe in s;
# the pack is read-only and each random draw has its own semantic key.
class_name TownSim
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const TownCondModule = preload("res://scripts/sim/town_cond.gd")
const Pressure = preload("res://scripts/sim/pressure_model.gd")
const Wheel = preload("res://scripts/sim/world_wheel.gd")
const Costs = preload("res://scripts/sim/living_costs.gd")
const Life = preload("res://scripts/sim/npc_life.gd")
const Rumors = preload("res://scripts/sim/rumor_net.gd")
const InstitutionsModule = preload("res://scripts/sim/institutions.gd")
const UnlocksModule = preload("res://scripts/sim/unlocks.gd")
const Items = preload("res://scripts/sim/item_gen.gd")
const MindModule = preload("res://scripts/core/mind.gd")

signal news(entry)

var pack: Dictionary = {}
var s: Dictionary = {}
var _world_ref: WeakRef = null
var world:
	get:
		return _world_ref.get_ref() if _world_ref != null else null
	set(value):
		_world_ref = weakref(value) if value != null else null
var templates: Dictionary = {}

func _init(p_pack: Dictionary = {}, seed: int = 0, p_world = null) -> void:
	if not p_pack.is_empty():
		setup(p_pack, seed, p_world)

func setup(p_pack: Dictionary, seed: int, p_world = null) -> void:
	pack = p_pack.duplicate(true)
	world = p_world
	var initial: Dictionary = pack.get("initial", {})
	var difficulty: String = str(pack.get("default_difficulty", "常年"))
	var difficulty_spec: Dictionary = pack.get("difficulty", {}).get(difficulty, {})
	s = {"seed": seed, "day": 0, "slot": 0, "minute": _wake(),
		"difficulty": difficulty, "weather": str(initial.get("weather", "")),
		"pressures": {}, "wheel_last": {}, "unlocked": {},
		"flags": initial.get("flags", {}).duplicate(true), "flags_today": {},
		"stats": initial.get("stats", pack.get("balance", {}).get("initial_stats", {})).duplicate(true),
		"cash": {"player": int(initial.get("cash", difficulty_spec.get("initial_cash", 0)))},
		"npc_cash": {}, "tickets": {}, "known": {}, "seen": {}, "queue": [], "seq": 0,
		"spawns": [], "influence_spent": {}, "stolen_stock": 0, "day_report": {},
		"player_rumors": {}, "bills": [], "bill_requests": {}, "action_requests": {},
		"visits": [], "emitted_visits": {}, "npc_locations": {}, "pending_events": [],
		"event_seq": 0, "published_news": {}, "news_entries": [], "player_feed": [],
		"dev_entries": [], "invitations": [], "spine_done": {}, "day_ended": true,
		"summary": {}, "journal_start": 0, "stock": [], "pawn_items": {},
		"cash_journal": [], "transfer_requests": {}, "initial_total": 0}
	for key in _sorted(pack.get("pressures", {}).keys()):
		s["pressures"][key] = float(pack["pressures"][key]["base"])
	for key in _sorted(pack.get("buildings", {}).keys()):
		if bool(pack["buildings"][key].get("unlocked", false)):
			s["unlocked"][key] = true
	for key in _sorted(pack.get("npcs", {}).keys()):
		var amount: int = int(pack["npcs"][key].get("cash", 0))
		s["npc_cash"][key] = amount
		s["cash"][key] = amount
		s["known"][key] = {}
	for account in s["cash"]:
		s["initial_total"] = int(s["initial_total"]) + int(s["cash"][account])
	var file = FileAccess.open("res://data/town/item_templates.json", FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			templates = parsed
	if world != null:
		world.town = self
		_isolate_runtime_db()
		_ensure_account("player")
		for key in _sorted(pack.get("npcs", {}).keys()):
			_ensure_account(str(key))
		_sync_cash()
		for flag in s["flags"]:
			if not world.flags.has(flag):
				world.flags[flag] = s["flags"][flag]
	_sync_world()

func start_day() -> Dictionary:
	if s.is_empty():
		return {}
	s["day"] = int(s["day"]) + 1
	s["slot"] = 0
	s["minute"] = _wake()
	s["flags_today"] = {}
	if _market_day():
		s["flags_today"]["market_day"] = true
	s["day_report"] = {"day": int(s["day"]), "weekday": weekday(), "news": []}
	s["visits"] = []
	s["emitted_visits"] = {}
	s["pending_events"] = []
	s["day_ended"] = false
	s["summary"] = {}
	_sync_cash()
	if world != null:
		s["journal_start"] = world.ledger.journal.size()
	_sync_world()
	Rumors.deliver(pack, s)
	Pressure.step(pack, s)
	for mode in ["exogenous", "endogenous"]:
		for wheel in pack.get("wheels", []):
			if str(wheel.get("mode", "exogenous")) == mode:
				Wheel.spin(pack, s, wheel, Callable(self, "_effect"), world)
	for deck in Wheel.decks(pack):
		if s["unlocked"].has(deck["building"]):
			Wheel.spin(pack, s, deck, Callable(self, "_effect"), world)
	Pressure.feeds(pack, s)
	_spine()
	var newly_unlocked: Array = s["day_report"].get("unlocks", []).duplicate()
	for building in UnlocksModule.check(pack, s, world):
		if not newly_unlocked.has(building):
			newly_unlocked.append(building)
	s["day_report"]["unlocks"] = newly_unlocked
	Costs.generate(pack, s, world)
	_sync_world()
	var plan: Array = Life.plan(pack, s, world)
	for visit in plan:
		visit["status"] = "planned"
		if str(visit.get("storylet", "")) != "":
			visit["session"] = _story_session(str(visit["storylet"]))
		else:
			visit["session"] = Items.session(templates, pack, s, visit, world)
		_register_session(visit["session"])
	s["visits"] = plan
	s["day_report"]["visits"] = plan
	s["day_report"]["weather"] = s["weather"]
	s["day_report"]["pressures"] = s["pressures"].duplicate(true)
	s["npc_locations"] = {}
	for npc in _sorted(pack.get("npcs", {}).keys()):
		s["npc_locations"][npc] = npc_location(str(npc))
	_collect_news()
	for bill in s["bills"]:
		if str(bill["status"]) in ["due", "overdue"] and int(bill["due_day"]) <= int(s["day"]):
			_queue_event({"type": "bill_due", "bill": _visible_bill(bill)}, _wake())
	s["dev_entries"].append(s["day_report"].duplicate(true))
	return _day_plan()

func set_minute(m: int) -> Array:
	if s.is_empty() or m < int(s["minute"]):
		return []
	var target: int = mini(m, _sleep())
	var current: int = int(s["minute"])
	var events: Array = []
	var boundaries: Array = _slot_minutes()
	for index in range(boundaries.size()):
		var at: int = int(boundaries[index])
		if at <= current or at > target:
			continue
		s["minute"] = at
		s["slot"] = index
		_sync_world()
		Rumors.deliver(pack, s)
		events.append({"type": "slot_changed", "slot": index, "minute": at})
		for npc in _sorted(pack.get("npcs", {}).keys()):
			var before: String = str(s["npc_locations"].get(npc, ""))
			var after: String = npc_location(str(npc), at)
			if before != after:
				s["npc_locations"][npc] = after
				events.append({"type": "npc_move", "npc": npc, "from": before, "to": after, "minute": at})
	s["minute"] = target
	s["slot"] = _slot_at(target)
	_sync_world()
	Rumors.deliver(pack, s)
	for visit in s["visits"]:
		var vid: String = str(visit["id"])
		if int(visit["minute"]) <= target and not s["emitted_visits"].has(vid):
			s["emitted_visits"][vid] = true
			if str(visit.get("status", "planned")) == "planned":
				visit["status"] = "waiting"
				events.append({"type": "visit_due", "visit": visit.duplicate(true), "minute": int(visit["minute"])})
	_collect_news()
	var keep: Array = []
	for event in s["pending_events"]:
		if int(event["minute"]) <= target:
			events.append(event.duplicate(true))
		else:
			keep.append(event)
	s["pending_events"] = keep
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["minute"]) != int(b["minute"]):
			return int(a["minute"]) < int(b["minute"])
		var order_a: int = _event_order(str(a["type"]))
		var order_b: int = _event_order(str(b["type"]))
		if order_a != order_b:
			return order_a < order_b
		var seq_a: int = int(a.get("_seq", 0))
		var seq_b: int = int(b.get("_seq", 0))
		if seq_a != seq_b:
			return seq_a < seq_b
		if str(a["type"]) == "npc_move":
			return str(a["npc"]) < str(b["npc"])
		if str(a["type"]) == "visit_due":
			return str(a["visit"]["id"]) < str(b["visit"]["id"])
		return JSON.stringify(a, "", true, true) < JSON.stringify(b, "", true, true))
	for event in events:
		event.erase("_seq")
	return events

func end_day() -> Dictionary:
	if s.is_empty():
		return {}
	if bool(s["day_ended"]):
		return s["summary"].duplicate(true)
	set_minute(_sleep())
	for visit in s["visits"]:
		if str(visit["status"]) in ["planned", "waiting"]:
			visit_missed(str(visit["id"]))
	var contracts: Array = []
	var debts: Array = []
	if world != null:
		var grace: int = int(pack.get("balance", {}).get("contract_grace_days", 0))
		for tid in world.ledger.tick_contracts(int(s["day"]), grace):
			var contract: Dictionary = world.ledger.contracts[tid]
			contracts.append({"id": tid, "status": contract["status"], "due_day": contract["due_day"]})
		world.ledger.tick_debts(int(s["day"]))
		for did in _sorted(world.ledger.debts.keys()):
			var debt: Dictionary = world.ledger.debts[did]
			if str(debt["status"]) == "overdue":
				debts.append({"id": did, "due_day": debt["due_day"], "outstanding": debt["outstanding"]})
	else:
		var grace: int = int(pack.get("balance", {}).get("contract_grace_days", 0))
		for npc in _sorted(s["tickets"].keys()):
			var ticket: Dictionary = s["tickets"][npc]
			var due: int = int(ticket.get("due", ticket.get("due_day", 0)))
			if int(s["day"]) <= due:
				continue
			if str(ticket.get("status", "active")) == "active":
				ticket["status"] = "overdue"
				contracts.append({"id": npc, "status": "overdue", "due_day": due})
			elif str(ticket["status"]) == "overdue" and int(s["day"]) > due + grace:
				for item in s["pawn_items"].get(npc, []):
					s["stock"].append(item.duplicate(true))
				s["pawn_items"].erase(npc)
				s["tickets"].erase(npc)
				contracts.append({"id": npc, "status": "forfeited", "due_day": due})
	var consequences: Array = Costs.end_day(pack, s, world)
	for row in consequences:
		if str(row.get("text", "")) != "":
			_news(str(row["text"]), str(row.get("source", "家用簿")), "seen")
		for effect in row.get("effects", []):
			_effect(effect, str(row.get("bill_id", "家用簿")))
	# PressureModel.step performs one daily decay at dawn, together with the
	# exogenous update. Ending a day must not apply a second decay or future draw.
	_collect_news()
	_sync_cash()
	var handled: Array = []
	var missed: Array = []
	for visit in s["visits"]:
		var visible: Dictionary = {"id": visit["id"], "who": visit["who"], "intent": visit["intent"], "status": visit["status"]}
		if str(visit["status"]) == "missed":
			missed.append(visible)
		else:
			handled.append(visible)
	var due_total: int = 0
	var paid_total: int = 0
	for bill in s["bills"]:
		if int(bill.get("created_day", 0)) == int(s["day"]):
			due_total += int(bill["amount"])
			paid_total += int(bill.get("paid", 0))
	var summary: Dictionary = {"day": int(s["day"]), "weather": s["weather"], "cash": _balance("player"),
		"bill_total": due_total, "bill_paid": paid_total, "unpaid": _unpaid(), "bills": bills(),
		"handled": handled, "missed": missed, "contracts": contracts, "debts": debts,
		"consequences": _visible_consequences(consequences)}
	if world != null:
		summary["flows"] = world.ledger.day_flows(int(s["journal_start"]))
	s["summary"] = summary
	s["day_ended"] = true
	return summary.duplicate(true)

func npc_location(npc_id: String, minute: int = -1) -> String:
	if not Life.present(pack, s, npc_id, world):
		return ""
	if world != null and world.npcs.has(npc_id) and not bool(world.npcs[npc_id].get("present", true)):
		return ""
	return Life.location(pack, s, npc_id, minute)

func npcs_at(place: String) -> Array:
	var result: Array = []
	for npc in _sorted(pack.get("npcs", {}).keys()):
		if npc_location(str(npc)) == place:
			result.append(npc)
	return result

func building_state(b_id: String) -> String:
	if not pack.get("buildings", {}).has(b_id) or not bool(s["unlocked"].get(b_id, false)):
		return "locked"
	var building: Dictionary = pack["buildings"][b_id]
	if b_id == "sunfu" and str(building.get("kind", "")) == "locked_visible":
		return "locked"
	var hours = building.get("hours", [_wake(), _sleep()])
	if hours is Dictionary:
		hours = hours.get("weekday:%d" % weekday(), hours.get("default", [_wake(), _sleep()]))
	if not hours is Array or hours.size() != 2:
		return "closed"
	var minute: int = int(s["minute"])
	var opening: int = int(hours[0])
	var closing: int = int(hours[1])
	var open_now: bool = minute >= opening and minute < closing
	if closing < opening:
		open_now = minute >= opening or minute < closing
	if b_id == "market" and not _market_day():
		open_now = false
	if bool(s["flags_today"].get(b_id + "_closed", false)):
		open_now = false
	return "open" if open_now else "closed"

func bills() -> Array:
	var result: Array = []
	for bill in s.get("bills", []):
		result.append(_visible_bill(bill))
	return result

func pay_bill(bill_id: String, amount: int, request_id: String) -> Dictionary:
	if request_id != "" and s["bill_requests"].has(request_id):
		var receipt: Dictionary = s["bill_requests"][request_id]
		if str(receipt["bill_id"]) != bill_id or int(receipt.get("requested_amount", amount)) != amount:
			return {"ok": false, "bill_id": bill_id, "paid": 0, "reason": "request_conflict"}
		return receipt.duplicate(true)
	var result: Dictionary = {"ok": false, "bill_id": bill_id, "paid": 0, "reason": "unknown_bill"}
	for bill in s["bills"]:
		if str(bill["id"]) != bill_id:
			continue
		var remaining: int = maxi(0, int(bill["amount"]) - int(bill.get("paid", 0)))
		if str(bill["status"]) in ["paid", "waived"] or remaining == 0:
			result = {"ok": true, "bill_id": bill_id, "paid": 0, "remaining": 0, "status": bill["status"]}
			break
		var paid: int = mini(mini(maxi(0, amount), remaining), _balance("player"))
		if paid <= 0:
			result["reason"] = "insufficient_funds" if amount > 0 else "invalid_amount"
			break
		var payee: String = str(bill["payee"])
		_ensure_account(payee)
		var journal: String = _transfer("player", payee, paid, str(bill["label"]), bill_id,
			"town_bill:" + request_id if request_id != "" else "")
		if journal == "":
			result["reason"] = "transfer_failed"
			break
		bill["paid"] = int(bill.get("paid", 0)) + paid
		remaining -= paid
		if remaining == 0:
			bill["status"] = "paid"
		result = {"ok": true, "bill_id": bill_id, "paid": paid, "remaining": remaining, "status": bill["status"], "journal": journal}
		break
	if request_id != "" and bool(result["ok"]):
		result["requested_amount"] = amount
		s["bill_requests"][request_id] = result.duplicate(true)
	_sync_cash()
	return result

func visits_today() -> Array:
	return s.get("visits", []).duplicate(true)

func visit_result(visit_id: String, outcome: Dictionary) -> void:
	for visit in s["visits"]:
		if str(visit["id"]) != visit_id or str(visit["status"]) in ["completed", "missed"]:
			continue
		var accepted: bool = bool(outcome.get("accepted", false)) or str(outcome.get("result", "")) in ["accept", "accepted", "deal"]
		visit["outcome"] = outcome.duplicate(true)
		# Pure mode owns its cash/item settlement. Witnesses can observe an
		# actual intake only after that settlement succeeds; attached worlds
		# already settle their transaction through Session.
		var settled: bool = accepted
		if world == null and accepted:
			settled = _record_pure_trade(visit, outcome)
		if settled and str(visit["intent"]) == "sell_stolen":
			player_act("accept_stolen", {"actor": visit["who"], "building": "pawnshop", "event_id": visit_id})
		visit["status"] = "completed"
		if str(visit["intent"]) == "gossip" and pack.get("npcs", {}).has(visit["who"]):
			hear(str(visit["who"]))
		_sync_cash()
		return

func visit_missed(visit_id: String) -> void:
	for visit in s["visits"]:
		if str(visit["id"]) == visit_id and str(visit["status"]) in ["planned", "waiting"]:
			visit["status"] = "missed"
			visit["outcome"] = {"result": "missed"}
			return

func player_act(act: String, args: Dictionary) -> Dictionary:
	var normalized: String = act
	match act:
		"收赃", "sell_stolen", "accept_stolen_goods": normalized = "accept_stolen"
		"举报", "report": normalized = "report_stolen"
		"送礼", "give_gift": normalized = "gift"
		"宵禁", "break_curfew": normalized = "curfew_break"
	var details: Dictionary = args.duplicate(true)
	if not details.has("building"):
		details["building"] = "桥头街" if normalized == "curfew_break" else "pawnshop"
	if not details.has("actor"):
		details["actor"] = "player"
	var request: String = str(details.get("request_id", details.get("event_id", "")))
	if request != "" and s["action_requests"].has(request):
		return s["action_requests"][request].duplicate(true)
	var result: Dictionary = InstitutionsModule.norm(pack, s, normalized, details, world)
	for effect in result.get("effects", []):
		_effect(effect, normalized)
	if normalized == "accept_stolen" and not bool(result.get("replayed", false)):
		s["stolen_stock"] = int(s["stolen_stock"]) + int(details.get("count", 1))
	_collect_news()
	var visible: Dictionary = {"ok": bool(result.get("ok", true)), "act": normalized}
	for key in ["text", "paid", "bill_id", "reason", "replayed"]:
		if result.has(key):
			visible[key] = result[key]
	if request != "":
		s["action_requests"][request] = visible.duplicate(true)
	return visible

func hear(npc_id: String) -> Array:
	var rows: Array = Rumors.hear(pack, s, npc_id, world)
	for row in rows:
		s["player_feed"].append(row.duplicate(true))
	return rows

func notice() -> Dictionary:
	var prices: Dictionary = {}
	for category in _sorted(pack.get("prices", {}).keys()):
		prices[category] = price(str(category))
	var invitations: Array = []
	for invitation in s.get("invitations", []):
		if int(invitation.get("due_day", invitation.get("day", s["day"]))) >= int(s["day"]):
			var visible: Dictionary = {}
			for key in ["id", "label", "who", "building", "payee", "amount", "received_day", "due_day", "text"]:
				if invitation.has(key):
					visible[key] = invitation[key]
			invitations.append(visible)
	var today_news: Array = []
	for entry in s.get("news_entries", []):
		if int(entry["day"]) == int(s["day"]):
			today_news.append(entry.duplicate(true))
	return {"weather": s.get("weather", ""), "prices": prices,
		"headline": str(today_news[0]["text"]) if not today_news.is_empty() else "",
		"news": today_news, "invitations": invitations, "market_day": _market_day()}

func price(category: String) -> int:
	var definition = pack.get("prices", {}).get(category, {})
	if definition is Dictionary:
		var scale: String = str(definition.get("scale", ""))
		var multiplier: float = float(s["pressures"].get(scale, 1.0)) if scale != "" else 1.0
		return maxi(0, int(round(float(definition.get("base", 0)) * multiplier)))
	return maxi(0, int(definition))

func dev_log() -> Array:
	return s.get("dev_entries", []).duplicate(true)

func to_dict() -> Dictionary:
	_sync_cash()
	return _encode_state(s)

func from_dict(d: Dictionary) -> void:
	s = _decode_state(d)
	if world != null:
		world.town = self
		for visit in s.get("visits", []):
			_register_session(visit.get("session", {}))
	_sync_world()

func save_json() -> String:
	return JSON.stringify(to_dict(), "", true, true)

func load_json(value: String) -> void:
	var parsed = JSON.parse_string(value)
	if parsed is Dictionary:
		from_dict(parsed)

func plant_rumor(key: String, origin: String = "player", conf: float = 1.0) -> void:
	Rumors.plant(pack, s, key, origin, conf)

func plant(key: String, origin: String, conf: float = 1.0) -> void:
	plant_rumor(key, origin, conf)

func share_rumors(npc_id: String) -> Array:
	return hear(npc_id)

func add_influence(key: String, amount: float, source: String) -> float:
	return Pressure.add_influence(pack, s, key, amount, source)

func cond(condition) -> bool:
	return TownCondModule.test(condition, pack, s, world)

func weekday() -> int:
	return (int(pack.get("time", {}).get("start_weekday", 0)) + int(s.get("day", 0))) % 7

func season() -> int:
	var days: int = maxi(1, int(pack.get("time", {}).get("season_days", 1)))
	return int(floor(float(s.get("day", 0)) / float(days))) % 4

func abs_slot() -> int:
	return int(s["day"]) * _slot_minutes().size() + int(s["slot"])

func advance_day() -> Dictionary:
	return start_day()

func _effect(effect: Dictionary, source: String) -> void:
	match str(effect.get("op", "")):
		"weather": s["weather"] = str(effect["value"])
		"pressure_add":
			var key: String = str(effect["key"])
			if not pack.get("pressures", {}).has(key):
				return
			var definition: Dictionary = pack["pressures"][key]
			if str(definition["kind"]) == "endogenous":
				add_influence(key, float(effect["value"]), source)
			else:
				s["pressures"][key] = clampf(float(s["pressures"][key]) + float(effect["value"]), float(definition["min"]), float(definition["max"]))
		"news": _news(str(effect["text"]), str(effect.get("via", source)), str(effect.get("source", "heard")), float(effect.get("conf", 1.0)))
		"flag_today": s["flags_today"][effect["key"]] = effect.get("value", true)
		"flag_set":
			s["flags"][effect["key"]] = effect.get("value", true)
			if world != null:
				world.flags[effect["key"]] = effect.get("value", true)
		"bill": _effect_bill(effect, source)
		"rumor": plant_rumor(str(effect["key"]), str(effect["origin"]), float(effect.get("conf", 1.0)))
		"spawn_visit":
			var spawn: Dictionary = effect.duplicate(true)
			spawn.erase("op")
			spawn["due"] = int(s["day"]) + int(effect.get("delay_days", 0))
			s["spawns"].append(spawn)
		"npc_feel":
			if world != null:
				for npc in npcs_at(str(effect.get("where", ""))):
					if world.npcs.has(npc):
						MindModule.feel(world.npcs[npc], {str(effect["key"]): float(effect["value"])})
		"institution":
			var result: Dictionary = InstitutionsModule.act(pack, s, str(effect["id"]), str(effect["act"]), world)
			for nested in result.get("effects", []):
				_effect(nested, source)
		"unlock":
			var building: String = str(effect["building"])
			if not s["unlocked"].has(building):
				s["unlocked"][building] = true
				_report("unlocks", building)
				var definition: Dictionary = pack.get("buildings", {}).get(building, {})
				if definition.has("news"):
					_news(str(definition["news"]), str(definition.get("name", building)), "seen")
		"item_drop":
			var category: String = str(effect.get("category", effect.get("item", "")))
			var item: Dictionary = Items.generate(templates, pack, s, [int(s["day"]), source, "drop"], category)
			if world != null:
				world.ledger.add_item(item, "player", str(effect.get("location", "stock")))
			else:
				if not s.has("stock"):
					s["stock"] = []
				s["stock"].append(item)
		"invitation":
			var invitation: Dictionary = effect.duplicate(true)
			invitation.erase("op")
			invitation["received_day"] = int(s["day"])
			var lead: int = int(effect.get("delay_days", 0))
			var range_days: Array = effect.get("lead_days", [])
			if range_days.size() == 2:
				var low: int = int(range_days[0])
				var high: int = maxi(low, int(range_days[1]))
				lead = low + int(floor(R.draw(int(s["seed"]), "invitation:" + source, [int(s["day"]), str(effect.get("id", ""))]) * float(high - low + 1)))
			invitation["due_day"] = int(effect.get("due_day", int(s["day"]) + lead))
			invitation["id"] = "%s:d%d" % [str(effect.get("id", source)), int(s["day"])]
			s["invitations"].append(invitation)
			if effect.has("text"):
				_news(str(effect["text"]), str(effect.get("who", "来信")), "seen")

func _effect_bill(effect: Dictionary, source: String) -> void:
	var definition: Dictionary = effect.duplicate(true)
	definition.erase("op")
	var key: String = str(effect.get("id", source))
	definition["id"] = str(effect.get("cost_id", "emergency"))
	var id: String = "bill:%s:d%d" % [key, int(s["day"])]
	var bill: Dictionary = Costs.add(pack, s, definition, source, id, world)
	if not bill.is_empty():
		_report("bills", bill.duplicate(true))

func _spine() -> void:
	for row in pack.get("spine", []):
		var id: String = str(row["id"])
		if int(row["day"]) <= int(s["day"]) and not s["spine_done"].has(id) and cond(row.get("when", {})):
			s["spine_done"][id] = true
			for effect in row.get("effects", []):
				_effect(effect, "spine:" + id)

func _news(text: String, via: String, source: String = "heard", confidence: float = 1.0) -> void:
	_report("news", {"day": int(s["day"]), "minute": int(s["minute"]), "text": text, "via": via, "source": source, "conf": confidence})

func _collect_news() -> void:
	for value in s["day_report"].get("news", []):
		var entry: Dictionary
		if value is Dictionary:
			entry = value.duplicate(true)
		else:
			entry = {"text": str(value), "via": "镇上", "source": "heard", "conf": 1.0}
		entry["day"] = int(entry.get("day", s["day"]))
		entry["minute"] = int(entry.get("minute", s["minute"]))
		entry["via"] = str(entry.get("via", "镇上"))
		entry["source"] = str(entry.get("source", "heard"))
		entry["conf"] = float(entry.get("conf", 1.0))
		var key: String = JSON.stringify(entry, "", true, true)
		if s["published_news"].has(key):
			continue
		s["published_news"][key] = true
		s["news_entries"].append(entry)
		s["player_feed"].append(entry.duplicate(true))
		_queue_event({"type": "news", "entry": entry.duplicate(true)}, int(entry["minute"]))
		if world != null:
			world.note("镇上消息", str(entry["text"]), str(entry["source"]), str(entry["via"]), float(entry["conf"]))
		news.emit(entry.duplicate(true))

func _report(kind: String, value) -> void:
	if not s["day_report"].has(kind):
		s["day_report"][kind] = []
	s["day_report"][kind].append(value)

func _queue_event(event: Dictionary, minute: int) -> void:
	s["event_seq"] = int(s["event_seq"]) + 1
	event["minute"] = minute
	event["_seq"] = int(s["event_seq"])
	s["pending_events"].append(event)

func _day_plan() -> Dictionary:
	return {"day": int(s["day"]), "weekday": weekday(), "weather": s["weather"], "notice": notice(),
		"bills": bills(), "unlocked_today": s["day_report"].get("unlocks", []).duplicate(), "visits": visits_today()}

func _story_session(id: String) -> Dictionary:
	if world != null and world.db.sessions.has(id):
		return world.db.sessions[id].duplicate(true)
	var path: String = "res://data/sessions/%s.json" % id
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			return parsed
	return {}

func _isolate_runtime_db() -> void:
	# World.setup uses DB.get_db(). Generated definitions belong to one game,
	# otherwise new seeds contaminate the singleton and earlier worlds.
	if world == null or world.db == null:
		return
	var original = world.db
	var overlay = original.get_script().new()
	for property in original.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = str(property["name"])
		var value = original.get(name)
		overlay.set(name, value.duplicate(true) if value is Dictionary or value is Array else value)
	world.db = overlay

func _register_session(session: Dictionary) -> void:
	var npc_id: String = str(session.get("npc", ""))
	var definition: Dictionary = session.get("_npc_def", {})
	if npc_id != "":
		var entrant_cash: int = int(definition.get("cash", 0))
		if world != null:
			if not world.ledger.accounts.has(npc_id):
				world.ledger.open_account(npc_id, entrant_cash)
		elif not s["cash"].has(npc_id):
			s["cash"][npc_id] = entrant_cash
			s["initial_total"] = int(s["initial_total"]) + entrant_cash
	if world == null:
		return
	for id in _sorted(session.get("_item_defs", {}).keys()):
		world.db.items[id] = session["_item_defs"][id].duplicate(true)
	if npc_id != "" and not definition.is_empty() and not world.npcs.has(npc_id):
		world.db.cast[npc_id] = definition.duplicate(true)
		world.npcs[npc_id] = {"id": npc_id, "def": definition, "name": definition.get("name", npc_id),
			"label": definition.get("label", npc_id), "persona": MindModule.make_persona(definition),
			"rel": {"player": MindModule.fresh_rel()}, "location": "德厚当", "present": true, "knows": {}, "log": []}

func _record_pure_trade(visit: Dictionary, outcome: Dictionary) -> bool:
	var npc: String = str(visit["who"])
	var session: Dictionary = visit.get("session", {})
	var amount: int = int(outcome.get("price", outcome.get("principal", 0)))
	visit["outcome"]["settled"] = false
	if amount <= 0:
		return false
	_ensure_account(npc)
	var mode: String = str(session.get("mode", "buy"))
	var redeem: bool = str(visit["intent"]) == "redeem" and s["tickets"].has(npc)
	var journal: String = _transfer(npc if mode == "sell" or redeem else "player", "player" if mode == "sell" or redeem else npc,
		amount, "柜台成交", str(visit["id"]), "visit:" + str(visit["id"]))
	if journal == "":
		return false
	if redeem:
		s["tickets"].erase(npc)
		s["pawn_items"].erase(npc)
	elif mode == "pawn":
		var terms: Dictionary = session.get("terms", {})
		s["tickets"][npc] = {"due": int(s["day"]) + int(terms.get("days", 0)), "principal": amount,
			"signed_day": int(s["day"]), "rate_month": float(terms.get("rate_month", 0.0)), "status": "active"}
		s["pawn_items"][npc] = session.get("_item_defs", {}).values().duplicate(true)
	elif mode == "buy":
		for item in session.get("_item_defs", {}).values():
			s["stock"].append(item.duplicate(true))
	elif mode == "sell":
		var keep: Array = []
		var sold: Array = outcome.get("stock", session.get("stock", []))
		for item in s["stock"]:
			if not sold.has(str(item.get("def_id", item.get("id", "")))):
				keep.append(item)
		s["stock"] = keep
	visit["outcome"]["settled"] = true
	return true

func _ensure_account(name: String) -> void:
	if world != null:
		if not world.ledger.accounts.has(name):
			world.ledger.open_account(name, 0)
	elif not s["cash"].has(name):
		s["cash"][name] = 0

func _balance(name: String) -> int:
	return int(world.ledger.balance(name)) if world != null else int(s["cash"].get(name, 0))

func _transfer(from: String, to: String, amount: int, reason: String, ref: String, request: String) -> String:
	if world != null:
		return world.ledger.transfer(from, to, amount, reason, ref, request)
	if request != "" and s["transfer_requests"].has(request):
		return str(s["transfer_requests"][request])
	if amount <= 0 or _balance(from) < amount:
		return ""
	_ensure_account(to)
	s["cash"][from] = _balance(from) - amount
	s["cash"][to] = _balance(to) + amount
	var journal: String = "town:J%d" % (s["cash_journal"].size() + 1)
	s["cash_journal"].append({"id": journal, "from": from, "to": to, "amount": amount, "reason": reason, "ref": ref})
	if request != "":
		s["transfer_requests"][request] = journal
	return journal

func _sync_cash() -> void:
	if world != null:
		s["cash"] = world.ledger.accounts.duplicate(true)
	for npc in _sorted(pack.get("npcs", {}).keys()):
		s["npc_cash"][npc] = _balance(str(npc))

func _sync_world() -> void:
	if world == null or s.is_empty():
		return
	world.day = int(s["day"])
	world.slot = int(s["slot"])
	world.weather = str(s["weather"])
	world.prev_rice_mod = world.rice_mod
	world.prev_med_mod = world.med_mod
	world.rice_mod = float(s["pressures"].get("rice_price", 1.0))
	world.med_mod = float(s["pressures"].get("med_price", 1.0))
	s["flags"] = world.flags.duplicate(true)
	for key in _sorted(s["stats"].keys()):
		s["stats"][key] = world.stat(str(key))
	s["npc_rel"] = {}
	for npc in _sorted(pack.get("npcs", {}).keys()):
		if world.npcs.has(npc):
			s["npc_rel"][npc] = world.npcs[npc].get("rel", {}).duplicate(true)
	for npc in _sorted(pack.get("npcs", {}).keys()):
		if world.npcs.has(npc):
			world.npcs[npc]["location"] = npc_location(str(npc))

func _visible_bill(bill: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ["id", "label", "amount", "payee", "building", "due_day", "status", "paid", "source", "date", "created_day", "min", "max", "range", "grace_days", "cost_id"]:
		if bill.has(key):
			result[key] = bill[key].duplicate(true) if bill[key] is Dictionary or bill[key] is Array else bill[key]
	return result

func _visible_consequences(rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		result.append({"bill_id": row.get("bill_id", ""), "text": row.get("text", ""), "date": row.get("date", s["day"]), "source": row.get("source", "家用簿")})
	return result

func _unpaid() -> int:
	var total: int = 0
	for bill in s["bills"]:
		if str(bill["status"]) in ["due", "overdue"] and int(bill["due_day"]) <= int(s["day"]):
			total += maxi(0, int(bill["amount"]) - int(bill.get("paid", 0)))
	return total

func _market_day() -> bool:
	var time: Dictionary = pack.get("time", {})
	var period: int = int(time.get("market_period_days", 0))
	return bool(s.get("flags_today", {}).get("market_day", false)) or (period > 0 and (int(s["day"]) - int(time.get("market_offset", 0))) % period == 0)

func _wake() -> int:
	return int(pack.get("time", {}).get("wake_minute", 360))

func _sleep() -> int:
	return int(pack.get("time", {}).get("sleep_minute", 1440))

func _slot_minutes() -> Array:
	var result: Array = []
	for hour in pack.get("time", {}).get("slot_hours", [6, 9, 12, 15, 18, 21]):
		result.append(int(hour) * 60)
	return result

func _slot_at(minute: int) -> int:
	var slot: int = 0
	var starts: Array = _slot_minutes()
	for index in range(starts.size()):
		if minute >= int(starts[index]):
			slot = index
	return slot

static func _event_order(type: String) -> int:
	match type:
		"slot_changed": return 0
		"npc_move": return 1
		"news": return 2
		"bill_due": return 3
		_: return 4

static func _sorted(values: Array) -> Array:
	var result: Array = values.duplicate()
	result.sort()
	return result

# JSON parsers round decimal floats and parse integer tokens as floats. Encode
# every original float by IEEE-754 bytes so round-trips preserve exact state.
static func _encode_state(value):
	if value is float:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(8)
		bytes.encode_double(0, value)
		return {"$town_f64": bytes.hex_encode()}
	if value is Dictionary:
		var result: Dictionary = {}
		for key in _sorted(value.keys()):
			result[key] = _encode_state(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_encode_state(entry))
		return result
	return value

static func _decode_state(value):
	if value is Dictionary:
		if value.size() == 1 and value.has("$town_f64"):
			var bytes: PackedByteArray = str(value["$town_f64"]).hex_decode()
			if bytes.size() == 8:
				return bytes.decode_double(0)
		var result: Dictionary = {}
		for key in _sorted(value.keys()):
			result[key] = _decode_state(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_decode_state(entry))
		return result
	if value is float and value == floor(value):
		return int(value)
	return value
