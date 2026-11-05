# 卡牌版合同 1.3 的画面与演出骨架及验收。
# 主人 W0（Claude），X02 同步；参照接口合同 §7.11。
# Contract 1.3: frozen layout, local stage validation, public scripts, Mock views and the owners' widgets.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const STAGE_EXAMPLES := "res://scripts/cards/mock/stage_examples.json"
## X01-b: the frozen widget interfaces are checked on the owners' scenes (CardIds.widget_scene / panel_scene).
const WIDGETS := {
	"stage": &"stage", "dialog": &"dialog", "hand": &"hand_fan", "hero": &"hero_bar", "checks": &"checks",
	"panel": &"almanac",
}
const FIXTURES := ["month_open", "month_wheel", "morning", "day_full", "day_counter", "night", "settle",
	"month_close", "year_jump", "street_prison"]


class StagePanelProbe:
	extends CardStagePanel


func _initialize() -> void:
	var t := T.new(self, "W0_stage")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_check_layout(t)
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture("day_full")
	_check_validation(t, mock.db)
	_check_scripts(t, mock)
	_check_mock(t, bus)
	await t.frames(1)
	await _check_widgets(t, mock, bus)
	mock = null
	bus.queue_free()
	await t.frames(2)


func _check_layout(t) -> void:
	var constants: Dictionary = load("res://scripts/cards/api/card_layout.gd").get_script_constant_map()
	for name in constants:
		if str(name).begins_with("S_"):
			continue
		_check_layout_value(t, constants[name], str(name))
	for name in ["WALL", "DOOR", "COUNTER", "UNDER", "ITEMS", "SHADOW", "SIGN", "DOOR_FLAG", "SLOTS", "COINS"]:
		t.eq(CardLayout.screen(constants["S_" + name]), constants[name], "scene x4 matches " + name)
	for name in CardIds.STAGE_SPOTS:
		t.eq(CardLayout.spot(name), CardLayout.screen(CardLayout.S_SPOTS[name]), "spot x4: %s" % name)
	for name in CardIds.HOTSPOTS:
		t.eq(CardLayout.HOTSPOTS[name], CardLayout.screen(CardLayout.S_HOTSPOTS[name]), "hotspot x4: %s" % name)
	for name in CardIds.PROP_SPOTS:
		var r := CardLayout.prop_rect(name, Vector2i(16, 16))
		_check_layout_value(t, r, "prop %s" % name)
		t.eq(r.end.y, CardLayout.S_PROP_SPOTS[name].y * 4, "prop bottom: %s" % name)
		t.eq(r.get_center().x, CardLayout.S_PROP_SPOTS[name].x * 4, "prop center: %s" % name)
	t.eq(CardLayout.FAN, Rect2(372, 520, 636, 200), "frozen FAN band is y520-720")
	t.eq(CardLayout.DIALOG, Rect2(52, 38, 380, 482), "frozen maximum dialog")
	t.eq(CardLayout.DIALOG.end.y, float(CardLayout.DIALOG_MAX_BOTTOM), "dialog max bottom is y520")
	_check_ui_regions(t)
	for count in range(1, 9):
		_check_centered_row(t, count, CardLayout.slot_rect, "slots")
	for count in range(1, 15):
		_check_centered_row(t, count, CardLayout.coin_rect, "coins")


func _check_layout_value(t, value, path: String) -> void:
	if value is Rect2:
		t.ok(value.has_area() and CardLayout.SCREEN.encloses(value), path + " is inside 1280x720")
	elif value is Array:
		for i in range(value.size()):
			_check_layout_value(t, value[i], "%s[%d]" % [path, i])
	elif value is Dictionary:
		for key in value:
			_check_layout_value(t, value[key], "%s.%s" % [path, key])


