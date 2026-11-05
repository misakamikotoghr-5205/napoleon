## Integration contracts for the formal-book default, segment identity, opening
## favors and repeat rival encounters. Altered mini definitions are isolated
## unit fixtures, not substitutes for the formal campaign playthrough.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/OCEAN/run_helpers.gd")
const Book = preload("res://scripts/cards/campaign/run/run_book.gd")
const Bridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const Rogue = preload("res://scripts/cards/campaign/ocean_rogue_rules.gd")
const B2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const View = preload("res://scripts/cards/campaign/ocean_view.gd")
const Combat = preload("res://scripts/tests/cards/OCEAN/battle_policy.gd")
const NodeCard = preload("res://scripts/cards/ui/map/map_node_card.gd")
const MapData = preload("res://scripts/cards/ui/map/map_data.gd")
const SquadPanel = preload("res://scripts/cards/ui/hub/hub_card_panel.gd")

var t: RefCounted
var _book := ""
var _plain_book := ""
var _passing_patrol_book := ""
var _env := {}


func _initialize() -> void:
	t = T.new(self, "OCEAN_napoleon_contracts")
	for key in ["DEHOUDANG_CAMPAIGN", "DEHOUDANG_START"]:
		_env[key] = [OS.has_environment(key), OS.get_environment(key)]
		OS.unset_environment(key)
	CardSave.set_root(t.user_dir())
	t.run_async(_run)


func _run() -> void:
	_test_default_resolution()
	_make_fixture()
	_test_segment_identity_and_favors()
	_test_debug_favors_and_recruitment()
	_test_repeat_rival()
	_test_wait_for_patrol()
	_test_resource_tolls()
	await _test_long_squad_menu()
	await _test_root_title({}, "napoleon", "toulon_arrival", true)
	await _test_root_title({"campaign": "ocean_pawn"}, "ocean", "prologue", false)
	for key in _env:
		if bool(_env[key][0]):
			OS.set_environment(key, str(_env[key][1]))
		else:
			OS.unset_environment(key)
	print("OCEAN napoleon contracts assertions: %d" % t.checks)


func _test_default_resolution() -> void:
	t.eq(Bridge.DEFAULT_BOOK, "napoleon", "the interactive default is the formal Napoleon book")
	t.eq(Bridge.game_opts({}).get("book"), Book.DEMO, "empty game options resolve to the branch demo")
	t.eq(Bridge.default_save_dir({}), "user://cards/napoleon-demo", "demo Continue uses its own directory")
	t.eq(Bridge.game_opts({"book": "napoleon_volume2"}).get("book"), Book.NAPOLEON, "complete second volume remains explicitly available")
	t.eq(Bridge.default_save_dir({"book": "napoleon_volume2"}), "user://cards/napoleon-volume2", "second-volume Continue keeps its original directory")
	t.eq(Bridge.game_opts({"book": "napoleon_volume1"}).get("book"), Book.VOLUME1, "the first-volume book keeps its original path")
	t.eq(Bridge.default_save_dir({"book": "napoleon_volume1"}), "user://cards/napoleon", "first-volume Continue keeps the original directory")
	t.eq(Bridge.game_opts({"campaign": "ocean_pawn"}).get("book"), "", "explicit legacy ocean campaign remains the single-segment book")
	t.eq(Bridge.default_save_dir({"campaign": "ocean_pawn"}), "user://cards/ocean_pawn", "the original ocean save directory is preserved")
	t.eq(Bridge.game_opts({"book": "ocean_pawn"}).get("book"), "", "explicit ocean book remains supported")
	OS.set_environment("DEHOUDANG_CAMPAIGN", "ocean_pawn")
	t.eq(Bridge.default_save_dir({}), "user://cards/ocean_pawn", "environment selector and Continue agree")
	t.eq(Bridge.game_opts({"campaign": "napoleon"}).get("book"), Book.DEMO, "explicit campaign overrides the environment selector")
	OS.unset_environment("DEHOUDANG_CAMPAIGN")


