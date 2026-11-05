# 卡牌版根场景。1.3：场景层、对话框、手牌扇、HUD、标签抽屉、打烊按钮叠在同一张桌上。
# 别人的控件用 CardIds.widget_scene 取各主人的场景（X01-b 起 W0 的桩已删）。
# 公开：engine、host、boot、autoplay_step、guide、table、mg_host、title、bus、stage、dialog、hand、hero、checks。
# 私有名 _on_close_day、_sync_phase_panel 留给 W0 的测试。
# 真引擎是默认：发行包（主场景 CardGame.tscn、不带参数）、--cards、boot({}) 都是 CardEngine；
# 只有 --cards-mock[=夹具] 或 boot({mock: true}) 才用 Mock（测试、截图显式传 mock: true）。
# TODO(design): close_requested 的 next / open_uid / to_title / quit。
class_name CardGameRoot
extends Control

const TABLE_SCENE := "res://scenes/cards/table/CardTable.tscn"
const SETTINGS_SCRIPT := "res://scripts/town/settings.gd"
const MUSIC_SCRIPT := "res://scripts/cards/ui/shell/card_music.gd"
const DrawerScript := preload("res://scripts/cards/ui/table/drawer_host.gd")
const HudScript := preload("res://scripts/cards/ui/table/hud.gd")
const CloseDayLabel := preload("res://scripts/cards/ui/table/close_day_label.gd")
const ToastScript := preload("res://scripts/cards/ui/table/toast.gd")
const RunKeeper := preload("res://scripts/cards/meta/run_keeper.gd")
## 远洋战役的高清营地（盖在像素柜台上面），和它换上的高清面板（slots / read → 事务面板，开部 / 结账 / 换部 / 终了 → 过场面板）
const HubScript := preload("res://scripts/cards/ui/hub/hub_panel.gd")
const MAP_SCRIPT := "res://scripts/cards/ui/map/map_panel.gd"
const HUB_OVERRIDES := {
	&"slots": "res://scripts/cards/ui/hub/hub_card_panel.gd",
	&"read": "res://scripts/cards/ui/hub/hub_card_panel.gd",
	&"help": "res://scripts/cards/ui/hub/hub_card_panel.gd",
	&"month_open": "res://scripts/cards/ui/hub/hub_phase_panel.gd",
	&"settle": "res://scripts/cards/ui/hub/hub_phase_panel.gd",
	&"year_jump": "res://scripts/cards/ui/hub/hub_phase_panel.gd",
	&"game_over": "res://scripts/cards/ui/hub/hub_phase_panel.gd",
	&"pause": "res://scripts/cards/ui/hub/hub_pause_panel.gd",
	&"settings": "res://scripts/cards/ui/hub/hub_settings_panel.gd",
	&"relics": "res://scripts/cards/ui/hub/hub_list_panel.gd",
	&"dossier": "res://scripts/cards/ui/hub/hub_list_panel.gd",
}
## 远洋战役的高清标题（继承 CardTitle，只换样子）；旧版战役照旧用 CardTitle.tscn
const HubTitleScript := preload("res://scripts/cards/ui/hub/hub_title.gd")
const OceanBridge := preload("res://scripts/cards/campaign/ocean_bridge.gd")
## 层次（b02）：手牌扇在牌桌里，z 不超过 150（C02）。画在它上面的东西都抬到更高的 z，
## 而且在树里排得更靠后，所以“画在上面的”就是“先吃到点击的”。
## 牌桌顶层（标签、街头、抽屉框）200；标题插在牌桌里、标签前面，160；叠层宿主 300（抽屉面板、打烊按钮、叠层，
## 按这个先后）；小游戏 400；飘字 450。
const Z_TITLE := 160
## 远洋战役的高清营地：盖住整张牌桌（含牌桌顶层 200），在叠层宿主（300）下面；抽屉框挪到它上面（260）
const Z_HUB := 250
const Z_TABLE_TOP := 200
const Z_MODAL := 300
const Z_MINIGAME := 400
const Z_TOAST := 450
## “打烊 · 下一天”（SPEC §10.1）：圆角 16、3px 边、径向渐变；主行毛笔 26，副行 14。
const END_RADIUS := 16.0
const END_HOVER_SCALE := 1.04
const END_PRESS_SCALE := 0.98
const END_BREATH_S := 0.6
## C08 panels that read digits / Space / Enter in their own _unhandled_input.
const C08_KEY_PANELS: Array[StringName] = [&"end_day", &"night", &"settle", &"month_open", &"month_close"]
## Drawers that read Space / Enter themselves (focus rows). Other drawers leave keys to the table.
const KEY_DRAWERS: Array[StringName] = [&"settings"]
## morning 自动开张（玩家路径，_cmdline_opts 打开）：先停这么久，让晨间画面亮一下。
const AUTO_DAY_DELAY_S := 0.6

var engine: CardEngineApi = null
var host: CardModalHost = null
var mg_host: CardMiniGameHost = null
var guide: CardGuide = null
var table = null
var title: CardTitle = null
var bus: CardEventBus = null
var stage: CardStage = null
var dialog: CardDialogApi = null
var hand: CardHandApi = null
var hero: CardHeroApi = null
var checks: CardChecksApi = null
var allow_quit: bool = true
var quit_requested: bool = false
## Rogue v1 old-ledger keeper (scripts/cards/meta/run_keeper.gd); null off the interactive real-engine path.
var keeper = null
## 远洋战役的高清营地（scripts/cards/ui/hub/hub_panel.gd）；旧版战役一直是 null
var hub = null

var _booted: bool = false
var _opts: Dictionary = {}
var _month_open_seen: Dictionary = {}
var _phase_seen: Dictionary = {}
var _panel_seen: Dictionary = {}
var _scene_story_seen: Dictionary = {}
## Lines a panel closed with ({"say"}) during settle before the settle stage opened (a stocktake pick): handed to the
## settle panel to say after its report, keyed by the settle's "settle:<abs_day>" (acceptance 3).
var _settle_after: Dictionary = {}
var _attempts: Dictionary = {}
## Autoplay: how often a requested panel (_open_key: kind, uid, day) was opened. A panel that closes without settling
## what the engine asked (the prison cell after the day's try) is not reopened forever; the day goes on.
var _auto_opened: Dictionary = {}
var _return_to_pause: bool = false
var _drawer = null
var _hud = null
var _street: Control = null
var _end: Button = null
var _end_title: Label = null
var _end_sub: Label = null
var _end_face: Control = null
var _end_glow: Panel = null
var _end_breath: Tween = null
var _end_scale: Tween = null
## 打烊按钮现在是哪种样子：&"day" &"ready" &"confirm" &"night"（测试读它）。
var _end_tone: StringName = &"day"
var _toast = null
## 上一份视图里的钱和档位（换了才飘字、出提示条）；开局、读档后第一份视图只记不提示。
var _last_marks: Dictionary = {}
var _music = null
var _wired: Array = []
var _hand_view: Dictionary = {}
var _hud_view: Dictionary = {}
var _auto_day: bool = false
var _auto_day_key: String = ""
var _auto_day_wait: float = 0.0
var _auto_day_poll: float = 0.0
var _boot_errors: PackedStringArray = PackedStringArray()


func _ready() -> void:
	if _booted:
		return
	if get_tree() == null or get_tree().current_scene != self:
		return
	var opts := _cmdline_opts()
	boot(opts)
	if opts.has("autoplay"):
		_autoplay_and_quit(int(opts["autoplay"]))


## Rogue v1 (ROGUE_V1.md §8.1): the old-ledger keeper, only on the interactive real-engine path (boot calls this in
## its real-engine branch); skip_title, autoplay and fixtures keep today's seed rule and write no profile.
func _add_keeper(opts: Dictionary, db: CardDB) -> void:
	if not bool(opts.get("skip_title", false)) and not opts.has("autoplay") and str(opts.get("fixture", "")) == "":
		keeper = RunKeeper.new()
		keeper.setup(engine, bus, _opts, db, func(key: String) -> void: _toast.show_text(CardText.ui(key)))
		add_child(keeper)


func _autoplay_and_quit(steps: int) -> void:
	for i in range(steps):
		await get_tree().process_frame
		autoplay_step()
	await get_tree().process_frame
	var v := engine.view()
	print("CARDS AUTOPLAY %s %d" % [v.get("phase", ""), int(v.get("date", {}).get("stage_day", 0))])
	get_tree().quit(0)


