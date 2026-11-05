## 战斗 v2 的战场面板（kind battle_v2，满屏 1280×720）。只读 campaign.battle2 / campaign.battle_preview 两个查询，
## 只发 campaign.battle_cmd {cmd, args}（规则内核的 deploy / withdraw / skill / card / aim / formation / carry / redraw /
## undo / fight / retreat）。打完了按「查看战果」换到战果面板（battle_result）。
## 高清 HUD（明日方舟式布局，帝国蓝金）：3D 战场铺满全屏在最底下（battle_board.gd，set_safe_area 让出 HUD 的地方）；
##   顶栏：战役名和皇帝的命令 · 我方军心条（交火后的预演）· 第 n/N 回合 · 敌军心条 · 撤销 / 战报 / 图例 / 撤退 · 金色「交火」，
##         下面一行红字警告（预演说会战败或有人倒下）；顶栏下方居中一行提示（当前操作，带「取消」）。
##   右下：部署牌（头像、费用、兵种、兵力、在场 / 冷却），上方是军令点（大数字、进度条、下回合 +n）和在场人数。
##   左下：军令牌（羊皮纸、蜡封费用）和「换牌」。
##   左侧：悬停或选中单位 / 敌人时滑出的情报栏（头像、兵种、兵力和交火后预演、攻防阻挡、技能、敌情）。
##   单位身边：选中我方单位时的圆按钮（技能带充能圈、撤下、方阵 / 瞄准、抬下）；部署选朝向时四个箭头围着那一格。
##   右侧：可收起的情报栏（来敌、羁绊、战报，战报「全部」展开整份日志）；图例在顶栏「图例」里。
##   确认交火、确认撤退、打完的横幅是居中的玻璃弹窗。
## 操作：点部署牌 → 点亮着的格子 → 选朝向；点格子上的单位 → 圆按钮；点军令牌，要目标的再点格子；悬停 → 情报栏和血条预演。
## Esc 先关战报 / 图例，再退出当前操作，再关面板。中文都在 data/campaigns/battle_ui.json；颜色走配色键（bthud_* / hd_*）；
## 没有 class_name。说明：docs/cards/BATTLE_V2.md「高清 HUD」。
extends CardPanel

const Ui = preload("res://scripts/cards/ui/battle/battle_ui.gd")
const Board = preload("res://scripts/cards/ui/battle/battle_board.gd")
const Rules = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const Kit = preload("res://scripts/cards/ui/battle/hud/hud_kit.gd")
const W = preload("res://scripts/cards/ui/battle/hud/hud_widgets.gd")
const Portrait = preload("res://scripts/cards/ui/battle/hud/hud_portrait.gd")
const D = preload("res://scripts/cards/ui/hd/hd_draw.gd")

const KIND := &"battle_v2"
const CMD := &"campaign.battle_cmd"
const SCREEN := Vector2(1280, 720)
const TOP_H := 58.0
const EDGE := 14.0
## 右侧情报栏
const COL_W := 214.0
const COL_Y := 104.0
const COL_BOTTOM := 528.0
const LOG_MIN := 84.0
const WAVES_MAX := 150.0
## 来敌框至少给几行（羁绊多的大仗里也看得清前两波）
const WAVES_ROWS := 4
## 单位身边的圆按钮：圆弧半径（带名字牌的高一点）、相邻按钮隔多少度、碰到东西沿弧挪的角度、弧上没地方往外挪多少、
## 不超过几个时说明字常显
const RING_R := 90.0
const RING_R_NAMED := 104.0
const RING_STEP := 44.0
const RING_SHIFTS := [0, 8, -8, 16, -16, 24, -24, 32, -32, 44, -44, 56, -56, 70, -70, 88, -88, 110, -110, 135, -135]
const RING_OUT := 30.0
const RING_CAPTIONS := 4
## 羁绊栏最多列几条（亮着的总列出来；超了就把差人的收进小签）
const BONDS_ROWS := 4
## 战报的行距
const LOG_SPACING := 1
## 地图的安全区：上让出顶栏和提示，下让出部署牌和军令牌
const SAFE_TOP := 100.0
const SAFE_BOTTOM := 178.0
## 左侧情报栏
const INFO_W := 256.0
const INFO_Y := 104.0
const INFO_MAX_H := 424.0
## 底部：部署牌、军令牌
const CARD_W := 84.0
const CARD_MIN_W := 64.0
const CARD_H := 104.0
const CARD_GAP := 6.0
const STRIP_Y := 604.0
const HAND_W := 120.0
const HAND_GAP := 8.0
const HAND_Y := 606.0
const CP_W := 196.0
## 军令牌要的目标：row 选一行，unit 选我方单位，cell 选一格；不在表里的直接打出
const CARD_TARGET := {"volley": "row", "bugler": "row", "bayonet": "unit", "fallback": "unit", "feint": "cell", "barrage": "cell"}
const DIRS := {"right": [1, 0], "left": [-1, 0], "up": [0, -1], "down": [0, 1]}
const LATERAL := {"right": [0, 1], "left": [0, -1], "up": [1, 0], "down": [-1, 0]}
## 部署牌上单位状态的底色
const STATE_KEYS := {"ok": "bthud_state_field", "dying": "bthud_state_dying", "carried": "bthud_state_out", "routed": "bthud_state_out",
	"down": "bthud_state_out", "out": "bthud_state_out"}

var kind: StringName = KIND
## 快动画（测试、自动试玩）：没有补间可跳，留着给宿主统一设
var fast: bool = false

var _q: Dictionary = {}
var _v: Dictionary = {}
## 上一份视图：交火回放还在放时，顶栏的回合、军心、军令点和战报先停在交火前（回放放完再换）
var _v_prev: Dictionary = {}
## 圆按钮那段弧最后用的半径
var _fan_r := 90.0
var _sig := ""
var _closed := false
## 当前操作：""、deploy（选了部署牌，等点格子）、facing（等选朝向）、target（技能 / 瞄准 / 军令等目标）、redraw、retreat、
## fight_confirm（预演说这一回合会战败或有人倒下，按交火先确认一次）
var _mode := ""
var _sel_unit := ""
var _sel_cell := Vector2i(-1, -1)
var _target: Dictionary = {}
var _act_unit := ""
var _hover := Vector2i(-1, -1)
var _preview: Dictionary = {}
var _preview_sig := ""
var _status := ""
## 每一块上次画的是什么（JSON 签名）：没变就不重建
var _secs: Dictionary = {}
var _bar_ids: Array = []
var _bar_cards: Dictionary = {}
var _info_key := ""
var _fight_risk := ""
var _log_open := false
var _legend_open := false
var _col_open := true
## 选骠骑兵朝向时的冲锋预演（campaign.battle_preview {cmd: deploy}）
var _charge: Dictionary = {}

var _board: Control
var _shade: Control
var _hud_title: Label
var _hud_order: Label
var _hud_turn: Label
var _pips: W.Pips
var _morale_bar: W.Bar
var _morale_num: Label
var _morale_after: Label
var _emorale_bar: W.Bar
var _emorale_num: Label
var _emorale_after: Label
var _hud_cp: Label
var _hud_cp_cap: Label
var _hud_cp_next: Label
var _cp_bar: W.Bar
var _cp_plate: Control
var _hud_field: Label
var _field_chip: Control
var _warn_box: PanelContainer
var _hud_warn: Label
var _status_box: PanelContainer
var _status_lbl: Label
var _btn_fight: Button
var _btn_undo: Button
var _btn_redraw: Button
var _btn_retreat: Button
var _btn_cancel: Button
var _btn_log: Button
var _btn_legend: Button
var _btn_col: Button
var _col: Control
var _waves_card: PanelContainer
var _waves_title: Label
var _waves_scroll: ScrollContainer
var _waves_box: VBoxContainer
var _bonds_card: PanelContainer
var _bonds_box: Control
var _log_card: PanelContainer
var _log_scroll: ScrollContainer
var _log_lbl: Label
var _log_more: Button
var _log_clip: Control
var _info_panel: PanelContainer
var _info_box: VBoxContainer
var _bar_row: Control
var _hand_row: Control
var _hand_head: Control
var _hand_count: Label
var _popup: Control
var _facing: Control
var _legend_panel: PanelContainer
var _legend_box: VBoxContainer
var _log_full: Control
var _log_full_lbl: Label
var _fight_box: Control
var _fight_lbl: Label
var _confirm: Control
var _banner: Control


func open(_args: Dictionary) -> void:
	_closed = false
	_ensure()
	_render(true)
	if _v.is_empty():
		# 没有在打的仗（存档换了、已经结算）：宿主接上关闭信号之后再关
		_close.call_deferred({})


func refresh(_view: Dictionary) -> void:
	if _closed or _board == null:
		return
	_render(false)


func dismiss() -> void:
	if _log_open:
		_toggle_log()
		return
	if _legend_open:
		_toggle_legend()
		return
	if _mode != "" or _act_unit != "":
		_cancel_mode()
		return
	_close({})


func autoplay_step() -> bool:
	if _closed or engine == null:
		return false
	if _v.is_empty():
		return false
	if str(_v.get("phase", "")) == "over":
		_on_result()
		return true
	_send("fight", {})
	return true


func _close(result: Dictionary) -> void:
	if _closed:
		return
	_closed = true
	close_requested.emit(result)


# ================================================================ 搭界面

func _ensure() -> void:
	if _board != null:
		return
	size = SCREEN
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Kit.theme()
	HdTheme.apply_hd_filter(self)
	var bg := ColorRect.new()
	bg.color = Kit.col("hd_ink")
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_board = Board.new()
	_board.name = "Board"
	_board.position = Vector2.ZERO
	_board.size = SCREEN
	add_child(_board)
	_board.set_safe_area(_safe_rect())
	_board.cell_pressed.connect(_on_cell)
	_board.cell_hovered.connect(_on_hover)
	_board.cell_left.connect(_on_leave)
	_board.playback_finished.connect(_on_playback_done)
	_shade = W.Shade.new()
	_shade.name = "HudShade"
	_shade.size = SCREEN
	add_child(_shade)
	_build_top()
	_build_column()
	_build_bottom()
	_build_info()
	_popup = Control.new()
	_popup.name = "Actions"
	_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.size = SCREEN
	_popup.visible = false
	add_child(_popup)
	_facing = Control.new()
	_facing.name = "Facing"
	_facing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_facing.size = SCREEN
	_facing.visible = false
	add_child(_facing)
	_build_legend()
	_build_log_full()
	_build_modals()


func _safe_rect() -> Rect2:
	var right := SCREEN.x - EDGE - (COL_W + 10.0 if _col_open else 0.0)
	return Rect2(EDGE, SAFE_TOP, right - EDGE, SCREEN.y - SAFE_TOP - SAFE_BOTTOM)


func _add(node: Control, pos: Vector2, parent: Node = null) -> Control:
	node.position = pos
	(parent if parent != null else self).add_child(node)
	return node


