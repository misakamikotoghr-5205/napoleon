# C12 test helpers: fixtures, opening a round, real mouse input, and the test's own judge.
# Owner C12.
extends RefCounted

const SCENE := "res://scenes/cards/minigames/spot/SpotGame.tscn"
const FIX_DIR := "res://scripts/tests/cards/C12/fixtures"
const RESULT_KEYS: Array[String] = ["aborted", "measures", "minutes", "observations", "quality_permille"]
const MEASURE_KEYS: Array[String] = ["atlas", "ink_used", "lens", "spots"]
const Marks = preload("res://scripts/cards/minigames/spot/spot_marks.gd")
const PanelScript = preload("res://scripts/cards/minigames/spot/spot_panel.gd")
const WellScript = preload("res://scripts/cards/minigames/spot/spot_well.gd")


static func fixture(name: String) -> Dictionary:
	return CardState.int_restore(CardDB.read_json("%s/%s.json" % [FIX_DIR, name]))


## Old engine params (no at / look / legend) and new ones (DESIGN 4.2).
static func fixture_names() -> PackedStringArray:
	return PackedStringArray(["hairpin", "scroll", "rice", "fine_only", "no_atlas", "hairpin3", "hairpin3_clean",
		"scroll3"])


static func old_fixture_names() -> PackedStringArray:
	return PackedStringArray(["hairpin", "scroll", "rice", "fine_only", "no_atlas"])


static func new_fixture_names() -> PackedStringArray:
	return PackedStringArray(["hairpin3", "hairpin3_clean", "scroll3"])


static func open_game(tree: SceneTree, params: Dictionary) -> CardSpotGame:
	var game: CardSpotGame = load(SCENE).instantiate()
	tree.root.add_child(game)
	game.start(params)
	return game


static func run(tree: SceneTree, params: Dictionary, action: Callable) -> Dictionary:
	var game := open_game(tree, params)
	var box: Array = [null]
	game.finished.connect(func(result: Dictionary) -> void: box[0] = result)
	action.call(game)
	game.queue_free()
	return box[0]


## Plays ops on a fresh game; returns the result (null when the ops never finish it).
static func replay(tree: SceneTree, params: Dictionary, ops: Array) -> Variant:
	return run(tree, params, func(g: CardSpotGame) -> void:
		for op in ops:
			g.apply_op(op)
	)


static func keys_of(d: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in d.keys():
		out.append(str(k))
	out.sort()
	return out


# ---------------- mouse ----------------
static func board(game: CardSpotGame) -> Control:
	return game.get_node("Board") as Control


## Screen position of item pixel (x, y) in the item well.
static func item_px(game: CardSpotGame, x: int, y: int) -> Vector2:
	var b := board(game)
	return b.get_global_rect().position + PanelScript.ITEM_AT + WellScript.pixel_center(Vector2i(x, y))


static func center_of(node: Control) -> Vector2:
	return node.get_global_rect().get_center()


static func move(tree: SceneTree, at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	tree.root.push_input(ev, true)


static func button_event(tree: SceneTree, at: Vector2, pressed: bool, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = at
	ev.global_position = at
	ev.button_index = index
	ev.pressed = pressed
	if pressed:
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if index == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	tree.root.push_input(ev, true)


## Move there, press, release (a real click through the viewport).
static func click(tree: SceneTree, at: Vector2, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	move(tree, at)
	button_event(tree, at, true, index)
	button_event(tree, at, false, index)


static func click_node(tree: SceneTree, node: Control) -> void:
	click(tree, center_of(node))


static func bubble_button(game: CardSpotGame, node_name: String) -> Button:
	return board(game).get_node("Bubble/" + node_name) as Button


## Pin item pixel (x, y) with tag 1 (wear) / 2 (differs) by clicking the item, then the call.
static func click_pin(tree: SceneTree, game: CardSpotGame, x: int, y: int, tag: int) -> void:
	click(tree, item_px(game, x, y))
	click_node(tree, bubble_button(game, "TagWear" if tag == 1 else "TagDiffers"))


# ---------------- the test's own judge (same rules as G04 judge, DESIGN 4.5) ----------------
## Per pin: inside a mark's spot grown by 2 px (coarse) / 1 px (fine)? Same call = right (differs) or
## soft (wear); wear called differs = wrong; differs called wear = 0; off every mark: differs = wrong.
static func judge(params: Dictionary, spots: Array) -> Dictionary:
	var out := {"right": 0, "soft": 0, "wrong": 0, "missed": 0, "idle": 0}
	var parts: Array = params.get("parts", [])
	for s in spots:
		var x := int(s[0])
		var y := int(s[1])
		var tag := int(s[2])
		var found: Dictionary = {}
		for mark in params.get("marks", []):
			var tol := 1 if Marks.is_fine(mark, parts) else 2
			if Marks.spot_rect(mark, parts).grow(tol).has_point(Vector2i(x, y)):
				found = mark
				break
		if found.is_empty():
			out["wrong" if tag == 2 else "idle"] += 1
			continue
		var wear := str(found.get("kind", "")) == "wear"
		if wear and tag == 1:
			out["soft"] += 1
		elif not wear and tag == 2:
			out["right"] += 1
		elif wear:
			out["wrong"] += 1
		else:
			out["missed"] += 1
	return out


## The right answer for every mark: [x, y, tag] at the middle of its spot.
static func answer(params: Dictionary) -> Array:
	var out: Array = []
	var parts: Array = params.get("parts", [])
	for mark in params.get("marks", []):
		var r := Marks.spot_rect(mark, parts)
		var mid := r.position + r.size / 2
		out.append([mid.x, mid.y, 1 if str(mark.get("kind", "")) == "wear" else 2])
	return out


static func part_ids() -> PackedStringArray:
	var ids: Dictionary = {}
	var town = CardDB.read_json("res://data/town/item_templates.json")
	_from_sprites(town, ids)
	_from_parts(town, ids)
	for rel in ["res://data/cards/items/templates_extra.json", "res://data/cards/_examples/items/templates_extra.json"]:
		var extra = CardDB.read_json(rel)
		if typeof(extra) != TYPE_DICTIONARY:
			continue
		_from_sprites(extra, ids)
		_from_parts(extra, ids)
	var out := PackedStringArray()
	for k in ids.keys():
		out.append(str(k))
	out.sort()
	return out


static func _from_sprites(doc, ids: Dictionary) -> void:
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var sprites = doc.get("appraise", {}).get("sprites", {})
	if typeof(sprites) != TYPE_DICTIONARY:
		return
	for body in sprites.values():
		if typeof(body) != TYPE_DICTIONARY:
			continue
		for key in body.keys():
			if str(key) == "pool" or str(key).begins_with("_"):
				continue
			ids[str(key)] = true


static func _from_parts(node, ids: Dictionary) -> void:
	if typeof(node) == TYPE_DICTIONARY:
		if typeof(node.get("parts")) == TYPE_ARRAY:
			for part in node["parts"]:
				if typeof(part) == TYPE_DICTIONARY and part.has("id"):
					ids[str(part["id"])] = true
		for k in node.keys():
			_from_parts(node[k], ids)
	elif typeof(node) == TYPE_ARRAY:
		for v in node:
			_from_parts(v, ids)
