# T04 real backend acceptance. The T03 frontend has not been delivered; this
# intentionally makes no claim about walking, rendering or UI screenshots.
extends SceneTree

const Driver = preload("res://scripts/tests/town_play_driver.gd")
const Director = preload("res://scripts/core/director.gd")
const Player = preload("res://scripts/tests/town_play_policy.gd")
const Save = preload("res://scripts/core/save.gd")

const SEEDS: Array = [1, 73, 196, 19380306, 2147483647]
const STRATEGIES: Array = ["town_fair", "town_greedy", "town_random"]
var failures: Array = []
var checks: int = 0
var report: Array = []
var started: int = 0
var running: bool = true
var suite: String = "all"

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="): suite = arg.substr(8)

func _initialize() -> void:
	started = Time.get_ticks_msec()
	if suite in ["all", "smoke"]:
		await _test_prologue()
		await _test_full_runs()
	if suite in ["all", "plans"]: await _test_branches()
	if suite in ["all", "save"]: await _test_save()
	if suite in ["all", "boundaries"]: await _test_boundaries()
	if suite in ["all", "economy"]: await _test_economy()
	if suite in ["all", "edges"]: await _test_late_edges()
	running = false
	var file = FileAccess.open("user://town_acceptance_report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "runs": report}, "\t", true, true))
		file.close()
	DB.shutdown()
	if failures.is_empty():
		print("TOWN PLAY ACCEPTANCE OK: %d checks; %d run reports" % [checks, report.size()])
		quit(0)
	else:
		for failure in failures: printerr("FAIL: ", failure)
		print("TOWN PLAY ACCEPTANCE FAILED: %d/%d" % [failures.size(), checks])
		quit(1)

func _process(_delta: float) -> bool:
	if running and started > 0 and Time.get_ticks_msec() - started > 600000:
		printerr("FAIL: 600 second watchdog: coroutine softlock")
		quit(1)
	return false

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)

func _trace_beat(beat: Dictionary, output: Array) -> void:
	if str(beat["type"]) in ["say", "narr", "caption", "tutorial"]:
		output.append({"type": beat["type"], "text": beat.get("text", ""), "who": beat.get("who", "")})

func _test_prologue() -> void:
	var legacy = Director.new()
	root.add_child(legacy)
	legacy.setup(196)
	var legacy_player = Player.new(legacy, "town_fair", 196)
	var old_trace: Array = []
	legacy.beat.connect(_trace_beat.bind(old_trace))
	await legacy.run_script("prologue")
	var town = Driver.new(self, "town_fair", 196)
	var town_trace: Array = []
	town.director.beat.connect(_trace_beat.bind(town_trace))
	await town.prologue()
	_check(old_trace == town_trace and old_trace.size() > 35, "Town preserves the complete original prologue dialogue/tutorial")
	_check(town.director.town_storylets.get("prologue", "") == "prologue", "Town points at original prologue")
	_check(legacy_player.errors.is_empty() and town.all_errors().is_empty(), "Both original and town prologues satisfy ledger invariants")
	legacy.beat.disconnect(legacy_player._on_beat)
	legacy_player.director = null
	legacy_player = null
	legacy.queue_free()
	legacy = null
	await town.dispose()

