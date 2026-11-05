extends Node3D
## Mockup C: HD-2D style canal street of 青溪镇, built procedurally at runtime.
## Units: 1 m = 16 px of pixel art. X = along the street, Y = up, Z = toward the camera.
## Facades sit on z = 0, the street runs z 0..6.5, the canal edge is z = 6.5, water y = WY.

const PXM := 1.0 / 16.0
const WY := -1.1
var OUT_PNG := ""
var TEXDIR := ""
var layout: Dictionary
var texcache := {}
var groups := {}          # key -> {st, mat, tw, th, refl}
var mirror: Node3D
var cam: Camera3D
var zhouma_head := Vector3.ZERO
var frames := 0
var bubble_rect: TextureRect
var lock_rect: TextureRect


func _ready() -> void:
	TEXDIR = ProjectSettings.globalize_path("res://tex/")
	OUT_PNG = OS.get_environment("OUT_PNG")
	if OUT_PNG == "":
		OUT_PNG = ProjectSettings.globalize_path("res://../render.png")
	layout = JSON.parse_string(FileAccess.get_file_as_string("res://layout.json"))
	setup_groups()
	mirror = Node3D.new()
	mirror.name = "Mirror"
	mirror.transform = Transform3D(Basis.from_scale(Vector3(1, -1, 1)), Vector3(0, 2.0 * WY, 0))
	add_child(mirror)
	build_ground()
	build_buildings()
	build_back_row()
	build_bridge()
	commit_groups()
	build_water()
	build_props()
	build_people()
	build_env()
	build_ui()


func _process(_d: float) -> void:
	frames += 1
	if frames == 3:
		place_bubble()
	if frames == 14:
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT_PNG)
		print("saved ", OUT_PNG, " ", img.get_size(), " ", RenderingServer.get_current_rendering_method())
		get_tree().quit()


# ---------------------------------------------------------------- resources
func tex(name: String) -> Texture2D:
	if texcache.has(name):
		return texcache[name]
	var img := Image.load_from_file(TEXDIR + name)
	var t := ImageTexture.create_from_image(img)
	texcache[name] = t
	return t


func mat(texname: String, opts := {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if texname != "":
		m.albedo_texture = tex(texname)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = opts.get("rough", 0.92)
	m.metallic_specular = opts.get("spec", 0.25)
	if opts.has("color"):
		m.albedo_color = opts["color"]
	if opts.get("scissor", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
	if opts.get("triplanar", 0.0) > 0.0:
		m.uv1_triplanar = true
		var s: float = opts["triplanar"]
		m.uv1_scale = Vector3(s, s, s)
	if opts.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func setup_groups() -> void:
	add_group("street", "street.png", 768, 192)
	add_group("cwall", "canal_wall.png", 128, 24, true)
	add_group("plaster", "plaster.png", 64, 64)
	add_group("roof", "roof.png", 64, 64)
	add_group("roof_far", "roof_far.png", 64, 64)
	add_group("eave", "eave.png", 16, 5)
	add_group("ridge", "ridge.png", 16, 8)
	add_group("wood", "wood.png", 32, 32)
	add_group("plaster_far", "plaster.png", 64, 64)
	groups["plaster_far"].mat.albedo_color = Color(0.74, 0.72, 0.7)
	groups["roof_far"].mat.albedo_color = Color(0.85, 0.87, 0.92)
	for k in layout.facades.keys():
		add_group("f_" + k, layout.facades[k].tex, 1, 1)
	add_group("f_gable", layout.gable.tex, 1, 1)


func add_group(key: String, texname: String, tw: float, th: float, refl := false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	groups[key] = {"st": st, "mat": mat(texname), "tw": tw, "th": th, "refl": refl, "n": 0}


func commit_groups() -> void:
	for k in groups.keys():
		var g: Dictionary = groups[k]
		if g.n == 0:
			continue
		var mesh: ArrayMesh = g.st.commit()
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = g.mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		add_child(mi)
		if g.refl:
			var mm := mi.duplicate()
			mirror.add_child(mm)


# quad with p0..p3 counter-clockwise seen from the outside
func quad_uv(key: String, p: Array, uv: Array, n: Vector3) -> void:
	var g: Dictionary = groups[key]
	var st: SurfaceTool = g.st
	for i in [0, 2, 1, 0, 3, 2]:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])
	g.n += 1


# world-space tiling UVs: u along ua, v along va (both unit vectors), 16 px per metre
func wquad(key: String, p: Array, n: Vector3, ua: Vector3, va: Vector3, off := Vector2.ZERO) -> void:
	var g: Dictionary = groups[key]
	var su: float = 16.0 / g.tw
	var sv: float = 16.0 / g.th
	var uvs := []
	for q in p:
		uvs.append(Vector2(q.dot(ua) * su + off.x, q.dot(va) * sv + off.y))
	quad_uv(key, p, uvs, n)


func wbox(key: String, a: Vector3, b: Vector3, faces := "fblrt") -> void:
	# axis aligned box a=min b=max, plain tiling texture
	var x0 := a.x; var y0 := a.y; var z0 := a.z
	var x1 := b.x; var y1 := b.y; var z1 := b.z
	if "f" in faces:
		wquad(key, [Vector3(x0, y0, z1), Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1)], Vector3.FORWARD * -1, Vector3.RIGHT, Vector3.DOWN)
	if "b" in faces:
		wquad(key, [Vector3(x1, y0, z0), Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0)], Vector3(0, 0, -1), Vector3.LEFT, Vector3.DOWN)
	if "l" in faces:
		wquad(key, [Vector3(x0, y0, z0), Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0)], Vector3.LEFT, Vector3(0, 0, 1), Vector3.DOWN)
	if "r" in faces:
		wquad(key, [Vector3(x1, y0, z1), Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1)], Vector3.RIGHT, Vector3(0, 0, -1), Vector3.DOWN)
	if "t" in faces:
		wquad(key, [Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0)], Vector3.UP, Vector3.RIGHT, Vector3(0, 0, 1))