func boot(opts: Dictionary) -> void:
	if _booted:
		return
	_booted = true
	_opts = opts.duplicate()
	add_to_group("card_settings_listeners")
	bus = opts.get("bus") if opts.get("bus") is CardEventBus else get_node_or_null("/root/CardBus") as CardEventBus
	var fixture := str(opts.get("fixture", ""))
	var use_mock := bool(opts.get("mock", false))
	if use_mock:
		var mock := MockCardEngine.new(bus)
		if fixture != "":
			mock.load_fixture(fixture)
		engine = mock
	else:
		engine = CardEngine.new(bus)
		var default_dir := OceanBridge.default_save_dir(opts) if OceanBridge.selected(opts) else CardSave.LEGACY_ROOT
		CardSave.set_root(str(opts.get("save_dir", default_dir)))
		# The title and permanent widgets need text before game.new/game.load.
		var db := CardDB.load_all(str(opts.get("data_root", CardDB.DEFAULT_ROOT)),
			{"only_examples": bool(opts.get("only_examples", false)), "ship": CardShip.is_ship()})
		# game.new refuses a data set with errors; the title shows these when it does.
		_boot_errors = db.errors()
		CardText.setup(db)
		_add_keeper(opts, db)
	_auto_day = bool(opts.get("auto_day", false)) and fixture == ""
	# Labels without a local font override inherit the bundled Chinese font.
	# System fallback otherwise repeatedly shapes the real campaign's dialogue.
	# The card UI theme (reskin SPEC 4.1): wood buttons, light labels, modal panels, variations.
	theme = CardTheme.build_theme()
	_build_table()
	host = CardModalHost.new()
	host.name = "ModalHost"
	host.stage = stage
	host.dialog = dialog
	host.checks = checks
	host.hand = hand
	host.play_layer = table.get_node("PlayLayer")
	host.drawer = _drawer
	host.settings_path = str(_opts.get("settings_path", ""))
	host.cards_settings_path = _cards_path()
	host.bind(engine, bus)
	host.follow_up.connect(_on_follow_up, CONNECT_DEFERRED)
	host.z_index = Z_MODAL
	add_child(host)
	host.set_band(_end)
	if _ocean_mode():
		host.overrides = HUB_OVERRIDES.duplicate()
	# 挪进宿主时 remove_child 会触发 tree_exiting，把先前的登记注销掉；所以挪好以后再登记（新手指引 gd.d1.close 指着它）。
	CardAnchors.register(&"a.btn.close_day", _end)
	mg_host = CardMiniGameHost.new()
	mg_host.name = "MiniGameHost"
	mg_host.z_index = Z_MINIGAME
	mg_host.bind(engine, bus)
	add_child(mg_host)
	_toast = ToastScript.new()
	_toast.name = "Toast"
	_toast.z_index = Z_TOAST
	add_child(_toast)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	guide = load("res://scenes/cards/shell/GuideOverlay.tscn").instantiate()
	guide.theme = theme   # a CanvasLayer stops theme inheritance; the guide gets the same card UI theme
	layer.add_child(guide)
	guide.bind(engine, bus)
	guide.set_enabled(_setting_guide_hints())
	var g := str(opts.get("guide", ""))
	var autoplay := opts.has("autoplay")
	guide.set_cmdline("off" if g == "" and (fixture != "" or autoplay) else g)
	_music = load(MUSIC_SCRIPT).new()
	_music.name = "Music"
	add_child(_music)
	if _music.has_method("bind"):
		_music.bind(bus)
	_apply_music_volume()
	if dialog != null and not dialog.reply_chosen.is_connected(_on_reply):
		dialog.reply_chosen.connect(_on_reply)
	# The root forwards the shared dialog's replies to the play panel, so stage
	# panels given this dialog must not also subscribe (GPT #42 P1, C04 double send).
	if host != null and dialog != null and host.dialog == dialog:
		host.routes_replies = true
	if hand != null and not hand.card_played.is_connected(_on_card_played):
		hand.card_played.connect(_on_card_played)
	if table != null and table.has_signal("card_pressed") and not table.card_pressed.is_connected(_on_table_card_pressed):
		table.card_pressed.connect(_on_table_card_pressed)
	if stage != null:
		if not stage.hotspot_pressed.is_connected(_on_hotspot):
			stage.hotspot_pressed.connect(_on_hotspot)
		if not stage.card_dropped.is_connected(_on_card_dropped):
			stage.card_dropped.connect(_on_card_dropped)
	if hero != null and not hero.person_pressed.is_connected(_on_person):
		hero.person_pressed.connect(_on_person)
	_apply_pace()
	bus.view_changed.connect(_on_view_changed)
	bus.request_panel.connect(_on_request_panel)
	bus.ui_event.connect(_on_ui_event)
	_refresh_all(engine.view())
	if bool(opts.get("skip_title", false)):
		_start.call_deferred()
	else:
		_show_title()
		_play_cue.call_deferred(&"title")


func autoplay_step() -> bool:
	if stage != null:
		stage.fast = true
	if dialog != null:
		dialog.chars_per_sec = 0
	if title != null:
		_on_title(&"new")
		return true
	if mg_host.is_active():
		mg_host.autoplay_current(0.8)
		return true
	var overlay := host.top_overlay()
	if overlay != null:
		if not overlay.autoplay_step():
			host.close_panel(overlay)
		return true
	if host.drawer_open():
		host.close_panel(host.drawer_panel())
		return true
	var play := host.play_panel()
	if play != null:
		if dialog != null and not dialog.is_idle():
			dialog.skip()
		elif not play.autoplay_step():
			host.close_panel(play)
		return true
	if dialog != null and not dialog.is_idle():
		dialog.skip()
		return true
	var v := engine.view()
	match str(v.get("phase", "")):
		"month_open":
			var month := int(v.get("date", {}).get("stage", 0))
			var op: Dictionary = v.get("open_panel", {})
			if not _month_open_seen.has(month):
				_sync_phase_panel()
			elif str(op.get("kind", "")) != "":
				host.open_panel(StringName(str(op["kind"])), op.get("args", {}))
			else:
				engine.send(&"month.begin")
		"morning":
			engine.send(&"day.begin")
		"day":
			return _autoplay_day(v)
		"night", "settle", "month_close", "year_jump", "game_over":
			host.open_panel(StringName(str(v["phase"])), {})
		_:
			return false
	return true


func on_settings_changed() -> void:
	_apply_pace()
	_apply_music_volume()


## 设置里存的音乐音量（0–100，旧四键文件 user://settings.json）用到曲目上。boot 和设置改动时各调一次。
func _apply_music_volume() -> void:
	if _music == null or not _music.has_method("set_volume"):
		return
	var path := str(_opts.get("settings_path", ""))
	if path == "":
		return
	var bag = load(SETTINGS_SCRIPT).new(path)
	bag.load_file()
	_music.set_volume(float(bag.music) / 100.0)


func _exit_tree() -> void:
	# 静态锚点表里的 Callable 会勾住本节点；换场景时必须清掉（合同 §7.10.4）。
	CardAnchors.clear()
	_wired.clear()
	if bus != null and bus.view_changed.is_connected(_on_view_changed):
		bus.view_changed.disconnect(_on_view_changed)
	if bus != null and bus.request_panel.is_connected(_on_request_panel):
		bus.request_panel.disconnect(_on_request_panel)
	if bus != null and bus.ui_event.is_connected(_on_ui_event):
		bus.ui_event.disconnect(_on_ui_event)


func _autoplay_day(v: Dictionary) -> bool:
	var op: Dictionary = v.get("open_panel", {})
	var asked := StringName(str(op.get("kind", "")))
	var okey := _open_key(v)
	if asked != &"" and not host.is_open(asked) and int(_auto_opened.get(okey, 0)) < 2:
		_auto_opened[okey] = int(_auto_opened.get(okey, 0)) + 1
		host.open_panel(asked, op.get("args", {}))
		return true
	for c in v.get("hand", []):
		var uid := str(c.get("uid", ""))
		if str(c.get("panel", "none")) != "none" and int(_attempts.get(uid, 0)) < 2:
			_attempts[uid] = int(_attempts.get(uid, 0)) + 1
			if hand != null:
				hand.play_uid(uid)
			return true
	engine.send(&"day.end", {"confirm": true})
	return true


func _reset_session_ui() -> void:
	_month_open_seen.clear()
	_phase_seen.clear()
	_panel_seen.clear()
	_scene_story_seen.clear()
	_settle_after.clear()
	_attempts.clear()
	_auto_opened.clear()
	_hand_view.clear()
	_hud_view.clear()
	_last_marks.clear()


