## A2 acceptance: public map policy and the real root/title/map/VN/battle/save controls.
## No gameplay state is edited to make a route reachable.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/map_policy.gd")
const MINI := "res://data/campaigns/napoleon/fixtures/mini_book.json"
const VnData = preload("res://scripts/cards/ui/vn/vn_data.gd")
const VnStage = preload("res://scripts/cards/ui/vn/vn_stage.gd")
const Canvas = preload("res://scripts/cards/ui/map/map_canvas.gd")

var t
var game: CardGameRoot
var _old_campaign := ""
var _had_campaign := false
var _commands: Array = []
var _dir := ""


func _initialize() -> void:
	_had_campaign = OS.has_environment("DEHOUDANG_CAMPAIGN")
	_old_campaign = OS.get_environment("DEHOUDANG_CAMPAIGN")
	OS.unset_environment("DEHOUDANG_CAMPAIGN")
	t = T.new(self, "OCEAN_map_ui")
	t.run_async(_body)


func _body() -> void:
	_test_public_policy()
	_test_away_anchor()
	await _boot("route")
	_test_cli()
	if await _press(game.title.get_node_or_null("new") as Button, "title new") and await _to_day():
		await _test_map_route()
	await _dispose()
	await _test_chapter_entry()
	await _dispose()
	await _test_stage_entry()
	await _test_art_override()
	await _test_world_renderer()
	await _dispose()
	await _boot("invalid_stage", {"stage": "bogus"})
	t.eq(game.title.selected_game_options().get("stage"), "bogus", "title preserves an invalid stage for engine validation instead of coercing it to zero")
	await _dispose()
	var failed := _commands.filter(func(row: Array) -> bool: return not bool(row[2]))
	t.eq(failed, [], "all commands issued by interactive controls succeed")
	var bus := root.get_node_or_null("CardBus") as CardEventBus
	if bus != null and bus.command_done.is_connected(_record):
		bus.command_done.disconnect(_record)
	if _had_campaign:
		OS.set_environment("DEHOUDANG_CAMPAIGN", _old_campaign)
	else:
		OS.unset_environment("DEHOUDANG_CAMPAIGN")
	print("OCEAN map UI assertions: %d; control commands: %d" % [t.checks, _commands.size()])


func _test_public_policy() -> void:
	for branch in ["conquest", "ocean", "cristo"]:
		var engine := CardEngine.new()
		var options := {"book": MINI, "seed": 30, "save_dir": t.user_dir() + "/policy_" + branch}
		t.ok(engine.new_game(options).get("ok", false), "policy starts a real mini book: " + branch)
		var policy := Policy.new()
		policy.branch = branch
		var success := policy.finish(engine)
		t.ok(success, "public policy reaches " + branch + " ending: " + policy.last_error)
		t.eq(engine.query(&"campaign.run").get("path"), ["trunk", branch], "policy traverses trunk and " + branch)
		var ending := str(engine.query(&"campaign").get("ending_id", ""))
		t.ok(ending.begins_with({"conquest": "k_mini_vol_", "ocean": "o_mini_", "cristo": "m_mini_vol_"}[branch]),
			"policy reaches an authored ending, not a failure: " + ending)
		print("MAP POLICY %s commands=%d ending=%s" % [branch, policy.commands.size(), ending])


func _test_away_anchor() -> void:
	var engine := CardEngine.new()
	t.ok(engine.new_game({"book": MINI, "seed": 30, "save_dir": t.user_dir() + "/away"}).get("ok", false), "start anchor-gate scenario")
	for _i in 5:
		if str(engine.view().get("phase", "")) == "day": break
		t.ok(engine.send(&"campaign.wait", {}).get("ok", false), "advance anchor-gate scenario through public command")
	t.ok(engine.send(&"campaign.map_roll", {}).get("ok", false), "roll before leaving an unread story")
	t.ok(engine.send(&"campaign.map_move", {"to": "a_post"}).get("ok", false), "move away from the story anchor through public command")
	var card := engine.query(&"card", {"uid": "story:mt_arrive"})
	var options: Array = card.get("choices", []).filter(func(row: Dictionary) -> bool: return str(row.get("id", "")) == "action:appraise:mt_seal")
	t.ok(options.size() == 1 and not bool(options[0].get("enabled", true)), "appraisal is disabled away from its map anchor")
	if not options.is_empty(): t.eq(options[0].get("reason"), "wrong_node", "away-anchor appraisal tells the player why it is unavailable")
	t.eq(card.get("observations"), [], "moving away does not reveal the appraisal answer")


