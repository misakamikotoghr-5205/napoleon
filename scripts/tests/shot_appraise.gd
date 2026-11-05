# 验货“找不同”的截图：真实渲染（需要 Xvfb，不能 --headless）。
# xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/shot_appraise.gd -- --out=/绝对路径 [--seed=N]
# 输出：appraise_d1_tutorial_open / appraise_d2_tutorial_circle / appraise_d3_tutorial_hit（序章哥哥教圈）、
#      appraise_a_genuine_rice（真米）、appraise_b_fake_sulfa（假磺胺：圈中两处、圈空一处）、appraise_c_generated_lens（生成的假货 + 放大镜镜片）
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const Session = preload("res://scripts/core/session.gd")
const Items = preload("res://scripts/sim/item_gen.gd")

var out_dir: String = ""
var seed_v: int = 7
var c
var main
var town

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := out_dir.path_join("appraise_%s.png" % name)
	root.get_viewport().get_texture().get_image().save_png(path)
	print("SHOT ", path)

func _run() -> void:
	c = Common.new(self)
	await c.make_main()
	main = c.main
	town = c.town
	town.set_fast(true)
	town.auto_dismiss = true
	main.dialogue.instant = true
	town.new_game(seed_v, "常年", false)      # 走真的序章
	var guard := 0
	while guard < 6000:
		guard += 1
		await process_frame
		var t: String = main.cur_type
		if t == "practice" and str(main.cur.get("kind", "")) == "inspect" and main.inspect.visible:
			break
		match t:
			"say", "narr":
				main.dialogue.finish_typing()
				main._on_dialogue_advanced()
			"caption":
				main._respond({})
			"tutorial":
				main._on_hotspot(str(main.cur["target"]))
			"choice", "door_flag", "pick_item":
				var opts: Array = main._options_for(main.cur)
				main._respond({"id": str(opts[0]["id"])} if not opts.is_empty() else {})
	var p = main.inspect
	await _shot("d1_tutorial_open")
	p.open_atlas()
	p.set_tool("magnifier")
	var r: Rect2 = p.part_local_rect("inscription")
	p._lens = r.get_center() / p.HAND_SCALE + Vector2(0.5, 0.5)
	await _shot("d2_tutorial_circle")
	p.circle_at(r.get_center(), 26.0, "magnifier")
	p._lens = Vector2(-1, -1)
	await _shot("d3_tutorial_hit")
	var w = town.world
	# (a) 真米：甲等粳米，上手看一圈
	w.add_page("rice_grades")      # 平常日子里早有米的图鉴页（序章后半哥哥也交代了六类货）
	var s1 = _session(w, ["rice_jing_a"])
	p.open(s1)
	p.set_tool("hand")
	p.circle_at(p.part_local_rect("grain").get_center(), 40.0, "hand")
	await _shot("a_genuine_rice")
	# (b) 假磺胺：粉末、厂标两处圈中，空白处圈空一笔
	w.unlocked["medbook"] = true
	var s2 = _session(w, ["sulfa_fake"])
	p.open(s2)
	p.circle_at(p.part_local_rect("powder").get_center(), 34.0, "hand")
	p.circle_at(p.part_local_rect("label").get_center(), 28.0, "hand")
	p.circle_at(Vector2(262, 80), 22.0, "hand")
	await _shot("b_fake_sulfa")
	# (c) 生成的假货：运行时画上的破绽 + 放大镜镜片
	var item := _generated_fake(w)
	var s3 = Session.new()
	s3.world = w
	s3.mode = "buy"
	s3._add(w.ledger.add_item(item, "player", "counter"))
	if not w.pages.has("deed_rules"):
		w.pages.append("deed_rules")
	p.open(s3)
	p.set_tool("magnifier")
	var ar: Rect2 = p.part_local_rect("authenticity")
	p._lens = ar.get_center() / p.HAND_SCALE
	p.last_text = "（镜片底下：%s）" % _kind_cn(item)
	p._rebuild()
	await _shot("c_generated_lens")
	p._lens = Vector2(-1, -1)
	p.circle_at(ar.get_center(), maxf(ar.size.x, ar.size.y) * 0.45, "magnifier")
	p.circle_at(p.part_local_rect("provenance").get_center(), 30.0, "hand")
	await _shot("c2_generated_circled")
	p.visible = false
	await c.shutdown()
	quit(0)

func _session(w, defs: Array):
	var items: Array = []
	for d in defs:
		items.append({"def": d})
	var s = Session.new()
	s.setup(w, {"id": "shot_appraise", "npc": "xiaoding", "mode": "buy", "items": items, "ask": 50, "floor": 25, "suggest": 40, "est": [10, 90], "min_inspect": 0})
	return s

func _kind_cn(item: Dictionary) -> String:
	for f in item.get("flaws", []):
		if str(f.get("part", "")) == "authenticity":
			return {"seal": "印泥颜色", "retrace": "描过的笔画", "speck": "杂点", "base_metal": "露底的颜色", "stitch": "新线", "thin": "印字"}.get(str(f["kind"]), "细处")
	return "细处"

# 找一件生成的、带印章类细处破绽、又被刮过记号的假文书（确定的键，截图每次一样）
func _generated_fake(w) -> Dictionary:
	var pack: Dictionary = town.world.town.pack.duplicate(true)
	pack["balance"]["items"]["fake_rate"] = 1.0
	pack["balance"]["items"]["stolen_rate"] = 1.0
	var templates: Dictionary = town.world.town.templates
	var best: Dictionary = {}
	for k in 40:
		var st: Dictionary = {"seed": int(w.world_seed), "day": 3, "pressures": {}, "stock": []}
		var it: Dictionary = Items.generate(templates, pack, st, ["shot_appraise", k], "documents")
		if best.is_empty():
			best = it
		for f in it.get("flaws", []):
			if str(f.get("kind", "")) == "seal" and str(it.get("template_id", "")) in ["field", "house"]:
				return it
	return best
