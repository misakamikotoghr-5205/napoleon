# 手牌扇：引擎顺序、扇形公式、悬停抬起、set_low / set_away、选中放大、打出、夜里睡了。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")
const CARD := Vector2(144, 200)
const CENTER_X := 690.0
const REST_TOP := 544.0
const HOVER_TOP := 380.0
const AWAY_TOP := 760.0
const LOW_DY := 56.0


func _initialize() -> void:
	var t := T.new(self, "C02_fan")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	S.setup_db()
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var fan: CardHandFan = load("res://scenes/cards/card/HandFan.tscn").instantiate()
	fan.bus = bus
	# 换皮：抬起 / 下沉 / 滑走都有补间（0.18 / 0.4 秒）；快动画直接到位，下面的位置断言照旧。补间另测（_tweens）。
	fan.fast_anim = true
	root.add_child(fan)
	var played: Array = []
	fan.card_played.connect(func(uid: String, def_id: String, how: StringName) -> void:
		played.append([uid, def_id, how]))
	await t.frames(1)
	var doc := S.read_json("res://scripts/tests/cards/C02/fixtures/fan_15.json")
	t.no_leaks(doc, "fan fixture")
	fan.refresh(doc)
	await t.frames(1)
	var slots := _slots(fan)
	var cards: Array = []
	cards.append_array(doc["hand"])
	cards.append_array(doc["kept"])
	t.eq(slots.size(), 15, "15 cards")
	t.ok(bool(cards[0].get("gold", false)), "gold is first")
	t.eq(str(cards[0].get("zone", "")), "hand", "gold stays in hand order")
	for i in 5:
		t.eq(str(cards[10 + i].get("zone", "")), "kept", "kept follows hand")
	for i in slots.size():
		var spot := _place(i, slots.size(), false, false, false)
		var slot: Control = slots[i]
		t.ok(_near(slot.position, spot["pos"]), "place %d" % i)
		t.ok(is_equal_approx(slot.rotation_degrees, float(spot["rot"])), "rot %d" % i)
		t.ok(slot.position.x >= 371.5, "left of band %d" % i)
		t.ok(slot.position.x + CARD.x <= 1008.5, "right of band %d" % i)
		var face := slot.get_node("Face") as CardWidget
		t.eq(face.size, CARD, "hand size %d" % i)
		var badge := face.get_node("KeptBadge") as Label
		t.eq(badge.visible, i >= 10, "kept badge %d" % i)
	t.ok(t.anchor_ok(&"a.hand"), "a.hand")
	t.ok(t.anchor_ok(&"a.hand.gold"), "a.hand.gold")
	t.ok(t.anchor_ok(&"a.hand.kept"), "a.hand.kept")
	var bad: PackedStringArray = t.all_text_from_cardtext(fan)
	t.ok(bad.is_empty(), "fan text " + " ".join(bad))
	t.ok(not S.has_pct(fan), "no pct")
	slots[4].mouse_entered.emit()
	var hovered := _place(4, slots.size(), false, false, true)
	t.ok(_near(slots[4].position, hovered["pos"]), "hover lifts to 380")
	t.ok(is_equal_approx(slots[4].rotation_degrees, 0.0), "hover rotation 0")
	# 换皮 / b13：悬停的牌靠树里的先后放到最上（点击也先到它），不再抬 z_index（b02：z 会把手牌画到叠层上面）。
	t.ok(_last_slot(fan, slots) == slots[4], "hover on top (last in tree order)")
	t.ok(_max_z(fan) <= 150, "hand z_index stays <= 150 (b02)")
	t.ok((slots[4].get_node("Face/Hi") as Control).visible, "hover shows the focus ring")
	slots[4].mouse_exited.emit()
	var back := _place(4, slots.size(), false, false, false)
	t.ok(_near(slots[4].position, back["pos"]), "hover ends")
	await t.frames(1)
	t.ok(_tree_order_ok(slots), "tree order restored after hover")
	fan.set_low(true)
	var lowered := _place(2, slots.size(), true, false, false)
	t.ok(_near(slots[2].position, lowered["pos"]), "set_low adds 56")
	slots[2].mouse_entered.emit()
	var low_hover := _place(2, slots.size(), true, false, true)
	t.ok(_near(slots[2].position, low_hover["pos"]), "hover while low")
	slots[2].mouse_exited.emit()
	fan.set_low(false)
	fan.set_away(true)
	t.ok(is_equal_approx(slots[1].position.y, AWAY_TOP), "set_away")
	t.ok(not (fan.get_node("Preview") as Control).visible, "away hides preview")
	fan.set_away(false)
	spy.clear()
	fan.select_index(3)
	var uid3 := str(cards[3].get("uid", ""))
	t.eq(_ui(spy, &"hand_selected"), {"uid": uid3}, "hand_selected")
	t.eq(_ui(spy, &"card_zoomed"), {"uid": uid3}, "card_zoomed")
	var preview := fan.get_node("Preview") as CardWidget
	t.ok(preview.visible, "preview shown")
	t.eq(preview.size, Vector2(288, 400), "preview is zoom size")
	t.ok(_near(preview.position, CardLayout.PREVIEW_CARD.position), "preview at PREVIEW_CARD")
	t.ok(t.anchor_ok(&"a.hand.preview"), "a.hand.preview")
	_preview_checks(t, fan, cards[3])
	fan.select_index(0)
	t.ok(not (fan.get_node("PreviewButtons/KeepSide") as Button).visible, "gold has no keep")
	fan.select_index(1)
	t.ok((fan.get_node("PreviewButtons/KeepSide") as Button).visible, "keepable shows keep")
	var got: Array = []
	(slots[1].get_node("Face") as CardWidget).action_requested.connect(
		func(uid: String, act: String) -> void: got.append([uid, act]))
	(fan.get_node("PreviewButtons/KeepSide") as Button).pressed.emit()
	t.eq(got, [[str(cards[1].get("uid", "")), "keep"]], "preview keep")
	played.clear()
	spy.clear()
	(fan.get_node("PreviewButtons/Play") as Button).pressed.emit()
	t.eq(played[0][2], &"button", "play button how")
	t.eq(_ui(spy, &"hand_played").get("how", ""), "button", "hand_played button")
	t.ok(not (fan.get_node("PreviewButtons") as Control).visible, "preview closes after play")
	fan.select_index(1)
	played.clear()
	spy.clear()
	t.ok(fan.play_selected(), "enter plays")
	t.eq(played[0][2], &"key", "enter how")
	t.eq(_ui(spy, &"hand_played").get("how", ""), "key", "hand_played key")
	played.clear()
	spy.clear()
	var uid2 := str(cards[2].get("uid", ""))
	t.ok(fan.play_uid(uid2), "play_uid")
	t.eq(played[0][0], uid2, "play_uid card")
	t.eq(played[0][2], &"auto", "auto how")
	t.eq(_ui(spy, &"hand_played").get("how", ""), "auto", "hand_played auto")
	t.eq(_ui(spy, &"hand_played").get("def", ""), str(cards[2].get("def", "")), "hand_played def")
	played.clear()
	spy.clear()
	var drag: Dictionary = slots[2]._get_drag_data(Vector2(8, 8))
	t.eq(drag, {"kind": "card", "uid": uid2, "zone": "hand"}, "drag data")
	t.eq(_ui(spy, &"card_drag_started"), {"uid": uid2, "zone": "hand"}, "drag event")
	t.ok((fan.get_node("DropHint") as Label).text == "" or not (fan.get_node("DropHint") as Label).visible,
		"no drop hint without a real drag")
	# NOTIFICATION_DRAG_END 每个节点都收到：只有被拖的那张出牌。
	for s in slots:
		(s as Control).notification(Control.NOTIFICATION_DRAG_END)
	t.eq(played.size(), 1, "drag plays")
	t.eq(played[0][2], &"drag", "drag how")
	t.eq(played[0][0], uid2, "only the dragged card plays")
	t.eq(_ui(spy, &"hand_played").get("how", ""), "drag", "hand_played drag")
	played.clear()
	for s in slots:
		(s as Control).notification(Control.NOTIFICATION_DRAG_END)
	t.eq(played.size(), 0, "a drag that did not start in the fan plays nothing")
	(fan.get_node("PreviewButtons/Back") as Button).pressed.emit()
	t.ok(not preview.visible, "back hides preview")
	t.ok(not fan.play_selected(), "back clears selection")
	fan.refresh({"phase": "settle", "hand": doc["hand"]})
	await t.frames(1)
	t.eq(_slots(fan).size(), 0, "other phases are empty")
	var night := S.read_json("res://scripts/tests/cards/C02/fixtures/fan_night.json")
	fan.refresh(night)
	await t.frames(1)
	var night_slots := _slots(fan)
	t.eq(night_slots.size(), 4, "offers plus sleep")
	var defs: Array = []
	for i in night_slots.size():
		played.clear()
		fan.select_index(i)
		fan.play_selected()
		defs.append(played[0][1])
	t.eq(defs, ["nw.a", "nw.b", "nw.c", ""], "night order and empty sleep def")
	var sleep_title := (night_slots[3].get_node("Face") as CardWidget).get_node("Title") as Label
	t.eq(sleep_title.text, CardText.ui("c02.night.none"), "sleep label")
	fan.select_index(3)
	t.eq((fan.get_node("PreviewButtons/Play") as Button).text, CardText.ui("c02.night.none"), "sleep play text")
	fan.select_index(0)
	t.eq((fan.get_node("PreviewButtons/Play") as Button).text, CardText.ui("c02.btn.play.night"), "night play text")
	fan.refresh({"phase": "day", "hand": [], "kept": []})
	await t.frames(1)
	var note := fan.get_node("HandNote") as Label
	t.ok(note.visible and note.text == CardText.ui("c02.hand.empty_done"), "empty hand note")
	await _real_input(t, fan, doc)
	await _wide_hand(t, fan)
	await _tweens(t, fan, doc)
	fan.queue_free()
	bus.free()
	await t.frames(1)


