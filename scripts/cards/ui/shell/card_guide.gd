# Guide overlay engine (root of GuideOverlay.tscn): picks steps, glows the anchor, shows the teacher's
# speech bubble, keeps progress (ui.guide) and the on/off switch.
# Looks and feels like the web prototype (docs/cards/prototype/scene_demo.html, #guide/.gbub):
#   one paper bubble at a time = teacher portrait + name + the whole wrapped line, a breathing gold/red
#   ring on the anchor, a person teacher standing at the counter side (GUIDE_TEACHER), and two buttons:
#   "got it" (shows "N more" when other steps are waiting) and "turn the guide off".
# Only those two buttons take the mouse; every other node ignores it. No key input. The engine never
# pauses; the guide sends no command except ui.guide. A step stays until "got it", until the player
# does one of its done_when things, or (seconds > 0 only) until its timeout.
# Robustness (TUTORIAL.md P0/P1): a heartbeat re-picks every POLL_S, so steps whose anchor appears
# later still light; steps bound to a panel/overlay pre-empt a free-floating step; table steps wait
# while an overlay/minigame covers the table; a phase that has passed marks its unshown steps skipped,
# and trigger.after accepts done or skipped.
# Owner C16. Contract: docs/cards/CARDS_INTERFACES.md section 7.10.7 (and the 10-22 prototype note).
class_name CardGuide
extends Control

const VIEW_W := 1280.0
const VIEW_H := 720.0
const PAD := 8.0
## Heartbeat: re-pick this often while idle; refresh the "N more" count and placement while showing.
const POLL_S := 0.25
## After "got it" the next waiting bubble follows this quickly (prototype: at once).
const ACK_GAP_S := 0.3
## A step that loses its anchor (or its phase) after this long on screen counts as shown once.
const SEEN_S := 2.0
## Prototype bubble: 520 wide; content padding 12 x 14; portrait column 64 x 84 inside a 2 px frame.
const BUBBLE_W := 520.0
const BUBBLE_MAIN := Vector2(444, 384)
const PAD_X := 14.0
const PAD_Y := 12.0
const PIC_BOX := Vector2(68, 88)
const PIC_CROP := Rect2(8, 4, 32, 42)
const ICON_BOX := Vector2(48, 48)
const TEXT_SIZE := 16
const NOTE_SIZE := 18
const WHO_SIZE := 14
const BTN_SIZE := 14
const BTN_H := 30.0
const TOP_Y := 36.0
## A hovered hand card rises to this y (hand_fan.gd HOVER_TOP); the bubble keeps clear of it.
const FAN_LIFT_TOP := 380.0
const SETTINGS_SCRIPT := "res://scripts/town/settings.gd"
const PERSON_TEACHERS: Array[String] = ["brother", "zhouma", "hu2", "suanming", "postman"]
## Anchors that live on the table (scene, HUD, hand, dialog, counter checks). An overlay or a minigame
## covers them; a side drawer covers the ones under it.
const TABLE_ANCHORS: Array[String] = ["a.hand", "a.top.", "a.btn.", "a.card", "a.slots.first", "a.slots.coins",
	"a.slots.roll", "a.slots.money", "a.slots.choices", "a.counter.item", "a.counter.look", "a.counter.tier.",
	"a.counter.reply", "a.counter.redeem", "a.demand.modes", "a.demand.delay", "a.almanac", "a.fortune.",
	"a.night.", "a.settle.", "a.street.", "a.prison.", "a.scene", "a.tab.", "a.hero", "a.contacts", "a.pet",
	"a.dialog"]
## What may light while a covering surface is on top (kind -> anchor prefixes). Unknown kinds allow any
## non-table anchor.
const SURFACE_ANCHORS := {
	"minigame": ["a.mg."], "wheel": ["a.wheel."], "end_day": ["a.endday."], "month_open": ["a.month."],
	"month_close": ["a.mclose."], "year_jump": ["a.year."], "game_over": ["a.over."],
	"short": ["a.short.", "a.estate."], "contacts_full": ["a.slots.release"], "kept_full": ["a.slots.discard"],
	"help": ["a.help."], "pause": ["a.pause."], "settings": ["a.settings."],
	"dossier": ["a.dossier.", "a.help.rules"],
	# Stage kinds whose panel is not a CardStagePanel open as an overlay (CardModalHost.open_panel):
	# their own anchors stay allowed there.
	"fortune": ["a.fortune."], "demand": ["a.demand."], "prison": ["a.prison."], "night": ["a.night."],
	"settle": ["a.settle."], "slots": ["a.slots."], "counter": ["a.counter.", "a.dialog"], "read": [],
	# Rogue v1 stocktake overlay: only its own anchors (none taught in v1), so table hints wait until it closes.
	"stocktake": ["a.stock."],
}
## Drawer kinds that draw a full-screen book/box (button audit b21/b22): treated like an overlay.
const FULL_DRAWERS: Array[String] = ["dossier", "settings"]

## Test hook: step ids in the order they lit this run.
var shown_log: PackedStringArray = []
## Test hook: fades and gaps count as 0; time moves only through explicit tick() (no _process).
var skip_fades: bool = false

var engine: CardEngineApi = null
var bus: CardEventBus = null

var _setting_on: bool = true
var _cmdline: int = -1
var _forced: int = -1
var _bound: bool = false
var _dirty: bool = true

var _compiled: Array = []
var _by_first: Dictionary = {}
var _by_token: Dictionary = {}
var _no_first: Array = []
var _settings: Dictionary = {}
var _gap_s: float = 2.0
var _fade_in_s: float = 0.3
var _fade_out_s: float = 0.7
var _fade_fast_s: float = 0.25
var _default_seconds: int = 16
var _max_new: int = 16

var _progress: Dictionary = {}
var _firsts: Dictionary = {}
var _open_panels: Dictionary = {}
var _overlay_stack: Array = []
var _drawer_kind: String = ""
var _view: Dictionary = {}
var _cur = null
var _anchor_id: StringName = &""
## Tests read the current anchor through this stable name.
var _anchor_now: StringName:
	get:
		return _anchor_id
## After load_steps, game.new no longer overwrites the test's steps with the engine's guide data.
var _external_steps: bool = false
## Steps that were on screen and stepped aside (overlay, context, phase): a later done_when finishes them.
var _started: Dictionary = {}
## Steps whose phase window passed without lighting; trigger.after treats them as passed.
var _skipped: Dictionary = {}
var _glow_rect: Rect2 = Rect2()
var _t_active: float = 0.0
var _gap: float = 0.0
var _poll_t: float = 0.0
## Guide time (real time, or the test's tick time): when each mechanism first fired, when the bubble lit.
var _clock: float = 0.0
var _first_at: Dictionary = {}
var _shown_at: float = 0.0
var _today: int = -1
var _new_today: int = 0
var _scan_best = null
var _surf: String = ""
var _drawer_rect: Rect2 = Rect2()
var _game_ref: WeakRef = null
var _more: int = -1
var _spot: Vector2 = Vector2(-1, -1)

var _fade: float = 0.0
var _fade_from: float = 0.0
var _fade_to: float = 0.0
var _fade_dur: float = 0.0
var _fade_t: float = 0.0
var _pulse: float = 0.5
var _pulse_tw: Tween = null
var _queue: Array = []
var _flush_queued: bool = false
var _styled: bool = false
var _note_style: bool = false

