# K11 指引验收：教学找不同、四种小游戏都有模板、电码本形状。
# 合同 §3.4 K11、§7.10.10；任务卡 docs/handoff_cards/K11_data-items-mg.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K11_guide_support")
	var town := _load("res://data/town/item_templates.json")
	var extra := _load("res://data/cards/items/templates_extra.json")
	var items := _load("res://data/cards/minigames/items.json")
	var launch := _load("res://data/cards/items/launch_items.json")
	var book := _load("res://data/cards/minigames/codebook.json")
	if town.is_empty() or items.is_empty() or book.is_empty():
		t.ok(false, "json parse")
		t.finish()
		return
	var merged: Dictionary = town.get("categories", {}).duplicate(true)
	for k in extra.get("categories", {}).keys():
		if not merged.has(k):
			merged[k] = extra["categories"][k]
	var sprites: Dictionary = town.get("appraise", {}).get("sprites", {})
	var by := {}
	for c in items.get("cards", []):
		by[str(c.get("id", ""))] = c
	t.ok(by.has("it.jewelry.hairpin"), "it.jewelry.hairpin exists")
	t.ok(by.has("it.jewelry.hairpin") and (by["it.jewelry.hairpin"]["minigames"] as Array).has("spot"),
		"hairpin minigames contain spot")
	t.ok(_tpl(merged, "documents.receipt"), "documents.receipt template exists")

	var counts := {"spot": 0, "coin_ring": 0, "weigh": 0, "fragments": 0}
	for row in launch.get("items", []):
		if int(row.get("weight", 0)) <= 0:
			continue
		var card: Dictionary = by.get("it." + str(row.get("template", "")), {})
		var kinds: Array = card.get("minigames", [])
		for kind in counts.keys():
			if kinds.has(kind):
				counts[kind] += 1
	for kind in ["spot", "coin_ring", "weigh", "fragments"]:
		t.ok(int(counts[kind]) >= 2, "%s used by >= 2 launch templates (%d)" % [kind, int(counts[kind])])

	for c in items.get("cards", []):
		var kinds2: Array = c.get("minigames", [])
		if not kinds2.has("spot"):
			continue
		var parts := str(c.get("template", "")).split(".")
		t.ok(parts.size() == 2 and merged.has(parts[0]), "spot template %s" % c.get("id", ""))
		if parts.size() != 2 or not merged.has(parts[0]):
			continue
		var sprite := ""
		for v in merged[parts[0]].get("variants", []):
			if str(v.get("id", "")) == parts[1]:
				sprite = str(v.get("sprite", ""))
		var key := sprite if sprite != "" else "proc:" + parts[1]
		t.ok(sprites.has(key), "spot layout %s -> %s" % [c.get("id", ""), key])

	var codes: Dictionary = book.get("codes", {})
	t.ok(not codes.is_empty(), "codebook has codes")
	for code in codes.keys():
		var cs := str(code)
		t.ok(cs.length() == 4 and cs.is_valid_int(), "code is 4 digits %s" % cs)
		var ent: Dictionary = codes[code]
		t.eq(str(ent.get("key", "")), "cb.word." + cs, "key cb.word.<code> %s" % cs)
		t.ok(str(ent.get("brief", "")).strip_edges() != "", "code brief %s" % cs)
	t.finish()


func _tpl(cats: Dictionary, tpl: String) -> bool:
	var parts := tpl.split(".")
	if parts.size() != 2 or not cats.has(parts[0]):
		return false
	for v in cats[parts[0]].get("variants", []):
		if str(v.get("id", "")) == parts[1]:
			return true
	return false


func _load(path: String) -> Dictionary:
	var raw = CardDB.read_json(path)
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var restored = CardState.int_restore(raw)
	return restored if typeof(restored) == TYPE_DICTIONARY else {}
