# 面板宿主：按 PANEL_SHOW 分到演出层、左/右抽屉、叠层。每个 kind 都用主人的场景（X01-b 起没有 W0 的 PanelStub）；
# 没登记场景的 kind 什么都不开、返回 null、不报错（框架版收尾默认，合同 §7.8）。
# 一次只演一出，一次只开一个抽屉。叠层可以叠。主人 C01。
# 层次（b02）：根场景给本节点 z_index（在手牌和牌桌顶层之上），画的顺序和点击的顺序一致。
# 合同：docs/cards/CARDS_INTERFACES.md §7.8、§7.11。
class_name CardModalHost
extends Control

signal follow_up(result: Dictionary, kind: StringName)

var engine: CardEngineApi = null
var bus: CardEventBus = null
var stage: CardStageApi = null
var dialog: CardDialogApi = null
var checks: CardChecksApi = null
var hand: CardHandApi = null
var play_layer: Control = null
var drawer = null
var settings_path: String = ""
var cards_settings_path: String = ""
## True once the root forwards dialog.reply_chosen → play.on_reply. Stage
## panels that get this dialog then must not subscribe to it themselves.
var routes_replies: bool = false

## Fast animations (fixtures, autoplay, the fast_anim setting): panels appear without fading.
var fast: bool = false
## The root's close-day button (see set_band).
var band: Control = null

## Meta set on stage panels whose dialog replies the host already forwards.
const REPLY_ROUTED_META := &"host_reply_dialog"
const SHADE_FADE_S := 0.22
## 战斗 v2 的三块面板（远洋战役的「战场」牌打出来开）：没有场景，直接 new 脚本；都按叠层摆，三块都是满屏的高清面板。
## 剧情 VN（远洋战役的金色剧情牌打出来开，scripts/cards/ui/vn/）也是满屏的脚本面板。
const SCRIPT_PANELS := {
	&"battle_lineup": "res://scripts/cards/ui/battle/battle_lineup_panel.gd",
	&"battle_v2": "res://scripts/cards/ui/battle/battle_panel.gd",
	&"battle_result": "res://scripts/cards/ui/battle/battle_result_panel.gd",
	&"vn": "res://scripts/cards/ui/vn/vn_panel.gd",
	&"map": "res://scripts/cards/ui/map/map_node_panel.gd",
	&"map_shop": "res://scripts/cards/ui/map/map_node_panel.gd",
	&"map_camp": "res://scripts/cards/ui/map/map_node_panel.gd",
	&"map_interlude": "res://scripts/cards/ui/map/map_node_panel.gd",
}
const FULLSCREEN := [&"battle_v2", &"battle_lineup", &"battle_result", &"vn", &"map", &"map_shop", &"map_camp", &"map_interlude"]
## 远洋战役（高清营地）开着时，根场景在这里把几种旧面板换成高清的脚本面板：kind -> 脚本路径（kind 不变，
## top_kind / is_open 照旧认它）。换上的都是满屏叠层（原来是抽屉的信物、档案、设置也一样）。旧版战役里这张表是空的，什么都不变。
var overrides: Dictionary = {}
## Drawer frame titles that differ from the tab caption (prototype: 黄历, 钱匣 · 家当).
const DRAWER_TITLES := {&"almanac": "c01.drawer.almanac", &"estates": "c01.drawer.estates", &"relics": "rg4.drawer.relics"}
const DRAWER_FADE_S := 0.26

var _overlays: Array = []
var _drawer: Dictionary = {}
var _play: Dictionary = {}
var _visual_owner: CardPanel = null
var _last_closed: StringName = &""
var _packed: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	engine = p_engine
	bus = p_bus
	# 不在 bind 时预加载全部面板：短测退出时会拖一堆纹理/字体泄漏。


func last_closed_kind() -> StringName:
	return _last_closed


