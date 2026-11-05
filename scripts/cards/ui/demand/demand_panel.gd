# 条子那一出：胡二站柜台前，条子拍在柜台中间，办法是回话，格子在柜台上。
# 主人 C05。合同：docs/cards/CARDS_INTERFACES.md §3.3 C05、§7.8、§7.11.4。
# 对话框、柜台格子、场景层由宿主 bind_stage 注入；还没有时用 CardIds.widget_scene() 的桩，整棵只建一次。
# open() 不再重建节点。锚点 a.demand.modes / a.demand.delay 写在回话上；a.demand.tier 用柜台中间道具的矩形。
class_name CardDemandPanel
extends CardStagePanel

const Fmt = preload("res://scripts/cards/ui/demand/demand_format.gd")
const TOSS_SCENE := preload("res://scenes/cards/slots/CoinToss.tscn")

static var _packed: Dictionary = {}

var _uid: String = ""
var _script: Dictionary = {}
var _card: Dictionary = {}
var _choice: String = ""
var _choices: Array = []
var _needs_slots: bool = false
var _step: String = "lines"
var _accept_lines: bool = false
var _did_submit: bool = false
var _success: bool = false
var _toss_pending: bool = false
var _wired: bool = false
var _tier_known: bool = false
var _tier_value: int = 0
var _days: int = -1
var _amount: int = -1
var _tried: Dictionary = {}
var _skipped: Dictionary = {}
var _coin_faces: Array = []
var _coin_need: int = 0
var _owns_dialog: bool = false

var _tier_l: Label
var _days_l: Label
var _amount_l: Label
var _away: Label
var _toss: CardCoinTossView


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if bus != null and not bus.coins_tossed.is_connected(_on_coins):
		bus.coins_tossed.connect(_on_coins)
	_bind_owners()


func open(args: Dictionary) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_widgets()
	_bind_owners()
	_reset_run()
	_uid = str(args.get("uid", ""))
	if stage != null and engine != null:
		stage.refresh(engine.view())
	_script = begin_play(_uid)
	_pull_card()
	_apply_meta()
	_place_meta()
	if _kind() == "info" and dialog != null:
		dialog.show_lines(_uid, [_narr("c05.inform.note")], true)
	_accept_lines = true
	if _script.is_empty():
		_step = "empty"
		return
	if dialog == null or dialog.is_idle():
		_offer_choices()


func refresh(view: Dictionary) -> void:
	if not _wired:
		return
	if stage != null:
		stage.refresh(view)
	_apply_row(_find_demand(view))
	_sync_away(view)
	_place_meta()


func autoplay_step() -> bool:
	if _step == "done" or _step == "empty":
		return false
	if _toss_pending:
		if _toss != null and _toss._playing:
			_toss.skip()
		elif checks != null:
			checks.skip_coins()
		_toss_pending = false
		if _did_submit:
			_show_outcome()
		return true
	if dialog != null and not dialog.is_idle():
		dialog.skip()
		return true
	match _step:
		"lines":
			_offer_choices()
			return true
		"choose":
			var id := _pick_choice()
			if id == "":
				if _skipped.has("delay"):
					_finish()
				else:
					on_reply("delay")
					if _step != "close" and _step != "done":
						_skipped["delay"] = true
						_finish()
			else:
				on_reply(id)
			return true
		"place":
			if _place_next():
				return true
			on_reply("submit")
			if _did_submit or _step == "outcome" or _step == "close" or _step == "done":
				return true
			_skip_choice(_choice)
			return true
		"submit":
			on_reply("submit")
			if _did_submit or _step == "outcome" or _step == "close" or _step == "done":
				return true
			_skip_choice(_choice)
			return true
		"close", "outcome":
			_finish()
			return true
	return false


func on_reply(reply_id: String) -> void:
	match reply_id:
		"later":
			_finish()
		"delay":
			_do_delay()
		"submit":
			_do_submit()
		_:
			_do_choose(reply_id)


func dismiss() -> void:
	_finish()


