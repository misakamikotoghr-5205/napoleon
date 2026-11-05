# W0 骨架自测①：每个脚本都能加载、每个场景都能实例化；冻结的类名、方法签名（参数个数）、信号都和合同一致；
# CardIds 的目录（70 个机制、锚点、界面事件、随机数域）齐全。合同：docs/cards/CARDS_INTERFACES.md §7、§7.10、附录 A。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
## 1.2 的 7 个旧锚点名 → 1.3 新名（X01-b 删掉旧名后，这里只用来确认旧名真的没了、新名有主人）
const RENAMED_1_2: Array = [["a.top.notice", "a.scene.notice"], ["a.left.self", "a.hero"],
	["a.left.contacts", "a.contacts"], ["a.left.kept", "a.hand.kept"], ["a.right.tickets", "a.scene.ledger"],
	["a.right.shelf", "a.tab.shelf"], ["a.right.dossier", "a.scene.notebook"]]

## 类名 → {"path": 路径, "m": {方法: 参数个数}, "s": [信号]}
const API := {
	"CardEngineApi": {"path": "res://scripts/cards/api/card_engine_api.gd", "m": {"new_game": 1, "load_game": 1,
		"save_game": 1, "view": 0, "send": 2, "query": 2, "is_busy": 0}},
	"CardMiniGame": {"path": "res://scripts/cards/api/card_minigame.gd", "m": {"kind": 0, "start": 1, "autoplay": 1,
		"abort": 0, "minutes_spent": 0}, "s": ["finished"]},
	"CardIds": {"path": "res://scripts/cards/api/card_ids.gd", "m": {}},
	"CardShip": {"path": "res://scripts/cards/api/card_ship.gd", "m": {"is_ship": 0}},
	"CardDslShapes": {"path": "res://scripts/cards/api/dsl_shapes.gd", "m": {"shape": 2, "check_stage": 1}},
	"CardEventBus": {"path": "res://scripts/cards/core/card_bus.gd", "m": {}, "s": ["phase_changed", "view_changed",
		"cards_dealt", "card_updated", "card_left", "coins_tossed", "wheel_spun", "money_changed", "tier_changed",
		"dossier_changed", "notice", "minigame_requested", "request_panel", "game_over", "saved", "first_time",
		"command_done", "ui_event"]},
	"CardDB": {"path": "res://scripts/cards/core/card_db.gd", "m": {"load_all": 2, "def": 1, "has": 1, "ids_of": 1,
		"pool": 2, "persons": 0, "rules": 1, "tags": 0, "text_entry": 1, "brief_of": 1, "obs_catalog": 1,
		"art_manifest": 0, "stage": 1, "hash": 0, "errors": 0}},
	"CardState": {"path": "res://scripts/cards/core/card_state.gd", "m": {"create": 2, "ns": 1, "to_dict": 0,
		"from_dict": 2, "hash": 0, "new_uid": 0}},
	"CardCtx": {"path": "res://scripts/cards/core/card_ctx.gd", "m": {"seed": 0, "abs_day": 0, "draw": 2, "emit": 2,
		"run": 2, "test": 1, "rules": 1}},
	"CardOps": {"path": "res://scripts/cards/core/card_ops.gd", "m": {"register": 4, "run": 3, "validate": 1, "known": 0}},
	"CardConds": {"path": "res://scripts/cards/core/card_conds.gd", "m": {"register": 4, "test": 2, "validate": 1}},
	"CardMods": {"path": "res://scripts/cards/core/card_mods.gd", "m": {"register": 3, "sum_int": 3, "pct": 3,
		"collect": 3, "any_true": 3, "merge": 3}},
	"CardHooks": {"path": "res://scripts/cards/core/card_hooks.gd", "m": {"on": 4, "fire": 3}},
	"CardActions": {"path": "res://scripts/cards/core/card_actions.gd", "m": {"register": 3, "for_card": 2}},
	"CardPiles": {"path": "res://scripts/cards/core/card_piles.gd", "m": {"spawn": 4, "move": 3, "zone_of": 2,
		"list": 2, "card": 2, "def_of": 2, "keep": 2, "resolve": 4, "order_hand": 1, "discard": 2, "expire": 2, "cap": 2}},
	"CardComposer": {"path": "res://scripts/cards/core/card_composer.gd", "m": {"compose": 1, "project": 2,
		"night_offers": 1, "street_deal": 1}},
	"CardSave": {"path": "res://scripts/cards/core/card_save.gd", "m": {"set_root": 1, "root": 0, "suspend_path": 0,
		"stage_path": 1, "write": 3, "read": 1, "exists": 1}},
	"CardText": {"path": "res://scripts/cards/core/card_text.gd", "m": {"setup": 1, "ui": 2, "card": 3, "t": 2,
		"person_name": 1, "item_text": 2, "obs": 1, "is_draft": 1, "issued_contains": 1}},
	"CardValidator": {"path": "res://scripts/cards/core/card_validator.gd", "m": {"validate": 3}},
	"CardFirsts": {"path": "res://scripts/cards/core/firsts.gd", "m": {"mark": 3, "all": 1}},
	"CardCoreInstall": {"path": "res://scripts/cards/core/core_install.gd", "m": {"install": 2}},
	"CardEngine": {"path": "res://scripts/cards/loop/card_engine.gd", "m": {"register_command": 3, "register_query": 3,
		"new_game": 1, "load_game": 1, "save_game": 1, "view": 0, "send": 2, "query": 2, "is_busy": 0}},
	"CardDayLoop": {"path": "res://scripts/cards/loop/day_loop.gd", "m": {"begin_stage": 2, "open_month": 1,
		"begin_day": 1, "end_day": 2, "choose_night": 2, "settle": 1, "close_month": 1, "jump_year": 1, "set_phase": 2,
		"advance_minutes": 2, "request_panel": 3, "set_mode": 2}},
	"CardCalendar": {"path": "res://scripts/cards/loop/calendar.gd", "m": {"today": 1, "date_of": 2,
		"is_market_day": 2, "week_of": 2}},
	"CardSchedule": {"path": "res://scripts/cards/loop/schedule.gd", "m": {"due": 2}},
	"CardGoldRule": {"path": "res://scripts/cards/loop/gold_rule.gd", "m": {"hand_sub": 2, "pending": 1, "leave": 2}},
	"CardGoals": {"path": "res://scripts/cards/loop/goals.gd", "m": {"pick": 1, "evaluate": 2, "verdict_key": 1}},
	"CardYearJump": {"path": "res://scripts/cards/loop/year_jump.gd", "m": {"run": 1}},
	"CardViewModel": {"path": "res://scripts/cards/loop/view_model.gd", "m": {"build": 1, "card_view": 3, "leaks": 1}},
	"CardLoopInstall": {"path": "res://scripts/cards/loop/loop_install.gd", "m": {"install": 2}},
	"CardSlots": {"path": "res://scripts/cards/rules/slots.gd", "m": {"slots_of": 2, "can_place": 4, "place": 4,
		"remove": 4, "preview": 2, "roll": 2}},
	"CardCoins": {"path": "res://scripts/cards/rules/coins.gd", "m": {"toss": 4}},
	"CardChoices": {"path": "res://scripts/cards/rules/choices.gd", "m": {"options": 2, "choose": 3}},
	"CardEffectsCore": {"path": "res://scripts/cards/rules/effects_core.gd", "m": {}},
	"CardCondsCore": {"path": "res://scripts/cards/rules/conds_core.gd", "m": {}},
	"CardMeters": {"path": "res://scripts/cards/rules/meters.gd", "m": {"value": 2, "tier": 2, "add": 4, "bump_tier": 4,
		"attr": 3, "add_attr": 6}},
	"CardKeptRules": {"path": "res://scripts/cards/rules/kept_rules.gd", "m": {"bonus": 3, "run_risk": 3}},
	"CardDemands": {"path": "res://scripts/cards/rules/demands.gd", "m": {"issue": 1, "submit": 2, "delay": 2,
		"days_left": 2, "on_settle": 1}},
	"CardDossier": {"path": "res://scripts/cards/rules/dossier.gd", "m": {"add": 2, "gap": 2, "year_after": 1, "view": 2}},
	"CardRulesInstall": {"path": "res://scripts/cards/rules/rules_install.gd", "m": {"install": 2}},
	"CardCounter": {"path": "res://scripts/cards/economy/counter.gd", "m": {"open": 2, "offer": 3, "answer": 3,
		"pick_stock": 3, "redeem": 3, "refuse": 2, "close": 2, "view": 2}},
	"CardPricing": {"path": "res://scripts/cards/economy/pricing.gd", "m": {"tiers": 2}},
	"CardCustomer": {"path": "res://scripts/cards/economy/customer.gd", "m": {"reply": 3, "spend_patience": 3}},
	"CardShelf": {"path": "res://scripts/cards/economy/shelf.gd", "m": {"items": 1, "cap": 1, "add": 3, "remove": 3,
		"view": 1}},
	"CardTickets": {"path": "res://scripts/cards/economy/tickets.gd", "m": {"open": 5, "tick": 1, "forfeit_all": 1,
		"view": 1}},
	"CardAppraisal": {"path": "res://scripts/cards/economy/appraisal.gd", "m": {"request": 3, "params_for": 3,
		"report": 4}},
	"CardItems": {"path": "res://scripts/cards/economy/items.gd", "m": {"generate": 3, "templates": 0}},
	"CardCurrency": {"path": "res://scripts/cards/economy/currency.gd", "m": {"apply_stage": 2, "convert": 4, "money": 1}},
	"CardMonthAccounts": {"path": "res://scripts/cards/economy/month_accounts.gd", "m": {"close": 1}},
	"CardEconomyInstall": {"path": "res://scripts/cards/economy/economy_install.gd", "m": {"install": 2}},
	"CardMortgage": {"path": "res://scripts/cards/ladder/mortgage.gd", "m": {"mortgage": 2, "redeem": 2,
		"on_month_close": 1, "view": 1}},
	"CardShortLadder": {"path": "res://scripts/cards/ladder/short_ladder.gd", "m": {"on_short": 2, "view": 1, "resolve": 2}},
	"CardStreet": {"path": "res://scripts/cards/ladder/street.gd", "m": {"enter": 1, "redeem_shop": 1, "shop_price": 1}},
	"CardPrison": {"path": "res://scripts/cards/ladder/prison.gd", "m": {"arrest": 2}},
	"CardLadderInstall": {"path": "res://scripts/cards/ladder/ladder_install.gd", "m": {"install": 2}},
	"CardWeights": {"path": "res://scripts/cards/fate/weights.gd", "m": {"rows": 2}},
	"CardFateTrigger": {"path": "res://scripts/cards/fate/fate_trigger.gd", "m": {"fate_due": 1, "crisis": 1, "on_crisis": 2}},
	"CardWheel": {"path": "res://scripts/cards/fate/wheel.gd", "m": {"view": 3, "offer": 4, "withdraw": 4, "stake": 4,
		"spin": 3, "weights": 3}},
	"CardFortune": {"path": "res://scripts/cards/fate/fortune.gd", "m": {"draw_lot": 2, "cezi": 3, "offer_chars": 1}},
	"CardAlmanac": {"path": "res://scripts/cards/fate/almanac.gd", "m": {"today": 1, "note": 2, "settle": 1}},
	"CardPins": {"path": "res://scripts/cards/fate/pins.gd", "m": {"pin": 4, "pinned": 2, "ban": 4, "banned": 2}},
	"CardPressure": {"path": "res://scripts/cards/fate/pressure.gd", "m": {"step_day": 1, "value_milli": 2}},
	"CardFateInstall": {"path": "res://scripts/cards/fate/fate_install.gd", "m": {"install": 2}},
	"CardPolicy": {"path": "res://scripts/cards/sim/policy.gd", "m": {"policy_name": 0, "decide": 2}},
	"CardAutoplay": {"path": "res://scripts/cards/sim/autoplay.gd", "m": {"play": 3}},
	"CardReplay": {"path": "res://scripts/cards/sim/replay.gd", "m": {"record": 1, "replay": 2}},
	"MockCardEngine": {"path": "res://scripts/cards/mock/mock_engine.gd", "m": {"load_fixture": 1, "new_game": 1,
		"send": 2, "query": 2, "view": 0}},
	"CardLayout": {"path": "res://scripts/cards/api/card_layout.gd", "m": {"screen": 1, "spot": 1,
		"prop_rect": 2, "slot_rect": 2, "coin_rect": 2}},
	"CardStageApi": {"path": "res://scripts/cards/ui/common/card_stage_api.gd", "m": {"refresh": 1, "play": 1,
		"clear_play": 0, "set_items": 1, "set_talking": 1, "set_dim_tools": 1, "spot_rect": 1},
		"s": ["hotspot_pressed", "card_dropped"]},
	"CardDialogApi": {"path": "res://scripts/cards/ui/common/card_dialog_api.gd", "m": {"show_lines": 3,
		"set_replies": 1, "clear": 0, "skip": 0, "is_idle": 0, "has_replies": 0, "set_max_bottom": 1, "current_uid": 0},
		"s": ["advanced", "lines_done", "reply_chosen"]},
	"CardHandApi": {"path": "res://scripts/cards/ui/common/card_hand_api.gd", "m": {"refresh": 1, "set_low": 1,
		"set_away": 1, "select_index": 1, "play_selected": 0, "play_uid": 1, "card_rect": 1},
		"s": ["card_played", "card_selected"]},
	"CardHeroApi": {"path": "res://scripts/cards/ui/common/card_hero_api.gd", "m": {"refresh": 1}, "s": ["person_pressed"]},
	"CardChecksApi": {"path": "res://scripts/cards/ui/common/card_checks_api.gd", "m": {"show_checks": 1,
		"hide_checks": 0, "is_shown": 0, "preview": 0, "play_coins": 2, "skip_coins": 0}, "s": ["changed", "coins_finished"]},
	"CardStagePanel": {"path": "res://scripts/cards/ui/common/card_stage_panel.gd", "m": {"bind_stage": 4,
		"begin_play": 1, "end_play": 0, "on_reply": 1, "on_card_played": 2, "on_hotspot": 1, "bind": 2,
		"open": 1, "refresh": 1, "autoplay_step": 0, "dismiss": 0}, "s": ["close_requested"]},
	"CardStageScript": {"path": "res://scripts/cards/ui/common/card_stage_script.gd", "m": {"resolve": 2,
		"lines": 2, "bg_id": 2, "speaker": 1}},
	"CardPanel": {"path": "res://scripts/cards/ui/common/card_panel.gd", "m": {"bind": 2, "open": 1, "refresh": 1,
		"autoplay_step": 0, "dismiss": 0}, "s": ["close_requested"]},
	"CardAnchors": {"path": "res://scripts/cards/ui/common/card_anchors.gd", "m": {"register": 3, "unregister": 2,
		"rect": 1, "has": 1, "ids": 0, "clear": 0}},
	"CardTheme": {"path": "res://scripts/cards/ui/common/card_theme.gd", "m": {"color": 1, "frame_style": 2,
		"font_title": 0, "font_body": 0}},
	"CardGuide": {"path": "res://scripts/cards/ui/shell/card_guide.gd", "m": {"bind": 2, "set_enabled": 1,
		"is_enabled": 0, "force": 1, "evaluate_now": 0, "active_step": 0, "tick": 1, "load_steps": 1}},
	"CardWidget": {"path": "res://scripts/cards/ui/card/card_widget.gd", "m": {"set_card": 1, "set_size_mode": 1,
		"set_highlight": 1, "get_uid": 0}, "s": ["pressed", "action_requested"]},
	"CardArt": {"path": "res://scripts/cards/ui/card/card_art.gd", "m": {"texture": 1, "path": 1, "is_placeholder": 1,
		"base_size": 1}},
	"CardSlotWidget": {"path": "res://scripts/cards/ui/slots/slot_widget.gd", "m": {"set_slot": 2},
		"s": ["place_requested", "remove_requested"]},
	"CardCoinTossView": {"path": "res://scripts/cards/ui/slots/coin_toss.gd", "m": {"play": 2, "skip": 0}, "s": ["finished"]},
	"CardDemandBoard": {"path": "res://scripts/cards/ui/demand/demand_board.gd", "m": {"refresh": 1}, "s": ["demand_pressed"]},
	"CardAlmanacStrip": {"path": "res://scripts/cards/ui/fortune/almanac_strip.gd", "m": {"refresh": 1}},
	"CardAlmanacDrawer": {"path": "res://scripts/cards/ui/fortune/almanac_drawer.gd", "m": {"bind": 2, "open": 1,
		"refresh": 1, "autoplay_step": 0, "dismiss": 0}, "s": ["close_requested"]},
	"CardStreetOverlay": {"path": "res://scripts/cards/ui/ladder/street_overlay.gd", "m": {"refresh": 1},
		"s": ["redeem_shop_pressed"]},
	"CardTitle": {"path": "res://scripts/cards/ui/shell/card_title.gd", "m": {}, "s": ["chose"]},
	"CardGameRoot": {"path": "res://scripts/cards/ui/table/card_game_root.gd", "m": {"boot": 1}},
	"CardModalHost": {"path": "res://scripts/cards/ui/table/modal_host.gd", "m": {"open_panel": 2}},
	"CardMiniGameHost": {"path": "res://scripts/cards/ui/table/minigame_host.gd", "m": {}},
}


