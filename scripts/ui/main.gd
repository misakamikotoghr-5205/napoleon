# 《德厚当》主界面：把导演（剧情数据解释器）发来的 beat 路由到各个面板；玩家操作再回传给导演。
# 布局（1280×720）v0.3b：柜台像素视图全屏（320×180 × 4）；钱匣/算盘/人脉侧栏按需弹出；底部桌沿条。
# 命令行（-- 之后）：--autoplay=<策略> --delay=<秒> --shots=<目录> --until=<checkpoint> --quit --seed=N --skip-title
#   小镇版（v0.4）：--town（直接开小镇）/ --autoplay=town_fair（经由界面自动试玩）/ --days=N / --fast（瞬移+快钟）/ --clock=<秒每游戏分钟>
#                  --skip-prologue / --save=<存档路径> / --difficulty=太平年|常年|乱世；--legacy 让“开张”走旧的线性版
extends Control

const VIEW_SCALE := 4

const Director = preload("res://scripts/core/director.gd")
const Autoplayer = preload("res://scripts/tests/autoplayer.gd")
const CounterView = preload("res://scripts/ui/counter_view.gd")
const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const Sidebar = preload("res://scripts/ui/sidebar.gd")
const InspectPanel = preload("res://scripts/ui/appraise_panel.gd")
const BookPanel = preload("res://scripts/ui/book_panel.gd")
const TicketPanel = preload("res://scripts/ui/ticket_panel.gd")
const TelegraphPanel = preload("res://scripts/ui/telegraph_panel.gd")
const Beeper = preload("res://scripts/ui/beeper.gd")
const TownGame = preload("res://scripts/town/town_game.gd")
const TownBot = preload("res://scripts/town/town_bot.gd")
const Settings = preload("res://scripts/town/settings.gd")
const SettingsPanel = preload("res://scripts/town/settings_panel.gd")
const MusicCues = preload("res://scripts/town/music_cues.gd")
const ShopOnly = preload("res://scripts/town/shop_only.gd")      # [shop-only]
const HelpPanel = preload("res://scripts/town/help_panel.gd")   # [onboarding] 操作说明（F1 / 标题按钮）

var autostart: bool = true
var auto_say_mode: String = "click"   # 测试用：自动试玩怎么推进对白
var director = null
var world = null
var autoplayer = null
var _db_global
# 名字、颜色这些从哪本 db 取：小镇里生成的客人（过路的、生客）只登记在这一局自己的 world.db 里，柜台、对白框都要从那儿取
var db:
	get:
		if world != null and world.get("db") != null:
			return world.db
		return _db_global
	set(value):
		_db_global = value
var beeper
var view
var scene_holder: Control
var sidebar
var dialogue
var overlay: Control
var inspect
var book
var ticket
var telegraph
var caption_layer: ColorRect
var caption_lbl: Label
var caption_sub: Label
var title_layer: Control
var generic_panel: PanelContainer
var generic_box: VBoxContainer
var toast_lbl: Label
var hover_lbl: Label
var stow_hint: Label
var desk_edge: ColorRect
var desk_wood: ColorRect
var bottom_hint: Label
var cash_chip: Button
var mute_btn: Button
var sidebar_user_pinned: bool = false
var cur: Dictionary = {}
var cur_type: String = ""
var args: Dictionary = {}
var shots_dir: String = ""
var shots_done: Dictionary = {}
var shot_plan: Dictionary = {}
var _respond_lock: bool = false
# v0.4 小镇模式：mode 决定显示哪一层。"legacy" 是旧的线性版；小镇里是 "town"（走动）/"closeup"（店铺特写）/"counter"（柜台）/"night"（夜里）。
var mode: String = "legacy"
var town = null
var town_bot = null
var autoplay_save: String = ""     # 自动试玩用的临时存档（带进程号），跑完删掉
var settings = null     # 玩家设置（音量、文字速度）
var music = null        # 音乐挂钩（没有音乐导演脚本时什么都不做）

func _ready() -> void:
	db = DB.get_db()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if args.has("cards") or args.has("cards-mock"):   # [cards] W0：--cards 直接进卡牌版（docs/cards/CARDS_INTERFACES.md §2.3）；默认启动不变
		get_tree().change_scene_to_file.call_deferred("res://scenes/cards/CardGame.tscn")
		return
	theme = Theme.new()
	theme.default_font = UiStyle.body_font()
	theme.default_font_size = 18
	_build()
	settings = Settings.new()
	settings.load_file()
	music = MusicCues.new(self)
	settings.apply(self)
	HelpPanel.install_hotkey(self)         # [onboarding] F1
	if args.has("shots"):
		shots_dir = str(args["shots"])
		_init_shot_plan()
	if not autostart:
		return
	var policy := str(args.get("autoplay", ""))
	if (policy.begins_with("town") or args.has("town")) and not args.has("legacy"):
		if shots_dir != "" and args.has("autoplay"):
			_show_title()
			await get_tree().create_timer(0.6).timeout
			await take_title_shot()
		_begin_town(policy.trim_prefix("town_") if policy.begins_with("town_") else (policy if policy != "town" else ""))
		return
	if args.has("autoplay") and shots_dir != "":
		_show_title()
		await get_tree().create_timer(0.6).timeout
		await take_title_shot()
		_begin(args.get("autoplay", ""))
	elif args.has("autoplay") or args.has("skip-title"):
		_begin(args.get("autoplay", ""))
	else:
		_show_title()