## 选中预览（换皮）：托盘、按钮是主题变体、看得清（b11）；按钮和托盘都不挡账簿热点（b42）。
func _preview_checks(t, fan: CardHandFan, card: Dictionary) -> void:
	var play := fan.get_node("PreviewButtons/Play") as Button
	var back := fan.get_node("PreviewButtons/Back") as Button
	t.eq(play.theme_type_variation, &"PrimaryButton", "play is a primary button")
	var want := "c02.btn.play.person" if str(card.get("type", "")) == "person" else "c02.btn.play.other"
	t.eq(play.text, CardText.ui(want), "play text follows the card")
	for b in [play, back]:
		var btn := b as Button
		var sb := btn.get_theme_stylebox("normal") as StyleBoxFlat
		t.ok(sb != null and sb.bg_color.a >= 0.9, btn.name + " has an opaque box (b11)")
		if sb != null:
			var ink := btn.get_theme_color("font_color")
			t.ok(absf(ink.get_luminance() - sb.bg_color.get_luminance()) >= 0.35, btn.name + " text readable (b11)")
			var font := btn.get_theme_font("font")
			var text_w := font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1, btn.get_theme_font_size("font_size")).x
			t.ok(text_w + sb.content_margin_left + sb.content_margin_right <= btn.size.x + 0.5, btn.name + " text fits")
	var ledger: Rect2 = CardLayout.HOTSPOTS[&"ledger"]
	t.ok(not CardLayout.PREVIEW_BTNS.intersects(ledger), "PREVIEW_BTNS clear of the ledger (b42)")
	for b in [play, back, fan.get_node("PreviewButtons/KeepSide")]:
		t.ok(not (b as Control).get_global_rect().intersects(ledger), str((b as Node).name) + " clear of the ledger (b42)")
	var tray = fan.preview_tray()
	t.ok(tray != null and (tray as Control).visible, "preview tray shown")
	for p in [ledger.get_center(), ledger.position + Vector2(2, 2), Vector2(ledger.position.x + 2, ledger.end.y - 2)]:
		t.ok(not tray.covers(p), "tray leaves the ledger free (b42)")
	t.ok(tray.covers(CardLayout.PREVIEW_CARD.get_center()), "tray behind the zoomed card")
	t.ok(tray.covers(play.get_global_rect().get_center()), "tray behind the buttons")
	t.ok(fan.get_node("Tray").get_index() < fan.get_node("Preview").get_index(), "tray under the zoomed card")
	# QA 10-25: the prototype draws #preview over the whole #hand, so the selected card lifted under the
	# mouse no longer covers the zoomed card's text; the tray takes the clicks inside its L shape only.
	var tray_i: int = fan.get_node("Tray").get_index()
	var under := true
	for s in fan.get("_slots"):
		if (s as Node).get_index() > tray_i:
			under = false
	t.ok(under, "hand cards draw under the preview tray")
	t.eq((tray as Control).mouse_filter, Control.MOUSE_FILTER_STOP, "the tray takes the clicks it covers")
	t.ok(not (tray as Control)._has_point(ledger.get_center() - (tray as Control).position), "tray hit area leaves the ledger free (b42)")
	t.ok(_max_z(fan) <= 150, "preview z_index stays <= 150 (b02)")
	# 每种牌的主按钮字（打出 · 请进门 / 打出 · 就办这件 / 打出）都放得进按钮列。
	var keep_sel: int = fan.get("_selected")
	var cards: Array = fan.get("_cards")
	for i in cards.size():
		fan.select_index(i)
		var f := play.get_theme_font("font")
		var sbp := play.get_theme_stylebox("normal") as StyleBoxFlat
		var w := f.get_string_size(play.text, HORIZONTAL_ALIGNMENT_LEFT, -1, play.get_theme_font_size("font_size")).x
		t.ok(w + sbp.content_margin_left + sbp.content_margin_right <= play.size.x + 0.5, "play text fits for card %d" % i)
	fan.select_index(keep_sel)


