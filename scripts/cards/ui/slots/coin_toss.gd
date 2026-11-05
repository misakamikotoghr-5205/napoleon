# 掷铜钱动画：按引擎给的正反面播，可跳过（跳过不丢结果）。C05、C06、C11 复用。
# 主人 C03。合同：docs/cards/CARDS_INTERFACES.md §3.3 C03、§7.8、§7.11.7。单段 Tween ≤ 0.6 秒。
# 快动画读冻结的 CardSettings.fast_anim()；fast_anim 仍给测试当场关掉补间。
# 换皮（10-22，原型 61/62）：每枚依次（隔 0.07 秒）跳起再落下、横着翻两回，落定翻开；自动算正面的那几枚
# （auto_heads）排在前面、带金圈、不翻。掷完右边一块小牌子：掷出的正面数（+自动正面）/ 要几个。
class_name CardCoinTossView
extends Control

signal finished

const Face = preload("res://scripts/cards/ui/slots/coin_face.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const COIN := Vector2(48, 48)
const STAGGER := 0.07
const JUMP := 40.0

## When true, play() shows the final faces on the same call and does not tween.
var fast_anim: bool = false
## 柜台上按 CardLayout.coin_rect 摆；单独用时仍是一横排。
var counter_layout: bool = false
## 柜台上：放进格子的东西直接算的正面数，画成前面几枚带金圈的正面铜钱（不掷）。
var auto_heads: int = 0

var _faces: Array = []
var _need: int = 0
var _playing: bool = false
var _started: bool = false
var _token: int = 0
var _left: int = 0
var _tweens: Array = []
var _coins: Array = []
var _autos: Array = []
var _row: HBoxContainer
var _nums: PanelContainer
var _heads: Label
var _auto_label: Label
var _need_label: Label


func _init() -> void:
	custom_minimum_size = Vector2(480, 72)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = custom_minimum_size
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)
	_nums = Kit.box(CardTheme.pill_style(&"days_plate", &"gold_deep", 6, 10.0, 2.0))
	_nums.name = "Nums"
	_nums.position = Vector2(0, 52)
	_nums.visible = false
	add_child(_nums)
	var line := Kit.row(4)
	_nums.add_child(line)
	line.add_child(Kit.icon("icon.coin.head", 1))
	_heads = Kit.label("0", 16, &"gold_pale", true)
	_heads.name = "HeadsCount"
	line.add_child(_heads)
	_auto_label = Kit.label("", 14, &"gold_hi", true)
	_auto_label.name = "AutoCount"
	_auto_label.visible = false
	line.add_child(_auto_label)
	var slash := Kit.label("/", 16, &"text_2")
	slash.name = "Slash"
	line.add_child(slash)
	_need_label = Kit.label("0", 16, &"hud_ink", true)
	_need_label.name = "NeedCount"
	line.add_child(_need_label)


