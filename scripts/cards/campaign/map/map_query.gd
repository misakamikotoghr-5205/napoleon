## 查询 campaign.map 和 campaign.run（WORLD_MAP_DESIGN §5.8）。只读、只给看得见的东西：雾里的节点不透露内容。
## 没有 class_name，别处 preload。返回的都是新字典，改了不影响状态。
extends RefCounted

const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const BattleApi = preload("res://scripts/cards/campaign/run/run_battle_api.gd")
const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")


static func map(campaign, reveal_all: bool = false) -> Dictionary:
	if campaign.state.is_empty() or not MapRules.enabled(campaign):
		return {"enabled": false}
	var m: Dictionary = campaign.state["map"]
	var sh := MapRules.sheet(campaign)
	var seg := str(campaign.state["segment"])
	var view_id := str(sh.get("view", ""))
	var hand: Array = []
	for i in (m["hand"] as Array).size():
		var id := str(m["hand"][i])
		var card := MapRules.card_def(campaign, id)
		hand.append({"index": i, "id": id, "mp": int(card.get("mp", 0)), "label": str(card.get("label", id)),
			"effects": (card.get("effects", {}) as Dictionary).duplicate(true), "coins": (card.get("coins", {}) as Dictionary).duplicate(true),
			"reveal": int(card.get("reveal", 0)), "ignore_forced": bool(card.get("ignore_forced", false)),
			"voyage_minus": int(card.get("voyage_minus", 0))})
	var out := {
		"enabled": true, "view": view_id, "view_def": (MapRules.map_of(campaign.book, seg).get("views", {}).get(view_id, {}) as Dictionary).duplicate(true),
		"frames": _frames(campaign, sh), "sheet": str(m["sheet"]), "chapter": str(m["sheet"]),
		"pos": str(m["pos"]), "mp": int(m["mp"]), "can_roll": not bool(m["rolled_today"]) and str(m["pending"]) == "",
		"hand": hand, "days": int(m["days_on_sheet"]), "days_max": int(sh.get("days_max", 0)), "delay": int(m["delay"]),
		"stamps": int(m["stamps"]), "stamps_need": int(sh.get("stamps_need", 0)), "depots": (m["depots"] as Array).duplicate(),
		"boss_mod": (m["boss_mod"] as Dictionary).duplicate(), "mustered": bool(m["mustered"]), "cp_early": int(m["cp_early"]),
		"pending": str(m["pending"]), "pending_kind": str(m["pending_kind"]), "meet": str(m["meet"]),
		"pay": _payment(campaign, sh),
		"event": str(m["event"]), "interlude": str(m["interlude"]), "encounter": str(m["encounter"].get("key", "")),
		"years": (sh.get("years", {}) as Dictionary).duplicate(true),
		"nodes": [], "links": [], "rivals": [], "teaser": [],
	}
	if reveal_all:
		out["reveal_all"] = true
	var pos := str(m["pos"])
	for n in sh.get("nodes", []):
		var id := str(n["id"])
		if not reveal_all and not MapRules.visible(campaign, id):
			continue
		out["nodes"].append(_node_row(campaign, sh, n, pos, reveal_all))
		if str(n.get("type", "")) == "teaser":
			out["teaser"].append({"id": id, "label": str(n.get("label", id)), "teaser": str(n.get("teaser", ""))})
	for l in sh.get("links", []):
		var a := str(l.get("a", ""))
		var b := str(l.get("b", ""))
		if not reveal_all and (not MapRules.visible(campaign, a) or not MapRules.visible(campaign, b)):
			continue
		var locked := not RunConditions.eval(campaign, l.get("requires", {}))
		out["links"].append({"a": a, "b": b, "legs": int(l.get("legs", 1)), "voyage_days": int(l.get("voyage_days", 0)),
			"oneway": bool(l.get("oneway", false)), "state": "locked" if locked else "open", "label": str(l.get("label", "")),
			"supply": int(l.get("supply", 0)), "toll": (l.get("toll", {}) as Dictionary).duplicate(), "route": str(l.get("route", ""))})
	for r in sh.get("rivals", []):
		if not MapRules.rival_active(campaign, r):
			continue
		var at := MapRules.rival_pos(campaign, r)
		if not MapRules.visible(campaign, at):
			continue
		var path: Array = r.get("path", [])
		var step := int(m["rivals"][str(r["id"])]["step"])
		out["rivals"].append({"id": str(r["id"]), "label": str(r.get("label", r["id"])), "pos": at,
			"next": str(path[(step + int(r.get("speed", 1))) % path.size()]), "stopped": int(m["rivals"][str(r["id"])]["stopped_until"]) >= int(campaign.state["day"])})
	return out


