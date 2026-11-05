# Assertions for contract 1.2's public next-day escape hatch.
# State reads below are test diagnostics only, never policy decisions or simulation input.
extends RefCounted


static func preview(t: RefCounted, engine: CardEngine) -> Dictionary:
	var before: String = engine.state_hash()
	var result: Dictionary = engine.query(&"day.end_preview")
	t.eq(engine.state_hash(), before, "preview is read only")
	t.no_leaks(result, "end preview")
	t.ok(result.has("step") and result.has("needs_confirm") and result.has("items"), "preview schema")
	var needs: bool = false
	for item in result.get("items", []):
		t.ok(typeof(item) == TYPE_DICTIONARY, "end row is a dictionary")
		for key in ["uid", "def", "kind", "consequence_key", "args"]:
			t.ok(item.has(key), "end row field " + key)
		t.ok(StringName(str(item.get("kind", ""))) in CardIds.END_KINDS, "registered end kind")
		needs = needs or not StringName(str(item.get("kind", ""))) in CardIds.END_NO_CONFIRM_KINDS
	t.eq(bool(result.get("needs_confirm", false)), needs, "confirmation matches rows")
	return result


static var _recovery_clone: CardEngine = null


static func end_step(t: RefCounted, engine: CardEngine, confirm: bool, expected: Dictionary = {}, before: Dictionary = {}) -> Dictionary:
	if expected.is_empty():
		expected = preview(t, engine)
	if before.is_empty():
		before = engine.view()
	var unconfirmed_pending: bool = str(before.get("phase", "")) != "game_over" and not confirm and bool(expected.get("needs_confirm", false))
	var state_before: Dictionary = engine.ctx.state.to_dict() if unconfirmed_pending else {}
	var result: Dictionary = engine.send(&"day.end", {"confirm": confirm})
	if str(before.get("phase", "")) == "game_over":
		t.eq(result.get("err", ""), "bad_phase", "terminal day end rejected")
		return result
	if confirm or not bool(expected.get("needs_confirm", false)):
		t.ok(bool(result.get("ok", false)), "day.end always succeeds after confirmation: " + str(result))
		var after_loop: Dictionary = engine.ctx.state.ns("loop")
		t.ok(str(after_loop.get("phase", "")) != str(before.get("phase", ""))
			or engine.ctx.abs_day() > int(before.get("date", {}).get("abs_day", 0)),
			"confirmed end advances phase or date")
	else:
		t.eq(result.get("err", ""), "must_resolve_pending", "unconfirmed end only asks confirmation")
		t.eq(_without_firsts(engine.ctx.state.to_dict()), _without_firsts(state_before), "confirmation request only marks firsts")
	t.eq(result.get("step", ""), expected.get("step", ""), "preview and execution step agree")
	t.eq(result.get("items", []), expected.get("items", []), "preview rows exactly equal execution rows")
	t.no_leaks(result, "day.end result")
	return result


static func escape(t: RefCounted, engine: CardEngine, first_preview: Dictionary = {}, first_view: Dictionary = {}) -> int:
	var v: Dictionary = engine.view() if first_view.is_empty() else first_view
	var day: int = int(v.get("date", {}).get("abs_day", 0))
	var used: int = 0
	var next_prev: Dictionary = first_preview
	for _index in range(CardIds.END_MAX_STEPS_TO_NEXT_DAY):
		if str(v.get("phase", "")) == "game_over":
			break
		if int(v.get("date", {}).get("abs_day", 0)) > day:
			break
		end_step(t, engine, true, next_prev, v)
		used += 1
		next_prev = {}
		v = engine.view()
	t.ok(str(v.get("phase", "")) == "game_over"
		or int(v.get("date", {}).get("abs_day", 0)) > day, "escape advances within eight commands")
	return used


static func replay(t: RefCounted, engine: CardEngine, opts: Dictionary) -> void:
	var log: Array = CardReplay.record(engine)
	var expected: Dictionary = engine.ctx.state.to_dict()
	# Save/load commands are excluded by the frozen log contract. Only the permitted
	# system resume first marker differs; retry stays because its command is recorded.
	(expected.get("core", {}).get("firsts", {}) as Dictionary).erase("resume")
	var replay_opts: Dictionary = opts.duplicate(true)
	replay_opts["save_dir"] = str(opts.get("save_dir", "")) + "/replay"
	var replay_hash: String = CardReplay.replay(replay_opts, log)
	CardSave.set_root(str(opts.get("save_dir", "")))
	t.eq(replay_hash, CardState.from_dict(expected).hash(), "sampled public replay hash, resume normalized")


static func terminal_recovery(t: RefCounted, engine: CardEngine, opts: Dictionary) -> void:
	var save_root: String = str(opts.get("save_dir", ""))
	CardSave.set_root(save_root)
	var has_suspend: bool = CardSave.exists(CardSave.suspend_path())
	var terminal_path: String = save_root + "/terminal_diagnostic.json"
	# This test-only clone preserves the actually reached terminal state so both
	# recovery commands can independently start at game_over without replaying a run.
	t.ok(bool(CardSave.write(terminal_path, engine.ctx.state, {}).get("ok", false)), "copy reached terminal for diagnostics")
	var retry: Dictionary = engine.send(&"game.retry_stage", {})
	t.ok(bool(retry.get("ok", false)), "terminal retry always succeeds")
	t.eq(engine.view().get("phase", ""), "month_open", "retry returns to month open")
	if has_suspend:
		var recovery_opts: Dictionary = opts.duplicate(true)
		recovery_opts["save_dir"] = save_root + "/recovery"
		if _recovery_clone == null:
			_recovery_clone = CardEngine.new()
		var clone: CardEngine = _recovery_clone
		t.ok(bool(clone.new_game(recovery_opts).get("ok", false)), "recovery facade starts")
		t.ok(bool(clone.load_game(terminal_path).get("ok", false)), "load reached terminal copy")
		t.eq(clone.view().get("phase", ""), "game_over", "load recovery begins at terminal")
		CardSave.set_root(save_root)
		t.ok(bool(clone.send(&"game.load", {}).get("ok", false)), "terminal default load always succeeds when suspend exists")
		t.ok(str(clone.view().get("phase", "")) in ["morning", "month_open"], "terminal load restores continuation")
	CardSave.set_root(save_root)


static func _without_firsts(state: Dictionary) -> Dictionary:
	var copy: Dictionary = state.duplicate(true)
	(copy.get("core", {}) as Dictionary).erase("firsts")
	return copy


static func continuation_state(engine: CardEngine) -> Dictionary:
	var state: Dictionary = engine.ctx.state.to_dict()
	# UI is deliberately unioned during load and excluded from the mechanics hash.
	state.erase("ui")
	(state.get("core", {}).get("firsts", {}) as Dictionary).erase("resume")
	return state


static func differences(a: Variant, b: Variant, path: String = "") -> Array:
	var out: Array = []
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var keys: Array = a.keys()
		for key in b.keys():
			if not keys.has(key):
				keys.append(key)
		keys.sort()
		for key in keys:
			out.append_array(differences(a.get(key), b.get(key), path + "." + str(key)))
	elif typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY and a.size() == b.size():
		for index in range(a.size()):
			out.append_array(differences(a[index], b[index], path + "[%d]" % index))
	elif JSON.stringify(a, "", true) != JSON.stringify(b, "", true):
		out.append({"path": path, "before": a, "after": b})
	return out
