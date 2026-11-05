# 各核心 first-time 恰好一次、白名单事件、存读保留和发牌顺序。
# 主人 G01；合同 §7.10.6。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_firsts")
	var c := H.ctx()
	var before := c.state.hash()
	t.ok(CardFirsts.mark(c, &"deal", {"uid": "c1", "weight": 5}), "first true")
	t.ok(c.state.hash() != before, "first enters hash")
	t.eq(c.out[0][2], {"uid": "c1"}, "hidden args removed")
	t.ok(not CardFirsts.mark(c, &"deal"), "second false")
	c.state = CardState.from_dict(JSON.parse_string(JSON.stringify(c.state.to_dict())))
	t.ok(not CardFirsts.mark(c, &"deal"), "saved first not repeated")
	c = H.ctx()
	CardComposer.compose(c)
	var names: Array = []
	for event in c.out:
		if event[0] == &"first_time":
			names.append(str(event[1]))
			t.no_leaks(event[2], "first args")
	t.eq(names[0], "deal", "deal before person")
	t.ok(names.has("person"), "person marked")
	CardPiles.spawn(c, "lf.any.coal_out", &"hand")
	CardPiles.spawn(c, "nw.1938.wangshan_dock", &"hand")
	CardPiles.spawn(c, "kp.ma_owes", &"hand")
	for i in range(5):
		var uid := CardPiles.spawn(c, "kp.ma_owes", &"hand")
		CardPiles.keep(c, uid)
	var overflow := CardPiles.spawn(c, "kp.ma_owes", &"hand")
	CardPiles.keep(c, overflow)
	c.state.ns("loop")["abs_day"] = 25
	CardPiles.settle_kept(c)
	for mech in ["deal", "person", "life", "news", "keep", "kept_full", "kept_expire"]:
		t.ok(CardFirsts.all(c).has(mech), "marked " + mech)
		var count := 0
		for event in c.out:
			if event[0] == &"first_time" and str(event[1]) == mech:
				count += 1
		t.eq(count, 1, "one first " + mech)
	c.state = CardState.from_dict(JSON.parse_string(JSON.stringify(c.state.to_dict())))
	c.out.clear()
	for mech in ["deal", "person", "life", "news", "keep", "kept_full", "kept_expire"]:
		t.ok(not CardFirsts.mark(c, StringName(mech)), "saved first never replays " + mech)
	t.eq(c.out, [], "restored firsts emit no events")
	t.finish()