# ====================================================================
func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bgc := ColorRect.new()
	bgc.color = Color("#0d0a08")
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bgc)
	# v0.3b：柜台全屏铺满（320×180 × 4 = 1280×720）
	scene_holder = Control.new()
	scene_holder.position = Vector2.ZERO
	scene_holder.size = Vector2(1280, 720)
	scene_holder.clip_contents = true
	add_child(scene_holder)
	view = CounterView.new()
	view.scale = Vector2(VIEW_SCALE, VIEW_SCALE)
	scene_holder.add_child(view)
	view.hotspot_clicked.connect(_on_hotspot)
	view.item_clicked.connect(_on_item_clicked)
	view.piece_clicked.connect(_on_piece)
	view.hover_text.connect(_on_hover_text)
	if view.has_signal("empty_clicked"):
		view.connect("empty_clicked", _on_scene_click)
	view.item_dropped.connect(_on_item_dropped)
	# 底部桌沿：补原先大对话框留下的空条（闲时淡木色，对白时显「继续」提示）
	desk_edge = ColorRect.new()
	desk_edge.color = Color(0.08, 0.05, 0.03, 0.28)
	desk_edge.position = Vector2(0, 696)
	desk_edge.size = Vector2(1280, 24)
	desk_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(desk_edge)
	desk_wood = ColorRect.new()
	desk_wood.color = Color("#5a3f2acc")
	desk_wood.position = Vector2(0, 694)
	desk_wood.size = Vector2(1280, 2)
	desk_wood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(desk_wood)
	bottom_hint = UiStyle.label("", 14, UiStyle.LAMP_PALE, false)
	bottom_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_hint.position = Vector2(0, 698)
	bottom_hint.size = Vector2(1280, 20)
	bottom_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hint.visible = false
	add_child(bottom_hint)
	# 侧栏：默认隐藏，点钱匣角标 / 算盘 / 议价时弹出
	sidebar = Sidebar.new()
	sidebar.main = self
	sidebar.position = Vector2(900, 16)
	sidebar.size = Vector2(360, 688)
	sidebar.custom_minimum_size = Vector2(360, 640)
	sidebar.visible = false
	add_child(sidebar)
	sidebar.offer.connect(_on_offer)
	sidebar.extra.connect(_on_counter_action.bind("extra"))
	sidebar.deal.connect(_on_counter_action.bind("deal"))
	sidebar.refuse.connect(_on_counter_action.bind("", "refuse"))
	if sidebar.has_signal("closed"):
		sidebar.closed.connect(_on_sidebar_closed)
	cash_chip = UiStyle.button("钱匣 · —", 14, "seal")
	cash_chip.position = Vector2(1088, 10)
	cash_chip.size = Vector2(176, 34)
	cash_chip.tooltip_text = "打开钱匣 / 口碑 / 人脉（也可点柜台上的算盘、账簿、万年历）"
	cash_chip.pressed.connect(_toggle_sidebar_panel)
	add_child(cash_chip)
	# 音效开关（打字机嘀嗒 / 算盘 / 电报）：左下角，快捷键 M
	mute_btn = UiStyle.button("", 12, "wood")
	mute_btn.position = Vector2(8, 680)
	mute_btn.size = Vector2(92, 34)
	mute_btn.tooltip_text = "音效开 / 关（M）"
	mute_btn.pressed.connect(toggle_mute)
	add_child(mute_btn)
	# v0.3：侧边对白气泡（叠在柜台画面上，不再占底部大条）
	dialogue = DialogueBox.new()
	dialogue.position = Vector2(40, 220)
	dialogue.size = Vector2(440, 160)
	dialogue.custom_minimum_size = Vector2(420, 140)
	dialogue.visible = false
	add_child(dialogue)
	dialogue.advanced.connect(_on_dialogue_advanced)
	dialogue.option_picked.connect(_on_option)
	dialogue.action_picked.connect(_on_dialogue_action)
	overlay = Control.new()
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	inspect = InspectPanel.new()
	inspect.main = self
	_place(inspect, Rect2(20, 10, 920, 610))
	overlay.add_child(inspect)
	inspect.visible = false
	inspect.closed.connect(_on_inspect_closed)
	inspect.done_practice.connect(_respond_if.bind("practice", {}))
	inspect.inspected.connect(func(_i, _p): sidebar.refresh(world))
	book = BookPanel.new()
	book.main = self
	_place(book, Rect2(40, 16, 880, 508))
	overlay.add_child(book)
	book.visible = false
	book.closed.connect(_on_book_closed)
	ticket = TicketPanel.new()
	_place(ticket, Rect2(60, 40, 840, 470))
	overlay.add_child(ticket)
	ticket.visible = false
	ticket.finished.connect(_on_ticket_finished)
	telegraph = TelegraphPanel.new()
	_place(telegraph, Rect2(30, 20, 900, 500))
	overlay.add_child(telegraph)
	telegraph.visible = false
	telegraph.sent.connect(_on_telegraph_sent)
	telegraph.skipped.connect(_respond_if.bind("telegraph", {"skip": true}))
	telegraph.done.connect(_respond_if.bind("telegraph", {}))
	generic_panel = UiStyle.paper_panel()
	_place(generic_panel, Rect2(120, 30, 720, 480))
	overlay.add_child(generic_panel)
	generic_panel.visible = false
	generic_box = UiStyle.vbox(8)
	generic_panel.add_child(generic_box)
	toast_lbl = UiStyle.label("", 16, UiStyle.LAMP, false)
	toast_lbl.add_theme_stylebox_override("normal", UiStyle.box(Color(0.12, 0.09, 0.07, 0.92), UiStyle.LAMP, 2, 3, 8))
	toast_lbl.position = Vector2(20, 12)
	toast_lbl.visible = false
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(toast_lbl)
	hover_lbl = UiStyle.label("", 15, UiStyle.PAPER, false)
	hover_lbl.add_theme_stylebox_override("normal", UiStyle.box(Color(0.12, 0.09, 0.07, 0.92), UiStyle.WOOD_MID, 1, 2, 5))
	hover_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hover_lbl.visible = false
	overlay.add_child(hover_lbl)
	stow_hint = UiStyle.label("先点当物，再点高亮的典当盒（也可以直接拖过去）", 16, UiStyle.LAMP, false)
	stow_hint.add_theme_stylebox_override("normal", UiStyle.box(Color(0.12, 0.09, 0.07, 0.9), UiStyle.LAMP, 2, 3, 8))
	stow_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stow_hint.visible = false
	overlay.add_child(stow_hint)
	caption_layer = ColorRect.new()
	caption_layer.color = Color("#0d0a08")
	caption_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption_layer.visible = false
	add_child(caption_layer)
	caption_lbl = UiStyle.title_label("", 40, UiStyle.LAMP_PALE)
	caption_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_layer.add_child(caption_lbl)
	caption_sub = UiStyle.label("▼ 点击继续", 15, UiStyle.MIST, false)
	caption_sub.position = Vector2(560, 650)
	caption_layer.add_child(caption_sub)
	caption_layer.gui_input.connect(_on_caption_input)
	beeper = Beeper.new()
	add_child(beeper)
	dialogue.beeper = beeper
	beeper.mute_changed.connect(func(_m): _refresh_mute_btn())
	_refresh_mute_btn()

func toggle_mute() -> void:
	if beeper != null:
		beeper.toggle_mute()

func _refresh_mute_btn() -> void:
	if mute_btn != null and beeper != null:
		mute_btn.text = "音效：关 (M)" if beeper.muted else "音效：开 (M)"

func _on_counter_action(id: String, action: String) -> void:
	if cur_type != "counter":
		return
	if action == "refuse":
		_respond({"action": "refuse"})
		return
	# v0.3：议价中本地交互（不推进导演）
	if action == "extra" and id == "_inspect_again":
		if director.session != null:
			inspect.open(director.session)
		return
	if action == "extra" and id == "_open_ledger":
		book.open("ledger", world)
		return
	if action == "extra" and id == "_sell_one":
		if director.session != null:
			_pick_single_sell()
		return
	_respond({"action": action, "id": id})

func _pick_single_sell() -> void:
	# 弹出：只卖库存里的一件（单件购买功能）
	var s = director.session
	if s == null or s.mode != "sell":
		return
	_clear_generic()
	generic_panel.set_meta("closable", true)
	_place(generic_panel, Rect2(220, 80, 520, 400))
	generic_panel.visible = true
	generic_box.add_child(UiStyle.title_label("只卖一件", 28))
	generic_box.add_child(UiStyle.label("勾一件给客人看。其余先不卖。", 15, UiStyle.INK_SOFT))
	for iid in s.item_ids:
		var it: Dictionary = s.item(iid)
		var on: bool = s.selected.get(iid, true)
		var iname: String = str(it["name"])
		var row_text := "%s %s（约 %d 蚨）" % ["✓" if on else "·", iname, world.market_now(it)]
		if director.shop_only():
			row_text = "%s %s" % ["✓" if on else "·", iname]      # [shop-only] 不写市价（架上买来的假货不在这里露底）
		var b := UiStyle.button(row_text, 15, "seal" if on else "paper", true)
		var id: String = iid
		b.pressed.connect(func():
			for j in s.item_ids:
				s.set_selected(j, j == id)
			generic_panel.visible = false
			_clear_generic()
			sidebar.refresh_session()
			_toast("只卖：%s" % iname)
		)
		generic_box.add_child(b)
	var cancel := UiStyle.button("取消", 15, "wood")
	cancel.pressed.connect(func():
		generic_panel.visible = false
		_clear_generic()
	)
	generic_box.add_child(cancel)

func _respond_if(t: String, r: Dictionary) -> void:
	if cur_type == t:
		_respond(r)

func _on_ticket_finished(c: String) -> void:
	if cur_type == "ticket":
		_respond({"condition": c})

func _on_telegraph_sent(w: Array) -> void:
	if cur_type == "telegraph":
		_respond({"words": w})

func _on_caption_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and cur_type == "caption":
		_respond({})

func _begin_demo() -> void:
	args["delay"] = "1.2"
	_begin("fair")

func _show_sidebar() -> void:
	if sidebar == null:
		return
	sidebar.visible = true
	sidebar.position = Vector2(900, 16)
	if cash_chip != null:
		cash_chip.visible = false
	_refresh_cash_chip()

func _hide_sidebar(force: bool = false) -> void:
	if sidebar == null:
		return
	if not force:
		if sidebar.session != null or sidebar.practice_mode:
			return
		if sidebar_user_pinned:
			return
	sidebar_user_pinned = false
	sidebar.visible = false
	if cash_chip != null:
		cash_chip.visible = mode in ["legacy", "counter", "night"]
	_refresh_cash_chip()

func _toggle_sidebar_panel() -> void:
	if sidebar == null:
		return
	if sidebar.visible and sidebar.session == null and not sidebar.practice_mode:
		sidebar_user_pinned = false
		_hide_sidebar(true)
	else:
		sidebar_user_pinned = true
		if sidebar.session == null and world != null:
			sidebar.bargain_scroll.visible = false
			sidebar.info_scroll.visible = true
			sidebar.refresh(world)
		_show_sidebar()

func _on_sidebar_closed() -> void:
	if sidebar != null and sidebar.session != null and not sidebar.session.closed:
		_toast("先了结这一笔（出价或不收了），再合上匣子。")
		return
	if sidebar != null and sidebar.practice_mode:
		sidebar.close_session(world)
	sidebar_user_pinned = false
	_hide_sidebar(true)

func _refresh_cash_chip() -> void:
	if cash_chip == null:
		return
	if world == null:
		cash_chip.text = "钱匣 · —"
		return
	cash_chip.text = "钱匣 · %d 蚨" % world.cash()

