# K11：首发物品表、小游戏规格、新模板、电码本骨架。
# 合同 §4.7.15、§4.7.23、§8.2；任务卡 docs/handoff_cards/K11_data-items-mg.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const FORBIDDEN: Array[String] = ["fake", "real", "genuine", "authentic", "forged", "stolen", "origin",
	"market", "value", "true_value", "floor", "tell", "benign", "fake_text", "real_text", "est", "verdict",
	"rare", "grade", "quality"]
const OLD_CATS: Array[String] = ["rice", "clothing", "jewelry", "utensils", "art", "medicine", "documents"]
const KINDS: Array[String] = ["spot", "coin_ring", "weigh", "fragments"]

var _cjk := RegEx.create_from_string("[\\x{3000}-\\x{9fff}\\x{f900}-\\x{faff}\\x{ff00}-\\x{ffef}]")


func _initialize() -> void:
	var t := T.new(self, "K11_data")
	var town := _load("res://data/town/item_templates.json")
	var extra := _load("res://data/cards/items/templates_extra.json")
	var launch := _load("res://data/cards/items/launch_items.json")
	var items := _load("res://data/cards/minigames/items.json")
	var book := _load("res://data/cards/minigames/codebook.json")
	if town.is_empty() or extra.is_empty() or launch.is_empty() or items.is_empty() or book.is_empty():
		t.ok(false, "json parse")
		t.finish()
		return
	for pair in [["items", items], ["extra", extra], ["launch", launch], ["book", book]]:
		var meta: Dictionary = pair[1].get("_meta", {})
		t.eq(str(meta.get("owner", "")), "K11", "%s owner" % pair[0])
		t.eq(int(meta.get("schema", 0)), 1, "%s schema" % pair[0])
		t.ok(str(meta.get("brief", "")).strip_edges() != "", "%s meta brief" % pair[0])
		var mp: Dictionary = meta.get("_provenance", {})
		t.eq(str(mp.get("task", "")), "K11", "%s meta task" % pair[0])
		t.eq(str(mp.get("date", "")), "2026-10-13", "%s meta date" % pair[0])

	var town_cats: Dictionary = town.get("categories", {})
	var extra_cats: Dictionary = extra.get("categories", {})
	var merged := town_cats.duplicate(true)
	for k in extra_cats.keys():
		if not merged.has(k):
			merged[k] = extra_cats[k]
	var ref_cat: Array = town_cats["rice"].keys()
	ref_cat.sort()
	var ref_var: Array = (town_cats["rice"]["variants"] as Array)[0].keys()
	ref_var.sort()

	var old_tpls: Array = []
	for cat in OLD_CATS:
		t.ok(town_cats.has(cat), "old category %s" % cat)
		for v in town_cats[cat].get("variants", []):
			old_tpls.append("%s.%s" % [cat, str(v["id"])])
	t.eq(old_tpls.size(), 28, "28 existing variants")

	var launch_rows: Array = launch.get("items", [])
	t.ok(launch_rows.size() >= 36, "launch count >= 36 (%d)" % launch_rows.size())
	var launch_by := {}
	for row in launch_rows:
		var tpl := str(row.get("template", ""))
		t.ok(not launch_by.has(tpl), "duplicate launch %s" % tpl)
		launch_by[tpl] = row
		t.ok(str(row.get("brief", "")).strip_edges() != "", "launch brief %s" % tpl)
		t.ok(CardDslShapes.is_int(row.get("weight")), "launch weight int %s" % tpl)
		t.ok(int(row.get("weight", -1)) >= 0, "launch weight >= 0 %s" % tpl)
	for tpl in old_tpls:
		t.ok(launch_by.has(tpl), "launch lists %s" % tpl)

	var card_by := {}
	for c in items.get("cards", []):
		var id := str(c.get("id", ""))
		t.ok(not card_by.has(id), "duplicate card %s" % id)
		card_by[id] = c
		t.ok(str(c.get("brief", "")).strip_edges() != "", "brief %s" % id)
		var pv: Dictionary = c.get("_provenance", {})
		t.eq(str(pv.get("task", "")), "K11", "provenance task %s" % id)
		t.eq(str(pv.get("by", "")), "ai", "provenance by %s" % id)
		t.eq(str(pv.get("date", "")), "2026-10-13", "provenance date %s" % id)
		t.eq(int(c.get("weight", -1)), 0, "card weight 0 %s" % id)
		var kinds: Array = c.get("minigames", [])
		t.ok(not kinds.is_empty(), "at least one minigame %s" % id)
		var tpl2 := str(c.get("template", ""))
		t.ok(_tpl_exists(merged, tpl2), "template exists %s" % tpl2)
		t.eq(id, "it." + tpl2, "id matches template %s" % id)
		t.ok(not kinds.has("decode"), "decode not on item %s" % id)
		for kind in kinds:
			t.ok(KINDS.has(str(kind)), "known kind %s on %s" % [kind, id])
			t.ok(typeof(c.get(str(kind))) == TYPE_DICTIONARY, "spec object %s.%s" % [id, kind])
			_check_spec(t, c[str(kind)], "%s.%s" % [id, kind])
		var hit := _cjk_find(c, "")
		t.ok(hit == "", "no CJK outside brief on %s (%s)" % [id, hit])
	for tpl3 in launch_by.keys():
		if int(launch_by[tpl3].get("weight", 0)) > 0:
			t.ok(card_by.has("it." + str(tpl3)), "it card for %s" % tpl3)

	for cat in extra_cats.keys():
		t.ok(not OLD_CATS.has(str(cat)), "new category name %s" % cat)
		t.ok(not town_cats.has(cat), "extra does not reuse %s" % cat)
		var got: Array = extra_cats[cat].keys()
		got.sort()
		t.eq(got, ref_cat.duplicate(), "category fields %s" % cat)
		_empty_text(t, extra_cats[cat], str(cat), ["variants"])
		t.ok(typeof(extra_cats[cat].get("can_fake")) == TYPE_BOOL, "can_fake bool %s" % cat)
		t.ok(CardDslShapes.is_int(extra_cats[cat].get("weight")), "category weight int %s" % cat)
		for v in extra_cats[cat].get("variants", []):
			var vid := str(v.get("id", ""))
			var vgot: Array = v.keys()
			vgot.sort()
			t.eq(vgot, ref_var.duplicate(), "variant fields %s.%s" % [cat, vid])
			_empty_text(t, v, "%s.%s" % [cat, vid], ["id", "sprite"])
			var sprite := str(v.get("sprite", ""))
			t.eq(sprite, "art/_placeholder/cards/items/%s.%s.png" % [cat, vid], "sprite %s.%s" % [cat, vid])
			t.ok(CardDslShapes.is_int(v.get("base_price")) and int(v.get("base_price", 0)) > 0, "base_price %s.%s" % [cat, vid])
			t.ok(CardDslShapes.is_int(v.get("weight")), "variant weight %s.%s" % [cat, vid])
			t.ok((v.get("tags", null) is Array) and (v["tags"] as Array).is_empty(), "empty tags %s.%s" % [cat, vid])
			t.ok(launch_by.has("%s.%s" % [cat, vid]), "launch has new %s.%s" % [cat, vid])
			print("NOTE: art_for_k12 item.%s.%s" % [cat, vid])

	var codes: Dictionary = book.get("codes", {})
	t.ok(codes.size() >= 60, "codebook >= 60 (%d)" % codes.size())
	for code in codes.keys():
		var cs := str(code)
		t.ok(_four(cs), "4-digit code %s" % cs)
		var ent: Dictionary = codes[code]
		t.eq(ent.keys().size(), 2, "code entry keys %s" % cs)
		t.eq(str(ent.get("key", "")), "cb.word." + cs, "code key %s" % cs)
		t.ok(str(ent.get("brief", "")).strip_edges() != "", "code brief %s" % cs)
		t.ok(not ent.has("word"), "no word field %s" % cs)
	t.ok(codes.has("5101") and codes.has("5121") and codes.has("5122"), "story slots and decoys present")
	_history(t, card_by)
	t.finish()


