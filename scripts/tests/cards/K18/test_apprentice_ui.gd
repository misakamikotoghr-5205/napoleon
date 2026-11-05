# K18: apprentice tint on the contact mini, and the guide step can light.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const STEP := "gd.apprentice"


func _initialize() -> void:
	var t := T.new(self, "K18_apprentice_ui")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var e := CardEngine.new(bus)
	t.ok(bool(e.new_game({"seed": 3, "stage": 1, "save_dir": t.user_dir() + "/ui"}).get("ok", false)), "new game")
	var bar := CardHeroBar.new()
	root.add_child(bar)
	await t.frames(1)
	bar.refresh(_view(false))
	var plain := bar.get_node_or_null("Contact0")
	t.ok(plain != null, "contact mini exists")
	t.eq((plain as CanvasItem).modulate, Color.WHITE, "plain contact stays white")
	bar.refresh(_view(true))
	var tinted := bar.get_node_or_null("Contact0") as CanvasItem
	var jade := CardTheme.color(&"jade")
	t.ok(tinted != null, "apprentice mini exists")
	t.ok(absf(tinted.modulate.r - jade.r) < 0.01 and absf(tinted.modulate.g - jade.g) < 0.01, "jade tint")
	t.ok(absf(tinted.modulate.a - 1.0) < 0.01, "full alpha at the counter")
	var away: Dictionary = _view(true)
	away["contacts"][0]["away_days"] = 2
	bar.refresh(away)
	var dim := bar.get_node_or_null("Contact0") as CanvasItem
	t.ok(absf(dim.modulate.a - 0.42) < 0.01, "away keeps the dim alpha")
	t.ok(absf(dim.modulate.r - jade.r) < 0.01 and absf(dim.modulate.g - jade.g) < 0.01 and absf(dim.modulate.b - jade.b) < 0.01, "away keeps jade")
	# 真 HeroBar 已登记 a.contacts；同 bus 绑指引
	t.ok(t.anchor_ok(&"a.contacts"), "HeroBar registers a.contacts")
	await _guide(t, e, bus, bar)
	t.finish()


func _guide(t, e: CardEngine, bus: CardEventBus, bar: CardHeroBar) -> void:
	var guide := CardGuide.new()
	guide.skip_fades = true
	root.add_child(guide)
	guide.bind(e, bus)
	guide.force(true)
	var raw = CardDB.read_json("res://data/cards/guide/steps.json")
	t.ok(typeof(raw) == TYPE_DICTIONARY, "steps.json loads")
	var step: Dictionary = {}
	for row in (raw as Dictionary).get("cards", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("id", "")) == STEP:
			step = row
			break
	t.ok(not step.is_empty(), "formal gd.apprentice in steps.json")
	t.eq(str(step.get("anchor", "")), "a.contacts", "formal anchor a.contacts")
	guide.load_steps(e.query(&"guide_data"))
	# 真实推进到第 11 天：day.begin 发 ask → deal_composed → first（同 bus）
	var loop := e.ctx.state.ns("loop")
	loop["stage_day"] = 11
	loop["abs_day"] = 11
	loop["phase"] = "morning"
	t.ok(CardSchedule.due(e.ctx, 11).has("p.tudi.1939.ask"), "schedule lists ask on day 11")
	t.ok(bool(e.send(&"day.begin", {}).get("ok", false)), "day.begin day 11")
	var ask := ""
	for uid in CardPiles.list(e.ctx, &"hand"):
		if str(CardPiles.card(e.ctx, uid).get("def", "")) == "p.tudi.1939.ask":
			ask = str(uid)
			break
	t.ok(ask != "", "ask dealt by day.begin")
	t.ok(CardFirsts.all(e.ctx).has("apprentice"), "engine first from deal_composed")
	await t.frames(2)
	guide.evaluate_now()
	t.eq(guide.active_step(), STEP, "formal guide step lights on HeroBar a.contacts")
	t.ok(bool(e.send(&"card.choose", {"uid": ask, "choice": "take"}).get("ok", false)), "take under guide")
	guide.evaluate_now()
	await t.frames(3)
	guide.evaluate_now()
	t.ok(guide.active_step() != STEP, "gd.apprentice left after take got=" + guide.active_step())
	var prog: Dictionary = e.query(&"guide_progress").get("progress", {})
	var grow: Dictionary = prog.get(STEP, {})
	t.eq(str(grow.get("status", "")), "done", "gd.apprentice progress status=done")
	t.ok(CardFirsts.all(e.ctx).has("apprentice"), "first still marked after guide")
	t.ok(not CardFirsts.mark(e.ctx, &"apprentice", {}), "no re-teach same session")
	# 存读不重教：经公开 day.end 链进到可存 morning
	var path: String = t.user_dir() + "/ui/mid.json"
	var guard := 0
	while str(e.view().get("phase", "")) not in ["morning", "month_open"] and guard < 12:
		guard += 1
		var ph := str(e.view().get("phase", ""))
		match ph:
			"day":
				e.send(&"day.end", {"confirm": true})
			"night":
				e.send(&"night.choose", {"def": ""})
			"settle":
				e.send(&"settle.next", {})
			_:
				e.send(&"day.end", {"confirm": true})
	var saved: Dictionary = e.send(&"game.save", {"path": path})
	t.ok(bool(saved.get("ok", false)), "save after guide in " + str(e.view().get("phase", "")) + ": " + str(saved.get("err", "")))
	var bus2 := CardEventBus.new()
	root.add_child(bus2)
	var spy = t.spy(bus2)
	var loaded := CardEngine.new(bus2)
	t.ok(bool(loaded.load_game(path).get("ok", false)), "load after guide")
	t.ok(CardFirsts.all(loaded.ctx).has("apprentice"), "first survives load")
	var g2 := CardGuide.new()
	g2.skip_fades = true
	root.add_child(g2)
	g2.bind(loaded, bus2)
	g2.force(true)
	g2.load_steps(loaded.query(&"guide_data"))
	await t.frames(1)
	g2.evaluate_now()
	t.ok(g2.active_step() != STEP, "loaded guide does not re-teach gd.apprentice got=" + g2.active_step())
	var firsts := 0
	for row in spy.log:
		if row[0] == &"first_time" and str(row[1]) == "apprentice":
			firsts += 1
	t.eq(firsts, 0, "load does not re-fire apprentice first")
	var prog2: Dictionary = loaded.query(&"guide_progress").get("progress", {})
	t.eq(str(prog2.get(STEP, {}).get("status", "")), "done", "loaded gd.apprentice stays done")
	g2.queue_free()
	bus2.queue_free()
	guide.queue_free()


func _view(apprentice: bool) -> Dictionary:
	return {
		"self": {"uid": "self", "attrs": {"eye": 1, "tongue": 1, "pull": 1, "nerve": 1}, "used_today": false},
		"contacts": [{
			"uid": "c1", "def": "ct.tudi", "type": "contact", "zone": "contacts", "person": "tudi",
			"apprentice": apprentice, "away_days": 0, "art": "portrait.ex_shopboy",
			"attrs": {"eye": 1, "tongue": 1, "pull": 1, "nerve": 1},
		}],
	}
