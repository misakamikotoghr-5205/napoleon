# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Frozen default stage scripts. Contract: CARDS_INTERFACES.md section 7.11.4.
# Only public card/view snapshots are read; text remains a CardText reference.
class_name CardStageScript
extends RefCounted

const GENERIC_TYPES: Array[String] = ["event", "fate", "big_fate", "street", "prison", "life"]
const PERSON_INTENTS: Array[String] = ["pawn", "sell", "buy", "redeem"]


static func resolve(card_view: Dictionary, view: Dictionary) -> Dictionary:
	var type := str(card_view.get("type", ""))
	var view_stage: Dictionary = view.get("stage", {})
	var block: Dictionary = card_view.get("stage", {})
	var script := {
		"uid": str(card_view.get("uid", "")), "def": str(card_view.get("def", "")),
		"type": type, "person": str(card_view.get("person", "")),
		"set": "counter" if type == "night" else str(view_stage.get("set", "counter")),
		"cast": _default_cast(card_view), "props": _default_props(card_view),
		"fx": [], "walk": "", "intro": [], "after": {},
	}
	if block.has("set"):
		script["set"] = str(block["set"])
	if block.has("cast"):
		script["cast"] = _cast(block["cast"])
	if block.has("props"):
		script["props"] = _props(block["props"])
	if block.has("fx"):
		script["fx"] = (block["fx"] as Array).duplicate(true)
	if block.has("walk"):
		script["walk"] = str(block["walk"])
	if block.has("intro"):
		script["intro"] = _beats(script, block["intro"])
	else:
		script["intro"] = _default_intro(script, card_view)
	var after: Dictionary = {}
	for key in CardIds.STAGE_AFTER_KEYS:
		var batch := _default_after(script, str(key))
		if not batch.is_empty():
			after[str(key)] = batch
	if type == "person" or type in GENERIC_TYPES:
		for choice in card_view.get("choices", []):
			var key := str((choice as Dictionary).get("id", ""))
			if key != "" and not after.has(key):
				after[key] = [_card_line(script, "narr", "", "outcomes." + key, true)]
	for key in block.get("after", {}):
		after[str(key)] = _beats(script, block["after"][key])
	script["after"] = after
	return script


static func lines(script: Dictionary, key: String) -> Array:
	if key == "intro":
		return (script.get("intro", []) as Array).duplicate(true)
	var after: Dictionary = script.get("after", {})
	if after.has(key):
		return (after[key] as Array).duplicate(true)
	return _default_after(script, key)


static func bg_id(script: Dictionary, view: Dictionary) -> String:
	var view_stage: Dictionary = view.get("stage", {})
	var set_id := str(script.get("set", view_stage.get("set", "counter")))
	if set_id == "":
		set_id = "counter"
	if set_id == "counter":
		return "bg.counter." + str(view_stage.get("time", "day"))
	return "bg." + set_id


static func speaker(script: Dictionary) -> String:
	match str(script.get("type", "")):
		"person":
			return str(script.get("person", ""))
		"demand":
			return "hu2"
		"news":
			for line in script.get("intro", []):
				if str(line.get("kind", "")) == "say":
					return str(line.get("who", ""))
			var news_cast: Array = script.get("cast", [])
			return str(news_cast[0].get("who", "ex_newsboy")) if not news_cast.is_empty() else "ex_newsboy"
	var cast: Array = script.get("cast", [])
	return str(cast[0].get("who", "")) if not cast.is_empty() else ""


static func _default_cast(card_view: Dictionary) -> Array:
	var who := ""
	var at := "customer"
	match str(card_view.get("type", "")):
		"person":
			who = str(card_view.get("person", ""))
		"demand":
			who = "hu2"
		"news":
			who = str(card_view.get("source", ""))
			if who == "":
				who = "ex_newsboy"
				at = "door"
		"event":
			if str(card_view.get("fortune", "")) != "":
				who = "suanming"
	return [{"who": who, "at": at, "look": "stand"}] if who != "" else []