## 顶栏：玻璃条 + 左标题 / 中军心和回合 / 右按钮和交火
func _build_top() -> void:
	var bar := Kit.plate(Rect2(0, 0, SCREEN.x, TOP_H), "hud", "TopBar")
	add_child(bar)
	var emblem := Emblem.new()
	emblem.glyph = Ui.text("hud_emblem")
	emblem.size = Vector2(34, 34)
	_add(emblem, Vector2(10, 12))
	_hud_title = Kit.lbl("", 19, "title", "hd_gold_hi")
	_hud_title.name = "Title"
	_hud_title.size = Vector2(330, 26)
	_hud_title.clip_text = true
	_add(_hud_title, Vector2(52, 5))
	_hud_order = Kit.lbl("", 12, "sans", "hd_text_2")
	_hud_order.name = "Order"
	_hud_order.size = Vector2(330, 18)
	_hud_order.clip_text = true
	_add(_hud_order, Vector2(53, 33))
	# 我方军心（左）、回合（中）、敌军心（右）
	var mx := 392.0
	var mw := 166.0
	_add(Kit.lbl(Ui.text("hud_morale_name"), 12, "sans_bold", "bthud_morale_hi"), Vector2(mx, 6))
	_morale_num = Kit.lbl("", 15, "num", "hd_text")
	_morale_num.size = Vector2(80, 20)
	_morale_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add(_morale_num, Vector2(mx + mw - 80, 3))
	_morale_bar = W.Bar.new()
	_morale_bar.name = "MoraleBar"
	_morale_bar.size = Vector2(mw, 11)
	_morale_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_morale_bar.tooltip_text = Ui.text("morale_tiers")
	_morale_bar.ticks = [[3, "bthud_tier_low"], [12, "bthud_tier_high"]]
	_add(_morale_bar, Vector2(mx, 25))
	_morale_after = Kit.lbl("", 11, "sans", "hd_text_2")
	_morale_after.size = Vector2(mw, 16)
	_add(_morale_after, Vector2(mx, 38))
	_hud_turn = Kit.lbl("", 21, "title", "hd_text")
	_hud_turn.name = "Turn"
	_hud_turn.size = Vector2(150, 28)
	_hud_turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(_hud_turn, Vector2(SCREEN.x * 0.5 - 75, 3))
	_pips = W.Pips.new()
	_pips.size = Vector2(150, 14)
	_add(_pips, Vector2(SCREEN.x * 0.5 - 75, 36))
	var ex := SCREEN.x - mx - mw
	_add(Kit.lbl(Ui.text("hud_enemy_morale_name"), 12, "sans_bold", "bthud_emorale_hi"), Vector2(ex, 6))
	_emorale_num = Kit.lbl("", 15, "num", "hd_text")
	_emorale_num.size = Vector2(80, 20)
	_emorale_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add(_emorale_num, Vector2(ex + mw - 80, 3))
	_emorale_bar = W.Bar.new()
	_emorale_bar.name = "EnemyMoraleBar"
	_emorale_bar.size = Vector2(mw, 11)
	_emorale_bar.fill_key = "bthud_emorale"
	_emorale_bar.hi_key = "bthud_emorale_hi"
	_emorale_bar.loss_key = "bthud_emorale_loss"
	_add(_emorale_bar, Vector2(ex, 25))
	_emorale_after = Kit.lbl("", 11, "sans", "hd_text_2")
	_emorale_after.size = Vector2(mw, 16)
	_add(_emorale_after, Vector2(ex, 38))
	# 右边：撤销 战报 图例 撤退，金色交火
	var row := Kit.hbox(6, "TopButtons")
	_add(row, Vector2(ex + mw + 14, 14))
	_btn_undo = Kit.small_button(Ui.text("btn_undo"), "BtnUndo", "secondary", 14, Vector2(9, 3), 30)
	_btn_undo.pressed.connect(func() -> void: _send("undo", {}))
	row.add_child(_btn_undo)
	# 战报、图例和撤销一样是有框的按钮（看得出能点）；只有撤退是红的
	_btn_log = Kit.small_button(Ui.text("btn_log"), "BtnLog", "secondary", 14, Vector2(9, 3), 30)
	_btn_log.pressed.connect(_toggle_log)
	row.add_child(_btn_log)
	_btn_legend = Kit.small_button(Ui.text("btn_legend"), "BtnLegend", "secondary", 14, Vector2(9, 3), 30)
	_btn_legend.pressed.connect(_toggle_legend)
	row.add_child(_btn_legend)
	_btn_retreat = Kit.small_button(Ui.text("btn_retreat"), "BtnRetreat", "danger", 14, Vector2(9, 3), 30)
	_btn_retreat.pressed.connect(_on_retreat)
	row.add_child(_btn_retreat)
	_btn_fight = Kit.button(Ui.text("btn_fight"), "BtnFight", "primary", 26)
	_btn_fight.size = Vector2(150, 56)
	_btn_fight.add_theme_font_override(&"font", HdTheme.font("title", 6))
	_btn_fight.pressed.connect(_on_fight)
	_add(_btn_fight, Vector2(SCREEN.x - EDGE - 150, 6))
	# 预演说这一回合交火后会战败 / 有人倒下：交火按钮下面常驻一行红字
	_warn_box = Kit.glass("glass_soft", "FightWarnBox")
	_warn_box.add_theme_stylebox_override(&"panel", Kit.flat("bthud_warn_bg", 0.94, 6, "hd_enemy_hi", 0.7, 1, Vector2(10, 3)))
	_warn_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_hud_warn = Kit.lbl("", 13, "sans_bold", "hd_text")
	_hud_warn.name = "FightWarning"
	_warn_box.add_child(_hud_warn)
	_warn_box.visible = false
	add_child(_warn_box)
	# 顶栏下方的提示行（当前操作；有操作时带「取消」）
	_status_box = Kit.glass("glass_soft", "StatusBox")
	_status_box.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 0.72, 15, "hd_gold", 0.35, 1, Vector2(16, 3)))
	_status_box.mouse_filter = Control.MOUSE_FILTER_PASS
	var sh := Kit.hbox(10)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_box.add_child(sh)
	_status_lbl = Kit.lbl("", 14, "sans", "hd_text_2")
	_status_lbl.name = "Status"
	_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh.add_child(_status_lbl)
	_btn_cancel = Kit.small_button(Ui.text("btn_cancel"), "BtnCancel", "ghost", 13, Vector2(10, 1), 24)
	_btn_cancel.pressed.connect(_cancel_mode)
	sh.add_child(_btn_cancel)
	add_child(_status_box)


## 右侧情报栏：来敌、羁绊、战报竖排（战报占满剩下的高度）；顶上一个「收起情报」
func _build_column() -> void:
	_btn_col = Kit.small_button(Ui.text("btn_intel_hide"), "BtnIntel", "secondary", 12, Vector2(10, 0), 24)
	_btn_col.pressed.connect(_toggle_column)
	add_child(_btn_col)
	var col := VBoxContainer.new()
	col.name = "IntelColumn"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 8)
	col.position = Vector2(SCREEN.x - EDGE - COL_W, COL_Y + 26)
	col.size = Vector2(COL_W, COL_BOTTOM - COL_Y - 26)
	add_child(col)
	_col = col
	_waves_card = _section("WavesCard")
	col.add_child(_waves_card)
	var wv := Kit.vbox(5)
	_waves_card.add_child(wv)
	_waves_title = Kit.lbl("", 14, "title", "hd_gold_hi")
	wv.add_child(_waves_title)
	_waves_scroll = ScrollContainer.new()
	_waves_scroll.name = "WavesScroll"
	_waves_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_waves_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	wv.add_child(_waves_scroll)
	_waves_box = Kit.vbox(3, "Waves")
	_waves_box.custom_minimum_size = Vector2(COL_W - 30, 0)
	_waves_scroll.add_child(_waves_box)
	_bonds_card = _section("BondsCard")
	col.add_child(_bonds_card)
	_bonds_box = Kit.vbox(4, "Bonds")
	_bonds_card.add_child(_bonds_box)
	_log_card = _section("LogCard")
	_log_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_log_card)
	var lv := Kit.vbox(4)
	_log_card.add_child(lv)
	var lh := Kit.hbox(4)
	lv.add_child(lh)
	var lt := Kit.lbl(Ui.text("log_title_short"), 14, "title", "hd_gold_hi")
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(lt)
	_log_more = Kit.small_button(Ui.text("log_more"), "BtnLogMore", "ghost", 12, Vector2(8, 0), 22)
	_log_more.pressed.connect(_toggle_log)
	lh.add_child(_log_more)
	# 战报：上一轮交火加本回合指挥阶段的全部内容，放不下就滚动、停在最后一行；「全部」展开整份日志
	# 滚动框的高度取整行（放在一块占满剩余高度的底板里，按行高往下取整），停在最后一行时最上面那行也是整行
	_log_clip = Control.new()
	_log_clip.name = "LogClip"
	_log_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_clip.mouse_filter = Control.MOUSE_FILTER_PASS
	lv.add_child(_log_clip)
	_log_scroll = ScrollContainer.new()
	_log_scroll.name = "LogScroll"
	_log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_log_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	_log_clip.add_child(_log_scroll)
	_log_lbl = Kit.wrap("", COL_W - 34, 12, "sans", "hd_text_2")
	_log_lbl.name = "Log"
	_log_lbl.add_theme_constant_override(&"line_spacing", LOG_SPACING)
	_log_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_log_scroll.add_child(_log_lbl)
	_log_clip.resized.connect(_fit_log_scroll)
	_log_lbl.resized.connect(_fit_log_scroll)
	# 内容变长（滚动范围变了）就停到最后一行；玩家自己往上滚不受影响
	_log_scroll.get_v_scroll_bar().changed.connect(_scroll_log_end)


func _section(node_name: String) -> PanelContainer:
	var p := Kit.glass("glass", node_name)
	var sb := HdTheme.panel_box("glass")
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	p.add_theme_stylebox_override(&"panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


## 底部：军令点、在场人数、部署牌（右），军令牌和换牌（左）
func _build_bottom() -> void:
	_bar_row = Control.new()
	_bar_row.name = "DeployBar"
	_bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_row.size = SCREEN
	add_child(_bar_row)
	_cp_plate = CpPlate.new()
	_cp_plate.name = "CpPlate"
	_cp_plate.size = Vector2(CP_W, 52)
	_add(_cp_plate, Vector2(SCREEN.x - EDGE - CP_W, STRIP_Y - 66))
	_add(Kit.lbl(Ui.text("hud_cp_title"), 12, "sans_bold", "hd_text_2"), Vector2(14, 6), _cp_plate)
	_hud_cp = Kit.lbl("", 30, "num", "hd_gold_hi")
	_hud_cp.name = "Cp"
	_hud_cp.size = Vector2(60, 34)
	_hud_cp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add(_hud_cp, Vector2(70, 2), _cp_plate)
	_hud_cp_cap = Kit.lbl("", 14, "num", "hd_text_3")
	_add(_hud_cp_cap, Vector2(132, 15), _cp_plate)
	_hud_cp_next = Kit.lbl("", 12, "sans_bold", "hd_good")
	_add(_hud_cp_next, Vector2(14, 22), _cp_plate)
	_cp_bar = W.Bar.new()
	_cp_bar.fill_key = "hd_gold"
	_cp_bar.hi_key = "hd_gold_hi"
	_cp_bar.size = Vector2(CP_W - 24, 7)
	_add(_cp_bar, Vector2(12, 40), _cp_plate)
	_field_chip = Kit.glass("glass_soft", "FieldChip")
	_field_chip.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 0.78, 13, "hd_gold", 0.4, 1, Vector2(12, 3)))
	_field_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_field = Kit.lbl("", 13, "sans", "hd_text")
	_field_chip.add_child(_hud_field)
	add_child(_field_chip)
	_hand_head = Kit.hbox(10, "HandHead")
	_add(_hand_head, Vector2(EDGE + 2, HAND_Y - 36))
	_hand_head.add_child(Kit.lbl(Ui.text("hand_head"), 16, "title", "hd_gold_hi"))
	_hand_count = Kit.lbl("", 12, "sans", "hd_text_2")
	_hand_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hand_head.add_child(_hand_count)
	_btn_redraw = Kit.small_button(Ui.text("btn_redraw"), "BtnRedraw", "secondary", 13, Vector2(10, 1), 26)
	_btn_redraw.pressed.connect(_on_redraw)
	_hand_head.add_child(_btn_redraw)
	_hand_row = Control.new()
	_hand_row.name = "Hand"
	_hand_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_row.size = SCREEN
	add_child(_hand_row)


## 左侧情报栏（悬停 / 选中时出现；挡住那一格时换到右边）
func _build_info() -> void:
	_info_panel = Kit.glass("glass_strong", "InfoPanel")
	var sb := HdTheme.panel_box("glass_strong")
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_info_panel.add_theme_stylebox_override(&"panel", sb)
	_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_panel.position = Vector2(EDGE, INFO_Y)
	_info_panel.visible = false
	add_child(_info_panel)
	_info_box = Kit.vbox(6, "Info")
	_info_box.custom_minimum_size = Vector2(INFO_W - 28, 0)
	_info_panel.add_child(_info_box)


func _build_legend() -> void:
	_legend_panel = Kit.glass("glass_strong", "LegendPanel")
	_legend_panel.visible = false
	add_child(_legend_panel)
	_legend_box = Kit.vbox(5, "Legend")
	_legend_box.custom_minimum_size = Vector2(300, 0)
	_legend_panel.add_child(_legend_box)


func _build_log_full() -> void:
	_log_full = _modal_layer("LogFull")
	_log_full.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_toggle_log())
	var box := Kit.glass("glass_strong", "LogFullBox")
	box.custom_minimum_size = Vector2(760, 0)
	_log_full.add_child(box)
	var lf := Kit.vbox(10)
	box.add_child(lf)
	var head := Kit.hbox(8)
	lf.add_child(head)
	var t := Kit.lbl(Ui.text("log_full_title"), 20, "title", "hd_gold_hi")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Kit.small_button(Ui.text("log_less"), "BtnLogClose", "ghost", 14, Vector2(12, 2), 28)
	close.pressed.connect(_toggle_log)
	head.add_child(close)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(0, 8)
	lf.add_child(rule)
	var lfs := ScrollContainer.new()
	lfs.name = "LogFullScroll"
	lfs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lfs.custom_minimum_size = Vector2(712, 400)
	lf.add_child(lfs)
	_log_full_lbl = Kit.wrap("", 696, 14, "sans", "hd_text")
	_log_full_lbl.name = "LogFullText"
	_log_full_lbl.add_theme_constant_override(&"line_spacing", 3)
	lfs.add_child(_log_full_lbl)
	box.reset_size()
	box.position = (SCREEN - box.get_combined_minimum_size()) * 0.5
	_log_full.visible = false


## 满屏压暗的一层（弹窗、战报全文用；挡住下面的点击）
func _modal_layer(node_name: String) -> Control:
	var layer := ColorRect.new()
	layer.name = node_name
	layer.color = Kit.col("bthud_shade")
	layer.size = SCREEN
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(layer)
	return layer


