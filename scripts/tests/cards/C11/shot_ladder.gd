# C11 screenshots (not in the suite). 1280x720.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C11/shot_ladder.gd -- --out=/tmp/shots/C11
extends SceneTree

const Support = preload("res://scripts/tests/cards/C11/support.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C11"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _panel(bus, "EstatePanel", "estates", {}, "estates.png", out_dir)
	await _panel(bus, "ShortPanel", "short_all", {}, "short_all.png", out_dir)
	await _panel(bus, "ShortPanel", "short_default_only", {}, "short_default.png", out_dir)
	await _street(bus, out_dir)
	await _prison(bus, out_dir)
	await _prison_days(bus, out_dir)
	bus.queue_free()
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)


func _panel(bus: CardEventBus, scene_name: String, fixture: String, args: Dictionary, file_name: String,
		out_dir: String) -> void:
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path(fixture))
	var panel: CardPanel = load("res://scenes/cards/ladder/%s.tscn" % scene_name).instantiate()
	panel.bind(mock, bus)
	root.add_child(panel)
	panel.open(args if not args.is_empty() else {})
	await _shot(out_dir.path_join(file_name))
	panel.queue_free()
	CardAnchors.clear()
	await process_frame


func _street(bus: CardEventBus, out_dir: String) -> void:
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("street"))
	var game := (load(CardIds.ROOT_SCENE) as PackedScene).instantiate() as CardGameRoot
	game.boot({"mock": true, "bus": bus, "fixture": Support.path("street"), "skip_title": true, "guide": "off"})
	root.add_child(game)
	for i in 4:
		await process_frame
	await _shot(out_dir.path_join("street.png"))
	game.queue_free()
	CardAnchors.clear()
	await process_frame


func _prison(bus: CardEventBus, out_dir: String) -> void:
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("prison"))
	var panel := (load("res://scenes/cards/ladder/PrisonPanel.tscn") as PackedScene).instantiate() as CardPrisonPanel
	var rig := Support.mount_stage(root, panel, mock, bus)
	panel.open({"uid": "c0015"})
	for i in 2:
		await process_frame
	await _shot(out_dir.path_join("prison_empty.png"))
	panel.on_reply("try")
	await process_frame
	var slots := Support.widgets(rig["checks"])
	if slots.size() >= 3:
		(slots[0] as CardSlotWidget).place_requested.emit("bribe", {"kind": "money", "amount": 40})
		(slots[1] as CardSlotWidget).place_requested.emit("bail", {"kind": "contact", "uid": "c0013"})
		(slots[2] as CardSlotWidget).place_requested.emit("favor", {"kind": "kept", "uid": "c0012"})
	await process_frame
	await _shot(out_dir.path_join("prison_placed.png"))
	panel.on_reply("roll")
	for i in 3:
		await process_frame
	await _shot(out_dir.path_join("prison_rolled.png"))
	for node in [panel, rig["stage"], rig["dialog"], rig["checks"], rig["hand"]]:
		node.queue_free()
	CardAnchors.clear()
	await process_frame


func _prison_days(bus: CardEventBus, out_dir: String) -> void:
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("prison_stay"))
	var panel := (load("res://scenes/cards/ladder/PrisonPanel.tscn") as PackedScene).instantiate() as CardPrisonPanel
	var rig := Support.mount_stage(root, panel, mock, bus)
	panel.open({"uid": "c0015"})
	for i in 2:
		await process_frame
	await _shot(out_dir.path_join("prison_days.png"))
	for node in [panel, rig["stage"], rig["dialog"], rig["checks"], rig["hand"]]:
		node.queue_free()
	CardAnchors.clear()
	await process_frame


func _shot(path: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)
