# C03 W2: example set and real K-data resident-ID check. Open the panel, autoplay until done.
# Coin faces are read from CoinFace after coins_finished / skip, not from the build-time meta.
# coins_finished(success) must carry the same success as the engine's coins_tossed (#209).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const PANEL := "res://scenes/cards/slots/SlotPanel.tscn"
const CHECK := "ev.1938.police_check"


func _initialize() -> void:
	var name: String = "C03_real_engine"
	var kdata: bool = false
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--name="):
			name = str(arg).substr("--name=".length())
		elif str(arg) == "--kdata":
			kdata = true
	var t = T.new(self, name)
	if kdata:
		t.run_async(_kdata.bind(t))
	else:
		t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine := CardEngine.new(bus)
	var opened: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": true,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(opened.get("ok", false)), "new_game")
	var spun: Dictionary = engine.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "month wheel")
	var morning: Dictionary = engine.send(&"month.begin", {})
	t.ok(bool(morning.get("ok", false)), "month.begin")
	var uid := ""
	var day := 0
	while uid == "" and day < 12 and bool(opened.get("ok", false)):
		day += 1
		var deal: Dictionary = engine.send(&"day.begin", {})
		t.ok(bool(deal.get("ok", false)), "day.begin %d %s" % [day, str(deal.get("err", ""))])
		if not bool(deal.get("ok", false)):
			break
		uid = _hand_uid(engine, CHECK)
		if uid == "":
			if not _next_morning(t, engine):
				break
	t.ok(uid != "", "example set dealt %s" % CHECK)
	if uid == "":
		bus.free()
		return
	await _play_check(t, engine, bus, uid, "example")
	bus.free()
	engine = null


func _kdata(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine := CardEngine.new(bus)
	var opened: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": false,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(opened.get("ok", false)), "kdata new_game " + str(opened.get("err", "")))
	t.ok(engine.ctx != null and engine.ctx.db != null and not engine.ctx.db.only_examples, "real K card set")
	var spun: Dictionary = engine.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "kdata month wheel " + str(spun.get("err", "")))
	var morning: Dictionary = engine.send(&"month.begin", {})
	t.ok(bool(morning.get("ok", false)), "kdata month.begin " + str(morning.get("err", "")))
	var deal: Dictionary = engine.send(&"day.begin", {})
	t.ok(bool(deal.get("ok", false)), "kdata day.begin " + str(deal.get("err", "")))
	var uid: String = ""
	if bool(opened.get("ok", false)) and engine.ctx != null:
		uid = CardPiles.spawn(engine.ctx, CHECK, CardIds.ZONE_HAND)
	t.ok(uid != "", "issued " + CHECK)
	if uid == "":
		bus.free()
		return
	var card: Dictionary = engine.query(&"card", {"uid": uid})
	t.eq(str(card.get("def", "")), CHECK, "kdata card def")
	t.eq(str(card.get("panel", "")), "slots", "kdata slots panel")
	await _play_check(t, engine, bus, uid, "kdata")
	bus.free()
	engine = null


func _play_check(t, engine: CardEngine, bus: CardEventBus, uid: String, label: String) -> void:
	var card: Dictionary = engine.query(&"card", {"uid": uid})
	t.eq(str(card.get("def", "")), CHECK, label + " card def")
	t.eq(str(card.get("panel", "")), "slots", label + " slots panel")
	var watch := Watch.new()
	watch.target = uid
	bus.coins_tossed.connect(watch.on_coins)
	var panel := (load(PANEL) as PackedScene).instantiate() as CardSlotPanel
	panel.bind(engine, bus)
	root.add_child(panel)
	panel.open({"uid": uid})
	await t.frames(2)
	_ui_ok(t, panel)
	var checks: CardCounterChecks = panel.find_child("Checks", true, false) as CardCounterChecks
	var checks_hits: Array = [0]
	var toss_hits: Array = [0]
	var armed: Array = [false]
	var snap: Dictionary = {"faces": [], "heads": "", "success": null}
	if checks != null:
		checks.coins_finished.connect(func(success: bool) -> void:
			checks_hits[0] = int(checks_hits[0]) + 1
			snap["success"] = success
			var toss_now: Node = panel.find_child("CoinToss", true, false)
			if toss_now == null:
				return
			snap["faces"] = _coin_nodes(toss_now)
			var heads_label: Label = toss_now.find_child("HeadsCount", true, false) as Label
			if heads_label != null:
				snap["heads"] = heads_label.text
		)
	var steps := 0
	var running := true
	while running and steps < 24:
		running = panel.autoplay_step()
		_arm_toss(panel, toss_hits, armed)
		steps += 1
		if running:
			await t.frames(1)
	t.ok(not running, label + " autoplay_step finished")
	t.ok(steps > 0 and steps < 24, label + " autoplay steps %d" % steps)
	var tossed: Array = watch.rows
	t.eq(tossed.size(), 1, label + " one coins_tossed")
	if tossed.size() == 1:
		var faces: Array = tossed[0]
		var shown: Array = snap["faces"] if typeof(snap["faces"]) == TYPE_ARRAY else []
		t.ok(faces.size() > 0, label + " resident check tosses coins")
		t.eq(checks_hits[0], 1, label + " coins_finished once")
		t.eq(snap["success"], watch.success, label + " coins_finished carries the engine's success")
		t.eq(toss_hits[0], 1, label + " CoinToss.finished once")
		t.eq(shown.size(), faces.size(), label + " coin count")
		var heads_n := 0
		for i in faces.size():
			var row: Dictionary = shown[i] if i < shown.size() and typeof(shown[i]) == TYPE_DICTIONARY else {}
			t.eq(bool(row.get("face", false)), bool(faces[i]), label + " CoinFace.face %d" % i)
			t.eq(bool(row.get("shown", false)), true, label + " CoinFace.shown %d" % i)
			if bool(faces[i]):
				heads_n += 1
		t.eq(str(snap.get("heads", "")), str(heads_n), label + " heads count")
	if bus.coins_tossed.is_connected(watch.on_coins):
		bus.coins_tossed.disconnect(watch.on_coins)
	_release(panel)
	panel.free()