## 确认交火、确认撤退、打完的横幅
func _build_modals() -> void:
	_fight_box = _modal_layer("FightConfirm")
	var fb := _dialog(_fight_box, Ui.text("fight_title"), "hd_enemy_hi")
	_fight_lbl = Kit.wrap("", 470, 17, "serif", "hd_text")
	_fight_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fb.add_child(_fight_lbl)
	var frow := Kit.hbox(18)
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	fb.add_child(frow)
	var fno := Kit.button(Ui.text("fight_no"), "BtnFightNo", "secondary", 17)
	fno.custom_minimum_size = Vector2(150, 44)
	fno.pressed.connect(_cancel_mode)
	frow.add_child(fno)
	var fyes := Kit.button(Ui.text("fight_yes"), "BtnFightYes", "danger", 17)
	fyes.custom_minimum_size = Vector2(150, 44)
	fyes.pressed.connect(func() -> void: _send("fight", {}))
	frow.add_child(fyes)
	_fight_box.visible = false
	_confirm = _modal_layer("RetreatConfirm")
	var cb := _dialog(_confirm, Ui.text("retreat_title"), "hd_enemy_hi")
	var cl := Kit.wrap(Ui.text("retreat_confirm"), 470, 17, "serif", "hd_text")
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cb.add_child(cl)
	var crow := Kit.hbox(18)
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	cb.add_child(crow)
	var no := Kit.button(Ui.text("retreat_no"), "BtnRetreatNo", "secondary", 17)
	no.custom_minimum_size = Vector2(150, 44)
	no.pressed.connect(_cancel_mode)
	crow.add_child(no)
	var yes := Kit.button(Ui.text("retreat_yes"), "BtnRetreatYes", "danger", 17)
	yes.custom_minimum_size = Vector2(150, 44)
	yes.pressed.connect(_on_retreat_yes)
	crow.add_child(yes)
	_confirm.visible = false
	_banner = _modal_layer("OverBanner")
	_banner.color = Kit.col("bthud_shade_soft")
	_banner.visible = false


## 弹窗：居中的玻璃框，标题、金线，返回放正文和按钮的竖排
func _dialog(layer: Control, title: String, title_key: String) -> VBoxContainer:
	var box := Kit.glass("glass_strong", layer.name + "Box")
	var sb := HdTheme.panel_box("glass_strong")
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	box.add_theme_stylebox_override(&"panel", sb)
	layer.add_child(box)
	var v := Kit.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(v)
	var t := Kit.lbl(title, 24, "title", title_key)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(0, 8)
	v.add_child(rule)
	return v


func _center_dialog(layer: Control) -> void:
	var box := layer.get_child(0) as Control
	if box == null:
		return
	box.reset_size()
	var s := box.get_combined_minimum_size()
	box.size = s
	box.position = ((SCREEN - s) * 0.5 + Vector2(0, -30)).round()


# ================================================================ 刷新

func _ask() -> Dictionary:
	return engine.query(&"campaign.battle2") if engine != null else {}


func _render(force: bool) -> void:
	_q = _ask()
	var v: Dictionary = _q.get("view", {})
	if v.is_empty() or not bool(v.get("ok", false)):
		if not _v.is_empty():
			_close({})
		return
	var sig := JSON.stringify(v)
	if sig == _sig and not force:
		return
	_sig = sig
	_v_prev = _v
	_v = v
	_preview = {}
	_preview_sig = ""
	if str(_v.get("phase", "")) == "over":
		_mode = ""
		_act_unit = ""
	_drop_stale_selection()
	# 每次状态变了都算一遍本回合预演：格子上标出会倒下的人，顶栏写交火后的军心和警告
	var pv := _preview_now() if str(_v.get("phase", "")) == "command" else {}
	var doomed := {}
	for uid in pv.get("fallen", []):
		doomed[str(uid)] = true
	_board.doomed = doomed
	_fight_risk = _risk_text(pv)
	_board.set_view(_v)
	_render_hud()
	if _changed("bonds", _v.get("bonds", [])):
		_render_bonds()
	if _changed("legend", _v.get("grid", {}).get("cells", []).map(func(c: Dictionary) -> String: return str(c["terrain"]))):
		_render_legend()
	if _changed("waves", [_v.get("waves", []), _v.get("turn", 0)]):
		_render_waves()
	_render_bar()
	_render_hand()
	_render_log()
	_render_mode()
	_render_info()


func _changed(section: String, data) -> bool:
	var sig := JSON.stringify(data)
	if str(_secs.get(section, "")) == sig:
		return false
	_secs[section] = sig
	return true


func _drop_stale_selection() -> void:
	if _sel_unit != "" and _mode in ["deploy", "facing"]:
		var b := _bar_entry(_sel_unit)
		if b.is_empty() or not bool(b.get("deployable", false)):
			_mode = ""
			_sel_unit = ""
	if _act_unit != "" and _unit(_act_unit).is_empty():
		_act_unit = ""


## 顶栏和战报这一刻该照哪份视图画：回放还在放就是交火前那份
func _hud_v() -> Dictionary:
	if _board != null and _board.is_playing() and not _v_prev.is_empty():
		return _v_prev
	return _v


func _on_playback_done() -> void:
	if _closed or _v.is_empty():
		return
	_render_hud()
	_render_log()


func _render_hud() -> void:
	var hv := _hud_v()
	var playing: bool = _board != null and _board.is_playing() and not _v_prev.is_empty()
	_hud_title.text = Ui.text("hud_title", {"battle": _v.get("name", ""), "scale": _v.get("scale_name", ""), "act": _v.get("act", 1)})
	var order: Dictionary = _v.get("order", {})
	_hud_order.text = Ui.text("hud_order", {"desc": str(order.get("desc", ""))}) if not order.is_empty() else ""
	if order.has("progress"):
		var progress: Dictionary = order["progress"]
		if bool(progress.get("failed", false)):
			_hud_order.text += Ui.text("order_failed")
		elif str(order.get("type", "")) == "extract":
			_hud_order.text += Ui.text("order_extract_progress", {"n": mini(int(progress.get("count", 0)), int(order.get("turns", 0))), "need": order.get("turns", 0)})
		if bool(progress.get("escaped", false)):
			_hud_order.text += Ui.text("order_escaped")
	_hud_order.tooltip_text = _hud_order.text
	_hud_order.mouse_filter = Control.MOUSE_FILTER_PASS if _hud_order.text != "" else Control.MOUSE_FILTER_IGNORE
	_hud_turn.text = Ui.text("hud_turn", {"turn": hv.get("turn", 0), "limit": hv.get("turn_limit", 0)})
	_pips.set_turn(int(hv.get("turn", 0)), int(hv.get("turn_limit", 1)))
	var cp := int(hv.get("cp", 0))
	var cap := int(hv.get("cp_cap", 20))
	_hud_cp.text = str(cp)
	_hud_cp_cap.text = Ui.text("hud_cp_cap", {"cap": cap})
	_hud_cp_next.text = Ui.text("hud_cp_next", {"n": hv.get("cp_next", 0)})
	_cp_bar.set_values(cp, cap)
	var m := int(hv.get("morale", 0))
	var mcap := maxi(1, int(hv.get("morale_cap", 15)))
	var em := int(hv.get("enemy_morale", 0))
	var emax := maxi(1, int(hv.get("enemy_morale_max", 1)))
	var pv: Dictionary = _preview if _preview_sig == _sig and not playing else {}
	_morale_num.text = Ui.text("hud_ratio", {"m": m, "cap": mcap})
	_emorale_num.text = Ui.text("hud_ratio", {"m": em, "cap": emax})
	if bool(pv.get("ok", false)) and str(hv.get("phase", "")) == "command":
		var ma := int(pv.get("morale", m))
		var ea := int(pv.get("enemy_morale", em))
		_morale_bar.set_values(m, mcap, ma)
		_emorale_bar.set_values(em, emax, ea)
		_morale_after.text = Ui.text("hud_after", {"n": ma})
		_emorale_after.text = Ui.text("hud_after", {"n": ea})
		_morale_after.add_theme_color_override(&"font_color", Kit.col("hd_enemy_hi" if ma <= 0 else ("bthud_loss" if ma < m else "hd_text_2")))
		_emorale_after.add_theme_color_override(&"font_color", Kit.col("hd_good" if ea < em else "hd_text_2"))
	else:
		_morale_bar.set_values(m, mcap)
		_emorale_bar.set_values(em, emax)
		_morale_after.text = ""
		_emorale_after.text = ""
	_hud_field.text = Ui.text("hud_field", {"n": _v.get("field_count", 0), "cap": _v.get("field_cap", 0),
		"c": _v.get("companion_count", 0), "ccap": _v.get("companion_cap", 0)})
	_field_chip.reset_size()
	var fs := _field_chip.get_combined_minimum_size()
	_field_chip.size = fs
	_field_chip.position = Vector2(_cp_plate.position.x - fs.x - 8, _cp_plate.position.y + _cp_plate.size.y - fs.y)
	_hud_warn.text = _fight_risk
	_hud_warn.tooltip_text = _fight_risk
	_warn_box.visible = _fight_risk != "" and not playing
	if _warn_box.visible:
		_warn_box.reset_size()
		var ws := _warn_box.get_combined_minimum_size()
		_warn_box.size = ws
		_warn_box.position = Vector2(SCREEN.x - EDGE - ws.x, TOP_H + 8)


## 预演的风险：这一回合交火后会战败，或者伙伴 / 主角会倒下（部队溃散不算）；没有风险回空串
func _risk_text(pv: Dictionary) -> String:
	if not bool(pv.get("ok", false)):
		return ""
	if str(pv.get("outcome", "")) == "defeat":
		return Ui.text("risk_defeat", {"m": pv.get("morale", 0)})
	var names: Array = []
	for uid in pv.get("fallen", []):
		var u := _unit(str(uid))
		if not u.is_empty() and str(u.get("kind", "")) in ["companion", "hero"]:
			names.append(str(u["name"]))
	if names.is_empty():
		return ""
	return Ui.text("risk_fall", {"names": Ui.join(names)})


## 羁绊：点亮的一行一条（名字、人数、档位，金色）；差一点的（已有人）暗色一行；一个人都没有的收进一枚「其余 n 条」（悬停看全部）
func _render_bonds() -> void:
	Kit.clear(_bonds_box)
	_bonds_box.add_child(Kit.lbl(Ui.text("bonds_title"), 14, "title", "hd_gold_hi"))
	var bonds: Array = _v.get("bonds", [])
	if bonds.is_empty():
		_bonds_box.add_child(Kit.lbl(Ui.text("bonds_none"), 12, "sans", "hd_text_3"))
	var rest: PackedStringArray = []
	var partial: PackedStringArray = []
	var lit := 0
	for b in bonds:
		if bool(b.get("active", false)):
			lit += 1
	var squeeze := lit + _count_partial(bonds) > BONDS_ROWS
	for b in bonds:
		var active := bool(b.get("active", false))
		var nxt := int(b.get("next", 0))
		var line := Ui.text("bond_count", {"name": b["name"], "count": b["count"], "next": nxt}) if nxt > 0 \
			else Ui.text("bond_count_max", {"name": b["name"], "count": b["count"]})
		if not active and int(b.get("count", 0)) <= 0:
			rest.append(line + Ui.text("list_sep2") + str(b.get("desc", "")))
			continue
		# 羁绊多的时候（亮着的加差人的超过 BONDS_ROWS 条）只列亮着的，差人的收进一个小签（悬停看全）
		if not active and squeeze:
			partial.append(line + Ui.text("list_sep2") + str(b.get("desc", "")))
			continue
		var row := Kit.hbox(6)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = str(b.get("desc", ""))
		row.add_child(Kit.lbl(line, 13, "sans_bold" if active else "sans", "hd_gold_hi" if active else "hd_text_2"))
		if active:
			row.add_child(Kit.pill(Ui.text("bond_tier", {"n": b["tier"]}), "hd_gold", "hd_ink", 11))
		_bonds_box.add_child(row)
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override(&"h_separation", 4)
	chips.add_theme_constant_override(&"v_separation", 4)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not partial.is_empty():
		var pc := Kit.pill(Ui.text("bonds_partial", {"n": partial.size()}), "hd_navy_3", "hd_text_2", 11, 0.8, "hd_gold")
		pc.name = "BondsPartial"
		pc.mouse_filter = Control.MOUSE_FILTER_PASS
		pc.tooltip_text = "\n".join(partial)
		chips.add_child(pc)
	if not rest.is_empty():
		var chip := Kit.pill(Ui.text("bonds_rest", {"n": rest.size()}), "hd_ink", "hd_text_3", 11, 0.6, "hd_gold")
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.tooltip_text = "\n".join(rest)
		chips.add_child(chip)
	if chips.get_child_count() > 0:
		_bonds_box.add_child(chips)
	else:
		chips.free()
	_layout_column()


## 差人的羁绊（有人、还没亮）有几条
func _count_partial(bonds: Array) -> int:
	var n := 0
	for b in bonds:
		if not bool(b.get("active", false)) and int(b.get("count", 0)) > 0:
			n += 1
	return n