func _set_bottom_hint(text: String) -> void:
	if bottom_hint == null:
		return
	bottom_hint.text = text
	bottom_hint.visible = text != ""
	if desk_edge != null:
		desk_edge.color = Color(0.10, 0.06, 0.03, 0.62) if text != "" else Color(0.08, 0.05, 0.03, 0.28)

func _clear_bottom_hint() -> void:
	_set_bottom_hint("")

func _place(c: Control, r: Rect2) -> void:
	c.custom_minimum_size = r.size
	c.position = r.position
	c.size = r.size

# ====================================================================
func _show_title() -> void:
	title_layer = Control.new()
	title_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_layer)
	var tr := TextureRect.new()
	tr.texture = DB.tex("art/bg/title.png")
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = Vector2(0, 0)
	tr.size = Vector2(1280, 720)
	title_layer.add_child(tr)
	var t := UiStyle.title_label("德厚当", 108, UiStyle.LAMP)
	t.position = Vector2(0, 70)
	t.size = Vector2(1280, 140)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_layer.add_child(t)
	var sub := UiStyle.label("民国二十七年 · 青溪镇　　小镇版 v0.4", 22, UiStyle.PAPER, false)
	sub.position = Vector2(0, 215)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_layer.add_child(sub)
	var box := UiStyle.vbox(10)
	box.position = Vector2(540, 470)
	box.size = Vector2(200, 220)
	title_layer.add_child(box)
	var b1 := UiStyle.button("开　张", 22, "seal")
	b1.pressed.connect(func():
		if args.has("legacy"):
			_begin("")
		else:
			_begin_town())
	box.add_child(b1)
	if TownGame.has_save(str(args.get("save", TownGame.SAVE_PATH))) and not args.has("legacy"):
		var b_cont := UiStyle.button("继　续", 20, "paper")
		b_cont.pressed.connect(func(): _begin_town("", true))
		box.add_child(b_cont)
	var b_set := UiStyle.button("设　置", 18)
	b_set.pressed.connect(_open_settings)
	box.add_child(b_set)
	HelpPanel.add_title_button(title_layer, self)   # [onboarding] 右下角“操作说明 F1”
	var b3 := UiStyle.button("退　出", 18, "wood")
	b3.pressed.connect(func(): get_tree().quit())
	box.add_child(b3)
	if music != null:
		music.cue("title")

func _open_settings() -> void:
	var sp = SettingsPanel.new()
	sp.build(self, settings)
	add_child(sp)

func _begin(auto_policy: String) -> void:
	if title_layer != null:
		title_layer.queue_free()
		title_layer = null
	var d = start_game(int(args.get("seed", "19380306")))
	if auto_policy != "":
		autoplayer = Autoplayer.new(d, auto_policy, int(args.get("seed", "1")))
		autoplayer.ui = self
		autoplayer.tree = get_tree()
		autoplayer.step_delay = float(args.get("delay", "0.05"))
		dialogue.instant = true
	if args.has("until"):
		d.stop_at = str(args["until"])
	d.finished.connect(_on_finished)
	d.run()

func start_game(p_seed: int = 19380306):
	director = Director.new()
	add_child(director)
	director.setup(p_seed)
	_wire_director()
	return director

func _wire_director() -> void:
	world = director.world
	view.world = world
	director.beat.connect(_on_beat)
	world.changed.connect(func():
		sidebar.refresh(world)
		_refresh_cash_chip()
	)
	sidebar.refresh(world)
	_refresh_cash_chip()

# ---------------- v0.4 小镇模式 ----------------
func _ensure_town() -> void:
	if town != null:
		return
	town = TownGame.new()
	add_child(town)
	move_child(town, 1)    # 黑底之上、柜台层之下：柜台层显示时盖住小镇，隐藏时露出小镇
	town.setup(self)
	town.title_requested.connect(_return_to_title, CONNECT_DEFERRED)
	town.quit_requested.connect(func(): get_tree().quit(), CONNECT_DEFERRED)

# 返回标题：把小镇和导演拆干净，再显示标题（开张/继续都能重新开始，不用重启程序）
func _return_to_title() -> void:
	if town != null:
		end_scene()
		# 当票、电报面板和各种临时提示不归 end_scene 管：从序章/柜台中途返回标题时一并收起，不能盖在标题画面上
		ticket.visible = false
		telegraph.visible = false
		_hide_scene_leftovers()
		town.shutdown()
		remove_child(town)
		town.queue_free()
		town = null
	if director != null and is_instance_valid(director):
		remove_child(director)
		director.queue_free()
	director = null
	world = null
	view.world = null
	autoplayer = null
	town_bot = null
	cur = {}
	cur_type = ""
	_respond_lock = false
	if sidebar.session != null:
		sidebar.session = null
	sidebar.practice_mode = false
	sidebar_user_pinned = false
	sidebar.visible = false
	set_mode("title")
	_refresh_cash_chip()
	if title_layer != null:
		title_layer.queue_free()
		title_layer = null
	_show_title()

func start_town(p_seed: int, difficulty: String = "常年"):
	if director != null and is_instance_valid(director):
		director.queue_free()
	director = Director.new()
	add_child(director)
	director.setup_town(p_seed, difficulty, ShopOnly.enabled())      # [shop-only]
	_wire_director()
	return director

func _begin_town(auto_policy: String = "", from_save: bool = false) -> void:
	if title_layer != null:
		title_layer.queue_free()
		title_layer = null
	_ensure_town()
	town.set_fast(args.has("fast"))
	if args.has("clock"):
		town.clock_override = float(args["clock"])     # 每游戏分钟多少真实秒（默认 0.7）
	if args.has("save"):
		town.save_path = str(args["save"])
	elif auto_policy != "":
		# 自动试玩不碰玩家自己的存档；文件名带进程号，几个试玩并行也不会抢同一个 .tmp
		town.save_path = TownGame.scratch_save_path("autoplay")
		autoplay_save = town.save_path
	if auto_policy != "":
		town.auto_dismiss = true
		town.director_ready.connect(_on_town_director.bind(auto_policy), CONNECT_ONE_SHOT)
	if from_save:
		var ok: bool = await town.load_game()
		if not ok:
			_return_to_title()          # 拆干净再回标题（半开的小镇不留着）
			_toast("读档失败，请重新开张。")
		return
	var seed_v := int(args["seed"]) if args.has("seed") else int(Time.get_ticks_usec() & 0x7fffffff)
	await town.new_game(seed_v, str(args.get("difficulty", "常年")), args.has("skip-prologue"))

# 自动试玩：序章和柜台由 autoplayer 回应；小镇里的走动由 TownBot 经由界面接口驱动
func _on_town_director(d, policy: String) -> void:
	autoplayer = Autoplayer.new(d, "town_" + policy, int(args.get("seed", "1")))
	autoplayer.ui = self
	autoplayer.tree = get_tree()
	autoplayer.step_delay = float(args.get("delay", "0.05"))
	dialogue.instant = true
	town_bot = TownBot.new()
	town_bot.setup(self, town, autoplayer, args)
	town_bot.run()

# 模式切换：只管显示哪一层；小镇自己的内容在 TownGame 里。
# clean=false：只翻柜台层的显隐，不收拾现场（店里的剧情在一拍之内翻来翻去，刚显示的对白框不能被收掉）。
func set_mode(m: String, clean: bool = true) -> void:
	mode = m
	if dialogue != null and dialogue.skip_btn != null:
		dialogue.skip_btn.tooltip_text = "补全这一句并继续（也可按空格 / 回车 / Esc）" if m == "legacy" else "补全这一句并继续（也可按 E / 空格 / 回车；Esc 是暂停菜单）"
	var counter_ui: bool = m in ["legacy", "counter", "night"]
	scene_holder.visible = counter_ui
	desk_edge.visible = counter_ui
	desk_wood.visible = counter_ui
	if mute_btn != null:
		mute_btn.visible = counter_ui     # 左下角音效钮跟柜台层走：小镇里那块是宵禁牌和按键条（M 键照样能开关）
	if counter_ui:
		cash_chip.visible = not sidebar.visible
	else:
		cash_chip.visible = false
		if clean:
			end_scene()
		else:
			_hide_sidebar(true)     # 议价侧栏跟着柜台层走；下一次 counter 拍会自己再打开

