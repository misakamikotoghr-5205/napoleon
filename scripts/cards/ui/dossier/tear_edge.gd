# 档案缺口的撕边。形状只由碎片 id 的哈希播种，不进游戏状态，也不写任何文字。
# 主人 C10。合同：docs/cards/CARDS_INTERFACES.md §3.3 C10、§7.5（缺口出现、还没拿到的不出现）。
extends Control

var frag_id: String = ""


func setup(id: String) -> void:
	frag_id = id
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var s := size
	if s.x < 8.0 or s.y < 8.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed(frag_id)
	var edge := PackedVector2Array()
	var steps := 8
	for i in range(steps + 1):
		var y := s.y * float(i) / float(steps)
		edge.append(Vector2(s.x - rng.randf_range(8.0, 30.0), y))
	var poly := PackedVector2Array()
	poly.append(Vector2(0, 0))
	for p in edge:
		poly.append(p)
	poly.append(Vector2(0, s.y))
	draw_colored_polygon(poly, CardTheme.color(&"paper_old"))
	var ink := CardTheme.color(&"wood_dark")
	draw_line(Vector2(0, 0), edge[0], ink, 2.0)
	for i in range(edge.size() - 1):
		draw_line(edge[i], edge[i + 1], ink, 2.0)
	draw_line(edge[edge.size() - 1], Vector2(0, s.y), ink, 2.0)
	draw_line(Vector2(0, s.y), Vector2(0, 0), ink, 2.0)


func _seed(id: String) -> int:
	var h := hash(id)
	if h < 0:
		h = h & 0x7fffffff
	if h == 0:
		h = 1
	return h
