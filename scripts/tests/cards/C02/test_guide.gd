# 牌桌 day_full 上证明人物、金色、留着、过期、生活、消息、命运、回来了吗、大轮盘会亮；换牌后不悬空。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")

var _packed_k16: Dictionary = {}
var _use_k16: bool = false
var _guide = null


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C02_guide"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_use_k16 = _arg("--steps=", "") == "k16"
	S.setup_db()
	var doc := S.read_json("res://scripts/tests/cards/C02/guide_steps.json")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load("res://scenes/cards/CardGame.tscn").instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": "day_full", "skip_title": true, "guide": "off"})
	root.add_child(game)
	var view: Dictionary = {}
	var gold_w: CardWidget = null
	for i in 20:
		await t.frames(1)
		view = game.engine.view()
		gold_w = S.find_uid(game, _uid(view, _is_gold))
		if gold_w != null:
			break
	t.ok(gold_w != null, "gold widget on table")
	var person_uid := _uid(view, _is_person)
	var life_uid := _uid(view, _is_life)
	var news_uid := _uid(view, _is_news)
	var fate_uid := _uid(view, _is_fate)
	var gold_uid := gold_w.get_uid()
	var kept_uid := ""
	for c in view.get("kept", []):
		if int(c.get("expires_in", -1)) >= 0:
			kept_uid = str(c.get("uid", ""))
	t.ok(person_uid != "" and life_uid != "" and news_uid != "" and fate_uid != "" and kept_uid != "", "fixture uids")
	var life_w := S.find_uid(game, life_uid)
	var kept_w := S.find_uid(game, kept_uid)
	var life_days := "" if life_w == null else (life_w.get_node("Days") as Label).text
	var kept_days := "" if kept_w == null else (kept_w.get_node("Days") as Label).text
	# 换皮：角标是原型的“剩 N 天”药丸（今晚到期另写），不再只写数字。
	t.ok(life_w != null and life_days == CardText.ui("c02.days.left", {"n": 3}), "life badge on table")
	var kept_n := _kept_days(view, kept_uid)
	var kept_text := CardText.ui("c02.days.tonight") if kept_n <= 0 else CardText.ui("c02.days.left", {"n": kept_n})
	t.ok(kept_w != null and kept_days == kept_text, "kept badge on table")
	t.ok(t.anchor_ok(StringName("a.card@" + person_uid)), "person anchor")
	t.ok(t.anchor_ok(StringName("a.card.gold@" + gold_uid)), "gold anchor")
	t.ok(t.anchor_ok(StringName("a.card.keep@" + news_uid)), "keep anchor")
	t.ok(t.anchor_ok(StringName("a.card.days@" + life_uid)), "life days anchor")
	t.ok(t.anchor_ok(&"a.hand.kept"), "kept zone anchor")
	t.ok(t.anchor_ok(&"a.hand"), "hand fallback")
	t.ok(t.anchor_ok(&"a.hand.gold"), "gold fallback")
	game.guide.skip_fades = true
	_light(t, game, bus, doc, "gd.d1.person", "person", person_uid)
	_show_step(game, bus, doc, "gd.d2.gold", "gold", gold_uid)
	t.eq(game.guide.active_step(), "gd.d2.gold", "gd.d2.gold lights")
	var replaced: Dictionary = S.states()["draft"].duplicate(true)
	replaced["uid"] = "c0098"
	replaced["gold"] = false
	replaced["actions"] = []
	gold_w.set_card(replaced)
	await t.frames(1)
	t.ok(not CardAnchors.has(StringName("a.card.gold@" + gold_uid)), "old gold anchor cleared")
	t.ok(not CardAnchors.has(StringName("a.card@" + gold_uid)), "old card anchor cleared")
	t.ok(CardAnchors.has(&"a.hand.gold"), "fallback still there")
	game.guide.tick(0.05)
	t.eq(game.guide.active_step(), "gd.d2.gold", "gold step uses fallback")
	_done(bus)
	t.eq(game.guide.active_step(), "", "gold step done")
	_light(t, game, bus, doc, "gd.d2.keep", "keep", news_uid)
	_light(t, game, bus, doc, "gd.life", "life", life_uid)
	_light(t, game, bus, doc, "gd.news", "news", news_uid)
	_light(t, game, bus, doc, "gd.fate", "fate", fate_uid)
	_light(t, game, bus, doc, "gd.kept_expire", "kept_expire", "")
	var ret := _example("demand_return")
	ret["uid"] = "c0097"
	var ret_w := S.mount(self, ret, &"hand", Vector2(250, 80))
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.card@c0097"), "return anchor")
	_light(t, game, bus, doc, "gd.demand_people", "demand_people_return", "c0097")
	var wheel := _example("big_fate")
	wheel["uid"] = "c0096"
	var wheel_w := S.mount(self, wheel, &"hand", Vector2(820, 80))
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.card@c0096"), "wheel anchor")
	_light(t, game, bus, doc, "gd.big_wheel", "big_wheel", "c0096")
	var fan: CardHandFan = load("res://scenes/cards/card/HandFan.tscn").instantiate()
	root.add_child(fan)
	var hero: CardHeroBar = load("res://scenes/cards/card/HeroBar.tscn").instantiate()
	root.add_child(hero)
	await t.frames(1)
	fan.refresh({
		"phase": "day",
		"hand": [{"uid": "gfan", "def": "p.x", "type": "person", "zone": "hand", "gold": true,
			"art": "portrait.linsao", "actions": []}],
		"kept": [{"uid": "gkept", "def": "p.y", "type": "news", "zone": "kept", "gold": false,
			"expires_in": 1, "art": "illus.news", "actions": []}],
	})
	hero.refresh({
		"self": {"uid": "selfg", "used_today": false, "attrs": {"eye": 1, "tongue": 1, "pull": 1, "nerve": 1}},
		"contacts": [{"uid": "ctg", "def": "ct.x", "type": "contact", "zone": "contacts",
			"art": "portrait.linsao", "actions": []}],
	})
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.hand.kept"), "fan kept anchor")
	t.ok(t.anchor_ok(&"a.hero"), "hero anchor")
	t.ok(t.anchor_ok(&"a.contacts"), "contacts anchor")
	_light(t, game, bus, doc, "gd.d1.deal", "deal", "")
	_light(t, game, bus, doc, "gd.contact", "contact", "")
	_light(t, game, bus, doc, "gd.kept_risk", "kept_risk", "")
	_light(t, game, bus, doc, "gd.person_state", "person_state", "")
	fan.queue_free()
	hero.queue_free()
	await _fade(t, game)
	ret_w.queue_free()
	wheel_w.queue_free()
	game.queue_free()
	bus.free()
	await t.frames(2)


