# X01-b release blocker: the shipped build's main scene is CardGame.tscn (run/main_scene.ship) and it
# starts with no command-line args. Booting it that way, and boot() without a mock option, must run
# CardEngine, never MockCardEngine. Same script, other suite lines:
#   --cards (X01_boot_main_cards): Main.tscn hands over to CardGame.tscn, still the real engine.
#   --cards-mock (X01_boot_mock_flag): only the explicit flag selects Mock.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const MAIN_SCENE := "res://scenes/Main.tscn"


func _initialize() -> void:
	var test_name := "X01_boot_ship"
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--name="):
			test_name = str(a).substr(7)
	var t := T.new(self, test_name)
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var args := OS.get_cmdline_user_args()
	var want_mock := args.has("--cards-mock")
	var via_main := args.has("--cards")
	if not want_mock and not via_main:
		t.eq(ProjectSettings.get_setting("application/run/main_scene.ship", ""), CardIds.ROOT_SCENE,
			"ship main scene is CardGame.tscn")
		await _bare_boot(t)
	change_scene_to_file(MAIN_SCENE if via_main else CardIds.ROOT_SCENE)
	var game: CardGameRoot = null
	for i in range(30):
		await process_frame
		game = current_scene as CardGameRoot
		if game != null and game.engine != null:
			break
	t.ok(game != null, "CardGame.tscn is the running scene")
	if game == null:
		return
	game.allow_quit = false
	var label := "--cards-mock" if want_mock else ("Main.tscn --cards" if via_main else "no args")
	t.eq(game.engine is MockCardEngine, want_mock, label + ": Mock only with --cards-mock")
	if not want_mock:
		t.ok(game.engine is CardEngine, label + ": boots CardEngine")
	t.ok(game.title != null, label + ": starts at the title")
	t.eq(game._cmdline_opts().get("mock"), want_mock, label + ": command-line engine choice")
	game.queue_free()
	await process_frame
	await process_frame


## boot() with no mock option (an embedder that passes nothing about the engine) is the real engine too.
func _bare_boot(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	game.boot({"bus": bus, "guide": "off", "save_dir": t.user_dir()})
	root.add_child(game)
	await t.frames(2)
	t.ok(game.engine is CardEngine and not (game.engine is MockCardEngine), "boot() without mock option uses CardEngine")
	game.queue_free()
	bus.queue_free()
	await t.frames(2)
