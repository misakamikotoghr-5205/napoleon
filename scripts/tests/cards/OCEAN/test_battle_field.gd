# 3D 战场（battle_board.gd + scripts/cards/ui/battle/field/）的无头测试：
# 七张模板都能搭起来；每格一个 Cell_<列>_<行> 按钮，点击区是这一格投到屏幕上的四边形（格子中心点得中、
# 邻格中心点不中）；cell_rect / cell_center 在板子里、和 Camera3D.unproject_position 对得上；整张图装进安全区
# （默认的窄边、满屏的 HUD 边、set_safe_area 自己给的）；单位和敌人各有一个 3D 节点，找图的 id 对；
# 高亮、预演、倒下的单位、交火后少了的敌人都跟着视图变；仓库规矩（没有 class_name、没有颜色字面量、
# 字符串字面量只有 ASCII、用到的 bt3d_* 配色键都在 palette.dev.json）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const OB = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const Board = preload("res://scripts/cards/ui/battle/battle_board.gd")
const FIELD_DIR := "res://scripts/cards/ui/battle/field"
const BOARD_PATH := "res://scripts/cards/ui/battle/battle_board.gd"
const PALETTE_DEV := "res://data/cards/theme/palette.dev.json"
const TEMPLATES := "res://data/campaigns/battle_templates.json"

var t


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_field")
	t.run_async(_body)


func _body() -> void:
	_test_house_rules()
	await _test_templates()
	await _test_play()
	await _test_elevated_body_click()
	await _test_safe_area()
	await _test_new_terrain()


func _state(tpl: String) -> Dictionary:
	var roster := [{"id": "dantes", "name": "D", "cls": "hussar", "max_hp": 12, "atk": 5, "def": 1, "block": 1, "cost": 3},
		{"id": "nemo", "name": "N", "cls": "artillery", "max_hp": 10, "atk": 6, "def": 0, "block": 0, "cost": 7}]
	var troops := [{"id": "line_1", "cls": "line", "name": "L"}, {"id": "jager_2", "cls": "jager", "name": "J"}]
	var s: Dictionary = R.new_battle(tpl, {"seed": 1815, "act": 1, "roster": roster, "troops": troops,
		"protagonist": {"enabled": true, "hp": 12, "max_hp": 12}, "cp_bonus": 7})
	t.ok(not s.has("error"), tpl + " builds")
	return s


func _view(s: Dictionary) -> Dictionary:
	return OB.public(R.view(s))


func _board(sz: Vector2) -> Control:
	var b: Control = Board.new()
	b.size = sz
	get_root().add_child(b)
	return b


