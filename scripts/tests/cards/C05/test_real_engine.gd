# Real engine, example set: reach the first Monday, board shows slips, panel autoplay finishes.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C05/support.gd")
const PANEL := "res://scenes/cards/demand/DemandPanel.tscn"

var _last_err: String = ""


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C05_real_engine"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var real_data: bool = _arg("--name=", "C05_real_engine") == "C05_real_data"
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng := CardEngine.new(bus)
	var started: Dictionary = eng.new_game({
		"seed": 7,
		"only_examples": not real_data,
		"save_dir": t.user_dir(),
	})
	await t.frames(1)
	t.ok(bool(started.get("ok", false)), "real new game " + str(started.get("err", "")))
	var reached := _until_monday(eng)
	t.ok(reached, "first monday " + _last_err + " " + _stamp(eng))
	var view: Dictionary = eng.view()
	var demands := _demands(view)
	t.ok(not demands.is_empty(), "view slips")
	var board := S.mount_board(self)
	board.refresh(view)
	await t.frames(1)
	var list := board.get_node("Scroll/List")
	t.ok(list.get_child_count() > 0, "board rows")
	t.eq(list.get_child_count(), demands.size(), "board shows every slip")
	var uid := ""
	var before_days := -1
	var before_tier := -1
	var kind: String = ""
	if not demands.is_empty() and typeof(demands[0]) == TYPE_DICTIONARY:
		var first: Dictionary = demands[0]
		uid = str(first.get("uid", ""))
		before_days = int(first.get("days_left", -1))
		var meta = first.get("demand", {})
		if typeof(meta) == TYPE_DICTIONARY:
			before_tier = int(meta.get("tier", -1))
			kind = str(meta.get("kind", ""))
	t.ok(uid != "", "slip uid")
	t.ok(list.get_node_or_null("Row_" + uid) != null, "row for slip")
	var panel: CardDemandPanel = load(PANEL).instantiate()
	root.add_child(panel)
	panel.bind(eng, bus)
	panel.open({"uid": uid})
	await t.frames(1)
	t.eq(panel._uid, uid, "panel opened")
	# #73: the real engine's demand CardView carries amount; the panel uses that number.
	var cv: Dictionary = eng.query(&"card", {"uid": uid})
	t.ok(cv.has("amount"), "real demand card view has amount")
	t.eq(panel._amount, int(cv.get("amount", -1)), "panel amount follows the engine")
	var closed := {"v": false}
	panel.close_requested.connect(func(_r: Dictionary) -> void: closed["v"] = true)
	var guard := 0
	while not bool(closed["v"]) and guard < 48:
		if not panel.autoplay_step():
			break
		guard += 1
		await t.frames(1)
	t.ok(bool(closed["v"]), "autoplay finished step=" + panel._step + " guard=" + str(guard))
	var gone := true
	var after_days := before_days
	var after_tier := before_tier
	for row in _demands(eng.view()):
		if typeof(row) != TYPE_DICTIONARY or str(row.get("uid", "")) != uid:
			continue
		gone = false
		after_days = int(row.get("days_left", -1))
		var meta2 = row.get("demand", {})
		if typeof(meta2) == TYPE_DICTIONARY:
			after_tier = int(meta2.get("tier", -1))
	t.ok(gone or after_days != before_days or after_tier != before_tier, "slip resolved or delayed")
	if real_data:
		var stock: Dictionary = eng.query(&"stock", {})
		var items: Array = stock.get("items", []) if typeof(stock.get("items")) == TYPE_ARRAY else []
		t.eq(kind, "goods", "real monday slip is goods")
		t.eq(items.size(), 0, "shelf has no goods to hand over")
		t.ok(panel._skipped.has("pay"), "out of stock skips pay")
		t.ok(bool(closed["v"]), "out of stock fallback still finishes")
	board.queue_free()
	panel.queue_free()
	bus.queue_free()
	await t.frames(2)


func _until_monday(eng: CardEngine) -> bool:
	for _i in range(96):
		var view: Dictionary = eng.view()
		if _is_monday(view):
			return true
		if str(view.get("phase", "")) == "game_over":
			_last_err = "game_over " + str(view.get("game_over_reason", ""))
			return false
		var result: Dictionary = _advance(eng, view)
		if not bool(result.get("ok", false)):
			_last_err = str(view.get("phase", "")) + " " + str(result.get("err", ""))
			return false
	_last_err = "cap"
	return false


func _is_monday(view: Dictionary) -> bool:
	var date := _date(view)
	if int(date.get("weekday", -1)) != 0:
		return false
	if int(date.get("stage_day", 0)) < 1:
		return false
	return not _demands(view).is_empty()


func _advance(eng: CardEngine, view: Dictionary) -> Dictionary:
	var phase := str(view.get("phase", ""))
	if phase == "month_open":
		var spun: Dictionary = eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
		if bool(spun.get("ok", false)):
			return eng.send(&"month.begin", {})
		return eng.send(&"day.end", {"confirm": true})
	if phase == "morning":
		return eng.send(&"day.begin", {})
	return eng.send(&"day.end", {"confirm": true})


func _demands(view: Dictionary) -> Array:
	var raw = view.get("demands", [])
	if typeof(raw) == TYPE_ARRAY:
		return raw
	return []


func _date(view: Dictionary) -> Dictionary:
	var raw = view.get("date", {})
	if typeof(raw) == TYPE_DICTIONARY:
		return raw
	return {}


func _stamp(eng: CardEngine) -> String:
	var view: Dictionary = eng.view()
	var date := _date(view)
	return "phase=%s day=%s wd=%s slips=%d" % [
		str(view.get("phase", "")),
		str(date.get("stage_day", "")),
		str(date.get("weekday", "")),
		_demands(view).size(),
	]


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback
