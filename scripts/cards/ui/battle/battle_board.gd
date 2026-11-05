## 战场格子（明日方舟式的斜俯视 3D 地图）：按规则内核的视图（battle2.view）搭一张有高低的 3D 沙盘——地块、摆件、
## 我方单位和敌人、路线、敌人移动箭头、炮击准星、部署 / 目标 / 射程 / 选中 / 悬停高亮；血条、兵力数字、名字、
## 伤害合计、标记这些字和小图形画在上面的 2D 叠加层里（按相机投影，任何分辨率都清楚）。每一格上面盖一个透明按钮
## （Cell_<列>_<行>），点击区就是这一格顶面投到屏幕上的四边形（站着人时再往上包住人身），接点击和悬停。
## 3D 在一个自己的 SubViewport 里按窗口实际分辨率渲染（4×MSAA），远景（field_backdrop）在 3D 后面。
## 对外接口和以前的 2D 格子一样（battle_panel.gd 不用改），另外加了 set_safe_area：地图自动缩放、居中装进这个区域。
## 有美术就用美术（art/hd/tile、prop、unit、bg/battle_backdrop），没有就用代码画的占位，放了图不用改代码。
## 说明：docs/cards/BATTLE_V2.md「3D 战场」。没有 class_name，battle_panel.gd preload 它。颜色全走配色键（bt3d_*）。
## 只画，不发指令：点击交给面板。
extends Control

const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const Cam = preload("res://scripts/cards/ui/battle/field/field_cam.gd")
const Terrain = preload("res://scripts/cards/ui/battle/field/field_terrain.gd")
const Props = preload("res://scripts/cards/ui/battle/field/field_props.gd")
const Sh = preload("res://scripts/cards/ui/battle/field/field_shaders.gd")
const UnitView = preload("res://scripts/cards/ui/battle/field/field_unit.gd")
const Overlay = preload("res://scripts/cards/ui/battle/field/field_overlay.gd")
const Backdrop = preload("res://scripts/cards/ui/battle/field/field_backdrop.gd")

signal cell_pressed(col: int, row: int)
signal cell_hovered(col: int, row: int)
signal cell_left(col: int, row: int)
## 交火回放放完了（或被跳过）：HUD 这时才把回合数、军心、战报换成交火以后的
signal playback_finished

const BASE_Y := Terrain.BASE_Y
## 板子满屏时默认给 HUD 留的边（上、下、左右）；小板子（嵌在旧面板里）只留一圈窄边
const HUD_TOP := 64.0
const HUD_BOTTOM := 170.0
const HUD_SIDE := 24.0
const COMPACT_PAD := 8.0
## 坐标字母 / 数字占的地方（从安全区里扣）
const LABEL_LEFT := 32.0
const LABEL_BOTTOM := 22.0
const MAX_PIXEL_SCALE := 2.0
const ANIM_TAIL := 0.7
## 交火回放：一步一步放（我方开火、白刃 -> 敌人挨打倒下 -> 敌人移动 -> 敌人攻击、我方挨打 -> 冲进鹰旗、新来的敌人），每步间隔
const STEP_S := 0.42
const STEPS := 5
const Ui = preload("res://scripts/cards/ui/battle/battle_ui.gd")
## 同一格几个敌人的站位（格内偏移）和缩小比例
const STACK := {1: [[0.0, 0.0]], 2: [[-0.2, -0.1], [0.2, 0.1]], 3: [[-0.22, -0.16], [0.22, -0.16], [0.0, 0.2]],
	4: [[-0.21, -0.17], [0.21, -0.17], [-0.21, 0.19], [0.21, 0.19]]}
const STACK_SCALE := {1: 1.0, 2: 0.78, 3: 0.7, 4: 0.66}
const TREE_SLOTS := [[-0.3, -0.3], [0.31, -0.28], [-0.33, 0.27], [0.32, 0.3]]

var view: Dictionary = {}
## 高亮：能部署的格子（平地绿、高地蓝）、目标格（红）、射程 / 图样（橙）、选中的格子（金）、悬停的格子（白框）
var valid_cells: Dictionary = {}
var target_cells: Dictionary = {}
var pattern_cells: Dictionary = {}
var selected := Vector2i(-1, -1)
var hovered := Vector2i(-1, -1)
## 悬停预演：uid → 交火后的兵力（我方是字符串 uid，敌人是 "e<编号>"）
var ghost_hp: Dictionary = {}
## 本回合预演（campaign.battle_preview）：交火后会倒下的我方单位，脚下红圈闪、血条旁画骷髅
var doomed: Dictionary = {}

var cols := 0
var rows := 0
## 兼容旧接口：一格在屏幕上的大约大小、整张图投影后的左上角
var cell := Vector2(100, 76)
var origin := Vector2.ZERO

## 相机（投影算法，无头也能用）；叠加层要画的单位清单
var cam: Cam = Cam.new()
var ov_units: Array = []

var _safe := Rect2()
var _safe_custom := false
var _heights := PackedFloat32Array()
var _terr: Dictionary = {}
var _terrain_sig := ""
var _fit_sig := ""
var _intent_sig := ""
var _cells_built := Vector2i(-1, -1)
var _quads: Dictionary = {}
var _units: Dictionary = {}
var _cell_fill: Dictionary = {}
var _cell_edge: Dictionary = {}
var _cell_style: Dictionary = {}
var _props: Props = Props.new()
var _prev: Dictionary = {}
var _px_scale := 1.0
var _anim_until := 0.0
## 交火回放：还没放的几步（[[Callable, ...], ...]）、推进它们的补间、飘字层
var _steps: Array = []
var _step_tw: Tween = null
var _playing := false
var _floats: Control

var _vp: SubViewport
var _vp_tex: TextureRect
var _cam3d: Camera3D
var _backdrop: Backdrop
var _terrain_root: Node3D
var _props_root: Node3D
var _static_root: Node3D
var _intent_root: Node3D
var _cells_root: Node3D
var _units_root: Node3D
var _overlay: Control


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	HdTheme.apply_hd_filter(self)
	_build_scene()
	resized.connect(_relayout)


func _enter_tree() -> void:
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_relayout):
		vp.size_changed.connect(_relayout)
	_relayout.call_deferred()


