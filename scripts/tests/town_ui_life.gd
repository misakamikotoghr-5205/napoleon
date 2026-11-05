# 小镇界面（f）：活的小镇——街上的人按日程走、搭话有气泡不露数字、地图提示只发一次光、宵禁与半夜强制入睡。
# godot --headless -s res://scripts/tests/town_ui_life.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownMap = preload("res://scripts/town/town_map.gd")

var c

func _initialize() -> void:
	_run()

func _toast_text(town) -> String:
	var out := ""
	for t in town.overlay._toast_box.get_children():
		out += (t as Label).text + "|"
	for q in town.overlay._toast_queue:
		out += str(q["text"]) + "|"
	return out

func _run() -> void:
	c = Common.new(self)
	await c.boot(31)
	var town = c.town
	town.seconds_per_minute = 100000.0
	# --- 街上的人（九点半：小丁、张护士、马保长在街上）---
	town.skip_to(550)
	await town.goto("ricehall")
	c.check(town.map_id == "town", "出门到了小镇")
	c.check(town.crowd.walkers.size() > 0, "街上有按日程出现的人（%d 个）" % town.crowd.walkers.size())
	# --- 搭话：气泡 ---
	var target = null
	for id in town.crowd.walkers:
		if is_instance_valid(town.crowd.walkers[id]) and town.crowd.walkers[id].visible:
			target = town.crowd.walkers[id]
			break
	c.check(target != null, "找到一个可以搭话的人")
	if target != null:
		target.path = []
		town.player.teleport(town.world_view.map.nearest_free(target.position + Vector2(0, 14)))
		await c.frames(3)
		town.interact()
		c.check(town.overlay.is_speaking(), "按 E：头顶出现气泡")
		var line: String = str(town.overlay._lines[0])
		var has_digit := false
		for ch in line:
			if ch >= "0" and ch <= "9":
				has_digit = true
		c.check(line != "" and not has_digit, "寒暄是一句话，没有数字：%s" % line)
		var guard := 0
		while town.overlay.is_speaking() and guard < 10:
			guard += 1
			town.overlay.advance_speech()
		c.check(not town.overlay.is_speaking(), "说完气泡收起")
	# --- 地图提示：第一次靠近发光，之后不再 ---
	var hint: Dictionary = town.world_view.map.hints[0]
	var hp: Vector2 = TownMap.tile_center(hint["at"])
	town.player.teleport(town.world_view.map.nearest_free(hp + Vector2(0, 20)))
	await c.frames(4)
	var glows1: int = town.overlay._glows.size()
	c.check(glows1 >= 1, "靠近告示墙：发光提示出现")
	town.player.teleport(Vector2(600, 232))
	await c.frames(3)
	town.player.teleport(town.world_view.map.nearest_free(hp + Vector2(0, 20)))
	await c.frames(4)
	c.check(town.overlay._glows.size() <= glows1, "再次靠近不再重复发光（once）")
	# --- 日程换档：下午的人换了地方 ---
	var moves_before: int = town.crowd.moves_handled
	town.skip_to(1000)
	c.check(town.crowd.moves_handled > moves_before, "日程换档时处理了 NPC 走动事件（%d 次）" % (town.crowd.moves_handled - moves_before))
	# --- 宵禁 ---
	town.skip_to(1259)
	var t1: String = _toast_text(town)
	town.skip_to(1262)
	await c.frames(2)
	var t2: String = _toast_text(town)
	c.check(t2.find("宵禁") >= 0 and t1 != t2, "21:00：宵禁提醒")
	c.check(town.minute >= 1260, "钟过了宵禁点")
	c.check(town.crowd.patrol != null, "宵禁后街上有巡逻的")
	# --- 半夜强制入睡 ---
	await town.goto("pawnshop")
	await town.goto("inside")
	town.skip_to(1440)
	var ok: bool = await c.until(func(): return town.world.day == 2 and town.is_idle_in_town(), 3000)
	c.check(ok, "24:00 强制入睡，换到第 2 天（day=%d）" % town.world.day)
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	print("RESULT: ", "OK" if c.failures == 0 else "FAILED (%d)" % c.failures)
	var code: int = 0 if c.failures == 0 else 1
	await c.shutdown()
	quit(code)
