## 战斗 v2 的战果（kind battle_result，满屏 1280×720 的高清结算）。只读 campaign.battle2 的 result / payout / view。
## 背景是战场远景（art/hd/bg/battle_backdrop，没有图就是占位）压暗；正中大字胜利 / 战败 / 撤出、胜法、三颗星；
## 左边战况（回合、军心、击杀、漏过）、奖赏（法郎换成本部币制、金币、勋章）和皇帝的命令；右边「命悬一线」：
## 倒下的人一行一个（头像、谁掷几枚、铜钱 CoinToss，快动画时直接翻开，播完写结论），被抬下 / 被俘的直接写结论，
## 再下面溃散的部队和信赖 +1。「继续」发 campaign.battle_finish {}；输了（大命运待处理）就关面板并打开手里的大命运牌，
## 走原来的大命运流程。结算过的仗再打开只回看（「收起」）。中文都在 data/campaigns/battle_ui.json；没有 class_name。
extends CardPanel

const Ui = preload("res://scripts/cards/ui/battle/battle_ui.gd")
const CoinToss = preload("res://scenes/cards/slots/CoinToss.tscn")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")
const Kit = preload("res://scripts/cards/ui/battle/hud/hud_kit.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")
const Portrait = preload("res://scripts/cards/ui/battle/hud/hud_portrait.gd")

const KIND := &"battle_result"
const SCREEN := Vector2(1280, 720)
const LEFT := Rect2(96, 300, 470, 300)
const RIGHT := Rect2(590, 300, 594, 300)
const COIN_SCALE := 0.78

var kind: StringName = KIND
## 快动画：铜钱直接翻开（测试、设置里的快动画、宿主的 fast）
var fast_anim: bool = false

var _q: Dictionary = {}
var _closed := false
var _rolls: Array = []
var _next_roll := 0
var _verdicts: Array = []
var _root: Control
var _btn_continue: Button
var _btn_skip: Button
var _status: Label


func open(_args: Dictionary) -> void:
	_closed = false
	size = SCREEN
	if _root == null:
		theme = Kit.theme()
		HdTheme.apply_hd_filter(self)
		var bg := HdPlaceholder.make_bg("battle_backdrop")
		bg.name = "Backdrop"
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		if HdPlaceholder.is_placeholder(bg):
			bg.set("title_alpha", 0.0)
		add_child(bg)
		_root = Control.new()
		_root.name = "Sheet"
		_root.size = size
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_root)
	_q = engine.query(&"campaign.battle2") if engine != null else {}
	_render()
	_play_next()


func refresh(_view: Dictionary) -> void:
	pass


func dismiss() -> void:
	# 没结算的仗关了也不丢：下次打出「战场」牌还会回到这里
	_close({})


func autoplay_step() -> bool:
	if _closed:
		return false
	if _btn_skip != null and _btn_skip.visible:
		_skip()
		return true
	if _btn_continue != null and not _btn_continue.disabled:
		_on_continue()
		return true
	return false


func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit(result)


func _fast() -> bool:
	if fast_anim or CardSettings.fast_anim():
		return true
	var host := get_parent()
	return host != null and "fast" in host and bool(host.get("fast"))


func _finished() -> bool:
	return bool(_q.get("payout", {}).get("finished", false))


func _fate_pending() -> bool:
	if engine == null:
		return false
	return bool(engine.query(&"campaign").get("big_fate", {}).get("pending", false))


# ================================================================ 画

func _add(node: Control, pos: Vector2, parent: Node = null) -> Control:
	node.position = pos
	(parent if parent != null else _root).add_child(node)
	return node


func _names(uids: Array) -> String:
	var names: Array = []
	for uid in uids:
		names.append(_name_of(str(uid)))
	return Ui.join(names)


func _name_of(uid: String) -> String:
	for b in _q.get("view", {}).get("deploy_bar", []):
		if str(b["uid"]) == uid:
			return str(b["name"])
	return uid


func _bar_of(uid: String) -> Dictionary:
	for b in _q.get("view", {}).get("deploy_bar", []):
		if str(b["uid"]) == uid:
			return b
	return {}


