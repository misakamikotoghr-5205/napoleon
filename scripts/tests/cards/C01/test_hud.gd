# C01 HUD：日期、时辰天气、档位、点钱和黄历开对的抽屉。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C01_hud")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, "res://scripts/tests/cards/C01/fixtures/market_rain.json")
	await t.frames(2)
	var view: Dictionary = game.engine.view()
	var hud: Node = game.table.get_node("Hud")
	var date: Dictionary = view.get("date", {})
	t.eq(hud.get_node("Date").text, CardText.ui("c01.hud.date", {
		"y": date.get("y", 0), "m": date.get("m", 0), "d": date.get("d", 0),
		"weekday": date.get("weekday", 0), "day": date.get("stage_day", 0),
		"days": date.get("stage_days", 0),
	}), "date line")
	var weather := _blob(hud.get_node("Weather"))
	t.ok(weather.contains(CardText.ui("c01.hud.time.day")), "time word")
	t.ok(weather.contains(CardText.ui("g05.weather.rain")), "weather word")
	# 换皮后集市日挪到状态格当药丸：时辰天气那格只有 100px，三段放不下会把“集市日”截成“集…”。
	t.ok(not weather.contains(CardText.ui("c01.hud.market")), "market word left the weather box")
	t.ok(_blob(hud.get_node("Status")).contains(CardText.ui("c01.hud.market")), "market word is a status pill")
	t.eq(hud.get_node("Rep").text, CardText.ui("g03.tier.rep.%d" % int(view.get("rep_tier", 0))), "rep")
	t.eq(hud.get_node("Heat").text, CardText.ui("g03.tier.heat.%d" % int(view.get("heat_tier", 0))), "heat")
	var money: Dictionary = view.get("money", {})
	var money_btn: Button = hud.get_node("Money")
	t.eq(money_btn.text, str(int(money.get("amount", 0))), "money amount")
	t.ok(_blob(money_btn).contains(CardText.ui("c01.money.unit." + str(money.get("currency", "fabi")))), "money unit")
	hud.get_node("Money").pressed.emit()
	await t.frames(1)
	t.eq(game.host.top_kind(), &"estates", "money opens estates")
	game.host.close_top()
	await t.frames(1)
	for child in hud.get_children():
		if child is Button and str(child.name) != "Money":
			(child as Button).pressed.emit()
			break
	await t.frames(1)
	t.eq(game.host.top_kind(), &"almanac", "almanac strip opens the almanac")
	game.host.close_top()
	await t.frames(1)
	_check_caps_and_no_overlap(t, hud, view)
	_check_money_glyphs(t, hud, view)
	game.queue_free()
	bus.queue_free()
	await t.frames(1)


