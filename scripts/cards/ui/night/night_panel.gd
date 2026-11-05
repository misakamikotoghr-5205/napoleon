# Night is a stage: the hand fan holds the night cards plus "sleep", and choices are replies.
# Owner C08. Contract 1.3 section 7.11. Dismiss (Esc) means tonight choose nothing.
# Anchor a.night.offers tracks the fan. Text from CardText, color from CardTheme.
# Exit teardown frees owned stage widgets and drops signal hooks so K14/W0 do not leave RIDs.
class_name CardNightPanel
extends CardStagePanel

# Same load-order fix as C03/C04: demand_panel caches PackedScenes in a static table.
# Instantiating another CardStagePanel first leaves that table's fonts/textures at exit.
const _DemandScript := preload("res://scripts/cards/ui/demand/demand_panel.gd")
const Chrome = preload("res://scripts/cards/ui/night/panel_chrome.gd")
const Bind = preload("res://scripts/cards/ui/night/stage_bind.gd")
const KIND := &"night"

var _offers: Array = []
var _replies: Array = []
var _script: Dictionary = {}
var _picked: String = ""
var _waiting: bool = false
var _done: bool = false
var _wired: bool = false
var _key_index: int = -1
var _owned: Dictionary = {}
var _torn: bool = false
var _said: bool = false   # last dialog line is our own narration (open/skip), not a card's lines


func _init() -> void:
	if _DemandScript == null:
		push_error("CardNightPanel: demand script failed to load")


func open(_args: Dictionary) -> void:
	_torn = false
	_done = false
	_waiting = false
	_picked = ""
	_replies = []
	_script = {}
	_key_index = -1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_owned = Bind.ensure(self, bus)
	_wire()
	_offers = _read_offers(engine.view() if engine != null else {})
	_refresh_hand()
	if stage != null and engine != null:
		stage.refresh(engine.view())
	_register_anchor()
	if _offers.is_empty():
		_say("c08.night.skip")
	else:
		_say("c08.narr.night_open")


## The corner button (sleep · till dawn) sends day.end at night, which moves the engine on to settle
## without night.choose. Close then, like the settle panel, so settle / stocktake can open and the
## next day's hand cards are not swallowed by a stale night stage.
func refresh(view: Dictionary) -> void:
	if _torn or not view.has("phase"):
		return
	if str(view.get("phase", "")) != "night":
		if not _done:
			_done = true
			_waiting = false
			_said = true   # whatever the dialog holds is tonight's (skip line or an unanswered card): drop it
			_finish_close()
		return
	if _done or _waiting:
		return
	var nxt := _read_offers(view)
	if _same(nxt, _offers):
		_refresh_hand(view)
		return
	_offers = nxt
	_refresh_hand(view)
	if _offers.is_empty():
		_say("c08.night.skip")
	else:
		_say("c08.narr.night_open")


func autoplay_step() -> bool:
	if _done or _torn:
		return false
	if dialog != null and not dialog.is_idle():
		dialog.skip()
	if _waiting:
		_pick_reply(0)
		return _done
	if _offers.is_empty():
		_choose({"def": ""})
		return _done
	_key_index = 0
	if hand != null and str(engine.view().get("phase", "")) == "night":
		hand.select_index(0)
		hand.play_selected()
	else:
		on_card_played("", _def_of(_offers[0]))
	if _waiting:
		_pick_reply(0)
	return _done


## Esc and the close button. During the night this chooses nothing; otherwise it only closes.
func dismiss() -> void:
	if _done:
		_finish_close()
		return
	if engine != null and str(engine.view().get("phase", "")) == "night":
		_choose({"def": ""})
		return
	_done = true
	_finish_close()


func on_reply(reply_id: String) -> void:
	if _done or _torn or not _waiting or _picked == "":
		return
	var def_id := _picked
	_waiting = false
	_choose({"def": def_id, "choice": reply_id})


func on_card_played(_uid: String, def_id: String) -> bool:
	if _done or _torn or _waiting:
		return true
	if def_id == "":
		_choose({"def": ""})
		return true
	var offer = _offer_for(def_id)
	var ids := _choice_ids(offer)
	if ids.is_empty():
		if typeof(offer) == TYPE_DICTIONARY and typeof(offer.get("stage")) == TYPE_DICTIONARY:
			_play_offer(offer)
		_choose({"def": def_id})
		return true
	_waiting = true
	_picked = def_id
	_key_index = -1
	_play_offer(offer)
	return true


func _exit_tree() -> void:
	_teardown()


func _finish_close() -> void:
	if _torn:
		return
	_teardown()
	close_requested.emit({})


func _teardown() -> void:
	if _torn:
		return
	_torn = true
	# Do not carry "nothing to do tonight" into the morning: drop our own narration line.
	if _said and dialog != null and is_instance_valid(dialog):
		dialog.clear()
	CardAnchors.unregister(&"a.night.offers", self)
	end_play()
	_unwire()
	Bind.release(self, _owned)
	_owned = {}
	engine = null
	bus = null


func _wire() -> void:
	if _wired:
		return
	_wired = true
	if hand != null and not hand.card_played.is_connected(_on_hand):
		hand.card_played.connect(_on_hand)
	if dialog != null and not dialog.reply_chosen.is_connected(on_reply):
		dialog.reply_chosen.connect(on_reply)


