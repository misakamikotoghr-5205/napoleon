# Settle is a stage: each report line is said in the dialog, then "dawn" sends settle.next.
# Owner C08. Contract 1.3. The hand tucks away. No meter points and no percent signs.
# Anchor a.settle.lines tracks the dialog. Text from CardText, color from CardTheme.
# Exit teardown frees owned stage widgets so day-walk tests do not leave RIDs at exit.
class_name CardSettlePanel
extends CardStagePanel

const _DemandScript := preload("res://scripts/cards/ui/demand/demand_panel.gd")
const Chrome = preload("res://scripts/cards/ui/night/panel_chrome.gd")
const Bind = preload("res://scripts/cards/ui/night/stage_bind.gd")
const KIND := &"settle"
const LINE_GAP := 0.45
const LINE_FADE := 0.4

var fast_anim: bool = false
var _lines: Array = []
var _shown: int = 0
var _revealed: bool = false
var _finished: bool = false
var _fast: bool = false
var _wired: bool = false
var _owned: Dictionary = {}
var _torn: bool = false
var _tick: SceneTreeTimer = null


func _init() -> void:
	if _DemandScript == null:
		push_error("CardSettlePanel: demand script failed to load")


func open(args: Dictionary) -> void:
	_torn = false
	_finished = false
	_revealed = false
	_shown = 0
	_fast = fast_anim or CardSettings.fast_anim()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_owned = Bind.ensure(self, bus)
	_wire()
	_lines = _read_lines()
	var after = args.get("after", [])
	if typeof(after) == TYPE_ARRAY:
		_add_rows(after)
	var snap := engine.view() if engine != null else {}
	if stage != null and not snap.is_empty():
		stage.refresh(snap)
	if hand != null and not snap.is_empty():
		hand.refresh(snap)
		hand.set_away(true)
	_register_anchor()
	_kick()


## The corner end-day button sends day.end during settle, which moves the engine to the next morning
## without the dawn reply. Close then, so the report does not linger over the next day.
func refresh(view: Dictionary) -> void:
	if _finished or _torn or not view.has("phase"):
		return
	if str(view.get("phase", "")) != "settle":
		_finished = true
		_finish_close()


## Dialog lines ({ref, args}) a panel closed over this stage asked to say (a stocktake pick's gain line): they come
## after the report, last before "dawn", instead of being buried under the report lines still to come.
## False once the stage is done (the caller says them itself).
func say_after(lines: Array) -> bool:
	if _finished or _torn:
		return false
	if not _revealed:
		_add_rows(lines)
	elif dialog != null:
		dialog.show_lines("settle", lines, true)
	return true


func _add_rows(lines: Array) -> void:
	for line in lines:
		if typeof(line) == TYPE_DICTIONARY and str(line.get("ref", "")) != "":
			_lines.append({"key": str(line["ref"]), "args": _args_of(line)})


func autoplay_step() -> bool:
	if _finished or _torn:
		return false
	if not _revealed:
		_reveal_all()
	on_reply("dawn")
	return _finished


## Closing the settle stage does not send settle.next. The hand comes back.
func dismiss() -> void:
	if hand != null and is_instance_valid(hand):
		hand.set_away(false)
	if _finished:
		_finish_close()
		return
	_finished = true
	_finish_close()


func on_reply(reply_id: String) -> void:
	if reply_id != "dawn" or _finished or _torn or engine == null:
		return
	if not _revealed:
		_reveal_all()
	_finished = true
	if hand != null and is_instance_valid(hand):
		hand.set_away(false)
	var result: Dictionary = engine.send(&"settle.next", {})
	if bool(result.get("ok", false)):
		_finish_close()
	else:
		_finished = false


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
	_stop_tick()
	CardAnchors.unregister(&"a.settle.lines", self)
	if hand != null and is_instance_valid(hand):
		hand.set_away(false)
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
	# Shared C01 dialog: root forwards reply_chosen. Connect only if we spawned ours.
	if bool(_owned.get("dialog", false)) and dialog != null and not dialog.reply_chosen.is_connected(on_reply):
		dialog.reply_chosen.connect(on_reply)


