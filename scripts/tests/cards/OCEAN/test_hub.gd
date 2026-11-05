# 远洋战役高清营地（scripts/cards/ui/hub/）的无头测试 OCEAN_hub：
# 真游戏根场景开新局：开部是高清过场面板；营地盖住像素柜台（手牌扇、旧打烊铜牌看不见），顶栏有日期、金库和各项指标，
# 左栏伙伴和部队、中间当前剧情和本场战事、右栏营地事务和行军箱；营地事务开高清事务面板（kind 仍是 slots / read，
# 满屏），选一项发 card.choose、写出结果、回营地；账簿是只读的；规矩开只读面板；结账开高清日终面板（settle），
# 金色按钮发 settle.next；打输一仗营地出现红色大命运卡，开出来是同一种高清面板（战场远景、红边），选完写“已经了结”；
# 终局面板是高清的、按钮回标题。最后查 scripts/cards/ui/hub/ 守仓库规矩（没有 class_name、没有颜色字面量、
# 字符串字面量只有 ASCII、用到的 hd_* 键都在 palette.dev.json）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const HubData = preload("res://scripts/cards/ui/hub/hub_data.gd")
const HUB_DIR := "res://scripts/cards/ui/hub"
const PALETTE_DEV := "res://data/cards/theme/palette.dev.json"

var t
var game: CardGameRoot
var _old_campaign := ""
var _had_campaign := false
var _closed: Array = []


func _initialize() -> void:
	_had_campaign = OS.has_environment("DEHOUDANG_CAMPAIGN")
	_old_campaign = OS.get_environment("DEHOUDANG_CAMPAIGN")
	OS.unset_environment("DEHOUDANG_CAMPAIGN")
	t = T.new(self, "OCEAN_hub")
	CardText.set_show_drafts(false)
	t.run_async(_body)


func _body() -> void:
	_test_data()
	_test_house_rules()
	await _boot()
	await _test_month_open()
	await _test_hub_layout()
	await _test_business_panel()
	await _test_read_panels()
	await _test_settle()
	await _test_big_fate()
	await _test_game_over()
	if game != null and is_instance_valid(game):
		game.queue_free()
		game = null
		await t.frames(4)
	if _had_campaign:
		OS.set_environment("DEHOUDANG_CAMPAIGN", _old_campaign)
	else:
		OS.unset_environment("DEHOUDANG_CAMPAIGN")


func _test_data() -> void:
	for key in ["brand", "roster_title", "camp_title", "kit_title", "log_title", "panel_prompt", "panel_later", "panel_back",
			"phase.settle_btn", "phase.over_btn", "gauge.treasury", "coin.gold", "cards.signage.label"]:
		t.ok(HubData.text(key) != "" or key.begins_with("cards."), "hub_ui.json has " + key)
	for uid in ["signage", "town", "backdoor", "resources", "march", "calendar", "squad", "status", "big_fate", "battle",
			"demand:bond", "item:x", "prop:y", "companion:z"]:
		var spec := HubData.card_spec(uid)
		t.ok(str(spec.get("label", "")) != "" and str(spec.get("icon", "")) != "", "card look for " + uid)
	t.ok(HubData.same_title("序曲·贝勒罗丰号的双面怀表", "序曲：贝勒罗丰号的双面怀表"), "same title ignores punctuation")
	t.ok(not HubData.same_title("第一部·黑岩孤岛与基督山的幽灵", "詹姆斯敦的雨水"), "different titles differ")
	var paged := "第一句话说完。\n\n第二句也说完。"
	t.eq(HubData.unpage(paged), "第一句话说完。\n第二句也说完。", "unpage puts each page on its own line")
	t.eq(str(HubData.scene_bg("prologue").get("id", "")), "bellerophon_hold", "hub background follows the scene's first VN background")


