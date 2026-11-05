extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G03/test_support.gd")
func _initialize() -> void:
	var t := T.new(self, "G03_conds")
	var e := S.engine()
	var ctx := e.ctx
	S.fragment(ctx, "df.one", "test")
	S.card(ctx, "dp.test", {"type": "dossier_page", "person": "test", "fragments": ["df.one"]}, &"discard")
	ctx.run([{"op": "flag", "key": "f", "value": "yes"}, {"op": "counter", "key": "n", "delta": 2}, {"op": "story", "node": "s", "outcome": "met"}, {"op": "contact_gain", "person": "ma"}, {"op": "dossier", "frag": "df.one"}], "test")
	CardPiles.spawn(ctx, "kp.ma_owes", &"kept")
	CardPiles.spawn(ctx, "dm.1938.money.t1", &"demands")
	var cases := {"all": [{"flag": "f"}, {"counter_gte": ["n", 2]}], "any": [{"flag": "missing"}, {"flag": "f"}], "not": {"flag": "missing"}, "flag": "f", "flag_eq": ["f", "yes"], "counter_gte": ["n", 2], "story": ["s", "met"], "rep_tier_gte": 0, "rep_tier_lte": 0, "heat_tier_gte": 0, "heat_tier_lte": 0, "conscience_gte": 0, "conscience_lte": 0, "attr_gte": ["ruhua", "eye", 2], "has_contact": "ma", "has_kept": {"def": "kp.ma_owes", "tags_any": ["favor"]}, "person_state": ["ma", "ok"], "dossier_has": "df.one", "dossier_page_complete": "test", "demand_open": "money"}
	var keys := cases.keys()
	keys.sort()
	for op in keys:
		var cond := {op: cases[op]}
		t.ok(ctx.test(cond), "condition positive " + str(op))
		t.eq(ctx.conds.validate(cond), "", "valid condition " + str(op))
		t.ok(ctx.conds.validate({op: null}) != "", "invalid shape " + str(op))
	t.ok(not ctx.test({"all": [{"flag": "f"}, {"flag": "missing"}]}), "all short circuit")
	t.ok(not ctx.test({"any": []}), "empty any false")
	t.ok(not ctx.test({"has_kept": {"tags_any": ["missing"]}}), "kept tags mismatch")
	t.ok(not ctx.test({"demand_open": "people"}), "demand kind mismatch")
	var hash := ctx.state.hash()
	for op in keys: ctx.test({op: cases[op]})
	t.eq(ctx.state.hash(), hash, "conditions are read only")
	t.finish()
