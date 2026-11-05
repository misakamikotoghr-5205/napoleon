# 小镇界面（a）：开局进当铺内部；用真实物理走到出口、走进小镇、再走回当铺门里；撞墙、不下水。
# godot --headless -s res://scripts/tests/town_ui_walk.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")

var c

func _initialize() -> void:
	_run()

# 沿路网走到门前，再朝门的方向顶进去，直到换图
func _walk_into(door: Dictionary, target_map: String) -> bool:
	var town = c.town
	var player = town.player
	var map = town.world_view.map
	var front: Vector2 = map.nearest_free(door["front"])
	player.walk_points(map.path_between(player.position, front))
	await player.arrived
	if player.position.distance_to(front) > 12.0:
		player.teleport(front)          # 路网上被家具挡住时直接放到门前（游戏里 goto 也是这么兜底的）
	var want := Vector2(0, -1) if door["sprite"] else Vector2(0, 1)
	player.use_external = true
	player.external_input = want
	var ok: bool = await c.until(func(): return town.map_id == target_map, 400)
	player.external_input = Vector2.ZERO
	player.use_external = false
	await c.until_idle()
	return ok

func _run() -> void:
	c = Common.new(self)
	await c.boot(11)
	var town = c.town
	town.seconds_per_minute = 100000.0     # 钟冻住，只测走路
	c.check(town.mode == "town", "开新局后进入小镇模式（晨间告示已关）")
	c.check(c.main.mode == "town", "main 的模式也是 town")
	c.check(not c.main.scene_holder.visible, "小镇模式下旧柜台层是隐藏的")
	c.check(town.map_id == "pawnshop", "早上在当铺里醒来")
	c.check(town.world_view.visible and town.hud.visible, "小镇画面和 HUD 可见")
	c.check(town.minute == 360, "从 6:00 开始")
	town.skip_to(550)                      # 九点半：街上有人（清晨他们都还在屋里）
	var map = town.world_view.map
	c.check(map.valid and map.id == "pawnshop", "当铺地图载入")
	c.check(town.world_view.sub.size == Vector2i(320, 180), "SubViewport 是 320×180")
	c.check(town.world_view.stretch_shrink == 4 and town.world_view.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "整数 ×4 放大，最近邻")
	c.check(town.player.global_position.distance_to(map.spawns["wake"]) < 24.0, "醒来的位置在 wake 点附近")
	# 1. 当铺门口：打开“去哪儿”，人还在铺子里。街上的碰撞仍走原来的地图（测试直接换图）。
	var exit_door: Dictionary = map.door_to_map("town")
	c.check(not exit_door.is_empty(), "当铺有通小镇的门")
	var player0 = town.player
	var front: Vector2 = map.nearest_free(exit_door["front"])
	player0.walk_points(map.path_between(player0.position, front))
	await player0.arrived
	if player0.position.distance_to(front) > 12.0:
		player0.teleport(front)
	var want := Vector2(0, -1) if exit_door["sprite"] else Vector2(0, 1)
	player0.use_external = true
	player0.external_input = want
	var opened: bool = await c.until(func(): return town.travel_panel != null, 400)
	player0.external_input = Vector2.ZERO
	player0.use_external = false
	c.check(opened and town.map_id == "pawnshop", "走到出口：打开去哪儿，人还在当铺里")
	c.check(town.guide != null and town.guide.ui_override == "travel", "去哪儿开着时，引导认这是出门地图")
	town.dismiss_modals()
	await c.until_idle()
	town._door_lock = 1.0
	await town._enter_map("town", "from_pawnshop")
	c.check(town.map_id == "town", "原来的小镇地图还能进（碰撞用）")
	var tmap = town.world_view.map
	var pdoor: Dictionary = tmap.door_for_building("pawnshop")
	c.check(town.player.global_position.distance_to(pdoor["front"]) < 32.0, "出来时站在当铺门前")
	c.check(town.crowd.walkers.size() > 0, "街上有按日程出现的人（%d 个）" % town.crowd.walkers.size())
	# 2. 碰撞：往茶馆墙里顶，进不去；往河里走，下不了水
	var tea: Dictionary = tmap.object_for_building("teahouse")
	var player = town.player
	player.teleport(Vector2(tea["pos"].x + 20.0, tea["bottom"] + 14.0))
	player.use_external = true
	player.external_input = Vector2(0, -1)
	await c.frames(70)
	c.check(player.position.y >= float(tea["bottom"]) + 5.0, "顶着茶馆的墙走不进去（y=%.1f）" % player.position.y)
	player.teleport(tmap.spawns["wake"])
	player.external_input = Vector2(0, 1)
	await c.frames(160)
	c.check(player.position.y < 272.0, "往河边走会停在河岸上（y=%.1f）" % player.position.y)
	player.external_input = Vector2.ZERO
	player.use_external = false
	# 3. 小镇 → 当铺
	var ok2: bool = await _walk_into(pdoor, "pawnshop")
	c.check(ok2 and town.map_id == "pawnshop", "走进当铺的门：回到当铺内部")
	c.check(town.player.global_position.distance_to(town.world_view.map.spawns["front_door"]) < 40.0, "进门后站在门口")
	# 4. 锁着的门只弹提示，不进店
	await town.goto("police")
	var before: int = town.overlay._toast_box.get_child_count()
	town.open_shop("police")
	await c.frames(2)
	c.check(town.mode == "town" and not town.shop_view.is_open, "警察所（封条）进不去")
	c.check(town.overlay._toast_box.get_child_count() > before or not town.overlay._toast_queue.is_empty(), "进不去时给了一句话")
	c.check(town.world_view.buildings.has("police") and town.world_view.buildings["police"]["variant"] == "locked", "警察所显示封条贴图")
	print("RESULT: ", "OK" if c.failures == 0 else "FAILED (%d)" % c.failures)
	var code: int = 0 if c.failures == 0 else 1
	await c.shutdown()
	quit(code)
