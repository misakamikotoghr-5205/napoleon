# 格子牌和只读牌的演出。kind slots 与 read。主人 C03。
# 合同：docs/cards/CARDS_INTERFACES.md §7.11.4、§7.11.7。话在对话框里，选项是回话，格子在柜台上。
# 宿主还没 bind_stage 时，自己补上画面控件，这样 W0 的三天试玩仍能把格子走完。
class_name CardSlotPanel
extends CardStagePanel

# C05 的条子面板也继承 CardStagePanel，并用静态表缓存柜台上的场景。
# 格子若先被实例化，Godot 会在退出时留下那张表以及它带上的字体和贴图
# （resources still in use / RID leak）。脚本初始化时先加载条子面板，
# 顺序就和“先打开条子”一样。路径从 W0 起就有，不改 C05 的文件。
const _DemandScript := preload("res://scripts/cards/ui/demand/demand_panel.gd")

var stage_script: Dictionary = {}
var reply_rows: Array = []

var _uid: String = ""
var _read: bool = false
var _phase: String = "idle"
var _closed: bool = false
var _holding: bool = false
var _placed: bool = false
var _rolled: bool = false
var _chose: bool = false
var _success: bool = false
var _heads: int = 0
var _need: int = 0
var _saw_coins: bool = false
var _refresh_queued: bool = false
var _wired: bool = false
var _owned_stage: bool = false
var _owned_hand: bool = false


func _init() -> void:
	if _DemandScript == null:
		push_error("CardSlotPanel: demand script failed to load")


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if bus == null:
		return
	if not bus.coins_tossed.is_connected(_on_coins):
		bus.coins_tossed.connect(_on_coins)
	if not bus.card_left.is_connected(_on_left):
		bus.card_left.connect(_on_left)


func open(args: Dictionary) -> void:
	_uid = str(args.get("uid", ""))
	_read = str(args.get("mode", "")) == "read"
	_phase = "talk"
	_closed = false
	_holding = false
	_placed = false
	_rolled = false
	_chose = false
	_success = false
	_heads = 0
	_need = 0
	_saw_coins = false
	reply_rows = []
	stage_script = {}
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_stage()
	if engine == null or _uid == "":
		return
	var card_view := _card()
	if not card_view.is_empty():
		var view := {}
		var raw = engine.view()
		if typeof(raw) == TYPE_DICTIONARY:
			view = raw
		stage_script = CardStageScript.resolve(card_view, view)
	begin_play(_uid)
	# 换皮 QA 10-25：主线（金色）牌在格子 / 只读演出里，对话框也套金圈（原型 .dlg.gold），和柜台牌一样走 set_header。
	if dialog != null and dialog.has_method("set_header") and bool(card_view.get("gold", false)):
		dialog.call("set_header", {"gold": true})
	if stage_script.is_empty():
		return
	if dialog == null or dialog.is_idle():
		_on_lines_done()


func refresh(_view: Dictionary) -> void:
	if _closed or _uid == "" or _phase == "toss" or _phase == "result":
		return
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_panel.call_deferred()


func autoplay_step() -> bool:
	if _closed or engine == null:
		return false
	if dialog != null and not dialog.is_idle():
		dialog.skip()
		return true
	if _phase == "toss":
		if checks != null:
			checks.skip_coins()
		return true
	if _phase == "result":
		dismiss()
		return true
	if _read:
		on_reply("read")
		return true
	if not _chose:
		var choice := _first_enabled_choice()
		if choice != "":
			on_reply(choice)
			return true
	if _phase == "checks" and not _placed:
		_placed = true
		_auto_place()
		return true
	if _phase == "checks" and not _rolled and _roll_enabled():
		on_reply("roll")
		return true
	dismiss()
	return true


func dismiss() -> void:
	if _closed:
		return
	_closed = true
	_phase = "done"
	if stage != null:
		stage.set_dim_tools(false)
	if dialog != null:
		dialog.set_max_bottom(CardLayout.DIALOG_MAX_BOTTOM)
	end_play()
	close_requested.emit({})


