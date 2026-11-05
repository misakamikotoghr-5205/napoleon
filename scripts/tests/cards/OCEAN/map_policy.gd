## Public-API map smoke policy. It never reads ctx, model, hidden slots, or battle truth.
## Movement follows visible links; battles use the always-available retreat path.
## This is a reachability driver, not a winning combat strategy.
extends RefCounted

var branch := "ocean"
var choices := {"mt_arrive": "mt_take_letter", "mt_march": "mt_swear"}
var last_error := ""
var commands: Array = []


func step(engine: CardEngineApi) -> Dictionary:
	var action := decide(engine)
	if action.is_empty():
		if last_error == "" and str(engine.view().get("phase", "")) != "game_over":
			last_error = "no_action:" + str(engine.query(&"campaign").get("scene_id", ""))
		return {"ok": str(engine.view().get("phase", "")) == "game_over", "err": "no_action"}
	var result := engine.send(StringName(action[0]), action[1])
	commands.append(action.duplicate(true))
	if not bool(result.get("ok", false)):
		last_error = "%s %s -> %s" % [action[0], action[1], result.get("err", "")]
	return result


func finish(engine: CardEngineApi, max_steps: int = 1000) -> bool:
	for _i in max_steps:
		if str(engine.view().get("phase", "")) == "game_over":
			return true
		if not bool(step(engine).get("ok", false)):
			return false
	last_error = "step_limit"
	return false


func decide(engine: CardEngineApi) -> Array:
	var view := engine.view()
	var phase := str(view.get("phase", ""))
	if phase == "game_over":
		return []
	if phase != "day":
		return ["campaign.wait", {}]
	var campaign := engine.query(&"campaign")
	var map := engine.query(&"campaign.map")
	if not bool(map.get("enabled", false)):
		return []
	var battle: Dictionary = campaign.get("battle2", {})
	if bool(campaign.get("big_fate", {}).get("pending", false)):
		return ["campaign.big_fate", {"choice": "desperate_breakout"}]
	if str(battle.get("phase", "")) == "active":
		return ["campaign.battle_finish", {}] if bool(battle.get("over", false)) else [
			"campaign.battle_cmd", {"cmd": "retreat", "args": {}}]
	if str(battle.get("phase", "")) == "lineup":
		return ["campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false}]
	var event := str(map.get("event", ""))
	if event == "":
		event = str(map.get("interlude", ""))
	if event != "":
		return card_action(engine, "event:" + event)
	var pending := str(map.get("pending_kind", ""))
	if pending in ["toll", "rival"]:
		var gold := int(campaign.get("coins", {}).get("gold", 0))
		return ["campaign.map_pay", {"how": "gold" if gold >= 2 else "fight"}]
	if str(map.get("pending", "")) != "":
		return ["campaign.map_enter", {}]
	var scene_id := str(campaign.get("scene_id", ""))
	var anchor: Dictionary = {}
	for node in map.get("nodes", []):
		if str(node.get("scene", "")) == scene_id:
			anchor = node
			break
	if anchor.is_empty():
		last_error = "unseen_anchor:" + scene_id
		return []
	var pos := str(map.get("pos", ""))
	if str(anchor["id"]) == pos:
		if bool(battle.get("has_battle", false)) and not bool(battle.get("resolved", false)):
			return ["campaign.battle_prepare", {}]
		var preferred := str(choices.get(scene_id, ""))
		for offer in engine.query(&"campaign.run").get("branch_offers", []):
			if str(offer.get("segment", "")) == branch and bool(offer.get("ok", false)):
				preferred = str(offer["choice"])
		return card_action(engine, "story:" + scene_id, preferred)
	var target := str(anchor["id"])
	if str(anchor.get("reason", "")) == "muster":
		var role := "post" if int(map.get("stamps", 0)) < int(map.get("stamps_need", 0)) else "muster"
		target = role_node(map, role)
		if role == "muster" and target == pos:
			return ["campaign.map_muster", {}]
	var route := path_to(map, target)
	if route.is_empty():
		last_error = "no_path:" + target
		return []
	var next := str(route[0])
	var node := node_of(map, next)
	var link := link_between(map, pos, next)
	if int(link.get("voyage_days", 0)) > 0:
		return ["campaign.map_move", {"to": next}] if bool(node.get("reachable", false)) else ["campaign.wait", {}]
	if int(map.get("mp", 0)) >= int(link.get("legs", 1)):
		return ["campaign.map_move", {"to": next}]
	if bool(map.get("can_roll", false)):
		var best := -1
		var points := 0
		for card in map.get("hand", []):
			if int(card.get("mp", 0)) > points:
				points = int(card["mp"])
				best = int(card["index"])
		return ["campaign.map_card", {"index": best}] if best >= 0 else ["campaign.map_roll", {}]
	return ["campaign.wait", {}]


static func card_action(engine: CardEngineApi, uid: String, preferred: String = "") -> Array:
	var options: Array = engine.query(&"card", {"uid": uid}).get("choices", [])
	var fallback := ""
	for option in options:
		if not bool(option.get("enabled", false)):
			continue
		var id := str(option.get("id", ""))
		if id.begins_with("action:appraise:") or id.begins_with("action:map_appraise:"):
			return ["card.choose", {"uid": uid, "choice": id}]
		if preferred != "" and (id == preferred or id.ends_with(":" + preferred)):
			return ["card.choose", {"uid": uid, "choice": id}]
		if fallback == "":
			fallback = id
	return ["card.choose", {"uid": uid, "choice": fallback}] if fallback != "" else []


static func node_of(map: Dictionary, id: String) -> Dictionary:
	for node in map.get("nodes", []):
		if str(node.get("id", "")) == id:
			return node
	return {}


static func role_node(map: Dictionary, role: String) -> String:
	for node in map.get("nodes", []):
		if str(node.get("role", "")) == role:
			return str(node["id"])
	return ""


static func link_between(map: Dictionary, a: String, b: String) -> Dictionary:
	for link in map.get("links", []):
		if str(link["a"]) == a and str(link["b"]) == b:
			return link
		if not bool(link.get("oneway", false)) and str(link["b"]) == a and str(link["a"]) == b:
			return link
	return {}


## Dijkstra over the same public graph drawn by MapCanvas. No unrevealed data is consulted.
static func path_to(map: Dictionary, target: String) -> Array:
	var start := str(map.get("pos", ""))
	var costs := {start: 0}
	var previous := {}
	var frontier: Array = [start]
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return int(costs[a]) < int(costs[b]))
		var current: String = frontier.pop_front()
		if current == target:
			break
		for link in map.get("links", []):
			if str(link.get("state", "open")) != "open":
				continue
			var next := ""
			if str(link["a"]) == current:
				next = str(link["b"])
			elif str(link["b"]) == current and not bool(link.get("oneway", false)):
				next = str(link["a"])
			var node := node_of(map, next)
			if next == "" or node.is_empty() or str(node.get("reason", "")) not in ["", "scene_order"]:
				continue
			var weight := int(link.get("legs", 1)) + 3 * int(link.get("voyage_days", 0))
			var cost := int(costs[current]) + weight
			if not costs.has(next) or cost < int(costs[next]):
				costs[next] = cost
				previous[next] = current
				if not next in frontier:
					frontier.append(next)
	if not costs.has(target):
		return []
	var path: Array = [target]
	while str(path[0]) != start:
		path.push_front(previous[path[0]])
	path.pop_front()
	return path
