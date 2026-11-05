# 3D 战场的摆件和小人占位：有 art/hd/prop/<id>.glb 就用真模型，没有就用代码搭的低多边形模型
# （树、农舍、红门、鹰旗与三色旗、胸墙、石桥、拒马、芦苇、乱石）；小人没有逐帧图时用一个“兵人”：
# 底座 + 腿 + 上衣 + 头 + 按兵种区分的帽子和家伙（双角帽、筒帽、熊皮帽、头盔；火枪、马刀、鼓、斧子；
# 骑兵连马，炮兵连炮，弹药车）。我方蓝衣、敌方红衣，主角金色肩章和腰带，伙伴系一条自己强调色的腰带。
# 模型都朝 +X（屏幕右侧），1 个单位 = 1 格，原点在底面中心。材质和网格按键缓存，一张图里共用。
# 颜色全走配色键 bt3d_*。没有 class_name，用的地方 new() 一个。
extends RefCounted

const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")

## 兵人的整体放大（一格宽 1；站着的人高约 0.9）
const FIG_SCALE := 1.65
const HATS := {"hero": "bicorne", "line": "bicorne", "medic": "bicorne", "drummer": "shako", "jager": "shako",
	"grenadier": "bearskin", "engineer": "bearskin", "hussar": "busby", "artillery": "shako",
	"whitecoat": "helmet", "grenz": "shako", "dragoon": "helmet", "hungarian": "bearskin", "leader": "bicorne",
	"gun": "helmet", "wagon": "helmet"}
const GEAR := {"hero": "sabre", "line": "musket", "grenadier": "musket", "jager": "rifle", "medic": "bag",
	"engineer": "axe", "drummer": "drum", "whitecoat": "musket", "grenz": "rifle", "hungarian": "musket",
	"leader": "sabre"}
const CAVALRY := ["hussar", "dragoon"]
const GUNS := ["artillery", "gun"]

var _mats: Dictionary = {}
var _meshes: Dictionary = {}


# ---------------- 材质、网格 ----------------

func mat(key: String, rough: float = 0.85) -> StandardMaterial3D:
	var k := "%s|%.2f" % [key, rough]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = CardTheme.color(StringName(key))
		m.roughness = rough
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		_mats[k] = m
	return _mats[k]


## 不在配色表里的颜色（伙伴的强调色，来自 HdArt.accent）
func mat_color(c: Color) -> StandardMaterial3D:
	var k := "#" + c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.7
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
		_mats[k] = m
	return _mats[k]


func box(sx: float, sy: float, sz: float) -> Mesh:
	var k := "box|%.3f|%.3f|%.3f" % [sx, sy, sz]
	if not _meshes.has(k):
		var m := BoxMesh.new()
		m.size = Vector3(sx, sy, sz)
		_meshes[k] = m
	return _meshes[k]


func cyl(rt: float, rb: float, h: float, seg: int = 14) -> Mesh:
	var k := "cyl|%.3f|%.3f|%.3f|%d" % [rt, rb, h, seg]
	if not _meshes.has(k):
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		m.radial_segments = seg
		m.rings = 1
		_meshes[k] = m
	return _meshes[k]


func sphere(r: float, seg: int = 16) -> Mesh:
	var k := "sph|%.3f|%d" % [r, seg]
	if not _meshes.has(k):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = seg
		m.rings = maxi(4, seg / 2)
		_meshes[k] = m
	return _meshes[k]


func capsule(r: float, h: float) -> Mesh:
	var k := "cap|%.3f|%.3f" % [r, h]
	if not _meshes.has(k):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = maxf(h, r * 2.0)
		m.radial_segments = 12
		m.rings = 4
		_meshes[k] = m
	return _meshes[k]


func prism(sx: float, sy: float, sz: float) -> Mesh:
	var k := "pri|%.3f|%.3f|%.3f" % [sx, sy, sz]
	if not _meshes.has(k):
		var m := PrismMesh.new()
		m.size = Vector3(sx, sy, sz)
		_meshes[k] = m
	return _meshes[k]


## 挂一个零件：rot 是角度（度）
func part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ---------------- 摆件 ----------------

