# 覆盖层：照网页原型的一个纸气泡（教的人头像 + 名字 + 换行的整句话 + 知道了/关掉指引），
# 只有那两个按钮吃鼠标、其余穿透，没有输入回调；气泡在画面内、不压住锚点和看得见的按钮（按钮审计 b47），
# 字不被截；教的人站在 GUIDE_TEACHER（博古格上有物件时不站）；气泡避开开着的抽屉、盘账叠层上不出别处的指引；
# “知道了（还有 N 条）”与“关掉指引”；挑步骤耗时；空闲不分配对象。
# 主人 C16。合同：docs/cards/CARDS_INTERFACES.md §7.10.7（主创 10-22：照网页原型）、§12.4。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fake = preload("res://scripts/tests/cards/C16/fake_engine.gd")


func _initialize() -> void:
	var t := T.new(self, "C16_guide_overlay")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	CardText.setup(CardDB.load_all())
	_scan_input(t)
	await _bubble(t)
	await _teachers(t)
	await _queue_and_ack(t)
	await _off_button(t)
	await _avoid_buttons(t)
	await _drawer_and_stocktake(t)
	await _speed(t)
	await _idle(t)
	await t.frames(2)


func _scan_input(t) -> void:
	var src := FileAccess.get_file_as_string("res://scripts/cards/ui/shell/card_guide.gd")
	for name in ["_input", "_unhandled_input", "_gui_input", "_unhandled_key_input"]:
		t.ok(not src.contains("func " + name), "guide has no " + name)


func _bubble(t) -> void:
	var ctx = await _open(t, [_step("gd.d1.deal", "brother", "a.hand")])
	ctx.guide.evaluate_now()
	await t.frames(2)
	_walk_mouse(t, ctx.guide)
	var bubble: Control = ctx.guide.get_node("Chrome/Bubble")
	var br := bubble.get_global_rect()
	var ar := CardAnchors.rect(&"a.hand")
	t.ok(bubble.is_visible_in_tree(), "bubble is visible")
	t.ok(Rect2(0, 0, 1280, 720).encloses(br), "bubble stays inside 1280x720")
	t.ok(not br.intersects(ar), "bubble does not cover the anchor")
	t.eq(br.size.x, 520.0, "bubble is the prototype's 520 wide")
	var text: Label = ctx.guide.get_node("Chrome/Bubble/Text")
	t.eq(text.text, CardText.t("gd.d1.deal#say"), "the whole line (say) is in the bubble")
	t.ok(text.text != "", "the line has text")
	t.eq(text.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "the line wraps")
	t.eq(text.get_visible_line_count(), text.get_line_count(), "no line of the text is cut off")
	t.ok(text.get_global_rect().end.y <= br.end.y and text.get_global_rect().end.x <= br.end.x, "text sits inside the bubble")
	var who: Label = ctx.guide.get_node("Chrome/Bubble/Who")
	t.eq(who.text, CardText.ui("c16.guide.who.brother"), "the bubble names who is talking")
	var ok: Button = ctx.guide.get_node("Chrome/Bubble/Ok")
	var off: Button = ctx.guide.get_node("Chrome/Bubble/Off")
	t.eq(ok.text, CardText.ui("c16.guide.ok"), "got-it button with nothing queued")
	t.eq(off.text, CardText.ui("c16.guide.off"), "turn-off button")
	t.ok(br.encloses(ok.get_global_rect()) and br.encloses(off.get_global_rect()), "both buttons sit inside the bubble")
	t.ok(not ok.get_global_rect().intersects(off.get_global_rect()), "the two buttons do not overlap")
	_free(ctx)


func _teachers(t) -> void:
	await _teacher(t, "brother", "portrait.brother", true, true)
	await _teacher(t, "obj.notice", "icon.obj.notice", true, false)
	await _teacher(t, "", "", false, false)
	# Rogue v1: the teacher spot covers the curio shelf, so he does not stand there once a relic is on it.
	await _teacher(t, "brother", "portrait.brother", true, false, 1)


