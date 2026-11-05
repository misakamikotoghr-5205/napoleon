# Existing CardGame.tscn, real hub/reply controls, and campaign save/continue.
# This test never sends gameplay commands directly to the engine.
# The ocean campaign plays on the HD hub (scripts/cards/ui/hub/hub_panel.gd) laid over the pixel table: its cards stand
# for the hand's cards (story, battle, big fate, camp business, demands, kit), its end button for the close-day button.
# Camp business, big fate, demands and kit open the HD business panel (hub_card_panel.gd, registered over slots / read);
# month open, settle, chapter change and the ending open the HD phase panel (hub_phase_panel.gd).
# Story cards open the full-screen story VN (kind vn, scripts/cards/ui/vn/vn_panel.gd): its lines are clicked
# through (advance), and its choice menu buttons carry the same reply_id meta the old dialog's replies did.
# Every scene's battle (battle v2) is fought through the real battle UI: the hand's battle card opens the
# lineup sheet, its 出征 button opens the battle panel, deploy cards / grid cells / facing arrows / unit action
# buttons / command cards / 交火 drive the fight (a simple deterministic policy, battle_policy.gd, picks the
# control), and the result panel's 继续 settles it; a defeat goes through the existing big fate card dialog.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG4/rg4_harness.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/battle_policy.gd")
const BATTLE_KINDS := ["battle_lineup", "battle_v2", "battle_result"]
const ROUTE := [
	["prologue", "secure_passage"], ["scene01", "seal_evidence"],
	["scene02", "expose_sabre"], ["scene03", "audit_accounts"],
	["scene04", "prepare_escape"], ["scene05", "redeem_emperor"],
	["scene06", "establish_rations"], ["scene07", "expose_viper"],
	["scene08", "prepare_operation"], ["scene09", "capture_viper"],
	["scene10", "audit_alliance"], ["scene11", "expose_vigo"],
	["scene12", "cut_orichalcum"], ["finale", "close_ledger"],
]
const PROLOGUE_APPRAISALS := ["watch_mark", "watch_weight", "watch_ring", "faria_letter"]

var t
var game: CardGameRoot
var _commands: Array = []
var _chapters: Dictionary = {}
var _appraisals := 0
var _prologue_dialogue := ""
var _old_campaign := ""
var _had_campaign := false
var _legacy_files: Dictionary = {}
var _battles: Array = []
var _hover_checked := false
var _fight_confirms := 0


func _initialize() -> void:
	_had_campaign = OS.has_environment("DEHOUDANG_CAMPAIGN")
	_old_campaign = OS.get_environment("DEHOUDANG_CAMPAIGN")
	OS.unset_environment("DEHOUDANG_CAMPAIGN")
	t = T.new(self, "OCEAN_ui")
	t.run_async(_body)


func _body() -> void:
	await _run()
	await _dispose_game()
	var bus := root.get_node_or_null("CardBus") as CardEventBus
	if bus != null and bus.command_done.is_connected(_command_done):
		bus.command_done.disconnect(_command_done)
	if _had_campaign:
		OS.set_environment("DEHOUDANG_CAMPAIGN", _old_campaign)
	else:
		OS.unset_environment("DEHOUDANG_CAMPAIGN")


