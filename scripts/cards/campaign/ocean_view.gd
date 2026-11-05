# Compatibility adapter for the existing card table. Campaign state never goes to UI.
# Player-visible text lives in data/campaigns/text/ocean_ui.json (A0; WORLD_MAP_DESIGN 15.1); this file has no Chinese literals.
class_name OceanView
extends RefCounted

const RogueData = preload("res://scripts/cards/campaign/ocean_rogue_data.gd")
const RogueRules = preload("res://scripts/cards/campaign/ocean_rogue_rules.gd")
const Battle2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const MapQuery = preload("res://scripts/cards/campaign/map/map_query.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const CompanionRules = preload("res://scripts/cards/campaign/companion_rules.gd")
const Conditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const SIDES := ["signage", "town", "backdoor", "resources", "battle", "march", "calendar", "squad", "status"]
const METRICS := ["treasury", "morale", "heat", "vitality", "construction", "exploration"]
const TEXT_PATH := "res://data/campaigns/text/ocean_ui.json"
## _dialog_pages 在这些句末标点后断页（。！？；）
const PAGE_BREAKS := ["\u3002", "\uff01", "\uff1f", "\uff1b", "\n"]

static var _text_db: CardDB
static var _text_owner: int = 0
## 多段书换段以后定义换了，静态文字（场景、人物、结局）要按新段重建
static var _text_def: String = ""
static var _text_sig: String = ""
static var _overlay: Dictionary = {}
static var _ui_text: Dictionary = {}


## 玩家看得见的字：data/campaigns/text/ocean_ui.json（读一次，缓存）
static func ui_text() -> Dictionary:
	if _ui_text.is_empty():
		var parsed = CardDB.read_json(TEXT_PATH)
		if typeof(parsed) == TYPE_DICTIONARY:
			_ui_text = parsed
		else:
			push_error("OceanView: cannot read " + TEXT_PATH)
	return _ui_text


## 顶层的一条字
static func _s(key: String) -> String:
	return str(ui_text().get(key, ""))


## 某一节里的一条字
static func _sec(section: String, key: String) -> String:
	return str(ui_text().get(section, {}).get(key, ""))


static func _metric_name(id: String, fallback: String, model = null) -> String:
	if model != null and not model.is_builtin():
		var labels: Dictionary = (model.definition.get("gauges", {}) as Dictionary).duplicate()
		labels.merge(model.book.get("raw", {}).get("segments", {}).get(str(model.state.get("segment", "")), {}).get("gauges", {}), true)
		if labels.has(id):
			return str(labels[id])
	return str(ui_text().get("metric_names", {}).get(id, fallback))


static func _sign_name(id: String, fallback: String) -> String:
	return str(ui_text().get("sign_names", {}).get(id, fallback))


static func _bond_name(model, tag: String) -> String:
	if model.is_builtin():
		return str(RogueData.BONDS.get(tag, {}).get("name", tag))
	for row in Battle2._bond_rows(Battle2.bond_set_id(model)):
		if str(row.get("tag", "")) == tag or str(row.get("id", "")) == tag:
			return str(row.get("name", tag))
	return tag


## 一遍替换 {名字}：只换 args 里有的键，换进去的值不再扫描；没给的占位符（{d}、{n}……）原样留给 CardText
static func _fmt(template: String, args: Dictionary) -> String:
	var out := ""
	var i := 0
	while i < template.length():
		var open := template.find("{", i)
		var close := template.find("}", open + 1) if open >= 0 else -1
		if open < 0 or close < 0:
			out += template.substr(i)
			break
		var key := template.substr(open + 1, close - open - 1)
		if args.has(key):
			out += template.substr(i, open - i) + str(args[key])
			i = close + 1
		else:
			out += template.substr(i, open + 1 - i)
			i = open + 1
	return out


static func build(model) -> Dictionary:
	setup_text(model)
	var state: Dictionary = model.state
	var current: Dictionary = model.scene()
	var chapter: Dictionary = model.chapter()
	var metrics: Dictionary = state.get("metrics", {})
	var rogue: Dictionary = state.get("rogue", {})
	var phase := str(state.get("phase", "month_open"))
	var hand: Array = []
	if not current.is_empty():
		hand.append(card(model, "story:" + str(current.get("id", "")), false))
	if bool(rogue.get("big_fate", {}).get("pending", false)):
		hand.append(card(model, "big_fate", false))
	for uid in SIDES:
		hand.append(card(model, uid, false))
	var demands: Array = []
	for row in _rows(state.get("demands", [])):
		if str(row.get("status", "pending")) == "pending":
			var demand := card(model, "demand:" + str(row.get("id", "")), false)
			demands.append(demand)
			hand.append(demand)
	var kept: Array = []
	for id in _inventory_ids(state):
		kept.append(card(model, "item:" + id, false))
	var seen_props := {}
	for p_id in _rows(rogue.get("props", [])):
		var pid := str(p_id)
		if not seen_props.has(pid):
			seen_props[pid] = true
			var p_card := card(model, "prop:" + pid, false)
			if not p_card.is_empty():
				kept.append(p_card)
	var contacts := _contacts_list(rogue, model)
	var op: Dictionary = {"kind": "", "args": {}}
	if phase == "game_over":
		op = {"kind": "game_over", "args": {"reason": _ending_id(state)}}
	return {
		"v": 1, "phase": phase, "mode": "shop", "busy": false,
		"game_over_reason": _ending_id(state), "hand": hand, "kept": kept,
		"contacts": contacts, "demands": demands, "tickets": [], "shelf_count": kept.size(),
		"self": {"uid": "ruhua", "def": "self.ruhua", "type": "self", "zone": "self",
			"person": "ruhua", "art": "portrait.ruhua", "used_today": false,
			"attrs": {"eye": int(metrics.get("morale", 0)), "tongue": int(metrics.get("heat", 0)),
				"pull": int(metrics.get("vitality", 0)), "nerve": int(metrics.get(
					"exploration" if str(chapter.get("id", "")) == "nautilus" else "construction", 0))}},
		"money": {"amount": int(metrics.get("treasury", 0)), "currency": str(chapter.get("currency", "pound"))},
		"rep_tier": clampi(int(metrics.get("morale", 0)) / 25, 0, 4),
		"heat_tier": clampi(int(metrics.get("heat", 0)) / 25, 0, 4),
		"date": _date(model), "notice": {"weather": "clear", "market_day": false,
			"news": [{"key": "ocean.notice", "args": {}}], "almanac": {}, "fortune": ""},
		"caps": {"kept": 99, "contacts": 8 if model.is_builtin() else model.roster()["ids"].size(), "shelf": 99},
		"goals": [{"id": "ocean.goal", "main": true, "status": "done" if phase == "game_over" else "open"}],
		"night_offers": [], "night_offer_cards": [],
		"stage_intro": {"bg": "bg.counter.day", "intro_paras": 0},
		"stage": {"set": "counter", "time": "night" if phase == "settle" else "day", "sealed": false},
		"open_panel": op, "estates": [], "pet": {"show": false},
		"relics": _relics(model), "stock": {"open": "", "week_deals": 0, "sources": []},
	}


static func card(model, uid: String, detailed: bool = true) -> Dictionary:
	var current: Dictionary = model.scene()
	var state: Dictionary = model.state
	var rogue: Dictionary = state.get("rogue", {})
	var def_id := ""
	var type := "event"
	var panel := "slots"
	var zone := "hand"
	var choices: Array = []
	var observations: Array = []
	var days_left := -1
	var demand: Dictionary = {}
	var presentation: Dictionary = {}
	if uid == "story:" + str(current.get("id", "")) and not current.is_empty():
		def_id = "ocean.scene." + str(current["id"])
		presentation = _presentation(current)
		# 剧情牌开满屏的剧情 VN（scripts/cards/ui/vn/vn_panel.gd），不再走旧的格子面板
		panel = "vn"
		if detailed:
			var clues: Array = _scene_entries(state, "clues", str(current["id"]))
			for app in _rows(current.get("appraisals", [])):
				var id := str(app.get("id", ""))
				if clues.has(id):
					observations.append("ocean.obs." + str(current["id"]) + "." + id)
				else:
					var reason := "bad_phase" if str(state.get("phase", "")) != "day" else MapRules.story_gate(model)
					var app_row := _choice("action:appraise:" + id, reason == "")
					if reason != "":
						app_row["reason"] = reason
					choices.append(app_row)
			for option in model.available_choices():
				var id := "action:choose:" + str(option.get("id", ""))
				var row := _choice(id, bool(option.get("available", option.get("enabled", true))))
				if str(option.get("reason", "")) == "battle_pending":
					row["reason_key"] = "ocean.reason.battle"
				# VN 有地方给每个灰掉的选项写原因：带上原因码，缺鉴定时带上还缺的鉴定（选项 id）
				if not bool(row["enabled"]):
					row["reason"] = str(option.get("reason", ""))
					if row["reason"] == "missing_clue":
						var needs: Array = []
						for clue in _rows(option.get("requires_clues", [])):
							if not clues.has(str(clue)):
								needs.append("action:appraise:" + str(clue))
						row["needs"] = needs
				choices.append(row)
	elif uid.begins_with("event:"):
		var event_id := uid.trim_prefix("event:")
		if not MapRules.enabled(model) or event_id == "" or MapRules.current_event(model) != event_id:
			return {}
		var event: Dictionary = model.event_def(event_id)
		if event.is_empty():
			return {}
		def_id = "ocean.event." + event_id
		panel = "vn"
		presentation = _presentation(event)
		if detailed:
			var phase_reason := _event_phase_reason(model)
			for app in _rows(event.get("appraisals", [])):
				var id := str(app.get("id", ""))
				if model._used("event:%s:clue:%s" % [event_id, id]):
					observations.append("ocean.event_obs." + event_id + "." + id)
				else:
					var row := _choice("action:map_appraise:" + id, phase_reason == "")
					if phase_reason != "":
						row["reason"] = phase_reason
					choices.append(row)
			for option in MapRules.event_choices(model, event):
				var reason := phase_reason if phase_reason != "" else MapRules.choice_error(model, event, option)
				var row := _choice("action:map_choose:" + str(option.get("id", "")), reason == "")
				if reason != "":
					row["reason"] = reason
					if reason == "missing_clue":
						var needs: Array = []
						for clue in _rows(option.get("requires_clues", [])):
							if not model._used("event:%s:clue:%s" % [event_id, clue]):
								needs.append("action:map_appraise:" + str(clue))
						row["needs"] = needs
				choices.append(row)
	elif uid in SIDES or uid == "big_fate":
		def_id = "ocean." + uid
		if uid == "status":
			type = "news"
			panel = "read"
		elif detailed and uid != "battle":
			choices = _side_choices(model, uid)
			_trim_disabled_reasons(choices)
	elif uid.begins_with("item:"):
		var id := uid.trim_prefix("item:")
		if not _inventory_ids(state).has(id):
			return {}
		def_id = "ocean.item." + id
		type = "news"
		panel = "read"
		zone = "kept"
	elif uid.begins_with("prop:"):
		var pid := uid.trim_prefix("prop:")
		if not _rows(rogue.get("props", [])).has(pid):
			return {}
		def_id = "ocean.prop." + pid
		type = "event"
		panel = "slots"
		zone = "kept"
		choices = [_choice("action:use_prop:" + pid, str(state.get("phase", "")) == "day")]
	elif uid.begins_with("companion:"):
		var cid := uid.trim_prefix("companion:")
		var comp: Dictionary = rogue.get("companions", {}).get(cid, {})
		if comp.is_empty() or not bool(comp.get("recruited", false)) or not bool(comp.get("alive", false)):
			return {}
		def_id = "ocean.companion." + cid
		type = "person"
		panel = "read"
		zone = "contacts"
	elif uid.begins_with("demand:"):
		for row in _rows(state.get("demands", [])):
			if str(row.get("id", "")) == uid.trim_prefix("demand:"):
				demand = row
				break
		if demand.is_empty():
			return {}
		def_id = "ocean." + uid.replace(":", ".")
		days_left = maxi(0, int(demand.get("due_day", 0)) - int(state.get("day", 0)))
		choices = [_choice("action:demand:" + str(demand["id"]), _can_fulfill(model, demand))]
	else:
		return {}
	var is_kept_ticket := uid.begins_with("item:") or uid.begins_with("prop:")
	var card_art := "prop.notice" if not is_kept_ticket else "prop.ticket"
	if uid == "signage":
		card_art = "prop.sign"
	elif uid == "town":
		card_art = "prop.lantern_post"
	elif uid == "backdoor":
		card_art = "prop.back_door"
	elif uid == "resources":
		card_art = "prop.abacus"
	elif uid == "battle":
		card_art = "prop.door_flag_red"
		# 战斗 v2：出征名单 / 战场 / 战果（ocean_battle2.gd 的 card_panel；面板在 scripts/cards/ui/battle/）
		panel = Battle2.card_panel(model)
	elif uid == "march":
		card_art = "prop.boat"
	elif uid == "calendar":
		card_art = "prop.calendar"
	elif uid == "squad":
		card_art = "prop.ledger"
	elif uid == "status":
		card_art = "prop.scale"
	elif uid == "big_fate":
		card_art = "illus.bf.wheel"
	elif uid.begins_with("prop:"):
		card_art = _prop_art(uid.trim_prefix("prop:"))
	elif uid.begins_with("item:"):
		card_art = _item_art(uid.trim_prefix("item:"))
	elif uid.begins_with("companion:"):
		card_art = _companion_art(uid.trim_prefix("companion:"))
	var result := {
		"uid": uid, "def": def_id, "type": type, "zone": zone, "gold": uid.begins_with("story:") or uid == "big_fate",
		"must_resolve": uid == "big_fate", "keepable": false, "expires_in": -1, "status": "open",
		"art": card_art,
		"person": "", "intent": "story", "source": "", "item": null, "asking": -1,
		"observations": observations, "days_left": days_left, "attrs": {}, "used_today": false,
		"away_days": 0, "can_appraise": false, "panel": panel, "actions": [],
		"stage": {"cast": [], "intro": [{"who": "", "ref": "body"}]},
	}
	if detailed:
		result["choices"] = choices
		result["slots"] = []
	if uid.begins_with("story:") or uid.begins_with("event:"):
		result["presentation"] = presentation
	if not demand.is_empty():
		result["demand"] = {"kind": "goods" if str(demand.get("item", "")) != "" else "money", "tier": 1}
		result["amount"] = int(demand.get("cost", 0))
		result["status"] = str(demand.get("status", "pending"))
	return result


## Only presentation data crosses the engine boundary; branch conditions and outcomes stay private.
static func _presentation(scene: Dictionary) -> Dictionary:
	var art: Variant = scene.get("art", {})
	if typeof(art) != TYPE_DICTIONARY or art.is_empty():
		return {}
	var staged := false
	for key in ["bg", "cast", "enter", "exit", "expr", "art"]:
		if art.has(key):
			staged = true
			break
	if not staged:
		var names: Dictionary = {}
		for person in art:
			if typeof(person) == TYPE_STRING and typeof(art[person]) == TYPE_STRING:
				names[person] = str(art[person])
		return {"art": names}
	var out: Dictionary = {}
	for key in ["bg", "cast", "enter", "exit", "expr", "art"]:
		if typeof(art.get(key)) in [TYPE_DICTIONARY, TYPE_ARRAY]:
			out[key] = art[key].duplicate(true)
	return out


static func _event_phase_reason(model) -> String:
	var state: Dictionary = model.state
	var phase := str(state.get("phase", ""))
	var map: Dictionary = state.get("map", {})
	var interlude := str(map.get("event", "")) == "" and str(map.get("interlude", "")) != ""
	if phase != "day" and not (interlude and phase in ["year_jump", "month_open", "morning"]):
		return "bad_phase"
	if bool(state.get("rogue", {}).get("big_fate", {}).get("pending", false)):
		return "big_fate_pending"
	return ""


static func _trim_disabled_reasons(choices: Array) -> void:
	# Every disabled-reason label is an extra row in the frozen dialog. A
	# single explanation keeps seven choices plus Later within its frame.
	var explained := false
	for choice in choices:
		if not bool(choice["enabled"]):
			if explained:
				choice["reason_key"] = ""
			explained = true


static func query(model, q: StringName, args: Dictionary = {}) -> Dictionary:
	setup_text(model)
	match str(q):
		"card":
			return card(model, str(args.get("uid", "")))
		"campaign":
			var current: Dictionary = model.scene()
			var rogue: Dictionary = model.state.get("rogue", {})
			var result := {
				"title": str(model.definition.get("title", "")),
				"scene_id": str(current.get("id", "")),
				"chapter_id": str(model.chapter().get("id", "")),
				"phase": str(model.state.get("phase", "")),
				"sign": str(model.state.get("sign", "white")),
				"gauges": _gauges(model),
				"ending_id": _ending_id(model.state),
				"choices": card(model, "story:" + str(current.get("id", ""))).get("choices", []),
				"coins": (rogue.get("coins", {}) as Dictionary).duplicate(true),
				"props": (rogue.get("props", []) as Array).duplicate(true),
				"bonds": RogueRules.bond_counts(rogue, model),
				"companions": _companions_query(rogue, model),
				"fallen_companions": (rogue.get("fallen_companions", []) as Array).duplicate(true),
				"march": _march_query(rogue),
				"calendar": (rogue.get("calendar", {}) as Dictionary).duplicate(true),
				"big_fate": (rogue.get("big_fate", {}) as Dictionary).duplicate(true),
				"army": Battle2.army_query(rogue, model.roster()["ids"], model.roster()["profiles"]),
				"battle2": Battle2.query(model),
				"segment": str(model.state.get("segment", "")),
				"map": _map_summary(model),
				"run": {"book": str(model.state.get("run", {}).get("book", "")), "path": (model.state.get("run", {}).get("path", []) as Array).duplicate(),
					"chapter_ord": int(model.state.get("run", {}).get("chapter_ord", 0))},
			}
			if CompanionRules.enabled(model):
				result["named_pairs"] = CompanionRules.public_pairs(model)
			return result
		"campaign.map":
			if args.keys().any(func(key: Variant) -> bool: return str(key) != "reveal") or (args.has("reveal") and typeof(args["reveal"]) != TYPE_BOOL):
				return {"ok": false, "err": "bad_args"}
			return MapQuery.map(model, bool(args.get("reveal", false)))
		"campaign.run":
			return MapQuery.run(model)
		"campaign.battle2":
			return Battle2.query(model)
		"campaign.battle_preview":
			return Battle2.preview(model, args)
		"slots":
			return {"uid": str(args.get("uid", "")), "slots": [], "coins": 0, "need": 0, "ready": false}
		"day.end_preview":
			var steps := {"month_open": "begin_month", "morning": "begin_day", "day": "end_day",
				"settle": "next_day", "year_jump": "year_next", "game_over": "game_over"}
			var phase := str(model.state.get("phase", ""))
			return {"step": str(steps.get(phase, "next_day")), "items": [], "can_end": phase != "game_over"}
		"stock":
			var items: Array = []
			for id in _inventory_ids(model.state):
				items.append({"item": id, "template": "ocean." + id, "cat": "paper", "art": "prop.ticket", "condition_word": 4})
			return {"items": items, "cap": 99}
		"relics":
			var relics := _relics(model)
			relics.merge({"ok": true, "err": ""})
			return relics
		"stocktake":
			return {"ok": false, "err": "not_allowed"}
		"tickets":
			return {"tickets": []}
		"estates":
			return {"estates": []}
		"settle_report", "month_report":
			return {"lines": [{"key": "ocean.report.status", "args": {}}]}
		"year_report":
			return {"lines": [{"key": "ocean.report.chapter", "args": {}, "section": "currency"},
				{"key": "ocean.report.status", "args": {}, "section": "after"}]}
		"firsts":
			return {"firsts": {"ocean": true}}
		"guide_data":
			return {"steps": [], "pages": [{"id": "ocean.rules", "order": 0, "teacher": "ruhua", "unlock_first": ["ocean"]}]}
		"guide_progress":
			return {"done": [], "skipped": [], "disabled": true}
		"guide_conds":
			return {"conds": {}}
		"dossier":
			return _dossier(model)
	return {}


## campaign 查询里的地图摘要（完整的在 campaign.map）
static func _map_summary(model) -> Dictionary:
	var m = model.state.get("map", {})
	if typeof(m) != TYPE_DICTIONARY or (m as Dictionary).is_empty():
		return {"enabled": false}
	return {"enabled": true, "sheet": str(m.get("sheet", "")), "pos": str(m.get("pos", "")), "mp": int(m.get("mp", 0)),
		"pending": str(m.get("pending", "")), "mustered": bool(m.get("mustered", false)), "days": int(m.get("days_on_sheet", 0))}


static func _contacts_list(rogue: Dictionary, model) -> Array:
	var out: Array = []
	var comps: Dictionary = rogue.get("companions", {})
	for c_id in model.roster()["ids"]:
		var row: Dictionary = comps.get(c_id, {})
		if not bool(row.get("recruited", false)) or not bool(row.get("alive", false)):
			continue
		var spec: Dictionary = model.roster()["specs"][c_id]
		out.append({
			"uid": "companion:" + c_id,
			"def": "ocean.companion." + c_id,
			"type": "person",
			"zone": "contacts",
			"person": c_id,
			"art": _companion_art(c_id),
			"used_today": false,
			"away_days": 0,
			"attrs": {
				"eye": int(row.get("atk", spec["atk"])),
				"tongue": int(spec.get("cost", 2)),
				"pull": int(row.get("hp", spec["max_hp"])),
				"nerve": int(row.get("block", spec["block"])),
			},
		})
	return out


static func _companion_art(c_id: String) -> String:
	match c_id:
		"dantes":
			return "portrait.brother"
		"gourgaud":
			return "portrait.ex_soldier"
		"faria":
			return "portrait.suanming"
		"friday":
			return "portrait.stranger_boatman"
		"nemo":
			return "portrait.stranger_collector"
		"morel":
			return "portrait.sunlaoye"
		"marie":
			return "portrait.ex_girl"
		"corso":
			return "portrait.ex_patrol"
	return "portrait.ruhua"


static func _prop_art(p_id: String) -> String:
	match p_id:
		"loaded_dice":
			return "prop.coin"
		"barricade":
			return "prop.trunk"
		"forced_march":
			return "prop.door_flag"
		"spyglass":
			return "prop.magnifier"
		"smoke_bomb":
			return "prop.lamp_off"
		"field_ration":
			return "prop.rice_sacks"
		"bribe_pouch":
			return "prop.cashbox"
		"imperial_decree":
			return "prop.stamp"
	return "prop.ticket"


static func _item_art(item_id: String) -> String:
	match item_id:
		"stolen_watch":
			return "item.utensils.clock"
		"code_manuscript":
			return "item.documents.letter"
		"sealed_orders":
			return "item.documents.receipt"
		"ship_compass":
			return "prop.magnifier"
		"medical_chest":
			return "item.medicine.quinine"
		"signal_mirror":
			return "item.silverware.box"
		"imperial_eagle":
			return "item.goldbar.bar_ten"
		"abyssal_chart":
			return "item.art.landscape"
	return "prop.ticket"


static func _companions_query(rogue: Dictionary, model) -> Array:
	var out: Array = []
	var comps: Dictionary = rogue.get("companions", {})
	for c_id in model.roster()["ids"]:
		var row: Dictionary = comps.get(c_id, {})
		var spec: Dictionary = model.roster()["specs"][c_id]
		out.append({
			"id": c_id,
			"name": str(spec["name"]),
			"class_label": str(spec["class_label"]),
			"place": str(row.get("place", spec["place"])),
			"recruited": bool(row.get("recruited", false)),
			"alive": bool(row.get("alive", true)),
			"level": int(row.get("level", 1)),
			"hp": int(row.get("hp", spec["max_hp"])),
			"max_hp": int(row.get("max_hp", spec["max_hp"])),
			"atk": int(row.get("atk", spec["atk"])),
			"block": int(row.get("block", spec["block"])),
			"cost": int(spec["cost"]),
			"gold_cost": int(spec["gold_cost"]) if model.is_builtin() else RogueRules.recruit_cost(model, c_id),
			"bonds": (spec["bonds"] as Array).duplicate(true),
			"skill_name": str(spec["skill_name"]),
		})
		if CompanionRules.enabled(model):
			out[-1].merge(CompanionRules.companion_status(model, str(c_id)))
	return out


static func _march_query(rogue: Dictionary) -> Dictionary:
	var march: Dictionary = rogue.get("march", {})
	var pos := clampi(int(march.get("pos", 0)), 0, RogueData.MARCH_BOARD.size() - 1)
	var tile: Dictionary = RogueData.MARCH_BOARD[pos]
	var route_id := str(march.get("route", "salon_route"))
	var route_spec: Dictionary = RogueData.ROUTES.get(route_id, RogueData.ROUTES["salon_route"])
	return {
		"pos": pos,
		"tile_id": str(tile["id"]),
		"tile_name": str(tile["name"]),
		"tile_desc": str(tile["desc"]),
		"laps": int(march.get("laps", 0)),
		"rolls": int(march.get("rolls", 0)),
		"last_roll": int(march.get("last_roll", 0)),
		"route": route_id,
		"route_name": str(route_spec["name"]),
		"activities_done": (march.get("activities_done", []) as Array).duplicate(true),
	}


# CardDB exposes its text layers as dictionaries; copy them before adding the
# campaign pack so the cached legacy database and its plugins stay unchanged.
static func setup_title_text(base: CardDB) -> CardDB:
	# v0.9 builds its title and old-ledger box before a campaign model exists.
	# This separate clone never replaces a live model's dynamic text overlay.
	var db := _copy_db(base)
	var title_text: Dictionary = {}
	var definition = CardDB.read_json("res://data/campaigns/ocean_pawn.json")
	_common_text(title_text, definition if typeof(definition) == TYPE_DICTIONARY else {})
	if typeof(definition) == TYPE_DICTIONARY:
		for id in _indexed(definition.get("characters", {})):
			db._cards["ocean.person." + str(id)] = {"id": "ocean.person." + str(id),
				"type": "dossier_fragment", "person": str(id), "order": 0}
	db._packs.append({"id": "ocean_title", "source": "ai",
		"provenance": "campaign adaptation", "text": title_text})
	CardText.setup(db)
	return db


static func _copy_db(base: CardDB) -> CardDB:
	var db := CardDB.new()
	db.root = base.root
	db.ship = base.ship
	db._cards = base._cards.duplicate(true)
	db._persons = base._persons.duplicate(true)
	db._ui_keys = base._ui_keys.duplicate(true)
	db._text = base._text.duplicate(true)
	db._ai_text = base._ai_text.duplicate(true)
	db._packs = base._packs.duplicate(true)
	db._rules = base._rules.duplicate(true)
	# The new script has one authored opening. Keep the v0.9 seed/ledger UI,
	# without offering Shanghai's alternate opening in a different campaign.
	db._rules["legacy"] = {"openings": {
		"og.default": {"veteran": false, "notice": "", "unlock_closed": 0, "order": 0}}}
	return db


static func setup_text(model) -> CardDB:
	if _text_db == null or _text_owner != model.get_instance_id() or _text_def != str(model.definition.get("id", "")):
		var base := CardDB.load_all()
		_text_db = _copy_db(base)
		_overlay = {}
		_text_db._packs.append({"id": "ocean_campaign", "source": "ai",
			"provenance": "campaign adaptation", "text": _overlay})
		_text_owner = model.get_instance_id()
		_text_def = str(model.definition.get("id", ""))
		_text_sig = ""
		_static_text(model)
	if CardText._db != _text_db:
		CardText.setup(_text_db)
	var state: Dictionary = model.state
	var b2: Dictionary = state.get("rogue", {}).get("battle2", {})
	var sig := "%d:%d:%s:%s:%d:%s:%d:%s:%s" % [
		int(state.get("scene_index", -1)),
		int(state.get("day", 0)),
		str(state.get("phase", "")),
		str(state.get("sign", "")),
		(state.get("ledger", []) as Array).size(),
		str(b2.get("phase", "")),
		int(b2.get("state", {}).get("turn", 0)),
		str(b2.get("state", {}).get("phase", "")),
		str(state.get("rogue", {}).get("big_fate", {}).get("pending", false)),
	]
	if CompanionRules.enabled(model):
		sig += ":" + str(hash([state.get("flags", {}), state.get("rogue", {}).get("companions", {}), state.get("rogue", {}).get("army", {}).get("trust", {}), state.get("map", {}).get("pos", "")]))
	if sig != _text_sig:
		_text_sig = sig
		_dynamic_text(model)
	if MapRules.enabled(model):
		var event: Dictionary = model.event_def(MapRules.current_event(model))
		if not event.is_empty():
			_event_text(model, event)
	return _text_db


## Event prose follows the same CardText contract as scene prose, including numbered audience questions.
static func _event_text(model, event: Dictionary) -> void:
	var id := str(event.get("id", ""))
	var choice_text: Dictionary = {}
	var outcomes: Dictionary = {}
	for app in _rows(event.get("appraisals", [])):
		var aid := str(app.get("id", ""))
		choice_text["action:map_appraise:" + aid] = str(app.get("label", aid))
		outcomes["action:map_appraise:" + aid] = _dialog_pages(str(app.get("observation", "")))
		_ui("ocean.event_obs." + id + "." + aid, str(app.get("observation", "")))
	for option in MapRules.event_choices(model, event):
		choice_text["action:map_choose:" + str(option.get("id", ""))] = str(option.get("label", ""))
	var body := _body_text(model, event)
	for question in _rows(event.get("questions", [])):
		var prompt := str(question.get("q", ""))
		if prompt != "":
			body += ("\n\n" if body != "" else "") + prompt
	var def_id := "ocean.event." + id
	_overlay[def_id] = {"title": str(event.get("title", id)), "body": _dialog_pages(body),
		"choices": choice_text, "outcomes": outcomes, "paras": body,
		"location": str(event.get("location", "")), "chapter": str(model.chapter().get("title", ""))}
	_text_db._cards[def_id] = {"id": def_id, "type": "event"}


static func _static_text(model) -> void:
	var definition: Dictionary = model.definition
	_common_text(_overlay, definition)
	_overlay["ruhua"] = {"name": _s("protagonist_name")}
	for id in _indexed(definition.get("characters", {})):
		var person: Dictionary = _indexed(definition.get("characters", {}))[id]
		_overlay[str(id)] = {"name": str(person.get("name", id))}
		_overlay["dp." + str(id)] = {"title": str(person.get("name", id))}
		_overlay["ocean.person." + str(id)] = {"body": str(person.get("description", person.get("role", "")))}
		_text_db._cards["ocean.person." + str(id)] = {"id": "ocean.person." + str(id),
			"type": "dossier_fragment", "person": str(id), "order": 0}
	for current in _rows(definition.get("scenes", [])):
		var id := str(current.get("id", ""))
		var choice_text: Dictionary = {}
		var outcomes: Dictionary = {}
		for app in _rows(current.get("appraisals", [])):
			var aid := str(app.get("id", ""))
			choice_text["action:appraise:" + aid] = str(app.get("label", aid))
			var obs_text := _dialog_pages(str(app.get("observation", "")))
			outcomes["action:appraise:" + aid] = obs_text
			_ui("ocean.obs." + id + "." + aid, str(app.get("observation", "")))
		for option in _rows(current.get("choices", [])):
			choice_text["action:choose:" + str(option.get("id", ""))] = str(option.get("label", ""))
		var def_id := "ocean.scene." + id
		# paras / location / chapter 给剧情 VN：正文原样的段落（不分页）、地点、所在的部
		var chapter_title := ""
		for chapter in _rows(definition.get("chapters", [])):
			if str(chapter.get("id", "")) == str(current.get("chapter", "")):
				chapter_title = str(chapter.get("title", ""))
		_overlay[def_id] = {"title": str(current.get("title", id)), "body": _dialog_pages(_scene_body(model, current)),
			"choices": choice_text, "outcomes": outcomes, "paras": _body_text(model, current),
			"location": str(current.get("location", "")), "chapter": chapter_title}
		_text_db._cards[def_id] = {"id": def_id, "type": "event"}
	for id in _indexed(definition.get("items", {})):
		var item: Dictionary = _indexed(definition.get("items", {}))[id]
		var name := str(item.get("name", item.get("title", id)))
		var body := _dialog_pages(str(item.get("description", item.get("body", _sec("item", "body_default")))))
		_overlay["ocean.item." + str(id)] = {"title": name, "body": body, "use": _sec("item", "use")}
		_overlay["item.ocean." + str(id)] = {"name": name, "description": body}
	for p_id in RogueData.PROP_IDS:
		var p_spec: Dictionary = RogueData.PROPS[p_id]
		var p_name := str(p_spec["name"])
		var p_desc := _dialog_pages(str(p_spec["desc"]))
		_overlay["ocean.prop." + p_id] = {
			"title": p_name,
			"body": p_desc,
			"use": p_desc,
			"choices": {"action:use_prop:" + p_id: _fmt(_s("prop_choice"), {"name": p_name})},
		}
		_text_db._cards["ocean.prop." + p_id] = {"id": "ocean.prop." + p_id, "type": "event"}
	for c_id in model.roster()["ids"]:
		var c_spec: Dictionary = model.roster()["specs"][c_id]
		if not model.is_builtin():
			_overlay[c_id] = {"name": str(c_spec["name"])}
		var b_names := PackedStringArray()
		for b_id in c_spec.get("bonds", []):
			b_names.append(_bond_name(model, str(b_id)))
		_overlay["ocean.companion." + c_id] = {
			"title": str(c_spec["name"]),
			"body": _fmt(_s("companion_body"), {"cls": str(c_spec["class_label"]),
				"bonds": _s("companion_bond_sep").join(b_names), "skill": str(c_spec["skill_name"])}),
		}
		_text_db._cards["ocean.companion." + c_id] = {"id": "ocean.companion." + c_id, "type": "person", "person": c_id}
	for chapter in _rows(definition.get("chapters", [])):
		_ui("c01.money.unit." + str(chapter.get("currency", "pound")), str(chapter.get("currency_name", _s("currency_default"))))
	for id in _indexed(definition.get("endings", {})):
		var ending: Dictionary = _indexed(definition.get("endings", {}))[id]
		_ui("g02.ending." + str(id), str(ending.get("title", id)) + "\n\n" + _body_text(model, ending))
	var fallback_endings: Dictionary = ui_text().get("fallback_endings", {})
	for id in fallback_endings:
		_ui("g02.ending." + str(id), str(fallback_endings[id]))
	_ui("g02.ending.obituary", Battle2.text("obituary_title") + "\n\n" + _paragraphs(Battle2.data().get("text", {}).get("obituary_body", [])))
	# 营地牌的标题、正文、选项（ocean_ui.json 的 overlays）；正文里随状态变的部分在 _dynamic_text
	var overlays: Dictionary = ui_text().get("overlays", {})
	for o_id in overlays:
		_overlay[str(o_id)] = (overlays[o_id] as Dictionary).duplicate(true)
	# 战斗 v2 的「战场」牌：文字在 ocean_battle.json；没有回话选项，打出去开出征名单 / 战场 / 战果面板
	_overlay["ocean.battle"] = {"title": Battle2.text("card_title"), "body": ""}
	_ui("ocean.reason.battle", Battle2.text("reason_battle"))
	for s_uid in ["battle", "march", "calendar", "squad", "big_fate"]:
		_text_db._cards["ocean." + s_uid] = {"id": "ocean." + s_uid, "type": "event"}
	var texts: Dictionary = ui_text().get("ui", {})
	for key in texts:
		_ui(str(key), str(texts[key]))
	if CompanionRules.enabled(model):
		for reason in ui_text().get("companion_v2", {}).get("reasons", {}):
			_ui("ocean.reason." + str(reason), str(ui_text()["companion_v2"]["reasons"][reason]))
	var tiers: Dictionary = ui_text().get("tiers", {})
	for tier in range(5):
		_ui("g03.tier.rep.%d" % tier, str(tiers.get("rep", [])[tier]))
		_ui("g03.tier.heat.%d" % tier, str(tiers.get("heat", [])[tier]))


static func _common_text(target: Dictionary, definition: Dictionary) -> void:
	var texts: Dictionary = ui_text().get("common", {})
	for key in texts:
		target[str(key)] = {"t": str(texts[key])}
	for id in _indexed(definition.get("endings", {})):
		var ending: Dictionary = _indexed(definition["endings"])[id]
		target["ocean.chronicle." + str(id)] = {"t": _fmt(_s("chronicle_ending"), {"title": str(ending.get("title", id))})}
	var names: Dictionary = ui_text().get("chronicle_names", {})
	for id in names:
		target["ocean.chronicle." + str(id)] = {"t": _fmt(_s("chronicle_ending"), {"title": str(names[id])})}
	target["ocean.chronicle.obituary"] = {"t": Battle2.text("chronicle_obituary")}


static func _dynamic_text(model) -> void:
	var state: Dictionary = model.state
	var rogue: Dictionary = state.get("rogue", {})
	var chapter: Dictionary = model.chapter()
	var current: Dictionary = model.scene()
	if not current.is_empty():
		(_overlay["ocean.scene." + str(current["id"])] as Dictionary)["body"] = _scene_body(model, current)
		if CompanionRules.enabled(model):
			_overlay["ocean.scene." + str(current["id"])]["paras"] = _body_text(model, current)
	if CompanionRules.enabled(model):
		for id in _indexed(model.definition.get("endings", {})):
			var ending: Dictionary = _indexed(model.definition.get("endings", {}))[id]
			_ui("g02.ending." + str(id), str(ending.get("title", id)) + "\n\n" + _body_text(model, ending))
	var summary := _summary(model)
	(_overlay["ocean.status"] as Dictionary)["body"] = summary + _ledger_text(model)
	if _ending_id(state) == "obituary":
		_ui("g02.ending.obituary", _obituary_text(model))
	(_overlay["ocean.resources"] as Dictionary)["body"] = _fmt(_sec("dynamic", "ocean.resources.body"), {"summary": summary})
	(_overlay["ocean.signage"] as Dictionary)["body"] = _fmt(_sec("dynamic", "ocean.signage.body"), {
		"sign": _sign_name(str(state.get("sign", "white")), _sec("dynamic", "ocean.signage.sign_default"))})
	(_overlay["ocean.town"] as Dictionary)["body"] = _sec("dynamic", "ocean.town.body")
	var coins: Dictionary = rogue.get("coins", {})
	(_overlay["ocean.battle"] as Dictionary)["body"] = _battle_card_text(model)
	var march_info := _march_query(rogue)
	(_overlay["ocean.march"] as Dictionary)["body"] = _fmt(_sec("dynamic", "ocean.march.body"), {
		"pos": int(march_info["pos"]),
		"tile": str(march_info["tile_name"]),
		"desc": str(march_info["tile_desc"]),
		"route": str(march_info["route_name"]),
		"rolls": int(march_info["rolls"]),
		"gold": int(coins.get("gold", 0)),
	})
	var cal: Dictionary = rogue.get("calendar", {})
	(_overlay["ocean.calendar"] as Dictionary)["body"] = _fmt(_sec("dynamic", "ocean.calendar.body"), {
		"week": int(cal.get("week", 1)),
		"countdown": int(cal.get("countdown", 3)),
		"scheduled": (cal.get("scheduled", []) as Array).size(),
		"slots": int(cal.get("max_slots", 3)),
	})
	(_overlay["ocean.squad"] as Dictionary)["body"] = _squad_body(rogue, model)
	if not model.is_builtin():
		var squad_labels := {}
		for c_id in model.roster()["ids"]:
			var spec: Dictionary = model.roster()["specs"][c_id]
			for action in ["recruit", "promote"]:
				var key := "action:" + str(action) + ":" + str(c_id)
				var label := _fmt(_s("companion_" + action), {"name": str(spec["name"]), "gold": RogueRules.recruit_cost(model, str(c_id))})
				squad_labels[key] = label
				_ui("c05.mode." + key, label)
			if CompanionRules.enabled(model):
				for action in ["reserve", "recall"]:
					var key := "action:" + str(action) + ":" + str(c_id)
					var label := _fmt(_sec("companion_v2", action), {"name": str(spec["name"])})
					squad_labels[key] = label
					_ui("c05.mode." + key, label)
				var bond_names := PackedStringArray()
				for bond in spec.get("bonds", []):
					bond_names.append(_bond_name(model, str(bond)))
				var original := _fmt(_s("companion_body"), {"cls": str(spec["class_label"]), "bonds": _s("companion_bond_sep").join(bond_names), "skill": str(spec["skill_name"])})
				_overlay["ocean.companion." + str(c_id)]["body"] = original + _companion_duty_text(model, str(c_id))
		_overlay["ocean.squad"]["choices"] = squad_labels
	(_overlay["ocean.big_fate"] as Dictionary)["body"] = _big_fate_body(model)
	_overlay["ocean.goal"] = {"title": _fmt(_sec("dynamic", "ocean.goal.title"), {
		"chapter": str(chapter.get("title", _sec("dynamic", "ocean.goal.chapter_default"))),
		"scene": str(current.get("title", _sec("dynamic", "ocean.goal.scene_default")))})}
	_ui("ocean.notice", _dialog_pages(_fmt(_sec("dynamic", "ocean.notice"), {
		"location": str(current.get("location", "")), "title": str(current.get("title", ""))})))
	_ui("ocean.report.status", _dialog_pages(summary))
	_ui("ocean.report.chapter", _fmt(_sec("dynamic", "ocean.report.chapter"), {
		"chapter": str(chapter.get("title", "")), "currency": str(chapter.get("currency_name", _s("currency_default")))}))
	var nerve := "exploration" if str(chapter.get("id", "")) == "nautilus" else "construction"
	_ui("c02.hero.nerve", (_sec("dynamic", "c02.hero.nerve.nautilus") if nerve == "exploration" else _sec("dynamic", "c02.hero.nerve.other")) if model.is_builtin() else _metric_name(nerve, nerve, model))
	for demand in _rows(state.get("demands", [])):
		var id := str(demand.get("id", ""))
		var title := str(demand.get("title", id))
		var days := maxi(0, int(demand.get("due_day", 0)) - int(state.get("day", 0)))
		var action := "action:demand:" + id
		var label := _sec("dynamic", "demand.goods") if str(demand.get("item", "")) != "" \
			else _fmt(_sec("dynamic", "demand.money"), {"cost": int(demand.get("cost", 0))})
		_overlay["ocean.demand." + id] = {"title": title,
			"body": _fmt(_sec("dynamic", "demand.body"), {"title": title, "days": days, "label": label}), "choices": {action: label},
			"outcomes": {"success": _sec("dynamic", "demand.success"), "fail": _sec("dynamic", "demand.fail"), "delay": _sec("dynamic", "demand.delay")}}
		_ui("c05.mode." + action, label)
	# Inventory may also contain runtime-created abstract supply tokens.
	for id in _inventory_ids(state):
		if not _overlay.has("ocean.item." + id):
			var name: String = _sec("item", "supply_medicine") if id == "medicine" else str(id).replace("_", " ")
			_overlay["ocean.item." + id] = {"title": name, "body": _sec("item", "supply_body")}
			_overlay["item.ocean." + id] = {"name": name}
	# The existing dialog splits on blank lines and has room for three text
	# lines. Paginate the content here rather than changing that UI contract.
	var dyn_ids: Array = ["ocean.big_fate"]
	if not current.is_empty():
		dyn_ids.append("ocean.scene." + str(current["id"]))
	for s_uid in SIDES:
		dyn_ids.append("ocean." + s_uid)
	for demand in _rows(state.get("demands", [])):
		dyn_ids.append("ocean.demand." + str(demand.get("id", "")))
	for id in dyn_ids:
		if _overlay.has(id):
			var entry: Dictionary = _overlay[id]
			entry["body"] = _dialog_pages(str(entry.get("body", "")))
			if str(id).begins_with("ocean.demand."):
				for outcome in entry.get("outcomes", {}):
					entry["outcomes"][outcome] = _dialog_pages(str(entry["outcomes"][outcome]))


## 「战场」牌的正文：本场的仗打到哪一步了（文字都在 ocean_battle.json 的 text.card_*）
static func _battle_card_text(model) -> String:
	var q := Battle2.query(model)
	var v: Dictionary = q.get("view", {})
	var args := {"battle": str(v.get("name", "")), "turn": int(v.get("turn", 0)), "limit": int(v.get("turn_limit", 0))}
	if not bool(q.get("has_battle", false)):
		return Battle2.text("card_body_free")
	if bool(model.state.get("rogue", {}).get("big_fate", {}).get("pending", false)):
		return Battle2.text("card_body_fate")
	match str(q.get("panel", "")):
		"battle_v2":
			return Battle2.text("card_body_active").format(args)
		"battle_result":
			if bool(q.get("resolved", false)):
				var res: Dictionary = q.get("result", {})
				args["outcome"] = str(Battle2.data().get("text", {}).get("outcome", {}).get(str(res.get("outcome", "")), ""))
				return Battle2.text("card_body_done").format(args)
			return Battle2.text("card_body_over").format(args)
	return Battle2.text("card_body_ready")


static func _squad_body(rogue: Dictionary, model) -> String:
	var coins: Dictionary = rogue.get("coins", {})
	var bonds := RogueRules.active_bonds(rogue, model)
	var b_names := PackedStringArray()
	for b_id in bonds:
		b_names.append(str(bonds[b_id]["name"]))
	var fallen: Array = rogue.get("fallen_companions", [])
	var body := _fmt(_sec("dynamic", "squad.body"), {
		"gold": int(coins.get("gold", 0)),
		"medal": int(coins.get("medal", 0)),
		"bonds": _s("list_sep").join(b_names) if not b_names.is_empty() else _sec("dynamic", "squad.bonds_none"),
		"fallen": (_s("list_sep").join(PackedStringArray(fallen)) if model.is_builtin() else _companion_names(fallen, model)) if not fallen.is_empty() else _sec("dynamic", "squad.fallen_none"),
	})
	if CompanionRules.enabled(model):
		body += _sec("companion_v2", "duty_intro")
		for id in model.roster()["ids"]:
			var comp: Dictionary = rogue.get("companions", {}).get(id, {})
			if bool(comp.get("recruited", false)) or bool(comp.get("left", false)):
				body += "\n" + str(model.roster()["specs"][id]["name"]) + _companion_duty_text(model, str(id))
		for pair in CompanionRules.public_pairs(model):
			body += _fmt(_sec("companion_v2", "pair"), {"name": pair["name"], "tier": pair["tier"], "status": _sec("companion_v2", "pair_active" if pair["active"] else "pair_inactive"), "desc": pair["desc"]})
	return body


static func _companion_duty_text(model, id: String) -> String:
	var status := CompanionRules.companion_status(model, id)
	var key := "left" if bool(status.get("left", false)) else ("reserved" if str(status.get("duty", "field")) == "reserve" else "field")
	var text := _sec("companion_v2", key)
	if not bool(status.get("left", false)):
		var comp: Dictionary = model.state.get("rogue", {}).get("companions", {}).get(id, {})
		if not bool(comp.get("alive", true)):
			return _sec("companion_v2", "fallen")
		if bool(comp.get("captured", false)):
			return _sec("companion_v2", "captured")
		var keep := str(status.get("keep", ""))
		if keep != "":
			text += _fmt(_sec("companion_v2", "keep"), {"effect": keep})
		var reason := str(status.get("deployment_reason", ""))
		if reason not in ["", "companion_on_duty"]:
			text += "\n" + str(ui_text().get("companion_v2", {}).get("reasons", {}).get(reason, ""))
	return text


static func _side_choices(model, uid: String) -> Array:
	var state: Dictionary = model.state
	var rogue: Dictionary = state.get("rogue", {})
	var coins: Dictionary = rogue.get("coins", {})
	var day := str(state.get("phase", "")) == "day"
	var chapter := str(model.chapter().get("id", ""))
	var scene_id := str(model.scene().get("id", ""))
	var metrics: Dictionary = state.get("metrics", {})
	var money := int(metrics.get("treasury", 0))
	var used := _scene_entries(state, "used_actions", scene_id)
	match uid:
		"signage":
			return [_choice("action:sign:white", day), _choice("action:sign:red", day),
				_choice("action:sign:black", day), _choice("action:wait", day)]
		"town":
			return [_choice("action:visit:town", day and not used.has("visit:town") and money >= 100),
				_choice("action:trade:fair", day and not used.has("trade")),
				_choice("action:trade:counterfeit", day and not used.has("trade"))]
		"backdoor":
			return [_choice("action:visit:backdoor", day and not used.has("visit:backdoor"))]
		"resources":
			var flags = state.get("flags", [])
			var funded := _has(flags, "revolution_funded") or _has(flags, "refused_funding")
			return [_choice("action:build", day and chapter == "new_elba" and money >= 200 and not used.has("construction") and int(metrics.get("construction", 0)) < 100),
				_choice("action:explore", day and chapter == "nautilus" and money >= 200 and not used.has("exploration") and int(metrics.get("exploration", 0)) < 100),
				_choice("action:fund:yes", day and chapter == "nautilus" and money >= 1000 and not funded),
				_choice("action:fund:no", day and chapter == "nautilus" and not funded)]
		"march":
			var route_used := used.has("route:" + scene_id)
			var done_acts: Array = rogue.get("march", {}).get("activities_done", [])
			return [
				_choice("action:roll_dice", day),
				_choice("action:pick_route:salon_route", day and not route_used),
				_choice("action:pick_route:duel_route", day and not route_used),
				_choice("action:pick_route:smuggle_route", day and not route_used),
				_choice("action:activity:salon", day and not done_acts.has("salon")),
				_choice("action:activity:duel", day and not done_acts.has("duel") and int(metrics.get("vitality", 0)) > 5),
				_choice("action:activity:gamble", day and not done_acts.has("gamble")),
			]
		"calendar":
			var cal: Dictionary = rogue.get("calendar", {})
			var has_slot := (cal.get("scheduled", []) as Array).size() < int(cal.get("max_slots", 3))
			return [
				_choice("action:schedule:recruit", day and has_slot),
				_choice("action:schedule:train", day and has_slot),
				_choice("action:schedule:bond_story", day and has_slot),
				_choice("action:schedule:diplomacy", day and has_slot),
				_choice("action:schedule:festival", day and has_slot),
				_choice("action:schedule:smuggle", day and has_slot),
			]
		"squad":
			var gold := int(coins.get("gold", 0))
			var medal := int(coins.get("medal", 0))
			if not model.is_builtin():
				var rows: Array = []
				for c_id in model.roster()["ids"]:
					var comp: Dictionary = rogue.get("companions", {}).get(c_id, {})
					if not bool(comp.get("alive", true)):
						continue
					if CompanionRules.enabled(model) and bool(comp.get("left", false)):
						continue
					if bool(comp.get("recruited", false)):
						rows.append(_choice("action:promote:" + str(c_id), day and _can_promote(rogue, str(c_id), medal)))
						if CompanionRules.enabled(model) and not model.book.get("companions", {}).get(c_id, {}).get("reserve", {}).is_empty():
							var reserved := CompanionRules.is_reserve(model, str(c_id))
							var reason := CompanionRules.duty_error(model, str(c_id), not reserved)
							var duty := _choice("action:" + ("recall:" if reserved else "reserve:") + str(c_id), reason == "")
							if reason != "":
								duty["reason"] = reason
								duty["reason_key"] = "ocean.reason." + reason
							rows.append(duty)
					else:
						var spec: Dictionary = model.roster()["specs"][c_id]
						if str(state.get("segment", "")) not in spec.get("segments", []):
							continue
						var reason := MapRules.gate(model, "recruit:" + str(c_id))
						var row := _choice("action:recruit:" + str(c_id), day and reason == "" and gold >= RogueRules.recruit_cost(model, str(c_id)))
						if reason != "":
							row["reason"] = reason
						rows.append(row)
				return rows
			return [
				_choice("action:recruit:friday", day and _can_recruit(rogue, "friday", gold)),
				_choice("action:recruit:nemo", day and _can_recruit(rogue, "nemo", gold)),
				_choice("action:recruit:morel", day and _can_recruit(rogue, "morel", gold)),
				_choice("action:recruit:marie", day and _can_recruit(rogue, "marie", gold)),
				_choice("action:recruit:corso", day and _can_recruit(rogue, "corso", gold)),
				_choice("action:promote:dantes", day and _can_promote(rogue, "dantes", medal)),
				_choice("action:promote:gourgaud", day and _can_promote(rogue, "gourgaud", medal)),
			]
		"big_fate":
			var pending := day and bool(rogue.get("big_fate", {}).get("pending", false))
			return [
				_choice("action:big_fate:sacrifice_rearguard", pending and _has_living_companion(rogue)),
				_choice("action:big_fate:ransom_supply", pending and money > 300),
				# 突围永远选得了：大命运不能卡死（生命与动力不够时这一下就耗尽，走“最后的灯火”）
				_choice("action:big_fate:desperate_breakout", pending),
			]
	return []


static func _can_recruit(rogue: Dictionary, c_id: String, gold: int) -> bool:
	var comp: Dictionary = rogue.get("companions", {}).get(c_id, {})
	if bool(comp.get("recruited", false)) or not bool(comp.get("alive", true)):
		return false
	var cost := int(RogueData.COMPANIONS.get(c_id, {}).get("gold_cost", 2))
	return gold >= cost


static func _can_promote(rogue: Dictionary, c_id: String, medal: int) -> bool:
	var comp: Dictionary = rogue.get("companions", {}).get(c_id, {})
	return bool(comp.get("recruited", false)) and bool(comp.get("alive", false)) and int(comp.get("level", 1)) < 3 and medal >= 1


## 大命运对话的正文：为什么触发、谁被俘；最后一段（和三个选项一起显示）写各选项当下的具体代价：会牺牲谁、
## 储备和生命与动力还剩多少。文字在 data/campaigns/ocean_battle.json（fate_*）。
static func _big_fate_body(model) -> String:
	var rogue: Dictionary = model.state.get("rogue", {})
	var metrics: Dictionary = model.state.get("metrics", {})
	var fate: Dictionary = rogue.get("big_fate", {})
	var whys: Dictionary = Battle2.data().get("text", {}).get("fate_why", {})
	var why := str(whys.get(str(fate.get("trigger", "")), whys.get("", "")))
	var captured := PackedStringArray()
	var victim := ""
	for c_id in model.roster()["ids"]:
		var comp: Dictionary = rogue.get("companions", {}).get(c_id, {})
		if not bool(comp.get("recruited", false)) or not bool(comp.get("alive", false)):
			continue
		if bool(comp.get("captured", false)):
			captured.append(str(model.roster()["profiles"].get(c_id, {}).get("short", c_id)))
		elif victim == "":
			victim = str(model.roster()["profiles"].get(c_id, {}).get("short", c_id))
	var cap_line := Battle2.text("fate_captured").format({"names": Battle2.text("list_sep").join(captured)}) if not captured.is_empty() else ""
	var money := int(metrics.get("treasury", 0))
	var vit := int(metrics.get("vitality", 0))
	var lines := (Battle2.text("fate_sacrifice").format({"name": victim}) if victim != "" else Battle2.text("fate_sacrifice_none")) \
		+ Battle2.text("fate_ransom" if money > 300 else "fate_ransom_poor").format({"money": money}) \
		+ Battle2.text("fate_breakout" if vit > 12 else "fate_breakout_last").format({"vit": vit})
	return Battle2.text("fate_body").format({"why": why, "captured": cap_line, "lines": lines})


static func _has_living_companion(rogue: Dictionary) -> bool:
	var comps: Dictionary = rogue.get("companions", {})
	for c_id in comps:
		var comp: Dictionary = comps[c_id]
		if bool(comp.get("recruited", false)) and bool(comp.get("alive", false)) and not bool(comp.get("captured", false)):
			return true
	return false


static func _choice(id: String, enabled: bool) -> Dictionary:
	return {"id": id, "enabled": enabled, "reason_key": "" if enabled else "ocean.reason.locked"}


static func _can_fulfill(model, demand: Dictionary) -> bool:
	if str(model.state.get("phase", "")) != "day" or str(demand.get("status", "pending")) != "pending" or str(demand.get("chapter", "")) != str(model.chapter().get("id", "")):
		return false
	var item := str(demand.get("item", ""))
	return int(model.state.get("metrics", {}).get("treasury", 0)) >= int(demand.get("cost", 0)) \
		and (item == "" or _inventory_ids(model.state).has(item))


static func _scene_body(model, current: Dictionary) -> String:
	var people := _indexed(model.definition.get("characters", {}))
	var speaker := str(current.get("speaker", ""))
	var name := str(people.get(speaker, {}).get("name", ""))
	var result := str(current.get("location", ""))
	if name != "":
		result += " · " + name
	result += "\n\n" + _body_text(model, current)
	var clues := _scene_entries(model.state, "clues", str(current.get("id", "")))
	for app in _rows(current.get("appraisals", [])):
		if clues.has(str(app.get("id", ""))):
			result += _fmt(_sec("scene", "appraised"), {"label": str(app.get("label", "")), "observation": str(app.get("observation", ""))})
	return result


static func _date(model) -> Dictionary:
	var current: Dictionary = model.scene()
	var raw = current.get("date", "1815-08-04")
	var y := 1815
	var m := 8
	var d := 4
	if typeof(raw) == TYPE_DICTIONARY:
		y = int(raw.get("y", raw.get("year", y)))
		m = int(raw.get("m", raw.get("month", m)))
		d = int(raw.get("d", raw.get("day", d)))
	elif typeof(raw) == TYPE_ARRAY and raw.size() >= 3:
		y = int(raw[0])
		m = int(raw[1])
		d = int(raw[2])
	else:
		var parts := str(raw).split("-")
		if parts.size() >= 3:
			y = int(parts[0])
			m = int(parts[1])
			d = int(parts[2])
	var index := 0
	var chapter: Dictionary = model.chapter()
	var chapters: Array = model.definition.get("chapters", [])
	for i in chapters.size():
		if str(chapters[i].get("id", "")) == str(chapter.get("id", "")):
			index = i
	var abs_day := int(model.state.get("day", 1))
	var scene_ids: Array = chapter.get("scene_ids", [])
	var scene_day := maxi(1, scene_ids.find(str(current.get("id", ""))) + 1)
	var scene_start := abs_day
	for row in _rows(model.state.get("ledger", [])):
		if str(row.get("scene", "")) == str(current.get("id", "")):
			scene_start = mini(scene_start, int(row.get("day", abs_day)))
	var stamp := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d,
		"hour": 0, "minute": 0, "second": 0}) + (abs_day - scene_start) * 86400
	var calendar := Time.get_datetime_dict_from_unix_time(stamp)
	y = int(calendar["year"])
	m = int(calendar["month"])
	d = int(calendar["day"])
	return {"stage": index, "era": str(chapter.get("id", "")), "y": y, "m": m, "d": d,
		"weekday": int(calendar["weekday"]), "stage_day": scene_day, "stage_days": maxi(1, scene_ids.size()), "abs_day": abs_day, "minute": 480}