func _exit_tree() -> void:
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(_relayout):
		vp.size_changed.disconnect(_relayout)


func _build_scene() -> void:
	_vp = SubViewport.new()
	_vp.name = "Field3D"
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_vp.size = Vector2i(64, 64)
	add_child(_vp)
	var layer := CanvasLayer.new()
	layer.layer = -1
	_vp.add_child(layer)
	_backdrop = Backdrop.new()
	_backdrop.name = "Backdrop"
	layer.add_child(_backdrop)
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _col("bt3d_ambient")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = _col("bt3d_sun")
	sun.light_energy = 1.05
	sun.basis = Basis.looking_at(Vector3(0.55, -1.0, -0.42).normalized(), Vector3.UP)
	_vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.light_color = _col("bt3d_fill")
	fill.light_energy = 0.32
	fill.basis = Basis.looking_at(Vector3(-0.6, -0.5, 0.7).normalized(), Vector3.UP)
	_vp.add_child(fill)
	_cam3d = Camera3D.new()
	_cam3d.fov = Cam.FOV_DEG
	_cam3d.near = Cam.NEAR
	_cam3d.far = Cam.FAR
	_cam3d.keep_aspect = Camera3D.KEEP_HEIGHT
	_vp.add_child(_cam3d)
	_cam3d.current = true
	var world := Node3D.new()
	world.name = "World"
	_vp.add_child(world)
	_terrain_root = _node3d(world, "Terrain")
	_props_root = _node3d(world, "Props")
	_static_root = _node3d(world, "StaticMarks")
	_intent_root = _node3d(world, "Intents")
	_cells_root = _node3d(world, "CellMarks")
	_units_root = _node3d(world, "Units")
	_vp_tex = TextureRect.new()
	_vp_tex.name = "FieldView"
	_vp_tex.texture = _vp.get_texture()
	_vp_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vp_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_vp_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp_tex.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_vp_tex)
	_overlay = Overlay.new()
	_overlay.name = "Overlay"
	_overlay.board = self
	add_child(_overlay)
	_floats = Control.new()
	_floats.name = "Floats"
	_floats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floats)


func _node3d(parent: Node, n: String) -> Node3D:
	var x := Node3D.new()
	x.name = n
	parent.add_child(x)
	return x


func _col(key: String) -> Color:
	return CardTheme.color(StringName(key))


func _col_a(key: String, a: float) -> Color:
	var c := CardTheme.color(StringName(key))
	c.a *= a
	return c


# ================================================================ 对外接口

func set_view(v: Dictionary) -> void:
	# 上一次交火还没放完又来了新视图（玩家点了别的）：剩下的几步立刻放完
	skip_playback()
	_prev = view
	view = v
	var g: Dictionary = v.get("grid", {})
	cols = int(g.get("cols", 0))
	rows = int(g.get("rows", 0))
	var cells: Array = g.get("cells", [])
	var tsig := "%d|%d|%s" % [cols, rows, JSON.stringify(cells)]
	if tsig != _terrain_sig:
		_terrain_sig = tsig
		_rebuild_terrain(cells)
	_relayout()
	_sync_units()
	_sync_intents()
	_sync_highlights()
	queue_redraw()


## 地图要装进的区域（板子本地坐标）。HUD 把板子铺满全屏后调它，给顶栏、部署栏、侧栏让出地方。
func set_safe_area(rect: Rect2) -> void:
	_safe = rect
	_safe_custom = true
	_fit_sig = ""
	_relayout()


## 现在用的安全区：设过就是设的；没设时满屏大板子留 HUD 的边（上 64、下 170、左右 24），小板子只留一圈窄边
func safe_area() -> Rect2:
	if _safe_custom:
		return _safe
	if size.x >= 1000.0 and size.y >= 600.0:
		return Rect2(Vector2(HUD_SIDE, HUD_TOP), size - Vector2(HUD_SIDE * 2.0, HUD_TOP + HUD_BOTTOM))
	return Rect2(Vector2.ZERO, size).grow(-COMPACT_PAD)


## 这一格顶面投到屏幕上的外接矩形（板子本地坐标；面板用它摆朝向箭头和动作菜单）
func cell_rect(c: int, r: int) -> Rect2:
	var q := cell_quad(c, r)
	if q.size() < 4:
		return Rect2(origin + Vector2(c * cell.x, r * cell.y), cell)
	var lo := q[0]
	var hi := q[0]
	for p in q:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo.round(), (hi - lo).round())


## 这一格顶面中心投到屏幕上的点
func cell_center(c: int, r: int) -> Vector2:
	if cols <= 0:
		return cell_rect(c, r).get_center()
	return cam.project(cell_top(c, r))


func cell_button(c: int, r: int) -> Button:
	return get_node_or_null("Cell_%d_%d" % [c, r]) as Button


## 高台或人物的投影可能压到邻格；统一选最近的格心或身体中心，避免靠按钮创建顺序抢走点击。
func cell_at_point(point: Vector2) -> Vector2i:
	var picked := Vector2i(-1, -1)
	var nearest := INF
	for key in _quads:
		var button := cell_button(key.x, key.y) as CellButton
		if button == null or not button.contains_local_point(point - button.position):
			continue
		var distance := point.distance_squared_to(cell_center(key.x, key.y))
		if button.has_body:
			distance = minf(distance, point.distance_squared_to(button.body_anchor))
		if distance < nearest:
			nearest = distance
			picked = key
	return picked


## 这一格顶面的四个角投到屏幕上：[后左, 后右, 前右, 前左]（屏幕上的左上、右上、右下、左下）
func cell_quad(c: int, r: int) -> PackedVector2Array:
	return _quads.get(Vector2i(c, r), PackedVector2Array())


## 这一格顶面中心的世界坐标
func cell_top(c: int, r: int) -> Vector3:
	var h := Terrain.GROUND
	if c >= 0 and r >= 0 and c < cols and r < rows and r * cols + c < _heights.size():
		h = _heights[r * cols + c]
	return Vector3(c, h, r)


func enemies_at(c: int, r: int) -> Array:
	var out: Array = []
	for e in view.get("enemies", []):
		if int(e["col"]) == c and int(e["row"]) == r:
			out.append(e)
	return out


