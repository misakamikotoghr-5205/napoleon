# 小镇界面（c）：客人到点走进当铺等着；主角走到柜台后，自动切到旧的柜台特写做完生意，再回当铺内部。
# godot --headless -s res://scripts/tests/town_ui_counter.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")

var c
var served: Array = []

func _initialize() -> void:
	_run()

func _on_served(id: String) -> void:
	served.append(id)

func _run() -> void:
	c = Common.new(self)
	await c.boot(13)
	var town = c.town
	town.seconds_per_minute = 100000.0
	town.visit_served.connect(_on_served)
	town.skip_to(545)                        # 小丁九点来当
	var ok_wait: bool = await c.until(func(): return not town.visitors.next_ready().is_empty(), 900)
	c.check(ok_wait, "到点的客人走进当铺、站到了等候点")
	c.check(town.visitors.count() >= 1, "当铺里有 %d 位客人在等" % town.visitors.count())
	var walkers := 0
	for id in town.visitors.present:
		if town.visitors.present[id]["walker"] != null:
			walkers += 1
	c.check(walkers >= 1, "客人有看得见的行走人物")
	c.check(town.map_id == "pawnshop" and town.mode == "town", "主角还在当铺内部，没有被拽进柜台")
	# 走到柜台后面：自动开始接待（一笔生意在 autoplayer 的“瞬间应答”下常常一帧内就做完，所以数 counter_started，不盯模式）
	var map = town.world_view.map
	var minute_before: int = town.minute
	var started_before: int = town.counter_started
	await town.goto("counter")
	var started: bool = await c.until(func(): return town.counter_started > started_before, 600)
	c.check(started, "站到柜台后（%s）自动开始接待" % str(map.counter_spot))
	var done: bool = await c.until(func(): return town.mode == "town" and served.size() >= 1, 3000)
	c.check(done, "一笔生意做完，回到当铺内部（已接待 %d 位）" % served.size())
	c.check(c.main.mode == "town" and not c.main.scene_holder.visible and not c.main.dialogue.visible, "对白框和柜台层收拾干净")
	c.check(town.minute >= minute_before + 10, "生意花了时间：%d → %d" % [minute_before, town.minute])
	var state: Dictionary = town.director.vars["town"]
	c.check(state["done_visits"].size() >= 1, "导演记下了办完的来访")
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	# 把剩下的也接了（最多 4 位），看不会卡
	var guard := 0
	while not town.visitors.next_ready().is_empty() and guard < 5:
		guard += 1
		var before: int = served.size()
		town.start_counter(town.visitors.next_ready())
		await c.until(func(): return town.mode == "town" and served.size() > before, 3000)
	c.check(town.mode == "town", "接完所有在等的客人后回到小镇模式")
	# 没人接待的客人会走：把钟拨到下午，早上的路人都该走了
	town.skip_to(1000)
	await c.frames(10)
	var waiting: Array = []
	for id in town.visitors.present:
		if not town.visitors.is_story(town.visitors.present[id]["visit"]):
			waiting.append(id)
	c.check(waiting.is_empty(), "过了耐心的路人客自己走了（剩 %d）" % waiting.size())
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破（结尾）")
	var fails1: int = c.failures
	await c.shutdown()
	var fails2: int = await _phase2()
	var fails: int = fails1 + fails2
	print("RESULT: ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	quit(0 if fails == 0 else 1)

# 第二段（新开一局，非快钟）：接待只在柜台后开始、等候的客人不会同时站在街上（M3）、办不成的生意不收时间也不算接待（L5）
func _phase2() -> int:
	var c2 = Common.new(self)
	await c2.boot(13, false, false)
	var town = c2.town
	town.seconds_per_minute = 100000.0
	var map = town.world_view.map
	var served2: Array = []
	town.visit_served.connect(func(id: String): served2.append(id))
	# --- 客人还在走路的时候，站到柜台后面也接待不了 ---
	town.player.teleport(map.counter_spot)
	await c2.frames(2)
	var walking_case: bool = town.visitors.count() >= 1 and town.visitors.next_ready().is_empty()
	var near: Dictionary = town._find_near()
	c2.check(not walking_case or not str(near.get("label", "")).begins_with("招呼") and not str(near.get("label", "")).begins_with("接待"),
		"客人还在走路时（%s）柜台后没有“招呼/接待”提示：%s" % [str(walking_case), str(near.get("label", ""))])
	var ok_wait: bool = await c2.until(func(): return not town.visitors.next_ready().is_empty(), 1500)
	c2.check(ok_wait, "客人走到位、站定了")
	# --- 站在客人旁边（柜台前面）：直接招呼他；按 E 的实际效果在 town_ui_pawnshop 里验 ---
	var row: Dictionary = town.visitors.present.values()[0]
	var w = row["walker"]
	town.player.teleport(map.nearest_free(w.position + Vector2(0, 16)))
	await c2.frames(2)
	var near2: Dictionary = town._find_near()
	var away_label := str(near2.get("label", ""))
	c2.check(town.player.global_position.distance_to(map.counter_spot) > 18.0 and away_label.begins_with("招呼"),
		"离开柜台、站在客人旁边：出现“招呼 X”（提示：%s）" % away_label)
	town.player.teleport(map.counter_spot)
	await c2.frames(2)
	var at_counter := str(town._find_near().get("label", ""))
	c2.check(at_counter.begins_with("招呼") or at_counter.begins_with("接待"), "站到柜台后：出现接待提示（%s）" % at_counter)
	# --- M3：小丁九点来当，他按日程这会儿在桥头街 ---
	town.skip_to(545)
	var xd := "xiaoding"
	var arrived: bool = await c2.until(func(): return town.visitors.is_present(xd) and not town.visitors.next_ready().is_empty(), 900)
	c2.check(arrived, "小丁到了当铺里等着")
	var loc: String = town.world.town.npc_location(xd)
	c2.check(town.crowd.is_street_place(loc), "（前提）按日程他这会儿在街上（%s）" % loc)
	await town.goto("ricehall")
	c2.check(town.map_id == "town" and town.crowd.walkers.size() > 0, "出门上街（街上 %d 个人）" % town.crowd.walkers.size())
	c2.check(not town.crowd.walkers.has(xd) and town.crowd.walker_for(xd) == null, "M3：小丁在当铺里等着，街上没有第二个小丁")
	town.crowd.on_move(xd, "家", "桥头街")
	c2.check(town.crowd.walker_for(xd) == null, "M3：日程挪动也不会把等着的他画到街上")
	var vid := ""
	for id in town.visitors.present:
		if str(town.visitors.present[id]["visit"].get("who", "")) == xd:
			vid = str(id)
	town.visitors.abandon(vid)
	c2.check(not town.visitors.is_present(xd) and town.crowd.walker_for(xd) != null, "M3：他走出当铺后，按日程回到街上")
	# --- L5：办不成的生意 ---
	await town.goto("counter")
	var minute0: int = town.minute
	var started0: int = town.counter_started
	var toasts0: int = town.overlay._toast_box.get_child_count() + town.overlay._toast_queue.size()
	town.start_counter({"id": "ghost_visit", "who": "zhang", "intent": "sell"})
	await c2.until(func(): return town.mode == "town", 600)
	c2.check(town.counter_started == started0 + 1 and town.mode == "town", "不存在的来访：进了又出来，回到小镇")
	c2.check(town.minute == minute0, "办不成：不耗时间（%d → %d）" % [minute0, town.minute])
	c2.check(served2.is_empty(), "办不成：不算接待（visit_served 没发）")
	c2.check(town.overlay._toast_box.get_child_count() + town.overlay._toast_queue.size() > toasts0, "办不成：说了一声")
	town.skip_to(1090)
	var stale := ""
	for id in town.visitors.present:
		if str(id).begins_with("visit_d1"):
			stale = str(id)
	c2.check(stale != "", "傍晚来了路人客（%s）" % stale)
	if stale != "":
		var visit: Dictionary = town.visitors.present[stale]["visit"].duplicate(true)
		town.world.town.visit_missed(stale)            # 模拟：他的事在别处已经了结
		var m1: int = town.minute
		town.start_counter(visit)
		await c2.until(func(): return town.mode == "town", 600)
		c2.check(town.minute == m1 and served2.is_empty(), "已经了结的来访：不耗时间、不算接待")
		c2.check(not town.visitors.present.has(stale) and town.visitors.blocked.has(stale), "已经了结的来访：客人撤下，不再反复提示")
	c2.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破（第二段）")
	var f: int = c2.failures
	await c2.shutdown()
	return f