# ---------------- 一次搭好 ----------------
func _ensure_widgets() -> void:
	if stage == null:
		var spawned_stage: CardStageApi = _spawn(&"stage") as CardStageApi
		stage = spawned_stage
	if dialog == null:
		var spawned_dialog: CardDialogApi = _spawn(&"dialog") as CardDialogApi
		dialog = spawned_dialog
		_owns_dialog = true
	if checks == null:
		var spawned_checks: CardChecksApi = _spawn(&"checks") as CardChecksApi
		checks = spawned_checks
	if not _wired:
		_wired = true
		_ensure_meta()
		if dialog != null and not dialog.lines_done.is_connected(_on_lines_done):
			dialog.lines_done.connect(_on_lines_done)
		# Shared C01 dialog: root forwards reply_chosen → play.on_reply.
		# Connect only when this panel spawned its own dialog, else one click
		# would fire card.choose twice.
		if _owns_dialog and dialog != null and not dialog.reply_chosen.is_connected(on_reply):
			dialog.reply_chosen.connect(on_reply)
		if checks != null and not checks.coins_finished.is_connected(_on_coins_finished):
			checks.coins_finished.connect(_on_coins_finished)
		if checks != null and not checks.changed.is_connected(_on_checks_changed):
			checks.changed.connect(_on_checks_changed)


func _spawn(kind: StringName) -> Node:
	if not _packed.has(kind):
		var packed: PackedScene = load(CardIds.widget_scene(kind)) as PackedScene
		_packed[kind] = packed
	var packed_scene: PackedScene = _packed[kind] as PackedScene
	var node: Node = packed_scene.instantiate()
	add_child(node)
	return node


func _bind_owners() -> void:
	for w in [stage, dialog, checks, hand]:
		if w != null and "bus" in w:
			w.bus = bus
	if checks != null and "engine" in checks:
		checks.engine = engine


func _ensure_meta() -> void:
	if _tier_l != null:
		return
	_tier_l = _meta_label("Tier")
	_days_l = _meta_label("Days")
	_amount_l = _meta_label("Amount")
	_amount_l.visible = false
	_away = _meta_label("Away")
	_away.visible = false
	add_child(_tier_l)
	add_child(_days_l)
	add_child(_amount_l)
	add_child(_away)


func _meta_label(node_name: String) -> Label:
	var lab := Label.new()
	lab.name = node_name
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", CardTheme.font_body())
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", CardTheme.color(&"ink"))
	# 换皮 10-22：柜台上那几行墨字垫一小块纸（深色柜台上看得清），宽度跟着字走。
	var paper := CardTheme.paper_card_style()
	paper.content_margin_top = 1.0
	paper.content_margin_bottom = 1.0
	paper.content_margin_left = 8.0
	paper.content_margin_right = 8.0
	lab.add_theme_stylebox_override("normal", paper)
	lab.size = Vector2(96, 28)
	return lab


# ---------------- 开场 ----------------
func _reset_run() -> void:
	_accept_lines = false
	_choice = ""
	_choices = []
	_needs_slots = false
	_step = "lines"
	_did_submit = false
	_success = false
	_toss_pending = false
	_tried = {}
	_skipped = {}
	_script = {}
	_card = {}
	_tier_known = false
	_days = -1
	_amount = -1
	if _amount_l != null:
		_amount_l.visible = false
		_amount_l.text = ""
	if _toss != null:
		_toss.visible = false
	if _away != null:
		_away.visible = false
		_away.text = ""


func _pull_card() -> void:
	_card = {}
	_choices = []
	if engine == null or _uid == "":
		return
	var q = engine.query(&"card", {"uid": _uid})
	if typeof(q) != TYPE_DICTIONARY or not bool(q.get("ok", true)):
		return
	_card = q
	var raw = _card.get("choices", [])
	_choices = raw if typeof(raw) == TYPE_ARRAY else []


func _apply_meta() -> void:
	var meta := _meta(_card)
	if meta.has("tier"):
		_set_tier(true, int(meta["tier"]))
	else:
		_set_tier(false, 0)
	if _card.has("days_left"):
		_set_days(int(_card["days_left"]))
	else:
		_set_days(-1)
	_set_amount(_due(_card))
	_reg_tier()


func _apply_row(row: Dictionary) -> void:
	if row.is_empty():
		return
	var meta := _meta(row)
	if meta.has("tier"):
		_set_tier(true, int(meta["tier"]))
	if row.has("days_left"):
		_set_days(int(row["days_left"]))
	if row.has("amount"):
		_set_amount(_due(row))
	_reg_tier()