func _json(path: String) -> Dictionary:
	return Book.read_json(path).get("data", {})


func _write(name: String, data: Dictionary) -> String:
	var path: String = t.user_dir() + "/" + name + ".json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, " ", true))
	file.close()
	return path


func _make_fixture() -> void:
	var raw := _json(H.MINI)
	raw["bond_set"] = "napoleon"
	raw["hero"] = {"bonds": ["italy", "quartermaster"], "bonds_by_segment": {"ocean": ["imperial", "far_sea"]}}
	var companions := _json(str(raw["companions"]))
	companions["companions"]["baptiste"]["bonds"] = ["quartermaster"]
	companions["companions"]["baptiste"]["bonds_by_segment"] = {"ocean": ["scholar", "far_sea"]}
	# Use Nemo's authored favor verbatim; only move his recruitment offer to a
	# small fixture node so this contract does not need the whole world route.
	var nemo: Dictionary = _json("res://data/campaigns/napoleon/companions.json")["companions"]["nemo"].duplicate(true)
	nemo["recruit"] = [{"seg": "ocean", "node": "mo_one:o_dock", "gold": 3}]
	companions["companions"]["nemo"] = nemo
	raw["companions"] = _write("companions", companions)
	var trunk := _json(str(raw["segments"]["trunk"]["file"]))
	for option in trunk["scenes"][0]["choices"]:
		if str(option["id"]) == "mt_take_letter":
			option["flags"].append("t_mysore_envoy")
	raw["segments"]["trunk"]["file"] = _write("trunk", trunk)
	raw["shared_flags"].append("t_mysore_envoy")
	var ocean_map := _json(str(raw["segments"]["ocean"]["map"]))
	ocean_map["sheets"][0]["nodes"][0]["actions"] = ["recruit:nemo"]
	raw["segments"]["ocean"]["map"] = _write("ocean-map", ocean_map)
	var trunk_map := _json(str(raw["segments"]["trunk"]["map"]))
	trunk_map["sheets"][1]["rivals"] = [{"id": "contract_rider", "label": "Contract rider", "path": ["b_supply"], "speed": 0, "start": 0,
		"meet": {"battle": {"template": "skirmish_c", "level": 1}, "toll": {"gold": 1}}, "burns_depots": false, "boss_waves_minus": 1}]
	raw["segments"]["trunk"]["map"] = _write("trunk-map", trunk_map)
	_plain_book = _write("book-without-opening-favor", raw)
	raw["debug_carry"]["branch_point"]["flags"].append("t_mysore_envoy")
	_book = _write("book-with-opening-favor", raw)
	var check := Book.load_bundle(_book)
	t.ok(check.get("ok", false), "isolated contract book loads")
	if bool(check.get("ok", false)):
		t.eq(Book.validate(check["book"])["errors"], [], "contract fixture obeys the same book/map validators")
	var passing_map := trunk_map.duplicate(true)
	passing_map["sheets"][1]["rivals"] = [
		{"id": "other_patrol", "path": ["b_fork"], "speed": 0, "start": 0, "meet": {"toll": {"gold": 1}}},
		{"id": "passing_patrol", "path": ["b_supply", "b_march"], "speed": 1, "start": 0, "meet": {"toll": {"gold": 999}}}]
	raw["segments"]["trunk"]["map"] = _write("passing-patrol-map", passing_map)
	_passing_patrol_book = _write("book-with-passing-patrol", raw)
	check = Book.load_bundle(_passing_patrol_book)
	t.ok(check.get("ok", false), "isolated passing-patrol book loads")
	if bool(check.get("ok", false)):
		t.eq(Book.validate(check["book"])["errors"], [], "passing-patrol fixture obeys the book/map validators")


func _new(path: String, opts: Dictionary = {}) -> RefCounted:
	var c := Campaign.new()
	var options := {"book": path, "seed": 7}
	options.merge(opts, true)
	var result := c.new_game(options)
	t.ok(result.get("ok", false), "fixture new_game: " + str(result))
	return c


