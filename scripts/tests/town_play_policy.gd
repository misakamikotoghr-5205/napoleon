# A headless player driven by public offers, inspected parts and authored choices.
# Random decisions use independent GameJev keys so saving never needs RNG state.
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")

var director
var policy: String
var seed: int
var plan: Dictionary
var errors: Array = []
var counts: Dictionary = {}
var sessions_seen: Dictionary = {}
var seen_scripts: Dictionary = {}
var beats: int = 0
var state: Dictionary = {}
var choices: Array = []

func _init(owner, strategy: String, world_seed: int, branch: Dictionary = {}) -> void:
	director = owner
	policy = strategy
	seed = world_seed
	plan = branch.duplicate(true)
	choices = plan.get("choices", []).duplicate()
	director.beat.connect(_on_beat, CONNECT_DEFERRED)

func _on_beat(beat: Dictionary) -> void:
	if beat.get("nowait", false):
		return
	beats += 1
	var kind := str(beat["type"])
	counts[kind] = int(counts.get(kind, 0)) + 1
	seen_scripts[str(director.current_script)] = true
	if beats > 14000:
		errors.append("More than 14000 beats: possible softlock")
		director.stopped = true
	var invariants: Array = director.world.ledger.check_invariants()
	if not invariants.is_empty():
		errors.append("Ledger invariants at %s: %s" % [kind, str(invariants)])
	director.submit(_respond(beat))

func _draw(domain: String, extra: Array = []) -> float:
	return R.draw(seed, "town_test:" + domain,
		[director.world.day, director.current_script, director.beats_emitted] + extra)

func _respond(beat: Dictionary) -> Dictionary:
	match str(beat["type"]):
		"say", "narr", "caption", "summary", "ledger", "ending": return {}
		"tutorial": return {"target": beat["target"]}
		"practice":
			if beat["kind"] == "inspect":
				var practice = beat["session"]
				for iid in practice.item_ids:
					for part in practice.item(iid).get("parts", []):
						practice.inspect(str(iid), str(part["id"]))
			return {"value": 50}
		"choice": return {"id": _choose(beat)}
		"counter": return _counter(beat)
		"ticket": return {"condition": "old" if plan.get("ticket", "") == "old" or policy == "town_greedy" else "true"}
		"stow": return {"to": "pawnbox"}
		"telegraph": return {"words": plan.get("telegram", ["平安"])} if beat.get("reply", false) else {}
		"chess":
			var remaining: Array = beat["remaining"]
			return {"piece": remaining[0]}
		"door_flag": return {"id": "blue"}
		"pick_item":
			var ids: Array = beat.get("iids", [])
			return {"id": ids[0] if not ids.is_empty() else ""}
		"night": return _night(beat)
		_:
			errors.append("Unknown waiting beat: " + str(beat["type"]))
			return {}

func _choose(beat: Dictionary) -> String:
	var options: Array = beat.get("options", [])
	if options.is_empty(): return ""
	var script := str(director.current_script)
	var per_script: Dictionary = plan.get("script_choices", {})
	var key := "choice:" + script
	var index := int(state.get(key, 0))
	if per_script.has(script):
		var ids: Array = per_script[script]
		if index < ids.size():
			for option in options:
				if str(option["id"]) == str(ids[index]):
					state[key] = index + 1
					return str(option["id"])
	if not choices.is_empty():
		for option in options:
			if str(option["id"]) == str(choices[0]): return str(choices.pop_front())
	if policy == "town_random":
		return str(options[mini(options.size() - 1, int(_draw("choice") * options.size()))]["id"])
	return str(options[0]["id"])

func _night(beat: Dictionary) -> Dictionary:
	var key := "night:%d" % int(beat["night"])
	var used: Dictionary = state.get(key, {})
	state[key] = used
	for id in plan.get("night%d" % int(beat["night"]), ["ledger", "telegraph", "flag"]):
		if used.has(id): continue
		for action in beat["actions"]:
			if str(action["id"]) == str(id) and action.get("enabled", false):
				used[id] = true
				return {"id": id}
	return {"id": "sleep"}

