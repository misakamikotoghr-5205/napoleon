# Rogue v1 old ledger outside the run: <save root>/profile.json. Reads and writes the file, folds harvests in,
# closes ledgers (chronicle rows), builds the run context for game.new and the title box data. Pure data: it never
# touches the engine (the keeper queries legacy.harvest and hands the result in). Owner RG5.
# docs/cards/rogue/ROGUE_V1.md §8.2 (file), §8.3 (API), §8.4 (one ledger's life), §5.7 (seeds).
# Only sets and "first seen in ledger n": nothing here accumulates a number the player could farm.
# Writes like CardSave.write: full precision JSON to <path>.tmp, then rename. A failed rename keeps the temp (on
# Windows the old profile.json may already be gone by then) and load_or_new reads <path>.tmp when profile.json is
# missing. A broken file is renamed profile.broken.json and a fresh one starts; a file from a newer version is left
# alone and used only in memory.
class_name CardProfile
extends RefCounted

const Ids = preload("res://scripts/cards/legacy/legacy_ids.gd")
const FORMAT := "dehoudang-cards-profile"
const VERSION := 1
const FILE := "profile.json"
const BROKEN := "profile.broken.json"
const TEMP_SUFFIX := ".tmp"
const NOTICE_RESET := "rg5.toast.profile_reset"
const ST_OPEN := "open"
const ST_CLOSED := "closed"

var data: Dictionary = {}
## True when the file on disk could not be used (broken or newer): the title shows rg5.toast.profile_reset once.
var was_reset: bool = false
var dir: String = ""
## A newer file on disk: keep it, never overwrite it.
var _memory_only: bool = false


static func path_in(p_dir: String) -> String:
	return p_dir.trim_suffix("/") + "/" + FILE


static func fresh() -> Dictionary:
	return {"format": FORMAT, "v": VERSION, "salt": 0, "runs_started": 0, "current": {}, "reroll": 0,
		"frags": {}, "guide_done": [], "chronicle": []}


## suspend_exists: a resumable game from before the old-ledger feature; it becomes ledger 1 (seed 7).
static func load_or_new(p_dir: String, suspend_exists: bool) -> CardProfile:
	var p := CardProfile.new()
	p.dir = p_dir.trim_suffix("/")
	var path := path_in(p.dir)
	var src := path
	if not FileAccess.file_exists(path):
		src = path + TEMP_SUFFIX
		if not FileAccess.file_exists(src):
			p.data = _fresh_claiming(suspend_exists)
			return p
	var d = CardDB.read_json(src)
	if typeof(d) == TYPE_DICTIONARY and str(d.get("format", "")) == FORMAT and int(d.get("v", 0)) > VERSION:
		p.data = _fresh_claiming(suspend_exists)
		p.was_reset = true
		p._memory_only = true
		return p
	if typeof(d) != TYPE_DICTIONARY or str(d.get("format", "")) != FORMAT:
		var broken := p.dir + "/" + BROKEN
		if FileAccess.file_exists(broken):
			DirAccess.remove_absolute(broken)
		DirAccess.rename_absolute(src, broken)
		p.data = _fresh_claiming(suspend_exists)
		p.was_reset = true
		return p
	p.data = _normalized(d)
	if src != path:
		DirAccess.rename_absolute(src, path)
	return p


static func _fresh_claiming(suspend_exists: bool) -> Dictionary:
	var d := fresh()
	if suspend_exists:
		d["runs_started"] = 1
		d["current"] = {"no": 1, "seed": CardRunSeed.FIRST_RUN_SEED, "status": ST_OPEN, "opening": Ids.DEFAULT_OPENING,
			"last": {}}
	return d


