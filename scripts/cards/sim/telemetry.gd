# 平衡观察器：监听公开总线并读公开视图/查询，不访问引擎上下文。
# G06；合同 §12.6。开发报告可用独立只读数据库给公开牌 id 分类。
# 肉鸽 v1（RG6，docs/cards/rogue/ROGUE_V1.md §14）：每关一块 stock —— 报价几份（周末 / 货郎）、每份几样、摆出过什么、
# 挑了什么（物件 / 客源 / 都不要 / 让出）、被拒几次、每周做成几笔（视图 stock.week_deals）；只读公开查询 stocktake。
extends RefCounted

const WEEK_DAYS: Array = [7, 14, 21, 28]

var engine: CardEngineApi
var catalog: CardDB
var stages: Dictionary = {}
var hashes: Array = []
var _view: Dictionary = {}
var _days_seen: Dictionary = {}
var _hand_days_seen: Dictionary = {}
var _previous_mode: String = "shop"
var _last_terminal: String = ""
var _offers_seen: Dictionary = {}    # offer id -> {"stage": String, "kinds": {item id: kind}, "row": index in list}


func attach(p_engine: CardEngineApi, db: CardDB) -> void:
	engine = p_engine
	catalog = db
	engine.bus.view_changed.connect(_changed)
	engine.bus.command_done.connect(_command)
	engine.bus.card_left.connect(_left)
	engine.bus.cards_dealt.connect(_dealt)
	engine.bus.coins_tossed.connect(_coins)
	engine.bus.wheel_spun.connect(_wheel)
	engine.bus.request_panel.connect(_panel)
	engine.bus.game_over.connect(_over)
	_changed(PackedStringArray())


func _row() -> Dictionary:
	var stage: String = str(_view.get("date", {}).get("stage", 0))
	if not stages.has(stage):
		stages[stage] = {"stage": int(stage), "cleared": false, "game_over_reasons": {}, "money_samples": [],
			"rep_tiers": {}, "heat_tiers": {}, "demands": {}, "mortgaged": 0,
			"street": {"entered": 0, "days": 0, "recovered": 0}, "prison": {"arrests": 0, "released": 0},
			"big_fate": {"spins": 0, "segments": {}}, "fate": {"good": 0, "bad": 0, "neutral": 0},
			"hand_counts": {}, "slot_checks": {}, "lot_accuracy": {"correct": 0, "verified": 0},
			"almanac": {"followed": 0, "offered": 0, "actions_followed": 0, "actions_offered": 0}, "steps": 0,
			"stock": _stock_row()}
	return stages[stage]


## Rogue v1 stocktake metrics of one stage. list rows: {offer, from, week, items, deals, picked, kind, replaced}.
static func _stock_row() -> Dictionary:
	return {"offers": 0, "week_offers": 0, "peddler_offers": 0, "week_sizes": {}, "peddler_sizes": {},
		"offered": {}, "picked": {}, "picked_kinds": {"relic": 0, "source": 0}, "passed": 0, "replaced": 0,
		"rejected": 0, "week_deals": {}, "list": []}