func _run() -> void:
	# Read the real legacy locations only: this campaign must never write there.
	for file in ["profile.json", "suspend.json", "stage_00.json"]:
		var path: String = CardSave.LEGACY_ROOT + "/" + file
		_legacy_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	await _boot()
	t.ok(game.title != null, "existing root opens a real title")
	t.ok(game.engine is CardEngine, "existing root uses the real engine")
	t.ok(game.keeper != null, "0.9 run keeper remains active")
	t.ok(_visible_text(game.title).contains("远洋"), "unchanged 0.9 title receives the campaign text")
	t.ok(game.title.get_script().resource_path.ends_with("hub/hub_title.gd"), "the ocean campaign opens the HD title")
	t.ok(game.title.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "the HD title filters smoothly")
	t.ok(not _visible_text(game.title).contains("打出"), "the title hint names the real camp buttons")
	var seed_field := game.title.get_node_or_null("RunBox/Seed") as LineEdit
	t.ok(seed_field != null, "0.9 title keeps the editable seed field")
	if seed_field == null:
		return
	var suggested := seed_field.text
	if not await _press(game.title.get_node_or_null("RunBox/Content/Reseed") as Button, "title changes suggested seed"):
		return
	t.ok(seed_field.text != suggested, "title reseed changes the suggestion")
	seed_field.text = "1815"
	if not await _press(game.title.get_node_or_null("new") as Button, "title new"):
		return
	t.ok(game.title == null, "title new closes the title")
	t.eq(game.engine.query(&"campaign").get("scene_id"), "prologue", "default new game selects ocean prologue")
	t.eq((game.engine as CardEngine).ctx.state.data.get("seed"), 1815, "title seed reaches the campaign engine")
	t.ok(FileAccess.file_exists(t.user_dir() + "/saves/suspend.json"), "0.9 keeper preserves the new campaign autosave")
	t.eq(_profile().current().get("status"), "open", "title creates an open ocean ledger")
	t.eq(_profile().current().get("seed"), 1815, "ocean profile records the typed seed")
	_assert_profile_progress("new ledger")
	if not await _cancel_new_and_continue():
		return
	if not await _advance_to_day():
		return
	var text := _visible_text(game)
	t.ok(text.contains("维尔福"), "existing protagonist widget displays the new protagonist")
	t.ok(text.contains("先令"), "existing money widget displays the new currency")
	var uid := "story:prologue"
	var choices: Array = game.engine.query(&"card", {"uid": uid}).get("choices", [])
	var actual_apps: Array = []
	for choice in choices:
		var id := str(choice.get("id", ""))
		if id.begins_with("action:appraise:"):
			actual_apps.append(id.trim_prefix("action:appraise:"))
	t.eq(actual_apps, PROLOGUE_APPRAISALS, "prologue exposes all four appraisal actions")
	if not await _open_card(uid):
		return
	var locked := _reply("action:choose:secure_passage")
	t.ok(locked != null and locked.disabled, "unexamined watch cannot unlock the evidence-based passage choice")
	t.ok(_prologue_dialogue.contains("贝勒罗丰") or _prologue_dialogue.contains("蒙托隆")
		or _prologue_dialogue.contains("大军团的账簿"), "actual dialogue contains the new story")
	await _close_play()
	for row in ROUTE:
		var scene_id := str(row[0])
		if not await _advance_to_day():
			return
		var campaign: Dictionary = game.engine.query(&"campaign")
		t.eq(campaign.get("scene_id"), scene_id, "UI route reaches " + scene_id)
		if str(campaign.get("scene_id", "")) != scene_id:
			return
		_chapters[str(campaign.get("chapter_id", ""))] = true
		_assert_profile_progress(scene_id)
		if scene_id == "scene01":
			t.eq(campaign.get("chapter_id"), "st_helena", "passage reaches the Saint Helena chapter")
			if not await _resume_from_title():
				return
			if not await _press(game.hub.find_child("BtnHubRelics", true, false) as Button, "hub relics button"):
				return
			await t.frames(3)
			t.eq(str(game.host.top_kind()), "relics", "the hub relics button opens the relics page")
			var relic_drawer := game.host.top_panel()
			t.ok(relic_drawer != null and relic_drawer.get_script().resource_path.ends_with("hub/hub_list_panel.gd"),
				"campaign relics are the HD list page, not the pixel drawer")
			t.ok(game.host.drawer_panel() == null, "no pixel drawer opens for the relics")
			if relic_drawer != null:
				t.ok(_visible_text(relic_drawer).contains("怀表"), "the relics page displays the prologue watch")
				relic_drawer.dismiss()
				await t.frames(3)
		uid = "story:" + scene_id
		choices = game.engine.query(&"card", {"uid": uid}).get("choices", [])
		for choice in choices:
			var id := str(choice.get("id", ""))
			if id.begins_with("action:appraise:"):
				if not await _act(uid, id):
					return
				_appraisals += 1
				var remaining: Array = game.engine.query(&"card", {"uid": uid}).get("choices", [])
				t.ok(not remaining.any(func(c: Dictionary) -> bool: return str(c.get("id", "")) == id),
					"completed appraisal disappears from choices: " + id)
		# The medicine is obtained by the first story choice. Submit both live
		# demands before their deadline through the same visible reply controls.
		if scene_id == "scene02":
			for demand in ["medicine", "bond"]:
				if not await _act("demand:" + demand, "action:demand:" + demand):
					return
		if not await _fight_battle(uid, "action:choose:" + str(row[1])):
			return
		if not await _act(uid, "action:choose:" + str(row[1])):
			return
		t.no_leaks(game.engine.view(), "campaign UI view after " + scene_id)
		print("OCEAN UI SCENE " + scene_id)
	t.eq(_chapters.keys(), ["prologue", "st_helena", "new_elba", "nautilus"], "UI traverses the prologue and three main parts")
	t.eq(_battles.size(), ROUTE.size(), "every scene's battle is fought through the battle UI")
	t.ok(_battles.filter(func(b: Array) -> bool: return b[1] == "victory").size() >= ROUTE.size() - 3, "the simple policy wins most battles: " + str(_battles))
	t.ok(_appraisals >= 40, "UI executes the full appraisal route")
	t.eq(game.engine.view().get("phase"), "game_over", "actual choices reach an ending")
	await t.frames(5)
	t.eq(str(game.host.top_kind()), "game_over", "existing ending panel opens")
	var ending := game.host.top_panel()
	t.ok(ending != null and ending.is_visible_in_tree(), "ending panel is visible")
	if ending != null:
		var ending_text := _visible_text(ending)
		t.ok(ending_text.contains("同盟"), "ending panel contains campaign ending text")
	t.eq(_profile().current().get("status"), "closed", "campaign ending closes the 0.9 ledger")
	t.eq(_profile().closed_count(), 1, "campaign ending creates exactly one shelf entry")
	var ending_reason := str(game.engine.view().get("game_over_reason", ""))
	var ending_hash := (game.engine as CardEngine).state_hash()
	await _dispose_game()
	await _boot()
	var run_box := game.title.get_node_or_null("RunBox")
	t.ok(run_box != null, "0.9 run box survives campaign restart")
	if run_box != null:
		t.eq(run_box.spines().size(), 1, "closed campaign appears on the actual title shelf")
		var title_text := _visible_text(game.title)
		t.ok(not title_text.contains("1938") and not title_text.contains("德厚当"), "campaign title does not mix in the legacy setting")
	if not await _press(game.title.get_node_or_null("continue") as Button, "continue completed campaign"):
		return
	t.eq((game.engine as CardEngine).state_hash(), ending_hash, "ending continuation retains exact state")
	t.eq(_profile().current().get("status"), "closed", "continuing a finished campaign keeps its ledger closed")
	t.eq(_profile().closed_count(), 1, "continuing an ending does not duplicate shelf entries")
	if not await _new_ledger_confirmation():
		return
	for path in _legacy_files:
		var contents: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		t.eq(contents, _legacy_files[path], "ocean title/profile flow leaves legacy file untouched: " + path)
	var failed: Array = _commands.filter(func(row: Array) -> bool: return not bool(row[2]))
	t.eq(failed, [], "all commands emitted by real UI controls succeed")
	print("OCEAN UI COMPLETE chapters=%d appraisals=%d commands=%d ending=%s battles=%s" % [
		_chapters.size(), _appraisals, _commands.size(), ending_reason, str(_battles)])


