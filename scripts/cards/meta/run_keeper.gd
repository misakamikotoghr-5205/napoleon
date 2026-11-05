# Rogue v1 old ledger in the shell: one node under CardGameRoot, only on the interactive real-engine path
# (no skip_title, no autoplay, no fixture). It listens to the bus (saved, game_over, command_done) and deals with
# CardProfile when a ledger opens, is saved, ends or is abandoned. Owner RG5. No class_name; preload it.
# docs/cards/rogue/ROGUE_V1.md §8.1, §8.4. The engine never reads the profile: the keeper hands the run context in
# through game.new {run} and reads legacy.harvest back. On the continue path it only reads the save files and only
# writes profile.json (X01_continue). Title calls go through has_method (the run box belongs to RG4).
extends Node

const Ids = preload("res://scripts/cards/legacy/legacy_ids.gd")
const OceanBridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const OceanViewAdapter = preload("res://scripts/cards/campaign/ocean_view.gd")
const TOAST_CLOSED := "rg5.toast.closed"
const RESUME_CMDS: Array[StringName] = [&"game.retry_stage", &"game.load"]

var engine: CardEngineApi = null
var bus: CardEventBus = null
var profile: CardProfile = null
## The opening picked on the title (only unlocked ones stick).
var opening: String = Ids.DEFAULT_OPENING
var _opts: Dictionary = {}
var _boot_db: CardDB = null
var _toast: Callable = Callable()
var _title: WeakRef = null
var _notice_shown: bool = false
var _pending: Dictionary = {}
var _absorb_queued: bool = false
var _ocean_campaign: bool = false


## opts: the root's boot options (seed, save_dir, data_root…). db: the data set the title reads before any game.
## toast: func(key: String) -> void, shows a CardText key as a toast.
func setup(p_engine: CardEngineApi, p_bus: CardEventBus, opts: Dictionary, db: CardDB, toast: Callable) -> void:
	name = "RunKeeper"
	engine = p_engine
	bus = p_bus
	_opts = opts.duplicate()
	_ocean_campaign = OceanBridge.selected(opts)
	_boot_db = OceanViewAdapter.setup_title_text(db) if _ocean_campaign else db
	_toast = toast
	profile = CardProfile.load_or_new(CardSave.root(), CardSave.exists(CardSave.suspend_path()))
	if bus == null:
		return
	if not bus.saved.is_connected(on_saved):
		bus.saved.connect(on_saved)
	if not bus.game_over.is_connected(on_game_over):
		bus.game_over.connect(on_game_over)
	if not bus.command_done.is_connected(on_command_done):
		bus.command_done.connect(on_command_done)


func _exit_tree() -> void:
	if bus == null or not is_instance_valid(bus):
		return
	for pair in [[bus.saved, on_saved], [bus.game_over, on_game_over], [bus.command_done, on_command_done]]:
		if (pair[0] as Signal).is_connected(pair[1]):
			(pair[0] as Signal).disconnect(pair[1])


# ---------------- title ----------------
func on_title(title: Node) -> void:
	_title = weakref(title) if title != null else null
	refresh_title()


## keep_typed: a seed the player typed into the box stays in it (changing the opening must not wipe it).
func refresh_title(keep_typed: bool = false) -> void:
	var title := _live_title()
	if title == null or not title.has_method("set_rogue"):
		return
	if _ocean_campaign:
		if _is_ocean_run():
			engine.view() # Restore the live campaign text if another engine rebound CardText.
		else:
			CardText.setup(_boot_db)
	var prefill := _forced_seed()
	if keep_typed and prefill < 1 and title.has_method("seed_text"):
		prefill = CardRunSeed.parse(str(title.call("seed_text")))
	var d := profile.title_data(_db(), prefill, opening)
	opening = str(d["opening"])
	if _notice_shown:
		d["notice_key"] = ""
	_notice_shown = true
	title.call("set_rogue", d)