func _counter(beat: Dictionary) -> Dictionary:
	var session = beat["session"]
	var sid := str(session.def.get("id", ""))
	sessions_seen[sid] = true
	var overrides: Dictionary = plan.get("sessions", {}).get(sid, {})
	var key := "session:" + sid
	var local: Dictionary = state.get(key, {"offers": 0, "extras": {}, "initialized": false})
	state[key] = local
	if not session.pending_events.is_empty(): return {"action": "event"}
	if plan.get("refuse_generated", false) and sid.begins_with("gen_d"):
		return {"action": "refuse"}
	if plan.get("refuse_day1", false) and director.world.day == 1:
		return {"action": "refuse"}
	if overrides.get("offer", "") == "refuse": return {"action": "refuse"}
	# Part/tool names and the player's own inspected state are objective controls.
	var inspect_all: bool = overrides.get("inspect", "all") != "none"
	if policy == "town_greedy" and not overrides.has("inspect"):
		inspect_all = session.min_inspect > 0
	if inspect_all:
		var looked := false
		for iid in session.item_ids:
			for part in session.item(iid).get("parts", []):
				var pid := str(part["id"])
				if not session.inspected[iid].has(pid) and session.can_use_tool(str(part.get("tool", "magnifier"))):
					session.inspect(str(iid), pid)
					looked = true
					if not session.pending_events.is_empty(): return {"action": "event"}
		if looked: return {"action": "event"}
	if not local["initialized"]:
		local["initialized"] = true
		for iid in session.item_ids:
			var definition_id := str(session.item(iid).get("def_id", ""))
			if session.tells_found(definition_id) > 0 and policy != "town_greedy" and not overrides.get("keep_fake", false):
				session.set_judged(str(iid), "fake")
				if session.split and session.item_ids.size() > 1: session.set_selected(str(iid), false)
		for definition_id in overrides.get("deselect", []):
			var iid: String = session.iid_of(str(definition_id))
			if iid != "": session.set_selected(iid, false)
	var extras: Array = beat.get("extras", [])
	for extra in extras:
		var eid := str(extra["id"])
		var wanted: bool = overrides.get("extras", []).has(eid) if overrides.has("extras") else policy == "town_fair"
		if wanted and not local["extras"].has(eid):
			local["extras"][eid] = true
			return {"action": "extra", "id": eid}
	var deals: Array = beat.get("deals", [])
	for deal in deals:
		if str(deal["id"]) == str(overrides.get("deal", "")): return {"action": "deal", "id": deal["id"]}
	if not session.any_selected() and not session.item_ids.is_empty():
		return {"action": "deal", "id": deals[0]["id"]} if not deals.is_empty() else {"action": "refuse"}
	local["offers"] = int(local["offers"]) + 1
	var offers := int(local["offers"])
	if offers > 8: return {"action": "refuse"}
	var ask: int = maxi(1, int(session.ask))
	var suggestion: int = maxi(1, int(session.suggestion))
	var value := ask
	match str(overrides.get("offer", "")):
		"ask": value = ask
		"suggest": value = suggestion
		_:
			if offers == 1:
				if policy == "town_greedy": value = int(ask * (1.25 if session.mode == "sell" else 0.55))
				elif policy == "town_random": value = int(ask * (0.55 + _draw("offer", [sid, offers]) * 0.7))
				else: value = suggestion if session.mode != "sell" else ask
	if session.item_ids.is_empty(): value = int(ask * 0.9) if offers == 1 else ask
	if session.mode != "sell":
		if director.world.cash() < ask and offers >= 2:
			for deal in deals:
				if str(deal["id"]) in ["refuse", "decline", "refuse_return", "cannot_afford"]: return {"action": "deal", "id": deal["id"]}
			return {"action": "refuse"}
		value = mini(value, director.world.cash())
	return {"action": "offer", "value": maxi(1, value)}
