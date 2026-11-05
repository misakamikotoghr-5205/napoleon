# Prison scene: dialog lines, a reply that puts slots on the counter, then the coin toss.
# Failure text is spoken, then the panel closes. It never sends game.* and does not decide game over.
# Owner C11. Extends CardStagePanel. Anchor a.prison.slots is the counter slots (rect_fn).
# Dialog and checks are the W0 stubs until C04 / C03 land (CardIds.widget_scene).
# TODO(design): guide teacher for prison stays "" (contract §7.10.10 conflict c).
# b39: once the slots are out, the roll reply reads like the counter's (c03.reply.roll: coins on the counter and
# heads needed, or c03.coins.auto_pass) and is redrawn whenever the slots change; a refused roll shows its reason.
class_name CardPrisonPanel
extends CardStagePanel

const KIND := &"prison"

var _args: Dictionary = {}
var _uid := ""
var _script: Dictionary = {}
var _phase := "intro"
var _rolled := false
var _closed := false
var _success := false
var _faces: Array = []
var _need := 0
var _placed: Dictionary = {}
var _arm_after := false
## The replies last handed to the dialog (tests and the guide read them; same idea as CardSlotPanel.reply_rows).
var reply_rows: Array = []

# C05 keeps stage, dialog and checks PackedScenes in a static dictionary.
# This panel is a second CardStagePanel. Godot 4.7 then keeps that cache, and
# the scripts it pins, alive at exit (W0_next_day: 135 resources). The modal
# host already queue_frees this node. A compiled read of _release_armed in this
# file leaks card_state.gd / card_db.gd in runs that never open the demand panel,
# so that read is appended only after the demand script is already cached.
static var _release_armed := false


func _enter_tree() -> void:
	if not ResourceLoader.has_cached(_sibling_script_path()):
		return
	if not tree_exited.is_connected(_arm_after_free):
		tree_exited.connect(_arm_after_free, CONNECT_ONE_SHOT)


func _arm_after_free() -> void:
	# Reload is refused while a panel instance exists, so wait until this one is gone.
	var root := "res://scripts/cards/ui/ladder/"
	var part := "scene_cache"
	load(root + part + "_release.gd").arm.call_deferred()


static func _sibling_script_path() -> String:
	var root := "res://scripts/cards/ui/"
	var part := "demand"
	return root + part + "/" + part + "_panel.gd"

func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_uid = str(args.get("uid", ""))
	_script = {}
	_phase = "intro"
	_rolled = false
	_closed = false
	_success = false
	_faces = []
	_need = 0
	_placed = {}
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wire()
	_register_slots_anchor()
	if engine == null or _uid == "":
		return
	_script = begin_play(_uid)


## The host plays the card once more right after open() (CardModalHost.open_panel), which restarts the dialog:
## the days line and the resting-relics line are said with every start, so they survive that restart.
func begin_play(uid: String) -> Dictionary:
	var script := super(uid)
	_say_days()
	_say_relics_rest()
	return script


func refresh(_view: Dictionary) -> void:
	if _closed or _phase != "checks":
		return
	_register_slots_anchor()


## Skip unfinished lines, take the try reply, place 40 and the first contact, roll, then close.
func autoplay_step() -> bool:
	if _closed or engine == null:
		return false
	if dialog != null and not dialog.is_idle():
		dialog.skip()
		return true
	if _phase == "intro" or _phase == "choose":
		on_reply("try")
		return not _closed
	if _phase == "checks" and not _rolled:
		var money_slot := _open_slot("money")
		if money_slot != "":
			return _send_place(money_slot, {"kind": "money", "amount": 40})
		var contact_slot := _open_slot("contact")
		var contacts := _zone("contacts")
		if contact_slot != "" and not contacts.is_empty():
			var who := str((contacts[0] as Dictionary).get("uid", ""))
			return _send_place(contact_slot, {"kind": "contact", "uid": who})
		on_reply("roll")
		return true
	if _phase == "rolling":
		if checks != null:
			checks.skip_coins()
		return true
	if _phase == "after":
		_request_close()
		return true
	return false


## "Leave it": close the scene and send no command. The card stays in hand.
func dismiss() -> void:
	_request_close()


