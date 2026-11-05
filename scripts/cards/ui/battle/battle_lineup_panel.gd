## 战斗 v2 的出征名单（kind battle_lineup，满屏 1280×720 的高清名册）。白天打出手里的「战场」牌打开。
## 打开时没有本场的名单就先发 campaign.battle_prepare {}；之后只读 campaign.battle2.lineup。
## 背景是大营帐篷（art/hd/bg/camp_tent，没有图就是占位章节卡）。左边伙伴立绘卡（兵种、兵力 / 伤痕、宿命之地、倒下的阵亡率、
## 羁绊标签，点卡片出征 / 留守），下面一排部队小卡；右边主角卡（亲临前线的代价、后方调度、揭开猎官），战场预览小地图，
## 这份名单点亮的羁绊，最下面「稍后」「出征」。「揭开猎官」发 campaign.battle_reveal {}；「出征」发
## campaign.battle_begin {companions, troops, protagonist}，成功就换到战场面板（battle_v2）。
## 中文都在 data/campaigns/battle_ui.json；颜色走配色键（bthud_* / hd_*）；没有 class_name。
extends CardPanel

const Ui = preload("res://scripts/cards/ui/battle/battle_ui.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")
const Kit = preload("res://scripts/cards/ui/battle/hud/hud_kit.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")
const Portrait = preload("res://scripts/cards/ui/battle/hud/hud_portrait.gd")

const KIND := &"battle_lineup"
const SCREEN := Vector2(1280, 720)
const LEFT_X := 36.0
const LEFT_W := 640.0
const RIGHT_X := 712.0
const RIGHT_W := 532.0
const TOP_Y := 136.0
const CARD := Vector2(148, 198)
const PIC_H := 100.0
const MAP_H := 190.0
const TROOP := Vector2(120, 46)

## 记住每一场上次排的名单（关掉再打开不重置成默认）：场景|模板 → {c, t, hero}。只在这一次运行里记，不进存档
static var _memo: Dictionary = {}

var kind: StringName = KIND

var _q: Dictionary = {}
var _lu: Dictionary = {}
var _pick_c: Array = []
var _pick_t: Array = []
var _hero := false
var _defaults_for := ""
var _status := ""
## 状态行是提示（主角上阵让位）而不是错误：用平常的字色
var _status_note := false
var _closed := false
var _sending := false
var _root: Control


func open(_args: Dictionary) -> void:
	_closed = false
	size = SCREEN
	if _root == null:
		theme = Kit.theme()
		HdTheme.apply_hd_filter(self)
		var bg := HdPlaceholder.make_bg("camp_tent")
		bg.name = "Backdrop"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		if HdPlaceholder.is_placeholder(bg):
			bg.set("title_alpha", 0.0)
		add_child(bg)
		var veil := Veil.new()
		veil.size = size
		add_child(veil)
		_root = Control.new()
		_root.name = "Sheet"
		_root.size = size
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_root)
	_q = _ask()
	var scene_ok := str(_q.get("phase", "")) == "lineup"
	if not scene_ok and engine != null:
		var res: Dictionary = engine.send(&"campaign.battle_prepare", {})
		if not bool(res.get("ok", false)):
			_status = Ui.err(str(res.get("err", "")))
		_q = _ask()
	_render()


func refresh(_view: Dictionary) -> void:
	if _closed or _sending or _root == null:
		return
	var q := _ask()
	if str(q.get("phase", "")) != "lineup":
		# 名单被别处用掉了（开战、换场景）：不再显示旧名单
		_close({})
		return
	if JSON.stringify(q) == JSON.stringify(_q):
		return
	_q = q
	_render()


func autoplay_step() -> bool:
	if _closed or engine == null:
		return false
	if str(_q.get("phase", "")) != "lineup":
		return false
	_on_march()
	return true


func dismiss() -> void:
	_close({})


func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit(result)


func _ask() -> Dictionary:
	return engine.query(&"campaign.battle2") if engine != null else {}


# ================================================================ 名单

func _caps() -> Dictionary:
	return _lu.get("caps", {"field": 0, "companions": 0})


func _field_used() -> int:
	return _pick_c.size() + _pick_t.size() + (1 if _hero else 0)


func _memo_key() -> String:
	return "%s|%s" % [str(_q.get("scene", "")), str(_q.get("template", ""))]


func _remember() -> void:
	_memo[_memo_key()] = {"c": _pick_c.duplicate(), "t": _pick_t.duplicate(), "hero": _hero}