# front face mapped to a sub-rect [u0,u1]x[v0,v1] of a facade texture
func face_front(key: String, x0: float, x1: float, y0: float, y1: float, z: float, u0 := 0.0, u1 := 1.0, v0 := 0.0, v1 := 1.0) -> void:
	quad_uv(key, [Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)],
		[Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0), Vector2(u0, v0)], Vector3(0, 0, 1))


# ---------------------------------------------------------------- ground + canal walls
func build_ground() -> void:
	# two street blocks separated by the water lane x 6.5..10
	for seg in [[-40.0, 6.5], [10.0, 40.0]]:
		var x0: float = seg[0]; var x1: float = seg[1]
		var z0 := -16.0; var z1 := 6.5
		# top: big non-repeating pavement field, origin x=-24, z=-4
		quad_uv("street", [Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x0, 0, z0)],
			[suv(x0, z1), suv(x1, z1), suv(x1, z0), suv(x0, z0)], Vector3.UP)
		# canal face (front) + lane faces
		var yb := WY - 0.02
		wquad("cwall", [Vector3(x0, yb, z1), Vector3(x1, yb, z1), Vector3(x1, 0, z1), Vector3(x0, 0, z1)], Vector3(0, 0, 1), Vector3.RIGHT, Vector3.DOWN)
		if x1 < 9.0:
			wquad("cwall", [Vector3(x1, yb, z1), Vector3(x1, yb, z0), Vector3(x1, 0, z0), Vector3(x1, 0, z1)], Vector3.RIGHT, Vector3(0, 0, -1), Vector3.DOWN)
		else:
			wquad("cwall", [Vector3(x0, yb, z0), Vector3(x0, yb, z1), Vector3(x0, 0, z1), Vector3(x0, 0, z0)], Vector3.LEFT, Vector3(0, 0, 1), Vector3.DOWN)
	# coping curb along the canal
	var cm := mat("stone.png", {"triplanar": 0.5})
	for seg in [[-40.0, 6.5], [10.0, 40.0]]:
		var bx := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(seg[1] - seg[0], 0.12, 0.42)
		bx.mesh = bm
		bx.material_override = cm
		bx.position = Vector3((seg[0] + seg[1]) / 2.0, 0.04, 6.38)
		add_child(bx)


func suv(x: float, z: float) -> Vector2:
	return Vector2((x + 24.0) * 16.0 / 768.0, (z + 4.0) * 16.0 / 192.0)


# ---------------------------------------------------------------- buildings
func building(key: String, x0: float, depth: float, rise: float, opts := {}) -> void:
	var f: Dictionary = layout.facades[key]
	var w: float = f.w
	var h: float = f.h
	var x1 := x0 + w
	var z0 := -depth
	face_front("f_" + key, x0, x1, 0, h, 0)
	var fr: float = opts.get("frieze", 0.42)
	wbox("plaster", Vector3(x0, 0, z0), Vector3(x1, h + fr, 0), "blr")
	wbox("plaster", Vector3(x0, h, -0.01), Vector3(x1, h + fr, 0), "f")
	roof(x0, x1, 0.0, z0, h + fr, rise, opts.get("ovf", 0.45), 0.12, opts.get("up", 0.3))
	if f.has("pent_y"):
		pent(x0, x1, h - float(f.pent_y))
	for l in f.lanterns:
		lantern(Vector3(x0 + float(l[0]), h - float(l[1]) + 0.05, 0.32))


