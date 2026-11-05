# 场景层：320x180 像素柜台按 4 倍铺满 1280x720。背景、人、道具、天气、热点。
# 主人 C01。class_name CardStage。合同 §7.11.3。坐标只用 CardLayout。
class_name CardStage
extends CardStageApi

const WALK_FRAME := Rect2(0, 0, 16, 32)
const GLOW_SHADER := preload("res://scripts/cards/ui/table/prop_glow.gdshader")
## Rogue v1 (RG4, ROGUE_V1.md 7.4): the relics standing in the curio shelf; it follows the curio hotspot.
const CurioShelf = preload("res://scripts/cards/ui/rogue/curio_shelf.gd")
## 换皮（SPEC §10.2–10.3）：工具悬停提亮 + 1 场景像素金边；说话的人上下跳（0.25 秒一段，循环）；
## 门口路人 4 帧走路横穿门洞（每步 1/6 秒一段，循环）；夜里点了油灯在灯旁加一团暖光。快动画时都不动。
const GLOW_S := 0.12
const GLOW_BRIGHT := 1.25
const BOB_S := 0.25
const BOB_LOOPS := 10
const WALK_STEP_S := 1.0 / 6.0
## Walk sheet rows (16×32 frames, 4 per row): 0 down, 1 left, 2 right, 3 up.
const WALK_ROW_LEFT := 1
const WALK_ROW_RIGHT := 2
## Doorway walkers cross the door in about 9 s and 11 s (prototype), in opposite directions.
const WALK_CROSS_S: Array[float] = [9.0, 11.0]
## Warm light around the lit lamp: scene rect (236, 30, 110, 120) ×4.
const LAMP_GLOW := Rect2(944, 120, 440, 480)

var bus: CardEventBus = null
## 快动画、夹具、自动试玩：进场立刻到位，换背景不淡入。
var fast: bool = false

var _view: Dictionary = {}
var _script: Dictionary = {}
var _background: TextureRect
var _fade: TextureRect
var _effects: Control
var _cast: Control
var _props: Control
var _items: Control
var _night_dark: ColorRect
var _cold: ColorRect
var _hotspots: Dictionary = {}
var _dim_tools: bool = false
var _lamp_on: bool = false
var _talking: String = ""
var _bg_id: String = ""
var _bob: Tween = null
var _lamp_light: TextureRect = null
var _walk_key: String = ""
var _curio: CurioShelf = null


func _ready() -> void:
	_build()
	refresh(_view)


func background_id() -> String:
	return _bg_id


func effect_on(which: String) -> bool:
	_build()
	var node := _effects.get_node_or_null(which) as CanvasItem
	return node != null and node.visible


func refresh(view: Dictionary) -> void:
	_build()
	_view = view.duplicate(true)
	_set_bg(CardStageScript.bg_id(_script, _view))
	_apply_tints()
	_refresh_effects()
	_refresh_hotspots()
	_curio.refresh(_view, (_hotspots[&"curio"] as Control).visible, fast)
	CardAnchors.register(&"a.scene", self)