var _chrome: Control
var _glow: Control
var _teacher: TextureRect
var _bubble: Panel
var _pic: Panel
var _pic_tex: TextureRect
var _who: Label
var _text: Label
var _ok: Button
var _off: Button
var _flash: PanelContainer
var _flash_text: Label
var _flash_tw: Tween = null

var _sb_plain: StyleBoxFlat
var _sb_note: StyleBoxFlat
var _font_bold: FontVariation
var _hl_gold: Color = Color(1, 1, 1, 1)
var _hl_red: Color = Color(1, 1, 1, 1)


class Compiled:
	extends RefCounted
	var raw: Dictionary = {}
	var index: int = 0
	var id: String = ""
	var priority: int = 50
	var max_shows: int = 2
	var seconds: float = 16.0
	var interrupt: bool = false
	var contextual: bool = false
	var anchor: String = ""
	var fallback: String = ""
	var anchor_uid: bool = false
	var fallback_uid: bool = false
	var teacher: String = ""
	var first: String = ""
	var phases: PackedStringArray = PackedStringArray()
	var mode: String = ""
	var has_stage: bool = false
	var stage_gte: int = 0
	var has_stage_day: bool = false
	var stage_day_gte: int = 0
	var has_abs: bool = false
	var abs_day_gte: int = 0
	var after: PackedStringArray = PackedStringArray()
	var panel: String = ""
	var hand_clear: bool = false
	var has_cond: bool = false
	var done: PackedStringArray = PackedStringArray()
	var done_map: Dictionary = {}
	var has_first_done: bool = false
	var resolved: String = ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_chrome()


func _ready() -> void:
	add_to_group("card_guide")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_chrome()
	_seal(self)


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	engine = p_engine
	bus = p_bus
	if _bound:
		_rebuild()
		return
	_bound = true
	bus.first_time.connect(_on_first)
	bus.command_done.connect(_on_cmd)
	bus.ui_event.connect(_on_ui)
	bus.view_changed.connect(_on_view)
	bus.phase_changed.connect(_on_phase)
	_rebuild()


func set_enabled(on: bool) -> void:
	_setting_on = on
	if not is_enabled():
		_dismiss()
	else:
		_dirty = true


func is_enabled() -> bool:
	if _forced >= 0:
		return _forced == 1
	if _cmdline >= 0:
		return _cmdline == 1
	return _setting_on


func force(on: bool) -> void:
	_forced = 1 if on else 0
	if not is_enabled():
		_dismiss()
	else:
		_dirty = true


func evaluate_now() -> void:
	_read_view()
	_dirty = true
	_pick(true)


func active_step() -> String:
	if _cur == null:
		return ""
	return _cur.id


func tick(delta_s: float) -> void:
	if not is_enabled():
		return
	if _fade_dur > 0.0:
		_advance_fade(delta_s)
	_clock += delta_s
	_poll_t -= delta_s
	var poll := _poll_t <= 0.0
	if poll:
		_poll_t = POLL_S
	if _cur != null:
		_tick_current(delta_s)
		if _cur != null and (poll or _dirty or skip_fades):
			_pick(false)
			_refresh_live()
		return
	if _gap > 0.0:
		if skip_fades:
			_gap = 0.0
		else:
			_gap = maxf(0.0, _gap - delta_s)
			if _gap > 0.0:
				if poll or _dirty:
					_pick_contextual()
				return
			_dirty = true
	if _dirty or skip_fades or poll:
		_pick(false)


func load_steps(data: Dictionary) -> void:
	_external_steps = true
	_apply_steps(data)
	_dirty = true


## "Got it": the showing step is done; the next waiting one follows after ACK_GAP_S.
## The bubble's Ok button calls it; autoplay and tests may too.
func acknowledge() -> void:
	if _cur == null:
		return
	_complete()
	_gap = 0.0 if skip_fades else ACK_GAP_S


## True while a bubble shows or a step could light now (the morning auto-start can wait on it).
func is_pending() -> bool:
	if not is_enabled():
		return false
	if _cur != null:
		return true
	if _compiled.is_empty():
		return false
	# Same gates as _pick: a step held back by the daily cap would never light, so nothing waits on it.
	_roll_day()
	if _new_today >= _max_new:
		return false
	_refresh_surface()
	return _best("") != null


## A panel registered or dropped an anchor outside any bus event (month_open turning to its goals page).
func anchors_changed() -> void:
	_dirty = true
	_poll_t = 0.0


func _apply_steps(data: Dictionary) -> void:
	var steps = data.get("steps", [])
	var settings = data.get("settings", {})
	_settings = settings.duplicate(true) if typeof(settings) == TYPE_DICTIONARY else {}
	_cache_timings()
	_compile(steps if typeof(steps) == TYPE_ARRAY else [])


func set_cmdline(mode: String) -> void:
	if mode == "on":
		_cmdline = 1
	elif mode == "off":
		_cmdline = 0
	else:
		_cmdline = -1
	if not is_enabled():
		_dismiss()


func _process(delta: float) -> void:
	if skip_fades:
		return
	if not is_enabled() or _compiled.is_empty():
		return
	tick(delta)


# ---------------- bookkeeping ----------------
func _rebuild() -> void:
	if engine == null:
		return
	if not _external_steps:
		var data = engine.query(&"guide_data")
		if typeof(data) == TYPE_DICTIONARY:
			_apply_steps(data)
	_merge_firsts(engine.query(&"firsts"))
	var prog = engine.query(&"guide_progress")
	_progress = {}
	if typeof(prog) == TYPE_DICTIONARY and typeof(prog.get("progress")) == TYPE_DICTIONARY:
		_progress = (prog["progress"] as Dictionary).duplicate(true)
	_started = {}
	_skipped = {}
	_read_view()
	if _cur != null:
		_cur = null
		_anchor_id = &""
		_hide_chrome()
	_dirty = true


func _merge_firsts(q: Dictionary) -> void:
	var src = q.get("firsts")
	if typeof(src) != TYPE_DICTIONARY:
		return
	var keep: Dictionary = {}
	for m in src.keys():
		var key := str(m)
		var old = _firsts.get(key)
		keep[key] = old if typeof(old) == TYPE_DICTIONARY else {}
	_firsts = keep


func _on_first(mech: StringName, args: Dictionary) -> void:
	_firsts[str(mech)] = args.duplicate()
	_first_at[str(mech)] = _clock
	_dirty = true
	_remember("first:" + str(mech))


func _on_cmd(cmd: StringName, _args: Dictionary, ok: bool) -> void:
	if not ok:
		return
	var name := str(cmd)
	if name == "game.new" or name == "game.load" or name == "game.retry_stage":
		_rebuild()
	_dirty = true
	_remember("cmd:" + name)


func _on_ui(ev_name: StringName, args: Dictionary) -> void:
	if ev_name == &"guide_shown" or ev_name == &"guide_done":
		return
	_dirty = true
	var kind := str(args.get("kind", ""))
	if ev_name == &"panel_opened" or ev_name == &"panel_closed":
		_track_surface(ev_name == &"panel_opened", kind, str(args.get("show", "")))
	if ev_name == &"panel_opened":
		_open_panels[kind] = int(_open_panels.get(kind, 0)) + 1
	_remember("ui:" + str(ev_name))
	if ev_name == &"panel_opened":
		_remember("panel:" + kind)
	elif ev_name == &"panel_closed":
		_open_panels[kind] = maxi(0, int(_open_panels.get(kind, 0)) - 1)