func roof(x0: float, x1: float, zf: float, zb: float, ytop: float, rise: float, ovf: float, ovs: float, upturn: float, key := "roof", far := false) -> void:
	var zr := (zf + zb) * 0.5
	var yr := ytop + rise
	var slope := rise / (zf - zr)
	var ze := zf + ovf
	var ye := ytop - ovf * slope
	var xa := x0 - ovs
	var xb := x1 + ovs
	var NX := 16
	var NT := 8
	var L: float = min(1.4, (xb - xa) * 0.3)
	var pts := []      # [ix][it]
	for ix in NX + 1:
		var x := lerpf(xa, xb, float(ix) / NX)
		var dend: float = min(x - xa, xb - x)
		var ef: float = clamp(1.0 - dend / L, 0.0, 1.0)
		ef = ef * ef
		var col := []
		for it in NT + 1:
			var t := float(it) / NT
			var z := lerpf(zr, ze, t) + 0.18 * ef * t * t
			var y := lerpf(yr, ye, t) - 0.16 * sin(PI * t) + upturn * ef * t * t
			col.append(Vector3(x, y, z))
		pts.append(col)
	var slen := Vector2(ze - zr, ye - yr).length()
	for ix in NX:
		for it in NT:
			var p0: Vector3 = pts[ix][it + 1]
			var p1: Vector3 = pts[ix + 1][it + 1]
			var p2: Vector3 = pts[ix + 1][it]
			var p3: Vector3 = pts[ix][it]
			var n := (p1 - p0).cross(p3 - p0).normalized()
			if n.y < 0:
				n = -n
			var vt0 := float(it + 1) / NT * slen * 16.0 / 64.0
			var vt1 := float(it) / NT * slen * 16.0 / 64.0
			var u0 := p0.x * 16.0 / 64.0
			var u1 := p1.x * 16.0 / 64.0
			quad_uv(key, [p0, p1, p2, p3], [Vector2(u0, vt0), Vector2(u1, vt0), Vector2(u1, vt1), Vector2(u0, vt1)], n)
	# fascia: round tile ends along the eave
	var fh := 0.2
	for ix in NX:
		var a: Vector3 = pts[ix][NT]
		var b: Vector3 = pts[ix + 1][NT]
		if not far:
			quad_uv("eave", [a - Vector3(0, fh, 0), b - Vector3(0, fh, 0), b, a],
				[Vector2(a.x, 1), Vector2(b.x, 1), Vector2(b.x, 0), Vector2(a.x, 0)], Vector3(0, 0, 1))
		else:
			quad_uv(key, [a - Vector3(0, fh, 0), b - Vector3(0, fh, 0), b, a],
				[Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0.05), Vector2(0, 0.05)], Vector3(0, 0, 1))
	# back slope (flat)
	var zbe := zb - 0.3
	var ybe := ytop - 0.3 * slope
	wquad(key, [Vector3(xb, ybe, zbe), Vector3(xa, ybe, zbe), Vector3(xa, yr, zr), Vector3(xb, yr, zr)], Vector3(0, 1, -1).normalized(), Vector3.LEFT, Vector3(0, 0, 1))
	# gable triangles
	var gk := "plaster_far" if far else "plaster"
	for gx in [x0, x1]:
		wquad(gk, [Vector3(gx, ytop, zf), Vector3(gx, ytop, zb), Vector3(gx, yr, zr), Vector3(gx, yr, zr)], Vector3.RIGHT, Vector3(0, 0, 1), Vector3.DOWN)
	# ridge with curled ends
	var rk := key if far else "ridge"
	var rh := 0.24
	var rw := 0.14
	var ry := yr - 0.08
	wquad(rk, [Vector3(xa + 0.15, ry, zr + rw), Vector3(xb - 0.15, ry, zr + rw), Vector3(xb - 0.15, ry + rh, zr + rw), Vector3(xa + 0.15, ry + rh, zr + rw)], Vector3(0, 0, 1), Vector3.RIGHT, Vector3.DOWN)
	wquad(rk, [Vector3(xa + 0.15, ry + rh, zr + rw), Vector3(xb - 0.15, ry + rh, zr + rw), Vector3(xb - 0.15, ry + rh, zr - rw), Vector3(xa + 0.15, ry + rh, zr - rw)], Vector3.UP, Vector3.RIGHT, Vector3(0, 0, 1))
	if not far:
		for side in [-1, 1]:
			var ex: float = xa + 0.15 if side < 0 else xb - 0.15
			var curl := MeshInstance3D.new()
			var cb := BoxMesh.new()
			cb.size = Vector3(0.42, 0.2, 0.24)
			curl.mesh = cb
			curl.material_override = groups["roof"].mat
			curl.position = Vector3(ex + side * 0.08, ry + rh + 0.06, zr)
			curl.rotation = Vector3(0, 0, side * deg_to_rad(28))
			add_child(curl)
			var tip := MeshInstance3D.new()
			var tb := BoxMesh.new()
			tb.size = Vector3(0.16, 0.2, 0.2)
			tip.mesh = tb
			tip.material_override = groups["roof"].mat
			tip.position = Vector3(ex + side * 0.27, ry + rh + 0.22, zr)
			tip.rotation = Vector3(0, 0, side * deg_to_rad(-20))
			add_child(tip)