func play(script: Dictionary) -> void:
	_build()
	_script = script.duplicate(true)
	_clear_cast()
	_clear_nodes(_props)
	_set_bg(CardStageScript.bg_id(_script, _view))
	for entry in _script.get("cast", []):
		if typeof(entry) == TYPE_DICTIONARY:
			_spawn(entry)
	for entry in _script.get("props", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var art := str(entry.get("art", ""))
		var base := CardArt.base_size(art)
		if base == Vector2i.ZERO:
			base = Vector2i(16, 16)
		_texture(_props, art, CardLayout.prop_rect(StringName(str(entry.get("at", "counter_mid"))), base))
	_refresh_effects()
	_refresh_hotspots()
	set_talking(_talking)


func clear_play() -> void:
	_build()
	_script = {}
	_talking = ""
	_clear_cast()
	_clear_nodes(_props)
	set_items([])
	set_dim_tools(false)
	_set_bg(CardStageScript.bg_id({}, _view))
	_refresh_effects()
	_refresh_hotspots()


func set_items(items: Array) -> void:
	_build()
	_clear_nodes(_items)
	var count := mini(2, items.size())
	var widths: Array[float] = []
	var total := 0.0
	for i in range(count):
		var entry: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		var base := CardArt.base_size(str(entry.get("art", "")))
		var width := float(base.x * 2) if base.x > 0 else 128.0
		widths.append(width)
		total += width
	total += 16.0 * maxi(0, count - 1)
	var x := CardLayout.ITEMS.get_center().x - total / 2.0
	for i in range(count):
		var entry: Dictionary = items[i] if typeof(items[i]) == TYPE_DICTIONARY else {}
		var art := str(entry.get("art", ""))
		var base := CardArt.base_size(art)
		var height := float(base.y * 2) if base.y > 0 else 128.0
		var item := _texture(_items, art, Rect2(x, CardLayout.ITEMS.end.y - height, widths[i], height))
		item.set_meta("item", str(entry.get("item", "")))
		if _time() == "night":
			item.modulate = CardTheme.color(&"night_tint")
		x += widths[i] + 16.0


func set_talking(who: String) -> void:
	_talking = who
	if _bob != null and _bob.is_valid():
		_bob.kill()
	_bob = null
	if _cast == null:
		return
	var speaker: Control = null
	for actor in _cast.get_children():
		var at := StringName(str(actor.get_meta("at", "customer")))
		var spot := CardLayout.spot(at)
		actor.position = spot.position
		if who != "" and str(actor.get_meta("who", "")) == who:
			actor.position.y -= float(CardLayout.SCALE)
			speaker = actor as Control
	# 说话的人一直轻轻跳（原型 bob .5s steps(2)）：上一格、下一格，各 0.25 秒；set_talking("") 停。
	if speaker == null or fast or not is_inside_tree():
		return
	var top := speaker.position.y
	# At most BOB_LOOPS hops (5 s): the dialog box calls set_talking(who) per line but not "" when typing stops.
	_bob = speaker.create_tween().set_loops(BOB_LOOPS)
	_bob.tween_interval(BOB_S)
	_bob.tween_callback(speaker.set_position.bind(Vector2(speaker.position.x, top + float(CardLayout.SCALE))))
	_bob.tween_interval(BOB_S)
	_bob.tween_callback(speaker.set_position.bind(Vector2(speaker.position.x, top)))


func is_bobbing() -> bool:
	return _bob != null and _bob.is_valid() and _bob.is_running()


func set_dim_tools(on: bool) -> void:
	_dim_tools = on
	if _background != null:
		_refresh_hotspots()


func toggle_lamp() -> void:
	_lamp_on = not _lamp_on
	_refresh_effects()
	_refresh_hotspots()


func spot_rect(spot_name: StringName) -> Rect2:
	return CardLayout.spot(spot_name)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if at_position.y < 30.0 or at_position.y > 560.0 or typeof(data) != TYPE_DICTIONARY:
		return false
	var zone := str((data as Dictionary).get("zone", ""))
	return str((data as Dictionary).get("kind", "")) == "card" and (zone == "hand" or zone == "kept")


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		card_dropped.emit((data as Dictionary).duplicate(true))


func _build() -> void:
	if _background != null:
		return
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = Vector2(1280, 720)
	_background = _texture(self, "", Rect2(0, 0, 1280, 720))
	_background.name = "Background"
	_fade = _texture(self, "", Rect2(0, 0, 1280, 720))
	_fade.name = "Fade"
	_fade.visible = false
	_effects = _layer("Effects")
	_cast = _layer("Cast")
	_props = _layer("Props")
	_items = _layer("Items")
	_night_dark = ColorRect.new()
	_night_dark.name = "NightDark"
	_night_dark.color = CardTheme.color(&"night_dark")
	_night_dark.size = Vector2(1280, 720)
	_night_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night_dark.visible = false
	add_child(_night_dark)
	_cold = ColorRect.new()
	_cold.name = "Cold"
	_cold.color = CardTheme.color(&"cold_tint")
	_cold.size = Vector2(1280, 720)
	_cold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cold.visible = false
	add_child(_cold)
	_rect_effect("Rain", CardLayout.DOOR, &"rain")
	_rect_effect("Shadow", CardLayout.SHADOW, &"silhouette")
	_rect_effect("Seal", CardLayout.DOOR_FLAG, &"seal_paper")
	var flag := _texture(_effects, "prop.door_flag", CardLayout.DOOR_FLAG)
	flag.name = "Flag"
	var sign := _texture(_effects, "prop.sign", CardLayout.SIGN)
	sign.name = "Sign"
	for id in CardIds.HOTSPOTS:
		var button := TextureButton.new()
		button.name = str(id)
		var rect: Rect2 = CardLayout.HOTSPOTS[id]
		button.position = rect.position
		button.size = rect.size
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_hotspot.bind(id))
		var glow := ShaderMaterial.new()
		glow.shader = GLOW_SHADER
		glow.set_shader_parameter(&"glow_color", CardTheme.color(&"tool_glow"))
		glow.set_shader_parameter(&"strength", 0.0)
		glow.set_shader_parameter(&"bright", 1.0)
		button.material = glow
		button.mouse_entered.connect(_glow.bind(id, true))
		button.mouse_exited.connect(_glow.bind(id, false))
		button.focus_entered.connect(_glow.bind(id, true))
		button.focus_exited.connect(_glow.bind(id, false))
		add_child(button)
		_hotspots[id] = button
	# Rogue v1: relics on the curio shelf, over the shelf prop; mouse IGNORE so the hotspot still takes the click.
	_curio = CurioShelf.new()
	_curio.follow(_hotspots[&"curio"])
	add_child(_curio)
	_lamp_light = TextureRect.new()
	_lamp_light.name = "LampLight"
	_lamp_light.texture = _lamp_texture()
	_lamp_light.position = LAMP_GLOW.position
	_lamp_light.size = LAMP_GLOW.size
	_lamp_light.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lamp_light.stretch_mode = TextureRect.STRETCH_SCALE
	_lamp_light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lamp_light.material = add
	_lamp_light.visible = false
	add_child(_lamp_light)
	move_child(_lamp_light, _night_dark.get_index() + 1)
	CardAnchors.register(&"a.scene", self)


