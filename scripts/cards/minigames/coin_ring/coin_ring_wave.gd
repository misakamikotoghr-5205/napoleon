# 余音框：每吹一下（或碰一下）添一道线，左端一个小银元和标签（甲 / 乙 / 客 / 碰）。线从声音模型来：
# 长短跟 ring_ms、疏密跟 pitch_cents、毛边跟 buzz；声音关着的时候这道线就是全部信息（DESIGN §5.3）。
# pin 时两枚样洋各有自己的一行，吹过一次就一直钉在那儿、不变淡：甲在最上面，乙在最下面，客人的线夹在中间
# （最新的一道紧挨着甲，对着甲比疏密；往下挨着乙，两头都比得上）。中间几行（rolling）轮着放最近吹的客人的线，
# 旧的变淡。复审三：原来基础眼力只有两行，吹客人的那一下乙就被挤掉，乙和客人的线从来不同时在框里。
# 不 pin（只一行）时照旧只放最近的一道。新线 0.5 秒内从左往右画完（快动画一下画完）。
# 线的颜色只分“谁的”（甲金、乙淡朱、客人的浅色），不分好坏。只画配色键，不写数字。主人 C13。
extends Control

const Voice = preload("res://scripts/cards/minigames/coin_ring/coin_ring_voice.gd")

const GUTTER := 72.0
const RIGHT_PAD := 16.0
const LINE_W := 2.0
const DRAW_SEC := 0.5
const FADED_ALPHA := 0.45
## The pinned sample lines: clearly drawn (never the faded ghost), a little softer than the line just blown so the
## rows read as "the references" and "this one".
const PIN_ALPHA := 0.75
## Most rows the box holds (160 px high: four rows keep each wave 15 px tall).
const MAX_ROWS := 4

const PIN_WHO := -1
const PIN_LOW_WHO := -2

## 轮着放的那几道（旧的在前）：{who:int, spec:Dictionary, salt:int, clink:int(-1 = 不是相碰), pips:int, label:String, reveal:float}
var rows: Array = []
## 钉住的样洋：who（-1 甲 / -2 乙）-> 那一道（同上的形状）；还没吹过的不在里面。
var pins: Dictionary = {}
## 一共几行；pin 时 = 2 + rolling。
var cap: int = 3
## 中间轮着放客人的线的行数。
var rolling: int = 1
## 甲、乙各占一行（只一行时不钉）。
var pin: bool = true
var fast_anim: bool = false
## 样洋那一行还空着时左端写的字（游戏给，不写死）：who -> 字。
var pin_labels: Dictionary = {}

var _labels: Array[Label] = []
var _tween: Tween
var _cache: Dictionary = {}
var _drawing: Dictionary = {}


## p_rolling: 中间轮着放几道（pin 时 1..2，不 pin 时就是总行数）。p_labels: {-1: "甲", -2: "乙"}。
func setup(p_rolling: int, p_fast: bool, p_pin: bool = true, p_labels: Dictionary = {}) -> void:
	pin = p_pin
	rolling = clampi(p_rolling, 1, MAX_ROWS - 2 if pin else MAX_ROWS)
	cap = rolling + (2 if pin else 0)
	fast_anim = p_fast
	pin_labels = p_labels.duplicate()
	rows.clear()
	pins = {}
	_cache.clear()
	_sync_labels()
	queue_redraw()


## who: -1 足银样洋、-2 哑板样洋、0.. 客人的第几枚；clink >= 0 是相碰的闷度（0..1000）。
func add_line(who: int, spec: Dictionary, salt: int, label: String, pips: int, clink: int = -1) -> void:
	var row := {"who": who, "spec": spec.duplicate(true), "salt": salt, "clink": clink, "pips": pips,
		"label": label, "reveal": 0.0}
	if pin and clink < 0 and (who == PIN_WHO or who == PIN_LOW_WHO):
		pins[who] = row
		_animate(row)
	else:
		rows.append(row)
		while rows.size() > rolling:
			rows.pop_front()
		_animate(rows[-1])
	_sync_labels()
	queue_redraw()


## 框里现在留着的线是谁的，从上往下（测试和“比过没有”用）；相碰的记 -9。
func held() -> Array:
	var out: Array = []
	for r in shown_rows():
		if not (r as Dictionary).is_empty():
			out.append(int(r["who"]) if int(r["clink"]) < 0 else -9)
	return out


## 从上往下每一行画的是哪一道（空着的行是 {}）：pin 时 甲、最近的几道客人的线（最新的在上）、乙。
func shown_rows() -> Array:
	if not pin:
		return rows.duplicate()
	var out: Array = [pins.get(PIN_WHO, {})]
	for k in range(rolling):
		var at := rows.size() - 1 - k
		out.append(rows[at] if at >= 0 else {})
	out.append(pins.get(PIN_LOW_WHO, {}))
	return out


## 空着的行是不是留给样洋的（那一行左端淡淡写着甲 / 乙）：返回 who，不是就 0。
func slot_who(index: int) -> int:
	if not pin:
		return 0
	if index == 0:
		return PIN_WHO
	if index == cap - 1:
		return PIN_LOW_WHO
	return 0


## 某一道线现在画多淡：钉住的样洋 PIN_ALPHA、最新的一道 1，轮着放的旧线 FADED_ALPHA。
func alpha_of(row: Dictionary) -> float:
	if row.is_empty():
		return FADED_ALPHA
	if pin:
		for who in pins:
			if is_same(row, pins[who]):
				return PIN_ALPHA
	return 1.0 if not rows.is_empty() and is_same(row, rows[-1]) else FADED_ALPHA


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_labels()


