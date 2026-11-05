# 第一人称柜台视图：内部 320×180，整数 3 倍放大（设计稿“画面规格”）。
# 上方门口与顾客、中间柜台面、下方桌下；所有操作都是点桌上的实物（data/layout.json 热点）。
extends Control

signal hotspot_clicked(id)
signal item_clicked(iid)
signal piece_clicked(key)
signal hover_text(text: String, global_pos: Vector2)
signal empty_clicked
signal item_dropped(iid: String, hotspot_id: String)

const DRAG_THRESHOLD := 3.0
const PIECE_SIZE := 20.0
const PIECE_DISC_R := 11.0
const PIECE_PER_ROW := 6
const PIECE_ROW_GAP := 22.0
const GOLD := Color("#ffd25a")
const DARK := Color("#0d0a08")

var db
var world
var bg: String = "dark"
var customer: String = ""
var brother: bool = false
var lamp: bool = false
var highlight: Array = []          # 高亮的热点（教学 / 放进典当盒）
var counter_items: Array = []      # 柜台上的物品实例
var selected_item: String = ""     # 当前选中的物品（黄框脉动）
var pieces: Array = []             # 陈叔叔的棋子 [{key, piece, sprite}]
var pieces_done: Array = []
var hover: String = ""
var t: float = 0.0
var _tex: Dictionary = {}
var _portrait_offset: float = 0.0
# 拖拽状态：按下柜台物品后，移动超过 DRAG_THRESHOLD 才算拖拽
var _press_item: String = ""
var _press_pos: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _drag_pos: Vector2 = Vector2.ZERO

const PIECE_SPRITES = {"黑子": "piece_black", "白子": "piece_white", "青子": "piece_cyan", "红子": "piece_red", "黄子": "piece_yellow", "灰子": "piece_gray"}

func _ready() -> void:
	db = DB.get_db()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(320, 180)
	size = Vector2(320, 180)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hover = ""
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		emit_signal("hover_text", "", get_global_transform() * get_local_mouse_position())

func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = DB.tex(path)
	return _tex[path]

func _process(delta: float) -> void:
	t += delta
	_portrait_offset = maxf(0.0, _portrait_offset - delta * 120.0)
	queue_redraw()

func set_scene(b: Dictionary) -> void:
	var newc := str(b.get("customer", ""))
	if newc != customer and newc != "":
		_portrait_offset = 18.0
	bg = str(b.get("bg", bg))
	customer = newc
	brother = bool(b.get("brother", brother))
	lamp = bool(b.get("lamp", lamp))
	queue_redraw()

func _bg_path() -> String:
	match bg:
		"day": return "art/bg/counter_day.png"
		"dusk": return "art/bg/counter_dusk.png"
		"night": return "art/bg/counter_night.png"
		"candle": return "art/bg/candle.png"
	return ""

func _visible_hotspots() -> Array:
	var out: Array = []
	if bg == "dark" or bg == "candle":
		return out
	for id in db.layout.get("hotspots", {}):
		if id in ["customer", "counter_item"]:
			continue
		if world != null and _tool_shown(id):
			out.append(id)
	return out

func _tool_shown(id: String) -> bool:
	match id:
		"lamp":
			return true
		"door_flag", "sign":
			return bg != "night"
		"scale", "medbook", "telegraph":
			return world.unlocked.get(id, false) or highlight.has(id)
	return true