func _render() -> void:
	Kit.clear(_root)
	var res: Dictionary = _q.get("result", {})
	var v: Dictionary = _q.get("view", {})
	var outcome := str(res.get("outcome", "ongoing"))
	var veil := Veil.new()
	veil.size = SCREEN
	veil.tone = "bthud_victory" if outcome == "victory" else ("bthud_defeat" if outcome == "defeat" else "bthud_retreat")
	_root.add_child(veil)
	if res.is_empty() or outcome == "ongoing":
		var box := Kit.glass("glass_strong", "EmptyBox")
		var vb := Kit.vbox(18)
		box.add_child(vb)
		var l := Kit.wrap(Ui.err("battle_over"), 500, 18, "serif", "hd_text")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
		_btn_continue = Kit.button(Ui.text("result_close"), "BtnClose", "secondary", 18)
		_btn_continue.custom_minimum_size = Vector2(180, 46)
		_btn_continue.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_btn_continue.pressed.connect(func() -> void: _close({}))
		vb.add_child(_btn_continue)
		_root.add_child(box)
		box.reset_size()
		box.position = ((SCREEN - box.get_combined_minimum_size()) * 0.5).round()
		return
	var win := outcome == "victory"
	var head_key := "hd_gold_hi" if win else ("hd_enemy_hi" if outcome == "defeat" else "hd_text")
	var kicker := Kit.lbl(Ui.text("result_title", {"battle": v.get("name", "")}), 15, "sans_bold", "hd_text_2")
	kicker.size = Vector2(SCREEN.x, 20)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(kicker, Vector2(0, 30))
	var rule := W.Rule.new()
	rule.size = Vector2(520, 10)
	_add(rule, Vector2(SCREEN.x * 0.5 - 260, 54))
	var big := Kit.lbl(Ui.text("over_" + outcome), 84, "title", head_key)
	big.name = "Outcome"
	big.add_theme_font_override(&"font", HdTheme.font("title", 24))
	Kit.outline(big, 10, "hd_ink", 0.6)
	big.size = Vector2(SCREEN.x, 110)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(big, Vector2(0, 62))
	var kind_text := Ui.pick("kind", str(res.get("victory_kind", "")))
	if outcome == "defeat":
		# 打输了也写一句为什么（主角被俘 / 军心归零），横线下面不再空着
		var caught: Array = res.get("captured", []) if typeof(res.get("captured", [])) == TYPE_ARRAY else []
		kind_text = Ui.text("defeat_captured" if caught.has("hero") else "defeat_morale")
	if kind_text != "":
		var kl := Kit.lbl(kind_text, 20, "serif", "hd_text")
		kl.size = Vector2(SCREEN.x, 28)
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_add(kl, Vector2(0, 176))
	var stars := W.Stars.new()
	stars.name = "Stars"
	stars.count = int(res.get("stars", 0))
	stars.size = Vector2(200, 64)
	_add(stars, Vector2(SCREEN.x * 0.5 - 100, 210))
	_left_card(res, v, outcome)
	_right_card(res)
	_status = Kit.lbl(Ui.text("result_done") if _finished() else "", 13, "sans", "hd_text_3")
	_status.size = Vector2(560, 20)
	_add(_status, Vector2(LEFT.position.x, 662))
	_btn_skip = Kit.button(Ui.text("result_skip"), "BtnSkip", "secondary", 16)
	_btn_skip.size = Vector2(160, 46)
	_btn_skip.visible = false
	_btn_skip.pressed.connect(_skip)
	_add(_btn_skip, Vector2(RIGHT.end.x - 250 - 14 - 160, 646))
	if _finished() and _fate_pending():
		# 读档回来、大命运还没处理：战场牌这里就是醒目的入口，不用在一手牌里找那张大命运
		_btn_continue = Kit.button(Ui.text("result_to_fate"), "BtnToFate", "primary", 20)
		_btn_continue.pressed.connect(func() -> void: _close({"open_uid": "big_fate"}))
		_status.text = Ui.text("result_fate_waiting")
	elif _finished():
		_btn_continue = Kit.button(Ui.text("result_close"), "BtnClose", "secondary", 18)
		_btn_continue.pressed.connect(func() -> void: _close({}))
	else:
		var lost := outcome == "defeat"
		_btn_continue = Kit.button(Ui.text("result_to_fate" if lost else "result_continue"), "BtnContinue", "danger" if lost else "primary", 20)
		_btn_continue.pressed.connect(_on_continue)
	_btn_continue.size = Vector2(250, 50)
	_add(_btn_continue, Vector2(RIGHT.end.x - 250, 644))


