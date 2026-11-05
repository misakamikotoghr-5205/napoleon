class_name Institutions
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const C = preload("res://scripts/sim/town_cond.gd")
const P = preload("res://scripts/sim/pressure_model.gd")
const Costs = preload("res://scripts/sim/living_costs.gd")
const Life = preload("res://scripts/sim/npc_life.gd")

static func act(pack: Dictionary, s: Dictionary, inst: String, action: String, world = null) -> Dictionary:
	var institutions: Dictionary = pack.get("institutions", {})
	if not institutions.has(inst) or not institutions[inst].get("acts", {}).has(action):
		return {"ok": false, "reason": "unknown_institution_action", "effects": []}
	var institution: Dictionary = institutions[inst]
	var building: String = str(institution.get("building", inst))
	if not bool(s.get("unlocked", {}).get(building, false)):
		return {"ok": false, "reason": "institution_locked", "effects": []}
	var spec: Dictionary = institution["acts"][action]
	if not C.test(spec.get("when", {}), pack, s, world):
		return {"ok": false, "reason": "conditions_unmet", "effects": []}
	var event_id: String = "%s:%s:d%d:s%d" % [inst, action, int(s.get("day", 0)), int(s.get("slot", 0))]
	if not s.has("institution_results"):
		s["institution_results"] = {}
	if s["institution_results"].has(event_id):
		return _replayed(s["institution_results"][event_id])
	var result: Dictionary = {"ok": true, "id": event_id, "institution": inst, "act": action,
		"day": int(s.get("day", 0)), "effects": spec.get("effects", []).duplicate(true)}
	if spec.has("fine_min") or spec.has("fine_max"):
		var low: int = maxi(0, int(spec.get("fine_min", 0)))
		var high: int = maxi(low, int(spec.get("fine_max", low)))
		var fine: Dictionary = {"id": "institution_fine", "label": str(spec.get("fine_label", "罚款")),
			"min": low, "max": high, "payee": str(spec.get("payee", institution.get("payee", building))),
			"building": building, "due_days": int(spec.get("due_days", 0)),
			"grace_days": int(spec.get("grace_days", pack.get("balance", {}).get("costs", {}).get("default_grace_days", 0)))}
		var bill: Dictionary = Costs.add(pack, s, fine, inst + "/" + action, "bill:institution:" + event_id, world)
		if not bill.is_empty():
			result["bill"] = bill.duplicate(true)
			result["fine"] = int(bill["amount"])
			result["paid"] = 0
	if str(spec.get("confiscate", "")) == "stolen":
		# A raid cannot consult hidden item origins. Only identified evidence can
		# be seized; live-pawn contracts remain attached to their original items.
		result["seized"] = _confiscate(s, inst, building, world)
	if not str(spec.get("news", "")).is_empty():
		result["text"] = str(spec["news"])
		_news(s, str(spec["news"]), str(pack.get("buildings", {}).get(building, {}).get("name", building)))
	s["institution_results"][event_id] = result.duplicate(true)
	_report(s, "institution", result.duplicate(true))
	return result

static func norm(pack: Dictionary, s: Dictionary, action: String, args: Dictionary, world = null) -> Dictionary:
	var actor: String = str(args.get("actor", "player"))
	var building: String = str(args.get("building", "pawnshop"))
	var target: String = str(args.get("item_id", args.get("visit_id", args.get("case_id", args.get("target", "")))))
	# request_id is deliberately absent: changing an API retry token must never
	# create another detection roll for the same physical transaction.
	var semantic: String = str(args.get("event_id", "%s:%s:%s:%s:d%d:s%d" % [action, actor, building, target, int(s.get("day", 0)), int(s.get("slot", 0))]))
	if not s.has("norm_results"):
		s["norm_results"] = {}
	if s["norm_results"].has(semantic):
		return _replayed(s["norm_results"][semantic])
	var result: Dictionary = {"ok": true, "id": semantic, "act": action, "detected": [], "effects": []}
	var npcs: Dictionary = pack.get("npcs", {})
	var authorities: Array = []
	var bystanders: Array = []
	var ids: Array = npcs.keys()
	ids.sort()
	for npc in ids:
		if str(npc) == actor:
			continue
		if not _present(pack, s, str(npc), world) or not _at_building(pack, s, str(npc), building):
			continue
		bystanders.append(npc)
		if "authority" in npcs[npc].get("roles", []):
			authorities.append(npc)
	var balance: Dictionary = pack.get("balance", {}).get("institutions", {})
	for rule in pack.get("norms", []):
		if str(rule.get("act", "")) != action or str(rule.get("building", building)) != building:
			continue
		if not C.test(rule.get("when", {}), pack, s, world):
			continue
		if rule.has("required_role") and str(rule["required_role"]) in npcs.get(actor, {}).get("roles", []):
			continue
		var chance: float = 0.0
		for authority in authorities:
			var rapport: float = _rapport(s, str(authority), actor, world)
			var strength: float = float(s.get("norm_strength", {}).get(building, 1.0)) if s.get("norm_strength", {}) is Dictionary else float(s.get("norm_strength", 1.0))
			var forgiveness: float = float(rule.get("forgiveness", 0.0)) * float(balance.get("forgiveness_relation_scale", 1.0))
			chance = maxf(chance, clampf(float(rule.get("detect_probability", 0.0)) * strength * (1.0 - forgiveness * rapport), 0.0, 1.0))
		# Opening an institution enables its formal powers. Townspeople can
		# already discuss what they saw before those powers become available.
		var authority_open: bool = not rule.has("authority_building") or bool(s.get("unlocked", {}).get(rule["authority_building"], false))
		if authority_open and not authorities.is_empty() and R.draw(int(s.get("seed", 0)), "norm_detection", [semantic, str(rule["id"])]) < chance:
			result["detected"].append(str(rule["id"]))
			var pressure: String = str(rule.get("pressure", "heat"))
			if pack.get("pressures", {}).has(pressure):
				P.add_influence(pack, s, pressure, float(rule.get("heat", 0.0)), "witnessed:" + semantic)
			if action == "accept_stolen":
				_evidence(s, "police", target, actor, semantic)
			for effect in rule.get("effects", []):
				result["effects"].append(effect.duplicate(true))
		var rumor: String = str(rule.get("rumor", ""))
		# The actor cannot invent a third-party eyewitness, and a known NPC
		# elsewhere in town is not evidence of this transaction either.
		var origin: String = str(bystanders[0]) if not bystanders.is_empty() else ""
		if not rumor.is_empty() and not origin.is_empty():
			result["effects"].append({"op": "rumor", "key": rumor, "origin": origin, "conf": float(balance.get("default_norm_confidence", 1.0)), "root": semantic + ":" + str(rule["id"])})
	s["norm_results"][semantic] = result.duplicate(true)
	return result

