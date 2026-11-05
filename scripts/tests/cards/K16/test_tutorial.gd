# K16: tutorial.json matches §7.10.11 (days 1-3 guests, slots, fortune, Zhouma news, contact).
# 10-22 (prototype): day 1 also deals the brother's gold handover, and on the real engine the day 1
# lessons pawn -> sell -> buy all close at the fair price the guide recommends (no money_short).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K16_tutorial")
	var doc: Dictionary = CardDB.read_json("res://data/cards/era/1938/tutorial.json")
	var templates: Dictionary = CardDB.read_json("res://data/town/item_templates.json")
	var cards: Array = doc.get("cards", [])
	t.ok(not cards.is_empty(), "tutorial has cards")
	var by_id := {}
	var days := {}
	for c in cards:
		var id := str(c.get("id", ""))
		by_id[id] = c
		t.eq(int(c.get("weight", -1)), 0, id + " weight 0")
		t.ok(_tut_id(id), id + " matches *.1938.tut_*")
		t.eq(c.get("era", []), ["1938"], id + " era")
		t.eq(str(c.get("_provenance", {}).get("task", "")), "K16", id + " provenance")
		var tags: Array = c.get("tags", [])
		var omen := false
		for tag in tags:
			if str(tag).begins_with("omen_"):
				omen = true
		t.ok(omen, id + " has an omen tag")
		var sch: Dictionary = c.get("schedule", {})
		var day := int(sch.get("stage_day", 0))
		t.ok(day in [1, 2, 3, 5, 6, 7], id + " schedule day")
		if not days.has(day):
			days[day] = []
		(days[day] as Array).append(c)
	_handover(t, by_id.get("p.brother.1938.tut_handover", {}), days.get(1, []))
	_day1(t, _lessons(days.get(1, [])), templates)
	_early(t, days)
	_fair_chain(t)
	var slots: Dictionary = by_id.get("ev.1938.tut_slots", {})
	t.ok(not slots.is_empty(), "slots event")
	t.ok(slots.has("check"), "slots has a top-level check")
	t.ok(int(slots.get("check", {}).get("need", 99)) <= 1, "slots need <= 1")
	t.ok(not slots.get("effects", {}).has("on_expire"), "slots does not add an on_expire")
	var acc := {}
	for s in slots.get("slots", []):
		for a in s.get("accepts", []):
			acc[str(a)] = true
	t.ok(acc.has("self") and acc.has("money"), "slots accept self and money")
	var fort: Dictionary = by_id.get("ev.1938.tut_fortune", {})
	t.eq(str(fort.get("opens_fortune", "")), "both", "fortune opens both")
	t.ok(int(fort.get("cost", {}).get("money", 0)) > 0, "fortune costs money")
	t.eq(bool(fort.get("must_resolve", true)), false, "fortune not must_resolve")
	var passed := false
	for ch in fort.get("choices", []):
		if str(ch.get("id", "")) == "pass":
			passed = true
	t.ok(passed, "fortune has pass")
	var news: Dictionary = by_id.get("nw.1938.tut_zhouma", {})
	t.eq(str(news.get("kind", "")), "rumor", "zhouma rumor")
	t.eq(str(news.get("source", "")), "zhouma", "zhouma source")
	t.eq(str(news.get("info_about", "")), "zhouma", "zhouma info_about")
	var db := CardDB.load_all()
	t.eq(db.file_of("nw.1938.tut_zhouma"), "era/1938/tutorial.json", "tut_zhouma lives in the K16 file")
	t.ok(db.persons().has(str(news.get("info_about", ""))), "info_about is a registered person")
	t.eq(bool(news.get("keepable", false)), true, "zhouma keepable")
	var frag := false
	for e in news.get("effects", {}).get("on_read", []):
		if str(e.get("op", "")) == "dossier" and str(e.get("frag", "")) == "df.zhouma.1938.tut_news":
			frag = true
	t.ok(frag, "on_read adds df.zhouma.1938.tut_news")
	var contact: Dictionary = by_id.get("ev.1938.tut_contact", {})
	var gained := false
	for ch2 in contact.get("choices", []):
		for e2 in ch2.get("effects", []):
			if str(e2.get("op", "")) == "contact_gain" and str(e2.get("person", "")) == "zhouma":
				gained = true
	t.ok(gained, "contact_gain zhouma")
	t.ok(not contact.has("check"), "tut_contact has no top-level check")
	var expired := false
	for e3 in contact.get("effects", {}).get("on_expire", []):
		if str(e3.get("op", "")) == "contact_gain" and str(e3.get("person", "")) == "zhouma":
			expired = true
	t.ok(expired, "tut_contact on_expire contact_gain zhouma")
	t.finish()