func _boot() -> void:
	game = load(CardIds.ROOT_SCENE).instantiate() as CardGameRoot
	root.add_child(game)
	await t.frames(2)
	var bus := root.get_node("CardBus") as CardEventBus
	if not bus.command_done.is_connected(_command_done):
		bus.command_done.connect(_command_done)
	game.boot({"mock": false, "bus": bus, "guide": "off", "campaign": "ocean_pawn",
		"save_dir": t.user_dir() + "/saves", "settings_path": t.user_dir() + "/settings.json"})
	game.allow_quit = false
	game.stage.fast = true
	game.host.fast = true
	game.dialog.chars_per_sec = 0
	CardText.set_show_drafts(false)
	await t.frames(3)
	t.eq(CardSave.root(), t.user_dir() + "/saves", "interactive campaign uses its own save and profile directory")


func _profile() -> CardProfile:
	return CardProfile.load_or_new(t.user_dir() + "/saves", false)


func _assert_profile_progress(context: String) -> void:
	var date: Dictionary = game.engine.view().get("date", {})
	var campaign: Dictionary = game.engine.query(&"campaign")
	t.eq(_profile().current().get("last"), {"stage": date.get("stage"),
		"era": campaign.get("chapter_id"), "stage_day": date.get("stage_day")},
		"autosave updates profile progress: " + context)


func _cancel_new_and_continue() -> bool:
	var before := (game.engine as CardEngine).state_hash()
	var saved := FileAccess.get_file_as_bytes(t.user_dir() + "/saves/suspend.json")
	await _dispose_game()
	await _boot()
	if not await _press(game.title.get_node_or_null("new") as Button, "new over an open campaign"):
		return false
	t.ok(game.title != null and game.title.is_asking_new(), "0.9 title asks before replacing an open campaign")
	if not await _press(game.title.find_child("ConfirmNo", true, false) as Button, "cancel new campaign"):
		return false
	t.eq(FileAccess.get_file_as_bytes(t.user_dir() + "/saves/suspend.json"), saved, "cancel keeps the existing campaign save byte-for-byte")
	t.eq(_profile().current().get("no"), 1, "cancel does not start another ledger")
	if not await _press(game.title.get_node_or_null("continue") as Button, "continue untouched initial campaign"):
		return false
	t.eq((game.engine as CardEngine).state_hash(), before, "initial campaign is immediately resumable")
	return true