# 小镇里 Esc / E 要关的东西，从最上面的往下数：账簿/档案/药典册子 → 放大镜验货（交易里） → 万年历、“只卖一件”小面板 → 玩家自己翻开的钱匣。
# 返回是否关掉了东西。关不掉的（对白、议价、当票、电报、夜里的选单……）是剧情在等回应，归剧情管，Esc 走暂停菜单。
# info_only（E 键）：只关纯看的册子和万年历，不动放大镜和钱匣。
func close_topmost_panel(info_only: bool = false) -> bool:
	if book.visible:
		book._close()          # 教学里翻账簿那一拍，关上就是“看完了”：closed 信号会回应剧情
		return true
	if inspect.visible and cur_type == "counter" and not info_only:
		inspect._on_close()
		return true
	if generic_panel.visible and generic_panel.get_meta("closable", false):
		generic_panel.visible = false
		_clear_generic()
		return true
	if not info_only and sidebar.visible and sidebar_user_pinned and sidebar.session == null and not sidebar.practice_mode:
		_hide_sidebar(true)
		return true
	return false

# 旧名字（店铺特写和旧测试还在用）
func close_hud_panel() -> bool:
	return close_topmost_panel()

func _hide_scene_leftovers() -> void:
	stow_hint.visible = false
	toast_lbl.visible = false
	hover_lbl.visible = false
	view.pieces = []
	view.highlight = []
	view.selected_item = ""
	dialogue.finish_typing()

# 一段对白/交易结束后收拾现场：对白框、侧栏、字幕、面板都收起，免得盖在小镇画面上
func end_scene() -> void:
	if dialogue != null:
		dialogue.visible = false
		dialogue.clear_options()
		dialogue.clear_actions()
	_clear_bottom_hint()
	caption_layer.visible = false
	generic_panel.visible = false
	stow_hint.visible = false
	inspect.visible = false
	book.visible = false
	hover_lbl.visible = false
	if _glow_lbl != null:
		_glow_lbl.visible = false
	toast_lbl.visible = false
	if sidebar.session != null and director != null and director.session == null:
		sidebar.close_session(world)
	_hide_sidebar(true)
	if view != null:
		view.counter_items = []
		view.highlight = []

# 小镇里有对白/弹窗/交易正在等玩家：时钟要停
func is_scene_busy() -> bool:
	return cur_type != "" or book.visible or generic_panel.visible or inspect.visible or caption_layer.visible

func finish_town_run(code: int = 0) -> void:
	if autoplay_save != "":
		TownGame.remove_save_files(autoplay_save)
		autoplay_save = ""
	if not args.has("quit"):
		return
	await get_tree().create_timer(0.3).timeout
	if beeper != null:
		beeper.queue_free()
	for tw in get_tree().get_processed_tweens():
		tw.kill()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)

func _on_finished() -> void:
	if director.done and not director.stopped and (director.stop_at == "" or director.stop_at == "ending"):
		await _show_end_card()
	if args.has("quit"):
		await get_tree().create_timer(0.3).timeout
		var code := 0
		if autoplayer != null and not autoplayer.errors.is_empty():
			for e in autoplayer.errors:
				printerr("FAIL: ", e)
			code = 1
		beeper.queue_free()
		for tw in get_tree().get_processed_tweens():
			tw.kill()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit(code)


func _place_dialogue(who: String = "", is_narr: bool = false) -> void:
	# NPC 靠顾客立绘左侧；玩家靠右侧柜台；旁白居中偏下（全屏 ×4 坐标）
	dialogue.visible = true
	if is_narr or who in ["", "narr"]:
		dialogue.set_side("narr", who)
		dialogue.position = Vector2(420, 500)
		dialogue.size = Vector2(440, 140)
	elif who == "you":
		dialogue.set_side("player", who)
		dialogue.position = Vector2(720, 360)
		dialogue.size = Vector2(440, 160)
	else:
		dialogue.set_side("npc", who)
		dialogue.position = Vector2(24, 160)
		dialogue.size = Vector2(440, 160)
	_set_bottom_hint("▼ 点气泡或按空格继续" if mode == "legacy" else "▼ 点气泡，或按 E / 空格继续　　Esc 暂停")

# ====================================================================
# beat 路由
func _on_beat(b: Dictionary) -> void:
	if b.get("nowait", false):
		if b["type"] == "scene":
			view.set_scene(b)
		elif b["type"] == "sfx":
			beeper.play(str(b.get("name", "")))
		sidebar.refresh(world)
		return
	cur = b
	cur_type = str(b["type"])
	sidebar.refresh(world)
	if cur_type != "counter" and director.session == null and sidebar.session != null:
		sidebar.close_session(world)
		_hide_sidebar()
	if cur_type != "counter":
		sidebar.enabled = false
	if cur_type in ["say", "narr", "choice", "door_flag", "pick_item", "tutorial", "counter"]:
		pass  # bottom hint set in _place_dialogue / counter
	elif cur_type not in ["practice"]:
		_clear_bottom_hint()
	view.highlight = []
	view.pieces = []
	if cur_type != "counter":
		view.counter_items = _counter_items_now()
	match cur_type:
		"caption":
			caption_layer.visible = true
			caption_lbl.text = str(b["text"])
			caption_lbl.add_theme_font_size_override("font_size", 64 if b.get("style", "") == "chapter" else 40)
			if b["text"] == "":
				caption_lbl.text = "……"
		"say":
			caption_layer.visible = false
			var who := str(b["who"])
			var nm := str(b["name"])
			var text := str(b["text"])
			if str(b.get("expr", "")) != "":
				text = str(b["expr"]) + text
			_place_dialogue(who, false)
			dialogue.show_line(nm, text, db.npc_color(who) if who != "you" else Color("#e8c88a"), false, true, float(db.cast.get(who, {}).get("voice_pitch", 1.1 if who == "you" else 1.0)))
		"narr":
			caption_layer.visible = false
			_place_dialogue("", true)
			dialogue.show_line("", str(b["text"]), UiStyle.MIST, true, true, 0.8)
		"choice", "door_flag", "pick_item":
			caption_layer.visible = false
			_place_dialogue("you", false)
			dialogue.show_options(str(b.get("name", "")), str(b.get("text", "")), _options_for(b))
		"tutorial":
			caption_layer.visible = false
			var t2 := str(b["target"])
			view.highlight = [t2]
			_place_dialogue(str(b["who"]), str(b["who"]) == "narr")
			dialogue.show_line(str(b["name"]), str(b["text"]), db.npc_color(str(b["who"])), str(b["who"]) == "narr", false, float(db.cast.get(str(b["who"]), {}).get("voice_pitch", 1.0)))
			dialogue.set_hint("（点发亮的「%s」）" % db.hotspot_label(t2))
			_glow_tip(t2, "点这里：%s" % db.hotspot_label(t2))
		"practice":
			if b["kind"] == "inspect":
				view.counter_items = b["session"].item_ids
				dialogue.show_line("", "（对着图鉴找不同：哪儿不一样，用朱笔圈出来。看完了点“看完了”。）", UiStyle.MIST, true, false)
				inspect.open(b["session"], "", true)
			else:
				sidebar.open_practice()
				_show_sidebar()
				dialogue.show_line("", "（在弹出的算盘上拨几颗珠子，再按“出价”。）", UiStyle.MIST, true, false)
		"counter":
			_open_counter(b)
		"ticket":
			ticket.open(b["draft"], b.get("practice", false))
			dialogue.show_line("", "（登记、填当票、盖章、交钱收物。）", UiStyle.MIST, true, false)
		"stow":
			view.highlight = ["pawnbox"] if (b.get("practice", false) or b.get("pawn", false)) else ["pawnbox", "trash"]
			view.counter_items = b["iids"]
			view.selected_item = ""
			var trash_txt := "" if (b.get("practice", false) or b.get("pawn", false)) else "；没用的、不该留的，放进垃圾箱"
			dialogue.show_line("", "（收下了，就放进典当盒%s：先点柜台上的当物，再点发亮的盒子；也可以直接拖过去。）" % trash_txt, UiStyle.MIST, true, false)
			_show_stow_hint()
		"ledger":
			book.open("ledger", world)
			dialogue.show_line("", "（账簿：钱匣里还有多少，翻它就知道。看完合上。）", UiStyle.MIST, true, false)
		"summary":
			_open_summary(b)
		"night":
			_open_night(b)
		"telegraph":
			telegraph.beeper = beeper
			telegraph.open(b)
			dialogue.show_line("", str(b.get("prompt", "")), UiStyle.MIST, true, false)
		"chess":
			view.pieces = b["pieces"]
			view.pieces_done = []
			for p in b["pieces"]:
				if not b["remaining"].has(p["key"]):
					view.pieces_done.append(p["key"])
			dialogue.show_line(db.npc_label("chen"), "（陈叔叔把六枚棋子摆在柜台上。点一枚，听他说。）", db.npc_color("chen"), true, false)
		"ending":
			_open_ending(b)
		_:
			push_error("界面不认识的 beat：" + cur_type)

