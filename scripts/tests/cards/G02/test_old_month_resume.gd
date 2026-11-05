# 旧 W0 月初没有运势面板，恢复后仍必须转月盘；已完成状态绝不重复转。
# 使用完整 G05/G02 真实边界，仅通过 CardSave 构造旧格式快照。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Real = preload("res://scripts/tests/cards/G02/real_firsts.gd")

func _initialize() -> void:
	var t := T.new(self, "G02_old_month_resume")
	var bus := CardEventBus.new()
	var e := CardEngine.new(bus)
	var spy = t.spy(bus)
	t.ok(bool(e.new_game({"seed": 7, "data_root": Real._data(t), "save_dir": t.user_dir()}).get("ok")), "real new month")
	var old := CardState.from_dict(e.ctx.state.to_dict())
	old.ns("loop").erase("_v")
	old.ns("loop")["open_panel"] = {"kind": "", "args": {}}
	old.ns("loop")["extension"] = 7
	var path: String = t.user_dir() + "/old_month.json"
	t.ok(bool(CardSave.write(path, old, {}).get("ok")), "old monthly snapshot")
	spy.clear()
	t.ok(bool(e.load_game(path).get("ok")), "old monthly snapshot loads")
	t.eq(e.view()["open_panel"], {"kind": "wheel", "args": {"wheel": "wh.month", "uid": "", "required": true}}, "required month panel reconstructed")
	t.eq(e.ctx.state.ns("loop")["extension"], 7, "unknown loop fields preserved")
	t.eq(spy.count(&"request_panel"), 1, "reconstructed panel emitted once")
	t.eq(spy.count(&"first_time"), 0, "existing monthly first not repeated")
	t.eq(e.send(&"month.begin").get("err"), "wheel_pending", "old month cannot bypass fortune")
	t.ok(bool(e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""}).get("ok")), "reconstructed wheel can spin")
	var chosen := str(e.view()["notice"]["fortune"])
	t.ok(chosen != "", "monthly fortune completed")
	# A completed save with no panel must remain byte-for-byte identical after loading.
	CardDayLoop.request_panel(e.ctx, &"", {})
	var completed := CardState.from_dict(e.ctx.state.to_dict())
	var completed_hash := completed.hash()
	CardSave.write(path, completed, {})
	spy.clear()
	e.load_game(path)
	t.eq(e.state_hash(), completed_hash, "completed fortune state unchanged")
	t.eq(e.view()["open_panel"]["kind"], "", "completed month does not reopen wheel")
	t.eq(spy.count(&"request_panel"), 0, "completed month emits no panel reconstruction")
	t.eq(e.view()["notice"]["fortune"], chosen, "completed segment unchanged")
	t.ok(not bool(e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""}).get("ok")), "completed month cannot spin again")
	# Partial legacy metadata may lose month_segment while preserving the completed wheel result.
	completed.ns("fate")["month_segment"] = ""
	CardSave.write(path, completed, {})
	e.load_game(path)
	var spin_before: Dictionary = e.ctx.state.ns("fate").get("wheels", {}).get("wh.month:", {}).get("result", {}).duplicate(true)
	t.eq(e.query(&"day.end_preview")["items"], [], "completed wheel result prevents automatic respin without segment marker")
	t.ok(bool(e.send(&"day.end", {"confirm": true}).get("ok")), "completed old month continues via generic next day")
	t.eq(e.ctx.state.ns("fate").get("wheels", {}).get("wh.month:", {}).get("result", {}), spin_before, "old completed wheel result stays unchanged")
	var morning_hash := e.state_hash()
	var morning: String = t.user_dir() + "/morning_manual.json"
	e.save_game(morning)
	spy.clear()
	e.load_game(morning)
	t.eq(e.state_hash(), morning_hash, "morning restore unchanged")
	t.eq(spy.count(&"request_panel"), 0, "repair only applies to month-open")
	bus.free()
	t.finish()
