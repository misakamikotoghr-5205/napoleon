# Counter play: guest on the stage, lines in the dialog, every choice is a reply.
# Owner C04. Text from CardText, color from CardTheme, art from CardArt.
# Does not preload the W0 stub. Contract 1.3 section 7.11 and the C04 card.
# Engine talk (open, offer, answer, pick, redeem, choose, refuse, close) stays.
# Anchors while the matching control is on screen:
#   a.counter.item a.counter.look a.counter.tier.* a.counter.reply
#   a.counter.stock (shelf drawer) a.counter.redeem
# Dialog emits dialog_advanced / dialog_skipped / reply_chosen.
# The panel connects dialog.reply_chosen only when the host does not forward it.
# C01 must not connect it a second time or one click would send two commands.
# ticket.status == "sold" means the pledge was sold (value not frozen).
# Reskin 10-23: nothing is written onto the scene any more. The item, its tags (intent, category,
# condition, asking, counter price, ticket figures), the inspect notes and the result line go into
# the dialog through CardDialogBox.set_header(). The shelf opens through the CardModalHost found
# from the root (b17); pick is greyed out with a reason when no shelf piece suits the buyer (b18);
# confirm_key() is the Enter action the root calls when the dialog is idle (b15).
class_name CardCounterPanel
extends CardStagePanel

# C03-style (CardSlotPanel): warm DemandPanel before Counter-first paths
# load Stage/Dialog into its static PackedScene table.
const _DemandScript := preload("res://scripts/cards/ui/demand/demand_panel.gd")

const KIND := &"counter"
const TIERS: Array[String] = ["harsh", "fair", "kind"]
## [shared] 10-25 appraisal Level B: G04 puts g04.counter.lever.<caught|soft|offended> in line_key once.
const LEVER_PREFIX := "g04.counter.lever."

var _uid: String = ""
var _cv: Dictionary = {}
var _card: Dictionary = {}
var _stock: Array = []
var _stock_known: bool = false   # the counter view carried a stock list (old fixtures do not)
var _snap: String = ""
var _phase: String = "talk"
var _result: String = ""
var _ticket_no: int = -1
var _seen_ticket_no: int = -1
var _tried_open: bool = false
var _guide_beat: bool = false
var _looked: bool = false
var _auto_looked: bool = false
var _auto_picked: bool = false
var _did_redeem: bool = false
var _closed: bool = false
var _guest_left: bool = false
var _in_open: bool = false
var _local_send: bool = false
var _wired: bool = false
var _script: Dictionary = {}
var _flash: float = 0.0
var _flash_rect: ColorRect
var _drawer: CardPanel
var _batch: Array = []
var _owned_stage: bool = false
var _owned_dialog: bool = false
var _owned_hand: bool = false
var _owned_checks: bool = false
var _torn: bool = false
var _scare_checks: bool = false
var _scare_rolled: bool = false
var _scare_holding: bool = false
var _scare_success: bool = false
var _scare_heads: int = 0
var _scare_need: int = 0
var _scare_saw_coins: bool = false
## 共享 hand（#42 bind_stage）进入吓唬前的可见性；关闭时恢复，不无条件 visible=false。
var _scare_hand_saved: bool = false
var _scare_hand_was_visible: bool = true


func _init() -> void:
	if _DemandScript == null:
		push_error("CardCounterPanel: demand script failed to load")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_widgets()


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if bus == null:
		return
	_hook(&"view_changed", _on_view_changed)
	_hook(&"card_left", _on_card_left)
	_hook(&"money_changed", _on_money)
	_hook(&"first_time", _on_first)
	_hook(&"command_done", _on_command_done)
	_wire_widgets()


func open(args: Dictionary) -> void:
	_torn = false
	_reset(str(args.get("uid", "")))
	_ensure_widgets()
	_wire_widgets()
	_apply_speed()
	_in_open = true
	_script = begin_play(_uid)
	_pull(true)
	_patch_ask()
	_place_items()
	_show_intro()
	_in_open = false
	if dialog == null or dialog.is_idle():
		_present()
	_sync_extras()


func refresh(_view: Dictionary) -> void:
	if _torn or _uid == "" or _in_open or _local_send:
		return
	_pull(false)
	_place_items()
	if dialog != null and dialog.is_idle():
		_present()
	_sync_extras()


func autoplay_step() -> bool:
	if engine == null or _closed or _torn:
		return false
	if dialog != null and not dialog.is_idle():
		dialog.skip()
	var host := _find_host()
	if host != null:
		var top := host.top_panel()
		if top != null and top != self:
			if not top.autoplay_step():
				host.close_panel(top)
			return true
	if _drawer != null and is_instance_valid(_drawer) and not _drawer.is_queued_for_deletion():
		if _drawer.autoplay_step():
			return true
		_release_drawer()
		return true
	if _scare_checks and _phase == "checks":
		if not _scare_rolled and _scare_roll_enabled():
			on_reply("roll")
			return true
		if checks != null and checks is CardCounterChecks:
			var board := checks as CardCounterChecks
			board.offer("nerve", {"kind": "self"})
			return true
		return true
	if _phase == "leave" or _phase == "settled":
		_finish_close()
		return false
	if not _is_open(_cv):
		var tried := _tried_open
		_pull(true)
		_place_items()
		_show_intro()
		if dialog == null or dialog.is_idle():
			_present()
		if not _is_open(_cv):
			return false
		if _tried_open and not tried:
			return true
	# The table plays the card, and open() sends counter.open, before gd.d1.person
	# is the current step. K16 completes that step on cmd:counter.open / panel:counter,
	# then gd.d1.look needs a.counter.look on screen before mg.request. One more
	# counter.open is idempotent on the scenario mock and lands while person is current.
	# Fixture mocks have no scenario(); a second open would replay their scripted reply.
	if not _guide_beat and _scenario_open():
		_guide_beat = true
		_send(&"counter.open", {"uid": _uid})
		if dialog != null and dialog.is_idle():
			_present()
		return true
	return _auto_act()


func dismiss() -> void:
	if _closed or _torn:
		return
	if not _guest_left and engine != null and _uid != "":
		_send(&"counter.close", {"uid": _uid})
	_finish_close()


