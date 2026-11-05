# 金色、红点、剩几天、生活牌角标、人脉离开、灰态、草稿、留着按钮、背面、乱参数。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C02_states")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var db := S.setup_db()
	var states := S.states()
	var w := S.mount(self, states["draft"], &"hand", Vector2(32, 32))
	await t.frames(1)
	_show(w, states["gold"])
	# 换皮（照网页原型 .card）：九宫格牌框图不再画在牌上（中心透明 → 人物牌透明，b12；24px 粗边直角，和原型差太远）。
	# 牌面是 Paper 渐变块（纸色上下两色 + 3px 牌种色边 + 圆角），FrameFlat 垫在下面画外影、兼做不透明的底。
	var nine := w.get_node("FrameNine") as NinePatchRect
	var flat := w.get_node("FrameFlat") as Panel
	t.ok(not nine.visible, "nine-patch frame art is not drawn on the card")
	t.ok(flat.visible, "gold frame visible")
	var sb := flat.get_theme_stylebox("panel") as StyleBoxFlat
	t.ok(sb.border_color.is_equal_approx(CardTheme.color(&"frame_gold")), "gold border")
	t.eq(sb.get_border_width(SIDE_LEFT), 3, "border 3px like the prototype")
	t.eq(sb.corner_radius_top_left, 9, "rounded corners 9")
	t.ok(sb.shadow_size > 0 and sb.shadow_offset.y > 0, "card drop shadow")
	t.ok(is_equal_approx(sb.bg_color.a, 1.0), "opaque face under the gradient")
	t.ok((w.get_node("Paper") as Control).visible, "gradient paper face")
	t.ok((w.get_node("RibbonMask/Ribbon") as Label).is_visible_in_tree(), "gold ribbon")
	t.eq((w.get_node("RibbonMask/Ribbon") as Label).text, CardText.ui("c02.ribbon.gold"), "ribbon text")
	t.eq((w.get_node("Band") as Label).text, CardText.ui("c02.band.gold"), "gold band text")
	var glow := w.get_node("Glow") as Panel
	t.ok(glow.visible, "glow on")
	var gs := glow.get_theme_stylebox("panel") as StyleBoxFlat
	t.ok(gs.shadow_color.is_equal_approx(CardTheme.with_alpha(&"gold_glow", 0.75)), "glow color")
	t.ok(gs.border_color.is_equal_approx(CardTheme.color(&"gold_pale")), "glow ring gold_pale")
	t.ok(not (w.get_node("Keep") as Button).visible, "gold hides keep")
	w.fast_anim = true
	_show(w, states["gold"])
	t.ok(is_equal_approx(glow.modulate.a, 1.0), "fast anim static")
	w.fast_anim = false
	_show(w, states["gold"])
	t.ok(glow.modulate.a < 0.99, "glow breathes")
	# b12：人物牌也是不透明的纸面（原来 frame.person 九宫格中心透明，牌名直接写在柜台上）。
	_show(w, states["plain"])
	var paper := w.get_node("Paper") as Control
	t.ok(paper.visible and (w.get_node("FrameFlat") as Panel).visible, "person card has a paper face (b12)")
	var face_sb := (w.get_node("FrameFlat") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	t.ok(is_equal_approx(face_sb.bg_color.a, 1.0), "person face opaque (b12)")
	t.ok(face_sb.border_color.is_equal_approx(CardTheme.color(&"frame_person")), "person frame colour")
	t.eq((w.get_node("Band") as Label).text, CardText.ui("c02.intent.pawn"), "person band shows the intent")
	_show(w, states["must_hand"])
	# 必须了断的红点：换皮后是牌种条左端一个印泥红小圆点（Panel），不再是左上角方块。
	var dot := w.get_node("Dot") as Panel
	t.ok(dot.visible, "dot in hand")
	t.ok((dot.get_theme_stylebox("panel") as StyleBoxFlat).bg_color.is_equal_approx(CardTheme.color(&"seal")), "dot seal")
	_show(w, states["must_other"])
	t.ok(not (w.get_node("Dot") as Panel).visible, "no dot outside hand")
	# 剩几天：换皮后是原型的药丸“剩 N 天”（days_plate 底），今晚到期换印泥红；原来是右上角一个数字牌子。
	_show(w, states["expires_1"])
	var days := w.get_node("Days") as Label
	t.ok(days.visible, "expire visible")
	t.eq(days.text, CardText.ui("c02.days.left", {"n": 1}), "expire 1")
	t.ok(_plate(days).is_equal_approx(CardTheme.color(&"days_plate")), "expire plate")
	var tonight: Dictionary = states["expires_1"].duplicate(true)
	tonight["expires_in"] = 0
	_show(w, tonight)
	t.eq((w.get_node("Days") as Label).text, CardText.ui("c02.days.tonight"), "expires tonight")
	t.ok(_plate(w.get_node("Days") as Label).is_equal_approx(CardTheme.color(&"seal")), "tonight plate seal")
	_show(w, states["expires_none"])
	t.ok(not (w.get_node("Days") as Label).visible, "no expire")
	t.eq((w.get_node("Days") as Label).text, "", "expire text cleared")
	_show(w, states["life"])
	t.eq((w.get_node("Days") as Label).text, CardText.ui("c02.days.left", {"n": 3}), "life days")
	t.ok(_plate(w.get_node("Days") as Label).is_equal_approx(CardTheme.color(&"days_plate")), "life plate")
	_show(w, states["life_offhand"])
	t.ok(not (w.get_node("Days") as Label).visible, "life badge only in hand")
	var prison: Dictionary = states["life"].duplicate(true)
	prison["type"] = "prison"
	prison["zone"] = "hand"
	prison["days_left"] = 2
	prison["expires_in"] = -1
	_show(w, prison)
	t.eq((w.get_node("Days") as Label).text, CardText.ui("c02.days.left", {"n": 2}), "prison days")
	var kept_card: Dictionary = states["expires_1"].duplicate(true)
	kept_card["zone"] = "kept"
	_show(w, kept_card)
	t.ok((w.get_node("KeptBadge") as Label).visible, "kept badge")
	t.eq((w.get_node("KeptBadge") as Label).text, CardText.ui("c02.kept.badge"), "kept badge text")
	var seal_sb := (w.get_node("KeptBadge") as Label).get_theme_stylebox("normal") as StyleBoxFlat
	t.ok(seal_sb.bg_color.is_equal_approx(CardTheme.color(&"seal")), "kept seal is red")
	t.ok(seal_sb.corner_radius_top_left * 2 >= int((w.get_node("KeptBadge") as Label).size.x), "kept seal is round")
	t.ok((w.get_node("FrameFlat").get_theme_stylebox("panel") as StyleBoxFlat).border_color.is_equal_approx(
		CardTheme.color(&"frame_kept")), "kept frame colour")
	t.ok((w.get_node("Days") as Label).position.y > (w.get_node("KeptBadge") as Label).position.y, "days under the seal")
	kept_card["zone"] = "hand"
	_show(w, kept_card)
	t.ok(not (w.get_node("KeptBadge") as Label).visible, "hand has no kept badge")
	_show(w, states["away_days"])
	t.eq((w.get_node("Days") as Label).text, CardText.ui("c02.days.away", {"n": 4}), "away days")
	t.ok(_plate(w.get_node("Days") as Label).is_equal_approx(CardTheme.color(&"indigo")), "away plate")
	_show(w, states["used_today"])
	var gray := is_equal_approx(w.modulate.r, 1.0) and is_equal_approx(w.modulate.g, 1.0)
	gray = gray and is_equal_approx(w.modulate.b, 1.0)
	t.ok(gray, "gray rgb")
	t.ok(w.modulate.a < 0.95, "gray alpha")
	# 草稿样式：这张牌在 AI 基础层已经有字了，先拿掉它的 AI 条目，假装还没写字
	var draft_def := str(states["draft"].get("def", ""))
	var ai_saved: Variant = db._ai_text.get(draft_def)
	db._ai_text.erase(draft_def)
	_show(w, states["draft"])
	t.ok(w.modulate.is_equal_approx(Color.WHITE), "not gray")
	var title := w.get_node("Title") as Label
	t.ok(CardText.is_draft(draft_def + "#title"), "example title is draft")
	t.ok(S.italic(title.get_theme_font("font")), "draft italic")
	t.ok(title.get_theme_color("font_color").is_equal_approx(CardTheme.color(&"ink_soft")), "draft color")
	if ai_saved != null:
		db._ai_text[draft_def] = ai_saved
	db._text[str(states["plain"]["def"])] = {"title": "Lin"}
	_show(w, states["plain"])
	title = w.get_node("Title") as Label
	t.eq(title.text, "Lin", "plain title")
	t.ok(not CardText.is_draft(str(states["plain"]["def"]) + "#title"), "plain not draft")
	t.ok(not S.italic(title.get_theme_font("font")), "plain roman")
	t.ok(title.get_theme_color("font_color").is_equal_approx(CardTheme.color(&"ink")), "plain color")
	db._text.erase(str(states["plain"]["def"]))
	_show(w, states["keep_on"])
	t.ok((w.get_node("Keep") as Button).visible, "keep shown")
	# b14：牌上的“留着”在牌的上半截（插图格左上），不在牌底那 24px（手牌扇里正好在屏幕外）。
	var keep_r := (w.get_node("Keep") as Button).get_rect()
	t.ok(keep_r.end.y <= 120.0 and keep_r.position.x < 40.0, "keep chip sits top-left, not at the card bottom")
	t.ok(Rect2(Vector2.ZERO, w.size).encloses(keep_r), "keep chip inside the card")
	var got: Array = []
	w.action_requested.connect(func(uid: String, act: String) -> void: got.append([uid, act]))
	t.ok(w.autoplay_step(), "autoplay keep")
	(w.get_node("Keep") as Button).pressed.emit()
	t.eq(got.size(), 2, "keep signals")
	t.eq(got[0][1], "keep", "autoplay id")
	t.eq(got[1], [str(states["keep_on"]["uid"]), "keep"], "button args")
	_show(w, states["keep_off"])
	t.ok(not (w.get_node("Keep") as Button).visible, "keep hidden when disabled")
	t.ok(not w.autoplay_step(), "autoplay idle")
	var priced: Dictionary = states["draft"].duplicate(true)
	priced["asking"] = 12345
	_show(w, priced)
	t.ok(not S.joined_text(w).contains("12345"), "no asking price")
	t.ok(not S.has_pct(w), "no pct")
	w.set_back(true)
	t.ok((w.get_node("BackFill") as Panel).visible, "back on")
	t.ok(not (w.get_node("Title") as Label).visible, "face hidden")
	t.ok(not S.art(w).is_visible_in_tree(), "art hidden")
	w.set_back(false)
	t.ok((w.get_node("Title") as Label).visible, "face back")
	w.set_card({})
	w.set_card({"uid": "cZ", "actions": "nope", "expires_in": "x", "gold": "nope", "must_resolve": 0, "days_left": null})
	w.set_size_mode(&"nope")
	t.eq(w.size, Vector2(144, 200), "bad mode falls back")
	w.set_highlight(true)
	t.ok((w.get_node("Hi") as Panel).visible, "highlight")
	w.set_highlight(false)
	w.set_back(true)
	w.set_back(false)
	w.fast_anim = true
	t.eq(w.get_uid(), "cZ", "uid from junk")
	t.ok(not w.autoplay_step(), "junk autoplay")
	w.queue_free()
	await t.frames(1)


func _plate(days: Label) -> Color:
	var sb := days.get_theme_stylebox("normal") as StyleBoxFlat
	return sb.bg_color if sb != null else Color.TRANSPARENT


func _show(w: CardWidget, view: Dictionary) -> void:
	w.set_size_mode(&"hand")
	w.set_back(false)
	w.set_card(view)