## 真鼠标（push_input）：b13 抬起的牌右下角压着右边的牌，点下去选中的还是它；b14 牌上的“留着”在屏幕里、不被压。
func _real_input(t, fan: CardHandFan, doc: Dictionary) -> void:
	var small := {"phase": "day", "hand": (doc["hand"] as Array).slice(0, 5), "kept": []}
	fan.refresh(small)
	await t.frames(1)
	var slots := _slots(fan)
	await _move(Vector2(640, 100))
	var strip: Vector2 = (slots[1] as Control).get_global_transform_with_canvas() * Vector2(20, 100)
	await _move(strip)
	t.eq(fan.get("_hover"), 1, "real hover lifts card 1")
	var lifted := slots[1] as Control
	var corner := lifted.get_global_transform_with_canvas() * Vector2(CARD.x - 8, CARD.y - 10)
	var neighbour := slots[2] as Control
	var local: Vector2 = neighbour.get_global_transform_with_canvas().affine_inverse() * corner
	t.ok(Rect2(Vector2.ZERO, CARD).has_point(local), "the lifted corner overlaps the right neighbour")
	await _move(corner)
	t.eq(root.gui_get_hovered_control(), lifted, "lifted card keeps the mouse over its corner (b13)")
	t.eq(fan.get("_hover"), 1, "hover stays on the lifted card (b13)")
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = corner
		ev.global_position = corner
		root.push_input(ev, true)
		await process_frame
	t.eq(fan.get("_selected"), 1, "click on the lifted corner selects the lifted card (b13)")
	(fan.get_node("PreviewButtons/Back") as Button).pressed.emit()
	await _move(Vector2(640, 100))
	t.eq(fan.get("_hover"), -1, "hover cleared")
	var news := {"uid": "kn", "def": "nw.x", "type": "news", "zone": "hand", "gold": false, "art": "",
		"actions": [{"id": "keep", "enabled": true, "reason_key": ""}]}
	for n in [3, 6, 12]:
		var hand: Array = []
		for i in n:
			var c: Dictionary = news.duplicate(true)
			c["uid"] = "kn%d" % i
			hand.append(c)
		fan.refresh({"phase": "day", "hand": hand, "kept": []})
		await t.frames(1)
		var ss := _slots(fan)
		for i in ss.size():
			var keep := (ss[i] as Control).get_node("Face/Keep") as Button
			var c_local := keep.position + keep.size * 0.5
			var at: Vector2 = (ss[i] as Control).get_global_transform_with_canvas() * c_local
			t.ok(CardLayout.SCREEN.has_point(at), "keep chip on screen (b14) n=%d i=%d" % [n, i])
			var covered := false
			for j in range(i + 1, ss.size()):
				var lp: Vector2 = (ss[j] as Control).get_global_transform_with_canvas().affine_inverse() * at
				if Rect2(Vector2.ZERO, CARD).has_point(lp):
					covered = true
			t.ok(not covered, "keep chip not covered by the next card (b14) n=%d i=%d" % [n, i])