func _teacher(t, who: String, art: String, show: bool, stands: bool, relics: int = 0) -> void:
	var ctx = await _open(t, [_step("who", who, "a.hand")])
	if relics > 0:
		ctx.eng.view_d["relics"] = {"cap": 6, "count": relics, "dormant": false, "held": []}
	ctx.guide.evaluate_now()
	await t.frames(1)
	var pic: TextureRect = ctx.guide.get_node("Chrome/Bubble/Art")
	t.eq(pic.visible, show, "portrait in the bubble for " + who)
	t.eq(str(pic.get_meta("art_id", "")), art, "art id for " + who)
	if show and pic.texture != null:
		var px := pic.size / pic.texture.get_size()
		t.ok(is_equal_approx(px.x, roundf(px.x)) and is_equal_approx(px.x, px.y), "portrait at a whole-pixel scale for " + who)
	var stand: TextureRect = ctx.guide.get_node("Chrome/Teacher")
	t.eq(stand.visible, stands, "teacher stands at the counter side for %s (%d relics)" % [who, relics])
	if stands:
		t.eq(Rect2(stand.position, stand.size), CardLayout.GUIDE_TEACHER, "teacher at GUIDE_TEACHER")
	_free(ctx)


## Several steps at once: one bubble, the rest wait; "got it (N more)" counts them; got it shows the next.
func _queue_and_ack(t) -> void:
	var a := _step("a", "brother", "a.hand")
	a["priority"] = 80
	var b := _step("b", "brother", "a.hand")
	b["priority"] = 70
	var ctx = await _open(t, [a, b])
	ctx.guide.evaluate_now()
	await t.frames(1)
	t.eq(ctx.guide.active_step(), "a", "first step shows")
	var ok: Button = ctx.guide.get_node("Chrome/Bubble/Ok")
	t.eq(ok.text, CardText.ui("c16.guide.ok_more", {"n": 1}), "got it shows how many more wait")
	t.ok(ok.mouse_filter == Control.MOUSE_FILTER_STOP and ok.focus_mode == Control.FOCUS_NONE, "got it takes clicks, never focus")
	ok.pressed.emit()
	t.eq(ctx.guide.active_step(), "", "got it closes the bubble")
	ctx.guide.tick(0.5)
	t.eq(ctx.guide.active_step(), "b", "the next waiting step follows")
	t.eq(ok.text, CardText.ui("c16.guide.ok"), "last one: plain got it")
	await t.frames(1)
	var done := false
	for row in ctx.eng.sent:
		if str(row[0]) == "ui.guide" and str(row[1].get("step", "")) == "a" and str(row[1].get("status", "")) == "done":
			done = true
	t.ok(done, "got it sends ui.guide done")
	_free(ctx)


func _off_button(t) -> void:
	var ctx = await _open(t, [_step("a", "brother", "a.hand")])
	ctx.guide.set_cmdline("on")
	ctx.guide._forced = -1
	ctx.guide.evaluate_now()
	await t.frames(1)
	t.eq(ctx.guide.active_step(), "a", "step shows")
	var off: Button = ctx.guide.get_node("Chrome/Bubble/Off")
	off.pressed.emit()
	t.eq(ctx.guide.active_step(), "", "turn-off hides the bubble at once")
	t.eq(ctx.guide.is_enabled(), false, "turn-off beats --guide=on")
	var flash: Control = ctx.guide.get_node("Flash")
	t.ok(flash.visible, "a line says where to turn it back on")
	t.eq((flash.get_node("Line") as Label).text, CardText.ui("c16.guide.off_flash"), "off line text")
	ctx.guide.evaluate_now()
	t.eq(ctx.guide.active_step(), "", "stays off")
	_free(ctx)


## Button audit b47: the bubble keeps off visible buttons (here a button on the prototype spot).
func _avoid_buttons(t) -> void:
	var ctx = await _open(t, [_step("a", "brother", "a.hand")])
	var btn := Button.new()
	btn.position = Vector2(520, 420)
	btn.size = Vector2(240, 60)
	ctx.holder.add_child(btn)
	await t.frames(1)
	ctx.guide.evaluate_now()
	await t.frames(2)
	var br: Rect2 = ctx.guide.get_node("Chrome/Bubble").get_global_rect()
	t.ok(not br.intersects(btn.get_global_rect()), "bubble does not cover a visible button")
	t.ok(not br.intersects(CardAnchors.rect(&"a.hand")), "and still not the anchor")
	_free(ctx)