## 默认名单：不在宿命之地的伙伴按顺序排到伙伴上限，部队按名册顺序补满在场上限；主角默认留守。
## 这一场之前排过（关掉名单又打开）就用上次的，去掉已经不在候选里的人
func _defaults() -> void:
	var key := _memo_key()
	if key == _defaults_for:
		return
	_defaults_for = key
	_pick_c = []
	_pick_t = []
	_hero = false
	var caps := _caps()
	if _memo.has(key):
		var m: Dictionary = _memo[key]
		var cids: Array = (_lu.get("candidates", []) as Array).map(func(c: Dictionary) -> String: return str(c["id"]))
		var tids: Array = (_lu.get("troops", []) as Array).map(func(tr: Dictionary) -> String: return str(tr["id"]))
		_hero = bool(m.get("hero", false)) and bool(_lu.get("protagonist", {}).get("available", true))
		for cid in m.get("c", []):
			if cid in cids and _pick_c.size() < int(caps["companions"]) and _field_used() < int(caps["field"]):
				_pick_c.append(cid)
		for tid in m.get("t", []):
			if tid in tids and _field_used() < int(caps["field"]):
				_pick_t.append(tid)
		return
	for c in _lu.get("candidates", []):
		if not bool(c.get("fated", false)) and _pick_c.size() < int(caps["companions"]) and _field_used() < int(caps["field"]):
			_pick_c.append(str(c["id"]))
	for tr in _lu.get("troops", []):
		if _field_used() < int(caps["field"]):
			_pick_t.append(str(tr["id"]))


func _render() -> void:
	Kit.clear(_root)
	_lu = _q.get("lineup", {})
	if _lu.is_empty():
		_render_empty()
		return
	_defaults()
	var caps := _caps()
	_add(Kit.lbl(Ui.text("lineup_kicker"), 13, "sans_bold", "hd_gold"), Vector2(LEFT_X, 20))
	var title := Kit.lbl(Ui.text("lineup_title", {"battle": _lu.get("battle_name", "")}), 30, "title", "hd_gold_hi")
	title.name = "Title"
	_add(title, Vector2(LEFT_X, 38))
	var sub := Ui.text("lineup_sub", {"scale": _lu.get("scale_name", ""), "act": _lu.get("act", 1), "turns": _lu.get("turn_limit", 0),
		"em": _lu.get("enemy_morale", 0)})
	_add(Kit.lbl(sub, 15, "serif", "hd_text"), Vector2(LEFT_X + 2, 82))
	if str(_lu.get("order", "")) != "":
		var ol := Kit.lbl(Ui.text("lineup_order", {"desc": _lu.get("order", "")}), 13, "sans", "hd_text_2")
		ol.size = Vector2(RIGHT_X + RIGHT_W - LEFT_X - 330, 18)
		ol.clip_text = true
		_add(ol, Vector2(LEFT_X + 2, 104))
	var chip := Kit.glass("glass_soft", "CapsChip")
	chip.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 0.8, 16, "hd_gold", 0.55, 1, Vector2(16, 6)))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caps_l := Kit.lbl(Ui.text("lineup_caps", {"n": _field_used(), "field": caps["field"], "c": _pick_c.size(), "cap": caps["companions"]}),
		16, "sans_bold", "hd_gold_hi")
	caps_l.name = "Caps"
	chip.add_child(caps_l)
	_root.add_child(chip)
	chip.reset_size()
	chip.position = Vector2(RIGHT_X + RIGHT_W - chip.get_combined_minimum_size().x, 40)
	var rule := W.Rule.new()
	rule.size = Vector2(RIGHT_X + RIGHT_W - LEFT_X, 8)
	_add(rule, Vector2(LEFT_X, TOP_Y - 12))
	var y := _companion_block(Vector2(LEFT_X, TOP_Y))
	_troop_block(Vector2(LEFT_X, maxf(y + 2, 400.0)))
	_hero_block(Vector2(RIGHT_X, TOP_Y))
	var my := _map_block(Vector2(RIGHT_X, TOP_Y + 164))
	_bond_block(Vector2(RIGHT_X, my + 10))
	var status := Kit.wrap(_status, RIGHT_W, 14, "sans_bold", "hd_gold_hi" if _status_note else "hd_enemy_hi")
	status.name = "Status"
	_add(status, Vector2(RIGHT_X, 628))
	var later := Kit.button(Ui.text("lineup_later"), "BtnLater", "secondary", 18)
	later.size = Vector2(170, 50)
	later.pressed.connect(func() -> void: _close({}))
	_add(later, Vector2(RIGHT_X + RIGHT_W - 170 - 14 - 220, 656))
	var march := Kit.button(Ui.text("lineup_march"), "BtnMarch", "primary", 24)
	march.size = Vector2(220, 52)
	march.add_theme_font_override(&"font", HdTheme.font("title", 8))
	march.pressed.connect(_on_march)
	_add(march, Vector2(RIGHT_X + RIGHT_W - 220, 654))


