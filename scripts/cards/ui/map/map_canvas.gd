## Public campaign.map view only. Camera, selection and zoom never enter the save.
extends Control

signal node_selected(id: String)
signal camera_changed

const MapProjection = preload("res://scripts/cards/ui/map/map_projection.gd")
const NODE_RADIUS := 13.0
const MIN_ZOOM := 1.0
const MAX_ZOOM := 3.0
const INK := Color("403b30")
const GOLD := Color("b58d43")
const RED := Color("9d5144")
const BLUE := Color("4d7483")
const PAPER_SHADER := "shader_type canvas_item; void fragment() { vec2 p = UV * vec2(850.0, 452.0); float grain = fract(sin(dot(floor(p), vec2(12.9898, 78.233))) * 43758.5453); float edge = pow(abs(UV.x - 0.5) * 2.0, 5.0) + pow(abs(UV.y - 0.5) * 2.0, 5.0); COLOR = vec4(vec3(0.83, 0.79, 0.67) + grain * 0.025 - edge * 0.045, 1.0); }"

var selected_node := ""
var _map: Dictionary = {}
var _view: Dictionary = {}
var _nodes: Dictionary = {}
var _sheet := ""
var _zoom := 1.0
var _camera := Vector2.ZERO
var _fit_scale := 1.0
var _frame := -1
var _press := Vector2.ZERO
var _pressed := false
var _dragged := false
var _hover := ""
var _layers: Array = []
var _base := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	var paper := ColorRect.new()
	paper.name = "Parchment"
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.show_behind_parent = true
	var shader := Shader.new()
	shader.code = PAPER_SHADER
	var material_paper := ShaderMaterial.new()
	material_paper.shader = shader
	paper.material = material_paper
	add_child(paper)
	resized.connect(_on_resized)
	queue_redraw()


func refresh(mapview: Dictionary) -> void:
	var identity := str(mapview.get("view", "")) + ":" + str(mapview.get("sheet", ""))
	var changed := identity != _sheet
	_sheet = identity
	_map = mapview.duplicate(true)
	_view = (_map.get("view_def", {}) as Dictionary).duplicate(true)
	_nodes.clear()
	for node in _map.get("nodes", []):
		_nodes[str(node["id"])] = node
	if changed or not _nodes.has(selected_node):
		selected_node = str(_map.get("pos", ""))
	_load_base()
	if changed:
		_reset_camera()
	else:
		var frame_index := _first_active_frame()
		if frame_index != _frame:
			set_frame(frame_index)
	queue_redraw()


func select_node(id: String, emit: bool = false) -> void:
	if not _nodes.has(id):
		return
	selected_node = id
	queue_redraw()
	if emit:
		node_selected.emit(id)


func set_zoom(value: float) -> void:
	_zoom = clampf(value, MIN_ZOOM, MAX_ZOOM)
	queue_redraw()
	camera_changed.emit()


func get_zoom() -> float:
	return _zoom


func set_frame(index: int) -> void:
	var frames: Array = _map.get("frames", [])
	_frame = index if index >= 0 and index < frames.size() else -1
	if _frame >= 0:
		var frame: Dictionary = frames[_frame]
		_camera = MapProjection.frame_center(frame, _view)
		_zoom = clampf(float(frame.get("zoom", 100)) / 100.0, MIN_ZOOM, MAX_ZOOM)
	queue_redraw()
	camera_changed.emit()


func get_frame() -> int:
	return _frame


func node_screen_position(id: String) -> Vector2:
	if not _nodes.has(id):
		return Vector2(-10000, -10000)
	return _screen(_node_point(_nodes[id])) + _offset(_nodes[id])


func hit_test(at: Vector2) -> String:
	var nearest := ""
	var distance := 23.0
	for id in _nodes:
		var next := node_screen_position(str(id)).distance_to(at)
		if next < distance:
			distance = next
			nearest = str(id)
	return nearest


func center_current() -> void:
	var id := str(_map.get("pos", ""))
	if _nodes.has(id):
		_camera = _node_point(_nodes[id])
		queue_redraw()
		camera_changed.emit()


func _first_active_frame() -> int:
	var frames: Array = _map.get("frames", [])
	for i in frames.size():
		# Conditions are evaluated by the backend; UI receives only the result.
		if bool(frames[i].get("active", not frames[i].has("when") or frames[i].get("when", {}).is_empty())):
			return i
	return -1