## 左卡：战况四格、奖赏、皇帝的命令
func _left_card(res: Dictionary, v: Dictionary, outcome: String) -> void:
	var card := Kit.plate(LEFT, "glass", "StatsCard")
	_root.add_child(card)
	var x := LEFT.position.x + 22
	var y := LEFT.position.y + 18
	var stats := [["result_stat_turns", res.get("turns", 0)], ["result_stat_morale", res.get("morale", 0)],
		["result_stat_kills", res.get("kills", 0)], ["result_stat_leaks", res.get("leaks", 0)]]
	var tw := (LEFT.size.x - 44 - 3 * 10) / 4.0
	for i in range(stats.size()):
		var tile := Tile.new()
		tile.size = Vector2(tw, 74)
		tile.value = str(int(stats[i][1]))
		tile.caption = Ui.text(str(stats[i][0]))
		_add(tile, Vector2(x + i * (tw + 10), y))
	# 原来的一行战况留着给读屏（节点名 StatsLine），画面上不再重复四格里的数
	var line := Kit.lbl(Ui.text("result_stats", {"turns": res.get("turns", 0), "m": res.get("morale", 0), "k": res.get("kills", 0),
		"l": res.get("leaks", 0)}), 12, "sans", "hd_text_3")
	line.name = "StatsLine"
	line.visible = false
	_add(line, Vector2(x, y + 82))
	_add(Kit.lbl(Ui.text("result_rewards_title"), 17, "title", "hd_gold_hi"), Vector2(x, y + 110))
	var rw: Dictionary = res.get("rewards", {})
	var pay: Dictionary = _q.get("payout", {})
	var reward_line := Ui.text("result_no_rewards")
	var chip_n := 0
	if outcome == "victory":
		reward_line = Ui.text("result_rewards", {"franc": rw.get("franc", 0), "currency": pay.get("currency_name", ""),
			"treasury": pay.get("treasury", 0), "gold": rw.get("gold", 0), "medal": rw.get("medal", 0)})
		# 奖赏签：是 0 的不写
		var chips := Kit.hbox(8)
		chips.name = "RewardChips"
		# 法郎和折成的账本单位是同一笔奖赏：一个签写“法郎 87 → 先令 +69”
		if int(rw.get("franc", 0)) > 0 and int(pay.get("treasury", 0)) > 0:
			var paid := Kit.pill(Ui.text("result_reward_paid", {"franc": rw.get("franc", 0),
				"currency": _short_unit(str(pay.get("currency_name", ""))), "n": pay.get("treasury", 0)}), "hd_gold", "hd_ink", 13)
			paid.mouse_filter = Control.MOUSE_FILTER_PASS
			paid.tooltip_text = str(pay.get("currency_name", ""))
			chips.add_child(paid)
		elif int(rw.get("franc", 0)) > 0:
			chips.add_child(Kit.pill(Ui.text("result_reward_franc", {"n": rw.get("franc", 0)}), "hd_gold", "hd_ink", 13))
		elif int(pay.get("treasury", 0)) > 0:
			chips.add_child(Kit.pill(Ui.text("result_reward_treasury", {"currency": pay.get("currency_name", ""), "n": pay.get("treasury", 0)}),
				"hd_navy_3", "hd_gold_hi", 13))
		if int(rw.get("gold", 0)) > 0:
			chips.add_child(Kit.pill(Ui.text("result_reward_gold", {"n": rw.get("gold", 0)}), "hd_gold_deep", "hd_text", 13))
		if int(rw.get("medal", 0)) > 0:
			chips.add_child(Kit.pill(Ui.text("result_reward_medal", {"n": rw.get("medal", 0)}), "hd_wax", "hd_text", 13))
		chip_n = chips.get_child_count()
		_add(chips, Vector2(x, y + 142))
	# 奖赏的一行字留给读屏（节点名 Rewards）；有奖赏签时画面上不再重复，没有奖赏才写“没有奖赏”
	if chip_n == 0:
		reward_line = Ui.text("result_no_rewards")
	var rl := Kit.wrap(reward_line, LEFT.size.x - 44, 13, "sans", "hd_text_3")
	rl.name = "Rewards"
	rl.visible = chip_n == 0
	_add(rl, Vector2(x, y + 142))
	# 皇帝的命令：完成 / 未完成都写出来（这一场有命令时）
	if not (v.get("order", {}) as Dictionary).is_empty():
		var done := bool(res.get("order_done", false))
		var ol := Kit.lbl(Ui.text("result_order" if done else "result_order_missed"), 14, "sans_bold", "hd_gold_hi" if done else "hd_text_3")
		ol.name = "OrderLine"
		_add(ol, Vector2(x, LEFT.end.y - 34))