## 七张模板：按钮、外接矩形、点击区、投影和相机一致
func _test_templates() -> void:
	var lib = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATES))
	var ids: Array = (lib.get("templates", {}) as Dictionary).keys()
	t.ok(ids.size() >= 7, "all battle templates listed")
	for tpl in ids:
		var s := _state(str(tpl))
		if s.has("error"):
			continue
		var b := _board(Vector2(900, 392))
		var v := _view(s)
		b.set_view(v)
		await t.frames(2)
		var cols := int(v["grid"]["cols"])
		var rows := int(v["grid"]["rows"])
		var all_in := true
		var hits_ok := true
		var miss_ok := true
		var clicks_ok := true
		var clicks: Array = []
		b.cell_pressed.connect(func(c: int, r: int) -> void: clicks.append(Vector2i(c, r)))
		var corner_checks := 0
		for r in range(rows):
			for c in range(cols):
				var btn: Button = b.find_child("Cell_%d_%d" % [c, r], false, false)
				if btn == null or not btn.is_visible_in_tree():
					all_in = false
					continue
				var rect: Rect2 = b.cell_rect(c, r)
				var ctr: Vector2 = b.cell_center(c, r)
				if rect.size.x < 8.0 or not Rect2(Vector2.ZERO, b.size).grow(1.0).encloses(rect) or not rect.grow(1.0).has_point(ctr):
					all_in = false
				if not btn._has_point(ctr - btn.position):
					hits_ok = false
				# Real viewport input must choose this cell, including overlaps from walls and elevated decks.
				var before := clicks.size()
				var mouse := b.get_global_transform_with_canvas() * ctr
				var motion := InputEventMouseMotion.new()
				motion.position = mouse
				root.push_input(motion, true)
				for pressed in [true, false]:
					var click := InputEventMouseButton.new()
					click.button_index = MOUSE_BUTTON_LEFT
					click.position = mouse
					click.pressed = pressed
					root.push_input(click, true)
				if clicks.size() != before + 1 or clicks.back() != Vector2i(c, r):
					clicks_ok = false
				if c + 1 < cols and btn._has_point(b.cell_center(c + 1, r) - btn.position):
					miss_ok = false
				if r + 1 < rows and btn._has_point(b.cell_center(c, r + 1) - btn.position):
					miss_ok = false
				# 外接矩形里、四边形外面的点（透视让格子成了梯形）：按钮不认
				var q: PackedVector2Array = b.cell_quad(c, r)
				for probe in [Vector2(rect.position.x + 1.0, rect.position.y + 1.0), Vector2(rect.end.x - 1.0, rect.position.y + 1.0)]:
					if not Geometry2D.is_point_in_polygon(probe, q) and btn.get_rect().has_point(probe):
						corner_checks += 1
						if btn._has_point(probe - btn.position):
							miss_ok = false
		t.ok(all_in, "%s: every cell has a visible button and an on-board rect" % tpl)
		t.ok(hits_ok, "%s: each cell button takes clicks at its own centre" % tpl)
		t.ok(clicks_ok, "%s: real mouse presses select exactly the intended grid cell" % tpl)
		t.ok(miss_ok, "%s: a cell button does not take clicks meant for its neighbours" % tpl)
		t.ok(corner_checks > 0, "%s: the hit area is the projected quad, not its bounding rect (%d corners)" % [tpl, corner_checks])
		var cam3d: Camera3D = b.find_child("Field3D", true, false).get_camera_3d()
		var p := Vector3(cols - 1, 0.18, rows - 1)
		var a: Vector2 = cam3d.unproject_position(p)
		t.ok(a.distance_to(b.cam.project(p)) < 1.0, "%s: own projection matches Camera3D (%s vs %s)" % [tpl, a, b.cam.project(p)])
		t.ok(b.find_children("Unit_*", "Node3D", true, false).size() == (v["battle_units"] as Array).size() + (v["enemies"] as Array).size(),
			"%s: one 3D node per unit and enemy" % tpl)
		b.queue_free()
		await t.frames(1)