func _meta(card: Dictionary) -> Dictionary:
	var block = card.get("demand", {})
	if typeof(block) == TYPE_DICTIONARY:
		return block
	return {}


func _kind() -> String:
	return str(_meta(_card).get("kind", ""))


## 选了办法以后要交的钱会变（讲价降一档、顶替另算）：重新取一次牌，只换掉牌视图，办法列表不动。
func _refresh_amount() -> void:
	var q = engine.query(&"card", {"uid": _uid})
	if typeof(q) == TYPE_DICTIONARY and not (q as Dictionary).is_empty() and bool(q.get("ok", true)):
		_card = q
	_set_amount(_due(_card))


## CardView.amount：按现在的办法要交的钱（G03 出，看得见的数）。没有这个键（旧夹具）是 -1。
func _due(card: Dictionary) -> int:
	var raw = card.get("amount", null)
	if typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		return int(raw)
	return -1


func _on_lines_done() -> void:
	# Host may call begin_play again after open(); that show_lines clears replies.
	# With shared dialog at chars_per_sec 0 the clear is instant — re-offer modes.
	if not _accept_lines or _step == "done" or _step == "empty":
		return
	if _step == "lines":
		_offer_choices()
	elif _step == "choose" and (dialog == null or not dialog.has_replies()):
		_offer_choices()


func _offer_choices() -> void:
	if dialog == null or _step == "done" or _step == "empty":
		return
	_step = "choose"
	var replies: Array = []
	var first := true
	for ch in _choices:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var id := str(ch.get("id", ""))
		if id == "":
			continue
		var anchor := "a.demand.modes" if first else ""
		first = false
		replies.append(_reply(id, "c05.mode." + id, bool(ch.get("enabled", false)),
				str(ch.get("reason_key", "")), "choice", anchor))
	replies.append(_reply("delay", "c05.reply.delay", true, "", "choice", "a.demand.delay"))
	replies.append(_reply("later", "c05.reply.later", true, "", "later", ""))
	dialog.set_replies(replies)
	_set_checks_chrome(false)


func _offer_submit() -> void:
	if dialog == null:
		return
	var submit := _reply("submit", "c05.reply.submit", true, "", "choice", "")
	if _amount > 0:
		# 对话框把不在字里的数补在回话后面：交上去 60。
		submit["args"] = {"n": _amount}
	dialog.set_replies([
		submit,
		_reply("delay", "c05.reply.delay", true, "", "choice", "a.demand.delay"),
		_reply("later", "c05.reply.later", true, "", "later", ""),
	])


func _reply(id: String, ref: String, enabled: bool, reason: String, style: String, anchor: String) -> Dictionary:
	return {
		"id": id, "ref": ref, "args": {}, "enabled": enabled, "reason_ref": reason,
		"style": style, "anchor": anchor, "echo": true,
	}


# ---------------- 办法、格子、交、拖 ----------------
func _do_choose(id: String) -> void:
	if engine == null or _uid == "":
		return
	var row := _choice_row(id)
	if not row.is_empty() and not bool(row.get("enabled", false)):
		return
	_tried = {}
	var result := engine.send(&"card.choose", {"uid": _uid, "choice": id})
	_choice = id
	if bool(result.get("ok", false)):
		_refresh_amount()
	_needs_slots = bool(result.get("needs_slots", false))
	if _needs_slots:
		_show_slots()
		_step = "place"
	else:
		_step = "submit"
	_offer_submit()
	if id == "inform" and dialog != null:
		dialog.show_lines(_uid, [_narr("c05.inform.note")], true)


func _show_slots() -> void:
	if checks != null:
		checks.show_checks(_uid)
	if hand != null:
		hand.set_low(true)
	if stage != null:
		stage.set_dim_tools(true)
	if dialog != null:
		dialog.set_max_bottom(CardLayout.DIALOG_CHECKS_BOTTOM)
	_set_checks_chrome(true)


func _set_checks_chrome(on: bool) -> void:
	if not on:
		if checks != null and checks.is_shown():
			checks.hide_checks()
		if hand != null:
			hand.set_low(false)
		if stage != null:
			stage.set_dim_tools(false)
		if dialog != null:
			dialog.set_max_bottom(CardLayout.DIALOG_MAX_BOTTOM)