func _boot(label: String, options: Dictionary = {}) -> void:
	_dir = t.user_dir() + "/" + label
	game = load(CardIds.ROOT_SCENE).instantiate() as CardGameRoot
	root.add_child(game)
	await t.frames(2)
	var bus := root.get_node("CardBus") as CardEventBus
	if not bus.command_done.is_connected(_record):
		bus.command_done.connect(_record)
	var boot := {"mock": false, "bus": bus, "guide": "off", "seed": 30, "book": MINI,
		"save_dir": _dir, "settings_path": _dir + "/settings.json"}
	boot.merge(options, true)
	game.boot(boot)
	game.allow_quit = false
	game.stage.fast = true
	game.host.fast = true
	CardText.set_show_drafts(false)
	await t.frames(3)
	t.ok(game.title != null, "book starts at the real title")


func _test_cli() -> void:
	var opts: Dictionary = game.call("_cmdline_opts", PackedStringArray([
		"--campaign=napoleon", "--book=" + MINI, "--segment=ocean", "--stage=1", "--map-reveal",
		"--save-dir=user://test/isolated-map-cli"]))
	t.eq(opts.get("campaign"), "napoleon", "CLI preserves campaign")
	t.eq(opts.get("book"), MINI, "CLI preserves explicit book path")
	t.eq(opts.get("segment"), "ocean", "CLI preserves segment")
	t.eq(opts.get("stage"), 1, "CLI parses stage as integer")
	t.eq(opts.get("map_reveal"), true, "CLI debug reveal flag")
	t.eq(opts.get("save_dir"), "user://test/isolated-map-cli", "CLI keeps debug campaign saves isolated")
	var bad: Dictionary = game.call("_cmdline_opts", PackedStringArray(["--stage=bogus"]))
	t.eq(bad.get("stage"), "bogus", "bad stage is preserved for engine validation instead of silently opening chapter zero")