## 一场仗打几步：部署、高亮、预演、交火后敌人少了 / 移动了，3D 节点跟着变
func _test_play() -> void:
	var s := _state("skirmish_a")
	var b := _board(Vector2(1280, 720))
	b.set_view(_view(s))
	await t.frames(1)
	t.eq(Board.art_id_for({"kind": "hero", "cls": "hero", "uid": "hero"}, false), "villefort", "hero art id")
	t.eq(Board.art_id_for({"kind": "troop", "cls": "jager", "uid": "jager_2"}, false), "troop_jager", "troop art id")
	t.eq(Board.art_id_for({"kind": "companion", "cls": "hussar", "uid": "zz_no_art"}, false), "troop_hussar",
		"companion without its own art falls back to the troop art id")
	t.eq(Board.art_id_for({"kind": "whitecoat"}, true), "enemy_whitecoat", "enemy art id")
	t.ok(R.apply(s, "deploy", {"unit": "line_1", "col": 3, "row": 1, "facing": "right"})["ok"], "deploy line")
	t.ok(R.apply(s, "deploy", {"unit": "hero", "col": 1, "row": 1, "facing": "right"})["ok"], "deploy hero")
	var v := _view(s)
	b.set_view(v)
	t.ok(b.unit_node("u:line_1") != null and b.unit_node("u:hero") != null, "deployed units get 3D nodes")
	var line_node = b.unit_node("u:line_1")
	t.ok(line_node.position.distance_to(b.cell_top(3, 1)) < 0.001, "unit stands on its tile top")
	var btn: Button = b.find_child("Cell_3_1", false, false)
	var head: Vector2 = b.cam.project(b.cell_top(3, 1) + Vector3(0, 0.5, 0))
	t.ok(btn._has_point(head - btn.position), "clicking the unit's body counts as clicking its cell")
	b.valid_cells = {Vector2i(2, 1): true}
	b.target_cells = {Vector2i(4, 1): true}
	b.pattern_cells = {Vector2i(5, 1): true}
	b.selected = Vector2i(3, 1)
	b.hovered = Vector2i(2, 1)
	b.doomed = {"line_1": true}
	b.ghost_hp = {"line_1": 3}
	b.queue_redraw()
	await t.frames(2)
	var marks: Node = b.find_child("CellMarks", true, false)
	var shown := 0
	for m in marks.get_children():
		if (m as Node3D).visible:
			shown += 1
	t.eq(shown, 5, "valid, target, pattern fills and the selected and hovered outlines are on")
	t.ok(bool(line_node.doomed), "a unit that falls this turn is marked on the field")
	b.valid_cells = {}
	b.target_cells = {}
	b.pattern_cells = {}
	b.selected = Vector2i(-1, -1)
	b.hovered = Vector2i(-1, -1)
	b.doomed = {}
	b.ghost_hp = {}
	b.queue_redraw()
	await t.frames(2)
	shown = 0
	for m in marks.get_children():
		if (m as Node3D).visible:
			shown += 1
	t.eq(shown, 0, "highlights clear")
	var before := (v["enemies"] as Array).size()
	var moved := false
	for _i in range(4):
		if str(s.get("phase", "")) == "over":
			break
		var pos := {}
		var inst := {}
		for e in _view(s)["enemies"]:
			var n = b.unit_node("e:%d" % int(e["uid"]))
			if n != null:
				pos[int(e["uid"])] = n.position
				inst[int(e["uid"])] = n
		R.apply(s, "fight", {})
		var v2 := _view(s)
		b.set_view(v2)
		await t.frames(2)
		var kept := true
		var per_cell := {}
		for e in v2["enemies"]:
			var kc := Vector2i(int(e["col"]), int(e["row"]))
			per_cell[kc] = int(per_cell.get(kc, 0)) + 1
		for e in v2["enemies"]:
			var n2 = b.unit_node("e:%d" % int(e["uid"]))
			t.ok(n2 != null, "enemy %d has a node after the fight" % int(e["uid"]))
			if n2 != null and pos.has(int(e["uid"])) and n2.position.distance_to(pos[int(e["uid"])]) > 0.01:
				moved = true
			# 同一格的敌人多了 / 少了也是同一个节点（换个大小），不删了重建
			if n2 != null and inst.has(int(e["uid"])) and n2 != inst[int(e["uid"])]:
				kept = false
			var n_here := int(per_cell[Vector2i(int(e["col"]), int(e["row"]))])
			if n2 != null and not is_equal_approx(float(n2.token_scale), float(Board.STACK_SCALE.get(n_here, 0.55))):
				kept = false
		t.ok(kept, "surviving enemies keep their 3D node and take the stack size of their cell")
		var count := b.find_children("Unit_*", "Node3D", true, false).size()
		t.eq(count, (v2["battle_units"] as Array).size() + (v2["enemies"] as Array).size(), "3D nodes follow the view after a fight")
	t.ok(moved or (_view(s)["enemies"] as Array).size() != before, "enemies moved or fell during the fights")
	b.queue_free()
	await t.frames(1)