## Warm radial light (prototype rgba(255,200,120,.16) around the lamp): lamp_glow fading out.
func _lamp_texture() -> GradientTexture2D:
	# Added on top of the night scene (additive blend), so the wall and counter around the lamp warm up.
	var grad := Gradient.new()
	var warm := CardTheme.color(&"lamp_glow")
	var core := minf(1.0, warm.a * 2.0)
	grad.set_color(0, CardTheme.with_alpha(&"lamp_glow", core))
	grad.set_color(1, CardTheme.with_alpha(&"lamp_glow", 0.0))
	grad.add_point(0.5, CardTheme.with_alpha(&"lamp_glow", core * 0.4))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 110
	tex.height = 120
	return tex


## Tool hover: brightness 1.25 and a one-scene-pixel tool_glow outline, 0.12 s (none on locked tools).
func _glow(id: StringName, on: bool) -> void:
	var button: TextureButton = _hotspots.get(id)
	if button == null or not (button.material is ShaderMaterial):
		return
	var lit := on and not button.disabled and button.visible
	var mat := button.material as ShaderMaterial
	var strength := 1.0 if lit else 0.0
	var bright := GLOW_BRIGHT if lit else 1.0
	if fast or not is_inside_tree():
		mat.set_shader_parameter(&"strength", strength)
		mat.set_shader_parameter(&"bright", bright)
		return
	var tw := button.create_tween().set_parallel(true)
	tw.tween_property(mat, "shader_parameter/strength", strength, GLOW_S)
	tw.tween_property(mat, "shader_parameter/bright", bright, GLOW_S)


