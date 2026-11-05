# 真引擎总线观察报告包含全部平衡指标，未观察到的比率不伪造。
# G06；合同 §12.6、规则覆盖只动已有键。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")
const Fair := preload("res://scripts/cards/sim/policies/fair.gd")
const METRICS: Array[String] = ["stage", "cleared", "game_over_reasons", "money_samples", "rep_tiers", "heat_tiers",
	"demands", "mortgaged", "street", "prison", "big_fate", "fate", "hand_counts", "slot_checks",
	"lot_accuracy", "almanac", "steps"]


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_report_schema")
	var bus: CardEventBus = CardEventBus.new()
	var engine: CardEngineApi = CardEngine.new(bus)
	var db: CardDB = CardDB.load_all("res://data/cards", {"only_examples": true})
	var telemetry: RefCounted = Telemetry.new()
	telemetry.attach(engine, db)
	t.ok(engine.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir()}).get("ok", false), "new game")
	CardAutoplay.play(engine, Fair.new(7), {"days": 3, "max_steps": 3000})
	for stage in telemetry.stages.values():
		for key in METRICS:
			t.ok(stage.has(key), "metric present " + key)
	var path: String = t.user_dir() + "/report.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "stages": telemetry.stages}))
	file = null
	t.ok(CardDB.read_json(path) != null, "report roundtrip")
	var overrides: Dictionary = CardState.int_restore(CardDB.read_json("res://data/cards/rules/balance_overrides.json"))
	for key in overrides.keys():
		if not str(key).begins_with("_"):
			_check_override(t, db.rules(str(key)), overrides[key], str(key))
	bus.free()
	_real_demand(t)
	t.finish()


func _check_override(t: RefCounted, base: Dictionary, over: Dictionary, prefix: String) -> void:
	for key in over.keys():
		t.ok(base.has(key), "existing key " + prefix + "." + str(key))
		if typeof(over[key]) == TYPE_DICTIONARY:
			_check_override(t, base.get(key, {}), over[key], prefix + "." + str(key))
		else:
			t.ok(typeof(over[key]) == TYPE_INT, "numeric override only")


func _real_demand(t: RefCounted) -> void:
	var bus: CardEventBus = CardEventBus.new()
	var engine: CardEngineApi = CardEngine.new(bus)
	var observer: RefCounted = Telemetry.new()
	observer.attach(engine, CardDB.load_all("res://data/cards", {"only_examples": false}))
	t.ok(engine.new_game({"seed": 7, "only_examples": false,
		"save_dir": t.user_dir() + "/real"}).get("ok", false), "real content new game")
	var refuser: CardPolicy = preload("res://scripts/cards/sim/policies/refuser.gd").new(7)
	CardAutoplay.play(engine, refuser, {"days": 8, "max_steps": 100})
	engine.send(&"day.begin", {})
	var demands: Array = engine.view().get("demands", [])
	t.ok(not demands.is_empty(), "real first weekly demand present")
	if not demands.is_empty():
		var uid: String = str(demands[0]["uid"])
		t.ok(engine.send(&"demand.delay", {"uid": uid}).get("ok", false), "real demand delayed")
		var detail: Dictionary = engine.query(&"card", {"uid": uid})
		var card: Dictionary = detail.get("card", detail)
		var key: String = str(card["demand"]["kind"]) + ":" + str(card["demand"]["tier"])
		t.eq(observer.stages["0"]["demands"].get(key, {}).get("delayed", 0), 1,
			"delay telemetry follows public nested kind and updated tier")
		t.ok(not observer.stages["0"]["demands"].has("unknown:0"), "no fabricated unknown tier")
	bus.free()