func _changed(_topics: PackedStringArray) -> void:
	_view = engine.view()
	var row: Dictionary = _row()
	var phase: String = str(_view.get("phase", ""))
	if phase != "boot" and _view.has("date"):
		row["reached"] = true
	var day: int = int(_view.get("date", {}).get("abs_day", 0))
	var mode: String = str(_view.get("mode", "shop"))
	if mode == "street" and _previous_mode != "street":
		row["street"]["entered"] += 1
	if mode == "shop" and _previous_mode == "street":
		row["street"]["recovered"] += 1
	_previous_mode = mode
	if phase == "year_jump":
		row["cleared"] = true
	var month_finished: bool = phase == "year_jump" or (phase == "game_over"
		and str(_view.get("game_over_reason", "")) == "ending")
	if month_finished and not row.has("month_money"):
		row["month_money"] = int(_view.get("money", {}).get("amount", 0))
	var key: String = str(row["stage"]) + ":" + str(day)
	if phase == "day" and not _hand_days_seen.has(key):
		_hand_days_seen[key] = true
		_add(row["hand_counts"], str(_view.get("hand", []).size()))
	if phase == "settle" and not _days_seen.has(key):
		_days_seen[key] = true
		_add(row["rep_tiers"], str(_view.get("rep_tier", 0)))
		_add(row["heat_tiers"], str(_view.get("heat_tier", 0)))
		(row["money_samples"] as Array).append(int(_view.get("money", {}).get("amount", 0)))
		_stock_week(row)
		if mode == "street":
			row["street"]["days"] += 1
		var alm: Dictionary = engine.query(&"almanac")
		var followed: bool = false
		var taboo: bool = false
		for action in alm.get("yi", []):
			row["almanac"]["actions_offered"] += 1
			if alm.get("done", []).has(action):
				row["almanac"]["actions_followed"] += 1
				followed = true
		for action in alm.get("ji", []):
			taboo = taboo or alm.get("done", []).has(action)
		if not alm.get("yi", []).is_empty():
			row["almanac"]["offered"] += 1
			row["almanac"]["followed"] += 1 if followed and not taboo else 0
	if phase in ["morning", "month_close"] and day in [10, 20, 30] \
			and not hashes.any(func(h: Dictionary) -> bool: return int(h["abs_day"]) == day):
		hashes.append({"abs_day": day, "hash": CardAutoplay._hash(engine)})


func _command(cmd: StringName, args: Dictionary, ok: bool) -> void:
	var row: Dictionary = _row()
	row["steps"] += 1
	if cmd == &"stock.pick":
		_stock_pick(args, ok)
	elif ok and cmd in [&"game.new", &"game.load", &"game.retry_stage"]:
		_offers_seen = {}    # offer ids restart with the timeline; a replayed week is a new offer
	if ok and (cmd == &"estate.mortgage" or (cmd == &"short.resolve" and str(args.get("by", "")) == "estate")):
		row["mortgaged"] += 1
	if ok and cmd == &"demand.delay":
		var card: Dictionary = engine.query(&"card", {"uid": args.get("uid", "")})
		if card.has("card"):
			card = card["card"]
		var key: String = _demand_key(card)
		if not row["demands"].has(key):
			row["demands"][key] = {"completed": 0, "delayed": 0, "failed": 0}
		row["demands"][key]["delayed"] += 1


func _left(uid: String, reason: StringName) -> void:
	var card: Dictionary = engine.query(&"card", {"uid": uid})
	if card.has("card"):
		card = card["card"]
	var row: Dictionary = _row()
	if str(card.get("type", "")) == "prison" and _last_terminal != "prison":
		row["prison"]["released"] += 1
	if str(card.get("type", "")) == "demand":
		var key: String = _demand_key(card)
		if not row["demands"].has(key):
			row["demands"][key] = {"completed": 0, "delayed": 0, "failed": 0}
		var outcome: String = "failed" if reason in [&"expired", &"left"] else "completed"
		row["demands"][key][outcome] += 1


func _demand_key(card: Dictionary) -> String:
	var definition: Dictionary = catalog.def(str(card.get("def", "")))
	var demand: Dictionary = card.get("demand", {})
	return str(demand.get("kind", definition.get("kind", "unknown"))) + ":" \
		+ str(demand.get("tier", definition.get("tier", 0)))


func _dealt(uids: PackedStringArray) -> void:
	for uid in uids:
		var card: Dictionary = engine.query(&"card", {"uid": uid})
		if card.has("card"):
			card = card["card"]
		if str(card.get("type", "")) == "fate":
			var valence: String = str(catalog.def(str(card.get("def", ""))).get("valence", "neutral"))
			if not valence in ["good", "bad"]:
				valence = "neutral"
			_row()["fate"][valence] += 1


func _coins(_uid: String, faces: Array, need: int, success: bool) -> void:
	var checks: Dictionary = _row()["slot_checks"]
	var key: String = str(faces.size() - need)
	if not checks.has(key):
		checks[key] = {"success": 0, "total": 0}
	checks[key]["total"] += 1
	checks[key]["success"] += 1 if success else 0


