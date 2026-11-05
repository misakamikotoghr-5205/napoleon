# Weigh (C14): dengzi or steelyard. The player levels the beam with weights and the poise, watches the needle
# in its gate to judge "level", presses "level, read the stars", counts the stars in the close-up, adds the
# weights on the hook, compares with what the customer claimed and says so. The game never reads, never
# compares, never prints a verdict (appraisal redesign DESIGN 6; B9). Owner C14.
# Contract: docs/cards/CARDS_INTERFACES.md 8.1 / 8.2 / 3.3 C14.
#
# Ops (every input goes through apply_op; mouse, keys, autoplay and tests alike; DESIGN 3.6, 6.4):
#   ["weight", i]   weight i on / off the hook             0 min
#   ["poise", s]    poise to star step s (once per release) 0 min
#   ["commit"]      level, read the stars (beam freezes)    2 min
#   ["again"]       weigh again (unfreeze, clears the call)  1 min
#   ["call", c]     1 match 2 light_small 3 light_much 4 heavy 5 unsure
#   ["done"]        hand back
# Result: observation = the player's call (obs.weigh.<call>, none = unsure); quality from the needle at the
# last commit only (1000 with the needle straight = the step nearest the weight, 600 up to three steps off, 250
# further, 100 never read); measures {read_fen, steps, commits, call}. autoplay(skill): skill = chance the call
# is right (draws [9000..9002]).
# Missing new params fall back: small_fen = claim * 60 / 1000, zoom 2, minor_ticks on, needle_gain 8.
# The needle leans from the step error (R.off_steps), so exactly one step stands it straight; one step off leans
# it at least the beam's NEEDLE_MIN_PX. The legend (top left of the beam) says what a big star and a small dot
# are worth and how a reading is made (hook weights plus the stars at the poise cord): rules, never the weight.
extends CardMiniGame

const _BEAM := preload("res://scripts/cards/minigames/weigh/weigh_beam.gd")
const _ZOOM := preload("res://scripts/cards/minigames/weigh/weigh_zoom.gd")
const R := preload("res://scripts/cards/minigames/weigh/weigh_rules.gd")
const Chrome = preload("res://scripts/cards/minigames/mg_chrome.gd")

const RNG_DOMAIN := "c.mg.weigh.layout"
const TILT_MAX := 0.12
const TILT_SPAN_STEPS := 24.0
const MAX_WEIGHTS := 9
const MIN_COMMIT := 2
const MIN_AGAIN := 1
const PANEL_POS := Vector2(140, 60)
const PANEL_SIZE := Vector2(1000, 600)
# Panel coordinates (screen = panel + (140, 60)); DESIGN 6.9, with everything under the beam 10 px higher
# (beam frame 286 tall, not 296) so the judgment row keeps a margin above the frame.
const BEAM_RECT := Rect2(34, 130, 932, 286)
const ZOOM_RECT := Rect2(582, 10, 340, 120)        # inside the beam frame: screen (756, 200)
const COMMIT_RECT := Rect2(34, 426, 200, 40)
const AGAIN_RECT := Rect2(246, 426, 160, 40)
const DONE_RECT := Rect2(418, 426, 160, 40)
const ABORT_SPOT := Rect2(590, 426, 120, 40)
const HINT_RECT := Rect2(722, 434, 244, 24)
const WEIGHT_Y := 476.0
const WEIGHT_PITCH := 96.0
const WEIGHT_SIZE := Vector2(88, 44)
const CALL_Y := 530.0
const CALL_PITCH := 188.0
const CALL_SIZE := Vector2(176, 44)
const NUDGE_IN_RECT := Rect2(692, 240, 110, 36)     # beam frame coordinates
const NUDGE_OUT_RECT := Rect2(812, 240, 110, 36)
const RULE_MATCH_RECT := Rect2(514, 71, 452, 22)    # right of the tool name / the claim
const RULE_SMALL_RECT := Rect2(514, 98, 452, 22)
## Reading legend, beam frame coordinates: four lines left of the lifting cord (x 210 on the steelyard).
const LEGEND_POS := Vector2(12, 6)
const LEGEND_PITCH := 23.0
const LEGEND_SIZE := Vector2(186, 23)
## Weight text keys by which parts are not zero (liang 4, qian 2, fen 1); all zero reads "0 fen".
const WT_KEYS := ["c14.weight.face_fen", "c14.weight.face_fen", "c14.weight.face_qian", "c14.weight.face",
	"c14.weight.face_liang", "c14.weight.face_lf", "c14.weight.face_lq", "c14.weight.face_lqf"]

