# 发牌的确定性、未来日、钉签名额、队列、去重、软上限和牢房矩阵。
# 主人 G01；合同 §7.4.6、§12.2。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_composer")
	for seed in range(50):
		var c := H.ctx(seed)
		var other := H.ctx(seed)
		var hash := c.state.hash()
		var predicted := CardComposer.project(c, 5)
		t.eq(c.state.hash(), hash, "projection read only")
		var dealt := CardComposer.compose(c)
		t.eq(H.defs(c, dealt), predicted, "prediction equals compose")
		t.eq(H.defs(other, CardComposer.compose(other)), predicted, "same seed same draws")
		t.eq(c.state.hash(), other.state.hash(), "same seed same hash")
		t.eq(t.find_floats(c.state.data), PackedStringArray(), "integer state")
	var c := H.ctx()
	c.state.ns("loop")["abs_day"] = 1
	c.state.ns("loop")["stage_day"] = 1
	t.eq(CardComposer.project(c, 3), PackedStringArray(), "future tutorial day draws nothing")
	t.ok(not CardComposer.project(c, 5).is_empty(), "future day outside tutorial draws")
	c.mods.register(&"pinned_cards", func(_c, _a): return ["ev.1938.police_check"] , "TEST")
	var pinned := H.defs(c, CardComposer.compose(c))
	t.ok(pinned.has("ev.1938.police_check"), "pins survive zero scripted budget")
	c = H.ctx()
	c.state.ns("loop")["mode"] = "street"
	c.mods.register(&"pinned_cards", func(_c, _a): return ["p.linsao.1938.pawn_hairpin"], "TEST")
	var street := H.defs(c, CardComposer.compose(c))
	t.ok(street.has("p.linsao.1938.pawn_hairpin"), "pins survive street budget")
	c = H.ctx()
	c.mods.register(&"deal_count", func(_c, a): return -999 if str(a.get("type")) == "person" else 0, "TEST")
	var closed := H.defs(c, CardComposer.compose(c))
	for id in closed:
		t.ok(str(c.db.def(id).get("type")) != "person", "closure blocks random person")
	c = H.ctx()
	CardPiles.spawn(c, "pr.cell", &"hand")
	for id in H.defs(c, CardComposer.compose(c)):
		t.ok(str(c.db.def(id).get("type")) != "person", "prison blocks random person")
	c = H.ctx()
	var first := CardComposer.extra_deal(c, &"person", 1)
	c.state = CardState.from_dict(JSON.parse_string(JSON.stringify(c.state.to_dict())))
	var next := CardComposer.extra_deal(c, &"person", 1)
	t.ok(first.size() == 1 and next.size() == 1, "two extras available")
	t.ok(H.defs(c, first)[0] != H.defs(c, next)[0], "saved draw avoids repeated definition")
	c.state.ns("core")["queue"].append({"def": "kp.ma_owes", "zone": "kept", "abs_day": 5})
	CardComposer.compose(c)
	t.eq(CardPiles.list(c, &"kept").size(), 1, "queued non-hand card delivered")
	t.eq(c.state.ns("core")["queue"], [], "queue consumed")
	c = H.ctx()
	c.mods.register(&"pool_rows", func(_c, _a): return [["ev.1938.police_check", 0]], "TEST")
	t.eq(CardComposer.project(c, 5), PackedStringArray(), "zero weight safe")
	# 无固定牌时软上限阻止新增随机牌；显式日程牌仍发。
	c = H.ctx()
	for i in range(10):
		CardPiles.spawn(c, "kp.ma_owes", &"hand")
	t.eq(CardComposer.project(c, 5), PackedStringArray(), "soft cap stops random cards")
	c.mods.register(&"scheduled_cards", func(_c, _a): return ["ev.1938.police_check"], "TEST")
	t.ok(H.defs(c, CardComposer.compose(c)).has("ev.1938.police_check"), "scheduled bypasses soft cap")
	# 软上限只限随机部分：钉签和队列里的牌在满手时也照发，随机部分一张不加（合同 §7.4.6）。
	c = H.ctx()
	for i in range(10):
		CardPiles.spawn(c, "kp.ma_owes", &"hand")
	c.mods.register(&"pinned_cards", func(_c, _a): return ["ev.1938.police_check"], "TEST")
	c.state.ns("core")["queue"] = [{"def": "p.linsao.1938.pawn_hairpin", "zone": "hand", "abs_day": 5}]
	var capped := H.defs(c, CardComposer.compose(c))
	capped.sort()
	t.eq(capped, PackedStringArray(["ev.1938.police_check", "p.linsao.1938.pawn_hairpin"]), "soft cap keeps pins and queue, drops only random")
	var root := t.user_dir() + "/pin_cards"
	H.copy_tree("res://data/cards", root)
	var doc: Dictionary = CardDB.read_json(root + "/_examples/era/1938/events.json")
	doc["cards"][0]["conditions"] = {"flag": "never"}
	var replacement: Dictionary = doc["cards"][0].duplicate(true)
	replacement["id"] = "ev.1938.substitute"
	replacement["conditions"] = {}
	doc["cards"].append(replacement)
	H.write(root + "/_examples/era/1938/events.json", doc)
	c = H.ctx(7, root)
	c.mods.register(&"pinned_cards", func(_c, _a): return ["ev.1938.police_check"], "TEST")
	t.ok(H.defs(c, CardComposer.compose(c)).has("ev.1938.substitute"), "ineligible pin takes same-omen substitute")
	doc["cards"].pop_back()
	H.write(root + "/_examples/era/1938/events.json", doc)
	c = H.ctx(7, root)
	c.mods.register(&"pinned_cards", func(_c, _a): return ["ev.1938.police_check"], "TEST")
	t.ok(H.defs(c, CardComposer.compose(c)).has("ev.1938.police_check"), "missing substitute deals the original pin")
	# 未来预测的条件和日程读取尚未发牌的早晨，而不是来源白天阶段。
	c = H.ctx()
	c.mods.register(&"pool_rows", func(pc, args):
		return [["ev.1938.police_check", 10]] if str(pc.state.ns("loop").get("phase")) == "morning" and str(args.get("pool")) == "event" else [], "TEST")
	var source_hash := c.state.hash()
	var future := CardComposer.project(c, 6)
	t.eq(future, PackedStringArray(["ev.1938.police_check"]), "future pool sees morning")
	t.eq(c.state.hash(), source_hash, "future phase projection leaves source unchanged")
	t.eq(c.state.ns("loop")["phase"], "day", "source stays day")
	c.state.ns("loop")["abs_day"] = 6
	c.state.ns("loop")["stage_day"] = 6
	c.state.ns("loop")["phase"] = "morning"
	t.eq(H.defs(c, CardComposer.compose(c)), future, "forecast equals actual future morning")
	c = H.ctx()
	c.mods.register(&"pool_rows", func(_pc, args):
		return [["ev.1938.police_check", 10]] if str(args.get("pool")) == "event" else [], "TEST")
	c.mods.register(&"scheduled_cards", func(pc, _args):
		return ["ev.1938.police_check"] if str(pc.state.ns("loop").get("phase")) == "morning" else [], "TEST")
	t.eq(CardComposer.project(c, 6), PackedStringArray(), "future scheduled card consumes random candidate")
	c.state.ns("loop")["abs_day"] = 6
	c.state.ns("loop")["stage_day"] = 6
	c.state.ns("loop")["phase"] = "morning"
	t.eq(H.defs(c, CardComposer.compose(c)), PackedStringArray(["ev.1938.police_check"]), "future morning delivers scheduled card exactly once")
	# 每个牌库都消费同一个带 abs_day 的修正项；负数不会留下负名额或掷空权重表。
	c = H.ctx()
	var count_args: Array = []
	c.mods.register(&"deal_count", func(_pc, args):
		count_args.append(args.duplicate())
		return -999, "TEST")
	t.eq(CardComposer.project(c, 5), PackedStringArray(), "all shop counts clamp zero")
	t.eq(CardComposer.night_offers(c), PackedStringArray(), "prison modifier suppresses night offers")
	t.eq(CardComposer.street_deal(c), PackedStringArray(), "prison modifier suppresses street helper")
	c.state.ns("loop")["mode"] = "street"
	t.eq(CardComposer.compose(c), PackedStringArray(), "prison modifier suppresses street compose")
	for args in count_args:
		t.eq(args.get("abs_day"), 5, "all count providers receive day")
	for pool in ["person", "event", "news", "fate", "night", "street"]:
		t.ok(count_args.any(func(args): return str(args.get("type")) == pool), "count queried for " + pool)
	t.finish()