## 叠加层用：单位的 3D 节点（"u:<uid>" / "e:<编号>"），没有回 null
func unit_node(key: String) -> UnitView:
	var n = _units.get(key, null)
	return n if n != null and is_instance_valid(n) else null


## 叠加层用：我方单位的视图字典
func unit_data(uid: String) -> Dictionary:
	for u in view.get("battle_units", []):
		if str(u["uid"]) == uid:
			return u
	return {}


func hero_on_field() -> bool:
	for u in view.get("battle_units", []):
		if str(u["uid"]) == "hero" and str(u["state"]) == "ok":
			return true
	return false


## 单位用哪套逐帧图：主角 villefort，伙伴用自己的 id（没有就退回 troop_<兵种>），部队 troop_<兵种>，
## 敌人 enemy_<种类>；拒马没有小人（用摆件 cheval）
static func art_id_for(u: Dictionary, enemy: bool) -> String:
	if enemy:
		return "enemy_" + str(u.get("kind", ""))
	var kind := str(u.get("kind", ""))
	var cls := str(u.get("cls", ""))
	match kind:
		"hero":
			return "villefort"
		"companion":
			var uid := str(u.get("uid", ""))
			if HdArt.has_art("unit", uid):
				return uid
			return "troop_" + cls
		"barricade":
			return ""
	return "troop_" + cls


# ================================================================ 布局

func _relayout() -> void:
	if not is_instance_valid(_vp):
		return
	_px_scale = _pixel_scale()
	var px := Vector2i(maxi(8, ceili(size.x * _px_scale)), maxi(8, ceili(size.y * _px_scale)))
	if _vp.size != px:
		_vp.size = px
	_backdrop.position = Vector2.ZERO
	_backdrop.size = Vector2(px)
	_vp_tex.position = Vector2.ZERO
	_vp_tex.size = size
	_overlay.position = Vector2.ZERO
	_overlay.size = size
	if cols <= 0 or rows <= 0:
		return
	var safe := safe_area()
	var fit := Rect2(safe.position + Vector2(LABEL_LEFT, 4.0), safe.size - Vector2(LABEL_LEFT + 4.0, LABEL_BOTTOM + 4.0))
	var sig := "%d|%d|%s|%s|%s|%d" % [cols, rows, str(size), str(fit), str(Array(_heights).hash()), px.x]
	if sig != _fit_sig:
		_fit_sig = sig
		cam.fit(cols, rows, _heights, BASE_Y, size, fit)
		_cam3d.transform = cam.xform
		_project_cells()
		var mid: Vector2 = cam.project(cell_top(cols / 2, rows / 2))
		_backdrop.glow_center = Vector2(mid.x / maxf(size.x, 1.0), mid.y / maxf(size.y, 1.0))
		_backdrop.queue_redraw()
	if _cells_built != Vector2i(cols, rows):
		_build_cells()
	_place_cells()
	_overlay.queue_redraw()


## 3D 视口的像素倍数：窗口比 1280×720 大时按实际像素渲染（最多 2 倍），字和边都不糊
func _pixel_scale() -> float:
	if not is_inside_tree():
		return 1.0
	var s := get_viewport().get_final_transform().get_scale().x * get_global_transform_with_canvas().get_scale().x
	return clampf(s, 1.0, MAX_PIXEL_SCALE)


func _project_cells() -> void:
	_quads.clear()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for r in range(rows):
		for c in range(cols):
			var h := cell_top(c, r).y
			var q := PackedVector2Array([cam.project(Vector3(c - 0.5, h, r - 0.5)), cam.project(Vector3(c + 0.5, h, r - 0.5)),
				cam.project(Vector3(c + 0.5, h, r + 0.5)), cam.project(Vector3(c - 0.5, h, r + 0.5))])
			_quads[Vector2i(c, r)] = q
			for p in q:
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	origin = lo
	var mid := cell_rect(cols / 2, rows / 2)
	cell = mid.size


func _build_cells() -> void:
	for child in get_children():
		if child is Button and str(child.name).begins_with("Cell_"):
			remove_child(child)
			child.queue_free()
	for r in range(rows):
		for c in range(cols):
			var b := CellButton.new()
			b.name = "Cell_%d_%d" % [c, r]
			b.cell = Vector2i(c, r)
			b.pressed.connect(func() -> void: cell_pressed.emit(c, r))
			b.mouse_entered.connect(func() -> void: _on_enter(c, r))
			b.mouse_exited.connect(func() -> void: _on_leave(c, r))
			add_child(b)
	_cells_built = Vector2i(cols, rows)


## 每格按钮的点击区：顶面四边形；站着人（或敌人）时再往上包住人身的下半截，点人也算点这一格
func _place_cells() -> void:
	var occupied := {}
	for u in view.get("battle_units", []):
		occupied[Vector2i(int(u["col"]), int(u["row"]))] = true
	for e in view.get("enemies", []):
		occupied[Vector2i(int(e["col"]), int(e["row"]))] = true
	for r in range(rows):
		for c in range(cols):
			var b := get_node_or_null("Cell_%d_%d" % [c, r]) as CellButton
			if b == null:
				continue
			var pts := cell_quad(c, r)
			if pts.size() < 4:
				continue
			b.has_body = occupied.has(Vector2i(c, r))
			if b.has_body:
				var top := cell_top(c, r)
				b.body_anchor = cam.project(top + Vector3(0, 0.5, 0))
				var hp := PackedVector2Array(pts)
				hp.append(cam.project(top + Vector3(-0.2, 0.7, 0)))
				hp.append(cam.project(top + Vector3(0.2, 0.7, 0)))
				pts = Geometry2D.convex_hull(hp)
			var lo := pts[0]
			var hi := pts[0]
			for p in pts:
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
			b.position = lo.floor()
			b.size = (hi - lo.floor()).ceil()
			var local := PackedVector2Array()
			for p in pts:
				local.append(p - b.position)
			b.poly = local


func _on_enter(c: int, r: int) -> void:
	hovered = Vector2i(c, r)
	cell_hovered.emit(c, r)
	queue_redraw()


