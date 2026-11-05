# C14 test fixtures and helpers. No class_name.
extends RefCounted

const SCENE := "res://scenes/cards/minigames/weigh/WeighGame.tscn"
const CATALOG := "res://data/cards/minigames/obs/weigh.json"
const FIXTURES := ["match", "light_small", "light_much", "heavy", "steelyard_rice"]
## The four categories by fixture (the steelyard rice fixture balances on its claim).
const EXPECT := {
	"match": "match",
	"light_small": "light_small",
	"light_much": "light_much",
	"heavy": "heavy",
	"steelyard_rice": "match",
}
const CALLS := ["", "match", "light_small", "light_much", "heavy", "unsure"]


func setup_text() -> void:
	CardText.setup(CardDB.load_all())


func params(name: String) -> Dictionary:
	var d = CardDB.read_json("res://scripts/tests/cards/C14/fixtures/%s.json" % name)
	return CardState.int_restore(d)


func catalog() -> Dictionary:
	var d = CardDB.read_json(CATALOG)
	return d["obs"] if typeof(d) == TYPE_DICTIONARY else {}


func open(tree: SceneTree, pars: Dictionary, bus: CardEventBus = null) -> Variant:
	var game: Variant = (load(SCENE) as PackedScene).instantiate()
	game.bus = bus
	tree.root.add_child(game)
	game.start(pars)
	return game


func play(game, skill: float) -> Dictionary:
	var box := {"r": {}}
	game.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	game.autoplay(skill)
	return box["r"]


## Runs ops on a fresh game and returns the result (an empty dict if it never finished).
func replay(tree: SceneTree, pars: Dictionary, ops: Array) -> Dictionary:
	var game = open(tree, pars)
	var box := {"r": {}}
	game.finished.connect(func(r: Dictionary) -> void: box["r"] = r)
	for op in ops:
		game.apply_op(op)
	game.queue_free()
	return box["r"]


func run_skill(tree: SceneTree, pars: Dictionary, skill: float) -> Dictionary:
	var game = open(tree, pars)
	var result := play(game, skill)
	game.queue_free()
	return result


## The test's own answer rule (DESIGN 6.2), written out here so the game's rule file is checked, not trusted.
func answer(pars: Dictionary) -> String:
	var res := maxi(1, int(pars.get("resolution_fen", 1)))
	var claimed := int(pars.get("claimed_fen", 0))
	var d := int(pars.get("actual_fen", 0)) - claimed
	var small := int(pars["small_fen"]) if pars.has("small_fen") else claimed * 60 / 1000
	if absi(d) <= res:
		return "match"
	if d > 0:
		return "heavy"
	return "light_small" if -d <= small else "light_much"


## G04's scoring as DESIGN 6.5 states it: right / soft / wrong for one call.
func judge(answer_cat: String, call: String) -> String:
	if (call == "light_much" or call == "heavy") and call == answer_cat:
		return "right"
	if call == "light_small" and answer_cat == "light_small":
		return "soft"
	if (call == "light_much" or call == "heavy") and (answer_cat == "match" or answer_cat == "light_small"):
		return "wrong"
	return ""


func call_of(result: Dictionary) -> String:
	var obs: Array = result.get("observations", [])
	if obs.size() != 1:
		return ""
	return str(obs[0]).trim_prefix("obs.weigh.")


## Ops that level the beam the slow way (only weight / poise ops), from the game's opening state.
func level_ops(game) -> Array:
	var out: Array = []
	game._phase = 0
	for _i in 64:
		if game._level():
			break
		var op: Array = game._skilled_op()
		if op.is_empty() or not game.apply_op(op):
			break
		out.append(op)
	return out


func signature(game) -> String:
	var bits := ""
	for on in game._on:
		bits += "1" if on else "0"
	return "%s:%d" % [bits, game._poise_step]


func assert_shape(t, result: Dictionary, obs_cat: Dictionary) -> void:
	var keys: Array = []
	for k in result.keys():
		keys.append(str(k))
	keys.sort()
	t.eq(keys, ["aborted", "measures", "minutes", "observations", "quality_permille"], "result keys")
	t.eq(typeof(result["quality_permille"]), TYPE_INT, "quality is int")
	t.eq(typeof(result["minutes"]), TYPE_INT, "minutes is int")
	t.eq(typeof(result["aborted"]), TYPE_BOOL, "aborted is bool")
	var q := int(result["quality_permille"])
	t.ok(q >= 0 and q <= 1000, "quality 0-1000 (%d)" % q)
	t.ok(t.find_floats(result).is_empty(), "result has no floats")
	var measures: Dictionary = result["measures"]
	var mk: Array = []
	for k in measures.keys():
		mk.append(str(k))
	mk.sort()
	t.eq(mk, ["call", "commits", "read_fen", "steps"], "measures keys")
	for k in mk:
		t.eq(typeof(measures[k]), TYPE_INT, "measure %s is int" % k)
	t.no_leaks(measures, "measures")
	var obs: Array = result["observations"]
	t.ok(obs.size() == 1, "one observation")
	if obs.size() == 1:
		t.ok(obs_cat.has(str(obs[0])), "observation in catalog: " + str(obs[0]))


func fidelity(obs_cat: Dictionary, result: Dictionary) -> String:
	var key := str((result["observations"] as Array)[0])
	return str(obs_cat[key].get("fidelity", ""))


## Visible text that gives away the hidden weight: the actual fen as a number, or a percent sign.
func secret_text(node: Node, actual: int) -> PackedStringArray:
	var bad := PackedStringArray()
	var needle := str(actual)
	for txt in visible_text(node):
		if txt.contains("%") or (needle != "" and txt.contains(needle)):
			bad.append(txt)
	return bad


## Every string a player can see: labels, buttons and the numbers the drawings put on the stars and weights.
func visible_text(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for n in _walk(node):
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
		elif n is RichTextLabel:
			out.append((n as RichTextLabel).get_parsed_text())
		if n.has_method("tick_texts"):
			for s in n.tick_texts():
				out.append(str(s))
	return out


func tap(tree: SceneTree, key: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = key
	ev.physical_keycode = key
	ev.echo = false
	tree.root.push_input(ev)
	await tree.process_frame
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	tree.root.push_input(up)
	await tree.process_frame


# ---------------- mouse (screen coordinates, 1280x720) ----------------

func move(tree: SceneTree, pos: Vector2, mask: int = 0) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	mv.button_mask = mask
	tree.root.push_input(mv, true)
	await tree.process_frame


func click(tree: SceneTree, pos: Vector2) -> void:
	await move(tree, pos)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	tree.root.push_input(down, true)
	await tree.process_frame
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	tree.root.push_input(up, true)
	await tree.process_frame
	await tree.process_frame


func drag(tree: SceneTree, from: Vector2, to: Vector2) -> void:
	await move(tree, from)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	down.global_position = from
	tree.root.push_input(down, true)
	await tree.process_frame
	for k in range(1, 6):
		await move(tree, from.lerp(to, float(k) / 5.0), MOUSE_BUTTON_MASK_LEFT)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	up.position = to
	up.global_position = to
	tree.root.push_input(up, true)
	await tree.process_frame
	await tree.process_frame


func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