func _do_submit() -> void:
	if engine == null or _uid == "" or _did_submit:
		return
	_toss_pending = false
	var result := engine.send(&"demand.submit", {"uid": _uid})
	if not bool(result.get("ok", false)):
		return
	_did_submit = true
	_success = bool(result.get("success", false))
	if not _toss_pending:
		_show_outcome()


func _do_delay() -> void:
	if engine == null or _uid == "":
		return
	var result := engine.send(&"demand.delay", {"uid": _uid})
	if not bool(result.get("ok", false)):
		return
	if result.has("days_left"):
		_set_days(int(result["days_left"]))
	if result.has("tier"):
		_set_tier(true, int(result["tier"]))
	_reg_tier()
	if dialog != null:
		var lines := CardStageScript.lines(_script, "delay")
		lines.append(_narr("c05.delay.note"))
		dialog.show_lines(_uid, lines, true)
	_step = "close"


func _show_outcome() -> void:
	if _step == "done":
		return
	_step = "outcome"
	if dialog == null or _script.is_empty():
		return
	var key := "success" if _success else "fail"
	dialog.show_lines(_uid, CardStageScript.lines(_script, key), true)


func _on_coins(uid: String, faces: Array, need: int, _success: bool) -> void:
	if uid != _uid:
		return
	_toss_pending = true
	_coin_faces = faces.duplicate()
	_coin_need = need
	if checks == null:
		_ensure_toss()
		_toss.visible = true
		_toss.play(faces, need)
	if checks != null:
		checks.play_coins(faces, need)


func _on_coins_finished(_ok: bool) -> void:
	if _toss != null and _toss._playing:
		return
	_toss_pending = false
	if _did_submit:
		_show_outcome()


func _on_toss_finished() -> void:
	_toss_pending = false
	if _did_submit:
		_show_outcome()


func _on_checks_changed() -> void:
	if engine != null:
		_sync_away(engine.view())


func _ensure_toss() -> void:
	if _toss != null:
		return
	_toss = TOSS_SCENE.instantiate() as CardCoinTossView
	_toss.name = "CoinToss"
	_toss.visible = false
	_toss.finished.connect(_on_toss_finished)
	add_child(_toss)


func _finish() -> void:
	if _step == "done":
		return
	_step = "done"
	_set_checks_chrome(false)
	end_play()
	close_requested.emit({})


# ---------------- 日子、档位、不在的人 ----------------
func _set_tier(known: bool, tier: int) -> void:
	_tier_known = known
	_tier_value = tier
	if _tier_l == null:
		return
	_tier_l.visible = known
	_tier_l.text = Fmt.tier_line(tier) if known else ""
	_paint(_tier_l, "c05.tier.%d" % tier if known else "")


func _set_days(n: int) -> void:
	_days = n
	if _days_l == null:
		return
	_days_l.visible = n >= 0
	_days_l.text = Fmt.days_line(n)
	_paint_danger()


func _set_amount(n: int) -> void:
	_amount = n
	if _amount_l == null:
		return
	_amount_l.visible = n > 0
	_amount_l.text = Fmt.amount_line(n)


func _paint(lab: Label, ref: String) -> void:
	if lab == null:
		return
	var draft := ref != "" and CardText.is_draft(ref)
	var danger := Fmt.days_danger(_days)
	var key := &"danger" if danger else (&"ink_soft" if draft else &"ink")
	lab.add_theme_color_override("font_color", CardTheme.color(key))


func _paint_danger() -> void:
	if _days_l != null and _days_l.visible:
		var danger := Fmt.days_danger(_days)
		_days_l.add_theme_color_override("font_color", CardTheme.color(&"danger" if danger else &"ink"))
	if _tier_l != null and _tier_l.visible:
		_paint(_tier_l, "c05.tier.%d" % _tier_value)


func _place_meta() -> void:
	if _tier_l == null:
		return
	var r := _tier_rect()
	_tier_l.position = r.position
	_days_l.position = r.position + Vector2(r.size.x + 8.0, 0)
	_amount_l.position = _days_l.position + Vector2(0, _days_l.size.y + 2.0)
	_away.position = r.position + Vector2(0, r.size.y + 4.0)


func _reg_tier() -> void:
	if _tier_l == null:
		return
	if _tier_l.visible:
		CardAnchors.register(&"a.demand.tier", _tier_l, _tier_rect)
	else:
		CardAnchors.unregister(&"a.demand.tier", _tier_l)