var bus: CardEventBus = null
var params: Dictionary = {}

var _tool: String = "dengzi"
var _seed: int = 0
var _claimed: int = 0
var _actual: int = 0
var _res: int = 1
var _weights: Array[int] = []
var _on: Array[bool] = []
var _poise_step: int = 0
var _poise_max: int = 1
var _zoom_k: int = R.DEFAULT_ZOOM
var _fine: bool = R.DEFAULT_MINOR_TICKS
var _gain: int = R.DEFAULT_NEEDLE_GAIN
var _steps: int = 0
var _commits: int = 0
var _agains: int = 0
var _committed: bool = false
var _read_fen: int = 0
var _quality_last: int = R.Q_NONE
var _call: int = 0
var _done: bool = false
var _started: bool = false
var _ops: Array = []
var _phase: int = 0
var _drag: bool = false
var _drag_step: int = 0
var _fast: bool = false
var _marked: int = -1

var _panel: Panel
var _beam: Control
var _zoom: Control
var _art: TextureRect
var _weights_box: Control
var _calls_box: Control
var _weight_btns: Array[Button] = []
var _call_btns: Array[Button] = []
var _faces: PackedStringArray = PackedStringArray()
var _commit_btn: Button
var _again_btn: Button
var _done_btn: Button
var _nudge_in: Button
var _nudge_out: Button


func kind() -> StringName:
	return &"weigh"


func start(p_params: Dictionary) -> void:
	params = p_params.duplicate(true)
	_done = false
	_started = true
	_steps = 0
	_commits = 0
	_agains = 0
	_committed = false
	_read_fen = 0
	_quality_last = R.Q_NONE
	_call = 0
	_minutes_spent = 0
	_ops = []
	_phase = 0
	_drag = false
	_fast = CardSettings.fast_anim()
	_read_params()
	_layout_rng()
	_clear_ui()
	_build()
	_refresh(false)


# ---------------- ops ----------------

## The only way the round changes. Returns false and changes nothing when the op is not legal now.
func apply_op(op: Array) -> bool:
	if _done or not _started or op.is_empty():
		return false
	var name := str(op[0])
	var arg := 0
	if op.size() > 1:
		if not (typeof(op[1]) in [TYPE_INT, TYPE_FLOAT]) or float(int(op[1])) != float(op[1]):
			return false
		arg = int(op[1])
	match name:
		"weight":
			if op.size() != 2 or _committed or arg < 0 or arg >= _on.size():
				return false
			_on[arg] = not _on[arg]
			_steps += 1
		"poise":
			if op.size() != 2 or _committed or arg < 0 or arg > _poise_max or arg == _poise_step:
				return false
			_poise_step = arg
			_steps += 1
		"commit":
			if op.size() != 1 or _committed:
				return false
			_drag = false   # a drag still open here is dropped: beam, close-up and reading all use the poise step
			_committed = true
			_commits += 1
			_read_fen = _indicated()
			_quality_last = R.quality(_actual, _read_fen, _res, true)
		"again":
			if op.size() != 1 or not _committed:
				return false
			_drag = false
			_committed = false
			_agains += 1
			_call = 0
		"call":
			if op.size() != 2 or not _committed or arg < 1 or arg >= R.CALLS.size():
				return false
			_call = arg
		"done":
			if op.size() != 1:
				return false
		_:
			return false
	_ops.append([name, arg] if op.size() == 2 else [name])
	_minutes_spent = mini(_commits * MIN_COMMIT + _agains * MIN_AGAIN, maxi(0, int(params.get("max_minutes", 30))))
	if name == "done":
		_finish()
		return true
	_emit_tool(name)
	_refresh(name != "commit")
	return true


func ops_log() -> Array:
	return _ops.duplicate(true)


