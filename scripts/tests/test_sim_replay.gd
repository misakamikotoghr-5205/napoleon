# Full-state replay and public API integration checks. JSON has one numeric
# type, so integral floats and ints compare alike; fractional floats compare
# their IEEE-754 bytes. No rounding or epsilon can hide a replay divergence.
extends SceneTree

const Sim = preload("res://scripts/sim/town_sim.gd")
const World = preload("res://scripts/core/world.gd")

var failures: Array = []
var checks: int = 0

func _initialize() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/town_pack.json"))
	_check(pack is Dictionary and not pack.is_empty(), "town pack loads")
	if pack is Dictionary and not pack.is_empty():
		_test_thirty_day_seeds(pack)
		_test_day_ten_json_replay(pack)
		_test_exogenous_isolation(pack)
		_test_minute_partition(pack)
		_test_bill_requests(pack, false)
		_test_bill_requests(pack, true)
		_test_failed_payment_retry(pack)
		_test_world_hooks(pack)
	DB.shutdown()
	for failure in failures:
		print("FAIL: ", failure)
	print("SIM REPLAY: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)

func _new_sim(pack: Dictionary, seed: int, world = null):
	var sim = Sim.new()
	sim.setup(pack, seed, world)
	return sim

func _test_thirty_day_seeds(pack: Dictionary) -> void:
	var first = _new_sim(pack, 19380306)
	var second = _new_sim(pack, 19380306)
	var other = _new_sim(pack, 19380307)
	var different_world: bool = false
	for day in range(1, 31):
		_equal(_run_day(first), _run_day(second), "same seed day %d outputs" % day)
		_equal(first.to_dict(), second.to_dict(), "same seed day %d full state" % day)
		_run_day(other)
		if _canonical(_exogenous(first)) != _canonical(_exogenous(other)):
			different_world = true
	_check(different_world, "different seeds produce different exogenous worlds in 30 days")

func _run_day(sim) -> Dictionary:
	var plan: Dictionary = sim.start_day()
	var output: Dictionary = {"plan": plan, "events": [], "heard": []}
	var day: int = int(sim.s["day"])
	for minute in [480, 600, 780, 960, 1140, 1320, int(sim.pack["time"]["sleep_minute"])]:
		output["events"].append_array(sim.set_minute(int(minute)))
		if minute == 600:
			sim.player_act("accept_stolen", {"actor": "xiaoding", "event_id": "replay:stolen:%d" % day})
			if day % 2 == 0:
				for bill in sim.bills():
					if str(bill["status"]) in ["due", "overdue"]:
						sim.pay_bill(str(bill["id"]), 1, "replay:bill:%s" % str(bill["id"]))
		if minute == 780:
			for visit in sim.visits_today():
				if str(visit.get("status", "")) == "waiting":
					sim.visit_result(str(visit["id"]), {"result": "refused", "accepted": false})
		if minute == 960:
			output["heard"].append_array(sim.hear("zhouma"))
	output["summary"] = sim.end_day()
	return output

func _test_day_ten_json_replay(pack: Dictionary) -> void:
	var continuous = _new_sim(pack, 7391)
	for _day in range(1, 10):
		_run_day(continuous)
	continuous.start_day()
	continuous.set_minute(600)
	continuous.player_act("accept_stolen", {"actor": "xiaoding", "event_id": "save:d10"})
	var before_save: Dictionary = continuous.to_dict()
	var encoded: String = JSON.stringify(before_save, "", true, true)
	var decoded = JSON.parse_string(encoded)
	_equal(before_save, decoded, "day 10 full-precision JSON preserves every numeric bit")
	var restored = _new_sim(pack, 7391)
	restored.from_dict(decoded)
	_equal(before_save, restored.to_dict(), "day 10 restore preserves full state")
	for minute in [601, 720, 901, 1080, 1260, int(pack["time"]["sleep_minute"])]:
		_equal(continuous.set_minute(int(minute)), restored.set_minute(int(minute)), "day 10 resumed events at %d" % minute)
	_equal(continuous.hear("zhouma"), restored.hear("zhouma"), "day 10 resumed rumor hearing")
	_equal(continuous.end_day(), restored.end_day(), "day 10 resumed summary")
	for day in range(11, 31):
		_equal(_run_day(continuous), _run_day(restored), "JSON replay day %d outputs" % day)
		_equal(continuous.to_dict(), restored.to_dict(), "JSON replay day %d full state" % day)

func _test_exogenous_isolation(pack: Dictionary) -> void:
	var control = _new_sim(pack, 54813)
	var accept = _new_sim(pack, 54813)
	var report = _new_sim(pack, 54813)
	var refuse = _new_sim(pack, 54813)
	var no_pay = _new_sim(pack, 54813)
	var cases: Array = [{"name": "accept_stolen", "sim": accept}, {"name": "report", "sim": report},
		{"name": "refuse", "sim": refuse}, {"name": "no_pay", "sim": no_pay}]
	for day in range(1, 31):
		control.start_day()
		control.set_minute(600)
		_pay_due(control, "control")
		control.end_day()
		var expected: Dictionary = _exogenous(control)
		for entry in cases:
			var sim = entry["sim"]
			sim.start_day()
			sim.set_minute(600)
			match str(entry["name"]):
				"accept_stolen":
					sim.player_act("accept_stolen", {"actor": "xiaoding", "count": 3, "event_id": "isolation:accept:%d" % day})
				"report":
					sim.player_act("report", {"actor": "xiaoding", "event_id": "isolation:report:%d" % day})
				"refuse":
					for visit in sim.visits_today():
						sim.visit_result(str(visit["id"]), {"accepted": false, "result": "refused"})
			if str(entry["name"]) != "no_pay":
				_pay_due(sim, str(entry["name"]))
			sim.end_day()
			_equal(expected, _exogenous(sim), "%s does not alter exogenous day %d" % [entry["name"], day])
	_check(int(accept.s["stolen_stock"]) > int(control.s["stolen_stock"]), "isolation fixture actually changes stolen stock")
	_check(int(no_pay.s["summary"]["unpaid"]) > int(control.s["summary"]["unpaid"]), "isolation fixture actually changes unpaid bills")

func _pay_due(sim, policy: String) -> void:
	for bill in sim.bills():
		if str(bill["status"]) in ["due", "overdue"]:
			sim.pay_bill(str(bill["id"]), int(bill["amount"]), "%s:%s" % [policy, str(bill["id"])])

func _exogenous(sim) -> Dictionary:
	var pressures: Dictionary = {}
	for key in sim.pack["pressures"]:
		if str(sim.pack["pressures"][key]["kind"]) == "exogenous":
			pressures[key] = sim.s["pressures"][key]
	var wheels: Array = []
	for row in sim.s["day_report"].get("wheels", []):
		if str(row["mode"]) == "exogenous":
			wheels.append(row.duplicate(true))
	return {"weather": sim.s["weather"], "pressures": pressures, "wheels": wheels,
		"rice": sim.price("rice"), "medicine": sim.price("medicine")}

func _test_minute_partition(pack: Dictionary) -> void:
	var fixture: Dictionary = pack.duplicate(true)
	var ids: Array = fixture["npcs"].keys()
	ids.sort()
	_check(ids.size() >= 8, "relay fixture has eight NPCs")
	if ids.size() < 8:
		return
	# Force a relay across midnight. A queued dawn delivery must have the same
	# timestamp and subsequent relays even when no caller ticks exactly at dawn.
	fixture["communication"] = {"delay_slots": 1, "confidence_decay": 1.0, "relay_probability": 1.0,
		"max_hops": 8, "ttl_slots": 30, "min_confidence": 0.0}
	for index in range(ids.size()):
		var spec: Dictionary = fixture["npcs"][ids[index]]
		spec["links"] = {str(ids[index + 1]): 1.0} if index < 7 else {}
		spec.erase("requires_building")
		spec.erase("when")
	var coarse = _new_sim(fixture, 883)
	var fine = _new_sim(fixture, 883)
	var sleep_minute: int = int(fixture["time"]["sleep_minute"])
	var wake_minute: int = int(fixture["time"]["wake_minute"])
	var plant_minute: int = int(fixture["time"]["slot_hours"][4]) * 60
	for day in range(1, 4):
		_equal(coarse.start_day(), fine.start_day(), "coarse/fine day %d plan" % day)
		var coarse_events: Array = []
		var fine_events: Array = []
		if day == 1:
			coarse_events.append_array(coarse.set_minute(plant_minute))
			for minute in range(wake_minute, plant_minute + 1):
				fine_events.append_array(fine.set_minute(minute))
			coarse.plant_rumor("replay_chain", str(ids[0]))
			fine.plant_rumor("replay_chain", str(ids[0]))
			coarse_events.append_array(coarse.set_minute(sleep_minute))
			for minute in range(plant_minute + 1, sleep_minute + 1):
				fine_events.append_array(fine.set_minute(minute))
		else:
			coarse_events = coarse.set_minute(sleep_minute)
			for minute in range(wake_minute, sleep_minute + 1):
				fine_events.append_array(fine.set_minute(minute))
		_equal(coarse_events, fine_events, "coarse/fine day %d chronological events" % day)
		_equal(coarse.to_dict(), fine.to_dict(), "coarse/fine day %d full state" % day)
		_equal(coarse.end_day(), fine.end_day(), "coarse/fine day %d summary" % day)
	_check(coarse.s["known"].get(ids[7], {}).has("replay_chain"), "forced rumor reaches eighth NPC across day boundaries")

func _test_bill_requests(pack: Dictionary, attached: bool) -> void:
	var world = World.new() if attached else null
	if world != null:
		world.setup(1407)
	var sim = _new_sim(pack, 1407, world)
	sim.start_day()
	var bill: Dictionary = _payable_bill(sim)
	var label: String = "world" if attached else "pure"
	_check(not bill.is_empty(), label + " has a payable bill")
	if bill.is_empty():
		_detach(sim)
		return
	var id: String = str(bill["id"])
	var original_cash: int = _cash(sim)
	var partial: Dictionary = sim.pay_bill(id, 1, "partial")
	_check(bool(partial.get("ok", false)) and int(partial.get("paid", 0)) == 1, label + " partial payment succeeds")
	_check(int(partial.get("remaining", 0)) == int(bill["amount"]) - 1 and _cash(sim) == original_cash - 1, label + " partial payment records only transferred cash")
	var checkpoint: Dictionary = _payment_state(sim)
	_equal(partial, sim.pay_bill(id, 1, "partial"), label + " payment retry returns original receipt")
	_equal(checkpoint, _payment_state(sim), label + " payment retry causes no mutation")
	var conflicting_bill: Dictionary = sim.pay_bill("other_bill", 1, "partial")
	_check(not bool(conflicting_bill.get("ok", true)) and str(conflicting_bill.get("reason", "")) == "request_conflict", label + " conflicting request rejects another bill")
	var conflicting_amount: Dictionary = sim.pay_bill(id, int(bill["amount"]) + 100, "partial")
	_check(not bool(conflicting_amount.get("ok", true)) and str(conflicting_amount.get("reason", "")) == "request_conflict", label + " conflicting request rejects another amount")
	_equal(checkpoint, _payment_state(sim), label + " conflicting request causes no mutation")
	var saved: Dictionary = {"town": sim.to_dict()}
	if attached:
		saved["ledger"] = world.ledger.to_dict()
	var parsed = JSON.parse_string(JSON.stringify(saved, "", true, true))
	var resumed_world = World.new() if attached else null
	if resumed_world != null:
		resumed_world.setup(1407)
		resumed_world.ledger.from_dict(parsed["ledger"])
	var resumed = _new_sim(pack, 1407, resumed_world)
	resumed.from_dict(parsed["town"])
	_equal(checkpoint, _payment_state(resumed), label + " town and ledger restore payment state")
	_equal(partial, resumed.pay_bill(id, 1, "partial"), label + " saved request receipt survives JSON")
	_equal(checkpoint, _payment_state(resumed), label + " saved request causes no second transfer")
	var final_payment: Dictionary = resumed.pay_bill(id, int(bill["amount"]) + 100, "remainder")
	_check(bool(final_payment.get("ok", false)) and int(final_payment.get("paid", -1)) == int(bill["amount"]) - 1 and str(final_payment.get("status", "")) == "paid", label + " overpayment caps at remaining bill")
	_check(_cash(resumed) == original_cash - int(bill["amount"]), label + " completed bill debits exactly its amount")
	var final_state: Dictionary = _payment_state(resumed)
	var already_paid: Dictionary = resumed.pay_bill(id, int(bill["amount"]), "paid_again")
	_check(bool(already_paid.get("ok", false)) and int(already_paid.get("paid", -1)) == 0, label + " paid bill accepts retry without money movement")
	_equal(final_state["money"], _payment_state(resumed)["money"], label + " paid bill adds no journal entry")
	if attached:
		_check(resumed_world.ledger.journal.size() == world.ledger.journal.size() + 1, "world ledger has one entry per successful distinct payment")
		_check(resumed_world.ledger.check_invariants().is_empty(), "world payment and restoration conserve money")
	_detach(sim)
	_detach(resumed)

func _test_failed_payment_retry(pack: Dictionary) -> void:
	var world = World.new()
	world.setup(2001)
	var sim = _new_sim(pack, 2001, world)
	sim.start_day()
	var bill: Dictionary = _payable_bill(sim)
	_check(not bill.is_empty(), "funding retry has a payable bill")
	if bill.is_empty():
		_detach(sim)
		return
	world.ledger.open_account("replay_escrow", 0)
	world.ledger.transfer("player", "replay_escrow", world.ledger.balance("player"), "暂存", "retry", "empty_cash")
	var before: Dictionary = _payment_state(sim)
	var denied: Dictionary = sim.pay_bill(str(bill["id"]), int(bill["amount"]), "fund_later")
	_check(not bool(denied.get("ok", true)) and str(denied.get("reason", "")) == "insufficient_funds", "unfunded payment fails explicitly")
	_equal(before["money"], _payment_state(sim)["money"], "failed payment does not write ledger")
	_equal(before["bills"], sim.bills(), "failed payment does not mark bill paid")
	world.ledger.transfer("replay_escrow", "player", int(bill["amount"]), "取回", "retry", "fund_cash")
	var paid: Dictionary = sim.pay_bill(str(bill["id"]), int(bill["amount"]), "fund_later")
	_check(bool(paid.get("ok", false)) and int(paid.get("paid", 0)) == int(bill["amount"]), "failed request can succeed with same ID after funding")
	_check(world.ledger.check_invariants().is_empty(), "funding retry conserves money")
	_detach(sim)

func _test_world_hooks(pack: Dictionary) -> void:
	var world = World.new()
	world.setup(918)
	var sim = _new_sim(pack, 918, world)
	sim.start_day()
	_check(world.town == sim, "town setup attaches world hook")
	_check(world.day == int(sim.s["day"]) and world.slot == int(sim.s["slot"]), "town dawn synchronizes world clock")
	_check(_canonical(world.rice_mod) == _canonical(sim.s["pressures"]["rice_price"]) and _canonical(world.med_mod) == _canonical(sim.s["pressures"]["med_price"]) and world.weather == str(sim.s["weather"]), "town dawn synchronizes current trading prices and weather")
	var before: Dictionary = _exogenous(sim)
	var money: Dictionary = world.ledger.to_dict()
	world.advance_slot()
	_check(world.day == 1 and world.slot == 1 and int(sim.s["minute"]) == int(pack["time"]["slot_hours"][1]) * 60, "world slot hook advances town clock once")
	_equal(before, _exogenous(sim), "world slot hook does not reroll weather or prices")
	_equal(money, world.ledger.to_dict(), "world slot hook does not run legacy NPC spending")
	world.plant_rumor("fair_shop", "zhouma")
	_check(sim.s["known"].get("zhouma", {}).has("fair_shop"), "world rumor planting routes into town network")
	var heard: Array = world.share_rumors("zhouma")
	_check(_has_rumor(heard, "fair_shop"), "world rumor hearing routes to delivered town knowledge")
	_check(world.ledger.check_invariants().is_empty(), "world hooks retain ledger invariants")
	_detach(sim)
	var legacy = World.new()
	legacy.setup(918)
	_check(legacy.town == null, "legacy world remains detached")
	legacy.advance_slot()
	_check(legacy.day == 1 and legacy.slot == 0, "legacy world retains slot and date progression")
	_check(legacy.ledger.check_invariants().is_empty(), "legacy world retains money conservation")

func _has_rumor(rows: Array, key: String) -> bool:
	for row in rows:
		if str(row.get("key", "")) == key:
			return true
	return false

func _payable_bill(sim) -> Dictionary:
	for bill in sim.bills():
		if str(bill["status"]) == "due" and int(bill["amount"]) > 1:
			return bill
	return {}

func _cash(sim) -> int:
	return sim.world.ledger.balance("player") if sim.world != null else int(sim.s["cash"]["player"])

func _payment_state(sim) -> Dictionary:
	var state: Dictionary = sim.to_dict()
	return {"bills": sim.bills(), "requests": state["bill_requests"],
		"money": sim.world.ledger.to_dict() if sim.world != null else state["cash"]}

func _detach(sim) -> void:
	if sim.world != null:
		sim.world.town = null
		sim.world = null

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _equal(first, second, message: String) -> void:
	checks += 1
	var difference: String = _difference(first, second)
	if difference != "":
		failures.append(message + " at " + difference)

func _difference(first, second, path: String = "state") -> String:
	if first is Dictionary and second is Dictionary:
		var first_keys: Array = first.keys()
		var second_keys: Array = second.keys()
		first_keys.sort()
		second_keys.sort()
		if first_keys != second_keys:
			return path + ".keys"
		for key in first_keys:
			var difference: String = _difference(first[key], second[key], path + "." + str(key))
			if difference != "":
				return difference
		return ""
	if first is Array and second is Array:
		if first.size() != second.size():
			return path + ".size (%d != %d)" % [first.size(), second.size()]
		for index in range(first.size()):
			var difference: String = _difference(first[index], second[index], "%s[%d]" % [path, index])
			if difference != "":
				return difference
		return ""
	if _canonical(first) != _canonical(second):
		return path + " (" + _canonical(first) + " != " + _canonical(second) + ")"
	return ""

func _canonical(value) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort()
		var entries: PackedStringArray = []
		for key in keys:
			entries.append(JSON.stringify(str(key)) + ":" + _canonical(value[key]))
		return "{" + ",".join(entries) + "}"
	if value is Array:
		var entries: PackedStringArray = []
		for entry in value:
			entries.append(_canonical(entry))
		return "[" + ",".join(entries) + "]"
	if value is int or value is float:
		if value is int or (is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) < 9.0e15):
			return "number:" + str(int(value))
		return "float64:" + PackedFloat64Array([float(value)]).to_byte_array().hex_encode()
	return JSON.stringify(value)
