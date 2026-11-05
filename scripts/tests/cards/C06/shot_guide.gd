# C06 指引截图（不进清单）：每个测试步骤一张 guide_<步骤 id>.png。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C06/shot_guide.gd -- --out=/tmp/shots/C06
extends SceneTree

const S = preload("res://scripts/tests/cards/C06/support.gd")
const STEPS := "res://scripts/tests/cards/C06/guide_steps.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C06"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var pack := S.boot(self)
	var mock: MockCardEngine = pack["mock"]
	var bus: CardEventBus = pack["bus"]
	mock.load_fixture(S.FIX + "month_widen.json")
	var panel := S.open_panel(self, mock, bus, S.args_of(S.read_fix("month_widen")))
	var card := ColorRect.new()
	card.color = CardTheme.color(&"paper")
	card.position = Vector2(24, 24)
	card.size = Vector2(96, 120)
	root.add_child(card)
	CardAnchors.register(&"a.card@c0099", card)
	var data = CardDB.read_json(STEPS)
	var guide := CardGuide.new()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.load_steps(data)
	guide.force(true)
	guide.skip_fades = true
	for i in 3:
		await process_frame
	bus.first_time.emit(&"month_wheel", {})
	guide.evaluate_now()
	await _save(out_dir, "guide_gd.m.wheel.png")
	guide.tick(1.0)
	guide.evaluate_now()
	await _save(out_dir, "guide_gd.m.incense.png")
	var slot := panel.find_child("IncenseSlot", true, false) as CardSlotWidget
	slot._drop_data(Vector2.ZERO, {"kind": "money", "amount": 10})
	guide.evaluate_now()
	bus.first_time.emit(&"big_wheel", {"uid": "c0099"})
	guide.evaluate_now()
	await _save(out_dir, "guide_gd.big_wheel.png")
	guide.tick(1.0)
	guide.evaluate_now()
	bus.first_time.emit(&"fair_wheel", {})
	guide.evaluate_now()
	await _save(out_dir, "guide_gd.fair_wheel.png")
	guide.tick(1.0)
	guide.evaluate_now()
	bus.first_time.emit(&"gamble_wheel", {})
	guide.evaluate_now()
	await _save(out_dir, "guide_gd.gamble_wheel.png")
	quit(0)


func _save(dir: String, file_name: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := dir.path_join(file_name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)