func _initialize() -> void:
	var t := T.new(self, "W0_skeleton")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_check_api(t)
	_check_state_loader(t)
	_check_scene_paths(t)
	for f in _files("res://scripts/cards", ".gd") + _files("res://scripts/tests/cards/lib", ".gd"):
		t.ok(load(f) is Script, "script loads: " + f)
	await _check_scenes(t)
	_check_catalog(t)


func _check_api(t) -> void:
	var globals: Dictionary = {}
	for g in ProjectSettings.get_global_class_list():
		globals[str(g["class"])] = str(g["path"])
	for cls in API.keys():
		var spec: Dictionary = API[cls]
		t.eq(globals.get(cls, ""), spec["path"], "class_name %s lives at" % cls)
		var scr: Script = load(spec["path"])
		t.ok(scr != null, "load " + spec["path"])
		if scr == null:
			continue
		var methods := _script_methods(scr)
		for m in spec["m"].keys():
			t.eq(methods.get(m, -1), spec["m"][m], "%s.%s argument count" % [cls, m])
		var sigs := _script_signals(scr)
		for sig in spec.get("s", []):
			t.ok(sigs.has(sig), "%s has signal %s" % [cls, sig])


func _check_state_loader(t) -> void:
	# The integrated loader added an optional fast path; the documented
	# one-argument call must still restore JSON integers by default.
	var script: Script = load("res://scripts/cards/core/card_state.gd")
	var found := false
	for method in script.get_script_method_list():
		if str(method["name"]) == "from_dict":
			found = true
			t.eq(method.get("default_args", []), [true], "from_dict keeps exactly one optional argument, default true")
			t.eq(method["args"][1]["name"], "restore_ints", "from_dict optional argument is restore_ints")
			t.eq(method["args"][1]["type"], TYPE_BOOL, "from_dict optional argument is boolean")
	t.ok(found, "from_dict metadata exists")
	var source := CardState.create(7, {}).to_dict()
	source["seed"] = 7.0
	source["extension"] = {"nested": [3.0]}
	var restored := CardState.from_dict(source)
	t.ok(restored != null, "documented one-argument from_dict remains callable")
	if restored != null:
		t.eq(typeof(restored.data["seed"]), TYPE_INT, "one-argument load restores seed integer")
		t.eq(typeof(restored.data["extension"]["nested"][0]), TYPE_INT, "one-argument load restores unknown namespace integers")
	t.eq(typeof(source["seed"]), TYPE_FLOAT, "one-argument load does not mutate input")


