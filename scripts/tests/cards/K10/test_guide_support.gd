# K10 指引验收：1938 本月运势香案加宽、春季黄历柜台动作、签的征兆、大赌引用报告。
# 角度用整数权重算到最后一步：w 全程是整数；合计角度之比用 360 约掉后的分数比较。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const COUNTER: Array[String] = ["pawn_in", "buy_in", "sell_out", "trade", "redeem"]


func _initialize() -> void:
	var t := T.new(self, "K10_guide_support")
	var db := CardDB.load_all()
	t.eq(db.errors(), PackedStringArray(), "CardDB load")
	_widen(t, db)
	_spring(t, db)
	_omens(t, db)
	_bigfate_report(db)
	t.finish()


# U=0 与 U=max_units 时，好段合计角度之比 >= 3/2；U 从 0 到 max_units 单调不减。
func _widen(t, db: CardDB) -> void:
	var wheel := db.def("wh.month")
	var inc: Dictionary = wheel.get("incense", {})
	var pct := int(inc.get("unit_widen_pct", 0))
	var max_units := int(inc.get("max_units", 0))
	t.ok(pct > 0 and max_units > 0, "month incense widen fields")
	var segs := _month_1938(db)
	t.ok(not segs.is_empty(), "1938 month segments")
	var base := _weights(segs, 0, pct)
	var prev_good := int(base[0])
	var prev_total := int(base[1])
	t.ok(prev_good > 0 and prev_total > 0, "U=0 good weight")
	var prev_mdeg := _good_mdeg(segs, 0, pct)
	t.ok(prev_mdeg > 0, "U=0 good millidegree")
	for u in range(1, max_units + 1):
		var now := _weights(segs, u, pct)
		var good := int(now[0])
		var total := int(now[1])
		# good/total 不减，交叉相乘避开小数。
		t.ok(good * prev_total >= prev_good * total, "monotonic share U=%d" % u)
		var mdeg := _good_mdeg(segs, u, pct)
		t.ok(mdeg >= prev_mdeg, "monotonic millidegree U=%d" % u)
		prev_good = good
		prev_total = total
		prev_mdeg = mdeg
	var top := _weights(segs, max_units, pct)
	# (good_max / total_max) / (good_0 / total_0) >= 3/2
	t.ok(2 * int(top[0]) * int(base[1]) >= 3 * int(base[0]) * int(top[1]), "good angle ratio >= 1.5")
	var top_mdeg := _good_mdeg(segs, max_units, pct)
	t.ok(float(top_mdeg) / float(_good_mdeg(segs, 0, pct)) >= 1.5, "millidegree ratio >= 1.5")


func _spring(t, db: CardDB) -> void:
	var spring: Array = []
	for id in db.ids_of(&"almanac_day"):
		var c := db.def(str(id))
		if (c.get("season", []) as Array).has(0):
			spring.append(c)
	t.ok(spring.size() >= 6, "spring almanac %d" % spring.size())
	var hit := 0
	for c in spring:
		for a in c.get("yi", []):
			if COUNTER.has(str(a)):
				hit += 1
				break
	t.ok(hit * 2 >= spring.size(), "spring counter actions %d/%d" % [hit, spring.size()])


func _omens(t, db: CardDB) -> void:
	var omens := {}
	for k in db.tags().keys():
		if str(k).begins_with("omen_"):
			omens[str(k)] = true
	t.ok(omens.size() >= 10, "closed omen family loaded")
	for grade in range(0, 5):
		var generic := false
		for id in db.ids_of(&"fortune_lot"):
			var c := db.def(str(id))
			if int(c.get("grade", -1)) != grade:
				continue
			var tags: Array = c.get("hint_tags", [])
			if tags.is_empty():
				generic = true
			for tag in tags:
				t.ok(omens.has(str(tag)), str(id) + " uses " + str(tag))
		t.ok(generic, "grade %d has a generic lot" % grade)
	for id in db.ids_of(&"cezi"):
		var tags: Array = db.def(str(id)).get("tags", [])
		t.ok(not tags.is_empty(), str(id) + " tags")
		for tag in tags:
			t.ok(omens.has(str(tag)), str(id) + " uses " + str(tag))


# 真数据里没被 wh.big 引用的大赌、以及扇区 add_card 指向不存在的牌：只打印，不断言。
func _bigfate_report(db: CardDB) -> void:
	var referenced := {}
	var dangling := {}
	for id in db.ids_of(&"wheel_segment"):
		var c := db.def(str(id))
		var effects: Array = c.get("effects", [])
		for e in effects:
			if typeof(e) != TYPE_DICTIONARY or str(e.get("op", "")) != "add_card":
				continue
			var card := str(e.get("card", ""))
			if str(c.get("wheel", "")) == "wh.big":
				referenced[card] = true
			if card != "" and not db.has(card):
				dangling[card] = true
	for id in db.ids_of(&"big_fate"):
		if str(id) == "bf.wheel":
			continue
		if not referenced.has(str(id)):
			print("NOTE: bigfate_unreferenced %s" % id)
	var keys: Array = dangling.keys()
	keys.sort()
	for card in keys:
		print("NOTE: dangling %s" % card)


func _month_1938(db: CardDB) -> Array:
	var out: Array = []
	for id in db.ids_of(&"wheel_segment"):
		var c := db.def(str(id))
		if str(c.get("wheel", "")) != "wh.month":
			continue
		var era: Array = c.get("era", [])
		if era.has("1938") or era.has("*"):
			out.append(c)
	return out


# [good_w, total_w]，全是整数。good：w = arc * (100 + U * unit_widen_pct)，其余 w = arc * 100。
func _weights(segs: Array, units: int, pct: int) -> Array:
	var good := 0
	var total := 0
	for s in segs:
		var arc := int(s.get("arc", 0))
		var w := arc * 100
		if str(s.get("valence", "")) == "good":
			w = arc * (100 + units * pct)
			good += w
		total += w
	return [good, total]


# 每段 arc_mdeg = 360000 * w / Σw（整数除法），好段相加。最后一步才拿去比。
func _good_mdeg(segs: Array, units: int, pct: int) -> int:
	var weights: Array = []
	var total := 0
	for s in segs:
		var arc := int(s.get("arc", 0))
		var w := arc * (100 + units * pct) if str(s.get("valence", "")) == "good" else arc * 100
		weights.append(w)
		total += w
	var good := 0
	for i in weights.size():
		if str(segs[i].get("valence", "")) != "good":
			continue
		good += int(360000 * int(weights[i]) / total)
	return good