func _close_title() -> void:
	if dialog != null and host.play_panel() == null:
		dialog.clear()
	if title != null and is_instance_valid(title):
		title.queue_free()
		title = null
	_show_table_top(true)


## 标题压着牌桌时，牌桌顶层（标签、街头、打烊按钮）画在标题上面（z 200 > 160），所以收起来；抽屉框留着，
## 从标题开的设置抽屉照样有框。关标题时放回来（街头按视图）。
func _show_table_top(on: bool) -> void:
	if table == null:
		return
	var tabs := table.get_node_or_null("Tabs") as CanvasItem
	if tabs != null:
		tabs.visible = on
	if _end != null:
		_end.visible = on and hub == null
	if hub != null:
		hub.visible = on
		if on and engine != null:
			_sync_hub(engine.view())
	if _street != null:
		if on and _street.has_method("refresh") and engine != null:
			_street.call("refresh", engine.view())
		elif not on:
			_street.visible = false


func _title_up() -> bool:
	return title != null and is_instance_valid(title) and not title.is_queued_for_deletion()


## 回标题前把这一局留在桌上的东西全收掉：叠层、抽屉、演出面板、小游戏、对话框。
func _close_session_ui() -> void:
	_return_to_pause = false
	_auto_day_key = ""
	set_process(false)
	if mg_host != null and mg_host.is_active():
		mg_host.abort()
	if host != null and host.has_method("close_all"):
		host.close_all()
	if dialog != null:
		dialog.clear()
	if stage != null and stage.has_method("clear_play"):
		stage.clear_play()
	# b32：上一局的手牌不留在标题上（标题也已经画在手牌上面）。
	if hand != null:
		hand.refresh({"phase": "", "hand": [], "kept": [], "night_offers": []})
		_hand_view.clear()


func _start() -> void:
	_reset_session_ui()
	var options := {"seed": int(_opts.get("seed", 7))}
	for key in ["save_dir", "only_examples", "data_root", "campaign", "book", "segment", "stage"]:
		if _opts.has(key):
			options[key] = _opts[key]
	if title != null and title.has_method("selected_game_options"):
		var selected: Dictionary = title.call("selected_game_options")
		if selected.has("entry"):
			options.erase("segment")
			options.erase("stage")
		options.merge(selected, true)
	if keeper != null:
		options = keeper.new_game_options(title, options)
	var result := engine.new_game(options)
	if bool(result.get("ok", false)):
		if keeper != null:
			keeper.after_new_game()
			if guide != null:
				guide.bind(engine, bus)   # re-read progress: the replayed done steps came after game.new's rebuild
		_close_title()
		_sync_phase_panel.call_deferred()
		return
	# 新局开不了（牌的骨架数据有错，game.new 会拒绝；文本和剧情插件有错只警告，不挡新局）：标题上要看得见，不能点了没反应。
	_show_start_error(result)


func _show_start_error(result: Dictionary) -> void:
	if not _title_up() or not title.has_method("show_error"):
		return
	var details := PackedStringArray()
	if engine is CardEngine:
		var db := CardDB.load_all(str(_opts.get("data_root", CardDB.DEFAULT_ROOT)),
			{"only_examples": bool(_opts.get("only_examples", false)), "ship": CardShip.is_ship()})
		details = db.errors()
	if details.is_empty():
		details = _boot_errors
	var lines := PackedStringArray()
	for i in mini(details.size(), 3):
		lines.append(details[i])
	if details.size() > 3:
		lines.append("(+%d)" % (details.size() - 3))
	if lines.is_empty():
		lines.append(str(result.get("err", "")))
	for line in lines:
		print("CARDS NEW GAME FAILED " + line)
	title.show_error(CardText.ui("c16.title.new_failed"), "\n".join(lines))


func _continue(path: String = "") -> void:
	var result := engine.load_game(CardSave.suspend_path() if path == "" else path)
	if not bool(result.get("ok", false)):
		_show_start_error(result)
		return
	_reset_session_ui()
	_close_title()
	_refresh_all(engine.view())
	_sync_phase_panel.call_deferred()


func _on_title(action: StringName) -> void:
	match action:
		&"new":
			_start()
		&"continue":
			_continue()
		&"branch":
			_continue(CardSave.root() + "/" + OceanBridge.BRANCH_FILE)
		&"settings":
			host.open_panel(&"settings", {})
		&"reseed", &"opening":
			if keeper != null:
				keeper.on_title_action(title, action)
		&"quit":
			quit_requested = true
			if allow_quit and get_tree() != null:
				get_tree().quit()


func _on_close_day() -> void:
	# b25（合同 §7.11.11）：抽屉开着时，按下先收回抽屉，再照常打烊（以前收完抽屉就停了，要按第二下）。
	if host.drawer_open():
		# 从暂停打开的设置抽屉：收回去以后不再弹回暂停，接着打烊。
		_return_to_pause = false
		var drawer_panel := host.drawer_panel()
		if drawer_panel != null:
			drawer_panel.dismiss()
	var view := engine.view()
	if str(view.get("phase", "")) == "game_over":
		if host.top_kind() != &"game_over":
			host.open_panel(&"game_over", {})
		return
	var result := engine.send(&"day.end", {"confirm": false})
	if not bool(result.get("ok", false)) and str(result.get("err", "")) == CardIds.ERR_MUST_RESOLVE:
		# 合同 §7.4.7 / W0 自测⑥：要确认就开 end_day。b52：开月时（step begin_month）清单要按“开张”说话，
		# 并能把引擎还等着的面板（被 Esc 关掉的必转轮盘）再开出来——args.pending 就是那块面板，
		# 清单（C08 end_day_confirm.gd）回 close_requested {"next": pending} 即可，根照 result.next 打开。
		var args := {"step": str(result.get("step", "")), "items": result.get("items", [])}
		var op: Dictionary = view.get("open_panel", {})
		if str(op.get("kind", "")) != "":
			args["pending"] = {"kind": str(op["kind"]), "args": op.get("args", {})}
		host.open_panel(&"end_day", args)


func _on_view_changed(_topics: PackedStringArray) -> void:
	_refresh_all(engine.view())
	_sync_phase_panel.call_deferred()


func _sync_phase_panel() -> void:
	if title != null:
		return
	var v := engine.view()
	var phase := str(v.get("phase", ""))
	var month := int(v.get("date", {}).get("stage", 0))
	if phase == "month_open" and not _month_open_seen.has(month):
		_month_open_seen[month] = true
		host.open_panel(&"month_open", {})
		return
	if host.top_panel() != null:
		return
	if phase == "month_open" and _auto_day and _ocean_live() and _month_open_seen.has(month):
		engine.send(&"month.begin")
		if str(engine.view().get("phase", "")) == "morning":
			engine.send(&"day.begin")
		return
	var op: Dictionary = v.get("open_panel", {})
	var okey := _open_key(v)
	if str(op.get("kind", "")) != "" and not _panel_seen.has(okey):
		_panel_seen[okey] = true
		host.open_panel(StringName(str(op["kind"])), op.get("args", {}))
		return
	var key := "%s:%d" % [phase, int(v.get("date", {}).get("abs_day", 0))]
	if phase in ["night", "settle", "month_close", "year_jump", "game_over"] and not _phase_seen.has(key):
		_phase_seen[key] = true
		var after: Array = _settle_after.get(key, [])
		_settle_after.clear()
		host.open_panel(StringName(phase), {"after": after} if not after.is_empty() else {})
	if phase == "day" and not _phase_seen.has(key):
		_phase_seen[key] = true
		_attempts = {}
		_show_news()
	if phase == "day" and _auto_day and _ocean_live() and host.top_panel() == null:
		var c_view: Dictionary = engine.query(&"campaign")
		var sid := str(c_view.get("scene_id", ""))
		if sid != "" and not _scene_story_seen.has(sid):
			_scene_story_seen[sid] = true
			_open_card("story:" + sid)
			return
	if phase == "morning":
		_arm_auto_day(key)
	_sync_music()


## 引擎要开的那块面板（view.open_panel）的记号：每块每天只自动开一次。
func _open_key(v: Dictionary) -> String:
	var op: Dictionary = v.get("open_panel", {})
	return "%s:%s:%d" % [op.get("kind", ""), op.get("args", {}).get("uid", ""), int(v.get("date", {}).get("abs_day", 0))]