func _counter_items_now() -> Array:
	if world == null:
		return []
	return world.ledger.items_at("counter")

func _options_for(b: Dictionary) -> Array:
	match str(b["type"]):
		"door_flag":
			var out: Array = []
			for o in b["options"]:
				out.append({"id": o["id"], "label": "%s（街坊看：%s）" % [o["label"], o.get("public", "")]})
			return out
		"pick_item":
			var out2: Array = []
			for iid in b["iids"]:
				var it: Dictionary = world.ledger.items[iid]
				if director != null and director.shop_only():
					# [shop-only] 不写市价（买来的假货在这里不露底）、不写加成：名字和自己账上的数
					var done := "，整理过" if float(it.get("tidy_bonus", 0.0)) > 0.0 else ""
					out2.append({"id": iid, "label": "%s（%s%s）" % [it["name"], director.walkin().record_of(str(iid)), done]})
					continue
				var tidy := "，整理过 +%d%%" % int(round(float(it.get("tidy_bonus", 0.0)) * 100)) if float(it.get("tidy_bonus", 0.0)) > 0.0 else ""
				out2.append({"id": iid, "label": "%s（约 %d 蚨%s）" % [it["name"], world.market_now(it), tidy]})
			return out2
	return b["options"]

func _respond(r: Dictionary) -> void:
	if cur.is_empty() or _respond_lock:
		return
	cur = {}
	var t := cur_type
	cur_type = ""
	view.highlight = []
	view.pieces = []
	view.selected_item = ""
	stow_hint.visible = false
	if t == "stow":
		toast_lbl.visible = false
	dialogue.clear_options()
	dialogue.clear_actions()
	if t == "caption":
		caption_layer.visible = false
	if t in ["summary", "night", "ending"]:
		generic_panel.visible = false
	if t == "ledger":
		book.visible = false
	if t == "practice":
		inspect.visible = false
		if sidebar.practice_mode:
			sidebar.close_session(world)
			_hide_sidebar()
	if t == "counter":
		sidebar.enabled = false
		# 议价结束先不强制关（结果还在看）；下一 beat 非 counter 时 close_session 会收起
	_clear_bottom_hint()
	if dialogue != null and t not in ["say", "narr", "choice", "door_flag", "pick_item", "counter", "tutorial"]:
		# 非对白类 beat 的清空在各自 open；此处保证空闲不留底栏字
		pass
	director.submit(r)

# ---------------- 交互回调 ----------------
func _on_dialogue_advanced() -> void:
	if cur_type in ["say", "narr"]:
		_respond({})

func _on_option(id: String) -> void:
	if cur_type in ["choice", "door_flag", "pick_item"]:
		_respond({"id": id})

# 点场景空白处（不是热点）：对白就往下走——玩家常常点在画面上而不是对白框里
func _on_scene_click() -> void:
	if cur_type in ["say", "narr"] and not book.visible and not inspect.visible:
		dialogue.click()
	elif cur_type == "caption":
		_respond({})

func _on_hotspot(id: String) -> void:
	if beeper != null:
		beeper.click()
	if cur_type == "tutorial" and id == str(cur.get("target", "")):
		_respond({"target": id})
		return
	if cur_type == "stow" and id in view.highlight:
		if view.selected_item == "" and not view.counter_items.is_empty():
			view.selected_item = view.counter_items[0]   # 直接点盒子也行：默认就是柜台上这件
		_respond({"to": id})
		return
	if cur_type == "tutorial" or cur_type == "caption":
		_toast("先点发亮的那样东西。")
		return
	match id:
		"ledger":
			if world.unlocked.get("ledger", false):
				book.open("ledger", world)
		"notebook":
			if world.unlocked.get("notebook", false):
				book.open("notebook", world)
		"medbook":
			if world.unlocked.get("medbook", false):
				_open_medbook()
		"magnifier", "counter_item":
			if cur_type == "counter" and director.session != null:
				inspect.open(director.session)
		"abacus":
			_show_sidebar()
			if cur_type == "counter":
				_glow_tip("abacus", "拨珠报价；嘴说：××蚨")
				if sidebar != null:
					sidebar.focus_abacus()
			else:
				_glow_tip("abacus", "算盘已打开 · 可练口述报价")
				if sidebar != null and sidebar.session == null and not sidebar.practice_mode:
					sidebar.open_practice()
		"calendar":
			_open_calendar()
		"telegraph":
			if town != null and mode != "legacy":
				_toast(str(town.telegraph_state()["text"]))        # 小镇版：整个游戏只有一处规则（TownGame.telegraph_state）
			elif world.slot == 5:
				_toast("电报机在柜子里。夜里吹灯前，在夜里的事情里选“发电报”。")
			else:
				_toast("白天别碰。夜里关了门再用。")
		"customer":
			if director.customer != "":
				_toast(str(db.cast.get(director.customer, {}).get("look", "")))
		"door_flag":
			_toast("门旗：%s。夜里可以换。" % _flag_label(world.door_flag))
		"sign":
			_toast("招牌。夜里可以换。")
		"lamp":
			_toast("油灯。" + ("今晚还剩 %d 盏灯油。" % director.lamps if world.slot == 5 else ""))
		"trash":
			_toast("垃圾箱：%d 件。夜里可以烧掉。" % world.ledger.items_at("trash").size())
		"pawnbox":
			_toast("典当盒：%d 件活当、库房 %d 件。" % [world.ledger.items_at("pawnbox").size(), world.ledger.items_at("stock").size()])
		"scale":
			_toast("小秤：称废品和金银。验货时点“秤”的部位。")

func _on_item_dropped(iid: String, hs: String) -> void:
	if cur_type == "stow" and hs in view.highlight:
		view.selected_item = iid
		_respond({"to": hs})
	elif cur_type == "counter" and hs in ["magnifier", "counter_item"] and director.session != null and director.session.item_ids.has(iid):
		inspect.open(director.session, iid)

func _on_hover_text(text: String, gpos: Vector2) -> void:
	if text == "":
		hover_lbl.visible = false
		return
	hover_lbl.text = text
	hover_lbl.visible = true
	hover_lbl.reset_size()
	var p := gpos + Vector2(18, 14)
	p.x = clampf(p.x, 8.0, 1272.0 - hover_lbl.size.x)
	p.y = clampf(p.y, 8.0, 700.0 - hover_lbl.size.y)
	hover_lbl.position = p

func _on_dialogue_action(kind: String, id: String) -> void:
	_on_counter_action(id, kind)

func _show_stow_hint() -> void:
	var r: Rect2 = db.hotspot("pawnbox")
	stow_hint.visible = true
	stow_hint.reset_size()
	stow_hint.position = Vector2(r.position.x * VIEW_SCALE + r.size.x * VIEW_SCALE + 16, r.position.y * VIEW_SCALE + 18)

func _flag_label(id: String) -> String:
	for f in db.factions.get("door_flags", []):
		if f["id"] == id:
			return f["label"]
	return "不挂"

func _open_medbook() -> void:
	book.open("medbook", world)
	if inspect.visible:
		_place(book, Rect2(560, 16, 700, 508))
	else:
		_place(book, Rect2(40, 16, 880, 508))

func _on_book_closed() -> void:
	_place(book, Rect2(40, 16, 880, 508))
	if cur_type == "ledger":
		_respond({})

func _on_item_clicked(iid: String) -> void:
	if cur_type == "stow":
		view.selected_item = iid
		_toast("选好了。再点发亮的%s。" % ("典当盒" if view.highlight.size() == 1 else "典当盒（或垃圾箱）"))
		return
	if cur_type == "counter" and director.session != null and director.session.item_ids.has(iid):
		inspect.open(director.session, iid)
	elif world.ledger.items.has(iid):
		_toast(str(world.ledger.items[iid]["name"]))

func _on_piece(key: String) -> void:
	if cur_type == "chess":
		_respond({"piece": key})

func _on_offer(v: int) -> void:
	if cur_type == "counter":
		_respond({"action": "offer", "value": v})
	elif cur_type == "practice" and str(cur.get("kind", "")) == "abacus":
		_respond({"value": v})

func _on_inspect_closed() -> void:
	# v0.3：关掉放大镜后立刻把柜台上的货重新摆出来（修「无法返回看货品」）
	if cur_type == "counter" and director.session != null:
		var items: Array = []
		for iid in director.session.item_ids:
			var loc: String = world.ledger.items[iid]["location"]
			if loc == "counter" or (director.session.mode == "sell" and loc == "stock"):
				items.append(iid)
		for iid in world.ledger.items_at("counter"):
			if not items.has(iid):
				items.append(iid)
		view.counter_items = items
		view.queue_redraw()
	sidebar.refresh(world)
	if cur_type == "counter" and director.session != null and not director.session.pending_events.is_empty():
		_respond({"action": "event"})