func _send(c, command: String, args: Dictionary = {}) -> Dictionary:
	var result: Dictionary = c.send(StringName(command), args)
	t.ok(result.get("ok", false), "%s %s: %s" % [command, args, result])
	return result


func _trust(c, id: String) -> int:
	return int(c.snapshot().get("rogue", {}).get("army", {}).get("trust", {}).get("hero|" + id, 0))


func _test_segment_identity_and_favors() -> void:
	var c = _new(_book)
	var cached: Dictionary = c.roster()
	t.eq(cached["specs"]["baptiste"]["bonds"], ["quartermaster"], "warm roster cache uses trunk allegiance")
	t.eq(B2.hero_profile(c)["tags"], ["italy", "quartermaster"], "trunk hero uses book allegiance")
	H.to_day(c)
	_send(c, "campaign.appraise", {"id": "mt_seal"})
	var plan := {"mt_arrive": "mt_take_letter", "mt_march": "mt_swear"}
	for _i in range(8):
		if str(c.scene().get("id", "")) == "mt_fork":
			break
		H.play_interlude(c)
		t.ok(H.play_scene(c, str(plan.get(str(c.scene().get("id", "")), ""))), "legal mini scene progression: " + H.last_error)
	t.eq(c.scene().get("id"), "mt_fork", "unit fixture reaches its real fork")
	H.play_interlude(c)
	t.ok(H.walk_to(c, "b_fork"), "walk to the actual branch anchor")
	H.to_day(c)
	_send(c, "campaign.choose", {"choice": "fork_ocean"})
	t.eq(c.snapshot()["run"]["path"], ["trunk", "ocean"], "one model transitions through the real branch command")
	t.eq(c.roster()["specs"]["baptiste"]["bonds"], ["scholar", "far_sea"], "cached roster is rebound to the new segment")
	t.eq(cached["specs"]["baptiste"]["bonds"], ["quartermaster"], "switch does not mutate the previously returned trunk roster")
	t.eq(B2.hero_profile(c)["tags"], ["imperial", "far_sea"], "hero uses ocean-specific allegiance")
	t.ok(not bool(c.snapshot()["rogue"]["companions"]["nemo"]["recruited"]), "favor is granted before Nemo joins")
	t.eq(_trust(c, "nemo"), 1, "the Mysore favor gives one trust on entering ocean")
	H.to_day(c)
	for _i in range(3):
		View.query(c, &"campaign")
		c.roster()
	t.eq(_trust(c, "nemo"), 1, "ordinary phase transitions and queries do not repeat opening favors")
	var restored := Campaign.new()
	t.ok(restored.load_book(_book).get("ok", false), "fresh restore model loads the same fixture")
	t.ok(restored.restore(c.snapshot()).get("ok", false), "restore accepts the post-branch snapshot")
	t.eq(restored.hash(), c.hash(), "restoring does not apply a favor twice")
	t.eq(_trust(restored, "nemo"), 1, "restored unrecruited Nemo retains exactly one trust")
	t.eq(restored.roster()["specs"]["baptiste"]["bonds"], ["scholar", "far_sea"], "restore rebuilds the correct segment roster")
	_test_lineup(c)


