## Deterministic formal-book acceptance driver. Decisions use public queries only.
## It remembers its own movements/actions; it never reads the model, ctx, flags or hidden map slots.
extends RefCounted

const Graph = preload("res://scripts/tests/cards/OCEAN/map_policy.gd")
const Combat = preload("res://scripts/tests/cards/OCEAN/napoleon_battle_policy.gd")

const STORY := {
	"toulon_arrival": "expose_thieves", "toulon_mulgrave": "credit_captain",
	"italy_nice": "pay_marie", "italy_milan": "pay_soldiers_first", "italy_rivoli": "wounded_first",
	"italy_campo_formio": "register_painting", "orient_orders": "sail_east", "orient_acre": "sort_the_sick",
	"boulogne_orders": "march_danube", "austerlitz_sun": "double_ration", "bayonne_orders": "into_spain",
	"saragossa_siege": "feed_civilians", "russia_niemen": "keep_half_in_vilna", "russia_borodino": "field_hospitals",
	"russia_berezina": "take_pierre", "collapse_lutzen": "drill_them", "collapse_leipzig": "save_the_treasury",
	"collapse_fontainebleau": "go_home_marseille", "elba_arrival": "cut_court_costs", "elba_night": "hold_the_prisoners",
	"k_golfe_juan": "pay_cannes", "k_laffrey": "pay_all_ranks", "k_tuileries": "royal_silver",
	"k_charleroi": "double_couriers", "k_waterloo": "hold_plancenoit", "k_waterloo_night": "exchange_wounded",
	"c_landfall": "deliver_first", "c_reserve": "take_the_paper", "c_gerard": "trade_your_letter",
	"c_petition": "rewrite_plain", "c_white_june": "stay_in_marseille", "c_if_contract": "honest_bid",
	"c_bread_34": "tell_hope", "c_faria_27": "bring_medicine", "c_morgiou": "buy_the_boat",
	"c_faria_dies": "medicine_last", "c_if_night": "your_boat",
	"prologue": "secure_passage", "scene01": "seal_evidence", "scene02": "expose_sabre",
	"scene03": "audit_accounts", "scene04": "prepare_escape", "scene05": "redeem_emperor",
	"scene06": "establish_rations", "scene07": "expose_viper", "scene08": "prepare_operation",
	"scene09": "capture_viper", "scene10": "audit_alliance", "scene11": "expose_vigo",
	"scene12": "fund_revolution", "finale": "close_ledger",
}

var branch := "ocean"
var preferred: Dictionary = STORY.duplicate(true)
var last_error := ""
var commands: Array = []
var scenes: Array = []
var chapters: Array = []
var battles: Array = []
var scout_count := 0
var max_heat := 0
var train_for_campaign := true
var _stamped: Dictionary = {}
var _entered: Dictionary = {}
var _actions: Dictionary = {}
var _battle_commands := 0


func step(engine: CardEngineApi) -> Dictionary:
	var before := engine.query(&"campaign")
	var map := engine.query(&"campaign.map")
	var key := str(before.get("segment", "")) + ":" + str(before.get("chapter_id", ""))
	var scene := str(before.get("scene_id", ""))
	if not scene in scenes:
		scenes.append(scene)
		print("NAPOLEON SCENE %s %s vitality=%d heat=%d days=%d" % [branch, scene, metric(before, "vitality"), metric(before, "heat"), int(map.get("days", 0))])
	if not key in chapters:
		chapters.append(key)
	max_heat = maxi(max_heat, metric(before, "heat"))
	var action := decide(engine)
	if action.is_empty():
		if last_error == "" and str(engine.view().get("phase", "")) != "game_over":
			last_error = "no_action:" + scene + ":" + str(map.get("pos", ""))
		return {"ok": str(engine.view().get("phase", "")) == "game_over", "err": last_error}
	var result := engine.send(StringName(action[0]), action[1])
	commands.append(action.duplicate(true))
	if not bool(result.get("ok", false)):
		last_error = "%s %s -> %s at %s/%s" % [action[0], action[1], result, scene, map.get("pos", "")]
		return result
	if action[0] == "campaign.map_move":
		var after_map := engine.query(&"campaign.map")
		var id := str(action[1]["to"])
		_entered[key + ":" + id] = true
		if int(after_map.get("stamps", 0)) > int(map.get("stamps", 0)):
			_stamped[key + ":" + id] = true
	elif action[0] == "campaign.map_scout":
		scout_count += 1
	elif action[0] == "campaign.battle_begin":
		_battle_commands = 0
	elif action[0] == "campaign.battle_cmd":
		_battle_commands += 1
	elif action[0] == "campaign.battle_finish":
		var b: Dictionary = before.get("battle2", {})
		battles.append({"scene": scene, "template": b.get("template", ""), "outcome": b.get("result", {}).get("outcome", ""), "commands": _battle_commands})
		print("NAPOLEON BATTLE %s %s %s commands=%d" % [branch, b.get("template", ""), b.get("result", {}).get("outcome", ""), _battle_commands])
	return result