func _render_empty() -> void:
	var box := Kit.glass("glass_strong", "EmptyBox")
	box.custom_minimum_size = Vector2(560, 0)
	var v := Kit.vbox(18)
	box.add_child(v)
	var l := Kit.wrap(_status if _status != "" else Ui.err("battle_over"), 500, 18, "serif", "hd_text")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var later := Kit.button(Ui.text("btn_close"), "BtnLater", "secondary", 18)
	later.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	later.custom_minimum_size = Vector2(170, 46)
	later.pressed.connect(func() -> void: _close({}))
	v.add_child(later)
	_root.add_child(box)
	box.reset_size()
	box.position = ((SCREEN - box.get_combined_minimum_size()) * 0.5).round()


func _add(node: Control, pos: Vector2) -> Control:
	node.position = pos
	_root.add_child(node)
	return node


func _bond_name(tag: String) -> String:
	for b in _lu.get("bond_set", []):
		if str(b.get("tag", "")) == tag:
			return str(b.get("name", tag))
	return tag


func _section_head(text: String, hint: String, pos: Vector2) -> void:
	var h := Kit.hbox(10)
	h.add_child(Kit.lbl(text, 18, "title", "hd_gold_hi"))
	if hint != "":
		var hl := Kit.lbl(hint, 12, "sans", "hd_text_3")
		hl.size_flags_vertical = Control.SIZE_SHRINK_END
		h.add_child(hl)
	_add(h, pos)


## 伙伴立绘卡：一行四张；返回下一块的 y
func _companion_block(pos: Vector2) -> float:
	_section_head(Ui.text("lineup_comp_title"), Ui.text("lineup_comp_hint"), pos)
	var cands: Array = _lu.get("candidates", [])
	var gap := (LEFT_W - CARD.x * 4.0) / 3.0
	var y := pos.y + 28.0
	for i in range(cands.size()):
		var c: Dictionary = cands[i]
		var p := Vector2(pos.x + (i % 4) * (CARD.x + gap), y + (i / 4) * (CARD.y + 10.0))
		_companion_card(c, p)
	var rows := ceili(cands.size() / 4.0)
	return y + rows * (CARD.y + 10.0)


func _companion_card(c: Dictionary, pos: Vector2) -> void:
	var cid := str(c["id"])
	var on := cid in _pick_c
	var fated := bool(c.get("fated", false))
	var card := RosterCard.new()
	card.name = "Comp_" + cid
	card.size = CARD
	card.on = on
	card.danger = fated
	_add(card, pos)
	var pic := Portrait.new()
	pic.position = Vector2(4, 4)
	pic.size = Vector2(CARD.x - 8, PIC_H)
	pic.setup(cid, str(c.get("short", cid)), cid)
	pic.dim = not on
	card.add_child(pic)
	var deco := RosterDeco.new()
	deco.size = CARD
	deco.on = on
	deco.cost = int(c.get("cost", 0))
	deco.glyph = Ui.cls_char(str(c["cls"]))
	deco.accent = pic.accent
	deco.badge = Ui.text("lineup_badge_on" if on else "lineup_badge_off")
	card.add_child(deco)
	# 先开裁切 / 省略号再定大小：不裁切时标签的最小宽度就是整行字宽，定的大小会被撑开、字跑出卡片
	var nm := Kit.lbl(str(c["short"]), 17, "title", "hd_text" if on else "hd_text_2")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.position = Vector2(8, PIC_H + 6)
	nm.size = Vector2(CARD.x - 16, 22)
	card.add_child(nm)
	var role := Kit.lbl(str(c.get("role", "")), 11, "sans", "hd_text_3")
	role.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role.position = Vector2(8, PIC_H + 28)
	role.size = Vector2(CARD.x - 16, 15)
	role.tooltip_text = str(c.get("role", ""))
	role.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(role)
	var hp := Kit.lbl(Ui.text("lineup_hp", {"hp": c["hp"], "max": c["max_hp"]}), 12, "sans_bold", "hd_text")
	hp.position = Vector2(8, PIC_H + 43)
	card.add_child(hp)
	var clip := Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.position = Vector2(8, PIC_H + 60)
	clip.size = Vector2(CARD.x - 16, 17)
	var tags := Kit.hbox(3)
	if bool(c.get("scarred", false)):
		tags.add_child(Kit.pill(Ui.text("lineup_scar"), "bthud_tag_scar", "hd_text", 10))
	if fated:
		tags.add_child(Kit.pill(Ui.text("lineup_fated"), "bthud_tag_fated", "hd_text", 10))
	for tag in c.get("bonds", []):
		tags.add_child(Kit.pill(_bond_name(str(tag)), "hd_navy_3", "hd_gold_hi", 10))
	clip.add_child(tags)
	card.add_child(clip)
	var dline := Ui.text("lineup_death_carried", {"pct": c["death_pct"], "carried": c.get("carried_pct", 0)}) if int(c.get("carried_pct", 0)) > 0 \
		else Ui.text("lineup_death", {"pct": c["death_pct"]})
	var dl := Kit.lbl(dline, 11, "sans", "hd_enemy_hi" if fated else "hd_text_3")
	dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	dl.position = Vector2(8, CARD.y - 22)
	dl.size = Vector2(CARD.x - 16, 15)
	card.add_child(dl)
	var btn := Kit.hit("Pick_" + cid)
	btn.size = CARD
	btn.tooltip_text = str(c.get("skill_title", ""))
	btn.pressed.connect(_toggle_companion.bind(cid))
	btn.mouse_entered.connect(func() -> void: card.set("hot", true))
	btn.mouse_exited.connect(func() -> void: card.set("hot", false))
	card.add_child(btn)


