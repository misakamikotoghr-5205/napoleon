# 生成 W0 的十个基础夹具（scripts/cards/mock/fixtures/*.json）：用 Mock 情景模式走到那一刻，存下视图、那一刻能问的查询、
# 几条常用指令的回应（结果、事件、视图补丁）。day_counter 的金簪找不同布局由真 ItemGen 生成（§7.7）。
# 用法：$GODOT --headless --path . -s res://scripts/cards/mock/build_fixtures.gd            重新生成
#       $GODOT --headless --path . -s res://scripts/cards/mock/build_fixtures.gd -- --check  只比对（W0 测试清单里跑）
# 主人 W0（Claude）。合同：docs/cards/CARDS_INTERFACES.md §7.7、附录 A 第 5 项。
extends SceneTree

const Scenario = preload("res://scripts/cards/mock/mock_scenario.gd")
const OUT_DIR := "res://scripts/cards/mock/fixtures"
const SEED := 7
const BRIEFS := "res://scripts/cards/mock/fixture_briefs.json"
const SPIN := [["wheel.offer", {"wheel": "wh.month", "uid": "", "source": {"kind": "money", "amount": 10}}],
	["wheel.spin", {"wheel": "wh.month", "uid": ""}]]
const DAY1 := [["day.begin", {}], ["counter.open", {"uid": "c0002"}], ["counter.offer", {"uid": "c0002", "tier": "fair"}],
	["counter.open", {"uid": "c0003"}], ["counter.offer", {"uid": "c0003", "tier": "fair"}],
	["counter.open", {"uid": "c0004"}], ["counter.pick_stock", {"uid": "c0004", "item": "I002"}],
	["counter.offer", {"uid": "c0004", "tier": "fair"}], ["day.end", {"confirm": false}]]

## 名字 → [走到那一刻的步骤, 那一刻要录的回应 [cmd, args], …]；每个夹具的说明（中文）在 fixture_briefs.json（.gd 里不写中文）
## 每个夹具都录 day.end 的 confirm 真、假各一条（打烊 · 下一天在任何阶段都往前走，§7.4.7；牌桌按钮先发 confirm:false），
## 查询里都有 day.end_preview。
var FIXTURES := {
	"month_open": [[],
		[["wheel.offer", {"wheel": "wh.month", "uid": "", "source": {"kind": "money", "amount": 10}}],
		 ["wheel.spin", {"wheel": "wh.month", "uid": ""}], ["month.begin", {}], ["day.end", {"confirm": false}],
		 ["day.end", {"confirm": true}]]],
	"month_wheel": [[SPIN[0]],
		[["wheel.spin", {"wheel": "wh.month", "uid": ""}], ["wheel.withdraw", {"wheel": "wh.month", "uid": "", "index": 0}],
		 ["day.end", {"confirm": false}], ["day.end", {"confirm": true}]]],
	"morning": [SPIN + [["month.begin", {}]], [["day.begin", {}], ["day.end", {"confirm": false}],
		["day.end", {"confirm": true}]]],
	"day_full": [[["@setup_day_full", {}]],
		[["counter.open", {"uid": "c0005"}], ["card.keep", {"uid": "c0010"}], ["card.choose", {"uid": "c0002", "choice": "listen"}],
		 ["day.end", {"confirm": false}], ["day.end", {"confirm": true}], ["card.read", {"uid": "c0010"}]]],
	"day_counter": [SPIN + [["month.begin", {}], ["day.begin", {}], ["counter.open", {"uid": "c0002"}]],
		[["mg.request", {"uid": "c0002", "item": "I001"}], ["counter.offer", {"uid": "c0002", "tier": "fair"}],
		 ["counter.offer", {"uid": "c0002", "tier": "harsh"}], ["counter.offer", {"uid": "c0002", "tier": "kind"}],
		 ["counter.refuse", {"uid": "c0002"}], ["counter.close", {"uid": "c0002"}], ["day.end", {"confirm": false}],
		 ["day.end", {"confirm": true}]]],
	"night": [SPIN + [["month.begin", {}]] + DAY1,
		[["night.choose", {"def": "nt.tidy"}], ["night.choose", {"def": "nt.family_dinner", "choice": "family_word"}],
		 ["night.choose", {"def": "nt.early_sleep"}], ["night.choose", {"def": ""}], ["day.end", {"confirm": false}],
		 ["day.end", {"confirm": true}]]],
	"settle": [SPIN + [["month.begin", {}]] + DAY1 + [["night.choose", {"def": "nt.tidy"}]],
		[["settle.next", {}], ["day.end", {"confirm": false}], ["day.end", {"confirm": true}]]],
	"month_close": [[["@setup_month_close", {}]],
		[["month.next", {}], ["day.end", {"confirm": false}], ["day.end", {"confirm": true}]]],
	"year_jump": [[["@setup_year_jump", {}]],
		[["year.next", {}], ["day.end", {"confirm": false}], ["day.end", {"confirm": true}]]],
	"street_prison": [[["@setup_street_prison", {}]],
		[["slot.place", {"uid": "c0015", "slot": "bribe", "source": {"kind": "money", "amount": 40}}],
		 ["slot.place", {"uid": "c0015", "slot": "bail", "source": {"kind": "contact", "uid": "c0013"}}],
		 ["slot.roll", {"uid": "c0015"}], ["day.end", {"confirm": false}], ["day.end", {"confirm": true}]]],
}