func _hand_uid(engine: CardEngine, def_id: String) -> String:
	var view: Dictionary = engine.view()
	for row in _rows(view.get("hand", [])):
		if str(row.get("def", "")) == def_id:
			return str(row.get("uid", ""))
	return ""


func _next_morning(t, engine: CardEngine) -> bool:
	var end: Dictionary = engine.send(&"day.end", {"confirm": true})
	t.ok(bool(end.get("ok", false)), "day.end %s" % str(end.get("err", "")))
	if not bool(end.get("ok", false)):
		return false
	var picked: Dictionary = {}
	for row in _rows(engine.view().get("night_offers", [])):
		if str(row.get("def", "")) == "nt.tidy":
			picked = row
			break
		if picked.is_empty():
			picked = row
	t.ok(not picked.is_empty(), "night offer")
	if picked.is_empty():
		return false
	var args: Dictionary = {"def": str(picked.get("def", ""))}
	var choices: Array = _rows(picked.get("choices", []))
	if not choices.is_empty():
		var choice = choices[0]
		if typeof(choice) == TYPE_DICTIONARY:
			args["choice"] = str(choice.get("id", ""))
		else:
			args["choice"] = str(choice)
	var night: Dictionary = engine.send(&"night.choose", args)
	t.ok(bool(night.get("ok", false)), "night.choose %s" % str(night.get("err", "")))
	if not bool(night.get("ok", false)):
		return false
	var settle: Dictionary = engine.send(&"settle.next", {})
	t.ok(bool(settle.get("ok", false)), "settle.next %s" % str(settle.get("err", "")))
	return bool(settle.get("ok", false))


func _release(panel: CardSlotPanel) -> void:
	var checks: CardCounterChecks = panel.find_child("Checks", true, false) as CardCounterChecks
	if checks != null:
		checks.engine = null
		checks.bus = null
	panel.engine = null
	panel.bus = null


func _ui_ok(t, node: Node) -> void:
	var bad: PackedStringArray = t.all_text_from_cardtext(node)
	t.ok(bad.is_empty(), "text from CardText: %s" % ", ".join(bad))
	var pct := PackedStringArray()
	for n in _walk(node):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).get_parsed_text()
		if txt.contains("%"):
			pct.append(txt)
	t.ok(pct.is_empty(), "percent on ui: %s" % ", ".join(pct))


func _arm_toss(panel: Node, toss_hits: Array, armed: Array) -> void:
	if bool(armed[0]):
		return
	var toss: Node = panel.find_child("CoinToss", true, false)
	if toss == null or not (toss is CardCoinTossView):
		return
	var view := toss as CardCoinTossView
	view.finished.connect(func() -> void:
		toss_hits[0] = int(toss_hits[0]) + 1
	)
	armed[0] = true
	if not view.is_playing():
		toss_hits[0] = int(toss_hits[0]) + 1


func _coin_nodes(toss: Node) -> Array:
	var out: Array = []
	var i := 0
	while true:
		var coin: Node = toss.find_child("Coin%d" % i, true, false)
		if coin == null:
			break
		out.append({
			"face": bool(coin.get("face")),
			"shown": bool(coin.get("shown")),
		})
		i += 1
	return out


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func _rows(raw) -> Array:
	if typeof(raw) != TYPE_ARRAY:
		return []
	return raw


class Watch:
	extends RefCounted
	var rows: Array = []
	var target: String = ""
	var success = null

	func on_coins(card_uid: String, faces: Array, _need: int, p_success: bool) -> void:
		if card_uid == target:
			rows.append(faces.duplicate())
			success = p_success
