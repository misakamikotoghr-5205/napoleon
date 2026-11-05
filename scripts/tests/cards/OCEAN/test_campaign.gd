# Real campaign data, command-driven routes, persistence and legacy compatibility.
# Ending routes never edit state: every flag/resource is earned through commands.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const SUCCESS_ROUTE := [
	["prologue", "secure_passage"], ["scene01", "seal_evidence"],
	["scene02", "expose_sabre"], ["scene03", "audit_accounts"],
	["scene04", "prepare_escape"], ["scene05", "redeem_emperor"],
	["scene06", "establish_rations"], ["scene07", "expose_viper"],
	["scene08", "prepare_operation"], ["scene09", "capture_viper"],
	["scene10", "audit_alliance"], ["scene11", "expose_vigo"],
	["scene12", "cut_orichalcum"], ["finale", "close_ledger"],
]
const FALLBACK_CHOICES := [
	"buy_passage", "aid_longwood", "decline_sabre", "buy_supplies", "reserve_escape",
	"emergency_escape", "ration_cautiously", "secure_hostage", "prepare_withdrawal",
	"rescue_only", "accept_custody", "quarantine_vigo", "hold_orichalcum", "close_without_review",
]

## 本场的仗了结之后剧情才能往下走：最省事的了结是空名单出征、立刻撤出、结算（不花钱、不伤人、没有奖赏）
const SKIP_BATTLE := [
	["campaign.battle_prepare", {}],
	["campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false}],
	["campaign.battle_cmd", {"cmd": "retreat", "args": {}}],
	["campaign.battle_finish", {}],
]

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_campaign")
	CardSave.set_root(t.user_dir())
	_test_definition()
	_test_rejections()
	_test_daily_signs()
	_test_demands()
	_test_side_actions()
	_test_restore_validation()
	_test_routes()
	_test_engine()
	_test_run_context()
	_test_save_isolation()
	_test_rejected_adapter_commands()
	_test_roguelike_coins_and_props()
	_test_inter_campaign_modes()
	_test_companions_bonds_and_battle_grid()
	print("OCEAN campaign assertions: %d" % t.checks)
	t.finish()


func _new(stage: int = 0, seed_value: int = 1815) -> RefCounted:
	var campaign := Campaign.new()
	var result: Dictionary = campaign.new_game({"stage": stage, "seed": seed_value})
	t.ok(result.get("ok", false), "start real campaign stage %d: %s" % [stage, result])
	return campaign


func _send(campaign: RefCounted, cmd: String, args: Dictionary = {}) -> bool:
	var result: Dictionary = campaign.send(StringName(cmd), args)
	t.ok(result.get("ok", false), "%s %s at %s: %s" % [cmd, args, campaign.scene().get("id", ""), result])
	return result.get("ok", false)


func _day(campaign: RefCounted) -> void:
	for _step in range(4):
		if campaign.state.get("phase") in ["day", "game_over"]:
			return
		if not _send(campaign, "campaign.wait"):
			return
	t.eq(campaign.state.get("phase"), "day", "reach active day")


func _reject(campaign: RefCounted, cmd: String, args: Dictionary, error: String, label: String) -> void:
	var before: Dictionary = campaign.snapshot()
	var result: Dictionary = campaign.send(StringName(cmd), args)
	t.eq(result.get("ok"), false, label + " rejected")
	t.eq(result.get("err"), error, label + " error")
	t.eq(campaign.snapshot(), before, label + " leaves complete state unchanged")


func _test_definition() -> void:
	var campaign := _new()
	var data: Dictionary = campaign.definition
	t.eq(data.get("id"), "ocean_pawn", "campaign identity")
	t.eq(data.get("scenes", []).size(), 14, "prologue, twelve numbered scenes and finale")
	t.eq(data.get("chapters", []).size(), 4, "prologue plus trilogy")
	var ids: Array = []
	var kinds: Array = []
	for chapter in data.get("chapters", []):
		ids.append(chapter.get("id"))
	t.eq(ids, ["prologue", "st_helena", "new_elba", "nautilus"], "chronological chapters")
	for scene in data.get("scenes", []):
		t.ok(not str(scene.get("title", "")).is_empty(), str(scene.get("id")) + " has narrative title")
		t.ok(not scene.get("choices", []).is_empty(), str(scene.get("id")) + " has playable choices")
		for appraisal in scene.get("appraisals", []):
			if appraisal.get("kind") not in kinds:
				kinds.append(appraisal.get("kind"))
			t.ok(not str(appraisal.get("observation", "")).is_empty(), "appraisal reveals evidence")
	for kind in ["spot", "weigh", "ring", "decode"]:
		t.ok(kind in kinds, "four-dimensional appraisal: " + kind)
	var exported: Dictionary = campaign.snapshot()
	exported["metrics"]["treasury"] = 0
	t.ok(campaign.state["metrics"]["treasury"] > 0, "snapshot cannot mutate model")
	var copied_scene: Dictionary = campaign.scene()
	copied_scene["choices"].clear()
	t.ok(not campaign.scene()["choices"].is_empty(), "scene cannot mutate definition")


func _test_rejections() -> void:
	var campaign := _new()
	var first: Dictionary = campaign.scene()
	var appraisal_id: String = first["appraisals"][0]["id"]
	_reject(campaign, "campaign.appraise", {"id": appraisal_id}, "bad_phase", "appraisal before day")
	_reject(campaign, "campaign.nonsense", {}, "bad_args", "unknown command")
	_day(campaign)
	_reject(campaign, "campaign.appraise", {"id": "missing"}, "bad_args", "unknown appraisal")
	_reject(campaign, "campaign.appraise", {"id": 1}, "bad_args", "wrong appraisal argument type")
	_reject(campaign, "campaign.wait", {"unexpected": true}, "bad_args", "extra arguments")
	_reject(campaign, "campaign.sign", {"sign": "purple"}, "bad_args", "unknown sign")
	_reject(campaign, "campaign.choose", {"choice": "missing"}, "bad_args", "unknown choice")
	var gated := ""
	for choice in first["choices"]:
		if not choice.get("requires_clues", []).is_empty():
			gated = choice["id"]
			break
	t.ok(gated != "", "prologue has evidence-gated decision")
	if gated != "":
		_reject(campaign, "campaign.choose", {"choice": gated}, "missing_clue", "unearned narrative outcome")
	_send(campaign, "campaign.appraise", {"id": appraisal_id})
	_reject(campaign, "campaign.appraise", {"id": appraisal_id}, "already_used", "duplicate appraisal")
	_send(campaign, "campaign.trade", {"kind": "fair"})
	_reject(campaign, "campaign.trade", {"kind": "counterfeit"}, "already_used", "duplicate trade")
	_send(campaign, "campaign.visit", {"place": "backdoor"})
	_reject(campaign, "campaign.visit", {"place": "backdoor"}, "already_used", "duplicate street visit")
	_reject(campaign, "campaign.build", {}, "bad_phase", "construction before island chapter")
	_reject(campaign, "campaign.explore", {}, "bad_phase", "exploration before submarine chapter")
	var before: String = campaign.hash()
	campaign.available_choices()
	campaign.chapter()
	campaign.scene()
	t.eq(campaign.hash(), before, "runtime queries are read only")


func _test_daily_signs() -> void:
	var campaign := _new()
	_day(campaign)
	var start: Dictionary = campaign.state["metrics"].duplicate(true)
	_send(campaign, "campaign.sign", {"sign": "red"})
	_send(campaign, "campaign.sign", {"sign": "red"})
	t.eq(campaign.state["metrics"], start, "hanging sign is not a daily settlement")
	_send(campaign, "campaign.wait")
	t.eq(campaign.state["day"], 2, "one settlement advances one day")
	t.eq(campaign.state["metrics"]["heat"], start["heat"] + 15, "red sign adds exactly fifteen alert")
	_day(campaign)
	t.eq(campaign.state["metrics"]["heat"], start["heat"] + 15, "phase transitions do not settle again")
	_send(campaign, "campaign.sign", {"sign": "black"})
	_send(campaign, "campaign.sign", {"sign": "black"})
	_send(campaign, "campaign.wait")
	t.eq(campaign.state["metrics"]["treasury"], start["treasury"] - 10, "black sign costs exactly ten shillings")
	t.eq(campaign.state["metrics"]["heat"], start["heat"] + 5, "black sign reduces alert by exactly ten")
	_day(campaign)
	_send(campaign, "campaign.sign", {"sign": "white"})
	var white: Dictionary = campaign.state["metrics"].duplicate(true)
	_send(campaign, "campaign.wait")
	t.eq(campaign.state["metrics"], white, "white sign preserves all resources")
	var sign_days: Array = []
	for row in campaign.state["ledger"]:
		if row["type"] == "daily_sign":
			sign_days.append(row["day"])
	t.eq(sign_days, [1, 2, 3], "one sign ledger entry per completed day")


func _demand(campaign: RefCounted, id: String) -> Dictionary:
	for row in campaign.state["demands"]:
		if row["id"] == id:
			return row
	return {}


func _test_demands() -> void:
	var campaign := _new(1)
	_day(campaign)
	t.eq(_demand(campaign, "medicine").get("due_day"), 6, "winter medicine has five full days")
	t.eq(_demand(campaign, "bond").get("cost"), 1000, "fifty pound bond is one thousand shillings")
	_reject(campaign, "campaign.demand", {"id": "medicine", "action": "fulfill"}, "missing_item", "medicine requires owned token")
	_send(campaign, "campaign.visit", {"place": "town"})
	t.ok("medicine" in campaign.state["inventory"], "town visit obtains medicine")
	_send(campaign, "campaign.demand", {"id": "medicine", "action": "fulfill"})
	t.ok("medicine" not in campaign.state["inventory"], "medicine delivery consumes one token")
	t.eq(_demand(campaign, "medicine").get("status"), "fulfilled", "medicine delivery recorded")
	_reject(campaign, "campaign.demand", {"id": "medicine", "action": "fulfill"}, "already_used", "duplicate medicine delivery")
	var funds: int = campaign.state["metrics"]["treasury"]
	_send(campaign, "campaign.demand", {"id": "bond", "action": "fulfill"})
	t.eq(campaign.state["metrics"]["treasury"], funds - 1000, "bond charged exactly once")
	t.eq(_demand(campaign, "bond").get("status"), "fulfilled", "payment and status committed together")
	_reject(campaign, "campaign.demand", {"id": "bond", "action": "fulfill"}, "already_used", "duplicate bond payment")
	# A balance fixture tests the atomic payment boundary, never an ending route.
	var poor := _new(1)
	_day(poor)
	var balance_fixture: Dictionary = poor.snapshot()
	balance_fixture["metrics"]["treasury"] = 999
	t.ok(poor.restore(balance_fixture).get("ok", false), "valid low-balance save fixture")
	_reject(poor, "campaign.demand", {"id": "bond", "action": "fulfill"}, "insufficient_funds", "unaffordable bond is atomic")
	var expired := _new(1)
	_day(expired)
	var initial: Dictionary = expired.state["metrics"].duplicate(true)
	for day_index in range(5):
		_send(expired, "campaign.wait")
		for id in ["medicine", "bond"]:
			t.eq(_demand(expired, id).get("status"), "pending" if day_index < 4 else "expired", "%s deadline after %d days" % [id, day_index + 1])
		_day(expired)
	t.eq(expired.state["metrics"]["vitality"], initial["vitality"] - 25, "missed medicine penalty once")
	t.eq(expired.state["metrics"]["heat"], initial["heat"] + 25, "missed bond penalty once")
	var after: Dictionary = expired.state["metrics"].duplicate(true)
	_send(expired, "campaign.wait")
	t.eq(expired.state["metrics"], after, "expired demands do not charge again")
	_day(expired)
	_reject(expired, "campaign.demand", {"id": "bond", "action": "fulfill"}, "already_used", "expired demand cannot be paid")


func _test_restore_validation() -> void:
	var campaign := _new()
	_day(campaign)
	_send(campaign, "campaign.appraise", {"id": campaign.scene()["appraisals"][0]["id"]})
	var original: Dictionary = campaign.snapshot()
	var restored := Campaign.new()
	t.ok(restored.load_definition().get("ok", false), "fresh runtime loads definition")
	t.ok(restored.restore(original).get("ok", false), "fresh runtime restores mid-story")
	t.eq(restored.hash(), campaign.hash(), "runtime save hash exact")
	var changes: Array = [
		["v", 999], ["campaign", "legacy"], ["definition_hash", "wrong"],
		["scene_index", 999], ["phase", "bogus"], ["day", -1],
		["metrics", {}], ["clues", {"missing_scene": []}], ["inventory", "broken"],
		["demands", [{"id": "bond", "cost": 0}]], ["ending", "alliance"],
	]
	for change in changes:
		var corrupt: Dictionary = original.duplicate(true)
		corrupt[change[0]] = change[1]
		t.eq(campaign.restore(corrupt).get("ok"), false, "reject corrupt runtime field " + change[0])
		t.eq(campaign.snapshot(), original, "failed restore preserves state: " + change[0])
	var fractional: Dictionary = original.duplicate(true)
	fractional["metrics"]["treasury"] = 1.5
	t.eq(campaign.restore(fractional).get("ok"), false, "fractional resource save rejected")
	t.eq(campaign.snapshot(), original, "fractional restore atomic")


func _test_side_actions() -> void:
	var island := _new(2)
	_day(island)
	var money: int = island.state["metrics"]["treasury"]
	_send(island, "campaign.build")
	t.eq(island.state["metrics"]["construction"], 25, "construction invests in island progress")
	t.eq(island.state["metrics"]["treasury"], money - 200, "construction debits island account")
	_reject(island, "campaign.build", {}, "already_used", "duplicate construction")
	var submarine := _new(3)
	_day(submarine)
	money = submarine.state["metrics"]["treasury"]
	_send(submarine, "campaign.explore")
	t.eq(submarine.state["metrics"]["exploration"], 25, "exploration advances deep-sea map")
	t.eq(submarine.state["metrics"]["treasury"], money - 200, "exploration debits deep-sea account")
	_reject(submarine, "campaign.explore", {}, "already_used", "duplicate exploration")
	money = submarine.state["metrics"]["treasury"]
	_send(submarine, "campaign.fund", {"support": true})
	t.eq(submarine.state["metrics"]["treasury"], money - 1000, "revolution funding costs one thousand")
	_reject(submarine, "campaign.fund", {"support": true}, "already_used", "duplicate revolution funding")
	_reject(submarine, "campaign.fund", {"support": false}, "already_used", "funding cannot be reversed")


func _test_routes() -> void:
	for ending in ["alliance", "ghost", "dark", "tragedy", "bittersweet"]:
		var result := _route(ending)
		var campaign: RefCounted = result["campaign"]
		t.eq(campaign.state["phase"], "game_over", ending + " reaches terminal state")
		t.eq(campaign.state["ending"], ending, ending + " earned by legitimate gameplay")
		var expected: Array = SUCCESS_ROUTE.map(func(row: Array) -> String: return row[0])
		if ending == "tragedy":
			expected = expected.slice(0, 12)
		t.eq(result["scenes"], expected, ending + " visits expected narrative scenes in order")
		t.eq(result["chapters"], ["prologue", "st_helena", "new_elba", "nautilus"], ending + " traverses full trilogy")
		t.eq(campaign.state["chapter_balances"].size(), 3, ending + " retains separate balances for departed chapters")
		if ending == "ghost":
			t.eq(campaign.state["metrics"]["construction"], 100, "ghost requires completed island")
			t.eq(campaign.state["metrics"]["exploration"], 100, "ghost requires completed exploration")
			t.ok(campaign.state["flags"].get("refused_funding", false), "ghost refuses revolution funding")
		if ending == "dark":
			t.ok(campaign.state["metrics"]["treasury"] > 20000, "dark ends wealthy")
			t.ok(campaign.state["metrics"]["morale"] < 30, "dark loses allied trust")
			for flag in ["theft_treasure", "counterfeit_trade"]:
				t.ok(campaign.state["flags"].get(flag, false), "dark consequence tracks " + flag)
		if ending == "tragedy":
			t.eq(campaign.state["metrics"]["heat"], 100, "unidentified Vigo decoy triggers blockade")
		_reject(campaign, "campaign.wait", {}, "bad_phase", "terminal " + ending + " is immutable")
		# Replay the actual accepted command stream and compare every intermediate hash.
		var replay := _new()
		for i in result["commands"].size():
			var command: Array = result["commands"][i]
			_send(replay, command[0], command[1])
			t.eq(replay.hash(), result["hashes"][i], "%s replay step %d" % [ending, i])
		t.eq(replay.snapshot(), campaign.snapshot(), ending + " deterministic final state")


func _route(ending: String) -> Dictionary:
	var result := {"campaign": _new(), "commands": [], "hashes": [], "scenes": [], "chapters": []}
	var campaign: RefCounted = result["campaign"]
	for step in SUCCESS_ROUTE:
		for _phase in range(4):
			if campaign.state["phase"] in ["day", "game_over"]:
				break
			_route_send(result, "campaign.wait")
		if campaign.state["phase"] == "game_over":
			break
		var scene: Dictionary = campaign.scene()
		t.eq(scene["id"], step[0], ending + " scheduled scene")
		result["scenes"].append(scene["id"])
		if scene["chapter"] not in result["chapters"]:
			result["chapters"].append(scene["chapter"])
			if scene["chapter"] != "prologue":
				t.eq(campaign.state["metrics"]["treasury"], campaign.chapter()["treasury_start"], "new currency opens independent chapter account")
		var waiting: Array = campaign.available_choices().filter(
			func(c: Dictionary) -> bool: return bool(c.get("advance", true)) and str(c["reason"]) == "battle_pending")
		t.ok(not waiting.is_empty(), ending + " story waits for the " + scene["id"] + " battle")
		for command in SKIP_BATTLE:
			_route_send(result, command[0], command[1])
		if ending != "bittersweet":
			for appraisal in scene["appraisals"]:
				_route_send(result, "campaign.appraise", {"id": appraisal["id"]})
		if scene["id"] == "scene01":
			_route_send(result, "campaign.visit", {"place": "town"})
			_route_send(result, "campaign.demand", {"id": "medicine", "action": "fulfill"})
			_route_send(result, "campaign.demand", {"id": "bond", "action": "fulfill"})
		if ending == "dark" and scene["id"] in ["scene10", "scene11"]:
			var side := "theft_treasure" if scene["id"] == "scene10" else "counterfeit_trade"
			_route_send(result, "campaign.choose", {"choice": side})
			_reject(campaign, "campaign.choose", {"choice": side}, "already_used", "one-use narrative side choice " + side)
		if ending == "ghost" and scene["id"] == "scene12":
			_route_send(result, "campaign.choose", {"choice": "choose_autonomy"})
			_reject(campaign, "campaign.fund", {"support": true}, "already_used", "narrative autonomy blocks later funding")
			_reject(campaign, "campaign.choose", {"choice": "fund_revolution"}, "already_used", "narrative autonomy cannot be reversed")
		if ending == "alliance" and scene["id"] == "scene12":
			_route_send(result, "campaign.fund", {"support": true})
			_reject(campaign, "campaign.choose", {"choice": "choose_autonomy"}, "already_used", "direct funding blocks narrative reversal")
			_reject(campaign, "campaign.choose", {"choice": "fund_revolution"}, "already_used", "direct funding blocks narrative duplicate debit")
		var choice: String = "accept_vigo_decoy" if ending == "tragedy" and scene["id"] == "scene11" else step[1]
		if ending == "bittersweet":
			choice = FALLBACK_CHOICES[result["scenes"].size() - 1]
		_route_send(result, "campaign.choose", {"choice": choice})
	return result


func _route_send(route: Dictionary, command: String, args: Dictionary = {}) -> void:
	if _send(route["campaign"], command, args):
		route["commands"].append([command, args.duplicate(true)])
		route["hashes"].append(route["campaign"].hash())


func _test_engine() -> void:
	var previous_mode := OS.get_environment("DEHOUDANG_CAMPAIGN")
	OS.set_environment("DEHOUDANG_CAMPAIGN", "")
	var bus := CardEventBus.new()
	var spy = t.spy(bus)
	var engine := CardEngine.new(bus)
	var options := {"campaign": "ocean_pawn", "seed": 1815, "save_dir": t.user_dir() + "/ocean"}
	t.ok(engine.new_game(options).get("ok", false), "explicit CardEngine ocean campaign remains available")
	t.eq(engine.query(&"campaign").get("scene_id"), "prologue", "default scene available through old engine")
	var date: Dictionary = engine.view().get("date", {})
	t.eq([date.get("y"), date.get("m"), date.get("d")], [1815, 8, 4], "default date is Napoleon prologue")
	t.ok(engine.send(&"month.begin").get("ok", false), "legacy month command opens chapter")
	t.ok(engine.send(&"day.begin").get("ok", false), "legacy day command opens story")
	var story := "story:prologue"
	var card: Dictionary = engine.query(&"card", {"uid": story})
	t.ok(not card.is_empty(), "old card query exposes narrative card")
	t.ok(engine.send(&"card.choose", {"uid": story, "choice": "action:appraise:watch_mark"}).get("ok", false), "old card choose dispatches appraisal")
	card = engine.query(&"card", {"uid": story})
	t.ok(not card.get("observations", []).is_empty(), "revealed evidence visible through old card shape")
	for id in ["watch_weight", "watch_ring", "faria_letter"]:
		t.ok(engine.send(&"card.choose", {"uid": story, "choice": "action:appraise:" + id}).get("ok", false), "old card appraisal " + id)
	t.eq(engine.send(&"card.choose", {"uid": story, "choice": "action:choose:secure_passage"}).get("err"), "choice_disabled", "story choice waits for the scene battle")
	t.eq(engine.query(&"card", {"uid": "battle"}).get("panel"), "battle_lineup", "battle card opens the lineup sheet")
	for command in SKIP_BATTLE:
		t.ok(engine.send(StringName(command[0]), command[1]).get("ok", false), "engine resolves prologue battle: " + command[0])
	t.eq(engine.query(&"card", {"uid": "battle"}).get("panel"), "battle_result", "resolved battle card opens the result")
	t.ok(engine.send(&"card.choose", {"uid": story, "choice": "action:choose:secure_passage"}).get("ok", false), "old card choice advances narrative")
	t.eq(engine.view()["phase"], "year_jump", "prologue choice exposes chapter transition")
	for command in [&"year.next", &"month.begin", &"day.begin"]:
		t.ok(engine.send(command).get("ok", false), "legacy phase command " + str(command))
	t.eq(engine.query(&"campaign").get("scene_id"), "scene01", "narrative now in St Helena")
	t.ok(engine.send(&"campaign.appraise", {"id": "linen_marks"}).get("ok", false), "save mid appraisal")
	_assert_public(engine)
	for row in spy.log:
		t.no_leaks(row.slice(1), "campaign event " + str(row[0]))
	var path: String = t.user_dir() + "/ocean/mid_story.json"
	var before: String = engine.state_hash()
	var view_before: Dictionary = engine.view()
	var history: Array = engine.command_log()
	t.ok(engine.save_game(path).get("ok", false), "save campaign through CardEngine")
	t.eq(engine.state_hash(), before, "saving does not mutate game")
	t.ok(not FileAccess.file_exists(path + ".tmp"), "atomic save leaves no temporary file")
	var loaded := CardEngine.new()
	t.ok(loaded.load_game(path).get("ok", false), "new engine recognizes campaign save")
	t.eq(loaded.state_hash(), before, "campaign load exact state hash")
	t.eq(loaded.view(), view_before, "campaign load restores public view")
	t.eq(loaded.command_log(), history, "campaign load restores command history")
	for command in [["campaign.appraise", {"id": "linen_register"}], ["campaign.appraise", {"id": "linen_report"}]] + SKIP_BATTLE + [["campaign.choose", {"choice": "seal_evidence"}]]:
		t.ok(engine.send(StringName(command[0]), command[1]).get("ok", false), "original continuation " + command[0])
		t.ok(loaded.send(StringName(command[0]), command[1]).get("ok", false), "loaded continuation " + command[0])
		t.eq(loaded.state_hash(), engine.state_hash(), "mid-story load continuation deterministic")
	_test_bad_saves(loaded, path)
	var legacy := CardEngine.new()
	t.ok(legacy.new_game({"campaign": "legacy", "only_examples": true, "seed": 7, "save_dir": t.user_dir() + "/legacy"}).get("ok", false), "explicit legacy fixture starts")
	t.ok(not legacy.ctx.state.data.has("ocean"), "legacy campaign remains independent")
	loaded.view()
	t.eq(CardText.person_name("ruhua"), "埃德蒙·德·维尔福", "ocean engine binds protagonist text")
	CardText.setup(legacy.ctx.db)
	t.ok(CardText.person_name("ruhua") != "埃德蒙·德·维尔福", "legacy binding replaces global protagonist text")
	loaded.view()
	t.eq(CardText.person_name("ruhua"), "埃德蒙·德·维尔福", "prior ocean engine view restores its text after legacy binding")
	var legacy_path: String = t.user_dir() + "/legacy/save.json"
	t.ok(legacy.save_game(legacy_path).get("ok", false), "legacy envelope still writes")
	var legacy_reader := CardEngine.new()
	t.ok(legacy_reader.load_game(legacy_path).get("ok", false), "new engine still loads legacy save")
	t.ok(not legacy_reader.ctx.state.data.has("ocean"), "legacy load does not become ocean")
	t.ok(loaded.load_game(legacy_path).get("ok", false), "ocean engine can explicitly load legacy file")
	t.ok(not loaded.ctx.state.data.has("ocean"), "loading legacy switches active runtime")
	t.ok(loaded.load_game(path).get("ok", false), "legacy runtime can explicitly reload ocean")
	t.eq(loaded.query(&"campaign").get("scene_id"), "scene01", "cross-campaign return restores saved scene")
	OS.set_environment("DEHOUDANG_CAMPAIGN", "legacy")
	var overridden := CardEngine.new()
	t.ok(overridden.new_game({"campaign": "ocean_pawn", "save_dir": t.user_dir() + "/override"}).get("ok", false), "explicit ocean overrides legacy environment")
	t.eq(overridden.query(&"campaign").get("chapter_id"), "prologue", "explicit campaign takes precedence")
	OS.set_environment("DEHOUDANG_CAMPAIGN", previous_mode)
	CardSave.set_root(t.user_dir())
	bus.free()


func _assert_public(engine: CardEngine) -> void:
	var before := engine.state_hash()
	var history := engine.command_log()
	t.no_leaks(engine.view(), "campaign view")
	for query in [&"campaign", &"stock", &"tickets", &"estates", &"settle_report", &"month_report", &"year_report", &"stage", &"day.end_preview"]:
		var result: Dictionary = engine.query(query)
		t.no_leaks(result, "campaign query " + str(query))
	var scene_id := str(engine.query(&"campaign").get("scene_id", ""))
	for uid in ["story:" + scene_id, "signage", "town", "backdoor", "resources", "battle", "march", "calendar", "squad", "status", "demand:medicine", "demand:bond"]:
		t.no_leaks(engine.query(&"card", {"uid": uid}), "card query " + uid)
	var detached := engine.query(&"campaign")
	detached["choices"].clear()
	var detached_view := engine.view()
	detached_view["hand"].clear()
	t.eq(engine.state_hash(), before, "queries and returned dictionary edits do not mutate state")
	t.eq(engine.command_log(), history, "queries do not enter replay history")
	t.ok(not engine.query(&"campaign").get("choices", []).is_empty(), "query result detached from model")
	t.ok(not engine.view().get("hand", []).is_empty(), "view result detached from model")


func _test_run_context() -> void:
	var engine := CardEngine.new()
	var run := {"no": 3, "opening": "og.default", "known": ["ocean.person.napoleon"]}
	var options := {"campaign": "ocean_pawn", "seed": 1821, "run": run,
		"save_dir": t.user_dir() + "/run_context"}
	t.ok(engine.new_game(options).get("ok", false), "0.9 run context starts a campaign")
	t.eq(engine.view().get("run"), {"no": 3, "opening": "og.default"}, "0.9 view retains the current ledger identity")
	t.eq(engine.ctx.state.data.get("run", {}).get("known"), ["ocean.person.napoleon"], "earlier ledger knowledge reaches the new campaign")
	for invalid in ["broken", {"no": 0, "opening": "og.default"},
		{"no": 3, "opening": "missing.opening"}, {"no": 3, "opening": "og.default", "known": 42}]:
		var rejected := options.duplicate(true)
		rejected["run"] = invalid
		_assert_engine_reject(engine, &"game.new", rejected, "malformed run rejected: " + str(invalid))
	var replay := CardEngine.new()
	var replay_options := options.duplicate(true)
	replay_options["save_dir"] = t.user_dir() + "/run_replay"
	t.ok(replay.new_game(replay_options).get("ok", false), "0.9 run replay starts")
	t.eq(replay.state_hash(), engine.state_hash(), "run start hash depends on run identity and seed, not directory")
	for command in [[&"month.begin", {}], [&"day.begin", {}], [&"campaign.appraise", {"id": "watch_mark"}]]:
		t.ok(engine.send(command[0], command[1]).get("ok", false), "original run command " + str(command[0]))
		t.ok(replay.send(command[0], command[1]).get("ok", false), "replayed run command " + str(command[0]))
		t.eq(replay.state_hash(), engine.state_hash(), "run replay stays deterministic after " + str(command[0]))
	var before := engine.state_hash()
	var history := engine.command_log()
	var harvest := engine.query(&"legacy.harvest", {})
	t.ok(harvest.get("ok", false), "0.9 profile can harvest campaign progress")
	t.eq(harvest.get("no"), 3, "harvest belongs to this ledger")
	t.eq(harvest.get("era"), engine.query(&"campaign").get("chapter_id"), "harvest uses the campaign chapter")
	t.no_leaks(harvest, "campaign harvest has no hidden engine keys")
	var closed := engine.query(&"legacy.harvest", {"close": "abandoned"})
	t.ok(closed.get("ok", false), "profile can request an abandonment summary")
	t.ok(not str(closed.get("chronicle", {}).get("key", "")).is_empty(), "abandonment has a shelf text key")
	t.no_leaks(closed, "campaign chronicle has no hidden engine keys")
	var ink := engine.query(&"legacy.old_ink", {})
	t.no_leaks(ink, "campaign old ink has no hidden engine keys")
	harvest["frags"] = ["mutated"]
	closed["chronicle"] = {"key": "mutated"}
	t.eq(engine.state_hash(), before, "harvest and edited query results never mutate campaign state")
	t.eq(engine.command_log(), history, "profile queries do not enter replay history")
	var path: String = t.user_dir() + "/run_context/mid_run.json"
	t.ok(engine.save_game(path).get("ok", false), "save the current ledger")
	var loaded := CardEngine.new()
	t.ok(loaded.load_game(path).get("ok", false), "load campaign with 0.9 run context")
	t.eq(loaded.state_hash(), before, "run context survives save/load without changing the hash")
	t.eq(loaded.ctx.state.data.get("run"), engine.ctx.state.data.get("run"), "saved ledger number/opening/old ink are restored")
	t.eq(loaded.query(&"legacy.harvest", {}), engine.query(&"legacy.harvest", {}), "restored ledger gives the same profile harvest")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for invalid in ["broken", {"_v": 1, "no": -3, "opening": "og.default", "known": []},
		{"_v": 1, "no": 3, "opening": "missing.opening", "known": []},
		{"_v": 1, "no": 3, "opening": "og.default", "known": 42},
		{"_v": 999, "no": 3, "opening": "og.default", "known": []}]:
		var corrupt := valid.duplicate(true)
		corrupt["state"]["run"] = invalid
		var corrupt_path: String = t.user_dir() + "/bad_run.json"
		_write(corrupt_path, corrupt)
		_assert_failed_load(loaded, corrupt_path, "corrupt run " + str(invalid))
	CardSave.set_root(t.user_dir())


func _test_save_isolation() -> void:
	var first := CardEngine.new()
	var second := CardEngine.new()
	var first_dir: String = t.user_dir() + "/isolation_a"
	var second_dir: String = t.user_dir() + "/isolation_b"
	t.ok(first.new_game({"campaign": "ocean_pawn", "seed": 11, "save_dir": first_dir}).get("ok", false), "first isolated engine starts")
	var first_start := first.state_hash()
	t.ok(second.new_game({"campaign": "ocean_pawn", "seed": 22, "save_dir": second_dir}).get("ok", false), "second isolated engine starts")
	var second_save := FileAccess.get_file_as_string(second_dir + "/suspend.json")
	var second_state := second.state_hash()
	for command in [["month.begin", {}], ["day.begin", {}], ["campaign.appraise", {"id": "watch_mark"}]]:
		t.ok(first.send(StringName(command[0]), command[1]).get("ok", false), "first engine continues after second: " + command[0])
	t.eq(FileAccess.get_file_as_string(second_dir + "/suspend.json"), second_save, "first engine autosave cannot overwrite second save")
	t.eq(second.state_hash(), second_state, "first engine actions cannot alter second state")
	var first_saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(first_dir + "/suspend.json"))
	t.eq(first_saved.get("state", {}).get("ocean", {}).get("clues", {}).get("prologue"), ["watch_mark"], "first autosave updated its own appraisal")
	var first_current := first.state_hash()
	t.ok(first.send(&"game.save").get("ok", false), "default manual save uses first engine directory")
	t.eq(FileAccess.get_file_as_string(second_dir + "/suspend.json"), second_save, "default manual save cannot overwrite second save")
	t.ok(first.send(&"game.load").get("ok", false), "default load uses first engine directory")
	t.eq(first.state_hash(), first_current, "default load restores first engine progress")
	t.ok(second.load_game(second_dir + "/suspend.json").get("ok", false), "second engine reclaims global save root before first retry")
	t.eq(second.state_hash(), second_state, "second engine reload preserves its own seed")
	t.ok(first.send(&"game.retry_stage").get("ok", false), "stage retry uses first engine directory")
	t.eq(first.state_hash(), first_start, "stage retry restores first engine seed and start")
	t.eq(FileAccess.get_file_as_string(second_dir + "/suspend.json"), second_save, "stage retry cannot overwrite second save")
	CardSave.set_root(t.user_dir())