func on_reply(reply_id: String) -> void:
	if _closed:
		return
	if reply_id == "later":
		dismiss()
		return
	if reply_id == "try":
		_enter_checks()
		return
	if reply_id == "roll":
		_roll()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		dismiss()
		_eat()
	elif key.keycode == KEY_SPACE and _phase == "rolling" and checks != null:
		checks.skip_coins()
		_eat()


func _wire() -> void:
	_arm(dialog, "bus", bus)
	_arm(checks, "engine", engine)
	_arm(checks, "bus", bus)
	if dialog != null and not dialog.lines_done.is_connected(_on_lines_done):
		dialog.lines_done.connect(_on_lines_done)
	# Shared root dialog: the root forwards reply_chosen → on_reply.
	if dialog != null and not _host_routes_replies() and not dialog.reply_chosen.is_connected(on_reply):
		dialog.reply_chosen.connect(on_reply)
	if checks != null and not checks.coins_finished.is_connected(_on_coins_finished):
		checks.coins_finished.connect(_on_coins_finished)
	if checks != null and not checks.changed.is_connected(_on_checks_changed):
		checks.changed.connect(_on_checks_changed)


func _on_checks_changed() -> void:
	if _closed or _phase != "checks":
		return
	_set_replies(true)


## True when the host (C01 root) already forwards this dialog's reply_chosen
## to on_reply. Then subscribing here too would send every reply twice.
func _host_routes_replies() -> bool:
	return dialog != null and has_meta(&"host_reply_dialog") \
		and int(get_meta(&"host_reply_dialog")) == dialog.get_instance_id()


func _arm(node: Object, prop: String, value: Variant) -> void:
	if node != null and node.get(prop) == null:
		node.set(prop, value)


func _on_lines_done() -> void:
	if _closed:
		return
	if _phase == "intro":
		_phase = "choose"
		_set_replies(false)
	elif _phase == "after" and not _arm_after:
		_request_close()


func _say_days() -> void:
	var nights := _days_left()
	if nights < 0 or dialog == null or _uid == "":
		return
	dialog.show_lines(_uid, [{
		"kind": "sys", "who": "", "ref": "c11.prison.days",
		"args": {"n": nights}, "opt": false,
	}], true)


## Rogue v1: relics on the curio shelf rest while the player is jailed, and the shelf is not in this scene.
func _say_relics_rest() -> void:
	if dialog == null or _uid == "" or engine == null:
		return
	var relics = engine.view().get("relics", {})
	if typeof(relics) != TYPE_DICTIONARY or not bool(relics.get("dormant", false)) or int(relics.get("count", 0)) <= 0:
		return
	dialog.show_lines(_uid, [{"kind": "sys", "who": "", "ref": "rg4.relics.away", "args": {}, "opt": false}], true)


func _days_left() -> int:
	if engine == null or _uid == "":
		return -1
	var cv := engine.query(&"card", {"uid": _uid})
	if cv.has("days_left"):
		return int(cv["days_left"])
	var hand: Variant = engine.view().get("hand", [])
	if typeof(hand) != TYPE_ARRAY:
		return -1
	for row in hand:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str(row.get("uid", "")) == _uid and row.has("days_left"):
			return int(row["days_left"])
	return -1


func _enter_checks() -> void:
	if _phase == "checks" or _phase == "rolling" or _phase == "after":
		return
	_phase = "checks"
	_arm(checks, "engine", engine)
	_arm(checks, "bus", bus)
	if checks != null:
		checks.show_checks(_uid)
	if hand != null:
		hand.set_low(true)
	if stage != null:
		stage.set_dim_tools(true)
	if dialog != null:
		dialog.set_max_bottom(CardLayout.DIALOG_CHECKS_BOTTOM)
	_register_slots_anchor()
	_set_replies(true)


func _set_replies(rolling: bool) -> void:
	var rows: Array = []
	if rolling:
		rows.append(_roll_reply())
	else:
		rows.append(_reply("try", "c11.reply.try", "choice"))
	rows.append(_reply("later", "c11.reply.later", "later"))
	reply_rows = rows.duplicate(true)
	if dialog == null:
		return
	dialog.set_replies(rows)


