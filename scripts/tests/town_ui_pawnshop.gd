# 当铺内部（试玩反馈修补）：柜台/家具有真的碰撞、腰门能穿过去、客人站在柜台前（Y 排序）、
# 每个交互点的提示（对的物件、对的字、对的位置、按 E 真的做那件事）、电报机只有一条规则且站着不动不会来回跳、
# 出门再进门之后等着的客人照样能接待（身体丢了会自己补回来；柜台前面直接招呼、点击客人都行）。
# godot --headless -s res://scripts/tests/town_ui_pawnshop.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const TownMap = preload("res://scripts/town/town_map.gd")

var failures: int = 0
var c
var town
var main
var map

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	root.push_input(ev)
	await process_frame

# 主角路上碰上熟人说的话（main 里一句一句的 say）：按 E 往下翻，直到人回到能走动的状态
func _say_through(max_frames: int = 900) -> void:
	var n := 0
	while n < max_frames and not town.is_idle_in_town():
		if town.main.cur_type in ["say", "narr"]:
			await _key(KEY_E)
			await c.frames(2)
		else:
			await process_frame
		n += 1

# 走路要等物理帧（无头测试里普通帧比物理帧快得多）
func _phys(n: int) -> void:
	for i in n:
		await physics_frame

func _toasts() -> String:
	var parts: Array = []
	for l in town.overlay._toast_box.get_children():
		parts.append((l as Label).text)
	for row in town.overlay._toast_queue:
		parts.append(str(row["text"]))
	return " | ".join(parts)

func _clear_toasts() -> void:
	town.overlay.clear_toasts()

# 站到 p，让提示刷新（_update_world 每帧跑）
func _stand(p: Vector2, frames: int = 3) -> Dictionary:
	town.player.teleport(p)
	await c.frames(frames)
	return town._find_near()

func _modal(file: String):
	for m in town.modal_layer.get_children():
		if m.get_script() != null and str(m.get_script().resource_path).ends_with(file):
			return m
	return null

func _run() -> void:
	c = Common.new(self)
	await c.boot(13, false, false)
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	town.world.unlocked["telegraph"] = true          # 序章里陈叔叔教过了（测试跳过了序章）
	map = town.world_view.map
	town.skip_to(420)
	await c.frames(3)
	town.visitors.clear_walkers()
	town.visitors.present.clear()
	await _collision()
	await _prompts()
	await _telegraph()
	await _visitors()
	print("RESULT: ", "OK" if failures == 0 and c.failures == 0 else "FAILED (%d)" % (failures + c.failures))
	failures += c.failures
	await c.shutdown()
	quit(0 if failures == 0 else 1)

