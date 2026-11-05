# 高清战斗 HUD（battle_panel.gd、battle_lineup_panel.gd、battle_result_panel.gd 和 scripts/cards/ui/battle/hud/）的无头测试：
# 仓库规矩（没有 class_name、没有颜色字面量、字符串字面量只有 ASCII、用到的 bthud_* 配色键都在 palette.dev.json、
# 用到的 battle_ui.json 文字键都在）；战场满屏、地图让出 HUD（安全区不压右侧情报栏）；顶栏、部署牌、军令牌互不重叠、
# 都在屏幕里；部署（牌 → 格子 → 朝向箭头围着那一格）、选中单位的圆按钮、悬停情报栏（不盖住悬停的那一格）、
# 交火风险警告和确认、撤退确认、图例、战报全文、收起情报栏、打完的横幅；出征名单和战果的节点合同、高清铜钱。
# 用一个假引擎（规则内核 + ocean_battle2 的查询），不开整局游戏。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const OB = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const Data = preload("res://scripts/cards/campaign/ocean_rogue_data.gd")
const Ui = preload("res://scripts/cards/ui/battle/battle_ui.gd")
const BPanel = preload("res://scripts/cards/ui/battle/battle_panel.gd")
const LPanel = preload("res://scripts/cards/ui/battle/battle_lineup_panel.gd")
const RPanel = preload("res://scripts/cards/ui/battle/battle_result_panel.gd")
const HUD_DIR := "res://scripts/cards/ui/battle/hud"
const PANELS := ["res://scripts/cards/ui/battle/battle_panel.gd", "res://scripts/cards/ui/battle/battle_lineup_panel.gd",
	"res://scripts/cards/ui/battle/battle_result_panel.gd"]
const PALETTE_DEV := "res://data/cards/theme/palette.dev.json"
const SCREEN := Rect2(0, 0, 1280, 720)

var t


class FakeCampaign extends RefCounted:
	var state: Dictionary = {}
	var scene_id := "scene05"

	func scene() -> Dictionary:
		return {"id": scene_id}

	func chapter() -> Dictionary:
		return {"currency": "franc", "currency_name": "franc"}


