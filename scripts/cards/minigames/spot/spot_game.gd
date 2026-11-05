# Spot the difference (C12): the player pins the exact spot on the item and says what it is, "old wear"
# or "not like the book". The game never says whether that is right: the observation handed back is the
# player's own call, right or wrong, and only the engine's private books compare it with the answer.
# Owner C12. Contract: docs/cards/CARDS_INTERFACES.md 3.3 C12, 6.3, 7.10.5, 8.1, 8.2; appraise DESIGN 4.
#
# Every input is an op (apply_op); the mouse, the keyboard, autoplay and tests all go through it:
#   ["tool", "eye"|"lens"]   switch tool (mg_tool event)                       0 min
#   ["atlas"]                open the pattern book (mg_tool event)             1 min
#   ["blink", 1|0]           hold / release "compare" (params.blink only)      0 min
#   ["pin", x, y, tag]       pin item pixel (x, y), tag 1 = wear, 2 = differs   2 min, 1 ink
#   ["retag", n, tag]        change pin n's call (n from 0)                    0 min
#   ["unpin", n]             take pin n away (ink is not given back)           0 min
#   ["done"]                 hand it back
# Missing new params fall back: no "at" -> the part centre 6x6 is the spot, no legend, ink 3, lens 72.
class_name CardSpotGame
extends CardMiniGame

const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")
const PanelScript = preload("res://scripts/cards/minigames/spot/spot_panel.gd")
const Rng = preload("res://scripts/sim/jev_rng.gd")

const DOMAIN := "c.mg.spot.layout"
const BOARD_POS := Vector2(90, 60)
const BOARD_SIZE := Vector2(1100, 600)
const TAG_WEAR := 1
const TAG_DIFFERS := 2
const MIN_PIN := 2
const MIN_ATLAS := 1
const NEAR_PX := 12.0
const SKILL_ATLAS := 0.5
const DEFAULT_INK := 3
const DEFAULT_LENS_PX := 72
const IMG := 64

var _params: Dictionary = {}
var _parts: Array = []
var _marks: Array = []
var _tools: Array = []
var _seed: int = 0
var _ink: int = 0
var _ink_max: int = 0
var _strokes: int = 0
var _tool: String = "eye"
var _atlas_open: bool = false
var _atlas_flipped: bool = false
var _atlas_first: bool = false
var _lens_used: bool = false
var _blink: bool = false
var _pins: Array = []
var _ops: Array = []
var _done: bool = false
var _started: bool = false
var _bus: CardEventBus = null
var _panel = null


func kind() -> StringName:
	return &"spot"


## Two minutes a pin, one for opening the book. Esc / abort hands in what was spent.
func minutes_spent() -> int:
	return _strokes * MIN_PIN + (MIN_ATLAS if _atlas_flipped else 0)


## Tests inject a bus; without one the autoload /root/CardBus is used.
func bind_bus(bus: CardEventBus) -> void:
	_bus = bus