func on_reply(reply_id: String) -> void:
	if reply_id == "look":
		_look()
	elif reply_id == "pick":
		_open_shelf()
	elif reply_id == "accept":
		_answer(true)
	elif reply_id == "decline":
		_answer(false)
	elif reply_id == "refuse":
		_refuse()
	elif reply_id == "later":
		dismiss()
	elif reply_id == "send_off":
		_finish_close()
	elif reply_id == "roll":
		_scare_roll()
	elif reply_id.begins_with("tier:"):
		_offer(reply_id.substr(5))
	elif reply_id.begins_with("redeem:"):
		_redeem(reply_id.substr(7))
	elif reply_id.begins_with("choice:"):
		_choose(reply_id.substr(7))


func on_hotspot(id: StringName) -> bool:
	if id == &"magnifier" and _can_look():
		on_reply("look")
		return true
	return false


## Enter with the dialog idle (b15): send off when the guest is done, accept his counter price, else
## offer the fair price. Returns false when Enter has nothing to do here (the root may then play the
## selected hand card). The root's _on_key calls this; _unhandled_input uses it too.
func confirm_key() -> bool:
	if _closed or _torn or engine == null:
		return false
	if dialog != null and not dialog.is_idle():
		return false
	if _phase == "leave" or _phase == "settled":
		on_reply("send_off")
		return true
	if _phase != "talk":
		return false
	# [shared] G04 10-25: a price the shop cannot pay is disabled; Enter then does nothing (the reply says why).
	if str(_cv.get("last_reply", "")) == "counter":
		if str(_cv.get("accept_err", "")) == "":
			on_reply("accept")
		return true
	if _show_tiers():
		if _tier_err("fair") == "":
			on_reply("tier:fair")
		return true
	return false


## Rebuild captions and replies. The timing check calls this after open().
func _render() -> void:
	if not is_inside_tree():
		return
	_place_items()
	if dialog != null and dialog.is_idle():
		_present()
	_sync_extras()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not is_visible_in_tree():
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		dismiss()
		_accept_key()
		return
	if dialog != null and not dialog.is_idle():
		dialog._unhandled_input(event)
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9 and dialog != null:
		dialog._unhandled_input(event)
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		confirm_key()
		_accept_key()


func _process(delta: float) -> void:
	if _flash_rect == null or _flash <= 0.0:
		return
	_flash = maxf(0.0, _flash - delta)
	_flash_rect.modulate = Color(1, 1, 1, _flash)


# ---------------- autoplay ----------------
func _auto_act() -> bool:
	var intent := str(_cv.get("intent", ""))
	if intent == "redeem" and not _did_redeem:
		_did_redeem = true
		on_reply("redeem:by_rule")
		return _phase == "talk" and str(_cv.get("last_reply", "")) == "counter"
	if intent == "buy" and _item() == null:
		# 挑过一次还没东西上柜（引擎没收这一件），再开抽屉也是原样，就不收了。
		if _stock.is_empty() or _auto_picked:
			on_reply("refuse")
			return false
		_auto_picked = true
		on_reply("pick")
		# The shelf now opens in the host's drawer, and the root's autoplay closes an open drawer
		# before it steps the play panel. Pick in the same step, the way the drawer's own
		# autoplay does, so the buyer is served instead of turned away.
		if _drawer != null and is_instance_valid(_drawer) and not _drawer.is_queued_for_deletion():
			_drawer.autoplay_step()
		return true
	if _can_look() and not _auto_looked:
		_auto_looked = true
		on_reply("look")
		return true
	if str(_cv.get("last_reply", "")) == "counter":
		on_reply("accept" if str(_cv.get("accept_err", "")) == "" else "decline")
		return false
	# [shared] G04 10-25: offer only a price the shop can pay; with none left, turn the guest away.
	if _tier_err("fair") == "":
		on_reply("tier:fair")
	elif _tier_err("harsh") == "":
		on_reply("tier:harsh")
	else:
		on_reply("refuse")
		return false
	return _phase == "talk" and str(_cv.get("last_reply", "")) == "counter"


# ---------------- commands ----------------
func _offer(tier: String) -> void:
	if not _show_tiers() or engine == null or _tier_err(tier) != "":
		return
	var before := _sig(_cv)
	var r := _send(&"counter.offer", {"uid": _uid, "tier": tier})
	if _sig(_cv) == before:
		_overlay_reply(r)
	_after_command()


func _answer(accept: bool) -> void:
	if _phase != "talk" or engine == null:
		return
	if str(_cv.get("last_reply", "")) != "counter":
		return
	if accept and str(_cv.get("accept_err", "")) != "":
		return
	var before := _sig(_cv)
	var r := _send(&"counter.answer", {"uid": _uid, "accept": accept})
	if _sig(_cv) == before:
		_overlay_reply(r)
	_after_command()


func _look() -> void:
	if not _can_look() or engine == null:
		return
	_looked = true
	_send(&"mg.request", {"uid": _uid, "item": _item_id()})
	_after_command()


func _redeem(mode: String) -> void:
	if _phase != "talk" or engine == null:
		return
	var before := _sig(_cv)
	var r := _send(&"counter.redeem", {"uid": _uid, "mode": mode})
	if _sig(_cv) == before:
		_overlay_reply(r)
	_after_command()


func _choose(choice_id: String) -> void:
	var row := _choice_row(choice_id)
	if row.is_empty() or not bool(row.get("enabled", true)) or engine == null:
		return
	var r := _send(&"card.choose", {"uid": _uid, "choice": choice_id})
	if bool(r.get("ok", false)) and bool(r.get("needs_slots", false)) and not _guest_left:
		_enter_scare_checks()
		return
	if bool(r.get("ok", false)) and (_guest_left or not bool(r.get("needs_slots", false))):
		_phase = "settled"
	_after_command()


func _refuse() -> void:
	if _phase != "talk" or engine == null:
		return
	var before := _sig(_cv)
	_send(&"counter.refuse", {"uid": _uid})
	if _sig(_cv) == before:
		var def_id := _def()
		if def_id != "":
			_cv["line_key"] = "%s#lines.refused" % def_id
		_cv["last_reply"] = "refused"
	_phase = "leave"
	_after_command()