func play(faces: Array, need: int) -> void:
	_playing = false
	_stop_tweens()
	_token += 1
	_faces = faces.duplicate()
	_need = need
	_started = true
	_playing = true
	visible = true
	_build()
	if _wants_fast() or _faces.is_empty() or not is_inside_tree():
		_reveal_all()
		_finish()
		return
	var token := _token
	_left = _coins.size()
	for i in _coins.size():
		var coin: Control = _coins[i]
		var y0 := coin.position.y
		var delay := STAGGER * float(i)
		var hop := create_tween()
		_tweens.append(hop)
		if delay > 0.0:
			hop.tween_interval(delay)
		hop.tween_property(coin, "position:y", y0 - JUMP, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(coin, "position:y", y0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		hop.tween_property(coin, "position:y", y0 - JUMP * 0.25, 0.08).set_ease(Tween.EASE_OUT)
		hop.tween_property(coin, "position:y", y0, 0.08).set_ease(Tween.EASE_IN)
		hop.finished.connect(_one_done.bind(token))
		var flip := create_tween()
		_tweens.append(flip)
		if delay > 0.0:
			flip.tween_interval(delay)
		flip.tween_property(coin, "scale:x", 0.1, 0.11)
		flip.tween_property(coin, "scale:x", 1.0, 0.11)
		flip.tween_property(coin, "scale:x", 0.1, 0.11)
		flip.tween_callback(_reveal_one.bind(i))
		flip.tween_property(coin, "scale:x", 1.0, 0.11)


func skip() -> void:
	if not _playing:
		return
	_stop_tweens()
	_reveal_all()
	_finish()


func is_playing() -> bool:
	return _playing


func same(faces: Array, need: int) -> bool:
	if not _started or _need != need or faces.size() != _faces.size():
		return false
	for i in faces.size():
		if bool(faces[i]) != bool(_faces[i]):
			return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _playing or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_SPACE:
		skip()
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()


func _build() -> void:
	_stop_tweens()
	for child in _row.get_children():
		_row.remove_child(child)
		child.free()
	for coin in _coins + _autos:
		if is_instance_valid(coin) and coin.get_parent() == self:
			remove_child(coin)
			coin.free()
	_coins.clear()
	_autos.clear()
	_nums.visible = false
	var autos := maxi(0, auto_heads) if counter_layout else 0
	var total := mini(CardLayout.COIN_MAX, autos + _faces.size())
	autos = mini(autos, maxi(0, total - _faces.size()))
	for i in autos:
		var a = Face.new()
		a.name = "AutoCoin%d" % i
		a.face = true
		a.shown = true
		a.ring = true
		var ra := CardLayout.coin_rect(i, total)
		a.position = ra.position
		a.size = ra.size
		add_child(a)
		_autos.append(a)
	for i in _faces.size():
		var coin = Face.new()
		coin.name = "Coin%d" % i
		coin.face = bool(_faces[i])
		coin.shown = false
		coin.idle_face = true
		coin.set_meta("face", bool(_faces[i]))
		var rect := _coin_rect(autos + i, total)
		coin.position = rect.position
		coin.size = rect.size
		coin.custom_minimum_size = rect.size
		coin.pivot_offset = rect.size * 0.5
		if counter_layout:
			add_child(coin)
		else:
			_row.add_child(coin)
		_coins.append(coin)
	_place_nums(total)


## 结果小牌子：柜台上放在最后一枚铜钱右边，竖直居中；单独用时在那一排下面。
func _place_nums(total: int) -> void:
	if not counter_layout:
		_nums.position = Vector2(0, COIN.y + 4.0)
		return
	var last := CardLayout.coin_rect(maxi(total, 1) - 1, maxi(total, 1))
	_nums.reset_size()
	var h := _nums.get_combined_minimum_size().y
	_nums.position = Vector2(last.end.x + 16.0, last.position.y + (last.size.y - h) * 0.5)


func _reveal_one(index: int) -> void:
	if index < 0 or index >= _coins.size():
		return
	var coin = _coins[index]
	coin.shown = true
	coin.queue_redraw()


func _reveal_all() -> void:
	for coin in _coins:
		coin.shown = true
		coin.scale = Vector2.ONE
		coin.queue_redraw()
	for i in _coins.size():
		var coin: Control = _coins[i]
		var total := _autos.size() + _coins.size()
		var rect := _coin_rect(_autos.size() + i, total)
		coin.position = rect.position


func _one_done(token: int) -> void:
	if token != _token or not _playing:
		return
	_left -= 1
	if _left <= 0:
		_finish()


func _finish() -> void:
	if not _playing:
		return
	_playing = false
	var heads := 0
	for face in _faces:
		if bool(face):
			heads += 1
	_heads.text = str(heads)
	_need_label.text = str(_need)
	_auto_label.visible = _autos.size() > 0
	_auto_label.text = CardText.ui("c03.coins.auto_plus", {"n": _autos.size()}) if _autos.size() > 0 else ""
	var ok := heads + _autos.size() >= _need
	_heads.add_theme_color_override("font_color", CardTheme.color(&"gold_pale" if ok else &"bad"))
	_nums.visible = true
	_place_nums(_autos.size() + _coins.size())
	finished.emit()


func _wants_fast() -> bool:
	return fast_anim or CardSettings.fast_anim()


func _coin_rect(i: int, n: int) -> Rect2:
	if counter_layout:
		return CardLayout.coin_rect(i, n)
	return Rect2(float(i) * (COIN.x + 8.0), 0, COIN.x, COIN.y)


func _stop_tweens() -> void:
	for tw in _tweens:
		if tw is Tween and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_tweens.clear()