static func _present(pack: Dictionary, s: Dictionary, npc: String, world) -> bool:
	if not Life.present(pack, s, npc, world):
		return false
	if world != null and world is Object:
		var live = world.get("npcs")
		if live is Dictionary and live.has(npc) and not bool(live[npc].get("present", true)):
			return false
	return true

static func _at_building(pack: Dictionary, s: Dictionary, npc: String, building: String) -> bool:
	# An arrived customer and their companions are at the counter during the
	# actual wait, even if their ordinary schedule says they would be at home.
	var minute: int = int(s.get("minute", -1))
	for visit in s.get("visits", []):
		if not visit is Dictionary or str(visit.get("status", "")) != "waiting":
			continue
		var arrives: int = int(visit.get("minute", 0))
		if minute < arrives or minute >= arrives + int(visit.get("patience_min", 0)):
			continue
		if str(visit.get("who", "")) == npc or npc in visit.get("companions", []):
			return building == "pawnshop" or building == str(pack.get("buildings", {}).get("pawnshop", {}).get("name", "pawnshop"))
	var place: String = str(s.get("npc_locations", {}).get(npc, ""))
	if place.is_empty():
		place = Life.location(pack, s, npc)
	return place == building or place == str(pack.get("buildings", {}).get(building, {}).get("name", building))

static func _rapport(s: Dictionary, npc: String, actor: String, world) -> float:
	var rel: Dictionary = s.get("npc_rel", {}).get(npc, {})
	if rel.has(actor):
		rel = rel[actor]
	if world != null and world is Object:
		var live = world.get("npcs")
		if live is Dictionary:
			rel = live.get(npc, {}).get("rel", {}).get(actor, rel)
	return clampf(float(rel.get("trust", 0.0)), 0.0, 1.0)

static func _evidence(s: Dictionary, inst: String, item: String, actor: String, event_id: String) -> void:
	if not s.has("institution_evidence"):
		s["institution_evidence"] = {}
	if not s["institution_evidence"].has(inst):
		s["institution_evidence"][inst] = {"items": {}, "events": {}}
	var record: Dictionary = s["institution_evidence"][inst]
	record["events"][event_id] = {"actor": actor, "day": int(s.get("day", 0)), "source": "witnessed"}
	if not item.is_empty():
		record["items"][item] = {"source": "witnessed", "event": event_id}

static func _confiscate(s: Dictionary, inst: String, building: String, world) -> int:
	var evidence: Dictionary = s.get("institution_evidence", {}).get(inst, {})
	var items: Dictionary = evidence.get("items", {})
	var seized: int = 0
	var ids: Array = items.keys()
	ids.sort()
	for id in ids:
		if bool(items[id].get("seized", false)):
			continue
		if world != null and world is Object:
			var ledger = world.get("ledger")
			if ledger == null or not ledger.items.has(id):
				continue
			var item: Dictionary = ledger.items[id]
			if not str(item.get("location", "")) in ["stock", "pawnbox", "player", "pawnshop"]:
				continue
			ledger.move_item(str(id), building, "", "警察所依见证扣存，原合同仍保留")
		items[id]["seized"] = true
		seized += 1
	if seized > 0:
		s["stolen_stock"] = maxi(0, int(s.get("stolen_stock", 0)) - seized)
	return seized

static func _replayed(saved: Dictionary) -> Dictionary:
	var result: Dictionary = saved.duplicate(true)
	result["replayed"] = true
	result["effects"] = []
	return result

static func _news(s: Dictionary, text: String, via: String) -> void:
	_report(s, "news", {"day": int(s.get("day", 0)), "minute": int(s.get("minute", 0)), "text": text,
		"via": via, "source": "seen", "conf": 1.0})

static func _report(s: Dictionary, kind: String, entry) -> void:
	if not s.has("day_report"):
		s["day_report"] = {}
	if not s["day_report"].has(kind):
		s["day_report"][kind] = []
	s["day_report"][kind].append(entry)