func _test_map_route() -> void:
	t.eq(game.engine.query(&"campaign.run").get("book"), "mini", "title forwards book to engine")
	t.eq(root.title, "迷你书", "window title follows the selected book")
	t.ok(game.hub != null and game.hub.get_script().resource_path.ends_with("map/map_panel.gd"), "map-enabled book installs MapPanel")
	if game.hub == null or not game.hub.has_method("map_canvas"):
		return
	t.ok(not game.hub.fixed_steps().get_global_rect().intersects(game.hub.action_button("roll_fixed").get_global_rect()),
		"fixed march roll button does not overlap the step selector or its arrows")
	await _shot("map-main")
	_test_queries()
	var canvas: Control = game.hub.map_canvas()
	var before := (game.engine as CardEngine).state_hash()
	canvas.set_zoom(2.0)
	await t.frames(2)
	t.eq(canvas.get_zoom(), 2.0, "map zooms to two times")
	t.eq((game.engine as CardEngine).state_hash(), before, "zoom is presentation-only")
	await _shot("map-zoom-2x")
	canvas.set_zoom(1.0)
	await t.frames(2)
	# The first adjacent node is selected through the actual mouse handler.
	var local: Vector2 = canvas.node_screen_position("a_post")
	t.eq(canvas.hit_test(local), "a_post", "visible node has a clickable hit target")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = local
		click.pressed = pressed
		canvas.call("_gui_input", click)
	await t.frames(2)
	t.eq(canvas.selected_node, "a_post", "mouse selects a map node")
	t.ok(game.hub.action_button("move").disabled, "cannot move before earning march points")
	await _shot("map-node-and-hand")
	game.hub.select_node("a_boss")
	await t.frames(2)
	t.ok(game.hub.action_button("move").disabled, "campaign boss remains locked before muster")
	game.hub.select_node("a_arrive")
	await t.frames(2)
	if not await _press(game.hub.action_button("enter"), "enter the first story"):
		return
	if not await _vn_choice("action:appraise:mt_seal"):
		return
	if not await _vn_choice("action:choose:mt_take_letter"):
		return
	await _clear_overlays()
	t.eq(game.engine.query(&"campaign").get("scene_id"), "mt_battle1", "story choice advances through real VN")
	if not await _press(game.hub.card_button("inventory"), "open map inventory"): return
	t.eq(str(game.host.top_kind()), "map", "map inventory uses the registered map modal")
	if not await _press(game.host.top_panel().action_button("item:mini_watch"), "inspect the story reward in map inventory"): return
	t.eq(str(game.host.top_kind()), "read", "inventory forwards its item to the existing reader")
	await _dismiss()
	await _resume()
	if not await _take_points():
		return
	if not await _move("a_post"):
		return
	t.eq(game.engine.query(&"campaign.map").get("stamps"), 1, "passing the post gives a stamp")
	if not await _press(game.hub.action_button("build"), "build supply depot"):
		return
	t.ok("a_post" in game.engine.query(&"campaign.map").get("depots", []), "depot command reaches the real backend")
	if not await _walk("a_muster"):
		return
	if not await _press(game.hub.action_button("muster"), "muster after earning stamp"):
		return
	t.eq(game.engine.query(&"campaign.map").get("mustered"), true, "muster opens the campaign route")
	if not await _walk("a_council"):
		return
	if not await _press(game.hub.action_button("enter"), "enter council event"):
		return
	var event := str(game.engine.query(&"campaign.map").get("event", ""))
	t.ok(event != "", "council sets the active event")
	_test_queries()
	if not await _vn_first_choice():
		return
	await _clear_overlays()
	t.eq(game.engine.query(&"card", {"uid": "event:" + event}), {}, "resolved event card disappears")
	if not await _walk("a_camp"):
		return
	if not await _press(game.hub.action_button("enter"), "enter camp node"):
		return
	t.eq(str(game.host.top_kind()), "map_camp", "camp node uses registered map modal")
	var supply := int(game.engine.query(&"campaign").get("coins", {}).get("supply", 0))
	if not await _press(game.host.top_panel().action_button("activity:rest"), "rest in the camp"):
		return
	t.eq(game.engine.query(&"campaign").get("coins", {}).get("supply"), supply + 2, "camp rest applies the authored supply reward")
	await _dismiss()
	if not await _walk("a_boss"):
		return
	if not await _press(game.hub.card_button("battle"), "map opens the battle lineup"):
		return
	t.eq(str(game.host.top_kind()), "battle_lineup", "battle card opens the existing lineup")
	if not await _press(game.host.top_panel().find_child("BtnMarch", true, false) as Button, "begin battle"):
		return
	t.eq(str(game.host.top_kind()), "battle_v2", "lineup leads to the existing battle field")
	if not await _press(game.host.top_panel().find_child("BtnRetreat", true, false) as Button, "retreat control"):
		return
	if not await _press(game.host.top_panel().find_child("BtnRetreatYes", true, false) as Button, "confirm retreat"):
		return
	if not await _press(game.host.top_panel().find_child("BtnResult", true, false) as Button, "view battle result"):
		return
	if not await _press(game.host.top_panel().find_child("BtnContinue", true, false) as Button, "settle battle result"):
		return
	await _clear_overlays()
	t.ok(bool(game.engine.query(&"campaign.battle2").get("resolved", false)), "battle is resolved and map remains usable")
	if not await _press(game.hub.action_button("enter"), "return to anchor story"):
		return
	if not await _vn_choice("action:choose:mt_after1"):
		return
	await _clear_overlays()
	if not await _to_day():
		return
	t.eq(game.engine.query(&"campaign.map").get("sheet"), "mt_two", "chapter transition opens the next map")
	# The second chapter starts with an interlude; it uses the same event VN path.
	if str(game.engine.query(&"campaign.map").get("interlude", "")) != "":
		if not await _press(game.hub.action_button("interlude"), "open chapter interlude"):
			return
		t.eq(str(game.host.top_kind()), "map_interlude", "chapter interlude uses registered map modal")
		if not await _press(game.host.top_panel().action_button("interlude"), "read chapter interlude"):
			return
		if not await _vn_first_choice():
			return
		await _clear_overlays()
	_test_queries()
	await _test_reveal_controls()
	await _shot("map-fog-rivals")
	await _resume()
	if not await _press(game.hub.action_button("roll"), "roll actual march dice"):
		return
	var points := int(game.engine.query(&"campaign.map").get("mp", 0))
	t.ok(points >= 1 and points <= 6, "dice supplies a legal march distance")
	t.ok(game.hub.action_button("roll").disabled, "dice may be used once per day")
	if not await _move("b_shop"):
		return
	if not await _press(game.hub.action_button("enter"), "enter map shop"):
		return
	t.eq(str(game.host.top_kind()), "map_shop", "shop node uses registered map modal")
	var coins: Dictionary = game.engine.query(&"campaign").get("coins", {}).duplicate(true)
	if not await _press(game.host.top_panel().action_button("activity:merchant"), "buy supplies in the map shop"):
		return
	t.eq(game.engine.query(&"campaign").get("coins", {}).get("gold"), int(coins.get("gold", 0)) - 1, "shop spends one gold")
	t.eq(game.engine.query(&"campaign").get("coins", {}).get("supply"), int(coins.get("supply", 0)) + 2, "shop grants two supplies")
	await _dismiss()