static func _gauges(model) -> Array:
	var out: Array = []
	var metrics: Dictionary = model.state.get("metrics", {})
	for id in METRICS:
		out.append({"id": id, "label": _metric_name(id, id, model), "amount": int(metrics.get(id, 0))})
	return out


static func _relics(model) -> Dictionary:
	var held: Array = []
	var definitions := _indexed(model.definition.get("items", []))
	for id in _inventory_ids(model.state):
		if definitions.has(id):
			held.append({"id": "ocean.item." + id, "art": "prop.ticket", "depth": "treasure",
				"since": _item_since(model, id)})
	return {"cap": definitions.size(), "count": held.size(), "dormant": false, "held": held}


static func _item_since(model, id: String) -> int:
	var since := 0
	var scenes := _indexed(model.definition.get("scenes", []))
	for row in _rows(model.state.get("ledger", [])):
		if str(row.get("type", "")) != "choice":
			continue
		for choice in _rows(scenes.get(str(row.get("scene", "")), {}).get("choices", [])):
			if str(choice.get("id", "")) == str(row.get("id", "")) and id in choice.get("items", []):
				since = int(row.get("day", 0))
	return since


static func _summary(model) -> String:
	var chapter: Dictionary = model.chapter()
	var metrics: Dictionary = model.state.get("metrics", {})
	var coins: Dictionary = model.state.get("rogue", {}).get("coins", {})
	return _fmt(_s("summary" if model.is_builtin() else "formal_summary"), {
		"treasury_name": _metric_name("treasury", "treasury", model), "morale_name": _metric_name("morale", "morale", model),
		"heat_name": _metric_name("heat", "heat", model), "vitality_name": _metric_name("vitality", "vitality", model),
		"construction_name": _metric_name("construction", "construction", model), "exploration_name": _metric_name("exploration", "exploration", model),
		"chapter": str(chapter.get("title", "")), "treasury": int(metrics.get("treasury", 0)),
		"currency": str(chapter.get("currency_name", _s("currency_default"))),
		"morale": int(metrics.get("morale", 0)), "heat": int(metrics.get("heat", 0)), "vitality": int(metrics.get("vitality", 0)),
		"construction": int(metrics.get("construction", 0)), "exploration": int(metrics.get("exploration", 0)),
		"gold": int(coins.get("gold", 0)), "supply": int(coins.get("supply", 0)), "medal": int(coins.get("medal", 0)), "intel": int(coins.get("intel", 0))})