func on_reply(reply_id: String) -> void:
	if _closed or engine == null:
		return
	if _phase == "result" and reply_id == "continue":
		dismiss()
		return
	# Card choices may use the same IDs as read-panel controls (e.g. the
	# postman's "keep" choice on day eight). Route them as card.choose first.
	if not _read:
		for choice in _rows(_card().get("choices", [])):
			if str(choice.get("id", "")) == reply_id:
				_choose(reply_id)
				return
	match reply_id:
		"later":
			dismiss()
		"roll":
			_roll()
		"read":
			engine.send(&"card.read", {"uid": _uid})
			dismiss()
		"keep":
			engine.send(&"card.keep", {"uid": _uid})
		"look":
			engine.send(&"mg.request", {"uid": _uid, "item": ""})
		_:
			_choose(reply_id)


func on_card_played(uid: String, _def_id: String) -> bool:
	if _phase != "checks" or checks == null or not (checks is CardCounterChecks):
		return false
	var source := _source_for(uid)
	if source.is_empty():
		return false
	var slot_id := _slot_accepting(str(source.get("kind", "")))
	if slot_id == "":
		return false
	(checks as CardCounterChecks).offer(slot_id, source)
	return true


func on_hotspot(_id: StringName) -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		dismiss()
		_handled()
	elif key.keycode == KEY_SPACE:
		if _phase == "toss" and checks != null:
			checks.skip_coins()
			_handled()
		elif dialog != null and not dialog.is_idle():
			dialog.skip()
			_handled()
		elif _phase == "result":
			dismiss()
			_handled()


func _ensure_stage() -> void:
	if stage == null:
		stage = _spawn(&"stage", "Stage") as CardStageApi
		_owned_stage = stage != null
	if hand == null:
		hand = _spawn(&"hand_fan", "Hand") as CardHandApi
		_owned_hand = hand != null
	if checks == null:
		checks = _spawn(&"checks", "Checks") as CardChecksApi
	if dialog == null:
		dialog = _spawn(&"dialog", "Dialog") as CardDialogApi
	if _owned_stage and stage != null:
		stage.visible = false
	if _owned_hand and hand != null:
		hand.visible = false
	_wire()


func _spawn(key: StringName, node_name: String) -> Node:
	var path := CardIds.widget_scene(key)
	if path == "":
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var node := packed.instantiate()
	node.name = node_name
	if _has_prop(node, "bus"):
		node.set("bus", bus)
	add_child(node)
	return node


func _wire() -> void:
	if checks is CardCounterChecks:
		(checks as CardCounterChecks).engine = engine
		(checks as CardCounterChecks).bus = bus
	if _wired:
		return
	_wired = true
	if dialog != null:
		if not dialog.lines_done.is_connected(_on_lines_done):
			dialog.lines_done.connect(_on_lines_done)
		# Shared root dialog: the root forwards reply_chosen → on_reply.
		if not _host_routes_replies() and not dialog.reply_chosen.is_connected(on_reply):
			dialog.reply_chosen.connect(on_reply)
	if checks != null:
		if not checks.changed.is_connected(_on_checks_changed):
			checks.changed.connect(_on_checks_changed)
		if not checks.coins_finished.is_connected(_on_coins_finished):
			checks.coins_finished.connect(_on_coins_finished)


## True when the host (C01 root) already forwards this dialog's reply_chosen
## to on_reply. Then subscribing here too would send every reply twice.
func _host_routes_replies() -> bool:
	return dialog != null and has_meta(&"host_reply_dialog") \
		and int(get_meta(&"host_reply_dialog")) == dialog.get_instance_id()


func _on_lines_done() -> void:
	if _phase == "toss" or _phase == "result" or _phase == "done" or _closed:
		return
	if _read:
		_phase = "talk"
		_apply(_read_rows())
		return
	var choices := _rows(_card().get("choices", []))
	if choices.is_empty() and _has_slots():
		_enter_checks()
		return
	_phase = "talk"
	_apply(_choice_rows(choices))