## skill = chance the call is right. Balance with the steady hand unless the draws say "read too early".
func autoplay(skill: float) -> void:
	if _done or not _started:
		return
	_drag = false
	var early := JevRng.draw(_seed, RNG_DOMAIN, [9000]) >= skill and JevRng.draw(_seed, RNG_DOMAIN, [9001]) < 0.5
	if not _committed:
		if not early:
			_phase = 0
			var guard := 0
			while not _level() and guard < 64:
				var op := _skilled_op()
				if op.is_empty() or not apply_op(op):
					break
				guard += 1
		apply_op(["commit"])
	var cat := R.answer(params)
	var pick := cat if JevRng.draw(_seed, RNG_DOMAIN, [9002]) < skill else R.neighbour(cat)
	apply_op(["call", R.call_index(pick)])
	apply_op(["done"])


## Esc and the host's "never mind": empty observations, only the minutes already spent.
func abort() -> void:
	if _done:
		return
	_done = true
	_drag = false
	_halt_beam()
	super.abort()


## The host's abort spot: right of "done" in the action row (b03 / b51 family).
func abort_rect() -> Rect2:
	return Chrome.abort_at(_panel, ABORT_SPOT.position, ABORT_SPOT.size.y)


func _finish() -> void:
	_done = true
	_drag = false
	_halt_beam()
	finished.emit({
		"quality_permille": _quality_last if _commits > 0 else R.Q_NONE,
		"observations": [R.obs_key(_call)],
		"minutes": minutes_spent(),
		"measures": {"read_fen": _read_fen, "steps": _steps, "commits": _commits, "call": _call},
		"aborted": false,
	})


# ---------------- physics (hidden weight stays here) ----------------

func _indicated() -> int:
	return _weight_sum() + _poise_step * _res


func _indicated_at(step: int) -> int:
	return _weight_sum() + step * _res


func _delta() -> int:
	return _actual - _indicated()


## Level = the needle stands straight: the step nearest the hidden weight, not "within one step".
func _level() -> bool:
	return R.off_steps(_actual, _indicated(), _res) == 0


func _near_level() -> bool:
	return absi(R.off_steps(_actual, _indicated(), _res)) <= 1


func _weight_sum() -> int:
	var s := 0
	for i in _weights.size():
		if _on[i]:
			s += _weights[i]
	return s


## Beam angle for a poise step: steep when far off, a hair when one or two steps off (the needle magnifies it).
## Counted in whole steps from the nearest one, so the best step is dead level even when the weight falls between
## two stars (old params, mocks); the engine puts real weights on a step.
func _tilt_at(step: int) -> float:
	var d := float(R.off_steps(_actual, _indicated_at(step), _res)) / TILT_SPAN_STEPS
	return -TILT_MAX * tanh(d)


# ---------------- setup ----------------

func _read_params() -> void:
	_seed = int(params.get("seed", 0))
	_tool = "steelyard" if str(params.get("tool", "dengzi")) == "steelyard" else "dengzi"
	_claimed = maxi(0, int(params.get("claimed_fen", 0)))
	_actual = maxi(0, int(params.get("actual_fen", 0)))
	_res = maxi(1, int(params.get("resolution_fen", 1)))
	_weights.clear()
	var src: Variant = params.get("weights_fen", [])
	if typeof(src) == TYPE_ARRAY:
		for i in mini(MAX_WEIGHTS, (src as Array).size()):
			_weights.append(maxi(0, int(src[i])))
	_on.clear()
	_on.resize(_weights.size())
	_zoom_k = clampi(int(params.get("zoom", R.DEFAULT_ZOOM)), 1, 4)
	_fine = bool(params.get("minor_ticks", R.DEFAULT_MINOR_TICKS))
	_gain = clampi(int(params.get("needle_gain", R.DEFAULT_NEEDLE_GAIN)), 1, 20)
	var cap_fen := R.poise_cap_fen(_tool, _weights, _claimed, _res, int(params.get("poise_fen", 0)))
	_poise_max = maxi(1, cap_fen / _res)
	_faces = PackedStringArray()
	for w in _weights:
		_faces.append(_wt(w))


func _layout_rng() -> void:
	var i := 0
	for n in _weights.size():
		_on[n] = JevRng.draw(_seed, RNG_DOMAIN, [i]) >= 0.5
		i += 1
	var u := JevRng.draw(_seed, RNG_DOMAIN, [i])
	_poise_step = clampi(floori(u * float(_poise_max + 1)), 0, _poise_max)
	_unstick()