static func _payment(campaign, sh: Dictionary) -> Dictionary:
	var m: Dictionary = campaign.state["map"]
	var kind := str(m.get("pending_kind", ""))
	if kind not in ["toll", "rival"]:
		return {}
	var toll: Dictionary = m.get("toll", {})
	var rival: Dictionary = {}
	if kind == "rival":
		for row in sh.get("rivals", []):
			if str(row.get("id", "")) == str(m.get("meet", "")):
				rival = row
				toll = row.get("meet", {}).get("toll", {})
	var rogue: Dictionary = campaign.state["rogue"]
	var ready := str(campaign.state.get("phase", "")) == "day" and not bool(rogue.get("big_fate", {}).get("pending", false))
	if MapRules.CompanionRules.reserve_bonus(campaign, "toll_free") > 0 and not toll.is_empty():
		toll = toll.duplicate(true)
		for currency in toll:
			toll[currency] = 0
	var gold := int(toll.get("gold", -1))
	var can_wait := false
	var path: Array = rival.get("path", [])
	if not path.is_empty():
		var step := int(m["rivals"][str(rival["id"])]["step"])
		for distance in range(1, path.size() + 1):
			can_wait = can_wait or str(path[(step + int(rival.get("speed", 1)) * distance) % path.size()]) != str(m["pos"])
	return {"gold": gold, "cost": toll.duplicate(true), "can_gold": ready and MapRules.toll_error(campaign, toll) == "",
		"can_prop": ready and "prop_bribe_pouch" in rogue.get("props", []),
		"can_fight": ready and typeof(rival.get("meet", {}).get("battle")) == TYPE_DICTIONARY,
		"can_wait": ready and can_wait}