class FakeEngine extends CardEngineApi:
	var state: Dictionary = {}
	var camp = null
	var result_override: Dictionary = {}
	var sent: Array = []

	func battle(tpl: String, comps: Array, troops: Array, hero: bool) -> void:
		var roster: Array = []
		for c_id in comps:
			var prof := OB.profile(c_id)
			roster.append({"id": c_id, "name": str(prof.get("short", c_id)), "cls": str(prof["cls"]), "max_hp": int(prof["hp"]),
				"atk": int(prof["atk"]), "def": int(prof["def"]), "block": int(prof["block"]), "cost": int(prof["cost"]),
				"skill": str(prof["skill"]), "tags": (Data.COMPANIONS[c_id]["bonds"] as Array).duplicate(), "scarred": false, "fated": false})
		var tr: Array = []
		for i in range(troops.size()):
			var row := {"id": "%s_%d" % [troops[i], i + 1], "cls": troops[i]}
			row["name"] = OB.troop_name(row)
			tr.append(row)
		state = R.new_battle(tpl, {"seed": 1815, "act": 1, "roster": roster, "troops": tr,
			"protagonist": {"enabled": hero, "name": "hero", "hp": 12, "max_hp": 12, "tags": ["imperial"]},
			"bond_set": "ocean", "morale": 10, "cp_bonus": 7})

	func lineup(tpl: String, comps: Array, troops: Array) -> void:
		camp = FakeCampaign.new()
		var companions := {}
		for c_id in Data.COMPANION_IDS:
			companions[c_id] = {"recruited": c_id in comps, "alive": true, "captured": false, "scarred": false}
		var tr: Array = []
		for i in range(troops.size()):
			tr.append({"id": "%s_%d" % [troops[i], i + 1], "cls": troops[i], "strength": 3})
		var probe := R.new_battle(tpl, {"seed": 7, "act": 2, "protagonist": {"enabled": true}})
		camp.state = {"seed": 1815, "rogue": {"companions": companions, "army": {"troops": tr, "hero_wounded": false},
			"coins": {"intel": 2}, "battle2": {"phase": "lineup", "scene": camp.scene_id, "template": tpl, "scale": str(probe["scale"]),
			"act": 2, "revealed": false, "hunters": 2, "lineup": {}, "state": {}, "result": {}}}}

	func new_game(_opts: Dictionary) -> Dictionary:
		return {}

	func load_game(_path: String) -> Dictionary:
		return {}

	func save_game(_path: String) -> Dictionary:
		return {}

	func view() -> Dictionary:
		return {}

	func is_busy() -> bool:
		return false

	func send(c: StringName, args: Dictionary = {}) -> Dictionary:
		sent.append([str(c), args.duplicate(true)])
		match c:
			&"campaign.battle_cmd":
				return R.apply(state, str(args.get("cmd", "")), args.get("args", {}))
			&"campaign.battle_reveal":
				return OB.reveal(camp, args)
			&"campaign.battle_begin", &"campaign.battle_prepare", &"campaign.battle_finish":
				return {"ok": true}
		return {"ok": false, "err": "bad"}

	func query(q: StringName, args: Dictionary = {}) -> Dictionary:
		match q:
			&"campaign":
				return {"big_fate": {"pending": false}}
			&"campaign.battle2":
				if camp != null:
					return {"phase": "lineup", "scene": camp.scene_id, "template": "", "lineup": OB.lineup(camp)}
				var over := str(state.get("phase", "")) == "over"
				var res: Dictionary = result_override if not result_override.is_empty() else (OB.public(R.result(state)) if over else {})
				return {"phase": "active", "view": OB.public(R.view(state)), "over": over, "result": res,
					"payout": {"treasury": 50, "currency_name": "franc", "finished": false}}
			&"campaign.battle_preview":
				if args.has("cmd"):
					return OB.public(R.preview_cmd(state, str(args["cmd"]), args.get("args", {})))
				return OB.public(R.preview(state))
		return {}


func _initialize() -> void:
	t = T.new(self, "OCEAN_battle_hud")
	t.run_async(_body)


func _body() -> void:
	_test_house_rules()
	await _test_battle_panel()
	await _test_lineup()
	await _test_result()


# ================================================================ 仓库规矩

func _test_house_rules() -> void:
	var files := PackedStringArray(PANELS)
	for f in DirAccess.get_files_at(HUD_DIR):
		if f.ends_with(".gd"):
			files.append(HUD_DIR + "/" + f)
	t.ok(files.size() >= 6, "HUD panels and helpers are there (%d)" % files.size())
	var colors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_DEV)).get("colors", {})
	var texts: Dictionary = Ui.data().get("text", {})
	var key_re := RegEx.create_from_string("\"(bthud_[a-z0-9_]+)\"")
	var text_re := RegEx.create_from_string("Ui\\.text\\(\"([a-z0-9_]+)\"[,)]")
	var pick_re := RegEx.create_from_string("Ui\\.pick\\(\"([a-z0-9_]+)\"")
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		var code := _strip_comments(src)
		t.ok(RegEx.create_from_string("(?m)^class_name\\s").search(code) == null, path + ": no class_name")
		t.ok(not RegEx.create_from_string("Color\\s*\\(|Color8\\s*\\(|Color\\.html|Color\\.from_|Color\\.[A-Z]").search(code),
			path + ": no colour literals")
		for lit in _strings(src):
			var ascii := true
			for i in lit.length():
				if lit.unicode_at(i) > 127:
					ascii = false
			t.ok(ascii, "%s: ASCII string literal '%s'" % [path.get_file(), lit])
		for m in key_re.search_all(code):
			t.ok(colors.has(m.get_string(1)), "%s: palette key %s exists" % [path.get_file(), m.get_string(1)])
		for m in text_re.search_all(code):
			t.ok(texts.has(m.get_string(1)), "%s: battle_ui text %s exists" % [path.get_file(), m.get_string(1)])
		for m in pick_re.search_all(code):
			t.ok(typeof(texts.get(m.get_string(1))) == TYPE_DICTIONARY, "%s: battle_ui group %s exists" % [path.get_file(), m.get_string(1)])