# v0.3：物品旁发光短提示（不用全局「提示」HUD）
var _glow_lbl: Label = null
var _glow_hs: String = ""

func _ensure_glow() -> void:
	if _glow_lbl != null:
		return
	_glow_lbl = UiStyle.label("", 14, UiStyle.LAMP, false)
	_glow_lbl.add_theme_stylebox_override("normal", UiStyle.box(Color(0.12, 0.09, 0.07, 0.85), UiStyle.LAMP, 2, 2, 6))
	_glow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_lbl.visible = false
	overlay.add_child(_glow_lbl)

func _glow_tip(hotspot_id: String, text: String) -> void:
	_ensure_glow()
	_glow_hs = hotspot_id
	_glow_lbl.text = text
	_glow_lbl.visible = true
	_glow_lbl.modulate = Color(1, 1, 1, 1)
	_glow_lbl.reset_size()
	var r: Rect2 = db.hotspot(hotspot_id) if db.hotspot(hotspot_id).size != Vector2.ZERO else Rect2(100, 100, 20, 20)
	_glow_lbl.position = Vector2(r.position.x * VIEW_SCALE + r.size.x * VIEW_SCALE + 8, r.position.y * VIEW_SCALE)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_glow_lbl, "modulate:a", 0.0, 0.7)
	tw.tween_callback(func(): _glow_lbl.visible = false)

func _open_calendar() -> void:
	_clear_generic()
	generic_panel.set_meta("closable", true)
	_place(generic_panel, Rect2(200, 60, 560, 420))
	generic_panel.visible = true
	generic_box.add_child(UiStyle.title_label("万年历", 32))
	generic_box.add_child(UiStyle.label(world.date_text() + " · " + world.slot_name(), 20, UiStyle.INK))
	generic_box.add_child(UiStyle.hsep(UiStyle.SEAL))
	generic_box.add_child(UiStyle.label("青溪镇 · 德厚当", 16, UiStyle.INK_SOFT))
	generic_box.add_child(UiStyle.label("今日行情：%s" % world.price_board(), 15, UiStyle.INK_SOFT))
	# 客观到期事项只在万年历/账簿里看，不再刷全局待办 HUD
	var any := false
	for td in world.todos:
		if td["status"] != "未了":
			continue
		any = true
		var due := ""
		if int(td["due_day"]) >= 0:
			due = " · 至 %s" % world.date_text(int(td["due_day"]))
		generic_box.add_child(UiStyle.label("· %s：%s%s" % [td["who"], td["text"], due], 14, UiStyle.INK_SOFT))
	if not any:
		generic_box.add_child(UiStyle.label("· （眼下没有写进日历的事）", 14, UiStyle.INK_SOFT))
	var btn := UiStyle.button("合上", 17, "wood")
	btn.pressed.connect(func():
		generic_panel.visible = false
		_clear_generic()
	)
	generic_box.add_child(btn)

func _toast(t: String) -> void:
	toast_lbl.text = t
	toast_lbl.visible = t != ""
	toast_lbl.reset_size()
	var tw := create_tween()
	toast_lbl.modulate.a = 1.0
	tw.tween_interval(2.2)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.6)

# ---------------- 柜台 ----------------
func _open_counter(b: Dictionary) -> void:
	var s = b["session"]
	caption_layer.visible = false
	var items: Array = []
	for iid in s.item_ids:
		var loc: String = world.ledger.items[iid]["location"]
		if loc == "counter" or (s.mode == "sell" and loc == "stock"):
			items.append(iid)
	for iid in world.ledger.items_at("counter"):
		if not items.has(iid):
			items.append(iid)
	view.counter_items = items
	sidebar.open_session(s, b.get("extras", []), b.get("deals", []), true)
	_show_sidebar()
	var acts: Array = []
	for e in b.get("extras", []):
		acts.append({"kind": "extra", "id": e["id"], "label": "◇ " + str(e["label"])})
	for d in b.get("deals", []):
		acts.append({"kind": "deal", "id": d["id"], "label": "◆ " + str(d["label"])})
	var tip := "（点货验看 / 拨算盘出价 / 点下面选项。）"
	if s.mode == "sell":
		tip = "（客人要买。可只勾一件卖；议价中也能再验。）"
	if s.needs_more_inspection():
		tip = "（先用放大镜多看几处，再谈价钱。）"
	var lab: Dictionary = s.def.get("labels", {})      # [shop-only] 保护费讲价：没有货可验，字眼也换一套
	if lab.has("tip"):
		tip = str(lab["tip"])
	_place_dialogue(s.npc_id, false)
	dialogue.show_line(db.npc_label(s.npc_id), tip, db.npc_color(s.npc_id), true, false)
	# v0.3：议价中可交互——再验、只卖一件、查账簿
	if not bool(lab.get("no_inspect", false)):
		acts.append({"kind": "extra", "id": "_inspect_again", "label": "◇ 再验一次"})
	if s.mode == "sell" and s.item_ids.size() > 1:
		acts.append({"kind": "extra", "id": "_sell_one", "label": "◇ 只卖一件"})
	acts.append({"kind": "extra", "id": "_open_ledger", "label": "◇ 翻账簿"})
	dialogue.show_actions(acts)

# ---------------- 日结 ----------------
func _clear_generic() -> void:
	generic_panel.set_meta("closable", false)      # 万年历、“只卖一件”这类纯看的小面板自己再打开这个开关
	for c in generic_box.get_children():
		generic_box.remove_child(c)
		c.queue_free()

func _open_summary(b: Dictionary) -> void:
	_clear_generic()
	_place(generic_panel, Rect2(100, 20, 760, 500))
	generic_panel.visible = true
	generic_box.add_child(UiStyle.title_label(str(b["title"]), 34))
	generic_box.add_child(UiStyle.label("收入 %d 蚨　　支出 %d 蚨　　钱匣余额 %d 蚨（%s）" % [b["income"], b["expense"], b["balance"], UiStyle.cn_money(int(b["balance"]))], 19))
	generic_box.add_child(UiStyle.hsep(UiStyle.SEAL))
	var v := UiStyle.vbox(2)
	for r in b["rows"]:
		v.add_child(UiStyle.label("%s %d 蚨 · %s" % [r[0], r[1], r[2]], 15, UiStyle.INK_SOFT))
	v.add_child(UiStyle.hsep())
	v.add_child(UiStyle.label("库存：", 16))
	if b["stock"].is_empty():
		v.add_child(UiStyle.label("　（空）", 15, UiStyle.INK_SOFT))
	for s in b["stock"]:
		v.add_child(UiStyle.label("　· " + str(s), 15, UiStyle.INK_SOFT))
	if not b["debts"].is_empty():
		v.add_child(UiStyle.label("借据：", 16))
		for d in b["debts"]:
			v.add_child(UiStyle.label("　· " + str(d), 15, UiStyle.INK_SOFT))
	generic_box.add_child(UiStyle.scroll(v))
	var btn := UiStyle.button("合上账簿", 18, "wood")
	btn.pressed.connect(func(): _respond({}))
	btn.set_meta("auto", true)
	generic_box.add_child(btn)
	dialogue.show_line("", "（账目：每一蚨都有来处。）", UiStyle.MIST, true, false)

# ---------------- 夜晚 ----------------
func _open_night(b: Dictionary) -> void:
	_clear_generic()
	_place(generic_panel, Rect2(150, 40, 660, 460))
	generic_panel.visible = true
	var head := UiStyle.hbox(12)
	generic_box.add_child(head)
	head.add_child(UiStyle.title_label("第%s晚" % ["", "一", "二", "三"][clampi(int(b["night"]), 0, 3)], 32))
	var lamps := ""
	for i in range(int(b["max_lamps"])):
		lamps += "● " if i < int(b["lamps"]) else "○ "
	head.add_child(UiStyle.label("灯油：" + lamps, 20, UiStyle.SEAL, false))
	if int(b.get("max_actions", 99)) < 99:
		generic_box.add_child(UiStyle.label("（今晚还能做 %d 件事）" % (int(b["max_actions"]) - int(b.get("used", 0))), 15, UiStyle.INK_SOFT))
	generic_box.add_child(UiStyle.hsep(UiStyle.SEAL))
	for a in b["actions"]:
		var lbl := "%s%s%s" % [a["label"], " ★" if a.get("star", false) else "", "（耗一盏灯油）" if int(a["cost"]) > 0 else "（不耗灯油）"]
		var btn := UiStyle.button(lbl, 17, "seal" if a["id"] == "sleep" else "paper", true)
		btn.disabled = not a["enabled"]
		btn.tooltip_text = str(a.get("desc", ""))
		var id: String = a["id"]
		btn.pressed.connect(func(): _respond({"id": id}))
		btn.set_meta("id", id)
		generic_box.add_child(btn)
		var night_desc := str(a.get("desc", ""))
		if not a["enabled"] and id == "telegraph" and town != null and mode != "legacy":
			night_desc = str(town.telegraph_state()["text"])        # 灰着的“发电报”要说为什么
		if night_desc != "":
			generic_box.add_child(UiStyle.label("　" + night_desc, 13, UiStyle.INK_SOFT))
	dialogue.show_line("", "（上了门板。屋里只有一盏油灯。）", UiStyle.MIST, true, false)

