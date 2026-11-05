# Real K data (only_examples false, seed 7). fortune.lot must return a lot id
# from the real pool, the strip must show that day's yi/ji, and K16
# gd.almanac / gd.lot / gd.cezi must light and finish on the engine's own steps.
# Public results only: lot id and almanac query. No future cards, days, or odds.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C07/c07_harness.gd")
const GUIDE_SCENE := "res://scenes/cards/shell/GuideOverlay.tscn"


func _initialize() -> void:
	var t := T.new(self, "C07_real_k")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var eng := CardEngine.new(bus)
	var opened: Dictionary = eng.new_game({
		"seed": 7,
		"only_examples": false,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(opened.get("ok", false)), "new game")
	t.ok(not eng.ctx.db.only_examples, "only_examples false")
	t.ok(eng.ctx.db.has("ev.1938.tut_fortune"), "real fortune card is loaded")
	var spun: Dictionary = eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "month wheel")
	var month: Dictionary = eng.send(&"month.begin", {})
	t.ok(bool(month.get("ok", false)), "month begin")
	var begun: Dictionary = eng.send(&"day.begin", {})
	t.ok(bool(begun.get("ok", false)), "day begin")
	if not _reach(t, eng, 4):
		_drop(bus)
		return
	var strip: CardAlmanacStrip = load(H.STRIP).instantiate() as CardAlmanacStrip
	strip.position = Vector2(420, 3)
	root.add_child(strip)
	await t.frames(1)
	var view: Dictionary = eng.view()
	strip.refresh(view)
	await t.frames(1)
	var alm: Dictionary = eng.query(&"almanac")
	t.no_leaks(alm, "almanac")
	var notice: Dictionary = view.get("notice", {})
	var from_view: Dictionary = {}
	if typeof(notice.get("almanac", {})) == TYPE_DICTIONARY:
		from_view = notice.get("almanac", {})
	t.eq(from_view.get("yi", []), alm.get("yi", []), "view yi is the engine almanac")
	t.eq(from_view.get("ji", []), alm.get("ji", []), "view ji is the engine almanac")
	var yi: Array = alm.get("yi", []) if typeof(alm.get("yi", [])) == TYPE_ARRAY else []
	var ji: Array = alm.get("ji", []) if typeof(alm.get("ji", [])) == TYPE_ARRAY else []
	t.ok(str(alm.get("id", "")) != "" and (yi.size() > 0 or ji.size() > 0), "engine almanac has yi or ji")
	var tip: Node = strip._make_custom_tooltip(".")
	_shown(t, strip, tip, yi, "yi")
	_shown(t, strip, tip, ji, "ji")
	t.eq(t.all_text_from_cardtext(strip).size(), 0, "strip text is CardText")
	t.ok(not _has_percent(strip) and not _has_percent(tip), "strip has no odds")
	tip.free()
	var data: Dictionary = eng.query(&"guide_data")
	var almanac_step: Dictionary = _step(data, "gd.almanac")
	var lot_step: Dictionary = _step(data, "gd.lot")
	var cezi_step: Dictionary = _step(data, "gd.cezi")
	t.ok(not almanac_step.is_empty() and not lot_step.is_empty() and not cezi_step.is_empty(), "guide_data has the three steps")
	t.ok(_done_has(almanac_step, "cmd:day.end"), "almanac done_when includes day.end")
	t.ok(_done_has(lot_step, "cmd:fortune.lot"), "lot done_when includes fortune.lot")
	t.ok(_done_has(cezi_step, "cmd:fortune.cezi"), "cezi done_when includes fortune.cezi")
	var guide: CardGuide = (load(GUIDE_SCENE) as PackedScene).instantiate() as CardGuide
	guide.force(true)
	guide.skip_fades = true
	root.add_child(guide)
	guide.bind(eng, bus)
	await t.frames(1)
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.almanac", "almanac step lights")
	t.eq(str(guide._anchor_now), str(almanac_step.get("anchor", "")), "almanac uses its anchor")
	t.ok(t.anchor_ok(guide._anchor_now), "a.almanac")
	var ended: Dictionary = eng.send(&"day.end", {"confirm": true})
	t.ok(bool(ended.get("ok", false)), "day.end")
	t.eq(guide.active_step(), "", "almanac step completes")
	if not _reach(t, eng, 5):
		_drop(bus, strip, guide)
		return
	var uid := _fortune_uid(eng)
	t.ok(uid != "", "fortune card is in hand")
	if uid == "":
		_drop(bus, strip, guide)
		return
	var panel: CardFortunePanel = load(H.PANEL).instantiate() as CardFortunePanel
	panel.bind(eng, bus)
	panel.fast_anim = true
	root.add_child(panel)
	panel.open({"uid": uid})
	await t.frames(1)
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.lot", "lot step lights")
	t.eq(str(guide._anchor_now), str(lot_step.get("anchor", "")), "lot uses its anchor")
	t.ok(t.anchor_ok(guide._anchor_now), "a.fortune.lot")
	var lot_btn := H.button_by_key(panel, "c07.btn.lot")
	t.ok(lot_btn != null, "lot reply")
	if lot_btn != null:
		lot_btn.pressed.emit()
	var fortune_q: Dictionary = eng.query(&"fortune", {"uid": uid})
	t.no_leaks(fortune_q, "fortune")
	var last: Dictionary = {}
	if typeof(fortune_q.get("last", {})) == TYPE_DICTIONARY:
		last = fortune_q.get("last", {})
	var lot_id := str(last.get("lot", ""))
	var era := str(eng.view().get("date", {}).get("era", ""))
	var pool: PackedStringArray = eng.ctx.db.pool(&"fortune_lot", era)
	t.ok(lot_id != "" and pool.has(lot_id), "lot in real pool")
	t.eq(guide.active_step(), "", "lot step completes")
	t.ok(not _has_percent(panel), "panel has no odds")
	t.eq(t.all_text_from_cardtext(panel).size(), 0, "panel text is CardText")
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.cezi", "cezi step lights")
	t.eq(str(guide._anchor_now), str(cezi_step.get("anchor", "")), "cezi uses its anchor")
	t.ok(t.anchor_ok(guide._anchor_now), "a.fortune.cezi")
	var cezi_btn := H.button_by_key(panel, "c07.btn.cezi")
	t.ok(cezi_btn != null, "cezi reply")
	if cezi_btn != null:
		cezi_btn.pressed.emit()
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.fortune.chars"), "a.fortune.chars")
	var buttons: Array = H.char_buttons(panel)
	t.ok(buttons.size() >= 1, "characters are on the mat")
	if not buttons.is_empty():
		var pick: int = mini(1, buttons.size() - 1)
		(buttons[pick] as Button).pressed.emit()
	t.eq(guide.active_step(), "", "cezi step completes")
	t.ok(guide.shown_log.has("gd.almanac") and guide.shown_log.has("gd.lot") and guide.shown_log.has("gd.cezi"), "three steps were shown")
	t.ok(not _has_percent(panel), "reading has no odds")
	panel.queue_free()
	_drop(bus, strip, guide)
	await t.frames(2)


