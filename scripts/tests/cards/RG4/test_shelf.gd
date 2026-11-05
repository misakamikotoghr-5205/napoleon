# RG4 curio shelf in the scene (card_stage.gd + curio_shelf.gd; ROGUE_V1.md 7.4): on the Mock root
# (boot {mock, fixture: rogue_drawer, skip_title}) the four held relics stand in CardLayout.curio_cell(0..3), 64 x 64,
# nearest filter, in held order; the shelf never takes the mouse, so a real click on the curio hotspot opens the
# relics drawer; on the street (and in prison) the hotspot and the relics are both hidden; a.scene.curio sits in
# CardLayout.CURIO; resting relics are dimmed, at night they take night_tint; a newly arrived relic flashes gold
# once (never with fast animations); clear_play() leaves the shelf alone; at most six cells are drawn; an offer still
# waiting puts a gold frame round the shelf (even an empty one); street and prison say the relics rest (note, line).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG4/rg4_harness.gd")


func _initialize() -> void:
	var t := T.new(self, "RG4_shelf")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	await _cells(t, bus)
	await _click(t, bus)
	await _street(t, bus)
	await _tints(t, bus)
	await _flash(t, bus)
	await _empty(t, bus)
	await _pending(t, bus)
	await _resting_words(t, bus)
	print("RG4_shelf checks %d" % t.checks)
	bus.queue_free()
	await t.frames(2)


func _boot(t, bus: CardEventBus, fixture: String) -> CardGameRoot:
	var game := H.boot(self, bus, fixture)
	await t.frames(4)
	while game.host.top_panel() != null:
		game.host.close_panel(game.host.top_panel())
	game.dialog.clear()
	await t.frames(1)
	return game


func _done(game: CardGameRoot) -> void:
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	await process_frame


func _shelf(game: CardGameRoot) -> Control:
	return game.stage.get_node_or_null("CurioShelf") as Control


func _pictures(shelf: Control) -> Array:
	var out: Array = []
	for child in shelf.get_children():
		if child is TextureRect and child.has_meta("item"):
			out.append(child)
	return out


