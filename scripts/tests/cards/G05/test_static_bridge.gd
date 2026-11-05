# G05 跨模块静态桥接的 Godot 运行验证。
# 测试 Script.has_method/call 与 W0 缺少方法时的无害分支。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const F = preload("res://scripts/tests/cards/G05/fixture.gd")
func _initialize() -> void:
	var t := T.new(self, "G05_static_bridge")
	var script: Script = F
	t.ok(script.has_method("db"), "static method visible through Script")
	var db: CardDB = script.call("db")
	t.ok(db.has("wh.month"), "static method callable through Script")
	t.ok(not script.has_method("not_implemented_bridge"), "missing W0 method rejected safely")
	t.finish()
