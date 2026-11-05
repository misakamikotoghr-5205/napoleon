# 每种例子牌三种尺寸都能摆上，尺寸、整数倍插图、文字来源、没有百分号。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")

const MODES: Array[StringName] = [&"hand", &"zoom", &"mini"]
const EXPECTED := {&"hand": Vector2(144, 200), &"zoom": Vector2(288, 400), &"mini": Vector2(72, 100)}


func _initialize() -> void:
	var t := T.new(self, "C02_examples")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	S.setup_db()
	var rows: Array = S.examples()
	t.ok(rows.size() >= 16, "example count")
	var seen := {}
	for row in rows:
		seen[str(row.get("key", ""))] = true
		t.no_leaks(row.get("view", {}), str(row.get("key", "")))
	for key in ["person", "gold_person", "self", "contact", "event", "fate", "big_fate", "demand", "life",
			"news", "kept", "estate", "night", "street", "prison", "pawn_ticket"]:
		t.ok(seen.has(key), "missing " + key)
	var w := S.mount(self, {}, &"hand", Vector2(24, 24))
	await t.frames(1)
	for row in rows:
		var view: Dictionary = row["view"]
		for mode in MODES:
			w.set_size_mode(mode)
			w.set_card(view)
			t.eq(w.size, EXPECTED[mode], str(row["key"]) + " " + str(mode))
			t.eq(w.custom_minimum_size, EXPECTED[mode], str(row["key"]) + " min")
			var art := S.art(w)
			var base := S.art_base(view)
			var k := S.art_k(mode)
			t.eq(art.size, Vector2(base.x * k, base.y * k), str(row["key"]) + " art")
			t.eq(art.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, str(row["key"]) + " filter")
			var title := w.get_node("Title") as Label
			# 换皮（照网页原型）：牌名居中粗体，放不下先缩字（手牌 20/17/15、放大 24/20/17、小牌 14），
			# 原来固定 20 / 14 号又 clip_text，长牌名会被拦腰切掉（b43）。
			var sizes: Array = CardWidget.METRICS[mode]["title_px"]
			t.ok(sizes.has(title.get_theme_font_size("font_size")), str(row["key"]) + " title px")
			t.ok(title.get_theme_font_size("font_size") >= 14, str(row["key"]) + " title px >= 14")
			t.eq(title.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, str(row["key"]) + " title centred")
			t.ok(S.title_fits(w), str(row["key"]) + " " + str(mode) + " title fits (b43)")
			var band := w.get_node("Band") as Label
			t.ok(band.visible, str(row["key"]) + " type band")
			t.ok((w.get_node("Paper") as Control).visible, str(row["key"]) + " paper face")
			if CardText.is_draft(str(view.get("def", "")) + "#title"):
				t.ok(S.italic(title.get_theme_font("font")), str(row["key"]) + " italic")
				t.ok(title.get_theme_color("font_color").is_equal_approx(CardTheme.color(&"ink_soft")), str(row["key"]) + " ink")
			var bad: PackedStringArray = t.all_text_from_cardtext(w)
			t.ok(bad.is_empty(), str(row["key"]) + " text " + " ".join(bad))
			t.ok(not S.has_pct(w), str(row["key"]) + " pct")
	w.queue_free()
	await t.frames(1)
	# 小牌放进横排容器（kept_full / contacts_full 的列表，容器比牌高）：照小牌的尺寸画、不被拉伸、不互相压。
	var list := HBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size = Vector2(860, 140)
	root.add_child(list)
	for row in rows.slice(0, 4):
		var m: CardWidget = load("res://scenes/cards/card/CardWidget.tscn").instantiate()
		m.set_size_mode(&"mini")
		m.set_card(row["view"])
		list.add_child(m)
	await t.frames(2)
	var prev_end := -1.0
	for m in list.get_children():
		var c := m as CardWidget
		t.eq(c.size, EXPECTED[&"mini"], "mini in a container keeps 72x100")
		t.eq((c.get_node("Paper") as Control).size, EXPECTED[&"mini"], "mini face drawn at 72x100")
		t.ok(c.position.x >= prev_end, "mini cards do not overlap")
		prev_end = c.position.x + c.size.x
	list.queue_free()
	await t.frames(1)
