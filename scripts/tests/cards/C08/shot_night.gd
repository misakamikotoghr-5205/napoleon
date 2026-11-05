# C08 screenshots (not in the suite): end-day list, gold, prison, night fan, dinner replies, candle, settle.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#   -s res://scripts/tests/cards/C08/shot_night.gd -- --out=res://scripts/tests/cards/C08/shots
# Owner C08.
extends SceneTree

const Support = preload("res://scripts/tests/cards/C08/support.gd")


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "res://scripts/tests/cards/C08/shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	var abs := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	await _panel(abs, host, mock, "end_day_items", &"end_day", {}, "end_day_items")
	await _panel(abs, host, mock, "end_day_gold", &"end_day", {}, "end_day_gold")
	await _panel(abs, host, mock, "end_day_prison", &"end_day", {}, "end_day_prison")
	await _panel(abs, host, mock, "end_day_prison_fail", &"end_day", {}, "end_day_prison_fail")
	await _panel(abs, host, mock, "night", &"night", {}, "night_fan")
	mock.load_fixture(Support.fixture("night_choices"))
	var night := host.open_panel(&"night", {})
	await process_frame
	await process_frame
	Support.play_hand(Support.offers(night)[0])
	await _shot(abs, "night_choices")
	host.close_top()
	await process_frame
	mock.load_fixture(Support.fixture("night_candle"))
	var candle := host.open_panel(&"night", {})
	await process_frame
	await process_frame
	Support.play_hand(Support.offers(candle)[0])
	await _shot(abs, "night_candle")
	host.close_top()
	await process_frame
	mock.load_fixture(Support.fixture("settle_lines"))
	var settle := host.open_panel(&"settle", {}) as CardSettlePanel
	var half := Time.get_ticks_msec()
	while Time.get_ticks_msec() - half < 1200:
		await process_frame
	await _shot(abs, "settle_half")
	settle._reveal_all()
	await _shot(abs, "settle_full")
	host.queue_free()
	bus.queue_free()
	await process_frame
	quit(0)


func _panel(abs: String, host: CardModalHost, mock: MockCardEngine, fixture: String, kind: StringName,
		args: Dictionary, name: String) -> void:
	mock.load_fixture(Support.fixture(fixture))
	host.open_panel(kind, args)
	await _shot(abs, name)
	host.close_top()
	await process_frame


func _shot(abs: String, name: String) -> void:
	for _i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var path := abs.path_join(name + ".png")
	var image := root.get_viewport().get_texture().get_image()
	image.save_png(path)
	print("SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])