func finish(engine: CardEngineApi, limit: int = 6000, stop_scene: String = "") -> bool:
	for _i in limit:
		if str(engine.view().get("phase", "")) == "game_over":
			return true
		if stop_scene != "" and str(engine.query(&"campaign").get("scene_id", "")) == stop_scene and str(engine.view().get("phase", "")) == "day":
			var map := engine.query(&"campaign.map")
			var here := Graph.node_of(map, str(map.get("pos", "")))
			if str(here.get("scene", "")) == stop_scene and str(map.get("pending", "")) == "":
				if not stop_scene in scenes:
					scenes.append(stop_scene)
				return true
		if not bool(step(engine).get("ok", false)):
			return false
	last_error = "step_limit"
	return false


func decide(engine: CardEngineApi) -> Array:
	var view := engine.view()
	if str(view.get("phase", "")) == "game_over":
		return []
	var c := engine.query(&"campaign")
	var m := engine.query(&"campaign.map")
	var b: Dictionary = c.get("battle2", {})
	if bool(c.get("big_fate", {}).get("pending", false)):
		return Graph.card_action(engine, "big_fate", "action:big_fate:ransom_supply")
	if str(b.get("phase", "")) == "active":
		if bool(b.get("over", false)):
			return ["campaign.battle_finish", {}]
		var action := Combat.next_action(b.get("view", {}), engine.query(&"campaign.battle_preview"))
		return ["campaign.battle_cmd", {"cmd": action[0], "args": action[1]}] if not action.is_empty() else ["campaign.battle_cmd", {"cmd": "fight", "args": {}}]
	if str(b.get("phase", "")) == "lineup":
		return ["campaign.battle_begin", Combat.lineup(b.get("lineup", {}))]
	var event := str(m.get("event", ""))
	if event == "":
		event = str(m.get("interlude", ""))
	if event != "":
		return Graph.card_action(engine, "event:" + event)
	if str(view.get("phase", "")) != "day":
		return ["campaign.wait", {}]
	var pending := str(m.get("pending_kind", ""))
	if pending in ["toll", "rival"]:
		var pay: Dictionary = m.get("pay", {})
		for how in ["gold", "prop", "fight"]:
			if bool(pay.get("can_" + how, false)):
				return ["campaign.map_pay", {"how": how}]
		if bool(pay.get("can_wait", false)):
			return ["campaign.wait", {}]
		last_error = "no_legal_payment:%s:%s" % [pending, pay]
		return []
	if str(m.get("pending", "")) != "":
		return ["campaign.map_enter", {}]
	if str(c.get("sign", "white")) != "white":
		return ["campaign.sign", {"sign": "white"}]
	var pos := str(m.get("pos", ""))
	var current := Graph.node_of(m, pos)
	var services := _services(engine, c, m, current)
	if not services.is_empty():
		return services
	var scene := str(c.get("scene_id", ""))
	var anchor := {}
	for n in m.get("nodes", []):
		if str(n.get("scene", "")) == scene:
			anchor = n
			break
	if not anchor.is_empty() and str(anchor["id"]) == pos:
		if bool(b.get("has_battle", false)) and not bool(b.get("resolved", false)):
			return ["campaign.battle_prepare", {}]
		var pick := str(preferred.get(scene, ""))
		for offer in engine.query(&"campaign.run").get("branch_offers", []):
			if str(offer.get("segment", "")) == branch:
				if not bool(offer.get("ok", false)):
					last_error = "branch_locked:%s:%s" % [branch, offer]
					return []
				pick = str(offer["choice"])
		return Graph.card_action(engine, "story:" + scene, pick)
	var target := str(anchor.get("id", ""))
	if not anchor.is_empty() and str(anchor.get("reason", "")) == "muster":
		if int(m.get("stamps", 0)) < int(m.get("stamps_need", 0)):
			target = _nearest(m, c, "post", true)
		else:
			target = _nearest(m, c, "muster")
			if target == pos:
				return ["campaign.map_muster", {}]
	if target == "" or (target != pos and Graph.path_to(m, target).is_empty()):
		# Fogged nodes visible to the player can be scouted; fully hidden nodes must be discovered by walking.
		var fog := _nearest(m, c, "?", false, true)
		if fog != "" and int(c.get("coins", {}).get("intel", 0)) > 0:
			return ["campaign.map_scout", {"node": fog}]
		target = _nearest(m, c, "", true)
	if target == "":
		last_error = "unreachable_scene:%s pos=%s nodes=%s" % [scene, pos, m.get("nodes", [])]
		return []
	return _travel(c, m, target)


