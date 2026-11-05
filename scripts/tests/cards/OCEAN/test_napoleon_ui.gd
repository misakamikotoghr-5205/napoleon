## C3: the real default book, title, Toulon prose/map/battle and save continuation.
## Reuse the ocean acceptance driver's actual battle controls; never edit game state.
extends "res://scripts/tests/cards/OCEAN/test_ui.gd"

var _battle_shot_taken := false
var _formal_policy: Script


func _initialize() -> void:
	_had_campaign = OS.has_environment("DEHOUDANG_CAMPAIGN")
	_old_campaign = OS.get_environment("DEHOUDANG_CAMPAIGN")
	OS.unset_environment("DEHOUDANG_CAMPAIGN")
	t = T.new(self, "OCEAN_napoleon_ui")
	t.run_async(_body)


func _boot() -> void:
	game = load(CardIds.ROOT_SCENE).instantiate() as CardGameRoot
	root.add_child(game)
	await t.frames(2)
	var bus := root.get_node("CardBus") as CardEventBus
	if not bus.command_done.is_connected(_command_done):
		bus.command_done.connect(_command_done)
	# No campaign/book override: this must exercise the real released default.
	game.boot({"mock": false, "bus": bus, "guide": "off", "seed": 1793,
		"save_dir": t.user_dir() + "/saves", "settings_path": t.user_dir() + "/settings.json"})
	game.allow_quit = false
	game.stage.fast = true
	game.host.fast = true
	game.dialog.chars_per_sec = 0
	CardText.set_show_drafts(false)
	await t.frames(3)
	t.eq(CardSave.root(), t.user_dir() + "/saves", "formal UI uses isolated saves")


func _run() -> void:
	await _boot()
	t.ok(game.title != null, "default boot opens the real title")
	if game.title == null:
		return
	t.ok(_visible_text(game.title).contains("鹰旗军需官"), "default title names the formal Napoleon book")
	t.eq(root.title, "鹰旗军需官", "window title names the formal book before New")
	await _shot("00-title")
	var seed := game.title.get_node_or_null("RunBox/Seed") as LineEdit
	t.ok(seed != null, "default title exposes its seed field")
	if seed == null:
		return
	seed.text = "1793"
	if not await _press(game.title.get_node_or_null("new") as Button, "start the real default campaign"):
		return
	t.ok(game.title == null, "formal New closes the title")
	t.eq(game.engine.query(&"campaign.run").get("book"), "napoleon", "default New selects the complete formal book")
	t.eq(game.engine.query(&"campaign.run").get("segment"), "trunk", "default New starts the trunk")
	t.eq(game.engine.query(&"campaign").get("scene_id"), "toulon_arrival", "default New starts authored Toulon prose")
	if not await _advance_to_day():
		return
	t.ok(game.hub != null and game.hub.get_script().resource_path.ends_with("map/map_panel.gd"), "formal book installs the actual map screen")
	if game.hub == null or not game.hub.has_method("map_canvas"):
		return
	t.eq(game.engine.query(&"campaign.map").get("sheet"), "toulon", "formal map starts at Toulon")
	t.eq(game.engine.query(&"campaign.map").get("pos"), "ollioules", "the player starts at the artillery depot")
	if not await _press(game.hub.card_button("story:toulon_arrival"), "open authored Toulon story"):
		return
	t.eq(str(game.host.top_kind()), "vn", "Toulon opens the actual VN")
	var vn := _vn()
	if vn == null:
		return
	vn.call("advance")
	await t.frames(2)
	await _shot("01-toulon-story")
	await _close_play()
	for clue in ["powder_weight", "powder_trail"]:
		if not await _act("story:toulon_arrival", "action:appraise:" + clue):
			return
	if not await _act("story:toulon_arrival", "action:choose:expose_thieves"):
		return
	t.eq(game.engine.query(&"campaign").get("scene_id"), "toulon_mulgrave", "the depot decision advances to the authored assault scene")
	game.hub.fixed_steps().value = 6
	if not await _press(game.hub.action_button("roll_fixed"), "use the starting fixed die for six march points"):
		return
	t.eq(game.engine.query(&"campaign.map").get("mp"), 6, "the fixed die supplies the complete tutorial route")
	if not await _move_to("sans_peur") or not await _move_to("la_seyne"):
		return
	t.eq(game.engine.query(&"campaign.map").get("stamps"), 1, "the artillery post grants its authored stamp")
	if not await _press(game.hub.action_button("muster"), "muster at La Seyne"):
		return
	t.eq(game.engine.query(&"campaign.map").get("mustered"), true, "muster opens the assault route")
	await _shot("02-toulon-map")
	if not await _move_to("dugommier_hq"):
		return
	if not await _press(game.hub.action_button("enter"), "enter Dugommier's council"):
		return
	t.eq(game.engine.query(&"campaign.map").get("event"), "ev_council_toulon", "the council opens its authored event")
	if not await _event_choice("action:map_choose:more_powder"):
		return
	await _close_play()
	t.eq(game.engine.query(&"campaign.map").get("event"), "", "the council decision returns to the map")
	if not await _move_to("caire_foot") or not await _move_to("petit_gibraltar"):
		return
	if not await _fight_battle("story:toulon_mulgrave", "action:choose:credit_captain"):
		return
	t.eq(_battles.size(), 1, "one real battle was played through the controls")
	if not _battles.is_empty():
		t.eq(_battles[0][1], "victory", "the tutorial policy wins Toulon")
	if not await _act("story:toulon_mulgrave", "action:choose:credit_captain"):
		return
	if not await _advance_to_day():
		return
	t.eq(game.engine.query(&"campaign").get("scene_id"), "italy_nice", "the victory continues into the authored Italy chapter")
	t.eq(game.engine.query(&"campaign.map").get("sheet"), "italy", "the next real map replaces Toulon")
	await _shot("04-italy-map")
	await _continue_formal()
	var failed: Array = _commands.filter(func(row: Array) -> bool: return not bool(row[2]))
	t.eq(failed, [], "all commands emitted by the formal UI controls succeeded")
	t.no_leaks(game.engine.view(), "formal UI public view")
	print("NAPOLEON UI assertions=%d commands=%d battle=%s" % [t.checks, _commands.size(), str(_battles)])