func _check_caps_and_no_overlap(t, hud: Control, view: Dictionary) -> void:
	var crowded := view.duplicate(true)
	crowded["mode"] = "street"
	crowded["stage"] = {"set": "prison", "time": "day", "sealed": true}
	crowded["money"] = {"amount": 987654321, "currency": "fabi"}
	crowded["notice"] = {
		"weather": "rain",
		"market_day": true,
		"fortune": "p.ex.gold",
		"almanac": {
			"id": "alm.shoudang",
			"yi": ["pawn_in", "redeem", "sell", "meet"],
			"ji": ["travel", "repair", "buy"],
			"done": ["pawn_in"],
		},
	}
	hud.call("refresh", crowded)
	var hud_bounds := CardLayout.HUD.grow(1.0)
	var segments: Array[Control] = [
		hud.get_node("Date") as Control,
		hud.get_node("Weather") as Control,
		hud.get_node("AlmanacStrip") as Control,
		hud.get_node("Status") as Control,
		hud.get_node("Money") as Control,
		hud.get_node("Rep") as Control,
		hud.get_node("Heat") as Control,
	]
	for i in range(segments.size()):
		var seg := segments[i]
		t.ok(hud_bounds.encloses(seg.get_global_rect()), "HUD encloses " + str(seg.name))
		for j in range(i + 1, segments.size()):
			var other := segments[j]
			t.ok(not seg.get_global_rect().intersects(other.get_global_rect()), "%s and %s do not overlap" % [seg.name, other.name])
	for name in ["Date", "Rep", "Heat"]:
		var lab := hud.get_node(name) as Label
		t.ok(lab.clip_text and lab.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%s trims with ellipsis" % name)
	var money_btn := hud.get_node("Money") as Button
	t.ok(money_btn.clip_text and money_btn.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "Money button trims with ellipsis")
	for box_name in ["Weather", "Status"]:
		var box := hud.get_node(box_name) as Control
		var children: Array[Control] = []
		for ch in box.get_children():
			if ch is Label:
				var l := ch as Label
				t.ok(l.clip_text and l.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%s child trims with ellipsis" % box_name)
				children.append(l)
		for i in range(children.size()):
			for j in range(i + 1, children.size()):
				t.ok(not children[i].get_global_rect().intersects(children[j].get_global_rect()), "%s children do not overlap" % box_name)
	var alm := hud.get_node("AlmanacStrip") as Control
	t.eq(alm.size, CardLayout.HUD_ALMANAC.size, "AlmanacStrip fits HUD_ALMANAC")
	var alm_bounds := alm.get_global_rect().grow(1.0)
	var alm_leaves: Array[Control] = []
	for ch in alm.get_children():
		if ch is Control:
			var c := ch as Control
			t.ok(alm_bounds.encloses(c.get_global_rect()), "AlmanacStrip encloses child")
			alm_leaves.append(c)
	for i in range(alm_leaves.size()):
		for j in range(i + 1, alm_leaves.size()):
			t.ok(not alm_leaves[i].get_global_rect().intersects(alm_leaves[j].get_global_rect()), "AlmanacStrip items do not overlap")


## #216 P2：用真实字形宽度验金额槽。999999 原样；七位及以上用“万”；量出来放不下就必须以 … 收尾；
## 单位标签紧跟数字、不压数字、不出 Money 框；Money 框不动。
func _check_money_glyphs(t, hud: Control, view: Dictionary) -> void:
	var wan := CardText.ui("c01.money.wan")
	var cases := {999999: "999999", 1234567: "123" + wan, 987654321: "98765" + wan}
	for amount in cases.keys():
		var v := view.duplicate(true)
		v["money"] = {"amount": amount, "currency": "fabi"}
		hud.call("refresh", v)
		var btn := hud.get_node("Money") as Button
		var unit := btn.get_node("MoneyUnit") as Label
		var font := btn.get_theme_font("font")
		var fsize := btn.get_theme_font_size("font_size")
		var text := btn.text
		var want: String = cases[amount]
		var ell := text.ends_with("…")
		t.ok(text == want or (ell and want.begins_with(text.left(text.length() - 1))), "money %d shows %s (got %s)" % [amount, want, text])
		t.ok(not text.is_valid_int() or text == str(amount), "money %d never shows a different bare number (got %s)" % [amount, text])
		var style := btn.get_theme_stylebox("normal")
		var avail := btn.size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		t.ok(w <= avail + 0.5 or ell, "money %d glyph width %.1f <= %.1f or ends with …" % [amount, w, avail])
		t.ok(unit.position.x >= minf(w, avail), "money %d unit starts after digits (%.1f >= %.1f)" % [amount, unit.position.x, w])
		var unit_w := font.get_string_size(unit.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		t.ok(unit.position.x + minf(unit_w, unit.size.x) <= btn.size.x + 0.5, "money %d unit stays inside Money" % amount)
		t.eq(btn.size, CardLayout.HUD_MONEY.size, "money %d keeps HUD_MONEY size" % amount)
		t.ok(not btn.get_global_rect().intersects((hud.get_node("Rep") as Control).get_global_rect()), "money %d does not touch Rep" % amount)
		t.ok(not btn.get_global_rect().intersects((hud.get_node("Status") as Control).get_global_rect()), "money %d does not touch Status" % amount)


func _blob(node: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if node is Label:
		parts.append((node as Label).text)
	elif node is Button:
		parts.append((node as Button).text)
	for child in node.get_children():
		var more := _blob(child)
		if more != "":
			parts.append(more)
	return " ".join(parts)
