extends SceneTree

const Costs = preload("res://scripts/sim/living_costs.gd")
const InstitutionsModule = preload("res://scripts/sim/institutions.gd")
const UnlocksModule = preload("res://scripts/sim/unlocks.gd")
const Life = preload("res://scripts/sim/npc_life.gd")
const Rumors = preload("res://scripts/sim/rumor_net.gd")
const Sim = preload("res://scripts/sim/town_sim.gd")
const Ledger = preload("res://scripts/core/ledger.gd")

class EvidenceWorld extends RefCounted:
	var ledger = Ledger.new()
	var npcs: Dictionary = {}
	var flags: Dictionary = {}
	var day: int = 0
	var slot: int = 0
	var weather: String = "晴"
	var rice_mod: float = 1.0
	var med_mod: float = 1.0
	var prev_rice_mod: float = 1.0
	var prev_med_mod: float = 1.0
	var town = null
	var db = null

	func date_text(value: int) -> String:
		return "账历第%d日" % value

	func stat(key: String) -> int:
		return 50 if key == "koubei" else 0

var failures: Array[String] = []
var checks: int = 0
var shipped: Dictionary = {}


func _init() -> void:
	shipped = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/town_pack.json"))
	_cost_ranges()
	_monthly_notice()
	_invitations()
	_payments()
	_delayed_consequences()
	_institutions()
	_locked_institution_rumors()
	_waiting_institution_witnesses()
	_pure_trade_settlement()
	_unlocks()
	_schedules()
	_visit_plans()
	_rumors()
	for failure in failures:
		print("FAIL: ", failure)
	print("SIM LIFE: ", "PASS" if failures.is_empty() else "FAIL", " (", checks, " checks)")
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func _state(day: int = 1) -> Dictionary:
	return {"day": day, "slot": 0, "minute": 360, "seed": 42, "weather": "雨", "difficulty": "常年",
		"flags": {}, "flags_today": {}, "stats": {}, "pressures": {"rice_price": 1.0, "med_price": 1.0, "rent_index": 1.0, "heat": 0.0, "unrest": 0.0},
		"unlocked": {"police": true, "baogong": true}, "cash": {"player": 100}, "day_report": {}, "influence_spent": {}}


func _cost(id: String) -> Dictionary:
	for spec in shipped["living_costs"]:
		if str(spec["id"]) == id:
			return spec.duplicate(true)
	return {}


func _cost_ranges() -> void:
	var categories: Array = ["food", "fuel", "medicine", "social", "levy", "rent", "certificate", "emergency", "turnover"]
	var original: String = JSON.stringify(shipped)
	for id in categories:
		var spec: Dictionary = _cost(str(id))
		check(not spec.is_empty(), "declared living-cost category exists: " + str(id))
		if spec.is_empty():
			continue
		# Exercise each declared formula independently, without a random event
		# deciding whether a category is covered by this run.
		spec["when"] = {}
		var pack: Dictionary = shipped.duplicate(true)
		pack["living_costs"] = [spec]
		for difficulty in ["太平年", "常年", "乱世"]:
			for seed_value in range(12):
				var state: Dictionary = _state(21 if id == "rent" else 6)
				state["seed"] = seed_value
				state["difficulty"] = difficulty
				for pressure in ["rice_price", "med_price"]:
					state["pressures"][pressure] = float(shipped["pressures"][pressure]["min" if seed_value % 2 == 0 else "max"])
				state["flags"]["mother_sick"] = true
				state["flags"]["emergency_bill"] = true
				state["invitations"] = [{"id": "gathering", "cost_id": "social", "due_day": int(state["day"]) + 4}]
				state["contract_bills"] = [{"id": "renewal", "cost_id": "turnover", "amount": 17, "due_day": int(state["day"]) + 2}]
				var generated: Array = Costs.generate(pack, state)
				check(generated.size() == 1, "eligible cost is generated: %s/%s/%d" % [id, difficulty, seed_value])
				if generated.size() != 1:
					continue
				var bill: Dictionary = generated[0]
				check(int(bill["amount"]) >= int(spec["min"]) and int(bill["amount"]) <= int(spec["max"]), "amount stays in declared range: " + str(id))
				check(bill["range"] == [int(spec["min"]), int(spec["max"])], "bill preserves visible declared range: " + str(id))
				check(not str(bill["source"]).is_empty() and not str(bill["date"]).is_empty() and int(bill["created_day"]) == int(state["day"]), "bill has source and creation date: " + str(id))
				check(Costs.generate(pack, state).is_empty() and state["bills"].size() == 1, "same obligation is announced only once: " + str(id))
				check(state["cash"]["player"] == 100, "announcing a cost never debits cash: " + str(id))
	check(JSON.stringify(shipped) == original, "cost generation leaves the shipped pack unchanged")
	var state: Dictionary = _state()
	check(Costs.generate({"living_costs": [_cost("medicine")]}, state).is_empty(), "medicine is absent when nobody is sick")
	check(Costs.generate({"living_costs": [_cost("social")]}, state).is_empty(), "social costs require actual invitations")


func _monthly_notice() -> void:
	var spec: Dictionary = _cost("rent")
	check(int(spec.get("announce_days", 0)) >= 7, "rent announcement declares at least seven days of notice")
	var pack: Dictionary = shipped.duplicate(true)
	pack["living_costs"] = [spec]
	var state: Dictionary = _state()
	var amount: int = -1
	var first_dates: Array = []
	var month_days: int = int(pack["balance"]["costs"]["month_days"])
	for day in range(1, month_days * 6 + 1):
		state["day"] = day
		var generated: Array = Costs.generate(pack, state)
		if not generated.is_empty():
			var bill: Dictionary = generated[0]
			first_dates.append(day)
			check(int(bill["due_day"]) - int(bill["created_day"]) >= 7, "monthly rent first appears at least seven days before its due date")
			if amount < 0:
				amount = int(bill["amount"])
			check(int(bill["amount"]) == amount, "rent does not climb simply because more months passed")
		Costs.end_day(pack, state)
	var expected_dates: Array = []
	for month in range(6):
		expected_dates.append(month * month_days + int(spec["due_day"]) - int(spec["announce_days"]))
	check(first_dates == expected_dates, "one rent notice is generated per declared month")
	check(state["bills"].size() == 6 and state["cash"]["player"] == 100, "unpaid monthly bills accumulate without hidden cash debits")
	check(float(shipped["pressures"]["rent_index"]["min"]) == float(shipped["pressures"]["rent_index"]["max"]), "shipped rent index has no unannounced random escalation")