func _reset_camera() -> void:
	var extent := MapProjection.canvas_size(_view)
	_camera = extent / 2.0
	_fit_scale = minf(maxf(1.0, size.x - 100.0) / extent.x, maxf(1.0, size.y - 100.0) / extent.y)
	_zoom = 1.0
	if not _nodes.is_empty():
		var bounds := Rect2(_node_point(_nodes.values()[0]), Vector2.ZERO)
		for n in _nodes.values():
			bounds = bounds.expand(_node_point(n))
		_camera = bounds.get_center()
		_fit_scale = minf(maxf(1.0, size.x - 100.0) / maxf(400.0, bounds.size.x),
			maxf(1.0, size.y - 100.0) / maxf(260.0, bounds.size.y))
	if str(_view.get("base", "")) == "world":
		_fit_scale = minf(maxf(1.0, size.x - 60.0) / extent.x, maxf(1.0, size.y - 60.0) / extent.y)
		_zoom = 2.0
		var id := str(_map.get("pos", ""))
		if _nodes.has(id):
			_camera = _node_point(_nodes[id])
	set_frame(_first_active_frame())


func _on_resized() -> void:
	if not _map.is_empty():
		_reset_camera()
	queue_redraw()


func _node_point(node: Dictionary) -> Vector2:
	var frames: Array = _map.get("frames", [])
	var frame_id := str(frames[_frame].get("id", "")) if _frame >= 0 and _frame < frames.size() else ""
	return MapProjection.node_point(node, _view, frame_id)


func _offset(node: Dictionary) -> Vector2:
	var offset: Array = node.get("offset", [])
	return Vector2(float(offset[0]), float(offset[1])) if offset.size() >= 2 else Vector2.ZERO


func _screen(point: Vector2, wrap: bool = true) -> Vector2:
	var delta := point - _camera
	if wrap and MapProjection.wraps(_view):
		var width := MapProjection.canvas_size(_view).x
		delta.x = fposmod(delta.x + width / 2.0, width) - width / 2.0
	return size / 2.0 + delta * _fit_scale * _zoom


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var before := (button.position - size / 2.0) / maxf(0.001, _fit_scale * _zoom)
			set_zoom(_zoom + (0.25 if button.button_index == MOUSE_BUTTON_WHEEL_UP else -0.25))
			_camera += before - (button.position - size / 2.0) / maxf(0.001, _fit_scale * _zoom)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				grab_focus()
				_press = button.position
				_pressed = true
				_dragged = false
			else:
				if _pressed and not _dragged:
					select_node(hit_test(button.position), true)
				_pressed = false
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _pressed:
			_dragged = _dragged or motion.position.distance_to(_press) > 6.0
			if _dragged:
				_camera -= motion.relative / maxf(0.001, _fit_scale * _zoom)
				if MapProjection.wraps(_view):
					_camera.x = fposmod(_camera.x, MapProjection.canvas_size(_view).x)
				camera_changed.emit()
				queue_redraw()
			accept_event()
		else:
			var hovered := hit_test(motion.position)
			if hovered != _hover:
				_hover = hovered
				tooltip_text = str(_nodes.get(hovered, {}).get("label", ""))
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hovered != "" else Control.CURSOR_DRAG
				queue_redraw()


func _load_base() -> void:
	var id := str(_view.get("base", ""))
	if id == _base:
		return
	_base = id
	_layers.clear()
	var data := MapProjection.base_data(_view)
	for kind in ["ice", "land", "lakes", "rivers", "islets"]:
		for shape in data.get(kind, []):
			var raw: Array = shape.get("pts", []) if typeof(shape) == TYPE_DICTIONARY else shape
			var points := PackedVector2Array()
			for i in range(0, raw.size() - 1, 2):
				var point := Vector2(float(raw[i]), float(raw[i + 1]))
				if points.is_empty() or point.distance_squared_to(points[-1]) >= 4.0:
					points.append(point)
			if points.size() < 2:
				continue
			# Triangulate once in the source coordinate system. Re-triangulating
			# projected screen coordinates can turn almost collinear coast points
			# into invalid polygons through floating-point rounding at some zooms.
			var triangles := PackedInt32Array()
			if kind != "rivers" and points.size() >= 3:
				triangles = Geometry2D.triangulate_polygon(points)
			_layers.append({"kind": kind, "points": points, "triangles": triangles})


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_draw_geography()
	for link in _map.get("links", []):
		var a := str(link.get("a", ""))
		var b := str(link.get("b", ""))
		if not _nodes.has(a) or not _nodes.has(b):
			continue
		var start := node_screen_position(a)
		var end := node_screen_position(b)
		var color := Color(INK, 0.55) if str(link.get("state", "")) != "locked" else Color(INK, 0.22)
		if MapProjection.wraps(_view):
			var width := MapProjection.canvas_size(_view).x * _fit_scale * _zoom
			if absf(end.x - start.x) > width / 2.0:
				end.x += width if end.x < start.x else -width
		_draw_route(start, end, link, color)
	for id in _nodes:
		_draw_node(str(id), _nodes[id])
	for rival in _map.get("rivals", []):
		var pos := str(rival.get("pos", ""))
		if not _nodes.has(pos):
			continue
		var at := node_screen_position(pos) + Vector2(22, -23)
		draw_line(at, at + Vector2(0, 18), INK, 2.0, true)
		draw_colored_polygon(PackedVector2Array([at, at + Vector2(17, 5), at + Vector2(0, 10)]), RED)
		_label(str(rival.get("label", "")), at + Vector2(0, -7), RED, 12)
	draw_rect(Rect2(Vector2.ZERO, size), Color(INK, 0.4), false, 1.0)