func _tier_rect() -> Rect2:
	var base := CardArt.base_size("prop.notice")
	if base == Vector2i.ZERO:
		base = Vector2i(16, 16)
	var r := CardLayout.prop_rect(&"counter_mid", base)
	if r.has_area():
		return r
	return Rect2(560, 400, 64, 48)


func _find_demand(view: Dictionary) -> Dictionary:
	var rows = view.get("demands", [])
	if typeof(rows) != TYPE_ARRAY:
		return {}
	for d in rows:
		if typeof(d) == TYPE_DICTIONARY and str(d.get("uid", "")) == _uid:
			return d
	return {}


func _sync_away(view: Dictionary) -> void:
	if _away == null:
		return
	var nums := PackedStringArray()
	var self_v = view.get("self", {})
	if typeof(self_v) == TYPE_DICTIONARY:
		_push_away(nums, int(self_v.get("away_days", 0)))
	var contacts = view.get("contacts", [])
	if typeof(contacts) == TYPE_ARRAY:
		for c in contacts:
			if typeof(c) == TYPE_DICTIONARY:
				_push_away(nums, int(c.get("away_days", 0)))
	_push_away(nums, int(_card.get("away_days", 0)))
	_away.text = " ".join(nums)
	_away.visible = not nums.is_empty()


func _push_away(nums: PackedStringArray, n: int) -> void:
	if n <= 0:
		return
	var s := str(n)
	if not nums.has(s):
		nums.append(s)


func _choice_row(id: String) -> Dictionary:
	for ch in _choices:
		if typeof(ch) == TYPE_DICTIONARY and str(ch.get("id", "")) == id:
			return ch
	return {}


func _narr(ref: String) -> Dictionary:
	return {"kind": "narr", "who": "", "ref": ref, "args": {}, "opt": false}


# ---------------- 自动放格子 ----------------
func _place_next() -> bool:
	if engine == null:
		return false
	for s in _target_slots(_query_slots()):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var sid := str(s.get("id", ""))
		if _tried.has(sid):
			continue
		_tried[sid] = true
		if _slot_filled(s):
			continue
		var src := _source_for(s)
		if src.is_empty():
			continue
		var result := engine.send(&"slot.place", {"uid": _uid, "slot": sid, "source": src})
		if bool(result.get("ok", false)):
			if checks != null:
				checks.show_checks(_uid)
			_sync_away(engine.view())
			return true
	return false


func _slot_filled(s: Dictionary) -> bool:
	var cur: Array = s.get("placed", []) if typeof(s.get("placed")) == TYPE_ARRAY else []
	return not cur.is_empty()


func _target_slots(slots: Array) -> Array:
	var marked: Array = []
	var moneyish: Array = []
	for s in slots:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		if bool(s.get("pay", false)):
			marked.append(s)
		var acc: Array = s.get("accepts", []) if typeof(s.get("accepts")) == TYPE_ARRAY else []
		if acc.has("money") or acc.has("item"):
			moneyish.append(s)
	if _choice == "pay" and not marked.is_empty():
		return marked
	if _choice == "pay" and not moneyish.is_empty():
		return moneyish
	return slots


func _query_slots() -> Array:
	if engine == null:
		return []
	var q = engine.query(&"slots", {"uid": _uid})
	if typeof(q) == TYPE_DICTIONARY and typeof(q.get("slots")) == TYPE_ARRAY:
		return q["slots"]
	return []


func _source_for(slot: Dictionary) -> Dictionary:
	var view := engine.view()
	var acc: Array = slot.get("accepts", []) if typeof(slot.get("accepts")) == TYPE_ARRAY else []
	for kind in acc:
		var src := _one_source(str(kind), slot, view)
		if not src.is_empty():
			return src
	return {}