## 图例：这张图上有的地形各一行（地块贴图 + 名字 + 作用），再加军心档位和格子上的记号
func _render_legend() -> void:
	Kit.clear(_legend_box)
	var head := Kit.hbox(8)
	_legend_box.add_child(head)
	var t := Kit.lbl(Ui.text("legend_title"), 18, "title", "hd_gold_hi")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Kit.small_button(Ui.text("log_less"), "BtnLegendClose", "ghost", 12, Vector2(8, 0), 22)
	close.pressed.connect(_toggle_legend)
	head.add_child(close)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(0, 6)
	_legend_box.add_child(rule)
	var seen: Array = []
	for cd in _v.get("grid", {}).get("cells", []):
		var tr := str(cd["terrain"])
		if tr in seen:
			continue
		seen.append(tr)
	for tr in Ui.data().get("legend_order", []):
		if not tr in seen:
			continue
		var row := Kit.hbox(8)
		var sw := Swatch.new()
		sw.terrain = str(tr)
		sw.custom_minimum_size = Vector2(22, 22)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sw)
		row.add_child(Kit.wrap(Ui.pick("legend", str(tr)), 266, 13, "sans", "hd_text"))
		_legend_box.add_child(row)
	for key in ["legend_morale", "legend_marks"]:
		_legend_box.add_child(Kit.wrap(Ui.text(key), 300, 12, "sans", "hd_text_2"))
	_place_legend()


func _place_legend() -> void:
	_legend_panel.reset_size()
	var s := _legend_panel.get_combined_minimum_size()
	_legend_panel.size = s
	_legend_panel.position = Vector2(clampf(_btn_legend.global_position.x + _btn_legend.size.x - s.x, EDGE, SCREEN.x - EDGE - s.x),
		TOP_H + 8)


## 来敌：之后几回合从哪个红门来谁（标签：猎官、重装……）
func _render_waves() -> void:
	Kit.clear(_waves_box)
	var t := int(_v.get("turn", 0))
	var known: Array = []
	var later := false
	for w in _v.get("waves", []):
		if bool(w.get("known", false)):
			known.append(w)
		else:
			later = true
	var horizon := 0
	for w in known:
		horizon = maxi(horizon, int(w["turn"]) - t)
	_waves_title.text = Ui.text("waves_title", {"n": maxi(2, horizon)})
	if known.is_empty():
		_waves_box.add_child(Kit.wrap(Ui.text("waves_none"), COL_W - 34, 12, "sans", "hd_text_3"))
	for w in known:
		var wr := Kit.hbox(6)
		var turn_pill := Kit.pill(Ui.text("waves_turn_short", {"turn": w["turn"]}), "bthud_wave", "hd_text", 11)
		wr.add_child(turn_pill)
		wr.add_child(Kit.lbl(Ui.text("waves_gate", {"gate": w["label"]}), 12, "sans_bold", "hd_enemy_hi"))
		_waves_box.add_child(wr)
		for d in w.get("detail", []):
			var row := Kit.hbox(4)
			row.add_child(Kit.lbl(str(d["name"]), 12, "sans", "hd_text"))
			for tg in d.get("battle_tags", []):
				var tag_text := Ui.pick("tag", str(tg))
				if tag_text != "":
					row.add_child(Kit.pill(tag_text, "bthud_tag_hunter" if str(tg) == "hunter" else "hd_gold_deep", "hd_text", 10))
			_waves_box.add_child(row)
	if later:
		_waves_box.add_child(Kit.lbl(Ui.text("waves_more"), 11, "sans", "hd_text_3"))
	_layout_column()


## 右栏三块竖排：来敌（放不下就滚动，给战报留至少 LOG_MIN 高）、羁绊、战报（占满剩下的）
func _layout_column() -> void:
	if _col == null:
		return
	var info_right := _info_panel != null and _info_panel.visible and _info_panel.position.x > SCREEN.x * 0.5
	_col.visible = _col_open and not info_right
	# 情报栏开在右边时「收起情报」也让出来（不从情报栏右上角透出来）
	_btn_col.visible = not info_right
	_btn_col.text = Ui.text("btn_intel_hide" if _col_open else "btn_intel")
	_btn_col.reset_size()
	_btn_col.position = Vector2(SCREEN.x - EDGE - _btn_col.size.x, COL_Y - 2)
	if not _col_open:
		return
	# 来敌最要紧：先给它（按内容，最多 WAVES_MAX 高，至少 WAVES_ROWS 行），羁绊是精简过的（亮着的几条 + 两个小签），
	# 战报占满剩下的（至少 LOG_MIN）。来敌的滚动框按整行截（没有半截的字）
	_bonds_box.reset_size()
	var bonds_h := _bonds_box.get_combined_minimum_size().y + 18.0
	_waves_box.reset_size()
	var content := _waves_box.get_combined_minimum_size().y
	var room := _col.size.y - bonds_h - LOG_MIN - 16.0 - 46.0
	var want := minf(content, WAVES_MAX)
	want = minf(maxf(want, minf(content, _rows_height(WAVES_ROWS))), maxf(room, _rows_height(WAVES_ROWS)))
	_waves_scroll.custom_minimum_size = Vector2(COL_W - 24, maxf(24.0, _whole_rows(want)))
	_log_card.custom_minimum_size = Vector2(0, LOG_MIN)
	_fit_log_scroll.call_deferred()


## 来敌框里前 n 行有多高
func _rows_height(n: int) -> float:
	var h := 0.0
	var i := 0
	var sep := float(_waves_box.get_theme_constant(&"separation"))
	for c in _waves_box.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		if i >= n:
			break
		h += (c as Control).get_combined_minimum_size().y + (sep if i > 0 else 0.0)
		i += 1
	return h


## 不超过 h 的整行高度（来敌一行一行往下数，放得下几行就截在那一行底下）
func _whole_rows(h: float) -> float:
	var used := 0.0
	var i := 0
	var sep := float(_waves_box.get_theme_constant(&"separation"))
	for c in _waves_box.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		var add := (c as Control).get_combined_minimum_size().y + (sep if i > 0 else 0.0)
		if used + add > h + 0.5:
			break
		used += add
		i += 1
	return used if i > 0 else h


func _toggle_column() -> void:
	_col_open = not _col_open
	_layout_column()
	_board.set_safe_area(_safe_rect())
	_render_mode()


## 部署栏：每个单位一张牌，开战时搭一次（单位名单变了才重搭），之后只改字、颜色和按钮状态
func _render_bar() -> void:
	if not _changed("bar", [_v.get("deploy_bar", []), _sel_unit if _mode in ["deploy", "facing"] else ""]):
		return
	var bar: Array = _v.get("deploy_bar", [])
	var ids: Array = bar.map(func(b: Dictionary) -> String: return str(b["uid"]))
	if ids != _bar_ids:
		Kit.clear(_bar_row)
		_bar_cards = {}
		_bar_ids = ids
		for b in bar:
			_bar_row.add_child(_deploy_card(b))
	for b in bar:
		_update_card(b)
	_layout_bottom()


func _deploy_card(b: Dictionary) -> Control:
	var uid := str(b["uid"])
	var bname := str(b["name"])
	var sep := Ui.text("name_sep")
	var display := bname.get_slice(sep, 0) if bname.contains(sep) else bname
	var tag := bname.get_slice(sep, 1) if bname.contains(sep) else ""
	var tag_key := "bthud_tag_troop"
	if bool(b.get("fated", false)):
		tag = Ui.text("lineup_fated")
		tag_key = "bthud_tag_fated"
	elif bool(b.get("scarred", false)):
		tag = Ui.text("lineup_scar")
		tag_key = "bthud_tag_scar"
	var card := W.DeployCard.new()
	card.name = "Card_" + uid
	var aid := Kit.art_id(uid, str(b["kind"]), str(b["cls"]))
	card.setup(b, aid, aid, Ui.cls_char(str(b["cls"])), display, tag, tag_key, Ui.text("act_dispatch") if uid == Rules.HERO else "")
	card.btn.pressed.connect(_on_deploy_card.bind(uid))
	card.btn.tooltip_text = str(b.get("cls_name", ""))
	if card.dispatch != null:
		card.dispatch.pressed.connect(func() -> void: _send("skill", {"unit": uid}))
	_bar_cards[uid] = card
	return card


func _update_card(b: Dictionary) -> void:
	var uid := str(b["uid"])
	var card = _bar_cards.get(uid, null)
	if card == null:
		return
	var status := str(b.get("status", "bar"))
	var deployable := bool(b.get("deployable", false))
	var dispatch := bool(b.get("can_dispatch", false))
	var on := deployable or status == "ok" or dispatch
	var picked := _sel_unit == uid and _mode in ["deploy", "facing"]
	var reason := str(b.get("reason", ""))
	var hero_off := uid == Rules.HERO and reason == "hero_disabled"
	# 溃散的部队兵力可能是负数：牌上写 0
	var sub := "" if hero_off else "%d/%d" % [maxi(0, int(b.get("hp", 0))), int(b.get("max_hp", 0))]
	var st_text := Ui.pick("unit_state", status) if status != "bar" else ""
	card.set_state(on, picked, deployable, int(b.get("cost", 0)), reason == "no_cp", sub, st_text,
		str(STATE_KEYS.get(status, "bthud_state_out")), int(b.get("cooldown", 0)), Ui.text("bar_cooldown_word"),
		maxi(0, int(b.get("hp", 0))), int(b.get("max_hp", 1)), dispatch)
	var tip := str(b.get("cls_name", ""))
	if not deployable and reason not in ["", "not_in_bar"]:
		tip = Ui.err(reason)
	card.btn.tooltip_text = tip


## 底部排版：军令牌从左往右，部署牌靠右；放不下时部署牌收窄（最窄 64）
func _layout_bottom() -> void:
	var n := _bar_ids.size()
	var hand_n := (_v.get("hand", []) as Array).size()
	var hand_right := EDGE + maxf(hand_n * (HAND_W + HAND_GAP), 260.0)
	var room := SCREEN.x - EDGE - hand_right - 16.0
	var w := CARD_W
	if n > 0:
		w = clampf(floorf((room - (n - 1) * CARD_GAP) / n), CARD_MIN_W, CARD_W)
	var x := SCREEN.x - EDGE - n * w - maxf(n - 1, 0) * CARD_GAP
	for uid in _bar_ids:
		var card = _bar_cards.get(uid, null)
		if card != null:
			card.place(x, STRIP_Y, w)
		x += w + CARD_GAP


func _render_hand() -> void:
	if not _changed("hand", [_v.get("hand", []), _v.get("deck_count", 0), _v.get("discard_count", 0), _mode, _target.get("card", -1)]):
		return
	Kit.clear(_hand_row)
	_hand_count.text = Ui.text("hand_count", {"deck": _v.get("deck_count", 0), "discard": _v.get("discard_count", 0)})
	var x := EDGE
	for h in _v.get("hand", []):
		var idx := int(h["index"])
		var playable := bool(h.get("playable", false))
		var picked := _mode == "redraw" or (_mode == "target" and int(_target.get("card", -1)) == idx)
		var note := Ui.pick("card_note", str(h["id"]))
		var card := W.CmdCard.new()
		card.name = "Order_%d" % idx
		_hand_row.add_child(card)
		# 打不出的牌写原因：扣在方阵（蓝签）、军令点不够、眼下没有能用的目标（红签），悬停提示里也写
		var reason := _card_reason(h)
		card.lock_blue = bool(h.get("locked", false))
		card.setup(idx, int(h["cost"]), str(h["name"]), str(h["desc"]), reason,
			playable, picked, playable or (_mode == "redraw" and not bool(h.get("locked", false))),
			str(h["desc"]) + ("\n" + note if note != "" else "") + ("\n" + _card_reason(h, true) if reason != "" else ""))
		card.btn.pressed.connect(_on_card.bind(idx))
		card.place(x, HAND_Y)
		x += HAND_W + HAND_GAP
	_layout_bottom()


## 军令牌为什么打不出（打得出、或者不在指挥阶段时是空串）；long = 悬停提示里的整句
func _card_reason(h: Dictionary, long: bool = false) -> String:
	if bool(h.get("locked", false)):
		return Ui.text("card_locked")
	if bool(h.get("playable", false)) or str(_v.get("phase", "")) != "command":
		return ""
	if int(h.get("cost", 0)) > int(_v.get("cp", 0)):
		return Ui.text("card_no_cp_long" if long else "card_no_cp", {"cost": int(h.get("cost", 0)), "cp": int(_v.get("cp", 0))})
	return Ui.text("card_no_target_long" if long else "card_no_target")


## 战报：从最后一个「—— 第 N 回合交火 ——」起到现在（上一轮交火 + 本回合指挥阶段）；第 1 回合还没交火时从开战算起。
## 放不下就滚到最后一行；「全部」打开整份日志（视图里最近 40 行）
func _render_log() -> void:
	var lines: Array = _hud_v().get("log", [])
	var from := 0
	for i in range(lines.size()):
		if str(lines[i]).begins_with(Ui.text("log_fight_prefix")):
			from = i
	var out := PackedStringArray()
	for i in range(from, lines.size()):
		out.append(str(lines[i]))
	var txt := "\n".join(out)
	if _log_lbl.text != txt:
		_log_lbl.text = txt
	_log_full_lbl.text = "\n".join(PackedStringArray(lines.map(func(x) -> String: return str(x))))


func _scroll_log_end() -> void:
	if _log_scroll != null and is_instance_valid(_log_scroll):
		var bar := _log_scroll.get_v_scroll_bar()
		_log_scroll.scroll_vertical = int(bar.max_value - bar.page)