func _script_methods(script: Script) -> Dictionary:
	var methods: Dictionary = {}
	var current := script
	while current != null:
		for method in current.get_script_method_list():
			var method_name := str(method["name"])
			if not methods.has(method_name):
				methods[method_name] = (method["args"] as Array).size()
		current = current.get_base_script()
	return methods


func _script_signals(script: Script) -> Array:
	var signals: Array = []
	var current := script
	while current != null:
		for sig in current.get_script_signal_list():
			signals.append(str(sig["name"]))
		current = current.get_base_script()
	return signals


func _check_scene_paths(t) -> void:
	for kind in CardIds.PANELS:
		if kind == &"minigame":
			t.eq(CardIds.panel_scene(kind), "", "minigame uses its own host")
			continue
		# X01-b：W0 的 PanelStub 已删，每个 kind 都必须是主人自己的场景，根是 CardPanel。
		var path := CardIds.panel_scene(kind)
		t.eq(path, str(CardIds.PANEL_SCENES.get(kind, "")), "panel scene is the owner scene: %s" % kind)
		t.ok(ResourceLoader.exists(path), "panel scene for %s exists" % kind)
		t.ok(not path.contains("/_w0/"), "panel scene is not a W0 stub: %s" % kind)
		var ps := load(path) as PackedScene if ResourceLoader.exists(path) else null
		if ps != null:
			var node := ps.instantiate()
			t.ok(node is CardPanel, "panel scene root is a CardPanel: %s" % kind)
			node.free()
	t.eq(CardIds.panel_scene(&"no_such_panel"), "", "unknown panel kind has no scene")
	for kind in CardIds.MINIGAME_SCENES.keys():
		t.ok(ResourceLoader.exists(str(CardIds.MINIGAME_SCENES[kind])), "minigame scene for %s exists" % kind)
	for w in CardIds.WIDGET_SCENES.keys():
		var path := CardIds.widget_scene(w)
		t.eq(path, str(CardIds.WIDGET_SCENES[w]), "widget scene is the owner scene: %s" % w)
		t.ok(ResourceLoader.exists(path), "widget scene %s exists" % w)
		t.ok(not path.contains("/_w0/"), "widget scene is not a W0 stub: %s" % w)
	t.eq(CardIds.widget_scene(&"no_such_widget"), "", "unknown widget has no scene")
	var ids: Dictionary = (load("res://scripts/cards/api/card_ids.gd") as GDScript).get_script_constant_map()
	for gone in ["PANEL_STUB", "WIDGET_STUBS", "ANCHORS_RENAMED"]:
		t.ok(not ids.has(gone), "W0 transition constant removed: " + gone)
	t.ok(not ResourceLoader.exists("res://scenes/cards/_w0/PanelStub.tscn"), "W0 stub scenes removed")
	t.ok(not ResourceLoader.exists("res://scripts/cards/ui/common/w0_stub.gd"), "W0 stub helper removed")