func _test_lineup(c) -> void:
	for _i in range(4):
		if str(c.scene().get("id", "")) == "mo_boss1":
			break
		t.ok(H.play_scene(c), "reach the battle via authored scene commands: " + H.last_error)
	t.ok(H.muster(c), "muster through the actual map gate")
	t.ok(H.walk_to(c, "o_boss"), "walk to the ocean boss")
	H.to_day(c)
	_send(c, "campaign.battle_prepare")
	var lineup: Dictionary = View.query(c, &"campaign")["battle2"]["lineup"]
	t.eq(lineup["protagonist"]["bonds"], ["imperial", "far_sea"], "public lineup shows the segment-specific hero tags")
	var candidate: Dictionary = {}
	for row in lineup["candidates"]:
		if str(row["id"]) == "baptiste":
			candidate = row
	t.eq(candidate.get("bonds"), ["scholar", "far_sea"], "public candidate uses the refreshed roster")
	var expected: Array = []
	for row in B2.lib()["bond_sets"]["napoleon"]:
		expected.append(str(row) if typeof(row) == TYPE_STRING else str(row["id"]))
	var shown: Array = []
	for row in lineup["bond_set"]:
		shown.append(str(row["id"]))
	t.eq(shown, expected, "public lineup shows the authored Napoleon bond definitions")
	_send(c, "campaign.battle_begin", {"companions": ["baptiste"], "troops": [], "protagonist": true})
	var battle: Dictionary = c.snapshot()["rogue"]["battle2"]["state"]
	t.eq(battle["units"]["hero"]["tags"], ["imperial", "far_sea"], "actual battle setup uses the book hero tags")
	t.eq(battle["units"]["baptiste"]["tags"], ["scholar", "far_sea"], "actual battle setup uses segment companion tags")
	var actual: Array = []
	for row in battle["bond_defs"]:
		actual.append(str(row["id"]))
	t.eq(actual, expected, "actual battle rules use Napoleon bonds rather than the ocean fallback")


func _test_debug_favors_and_recruitment() -> void:
	var plain = _new(_plain_book, {"segment": "ocean"})
	H.to_day(plain)
	t.eq(_trust(plain, "nemo"), 0, "no historical favor gives no opening trust")
	t.eq(Rogue.recruit_cost(plain, "nemo"), 3, "authored node price without the favor")
	var favored = _new(_book, {"segment": "ocean"})
	H.to_day(favored)
	t.eq(_trust(favored, "nemo"), 1, "debug carry applies opening favors after its flags are installed")
	t.eq(Rogue.recruit_cost(favored, "nemo"), 2, "Mysore favor discounts Nemo by one gold")
	var gold := int(favored.snapshot()["rogue"]["coins"]["gold"])
	_send(favored, "campaign.recruit", {"id": "nemo"})
	t.eq(int(favored.snapshot()["rogue"]["coins"]["gold"]), gold - 2, "real recruitment spends the discounted amount")
	t.ok(favored.snapshot()["rogue"]["companions"]["nemo"]["recruited"], "Nemo is recruited through the node command")
	t.eq(_trust(favored, "nemo"), 1, "recruitment preserves trust earned before joining")
	var before: String = favored.hash()
	t.eq(favored.send(&"campaign.recruit", {"id": "nemo"}).get("err"), "already_used", "recruiting again is rejected")
	t.eq(favored.hash(), before, "duplicate recruitment neither charges nor grants trust")