func _on_leave(c: int, r: int) -> void:
	if hovered == Vector2i(c, r):
		hovered = Vector2i(-1, -1)
	cell_left.emit(c, r)
	queue_redraw()


# ================================================================ 地形、摆件

func _rebuild_terrain(cells: Array) -> void:
	_terr.clear()
	for cd in cells:
		_terr[Vector2i(int(cd["col"]), int(cd["row"]))] = str(cd["terrain"])
	_heights = Terrain.heights(cells, cols, rows, true)
	Terrain.build(_terrain_root, cells, cols, rows, Terrain.heights(cells, cols, rows), _col)
	_clear(_props_root)
	_clear(_static_root)
	for cd in cells:
		_place_props(int(cd["col"]), int(cd["row"]), str(cd["terrain"]))
		if str(cd["terrain"]) == "gate":
			_static_root.add_child(Sh.mark_node({"shape": Sh.CELL, "fill": _col_a("bt3d_spawn", 0.26), "edge": _col("bt3d_spawn"),
				"edge_w": 0.04, "glow": 0.5}, 1, cell_top(int(cd["col"]), int(cd["row"])) + Vector3(0, 0.01, 0), 1.0, 1.0))
		if bool(cd.get("reserved", false)):
			var top := cell_top(int(cd["col"]), int(cd["row"]))
			_static_root.add_child(Sh.mark_node({"shape": Sh.CELL, "fill": _col_a("bt3d_reserved", 0.12), "edge": _col("bt3d_reserved"),
				"edge_w": 0.045, "dash": 6.0}, 2, top + Vector3(0, 0.012, 0), 1.0, 1.0))
	var span := Vector3(cols + 1.4, 1, rows + 1.6)
	_static_root.add_child(Sh.mark_node({"shape": Sh.DISC, "fill": _col("bt3d_under_shadow"), "radius": 0.55}, -10,
		Vector3((cols - 1) * 0.5, BASE_Y - 0.02, (rows - 1) * 0.5 + 0.2), span.x, span.z))
	_build_cell_pool()
	_fit_sig = ""


func _clear(n: Node) -> void:
	for ch in n.get_children():
		n.remove_child(ch)
		ch.queue_free()