## 部队小卡：一行五张（头像、名字、营号和编制）；随行的金边、头像亮，留营的暗
func _troop_block(pos: Vector2) -> void:
	_section_head(Ui.text("lineup_troops"), Ui.text("lineup_troop_hint"), pos)
	var troops: Array = _lu.get("troops", [])
	if troops.is_empty():
		_add(Kit.lbl(Ui.text("lineup_no_troops"), 13, "sans", "hd_text_3"), pos + Vector2(0, 32))
	var gap := (LEFT_W - TROOP.x * 5.0) / 4.0
	for i in range(troops.size()):
		var tr: Dictionary = troops[i]
		var tid := str(tr["id"])
		var on := tid in _pick_t
		var p := pos + Vector2((i % 5) * (TROOP.x + gap), 28 + (i / 5) * (TROOP.y + 8))
		var card := RosterCard.new()
		card.name = "TroopCard_" + tid
		card.size = TROOP
		card.on = on
		_add(card, p)
		var aid := "troop_" + str(tr["cls"])
		var pic := Portrait.new()
		pic.position = Vector2(4, 4)
		pic.size = Vector2(38, 38)
		pic.setup(aid, str(tr["name"]), aid)
		pic.dim = not on
		card.add_child(pic)
		var bname := str(tr["name"])
		var nm := Kit.lbl(bname.get_slice(Ui.text("name_sep"), 0), 13, "sans_bold", "hd_text" if on else "hd_text_2")
		nm.position = Vector2(48, 4)
		nm.size = Vector2(TROOP.x - 52, 18)
		nm.clip_text = true
		card.add_child(nm)
		var sl := Kit.lbl(Ui.text("lineup_strength", {"n": tr.get("strength", 3)}), 11, "sans", "hd_gold_hi" if on else "hd_text_3")
		sl.size = Vector2(TROOP.x - 52, 15)
		sl.clip_text = true
		card.add_child(_at(sl, Vector2(48, 24)))
		var btn := Kit.hit("Troop_" + tid)
		btn.size = TROOP
		btn.tooltip_text = bname
		btn.pressed.connect(_toggle_troop.bind(tid))
		btn.mouse_entered.connect(func() -> void: card.set("hot", true))
		btn.mouse_exited.connect(func() -> void: card.set("hot", false))
		card.add_child(btn)


func _at(node: Control, pos: Vector2) -> Control:
	node.position = pos
	return node


