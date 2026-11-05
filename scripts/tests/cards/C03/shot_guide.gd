# C03 guide screenshots, one png per step (not in the suite).
extends SceneTree

const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const STEPS := "res://scripts/tests/cards/C03/guide_steps.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C03"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr("--out=".length())
	DirAccess.make_dir_recursive_absolute(out_dir)
	var data = CardDB.read_json(STEPS)
	await _one(out_dir, data, "gd.slots", "event_slots", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0003"}, "slots")
	await _one(out_dir, data, "gd.coins", "event_slots", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0003"}, "coins")
	await _one(out_dir, data, "gd.choice", "fate_choices", "res://scenes/cards/slots/SlotPanel.tscn", {"uid": "c0004"}, "choice")
	await _one(out_dir, data, "gd.contacts_full", "contacts_full", "res://scenes/cards/slots/ContactsFull.tscn", {"new_uid": "c0099"}, "contacts_full")
	await _one(out_dir, data, "gd.kept_full", "kept_full", "res://scenes/cards/slots/KeptFull.tscn", {"new_uid": "c0088"}, "kept_full")
	quit(0)


func _one(out_dir: String, data: Dictionary, step: String, fx: String, scene: String, args: Dictionary, mech: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture("res://scripts/tests/cards/C03/fixtures/%s.json" % fx)
	var panel := (load(scene) as PackedScene).instantiate() as CardPanel
	panel.bind(mock, bus)
	root.add_child(panel)
	panel.open(args)
	var guide: CardGuide = (load(GUIDE) as PackedScene).instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(data)
	for _i in 3:
		await process_frame
	bus.first_time.emit(StringName(mech), {"uid": str(args.get("uid", args.get("new_uid", "")))})
	guide.evaluate_now()
	for _i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("guide_" + step + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path, " step ", guide.active_step())
	guide.queue_free()
	panel.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await process_frame
