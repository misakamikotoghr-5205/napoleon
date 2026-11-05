# RG5_profile: CardProfile on its own — new / broken / newer files, atomic writes (a failed rename keeps the temp,
# read back next time), a bad ledger counter repaired, ledger numbers and seeds,
# absorb (a union: idempotent, order free), close_run upsert, reopen, close_abandoned, openings unlock,
# run_context filtering, title_data shape, note_guide, claiming a pre-profile suspend. Owner RG5. ROGUE_V1.md §8.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG5/helper.gd")


func _initialize() -> void:
	var t := T.new(self, "RG5_profile")
	_files(t)
	_broken(t)
	_newer(t)
	_failed_rename(t)
	_repaired(t)
	_ledgers(t)
	_absorb(t)
	_close(t)
	var db := CardDB.load_all(H.data_root(t), {})
	_openings(t, db)
	_title(t, db)
	_guide_and_claim(t)
	t.finish()


func _dir(t, sub: String) -> String:
	var d: String = t.user_dir() + "/" + sub
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _fresh(t, sub: String) -> CardProfile:
	return CardProfile.load_or_new(_dir(t, sub), false)


func _files(t) -> void:
	var dir := _dir(t, "files")
	var p := CardProfile.load_or_new(dir, false)
	t.eq(CardProfile.path_in(dir), dir + "/profile.json", "path_in")
	t.eq(CardProfile.path_in(dir + "/"), dir + "/profile.json", "path_in trims the slash")
	t.ok(not p.was_reset, "a missing file is not a reset")
	t.eq(p.data, CardProfile.fresh(), "a new profile is the fresh shape")
	t.eq([p.next_no(), p.suggest_seed(), p.closed_count()], [1, 7, 0], "ledger 1 suggests seed 7")
	t.ok(not FileAccess.file_exists(CardProfile.path_in(dir)), "loading writes nothing")
	p.begin_run(2147483000, "og.default")
	t.ok(p.save(), "save ok")
	t.ok(FileAccess.file_exists(CardProfile.path_in(dir)), "profile.json written")
	t.ok(not FileAccess.file_exists(CardProfile.path_in(dir) + ".tmp"), "no temp file left behind")
	var back := CardProfile.load_or_new(dir, false)
	t.eq(back.data, p.data, "round trip")
	t.eq(int(back.current()["seed"]), 2147483000, "large seeds survive at full precision")
	t.eq(t.find_floats(back.data), PackedStringArray(), "no floats after reading back")
	t.eq(str(back.data["format"]), CardProfile.FORMAT, "format tag")


func _broken(t) -> void:
	for bad in ["not a profile {", JSON.stringify({"format": "something-else", "v": 1}), "[1, 2]"]:
		var dir := _dir(t, "broken")
		var path := CardProfile.path_in(dir)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(bad)
		f.close()
		var p := CardProfile.load_or_new(dir, false)
		t.ok(p.was_reset, "broken file -> was_reset (%s)" % bad.substr(0, 12))
		t.eq(FileAccess.get_file_as_string(dir + "/profile.broken.json"), bad, "broken file renamed to profile.broken.json")
		t.ok(not FileAccess.file_exists(path), "the broken profile.json is moved away")
		t.eq(p.data, CardProfile.fresh(), "a fresh profile replaces it")
		t.eq(p.title_data(null, -1, "og.default")["notice_key"], "rg5.toast.profile_reset", "title notice after a reset")
		t.ok(p.save(), "the fresh profile can be saved")
		t.ok(FileAccess.file_exists(path), "a new profile.json is written")
		DirAccess.remove_absolute(path)


func _newer(t) -> void:
	var dir := _dir(t, "newer")
	var path := CardProfile.path_in(dir)
	var newer := JSON.stringify({"format": CardProfile.FORMAT, "v": CardProfile.VERSION + 1, "runs_started": 9})
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(newer)
	f.close()
	var p := CardProfile.load_or_new(dir, false)
	t.ok(p.was_reset, "newer file -> was_reset")
	t.eq(p.next_no(), 1, "newer file: a fresh profile in memory")
	p.begin_run(7, "og.default")
	t.ok(not p.save(), "newer file: never overwritten")
	t.eq(FileAccess.get_file_as_string(path), newer, "newer file bytes untouched")
	t.ok(not FileAccess.file_exists(dir + "/profile.broken.json"), "newer file is not renamed")