func _history(t, card_by: Dictionary) -> void:
	for id in ["it.silver.yuan_a", "it.silver.yuan_b", "it.silver.yuan_c"]:
		t.ok(card_by.has(id), "card %s" % id)
		if not card_by.has(id):
			continue
		var kinds: Array = card_by[id]["minigames"]
		t.ok(kinds.has("coin_ring") and not kinds.has("weigh") and not kinds.has("spot"), "yuan blow only %s" % id)
	for id2 in ["it.silver.bits", "it.jewelry.hairpin", "it.goldbar.bar_one", "it.goldbar.bar_ten",
			"it.medicine.quinine", "it.medicine.iodine", "it.medicine.aspirin", "it.medicine.sulfa",
			"it.silverware.cup", "it.silverware.spoon", "it.silverware.box", "it.jewelry.bangle", "it.jewelry.ring"]:
		t.ok(card_by.has(id2) and str(card_by[id2]["weigh"]["tool"]) == "dengzi", "dengzi %s" % id2)
	for id3 in ["it.rice.jing", "it.rice.xian", "it.rice.nuo", "it.rice.broken"]:
		t.ok(card_by.has(id3) and str(card_by[id3]["weigh"]["tool"]) == "steelyard", "steelyard %s" % id3)
	t.ok(card_by.has("it.jewelry.hairpin") and card_by["it.jewelry.hairpin"]["minigames"].has("spot"), "hairpin spot")
	for id4 in card_by.keys():
		var c4: Dictionary = card_by[id4]
		var tpl := str(c4.get("template", ""))
		var cat := tpl.split(".")[0]
		if cat in ["art", "documents", "papers"]:
			t.ok(c4["minigames"].has("fragments"), "fragments %s" % id4)
		if not OLD_CATS.has(cat):
			t.ok(not c4["minigames"].has("spot"), "new category has no spot %s" % id4)