static func _ledger_text(model) -> String:
	var result := ""
	var chapters := _indexed(model.definition.get("chapters", []))
	var balances: Dictionary = model.state.get("chapter_balances", {})
	for id in balances:
		var chapter: Dictionary = chapters.get(id, {})
		result += _fmt(_sec("ledger", "balance"), {"chapter": str(chapter.get("title", id)),
			"treasury": int(balances[id].get("treasury", 0)), "currency": str(chapter.get("currency_name", _s("currency_default")))})
	var ledger: Array = _rows(model.state.get("ledger", []))
	for i in range(maxi(0, ledger.size() - 8), ledger.size()):
		var row: Dictionary = ledger[i]
		var label := _record_text(model, row)
		result += _fmt(_sec("ledger", "row"), {"day": int(row.get("day", 0)), "label": label})
	return _sec("ledger", "head") + result if result != "" else ""


static func _record_text(model, row: Dictionary) -> String:
	var rec: Dictionary = ui_text().get("record", {})
	var label := str(rec.get("default", ""))
	match str(row.get("type", "")):
		"start": label = _fmt(str(rec.get("start", "")), {"treasury": int(row.get("treasury", 0))})
		"appraisal": label = _fmt(str(rec.get("appraisal", "")), {"observation": str(row.get("observation", ""))})
		"choice":
			for scene in _rows(model.definition.get("scenes", [])):
				if str(scene.get("id", "")) == str(row.get("scene", "")):
					for choice in _rows(scene.get("choices", [])):
						if str(choice.get("id", "")) == str(row.get("id", "")):
							label = str(choice.get("label", str(rec.get("choice_default", ""))))
		"daily_sign": label = _fmt(str(rec.get("daily_sign", "")), {"sign": _sign_name(str(row.get("sign", "white")), str(rec.get("daily_sign_default", "")))})
		"visit": label = str(rec.get("visit_town" if str(row.get("place", "")) == "town" else "visit_backdoor", ""))
		"trade": label = str(rec.get("trade_fair" if str(row.get("kind", "")) == "fair" else "trade_counterfeit", ""))
		"project": label = _fmt(str(rec.get("project", "")), {"metric": _metric_name(str(row.get("metric", "")), str(rec.get("project_default", "")), model)})
		"funding": label = str(rec.get("funding_yes" if bool(row.get("support", false)) else "funding_no", ""))
		"demand_fulfilled": label = str(rec.get("demand_fulfilled_medicine" if str(row.get("id", "")) == "medicine" else "demand_fulfilled_bond", ""))
		"demand_expired": label = str(rec.get("demand_expired_medicine" if str(row.get("id", "")) == "medicine" else "demand_expired_bond", ""))
		"chapter_open": label = _fmt(str(rec.get("chapter_open", "")), {"treasury": int(row.get("treasury_start", 0))})
		"march_roll": label = _fmt(str(rec.get("march_roll", "")), {"steps": int(row.get("steps", 1)), "tile": str(row.get("tile", ""))})
		"pick_route": label = _fmt(str(rec.get("pick_route", "")), {"route": str(row.get("route", ""))})
		"activity": label = _fmt(str(rec.get("activity", "")), {"id": str(row.get("id", ""))})
		"schedule": label = _fmt(str(rec.get("schedule", "")), {"action": str(row.get("action", ""))})
		"recruit": label = _fmt(str(rec.get("recruit", "")), {"id": str(row.get("id", "")) if model.is_builtin() else _companion_names([str(row.get("id", ""))], model)})
		"promote": label = _fmt(str(rec.get("promote", "")), {"id": str(row.get("id", "")) if model.is_builtin() else _companion_names([str(row.get("id", ""))], model)})
		"companion_duty", "companion_departed": label = _fmt(_sec("companion_v2", str(row["type"])), {"name": _companion_names([str(row.get("id", ""))], model)})
		"use_prop": label = _fmt(str(rec.get("use_prop", "")), {"id": str(row.get("id", ""))})
		"battle_start": label = str(rec.get("battle_start", ""))
		"battle_scout": label = str(rec.get("battle_scout", ""))
		"battle_deploy": label = _fmt(str(rec.get("battle_deploy", "")), {"id": str(row.get("id", "")) if model.is_builtin() else _companion_names([str(row.get("id", ""))], model)})
		"battle_skill": label = _fmt(str(rec.get("battle_skill", "")), {"id": str(row.get("id", "")) if model.is_builtin() else _companion_names([str(row.get("id", ""))], model)})
		"battle_step": label = str(rec.get("battle_step", ""))
		"battle_victory": label = str(rec.get("battle_victory", ""))
		"battle_defeat": label = str(rec.get("battle_defeat", ""))
		"companion_fallen": label = _fmt(str(rec.get("companion_fallen", "")), {"id": str(row.get("id", "")) if model.is_builtin() else _companion_names([str(row.get("id", ""))], model)})
		"battle2": label = _battle2_text(row, model)
		"recruit_troop": label = Battle2.text("ledger_recruit_troop").format({"name": Battle2.troop_name({"id": str(row.get("id", "")), "cls": str(row.get("cls", ""))}), "gold": int(row.get("cost", 0))})
		"troop_disbanded": label = Battle2.text("ledger_troop_disbanded").format({"name": Battle2.troop_name({"id": str(row.get("id", "")), "cls": str(row.get("cls", ""))})})
		"big_fate":
			var fate_choices: Dictionary = _overlay.get("ocean.big_fate", {}).get("choices", {})
			var fate_id := str(row.get("choice", ""))
			label = _fmt(str(rec.get("big_fate", "")), {"choice": str(fate_choices.get("action:big_fate:" + fate_id, fate_id))})
		"ending": label = str(rec.get("ending", ""))
	var effects: Dictionary = row.get("effects", {})
	for id in effects:
		if int(effects[id]) != 0:
			label += _fmt(str(rec.get("effect", "")), {"metric": _metric_name(str(id), str(id), model), "delta": "%+d" % int(effects[id])})
	return label