func _quiet_pack() -> Dictionary:
	var pack: Dictionary = shipped.duplicate(true)
	pack["wheels"] = []
	pack["building_decks"] = {}
	pack["spine"] = []
	pack["influence"]["feeds"] = []
	return pack


func _invitation_specs(value, result: Array) -> void:
	if value is Dictionary:
		if str(value.get("op", "")) == "invitation":
			result.append(value.duplicate(true))
		for key in value:
			_invitation_specs(value[key], result)
	elif value is Array:
		for child in value:
			_invitation_specs(child, result)


func _invitations() -> void:
	var declared: Array = []
	_invitation_specs(shipped, declared)
	check(not declared.is_empty(), "shipped town events include actual social invitations")
	for effect in declared:
		var lead = effect.get("lead_days", [effect.get("delay_days", 0), effect.get("delay_days", 0)])
		check(lead is Array and lead.size() == 2 and int(lead[0]) >= 3 and int(lead[1]) <= 7, "declared social invitations arrive three to seven days ahead")
		for seed_value in range(8):
			var actual_pack: Dictionary = _quiet_pack()
			actual_pack["living_costs"] = [_cost("social")]
			actual_pack["spine"] = [{"day": 1, "id": "declared_invitation", "effects": [effect.duplicate(true)]}]
			var actual_sim = Sim.new(actual_pack, seed_value)
			var actual_plan: Dictionary = actual_sim.start_day()
			var actual_invitations: Array = actual_plan["notice"]["invitations"]
			check(actual_invitations.size() == 1 and actual_sim.bills().size() == 1, "declared invitation executes through the public daily pipeline")
			if actual_invitations.is_empty() or actual_sim.bills().is_empty():
				continue
			var due: int = int(actual_invitations[0]["due_day"])
			check(due - int(actual_invitations[0]["received_day"]) >= 3 and due - int(actual_invitations[0]["received_day"]) <= 7 and int(actual_sim.bills()[0]["due_day"]) == due, "declared invitation draws within its advance-notice interval and bills its actual date")
	# Boundary examples use the public start_day pipeline rather than directly
	# modifying a bill; this verifies both invitation effects and social costs.
	for lead in [3, 7]:
		var pack: Dictionary = _quiet_pack()
		pack["living_costs"] = [_cost("social")]
		pack["spine"] = [{"day": 1, "id": "test_invitation", "effects": [{"op": "invitation", "id": "wedding", "cost_id": "social", "delay_days": lead, "who": "zhouma", "text": "街坊送来请帖。"}]}]
		var sim = Sim.new(pack, 42)
		var player_cash: int = int(sim.s["cash"]["player"])
		var plan: Dictionary = sim.start_day()
		var invitations: Array = plan["notice"]["invitations"]
		check(invitations.size() == 1, "received invitation is visible in the daily notice")
		check(sim.bills().size() == 1, "actual invitation creates exactly one social bill")
		if invitations.is_empty() or sim.bills().is_empty():
			continue
		var bill: Dictionary = sim.bills()[0]
		check(int(invitations[0]["received_day"]) == 1 and int(invitations[0]["due_day"]) == 1 + lead, "invitation records receipt and delayed due date")
		check(bill["cost_id"] == "social" and int(bill["due_day"]) == 1 + lead and str(bill["source"]).begins_with("event:"), "social obligation follows the invitation date and source")
		for day in range(1, lead + 2):
			if day > 1:
				sim.start_day()
			sim.end_day()
			check(int(sim.s["cash"]["player"]) == player_cash, "invitation and nightfall never automatically charge the player")
		check(sim.bills().size() == 1, "an invitation is not billed again on later days")


func _payments() -> void:
	var world = EvidenceWorld.new()
	world.ledger.open_account("player", 100)
	var pack: Dictionary = _quiet_pack()
	var sim = Sim.new(pack, 42, world)
	sim.s["day"] = 5
	var spec: Dictionary = {"id": "food", "label": "米行赊账", "amount": 20, "min": 20, "max": 20, "payee": "米行", "building": "ricehall", "due_day": 5}
	Costs.add(pack, sim.s, spec, "米行/赊账", "bill:test", world)
	check(sim.bills()[0]["date"] == "账历第5日", "bill uses the world's calendar when available")
	var original_bill: Dictionary = sim.bills()[0].duplicate(true)
	var first: Dictionary = sim.pay_bill("bill:test", 7, "partial")
	check(first.get("ok", false) and int(first["paid"]) == 7 and int(first["remaining"]) == 13, "explicit partial payment leaves the remaining obligation")
	check(world.ledger.balance("player") == 93 and world.ledger.balance("米行") == 7 and world.ledger.journal.size() == 1, "payment transfers cash to the named payee through the ledger")
	check(world.ledger.journal[0]["ref"] == "bill:test" and world.ledger.journal[0]["reason"] == "米行赊账", "payment journal links to its source bill")
	check(sim.pay_bill("bill:test", 7, "partial") == first and world.ledger.journal.size() == 1, "replaying a payment returns the receipt without another debit")
	check(sim.pay_bill("bill:test", 8, "partial").get("reason", "") == "request_conflict", "changing a replayed payment amount is rejected")
	check(sim.pay_bill("different_bill", 7, "partial").get("reason", "") == "request_conflict", "a receipt cannot be reused for another bill")
	var final_payment: Dictionary = sim.pay_bill("bill:test", 999, "finish")
	check(final_payment.get("ok", false) and int(final_payment["paid"]) == 13 and sim.bills()[0]["status"] == "paid", "overpayment is capped at the outstanding balance")
	check(sim.pay_bill("bill:test", 20, "already_paid").get("paid", -1) == 0 and world.ledger.journal.size() == 2, "a paid bill cannot charge again under a new request")
	check(sim.bills()[0]["source"] == original_bill["source"] and sim.bills()[0]["date"] == original_bill["date"], "settlement preserves the bill's original source and date")
	check(world.ledger.total() == 100 and world.ledger.check_invariants().is_empty(), "bill payment conserves total ledger money")
	check(not sim.pay_bill("missing", 1, "missing").get("ok", true), "unknown bill cannot debit cash")
	var poor = Sim.new(pack, 42)
	poor.s["cash"]["player"] = 0
	Costs.add(pack, poor.s, spec, "米行/赊账", "bill:poor")
	check(poor.pay_bill("bill:poor", 20, "poor").get("reason", "") == "insufficient_funds" and int(poor.bills()[0]["paid"]) == 0, "insufficient funds leave the obligation unpaid")
	world.town = null
	sim.world = null


