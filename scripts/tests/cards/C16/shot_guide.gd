# 第 1–3 天每一步一张 1280x720，外加拼图。不进清单。
# xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --audio-driver Dummy --path . \
#     -s res://scripts/tests/cards/C16/shot_guide.gd -- --out=<目录>
extends SceneTree

const Drive = preload("res://scripts/tests/cards/C16/guide_drive.gd")
const Fake = preload("res://scripts/tests/cards/C16/fake_engine.gd")
const FIXTURES: Array[String] = [
	"res://scripts/tests/cards/C16/fixtures/guide_d1.json",
	"res://scripts/tests/cards/C16/fixtures/guide_d2.json",
	"res://scripts/tests/cards/C16/fixtures/guide_d3.json",
]

var _out := ""
var _anchors: Dictionary = {}
var _guide: CardGuide
var _shots: Array[String] = []


func _initialize() -> void:
	_out = ProjectSettings.globalize_path("user://shots/C16")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {}))
	_run()


func _run() -> void:
	var doc = CardDB.read_json("res://scripts/tests/cards/C16/fixtures/guide_steps_full.json")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng = Fake.new()
	eng.data = _pack(doc)
	eng.view_d = {"phase": "boot", "mode": "shop", "date": {"stage": 0, "stage_day": 0, "abs_day": 0}, "hand": []}
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(holder)
	var bg := ColorRect.new()
	bg.color = CardTheme.color(&"wood_dark")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	_place_anchors(holder)
	_guide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	_guide.skip_fades = true
	_guide.set_process(false)
	holder.add_child(_guide)
	_guide.bind(eng, bus)
	_guide.load_steps(eng.data)
	_guide.force(true)
	for fx in FIXTURES:
		var day = CardDB.read_json(fx)
		await Drive.play(self, _guide, bus, eng, day.get("ops", []), _on_shown)
	_sheet()
	print("SHOTS " + str(_shots.size()))
	_guide.queue_free()
	bus.queue_free()
	await process_frame
	quit(0)


func _on_shown(id: String) -> void:
	for key in _anchors.keys():
		(_anchors[key] as CanvasItem).visible = str(key) == str(_guide._anchor_id)
	for _i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := _out.path_join(id + ".png")
	root.get_viewport().get_texture().get_image().save_png(path)
	_shots.append(path)
	print("SHOT " + path)
	for key in _anchors.keys():
		(_anchors[key] as CanvasItem).visible = true


func _sheet() -> void:
	if _shots.is_empty():
		return
	var cols := 7
	var tw := 320
	var th := 180
	var rows := int(ceil(float(_shots.size()) / float(cols)))
	var sheet := Image.create(cols * tw, rows * th, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(1, 1, 1, 1))
	for i in _shots.size():
		var img := Image.load_from_file(_shots[i])
		if img == null:
			continue
		img.resize(tw, th, Image.INTERPOLATE_NEAREST)
		var row := int(i / cols)
		var col := i - row * cols
		sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i(col * tw, row * th))
	var path := _out.path_join("guide_d1_3_sheet.png")
	sheet.save_png(path)
	print("SHOT " + path)


func _place_anchors(holder: Control) -> void:
	var seen: Dictionary = {}
	for fx in FIXTURES:
		var day = CardDB.read_json(fx)
		for a in day.get("anchors", []):
			var id := str(a.get("id", ""))
			if id == "" or seen.has(id):
				continue
			seen[id] = true
			var rect := ColorRect.new()
			rect.color = CardTheme.color(&"paper")
			rect.modulate = Color(1, 1, 1, 0.85)
			rect.position = Vector2(float(a.get("x", 0)), float(a.get("y", 0)))
			rect.size = Vector2(float(a.get("w", 10)), float(a.get("h", 10)))
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(rect)
			CardAnchors.register(StringName(id), rect)
			_anchors[id] = rect


func _pack(doc: Dictionary) -> Dictionary:
	var steps: Array = []
	for c in doc.get("cards", []):
		var d: Dictionary = (c as Dictionary).duplicate(true)
		for k in ["brief", "_provenance", "_test", "weight", "era"]:
			d.erase(k)
		steps.append(d)
	var rules = CardDB.read_json("res://data/cards/rules/guide.json")
	return {"steps": steps, "settings": rules if typeof(rules) == TYPE_DICTIONARY else {}}