# ---------------------------------------------------------------- 碰撞与排序
func _collision() -> void:
	# 柜台那一带（贴图 y 100–140）整排是实心的，只有腰门那一格（x 240–256）能过
	var bad_solid := 0
	var bad_lane := 0
	for fx in range(53, 283, 2):
		for fy in range(106, 140, 2):
			var lane: bool = fx >= 245 and fx <= 251
			var free: bool = map.foot_free(Vector2(fx, fy))
			if lane and not free:
				bad_lane += 1
			elif not lane and free:
				bad_solid += 1
	_check(bad_solid == 0, "柜台贴图范围里除腰门外处处挡脚（漏洞 %d 处）" % bad_solid)
	_check(bad_lane == 0, "腰门那一格从头到尾能走（卡住 %d 处）" % bad_lane)
	var lane_ok := true
	for fy in range(80, 148, 2):
		lane_ok = lane_ok and map.foot_free(Vector2(248, fy))
	_check(lane_ok, "腰门通道从客人那一侧到柜台后一路畅通")
	_check(not map.foot_free(Vector2(60, 140)) and not map.foot_free(Vector2(200, 140)), "长凳挡脚")
	_check(not map.foot_free(Vector2(32, 80)) and not map.foot_free(Vector2(310, 80)), "床、后门洞挡脚（不能站到床上、踩进门洞）")
	_check(not map.foot_free(Vector2(288, 164)) and not map.foot_free(Vector2(22, 168)), "衣架、花盆挡脚")
	# 所有站位站得下、走得到
	var spots: Dictionary = {"counter_spot": map.counter_spot, "wake": map.spawns["wake"], "front_door": map.spawns["front_door"]}
	for i in map.customer_spots.size():
		spots["customer_spot[%d]" % i] = map.customer_spots[i]
	for key in map.interacts:
		if map.interacts[key].has("stand"):
			spots["interact." + key] = map.interacts[key]["stand"]
	var seen := _flood(map.spawns["wake"])
	for key in spots:
		var p: Vector2 = spots[key]
		_check(map.foot_free(p), "站位 %s %s 没压在家具里" % [key, str(p)])
		_check(_reach(seen, p), "站位 %s 走得到" % key)
	_check(_reach(seen, map.doors[0]["front"] if map.doors.size() > 0 else Vector2(168, 168)), "街门口走得到")
	# 真的往柜台里推：停在柜台前，进不去
	town.player.use_external = true
	# 对照：空地上同样推 60 帧，确实走得动（下面“推不进去”才不是因为根本没走）
	town.player.teleport(Vector2(130, 165))
	town.player.external_input = Vector2(0, -1)
	await _phys(30)
	_check(town.player.position.y < 160.0, "（对照）空地上往上推 30 个物理帧：走动了 → y=%.1f" % town.player.position.y)
	town.player.teleport(Vector2(70, 160))
	await _phys(100)
	_check(town.player.position.y >= 145.0 and town.player.position.y <= 150.0, "从长凳前往柜台里推 100 帧：停在 y=%.1f（≈148，贴着柜台），没有走进柜台图" % town.player.position.y)
	town.player.teleport(Vector2(200, 160))
	await _phys(100)
	_check(town.player.position.y >= 145.0 and town.player.position.y <= 150.0, "从油灯那一段往里推：停在 y=%.1f" % town.player.position.y)
	town.player.teleport(Vector2(248, 130))        # 站在腰门里往左右推：进不了两边的柜台
	town.player.external_input = Vector2(-1, 0)
	await _phys(60)
	_check(town.player.position.x >= 244.0 and town.player.position.x < 247.9, "在腰门里往左推：x=%.1f，贴着左边的柜台，没进去" % town.player.position.x)
	town.player.teleport(Vector2(248, 130))
	town.player.external_input = Vector2(1, 0)
	await _phys(60)
	_check(town.player.position.x <= 252.0 and town.player.position.x > 248.1, "在腰门里往右推：x=%.1f，贴着右边的柜台，没进去" % town.player.position.x)
	# 腰门走得过去：从客人那一侧一路往上，到柜台后面
	town.player.teleport(Vector2(248, 150))
	town.player.external_input = Vector2(0, -1)
	await _phys(160)
	_check(town.player.position.y <= 80.0 and absf(town.player.position.x - 248.0) < 3.0, "从腰门走过去：到了柜台后面 %s" % str(town.player.position))
	town.player.external_input = Vector2(0, 1)
	await _phys(200)
	_check(town.player.position.y >= 145.0, "再从腰门走回客人那一侧 %s" % str(town.player.position))
	town.player.use_external = false
	town.player.external_input = Vector2.ZERO
	# 客人走位：进门到等候点、出门的路上不穿柜台
	var worst := 0
	var starts: Array = [map.named["exit"] - Vector2(0, 10)] + map.customer_spots
	for a in starts:
		for b in map.customer_spots + [map.named["exit"]]:
			var path: Array = map.path_between(a, b)
			for i in range(path.size() - 1):
				var p0: Vector2 = path[i]
				var p1: Vector2 = path[i + 1]
				var steps := int(p0.distance_to(p1) / 2.0) + 1
				for k in range(steps + 1):
					var q: Vector2 = p0.lerp(p1, float(k) / float(steps))
					if q.y > 100.0 and q.y < 140.0:
						worst += 1
	_check(worst == 0, "客人从门口走到等候点、再走出去，路线上没有穿过柜台的点（%d）" % worst)
	# Y 排序：柜台、长凳的脚线在客人之前、主角（柜台后）之后
	var counter_y := 0.0
	var holders: Array = []
	for k in map.objects:
		if str(k["id"]).begins_with("counter") or str(k["id"]) == "pawn_bench":
			counter_y = maxf(counter_y, float(k["foot"].y))
			holders.append(k["foot"].y)
	town.player.teleport(map.counter_spot)
	_check(town.player.position.y < float(holders.min()), "柜台后的主角（y=%d）在柜台脚线（%d）之前画：被柜台挡在后面" % [int(town.player.position.y), int(holders.min())])
	for s in map.customer_spots:
		_check((s as Vector2).y > counter_y, "客人等候点 %s 的脚线在柜台脚线（%d）之后：站在柜台前面" % [str(s), int(counter_y)])
	_check(map.customer_spots.size() >= 2 and (map.counter_spot.y < (map.customer_spots[0] as Vector2).y), "主角在柜台后、客人在柜台前")
	_check(town.world_view.ysort != null and town.world_view.ysort.y_sort_enabled, "角色和家具按脚线 Y 排序")