func start(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_seed = int(_params.get("seed", 0))
	_parts = _arr(_params.get("parts"))
	_marks = _arr(_params.get("marks"))
	_tools = _arr(_params.get("tools"))
	_ink = maxi(0, int(_params.get("ink", DEFAULT_INK)))
	_ink_max = _ink
	_strokes = 0
	_atlas_open = bool(_params.get("atlas_open", false)) and _has_tool("atlas")
	_atlas_flipped = false
	_atlas_first = false
	_tool = "eye" if _has_tool("eye") else _first_inspect()
	_lens_used = _tool == "lens"
	_blink = false
	_pins = []
	_ops = []
	_done = false
	_started = true
	_minutes_spent = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_panel()


## The one way to change the round. Returns false and changes nothing when the op does not apply.
func apply_op(op: Array) -> bool:
	if not _started or _done or op.is_empty():
		return false
	var name := str(op[0])
	var ok := false
	match name:
		"tool":
			ok = op.size() == 2 and _op_tool(str(op[1]))
		"atlas":
			ok = op.size() == 1 and _op_atlas()
		"blink":
			ok = op.size() == 2 and _int(op[1]) != null and _op_blink(int(op[1]))
		"pin":
			ok = op.size() == 4 and _ints(op, 1) and _op_pin(int(op[1]), int(op[2]), int(op[3]))
		"retag":
			ok = op.size() == 3 and _ints(op, 1) and _op_retag(int(op[1]), int(op[2]))
		"unpin":
			ok = op.size() == 2 and _ints(op, 1) and _op_unpin(int(op[1]))
		"done":
			ok = op.size() == 1
	if not ok:
		return false
	_ops.append(_clean(op))
	_minutes_spent = minutes_spent()
	if name == "done":
		_finish()
	else:
		_refresh()
	return true


## Ops applied so far, in order (deep copy). Feeding them to a fresh game gives the same result.
func ops_log() -> Array:
	return _ops.duplicate(true)


## Current pins [[x, y, tag], ...] (copy).
func pins() -> Array:
	return _pins.duplicate(true)


func ink_left() -> int:
	return _ink


func current_tool() -> String:
	return _tool


func atlas_is_open() -> bool:
	return _atlas_open


func blink_held() -> bool:
	return _blink


func is_done() -> bool:
	return _done


## skill = chance that each call is right (DESIGN P8). Same seed + same skill -> same ops.
## skill >= 0.5 opens the book first. Marks go by part id; mark i is right when draw[9000 + i] < skill
## (lens first for a fine one, pin the middle of the spot, the right tag); otherwise draw[9100 + i] < 0.5
## pins the middle with the other tag, else pins "differs" 6-9 px off the spot.
func autoplay(skill: float) -> void:
	if not _started or _done:
		return
	if skill >= SKILL_ATLAS and _has_tool("atlas") and not _atlas_open:
		apply_op(["atlas"])
	var order := _marks_by_part()
	for i in order.size():
		if _done or _ink <= 0:
			break
		var mark: Dictionary = order[i]
		var spot := Marks.spot_rect(mark, _parts)
		if spot.size.x <= 0 or spot.size.y <= 0:
			continue
		var mid := spot.position + spot.size / 2
		var right_tag := TAG_WEAR if str(mark.get("kind", "")) == "wear" else TAG_DIFFERS
		if Rng.draw(_seed, DOMAIN, [9000 + i]) < skill:
			if Marks.is_fine(mark, _parts) and _has_tool("lens") and _tool != "lens":
				apply_op(["tool", "lens"])
			apply_op(["pin", mid.x, mid.y, right_tag])
		elif Rng.draw(_seed, DOMAIN, [9100 + i]) < 0.5:
			apply_op(["pin", mid.x, mid.y, TAG_DIFFERS if right_tag == TAG_WEAR else TAG_WEAR])
		else:
			var off := _off_spot(mid, i)
			if off.x >= 0:
				apply_op(["pin", off.x, off.y, TAG_DIFFERS])
			else:
				apply_op(["pin", mid.x, mid.y, TAG_DIFFERS if right_tag == TAG_WEAR else TAG_WEAR])
	apply_op(["done"])


func abort() -> void:
	if _done:
		return
	_done = true
	_minutes_spent = minutes_spent()
	_blink = false
	super.abort()


## The host's visible abort sits in the gap kept free right of "done".
func abort_rect() -> Rect2:
	if _panel == null or not is_instance_valid(_panel):
		return Rect2()
	return Rect2(_panel.position + PanelScript.ABORT_SPOT.position, PanelScript.ABORT_SPOT.size)


## Keyboard (contract 1.2, 8.2: playable by keyboard; Esc = abort). The same ops as the mouse:
## arrows move the cursor pixel (Shift: 4 px), Enter / Space open the call there, 1 / 2 call it old wear /
## not like the book, 0 / Delete / Backspace take a pin away, L lens <-> eye, A opens the book,
## hold B to compare, F hands it back. F1 is left alone (help).
func _unhandled_input(event: InputEvent) -> void:
	if _done or not _started or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo and not _is_arrow(key.keycode):
		return
	var used := _on_key(key) if key.pressed else _on_key_up(key)
	if not used:
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _on_key(key: InputEventKey) -> bool:
	var code := key.keycode
	if code == KEY_ESCAPE:
		abort()
		return true
	if _panel == null or not is_instance_valid(_panel):
		return false
	var step := 4 if key.shift_pressed else 1
	if code == KEY_LEFT:
		_panel.key_move(Vector2i(-step, 0))
	elif code == KEY_RIGHT:
		_panel.key_move(Vector2i(step, 0))
	elif code == KEY_UP:
		_panel.key_move(Vector2i(0, -step))
	elif code == KEY_DOWN:
		_panel.key_move(Vector2i(0, step))
	elif code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_panel.key_enter()
	elif code in [KEY_1, KEY_KP_1]:
		_panel.key_call(TAG_WEAR)
	elif code in [KEY_2, KEY_KP_2]:
		_panel.key_call(TAG_DIFFERS)
	elif code in [KEY_0, KEY_KP_0, KEY_DELETE, KEY_BACKSPACE]:
		_panel.key_remove()
	elif code == KEY_L:
		apply_op(["tool", "eye" if _tool == "lens" else "lens"])
	elif code == KEY_A:
		apply_op(["atlas"])
	elif code == KEY_B:
		apply_op(["blink", 1])
	elif code == KEY_F:
		apply_op(["done"])
	else:
		return false
	return true


func _on_key_up(key: InputEventKey) -> bool:
	if key.keycode == KEY_B and _blink:
		apply_op(["blink", 0])
		return true
	return false


func _is_arrow(code: Key) -> bool:
	return code in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]