## 战报滚动框：宽占满底板，高按行高往下取整（行高 = 字高 + 行距，从标签实际排出来的行算）
func _fit_log_scroll() -> void:
	if _log_clip == null or not is_instance_valid(_log_clip) or not is_instance_valid(_log_scroll):
		return
	var lh := _log_line_h()
	var avail := _log_clip.size.y
	var rows := maxi(1, int(floorf((avail + LOG_SPACING) / lh)))
	var h := minf(avail, float(rows) * lh - LOG_SPACING)
	var want := Vector2(_log_clip.size.x, maxf(h, 1.0))
	if _log_scroll.size.distance_to(want) > 0.5 or _log_scroll.position != Vector2.ZERO:
		_log_scroll.position = Vector2.ZERO
		_log_scroll.size = want
	_scroll_log_end.call_deferred()


func _log_line_h() -> float:
	var n := _log_lbl.get_line_count() if _log_lbl != null else 0
	if n > 0:
		var mh := _log_lbl.get_combined_minimum_size().y
		if mh > 1.0:
			return (mh + LOG_SPACING) / float(n)
	return HdTheme.font("sans").get_height(12) + LOG_SPACING


func _toggle_log() -> void:
	_log_open = not _log_open
	_log_full.visible = _log_open
	_log_more.text = Ui.text("log_less" if _log_open else "log_more")
	if _log_open:
		var box := _log_full.get_child(0) as Control
		box.reset_size()
		box.position = ((SCREEN - box.get_combined_minimum_size()) * 0.5).round()
		# 打开时停在最新的一行（排好版以后再滚）
		var sc := _log_full.find_child("LogFullScroll", true, false) as ScrollContainer
		await get_tree().process_frame
		if sc != null and is_instance_valid(sc):
			sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func _toggle_legend() -> void:
	_legend_open = not _legend_open
	_legend_panel.visible = _legend_open
	if _legend_open:
		_place_legend()


func _render_mode() -> void:
	var live := str(_v.get("phase", "")) == "command"
	_btn_fight.disabled = not live or _mode != ""
	_btn_undo.disabled = not live or not bool(_v.get("can_undo", false))
	_btn_redraw.disabled = not live or not bool(_v.get("can_redraw", false))
	_btn_retreat.disabled = not live
	_btn_cancel.visible = _mode != "" or _act_unit != ""
	_btn_cancel.disabled = _mode == "" and _act_unit == ""
	_board.valid_cells = {}
	_board.target_cells = {}
	_board.pattern_cells = {}
	_board.selected = Vector2i(-1, -1)
	_facing.visible = false
	_popup.visible = false
	_confirm.visible = _mode == "retreat"
	if _confirm.visible:
		_center_dialog(_confirm)
	_fight_box.visible = _mode == "fight_confirm"
	if _fight_box.visible:
		_fight_lbl.text = Ui.text("fight_confirm", {"risk": _fight_risk})
		_center_dialog(_fight_box)
	var hint := Ui.text("status_ready")
	match _mode:
		"deploy":
			_board.valid_cells = _deploy_cells(_sel_unit)
			hint = Ui.text("status_deploy", {"name": _bar_entry(_sel_unit).get("name", "")})
		"facing":
			_board.selected = _sel_cell
			_show_facing()
			hint = Ui.text("status_facing", {"name": _bar_entry(_sel_unit).get("name", "")})
		"target":
			_board.target_cells = _target.get("cells", {})
			hint = Ui.text({"row": "status_target_row", "unit": "status_target_unit"}.get(str(_target.get("need", "")), "status_target_cell"))
		"redraw":
			hint = Ui.text("status_redraw")
		"fight_confirm":
			hint = _fight_risk
	if _mode == "facing" and not _charge.is_empty():
		_apply_charge_marks()
	if _mode == "" and _act_unit != "":
		var u := _unit(_act_unit)
		_board.selected = Vector2i(int(u["col"]), int(u["row"]))
		for pc in u.get("pattern", []):
			_board.pattern_cells[Vector2i(int(pc[0]), int(pc[1]))] = true
		_show_actions(u)
	if not live:
		hint = Ui.text("status_over")
	_status_lbl.text = _status if _status != "" else hint
	_status_lbl.add_theme_color_override(&"font_color", Kit.col("hd_enemy_hi" if _status != "" else ("hd_text" if _mode != "" else "hd_text_2")))
	_status_box.reset_size()
	var ss := _status_box.get_combined_minimum_size()
	_status_box.size = ss
	_status_box.position = Vector2(round(SCREEN.x * 0.5 - ss.x * 0.5), TOP_H + 8)
	_status_box.visible = live or _status != ""
	_show_banner(not live)
	_board.queue_redraw()


func _show_banner(on: bool) -> void:
	_banner.visible = on
	if not on:
		return
	Kit.clear(_banner)
	var outcome := str(_v.get("outcome", ""))
	var win := outcome == "victory"
	var box := Kit.vbox(12, "OverBox")
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(box)
	var kicker := Kit.lbl(Ui.text("over_kicker"), 15, "sans_bold", "hd_text_2")
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(kicker)
	var rule := W.Rule.new()
	rule.custom_minimum_size = Vector2(420, 10)
	box.add_child(rule)
	var big := Kit.lbl(Ui.text("over_" + outcome) if outcome != "" else "", 72, "title", "hd_gold_hi" if win else "hd_enemy_hi")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.add_theme_font_override(&"font", HdTheme.font("title", 18))
	Kit.outline(big, 8, "hd_ink", 0.7)
	box.add_child(big)
	var res: Dictionary = _q.get("result", {})
	var kind_text := Ui.pick("kind", str(res.get("victory_kind", "")))
	if kind_text != "":
		var k := Kit.lbl(kind_text, 20, "serif", "hd_text")
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(k)
	var rule2 := W.Rule.new()
	rule2.custom_minimum_size = Vector2(420, 10)
	box.add_child(rule2)
	var go := Kit.button(Ui.text("btn_result"), "BtnResult", "primary", 20)
	go.custom_minimum_size = Vector2(220, 50)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(_on_result)
	box.add_child(go)
	box.reset_size()
	var s := box.get_combined_minimum_size()
	box.size = s
	box.position = ((SCREEN - s) * 0.5 + Vector2(0, -20)).round()
	var band := Band.new()
	band.size = Vector2(SCREEN.x, s.y + 90)
	band.position = Vector2(0, box.position.y - 45)
	band.tone = "bthud_victory" if win else ("bthud_defeat" if outcome == "defeat" else "bthud_retreat")
	_banner.add_child(band)
	_banner.move_child(band, 0)


# ================================================================ 悬停与情报

func _on_hover(c: int, r: int) -> void:
	_hover = Vector2i(c, r)
	_render_info()


## 离开格子：血条上的预演去掉，情报栏回到选中的单位（没选中就收起）
func _on_leave(c: int, r: int) -> void:
	if _hover == Vector2i(c, r):
		_hover = Vector2i(-1, -1)
		_board.ghost_hp = {}
		_board.queue_redraw()
		if _info_key != "charge":
			_render_info()


func _preview_now() -> Dictionary:
	if _preview_sig != _sig:
		_preview = engine.query(&"campaign.battle_preview") if engine != null else {}
		_preview_sig = _sig
	return _preview


## 情报栏看哪一格：悬停的那格；没悬停时看选中的单位
func _info_cell() -> Vector2i:
	if _hover.x >= 0:
		return _hover
	if _act_unit != "":
		var u := _unit(_act_unit)
		if not u.is_empty():
			return Vector2i(int(u["col"]), int(u["row"]))
	return Vector2i(-1, -1)


func _render_info() -> void:
	var at := _info_cell()
	var key := "%d|%d|%s" % [at.x, at.y, _sig]
	if key == _info_key:
		return
	_info_key = key
	Kit.clear(_info_box)
	var ghost := {}
	var cell := _cell(at.x, at.y)
	var u := _unit_at(at.x, at.y) if not cell.is_empty() else {}
	var foes: Array = _board.enemies_at(at.x, at.y) if not cell.is_empty() else []
	if cell.is_empty() or str(_v.get("phase", "")) != "command" or (u.is_empty() and foes.is_empty()):
		_info_panel.visible = false
		_board.ghost_hp = ghost
		_layout_column()
		return
	var pv := _preview_now()
	if not u.is_empty():
		_info_unit(u, pv, ghost)
	for e in foes:
		_info_enemy(e, pv, ghost, u.is_empty() and foes.size() == 1)
	var foot := Kit.hbox(6)
	foot.add_child(Kit.pill(Ui.text("info_cell", {"label": cell.get("label", ""), "terrain": cell.get("name", "")}), "hd_navy_3", "hd_text_2", 11))
	_info_box.add_child(foot)
	if bool(pv.get("ok", false)):
		_info_box.add_child(Kit.wrap(Ui.text("info_preview_morale", {"m": pv.get("morale", 0), "em": pv.get("enemy_morale", 0)}),
			INFO_W - 28, 12, "sans", "hd_text_3"))
	_board.ghost_hp = ghost
	_board.queue_redraw()
	_show_info_panel(at)


## 情报栏放左边；那一格在屏幕左边、会被挡住时放右边（盖在右侧情报栏上，情报栏先收起来）
func _show_info_panel(at: Vector2i) -> void:
	_info_panel.visible = true
	_info_panel.reset_size()
	var s := _info_panel.get_combined_minimum_size()
	_info_panel.size = Vector2(INFO_W, minf(s.y, INFO_MAX_H))
	# 情报栏开在右边、盖住右侧情报栏（开着时情报栏本来就让出来）：左边是鹰旗和我方守军，不能挡。
	# 只有右侧情报栏收起、地图铺到右边、悬停的格子正好在右边时，才换到左边
	var x := SCREEN.x - EDGE - INFO_W
	if at.x >= 0 and not _col_open:
		var p: Vector2 = _board.position + _board.cell_center(at.x, at.y)
		if p.x > SCREEN.x - EDGE - INFO_W - 50.0:
			x = EDGE
	_info_panel.position = Vector2(x, INFO_Y)
	_layout_column()


func _info_head(art: String, accent: String, title: String, sub: String, title_key: String) -> void:
	var head := Kit.hbox(12)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 1.0, 6, "hd_gold", 0.7, 1, Vector2(2, 2)))
	var pic := Portrait.new()
	pic.custom_minimum_size = Vector2(72, 72)
	pic.setup(art, title, accent)
	frame.add_child(pic)
	head.add_child(frame)
	var col := Kit.vbox(2)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := Kit.wrap(title, INFO_W - 28 - 86, 19, "title", title_key)
	col.add_child(nm)
	col.add_child(Kit.wrap(sub, INFO_W - 28 - 86, 12, "sans", "hd_text_2"))
	head.add_child(col)
	_info_box.add_child(head)


func _info_unit(u: Dictionary, pv: Dictionary, ghost: Dictionary) -> void:
	var uid := str(u["uid"])
	var aid := Kit.art_id(uid, str(u["kind"]), str(u["cls"]))
	var state := Ui.pick("unit_state", str(u["state"]))
	_info_head(aid, aid, str(u["name"]), str(u["cls_name"]) + ("  " + state if str(u["state"]) != "ok" else ""),
		"bthud_name_hero" if str(u["kind"]) == "hero" else "hd_text")
	var after: Dictionary = pv.get("battle_units", {}).get(uid, {})
	var line := Ui.text("info_hp", {"hp": maxi(0, int(u["hp"])), "max": u["max_hp"]})
	var tone := "hd_text"
	var hp_after := -1
	if not after.is_empty() and str(u["state"]) == "ok":
		hp_after = int(after.get("hp", 0))
		if str(after.get("status", "ok")) != "ok":
			line += "  " + Ui.text("info_after_fall")
			tone = "hd_enemy_hi"
			ghost[uid] = 0
			hp_after = 0
		elif hp_after < int(u["hp"]):
			line += "  " + Ui.text("info_after", {"hp": hp_after})
			tone = "bthud_loss"
			ghost[uid] = hp_after
		else:
			line += "  " + Ui.text("info_after_same")
			tone = "hd_good"
	_info_box.add_child(Kit.wrap(line, INFO_W - 28, 13, "sans_bold", tone))
	var bar := W.Bar.new()
	bar.custom_minimum_size = Vector2(INFO_W - 28, 9)
	bar.set("fill_key", "bthud_hp")
	bar.set("hi_key", "bthud_hp_hi")
	bar.set_values(int(u["hp"]), int(u["max_hp"]), hp_after)
	_info_box.add_child(bar)
	_info_box.add_child(_stat_row([[Ui.text("stat_atk"), u["atk"]], [Ui.text("stat_def"), u["def"]],
		[Ui.text("stat_block"), "%d/%d" % [int(u["block_used"]), int(u["block"])]]]))
	var sk := str(u.get("skill", ""))
	if sk != "" and int(u.get("charge_need", 0)) > 0:
		var ready := bool(u.get("skill_ready", false))
		var sr := Kit.hbox(8)
		var nm := Kit.lbl(Ui.text("info_skill", {"skill": u["skill_name"]}), 14, "title", "hd_gold_hi")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sr.add_child(nm)
		sr.add_child(Kit.pill(Ui.text("info_skill_ready") if ready else Ui.text("info_skill_wait", {"charge": u["charge"], "need": u["charge_need"]}),
			"hd_gold" if ready else "hd_navy_3", "hd_ink" if ready else "hd_text", 11))
		_info_box.add_child(sr)
		var desc := str(Rules.SKILLS.get(sk, {}).get("desc", ""))
		if desc != "":
			_info_box.add_child(Kit.wrap(desc, INFO_W - 28, 12, "sans", "hd_text_2"))
	var flags: Array = []
	if bool(u.get("square", false)):
		flags.append(Ui.text("info_square"))
	if bool(u.get("scarred", false)):
		flags.append(Ui.text("lineup_scar"))
	if bool(u.get("fated", false)):
		flags.append(Ui.text("lineup_fated"))
	if not flags.is_empty():
		var fr := Kit.hbox(4)
		for f in flags:
			fr.add_child(Kit.pill(str(f), "hd_navy_3", "hd_text", 11))
		_info_box.add_child(fr)