func _draw_geography() -> void:
	if _layers.is_empty():
		for x in range(0, int(size.x), 60):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(INK, 0.04), 1.0)
		for y in range(0, int(size.y), 60):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(INK, 0.04), 1.0)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.34, 0.47, 0.48, 0.16))
	var copies := [-1, 0, 1] if MapProjection.wraps(_view) else [0]
	var width := MapProjection.canvas_size(_view).x
	for copy in copies:
		for layer in _layers:
			var points := PackedVector2Array()
			var bounds := Rect2()
			for point in layer["points"]:
				var projected := _screen(point + Vector2(float(copy) * width, 0), false)
				points.append(projected)
				bounds = Rect2(projected, Vector2.ZERO) if points.size() == 1 else bounds.expand(projected)
			if not Rect2(Vector2.ZERO, size).intersects(bounds.grow(1.0)):
				continue
			var kind := str(layer["kind"])
			var fill := Color("ddd3b0") if kind in ["land", "islets"] else Color("a9bdbc")
			if kind == "ice":
				fill = Color("e5e2cf")
			if not (layer["triangles"] as PackedInt32Array).is_empty():
				RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), layer["triangles"], points,
					PackedColorArray([fill]))
				draw_polyline(points, Color(INK, 0.28), 1.0, true)
			else:
				draw_polyline(points, Color(BLUE, 0.5), 1.0, true)


func _draw_route(start: Vector2, end: Vector2, link: Dictionary, color: Color) -> void:
	if int(link.get("voyage_days", 0)) > 0:
		draw_dashed_line(start, end, color, 2.0, 8.0, true)
	else:
		draw_line(start, end, color, 2.0, true)
	if bool(link.get("oneway", false)) and start.distance_to(end) > 32.0:
		var direction := (end - start).normalized()
		var middle := start.lerp(end, 0.57)
		draw_line(middle, middle - direction.rotated(0.5) * 10.0, color, 2.0, true)
		draw_line(middle, middle - direction.rotated(-0.5) * 10.0, color, 2.0, true)


func _draw_node(id: String, node: Dictionary) -> void:
	var at := node_screen_position(id)
	if not Rect2(Vector2.ZERO, size).grow(80.0).has_point(at):
		return
	var state := str(node.get("state", ""))
	var color := INK
	if state == "current": color = BLUE
	elif state == "done": color = Color("6e8060")
	elif state in ["locked", "fog"]: color = Color("8a8678")
	if _offset(node) != Vector2.ZERO:
		draw_line(_screen(_node_point(node)), at, Color(INK, 0.45), 1.0, true)
	if id == selected_node:
		draw_arc(at, NODE_RADIUS + 6, 0, TAU, 40, GOLD, 3.0, true)
	if id == _hover:
		draw_circle(at, NODE_RADIUS + 3, Color(GOLD, 0.28))
	if state == "fog":
		draw_circle(at, NODE_RADIUS + 10, Color(INK, 0.12))
	draw_circle(at, NODE_RADIUS, Color("eee4c8"))
	draw_arc(at, NODE_RADIUS, 0, TAU, 36, color, 2.0, true)
	var glyph := "?" if state == "fog" and not bool(_map.get("reveal_all", false)) else _glyph(str(node.get("type", "")))
	_label(glyph, at + Vector2(0, 5), color, 16)
	var label := str(node.get("label", id))
	_label(label, at + Vector2(0, 33), color, 14)
	if id == str(_map.get("pos", "")):
		draw_colored_polygon(PackedVector2Array([at + Vector2(-6, -28), at + Vector2(6, -28), at + Vector2(0, -19)]), BLUE)


func _glyph(kind: String) -> String:
	return {"story": "◆", "event": "!", "branch": "Y", "battle": "×", "elite": "×", "boss": "★",
		"camp": "△", "supply": "+", "shop": "$", "teaser": "…"}.get(kind, "·")


func _label(text: String, at: Vector2, color: Color, font_size: int) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(clampf(at.x - width / 2.0, 8.0, maxf(8.0, size.x - width - 8.0)), at.y),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