func _flood(start: Vector2) -> Dictionary:
	var seen: Dictionary = {}
	var stack: Array = [Vector2i(int(start.x) / 2 * 2, int(start.y) / 2 * 2)]
	var w := int(map.size_px.x)
	var h := int(map.size_px.y)
	while not stack.is_empty():
		var q: Vector2i = stack.pop_back()
		if seen.has(q) or q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or not map.foot_free(Vector2(q.x, q.y)):
			continue
		seen[q] = true
		stack.append(Vector2i(q.x + 2, q.y))
		stack.append(Vector2i(q.x - 2, q.y))
		stack.append(Vector2i(q.x, q.y + 2))
		stack.append(Vector2i(q.x, q.y - 2))
	return seen

func _reach(seen: Dictionary, p: Vector2) -> bool:
	return seen.has(Vector2i(int(p.x) / 2 * 2, int(p.y) / 2 * 2)) or seen.has(Vector2i(int(p.x) / 2 * 2, int(p.y - 1) / 2 * 2))

# ---------------------------------------------------------------- 提示：每个交互点
func _prompts() -> void:
	var hud_rect: Rect2 = town.overlay.HUD_RECT
	# (站位, 期望 id, 期望提示, 物件在世界里的位置（提示必须指着它附近）)
	var table: Array = [
		["bed", Vector2(58, 72), "bed", "床（天还早）", Vector2(32, 78)],
		["shelf", Vector2(110, 72), "shelf", "看货架", Vector2(110, 36)],
		["counter 没客人", map.counter_spot, "shelf", "看货架", Vector2(168, 36)],
		["lamp", Vector2(191, 72), "lamp", "油灯", Vector2(191, 96)],
		["telegraph", Vector2(275, 72), "telegraph", "电报机（打烊后才能用）", Vector2(275, 98)],
		["backdoor", Vector2(297, 72), "backdoor", "后门", Vector2(312, 90)],
	]
	for row in table:
		var near: Dictionary = await _stand(row[1])
		_check(str(near.get("id", "")) == row[2] and str(near.get("label", "")) == row[3], "站在%s旁（%s）：提示“%s”（实际 %s/%s）" % [row[0], str(row[1]), row[3], str(near.get("id", "")), str(near.get("label", ""))])
		var anchor: Vector2 = near.get("anchor", Vector2.INF)
		_check(anchor.distance_to(row[4]) < 6.0, "%s的提示指着对的地方 %s（目标 %s）" % [row[0], str(anchor), str(row[4])])
		var shown: String = town.overlay.prompt_text()
		var rect: Rect2 = town.overlay.prompt_rect()
		_check(shown == "【E】 " + str(row[3]), "%s：屏幕上的提示条写着“%s”" % [row[0], shown])
		_check(Rect2(0, 0, 1280, 720).encloses(rect) and not rect.intersects(hud_rect), "%s：提示条整个在屏幕内、没压在右上角的 HUD 上 %s" % [row[0], str(rect)])
	# 这些地方没有任何提示：腰门通道里、两张长凳之间的空地
	var none1: Dictionary = await _stand(Vector2(248, 120))
	_check(none1.is_empty() and town.overlay.prompt_text() == "", "腰门通道里没有提示（它不是交互物件）")
	var none2: Dictionary = await _stand(Vector2(130, 160))
	_check(none2.is_empty(), "柜台前的空地没有提示（没客人）")
	var door: Dictionary = await _stand(Vector2(168, 176))
	_check(str(door.get("label", "")) == "出门" and str(door.get("id", "")) == "door:town", "站在门格上：出门")
	# 货架这一整面墙：每个 x 上最多一个提示，只有两种来源——货架或离得近的物件；沿走廊扫一遍，物件的区间连续，不来回跳
	var ids: Array = []
	for x in range(52, 300, 1):
		town.player.teleport(Vector2(x, 72))
		await c.frames(2)
		ids.append(str(town._find_near().get("id", "-")))
	var changes := 0
	for i in range(1, ids.size()):
		if ids[i] != ids[i - 1]:
			changes += 1
	var regions := _runs(ids)
	_check(regions.find("-") < 0, "走廊上从头到尾每个位置都有提示（%s）" % str(regions))
	_check(changes == regions.size() - 1 and regions == ["bed", "shelf", "lamp", "shelf", "telegraph", "backdoor"], "沿走廊 1 像素一步扫过去：提示依次是 %s，每个区间只出现一次" % str(regions))
	var back: Array = []
	for x in range(299, 51, -1):
		town.player.teleport(Vector2(x, 72))
		await c.frames(2)
		back.append(str(town._find_near().get("id", "-")))
	var back_regions := _runs(back)
	_check(back_regions.size() == 6, "反方向扫回来：同样 6 个区间，没有额外的来回跳（%s）" % str(back_regions))
	# 柜台后面的走道有好几行（脚线 y 72–83 都走得到）：走在哪一行，同一个 x 上的提示都一样
	var rows_ok := true
	var row_info := ""
	for y in [72, 76, 80, 83]:
		var row_ids: Array = []
		for x in range(52, 300, 2):
			town.player.teleport(Vector2(x, y))
			await c.frames(1)
			row_ids.append(str(town._find_near().get("id", "-")))
		var row_regions := _runs(row_ids)
		row_info += " y=%d:%s" % [y, str(row_regions)]
		rows_ok = rows_ok and row_regions == ["bed", "shelf", "lamp", "shelf", "telegraph", "backdoor"]
	_check(rows_ok, "走道的每一行（y=72/76/80/83）提示的顺序都一样，贴着柜台那一行也有油灯、电报箱的提示（%s ）" % row_info)
	var lamp_rows := 0
	for y in [72, 76, 80, 83]:
		var near_row: Dictionary = await _stand(Vector2(191, y))
		if str(near_row.get("id", "")) == "lamp":
			lamp_rows += 1
	_check(lamp_rows == 4, "站在油灯正后方，走道里每一行都是“油灯”（%d/4）" % lamp_rows)
	var far_y: Dictionary = await _stand(Vector2(191, 100))
	_check(str(far_y.get("id", "")) != "lamp", "油灯的提示不会隔着柜台（y=100 在柜台里，走不到；就算瞬移过去也不出油灯）")
	# 按 E 真的做它写的事
	_clear_toasts()
	await _stand(Vector2(58, 72))
	await _key(KEY_E)
	_check(_toasts().find("天还亮") >= 0 and not town.is_sleeping(), "白天在床边按 E：说天还亮着，没睡（%s）" % _toasts())
	_clear_toasts()
	await _stand(Vector2(191, 72))
	await _key(KEY_E)
	_check(_toasts().find("油灯") >= 0 and _toasts().find("灯油") >= 0, "油灯按 E：说灯油（%s）" % _toasts())
	_clear_toasts()
	await _stand(Vector2(297, 72))
	await _key(KEY_E)
	_check(_toasts().find("后门") >= 0, "后门按 E：说后门（%s）" % _toasts())
	await _stand(Vector2(110, 72))
	await _key(KEY_E)
	_check(_modal("shelf_panel.gd") != null, "货架按 E：打开满当货架")
	await _key(KEY_E)
	_check(_modal("shelf_panel.gd") == null and town.mode == "town", "再按 E：货架关上")
	# 街上的提示也指着它的对象
	town.skip_to(560)
	await town.goto("ricehall")
	await c.frames(3)
	var street: Dictionary = town._find_near()
	# 街上有人走过门口时（例如胡二），先招呼人是对的；不管哪种，提示都指着身边的东西
	var street_id := str(street.get("id", ""))
	_check((street_id.begins_with("door:") or street_id.begins_with("npc:")) and (street.get("anchor", Vector2.INF) as Vector2).distance_to(town.player.global_position) < 60.0, "街上站在米行门口：提示指着门或门口的人（%s %s）" % [street_id, str(street.get("anchor", ""))])
	await town.goto("counter")
	await c.frames(3)