func _unwire() -> void:
	if dialog != null and is_instance_valid(dialog) and dialog.reply_chosen.is_connected(on_reply):
		dialog.reply_chosen.disconnect(on_reply)
	_wired = false


func _register_anchor() -> void:
	CardAnchors.register(&"a.settle.lines", self, _dialog_rect)


func _dialog_rect() -> Rect2:
	var box := CardAnchors.rect(&"a.dialog")
	if box.has_area():
		return box
	if dialog != null and dialog.is_inside_tree() and dialog.visible:
		return dialog.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, dialog.size)
	return Rect2()


func _read_lines() -> Array:
	if engine == null:
		return []
	var report: Dictionary = engine.query(&"settle_report", {})
	var lines = report.get("lines", [])
	if typeof(lines) != TYPE_ARRAY:
		return []
	return (lines as Array).duplicate(true)


func _kick() -> void:
	if dialog != null:
		# The prototype's close report opens with a centred gold system line ("day N, closing").
		var head := _narr("c08.settle.title", {})
		head["kind"] = "sys"
		dialog.show_lines("settle", [head])
	if _lines.is_empty() or _fast:
		_reveal_all()
		return
	_push_one()
	_arm()


func _arm() -> void:
	if _revealed or _torn:
		return
	if not is_inside_tree():
		_arm.call_deferred()
		return
	_stop_tick()
	_tick = get_tree().create_timer(LINE_GAP)
	_tick.timeout.connect(_on_tick)


func _stop_tick() -> void:
	if _tick != null:
		if _tick.timeout.is_connected(_on_tick):
			_tick.timeout.disconnect(_on_tick)
		_tick = null


func _on_tick() -> void:
	_tick = null
	if _revealed or _finished or _torn:
		return
	if _shown >= _lines.size():
		_show_dawn()
		return
	_push_one()
	_arm()


func _push_one() -> void:
	if _shown >= _lines.size() or dialog == null:
		return
	var row: Dictionary = _lines[_shown]
	_shown += 1
	dialog.show_lines("settle", [_narr(str(row.get("key", "")), _args_of(row))], true)
	if _shown >= _lines.size():
		_show_dawn()


func _reveal_all() -> void:
	var batch: Array = []
	while _shown < _lines.size():
		var row: Dictionary = _lines[_shown]
		_shown += 1
		batch.append(_narr(str(row.get("key", "")), _args_of(row)))
	if dialog != null and not batch.is_empty():
		dialog.show_lines("settle", batch, true)
	# Finish typing before dawn is offered (real C04 chars_per_sec > 0).
	_show_dawn()


func _show_dawn() -> void:
	_revealed = true
	_stop_tick()
	if dialog == null:
		return
	# CardDialogApi.skip() completes the visible line so is_idle() is true
	# before the dawn reply appears. First Space/Enter must not settle.next.
	if not dialog.is_idle():
		dialog.skip()
	dialog.set_replies([{
		"id": "dawn",
		"ref": "c08.reply.dawn",
		"args": {},
		"enabled": true,
		"echo": true,
		"anchor": "a.settle.lines",
	}])


## "nums": false: report args the words do not print (tier indices, one-per-line counts) never become number chips.
func _narr(key: String, args: Dictionary) -> Dictionary:
	return {"kind": "narr", "who": "", "ref": key, "args": args, "opt": false, "nums": false}


func _args_of(row: Dictionary) -> Dictionary:
	var raw = row.get("args", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func _unhandled_input(event: InputEvent) -> void:
	if _finished or _torn or not Chrome.is_front(self):
		return
	var code := Chrome.pressed_key(event)
	if code < 0:
		return
	if code == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		dismiss()
		return
	if code == KEY_1 and _revealed:
		get_viewport().set_input_as_handled()
		on_reply("dawn")
		return
	if code != KEY_SPACE and code != KEY_ENTER and code != KEY_KP_ENTER:
		return
	get_viewport().set_input_as_handled()
	if not _revealed:
		_reveal_all()
	elif dialog != null and not dialog.is_idle():
		dialog.skip()
	else:
		on_reply("dawn")