## 桅杆上的人物身体仍可点选，不会被身后的甲板格抢走点击。
func _test_elevated_body_click() -> void:
	var board := _board(Vector2(1280, 720))
	board.set_view(_view(_state("viper_boarding")))
	await t.frames(2)
	# H2's sniper stands on rigging above H1's deck; its body projects over H1's top.
	var point: Vector2 = board.cam.project(board.cell_top(7, 1) + Vector3(0, 0.5, 0))
	var received := []
	board.cell_pressed.connect(func(c: int, r: int) -> void: received.append(Vector2i(c, r)))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.pressed = pressed
		root.push_input(click, true)
	t.eq(board.cell_at_point(point), Vector2i(7, 1), "elevated sniper body belongs to H2")
	t.eq(received, [Vector2i(7, 1)], "real mouse selects the elevated H2 sniper, not the H1 deck")
	board.queue_free()
	await t.frames(1)


## 安全区：默认（小板子窄边、满屏留 HUD 的边）和 set_safe_area 给的，整张图都装在里面
func _test_safe_area() -> void:
	var s := _state("rivoli")
	var b := _board(Vector2(1280, 720))
	b.set_view(_view(s))
	await t.frames(1)
	var safe: Rect2 = b.safe_area()
	t.eq(safe, Rect2(24, 64, 1232, 486), "full-screen board leaves room for the HUD by default")
	t.ok(safe.grow(1.0).encloses(_map_rect(b)), "rivoli fits the default HUD safe area: %s in %s" % [_map_rect(b), safe])
	var custom := Rect2(300, 100, 600, 360)
	b.set_safe_area(custom)
	await t.frames(1)
	var mr := _map_rect(b)
	t.ok(custom.grow(1.0).encloses(mr), "rivoli fits a custom safe area: %s in %s" % [mr, custom])
	t.ok(mr.size.x > custom.size.x * 0.6 or mr.size.y > custom.size.y * 0.6, "the map fills the custom safe area")
	b.size = Vector2(900, 392)
	b.set_safe_area(Rect2(0, 0, 900, 392))
	await t.frames(1)
	t.ok(Rect2(0, 0, 900, 392).grow(1.0).encloses(_map_rect(b)), "rivoli fits the old 900x392 board")
	b.queue_free()
	await t.frames(1)


func _map_rect(b: Control) -> Rect2:
	var out := Rect2()
	var first := true
	for r in range(int(b.rows)):
		for c in range(int(b.cols)):
			var rc: Rect2 = b.cell_rect(c, r)
			out = rc if first else out.merge(rc)
			first = false
	return out


## 仓库规矩：没有 class_name；颜色只走配色键；字符串字面量只有 ASCII；bt3d_* 配色键都在开发配色表里
func _test_house_rules() -> void:
	var files := PackedStringArray([BOARD_PATH])
	for f in DirAccess.get_files_at(FIELD_DIR):
		if f.ends_with(".gd"):
			files.append(FIELD_DIR + "/" + f)
	t.ok(files.size() >= 8, "board and field helpers are there (%d)" % files.size())
	var colors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_DEV)).get("colors", {})
	var key_re := RegEx.create_from_string("\"(bt3d_[a-z0-9_]+)\"")
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		var code := _strip_comments(src)
		t.ok(RegEx.create_from_string("(?m)^class_name\\s").search(code) == null, path + ": no class_name")
		t.ok(not RegEx.create_from_string("Color\\s*\\(|Color8\\s*\\(|Color\\.html|Color\\.from_|Color\\.[A-Z]").search(code),
			path + ": no colour literals")
		for lit in _strings(src):
			var ascii := true
			for i in lit.length():
				if lit.unicode_at(i) > 127:
					ascii = false
			t.ok(ascii, "%s: ASCII string literal '%s'" % [path.get_file(), lit])
		for m in key_re.search_all(code):
			t.ok(colors.has(m.get_string(1)), "%s: palette key %s exists" % [path.get_file(), m.get_string(1)])


func _strip_comments(src: String) -> String:
	var out := ""
	var in_str := false
	var i := 0
	while i < src.length():
		var c := src.unicode_at(i)
		if in_str and c == 92:
			out += src.substr(i, 2)
			i += 2
			continue
		if c == 34:
			in_str = not in_str
		if c == 35 and not in_str:
			while i < src.length() and src.unicode_at(i) != 10:
				i += 1
			continue
		out += src.substr(i, 1)
		i += 1
	return out