## The roll reply as the counter writes it: "掷铜钱 · n 枚 · 要 m 个正面" from the slots preview (b39).
func _roll_reply() -> Dictionary:
	var info: Dictionary = checks.preview() if checks != null else {}
	if info.is_empty() and engine != null and _uid != "":
		info = engine.query(&"slots", {"uid": _uid})
	var auto := bool(info.get("auto_pass", false))
	var row := _reply("roll", "c03.coins.auto_pass" if auto else "c03.reply.roll", "roll")
	row["args"] = {"n": int(info.get("coins", 0)), "m": int(info.get("need", 0))}
	return row


func _reply(id: String, ref: String, style: String) -> Dictionary:
	return {
		"id": id, "ref": ref, "args": {}, "enabled": true,
		"reason_ref": "", "style": style, "anchor": "", "echo": true,
	}


func _roll() -> void:
	if _closed or _rolled or engine == null or _uid == "":
		return
	_phase = "rolling"
	var result := engine.send(&"slot.roll", {"uid": _uid})
	if not bool(result.get("ok", false)):
		_phase = "checks"
		if checks is CardCounterChecks:
			(checks as CardCounterChecks).show_reason(result)
		return
	_rolled = true
	# G03/G06 slot.roll result: {faces, heads, need, success}. Prefer success;
	# if missing, match ladder settlement: heads >= need (auto_pass already folded in).
	_faces = result.get("faces", []) if typeof(result.get("faces", [])) == TYPE_ARRAY else []
	_need = int(result.get("need", 0))
	var heads := int(result.get("heads", -1))
	if heads < 0:
		heads = 0
		for face in _faces:
			if bool(face):
				heads += 1
	if result.has("success"):
		_success = bool(result["success"])
	else:
		_success = heads >= _need
	if checks != null:
		checks.play_coins(_faces, _need)
		# C03 CounterChecks is async; W0 stub finishes inside play_coins via coins_finished.
	else:
		_show_after()


func _on_coins_finished(_success: bool) -> void:
	if _closed or _phase == "after":
		return
	_show_after()


func _show_after() -> void:
	_phase = "after"
	var key := "success" if _success else "fail"
	if dialog == null or _script.is_empty():
		_request_close()
		return
	_arm_after = true
	dialog.show_lines(_uid, CardStageScript.lines(_script, key), true)
	_arm_after = false
	# The line is on screen for this frame; close once the frame finishes.
	_request_close.call_deferred()


func _send_place(slot_id: String, source: Dictionary) -> bool:
	if engine == null or _uid == "" or _rolled:
		return false
	var result := engine.send(&"slot.place", {"uid": _uid, "slot": slot_id, "source": source})
	if not bool(result.get("ok", false)):
		return false
	_placed[slot_id] = true
	return true


func _open_slot(kind: String) -> String:
	if engine == null or _uid == "":
		return ""
	var q := engine.query(&"slots", {"uid": _uid})
	var rows: Variant = q.get("slots", [])
	if typeof(rows) != TYPE_ARRAY:
		return ""
	for s in rows:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var id := str(s.get("id", ""))
		var accepts: Array = s.get("accepts", [])
		if not accepts.has(kind) or _placed.has(id):
			continue
		var placed: Array = s.get("placed", [])
		if not placed.is_empty():
			continue
		return id
	return ""


func _zone(zone_name: String) -> Array:
	if engine == null:
		return []
	var rows: Variant = engine.view().get(zone_name, [])
	return rows if typeof(rows) == TYPE_ARRAY else []


func _slot_widgets(node: Node) -> Array:
	var out: Array = []
	if node == null:
		return out
	if node is CardSlotWidget:
		out.append(node)
	for child in node.get_children():
		out.append_array(_slot_widgets(child))
	return out


func _register_slots_anchor() -> void:
	CardAnchors.register(&"a.prison.slots", self, _slots_rect)


func _slots_rect() -> Rect2:
	var merged := Rect2()
	var any := false
	if checks != null:
		for node in _slot_widgets(checks):
			var widget := node as Control
			if widget == null or not widget.is_visible_in_tree():
				continue
			var rect := widget.get_global_rect()
			if rect.size == Vector2.ZERO:
				continue
			merged = rect if not any else merged.merge(rect)
			any = true
	if any:
		return merged
	return CardLayout.SLOTS


func _request_close() -> void:
	if _closed:
		return
	_closed = true
	end_play()
	close_requested.emit({})


func _eat() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