func _delayed_consequences() -> void:
	var pack: Dictionary = _quiet_pack()
	var state: Dictionary = _state()
	var spec: Dictionary = {"id": "test", "amount": 10, "payee": "街坊", "due_day": 1, "grace_days": 2, "late_effects": [
		{"after_days": 3, "op": "flag_set", "key": "first_warning", "value": true},
		{"after_days": 5, "op": "flag_set", "key": "second_warning", "value": true},
	]}
	Costs.add(pack, state, spec, "notice:test", "bill:late")
	check(Costs.end_day(pack, state).is_empty(), "a due bill has no immediate late consequence")
	state["day"] = 2
	var rows: Array = Costs.end_day(pack, state)
	check(rows.size() == 1 and rows[0]["effects"].is_empty(), "first late day gives a visible warning with no sanction")
	check(Costs.end_day(pack, state).is_empty(), "the overdue warning is idempotent")
	state["day"] = 3
	check(Costs.end_day(pack, state).is_empty(), "grace period delays declared consequences")
	state["day"] = 4
	rows = Costs.end_day(pack, state)
	check(rows.size() == 1 and rows[0]["effects"][0]["key"] == "first_warning", "first delayed stage appears exactly after grace")
	check(Costs.end_day(pack, state).is_empty(), "a delayed stage applies once per bill")
	state["day"] = 6
	rows = Costs.end_day(pack, state)
	check(rows.size() == 1 and rows[0]["effects"][0]["key"] == "second_warning", "later stage escalates only at its declared delay")
	check(state["cash"]["player"] == 100, "overdue consequences never hide a cash debit")
	state["bills"][0]["status"] = "paid"
	state["day"] = 20
	check(Costs.end_day(pack, state).is_empty(), "paid obligations cannot produce later penalties")
	# The coordinator must actually apply each returned stage once.
	pack["living_costs"] = []
	var sim = Sim.new(pack, 42)
	sim.start_day()
	Costs.add(pack, sim.s, spec, "notice:test", "bill:integration")
	for day in range(1, 7):
		if day > 1:
			sim.start_day()
		sim.end_day()
		check(bool(sim.s["flags"].get("first_warning", false)) == (day >= 4), "coordinator applies first stage after its delay")
		check(bool(sim.s["flags"].get("second_warning", false)) == (day >= 6), "coordinator applies second stage after its delay")
		var before: String = JSON.stringify(sim.to_dict())
		sim.end_day()
		check(JSON.stringify(sim.to_dict()) == before, "replaying nightfall cannot reapply a consequence")


func _institution_pack() -> Dictionary:
	var pack: Dictionary = _quiet_pack()
	pack["npcs"] = {
		"officer": {"roles": ["authority"], "links": {}, "schedule": {"default": ["德厚当"]}, "requires_building": "police"},
		"customer": {"roles": [], "links": {}, "schedule": {"default": ["德厚当"]}},
	}
	pack["norms"] = [{"id": "witnessed_goods", "act": "accept_stolen", "building": "pawnshop", "detect_probability": 1.0, "forgiveness": 0.0, "heat": 0.25, "authority_building": "police"}]
	return pack


func _institutions() -> void:
	var pack: Dictionary = _institution_pack()
	var state: Dictionary = _state()
	var before: String = JSON.stringify(state)
	check(not InstitutionsModule.act(pack, state, "missing", "raid").get("ok", true), "unknown institution is rejected")
	check(not InstitutionsModule.act(pack, state, "police", "missing").get("ok", true), "unknown institution action is rejected")
	check(JSON.stringify(state) == before, "unknown institution commands have no side effects")
	state["unlocked"]["police"] = false
	check(InstitutionsModule.act(pack, state, "police", "raid").get("reason", "") == "institution_locked", "a locked institution cannot exercise its powers")
	var absent: Dictionary = _state()
	absent["npc_locations"] = {"officer": "保公所", "customer": "德厚当"}
	var result: Dictionary = InstitutionsModule.norm(pack, absent, "accept_stolen", {"actor": "customer", "item_id": "hidden", "building": "pawnshop", "event_id": "absent"})
	check(result["detected"].is_empty() and float(absent["pressures"]["heat"]) == 0.0 and not absent.has("institution_evidence"), "an absent authority cannot discover hidden wrongdoing")
	var self_witness: Dictionary = _state()
	result = InstitutionsModule.norm(pack, self_witness, "accept_stolen", {"actor": "officer", "item_id": "self", "building": "pawnshop", "event_id": "self"})
	check(result["detected"].is_empty(), "an authority is not its own witnessing observer")
	var world = EvidenceWorld.new()
	world.ledger.open_account("player", 100)
	world.ledger.open_account("customer", 10)
	world.npcs = {"officer": {"present": true}, "customer": {"present": true}}
	var visible_item: String = world.ledger.add_item({"def_id": "visible", "stolen": true}, "customer", "counter")
	var hidden_item: String = world.ledger.add_item({"def_id": "hidden", "stolen": true}, "player", "stock")
	var ticket: String = world.ledger.open_pawn("customer", [visible_item], 20, 1, 30, "原物保管", false)
	var original_contract: Dictionary = world.ledger.contracts[ticket].duplicate(true)
	state = _state()
	result = InstitutionsModule.act(pack, state, "police", "raid", world)
	check(int(result.get("seized", -1)) == 0 and world.ledger.items[hidden_item]["location"] == "stock", "a raid cannot inspect hidden stolen flags without evidence")
	check(world.ledger.balance("player") == 80 and int(result.get("paid", -1)) == 0, "institution fine is an obligation and never an automatic debit")
	check(state["bills"].size() == 1 and state["bills"][0]["source"] == "police/raid", "institution fines have a persistent source bill")
	result = InstitutionsModule.norm(pack, state, "accept_stolen", {"actor": "customer", "item_id": visible_item, "building": "pawnshop", "event_id": "witnessed", "request_id": "first"}, world)
	check(result["detected"] == ["witnessed_goods"] and state["institution_evidence"]["police"]["items"].has(visible_item), "a present authority creates evidence for the actual witnessed item")
	var heat: float = float(state["pressures"]["heat"])
	result = InstitutionsModule.norm(pack, state, "accept_stolen", {"actor": "customer", "item_id": visible_item, "building": "pawnshop", "event_id": "witnessed", "request_id": "new_retry"}, world)
	check(result.get("replayed", false) and result["effects"].is_empty() and float(state["pressures"]["heat"]) == heat, "changing a retry token cannot repeat detection or sanctions")
	state["slot"] = 1
	result = InstitutionsModule.act(pack, state, "police", "raid", world)
	check(int(result.get("seized", -1)) == 1 and world.ledger.items[visible_item]["location"] == "police", "a subsequent raid seizes only its witnessed evidence")
	check(world.ledger.items[hidden_item]["location"] == "stock", "unwitnessed stock remains private after another item is seized")
	check(world.ledger.contracts[ticket] == original_contract and world.ledger.items[visible_item]["pledged_to"] == ticket, "confiscation preserves the live-pawn contract and original-item obligation")
	check(not world.ledger.redeem(ticket, 2) and world.ledger.contracts[ticket]["status"] == "active", "seized original property cannot be silently redeemed")
	var bills_before: int = state["bills"].size()
	var journal_before: int = world.ledger.journal.size()
	check(InstitutionsModule.act(pack, state, "police", "raid", world).get("replayed", false) and state["bills"].size() == bills_before and world.ledger.journal.size() == journal_before, "replaying a raid adds no fine or money movement")
	check(world.ledger.check_invariants().is_empty(), "institution activity preserves money and pawn invariants")
	var concealed: Dictionary = _state()
	world.npcs["officer"]["present"] = false
	result = InstitutionsModule.norm(pack, concealed, "accept_stolen", {"actor": "customer", "item_id": hidden_item, "building": "pawnshop", "event_id": "off_duty"}, world)
	check(result["detected"].is_empty(), "world absence overrides an authority's scheduled location")