func _after_command() -> void:
	var key := str(_cv.get("last_reply", ""))
	if key == "accept" or key == "counter" or key == "leave" or key == "refused":
		_show_reaction(key)
	elif dialog == null or dialog.is_idle():
		_present()
	_place_items()
	_sync_extras()


func _exit_tree() -> void:
	_teardown()


func _finish_close() -> void:
	if _torn:
		return
	_set_scare_checks_chrome(false)
	_scare_checks = false
	_closed = true
	_teardown()
	close_requested.emit({})


func _teardown() -> void:
	if _torn:
		return
	_torn = true
	_closed = true
	_release_drawer()
	if stage != null and is_instance_valid(stage):
		CardAnchors.unregister(&"a.counter.item", stage)
	if dialog != null and is_instance_valid(dialog):
		var lab := dialog.find_child("ReplyLine", true, false) as Label
		if lab != null:
			CardAnchors.unregister(&"a.counter.reply", lab)
	end_play()
	_unwire()
	_free_owned()
	if _flash_rect != null and is_instance_valid(_flash_rect):
		if _flash_rect.get_parent() == self:
			remove_child(_flash_rect)
		_flash_rect.queue_free()
		_flash_rect = null
	engine = null
	bus = null


func _unwire() -> void:
	if dialog != null and is_instance_valid(dialog):
		if dialog.reply_chosen.is_connected(on_reply):
			dialog.reply_chosen.disconnect(on_reply)
		if dialog.lines_done.is_connected(_on_lines_done):
			dialog.lines_done.disconnect(_on_lines_done)
		if "bus" in dialog and bool(_owned_dialog):
			dialog.set("bus", null)
	if stage != null and is_instance_valid(stage):
		if stage.hotspot_pressed.is_connected(_on_stage_hotspot):
			stage.hotspot_pressed.disconnect(_on_stage_hotspot)
		if "bus" in stage and bool(_owned_stage):
			stage.set("bus", null)
	if checks != null and is_instance_valid(checks):
		if checks.has_signal("changed") and checks.changed.is_connected(_on_scare_checks_changed):
			checks.changed.disconnect(_on_scare_checks_changed)
		if checks.has_signal("coins_finished") and checks.coins_finished.is_connected(_on_scare_coins_finished):
			checks.coins_finished.disconnect(_on_scare_coins_finished)
	if bus != null and is_instance_valid(bus):
		if bus.coins_tossed.is_connected(_on_scare_coins_tossed):
			bus.coins_tossed.disconnect(_on_scare_coins_tossed)
		for pair in [
			[&"view_changed", _on_view_changed],
			[&"card_left", _on_card_left],
			[&"money_changed", _on_money],
			[&"first_time", _on_first],
			[&"command_done", _on_command_done],
		]:
			var sig: StringName = pair[0]
			var cb: Callable = pair[1]
			if bus.is_connected(sig, cb):
				bus.disconnect(sig, cb)
	_wired = false


func _free_owned() -> void:
	_free_one(dialog if _owned_dialog else null)
	_free_one(stage if _owned_stage else null)
	_free_one(hand if _owned_hand else null)
	_free_one(checks if _owned_checks else null)
	if _owned_dialog:
		dialog = null
		_owned_dialog = false
	if _owned_stage:
		stage = null
		_owned_stage = false
	if _owned_hand:
		hand = null
		_owned_hand = false
	if _owned_checks:
		checks = null
		_owned_checks = false