func _one_source(kind: String, slot: Dictionary, view: Dictionary) -> Dictionary:
	match kind:
		"money":
			var amt := int(view.get("money", {}).get("amount", 0))
			if _amount > 0:
				# 只放这一办法要交的钱，不把现钱全压上（和 G06 自动玩一样）。
				amt = mini(amt, _amount)
			elif slot.has("amount"):
				amt = int(slot["amount"])
			return {"kind": "money", "amount": amt}
		"item":
			var items := _stock_items()
			if items.is_empty() or typeof(items[0]) != TYPE_DICTIONARY:
				return {}
			return {"kind": "item", "item": str(items[0].get("item", ""))}
		"self":
			var sv = view.get("self", {})
			if typeof(sv) != TYPE_DICTIONARY or sv.is_empty():
				return {}
			return {"kind": "self"}
		"contact":
			return _first_card(view.get("contacts", []), "contact")
		"kept":
			return _first_card(view.get("kept", []), "kept")
		"news":
			return _first_news(view)
		_:
			return {}


func _first_card(cards, kind: String) -> Dictionary:
	if typeof(cards) != TYPE_ARRAY:
		return {}
	for c in cards:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var uid := str(c.get("uid", ""))
		if uid == "":
			continue
		return {"kind": kind, "uid": uid}
	return {}


func _first_news(view: Dictionary) -> Dictionary:
	for zone in ["hand", "kept"]:
		var cards = view.get(zone, [])
		if typeof(cards) != TYPE_ARRAY:
			continue
		for c in cards:
			if typeof(c) != TYPE_DICTIONARY or str(c.get("type", "")) != "news":
				continue
			var uid := str(c.get("uid", ""))
			if uid == "":
				continue
			return {"kind": "news", "uid": uid}
	return {}


func _stock_items() -> Array:
	if engine == null:
		return []
	var q = engine.query(&"stock", {})
	if typeof(q) == TYPE_ARRAY:
		return q
	if typeof(q) == TYPE_DICTIONARY and typeof(q.get("items")) == TYPE_ARRAY:
		return q["items"]
	return []


func _pick_choice() -> String:
	var enabled := {}
	var order: Array = []
	for ch in _choices:
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var id := str(ch.get("id", ""))
		order.append(id)
		if bool(ch.get("enabled", false)):
			enabled[id] = true
	if enabled.has("pay") and not _skipped.has("pay"):
		return "pay"
	if enabled.has("substitute") and not _skipped.has("substitute"):
		return "substitute"
	for id in order:
		if enabled.has(id) and not _skipped.has(str(id)):
			return str(id)
	return ""


func _skip_choice(id: String) -> void:
	if id != "":
		_skipped[id] = true
	_tried = {}
	_choice = ""
	_needs_slots = false
	_step = "choose"
	_offer_choices()


# ---------------- 键盘：Tab 选回话，Enter 确认，D 拖一拖，Esc 关 ----------------
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not is_visible_in_tree() or not _is_top():
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var handled := true
	match key.keycode:
		KEY_TAB:
			_cycle(key.shift_pressed)
		KEY_ENTER, KEY_KP_ENTER:
			_confirm_enter()
		KEY_D:
			on_reply("delay")
		KEY_ESCAPE:
			dismiss()
		_:
			handled = false
	if handled and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _is_top() -> bool:
	var host := get_parent()
	if host is CardModalHost:
		return host.top_panel() == self
	return true


func _cycle(back: bool) -> void:
	var btns := _enabled_replies()
	if btns.is_empty() or get_viewport() == null:
		return
	var i := btns.find(get_viewport().gui_get_focus_owner())
	if i < 0:
		i = (btns.size() - 1) if back else 0
	elif back:
		i = (i - 1 + btns.size()) % btns.size()
	else:
		i = (i + 1) % btns.size()
	(btns[i] as Control).grab_focus()


func _confirm_enter() -> void:
	if _toss_pending:
		if _toss != null and _toss._playing:
			_toss.skip()
		elif checks != null:
			checks.skip_coins()
		return
	var btn := _focused_reply()
	if btn == null:
		var btns := _enabled_replies()
		btn = btns[0] if not btns.is_empty() else null
	if btn != null:
		btn.pressed.emit()


func _focused_reply() -> Button:
	if get_viewport() == null or dialog == null:
		return null
	var cur := get_viewport().gui_get_focus_owner()
	if cur is Button and dialog.is_ancestor_of(cur):
		return cur as Button
	return null


func _enabled_replies() -> Array:
	var out: Array = []
	if dialog == null:
		return out
	for c in dialog.find_children("*", "Button", true, false):
		if c is Button and not (c as Button).disabled and str(c.text) != CardText.ui("w0.dialog.skip"):
			out.append(c)
	return out
