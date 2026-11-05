# C01 1.3：自己的锚点落在 CardLayout 的矩形里；HUD、对话框、手牌扇、头像、标签、打烊按钮互不压住。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C01/support.gd")
const OWN := "res://scripts/tests/cards/C01/fixtures/"
const BASE: Array[String] = ["month_open", "month_wheel", "morning", "day_full", "day_counter", "night", "settle",
	"month_close", "year_jump", "street_prison"]


func _initialize() -> void:
	var t := T.new(self, "C01_layout")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_bands(t)
	_fixtures_clean(t)
	var bus := CardEventBus.new()
	root.add_child(bus)
	for name in BASE:
		await _one(t, bus, name, name)
	for f in DirAccess.get_files_at(OWN):
		if f.ends_with(".json"):
			await _one(t, bus, OWN + f, f.get_basename())
	bus.queue_free()
	await t.frames(1)


func _one(t, bus: CardEventBus, fixture: String, label: String) -> void:
	var game := S.boot(self, bus, fixture)
	await t.frames(2)
	var view: Dictionary = game.engine.view()
	for id in [&"a.top.date", &"a.top.weather", &"a.top.money", &"a.top.rep", &"a.top.heat", &"a.btn.close_day", &"a.scene"]:
		t.ok(t.anchor_in(id, _anchor_rect(id)), "%s %s" % [label, id])
	for id in [&"a.tab.contacts", &"a.tab.demands", &"a.tab.dossier", &"a.tab.rules", &"a.tab.shelf",
			&"a.tab.tickets", &"a.tab.estates", &"a.tab.settings"]:
		t.ok(t.anchor_in(id, _anchor_rect(id)), "%s %s" % [label, id])
	if _tools_on(view):
		for id in [&"a.scene.notice", &"a.scene.ledger", &"a.scene.notebook", &"a.scene.calendar",
				&"a.scene.cashbox", &"a.scene.magnifier"]:
			t.ok(t.anchor_in(id, _anchor_rect(id)), "%s %s" % [label, id])
		if not (view.get("demands", []) as Array).is_empty():
			t.ok(t.anchor_in(&"a.scene.notewall", CardLayout.HOTSPOTS[&"notewall"]), "%s notewall" % label)
	var bad: PackedStringArray = t.all_text_from_cardtext(game)
	t.ok(bad.is_empty(), "%s text %s" % [label, ", ".join(bad)])
	_no_percent(t, game, label)
	var hud: Node = game.table.get_node("Hud")
	var rep: String = hud.get_node("Rep").text
	var heat: String = hud.get_node("Heat").text
	t.eq(rep, CardText.ui("g03.tier.rep.%d" % int(view.get("rep_tier", 0))), label + " rep")
	t.eq(heat, CardText.ui("g03.tier.heat.%d" % int(view.get("heat_tier", 0))), label + " heat")
	if label == "street":
		t.ok(game.table.get_node("Street").visible, "street overlay visible")
	game.queue_free()
	CardAnchors.clear()
	await t.frames(1)


func _bands(t) -> void:
	var boxes: Array[Rect2] = [CardLayout.HUD, CardLayout.FAN, CardLayout.HERO, CardLayout.END_DAY]
	boxes.append(Rect2(CardLayout.DIALOG.position, Vector2(CardLayout.DIALOG.size.x, CardLayout.FAN.position.y - CardLayout.DIALOG.position.y)))
	for r in CardLayout.CONTACT_MINIS:
		boxes.append(r)
	for r in CardLayout.TABS_L:
		boxes.append(r)
	for r in CardLayout.TABS_R:
		boxes.append(r)
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var inter := boxes[i].intersection(boxes[j])
			var area := maxf(inter.size.x, 0.0) * maxf(inter.size.y, 0.0)
			t.ok(area < 1.0, "bands overlap %d %d" % [i, j])


func _anchor_rect(id: StringName) -> Rect2:
	match id:
		&"a.top.date":
			return CardLayout.HUD_DATE
		&"a.top.weather":
			return CardLayout.HUD_WEATHER
		&"a.top.money":
			return CardLayout.HUD_MONEY
		&"a.top.rep":
			return CardLayout.HUD_REP
		&"a.top.heat":
			return CardLayout.HUD_HEAT
		&"a.btn.close_day":
			return CardLayout.END_DAY
		&"a.scene":
			return CardLayout.SCREEN
		&"a.scene.notice", &"a.scene.ledger", &"a.scene.notebook", &"a.scene.calendar", &"a.scene.cashbox", &"a.scene.magnifier":
			return CardLayout.HOTSPOTS[StringName(str(id).trim_prefix("a.scene."))]
	var tab := str(id).trim_prefix("a.tab.")
	var names: Array = CardIds.TABS_L + CardIds.TABS_R
	var rects: Array = CardLayout.TABS_L + CardLayout.TABS_R
	var at := names.find(StringName(tab))
	return rects[at] if at >= 0 else CardLayout.SCREEN


func _tools_on(view: Dictionary) -> bool:
	var mode := str(view.get("mode", "shop"))
	var set_name := str(view.get("stage", {}).get("set", "counter"))
	return mode != "street" and mode != "prison" and set_name != "street" and set_name != "prison"


func _fixtures_clean(t) -> void:
	for f in DirAccess.get_files_at(OWN):
		if not f.ends_with(".json"):
			continue
		var doc: Dictionary = CardDB.read_json(OWN + f)
		t.no_leaks(doc.get("view", {}), f + " view")
		for k in doc.get("queries", {}).keys():
			t.no_leaks(doc["queries"][k], f + " " + str(k))


func _no_percent(t, node: Node, label: String) -> void:
	if node is Label and (node as Label).text.contains("%"):
		t.ok(false, label + " percent in label")
	if node is Button and (node as Button).text.contains("%"):
		t.ok(false, label + " percent in button")
	for c in node.get_children():
		_no_percent(t, c, label)