## 战斗 v2 的账目：战场、胜负、星级、奖赏、阵亡、伤痕、被俘、主角下落（文字都在 ocean_battle.json）
static func _battle2_text(row: Dictionary, model = null) -> String:
	var tx: Dictionary = Battle2.data().get("text", {})
	var line := Battle2.text("ledger_battle").format({
		"battle": str(row.get("battle", "")), "outcome": str(tx.get("outcome", {}).get(str(row.get("outcome", "")), row.get("outcome", ""))),
		"stars": int(row.get("stars", 0)), "francs": int(row.get("francs", 0)), "treasury": int(row.get("treasury", 0)),
		"gold": int(row.get("gold", 0)), "medal": int(row.get("medal", 0)),
		"protagonist": str(tx.get("protagonist", {}).get(str(row.get("protagonist", "")), ""))})
	for pair in [["died", "ledger_died"], ["scarred", "ledger_scarred"], ["captured", "ledger_captured"]]:
		var ids: Array = _rows(row.get(pair[0], []))
		if not ids.is_empty():
			line += Battle2.text(pair[1]).format({"names": _companion_names(ids, model)})
	return line


static func _companion_names(ids: Array, model = null) -> String:
	var names := PackedStringArray()
	for c_id in ids:
		var specs: Dictionary = RogueData.COMPANIONS if model == null else model.roster()["specs"]
		names.append(str(specs.get(str(c_id), {}).get("name", c_id)))
	return Battle2.text("list_sep").join(names)