func _free_one(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if "bus" in node:
		node.set("bus", null)
	if node.get_parent() == self:
		remove_child(node)
	node.queue_free()


func _send(cmd: StringName, args: Dictionary) -> Dictionary:
	_local_send = true
	var r := engine.send(cmd, args)
	_local_send = false
	return r


func _scenario_open() -> bool:
	if engine == null or not _is_open(_cv) or _uid == "":
		return false
	if not engine.has_method("scenario"):
		return false
	return engine.call("scenario") != null


# ---------------- read engine ----------------
func _pull(allow_open: bool) -> void:
	if engine == null or _uid == "":
		return
	var card = engine.query(&"card", {"uid": _uid})
	_card = card if typeof(card) == TYPE_DICTIONARY else {}
	var q = engine.query(&"counter", {"uid": _uid})
	if typeof(q) != TYPE_DICTIONARY:
		q = {}
	_load_stock(q)
	if _is_open(q):
		if _snap != _sig(q):
			_cv = (q as Dictionary).duplicate(true)
			_snap = _sig(q)
			_sync_phase()
		return
	if not allow_open or _tried_open:
		return
	_tried_open = true
	var pre := _sig(q)
	var r := _send(&"counter.open", {"uid": _uid})
	if _is_open(_cv) and _snap != pre:
		return
	if typeof(r) == TYPE_DICTIONARY and _is_open(r):
		_cv = (r as Dictionary).duplicate(true)
		_cv.erase("ok")
		_cv.erase("err")
		_snap = pre
		_load_stock(_cv)
		_sync_phase()


func _load_stock(q: Dictionary) -> void:
	var raw = q.get("stock", _cv.get("stock", null))
	_stock_known = typeof(raw) == TYPE_ARRAY
	if typeof(raw) != TYPE_ARRAY:
		raw = []
	var by_id := {}
	if engine != null:
		var full = engine.query(&"stock", {})
		var items = full.get("items", []) if typeof(full) == TYPE_DICTIONARY else []
		if typeof(items) == TYPE_ARRAY:
			for it in items:
				if typeof(it) == TYPE_DICTIONARY:
					by_id[str(it.get("item", ""))] = it
	_stock = []
	for entry in raw:
		if typeof(entry) == TYPE_DICTIONARY:
			_stock.append(entry)
		elif by_id.has(str(entry)):
			_stock.append(by_id[str(entry)])
		else:
			_stock.append({"item": str(entry)})


func _overlay_reply(r: Dictionary) -> void:
	if typeof(r) != TYPE_DICTIONARY or not bool(r.get("ok", false)) or not r.has("reply"):
		return
	var reply := str(r["reply"])
	_cv["last_reply"] = reply
	if r.has("price"):
		_cv["last_price"] = int(r["price"])
	_cv["round"] = int(_cv.get("round", 0)) + 1
	var def_id := _def()
	var line := str(_cv.get("line_key", ""))
	if def_id != "" and not line.ends_with("#lines." + reply):
		_cv["line_key"] = "%s#lines.%s" % [def_id, reply]
	_sync_phase()


func _sync_phase() -> void:
	var reply := str(_cv.get("last_reply", ""))
	if reply == "leave" or reply == "refused":
		_phase = "leave"
	elif reply == "accept":
		_note_result()
		_phase = "settled"
	elif _phase != "leave" and _phase != "settled":
		_phase = "talk"


func _note_result() -> void:
	var intent := str(_cv.get("intent", ""))
	if intent == "pawn":
		_result = "ticket"
		_take_ticket_no()
	elif intent == "sell":
		_result = "shelved"


func _take_ticket_no() -> void:
	if _seen_ticket_no >= 0:
		_ticket_no = _seen_ticket_no
		return
	var ticket = _cv.get("ticket")
	if typeof(ticket) == TYPE_DICTIONARY and (ticket as Dictionary).has("no"):
		_ticket_no = int(ticket["no"])
		return
	if engine == null:
		return
	var tq = engine.query(&"tickets", {})
	var arr = tq.get("tickets", []) if typeof(tq) == TYPE_DICTIONARY else []
	if typeof(arr) == TYPE_ARRAY and not (arr as Array).is_empty():
		var last = (arr as Array).back()
		if typeof(last) == TYPE_DICTIONARY:
			_ticket_no = int(last.get("no", -1))


# ---------------- stage and dialog ----------------
func _show_intro() -> void:
	if dialog == null:
		return
	var lines := _with_impatient(CardStageScript.lines(_script, "intro"))
	_batch = lines.duplicate(true)
	lines.append_array(_obs_lines(_obs_keys()))
	_batch = lines.duplicate(true)
	dialog.show_lines(_uid, lines, false)
	_mark_reply_anchor()


func _show_reaction(key: String) -> void:
	if dialog == null:
		_present()
		return
	var lines := _patched(CardStageScript.lines(_script, key), key)
	if _impatient():
		lines.append_array(CardStageScript.lines(_script, "impatient"))
	_batch = lines
	dialog.show_lines(_uid, lines, false)
	_mark_reply_anchor()


func _patched(lines: Array, key: String) -> Array:
	if key != "counter":
		return lines
	var price := int(_cv.get("last_price", 0))
	for i in range(lines.size()):
		if typeof(lines[i]) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = lines[i]
		var args: Dictionary = line.get("args", {})
		if typeof(args) != TYPE_DICTIONARY:
			args = {}
		args = args.duplicate(true)
		args["price"] = price
		line["args"] = args
		lines[i] = line
	return lines


func _patch_ask() -> void:
	var asking := int(_cv.get("asking", -1))
	if asking < 0 or _script.is_empty():
		return
	var intro: Array = _script.get("intro", [])
	for i in range(intro.size()):
		if typeof(intro[i]) != TYPE_DICTIONARY:
			continue
		var line: Dictionary = intro[i]
		if not str(line.get("ref", "")).ends_with("#lines.ask"):
			continue
		var args: Dictionary = line.get("args", {})
		if typeof(args) != TYPE_DICTIONARY:
			args = {}
		args = args.duplicate(true)
		args["price"] = asking
		line["args"] = args
		intro[i] = line
	_script["intro"] = intro


func _present() -> void:
	if dialog == null or _closed:
		return
	dialog.set_replies(_replies())
	_mark_reply_anchor()


func _replies() -> Array:
	var out: Array = []
	if not _is_open(_cv):
		if _phase == "leave" or _phase == "settled":
			out.append(_reply("send_off", "c04.btn.send_off", "choice", ""))
		return out
	if _phase == "leave" or _phase == "settled":
		out.append(_reply("send_off", "c04.btn.send_off", "choice", ""))
		return out
	if _scare_checks and _phase == "checks":
		return _scare_roll_rows()
	var intent := str(_cv.get("intent", ""))
	if intent == "buy" and _item() == null:
		var pick := _reply("pick", "c04.reply.pick", "choice", "")
		if _stock_known and _stock.is_empty():
			# b18: nothing on the shelf suits him; do not open an empty drawer.
			pick["enabled"] = false
			pick["reason_ref"] = "c04.reason.shelf_empty"
		out.append(pick)
		_append_scare_replies(out)
		_add_tail(out)
		return out
	if intent == "redeem":
		var first := true
		for mode in _redeem_modes():
			var anchor := "a.counter.redeem" if first else ""
			first = false
			out.append(_reply("redeem:" + mode, "c04.redeem." + mode, "choice", anchor))
		_append_scare_replies(out)
		_add_tail(out)
		return out
	if _can_look():
		out.append(_reply("look", "c04.reply.look", "look", "a.counter.look"))
	if _show_tiers():
		var tiers: Dictionary = _cv.get("tiers", {})
		var dir := "receive" if str(_cv.get("direction", "pay")) == "receive" else "pay"
		for tier in TIERS:
			var why := _tier_err(tier)
			out.append({
				"id": "tier:" + tier,
				"ref": "c04.tier.%s.%s" % [tier, dir],
				"args": {"n": int(tiers.get(tier, 0))},
				"style": "tier",
				"anchor": "a.counter.tier." + tier,
				"enabled": why == "",
				"echo": true,
				"reason_ref": _reason_ref(why),
			})
	if str(_cv.get("last_reply", "")) == "counter":
		var accept := _reply("accept", "c04.reply.accept", "choice", "")
		var why_accept := str(_cv.get("accept_err", ""))
		if why_accept != "":
			# [shared] G04 10-25: the shop cannot pay his price; never narrate a deal that cannot happen.
			accept["enabled"] = false
			accept["reason_ref"] = _reason_ref(why_accept)
		out.append(accept)
		out.append(_reply("decline", "c04.reply.decline", "choice", ""))
	for ch in _choices():
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var id := str(ch.get("id", ""))
		var on := bool(ch.get("enabled", true))
		var ref := "%s#choices.%s" % [_def(), id]
		if id == "scare":
			ref = "k18.reply.scare"
		out.append({
			"id": "choice:" + id,
			"ref": ref,
			"style": "choice",
			"anchor": "",
			"enabled": on,
			"echo": true,
			"reason_ref": str(ch.get("reason_key", "")) if not on else "",
		})
	_add_tail(out)
	return out


func _add_tail(out: Array) -> void:
	out.append(_reply("refuse", "c04.reply.refuse", "choice", ""))
	out.append(_reply("later", "c04.reply.later", "later", ""))


## [shared] G04 10-25: why this tier price cannot be offered now ("" = it can; CounterView.tier_err).
func _tier_err(tier: String) -> String:
	var errs = _cv.get("tier_err", {})
	return str(errs.get(tier, "")) if typeof(errs) == TYPE_DICTIONARY else ""


func _reason_ref(err: String) -> String:
	match err:
		"":
			return ""
		"shelf_full":
			return "c04.reason.shelf_full"
	return "c04.reason.money_short"


func _reply(id: String, ref: String, style: String, anchor: String) -> Dictionary:
	return {
		"id": id, "ref": ref, "style": style, "anchor": anchor,
		"enabled": true, "echo": true, "args": {},
	}


func _on_lines_done() -> void:
	if _in_open or _closed:
		return
	_mark_reply_anchor()
	_present()
	_sync_extras()


func _mark_reply_anchor() -> void:
	if dialog == null:
		return
	var lab := dialog.find_child("ReplyLine", true, false) as Label
	if lab == null:
		return
	var guest := false
	for line in _batch:
		if typeof(line) == TYPE_DICTIONARY and str(line.get("ref", "")).find("#lines.") >= 0:
			guest = true
			break
	if guest:
		CardAnchors.register(&"a.counter.reply", lab)
	else:
		CardAnchors.unregister(&"a.counter.reply", lab)


func _place_items() -> void:
	if stage == null:
		return
	var items: Array = []
	var it = _item()
	if it != null:
		items.append({"item": str(it.get("item", "")), "art": str(it.get("art", ""))})
	stage.set_items(items)
	if items.is_empty():
		CardAnchors.unregister(&"a.counter.item", stage)
	else:
		CardAnchors.register(&"a.counter.item", stage, _item_rect)


func _item_rect() -> Rect2:
	return CardLayout.screen(CardLayout.S_ITEMS)


func _open_shelf() -> void:
	if _drawer != null and is_instance_valid(_drawer) and not _drawer.is_queued_for_deletion():
		return
	if _stock_known and _stock.is_empty():
		return
	var host := _find_host()
	if host != null:
		_drawer = host.open_panel(&"shelf", {"pick_for": _uid})
		if _drawer != null:
			_drawer.close_requested.connect(_on_drawer_closed)
		return
	var packed := load(CardIds.panel_scene(&"shelf")) as PackedScene
	if packed == null:
		return
	_drawer = packed.instantiate() as CardPanel
	_drawer.bind(engine, bus)
	add_child(_drawer)
	_drawer.open({"pick_for": _uid})
	_drawer.close_requested.connect(_on_drawer_closed)


func _on_drawer_closed(_result: Dictionary) -> void:
	_release_drawer()
	_place_items()
	if dialog != null and dialog.is_idle():
		_present()
	_sync_extras()


func _release_drawer() -> void:
	var d := _drawer
	_drawer = null
	if d == null or not is_instance_valid(d):
		return
	var host := _find_host()
	if host != null and d.get_parent() == host:
		if not d.is_queued_for_deletion():
			host.close_panel(d)
		return
	if not d.is_queued_for_deletion():
		d.queue_free()


# ---------------- bus ----------------
func _on_view_changed(_topics: PackedStringArray) -> void:
	if _uid == "" or not is_inside_tree() or _in_open:
		return
	var before := _obs_keys()
	var lever_before := str(_cv.get("line_key", ""))
	_pull(false)
	_place_items()
	var fresh := _new_keys(before, _obs_keys())
	var lines := _obs_lines(fresh)
	# [shared] 10-25 appraisal Level B: after the narrated observations, the customer reacts once (G04 line_key).
	var lever := str(_cv.get("line_key", ""))
	if lever.begins_with(LEVER_PREFIX) and lever != lever_before:
		lines.append(_lever_line(lever))
	if dialog != null and not lines.is_empty():
		_batch.append_array(lines)
		dialog.show_lines(_uid, lines, true)
		_sync_extras()
		return
	if dialog != null and dialog.is_idle() and not _local_send:
		_present()
	_sync_extras()


func _on_card_left(uid: String, _reason: StringName) -> void:
	if uid != _uid:
		return
	_guest_left = true


func _on_money(_old_amount: int, _new_amount: int, _reason: String) -> void:
	_flash = 0.85
	if _flash_rect != null:
		_flash_rect.modulate = Color(1, 1, 1, _flash)


func _on_first(mech: StringName, args: Dictionary) -> void:
	if mech == &"ticket" and args.has("no"):
		_seen_ticket_no = int(args["no"])


func _on_command_done(cmd: StringName, args: Dictionary, ok: bool) -> void:
	if str(args.get("uid", "")) != _uid:
		return
	if cmd == &"mg.report":
		var result = args.get("result", {})
		if typeof(result) == TYPE_DICTIONARY and bool((result as Dictionary).get("aborted", false)):
			_looked = false
		return
	if _local_send or not ok:
		return
	if cmd != &"counter.pick_stock":
		return
	var found := _stock_by_id(str(args.get("item", "")))
	if not found.is_empty():
		_cv["item"] = found
	_place_items()
	if dialog != null and dialog.is_idle():
		_present()
	_sync_extras()


func _on_stage_hotspot(id: StringName) -> void:
	on_hotspot(id)


# ---------------- widgets ----------------
func _ensure_widgets() -> void:
	if _flash_rect == null:
		_flash_rect = ColorRect.new()
		_flash_rect.color = CardTheme.color(&"lamp")
		_flash_rect.modulate = Color(1, 1, 1, 0)
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_flash_rect)
	# Dialog first; DemandPanel is already warmed via _DemandScript preload.
	if dialog == null:
		dialog = _spawn(&"dialog") as CardDialogApi
		_owned_dialog = dialog != null
	if stage == null:
		stage = _spawn(&"stage") as CardStageApi
		_owned_stage = stage != null
	# 手牌扇等到吓唬检定才挂。提前挂上时预览钮 Back/KeepSide/Play 自身 visible 仍为真，
	# C04 只看 Button.visible、不看父节点，送客后会多出这三颗钮。
	if checks == null:
		checks = _spawn(&"checks") as CardChecksApi
		_owned_checks = checks != null
	if stage != null and dialog != null and stage.get_index() > dialog.get_index():
		move_child(dialog, get_child_count() - 1)
	_wire_widgets()
	_apply_speed()