## morning 不再空等：玩家路径下（auto_day）停一下就自动开张，和自动打法的 day.begin 一样。
## 打烊 · 下一天照旧随时能点（早上点它就是开张）。测试 boot({...}) 不开 auto_day，行为不变。
func _arm_auto_day(key: String) -> void:
	if not _auto_day or _auto_day_key == key:
		return
	_auto_day_key = key
	_auto_day_wait = 0.0
	_auto_day_poll = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if _auto_day_key == "":
		set_process(false)
		return
	_auto_day_wait += delta
	if _auto_day_wait < AUTO_DAY_DELAY_S:
		return
	# 等的时候每 0.2 秒看一眼就够，不必每帧取 view。
	_auto_day_poll -= delta
	if _auto_day_poll > 0.0:
		return
	_auto_day_poll = 0.2
	if _title_up() or engine == null:
		return
	var v := engine.view()
	var key := "%s:%d" % [str(v.get("phase", "")), int(v.get("date", {}).get("abs_day", 0))]
	if key != _auto_day_key:
		# 已经开张了（玩家自己点了打烊按钮），或者换了阶段。
		_auto_day_key = ""
		set_process(false)
		return
	if host.top_panel() != null or (mg_host != null and mg_host.is_active()):
		return
	# 指引有气泡在讲、或者此刻有一步要亮（两步之间的空档）时一直等，读完点知道了才开张；不设上限。
	# 打烊按钮（早上是“开张”）照常能按，玩家不想听可以自己开张。
	if guide != null and guide.is_pending():
		return
	_auto_day_key = ""
	set_process(false)
	engine.send(&"day.begin")


func _on_request_panel(_kind: StringName, _args: Dictionary) -> void:
	_sync_phase_panel.call_deferred()


func _on_ui_event(ev_name: StringName, _args: Dictionary) -> void:
	if ev_name == &"panel_closed":
		_sync_phase_panel.call_deferred()
		# 满屏面板关了，营地露出来：把盖着时攒下的视图排一遍
		if hub != null and engine != null:
			_sync_hub(engine.view())
	# 夜里变红（SPEC §1 第 9 条）：确认清单关掉时视图不一定再变，按钮要自己再看一眼。
	if ev_name == &"panel_closed" or ev_name == &"panel_opened":
		if engine != null and _end != null:
			_refresh_end(engine.view())
		_sync_music()


func _input(event: InputEvent) -> void:
	var surface := _key_surface(event)
	if surface != null:
		# A minigame or pause/help/settings/wheel overlay is on top. The table
		# hand never sees these keys, but the top surface must still get them
		# (GPT #42 P1): GUI focus inside it and its own _unhandled_input run
		# normally, and _unhandled_key_input below stops them from leaking down.
		# A focused control under the overlay (a hand card) would take Enter as
		# ui_accept, so in that case deliver to the top surface right here.
		if _focus_outside(surface):
			_deliver_top(surface, event)
			if get_viewport() != null:
				get_viewport().set_input_as_handled()
		return
	if _on_key(event) and get_viewport() != null:
		get_viewport().set_input_as_handled()


## Runs after GUI and before every _unhandled_input. Hands digits / Space /
## Enter to the top surface only, then marks them handled so the dialog,
## counter or hand underneath never act on them.
func _unhandled_key_input(event: InputEvent) -> void:
	var surface := _key_surface(event)
	if surface == null:
		return
	_deliver_top(surface, event)
	if get_viewport() != null:
		get_viewport().set_input_as_handled()


## The surface that owns digits / Space / Enter right now, or null when the
## table (or a C08 panel) handles them through _on_key as before.
func _key_surface(event: InputEvent) -> Node:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return null
	var key := event as InputEventKey
	var code := key.keycode
	if code == KEY_NONE:
		code = key.physical_keycode
	if not ((code >= KEY_1 and code <= KEY_9) or code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]):
		return null
	if mg_host != null and mg_host.is_active():
		return mg_host.current if mg_host.current != null else mg_host
	if host == null:
		return null
	if _title_up():
		# 标题上：开着的面板（设置抽屉等）拿键；没开面板时返回 null，键交给标题自己（焦点按钮 / _unhandled_input）。
		return host.top_panel()
	if host.top_kind() in C08_KEY_PANELS:
		return null
	var overlay := host.top_overlay()
	if overlay != null:
		return overlay
	if host.top_kind() in KEY_DRAWERS:
		return host.drawer_panel()
	return null


func _focus_outside(surface: Node) -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var focus := vp.gui_get_focus_owner()
	return focus != null and focus != surface and not surface.is_ancestor_of(focus)


## Same order the engine uses for _unhandled_input (last child first, then
## the parent), limited to the top surface's subtree. Stops once handled.
func _deliver_top(node: Node, event: InputEvent) -> void:
	var vp := get_viewport()
	var count := node.get_child_count()
	for i in range(count - 1, -1, -1):
		var child := node.get_child(i)
		if child == null or not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		_deliver_top(child, event)
		if vp != null and vp.is_input_handled():
			return
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node.is_processing_unhandled_input() and node.can_process() and node.has_method(&"_unhandled_input"):
		node.call(&"_unhandled_input", event)


## C16 的壳测试直接调用这个入口。真按键先走 _input，这里只接没人处理的。
func _unhandled_input(event: InputEvent) -> void:
	_on_key(event)


func _on_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key := event as InputEventKey
	var code := key.keycode
	if code == KEY_NONE:
		code = key.physical_keycode
	if _title_up():
		# 标题压着牌桌：Esc 只关标题上开着的面板；F1、数字、空格、回车都不碰背后的牌桌（暂停、帮助、手牌）。
		if code == KEY_ESCAPE and host != null and host.top_panel() != null:
			host.close_top()
			return true
		return false
	if code == KEY_F1:
		if host.top_kind() == &"help":
			host.close_top()
		else:
			host.open_panel(&"help", {})
		return true
	if code == KEY_ESCAPE:
		if mg_host != null and mg_host.is_active():
			mg_host.abort()
		elif host.top_overlay() == null and not host.drawer_open() and _hand_has_selection():
			# b31：选着一张牌时，第一下 Esc 是“放回手里”（和预览旁的按钮一样），不开暂停。
			_deselect_hand()
		elif host.top_panel() != null:
			host.close_top()
		elif not _return_to_pause:
			host.open_panel(&"pause", {})
		return true
	# Digits / Space / Enter: route by topmost surface. Never drive the table
	# hand while a minigame, pause/help/settings overlay, or C08 panel is up.
	if (code >= KEY_1 and code <= KEY_9) or code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		# Real key presses never get here with a minigame/overlay on top
		# (_input / _unhandled_key_input route them to that surface). Direct
		# callers (C16 shell tests) just must not drive the hand.
		if mg_host != null and mg_host.is_active():
			return false
		if host != null:
			# C08 night/settle/end_day (+ month) own these keys via _unhandled_input.
			if host.top_kind() in C08_KEY_PANELS:
				return false
			if host.top_overlay() != null:
				return false
	if code >= KEY_1 and code <= KEY_9:
		var index := code - KEY_1
		if hub != null and hub.visible:
			# 高清营地盖着手牌扇：数字键不去选看不见的牌
			return true
		if dialog != null and dialog.has_replies() and _press_reply(index):
			pass
		elif hand != null:
			hand.select_index(index)
		return true
	if code == KEY_SPACE or code == KEY_ENTER or code == KEY_KP_ENTER:
		if dialog != null and not dialog.is_idle():
			_advance_dialog()
		elif code == KEY_ENTER or code == KEY_KP_ENTER:
			_enter(event)
		else:
			return false
		return true
	return false


## Enter with the dialog idle (b15). In order: the reply that has focus, the selected hand card,
## then the play panel's own confirm (its default reply: counter 公道价 / 送客, demand accept ...).
## The press is always consumed here, so a focused reply button never fires a second time on release.
func _enter(event: InputEvent) -> void:
	if _press_focused_reply():
		return
	if hand != null and hand.play_selected():
		return
	var play := host.play_panel() if host != null else null
	if play == null or not is_instance_valid(play):
		return
	# C04 (reskin/dialog): CardCounterPanel.confirm_key() -> bool sees the guest off / accepts the counter
	# price / offers the fair price. Other panels may expose on_confirm(); older ones read Enter in their own
	# _unhandled_input (counter_panel._confirm before reskin/dialog), so hand them the key.
	if play.has_method(&"confirm_key"):
		play.call(&"confirm_key")
	elif play.has_method(&"on_confirm"):
		play.call(&"on_confirm")
	else:
		_deliver_top(play, event)