## 主角卡：立绘、亲临前线的代价（HeroLine）、后方调度或重伤的说明、揭开猎官
func _hero_block(pos: Vector2) -> void:
	var hero: Dictionary = _lu.get("protagonist", {})
	var available := bool(hero.get("available", true))
	var h := 154.0
	var card := RosterCard.new()
	card.name = "HeroCard"
	card.size = Vector2(RIGHT_W, h)
	card.on = _hero
	_add(card, pos)
	var pic := Portrait.new()
	pic.position = Vector2(5, 5)
	pic.size = Vector2(118, h - 10)
	pic.setup("villefort", Ui.text("lineup_hero_name"), "villefort")
	pic.dim = not _hero
	card.add_child(pic)
	var x := 136.0
	var head := Kit.hbox(10)
	head.position = Vector2(x, 10)
	head.add_child(Kit.lbl(Ui.text("lineup_hero"), 19, "title", "hd_text" if available else "hd_text_3"))
	head.add_child(Kit.pill(Ui.text("lineup_badge_hero_on" if _hero else "lineup_badge_hero_off"), "hd_gold" if _hero else "hd_navy_3",
		"hd_ink" if _hero else "hd_text_2", 11))
	card.add_child(head)
	card.add_child(_at(Kit.lbl(Ui.text("lineup_hero_name") + "  " + Ui.text("lineup_hp", {"hp": hero.get("hp", 0), "max": hero.get("hp", 0)}),
		12, "sans", "hd_text_2"), Vector2(x, 40)))
	var hunters := int(hero.get("hunters", -1))
	var line := Ui.text("lineup_hero_line", {"pct": hero.get("death_pct", 25), "hunters": Ui.text("lineup_hero_hidden") if hunters < 0 else str(hunters)})
	var hl := Kit.wrap(line, RIGHT_W - x - 14, 14, "sans_bold", "hd_gold_hi" if _hero else "hd_text")
	hl.name = "HeroLine"
	card.add_child(_at(hl, Vector2(x, 62)))
	var note := Kit.wrap(Ui.text("lineup_hero_rear") if available else Ui.text("lineup_hero_wounded"), RIGHT_W - x - 14, 12,
		"sans", "hd_text_3" if available else "hd_enemy_hi")
	card.add_child(_at(note, Vector2(x, 104)))
	var btn := Kit.hit("Hero")
	btn.size = Vector2(RIGHT_W, h)
	btn.disabled = not available
	btn.pressed.connect(_toggle_hero)
	btn.mouse_entered.connect(func() -> void: card.set("hot", available))
	btn.mouse_exited.connect(func() -> void: card.set("hot", false))
	card.add_child(btn)
	if hunters < 0:
		# 揭开猎官：按钮放在主角卡里面（右下角），不压框线
		var rv := Kit.small_button(Ui.text("lineup_reveal", {"n": _lu.get("intel", 0)}), "BtnReveal", "secondary", 12, Vector2(10, 2), 28)
		rv.disabled = int(_lu.get("intel", 0)) < 1
		rv.pressed.connect(_on_reveal)
		card.add_child(rv)
		rv.reset_size()
		rv.position = Vector2(RIGHT_W - rv.size.x - 12, 10)


