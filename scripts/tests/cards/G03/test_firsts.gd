extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G03/test_support.gd")
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
func _initialize() -> void:
	var t := T.new(self, "G03_firsts")
	var e := S.engine()
	var ctx := e.ctx
	ctx.state.ns("loop").merge({"stage_day": 2, "abs_day": 2}, true)
	var choice := S.card(ctx, "ev.first_choice", {"type": "event", "choices": [{"id": "yes", "effects": []}]})
	ctx.hooks.fire(ctx, &"deal_composed", {"uids": [choice]})
	t.eq(CardFirsts.all(ctx).get("choice"), 2, "day two choice first")
	ctx.state.ns("loop").merge({"stage_day": 3, "abs_day": 3}, true)
	var slots := S.event(ctx)
	ctx.hooks.fire(ctx, &"deal_composed", {"uids": [slots]})
	t.eq(CardFirsts.all(ctx).get("slots"), 3, "day three slots first")
	t.eq(CardFirsts.all(ctx).get("coins"), 3, "day three coins first")
	S.fragment(ctx, "df.first", "test")
	S.fragment(ctx, "df.gap", "test")
	S.fragment(ctx, "df.after", "test", "year_after", "df.first", ["1939"])
	CardDossier.add(ctx, "df.first")
	CardDossier.gap(ctx, "df.gap")
	CardMeters.add(ctx, &"rep", 20, "test")
	CardMeters.add(ctx, &"heat", 20, "test")
	ctx.db._rules["deal"]["caps"]["contacts"] = 0
	CardEffectsCore.gain_contact(ctx, "ma")
	CardEffectsCore.set_person(ctx, "ma", "hurt", 2)
	CardPiles.spawn(ctx, "kp.mystery_box", &"kept")
	H.kept_first(ctx)
	ctx.state.ns("loop").merge({"stage": 1, "stage_day": 1}, true)
	CardDossier.year_after(ctx)
	ctx.state.ns("loop").merge({"stage": 0, "stage_day": 7, "abs_day": 7}, true)
	ctx.db._by_type["demand"] = ["dm.1938.info.t3"]
	var demand := CardDemands.issue(ctx)
	ctx.state.ns("loop")["abs_day"] = 13
	CardDemands.on_settle(ctx)
	CardEffectsCore.set_person(ctx, "ruhua", "away", 1)
	H.person_row(ctx, "ruhua")["demand_return"] = {"attr": "nerve", "need": 0}
	ctx.state.ns("loop")["abs_day"] = 14
	CardDemands.return_people(ctx)
	var names := ["choice", "slots", "coins", "demand", "demand_delay", "demand_people_return", "demand_inform", "demand_fabricate", "demand_fail", "dossier", "dossier_gap", "year_after", "contact", "contacts_full", "tier_rep", "tier_heat", "person_state", "kept_risk"]
	for name in names:
		t.ok(CardFirsts.all(ctx).has(name), "first exists " + name)
		var count := 0
		for row in ctx.out:
			if row[0] == &"first_time" and str(row[1]) == name:
				count += 1
				for key in row[2].keys(): t.ok(str(key) in ["uid", "def", "kind", "person", "no"], "first args whitelist")
		t.eq(count, 1, "first once " + name)
	var clone := S.clone(e)
	clone.ctx.out = []
	for name in names: t.ok(not CardFirsts.mark(clone.ctx, StringName(name), {}), "save prevents repeated first")
	t.eq(clone.ctx.out, [], "no repeated first events")
	t.ok(demand != "", "info demand issued")
	t.finish()
