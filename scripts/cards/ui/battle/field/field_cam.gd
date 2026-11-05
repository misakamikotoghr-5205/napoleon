# 3D 战场的相机：斜俯视的透视相机，把 cols×rows 的地图（连同地块高度、地图底座、最后一排小人的头顶和血条）
# 自动装进安全区（board 本地坐标）；投影算法和 Camera3D 一模一样（竖直 fov、KEEP_HEIGHT），所以不进场景树、
# 无头模式下也能把格子投到屏幕上（Cell_c_r 按钮的点击区、cell_rect、2D 叠加层都用它）。没有 class_name，preload。
# 坐标：格子 (col,row) 的中心在世界 (x=col, z=row)，地块顶面高度 y 由 field_terrain 给；一格 = 1 个单位。
extends RefCounted

const PITCH_DEG := 54.0   # 相机往下俯的角度（从水平算）
const FOV_DEG := 30.0     # 竖直视角：透视适中，远排略窄
const NEAR := 0.05
const FAR := 200.0
const HEAD_CLEAR := 1.45  # 最后一排要给小人和血条留的高度（世界单位）

var view_size := Vector2(1280, 720)   # 板子（视口）大小，像素
var safe := Rect2(0, 0, 1280, 720)    # 地图要装进的区域（板子本地坐标）
var xform := Transform3D.IDENTITY     # 相机的世界变换
var proj := Projection.IDENTITY
var _inv := Transform3D.IDENTITY
var dist := 10.0


## 按地图大小、各格顶面高度（row-major，长度 cols*rows）、地图底座深度装好相机
func fit(cols: int, rows: int, heights: PackedFloat32Array, base_y: float, p_size: Vector2, p_safe: Rect2) -> void:
	view_size = Vector2(maxf(p_size.x, 8.0), maxf(p_size.y, 8.0))
	safe = p_safe
	if safe.size.x < 4.0 or safe.size.y < 4.0:
		safe = Rect2(Vector2.ZERO, view_size)
	proj = Projection.create_perspective(FOV_DEG, view_size.x / view_size.y, NEAR, FAR, false)
	var pts := _fit_points(cols, rows, heights, base_y)
	var pitch := deg_to_rad(PITCH_DEG)
	var basis := Basis(Vector3.RIGHT, -pitch)
	var fwd := -basis.z
	var centre := Vector3((cols - 1) * 0.5, 0.25, (rows - 1) * 0.5)
	var off := Vector2.ZERO
	dist = maxf(4.0, float(maxi(cols, rows)) * 1.6)
	var tan_half := tan(deg_to_rad(FOV_DEG) * 0.5)
	for _i in range(10):
		_set_xform(Transform3D(basis, centre - fwd * dist + basis.x * off.x + basis.y * off.y))
		var bb := _bbox(pts)
		if bb.size.x <= 0.0 or bb.size.y <= 0.0:
			break
		var k := maxf(bb.size.x / safe.size.x, bb.size.y / safe.size.y)
		dist = clampf(dist * k, 1.5, 150.0)
		_set_xform(Transform3D(basis, centre - fwd * dist + basis.x * off.x + basis.y * off.y))
		bb = _bbox(pts)
		var delta := safe.get_center() - bb.get_center()
		var wpp := 2.0 * dist * tan_half / view_size.y
		off.x -= delta.x * wpp
		off.y += delta.y * wpp
	_set_xform(Transform3D(basis, centre - fwd * dist + basis.x * off.x + basis.y * off.y))


func _set_xform(t: Transform3D) -> void:
	xform = t
	_inv = t.affine_inverse()


## 世界坐标 → 板子本地像素坐标（和 Camera3D.unproject_position 一样）
func project(p: Vector3) -> Vector2:
	var v := _inv * p
	var clip := proj * Vector4(v.x, v.y, v.z, 1.0)
	var w := clip.w if absf(clip.w) > 0.00001 else 0.00001
	return Vector2((clip.x / w + 1.0) * 0.5 * view_size.x, (1.0 - clip.y / w) * 0.5 * view_size.y)


## 某个世界点附近，1 个世界单位（水平方向）在屏幕上有多少像素
func px_per_unit(p: Vector3) -> float:
	return project(p).distance_to(project(p + Vector3.RIGHT))


func _bbox(pts: PackedVector3Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var s := project(p)
		lo = Vector2(minf(lo.x, s.x), minf(lo.y, s.y))
		hi = Vector2(maxf(hi.x, s.x), maxf(hi.y, s.y))
	return Rect2(lo, hi - lo)


## 要装进安全区的点：每格顶面四角、地图四边的底座下沿、最后一排小人头顶（含血条）的高度
func _fit_points(cols: int, rows: int, heights: PackedFloat32Array, base_y: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for r in range(rows):
		for c in range(cols):
			var h := heights[r * cols + c] if r * cols + c < heights.size() else 0.2
			pts.append(Vector3(c - 0.5, h, r - 0.5))
			pts.append(Vector3(c + 0.5, h, r - 0.5))
			pts.append(Vector3(c - 0.5, h, r + 0.5))
			pts.append(Vector3(c + 0.5, h, r + 0.5))
			if r == 0:
				pts.append(Vector3(c, h + HEAD_CLEAR, 0.0))
	pts.append(Vector3(-0.5, base_y, rows - 0.5))
	pts.append(Vector3(cols - 0.5, base_y, rows - 0.5))
	pts.append(Vector3(-0.5, base_y, -0.5))
	pts.append(Vector3(cols - 0.5, base_y, -0.5))
	return pts
