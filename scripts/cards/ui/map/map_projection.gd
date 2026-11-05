## Pure presentation projection. Geographic outlines use the published Natural Earth
## view parameters; no campaign state or rules are read here.
extends RefCounted

const GEO_ROOT := "res://data/campaigns/napoleon/maps/geo/"
const CANVAS_SIZE := Vector2(1920, 1080)
static var _bases: Dictionary = {}


static func base_data(view: Dictionary) -> Dictionary:
	var id := str(view.get("base", ""))
	if id not in ["europe", "world", "med"]:
		return {}
	if not _bases.has(id):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(GEO_ROOT + id + ".json"))
		_bases[id] = data if typeof(data) == TYPE_DICTIONARY else {}
	return _bases[id]


static func canvas_size(view: Dictionary) -> Vector2:
	var v: Dictionary = base_data(view).get("view", {})
	return Vector2(float(v.get("width", CANVAS_SIZE.x)), float(v.get("height", CANVAS_SIZE.y)))


static func wraps(view: Dictionary) -> bool:
	return bool(base_data(view).get("view", {}).get("x_wraps", false))


static func project_geo(geo: Array, view: Dictionary) -> Vector2:
	if geo.size() < 2:
		return Vector2.ZERO
	var lon := float(geo[0]) / 100.0
	var lat := clampf(float(geo[1]) / 100.0, -89.0, 89.0)
	var v: Dictionary = base_data(view).get("view", {})
	if v.is_empty():
		# Older draft views gave explicit hundredths-of-degree bounds.
		var xs: Array = view.get("lon", [-18000, 18000])
		var ys: Array = view.get("lat", [-9000, 9000])
		return Vector2((float(geo[0]) - float(xs[0])) / maxf(1.0, float(xs[1]) - float(xs[0])) * CANVAS_SIZE.x,
			(float(ys[1]) - float(geo[1])) / maxf(1.0, float(ys[1]) - float(ys[0])) * CANVAS_SIZE.y)
	var scale := float(v["scale"])
	var x := scale * (deg_to_rad(lon) - deg_to_rad(float(v["lon_min"])))
	var y := log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0))
	if str(v.get("projection", "")) == "miller":
		y = 1.25 * log(tan(PI / 4.0 + 0.4 * deg_to_rad(lat)))
	return Vector2(x, scale * (float(v["y_top"]) - y))


static func node_point(node: Dictionary, view: Dictionary, frame_id: String = "") -> Vector2:
	var frames: Variant = node.get("xy_frames", {})
	if typeof(frames) == TYPE_DICTIONARY and typeof(frames.get(frame_id)) == TYPE_ARRAY:
		return _pair(frames[frame_id])
	if typeof(node.get("xy")) == TYPE_ARRAY and node["xy"].size() >= 2:
		return _pair(node["xy"])
	if typeof(node.get("geo")) == TYPE_ARRAY:
		return project_geo(node["geo"], view)
	return CANVAS_SIZE / 2.0


static func frame_center(frame: Dictionary, view: Dictionary) -> Vector2:
	var center: Variant = frame.get("center", [])
	if typeof(center) == TYPE_DICTIONARY:
		return node_point(center, view)
	if typeof(center) == TYPE_ARRAY and center.size() >= 2:
		if str(view.get("proj", "canvas")) != "canvas":
			return project_geo(center, view)
		return _pair(center)
	return canvas_size(view) / 2.0


static func _pair(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1])) if value.size() >= 2 else Vector2.ZERO
