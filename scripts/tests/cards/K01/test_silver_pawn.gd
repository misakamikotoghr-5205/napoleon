# K01: silver-yuan pawn guest is in the dealer pool and opens coin_ring.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const ID := "p.stranger_coindealer.any.pawn_silver"


func _initialize() -> void:
	var t := T.new(self, "K01_silver_pawn")
	var db := CardDB.load_all("res://data/cards", {})
	t.eq(db.errors(), PackedStringArray(), "CardDB load errors")
	var card: Dictionary = db.def(ID)
	t.ok(not card.is_empty(), "def loads")
	t.eq(str(card.get("type", "")), "person", "type")
	t.eq(str(card.get("intent", "")), "pawn", "intent")
	t.eq(str(card.get("item", {}).get("template", "")), "silver.yuan_a", "template")
	t.eq(str(card.get("minigame_hint", "")), "coin_ring", "minigame hint")
	t.eq(int(card.get("weight", 0)), 7, "weight")
	t.ok(db.pool(&"person", "1938").has(ID), "person pool 1938")
	t.ok(_in_deal_rows(db, "1938"), "dealer rows 1938")
	t.ok(_in_deal_rows(db, "1939"), "dealer rows 1939")
	t.ok(_in_deal_rows(db, "1940"), "dealer rows 1940")
	_kind(t)
	t.finish()


func _in_deal_rows(db: CardDB, era: String) -> bool:
	for row in db.deal_rows(&"person", era):
		if str(row[0]) == ID and int(row[1]) > 0:
			return true
	return false


func _kind(t) -> void:
	var engine := CardEngine.new()
	var started: Dictionary = engine.new_game({"seed": 7, "save_dir": t.user_dir()})
	t.ok(bool(started.get("ok", false)), "new game")
	if not bool(started.get("ok", false)):
		return
	var uid := CardPiles.spawn(engine.ctx, ID, &"hand")
	t.ok(uid != "", "spawn guest")
	var opened: Dictionary = CardCounter.open(engine.ctx, uid)
	t.ok(bool(opened.get("ok", false)), "counter open")
	var econ: Dictionary = engine.ctx.state.ns("econ")
	var sessions: Dictionary = econ.get("sessions", {})
	var session: Dictionary = sessions.get(uid, {})
	var item_id: String = str(session.get("item", ""))
	var metas: Dictionary = econ.get("items_meta", {})
	var meta: Dictionary = metas.get(item_id, {})
	t.eq(str(meta.get("template", "")), "silver.yuan_a", "generated template")
	var req: Dictionary = CardAppraisal.request(engine.ctx, uid, item_id)
	t.eq(bool(req.get("ok", false)), true, "mg.request ok")
	t.eq(str(req.get("kind", "")), "coin_ring", "mg kind")
	var params: Dictionary = req.get("params", {})
	t.eq(str(params.get("kind", "")), "coin_ring", "params kind")
	t.ok(params.has("coins"), "coin_ring params")