func _check_spec(t, spec: Dictionary, path: String) -> void:
	_walk_spec(t, spec, path)


func _walk_spec(t, v, path: String) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				var ks := str(k)
				t.ok(not _bad_key(ks), "forbidden key %s at %s" % [ks, path])
				_walk_spec(t, v[k], "%s.%s" % [path, ks])
		TYPE_ARRAY:
			t.ok(v.size() == 2, "range length %s" % path)
			if v.size() == 2:
				t.ok(CardDslShapes.is_int(v[0]) and CardDslShapes.is_int(v[1]), "range ints %s" % path)
				if CardDslShapes.is_int(v[0]) and CardDslShapes.is_int(v[1]):
					t.ok(int(v[0]) <= int(v[1]), "lo<=hi %s" % path)
		TYPE_INT, TYPE_STRING:
			pass

		TYPE_FLOAT:
			t.ok(CardDslShapes.is_int(v), "non-integer %s" % path)
		_:
			t.ok(false, "bad spec type at %s" % path)


func _bad_key(ks: String) -> bool:
	if FORBIDDEN.has(ks):
		return true
	for part in ks.split("_"):
		if FORBIDDEN.has(part):
			return true
	return false


func _empty_text(t, d: Dictionary, path: String, allow: Array) -> void:
	for k in d.keys():
		if allow.has(str(k)):
			continue
		if typeof(d[k]) == TYPE_STRING:
			t.ok(str(d[k]) == "", "empty text %s.%s" % [path, k])


func _tpl_exists(cats: Dictionary, tpl: String) -> bool:
	var parts := tpl.split(".")
	if parts.size() != 2 or not cats.has(parts[0]):
		return false
	for v in cats[parts[0]].get("variants", []):
		if str(v.get("id", "")) == parts[1]:
			return true
	return false


func _four(cs: String) -> bool:
	if cs.length() != 4:
		return false
	for i in cs.length():
		var ch := cs[i]
		if ch < "0" or ch > "9":
			return false
	return true


func _cjk_find(v, path: String) -> String:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			if _cjk.search(str(v)):
				return path
		TYPE_DICTIONARY:
			for k in v.keys():
				var ks := str(k)
				if ks == "brief" or ks.begins_with("_"):
					continue
				if _cjk.search(ks):
					return path + "." + ks
				var sub := _cjk_find(v[k], path + "." + ks)
				if sub != "":
					return sub
		TYPE_ARRAY:
			for i in range(v.size()):
				var sub2 := _cjk_find(v[i], "%s[%d]" % [path, i])
				if sub2 != "":
					return sub2
	return ""


func _load(path: String) -> Dictionary:
	var raw = CardDB.read_json(path)
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var restored = CardState.int_restore(raw)
	return restored if typeof(restored) == TYPE_DICTIONARY else {}