func _test_repeat_rival() -> void:
	var c = _new(_book, {"stage": 1})
	H.to_day(c)
	_send(c, "campaign.map_roll", {"steps": 6})
	_send(c, "campaign.map_move", {"to": "b_supply"})
	t.eq(View.query(c, &"campaign.map").get("meet"), "contract_rider", "walking onto the fixture patrol creates a real encounter")
	t.eq(View.query(c, &"campaign.map").get("pay"), {"gold": 1, "cost": {"gold": 1}, "can_gold": true, "can_prop": false, "can_fight": true, "can_wait": false}, "payment choices describe this stationary armed patrol")
	_send(c, "campaign.map_pay", {"how": "fight"})
	_send(c, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
	_send(c, "campaign.battle_cmd", {"cmd": "retreat", "args": {}})
	_send(c, "campaign.battle_finish")
	if bool(View.query(c, &"campaign").get("big_fate", {}).get("pending", false)):
		_send(c, "campaign.big_fate", {"choice": "desperate_breakout"})
	var before: String = c.hash()
	t.ok(not bool(c.send(&"campaign.battle_finish", {}).get("ok", false)), "finishing the same rival battle twice is rejected")
	t.eq(c.hash(), before, "duplicate finish grants no reward")
	_send(c, "campaign.map_move", {"to": "b_march"})
	_send(c, "campaign.map_move", {"to": "b_supply"})
	t.eq(View.query(c, &"campaign.map").get("meet"), "contract_rider", "the unbeaten patrol can be encountered again")
	_send(c, "campaign.map_pay", {"how": "fight"})
	var battle: Dictionary = View.query(c, &"campaign")["battle2"]
	t.eq(battle.get("phase"), "lineup", "retreating does not leave a stale finished key blocking the next battle")
	_send(c, "campaign.battle_begin", Combat.lineup(battle["lineup"]))
	for _i in range(500):
		battle = View.query(c, &"campaign")["battle2"]
		if bool(battle.get("over", false)):
			break
		var action := Combat.next_action(battle.get("view", {}), View.query(c, &"campaign.battle_preview"))
		_send(c, "campaign.battle_cmd", {"cmd": action[0] if not action.is_empty() else "fight", "args": action[1] if not action.is_empty() else {}})
	t.eq(View.query(c, &"campaign")["battle2"].get("result", {}).get("outcome"), "victory", "the repeat encounter can be won using public combat information")
	_send(c, "campaign.battle_finish")
	_send(c, "campaign.map_move", {"to": "b_march"})
	_send(c, "campaign.map_move", {"to": "b_supply"})
	t.eq(View.query(c, &"campaign.map").get("meet"), "", "a defeated patrol does not grant another encounter")
	t.eq(View.query(c, &"campaign.map").get("pay"), {}, "resolved encounter exposes no stale payment choices")
	t.eq(c.snapshot()["map"]["boss_waves_minus"], 1, "the patrol's boss-wave reward is applied once")


func _test_wait_for_patrol() -> void:
	var c = _new(_passing_patrol_book, {"stage": 1})
	H.to_day(c)
	_send(c, "campaign.map_roll", {"steps": 6})
	_send(c, "campaign.map_move", {"to": "b_supply"})
	if str(View.query(c, &"campaign.map").get("meet", "")) == "":
		H.next_day(c)
	t.eq(View.query(c, &"campaign.map").get("meet"), "passing_patrol", "a moving patrol meets the player at its real route stop")
	t.eq(View.query(c, &"campaign.map").get("pay"), {"gold": 999, "cost": {"gold": 999}, "can_gold": false, "can_prop": false, "can_fight": false, "can_wait": true}, "unaffordable toll-only patrol offers waiting and uses its own fee")
	var before: String = c.hash()
	t.eq(c.send(&"campaign.map_pay", {"how": "gold"}).get("err"), "insufficient_funds", "unaffordable toll is rejected")
	t.eq(c.hash(), before, "failed payment leaves the encounter unchanged")
	t.eq(c.send(&"campaign.map_pay", {"how": "fight"}).get("err"), "bad_args", "a patrol without a battle cannot be fought")
	t.eq(c.hash(), before, "unavailable fight leaves the encounter unchanged")
	H.next_day(c)
	var map: Dictionary = View.query(c, &"campaign.map")
	t.eq([map.get("pending"), map.get("meet"), map.get("pay")], ["", "", {}], "waiting until the patrol moves on clears its block and payment menu")
	_send(c, "campaign.map_roll", {"steps": 6})
	_send(c, "campaign.map_move", {"to": "b_slot1"})


func _test_resource_tolls() -> void:
	# Read the real non-gold offers; isolate only their encounter location.
	var tolls: Array = []
	for sheet in _json("res://data/campaigns/napoleon/maps/europe.json")["sheets"]:
		for rival in sheet.get("rivals", []):
			if str(rival["id"]) in ["storks_convoy", "campbell_cutter"]:
				tolls.append((rival["meet"]["toll"] as Dictionary).duplicate(true))
	t.eq(tolls, [{"supply": 2}, {"intel": 1}], "formal patrols retain their authored resource tolls")
	tolls.append({"gold": 1, "supply": 2, "intel": 1})
	for index in tolls.size():
		var toll: Dictionary = tolls[index]
		var raw := _json(_book)
		var map := _json(str(raw["segments"]["trunk"]["map"]))
		map["sheets"][1]["rivals"][0]["meet"] = {"toll": toll}
		raw["segments"]["trunk"]["map"] = _write("resource-toll-map-" + str(index), map)
		# Preserve at least one intel after the deterministic roll's cost.
		raw["start_rogue"]["coins"] = {"gold": 4, "supply": 6, "medal": 2, "intel": 3}
		var path := _write("resource-toll-book-" + str(index), raw)
		var c = _new(path, {"stage": 1})
		H.to_day(c)
		_send(c, "campaign.map_roll", {"steps": 6})
		_send(c, "campaign.map_move", {"to": "b_supply"})
		var public_map: Dictionary = View.query(c, &"campaign.map")
		t.eq(public_map["pay"]["cost"], toll, "public payment shows the complete resource toll")
		t.ok(public_map["pay"]["can_gold"], "legacy payment command is available when all resources suffice")
		_assert_toll_button(c, toll, true)
		var coins: Dictionary = c.snapshot()["rogue"]["coins"]
		var expected := coins.duplicate(true)
		for currency in toll:
			expected[currency] = int(expected[currency]) - int(toll[currency])
		_send(c, "campaign.map_pay", {"how": "gold"})
		t.eq(c.snapshot()["rogue"]["coins"], expected, "payment spends each authored resource and leaves all others unchanged")
		t.eq(View.query(c, &"campaign.map")["pending"], "", "paid toll releases the encounter")
		var paid_hash: String = c.hash()
		t.eq(c.send(&"campaign.map_pay", {"how": "gold"}).get("err"), "bad_phase", "one encounter can only be paid once")
		t.eq(c.hash(), paid_hash, "repeat payment does not charge again")
		# The starting loaded die permits a fixed roll with no intel to spend.
		# Insufficient supply/intel exercises atomic rejection of mixed costs.
		raw["start_rogue"]["coins"]["supply"] = 0
		raw["start_rogue"]["coins"]["intel"] = 0
		path = _write("resource-toll-poor-" + str(index), raw)
		var poor = _new(path, {"stage": 1})
		H.to_day(poor)
		_send(poor, "campaign.map_roll", {"steps": 6})
		_send(poor, "campaign.map_move", {"to": "b_supply"})
		t.ok(not View.query(poor, &"campaign.map")["pay"]["can_gold"], "missing supply/intel disables payment despite enough gold")
		_assert_toll_button(poor, toll, false)
		var before: String = poor.hash()
		t.eq(poor.send(&"campaign.map_pay", {"how": "gold"}).get("err"), "insufficient_funds", "resource shortage rejects the whole toll")
		t.eq(poor.hash(), before, "shortage neither consumes other resources nor clears the encounter")
		t.eq(View.query(poor, &"campaign.map")["meet"], "contract_rider", "non-gold toll cannot be cleared for free")


func _assert_toll_button(c, toll: Dictionary, enabled: bool) -> void:
	var panel := NodeCard.new()
	var map: Dictionary = View.query(c, &"campaign.map")
	panel.refresh(map, View.query(c, &"campaign"), MapData.node(map, str(map["pos"])))
	var button := panel.action_button("pay_gold")
	t.ok(button != null, "resource payment retains the existing action button")
	if button != null:
		t.eq(button.disabled, not enabled, "button affordability matches the public payment contract")
		for currency in toll:
			t.ok(button.text.contains(MapData.text("resources." + str(currency))), "payment label names " + str(currency))
		if not toll.has("gold"):
			t.ok(not button.text.contains(MapData.text("resources.gold")), "non-gold toll is not presented as free gold")
	panel.free()


func _test_long_squad_menu() -> void:
	# A complete authored roster is a supported unit fixture, with no live-state edits.
	var raw := _json(Book.NAPOLEON)
	var members: Dictionary = _json(str(raw["companions"]))["companions"]
	var carry := {}
	for id in members:
		carry[id] = 1
	raw["debug_carry"]["conquest"]["stages"]["0"]["companions"] = carry
	var path := _write("long-squad-book", raw)
	var engine := CardEngine.new()
	var result := engine.new_game({"book": path, "segment": "conquest", "seed": 30, "save_dir": t.user_dir() + "/long-squad"})
	t.ok(result.get("ok", false), "long roster starts from isolated debug carry")
	for _i in range(8):
		if str(engine.view().get("phase", "")) == "day":
			break
		t.ok(engine.send(&"campaign.wait", {}).get("ok", false), "long roster reaches day via normal phase commands")
	var panel := SquadPanel.new()
	panel.fast = true
	panel.bind(engine, null)
	root.add_child(panel)
	panel.open({"uid": "squad"})
	await t.frames(4)
	var buttons := panel.choice_buttons().filter(func(button: Button) -> bool:
		return str(button.get_meta("reply_id", "")).begins_with("action:promote:"))
	t.eq(buttons.size(), 28, "long roster keeps every legal promotion action")
	var scroll := panel.find_child("ChoicesScroll", true, false) as ScrollContainer
	t.ok(scroll != null, "the existing choice area supports scrolling")
	if scroll != null and not buttons.is_empty():
		var last: Button = buttons[-1]
		t.ok(not last.disabled, "the last authored companion can be promoted")
		t.ok(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "long roster has vertical overflow to scroll")
		scroll.ensure_control_visible(last)
		await t.frames(3)
		t.ok(scroll.scroll_vertical > 0, "scrolling reaches the final companion")
		t.ok(scroll.get_global_rect().encloses(last.get_global_rect()), "the final action is fully inside the visible choice viewport")
		var later := panel.find_child("BtnLater", true, false) as Button
		t.ok(later != null and Rect2(0, 0, 1280, 720).encloses(later.get_global_rect()), "the return button stays on screen with 28 choices")
		var id := str(last.get_meta("reply_id")).trim_prefix("action:promote:")
		var before := _public_companion(engine, id)
		# Real viewport input verifies hit testing through the scroll container.
		var point := last.get_global_rect().get_center()
		for down in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.position = point
			click.global_position = point
			root.push_input(click, true)
			await t.frames(1)
		t.eq(_public_companion(engine, id).get("level"), int(before.get("level", 0)) + 1, "clicking the scrolled final control promotes the actual companion")
	panel.queue_free()
	await t.frames(3)


func _public_companion(engine: CardEngine, id: String) -> Dictionary:
	for row in engine.query(&"campaign").get("companions", []):
		if str(row.get("id", "")) == id:
			return row
	return {}


func _test_root_title(options: Dictionary, segment: String, scene: String, map_enabled: bool) -> void:
	var game := load(CardIds.ROOT_SCENE).instantiate() as CardGameRoot
	root.add_child(game)
	await t.frames(2)
	var dir: String = t.user_dir() + "/root-" + segment
	var boot := {"mock": false, "guide": "off", "seed": 30, "save_dir": dir, "settings_path": dir + "/settings.json"}
	boot.merge(options, true)
	game.boot(boot)
	game.allow_quit = false
	game.host.fast = true
	await t.frames(3)
	t.eq(CardSave.root(), dir, "title reads the explicitly isolated save directory")
	var title_name := str(game.title.call("campaign_window_title"))
	t.eq(game.get_window().title, title_name, "root window identity agrees with the title before starting")
	var button := game.title.get_node_or_null("new") as Button
	t.ok(button != null and not button.disabled, "selected book can start from its real title button")
	if button != null and not button.disabled:
		button.pressed.emit()
		await t.frames(6)
		var campaign := game.engine.query(&"campaign")
		t.eq(campaign.get("scene_id"), scene, "title starts the selected book's first scene")
		t.eq(game.engine.query(&"campaign.run").get("segment"), "trunk" if segment == "napoleon" else segment, "engine segment agrees with title selection")
		t.eq(game.engine.query(&"campaign.map").get("enabled", false), map_enabled, "only the formal book starts with a map")
		t.eq(CardSave.root(), dir, "starting the engine keeps title and Continue on the same isolated directory")
		t.ok(FileAccess.file_exists(dir + "/suspend.json"), "new game writes its snapshot into the isolated slot")
	game.queue_free()
	await t.frames(4)