func open_panel(kind: StringName, args: Dictionary) -> CardPanel:
	var packed := args.duplicate(true)
	var tab := StringName(str(packed.get("_tab", "")))
	packed.erase("_tab")
	if kind == &"read":
		packed["mode"] = "read"
	if kind == &"settings":
		if str(packed.get("settings_path", "")) == "":
			packed["settings_path"] = settings_path
		if str(packed.get("cards_settings_path", "")) == "":
			packed["cards_settings_path"] = cards_settings_path
	var panel := _make(kind)
	if panel == null:
		return null
	var declared: StringName = CardIds.PANEL_SHOW.get(kind, CardIds.SHOW_OVERLAY)
	var show := declared
	if show == CardIds.SHOW_STAGE and not (panel is CardStagePanel):
		show = CardIds.SHOW_OVERLAY
	if show == CardIds.SHOW_HOST:
		show = CardIds.SHOW_OVERLAY
	# 换上的高清面板（远洋战役）一律按满屏叠层摆：信物、档案、设置不再进像素抽屉框
	if overrides.has(kind):
		show = CardIds.SHOW_OVERLAY
	panel.bind(engine, bus)
	if panel is CardStagePanel:
		(panel as CardStagePanel).bind_stage(stage, dialog, checks, hand)
		# Only the play (stage) panel gets the root's reply forwarding.
		if routes_replies and dialog != null and show == CardIds.SHOW_STAGE:
			panel.set_meta(REPLY_ROUTED_META, dialog.get_instance_id())
	if show == CardIds.SHOW_STAGE:
		_replace_play()
		_place_play(panel)
		_remember(_play, kind, panel, show, "")
	elif show == CardIds.SHOW_DRAWER_L or show == CardIds.SHOW_DRAWER_R:
		_replace_drawer()
		var side := "l" if show == CardIds.SHOW_DRAWER_L else "r"
		_place_drawer(panel, kind, tab, side)
		_remember(_drawer, kind, panel, show, side)
		_ui(&"drawer_opened", kind, show, side)
	else:
		var full := is_fullscreen(kind)
		_place_overlay(panel, full)
		_overlays.append({
			"kind": kind, "panel": panel, "show": show, "where": "overlay", "side": "",
		})
		# 满屏面板自己画整个画面，背后不再演旧柜台的那出戏
		if not full:
			_arm_visual(panel, packed)
	panel.open(packed)
	if show == CardIds.SHOW_STAGE and panel is CardStagePanel and str(packed.get("uid", "")) != "":
		(panel as CardStagePanel).begin_play(str(packed["uid"]))
	if not panel.close_requested.is_connected(_on_close):
		panel.close_requested.connect(_on_close.bind(panel))
	_ui(&"panel_opened", kind, show, "")
	return panel


func close_panel(p: CardPanel) -> void:
	_drop(p, true)


func close_top() -> void:
	var top := top_panel()
	if top != null:
		top.dismiss()


## 回标题时用：叠层、抽屉、演出面板一次收干净（不走各面板的 close_requested，不发后续指令）。
func close_all() -> void:
	for row in _rows():
		var panel: CardPanel = row["panel"]
		if is_instance_valid(panel):
			_drop(panel, true)
	_overlays.clear()
	_drawer = {}
	_play = {}
	_visual_owner = null


func top_panel() -> CardPanel:
	if not _overlays.is_empty():
		return _overlays.back()["panel"]
	if not _drawer.is_empty():
		return _drawer["panel"]
	if not _play.is_empty():
		return _play["panel"]
	return null


func top_kind() -> StringName:
	if not _overlays.is_empty():
		return _overlays.back()["kind"]
	if not _drawer.is_empty():
		return _drawer["kind"]
	if not _play.is_empty():
		return _play["kind"]
	return &""


## 满屏的高清面板（自己画整个画面）：登记的满屏脚本面板，和远洋战役换上的高清面板
func is_fullscreen(kind: StringName) -> bool:
	return kind in FULLSCREEN or overrides.has(kind)