func _new_ledger_confirmation() -> bool:
	await _dispose_game()
	await _boot()
	if not await _press(game.title.get_node_or_null("new") as Button, "start second ledger after ending"):
		return false
	t.eq(_profile().current().get("no"), 2, "closed campaign starts ledger two")
	t.eq(_profile().closed_count(), 1, "new ledger preserves the finished campaign")
	_assert_profile_progress("second ledger start")
	for step in [["prologue", "buy_passage"], ["scene01", "aid_longwood"]]:
		if not await _advance_to_day() or not await _retreat_battle() \
				or not await _act("story:" + str(step[0]), "action:choose:" + str(step[1])):
			return false
	if not await _advance_to_day():
		return false
	_assert_profile_progress("second ledger after reaching scene02")
	var last: Dictionary = _profile().current().get("last", {}).duplicate(true)
	await _dispose_game()
	await _boot()
	if not await _press(game.title.get_node_or_null("new") as Button, "replace open second ledger"):
		return false
	t.ok(game.title != null and game.title.is_asking_new(), "open ledger replacement requires the existing confirmation")
	if not await _press(game.title.find_child("ConfirmYes", true, false) as Button, "confirm third ledger"):
		return false
	t.eq(_profile().current().get("no"), 3, "confirmed replacement opens exactly one new ledger")
	t.eq(_profile().closed_count(), 2, "replaced campaign is archived once")
	t.eq(_profile().data.get("chronicle", [])[1].get("reason"), "abandoned", "replaced campaign records abandonment")
	var archived: Dictionary = _profile().data.get("chronicle", [])[1]
	t.eq([archived.get("stage"), archived.get("stage_day")], [last.get("stage"), last.get("stage_day")],
		"cold-boot abandonment records the latest automatically saved chapter and scene")
	_assert_profile_progress("confirmed third ledger start")
	t.ok(FileAccess.file_exists(t.user_dir() + "/saves/suspend.json"), "confirmed new campaign retains its own continuation save")
	if not await _test_roguelike_ui():
		return false
	return true


func _test_roguelike_ui() -> bool:
	if not await _advance_to_day():
		return false
	# 1. Play Monopoly March, Weekly Calendar, Companion Squad, and Prop cards via real hand & dialog replies
	if not await _act("march", "action:roll_dice"):
		return false
	if not await _act("calendar", "action:schedule:recruit"):
		return false
	if not await _act("squad", "action:recruit:friday"):
		return false
	if not await _act("prop:prop_field_ration", "action:use_prop:prop_field_ration"):
		return false
	# 2. Verify Contacts drawer displays recruited companions and kept Monopoly props
	var contacts_panel := game.host.open_panel(&"contacts", {})
	await t.frames(3)
	t.ok(contacts_panel != null and contacts_panel.is_visible_in_tree(), "contacts drawer opens for companions")
	if contacts_panel != null:
		var c_text := _visible_text(contacts_panel)
		t.ok(c_text.contains("唐泰斯") and c_text.contains("星期五"), "contacts drawer shows starter and newly recruited companions")
		contacts_panel.dismiss()
		await t.frames(3)
	# 3. The battle card opens the battle v2 lineup sheet: protagonist line, intel reveal, 稍后 keeps the lineup
	if not await _open_battle_card():
		return false
	var sheet := game.host.top_panel()
	t.eq(str(game.host.top_kind()), "battle_lineup", "battle card opens the lineup sheet")
	var sheet_text := _visible_text(sheet)
	for part in ["出征名单", "唐泰斯", "星期五", "军心 +3、奖赏 ×1.5、倒下阵亡 25%、本场猎官 ?", "出征"]:
		t.ok(sheet_text.contains(part), "lineup sheet shows " + part)
	var intel := int(game.engine.query(&"campaign")["coins"]["intel"])
	if not await _press(sheet.find_child("BtnReveal", true, false) as Button, "reveal the hunters with an intel coin"):
		return false
	t.eq(int(game.engine.query(&"campaign")["coins"]["intel"]), intel - 1, "reveal costs one intel coin")
	var hunters := int(game.engine.query(&"campaign.battle2")["lineup"]["protagonist"]["hunters"])
	t.ok(_visible_text(sheet).contains("本场猎官 %d" % hunters), "revealed hunter count shows on the lineup")
	# 试玩反馈：名单页有战场预览；在场名额排满时带主角让最后一支部队留守；关掉再打开记得上次的名单
	t.ok(sheet.find_child("MiniMap", true, false) != null, "lineup sheet shows the battlefield preview")
	var lu0: Dictionary = game.engine.query(&"campaign.battle2")["lineup"]
	var cap := int(lu0["caps"]["field"])
	var troops0: Array = (sheet.get("_pick_t") as Array).duplicate()
	var full := (sheet.get("_pick_c") as Array).size() + troops0.size() >= cap
	if not await _press(sheet.find_child("Hero", true, false) as Button, "bring the protagonist"):
		return false
	t.eq(bool(sheet.get("_hero")), true, "the protagonist joins the lineup")
	t.eq((sheet.get("_pick_t") as Array).size(), troops0.size() - (1 if full else 0), "a full lineup sends its last troop home for him")
	var first := str((lu0["candidates"] as Array)[0]["id"])
	if not await _press(sheet.find_child("Pick_" + first, true, false) as Button, "toggle " + first):
		return false
	var kept_c: Array = (sheet.get("_pick_c") as Array).duplicate()
	var kept_t: Array = (sheet.get("_pick_t") as Array).duplicate()
	if not await _press(sheet.find_child("BtnLater", true, false) as Button, "lineup later before reopening"):
		return false
	if not await _open_battle_card():
		return false
	sheet = game.host.top_panel()
	t.eq([sheet.get("_pick_c"), sheet.get("_pick_t"), sheet.get("_hero")], [kept_c, kept_t, true], "reopening the lineup keeps the last picks")
	if not await _press(sheet.find_child("Hero", true, false) as Button, "protagonist stays home again"):
		return false
	if not await _press(sheet.find_child("BtnLater", true, false) as Button, "lineup later"):
		return false
	t.eq(str(game.engine.query(&"campaign.battle2")["phase"]), "lineup", "closing the sheet keeps the lineup")
	t.no_leaks(game.engine.view(), "no forbidden keys after roguelike UI flow")
	return true