func _boot() -> void:
	game = load(CardIds.ROOT_SCENE).instantiate() as CardGameRoot
	root.add_child(game)
	await t.frames(2)
	var bus := root.get_node("CardBus") as CardEventBus
	game.boot({"mock": false, "bus": bus, "guide": "off", "campaign": "ocean_pawn",
		"save_dir": t.user_dir() + "/saves", "settings_path": t.user_dir() + "/settings.json"})
	game.allow_quit = false
	game.stage.fast = true
	game.host.fast = true
	await t.frames(3)
	t.ok(game.title != null, "real title first")
	t.ok(game.hub == null or not game.hub.visible, "no hub over the title")
	var new_btn := game.title.get_node_or_null("new") as Button
	new_btn.pressed.emit()
	await t.frames(4)


func _test_month_open() -> void:
	t.eq(str(game.host.top_kind()), "month_open", "a new run opens on the chapter card")
	var p := game.host.top_panel()
	t.ok(p != null and p.get_script().resource_path.ends_with("hub/hub_phase_panel.gd"), "the chapter card is the HD phase panel")
	t.ok(game.host.is_fullscreen(&"month_open"), "the HD phase panel is full screen")
	t.ok(p != null and p.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "HD phase panel filters linearly")
	var btn := p.find_child("BtnPhase", true, false) as Button
	t.ok(btn != null and btn.is_visible_in_tree(), "chapter card has its gold button")
	t.ok(_text(p).contains("序曲"), "chapter card names the part")
	var before := (game.engine as CardEngine).command_log().size()
	btn.pressed.emit()
	await t.frames(3)
	t.eq((game.engine as CardEngine).command_log().size(), before, "month_open closes without a command (the hub's button starts the part)")
	await _to_day()


func _test_hub_layout() -> void:
	var hub = game.hub
	t.ok(hub != null and hub.visible and hub.is_visible_in_tree(), "the HD hub is on screen during the day")
	if hub == null:
		return
	t.ok(hub.z_index > 200 and hub.get_index() == game.table.get_index() + 1, "hub sits over the whole table, under the modal host")
	t.ok(hub.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "hub filters linearly")
	t.ok(not (game.get("_end") as Control).visible, "the pixel close-day plate is hidden")
	var text := _text(hub)
	for part in ["维尔福", "先令", "同盟威望", "敌方警戒", "体力与士气", "伙伴", "部队", "营地事务", "行军箱", "航海日志", "金币"]:
		t.ok(text.contains(part), "hub shows " + part)
	t.ok(not text.contains("BG "), "no asset ids on screen")
	for uid in ["story:prologue", "battle", "signage", "town", "backdoor", "resources", "march", "calendar", "squad", "status"]:
		var b: Button = hub.card_button(uid)
		t.ok(b != null and b.is_visible_in_tree(), "hub card " + uid)
	var end: Button = hub.end_button()
	t.ok(end != null and end.is_visible_in_tree() and _text(end).contains("扎营"), "hub end button carries the close-day label")
	# 第一天：剧情没定、仗没打、营地还有事可办——结账不是金色主按钮，副行写还剩什么
	var left: PackedStringArray = hub.pending_parts()
	t.ok(left.size() >= 2, "day one has pending business: " + " / ".join(left))
	t.ok(_text(end).contains(HubData.text("end_pending.story")), "the end button says the story is undecided")
	t.ok(str(end.get_meta(&"hd_button", "")) != "primary", "the end button is not the gold primary while work is pending")
	t.ok(not _text(end).contains("今天的事都办了"), "the end button no longer claims the day is done")
	# 营地事务栏放得下八件，不压到行军箱
	var camp := hub.find_child("Camp", true, false) as Control
	var kit := hub.find_child("Kit", true, false) as Control
	t.ok(camp != null and kit != null and camp.get_global_rect().end.y <= kit.get_global_rect().position.y,
		"the camp list ends above the kit chest")
	# 顶栏副标题先写场次
	var scene_l := hub.find_child("Scene", true, false) as Label
	t.ok(scene_l != null and scene_l.text.begins_with("第 "), "the top bar subtitle starts with the scene counter")
	await _test_hd_shell_panels()
	# 点剧情卡开 VN，点战场卡开出征名单（都是原来那几块满屏面板）
	(hub.card_button("story:prologue") as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "vn", "the story card opens the story VN")
	game.host.top_panel().dismiss()
	await t.frames(3)
	(hub.card_button("battle") as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "battle_lineup", "the battle card opens the lineup")
	var sheet := game.host.top_panel()
	var later := sheet.find_child("BtnLater", true, false) as Button
	if later != null:
		later.pressed.emit()
	await t.frames(3)