func _locked_institution_rumors() -> void:
	var pack: Dictionary = _institution_pack()
	pack["npcs"]["customer"]["links"] = {"observer": 1.0}
	pack["npcs"]["observer"] = {"roles": [], "links": {"civic": 1.0}, "schedule": {"default": ["德厚当"]}}
	pack["npcs"]["civic"] = {"roles": ["authority"], "links": {}, "schedule": {"default": ["保公所"]}, "requires_building": "baogong"}
	pack["norms"][0]["rumor"] = "pawnshop_fenced"
	# Deterministic delivery must reach the real opening threshold. The
	# pressure model still enforces the shipped per-day influence cap.
	pack["norms"][0]["heat"] = 0.5
	pack["norms"][0]["effects"] = [{"op": "flag_set", "key": "formal_sanction", "value": true}]
	pack["communication"]["relay_probability"] = 1.0
	pack["communication"]["confidence_decay"] = 1.0
	var state: Dictionary = _state()
	state["unlocked"]["police"] = false
	var args: Dictionary = {"actor": "customer", "item_id": "reported_transaction", "building": "pawnshop", "event_id": "before_opening", "request_id": "first"}
	var result: Dictionary = InstitutionsModule.norm(pack, state, "accept_stolen", args)
	check(result["effects"].size() == 1 and result["effects"][0]["op"] == "rumor" and result["effects"][0]["origin"] == "observer", "closed police do not suppress a real bystander's observed rumor")
	check(result["detected"].is_empty() and not state.has("institution_evidence") and float(state["pressures"]["heat"]) == 0.0, "a bystander's rumor creates no immediate formal detection, evidence, or heat")
	check(InstitutionsModule.act(pack, state, "police", "raid").get("reason", "") == "institution_locked" and not state.has("bills"), "rumor generation does not grant a closed institution sanction powers")
	args["request_id"] = "retry"
	var replay: Dictionary = InstitutionsModule.norm(pack, state, "accept_stolen", args)
	check(replay.get("replayed", false) and replay["effects"].is_empty(), "retrying the same witnessed transaction emits no duplicate rumor")
	var no_witness: Dictionary = _state()
	no_witness["unlocked"]["police"] = false
	no_witness["npc_locations"] = {"observer": "家", "civic": "保公所", "customer": "德厚当"}
	result = InstitutionsModule.norm(pack, no_witness, "accept_stolen", args)
	check(result["effects"].is_empty() and float(no_witness["pressures"]["heat"]) == 0.0, "a known actor alone cannot invent an eyewitness rumor before police open")
	args["actor"] = "stranger:unknown"
	args["event_id"] = "unknown_actor"
	no_witness["npc_locations"]["customer"] = "家"
	result = InstitutionsModule.norm(pack, no_witness, "accept_stolen", args)
	check(result["effects"].is_empty() and result["detected"].is_empty(), "an unknown stranger with no actual bystanders cannot manufacture a sighting")
	args["event_id"] = "stranger_observed"
	result = InstitutionsModule.norm(pack, state, "accept_stolen", args)
	check(result["effects"].size() == 1 and result["effects"][0]["origin"] == "customer", "an observed stranger transaction names an actual present observer instead of inventing an NPC origin")
	# Return to the first result through its persisted semantic record; emit
	# its one real observation just as TownSim's effect coordinator does.
	var effect: Dictionary = state["norm_results"]["before_opening"]["effects"][0]
	Rumors.plant(pack, state, str(effect["key"]), str(effect["origin"]), float(effect["conf"]))
	check(state["known"]["observer"].has("pawnshop_fenced") and not state["known"].get("civic", {}).has("pawnshop_fenced"), "only the actual observer knows the rumor before the relay delay")
	check(float(state["pressures"]["heat"]) == 0.0 and not UnlocksModule.check(pack, state).has("police"), "a private observation does not prematurely open police")
	var queued: int = state["queue"].size()
	var sequence: int = int(state["seq"])
	Rumors.plant(pack, state, str(effect["key"]), str(effect["origin"]), float(effect["conf"]))
	check(state["queue"].size() == queued and int(state["seq"]) == sequence and Rumors.deliver(pack, state).is_empty(), "replanting and delivery retries do not duplicate a pending accusation")
	state["slot"] = 1
	state["minute"] = 540
	var deliveries: Array = Rumors.deliver(pack, state)
	check(deliveries.size() == 1 and deliveries[0]["to"] == "civic" and state["known"]["civic"]["pawnshop_fenced"]["via"] == "observer", "a real available civic authority receives the delayed accusation with its observer source")
	check(float(state["pressures"]["heat"]) >= 0.3 and not state["unlocked"]["police"] and not state.has("institution_evidence"), "heard accusation raises endogenous heat while police powers and formal item evidence remain locked")
	var heat: float = float(state["pressures"]["heat"])
	check(Rumors.deliver(pack, state).is_empty() and float(state["pressures"]["heat"]) == heat, "the same delivered accusation influences heat once")
	check(UnlocksModule.check(pack, state).has("police") and state["unlocked"]["police"] and int(state["day"]) < 22, "delayed heard accusations can open police before the historical date")
	check(UnlocksModule.check(pack, state).is_empty(), "the accusation-driven opening is idempotent")
	args = {"actor": "customer", "building": "pawnshop", "item_id": "after_opening_item", "event_id": "after_opening"}
	result = InstitutionsModule.norm(pack, state, "accept_stolen", args)
	check(result["detected"] == ["witnessed_goods"] and state["institution_evidence"]["police"]["items"].has("after_opening_item"), "after opening, a newly witnessed transaction can create formal police evidence")
	# Also cover the coordinator's public action and clock boundary, including
	# the actual next-morning unlock check rather than only module calls.
	pack["buildings"]["baogong"]["unlocked"] = true
	var sim = Sim.new(pack, 42)
	sim.start_day()
	check(not sim.s["unlocked"].get("police", false), "the public daily pipeline starts with police locked")
	sim.player_act("accept_stolen", {"actor": "customer", "building": "pawnshop", "event_id": "public_observation"})
	check(sim.s["known"].get("observer", {}).has("pawnshop_fenced") and float(sim.s["pressures"]["heat"]) == 0.0, "public player action seeds the actual observer without granting immediate detection")
	sim.set_minute(540)
	check(sim.s["known"].get("civic", {}).has("pawnshop_fenced") and float(sim.s["pressures"]["heat"]) >= 0.3, "public clock advance delivers the accusation and its capped influence")
	sim.end_day()
	var plan: Dictionary = sim.start_day()
	check(plan["unlocked_today"].has("police") and int(sim.s["day"]) == 2, "the next public morning opens police from the heard accusation")