func _test_queries() -> void:
	var before := (game.engine as CardEngine).state_hash()
	var history := (game.engine as CardEngine).command_log()
	var map := game.engine.query(&"campaign.map")
	var original := map.duplicate(true)
	t.no_leaks(map, "public map")
	t.no_leaks(game.engine.query(&"campaign.run"), "public run")
	for frame in map.get("frames", []):
		t.ok(not frame.has("when"), "camera frames hide their rule conditions")
	for node in map.get("nodes", []):
		if str(node.get("type", "")) == "?":
			t.ok(not node.has("event") and not node.has("scene") and not node.has("template"), "fog keeps encounter content private")
	var event := str(map.get("event", ""))
	if event == "": event = str(map.get("interlude", ""))
	if event != "":
		var card := game.engine.query(&"card", {"uid": "event:" + event})
		t.ok(not card.is_empty(), "active map event is available through the card query")
		t.no_leaks(card, "event card")
		card["choices"] = []
	t.eq(game.engine.query(&"card", {"uid": "event:missing"}), {}, "unknown event is not exposed")
	map["nodes"] = []
	if not map.get("hand", []).is_empty():
		map["hand"][0]["effects"]["test_mutation"] = 999
	t.ok(not game.engine.query(&"campaign.map").get("nodes", []).is_empty(), "caller cannot mutate map through its returned dictionary")
	t.eq(game.engine.query(&"campaign.map"), original, "nested march-card data and map rows are detached copies")
	t.eq((game.engine as CardEngine).state_hash(), before, "public queries preserve hash")
	t.eq((game.engine as CardEngine).command_log(), history, "public queries preserve command log")


func _test_reveal_controls() -> void:
	var before := (game.engine as CardEngine).state_hash()
	var preview := ""
	for node in game.engine.query(&"campaign.map", {"reveal": true}).get("nodes", []):
		if bool(node.get("preview_only", false)) and str(node.get("state", "")) == "fog":
			preview = str(node["id"])
			break
	t.ok(preview != "", "chapter two includes a fog node for debug reveal coverage")
	if preview == "": return
	game.hub.reveal_map = true
	game.hub.refresh(game.engine.view())
	game.hub.select_node(preview)
	await t.frames(2)
	t.ok(game.hub.action_button("move").disabled, "debug reveal does not unlock movement into a preview node")
	t.ok(game.hub.action_button("scout").disabled, "debug reveal does not expose scouting controls for preview-only nodes")
	game.hub.reveal_map = false
	game.hub.refresh(game.engine.view())
	game.hub.select_node(str(game.engine.query(&"campaign.map").get("pos", "")))
	t.eq((game.engine as CardEngine).state_hash(), before, "debug reveal remains presentation-only")