func pent(x0: float, x1: float, y: float) -> void:
	# lean-to eave between the storeys
	var NX := 12
	var xa := x0 - 0.08
	var xb := x1 + 0.08
	var L: float = 1.0
	var prev_a := Vector3.ZERO
	var prev_b := Vector3.ZERO
	for ix in NX + 1:
		var x := lerpf(xa, xb, float(ix) / NX)
		var dend: float = min(x - xa, xb - x)
		var ef: float = clamp(1.0 - dend / L, 0.0, 1.0)
		ef = ef * ef
		var a := Vector3(x, y + 0.12, 0.0)
		var b := Vector3(x, y - 0.24 + 0.2 * ef, 0.62 + 0.08 * ef)
		if ix > 0:
			var n := Vector3(0, 1, 0.55).normalized()
			quad_uv("roof", [prev_b, b, a, prev_a],
				[Vector2(prev_b.x / 4.0, 0.2), Vector2(b.x / 4.0, 0.2), Vector2(b.x / 4.0, 0.0), Vector2(prev_a.x / 4.0, 0.0)], n)
			quad_uv("eave", [prev_b - Vector3(0, 0.18, 0), b - Vector3(0, 0.18, 0), b, prev_b],
				[Vector2(prev_b.x, 1), Vector2(b.x, 1), Vector2(b.x, 0), Vector2(prev_b.x, 0)], Vector3(0, 0, 1))
		prev_a = a
		prev_b = b


func build_buildings() -> void:
	building("sun", -19.75, 3.0, 0.8, {"ovf": 0.3, "up": 0.2, "frieze": 0.3})
	building("tea", -14.0, 4.2, 1.1, {"frieze": 0.36})
	building("pawn", -9.375, 4.4, 1.35, {"frieze": 0.55})
	gable_wall(-5.0)
	building("rice", -1.5, 4.2, 1.05, {"ovf": 0.55, "frieze": 0.3})
	building("pharm", 2.625, 4.2, 1.25)
	building("police", 10.0, 4.2, 1.05, {"frieze": 0.3})
	building("post", 14.125, 4.2, 1.25)


func gable_wall(x0: float) -> void:
	# stepped 马头墙 with the giant 当, 0.55 m thick, warehouse roof behind
	var g: Dictionary = layout.gable
	var W: float = g.w
	var H: float = g.h
	var steps := [[0, 12, 26], [12, 22, 13], [22, 34, 0], [34, 44, 13], [44, 56, 26]]
	var t := 0.55
	for s in steps:
		var a: float = x0 + float(s[0]) * PXM
		var b: float = x0 + float(s[1]) * PXM
		var top: float = H - float(s[2]) * PXM
		face_front("f_gable", a, b, 0, top, 0, float(s[0]) / 56.0, float(s[1]) / 56.0, float(s[2]) * PXM / H, 1.0)
		wbox("plaster", Vector3(a, 0, -t), Vector3(b, top, 0), "blr")
		# tile cap
		cap(a - 0.04, b + 0.04, top, -t, s)
	# warehouse behind
	var bh := 4.1
	wbox("plaster", Vector3(x0 + 0.05, 0, -5.0), Vector3(x0 + W - 0.05, bh, -t), "lr")
	roof(x0 + 0.05, x0 + W - 0.05, -t, -5.0, bh, 1.0, 0.2, 0.05, 0.15)


