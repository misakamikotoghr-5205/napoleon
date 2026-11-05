# C05 截图（不进清单）：条子抽屉、墙上的条子热点、四类那一出、讲价格子、拖一拖、没办成。1280x720。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#   -s res://scripts/tests/cards/C05/shot_demand.gd -- --out=/tmp/shots/C05
extends SceneTree

const S = preload("res://scripts/tests/cards/C05/support.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := ProjectSettings.globalize_path("res://scripts/tests/cards/C05/shots")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _drawer(bus, out_dir)
	await _panel(bus, out_dir, "money.json", "m_pay", "panel_money.png", true)
	await _panel(bus, out_dir, "goods.json", "g_pay", "panel_goods.png", false)
	await _panel(bus, out_dir, "people.json", "p_sub", "panel_people.png", false)
	await _panel(bus, out_dir, "info.json", "i_inform", "panel_info.png", false)
	await _haggle(bus, out_dir)
	await _delay(bus, out_dir)
	await _fail(bus, out_dir)
	bus.queue_free()
	CardAnchors.clear()
	CardText.setup(null)
	await process_frame
	quit(0)


func _boot(bus: CardEventBus, fixture: String) -> CardGameRoot:
	var game := S.boot(self, bus, fixture)
	for i in 6:
		await process_frame
	return game


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())


func _drop(game: Node) -> void:
	game.queue_free()
	CardAnchors.clear()
	await process_frame


func _drawer(bus: CardEventBus, out_dir: String) -> void:
	var game := await _boot(bus, "board_three.json")
	game.host.open_panel(&"demands", {})
	for i in 3:
		await process_frame
	await _shot(out_dir.path_join("drawer.png"))
	await _drop(game)


func _panel(bus: CardEventBus, out_dir: String, fixture: String, uid: String, file: String, hotspot: bool) -> void:
	var game := await _boot(bus, fixture)
	game.host.open_panel(&"demand", {"uid": uid})
	for i in 3:
		await process_frame
	if hotspot:
		await _shot(out_dir.path_join("hotspot.png"))
	var panel := game.host.top_panel() as CardDemandPanel
	S.skip_dialog(panel)
	for i in 2:
		await process_frame
	await _shot(out_dir.path_join(file))
	await _drop(game)


func _haggle(bus: CardEventBus, out_dir: String) -> void:
	var game := await _boot(bus, "money.json")
	game.host.open_panel(&"demand", {"uid": "m_haggle"})
	for i in 2:
		await process_frame
	var panel := game.host.top_panel() as CardDemandPanel
	S.skip_dialog(panel)
	await process_frame
	var btn := S.reply_button(panel, "c05.mode.haggle")
	if btn != null:
		btn.pressed.emit()
	await process_frame
	var widget := S.slot_widget(panel, "favor")
	if widget != null:
		widget._drop_data(Vector2.ZERO, {"kind": "card", "uid": "k1", "zone": "kept"})
	for i in 2:
		await process_frame
	await _shot(out_dir.path_join("haggle_slots.png"))
	var submit := S.reply_button(panel, "c05.reply.submit")
	if submit != null:
		submit.pressed.emit()
	await process_frame
	var toss := panel.find_child("CoinToss", true, false) as CardCoinTossView
	if toss != null and toss._playing:
		await _shot(out_dir.path_join("haggle_toss.png"))
	await _drop(game)


func _delay(bus: CardEventBus, out_dir: String) -> void:
	var game := await _boot(bus, "delay.json")
	game.host.open_panel(&"demand", {"uid": "d1"})
	for i in 2:
		await process_frame
	var panel := game.host.top_panel() as CardDemandPanel
	S.skip_dialog(panel)
	await process_frame
	var btn := S.reply_button(panel, "c05.reply.delay")
	if btn != null:
		btn.pressed.emit()
	for i in 2:
		await process_frame
	await _shot(out_dir.path_join("delay.png"))
	await _drop(game)


func _fail(bus: CardEventBus, out_dir: String) -> void:
	var game := await _boot(bus, "fail.json")
	game.host.open_panel(&"demand", {"uid": "f1"})
	for i in 2:
		await process_frame
	var panel := game.host.top_panel() as CardDemandPanel
	S.skip_dialog(panel)
	await process_frame
	var btn := S.reply_button(panel, "c05.mode.haggle")
	if btn != null:
		btn.pressed.emit()
	await process_frame
	var submit := S.reply_button(panel, "c05.reply.submit")
	if submit != null:
		submit.pressed.emit()
	await process_frame
	var toss := panel.find_child("CoinToss", true, false) as CardCoinTossView
	if toss != null and toss._playing:
		toss.skip()
	for i in 3:
		await process_frame
	await _shot(out_dir.path_join("fail.png"))
	await _drop(game)