func _enter_checks() -> void:
	_phase = "checks"
	if checks != null:
		checks.show_checks(_uid)
	if hand != null:
		hand.set_low(true)
	if stage != null:
		stage.set_dim_tools(true)
	if dialog != null:
		dialog.set_max_bottom(404)
	_apply(_roll_rows())


func _choose(choice_id: String) -> void:
	if choice_id == "" or _chose:
		return
	_chose = true
	var result := engine.send(&"card.choose", {"uid": _uid, "choice": choice_id})
	if bool(result.get("needs_slots", false)):
		_enter_checks()
		return
	_phase = "talk"
	_show_lines(CardStageScript.lines(stage_script, choice_id))


func _roll() -> void:
	if _rolled or not _roll_enabled():
		return
	_rolled = true
	_holding = true
	_phase = "toss"
	_saw_coins = false
	var result := engine.send(&"slot.roll", {"uid": _uid})
	if _saw_coins or not bool(result.get("ok", false)):
		return
	_on_coins(_uid, _rows(result.get("faces", [])), int(result.get("need", 0)), bool(result.get("success", false)))


func _on_coins(uid: String, faces: Array, need: int, success: bool) -> void:
	if str(uid) != _uid:
		return
	_saw_coins = true
	_holding = true
	_success = success
	_need = need
	_heads = 0
	for face in faces:
		if bool(face):
			_heads += 1
	_phase = "toss"
	if checks != null:
		checks.play_coins(faces, need)


func _on_coins_finished(_success: bool) -> void:
	if _phase != "toss" and _phase != "result":
		return
	_phase = "result"
	var key := "success" if _success else "fail"
	var lines: Array = [{
		"kind": "sys", "who": "", "ref": "c03.sys.roll",
		"args": {"heads": _heads, "need": _need}, "opt": false,
	}]
	lines.append_array(CardStageScript.lines(stage_script, key))
	_show_lines(lines)
	# Acceptance 4: the coins are spent, so the dead roll reply goes; "go on" closes the stage (Space / Esc still do).
	_apply([{
		"id": "continue", "ref": "c03.btn.continue", "args": {}, "enabled": true,
		"reason_ref": "", "style": "choice", "anchor": "", "echo": false,
	}])


func _on_left(uid: String, _reason: StringName) -> void:
	if str(uid) != _uid or _closed:
		return
	if _holding or _phase == "toss" or _phase == "result":
		return
	dismiss()


func _on_checks_changed() -> void:
	if _phase != "checks" or _closed:
		return
	_apply(_roll_rows())


func _refresh_panel() -> void:
	_refresh_queued = false
	if _closed or _phase != "checks" or checks == null:
		return
	checks.show_checks(_uid)
	_apply(_roll_rows())


func _show_lines(lines: Array) -> void:
	if dialog == null or lines.is_empty():
		return
	dialog.show_lines(_uid, lines, true)


func _apply(rows: Array) -> void:
	reply_rows = rows.duplicate(true)
	if dialog != null:
		dialog.set_replies(reply_rows)


func _choice_rows(choices: Array) -> Array:
	var rows: Array = []
	var def_id := str(stage_script.get("def", _card().get("def", "")))
	for i in choices.size():
		var choice: Dictionary = choices[i]
		var id := str(choice.get("id", ""))
		var ref := "%s#choices.%s" % [def_id, id]
		if id == "scare":
			ref = "k18.reply.scare"
		rows.append({
			"id": id,
			"ref": ref,
			"args": {},
			"enabled": bool(choice.get("enabled", true)),
			"reason_ref": str(choice.get("reason_key", "")),
			"style": "choice",
			"anchor": "a.slots.choices" if i == 0 else "",
			"echo": true,
		})
	rows.append(_later_row())
	return rows


