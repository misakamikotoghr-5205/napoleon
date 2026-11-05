# K17 真实指引链（合同 1.4，#182 第 5 条）：真牌库 1940 关 + 真 CardEngine + 真 GuideOverlay（CardGuide）+ 真 CardWidget 锚点。
# 第 14 天自然发牌 → first office 带 uid → gd.office 亮在 a.card.gold@<uid> 上 → 公开 card.choose 完成 →
# ui.guide 进度（shown→done）写进引擎 → 存档 → 新引擎读档 + 新 CardGuide 绑定：进度 done 读回，
# 锚点（a.hand.gold 兜底）、firsts.office、白天阶段都在，gd.office 仍不再亮（后续三天每天开门都评一次）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const ID := "p.ma.1940.baozhang"
const STEP := "gd.office"
const DAY := 14


func _initialize() -> void:
	var t := T.new(self, "K17_baozhang_guide")
	t.run_async(_body.bind(t))


func _ok(t, e: CardEngine, cmd: StringName, args: Dictionary, tag: String) -> Dictionary:
	var res := e.send(cmd, args)
	t.ok(bool(res.get("ok", false)), "%s: %s %s" % [tag, cmd, res.get("err", "")])
	return res


func _uid(e: CardEngine) -> String:
	for c in e.view().get("hand", []):
		if str(c.get("def", "")) == ID: return str(c["uid"])
	return ""


func _card_view(e: CardEngine, uid: String) -> Dictionary:
	for c in e.view().get("hand", []):
		if str(c.get("uid", "")) == uid: return c
	return {}


func _close(t, e: CardEngine, tag: String) -> void:
	_ok(t, e, &"day.end", {"confirm": true}, tag)
	var offers: Array = e.view().get("night_offers", [])
	if offers.is_empty():
		t.ok(false, tag + ": night offers present")
		return
	var row: Dictionary = offers[0]
	for o in offers:
		if str(o.get("def", "")) == "nt.tidy": row = o
	var args := {"def": str(row["def"])}
	if not (row.get("choices", []) as Array).is_empty(): args["choice"] = str(row["choices"][0])
	_ok(t, e, &"night.choose", args, tag)
	_ok(t, e, &"settle.next", {}, tag)


func _progress(e: CardEngine) -> Dictionary:
	var p: Dictionary = e.query(&"guide_progress").get("progress", {})
	var row = p.get(STEP, {})
	return row if typeof(row) == TYPE_DICTIONARY else {}


func _guide(bus: CardEventBus, e: CardEngine) -> CardGuide:
	var g := (load(GUIDE) as PackedScene).instantiate() as CardGuide
	root.add_child(g)
	g.bind(e, bus)
	g.force(true)
	g.skip_fades = true
	return g