func _test_chapter_entry() -> void:
	await _boot("chapters", {"segment": "ocean", "stage": 1})
	t.ok(game.title.has_method("chapter_choices"), "title has the chapter drawer contract")
	if not game.title.has_method("chapter_choices"):
		return
	var rows: Array = game.title.chapter_choices()
	t.ok(rows.any(func(row: Dictionary) -> bool: return str(row.get("segment", "")) == "cristo"), "explicit mini book offers its branch debug entries")
	if not await _press(game.title.find_child("Chapters", true, false) as Button, "open chapter drawer"):
		return
	if not await _press(game.title.chapter_button("cristo", 0), "select the Cristo chapter"):
		return
	if not await _press(game.title.get_node_or_null("new") as Button, "new game with chapter selection"):
		return
	if not await _to_day():
		return
	t.eq(game.engine.query(&"campaign.run").get("segment"), "cristo", "selected title chapter overrides the boot segment")
	t.eq(game.engine.query(&"campaign.map").get("sheet"), "mc_one", "selected chapter opens its map")
	t.eq(root.title, "迷你书", "debug chapter keeps the book's window title")
	await _test_event_appraisal()


func _test_event_appraisal() -> void:
	var uid := "event:ev_mc_weigh"
	var card := game.engine.query(&"card", {"uid": uid})
	t.ok(not card.is_empty(), "Cristo entry offers its authored weighing interlude")
	if card.is_empty(): return
	t.eq(card.get("observations"), [], "event observation stays hidden before appraisal")
	t.ok(not JSON.stringify(card).contains("少了两枚"), "unrevealed observation text is absent from the card query")
	var locked: Array = card.get("choices", []).filter(func(row: Dictionary) -> bool: return str(row.get("id", "")) == "action:map_choose:expose")
	t.ok(locked.size() == 1 and not bool(locked[0].get("enabled", true)), "event choice is locked before its required clue")
	if not locked.is_empty():
		t.eq(locked[0].get("reason"), "missing_clue", "event choice exposes a usable disabled reason")
		t.eq(locked[0].get("needs"), ["action:map_appraise:mc_scale"], "event choice names the public appraisal action")
	if not await _press(game.hub.action_button("interlude"), "open weighing interlude"): return
	if not await _press(game.host.top_panel().action_button("interlude"), "read weighing interlude"): return
	if not await _vn_choice("action:map_appraise:mc_scale"): return
	t.eq(game.engine.query(&"card", {"uid": uid}).get("observations"), ["ocean.event_obs.ev_mc_weigh.mc_scale"], "appraisal unlocks precisely its observation")
	if not await _vn_choice("action:map_choose:expose"): return
	await _clear_overlays()
	t.eq(game.engine.query(&"card", {"uid": uid}), {}, "finished interlude no longer exposes an actionable event card")


func _test_stage_entry() -> void:
	await _boot("stage", {"segment": "ocean", "stage": 1})
	if not await _press(game.title.get_node_or_null("new") as Button, "start directly in ocean chapter two"): return
	if not await _to_day(): return
	t.eq(game.engine.query(&"campaign.run").get("segment"), "ocean", "title preserves the explicit segment")
	t.eq(game.engine.query(&"campaign.map").get("sheet"), "mo_two", "title preserves the explicit nonzero stage")


