# The minigame host's visible abort button sits in the spot the game keeps free in its own button row:
# it overlaps no game button, stays inside the game's frame and on screen (b03: coin ring with one coin,
# its "done" sat under the abort; b51: fragments tools under the abort). Shared by C12-C15:
#   --game=spot|coin_ring|weigh|fragments|decode  --name=<suite line name>
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const Spot = preload("res://scripts/tests/cards/C12/c12_lib.gd")
const Weigh = preload("res://scripts/tests/cards/C14/weigh_fix.gd")
const Frag = preload("res://scripts/tests/cards/C15/harness.gd")


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_host_abort"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var game := H.arg("game", "coin_ring")
	var cases: Array = []
	match game:
		"spot":
			cases = [Spot.fixture("hairpin"), Spot.fixture("no_atlas")]
		"coin_ring":
			cases = [H.fixture("good"), H.fixture("stack")]
		"weigh":
			cases = [Weigh.new().params("steelyard_rice"), Weigh.new().params("match")]
		"fragments":
			cases = [Frag.params("ticket196.json")]
		"decode":
			cases = [Frag.params("telegram.json"), Frag.params("ledger.json")]
	t.ok(not cases.is_empty(), "cases for " + game)
	for i in cases.size():
		await _case(t, StringName(game), cases[i], i)


func _case(t, kind: StringName, params: Dictionary, index: int) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var host := CardMiniGameHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	host._on_requested("c0001", "I001", kind, params)
	await t.frames(3)
	var label := "%s #%d" % [kind, index]
	var mg := host.current
	t.ok(mg != null and mg.has_method("abort_rect"), label + " keeps an abort spot")
	var abort := host.get_node("Abort") as Button
	t.ok(abort.visible, label + " abort visible")
	var r := abort.get_global_rect()
	t.ok(Rect2(0, 0, 1280, 720).encloses(r), label + " abort on screen %s" % r)
	var frame := CardAnchors.rect(StringName("a.mg.%s.main" % kind))
	t.ok(frame.has_area() and frame.grow(1.0).encloses(r), label + " abort inside the game frame %s %s" % [r, frame])
	var hits := PackedStringArray()
	for n in _walk(mg):
		if n is BaseButton and (n as Control).is_visible_in_tree():
			var b := (n as Control).get_global_rect()
			if b.intersects(r):
				hits.append("%s %s" % [n.name, b])
	t.eq(hits, PackedStringArray(), label + " no game button under the abort")
	host.abort()
	await t.frames(2)
	t.ok(not host.is_active(), label + " abort still ends the game")
	host.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await t.frames(2)


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
