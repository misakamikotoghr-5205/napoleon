# 大轮盘、庙会花钱、赌摊押牌、钱不够。autoplay 走完每个夹具。主人 C06。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C06/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C06_kinds")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _big(t)
	await _fair(t)
	await _gamble(t)
	await _no_money(t)
	await _missing(t)
	for name in S.FIXTURES:
		await _auto(t, name)
	await t.frames(1)


func _big(t) -> void:
	var panel := await _open(t, "big")
	panel.fast_anim = true
	S.press(panel, "Spin")
	var reveal := panel.find_child("RevealTitle", true, false) as Label
	t.ok(reveal.visible, "big wheel reveals")
	_expect_title(t, reveal, _ok_segment("big"), "big")
	t.ok(S.arc_of(panel, "ws.any.big.fanshen_ship") > 0.0, "turnaround segment")
	t.ok(S.arc_of(panel, "ws.any.big.pingan") > 0.0, "safe segment")
	t.ok(S.arc_of(panel, "ws.any.big.zhuidi") > 0.0, "crash segment")
	await _drop(panel)


func _fair(t) -> void:
	var panel := await _open(t, "fair")
	var cost := panel.find_child("CostMoney", true, false) as Label
	t.ok(cost.visible, "fair shows the cost line")
	t.eq(cost.text, CardText.ui("c06.cost.money", {"n": 2}), "cost line is the ui key")
	panel.fast_anim = true
	S.press(panel, "Spin")
	var reveal := panel.find_child("RevealTitle", true, false) as Label
	t.ok(reveal.visible, "fair reveals")
	_expect_title(t, reveal, _ok_segment("fair"), "fair")
	await _drop(panel)


func _gamble(t) -> void:
	var pack := await _mount("gamble_stake")
	var panel: CardWheelPanel = pack["panel"]
	var mock: MockCardEngine = pack["mock"]
	panel.fast_anim = true
	await t.frames(2)
	var face := S.face(panel)
	var before := face.rotation
	S.press(panel, "Spin")
	var err := panel.find_child("Err", true, false) as Label
	t.ok(err.visible, "stake_required is shown")
	t.eq(err.text, CardText.ui("c06.err.stake_required"), "stake reason text")
	t.ok(absf(face.rotation - before) < 0.001, "no spin before the stake")
	var reveal := panel.find_child("RevealTitle", true, false) as Label
	t.ok(not reveal.visible, "no reveal before the stake")
	S.press(panel, "Stake")
	var stakes: Array = S.sent_cmds(mock, "wheel.stake")
	t.eq(stakes.size(), 1, "one stake")
	t.eq(stakes[0], {"wheel": "wh.gamble", "uid": "c0102", "kept_uid": "c0020"}, "stake args")
	S.press(panel, "Spin")
	t.ok(reveal.visible, "gamble reveals after the stake")
	_expect_title(t, reveal, _ok_segment("gamble_stake"), "gamble")
	await _drop(panel)
	(pack["bus"] as Node).queue_free()
	await t.frames(1)


func _no_money(t) -> void:
	var panel := await _open(t, "no_money")
	panel.fast_anim = true
	var face := S.face(panel)
	var before := face.rotation
	S.press(panel, "Spin")
	var err := panel.find_child("Err", true, false) as Label
	t.ok(err.visible, "insufficient money is shown")
	t.eq(err.text, CardText.ui("c06.err.insufficient_money"), "money reason text")
	t.ok(absf(face.rotation - before) < 0.001, "no spin when money is short")
	var reveal := panel.find_child("RevealTitle", true, false) as Label
	t.ok(not reveal.visible, "no reveal when money is short")
	await _drop(panel)


func _missing(t) -> void:
	var pack := S.boot(self)
	var panel := S.open_panel(self, pack["mock"], pack["bus"], {"uid": "missing-card"})
	var n := {"c": 0}
	panel.close_requested.connect(func(_r): n["c"] = int(n["c"]) + 1)
	await t.frames(2)
	t.ok(panel.can_close(), "unknown card can close")
	t.eq(int(n["c"]), 1, "unknown card asks to close")
	var err := panel.find_child("Err", true, false) as Label
	t.ok(err != null and err.visible, "unknown card shows a reason")
	t.eq(err.text, CardText.ui("c06.err.missing"), "missing reason text")
	await _drop(panel)
	(pack["bus"] as Node).queue_free()
	await t.frames(1)


func _auto(t, name: String) -> void:
	var pack := await _mount(name)
	var panel: CardWheelPanel = pack["panel"]
	await t.frames(1)
	var steps := 0
	var more := true
	while steps < 8 and more:
		more = panel.autoplay_step()
		steps += 1
	t.ok(not more, "autoplay finishes " + name)
	t.ok(steps >= 1, "autoplay took a step " + name)
	await _drop(panel)
	(pack["bus"] as Node).queue_free()
	await t.frames(1)


func _open(t, name: String) -> CardWheelPanel:
	var pack := await _mount(name)
	var panel: CardWheelPanel = pack["panel"]
	await t.frames(1)
	panel.set_meta("bus", pack["bus"])
	return panel


func _mount(name: String) -> Dictionary:
	var fix := S.read_fix(name)
	var pack := S.boot(self)
	var mock: MockCardEngine = pack["mock"]
	mock.load_fixture(S.FIX + name + ".json")
	var panel := S.open_panel(self, mock, pack["bus"], S.args_of(fix))
	return {"panel": panel, "mock": mock, "bus": pack["bus"]}


func _drop(panel: Node) -> void:
	var bus: Node = null
	if panel.has_meta("bus"):
		var meta = panel.get_meta("bus")
		if meta is Node:
			bus = meta
	panel.queue_free()
	if bus != null:
		bus.queue_free()
	await process_frame


func _expect_title(t, reveal: Label, seg: String, label: String) -> void:
	var raw := CardText.card(seg, "title")
	if S.has_digit(raw):
		t.eq(reveal.text, CardText.ui("c06.segment.name"), label + " digit title is replaced")
	else:
		t.eq(reveal.text, raw, label + " reveal title")
	t.ok(not S.has_digit(reveal.text), label + " reveal has no digits")


func _ok_segment(name: String) -> String:
	for row in S.spin_rows(S.read_fix(name)):
		var res: Dictionary = row.get("result", {})
		if bool(res.get("ok", false)):
			return str(res.get("segment", ""))
	return ""
