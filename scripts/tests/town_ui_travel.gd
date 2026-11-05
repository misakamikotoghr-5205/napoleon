# 去哪儿：当铺门口打开地图（人不出街）；点开着的店传送并来回耗时；0 分钟可写在数据里；
# 关着的地方灰着且不去；店里能看见日程上在那儿的人；桥头碰见是一小段对话。
# godot --headless -s res://scripts/tests/town_ui_travel.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const Travel = preload("res://scripts/town/travel.gd")

var c

func _initialize() -> void:
	_run()

func _notes() -> String:
	var out := ""
	for e in c.town.world.notebook:
		out += str(e.get("text", "")) + "\n"
	return out

func _toast() -> String:
	var out := ""
	for t in c.town.overlay._toast_box.get_children():
		out += (t as Label).text
	for q in c.town.overlay._toast_queue:
		out += str(q.get("text", ""))
	return out

func _run() -> void:
	c = Common.new(self)
	await c.boot(9)
	var town = c.town
	town.seconds_per_minute = 100000.0
	town.skip_to(600)
	c.check(town.map_id == "pawnshop", "人在当铺里")
	var cfg := Travel.config()
	var rice_saved = cfg["places"]["ricehall"]["minutes"]
	var post_saved = cfg["places"]["post"]["minutes"]
	cfg["places"]["post"].erase("minutes")
	var fallback := Travel.minutes_for("post", town.curfew)
	c.check(fallback >= 5 and fallback <= 15, "没写分钟数时按路段夹在 5–15（邮电局 %d）" % fallback)
	cfg["places"]["post"]["minutes"] = 0
	c.check(Travel.minutes_for("post", town.curfew) == 0, "数据写成 0 就是不花时间")
	cfg["places"]["post"]["minutes"] = post_saved
	cfg["places"]["ricehall"]["minutes"] = rice_saved
	town.open_travel_map()
	await c.frames(4)
	c.check(town.travel_panel != null and town.map_id == "pawnshop", "门口打开去哪儿，地图还是当铺")
	c.check(town._modal_depth > 0, "地图开着，钟停")
	c.check(town.guide.ui_override == "travel", "引导盖在 travel 上")
	c.check(town.guide.travel_anchors.has("ricehall") and town.guide.travel_anchors.has("_map"), "米行和整张图都登记了锚点")
	var legend: String = town.travel_panel.legend.text
	c.check(str(town.travel_panel.lines["ricehall"]).find("来回各 5 分钟") >= 0, "地图上写着米行来回各 5 分钟（%s）" % str(town.travel_panel.lines["ricehall"]))
	c.check(legend.find("济生堂") >= 0 and legend.find("字条") >= 0, "没开门的济生堂写着原因")
	c.check(legend.find("码头") >= 0 and legend.find("没有你的事") >= 0, "没有店面的码头去不了，写明原因")
	c.check(legend.find("概率") < 0, "地图上不写概率")
	var m0: int = town.minute
	cfg["meet_chance"] = 0.0
	cfg["places"]["teahouse"]["minutes"] = 0
	town.dismiss_modals()
	await c.until_idle()
	await town.travel_to("teahouse")
	await c.until(func(): return town.shop_view.is_open, 600)
	c.check(town.shop_view.is_open and town.map_id == "pawnshop", "0 分钟也能进茶馆特写，人不到街上")
	c.check(town.minute == m0, "数据为 0：去的时候钟不走（%d）" % town.minute)
	town.shop_view.close_shop()
	await c.until_idle()
	c.check(town.minute == m0 and town.map_id == "pawnshop", "回来也不花时间，人在铺子里")
	cfg["places"]["teahouse"]["minutes"] = 5
	cfg["meet_chance"] = 1.0
	var notes0 := _notes()
	await town.travel_to("ricehall")
	await c.until(func(): return town.shop_view.is_open, 600)
	c.check(town.shop_view.building_id == "ricehall" and town.map_id == "pawnshop", "点米行：进了米行特写")
	c.check(town.minute >= m0 + 5, "去米行花了数据里的分钟（%d → %d）" % [m0, town.minute])
	var met := _notes()
	c.check(met != notes0 and (met.find("小丁") >= 0 or met.find("张慧娟") >= 0 or met.find("桥头") >= 0), "上午桥头有人，路上碰上说了几句")
	var at_shop: int = town.minute
	town.shop_view.close_shop()
	await c.until_idle()
	c.check(town.minute >= at_shop + 5 and town.map_id == "pawnshop", "从米行回来再花一趟时间")
	var m1: int = town.minute
	var toast0 := _toast()
	await town.travel_to("pharmacy")
	await c.frames(4)
	c.check(not town.shop_view.is_open and town.minute == m1, "济生堂还关着：人不走，钟不走")
	c.check(_toast() != toast0 and _toast().find("济生堂") >= 0, "关着的原因说给你听")
	town.skip_to(900)
	await town.travel_to("teahouse")
	await c.until(func(): return town.shop_view.is_open, 600)
	c.check(town.shop_view.here_lbl.visible and town.shop_view.here_lbl.text.find("张") >= 0, "下午茶馆里能看见张慧娟（%s）" % town.shop_view.here_lbl.text)
	var labels := ""
	for b in town.shop_view.menu_box.get_children():
		if b is Button:
			labels += (b as Button).text
	c.check(labels.find("张") >= 0, "能和店里的人说话")
	town.shop_view.close_shop()
	await c.until_idle()
	cfg["meet_chance"] = 0.35
	print("RESULT: ", "OK" if c.failures == 0 else "FAILED (%d)" % c.failures)
	var code: int = 0 if c.failures == 0 else 1
	await c.shutdown()
	quit(code)
