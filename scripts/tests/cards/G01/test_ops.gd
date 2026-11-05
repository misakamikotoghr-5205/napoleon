# 核心 op 正例、形状反例和延迟非手牌队列。
# 主人 G01；合同 §5.2。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_ops")
	var c := H.ctx()
	var e := H.install(c)
	c.run([{"op": "add_card", "card": "kp.ma_owes", "to": "kept", "in_days": 2}], "TEST")
	t.eq(c.state.ns("core")["queue"][0]["abs_day"], 7, "delayed kept queued")
	c.state.ns("loop")["abs_day"] = 7
	c.state.ns("loop")["stage_day"] = 7
	CardComposer.compose(c)
	t.eq(CardPiles.list(c, &"kept").size(), 1, "queued kept moved")
	c.run([{"op": "remove_card", "match": {"def": "kp.ma_owes"}, "from": "kept", "n": 1}], "TEST")
	t.eq(CardPiles.list(c, &"kept").size(), 0, "remove")
	var life := CardPiles.spawn(c, "lf.any.coal_out", &"hand")
	c.run([{"op": "waive", "match": {"type": "life"}, "n": 1}], "TEST")
	t.eq(CardPiles.zone_of(c, life), &"discard", "waive")
	c.run([{"op": "extra_deal", "type": "event", "n": 1, "day": "tomorrow"}], "TEST")
	t.eq(c.state.ns("core")["queue"][0]["pool"], "event", "extra tomorrow")
	for invalid in [{"op": "add_card", "card": "kp.ma_owes", "to": "bogus"}, {"op": "remove_card", "match": {}, "n": "bad"}, {"op": "waive", "n": "bad"}, {"op": "extra_deal", "n": "bad", "day": "today"}]:
		t.ok(c.ops.validate(invalid) != "", "shape rejects invalid")
	t.eq(t.find_floats(c.state.data), PackedStringArray(), "integer op state")
	e = null
	t.finish()
