# K07 指引支撑：1938 四张小档温和，要人/要消息/要钱的办法齐，回来事件在。
# 主人 K07。任务卡 docs/handoff_cards/K07_data-demand.md 新手指引验收。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
# 起步钱 340 的大约一成。任务卡要求把这个上限写成常量，并在 PR 里说明。
const MILD_MONEY_CAP := 40
## 归属表 K07：data/cards/demand/**。CardDB.file_of 是相对数据根的路径。
const OWN_PREFIX := "demand/"


func _initialize() -> void:
	var t := T.new(self, "K07_guide_support")
	var db := CardDB.load_all("res://data/cards")
	var errs := PackedStringArray()
	for e in db.errors():
		var s := str(e)
		if s.begins_with(OWN_PREFIX):
			errs.append(s)
	errs.append_array(_mild_errors(db))
	errs.append_array(_method_errors(db))
	errs.append_array(_return_errors(db))
	if errs.is_empty():
		t.ok(true, "guide support")
	else:
		for e in errs:
			t.ok(false, e)
	t.finish()


func _mild_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	var rules: Dictionary = db.rules("demand_rules")
	var tiers: Array = rules.get("tier_by_stage", [])
	if tiers.is_empty() or int(tiers[0]) != 0:
		errs.append("stage 0 tier is not t0")
	for kind in ["money", "goods", "people", "info"]:
		var id := "dm.1938.%s.t0" % kind
		if not db.has(id):
			errs.append("missing " + id)
			continue
		if not db.file_of(id).begins_with(OWN_PREFIX):
			errs.append(id + " file")
			continue
		var c := db.def(id)
		if int(c.get("tier", -1)) != 0 or int(c.get("weight", -1)) != 10 or c.has("schedule"):
			errs.append(id + " not an equal-weight t0")
	var money := db.def("dm.1938.money.t0")
	if int(money.get("resolve", {}).get("money", {}).get("amount", 999)) > MILD_MONEY_CAP:
		errs.append("1938 money t0 above cap")
	var goods: Dictionary = db.def("dm.1938.goods.t0").get("resolve", {}).get("goods", {})
	if int(goods.get("n", 0)) != 1 or str(goods.get("cat", "")) != "rice":
		errs.append("1938 goods t0 is not one common rice")
	var away := int(db.def("dm.1938.people.t0").get("resolve", {}).get("people", {}).get("away_days", 99))
	if away > 7:
		errs.append("1938 people t0 away_days")
	var need := int(db.def("dm.1938.info.t0").get("resolve", {}).get("fabricate", {}).get("need", 99))
	if need > 1:
		errs.append("1938 info t0 fabricate need")
	return errs


func _method_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	for id in db.ids_of(&"demand"):
		if not db.file_of(id).begins_with(OWN_PREFIX):
			continue
		var c := db.def(id)
		var kind := str(c.get("kind", ""))
		var res: Dictionary = c.get("resolve", {})
		if kind == "people":
			var chk = res.get("people", {}).get("return_check", {})
			if typeof(chk) != TYPE_DICTIONARY or not chk.has("attr") or not chk.has("need"):
				errs.append(id + " return_check")
		elif kind == "info":
			var fab = res.get("fabricate", {})
			if typeof(fab) != TYPE_DICTIONARY or not fab.has("attr") or not fab.has("need"):
				errs.append(id + " fabricate")
		elif kind == "money":
			if typeof(res.get("haggle")) != TYPE_DICTIONARY:
				errs.append(id + " haggle")
	return errs


func _return_errors(db: CardDB) -> PackedStringArray:
	var errs := PackedStringArray()
	if not db.has("ev.any.demand_return"):
		errs.append("missing ev.any.demand_return")
		return errs
	if not db.file_of("ev.any.demand_return").begins_with(OWN_PREFIX):
		errs.append("return file")
		return errs
	var c := db.def("ev.any.demand_return")
	if str(c.get("type", "")) != "event" or int(c.get("weight", -1)) != 0:
		errs.append("return type/weight")
	if not _has_omen(c.get("tags", [])):
		errs.append("return omen")
	return errs


func _has_omen(tags) -> bool:
	if typeof(tags) != TYPE_ARRAY:
		return false
	for tag in tags:
		if str(tag).begins_with("omen_"):
			return true
	return false