# ---------------- 结尾：德字第一九六号 ----------------
func _open_ending(b: Dictionary) -> void:
	_clear_generic()
	_place(generic_panel, Rect2(250, 20, 460, 500))
	generic_panel.visible = true
	caption_layer.visible = false
	var tk: Dictionary = b.get("ticket", {})
	generic_box.add_child(UiStyle.title_label("当　票", 40, UiStyle.SEAL))
	var tr := TextureRect.new()
	tr.texture = DB.tex("art/ui/ticket_blank.png")
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = Vector2(150, 200)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	generic_box.add_child(tr)
	generic_box.add_child(UiStyle.title_label(str(tk.get("no", "德字第一九六号")), 36))
	generic_box.add_child(UiStyle.label("字是爸的。", 18, UiStyle.INK_SOFT))
	generic_box.add_child(UiStyle.label("日期：%s——爸妈离家的那一天" % tk.get("date", ""), 18))
	generic_box.add_child(UiStyle.label("当户：　　　　（空）", 18))
	var btn := UiStyle.button("……", 18, "wood")
	btn.pressed.connect(func(): _respond({}))
	generic_box.add_child(btn)
	dialogue.show_line("", "（蓝布包里是一张当票。）", UiStyle.MIST, true, false)

# 第一章 · 未完：试玩版结束画面，点击回到标题
var _end_layer: Control = null

func _show_end_card() -> void:
	_end_layer = ColorRect.new()
	_end_layer.color = Color("#0d0a08")
	_end_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_end_layer)
	var v := UiStyle.vbox(18)
	v.position = Vector2(0, 200)
	v.size = Vector2(1280, 360)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_layer.add_child(v)
	var t1 := UiStyle.title_label("第一章 · 未完", 64, UiStyle.LAMP_PALE)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var t2 := UiStyle.label("《德厚当》试玩版 v0.3 完 · 待续", 24, UiStyle.PAPER, false)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	var t3 := UiStyle.label("钱匣 %d 蚨　·　口碑 %d　·　活当 %d 张　·　档案簿 %d 条" % [world.cash(), world.koubei, world.ledger.contracts.size(), world.notebook.size()], 17, UiStyle.MIST, false)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t3)
	var btn := UiStyle.button("回到标题", 20, "seal")
	btn.custom_minimum_size = Vector2(220, 48)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_back_to_title)
	v.add_child(btn)
	if shots_dir != "":
		shot_plan["endcard"] = "m4_endcard.png"
		await _capture("endcard")
	elif autoplayer != null:
		await get_tree().create_timer(1.0).timeout

func _back_to_title() -> void:
	get_tree().reload_current_scene()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		# 小镇版（非 legacy、非标题）：Esc 归 TownGame（先关面板，再暂停菜单），这里不再拿 Esc 推进对白；
		# 对白、字幕往下走用 E / 空格 / 回车 / 点击。legacy 保持老样子：Esc 推进对白（防卡死测试靠它）。
		var in_town := mode != "legacy" and mode != "title"
		# 选项可以用数字键 1–9 选（R3：选择态键盘无法选支）
		if cur_type in ["choice", "door_flag", "pick_item"] and ev.keycode >= KEY_1 and ev.keycode <= KEY_9:
			var n: int = ev.keycode - KEY_1
			var opts: Array = _options_for(cur)
			if n < opts.size():
				_respond({"id": str(opts[n]["id"])})
			return
		if ev.keycode == KEY_M:
			toggle_mute()      # M：音效开 / 关（小镇与 legacy 都可用）
			return
		if in_town and ev.keycode == KEY_E and close_topmost_panel(true):
			get_viewport().set_input_as_handled()       # E 关掉册子/万年历：这一下不再往下传
			return
		if ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or (in_town and ev.keycode == KEY_E):
			if cur_type in ["say", "narr"]:
				dialogue.click()
			elif cur_type == "caption":
				_respond({})
		elif ev.keycode == KEY_ESCAPE and not in_town:
			# Esc：先关掉盖在上面的册子/验货面板；没有的话，对白就直接跳到下一句（不会卡死）
			if book.visible and cur_type != "ledger":
				book.visible = false
			elif book.visible and cur_type == "ledger":
				book._close()
			elif inspect.visible and cur_type == "counter":
				inspect._on_close()
			elif cur_type in ["say", "narr"]:
				dialogue.skip()
			elif cur_type == "caption":
				_respond({})

# ====================================================================
# 自动试玩（界面路径）：autoplayer 决定回应，这里经由面板执行；按计划截图。
func auto_apply(b: Dictionary, r: Dictionary) -> void:
	if b != cur:
		return
	await _maybe_shot(b, r)
	if b != cur:
		return
	match str(b["type"]):
		"say", "narr":
			# 测试不同的“往下走”方式（v0.2 防卡死回归）：点对白框 / 按 Esc / 点画面空白处 / 点“跳过”
			match auto_say_mode:
				"esc":
					var ev := InputEventKey.new()
					ev.keycode = KEY_ESCAPE
					ev.pressed = true
					_unhandled_input(ev)
				"scene":
					dialogue.finish_typing()
					_on_scene_click()
				"skip":
					if not dialogue.skip_btn.visible and autoplayer != null:
						autoplayer.errors.append("对白时看不到“跳过”按钮")
					dialogue.skip_btn.emit_signal("pressed")
				_:
					dialogue.finish_typing()
					dialogue.click()
			if b == cur and autoplayer != null:
				autoplayer.errors.append("对白点了没反应（%s）：%s" % [auto_say_mode, str(b.get("text", "")).substr(0, 20)])
				_respond(r)
		"caption":
			_respond({})
		"choice", "door_flag", "pick_item":
			var btn: Button = dialogue.option_button(str(r.get("id", "")))
			if btn != null:
				btn.emit_signal("pressed")
			else:
				_respond(r)
		"tutorial":
			view.emit_signal("hotspot_clicked", str(b["target"]))
		"stow":
			if not view.counter_items.is_empty():
				view.emit_signal("item_clicked", str(view.counter_items[0]))
			view.emit_signal("hotspot_clicked", str(r.get("to", "pawnbox")))
		"practice":
			if b["kind"] == "inspect":
				inspect._rebuild()
				inspect._on_close()
			else:
				sidebar.set_value(int(r.get("value", 50)))
				sidebar.offer_btn.emit_signal("pressed")
		"counter":
			match str(r.get("action", "")):
				"offer":
					sidebar.set_value(int(r["value"]))
					sidebar.offer_btn.emit_signal("pressed")
				"extra", "deal":
					var eb: Button = dialogue.action_button(str(r["action"]), str(r["id"]))
					if eb != null:
						eb.emit_signal("pressed")
					else:
						_respond(r)
				"event":
					inspect.open(b["session"])
					inspect._on_close()
					if b == cur:   # 没有待发事件时 _on_inspect_closed 不回应：直接刷新柜台
						_respond(r)
				"refuse":
					if not sidebar.refuse_btn.visible and autoplayer != null:
						autoplayer.errors.append("柜台上没有“不做了”的出口：" + str(b["session"].def.get("id", "")))
					sidebar.refuse_btn.emit_signal("pressed")
					if b == cur:
						_respond(r)
				_:
					_respond(r)
		"ticket":
			ticket.choose(str(r.get("condition", "true")))
			ticket._stamp()
			ticket._give()
		"ledger":
			book.close_btn.emit_signal("pressed")
		"telegraph":
			telegraph.auto_decode()
			if r.get("skip", false):
				telegraph.skip_btn.emit_signal("pressed")
			elif r.has("words"):
				telegraph.picked = r["words"].duplicate()
				telegraph._send()
			else:
				telegraph.done_btn.emit_signal("pressed")
		"chess":
			view.emit_signal("piece_clicked", str(r.get("piece", "")))
		"night":
			for c in generic_box.get_children():
				if c is Button and c.get_meta("id", "") == str(r.get("id", "")):
					c.emit_signal("pressed")
					return
			_respond(r)
		_:
			_respond(r)

