# Script interpreter seam. Legacy Director handlers remain the default registry entries.
extends RefCounted

var director
var ops: Dictionary = {}
var hooks: Dictionary = {}

func setup(p_director) -> void:
	director = p_director
	for op in director.KNOWN_OPS:
		register_op(str(op), Callable(director, "do_step"))
	register_op("town_action", Callable(director, "_town_step"))
	for hook in ["swap_rice_bag", "give_item", "burn_trash", "ma_fee", "brother_money", "day_close_lines", "share_rumors", "sun_real_deed", "set_door_flag"]:
		register_hook(hook, Callable(director, "_legacy_call_hook"))
	register_hook("town_action", Callable(director, "_town_hook"))

func register_op(id: String, handler: Callable) -> void:
	ops[id] = handler

func register_hook(id: String, handler: Callable) -> void:
	hooks[id] = handler

func execute(steps: Array) -> void:
	for step in steps:
		if director.stopped or director._halt:
			return
		if typeof(step) != TYPE_DICTIONARY or not step.has("op"):
			push_error("剧情步骤格式错误（%s）：%s" % [director.current_script, str(step)])
			continue
		if step.has("when") and not director.ctx.test(str(step["when"])):
			continue
		var op := str(step["op"])
		if not ops.has(op):
			push_error("未知剧情操作 op=%s（%s）" % [op, director.current_script])
			continue
		await ops[op].call(step)

func call_hook(id: String, args: Dictionary) -> void:
	if not hooks.has(id):
		push_error("未实现的钩子：" + id)
		return
	# Legacy hooks take their own name; extension hooks only take their arguments.
	if id == "town_action":
		await hooks[id].call(args)
	else:
		await hooks[id].call(id, args)