func _check_ui_regions(t) -> void:
	# The maximum DIALOG (bottom y520) is one of the regions: it never covers FAN or HERO.
	var regions: Array = [CardLayout.HUD, CardLayout.DIALOG, CardLayout.FAN, CardLayout.HERO, CardLayout.END_DAY, CardLayout.STREET_REDEEM]
	regions.append_array(CardLayout.CONTACT_MINIS)
	regions.append_array(CardLayout.TABS_L)
	regions.append_array(CardLayout.TABS_R)
	for i in range(regions.size()):
		for j in range(i + 1, regions.size()):
			t.ok(not regions[i].intersects(regions[j]), "UI regions %d/%d do not overlap" % [i, j])
	var checks_dialog := Rect2(CardLayout.DIALOG.position,
		Vector2(CardLayout.DIALOG.size.x, CardLayout.DIALOG_CHECKS_BOTTOM - CardLayout.DIALOG.position.y))
	t.ok(not checks_dialog.intersects(CardLayout.SLOTS), "dialog bottom 404 avoids checks")
	t.ok(CardLayout.DIALOG_MAX_BOTTOM <= int(CardLayout.FAN.position.y), "dialog max bottom stays above the fan band")


func _check_centered_row(t, count: int, rect_fn: Callable, label: String) -> void:
	var first: Rect2 = rect_fn.call(0, count)
	var last: Rect2 = rect_fn.call(count - 1, count)
	t.eq(first.position.x + last.end.x, 1280.0, "%s/%d center is x640" % [label, count])
	for i in range(count):
		var rect: Rect2 = rect_fn.call(i, count)
		_check_layout_value(t, rect, "%s/%d/%d" % [label, count, i])
		if i > 0:
			t.ok(not rect.intersects(rect_fn.call(i - 1, count)), "%s cells do not overlap" % label)
	if label == "slots":
		t.eq(first.size, Vector2(160 if count <= 4 else 120, 120), "slot size follows count")
	else:
		t.eq(first.size, Vector2(48, 48), "coin size")


func _check_validation(t, db: CardDB) -> void:
	var examples: Dictionary = CardDB.read_json(STAGE_EXAMPLES)
	t.eq(examples.size(), 6, "six Mock stage examples")
	for id in examples:
		var card := db.def(str(id)).duplicate(true)
		t.ok(not card.is_empty(), "example card exists: %s" % id)
		card["stage"] = examples[id]
		t.eq(CardDslShapes.check_stage(card), PackedStringArray(), "valid stage example: %s" % id)
	t.eq(CardDslShapes.check_stage({"type": "kept"}), PackedStringArray(), "stage absent is valid")
	var cases := [
		["V38", {"unknown": true}, "unknown stage key"],
		["V38", {"cast": null}, "null cast"],
		["V38", {"props": 7}, "numeric props"],
		["V38", {"intro": {}}, "non-array intro"],
		["V38", {"after": []}, "non-object after"],
		["V38", {"fx": ["rain", "rain"]}, "duplicate fx"],
		["V38", {"fx": ["rain", "fire", "smoke", "warm"]}, "four fx"],
		["V38", {"cast": [_cast("street")]}, "street cannot stand"],
		["V38", {"cast": [_cast("door", "walk")]}, "walk only at street"],
		["V38", {"set": "moon"}, "unknown set"],
		["V38", {"cast": [_cast("customer"), _cast("companion"), _cast("door_l"), _cast("door_r")]}, "four cast"],
		["V41", {"cast": [_cast("door"), _cast("door_l")]}, "door conflicts with door_l"],
		["V41", {"set": "temple", "cast": [_cast("street", "walk")]}, "street only at counter"],
		["V41", {"set": "prison", "walk": "patrol"}, "walk only at counter"],
		["V39", {"intro": [{"who": "not_present", "ref": "body", "brief": "probe"}]}, "speaker is not present"],
		["V38", {"intro": [{"who": "", "ref": "title", "brief": "probe"}]}, "invalid text ref"],
		["V38", {"intro": [{"who": "", "ref": "body"}]}, "beat needs brief"],
		["V38", {"after": {"unknown_result": []}}, "unknown result key"],
	]
	for row in cases:
		_expect_rule(t, {"type": "event", "stage": row[1]}, row[0], row[2])
	_expect_rule(t, {"type": "kept", "stage": {}}, "V40", "kept cannot carry stage")
	_expect_rule(t, {"type": "event", "stage": null}, "V38", "null stage")
	var many_beats: Array = []
	for i in range(13):
		many_beats.append({"who": "", "ref": "body", "brief": "probe"})
	_expect_rule(t, {"type": "event", "stage": {"intro": many_beats}}, "V38", "intro limit")
	_expect_rule(t, {"type": "event", "stage": {"after": {"success": many_beats.slice(0, 9)}}}, "V38", "after limit")
	var many_props: Array = []
	for i in range(5):
		many_props.append({"art": "prop.notice", "at": "counter_mid", "brief": "probe"})
	_expect_rule(t, {"type": "event", "stage": {"props": many_props}}, "V38", "props limit")
	var beat := {"who": "me", "ref": "choices.custom", "brief": "probe"}
	t.eq(CardDslShapes.check_stage({"type": "event", "choices": [{"id": "custom"}],
		"stage": {"after": {"custom": [beat]}}}), PackedStringArray(), "local choice after key is valid")
	for mode in CardIds.DEMAND_MODES:
		t.eq(CardDslShapes.check_stage({"type": "demand", "stage": {"after": {str(mode): []}}}),
			PackedStringArray(), "demand mode after key: %s" % mode)