func _press_focused_reply() -> bool:
	var vp := get_viewport()
	if vp == null or dialog == null:
		return false
	var focus := vp.gui_get_focus_owner()
	if not (focus is Button) or not dialog.is_ancestor_of(focus):
		return false
	var button := focus as Button
	if button.disabled or not button.is_visible_in_tree():
		return false
	button.pressed.emit()
	return true


func _hand_has_selection() -> bool:
	if hand == null:
		return false
	if hand.has_method(&"has_selection"):
		return bool(hand.call(&"has_selection"))
	var sel = hand.get("_selected")
	return sel != null and int(sel) >= 0


func _deselect_hand() -> void:
	if hand == null:
		return
	if hand.has_method(&"deselect"):
		hand.call(&"deselect")
	elif hand.has_method(&"_on_back"):
		hand.call(&"_on_back")


func _on_follow_up(result: Dictionary, kind: StringName) -> void:
	if result.has("next"):
		var nxt: Dictionary = result["next"]
		var next_kind := StringName(str(nxt.get("kind", "")))
		if kind == &"pause" and (next_kind == &"settings" or next_kind == &"help"):
			_return_to_pause = true
		host.open_panel(next_kind, nxt.get("args", {}))
		return
	var say = result.get("say", [])
	if typeof(say) == TYPE_ARRAY and not (say as Array).is_empty():
		_say_news(say)
	var open_uid := str(result.get("open_uid", ""))
	if open_uid != "":
		_open_card(open_uid)
		return
	if bool(result.get("to_title", false)):
		_close_session_ui()
		_show_title()
		_play_cue(&"title")
		return
	if bool(result.get("quit", false)):
		quit_requested = true
		if allow_quit and get_tree() != null:
			get_tree().quit()
		return
	if _return_to_pause and (kind == &"settings" or kind == &"help"):
		_return_to_pause = false
		if host.top_kind() != &"pause":
			host.open_panel(&"pause", {})


func _on_table_card_pressed(uid: String) -> void:
	# W0/C03 兼容：点牌即开对应面板（正式扇面走 card_played）。
	if uid != "":
		_open_card(uid)


## W0/C04 测试兼容：旧名 _on_card_pressed（C01 #42 改名后保留）。
func _on_card_pressed(uid: String) -> void:
	_on_table_card_pressed(uid)


func _on_card_played(uid: String, def_id: String, _how: StringName) -> void:
	var play := host.play_panel()
	if play is CardStagePanel and (play as CardStagePanel).on_card_played(uid, def_id):
		return
	if str(engine.view().get("phase", "")) == "night":
		if not host.is_open(&"night"):
			host.open_panel(&"night", {"def": def_id})
		return
	if uid != "":
		_open_card(uid)


func _on_card_dropped(data: Dictionary) -> void:
	if str(data.get("kind", "")) != "card":
		return
	var zone := str(data.get("zone", ""))
	if zone != "hand" and zone != "kept":
		return
	var uid := str(data.get("uid", ""))
	if uid != "":
		_open_card(uid)


func _on_hotspot(id: StringName) -> void:
	if id == &"notice":
		_show_news()
		return
	if id == &"lamp":
		if stage != null and stage.has_method("toggle_lamp"):
			stage.toggle_lamp()
		return
	if id == &"magnifier":
		var play := host.play_panel()
		var took := false
		if play is CardStagePanel:
			took = (play as CardStagePanel).on_hotspot(id)
		# b33：柜上没东西可看时也给一句话，不再点了没反应。
		if not took and _toast != null:
			_toast.show_text(CardText.ui("c01.toast.nothing_to_look"))
		return
	var route: Array = CardIds.HOTSPOT_PANELS.get(id, [])
	if route.size() >= 2:
		host.open_panel(route[0], (route[1] as Dictionary).duplicate(true))


func _on_person(_uid: String) -> void:
	host.open_panel(&"contacts", {})


func _on_reply(reply_id: String) -> void:
	var play := host.play_panel()
	if play is CardStagePanel:
		(play as CardStagePanel).on_reply(reply_id)


func _on_action(uid: String, action_id: String) -> void:
	if action_id == "keep":
		engine.send(&"card.keep", {"uid": uid})
	elif action_id == "discard":
		engine.send(&"card.discard", {"uid": uid})
	elif action_id == "read":
		host.open_panel(&"read", {"uid": uid})
	elif action_id.begins_with("choose:"):
		host.open_panel(&"slots", {"uid": uid, "choice": action_id.substr(7)})


func _on_tab(tab: StringName) -> void:
	var spec: Array = CardIds.TAB_PANELS.get(tab, [])
	if spec.size() < 2:
		return
	var args: Dictionary = (spec[1] as Dictionary).duplicate(true)
	args["_tab"] = str(tab)
	host.open_panel(spec[0], args)


func _open_card(uid: String) -> void:
	if _ocean_live() and uid.begins_with("story:"):
		if str(engine.view().get("phase", "")) == "month_open":
			engine.send(&"month.begin")
		if str(engine.view().get("phase", "")) == "morning":
			engine.send(&"day.begin")
	var card_view := engine.query(&"card", {"uid": uid})
	var panel := StringName(str(card_view.get("panel", "none")))
	if panel == &"none" or panel == &"":
		return
	var args := {"uid": uid}
	if panel == &"wheel":
		var def_id := str(card_view.get("def", ""))
		args["wheel"] = "wh.big" if def_id == "bf.wheel" else ""
	host.open_panel(panel, args)


func _show_news() -> void:
	if dialog == null or dialog.visible or hub != null:
		return
	if host.play_panel() != null:
		return
	var notice: Dictionary = engine.view().get("notice", {})
	var lines := _news_lines(notice.get("news", []))
	if not lines.is_empty():
		dialog.show_lines("", lines)


## close_requested {"say": [notice entries]}: what a panel's command just did (the stocktake pick's gain / released /
## passed lines), said at once. Appended to what the dialog shows (the night report), otherwise on its own.
## At settle (acceptance 3) the settle stage says them after its report, so the report lines that follow do not push
## a stocktake pick's gain line out of sight; if the stage has not opened yet they wait for it.
func _say_news(news: Array) -> void:
	var lines := _news_lines(news)
	if dialog == null or lines.is_empty():
		return
	var play := host.play_panel() if host != null else null
	if play is CardSettlePanel and (play as CardSettlePanel).say_after(lines):
		return
	var v := engine.view()
	var key := "settle:%d" % int(v.get("date", {}).get("abs_day", 0))
	if str(v.get("phase", "")) == "settle" and not _phase_seen.has(key) and not _title_up():
		var held: Array = _settle_after.get(key, [])
		held.append_array(lines)
		_settle_after[key] = held
		return
	if dialog.visible:
		dialog.show_lines(dialog.current_uid(), lines, true)
	else:
		dialog.show_lines("", lines)


func _news_lines(news: Array) -> Array:
	var lines: Array = []
	for entry in news:
		# 真引擎存 {key, args}（card_engine._capture_notices），Mock 和合同 §7.5 的例子是裸键；都按 CardText 引用说。
		var ref := ""
		var args: Dictionary = {}
		if typeof(entry) == TYPE_DICTIONARY:
			ref = str(entry.get("key", entry.get("ref", "")))
			var raw = entry.get("args", {})
			args = raw if typeof(raw) == TYPE_DICTIONARY else {}
		else:
			ref = str(entry)
		if ref == "":
			continue
		lines.append({"kind": "narr", "who": "", "ref": ref, "args": args, "opt": false})
	return lines


func _show_title() -> void:
	if title != null and is_instance_valid(title):
		return
	if _ocean_mode():
		title = HubTitleScript.new()
		title.name = "CardTitle"
		if title.has_method("configure_campaign"):
			title.call("configure_campaign", _opts)
	else:
		title = load("res://scenes/cards/shell/CardTitle.tscn").instantiate()
	# 标题插在牌桌里、手牌扇之后、标签之前（b02/b32）：z 160 盖住手牌（≤150），抽屉的遮罩和框（200）、
	# ModalHost（300）照样画在标题上面、点得到，从标题打开的设置抽屉有框有遮罩。
	# 没开面板时 ModalHost 是 MOUSE_FILTER_IGNORE，点击照样落到标题按钮上。
	title.z_index = Z_TITLE
	var tabs: Node = table.get_node_or_null("Tabs") if table != null else null
	if tabs != null:
		table.add_child(title)
		table.move_child(title, tabs.get_index())
	else:
		add_child(title)
		if host != null and host.get_parent() == self:
			move_child(title, host.get_index())
	_show_table_top(false)
	if title.has_method("campaign_window_title") and get_window() != null:
		get_window().title = str(title.call("campaign_window_title"))
	if title.has_method("set_blocked"):
		title.call("set_blocked", _title_blocked)
	if not title.chose.is_connected(_on_title):
		title.chose.connect(_on_title)
	if keeper != null:
		keeper.on_title(title)