## 账本单位只取括号前的那截（“先令（20先令＝1英镑）”写“先令”），全名在悬停提示里
func _short_unit(unit: String) -> String:
	return unit.get_slice("\uFF08", 0).get_slice("(", 0).get_slice("\uFF0F", 0).strip_edges()


## 右卡：命悬一线（铜钱）、溃散、信赖
func _right_card(res: Dictionary) -> void:
	var fallen: Array = res.get("fallen", [])
	var routed: Array = res.get("routed", [])
	var trust: Array = res.get("trust_up", [])
	var h := 56.0
	for f in fallen:
		h += 100.0 if bool(f.get("rolled", false)) else 52.0
	if fallen.is_empty():
		h += 40.0
	h += (26.0 if not routed.is_empty() else 0.0) + (26.0 if not trust.is_empty() else 0.0) + 10.0
	var rect := Rect2(RIGHT.position, Vector2(RIGHT.size.x, maxf(RIGHT.size.y, h)))
	var card := Kit.plate(rect, "glass", "FatesCard")
	_root.add_child(card)
	var x := rect.position.x + 22
	var y := rect.position.y + 16
	# 没人倒下时不叫“命悬一线”，叫“伤亡与命运”
	_add(Kit.lbl(Ui.text("result_fates" if not fallen.is_empty() else "result_fates_neutral"), 19, "title", "hd_gold_hi"), Vector2(x, y))
	y += 38.0
	_rolls = []
	_verdicts = []
	if fallen.is_empty():
		var none := Kit.lbl(Ui.text("result_fates_none"), 15, "serif", "hd_text_2")
		_add(none, Vector2(x, y))
		# 输了要去面对大命运（可能有人回不来），不写绿色的“全员归营”；有部队溃散时写“无人阵亡 · N 营溃散”
		var outcome := str(res.get("outcome", ""))
		var tag_key := "result_casualty_none"
		var tag_tone := "hd_good"
		if outcome == "defeat":
			tag_key = "result_casualty_fate"
			tag_tone = "hd_warn"
		elif not routed.is_empty():
			tag_key = "result_casualty_routed"
			tag_tone = "hd_warn"
		var tag := Kit.lbl(Ui.text(tag_key, {"n": routed.size()}), 12, "sans_bold", tag_tone)
		tag.name = "CasualtyTag"
		_add(tag, Vector2(x, y + 24))
		y += 48.0
	for f in fallen:
		y = _fate_row(f, x, y, rect.size.x - 44)
	if not routed.is_empty():
		_add(Kit.wrap(Ui.text("result_routed", {"names": _names(routed)}), rect.size.x - 44, 13, "sans", "hd_text_2"), Vector2(x, y))
		y += 26.0
	if not trust.is_empty():
		_add(Kit.wrap(Ui.text("result_trust", {"names": _names(trust)}), rect.size.x - 44, 13, "sans_bold", "hd_good"), Vector2(x, y))
		y += 26.0
	_roster_strip(x, y + 8.0, rect)