# ================================================================ 战场面板

func _host(panel: Control) -> void:
	get_root().add_child(panel)
	panel.position = Vector2.ZERO
	panel.size = SCREEN.size


func _find(root: Node, n: String) -> Node:
	return root.find_child(n, true, false)


func _btn(root: Node, n: String) -> Button:
	return root.find_child(n, true, false) as Button


func _press(root: Node, n: String) -> bool:
	var b := _btn(root, n)
	var ready := b != null and b.is_visible_in_tree() and not b.disabled
	t.ok(ready, "visible enabled button " + n)
	if ready:
		b.pressed.emit()
		await t.frames(2)
	return ready


func _grect(c: Node) -> Rect2:
	return (c as Control).get_global_rect() if c is Control else Rect2()


func _test_battle_panel() -> void:
	var eng := FakeEngine.new()
	eng.battle("skirmish_b", ["dantes", "gourgaud"], ["line", "jager", "hussar"], true)
	var panel = BPanel.new()
	panel.bind(eng, null)
	_host(panel)
	panel.open({})
	await t.frames(3)
	var board: Control = _find(panel, "Board")
	t.ok(board != null and board.position == Vector2.ZERO and board.size == SCREEN.size, "3D board fills the screen behind the HUD")
	var col: Control = _find(panel, "IntelColumn")
	var safe: Rect2 = board.safe_area()
	t.ok(SCREEN.encloses(safe) and safe.position.y >= 90.0 and safe.end.y <= 560.0, "map safe area sits between the top bar and the cards: " + str(safe))
	t.ok(col.is_visible_in_tree() and safe.end.x <= col.get_global_rect().position.x, "map leaves the intel column free")
	# 节点合同（OCEAN_ui 和自动试玩按名字找）
	var v: Dictionary = eng.query(&"campaign.battle2")["view"]
	for b in v["deploy_bar"]:
		t.ok(_btn(panel, "Deploy_" + str(b["uid"])) != null, "deploy card button for " + str(b["uid"]))
	t.ok(_btn(panel, "Dispatch_hero") != null and _btn(panel, "Dispatch_hero").is_visible_in_tree(), "rear dispatch on the hero card")
	for h in v["hand"]:
		t.ok(_btn(panel, "Card_%d" % int(h["index"])) != null, "command card button %d" % int(h["index"]))
	for n in ["BtnFight", "BtnUndo", "BtnRedraw", "BtnRetreat", "BtnLog", "BtnLegend", "BtnIntel", "BtnLogMore"]:
		t.ok(_btn(panel, n) != null, "HUD button " + n)
	t.ok(_find(panel, "FightWarning") is Label, "fight warning label")
	var log_l := _find(panel, "Log") as Label
	t.ok(log_l != null and log_l.is_visible_in_tree() and log_l.text.contains(str(v["name"])), "turn-1 battle report shows the opening line")
	# 都在屏幕里、互不重叠
	var top: Array = []
	for n in ["Title", "MoraleBar", "Turn", "EnemyMoraleBar", "TopButtons", "BtnFight"]:
		var node := _find(panel, n)
		t.ok(node != null and SCREEN.encloses(_grect(node)), n + " inside the screen")
		top.append(_grect(node))
	t.ok(_disjoint(top), "top bar pieces do not overlap")
	var cards: Array = []
	for b in v["deploy_bar"]:
		cards.append(_grect(_find(panel, "Card_" + str(b["uid"]))))
	var orders: Array = []
	for h in v["hand"]:
		orders.append(_grect(_find(panel, "Order_%d" % int(h["index"]))))
	t.ok(_disjoint(cards + orders), "deploy cards and command cards do not overlap")
	for r in cards + orders:
		t.ok(SCREEN.encloses(r), "bottom card inside the screen: " + str(r))
	for n in ["CpPlate", "FieldChip", "HandHead", "StatusBox"]:
		t.ok(SCREEN.encloses(_grect(_find(panel, n))), n + " inside the screen")
	t.ok(not _grect(_find(panel, "CpPlate")).intersects(col.get_global_rect()), "CP plate below the intel column")
	# 部署：牌 → 亮着的格子 → 四个朝向箭头围着那一格
	if not await _press(panel, "Deploy_gourgaud"):
		return
	var valid: Dictionary = board.get("valid_cells")
	t.ok(not valid.is_empty(), "picking a deploy card lights the cells")
	var cell: Vector2i = valid.keys()[0]
	for k in valid.keys():
		if k.x == 3 and k.y == 1:
			cell = k
	if not await _press(panel, "Cell_%d_%d" % [cell.x, cell.y]):
		return
	var c: Vector2 = board.cell_center(cell.x, cell.y)
	for dir in ["right", "left", "up", "down"]:
		var f := _btn(panel, "Face_" + dir)
		t.ok(f != null and f.is_visible_in_tree(), "facing arrow " + dir)
		if f != null:
			var d := f.get_global_rect().get_center().distance_to(c)
			t.ok(d > 40.0 and d < 110.0, "facing arrow %s sits around the cell (%d px)" % [dir, int(d)])
	var right_x := _btn(panel, "Face_right").get_global_rect().get_center().x
	t.ok(right_x > c.x and _btn(panel, "Face_left").get_global_rect().get_center().x < c.x, "right arrow right of the cell, left arrow left")
	t.ok(_btn(panel, "Face_up").get_global_rect().get_center().y < _btn(panel, "Face_down").get_global_rect().get_center().y, "up arrow above down arrow")
	if not await _press(panel, "Face_right"):
		return
	t.ok(str(eng.state["units"]["gourgaud"]["status"]) == "ok", "facing arrow deploys the companion")
	# 选中单位：身边的圆按钮
	if not await _press(panel, "Cell_%d_%d" % [cell.x, cell.y]):
		return
	for n in ["Act_skill", "Act_withdraw", "Act_square", "Act_close"]:
		var a := _btn(panel, n)
		t.ok(a != null and a.is_visible_in_tree() and SCREEN.encloses(a.get_global_rect()), "unit action " + n + " on screen")
	t.ok(_btn(panel, "Act_withdraw").disabled, "just deployed: withdraw is greyed")
	var info := _find(panel, "Info") as Control
	t.ok(info != null and info.is_visible_in_tree() and _text(info).contains(str(eng.state["units"]["gourgaud"]["name"])), "selected unit shows in the info panel")
	if not await _press(panel, "Act_close"):
		return
	# 悬停：情报栏写交火后的兵力，不盖住悬停的那一格
	var cb := _btn(panel, "Cell_%d_%d" % [cell.x, cell.y])
	cb.mouse_entered.emit()
	await t.frames(2)
	t.ok(info.is_visible_in_tree() and _text(info).contains(Ui.text("info_after_same").substr(0, 3)), "hover shows the after-fight strength")
	t.ok(not _grect(_find(panel, "InfoPanel")).has_point(c), "info panel does not cover the hovered cell")
	cb.mouse_exited.emit()
	await t.frames(2)
	t.ok(not info.is_visible_in_tree(), "info panel hides when nothing is hovered or selected")
	var left := _btn(panel, "Cell_0_1")
	left.mouse_entered.emit()
	await t.frames(2)
	if info.is_visible_in_tree():
		t.ok(not _grect(_find(panel, "InfoPanel")).has_point(board.cell_center(0, 1)), "info panel flips away from a left-edge cell")
	left.mouse_exited.emit()
	await t.frames(2)
	# 风险：伙伴交火后会倒下 → 交火按钮下面红字，按交火先确认
	var warn := _find(panel, "FightWarning") as Label
	for _turn in range(4):
		eng.state["units"]["gourgaud"]["hp"] = 1
		panel.refresh({})
		await t.frames(2)
		if warn.text != "" or str(eng.state.get("phase", "")) == "over":
			break
		R.apply(eng.state, "fight", {})
	t.ok(warn.text != "" and warn.is_visible_in_tree(), "risk line under the fight button: " + warn.text)
	t.ok(SCREEN.encloses(_grect(_find(panel, "FightWarnBox"))), "risk line inside the screen")
	if not await _press(panel, "BtnFight"):
		return
	t.ok(_btn(panel, "BtnFightYes").is_visible_in_tree(), "fight asks for confirmation when the preview warns")
	t.ok(SCREEN.encloses(_grect(_find(panel, "FightConfirmBox"))), "fight confirm dialog on screen")
	await _press(panel, "BtnFightNo")
	t.ok(not _btn(panel, "BtnFightYes").is_visible_in_tree(), "think again closes the dialog")
	await _press(panel, "BtnRetreat")
	t.ok(_btn(panel, "BtnRetreatYes").is_visible_in_tree() and _text(_find(panel, "RetreatConfirm")).contains(Ui.text("retreat_confirm").substr(0, 6)),
		"retreat asks for confirmation")
	await _press(panel, "BtnRetreatNo")
	# 图例、战报全文、收起情报栏
	await _press(panel, "BtnLegend")
	var legend := _find(panel, "LegendPanel") as Control
	t.ok(legend.is_visible_in_tree() and SCREEN.encloses(legend.get_global_rect()) and _find(panel, "Legend").get_child_count() > 3, "legend popover lists the terrain")
	await _press(panel, "BtnLegend")
	t.ok(not legend.is_visible_in_tree(), "legend toggles off")
	await _press(panel, "BtnLog")
	t.ok((_find(panel, "LogFull") as Control).visible and (_find(panel, "LogFullText") as Label).text.contains(str(v["name"])), "full battle report opens")
	panel.dismiss()
	await t.frames(1)
	t.ok(not (_find(panel, "LogFull") as Control).visible, "Esc closes the full report first")
	var narrow: Rect2 = board.safe_area()
	await _press(panel, "BtnIntel")
	t.ok(not col.is_visible_in_tree() and board.safe_area().size.x > narrow.size.x, "hiding the intel column widens the map")
	await _press(panel, "BtnIntel")
	t.ok(col.is_visible_in_tree() and board.safe_area() == narrow, "showing it again restores the map")
	# 打完：横幅和查看战果
	for _i in range(20):
		if str(eng.state.get("phase", "")) == "over":
			break
		R.apply(eng.state, "fight", {})
	panel.refresh({})
	await t.frames(2)
	t.ok(_btn(panel, "BtnResult") != null and _btn(panel, "BtnResult").is_visible_in_tree(), "battle over: result button on the banner")
	panel.queue_free()
	await t.frames(3)