func _cast(at: String, look: String = "stand") -> Dictionary:
	return {"who": "ex_patrol", "at": at, "look": look, "brief": "probe"}


func _expect_rule(t, card: Dictionary, rule: String, message: String) -> void:
	var errors := CardDslShapes.check_stage(card)
	t.ok(Array(errors).any(func(e: String) -> bool: return e.begins_with(rule + ":")), "%s reports %s: %s" % [message, rule, errors])
	for error in errors:
		t.ok(error.begins_with("V38:") or error.begins_with("V39:") or error.begins_with("V40:") or error.begins_with("V41:"),
			"stage validator returns a frozen rule number")


func _check_scripts(t, mock: MockCardEngine) -> void:
	var view := mock.view()
	var person := _card("person", "p.linsao.1938.pawn_hairpin")
	person.merge({"person": "linsao", "intent": "pawn"})
	var script := CardStageScript.resolve(person, view)
	t.eq(script["cast"][0]["who"], "linsao", "person default speaker")
	t.eq(script["cast"][0]["at"], "customer", "person stands at customer")
	t.eq(CardStageScript.speaker(script), "linsao", "person speaker")
	t.eq(script["intro"].map(func(line: Dictionary) -> String: return line["ref"]),
		["w0.stage.enter", person["def"] + "#lines.greet", person["def"] + "#body", person["def"] + "#lines.ask"],
		"person intro follows frozen order")
	t.eq(script["intro"].map(func(line: Dictionary) -> bool: return line["opt"]), [true, false, false, true], "person optional beats")
	var accept := CardStageScript.lines(script, "accept")
	t.eq(accept.size(), 1, "person accept has one line")
	t.eq(accept[0]["ref"], person["def"] + "#lines.accept", "person accept text ref")
	t.eq(accept[0]["who"], "linsao", "accept speaker")
	var news := _card("news", "nw.1938.wangshan_dock")
	news["source"] = "wangshan"
	var sourced := CardStageScript.resolve(news, view)
	t.eq(sourced["cast"][0]["who"], "wangshan", "news source is cast")
	t.eq(sourced["cast"][0]["at"], "customer", "news source at counter")
	news.erase("source")
	var unsourced := CardStageScript.resolve(news, view)
	t.eq(unsourced["cast"][0]["who"], "ex_newsboy", "news defaults to newsboy")
	t.eq(unsourced["cast"][0]["at"], "door", "newsboy at door")
	var demand := CardStageScript.resolve(_card("demand", "dm.1938.money.t1"), view)
	t.eq(demand["cast"][0]["who"], "hu2", "demand speaker hu2")
	t.eq(demand["props"][0]["art"], "prop.notice", "demand carries notice")
	t.eq(demand["props"][0]["at"], "counter_mid", "notice on counter")
	_check_script_override(t, mock)
	_check_backgrounds(t)