## Without a CardGameRoot above us (tests), remember overlays and drawers from the panel events.
func _track_surface(opened: bool, kind: String, show: String) -> void:
	if show == "":
		show = str(CardIds.PANEL_SHOW.get(StringName(kind), &"overlay"))
	if show == "overlay" or show == "host":
		if opened:
			_overlay_stack.append(kind)
		else:
			var at := _overlay_stack.rfind(kind)
			if at >= 0:
				_overlay_stack.remove_at(at)
	elif show.begins_with("drawer"):
		if opened:
			_drawer_kind = kind
		elif _drawer_kind == kind:
			_drawer_kind = ""


func _on_view(_topics: PackedStringArray) -> void:
	_read_view()
	_dirty = true
	_pick.call_deferred(false)


func _on_phase(from: StringName, to: StringName) -> void:
	var was := str(from)
	var now := str(to)
	_view["phase"] = now
	_dirty = true
	_gap = 0.0
	# A showing step whose phase ended steps aside on the next tick, after the command that changed the
	# phase has reported (its done_when, e.g. cmd:day.begin, comes after phase_changed).
	for item in _compiled:
		var step: Compiled = item
		if step.phases.size() == 0 or not step.phases.has(was) or step.phases.has(now):
			continue
		if _is_done(step.id) or _shows_of(step.id) > 0:
			continue
		if step.first == "" or _firsts.has(step.first):
			_skipped[step.id] = true


func _remember(token: String) -> void:
	if _cur != null and _cur.done_map.has(token):
		_complete()
	var rows = _by_token.get(token)
	if rows == null:
		return
	for item in rows:
		var step: Compiled = item
		if (_cur != null and step == _cur) or _is_done(step.id):
			continue
		# Done if it was on screen before, or if it is a panel step whose moment is now (the player
		# already did what it would teach: do not teach it afterwards).
		if _started.has(step.id) or (step.panel != "" and _trigger(step)):
			_started.erase(step.id)
			_auto_done(step)


func _read_view() -> void:
	if engine == null:
		return
	var v = engine.view()
	if typeof(v) == TYPE_DICTIONARY:
		_view = v


# ---------------- surfaces: what covers the table ----------------
func _game() -> CardGameRoot:
	if _game_ref != null:
		var g = _game_ref.get_ref()
		if g != null:
			return g
	var n := get_parent()
	while n != null:
		if n is CardGameRoot:
			_game_ref = weakref(n)
			return n
		n = n.get_parent()
	return null


func _refresh_surface() -> void:
	_surf = ""
	_drawer_rect = Rect2()
	var g := _game()
	if g != null:
		if g.mg_host != null and g.mg_host.is_active():
			_surf = "minigame"
			return
		if g.host == null:
			return
		if g.host.top_overlay() != null:
			_surf = str(g.host.top_kind())
			return
		if g.host.drawer_open():
			_set_drawer(str(g.host.top_kind()))
		return
	if not _overlay_stack.is_empty():
		_surf = str(_overlay_stack.back())
		return
	if _drawer_kind != "":
		_set_drawer(_drawer_kind)


func _set_drawer(kind: String) -> void:
	if FULL_DRAWERS.has(kind):
		_surf = kind
		return
	var show := str(CardIds.PANEL_SHOW.get(StringName(kind), &""))
	_drawer_rect = CardLayout.DRAWER_L if show == "drawer_l" else CardLayout.DRAWER_R


static func _is_table(anchor_id: String) -> bool:
	for p in TABLE_ANCHORS:
		if anchor_id.begins_with(p):
			return true
	return false


## The anchor may light on the current surface (not hidden behind an overlay, minigame or drawer).
func _allowed(anchor_id: String) -> bool:
	var table := _is_table(anchor_id)
	if _surf == "":
		if table and _drawer_rect.has_area():
			return not _drawer_rect.has_point(CardAnchors.rect(StringName(anchor_id)).get_center())
		return true
	var pre = SURFACE_ANCHORS.get(_surf)
	if pre == null:
		return not table
	for p in pre:
		if anchor_id.begins_with(str(p)):
			return true
	return false


# ---------------- picking ----------------
func _pick(now: bool) -> void:
	if not is_enabled() or _compiled.is_empty():
		_dirty = false
		return
	_refresh_surface()
	if _cur != null and not _anchor_still():
		# The step on screen lost its anchor or got covered since the last tick: settle that first.
		if _covered(_cur):
			_step_aside(false)
		else:
			_drop_anchor()
			if not now and not skip_fades:
				return
	if _cur != null:
		var challenger = _best(_cur.id)
		if challenger != null:
			if challenger.interrupt and challenger.priority > _cur.priority:
				_cancel_current()
			else:
				_step_aside(false)
			_show(challenger)
		_dirty = false
		return
	if not now and not skip_fades and _gap > 0.0:
		return
	_roll_day()
	if _new_today >= _max_new:
		_dirty = false
		return
	var best = _best("")
	_dirty = false
	if best != null:
		_show(best)


## During the gap only a step bound to what the player just opened may light (no waiting there).
func _pick_contextual() -> void:
	if not is_enabled() or _compiled.is_empty():
		return
	_refresh_surface()
	_roll_day()
	if _new_today >= _max_new:
		return
	var best = _best("")
	if best != null and best.contextual:
		_gap = 0.0
		_show(best)


func _best(except_id: String):
	_scan_best = null
	_scan(_no_first, except_id)
	for mech in _firsts.keys():
		var row = _by_first.get(str(mech))
		if row != null:
			_scan(row, except_id)
	var found = _scan_best
	_scan_best = null
	return found


func _scan(list: Array, except_id: String) -> void:
	for item in list:
		var step: Compiled = item
		if step.id == except_id:
			continue
		var can := _cur == null or _can_challenge(step)
		if not step.has_first_done:
			if not can:
				continue
			if _scan_best != null and (step.priority < _scan_best.priority or (step.priority == _scan_best.priority and step.index > _scan_best.index)):
				continue
		if not _passes(step):
			continue
		if not can:
			continue
		if _scan_best == null or step.priority > _scan_best.priority:
			_scan_best = step
		elif step.priority == _scan_best.priority and step.index < _scan_best.index:
			_scan_best = step


## Who may take the bubble from the step on screen: an interrupt step of higher priority; a step bound
## to what the player has open (panel/overlay) over a free-floating one; and over a free-floating one,
## a step whose mechanism happened after it lit (the player moved on; teach what just happened).
func _can_challenge(step: Compiled) -> bool:
	if step.interrupt and step.priority > _cur.priority:
		return true
	if _cur.contextual:
		return false
	if step.contextual:
		return true
	return step.first != "" and float(_first_at.get(step.first, -1.0)) > _shown_at


func _passes(step: Compiled) -> bool:
	if _is_done(step.id):
		return false
	if _shows_of(step.id) >= step.max_shows:
		return false
	if not _trigger(step):
		return false
	var anchor := _resolve(step)
	if anchor == "":
		return false
	if _should_auto(step):
		_auto_done(step)
		return false
	step.resolved = anchor
	return true


