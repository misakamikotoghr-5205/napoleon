# RG5_root: the keeper inside the real CardGameRoot — title data, the seed box / boot seed, ledger 1 opens,
# a saved morning is absorbed, game over closes the ledger (chronicle, toast), back on the title og.shanghai is
# open, ledger 2 starts with the derived seed and drops the old resume point, retry reopens, a new ledger over a
# running one closes it as abandoned, finished guide steps carry over (in the engine and for the overlay with guide
# hints on), reseed, and the keeper stays out of the skip_title / mock paths, a typed seed survives an opening
# change, a pre-profile resume point is claimed as ledger 1 (closed from that save when a new ledger starts, keeping
# its fragments and finished guide steps), and the continue path leaves the save files alone. RG4's run box is
# optional: the set_rogue / seed_text checks run only when the title has those methods; a stand-in title covers the
# keeper's side either way. Owner RG5. ROGUE_V1.md §7.5, §8.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG5/helper.gd")
const STAND_IN := "extends Node\nvar got: Dictionary = {}\nvar typed: String = \"12345\"\nvar pick: String = \"og.default\"\n" \
	+ "func set_rogue(d: Dictionary) -> void:\n\tgot = d\nfunc seed_text() -> String:\n\treturn typed\n" \
	+ "func opening_id() -> String:\n\treturn pick\n"

const CLAIM_FRAG := "df.zhouma.1940.teahouse_word"

var _root_dir: String = ""


func _initialize() -> void:
	var t := T.new(self, "RG5_root")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_root_dir = H.data_root(t)
	for sub in ["saves", "skip", "mock", "claim", "resume", "guide"]:
		t._rm_tree(t.user_dir() + "/" + sub)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := await _boot(t, bus, {})
	await _first_ledger(t, game)
	await _second_ledger(t, game)
	await _abandon_and_guide(t, game)
	game.queue_free()
	await t.frames(2)
	await _boot_seed(t, bus)
	await _keeper_paths(t, bus)
	await _claim_old_suspend(t, bus)
	await _continue_path(t, bus)
	await _guide_carry(t, bus)
	bus.queue_free()
	await t.frames(2)


func _boot(t, bus: CardEventBus, extra: Dictionary) -> CardGameRoot:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	var opts := {"mock": false, "bus": bus, "guide": "off", "save_dir": t.user_dir() + "/saves", "data_root": _root_dir,
		"settings_path": ""}
	opts.merge(extra, true)
	game.boot(opts)
	root.add_child(game)
	await t.frames(2)
	return game


func _stand_in() -> Node:
	var s := GDScript.new()
	s.source_code = STAND_IN
	s.reload()
	var n := Node.new()
	n.set_script(s)
	return n


func _profile(t) -> CardProfile:
	return CardProfile.load_or_new(t.user_dir() + "/saves", false)