## 右卡剩下的地方：这一仗出战的人（头像、名字、剩下的兵力），一排排往下摆，放不下就不摆
func _roster_strip(x: float, y: float, rect: Rect2) -> void:
	var fought: Array = []
	for b in _q.get("view", {}).get("deploy_bar", []):
		# 一直在部署栏里、兵力满的（没上过场）不写
		if str(b.get("status", "bar")) == "bar" and int(b.get("hp", 0)) >= int(b.get("max_hp", 0)):
			continue
		fought.append(b)
	if fought.is_empty() or rect.end.y - y < 70.0:
		return
	_add(Kit.lbl(Ui.text("result_fought"), 13, "sans_bold", "hd_gold"), Vector2(x, y))
	y += 22.0
	var cw := 132.0
	var per_row := maxi(1, int((rect.size.x - 44.0 + 8.0) / (cw + 8.0)))
	for i in range(fought.size()):
		var b: Dictionary = fought[i]
		var row := i / per_row
		var cy := y + row * 48.0
		if cy + 44.0 > rect.end.y - 10.0:
			break
		var cx := x + (i % per_row) * (cw + 8.0)
		var chip := PanelContainer.new()
		chip.name = "Fought_" + str(b["uid"])
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 0.55, 6, "hd_gold", 0.22, 1, Vector2(4, 3)))
		chip.custom_minimum_size = Vector2(cw, 42)
		var hb := Kit.hbox(6)
		chip.add_child(hb)
		var uid := str(b["uid"])
		var aid := Kit.art_id(uid, str(b.get("kind", "troop")), str(b.get("cls", "")))
		var pic := Portrait.new()
		pic.custom_minimum_size = Vector2(34, 34)
		pic.setup(aid, str(b.get("name", "")), aid)
		pic.dim = str(b.get("status", "")) in ["routed", "dead"]
		hb.add_child(pic)
		var vb := Kit.vbox(0)
		var nm := Kit.lbl(str(b.get("name", "")).get_slice(Ui.text("name_sep"), 0), 12, "sans_bold", "hd_text")
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.custom_minimum_size = Vector2(cw - 52, 0)
		vb.add_child(nm)
		vb.add_child(Kit.lbl("%d/%d" % [maxi(0, int(b.get("hp", 0))), int(b.get("max_hp", 0))], 12, "num",
			"hd_text_2" if maxi(0, int(b.get("hp", 0))) > 0 else "hd_enemy_hi"))
		hb.add_child(vb)
		_add(chip, Vector2(cx, cy))


## 一个倒下的人：头像 + 一行谁掷几枚 + 铜钱（播完再写结论）；不掷的直接写结论
func _fate_row(f: Dictionary, x: float, y: float, w: float) -> float:
	var uid := str(f["unit"])
	var hero := uid == "hero"
	var name := _name_of(uid)
	var b := _bar_of(uid)
	var aid := Kit.art_id(uid, "hero" if hero else str(b.get("kind", "companion")), str(b.get("cls", "")))
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 1.0, 6, "hd_gold", 0.7, 1, Vector2(2, 2)))
	var pic := Portrait.new()
	pic.custom_minimum_size = Vector2(56, 56)
	pic.setup(aid, name, aid)
	frame.add_child(pic)
	_add(frame, Vector2(x, y))
	var tx := x + 74
	if bool(f.get("rolled", false)):
		var head := Ui.text("result_hero_roll", {"n": f["coins"]}) if hero else Ui.text("result_roll", {"name": name, "n": f["coins"]})
		_add(Kit.lbl(head, 14, "sans_bold", "hd_text"), Vector2(tx, y - 2))
		var toss: Control = CoinToss.instantiate()
		toss.name = "Coins_" + uid
		toss.fast_anim = true
		toss.scale = Vector2(COIN_SCALE, COIN_SCALE)
		# 铜钱的掷法、动画、结论都是 CoinToss 的；这里把它的像素铜钱藏起来，盖一层照着它每一枚的位置和翻面画的高清铜钱
		toss.modulate.a = 0.0
		_add(toss, Vector2(tx - 4, y + 18))
		var hd := HdCoins.new()
		hd.name = "HdCoins_" + uid
		hd.toss = toss
		hd.size = Vector2(480, 72) * COIN_SCALE
		_add(hd, Vector2(tx - 4, y + 18))
		var verdict := Kit.lbl("", 16, "title", "hd_enemy_hi")
		verdict.name = "Verdict_" + uid
		verdict.size = Vector2(w - 74, 22)
		_add(verdict, Vector2(tx, y + 76))
		var died := bool(f.get("died", false))
		var text_v := Ui.text("result_hero_died" if died else "result_hero_lived") if hero else Ui.text("result_died" if died else "result_lived")
		if not hero and not died and bool(f.get("was_scarred", false)):
			# 本来就带伤：活下来伤痕也不加重（兵力上限不会再降）
			text_v = Ui.text("result_lived_scarred")
		var faces: Array = []
		var heads := 0
		for xv in f.get("coin_faces", []):
			faces.append(int(xv) == 1)
			heads += 1 if int(xv) == 1 else 0
		text_v = Ui.text("result_heads", {"h": heads, "n": faces.size()}) + text_v
		_rolls.append({"toss": toss, "faces": faces, "verdict": verdict, "text": text_v, "died": died, "pic": pic})
		return y + 104.0
	var line := ""
	if hero and bool(f.get("captured", false)):
		line = Ui.text("result_hero_captured")
	elif bool(f.get("captured", false)):
		line = Ui.text("result_captured", {"name": name})
	else:
		line = Ui.text("result_carried", {"name": name})
	var bad := bool(f.get("captured", false))
	_add(Kit.wrap(line, w - 74, 15, "sans_bold", "hd_enemy_hi" if bad else "hd_text"), Vector2(tx, y + 16))
	return y + 66.0


