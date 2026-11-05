# C01 面板宿主：三路呈现、show、一次一个抽屉、next / open_uid / to_title / quit。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C01_host")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, "day_full")
	game.allow_quit = false
	await t.frames(2)
	var opened: Array = []
	var closed: Array = []
	bus.ui_event.connect(func(ev_name: StringName, args: Dictionary) -> void:
		if ev_name == &"panel_opened":
			opened.append(args.duplicate())
		elif ev_name == &"panel_closed":
			closed.append(args.duplicate())
	)
	var worst := 0
	var kinds := 0
	for kind in CardIds.PANELS:
		if kind == &"minigame":
			continue
		kinds += 1
		var t0 := Time.get_ticks_usec()
		var panel: CardPanel = game.host.open_panel(kind, {})
		var dt := Time.get_ticks_usec() - t0
		worst = maxi(worst, dt)
		var show := _expect_show(kind, panel)
		t.ok(panel != null, "open %s" % kind)
		t.eq(game.host.top_kind(), kind, "top is %s" % kind)
		t.eq(str(opened.back().get("show", "")), str(show), "%s show" % kind)
		t.ok(_layer_ok(game, panel, show), "%s layer" % kind)
		game.host.close_top()
		await t.frames(1)
	t.eq(opened.size(), kinds, "opened count")
	t.eq(closed.size(), kinds, "closed count")
	for i in kinds:
		t.eq(str(opened[i].get("kind", "")), str(closed[i].get("kind", "")), "pair %s" % opened[i].get("kind", ""))
		t.eq(str(opened[i].get("show", "")), str(closed[i].get("show", "")), "show pair %s" % opened[i].get("kind", ""))
	print("C01_PANEL_OPEN_US %d" % worst)
	# §12.4 开面板 ≤ 50 ms；真人面板的 open() 归各主人（help/dossier 可达数秒）。
	# #145：墙钟断言改稳——只卡宿主放置开销（实例化空面板 + shade + 入树，不算 panel.open）。
	# X01-b 起没有 W0 的 PanelStub，空面板用 CardPanel 基类本身。
	var place_samples: Array[int] = []
	for _i in 7:
		var t0 := Time.get_ticks_usec()
		var stub := CardPanel.new()
		stub.bind(game.engine, bus)
		var shade := ColorRect.new()
		shade.color = CardTheme.color(&"shade")
		shade.size = Vector2(1280, 720)
		game.host.add_child(shade)
		stub.position = CardLayout.OVERLAY_MAX.position
		stub.size = CardLayout.OVERLAY_MAX.size
		game.host.add_child(stub)
		place_samples.append(Time.get_ticks_usec() - t0)
		shade.queue_free()
		stub.queue_free()
		await t.frames(1)
	place_samples.sort()
	var place_us: int = place_samples[place_samples.size() >> 1]
	print("C01_PANEL_PLACE_US %d" % place_us)
	t.ok(place_us <= 50000, "panel place us %d" % place_us)
	await _one_drawer(t, game)
	await _conventions(t, game)
	game.queue_free()
	bus.queue_free()
	await t.frames(1)


func _one_drawer(t, game) -> void:
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	await t.frames(1)
	game.host.open_panel(&"shelf", {})
	game.host.open_panel(&"tickets", {})
	await t.frames(1)
	t.ok(not game.host.is_open(&"shelf"), "the previous drawer is gone")
	t.ok(game.host.is_open(&"tickets"), "one drawer stays")
	t.eq(game.host.top_kind(), &"tickets", "top is the new drawer")
	game.host.close_top()
	await t.frames(1)


func _conventions(t, game) -> void:
	# X01-b：没有 W0 的 PanelStub 了；没登记场景的 kind 什么都不开、返回 null、不报错，也不发指令。
	var sent: int = (game.engine as MockCardEngine).sent.size()
	var missing: CardPanel = game.host.open_panel(&"c01_missing", {"anything": 1})
	await t.frames(1)
	t.ok(missing == null, "unknown kind opens nothing")
	t.ok(not game.host.is_open(&"c01_missing") and game.host.top_panel() == null, "unknown kind leaves the host empty")
	t.eq((game.engine as MockCardEngine).sent.size(), sent, "unknown kind sends nothing")
	var help: CardPanel = game.host.open_panel(&"help", {})
	help.close_requested.emit({"next": {"kind": "pause", "args": {}}})
	await t.frames(2)
	t.eq(game.host.top_kind(), &"pause", "result.next opens pause")
	t.ok(not game.host.is_open(&"help"), "help closed before next")
	game.host.close_top()
	await t.frames(1)
	help = game.host.open_panel(&"help", {})
	help.close_requested.emit({"open_uid": "c0002"})
	await t.frames(2)
	var want := StringName(str(game.engine.query(&"card", {"uid": "c0002"}).get("panel", "")))
	t.eq(game.host.top_kind(), want, "result.open_uid opens the card panel")
	game.host.close_panel(game.host.top_panel())
	help = game.host.open_panel(&"help", {})
	help.close_requested.emit({"quit": true})
	await t.frames(2)
	t.ok(game.quit_requested, "result.quit requests quit")
	t.ok(not game.host.is_open(&"help"), "quit closed the panel")
	help = game.host.open_panel(&"help", {})
	help.close_requested.emit({"to_title": true})
	await t.frames(2)
	t.ok(is_instance_valid(game.title), "result.to_title shows the title")
	t.ok(game.host.top_panel() == null, "title has no panel")


func _expect_show(kind: StringName, panel: CardPanel) -> StringName:
	var declared: StringName = CardIds.PANEL_SHOW.get(kind, CardIds.SHOW_OVERLAY)
	if declared == CardIds.SHOW_STAGE and not (panel is CardStagePanel):
		return CardIds.SHOW_OVERLAY
	if declared == CardIds.SHOW_HOST:
		return CardIds.SHOW_OVERLAY
	return declared


func _layer_ok(game, panel: CardPanel, show: StringName) -> bool:
	var parent := panel.get_parent()
	if show == CardIds.SHOW_OVERLAY:
		return parent == game.host
	if show == CardIds.SHOW_DRAWER_L or show == CardIds.SHOW_DRAWER_R:
		# 抽屉面板挂在 ModalHost 下，方便各面板 _find_host()；框仍由 DrawerHost 画。
		return parent == game.host and game.host.drawer_open()
	if show == CardIds.SHOW_STAGE:
		return parent != null and str(parent.name) == "PlayLayer"
	return false
