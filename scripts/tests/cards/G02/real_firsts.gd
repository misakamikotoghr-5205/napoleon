# 完整模块的前三天固定指令验收；例子数据加自己的教学日程，不读任何旧正文。
# first 串按日、指令、机制保存，布局 seed 仅在明确的小游戏参数路径豁免黑名单。
extends RefCounted

const H = preload("res://scripts/tests/cards/G02/helpers.gd")
const GAME_SEED := 7

static func run(t: RefCounted, update: bool = false) -> void:
	var first := _play(t, false)
	var second := _play(t, true)
	t.eq(first["log"], second["log"], "same seed first chain reproducible")
	t.eq(first["hash"], second["hash"], "guide toggle never changes state hash")
	var expected := {"0": ["month_open", "month_wheel", "incense"],
		"1": ["notice", "deal", "person", "counter", "mg.spot", "ticket", "shelf", "buyer", "night", "settle"],
		"2": ["gold", "choice", "keep"], "3": ["slots", "coins"]}
	for day in expected.keys():
		for mechanism in expected[day]:
			t.ok((first["days"].get(day, []) as Array).has(mechanism), "day%s mechanism %s" % [day, mechanism])
	var path := "res://scripts/tests/cards/G02/golden/firsts_d1_3.json"
	if update:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		H._write(path, JSON.stringify(first["log"], "\t", true, true) + "\n")
	else:
		t.eq(first["log"], CardState.int_restore(CardDB.read_json(path)), "frozen full first chain")
	_gold_resume(t)
	print("G02 REAL FIRSTS " + JSON.stringify(first["days"], "", true))

static func _play(t: RefCounted, guides: bool) -> Dictionary:
	var data_root := _data(t)
	var bus := CardEventBus.new()
	var e := CardEngine.new(bus)
	var spy = t.spy(bus)
	var log: Array = []
	var current: Array = ["game.new"]
	bus.first_time.connect(func(mechanism: StringName, args: Dictionary) -> void:
		log.append([int(e.view().get("date", {}).get("abs_day", 0)), str(current[0]), str(mechanism), args]))
	_send(t, e, current, &"game.new", {"seed": GAME_SEED, "data_root": data_root, "save_dir": t.user_dir() + "/real"})
	_send(t, e, current, &"wheel.offer", {"wheel": "wh.month", "uid": "", "source": {"kind": "money", "amount": 1}})
	_send(t, e, current, &"wheel.spin", {"wheel": "wh.month", "uid": ""})
	_send(t, e, current, &"month.begin")
	_send(t, e, current, &"day.begin")
	_counter(t, e, current, "p.g02.d1.pawn", true)
	_counter(t, e, current, "p.g02.d1.sell", false)
	_counter(t, e, current, "p.g02.d1.buy", false)
	_night(t, e, current)
	_send(t, e, current, &"settle.next")
	_send(t, e, current, &"day.begin")
	var gold := _uid(e, "p.brother.1938.farewell")
	_send(t, e, current, &"card.choose", {"uid": gold, "choice": "listen"})
	var note := _uid(e, "kp.brother_note")
	if note != "" and str(e.query(&"card", {"uid": note}).get("zone", "")) == "hand":
		_send(t, e, current, &"card.keep", {"uid": note})
	_night(t, e, current)
	_send(t, e, current, &"settle.next")
	_send(t, e, current, &"day.begin")
	var event := _uid(e, "ev.g02.d3.slots")
	_send(t, e, current, &"slot.place", {"uid": event, "slot": "self", "source": {"kind": "self"}})
	_send(t, e, current, &"slot.roll", {"uid": event})
	_night(t, e, current)
	if guides:
		_send(t, e, current, &"ui.guide", {"step": "gd.d1.deal", "status": "shown"})
	var days: Dictionary = {}
	for row in log:
		var day := str(row[0])
		if not days.has(day): days[day] = []
		days[day].append(row[2])
	var exempt := 0
	for ev in spy.log: exempt += _event_leaks(t, ev, GAME_SEED)
	t.ok(exempt > 0, "layout seed exemption exercised by the spot minigame")
	var result := {"hash": e.state_hash(), "log": log, "days": days}
	bus.free()
	return result