# ---------------- ops ----------------
func _op_tool(tool_name: String) -> bool:
	if (tool_name != "eye" and tool_name != "lens") or not _has_tool(tool_name) or _tool == tool_name:
		return false
	_tool = tool_name
	if tool_name == "lens":
		_lens_used = true
	_emit_tool(tool_name)
	return true


func _op_atlas() -> bool:
	if not _has_tool("atlas") or _atlas_open:
		return false
	_atlas_open = true
	_atlas_flipped = true
	_emit_tool("atlas")
	return true


func _op_blink(v: int) -> bool:
	if v != 0 and v != 1:
		return false
	var on := v == 1
	if on == _blink:
		return false
	if on and (not bool(_params.get("blink", false)) or not _atlas_open):
		return false
	_blink = on
	return true


func _op_pin(x: int, y: int, tag: int) -> bool:
	if x < 0 or y < 0 or x >= IMG or y >= IMG or not _tag_ok(tag) or _ink <= 0:
		return false
	if _pins.is_empty():
		_atlas_first = _atlas_open
	_pins.append([x, y, tag])
	_ink -= 1
	_strokes += 1
	return true


func _op_retag(n: int, tag: int) -> bool:
	if n < 0 or n >= _pins.size() or not _tag_ok(tag) or int(_pins[n][2]) == tag:
		return false
	_pins[n][2] = tag
	return true


func _op_unpin(n: int) -> bool:
	if n < 0 or n >= _pins.size():
		return false
	_pins.remove_at(n)
	return true


# ---------------- result ----------------
func _finish() -> void:
	_done = true
	_blink = false
	_minutes_spent = minutes_spent()
	var spots: Array = []
	for p in _pins:
		spots.append([int(p[0]), int(p[1]), int(p[2])])
	finished.emit({
		"quality_permille": _quality(),
		"observations": _observations(),
		"minutes": minutes_spent(),
		"measures": {"spots": spots, "ink_used": _strokes, "atlas": _atlas_open, "lens": _lens_used},
		"aborted": false,
	})


## Process only (DESIGN 4.5): 300 + 400 if the book was open before the first pin (or nothing was pinned)
## + 300 if the lens was used. Never how many calls were right.
func _quality() -> int:
	var q := 300
	if _pins.is_empty() or _atlas_first:
		q += 400
	if _lens_used:
		q += 300
	return clampi(q, 0, 1000)


## One key per pin's part and call ("obs.spot.<part>.wear|differs"), each once, in pin order.
## Nothing pinned after opening the book -> "obs.spot.nothing_found".
func _observations() -> Array:
	var out: Array = []
	for p in _pins:
		var pid := part_at(int(p[0]), int(p[1]))
		if pid == "":
			continue
		var key := "obs.spot.%s.%s" % [pid, "wear" if int(p[2]) == TAG_WEAR else "differs"]
		if not out.has(key):
			out.append(key)
	if _pins.is_empty() and _atlas_open:
		out.append("obs.spot.nothing_found")
	return out


## The part a pixel belongs to: the part of the mark painted there (part rects can overlap; a pin on a
## mark names that mark's part, which always holds it), else the smallest part rect holding it, else the
## nearest part centre within 12 px, else "" (no observation).
func part_at(x: int, y: int) -> String:
	var best := ""
	var best_area := 1 << 30
	for mark in _marks:
		if typeof(mark) != TYPE_DICTIONARY:
			continue
		var spot := Marks.spot_rect(mark, _parts)
		var pid := str(mark.get("part", ""))
		if spot.has_point(Vector2i(x, y)) and spot.get_area() < best_area and not Marks.part_of(_parts, pid).is_empty():
			best_area = spot.get_area()
			best = pid
	if best != "":
		return best
	for part in _parts:
		if typeof(part) != TYPE_DICTIONARY:
			continue
		var r := Marks.rect_of(part.get("rect", []))
		if r.has_point(Vector2i(x, y)) and r.get_area() < best_area:
			best_area = r.get_area()
			best = str(part.get("id", ""))
	if best != "":
		return best
	var best_d := NEAR_PX
	var at := Vector2(x + 0.5, y + 0.5)
	for part in _parts:
		if typeof(part) != TYPE_DICTIONARY:
			continue
		var r2 := Marks.rect_of(part.get("rect", []))
		if r2.size.x <= 0 or r2.size.y <= 0:
			continue
		var d := Vector2(r2.position) + Vector2(r2.size) / 2.0
		var dist := d.distance_to(at)
		if dist <= best_d:
			best_d = dist
			best = str(part.get("id", ""))
	return best