func glow_on(id: StringName) -> bool:
	var button: TextureButton = _hotspots.get(id)
	if button == null or not (button.material is ShaderMaterial):
		return false
	return float((button.material as ShaderMaterial).get_shader_parameter(&"strength")) > 0.0


func _spawn(entry: Dictionary) -> void:
	var who := str(entry.get("who", ""))
	var at := StringName(str(entry.get("at", "customer")))
	var look := str(entry.get("look", "stand"))
	var spot := CardLayout.spot(at)
	var art := "portrait." + who
	if look == "shadow":
		art = "portrait." + who
	elif _is_door(at) and CardArt.base_size("walk." + who) != Vector2i.ZERO:
		art = "walk." + who
	var actor := _texture(_cast, art, spot)
	actor.set_meta("who", who)
	actor.set_meta("at", str(at))
	actor.set_meta("look", look)
	_tint_one(actor)
	if at == &"customer":
		CardAnchors.register(&"a.scene.customer", actor)
	if fast or not is_inside_tree():
		actor.position = spot.position
		return
	if _time() == "night":
		var tint := actor.modulate
		actor.modulate.a = 0.0
		var fade := create_tween()
		fade.tween_property(actor, "modulate:a", tint.a, 0.25)
		return
	var walked: bool = art.begins_with("walk.") and _time() != "night"
	if walked:
		actor.position = Vector2(CardLayout.DOOR.position.x, spot.position.y)
		var walk := create_tween()
		walk.tween_property(actor, "position", spot.position, 0.6)
		return
	actor.position = spot.position + Vector2(0, 72)
	var slide := create_tween()
	slide.tween_property(actor, "position", spot.position, 0.25)


func _set_bg(art_id: String) -> void:
	if art_id == _bg_id and _background.texture != null:
		return
	_bg_id = art_id
	_background.set_meta("art_id", art_id)
	var tex := CardArt.texture(art_id)
	if fast or not is_inside_tree() or _background.texture == null:
		_background.texture = tex
		_fade.visible = false
		return
	_fade.texture = tex
	_fade.visible = true
	_fade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	tw.finished.connect(func() -> void:
		_background.texture = tex
		_fade.visible = false
	)


func _refresh_effects() -> void:
	var set_name := _set_name()
	var night: bool = _time() == "night"
	var sealed: bool = _sealed() or _fx_has("seal")
	var rain: bool = _weather() == "rain" or _fx_has("rain")
	var counter: bool = set_name == "counter" or set_name == "candle" or set_name == ""
	_show("Rain", rain and counter)
	_show("Shadow", int(_view.get("heat_tier", 0)) >= 3 and not night and counter)
	_show("Seal", sealed and not night)
	var flag := _effects.get_node_or_null("Flag") as CanvasItem
	var sign := _effects.get_node_or_null("Sign") as CanvasItem
	if flag != null:
		flag.visible = not night and counter
		flag.modulate = CardTheme.color(&"seal") if sealed else Color.WHITE
	if sign != null:
		sign.visible = not night and counter
	_night_dark.visible = night and not _lamp_on
	if _lamp_light != null:
		_lamp_light.visible = night and _lamp_on and counter
	_cold.visible = set_name == "prison"
	_walkers(counter and not night and not sealed)


