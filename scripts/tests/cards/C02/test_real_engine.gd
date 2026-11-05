# Real CardEngine day.begin, then every hand CardView renders through CardWidget.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")
const HAND := Vector2(144, 200)


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C02_real_engine"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var real: bool = t.name == "C02_real_data"
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	var engine := CardEngine.new(bus)
	var opts: Dictionary = {"seed": 7, "only_examples": true, "save_dir": t.user_dir()}
	if real:
		opts["only_examples"] = false
	var r: Dictionary = engine.new_game(opts)
	t.ok(bool(r.get("ok", false)), "new_game " + str(r.get("err", "")))
	if real:
		t.ok(not engine.ctx.db.only_examples, "real 1938 set")
	var spun: Dictionary = engine.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "month wheel " + str(spun.get("err", "")))
	var month: Dictionary = engine.send(&"month.begin", {})
	t.ok(bool(month.get("ok", false)), "month.begin " + str(month.get("err", "")))
	var begun: Dictionary = engine.send(&"day.begin", {})
	t.ok(bool(begun.get("ok", false)), "day.begin " + str(begun.get("err", "")))
	# Example set day 1 is scripted and deals nothing. Real 1938 day 1 already has a hand.
	var view: Dictionary = engine.view()
	if not real:
		view = _until_hand(t, engine)
	t.eq(str(view.get("phase", "")), "day", "phase is day")
	if real:
		var date: Dictionary = {}
		var raw_date = view.get("date", {})
		if typeof(raw_date) == TYPE_DICTIONARY:
			date = raw_date
		t.eq(int(date.get("stage_day", 0)), 1, "stage day 1")
	var hand: Array = _dicts(view.get("hand", []))
	t.ok(not hand.is_empty(), "day.begin dealt a hand")
	var fan: CardHandFan = load("res://scenes/cards/card/HandFan.tscn").instantiate()
	fan.bus = bus
	root.add_child(fan)
	var w := S.mount(self, {}, &"hand", Vector2(24, 24))
	await t.frames(1)
	fan.refresh(view)
	await t.frames(2)
	var rendered := 0
	for card in hand:
		var cv: Dictionary = card
		var uid := str(cv.get("uid", ""))
		var def_id := str(cv.get("def", ""))
		w.set_size_mode(&"hand")
		w.set_card(cv)
		await t.frames(1)
		t.eq(w.size, HAND, uid + " size")
		t.eq(w.custom_minimum_size, HAND, uid + " min")
		t.eq(w.get_uid(), uid, uid + " uid")
		t.ok(w.is_inside_tree() and w.visible, uid + " on tree")
		var expect := ""
		if def_id != "":
			expect = CardText.card(def_id, "title")
		var title := w.get_node("Title") as Label
		t.eq(title.text, expect, uid + " title")
		var art := S.art(w)
		var base := S.art_base(cv)
		t.eq(art.size, Vector2(base.x * S.art_k(&"hand"), base.y * S.art_k(&"hand")), uid + " art")
		t.eq(art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, uid + " filter")
		t.ok(int(art.size.x) % base.x == 0 and int(art.size.y) % base.y == 0, uid + " integer scale")
		# b43：真牌名在手牌和小牌（打烊清单）里都不被拦腰切掉。
		t.ok(S.title_fits(w), uid + " hand title fits")
		w.set_size_mode(&"mini")
		t.ok(S.title_fits(w), uid + " mini title fits")
		w.set_size_mode(&"hand")
		var bad: PackedStringArray = t.all_text_from_cardtext(w)
		t.ok(bad.is_empty(), uid + " text " + " ".join(bad))
		t.ok(not S.has_pct(w), uid + " pct")
		var face: CardWidget = S.find_uid(fan, uid)
		t.ok(face != null, uid + " fan face")
		if face != null:
			t.eq(face.get_uid(), uid, uid + " fan uid")
			t.eq(face.size, HAND, uid + " fan size")
			var fan_bad: PackedStringArray = t.all_text_from_cardtext(face)
			t.ok(fan_bad.is_empty(), uid + " fan text " + " ".join(fan_bad))
		rendered += 1
	t.eq(rendered, hand.size(), "every hand card rendered")
	w.queue_free()
	fan.queue_free()
	await t.frames(2)
	bus.free()
	await t.frames(1)


func _until_hand(t, engine: CardEngine) -> Dictionary:
	var view: Dictionary = engine.view()
	var hops := 0
	while _dicts(view.get("hand", [])).is_empty() and hops < 4:
		hops += 1
		var phase := str(view.get("phase", ""))
		if phase == "day":
			var ended: Dictionary = engine.send(&"day.end", {"confirm": true})
			t.ok(bool(ended.get("ok", false)), "day.end " + str(ended.get("err", "")))
			if not bool(ended.get("ok", false)):
				return view
			view = engine.view()
			phase = str(view.get("phase", ""))
		if phase == "night":
			var night: Dictionary = engine.send(&"night.choose", {"def": "", "choice": ""})
			t.ok(bool(night.get("ok", false)), "night.choose " + str(night.get("err", "")))
			if not bool(night.get("ok", false)):
				return view
			view = engine.view()
			phase = str(view.get("phase", ""))
		if phase == "settle":
			var settled: Dictionary = engine.send(&"settle.next", {})
			t.ok(bool(settled.get("ok", false)), "settle.next " + str(settled.get("err", "")))
			if not bool(settled.get("ok", false)):
				return view
			view = engine.view()
			phase = str(view.get("phase", ""))
		if phase == "morning":
			var again: Dictionary = engine.send(&"day.begin", {})
			t.ok(bool(again.get("ok", false)), "later day.begin " + str(again.get("err", "")))
			if not bool(again.get("ok", false)):
				return view
			view = engine.view()
	return view


func _dicts(v: Variant) -> Array:
	var out: Array = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for row in v:
		if typeof(row) == TYPE_DICTIONARY:
			out.append(row)
	return out


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