## 本场的仗：剧情决定先是灰的；打出「战场」牌 → 出征名单 → 战场（策略选控件）→ 战果 → 继续；输了走大命运牌
func _fight_battle(story_uid: String, story_action: String) -> bool:
	var before: Array = game.engine.query(&"card", {"uid": story_uid}).get("choices", []).filter(
		func(c: Dictionary) -> bool: return str(c.get("id", "")) == story_action)
	t.ok(not before.is_empty() and not bool(before[0].get("enabled", true)) and str(before[0].get("reason_key", "")) == "ocean.reason.battle",
		"story choice waits for the scene battle: " + story_action)
	if not await _open_battle_card():
		return false
	var sheet := game.host.top_panel()
	t.eq(str(game.host.top_kind()), "battle_lineup", "battle card opens the lineup sheet")
	var lu: Dictionary = game.engine.query(&"campaign.battle2").get("lineup", {})
	var want := _policy_lineup(lu)
	for pass_no in [0, 1]:
		for c in lu.get("candidates", []):
			var cid := str(c["id"])
			var on: bool = cid in (sheet.get("_pick_c") as Array)
			if on != (cid in want["companions"]) and on == (pass_no == 0):
				if not await _press(sheet.find_child("Pick_" + cid, true, false) as Button, "lineup companion " + cid):
					return false
		for tr in lu.get("troops", []):
			var tid := str(tr["id"])
			var on_t: bool = tid in (sheet.get("_pick_t") as Array)
			if on_t != (tid in want["troops"]) and on_t == (pass_no == 0):
				if not await _press(sheet.find_child("Troop_" + tid, true, false) as Button, "lineup troop " + tid):
					return false
	if not await _press(sheet.find_child("BtnMarch", true, false) as Button, "march out"):
		return false
	t.eq(str(game.host.top_kind()), "battle_v2", "march opens the battle panel")
	var panel := game.host.top_panel()
	if _battles.is_empty():
		# 战报第 1 回合就有内容（开战那一行和本回合指挥阶段），不再是「还没交过火」
		var v0: Dictionary = game.engine.query(&"campaign.battle2").get("view", {})
		t.ok(_visible_text(panel.find_child("Log", true, false)).contains(str(v0.get("name", "?"))), "turn-1 battle report shows the opening line")
	for _step in range(400):
		var v: Dictionary = game.engine.query(&"campaign.battle2").get("view", {})
		if str(v.get("phase", "")) != "command":
			break
		var act := _policy_action(v, game.engine.query(&"campaign.battle_preview"))
		if act.is_empty():
			if not _hover_checked:
				await _check_hover(panel, v)
			var risk := str((panel.find_child("FightWarning", true, false) as Label).text)
			if not await _press(panel.find_child("BtnFight", true, false) as Button, "fight"):
				return false
			# 预演说会战败或有人倒下：交火先确认一次（顶栏常驻同一句警告）
			var confirm := panel.find_child("BtnFightYes", true, false) as Button
			t.eq(confirm != null and confirm.is_visible_in_tree(), risk != "", "fight asks for confirmation exactly when the HUD warns: " + risk)
			if confirm != null and confirm.is_visible_in_tree():
				_fight_confirms += 1
				if not await _press(confirm, "fight anyway"):
					return false
			continue
		if not await _ui_action(panel, v, act):
			return false
	var q: Dictionary = game.engine.query(&"campaign.battle2")
	t.ok(bool(q.get("over", false)), "battle ends within the turn limit")
	if not await _press(panel.find_child("BtnResult", true, false) as Button, "open the result"):
		return false
	t.eq(str(game.host.top_kind()), "battle_result", "result panel opens")
	var res: Dictionary = game.engine.query(&"campaign.battle2").get("result", {})
	_battles.append([str(q.get("scene", "")), str(res.get("outcome", "")), int(res.get("stars", 0))])
	var result_panel := game.host.top_panel()
	for f in res.get("fallen", []):
		if bool(f.get("rolled", false)):
			var toss := result_panel.find_child("Coins_" + str(f["unit"]), true, false)
			t.ok(toss != null and toss.is_visible_in_tree(), "fate coins shown for " + str(f["unit"]))
	if not await _press(result_panel.find_child("BtnContinue", true, false) as Button, "settle the battle"):
		return false
	if bool(game.engine.query(&"campaign")["big_fate"]["pending"]):
		if not await _wait_replies():
			return false
		var choice := "action:big_fate:ransom_supply"
		var button := _reply(choice)
		if button == null or button.disabled:
			choice = "action:big_fate:desperate_breakout"
			button = _reply(choice)
		if not await _press(button, "big fate " + choice):
			return false
		await _close_play()
	t.ok(bool(game.engine.query(&"campaign.battle2").get("resolved", false)), "scene battle resolved: " + str(q.get("scene", "")))
	var after: Array = game.engine.query(&"card", {"uid": story_uid}).get("choices", []).filter(
		func(c: Dictionary) -> bool: return str(c.get("id", "")) == story_action)
	t.ok(not after.is_empty() and str(after[0].get("reason_key", "")) != "ocean.reason.battle", "battle no longer blocks " + story_action)
	print("OCEAN UI BATTLE %s %s %d confirms=%d" % (_battles.back() + [_fight_confirms]))
	return true