## 标题上开着面板（设置抽屉等）时，方向键和回车归那块面板，不归标题按钮。
func _title_blocked() -> bool:
	return host != null and host.top_panel() != null


## 远洋战役开着时：第一次见到它就搭高清营地（插在牌桌后面、叠层宿主前面，点击和画的先后一致），
## 把抽屉挪到营地上面，在宿主里登记换上的高清面板；之后每次视图变了刷新营地。旧版战役什么都不做。
func _sync_hub(view: Dictionary) -> void:
	if not _ocean_live() or table == null or host == null:
		return
	var map_view: Dictionary = engine.query(&"campaign.map")
	var has_map := bool(map_view.get("enabled", false))
	var wanted: String = MAP_SCRIPT if has_map else "res://scripts/cards/ui/hub/hub_panel.gd"
	if hub != null and hub.get_script().resource_path != wanted:
		hub.hide()
		hub.queue_free()
		hub = null
	var run_view: Dictionary = engine.query(&"campaign.run")
	var window_title := str(run_view.get("title", ""))
	if window_title == "":
		window_title = str(engine.query(&"campaign").get("title", ""))
	if window_title != "" and get_window() != null:
		get_window().title = window_title
	if hub == null:
		hub = load(MAP_SCRIPT).new() if has_map else HubScript.new()
		if has_map:
			hub.reveal_map = bool(_opts.get("map_reveal", false))
		hub.bind(engine)
		hub.fast = _want_fast() or bool(host.fast)
		hub.z_index = Z_HUB
		add_child(hub)
		move_child(hub, table.get_index() + 1)
		hub.card_pressed.connect(_open_card)
		hub.end_pressed.connect(_on_close_day)
		hub.menu_pressed.connect(func() -> void:
			if host.top_panel() == null:
				host.open_panel(&"pause", {}))
		hub.open_requested.connect(func(kind: StringName, args: Dictionary) -> void:
			host.open_panel(kind, args))
		host.overrides = HUB_OVERRIDES.duplicate()
		if _drawer != null and _drawer.get_parent() == table:
			_drawer.reparent(self, false)
			move_child(_drawer, hub.get_index() + 1)
			_drawer.z_index = Z_HUB + 10
		if _end != null:
			_end.visible = false
		hub.visible = not _title_up()
	elif not _ocean_live():
		return
	# 标题压着、或者满屏面板（剧情、战场、事务……）盖着时只记下视图，等露出来再重排（战斗里每条指令都会变视图）
	var covered: bool = _title_up() or not hub.visible \
		or (host.top_overlay() != null and host.is_fullscreen(host.top_kind()))
	hub.refresh(view, covered)


func _ocean_live() -> bool:
	return engine != null and engine.get("_ocean") != null


## 这一局（还没开局时：开局以后）走远洋战役：真引擎、没指定旧版数据。标题、暂停、设置从标题起就用高清的。
func _ocean_mode() -> bool:
	return engine is CardEngine and OceanBridge.selected(_opts)


func _refresh_all(view: Dictionary) -> void:
	_sync_hub(view)
	if stage != null:
		stage.refresh(view)
	if _hud != null:
		var hud_view := _view_fields(view, ["date", "stage", "notice", "money", "rep_tier", "heat_tier", "mode"])
		if hud_view != _hud_view:
			_hud_view = hud_view.duplicate(true)
			_hud.refresh(view)
	if hand != null:
		# Open-panel queries still refresh below on every command. The persistent
		# hand/HUD only rebuild when their inputs change, preserving live controls.
		var hand_view := _view_fields(view, ["phase", "hand", "kept", "night_offers"])
		if hand_view != _hand_view:
			_hand_view = hand_view.duplicate(true)
			hand.refresh(view)
			_wire_hand()
	if hero != null:
		hero.refresh(view)
	if checks != null and checks.has_method("refresh"):
		checks.call("refresh", view)
	if _street != null and _street.has_method("refresh"):
		_street.call("refresh", view)
		if _title_up():
			_street.visible = false
	if _drawer != null:
		_drawer.refresh(view)
	if host != null:
		host.refresh(view)
	_refresh_end(view)
	_notice_changes(view)


## 钱变了从顶栏钱下面飘 ± 字；口碑、风声换档出一条提示（SPEC §10.8）。开局 / 读档后的第一份视图只记下来。
func _notice_changes(view: Dictionary) -> void:
	var money: Dictionary = view.get("money", {}) if typeof(view.get("money", {})) == TYPE_DICTIONARY else {}
	var marks := {
		"phase": str(view.get("phase", "")),
		"amount": int(money.get("amount", 0)),
		"currency": str(money.get("currency", "fabi")),
		"rep": int(view.get("rep_tier", 0)),
		"heat": int(view.get("heat_tier", 0)),
	}
	var old := _last_marks
	_last_marks = marks
	if old.is_empty() or _toast == null or _title_up() or marks["phase"] in ["", "boot"]:
		return
	# 高清营地自己在数字上飘 ± 字，不再出像素的飘字和提示条
	if hub != null:
		return
	if str(old.get("currency", "")) == marks["currency"] and int(old["amount"]) != marks["amount"]:
		_toast.money(marks["amount"] - int(old["amount"]), CardText.ui("c01.money.unit." + marks["currency"]),
			CardLayout.HUD_MONEY)
	var rep: int = clampi(marks["rep"], 0, 4)
	var heat: int = clampi(marks["heat"], 0, 4)
	if heat != clampi(int(old["heat"]), 0, 4):
		_toast.show_text(CardText.ui("g03.tier.heat.%d" % heat), heat > int(old["heat"]))
	elif rep != clampi(int(old["rep"]), 0, 4):
		_toast.show_text(CardText.ui("g03.tier.rep.%d" % rep), rep < int(old["rep"]))


func _view_fields(view: Dictionary, keys: Array) -> Dictionary:
	var fields := {}
	for key in keys:
		fields[key] = view.get(key)
	return fields


func _refresh_end(view: Dictionary) -> void:
	if _end == null:
		return
	var phase := str(view.get("phase", ""))
	var preview: Dictionary = engine.query(&"day.end_preview", {}) if engine != null else {}
	var step := str(preview.get("step", ""))
	var key := "c01.btn.close_day.game_over" if phase == "game_over" else "c01.btn.close_day." + (step if step != "" else "next_day")
	key = CloseDayLabel.key_for(view, key)
	_end_title.text = CardText.ui(key)
	var pending := _pending_count(preview)
	var on_day := phase == "day"
	var night := phase == "night"
	_end_sub.visible = on_day or night
	if on_day:
		if pending == 0:
			_end_sub.text = CardText.ui("c01.btn.close_day.done")
		else:
			_end_sub.text = CardText.ui("c01.btn.close_day.left", {"n": pending})
	elif night:
		_end_sub.text = CardText.ui("c01.btn.close_day.night_sub")
	# 夜里永远是蓝的：照样打烊以后确认清单可能还没关完，以前会停在红色（SPEC §1 第 9 条）。
	var tone := &"day"
	if night:
		tone = &"night"
	elif host != null and host.is_open(&"end_day"):
		tone = &"confirm"
	elif on_day and pending == 0:
		tone = &"ready"
	_paint_end(tone)
	if hub != null:
		hub.set_end_state(_end_title.text, _end_sub.text if _end_sub.visible else "", str(tone))


