# G04 鉴定改版（主创 10-25：要玩家看出来才算数）测试的共用夹具：真数据的经济上下文、按真假挑物品、造结果。
# 只驱动 G04 自己的接口；其他线的钩子不装（同 economy_test_support）。
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")
const TestEngine = preload("res://scripts/tests/cards/G04/economy_engine.gd")
const S = preload("res://scripts/tests/cards/G04/economy_test_support.gd")

## Economy context over the real card set (items.json specs, codebook, news) plus the G04 fixture cards.
static func real_ctx(seed: int = 7) -> CardCtx:
	var eng := TestEngine.new()
	var c := eng.ctx
	c.state = CardState.create(seed, {})
	c.state.ns("loop").merge({"phase": "day", "abs_day": 1, "stage": 0, "mode": "shop"})
	c.db = CardDB.load_all(CardDB.DEFAULT_ROOT, {})
	var fixture: Dictionary = CardDB.read_json("res://scripts/tests/cards/G04/fixture.json")
	for row in CardState.int_restore(fixture)["cards"]:
		if c.db._cards.has(row["id"]):
			continue
		c.db._cards[row["id"]] = row
		c.db._file_of[row["id"]] = "test"
		if not c.db._by_type.has(row["type"]):
			c.db._by_type[row["type"]] = []
		if not c.db._by_type[row["type"]].has(row["id"]):
			c.db._by_type[row["type"]].append(row["id"])
	CardCurrency.apply_stage(c, c.db.stage(0))
	# Real documents carry other lines' effects (story, dossier, flag, notice); they are no-ops here.
	var known := c.ops.known()
	for op in CardDslShapes.EFFECT_OPS.keys():
		if not known.has(str(op)):
			c.ops.register(op, _noop, CardDslShapes.shape(op), "test")
	c.out.clear()
	return c

static func _noop(_ctx: CardCtx, _eff: Dictionary, _source: String) -> void:
	pass

## Generates items of this template until `n` with the wanted truth exist; returns their ids.
static func items_of(c: CardCtx, template: String, fake: bool, n: int, tag: String = "pick") -> Array:
	var out: Array = []
	var k := 0
	while out.size() < n and k < n * 80:
		var r := CardItems.generate(c, ["c", 1, tag, template, k], template)
		k += 1
		if not bool(r.get("ok", false)):
			continue
		var id := str(r["item"])
		if bool(E.meta(c, id).get("fake", false)) == fake:
			out.append(id)
	return out

## A finished, non-aborted result with these claims and measures.
static func result(observations: Array, measures: Dictionary, quality: int = 1000, minutes: int = 1) -> Dictionary:
	return {"quality_permille": quality, "observations": observations, "minutes": minutes, "measures": measures, "aborted": false}

## A pawn customer (fixture p.test.pawn: hairpin, spot) already at the counter, with the item id.
static func pawn_with(c: CardCtx, def_id: String = "p.test.pawn") -> Array:
	var uid := S.spawn(c, def_id)
	CardCounter.open(c, uid)
	return [uid, str(E.session(c, uid)["item"])]

## Forces the private truth of an item (the spot layout is rebuilt from it on the next request).
static func set_truth(c: CardCtx, item: String, fake: bool, stolen: bool = false) -> void:
	var m := E.meta(c, item)
	m["fake"] = fake
	m["stolen"] = stolen

## Pin measures that name every mark of a spot answer with the given tags ("right" = its own kind).
static func spot_pins(answer: Dictionary, how: String) -> Array:
	var pins: Array = []
	for mk in answer.get("marks", []):
		var cx := int(mk[2]) + int(mk[4]) / 2
		var cy := int(mk[3]) + int(mk[5]) / 2
		var tag := 2 if str(mk[1]) == "differs" else 1
		if how == "differs":
			tag = 2
		elif how == "wrong":
			tag = 1 if tag == 2 else 2
		pins.append([cx, cy, tag])
	return pins

## Recursively: does any dictionary key in v equal one of keys?
static func has_key(v, keys: Array) -> bool:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			if keys.has(str(k)) or has_key(v[k], keys):
				return true
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			if has_key(x, keys):
				return true
	return false
