# C02 截图（不进清单）：三种尺寸拼表、状态、day_full 牌桌、悬停放大。1280x720。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C02/shot_cards.gd -- --out=<目录>
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
	var rows: Array = S.examples()
	await _sheet(out_dir.path_join("C02_sheet_hand.png"), rows, &"hand", 6, 200, 230)
	await _sheet(out_dir.path_join("C02_sheet_mini.png"), rows, &"mini", 9, 100, 130)
	var zoom_rows: Array = []
	for key in ["gold_person", "person", "life", "kept"]:
		for row in rows:
			if str(row.get("key", "")) == key:
				zoom_rows.append(row)
	await _sheet(out_dir.path_join("C02_sheet_zoom.png"), zoom_rows, &"zoom", 4, 304, 0)
	await _states(out_dir.path_join("C02_states.png"))
	await _hover(out_dir.path_join("C02_hover.png"))
	await _table(out_dir.path_join("C02_day_full.png"))
	CardText.setup(null)
	CardAnchors.clear()
	quit(0)


func _sheet(path: String, rows: Array, mode: StringName, cols: int, pitch_x: int, pitch_y: int) -> void:
	var host := _host()
	var card_size: Vector2 = CardWidget.SIZES[mode]
	var n := rows.size()
	var rows_n := 1 if pitch_y <= 0 else int(ceil(float(n) / float(cols)))
	var grid_w := cols * pitch_x
	var grid_h: float = card_size.y if pitch_y <= 0 else float(rows_n * pitch_y)
	var origin := Vector2((1280.0 - float(grid_w)) / 2.0, maxf(16.0, (720.0 - grid_h) / 2.0))
	for i in n:
		var col := i % cols
		var row_i := int(i) / cols
		var step_y := 0 if pitch_y <= 0 else pitch_y
		var at := origin + Vector2(col * pitch_x, row_i * step_y)
		var view: Dictionary = rows[i]["view"]
		S.mount(self, view, mode, at)
	await _grab(path)
	_free_cards()
	host.queue_free()
	CardAnchors.clear()
	await process_frame


func _states(path: String) -> void:
	var host := _host()
	var states := S.states()
	var keys: Array[String] = ["gold", "must_hand", "expires_1", "life", "away_days", "used_today", "draft", "keep_on"]
	for i in keys.size():
		S.mount(self, states[keys[i]], &"hand", Vector2(24 + i * 156, 240))
	await _grab(path)
	_free_cards()
	host.queue_free()
	CardAnchors.clear()
	await process_frame


func _hover(path: String) -> void:
	var host := _host()
	var view: Dictionary = {}
	for row in S.examples():
		if str(row.get("key", "")) == "gold_person":
			view = row["view"]
	var w := S.mount(self, view, &"hand", Vector2(496, 420))
	await process_frame
	w.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await _grab(path)
	_free_cards()
	host.queue_free()
	CardAnchors.clear()
	await process_frame


func _free_cards() -> void:
	var doomed: Array = []
	for c in root.get_children():
		if c is CardWidget:
			doomed.append(c)
	for c in doomed:
		(c as Node).queue_free()


func _table(path: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load("res://scenes/cards/CardGame.tscn").instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "day_full", "skip_title": true, "guide": "off"})
	root.add_child(game)
	for i in 8:
		await process_frame
	await _grab(path)
	game.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await process_frame


func _host() -> Control:
	var host := Control.new()
	host.position = Vector2.ZERO
	host.size = Vector2(1280, 720)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(host)
	var bg := ColorRect.new()
	bg.color = CardTheme.color(&"wood_dark")
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)
	return host


func _grab(path: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())