func _write(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	t.ok(file != null, "open isolated corrupt-save fixture")
	if file != null:
		file.store_string(JSON.stringify(value))
		file.close()


func _test_rejected_adapter_commands() -> void:
	var bus := CardEventBus.new()
	var engine := CardEngine.new(bus)
	t.ok(engine.new_game({"campaign": "ocean_pawn", "stage": 1, "save_dir": t.user_dir() + "/negative_commands"}).get("ok", false), "negative adapter tests start in Saint Helena")
	t.ok(engine.send(&"month.begin").get("ok", false), "negative adapter test opens month")
	t.ok(engine.send(&"day.begin").get("ok", false), "negative adapter test opens day")
	t.ok(engine.has_command(&"campaign.appraise"), "advertises implemented campaign command")
	t.eq(engine.has_command(&"campaign.whatever"), false, "does not advertise unknown campaign command")
	for command in [
		[&"card.choose", {"uid": "story:scene01", "choice": "action:appraise:linen_marks", "extra": true}],
		[&"card.read", {"uid": "status", "extra": true}],
		[&"demand.submit", {"uid": "demand:bond", "extra": true}],
	]:
		_assert_engine_reject(engine, command[0], command[1], str(command[0]) + " rejects extra arguments")
	var spy = t.spy(bus)
	var callback_observations: Array = []
	bus.command_done.connect(func(_cmd: StringName, _args: Dictionary, _ok: bool) -> void:
		callback_observations.append(["command_done", engine.is_busy(), engine.send(&"campaign.wait").get("err")])
	)
	bus.view_changed.connect(func(_topics: PackedStringArray) -> void:
		callback_observations.append(["view_changed", engine.is_busy(), engine.send(&"campaign.wait").get("err")])
	)
	for command in [
		[&"game.load", {"path": t.user_dir() + "/missing_notification_save.json"}],
		[&"game.retry_stage", {"unexpected": true}],
	]:
		spy.clear()
		callback_observations.clear()
		_assert_engine_reject(engine, command[0], command[1], str(command[0]) + " invalid request")
		t.eq(spy.names(), [&"command_done", &"view_changed"], str(command[0]) + " emits exactly failure then view")
		t.eq(spy.log[0].slice(1), [command[0], command[1], false], str(command[0]) + " reports the failed command")
		t.eq(callback_observations, [["command_done", true, "busy"], ["view_changed", true, "busy"]], str(command[0]) + " notifications preserve busy and reject reentry")
		t.eq(engine.is_busy(), false, str(command[0]) + " releases busy after notifications")
	bus.free()


func _assert_engine_reject(engine: CardEngine, command: StringName, args: Dictionary, label: String) -> void:
	var state_before: Dictionary = engine.ctx.state.data.duplicate(true)
	var view_before := engine.view()
	var history := engine.command_log()
	var root_before := CardSave.root()
	var result := engine.send(command, args)
	t.eq(result.get("ok"), false, label)
	t.eq(engine.ctx.state.data, state_before, label + " preserves complete state")
	t.eq(engine.view(), view_before, label + " preserves view")
	t.eq(engine.command_log(), history, label + " preserves history")
	t.eq(CardSave.root(), root_before, label + " preserves save root")


func _test_bad_saves(engine: CardEngine, source: String) -> void:
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var variants: Dictionary = {}
	for label in ["future_envelope", "future_campaign", "wrong_campaign", "wrong_definition", "missing_campaign", "malformed_campaign", "bad_command_log", "bad_guide_tree", "bad_guide_row"]:
		var changed: Dictionary = valid.duplicate(true)
		match label:
			"future_envelope": changed["v"] = 999
			"future_campaign": changed["state"]["ocean"]["v"] = 999
			"wrong_campaign": changed["state"]["ocean"]["campaign"] = "other_story"
			"wrong_definition": changed["state"]["ocean"]["definition_hash"] = "other_data"
			"missing_campaign": changed["state"].erase("ocean")
			"malformed_campaign": changed["state"]["ocean"] = "broken"
			"bad_command_log": changed["cmd_log"] = [["campaign.wait", "broken"]]
			"bad_guide_tree": changed["state"]["ui"] = {"guide": 17}
			"bad_guide_row": changed["state"]["ui"] = {"guide": {"ocean_intro": 17}}
		variants[label] = changed
	var path: String = t.user_dir() + "/bad_save.json"
	for label in variants:
		_write(path, variants[label])
		_assert_failed_load(engine, path, label)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	_assert_failed_load(engine, path, "invalid JSON")
	_assert_failed_load(engine, t.user_dir() + "/missing.json", "missing file")


func _assert_failed_load(engine: CardEngine, path: String, label: String) -> void:
	var before := engine.state_hash()
	var state_before: Dictionary = engine.ctx.state.data.duplicate(true)
	var view_before := engine.view()
	var history := engine.command_log()
	var root_before := CardSave.root()
	t.eq(engine.load_game(path).get("ok"), false, label + " save rejected")
	t.eq(engine.state_hash(), before, label + " load preserves state")
	t.eq(engine.ctx.state.data, state_before, label + " load preserves complete state including UI")
	t.eq(engine.view(), view_before, label + " load preserves view")
	t.eq(engine.command_log(), history, label + " load preserves history")
	t.eq(CardSave.root(), root_before, label + " load preserves save root")


func _test_roguelike_coins_and_props() -> void:
	var campaign := _new(1, 1815)
	_day(campaign)
	var rogue: Dictionary = campaign.state["rogue"]
	t.eq(rogue["coins"], {"gold": 4, "supply": 6, "medal": 2, "intel": 2}, "four functional coins initialized")
	t.ok("prop_loaded_dice" in rogue["props"], "starts with loaded dice prop")
	t.ok("prop_field_ration" in rogue["props"], "starts with field ration prop")
	t.ok("prop_smoke_bomb" in rogue["props"], "starts with smoke bomb prop")
	_reject(campaign, "campaign.use_prop", {"id": "prop_imperial_decree"}, "missing_item", "cannot use unowned prop")
	_reject(campaign, "campaign.use_prop", {"id": "bogus_prop"}, "bad_args", "reject unknown prop id")
	var supply_before := int(rogue["coins"]["supply"])
	var vit_before := int(campaign.state["metrics"]["vitality"])
	_send(campaign, "campaign.use_prop", {"id": "prop_field_ration"})
	t.eq(int(campaign.state["rogue"]["coins"]["supply"]), supply_before + 3, "field ration adds supply coins")
	t.eq(int(campaign.state["metrics"]["vitality"]), mini(100, vit_before + 15), "field ration restores vitality")
	t.ok("prop_field_ration" not in campaign.state["rogue"]["props"], "used prop is consumed once")


func _test_inter_campaign_modes() -> void:
	var campaign := _new(1, 1815)
	_day(campaign)
	# 1. Monopoly-style March Board
	var pos0 := int(campaign.state["rogue"]["march"]["pos"])
	_send(campaign, "campaign.roll_dice", {"steps": 4})
	t.eq(int(campaign.state["rogue"]["march"]["pos"]), (pos0 + 4) % 12, "controlled dice roll with loaded dice moves exact steps")
	_send(campaign, "campaign.roll_dice", {})
	t.eq(int(campaign.state["rogue"]["march"]["rolls"]), 2, "deterministic dice roll increments roll count")
	# 2. Branching Route & Side Activities
	_send(campaign, "campaign.pick_route", {"route": "duel_route"})
	t.eq(str(campaign.state["rogue"]["march"]["route"]), "duel_route", "branching route selected")
	_reject(campaign, "campaign.pick_route", {"route": "salon_route"}, "already_used", "one route choice per scene")
	for act_id in ["salon", "duel", "gamble", "merchant", "rest", "festival", "diplomacy"]:
		_send(campaign, "campaign.activity", {"id": act_id})
	_reject(campaign, "campaign.activity", {"id": "salon"}, "already_used", "duplicate activity in same scene rejected")
	# 3. Stronghold & Weekly Calendar
	_send(campaign, "campaign.schedule", {"action": "recruit"})
	_send(campaign, "campaign.schedule", {"action": "train"})
	t.eq(int(campaign.state["rogue"]["calendar"]["countdown"]), 1, "calendar countdown decrements after two slots")
	_send(campaign, "campaign.schedule", {"action": "bond_story"})
	t.eq(int(campaign.state["rogue"]["calendar"]["countdown"]), 0, "calendar week completes after three slots")
	t.eq(int(campaign.state["rogue"]["calendar"]["week"]), 2, "completed calendar advances week")
	_reject(campaign, "campaign.schedule", {"action": "diplomacy"}, "already_complete", "cannot exceed weekly calendar slots")


func _test_companions_bonds_and_battle_grid() -> void:
	var campaign := _new(1, 1815)
	_day(campaign)
	# Starter companions (dantes, gourgaud, faria) already activate shadow bond (dantes + faria).
	var bonds_start: Dictionary = Campaign.RogueRules.active_bonds(campaign.state["rogue"])
	t.ok(bonds_start.has("shadow"), "starter companions activate shadow bond")
	# Recruit friday (island + far_sea) -> activates island (gourgaud + friday) and far_sea (dantes + friday)!
	_send(campaign, "campaign.recruit", {"id": "friday"})
	_reject(campaign, "campaign.recruit", {"id": "friday"}, "already_used", "cannot recruit duplicate companion")
	var bonds_after: Dictionary = Campaign.RogueRules.active_bonds(campaign.state["rogue"])
	t.ok(bonds_after.has("island") and bonds_after.has("far_sea"), "recruiting Friday activates island and far_sea bonds")
	# Promote dantes with medal coin
	var dantes_atk := int(campaign.state["rogue"]["companions"]["dantes"]["atk"])
	_send(campaign, "campaign.promote", {"id": "dantes"})
	t.eq(int(campaign.state["rogue"]["companions"]["dantes"]["level"]), 2, "dantes promoted to level 2")
	t.eq(int(campaign.state["rogue"]["companions"]["dantes"]["atk"]), dantes_atk + 6, "promotion increases companion attack")
	# 战斗 v2：剧情的决定等本场的仗了结；撤出随时可按，不转大命运
	t.eq(Campaign.Battle2.resolved(campaign), false, "scene01 battle not yet resolved")
	var gated: Array = campaign.available_choices().filter(func(c: Dictionary) -> bool: return str(c["reason"]) == "battle_pending")
	t.ok(not gated.is_empty(), "story choices wait for the battle")
	_send(campaign, "campaign.battle_prepare", {})
	_send(campaign, "campaign.battle_begin", {"companions": ["dantes"], "troops": [], "protagonist": false})
	_reject(campaign, "campaign.battle_start", {"protagonist": true}, "bad_args", "Gemini grid commands are gone")
	_send(campaign, "campaign.battle_cmd", {"cmd": "retreat", "args": {}})
	_send(campaign, "campaign.battle_finish", {})
	t.eq(bool(campaign.state["rogue"]["big_fate"]["pending"]), false, "retreat does not open the big fate")
	t.eq(Campaign.Battle2.resolved(campaign), true, "retreat resolves the scene battle")
	t.eq(campaign.available_choices().filter(func(c: Dictionary) -> bool: return str(c["reason"]) == "battle_pending"), [], "story choices open after the battle")
	# Defeat -> Big Fate & Companion Permadeath (一条命)：空名单连按交火，漏怪打光军心（模板保证“什么都不做必输”）
	var crisis := _new(2, 1815)
	_day(crisis)
	_send(crisis, "campaign.battle_prepare", {})
	_send(crisis, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
	for _turn in range(20):
		if str(crisis.state["rogue"]["battle2"]["state"]["phase"]) != "command":
			break
		_send(crisis, "campaign.battle_cmd", {"cmd": "fight", "args": {}})
	_send(crisis, "campaign.battle_finish", {})
	t.eq(bool(crisis.state["rogue"]["big_fate"]["pending"]), true, "defeat triggers Big Fate crisis")
	t.eq(Campaign.Battle2.resolved(crisis), false, "pending big fate keeps the story waiting")
	_reject(crisis, "campaign.battle_prepare", {}, "big_fate_pending", "cannot start new battle before resolving Big Fate")
	_send(crisis, "campaign.big_fate", {"choice": "sacrifice_rearguard"})
	t.eq(bool(crisis.state["rogue"]["big_fate"]["pending"]), false, "Big Fate resolved")
	t.eq(Campaign.Battle2.resolved(crisis), true, "chosen big fate resolves the scene battle")
	t.ok("dantes" in crisis.state["rogue"]["fallen_companions"], "sacrificed companion recorded in fallen_companions")
	t.eq(bool(crisis.state["rogue"]["companions"]["dantes"]["alive"]), false, "fallen companion has permadeath (alive == false)")
	_reject(crisis, "campaign.promote", {"id": "dantes"}, "companion_fallen", "fallen companion cannot be promoted")
	# 突围永远选得了：生命与动力不够 12 也能选，只是这一下耗尽，走“最后的灯火”
	var spent := _new(2, 1815)
	_day(spent)
	_send(spent, "campaign.battle_prepare", {})
	_send(spent, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
	for _turn in range(20):
		if str(spent.state["rogue"]["battle2"]["state"]["phase"]) != "command":
			break
		_send(spent, "campaign.battle_cmd", {"cmd": "fight", "args": {}})
	_send(spent, "campaign.battle_finish", {})
	spent.state["metrics"]["vitality"] = 5
	_send(spent, "campaign.big_fate", {"choice": "desperate_breakout"})
	t.eq([spent.state["phase"], spent.state["ending"]], ["game_over", "loss"], "breakout without vitality ends the voyage instead of deadlocking")