## A rename that fails keeps the temp copy; with profile.json gone, the next load reads it back and moves it into place.
func _failed_rename(t) -> void:
	var dir := _dir(t, "rename")
	var path := CardProfile.path_in(dir)
	for left in [path, path + ".tmp", dir + "/profile.broken.json"]:
		DirAccess.remove_absolute(left)
	var p := CardProfile.load_or_new(dir, false)
	p.begin_run(4242, "og.default")
	DirAccess.make_dir_recursive_absolute(path)
	t.ok(not p.save(), "rename onto a directory fails")
	t.ok(FileAccess.file_exists(path + ".tmp"), "the temp copy is kept after a failed rename")
	DirAccess.remove_absolute(path)
	var back := CardProfile.load_or_new(dir, false)
	t.ok(not back.was_reset, "recovered from the temp copy: nothing was lost, no reset notice")
	t.eq(back.data, p.data, "the temp copy is the profile")
	t.ok(FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".tmp"), "temp moved into place")
	DirAccess.remove_absolute(path)
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	f.store_string("{\"format\": \"dehoudang-cards-pro")
	f.close()
	var cut := CardProfile.load_or_new(dir, false)
	t.ok(cut.was_reset, "a half-written temp and no profile.json -> reset notice")
	t.eq(cut.data, CardProfile.fresh(), "half-written temp -> fresh profile")
	t.ok(not FileAccess.file_exists(path + ".tmp"), "half-written temp moved to profile.broken.json")