func _hash(c: int, r: int, k: int) -> int:
	var h := (c * 73856093) ^ (r * 19349663) ^ (k * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


## 摆件脚下软影子的大小（格）：树、房子、旗杆这些高的东西才要
const PROP_SHADOW := {"tree_a": 0.5, "tree_b": 0.3, "tree_c": 0.32, "house_a": 0.66, "house_b": 0.58, "eagle": 0.42}


func _put(id: String, at: Vector3, yaw: float, scl: float, seed_value: int) -> Node3D:
	var p: Node3D = _props.prop(id, seed_value)
	p.position = at
	p.rotation_degrees = Vector3(0, yaw, 0)
	p.scale = Vector3.ONE * scl
	_props_root.add_child(p)
	if PROP_SHADOW.has(id):
		var d := float(PROP_SHADOW[id]) * scl
		_static_root.add_child(Sh.mark_node({"shape": Sh.DISC, "fill": _col("bt3d_prop_shadow"), "radius": 0.2}, 0,
			at + Vector3(0.04, 0.008, 0.04), d, d * 0.8))
	return p


func _place_props(c: int, r: int, tr: String) -> void:
	var top := cell_top(c, r)
	var s := c * 31 + r * 17
	match tr:
		"woods":
			var n := 2 + _hash(c, r, 1) % 2
			var start := _hash(c, r, 2) % 4
			for i in range(n):
				var slot: Array = TREE_SLOTS[(start + i) % 4]
				var back := float(slot[1]) < 0.0
				var id := ("tree_a" if _hash(c, r, 3 + i) % 2 == 0 else "tree_b") if back else "tree_c"
				var j := Vector3((_hash(c, r, 10 + i) % 9 - 4) * 0.012, 0, (_hash(c, r, 20 + i) % 9 - 4) * 0.012)
				_put(id, top + Vector3(float(slot[0]), 0, float(slot[1])) + j, float(_hash(c, r, 30 + i) % 360), 1.0, s + i)
		"village":
			var id2 := "house_a" if _hash(c, r, 4) % 3 != 0 else "house_b"
			var side := -1.0 if _hash(c, r, 5) % 2 == 0 else 1.0
			_put(id2, top + Vector3(0.12 * side, 0, -0.24), (_hash(c, r, 6) % 3 - 1) * 12.0, 0.82, s)
			_put("tree_c", top + Vector3(-0.32 * side, 0, -0.3), 0.0, 0.7, s + 3)
		"high":
			if _hash(c, r, 7) % 2 == 0:
				var slot2: Array = TREE_SLOTS[_hash(c, r, 8) % 2]
				_put("rocks", top + Vector3(float(slot2[0]), 0, float(slot2[1])), float(_hash(c, r, 9) % 360), 1.0, s)
		"marsh":
			for i in range(2 + _hash(c, r, 11) % 2):
				var slot3: Array = TREE_SLOTS[(i + _hash(c, r, 12)) % 4]
				_put("reeds", top + Vector3(float(slot3[0]) * 0.9, 0, float(slot3[1]) * 0.9), 0.0, 1.0, s + i)
		"gate":
			_put("gate", top + Vector3(0.4, 0, 0), 0.0, 1.0, s)
		"eagle":
			_put("eagle", top + Vector3(-0.08, 0, -0.08), 0.0, 1.0, s)
		"bridge":
			var along_x: bool = str(_terr.get(Vector2i(c - 1, r), "river")) != "river" or str(_terr.get(Vector2i(c + 1, r), "river")) != "river"
			_put("bridge", Vector3(top.x, Terrain.top_of("bridge"), top.z), 0.0 if along_x else 90.0, 1.0, s)
		"earthwork":
			_put("earthwork", top + Vector3(0.3, 0, 0), 90.0, 1.0, s)
		"plain":
			if _hash(c, r, 13) % 4 == 0:
				var slot4: Array = TREE_SLOTS[_hash(c, r, 14) % 2]
				_put("tree_c", top + Vector3(float(slot4[0]) * 1.05, 0, float(slot4[1]) * 1.05), 0.0, 0.55, s)


# ================================================================ 单位

func _sync_units() -> void:
	var seen := {}
	ov_units = []
	var turn_changed := int(view.get("turn", 0)) != int(_prev.get("turn", 0)) and not _prev.is_empty()
	var animate := not _prev.is_empty()
	# 交火以后（回合数变了）按步回放；无头模式（测试）照旧一下子到位
	var staged := turn_changed and _staging_on()
	var steps: Array = []
	for _i in range(STEPS):
		steps.append([])
	for u in view.get("battle_units", []):
		var key := "u:" + str(u["uid"])
		seen[key] = true
		var cellv := Vector2i(int(u["col"]), int(u["row"]))
		var foot := cell_top(cellv.x, cellv.y)
		var node := _unit_for(key, u, false, 1.0)
		node.set_facing(str(u.get("facing", "right")))
		node.set_doomed(doomed.has(str(u["uid"])) and str(u.get("state", "ok")) != "dying")
		if staged and not bool(node.get_meta(&"new", false)):
			var dying := str(u.get("state", "ok")) == "dying"
			node.set_meta(&"shown_hp", int(node.get_meta(&"hp", int(u["hp"]))))
			steps[3].append(_staged_update.bind(node, foot, int(u["hp"]), dying))
		else:
			node.set_dying(str(u.get("state", "ok")) == "dying")
			node.set_meta(&"shown_hp", int(u["hp"]))
			_update_unit(node, foot, int(u["hp"]), animate)
		ov_units.append({"key": key, "data": u, "side": "ally", "foot": foot, "head": node.head, "n": 1, "cell": cellv})
	var by_cell := {}
	for e in view.get("enemies", []):
		var kc := Vector2i(int(e["col"]), int(e["row"]))
		if not by_cell.has(kc):
			by_cell[kc] = []
		by_cell[kc].append(e)
	for kc in by_cell:
		var list: Array = by_cell[kc]
		var n := list.size()
		var offs: Array = STACK.get(n, [])
		var scl := float(STACK_SCALE.get(n, 0.55))
		for i in range(n):
			var e: Dictionary = list[i]
			var key2 := "e:%d" % int(e["uid"])
			seen[key2] = true
			var off := Vector3.ZERO
			if i < offs.size():
				off = Vector3(float(offs[i][0]), 0, float(offs[i][1]))
			else:
				off = Vector3((i % 3 - 1) * 0.27, 0, (i / 3) * 0.26 - 0.2)
			var foot2 := cell_top(kc.x, kc.y) + off
			var node2 := _unit_for(key2, e, true, scl)
			# 同一格的敌人多了 / 少了（合到一格、同格的倒下、新来的落进来）：同一个节点换个大小，
			# 不删了重建——重建的会被当成新来的藏到最后，走位和挨打的飘字就丢了
			var rescale := not bool(node2.get_meta(&"new", false)) and not is_equal_approx(node2.token_scale, scl)
			if staged and bool(node2.get_meta(&"new", false)):
				# 新来的敌人最后才落下
				node2.set_meta(&"new", false)
				node2.position = foot2
				node2.set_meta(&"hp", int(e["hp"]))
				node2.set_meta(&"shown_hp", int(e["hp"]))
				node2.visible = false
				steps[4].append(_staged_arrive.bind(node2))
			elif staged:
				var before := int(node2.get_meta(&"hp", int(e["hp"])))
				# 叠加层回放时画的兵力：挨打那一步才降下来
				node2.set_meta(&"shown_hp", before)
				if int(e["hp"]) < before:
					steps[1].append(_staged_hit.bind(node2, before - int(e["hp"]), int(e["hp"])))
				node2.set_meta(&"hp", int(e["hp"]))
				if node2.position.distance_to(foot2) > 0.001 or rescale:
					steps[2].append(_staged_move.bind(node2, foot2, scl))
			else:
				if rescale:
					node2.set_token_scale(scl, animate)
				node2.set_meta(&"shown_hp", int(e["hp"]))
				_update_unit(node2, foot2, int(e["hp"]), animate)
			ov_units.append({"key": key2, "data": e, "side": "enemy", "foot": foot2, "head": node2.head, "n": n, "cell": kc})
	var eagle_hits := {}
	for it in _prev.get("intents", []):
		if str(it.get("type", "")) == "enemy" and str(it.get("attack", {}).get("kind", "")) == "eagle":
			var mt: Array = it.get("move_to", [])
			if mt.size() >= 2:
				eagle_hits["e:%d" % int(it.get("enemy", -1))] = cell_top(int(mt[0]), int(mt[1]))
	for key3 in _units.keys():
		if seen.has(key3):
			continue
		var gone: UnitView = _units[key3]
		_units.erase(key3)
		if not is_instance_valid(gone):
			continue
		gone.name = "Gone_%d" % gone.get_instance_id()
		if not staged:
			gone.play_down()
			_bump_anim()
		elif eagle_hits.has(key3):
			steps[4].append(_staged_eagle.bind(gone, eagle_hits[key3]))
		elif str(key3).begins_with("e:"):
			steps[1].append(_staged_down.bind(gone))
		else:
			steps[3].append(_staged_down.bind(gone))
	if turn_changed:
		_play_exchange(steps if staged else [])
	if staged:
		var dm := int(_prev.get("morale", 0)) - int(view.get("morale", 0))
		if dm > 0:
			steps[4].append(_float_at.bind(_eagle_point(eagle_hits) + Vector3(0, 1.0, 0), Ui.text("float_morale", {"n": "-%d" % dm}), "hd_warn", 26))
		_run_steps(steps)


## 交火回放开不开：有画面、在场景树里（无头测试一下子到位）
func _staging_on() -> bool:
	return is_inside_tree() and DisplayServer.get_name() != "headless"


## 交火回放还在放（面板据此决定点击是先跳过回放）
func is_playing() -> bool:
	return _playing


## 剩下的几步立刻放完（玩家点了东西、来了新视图）
func skip_playback() -> void:
	if _step_tw != null and _step_tw.is_valid():
		_step_tw.kill()
	_step_tw = null
	var rest := _steps
	_steps = []
	for step in rest:
		for f in step:
			(f as Callable).call()
	_end_playback()


## 回放放完：下一回合的敌情（路线、箭头、攻击线、伤害签）这时才亮出来，免得和刚打完的那一轮混在一起
func _end_playback() -> void:
	var was := _playing
	_playing = false
	if is_instance_valid(_intent_root):
		_intent_root.visible = true
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()
	if was:
		playback_finished.emit()


## 叠加层画的兵力：回放时是“已经放到哪一步”的兵力（挨打那一步才降），平时就是视图里的
func shown_hp(key: String, hp: int) -> int:
	if not _playing:
		return hp
	var n := unit_node(key)
	if n == null:
		return hp
	return int(n.get_meta(&"shown_hp", hp))


func _run_steps(steps: Array) -> void:
	_steps = steps
	_playing = true
	if is_instance_valid(_intent_root):
		_intent_root.visible = false
	_step_tw = create_tween()
	for i in range(steps.size()):
		_step_tw.tween_callback(_next_step)
		_step_tw.tween_interval(STEP_S)
	_step_tw.tween_callback(_end_playback)
	_anim_until = Time.get_ticks_msec() / 1000.0 + STEP_S * STEPS + ANIM_TAIL
	set_process(true)


func _next_step() -> void:
	if _steps.is_empty():
		return
	var step: Array = _steps.pop_front()
	for f in step:
		(f as Callable).call()


func _staged_update(node: UnitView, foot: Vector3, hp: int, dying: bool) -> void:
	if not is_instance_valid(node):
		return
	var before := int(node.get_meta(&"hp", hp))
	node.set_dying(dying)
	if node.position.distance_to(foot) > 0.001:
		node.move_to(foot, true)
	if hp < before:
		node.play_hit()
		_float_unit(node, "-%d" % (before - hp), "hd_enemy_hi")
	node.set_meta(&"hp", hp)
	node.set_meta(&"shown_hp", hp)
	_bump_anim()


func _staged_hit(node: UnitView, dmg: int, after: int) -> void:
	if not is_instance_valid(node):
		return
	node.play_hit()
	node.set_meta(&"shown_hp", after)
	_float_unit(node, "-%d" % dmg, "hd_gold_hi")
	_bump_anim()


func _staged_move(node: UnitView, foot: Vector3, scl: float) -> void:
	if is_instance_valid(node):
		node.set_token_scale(scl, true)
		node.move_to(foot, true)
		_bump_anim()


func _staged_arrive(node: UnitView) -> void:
	if not is_instance_valid(node):
		return
	node.visible = true
	node.appear()
	_bump_anim()


func _staged_down(node: UnitView) -> void:
	if is_instance_valid(node):
		node.play_down()
		_bump_anim()


## 冲进鹰旗：走到鹰旗格再倒下（军心的扣分在同一步飘出来）
func _staged_eagle(node: UnitView, at: Vector3) -> void:
	if not is_instance_valid(node):
		return
	node.move_to(at, true)
	var t := node.create_tween()
	t.tween_interval(0.3)
	t.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.play_down())
	_bump_anim()