func _stat_row(items: Array) -> Control:
	var row := Kit.hbox(6)
	for it in items:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 0.6, 5, "hd_gold", 0.3, 1, Vector2(8, 2)))
		var h := Kit.hbox(5)
		h.add_child(Kit.lbl(str(it[0]), 11, "sans", "hd_text_3"))
		h.add_child(Kit.lbl(str(it[1]), 14, "num", "hd_text"))
		chip.add_child(h)
		row.add_child(chip)
	return row


## 每个敌人：小头像、名字、兵力 → 交火后，下一行它这一回合要做什么
func _info_enemy(e: Dictionary, pv: Dictionary, ghost: Dictionary, big: bool) -> void:
	var euid := int(e["uid"])
	var ea: Dictionary = pv.get("enemies", {}).get(str(euid), {})
	var hp_after := -1
	var after_txt := ""
	var tone := "hd_text"
	if not ea.is_empty():
		if not bool(ea.get("alive", true)):
			after_txt = Ui.text("info_after_dead_short")
			tone = "hd_good"
			ghost["e%d" % euid] = 0
			hp_after = 0
		elif int(ea.get("hp", 0)) < int(e["hp"]):
			after_txt = Ui.text("after_arrow", {"n": int(ea["hp"])})
			ghost["e%d" % euid] = int(ea["hp"])
			hp_after = int(ea["hp"])
	var aid := "enemy_" + str(e.get("kind", ""))
	if big:
		_info_head(aid, aid, str(e["name"]), Ui.text("info_enemy_stats", {"atk": e.get("atk", 0), "def": e.get("def", 0), "spd": e.get("spd", 0)}),
			"hd_enemy_hi")
	var row := Kit.hbox(8)
	if not big:
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override(&"panel", Kit.flat("hd_ink", 1.0, 4, "hd_enemy", 0.8, 1, Vector2(1, 1)))
		var pic := Portrait.new()
		pic.custom_minimum_size = Vector2(36, 36)
		pic.setup(aid, str(e["name"]), aid)
		frame.add_child(pic)
		row.add_child(frame)
	var col := Kit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var head := Kit.hbox(6)
	if not big:
		head.add_child(Kit.lbl(str(e["name"]), 13, "sans_bold", "hd_enemy_hi"))
	head.add_child(Kit.lbl("%d/%d" % [int(e["hp"]), int(e["max_hp"])], 13, "num", "hd_text"))
	if after_txt != "":
		head.add_child(Kit.lbl(after_txt, 13, "sans_bold", tone if tone != "hd_text" else "bthud_loss"))
	for tg in e.get("battle_tags", []):
		var tag_text := Ui.pick("tag", str(tg))
		if tag_text != "":
			head.add_child(Kit.pill(tag_text, "bthud_tag_hunter" if str(tg) == "hunter" else "hd_gold_deep", "hd_text", 10))
	col.add_child(head)
	var bar := W.Bar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.set("fill_key", "bthud_enemy_hp")
	bar.set("hi_key", "bthud_enemy_hp_hi")
	bar.set("loss_key", "bthud_loss")
	bar.set_values(int(e["hp"]), int(e["max_hp"]), hp_after)
	col.add_child(bar)
	var line2 := _intent_line(_intent_for(euid))
	if line2 != "":
		col.add_child(Kit.wrap(line2, INFO_W - 28 - (0 if big else 44), 12, "sans", "hd_text_2"))
	row.add_child(col)
	_info_box.add_child(row)


func _intent_for(euid: int) -> Dictionary:
	for it in _v.get("intents", []):
		if str(it.get("type", "")) == "enemy" and int(it.get("enemy", -1)) == euid:
			return it
	return {}


func _intent_line(it: Dictionary) -> String:
	if it.is_empty():
		return ""
	if bool(it.get("cancelled", false)):
		return Ui.text("info_intent_cancelled")
	var parts := PackedStringArray()
	var mt: Array = it.get("move_to", [])
	var at: Array = it.get("at", [])
	if mt != at and mt.size() == 2:
		parts.append(Ui.text("info_intent_move", {"to": Ui.label(int(mt[0]), int(mt[1]))}))
	var atk: Dictionary = it.get("attack", {})
	match str(atk.get("kind", "")):
		"eagle":
			parts.append(Ui.text("info_intent_eagle", {"n": atk.get("morale", 0)}))
		"melee", "ranged":
			var tu := _unit(str(atk.get("target", "")))
			parts.append(Ui.text("info_intent_attack", {"target": tu.get("name", ""), "dmg": atk.get("dmg", 0)}))
		"gun":
			var c: Array = atk.get("cell", [0, 0])
			parts.append(Ui.text("info_intent_gun", {"cell": Ui.label(int(c[0]), int(c[1])), "dmg": atk.get("dmg", 0)}))
		"gun_aim":
			var c2: Array = atk.get("cell", [0, 0])
			parts.append(Ui.text("info_intent_aim", {"cell": Ui.label(int(c2[0]), int(c2[1])), "turn": atk.get("fire_turn", 0)}))
	if parts.is_empty():
		parts.append(Ui.text("info_intent_stay"))
	return Ui.text("list_sep2").join(parts)


# ================================================================ 点击

## 交火回放还在放时，点什么都先把回放放完（看得到最后的样子再操作）
func _skip_playback() -> void:
	if _board != null and _board.has_method("skip_playback"):
		_board.skip_playback()


func _on_deploy_card(uid: String) -> void:
	_skip_playback()
	_status = ""
	_act_unit = ""
	if _mode in ["deploy", "facing"] and _sel_unit == uid:
		_cancel_mode()
		return
	_mode = "deploy"
	_sel_unit = uid
	_render_bar()
	_render_mode()
	_render_info()


func _on_cell(c: int, r: int) -> void:
	_skip_playback()
	if str(_v.get("phase", "")) != "command":
		return
	_status = ""
	match _mode:
		"deploy":
			if _board.valid_cells.has(Vector2i(c, r)):
				_mode = "facing"
				_sel_cell = Vector2i(c, r)
			else:
				_status = Ui.err(_place_reason(_sel_unit, c, r))
			_render_mode()
			return
		"facing":
			_mode = "deploy"
			_on_cell(c, r)
			return
		"target":
			_pick_target(c, r)
			return
		"redraw", "retreat":
			return
	var u := _unit_at(c, r)
	_act_unit = str(u["uid"]) if not u.is_empty() and str(u.get("kind", "")) != "barricade" else ""
	_render_mode()
	_render_info()


func _on_card(idx: int) -> void:
	_skip_playback()
	_status = ""
	if _mode == "redraw":
		_mode = ""
		_send("redraw", {"index": idx})
		return
	var h: Dictionary = {}
	for x in _v.get("hand", []):
		if int(x["index"]) == idx:
			h = x
	if h.is_empty():
		return
	var cid := str(h["id"])
	var need := str(CARD_TARGET.get(cid, ""))
	if need == "":
		_send("card", {"index": idx})
		return
	_act_unit = ""
	_mode = "target"
	_target = {"cmd": "card", "args": {"index": idx}, "need": need, "card": idx, "cells": _card_cells(cid, need)}
	_render_hand()
	_render_mode()


## 交火：预演说会战败或伙伴 / 主角会倒下时先确认一次
func _on_fight() -> void:
	_skip_playback()
	_status = ""
	_act_unit = ""
	if _fight_risk != "" and _mode != "fight_confirm":
		_mode = "fight_confirm"
		_render_mode()
		return
	_send("fight", {})


func _on_redraw() -> void:
	_status = ""
	_act_unit = ""
	_mode = "redraw"
	_render_hand()
	_render_mode()


func _on_retreat() -> void:
	_skip_playback()
	_status = ""
	_act_unit = ""
	_mode = "retreat"
	_render_mode()


func _on_retreat_yes() -> void:
	_mode = ""
	_send("retreat", {})


func _on_result() -> void:
	_close({"next": {"kind": "battle_result", "args": {}}})


func _cancel_mode() -> void:
	var was_card := _mode in ["redraw", "target"]
	var was_bar := _mode in ["deploy", "facing"]
	_mode = ""
	_sel_unit = ""
	_sel_cell = Vector2i(-1, -1)
	_target = {}
	_act_unit = ""
	_status = ""
	_charge = {}
	if was_card:
		_render_hand()
	if was_bar:
		_render_bar()
	_render_mode()
	_info_key = ""
	_render_info()


func _send(cmd: String, args: Dictionary) -> void:
	if engine == null:
		return
	# 先退出当前操作：指令成功时宿主的刷新（view_changed）会按新状态整个重画一遍
	_status = ""
	_mode = ""
	_sel_unit = ""
	_target = {}
	_charge = {}
	if cmd in ["fight", "withdraw", "carry", "undo", "retreat"]:
		_act_unit = ""
	var res: Dictionary = engine.send(CMD, {"cmd": cmd, "args": args})
	if _closed:
		return
	if not bool(res.get("ok", false)):
		_status = Ui.err(str(res.get("err", "")))
	_render(false)
	_render_bar()
	_render_hand()
	_render_mode()
	_render_info()


# ---------------------------------------------------------------- 朝向

## 四个箭头围着那一格（方向按相机投影：斜着的地图上「上」是往远处）
func _show_facing() -> void:
	Kit.clear(_facing)
	_facing.visible = true
	var c: Vector2 = _board.position + _board.cell_center(_sel_cell.x, _sel_cell.y)
	var ring := FacingRing.new()
	ring.size = SCREEN
	ring.center = c
	_facing.add_child(ring)
	var cam = _board.get("cam")
	var top: Vector3 = _board.cell_top(_sel_cell.x, _sel_cell.y)
	var s := 46.0
	for dir in ["right", "left", "up", "down"]:
		var d: Array = DIRS[dir]
		var tip: Vector2 = _board.position + cam.project(top + Vector3(float(d[0]), 0, float(d[1])) * 0.9)
		var vec := tip - c
		if vec.length() < 1.0:
			vec = Vector2(float(d[0]), float(d[1]))
		var dist := clampf(vec.length(), 58.0, 96.0)
		var b := W.FaceArrow.new()
		b.name = "Face_" + dir
		b.dir = dir
		b.vec = vec
		b.size = Vector2(s, s)
		b.position = (c + vec.normalized() * dist - Vector2(s, s) * 0.5).round()
		b.pressed.connect(_on_facing.bind(dir))
		b.mouse_entered.connect(_on_facing_hover.bind(dir))
		_facing.add_child(b)


func _on_facing_hover(dir: String) -> void:
	var b := _bar_entry(_sel_unit)
	_board.pattern_cells = {}
	_board.target_cells = {}
	_charge = {}
	if str(b.get("cls", "")) == "hussar" and engine != null:
		# 骠骑兵：部署就冲锋。先在深拷贝上下这条部署（指令预演），画出冲锋路线、落点和被冲击的格子，情报栏写战果
		var args := {"unit": _sel_unit, "col": _sel_cell.x, "row": _sel_cell.y, "facing": dir}
		_charge = engine.query(&"campaign.battle_preview", {"cmd": "deploy", "args": args})
		_charge["dir"] = dir
		_apply_charge_marks()
		_render_charge_info()
	else:
		for pc in _pattern(str(b.get("cls", "")), _sel_cell.x, _sel_cell.y, dir):
			_board.pattern_cells[Vector2i(pc[0], pc[1])] = true
	_board.queue_redraw()


func _apply_charge_marks() -> void:
	_board.pattern_cells = {}
	_board.target_cells = {}
	if not bool(_charge.get("ok", false)):
		return
	var land: Dictionary = _charge.get("unit", {})
	var d: Array = DIRS.get(str(_charge.get("dir", "right")), [1, 0])
	var p := _sel_cell
	var to := Vector2i(int(land.get("col", p.x)), int(land.get("row", p.y)))
	for _i in range(8):
		if p == to:
			break
		p += Vector2i(int(d[0]), int(d[1]))
		_board.pattern_cells[p] = true
	for hc in _charge.get("hit_cells", []):
		_board.target_cells[Vector2i(int(hc[0]), int(hc[1]))] = true


