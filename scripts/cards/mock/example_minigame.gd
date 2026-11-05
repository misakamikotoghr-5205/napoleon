# 示例小游戏插件（W0）：演示 CardMiniGame 的接口——start(params) 只用参数搭局面，autoplay(skill) 走和玩家一样的路径
# （这里就是按“看完了”），finished 只交观察键和整数，永远不交判词。不是真的小游戏：一块占位面板、一个按钮。
# C12–C15 的桩先继承它（所以宿主从第一天就能打开每一种小游戏），主人换成真实现时改成 extends CardMiniGame。
# 主人 W0（Claude）。不写 class_name。合同：docs/cards/CARDS_INTERFACES.md §8。
extends CardMiniGame

var params: Dictionary = {}
var _done: bool = false


func kind() -> StringName:
	return StringName(str(params.get("kind", "spot")))


func start(p_params: Dictionary) -> void:
	params = p_params.duplicate(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := PanelContainer.new()
	box.size = Vector2(480, 300)
	box.position = Vector2(400, 210)
	box.add_theme_stylebox_override("panel", CardTheme.frame_style(&"event", false))
	add_child(box)
	var col := VBoxContainer.new()
	box.add_child(col)
	var title := Label.new()
	title.text = CardText.ui("w0.panel.minigame")
	col.add_child(title)
	var art := TextureRect.new()
	art.texture = CardArt.texture(str(params.get("art", "")))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.custom_minimum_size = Vector2(128, 128)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	col.add_child(art)
	var done := Button.new()
	done.text = CardText.ui("w0.mg.done")
	done.pressed.connect(func() -> void: _finish(0.6))
	col.add_child(done)
	CardAnchors.register(StringName("a.mg.%s.main" % kind()), box)


func autoplay(skill: float) -> void:
	_finish(skill)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE and not _done:
		_done = true
		get_viewport().set_input_as_handled()
		abort()


func _finish(skill: float) -> void:
	if _done:
		return
	_done = true
	_minutes_spent = 2 * maxi(1, int(params.get("minutes_per_step", 1)))
	finished.emit({"quality_permille": clampi(int(round(skill * 1000.0)), 0, 1000),
		"observations": observations_for(skill), "minutes": _minutes_spent, "measures": {}, "aborted": false})


## 只用参数里的物理量和摆设给出观察键（清楚不清楚看 skill）；键的目录由各小游戏的主人写在 data/cards/minigames/obs/
func observations_for(skill: float) -> Array:
	var out: Array = []
	var clear := skill >= 0.5
	match kind():
		&"spot":
			for m in params.get("marks", []):
				out.append("obs.spot.%s.%s" % [m.get("part", ""), m.get("kind", "differs") if clear else "unclear"])
			if out.is_empty():
				for p in params.get("parts", []):
					out.append("obs.spot.%s.%s" % [p.get("id", ""), "plain" if clear else "unclear"])
		&"weigh":
			var diff := int(params.get("actual_fen", 0)) - int(params.get("claimed_fen", 0))
			if not clear:
				out.append("obs.weigh.unsure")
			elif absi(diff) <= int(params.get("resolution_fen", 5)):
				out.append("obs.weigh.match")
			elif diff > 0:
				out.append("obs.weigh.heavy")
			else:
				out.append("obs.weigh.light_small" if -diff * 100 <= int(params.get("claimed_fen", 1)) * 5 else "obs.weigh.light_much")
		_:
			out.append("obs.%s.%s" % [kind(), "clear" if clear else "unclear"])
	return out