func _eagle_point(hits: Dictionary) -> Vector3:
	for k in hits:
		return hits[k]
	for kc in _terr:
		if str(_terr[kc]) == "eagle":
			return cell_top(kc.x, kc.y)
	return Vector3.ZERO


func _float_unit(node: UnitView, text: String, color_key: String) -> void:
	_float_at(node.position + Vector3(0, node.head * node.token_scale + 0.1, 0), text, color_key, 26)


## 飘字：投到屏幕上的那一点往上飘、淡出（伤害 -N、军心 -N）
func _float_at(world: Vector3, text: String, color_key: String, font_size: int) -> void:
	if _floats == null or not is_instance_valid(_floats):
		return
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override(&"font", HdTheme.font("num"))
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", HdTheme.color(color_key))
	l.add_theme_color_override(&"font_outline_color", HdTheme.alpha("hd_ink", 0.92))
	l.add_theme_constant_override(&"outline_size", 8)
	_floats.add_child(l)
	l.reset_size()
	var p := cam.project(world)
	l.position = (p - Vector2(l.size.x * 0.5, l.size.y)).round()
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 34.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.75)
	tw.chain().tween_callback(l.queue_free)


func _unit_for(key: String, d: Dictionary, enemy: bool, scl: float) -> UnitView:
	var n = _units.get(key, null)
	if n != null and is_instance_valid(n):
		return n
	var info := {"side": "enemy" if enemy else "ally", "kind": "enemy" if enemy else str(d.get("kind", "troop")),
		"cls": str(d.get("cls", "")), "ekind": str(d.get("kind", "")) if enemy else "",
		"elite": bool(d.get("elite", false)), "heavy": "heavy" in d.get("battle_tags", [])}
	if not enemy and str(d.get("kind", "")) == "companion":
		info["accent"] = HdArt.accent(str(d.get("uid", "")))
	var node := UnitView.new()
	node.setup(key, info, art_id_for(d, enemy), _props, _col, scl)
	_units_root.add_child(node)
	_units[key] = node
	node.set_meta(&"new", true)
	return node


func _update_unit(node: UnitView, foot: Vector3, hp: int, animate: bool) -> void:
	var fresh := bool(node.get_meta(&"new", false))
	if fresh:
		node.set_meta(&"new", false)
		node.position = foot
		node.set_meta(&"hp", hp)
		if animate:
			node.appear()
			_bump_anim()
		else:
			node._start_idle()
		return
	if node.position.distance_to(foot) > 0.001:
		node.move_to(foot, animate)
		_bump_anim()
	var before := int(node.get_meta(&"hp", hp))
	if hp < before:
		node.play_hit()
		_bump_anim()
	node.set_meta(&"hp", hp)