func _render_charge_info() -> void:
	_info_key = "charge"
	Kit.clear(_info_box)
	var b := _bar_entry(_sel_unit)
	var aid := Kit.art_id(_sel_unit, str(b.get("kind", "")), str(b.get("cls", "")))
	_info_head(aid, aid, Ui.text("charge_title"), str(b.get("name", "")), "hd_gold_hi")
	if not bool(_charge.get("ok", false)):
		_info_box.add_child(Kit.wrap(Ui.err(str(_charge.get("err", ""))), INFO_W - 28, 13, "sans", "hd_enemy_hi"))
		_show_info_panel(_sel_cell)
		return
	var land: Dictionary = _charge.get("unit", {})
	var hits: Array = _charge.get("hit_cells", [])
	if hits.is_empty():
		_info_box.add_child(Kit.wrap(Ui.text("charge_none"), INFO_W - 28, 13, "sans", "hd_text_2"))
		_show_info_panel(_sel_cell)
		return
	var hc: Array = hits[0]
	_info_box.add_child(Kit.wrap(Ui.text("charge_line", {"land": Ui.label(int(land.get("col", 0)), int(land.get("row", 0))),
		"cell": Ui.label(int(hc[0]), int(hc[1])), "n": (_charge.get("enemies", {}) as Dictionary).size()}), INFO_W - 28, 13, "sans", "hd_text"))
	_info_box.add_child(Kit.wrap(Ui.text("charge_kills", {"k": _charge.get("kills", 0), "em0": _v.get("enemy_morale", 0),
		"em": _charge.get("enemy_morale", 0)}), INFO_W - 28, 14, "sans_bold", "hd_good" if int(_charge.get("kills", 0)) > 0 else "hd_text"))
	for euid in _charge.get("enemies", {}):
		var row: Dictionary = _charge["enemies"][euid]
		var e := {}
		for x in _v.get("enemies", []):
			if str(int(x["uid"])) == str(euid):
				e = x
		if e.is_empty():
			continue
		var line := "%s %d %s" % [str(e["name"]), int(e["hp"]), Ui.text("info_after_dead_short") if not bool(row.get("alive", true)) else Ui.text("after_arrow", {"n": int(row.get("hp", 0))})]
		_info_box.add_child(Kit.wrap(line, INFO_W - 28, 12, "sans", "hd_text_2"))
	_show_info_panel(_sel_cell)


func _on_facing(dir: String) -> void:
	var uid := _sel_unit
	var cell := _sel_cell
	_send("deploy", {"unit": uid, "col": cell.x, "row": cell.y, "facing": dir})


# ---------------------------------------------------------------- 单位动作

## 选中我方单位：身边一圈圆按钮（技能在右，撤下在左上，方阵 / 瞄准在左下，关闭在右上），名字在头顶
func _show_actions(u: Dictionary) -> void:
	Kit.clear(_popup)
	var live := str(_v.get("phase", "")) == "command"
	var uid := str(u["uid"])
	var big := 50.0
	var small := 44.0
	var order: Array = []
	var notes: Array = []
	if str(u["state"]) == "dying":
		var carry := _act_button("Act_carry", Ui.text("act_glyph_carry"), Ui.text("act_cap_carry", {"cost": u.get("carry_cost", 2)}), big)
		carry.tone = "danger"
		carry.disabled = not live or not bool(u.get("can_carry", false))
		carry.tooltip_text = Ui.text("act_carry", {"cost": u.get("carry_cost", 2)})
		carry.pressed.connect(func() -> void: _send("carry", {"unit": uid}))
		order.append(carry)
		var why := str(u.get("carry_reason", ""))
		if why != "":
			# 抬不了：写清楚为什么（旁边没人 / 军令点不够），不是一个 0 点的灰按钮
			var wl := Kit.wrap(Ui.text("act_carry_" + why), 190, 12, "sans_bold", "hd_enemy_hi")
			wl.name = "CarryReason"
			Kit.outline(wl, 4, "hd_ink", 0.9)
			_popup.add_child(wl)
			notes.append(wl)
	elif str(u.get("kind", "")) != "npc":
		var sk := str(u.get("skill", ""))
		if sk != "":
			var ready := bool(u.get("skill_ready", false))
			var need := maxi(1, int(u.get("charge_need", 1)))
			var frac := float(u.get("charge", 0)) / float(need)
			var glyph := str(u.get("skill_name", "")).substr(0, 1)
			if sk == "fortify":
				for mode in ["barricade", "earthwork"]:
					var fb := _act_button("Act_skill_" + mode, Ui.text("act_glyph_" + mode), Ui.text("act_cap_" + mode), big - 4.0)
					fb.ring = frac
					fb.lit = ready
					fb.disabled = not live or not ready
					fb.tooltip_text = Ui.text("act_fortify_" + mode) if ready \
						else Ui.text("act_skill_wait", {"skill": u["skill_name"], "charge": u["charge"], "need": u["charge_need"]})
					fb.pressed.connect(_on_skill.bind(u, mode))
					order.append(fb)
			else:
				var cap := str(u["skill_name"]) if ready else Ui.text("act_skill_wait", {"skill": u["skill_name"], "charge": u["charge"], "need": u["charge_need"]})
				var sb := _act_button("Act_skill", glyph, cap, big)
				sb.ring = frac
				sb.lit = ready
				sb.disabled = not live or not ready
				sb.tooltip_text = Ui.text("act_skill", {"skill": u["skill_name"]}) + "\n" + str(Rules.SKILLS.get(sk, {}).get("desc", ""))
				sb.pressed.connect(_on_skill.bind(u, ""))
				order.append(sb)
		if bool(u.get("can_move", false)):
			var move := _act_button("Act_move", Ui.text("act_glyph_move"), Ui.text("act_move"), small)
			move.tone = "ally"
			move.pressed.connect(_on_move.bind(u))
			order.append(move)
		if str(u["cls"]) == "artillery":
			var aim := _act_button("Act_aim", Ui.text("act_glyph_aim"), Ui.text("act_aim"), small)
			aim.tone = "ally"
			aim.disabled = not live
			aim.pressed.connect(_on_aim.bind(u))
			order.append(aim)
		if str(u["cls"]) in ["line", "grenadier"]:
			var sq := bool(u.get("square", false))
			var fb2 := _act_button("Act_square", Ui.text("act_glyph_square"), Ui.text("act_cap_square_off" if sq else "act_cap_square_on"), small)
			fb2.tone = "ally"
			fb2.lit = sq
			fb2.disabled = not live
			fb2.tooltip_text = Ui.text("act_square_off" if sq else "act_square_on")
			fb2.pressed.connect(func() -> void: _send("formation", {"unit": uid, "square": not sq}))
			order.append(fb2)
		var wd := _act_button("Act_withdraw", Ui.text("act_glyph_withdraw"), Ui.text("act_withdraw"), small)
		wd.disabled = not live or not bool(u.get("can_withdraw", false))
		wd.tooltip_text = Ui.err("just_deployed") if live and not bool(u.get("can_withdraw", false)) else Ui.text("act_withdraw")
		wd.pressed.connect(func() -> void: _send("withdraw", {"unit": uid}))
		order.append(wd)
	var close := _act_button("Act_close", Ui.text("act_glyph_close"), "", 30.0)
	close.pressed.connect(_cancel_mode)
	order.append(close)
	_place_ring(u, order, notes)
	_popup.visible = true


func _act_button(node_name: String, glyph: String, caption: String, s: float) -> W.RoundAct:
	var b := W.RoundAct.new()
	b.name = node_name
	b.glyph = glyph
	b.caption = caption
	# 说明字只在悬停时出（常显会压到邻格的单位和名字牌）；完整说明在悬停提示里
	b.caption_on_hover = true
	if b.tooltip_text == "" and caption != "":
		b.tooltip_text = caption
	b.size = Vector2(s, s)
	_popup.add_child(b)
	return b


## 选中单位身边的一圈圆按钮：都在头顶一段固定半径的圆弧上（以正上方为中，按顺序左右排开），
## 碰到别的单位（身子、血条、名字牌）、鹰旗格、自己的血条，或出了屏幕（顶栏、底下的牌），只沿着这段弧挪开；
## 弧上实在没地方才往外挪一圈。按钮不多（关闭键不算，≤ RING_CAPTIONS 个）时，说明字常显在按钮下面
func _place_ring(u: Dictionary, buttons: Array, notes: Array) -> void:
	var cam = _board.get("cam")
	var top: Vector3 = _board.cell_top(int(u["col"]), int(u["row"]))
	var head: Vector2 = _board.position + cam.project(top + Vector3(0, 1.0, 0))
	var center := head + Vector2(0, 14)
	var named := str(u.get("kind", "")) in ["hero", "companion"]
	var blocks := _ring_obstacles(str(u["uid"]), head, named)
	var main := 0
	for b in buttons:
		if str((b as Control).name) != "Act_close":
			main += 1
	var captions := main <= RING_CAPTIONS
	for b in buttons:
		if captions and (b as W.RoundAct).caption != "":
			(b as W.RoundAct).caption_on_hover = false
	var radius := RING_R_NAMED if named else RING_R
	# 先找一段连在一起的弧：按钮按顺序沿弧排开，整段都不碰东西、都在屏幕里，弧短、离正上方近
	var angles := _ring_fan(buttons, center, blocks, radius, RING_STEP)
	if angles.is_empty():
		angles = _ring_fan(buttons, center, blocks, radius + RING_OUT, RING_STEP * 0.85)
	if not angles.is_empty():
		for i in range(buttons.size()):
			var b: Control = buttons[i]
			var c := center + Vector2(cos(deg_to_rad(float(angles[i]))), sin(deg_to_rad(float(angles[i])))) * float(_fan_r)
			b.position = (c - b.size * 0.5).round()
	else:
		# 弧上实在排不下：一个一个沿弧找空位
		var placed: Array = []
		var n := buttons.size()
		for i in range(n):
			var b: W.RoundAct = buttons[i]
			var pref := -90.0 + (float(i) - float(n - 1) * 0.5) * RING_STEP
			var chosen := Vector2.INF
			var fallback := Vector2.INF
			for d in RING_SHIFTS:
				var a := deg_to_rad(pref + float(d))
				var c: Vector2 = center + Vector2(cos(a), sin(a)) * (radius + RING_OUT)
				var rect := _act_rect(b, c)
				if not _ring_on_screen(rect) or _ring_hits(rect.grow(3.0), placed):
					continue
				if fallback == Vector2.INF:
					fallback = c
				if _ring_hits(rect.grow(2.0), blocks):
					continue
				chosen = c
				break
			if chosen == Vector2.INF:
				chosen = fallback if fallback != Vector2.INF else center + Vector2(0, -radius)
			b.position = (chosen - b.size * 0.5).round()
			placed.append(_act_rect(b, chosen))
	for wl in notes:
		(wl as Control).position = (head + Vector2(-95, 30)).round()


## 一段连着的弧：按钮按顺序沿圆弧（半径 rad）往顺时针方向排，相邻两个隔开刚好放得下（最少 step 度的一半、按宽度算），
## 碰到东西就沿弧再往后挪一点。起点在一圈里挑：整段都在屏幕里、不碰东西，弧最短、中点离正上方（-90°）最近的那个。
## 找不到返回空数组。用到的半径记在 _fan_r
func _ring_fan(buttons: Array, center: Vector2, blocks: Array, rad: float, step: float) -> Array:
	var n := buttons.size()
	var best: Array = []
	var best_score := INF
	var a0 := -270.0
	while a0 <= 90.0:
		var out: Array = []
		var rects: Array = []
		var a := a0
		var ok := true
		for i in range(n):
			var placed := false
			while a <= a0 + 330.0:
				var c := center + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * rad
				var rect := _act_rect(buttons[i], c)
				if _ring_on_screen(rect) and not _ring_hits(rect.grow(2.0), blocks) and not _ring_hits(rect.grow(3.0), rects):
					out.append(a)
					rects.append(rect)
					placed = true
					break
				a += 4.0
			if not placed:
				ok = false
				break
			if i + 1 < n:
				var w := (_act_rect(buttons[i], Vector2.ZERO).size.x + _act_rect(buttons[i + 1], Vector2.ZERO).size.x) * 0.5 + 8.0
				a += maxf(step * 0.5, rad_to_deg(w / rad))
		if ok:
			var span := float(out.back()) - float(out[0])
			var mid := (float(out.back()) + float(out[0])) * 0.5
			var score := span + absf(wrapf(mid + 90.0, -180.0, 180.0)) * 0.6
			if score < best_score:
				best = out
				best_score = score
		a0 += 6.0
	if not best.is_empty():
		_fan_r = rad
	return best