func _first_ledger(t, game: CardGameRoot) -> void:
	t.ok(game.title != null, "title is up")
	t.ok(game.keeper != null, "the keeper runs on the interactive path")
	if game.keeper == null:
		return
	var fake := _stand_in()
	game.keeper.on_title(fake)
	t.eq(fake.got.get("run_no"), 1, "stand-in title: ledger 1")
	t.eq(fake.got.get("seed"), 7, "stand-in title: seed 7 suggested")
	t.eq(fake.got.get("shelf"), [], "stand-in title: empty shelf")
	t.eq(fake.got.get("openings"), [{"id": "og.default", "unlocked": true}, {"id": "og.shanghai", "unlocked": false}],
		"stand-in title: shanghai still locked")
	var opts: Dictionary = game.keeper.new_game_options(fake, {"seed": 7, "save_dir": "x"})
	t.eq([opts.get("seed"), opts.get("run"), opts.get("save_dir")], [12345, {"no": 1, "opening": "og.default", "known": []}, "x"],
		"the typed seed wins over the suggestion; run context added; base options kept")
	fake.typed = "  "
	t.eq(game.keeper.new_game_options(fake, {}).get("seed"), 7, "an empty box falls back to the suggestion")
	fake.typed = "12345"
	game.keeper.on_title(fake)
	game.keeper.set_opening("og.default")
	t.eq(fake.got.get("seed"), 12345, "changing the opening keeps the typed seed in the box")
	game.keeper.on_title_action(fake, &"opening")
	t.eq(fake.got.get("seed"), 12345, "the opening action keeps the typed seed too")
	fake.pick = "og.shanghai"
	game.keeper.on_title_action(fake, &"opening")
	t.eq([game.keeper.opening, fake.got.get("opening")], ["og.default", "og.default"], "a locked opening does not stick")
	fake.free()
	game.keeper.on_title(game.title)
	var expect_seed := 7
	if game.title.has_method("seed_text"):
		t.eq(str(game.title.call("seed_text")), "7", "set_rogue prefilled the seed box")
		var box := _line_edit(game.title)
		t.ok(box != null, "the seed box is a LineEdit")
		if box != null:
			box.text = "12345"
			expect_seed = 12345
	else:
		print("RG5_root: title has no run box (RG4 not merged); seed box checks skipped")
	game.title.chose.emit(&"new")
	await t.frames(2)
	t.ok(game.title == null, "new closes the title")
	var e: CardEngine = game.engine
	t.eq(int(e.ctx.state.data["seed"]), expect_seed, "engine seed")
	t.eq(e.ctx.state.data.get("run", {}).get("no"), 1, "run.no 1")
	var p := _profile(t)
	t.eq([int(p.data["runs_started"]), p.current().get("seed"), p.current().get("status")], [1, expect_seed, "open"],
		"profile on disk: ledger 1 open")
	t.ok(bool(e.send(&"day.end", {"confirm": true}).get("ok", false)), "first morning")
	await t.frames(2)
	t.ok(FileAccess.file_exists(CardSave.suspend_path()), "the morning wrote a resume point")
	t.eq(_profile(t).current().get("last"), {"stage": 0, "era": "1938", "stage_day": 1}, "the saved morning was absorbed")
	game.keeper.on_game_over(&"prison")
	await t.frames(2)
	p = _profile(t)
	t.eq(p.closed_count(), 1, "game over: one chronicle row")
	t.eq(p.data["chronicle"][0].get("key"), "rg5.chronicle.prison.1938", "prison chronicle key")
	t.eq(p.data["chronicle"][0].get("args"), {"d": 1}, "chronicle day")
	t.eq(p.current().get("status"), "closed", "the ledger is closed")
	var toast = game.get("_toast")
	t.eq(toast.text() if toast != null else "", CardText.ui("rg5.toast.closed"), "the closing toast")


func _second_ledger(t, game: CardGameRoot) -> void:
	if game.keeper == null:
		return
	game._on_follow_up({"to_title": true}, &"pause")
	await t.frames(2)
	t.ok(game.title != null, "back on the title")
	var data: Dictionary = game.keeper.profile.title_data(game.keeper._db(), -1, "og.shanghai")
	t.eq((data["shelf"] as Array).size(), 1, "one spine on the shelf")
	t.eq(data["openings"][1], {"id": "og.shanghai", "unlocked": true}, "og.shanghai can be picked")
	game.keeper.set_opening("og.shanghai")
	t.eq(game.keeper.opening, "og.shanghai", "keeper keeps the picked opening")
	if game.title.has_method("opening_id"):
		t.eq(str(game.title.call("opening_id")), "og.shanghai", "the run box shows the picked opening")
	var suspend := CardSave.suspend_path()
	t.ok(FileAccess.file_exists(suspend), "ledger 1's resume point is still there")
	game.title.chose.emit(&"new")
	await t.frames(2)
	var e: CardEngine = game.engine
	t.eq(e.ctx.state.data.get("run", {}).get("no"), 2, "run.no 2")
	t.eq(e.ctx.state.data.get("run", {}).get("opening"), "og.shanghai", "run.opening og.shanghai")
	t.eq(int(e.ctx.state.data["seed"]), CardRunSeed.derive(0, 2, 0), "ledger 2 seed = derive(0, 2, 0)")
	t.ok(not FileAccess.file_exists(suspend), "the old resume point was dropped")
	t.ok(FileAccess.file_exists(CardSave.stage_path(0)), "the new stage checkpoint exists")
	# This time the game over comes the real way: the engine ends the game and the bus carries game_over.
	CardDayLoop.finish_game(e.ctx, "prison")
	game.bus.game_over.emit(&"prison")
	await t.frames(2)
	t.eq(_profile(t).current().get("status"), "closed", "ledger 2 closed by the bus game_over")
	t.eq(_profile(t).data["chronicle"][1].get("key"), "rg5.chronicle.prison.1938", "ledger 2 chronicle from the engine")
	t.ok(bool(e.send(&"game.retry_stage").get("ok", false)), "retry the stage")
	await t.frames(1)
	t.eq(_profile(t).current().get("status"), "open", "retry reopens the ledger")
	t.eq(_profile(t).closed_count(), 2, "the reopened ledger keeps its row until it closes again")