## New books can supply another public-query policy without replacing the real UI driver.
func _policy_lineup(lineup: Dictionary) -> Dictionary:
	return Policy.lineup(lineup)


func _policy_action(view: Dictionary, preview: Dictionary) -> Array:
	return Policy.next_action(view, preview)


## 撤出也能了结本场的仗（不会卡死）：出征 → 撤退 → 确认 → 战果 → 继续，不转大命运
func _retreat_battle() -> bool:
	if not await _open_battle_card():
		return false
	var sheet := game.host.top_panel()
	if not await _press(sheet.find_child("BtnMarch", true, false) as Button, "march out before retreating"):
		return false
	var panel := game.host.top_panel()
	if not await _press(panel.find_child("BtnRetreat", true, false) as Button, "retreat"):
		return false
	t.ok(_visible_text(panel).contains("全军撤出战场"), "retreat asks for confirmation")
	if not await _press(panel.find_child("BtnRetreatYes", true, false) as Button, "confirm retreat"):
		return false
	if not await _press(panel.find_child("BtnResult", true, false) as Button, "open the retreat result"):
		return false
	var res := game.host.top_panel()
	t.ok(_visible_text(res).contains("撤出"), "result shows the retreat")
	if not await _press(res.find_child("BtnContinue", true, false) as Button, "settle the retreat"):
		return false
	t.eq(bool(game.engine.query(&"campaign")["big_fate"]["pending"]), false, "retreat does not open the big fate")
	t.ok(bool(game.engine.query(&"campaign.battle2").get("resolved", false)), "retreat resolves the scene battle")
	return true