func _draw() -> void:
	draw_rect(Rect2(0, 0, 320, 180), Color("#0d0a08"))
	var bgt := tex(_bg_path()) if _bg_path() != "" else null
	if bgt != null:
		draw_texture(bgt, Vector2.ZERO)
	if bg == "dark":
		return
	if bg == "candle":
		_draw_people(true)
		var c := tex("art/tools/candle.png")
		if c != null:
			draw_texture(c, Vector2(156, 112))
		var fl := 0.5 + 0.5 * sin(t * 7.0) * sin(t * 3.1)
		draw_rect(Rect2(159, 110 + int(fl), 2, 2), Color("#ffd25a"))
		return
	# 门外：门旗、招牌
	if bg != "night" and world != null:
		var fid: String = world.door_flag
		var fpath := "art/tools/door_flag_none.png"
		match fid:
			"blue": fpath = "art/tools/door_flag.png"
			"white": fpath = "art/tools/door_flag_white.png"
			"red": fpath = "art/tools/door_flag_red.png"
		_draw_tool("door_flag", fpath)
		_draw_tool("sign", "art/tools/sign.png")
	# 维持会怀疑达到 5：门外出现“影子”（设计稿数值表）。只给暗示，不显示数字
	if world != null and world.suspicion >= 5 and bg in ["day", "dusk"]:
		var door: Array = db.layout.get("regions", {}).get("door", [112, 8, 96, 92])
		var sx: float = door[0] + 6 + 2.0 * sin(t * 0.7)
		draw_rect(Rect2(sx, door[1] + 30, 9, 60), Color(0.05, 0.05, 0.07, 0.55))
		draw_circle(Vector2(sx + 4.5, door[1] + 26), 5.0, Color(0.05, 0.05, 0.07, 0.55))
	_draw_people(false)
	# 柜台上的工具
	for id in ["magnifier", "abacus", "scale", "ledger", "notebook", "medbook", "pawnbox", "trash", "telegraph", "lamp", "calendar"]:
		if not _tool_shown(id):
			continue
		var p := "art/tools/%s.png" % id
		if id == "lamp" and not lamp and bg != "day" and bg != "dusk":
			p = "art/tools/lamp_off.png"
		if id == "telegraph" and world.slot == 5 and world.unlocked.get("telegraph", false) and world.day >= 2:
			p = "art/tools/telegraph_open.png"
		_draw_tool(id, p)
	# 柜台上的物品
	var area: Rect2 = db.hotspot("counter_item")
	var n := counter_items.size()
	for i in range(n):
		var iid: String = counter_items[i]
		var r := _item_rect(i, n, area)
		var it: Dictionary = world.ledger.items.get(iid, {})
		var tx := tex(str(it.get("sprite", "")))
		if tx != null:
			draw_texture_rect(tx, r, false)
		else:
			draw_rect(r, Color("#d9c49a"))
		if _dragging and _press_item == iid:
			continue  # 拖拽中的原位置留空，光标处绘制
		if hover == "item:" + iid:
			draw_rect(r.grow(1), Color(1, 1, 1, 0.35), false, 1.0)
		if selected_item == iid:
			var sa := 0.5 + 0.5 * sin(t * 5.0)
			draw_rect(r.grow(2), Color(GOLD.r, GOLD.g, GOLD.b, sa), false, 1.0)
	# 棋子：20×20 图 + 深色底盘 + 金边；待办脉动，已完成 35% 透明
	for i in range(pieces.size()):
		var pr := _piece_rect(i)
		var key: String = pieces[i]["key"]
		var done := pieces_done.has(key)
		var alpha := 0.35 if done else 1.0
		var c := pr.get_center()
		draw_circle(c, PIECE_DISC_R, Color(0, 0, 0, 0.55 * alpha))
		if not done:
			var a := 0.5 + 0.5 * sin(t * 5.0 + i)
			draw_arc(c, PIECE_DISC_R, 0.0, TAU, 32, Color(GOLD.r, GOLD.g, GOLD.b, a), 1.0)
		else:
			draw_arc(c, PIECE_DISC_R, 0.0, TAU, 32, Color(GOLD.r, GOLD.g, GOLD.b, 0.35), 1.0)
		var ptx := tex("art/tools/%s.png" % PIECE_SPRITES.get(pieces[i].get("piece", ""), "piece_gray"))
		if ptx != null:
			draw_texture_rect(ptx, pr, false, Color(1, 1, 1, alpha))
	# 高亮（教学）：金框 + 红外框 + 上方 ▼ 跳动箭头
	for id in highlight:
		var hr: Rect2 = db.hotspot(id)
		var a2 := 0.55 + 0.45 * sin(t * 6.0)
		draw_rect(hr.grow(1), Color(1.0, 0.82, 0.35, a2), false, 1.0)
		draw_rect(hr.grow(2), Color(0.69, 0.15, 0.16, a2 * 0.8), false, 1.0)
		_draw_arrow(hr)
	# 普通悬停：细灰框（与教学高亮区分）
	if hover != "" and not hover.begins_with("item:") and not hover.begins_with("piece:") and not highlight.has(hover):
		draw_rect(db.hotspot(hover).grow(1), Color(1, 1, 1, 0.35), false, 1.0)
	# 拖拽中的物品跟随光标（半透明）
	if _dragging and _press_item != "":
		var dit: Dictionary = world.ledger.items.get(_press_item, {})
		var dtx := tex(str(dit.get("sprite", "")))
		var ds := Vector2(28, 28)
		var dr := Rect2(_drag_pos - ds / 2.0, ds)
		if dtx != null:
			draw_texture_rect(dtx, dr, false, Color(1, 1, 1, 0.5))
		else:
			draw_rect(dr, Color(0.85, 0.77, 0.6, 0.5))
	# 夜里只有油灯照亮柜台右侧
	if bg == "night":
		_night_shade()

