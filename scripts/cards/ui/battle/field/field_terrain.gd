# 3D 战场的地块：每格一块有厚度的板。平地类顶面高 0.18，高地 / 胸墙 0.5（四周露出岩层侧面），河、桥下、浅滩、
# 沼泽往下沉，顶面就是水面（河和浅滩的水会慢慢流）。相邻格子高低不同的地方补侧面，整张图四周有一圈往下到
# BASE_Y 的底座（像一块摆在桌上的沙盘）。顶面贴图：art/hd/tile/<tex>.png，没有就用 hd_placeholder 的无缝噪声贴图；
# 侧面 side_earth / side_rock。同一种贴图的格子合成一个网格（一张图只有十来次绘制）。没有 class_name，preload。
extends RefCounted

const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const Sh = preload("res://scripts/cards/ui/battle/field/field_shaders.gd")

const BASE_Y := -0.42
const GROUND := 0.18
const HIGH := 0.5
## 各地形的顶面高度（世界单位）
## 新地形沿用 HdArt 的注册占位贴图；虚空没有顶面或侧面。
const TOP := {"plain": GROUND, "road": GROUND, "village": GROUND, "woods": GROUND, "gate": GROUND, "eagle": GROUND,
	"high": HIGH, "earthwork": HIGH, "river": 0.03, "bridge": 0.03, "ford": 0.085, "marsh": 0.11,
	"void": 0.0, "sea": 0.0, "shallows": 0.06, "reef": 0.04, "deck": 0.30, "quarterdeck": 0.62, "rigging": 1.10, "mast": 0.90,
	"wall": 0.90, "building": GROUND, "rooftop": 0.75, "corridor": GROUND, "cell": GROUND, "door": GROUND, "catacomb": 0.12,
	"snow": GROUND, "mud": GROUND, "ice": GROUND, "sand": GROUND, "well": GROUND, "dune": HIGH, "rubble": GROUND,
	"beach": GROUND, "cave": GROUND, "dock": GROUND, "plank": GROUND, "hatch": GROUND, "street": GROUND}
## 站人的高度和顶面不一样的地形：桥（顶面是河水，人站在桥面上）
const STAND := {"bridge": GROUND}
## 水面流动的快慢（0 = 不流）
const FLOW := {"river": 1.0, "bridge": 1.0, "ford": 0.55}
## 顶面贴图没在清单里写 terrain 时的后备
const TEX_FALLBACK := {"plain": "grass", "gate": "grass", "eagle": "grass", "road": "road", "high": "rock",
	"village": "village_ground", "woods": "forest_floor", "river": "water", "bridge": "water", "ford": "ford",
	"marsh": "marsh", "earthwork": "earthwork_top"}
const ROCKY := ["high", "earthwork"]
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func top_of(terrain: String) -> float:
	return float(TOP.get(terrain, GROUND))


static func tex_id(terrain: String) -> String:
	if terrain == "void":
		return ""
	var t := HdArt.terrain_tex(terrain)
	return t if t != "" else str(TEX_FALLBACK.get(terrain, "grass"))


static func stand_of(terrain: String) -> float:
	return float(STAND.get(terrain, top_of(terrain)))


## 每格顶面高度（row-major）；stand = true 时给站人的高度（桥面）
static func heights(cells: Array, cols: int, rows: int, stand: bool = false) -> PackedFloat32Array:
	var hs := PackedFloat32Array()
	hs.resize(cols * rows)
	hs.fill(GROUND)
	for cd in cells:
		var c := int(cd.get("col", 0))
		var r := int(cd.get("row", 0))
		if c >= 0 and r >= 0 and c < cols and r < rows:
			var tr := str(cd.get("terrain", "plain"))
			hs[r * cols + c] = stand_of(tr) if stand else top_of(tr)
	return hs