## Fields of the wrong type fall back to their defaults; unknown keys are kept as they are. The ledger counter never
## falls below a ledger number already used (so a new ledger never takes an old one's shelf row), reroll never below 0.
static func _normalized(d: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	var base := fresh()
	var keys: Array = base.keys()
	keys.sort()
	for key in keys:
		if not out.has(key) or typeof(out[key]) != typeof(base[key]):
			out[key] = base[key]
	out["v"] = VERSION
	var frags: Dictionary = {}
	var ids: Array = (out["frags"] as Dictionary).keys()
	ids.sort()
	for id in ids:
		frags[str(id)] = maxi(1, int(out["frags"][id])) if typeof(out["frags"][id]) == TYPE_INT else 1
	out["frags"] = frags
	var rows: Array = []
	for row in out["chronicle"]:
		if typeof(row) == TYPE_DICTIONARY and typeof(row.get("no")) == TYPE_INT:
			rows.append(row)
	out["chronicle"] = rows
	var done: Array = []
	for s in out["guide_done"]:
		if typeof(s) == TYPE_STRING and not done.has(s):
			done.append(s)
	done.sort()
	out["guide_done"] = done
	var cur_no = (out["current"] as Dictionary).get("no")
	var used := int(cur_no) if typeof(cur_no) == TYPE_INT else 0
	for row in rows:
		used = maxi(used, int(row["no"]))
	out["runs_started"] = maxi(int(out["runs_started"]), maxi(0, used))
	out["reroll"] = maxi(0, int(out["reroll"]))
	return out


func save() -> bool:
	if _memory_only or dir == "":
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var path := path_in(dir)
	var temp := path + TEMP_SUFFIX
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	var err := f.get_error()
	f.close()
	if err != OK:
		DirAccess.remove_absolute(temp)
		return false
	return DirAccess.rename_absolute(temp, path) == OK


func next_no() -> int:
	return maxi(0, int(data.get("runs_started", 0))) + 1


func suggest_seed() -> int:
	return CardRunSeed.derive(int(data.get("salt", 0)), next_no(), int(data.get("reroll", 0)))


func reroll_seed() -> int:
	data["reroll"] = int(data.get("reroll", 0)) + 1
	return suggest_seed()


func closed_count() -> int:
	return (data.get("chronicle", []) as Array).size()


func current() -> Dictionary:
	var c = data.get("current", {})
	return c if typeof(c) == TYPE_DICTIONARY else {}


func is_open() -> bool:
	return str(current().get("status", "")) == ST_OPEN


## [{id, unlocked}] by order (then id); unlocked = closed_count() >= unlock_closed.
func openings(db: CardDB) -> Array:
	var table := _openings_table(db)
	var ids: Array = table.keys()
	ids.sort_custom(func(a, b) -> bool:
		var oa := int(table[a].get("order", 0))
		var ob := int(table[b].get("order", 0))
		return oa < ob if oa != ob else str(a) < str(b))
	var out: Array = []
	for id in ids:
		out.append({"id": str(id), "unlocked": closed_count() >= int(table[id].get("unlock_closed", 0))})
	return out


func is_unlocked(db: CardDB, opening: String) -> bool:
	for row in openings(db):
		if str(row["id"]) == opening:
			return bool(row["unlocked"])
	return false


## {no, opening, known}: known = every fragment an earlier ledger saw that this data set still has, sorted.
func run_context(db: CardDB, opening: String) -> Dictionary:
	var ids: Array = (data.get("frags", {}) as Dictionary).keys()
	ids.sort()
	var known: Array = []
	for id in ids:
		if db != null and str(db._cards.get(str(id), {}).get("type", "")) == "dossier_fragment":
			known.append(str(id))
	return {"no": next_no(), "opening": opening, "known": known}


func begin_run(seed_value: int, opening: String) -> void:
	data["runs_started"] = int(data.get("runs_started", 0)) + 1
	data["current"] = {"no": int(data["runs_started"]), "seed": seed_value, "status": ST_OPEN, "opening": opening,
		"last": {}}
	data["reroll"] = 0


## Fold a legacy.harvest result in: the fragment set is a union that keeps the lowest ledger number per id (so the
## order of absorbs never matters, and absorbing twice is absorbing once); current.last follows the harvest.
func absorb(harvest: Dictionary) -> void:
	if not bool(harvest.get("ok", true)):
		return
	var no := _ledger_no(harvest)
	var frags: Dictionary = data.get("frags", {})
	for id in harvest.get("frags", []):
		var fid := str(id)
		frags[fid] = mini(int(frags[fid]), no) if frags.has(fid) else no
	data["frags"] = frags
	var cur := current()
	if not cur.is_empty():
		cur["last"] = {"stage": int(harvest.get("stage", 0)), "era": str(harvest.get("era", "")),
			"stage_day": int(harvest.get("stage_day", 0))}
		data["current"] = cur


## Close this ledger: absorb, then upsert its chronicle row by ledger number (closing again replaces it).
func close_run(harvest: Dictionary, reason: String) -> void:
	absorb(harvest)
	var line = harvest.get("chronicle", {})
	if typeof(line) != TYPE_DICTIONARY or str(line.get("key", "")) == "":
		line = {"key": Ids.KEY_OTHER, "args": {"d": maxi(1, int(harvest.get("stage_day", 0)))}}
	_upsert_chronicle(_ledger_no(harvest), reason, line, int(harvest.get("stage", 0)), int(harvest.get("stage_day", 0)))


## The engine no longer holds this ledger (the game was restarted): build the line from current.last.
func close_abandoned() -> void:
	var cur := current()
	if cur.is_empty():
		return
	var last: Dictionary = cur.get("last", {}) if typeof(cur.get("last")) == TYPE_DICTIONARY else {}
	var era := str(last.get("era", ""))
	var d := maxi(1, int(last.get("stage_day", 0)))
	var key := Ids.KEY_PREFIX + Ids.CLOSE_ABANDONED + "." + era if Ids.CHRONICLE_ERAS.has(era) else Ids.KEY_OTHER
	_upsert_chronicle(int(cur.get("no", 0)), Ids.CLOSE_ABANDONED, {"key": key, "args": {"d": d}},
		int(last.get("stage", 0)), int(last.get("stage_day", 0)))


func reopen() -> void:
	var cur := current()
	if cur.is_empty():
		return
	cur["status"] = ST_OPEN
	data["current"] = cur


## guide_progress (the query result or its progress map): steps with status done join guide_done.
func note_guide(progress: Dictionary) -> void:
	var rows = progress.get("progress", progress)
	if typeof(rows) != TYPE_DICTIONARY:
		return
	var done: Array = data.get("guide_done", [])
	var steps: Array = (rows as Dictionary).keys()
	steps.sort()
	for step in steps:
		var row = rows[step]
		if typeof(row) == TYPE_DICTIONARY and str(row.get("status", "")) == "done" and not done.has(str(step)):
			done.append(str(step))
	done.sort()
	data["guide_done"] = done


func guide_done() -> Array:
	return (data.get("guide_done", []) as Array).duplicate()


## The title box data (§7.5). forced_seed > 0 prefills it (command line / boot seed); otherwise the suggestion.
## open_no: the ledger still open (0 when none), so the box can say "open shop" closes it.
## A ledger reopened by "retry the month" keeps its chronicle row (and what it unlocked) until it closes again, but
## the shelf leaves its spine out while it is open: one book is never both "on the shelf" and "not closed yet".
func title_data(db: CardDB, forced_seed: int, opening: String) -> Dictionary:
	var shelf: Array = []
	var open_no := int(current().get("no", 0)) if is_open() else 0
	for row in data.get("chronicle", []):
		if open_no > 0 and int(row.get("no", 0)) == open_no:
			continue
		shelf.append({"no": int(row.get("no", 0)), "key": str(row.get("key", "")),
			"args": (row.get("args", {}) as Dictionary).duplicate(true) if typeof(row.get("args")) == TYPE_DICTIONARY else {},
			"reason": str(row.get("reason", "")), "opening": str(row.get("opening", Ids.DEFAULT_OPENING))})
	var chosen := opening if is_unlocked(db, opening) else Ids.DEFAULT_OPENING
	return {"run_no": next_no(), "open_no": open_no,
		"seed": forced_seed if forced_seed > 0 else suggest_seed(),
		"openings": openings(db), "opening": chosen, "shelf": shelf,
		"notice_key": NOTICE_RESET if was_reset else ""}


func _openings_table(db: CardDB) -> Dictionary:
	var rules: Dictionary = db.rules(Ids.RULES) if db != null else {}
	var table = rules.get("openings")
	if typeof(table) != TYPE_DICTIONARY or (table as Dictionary).is_empty():
		return Ids.DEFAULT_OPENINGS
	return table


func _ledger_no(harvest: Dictionary) -> int:
	var no := int(current().get("no", 0))
	if no <= 0:
		no = int(harvest.get("no", 0))
	return maxi(1, no)


func _upsert_chronicle(no: int, reason: String, line: Dictionary, stage: int, stage_day: int) -> void:
	var cur := current()
	var row := {"no": no, "seed": int(cur.get("seed", 0)), "opening": str(cur.get("opening", Ids.DEFAULT_OPENING)),
		"reason": reason, "key": str(line.get("key", Ids.KEY_OTHER)),
		"args": (line.get("args", {}) as Dictionary).duplicate(true) if typeof(line.get("args")) == TYPE_DICTIONARY else {},
		"stage": stage, "stage_day": stage_day}
	var rows: Array = data.get("chronicle", [])
	var replaced := false
	for i in rows.size():
		if int(rows[i].get("no", 0)) == no:
			rows[i] = row
			replaced = true
	if not replaced:
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("no", 0)) < int(b.get("no", 0)))
	data["chronicle"] = rows
	if not cur.is_empty():
		cur["status"] = ST_CLOSED
		data["current"] = cur
