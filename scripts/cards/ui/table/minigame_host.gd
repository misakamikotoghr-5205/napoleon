# 小游戏宿主：听 minigame_requested，按 §8.1 表实例化、start(params)。finished 后延迟发 mg.report。
# Esc 交给当前小游戏 abort()。放在面板之上、指引之下。主人 C01。
# 合同：docs/cards/CARDS_INTERFACES.md §3.3 C01、§8.1。
class_name CardMiniGameHost
extends Control

const EXAMPLE := "res://scripts/cards/mock/example_minigame.gd"
const ABORT_RECT := Rect2(560, 640, 160, 40)   # fallback spot for games that keep no spot free

var engine: CardEngineApi = null
var bus: CardEventBus = null
var current: CardMiniGame = null
var _uid: String = ""
var _item: String = ""
var _abort: Button = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	engine = p_engine
	bus = p_bus
	if not bus.minigame_requested.is_connected(_on_requested):
		bus.minigame_requested.connect(_on_requested)


func is_active() -> bool:
	return current != null


## 自动试玩：用小游戏自己的 autoplay（和玩家一样的路径）
func autoplay_current(skill: float) -> void:
	if current != null:
		current.autoplay(skill)


## “算了”和 Esc 都走这里。current 要等 finished 回调里再清，不然报告会被丢掉。
func abort() -> void:
	if current != null:
		current.abort()


## Esc 放在 _unhandled_input。帮助这类叠层在 _input 里先关掉自己（C10）；没人接的 Esc 才 abort。
func _unhandled_input(event: InputEvent) -> void:
	if current == null or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	abort()


func _on_requested(uid: String, item_id: String, kind: StringName, params: Dictionary) -> void:
	if current != null:
		current.queue_free()
		current = null
	var mg := _make(kind)
	_uid = uid
	_item = item_id
	current = mg
	add_child(mg)
	_ensure_abort()
	_abort.visible = true
	move_child(_abort, -1)
	mg.finished.connect(_on_finished.bind(mg))
	mg.start(params)
	_place_abort()


func _on_finished(result: Dictionary, mg: CardMiniGame) -> void:
	if mg != current:
		return
	current = null
	if _abort != null:
		_abort.visible = false
	mg.queue_free()
	# 不在总线回调里同步 send（§7.2）
	engine.send.call_deferred(&"mg.report", {"uid": _uid, "item": _item, "result": result})


func _make(kind: StringName) -> CardMiniGame:
	var path := str(CardIds.MINIGAME_SCENES.get(kind, ""))
	if path != "" and ResourceLoader.exists(path):
		var node: Node = load(path).instantiate()
		if node is CardMiniGame:
			return node as CardMiniGame
		if node != null:
			node.queue_free()
	return (load(EXAMPLE) as GDScript).new() as CardMiniGame


## The visible abort sits where the game keeps a spot free in its own button row (abort_rect(): a Rect2 in
## the game's coordinates), so it no longer lands on the games' own buttons (b03 coin ring, b51 fragments).
## Games without that method keep the old bottom-centre spot. Position only; the layering stays as it was.
func _place_abort() -> void:
	if _abort == null:
		return
	var r := ABORT_RECT
	if current != null and current.has_method("abort_rect"):
		var got = current.call("abort_rect")
		if got is Rect2 and (got as Rect2).has_area():
			r = Rect2(current.position + (got as Rect2).position, (got as Rect2).size)
	_abort.position = r.position
	_abort.size = r.size


func _ensure_abort() -> void:
	if _abort != null:
		return
	_abort = Button.new()
	_abort.name = "Abort"
	_abort.text = CardText.ui("c01.btn.mg_abort")
	_abort.position = ABORT_RECT.position
	_abort.size = ABORT_RECT.size
	_abort.focus_mode = Control.FOCUS_ALL
	_abort.visible = false
	_abort.pressed.connect(abort)
	add_child(_abort)