func cap(a: float, b: float, top: float, zb: float, s: Array) -> void:
	var zf := 0.12
	var zbb := zb - 0.12
	var zm := (zf + zbb) * 0.5
	var yb := top - 0.02
	var yr := top + 0.2
	var ext_l: float = 0.0
	var ext_r: float = 0.0
	# horse-head (座头) on the outer ends
	if int(s[0]) == 0 or int(s[0]) == 12:
		ext_l = 0.1
	if int(s[1]) == 56 or int(s[1]) == 44:
		ext_r = 0.1
	if int(s[0]) == 22:
		ext_l = 0.1
		ext_r = 0.1
	var xa := a - ext_l
	var xb := b + ext_r
	wquad("roof", [Vector3(xa, yb, zf), Vector3(xb, yb, zf), Vector3(xb, yr, zm), Vector3(xa, yr, zm)], Vector3(0, 1, 1).normalized(), Vector3.RIGHT, Vector3(0, 0, -1))
	wquad("roof", [Vector3(xb, yb, zbb), Vector3(xa, yb, zbb), Vector3(xa, yr, zm), Vector3(xb, yr, zm)], Vector3(0, 1, -1).normalized(), Vector3.LEFT, Vector3(0, 0, 1))
	quad_uv("eave", [Vector3(xa, yb - 0.12, zf), Vector3(xb, yb - 0.12, zf), Vector3(xb, yb, zf), Vector3(xa, yb, zf)],
		[Vector2(xa * 2, 1), Vector2(xb * 2, 1), Vector2(xb * 2, 0), Vector2(xa * 2, 0)], Vector3(0, 0, 1))
	for side in [-1, 1]:
		if (side < 0 and ext_l > 0) or (side > 0 and ext_r > 0):
			var ex: float = xa if side < 0 else xb
			var hd := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.36, 0.13, 0.22)
			hd.mesh = bm
			hd.material_override = groups["roof"].mat
			hd.position = Vector3(ex + side * 0.06, yr + 0.06, zm)
			hd.rotation = Vector3(0, 0, side * deg_to_rad(30))
			add_child(hd)


func build_back_row() -> void:
	# second row of houses + a few trees, greyer; DOF/fog push them back
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	var x := -26.0
	while x < 26.0:
		var w := rnd.randf_range(3.5, 6.5)
		var h := rnd.randf_range(4.2, 6.2)
		var z0 := rnd.randf_range(-7.0, -6.2)
		var d := 5.0
		wbox("plaster_far", Vector3(x, 0, z0 - d), Vector3(x + w, h, z0), "flr")
		roof(x, x + w, z0, z0 - d, h, rnd.randf_range(1.3, 1.8), 0.4, 0.1, 0.25, "roof_far", true)
		x += w + rnd.randf_range(-0.2, 0.6)
	x = -24.0
	while x < 24.0:
		var w2 := rnd.randf_range(4.0, 7.0)
		var h2 := rnd.randf_range(5.5, 7.5)
		var z2 := -13.5
		wbox("plaster_far", Vector3(x, 0, z2 - 5.0), Vector3(x + w2, h2, z2), "flr")
		roof(x, x + w2, z2, z2 - 5.0, h2, 1.6, 0.4, 0.1, 0.25, "roof_far", true)
		x += w2 + 0.2
	for tx in [-19.0, -9.5, -3.0, 4.0, 9.0, 17.0]:
		var tr := sprite("willow_48x64.png", Vector3(tx, 1.5 + rnd.randf_range(0, 1.5), -12.4), 0.15)
		tr.modulate = Color(0.55, 0.62, 0.55)


# ---------------------------------------------------------------- bridge
func hump(x: float) -> float:
	var c := 8.25
	var hw := 2.45
	var t: float = clamp(abs(x - c) / hw, 0.0, 1.0)
	return 0.95 * pow(1.0 - t * t, 0.75)