func _light(t, game: CardGameRoot, bus: CardEventBus, doc: Dictionary, step_id: String, mech: String,
		uid: String) -> void:
	_show_step(game, bus, doc, step_id, mech, uid)
	t.eq(game.guide.active_step(), step_id, step_id + " lights")
	if _use_k16 and step_id == "gd.d1.person":
		_assert_k16_person(t, game, uid)
	_done(bus)
	t.eq(game.guide.active_step(), "", step_id + " done")
	if _use_k16 and step_id == "gd.d1.person":
		t.ok(game.guide._is_done(step_id), "gd.d1.person completed")


func _show_step(game: CardGameRoot, bus: CardEventBus, doc: Dictionary, step_id: String, mech: String,
		uid: String) -> void:
	game.guide.skip_fades = true
	if _use_k16:
		_guide = game.guide
		game.guide.load_steps(_k16_doc(game))
		_arm_k16(game, step_id)
	else:
		game.guide.load_steps(_one(doc, step_id))
	game.guide.force(true)
	var args := {}
	if uid != "":
		args["uid"] = uid
	bus.first_time.emit(StringName(mech), args)
	game.guide.evaluate_now()


func _is_gold(c: Dictionary) -> bool:
	return bool(c.get("gold", false))


func _is_person(c: Dictionary) -> bool:
	return str(c.get("type", "")) == "person" and not bool(c.get("gold", false))


func _is_life(c: Dictionary) -> bool:
	return str(c.get("type", "")) == "life"


func _is_news(c: Dictionary) -> bool:
	return str(c.get("type", "")) == "news"


func _is_fate(c: Dictionary) -> bool:
	return str(c.get("type", "")) == "fate"