func _trigger(step: Compiled) -> bool:
	if step.first != "" and not _firsts.has(step.first):
		return false
	if step.phases.size() > 0 and not _phase_hit(step):
		return false
	if step.mode != "" and step.mode != str(_view.get("mode", "shop")):
		return false
	if not _date_ok(step):
		return false
	if not _after_ok(step):
		return false
	if step.panel != "" and int(_open_panels.get(step.panel, 0)) <= 0:
		return false
	if step.hand_clear and not _hand_is_clear():
		return false
	if step.has_cond and not _cond_ok(step.id):
		return false
	return true


func _phase_hit(step: Compiled) -> bool:
	var ph := str(_view.get("phase", ""))
	for p in step.phases:
		if p == ph:
			return true
	return false


func _date_ok(step: Compiled) -> bool:
	if not step.has_stage and not step.has_stage_day and not step.has_abs:
		return true
	var date = _view.get("date")
	var stage := 0
	var stage_day := 0
	var abs_day := 0
	if typeof(date) == TYPE_DICTIONARY:
		stage = int(date.get("stage", 0))
		stage_day = int(date.get("stage_day", 0))
		abs_day = int(date.get("abs_day", 0))
	if step.has_stage and stage < step.stage_gte:
		return false
	if step.has_stage_day and stage_day < step.stage_day_gte:
		return false
	if step.has_abs and abs_day < step.abs_day_gte:
		return false
	return true


func _after_ok(step: Compiled) -> bool:
	for a in step.after:
		if _skipped.has(a):
			continue
		var row = _progress.get(a)
		if typeof(row) != TYPE_DICTIONARY or str(row.get("status", "")) != "done":
			return false
	return true


func _hand_is_clear() -> bool:
	var hand = _view.get("hand")
	if typeof(hand) != TYPE_ARRAY:
		return true
	for c in hand:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		if bool(c.get("must_resolve", false)) and not bool(c.get("gold", false)):
			return false
	return true


func _cond_ok(id: String) -> bool:
	if engine == null:
		return false
	var ans: Dictionary = engine.query(&"guide_conds", {"ids": [id]})
	return bool(ans.get(id, false))


func _should_auto(step: Compiled) -> bool:
	if not step.has_first_done:
		return false
	for tok in step.done:
		var s := str(tok)
		if s.begins_with("first:") and _firsts.has(s.substr(6)):
			return true
	return false


func _auto_done(step: Compiled) -> void:
	_set_done(step.id)
	_enqueue(step.id, "done")


## Primary anchor, else the fallback; each must exist and not be hidden behind the top surface.
func _resolve(step: Compiled) -> String:
	var uid := _uid_of(step.first) if (step.anchor_uid or step.fallback_uid) else ""
	var primary := _fill(step.anchor, uid, step.anchor_uid)
	if primary != "" and CardAnchors.has(StringName(primary)) and _allowed(primary):
		return primary
	var spare := _fill(step.fallback, uid, step.fallback_uid)
	if spare != "" and CardAnchors.has(StringName(spare)) and _allowed(spare):
		return spare
	return ""


## Some anchor of the step exists, but the top surface hides it.
func _covered(step: Compiled) -> bool:
	var uid := _uid_of(step.first) if (step.anchor_uid or step.fallback_uid) else ""
	for pat in [_fill(step.anchor, uid, step.anchor_uid), _fill(step.fallback, uid, step.fallback_uid)]:
		if str(pat) != "" and CardAnchors.has(StringName(str(pat))):
			return true
	return false


func _uid_of(mech: String) -> String:
	if mech == "":
		return ""
	var args = _firsts.get(mech)
	if typeof(args) != TYPE_DICTIONARY:
		return ""
	return str(args.get("uid", ""))


func _fill(pat: String, uid: String, has_uid: bool) -> String:
	if pat == "":
		return ""
	if not has_uid:
		return pat
	if uid == "":
		return ""
	return pat.replace("{uid}", uid)


func _roll_day() -> void:
	var day := _abs_day()
	if day != _today:
		_today = day
		_new_today = 0


func _abs_day() -> int:
	var date = _view.get("date")
	if typeof(date) != TYPE_DICTIONARY:
		return 0
	return int(date.get("abs_day", 0))


# ---------------- show, finish, step aside ----------------
func _show(step: Compiled) -> void:
	_cur = step
	_anchor_id = StringName(step.resolved)
	_t_active = 0.0
	_shown_at = _clock
	_gap = 0.0
	_new_today += 1
	_glow_rect = Rect2()
	_started.erase(step.id)
	shown_log.append(step.id)
	var prog: Dictionary = _progress.get(step.id, {})
	prog["shows"] = int(prog.get("shows", 0)) + 1
	prog["status"] = "shown"
	prog["abs_day"] = _today
	_progress[step.id] = prog
	_enqueue(step.id, "shown")
	if bus != null:
		bus.ui_event.emit(&"guide_shown", {"step": step.id})
	_apply_copy(step)
	_refresh_more()
	_layout(true)
	_layout_later.call_deferred()
	_start_fade(1.0, _fade_in_s)
	_start_pulse()


func _complete() -> void:
	if _cur == null:
		return
	var id: String = _cur.id
	_set_done(id)
	_enqueue(id, "done")
	if bus != null:
		bus.ui_event.emit(&"guide_done", {"step": id})
	_cur = null
	_anchor_id = &""
	_start_fade(0.0, _fade_out_s)
	_gap = _gap_s
	_dirty = true


func _expire() -> void:
	_cur = null
	_anchor_id = &""
	_start_fade(0.0, _fade_out_s)
	_gap = _gap_s
	_dirty = true


## Interrupted by a higher-priority interrupt step: not counted, may light again.
func _cancel_current() -> void:
	if _cur == null:
		return
	_uncount(_cur.id)
	_cur = null
	_anchor_id = &""
	_hide_chrome()
	_fade_dur = 0.0


## The step steps aside without being finished: an overlay covers its anchor, a step bound to what the
## player just opened takes the bubble, or its phase ended. A done_when that happens later finishes it.
## Seen long enough (phase / anchor end) it counts as one show; otherwise it is as if it never lit.
func _step_aside(by_phase: bool) -> void:
	if _cur == null:
		return
	var id: String = _cur.id
	if not (by_phase and _t_active >= SEEN_S):
		_uncount(id)
	_started[id] = true
	_cur = null
	_anchor_id = &""
	_hide_chrome()
	_fade_dur = 0.0
	_dirty = true


func _drop_anchor() -> void:
	if _cur == null:
		return
	var id: String = _cur.id
	if _t_active >= SEEN_S:
		_started[id] = true
	else:
		_uncount(id)
	_cur = null
	_anchor_id = &""
	_start_fade(0.0, _fade_fast_s)
	# Short: the anchor usually goes because the screen changed, and the next screen may need its own
	# step at once (closing the month wheel goes straight to the morning notice).
	_gap = minf(_gap_s, ACK_GAP_S)
	_dirty = true


func _uncount(id: String) -> void:
	_unlog(id)
	_unshow(id)
	_new_today = maxi(0, _new_today - 1)
	_drop_pending_shown(id)


func _dismiss() -> void:
	_cur = null
	_anchor_id = &""
	_fade_dur = 0.0
	_fade = 0.0
	if _chrome != null:
		_chrome.modulate = Color(1, 1, 1, 0)
	_hide_chrome()
	_dirty = false