## The opening is never level or one step off it (the player has to find it).
func _unstick() -> void:
	var guard := 0
	while _near_level() and guard < 48:
		if _poise_step + 4 <= _poise_max:
			_poise_step += 4
		elif _poise_step - 4 >= 0:
			_poise_step -= 4
		elif not _weights.is_empty():
			var k := guard % _weights.size()
			_on[k] = not _on[k]
		else:
			return
		guard += 1


## The steady hand (autoplay): poise home, all weights off, the biggest weights that still fit under the weight,
## then the poise to the step where the needle stands straight (it never stops one step off).
func _skilled_op() -> Array:
	if _phase == 0:
		_phase = 1
		if _poise_step != 0:
			return ["poise", 0]
	if _phase == 1:
		var big := _largest_on()
		if big >= 0:
			return ["weight", big]
		_phase = 2
	if _level():
		return []
	var room := _actual - _weight_sum()
	if _phase == 2:
		var idx := _best_weight_to_add(room)
		if idx >= 0:
			return ["weight", idx]
		_phase = 3
	if _phase == 3:
		_phase = 4
		var need := clampi(R.off_steps(room, 0, _res), 0, _poise_max)
		if need != _poise_step:
			return ["poise", need]
	return []


## The largest weight that does not overshoot the room left (the poise only reaches forward from home).
func _best_weight_to_add(room: int) -> int:
	if room <= 0:
		return -1
	var best := -1
	var best_v := -1
	for i in _weights.size():
		if _on[i] or _weights[i] <= 0 or _weights[i] > room:
			continue
		if _weights[i] > best_v:
			best_v = _weights[i]
			best = i
	return best


func _largest_on() -> int:
	var best := -1
	var best_v := -1
	for i in _weights.size():
		if _on[i] and _weights[i] > best_v:
			best_v = _weights[i]
			best = i
	return best


# ---------------- text ----------------

## One unit scheme for every weight on screen (weight faces, the claim, the rule for "a little"): X liang Y qian
## Z fen with the zero parts left out, so the player adds faces and stars straight against the claim.
## Faces are physical and the claim and the rule are what the player is told; the hidden weight never goes here.
func _wt(fen: int) -> String:
	var s := R.split(fen)
	var bits := (4 if int(s["liang"]) > 0 else 0) + (2 if int(s["qian"]) > 0 else 0) + (1 if int(s["fen"]) > 0 else 0)
	return CardText.ui(WT_KEYS[bits], {"liang": s["liang"], "qian": s["qian"], "fen": s["fen"]})


# ---------------- input ----------------

func _unhandled_input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey):
		return
	var e := event as InputEventKey
	if not e.pressed or e.echo:
		return
	var code := e.keycode if e.keycode != KEY_NONE else e.physical_keycode
	if code == KEY_ESCAPE:
		abort()
		get_viewport().set_input_as_handled()
		return
	if not (code in [KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_F] or (code >= KEY_1 and code <= KEY_9)):
		return
	# A key pressed while the poise is still held: put it down where the player sees it first (one poise op),
	# so Enter reads the stars the frozen beam shows and the arrows nudge from there.
	_drop_drag()
	if code == KEY_LEFT:
		apply_op(["poise", _poise_step - 1])
	elif code == KEY_RIGHT:
		apply_op(["poise", _poise_step + 1])
	elif code == KEY_ENTER or code == KEY_KP_ENTER:
		apply_op(["commit"])
	elif code == KEY_F:
		apply_op(["done"])
	else:
		apply_op(["weight", int(code) - int(KEY_1)])
	get_viewport().set_input_as_handled()


func _drop_drag() -> void:
	if not _drag:
		return
	_drag = false
	if not apply_op(["poise", _drag_step]):
		_refresh(true)


## Press on the beam picks the poise up, dragging moves it (the needle follows), release puts it down where it
## was last shown (the beam turns under the mouse while it swings, so the step is not measured again): one op.
func _on_beam_input(event: InputEvent) -> void:
	if _done or _committed:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag = true
			_drag_step = int(_beam.call("step_at", mb.position))
			_refresh(true)
		elif _drag:
			_drop_drag()
		_beam.accept_event()
	elif event is InputEventMouseMotion and _drag:
		var step2 := int(_beam.call("step_at", (event as InputEventMouseMotion).position))
		if step2 != _drag_step:
			_drag_step = step2
			_refresh(true)
		_beam.accept_event()


