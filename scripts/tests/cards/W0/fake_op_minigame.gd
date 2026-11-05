# W0 self-test helper: the smallest minigame that follows the 10-25 op convention (apply_op / ops_log).
# Only used by test_mg_ops.gd to prove scripts/tests/cards/lib/mg_ops.gd works.
extends CardMiniGame

var _params: Dictionary = {}
var _log: Array = []
var _call: int = 0
var _steps: int = 0
var _done: bool = false


func kind() -> StringName:
	return &"weigh"


func start(params: Dictionary) -> void:
	_params = params.duplicate(true)
	_log = []
	_call = 0
	_steps = 0
	_done = false
	_minutes_spent = 0


func apply_op(op: Array) -> bool:
	if _done or op.is_empty():
		return false
	match str(op[0]):
		"poise":
			if op.size() != 2 or typeof(op[1]) != TYPE_INT:
				return false
			_steps += 1
		"commit":
			_minutes_spent += 2
		"call":
			if op.size() != 2 or int(op[1]) < 1 or int(op[1]) > 5:
				return false
			_call = int(op[1])
		"done":
			_done = true
			_log.append(op.duplicate(true))
			finished.emit({"quality_permille": 1000 if _steps > 0 else 250, "observations": [],
				"minutes": _minutes_spent, "measures": {"read_fen": 300, "steps": _steps, "commits": 1, "call": _call}, "aborted": false})
			return true
		_:
			return false
	_log.append(op.duplicate(true))
	return true


func ops_log() -> Array:
	return _log.duplicate(true)


func autoplay(skill: float) -> void:
	var right := JevRng.draw(int(_params.get("seed", 0)), "c.mg.weigh.layout", [9000]) < skill
	for step in range(3):
		apply_op(["poise", step])
	apply_op(["commit"])
	apply_op(["call", 3 if right else 1])
	apply_op(["done"])