func build_bridge() -> void:
	var sm := mat("stone.png", {"triplanar": 0.5})
	var dark := mat("stone.png", {"triplanar": 0.5, "color": Color(0.82, 0.8, 0.76)})
	var c := 8.25
	var r := 1.42
	var zf := 4.7
	var depth := 3.2
	var prof := PackedVector2Array()
	var xs := 5.7
	var xe := 10.8
	prof.append(Vector2(xs, WY - 0.3))
	for i in 25:
		var x := lerpf(xs, xe, float(i) / 24.0)
		prof.append(Vector2(x, max(0.02, hump(x))))
	prof.append(Vector2(xe, WY - 0.3))
	for i in 17:
		var a := lerpf(0.0, PI, float(i) / 16.0)
		prof.append(Vector2(c + r * cos(a), WY - 0.3 + 0.3 + r * sin(a) * 1.0 + (0.0 if i in [0, 16] else 0.0)))
	var body := CSGPolygon3D.new()
	body.polygon = prof
	body.depth = depth
	body.position = Vector3(0, 0, zf)
	body.material = sm
	var parts := [body]
	# voussoir ring on both faces
	for zz in [zf + 0.05, zf - depth]:
		var ring := PackedVector2Array()
		var r2 := r + 0.26
		for i in 17:
			var a := lerpf(0.0, PI, float(i) / 16.0)
			ring.append(Vector2(c + r2 * cos(a), WY + r2 * sin(a)))
		for i in 17:
			var a := lerpf(PI, 0.0, float(i) / 16.0)
			ring.append(Vector2(c + r * cos(a), WY + r * sin(a)))
		var rg := CSGPolygon3D.new()
		rg.polygon = ring
		rg.depth = 0.05
		rg.position = Vector3(0, 0, zz)
		rg.material = dark
		parts.append(rg)
	# parapets
	for zz in [zf + 0.02, zf - depth + 0.26]:
		var pp := PackedVector2Array()
		var xa := 6.0
		var xb := 10.5
		for i in 21:
			var x := lerpf(xa, xb, float(i) / 20.0)
			pp.append(Vector2(x, hump(x) + 0.55))
		for i in 21:
			var x := lerpf(xb, xa, float(i) / 20.0)
			pp.append(Vector2(x, hump(x) - 0.05))
		var par := CSGPolygon3D.new()
		par.polygon = pp
		par.depth = 0.24
		par.position = Vector3(0, 0, zz)
		par.material = dark
		parts.append(par)
		# end posts
		for px in [xa, xb]:
			var post := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.3, 0.8, 0.3)
			post.mesh = bm
			post.material_override = sm
			post.position = Vector3(px, hump(px) + 0.3, zz - 0.12)
			parts.append(post)
	for p in parts:
		add_child(p)
		var m: Node3D = p.duplicate()
		mirror.add_child(m)
	# lane walls under the bridge are the street blocks' side faces


# ---------------------------------------------------------------- water
func build_water() -> void:
	var wm := StandardMaterial3D.new()
	wm.albedo_texture = tex("water.png")
	wm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(0.62, 0.8, 0.74, 0.62)
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.uv1_scale = Vector3(80.0 / 4.0, 50.0 / 4.0, 1)
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 50)
	var wi := MeshInstance3D.new()
	wi.mesh = pm
	wi.material_override = wm
	wi.position = Vector3(0, WY, 9.0)
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wi)
	# deep bed: dark teal so the mirror world reads as a darker reflection
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.36, 0.5, 0.5)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var bp := PlaneMesh.new()
	bp.size = Vector2(80, 50)
	var bi := MeshInstance3D.new()
	bi.mesh = bp
	bi.material_override = bm
	bi.position = Vector3(0, WY - 6.0, 9.0)
	add_child(bi)


# ---------------------------------------------------------------- sprites
func sprite(texname: String, pos: Vector3, psize := PXM, bb := BaseMaterial3D.BILLBOARD_ENABLED) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex(texname)
	s.pixel_size = psize
	s.billboard = bb
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.centered = true
	s.offset = Vector2(0, s.texture.get_height() / 2.0)
	s.position = pos
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.modulate = Color(1.0, 0.97, 0.9)
	add_child(s)
	return s