## 菜单、设置、信物、档案、帮助都是高清满屏叠层（不是像素的暂停框和抽屉）
func _test_hd_shell_panels() -> void:
	var hub = game.hub
	(hub.find_child("BtnHubMenu", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "pause", "the menu button opens the pause menu")
	var p := game.host.top_panel()
	t.ok(p != null and p.get_script().resource_path.ends_with("hub/hub_pause_panel.gd"), "pause is the HD menu")
	t.ok(_text(p).contains(HubData.text("pause.resume")) and not _text(p).contains("柜台"), "pause says back to camp, not counter")
	(p.find_child("settings", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "settings", "pause opens settings")
	var st := game.host.top_panel()
	t.ok(st != null and st.get_script().resource_path.ends_with("hub/hub_settings_panel.gd"), "settings is the HD panel")
	t.ok(game.host.drawer_panel() == null, "settings is not a pixel drawer")
	(st.find_child("Back", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "pause", "closing settings returns to the pause menu")
	p = game.host.top_panel()
	(p.find_child("help", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "help", "pause help opens help")
	var hp := game.host.top_panel()
	t.ok(hp != null and hp.get_script().resource_path.ends_with("hub/hub_card_panel.gd"), "help is the HD rules page")
	t.ok(_text(hp).contains("开始剧情") and not _text(hp).contains("打出金色"), "the rules name the real camp buttons")
	hp.dismiss()
	await t.frames(3)
	while game.host.top_panel() != null:
		game.host.close_top()
		await t.frames(2)
	for pair in [["BtnHubRelics", "relics"], ["BtnHubDossier", "dossier"]]:
		(hub.find_child(pair[0], true, false) as Button).pressed.emit()
		await t.frames(3)
		t.eq(str(game.host.top_kind()), pair[1], pair[1] + " opens")
		var lp := game.host.top_panel()
		t.ok(lp != null and lp.get_script().resource_path.ends_with("hub/hub_list_panel.gd"), pair[1] + " is the HD list page")
		t.ok(game.host.drawer_panel() == null and game.host.is_fullscreen(StringName(pair[1])), pair[1] + " is a full-screen overlay")
		if pair[1] == "dossier":
			var tiles: Dictionary = lp.call("tiles")
			t.ok(tiles.size() >= 10, "the dossier lists the cast")
			var other := str(tiles.keys()[2])
			(tiles[other] as Button).pressed.emit()
			await t.frames(2)
			t.eq(str(lp.call("person")), other, "clicking a tile shows that person")
		game.host.close_top()
		await t.frames(3)
	t.eq(str(game.host.top_kind()), "", "back to the hub after the shell panels")


func _test_business_panel() -> void:
	var hub = game.hub
	var money0 := _gauge("treasury")
	(hub.card_button("town") as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "slots", "camp business keeps the slots kind")
	var p := game.host.top_panel()
	t.ok(p.get_script().resource_path.ends_with("hub/hub_card_panel.gd"), "slots is the HD business panel in the ocean campaign")
	t.ok(game.host.is_fullscreen(&"slots"), "business panel is full screen")
	var text := _text(p)
	t.ok(text.contains("市镇补给") and not text.contains("Town"), "business panel title uses the camp's short name")
	t.ok(text.contains("如何处置"), "business panel asks the question")
	var buttons: Array = p.call("choice_buttons")
	t.ok(buttons.size() == 3, "town offers its three choices")
	var visit: Button = null
	for b in buttons:
		if str(b.get_meta("reply_id")) == "action:visit:town":
			visit = b
	t.ok(visit != null and not visit.disabled, "visit is open")
	var n := (game.engine as CardEngine).command_log().size()
	visit.pressed.emit()
	await t.frames(3)
	var log := (game.engine as CardEngine).command_log()
	t.ok(log.size() > n and log.back() == ["card.choose", {"uid": "town", "choice": "action:visit:town"}], "the choice goes through card.choose")
	t.eq(_gauge("treasury"), money0 - 100, "the engine applies the visit")
	var res := str(p.call("result_text"))
	t.ok(res.contains("已办") and res.contains("-100"), "the panel writes what was done and what changed: " + res.replace("\n", " "))
	var again: Button = null
	for b in p.call("choice_buttons"):
		if str(b.get_meta("reply_id")) == "action:visit:town":
			again = b
	t.ok(again != null and again.disabled and (again.find_child("Reason", false, false) as Label).text != "", "a used choice greys out with a reason")
	var back := p.find_child("BtnLater", true, false) as Button
	t.ok(back != null and back.text == HubData.text("panel_back"), "after a choice the tail button returns to camp")
	back.pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "", "back to the hub")
	t.ok(_text(hub).contains(str(money0 - 100)), "hub top bar shows the new treasury")


func _test_read_panels() -> void:
	var hub = game.hub
	(hub.card_button("status") as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "read", "the ledger keeps the read kind")
	var p := game.host.top_panel()
	t.ok((p.call("choice_buttons") as Array).is_empty(), "the ledger has no choices")
	t.ok(_text(p).contains("军费：") and _text(p).contains("同盟威望"), "the ledger shows the summary")
	t.ok(not _text(p).contains("\n\n\n"), "no empty pages between ledger rows")
	var n := (game.engine as CardEngine).command_log().size()
	(p.find_child("BtnLater", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.eq((game.engine as CardEngine).command_log().size(), n, "reading sends no command")
	(hub.find_child("BtnHubRules", true, false) as Button).pressed.emit()
	await t.frames(3)
	var rules := game.host.top_panel()
	t.ok(rules != null and _text(rules).contains("军需官手册"), "the rules button opens the rules page")
	rules.dismiss()
	await t.frames(3)
	(hub.find_child("BtnHubRelics", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "relics", "the relics button opens the relic drawer")
	game.host.close_top()
	await t.frames(3)


func _test_settle() -> void:
	var hub = game.hub
	(hub.end_button() as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.engine.view().get("phase", "")), "settle", "the hub's end button ends the day")
	t.eq(str(game.host.top_kind()), "settle", "settle opens")
	var p := game.host.top_panel()
	t.ok(p.get_script().resource_path.ends_with("hub/hub_phase_panel.gd"), "settle is the HD phase panel")
	t.ok(_text(p).contains("军费："), "settle shows the report")
	var btn := p.find_child("BtnPhase", true, false) as Button
	btn.pressed.emit()
	await t.frames(3)
	var log := (game.engine as CardEngine).command_log()
	t.ok(log.any(func(r: Array) -> bool: return str(r[0]) == "settle.next"), "the gold button sends settle.next")
	await _to_day()


func _test_big_fate() -> void:
	var e := game.engine
	e.send(&"campaign.battle_prepare", {})
	e.send(&"campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
	for _i in range(30):
		if str(e.query(&"campaign.battle2").get("view", {}).get("phase", "")) != "command":
			break
		e.send(&"campaign.battle_cmd", {"cmd": "fight", "args": {}})
	e.send(&"campaign.battle_finish", {})
	await t.frames(3)
	t.ok(bool(e.query(&"campaign")["big_fate"]["pending"]), "a lost battle leaves a big fate")
	var card: Button = game.hub.card_button("big_fate")
	t.ok(card != null and card.is_visible_in_tree(), "the hub shows the red big fate card")
	t.ok(game.hub.card_button("battle") == null, "the battle card steps aside for the big fate")
	card.pressed.emit()
	await t.frames(3)
	var p := game.host.top_panel()
	t.eq(str(game.host.top_kind()), "slots", "the big fate opens the HD business panel")
	t.ok(p.find_child("Bg_battle_backdrop", true, false) != null, "big fate uses the battle backdrop")
	t.ok(_text(p).contains("大命运"), "big fate title")
	var pick: Button = null
	for b in p.call("choice_buttons"):
		if str(b.get_meta("reply_id")) == "action:big_fate:desperate_breakout":
			pick = b
	t.ok(pick != null and not pick.disabled, "breakout is always open")
	pick.pressed.emit()
	await t.frames(3)
	t.ok(not bool(e.query(&"campaign")["big_fate"]["pending"]), "the big fate is resolved through card.choose")
	t.ok(_text(p).contains(HubData.text("panel_gone")) and (p.call("choice_buttons") as Array).is_empty(), "the panel says it is settled")
	(p.find_child("BtnLater", true, false) as Button).pressed.emit()
	await t.frames(3)
	t.ok(game.hub.card_button("big_fate") == null, "the red card leaves the hub")


func _test_game_over() -> void:
	var p := game.host.open_panel(&"game_over", {"reason": "alliance"})
	await t.frames(3)
	t.ok(p != null and p.get_script().resource_path.ends_with("hub/hub_phase_panel.gd"), "the ending is the HD phase panel")
	t.ok(_text(p).contains("四海同盟"), "the ending shows its title")
	_closed = []
	p.close_requested.connect(func(r: Dictionary) -> void: _closed.append(r))
	(p.find_child("BtnPhase", true, false) as Button).pressed.emit()
	t.eq(_closed, [{"to_title": true}], "the ending's button returns to the title")
	await t.frames(4)


## scripts/cards/ui/hub/ 守仓库规矩
func _test_house_rules() -> void:
	var palette = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_DEV))
	var colors: Dictionary = palette.get("colors", {}) if typeof(palette) == TYPE_DICTIONARY else {}
	var n := 0
	for f in DirAccess.get_files_at(HUB_DIR):
		if not f.ends_with(".gd"):
			continue
		n += 1
		var src := FileAccess.get_file_as_string(HUB_DIR + "/" + f)
		var code := _strip_comments(src)
		t.ok(RegEx.create_from_string("(?m)^class_name\\s").search(code) == null, f + ": no class_name")
		t.ok(RegEx.create_from_string("Color\\s*\\(|Color8\\s*\\(|Color\\.html|Color\\.from_").search(code) == null, f + ": no colour literals")
		for lit in _strings(src):
			var ascii := true
			for i in lit.length():
				if lit.unicode_at(i) > 127:
					ascii = false
			t.ok(ascii, "%s: ASCII string literal '%s'" % [f, lit])
			if RegEx.create_from_string("^(hd|bthud)_[a-z0-9_]+$").search(lit) != null:
				t.ok(colors.has(lit), "%s: palette key %s exists" % [f, lit])
	t.ok(n >= 5, "hub scripts are there (%d)" % n)


# ================================================================ 小工具

func _to_day() -> void:
	for _i in range(40):
		if str(game.engine.view().get("phase", "")) == "day" and game.host.top_panel() == null:
			await t.frames(2)
			return
		var p := game.host.top_panel()
		if p != null:
			p.autoplay_step()
		else:
			(game.hub.end_button() as Button).pressed.emit()
		await t.frames(3)
	t.ok(false, "reach the day: " + str(game.engine.view().get("phase", "")))


func _gauge(id: String) -> int:
	for g in game.engine.query(&"campaign").get("gauges", []):
		if str(g["id"]) == id:
			return int(g["amount"])
	return -1


func _text(node: Node) -> String:
	var out := PackedStringArray()
	for c in _walk(node):
		if c is CanvasItem and not (c as CanvasItem).is_visible_in_tree():
			continue
		if c is Label or c is Button:
			out.append(str(c.text))
	return "\n".join(out)


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out


func _strings(src: String) -> Array:
	var out: Array = []
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for line in src.split("\n"):
		var s := line.strip_edges()
		if s.begins_with("#"):
			continue
		var code := line
		var hash := _comment_at(line)
		if hash >= 0:
			code = line.substr(0, hash)
		for m in re.search_all(code):
			out.append(m.get_string(1))
	return out


func _comment_at(line: String) -> int:
	var in_str := false
	var i := 0
	while i < line.length():
		var c := line.unicode_at(i)
		if in_str and c == 92:
			i += 2
			continue
		if c == 34:
			in_str = not in_str
		elif c == 35 and not in_str:
			return i
		i += 1
	return -1


func _strip_comments(src: String) -> String:
	var out := PackedStringArray()
	for line in src.split("\n"):
		var h := _comment_at(line)
		out.append(line if h < 0 else line.substr(0, h))
	return "\n".join(out)
