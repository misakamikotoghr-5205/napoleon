# C09 month-open: background scale, intro lines, three goals, wheel after close.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C09/c09_support.gd")
const SCENE := "res://scenes/cards/month/MonthOpen.tscn"
const FX := "res://scripts/tests/cards/C09/fixtures/month_open_three.json"


func _initialize() -> void:
	var t := T.new(self, "C09_month_open")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_sources(t)
	var stage := S.stage_1938()
	var paras := int(stage.get("intro_paras", 0))
	var art := str(stage.get("bg", ""))
	var brief := str(stage.get("brief", ""))
	var pack := S.mount(self, FX)
	var p := S.open_panel(self, pack, SCENE) as CardMonthOpen
	p.open({"uid": "c0002"})
	p.refresh(pack["mock"].view())
	await t.frames(1)
	var bg := p.find_child("Bg", true, false) as TextureRect
	t.ok(bg != null, "background node")
	t.eq(str(bg.get_meta("art_id", "")), art, "background art id")
	t.eq(bg.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "nearest filter")
	var base := CardArt.base_size(art)
	t.ok(base.x > 0 and base.y > 0, "stage background has a base size")
	t.eq(bg.size, Vector2(base.x * 4, base.y * 4), "background is an integer x4")
	t.eq(int(bg.get_meta("scale", 0)), 4, "scale meta is 4")
	var para_root := p.find_child("Paras", true, false)
	t.eq(para_root.get_child_count(), paras, "paragraph count matches intro_paras")
	for i in paras:
		var lab := p.find_child("P%d" % [i + 1], true, false) as Label
		var ref := "stage.1938#intro.p%d" % [i + 1]
		t.eq(lab.text, CardText.t(ref), "paragraph %d from CardText" % [i + 1])
		t.ok(lab.text != brief, "stage brief is not shown on its own")
	t.ok(not (p.find_child("P1", true, false) as CanvasItem).visible or paras > 0, "first line exists")
	t.ok((p.find_child("P1", true, false) as CanvasItem).visible, "first paragraph starts visible")
	if paras > 1:
		t.ok(not (p.find_child("P2", true, false) as CanvasItem).visible, "later paragraphs wait")
	if not CardSettings.fast_anim():
		t.eq((p.find_child("P1", true, false) as CanvasItem).modulate.a, 0.0, "paragraph fades in unless fast_anim is on")
	S.tap(p, KEY_SPACE)
	if paras > 1:
		t.ok((p.find_child("P2", true, false) as CanvasItem).visible, "space shows the next paragraph")
	S.tap(p, KEY_ENTER)
	var guard := 0
	while not S.goals_visible(p) and guard < 8:
		S.tap(p, KEY_SPACE)
		guard += 1
	t.ok(S.goals_visible(p), "goals page is showing")
	await t.frames(1)
	t.ok(t.anchor_ok(&"a.month.goals"), "goals anchor %s" % CardAnchors.rect(&"a.month.goals"))
	var goals := p.find_child("Goals", true, false)
	var rows: Array = []
	var mains := 0
	for c in goals.get_children():
		if c.has_meta("goal_id"):
			rows.append(c)
			if bool(c.get_meta("main")):
				mains += 1
				t.ok(S.blob(c).contains(CardText.ui("c09.goals.main")), "main goal is marked")
			else:
				t.ok(not S.blob(c).contains(CardText.ui("c09.goals.main")), "optional goal is not marked main")
	t.eq(rows.size(), 3, "three goals")
	t.eq(mains, 1, "one main goal")
	t.ok(S.blob(p).contains(CardText.ui("c09.goals.title")), "goals heading")
	t.ok(t.all_text_from_cardtext(p).is_empty(), "text from CardText: %s" % ", ".join(t.all_text_from_cardtext(p)))
	t.ok(not S.has_percent(p), "no percent sign")
	t.no_leaks(pack["mock"].view(), "month open view")
	var got := [false]
	p.close_requested.connect(func(_r: Dictionary) -> void: got[0] = true)
	S.tap(p, KEY_ESCAPE)
	t.ok(got[0], "escape on the goals page closes")
	t.eq(S.count_cmd(pack["mock"], "month.begin"), 0, "the interlude does not send month.begin")
	_escape_early(t)
	_timed_open(t, pack)
	_autoplay_same(t)
	await _wheel(t)
	await _goals_click(t)