func _cells(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, "rogue_drawer")
	var shelf := _shelf(game)
	t.ok(shelf != null, "the stage builds a CurioShelf")
	if shelf == null:
		await _done(game)
		return
	t.eq(shelf.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the shelf never takes the mouse")
	t.ok(shelf.is_visible_in_tree(), "the shelf shows in the shop by day")
	var pics := _pictures(shelf)
	t.eq(pics.size(), 4, "four relics on the shelf")
	var want := ["rl.stub_box", "rl.camphor_chest", "rl.oilpaper_umbrella", "rl.rosewood_abacus"]
	for i in pics.size():
		var pic: TextureRect = pics[i]
		t.eq(str(pic.get_meta("item")), want[i], "cell %d holds the %d-th relic taken" % [i, i + 1])
		t.eq(pic.get_global_rect(), CardLayout.curio_cell(i), "cell %d at CardLayout.curio_cell(%d)" % [i, i])
		t.eq(pic.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "cell %d nearest filter" % i)
		t.eq(pic.mouse_filter, Control.MOUSE_FILTER_IGNORE, "cell %d ignores the mouse" % i)
		t.ok(pic.texture != null, "cell %d has art" % i)
		t.ok(CardLayout.CURIO.encloses(pic.get_global_rect()), "cell %d inside the curio shelf" % i)
	t.ok(t.anchor_in(&"a.scene.curio", CardLayout.CURIO), "a.scene.curio inside CardLayout.CURIO")
	t.eq(CardAnchors.rect(&"a.scene.curio"), CardLayout.CURIO, "a.scene.curio is the curio hotspot")
	t.ok(shelf.modulate.is_equal_approx(Color.WHITE), "by day the relics keep their colours")
	game.stage.set_dim_tools(true)
	await t.frames(2)
	t.ok(shelf.modulate.is_equal_approx(CardTheme.color(&"ink_soft")), "locked tools: the relics dim with the shelf")
	game.stage.set_dim_tools(false)
	await t.frames(2)
	t.ok(shelf.modulate.is_equal_approx(Color.WHITE), "freed tools: the relics brighten again")
	t.eq(shelf.get_index() > game.stage.get_node("curio").get_index(), true, "the relics stand over the empty shelf prop")
	var old := shelf.get_instance_id()
	game.stage.clear_play()
	await t.frames(1)
	t.ok(_shelf(game) != null and _shelf(game).get_instance_id() == old and _pictures(_shelf(game)).size() == 4,
		"clear_play leaves the shelf alone")
	await _done(game)


## A real click in the middle of the hotspot (over the relics) opens the relics drawer through the root's route.
func _click(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, "rogue_drawer")
	var cell := CardLayout.curio_cell(1)
	var hovered := await H.hover(self, cell.get_center())
	t.eq(hovered, game.stage.get_node("curio"), "the hotspot is under the mouse over a relic")
	await H.click(self, cell.get_center())
	await t.frames(3)
	t.eq(game.host.top_kind(), &"relics", "clicking the curio shelf opens the relics drawer")
	await _done(game)


func _street(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, "rogue_street")
	var shelf := _shelf(game)
	var hot := game.stage.get_node("curio") as Control
	t.eq(str(game.engine.view().get("stage", {}).get("set", "")), "prison", "rogue_street is the prison set")
	t.ok(not hot.visible, "prison: the curio hotspot is hidden")
	t.ok(shelf != null and not shelf.is_visible_in_tree(), "prison: the relics are hidden with it")
	t.ok(not CardAnchors.has(&"a.scene.curio"), "prison: no curio anchor")
	game.stage.refresh(_with_set(game.engine.view(), "counter"))
	await t.frames(1)
	t.ok(hot.visible and shelf.is_visible_in_tree(), "back at the counter: hotspot and relics again")
	t.ok(shelf.modulate.is_equal_approx(CardTheme.color(&"ink_soft")), "resting relics are dimmed")
	game.stage.refresh(_with_set(game.engine.view(), "street"))
	await t.frames(1)
	t.ok(not hot.visible and not shelf.is_visible_in_tree(), "street: hotspot and relics hidden")
	t.ok(not CardAnchors.has(&"a.scene.curio"), "street: no curio anchor")
	await _done(game)


func _tints(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, "rogue_week")
	var shelf := _shelf(game)
	t.eq(str(game.engine.view().get("stage", {}).get("time", "")), "night", "rogue_week is a night view")
	t.ok(shelf.is_visible_in_tree(), "night: the shelf shows")
	t.eq(_pictures(shelf).size(), 2, "night: two relics")
	t.ok(shelf.modulate.is_equal_approx(CardTheme.color(&"night_tint")), "night: the relics take night_tint")
	await _done(game)


## A relic that just arrived flashes gold once; with fast animations nothing flashes.
func _flash(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, "rogue_drawer")
	var shelf := _shelf(game)
	var view := game.engine.view().duplicate(true)
	view["relics"]["held"].append({"id": "rl.chen_mortar", "art": "prop.relic.chen_mortar", "depth": "storied", "since": 50})
	game.stage.fast = true
	game.stage.refresh(view)
	await t.frames(1)
	t.eq(shelf.call("flashes"), 0, "fast animations: no flash")
	t.eq(_pictures(shelf).size(), 5, "the new relic stands in cell 4")
	view["relics"]["held"].append({"id": "rl.old_almanac", "art": "prop.relic.old_almanac", "depth": "plain", "since": 51})
	game.stage.fast = false
	game.stage.refresh(view)
	await t.frames(1)
	t.eq(shelf.call("flashes"), 1, "a new relic flashes once")
	var glow := shelf.get_node_or_null("Flash5") as ColorRect
	t.ok(glow != null and glow.get_global_rect() == CardLayout.curio_cell(5), "the flash covers the new cell")
	game.stage.refresh(view)
	await t.frames(1)
	t.eq(shelf.call("flashes"), 1, "the same view does not flash again")
	var many := view.duplicate(true)
	for i in 3:
		many["relics"]["held"].append({"id": "rl.extra%d" % i, "art": "prop.relic.cat_bowl", "depth": "plain", "since": 60})
	game.stage.fast = true
	game.stage.refresh(many)
	await t.frames(1)
	t.eq(_pictures(shelf).size(), 6, "at most six cells")
	await create_timer(0.5).timeout
	await t.frames(2)
	t.ok(shelf.get_node_or_null("Flash5") == null, "the flash is gone after its tween")
	await _done(game)


## No relics in the view (example set, Mock day_full): nothing drawn, the hotspot still works.
func _empty(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, "day_full")
	var shelf := _shelf(game)
	t.ok(shelf != null and _pictures(shelf).is_empty(), "day_full: no relics drawn")
	t.ok(not shelf.visible, "day_full: the empty shelf layer stays hidden")
	t.ok((game.stage.get_node("curio") as Control).visible, "day_full: the curio hotspot is up")
	await _done(game)


## An offer still waiting (view.stock.open): a gold frame lies around the shelf, also when it holds nothing yet.
func _pending(t, bus: CardEventBus) -> void:
	var game := await _boot(t, bus, "rogue_drawer")
	var shelf := _shelf(game)
	t.ok(shelf.call("pending_mark") == null, "no offer waiting: no frame")
	await _done(game)
	game = await _boot(t, bus, "rogue_drawer_pending")
	shelf = _shelf(game)
	var mark: Control = shelf.call("pending_mark")
	t.ok(mark != null and mark.is_visible_in_tree(), "an offer waits: the shelf has a gold frame")
	if mark != null:
		t.ok(mark.get_global_rect().encloses(CardLayout.CURIO), "the frame goes round the curio shelf")
		t.eq(mark.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the frame never takes the mouse")
	var view := game.engine.view()
	view["relics"]["held"] = []
	view["relics"]["count"] = 0
	game.stage.refresh(view)
	await t.frames(1)
	t.ok(shelf.is_visible_in_tree() and _pictures(shelf).is_empty(), "empty shelf with an offer waiting: the frame shows")
	view["stock"]["open"] = ""
	game.stage.refresh(view)
	await t.frames(1)
	t.ok(not shelf.is_visible_in_tree(), "picked: an empty shelf layer hides again")
	await _done(game)


## Street and prison hide the shelf: the street note and the prison dialog say the relics rest.
func _resting_words(t, bus: CardEventBus) -> void:
	var game := H.boot(self, bus, "rogue_street")
	await t.frames(6)
	var refs: Array = []
	for row in game.dialog.get("_lines"):
		refs.append(str(row.get("ref", "")))
	t.ok(refs.has("rg4.relics.away"), "prison with relics held: the dialog says they rest " + str(refs))
	var note := game.find_child("relics_rest", true, false) as Label
	t.ok(note != null and note.is_visible_in_tree(), "street with relics held: a note says they rest")
	if note != null:
		t.eq(note.text, CardText.ui("rg4.relics.away"), "street note words")
		var hint := note.get_parent().get_node("hint") as Control
		t.ok(note.get_global_rect().end.y <= hint.get_global_rect().position.y, "the note sits above the street hint")
	await _done(game)


func _with_set(view: Dictionary, set_name: String) -> Dictionary:
	var v := view.duplicate(true)
	var stage: Dictionary = v.get("stage", {})
	stage["set"] = set_name
	v["stage"] = stage
	v["mode"] = "shop" if set_name == "counter" else set_name
	return v