static func _obituary_text(model) -> String:
	var living: Array = []
	var comps: Dictionary = model.state.get("rogue", {}).get("companions", {})
	for c_id in model.roster()["ids"]:
		var comp: Dictionary = comps.get(c_id, {})
		if bool(comp.get("recruited", false)) and bool(comp.get("alive", false)):
			living.append(c_id)
	var memoir := Battle2.text("obituary_memoir").format({"names": _companion_names(living, model)}) if not living.is_empty() else Battle2.text("obituary_alone")
	return Battle2.text("obituary_title") + "\n\n" + _paragraphs(Battle2.data().get("text", {}).get("obituary_body", [])) + "\n\n" + memoir


static func _dossier(model) -> Dictionary:
	var pages: Array = []
	for id in _indexed(model.definition.get("characters", {})):
		pages.append({"person": str(id), "complete": true, "new": 0,
			"fragments": [{"id": "ocean.person." + str(id), "state": "have", "order": 0, "new": false, "kind": ""}]})
	return {"pages": pages}


static func _ending_id(state: Dictionary) -> String:
	var ending = state.get("ending", "")
	return str(ending.get("id", "")) if typeof(ending) == TYPE_DICTIONARY else str(ending)


static func _inventory_ids(state: Dictionary) -> Array:
	var raw = state.get("inventory", [])
	var result: Array = []
	if typeof(raw) == TYPE_DICTIONARY:
		for id in raw:
			if int(raw[id]) > 0:
				result.append(str(id))
	else:
		for row in _rows(raw):
			result.append(str(row.get("id", "")) if typeof(row) == TYPE_DICTIONARY else str(row))
	return result