## The new line draws itself left to right; every other line is finished at once.
func _animate(fresh: Dictionary) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	for who in pins:
		pins[who]["reveal"] = 1.0
	for r in rows:
		r["reveal"] = 1.0
	_drawing = fresh
	if fast_anim or not is_inside_tree():
		_drawing = {}
		return
	fresh["reveal"] = 0.0
	_tween = create_tween()
	_tween.tween_method(_set_reveal, 0.0, 1.0, DRAW_SEC)


func _set_reveal(v: float) -> void:
	if _drawing.is_empty():
		return
	_drawing["reveal"] = v
	queue_redraw()


func _row_h() -> float:
	return size.y / float(maxi(cap, 1))


func _trace_w() -> float:
	return maxf(size.x - GUTTER - RIGHT_PAD, 8.0)


func _sync_labels() -> void:
	while _labels.size() < cap:
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_override("font", CardTheme.font_body())
		l.add_theme_font_size_override("font_size", 16)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)
		_labels.append(l)
	var h := _row_h()
	var shown := shown_rows()
	for i in range(_labels.size()):
		var l := _labels[i]
		if i >= shown.size():
			l.text = ""
			l.visible = false
			continue
		var r: Dictionary = shown[i]
		l.visible = true
		l.position = Vector2(36.0, h * float(i) + 2.0)
		l.size = Vector2(GUTTER - 38.0, h - 4.0)
		if r.is_empty():
			# A sample's row before it has been blown: its mark, faint, so the slot reads as "for 甲" / "for 乙".
			var slot := slot_who(i)
			l.text = str(pin_labels.get(slot, "")) if slot != 0 else ""
			l.add_theme_color_override("font_color", _slot_ink(slot))
		else:
			l.text = str(r["label"])
			l.add_theme_color_override("font_color", _ink(r))
		l.modulate = Color(1, 1, 1, alpha_of(r))


func _slot_ink(who: int) -> Color:
	return CardTheme.color(&"almanac_ji" if who == PIN_LOW_WHO else &"gold_pale")


func _ink(r: Dictionary) -> Color:
	if int(r["clink"]) >= 0:
		return CardTheme.color(&"text_2")
	match int(r["who"]):
		-1:
			return CardTheme.color(&"gold_pale")
		-2:
			return CardTheme.color(&"almanac_ji")
	return CardTheme.color(&"hud_ink")


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	var h := _row_h()
	for i in range(1, cap):
		var y := floorf(h * float(i)) + 0.5
		draw_line(Vector2(8, y), Vector2(size.x - 8, y), CardTheme.with_alpha(&"line", 0.6), 1.0)
	var shown := shown_rows()
	for i in range(shown.size()):
		var row: Dictionary = shown[i]
		var mid := h * float(i) + h * 0.5
		if row.is_empty():
			var slot := slot_who(i)
			if slot != 0:
				var ink := _slot_ink(slot)
				ink.a *= FADED_ALPHA * 0.6
				draw_circle(Vector2(20.0, mid), 10.0, ink, false, 1.0)
			continue
		var alpha := alpha_of(row)
		_draw_icon(row, Vector2(20.0, mid), alpha)
		_draw_trace(row, i, mid, h, alpha)


func _draw_icon(row: Dictionary, at: Vector2, alpha: float) -> void:
	var ink := _ink(row)
	ink.a *= alpha
	if int(row["clink"]) >= 0:
		draw_circle(at + Vector2(-5, 0), 7.0, ink, false, 2.0)
		draw_circle(at + Vector2(5, 0), 7.0, ink, false, 2.0)
		return
	draw_circle(at, 10.0, ink, false, 2.0)
	draw_circle(at, 5.0, ink, false, 1.0)
	if int(row["who"]) == -2:
		var thread := CardTheme.color(&"seal")
		thread.a *= alpha
		draw_arc(at, 13.0, -0.4, PI * 1.6, 18, thread, 2.0)
	var pips := int(row["pips"])
	for k in range(pips):
		var px := at.x - float(pips - 1) * 3.0 + float(k) * 6.0
		draw_circle(Vector2(px, at.y + 16.0), 2.0, ink)


func _draw_trace(row: Dictionary, index: int, mid: float, h: float, alpha: float) -> void:
	var ys := _points_for(row, index)
	if ys.size() < 2:
		return
	var reveal := clampf(float(row["reveal"]), 0.0, 1.0)
	var shown := int(ceil(float(ys.size()) * reveal))
	if shown < 2:
		return
	var amp := h * 0.38
	var pts := PackedVector2Array()
	pts.resize(shown)
	for x in range(shown):
		pts[x] = Vector2(GUTTER + float(x), mid - ys[x] * amp)
	var ink := _ink(row)
	ink.a *= alpha
	draw_polyline(pts, ink, LINE_W, false)
	if shown == ys.size() and int(row["clink"]) < 0:
		var end := Vector2(GUTTER + float(shown - 1), mid)
		draw_line(end + Vector2(0, -5), end + Vector2(0, 5), ink, 1.0)


func _points_for(row: Dictionary, _index: int) -> PackedFloat32Array:
	var w := _trace_w()
	var key := "%d|%d|%d|%s|%d" % [int(row["who"]), int(row["salt"]), int(row["clink"]), JSON.stringify(row["spec"], "", true), int(w)]
	if _cache.has(key):
		return _cache[key]
	var ys: PackedFloat32Array
	if int(row["clink"]) >= 0:
		ys = Voice.clink_trace(int(row["clink"]), int(row["salt"]), w)
	else:
		ys = Voice.trace(row["spec"], int(row["salt"]), w)
	_cache[key] = ys
	return ys