func _strings(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var code := _strip_comments(src)
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for m in re.search_all(code):
		out.append(m.get_string(1))
	return out


## 第五片的新地形和最大尺寸（WORLD_MAP_DESIGN §9.5 的最低兼容；新地形的贴图、摆件、虚空不建地块是 B2）：
## 12×7 的不规则决战图（虚空、墙、海、桅盘、屋顶、隐身敌人）在满屏板子上搭得起来，每格点击区不小于 44 px，交火后节点跟着视图
func _test_new_terrain() -> void:
	var map := ["__^^^^^^^^WW", "_^E=====b==G", "^^^..w..#^tW", "E===v=====G_", "^^^.R...^^^^", "_E===f====G_", "__^^^^^^^^__"]
	var tpl := {"id": "epic12", "name": "e", "scale": "epic", "level": 14, "turn_limit": 13, "enemy_morale": 40, "map": map,
		"routes": {"a": ["L2", "K2", "J2", "I2", "H2", "G2", "F2", "E2", "D2", "C2"], "b": ["K4", "J4", "I4", "H4", "G4", "F4", "E4", "D4", "C4", "B4", "A4"],
			"c": ["K6", "J6", "I6", "H6", "G6", "F6", "E6", "D6", "C6", "B6"]},
		"waves": [{"turn": 1, "route": "a", "units": ["redcoat", "smuggler"]}, {"turn": 1, "at": "L1", "units": ["gunboat"]},
			{"turn": 1, "at": "K3", "units": ["marine_sharpshooter"]}, {"turn": 2, "route": "b", "units": ["highlander", "navy_captain"]},
			{"turn": 3, "route": "c", "units": ["scots_grey", "rifleman"]}]}
	t.eq(R.validate_template(tpl), [], "12x7 mixed-terrain template validates")
	var s: Dictionary = R.new_battle("epic12", {"seed": 3, "level": 14, "template": tpl, "weather": "night", "protagonist": {"enabled": true}, "cp_bonus": 7,
		"roster": [{"id": "corso", "name": "C", "cls": "jager", "cost": 3}], "troops": [{"id": "line_1", "cls": "line", "name": "L"}, {"id": "gren", "cls": "grenadier", "name": "G"}]})
	t.ok(not s.has("error"), "12x7 battle builds")
	t.ok(R.apply(s, "deploy", {"unit": "corso", "col": 4, "row": 4, "facing": "right"})["ok"], "a jager climbs the rooftop")
	t.ok(R.apply(s, "deploy", {"unit": "gren", "col": 3, "row": 3, "facing": "right"})["ok"], "a grenadier on the road")
	var b := _board(Vector2(1280, 720))
	b.set_view(_view(s))
	await t.frames(2)
	var small := 0
	var missing := 0
	for r in range(7):
		for c in range(12):
			var btn: Button = b.find_child("Cell_%d_%d" % [c, r], false, false)
			if btn == null:
				missing += 1
				continue
			var rc: Rect2 = b.cell_rect(c, r)
			if rc.size.x < 44.0 or rc.size.y < 44.0:
				small += 1
	t.eq([missing, small], [0, 0], "12x7 on 1280x720 with the HUD safe area: every cell has a button and is at least 44 px")
	t.ok(b.safe_area().grow(1.0).encloses(_map_rect(b)), "12x7 fits the HUD safe area")
	for _i in range(4):
		if str(s.get("phase", "")) == "over":
			break
		R.apply(s, "fight", {})
		var v := _view(s)
		b.set_view(v)
		await t.frames(1)
		t.eq(b.find_children("Unit_*", "Node3D", true, false).size(), (v["battle_units"] as Array).size() + (v["enemies"] as Array).size(),
			"new terrain: one 3D node per unit and enemy after a fight (hidden enemies included)")
	b.queue_free()
	await t.frames(1)