func _unwire() -> void:
	if hand != null and is_instance_valid(hand) and hand.card_played.is_connected(_on_hand):
		hand.card_played.disconnect(_on_hand)
	if dialog != null and is_instance_valid(dialog) and dialog.reply_chosen.is_connected(on_reply):
		dialog.reply_chosen.disconnect(on_reply)
	if hand != null and is_instance_valid(hand) and "bus" in hand and not bool(_owned.get("hand", false)):
		# Shared table hand keeps its own bus; only clear if we tagged it for this panel.
		pass
	_wired = false


func _on_hand(uid: String, def_id: String, _how: StringName) -> void:
	on_card_played(uid, def_id)


func _refresh_hand(view: Dictionary = {}) -> void:
	if hand == null or engine == null:
		return
	var snap := view if not view.is_empty() else engine.view()
	hand.refresh(snap)


func _register_anchor() -> void:
	CardAnchors.register(&"a.night.offers", self, _hand_rect)


func _hand_rect() -> Rect2:
	var fan := CardAnchors.rect(&"a.hand")
	if fan.has_area():
		return fan
	if hand != null and hand.is_inside_tree():
		return hand.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, hand.size)
	return Rect2()


func _say(key: String) -> void:
	if dialog == null:
		return
	dialog.show_lines("", [{"kind": "narr", "who": "", "ref": key, "args": {}, "opt": false}])
	_said = true


func _play_offer(offer) -> void:
	_said = false
	var cv := _night_view(offer)
	var snap := engine.view() if engine != null else {}
	_script = CardStageScript.resolve(cv, snap)
	if stage != null:
		stage.play(_script)
	var def_id := str(cv.get("def", ""))
	if dialog != null:
		dialog.show_lines(def_id, CardStageScript.lines(_script, "intro"))
	_replies = []
	for choice_id in _choice_ids(offer):
		_replies.append({
			"id": choice_id,
			"ref": "%s#choices.%s" % [def_id, choice_id],
			"args": {},
			"enabled": true,
			"echo": true,
		})
	if dialog != null:
		dialog.set_replies(_replies)


func _night_view(offer) -> Dictionary:
	var def_id := _def_of(offer)
	var art := "illus." + def_id
	var block: Dictionary = {}
	if typeof(offer) == TYPE_DICTIONARY:
		if str(offer.get("art", "")) != "":
			art = str(offer.get("art", ""))
		if typeof(offer.get("stage")) == TYPE_DICTIONARY:
			block = offer.get("stage")
	return {"uid": "", "def": def_id, "type": "night", "art": art, "zone": "night", "stage": block}


func _choose(args: Dictionary) -> void:
	if _done or _torn or engine == null:
		return
	_done = true
	_waiting = false
	var result: Dictionary = engine.send(&"night.choose", args)
	if dialog != null and not _script.is_empty() and str(args.get("choice", "")) != "":
		var extra: Array = CardStageScript.lines(_script, "done")
		if not extra.is_empty():
			dialog.show_lines(str(args.get("def", "")), extra, true)
			_said = false
	if bool(result.get("ok", false)):
		_finish_close()
	else:
		_done = false


func _pick_reply(index: int) -> void:
	if index < 0 or index >= _replies.size():
		return
	on_reply(str(_replies[index].get("id", "")))


func _read_offers(view: Dictionary) -> Array:
	var raw = view.get("night_offers", [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	return (raw as Array).duplicate(true)


func _same(a: Array, b: Array) -> bool:
	return JSON.stringify(a) == JSON.stringify(b)


func _offer_for(def_id: String):
	for offer in _offers:
		if _def_of(offer) == def_id:
			return offer
	return null


func _def_of(offer) -> String:
	if typeof(offer) == TYPE_DICTIONARY:
		return str(offer.get("def", ""))
	return str(offer)


func _choice_ids(offer) -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(offer) != TYPE_DICTIONARY:
		return out
	var rows = offer.get("choices", [])
	if typeof(rows) != TYPE_ARRAY:
		return out
	for row in rows:
		var id := ""
		if typeof(row) == TYPE_DICTIONARY:
			id = str(row.get("id", ""))
		else:
			id = str(row)
		if id != "":
			out.append(id)
	return out


func _unhandled_input(event: InputEvent) -> void:
	if _done or _torn or not Chrome.is_front(self):
		return
	var code := Chrome.pressed_key(event)
	if code < 0:
		return
	if code == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()
		return
	if code >= KEY_1 and code <= KEY_9:
		var index := code - KEY_1
		get_viewport().set_input_as_handled()
		if _waiting:
			_pick_reply(index)
		elif hand != null:
			_key_index = index
			hand.select_index(index)
		return
	if code != KEY_SPACE and code != KEY_ENTER and code != KEY_KP_ENTER:
		return
	get_viewport().set_input_as_handled()
	# A card already picked with 1–9 is played even while the opening line is
	# still typing; otherwise the first Space / Enter only finishes the line.
	var picked := not _waiting and hand != null and _key_index >= 0
	if dialog != null and not dialog.is_idle():
		dialog.skip()
		if not picked:
			return
	if _waiting:
		_pick_reply(0 if _key_index < 0 else _key_index)
		return
	if hand == null:
		return
	if _key_index < 0:
		_key_index = 0
		hand.select_index(0)
	hand.play_selected()