func _day1(t, rows: Array, templates: Dictionary) -> void:
	t.eq(rows.size(), 3, "day 1 has 3 cards")
	rows.sort_custom(_by_order)
	var intents: Array = []
	for i in range(rows.size()):
		intents.append(str(rows[i].get("intent", "")))
		t.eq(int(rows[i].get("schedule", {}).get("order", 0)), i + 1, "day 1 order")
	t.eq(intents, ["pawn", "sell", "buy"], "day 1 pawn sell buy")
	var pawn: Dictionary = rows[0]
	var sell: Dictionary = rows[1]
	var buy: Dictionary = rows[2]
	t.eq(str(pawn.get("minigame", "")), "spot", "pawn minigame spot")
	t.eq(str(sell.get("minigame", "")), "spot", "sell minigame spot")
	var tpl := str(pawn.get("item", {}).get("template", ""))
	t.ok(_sprite_laid_out(templates, tpl), "pawn template has a spot layout")
	var cat := str(sell.get("item", {}).get("template", "")).get_slice(".", 0)
	var cats: Array = buy.get("want", {}).get("cats", [])
	t.ok(cats.has(cat), "buy want.cats includes the sold category")


func _early(t, days: Dictionary) -> void:
	for day in [1, 2, 3]:
		for c in days.get(day, []):
			var id := str(c.get("id", ""))
			var typ := str(c.get("type", ""))
			if bool(c.get("gold", false)):
				t.eq(id, "p.brother.1938.tut_handover", "the only gold card on days 1-3 is the handover")
			elif typ == "person":
				t.ok(str(c.get("intent", "")) in ["pawn", "sell", "buy"], id + " intent")
				t.ok((c.get("choices", []) as Array).is_empty(), id + " has no choices")
				if c.has("item"):
					t.eq(str(c.get("minigame", "")), "spot", id + " spot")
			elif typ == "event":
				t.eq(id, "ev.1938.tut_slots", "only the slots event on days 1-3")
			else:
				t.ok(false, id + " unexpected on days 1-3")


## Day 1's guests other than the brother's gold handover.
func _lessons(rows: Array) -> Array:
	var out: Array = []
	for c in rows:
		if not bool(c.get("gold", false)):
			out.append(c)
	return out


func _handover(t, c: Dictionary, day1: Array) -> void:
	t.ok(not c.is_empty(), "day 1 has the brother's handover")
	if c.is_empty():
		return
	CardText.setup(CardDB.load_all())
	t.eq(str(c.get("type", "")), "person", "handover is a person card")
	t.eq(str(c.get("person", "")), "brother", "handover is the brother")
	t.eq(bool(c.get("gold", false)), true, "handover is gold (taught on day 1 by gd.d2.gold)")
	t.eq(bool(c.get("keepable", true)), false, "handover cannot be kept")
	t.eq(int(c.get("schedule", {}).get("stage_day", 0)), 1, "handover on day 1")
	var last := 0
	for r in _lessons(day1):
		last = maxi(last, int(r.get("schedule", {}).get("order", 0)))
	t.ok(int(c.get("schedule", {}).get("order", 0)) > last, "dealt after the lessons: the first person is a guest")
	var ids: Array = []
	for ch in c.get("choices", []):
		ids.append(str(ch.get("id", "")))
		for e in ch.get("effects", []):
			t.ok(str(e.get("op", "")) in ["story", "dossier"], "handover choice only writes story/dossier")
	t.eq(ids, ["listen", "assure"], "handover choices")
	var ops: Array = []
	for e2 in c.get("effects", {}).get("on_expire", []):
		ops.append(str(e2.get("op", "")))
	t.ok(ops.has("story") and ops.has("dossier_gap"), "ignored handover leaves a dossier gap")
	t.eq(CardText.has_text("p.brother.1938.tut_handover#title"), true, "handover has a title")
	t.eq(CardText.has_text("p.brother.1938.tut_handover#lines.greet"), true, "handover has a greeting")