# 高亮热点上方的 ▼ 箭头：约 7 px 宽，灯黄填充 + 2 px 深色描边，上下跳动
func _draw_arrow(hr: Rect2) -> void:
	var cx := hr.position.x + hr.size.x / 2.0
	var ty := hr.position.y - 3.0 + 2.0 * sin(t * 6.0)
	# 深色描边（略大一圈）
	var outline := PackedVector2Array([
		Vector2(cx - 4.5, ty - 6.0),
		Vector2(cx + 4.5, ty - 6.0),
		Vector2(cx, ty + 2.0),
	])
	draw_colored_polygon(outline, DARK)
	var fill := PackedVector2Array([
		Vector2(cx - 3.5, ty - 5.0),
		Vector2(cx + 3.5, ty - 5.0),
		Vector2(cx, ty),
	])
	draw_colored_polygon(fill, GOLD)

func _night_shade() -> void:
	if not lamp:
		draw_rect(Rect2(0, 0, 320, 180), Color(0, 0, 0.05, 0.35))

func _draw_people(candle: bool) -> void:
	var cr: Array = db.layout.get("customer", [136, 36, 48, 64])
	if customer != "":
		var pt := tex(portrait_path(customer))
		if pt != null:
			var mod := Color(1, 0.86, 0.66) if candle else (Color(0.95, 0.85, 0.72) if bg == "night" else Color.WHITE)
			var r := Rect2(cr[0], cr[1] + _portrait_offset, cr[2], cr[3])
			if candle:
				# 烛火只照亮半边脸
				var half: float = cr[2] / 2.0
				draw_texture_rect_region(pt, Rect2(r.position, Vector2(half, r.size.y)), Rect2(0, 0, half, r.size.y), Color(0.32, 0.25, 0.2))
				draw_texture_rect_region(pt, Rect2(r.position + Vector2(half, 0), Vector2(half, r.size.y)), Rect2(half, 0, half, r.size.y), mod)
			else:
				draw_texture_rect(pt, r, false, mod)
	if brother and customer != "brother" and not candle:
		var bs: Array = db.layout.get("brother_spot", [262, 40, 48, 64])
		var bt := tex("art/portraits/brother.png")
		if bt != null:
			var m2 := Color(0.95, 0.85, 0.72) if bg == "night" else Color.WHITE
			draw_texture_rect(bt, Rect2(bs[0], bs[1], bs[2], bs[3]), false, m2)

# 立绘：有名有姓的人用自己的；生客（stranger:<原型>#…）和只守铺子版的过路客人（walkin:<原型>#…）用原型的
# art/portraits/stranger_<原型>.png——原型没有自己的图（学生），借一张过路人的（STRANGER_FALLBACK），柜台后不空着
const STRANGER_FALLBACK := "art/portraits/stranger_refugee.png"
static var _portrait_ok: Dictionary = {}

static func portrait_path(who: String) -> String:
	if who.begins_with("stranger:") or who.begins_with("walkin:"):
		var path := "art/portraits/stranger_%s.png" % who.substr(who.find(":") + 1).split("#")[0]
		if not _portrait_ok.has(path):
			_portrait_ok[path] = ResourceLoader.exists("res://" + path)
		return path if bool(_portrait_ok[path]) else STRANGER_FALLBACK
	return "art/portraits/%s.png" % who