func _emit_tool(tool: String) -> void:
	var b := _resolve_bus()
	if b != null:
		b.ui_event.emit(&"mg_tool", {"kind": "weigh", "tool": tool})


func _resolve_bus() -> CardEventBus:
	if bus != null:
		return bus
	var n: Node = get_parent()
	while n != null:
		if n is CardMiniGameHost and (n as CardMiniGameHost).bus != null:
			return (n as CardMiniGameHost).bus
		n = n.get_parent()
	if is_inside_tree():
		var auto := get_node_or_null("/root/CardBus")
		if auto is CardEventBus:
			return auto as CardEventBus
	return null


# ---------------- view ----------------

func _clear_ui() -> void:
	_halt_beam()
	while get_child_count() > 0:
		var c := get_child(0)
		remove_child(c)
		c.free()
	_panel = null
	_beam = null
	_zoom = null
	_art = null
	_weights_box = null
	_calls_box = null
	_weight_btns.clear()
	_call_btns.clear()
	_commit_btn = null
	_again_btn = null
	_done_btn = null
	_nudge_in = null
	_nudge_out = null
	_marked = -1


func _halt_beam() -> void:
	if _beam != null and is_instance_valid(_beam):
		_beam.call("halt")


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = CardTheme.color(&"shade")
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.add_theme_stylebox_override("panel", Chrome.frame())
	_panel.clip_contents = true
	add_child(_panel)
	_build_header()
	_build_beam()
	_build_actions()
	_build_weights()
	_build_calls()
	CardAnchors.register(&"a.mg.weigh.main", _panel)
	CardAnchors.register(&"a.mg.weigh.beam", _beam)
	CardAnchors.register(&"a.mg.weigh.weights", _weights_box)
	if CardIds.is_known_anchor("a.mg.weigh.call"):
		CardAnchors.register(&"a.mg.weigh.call", _calls_box)


func _build_header() -> void:
	_panel.add_child(Chrome.title(CardText.ui("c14.title"), CardText.is_draft("c14.title"), PANEL_SIZE.x))
	var tool_key := "c14.tool.steelyard" if _tool == "steelyard" else "c14.tool.dengzi"
	_panel.add_child(_note(CardText.ui(tool_key), Rect2(34, 70, 460, 24), tool_key))
	var lab := Chrome.label(CardText.ui("c14.claimed", {"w": _wt(_claimed)}), 17, CardText.is_draft("c14.claimed"))
	_place(lab, Rect2(34, 94, 480, 30))
	lab.name = "Claimed"
	_panel.add_child(lab)
	# The shop's rule for the calls, in the claim's units (a rule of the game, not the hidden weight): how far
	# off still matches, and how light is only "a little". The small line is left out when there is no such band.
	var rule := _note(CardText.ui("c14.rule.match", {"w": _wt(_res)}), RULE_MATCH_RECT, "c14.rule.match")
	rule.name = "RuleMatch"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(rule)
	var small := R.small_fen(params)
	if small > _res:
		var rule2 := _note(CardText.ui("c14.rule.small", {"w": _wt(small)}), RULE_SMALL_RECT, "c14.rule.small")
		rule2.name = "RuleSmall"
		rule2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_panel.add_child(rule2)