var _db: CardDB


func _initialize() -> void:
	var check := OS.get_cmdline_user_args().has("--check")
	_db = CardDB.load_all(CardDB.DEFAULT_ROOT, {"only_examples": true})
	CardText.setup(_db)
	var bad := PackedStringArray()
	var names: Array = FIXTURES.keys()
	names.sort()
	for name in names:
		var fx := build(str(name))
		var text := JSON.stringify(fx, "  ", true) + "\n"
		var path := "%s/%s.json" % [OUT_DIR, name]
		if check:
			var have := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
			if have != text:
				bad.append(str(name))
		else:
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(text)
			f.close()
			print("wrote ", path)
	CardText.setup(null)
	_db = null
	if check:
		if bad.is_empty():
			print("CARDS TEST PASS W0_fixtures_up_to_date")
			quit(0)
		else:
			print("FAIL: fixtures out of date (run build_fixtures.gd): " + ", ".join(bad))
			quit(1)
	else:
		quit(0)


func build(name: String) -> Dictionary:
	var spec: Array = [_brief(name)] + FIXTURES[name]
	var scn = _replay(spec[1])
	var view: Dictionary = scn.view()
	var fx := {"_meta": {"owner": "W0", "schema": 1, "brief": spec[0], "_provenance": "ai_placeholder",
		"generated_by": "res://scripts/cards/mock/build_fixtures.gd"}, "view": view, "queries": _queries(scn, view),
		"guide_progress": {}, "responses": []}
	for row in spec[2]:
		var probe = _replay(spec[1])
		var before: Dictionary = probe.view()
		var result: Dictionary = probe.send(str(row[0]), row[1])
		var after: Dictionary = probe.view()
		var patch: Array = []
		var keys: Array = after.keys()
		keys.sort()
		for k in keys:
			if JSON.stringify(before.get(k)) != JSON.stringify(after[k]):
				patch.append({"op": "set", "path": k, "value": after[k]})
		(fx["responses"] as Array).append({"cmd": row[0], "match": row[1], "result": result, "patch": patch,
			"events": _json_events(probe.events)})
	(fx["responses"] as Array).append({"cmd": "*", "result": {"ok": true, "err": ""}})
	return fx


func _brief(name: String) -> String:
	var d = CardDB.read_json(BRIEFS)
	return str(d.get("briefs", {}).get(name, {}).get("brief", "")) if typeof(d) == TYPE_DICTIONARY else ""


func _replay(steps: Array):
	var scn = Scenario.new(_db, {"seed": SEED})
	scn.start()
	for s in steps:
		var cmd := str(s[0])
		if cmd.begins_with("@"):
			scn.call(cmd.substr(1))
		else:
			var r: Dictionary = scn.send(cmd, s[1])
			if not bool(r.get("ok", false)) and cmd != "day.end":
				push_error("build_fixtures: step %s %s failed: %s" % [cmd, s[1], r])
	scn.events = []
	return scn


## 那一刻能问的查询（键的写法见 MockCardEngine.query_key）
func _queries(scn, view: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for q in ["firsts", "stock", "tickets", "estates", "almanac", "dossier", "settle_report", "month_report",
			"year_report", "short", "day.end_preview"]:
		out[MockCardEngine.query_key(StringName(q), {})] = scn.query(q, {})
	var wa := {"uid": "", "wheel": "wh.month"}
	out[MockCardEngine.query_key(&"wheel", wa)] = scn.query("wheel", wa)
	for z in ["hand", "kept", "contacts", "pending", "demands"]:
		for c in view.get(z, []):
			var a := {"uid": str(c["uid"])}
			out[MockCardEngine.query_key(&"card", a)] = scn.query("card", a)
			out[MockCardEngine.query_key(&"actions", a)] = scn.query("actions", a)
			match str(c.get("panel", "")):
				"slots", "prison", "demand", "read":
					out[MockCardEngine.query_key(&"slots", a)] = scn.query("slots", a)
				"counter":
					var cv: Dictionary = scn.query("counter", a)
					if bool(cv.get("ok", true)):
						out[MockCardEngine.query_key(&"counter", a)] = cv
				"fortune":
					out[MockCardEngine.query_key(&"fortune", a)] = scn.query("fortune", a)
				"wheel":
					var wd := _db.def(str(c["def"]))
					var wid := str(wd.get("opens_wheel", "wh.fair"))
					var wa2 := {"uid": str(c["uid"]), "wheel": wid}
					out[MockCardEngine.query_key(&"wheel", wa2)] = scn.query("wheel", wa2)
	return out


func _json_events(events: Array) -> Array:
	var out: Array = []
	for ev in events:
		var row: Array = []
		for x in ev:
			row.append(Array(x) if typeof(x) == TYPE_PACKED_STRING_ARRAY else (str(x) if typeof(x) == TYPE_STRING_NAME else x))
		out.append(row)
	return out
