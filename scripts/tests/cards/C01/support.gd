# C01 测试共用：开机、按键。不写 class_name。
extends RefCounted


static func boot(tree: SceneTree, bus: CardEventBus, fixture: String, extra: Dictionary = {}) -> CardGameRoot:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	var opts := {"mock": true, "bus": bus, "skip_title": true, "settings_path": ""}
	if fixture != "":
		opts["fixture"] = fixture
	opts.merge(extra, true)
	game.boot(opts)
	tree.root.add_child(game)
	return game


static func press(node: Node, code: Key) -> void:
	# 完整按下+释放，才能激活 GUI 按钮（ui_accept 认松开）。
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	down.echo = false
	node.get_viewport().push_input(down)
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	up.echo = false
	node.get_viewport().push_input(up)


static func click(node: Node, canvas_point: Vector2) -> void:
	# 无头窗口是 0×0。用视口本地坐标，不经过窗口变换。
	var move := InputEventMouseMotion.new()
	move.position = canvas_point
	move.global_position = canvas_point
	node.get_viewport().push_input(move, true)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = canvas_point
	ev.global_position = canvas_point
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	node.get_viewport().push_input(ev, true)
