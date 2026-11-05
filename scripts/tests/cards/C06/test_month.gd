# 本月运势：没转也能关（合同 7.8，b08）；放香 / 拿回；好段变宽；转完继续发 month.begin；
# 面板居中（b09）、香案按钮不压格子（b10）。主人 C06。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C06/support.gd")
const CAI := "ws.1938.month.caixing"
const LIU := "ws.1938.month.liunian"
const PING := "ws.1938.month.pingan"


func _initialize() -> void:
	var t := T.new(self, "C06_month")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_warm()
	var fix := S.read_fix("month_widen")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := OfferSwap.new(bus)
	mock.widened = (fix.get("widen_to", {}) as Dictionary).duplicate(true)
	mock.load_fixture(S.FIX + "month_widen.json")
	var args := S.args_of(fix)
	var panel := S.open_panel(self, mock, bus, args)
	var open_samples: Array = []
	for _i in 5:
		var t0 := Time.get_ticks_usec()
		panel.open(args)
		open_samples.append(Time.get_ticks_usec() - t0)
	open_samples.sort()
	var open_us: int = int(open_samples[open_samples.size() / 2])
	print("C06 month open_us %d" % open_us)
	t.ok(open_us < 50000, "open under 50ms (%d us)" % open_us)
	t.ok(CardWheelPanel.ARC_TWEEN_SEC <= 0.6, "arc tween slice")
	t.ok(CardWheelPanel.SPIN_SLICE_SEC <= 0.6, "spin slice")
	t.eq(CardWheelPanel.FACE_PX, 480, "face is 480")
	await t.frames(2)
	var box := panel.find_child("Box", true, false) as Control
	t.ok(box.size.x <= 1100.0 and box.size.y <= 640.0, "panel box within 1100x640")
	var face := S.face(panel)
	t.eq(face.size, Vector2(480, 480), "face pixel size")
	var art := panel.find_child("WheelArt", true, false) as TextureRect
	t.eq(art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "wheel art nearest")
	# Contract 7.8 voided the old can_close() lock: every panel closes, an unspun month wheel is spun by the
	# engine at day end. The close button used to look live and do nothing (b08).
	t.ok(panel.can_close(), "month wheel can close before the spin")
	var close_btn := panel.find_child("Close", true, false) as Button
	t.ok(close_btn.visible, "close shows before the spin")
	_layout(t, panel)
	var closes := {"n": 0}
	panel.close_requested.connect(func(_r): closes["n"] = int(closes["n"]) + 1)
	var offer := panel.find_child("Offer", true, false) as Button
	offer.grab_focus()
	await t.frames(1)
	t.ok(offer.has_focus(), "offer button can take focus")
	t.ok(str(offer.focus_next) != "", "tab leaves the incense control")
	var before := {"cai": S.arc_of(panel, CAI), "liu": S.arc_of(panel, LIU), "ping": S.arc_of(panel, PING)}
	t.ok(before["cai"] > 0.0, "good segment is on the wheel")
	S.press(panel, "Offer")
	var samples: Array = [before["cai"]]
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 900:
		await t.frames(1)
		var now := S.arc_of(panel, CAI)
		if absf(now - float(samples[-1])) > 0.02:
			samples.append(now)
		if now > float(before["cai"]) + 8.0:
			break
	var end_cai := S.arc_of(panel, CAI)
	if absf(end_cai - float(samples[-1])) > 0.02:
		samples.append(end_cai)
	t.ok(samples.size() >= 2, "good arc was sampled across the tween")
	for i in range(1, samples.size()):
		t.ok(float(samples[i]) + 0.02 >= float(samples[i - 1]), "good arc grows monotonically")
	t.ok(end_cai > float(before["cai"]) + 8.0, "good arc ended wider")
	t.ok(S.arc_of(panel, LIU) < float(before["liu"]) - 1.0, "other arc shrank")
	t.ok(S.arc_of(panel, PING) < float(before["ping"]) - 1.0, "third arc shrank")
	t.ok(absf(S.sum_arcs(panel) - 360.0) < 0.2, "arcs sum to 360")
	var offers: Array = S.sent_cmds(mock, "wheel.offer")
	t.eq(offers.size(), 1, "one incense offer")
	t.eq(offers[0], {"wheel": "wh.month", "uid": "", "source": {"kind": "money", "amount": 10}}, "offer args")
	await t.frames(2)
	S.press(panel, "Take")
	var backs: Array = S.sent_cmds(mock, "wheel.withdraw")
	t.eq(backs.size(), 1, "one withdraw")
	t.eq(backs[0], {"wheel": "wh.month", "uid": "", "index": 0}, "withdraw args")
	panel.fast_anim = true
	S.press(panel, "Spin")
	var reveal := panel.find_child("RevealTitle", true, false) as Label
	t.ok(reveal.visible, "reveal title shows")
	var spun: Array = S.sent_cmds(mock, "wheel.spin")
	t.eq(spun.size(), 1, "one spin")
	t.eq(spun[0], {"wheel": "wh.month", "uid": ""}, "spin args")
	var seg := ""
	for row in S.spin_rows(fix):
		var res: Dictionary = row.get("result", {})
		if bool(res.get("ok", false)):
			seg = str(res.get("segment", ""))
	t.ok(seg != "", "fixture names the landed segment")
	t.eq(reveal.text, CardText.card(seg, "title"), "reveal uses the segment title")
	t.ok(panel.can_close(), "month can close after the reveal")
	t.ok(not close_btn.visible, "close hides after the reveal; continue does that job (b08)")
	t.ok((panel.find_child("Continue", true, false) as Button).visible, "continue shows after the reveal")
	S.press(panel, "Continue")
	var begins: Array = S.sent_cmds(mock, "month.begin")
	t.eq(begins.size(), 1, "continue sends month.begin once")
	t.eq(int(closes["n"]), 1, "continue closes the panel")
	panel.queue_free()
	await t.frames(2)
	var bus2 := CardEventBus.new()
	root.add_child(bus2)
	var mock2 := MockCardEngine.new(bus2)
	mock2.load_fixture(S.FIX + "month_widen.json")
	var panel2 := S.open_panel(self, mock2, bus2, args)
	await t.frames(1)
	var steps := 0
	var more := true
	while steps < 8 and more:
		more = panel2.autoplay_step()
		steps += 1
	t.ok(not more, "month autoplay finishes")
	await _close_unspun(t, args)
	t.ok(S.sent_cmds(mock2, "month.begin").size() >= 1, "autoplay sends month.begin")
	panel2.queue_free()
	bus.queue_free()
	bus2.queue_free()
	await t.frames(2)


