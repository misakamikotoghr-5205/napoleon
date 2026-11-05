# C10：gd.news、gd.dossier、gd.dossier_gap、gd.year_after、gd.d2.rules 会亮并完成。四个锚点有面积。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C10/support.gd")
const FX := "res://scripts/tests/cards/C10/fixtures/guide_play.json"
const STEPS := "res://scripts/tests/cards/C10/guide_steps.json"

func _initialize() -> void:
	var t := T.new(self, "C10_guide")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	S.leaks_fixture(t, FX)
	var steps = CardDB.read_json(STEPS)
	t.no_leaks(steps, "guide steps")
	await _fallback(t, steps)
	await _main(t, steps)


func _fallback(t, steps: Dictionary) -> void:
	var data = CardDB.read_json(FX).duplicate(true)
	data["view"]["phase"] = "day"
	data["view"]["date"]["stage_day"] = 6
	data["view"]["hand"] = []
	var path: String = t.user_dir() + "/news_fallback.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var only := {"settings": steps["settings"], "pages": [], "steps": []}
	for s in steps["steps"]:
		if str(s.get("id", "")) == "gd.news":
			only["steps"].append(s)
	var game := _boot(path)
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps(only)
	await t.frames(4)
	t.ok(CardAnchors.has(&"a.hand"), "hand anchor exists")
	t.ok(not CardAnchors.has(&"a.card@missing"), "missing card has no anchor")
	game.bus.first_time.emit(&"news", {"uid": "missing"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.news", "news step uses the hand fallback")
	game.bus.ui_event.emit(&"hand_selected", {"uid": "missing"})
	t.eq(game.guide.active_step(), "", "fallback news completes")
	_drop(game)
	await t.frames(2)
	CardAnchors.clear()


func _main(t, steps: Dictionary) -> void:
	var game := _boot(FX)
	game.guide.force(true)
	game.guide.skip_fades = true
	game.guide.load_steps(steps)
	await t.frames(4)
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.d2.rules", "day-2 rules step")
	t.ok(t.anchor_ok(&"a.tab.rules"), "rules anchor is the rules tab")
	game.host.open_panel(&"help", {})
	await t.frames(1)
	t.eq(game.guide.active_step(), "", "opening help completes gd.d2.rules")
	t.ok(t.anchor_ok(&"a.help.rules"), "a.help.rules")
	game.host.close_top()
	await t.frames(1)
	var advanced: Dictionary = game.engine.send(&"day.begin", {})
	t.ok(bool(advanced.get("ok", false)), "move to day 6")
	await t.frames(2)
	t.ok(CardAnchors.has(&"a.card@c0010"), "news card anchor")
	t.ok(CardAnchors.has(&"a.hand"), "hand still anchored")
	game.bus.first_time.emit(&"news", {"uid": "c0010"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.news", "news step lights on the card")
	game.bus.ui_event.emit(&"hand_selected", {"uid": "c0010"})
	t.eq(game.guide.active_step(), "", "news step completes")
	game.bus.first_time.emit(&"dossier", {"person": "brother"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.dossier", "first fragment points at the dossier button")
	game.host.open_panel(&"dossier", {})
	await t.frames(2)
	t.eq(game.guide.active_step(), "", "opening the book completes gd.dossier")
	t.ok(t.anchor_ok(&"a.dossier.page"), "a.dossier.page")
	t.ok(t.anchor_ok(&"a.dossier.gap"), "a.dossier.gap")
	t.ok(t.anchor_ok(&"a.dossier.rules_tab"), "a.dossier.rules_tab")
	game.bus.first_time.emit(&"dossier_gap", {"person": "brother"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.dossier_gap", "gap step")
	game.guide.tick(4.0)
	t.eq(game.guide.active_step(), "", "gap step completes")
	var book := game.host.top_panel()
	(S.find_meta(book, &"c10_person", "linsao") as Button).pressed.emit()
	await t.frames(1)
	t.ok(not CardAnchors.has(&"a.year.after"), "year-jump page is not open")
	t.ok(t.anchor_ok(&"a.dossier.page"), "year-after fallback is the dossier page")
	game.bus.first_time.emit(&"year_after", {"person": "linsao"})
	game.guide.evaluate_now()
	t.eq(game.guide.active_step(), "gd.year_after", "year-after lights on the dossier page")
	game.guide.tick(4.0)
	t.eq(game.guide.active_step(), "", "year-after completes")
	(S.find_meta(book, &"c10_person", "brother") as Button).pressed.emit()
	game.host.open_panel(&"help", {})
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.dossier.page"), "page anchor inside the screen")
	t.ok(t.anchor_ok(&"a.dossier.gap"), "gap anchor inside the screen")
	t.ok(t.anchor_ok(&"a.dossier.rules_tab"), "rules tab inside the screen")
	t.ok(t.anchor_ok(&"a.help.rules"), "help rules tab inside the screen")
	var got: Array = []
	for id in game.guide.shown_log:
		got.append(str(id))
	t.eq(got, ["gd.d2.rules", "gd.news", "gd.dossier", "gd.dossier_gap", "gd.year_after"], "five steps in order")
	_drop(game)
	await t.frames(2)


func _boot(fixture: String) -> CardGameRoot:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": fixture, "skip_title": true, "guide": "off"})
	root.add_child(game)
	return game


func _drop(game: CardGameRoot) -> void:
	var bus := game.bus
	game.queue_free()
	if bus != null:
		bus.queue_free()