func _waiting_institution_witnesses() -> void:
	var pack: Dictionary = _institution_pack()
	pack["norms"][0]["rumor"] = "pawnshop_fenced"
	pack["npcs"]["customer"]["schedule"]["default"] = ["家"]
	pack["npcs"]["officer"]["schedule"]["default"] = ["警察所"]
	pack["npcs"]["observer"] = {"roles": [], "links": {}, "schedule": {"default": ["家"]}}
	var state: Dictionary = _state()
	state["unlocked"]["police"] = false
	state["minute"] = 480
	state["visits"] = [{"id": "observed_visit", "who": "customer", "intent": "sell_stolen", "status": "planned", "minute": 500, "patience_min": 20, "companions": ["observer"]}]
	var args: Dictionary = {"actor": "customer", "building": "pawnshop", "event_id": "before_arrival"}
	check(InstitutionsModule.norm(pack, state, "accept_stolen", args)["effects"].is_empty(), "a planned visitor's companions cannot witness before arriving")
	state["visits"][0]["status"] = "waiting"
	args["event_id"] = "waiting_before_arrival"
	check(InstitutionsModule.norm(pack, state, "accept_stolen", args)["effects"].is_empty(), "a premature waiting status does not place companions at the counter")
	state["minute"] = 500
	args["event_id"] = "actual_waiting"
	var result: Dictionary = InstitutionsModule.norm(pack, state, "accept_stolen", args)
	check(result["effects"].size() == 1 and result["effects"][0]["origin"] == "observer", "a companion actually waiting at the counter can witness despite a home schedule")
	check(Life.location(pack, state, "observer") == "家" and result["detected"].is_empty(), "counter presence leaves the ordinary schedule unchanged and police powers locked")
	state["minute"] = 520
	args["event_id"] = "expired_waiting"
	check(InstitutionsModule.norm(pack, state, "accept_stolen", args)["effects"].is_empty(), "an expired waiting visit supplies no eyewitness at its exact patience boundary")
	state["minute"] = 510
	state["visits"][0]["status"] = "completed"
	args["event_id"] = "completed_waiting"
	check(InstitutionsModule.norm(pack, state, "accept_stolen", args)["effects"].is_empty(), "completed visitors are not retained as permanent eyewitnesses")
	state["visits"][0]["status"] = "waiting"
	state["visits"][0]["companions"] = []
	args["event_id"] = "actor_alone"
	check(InstitutionsModule.norm(pack, state, "accept_stolen", args)["effects"].is_empty(), "an actual waiting actor cannot supply their own third-party sighting")
	state["visits"].append({"id": "observer_visit", "who": "observer", "status": "waiting", "minute": 500, "patience_min": 20, "companions": []})
	args["event_id"] = "other_waiting_customer"
	result = InstitutionsModule.norm(pack, state, "accept_stolen", args)
	check(result["effects"].size() == 1 and result["effects"][0]["origin"] == "observer", "a separate actual waiting customer's own presence also supplies an eyewitness")
	state["unlocked"]["police"] = true
	state["visits"][0]["companions"] = ["officer"]
	args["event_id"] = "waiting_authority"
	result = InstitutionsModule.norm(pack, state, "accept_stolen", args)
	check(result["detected"] == ["witnessed_goods"], "an available authority actually accompanying a visitor can witness at the counter")
	var world = EvidenceWorld.new()
	world.npcs["officer"] = {"present": false}
	args["event_id"] = "absent_waiting_authority"
	check(InstitutionsModule.norm(pack, state, "accept_stolen", args, world)["detected"].is_empty(), "actual visit membership still respects an authority's present flag")
	var sim = Sim.new(pack, 42)
	sim.start_day()
	sim.s["minute"] = 510
	sim.s["visits"] = [{"id": "counter_trade", "who": "customer", "intent": "sell_stolen", "status": "waiting", "minute": 500, "patience_min": 20, "companions": ["observer"]}]
	sim.visit_result("counter_trade", {"accepted": true, "price": 1})
	check(sim.s["known"].get("observer", {}).has("pawnshop_fenced") and sim.s["visits"][0]["status"] == "completed", "visit completion records the actual companion's observation before closing the wait")
	var before: String = JSON.stringify(sim.to_dict())
	sim.visit_result("counter_trade", {"accepted": true, "price": 1})
	check(JSON.stringify(sim.to_dict()) == before, "replaying a completed transaction cannot re-add its companion's observation")


