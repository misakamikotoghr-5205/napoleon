# 小镇界面（b）：每家开着的店都能进特写、看到掌柜和菜单、买东西、回街上；关着/锁着的店只弹提示。
# godot --headless -s res://scripts/tests/town_ui_shops.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")

var c

func _initialize() -> void:
	_run()

func _run() -> void:
	c = Common.new(self)
	await c.boot(12)
	var town = c.town
	town.seconds_per_minute = 100000.0
	# 把后来才开的店先开了（解锁条件由 T04 管，这里只测界面）
	for b in ["pharmacy", "baogong", "post", "market"]:
		town.world.town.s["unlocked"][b] = true
	town.world.town.s["flags_today"]["market_day"] = true
	town.skip_to(600)
	await town.goto("ricehall")
	for bid in ["teahouse", "ricehall", "pharmacy", "baogong", "post", "market"]:
		var state: String = town.world.town.building_state(bid)
		c.check(state == "open", "%s 眼下开着（%s）" % [bid, state])
		await town.open_shop(bid)
		await c.until(func(): return town.shop_view.is_open, 120)
		var sv = town.shop_view
		c.check(sv.is_open and town.mode == "closeup", "%s：进入特写模式" % bid)
		c.check(c.main.mode == "closeup" and not c.main.scene_holder.visible, "%s：main 切到特写，柜台层隐藏" % bid)
		c.check(sv.bg.texture != null and sv.bg.texture.get_size() == Vector2(320, 180), "%s：背景是 320×180" % bid)
		c.check(sv.keeper_rect.texture != null, "%s：有掌柜立绘" % bid)
		c.check(sv._full != "", "%s：掌柜有招呼语" % bid)
		c.check(sv.menu_box.get_child_count() >= 3, "%s：菜单有 %d 项" % [bid, sv.menu_box.get_child_count()])
		sv.close_shop()
		await c.until_idle()
		c.check(town.mode == "town" and town.map_id == "town" and not sv.visible, "%s：出店回到街上" % bid)
	# 买米：钱少、米多，进家用库存
	await town.open_shop("ricehall")
	var home_before: Dictionary = town.household().duplicate()
	var cash_before: int = town.world.cash()
	var r: Dictionary = town.shop_view.buy("rice", 2)
	c.check(r.get("ok", false), "买米成功")
	c.check(town.household()["rice"] == int(home_before["rice"]) + 2 or int(town.director.town_action("household")["household"]["rice"]) == int(home_before["rice"]) + 2, "米缸多了 2 份")
	c.check(town.world.cash() < cash_before, "钱匣少了：%d → %d" % [cash_before, town.world.cash()])
	c.check(town.world.ledger.check_invariants().is_empty(), "账本不变量没破")
	c.check(town.hud.cash_lbl.text.begins_with(str(town.world.cash())), "HUD 钱数跟着变")
	# 菜单里补上柴炭、灯油（米行）
	var labels: Array = []
	for b in town.shop_view.menu_box.get_children():
		labels.append((b as Button).text)
	c.check(str(labels).find("柴炭") >= 0 and str(labels).find("灯油") >= 0, "米行菜单里能买柴炭和灯油")
	var r2: Dictionary = town.shop_view.buy("fuel", 1)
	c.check(r2.get("ok", false), "买柴炭成功")
	# 付账：没有到期的账时只说一句，不动钱
	var cash2: int = town.world.cash()
	town.shop_view.pay("")
	c.check(town.world.cash() == cash2 or town.world.cash() < cash2, "付账不会凭空多钱")
	town.shop_view.close_shop()
	await c.until_idle()
	# 关门的店：夜里 22:00 茶馆已打烊，只弹提示
	town.skip_to(1330)
	var n_before: int = town.overlay._toast_box.get_child_count() + town.overlay._toast_queue.size()
	await town.open_shop("ricehall")
	c.check(town.mode == "town" and not town.shop_view.is_open, "打烊的米行进不去")
	c.check(town.overlay._toast_box.get_child_count() + town.overlay._toast_queue.size() > n_before, "打烊时说明了一句")
	print("RESULT: ", "OK" if c.failures == 0 else "FAILED (%d)" % c.failures)
	var code: int = 0 if c.failures == 0 else 1
	await c.shutdown()
	quit(code)
