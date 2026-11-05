# C15 tests, shared: fixtures, mounting a game on a host with a bus, mouse input, and the judges the tests
# use to score the player's calls (same rules as DESIGN 7.5 / 8.5 and G04's judge). Owner C15.
extends RefCounted

const FRAG := "res://scenes/cards/minigames/fragments/FragmentsGame.tscn"
const DEC := "res://scenes/cards/minigames/decode/DecodeGame.tscn"
const BOOK := "res://data/cards/minigames/codebook.json"
const FRAG_FIXTURES := ["ticket196.json", "ticket_fake.json", "ticket_real.json", "letter_missing.json",
	"letter5.json", "scroll.json", "scroll8.json"]
const DEC_FIXTURES := ["telegram.json", "ledger.json", "chen_code.json", "ledger_key.json"]


static func params(name: String) -> Dictionary:
	var raw = CardDB.read_json("res://scripts/tests/cards/C15/fixtures/" + name)
	var p: Dictionary = CardState.int_restore(raw)
	if bool(p.get("_with_book", false)):
		p.erase("_with_book")
		p["book"] = book_rows()
	return p


## The real code book as the engine passes it: [[code, word key], ...] sorted by code.
static func book_rows() -> Array:
	var out: Array = []
	var doc = CardDB.read_json(BOOK)
	if typeof(doc) != TYPE_DICTIONARY:
		return out
	var codes: Array = (doc.get("codes", {}) as Dictionary).keys()
	codes.sort()
	for c in codes:
		out.append([str(c), str(doc["codes"][c].get("key", ""))])
	return out


static func open_game(tree: SceneTree, scene: String, fix: Dictionary) -> Dictionary:
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var host := CardMiniGameHost.new()
	host.bus = bus
	tree.root.add_child(host)
	var game = load(scene).instantiate()
	host.add_child(game)
	game.start(fix)
	return {"bus": bus, "mock": mock, "host": host, "game": game}


static func close(ctx: Dictionary) -> void:
	(ctx["host"] as Node).queue_free()
	(ctx["bus"] as Node).queue_free()
	CardAnchors.clear()


static func take(game: Node) -> Dictionary:
	var box := {"r": {}}
	if not game.finished.is_connected(_keep.bind(box)):
		game.finished.connect(_keep.bind(box))
	return box


static func _keep(result: Dictionary, box: Dictionary) -> void:
	box["r"] = result


static func press(game: Node, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = key
	ev.physical_keycode = key
	ev.echo = false
	game._input(ev)


# ---------------- mouse (viewport coords, like a real pointer) ----------------
static func move(tree: SceneTree, at: Vector2, mask: int = 0) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	ev.button_mask = mask
	tree.root.push_input(ev, true)


static func button(tree: SceneTree, at: Vector2, pressed: bool, which: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = which
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if which == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	tree.root.push_input(ev, true)


static func click(tree: SceneTree, at: Vector2, which: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	move(tree, at)
	button(tree, at, true, which)
	button(tree, at, false, which)


static func drag(tree: SceneTree, from: Vector2, to: Vector2) -> void:
	move(tree, from)
	button(tree, from, true)
	var steps := 6
	for i in range(1, steps + 1):
		move(tree, from.lerp(to, float(i) / float(steps)), MOUSE_BUTTON_MASK_LEFT)
	button(tree, to, false)


# ---------------- judges (the tests' own reading of the hidden answer) ----------------
## Fragments: answer = {seal_off: seal_offset_px >= 2, odd: ink_mismatch}. A crossed seam touching other
## paper finds that piece (one right each); a crossed seam between two plain pieces is wrong. Seal: "offset"
## on an offset seal is right, on an aligned one wrong; "aligned" is correct only on an aligned seal.
static func judge_frag(game, result: Dictionary) -> Dictionary:
	var L: Dictionary = game.layout()
	var odd: Array = L["odd"]
	var seal: Dictionary = L["seal"]
	var off := not seal.is_empty() and int(seal["shift"]) >= 2
	var m: Dictionary = result.get("measures", {})
	var found: Dictionary = {}
	var right := 0
	var wrong := 0
	var calls := 0
	var good := 0
	for pair in m.get("seams", []):
		calls += 1
		var a := int(pair[0])
		var b := int(pair[1])
		if odd.has(a) or odd.has(b):
			good += 1
			for q in [a, b]:
				if odd.has(q) and not found.has(q):
					found[q] = true
					right += 1
		else:
			wrong += 1
	var call := int(m.get("seal_call", 0))
	if call != 0:
		calls += 1
		if call == (2 if off else 1):
			good += 1
		if call == 2:
			if off:
				right += 1
			else:
				wrong += 1
	var chances := odd.size() + (0 if seal.is_empty() else 1)
	var seal_ok := seal.is_empty() or call == (2 if off else 1)
	return {"right": right, "wrong": wrong, "found": found.size(), "odd": odd.size(), "calls": calls, "good": good,
		"chances": chances, "all": wrong == 0 and found.size() == odd.size() and seal_ok, "seal_ok": seal_ok}


## Decode: each copied group is right when it is the group's real code, wrong otherwise; blank is neither.
static func judge_decode(codes: Array, result: Dictionary) -> Dictionary:
	var picked: Array = result.get("measures", {}).get("picked", [])
	var right := 0
	var wrong := 0
	for g in range(mini(codes.size(), picked.size())):
		var v := int(picked[g])
		if v < 0:
			continue
		if v == int(str(codes[g])):
			right += 1
		else:
			wrong += 1
	return {"right": right, "wrong": wrong, "groups": codes.size()}


## Plays ops on a fresh game and returns its result.
static func replay(tree: SceneTree, scene: String, fix: Dictionary, ops: Array) -> Dictionary:
	var ctx := open_game(tree, scene, fix)
	var box := take(ctx["game"])
	for op in ops:
		ctx["game"].apply_op(op)
	var r: Dictionary = box["r"]
	close(ctx)
	return r