func blob(pos: Vector3, rx: float, rz: float, a := 0.55) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("blob.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1, a)
	var q := PlaneMesh.new()
	q.size = Vector2(rx * 2, rz * 2)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos + Vector3(0.08, 0.012, -0.05)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func char_sprite(name: String, pos: Vector3, row: int, col := 0) -> Sprite3D:
	var s := sprite(name + "_sheet.png", pos)
	s.hframes = 3
	s.vframes = 4
	s.frame = row * 3 + col
	s.offset = Vector2(0, 16)
	blob(pos, 0.45, 0.22)
	return s


func glow(pos: Vector3, size: float, col: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("glow.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.no_depth_test = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func lantern(top: Vector3) -> void:
	var s := sprite("lantern_red.png", top)
	s.offset = Vector2(0, -7)
	s.modulate = Color(1.6, 1.25, 1.1)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.28)
	l.light_energy = 1.4
	l.omni_range = 3.2
	l.position = top + Vector3(0, -0.5, 0.25)
	add_child(l)
	glow(top + Vector3(0, -0.45, 0.1), 1.6, Color(1.0, 0.55, 0.3, 0.55))


func lamp_post(pos: Vector3) -> void:
	sprite("lantern_post.png", pos)
	blob(pos, 0.3, 0.15, 0.4)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 1.0
	l.omni_range = 3.5
	l.position = pos + Vector3(0, 1.75, 0.2)
	add_child(l)
	glow(pos + Vector3(0, 1.72, 0.05), 1.3, Color(1.0, 0.75, 0.4, 0.5))


func build_props() -> void:
	# willows along the canal
	for w in [[-15.0, 6.0, 1.4], [-4.2, 6.05, 1.0], [14.6, 5.9, 1.35], [-23.0, 6.0, 1.4]]:
		var p := Vector3(w[0], 0, w[1])
		var s := sprite("willow_48x64.png", p, PXM * float(w[2]))
		s.modulate = Color(0.8, 0.84, 0.6)
		blob(p + Vector3(0.6, 0, -0.6), 1.9, 0.9, 0.42)
	# street lamps
	for x in [-11.5, 0.6, 11.3]:
		lamp_post(Vector3(x, 0, 6.0))
	# props
	var P := [
		["water_vat.png", -5.6, 0.55], ["barrel.png", -10.0, 0.45],
		["rice_sacks.png", 0.1, 0.75], ["baskets.png", 1.6, 0.7], ["crates.png", -1.0, 0.5],
		["bench.png", -12.6, 0.9], ["tea_table.png", -12.0, 2.3],
		["herb_rack.png", 4.6, 0.75], ["flowerpot.png", 2.9, 0.45],
		["notice_board.png", 14.5, 0.6], ["mailbox.png", 17.0, 0.6], ["bush_flower.png", -4.6, 0.55],
		["grass_tuft_1.png", 10.6, 0.3], ["grass_tuft_2.png", 13.4, 0.3], ["bollard.png", -7.0, 6.05], ["bollard.png", 1.2, 6.05],
		["rickshaw.png", 1.9, 4.7], ["laundry_pole.png", -12.6, 5.2],
	]
	for p in P:
		var pos := Vector3(p[1], 0, p[2])
		var s := sprite(p[0], pos)
		var w: float = s.texture.get_width() * PXM
		blob(pos, w * 0.55, 0.2, 0.45)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_color = Color(1.0, 0.86, 0.6)
	gm.render_priority = 3
	gm.no_depth_test = false
	var grnd := RandomNumberGenerator.new()
	grnd.seed = 11
	for i in 46:
		var q := PlaneMesh.new()
		q.size = Vector2(grnd.randf_range(0.18, 0.55), 0.0625)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = gm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var gx := grnd.randf_range(-16, 16)
		var gz := grnd.randf_range(7.0, 11.0)
		mi.position = Vector3(snappedf(gx, 0.0625), WY + 0.03, snappedf(gz, 0.0625))
		add_child(mi)
	var trnd := RandomNumberGenerator.new()
	trnd.seed = 21
	for i in 26:
		var tz := 0.25 if i % 2 == 0 else 6.1
		var tx := trnd.randf_range(-15, 17)
		if tx > 6.3 and tx < 10.2:
			continue
		sprite("grass_tuft_%d.png" % (1 + i % 2), Vector3(tx, 0, tz + trnd.randf_range(-0.05, 0.1)))
	var cat := sprite("cat_sit.png", Vector3(-4.9, 0, 1.0))
	blob(Vector3(-4.9, 0, 1.0), 0.4, 0.15, 0.5)
	# boats on the canal + their reflections
	boat("boat_48x22.png", Vector3(-3.5, WY + 0.02, 8.6))
	boat("boat_32x16.png", Vector3(-12.5, WY + 0.02, 7.3))
	boat("boat_32x16.png", Vector3(16.0, WY + 0.02, 7.2))
	for d in [[2.0, 9.6], [2.6, 9.9], [19.0, 9.0]]:
		sprite("duck.png", Vector3(d[0], WY + 0.02, d[1]))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 3
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mm.albedo_color = Color(1.0, 0.85, 0.55, 0.9)
	for i in 70:
		var q := QuadMesh.new()
		var sz := rnd.randf_range(0.05, 0.09)
		q.size = Vector2(sz, sz)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rnd.randf_range(-14, 9), rnd.randf_range(0.6, 4.5), rnd.randf_range(0.5, 6.0))
		add_child(mi)


func boat(texname: String, pos: Vector3) -> void:
	var s := sprite(texname, pos)
	var r := sprite(texname, pos)
	r.flip_v = true
	r.offset = Vector2(0, -s.texture.get_height() / 2.0)
	r.modulate = Color(0.55, 0.62, 0.66)
	r.position = pos + Vector3(0, 0, 0.02)


func build_people() -> void:
	# 沈如花 talking with 周妈 in front of 德厚当's door (door centre x ~ -7.2)
	char_sprite("zhouma", Vector3(-7.55, 0, 3.9), 2)
	char_sprite("ruhua", Vector3(-6.6, 0, 4.0), 1)
	zhouma_head = Vector3(-7.55, 2.1, 3.9)
	char_sprite("wangshan", Vector3(0.7, 0, 1.6), 0)
	char_sprite("zhang", Vector3(3.5, 0, 3.0), 1, 1)
	char_sprite("ma", Vector3(8.0, hump(8.0), 3.2), 1)
	char_sprite("police", Vector3(12.0, 0, 1.6), 0)
	char_sprite("xiaoding", Vector3(-1.2, 0, 3.6), 2, 1)
	var ch := sprite("chicken.png", Vector3(-0.9, 0, 3.5))
	blob(Vector3(-0.9, 0, 3.5), 0.2, 0.1)


# ---------------------------------------------------------------- environment / camera
func build_env() -> void:
	var sun := DirectionalLight3D.new()
	var dir := Vector3(0.62, -0.55, -0.56).normalized()
	sun.transform.basis = Basis.looking_at(dir, Vector3.UP)
	sun.light_color = Color(1.0, 0.83, 0.62)
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.86, 0.78, 0.64)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.56, 0.62, 0.78)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.9, 0.78, 0.62)
	env.fog_density = 0.55
	env.fog_depth_begin = 29.0
	env.fog_depth_end = 52.0
	env.fog_depth_curve = 1.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	cam = Camera3D.new()
	cam.fov = 30.0
	var target := Vector3(-0.5, 1.75, 2.5)
	var pitch := deg_to_rad(30.0)
	var dist := 27.5
	add_child(cam)
	cam.look_at_from_position(target + Vector3(0, sin(pitch), cos(pitch)) * dist, target, Vector3.UP)
	cam.near = 1.0
	cam.far = 200.0
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = dist + 3.5
	attr.dof_blur_far_transition = 6.0
	attr.dof_blur_near_enabled = true
	attr.dof_blur_near_distance = dist - 3.4
	attr.dof_blur_near_transition = 2.6
	attr.dof_blur_amount = 0.2
	cam.attributes = attr
	cam.current = true


