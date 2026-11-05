# C04 test helpers. No class_name. Fixtures live next to this file.
# boot() builds the card-game root (画面根) on the fixture. Callers await one frame,
# then play() presses the card the same way the table does.
extends RefCounted

# Warm DemandPanel static PackedScene table + counter scenes before timed opens
# (same idea as C08 support._warm). Keeps C04 open()/rebuild budgets honest.
const _WarmDemand := preload("res://scripts/cards/ui/demand/demand_panel.gd")
const _WarmCounter := preload("res://scenes/cards/counter/CounterPanel.tscn")
const _WarmDialog := preload("res://scenes/cards/counter/DialogBox.tscn")
const _WarmShelf := preload("res://scenes/cards/counter/ShelfDrawer.tscn")
const _WarmTickets := preload("res://scenes/cards/counter/TicketsDrawer.tscn")

const DIR := "res://scripts/tests/cards/C04/fixtures/"
const ROOT := "res://scenes/cards/CardGame.tscn"

static var _warmed: bool = false


static func _warm() -> void:
	if _warmed:
		return
	_warmed = true
	if _WarmDemand == null:
		push_error("C04 support: demand script failed to load")
	for packed in [_WarmCounter, _WarmDialog, _WarmShelf, _WarmTickets]:
		if packed == null:
			push_error("C04 support: counter packed scene failed to load")
			continue
		var node: Node = packed.instantiate()
		node.free()


static func path(name: String) -> String:
	return DIR + name + ".json"


static func read(name: String):
	return CardDB.read_json(path(name))


static func boot(tree: SceneTree, name: String) -> Dictionary:
	_warm()
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var game: CardGameRoot = load(ROOT).instantiate()
	tree.root.add_child(game)
	game.boot({"mock": true,
		"bus": bus,
		"fixture": path(name),
		"skip_title": true,
		"guide": "off",
	})
	return {"bus": bus, "mock": game.engine, "game": game}


static func play(ctx: Dictionary, uid: String) -> CardCounterPanel:
	var game: CardGameRoot = ctx.game
	game._on_card_pressed(uid)
	return game.host.top_panel() as CardCounterPanel


static func button(panel: Node, node_name: String) -> Button:
	var n := panel.find_child(node_name, true, false)
	if n == null and panel.get_tree() != null:
		n = panel.get_tree().root.find_child(node_name, true, false)
	return n as Button


static func label(panel: Node, node_name: String) -> Label:
	var n := panel.find_child(node_name, true, false)
	if n == null and panel.get_tree() != null:
		n = panel.get_tree().root.find_child(node_name, true, false)
	return n as Label


static func cmds(mock: MockCardEngine) -> Array:
	var out: Array = []
	for row in mock.sent:
		var cmd := str(row[0])
		if cmd == "game.new" or cmd.begins_with("ui."):
			continue
		out.append([row[0], (row[1] as Dictionary).duplicate(true)])
	return out


static func free_all(nodes: Array) -> void:
	for n in nodes:
		if n != null and is_instance_valid(n):
			n.queue_free()


## Close panels and drop the mock ref held in ctx, then queue_free game/bus.
## Callers must await frames afterward so queue_free runs before process exit.
## Do not null game.engine before free — deferred _sync_phase_panel still needs it.
static func free_ctx(ctx: Dictionary) -> void:
	var game = ctx.get("game")
	var bus = ctx.get("bus")
	ctx.clear()
	if game != null and is_instance_valid(game) and "host" in game and game.host != null:
		while game.host.top_panel() != null:
			game.host.close_top()
	free_all([game, bus])