## 一个圆按钮占的地方：圆本身，常显说明字时再加上下面那一行字
func _act_rect(b: W.RoundAct, c: Vector2) -> Rect2:
	var r := Rect2(c - b.size * 0.5, b.size)
	if b.caption != "" and not b.caption_on_hover:
		var w := HdTheme.font("sans_bold").get_string_size(b.caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
		r = r.merge(Rect2(Vector2(c.x - w * 0.5, r.end.y), Vector2(w, 18)))
	return r


## 圆按钮要避开的东西（屏幕坐标）：别的单位（头顶的血条、名字牌到脚底）、鹰旗格（连旗杆）、自己的血条和名字牌
func _ring_obstacles(self_uid: String, head: Vector2, named: bool) -> Array:
	# 自己头顶：血条、名字牌（主角、伙伴）、这一回合挨打的合计签
	var above := 62.0 if named else 42.0
	var out: Array = [Rect2(head + Vector2(-42, -above), Vector2(84, above + 4))]
	var cam = _board.get("cam")
	for ou in _board.get("ov_units"):
		var d: Dictionary = ou.get("data", {})
		if str(ou.get("side", "")) == "ally" and str(d.get("uid", "")) == self_uid:
			continue
		var node = _board.unit_node(str(ou["key"]))
		var foot: Vector3 = node.position if node != null else ou["foot"]
		var h := float(node.head) if node != null else float(ou["head"])
		var hp: Vector2 = _board.position + cam.project(foot + Vector3(0, h, 0))
		var fp: Vector2 = _board.position + cam.project(foot)
		var other_named := str(d.get("kind", "")) in ["hero", "companion"]
		var top_h := 46.0 if other_named else 30.0
		out.append(Rect2(Vector2(hp.x - 40, hp.y - top_h), Vector2(84, maxf(fp.y - hp.y, 10.0) + top_h + 6)))
	for cd in _v.get("grid", {}).get("cells", []):
		if str(cd.get("terrain", "")) != "eagle":
			continue
		var cr: Rect2 = _board.cell_rect(int(cd["col"]), int(cd["row"]))
		cr.position += _board.position
		out.append(Rect2(cr.position + Vector2(0, -56), cr.size + Vector2(0, 56)))
	return out


func _ring_on_screen(r: Rect2) -> bool:
	return r.position.x >= 6.0 and r.end.x <= SCREEN.x - 6.0 and r.position.y >= SAFE_TOP and r.end.y <= STRIP_Y - 12.0


func _ring_hits(r: Rect2, rects: Array) -> bool:
	for o in rects:
		if r.intersects(o):
			return true
	return false


## 圆按钮按圆心摆，夹在屏幕里（不压顶栏和底下的牌）
func _place_act(b: Control, center: Vector2) -> void:
	var c := Vector2(clampf(center.x, b.size.x * 0.5 + 6, SCREEN.x - b.size.x * 0.5 - 6),
		clampf(center.y, SAFE_TOP + b.size.y * 0.5, STRIP_Y - 26 - b.size.y * 0.5))
	b.position = (c - b.size * 0.5).round()


func _on_skill(u: Dictionary, mode: String) -> void:
	var uid := str(u["uid"])
	match str(u.get("skill", "")):
		"mark_target":
			var cells := {}
			for pc in u.get("pattern", []):
				if not _board.enemies_at(int(pc[0]), int(pc[1])).is_empty():
					cells[Vector2i(int(pc[0]), int(pc[1]))] = true
			_begin_target("skill", {"unit": uid}, "cell", cells)
		"fortify":
			var cells2 := {}
			for d in DIRS.values():
				var c := int(u["col"]) + int(d[0])
				var r := int(u["row"]) + int(d[1])
				var cd := _cell(c, r)
				if cd.is_empty() or _occupied(c, r):
					continue
				var tr := str(cd.get("terrain", ""))
				if (mode == "earthwork" and tr == "plain") or (mode != "earthwork" and tr in Rules.GROUND and not bool(cd.get("reserved", false))):
					cells2[Vector2i(c, r)] = true
			_begin_target("skill", {"unit": uid, "mode": mode}, "cell", cells2)
		_:
			_send("skill", {"unit": uid})


func _on_move(u: Dictionary) -> void:
	var cells := {}
	for at in u.get("move_cells", []):
		cells[Vector2i(int(at[0]), int(at[1]))] = true
	_begin_target("move", {"unit": str(u["uid"])}, "cell", cells)


func _on_aim(u: Dictionary) -> void:
	var cells := {}
	for pc in u.get("pattern", []):
		cells[Vector2i(int(pc[0]), int(pc[1]))] = true
	_begin_target("aim", {"unit": str(u["uid"])}, "cell", cells)


func _begin_target(cmd: String, args: Dictionary, need: String, cells: Dictionary) -> void:
	_act_unit = ""
	_mode = "target"
	_target = {"cmd": cmd, "args": args, "need": need, "cells": cells}
	_render_mode()


func _pick_target(c: int, r: int) -> void:
	var cells: Dictionary = _target.get("cells", {})
	if not cells.has(Vector2i(c, r)):
		_status = Ui.err("bad_cell")
		_render_mode()
		return
	var args: Dictionary = (_target.get("args", {}) as Dictionary).duplicate()
	match str(_target.get("need", "")):
		"row":
			args["row"] = r
		"unit":
			args["unit"] = str(_unit_at(c, r).get("uid", ""))
		_:
			args["col"] = c
			args["row"] = r
	var cmd := str(_target.get("cmd", ""))
	_mode = ""
	_target = {}
	_send(cmd, args)


## 军令牌的目标格：行牌高亮整行；单位牌高亮能用的我方单位；佯动高亮敌方目标旁边的格子；集中炮火高亮炮兵射程
func _card_cells(cid: String, need: String) -> Dictionary:
	var out := {}
	var cols := int(_v.get("grid", {}).get("cols", 0))
	var rows := int(_v.get("grid", {}).get("rows", 0))
	match need:
		"row":
			for r in range(rows):
				var any := cid == "volley"
				if cid == "bugler":
					for e in _v.get("enemies", []):
						if int(e["row"]) == r and str(e["type"]) != "gun":
							any = true
				if any:
					for c in range(cols):
						out[Vector2i(c, r)] = true
		"unit":
			for u in _v.get("battle_units", []):
				if str(u["state"]) != "ok" or str(u["kind"]) == "barricade":
					continue
				if cid == "fallback" and not bool(u.get("can_withdraw", false)):
					continue
				if cid == "bayonet" and not str(u["cls"]) in ["line", "grenadier", "hussar", "engineer", "drummer", "hero"]:
					continue
				out[Vector2i(int(u["col"]), int(u["row"]))] = true
		"cell":
			if cid == "barrage":
				for u in _v.get("battle_units", []):
					if str(u["cls"]) == "artillery" and str(u["state"]) == "ok":
						for pc in u.get("pattern", []):
							out[Vector2i(int(pc[0]), int(pc[1]))] = true
			else:
				var aims: Array = []
				for it in _v.get("intents", []):
					if str(it.get("type", "")) == "crosshair":
						aims.append(Vector2i(int(it["cell"][0]), int(it["cell"][1])))
					elif str(it.get("type", "")) == "enemy" and str(it.get("attack", {}).get("kind", "")) == "ranged":
						var tu := _unit(str(it["attack"].get("target", "")))
						if not tu.is_empty():
							aims.append(Vector2i(int(tu["col"]), int(tu["row"])))
				for a in aims:
					for d in DIRS.values():
						var p := Vector2i(a.x + int(d[0]), a.y + int(d[1]))
						if p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows:
							out[p] = true
	return out


# ================================================================ 查表

func _unit(uid: String) -> Dictionary:
	for u in _v.get("battle_units", []):
		if str(u["uid"]) == uid:
			return u
	return {}


func _unit_at(c: int, r: int) -> Dictionary:
	for u in _v.get("battle_units", []):
		if int(u["col"]) == c and int(u["row"]) == r:
			return u
	return {}


func _bar_entry(uid: String) -> Dictionary:
	for b in _v.get("deploy_bar", []):
		if str(b["uid"]) == uid:
			return b
	return {}


func _cell(c: int, r: int) -> Dictionary:
	var g: Dictionary = _v.get("grid", {})
	var cols := int(g.get("cols", 0))
	if c < 0 or r < 0 or c >= cols or r >= int(g.get("rows", 0)):
		return {}
	return g["cells"][r * cols + c]


func _occupied(c: int, r: int) -> bool:
	return not _unit_at(c, r).is_empty() or not _board.enemies_at(c, r).is_empty()


func _place_reason(uid: String, c: int, r: int) -> String:
	var b := _bar_entry(uid)
	var cd := _cell(c, r)
	if b.is_empty() or cd.is_empty():
		return "bad_cell"
	var tr := str(cd.get("terrain", ""))
	# 站位一律问规则内核（40 种地形；桅盘、屋顶只给猎兵）
	if not Rules.can_stand(str(b.get("cls", "")), tr):
		return "terrain"
	if not _unit_at(c, r).is_empty():
		return "occupied"
	if not _board.enemies_at(c, r).is_empty():
		return "enemy_here"
	if bool(cd.get("reserved", false)):
		return "reserved"
	return ""


func _deploy_cells(uid: String) -> Dictionary:
	var out := {}
	var start := str(_bar_entry(uid).get("start_cell", ""))
	for cd in _v.get("grid", {}).get("cells", []):
		if (start == "" or str(cd["label"]) == start) and _place_reason(uid, int(cd["col"]), int(cd["row"])) == "":
			out[Vector2i(int(cd["col"]), int(cd["row"]))] = true
	return out


## 射程图样（和规则内核 _pattern_cells 一样）：横队前方 1–2 格，猎兵前方 1–3 格，炮兵前方第 2–5 格本行和上下相邻行，其余前方 1 格
func _pattern(cls: String, c: int, r: int, facing: String) -> Array:
	var f: Array = DIRS[facing]
	var l: Array = LATERAL[facing]
	var spec: Array = []
	match cls:
		"line": spec = [[1, 0], [2, 0]]
		"jager": spec = [[1, 0], [2, 0], [3, 0]]
		"artillery":
			for dx in range(2, 6):
				for dy in [-1, 0, 1]:
					spec.append([dx, dy])
		_: spec = [[1, 0]]
	var out: Array = []
	var cols := int(_v.get("grid", {}).get("cols", 0))
	var rows := int(_v.get("grid", {}).get("rows", 0))
	for s in spec:
		var cc: int = c + int(f[0]) * int(s[0]) + int(l[0]) * int(s[1])
		var rr: int = r + int(f[1]) * int(s[0]) + int(l[1]) * int(s[1])
		if cc >= 0 and rr >= 0 and cc < cols and rr < rows:
			out.append([cc, rr])
	return out


# ================================================================ 小件

## 顶栏左边的徽章：金圈里一个字
class Emblem extends Control:
	var glyph := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(c, r, Kit.cola("hd_navy_2"), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 48, Kit.cola("hd_gold_hi"), 1.5, true)
		draw_arc(c, r - 3.5, 0, TAU, 48, Kit.cola("hd_gold", 0.5), 1.0, true)
		Kit.text_c(self, glyph, c, HdTheme.font("title"), int(r * 1.05), Kit.cola("hd_gold_hi"))


## 军令点牌子的底：玻璃 + 左边一道金
class CpPlate extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(HdTheme.panel_box("glass"), r)
		Kit.box(self, Rect2(0, 6, 3, size.y - 12), Kit.cola("hd_gold"), 1.0)


## 选朝向时那一格周围的金圈和说明
class FacingRing extends Control:
	var center := Vector2.ZERO

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		D.glow(self, Rect2(center - Vector2(110, 80), Vector2(220, 160)), Kit.cola("hd_ink", 0.55))
		draw_arc(center, 78.0, 0, TAU, 96, Kit.cola("hd_gold", 0.35), 1.5, true)
		draw_arc(center, 70.0, 0, TAU, 96, Kit.cola("hd_gold_hi", 0.18), 6.0, true)


## 图例里的地块小样：这种地形用的地块贴图（有美术用美术），红门、鹰旗、河、桥再加个小记号
class Swatch extends Control:
	var terrain := "plain"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var tex_id := HdArt.terrain_tex(terrain)
		if terrain == "bridge":
			tex_id = HdArt.terrain_tex("river")
		if tex_id != "":
			draw_texture_rect(HdPlaceholder.make_tile_tex(tex_id), r, false)
		else:
			Kit.box(self, r, Kit.cola("hd_navy_3"), 3.0)
		match terrain:
			"gate":
				Kit.box(self, Rect2(r.position + Vector2(5, 3), Vector2(4, r.size.y - 6)), Kit.cola("bthud_gate"), 1.0)
				Kit.box(self, Rect2(r.position + Vector2(r.size.x - 9, 3), Vector2(4, r.size.y - 6)), Kit.cola("bthud_gate"), 1.0)
			"eagle":
				D.diamond(self, r.get_center(), 6.0, Kit.cola("hd_gold_hi"))
			"bridge":
				Kit.box(self, Rect2(r.position + Vector2(0, r.size.y * 0.32), Vector2(r.size.x, r.size.y * 0.36)), Kit.cola("bthud_bridge"), 1.0)
		Kit.box_edge(self, r, Kit.cola("hd_ink", 0.0), 3.0, Kit.cola("hd_gold", 0.6), 1.0)


## 打完的横幅底下那条横贯屏幕的暗带：两头淡出，上下各一道胜负色的细线
class Band extends Control:
	var tone := "bthud_victory"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var clear := Kit.cola("hd_ink", 0.0)
		var dark := Kit.cola("hd_ink", 0.82)
		var xs := [0.0, w * 0.22, w * 0.78, w]
		var cs := [clear, dark, dark, clear]
		for i in range(3):
			draw_polygon(PackedVector2Array([Vector2(xs[i], 0), Vector2(xs[i + 1], 0), Vector2(xs[i + 1], h), Vector2(xs[i], h)]),
				PackedColorArray([cs[i], cs[i + 1], cs[i + 1], cs[i]]))
		D.fade_line(self, Vector2(0, 1), Vector2(w, 1), Kit.cola(tone, 0.8), 1.5)
		D.fade_line(self, Vector2(0, h - 1), Vector2(w, h - 1), Kit.cola(tone, 0.8), 1.5)
		D.glow(self, Rect2(w * 0.5 - 300, -60, 600, h + 120), Kit.cola(tone, 0.18))
