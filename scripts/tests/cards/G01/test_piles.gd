# 牌堆期限、回调、排序、溢出与重复结算边界。
# 主人 G01；合同 §7.4.2、§10.2。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_piles")
	var c := H.ctx()
	var seen: Array = []
	c.ops.register(&"rep", func(_c, eff, _s): seen.append(eff.get("delta")), CardDslShapes.shape(&"rep"), "TEST")
	c.ops.register(&"heat", func(_c, eff, _s): seen.append(eff.get("delta")), CardDslShapes.shape(&"heat"), "TEST")
	var kept := CardPiles.spawn(c, "kp.ma_owes", &"hand")
	t.eq(CardPiles.keep(c, kept), "", "keep")
	t.eq(CardPiles.keep(c, kept), CardIds.ERR_BAD_ARGS, "cannot keep twice")
	c.state.ns("loop")["abs_day"] = 25
	CardPiles.settle_kept(c)
	t.eq(CardPiles.zone_of(c, kept), &"discard", "expiry settles")
	t.ok(CardFirsts.all(c).has("kept_expire"), "expiry first")
	var before := c.out.size()
	CardPiles.expire(c, kept)
	t.eq(c.out.size(), before, "expire idempotent")
	var resolved := CardPiles.spawn(c, "kp.ma_owes", &"hand")
	CardPiles.resolve(c, resolved, &"resolved", {"almanac": ["meet"]})
	before = c.out.size()
	CardPiles.resolve(c, resolved, &"resolved")
	t.eq(c.out.size(), before, "resolve idempotent")
	var life := CardPiles.spawn(c, "lf.any.coal_out", &"hand")
	var due := int(CardPiles.card(c, life).get("vars", {}).get("due_abs_day", -1))
	c.state.ns("loop")["abs_day"] = due - 1
	CardPiles.end_day(c)
	t.eq(CardPiles.zone_of(c, life), &"hand", "life before due carries")
	c.state.ns("loop")["abs_day"] = due
	# Fixture effects need money/heat ops; local no-op providers record execution without unrelated module behavior.
	c.ops.register(&"attr", func(_c, _e, _s): seen.append("attr"), CardDslShapes.shape(&"attr"), "TEST")
	c.ops.register(&"pay", func(_c, _e, _s): seen.append("pay"), CardDslShapes.shape(&"pay"), "TEST")
	CardPiles.end_day(c)
	t.eq(CardPiles.zone_of(c, life), &"discard", "life due expires")
	for id in ["p.linsao.1938.pawn_hairpin", "ev.1938.police_check", "pr.cell", "p.brother.1938.farewell"]:
		CardPiles.spawn(c, id, &"hand")
	var defs := H.defs(c, CardPiles.list(c, &"hand"))
	t.eq(defs[0], "p.brother.1938.farewell", "gold first")
	t.eq(defs[1], "pr.cell", "prison second")
	t.eq(defs[2], "ev.1938.police_check", "event before person")
	t.eq(CardPiles.cap(c, &"discard"), -1, "uncapped zone")
	c.mods.register(&"cap", func(_c, _a): return -999, "TEST")
	t.eq(CardPiles.cap(c, &"kept"), 0, "negative cap clamps to zero")
	t.eq(t.find_floats(c.state.data), PackedStringArray(), "integer expiry state")
	t.finish()