func _check_script_override(t, mock: MockCardEngine) -> void:
	var police_uid := _uid(mock.view(), "ev.1938.police_check")
	var card := mock.query(&"card", {"uid": police_uid})
	var script := CardStageScript.resolve(card, mock.view())
	t.eq(script["cast"].size(), 2, "police stage overrides empty event cast")
	t.eq(script["cast"].map(func(actor: Dictionary) -> String: return actor["at"]), ["door_l", "door_r"], "police at both doors")
	t.eq(script["intro"][0]["who"], "ex_patrol", "police first speaker")
	t.eq(script["intro"][0]["ref"], "ev.1938.police_check#lines.greet", "police stage refs expand")
	t.eq(script["intro"][0]["opt"], false, "explicit stage lines are required")
	t.eq(CardStageScript.lines(script, "success")[0]["ref"], "ev.1938.police_check#lines.pass", "explicit after overrides default")
	var person := _card("person", "p.linsao.1938.pawn_hairpin")
	person.merge({"person": "linsao", "intent": "redeem",
		"stage": {"cast": [{"who": "linsao", "at": "door", "brief": "probe"}]}})
	var at_door := CardStageScript.resolve(person, {})
	t.eq(at_door["intro"][0]["ref"], "w0.stage.at_door", "door cast changes entry narration")
	t.ok(at_door["props"].any(func(prop: Dictionary) -> bool: return prop["art"] == "prop.ticket"), "redeem defaults to a ticket")
	person["stage"] = {"cast": [{"who": "linsao", "at": "customer", "brief": "probe"}, _cast("door")]}
	var with_patrol := CardStageScript.resolve(person, {})
	t.eq(with_patrol["intro"][0]["ref"], "w0.stage.enter", "person at counter retains entry despite patrol at door")


func _check_backgrounds(t) -> void:
	for time in ["day", "dusk", "night"]:
		t.eq(CardStageScript.bg_id({}, {"stage": {"set": "counter", "time": time}}),
			"bg.counter." + time, "counter background at " + time)
	for set_name in ["street", "candle"]:
		t.eq(CardStageScript.bg_id({"set": set_name}, {"stage": {"set": "counter", "time": "night"}}),
			"bg." + set_name, "script background overrides view: " + set_name)
	t.eq(CardStageScript.bg_id({}, {}), "bg.counter.day", "1.2 view background fallback")


func _card(type: String, def_id: String) -> Dictionary:
	return {"uid": "probe", "def": def_id, "type": type}


func _check_mock(t, bus: CardEventBus) -> void:
	var mock := MockCardEngine.new(bus)
	mock.new_game({"seed": 7})
	for command in [[&"wheel.spin", {"wheel": "wh.month", "uid": ""}], [&"month.begin", {}], [&"day.begin", {}]]:
		t.ok(mock.send(command[0], command[1]).get("ok", false), "new game command: %s" % command[0])
	t.eq(mock.view()["stage"]["time"], "day", "fresh day after dealing")
	var dealt: Array = mock.view()["hand"].duplicate(true)
	var boundary := int(ceil(dealt.size() * 0.6))
	t.ok(dealt.size() > 0, "new game dealt cards")
	for i in range(boundary):
		t.ok(mock.send(&"card.discard", {"uid": dealt[i]["uid"]}).get("ok", false), "remove dealt card %d" % i)
		t.eq(mock.view()["stage"]["time"], "dusk" if i + 1 == boundary else "day", "60 percent dusk boundary %d" % i)
		t.no_leaks(mock.view(), "day progress view")
	t.ok(mock.send(&"day.end", {"confirm": true}).get("ok", false), "day end reaches night")
	t.eq(mock.view()["stage"]["time"], "night", "night stage time")
	_check_night_offers(t, mock.view())
	for fixture in FIXTURES:
		mock.load_fixture(fixture)
		var view := mock.view()
		t.eq(view["stage"]["set"], "prison" if fixture == "street_prison" else "counter", fixture + " stage set")
		t.eq(view["stage"]["time"], "night" if fixture in ["night", "settle"] else "day", fixture + " stage time")
		t.eq(view["stage"]["sealed"], false, fixture + " stage sealed")
		t.no_leaks(view, fixture + " view")
		_check_card_fields(t, mock, view)
		var data: Dictionary = CardDB.read_json(mock.fixture_path)
		for key in data["queries"]:
			t.no_leaks(data["queries"][key], fixture + " query " + key)
		if fixture == "night":
			_check_night_offers(t, view)