func _body(t) -> void:
	var tag := "guide"
	var bus := CardEventBus.new()
	root.add_child(bus)
	var e := CardEngine.new(bus)
	var r := e.new_game({"seed": 11, "stage": 2, "only_examples": false, "save_dir": t.user_dir() + "/k17_guide"})
	t.ok(bool(r.get("ok", false)), "real 1940 new game " + str(r.get("err", "")))
	var g := _guide(bus, e)
	await t.frames(1)
	var steps: Array = e.query(&"guide_data").get("steps", [])
	var has_step := false
	for s in steps:
		if str(s.get("id", "")) == STEP: has_step = true
	t.ok(has_step, "real guide_data carries " + STEP)
	_ok(t, e, &"wheel.spin", {"wheel": "wh.month", "uid": ""}, tag)
	_ok(t, e, &"month.begin", {}, tag)
	for d in range(1, DAY):
		_ok(t, e, &"day.begin", {}, tag)
		await t.frames(1)
		g.evaluate_now()
		t.ok(not g.shown_log.has(STEP), "%s not shown before day %d (day %d)" % [STEP, DAY, d])
		if str(e.view()["phase"]) == "game_over":
			t.ok(false, "unexpected game_over day %d" % d)
			return
		if g.active_step() != "": g._dismiss()
		_close(t, e, tag)
		await t.frames(1)
	_ok(t, e, &"day.begin", {}, tag)
	t.eq(int(e.view()["date"]["stage_day"]), DAY, "reached day 14")
	var uid := _uid(e)
	t.ok(uid != "", "baozhang dealt on day 14")
	t.eq(g._uid_of("office"), uid, "guide heard first office with the dealt card uid")
	t.ok(_progress(e).is_empty(), "no gd.office progress before it is shown")
	# 真牌面：CardWidget 自己登记 a.card@uid 与 a.card.gold@uid
	var w := CardWidget.new()
	w.fast_anim = true
	w.set_size_mode(&"hand")
	w.set_card(_card_view(e, uid))
	w.position = Vector2(560, 480)
	root.add_child(w)
	await t.frames(2)
	var anchor := StringName("a.card.gold@" + uid)
	t.ok(t.anchor_ok(anchor), "real CardWidget registers " + str(anchor))
	g.evaluate_now()
	# K16 10-22 (prototype): steps no longer chain across days, so in a fresh 1940 game the first gold
	# card also teaches the gold rule (gd.d2.gold, higher priority). The player reads it and presses got it.
	var reads := 0
	while g.active_step() != STEP and g.active_step() != "" and reads < 4:
		g.acknowledge()
		g.evaluate_now()
		reads += 1
	t.eq(g.active_step(), STEP, "gd.office lit on day 14")
	t.eq(str(g._anchor_now), str(anchor), "gd.office points at the baozhang gold card")
	t.eq(g.shown_log.count(STEP), 1, "shown once")
	await t.frames(2)
	var p1 := _progress(e)
	t.eq(str(p1.get("status", "")), "shown", "engine ui.guide progress = shown")
	t.eq(int(p1.get("shows", 0)), 1, "engine ui.guide shows = 1")
	# 公开指令选一个走向 → done_when cmd:card.choose
	_ok(t, e, &"card.choose", {"uid": uid, "choice": "nominal"}, tag)
	t.eq(g.active_step(), "", "card.choose completes gd.office")
	await t.frames(2)
	var p2 := _progress(e)
	t.eq(str(p2.get("status", "")), "done", "engine ui.guide progress = done")
	t.eq(int(p2.get("shows", 0)), 1, "still one show")
	w.queue_free()
	await t.frames(1)
	_close(t, e, tag)
	await t.frames(1)
	var path: String = t.user_dir() + "/k17_guide/mid.json"
	_ok(t, e, &"game.save", {"path": path}, tag)
	# 读档：新引擎、新指引
	var b2 := CardEventBus.new()
	root.add_child(b2)
	var e2 := CardEngine.new(b2)
	var lr := e2.load_game(path)
	t.ok(bool(lr.get("ok", false)), "load " + str(lr.get("err", "")))
	t.eq(str(_progress(e2).get("status", "")), "done", "gd.office done survives save/load")
	t.ok((e2.query(&"firsts").get("firsts", {}) as Dictionary).has("office"), "firsts.office survives load")
	var g2 := _guide(b2, e2)
	# 兜底锚点 a.hand.gold 在场：没有“done”就会亮——证明不亮只因为读回的进度
	var slot := Control.new()
	slot.position = Vector2(40, 600)
	slot.size = Vector2(120, 80)
	root.add_child(slot)
	await t.frames(1)
	CardAnchors.register(&"a.hand.gold", slot)
	t.ok(t.anchor_ok(&"a.hand.gold"), "fallback anchor a.hand.gold present after load")
	t.eq(str(g2._progress.get(STEP, {}).get("status", "")), "done", "loaded CardGuide rebuilt progress done")
	for d in range(DAY + 1, DAY + 4):
		_ok(t, e2, &"day.begin", {}, tag + "/loaded")
		await t.frames(1)
		t.eq(str(e2.view()["phase"]), "day", "loaded: day phase on day %d" % d)
		g2.evaluate_now()
		t.ok(g2.active_step() != STEP, "loaded: gd.office not re-shown (day %d)" % d)
		if g2.active_step() != "": g2._dismiss()
		_close(t, e2, tag + "/loaded")
		await t.frames(1)
	t.ok(not g2.shown_log.has(STEP), "loaded guide never showed gd.office")
	t.eq(int(_progress(e2).get("shows", 0)), 1, "loaded: shows stays 1")
	# 对照：同一读档、同样锚点和阶段，进度清掉的指引会亮——上面的“不亮”不是环境缺件
	var g3 := (load(GUIDE) as PackedScene).instantiate() as CardGuide
	root.add_child(g3)
	g3.skip_fades = true
	g3.force(true)
	g3.bind(e2, b2)
	g3._progress.erase(STEP)
	_ok(t, e2, &"day.begin", {}, tag + "/control")
	await t.frames(1)
	g3._progress.erase(STEP)
	g3.evaluate_now()
	var lit := g3.active_step() == STEP or g3.shown_log.has(STEP)
	t.ok(lit, "control: without done progress gd.office would show on fallback anchor (active=%s)" % g3.active_step())
	g3.set_enabled(false)
	g3.force(false)
	await t.frames(1)
	for n in [g3, g2, slot, g, b2, bus]:
		n.queue_free()
	await t.frames(2)
