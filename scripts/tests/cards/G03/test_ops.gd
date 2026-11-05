extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G03/test_support.gd")
func _initialize() -> void:
	var t := T.new(self, "G03_ops")
	var e := S.engine()
	var ctx := e.ctx
	S.fragment(ctx, "df.test.one", "test")
	S.fragment(ctx, "df.test.two", "test")
	var ops: Array = [
		{"op": "rep", "delta": 15}, {"op": "heat", "tier": 1}, {"op": "conscience", "delta": -3},
		{"op": "attr", "who": "ruhua", "attr": "eye", "delta": 1, "days": 2},
		{"op": "flag", "key": "set"}, {"op": "flag_clear", "key": "set"}, {"op": "counter", "key": "n", "delta": 2},
		{"op": "story", "node": "test", "outcome": "met"}, {"op": "dossier", "frag": "df.test.one"},
		{"op": "dossier_gap", "frag": "df.test.two"}, {"op": "notice", "key": "g03.demand.done"},
		{"op": "if", "cond": {"counter_gte": ["n", 2]}, "then": [{"op": "flag", "key": "branch"}]},
		{"op": "coin_check", "coins": 0, "need": 0, "then": [{"op": "flag", "key": "coin"}]},
		{"op": "person_state", "person": "ma", "state": "hurt", "days": 2},
		{"op": "contact_gain", "person": "ma"}, {"op": "contact_lose", "person": "ma"},
		{"op": "demand_tier", "delta": -1}, {"op": "kept_risk", "tags_any": ["contraband"]}]
	var kept := CardPiles.spawn(ctx, "kp.mystery_box", &"kept")
	for eff in ops:
		t.eq(ctx.ops.validate(eff), "", "shape valid " + str(eff["op"]))
		t.ok(ctx.ops.validate({"op": eff["op"], "bad": 1}) != "", "shape invalid " + str(eff["op"]))
		ctx.run([eff], "c.test/ops")
	t.eq(CardMeters.tier(ctx, &"rep"), 1, "rep effect")
	t.eq(CardMeters.tier(ctx, &"heat"), 1, "heat tier effect")
	t.eq(CardMeters.value(ctx, &"conscience"), -3, "conscience effect")
	t.eq(CardMeters.attr(ctx, "ruhua", &"eye"), 3, "attr effect")
	t.ok(not ctx.test({"flag": "set"}), "flag cleared")
	t.ok(ctx.test({"story": ["test", "met"]}) and ctx.test({"flag_eq": ["story.test", "met"]}), "story flag")
	t.ok(ctx.test({"flag": "branch"}) and ctx.test({"flag": "coin"}), "nested branches")
	t.ok(CardDossier.has_fragment(ctx, "df.test.one"), "dossier add")
	t.eq(ctx.state.ns("rules")["dossier"]["test"]["gaps"], ["df.test.two"], "gap effect")
	t.ok(ctx.test({"person_state": ["ma", "hurt"]}), "person effect")
	t.ok(not ctx.test({"has_contact": "ma"}), "contact lose effect")
	t.eq(ctx.state.ns("rules")["demand"]["tier_bias"], -1, "demand bias")
	t.eq(ctx.state.ns("rules")["test_effects"][0]["op"], "arrest", "kept risk")
	t.ok(CardPiles.zone_of(ctx, kept) == &"kept", "risk keeps card")
	ctx.run([{"op": "heat", "delta": 100}], "c.test/heat")
	t.eq(ctx.state.ns("rules")["test_effects"].size(), 2, "heat immediate arrest")
	t.no_leaks(ctx.out, "effect events")
	t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "no floats")
	_test_contact_overflow(t)
	t.finish()

func _test_contact_overflow(t) -> void:
	var e := S.engine()
	var ctx := e.ctx
	ctx.db._rules["deal"]["caps"]["contacts"] = 1
	S.card(ctx, "ct.test", {"type": "contact", "person": "test", "attrs": {"eye": 1}}, &"discard")
	CardEffectsCore.gain_contact(ctx, "ma")
	CardEffectsCore.gain_contact(ctx, "test")
	var first := CardPiles.list(ctx, &"contacts")[0]
	var pending := CardPiles.list(ctx, &"pending")[0]
	t.eq(ctx.state.ns("loop")["open_panel"]["kind"], "contacts_full", "contact overflow panel")
	t.ok(CardEffectsCore.release_contact(ctx, first)["ok"], "release old contact")
	t.eq(CardPiles.zone_of(ctx, pending), &"contacts", "pending contact promoted")
	CardEffectsCore.gain_contact(ctx, "test")
	t.eq(CardPiles.list(ctx, &"contacts").size(), 1, "contact gain duplicate ignored")