## 一步打法换成界面上的点击：部署牌 → 格子 → 朝向箭头；点单位 → 动作按钮（→ 目标格）；军令牌；后方调度
func _ui_action(panel: CardPanel, v: Dictionary, act: Array) -> bool:
	var cmd := str(act[0])
	var a: Dictionary = act[1]
	var count := (game.engine as CardEngine).command_log().size()
	match cmd:
		"deploy":
			if not await _press(panel.find_child("Deploy_" + str(a["unit"]), true, false) as Button, "deploy card " + str(a["unit"])):
				return false
			if not await _press(panel.find_child("Cell_%d_%d" % [int(a["col"]), int(a["row"])], true, false) as Button, "deploy cell"):
				return false
			if not await _press(panel.find_child("Face_" + str(a["facing"]), true, false) as Button, "facing " + str(a["facing"])):
				return false
		"card":
			if not await _press(panel.find_child("Card_%d" % int(a["index"]), true, false) as Button, "command card"):
				return false
		_:
			var uid := str(a["unit"])
			var dispatch := panel.find_child("Dispatch_" + uid, true, false) as Button
			if cmd == "skill" and dispatch != null:
				if not await _press(dispatch, "rear dispatch"):
					return false
			else:
				var u: Dictionary = {}
				for x in v.get("battle_units", []):
					if str(x["uid"]) == uid:
						u = x
				if not await _press(panel.find_child("Cell_%d_%d" % [int(u["col"]), int(u["row"])], true, false) as Button, "select " + uid):
					return false
				var act_name := "Act_" + cmd
				if cmd == "skill" and a.has("mode"):
					act_name = "Act_skill_" + str(a["mode"])
				if not await _press(panel.find_child(act_name, true, false) as Button, act_name + " " + uid):
					return false
				if a.has("col"):
					if not await _press(panel.find_child("Cell_%d_%d" % [int(a["col"]), int(a["row"])], true, false) as Button, "target cell"):
						return false
	var log := (game.engine as CardEngine).command_log()
	t.ok(log.size() > count and str(log.back()[0]) == "campaign.battle_cmd" and str(log.back()[1].get("cmd", "")) == cmd,
		"battle UI sends %s for %s" % [cmd, str(a)])
	return log.size() > count


## 悬停一个我方单位：右栏写出交火后的兵力（campaign.battle_preview）
func _check_hover(panel: CardPanel, v: Dictionary) -> void:
	for u in v.get("battle_units", []):
		if str(u["state"]) != "ok" or str(u["kind"]) == "barricade":
			continue
		var cell := panel.find_child("Cell_%d_%d" % [int(u["col"]), int(u["row"])], true, false) as Button
		cell.mouse_entered.emit()
		await t.frames(2)
		var info := panel.find_child("Info", true, false)
		var text := _visible_text(info)
		t.ok(text.contains(str(u["name"])) and (text.contains("交火后")), "hover shows the predicted strength after the fight")
		cell.mouse_exited.emit()
		await t.frames(1)
		_hover_checked = true
		return


func _open_battle_card() -> bool:
	await _close_play()
	var button: Button = game.hub.card_button("battle") if game.hub != null else null
	t.ok(button != null, "hub shows the battle card")
	if button == null:
		return false
	if not await _press(button, "play battle card"):
		return false
	for _i in range(20):
		if str(game.host.top_kind()) in BATTLE_KINDS:
			return true
		await t.frames(1)
	t.ok(false, "battle card opens a battle panel: " + str(game.host.top_kind()))
	return false


func _wait_replies() -> bool:
	var hub_card: Button = game.hub.card_button("big_fate") if game.hub != null else null
	if hub_card != null and not str(game.host.top_kind()) in ["slots", "read"]:
		if not await _press(hub_card, "hub big fate card"):
			return false
	for _i in range(100):
		if not _reply_buttons().is_empty():
			return true
		if game.dialog != null and not game.dialog.is_idle():
			game.dialog.skip()
		await t.frames(1)
	t.ok(false, "big fate dialog exposes replies")
	return false


func _dispose_game() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
		game = null
		await t.frames(4)


func _resume_from_title() -> bool:
	var before := (game.engine as CardEngine).state_hash()
	var before_log := (game.engine as CardEngine).command_log()
	t.ok(CardSave.exists(CardSave.suspend_path()), "UI progress creates a continuation save")
	await _dispose_game()
	await _boot()
	t.ok(game.title != null, "fresh root returns to title")
	if not await _press(game.title.get_node_or_null("continue") as Button, "title continue"):
		return false
	t.ok(game.title == null, "title continue closes the title")
	t.eq((game.engine as CardEngine).state_hash(), before, "title continue restores the exact campaign state")
	t.eq((game.engine as CardEngine).command_log(), before_log, "title continue restores command history")
	t.eq(game.engine.query(&"campaign").get("scene_id"), "scene01", "title continue resumes Saint Helena")
	return true


func _advance_to_day() -> bool:
	for _i in range(40):
		if str(game.engine.view().get("phase", "")) == "day":
			await t.frames(3)
			return true
		var panel := game.host.top_panel()
		if panel != null:
			if str(game.host.top_kind()) not in ["month_open", "year_jump", "settle", "month_close"]:
				t.ok(false, "unexpected progress panel: " + str(game.host.top_kind()))
				return false
			panel.autoplay_step()
		else:
			if not await _press(game.hub.end_button() as Button, "progress to day"):
				return false
		await t.frames(3)
	t.ok(false, "existing progress controls cannot reach day: " + str(game.engine.view().get("phase", "")))
	return false