# ================================================================ 铜钱

func _play_next() -> void:
	if _closed:
		return
	if _next_roll >= _rolls.size():
		_btn_skip.visible = false
		if _btn_continue != null:
			_btn_continue.disabled = false
		return
	if _btn_continue != null and not _finished():
		_btn_continue.disabled = true
	var row: Dictionary = _rolls[_next_roll]
	var toss = row["toss"]
	var quick := _fast() or _finished() or not is_inside_tree()
	toss.fast_anim = quick
	_btn_skip.visible = not quick
	if quick:
		toss.play(row["faces"], 1)
		_reveal(_next_roll)
		_next_roll += 1
		_play_next()
		return
	if not toss.finished.is_connected(_on_toss_done):
		toss.finished.connect(_on_toss_done.bind(_next_roll), CONNECT_ONE_SHOT)
	toss.play(row["faces"], 1)


func _on_toss_done(i: int) -> void:
	if _closed or i != _next_roll:
		return
	_reveal(i)
	_next_roll += 1
	_play_next()


func _reveal(i: int) -> void:
	var row: Dictionary = _rolls[i]
	# 铜钱自带的「⊕ 正面 / 要几个」小牌子在这里看不懂：藏起来，正面数写进结论那一行
	var nums := (row["toss"] as Node).get_node_or_null("Nums") as Control
	if nums != null:
		nums.visible = false
	var verdict: Label = row["verdict"]
	verdict.text = str(row["text"])
	verdict.add_theme_color_override(&"font_color", Kit.col("hd_enemy_hi" if bool(row["died"]) else "hd_good"))
	if bool(row["died"]):
		(row["pic"] as Control).set("dim", true)


func _skip() -> void:
	for i in range(_next_roll, _rolls.size()):
		var row: Dictionary = _rolls[i]
		var toss = row["toss"]
		if toss.finished.is_connected(_on_toss_done):
			toss.finished.disconnect(_on_toss_done)
		toss.fast_anim = true
		if toss.is_playing():
			toss.skip()
		else:
			toss.play(row["faces"], 1)
		_reveal(i)
	_next_roll = _rolls.size()
	_play_next()


func _on_continue() -> void:
	if _finished():
		_close({})
		return
	var res: Dictionary = engine.send(&"campaign.battle_finish", {})
	if not bool(res.get("ok", false)):
		_status.text = Ui.err(str(res.get("err", "")))
		_status.add_theme_color_override(&"font_color", Kit.col("hd_enemy_hi"))
		return
	var camp: Dictionary = engine.query(&"campaign")
	if bool(camp.get("big_fate", {}).get("pending", false)):
		_close({"open_uid": "big_fate"})
		return
	if OS.get_environment("DEHOUDANG_NO_MAP") == "1" and str(camp.get("scene_id", "")) != "":
		_close({"open_uid": "story:" + str(camp.get("scene_id", ""))})
		return
	_close({})


# ================================================================ 小件

