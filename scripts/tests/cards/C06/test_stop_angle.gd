# 每个夹具：停下后盘面旋转换算成相对 12 点的角度，与 stop_deg 相差不超过 0.5 度，且落在选中段里。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C06/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C06_stop_angle")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in S.FIXTURES:
		var fix := S.read_fix(name)
		var segs: Array = S.wheel_query(fix).get("segments", [])
		for row in S.spin_rows(fix):
			var res: Dictionary = row.get("result", {})
			if not res.has("stop_deg"):
				continue
			var stop := float(res.get("stop_deg", -1.0))
			var seg := str(res.get("segment", ""))
			t.ok(S.stop_inside(segs, seg, stop), "%s stop_deg %.3f sits in %s" % [name, stop, seg])
		await _play(t, name, fix)
	await t.frames(1)


func _play(t, name: String, fix: Dictionary) -> void:
	var pack := S.boot(self)
	var mock: MockCardEngine = pack["mock"]
	var bus: CardEventBus = pack["bus"]
	mock.load_fixture(S.FIX + name + ".json")
	var panel := S.open_panel(self, mock, bus, S.args_of(fix))
	panel.fast_anim = true
	await t.frames(1)
	var face := S.face(panel)
	var before := face.rotation
	if name == "gamble_stake":
		S.press(panel, "Spin")
		t.ok(absf(face.rotation - before) < 0.001, "stake error does not rotate")
		S.press(panel, "Stake")
		S.press(panel, "Spin")
	elif name == "no_money":
		S.press(panel, "Spin")
		t.ok(absf(face.rotation - before) < 0.001, "no money does not rotate")
		panel.queue_free()
		bus.queue_free()
		await t.frames(1)
		return
	else:
		S.press(panel, "Spin")
	var res := {}
	for row in S.spin_rows(fix):
		var one: Dictionary = row.get("result", {})
		if bool(one.get("ok", false)):
			res = one
	var stop := float(res.get("stop_deg", -999.0))
	var seg := str(res.get("segment", ""))
	var angle := S.from_twelve(face)
	t.ok(absf(angle - stop) <= 0.5, "%s angle %.3f vs stop %.3f" % [name, angle, stop])
	t.ok(S.stop_inside(S.wheel_query(fix).get("segments", []), seg, angle), "%s needle sits in %s" % [name, seg])
	panel.queue_free()
	bus.queue_free()
	await t.frames(1)