func _abandon_and_guide(t, game: CardGameRoot) -> void:
	if game.keeper == null:
		return
	game._on_follow_up({"to_title": true}, &"pause")
	await t.frames(2)
	var before: int = game.keeper.profile.suggest_seed()
	game._on_title(&"reseed")
	t.eq(int(_profile(t).data["reroll"]), 1, "reseed is saved")
	t.ok(game.keeper.profile.suggest_seed() != before, "reseed changes the suggestion")
	game.keeper.profile.data["guide_done"] = ["gd.d1.deal"]
	game.title.chose.emit(&"new")
	await t.frames(2)
	var p := _profile(t)
	t.eq(p.closed_count(), 2, "a running ledger closed by a new one keeps one row per ledger")
	t.eq([p.data["chronicle"][1].get("reason"), p.data["chronicle"][1].get("key")],
		["abandoned", "rg5.chronicle.abandoned.1938"], "ledger 2 replaced as abandoned")
	t.eq(int(p.current()["no"]), 3, "ledger 3 is open")
	t.eq(int((game.engine as CardEngine).ctx.state.data["seed"]), CardRunSeed.derive(0, 3, 1), "the rerolled seed is used")
	var progress: Dictionary = game.engine.query(&"guide_progress", {}).get("progress", {})
	t.eq(progress.get("gd.d1.deal", {}).get("status"), "done", "finished guide steps carry over")
	t.eq((game.engine as CardEngine).command_log().size(), 1, "the guide replay is not in the command log")


func _boot_seed(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, {"seed": 4242})
	if game.keeper == null:
		t.ok(false, "keeper missing with a boot seed")
		return
	var fake := _stand_in()
	game.keeper.on_title(fake)
	t.eq(fake.got.get("seed"), 4242, "the boot seed prefills the title")
	var opts: Dictionary = game.keeper.new_game_options(fake, {})
	t.eq(opts.get("seed"), 4242, "the boot seed beats the typed text")
	fake.free()
	game.keeper.on_title(game.title)
	game.title.chose.emit(&"new")
	await t.frames(2)
	t.eq(int((game.engine as CardEngine).ctx.state.data["seed"]), 4242, "engine uses the boot seed")
	var p := _profile(t)
	t.eq(p.data["chronicle"][2].get("reason"), "abandoned", "restarted app: the open ledger 3 closed as abandoned")
	t.eq([p.data["chronicle"][2].get("key"), p.data["chronicle"][2].get("args")], ["rg5.chronicle.abandoned.1938", {"d": 1}],
		"restarted app: the line comes from the last absorbed save (month opening reads as day 1)")
	t.eq(int(p.current()["no"]), 4, "ledger 4")
	game.queue_free()
	await t.frames(2)


