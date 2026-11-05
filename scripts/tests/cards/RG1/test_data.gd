# RG1_data: the relic definitions the module runs on (res://data/cards/era/common/relics.json once RG3 has merged it,
# the RG1 fixture until then) against ROGUE_V1.md §5.4 / §6.2: every mods row is a known mod with all parameters
# and nothing else, pct an integer 1-400, "when" a valid condition using only the cheap whitelisted ops, passives /
# downsides only on day_start / settle with well-formed effects, a known depth, art under prop.relic.; and
# rules/relics.json (when present) has sane clamps. Also proves relic_mods.check_row rejects bad rows. Owner RG1.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Ids = preload("res://scripts/cards/relic/relic_ids.gd")
const Mods = preload("res://scripts/cards/relic/relic_mods.gd")

const REAL := "res://data/cards/era/common/relics.json"
const FIXTURE := "res://scripts/tests/cards/RG1/fixtures/relics.json"
const REAL_RULES := "res://data/cards/rules/relics.json"
const FIXTURE_RULES := "res://scripts/tests/cards/RG1/fixtures/rules_relics.json"
## ROGUE_V1.md §5.4, written out again here so the module's own table is checked against the spec.
const SPEC_ROWS := {
	"price_pct": ["direction", "pct", "cats?"], "patience_pct": ["pct"], "appraise_pct": ["pct", "cats?"],
	"shelf_cap": ["delta"], "kept_cap": ["delta"], "deal_count": ["type", "delta"],
	"pool_weight": ["pool", "pct", "tags_any?", "intents?"], "coins": ["source_kind", "delta", "slot_tags_any?"],
}
const SPEC_WHEN := ["all", "any", "not", "flag", "has_contact", "weather", "market_day", "almanac_yi", "estate_status",
	"stage_gte", "weekday", "heat_tier_gte", "rep_tier_gte"]


func _initialize() -> void:
	var t := T.new(self, "RG1_data")
	_spec_tables(t)
	_checker(t)
	var path := REAL if FileAccess.file_exists(REAL) else FIXTURE
	var doc = CardDB.read_json(path)
	t.ok(typeof(doc) == TYPE_DICTIONARY and typeof(doc.get("cards")) == TYPE_ARRAY, "%s parses" % path)
	var cards: Array = doc.get("cards", []) if typeof(doc) == TYPE_DICTIONARY else []
	t.ok(not cards.is_empty(), "%s has relics" % path)
	for d in cards:
		_relic(t, d)
	var rules_path := REAL_RULES if FileAccess.file_exists(REAL_RULES) else FIXTURE_RULES
	_rules(t, CardDB.read_json(rules_path), rules_path)
	t.finish()


func _spec_tables(t) -> void:
	var keys: Array = Ids.MOD_ROWS.keys()
	keys.sort()
	var spec_keys: Array = SPEC_ROWS.keys()
	spec_keys.sort()
	t.eq(keys, spec_keys, "module row table = s5.4 mods")
	for mod in spec_keys:
		var params: Array = []
		for p in Ids.MOD_ROWS.get(mod, {}).keys():
			params.append(str(p) + ("?" if str(Ids.MOD_ROWS[mod][p]).ends_with("?") else ""))
		params.sort()
		var want: Array = SPEC_ROWS[mod].duplicate()
		want.sort()
		t.eq(params, want, "%s parameters" % mod)
	t.eq(Array(Ids.WHEN_OPS), SPEC_WHEN, "when whitelist = s5.4")
	t.eq(Array(Ids.PASSIVE_HOOKS), ["day_start", "settle"], "passive hooks = day_start, settle")
	for op in SPEC_WHEN:
		t.ok(CardDslShapes.COND_OPS.has(StringName(op)), "whitelisted op %s exists" % op)


func _checker(t) -> void:
	var good := {"mod": "price_pct", "direction": "pay", "pct": 96, "when": {"almanac_yi": "pawn_in"}}
	t.eq(Mods.check_row(good), "", "a good row passes")
	var bad := [
		{"mod": "price_pct", "pct": 96},
		{"mod": "price_pct", "direction": "lend", "pct": 96},
		{"mod": "patience_pct", "pct": 0},
		{"mod": "patience_pct", "pct": 401},
		{"mod": "patience_pct", "pct": 1.5},
		{"mod": "patience_pct", "pct": 90, "cats": ["art"]},
		{"mod": "kept_cap", "delta": "1"},
		{"mod": "deal_count", "type": "fate", "delta": 1},
		{"mod": "pool_weight", "pool": "person", "pct": 90, "tags_any": []},
		{"mod": "coins", "source_kind": "anyone", "delta": 1},
		{"mod": "luck", "pct": 120},
		{"mod": "patience_pct", "pct": 90, "when": {"money_gte": 10}},
		{"mod": "patience_pct", "pct": 90, "when": {"not": {"no_such_op": 1}}},
		{"mod": "patience_pct", "pct": 90, "flaw": "yes"},
		"patience_pct",
	]
	for row in bad:
		t.ok(Mods.check_row(row) != "", "bad row rejected: %s" % JSON.stringify(row))
	var def := {"id": "rl.test", "type": "relic", "depth": "plain", "art": "prop.relic.test", "mods": [],
		"passives": [{"hook": "deal", "effects": [{"op": "rep", "delta": 1}]}],
		"downsides": [{"hook": "settle", "effects": [{"op": "no_such_op"}]}]}
	t.eq(Mods.check_def(def).size(), 2, "passive on a v1-forbidden hook and a bad effect are both reported")
	def["depth"] = "legendary"
	def["art"] = "relic.test"
	t.eq(Mods.check_def(def).size(), 4, "bad depth and bad art reported too")