func _spawn(widget_name: StringName) -> Control:
	var path := CardIds.widget_scene(widget_name)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var node := load(path).instantiate() as Control
	if node == null:
		return null
	add_child(node)
	return node


func _wire_widgets() -> void:
	if stage != null and stage.get("bus") != null:
		stage.set("bus", bus)
	elif stage != null and "bus" in stage:
		stage.bus = bus
	if dialog != null and "bus" in dialog:
		dialog.bus = bus
	if checks != null:
		if "engine" in checks:
			checks.engine = engine
		if "bus" in checks:
			checks.bus = bus
		if checks.has_signal("changed") and not checks.changed.is_connected(_on_scare_checks_changed):
			checks.changed.connect(_on_scare_checks_changed)
		if checks.has_signal("coins_finished") and not checks.coins_finished.is_connected(_on_scare_coins_finished):
			checks.coins_finished.connect(_on_scare_coins_finished)
	if bus != null and not bus.coins_tossed.is_connected(_on_scare_coins_tossed):
		bus.coins_tossed.connect(_on_scare_coins_tossed)
	if _wired:
		return
	# Shared root dialog: the root forwards reply_chosen → on_reply. Connect only
	# for our own dialog (or one injected without a forwarding host), like C05.
	if dialog != null and not _host_routes_replies() and not dialog.reply_chosen.is_connected(on_reply):
		dialog.reply_chosen.connect(on_reply)
	if dialog != null and not dialog.lines_done.is_connected(_on_lines_done):
		dialog.lines_done.connect(_on_lines_done)
	if stage != null and not stage.hotspot_pressed.is_connected(_on_stage_hotspot):
		stage.hotspot_pressed.connect(_on_stage_hotspot)
	_wired = dialog != null


