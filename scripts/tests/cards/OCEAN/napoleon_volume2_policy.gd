## Full-book route driver. All choices and travel use public queries and commands.
## Witnesses stay out of optional deployments; their one life is needed for the later hearings.
extends "res://scripts/tests/cards/OCEAN/napoleon_policy.gd"

const FUTURE_STORY := {
	"alps_marengo": "write_letters", "eylau_snow": "send_wounded_warsaw", "wagram_lobau": "anchor_bridges",
	"k_brussels": "gold_to_treasury", "k_ultimatum": "offer_1814_borders", "k_rhine": "bury_both",
	"k_bavaria": "bavaria_shares", "k_vienna": "spare_vienna", "k_schoenbrunn": "son_stays",
	"k_choice_1817": "to_iberia", "k_torres_vedras": "amnesty", "k_dover": "london_parley",
	"k_warsaw": "depots_first", "k_niemen": "raft_parley", "k_paris_1819": "rest_first",
	"k_leipzig_1819": "one_stone", "k_final": "final_peace",
	"c_tiboulen": "maltese_sailor", "c_livorno": "open_account", "c_montecristo": "leave_faria_share",
	"c_caderousse": "let_him_give", "c_morrel_rescue": "purse_as_planned", "c_carnival": "thomson_french",
	"c_san_sebastiano": "albert_oath", "c_champs_elysees": "map_the_names", "c_auteuil": "dig_the_box",
	"c_peers": "haydee_alone", "c_danglars": "expose_the_letter", "c_trial": "let_him_speak",
}
const EVENT_CHOICES := {
	"ev_morrel_petition": "free_34", "ev_haydee_constantinople": "count_buys",
	"ev_noirtier_eyes": "antidote_faria",
}
const DETOURS := {
	"k_charleroi": ["war_ministry"],
	"c_carnival": ["constantinople"],
	"c_peers": ["st_honore"],
}
const WITNESSES := ["dantes", "faria", "haydee"]

var events: Array = []
var detours_done: Array = []
var promotions := 0
var _visited_detours := {}


func _init() -> void:
	preferred.merge(FUTURE_STORY, true)


func step(engine: CardEngineApi) -> Dictionary:
	var before := engine.query(&"campaign.map")
	var current := Graph.node_of(before, str(before.get("pos", "")))
	var event := str(before.get("event", ""))
	var result := super.step(engine)
	if bool(result.get("ok", false)) and not commands.is_empty():
		var action: Array = commands.back()
		if str(action[0]) == "card.choose" and str(action[1].get("choice", "")).begins_with("action:promote:"):
			promotions += 1
	if bool(result.get("ok", false)) and event != "" and str(engine.query(&"campaign.map").get("event", "")) != event:
		if event not in events:
			events.append(event)
		var key := str(before.get("sheet", "")) + ":" + str(current.get("id", ""))
		_visited_detours[key] = true
		if str(current.get("id", "")) not in detours_done:
			detours_done.append(str(current.get("id", "")))
	return result


func decide(engine: CardEngineApi) -> Array:
	var c := engine.query(&"campaign")
	var m := engine.query(&"campaign.map")
	var battle: Dictionary = c.get("battle2", {})
	if bool(c.get("big_fate", {}).get("pending", false)) or str(battle.get("phase", "")) == "active":
		return super.decide(engine)
	if not bool(c.get("big_fate", {}).get("pending", false)) and str(battle.get("phase", "")) == "lineup":
		var lineup: Dictionary = (battle.get("lineup", {}) as Dictionary).duplicate(true)
		lineup["candidates"] = (lineup.get("candidates", []) as Array).filter(func(row: Dictionary) -> bool: return str(row.get("id", "")) not in WITNESSES)
		return ["campaign.battle_begin", Combat.lineup(lineup)]
	var event := str(m.get("event", ""))
	if event != "" and EVENT_CHOICES.has(event):
		return Graph.card_action(engine, "event:" + event, str(EVENT_CHOICES[event]))
	if str(engine.view().get("phase", "")) == "day" and str(m.get("pending", "")) == "" and str(m.get("interlude", "")) == "" and not bool(c.get("big_fate", {}).get("pending", false)) and str(battle.get("phase", "")) not in ["lineup", "active"]:
		var scene := str(c.get("scene_id", ""))
		for node_id in DETOURS.get(scene, []):
			var node := Graph.node_of(m, str(node_id))
			var key := str(m.get("sheet", "")) + ":" + str(node_id)
			if _visited_detours.has(key) or str(node.get("state", "")) == "done":
				continue
			if node.is_empty() or str(node.get("reason", "")) not in ["", "scene_order"]:
				last_error = "required_public_detour_locked:%s:%s" % [scene, node_id]
				return []
			if str(m.get("pos", "")) == str(node_id):
				if str(node.get("event", "")) != "":
					return ["campaign.map_enter", {}]
				# A non-event waypoint is complete once its public node is reached.
				_visited_detours[key] = true
				if node_id not in detours_done:
					detours_done.append(node_id)
				continue
			if Graph.path_to(m, str(node_id)).is_empty():
				last_error = "required_public_detour_unreachable:%s:%s" % [scene, node_id]
				return []
			var service := _services(engine, c, m, Graph.node_of(m, str(m.get("pos", ""))))
			if not service.is_empty():
				return service
			return _travel(c, m, str(node_id))
	return super.decide(engine)


func _services(engine: CardEngineApi, c: Dictionary, m: Dictionary, node: Dictionary) -> Array:
	var usual := super._services(engine, c, m, node)
	if not usual.is_empty():
		return usual
	if int(c.get("coins", {}).get("medal", 0)) > 1:
		for option in engine.query(&"card", {"uid": "squad"}).get("choices", []):
			var id := str(option.get("id", ""))
			if id.begins_with("action:promote:") and id.trim_prefix("action:promote:") not in WITNESSES and bool(option.get("enabled", false)):
				return ["card.choose", {"uid": "squad", "choice": id}]
	return []