## 交火之后（回合数变了）：上一回合敌情里要打人的敌人往目标冲一下，射程里有敌人的我方单位往前冲一下。
## steps 不空时按步回放：我方往前冲放第 0 步，敌人往目标冲放第 3 步
func _play_exchange(steps: Array = []) -> void:
	for it in _prev.get("intents", []):
		if str(it.get("type", "")) != "enemy" or bool(it.get("cancelled", false)):
			continue
		var atk: Dictionary = it.get("attack", {})
		var kind := str(atk.get("kind", ""))
		if kind == "" or kind == "gun_aim":
			continue
		var node := unit_node("e:%d" % int(it.get("enemy", -1)))
		if node == null:
			continue
		var tgt := unit_node("u:" + str(atk.get("target", "")))
		var dir := Vector3(-1, 0, 0)
		if tgt != null:
			dir = tgt.position - node.position
		if not steps.is_empty():
			steps[3].push_front(_staged_attack.bind(node, dir))
			continue
		node.play_attack(dir)
		_bump_anim()
	var foes := {}
	for e in _prev.get("enemies", []):
		foes[Vector2i(int(e["col"]), int(e["row"]))] = true
	for u in _prev.get("battle_units", []):
		if str(u.get("state", "")) != "ok":
			continue
		var hit := false
		for pc in u.get("pattern", []):
			if foes.has(Vector2i(int(pc[0]), int(pc[1]))):
				hit = true
		var node2 := unit_node("u:" + str(u["uid"]))
		if hit and node2 != null:
			if not steps.is_empty():
				steps[0].append(_staged_attack.bind(node2, UnitView._dir_vec(str(u.get("facing", "right")))))
				continue
			node2.play_attack(UnitView._dir_vec(str(u.get("facing", "right"))))
			_bump_anim()


func _staged_attack(node: UnitView, dir: Vector3) -> void:
	if is_instance_valid(node):
		node.play_attack(dir)
		_bump_anim()


func _bump_anim() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_anim_until = Time.get_ticks_msec() / 1000.0 + ANIM_TAIL
	set_process(true)


func _process(_delta: float) -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()
	if Time.get_ticks_msec() / 1000.0 > _anim_until:
		set_process(false)


# ================================================================ 敌情（路线、移动箭头、准星、来敌）

func _sync_intents() -> void:
	var sig := JSON.stringify([view.get("intents", []), view.get("grid", {}).get("routes", []), view.get("turn", 0)])
	if sig == _intent_sig:
		return
	_intent_sig = sig
	_clear(_intent_root)
	for rt in view.get("grid", {}).get("routes", []):
		var pts: Array = []
		for pc in rt.get("cells", []):
			pts.append(Vector2i(int(pc[0]), int(pc[1])))
		_ribbon(pts, {"shape": Sh.LINE, "fill": _col("bt3d_route"), "dash": -4.0, "width_ratio": 0.1}, 0.1, 5, false)
	var drawn := {}
	var t := int(view.get("turn", 0))
	for it in view.get("intents", []):
		match str(it.get("type", "")):
			"enemy":
				var a := Vector2i(int(it["at"][0]), int(it["at"][1]))
				var b := Vector2i(int(it["move_to"][0]), int(it["move_to"][1]))
				if a == b:
					continue
				var cancelled := bool(it.get("cancelled", false))
				var path := _path(a, b)
				var pkey := str(path) + str(cancelled)
				if drawn.has(pkey):
					continue
				drawn[pkey] = true
				if cancelled:
					_ribbon(path, {"shape": Sh.LINE, "fill": _col("bt3d_cancelled"), "dash": 5.0}, 0.11, 7, true)
				else:
					_ribbon(path, {"shape": Sh.LINE, "fill": _col("bt3d_move"), "edge": _col("bt3d_move"), "glow": 1.0}, 0.14, 8, true)
			"crosshair":
				var cc := Vector2i(int(it["cell"][0]), int(it["cell"][1]))
				var now := bool(it.get("now", false))
				var spec := {"shape": Sh.CROSS, "edge": _col_a("bt3d_gun", 1.0 if now else 0.6),
					"fill": _col_a("bt3d_gun", 0.2 if now else 0.08), "pulse": 0.35 if now else 0.0}
				_intent_root.add_child(Sh.mark_node(spec, 9, cell_top(cc.x, cc.y) + Vector3(0, 0.03, 0), 0.94, 0.94))
			"wave":
				if int(it.get("turn", 0)) == t + 1:
					var wc := Vector2i(int(it["cell"][0]), int(it["cell"][1]))
					_intent_root.add_child(Sh.mark_node({"shape": Sh.CELL, "fill": _col_a("bt3d_wave", 0.22), "edge": _col("bt3d_wave"),
						"edge_w": 0.05, "glow": 0.3, "pulse": 0.5}, 6, cell_top(wc.x, wc.y) + Vector3(0, 0.02, 0), 1.0, 1.0))


## 从 a 走到 b 经过的格子（同一条路线上 a 在 b 前面）；找不到就直线
func _path(a: Vector2i, b: Vector2i) -> Array:
	for rt in view.get("grid", {}).get("routes", []):
		var cells: Array = rt.get("cells", [])
		var ia := -1
		var ib := -1
		for i in range(cells.size()):
			if Vector2i(int(cells[i][0]), int(cells[i][1])) == a:
				ia = i
			if Vector2i(int(cells[i][0]), int(cells[i][1])) == b:
				ib = i
		if ia >= 0 and ib > ia:
			var out: Array = []
			for i in range(ia, ib + 1):
				out.append(Vector2i(int(cells[i][0]), int(cells[i][1])))
			return out
	return [a, b]


