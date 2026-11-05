# C01 配色键、牌框、以及自己的脚本和场景里没有中文串、没有颜色字面量。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const KEYS: Array[String] = ["paper", "paper_old", "ink", "ink_soft", "wood", "wood_mid", "wood_dark", "lamp",
	"seal", "gold", "gold_glow", "jade", "indigo", "mist", "good", "danger", "shade", "frame_person",
	"frame_self", "frame_contact", "frame_event", "frame_fate", "frame_big_fate", "frame_demand", "frame_life",
	"frame_news", "frame_kept", "frame_estate", "frame_night", "frame_street", "frame_prison", "frame_gold",
	"guide_glow", "guide_bubble", "guide_ink", "scene_void", "hud_bg", "hud_ink", "dialog_bg", "dialog_ink",
	"dialog_name", "dialog_me", "dialog_sys", "reply_bg", "reply_hover", "reply_ink", "reply_off", "tab_bg",
	"tab_on", "drawer_bg", "drawer_ink", "scrim", "btn_day", "btn_day_ready", "btn_day_confirm", "btn_day_night",
	"btn_day_ink", "night_tint", "night_dark", "candle_tint", "cold_tint", "warm_tint", "predawn", "lamp_glow",
	"rain", "fire_glow", "smoke", "seal_paper", "silhouette", "hero_ring", "guide_note"]
# Reskin keys (SPEC 3.2-3.3, 10-22 web prototype look): the dev palette has them, palette.json must too.
const RESKIN_KEYS: Array[String] = ["wood_0", "wood_3", "line", "umber", "text_2", "text_3", "gold_hi", "gold_pale",
	"gold_deep", "seal_dark", "seal_rim", "focus", "bad", "warn", "almanac_yi", "almanac_ji", "money_up", "money_down",
	"hud_bg_low", "hud_rule", "btn_top", "btn_bot", "btn_hover_top", "btn_edge", "btn_shadow", "btn_primary_top",
	"btn_primary_bot", "btn_primary_hover_top", "btn_primary_hover_bot", "btn_primary_edge", "btn_primary_ink",
	"btn_warn_top", "btn_warn_bot", "btn_warn_edge", "modal_top", "modal_bot", "modal_edge", "card_face_top",
	"card_face_bot", "card_gold_top", "card_gold_bot", "card_bigfate_top", "card_bigfate_bot", "card_prison_top",
	"card_prison_bot", "card_kept_top", "card_kept_bot", "card_night_top", "card_night_bot", "card_night_ink",
	"card_night_sub", "card_band_ink", "card_sub_ink", "card_well", "card_well_line", "card_hilite", "card_shadow",
	"card_band_gold", "frame_fate_bad", "ribbon_ink", "days_plate", "days_ink", "btn_day_hi", "btn_day_lo",
	"btn_day_ready_hi", "btn_day_ready_lo", "btn_day_confirm_hi", "btn_day_confirm_lo", "btn_day_night_hi",
	"btn_day_night_lo", "btn_day_edge", "btn_day_sub", "btn_day_ready_sub", "btn_day_light_ink", "btn_day_light_sub",
	"btn_day_night_ink", "btn_day_night_sub", "btn_day_ring", "btn_day_ready_glow", "hero_top", "hero_bot", "hero_edge",
	"mate_top", "mate_bot", "pstate_bg", "slot_bg", "slot_full", "slot_edge", "slot_over", "guide_edge",
	"guide_note_edge", "guide_who", "guide_hl_gold", "guide_hl_red", "flash_bg", "flash_edge", "flash_bad_edge",
	"flash_bad_ink", "tool_glow", "drop_ring", "drop_bg", "title_shadow", "title_glow", "wheel_good_a", "wheel_good_b",
	"wheel_mid_a", "wheel_mid_b", "wheel_bad_a", "wheel_bad_b", "dialog_narr", "reply_look", "wood_1", "wood_2",
	"ink_3", "book_top", "book_bot", "book_edge", "ledger_in", "modal_shadow", "btn_warn_ink"]
const TYPES: Array[String] = ["person", "self", "contact", "event", "fate", "big_fate", "demand", "life", "news",
	"kept", "estate", "night", "street", "prison", "pawn_ticket"]


func _initialize() -> void:
	var t := T.new(self, "C01_theme")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for k in KEYS:
		# 缺键不再返回洋红（退回 mist），所以直接查键在不在。
		t.ok(CardTheme._has(StringName(k)), "palette " + k)
	for k in RESKIN_KEYS:
		t.ok(CardTheme._has(StringName(k)), "reskin palette " + k)
	await _check_reskin_api(t)
	for ty in TYPES:
		t.ok(CardTheme.frame_style(StringName(ty), false) is StyleBox, "frame " + ty)
		t.ok(CardTheme.frame_style(StringName(ty), true) is StyleBox, "gold frame " + ty)
	t.eq(CardTheme.font_size(&"min"), 14, "min size")
	t.eq(CardTheme.font_size(&"body"), 16, "body size")
	t.eq(CardTheme.font_size(&"card"), 20, "card size")
	t.eq(CardTheme.font_size(&"title"), 32, "title size")
	t.eq(CardTheme.font_size(&"hud"), 15, "hud size")
	t.eq(CardTheme.font_size(&"reply"), 17, "reply size")
	t.eq(CardTheme.font_size(&"name"), 22, "name size")
	t.ok(CardTheme.panel_style() is StyleBox, "panel style")
	t.ok(CardTheme.font_title() != null and CardTheme.font_body() != null, "fonts")
	for path in _gd_files():
		var src := FileAccess.get_file_as_string(path)
		for lit in _strings(src):
			t.ok(not _cjk(lit), path + " cjk string")
		t.ok(not _strip(src).contains("Color("), path + " color literal")
	for path in _tscn_files():
		t.ok(not _cjk(FileAccess.get_file_as_string(path)), path + " tscn cjk")
	await t.frames(1)