## 战场预览：小地图（地块贴图、敌人的路线、红门和鹰旗、开场就在的敌人）和说明；返回下一块的 y
func _map_block(pos: Vector2) -> float:
	var mp: Dictionary = _lu.get("map", {})
	var cols := int(mp.get("cols", 0))
	var rows := int(mp.get("rows", 0))
	if cols <= 0 or rows <= 0:
		return pos.y
	_section_head(Ui.text("lineup_map"), "", pos)
	var box := Kit.plate(Rect2(pos + Vector2(0, 30), Vector2(RIGHT_W, MAP_H)), "glass", "MapBox")
	_root.add_child(box)
	var cs := floorf(minf(40.0, minf((MAP_H - 24.0) / rows, 320.0 / cols)))
	var mini := MiniMap.new()
	mini.name = "MiniMap"
	mini.data = mp
	mini.cell = cs
	mini.size = Vector2(cs * cols, cs * rows)
	_add(mini, (pos + Vector2(14, 30 + (MAP_H - cs * rows) * 0.5)).round())
	var nx := 14.0 + cs * cols + 16.0
	var keys := Kit.vbox(5)
	for row in [["lineup_map_routes", "bthud_route"], ["lineup_map_foes", "hd_enemy"], ["lineup_map_high", "hd_tile_rock"]]:
		var kh := Kit.hbox(6)
		var sw := KeySwatch.new()
		sw.key = str(row[1])
		sw.kind = str(row[0])
		sw.custom_minimum_size = Vector2(18, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kh.add_child(sw)
		kh.add_child(Kit.lbl(Ui.text(str(row[0])), 12, "sans_bold", "hd_text"))
		keys.add_child(kh)
	_add(keys, pos + Vector2(nx, 42))
	var note := Kit.wrap(Ui.text("lineup_map_note"), RIGHT_W - nx - 14, 12, "sans", "hd_text_2")
	_add(note, pos + Vector2(nx, 112))
	return pos.y + 30 + MAP_H


## 这份名单点亮的羁绊：职业羁绊数伙伴和部队的兵种，阵营羁绊数伙伴和（带上的）主角的标签
func _bond_block(pos: Vector2) -> void:
	_section_head(Ui.text("lineup_bonds"), "", pos)
	var cls_count := {}
	var tag_count := {}
	for c in _lu.get("candidates", []):
		if str(c["id"]) in _pick_c:
			cls_count[str(c["cls"])] = int(cls_count.get(str(c["cls"]), 0)) + 1
			for tg in c.get("bonds", []):
				tag_count[str(tg)] = int(tag_count.get(str(tg), 0)) + 1
	for tr in _lu.get("troops", []):
		if str(tr["id"]) in _pick_t:
			cls_count[str(tr["cls"])] = int(cls_count.get(str(tr["cls"]), 0)) + 1
	if _hero:
		for tg in _lu.get("protagonist", {}).get("bonds", []):
			tag_count[str(tg)] = int(tag_count.get(str(tg), 0)) + 1
	var y := 28.0
	var lit := 0
	for b in _lu.get("bond_set", []):
		var n := int(cls_count.get(str(b.get("cls", "")), 0)) if str(b.get("kind", "")) == "class" else int(tag_count.get(str(b.get("tag", "")), 0))
		var tiers: Array = b.get("tiers", [])
		var tier := 0
		for th in tiers:
			if n >= int(th):
				tier += 1
		if tier == 0:
			continue
		lit += 1
		# 名字、档位、说明一行（说明放不下就截断，悬停看全文）
		var row := Kit.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = str(b.get("desc", ""))
		row.add_child(Kit.lbl(str(b["name"]), 14, "sans_bold", "hd_gold_hi"))
		row.add_child(Kit.pill(Ui.text("bond_tier", {"n": tier}), "hd_gold", "hd_ink", 11))
		var d := Kit.lbl(str(b.get("desc", "")), 12, "sans", "hd_text_2")
		d.clip_text = true
		d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		d.custom_minimum_size = Vector2(RIGHT_W - 170, 0)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(d)
		row.size = Vector2(RIGHT_W, 22)
		_add(row, pos + Vector2(0, y))
		y += 25.0
		if pos.y + y > 600.0:
			break
	if lit == 0:
		_add(Kit.lbl(Ui.text("lineup_bonds_none"), 12, "sans", "hd_text_3"), pos + Vector2(0, y))


# ================================================================ 点击

func _toggle_companion(cid: String) -> void:
	_status = ""
	_status_note = false
	var caps := _caps()
	if cid in _pick_c:
		_pick_c.erase(cid)
	elif _pick_c.size() >= int(caps["companions"]):
		_status = Ui.text("lineup_full_companions")
	elif _field_used() >= int(caps["field"]):
		_status = Ui.text("lineup_full_field")
	else:
		_pick_c.append(cid)
	_remember()
	_render()


func _toggle_troop(tid: String) -> void:
	_status = ""
	_status_note = false
	if tid in _pick_t:
		_pick_t.erase(tid)
	elif _field_used() >= int(_caps()["field"]):
		_status = Ui.text("lineup_full_field")
	else:
		_pick_t.append(tid)
	_remember()
	_render()


func _toggle_hero() -> void:
	_status = ""
	_status_note = false
	if _hero:
		_hero = false
	elif _field_used() >= int(_caps()["field"]):
		# 默认名单把在场名额排满了：带主角时让最后一支部队留守，不用先去掉一个人
		if _pick_t.is_empty():
			_status = Ui.text("lineup_full_field")
		else:
			var out := str(_pick_t.pop_back())
			_hero = true
			_status = Ui.text("lineup_hero_swap", {"name": _troop_name(out)})
			_status_note = true
	else:
		_hero = true
	_remember()
	_render()


func _troop_name(tid: String) -> String:
	for tr in _lu.get("troops", []):
		if str(tr["id"]) == tid:
			return str(tr["name"])
	return tid


func _on_reveal() -> void:
	_status = ""
	_status_note = false
	_sending = true
	var res: Dictionary = engine.send(&"campaign.battle_reveal", {})
	_sending = false
	if not bool(res.get("ok", false)):
		_status = Ui.err(str(res.get("err", "")))
	_q = _ask()
	_render()


func _on_march() -> void:
	_status = ""
	_status_note = false
	_remember()
	# 名单按候选人和名册的顺序发（部署栏也按这个顺序摆）
	var comps: Array = []
	for c in _lu.get("candidates", []):
		if str(c["id"]) in _pick_c:
			comps.append(str(c["id"]))
	var troops: Array = []
	for tr in _lu.get("troops", []):
		if str(tr["id"]) in _pick_t:
			troops.append(str(tr["id"]))
	_sending = true
	var res: Dictionary = engine.send(&"campaign.battle_begin", {"companions": comps, "troops": troops, "protagonist": _hero})
	_sending = false
	if bool(res.get("ok", false)):
		_close({"next": {"kind": "battle_v2", "args": {}}})
		return
	_status = Ui.err(str(res.get("err", "")))
	_q = _ask()
	_render()


# ================================================================ 小件

## 背景上的一层暗：左边（名单）压得深、右上淡一点，字压在图上也清楚
class Veil extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Kit.cola("hd_ink", 0.4))
		D.vgrad(self, Rect2(0, 0, size.x, 150), [[0.0, Kit.cola("hd_ink", 0.7)], [1.0, Kit.cola("hd_ink", 0.0)]])
		D.vgrad(self, Rect2(0, size.y - 140, size.x, 140), [[0.0, Kit.cola("hd_ink", 0.0)], [1.0, Kit.cola("hd_ink", 0.6)]])
		D.vignette(self, Rect2(Vector2.ZERO, size), 0.6)