func _pure_trade_fixture(intent: String, stock: Array = []) -> Dictionary:
	var pack: Dictionary = _quiet_pack()
	pack["npcs"] = {}
	for npc in ["xiaoding", "zhouma"]:
		pack["npcs"][npc] = shipped["npcs"][npc].duplicate(true)
		pack["npcs"][npc]["schedule"] = {"default": ["家", "家", "家", "家", "家", "家"]}
		pack["npcs"][npc]["visit"] = {"base": 0.0, "intents": {"sell": 1.0}}
		pack["npcs"][npc]["links"] = {}
	pack["strangers"]["per_day"] = {"base": 0, "max": 0}
	pack["visit_config"]["need_gain"] = 0.0
	pack["visit_config"]["market_visit_gain"] = 0.0
	var sim = Sim.new(pack, 42)
	sim.s["stock"] = stock.duplicate(true)
	sim.s["spawns"] = [{"id": "actual_trade", "who": "xiaoding", "intent": intent, "due": 1, "minute": 500, "slot": 0, "patience_min": 30, "companions": ["zhouma"]}]
	sim.start_day()
	sim.set_minute(510)
	var visit: Dictionary = {}
	for planned in sim.s["visits"]:
		if str(planned["id"]) == "actual_trade":
			visit = planned
	var session: Dictionary = visit.get("session", {})
	var has_goods: bool = not session.get("stock", []).is_empty() if str(session.get("mode", "")) == "sell" else not session.get("_item_defs", {}).is_empty()
	check(not visit.is_empty() and visit["status"] == "waiting" and visit["companions"] == ["zhouma"] and has_goods, "settlement fixture has a generated session and its actual waiting companion: " + intent)
	return {"sim": sim, "visit": visit}


func _pure_trade_settlement() -> void:
	var fixture: Dictionary = _pure_trade_fixture("sell_stolen")
	var sim = fixture["sim"]
	var visit: Dictionary = fixture["visit"]
	if visit.is_empty():
		return
	var stock: Array = visit["session"]["_item_defs"].values().duplicate(true)
	var cash_before: Dictionary = sim.s["cash"].duplicate(true)
	var journal_before: Array = sim.s["cash_journal"].duplicate(true)
	sim.visit_result(str(visit["id"]), {"accepted": true, "price": int(sim.s["cash"]["player"]) + 1})
	check(not bool(visit["outcome"].get("settled", true)) and sim.s["stock"].is_empty(), "an accepted stolen-goods offer with insufficient player cash never settles or grants inventory")
	check(sim.s["cash"] == cash_before and sim.s["cash_journal"] == journal_before and sim.s["transfer_requests"].is_empty(), "failed pure settlement moves no money and records no successful transfer")
	check(not sim.s["known"].get("zhouma", {}).has("pawnshop_fenced") and not sim.s.get("norm_results", {}).has(visit["id"]) and int(sim.s["stolen_stock"]) == 0, "actual companions do not spread a completed intake accusation for an unpaid rejected transaction")
	var before: String = JSON.stringify(sim.to_dict())
	sim.visit_result(str(visit["id"]), {"accepted": true, "price": 1})
	check(JSON.stringify(sim.to_dict()) == before, "replaying an unsettled completed visit cannot manufacture its transaction")
	fixture = _pure_trade_fixture("buy", stock)
	sim = fixture["sim"]
	visit = fixture["visit"]
	cash_before = sim.s["cash"].duplicate(true)
	var stock_before: Array = sim.s["stock"].duplicate(true)
	sim.visit_result(str(visit["id"]), {"accepted": true, "price": int(sim.s["cash"]["xiaoding"]) + 1})
	check(visit["session"]["mode"] == "sell" and not bool(visit["outcome"].get("settled", true)) and sim.s["stock"] == stock_before and sim.s["cash"] == cash_before, "an actual buyer with insufficient funds cannot remove stock or transfer cash")
	for intent in ["sell_stolen", "pawn", "buy"]:
		for price_value in [0, -1]:
			fixture = _pure_trade_fixture(str(intent), stock if intent == "buy" else [])
			sim = fixture["sim"]
			visit = fixture["visit"]
			cash_before = sim.s["cash"].duplicate(true)
			stock_before = sim.s["stock"].duplicate(true)
			sim.visit_result(str(visit["id"]), {"accepted": true, "price": price_value})
			check(not bool(visit["outcome"].get("settled", true)) and sim.s["cash"] == cash_before and sim.s["cash_journal"].is_empty(), "nonpositive pure price is rejected without money movement: %s/%d" % [intent, price_value])
			check(sim.s["stock"] == stock_before and sim.s["tickets"].is_empty() and sim.s["pawn_items"].is_empty(), "nonpositive price cannot grant/remove goods or create a zero-principal pawn: %s/%d" % [intent, price_value])
			check(not sim.s["known"].get("zhouma", {}).has("pawnshop_fenced") and int(sim.s["stolen_stock"]) == 0, "a nonpositive uncompleted intake creates no eyewitness accusation: %s/%d" % [intent, price_value])
	fixture = _pure_trade_fixture("sell_stolen")
	sim = fixture["sim"]
	visit = fixture["visit"]
	var definitions: Array = visit["session"]["_item_defs"].values().duplicate(true)
	cash_before = sim.s["cash"].duplicate(true)
	sim.visit_result(str(visit["id"]), {"accepted": true, "price": 1})
	check(bool(visit["outcome"].get("settled", false)) and sim.s["stock"] == definitions and int(sim.s["cash"]["player"]) == int(cash_before["player"]) - 1, "a positive funded intake still pays the seller and retains the generated goods")
	check(sim.s["known"].get("zhouma", {}).has("pawnshop_fenced") and int(sim.s["stolen_stock"]) == 1 and visit["status"] == "completed", "a real settled intake records its waiting companion's accusation before closing the visit")
	fixture = _pure_trade_fixture("pawn")
	sim = fixture["sim"]
	visit = fixture["visit"]
	sim.visit_result(str(visit["id"]), {"accepted": true, "principal": 1})
	check(bool(visit["outcome"].get("settled", false)) and int(sim.s["tickets"]["xiaoding"]["principal"]) == 1 and not sim.s["pawn_items"]["xiaoding"].is_empty(), "a funded positive pawn principal still settles through its existing outcome field")
	# Session owns attached-world settlement. Simulate its already completed
	# real ledger transfer; TownSim must neither require a pure price field nor
	# charge the transaction twice when the caller reports the acceptance.
	fixture = _pure_trade_fixture("sell_stolen")
	sim = fixture["sim"]
	visit = fixture["visit"]
	var world = EvidenceWorld.new()
	world.ledger.open_account("player", 100)
	world.ledger.open_account("xiaoding", 10)
	world.npcs = {"xiaoding": {"present": true}, "zhouma": {"present": true}}
	world.ledger.transfer("player", "xiaoding", 1, "柜台成交", str(visit["id"]), "session:actual_trade")
	var item: Dictionary = visit["session"]["_item_defs"].values()[0]
	var item_id: String = world.ledger.add_item(item, "player", "stock")
	sim.world = world
	var accounts: Dictionary = world.ledger.accounts.duplicate(true)
	var journal: Array = world.ledger.journal.duplicate(true)
	sim.visit_result(str(visit["id"]), {"accepted": true})
	check(sim.s["known"].get("zhouma", {}).has("pawnshop_fenced") and visit["status"] == "completed", "a Session-settled attached-world acceptance still records its actual waiting witness without a pure price")
	check(world.ledger.accounts == accounts and world.ledger.journal == journal and world.ledger.items[item_id]["location"] == "stock", "attached-world acceptance adds no duplicate settlement or item movement")
	check(world.ledger.check_invariants().is_empty(), "the existing attached-world settlement preserves ledger invariants")


