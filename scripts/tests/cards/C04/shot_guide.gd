# C04 guide screenshots (not in the suite). One PNG per step: guide_<step id>.png
extends SceneTree

const S = preload("res://scripts/tests/cards/C04/support.gd")
const STEPS := "res://scripts/tests/cards/C04/guide_steps.json"
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const TABLE := "res://scenes/cards/table/CardTable.tscn"


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C04"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _step_counter(out_dir, "pawn", "c0002", &"counter", "gd.d1.look", "")
	await _step_counter(out_dir, "pawn", "c0002", &"counter", "gd.d1.tiers", "look")
	await _step_counter(out_dir, "buy", "c0004", &"buyer", "gd.d1.buyer", "")
	await _step_counter(out_dir, "redeem_by_rule", "c0008", &"redeem", "gd.redeem", "")
	await _step_ticket(out_dir)
	quit(0)


func _step_counter(out_dir: String, fx: String, uid: String, mech: StringName, step: String, prep: String) -> void:
	var ctx: Dictionary = S.boot(self, fx)
	var panel: CardCounterPanel = ctx.panel
	var guide := _guide(ctx.mock, ctx.bus)
	panel.open({"uid": uid})
	await _frames(3)
	if prep == "look":
		ctx.bus.first_time.emit(&"counter", {"uid": uid})
		guide.evaluate_now()
		S.button(panel, "LookButton").pressed.emit()
		await _frames(2)
		guide.evaluate_now()
	else:
		ctx.bus.first_time.emit(mech, {"uid": uid})
		guide.evaluate_now()
	await _frames(2)
	await _save(out_dir, "guide_%s.png" % step)
	S.free_all([guide, panel, ctx.bus])
	CardAnchors.clear()
	await _frames(2)


func _step_ticket(out_dir: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(S.path("pawn"))
	var table: Control = load(TABLE).instantiate()
	table.bus = bus
	root.add_child(table)
	await _frames(2)
	table.refresh({
		"phase": "day", "mode": "shop",
		"date": {"y": 1938, "m": 3, "d": 2, "abs_day": 1},
		"notice": {"weather": "clear", "news": [], "almanac": {}},
		"money": {"amount": 340}, "rep_tier": 0, "heat_tier": 0,
		"tickets": [{"no": 1}], "hand": [], "contacts": [], "kept": [], "demands": [],
	})
	var guide := _guide(mock, bus)
	await _frames(2)
	bus.first_time.emit(&"ticket", {"no": 1})
	guide.evaluate_now()
	await _frames(2)
	await _save(out_dir, "guide_gd.d1.ticket.png")
	S.free_all([guide, table, bus])
	await _frames(1)


func _guide(mock: MockCardEngine, bus: CardEventBus) -> CardGuide:
	var guide: CardGuide = load(GUIDE).instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(CardDB.read_json(STEPS))
	return guide


func _save(dir_path: String, file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := dir_path.path_join(file_name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
