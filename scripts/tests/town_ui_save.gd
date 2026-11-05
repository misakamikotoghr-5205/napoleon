# 小镇界面（d）：睡觉 → 夜里 → 日结 → 第二天早上自动存档 → 重新读档，日期、钱、账本一致。
# godot --headless -s res://scripts/tests/town_ui_save.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
var SAVE: String = TownGame.scratch_save_path("ui_save")      # 带进程号

var c

func _initialize() -> void:
	_run()

func _run() -> void:
	c = Common.new(self)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	await c.make_main()
	var town = c.town
	town.set_fast(true)
	town.auto_dismiss = true
	town.autosave = true
	town.save_path = SAVE
	town.director_ready.connect(c._on_director)
	town.new_game(21, "常年", true)
	await town.day_started
	await c.until_idle()
	c.check(FileAccess.file_exists(SAVE), "新的一天开始时自动存了档")
	c.check(town.world.day == 1, "第 1 天")
	town.seconds_per_minute = 100000.0
	# 白天睡不得：提示一句，日子不变
	town.sleep()
	await c.frames(3)
	c.check(town.world.day == 1 and town.mode == "town", "18:00 以前睡觉被拒绝")
	town.skip_to(1100)
	await town.goto("bed")
	var d1_cash: int = town.world.cash()
	town.sleep()
	c.check(town.mode == "night" or town.mode == "town", "开始过夜")
	await town.day_finished
	await town.day_started
	await c.until_idle()
	c.check(town.world.day == 2, "睡一觉，第 2 天（%d）" % town.world.day)
	c.check(not town.last_summary.is_empty() and int(town.last_summary.get("day", 0)) == 1, "有第 1 天的日结")
	c.check(town.minute == 360 and town.map_id == "pawnshop", "新的一天 6:00，在当铺里醒来")
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	var saved: Dictionary = {"day": town.world.day, "cash": town.world.cash(), "minute": town.minute,
		"ledger": JSON.stringify(town.world.ledger.to_dict(), "", true, true),
		"notes": town.world.notebook.size(), "household": JSON.stringify(town.household(), "", true, true)}
	print("第一天睡前钱 %d，第二天早上 %d" % [d1_cash, saved["cash"]])
	c.check(FileAccess.file_exists(SAVE), "第二天早上的存档在")
	c.check(TownGame.has_save(SAVE), "标题画面据此显示“继续”")
	await c.shutdown()
	# 读档：全新的 Main
	var c2 = Common.new(self)
	await c2.make_main()
	var town2 = c2.town
	town2.set_fast(true)
	town2.auto_dismiss = true
	town2.autosave = false
	town2.save_path = SAVE
	var ok: bool = await town2.load_game(SAVE)
	c2.check(ok, "读档成功")
	await c2.until_idle()
	c2.check(town2.world.day == saved["day"], "读档后日期一致：第 %d 天" % town2.world.day)
	c2.check(town2.world.cash() == saved["cash"], "读档后钱一致：%d" % town2.world.cash())
	c2.check(town2.minute == saved["minute"], "读档后钟一致：%d" % town2.minute)
	c2.check(JSON.stringify(town2.world.ledger.to_dict(), "", true, true) == saved["ledger"], "读档后账本逐字一致")
	c2.check(town2.world.notebook.size() == saved["notes"], "读档后档案簿条数一致")
	c2.check(JSON.stringify(town2.household(), "", true, true) == saved["household"], "读档后家用一致")
	c2.check(town2.mode == "town" and town2.map_id == "pawnshop", "读档后在当铺里醒着")
	# 读档后接着过一天不出错
	town2.seconds_per_minute = 100000.0
	town2.skip_to(1100)
	c2.check(town2.world.ledger.check_invariants().is_empty(), "读档后接着走钟，账本不变量没破")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var fails: int = c.failures + c2.failures
	print("RESULT: ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	await c2.shutdown()
	quit(0 if fails == 0 else 1)
