# C10：牌桌上没有面板、开着柜台/格子/轮盘/夜/档案、开着小游戏时，F1 开帮助，再按 F1 或 Esc 关。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C10/support.gd")
const LINES: Array = ["c10.help.title", "c10.help.keys.f1", "c10.help.keys.esc", "c10.help.keys.enter",
	"c10.help.keys.space", "c10.help.keys.tab", "c10.help.keys.num", "c10.help.day_flow"]

func _initialize() -> void:
	var t := T.new(self, "C10_help_keys")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _standalone(t)
	var game := _boot("day_full")
	await t.frames(3)
	var spy = t.spy(game.bus)
	for close_key in [KEY_F1, KEY_ESCAPE]:
		await _case(t, game, spy, "", "", close_key)
		await _case(t, game, spy, "counter", "counter", close_key)
		await _case(t, game, spy, "slots", "slots", close_key)
		await _case(t, game, spy, "wheel", "wheel", close_key)
		await _case(t, game, spy, "night", "night", close_key)
		await _case(t, game, spy, "dossier", "dossier", close_key)
		await _case(t, game, spy, "minigame", "spot", close_key)
	_drop(game)
	await t.frames(2)


func _standalone(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture("day_full")
	var p: CardHelpPanel = load("res://scenes/cards/dossier/HelpPanel.tscn").instantiate()
	p.bind(mock, bus)
	root.add_child(p)
	var t0 := Time.get_ticks_usec()
	p.open({"uid": "c0002"})
	print("C10 help_open_us " + str(Time.get_ticks_usec() - t0))
	await t.frames(2)
	_lines(t, p)
	var on_tab := S.find_meta(p, &"c10_tab", "controls") as Button
	t.ok(on_tab.get_theme_color("font_color") == CardTheme.color(&"btn_primary_ink"), "b49 help active tab dark ink")
	var on_box := on_tab.get_theme_stylebox("normal") as StyleBoxFlat
	t.ok(on_box != null and on_box.bg_color.get_luminance() > 0.45, "b49 help active tab has a bright fill")
	t.eq(t.all_text_from_cardtext(p), PackedStringArray(), "help text from CardText")
	t.ok(not S.has_percent(p), "help has no percent")
	t.ok(t.anchor_ok(&"a.help.rules"), "a.help.rules")
	var got: Array = []
	p.close_requested.connect(func(r: Dictionary) -> void: got.append(r))
	t.ok(p.autoplay_step(), "help autoplay first")
	t.eq(got, [{}], "help autoplay closes")
	t.ok(not p.autoplay_step(), "help autoplay second")
	p.queue_free()
	bus.queue_free()
	await t.frames(1)


func _case(t, game: CardGameRoot, spy, label: String, kind: String, close_key: Key) -> void:
	_clear(game)
	if game.mg_host.is_active():
		game.mg_host.current.abort()
		await t.frames(2)
	if kind == "spot":
		game.bus.minigame_requested.emit("c0002", "", &"spot", {})
		await t.frames(1)
		t.ok(game.mg_host.is_active(), "minigame is up")
	elif kind == "wheel":
		game.host.open_panel(&"wheel", {"wheel": "wh.month"})
	elif kind != "":
		game.host.open_panel(StringName(kind), {})
		await t.frames(1)
		t.ok(game.host.is_open(StringName(kind)), label + " is open")
	spy.clear()
	await S.tap(t.tree, KEY_F1)
	t.eq(String(game.host.top_kind()), "help", "F1 opens help over " + label)
	t.eq(_help_names(spy), ["panel_opened"], "panel_opened help over " + label)
	if label == "" and close_key == KEY_F1:
		_lines(t, game.host.top_panel())
	spy.clear()
	await S.tap(t.tree, close_key)
	t.ok(not game.host.is_open(&"help"), "help closes over " + label)
	t.eq(_help_names(spy), ["panel_closed"], "panel_closed help over " + label)
	if kind != "" and kind != "spot":
		t.ok(game.host.is_open(StringName(kind)), label + " stays under help")
	if kind == "spot":
		t.ok(game.mg_host.is_active(), "minigame stays after help closes")


func _lines(t, panel: Node) -> void:
	var body := panel.find_child("HelpBody", true, false)
	var seen: Array = []
	for c in body.get_children():
		if c is Label and c.has_meta(&"c10_help_key"):
			var key := str(c.get_meta(&"c10_help_key"))
			seen.append(key)
			t.eq((c as Label).text, CardText.ui(key), "controls line " + key)
	t.eq(seen, LINES, "controls page is c10.help.*")


func _help_names(spy) -> Array:
	var out: Array = []
	for ev in spy.ui_events():
		if typeof(ev[1]) != TYPE_DICTIONARY:
			continue
		if str(ev[1].get("kind", "")) != "help":
			continue
		var name := str(ev[0])
		if name == "panel_opened" or name == "panel_closed":
			out.append(name)
	return out


func _clear(game: CardGameRoot) -> void:
	while game.host.top_panel() != null:
		game.host.close_top()


func _boot(fixture: String) -> CardGameRoot:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true, "bus": bus, "fixture": fixture, "skip_title": true, "guide": "off"})
	root.add_child(game)
	return game


func _drop(game: CardGameRoot) -> void:
	var bus := game.bus
	game.queue_free()
	if bus != null:
		bus.queue_free()