## 四种样子（SPEC §10.1）：日 / 都办完了（绿光呼吸）/ 再按一下确认（红）/ 夜里（蓝）。
func _paint_end(tone: StringName) -> void:
	_end_tone = tone
	var keys: Array = [&"btn_day_hi", &"btn_day", &"btn_day_lo", &"btn_day_ink", &"btn_day_sub"]
	match tone:
		&"ready":
			keys = [&"btn_day_ready_hi", &"btn_day_ready", &"btn_day_ready_lo", &"btn_day_ink", &"btn_day_ready_sub"]
		&"confirm":
			keys = [&"btn_day_confirm_hi", &"btn_day_confirm", &"btn_day_confirm_lo", &"btn_day_light_ink",
				&"btn_day_light_sub"]
		&"night":
			keys = [&"btn_day_night_hi", &"btn_day_night", &"btn_day_night_lo", &"btn_day_night_ink",
				&"btn_day_night_sub"]
	if _end_face != null:
		_end_face.call("set_colors", keys[0], keys[2], keys[1], 0.55)
	_end_title.add_theme_color_override("font_color", CardTheme.color(keys[3]))
	_end_sub.add_theme_color_override("font_color", CardTheme.color(keys[4]))
	# 两行时主行在上；一行时主行竖直居中。
	var h := CardLayout.END_DAY.size.y
	if _end_sub.visible:
		_end_title.position = Vector2(8, 14)
		_end_sub.position = Vector2(8, 54)
	else:
		_end_title.position = Vector2(8, floorf((h - _end_title.size.y) * 0.5))
	_breathe_end(tone == &"ready")


## 都办完了：外圈绿光 0.6 秒一段地呼吸（快动画时常亮不动）。
func _breathe_end(on: bool) -> void:
	if _end_glow == null:
		return
	_end_glow.visible = on
	if not on:
		if _end_breath != null and _end_breath.is_valid():
			_end_breath.kill()
		_end_breath = null
		return
	if _end_breath != null and _end_breath.is_valid():
		return
	_end_glow.modulate.a = 1.0
	if _want_fast() or not is_inside_tree():
		return
	_end_breath = _end_glow.create_tween().set_loops()
	_end_breath.tween_property(_end_glow, "modulate:a", 0.4, END_BREATH_S).set_trans(Tween.TRANS_SINE)
	_end_breath.tween_property(_end_glow, "modulate:a", 1.0, END_BREATH_S).set_trans(Tween.TRANS_SINE)


func _pending_count(preview: Dictionary) -> int:
	var count := 0
	for item in preview.get("items", []):
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if str(item.get("uid", "")) == "":
			continue
		var item_kind := StringName(str(item.get("kind", "")))
		if item_kind in CardIds.END_NO_CONFIRM_KINDS:
			continue
		count += 1
	return count


func _build_table() -> void:
	table = load(TABLE_SCENE).instantiate()
	table.name = "Table"
	table.bus = bus
	add_child(table)
	stage = _spawn(&"stage", "Stage") as CardStage
	stage.bus = bus
	checks = _spawn(&"checks", "Checks") as CardChecksApi
	var play := Control.new()
	play.name = "PlayLayer"
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play.size = Vector2(1280, 720)
	table.add_child(play)
	dialog = _spawn(&"dialog", "Dialog") as CardDialogApi
	if "bus" in dialog:
		dialog.set("bus", bus)
	_hud = HudScript.new()
	_hud.name = "Hud"
	table.add_child(_hud)
	_hud.money_pressed.connect(func() -> void: host_open(&"estates"))
	_hud.almanac_pressed.connect(func() -> void: host_open(&"almanac"))
	hero = _spawn(&"hero_bar", "Hero") as CardHeroApi
	if "bus" in hero:
		hero.set("bus", bus)
	hand = _spawn(&"hand_fan", "Hand") as CardHandApi
	if "bus" in hand:
		hand.set("bus", bus)
	_drawer = DrawerScript.new()
	_drawer.name = "Drawer"
	_drawer.lift_tabs(table)
	_street = _spawn(&"street_overlay", "Street")
	if _street.has_signal("redeem_shop_pressed"):
		_street.redeem_shop_pressed.connect(_on_redeem_shop)
	table.add_child(_drawer)
	_drawer.tab_pressed.connect(_on_tab)
	_drawer.close_pressed.connect(_on_drawer_close)
	_build_end()
	table.add_child(_end)
	# b02：手牌扇的 z 最高 150；标签、街头、抽屉框在树里排在手牌后面，z 也抬到它上面。
	# 打烊按钮在 boot 里挪进叠层宿主（抽屉面板之上、叠层之下），见 CardModalHost.set_band。
	for node in [table.get_node_or_null("Tabs"), _street, _drawer]:
		if node is CanvasItem:
			(node as CanvasItem).z_index = Z_TABLE_TOP
	if dialog != null and dialog.has_method("set_max_bottom"):
		dialog.set_max_bottom(int(CardLayout.FAN.position.y))


func host_open(kind: StringName) -> void:
	if host != null:
		host.open_panel(kind, {})


func _spawn(widget: StringName, node_name: String) -> Control:
	var path := CardIds.widget_scene(widget)
	var node: Control = load(path).instantiate()
	node.name = node_name
	table.add_child(node)
	return node


## 大铜牌（SPEC §10.1）：按钮本身五态都是空框；下面垫外影 + 3px 金圈，再上面是径向渐变的牌面、上沿一道亮线、两行字。
func _build_end() -> void:
	var box := CardLayout.END_DAY
	_end = Button.new()
	_end.name = "EndDay"
	_end.position = box.position
	_end.size = box.size
	_end.pivot_offset = box.size * 0.5
	_end.focus_mode = Control.FOCUS_ALL
	_end.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		_end.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = CardTheme.color(&"focus")
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(int(END_RADIUS) + 5)
	ring.set_expand_margin_all(6.0)
	_end.add_theme_stylebox_override("focus", ring)
	_end.pressed.connect(_on_close_day)
	_end.mouse_entered.connect(_scale_end.bind(END_HOVER_SCALE))
	_end.mouse_exited.connect(_scale_end.bind(1.0))
	_end.button_down.connect(_scale_end.bind(END_PRESS_SCALE))
	_end.button_up.connect(func() -> void: _scale_end(END_HOVER_SCALE if _end.is_hovered() else 1.0))
	_end_glow = _end_panel("Glow", _end_glow_style())
	_end_panel("Ring", _end_ring_style())
	_end_face = CardTheme.grad_box(&"btn_day_hi", &"btn_day_lo", &"btn_day_edge", 3.0, END_RADIUS, true)
	_end_face.name = "Face"
	_end_face.size = box.size
	_end.add_child(_end_face)
	var shine := ColorRect.new()
	shine.name = "Shine"
	var white := Color.WHITE
	white.a = 0.35
	shine.color = white
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shine.position = Vector2(END_RADIUS, 3)
	shine.size = Vector2(box.size.x - END_RADIUS * 2.0, 2)
	_end.add_child(shine)
	_end_title = _end_label(Vector2(8, 14), Vector2(box.size.x - 16, 36))
	_end_title.name = "Title"
	_end_title.add_theme_font_override("font", CardTheme.font_title())
	_end_title.add_theme_font_size_override("font_size", 26)
	_end_sub = _end_label(Vector2(8, 54), Vector2(box.size.x - 16, 22))
	_end_sub.name = "Sub"
	_end_sub.add_theme_font_size_override("font_size", CardTheme.font_size(&"min"))
	_paint_end(&"day")


func _end_panel(node_name: String, style: StyleBox) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = CardLayout.END_DAY.size
	panel.add_theme_stylebox_override("panel", style)
	_end.add_child(panel)
	return panel


## 外圈：3px btn_day_ring + 影 0 10 24。
func _end_ring_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(&"btn_day_ring")
	sb.set_corner_radius_all(int(END_RADIUS) + 3)
	sb.set_expand_margin_all(3.0)
	sb.shadow_color = CardTheme.with_alpha(&"scene_void", 0.65)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	return sb


## 都办完了的绿光：透明底，只画 24px 的光晕。
func _end_glow_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.with_alpha(&"btn_day_ready_glow", 0.0)
	sb.set_corner_radius_all(int(END_RADIUS))
	sb.shadow_color = CardTheme.color(&"btn_day_ready_glow")
	sb.shadow_size = 24
	return sb


## 悬停放大 1.04、按下 0.98（Tween 0.12 秒；快动画直接到位）。
func _scale_end(to: float) -> void:
	if _end == null:
		return
	if _end_scale != null and _end_scale.is_valid():
		_end_scale.kill()
	var target := Vector2(to, to)
	if _want_fast() or not is_inside_tree():
		_end.scale = target
		return
	_end_scale = _end.create_tween()
	_end_scale.tween_property(_end, "scale", target, 0.12)
	if _end_face != null:
		var lit := Color.WHITE * (1.08 if to > 1.0 else 1.0)
		lit.a = 1.0
		_end_scale.parallel().tween_property(_end_face, "modulate", lit, 0.12)


func _end_label(at: Vector2, box_size: Vector2) -> Label:
	var label := Label.new()
	label.position = at
	label.size = box_size
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", CardTheme.font_body())
	label.add_theme_font_size_override("font_size", CardTheme.font_size(&"hud"))
	label.add_theme_color_override("font_color", CardTheme.color(&"btn_day_ink"))
	_end.add_child(label)
	return label