func _check_night_offers(t, view: Dictionary) -> void:
	t.ok(not view["night_offers"].is_empty(), "night has offers")
	for offer in view["night_offers"]:
		t.ok(offer is Dictionary, "night offer is a dictionary")
		if offer is Dictionary:
			t.ok(offer.has("def") and offer.has("art") and offer.has("choices"), "night offer carries def/art/choices")
			t.ok(offer["choices"] is Array, "night offer choices are IDs")
			t.no_leaks(offer, "night offer")


func _check_card_fields(t, mock: MockCardEngine, view: Dictionary) -> void:
	for zone in ["hand", "kept", "contacts", "pending", "demands"]:
		for cv in view[zone]:
			for key in ["stage", "source", "wheel", "fortune"]:
				t.ok(cv.has(key), "%s CardView has %s" % [cv["def"], key])
			t.ok(not _has_key(cv["stage"], "brief"), "public stage omits every brief")
			var card := mock.query(&"card", {"uid": cv["uid"]})
			t.no_leaks(card, "card query " + cv["uid"])
			for key in ["stage", "source", "wheel", "fortune"]:
				t.ok(card.has(key), "%s detailed CardView has %s" % [cv["def"], key])
			t.ok(not _has_key(card.get("stage", {}), "brief"), "detailed stage omits every brief")
			if cv["type"] == "demand":
				for result in [cv, card]:
					t.ok(result.has("demand"), "demand CardView includes demand")
					var demand: Dictionary = result.get("demand", {})
					t.ok(demand.has("kind") and demand.has("tier"), "demand exposes kind and tier")


func _has_key(value, key: String) -> bool:
	if value is Dictionary:
		if value.has(key):
			return true
		for child in value.values():
			if _has_key(child, key):
				return true
	elif value is Array:
		for child in value:
			if _has_key(child, key):
				return true
	return false


## X01-b：W0 的桩删了，同一组冻结接口（§7.11.3–7.11.7、§7.8）改对着各主人的真控件验。
func _check_widgets(t, mock: MockCardEngine, bus: CardEventBus) -> void:
	var widgets: Dictionary = {}
	for kind in WIDGETS:
		var path := CardIds.panel_scene(WIDGETS[kind]) if kind == "panel" else CardIds.widget_scene(WIDGETS[kind])
		t.ok(ResourceLoader.exists(path) and not path.contains("/_w0/"), "%s is the owner scene: %s" % [kind, path])
		var node: Control = load(path).instantiate()
		widgets[kind] = node
		if node is CardPanel:
			node.bind(mock, bus)
		else:
			node.set("bus", bus)
			if node is CardChecksApi:
				node.set("engine", mock)
		root.add_child(node)
	await t.frames(1)
	_check_stage_widget(t, widgets["stage"], mock)
	_check_dialog_widget(t, widgets["dialog"])
	await _check_hand_widget(t, widgets["hand"], mock)
	_check_hero_widget(t, widgets["hero"], mock)
	await _check_checks_widget(t, widgets["checks"], mock)
	var panel: CardPanel = widgets["panel"]
	panel.open({})
	panel.refresh(mock.view())
	var sent := mock.sent.size()
	var closes: Array = []
	panel.close_requested.connect(func(result: Dictionary) -> void: closes.append(result))
	panel.dismiss()
	t.eq(closes, [{}], "drawer dismiss only closes")
	t.eq(panel.autoplay_step(), false, "closed drawer has no automatic step")
	t.eq(mock.sent.size(), sent, "drawer sends no command")
	await _check_stage_panel(t, widgets, mock, bus)
	for kind in widgets:
		var bad: PackedStringArray = t.all_text_from_cardtext(widgets[kind])
		t.ok(bad.is_empty(), "%s text comes from CardText: %s" % [kind, ", ".join(bad)])
		widgets[kind].queue_free()
	await t.frames(2)
	CardAnchors.clear()