## 名册卡的底和框：选中金边外发光，没选暗一点；悬停亮边；宿命之地红边
class RosterCard extends Control:
	var on := false
	var danger := false
	var hot := false:
		set(v):
			hot = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if on:
			Kit.box_glow(self, r, Kit.cola("hd_card_hi", 0.96), 7.0, Kit.cola("hd_gold_hi"), 2.0, Kit.cola("hd_gold", 0.45), 14)
		else:
			Kit.box_glow(self, r, Kit.cola("hd_card", 0.9), 7.0, Kit.cola("hd_enemy_hi" if danger else "hd_gold", 0.7 if danger else 0.3),
				1.0, Kit.cola("hd_shadow", 0.5), 10)
		if hot:
			Kit.box_edge(self, r, Kit.cola("hd_ink", 0.0), 7.0, Kit.cola("hd_white", 0.55), 1.0)


## 伙伴卡头像上的：费用、兵种字、底部渐变和「出征 / 留守」签
class RosterDeco extends Control:
	var on := false
	var cost := 0
	var glyph := ""
	var badge := ""
	var accent: Color

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var pr := Rect2(4, 4, size.x - 8, PIC_H)
		D.vgrad(self, Rect2(pr.position.x, pr.position.y + 60, pr.size.x, 52), [[0.0, Kit.cola("hd_ink", 0.0)], [1.0, Kit.cola("hd_ink", 0.75)]])
		var cr := Rect2(2, 2, 26, 22)
		Kit.box_edge(self, cr, Kit.cola("bthud_cost_bg", 0.95), 5.0, Kit.cola("hd_gold", 0.8), 1.0)
		Kit.text_c(self, str(cost), cr.get_center(), HdTheme.font("num"), 15, Kit.cola("bthud_cost_ink"))
		var gc := Vector2(size.x - 15, 15)
		draw_circle(gc, 11.5, Kit.cola("hd_ink", 0.88), true, -1.0, true)
		draw_arc(gc, 11.5, 0, TAU, 40, accent, 1.5, true)
		Kit.text_c(self, glyph, gc, HdTheme.font("title"), 13, Kit.cola("hd_gold_hi"))
		var fb := HdTheme.font("sans_bold")
		var bw := fb.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 22.0
		var br := Rect2(Vector2(size.x * 0.5 - bw * 0.5, pr.end.y - 22), Vector2(bw, 19))
		if on:
			Kit.box_glow(self, br, Kit.cola("hd_gold"), 9.0, Kit.cola("hd_gold_hi"), 1.0, Kit.cola("hd_gold", 0.4), 8)
			Kit.text_c(self, badge, br.get_center(), fb, 12, Kit.cola("hd_ink"))
		else:
			Kit.box_edge(self, br, Kit.cola("hd_ink", 0.85), 9.0, Kit.cola("hd_text_3", 0.6), 1.0)
			Kit.text_c(self, badge, br.get_center(), fb, 12, Kit.cola("hd_text_3"))


## 小地图图例的色样：路线一道线、敌人一个点、高地一块石面
class KeySwatch extends Control:
	var key := ""
	var kind := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"lineup_map_routes":
				draw_line(Vector2(1, c.y), Vector2(size.x - 1, c.y), Kit.cola(key), 3.0, true)
			"lineup_map_foes":
				draw_circle(c, 5.0, Kit.cola(key), true, -1.0, true)
				draw_arc(c, 5.0, 0, TAU, 24, Kit.cola("hd_white", 0.85), 1.2, true)
			_:
				draw_texture_rect(HdPlaceholder.make_tile_tex("rock"), Rect2(Vector2.ZERO, size), false)
				Kit.box_edge(self, Rect2(Vector2.ZERO, size), Kit.cola("hd_ink", 0.0), 2.0, Kit.cola("hd_gold", 0.6), 1.0)