## 试玩反馈：手里 20 张牌时，鼠标指着一张牌露出来的那一条的左边，它抬起摆正、往右挪，鼠标落到左边那张上，
## 悬停和点击都变成了邻牌。抬起的牌还认原位露出来的那一条：悬停留在它身上，点下去选中的也是它。
func _wide_hand(t, fan: CardHandFan) -> void:
	var news := {"uid": "w", "def": "nw.x", "type": "news", "zone": "hand", "gold": false, "art": "",
		"actions": [{"id": "keep", "enabled": true, "reason_key": ""}]}
	var hand: Array = []
	for i in 20:
		var c: Dictionary = news.duplicate(true)
		c["uid"] = "w%d" % i
		hand.append(c)
	for fast in [true, false]:
		fan.fast_anim = fast
		fan.set("_fast_setting", false)
		fan.refresh({"phase": "day", "hand": hand, "kept": []})
		await t.frames(1)
		await _move(Vector2(640, 100))
		await create_timer(0.3).timeout
		var ss := _slots(fan)
		for idx in [1, 7, 12]:
			var slot := ss[idx] as Control
			# 露出来的那一条的左边缘附近（没抬起时的摆法），正是试玩里点不中的位置
			var at: Vector2 = slot.get_global_transform_with_canvas() * Vector2(4, 80)
			await _move(at)
			await create_timer(0.25).timeout
			await _move(at + Vector2(0, 0.5))
			await _move(at)
			t.eq(fan.get("_hover"), idx, "wide hand (fast=%s): hover stays on card %d after it lifts" % [fast, idx])
			t.eq(root.gui_get_hovered_control(), slot, "wide hand (fast=%s): the lifted card %d keeps the mouse" % [fast, idx])
			for down in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.pressed = down
				ev.position = at
				ev.global_position = at
				root.push_input(ev, true)
				await process_frame
			t.eq(fan.get("_selected"), idx, "wide hand (fast=%s): the click selects card %d, not its neighbour" % [fast, idx])
			(fan.get_node("PreviewButtons/Back") as Button).pressed.emit()
			await _move(Vector2(640, 100))
			await create_timer(0.25).timeout
		# 往左挪进左边那张露出来的那一条，悬停换过去（不会一直粘在抬起的牌上）
		var s3 := ss[3] as Control
		var p3: Vector2 = s3.get_global_transform_with_canvas() * Vector2(6, 120)
		await _move(p3)
		await create_timer(0.25).timeout
		var s2 := ss[2] as Control
		var p2: Vector2 = s2.get_global_transform_with_canvas() * Vector2(6, 120)
		await _move(p2)
		await create_timer(0.25).timeout
		await _move(p2 + Vector2(0, 0.5))
		t.eq(fan.get("_hover"), 2, "wide hand (fast=%s): moving left onto the neighbour's strip hovers the neighbour" % fast)
		await _move(Vector2(640, 100))
		await create_timer(0.25).timeout
	fan.fast_anim = true