func _check_scenes(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	mock.load_fixture("day_full")
	for f in _files("res://scenes/cards", ".tscn"):
		var ps: PackedScene = load(f)
		t.ok(ps != null, "scene loads: " + f)
		if ps == null:
			continue
		var n := ps.instantiate()
		t.ok(n is Control, "scene root is a Control: " + f)
		if n is CardPanel:
			(n as CardPanel).bind(mock, bus)
		if f.ends_with("CardGame.tscn"):
			(n as CardGameRoot).boot({"mock": true, "bus": bus, "fixture": "day_full", "skip_title": true})
		root.add_child(n)
		if n is CardPanel:
			(n as CardPanel).open({"uid": "c0002"})
			(n as CardPanel).refresh(mock.view())
		await t.frames(1)
		n.queue_free()
		await t.frames(1)
	mock = null
	bus.queue_free()
	await t.frames(2)


func _check_catalog(t) -> void:
	t.eq(CardIds.FIRSTS.size(), 70, "CardIds.FIRSTS has 70 mechanisms (7.10.10; 1.4 office + K18 pet + K18 apprentice + scare)")
	var owners: Dictionary = {}
	for m in CardIds.FIRSTS.keys():
		owners[CardIds.FIRSTS[m]] = int(owners.get(CardIds.FIRSTS[m], 0)) + 1
	t.eq(owners, {"G01": 7, "G02": 13, "G03": 21, "G04": 12, "G05": 12, "G06": 4, "K18": 1}, "first-time emitters per task (3.2; office + pet + apprentice + scare)")
	for a in CardIds.ANCHORS.keys():
		t.ok(CardIds.is_known_anchor(str(a) + ("@c0001" if CardIds.CARD_ANCHORS.has(a) else "")), "anchor known: %s" % a)
	t.ok(CardIds.is_known_anchor("a.card@{uid}") and not CardIds.is_known_anchor("a.card") and
		not CardIds.is_known_anchor("a.hand@c0001") and not CardIds.is_known_anchor("a.nope"), "anchor id rules")
	for d in ["c.deal.person", "c.deal.n.news", "c.coin", "c.wheel.wh.month", "pressure:c_unrest", "wheel:c_climate",
			"item_quality", "c.mg.spot.layout", "c.ai.fair", "c.street.beg", "c.year.ma", "c.mock"]:
		t.ok(CardIds.rng_owner(d) != "", "rng domain registered: " + d)
	for d in ["c.mg.", "c.deal.bogus", "random", "c.wheel.month"]:
		t.eq(CardIds.rng_owner(d), "", "rng domain not registered: " + d)
	for k in ["paper", "ink", "seal", "gold", "shade", "frame_gold", "frame_person", "guide_glow", "guide_bubble", "guide_ink",
			"dialog_bg", "night_tint", "btn_day", "guide_note"]:
		t.ok(CardTheme.color(StringName(k)).a > 0.0, "dev palette has " + k)
	_check_stage_catalog(t)


func _check_stage_catalog(t) -> void:
	var shows: Array = CardIds.PANEL_SHOW.keys()
	var panels: Array = CardIds.PANELS.duplicate()
	shows.sort()
	panels.sort()
	t.eq(shows, panels, "PANEL_SHOW covers exactly PANELS")
	# X01-b：1.2 的 7 个旧锚点名删掉了（W1 过渡结束）；它们的新名都归一条 C 线。
	for pair in RENAMED_1_2:
		t.ok(not CardIds.ANCHORS.has(StringName(pair[0])), "old 1.2 anchor removed: %s" % pair[0])
		t.ok(not CardIds.is_known_anchor(pair[0]), "old 1.2 anchor is unknown: %s" % pair[0])
		var owner := str(CardIds.ANCHORS.get(StringName(pair[1]), ""))
		t.ok(owner.begins_with("C") and owner.substr(1).is_valid_int(), "new anchor has task owner: %s" % pair[1])
	for a in CardIds.ANCHORS.keys():
		var owner := str(CardIds.ANCHORS[a])
		t.ok(owner != "renamed", "no anchor is a renamed placeholder: %s" % a)
	var events: Array = CardIds.UI_EVENTS.keys().map(func(k) -> String: return str(k))
	var expected: Array = ["panel_opened", "panel_closed", "drawer_opened", "drawer_closed", "hotspot_pressed",
		"hand_selected", "hand_played", "card_zoomed", "card_drag_started", "slot_drop", "dialog_advanced", "dialog_skipped",
		"reply_chosen", "mg_tool", "guide_shown", "guide_done"]
	events.sort()
	expected.sort()
	t.eq(events, expected, "UI_EVENTS matches all 16 frozen events")
	for hotspot in CardIds.HOTSPOTS:
		var r: Rect2 = CardLayout.HOTSPOTS[hotspot]
		t.ok(r.has_area() and Rect2(0, 0, 1280, 720).encloses(r), "hotspot has screen rectangle: %s" % hotspot)


func _files(dir: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d, ext))
	return out
