# K17（合同 1.4，§九.7 官场开头）：1940 金色牌“请你当保长”。
# 数据形状 + 走一遍每个选项与打烊没理，核对给后续官场线、1945 肃奸埋下的旗标；第一次发到手上记 first office。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/G03/test_support.gd")
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
const FILE := "res://data/cards/era/1940/officialdom.json"
const ID := "p.ma.1940.baozhang"
const NODE := "s1940.baozhang"
# 选项 → 必须设的旗标、肃奸记号
const WANT := {
	"take": {"flags": {"office_post": "baozhang", "office_baozhang_take": true}, "marks": 2},
	"nominal": {"flags": {"office_post": "baozhang", "office_baozhang_nominal": true, "office_shield_neighbors": true}, "marks": 1},
	"buy_off": {"flags": {"office_baozhang_buy_off": true}, "marks": 0},
	"refuse": {"flags": {"office_baozhang_refuse": true, "office_foe_ma": true}, "marks": 0},
}


func _initialize() -> void:
	var t := T.new(self, "K17_baozhang")
	var doc = CardState.int_restore(CardDB.read_json(FILE))
	t.ok(typeof(doc) == TYPE_DICTIONARY, "parse officialdom.json")
	t.eq(str(doc.get("_meta", {}).get("owner", "")), "K17", "owner K17")
	var defs := {}
	for c in doc.get("cards", []):
		defs[str(c["id"])] = c
		t.eq(str(c.get("_provenance", {}).get("task", "")), "K17", str(c["id"]) + " provenance")
		_no_text_keys(t, c, str(c["id"]))
	var card: Dictionary = defs.get(ID, {})
	t.ok(not card.is_empty(), "gold card exists")
	t.ok(bool(card.get("gold", false)), "gold")
	t.eq(str(card.get("type", "")), "person", "person card")
	t.eq(str(card.get("story_node", "")), NODE, "story node")
	t.eq(int(card.get("weight", -1)), 0, "weight zero (scheduled only)")
	t.ok((card.get("tags", []) as Array).has("office"), "office tag → first office")
	var day := int(card.get("schedule", {}).get("stage_day", 0))
	t.ok(day >= 1 and day <= 30, "stage_day in 1940 stage")
	# 和 1940 其他金色牌不撞同一天
	var story = CardState.int_restore(CardDB.read_json("res://data/cards/era/1940/story.json"))
	for c2 in story.get("cards", []):
		if bool(c2.get("gold", false)):
			t.ok(int(c2.get("schedule", {}).get("stage_day", 0)) != day, "no other gold on day %d: %s" % [day, c2["id"]])
	var ids: Array = []
	for ch in card.get("choices", []):
		ids.append(str(ch["id"]))
		t.ok(not JSON.stringify(ch).contains("game_over"), ch["id"] + " no game_over")
		t.ok(not JSON.stringify(ch).contains("\"check\""), ch["id"] + " no check, choice always resolves")
	ids.sort()
	t.eq(ids, ["buy_off", "nominal", "refuse", "take"], "four outcomes")

	for choice in WANT.keys():
		var e := S.engine()
		var ctx := e.ctx
		for id in defs.keys():
			if id != ID: S.card(ctx, id, (defs[id] as Dictionary).duplicate(true), &"discard")
		var uid := S.card(ctx, ID, card.duplicate(true), &"hand")
		ctx.hooks.fire(ctx, &"deal_composed", {"uids": [uid]})
		t.ok(CardFirsts.all(ctx).has("office"), choice + ": first office on deal")
		var res: Dictionary = CardChoices.choose(ctx, uid, choice)
		t.ok(str(res.get("err", "")) == "", choice + ": choose ok " + JSON.stringify(res))
		var r := H.peek(ctx)
		var flags: Dictionary = r.get("flags", {})
		t.eq(str(flags.get("story." + NODE, "")), choice, choice + ": story flag")
		var want: Dictionary = WANT[choice]
		for k in want["flags"].keys():
			t.eq(flags.get(k), want["flags"][k], choice + ": flag " + k)
		t.eq(int(r.get("counters", {}).get("sujian_marks", 0)), int(want["marks"]), choice + ": sujian_marks")
		if choice == "buy_off":
			t.eq(int(r.get("test_money", 0)), 440, "buy_off: paid 60")

	# 打烊没理：走 on_expire
	var e2 := S.engine()
	var ctx2 := e2.ctx
	for id in defs.keys():
		S.card(ctx2, id, (defs[id] as Dictionary).duplicate(true), &"discard")
	ctx2.ops.run(ctx2, card["effects"]["on_expire"], "K17:expire")
	var f2: Dictionary = H.peek(ctx2).get("flags", {})
	t.eq(str(f2.get("story." + NODE, "")), "ignored", "ignored: story flag")
	t.ok(bool(f2.get("office_baozhang_ignored", false)), "ignored: flag")
	t.ok(not f2.has("office_post"), "ignored: no post")
	t.finish()


func _no_text_keys(t, v, where: String) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		for k in v.keys():
			t.ok(not (str(k) in ["text", "title", "body", "label", "name", "lines", "desc"]), where + " no text key " + str(k))
			_no_text_keys(t, v[k], where)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_no_text_keys(t, x, where)