func _tick_current(delta_s: float) -> void:
	_t_active += delta_s
	if _cur.phases.size() > 0 and not _phase_hit(_cur):
		_step_aside(true)
		return
	if not _anchor_still():
		if _covered(_cur):
			_step_aside(false)
		else:
			_drop_anchor()
		return
	_follow()
	if _cur.seconds <= 0.0 or _t_active < _cur.seconds:
		return
	if _cur.done_map.has("timeout"):
		_complete()
	else:
		_expire()


func _anchor_still() -> bool:
	if _cur == null:
		return false
	_refresh_surface()
	if _anchor_id != &"" and CardAnchors.has(_anchor_id) and _allowed(str(_anchor_id)):
		return true
	var nxt := _resolve(_cur)
	if nxt == "":
		return false
	_anchor_id = StringName(nxt)
	_cur.resolved = nxt
	_glow_rect = Rect2()
	return true


func _set_done(id: String) -> void:
	var prog: Dictionary = _progress.get(id, {})
	prog["status"] = "done"
	if not prog.has("shows"):
		prog["shows"] = 0
	prog["abs_day"] = _abs_day()
	_progress[id] = prog
	_started.erase(id)


func _unshow(id: String) -> void:
	var row = _progress.get(id)
	if typeof(row) != TYPE_DICTIONARY:
		return
	var prog: Dictionary = row
	prog["shows"] = maxi(0, int(prog.get("shows", 0)) - 1)
	if str(prog.get("status", "")) != "done" and int(prog["shows"]) <= 0:
		prog.erase("status")
	_progress[id] = prog


func _unlog(id: String) -> void:
	for i in range(shown_log.size() - 1, -1, -1):
		if shown_log[i] == id:
			shown_log.remove_at(i)
			return


func _is_done(id: String) -> bool:
	var row = _progress.get(id)
	return typeof(row) == TYPE_DICTIONARY and str(row.get("status", "")) == "done"


func _shows_of(id: String) -> int:
	var row = _progress.get(id)
	if typeof(row) != TYPE_DICTIONARY:
		return 0
	return int(row.get("shows", 0))


func _enqueue(id: String, status: String) -> void:
	if engine == null or not is_enabled():
		return
	_queue.append({"step": id, "status": status})
	if _flush_queued:
		return
	_flush_queued = true
	_flush.call_deferred()


func _flush() -> void:
	_flush_queued = false
	if engine == null:
		_queue.clear()
		return
	var batch := _queue
	_queue = []
	for item in batch:
		engine.send(&"ui.guide", {"step": str(item["step"]), "status": str(item["status"])})


func _drop_pending_shown(id: String) -> void:
	var keep: Array = []
	for item in _queue:
		if str(item.get("step", "")) == id and str(item.get("status", "")) == "shown":
			continue
		keep.append(item)
	_queue = keep


# ---------------- "N more" and the off button ----------------
## Other steps that could light right now (the prototype's queue length).
func _refresh_more() -> void:
	if _cur == null:
		return
	var n := 0
	var seen := {}
	for item in _no_first:
		n += _count_one(item, seen)
	for mech in _firsts.keys():
		var row = _by_first.get(str(mech))
		if row == null:
			continue
		for item in row:
			n += _count_one(item, seen)
	if n == _more:
		return
	_more = n
	_ok.text = CardText.ui("c16.guide.ok_more", {"n": n}) if n > 0 else CardText.ui("c16.guide.ok")
	_layout_buttons()


func _count_one(item, seen: Dictionary) -> int:
	var step: Compiled = item
	if step == _cur or seen.has(step.id):
		return 0
	seen[step.id] = true
	var keep := step.resolved
	var ok := _passes(step)
	step.resolved = keep
	return 1 if ok else 0


func _on_ok_pressed() -> void:
	acknowledge()


## "Turn the guide off": stop now, save the setting (guide_hints, the same key the settings panel
## writes) and say where to turn it back on. The player's choice beats --guide=on and the test hook.
func _on_off_pressed() -> void:
	_persist_off()
	_cmdline = -1
	if _forced == 1:
		_forced = -1
	set_enabled(false)
	_show_flash(CardText.ui("c16.guide.off_flash"))


func _persist_off() -> void:
	var g := _game()
	if g == null or g.host == null:
		return
	var path := str(g.host.settings_path)
	if path == "":
		return
	var bag = load(SETTINGS_SCRIPT).new(path)
	bag.load_file()
	bag.guide_hints = false
	bag.save_file()


func _show_flash(line: String) -> void:
	if _flash == null:
		return
	_flash_text.text = line
	_flash.visible = true
	_flash.reset_size()
	var w := _flash.get_combined_minimum_size().x
	_flash.position = Vector2(roundf((VIEW_W - w) * 0.5), roundf(VIEW_H * 0.18))
	_flash.modulate = Color(1, 1, 1, 1)
	if _flash_tw != null and _flash_tw.is_valid():
		_flash_tw.kill()
	if not is_inside_tree():
		return
	_flash_tw = create_tween()
	_flash_tw.tween_interval(2.2)
	_flash_tw.tween_property(_flash, "modulate:a", 0.0, 0.4)
	_flash_tw.tween_callback(_end_flash)


func _end_flash() -> void:
	_flash.hide()
	_flash_text.text = ""


# ---------------- fades (manual: tests drive them through tick) and the breathing ring ----------------
func _start_fade(target: float, seconds: float) -> void:
	# A bubble on its way out no longer takes clicks: the screen under it already changed.
	_set_clickable(target > 0.0)
	var dur := 0.0 if (skip_fades or _fast()) else maxf(0.0, seconds)
	if dur <= 0.0:
		_fade = target
		_fade_dur = 0.0
		_chrome.modulate = Color(1, 1, 1, target)
		if target <= 0.0:
			_hide_chrome()
		else:
			_show_chrome()
		return
	_fade_from = _fade
	_fade_to = target
	_fade_dur = dur
	_fade_t = 0.0
	_show_chrome()


func _set_clickable(on: bool) -> void:
	var f := Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	for b in [_ok, _off]:
		if b != null:
			(b as Button).mouse_filter = f


func _advance_fade(delta: float) -> void:
	if _fade_dur <= 0.0:
		return
	_fade_t += delta
	var u := clampf(_fade_t / _fade_dur, 0.0, 1.0)
	_fade = lerpf(_fade_from, _fade_to, u)
	_chrome.modulate = Color(1, 1, 1, _fade)
	if u < 1.0:
		return
	_fade_dur = 0.0
	if _fade_to <= 0.0 and _cur == null:
		_hide_chrome()


func _fast() -> bool:
	return CardSettings.fast_anim()