## b09: the box is centred on the screen (the host pins the panel at 90,40). b10: the incense sticks and the
## offer button stay clear of the incense slot (a drop target).
func _layout(t, panel: CardWheelPanel) -> void:
	var box := (panel.find_child("Box", true, false) as Control).get_global_rect()
	t.ok(absf(box.get_center().x - 640.0) <= 1.0 and absf(box.get_center().y - 360.0) <= 1.0, "box centred %s" % box)
	t.ok(Rect2(0, 0, 1280, 720).encloses(box), "box on screen")
	var slot := (panel.find_child("IncenseSlot", true, false) as Control).get_global_rect()
	var offer := (panel.find_child("Offer", true, false) as Control).get_global_rect()
	var sticks := (panel.find_child("Sticks", true, false) as Control).get_global_rect()
	t.ok(not slot.intersects(offer), "offer clear of the incense slot %s %s" % [offer, slot])
	t.ok(not slot.intersects(sticks), "sticks clear of the incense slot")
	for name in ["Spin", "Close", "Offer"]:
		var r := (panel.find_child(name, true, false) as Control).get_global_rect()
		t.ok(box.encloses(r), name + " inside the box")


## Pinned like the modal host pins overlays: close before spinning closes once and sends nothing.
func _close_unspun(t, args: Dictionary) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture(S.FIX + "month_widen.json")
	var host := CardModalHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	var panel := load("res://scenes/cards/wheel/WheelPanel.tscn").instantiate() as CardWheelPanel
	panel.bind(mock, bus)
	host._place_overlay(panel)
	panel.open(args)
	await t.frames(2)
	_layout(t, panel)
	var got := {"n": 0}
	panel.close_requested.connect(func(_r): got["n"] = int(got["n"]) + 1)
	S.press(panel, "Close")
	t.eq(int(got["n"]), 1, "close before the spin closes the month wheel (b08)")
	t.eq(S.sent_cmds(mock, "month.begin").size(), 0, "closing unspun sends no month.begin")
	t.eq(S.sent_cmds(mock, "wheel.spin").size(), 0, "closing unspun does not spin")
	host.queue_free()
	bus.queue_free()
	await t.frames(2)


func _warm() -> void:
	CardTheme.color(&"paper")
	CardTheme.font_body()
	CardText.ui("c06.btn.spin")
	CardArt.texture("wheel.month")
	CardArt.texture("icon.ws.caixing")
	var w: CardWheelPanel = load("res://scenes/cards/wheel/WheelPanel.tscn").instantiate()
	w._build()
	w.free()


func _key(panel: Node, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	panel._unhandled_input(ev)


class OfferSwap extends MockCardEngine:
	var widened: Dictionary = {}
	var armed: bool = false

	func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
		if str(cmd) == "wheel.offer":
			armed = true
		return super.send(cmd, args)

	func query(q: StringName, args: Dictionary = {}) -> Dictionary:
		if armed and q == &"wheel" and not widened.is_empty():
			return widened.duplicate(true)
		return super.query(q, args)