func _sources(t) -> void:
	var cjk := RegEx.create_from_string("[\\x{3000}-\\x{9fff}\\x{ff00}-\\x{ffef}]")
	var paths := [
		"res://scripts/cards/ui/month/month_ui.gd",
		"res://scripts/cards/ui/month/month_open.gd",
		"res://scripts/cards/ui/month/month_close.gd",
		"res://scripts/cards/ui/month/year_jump_panel.gd",
		"res://scripts/cards/ui/month/game_over.gd",
		"res://scenes/cards/month/MonthOpen.tscn",
		"res://scenes/cards/month/MonthClose.tscn",
		"res://scenes/cards/month/YearJump.tscn",
		"res://scenes/cards/month/GameOver.tscn",
	]
	for path in paths:
		var text := FileAccess.get_file_as_string(path)
		t.ok(cjk.search(text) == null, "ASCII only: " + path)
		t.ok(not text.contains("w0_stub"), "no w0 stub: " + path)
		t.ok(not text.contains("Color(") or text.contains("Color(1, 1, 1, 0)"), "colors: " + path)


func _escape_early(t) -> void:
	var pack := S.mount(self, FX)
	var p := S.open_panel(self, pack, SCENE)
	var result := [{"missing": true}]
	p.close_requested.connect(func(r: Dictionary) -> void: result[0] = r)
	p.dismiss()
	t.eq(result[0], {}, "dismiss during the interlude closes without a title return")
	t.eq(S.count_cmd(pack["mock"], "month.begin"), 0, "early close sends no command")
	var pack2 := S.mount(self, FX)
	var p2 := S.open_panel(self, pack2, SCENE)
	var escaped := [{"missing": true}]
	p2.close_requested.connect(func(r: Dictionary) -> void: escaped[0] = r)
	S.tap(p2, KEY_ESCAPE)
	t.eq(escaped[0], {}, "escape during the interlude closes")
	t.eq(S.count_cmd(pack2["mock"], "month.begin"), 0, "escape during the interlude sends no command")


func _timed_open(t, pack: Dictionary) -> void:
	CardTheme.font_title()
	CardTheme.font_body()
	ThemeDB.get_default_theme().default_font = CardTheme.font_body()
	CardArt.texture("bg.stage.1938")
	var p: CardMonthOpen = load(SCENE).instantiate()
	p.bind(pack["mock"], pack["bus"])
	root.add_child(p)
	p.open({})
	var samples: Array = []
	for _i in 5:
		for c in p.get_children():
			p.remove_child(c)
			c.free()
		var t0 := Time.get_ticks_usec()
		p.open({})
		samples.append(Time.get_ticks_usec() - t0)
	samples.sort()
	var us: int = int(samples[samples.size() / 2])
	print("C09 month_open open_us ", us)
	t.ok(us < 50000, "month open builds within 50ms (%d us)" % us)


func _autoplay_same(t) -> void:
	var a := S.mount(self, FX)
	var b := S.mount(self, FX)
	var pa := S.open_panel(self, a, SCENE)
	var pb := S.open_panel(self, b, SCENE)
	t.eq(S.drain(pa), S.drain(pb), "autoplay step count is stable")
	t.eq(a["mock"].sent, b["mock"].sent, "autoplay sends the same commands")
	t.eq(S.count_cmd(a["mock"], "month.begin"), 0, "autoplay does not begin the month")


func _wheel(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var opened: Array = []
	bus.ui_event.connect(func(n: StringName, a: Dictionary) -> void:
		if n == &"panel_opened":
			opened.append(str(a.get("kind", "")))
	)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": true,
		"bus": bus,
		"fixture": "month_open",
		"skip_title": true,
		"guide": "off",
		"settings_path": t.user_dir() + "/settings.json",
	})
	root.add_child(game)
	await t.frames(3)
	t.eq(game.host.top_kind(), &"month_open", "host opens the interlude first")
	var guard := 0
	while game.host.top_kind() == &"month_open" and guard < 12:
		var top := game.host.top_panel()
		if top == null or not top.autoplay_step():
			break
		guard += 1
		await t.frames(1)
	await t.frames(2)
	t.ok(opened.has("wheel"), "after the interlude, C01 opens the wheel")
	t.ok(game.host.is_open(&"wheel"), "wheel panel is up")


## b30: on the goals page a mouse click on the goal list begins (the list used to swallow the click), and the
## gold begin button keeps its own size instead of stretching across the band.
func _goals_click(t) -> void:
	var pack := S.mount(self, FX)
	var p := S.open_panel(self, pack, SCENE) as CardMonthOpen
	p.refresh(pack["mock"].view())
	var guard := 0
	while not S.goals_visible(p) and guard < 8:
		S.tap(p, KEY_SPACE)
		guard += 1
	await t.frames(2)
	var begin := p.find_child("Begin", true, false) as Button
	t.ok(begin.size.x < 400.0, "begin is not stretched (%s)" % begin.size)
	var row: Control = null
	for c in p.find_child("Goals", true, false).get_children():
		if c.has_meta("goal_id"):
			row = c
			break
	t.ok(row != null, "a goal row")
	var got := [false]
	p.close_requested.connect(func(_r: Dictionary) -> void: got[0] = true)
	var at := row.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	root.push_input(move, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		root.push_input(click, true)
	await t.frames(1)
	t.ok(got[0], "a click on the goal list begins")
	p.queue_free()
	await t.frames(1)