func _test_art_override() -> void:
	var baseline := VnData.scene("mt_arrive")
	var presentation := {"art": {"hero": "hero_napoleon_trunk"}}
	var staging := VnData.scene("mt_arrive", presentation)
	t.eq(staging.get("art"), presentation["art"], "scene presentation accepts a costume override")
	staging["art"]["hero"] = "changed"
	t.eq(presentation["art"]["hero"], "hero_napoleon_trunk", "staging cannot mutate its supplied presentation")
	t.eq(VnData.scene("mt_arrive"), baseline, "scene override cannot contaminate cached cast data")
	var stage := VnStage.new()
	stage.fast = true
	stage.art_overrides = presentation["art"].duplicate(true)
	root.add_child(stage)
	stage.enter("hero")
	await t.frames(2)
	t.eq(stage.actor_node("hero").get_meta("hd_id", ""), "hero_napoleon_trunk", "VN actor uses the scene-specific art id")
	stage.queue_free()
	await t.frames(2)


## Mini-book sea chapters deliberately use a local canvas. This isolated public-view
## fixture exercises the shipped Natural Earth world renderer without editing gameplay.
func _test_world_renderer() -> void:
	var before := (game.engine as CardEngine).state_hash()
	# Root's map has a positive z-index. A dedicated layer keeps this independent
	# renderer fixture above the live game and makes the screenshot unambiguous.
	var layer := CanvasLayer.new()
	layer.name = "WorldRendererFixture"
	layer.layer = 200
	root.add_child(layer)
	var background := ColorRect.new()
	background.color = Color("252a2c")
	background.size = Vector2(1280, 720)
	layer.add_child(background)
	var caption := Label.new()
	caption.position = Vector2(24, 20)
	caption.text = "Natural Earth world renderer - 2x (presentation fixture)"
	caption.add_theme_font_size_override("font_size", 24)
	layer.add_child(caption)
	var canvas := Canvas.new()
	canvas.position = Vector2(24, 72)
	canvas.size = Vector2(1232, 624)
	layer.add_child(canvas)
	canvas.refresh({"enabled": true, "view": "world", "sheet": "renderer_fixture", "pos": "port",
		"view_def": {"proj": "miller", "base": "world"}, "frames": [],
		"nodes": [{"id": "port", "label": "港口", "geo": [-1000, 3600], "type": "camp", "state": "current"},
			{"id": "island", "label": "远岛", "geo": [-4200, 1000], "type": "story", "state": "open"}],
		"links": [{"a": "port", "b": "island", "state": "open", "voyage_days": 2}], "rivals": []})
	canvas.set_zoom(2.0)
	await t.frames(2)
	t.eq(canvas.get_zoom(), 2.0, "Natural Earth world renderer supports two-times zoom")
	t.eq(canvas.hit_test(canvas.node_screen_position("port")), "port", "projected geographic nodes remain selectable at two-times zoom")
	await _shot("map-world-2x-renderer")
	t.eq((game.engine as CardEngine).state_hash(), before, "world renderer fixture leaves the running campaign untouched")
	layer.queue_free()
	await t.frames(2)


func _take_points() -> bool:
	var map := game.engine.query(&"campaign.map")
	if int(map.get("mp", 0)) > 0:
		return true
	if not bool(map.get("can_roll", false)):
		if not await _press(game.hub.end_button(), "camp for the next march") or not await _to_day():
			return false
		map = game.engine.query(&"campaign.map")
	var best := -1
	var points := 0
	for card in map.get("hand", []):
		if int(card.get("mp", 0)) > points:
			points = int(card["mp"])
			best = int(card["index"])
	return await _press(game.hub.map_hand().action_button(best), "play a march card") if best >= 0 else await _press(game.hub.action_button("roll"), "roll march dice")


func _walk(target: String) -> bool:
	for _i in 25:
		var map := game.engine.query(&"campaign.map")
		if str(map.get("pos", "")) == target:
			game.hub.select_node(target)
			await t.frames(2)
			return true
		var path := Policy.path_to(map, target)
		if path.is_empty():
			t.ok(false, "public route exists to " + target)
			return false
		var next := str(path[0])
		var link := Policy.link_between(map, str(map.get("pos", "")), next)
		if int(map.get("mp", 0)) < int(link.get("legs", 1)):
			if int(map.get("mp", 0)) > 0:
				if not await _press(game.hub.end_button(), "end a march with insufficient points") or not await _to_day(): return false
			if not await _take_points(): return false
		if not await _move(next): return false
	t.ok(false, "movement guard reached for " + target)
	return false