func _wheel(wheel_id: String, segment_id: String, _stop: float) -> void:
	if wheel_id == "wh.big":
		var big: Dictionary = _row()["big_fate"]
		big["spins"] += 1
		_add(big["segments"], str(catalog.def(segment_id).get("valence", "neutral")))


func _panel(kind: StringName, args: Dictionary) -> void:
	if kind == &"prison":
		_row()["prison"]["arrests"] += 1
	elif kind == &"stocktake":
		_stock_offer(str(args.get("offer", "")))


## A stocktake overlay was requested: count the offer once (a re-request of the same open offer is not a new one).
func _stock_offer(offer_id: String) -> void:
	var offer: Dictionary = engine.query(&"stocktake", {"offer": offer_id} if offer_id != "" else {})
	if not bool(offer.get("ok", false)):
		return
	offer_id = str(offer.get("offer", offer_id))
	if offer_id == "" or _offers_seen.has(offer_id):
		return
	var row: Dictionary = _row()
	var stock: Dictionary = row["stock"]
	var items: Array = offer.get("items", [])
	var from: String = str(offer.get("from", ""))
	var kinds: Dictionary = {}
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			kinds[str(item.get("id", ""))] = str(item.get("kind", ""))
			_add(stock["offered"], str(item.get("id", "")))
	stock["offers"] += 1
	if from == "peddler":
		stock["peddler_offers"] += 1
		_add(stock["peddler_sizes"], str(items.size()))
	else:
		stock["week_offers"] += 1
		_add(stock["week_sizes"], str(items.size()))
	(stock["list"] as Array).append({"offer": offer_id, "from": from, "week": int(offer.get("week", -1)),
		"items": items.size(), "deals": int(offer.get("deals", 0)), "picked": "", "kind": "", "replaced": false})
	_offers_seen[offer_id] = {"stage": str(row["stage"]), "kinds": kinds, "row": (stock["list"] as Array).size() - 1}


## stock.pick finished (command_done carries only the visible args and ok).
func _stock_pick(args: Dictionary, ok: bool) -> void:
	var offer_id: String = str(args.get("offer", ""))
	var seen: Dictionary = _offers_seen.get(offer_id, {})
	var stage: String = str(seen.get("stage", ""))
	var stock: Dictionary = stages[stage]["stock"] if stages.has(stage) else _row()["stock"]
	if not ok:
		stock["rejected"] += 1
		return
	var pick: String = str(args.get("pick", ""))
	var replaced: bool = str(args.get("replace", "")) != ""
	var kind: String = str(seen.get("kinds", {}).get(pick, ""))
	if pick == "":
		stock["passed"] += 1
	else:
		_add(stock["picked"], pick)
		if kind in ["relic", "source"]:
			stock["picked_kinds"][kind] += 1
	if replaced:
		stock["replaced"] += 1
	var index: int = int(seen.get("row", -1))
	if index >= 0 and index < (stock["list"] as Array).size():
		stock["list"][index]["picked"] = pick
		stock["list"][index]["kind"] = kind
		stock["list"][index]["replaced"] = replaced


## Weekly deals at the settle of each stocktake day, from the visible view.stock.week_deals (module enabled only).
func _stock_week(row: Dictionary) -> void:
	var stock_view: Variant = _view.get("stock", {})
	if typeof(stock_view) != TYPE_DICTIONARY or not (stock_view as Dictionary).has("week_deals"):
		return
	var days: Array = WEEK_DAYS
	if catalog != null:
		days = catalog.rules("stock").get("week_days", WEEK_DAYS)
	var stage_day: int = int(_view.get("date", {}).get("stage_day", 0))
	for day in days:
		if int(day) == stage_day:
			row["stock"]["week_deals"][str(stage_day / 7 - 1)] = int(stock_view["week_deals"])
			return


func _over(reason: StringName) -> void:
	_last_terminal = str(reason)
	if reason == &"ending":
		_row()["cleared"] = true
	else:
		_add(_row()["game_over_reasons"], str(reason))


func _add(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1