## Camera conditions are evaluated here; UI code never needs campaign flags to choose a frame.
static func _frames(campaign, sh: Dictionary) -> Array:
	var frames: Array = []
	for value in sh.get("frames", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var frame: Dictionary = value.duplicate(true)
		frame["active"] = RunConditions.eval(campaign, frame.get("when", {}))
		frame.erase("when")
		frames.append(frame)
	return frames


static func _node_row(campaign, sh: Dictionary, n: Dictionary, pos: String, reveal_all: bool = false) -> Dictionary:
	var m: Dictionary = campaign.state["map"]
	var id := str(n["id"])
	var revealed := MapRules.revealed(campaign, id) or id == pos
	var row := {"id": id, "label": str(n.get("label", id)), "date": str(n.get("date", "")), "role": str(n.get("role", "")),
		"phase": str(n.get("phase", "accumulate")), "offset": (n.get("offset", []) as Array).duplicate() if typeof(n.get("offset")) == TYPE_ARRAY else []}
	if n.has("xy"):
		row["xy"] = (n["xy"] as Array).duplicate()
	if n.has("geo"):
		row["geo"] = (n["geo"] as Array).duplicate()
	if typeof(n.get("xy_frames")) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		row["xy_frames"] = n["xy_frames"].duplicate(true)
	if typeof(n.get("frame")) == TYPE_STRING:
		row["frame"] = str(n["frame"])
	var lock := MapRules.enter_reason(campaign, n)
	var st := "open"
	if id == pos:
		st = "current"
	elif id in m["done"]:
		st = "done"
	elif lock != "":
		st = "locked"
	elif not revealed:
		st = "fog"
	row["state"] = st
	row["reason"] = lock
	if not revealed:
		# Screenshot reveal exposes cartography only, never event choices, observations or node actions.
		row["type"] = MapRules.node_kind(campaign, n) if reveal_all else "?"
		row["role"] = ""
		if reveal_all:
			row["preview_only"] = true
			row["reachable"] = false
		return row
	var kind := MapRules.node_kind(campaign, n)
	row["type"] = kind
	row["scene"] = str(n.get("scene", ""))
	row["event"] = str(n.get("event", "")) if str(n.get("type", "")) != "slot" else (str(m["slots"][id]["id"]) if kind == "event" else "")
	row["actions"] = MapRules.node_actions(campaign, n)
	row["demands"] = (n.get("demands", []) as Array).duplicate()
	var battle := _battle_of(campaign, n, kind)
	if not battle.is_empty():
		row["level"] = int(battle["level"])
		row["stars"] = BattleApi.stars(int(battle["level"]))
		row["power"] = BattleApi.power(str(battle["template"]), int(battle["level"]))
		row["template"] = str(battle["template"])
	var link := MapRules.link_between(sh, pos, id)
	row["reachable"] = false
	row["cost"] = {}
	if not link.is_empty():
		var legs := int(link.get("legs", 1))
		var voyage := int(link.get("voyage_days", 0))
		var ok := MapRules.lock_reason(campaign, n) == "" and RunConditions.eval(campaign, link.get("requires", {})) and str(m["pending"]) == ""
		if voyage > 0:
			ok = ok and int(m["mp"]) == 0 and not bool(m["moved_today"])
		else:
			ok = ok and legs <= int(m["mp"])
		row["reachable"] = ok
		row["cost"] = {"legs": legs, "voyage_days": voyage, "supply": int(link.get("supply", 0)), "toll": (link.get("toll", {}) as Dictionary).duplicate()}
	return row


static func _battle_of(campaign, n: Dictionary, kind: String) -> Dictionary:
	if str(n.get("scene", "")) != "":
		return campaign.scene_battle(str(n["scene"]))
	if kind in MapRules.BATTLE_TYPES:
		if str(n.get("type", "")) == "slot":
			var slot: Dictionary = campaign.state["map"]["slots"].get(str(n["id"]), {})
			return {"template": str(slot.get("id", "")), "level": int(slot.get("level", 1))}
		return {"template": MapRules.node_template(n), "level": int(n.get("level", 1))}
	return {}


## campaign.run：书、卷、当前段、走过的段、等级偏移、章序；当前场有分岔抉择时给出三条分支能不能走、为什么
static func run(campaign) -> Dictionary:
	if campaign.state.is_empty():
		return {}
	var r: Dictionary = campaign.state.get("run", {})
	var raw: Dictionary = campaign.book.get("raw", {})
	var segment := str(campaign.state.get("segment", ""))
	var offers: Array = []
	for c in campaign.available_choices():
		if str(c.get("branch", "")) == "":
			continue
		offers.append({"segment": str(c["branch"]), "choice": str(c["id"]), "ok": bool(c["available"]),
			"reason": str(c.get("cond", c.get("reason", ""))) if not bool(c["available"]) else "",
			"reason_root": RunConditions.root(str(c.get("cond", ""))) if not bool(c["available"]) else ""})
	return {"book": str(r.get("book", "")), "volume": int(r.get("volume", 1)), "segment": str(campaign.state.get("segment", "")),
		"title": str(raw.get("title", {}).get("name", campaign.definition.get("title", ""))),
		"brand": str(raw.get("segments", {}).get(segment, {}).get("brand", campaign.definition.get("title", ""))),
		"path": (r.get("path", []) as Array).duplicate(), "level_offset": int(r.get("level_offset", 0)), "chapter_ord": int(r.get("chapter_ord", 0)),
		"stats": (r.get("stats", {}) as Dictionary).duplicate(), "medal_earned": RunConditions.stat(campaign, "medal_earned"),
		"branch_offers": offers, "start_segment": str(r.get("start", {}).get("segment", "")), "start_stage": int(r.get("start", {}).get("stage", 0)),
		"carry": str(r.get("start", {}).get("carry", "")), "meta": {}}
