# C02 指引截图（不进清单）：每个要证明的步骤亮起时一张 guide_<步骤 id>.png。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C02/shot_guide.gd -- --out=<目录>
extends SceneTree

const S = preload("res://scripts/tests/cards/C02/support.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C02"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	S.setup_db()
	var doc := S.read_json("res://scripts/tests/cards/C02/guide_steps.json")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load("res://scenes/cards/CardGame.tscn").instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "day_full", "skip_title": true, "guide": "off"})
	root.add_child(game)
	var view: Dictionary = {}
	for i in 12:
		await process_frame
		view = game.engine.view()
		if not view.get("hand", []).is_empty():
			break
	game.guide.skip_fades = true
	game.guide.force(true)
	var uids := {
		"gd.d1.person": _uid(view, "person"),
		"gd.d2.gold": _uid(view, "gold"),
		"gd.d2.keep": _uid(view, "news"),
		"gd.kept_expire": "",
		"gd.life": _uid(view, "life"),
		"gd.news": _uid(view, "news"),
		"gd.fate": _uid(view, "fate"),
		"gd.demand_people": "c0097",
		"gd.big_wheel": "c0096",
	}
	var mechs := {
		"gd.d1.person": "person",
		"gd.d2.gold": "gold",
		"gd.d2.keep": "keep",
		"gd.kept_expire": "kept_expire",
		"gd.life": "life",
		"gd.news": "news",
		"gd.fate": "fate",
		"gd.demand_people": "demand_people_return",
		"gd.big_wheel": "big_wheel",
	}
	var ret_w: CardWidget = null
	var wheel_w: CardWidget = null
	for step in doc.get("steps", []):
		var step_id := str(step.get("id", ""))
		if step_id == "gd.demand_people" and ret_w == null:
			var ret := _example("demand_return")
			ret["uid"] = "c0097"
			ret_w = S.mount(self, ret, &"hand", Vector2(400, 90))
			await process_frame
		if step_id == "gd.big_wheel" and wheel_w == null:
			var wheel := _example("big_fate")
			wheel["uid"] = "c0096"
			wheel_w = S.mount(self, wheel, &"hand", Vector2(700, 90))
			await process_frame
		game.guide.load_steps({"steps": [step], "settings": doc.get("settings", {})})
		var args := {}
		var uid := str(uids.get(step_id, ""))
		if uid != "":
			args["uid"] = uid
		bus.first_time.emit(StringName(str(mechs.get(step_id, ""))), args)
		game.guide.evaluate_now()
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_viewport().get_texture().get_image()
		var path := out_dir.path_join("guide_%s.png" % step_id)
		img.save_png(path)
		print("SHOT ", path, " ", img.get_width(), "x", img.get_height(), " step ", game.guide.active_step())
		bus.ui_event.emit(&"card_zoomed", {"uid": "shot"})
		await process_frame
		if step_id == "gd.demand_people" and ret_w != null:
			ret_w.queue_free()
			ret_w = null
			await process_frame
	game.queue_free()
	bus.queue_free()
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)


func _example(key: String) -> Dictionary:
	for row in S.examples():
		if str(row.get("key", "")) == key:
			return (row["view"] as Dictionary).duplicate(true)
	return {}


func _uid(view: Dictionary, kind: String) -> String:
	for zone in ["hand", "kept", "contacts", "demands"]:
		for c in view.get(zone, []):
			var typ := str(c.get("type", ""))
			var gold := bool(c.get("gold", false))
			if kind == "gold" and gold:
				return str(c.get("uid", ""))
			if kind == "person" and typ == "person" and not gold:
				return str(c.get("uid", ""))
			if kind == typ:
				return str(c.get("uid", ""))
	return ""