# ================================================================ 出征名单

func _test_lineup() -> void:
	var eng := FakeEngine.new()
	var comps := ["dantes", "gourgaud", "faria", "friday", "nemo", "morel"]
	var troops := ["line", "jager", "artillery", "grenadier", "hussar"]
	eng.lineup("major_a", comps, troops)
	var panel = LPanel.new()
	panel.bind(eng, null)
	_host(panel)
	panel.open({})
	await t.frames(3)
	for cid in comps:
		t.ok(_btn(panel, "Pick_" + cid) != null, "companion card " + cid)
	for i in range(troops.size()):
		t.ok(_btn(panel, "Troop_%s_%d" % [troops[i], i + 1]) != null, "troop card " + troops[i])
	for n in ["Hero", "BtnMarch", "BtnLater", "BtnReveal"]:
		t.ok(_btn(panel, n) != null and _btn(panel, n).is_visible_in_tree(), "lineup button " + n)
	t.ok(_find(panel, "MiniMap") != null and _find(panel, "Caps") is Label, "lineup shows the map preview and caps")
	t.ok(_text(panel).contains(Ui.text("lineup_title", {"battle": OB.lineup(eng.camp)["battle_name"]})), "lineup title")
	var rects: Array = []
	for n in panel.find_children("Comp_*", "", true, false) + panel.find_children("TroopCard_*", "", true, false):
		rects.append(_grect(n))
		t.ok(SCREEN.encloses(_grect(n)), "roster card inside the screen: " + str(n.name))
	for n in ["HeroCard", "MapBox", "BtnMarch", "BtnLater"]:
		rects.append(_grect(_find(panel, n)))
		t.ok(SCREEN.encloses(_grect(_find(panel, n))), n + " inside the screen")
	t.ok(_disjoint(rects), "roster cards, hero card, map and buttons do not overlap")
	var intel := int(eng.camp.state["rogue"]["coins"]["intel"])
	await _press(panel, "BtnReveal")
	t.eq(int(eng.camp.state["rogue"]["coins"]["intel"]), intel - 1, "reveal spends an intel coin")
	t.ok(_btn(panel, "BtnReveal") == null, "revealed: the button goes away")
	await _press(panel, "Hero")
	t.ok(bool(panel.get("_hero")), "hero card toggles the protagonist")
	await _press(panel, "BtnMarch")
	var begin: Array = eng.sent.filter(func(s: Array) -> bool: return s[0] == "campaign.battle_begin")
	t.ok(not begin.is_empty() and bool(begin[0][1]["protagonist"]), "march sends the lineup")
	panel.queue_free()
	await t.frames(3)