## 一条贴地的带子（沿格子中心走），arrow 时末端加一个三角箭头
func _ribbon(cells: Array, spec: Dictionary, width: float, prio: int, arrow: bool) -> void:
	if cells.size() < 2:
		return
	var pts: Array = []
	for i in range(cells.size()):
		var cv: Vector2i = cells[i]
		pts.append(Vector3(cv.x, 0, cv.y))
	if arrow:
		var last: Vector3 = pts[pts.size() - 1]
		var prev: Vector3 = pts[pts.size() - 2]
		var dl := (last - prev).normalized()
		pts[pts.size() - 1] = last - dl * 0.24
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var run := 0.0
	for i in range(pts.size() - 1):
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var ca: Vector2i = cells[i]
		var cb: Vector2i = cells[mini(i + 1, cells.size() - 1)]
		var y := maxf(cell_top(ca.x, ca.y).y, cell_top(cb.x, cb.y).y) + 0.03
		var d := p1 - p0
		var seg := d.length()
		if seg < 0.001:
			continue
		var dn := d / seg
		var nrm := Vector3(-dn.z, 0, dn.x) * width * 0.5
		var a0 := Vector3(p0.x, y, p0.z) - dn * (width * 0.5 if i > 0 else 0.0)
		var a1 := Vector3(p1.x, y, p1.z)
		var u0 := run
		var u1 := run + seg
		for row in [[a0 - nrm, Vector2(u0, 0)], [a1 - nrm, Vector2(u1, 0)], [a1 + nrm, Vector2(u1, 1)],
				[a0 - nrm, Vector2(u0, 0)], [a1 + nrm, Vector2(u1, 1)], [a0 + nrm, Vector2(u0, 1)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(row[1])
			st.add_vertex(row[0])
		run = u1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = Sh.mark_material(spec, prio)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_intent_root.add_child(mi)
	if arrow:
		var lc: Vector2i = cells[cells.size() - 1]
		var pc: Vector2i = cells[cells.size() - 2]
		var dir := Vector3(lc.x - pc.x, 0, lc.y - pc.y).normalized()
		var tip := Vector3(lc.x, 0, lc.y) - dir * 0.08
		var y2 := maxf(cell_top(lc.x, lc.y).y, cell_top(pc.x, pc.y).y) + 0.032
		var yaw := rad_to_deg(atan2(-dir.z, dir.x))
		var head := Sh.mark_node({"shape": Sh.ARROW, "fill": spec.get("fill")}, prio + 1,
			Vector3(tip.x, y2, tip.z) - dir * 0.16, 0.34, width * 2.6, yaw)
		_intent_root.add_child(head)


# ================================================================ 高亮（每格两块：填充、边框）

func _build_cell_pool() -> void:
	_clear(_cells_root)
	_cell_fill.clear()
	_cell_edge.clear()
	_cell_style.clear()
	for r in range(rows):
		for c in range(cols):
			var top := cell_top(c, r)
			var f := Sh.mark_node({"shape": Sh.CELL}, 4, top + Vector3(0, 0.016, 0), 1.0, 1.0)
			f.visible = false
			_cells_root.add_child(f)
			var e := Sh.mark_node({"shape": Sh.CELL}, 10, top + Vector3(0, 0.02, 0), 1.0, 1.0)
			e.visible = false
			_cells_root.add_child(e)
			_cell_fill[Vector2i(c, r)] = f
			_cell_edge[Vector2i(c, r)] = e


func _draw() -> void:
	_sync_highlights()


func _sync_highlights() -> void:
	for key in _cell_fill:
		var tr := str(_terr.get(key, "plain"))
		var fs := ""
		if target_cells.has(key):
			fs = "target"
		elif pattern_cells.has(key):
			fs = "pattern"
		elif valid_cells.has(key):
			fs = "valid_high" if tr in Terrain.ROCKY else "valid"
		var es := ""
		if selected == key:
			es = "selected"
		elif hovered == key:
			es = "hover"
		_style_cell(key, fs, es)
	for key2 in _units:
		var node: UnitView = _units[key2]
		if is_instance_valid(node) and str(key2).begins_with("u:"):
			var uid := str(key2).substr(2)
			node.set_doomed(doomed.has(uid) and not node.dying)
	if is_instance_valid(_overlay):
		_overlay.queue_redraw()


func _style_cell(key: Vector2i, fs: String, es: String) -> void:
	var sig := fs + "|" + es
	if str(_cell_style.get(key, "|")) == sig:
		return
	_cell_style[key] = sig
	var f: MeshInstance3D = _cell_fill[key]
	var e: MeshInstance3D = _cell_edge[key]
	f.visible = fs != ""
	if fs != "":
		var fm := f.material_override as ShaderMaterial
		var spec: Dictionary = {}
		match fs:
			"target":
				spec = {"fill": _col_a("bt3d_target", 0.34), "edge": _col("bt3d_target"), "edge_w": 0.05, "glow": 0.35, "dash": 0.0, "pulse": 0.18}
			"pattern":
				spec = {"fill": _col_a("bt3d_pattern", 0.22), "edge": _col("bt3d_pattern"), "edge_w": 0.04, "glow": 0.25, "dash": 5.0, "pulse": 0.0}
			"valid_high":
				spec = {"fill": _col_a("bt3d_valid_high", 0.24), "edge": _col("bt3d_valid_high"), "edge_w": 0.045, "glow": 0.4, "dash": 0.0, "pulse": 0.15}
			_:
				spec = {"fill": _col_a("bt3d_valid_ground", 0.22), "edge": _col("bt3d_valid_ground"), "edge_w": 0.045, "glow": 0.4, "dash": 0.0, "pulse": 0.15}
		for k in spec:
			fm.set_shader_parameter(StringName(k), spec[k])
	e.visible = es != ""
	if es != "":
		var em := e.material_override as ShaderMaterial
		if es == "selected":
			for pair in [["fill", _col_a("bt3d_select", 0.16)], ["edge", _col("bt3d_select")], ["edge_w", 0.07], ["glow", 0.45], ["pulse", 0.25]]:
				em.set_shader_parameter(StringName(pair[0]), pair[1])
		else:
			for pair2 in [["fill", _col_a("bt3d_hover", 0.1)], ["edge", _col_a("bt3d_hover", 0.9)], ["edge_w", 0.035], ["glow", 0.2], ["pulse", 0.0]]:
				em.set_shader_parameter(StringName(pair2[0]), pair2[1])


## 透明格子按钮：只认这一格投到屏幕上的多边形（相邻格子的外接矩形会重叠，点哪算哪）
class CellButton extends Button:
	var poly := PackedVector2Array()
	var cell := Vector2i(-1, -1)
	var has_body := false
	var body_anchor := Vector2.ZERO

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
			add_theme_stylebox_override(st, empty)

	func _has_point(p: Vector2) -> bool:
		if not contains_local_point(p):
			return false
		return get_parent().cell_at_point(p + position) == cell

	func contains_local_point(p: Vector2) -> bool:
		if poly.size() < 3:
			return Rect2(Vector2.ZERO, size).has_point(p)
		return Geometry2D.is_point_in_polygon(p, poly)