func _move(id: String) -> bool:
	game.hub.select_node(id)
	await t.frames(2)
	if not await _press(game.hub.action_button("move"), "move to " + id): return false
	t.eq(game.engine.query(&"campaign.map").get("pos"), id, "map movement reaches " + id)
	return true


func _vn_choice(id: String) -> bool:
	for _i in 100:
		var panel := game.host.top_panel()
		if panel == null or str(game.host.top_kind()) != "vn":
			t.ok(false, "VN panel exists for " + id)
			return false
		if str(panel.state()) == "choices":
			for button in panel.choice_buttons():
				if str(button.get_meta("reply_id", "")) == id:
					return await _press(button, "VN " + id)
			break
		panel.advance()
		await t.frames(1)
	t.ok(false, "VN exposes " + id)
	return false


func _vn_first_choice() -> bool:
	for _i in 100:
		var panel := game.host.top_panel()
		if panel == null or str(game.host.top_kind()) != "vn":
			t.ok(false, "event opens VN")
			return false
		if str(panel.state()) == "choices":
			for button in panel.choice_buttons():
				if not button.disabled:
					return await _press(button, "event choice")
			break
		panel.advance()
		await t.frames(1)
	t.ok(false, "event VN exposes a usable choice")
	return false


func _resume() -> void:
	var hash_before := (game.engine as CardEngine).state_hash()
	var log_before := (game.engine as CardEngine).command_log()
	var map_before := game.engine.query(&"campaign.map")
	t.ok(FileAccess.file_exists(_dir + "/suspend.json"), "progress produced a continuation save")
	await _dispose()
	await _boot("route")
	if not await _press(game.title.get_node_or_null("continue") as Button, "continue map campaign"): return
	await _clear_overlays()
	t.eq((game.engine as CardEngine).state_hash(), hash_before, "Continue restores exact map campaign state")
	t.eq((game.engine as CardEngine).command_log(), log_before, "Continue restores command history")
	t.eq(game.engine.query(&"campaign.map"), map_before, "Continue restores random slots, march hand and route")
	t.ok(game.hub.get_script().resource_path.ends_with("map/map_panel.gd"), "Continue restores the map screen")


func _to_day() -> bool:
	for _i in 40:
		var panel := game.host.top_panel()
		if str(game.engine.view().get("phase", "")) == "day" and panel == null:
			await t.frames(2)
			return true
		if panel != null:
			if str(game.host.top_kind()) not in ["month_open", "year_jump", "settle", "month_close"]:
				t.ok(false, "unexpected phase panel " + str(game.host.top_kind()))
				return false
			panel.autoplay_step()
		elif game.hub != null:
			if not await _press(game.hub.end_button(), "advance map day"): return false
		await t.frames(2)
	t.ok(false, "map controls advance to day")
	return false


func _clear_overlays() -> void:
	for _i in 30:
		var panel := game.host.top_panel()
		if panel == null: return
		if str(game.host.top_kind()) == "vn" and str(panel.state()) != "choices":
			panel.advance()
		else:
			panel.dismiss()
		await t.frames(2)


func _dismiss() -> void:
	if game.host.top_panel() != null:
		game.host.top_panel().dismiss()
		await t.frames(3)


func _press(button: Button, label: String) -> bool:
	var available := button != null and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
	t.ok(available, label + " is a usable real control")
	if not available: return false
	button.pressed.emit()
	await t.frames(4)
	return true


func _record(cmd: StringName, args: Dictionary, ok: bool) -> void:
	_commands.append([str(cmd), args.duplicate(true), ok])


func _shot(name: String) -> void:
	var directory := OS.get_environment("OCEAN_MAP_SHOTS")
	if directory == "" or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	t.ok(screenshot != null and screenshot.save_png(directory.path_join(name + ".png")) == OK, "capture " + name)


func _dispose() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		game = null
		await t.frames(4)