static func _default_props(card_view: Dictionary) -> Array:
	match str(card_view.get("type", "")):
		"person":
			if str(card_view.get("intent", "")) == "redeem":
				return [{"art": "prop.ticket", "at": "counter_left"}]
		"demand":
			return [{"art": "prop.notice", "at": "counter_mid"}]
		"pawn_ticket":
			return [{"art": "prop.ticket", "at": "counter_mid"}]
	return []


static func _default_intro(script: Dictionary, card_view: Dictionary) -> Array:
	var type := str(script["type"])
	var who := speaker(script)
	var intro: Array = []
	match type:
		"person":
			var entrance := "w0.stage.enter"
			for actor in script["cast"]:
				if str(actor.get("who", "")) == who and str(actor.get("at", "")).begins_with("door"):
					entrance = "w0.stage.at_door"
					break
			intro.append(_line("narr", "", entrance, {"name": CardText.person_name(who)}, true))
			intro.append(_card_line(script, "say", who, "lines.greet"))
			intro.append(_card_line(script, "narr", "", "body"))
			if str(card_view.get("intent", "")) in PERSON_INTENTS:
				intro.append(_card_line(script, "say", who, "lines.ask", true))
		"news":
			who = str(card_view.get("source", ""))
			if who == "":
				who = "ex_newsboy"
			intro.append(_card_line(script, "say", who, "lines.greet", true))
			intro.append(_card_line(script, "narr", "", "body"))
		"demand":
			intro.append(_card_line(script, "say", who, "lines.issue"))
			intro.append(_card_line(script, "narr", "", "body"))
		_:
			var cast: Array = script["cast"]
			if type in GENERIC_TYPES and type != "life" and not cast.is_empty():
				var at := str(cast[0].get("at", ""))
				if at == "customer" or at == "companion" or at.begins_with("door"):
					intro.append(_card_line(script, "say", who, "lines.greet", true))
			intro.append(_card_line(script, "narr", "", "body"))
	return intro


static func _default_after(script: Dictionary, key: String) -> Array:
	var type := str(script.get("type", ""))
	var who := speaker(script)
	if type == "person":
		match key:
			"accept", "counter":
				return [_card_line(script, "say", who, "lines." + key)]
			"leave", "refused":
				return [_card_line(script, "say", who, "lines." + key),
					_line("narr", "", "w0.stage.leave", {"name": CardText.person_name(who)})]
			"impatient":
				return [_card_line(script, "say", who, "lines.impatient", true)]
	if (type == "person" or type in GENERIC_TYPES or type == "demand") and key in ["success", "fail"]:
		return [_card_line(script, "narr", "", "outcomes." + key)]
	if type in GENERIC_TYPES and key == "pass":
		return [_card_line(script, "narr", "", "outcomes.pass", true)]
	if type == "demand" and key == "delay":
		return [_card_line(script, "narr", "", "outcomes.delay", true)]
	if type == "night" and key == "done":
		return [_card_line(script, "narr", "", "outcomes.done", true)]
	if (type == "person" or type in GENERIC_TYPES) and key != "" and not StringName(key) in CardIds.STAGE_AFTER_KEYS:
		return [_card_line(script, "narr", "", "outcomes." + key, true)]
	return []


static func _cast(rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		result.append({"who": str(row.get("who", "")), "at": str(row.get("at", "customer")),
			"look": str(row.get("look", "stand"))})
	return result


static func _props(rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		result.append({"art": str(row.get("art", "")), "at": str(row.get("at", "counter_mid"))})
	return result


static func _beats(script: Dictionary, rows: Array) -> Array:
	var result: Array = []
	for row in rows:
		var who := str(row.get("who", ""))
		var kind := "narr" if who == "" else ("me" if who == "me" else "say")
		result.append(_card_line(script, kind, who, str(row.get("ref", ""))))
	return result


static func _card_line(script: Dictionary, kind: String, who: String, field: String, opt: bool = false) -> Dictionary:
	return _line(kind, who, str(script.get("def", "")) + "#" + field, {}, opt)


static func _line(kind: String, who: String, ref: String, args: Dictionary = {}, opt: bool = false) -> Dictionary:
	var line_args := args.duplicate(true)
	if who != "":
		line_args["name"] = CardText.person_name("ruhua" if who == "me" else who)
	return {"kind": kind, "who": who, "ref": ref, "args": line_args, "opt": opt}