## The guide says: the first time, offer the middle price. On the real engine that must work for the
## whole day 1 chain on any seed: the pawn and the purchase fit in the till, the buyer finds stock.
func _fair_chain(t) -> void:
	for seed_i in range(1, 13):
		var e := CardEngine.new()
		var dir: String = str(t.user_dir()).path_join("chain_%d" % seed_i)
		DirAccess.make_dir_recursive_absolute(dir)
		t.ok(bool(e.send(&"game.new", {"seed": seed_i, "save_dir": dir}).get("ok", false)), "game.new seed %d" % seed_i)
		e.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
		e.send(&"month.begin")
		e.send(&"day.begin")
		for def_id in ["p.zhang.1938.tut_pawn", "p.wu.1938.tut_sell", "p.xiaoding.1938.tut_buy"]:
			var uid := ""
			for row in e.view().get("hand", []):
				if str(row.get("def", "")) == def_id:
					uid = str(row.get("uid", ""))
			t.ok(uid != "", "seed %d deals %s" % [seed_i, def_id])
			if uid == "":
				continue
			e.send(&"counter.open", {"uid": uid})
			if def_id.ends_with("tut_buy"):
				var stock: Array = e.query(&"counter", {"uid": uid}).get("stock", [])
				t.ok(not stock.is_empty(), "seed %d: the buyer finds the piece bought from Wu" % seed_i)
				if stock.is_empty():
					continue
				var sid := str(stock[0]) if typeof(stock[0]) == TYPE_STRING else str(stock[0].get("item", stock[0].get("id", "")))
				e.send(&"counter.pick_stock", {"uid": uid, "item": sid})
			var res := e.send(&"counter.offer", {"uid": uid, "tier": "fair"})
			if str(res.get("reply", "")) == "counter":
				res = e.send(&"counter.answer", {"uid": uid, "accept": true})
			t.ok(str(res.get("err", "")) != "money_short", "seed %d %s: the till covers the fair price" % [seed_i, def_id])
			if not def_id.ends_with("tut_buy"):
				t.eq(str(res.get("reply", "")), "accept", "seed %d %s: takes the fair price" % [seed_i, def_id])


func _sprite_laid_out(templates: Dictionary, tpl: String) -> bool:
	var parts := tpl.split(".")
	if parts.size() != 2:
		return false
	var sprite := ""
	for v in templates.get("categories", {}).get(parts[0], {}).get("variants", []):
		if str(v.get("id", "")) == parts[1]:
			sprite = str(v.get("sprite", ""))
	if sprite == "":
		return false
	var sprites: Dictionary = templates.get("appraise", {}).get("sprites", {})
	if sprites.has(sprite):
		return true
	return sprites.has("proc:" + parts[1])


func _by_order(a, b) -> bool:
	return int(a.get("schedule", {}).get("order", 0)) < int(b.get("schedule", {}).get("order", 0))


func _tut_id(id: String) -> bool:
	var head := id.begins_with("p.") or id.begins_with("ev.") or id.begins_with("nw.")
	return head and id.contains(".1938.tut_")
