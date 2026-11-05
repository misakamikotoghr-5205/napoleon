# C06 截图（不进清单）：空香案、放香变宽、转动中、揭晓、大轮盘、庙会、赌摊。1280x720。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C06/shot_wheel.gd -- --out=/tmp/shots/C06
extends SceneTree

const S = preload("res://scripts/tests/cards/C06/support.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C06"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _shot_month(out_dir)
	await _shot_kind(out_dir, "big", "big.png")
	await _shot_kind(out_dir, "fair", "fair.png")
	await _shot_gamble(out_dir)
	quit(0)


func _shot_month(out_dir: String) -> void:
	var fix := S.read_fix("month_widen")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := Widen.new(bus)
	mock.widened = (fix.get("widen_to", {}) as Dictionary).duplicate(true)
	mock.load_fixture(S.FIX + "month_widen.json")
	var panel := S.open_panel(self, mock, bus, S.args_of(fix))
	await _frame(4)
	await _save(out_dir, "month_empty.png")
	S.press(panel, "Offer")
	await _frame(20)
	await _save(out_dir, "month_incense.png")
	S.press(panel, "Spin")
	await _frame(8)
	await _save(out_dir, "month_spin.png")
	for i in 40:
		await process_frame
		var reveal := panel.find_child("RevealTitle", true, false) as Label
		if reveal != null and reveal.visible:
			break
	await _save(out_dir, "month_reveal.png")
	panel.queue_free()
	bus.queue_free()
	await process_frame


func _shot_kind(out_dir: String, name: String, file_name: String) -> void:
	var fix := S.read_fix(name)
	var pack := S.boot(self)
	var mock: MockCardEngine = pack["mock"]
	mock.load_fixture(S.FIX + name + ".json")
	var panel := S.open_panel(self, mock, pack["bus"], S.args_of(fix))
	panel.fast_anim = true
	await _frame(3)
	S.press(panel, "Spin")
	await _frame(3)
	await _save(out_dir, file_name)
	panel.queue_free()
	(pack["bus"] as Node).queue_free()
	await process_frame


func _shot_gamble(out_dir: String) -> void:
	var fix := S.read_fix("gamble_stake")
	var pack := S.boot(self)
	var mock: MockCardEngine = pack["mock"]
	mock.load_fixture(S.FIX + "gamble_stake.json")
	var panel := S.open_panel(self, mock, pack["bus"], S.args_of(fix))
	await _frame(4)
	await _save(out_dir, "gamble.png")
	panel.queue_free()
	(pack["bus"] as Node).queue_free()
	await process_frame


func _frame(n: int) -> void:
	for i in n:
		await process_frame


func _save(dir: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir.path_join(file_name)
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)


class Widen extends MockCardEngine:
	var widened: Dictionary = {}
	var armed: bool = false

	func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
		if str(cmd) == "wheel.offer":
			armed = true
		return super.send(cmd, args)

	func query(q: StringName, args: Dictionary = {}) -> Dictionary:
		if armed and q == &"wheel" and not widened.is_empty():
			return widened.duplicate(true)
		return super.query(q, args)