# ================================================================ 战果

func _test_result() -> void:
	var eng := FakeEngine.new()
	eng.battle("skirmish_a", ["dantes", "gourgaud"], ["line", "jager"], true)
	eng.state["phase"] = "over"
	eng.result_override = {"outcome": "victory", "victory_kind": "hold", "stars": 2, "turns": 7, "morale": 4, "kills": 9, "leaks": 3,
		"rewards": {"franc": 50, "gold": 0, "medal": 1}, "order_done": true,
		"fallen": [{"unit": "dantes", "rolled": true, "coins": 3, "coin_faces": [0, 1, 0], "died": false, "was_scarred": false},
			{"unit": "gourgaud", "rolled": false, "captured": false}], "routed": ["line_1"], "trust_up": []}
	var panel = RPanel.new()
	panel.fast_anim = true
	panel.bind(eng, null)
	_host(panel)
	panel.open({})
	await t.frames(3)
	t.eq((_find(panel, "Outcome") as Label).text, Ui.text("over_victory"), "big outcome title")
	var toss := _find(panel, "Coins_dantes") as Control
	t.ok(toss != null and toss.is_visible_in_tree(), "fate coins shown")
	t.ok(_find(panel, "HdCoins_dantes") != null, "HD coins drawn over the coin toss")
	t.ok((_find(panel, "Verdict_dantes") as Label).text != "", "verdict written after the coins")
	var cont := _btn(panel, "BtnContinue")
	t.ok(cont != null and cont.is_visible_in_tree() and not cont.disabled and SCREEN.encloses(cont.get_global_rect()), "continue button ready")
	for n in ["StatsCard", "FatesCard", "Stars"]:
		t.ok(SCREEN.encloses(_grect(_find(panel, n))), n + " inside the screen")
	await _press(panel, "BtnContinue")
	t.ok(eng.sent.any(func(s: Array) -> bool: return s[0] == "campaign.battle_finish"), "continue settles the battle")
	panel.queue_free()
	await t.frames(3)


# ================================================================ 小工具

func _disjoint(rects: Array) -> bool:
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			if (rects[i] as Rect2).grow(-1.0).intersects((rects[j] as Rect2).grow(-1.0)):
				print("OVERLAP ", rects[i], " ", rects[j])
				return false
	return true


func _text(node: Node) -> String:
	var out := PackedStringArray()
	for n in [node] + node.find_children("*", "", true, false):
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		if n is Label or n is Button:
			out.append(str(n.text))
	return "\n".join(out)


func _strip_comments(src: String) -> String:
	var out := ""
	var in_str := false
	var i := 0
	while i < src.length():
		var c := src.unicode_at(i)
		if in_str and c == 92:
			out += src.substr(i, 2)
			i += 2
			continue
		if c == 34:
			in_str = not in_str
		if c == 35 and not in_str:
			while i < src.length() and src.unicode_at(i) != 10:
				i += 1
			continue
		out += src.substr(i, 1)
		i += 1
	return out


func _strings(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var code := _strip_comments(src)
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for m in re.search_all(code):
		out.append(m.get_string(1))
	return out
