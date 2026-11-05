# W0 骨架自测⑤：校验器——例子集在 default / strict 下全绿、ship 下“关着门”（V27）；真数据 default 全绿；
# W0 负责的每条 default“错”规则各有一个反例，会报出对应的规则号。反例写在本测试自己的 user:// 目录里。
# 合同：docs/cards/CARDS_INTERFACES.md §4.9。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

var _p := {"by": "ai", "task": "W0", "date": "2026-10-13"}


func _initialize() -> void:
	var t := T.new(self, "W0_validator")
	var ex := CardValidator.validate("res://data/cards", &"default", {"examples": true})
	t.eq(ex["errors"], PackedStringArray(), "examples: default mode has no errors")
	t.ok(int(ex["cards"]) >= 60, "examples: card count (%d)" % ex["cards"])
	# 例子集只是样本：strict 的“整局覆盖”规则（V16 可达、V17 条子档位、V18 轮盘每年的段、V19 签与测字、V29 每个机制有步骤和规矩页）不适用
	var coverage := [": V16 ", ": V17 ", ": V18 ", ": V19 ", ": V29 "]
	var strict_errs := Array(CardValidator.validate("res://data/cards", &"strict", {"examples": true})["errors"]).filter(
		func(e: String) -> bool: return coverage.all(func(c: String) -> bool: return e.find(c) < 0))
	t.eq(strict_errs, [], "examples: strict mode has no errors besides whole-game coverage (V16-V19, V29)")
	var ship: PackedStringArray = CardValidator.validate("res://data/cards", &"ship", {"examples": true})["errors"]
	t.ok(_has(ship, "V27"), "examples: ship mode fails closed (V27: no human text yet)")
	t.eq(CardValidator.validate("res://data/cards", &"default", {})["errors"], PackedStringArray(), "real data: default ok")
	var exdb := CardDB.load_all("res://data/cards", {"only_examples": true})
	t.eq(exdb.errors(), PackedStringArray(), "examples load without errors")
	for type in CardIds.TYPES:
		t.ok(not exdb.ids_of(type).is_empty(), "examples have at least one '%s' card" % type)
	# 反例
	var root := t.user_dir() + "/data"
	_copy_rules(root)
	var person := {"id": "p.linsao.1938.bad", "type": "person", "person": "linsao", "intent": "pawn", "era": ["1938"],
		"weight": 10, "brief": "x", "_provenance": _p}
	_cards(root, "era/1938/people.json", "K01", [
		_with(person, {"id": "P.Bad"}),                                                     # V02 正则
		_with(person, {"id": "ev.1938.wrong_prefix"}),                                      # V02 前缀
		_with(person, {"id": "p.linsao.1938.unknown", "colour": "red"}),                   # V03 未知字段
		_without(_with(person, {"id": "p.linsao.1938.no_intent"}), "intent"),              # V03 缺必填
		_with(person, {"id": "p.linsao.1938.text", "title": "x"}),                          # V04
		_with(person, {"id": "p.linsao.1938.cjk", "tags": ["\u597d"]}),                         # V05
		_without(_with(person, {"id": "p.linsao.1938.nobrief"}), "brief"),                 # V06
		_with(person, {"id": "p.linsao.1938.neg", "weight": -1}),                           # V07
		_with(person, {"id": "p.linsao.1938.float", "term_days": 1.5}),                     # V07
		_with(person, {"id": "p.linsao.1938.era", "era": ["1999"]}),                        # V08
		_with(person, {"id": "p.linsao.1938.op", "effects": {"on_accept": [{"op": "fly"}]}}),          # V10
		_with(person, {"id": "p.linsao.1938.shape", "effects": {"on_accept": [{"op": "rep"}]}}),       # V10
		_with(person, {"id": "p.linsao.1938.cond", "conditions": {"bogus": 1}}),                       # V10
		_with(person, {"id": "p.linsao.1938.gold", "gold": true}),                          # V13
		_with(person, {"id": "p.linsao.1938.sched", "weight": 0, "schedule": {"stage_day": 40}}),      # V28
		_with(person, {"id": "p.linsao.1938.mg", "minigame": "spot"}),                      # V33
	])
	var ev := {"id": "ev.1938.slots_bad", "type": "event", "era": ["1938"], "brief": "x", "_provenance": _p,
		"slots": [{"id": "man", "accepts": ["self"]}], "check": {"need": 13}}
	_cards(root, "era/1938/events.json", "K99", [ev,                                         # V01 主人 / V15 / V07 need
		{"id": "ev.1938.check_only", "type": "event", "era": ["1938"], "brief": "x", "_provenance": _p,
			"check": {"need": 1}},                                                           # V15 有 check 没格子
		{"id": "ev.1938.typo", "type": "eventt", "era": ["1938"], "brief": "x", "_provenance": _p}])   # V03 未知类型
	_cards(root, "demand/d.json", "K07", [{"id": "dm.1938.money.t9", "type": "demand", "era": ["1938"], "kind": "cash",
		"tier": 9, "resolve": {}, "brief": "x", "_provenance": _p}])                          # V17
	_cards(root, "common/kept.json", "K09", [{"id": "kp.bad", "type": "kept", "era": ["*"], "kind": "favor",
		"keepable": false, "brief": "x", "_provenance": _p}])                                # V14
	_cards(root, "fortune/almanac.json", "K10", [{"id": "alm.bad", "type": "almanac_day", "era": ["*"],
		"yi": ["dance"], "ji": [], "brief": "x", "_provenance": _p}])                         # V20
	_cards(root, "minigames/items.json", "K11", [{"id": "it.bad.none", "type": "item", "era": ["*"],
		"template": "jewelry.nope", "minigames": ["spot", "juggle"], "brief": "x", "_provenance": _p}])   # V22
	var step := {"id": "gd.bad", "type": "guide_step", "era": ["*"], "weight": 0, "teaches": ["deal"],
		"trigger": {"first": "deal", "cond": {"conscience_gte": 0}}, "teacher": "nobody", "anchor": "a.nope",
		"done_when": ["first:deal", "dance"], "rule_page": "rule.none", "brief": "x", "_provenance": _p}
	_cards(root, "guide/steps.json", "K16", [step])                                         # V30 V31 V32 V35
	_write(root + "/minigames/obs/weigh.json", {"_meta": {"owner": "C14", "schema": 1, "kind": "weigh"},
		"obs": {"obs.weigh.fake": {"fidelity": "clear", "brief": "x"}, "weigh.bad": {"fidelity": "loud", "brief": "x"}}})  # V23
	_write(root + "/ui_keys/K01.json", {"_meta": {"owner": "K01", "schema": 1}, "keys": {"k02.wrong": {"brief": "x"}}})  # V24
	_write(root + "/text/era/1938/people.text.json", {"_meta": {"owner": "A", "schema": 1},
		"p.linsao.1938.op": {"title": "x", "_provenance": "ai:2026-10-13"}, "p.nobody": {"title": "x",
		"_provenance": "human:A:2026-10-13"}})                                                 # V26
	var deal: Dictionary = CardDB.read_json(root + "/rules/deal.json")
	deal.erase("caps")
	_write(root + "/rules/deal.json", deal)                                                  # V25
	_write(root + "/rules/balance_overrides.json", {"_meta": {"owner": "G06", "schema": 1},
		"slots": {"no_such_key": 1}})                                                         # V25
	var res := CardValidator.validate(root, &"default", {})
	var errs: PackedStringArray = res["errors"]
	var expect := [
		["P.Bad", "V02"], ["ev.1938.wrong_prefix", "V02"], ["p.linsao.1938.unknown", "V03"],
		["p.linsao.1938.no_intent", "V03"], ["p.linsao.1938.text", "V04"], ["p.linsao.1938.cjk", "V05"],
		["p.linsao.1938.nobrief", "V06"], ["p.linsao.1938.neg", "V07"], ["p.linsao.1938.float", "V07"],
		["p.linsao.1938.era", "V08"], ["p.linsao.1938.op", "V10"], ["p.linsao.1938.shape", "V10"],
		["p.linsao.1938.cond", "V10"], ["p.linsao.1938.gold", "V13"], ["p.linsao.1938.sched", "V28"],
		["p.linsao.1938.mg", "V33"], ["era/1938/events.json: -", "V01"], ["ev.1938.slots_bad", "V15"],
		["ev.1938.slots_bad", "V07"], ["ev.1938.check_only", "V15"], ["ev.1938.typo", "V03"],
		["dm.1938.money.t9", "V17"], ["kp.bad", "V14"], ["alm.bad", "V20"], ["it.bad.none", "V22"],
		["gd.bad", "V30"], ["gd.bad", "V31"], ["gd.bad", "V32"], ["gd.bad", "V35"], ["obs.weigh.fake", "V23"],
		["weigh.bad", "V23"], ["k02.wrong", "V24"], ["p.linsao.1938.op", "V26"], ["p.nobody", "V26"],
		["rules/deal.json", "V25"], ["rules/balance_overrides.json", "V25"]]
	for e in expect:
		t.ok(_has_both(errs, str(e[0]), str(e[1])), "expected %s for %s" % [e[1], e[0]])
	t.ok(_has(CardValidator.validate(root, &"default", {"only": PackedStringArray(["data/cards/demand/d.json"])})["errors"],
		"V17") and not _has(CardValidator.validate(root, &"default", {"only": PackedStringArray(["data/cards/demand/d.json"])})[
		"errors"], "V13"), "--only limits reported files")
	# 形状函数
	t.eq(CardDslShapes.check_effect({"op": "rep", "delta": 3}), "", "rep delta ok")
	t.ok(CardDslShapes.check_effect({"op": "rep", "delta": 3, "tier": 1}) != "", "rep with both delta and tier")
	t.eq(CardDslShapes.check_effect({"op": "if", "cond": {"flag": "x"}, "then": [{"op": "heat", "tier": 1}]}), "", "nested if")
	t.ok(CardDslShapes.check_effect({"op": "if", "cond": {"flag": 1}, "then": []}) != "", "bad nested cond")
	t.eq(CardDslShapes.check_cond({"all": [{"day_gte": 3}, {"not": {"flag": "a"}}]}), "", "all/not")
	t.eq(str(CardDslShapes.shape(&"weather", true).call("rain")), "", "cond shape for weather")
	t.eq(str(CardDslShapes.shape(&"weather").call({"op": "weather", "value": "rain"})), "", "effect shape for weather")
	t.finish()


func _with(base: Dictionary, over: Dictionary) -> Dictionary:
	var d := base.duplicate(true)
	d.merge(over, true)
	return d


func _without(base: Dictionary, key: String) -> Dictionary:
	var d := base.duplicate(true)
	d.erase(key)
	return d


func _cards(root: String, rel: String, owner: String, cards: Array) -> void:
	_write(root + "/" + rel, {"_meta": {"owner": owner, "schema": 1}, "cards": cards})


func _write(path: String, d: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "  "))
	f.close()


func _copy_rules(root: String) -> void:
	for f in CardDB.list_json("res://data/cards/rules"):
		_write(root + "/rules/" + f.get_file(), CardDB.read_json(f))


func _has(errs: PackedStringArray, rule: String) -> bool:
	for e in errs:
		if e.contains(" " + rule + " "):
			return true
	return false


func _has_both(errs: PackedStringArray, what: String, rule: String) -> bool:
	for e in errs:
		if e.contains(what) and e.contains(" " + rule + " "):
			return true
	return false