## 背景压暗：整体一层暗，正中一团胜负色的光（胜利金、战败红、撤出灰），四角暗角
class Veil extends Control:
	var tone := "bthud_victory"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Kit.cola("hd_ink", 0.62))
		D.glow(self, Rect2(size.x * 0.5 - 420, -120, 840, 460), Kit.cola(tone, 0.32))
		D.vgrad(self, Rect2(0, size.y - 260, size.x, 260), [[0.0, Kit.cola("hd_ink", 0.0)], [1.0, Kit.cola("hd_ink", 0.7)]])
		D.vignette(self, r, 0.7)


## 战况的一格：大数字和下面一行小字
class Tile extends Control:
	var value := ""
	var caption := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		Kit.box_edge(self, r, Kit.cola("hd_ink", 0.55), 6.0, Kit.cola("hd_gold", 0.3), 1.0)
		Kit.text_c(self, value, Vector2(size.x * 0.5, size.y * 0.42), HdTheme.font("num"), 28, Kit.cola("hd_gold_hi"))
		Kit.text_c(self, caption, Vector2(size.x * 0.5, size.y - 14), HdTheme.font("sans"), 12, Kit.cola("hd_text_2"))


## 高清铜钱（方孔钱）：照着 CoinToss 里每一枚铜钱（Row 下的 Coin0、Coin1……）当下的位置、翻面的横向缩放、翻开没有、正反面来画。
## 正面金色带四个小点，反面暗铜色，没翻开的压暗。只画，不改 CoinToss 的任何东西。
class HdCoins extends Control:
	var toss: Control = null

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if toss == null or not is_instance_valid(toss):
			return
		var inv := get_global_transform().affine_inverse()
		for ch in toss.find_children("Coin*", "Control", true, false):
			var coin := ch as Control
			if coin == null or not str(coin.name).begins_with("Coin") or not ("shown" in coin):
				continue
			var xf := inv * coin.get_global_transform()
			var center: Vector2 = xf * (coin.size * 0.5)
			var sc := xf.get_scale()
			var r := coin.size.y * 0.5 * absf(sc.y) * 0.9
			var rx := maxf(coin.size.x * 0.5 * absf(sc.x) * 0.9, 1.0)
			_coin(center, rx, r, bool(coin.get("shown")), bool(coin.get("face")))

	func _coin(c: Vector2, rx: float, r: float, shown: bool, face: bool) -> void:
		var k := rx / r
		D.glow(self, Rect2(c - Vector2(rx, r) * 1.6 + Vector2(0, r * 0.25), Vector2(rx, r) * 3.2), Kit.cola("hd_shadow", 0.55))
		var top := Kit.cola("hd_gold_hi")
		var bottom := Kit.cola("hd_gold_deep")
		if not shown:
			top = Kit.cola("hd_gold_deep")
			bottom = Kit.cola("hd_ink")
		elif not face:
			top = Kit.cola("hd_gold_deep").lerp(Kit.cola("hd_wax"), 0.35)
			bottom = Kit.cola("hd_ink").lerp(Kit.cola("hd_wax"), 0.4)
		var body := D.ellipse(c, rx, r, 48)
		D.poly_colors(self, body, D.colors_by_y(body, c.y - r, c.y + r, top, bottom), 1.2)
		var rim := body.duplicate()
		rim.append(body[0])
		draw_polyline(rim, Kit.cola("hd_gold_hi", 0.9 if shown and face else 0.45), 1.5, true)
		var inner := D.ellipse(c, rx * 0.8, r * 0.8, 40)
		inner.append(inner[0])
		draw_polyline(inner, Kit.cola("hd_ink", 0.35), 1.0, true)
		var h := r * 0.22
		var hole := PackedVector2Array([c + Vector2(-h * k, -h), c + Vector2(h * k, -h), c + Vector2(h * k, h), c + Vector2(-h * k, h)])
		D.poly(self, hole, Kit.cola("hd_ink", 0.92), 1.0)
		if shown and face:
			for d in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				var p: Vector2 = c + Vector2(d.x * rx, d.y * r) * 0.52
				D.diamond(self, p, maxf(r * 0.08, 1.5), Kit.cola("hd_gold_deep"))
			draw_arc(c + Vector2(-rx * 0.15, -r * 0.15), r * 0.62, PI * 1.05, PI * 1.45, 12, Kit.cola("hd_white", 0.5), 1.5, true)
