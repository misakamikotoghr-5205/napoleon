class_name RumorNet
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const Life = preload("res://scripts/sim/npc_life.gd")
const Pressure = preload("res://scripts/sim/pressure_model.gd")

static func plant(pack: Dictionary, s: Dictionary, key: String, origin: String, conf: float = 1.0) -> void:
	if not pack.get("npcs", {}).has(origin):
		return
	_ensure_state(s)
	var root: String = "%s@%d" % [key, int(s.get("day", 0))]
	_enqueue(pack, s, root, key, origin, origin, 0, conf, 0, [], _abs_slot(pack, s))
	deliver(pack, s)

# The returned observations are internal deliveries, not player news. Only
# hear() turns delivered NPC knowledge into entries the player can see.
static func deliver(pack: Dictionary, s: Dictionary) -> Array:
	_ensure_state(s)
	var delivered: Array = []
	var now: int = _abs_slot(pack, s)
	var comm: Dictionary = pack.get("communication", {})
	var npcs: Dictionary = pack.get("npcs", {})
	while not s["queue"].is_empty():
		s["queue"].sort_custom(func(a: Array, b: Array) -> bool:
			return int(a[0]) < int(b[0]) or (int(a[0]) == int(b[0]) and int(a[1]) < int(b[1])))
		if int(s["queue"][0][0]) > now:
			break
		var queued: Array = s["queue"].pop_front()
		var message: Dictionary = queued[2]
		var who: String = str(message["to"])
		if not npcs.has(who):
			continue
		if now - int(message["origin"]) > int(comm.get("ttl_slots", 0)):
			continue
		if int(message["hops"]) > int(comm.get("max_hops", 0)) or float(message["conf"]) < float(comm.get("min_confidence", 0.0)):
			continue
		if not s["known"].has(who):
			s["known"][who] = {}
		if not s["known"][who].has(message["key"]):
			s["known"][who][message["key"]] = {
				"hops": int(message["hops"]), "conf": float(message["conf"]), "via": str(message["via"]),
				"at": now, "root": str(message["root"]), "origin": int(message["origin"])}
		delivered.append(message.duplicate(true))
		if "authority" in npcs[who].get("roles", []) and Life.present(pack, s, who):
			for rule in pack.get("norms", []):
				if str(rule.get("rumor", "")) == str(message["key"]):
					Pressure.add_influence(pack, s, "heat", float(rule.get("heat", 0.0)) * float(message["conf"]), "heard:" + who)
		if int(message["hops"]) >= int(comm.get("max_hops", 0)):
			continue
		var visited: Array = message["visited"].duplicate()
		visited.append(who)
		var links: Dictionary = npcs[who].get("links", {})
		for recipient in _sorted(links.keys()):
			if recipient in visited or not npcs.has(recipient):
				continue
			var hops: int = int(message["hops"]) + 1
			var probability: float = clampf(float(comm.get("relay_probability", 0.0)) * float(links[recipient]), 0.0, 1.0)
			if R.draw(int(s.get("seed", 0)), "relay", [str(message["root"]), who, str(recipient), hops]) >= probability:
				continue
			_enqueue(pack, s, str(message["root"]), str(message["key"]), str(recipient), who, hops,
				float(message["conf"]) * float(comm.get("confidence_decay", 1.0)), int(comm.get("delay_slots", 0)), visited, int(message["origin"]))
	return delivered

static func hear(pack: Dictionary, s: Dictionary, npc: String, world = null) -> Array:
	_ensure_state(s)
	var result: Array = []
	if not Life.present(pack, s, npc, world):
		return result
	var known: Dictionary = s["known"].get(npc, {})
	for key in _sorted(known.keys()):
		if s["player_rumors"].has(key):
			continue
		var knowledge: Dictionary = known[key]
		var row: Dictionary = {"day": int(s.get("day", 0)), "minute": int(s.get("minute", 0)), "key": str(key),
			"text": rumor_text(pack, str(key), int(knowledge["hops"])), "via": npc, "source": "heard",
			"conf": float(knowledge["conf"]), "hops": int(knowledge["hops"])}
		s["player_rumors"][key] = true
		result.append(row)
		if world != null and world is Object and world.has_method("note"):
			world.note("流言", str(row["text"]), "heard", npc, float(row["conf"]))
	return result

static func rumor_text(pack: Dictionary, key: String, hops: int) -> String:
	var texts = pack.get("rumors", {}).get(key, [key])
	if texts is Dictionary:
		texts = texts.get("texts", [key])
	if not texts is Array or texts.is_empty():
		return key
	return str(texts[clampi(hops, 0, texts.size() - 1)])

static func _enqueue(pack: Dictionary, s: Dictionary, root: String, key: String, recipient: String, reporter: String, hops: int, conf: float, delay: int, visited: Array, origin: int) -> void:
	var comm: Dictionary = pack.get("communication", {})
	var due: int = _abs_slot(pack, s) + maxi(0, delay)
	if due - origin > int(comm.get("ttl_slots", 0)) or conf < float(comm.get("min_confidence", 0.0)):
		return
	if hops > int(comm.get("max_hops", 0)):
		return
	var dedup: String = root + "|" + recipient
	# Mark before queueing: the first path wins even while its message waits.
	if s["seen"].has(dedup):
		return
	s["seen"][dedup] = true
	s["seq"] = int(s["seq"]) + 1
	s["queue"].append([due, int(s["seq"]), {"root": root, "key": key, "to": recipient,
		"via": reporter, "hops": hops, "conf": conf, "visited": visited.duplicate(), "origin": origin}])

static func _abs_slot(pack: Dictionary, s: Dictionary) -> int:
	var slots: Array = pack.get("time", {}).get("slots", [])
	var hours: Array = pack.get("time", {}).get("slot_hours", [])
	var count: int = maxi(1, slots.size() if not slots.is_empty() else hours.size())
	return int(s.get("day", 0)) * count + int(s.get("slot", 0))

static func _ensure_state(s: Dictionary) -> void:
	for key in ["known", "seen", "player_rumors"]:
		if not s.has(key):
			s[key] = {}
	if not s.has("queue"):
		s["queue"] = []
	if not s.has("seq"):
		s["seq"] = 0
	s["seq"] = int(s["seq"])
	# Godot parses JSON numbers as floats. Canonicalize the network's integer
	# fields even when a message or old knowledge is untouched this turn.
	for npc in _sorted(s["known"].keys()):
		for key in _sorted(s["known"][npc].keys()):
			var entry: Dictionary = s["known"][npc][key]
			for field in ["hops", "at", "origin"]:
				if entry.has(field):
					entry[field] = int(entry[field])
			if entry.has("conf"):
				entry["conf"] = float(entry["conf"])
	for queued in s["queue"]:
		queued[0] = int(queued[0])
		queued[1] = int(queued[1])
		var message: Dictionary = queued[2]
		message["hops"] = int(message["hops"])
		message["origin"] = int(message["origin"])
		message["conf"] = float(message["conf"])

static func _sorted(values: Array) -> Array:
	var result: Array = values.duplicate()
	result.sort()
	return result
