# K06 新手指引能挂上的数据：春冬生活牌、几天内处理、回家吃饭能免、钱不够阶梯、期限、开场目标。
# 合同：docs/cards/CARDS_INTERFACES.md §7.10；任务卡 docs/handoff_cards/K06_data-1940-world.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K06_guide_support")
	var doc: Dictionary = CardState.int_restore(CardDB.read_json("res://data/cards/era/common/life.json"))
	var cards: Array = doc.get("cards", [])
	var spring := 0
	var winter := 0
	var waivable := 0
	var ladder := 0
	for raw in cards:
		var c: Dictionary = raw
		var season: Array = c.get("season", [])
		if season.has(0):
			spring += 1
		if season.has(3):
			winter += 1
		var due = c.get("due_days")
		t.ok(typeof(due) == TYPE_INT and int(due) > 0, "due_days " + str(c.get("id", "")))
		if bool(c.get("waivable", false)):
			waivable += 1
		if _has_ladder(c):
			ladder += 1
		t.ok(_expire_ok(c), "on_expire " + str(c.get("id", "")))
	t.ok(spring >= 6, "spring seasons %d" % spring)
	t.ok(winter >= 4, "winter seasons %d" % winter)
	t.ok(cards.size() > 0 and waivable * 2 >= cards.size(), "waivable %d/%d" % [waivable, cards.size()])
	t.ok(ladder >= 4, "ladder pay cards %d" % ladder)
	var stage: Dictionary = CardState.int_restore(CardDB.read_json("res://data/cards/era/1940/stage.json"))
	var goals: Dictionary = CardState.int_restore(CardDB.read_json("res://data/cards/era/1940/goals.json"))
	var main_id := str(stage.get("main_goal", ""))
	var main_ok := false
	for raw2 in goals.get("cards", []):
		var g: Dictionary = raw2
		if str(g.get("id", "")) == main_id and bool(g.get("main", false)):
			main_ok = true
	t.ok(main_ok, "stage main_goal is a main goal")
	t.eq(str(stage.get("bg", "")), "bg.stage.1940", "stage bg")
	t.finish()


func _expire_ok(c: Dictionary) -> bool:
	var fx = c.get("effects", {})
	if typeof(fx) != TYPE_DICTIONARY:
		return false
	var ex = fx.get("on_expire", [])
	return typeof(ex) == TYPE_ARRAY and not (ex as Array).is_empty()


func _has_ladder(c: Dictionary) -> bool:
	var found := [false]
	_walk(c, found)
	return bool(found[0])


func _walk(v, found: Array) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if str(v.get("op", "")) == "pay" and str(v.get("short", "")) == "ladder":
			found[0] = true
		for k in v.keys():
			_walk(v[k], found)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_walk(x, found)