func _build_beam() -> void:
	_panel.add_child(Chrome.plate(Chrome.inset(), BEAM_RECT.position, BEAM_RECT.size))
	_beam = _BEAM.new()
	_beam.name = "Beam"
	_beam.position = BEAM_RECT.position
	_beam.size = BEAM_RECT.size
	_beam.custom_minimum_size = BEAM_RECT.size
	_beam.mouse_filter = Control.MOUSE_FILTER_STOP
	_beam.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_beam.clip_contents = true
	_beam.set("fast", _fast)
	_panel.add_child(_beam)
	_beam.gui_input.connect(_on_beam_input)
	_art = TextureRect.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_setup_art()
	_beam.add_child(_art)
	_beam.call("set_art", _art)
	_build_legend()
	_nudge_in = _button(CardText.ui("c14.btn.poise_in"), Rect2(BEAM_RECT.position + NUDGE_IN_RECT.position, NUDGE_IN_RECT.size))
	_nudge_in.theme_type_variation = &"SmallButton"
	_nudge_in.name = "NudgeIn"
	_nudge_in.pressed.connect(func() -> void: apply_op(["poise", _poise_step - 1]))
	_panel.add_child(_nudge_in)
	_nudge_out = _button(CardText.ui("c14.btn.poise_out"), Rect2(BEAM_RECT.position + NUDGE_OUT_RECT.position, NUDGE_OUT_RECT.size))
	_nudge_out.theme_type_variation = &"SmallButton"
	_nudge_out.name = "NudgeOut"
	_nudge_out.pressed.connect(func() -> void: apply_op(["poise", _poise_step + 1]))
	_panel.add_child(_nudge_out)
	_zoom = _ZOOM.new()
	_zoom.name = "Zoom"
	_place(_zoom, Rect2(BEAM_RECT.position + ZOOM_RECT.position, ZOOM_RECT.size))
	_zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom.visible = false
	_zoom.add_child(_note(CardText.ui("c14.cap.zoom"), Rect2(8, 4, 200, 20), "c14.cap.zoom"))
	_panel.add_child(_zoom)


## How to read this scale, top left of the beam (left of the lifting cord on both tools): what a big star and a
## small dot are worth here, and that a reading is the hook weights plus the stars at the poise cord. Rules of
## the scale, the same for every piece; never the hidden weight.
func _build_legend() -> void:
	var star_key := "c14.star.liang" if R.major_fen(_tool, _res) >= 100 else "c14.star.qian"
	var rows := [
		[star_key, CardText.ui(star_key), "LegendStar"],
		["c14.legend.dot", CardText.ui("c14.legend.dot", {"w": _wt(R.minor_fen(_tool, _res, _fine))}), "LegendDot"],
		["c14.legend.cord", CardText.ui("c14.legend.cord"), "LegendCord"],
		["c14.legend.sum", CardText.ui("c14.legend.sum"), "LegendSum"],
	]
	for i in rows.size():
		var l := _note(str(rows[i][1]), Rect2(LEGEND_POS + Vector2(0, LEGEND_PITCH * i), LEGEND_SIZE), str(rows[i][0]))
		l.name = str(rows[i][2])
		_beam.add_child(l)


func _setup_art() -> void:
	var id := str(params.get("art", ""))
	var tex := CardArt.texture(id)
	_art.texture = tex
	_art.visible = tex != null
	var base := CardArt.base_size(id)
	if base.x <= 0 or base.y <= 0:
		base = Vector2i(48, 48)
	var k := 2
	while k > 1 and (base.x * k > 140 or base.y * k > 96):
		k -= 1
	var sz := Vector2(base * k)
	_art.custom_minimum_size = sz
	_art.size = sz
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE


func _build_actions() -> void:
	_commit_btn = _button(CardText.ui("c14.btn.commit"), COMMIT_RECT)
	_commit_btn.name = "Commit"
	_commit_btn.pressed.connect(func() -> void: apply_op(["commit"]))
	_panel.add_child(_commit_btn)
	_again_btn = _button(CardText.ui("c14.btn.again"), AGAIN_RECT)
	_again_btn.name = "Again"
	_again_btn.pressed.connect(func() -> void: apply_op(["again"]))
	_panel.add_child(_again_btn)
	_done_btn = _button(CardText.ui("c14.btn.done"), DONE_RECT)
	_done_btn.name = "Done"
	_done_btn.theme_type_variation = &"PrimaryButton"
	_done_btn.pressed.connect(func() -> void: apply_op(["done"]))
	_panel.add_child(_done_btn)
	var hint := _note(CardText.ui("c14.tool.poise"), HINT_RECT, "c14.tool.poise")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(hint)