func _unlocks() -> void:
	var state: Dictionary = _state(21)
	state["unlocked"] = {}
	check(not UnlocksModule.check(shipped, state).has("police") and not state["unlocked"].get("police", false), "police remain closed before the historical date with low heat")
	state["day"] = 22
	check(UnlocksModule.check(shipped, state).has("police") and state["unlocked"]["police"], "police unlock on day 22")
	var news_count: int = state["day_report"]["news"].size()
	check(UnlocksModule.check(shipped, state).is_empty() and state["day_report"]["news"].size() == news_count, "unlock notices are not repeated")
	for pressure in ["heat", "unrest"]:
		state = _state(1)
		state["unlocked"] = {}
		state["pressures"][pressure] = 0.3 if pressure == "heat" else 0.35
		check(UnlocksModule.check(shipped, state).has("police"), "police can open early at the declared " + str(pressure) + " threshold")
		state["pressures"][pressure] = 0.0
		UnlocksModule.check(shipped, state)
		check(state["unlocked"]["police"], "an already opened institution remains unlocked after pressure falls")
	var pack: Dictionary = _quiet_pack()
	pack["spine"] = shipped["spine"].duplicate(true)
	var sim = Sim.new(pack, 42)
	for day in range(1, 23):
		var plan: Dictionary = sim.start_day()
		check(bool(sim.s["unlocked"].get("police", false)) == (day >= 22), "daily pipeline opens police at the historical day")
		if day == 22:
			check(plan["unlocked_today"].count("police") == 1, "spine and condition checks produce one opening receipt")
		sim.end_day()


func _schedules() -> void:
	var pack: Dictionary = {"time": shipped["time"], "buildings": shipped["buildings"], "npcs": {
		"test": {"home": "家", "schedule": {
			"default": ["家", "桥头街", "茶馆", "米行", "家", "家"],
			"weekday:0": ["茶馆"], "weather:雨": ["米行"], "day:7": ["pawnshop"],
		}},
	}}
	var state: Dictionary = _state(1)
	state["weather"] = "晴"
	check(Life.location(pack, state, "test", 539) == "家" and Life.location(pack, state, "test", 540) == "桥头街", "schedule changes precisely at a slot boundary")
	check(Life.location(pack, state, "test", 720) == "茶馆", "explicit minute overrides the state's current minute")
	state["day"] = 0
	check(Life.location(pack, state, "test") == "茶馆", "weekday override replaces the default schedule")
	state["weather"] = "雨"
	check(Life.location(pack, state, "test") == "米行", "weather override takes precedence over weekday")
	state["day"] = 7
	check(Life.location(pack, state, "test") == "德厚当", "exact-day override takes precedence and resolves building IDs to map names")
	check(Life.location(pack, state, "missing") == "", "unknown NPC has no omniscient location")
	pack["npcs"]["test"]["requires_building"] = "police"
	state["unlocked"]["police"] = false
	check(Life.location(pack, state, "test") == "", "unavailable NPC is absent from its scheduled place")
	var required: Array = ["德厚当", "桥头街", "茶馆", "米行", "济生堂", "保公所", "邮电局", "码头", "孙府", "集市", "镇外", "家"]
	for place in required:
		check(shipped["places"].has(place), "pack declares map place: " + str(place))
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cast.json"))
	for npc in cast["npcs"]:
		check(shipped["npcs"].has(npc) and shipped["npcs"][npc].get("schedule", {}).has("default"), "cast NPC has a default town schedule: " + str(npc))
	for npc in shipped["npcs"]:
		for override in shipped["npcs"][npc].get("schedule", {}):
			var row: Array = shipped["npcs"][npc]["schedule"][override]
			check(row.size() == shipped["time"]["slots"].size(), "shipped schedule covers every daily slot: %s/%s" % [npc, override])
			for place in row:
				check(shipped["places"].has(place), "schedule place is available on the town map: " + str(place))


