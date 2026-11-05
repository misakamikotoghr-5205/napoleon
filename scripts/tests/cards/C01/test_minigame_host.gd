# C01 小游戏宿主：mg.request → 实例化 → autoplay → mg.report；Esc → aborted。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")
const RESULT_KEYS: Array[String] = ["aborted", "measures", "minutes", "observations", "quality_permille"]


func _initialize() -> void:
	var t := T.new(self, "C01_minigame_host")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, "day_counter")
	await t.frames(2)
	var mock: MockCardEngine = game.engine
	mock.send(&"mg.request", {"uid": "c0002", "item": "I001"})
	await t.frames(1)
	t.ok(game.mg_host.is_active(), "minigame is up")
	game.mg_host.autoplay_current(0.8)
	await t.frames(2)
	var report := _last_report(mock)
	t.ok(not report.is_empty(), "mg.report sent")
	t.eq(str(report.get("uid", "")), "c0002", "report uid")
	t.eq(str(report.get("item", "")), "I001", "report item")
	_result_shape(t, report.get("result", {}), false)
	mock.send(&"mg.request", {"uid": "c0002", "item": "I001"})
	await t.frames(1)
	t.ok(game.mg_host.is_active(), "minigame reopened")
	S.press(game, KEY_ESCAPE)
	await t.frames(2)
	report = _last_report(mock)
	_result_shape(t, report.get("result", {}), true)
	t.ok(not game.mg_host.is_active(), "abort clears the minigame")
	game.queue_free()
	bus.queue_free()
	await t.frames(1)


func _last_report(mock: MockCardEngine) -> Dictionary:
	for i in range(mock.sent.size() - 1, -1, -1):
		if str(mock.sent[i][0]) == "mg.report":
			return mock.sent[i][1]
	return {}


func _result_shape(t, result: Dictionary, aborted: bool) -> void:
	var keys: Array[String] = []
	for k in result.keys():
		keys.append(str(k))
	keys.sort()
	t.eq(keys, RESULT_KEYS, "result keys")
	t.eq(bool(result.get("aborted", false)), aborted, "aborted flag")