## 小地图：一格一块地块贴图（和 3D 战场同一套，有美术用美术），高地加一道亮边，红门两根红柱、鹰旗金菱形，
## 敌人的路线是红线（终点一个箭头），开场就在的敌人画红点
class MiniMap extends Control:
	var data: Dictionary = {}
	var cell := 24.0

	func _draw() -> void:
		var cols := int(data.get("cols", 0))
		var rows := int(data.get("rows", 0))
		var terr: Array = data.get("terrain", [])
		Kit.box(self, Rect2(Vector2.ZERO, size).grow(3), Kit.cola("hd_ink", 0.9), 4.0)
		for r in range(rows):
			for c in range(cols):
				var tr := str(terr[r * cols + c]) if r * cols + c < terr.size() else "plain"
				var rect := Rect2(Vector2(c, r) * cell, Vector2(cell, cell)).grow(-0.5)
				var tid := HdArt.terrain_tex("river" if tr == "bridge" else tr)
				if tid != "":
					draw_texture_rect(HdPlaceholder.make_tile_tex(tid), rect, false)
				match tr:
					"high", "earthwork":
						draw_line(rect.position + Vector2(0, 1), rect.position + Vector2(rect.size.x, 1), Kit.cola("hd_white", 0.35), 2.0)
						draw_line(rect.position + Vector2(0, rect.size.y - 1), rect.end - Vector2(0, 1), Kit.cola("hd_ink", 0.5), 2.0)
					"gate":
						Kit.box(self, Rect2(rect.position + Vector2(cell * 0.2, 3), Vector2(3, cell - 6)), Kit.cola("bthud_gate"), 1.0)
						Kit.box(self, Rect2(rect.position + Vector2(cell * 0.8 - 3, 3), Vector2(3, cell - 6)), Kit.cola("bthud_gate"), 1.0)
					"eagle":
						D.diamond(self, rect.get_center(), cell * 0.2, Kit.cola("hd_gold_hi"))
					"bridge":
						Kit.box(self, Rect2(rect.position + Vector2(0, cell * 0.3), Vector2(rect.size.x, cell * 0.4)), Kit.cola("bthud_bridge"), 1.0)
					"village":
						Kit.box(self, Rect2(rect.get_center() - Vector2(cell * 0.18, cell * 0.12), Vector2(cell * 0.36, cell * 0.28)),
							Kit.cola("bthud_gate", 0.85), 1.0)
				draw_rect(rect, Kit.cola("hd_ink", 0.35), false, 1.0)
		for rt in data.get("routes", []):
			var pts := PackedVector2Array()
			for p in rt:
				pts.append((Vector2(float(p[0]), float(p[1])) + Vector2(0.5, 0.5)) * cell)
			if pts.size() < 2:
				continue
			draw_polyline(pts, Kit.cola("hd_ink", 0.5), 4.5, true)
			draw_polyline(pts, Kit.cola("bthud_route", 0.95), 2.2, true)
			var a := pts[pts.size() - 2]
			var b := pts[pts.size() - 1]
			var dv := (b - a).normalized()
			var nv := Vector2(-dv.y, dv.x)
			var tip := b - dv * cell * 0.15
			D.poly(self, PackedVector2Array([tip, tip - dv * 7 + nv * 5, tip - dv * 7 - nv * 5]), Kit.cola("bthud_route"), 1.0)
		var counts := {}
		for e in data.get("foes", []):
			var key := Vector2i(int(e["col"]), int(e["row"]))
			var k2 := int(counts.get(key, 0))
			counts[key] = k2 + 1
			var p := (Vector2(key) + Vector2(0.3 + 0.4 * (k2 % 2), 0.3 + 0.4 * ((k2 / 2) % 2))) * cell
			draw_circle(p, maxf(cell * 0.14, 3.0), Kit.cola("hd_enemy"), true, -1.0, true)
			draw_arc(p, maxf(cell * 0.14, 3.0), 0, TAU, 24, Kit.cola("hd_white", 0.85), 1.2, true)
		Kit.box_edge(self, Rect2(Vector2.ZERO, size).grow(3), Kit.cola("hd_ink", 0.0), 4.0, Kit.cola("hd_gold", 0.6), 1.0)
