# C11 guide screenshots, one file per step: guide_<step id>.png. Not in the suite.
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
	var steps: Dictionary = CardDB.read_json(Support.STEPS)
	await _mortgage(steps, out_dir)
	await _short(steps, out_dir)
	await _street(steps, out_dir)
	await _prison(steps, out_dir)
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)


func _mortgage(steps: Dictionary, out_dir: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("estates"))
	var guide := _guide(mock, bus, steps)
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	host.open_panel(&"estates", {})
	for i in 2:
		await process_frame
	bus.first_time.emit(&"mortgage", {})
	guide.evaluate_now()
	await _shot(guide, "gd.mortgage", out_dir)
	await _free([host, guide, bus])


func _short(steps: Dictionary, out_dir: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("short_all"))
	var guide := _guide(mock, bus, steps)
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	host.open_panel(&"short", {})
	for i in 2:
		await process_frame
	bus.first_time.emit(&"money_short", {})
	guide.evaluate_now()
	await _shot(guide, "gd.money_short", out_dir)
	await _free([host, guide, bus])


func _street(steps: Dictionary, out_dir: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("street"))
	var game := (load(CardIds.ROOT_SCENE) as PackedScene).instantiate() as CardGameRoot
	game.boot({"mock": true, "bus": bus, "fixture": Support.path("street"), "skip_title": true, "guide": "off"})
	root.add_child(game)
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps(steps)
	for i in 4:
		await process_frame
	bus.first_time.emit(&"street", {})
	game.guide.evaluate_now()
	await _shot(game.guide, "gd.street", out_dir)
	await _free([game, bus])


func _prison(steps: Dictionary, out_dir: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(Support.path("prison"))
	var guide := _guide(mock, bus, steps)
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	var panel := host.open_panel(&"prison", {"uid": "c0015"})
	var rig := Support.mount_stage(root, panel, mock, bus)
	panel.open({"uid": "c0015"})
	(panel as CardPrisonPanel).on_reply("try")
	for i in 2:
		await process_frame
	bus.first_time.emit(&"prison", {"uid": "c0015"})
	guide.evaluate_now()
	await _shot(guide, "gd.prison", out_dir)
	await _free([host, guide, bus])


func _guide(mock: MockCardEngine, bus: CardEventBus, steps: Dictionary) -> CardGuide:
	var g := CardGuide.new()
	root.add_child(g)
	g.bind(mock, bus)
	g.force(true)
	g.skip_fades = true
	g.load_steps(steps)
	return g


func _shot(guide: CardGuide, id: String, out_dir: String) -> void:
	if guide.active_step() != id:
		push_error("guide step %s did not light (got %s)" % [id, guide.active_step()])
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("guide_%s.png" % id)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _free(nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n) and n is Node:
			(n as Node).queue_free()
	CardAnchors.clear()
	await process_frame