func top_overlay() -> CardPanel:
	return _overlays.back()["panel"] if not _overlays.is_empty() else null


func play_panel() -> CardPanel:
	return _play["panel"] if not _play.is_empty() else null


func drawer_panel() -> CardPanel:
	return _drawer["panel"] if not _drawer.is_empty() else null


func drawer_open() -> bool:
	return not _drawer.is_empty()


func is_open(kind: StringName) -> bool:
	for row in _overlays:
		if row["kind"] == kind:
			return true
	if not _drawer.is_empty() and _drawer["kind"] == kind:
		return true
	if not _play.is_empty() and _play["kind"] == kind:
		return true
	return false


func refresh(view: Dictionary) -> void:
	for row in _rows():
		var panel: CardPanel = row["panel"]
		if is_instance_valid(panel):
			panel.refresh(view)


func _on_close(result: Dictionary, panel: CardPanel) -> void:
	var row := _find(panel)
	if row.is_empty():
		return
	var kind: StringName = row["kind"]
	_drop(panel, true)
	follow_up.emit(result, kind)


func _replace_play() -> void:
	_visual_owner = null
	if _play.is_empty():
		return
	var old: CardPanel = _play["panel"]
	if is_instance_valid(old):
		old.dismiss()


func _replace_drawer() -> void:
	if _drawer.is_empty():
		return
	var old: CardPanel = _drawer["panel"]
	if is_instance_valid(old):
		old.dismiss()


func _place_play(panel: CardPanel) -> void:
	if play_layer == null:
		add_child(panel)
		return
	_pin(panel, Rect2(0, 0, 1280, 720))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_layer.add_child(panel)


func _pin(panel: Control, rect: Rect2) -> void:
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = rect.position
	panel.size = rect.size


func _place_drawer(panel: CardPanel, kind: StringName, tab: StringName, side: String) -> void:
	var title := "c01.tab." + str(tab if tab != &"" else kind)
	if kind in DRAWER_TITLES:
		title = DRAWER_TITLES[kind]
	var highlight := tab if tab != &"" else kind
	if drawer != null and drawer.has_method("show_frame"):
		drawer.show_frame(highlight, side, title)
	# 挂在 ModalHost 下（满屏），与 Body 同尺寸；C05 等沿父节点能找到宿主。
	_pin(panel, Rect2(0, 0, 1280, 720))
	add_child(panel)
	# b23：抽屉框的标题行（标题、细线、合上）挪到面板上面，满屏的面板根不再挡住“合上”。
	if drawer != null and drawer.has_method("chrome"):
		var chrome: Control = drawer.chrome()
		if chrome != null:
			if chrome.get_parent() != self:
				if chrome.get_parent() != null:
					chrome.get_parent().remove_child(chrome)
				add_child(chrome)
			move_child(chrome, -1)
	# 合同层次：抽屉 8 < 打烊按钮 9 < 叠层 10。打烊按钮挂在本节点里，排在抽屉面板和标题行后面、叠层前面。
	if band != null and band.get_parent() == self:
		move_child(band, -1)
	_fade_in(panel, DRAWER_FADE_S)


## The close-day button lives here (contract §7.11.1 layer 9): above the drawer panel and its title row,
## below every overlay (overlays are added after it). The root calls this once.
func set_band(node: Control) -> void:
	band = node
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	add_child(node)


func _place_overlay(panel: CardPanel, full: bool = false) -> void:
	var shade := ColorRect.new()
	shade.color = CardTheme.color(&"shade")
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_fade_in(shade, SHADE_FADE_S)
	_pin(panel, Rect2(0, 0, 1280, 720) if full else CardLayout.OVERLAY_MAX)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("shade", shade)
	add_child(panel)


