# Real Director/TownSim orchestration shared by 14-day, branch and save tests.
extends RefCounted

const Director = preload("res://scripts/core/director.gd")
const Player = preload("res://scripts/tests/town_play_policy.gd")

var tree: SceneTree
var director
var player
var strategy: String
var seed: int
var plan: Dictionary
var errors: Array = []
var generated_sessions: Dictionary = {}
var authored_sessions: Dictionary = {}
var days: Array = []
var actions: Array = []
var hooks_done: Dictionary = {}
var day_visits: Dictionary = {}

func _init(scene_tree: SceneTree, policy: String, world_seed: int, branch: Dictionary = {}) -> void:
	tree = scene_tree
	strategy = policy
	seed = world_seed
	plan = branch.duplicate(true)
	director = Director.new()
	tree.root.add_child(director)
	director.setup_town(seed)
	player = Player.new(director, strategy, seed, plan)

func prologue() -> void:
	await director.run_script("prologue")
	director.town_action("prologue_done")
	_check_ledger("prologue")

func begin_day(expected_day: int) -> void:
	var report: Dictionary = director.town_start_day()
	if int(report.get("day", -1)) != expected_day:
		errors.append("Day %d started as %s" % [expected_day, str(report.get("day"))])
	director.world.town.set_minute(540)
	_run_hooks("start")
	if not plan.get("counter_only", false):
		_supply()
	_check_ledger("day%d morning" % expected_day)

func visits_until(minute: int = 1260) -> void:
	var passes := 0
	while passes < 80:
		passes += 1
		var pending: Array = director.town_visits()
		var ran := false
		for visit in pending:
			if int(visit.get("minute", 540)) > minute: continue
			var id := str(visit["id"])
			if day_visits.has(id): continue
			day_visits[id] = true
			director.world.town.set_minute(maxi(540, int(visit.get("minute", 540))))
			var outcome: Dictionary = await director.run_town_visit(visit)
			if not outcome.get("ok", false) and outcome.get("error", "") != "condition_changed":
				errors.append("Visit %s failed: %s" % [id, str(outcome)])
			var session_id := str(visit.get("session", {}).get("id", "")) if visit.get("session", {}) is Dictionary else ""
			if session_id.begins_with("gen_d"):
				generated_sessions[session_id] = outcome.get("result", "")
			elif session_id != "": authored_sessions[session_id] = outcome.get("result", "")
			_run_hooks(id)
			_run_hooks(session_id)
			_check_ledger("after " + id)
			ran = true
			break # New conditional cards join their real minute window immediately.
		if not ran: break
	if passes == 80: errors.append("Visit queue did not settle")
	director.world.town.set_minute(minute)

func finish_day() -> void:
	var world = director.world
	_run_hooks("before_night")
	if not plan.get("counter_only", false):
		if not plan.get("no_sale", false) and world.day >= 3:
			var shelf: Dictionary = director.town_action("shelf")
			var rows: Array = shelf.get("items", [])
			if not rows.is_empty(): _action("sell", {"iid": rows[0]["iid"]})
		if not plan.get("no_bills", false): _action("pay_bills", {})
	await director.town_night()
	_run_hooks("after_night")
	var summary: Dictionary = director.town_finish_day()
	days.append({"day": world.day, "cash": world.cash(), "summary": summary.duplicate(true), "flags": world.flags.duplicate(true), "unlocked": world.unlocked.duplicate(true), "done_cards": director.vars["town"]["done_cards"].duplicate(true)})
	_check_ledger("day%d finished" % world.day)

func run_days(first: int, last: int) -> void:
	for day in range(first, last + 1):
		begin_day(day)
		await visits_until()
		await finish_day()

func all_errors() -> Array:
	var out: Array = errors.duplicate()
	out.append_array(player.errors)
	return out

func _check_ledger(context: String) -> void:
	var invariants: Array = director.world.ledger.check_invariants()
	if not invariants.is_empty(): errors.append("%s: %s" % [context, str(invariants)])

func _supply() -> void:
	var home: Dictionary = director.town_action("household").get("household", {})
	for key in ["rice", "fuel", "oil"]:
		if int(home.get(key, 0)) < 2 and director.world.cash() >= 30:
			_action("buy_" + key, {"units": 3})
	if int(home.get("illness", 0)) > 0 and int(home.get("medicine", 0)) == 0:
		_action("buy_medicine", {"units": 1})

func _action(act: String, args: Dictionary) -> Dictionary:
	var result: Dictionary = director.town_action(act, args)
	actions.append({"day": director.world.day, "act": act, "args": args.duplicate(true), "result": result.duplicate(true)})
	_check_ledger("action " + act)
	return result

func _run_hooks(trigger: String) -> void:
	var rows: Array = plan.get("actions", [])
	for index in range(rows.size()):
		var hook: Dictionary = rows[index]
		var key := str(index)
		if hooks_done.has(key) or int(hook["day"]) != director.world.day or str(hook.get("trigger", "start")) != trigger:
			continue
		hooks_done[key] = true
		var args: Dictionary = hook.get("args", {}).duplicate(true)
		if hook.has("item_def"):
			args["iid"] = director.world.ledger.find_item(str(hook["item_def"]))
		elif hook.has("shelf_index"):
			var shelf: Array = director.town_action("shelf").get("items", [])
			var at := int(hook["shelf_index"])
			args["iid"] = shelf[at]["iid"] if at >= 0 and at < shelf.size() else ""
		var previous_ledger := JSON.stringify(director.world.ledger.to_dict(), "", true, true)
		var stock_before: int = director.world.ledger.items_at("stock").size()
		var cash_before: int = director.world.cash()
		var result: Dictionary = _action(str(hook["act"]), args)
		if hook.has("expect_stock_delta") and director.world.ledger.items_at("stock").size() - stock_before != int(hook["expect_stock_delta"]):
			errors.append("Plan action %d incorrect stock delta" % index)
		if hook.get("expect_cash_matches_price", false) and director.world.cash() - cash_before != int(result.get("price", 0)) - int(result.get("fee", 0)):
			errors.append("Plan action %d does not match actual sale price/fee" % index)
		if hook.get("expect_ledger_unchanged", false) and previous_ledger != JSON.stringify(director.world.ledger.to_dict(), "", true, true):
			errors.append("Plan action %d changed ledger despite rejection/replay" % index)
		for field in hook.get("expect", {}):
			if result.get(field) != hook["expect"][field]:
				errors.append("Plan %s action %d %s expected %s=%s, got %s" % [str(plan.get("id", "")), index, hook["act"], field, str(hook["expect"][field]), str(result)])

func dispose() -> void:
	if director != null and is_instance_valid(director):
		if player != null and director.beat.is_connected(player._on_beat): director.beat.disconnect(player._on_beat)
		player.director = null
		director.queue_free()
	player = null
	director = null
	await tree.process_frame
	await tree.process_frame