## Rogue v1: an open side drawer (the relics drawer, drawer_r) is kept clear like a panel; while the stocktake overlay
## is up, a hint on an anchor that is not the overlay's own waits until it closes.
func _drawer_and_stocktake(t) -> void:
	var ctx = await _open(t, [_step("a", "zhouma", "a.hand")])
	ctx.bus.ui_event.emit(&"panel_opened", {"kind": "relics"})
	ctx.guide.evaluate_now()
	await t.frames(2)
	t.eq(ctx.guide.active_step(), "a", "a hand hint shows next to the relics drawer")
	var br: Rect2 = ctx.guide.get_node("Chrome/Bubble").get_global_rect()
	t.ok(not br.intersects(CardLayout.DRAWER_R), "the bubble keeps off the open drawer " + str(br))
	_free(ctx)
	ctx = await _open(t, [_step("b", "hu2", "a.demand.tier")])
	var tier := ColorRect.new()
	tier.position = Vector2(40, 200)
	tier.size = Vector2(60, 60)
	tier.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctx.holder.add_child(tier)
	CardAnchors.register(&"a.demand.tier", tier)
	ctx.bus.ui_event.emit(&"panel_opened", {"kind": "stocktake"})
	ctx.guide.evaluate_now()
	await t.frames(1)
	t.eq(ctx.guide.active_step(), "", "stocktake overlay up: a hint on another anchor waits")
	ctx.bus.ui_event.emit(&"panel_closed", {"kind": "stocktake"})
	ctx.guide.evaluate_now()
	await t.frames(1)
	t.eq(ctx.guide.active_step(), "b", "and shows once the overlay closes")
	_free(ctx)


func _speed(t) -> void:
	var steps: Array = []
	for i in 70:
		steps.append({
			"id": "s" + str(i), "teacher": "", "anchor": "a.scene.notice", "anchor_fallback": "",
			"trigger": {"first": "m" + str(i)}, "done_when": ["timeout"],
			"priority": 50, "max_shows": 2, "seconds": 30, "interrupt": false,
		})
	steps[0]["anchor"] = "a.hand"
	var ctx = await _open(t, steps)
	for i in 70:
		ctx.bus.first_time.emit(StringName("m" + str(i)), {})
	ctx.guide.evaluate_now()
	var samples: Array = []
	for _n in 5:
		ctx.guide.evaluate_now()
		var t0 := Time.get_ticks_usec()
		ctx.guide.evaluate_now()
		var us := int(Time.get_ticks_usec() - t0)
		samples.append(us)
	samples.sort()
	var pick_us: int = int(samples[samples.size() / 2])
	print("C16_pick_us " + str(pick_us))
	t.ok(pick_us <= 1000, "pick among 70 steps is within 1 ms (" + str(pick_us) + " us)")
	_free(ctx)


func _idle(t) -> void:
	var ctx = await _open(t, [])
	ctx.guide.skip_fades = false
	ctx.guide.set_process(true)
	ctx.guide.force(true)
	await t.frames(8)
	var before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	await t.frames(60)
	var after := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	print("C16_idle_delta " + str(after - before))
	t.eq(after, before, "idle frames do not allocate objects")
	_free(ctx)


func _step(id: String, teacher: String, anchor: String) -> Dictionary:
	return {
		"id": id, "teacher": teacher, "anchor": anchor, "anchor_fallback": "",
		"trigger": {}, "done_when": ["ui:never"],
		"priority": 50, "max_shows": 2, "seconds": 0, "interrupt": false,
	}


## Everything ignores the mouse except the bubble's two buttons (contract 7.10.7, 10-22 prototype note).
func _walk_mouse(t, n: Node) -> void:
	if n is BaseButton:
		t.ok(n.name in ["Ok", "Off"], n.name + " is one of the two bubble buttons")
		t.eq((n as Control).mouse_filter, Control.MOUSE_FILTER_STOP, n.name + " takes the click")
		t.eq((n as Control).focus_mode, Control.FOCUS_NONE, n.name + " never takes key focus")
	elif n is Control:
		t.eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, n.name + " ignores the mouse")
	for c in n.get_children():
		_walk_mouse(t, c)


func _open(t, steps: Array):
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng = Fake.new()
	var rules = CardDB.read_json("res://data/cards/rules/guide.json")
	eng.data = {"steps": steps, "settings": rules if typeof(rules) == TYPE_DICTIONARY else {}}
	eng.view_d = {"phase": "day", "mode": "shop", "date": {"stage": 0, "stage_day": 1, "abs_day": 1}, "hand": []}
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var hand := ColorRect.new()
	hand.color = CardTheme.color(&"paper")
	hand.position = Vector2(380, 540)
	hand.size = Vector2(620, 170)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(hand)
	CardAnchors.register(&"a.hand", hand)
	var guide: CardGuide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.skip_fades = true
	guide.set_process(false)
	holder.add_child(guide)
	guide.bind(eng, bus)
	guide.load_steps(eng.data)
	guide.force(true)
	await t.frames(1)
	return {"guide": guide, "bus": bus, "eng": eng, "holder": holder}


func _free(ctx) -> void:
	ctx.holder.queue_free()
	ctx.bus.queue_free()
	CardAnchors.clear()