## Prototype .hl: 1.2 s breath between a thin ring and a 14 px gold halo. Two 0.6 s Tween legs, looped.
func _start_pulse() -> void:
	_stop_pulse()
	_pulse = 0.5
	if skip_fades or _fast() or not is_inside_tree():
		return
	_pulse = 0.0
	_pulse_tw = create_tween().set_loops()
	_pulse_tw.tween_method(_set_pulse, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_method(_set_pulse, 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = null


func _set_pulse(v: float) -> void:
	_pulse = v
	_glow.queue_redraw()


# ---------------- chrome ----------------
func _build_chrome() -> void:
	_chrome = Control.new()
	_chrome.name = "Chrome"
	_chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.modulate = Color(1, 1, 1, 0)
	add_child(_chrome)
	_glow = Control.new()
	_glow.name = "Glow"
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(_draw_glow)
	_chrome.add_child(_glow)
	_teacher = TextureRect.new()
	_teacher.name = "Teacher"
	_teacher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_teacher.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_teacher.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_teacher.stretch_mode = TextureRect.STRETCH_SCALE
	_teacher.position = CardLayout.GUIDE_TEACHER.position
	_teacher.size = CardLayout.GUIDE_TEACHER.size
	_teacher.visible = false
	_chrome.add_child(_teacher)
	_bubble = Panel.new()
	_bubble.name = "Bubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_chrome.add_child(_bubble)
	_pic = Panel.new()
	_pic.name = "Pic"
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_pic)
	_pic_tex = TextureRect.new()
	_pic_tex.name = "Art"
	_pic_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pic_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_bubble.add_child(_pic_tex)
	_who = Label.new()
	_who.name = "Who"
	_who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_who)
	_text = Label.new()
	_text.name = "Text"
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_text)
	_off = _make_button("Off")
	_off.pressed.connect(_on_off_pressed)
	_ok = _make_button("Ok")
	_ok.pressed.connect(_on_ok_pressed)
	_flash = PanelContainer.new()
	_flash.name = "Flash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.visible = false
	add_child(_flash)
	_flash_text = Label.new()
	_flash_text.name = "Line"
	_flash_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.add_child(_flash_text)


func _make_button(node_name: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bubble.add_child(b)
	return b


func _style_chrome() -> void:
	if _styled:
		return
	_styled = true
	_sb_plain = _bubble_box(&"guide_bubble", &"guide_edge")
	_sb_note = _bubble_box(&"guide_note", &"guide_note_edge")
	_bubble.add_theme_stylebox_override("panel", _sb_plain)
	var pic := StyleBoxFlat.new()
	pic.bg_color = CardTheme.color(&"wood_dark")
	pic.border_color = CardTheme.color(&"guide_edge")
	pic.set_border_width_all(2)
	pic.set_corner_radius_all(4)
	_pic.add_theme_stylebox_override("panel", pic)
	_font_bold = FontVariation.new()
	_font_bold.base_font = CardTheme.font_body()
	_font_bold.variation_embolden = 0.8
	_who.add_theme_font_override("font", _font_bold)
	_who.add_theme_font_size_override("font_size", WHO_SIZE)
	_who.add_theme_color_override("font_color", CardTheme.color(&"guide_who"))
	_text.add_theme_color_override("font_color", CardTheme.color(&"guide_ink"))
	_text.add_theme_constant_override("line_spacing", 4)
	_style_button(_ok, &"btn_day", &"lamp", &"gold", &"btn_day_ink")
	_style_button(_off, &"tab_on", &"wood_mid", &"wood_mid", &"hud_ink")
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = CardTheme.color(&"dialog_bg")
	fsb.border_color = CardTheme.color(&"gold")
	fsb.set_border_width_all(2)
	fsb.set_corner_radius_all(6)
	fsb.content_margin_left = 16
	fsb.content_margin_right = 16
	fsb.content_margin_top = 8
	fsb.content_margin_bottom = 8
	fsb.shadow_color = CardTheme.color(&"shade")
	fsb.shadow_size = 10
	fsb.shadow_offset = Vector2(0, 8)
	_flash.add_theme_stylebox_override("panel", fsb)
	_flash_text.add_theme_font_override("font", CardTheme.font_body())
	_flash_text.add_theme_font_size_override("font_size", 15)
	_flash_text.add_theme_color_override("font_color", CardTheme.color(&"dialog_name"))
	_hl_gold = CardTheme.color(&"guide_hl_gold")
	_hl_red = CardTheme.color(&"guide_hl_red")
	_apply_text_style(false)


## Prototype .gbub: paper fill, 3 px dark-brown rim, radius 12, drop shadow 0 12 30.
func _bubble_box(fill: StringName, edge: StringName) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CardTheme.color(fill)
	sb.border_color = CardTheme.color(edge)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.shadow_color = CardTheme.color(&"shade")
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 12)
	sb.anti_aliasing = true
	return sb


func _style_button(b: Button, fill: StringName, hover: StringName, edge: StringName, ink: StringName) -> void:
	# Every state is set here: the shared theme (CardTheme.build_theme on the root) must not show through.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = CardTheme.color(hover if state == "hover" else fill)
		sb.border_color = CardTheme.color(edge)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		if state != "pressed" and state != "hover_pressed":
			sb.shadow_color = CardTheme.color(&"wood_dark")
			sb.shadow_size = 1
			sb.shadow_offset = Vector2(0, 2)
		if state == "focus":
			sb.draw_center = false
		b.add_theme_stylebox_override(state, sb)
	var c := CardTheme.color(ink)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(key, c)
	b.add_theme_font_override("font", _font_bold)
	b.add_theme_font_size_override("font_size", BTN_SIZE)


## Note style (things that teach: the brother's ledger notes, the almanac, the notice) = prototype
## .gbub.note: blue-ink rim, brush font 18.
func _apply_text_style(note: bool) -> void:
	_note_style = note
	_bubble.add_theme_stylebox_override("panel", _sb_note if note else _sb_plain)
	if note:
		_text.add_theme_font_override("font", CardTheme.font_title())
		_text.add_theme_font_size_override("font_size", NOTE_SIZE)
	else:
		_text.add_theme_font_override("font", CardTheme.font_body())
		_text.add_theme_font_size_override("font_size", TEXT_SIZE)


func _apply_copy(step: Compiled) -> void:
	_style_chrome()
	var line := CardText.t(step.id + "#say")
	if line.strip_edges() == "":
		line = CardText.t(step.id + "#bubble")
	_text.text = line
	var teacher := step.teacher
	_apply_text_style(teacher.begins_with("obj."))
	_who.text = _who_name(teacher)
	_who.visible = _who.text != ""
	_ok.text = CardText.ui("c16.guide.ok")
	_off.text = CardText.ui("c16.guide.off")
	var art := _teacher_art(teacher)
	_pic_tex.set_meta("art_id", art)
	_pic_tex.texture = null
	_teacher.texture = null
	if art != "":
		var tex := CardArt.texture(art)
		if teacher.begins_with("obj."):
			_pic_tex.texture = tex
		else:
			_pic_tex.texture = _crop(tex)
			_teacher.texture = tex
	_more = -1


func _who_name(teacher: String) -> String:
	if teacher == "":
		return ""
	var key := "c16.guide.who." + teacher
	if CardText.has_text(key):
		return CardText.ui(key)
	if teacher.begins_with("obj."):
		return ""
	return CardText.person_name(teacher)