## 在 root 下面搭好全部地块网格（root 先清空）。colors：配色键取色的函数（key -> Color）
static func build(root: Node3D, cells: Array, cols: int, rows: int, hs: PackedFloat32Array, colors: Callable) -> void:
	for ch in root.get_children():
		root.remove_child(ch)
		ch.queue_free()
	var terr := {}
	for cd in cells:
		terr[Vector2i(int(cd.get("col", 0)), int(cd.get("row", 0)))] = str(cd.get("terrain", "plain"))
	var tops := {}     # 贴图 id -> SurfaceTool
	var flows := {}    # 贴图 id -> 流速
	var sides := {}    # side_earth / side_rock -> SurfaceTool
	var fade: Color = colors.call("bt3d_side_fade")
	var white: Color = colors.call("hd_white")
	for r in range(rows):
		for c in range(cols):
			var tr: String = terr.get(Vector2i(c, r), "plain")
			if tr == "void":
				continue
			var h := hs[r * cols + c]
			var tid := tex_id(tr)
			if not tops.has(tid):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tops[tid] = st
				flows[tid] = float(FLOW.get(tr, 0.0))
			_top_quad(tops[tid], c, r, h)
			var sid := "side_rock" if tr in ROCKY else "side_earth"
			for d in DIRS:
				var n: Vector2i = Vector2i(c, r) + d
				var inside: bool = n.x >= 0 and n.y >= 0 and n.x < cols and n.y < rows and terr.get(n, "plain") != "void"
				var bottom := hs[n.y * cols + n.x] if inside else BASE_Y
				if bottom >= h - 0.001:
					continue
				if not sides.has(sid):
					var st2 := SurfaceTool.new()
					st2.begin(Mesh.PRIMITIVE_TRIANGLES)
					sides[sid] = st2
				_side_quad(sides[sid], c, r, d, h, bottom, white, fade)
	for tid in tops:
		var mi := MeshInstance3D.new()
		mi.name = "Top_" + str(tid)
		mi.mesh = (tops[tid] as SurfaceTool).commit()
		mi.material_override = top_material(str(tid), float(flows[tid]), colors)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	for sid in sides:
		var ms := MeshInstance3D.new()
		ms.name = "Side_" + str(sid)
		ms.mesh = (sides[sid] as SurfaceTool).commit()
		ms.material_override = side_material(str(sid))
		ms.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ms)


static func top_material(tid: String, flow: float, colors: Callable) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Sh.top_shader()
	m.set_shader_parameter(&"tex", HdPlaceholder.make_tile_tex(tid))
	m.set_shader_parameter(&"grid_col", colors.call("bt3d_grid"))
	m.set_shader_parameter(&"flow", flow)
	m.set_shader_parameter(&"shine", colors.call("bt3d_water_shine"))
	m.set_shader_parameter(&"tint", colors.call("bt3d_tint_water" if flow > 0.0 else "bt3d_tint_land"))
	m.set_shader_parameter(&"vary", 0.04 if flow > 0.0 else 0.08)
	return m


static func side_material(sid: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = HdPlaceholder.make_tile_tex(sid)
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return m


static func _top_quad(st: SurfaceTool, c: int, r: int, h: float) -> void:
	var a := Vector3(c - 0.5, h, r - 0.5)
	var b := Vector3(c + 0.5, h, r - 0.5)
	var cc := Vector3(c + 0.5, h, r + 0.5)
	var d := Vector3(c - 0.5, h, r + 0.5)
	for v in [a, b, cc, a, cc, d]:
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(v.x, v.z))
		st.add_vertex(v)


## 一块侧面：沿 d 方向那条边，从顶面 h 往下到 bottom；u 沿边（世界单位，侧面贴图左右无缝），
## v 从上沿 0 到底座 1（台阶只露出上半截：草皮 / 岩面那一条）；越往下越暗
static func _side_quad(st: SurfaceTool, c: int, r: int, d: Vector2i, h: float, bottom: float, white: Color,
		fade: Color) -> void:
	var span := maxf(h - BASE_Y, 0.01)
	var p0: Vector3
	var p1: Vector3
	if d.x != 0:
		var x := c + 0.5 * d.x
		p0 = Vector3(x, h, r - 0.5)
		p1 = Vector3(x, h, r + 0.5)
	else:
		var z := r + 0.5 * d.y
		p0 = Vector3(c - 0.5, h, z)
		p1 = Vector3(c + 0.5, h, z)
	var n := Vector3(d.x, 0, d.y)
	var q0 := Vector3(p0.x, bottom, p0.z)
	var q1 := Vector3(p1.x, bottom, p1.z)
	var u0 := p0.z if d.x != 0 else p0.x
	var u1 := p1.z if d.x != 0 else p1.x
	var vb := (h - bottom) / span
	var low := white.lerp(fade, clampf(vb, 0.0, 1.0) * 0.85)
	var verts := [[p0, Vector2(u0, 0.0), white], [p1, Vector2(u1, 0.0), white], [q1, Vector2(u1, vb), low],
		[p0, Vector2(u0, 0.0), white], [q1, Vector2(u1, vb), low], [q0, Vector2(u0, vb), low]]
	for row in verts:
		st.set_normal(n)
		st.set_color(row[2])
		st.set_uv(row[1])
		st.add_vertex(row[0])