## True when the host (C01 root) already forwards this dialog's reply_chosen
## to on_reply. Then subscribing here too would send every reply twice.
func _host_routes_replies() -> bool:
	return dialog != null and has_meta(&"host_reply_dialog") \
		and int(get_meta(&"host_reply_dialog")) == dialog.get_instance_id()


func _apply_speed() -> void:
	if dialog == null:
		return
	var instant := false
	if has_meta("instant_lines") and bool(get_meta("instant_lines")):
		instant = true
	if engine != null and "fixture_path" in engine and str(engine.fixture_path).find("/C04/") >= 0:
		instant = true
	if CardSettings.fast_anim():
		instant = true
	if instant:
		dialog.chars_per_sec = 0


# ---------------- item row (in the dialog) ----------------
## Pushes the item row, notes and result line into the dialog (RESKIN SPEC 6.4). Only numbers the
## player can see: asking, the counter price, ticket number / principal / days.
func _sync_extras() -> void:
	if dialog == null or _torn or not dialog.has_method("set_header"):
		return
	dialog.call("set_header", _header_info())


func _header_info() -> Dictionary:
	if _uid == "" or (_cv.is_empty() and _card.is_empty()):
		return {}
	var out := {"gold": bool(_card.get("gold", false))}
	var intent := str(_cv.get("intent", ""))
	var tags: Array = []
	var it = _item()
	if intent != "" and (it != null or intent != "buy"):
		tags.append({"ref": "c04.intent." + intent})
	if it != null:
		out["art"] = str(it.get("art", ""))
		var key := "c04.header." + (intent if intent in ["pawn", "sell", "buy", "redeem"] else "pawn")
		out["title_ref"] = key
		out["title_args"] = {"name": _item_name(it)}
		var cat := str(it.get("cat", ""))
		if cat != "":
			tags.append({"ref": "c04.cat." + cat})
		if it.has("condition_word"):
			var cond := CardText.ui("c04.cond.%d" % clampi(int(it["condition_word"]), 0, 4))
			tags.append({"ref": "c04.header.cond", "args": {"cond": cond}})
	elif intent == "buy":
		out["title_ref"] = "c04.header.buy_none"
	var asking := int(_cv.get("asking", -1))
	if asking > 0:
		tags.append({"ref": "c04.header.asking", "args": {"n": asking}})
	if str(_cv.get("last_reply", "")) == "counter" and int(_cv.get("last_price", 0)) != 0:
		tags.append({"ref": "c04.header.counter", "args": {"n": int(_cv.get("last_price", 0))}})
	var ticket = _cv.get("ticket")
	if typeof(ticket) == TYPE_DICTIONARY:
		var t: Dictionary = ticket
		tags.append({"ref": "c04.header.ticket", "args": {"n": int(t.get("no", 0))}})
		tags.append({"ref": "c04.header.principal", "args": {"n": int(t.get("principal", 0))}})
		tags.append({"ref": "c04.header.days", "args": {"n": int(t.get("days_left", 0))}})
		if bool(t.get("foreign", false)):
			tags.append({"ref": "c04.tickets.foreign"})
	elif _result == "ticket" and _ticket_no >= 0:
		tags.append({"ref": "c04.header.ticket", "args": {"n": _ticket_no}})
	out["tags"] = tags
	var notes: Array = []
	for key in _obs_keys():
		var parts := key.split(".")
		var kind := parts[1] if parts.size() > 2 and parts[0] == "obs" else "other"
		var label := "c04.note." + kind
		if not CardText.has_text(label):
			label = "c04.note.other"
		notes.append({"label_ref": label, "text_ref": key, "args": {}})
	out["notes"] = notes
	if _result == "ticket" or _result == "shelved":
		out["lead_ref"] = "c04.result." + _result
	return out


