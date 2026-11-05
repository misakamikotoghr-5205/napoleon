# 真门面与CLI缓存逐项等价；验证事件期间busy、外部改快照、存读和指标。
# G06；合同1.2 §7.2、§12.4；测试不读ctx，不依赖墙钟。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario := preload("res://scripts/tests/cards/G06/scenario.gd")
const CachedAPI := preload("res://scripts/cards/sim/cached_api.gd")
const Telemetry := preload("res://scripts/cards/sim/telemetry.gd")
const Fair := preload("res://scripts/cards/sim/policies/fair.gd")


class TraceAPI extends CardEngineApi:
	var delegate: CardEngineApi
	var trace: Array = []

	func _init(target: CardEngineApi) -> void:
		delegate = target
		bus = target.bus
	func new_game(opts: Dictionary) -> Dictionary:
		return _record("new_game", opts, delegate.new_game(opts))
	func load_game(path: String) -> Dictionary:
		return _record("load_game", path, delegate.load_game(path))
	func save_game(path: String) -> Dictionary:
		return _record("save_game", path, delegate.save_game(path))
	func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
		return _record(str(cmd), args, delegate.send(cmd, args))
	func view() -> Dictionary:
		return _record("view", {}, delegate.view())
	func query(q: StringName, args: Dictionary = {}) -> Dictionary:
		return _record("query:" + str(q), args, delegate.query(q, args))
	func is_busy() -> bool:
		return delegate.is_busy()
	func state_hash() -> String:
		var hash_value: String = str(delegate.call("state_hash"))
		trace.append(JSON.stringify(["state_hash", hash_value], "", true).sha256_text())
		return hash_value
	func command_log() -> Array:
		return delegate.call("command_log")
	func _record(method: String, args: Variant, result: Dictionary) -> Dictionary:
		trace.append(JSON.stringify([method, args, result], "", true).sha256_text())
		return result


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_cached_api")
	var data_root: String = Scenario.build(t.user_dir() + "/data")
	var raw: Dictionary = _run(t, false, data_root)
	var cached: Dictionary = _run(t, true, data_root)
	t.eq(cached["trace"], raw["trace"], "every public response equals uncached facade")
	t.eq(cached["events"], raw["events"], "event payload and order preserved")
	t.eq(cached["result"], raw["result"], "same commands yield same raw opaque state hash")
	t.eq(cached["log"], raw["log"], "command history including rejects preserved")
	t.eq(cached["telemetry"], raw["telemetry"], "all public metrics and checkpoints preserved")
	t.finish()


func _run(t: RefCounted, use_cache: bool, data_root: String) -> Dictionary:
	var bus_node: CardEventBus = CardEventBus.new()
	var delegate: CardEngineApi = CardEngine.new(bus_node)
	var traced: TraceAPI = TraceAPI.new(CachedAPI.new(delegate) if use_cache else delegate)
	t.ok(traced.bus == delegate.bus, "bus is passed through")
	var spy: RefCounted = t.spy(bus_node)
	var observer: RefCounted = Telemetry.new()
	observer.attach(traced, CardDB.load_all(data_root, {"only_examples": true}))
	bus_node.command_done.connect(func(_cmd: StringName, _args: Dictionary, _ok: bool) -> void:
		t.ok(traced.is_busy(), "busy stays true during command callbacks")
		t.ok(traced.view().get("busy", false), "cached view refreshes callback busy")
		traced.query(&"firsts", {}))
	traced.view()
	var opts: Dictionary = {"seed": 1, "only_examples": true, "data_root": data_root, "save_dir": t.user_dir() + "/save"}
	t.ok(traced.new_game(opts).get("ok", false), "new game invalidates cached boot")
	var snapshot: Dictionary = traced.view()
	var changed: Dictionary = traced.view()
	changed["date"]["stage"] = 99
	changed["self"]["attrs"]["eye"] = 99
	t.eq(traced.view(), snapshot, "caller mutation never affects future snapshots")
	t.ok(traced.save_game(t.user_dir() + "/snapshot.json").get("ok", false), "save through facade")
	t.ok(traced.load_game(t.user_dir() + "/snapshot.json").get("ok", false), "load invalidates prior view")
	traced.send(&"card.keep", {"uid": "missing.uid"})
	traced.send(&"day.begin", {})
	var result: Dictionary = CardAutoplay.play(traced, Fair.new(1), {"stages": 3, "max_steps": 20000})
	t.ok(result.get("ok", false) and int(result.get("days", 0)) == 90, "true three-stage run")
	t.ok(not traced.view().get("busy", true), "busy returns false after send")
	var row: Dictionary = {"result": result, "trace": traced.trace.duplicate(), "events": spy.log.duplicate(true),
		"log": CardReplay.record(traced), "telemetry": {"stages": observer.stages, "hashes": observer.hashes}}
	bus_node.free()
	return row