func _build_weights() -> void:
	_weights_box = Control.new()
	_weights_box.name = "Weights"
	var n := _weights.size()
	var w := maxf(WEIGHT_SIZE.x, float(n) * WEIGHT_PITCH - (WEIGHT_PITCH - WEIGHT_SIZE.x))
	_place(_weights_box, Rect2(34, WEIGHT_Y, w, WEIGHT_SIZE.y))
	_weights_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_weights_box)
	for i in n:
		var b := _button(_faces[i], Rect2(i * WEIGHT_PITCH, 0, WEIGHT_SIZE.x, WEIGHT_SIZE.y))
		b.name = "Weight%d" % i
		b.pressed.connect(func() -> void: apply_op(["weight", i]))
		_weights_box.add_child(b)
		_weight_btns.append(b)
	var cap_x := 34.0 + float(n) * WEIGHT_PITCH
	if 966.0 - cap_x >= 130.0:
		var cap := _note(CardText.ui("c14.tool.weight"), Rect2(cap_x, WEIGHT_Y + 12.0, 966.0 - cap_x, 22), "c14.tool.weight")
		_panel.add_child(cap)


func _build_calls() -> void:
	_calls_box = Control.new()
	_calls_box.name = "Calls"
	_place(_calls_box, Rect2(34, CALL_Y, 4.0 * CALL_PITCH + CALL_SIZE.x, CALL_SIZE.y))
	_calls_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_calls_box)
	for c in range(1, R.CALLS.size()):
		var key := "c14.call." + R.CALLS[c]
		var b := _button(CardText.ui(key), Rect2(float(c - 1) * CALL_PITCH, 0, CALL_SIZE.x, CALL_SIZE.y))
		b.name = "Call%d" % c
		b.pressed.connect(func() -> void: apply_op(["call", c]))
		_calls_box.add_child(b)
		_call_btns.append(b)


func _note(text: String, r: Rect2, ref: String) -> Label:
	var l := Chrome.note(text, ref != "" and CardText.is_draft(ref))
	_place(l, r)
	l.clip_text = true
	return l


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size
	c.custom_minimum_size = r.size


func _button(text: String, r: Rect2) -> Button:
	var b := Chrome.button(text)
	_place(b, r)
	b.add_theme_font_size_override("font_size", 16)
	b.clip_text = true
	return b


## The player's own pick is marked in the player's pen (gold_hi edge and ink); nothing says right or wrong.
func _mark_call(b: Button, on: bool) -> void:
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.remove_theme_stylebox_override(st)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.remove_theme_color_override(fc)
	if not on:
		return
	var sb := CardTheme.button_style(&"btn_hover_top", &"btn_top", &"gold_hi")
	sb.set_border_width_all(3)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, sb)
	for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(fc, CardTheme.color(&"gold_hi"))


func _refresh(animate: bool) -> void:
	var step := _drag_step if _drag else _poise_step
	if _beam != null and is_instance_valid(_beam):
		var hook := PackedStringArray()
		for i in _weights.size():
			if _on[i]:
				hook.append(_faces[i])
		_beam.call("sync", {
			"tool": _tool,
			"poise_step": step,
			"poise_max": _poise_max,
			"resolution": _res,
			"major": R.major_fen(_tool, _res),
			"minor": R.minor_fen(_tool, _res, _fine),
			"needle_gain": _gain,
			"frozen": _committed,
			"hook": hook,
			"tilt": _tilt_at(step),
			"animate": animate,
			# The star close-up sits over the far end of the beam: star numbers under it are not drawn (no cut glyphs).
			"cover": ZOOM_RECT if _committed else Rect2(),
		})
	if _zoom != null:
		_zoom.visible = _committed
		_zoom.call("sync", {
			"tool": _tool,
			"poise_fen": _poise_step * _res,
			"cap_fen": _poise_max * _res,
			"resolution": _res,
			"major": R.major_fen(_tool, _res),
			"minor": R.minor_fen(_tool, _res, _fine),
			"zoom": _zoom_k,
		})
	for i in _weight_btns.size():
		_weight_btns[i].disabled = _committed
		_weight_btns[i].modulate = Color(1, 1, 1, 0.4) if _on[i] else Color(1, 1, 1, 1)
	if _nudge_in != null:
		_nudge_in.disabled = _committed or _poise_step <= 0
		_nudge_out.disabled = _committed or _poise_step >= _poise_max
	if _commit_btn != null:
		_commit_btn.disabled = _committed
		_again_btn.disabled = not _committed
	var mark := _call if _committed else 0
	for i in _call_btns.size():
		_call_btns[i].disabled = not _committed
		if mark != _marked:
			_mark_call(_call_btns[i], mark == i + 1)
	_marked = mark