func _check_stage_widget(t, stage: CardStageApi, mock: MockCardEngine) -> void:
	stage.set("fast", true)
	stage.refresh(mock.view())
	for anchor in ["a.scene", "a.scene.notice", "a.scene.ledger", "a.scene.notebook", "a.scene.calendar",
			"a.scene.cashbox", "a.scene.magnifier", "a.scene.notewall"]:
		t.ok(CardAnchors.has(StringName(anchor)), "stage registers " + anchor)
	var card := mock.query(&"card", {"uid": _uid(mock.view(), "p.linsao.1938.pawn_hairpin")})
	stage.play(CardStageScript.resolve(card, mock.view()))
	t.ok(CardAnchors.has(&"a.scene.customer"), "stage registers present customer")
	stage.set_items([{"item": "I001", "art": "item.jewelry.hairpin"}, {"item": "I002", "art": "item.utensils.bowl"}])
	stage.set_talking("linsao")
	stage.set_talking("")
	stage.set_dim_tools(true)
	stage.set_dim_tools(false)
	for spot in CardIds.STAGE_SPOTS:
		t.eq(stage.spot_rect(spot), CardLayout.spot(spot), "stage spot method: %s" % spot)
	stage.clear_play()
	t.ok(not CardAnchors.has(&"a.scene.customer"), "stage clears customer anchor")
	stage.refresh({})
	stage.refresh(mock.view())


func _check_dialog_widget(t, dialog: CardDialogApi) -> void:
	var lines := [{"kind": "narr", "who": "", "ref": "ev.1938.police_check#body", "args": {}, "opt": false}]
	dialog.show_lines("probe", lines)
	t.eq(dialog.current_uid(), "probe", "dialog tracks current uid")
	t.ok(CardAnchors.has(&"a.dialog"), "dialog registers its anchor")
	dialog.show_lines("probe", lines, true)
	dialog.set_replies([{"id": "pass", "ref": "w0.dialog.skip", "args": {}, "enabled": true,
		"reason_ref": "", "style": "choice", "anchor": "a.slots.roll", "echo": true}])
	t.ok(dialog.has_replies(), "dialog shows replies")
	t.ok(CardAnchors.has(&"a.slots.roll"), "reply registers supplied anchor")
	dialog.set_max_bottom(404)
	t.ok(CardAnchors.rect(&"a.dialog").end.y <= 404, "dialog honors checks bottom")
	dialog.set_max_bottom(520)
	t.ok(CardAnchors.rect(&"a.dialog").end.y <= 520, "dialog avoids fan when limited")
	dialog.skip()
	t.ok(dialog.is_idle(), "skip consumes queued lines")
	dialog.set_replies([])
	t.ok(not dialog.has_replies() and not CardAnchors.has(&"a.slots.roll"), "clearing replies removes their anchors")
	dialog.clear()
	t.eq(dialog.current_uid(), "", "clear resets dialog uid")
	t.ok(not CardAnchors.has(&"a.dialog"), "clear hides dialog anchor")
	dialog.set_max_bottom(570)


func _check_hand_widget(t, hand: CardHandApi, mock: MockCardEngine) -> void:
	hand.refresh(mock.view())
	await t.frames(1)
	for anchor in ["a.hand", "a.hand.gold", "a.hand.kept"]:
		t.ok(CardAnchors.has(StringName(anchor)), "hand registers " + anchor)
	var uid := str(mock.view()["hand"][0]["uid"])
	t.ok(hand.card_rect(uid).has_area(), "hand exposes card rectangle")
	hand.set_low(true)
	hand.set_low(false)
	hand.set_away(true)
	hand.set_away(false)
	var plays: Array = []
	hand.card_played.connect(func(p_uid: String, def_id: String, how: StringName) -> void: plays.append([p_uid, def_id, how]))
	hand.select_index(0)
	t.ok(hand.play_selected(), "selected hand card can play")
	t.ok(not plays.is_empty() and plays.back()[2] in [&"button", &"key"], "selected play reports button or key")
	t.ok(hand.play_uid(uid), "hand automatic play")
	t.eq(plays.back()[2], &"auto", "play_uid reports auto")
	t.eq(plays.back()[0], uid, "play_uid preserves uid")


func _check_hero_widget(t, hero: CardHeroApi, mock: MockCardEngine) -> void:
	hero.refresh(mock.view())
	t.ok(CardAnchors.has(&"a.hero"), "hero registers self")
	t.ok(CardAnchors.has(&"a.contacts"), "hero registers contacts")
	t.ok(t.anchor_in(&"a.hero", CardLayout.HERO), "hero anchor stays in its layout")


