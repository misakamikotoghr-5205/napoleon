# 指引数据有序、条件只给布尔、ui 指令无事件无日志且不改状态哈希。
# 主人 G01；合同 §7.10.6。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_guide_queries")
	var bus := CardEventBus.new()
	var e := CardEngine.new(bus)
	t.ok(e.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir()})["ok"], "new")
	var spy := t.spy(bus)
	var hash := e.ctx.state.hash()
	var log := e.command_log()
	t.ok(e.send(&"ui.guide", {"step": "gd.d1.deal", "status": "shown"})["ok"], "shown")
	t.ok(e.send(&"ui.guide", {"step": "gd.d1.deal", "status": "done"})["ok"], "done")
	t.eq(spy.log, [], "ui emits nothing")
	t.eq(e.command_log(), log, "ui outside log")
	t.eq(e.ctx.state.hash(), hash, "ui outside hash")
	var data := e.query(&"guide_data")
	t.eq(data["steps"][0]["id"], "gd.d1.deal", "file order preserved")
	t.ok(data.has("settings"), "guide settings")
	t.no_leaks(data, "guide query")
	for step in data["steps"]:
		t.ok(not step.has("brief") and not step.has("_provenance"), "notes stripped")
	var conds := e.query(&"guide_conds", {"ids": ["gd.d1.deal", "gd.unknown"]})
	t.eq(conds, {"gd.d1.deal": true, "gd.unknown": false}, "conditions only booleans")
	t.eq(e.query(&"guide_progress")["progress"]["gd.d1.deal"]["status"], "done", "progress query")
	bus.free()
	t.finish()