func _relic(t, d) -> void:
	t.ok(typeof(d) == TYPE_DICTIONARY, "card row is an object")
	if typeof(d) != TYPE_DICTIONARY:
		return
	var id := str(d.get("id", ""))
	t.eq(Mods.check_def(d), PackedStringArray(), "%s passes the module check" % id)
	t.ok(Ids.DEPTHS.has(str(d.get("depth", ""))), "%s depth %s" % [id, d.get("depth")])
	t.ok(str(d.get("art", "")).begins_with("prop.relic."), "%s art %s" % [id, d.get("art")])
	for row in d.get("mods", []):
		_row(t, id, row)
	for field in ["passives", "downsides"]:
		for row in d.get(field, []):
			t.ok(str(row.get("hook", "")) in ["day_start", "settle"], "%s %s hook %s" % [id, field, row.get("hook")])
			t.eq(CardDslShapes.check_effects(row.get("effects", [])), PackedStringArray(), "%s %s effects" % [id, field])


## Independent of relic_mods.gd: the §5.4 table read straight off SPEC_ROWS.
func _row(t, id: String, row) -> void:
	var mod := str(row.get("mod", ""))
	t.ok(SPEC_ROWS.has(mod), "%s: mod %s is in the s5.4 table" % [id, mod])
	var allowed := ["mod", "when", "flaw"]
	for p in SPEC_ROWS.get(mod, []):
		var name := str(p).trim_suffix("?")
		allowed.append(name)
		if not str(p).ends_with("?"):
			t.ok(row.has(name), "%s: %s has %s" % [id, mod, name])
	var keys: Array = row.keys()
	keys.sort()
	for k in keys:
		t.ok(str(k) in allowed, "%s: %s key %s allowed" % [id, mod, k])
	if row.has("pct"):
		t.ok(typeof(row["pct"]) == TYPE_INT and int(row["pct"]) >= 1 and int(row["pct"]) <= 400, "%s: %s pct 1-400" % [id, mod])
	if row.has("delta"):
		t.ok(typeof(row["delta"]) == TYPE_INT, "%s: %s delta is an integer" % [id, mod])
	if row.has("when"):
		t.eq(CardDslShapes.check_cond(row["when"]), "", "%s: %s when is a valid condition" % [id, mod])
		for op in CardDslShapes.cond_ops_used(row["when"]):
			t.ok(op in SPEC_WHEN, "%s: %s when uses only whitelisted ops (%s)" % [id, mod, op])


func _rules(t, rules, path: String) -> void:
	t.ok(typeof(rules) == TYPE_DICTIONARY, "%s parses" % path)
	if typeof(rules) != TYPE_DICTIONARY:
		return
	t.ok(typeof(rules.get("cap", 6)) == TYPE_INT and int(rules.get("cap", 6)) >= 1, "cap is a positive integer")
	var bounds: Dictionary = rules.get("clamp", {})
	var names: Array = bounds.keys()
	names.sort()
	for key in names:
		t.ok(Ids.CLAMP_DEFAULTS.has(key), "clamp key %s is one the module reads" % key)
		t.ok(typeof(bounds[key]) == TYPE_INT, "clamp %s is an integer" % key)
	var defaults: Array = Ids.CLAMP_DEFAULTS.keys()
	defaults.sort()
	for key in defaults:
		if str(key).ends_with("_min"):
			var top := str(key).trim_suffix("_min") + "_max"
			var lo := int(bounds.get(key, Ids.CLAMP_DEFAULTS[key]))
			var hi := int(bounds.get(top, Ids.CLAMP_DEFAULTS[top]))
			t.ok(lo <= hi, "%s <= %s" % [key, top])
			var neutral := 0 if str(key) in ["shelf_cap_min", "kept_cap_min", "deal_count_min", "coins_min"] else 100
			t.ok(lo <= neutral and neutral <= hi, "%s range holds the neutral value" % str(key).trim_suffix("_min"))