func _check_checks_widget(t, checks: CardChecksApi, mock: MockCardEngine) -> void:
	checks.show_checks(_uid(mock.view(), "ev.1938.police_check"))
	t.ok(checks.is_shown(), "checks show slots")
	t.ok(CardAnchors.has(&"a.slots.first"), "checks register first slot")
	t.ok(CardAnchors.has(&"a.slots.coins"), "checks register coin row")
	var preview := checks.preview()
	t.no_leaks(preview, "checks preview")
	var coins: Array = []
	checks.coins_finished.connect(func(success: bool) -> void: coins.append(success))
	# coins_finished 带真实成败（#209）：自动正面 + 这一把的正面 ≥ 要几个，或自动过。
	var auto := int(preview.get("auto_heads", 0))
	var pass_all := bool(preview.get("auto_pass", false))
	checks.play_coins([true, false, true], 2)
	checks.skip_coins()
	await t.frames(1)
	checks.play_coins([false, false, false], 1 + auto)
	checks.skip_coins()
	await t.frames(1)
	t.eq(coins, [true, pass_all], "coins_finished reports success, then failure")
	checks.hide_checks()
	t.ok(not checks.is_shown(), "checks hide")
	checks.show_checks(_uid(mock.view(), "dm.1938.money.t1"))
	t.ok(CardAnchors.has(&"a.slots.money"), "money checks register controls")
	checks.hide_checks()


func _check_stage_panel(t, widgets: Dictionary, mock: MockCardEngine, bus: CardEventBus) -> void:
	var panel := StagePanelProbe.new()
	panel.bind(mock, bus)
	panel.bind_stage(widgets["stage"], widgets["dialog"], widgets["checks"], widgets["hand"])
	root.add_child(panel)
	var uid := _uid(mock.view(), "ev.1938.police_check")
	var script := panel.begin_play(uid)
	await t.frames(1)
	t.eq(widgets["dialog"].current_uid(), uid, "begin_play routes uid to dialog")
	var first: Dictionary = script["intro"][0]
	var expected := CardText.t(first["ref"], first["args"])
	t.ok(_nodes(widgets["dialog"]).any(func(node: Node) -> bool:
			return (node is Label and node.text == expected) or (node is RichTextLabel and node.get_parsed_text() == expected)),
		"begin_play shows first police line")
	for spot in [&"door_l", &"door_r"]:
		var actors: Array = _nodes(widgets["stage"]).filter(func(node: Node) -> bool:
			return (node is TextureRect and str(node.get_meta("who", "")) == "ex_patrol" and
				str(node.get_meta("at", "")) == str(spot)))
		t.eq(actors.size(), 1, "begin_play creates one patrol at %s" % spot)
		if not actors.is_empty():
			var actor: TextureRect = actors[0]
			# 正在说话的人上下动 1 场景像素（§7.11.3 set_talking），所以 y 允许差 4 屏幕像素。
			var got := actor.get_global_rect()
			var want := CardLayout.spot(spot)
			t.ok(got.size == want.size and got.position.x == want.position.x and absf(got.position.y - want.position.y) <= 4.0,
				"patrol occupies frozen %s rectangle: %s" % [spot, got])
			var art := "walk.ex_patrol" if CardArt.base_size("walk.ex_patrol") != Vector2i.ZERO else "portrait.ex_patrol"
			var tex: Texture2D = actor.texture
			if tex is AtlasTexture:
				tex = (tex as AtlasTexture).atlas
			t.eq(tex, CardArt.texture(art), "patrol uses CardArt resolution (%s)" % art)
	panel.on_reply("pass")
	t.eq(panel.on_card_played(uid, "ev.1938.police_check"), false, "default panel does not consume a new play")
	t.eq(panel.on_hotspot(&"ledger"), false, "default panel does not consume a hotspot")
	panel.end_play()
	t.ok(not CardAnchors.has(&"a.dialog") and not widgets["checks"].is_shown(), "end_play clears dialog and checks")
	panel.queue_free()
	await t.frames(1)


func _uid(view: Dictionary, def_id: String) -> String:
	for zone in ["hand", "kept", "contacts", "pending", "demands"]:
		for card in view[zone]:
			if card["def"] == def_id:
				return str(card["uid"])
	return ""


func _nodes(node: Node) -> Array:
	var result: Array = [node]
	for child in node.get_children():
		result.append_array(_nodes(child))
	return result