## The title's two extra actions: reseed (another suggested seed) and opening (the box changed its pick).
func on_title_action(title: Node, action: StringName) -> void:
	if title != null:
		_title = weakref(title)
	match action:
		&"reseed":
			profile.reroll_seed()
			profile.save()
			refresh_title()
		&"opening":
			if title != null and title.has_method("opening_id"):
				set_opening(str(title.call("opening_id")))


## Only an unlocked opening sticks; the title is refreshed either way (keeping a typed seed).
func set_opening(id: String) -> void:
	if profile.is_unlocked(_db(), id):
		opening = id
	refresh_title(true)


# ---------------- new ledger ----------------
## Before engine.new_game: close a ledger that is still open, pick the seed, add the run context.
## Seed: boot / command-line seed > the title's seed box (when it parses) > the profile's suggestion.
func new_game_options(title: Node, base: Dictionary) -> Dictionary:
	_close_open_ledger()
	var seed_value := _pick_seed(title)
	if not profile.is_unlocked(_db(), opening):
		opening = Ids.DEFAULT_OPENING
	var options := base.duplicate()
	options["seed"] = seed_value
	options["run"] = profile.run_context(_db(), opening)
	_pending = {"seed": seed_value, "opening": opening}
	return options


## After a successful game.new: the old resume point belonged to the last ledger; start this one; replay the
## guide steps earlier ledgers finished (ui.guide is outside the log, the hash and command_done).
func after_new_game() -> void:
	var suspend := CardSave.suspend_path()
	# The Ocean engine already replaced suspend with the new run before returning.
	# Keep that fresh save; the legacy engine retains its original stale-save cleanup.
	if not _is_ocean_run() and FileAccess.file_exists(suspend):
		DirAccess.remove_absolute(suspend)
	profile.begin_run(int(_pending.get("seed", CardRunSeed.FIRST_RUN_SEED)), str(_pending.get("opening", opening)))
	_pending = {}
	profile.save()
	for step in profile.guide_done():
		engine.send(&"ui.guide", {"step": str(step), "status": "done"})


func _pick_seed(title: Node) -> int:
	if _opts.has("seed"):
		return int(_opts["seed"])
	if title != null and title.has_method("seed_text"):
		var typed := CardRunSeed.parse(str(title.call("seed_text")))
		if typed >= 1:
			return typed
	return profile.suggest_seed()


func _close_open_ledger() -> void:
	if not profile.is_open():
		return
	if str(engine.view().get("phase", CardIds.PH_BOOT)) != str(CardIds.PH_BOOT):
		var h := engine.query(Ids.Q_HARVEST, {"close": Ids.CLOSE_ABANDONED})
		if bool(h.get("ok", false)):
			profile.close_run(h, Ids.CLOSE_ABANDONED)
		else:
			profile.close_abandoned()
	else:
		_absorb_suspend()
		if _ocean_campaign:
			var last: Dictionary = profile.current().get("last", {})
			var day := maxi(1, int(last.get("stage_day", 0)))
			profile.close_run({"stage": int(last.get("stage", 0)), "era": str(last.get("era", "")),
				"stage_day": day, "frags": [], "chronicle": {"key": "ocean.chronicle.abandoned", "args": {"d": day}}},
				Ids.CLOSE_ABANDONED)
		else:
			profile.close_abandoned()
	profile.save()


