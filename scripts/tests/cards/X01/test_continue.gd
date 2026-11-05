extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

func _initialize() -> void:
	var t := T.new(self, "X01_continue")
	t.run_async(_body.bind(t))

func _body(t) -> void:
	var source := CardEngine.new()
	t.ok(source.new_game({"seed": 19, "save_dir": t.user_dir()}).get("ok", false), "create saved campaign")
	for _step in range(40):
		var view := source.view()
		if view.get("phase") == "morning" and int(view.get("date", {}).get("stage_day", 0)) == 8:
			break
		t.ok(source.send(&"day.end", {"confirm": true}).get("ok", false), "advance save to day eight")
	t.eq(source.view().get("date", {}).get("stage_day"), 8, "non-first-day save")
	var path := CardSave.suspend_path()
	var saved := FileAccess.get_file_as_bytes(path)
	var stage_saved := FileAccess.get_file_as_bytes(CardSave.stage_path(0))
	var expected_log := source.command_log()
	var expected_date: Dictionary = source.view()["date"]
	# A separate normal load supplies the documented resume first-time changes.
	var expected := CardEngine.new()
	t.ok(expected.load_game(path).get("ok", false), "reference load")
	var bus := CardEventBus.new()
	root.add_child(bus)
	var commands: Array = []
	bus.command_done.connect(func(cmd, _args, _ok): commands.append(str(cmd)))
	var game := _boot(t, bus)
	await t.frames(2)
	t.ok(not (game.title.get_node("continue") as Button).disabled, "saved game enables continue")
	(game.title.get_node("continue") as Button).pressed.emit()
	await t.frames(2)
	t.ok(game.title == null, "successful load closes title")
	t.eq(game.engine.view()["date"], expected_date, "continue restores date")
	t.eq((game.engine as CardEngine).state_hash(), expected.state_hash(), "continue restores saved state")
	t.eq((game.engine as CardEngine).command_log(), expected_log, "continue restores command history")
	t.eq(commands, ["game.load"], "continue never sends game.new")
	t.eq(FileAccess.get_file_as_bytes(path), saved, "continue does not overwrite suspend")
	t.eq(FileAccess.get_file_as_bytes(CardSave.stage_path(0)), stage_saved, "continue does not overwrite stage checkpoint")
	t.eq(game.host.top_kind(), &"", "morning restores table without new-month panel")
	game.queue_free()
	await t.frames(2)
	for broken in ["missing", "malformed", "newer"]:
		if broken == "missing":
			DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string("not a save" if broken == "malformed" else JSON.stringify({"format": CardSave.FORMAT, "v": CardState.VERSION + 1}))
			file.close()
		var before := FileAccess.get_file_as_bytes(path) if broken != "missing" else PackedByteArray()
		commands.clear()
		game = _boot(t, bus)
		await t.frames(2)
		var title := game.title
		game.title.chose.emit(&"continue")
		await t.frames(2)
		t.ok(game.title == title and is_instance_valid(title), broken + ": title stays open")
		t.eq(game.engine.view().get("phase"), "boot", broken + ": no fallback new game")
		t.eq(commands, ["game.load"], broken + ": only load attempted")
		t.eq(game.host.top_kind(), &"", broken + ": no gameplay panel")
		if broken == "missing":
			t.ok(not FileAccess.file_exists(path), "missing suspend not created")
		else:
			t.eq(FileAccess.get_file_as_bytes(path), before, broken + ": original bytes preserved")
		t.eq(FileAccess.get_file_as_bytes(CardSave.stage_path(0)), stage_saved, broken + ": stage preserved")
		game.queue_free()
		await t.frames(2)
	bus.queue_free()
	await t.frames(2)

func _boot(t, bus: CardEventBus) -> CardGameRoot:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"mock": false, "bus": bus, "guide": "off", "save_dir": t.user_dir()})
	root.add_child(game)
	return game
