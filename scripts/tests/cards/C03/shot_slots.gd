# C03 screenshots (not in the suite). 1280x720.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C03/shot_slots.gd -- --out=/tmp/shots/C03
extends SceneTree

const PANEL := "res://scenes/cards/slots/SlotPanel.tscn"
const FIXTURES: Array[String] = ["event_slots", "fate_choices", "gold_story", "slot_reject", "read_news",
	"read_ticket", "contacts_full", "kept_full", "roll_fail"]


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C03"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr("--out=".length())
	DirAccess.make_dir_recursive_absolute(out_dir)
	for name in FIXTURES:
		var panel := await _open(name, _args_for(name))
		await _shot(out_dir, "C03_" + name)
		if name == "event_slots" and panel is CardSlotPanel:
			(panel as CardSlotPanel).on_reply("roll")
			await process_frame
			await process_frame
			await _shot(out_dir, "C03_toss_mid")
			var toss: CardCoinTossView = panel.find_child("CoinToss", true, false)
			if toss != null and toss.is_playing():
				toss.skip()
			if (panel as CardSlotPanel).dialog != null and not (panel as CardSlotPanel).dialog.is_idle():
				(panel as CardSlotPanel).dialog.skip()
			await process_frame
			await _shot(out_dir, "C03_toss_end")
		await _free(panel)
	quit(0)


func _args_for(name: String) -> Dictionary:
	if name == "contacts_full":
		return {"new_uid": "c0099"}
	if name == "kept_full":
		return {"new_uid": "c0088"}
	if name == "read_news":
		return {"uid": "c0031", "mode": "read"}
	if name == "read_ticket":
		return {"uid": "c0032", "mode": "read"}
	if name == "fate_choices":
		return {"uid": "c0004"}
	if name == "gold_story":
		return {"uid": "c0002"}
	if name == "slot_reject":
		return {"uid": "c0200"}
	return {"uid": "c0003"}


func _open(fx: String, args: Dictionary) -> Control:
	var bus := CardEventBus.new()
	bus.name = "ShotBus"
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture("res://scripts/tests/cards/C03/fixtures/%s.json" % fx)
	var scene := PANEL
	if fx == "contacts_full":
		scene = "res://scenes/cards/slots/ContactsFull.tscn"
	elif fx == "kept_full":
		scene = "res://scenes/cards/slots/KeptFull.tscn"
	var panel := (load(scene) as PackedScene).instantiate() as CardPanel
	panel.bind(mock, bus)
	root.add_child(panel)
	panel.open(args)
	for _i in 4:
		await process_frame
	return panel


func _shot(out_dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join(file_name + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _free(panel: Node) -> void:
	var bus := root.get_node_or_null("ShotBus")
	panel.queue_free()
	if bus != null:
		bus.queue_free()
	CardAnchors.clear()
	await process_frame
