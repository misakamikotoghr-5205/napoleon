# K16 screenshots (not in the suite): every guide step that is not in _test.d1_3.
# One step at a time, trigger cleared, closest W0 fixture, panel opened when the anchor lives there.
# Steps whose anchor is not registered are printed as UNSHOT (minigames, branch list).
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/K16/shot_all_steps.gd -- --out=scripts/tests/cards/K16/shots/rest
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("user://shots/K16_rest")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var raw: Dictionary = CardDB.read_json("res://data/cards/guide/steps.json")
	var early: Dictionary = {}
	for id in raw.get("_test", {}).get("d1_3", []):
		early[str(id)] = true
	var bus := CardEventBus.new()
	root.add_child(bus)
	var shot := 0
	var missed := 0
	for row in raw.get("cards", []):
		var id := str(row.get("id", ""))
		if early.has(id):
			continue
		var ok: bool = await _one(bus, row, out_dir)
		if ok:
			shot += 1
		else:
			missed += 1
	print("SHOT_COUNT %d UNSHOT_COUNT %d" % [shot, missed])
	bus.queue_free()
	await process_frame
	quit(0)


func _one(bus: CardEventBus, row: Dictionary, out_dir: String) -> bool:
	var id := str(row.get("id", ""))
	var anchor := str(row.get("anchor", ""))
	var place: PackedStringArray = _place(anchor)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": place[0], "skip_title": true, "guide": "on"})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	for _i in 3:
		await process_frame
	var uid := _hand_uid(game)
	if place[1] != "":
		game.host.open_panel(StringName(place[1]), {"uid": uid, "wheel": "wh.month"})
		for _j in 2:
			await process_frame
	var step: Dictionary = row.duplicate(true)
	step["trigger"] = {}
	step["anchor"] = str(step.get("anchor", "")).replace("{uid}", uid)
	step["anchor_fallback"] = str(step.get("anchor_fallback", "")).replace("{uid}", uid)
	var settings: Dictionary = game.engine.query(&"guide_data").get("settings", {})
	game.guide.load_steps({"steps": [step], "pages": [], "settings": settings})
	game.guide.shown_log = PackedStringArray()
	game.guide.evaluate_now()
	await RenderingServer.frame_post_draw
	var shown := game.guide.active_step() == id
	if shown:
		var img := root.get_viewport().get_texture().get_image()
		if img != null and img.get_width() > 1:
			img.save_png(out_dir.path_join("%s.png" % id))
			print("SHOT %s via %s/%s" % [id, place[0], place[1]])
		else:
			shown = false
			print("UNSHOT %s empty viewport" % id)
	else:
		print("UNSHOT %s anchor %s not registered on %s panel %s" % [id, anchor, place[0], place[1]])
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	return shown


func _hand_uid(game: CardGameRoot) -> String:
	var hand: Array = game.engine.view().get("hand", [])
	if hand.is_empty():
		return "c0001"
	return str(hand[0].get("uid", "c0001"))


func _place(anchor: String) -> PackedStringArray:
	if anchor.begins_with("a.month"):
		return PackedStringArray(["month_open", "month_open"])
	if anchor.begins_with("a.wheel"):
		return PackedStringArray(["month_wheel", "wheel"])
	if anchor.begins_with("a.counter"):
		return PackedStringArray(["day_counter", "counter"])
	if anchor.begins_with("a.slots"):
		return PackedStringArray(["day_full", "slots"])
	if anchor.begins_with("a.night"):
		return PackedStringArray(["night", "night"])
	if anchor.begins_with("a.endday"):
		return PackedStringArray(["day_full", "end_day"])
	if anchor.begins_with("a.settle"):
		return PackedStringArray(["settle", "settle"])
	if anchor.begins_with("a.mclose"):
		return PackedStringArray(["month_close", "month_close"])
	if anchor.begins_with("a.year"):
		return PackedStringArray(["year_jump", "year_jump"])
	if anchor.begins_with("a.fortune"):
		return PackedStringArray(["day_full", "fortune"])
	if anchor.begins_with("a.demand"):
		return PackedStringArray(["day_full", "demand"])
	if anchor.begins_with("a.dossier"):
		return PackedStringArray(["day_full", "dossier"])
	if anchor.begins_with("a.help"):
		return PackedStringArray(["day_full", "help"])
	if anchor.begins_with("a.estate"):
		return PackedStringArray(["day_full", "estates"])
	if anchor.begins_with("a.short"):
		return PackedStringArray(["day_full", "short"])
	if anchor.begins_with("a.prison"):
		return PackedStringArray(["street_prison", "prison"])
	if anchor.begins_with("a.street"):
		return PackedStringArray(["street_prison", ""])
	if anchor.begins_with("a.over"):
		return PackedStringArray(["month_close", "game_over"])
	if anchor.begins_with("a.pause"):
		return PackedStringArray(["day_full", "pause"])
	if anchor.begins_with("a.settings"):
		return PackedStringArray(["day_full", "settings"])
	return PackedStringArray(["day_full", ""])
