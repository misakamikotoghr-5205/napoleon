# 回放 guide_d1/d2/d3 夹具上的事件（op: view first cmd ui tick eval ack；ack = 玩家点“知道了”）。不写 class_name。
extends RefCounted


static func play(tree: SceneTree, guide: CardGuide, bus: CardEventBus, eng, ops: Array, on_shown: Callable = Callable()) -> void:
	var seen: Dictionary = {}
	var phase := str(eng.view_d.get("phase", ""))
	for op in ops:
		if typeof(op) != TYPE_DICTIONARY:
			continue
		var kind := str(op.get("op", ""))
		if kind == "view":
			phase = _view(eng, bus, op, phase)
		elif kind == "first":
			var args: Dictionary = {}
			if str(op.get("uid", "")) != "":
				args["uid"] = str(op["uid"])
			bus.first_time.emit(StringName(str(op.get("mech", ""))), args)
		elif kind == "cmd":
			bus.command_done.emit(StringName(str(op.get("cmd", ""))), {}, true)
		elif kind == "ui":
			var uargs: Dictionary = {}
			if str(op.get("kind", "")) != "":
				uargs["kind"] = str(op["kind"])
			if str(op.get("uid", "")) != "":
				uargs["uid"] = str(op["uid"])
			bus.ui_event.emit(StringName(str(op.get("name", ""))), uargs)
		elif kind == "tick":
			guide.tick(float(op.get("s", 0)))
		elif kind == "ack":
			# The player presses "got it" on the bubble (10-22 prototype flow).
			guide.acknowledge()
		elif kind == "eval":
			guide.evaluate_now()
			await tree.process_frame
			var id: String = guide.active_step()
			if id != "" and not seen.has(id):
				seen[id] = true
				if on_shown.is_valid():
					await on_shown.call(id)
	await tree.process_frame


static func _view(eng, bus: CardEventBus, op: Dictionary, prev: String) -> String:
	var phase := str(op.get("phase", prev))
	eng.view_d["phase"] = phase
	eng.view_d["mode"] = str(op.get("mode", "shop"))
	eng.view_d["date"] = {
		"stage": int(op.get("stage", 0)),
		"stage_day": int(op.get("stage_day", 0)),
		"abs_day": int(op.get("abs_day", 0)),
	}
	if op.has("hand"):
		eng.view_d["hand"] = op["hand"]
	elif not eng.view_d.has("hand"):
		eng.view_d["hand"] = []
	if phase != prev:
		bus.phase_changed.emit(StringName(prev), StringName(phase))
	bus.view_changed.emit(PackedStringArray())
	return phase