func _keeper_paths(t, bus: CardEventBus) -> void:
	var skip := await _boot(t, bus, {"skip_title": true, "save_dir": t.user_dir() + "/skip"})
	t.ok(skip.keeper == null, "no keeper with skip_title")
	t.eq(int((skip.engine as CardEngine).ctx.state.data["seed"]), 7, "skip_title keeps the old seed rule")
	t.ok(not (skip.engine as CardEngine).ctx.state.data.has("run"), "skip_title: no run context")
	skip.queue_free()
	await t.frames(2)
	var mock := await _boot(t, bus, {"mock": true, "fixture": "morning", "save_dir": t.user_dir() + "/mock"})
	t.ok(mock.keeper == null, "no keeper with the mock engine")
	mock.queue_free()
	await t.frames(2)
	t.ok(not FileAccess.file_exists(CardProfile.path_in(t.user_dir() + "/skip")), "skip_title writes no profile")


func _line_edit(n: Node) -> LineEdit:
	for c in n.find_children("*", "LineEdit", true, false):
		return c as LineEdit
	return null


## A resume point written before the old-ledger feature (no profile.json): the engine plays to the given morning.
## frag / step: a dossier fragment the old game holds and a guide step it finished (both written by that morning).
func _seed_suspend(dir: String, day: int, frag: String = "", step: String = "") -> void:
	var e := H.engine(_root_dir, dir, 7, {})
	if frag != "":
		CardDossier.add(e.ctx, frag)
	if step != "":
		e.send(&"ui.guide", {"step": step, "status": "done"})
	H.to_morning(e, day)


## No profile, an old suspend.json: it is ledger 1 (seed 7, open); a new ledger closes it from that save and keeps
## what that save holds (its fragments become old ink, its finished guide steps carry over).
func _claim_old_suspend(t, bus: CardEventBus) -> void:
	var dir: String = t.user_dir() + "/claim"
	_seed_suspend(dir, 3, CLAIM_FRAG, "gd.d1.deal")
	var old := CardSave.read(dir + "/suspend.json")
	var held: Array = (old["state"] as CardState).data.get("rules", {}).get("dossier", {}).get("zhouma", {}).get("have", []) \
		if bool(old.get("ok", false)) else []
	t.ok(held.has(CLAIM_FRAG), "claim: the old save holds the fragment")
	t.ok(FileAccess.file_exists(dir + "/suspend.json"), "claim: an old resume point exists")
	var game := await _boot(t, bus, {"save_dir": dir})
	t.ok(game.keeper != null, "claim: keeper up")
	if game.keeper == null:
		game.queue_free()
		await t.frames(2)
		return
	var cur: Dictionary = game.keeper.profile.current()
	t.eq([cur.get("no"), cur.get("seed"), cur.get("status"), game.keeper.profile.next_no()], [1, 7, "open", 2],
		"claim: the old game is ledger 1")
	t.ok(not FileAccess.file_exists(CardProfile.path_in(dir)), "claim: booting writes no profile yet")
	game.title.chose.emit(&"new")
	await t.frames(2)
	var p := CardProfile.load_or_new(dir, false)
	t.eq(p.data["chronicle"], [{"no": 1, "seed": 7, "opening": "og.default", "reason": "abandoned",
		"key": "rg5.chronicle.abandoned.1938", "args": {"d": 3}, "stage": 0, "stage_day": 3}],
		"claim: ledger 1 closed as abandoned from its resume point")
	t.eq([int(p.current()["no"]), p.current()["status"]], [2, "open"], "claim: ledger 2 open")
	t.eq(p.data["frags"], {CLAIM_FRAG: 1}, "claim: the old save's fragment is kept as seen in ledger 1")
	t.eq((game.engine as CardEngine).ctx.state.data.get("run", {}).get("known"), [CLAIM_FRAG],
		"claim: ledger 2 knows it (old ink)")
	t.ok(p.guide_done().has("gd.d1.deal"), "claim: the old save's finished guide step carries over")
	t.eq(int((game.engine as CardEngine).ctx.state.data["seed"]), CardRunSeed.derive(0, 2, 0), "claim: ledger 2 seed")
	t.ok(not FileAccess.file_exists(dir + "/suspend.json"), "claim: the old resume point was dropped")
	game.queue_free()
	await t.frames(2)


