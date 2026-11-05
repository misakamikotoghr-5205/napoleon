# 纯鼠标走通（DESIGN §13）：只用 InputEventMouseButton / InputEventMouseMotion 在屏幕坐标上点（视口 push_input），
# 单枚：点两枚样洋、点客人的那枚、点“像哑板”、点“听好了”；一摞：拖一枚碰另一枚、点小牌轮换响/哑、点“听好了”；
# 吹次用完再点银元没反应；abort_rect() 不压自己的按钮、在框里、在屏幕里；Esc → aborted:true；宿主的“算了”随时能关。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_mouse"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {}))
	await _single(t)
	await _stack(t)
	await _spent(t)
	await _abort_spot(t, "v2_good")
	await _abort_spot(t, "v2_stack")
	await _abort_spot(t, "good")
	await _esc(t)
	await _host_abort(t)


func _single(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture("v2_wellmade"), bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	H.click(g, H.center(g._sample_faces[0]))
	H.click(g, H.center(g._sample_faces[1]))
	H.click(g, H.center(g._coin_faces[0]))
	t.eq(g.ops_log(), [["blow", -1], ["blow", -2], ["blow", 0]], "clicking a coin blows that coin")
	t.eq(g._wave.held(), [-1, 0, -2], "silver on top, the coin under it, dull at the bottom")
	H.click(g, H.center(g._call_btns[1]))
	t.eq(g._call, 2, "clicking a call picks it")
	t.eq((g._call_btns[1] as Button).get_theme_color("font_color"), CardTheme.color(&"gold_hi"), "the picked call is in the player's pen")
	H.click(g, H.center(g._call_btns[0]))
	H.click(g, H.center(g._call_btns[1]))
	H.click(g, H.center(g._done_btn))
	t.ok(box[0] != null, "done by mouse")
	var r: Dictionary = box[0] if box[0] != null else {}
	t.eq(r.get("observations", []), ["obs.coin_ring.like_dull_sample"], "the player's call is the observation")
	t.eq(r.get("quality_permille", -1), 1000, "both samples, the coin, and compared")
	t.eq(g.ops_log().back(), ["done"], "the mouse went through apply_op")
	# A miss: press on a coin, release outside it -> nothing.
	await H.drop(self, [g, bus])
	bus = CardEventBus.new()
	root.add_child(bus)
	g = H.open(self, H.fixture("v2_good"), bus)
	await t.frames(1)
	var at := H.center(g._coin_faces[0])
	H.move(g, at)
	H.button(g, at, true)
	H.move(g, at + Vector2(300, 220), MOUSE_BUTTON_MASK_LEFT)
	H.button(g, at + Vector2(300, 220), false)
	t.eq(g.ops_log(), [], "press on the coin, release elsewhere: no blow")
	H.click(g, Vector2(700, 380))
	t.eq(g.ops_log(), [], "clicking the sound box does nothing")
	await H.drop(self, [g, bus])


func _stack(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture("v2_stack"), bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	H.click(g, H.center(g._sample_faces[0]))
	H.click(g, H.center(g._coin_faces[2]))
	H.drag(g, H.center(g._coin_faces[3]), H.center(g._coin_faces[2]))
	t.eq(g.ops_log(), [["blow", -1], ["blow", 2], ["clink", 3, 2]], "dragging one coin onto another clinks them")
	t.ok(g._ghost == null, "the dragged coin is put back")
	H.drag(g, H.center(g._coin_faces[0]), Vector2(640, 600))
	t.eq(g.ops_log().size(), 3, "dropping a coin on nothing does nothing")
	for i in range(5):
		var clicks := 2 if i in [2, 4] else 1
		for _k in range(clicks):
			H.click(g, H.center(g._chips[i]))
	t.eq(g._marks, [1, 1, 2, 1, 2], "the little tags cycle unset -> ring -> dull")
	H.click(g, H.center(g._chips[0]))
	H.click(g, H.center(g._chips[0]))
	t.eq(int(g._marks[0]), 0, "and back to unset")
	H.click(g, H.center(g._chips[0]))
	H.click(g, H.center(g._done_btn))
	var r: Dictionary = box[0] if box[0] != null else {}
	t.eq(r.get("observations", []), ["obs.coin_ring.some_dull"], "two tagged dull")
	t.eq(r.get("measures", {}).get("clinked", false), true, "clinked by mouse")
	await H.drop(self, [g, bus])


func _spent(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture("one_try"), bus)
	await t.frames(1)
	H.click(g, H.center(g._coin_faces[0]))
	t.eq(g._tries_left, 0, "the only try is spent")
	H.click(g, H.center(g._coin_faces[0]))
	H.click(g, H.center(g._sample_faces[0]))
	t.eq(g.ops_log(), [["blow", 0]], "no more blows once the tries are gone")
	t.ok(not (g._coin_faces[0] as Control).modulate.is_equal_approx(Color.WHITE), "spent coins look dim")
	H.click(g, H.center(g._call_btns[2]))
	t.eq(g._call, 3, "the call still works")
	await H.drop(self, [g, bus])


func _abort_spot(t, name: String) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture(name), bus)
	await t.frames(1)
	var r := g.abort_rect()
	t.ok(r.has_area(), name + ": abort spot")
	t.ok(Rect2(0, 0, 1280, 720).encloses(r), name + ": abort spot on screen %s" % r)
	t.ok(g._panel.get_global_rect().grow(1.0).encloses(r), name + ": abort spot inside the frame")
	var hits: Array = []
	for n in _walk(g):
		if n is BaseButton or n in g._coin_faces or n in g._sample_faces:
			if (n as Control).get_global_rect().intersects(r):
				hits.append(str(n.name))
	t.eq(hits, [], name + ": nothing of the game under the abort spot")
	await H.drop(self, [g, bus])


func _esc(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture("v2_good"), bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	H.click(g, H.center(g._sample_faces[0]))
	H.key(g, KEY_ESCAPE)
	var r: Dictionary = box[0] if box[0] != null else {}
	t.eq(r.get("aborted", false), true, "esc aborts")
	t.eq(r.get("observations", ["x"]), [], "abort has no observations")
	t.eq(r.get("minutes", -1), 1, "abort keeps the minutes already spent")
	H.click(g, H.center(g._coin_faces[0]))
	t.eq(g.ops_log(), [["blow", -1]], "nothing after abort")
	await H.drop(self, [g, bus])


## 宿主的“算了”按钮（真的按钮，在 abort_rect 那个位置）点了就关，任何时候。
func _host_abort(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var host := CardMiniGameHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	host._on_requested("c0001", "", &"coin_ring", H.fixture("v2_stack"))
	await t.frames(2)
	var g := host.current as CardCoinRingGame
	H.click(g, H.center(g._coin_faces[0]))
	var abort := host.get_node("Abort") as Button
	H.move(g, H.center(g._coin_faces[1]))
	H.button(g, H.center(g._coin_faces[1]), true)
	H.move(g, H.center(abort), MOUSE_BUTTON_MASK_LEFT)
	H.button(g, H.center(abort), false)
	t.ok(host.is_active(), "a drag that ends on the abort button is not a click on it")
	H.click(g, H.center(abort))
	await t.frames(2)
	t.ok(not host.is_active(), "the host abort closes the game mid-round")
	host.queue_free()
	bus.queue_free()
	mock = null
	await t.frames(2)
	CardAnchors.clear()


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
