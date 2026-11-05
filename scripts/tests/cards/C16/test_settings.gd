# 设置写入两份文件：旧四键进 settings.gd 的路径，fast_anim 进卡牌自己的文件。
# 关掉新手提示会让 card_guide 组里的引擎 is_enabled 为假。主人 C16。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "C16_settings")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var legacy: String = t.user_dir() + "/legacy.json"
	var cards: String = t.user_dir() + "/cards.json"
	t.eq(CardSettings.fast_anim(cards), false, "missing fast_anim file reads false")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	root.add_child(guide)
	t.eq(guide.is_enabled(), true, "guide starts on")
	var panel: CardSettings = load("res://scenes/cards/shell/CardSettings.tscn").instantiate()
	panel.bind(null, bus)
	root.add_child(panel)
	panel.open({"uid": "c0002", "settings_path": legacy, "cards_settings_path": cards})
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.settings.guide_toggle"), "guide toggle anchor is on screen")
	panel._music.value = 15
	panel._sfx.value = 25
	panel._on_speed(3)
	panel._guide_btn.pressed.emit()
	panel._fast_btn.pressed.emit()
	t.eq(guide.is_enabled(), false, "guide hints off disables CardGuide")
	var old = _read(legacy)
	var keys: Array = old.keys()
	keys.sort()
	t.eq(keys, ["guide_hints", "music", "sfx", "text_speed"], "legacy file keeps the four old keys")
	t.eq(int(old["music"]), 15, "music saved")
	t.eq(int(old["sfx"]), 25, "sfx saved")
	t.eq(int(old["text_speed"]), 3, "text speed saved")
	t.eq(bool(old["guide_hints"]), false, "guide hints saved")
	var fast = _read(cards)
	t.eq(fast.keys(), ["fast_anim"], "cards file only stores fast_anim")
	t.eq(bool(fast["fast_anim"]), true, "fast_anim saved")
	t.eq(CardSettings.fast_anim(cards), true, "fast_anim() reads the test path")
	panel._music.value = 10
	_key(panel, KEY_LEFT)
	var again = _read(legacy)
	t.eq(int(again["music"]), 5, "left key nudges the focused slider")
	var bad: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(bad.is_empty(), "settings text comes from CardText")
	t.ok(panel.autoplay_step(), "settings autoplay closes")
	panel.queue_free()
	guide.queue_free()
	bus.queue_free()
	await t.frames(2)


func _read(path: String):
	var parser := JSON.new()
	parser.parse(FileAccess.get_file_as_string(path))
	return parser.data


func _key(node: Node, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.physical_keycode = code
	node._unhandled_input(ev)