# ---------------- helpers ----------------
func _reset(uid: String) -> void:
	_uid = uid
	_cv = {}
	_card = {}
	_stock = []
	_stock_known = false
	_snap = ""
	_phase = "talk"
	_result = ""
	_ticket_no = -1
	_seen_ticket_no = -1
	_tried_open = false
	_guide_beat = false
	_looked = false
	_auto_looked = false
	_auto_picked = false
	_did_redeem = false
	_closed = false
	_guest_left = false
	_script = {}
	_batch = []
	_release_drawer()


func _with_impatient(lines: Array) -> Array:
	if _impatient():
		lines.append_array(CardStageScript.lines(_script, "impatient"))
	return lines


func _impatient() -> bool:
	return str(_cv.get("line_key", "")).find("impatient") >= 0


func _obs_keys() -> PackedStringArray:
	var out := PackedStringArray()
	var it = _item()
	if it == null:
		return out
	var obs = it.get("observations", [])
	if typeof(obs) != TYPE_ARRAY:
		return out
	for key in obs:
		out.append(str(key))
	return out


func _obs_lines(keys: PackedStringArray) -> Array:
	var lines: Array = []
	for key in keys:
		if key == "":
			continue
		lines.append({"kind": "narr", "who": "", "ref": key, "args": {}, "opt": false})
	return lines


## The customer's reaction to the appraisal; a person card may override it in its own lines.<caught|offended|soft>.
func _lever_line(key: String) -> Dictionary:
	var who := CardStageScript.speaker(_script)
	var ref := key
	var own := "%s#lines.%s" % [_def(), key.trim_prefix(LEVER_PREFIX)]
	if _def() != "" and CardText.has_text(own):
		ref = own
	var args := {"price": int(_cv.get("asking", 0))}
	if who != "":
		args["name"] = CardText.person_name(who)
	return {"kind": "say" if who != "" else "narr", "who": who, "ref": ref, "args": args, "opt": false}