## b36：赎铺面没办成（多半是钱不够）要有一句话，不能点了没反应。
func _on_redeem_shop() -> void:
	var result := engine.send(&"street.redeem_shop", {})
	if bool(result.get("ok", false)) or _toast == null:
		return
	var view := engine.view()
	var price := 0
	for estate in view.get("estates", []):
		if typeof(estate) == TYPE_DICTIONARY and str(estate.get("id", "")) == "es.shopfront":
			price = int(estate.get("money", 0))
	var currency := str(view.get("money", {}).get("currency", "fabi"))
	if str(result.get("err", "")) == CardIds.ERR_INSUFFICIENT_MONEY and price > 0:
		_toast.show_text(CardText.ui("c01.toast.redeem_short",
			{"price": price, "unit": CardText.ui("c01.money.unit." + currency)}), true)
	else:
		_toast.show_text(CardText.ui("c01.toast.redeem_failed"), true)


func _wire_hand() -> void:
	if hand == null:
		return
	var live: Array = []
	for old in _wired:
		if is_instance_valid(old):
			live.append(old)
	_wired = live
	var pending: Array = []
	_collect_widgets(hand, pending)
	var gold_uids := {}
	if engine != null:
		var view: Dictionary = engine.view()
		for zone in ["hand", "kept"]:
			for card in view.get(zone, []):
				if typeof(card) == TYPE_DICTIONARY and bool(card.get("gold", false)):
					gold_uids[str(card.get("uid", ""))] = true
	for widget in pending:
		if not _wired.has(widget):
			_wired.append(widget)
			widget.action_requested.connect(_on_action)
		_clip_card_anchors(widget, gold_uids)


func _collect_widgets(node: Node, into: Array) -> void:
	if node is CardWidget:
		into.append(node)
	for child in node.get_children():
		_collect_widgets(child, into)


func _clip_card_anchors(widget: CardWidget, gold_uids: Dictionary) -> void:
	var uid := widget.get_uid()
	if uid == "":
		return
	CardAnchors.register(StringName("a.card@" + uid), widget, _clip_control.bind(widget))
	if gold_uids.has(uid):
		CardAnchors.register(StringName("a.card.gold@" + uid), widget, _clip_control.bind(widget))
	var keep := widget.get_node_or_null("Keep") as Control
	if keep != null and keep.visible:
		CardAnchors.register(StringName("a.card.keep@" + uid), keep, _clip_control.bind(keep))
	var days := widget.get_node_or_null("Days") as Control
	if days != null and days.visible:
		CardAnchors.register(StringName("a.card.days@" + uid), days, _clip_control.bind(days))


func _clip_control(node: Control) -> Rect2:
	if node == null or not node.is_inside_tree() or not node.is_visible_in_tree():
		return Rect2()
	var raw: Rect2 = node.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, node.size)
	var clipped := raw.intersection(CardLayout.SCREEN)
	if clipped.has_area():
		return clipped
	# 扇面底部的 Keep / Days 会整块掉出 720；退回所属牌面的可见底边，指引仍找得到。
	var parent: Node = node.get_parent()
	while parent != null and not (parent is CardWidget):
		parent = parent.get_parent()
	if parent is CardWidget:
		var card := parent as Control
		var card_raw: Rect2 = card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size)
		var card_clip := card_raw.intersection(CardLayout.SCREEN)
		if card_clip.has_area():
			var h := minf(24.0, card_clip.size.y)
			return Rect2(card_clip.position.x, card_clip.end.y - h, card_clip.size.x, h)
	return clipped


func _on_drawer_close() -> void:
	var panel := host.drawer_panel() if host != null else null
	if panel != null:
		panel.dismiss()


func _press_reply(index: int) -> bool:
	var buttons: Array = []
	_collect_reply_buttons(dialog, buttons)
	if index < 0 or index >= buttons.size():
		return false
	var button: Button = buttons[index]
	if button.disabled:
		return false
	button.pressed.emit()
	return true


func _collect_reply_buttons(node: Node, into: Array) -> void:
	for child in node.get_children():
		# C04 的回话按钮带 reply_id 元数据（套在一行 HBox 里）；老对话框是直接放在 VBox 里
		if child is Button and (child.has_meta("reply_id") or child.get_parent() is VBoxContainer):
			into.append(child)
		_collect_reply_buttons(child, into)


func _advance_dialog() -> void:
	if dialog == null:
		return
	if dialog.has_method("advance"):
		dialog.call("advance")
	elif dialog.has_method("_advance"):
		dialog.call("_advance")
	elif dialog.has_method("_advance_or_finish"):
		dialog.call("_advance_or_finish")


func _apply_pace() -> void:
	var fast := _want_fast()
	if stage != null:
		stage.fast = fast
	for node in [_drawer, host, _toast, hub]:
		if node != null:
			node.set("fast", fast)
	if dialog == null:
		return
	var cps := 40
	var path := str(_opts.get("settings_path", ""))
	if path != "":
		var bag = load(SETTINGS_SCRIPT).new(path)
		bag.load_file()
		cps = int(bag.text_cps())
	if fast:
		cps = 0
	dialog.chars_per_sec = cps


func _want_fast() -> bool:
	if str(_opts.get("fixture", "")) != "":
		return true
	if _opts.has("autoplay"):
		return true
	return CardSettings.fast_anim(_cards_path())


func _cards_path() -> String:
	var path := str(_opts.get("settings_path", ""))
	if path == "":
		return ""
	return path.get_base_dir().path_join("cards/settings.json")


func _play_cue(cue: StringName) -> void:
	if _music != null and _music.has_method("play"):
		_music.play(cue)


func _sync_music() -> void:
	if _music == null:
		return
	if _title_up():
		_play_cue(&"title")
		return
	if host != null:
		var tk := host.top_kind()
		if tk == &"vn":
			_play_cue(&"story")
			return
		if tk == &"battle_lineup":
			_play_cue(&"battle_prep")
			return
		if tk == &"battle_v2":
			_play_cue(&"battle")
			return
		if tk == &"battle_result":
			_play_cue(&"victory")
			return
		if tk in [&"month_close", &"settle", &"game_over"]:
			_play_cue(&"victory")
			return
		if tk == &"year_jump":
			_play_cue(&"title")
			return
	if _ocean_live():
		_play_cue(&"camp")


func _cmdline_opts(argv: PackedStringArray = PackedStringArray()) -> Dictionary:
	# 发行包不带任何参数也要走真引擎（X01-b 发行阻断）；Main.tscn 的 --cards 同样是真引擎。
	# auto_day：像玩家一样启动时，早上自动开张（不再空等打烊按钮）。
	# 默认启用无地图纯剧情收集+战斗流程（DEHOUDANG_NO_MAP=1）。
	if not OS.has_environment("DEHOUDANG_NO_MAP"):
		OS.set_environment("DEHOUDANG_NO_MAP", "1")
	var out := {"settings_path": "user://settings.json", "mock": false, "auto_day": true}
	var arguments := OS.get_cmdline_user_args() if argv.is_empty() else argv
	for a in arguments:
		if a == "--cards-mock":
			out["mock"] = true
		elif a.begins_with("--cards-mock="):
			out["mock"] = true
			out["fixture"] = a.substr(13)
		elif a.begins_with("--seed="):
			out["seed"] = int(a.substr(7))
		elif a.begins_with("--guide="):
			out["guide"] = a.substr(8)
		elif a.begins_with("--campaign="):
			out["campaign"] = a.substr(11)
		elif a.begins_with("--book="):
			out["book"] = a.substr(7)
		elif a.begins_with("--save-dir="):
			out["save_dir"] = a.substr(11)
		elif a.begins_with("--segment="):
			out["segment"] = a.substr(10)
		elif a.begins_with("--stage="):
			var stage_arg := a.substr(8)
			out["stage"] = int(stage_arg) if stage_arg.is_valid_int() else stage_arg
		elif a == "--map-reveal":
			out["map_reveal"] = true
		elif a.begins_with("--cards-autoplay="):
			out["autoplay"] = int(a.substr(17))
			out["skip_title"] = true
	return out


func _setting_guide_hints() -> bool:
	var path := str(_opts.get("settings_path", ""))
	if path == "":
		return true
	var bag = load(SETTINGS_SCRIPT).new(path)
	bag.load_file()
	return bool(bag.guide_hints)