# ---------------- autoplay helpers ----------------
func _marks_by_part() -> Array:
	var rows: Array = []
	for i in _marks.size():
		if typeof(_marks[i]) == TYPE_DICTIONARY:
			rows.append([str(_marks[i].get("part", "")), i])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		return a[0] < b[0] if a[0] != b[0] else int(a[1]) < int(b[1]))
	var out: Array = []
	for row in rows:
		out.append(_marks[int(row[1])])
	return out


## A pixel 6-9 px from the spot's middle that is on the picture and clear of every mark's spot (grown by
## 2 px), so a wrong pin really misses. Vector2i(-1, -1) when there is none.
func _off_spot(mid: Vector2i, i: int) -> Vector2i:
	var dist := 6 + int(Rng.draw(_seed, DOMAIN, [9100 + i, 1]) * 4.0)
	var start_dir := int(Rng.draw(_seed, DOMAIN, [9200 + i]) * 8.0)
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
	for extra: int in [0, 3, 6]:
		for k in 8:
			var d: Vector2i = dirs[(start_dir + k) % 8]
			var reach := float(dist + extra)
			if d.x != 0 and d.y != 0:
				reach /= sqrt(2.0)
			var p := mid + Vector2i(roundi(float(d.x) * reach), roundi(float(d.y) * reach))
			if p.x < 0 or p.y < 0 or p.x >= IMG or p.y >= IMG:
				continue
			if _near_any_mark(p):
				continue
			return p
	return Vector2i(-1, -1)


func _near_any_mark(p: Vector2i) -> bool:
	for mark in _marks:
		if typeof(mark) != TYPE_DICTIONARY:
			continue
		if Marks.spot_rect(mark, _parts).grow(2).has_point(p):
			return true
	return false


# ---------------- view ----------------
func _build_panel() -> void:
	for c in get_children():
		c.queue_free()
	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.color = CardTheme.color(&"shade")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_panel = PanelScript.new()
	_panel.name = "Board"
	_panel.position = BOARD_POS
	_panel.size = BOARD_SIZE
	_panel.custom_minimum_size = BOARD_SIZE
	add_child(_panel)
	_panel.build(_params, {"lens_px": int(_params.get("lens_px", DEFAULT_LENS_PX)),
		"blink": bool(_params.get("blink", false)), "ink_max": _ink_max})
	_panel.op_asked.connect(_on_op_asked)
	_refresh()


func _on_op_asked(op: Array) -> void:
	apply_op(op)


func _refresh() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	_panel.show_state({"pins": _pins.duplicate(true), "ink": _ink, "tool": _tool, "atlas_open": _atlas_open,
		"blink": _blink})


func _emit_tool(tool_name: String) -> void:
	var bus := _bus
	if bus == null:
		var node := get_node_or_null("/root/CardBus")
		if node is CardEventBus:
			bus = node
	if bus == null:
		return
	bus.ui_event.emit(&"mg_tool", {"kind": "spot", "tool": tool_name})


# ---------------- small helpers ----------------
func _has_tool(tool_name: String) -> bool:
	for entry in _tools:
		if str(entry) == tool_name:
			return true
	return false


func _first_inspect() -> String:
	for entry in _tools:
		var t := str(entry)
		if t == "eye" or t == "lens":
			return t
	return "eye"


func _tag_ok(tag: int) -> bool:
	return tag == TAG_WEAR or tag == TAG_DIFFERS


## Whole numbers only (an integral float from a replayed JSON log is fine).
func _int(v) -> Variant:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)):
		return int(v)
	return null


func _ints(op: Array, from: int) -> bool:
	for k in range(from, op.size()):
		if _int(op[k]) == null:
			return false
	return true


func _clean(op: Array) -> Array:
	var out: Array = [str(op[0])]
	for k in range(1, op.size()):
		out.append(int(op[k]) if typeof(op[k]) == TYPE_INT or typeof(op[k]) == TYPE_FLOAT else str(op[k]))
	return out


func _arr(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else []