## Continue reads the save files and writes only profile.json; a new ledger afterwards closes the loaded one.
func _continue_path(t, bus: CardEventBus) -> void:
	var dir: String = t.user_dir() + "/resume"
	_seed_suspend(dir, 2)
	var suspend := dir + "/suspend.json"
	var stage0 := dir + "/stage_00.json"
	var bytes := [FileAccess.get_file_as_string(suspend), FileAccess.get_file_as_string(stage0)]
	var game := await _boot(t, bus, {"save_dir": dir})
	if game.keeper == null:
		t.ok(false, "continue: keeper missing")
		game.queue_free()
		await t.frames(2)
		return
	game.title.chose.emit(&"continue")
	await t.frames(2)
	t.ok(game.title == null, "continue: the title closed")
	t.eq(int((game.engine as CardEngine).view()["date"]["stage_day"]), 2, "continue: day 2 loaded")
	t.eq([FileAccess.get_file_as_string(suspend), FileAccess.get_file_as_string(stage0)], bytes,
		"continue: suspend.json and stage_00.json untouched")
	var extra: Array = Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool:
		return not ["suspend.json", "stage_00.json", "profile.json"].has(f))
	t.eq(extra, [], "continue: no save file besides profile.json is written")
	game._on_follow_up({"to_title": true}, &"pause")
	await t.frames(2)
	game.title.chose.emit(&"new")
	await t.frames(2)
	var p := CardProfile.load_or_new(dir, false)
	t.eq([p.data["chronicle"][0]["reason"], p.data["chronicle"][0]["key"], p.data["chronicle"][0]["args"]],
		["abandoned", "rg5.chronicle.abandoned.1938", {"d": 2}], "continue then new: the loaded ledger closes from the engine")
	t.eq(int(p.current()["no"]), 2, "continue then new: ledger 2")
	game.queue_free()
	await t.frames(2)


## Guide hints on: a step an earlier ledger finished is done for the overlay too (not only in the engine state), so
## the bubble does not light again in the next ledger. gd.m.open is the first bubble of a fresh ledger.
func _guide_carry(t, bus: CardEventBus) -> void:
	var dir: String = t.user_dir() + "/guide"
	var game := await _boot(t, bus, {"guide": "on", "save_dir": dir})
	if game.keeper == null:
		t.ok(false, "guide carry: keeper missing")
		game.queue_free()
		await t.frames(2)
		return
	game.guide.skip_fades = true
	game.title.chose.emit(&"new")
	await t.frames(2)
	t.eq(await _month_open_bubble(t, game), "gd.m.open", "guide carry: a fresh ledger lights gd.m.open")
	game._on_follow_up({"to_title": true}, &"pause")
	await t.frames(2)
	game.keeper.profile.data["guide_done"] = ["gd.m.open"]
	var shown := Array(game.guide.shown_log).count("gd.m.open")
	game.title.chose.emit(&"new")
	await t.frames(2)
	t.eq(game.engine.query(&"guide_progress", {}).get("progress", {}).get("gd.m.open", {}).get("status"), "done",
		"guide carry: the engine holds the carried step as done")
	t.ok(game.guide._is_done("gd.m.open"), "guide carry: the overlay reads the carried step as done")
	t.ok(await _month_open_bubble(t, game) != "gd.m.open", "guide carry: the carried step does not light again")
	t.eq(Array(game.guide.shown_log).count("gd.m.open"), shown, "guide carry: the carried step is not shown again")
	game.queue_free()
	await t.frames(2)


## Play the month opening up to its goals (where gd.m.open lights) and return the bubble that is up.
func _month_open_bubble(t, game: CardGameRoot) -> String:
	for _i in 400:
		if CardAnchors.has(&"a.month.goals"):
			break
		game.autoplay_step()
		await t.frames(1)
	await t.frames(1)
	game.guide.tick(0.5)
	game.guide.evaluate_now()
	return game.guide.active_step()