func _fade(t, game: CardGameRoot) -> void:
	var bus2 := CardEventBus.new()
	root.add_child(bus2)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.skip_fades = true
	root.add_child(guide)
	guide.bind(game.engine, bus2)
	guide.load_steps({
		"settings": {"max_new_per_day": 8, "gap_ms": 0, "default_seconds": 30},
		"steps": [{
			"id": "gd.gold.nofallback",
			"trigger": {"first": "gold"},
			"anchor": "a.card.gold@{uid}",
			"anchor_fallback": "",
			"done_when": ["ui:card_zoomed"],
			"priority": 90,
			"max_shows": 2,
			"seconds": 30,
		}],
	})
	guide.force(true)
	var view: Dictionary = S.states()["gold"].duplicate(true)
	view["uid"] = "c0095"
	var w := S.mount(self, view, &"hand", Vector2(480, 80))
	await t.frames(1)
	bus2.first_time.emit(&"gold", {"uid": "c0095"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.gold.nofallback", "fade step lights")
	var other: Dictionary = S.states()["draft"].duplicate(true)
	other["uid"] = "c0094"
	other["gold"] = false
	w.set_card(other)
	await t.frames(1)
	t.ok(not CardAnchors.has(&"a.card.gold@c0095"), "fade primary gone")
	guide.tick(0.05)
	t.eq(guide.active_step(), "", "step fades instead of dangling")
	w.queue_free()
	guide.queue_free()
	bus2.free()
	await t.frames(1)


func _done(bus: CardEventBus) -> void:
	if _use_k16 and _guide != null and _guide._cur != null:
		_finish_k16(bus)
		return
	bus.ui_event.emit(&"card_zoomed", {"uid": "done"})


# K16 done_when is not the W1 ui:card_zoomed. Finish with that step's cmd, ui, or panel token.
func _finish_k16(bus: CardEventBus) -> void:
	if _guide == null or _guide._cur == null:
		return
	var id: String = _guide._cur.id
	var tokens: PackedStringArray = _guide._cur.done
	for tok in tokens:
		var token: String = str(tok)
		if token == "" or token == "timeout":
			continue
		if _guide.active_step() != id:
			return
		_emit_done(bus, token)
		if _guide.active_step() != id:
			return
	if _guide != null and _guide._cur != null and _guide.active_step() == id:
		var secs: float = float(_guide._cur.seconds)
		_guide.tick(secs + 1.0)


func _emit_done(bus: CardEventBus, token: String) -> void:
	if token.begins_with("cmd:"):
		bus.command_done.emit(StringName(token.substr(4)), {}, true)
	elif token.begins_with("ui:"):
		bus.ui_event.emit(StringName(token.substr(3)), {})
	elif token.begins_with("panel:"):
		bus.ui_event.emit(&"panel_opened", {"kind": token.substr(6)})
	elif token.begins_with("first:"):
		bus.first_time.emit(StringName(token.substr(6)), {})


func _assert_k16_person(t, game: CardGameRoot, uid: String) -> void:
	var view: Dictionary = game.engine.view()
	var date: Dictionary = {}
	var raw_date = view.get("date", {})
	if typeof(raw_date) == TYPE_DICTIONARY:
		date = raw_date
	t.eq(int(date.get("stage_day", 0)), 1, "stage_day 1")
	t.eq(str(view.get("phase", "")), "day", "person phase")
	t.eq(str(view.get("mode", "")), "shop", "person mode")
	t.ok(game.guide._is_done("gd.d1.deal"), "after chain through gd.d1.deal")
	t.eq(str(game.guide._anchor_id), "a.card@" + uid, "person anchor")
	var firsts: Dictionary = {}
	var raw_first = game.guide._firsts.get("person", {})
	if typeof(raw_first) == TYPE_DICTIONARY:
		firsts = raw_first
	t.eq(str(firsts.get("uid", "")), uid, "person uid")


# k16 only: day_full is stage_day 9 with almanac already first, so gd.almanac
# (stage_day_gte 4) preempts day-1 steps. Pin stage_day to 1 unless the step
# itself needs a later day, mark every higher-priority step done (that is the
# after chain through gd.d1.deal for gd.d1.person), then the caller emits first_time.
func _arm_k16(game: CardGameRoot, step_id: String) -> void:
	var guide: CardGuide = game.guide
	var steps: Array = _k16_doc(game).get("steps", [])
	var target: Dictionary = {}
	var target_i: int = -1
	for i in range(steps.size()):
		var row: Dictionary = steps[i]
		if str(row.get("id", "")) != step_id:
			continue
		target = row
		target_i = i
		break
	if target_i < 0:
		return
	var pri: int = int(target.get("priority", 50))
	var trig: Dictionary = {}
	var raw_trig = target.get("trigger", {})
	if typeof(raw_trig) == TYPE_DICTIONARY:
		trig = raw_trig
	var day: int = _day_of(trig)
	if step_id == "gd.d1.person":
		day = 1
	_mock_clock(game, day, _phase_of(trig))
	_mark_after_chain(guide, steps, step_id)
	for i in range(steps.size()):
		var row: Dictionary = steps[i]
		var id: String = str(row.get("id", ""))
		if id == step_id:
			continue
		var sp: int = int(row.get("priority", 50))
		if sp > pri or (sp == pri and i < target_i):
			_mark_guide_done(guide, id)
	_clear_guide_done(guide, step_id)


func _day_of(trig: Dictionary) -> int:
	if not trig.has("stage_day_gte"):
		return 1
	return maxi(1, int(trig["stage_day_gte"]))


func _phase_of(trig: Dictionary) -> String:
	if not trig.has("phase"):
		return "day"
	var ph = trig["phase"]
	if typeof(ph) == TYPE_ARRAY:
		var arr: Array = ph
		if arr.is_empty():
			return "day"
		return str(arr[0])
	return str(ph)


func _mock_clock(game: CardGameRoot, stage_day: int, phase: String) -> void:
	var mock: MockCardEngine = game.engine as MockCardEngine
	var date: Dictionary = mock._view.get("date", {})
	date["stage_day"] = stage_day
	mock._view["date"] = date
	mock._view["phase"] = phase
	if str(mock._view.get("mode", "")) == "":
		mock._view["mode"] = "shop"


func _mark_after_chain(guide: CardGuide, steps: Array, step_id: String) -> void:
	var by_id: Dictionary = {}
	for row in steps:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		by_id[str(row.get("id", ""))] = row
	var stack: Array = [step_id]
	var seen: Dictionary = {}
	while not stack.is_empty():
		var cur: String = str(stack.pop_back())
		if seen.has(cur):
			continue
		seen[cur] = true
		var row: Dictionary = {}
		var raw_row = by_id.get(cur, {})
		if typeof(raw_row) == TYPE_DICTIONARY:
			row = raw_row
		var chain_trig: Dictionary = {}
		var raw_chain = row.get("trigger", {})
		if typeof(raw_chain) == TYPE_DICTIONARY:
			chain_trig = raw_chain
		var after = chain_trig.get("after", [])
		if typeof(after) != TYPE_ARRAY:
			continue
		for item in after:
			var aid: String = str(item)
			if aid == "" or aid == step_id:
				continue
			_mark_guide_done(guide, aid)
			stack.append(aid)


func _mark_guide_done(guide: CardGuide, id: String) -> void:
	var prog: Dictionary = {}
	var old = guide._progress.get(id, {})
	if typeof(old) == TYPE_DICTIONARY:
		prog = old
	prog["status"] = "done"
	if not prog.has("shows"):
		prog["shows"] = 0
	prog["abs_day"] = 0
	guide._progress[id] = prog


func _clear_guide_done(guide: CardGuide, id: String) -> void:
	guide._progress.erase(id)


func _k16_doc(game: CardGameRoot) -> Dictionary:
	if _packed_k16.is_empty():
		_packed_k16 = game.engine.query(&"guide_data")
	return _packed_k16


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


func _one(doc: Dictionary, step_id: String) -> Dictionary:
	var steps: Array = []
	for s in doc.get("steps", []):
		if str(s.get("id", "")) == step_id:
			steps.append(s)
	return {"steps": steps, "settings": doc.get("settings", {})}


func _example(key: String) -> Dictionary:
	for row in S.examples():
		if str(row.get("key", "")) == key:
			return (row["view"] as Dictionary).duplicate(true)
	return {}


func _uid(view: Dictionary, pred: Callable) -> String:
	for zone in ["hand", "kept", "contacts", "demands"]:
		for c in view.get(zone, []):
			if pred.call(c):
				return str(c.get("uid", ""))
	return ""


func _kept_days(view: Dictionary, uid: String) -> int:
	for c in view.get("kept", []):
		if str(c.get("uid", "")) == uid:
			return int(c.get("expires_in", -1))
	return -1