func build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	# vignette + warm grade
	var vr := ColorRect.new()
	vr.size = Vector2(1280, 720)
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5, 0.48);
	d.x *= 1.5;
	float v = smoothstep(0.35, 0.95, length(d));
	COLOR = vec4(0.12, 0.06, 0.03, v * 0.55);
}
"""
	var sm := ShaderMaterial.new()
	sm.shader = sh
	vr.material = sm
	cl.add_child(vr)
	var rays := ColorRect.new()
	rays.size = Vector2(1280, 720)
	var rsh := Shader.new()
	rsh.code = """
shader_type canvas_item;
render_mode blend_add;
void fragment() {
	vec2 p = UV * vec2(1.7778, 1.0);
	vec2 dir = normalize(vec2(0.62, 1.0));
	vec2 nrm = vec2(dir.y, -dir.x);
	float s = dot(p, nrm);
	float b = 0.0;
	b += smoothstep(0.07, 0.0, abs(s - 0.02)) * 0.9;
	b += smoothstep(0.03, 0.0, abs(s + 0.16)) * 0.6;
	b += smoothstep(0.09, 0.0, abs(s + 0.40)) * 0.55;
	b += smoothstep(0.025, 0.0, abs(s + 0.62)) * 0.5;
	b += smoothstep(0.05, 0.0, abs(s - 0.22)) * 0.45;
	float along = dot(p, dir);
	float fade = smoothstep(1.25, 0.05, along) * smoothstep(-0.05, 0.25, along);
	COLOR = vec4(vec3(1.0, 0.8, 0.55) * b * fade * 0.075, 1.0);
}
"""
	var rsm := ShaderMaterial.new()
	rsm.shader = rsh
	rays.material = rsm
	cl.add_child(rays)
	var hud := TextureRect.new()
	hud.texture = tex("hud.png")
	hud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cl.add_child(hud)
	var b := TextureRect.new()
	b.name = "Bubble"
	b.texture = tex("bubble.png")
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cl.add_child(b)
	bubble_rect = b
	lock_rect = TextureRect.new()
	lock_rect.texture = tex("locktag.png")
	cl.add_child(lock_rect)


func place_bubble() -> void:
	var b := bubble_rect
	var sp := cam.unproject_position(zhouma_head)
	var tip: Array = layout.bubble_tip
	b.position = (sp - Vector2(tip[0], tip[1]) + Vector2(4, -6)).round()
	var lp := cam.unproject_position(Vector3(11.3, 3.4, 0.2))
	var lt: Array = layout.lock_tip
	lock_rect.position = (lp - Vector2(lt[0], lt[1])).round()