func _read_rows() -> Array:
	var card_view := _card()
	var rows: Array = [{
		"id": "read", "ref": "c03.reply.read", "args": {}, "enabled": true,
		"reason_ref": "", "style": "choice", "anchor": "a.slots.choices", "echo": false,
	}]
	if bool(card_view.get("keepable", false)):
		rows.append({
			"id": "keep", "ref": "c03.reply.keep", "args": {}, "enabled": true,
			"reason_ref": "", "style": "choice", "anchor": "", "echo": false,
		})
	if str(card_view.get("minigame", "")) != "":
		rows.append({
			"id": "look", "ref": "c03.reply.look", "args": {}, "enabled": true,
			"reason_ref": "", "style": "look", "anchor": "", "echo": false,
		})
	rows.append(_later_row())
	return rows


func _roll_rows() -> Array:
	var info := checks.preview() if checks != null else {}
	var auto_pass := bool(info.get("auto_pass", false))
	return [{
		"id": "roll",
		"ref": "c03.coins.auto_pass" if auto_pass else "c03.reply.roll",
		"args": {"n": int(info.get("coins", 0)), "m": int(info.get("need", 0))},
		"enabled": _roll_enabled(),
		"reason_ref": "c03.err.slot_required" if _required_blocked() else "",
		"style": "roll",
		"anchor": "a.slots.roll",
		"echo": false,
	}]


func _later_row() -> Dictionary:
	return {
		"id": "later", "ref": "c03.reply.later", "args": {}, "enabled": true,
		"reason_ref": "", "style": "later", "anchor": "", "echo": false,
	}


func _roll_enabled() -> bool:
	if _required_blocked():
		return false
	if checks == null:
		return false
	var info := checks.preview()
	if info.has("ready") and not bool(info.get("ready", false)):
		return false
	return true


func _required_blocked() -> bool:
	for slot in _rows(_slots_query().get("slots", [])):
		if bool(slot.get("required", false)) and _rows(slot.get("placed", [])).is_empty():
			return true
	return false


func _has_slots() -> bool:
	return not _rows(_slots_query().get("slots", [])).is_empty()


func _auto_place() -> void:
	if not (checks is CardCounterChecks):
		return
	var board := checks as CardCounterChecks
	var self_slot := _slot_accepting("self")
	if self_slot != "":
		board.offer(self_slot, {"kind": "self"})
	var money_slot := _slot_accepting("money")
	if money_slot != "":
		board.offer(money_slot, {"kind": "money", "amount": 20})


func _slot_accepting(kind: String) -> String:
	for slot in _rows(_slots_query().get("slots", [])):
		var accepts := _rows(slot.get("accepts", []))
		if accepts.has(kind):
			return str(slot.get("id", ""))
	return ""


func _source_for(uid: String) -> Dictionary:
	var raw = engine.view() if engine != null else {}
	var view: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var self_view: Dictionary = view.get("self", {}) if typeof(view.get("self")) == TYPE_DICTIONARY else {}
	if str(self_view.get("uid", "")) == uid:
		return {"kind": "self"}
	for row in _rows(view.get("contacts", [])):
		if str(row.get("uid", "")) == uid:
			return {"kind": "contact", "uid": uid}
	for row in _rows(view.get("kept", [])):
		if str(row.get("uid", "")) == uid:
			return {"kind": "kept", "uid": uid}
	for row in _rows(view.get("hand", [])):
		if str(row.get("uid", "")) == uid and str(row.get("type", "")) == "news":
			return {"kind": "news", "uid": uid}
	return {}


func _first_enabled_choice() -> String:
	for row in reply_rows:
		if str(row.get("style", "")) == "choice" and bool(row.get("enabled", false)):
			return str(row.get("id", ""))
	return ""


func _card() -> Dictionary:
	if engine == null or _uid == "":
		return {}
	var result = engine.query(&"card", {"uid": _uid})
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _slots_query() -> Dictionary:
	if engine == null or _uid == "":
		return {}
	var result = engine.query(&"slots", {"uid": _uid})
	return result if typeof(result) == TYPE_DICTIONARY else {}


func _rows(raw) -> Array:
	return raw if typeof(raw) == TYPE_ARRAY else []


func _has_prop(node: Object, prop: String) -> bool:
	for row in node.get_property_list():
		if str(row.get("name", "")) == prop:
			return true
	return false


func _handled() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