func _draw_tool(id: String, path: String) -> void:
	var r: Rect2 = db.hotspot(id)
	var tx := tex(path)
	if tx != null:
		draw_texture_rect(tx, r, false)

func _item_rect(i: int, n: int, area: Rect2) -> Rect2:
	var s := 36.0 if n <= 2 else 28.0
	var total := s * n + 4.0 * (n - 1)
	var x0 := area.position.x + (area.size.x - total) / 2.0
	return Rect2(x0 + i * (s + 4.0), area.position.y + (area.size.y - s) / 2.0, s, s)

# 棋子：counter_item 区域内每行 6 个，水平均分并居中；超过 6 个则向下换行
func _piece_rect(i: int) -> Rect2:
	# 棋子摆满柜台中段（比验货区宽），彼此不重叠
	var area := Rect2(100, 108, 120, 30)
	var cell := area.size.x / float(PIECE_PER_ROW)
	var col := i % PIECE_PER_ROW
	var row := i / PIECE_PER_ROW
	var rows := int(ceil(float(pieces.size()) / float(PIECE_PER_ROW)))
	var cx := area.position.x + cell * (col + 0.5)
	var cy := area.get_center().y + (row - (rows - 1) / 2.0) * PIECE_ROW_GAP
	return Rect2(cx - PIECE_SIZE / 2.0, cy - PIECE_SIZE / 2.0, PIECE_SIZE, PIECE_SIZE)

# 可作为拖放目标的热点：高亮列表 + 当前可见工具
func _drop_target_at(pos: Vector2) -> String:
	for id in highlight:
		if db.hotspot(id).has_point(pos):
			return id
	for id in _visible_hotspots():
		if db.hotspot(id).has_point(pos):
			return id
	return ""

func _hit(pos: Vector2) -> String:
	for i in range(pieces.size()):
		if _piece_rect(i).grow(1).has_point(pos) and not pieces_done.has(pieces[i]["key"]):
			return "piece:" + str(pieces[i]["key"])
	var area: Rect2 = db.hotspot("counter_item")
	for i in range(counter_items.size()):
		if _item_rect(i, counter_items.size(), area).has_point(pos):
			return "item:" + str(counter_items[i])
	var drop := _drop_target_at(pos)
	if drop != "":
		return drop
	if customer != "" and db.hotspot("customer").has_point(pos):
		return "customer"
	return ""

func _set_hover(h: String, pos: Vector2) -> void:
	if h == hover:
		return
	hover = h
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
	emit_signal("hover_text", _tip(h), get_global_transform() * pos)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		_set_hover(_hit(ev.position), ev.position)
		if _press_item != "":
			if not _dragging and ev.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				_drag_pos = ev.position
			queue_redraw()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var h2 := _hit(ev.position)
			if h2.begins_with("item:"):
				_press_item = h2.substr(5)
				_press_pos = ev.position
				_drag_pos = ev.position
				_dragging = false
			elif h2.begins_with("piece:"):
				emit_signal("piece_clicked", h2.substr(6))
			elif h2 != "":
				emit_signal("hotspot_clicked", h2)
			else:
				emit_signal("empty_clicked")
		else:
			if _press_item != "":
				var iid := _press_item
				var was_dragging := _dragging
				var target := _drop_target_at(ev.position)
				_press_item = ""
				_dragging = false
				if was_dragging:
					if target != "":
						emit_signal("item_dropped", iid, target)
				else:
					emit_signal("item_clicked", iid)
				queue_redraw()
		accept_event()

func _tip(h: String) -> String:
	if h == "":
		return ""
	if h.begins_with("item:"):
		if world == null:
			return ""
		return str(world.ledger.items.get(h.substr(5), {}).get("name", ""))
	if h.begins_with("piece:"):
		return "棋子"
	if h == "customer":
		return (world.db if world != null and world.get("db") != null else db).npc_label(customer)      # 小镇：生成的客人在这一局的 db 里
	return db.hotspot_label(h)

# 截图 / 测试用：热点在 1280×720 屏幕上的中心
func hotspot_center_global(id: String) -> Vector2:
	return get_global_transform() * db.hotspot(id).get_center()