## 一件摆件：有真模型用真模型，没有用占位；seed 决定占位的小变化（同一格每次都一样）
func prop(id: String, seed_value: int = 0) -> Node3D:
	var scene := HdArt.prop(id)
	if scene != null:
		var inst := scene.instantiate()
		if inst is Node3D:
			inst.set_meta(&"hd_placeholder", false)
			return inst
		var holder := Node3D.new()
		holder.add_child(inst)
		holder.set_meta(&"hd_placeholder", false)
		return holder
	var n := Node3D.new()
	n.name = "Prop_" + id
	n.set_meta(&"hd_placeholder", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + id.length() * 131 + 17
	match id:
		"tree_a": _tree_a(n, rng)
		"tree_b": _tree_b(n, rng)
		"tree_c": _tree_c(n, rng)
		"house_a": _house_a(n)
		"house_b": _house_b(n)
		"gate": _gate(n)
		"eagle": _eagle(n)
		"earthwork": _earthwork(n)
		"bridge": _bridge(n)
		"cheval": _cheval(n)
		"reeds": _reeds(n, rng)
		"rocks": _rocks(n, rng)
	return n


func _tree_a(n: Node3D, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.85, 1.1)
	part(n, cyl(0.028, 0.045, 0.32), mat("bt3d_trunk"), Vector3(0, 0.16, 0) * s)
	part(n, sphere(0.19), mat("bt3d_leaf_dark"), Vector3(0, 0.4, 0) * s, Vector3.ZERO, Vector3(1.1, 0.75, 1.1) * s)
	part(n, sphere(0.16), mat("bt3d_leaf"), Vector3(-0.08, 0.5, 0.05) * s, Vector3.ZERO, Vector3.ONE * s)
	part(n, sphere(0.15), mat("bt3d_leaf"), Vector3(0.09, 0.52, -0.03) * s, Vector3.ZERO, Vector3.ONE * s)
	part(n, sphere(0.12), mat("bt3d_leaf_hi"), Vector3(0.0, 0.64, 0.0) * s, Vector3.ZERO, Vector3.ONE * s)
	part(n, sphere(0.09), mat("bt3d_leaf_hi"), Vector3(-0.1, 0.6, -0.07) * s, Vector3.ZERO, Vector3.ONE * s)


func _tree_b(n: Node3D, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.9, 1.12)
	part(n, cyl(0.022, 0.032, 0.14), mat("bt3d_trunk"), Vector3(0, 0.07, 0) * s)
	part(n, sphere(0.11), mat("bt3d_cypress"), Vector3(0, 0.46, 0) * s, Vector3.ZERO, Vector3(1.0, 3.4, 1.0) * s)
	part(n, sphere(0.07), mat("bt3d_cypress_hi"), Vector3(0.03, 0.6, -0.02) * s, Vector3.ZERO, Vector3(1.0, 2.6, 1.0) * s)


func _tree_c(n: Node3D, rng: RandomNumberGenerator) -> void:
	var s := rng.randf_range(0.8, 1.1)
	part(n, sphere(0.11), mat("bt3d_bush"), Vector3(0, 0.08, 0) * s, Vector3.ZERO, Vector3(1, 0.8, 1) * s)
	part(n, sphere(0.085), mat("bt3d_leaf_hi"), Vector3(0.1, 0.07, 0.05) * s, Vector3.ZERO, Vector3(1, 0.8, 1) * s)
	part(n, sphere(0.08), mat("bt3d_bush"), Vector3(-0.08, 0.06, -0.06) * s, Vector3.ZERO, Vector3(1, 0.8, 1) * s)


func _house_a(n: Node3D) -> void:
	part(n, box(0.46, 0.26, 0.34), mat("bt3d_wall"), Vector3(0, 0.13, 0))
	part(n, prism(0.42, 0.17, 0.54), mat("bt3d_roof", 0.7), Vector3(0, 0.345, 0), Vector3(0, 90, 0))
	part(n, box(0.08, 0.15, 0.012), mat("bt3d_wood_dark"), Vector3(0.0, 0.075, 0.172))
	for x in [-0.15, 0.15]:
		part(n, box(0.07, 0.065, 0.012), mat("bt3d_window"), Vector3(x, 0.16, 0.172))
	part(n, box(0.05, 0.12, 0.05), mat("bt3d_stone"), Vector3(0.13, 0.42, -0.06))


func _house_b(n: Node3D) -> void:
	part(n, box(0.38, 0.22, 0.3), mat("bt3d_wall_b"), Vector3(0, 0.11, 0))
	part(n, prism(0.36, 0.16, 0.44), mat("bt3d_roof_b", 0.75), Vector3(0, 0.3, 0), Vector3(0, 90, 0))
	part(n, box(0.12, 0.14, 0.012), mat("bt3d_wood_dark"), Vector3(0.05, 0.07, 0.152))
	part(n, box(0.34, 0.07, 0.045), mat("bt3d_stone"), Vector3(-0.08, 0.035, 0.3))
	part(n, box(0.045, 0.07, 0.22), mat("bt3d_stone"), Vector3(-0.25, 0.035, 0.2))


## 红门：门洞朝 ±X（敌人从 +X 走向 -X），两根矮门柱在 z = ±0.41，上面一道横梁、门牌；
## 做得矮，免得从斜上方看过去挡住站在门里的敌人
func _gate(n: Node3D) -> void:
	for z in [-0.41, 0.41]:
		part(n, box(0.1, 0.5, 0.1), mat("bt3d_gate", 0.6), Vector3(0, 0.25, z))
		part(n, prism(0.16, 0.08, 0.16), mat("bt3d_gate_dark"), Vector3(0, 0.54, z))
		part(n, box(0.14, 0.05, 0.14), mat("bt3d_gate_dark"), Vector3(0, 0.025, z))
	part(n, box(0.08, 0.06, 0.94), mat("bt3d_gate", 0.6), Vector3(0, 0.46, 0))
	part(n, box(0.03, 0.1, 0.3), mat("bt3d_gate_dark"), Vector3(0.03, 0.38, 0))


## 鹰旗：沙袋围着旗杆，杆顶金鹰，挂一面三色旗（蓝白红，蓝色靠杆）
func _eagle(n: Node3D) -> void:
	for i in range(9):
		var a := TAU * i / 9.0
		part(n, capsule(0.04, 0.13), mat("bt3d_sandbag"), Vector3(cos(a) * 0.15, 0.04, sin(a) * 0.15),
			Vector3(90, -rad_to_deg(a), 0))
	part(n, cyl(0.013, 0.018, 1.0), mat("bt3d_pole"), Vector3(0, 0.5, 0))
	part(n, box(0.06, 0.025, 0.06), mat("bt3d_gold", 0.35), Vector3(0, 1.0, 0))
	part(n, sphere(0.032), mat("bt3d_gold", 0.35), Vector3(0, 1.04, 0))
	part(n, box(0.018, 0.05, 0.14), mat("bt3d_gold", 0.35), Vector3(0, 1.06, 0), Vector3(25, 0, 0))
	part(n, box(0.018, 0.05, 0.14), mat("bt3d_gold", 0.35), Vector3(0, 1.06, 0), Vector3(-25, 0, 0))
	var keys := ["bt3d_flag_blue", "bt3d_flag_white", "bt3d_flag_red"]
	for i in range(3):
		part(n, box(0.1, 0.22, 0.008), mat(keys[i], 0.9), Vector3(0.065 + i * 0.1, 0.84 - i * 0.008, 0.01 * i),
			Vector3(0, -8 + i * 6, -2 - i * 2))


## 胸墙：一排填土柳条筐沿 X 摆开（board 摆的时候转 90° 放到敌人来的那一边）
func _earthwork(n: Node3D) -> void:
	for x in [-0.36, -0.12, 0.12, 0.36]:
		part(n, cyl(0.1, 0.1, 0.2, 12), mat("bt3d_gabion"), Vector3(x, 0.1, 0.02))
		part(n, cyl(0.085, 0.085, 0.02, 12), mat("bt3d_earth"), Vector3(x, 0.205, 0.02))
	part(n, box(0.96, 0.08, 0.14), mat("bt3d_earth"), Vector3(0, 0.04, -0.13))


## 石桥：桥面沿 X，长 1、宽 0.62；原点放在水面，桥面顶比原点高 0.15，桥墩往下伸
func _bridge(n: Node3D) -> void:
	part(n, box(1.0, 0.05, 0.62), mat("bt3d_stone"), Vector3(0, 0.125, 0))
	for z in [-0.31, 0.31]:
		part(n, box(1.0, 0.075, 0.05), mat("bt3d_stone_dark"), Vector3(0, 0.19, z))
	for x in [-0.36, 0.36]:
		part(n, box(0.14, 0.4, 0.6), mat("bt3d_stone_dark"), Vector3(x, -0.08, 0))


## 拒马：一根横木沿 Z，三组交叉削尖的木桩
func _cheval(n: Node3D) -> void:
	part(n, cyl(0.035, 0.035, 0.84, 10), mat("bt3d_wood"), Vector3(0, 0.15, 0), Vector3(90, 0, 0))
	for z in [-0.3, 0.0, 0.3]:
		for a in [-38.0, 38.0]:
			part(n, cyl(0.004, 0.02, 0.46, 6), mat("bt3d_stake"), Vector3(0, 0.15, z), Vector3(0, 0, a))
			part(n, cyl(0.004, 0.02, 0.46, 6), mat("bt3d_stake"), Vector3(0, 0.15, z), Vector3(0, 0, a + 180.0))


func _reeds(n: Node3D, rng: RandomNumberGenerator) -> void:
	for i in range(7):
		var h := rng.randf_range(0.16, 0.3)
		var p := Vector3(rng.randf_range(-0.1, 0.1), h * 0.5, rng.randf_range(-0.1, 0.1))
		var tilt := Vector3(rng.randf_range(-12, 12), 0, rng.randf_range(-12, 12))
		part(n, cyl(0.004, 0.009, h, 5), mat("bt3d_reed"), p, tilt)
		if i % 3 == 0:
			part(n, capsule(0.013, 0.06), mat("bt3d_reed_head"), p + Vector3(0, h * 0.5, 0), tilt)


func _rocks(n: Node3D, rng: RandomNumberGenerator) -> void:
	for i in range(3):
		var r := rng.randf_range(0.04, 0.075)
		part(n, sphere(r, 8), mat("bt3d_rock", 0.95), Vector3(rng.randf_range(-0.1, 0.1), r * 0.35, rng.randf_range(-0.1, 0.1)),
			Vector3(0, rng.randf_range(0, 90), 0), Vector3(1.0, 0.6, 0.85))


# ---------------- 兵人 ----------------

## 一个兵人（朝 +X）。spec：side（ally / enemy）、kind（hero companion troop barricade enemy）、cls（我方兵种）、
## ekind（敌人种类）、accent（伙伴的强调色）
func figure(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Figure"
	var side := str(spec.get("side", "ally"))
	var kind := str(spec.get("kind", "troop"))
	var cls := str(spec.get("cls", "line"))
	var who := str(spec.get("ekind", "")) if side == "enemy" else ("hero" if kind == "hero" else cls)
	if cls == "barricade" or kind == "barricade":
		var ch := prop("cheval", 3)
		ch.rotation_degrees = Vector3(0, 0, 0)
		root.add_child(ch)
		return root
	var body := Node3D.new()
	body.name = "Body"
	body.scale = Vector3.ONE * FIG_SCALE
	root.add_child(body)
	var coat := mat("bt3d_enemy_coat" if side == "enemy" else ("bt3d_hero_coat" if kind == "hero" else "bt3d_ally_coat"))
	part(body, cyl(0.15, 0.16, 0.025, 24), mat("bt3d_base", 0.6), Vector3(0, 0.0125, 0))
	if who in GUNS:
		_gun_crew(body, side, coat, who)
	elif who == "wagon":
		_wagon(body)
	elif who in CAVALRY:
		_horse(body, side)
		_soldier(body, coat, who, kind, spec, Vector3(-0.02, 0.24, 0), true)
	else:
		_soldier(body, coat, who, kind, spec, Vector3.ZERO, false)
	return root


## 一个站着的兵（mounted 时只有上半身，坐在马上）
func _soldier(p: Node3D, coat: Material, who: String, kind: String, spec: Dictionary, at: Vector3, mounted: bool) -> void:
	if not mounted:
		for z in [-0.034, 0.034]:
			part(p, cyl(0.024, 0.028, 0.17, 8), mat("bt3d_breeches"), at + Vector3(0, 0.11, z))
			part(p, cyl(0.03, 0.03, 0.07, 8), mat("bt3d_boot", 0.5), at + Vector3(0.005, 0.06, z))
	var y0 := at.y + (0.2 if not mounted else 0.06)
	part(p, cyl(0.072, 0.094, 0.2, 14), coat, at + Vector3(0, y0 + 0.1, 0))
	part(p, box(0.03, 0.13, 0.13), coat, at + Vector3(-0.075, y0 + 0.02, 0), Vector3(0, 0, -12))
	for s in [-1.0, 1.0]:
		part(p, box(0.006, 0.2, 0.022), mat("bt3d_belt"), at + Vector3(0.079, y0 + 0.1, 0), Vector3(32.0 * s, 0, 0))
	for z in [-0.1, 0.1]:
		part(p, capsule(0.024, 0.18), coat, at + Vector3(0.01, y0 + 0.1, z), Vector3(signf(z) * 8.0, 0, -8))
	part(p, cyl(0.03, 0.035, 0.04, 10), mat("bt3d_skin"), at + Vector3(0, y0 + 0.215, 0))
	part(p, sphere(0.058), mat("bt3d_skin", 0.7), at + Vector3(0.004, y0 + 0.27, 0))
	if kind == "hero" or who == "leader":
		for z in [-0.085, 0.085]:
			part(p, sphere(0.026, 10), mat("bt3d_gold", 0.35), at + Vector3(0, y0 + 0.19, z), Vector3.ZERO, Vector3(1, 0.6, 1.3))
		part(p, cyl(0.098, 0.098, 0.028, 16), mat("bt3d_gold", 0.35), at + Vector3(0, y0 + 0.02, 0))
	elif kind == "companion" and spec.has("accent"):
		part(p, cyl(0.098, 0.098, 0.03, 16), mat_color(spec["accent"]), at + Vector3(0, y0 + 0.02, 0))
	_hat(p, str(HATS.get(who, "bicorne")), at + Vector3(0, y0 + 0.31, 0), kind, spec)
	_gear(p, str(GEAR.get(who, "musket" if not mounted else "sabre")), at + Vector3(0, y0, 0), mounted)


func _hat(p: Node3D, hat: String, at: Vector3, kind: String, spec: Dictionary) -> void:
	var plume: Material = mat_color(spec["accent"]) if kind == "companion" and spec.has("accent") else mat("bt3d_flag_red")
	match hat:
		"bicorne":
			part(p, sphere(0.1, 14), mat("bt3d_hat", 0.6), at + Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(0.36, 0.42, 1.0))
			part(p, sphere(0.02, 8), mat("bt3d_flag_white"), at + Vector3(0.032, 0.03, 0.045))
			if kind == "hero":
				part(p, box(0.004, 0.01, 0.19), mat("bt3d_gold", 0.35), at + Vector3(0.002, 0.055, 0))
		"shako":
			part(p, cyl(0.05, 0.058, 0.11, 12), mat("bt3d_hat", 0.6), at + Vector3(0, 0.035, 0))
			part(p, box(0.045, 0.008, 0.08), mat("bt3d_hat", 0.5), at + Vector3(0.05, -0.012, 0))
			part(p, sphere(0.02, 8), plume, at + Vector3(0.03, 0.1, 0))
		"bearskin":
			part(p, cyl(0.056, 0.068, 0.17, 12), mat("bt3d_fur", 0.95), at + Vector3(0, 0.06, 0))
			part(p, capsule(0.013, 0.09), plume, at + Vector3(0.0, 0.1, 0.06))
		"busby":
			part(p, cyl(0.055, 0.062, 0.1, 12), mat("bt3d_fur", 0.95), at + Vector3(0, 0.03, 0))
			part(p, capsule(0.012, 0.08), plume, at + Vector3(0.01, 0.1, 0.03))
		"helmet":
			part(p, sphere(0.064, 12), mat("bt3d_hat", 0.45), at + Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.05, 0.85, 1.0))
			part(p, box(0.13, 0.035, 0.022), mat("bt3d_crest", 0.6), at + Vector3(-0.005, 0.055, 0))


func _gear(p: Node3D, gear: String, at: Vector3, mounted: bool) -> void:
	match gear:
		"musket":
			part(p, cyl(0.009, 0.011, 0.44, 6), mat("bt3d_wood"), at + Vector3(0.03, 0.12, 0.125), Vector3(-6, 0, 0))
			part(p, cyl(0.003, 0.005, 0.1, 5), mat("bt3d_metal", 0.3), at + Vector3(0.03, 0.39, 0.13), Vector3(-6, 0, 0))
		"rifle":
			part(p, cyl(0.009, 0.011, 0.36, 6), mat("bt3d_wood"), at + Vector3(0.03, 0.1, 0.125), Vector3(-6, 0, 0))
		"sabre":
			var y := 0.18 if mounted else 0.06
			part(p, box(0.008, 0.26, 0.018), mat("bt3d_metal", 0.25), at + Vector3(0.08, y + 0.12, 0.11), Vector3(0, 0, -35))
			part(p, box(0.02, 0.012, 0.04), mat("bt3d_gold", 0.35), at + Vector3(0.02, y + 0.02, 0.11), Vector3(0, 0, -35))
		"bag":
			part(p, box(0.06, 0.07, 0.04), mat("bt3d_wood_dark"), at + Vector3(-0.02, 0.03, 0.11))
			part(p, box(0.026, 0.026, 0.005), mat("bt3d_flag_red"), at + Vector3(-0.02, 0.04, 0.132))
		"drum":
			part(p, cyl(0.06, 0.06, 0.07, 16), mat("bt3d_drum", 0.4), at + Vector3(0.05, 0.02, 0.09), Vector3(90, 0, 0))
			part(p, cyl(0.062, 0.062, 0.012, 16), mat("bt3d_flag_red"), at + Vector3(0.05, 0.02, 0.06), Vector3(90, 0, 0))
		"axe":
			part(p, cyl(0.008, 0.01, 0.36, 6), mat("bt3d_wood"), at + Vector3(0.03, 0.08, 0.125))
			part(p, box(0.07, 0.05, 0.01), mat("bt3d_metal", 0.3), at + Vector3(0.06, 0.25, 0.125))


func _horse(p: Node3D, side: String) -> void:
	var hide := mat("bt3d_horse_dark" if side == "enemy" else "bt3d_horse")
	part(p, capsule(0.085, 0.42), hide, Vector3(0, 0.27, 0), Vector3(0, 0, 90))
	part(p, capsule(0.048, 0.2), hide, Vector3(0.17, 0.37, 0), Vector3(0, 0, -40))
	part(p, capsule(0.042, 0.15), hide, Vector3(0.25, 0.43, 0), Vector3(0, 0, -105))
	part(p, capsule(0.02, 0.14), mat("bt3d_fur"), Vector3(-0.22, 0.26, 0), Vector3(0, 0, 30))
	for x in [-0.13, 0.13]:
		for z in [-0.045, 0.045]:
			part(p, cyl(0.016, 0.02, 0.22, 6), mat("bt3d_horse_leg"), Vector3(x, 0.11, z))
	part(p, box(0.16, 0.025, 0.2), mat("bt3d_ally_coat" if side == "ally" else "bt3d_enemy_coat"), Vector3(-0.02, 0.35, 0))


func _gun_crew(p: Node3D, side: String, coat: Material, who: String) -> void:
	var wood := mat("bt3d_carriage_enemy" if side == "enemy" else "bt3d_carriage")
	part(p, box(0.34, 0.05, 0.11), wood, Vector3(-0.06, 0.12, 0), Vector3(0, 0, 10))
	for z in [-0.095, 0.095]:
		part(p, cyl(0.1, 0.1, 0.025, 18), mat("bt3d_wood_dark"), Vector3(0.0, 0.1, z), Vector3(90, 0, 0))
		part(p, cyl(0.025, 0.025, 0.035, 8), mat("bt3d_metal", 0.3), Vector3(0.0, 0.1, z), Vector3(90, 0, 0))
	part(p, cyl(0.026, 0.038, 0.4, 12), mat("bt3d_bronze", 0.3), Vector3(0.08, 0.19, 0), Vector3(0, 0, -82))
	var crew := Node3D.new()
	crew.scale = Vector3.ONE * 0.8
	crew.position = Vector3(-0.2, 0, 0.14)
	p.add_child(crew)
	_soldier(crew, coat, who, "troop", {}, Vector3.ZERO, false)


func _wagon(p: Node3D) -> void:
	part(p, box(0.36, 0.12, 0.22), mat("bt3d_carriage_enemy"), Vector3(0, 0.19, 0))
	part(p, sphere(0.16, 14), mat("bt3d_canvas", 0.95), Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.15, 0.55, 0.72))
	for x in [-0.11, 0.11]:
		for z in [-0.125, 0.125]:
			part(p, cyl(0.075, 0.075, 0.022, 16), mat("bt3d_wood_dark"), Vector3(x, 0.075, z), Vector3(90, 0, 0))
	part(p, cyl(0.008, 0.008, 0.3, 6), mat("bt3d_wood"), Vector3(0.3, 0.12, 0), Vector3(0, 0, 80))