func _new_keys(before: PackedStringArray, now: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for key in now:
		if not before.has(key):
			out.append(key)
	return out


func _is_open(d: Dictionary) -> bool:
	if d.is_empty() or (d.has("ok") and not bool(d["ok"])):
		return false
	return typeof(d.get("tiers")) == TYPE_DICTIONARY


func _show_tiers() -> bool:
	if _phase != "talk" or not _is_open(_cv):
		return false
	var intent := str(_cv.get("intent", ""))
	if intent == "redeem" or (intent == "buy" and _item() == null):
		return false
	return true


func _can_look() -> bool:
	return _phase == "talk" and bool(_cv.get("can_appraise", false)) and not _looked and _item_id() != ""


func _redeem_modes() -> PackedStringArray:
	var ticket = _cv.get("ticket")
	if typeof(ticket) == TYPE_DICTIONARY and str(ticket.get("status", "")) == "sold":
		return PackedStringArray(["compensate", "buy_back"])
	return PackedStringArray(["by_rule", "squeeze"])


func _item() -> Variant:
	var it = _cv.get("item")
	if typeof(it) == TYPE_DICTIONARY and not (it as Dictionary).is_empty():
		return it
	return null


func _item_id() -> String:
	var it = _item()
	return str(it.get("item", "")) if it != null else ""


func _def() -> String:
	return str(_card.get("def", ""))



func _append_scare_replies(out: Array) -> void:
	for ch in _choices():
		if typeof(ch) != TYPE_DICTIONARY:
			continue
		var id := str(ch.get("id", ""))
		if id != "scare":
			continue
		var on := bool(ch.get("enabled", true))
		out.append({
			"id": "choice:" + id,
			"ref": "k18.reply.scare",
			"style": "choice",
			"anchor": "",
			"enabled": on,
			"echo": true,
			"reason_ref": str(ch.get("reason_key", "")) if not on else "",
		})


func _enter_scare_checks() -> void:
	_ensure_widgets()
	if hand == null:
		hand = _spawn(&"hand_fan") as CardHandApi
		_owned_hand = hand != null
		if hand != null:
			hand.visible = false
	_scare_checks = true
	_scare_rolled = false
	_scare_holding = false
	_scare_success = false
	_scare_heads = 0
	_scare_need = 0
	_scare_saw_coins = false
	_phase = "checks"
	if checks != null:
		if "engine" in checks:
			checks.engine = engine
		if "bus" in checks:
			checks.bus = bus
		checks.show_checks(_uid)
	if hand != null:
		if not _scare_hand_saved:
			_scare_hand_was_visible = hand.visible
			_scare_hand_saved = true
		hand.visible = true
		hand.set_low(true)
	if stage != null:
		stage.set_dim_tools(true)
	if dialog != null:
		dialog.set_max_bottom(404)
	_present()


func _scare_roll_rows() -> Array:
	var info: Dictionary = checks.preview() if checks != null else {}
	var auto_pass := bool(info.get("auto_pass", false))
	return [{
		"id": "roll",
		"ref": "c03.coins.auto_pass" if auto_pass else "c03.reply.roll",
		"args": {"n": int(info.get("coins", 0)), "m": int(info.get("need", 0))},
		"enabled": _scare_roll_enabled(),
		"reason_ref": "c03.err.slot_required" if _scare_required_blocked() else "",
		"style": "roll",
		"anchor": "a.slots.roll",
		"echo": false,
	}, _reply("later", "c04.reply.later", "later", "")]


func _scare_roll_enabled() -> bool:
	if _scare_required_blocked() or checks == null:
		return false
	var info: Dictionary = checks.preview()
	if info.has("ready") and not bool(info.get("ready", false)):
		return false
	return true


func _scare_required_blocked() -> bool:
	var q: Dictionary = engine.query(&"slots", {"uid": _uid}) if engine != null else {}
	for slot in q.get("slots", []):
		if typeof(slot) != TYPE_DICTIONARY:
			continue
		if bool(slot.get("required", false)):
			var placed = slot.get("placed", [])
			if typeof(placed) != TYPE_ARRAY or placed.is_empty():
				return true
	return false


func _scare_roll() -> void:
	if _scare_rolled or not _scare_roll_enabled() or engine == null:
		return
	_scare_rolled = true
	_scare_holding = true
	_phase = "toss"
	_scare_saw_coins = false
	var result: Dictionary = engine.send(&"slot.roll", {"uid": _uid})
	if _scare_saw_coins or not bool(result.get("ok", false)):
		return
	_on_scare_coins_tossed(_uid, result.get("faces", []), int(result.get("need", 0)), bool(result.get("success", false)))


func _on_scare_coins_tossed(uid: String, faces: Array, need: int, success: bool) -> void:
	if str(uid) != _uid or not _scare_checks:
		return
	_scare_saw_coins = true
	_scare_holding = true
	_scare_success = success
	_scare_need = need
	_scare_heads = 0
	for face in faces:
		if bool(face):
			_scare_heads += 1
	_phase = "toss"
	if checks != null:
		checks.play_coins(faces, need)
	else:
		_on_scare_coins_finished(success)


func _on_scare_coins_finished(_success: bool) -> void:
	if not _scare_checks:
		return
	_scare_holding = false
	_set_scare_checks_chrome(false)
	_scare_checks = false
	_phase = "settled"
	_guest_left = true
	_present()


func _on_scare_checks_changed() -> void:
	if not _scare_checks or _phase != "checks" or _closed:
		return
	_present()


func _set_scare_checks_chrome(on: bool) -> void:
	if not on:
		if checks != null and checks.is_shown():
			checks.hide_checks()
		if hand != null:
			hand.set_low(false)
			# 只隐藏自建 fallback hand；共享 hand 恢复进入吓唬前状态（普通关柜台也不再误藏）。
			if _owned_hand:
				hand.visible = false
			elif _scare_hand_saved:
				hand.visible = _scare_hand_was_visible
			_scare_hand_saved = false
		if stage != null:
			stage.set_dim_tools(false)
		if dialog != null:
			dialog.set_max_bottom(CardLayout.DIALOG_MAX_BOTTOM)


func on_card_played(uid: String, _def_id: String) -> bool:
	if not _scare_checks or _phase != "checks" or checks == null or not (checks is CardCounterChecks):
		return false
	var source := _scare_source_for(uid)
	if source.is_empty():
		return false
	var accepts_kind := str(source.get("kind", ""))
	if accepts_kind not in ["self", "contact"]:
		return false
	(checks as CardCounterChecks).offer("nerve", source)
	return true


func _scare_source_for(uid: String) -> Dictionary:
	var raw = engine.view() if engine != null else {}
	var view: Dictionary = raw if typeof(raw) == TYPE_DICTIONARY else {}
	var self_view: Dictionary = view.get("self", {}) if typeof(view.get("self")) == TYPE_DICTIONARY else {}
	if str(self_view.get("uid", "")) == uid:
		return {"kind": "self"}
	for row in view.get("contacts", []):
		if typeof(row) == TYPE_DICTIONARY and str(row.get("uid", "")) == uid:
			return {"kind": "contact", "uid": uid}
	return {}


func _choices() -> Array:
	var raw = _card.get("choices", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


func _choice_row(id: String) -> Dictionary:
	for ch in _choices():
		if typeof(ch) == TYPE_DICTIONARY and str(ch.get("id", "")) == id:
			return ch
	return {}


func _stock_by_id(item_id: String) -> Dictionary:
	for entry in _stock:
		if typeof(entry) == TYPE_DICTIONARY and str(entry.get("item", "")) == item_id:
			return entry
	return {}


func _item_name(it: Dictionary) -> String:
	var tpl := str(it.get("template", ""))
	if tpl == "":
		return ""
	return CardText.item_text(tpl, "name")


## The panel host. Stage panels live in Table/PlayLayer, beside (not under) the ModalHost, so also
## take the root's `host` on the way up (b17: the shelf opened inside this panel, under the table).
func _find_host() -> CardModalHost:
	var n: Node = get_parent()
	while n != null:
		if n is CardModalHost:
			return n
		var h = n.get("host") if "host" in n else null
		if h is CardModalHost and is_instance_valid(h):
			return h
		n = n.get_parent()
	return null


func _hook(sig: StringName, cb: Callable) -> void:
	if bus != null and not bus.is_connected(sig, cb):
		bus.connect(sig, cb)


func _accept_key() -> void:
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _sig(d: Dictionary) -> String:
	var iid := ""
	var obs := ""
	var it = d.get("item")
	if typeof(it) == TYPE_DICTIONARY:
		iid = str(it.get("item", ""))
		var o = it.get("observations", [])
		if typeof(o) == TYPE_ARRAY:
			var parts := PackedStringArray()
			for x in o:
				parts.append(str(x))
			obs = "|".join(parts)
	var tk := ""
	var ticket = d.get("ticket")
	if typeof(ticket) == TYPE_DICTIONARY:
		tk = "%s:%s:%s" % [str(ticket.get("no", "")), str(ticket.get("status", "")), str(ticket.get("days_left", ""))]
	var tiers = d.get("tiers", {})
	var ts := ""
	if typeof(tiers) == TYPE_DICTIONARY:
		ts = "%s,%s,%s" % [str(tiers.get("harsh", "")), str(tiers.get("fair", "")), str(tiers.get("kind", ""))]
	var stock_n := 0
	if typeof(d.get("stock")) == TYPE_ARRAY:
		stock_n = (d.get("stock") as Array).size()
	var errs = d.get("tier_err", {})
	var es := ""
	if typeof(errs) == TYPE_DICTIONARY:
		es = "%s,%s,%s,%s" % [str(errs.get("harsh", "")), str(errs.get("fair", "")), str(errs.get("kind", "")), str(d.get("accept_err", ""))]
	return "%s#%s#%s#%s#%s#%s#%s#%s#%s#%s#%s" % [str(d.get("last_reply", "")), str(d.get("last_price", "")),
		str(d.get("line_key", "")), str(d.get("round", "")), iid, obs, str(d.get("asking", "")), tk, ts, str(stock_n), es]