func _services(engine: CardEngineApi, c: Dictionary, m: Dictionary, node: Dictionary) -> Array:
	var scene := str(c.get("scene_id", ""))
	var actions: Array = node.get("actions", [])
	for demand in engine.view().get("demands", []):
		var uid := str(demand.get("uid", ""))
		if uid.trim_prefix("demand:") in node.get("demands", []):
			var fulfill := Graph.card_action(engine, uid)
			if not fulfill.is_empty():
				return fulfill
	var done: Array = c.get("march", {}).get("activities_done", [])
	if "activity:rest" in actions and not "rest" in done and metric(c, "vitality") < 90:
		return ["campaign.activity", {"id": "rest"}]
	if "activity:festival" in actions and not "festival" in done and metric(c, "vitality") < 85:
		return ["campaign.activity", {"id": "festival"}]
	var scheduled: Array = c.get("calendar", {}).get("scheduled", [])
	if scheduled.size() < int(c.get("calendar", {}).get("max_slots", 3)):
		if "schedule:festival" in actions and metric(c, "vitality") < 70:
			return ["campaign.schedule", {"action": "festival"}]
		if "schedule:recruit" in actions and int(c.get("coins", {}).get("supply", 0)) < 5:
			return ["campaign.schedule", {"action": "recruit"}]
		if train_for_campaign and "schedule:train" in actions:
			return ["campaign.schedule", {"action": "train"}]
	if str(c.get("segment", "")) == "ocean":
		for project in ["build", "explore"]:
			var project_key: String = scene + ":" + str(project)
			var gauge := "construction" if project == "build" else "exploration"
			if project in actions and not _actions.has(project_key) and metric(c, gauge) < 100 and metric(c, "treasury") >= 300:
				_actions[project_key] = true
				return ["campaign." + str(project), {}]
	for action in ["trade:fair", "visit:town", "visit:backdoor"]:
		var key: String = scene + ":" + str(action)
		if action not in actions or _actions.has(key):
			continue
		if action == "visit:town" and (metric(c, "treasury") < 150 or metric(c, "vitality") >= 96):
			continue
		_actions[key] = true
		if action == "trade:fair":
			return ["campaign.trade", {"kind": "fair"}]
		return ["campaign.visit", {"place": action.trim_prefix("visit:")}]
	if "activity:merchant" in actions and not "merchant" in done and int(c.get("coins", {}).get("gold", 0)) >= 2 and int(c.get("coins", {}).get("supply", 0)) < 6:
		return ["campaign.activity", {"id": "merchant"}]
	if "build_depot" in actions and str(m.get("pos", "")) not in m.get("depots", []) and int(c.get("coins", {}).get("gold", 0)) >= 4:
		return ["campaign.map_build", {}]
	return []


func _nearest(m: Dictionary, c: Dictionary, role: String, unvisited: bool = false, kind: bool = false) -> String:
	var key := str(c.get("segment", "")) + ":" + str(c.get("chapter_id", "")) + ":"
	var best := ""
	var distance := 100000
	var pos := str(m.get("pos", ""))
	for n in m.get("nodes", []):
		var id := str(n.get("id", ""))
		if role != "" and str(n.get("type" if kind else "role", "")) != role:
			continue
		if unvisited and (_stamped.has(key + id) if role == "post" else _entered.has(key + id)):
			continue
		if str(n.get("reason", "")) not in ["", "scene_order"]:
			continue
		if role == "" and id == pos:
			continue
		var route := Graph.path_to(m, id)
		if route.is_empty() and id != pos:
			continue
		if route.size() < distance:
			distance = route.size()
			best = id
	return best


func _travel(c: Dictionary, m: Dictionary, target: String) -> Array:
	var route := Graph.path_to(m, target)
	if route.is_empty():
		last_error = "no_path:" + target
		return []
	var next := str(route[0])
	var link := Graph.link_between(m, str(m.get("pos", "")), next)
	if int(link.get("voyage_days", 0)) > 0:
		return ["campaign.map_move", {"to": next}] if bool(Graph.node_of(m, next).get("reachable", false)) else ["campaign.wait", {}]
	if int(m.get("mp", 0)) >= int(link.get("legs", 1)):
		return ["campaign.map_move", {"to": next}]
	if bool(m.get("can_roll", false)):
		var best := -1
		var best_mp := 0
		var score := -10000
		for card in m.get("hand", []):
			var points := 100 * int(card.get("mp", 0)) + int(card.get("coins", {}).get("supply", 0)) * 10
			if metric(c, "vitality") < 70:
				points += 5 * int(card.get("effects", {}).get("vitality", 0))
			if points > score:
				score = points
				best = int(card["index"])
				best_mp = int(card.get("mp", 0))
		if best_mp < int(link.get("legs", 1)) - int(m.get("mp", 0)):
			return ["campaign.map_roll", {"steps": 6} if int(c.get("coins", {}).get("intel", 0)) > 0 else {}]
		return ["campaign.map_card", {"index": best}] if best >= 0 else ["campaign.map_roll", {}]
	return ["campaign.wait", {}]


static func metric(c: Dictionary, id: String) -> int:
	for row in c.get("gauges", []):
		if str(row.get("id", "")) == id:
			return int(row.get("amount", row.get("value", 0)))
	return 0