## Fade a freshly placed node in (drawer content while its frame slides, overlay shade 0.22 s).
## Only the look changes; the node takes clicks at once. Fast animations: no fade.
func _fade_in(node: CanvasItem, seconds: float) -> void:
	if fast or not is_inside_tree():
		return
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, "modulate:a", 1.0, seconds)


func _arm_visual(panel: CardPanel, args: Dictionary) -> void:
	if stage == null or engine == null or not _play.is_empty():
		return
	var uid := str(args.get("uid", ""))
	if uid == "":
		return
	var card_view := engine.query(&"card", {"uid": uid})
	if card_view.is_empty():
		return
	stage.play(CardStageScript.resolve(card_view, engine.view()))
	_visual_owner = panel


func _drop(panel: CardPanel, notify: bool) -> void:
	var row := _find(panel)
	if row.is_empty():
		return
	var kind: StringName = row["kind"]
	var show: StringName = row["show"]
	var side := str(row.get("side", ""))
	_last_closed = kind
	if row.get("where", "") == "overlay":
		_overlays.erase(row)
		var shade: Node = panel.get_meta("shade", null)
		if is_instance_valid(shade):
			shade.queue_free()
	elif row.get("where", "") == "drawer":
		_drawer = {}
		if drawer != null and drawer.has_method("hide_frame"):
			drawer.hide_frame()
		if notify:
			_ui(&"drawer_closed", kind, show, side)
	elif row.get("where", "") == "play":
		_play = {}
		if panel is CardStagePanel:
			(panel as CardStagePanel).end_play()
	if _visual_owner == panel:
		_visual_owner = null
		if stage != null and _play.is_empty():
			stage.clear_play()
	if is_instance_valid(panel):
		panel.queue_free()
	if notify:
		_ui(&"panel_closed", kind, show, "")


func _find(panel: CardPanel) -> Dictionary:
	for row in _overlays:
		if row["panel"] == panel:
			return row
	if not _drawer.is_empty() and _drawer["panel"] == panel:
		return _drawer
	if not _play.is_empty() and _play["panel"] == panel:
		return _play
	return {}


func _rows() -> Array:
	var out: Array = []
	out.append_array(_overlays)
	if not _drawer.is_empty():
		out.append(_drawer)
	if not _play.is_empty():
		out.append(_play)
	return out


func _remember(bucket: Dictionary, kind: StringName, panel: CardPanel, show: StringName, side: String) -> void:
	bucket.clear()
	bucket["kind"] = kind
	bucket["panel"] = panel
	bucket["show"] = show
	bucket["side"] = side
	bucket["where"] = "drawer" if side != "" else "play"


## 主人的面板场景；kind 没登记场景（或场景根不是 CardPanel）时返回 null。
func _make(kind: StringName) -> CardPanel:
	if overrides.has(kind):
		var hd_panel: CardPanel = load(str(overrides[kind])).new()
		if "kind" in hd_panel:
			hd_panel.set("kind", kind)
		return hd_panel
	if SCRIPT_PANELS.has(kind):
		var script_panel: CardPanel = load(str(SCRIPT_PANELS[kind])).new()
		if "kind" in script_panel:
			script_panel.set("kind", kind)
		return script_panel
	var packed := _packed_scene(kind)
	if packed == null:
		return null
	var node: Node = packed.instantiate()
	if node is CardPanel:
		if "kind" in node:
			node.set("kind", kind)
		return node as CardPanel
	if node != null:
		node.free()
	return null


func _packed_scene(kind: StringName) -> PackedScene:
	if _packed.has(kind):
		return _packed[kind]
	var path := CardIds.panel_scene(kind)
	var packed: PackedScene = load(path) as PackedScene if path != "" and ResourceLoader.exists(path) else null
	_packed[kind] = packed
	return packed


func _ui(ev_name: StringName, kind: StringName, show: StringName, side: String) -> void:
	if bus == null:
		return
	var args := {"kind": str(kind), "show": str(show)}
	if side != "":
		args["side"] = side
	bus.ui_event.emit(ev_name, args)