static func _counter(t: RefCounted, e: CardEngine, current: Array, id: String, appraise: bool) -> void:
	var uid := _uid(e, id)
	_send(t, e, current, &"counter.open", {"uid": uid})
	var cv := e.query(&"counter", {"uid": uid})
	var item_ref: Variant = cv.get("item")
	var item := str(item_ref.get("item", "")) if typeof(item_ref) == TYPE_DICTIONARY else ""
	if appraise:
		_send(t, e, current, &"mg.request", {"uid": uid, "item": item})
		_send(t, e, current, &"mg.report", {"uid": uid, "item": item, "result": {"quality_permille": 1000, "minutes": 1, "observations": [], "measures": {}, "aborted": false}})
	if id.ends_with("buy"):
		var stock: Array = cv.get("stock", [])
		t.ok(not stock.is_empty(), "teaching buyer has stock")
		if not stock.is_empty():
			var stock_id := str(stock[0]) if typeof(stock[0]) == TYPE_STRING else str(stock[0].get("item", stock[0].get("id", "")))
			_send(t, e, current, &"counter.pick_stock", {"uid": uid, "item": stock_id})
	var r := _send(t, e, current, &"counter.offer", {"uid": uid, "tier": "kind"})
	if str(r.get("reply", "")) == "counter":
		_send(t, e, current, &"counter.answer", {"uid": uid, "accept": true})

static func _night(t: RefCounted, e: CardEngine, current: Array) -> void:
	_send(t, e, current, &"day.end", {"confirm": true})
	var offers: Array = e.view()["night_offers"]
	t.ok(not offers.is_empty(), "night offers exist")
	if offers.is_empty(): return
	var def_id := H.offer_def(offers[0])
	for offer in offers:
		if H.offer_def(offer) == "nt.tidy": def_id = "nt.tidy"
	var args := {"def": def_id}
	for row in offers:
		if H.offer_def(row) == def_id and not row["choices"].is_empty(): args["choice"] = str(row["choices"][0])
	_send(t, e, current, &"night.choose", args)

static func _uid(e: CardEngine, def_id: String) -> String:
	for zone in ["hand", "kept", "contacts", "pending"]:
		for row in e.view().get(zone, []):
			if str(row.get("def", "")) == def_id: return str(row["uid"])
	return ""

static func _send(t: RefCounted, e: CardEngine, current: Array, cmd: StringName, args: Dictionary = {}) -> Dictionary:
	current[0] = str(cmd)
	var result := e.send(cmd, args)
	t.ok(bool(result.get("ok", false)), "real command %s: %s" % [cmd, result.get("err", "")])
	var hash_before := e.state_hash()
	t.no_leaks(e.view(), "real view after %s" % cmd)
	t.eq(e.state_hash(), hash_before, "real view read only")
	t.eq(e.view(), e.view(), "real view stable")
	return result

## 合同 §7.5 的布局种子例外：只放过 minigame_requested 参数里的 params.seed 与 params.marks[i].seed，
## 值必须是整数且不是本局主种子；别处的 seed 和别的隐藏键照算漏。返回放过的路径数。
static func _event_leaks(t: RefCounted, event: Array, game_seed: int) -> int:
	var args: Array = event.slice(1)
	var layout := RegEx.create_from_string("^\\[3\\]\\.(marks\\[(\\d+)\\]\\.)?seed$")
	var bad := PackedStringArray()
	var exempt := 0
	for path in CardViewModel.leaks(args):
		var hit: RegExMatch = layout.search(path) if event[0] == &"minigame_requested" else null
		if hit == null:
			bad.append(path)
			continue
		var holder: Dictionary = args[3] if hit.get_string(2) == "" else args[3]["marks"][int(hit.get_string(2))]
		t.ok(typeof(holder["seed"]) == TYPE_INT and int(holder["seed"]) != game_seed,
			"layout seed %s is an int, not the game seed" % path)
		exempt += 1
	t.ok(bad.is_empty(), "real event %s leaks hidden keys: %s" % [event[0], ", ".join(bad)])
	return exempt