func _test_full_runs() -> void:
	for strategy in STRATEGIES:
		for seed in SEEDS:
			var run = Driver.new(self, str(strategy), int(seed))
			await run.prologue()
			await run.run_days(1, 14)
			var label := "%s seed=%d" % [strategy, seed]
			_check(run.all_errors().is_empty(), label + " no beat/action/ledger failures: " + str(run.all_errors()))
			_check(run.days.size() == 14 and run.director.world.day == 14, label + " completed all 14 days")
			_check(run.generated_sessions.size() >= 8, label + " executed actual generated runtime sessions")
			var generated_beats := 0
			for sid in run.player.sessions_seen:
				if str(sid).begins_with("gen_d"): generated_beats += 1
			_check(generated_beats >= 8, label + " generated sessions actually emitted counter beats")
			_check(run.director.world.flags.get("ticket196", false), label + " original ticket196 reached")
			_check(not run.director.done and not run.director.stopped, label + " ticket196 continues into day3–14")
			var done: Dictionary = run.director.vars["town"]["done_cards"]
			_check(done.size() >= 20, label + " executed authored story cards across 14 days")
			for card in ["d1_open", "d1_xiaoding", "d1_zhang", "d1_wangshan", "d1_li", "d2_pawn_lesson", "d2_linsao", "d2_zhouma", "d2_zhao", "d2_sunyoung", "d2_ma", "d2_brother_farewell", "n1_backdoor_and_lamp", "n2_telegram_backdoor", "n2_ticket196", "d3_chen", "d4_first_letter", "d5_wangshan", "d7_fees", "n14_accounts"]:
				_check(done.has(card), label + " real authored card " + card)
			_check(done.get("d4_first_letter") == 4 and done.get("d5_wangshan") == 5 and (done.get("d9_wangshan_iou") == 9 or done.get("d9_no_iou") == 9), label + " letter4/Wangshan5/debt9 scheduled on actual dates")
			_check(run.days[1]["flags"].get("ticket196", false) and not run.days[2]["flags"].get("brother_letter_1", false) and run.days[3]["flags"].get("brother_letter_1", false), label + " ticket on night2, first letter on day4")
			_check(run.director.world.ledger.foreign_tickets.size() == 1, label + " exactly one original ticket196")
			_check(run.director.world.ledger.check_invariants().is_empty(), label + " final ledger invariants")
			for sid in ["d1_xiaoding", "d1_zhang", "d1_li", "d2_linsao", "d2_zhao", "d2_sunyoung"]:
				_check(run.player.sessions_seen.has(sid), label + " visited original " + sid)
			_check(int(run.player.counts.get("telegraph", 0)) >= 2, label + " night telegrams actually ran")
			var row := _outcome(run)
			row["strategy"] = strategy
			row["seed"] = seed
			row["generated_sessions"] = run.generated_sessions.size()
			row["authored_cards"] = done.size()
			report.append(row)
			print("TOWN14 %s: generated=%d cards=%d beats=%d cash=%d" % [label, run.generated_sessions.size(), done.size(), run.player.beats, run.director.world.cash()])
			await run.dispose()

func _outcome(run) -> Dictionary:
	var world = run.director.world
	return {"day": world.day, "cash": world.cash(), "flags": world.flags.duplicate(true),
		"koubei": world.koubei, "benxin": world.benxin, "household": run.director.vars["town"]["household"].duplicate(true),
		"contracts": world.ledger.contracts.duplicate(true), "debts": world.ledger.debts.duplicate(true),
		"accounts": world.ledger.accounts.duplicate(true), "bills": world.town.bills(), "stock": world.ledger.items_at("stock"), "journal_rows": world.ledger.journal.size()}

func _test_branches() -> void:
	var loaded = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/plans_town.json"))
	_check(loaded is Dictionary and loaded.get("plans", {}).size() >= 10, "At least ten authored branch plans")
	if not loaded is Dictionary: return
	var outcomes: Dictionary = {}
	for name in loaded.get("plans", {}):
		var plan: Dictionary = loaded["plans"][name].duplicate(true)
		plan["id"] = name
		var run = Driver.new(self, str(plan.get("strategy", "town_fair")), 196, plan)
		await run.prologue()
		await run.run_days(1, int(plan.get("until_day", 14)))
		_check(run.all_errors().is_empty(), "Plan %s has no runtime/invariant failures: %s" % [name, str(run.all_errors())])
		_check(run.hooks_done.size() == plan.get("actions", []).size(), "Plan %s executed every requested action" % name)
		for key in plan.get("expect_flags", {}):
			_check(run.director.world.flags.get(key) == plan["expect_flags"][key], "Plan %s flag %s expected %s got %s" % [name, key, str(plan["expect_flags"][key]), str(run.director.world.flags.get(key))])
		for unlock in plan.get("expect_unlocked", []):
			_check(run.director.world.unlocked.get(unlock, false), "Plan %s unlocks %s" % [name, unlock])
		for expectation in plan.get("expect_contracts", []):
			var found := false
			for contract in run.director.world.ledger.contracts.values():
				if contract["borrower"] != str(expectation["borrower"]): continue
				found = true
				for key in expectation:
					_check(contract.get(key) == expectation[key], "Plan %s contract %s=%s got %s" % [name, key, str(expectation[key]), str(contract.get(key))])
			_check(found, "Plan %s contract exists for %s" % [name, expectation["borrower"]])
		for expectation in plan.get("expect_debts", []):
			var found := false
			for debt in run.director.world.ledger.debts.values():
				if debt["debtor"] != expectation["debtor"] or debt["creditor"] != expectation["creditor"]: continue
				found = true
				for key in expectation:
					_check(debt.get(key) == expectation[key], "Plan %s debt %s=%s got %s" % [name, key, str(expectation[key]), str(debt.get(key))])
			_check(found, "Plan %s opens the actual requested debt" % name)
		if plan.get("expect_overdue", false):
			var overdue := false
			for bill in run.director.world.town.bills(): overdue = overdue or bill["status"] == "overdue"
			_check(overdue, "Plan %s produces actual overdue bills" % name)
		outcomes[name] = _outcome(run)
		var row: Dictionary = outcomes[name].duplicate(true)
		row["plan"] = name
		report.append(row)
		print("TOWN PLAN %s: cash=%d cards=%d" % [name, run.director.world.cash(), run.director.vars["town"]["done_cards"].size()])
		await run.dispose()
	for pair in loaded.get("compare", []):
		if not outcomes.has(pair[0]) or not outcomes.has(pair[1]):
			_check(false, "Missing compared branch outcome " + str(pair))
			continue
		var left: Dictionary = outcomes[pair[0]]
		var right: Dictionary = outcomes[pair[1]]
		for field in pair[2]: _check(left.get(field) != right.get(field), "%s versus %s differs in actual %s" % [pair[0], pair[1], field])

