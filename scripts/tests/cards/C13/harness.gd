# C13 测试共用：读夹具、开一局、按 op 玩、用真的鼠标事件点。主人 C13。
# 夹具：good/bad/one_try/stack 是改版前的老参数（没有 samples/ghosts/clink，测兼容）；
# v2_* 是 appraise/DESIGN.md §5.2 的新参数。ANSWERS 是测试自己“看参数出答案”（哪几枚是哑的），小游戏读不到。
extends RefCounted

const FIX_DIR := "res://scripts/tests/cards/C13/fixtures"
const GUIDE_STEPS := "res://scripts/tests/cards/C13/guide_steps.json"
const SCENE := "res://scenes/cards/minigames/coin_ring/CoinRingGame.tscn"
## 夹具里哪几枚是哑的（下标）。
const ANSWERS := {
	"good": [], "bad": [0], "one_try": [], "stack": [2],
	"v2_good": [], "v2_worn": [], "v2_dull": [0], "v2_wellmade": [0], "v2_stack": [2, 4],
}
const ALL := ["good", "bad", "one_try", "stack", "v2_good", "v2_worn", "v2_dull", "v2_wellmade", "v2_stack"]


static func open(tree: SceneTree, fix: Dictionary, p_bus: CardEventBus, fast: bool = true) -> CardCoinRingGame:
	var packed := load(SCENE) as PackedScene
	var g := packed.instantiate() as CardCoinRingGame
	g.bus = p_bus
	g.fast_anim = fast
	tree.root.add_child(g)
	g.start(fix)
	return g


static func fixture(name: String) -> Dictionary:
	return read_json("%s/%s.json" % [FIX_DIR, name])


static func read_json(path: String) -> Dictionary:
	var d = CardDB.read_json(path)
	return d if typeof(d) == TYPE_DICTIONARY else {}


static func arg(key: String, fallback: String = "") -> String:
	var prefix := "--%s=" % key
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback


## 开一局、按 ops 走完，返回 {result, ops, game_ok}（game 已经释放）。
static func run_ops(tree: SceneTree, fix: Dictionary, ops: Array) -> Dictionary:
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var g := open(tree, fix, bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	var accepted: Array = []
	for op in ops:
		accepted.append(g.apply_op(op))
	var out := {"result": box[0] if box[0] != null else {}, "ops": g.ops_log(), "accepted": accepted}
	await drop(tree, [g, bus])
	return out


## 开一局、autoplay(skill)，返回 {result, ops}。
static func auto(tree: SceneTree, fix: Dictionary, skill: float) -> Dictionary:
	var bus := CardEventBus.new()
	tree.root.add_child(bus)
	var g := open(tree, fix, bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	g.autoplay(skill)
	var out := {"result": box[0] if box[0] != null else {}, "ops": g.ops_log()}
	await drop(tree, [g, bus])
	return out


## 每一枚玩家说的是什么：1 响（像足银）、2 哑（像哑板）、0 没定 / 说不好。单枚看 call，一摞看 marks。
static func judged(result: Dictionary) -> Array:
	var m: Dictionary = result.get("measures", {})
	return (m.get("marks", []) as Array).duplicate()


## G04 的判分规则（DESIGN §5.5），测试自己写一遍：right = 标哑的坏枚数，wrong = 标哑的好枚数。
static func judge(name: String, result: Dictionary) -> Dictionary:
	var bad: Array = ANSWERS.get(name, [])
	var right := 0
	var wrong := 0
	var marks := judged(result)
	for i in range(marks.size()):
		if int(marks[i]) != 2:
			continue
		if bad.has(i):
			right += 1
		else:
			wrong += 1
	return {"right": right, "wrong": wrong}


## 每一枚都判对了吗（坏的标哑、好的标响）。
static func all_right(name: String, result: Dictionary) -> bool:
	var bad: Array = ANSWERS.get(name, [])
	var marks := judged(result)
	var n := (fixture(name).get("coins", []) as Array).size()
	if marks.size() != n:
		return false
	for i in range(n):
		if int(marks[i]) != (2 if bad.has(i) else 1):
			return false
	return true


## 每一枚都判错了吗（坏的标响、好的标哑）。
static func all_wrong(name: String, result: Dictionary) -> bool:
	var bad: Array = ANSWERS.get(name, [])
	var marks := judged(result)
	var n := (fixture(name).get("coins", []) as Array).size()
	if marks.size() != n:
		return false
	for i in range(n):
		if int(marks[i]) != (1 if bad.has(i) else 2):
			return false
	return true


# ---------------- 真的鼠标 ----------------

static func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


static func move(g: Node, at: Vector2, mask: int = 0) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	mv.button_mask = mask
	g.get_viewport().push_input(mv, true)


static func button(g: Node, at: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = at
	mb.global_position = at
	mb.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	g.get_viewport().push_input(mb, true)


static func click(g: Node, at: Vector2) -> void:
	move(g, at)
	button(g, at, true)
	button(g, at, false)


static func drag(g: Node, from: Vector2, to: Vector2) -> void:
	move(g, from)
	button(g, from, true)
	for k in range(1, 7):
		move(g, from.lerp(to, float(k) / 6.0), MOUSE_BUTTON_MASK_LEFT)
	button(g, to, false)


static func key(g: Node, code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		g.get_viewport().push_input(ev)


static func drop(tree: SceneTree, nodes: Array) -> void:
	for n in nodes:
		if is_instance_valid(n) and n is Node:
			(n as Node).queue_free()
	for _i in range(4):
		await tree.process_frame
	CardAnchors.clear()


static func guide_steps() -> Dictionary:
	return read_json(GUIDE_STEPS)
