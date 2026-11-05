# C14 screenshots (not in the suite): dengzi opening, beam tilted, level (needle centred), stars read with a
# call picked, the steelyard with rice, and gd.mg.weigh lit.
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C14/shot_weigh.gd -- --out=/tmp/shots/C14
extends SceneTree

const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")

var fix
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const STEPS := "res://scripts/tests/cards/C14/guide_steps.json"


func _initialize() -> void:
	_run()


func _run() -> void:
	var out_dir := "/tmp/shots/C14"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)
	fix = Fix.new()
	fix.setup_text()
	var holder := Control.new()
	holder.theme = CardTheme.build_theme()
	holder.size = Vector2(1280, 720)
	root.add_child(holder)
	var pars: Dictionary = fix.params("light_small")
	var game: Variant = (load(Fix.SCENE) as PackedScene).instantiate()
	holder.add_child(game)
	game.start(pars)
	game._beam.set("fast", true)
	game._refresh(false)
	await _settle()
	await _shot(out_dir, "dengzi_open")
	_clear_scale(game)
	await _settle()
	await _shot(out_dir, "dengzi_tilt")
	fix.level_ops(game)
	await _settle()
	await _shot(out_dir, "dengzi_level")
	game.apply_op(["commit"])
	game.apply_op(["call", 2])
	await _settle()
	await _shot(out_dir, "dengzi_read")
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	var rice: Variant = (load(Fix.SCENE) as PackedScene).instantiate()
	holder.add_child(rice)
	rice.start(fix.params("steelyard_rice"))
	rice._refresh(false)
	await _settle()
	await _shot(out_dir, "steelyard_rice")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var guide: CardGuide = load(GUIDE).instantiate()
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(CardDB.read_json(STEPS))
	await _settle()
	bus.first_time.emit(&"mg.weigh", {"uid": "c0014"})
	guide.evaluate_now()
	await _settle()
	await _shot(out_dir, "guide_gd.mg.weigh")
	rice.queue_free()
	guide.queue_free()
	bus.queue_free()
	holder.queue_free()
	CardText.setup(null)
	CardAnchors.clear()
	await process_frame
	quit(0)


func _clear_scale(game) -> void:
	game.apply_op(["poise", 0])
	for i in game._weights.size():
		if game._on[i]:
			game.apply_op(["weight", i])


func _settle() -> void:
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(dir: String, name: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	var path := dir.path_join(name + ".png")
	img.save_png(path)
	print("SHOT ", path, " ", img.get_width(), "x", img.get_height())