## The portrait's head and shoulders at x2 (whole pixels, like every pixel image here).
func _crop(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var at := AtlasTexture.new()
	at.atlas = tex
	var size_now := tex.get_size()
	if size_now.x >= PIC_CROP.end.x and size_now.y >= PIC_CROP.end.y:
		at.region = PIC_CROP
	else:
		at.region = Rect2(Vector2.ZERO, size_now)
	return at


func _teacher_art(teacher: String) -> String:
	if teacher == "":
		return ""
	if teacher.begins_with("obj."):
		return "icon." + teacher
	return "portrait." + teacher


func _layout_later() -> void:
	_layout(false)


## Size the bubble from its text, then place it (fresh = pick the best spot again).
func _layout(fresh: bool) -> void:
	if _cur == null:
		return
	if _anchor_id != &"":
		_glow_rect = _local_anchor(_anchor_id)
	var obj: bool = str(_cur.teacher).begins_with("obj.")
	var has_pic := _pic_tex.texture != null
	var left := PAD_X
	_pic.visible = has_pic and not obj
	_pic_tex.visible = has_pic
	if has_pic:
		if obj:
			_pic_tex.position = Vector2(PAD_X + 4.0, PAD_Y + 4.0)
			_pic_tex.size = ICON_BOX
			left = PAD_X + ICON_BOX.x + 18.0
		else:
			_pic.position = Vector2(PAD_X, PAD_Y)
			_pic.size = PIC_BOX
			_pic_tex.position = Vector2(PAD_X + 2.0, PAD_Y + 2.0)
			_pic_tex.size = PIC_BOX - Vector2(4, 4)
			left = PAD_X + PIC_BOX.x + 14.0
	var text_w := BUBBLE_W - left - PAD_X
	var y := PAD_Y
	if _who.visible:
		_who.position = Vector2(left, y)
		_who.size = Vector2(text_w, 20)
		y += 22.0
	_text.position = Vector2(left, y)
	_text.custom_minimum_size = Vector2(text_w, 0)
	_text.size = Vector2(text_w, 0)
	var th := _text.get_minimum_size().y
	_text.size = Vector2(text_w, th)
	y += th + 8.0
	var pic_bottom := PAD_Y + (PIC_BOX.y if has_pic and not obj else (ICON_BOX.y + 4.0 if has_pic else 0.0))
	var h := maxf(y + BTN_H + PAD_Y, pic_bottom + PAD_Y)
	_bubble.size = Vector2(BUBBLE_W, ceilf(h))
	_layout_buttons()
	_place(fresh)
	_glow.queue_redraw()


func _layout_buttons() -> void:
	var by := _bubble.size.y - PAD_Y - BTN_H
	var x := BUBBLE_W - PAD_X
	for b in [_ok, _off]:
		var w := maxf(64.0, b.get_combined_minimum_size().x)
		x -= w
		b.position = Vector2(x, by)
		b.size = Vector2(w, BTN_H)
		x -= 10.0


## Choose where the bubble goes: never over the glowing anchor or a visible button (button audit b47),
## as little as possible over the dialog, the selected card, the counter checks and the hand. The
## prototype spot (444, 384) comes first; GUIDE_SAY and GUIDE_SAY_LOW are among the fallbacks.
func _place(fresh: bool) -> void:
	var sz := _bubble.size
	var avoid := _avoid_rects()
	if not fresh and _spot.x >= 0.0 and _score(Rect2(_spot, sz), avoid) < 1.0:
		_bubble.position = _spot
		_refresh_teacher()
		return
	var best := Vector2(-1, -1)
	var best_score := INF
	var spots := _spots(sz)
	for i in spots.size():
		var p := _clamp_pos(spots[i], sz)
		var s := _score(Rect2(p, sz), avoid) + float(i) * 0.5
		if s < best_score:
			best_score = s
			best = p
	_spot = best
	_bubble.position = best
	_refresh_teacher()


func _spots(sz: Vector2) -> Array[Vector2]:
	var a := _glow_rect.grow(12.0)
	var right := VIEW_W - 16.0 - sz.x
	var low := VIEW_H - 12.0 - sz.y
	var out: Array[Vector2] = [
		BUBBLE_MAIN,
		CardLayout.GUIDE_SAY.position,
		Vector2(right, TOP_Y),
		Vector2(right, BUBBLE_MAIN.y),
		Vector2(CardLayout.GUIDE_SAY_LOW.position.x, low),
		Vector2(BUBBLE_MAIN.x, low),
		Vector2(right, low),
		Vector2(16.0, TOP_Y),
		Vector2(16.0, BUBBLE_MAIN.y),
	]
	if a.has_area():
		out.append(Vector2(a.end.x, a.position.y))
		out.append(Vector2(a.position.x - sz.x, a.position.y))
		out.append(Vector2(a.position.x, a.end.y))
		out.append(Vector2(a.position.x, a.position.y - sz.y))
	return out


## [rect, weight] pairs. The anchor weighs most, then buttons, then content the player reads.
func _avoid_rects() -> Array:
	var out: Array = []
	if _glow_rect.has_area():
		out.append([_glow_rect.grow(6.0), 50.0])
	for r in _button_rects():
		out.append([r, 20.0])
	# An open side drawer is read like a panel (its title and first rows sit right under the top bar).
	if _drawer_rect.has_area():
		out.append([_drawer_rect, 20.0])
	# Hand cards are not Buttons but are clicked: keep off the fan, up to where a hovered card rises.
	if (_surf == "" or _surf == "night") and CardAnchors.has(&"a.hand"):
		var band := _local_anchor(&"a.hand")
		if band.has_area():
			var top := minf(band.position.y, FAN_LIFT_TOP)
			out.append([Rect2(band.position.x, top, band.size.x, band.end.y - top), 20.0])
	if _surf != "":
		return out
	var soft := {&"a.dialog": 4.0, &"a.hand.preview": 4.0, &"a.slots.first": 4.0, &"a.slots.coins": 4.0,
		&"a.hand": 2.0, &"a.counter.item": 1.0, &"a.hero": 2.0, &"a.contacts": 1.0}
	for id in soft.keys():
		if CardAnchors.has(id):
			out.append([_local_anchor(id), float(soft[id])])
	return out


func _score(r: Rect2, avoid: Array) -> float:
	var s := 0.0
	for row in avoid:
		var other: Rect2 = row[0]
		var hit := r.intersection(other)
		if hit.has_area():
			s += hit.get_area() * float(row[1]) / 100.0
	return s


## Visible clickable buttons on the surface the player sees on top (not ours): the open overlay or
## minigame when there is one (the table under it does not count), otherwise the whole scene.
func _button_rects() -> Array:
	var out: Array = []
	if not is_inside_tree():
		return out
	var top: Node = get_tree().root
	var g := _game()
	if g != null and _surf != "":
		if _surf == "minigame" and g.mg_host != null:
			top = g.mg_host
		elif g.host != null and g.host.top_panel() != null:
			top = g.host.top_panel()
	_collect_buttons(top, out)
	return out


func _collect_buttons(n: Node, out: Array) -> void:
	if n == self:
		return
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is BaseButton:
		var b := n as BaseButton
		if b.mouse_filter != Control.MOUSE_FILTER_IGNORE and b.is_visible_in_tree():
			var r := b.get_global_rect()
			if r.has_area():
				out.append(r)
	for c in n.get_children():
		_collect_buttons(c, out)


func _follow() -> void:
	if _anchor_id == &"":
		return
	var r := _local_anchor(_anchor_id)
	if r == _glow_rect:
		return
	var moved := r.position.distance_to(_glow_rect.position) > 24.0 or r.size.distance_to(_glow_rect.size) > 24.0
	_glow_rect = r
	_glow.queue_redraw()
	if moved:
		_place(false)


## Every poll while showing: keep the "N more" count, the teacher and the spot current.
func _refresh_live() -> void:
	if _cur == null:
		return
	_refresh_more()
	_place(false)


## A person teacher stands at the counter side (GUIDE_TEACHER, x4) while nothing covers the table and
## that spot is free (he is not the one at the counter, nobody stands as companion, no relic sits on the
## curio shelf behind that spot); at night through night_tint. Prototype: the brother stands beside the
## counter while he teaches.
func _refresh_teacher() -> void:
	if _cur == null or _teacher.texture == null or not PERSON_TEACHERS.has(str(_cur.teacher)):
		_teacher.visible = false
		return
	var free := _surf == "" and not _drawer_rect.has_area() and not _companion_taken(str(_cur.teacher))
	free = free and not _curio_taken()
	free = free and not Rect2(_bubble.position, _bubble.size).intersects(CardLayout.GUIDE_TEACHER.grow(-48.0))
	_teacher.visible = free
	var stage = _view.get("stage", {})
	var night := str(_view.get("phase", "")) == "night"
	if typeof(stage) == TYPE_DICTIONARY and str(stage.get("time", "")) == "night":
		night = true
	_teacher.modulate = CardTheme.color(&"night_tint") if night else Color(1, 1, 1, 1)


## Rogue v1: CardLayout.CURIO lies inside GUIDE_TEACHER; once a relic is on the shelf the teacher would hide it.
func _curio_taken() -> bool:
	var relics = _view.get("relics", {})
	return typeof(relics) == TYPE_DICTIONARY and int(relics.get("count", 0)) > 0


func _companion_taken(who: String) -> bool:
	var g := _game()
	if g == null or g.stage == null:
		return CardAnchors.has(&"a.dialog")
	var cast := g.stage.get_node_or_null("Cast")
	if cast == null:
		return false
	for actor in cast.get_children():
		if not (actor is CanvasItem) or not (actor as CanvasItem).visible:
			continue
		if str(actor.get_meta("who", "")) == who or str(actor.get_meta("at", "")) == "companion":
			return true
	return false


func _clamp_pos(p: Vector2, sz: Vector2) -> Vector2:
	return Vector2(
		roundf(clampf(p.x, PAD, VIEW_W - sz.x - PAD)),
		roundf(clampf(p.y, TOP_Y, VIEW_H - sz.y - PAD)))


func _local_anchor(id: StringName) -> Rect2:
	var r := CardAnchors.rect(id)
	if not r.has_area():
		return Rect2()
	if not is_inside_tree():
		return r
	return get_global_transform_with_canvas().affine_inverse() * r


func _show_chrome() -> void:
	_bubble.visible = true
	if _cur != null:
		_refresh_teacher()


func _hide_chrome() -> void:
	_bubble.visible = false
	# Hidden words are cleared too: the next bubble asks CardText again (after a new game resets it).
	_text.text = ""
	_who.text = ""
	_ok.text = ""
	_off.text = ""
	_teacher.visible = false
	_glow_rect = Rect2()
	_spot = Vector2(-1, -1)
	_stop_pulse()
	_glow.queue_redraw()


func _draw_glow() -> void:
	if _cur == null or not _glow_rect.has_area():
		return
	var r := _glow_rect.grow(4.0)
	var p := clampf(_pulse, 0.0, 1.0)
	# Outer halo: up to 14 px of gold at the bright end of the breath.
	for i in 4:
		var c := _hl_gold
		c.a = _hl_gold.a * 0.5 * p * (1.0 - float(i) / 4.0)
		draw_rect_on(_glow, r.grow(3.0 + float(i) * 3.5), c, 3.5)
	var red := _hl_red
	red.a = _hl_red.a * (1.0 - 0.6 * p)
	draw_rect_on(_glow, r.grow(3.0), red, 4.0)
	draw_rect_on(_glow, r, _hl_gold, 2.0 + p)


static func draw_rect_on(ci: CanvasItem, r: Rect2, c: Color, w: float) -> void:
	ci.draw_rect(r, c, false, w)


func _seal(n: Node) -> void:
	if n is BaseButton:
		return
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_seal(c)


# ---------------- step index ----------------
func _cache_timings() -> void:
	_gap_s = float(_iset("gap_ms", 2000)) / 1000.0
	_fade_in_s = float(_iset("fade_in_ms", 300)) / 1000.0
	_fade_out_s = float(_iset("fade_out_ms", 700)) / 1000.0
	_fade_fast_s = float(_iset("fade_fast_ms", 250)) / 1000.0
	_default_seconds = _iset("default_seconds", 16)
	_max_new = _iset("max_new_per_day", 16)


func _iset(key: String, fallback: int) -> int:
	return int(_settings.get(key, fallback))


func _compile(steps: Array) -> void:
	_compiled = []
	_by_first = {}
	_by_token = {}
	_no_first = []
	for i in steps.size():
		if typeof(steps[i]) != TYPE_DICTIONARY:
			continue
		var step := _compile_one(steps[i], _compiled.size())
		_compiled.append(step)
		if step.first == "":
			_no_first.append(step)
		else:
			if not _by_first.has(step.first):
				_by_first[step.first] = []
			(_by_first[step.first] as Array).append(step)
		for tok in step.done:
			if tok == "timeout" or tok.begins_with("first:"):
				continue
			if not _by_token.has(tok):
				_by_token[tok] = []
			(_by_token[tok] as Array).append(step)


func _compile_one(raw: Dictionary, index: int) -> Compiled:
	var step := Compiled.new()
	step.raw = raw
	step.index = index
	step.id = str(raw.get("id", ""))
	step.priority = int(raw.get("priority", 50))
	step.max_shows = int(raw.get("max_shows", 2))
	step.seconds = float(raw.get("seconds", _default_seconds))
	step.interrupt = bool(raw.get("interrupt", false))
	step.anchor = str(raw.get("anchor", ""))
	step.fallback = str(raw.get("anchor_fallback", ""))
	step.anchor_uid = step.anchor.contains("{uid}")
	step.fallback_uid = step.fallback.contains("{uid}")
	step.teacher = str(raw.get("teacher", ""))
	var trig = raw.get("trigger")
	if typeof(trig) == TYPE_DICTIONARY:
		_compile_trigger(step, trig)
	step.contextual = step.panel != "" or (step.anchor != "" and not _is_table(step.anchor))
	var done = raw.get("done_when")
	if typeof(done) == TYPE_ARRAY:
		for tok in done:
			var s := str(tok)
			step.done.append(s)
			step.done_map[s] = true
			if s.begins_with("first:"):
				step.has_first_done = true
	return step


func _compile_trigger(step: Compiled, trig: Dictionary) -> void:
	if trig.has("first"):
		step.first = str(trig["first"])
	if trig.has("phase"):
		var ph = trig["phase"]
		if typeof(ph) == TYPE_ARRAY:
			for item in ph:
				step.phases.append(str(item))
		else:
			step.phases.append(str(ph))
	if trig.has("mode"):
		step.mode = str(trig["mode"])
	if trig.has("stage_gte"):
		step.has_stage = true
		step.stage_gte = int(trig["stage_gte"])
	if trig.has("stage_day_gte"):
		step.has_stage_day = true
		step.stage_day_gte = int(trig["stage_day_gte"])
	if trig.has("abs_day_gte"):
		step.has_abs = true
		step.abs_day_gte = int(trig["abs_day_gte"])
	var after = trig.get("after")
	if typeof(after) == TYPE_ARRAY:
		for a in after:
			step.after.append(str(a))
	if trig.has("panel"):
		step.panel = str(trig["panel"])
	step.hand_clear = bool(trig.get("hand_clear", false))
	step.has_cond = trig.has("cond")