static func _data(t: RefCounted) -> String:
	var root_path: String = t.user_dir() + "/real_data"
	for path in CardDB.list_json_recursive("res://data/cards/_examples"):
		var relative := path.trim_prefix("res://data/cards/_examples/")
		if relative == "tags.json": relative = "tags/examples.json"
		elif relative == "ui_keys.json": relative = "ui_keys/examples.json"
		DirAccess.make_dir_recursive_absolute((root_path + "/" + relative).get_base_dir())
		H._write(root_path + "/" + relative, FileAccess.get_file_as_string(path))
	for path in CardDB.list_json("res://data/cards/rules"):
		DirAccess.make_dir_recursive_absolute(root_path + "/rules")
		H._write(root_path + "/rules/" + path.get_file(), FileAccess.get_file_as_string(path))
	H._write(root_path + "/era/1938/tutorial.json", FileAccess.get_file_as_string("res://scripts/tests/cards/G02/fixtures/tutorial_d1_3.json"))
	return root_path


static func _gold_resume(t: RefCounted) -> void:
	var e := CardEngine.new()
	var current: Array = [""]
	_send(t, e, current, &"game.new", {"seed": 7, "data_root": _data(t), "save_dir": t.user_dir() + "/gold_real"})
	var initial := CardSave.read(CardSave.stage_path(0))
	_send(t, e, current, &"wheel.spin", {"wheel": "wh.month", "uid": ""})
	_send(t, e, current, &"month.begin")
	_send(t, e, current, &"day.begin")
	_night(t, e, current)
	_send(t, e, current, &"settle.next")
	var saved_hash := H.without_resume(e.ctx.state)
	_send(t, e, current, &"day.begin")
	var uid := _uid(e, "p.brother.1938.farewell")
	t.eq(e.send(&"card.keep", {"uid": uid}).get("err"), "not_keepable", "real gold cannot be kept")
	t.eq(e.send(&"day.end").get("err"), "must_resolve_pending", "real gold needs confirmation")
	_send(t, e, current, &"game.load", {"path": CardSave.suspend_path()})
	t.eq(H.without_resume(e.ctx.state), saved_hash, "real resume matches stored morning")
	_send(t, e, current, &"day.begin")
	t.eq(_uid(e, "p.brother.1938.farewell"), uid, "same gold UID after morning replay")
	_send(t, e, current, &"day.end", {"confirm": true})
	t.ok(e.ctx.test({"story": ["s1938.brother_farewell", "ignored"]}), "unhandled gold story goes ignored")
	var dossier := e.query(&"dossier", {"person": "brother"})
	var gaps: Array = []
	for page in dossier.get("pages", []):
		for frag in page.get("fragments", []):
			if str(frag.get("state", "")) == "gap": gaps.append(str(frag["id"]))
	t.ok(gaps.has("df.brother.1938.farewell"), "unhandled gold leaves permanent dossier gap")
	var offers: Array = e.view()["night_offers"]
	var def_id := H.offer_def(offers[0])
	for offer in offers:
		if H.offer_def(offer) == "nt.tidy": def_id = "nt.tidy"
	var args := {"def": def_id}
	for row in offers:
		if H.offer_def(row) == def_id and not row["choices"].is_empty(): args["choice"] = str(row["choices"][0])
	_send(t, e, current, &"night.choose", args)
	_send(t, e, current, &"settle.next")
	t.eq(_uid(e, "p.brother.1938.farewell"), "", "gold gone next morning")
	t.ok(e.ctx.test({"story": ["s1938.brother_farewell", "ignored"]}), "story persists next morning")
	_send(t, e, current, &"game.retry_stage")
	t.eq(H.without_resume(e.ctx.state), H.without_resume(initial["state"]), "real retry equals stage snapshot")