func _reach(t, eng: CardEngine, day_at_least: int) -> bool:
	var guard := 0
	while guard < 40:
		var view: Dictionary = eng.view()
		var phase := str(view.get("phase", ""))
		var stage_day := int(view.get("date", {}).get("stage_day", 0))
		if phase == "game_over":
			t.ok(false, "game ended before the fortune steps")
			return false
		if phase == "day" and stage_day >= day_at_least:
			return true
		var adv: Dictionary = eng.send(&"day.end", {"confirm": true})
		if not bool(adv.get("ok", false)):
			t.ok(false, "could not advance")
			return false
		guard += 1
	t.ok(false, "did not reach the fortune steps")
	return false


func _fortune_uid(eng: CardEngine) -> String:
	var hand: Array = eng.view().get("hand", [])
	for card in hand:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = card
		if str(row.get("panel", "")) == "fortune":
			return str(row.get("uid", ""))
	return ""


func _step(data: Dictionary, id: String) -> Dictionary:
	var steps: Array = data.get("steps", []) if typeof(data.get("steps", [])) == TYPE_ARRAY else []
	for step in steps:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = step
		if str(row.get("id", "")) == id:
			return row
	return {}


func _done_has(step: Dictionary, token: String) -> bool:
	var done: Array = step.get("done_when", []) if typeof(step.get("done_when", [])) == TYPE_ARRAY else []
	return done.has(token)


func _shown(t, strip: Node, tip: Node, actions: Array, label: String) -> void:
	for action in actions:
		var word := CardText.ui("g05.almanac." + str(action))
		var n := H.count_text(strip, word) + H.count_text(tip, word)
		t.ok(n >= 1, "strip shows " + label)


func _has_percent(node: Node) -> bool:
	for n in H.walk(node):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		if txt.contains("%"):
			return true
	return false


func _drop(bus: Node, strip: Node = null, guide: Node = null) -> void:
	if guide != null and is_instance_valid(guide):
		guide.queue_free()
	if strip != null and is_instance_valid(strip):
		strip.queue_free()
	if is_instance_valid(bus):
		bus.queue_free()