## 补间：快动画关掉时抬起要 0.18 秒走到位，滑走 0.4 秒并淡出。
func _tweens(t, fan: CardHandFan, doc: Dictionary) -> void:
	fan.fast_anim = false
	fan.refresh({"phase": "day", "hand": (doc["hand"] as Array).slice(0, 4), "kept": []})
	fan.set("_fast_setting", false)
	await t.frames(1)
	var slots := _slots(fan)
	var target: Dictionary = _place(2, slots.size(), false, false, true)
	slots[2].mouse_entered.emit()
	await t.frames(1)
	t.ok(not _near(slots[2].position, target["pos"]), "hover lift is animated")
	await create_timer(0.3).timeout
	t.ok(_near(slots[2].position, target["pos"]), "hover lift reaches 380")
	slots[2].mouse_exited.emit()
	fan.set_away(true)
	await create_timer(0.5).timeout
	t.ok(is_equal_approx(slots[1].position.y, AWAY_TOP), "away slide reaches the bottom")
	t.ok(slots[1].modulate.a < 0.05, "away fades out")
	fan.set_away(false)
	fan.fast_anim = true


func _move(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv, true)
	await process_frame
	await process_frame


func _last_slot(fan: Node, slots: Array) -> Node:
	var best: Node = null
	for s in slots:
		if best == null or (s as Node).get_index() > best.get_index():
			best = s
	return best if fan != null else null


