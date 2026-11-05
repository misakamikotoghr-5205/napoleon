# C03：铜钱正反和 faces 一致，skip 不改结果，finished 一次，面板结果正文对得上 success。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C03/harness.gd")
const TOSS := "res://scenes/cards/slots/CoinToss.tscn"
const PANEL := "res://scenes/cards/slots/SlotPanel.tscn"


func _initialize() -> void:
	var t := T.new(self, "C03_coin_toss")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	H.leaks_all(t)
	await _widget(t)
	await _panel(t, "event_slots", "c0003", [true, false, true], 2, true)
	await _panel(t, "roll_fail", "c0003", [false, false], 2, false)


func _widget(t) -> void:
	var toss: CardCoinTossView = (load(TOSS) as PackedScene).instantiate()
	root.add_child(toss)
	var faces: Array = [true, false, true, false]
	var hits := [0]
	toss.finished.connect(func() -> void: hits[0] += 1)
	toss.play(faces, 3)
	t.eq(_faces(toss), faces, "faces right after play")
	toss.skip()
	t.eq(_faces(toss), faces, "skip keeps faces")
	t.eq((toss.find_child("HeadsCount", true, false) as Label).text, "2", "heads count")
	t.eq((toss.find_child("NeedCount", true, false) as Label).text, "3", "need count")
	toss.skip()
	await t.frames(3)
	t.eq(hits[0], 1, "finished once after skip")
	toss.fast_anim = true
	toss.play([false, true], 1)
	t.eq(hits[0], 2, "second play finishes once")
	t.eq(_faces(toss), [false, true], "fast faces")
	toss.fast_anim = false
	toss.play([true], 1)
	var guard := 0
	while toss.is_playing() and guard < 180:
		await t.frames(1)
		guard += 1
	t.ok(not toss.is_playing(), "tween finished in %d frames" % guard)
	t.eq(_faces(toss), [true], "tween faces")
	t.eq(hits[0], 3, "finished once for the tween")
	var space := InputEventKey.new()
	space.pressed = true
	space.keycode = KEY_SPACE
	toss.play([false], 1)
	toss._unhandled_input(space)
	t.eq(hits[0], 4, "space skips once")
	t.eq(_faces(toss), [false], "space keeps the face")
	H.ui_ok(t, toss)
	toss.queue_free()
	await t.frames(1)


func _panel(t, fx: String, uid: String, faces: Array, need: int, success: bool) -> void:
	var pair: Array = H.boot(self, fx)
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": uid}) as CardSlotPanel
	await t.frames(2)
	var hits := [0]
	panel.on_reply("roll")
	var toss: CardCoinTossView = panel.find_child("CoinToss", true, false)
	toss.finished.connect(func() -> void: hits[0] += 1)
	if toss.is_playing():
		toss.skip()
	else:
		hits[0] += 1
	if panel.dialog != null and not panel.dialog.is_idle():
		panel.dialog.skip()
	await t.frames(2)
	t.eq(_faces(toss), faces, fx + " faces")
	t.eq(hits[0], 1, fx + " finished once")
	var field := "outcomes.success" if success else "outcomes.fail"
	var want := CardText.card("ev.1938.police_check", field)
	t.ok(_has_text(panel, want), fx + " outcome text")
	t.eq((toss.find_child("NeedCount", true, false) as Label).text, str(need), fx + " need")
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])


func _has_text(node: Node, want: String) -> bool:
	if node is Label and (node as Label).text == want:
		return true
	for child in node.get_children():
		if _has_text(child, want):
			return true
	return false


func _faces(toss: Node) -> Array:
	var out: Array = []
	var i := 0
	while true:
		var coin := toss.find_child("Coin%d" % i, true, false)
		if coin == null:
			break
		out.append(bool(coin.get_meta("face")))
		i += 1
	return out