## A ledger claimed from a pre-profile resume point was never absorbed: fold that save in before it closes (its
## fragments, its last day for the chronicle line, its finished guide steps). Reads the save only.
func _absorb_suspend() -> void:
	var cur := profile.current()
	if cur.is_empty() or (typeof(cur.get("last")) == TYPE_DICTIONARY and not (cur["last"] as Dictionary).is_empty()):
		return
	var res := CardSave.read(CardSave.suspend_path())
	if not bool(res.get("ok", false)):
		return
	var data: Dictionary = (res["state"] as CardState).data
	if data.has("ocean"):
		var harvest := OceanBridge.saved_harvest(res["state"])
		if bool(harvest.get("ok", false)):
			profile.absorb(harvest)
		var ocean_ui: Variant = data.get("ui", {})
		if typeof(ocean_ui) == TYPE_DICTIONARY and typeof(ocean_ui.get("guide")) == TYPE_DICTIONARY:
			profile.note_guide(ocean_ui["guide"])
		return
	var loop: Dictionary = data.get("loop", {})
	var stage := int(loop.get("stage", 0))
	var db := _db()
	profile.absorb({"stage": stage, "era": str(db.stage(stage).get("era", "")) if db != null else "",
		"stage_day": int(loop.get("stage_day", 0)), "frags": _held_frags(data)})
	var ui = data.get("ui", {})
	if typeof(ui) == TYPE_DICTIONARY and typeof(ui.get("guide")) == TYPE_DICTIONARY:
		profile.note_guide(ui["guide"])


## The fragments a saved state holds (rules.dossier[person].have), sorted: what legacy.harvest would list.
static func _held_frags(data: Dictionary) -> Array:
	var out: Array = []
	var rules = data.get("rules", {})
	var dossier = rules.get("dossier", {}) if typeof(rules) == TYPE_DICTIONARY else {}
	if typeof(dossier) != TYPE_DICTIONARY:
		return out
	var persons: Array = (dossier as Dictionary).keys()
	persons.sort()
	for person in persons:
		var row = dossier[person]
		if typeof(row) != TYPE_DICTIONARY or typeof(row.get("have")) != TYPE_ARRAY:
			continue
		for id in row["have"]:
			if not out.has(str(id)):
				out.append(str(id))
	out.sort()
	return out


# ---------------- bus ----------------
func on_saved(_path: String, ok: bool) -> void:
	if ok and not _absorb_queued:
		_absorb_queued = true
		absorb_now.call_deferred()


func on_game_over(reason: StringName) -> void:
	close_now.call_deferred(str(reason))


func on_command_done(cmd: StringName, _args: Dictionary, ok: bool) -> void:
	if ok and RESUME_CMDS.has(cmd) and not profile.is_open() and not profile.current().is_empty():
		if _is_ocean_run() and str(engine.view().get("phase", "")) == "game_over":
			return
		profile.reopen()
		profile.save()


## Fold this ledger's harvest and finished guide steps into the profile (after a save went out).
func absorb_now() -> void:
	_absorb_queued = false
	var h := engine.query(Ids.Q_HARVEST, {})
	if not bool(h.get("ok", false)):
		return
	profile.absorb(h)
	profile.note_guide(engine.query(&"guide_progress", {}))
	profile.save()


## Close this ledger with the engine's chronicle line for reason (game over).
func close_now(reason: String) -> void:
	var h := engine.query(Ids.Q_HARVEST, {"close": reason})
	if not bool(h.get("ok", false)):
		return
	profile.close_run(h, reason)
	profile.note_guide(engine.query(&"guide_progress", {}))
	profile.save()
	if _toast.is_valid():
		_toast.call(TOAST_CLOSED)


# ---------------- helpers ----------------
func _is_ocean_run() -> bool:
	var ctx = engine.get("ctx") if engine != null else null
	return ctx != null and ctx.state != null and ctx.state.data.has("ocean")


func _live_title() -> Node:
	if _title == null:
		return null
	var t = _title.get_ref()
	if t == null or not is_instance_valid(t) or (t as Node).is_queued_for_deletion():
		return null
	return t


func _forced_seed() -> int:
	return int(_opts["seed"]) if _opts.has("seed") else -1


## The engine's data once a game exists, the boot data before that.
func _db() -> CardDB:
	var ctx = engine.get("ctx") if engine != null else null
	if ctx != null and ctx.db != null:
		return ctx.db
	return _boot_db