func _visit_plans() -> void:
	var pack: Dictionary = _quiet_pack()
	pack["npcs"] = {}
	pack["strangers"]["per_day"] = {"base": 0, "max": 0}
	pack["visit_config"]["min_per_day"] = 3
	var state: Dictionary = _state()
	var visits: Array = Life.plan(pack, state)
	check(visits.size() == 3, "minimum visit guarantee works even when every normal visit probability is zero")
	var ids: Dictionary = {}
	for visit in visits:
		check(not ids.has(visit["id"]), "minimum-floor visits have unique IDs")
		ids[visit["id"]] = true
		check(int(visit["minute"]) >= 360 and int(visit["minute"]) < 1440 and int(visit["patience_min"]) >= int(pack["visit_config"]["patience_min"][0]), "floor visitor receives an actual arrival minute and patience")
	pack["visit_config"].merge({"min_per_day": 1, "max_probability": 1.0, "need_gain": 0.0, "companion_probability": 1.0, "companion_max": 1}, true)
	pack["npcs"] = {
		"a": {"cash": 100, "links": {"a": 1.0, "b": 1.0, "c": 1.0}, "schedule": {"default": ["德厚当"]}, "visit": {"base": 1.0, "intents": {"sell": 1.0}}},
		"b": {"requires_building": "police", "links": {}, "schedule": {"default": ["家"]}, "visit": {"base": 0.0}},
		"c": {"links": {}, "schedule": {"default": ["家"]}, "visit": {"base": 0.0}},
	}
	state = _state()
	state["weather"] = "晴"
	state["unlocked"]["police"] = false
	visits = Life.plan(pack, state)
	check(visits.size() == 1 and visits[0]["who"] == "a" and visits[0]["companions"] == ["c"], "linked companions respect presence, self-exclusion, and the declared cap")
	check(visits == Life.plan(pack, _same_visit_state(state)), "the same day produces the same companion and arrival plan")
	pack["npcs"]["a"]["visit"]["when"] = {"day_gte": 2}
	visits = Life.plan(pack, _same_visit_state(state))
	check(visits.size() == 1 and str(visits[0]["who"]).begins_with("stranger:"), "visit-specific date conditions suppress named visits while retaining the daily floor")
	state["spawns"] = [{"who": "c", "intent": "gossip", "due": 1, "companions": ["c", "a"]}, {"who": "a", "intent": "sell", "due": 3}]
	visits = Life.plan(pack, state)
	check(visits.size() == 1 and visits[0]["who"] == "c" and visits[0]["companions"] == ["a", "c"], "scheduled authored visitor arrives with stable companion ordering")
	check(state["spawns"].size() == 1 and int(state["spawns"][0]["due"]) == 3, "planning preserves future scheduled visitors")


func _same_visit_state(state: Dictionary) -> Dictionary:
	var fresh: Dictionary = state.duplicate(true)
	fresh["spawns"] = []
	return fresh


func _rumor_pack() -> Dictionary:
	return {"time": {"slots": ["清晨", "上午", "中午", "下午", "傍晚", "夜"]},
		"communication": {"delay_slots": 1, "confidence_decay": 0.5, "relay_probability": 1.0, "max_hops": 2, "ttl_slots": 12, "min_confidence": 0.1},
		"rumors": {"test": ["第一手", "第二手", "第三手"]},
		"npcs": {"a": {"links": {"b": 1.0, "c": 1.0}}, "b": {"links": {"a": 1.0, "d": 1.0}}, "c": {"links": {"d": 1.0}}, "d": {"links": {"e": 1.0}}, "e": {"links": {}}},
	}


func _rumors() -> void:
	var pack: Dictionary = _rumor_pack()
	var state: Dictionary = _state()
	state["slot"] = 5
	Rumors.plant(pack, state, "test", "a")
	check(state["known"].get("a", {}).has("test") and not state["known"].has("b"), "planting delivers only to the origin before the relay delay")
	check(state["player_rumors"].is_empty() and Rumors.hear(pack, state, "b").is_empty(), "queued rumors never become player news before delivery")
	var seq: int = int(state["seq"])
	var queued: int = state["queue"].size()
	Rumors.plant(pack, state, "test", "a", 0.7)
	check(int(state["seq"]) == seq and state["queue"].size() == queued, "the same root is deduplicated even while its relays wait")
	check(Rumors.deliver(pack, state).is_empty(), "replaying the current slot cannot deliver a future message")
	state["day"] = 2
	state["slot"] = 0
	var deliveries: Array = Rumors.deliver(pack, state)
	check(deliveries.size() == 2 and state["known"]["b"]["test"]["hops"] == 1, "one-slot relay delay correctly crosses midnight")
	check(is_equal_approx(float(state["known"]["b"]["test"]["conf"]), 0.5), "each hop applies declared confidence decay")
	check(state["queue"].size() == 1, "diamond paths queue one recipient once per root")
	var heard: Array = Rumors.hear(pack, state, "b")
	check(heard.size() == 1 and heard[0]["text"] == "第二手" and heard[0]["source"] == "heard" and heard[0]["via"] == "b", "hearing delivers the NPC's actual distorted message with its provenance")
	check(Rumors.hear(pack, state, "b").is_empty() and Rumors.hear(pack, state, "c").is_empty(), "player hears each rumor key once across all tellers")
	state["slot"] = 1
	deliveries = Rumors.deliver(pack, state)
	check(deliveries.size() == 1 and state["known"]["d"]["test"]["hops"] == 2 and state["known"]["d"]["test"]["via"] == "b", "first deterministic diamond path wins at the maximum allowed hop")
	state["slot"] = 4
	Rumors.deliver(pack, state)
	check(not state["known"].has("e") and state["queue"].is_empty(), "rumors stop at the declared hop limit")
	check(Rumors.rumor_text(pack, "test", 99) == "第三手", "distortion texts clamp at the final declared version")
	var expired_pack: Dictionary = _rumor_pack()
	expired_pack["communication"]["ttl_slots"] = 1
	state = _state()
	Rumors.plant(expired_pack, state, "test", "a")
	state["slot"] = 2
	check(Rumors.deliver(expired_pack, state).is_empty() and not state["known"].has("b") and state["queue"].is_empty(), "an expired queued rumor is discarded before becoming NPC knowledge")
	state = _state()
	expired_pack["communication"]["delay_slots"] = 2
	Rumors.plant(expired_pack, state, "test", "a")
	check(state["queue"].is_empty(), "a relay arriving after the TTL is never queued")
	var weak_pack: Dictionary = _rumor_pack()
	weak_pack["communication"]["min_confidence"] = 0.3
	state = _state()
	Rumors.plant(weak_pack, state, "test", "a")
	state["slot"] = 1
	Rumors.deliver(weak_pack, state)
	check(state["known"].has("b") and state["queue"].is_empty(), "confidence floor allows the first hop and blocks weaker later relays")
	pack["npcs"]["a"]["requires_building"] = "police"
	state = _state()
	state["unlocked"]["police"] = false
	Rumors.plant(pack, state, "test", "a")
	check(Rumors.hear(pack, state, "a").is_empty(), "an unavailable NPC cannot tell the player its knowledge")
	var untouched: Dictionary = _state()
	var before: String = JSON.stringify(untouched)
	Rumors.plant(pack, untouched, "test", "missing")
	check(JSON.stringify(untouched) == before, "unknown rumor origin cannot seed hidden knowledge")