static func _scene_entries(state: Dictionary, field: String, scene_id: String) -> Array:
	var rows = state.get(field, {}).get(scene_id, [])
	return rows.keys() if typeof(rows) == TYPE_DICTIONARY else _rows(rows)


static func _has(container, key: String) -> bool:
	return container.has(key) if typeof(container) in [TYPE_ARRAY, TYPE_DICTIONARY] else false


static func _indexed(raw) -> Dictionary:
	if typeof(raw) == TYPE_DICTIONARY:
		var result: Dictionary = {}
		for key in raw:
			result[str(key)] = raw[key] if typeof(raw[key]) == TYPE_DICTIONARY else {"name": str(raw[key])}
		return result
	var result: Dictionary = {}
	for row in _rows(raw):
		if typeof(row) == TYPE_DICTIONARY:
			result[str(row.get("id", ""))] = row
	return result


static func _body_text(model, entry: Dictionary) -> String:
	var body := _paragraphs(entry.get("body", entry.get("description", "")))
	if CompanionRules.enabled(model):
		for extra in _rows(entry.get("body_extra", [])):
			if typeof(extra) == TYPE_DICTIONARY and Conditions.eval(model, extra.get("when", {})):
				var text := _paragraphs(extra.get("body", []))
				if text != "":
					body += ("\n\n" if body != "" else "") + text
	return body


static func _paragraphs(raw) -> String:
	return "\n\n".join(PackedStringArray(raw)) if typeof(raw) == TYPE_ARRAY else str(raw)


static func _dialog_pages(text: String) -> String:
	var pages := PackedStringArray()
	# Keep explicit ledger/status rows intact; the source prose uses blank
	# lines, so both forms still become ordinary CardText dialogue beats.
	for paragraph in text.split("\n", false):
		var remaining := paragraph.strip_edges()
		while remaining != "":
			var cost := 0
			var cut := 0
			var sentence := 0
			while cut < remaining.length():
				var ch := remaining.substr(cut, 1)
				if cost + 1 > 52:
					break
				cost += 1
				cut += 1
				if ch in PAGE_BREAKS:
					sentence = cut
			if cut < remaining.length() and sentence >= 20:
				cut = sentence
			pages.append(remaining.left(cut).strip_edges())
			remaining = remaining.substr(cut).strip_edges()
	return "\n\n".join(pages)


static func _rows(raw) -> Array:
	return raw if typeof(raw) == TYPE_ARRAY else []


static func _ui(key: String, text: String) -> void:
	_overlay[key] = {"t": text}