func _walkers(on: bool) -> void:
	# 同一天、同一种演出、开关没变就不重摆（不然每次视图变化路人都跳回起点）。
	var key := "%s|%s|%d|%s" % [str(on), str(_script.get("walk", "")),
		absi(int(_view.get("date", {}).get("abs_day", 1))), str(fast) + str(is_inside_tree())]
	if key == _walk_key and _effects.get_node_or_null("Walkers") != null:
		return
	_walk_key = key
	var old := _effects.get_node_or_null("Walkers")
	if old != null:
		_effects.remove_child(old)
		old.queue_free()
	if not on:
		return
	var walk := str(_script.get("walk", ""))
	if walk == "none":
		return
	# 门洞裁一个框：路人从一边走进来、横穿门洞、从另一边出去，再从头走（原型 9 秒、11 秒两条，方向相反）。
	var box := Control.new()
	box.name = "Walkers"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.clip_contents = true
	box.position = CardLayout.DOOR.position
	box.size = CardLayout.DOOR.size
	_effects.add_child(box)
	var day := absi(int(_view.get("date", {}).get("abs_day", 1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = day
	var n := 1 if walk == "" else 2
	var foot_y := CardLayout.spot(&"street").position.y - CardLayout.DOOR.position.y
	for i in range(n):
		var who: String = CardIds.EXTRAS[rng.randi() % CardIds.EXTRAS.size()]
		var art := "walk." + who
		if CardArt.base_size(art) == Vector2i.ZERO:
			art = "portrait." + who
		var x := float(rng.randi_range(0, int(CardLayout.DOOR.size.x) - 64))
		var walker := _texture(box, art, Rect2(x, foot_y, 64, 128))
		if art.begins_with("walk.") and not fast and is_inside_tree():
			_walk_loop(walker, i % 2 == 0, WALK_CROSS_S[i % WALK_CROSS_S.size()])


## One doorway walker: four walk frames at 6 per second while sliding across the clipped door box.
## Each tween step is 1/6 s; the loop wraps the walker back to the far side when it has left the door.
func _walk_loop(walker: TextureRect, rightward: bool, cross_s: float) -> void:
	var atlas := walker.texture as AtlasTexture
	if atlas == null:
		return
	atlas = atlas.duplicate() as AtlasTexture
	walker.texture = atlas
	var row := WALK_ROW_RIGHT if rightward else WALK_ROW_LEFT
	var span := CardLayout.DOOR.size.x + walker.size.x
	var step := span / (cross_s / WALK_STEP_S) * (1.0 if rightward else -1.0)
	walker.set_meta("walk_frame", 0)
	atlas.region = Rect2(0, row * WALK_FRAME.size.y, WALK_FRAME.size.x, WALK_FRAME.size.y)
	var tw := walker.create_tween().set_loops()
	tw.tween_callback(_walk_step.bind(walker, atlas, row, rightward))
	tw.tween_property(walker, "position:x", step, WALK_STEP_S).as_relative()


func _walk_step(walker: TextureRect, atlas: AtlasTexture, row: int, rightward: bool) -> void:
	if not is_instance_valid(walker):
		return
	var frame := (int(walker.get_meta("walk_frame", 0)) + 1) % 4
	walker.set_meta("walk_frame", frame)
	atlas.region = Rect2(frame * WALK_FRAME.size.x, row * WALK_FRAME.size.y, WALK_FRAME.size.x, WALK_FRAME.size.y)
	var door_w := CardLayout.DOOR.size.x
	if rightward and walker.position.x > door_w:
		walker.position.x = -walker.size.x
	elif not rightward and walker.position.x < -walker.size.x:
		walker.position.x = door_w


func _refresh_hotspots() -> void:
	var set_name := _set_name()
	var tools: bool = set_name != "street" and set_name != "prison"
	for id in _hotspots:
		var button: TextureButton = _hotspots[id]
		var art := "prop." + str(id)
		var night: bool = _time() == "night"
		if id == &"notewall":
			art = "prop.notice_wall"
		elif id == &"lamp" and not (night and _lamp_on):
			# b35：白天灯点不了，画成没点的灯（以前画着亮灯却按不动）；夜里没点也是这张。
			art = "prop.lamp_off"
		button.texture_normal = CardArt.texture(art)
		button.visible = tools
		if id == &"notewall":
			button.visible = tools and not (_view.get("demands", []) as Array).is_empty()
		var locked: bool = _dim_tools or (id == &"lamp" and not night)
		button.disabled = locked
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
		button.modulate = CardTheme.color(&"ink_soft") if _dim_tools else Color.WHITE
		if locked or not button.visible:
			_glow(id, false)
		var anchor := StringName("a.scene." + str(id))
		if CardIds.is_known_anchor(str(anchor)):
			_anchor(anchor, button, button.visible)


func _anchor(id: StringName, node: Control, on: bool) -> void:
	if on:
		CardAnchors.register(id, node)
	else:
		CardAnchors.unregister(id, node)


func _apply_tints() -> void:
	if _cast == null:
		return
	for actor in _cast.get_children():
		_tint_one(actor as CanvasItem)


func _tint_one(actor: CanvasItem) -> void:
	if actor == null:
		return
	var look := str(actor.get_meta("look", "stand"))
	if look == "shadow":
		actor.modulate = CardTheme.color(&"silhouette")
	elif _time() == "night":
		actor.modulate = CardTheme.color(&"night_tint")
	elif str(_script.get("set", "")) == "candle" or _set_name() == "candle":
		actor.modulate = CardTheme.color(&"candle_tint")
	else:
		actor.modulate = Color.WHITE


func _on_hotspot(id: StringName) -> void:
	hotspot_pressed.emit(id)
	var event_bus := bus
	if event_bus == null and is_inside_tree():
		event_bus = get_node_or_null("/root/CardBus") as CardEventBus
	if event_bus != null:
		event_bus.ui_event.emit(&"hotspot_pressed", {"id": str(id)})


func _layer(node_name: String) -> Control:
	var layer := Control.new()
	layer.name = node_name
	layer.size = Vector2(1280, 720)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer


func _texture(parent: Node, art: String, rect: Rect2) -> TextureRect:
	var picture := TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture = _art_texture(art)
	picture.position = rect.position
	picture.size = rect.size
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	return picture


func _art_texture(art: String) -> Texture2D:
	if art == "":
		return null
	var tex := CardArt.texture(art)
	if tex != null and art.begins_with("walk."):
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = WALK_FRAME
		return atlas
	return tex


func _rect_effect(node_name: String, rect: Rect2, key: StringName) -> void:
	var box := ColorRect.new()
	box.name = node_name
	box.color = CardTheme.color(key)
	box.position = rect.position
	box.size = rect.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	_effects.add_child(box)


func _show(node_name: String, on: bool) -> void:
	var node := _effects.get_node_or_null(node_name) as CanvasItem
	if node != null:
		node.visible = on


func _clear_cast() -> void:
	if _cast == null:
		return
	for actor in _cast.get_children():
		if str(actor.get_meta("at", "")) == "customer":
			CardAnchors.unregister(&"a.scene.customer", actor)
		_cast.remove_child(actor)
		actor.queue_free()


func _clear_nodes(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _state() -> Dictionary:
	var raw: Variant = _view.get("stage", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _time() -> String:
	var t := str(_state().get("time", "day"))
	return t if t != "" else "day"


func _set_name() -> String:
	var from_script := str(_script.get("set", ""))
	if from_script != "":
		return from_script
	var s := str(_state().get("set", "counter"))
	return s if s != "" else "counter"


func _sealed() -> bool:
	return bool(_state().get("sealed", false))


func _weather() -> String:
	var notice: Variant = _view.get("notice", {})
	if typeof(notice) != TYPE_DICTIONARY:
		return ""
	return str((notice as Dictionary).get("weather", ""))


func _fx_has(name: String) -> bool:
	for fx in _script.get("fx", []):
		if str(fx) == name:
			return true
	return false


func _is_door(at: StringName) -> bool:
	return at == &"door" or at == &"door_l" or at == &"door_r" or at == &"street"