## A parseable profile with a bad ledger counter: the counter never goes below a used ledger number or 0.
func _repaired(t) -> void:
	var cases := [
		[{"runs_started": -1}, 1, "runs_started -1 -> ledger 1"],
		[{"runs_started": 0, "chronicle": [{"no": 1, "key": "k"}, {"no": 2, "key": "k"}]}, 3, "behind the shelf -> 3"],
		[{"runs_started": 1, "current": {"no": 4, "status": "open"}}, 5, "behind the open ledger -> 5"],
		[{"runs_started": 6, "chronicle": [{"no": 2, "key": "k"}]}, 7, "a sane counter is kept"],
	]
	for row in cases:
		var dir := _dir(t, "repair")
		var d := CardProfile.fresh()
		d.merge(row[0], true)
		var f := FileAccess.open(CardProfile.path_in(dir), FileAccess.WRITE)
		f.store_string(JSON.stringify(d))
		f.close()
		var p := CardProfile.load_or_new(dir, false)
		t.eq(p.next_no(), row[1], str(row[2]))
		t.ok(int(p.run_context(null, "og.default")["no"]) >= 1, "run.no >= 1: " + str(row[2]))
	var p := _fresh(t, "repair_raw")
	p.data["runs_started"] = -5
	p.data["reroll"] = -3
	t.eq(p.next_no(), 1, "next_no is at least 1 even in memory")
	var dir := _dir(t, "repair_reroll")
	var f := FileAccess.open(CardProfile.path_in(dir), FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": CardProfile.FORMAT, "v": 1, "reroll": -3}))
	f.close()
	t.eq(int(CardProfile.load_or_new(dir, false).data["reroll"]), 0, "reroll below 0 -> 0")


func _ledgers(t) -> void:
	var p := _fresh(t, "ledgers")
	p.begin_run(p.suggest_seed(), "og.default")
	t.eq(p.current(), {"no": 1, "seed": 7, "status": "open", "opening": "og.default", "last": {}}, "first ledger")
	t.eq(p.next_no(), 2, "next ledger is 2")
	var s0 := p.suggest_seed()
	t.eq(s0, CardRunSeed.derive(0, 2, 0), "ledger 2 seed derives from salt 0")
	var s1 := p.reroll_seed()
	t.ok(s1 != s0, "reroll changes the suggestion")
	t.eq([int(p.data["reroll"]), p.suggest_seed()], [1, s1], "reroll counted")
	t.eq(p.reroll_seed(), CardRunSeed.derive(0, 2, 2), "second reroll")
	p.begin_run(s1, "og.shanghai")
	t.eq([int(p.data["runs_started"]), int(p.data["reroll"]), int(p.current()["no"])], [2, 0, 2], "begin_run counts and resets reroll")
	t.ok(p.is_open(), "the new ledger is open")


func _harvest(no: int, frags: Array, stage: int, era: String, day: int) -> Dictionary:
	return {"ok": true, "err": "", "no": no, "phase": "morning", "reason": "", "stage": stage, "era": era,
		"stage_day": day, "frags": frags}


func _absorb(t) -> void:
	var h1 := _harvest(1, ["df.a", "df.b"], 0, "1938", 5)
	var h2 := _harvest(2, ["df.b", "df.c"], 1, "1939", 3)
	var p := _fresh(t, "absorb1")
	p.begin_run(7, "og.default")
	p.absorb(h1)
	var once := p.data.duplicate(true)
	p.absorb(h1)
	t.eq(p.data, once, "absorbing the same harvest twice = once")
	t.eq(p.data["frags"], {"df.a": 1, "df.b": 1}, "frags remember the ledger they were first seen in")
	t.eq(p.current()["last"], {"stage": 0, "era": "1938", "stage_day": 5}, "absorb records where the ledger is")
	var a := _fresh(t, "absorb2")
	var b := _fresh(t, "absorb3")
	a.absorb(h1)
	a.absorb(h2)
	b.absorb(h2)
	b.absorb(h1)
	t.eq(a.data["frags"], b.data["frags"], "absorb order does not matter")
	t.eq(a.data["frags"], {"df.a": 1, "df.b": 1, "df.c": 2}, "union keeps the lowest ledger number")
	var c := _fresh(t, "absorb4")
	var shuffled := h2.duplicate(true)
	shuffled["frags"] = ["df.c", "df.b"]
	c.absorb(shuffled)
	c.absorb(h1)
	c.absorb(shuffled)
	t.eq(c.data["frags"], a.data["frags"], "shuffled and repeated absorbs give the same set")
	var d := _fresh(t, "absorb5")
	d.absorb({"ok": false, "err": "not_implemented"})
	t.eq(d.data, CardProfile.fresh(), "a failed harvest is ignored")


func _close(t) -> void:
	var p := _fresh(t, "close")
	p.begin_run(7, "og.default")
	var h := _harvest(1, ["df.a"], 1, "1939", 17)
	h["chronicle"] = {"key": "rg5.chronicle.prison.1939", "args": {"d": 17}}
	p.close_run(h, "prison")
	t.eq(p.data["chronicle"], [{"no": 1, "seed": 7, "opening": "og.default", "reason": "prison",
		"key": "rg5.chronicle.prison.1939", "args": {"d": 17}, "stage": 1, "stage_day": 17}], "close_run writes one row")
	t.eq(str(p.current()["status"]), "closed", "close_run closes the ledger")
	t.eq(p.data["frags"], {"df.a": 1}, "close_run absorbs first")
	t.eq(p.closed_count(), 1, "one closed ledger")
	p.reopen()
	t.ok(p.is_open(), "reopen")
	var h2 := _harvest(1, ["df.a", "df.b"], 2, "1940", 30)
	h2["chronicle"] = {"key": "rg5.chronicle.ending.plain", "args": {}}
	p.close_run(h2, "ending")
	t.eq(p.closed_count(), 1, "closing the same ledger again replaces its row")
	t.eq([p.data["chronicle"][0]["key"], p.data["chronicle"][0]["reason"]], ["rg5.chronicle.ending.plain", "ending"], "replaced row")
	p.begin_run(99, "og.shanghai")
	p.absorb(_harvest(2, [], 1, "1939", 12))
	p.close_abandoned()
	t.eq(p.closed_count(), 2, "close_abandoned adds the second row")
	t.eq(p.data["chronicle"][1], {"no": 2, "seed": 99, "opening": "og.shanghai", "reason": "abandoned",
		"key": "rg5.chronicle.abandoned.1939", "args": {"d": 12}, "stage": 1, "stage_day": 12}, "close_abandoned uses last")
	p.begin_run(5, "og.default")
	p.close_abandoned()
	t.eq([p.data["chronicle"][2]["key"], p.data["chronicle"][2]["args"]], ["rg5.chronicle.other", {"d": 1}],
		"no last yet: the generic line")
	t.eq(p.data["chronicle"].map(func(r: Dictionary) -> int: return int(r["no"])), [1, 2, 3], "shelf is old to new")
	var missing := _harvest(4, [], 0, "1938", 2)
	p.begin_run(6, "og.default")
	p.close_run(missing, "prison")
	t.eq(p.data["chronicle"][3]["key"], "rg5.chronicle.other", "a harvest without a chronicle line falls back")


func _openings(t, db: CardDB) -> void:
	var p := _fresh(t, "openings")
	t.eq(p.openings(db), [{"id": "og.default", "unlocked": true}, {"id": "og.shanghai", "unlocked": false}],
		"shanghai locked before any ledger is closed")
	t.eq(p.openings(null), [{"id": "og.default", "unlocked": true}], "no legacy rules: only the default opening")
	p.begin_run(7, "og.default")
	p.close_run(_harvest(1, [], 0, "1938", 4), "prison")
	t.eq(p.openings(db), [{"id": "og.default", "unlocked": true}, {"id": "og.shanghai", "unlocked": true}],
		"closing the first ledger unlocks shanghai")
	p.data["frags"] = {"df.linsao.1938.husband": 1, "df.brother.1938.farewell": 1, "df.nope.1938.x": 1,
		"p.zhang.1938.tut_pawn": 1}
	t.eq(p.run_context(db, "og.shanghai"), {"no": 2, "opening": "og.shanghai",
		"known": ["df.brother.1938.farewell", "df.linsao.1938.husband"]}, "run_context keeps existing fragments, sorted")


func _title(t, db: CardDB) -> void:
	var p := _fresh(t, "title")
	var d := p.title_data(db, -1, "og.shanghai")
	t.eq(d, {"run_no": 1, "open_no": 0, "seed": 7, "openings": [{"id": "og.default", "unlocked": true},
		{"id": "og.shanghai", "unlocked": false}], "opening": "og.default", "shelf": [], "notice_key": ""},
		"title data before any ledger (locked opening falls back)")
	p.begin_run(7, "og.default")
	p.close_run(_harvest(1, [], 1, "1939", 17).merged({"chronicle": {"key": "rg5.chronicle.prison.1939", "args": {"d": 17}}}), "prison")
	d = p.title_data(db, 4242, "og.shanghai")
	t.eq([d["run_no"], d["seed"], d["opening"]], [2, 4242, "og.shanghai"], "forced seed and an unlocked opening")
	t.eq(d["shelf"], [{"no": 1, "key": "rg5.chronicle.prison.1939", "args": {"d": 17}, "reason": "prison",
		"opening": "og.default"}], "shelf rows")
	t.eq(p.title_data(db, -1, "og.default")["seed"], CardRunSeed.derive(0, 2, 0), "suggested seed when none is forced")
	t.eq(d["open_no"], 0, "ledger 1 closed: nothing open")
	p.begin_run(99, "og.default")
	d = p.title_data(db, -1, "og.default")
	t.eq([d["open_no"], d["run_no"]], [2, 3], "ledger 2 open: the title names it next to ledger 3")
	# Acceptance 5: a ledger closed by a game over and reopened by "retry the month" keeps its row (and the unlock),
	# but its spine is off the shelf while it is open again; closing it again puts it back once.
	p.close_run(_harvest(2, [], 0, "1938", 9).merged({"chronicle": {"key": "rg5.chronicle.prison.1938", "args": {"d": 9}}}), "prison")
	t.eq(p.title_data(db, -1, "og.default")["shelf"].size(), 2, "ledger 2 closed: two spines")
	p.reopen()
	d = p.title_data(db, -1, "og.default")
	t.eq(p.closed_count(), 2, "reopened: the row is kept")
	t.eq(d["open_no"], 2, "reopened: ledger 2 is open again")
	t.eq(d["shelf"].map(func(row: Dictionary) -> int: return int(row["no"])), [1], "reopened: its spine is off the shelf")
	t.eq(d["openings"][1].get("unlocked"), true, "reopened: what it unlocked stays")
	p.close_run(_harvest(2, [], 0, "1938", 12), "abandoned")
	t.eq(p.title_data(db, -1, "og.default")["shelf"].size(), 2, "closed again: one spine for ledger 2")


func _guide_and_claim(t) -> void:
	var p := _fresh(t, "guide")
	p.note_guide({"progress": {"gd.b": {"status": "done"}, "gd.a": {"status": "shown"}}})
	t.eq(p.guide_done(), ["gd.b"], "only finished steps")
	p.note_guide({"gd.c": {"status": "done"}, "gd.b": {"status": "done"}, "gd.a": {"status": "done"}})
	t.eq(p.guide_done(), ["gd.a", "gd.b", "gd.c"], "note_guide is a sorted union")
	var claim := CardProfile.load_or_new(_dir(t, "claim"), true)
	t.eq([int(claim.data["runs_started"]), claim.current(), claim.next_no()],
		[1, {"no": 1, "seed": 7, "status": "open", "opening": "og.default", "last": {}}, 2],
		"an old suspend becomes ledger 1")
	t.ok(not claim.was_reset, "claiming is not a reset")