func _snapshot(run, context: Dictionary = {}) -> Dictionary:
	return Save.snapshot(run.director.world, run.director.world.town, run.director, context)

func _encoded(snapshot: Dictionary) -> String:
	return JSON.stringify(snapshot, "", true, true)

func _test_save() -> void:
	var continuous = Driver.new(self, "town_random", 2147483647)
	await continuous.prologue()
	await continuous.run_days(1, 9)
	continuous.begin_day(10)
	await continuous.visits_until(900)
	var context := {"minute": 900, "map_id": "pawnshop", "player_pos": [136.25, 74.5]}
	var saved: Dictionary = _snapshot(continuous, context)
	_check(not saved.is_empty(), "Actual day10 midpoint can snapshot: " + Save.last_error)
	var resumed = Driver.new(self, "town_random", 1)
	var read_context: Dictionary = {}
	var json_roundtrip = JSON.parse_string(_encoded(saved))
	var restored: bool = Save.restore(json_roundtrip, resumed.director.world, resumed.director.world.town, resumed.director, continuous.director.world.town.pack, read_context)
	_check(restored, "Actual midpoint JSON restore accepted: " + Save.last_error)
	_check(_encoded(_snapshot(resumed, read_context)) == _encoded(saved), "Day10 JSON restore preserves every saved field and float bit")
	# Player bookkeeping describes completed callbacks only and is outside game
	# state; copy it so intentionally repeated scripted choices keep their place.
	resumed.player.seed = continuous.player.seed
	resumed.player.state = continuous.player.state.duplicate(true)
	resumed.player.choices = continuous.player.choices.duplicate(true)
	resumed.day_visits = continuous.day_visits.duplicate(true)
	var stable := _encoded(_snapshot(resumed, read_context))
	for variant in ["pack_hash", "version", "malformed_ledger", "malformed_sim", "malformed_float"]:
		var invalid: Dictionary = saved.duplicate(true)
		match variant:
			"pack_hash": invalid["pack_hash"] = "another_pack"
			"version": invalid["version"] = Save.VERSION + 1
			"malformed_ledger": invalid["ledger"]["accounts"]["player"] = -1
			"malformed_sim": invalid["town_sim"]["visits"] = "invalid"
			"malformed_float": invalid["player_pos"] = [{"$town_f64": "xx"}, 0]
		var before_context := read_context.duplicate(true)
		_check(not Save.restore(invalid, resumed.director.world, resumed.director.world.town, resumed.director, continuous.director.world.town.pack, read_context), "Reject " + variant)
		_check(_encoded(_snapshot(resumed, read_context)) == stable and read_context == before_context, "Reject " + variant + " atomically preserves all live state/context")
	var path := "user://town_acceptance_day10.json"
	_check(Save.write(path, continuous.director.world, continuous.director.world.town, continuous.director, context), "Atomic file save writes actual midpoint")
	_check(Save.write(path, continuous.director.world, continuous.director.world.town, continuous.director, context), "Atomic file save replaces previous file")
	_check(not FileAccess.file_exists(path + ".tmp"), "Atomic rename leaves no temporary file")
	_check(Save.read(path, resumed.director.world, resumed.director.world.town, resumed.director, continuous.director.world.town.pack, read_context), "Read actual saved file")
	_check(_encoded(_snapshot(resumed, read_context)) == _encoded(saved), "File read preserves exact full midpoint snapshot")
	var corrupt_path := "user://town_acceptance_corrupt.json"
	var corrupt_file = FileAccess.open(corrupt_path, FileAccess.WRITE)
	corrupt_file.store_string("{\"version\":1,\"world\":")
	corrupt_file.close()
	_check(not Save.read(corrupt_path, resumed.director.world, resumed.director.world.town, resumed.director, continuous.director.world.town.pack, read_context), "Malformed/truncated save file is rejected")
	_check(_encoded(_snapshot(resumed, read_context)) == _encoded(saved), "Malformed file read preserves every live state field")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	await continuous.visits_until()
	await continuous.finish_day()
	await continuous.run_days(11, 14)
	await resumed.visits_until()
	await resumed.finish_day()
	await resumed.run_days(11, 14)
	var final_context := {"map_id": "pawnshop", "player_pos": [136.25, 74.5]}
	var expected := _encoded(_snapshot(continuous, final_context))
	var actual := _encoded(_snapshot(resumed, final_context))
	_check(expected == actual, "Actual day10midpoint→day14 replay matches every saved field bitwise")
	_check(continuous.all_errors().is_empty() and resumed.all_errors().is_empty(), "Continuous and resumed runs have no softlock/invariant failures")
	if expected != actual: _describe_diff(JSON.parse_string(expected), JSON.parse_string(actual), "save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await continuous.dispose()
	await resumed.dispose()

func _describe_diff(left, right, path: String, depth: int = 0) -> void:
	if depth > 12 or left == right: return
	if left is Dictionary and right is Dictionary:
		for key in left:
			if not right.has(key): print("SAVE DIFF missing ", path + "." + str(key))
			elif left[key] != right[key]: _describe_diff(left[key], right[key], path + "." + str(key), depth + 1)
	elif left is Array and right is Array:
		if left.size() != right.size(): print("SAVE DIFF size ", path, " ", left.size(), " ", right.size())
		for index in range(mini(left.size(), right.size())):
			if left[index] != right[index]: _describe_diff(left[index], right[index], path + "[%d]" % index, depth + 1)
	else: print("SAVE DIFF ", path, " ", str(left).left(120), " / ", str(right).left(120))

# Caller-owned time and idempotent requests must not let stale client dictionaries
# execute a future, expired or already absent visitor.
func _test_boundaries() -> void:
	var run = Driver.new(self, "town_fair", 196, {"refuse_generated": true})
	await run.prologue()
	run.director.town_start_day()
	var visits: Array = run.director.town_visits()
	var generated: Dictionary = {}
	var story: Dictionary = {}
	for visit in visits:
		if str(visit.get("session", {}).get("id", "")).begins_with("gen_d") and generated.is_empty(): generated = visit.duplicate(true)
		if str(visit.get("storylet", "")) == "d1_li": story = visit.duplicate(true)
	_check(not generated.is_empty() and not story.is_empty(), "Boundary checks use actual generated and authored visitors")
	if generated.is_empty() or story.is_empty():
		await run.dispose()
		return
	var baseline := _encoded(_snapshot(run))
	var premature: Dictionary = await run.director.run_town_visit(generated)
	_check(not premature.get("ok", false), "Generated future visit is rejected before its minute")
	_check(_encoded(_snapshot(run)) == baseline, "Future visit rejection preserves the entire game snapshot")
	var story_early: Dictionary = await run.director.run_town_visit(story)
	_check(not story_early.get("ok", false), "Authored future visit is rejected before its minute")
	_check(_encoded(_snapshot(run)) == baseline, "Future story rejection preserves the entire game snapshot")
	# Consume one real visit, then its old request must return its original receipt
	# without another counter, transfer or story operation.
	run.director.world.town.set_minute(int(generated["minute"]))
	var first: Dictionary = await run.director.run_town_visit(generated)
	baseline = _encoded(_snapshot(run))
	var replay: Dictionary = await run.director.run_town_visit(generated)
	_check(first == replay, "Completed visit replays the original outcome receipt")
	_check(_encoded(_snapshot(run)) == baseline, "Completed visit replay changes no saved field")
	# Start another day to obtain an unconsumed generated visitor, then expire it.
	run.director.town_finish_day()
	run.director.town_start_day()
	generated = {}
	for visit in run.director.town_visits():
		if str(visit.get("session", {}).get("id", "")).begins_with("gen_d"):
			generated = visit.duplicate(true)
			break
	_check(not generated.is_empty(), "Expiry checks use a fresh actual generated visitor")
	if not generated.is_empty():
		run.director.world.town.set_minute(mini(1440, int(generated["minute"]) + int(generated["patience_min"]) + 1))
		var ledger_before := JSON.stringify(run.director.world.ledger.to_dict(), "", true, true)
		var expired: Dictionary = await run.director.run_town_visit(generated)
		_check(not expired.get("ok", false), "Expired generated visitor is rejected")
		_check(JSON.stringify(run.director.world.ledger.to_dict(), "", true, true) == ledger_before, "Expired visitor is marked absent without any money/item/contract transaction")
		baseline = _encoded(_snapshot(run))
		var forged: Dictionary = generated.duplicate(true)
		forged["minute"] = 360
		forged["patience_min"] = 1440
		forged["status"] = "planned"
		var forged_result: Dictionary = await run.director.run_town_visit(forged)
		_check(not forged_result.get("ok", false), "Caller-edited old visit cannot extend its real patience or status")
		_check(_encoded(_snapshot(run)) == baseline, "Forged visitor rejection preserves every saved field")
	run.director.world.town.set_minute(maxi(int(run.director.world.town.s["minute"]), int(story["minute"])))
	baseline = _encoded(_snapshot(run))
	var wrong_day: Dictionary = await run.director.run_town_visit(story)
	_check(not wrong_day.get("ok", false), "Yesterday's authored visitor cannot execute during today's matching minute window")
	_check(_encoded(_snapshot(run)) == baseline, "Wrong-day authored rejection preserves all state")
	var forged_story: Dictionary = story.duplicate(true)
	forged_story["minute"] = 0
	forged_story["end_minute"] = 1440
	forged_story["script"] = "prologue"
	var forged_story_result: Dictionary = await run.director.run_town_visit(forged_story)
	_check(not forged_story_result.get("ok", false), "Caller cannot forge an authored script or its date/minute window")
	_check(_encoded(_snapshot(run)) == baseline, "Forged authored rejection preserves every state field")
	run.director.world.town.set_minute(1261)
	baseline = _encoded(_snapshot(run))
	var old_story: Dictionary = await run.director.run_town_visit(story)
	_check(not old_story.get("ok", false), "Old authored dictionary cannot bypass its date/window")
	_check(_encoded(_snapshot(run)) == baseline, "Old authored rejection preserves the entire snapshot")
	await run.dispose()
	# Request identity covers semantic action arguments, not only the item id.
	var requests = Driver.new(self, "town_fair", 196)
	await requests.prologue()
	requests.begin_day(1)
	var shelf: Array = requests.director.town_action("shelf").get("items", [])
	_check(shelf.size() >= 2, "Request checks use real inherited sale stock")
	if shelf.size() >= 2:
		var original := {"iid": shelf[0]["iid"], "request_id": "semantic-sale"}
		var accepted: Dictionary = requests.director.town_action("sell", original)
		_check(accepted.get("ok", false), "Initial public sale request succeeds")
		baseline = _encoded(_snapshot(requests))
		var duplicate: Dictionary = requests.director.town_action("sell", original)
		_check(duplicate == accepted and _encoded(_snapshot(requests)) == baseline, "Same semantic request returns receipt atomically")
		var conflict: Dictionary = requests.director.town_action("sell", {"iid": shelf[1]["iid"], "request_id": "semantic-sale"})
		_check(not conflict.get("ok", false) and conflict.get("error") == "request_conflict", "Same request id with a different item is rejected")
		_check(_encoded(_snapshot(requests)) == baseline, "Different semantic request leaves every game field unchanged")
		conflict = requests.director.town_action("find_buyer", original)
		_check(not conflict.get("ok", false) and conflict.get("error") == "request_conflict", "Same request id with a different action is rejected")
		_check(_encoded(_snapshot(requests)) == baseline, "Different action request rejection is atomic")
	await requests.dispose()

	# A real week creates independent rent, levy and living-cost bills. One
	# outer request must settle all affordable rows with distinct child keys.
	var plans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/plans_town.json"))
	var billing_plan: Dictionary = plans["plans"]["fair_active"].duplicate(true)
	billing_plan["refuse_day1"] = true
	var billing = Driver.new(self, "town_fair", 196, billing_plan)
	await billing.prologue()
	await billing.run_days(1, 6)
	billing.begin_day(7)
	var due_count := 0
	for bill in billing.director.world.town.bills():
		if bill["status"] in ["due", "overdue"]: due_count += 1
	_check(due_count >= 2, "Aggregate payment uses multiple actual outstanding bills")
	var cash_before: int = billing.director.world.cash()
	var payment: Dictionary = billing.director.town_action("pay_bills", {"request_id": "week-all-bills"})
	_check(payment.get("ok", false) and payment.get("receipts", []).size() >= 2, "One request actually pays multiple independent bills: " + str(payment))
	_check(cash_before - billing.director.world.cash() == int(payment.get("paid", 0)) and int(payment.get("paid", 0)) > 0, "Aggregate receipt amount equals actual player cash transferred")
	var remaining := 0
	for bill in billing.director.world.town.bills():
		if bill["status"] in ["due", "overdue"]: remaining += 1
	_check(remaining == 0, "All actual outstanding bills settled")
	baseline = _encoded(_snapshot(billing))
	var payment_replay: Dictionary = billing.director.town_action("pay_bills", {"request_id": "week-all-bills"})
	_check(payment_replay == payment and _encoded(_snapshot(billing)) == baseline, "Aggregate retry returns exact receipt without another child transfer")
	var payment_conflict: Dictionary = billing.director.town_action("pay_bills", {"request_id": "week-all-bills", "amount": 1})
	_check(payment_conflict.get("error", "") == "request_conflict" and _encoded(_snapshot(billing)) == baseline, "Aggregate request reused with different payment terms rejects atomically")
	_check(billing.director.world.ledger.check_invariants().is_empty(), "Aggregate payment conserves real ledger accounts")
	await billing.dispose()

func _test_economy() -> void:
	var plans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/plans_town.json"))
	var social_plan: Dictionary = plans["plans"]["fair_active"].duplicate(true)
	var social = Driver.new(self, "town_fair", 196, social_plan)
	await social.prologue()
	await social.run_days(1, 9)
	social.begin_day(10)
	var social_bill: Dictionary = {}
	for bill in social.director.world.town.bills():
		if bill.get("cost_id", "") == "social" and str(bill.get("source", "")).contains("zhouma_d10"):
			social_bill = bill
			break
	_check(not social_bill.is_empty(), "Social regression uses the actual authored invitation and its generated bill")
	var gift: Dictionary = social.director.town_action("gift", {"id": "zhouma_d10", "request_id": "real-invitation-gift"})
	_check(gift.get("ok", false), "Public gift actually transfers the invitation gift")
	if not social_bill.is_empty():
		var cash_after: int = social.director.world.cash()
		var ledger_after := JSON.stringify(social.director.world.ledger.to_dict(), "", true, true)
		var social_payment: Dictionary = social.director.town_action("pay_bills", {"bill_id": social_bill["id"], "request_id": "gift-bill-reconcile"})
		_check(social.director.world.cash() == cash_after and int(social_payment.get("paid", 0)) == 0, "Gift followed by its social bill never charges a second time")
		_check(JSON.stringify(social.director.world.ledger.to_dict(), "", true, true) == ledger_after, "Gift reconciliation makes no additional ledger transfer")
		var settled := false
		for bill in social.director.world.town.bills():
			if bill["id"] == social_bill["id"]: settled = bill["status"] in ["paid", "waived"]
		_check(settled, "The real invitation's social bill is settled after the gift")
	_check(social.director.world.ledger.check_invariants().is_empty(), "Gift reconciliation preserves account conservation")
	await social.dispose()
	# Deplete real starting supplies through twelve actual sleeps. No fixture
	# edits or helper purchases hide whether paying a food/fuel bill feeds home.
	var home_plan: Dictionary = plans["plans"]["fair_active"].duplicate(true)
	home_plan["counter_only"] = true
	home_plan["refuse_day1"] = true
	home_plan["script_choices"]["town_day6_invitation"] = ["decline"]
	home_plan["script_choices"]["town_day10_invitation"] = ["decline"]
	var home = Driver.new(self, "town_fair", 196, home_plan)
	await home.prologue()
	await home.run_days(1, 12)
	home.begin_day(13)
	var before: Dictionary = home.director.town_action("household")["household"]
	_check(int(before["rice"]) == 0 and int(before["fuel"]) == 0, "Food/fuel regression consumes actual initial supplies completely: " + str(before))
	var food: Dictionary = {}
	var fuel: Dictionary = {}
	for bill in home.director.world.town.bills():
		if int(bill.get("created_day", -1)) != 13: continue
		if bill.get("cost_id", "") == "food": food = bill
		if bill.get("cost_id", "") == "fuel": fuel = bill
	_check(not food.is_empty() and not fuel.is_empty(), "Current real daily bills include food and fuel")
	if not food.is_empty() and not fuel.is_empty():
		var food_paid: Dictionary = home.director.town_action("pay_bills", {"bill_id": food["id"], "request_id": "day13-food"})
		var fuel_paid: Dictionary = home.director.town_action("pay_bills", {"bill_id": fuel["id"], "request_id": "day13-fuel"})
		_check(food_paid.get("ok", false) and fuel_paid.get("ok", false), "Public food and fuel bill payments succeed: " + str(food_paid) + " / " + str(fuel_paid))
		var supplied: Dictionary = home.director.town_action("household")["household"]
		_check(int(supplied["rice"]) >= 1 or int(home.director.vars["town"]["ate_out_day"]) == 13, "A paid food bill supplies an actual daily meal")
		var needed_fuel := 2 if home.director.world.weather in ["雨", "大风"] else 1
		_check(int(supplied["fuel"]) >= needed_fuel, "A paid fuel bill supplies the actual weather-adjusted daily fuel")
		await home.finish_day()
		var after: Dictionary = home.director.town_action("household")["household"]
		_check(int(after["hunger"]) <= int(before["hunger"]), "Sleep does not add hunger after a paid real meal")
		_check(int(after["cold"]) <= int(before["cold"]), "Sleep does not add cold after paid real fuel")
		var cash_after: int = home.director.world.cash()
		home.director.town_action("pay_bills", {"bill_id": food["id"], "request_id": "day13-food"})
		home.director.town_action("pay_bills", {"bill_id": fuel["id"], "request_id": "day13-fuel"})
		_check(home.director.world.cash() == cash_after, "Already paid household bill retries never charge twice")
	_check(home.all_errors().is_empty() and home.director.world.ledger.check_invariants().is_empty(), "Household payment run has no softlock or ledger failure")
	await home.dispose()

func _test_late_edges() -> void:
	var plans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/tests/plans_town.json"))
	var early = Driver.new(self, "town_fair", 196, plans["plans"]["fair_active"])
	await early.prologue()
	await early.run_days(1, 5)
	early.begin_day(6)
	await early.visits_until(900)
	var before: int = early.director.world.cash()
	var gift: Dictionary = early.director.town_action("gift", {"id": "zhouma_d10", "amount": 11, "request_id": "early-eleven-gift"})
	_check(gift.get("ok", false) and early.director.world.cash() == before - 11, "Gift on the real invitation's arrival day transfers exactly the custom eleven")
	early.director.town_finish_day()
	early.begin_day(7)
	var bill: Dictionary = {}
	for row in early.director.world.town.bills():
		if row["id"] == "bill:social:zhouma_d10": bill = row
	_check(not bill.is_empty() and bill.get("status") == "paid" and int(bill.get("amount", 0)) == 11 and int(bill.get("paid", 0)) == 11, "A later generated social bill preserves the earlier gift's actual eleven-payment receipt")
	var reconciled_cash: int = early.director.world.cash()
	var reconciled_ledger := JSON.stringify(early.director.world.ledger.to_dict(), "", true, true)
	early.director.town_action("pay_bills", {"bill_id": "bill:social:zhouma_d10", "request_id": "early-gift-later-bill"})
	_check(early.director.world.cash() == reconciled_cash and JSON.stringify(early.director.world.ledger.to_dict(), "", true, true) == reconciled_ledger, "The later social bill cannot charge the early gift a second time")
	# Partial payment is an actual transaction even when its aggregate ok flag
	# is false because some debt remains. Retrying must replay that transaction.
	var rent_id := "legacy_bill_0"
	var partial_cash: int = early.director.world.cash()
	var partial: Dictionary = early.director.town_action("pay_bills", {"bill_id": rent_id, "amount": 5, "request_id": "partial-rent"})
	_check(not partial.get("ok", true) and int(partial.get("paid", 0)) == 5 and early.director.world.cash() == partial_cash - 5, "Partial real rent payment records exactly five and leaves a balance")
	var after_partial := _encoded(_snapshot(early))
	var partial_retry: Dictionary = early.director.town_action("pay_bills", {"bill_id": rent_id, "amount": 5, "request_id": "partial-rent"})
	_check(partial_retry == partial and _encoded(_snapshot(early)) == after_partial, "Retry of a partial-payment receipt changes no game state")
	var partial_conflict: Dictionary = early.director.town_action("pay_bills", {"bill_id": rent_id, "amount": 6, "request_id": "partial-rent"})
	_check(partial_conflict.get("error") == "request_conflict" and _encoded(_snapshot(early)) == after_partial, "Different amount cannot reuse a partial-payment request identity")
	_check(early.all_errors().is_empty() and early.director.world.ledger.check_invariants().is_empty(), "Early gift and partial rent preserve real ledger invariants")
	await early.dispose()
	# Use the canonical item/pawn APIs to fixture a short two-original contract.
	# Actual TownSim sleeps expire it; no contract flags or ownership are forged.
	var compound = Driver.new(self, "town_fair", 196)
	compound.begin_day(1)
	var first: String = compound.director.new_item("hairpin", "zhouma", "counter")
	var second: String = compound.director.new_item("coin", "zhouma", "counter")
	var tid: String = compound.director.world.ledger.open_pawn("zhouma", [first, second], 20, 1, 1, "两件原物", false)
	_check(tid != "", "Two-original edge uses a real funded pawn contract")
	var sale: Dictionary = compound.director.town_action("risk_sell", {"iid": first, "request_id": "compound-one-original"})
	_check(sale.get("ok", false) and sale.get("risky", false), "One original is actually sold while its contract obligation survives")
	compound.director.town_finish_day()
	for day in range(2, 9):
		compound.director.town_start_day()
		compound.director.town_finish_day()
	var contract: Dictionary = compound.director.world.ledger.contracts[tid]
	_check(contract["status"] == "forfeited" and contract.get("restitution_due", false) and compound.director.world.ledger.items[second]["location"] == "stock", "Actual expiry leaves one sold original and one held in forfeited stock with restitution due")
	compound.director.world.ledger.transfer("player", "市场", compound.director.world.cash(), "验收：暂缺买回款")
	var insufficient := JSON.stringify(compound.director.world.ledger.to_dict(), "", true, true)
	var denied: Dictionary = compound.director.town_action("redeem", {"tid": tid, "mode": "buyback"})
	_check(not denied.get("ok", false) and JSON.stringify(compound.director.world.ledger.to_dict(), "", true, true) == insufficient, "Insufficient buyback cash rejects without changing any money, item or contract field")
	compound.director.world.ledger.transfer("市场", "player", 500, "验收：备齐买回款")
	var returned: Dictionary = compound.director.town_action("redeem", {"tid": tid, "mode": "buyback"})
	_check(returned.get("ok", false) and int(returned.get("buyback", 0)) > 0, "Sufficient cash buys the sold original back and redeems the compound contract")
	for iid in [first, second]:
		var item: Dictionary = compound.director.world.ledger.items[iid]
		_check(item["location"] == "npc:zhouma" and item["owner"] == "zhouma" and item["pledged_to"] == "", "Each exact original is returned to its borrower without a remaining pledge: " + str(iid))
	_check(contract["status"] == "redeemed" and not contract.get("restitution_due", true), "Compound restitution is closed only after both originals return")
	_check(compound.director.world.ledger.check_invariants().is_empty(), "Compound forfeit/buyback conserves the actual ledger")
	await compound.dispose()