func _open_card(uid: String) -> bool:
	await _close_play()
	var button: Button = game.hub.card_button(uid) if game.hub != null else null
	t.ok(button != null, "hub shows " + uid)
	if button == null:
		return false
	if not await _press(button, "play " + uid):
		return false
	for _i in range(100):
		var vn := _vn()
		if vn != null:
			# 剧情牌：满屏剧情 VN，一句一句点过去，直到出抉择菜单
			if uid == "story:prologue":
				_prologue_dialogue += _visible_text(vn) + "\n"
			if not _reply_buttons().is_empty():
				t.ok(uid.begins_with("story:"), "only story cards open the story VN: " + uid)
				return true
			vn.call("advance")
		else:
			if str(game.host.top_kind()) in ["slots", "read"] and not _reply_buttons().is_empty():
				t.ok(not uid.begins_with("story:"), "story card opens the story VN, not the business panel: " + uid)
				t.ok(game.host.is_fullscreen(game.host.top_kind()), "business panel is the full-screen HD panel: " + uid)
				return true
		await t.frames(1)
	t.ok(false, "card panel fails to expose replies for " + uid)
	return false


## 开着的剧情 VN（满屏叠层 kind vn），没有就是 null
func _vn() -> CardPanel:
	if game == null or game.host == null or str(game.host.top_kind()) != "vn":
		return null
	return game.host.top_panel()


func _act(uid: String, action: String) -> bool:
	if not await _open_card(uid):
		return false
	var button := _reply(action)
	t.ok(button != null, "dialog has requested reply " + action)
	if button == null:
		print("OCEAN UI REPLIES " + str(_reply_ids()))
		return false
	t.ok(not button.text.is_empty() and not button.text.begins_with("action:"), "reply displays authored text: " + action)
	var count := (game.engine as CardEngine).command_log().size()
	if not await _press(button, action):
		return false
	var log := (game.engine as CardEngine).command_log()
	t.ok(log.size() > count, "reply dispatches a gameplay command: " + action)
	if log.size() <= count:
		return false
	var found := false
	for entry in log.slice(count):
		if str(entry[0]) == "card.choose" and entry[1].get("uid") == uid and entry[1].get("choice") == action:
			found = true
	t.ok(found, "reply uses the existing card.choose contract: " + action)
	await _close_play()
	return found


func _close_play() -> void:
	var panel := game.host.play_panel()
	if panel != null:
		panel.dismiss()
	# 高清事务面板（slots / read 换上的满屏叠层）：“稍后再来”
	for _i in range(3):
		if not str(game.host.top_kind()) in ["slots", "read"]:
			break
		game.host.top_panel().dismiss()
		await t.frames(1)
	# 剧情 VN：“稍后”（Esc 一样先关记录、恢复隐藏的界面，再关面板）
	for _i in range(4):
		var vn := _vn()
		if vn == null:
			break
		vn.dismiss()
		await t.frames(1)
	await t.frames(3)


func _press(button: Button, context: String) -> bool:
	var ready := button != null and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
	t.ok(ready, "visible enabled button: " + context)
	if not ready:
		return false
	button.pressed.emit()
	await t.frames(3)
	return true


func _reply(action: String) -> Button:
	for button in _reply_buttons():
		if str(button.get_meta("reply_id", "")) == action:
			return button
	return null


func _reply_buttons() -> Array[Button]:
	var out: Array[Button] = []
	var roots: Array = [game.dialog]
	var vn := _vn()
	if vn != null:
		roots.append(vn)
	if str(game.host.top_kind()) in ["slots", "read"]:
		roots.append(game.host.top_panel())
	for r in roots:
		if r == null:
			continue
		for node in _walk(r):
			if node is Button and node.has_meta("reply_id") and node.is_visible_in_tree():
				out.append(node)
	return out


func _reply_ids() -> Array:
	var out: Array = []
	for button in _reply_buttons():
		out.append(str(button.get_meta("reply_id", "")))
	return out


func _visible_text(node: Node) -> String:
	var texts := PackedStringArray()
	for child in _walk(node):
		if child is CanvasItem and not child.is_visible_in_tree():
			continue
		if child is Label or child is Button:
			texts.append(str(child.text))
		elif child is RichTextLabel:
			texts.append(child.get_parsed_text())
	return "\n".join(texts)


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out


func _command_done(cmd: StringName, args: Dictionary, ok: bool) -> void:
	_commands.append([str(cmd), args.duplicate(true), ok])