func _runs(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		if out.is_empty() or out[out.size() - 1] != id:
			out.append(id)
	return out

# ---------------------------------------------------------------- 电报机：一条规则
func _telegraph() -> void:
	town.world.unlocked["telegraph"] = false
	var st: Dictionary = town.telegraph_state()
	_check(st["state"] == "locked" and not st["usable"] and str(st["label"]).find("还不会用") >= 0, "没学会：不能用，提示说“还不会用”（%s）" % str(st["label"]))
	town.world.unlocked["telegraph"] = true
	town.skip_to(600)
	await c.frames(2)
	st = town.telegraph_state()
	_check(st["state"] == "day" and not st["usable"] and str(st["text"]).find("白天用电报太扎眼") >= 0 and str(st["text"]).find("打烊") >= 0, "白天：不能用，说“白天用电报太扎眼，等打烊以后”")
	# 站在电报箱旁不动：提示一直是同一句（时钟停着）
	await _stand(Vector2(275, 72))
	var labels: Dictionary = {}
	for i in 90:
		await process_frame
		labels[town.overlay.prompt_text()] = true
	_check(labels.size() == 1, "站着不动 90 帧：提示条只有一种写法（%s）" % str(labels.keys()))
	_clear_toasts()
	await _key(KEY_E)
	_check(_toasts().find("白天用电报太扎眼") >= 0, "白天按 E：说明为什么不能用（%s）" % _toasts())
	# 柜台特写里点电报机：同一句话
	main.toast_lbl.text = ""
	main._on_hotspot("telegraph")
	_check(main.toast_lbl.text == st["text"], "柜台特写里点电报机：说的是同一句（%s）" % main.toast_lbl.text)
	# 钟走过打烊（18:00，也是床上从“床（天还早）”变成“睡觉”的钟点）：提示变一次，不会变回来；和床同一分钟变
	var story_cfg: Dictionary = town.director.town_storylets["config"]["story"]
	var free_from_before: int = int(story_cfg["free_night_from"])
	story_cfg["free_night_from"] = 1          # 第三夜起才能自己发：用配置把“自己发”提前，才测得到“夜里能用”的状态
	town.skip_to(1075)
	var seq: Array = []
	var tele_flip := -1
	var bed_flip := -1
	for i in 12:
		town.advance_minute()
		await _stand(Vector2(58, 72), 2)
		var bed_label: String = str(town._find_near().get("label", ""))
		if bed_flip < 0 and bed_label == "睡觉":
			bed_flip = town.minute
		await _stand(Vector2(275, 72), 2)
		var t: String = town.overlay.prompt_text()
		if tele_flip < 0 and str(town.telegraph_state()["state"]) == "night":
			tele_flip = town.minute
		if seq.is_empty() or seq[seq.size() - 1] != t:
			seq.append(t)
	_check(seq.size() == 2 and str(seq[0]).find("打烊后才能用") >= 0 and str(seq[1]).find("睡前用") >= 0, "钟走过 18:00（每分钟看一眼）：电报箱的提示只变一次（%s）" % str(seq))
	_check(tele_flip == 1080 and bed_flip == 1080, "电报机“能用”和床上“睡觉”在同一分钟（%d / %d）开始：夜里选单只有睡觉才进得去，两处说的一致" % [tele_flip, bed_flip])
	st = town.telegraph_state()
	_check(st["state"] == "night" and st["usable"], "夜里（能自己发的夜）：能用，说在“夜里的事”里发")
	_clear_toasts()
	await _key(KEY_E)
	_check(_toasts().find("夜里的事") >= 0 and _toasts().find("发电报") >= 0, "夜里按 E：说去“夜里的事”里发电报（%s）" % _toasts())
	story_cfg["free_night_from"] = free_from_before
	st = town.telegraph_state()
	_check(st["state"] == "scripted" and not st["usable"] and str(st["text"]).find("第三夜") >= 0, "头两夜：电报由剧情安排，不能自己发，并说明（%s）" % str(st["text"]))
	# 夜里选单：灰着的“发电报”要说原因；能用时不改原来的说明
	var beat := {"night": 2, "lamps": 3, "max_lamps": 3, "used": 0, "max_actions": 99, "actions": [
		{"id": "telegraph", "label": "发电报", "star": false, "cost": 1, "desc": "联系陈叔叔", "enabled": false},
		{"id": "sleep", "label": "睡觉", "star": false, "cost": 0, "desc": "", "enabled": true}]}
	town.world.unlocked["telegraph"] = false
	main._open_night(beat)
	var texts := _label_texts(main.generic_box)
	_check(texts.find("还不会用") >= 0, "夜里选单：发电报灰着，旁边说“还不会用”（%s）" % texts.substr(0, 80))
	town.world.unlocked["telegraph"] = true
	beat["actions"][0]["enabled"] = true
	main._open_night(beat)
	texts = _label_texts(main.generic_box)
	_check(texts.find("联系陈叔叔") >= 0 and texts.find("还不会用") < 0, "夜里选单：能用时照常显示原来的说明")
	main.generic_panel.visible = false
	main._clear_generic()

func _label_texts(node: Node) -> String:
	var out := ""
	for ch in node.get_children():
		if ch is Label:
			out += (ch as Label).text + " "
		out += _label_texts(ch)
	return out

# ---------------------------------------------------------------- 客人：出门再进门之后照样能接待
func _visitors() -> void:
	# 换一局：接上自动应答（柜台交易自己做完）
	await c.shutdown()
	c = Common.new(self)
	await c.boot(13, false, true)
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	map = town.world_view.map
	var served: Array = []
	town.visit_served.connect(func(id: String): served.append(id))
	# --- 主角在街上的时候客人到了，进门 ---
	await town.goto("ricehall")
	_check(town.map_id == "town", "（前提）主角在街上")
	town.skip_to(545)
	await c.frames(3)
	_check(town.visitors.count() >= 2, "主角不在当铺：客人到了，名单里有 %d 位" % town.visitors.count())
	for id in town.visitors.present:
		_check(town.visitors.present[id]["walker"] == null, "主角在街上：%s 的身体还没画（没人看）" % str(id))
	# 回到当铺
	await town.goto("counter")
	await c.frames(3)
	_check(town.map_id == "pawnshop", "（前提）回到当铺")
	var all_standing := true
	var all_in_tree := true
	for id in town.visitors.present:
		var w = town.visitors.present[id]["walker"]
		all_standing = all_standing and w != null and is_instance_valid(w) and not w.is_walking() and w.visible
		all_in_tree = all_in_tree and w != null and is_instance_valid(w) and w.is_inside_tree()
	_check(all_standing and all_in_tree, "出门期间到的客人：回来就站在等候点，身体挂在场景里")
	var near: Dictionary = town._find_near()
	_check(str(near.get("id", "")) == "counter" and str(near.get("label", "")).begins_with("招呼"), "站在柜台后：能招呼（%s）" % str(near.get("label", "")))
	_check(not town.visitors.next_ready().is_empty(), "next_ready 有人")
	# --- 来回换图很多次，每一次回来都还能接待 ---
	var rounds_ok := 0
	for i in 4:
		await town.goto("ricehall")
		town.spend_minutes(1)
		await town.goto("counter")
		await c.frames(3)
		var ready: Dictionary = town.visitors.next_ready()
		var w2 = town.visitors.walker_of(str(ready.get("id", "")))
		if not ready.is_empty() and w2 != null and not w2.is_walking():
			rounds_ok += 1
	_check(rounds_ok == 4, "来回出门进门 4 次：每次回来都有站定的客人可以接待（%d/4）" % rounds_ok)
	# --- 身体丢了（空、已释放）会自己补回来 ---
	var any_id: String = str(town.visitors.present.keys()[0])
	town.visitors.present[any_id]["walker"].queue_free()
	await c.frames(2)
	_check(town.visitors.walker_of(any_id) == null, "（前提）把一位客人的身体弄丢了")
	town.visitors.poll(town.minute)
	_check(town.visitors.walker_of(any_id) != null and not town.visitors.walker_of(any_id).is_walking(), "下一次点名：身体补回来了，站在等候点")
	var any_id2: String = str(town.visitors.present.keys()[1])
	town.visitors.present[any_id2]["walker"] = null
	town.skip_to(town.minute + 1)
	await c.frames(2)
	_check(town.visitors.walker_of(any_id2) != null, "身体是 null：过一分钟也补回来")
	var z_ok := true
	for id in town.visitors.present:
		var wz = town.visitors.present[id]["walker"]
		z_ok = z_ok and wz != null and wz.z_index == 0 and wz.get_parent() == town.world_view.ysort
	_check(z_ok, "客人和主角、家具一样挂在 Y 排序层里（没有“永远盖在最上面”的 z_index 补丁）")
	# --- 站在柜台前面也能直接招呼（E）与点击 ---
	var rows: Array = town.visitors.present.values()
	var first_visit: Dictionary = rows[0]["visit"]
	var w3 = town.visitors.walker_of(str(first_visit["id"]))
	town.player.teleport(map.nearest_free(w3.position + Vector2(0, 16)))
	await c.frames(3)
	var front: Dictionary = town._find_near()
	_check(str(front.get("id", "")) == "customer" and str(front.get("label", "")).begins_with("招呼") and (front.get("anchor", Vector2.INF) as Vector2).distance_to(w3.position + Vector2(0, -34)) < 2.0, "站在客人身边（柜台前面）：提示“招呼 X”，指着他的头顶（%s）" % str(front.get("label", "")))
	var served_before := served.size()
	var started_before: int = town.counter_started
	await _key(KEY_E)
	_check(town.counter_started == started_before + 1, "在客人身边按 E：开始接待")
	await c.until(func(): return town.mode == "town" and served.size() > served_before, 3000)
	_check(served.size() == served_before + 1, "这一位办完了（visit_served 发了）")
	# 点击客人
	var visit2: Dictionary = town.visitors.next_ready()
	var w4 = town.visitors.walker_of(str(visit2.get("id", "")))
	_check(w4 != null, "（前提）还有站定的客人")
	var started2: int = town.counter_started
	var click_pos: Vector2 = town.world_view.world_to_screen(w4.position + Vector2(0, -14))
	var evd := InputEventMouseButton.new()
	evd.button_index = MOUSE_BUTTON_LEFT
	evd.pressed = true
	evd.position = click_pos
	evd.global_position = click_pos
	town.world_view.gui_input.emit(evd)        # 无头窗口只有 64×64，push_input 进不了控件；真窗口里的点击在 shot_pawnshop_audit 里验
	await process_frame
	await c.frames(2)
	_check(town.counter_started == started2 + 1, "点击客人（屏幕 %s）：开始接待" % str(click_pos))
	await c.until(func(): return town.mode == "town", 3000)
	# 点空地什么也不发生
	var started3: int = town.counter_started
	_check(not town.click_world(Vector2(40, 400)) and town.counter_started == started3, "点空地：没有事发生")
	_check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	await _arrivals_elsewhere()

# ---------------------------------------------------------------- 客人到的时候主角不在“走动”状态：店铺特写、柜台里、街上
func _bodies_ok() -> String:
	var bad: Array = []
	for id in town.visitors.present:
		var visit: Dictionary = town.visitors.present[id]["visit"]
		if not town.visitors.needs_body(visit):
			continue
		var w = town.visitors.present[id].get("walker", null)
		if w == null or not is_instance_valid(w) or not w.is_inside_tree() or not w.visible:
			bad.append(str(id))
	return ",".join(bad)

func _wait_standing() -> void:
	await c.until(func():
		for id in town.visitors.present:
			var w = town.visitors.present[id].get("walker", null)
			if w != null and is_instance_valid(w) and w.is_walking():
				return false
		return true, 1200)

func _arrivals_elsewhere() -> void:
	# 换一局，干净的名单；主角站在当铺里的货架前（不在柜台后面，免得自动开始接待）
	await c.shutdown()
	c = Common.new(self)
	await c.boot(13, false, false)
	main = c.main
	town = c.town
	town.seconds_per_minute = 100000.0
	map = town.world_view.map
	town.visitors.clear_walkers()
	town.visitors.present.clear()
	town.player.teleport(Vector2(110, 72))
	town.skip_to(430)                              # 米行 7:00 开门
	await c.frames(2)
	# --- 1. 主角在当铺这张图上，看着店铺特写（不经过街上），时间过去，客人到了 ---
	await town.open_shop("ricehall")
	_check(town.mode == "closeup" and town.map_id == "pawnshop", "（前提）在当铺里直接进了米行特写（地图还是当铺）")
	town.skip_to(560)
	await c.frames(3)
	_check(town.visitors.count() >= 2, "特写期间客人到了：名单里 %d 位" % town.visitors.count())
	town.skip_to(700)
	await c.frames(3)
	_check(town.visitors.count() >= 3, "特写里再过了两个多钟头：名单里 %d 位（后到的也在）" % town.visitors.count())
	_check(_bodies_ok() == "", "特写期间到的客人（含后到的）都有身体、挂在场景里（缺：%s）" % _bodies_ok())
	town.shop_view.close_shop()
	await c.until(func(): return town.mode == "town" and not town._transitioning, 600)
	await _wait_standing()
	_check(town.mode == "town" and _bodies_ok() == "", "关了特写回到当铺：每位客人都站在等候点（缺：%s）" % _bodies_ok())
	var ready1: Dictionary = town.visitors.next_ready()
	_check(not ready1.is_empty(), "关了特写：有人可接待")
	# 每一位都招呼得到：站到他身边，提示就是“招呼 他”
	var greeted: Array = []
	for id in town.visitors.present:
		var wk = town.visitors.walker_of(str(id))
		if wk == null:
			continue
		town.player.teleport(map.nearest_free(wk.position + Vector2(0, 14)))
		await c.frames(3)
		var nr: Dictionary = town._find_near()
		if str(nr.get("id", "")) == "customer" and str(nr.get("label", "")).begins_with("招呼"):
			greeted.append(str(id))
	_check(greeted.size() == town.visitors.count(), "站到每一位客人身边都出“招呼 X”（%d/%d）" % [greeted.size(), town.visitors.count()])
	# --- 2. 一次来回很多遍：门口“去哪儿”出门再回来、特写进出，每一遍回来客人都在 ---
	for i in 3:
		town.player.teleport(Vector2(168, 176))
		await c.frames(2)
		await town.enter_door("town")
		_check(town.travel_panel != null and town.map_id == "pawnshop", "第 %d 遍：当铺的门打开“去哪儿”" % (i + 1))
		await town.travel_to("ricehall")
		await c.until(func(): return town.shop_view.is_open, 600)
		_check(town.shop_view.is_open and town.shop_view.building_id == "ricehall", "第 %d 遍：出门到了米行" % (i + 1))
		town.skip_to(town.minute + 3)
		town.shop_view.close_shop()
		await _say_through()        # 回来路上在桥头碰上熟人：按 E 把话听完
		_check(await c.until_idle(600), "第 %d 遍：从米行回到当铺，路上的话按 E 听完，人能走动" % (i + 1))
		_check(town.map_id == "pawnshop" and town.mode == "town", "第 %d 遍：人在当铺里" % (i + 1))
		await c.frames(3)
		await _wait_standing()
		_check(_bodies_ok() == "" and town.visitors.walker_of(str(town.visitors.next_ready().get("id", ""))) != null, "第 %d 遍（出门）：回来客人都在，能接待（缺：%s）" % [i + 1, _bodies_ok()])
		var at_spawn: Dictionary = town._find_near()
		_check(str(at_spawn.get("label", "")).begins_with("招呼") or str(at_spawn.get("label", "")) == "出门", "第 %d 遍：回来站在门口，提示是“招呼 X”或“出门”（%s）" % [i + 1, str(at_spawn.get("label", ""))])
		await town.open_shop("ricehall")
		town.skip_to(town.minute + 2)
		town.shop_view.close_shop()
		await c.until(func(): return town.mode == "town" and not town._transitioning, 600)
		_check(_bodies_ok() == "", "第 %d 遍（特写）：关了特写客人都在（缺：%s）" % [i + 1, _bodies_ok()])
	# 门口那一格：就算中间的等候点站着客人，站在出门那一格也是“出门”，E 就出门
	town.player.teleport(Vector2(168, 176))
	await c.frames(3)
	var at_door: Dictionary = town._find_near()
	_check(str(at_door.get("id", "")) == "door:town" and str(at_door.get("label", "")) == "出门", "站在出门那一格（客人在中间的等候点）：提示“出门”（%s/%s）" % [str(at_door.get("id", "")), str(at_door.get("label", ""))])
	# --- 3. 客人到的时候主角正在柜台页里办另一位（地图还是当铺，世界层是藏起来的） ---
	town.player.teleport(Vector2(110, 72))
	await c.frames(2)
	var late_id := ""
	for id in town.visitors.present:
		if str(id).begins_with("story_"):
			late_id = str(id)        # 主线客人：等到宵禁前，不会因为耐心耗尽被撤
			break
	_check(late_id != "", "（前提）名单里有位主线客人")
	var late_walker = town.visitors.present[late_id]["walker"]
	late_walker.queue_free()
	town.visitors.present.erase(late_id)          # 让他“还没到”
	await c.frames(2)
	town._set_mode("counter")                      # 柜台页开着（等同于在接待别人）
	town.visitors.poll(town.minute)                # 点名：他到了
	_check(town.visitors.present.has(late_id), "柜台页开着的时候点名：他到了（进了名单）")
	_check(_bodies_ok() == "", "柜台页开着的时候到的客人：已经有身体、站在等候点（缺：%s）" % _bodies_ok())
	# 再把身体弄丢（换图、读档、没挂上……任何原因），回到走动状态的那一下要补回来
	var lost = town.visitors.present[late_id]["walker"]
	lost.get_parent().remove_child(lost)
	lost.queue_free()
	town.visitors.present[late_id]["walker"] = null
	_check(_bodies_ok() != "", "（前提）身体丢了")
	town._set_mode("town")
	await c.frames(2)
	await _wait_standing()
	_check(_bodies_ok() == "", "回到走动状态：身体补回来了（缺：%s）" % _bodies_ok())
	var nxt: Dictionary = town.visitors.next_ready()
	_check(not nxt.is_empty() and town.visitors.walker_of(str(nxt.get("id", ""))) != null, "补回来之后能接待")
	_check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