# ---------------- 截图 ----------------
func _init_shot_plan() -> void:
	# 触发键 → 文件名（每个只截一次）
	shot_plan = {
		"title": "m1_title.png",
		"caption#1": "m2_prologue_1_caption.png",
		"say:brother#1": "m2_prologue_2_candle.png",
		"tutorial:pawnbox": "m2_prologue_3_tutorial.png",
		"practice:inspect#1": "m2_prologue_4_inspect_coin.png",
		"practice:abacus": "m2_prologue_5_abacus.png",
		"ledger#1": "m2_prologue_6_ledger.png",
		"chess#3": "m2_prologue_7_chess.png",
		"say:chen#3": "m2_prologue_8_chen.png",
		"door_flag#1": "m2_prologue_9_doorflag.png",
		"counter:d1_xiaoding#1": "m1_framework.png",
		"inspect:d1_zhang": "m3_day1_zhang.png",
		"counter:d1_xiaoding#3": "m3_day1_xiaoding.png",
		"counter:d1_wangshan#2": "m3_day1_wangshan.png",
		"choice@d1_li#1": "m3_day1_li.png",
		"summary#1": "m3_day_summary.png",
		"notebook:day1": "m3_notebook.png",
		"night#1": "m4_night1.png",
		"ticket#1": "m4_dawn_practice.png",
		"ticket#2": "m4_linsao.png",
		"inspect:d2_zhao": "m4_zhao.png",
		"choice@d2_farewell#1": "m4_farewell.png",
		"inspect:d2_sunyoung": "m4_sun_fake_deed.png",
		"say:ma#3": "m4_mabaozhang.png",
		"ledger:night2": "m4_ledger.png",
		"telegraph#1": "m4_telegraph.png",
		"ending#1": "m4_cliffhanger.png",
		"counter:d2_xiaoding_return#1": "v02_branch.png",
		"counter:d2_guanjia#1": "v02_branch_guanjia.png",
		"night_backdoor": "v02_branch_backdoor.png",
		"dialogue_exit": "v02_dialogue_exit.png",
		"tidy_persist": "v02_tidy_persist.png",
		"bargain_exit": "v02_bargain_exit.png",
		"stow#1": "m5_fix_pawnbox_hint.png",
		"typewriter": "m5_fix_typewriter.png",
		"inspect:d1_xiaoding": "m5_fix_inspect.png",
		"counter:d1_xiaoding#2": "m5_fix_no_floorprice.png",
		"tutorial:abacus": "m5_fix_hotspots.png",
	}


var _shot_counts: Dictionary = {}

func capture_town_shot(shot_name: String) -> void:
	# 小镇模式的截图：shots_dir/v04_<名字>.png，每个名字只截一次
	var key := "v04_" + shot_name
	if shots_dir == "" or shots_done.has(key):
		return
	shot_plan[key] = key + ".png"
	await _capture(key)

func _maybe_shot(b: Dictionary, r: Dictionary) -> void:
	if shots_dir == "":
		return
	if town != null and str(b["type"]) == "counter" and not shots_done.has("v04_counter"):
		await capture_town_shot("counter")
	var t := str(b["type"])
	var keys: Array = [t]
	match t:
		"say": keys = ["say:" + str(b["who"])]
		"tutorial": keys = ["tutorial:" + str(b["target"])]
		"practice": keys = ["practice:" + str(b["kind"])]
		"counter": keys = ["counter:" + str(b["session"].def.get("id", ""))]
		"choice":
			keys = ["choice@" + (str(director.session.def.get("id", "")) if director.session != null else director.current_script)]
	var fire := ""
	for k in keys:
		_shot_counts[k] = int(_shot_counts.get(k, 0)) + 1
		for cand in [k, "%s#%d" % [k, _shot_counts[k]]]:
			if shot_plan.has(cand) and not shots_done.has(cand):
				fire = cand
	if t == "counter" and str(b["session"].def.get("id", "")) == "d1_zhang" and not shots_done.has("inspect:d1_zhang") and b["session"].inspected_total() >= 3:
		inspect.open(b["session"], b["session"].iid_of("sulfa_fake"))
		_open_medbook()
		book.page_idx = 99
		book._render()
		await _capture("inspect:d1_zhang")
		book.visible = false
		_place(book, Rect2(40, 16, 880, 508))
		inspect.visible = false
	if t == "say" and str(b["who"]) == "chen" and not shots_done.has("typewriter"):
		dialogue.instant = false
		dialogue.show_line(str(b["name"]), str(b["text"]), db.npc_color("chen"), false, true, 0.9)
		await get_tree().create_timer(0.05).timeout
		await _capture("typewriter", true)
		dialogue.instant = true
		dialogue.finish_typing()
	if t == "counter" and str(b["session"].def.get("id", "")) == "d1_xiaoding" and not shots_done.has("inspect:d1_xiaoding") and b["session"].inspected_total() >= 3:
		inspect.open(b["session"])
		await _capture("inspect:d1_xiaoding")
		inspect.visible = false
	if t == "counter" and str(b["session"].def.get("id", "")) == "d2_zhao" and not shots_done.has("inspect:d2_zhao") and b["session"].inspected_total() >= 4:
		inspect.open(b["session"])
		await _capture("inspect:d2_zhao")
		inspect.visible = false
	if t == "counter" and str(b["session"].def.get("id", "")) == "d2_sunyoung" and not shots_done.has("inspect:d2_sunyoung") and b["session"].inspected_total() >= 2:
		inspect.open(b["session"])
		await _capture("inspect:d2_sunyoung")
		inspect.visible = false
	if t == "say" and not shots_done.has("dialogue_exit") and world.day >= 1 and str(b["who"]) != "you":
		dialogue.instant = false
		dialogue.show_line(str(b["name"]), str(b["text"]), db.npc_color(str(b["who"])), false, true, 1.0)
		await get_tree().create_timer(0.05).timeout
		await _capture("dialogue_exit", true)
		dialogue.instant = true
		dialogue.finish_typing()
	if t == "say" and director.current_script == "d2_xiaoding_return" and str(b["who"]) == "xiaoding" and not shots_done.has("xiaoding_return"):
		shot_plan["xiaoding_return"] = "v02_branch.png"
		await _capture("xiaoding_return")
	if t == "pick_item" and director.night_no == 2 and not shots_done.has("tidy_persist"):
		await _capture("tidy_persist")
	if t == "say" and director.session != null and director.session.closed and director.session.result in ["leave", ""] and str(b["who"]) == director.session.npc_id and not shots_done.has("bargain_exit"):
		await _capture("bargain_exit")
	if t == "choice" and director.current_script == "n1_backdoor" and not shots_done.has("night_backdoor"):
		await _capture("night_backdoor")
	if t == "night" and int(b.get("night", 0)) == 2 and not shots_done.has("ledger:night2"):
		generic_panel.visible = false
		book.open("ledger", world)
		book.tab = "待办"
		book._render()
		await _capture("ledger:night2")
		book.visible = false
		generic_panel.visible = true
	if t == "night" and int(b.get("night", 0)) == 1 and not shots_done.has("notebook:day1"):
		generic_panel.visible = false
		book.open("notebook", world)
		await _capture("notebook:day1")
		book.visible = false
		generic_panel.visible = true
	if fire == "":
		return
	if t == "practice" and b["kind"] == "inspect":
		inspect._rebuild()
	if t == "telegraph":
		telegraph.auto_decode()
		if r.has("words"):
			telegraph.picked = r["words"].duplicate()
			telegraph._refresh()
	if t == "ticket":
		ticket.choose(str(r.get("condition", "true")))
		ticket._stamp()
		await get_tree().create_timer(0.4).timeout
	if t == "ledger" and _shot_counts.get("ledger", 0) >= 3:
		book.tab = "活当"
		book._render()
	await _capture(fire)

func _capture(key: String, keep_typing: bool = false) -> void:
	shots_done[key] = true
	if not keep_typing:
		dialogue.finish_typing()
	await get_tree().create_timer(0.25 if not keep_typing else 0.02).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var dir := shots_dir
	if not dir.begins_with("/") and not dir.begins_with("res://"):
		dir = ProjectSettings.globalize_path("res://") + dir
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join(shot_plan[key])
	img.save_png(path)
	print("SHOT ", path)

func take_title_shot() -> void:
	if shots_dir != "" and shot_plan.has("title"):
		await _capture("title")