## Reskin foundation (SPEC 4): the theme, its variations and the shared styles other components build on.
func _check_reskin_api(t) -> void:
	var th := CardTheme.build_theme()
	t.ok(th is Theme and th.default_font == CardTheme.font_body() and th.default_font_size == 16, "theme font")
	t.ok(th.get_color(&"font_color", &"Label").is_equal_approx(CardTheme.color(&"hud_ink")), "label is light ink")
	for v in ["PrimaryButton", "SmallButton", "BigButton", "PrimaryBigButton", "WarnButton", "ReplyButton",
			"TabButton", "TabButtonR", "SkipButton"]:
		var base: StringName = &"PrimaryButton" if v == "PrimaryBigButton" else &"Button"
		t.ok(th.is_type_variation(StringName(v), base), "button variation " + v)
		t.ok(th.has_stylebox(&"normal", StringName(v)), "variation has a normal box " + v)
	for v in ["InkLabel", "NoteLabel", "HintLabel", "ModalTitle", "ModalHeading", "PaperTitle"]:
		t.ok(th.is_type_variation(StringName(v), &"Label"), "label variation " + v)
	for v in ["ModalPanel", "PaperBook", "PaperCard", "RowNote"]:
		t.ok(th.is_type_variation(StringName(v), &"PanelContainer"), "panel variation " + v)
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.ok(th.get_stylebox(StringName(s), &"Button") is StyleBoxFlat, "button state " + s)
	t.ok(th.has_stylebox(&"panel", &"PanelContainer") and th.has_stylebox(&"grabber", &"VScrollBar"), "panel and scrollbar")
	t.ok(th.has_stylebox(&"normal", &"LineEdit") and th.has_stylebox(&"normal", &"CheckBox"), "line edit and check box")
	var bold := CardTheme.font_body_bold()
	t.ok(bold is FontVariation and (bold as FontVariation).variation_embolden > 0.0, "bold body font")
	t.ok(CardTheme.font_body_bold() == bold, "bold font is cached")
	var modal := CardTheme.modal_style()
	t.ok(modal is StyleBox and modal.content_margin_left >= 14.0 and modal.content_margin_top >= 14.0, "modal style")
	var nine := CardTheme.nine_box("frame.dialog", 2, false)
	t.ok(nine is StyleBoxTexture, "dev build nine box uses the frame art")
	if nine is StyleBoxTexture:
		var tex := (nine as StyleBoxTexture).texture
		t.eq(tex.get_size(), Vector2(96, 96), "frame.dialog scaled x2 with nearest")
		t.eq((nine as StyleBoxTexture).texture_margin_left, 14.0, "nine margin x2")
		t.ok(not (nine as StyleBoxTexture).draw_center, "nine box center off")
		t.ok(CardTheme.nine_box("frame.dialog", 2, true).texture == tex, "scaled frame texture is cached")
	var nb := CardTheme.nine_box("frame.nope", 2, true)
	t.ok(nb is StyleBox, "missing art still gives a box")
	t.ok(CardTheme.paper_book_style() is StyleBoxFlat and CardTheme.paper_card_style() is StyleBoxFlat, "paper styles")
	var note := CardTheme.row_note_style()
	t.eq(note.border_width_left, 3, "note bar width")
	t.eq(note.border_width_right, 0, "note bar only on the left")
	t.ok(CardTheme.tab_style("l", false).border_width_left == 0 and CardTheme.tab_style("r", true).border_width_right == 0,
		"tab plates open on the screen side")
	var g := CardTheme.grad_box(&"card_face_top", &"card_face_bot", &"frame_person", 3.0, 9.0, false)
	t.ok(g is Control and g.material is ShaderMaterial, "grad box")
	root.add_child(g)
	g.size = Vector2(144, 200)
	await t.frames(1)
	var mat := g.material as ShaderMaterial
	t.eq(mat.get_shader_parameter(&"size_px"), Vector2(144, 200), "grad box size follows the control")
	t.ok((mat.get_shader_parameter(&"color_top") as Color).is_equal_approx(CardTheme.color(&"card_face_top")), "grad top")
	t.eq(mat.get_shader_parameter(&"border_px"), 3.0, "grad border")
	g.queue_free()


func _gd_files() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := "res://scripts/cards/ui/table"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	out.append("res://scripts/cards/ui/common/card_theme.gd")
	out.append("res://scripts/cards/ui/common/grad_box.gd")
	return out


func _tscn_files() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("res://scenes/cards/CardGame.tscn")
	var dir := "res://scenes/cards/table"
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	return out


func _cjk(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x3400 and c <= 0x9FFF:
			return true
	return false


func _strings(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var i := 0
	var n := src.length()
	while i < n:
		var c := src.unicode_at(i)
		if c == 35:
			while i < n and src.unicode_at(i) != 10:
				i += 1
			continue
		if c == 34:
			i += 1
			var start := i
			while i < n and src.unicode_at(i) != 34:
				if src.unicode_at(i) == 92:
					i += 2
					continue
				i += 1
			out.append(src.substr(start, i - start))
			i += 1
			continue
		i += 1
	return out


func _strip(src: String) -> String:
	var out := ""
	var i := 0
	var n := src.length()
	while i < n:
		var c := src.unicode_at(i)
		if c == 35:
			while i < n and src.unicode_at(i) != 10:
				i += 1
			continue
		if c == 34:
			i += 1
			while i < n and src.unicode_at(i) != 34:
				if src.unicode_at(i) == 92:
					i += 2
					continue
				i += 1
			i += 1
			continue
		out += src.substr(i, 1)
		i += 1
	return out