func _move_to(id: String) -> bool:
	var canvas: Control = game.hub.map_canvas()
	var point: Vector2 = canvas.node_screen_position(id)
	t.eq(canvas.hit_test(point), id, "the authored node has a selectable map marker: " + id)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.pressed = pressed
		canvas.call("_gui_input", click)
	await t.frames(2)
	t.eq(canvas.selected_node, id, "click selects the authored node: " + id)
	if not await _press(game.hub.action_button("move"), "march to " + id):
		return false
	t.eq(game.engine.query(&"campaign.map").get("pos"), id, "movement reaches " + id)
	return true


func _event_choice(action: String) -> bool:
	for _i in range(120):
		var panel := _vn()
		if panel == null:
			t.ok(false, "the council VN remains available")
			return false
		var button := _reply(action)
		if button != null:
			return await _press(button, "council choice " + action)
		panel.call("advance")
		await t.frames(1)
	t.ok(false, "the council exposes " + action)
	return false


func _open_battle_card() -> bool:
	if not await super._open_battle_card():
		return false
	var candidates: Array = game.engine.query(&"campaign.battle2").get("lineup", {}).get("candidates", [])
	for id in ["baptiste", "corso"]:
		t.ok(candidates.any(func(row: Dictionary) -> bool: return str(row.get("id", "")) == id),
			"the depot story recruited " + id + " into the real lineup")
	return true


func _policy_lineup(lineup: Dictionary) -> Dictionary:
	return _napoleon_policy().lineup(lineup)


func _policy_action(view: Dictionary, preview: Dictionary) -> Array:
	return _napoleon_policy().next_action(view, preview)


func _napoleon_policy() -> Script:
	if _formal_policy == null:
		_formal_policy = load("res://scripts/tests/cards/OCEAN/napoleon_battle_policy.gd")
	return _formal_policy


func _ui_action(panel: CardPanel, view: Dictionary, act: Array) -> bool:
	var args: Dictionary = act[1]
	if str(act[0]) != "card" or not args.has("row"):
		return await super._ui_action(panel, view, act)
	var before := (game.engine as CardEngine).command_log().size()
	if not await _press(panel.find_child("Card_%d" % int(args["index"]), true, false) as Button, "targeted command card"):
		return false
	# Row orders highlight every cell in that row; cell orders select the exact target.
	var cell := "Cell_%d_%d" % [int(args.get("col", 0)), int(args["row"])]
	if not await _press(panel.find_child(cell, true, false) as Button, "command card target"):
		return false
	var log := (game.engine as CardEngine).command_log()
	t.ok(log.size() > before and str(log.back()[0]) == "campaign.battle_cmd"
		and log.back()[1] == {"cmd": "card", "args": args},
		"targeted command card sends its selected row or cell")
	return log.size() > before


func _continue_formal() -> void:
	var before := (game.engine as CardEngine).state_hash()
	var history := (game.engine as CardEngine).command_log()
	var map := game.engine.query(&"campaign.map")
	t.ok(CardSave.exists(CardSave.suspend_path()), "formal progress is autosaved")
	await _dispose_game()
	await _boot()
	if not await _press(game.title.get_node_or_null("continue") as Button, "continue the formal campaign"):
		return
	t.eq((game.engine as CardEngine).state_hash(), before, "Continue restores the exact formal campaign hash")
	t.eq((game.engine as CardEngine).command_log(), history, "Continue restores the exact formal command history")
	t.eq(game.engine.query(&"campaign.map"), map, "Continue restores the real Italy map")
	t.eq(game.engine.query(&"campaign.run").get("book"), "napoleon", "Continue keeps the formal book identity")


func _press(button: Button, context: String) -> bool:
	var ok: bool = await super._press(button, context)
	if ok and context == "march out" and not _battle_shot_taken:
		_battle_shot_taken = true
		await _shot("03-first-battle")
	return ok


func _shot(id: String) -> void:
	var folder := OS.get_environment("OCEAN_NAPOLEON_SHOTS")
	if folder == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(folder)
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	t.eq(picture.save_png(folder.path_join(id + ".png")), OK, "save actual formal UI screenshot " + id)