func _tree_order_ok(slots: Array) -> bool:
	for i in range(1, slots.size()):
		if (slots[i] as Node).get_index() <= (slots[i - 1] as Node).get_index():
			return false
	return true


func _max_z(node: Node) -> int:
	var best := 0
	if node is CanvasItem:
		best = (node as CanvasItem).z_index
	for c in node.get_children():
		best = maxi(best, _max_z(c))
	return best


func _slots(fan: Node) -> Array:
	var out: Array = []
	for c in fan.get_children():
		if str(c.name).begins_with("FanCard"):
			out.append(c)
	out.sort_custom(func(a: Node, b: Node) -> bool:
		return int(str(a.name).trim_prefix("FanCard")) < int(str(b.name).trim_prefix("FanCard")))
	return out


func _place(i: int, n: int, low: bool, away: bool, hover: bool) -> Dictionary:
	var spacing := 0.0
	if n > 1:
		spacing = minf(115.0, 492.0 / float(n - 1))
	var mid := float(n - 1) * 0.5
	var denom := maxf(1.0, mid)
	var tv := (float(i) - mid) / denom
	var angle := tv * minf(6.0, 2.0 + 1.2 * float(n))
	var top := REST_TOP + float(roundi(16.0 * tv * tv))
	if hover and not away:
		top = HOVER_TOP
		angle = 0.0
	if low and not away:
		top += LOW_DY
	if away:
		top = AWAY_TOP
	var cx := CENTER_X + (float(i) - mid) * spacing
	return {"pos": Vector2(cx - CARD.x * 0.5, top), "rot": angle}


func _near(a: Vector2, b: Vector2) -> bool:
	return is_equal_approx(a.x, b.x) and is_equal_approx(a.y, b.y)


func _ui(spy, ev_name: StringName) -> Dictionary:
	for row in spy.ui_events():
		if row[0] == ev_name:
			return row[1]
	return {}
