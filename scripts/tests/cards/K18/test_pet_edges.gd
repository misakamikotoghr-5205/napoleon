# K18 edges: nights before the cat is kept write nothing; shoo is not a first and day.end still moves.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Pet = preload("res://scripts/cards/rules/pet.gd")
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
const ARRIVE := "ev.1938.cat_arrive"
const FIND := "ev.1938.find_cat"


func _initialize() -> void:
	var t := T.new(self, "K18_pet_edges")
	_absent(t)
	_shoo(t)
	t.finish()


func _game(t, tag: String) -> CardEngine:
	var engine := CardEngine.new()
	var started: Dictionary = engine.new_game({"seed": 7, "only_examples": false, "save_dir": t.user_dir() + "/" + tag})
	t.ok(bool(started.get("ok", false)), tag + " game")
	return engine


func _absent(t) -> void:
	var ctx := _game(t, "absent").ctx
	t.ok(not H.peek(ctx).has("pet"), "no pet key before the nights")
	var before := ctx.state.hash()
	Pet.on_night(ctx, {})
	Pet.on_night(ctx, {})
	t.eq(ctx.state.hash(), before, "two on_night calls leave state.hash unchanged")
	t.ok(not H.peek(ctx).has("pet"), "rules still have no pet key")
	t.ok(not _find_queued(ctx), "core.queue has no find card")


func _shoo(t) -> void:
	var engine := _game(t, "shoo")
	var ctx := engine.ctx
	var uid := CardPiles.spawn(ctx, ARRIVE, &"hand")
	t.ok(uid != "", "spawn arrive")
	var chosen: Dictionary = engine.send(&"card.choose", {"uid": uid, "choice": "shoo"})
	t.ok(bool(chosen.get("ok", false)), "shoo: " + str(chosen.get("err", "")))
	t.ok(not CardFirsts.all(ctx).has("pet"), "firsts have no pet")
	t.ok(not engine.view().has("pet"), "view has no pet key")
	var today := ctx.abs_day()
	var guard := 0
	while ctx.abs_day() == today and str(ctx.state.ns("loop").get("phase", "")) != "game_over" and guard < 8:
		guard += 1
		var step: Dictionary = engine.send(&"day.end", {"confirm": true})
		t.ok(bool(step.get("ok", false)), "advance day.end: " + str(step.get("err", "")))
		if not bool(step.get("ok", false)):
			break
	t.ok(ctx.abs_day() > today, "reached the next day")
	var ended: Dictionary = engine.send(&"day.end", {"confirm": true})
	t.ok(bool(ended.get("ok", false)), "next day day.end: " + str(ended.get("err", "")))


func _find_queued(ctx: CardCtx) -> bool:
	for row in ctx.state.ns("core").get("queue", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("def", "")) == FIND:
			return true
	return false
