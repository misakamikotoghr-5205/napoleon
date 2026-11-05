# Real engine. Default --examples=true keeps the example set.
# --examples=false boots real K data (same ids: coal, jewel cabinet, mystery box, police).
# Cannot pay -> broke panel pawns an estate -> debt clears, then arrest -> prison -> engine roll.
# Faces, need and success are the engine coins_tossed signal. Outcome is not written into state.
# Boot: CardEngine seed 7, save_dir t.user_dir().
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C11/support.gd")
const PRISON_SCENE := "res://scenes/cards/ladder/PrisonPanel.tscn"
const COAL := "lf.any.coal_out"
const CABINET := "es.jewel_cabinet"
const BOX := "kp.mystery_box"
const POLICE := "ev.1938.police_check"


func _initialize() -> void:
	var examples: bool = _arg("--examples=", "true") != "false"
	var t = T.new(self, _arg("--name=", "C11_real_engine"))
	t.run_async(_body.bind(t, examples))


func _body(t, examples: bool) -> void:
	CardTheme.font_body()
	var bus: CardEventBus = CardEventBus.new()
	root.add_child(bus)
	var asked: PackedStringArray = PackedStringArray()
	var tossed: Array = []
	bus.request_panel.connect(func(kind: StringName, _args: Dictionary) -> void:
		asked.append(str(kind)))
	bus.coins_tossed.connect(func(uid: String, faces: Array, need: int, success: bool) -> void:
		tossed.append({"uid": uid, "faces": faces.duplicate(), "need": need, "success": success}))
	var engine: CardEngine = CardEngine.new(bus)
	var started: Dictionary = engine.new_game({
		"seed": 7,
		"only_examples": examples,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(started.get("ok", false)), "real engine boots: " + str(started.get("err", "")))
	await t.frames(1)
	var cost: Dictionary = _ladder_pay(engine)
	var due: int = int(cost.get("amount", 0))
	t.eq(str(cost.get("short", "")), "ladder", "example cost short is ladder")
	t.ok(due > 0, "example ladder cost has an amount")
	var have: int = CardCurrency.money(engine.ctx)
	engine.ctx.run([{"op": "money", "delta": -have, "reason": "g06.short.payment"}], "C11_DRAIN")
	var broke: int = CardCurrency.money(engine.ctx)
	t.ok(broke < due, "cannot pay the ladder cost")
	var coal_uid: String = CardPiles.spawn(engine.ctx, COAL, CardIds.ZONE_HAND)
	t.ok(coal_uid != "", "coal card is in hand")
	var chosen: Dictionary = engine.send(&"card.choose", {"uid": coal_uid, "choice": "buy"})
	t.ok(bool(chosen.get("ok", false)), "buy runs the ladder pay: " + str(chosen.get("err", "")))
	var opened: Dictionary = engine.view().get("open_panel", {})
	t.eq(str(opened.get("kind", "")), "short", "broke panel requested")
	t.ok(asked.has("short"), "engine asked for the short panel")
	var panel_args: Dictionary = opened.get("args", {})
	var options: Array = []
	var raw_options: Variant = panel_args.get("options", [])
	if typeof(raw_options) == TYPE_ARRAY:
		options = raw_options
	t.ok(options.has("estate"), "estate path is open")
	var offer: int = _estate_money(engine, CABINET)
	t.ok(offer >= due, "jewelry cabinet covers the shortage")
	var host: CardModalHost = CardModalHost.new()
	host.bind(engine, bus)
	root.add_child(host)
	var short_panel: CardPanel = host.open_panel(&"short", panel_args)
	await t.frames(2)
	t.ok(short_panel is CardShortPanel, "broke panel is CardShortPanel")
	var pawn: Button = Support.find(short_panel, "estate_es_jewel_cabinet") as Button
	t.ok(pawn != null, "jewelry cabinet button")
	if pawn != null:
		pawn.pressed.emit()
	await t.frames(1)
	t.eq(_estate_status(engine, CABINET), "mortgaged", "pawned the jewelry cabinet")
	t.ok(engine.query(&"short").is_empty(), "ladder cost paid")
	t.eq(CardCurrency.money(engine.ctx), broke + offer - due, "pawn money paid the ladder cost")
	t.ok(_logged(engine, "short.resolve", {"by": "estate", "estate": CABINET}), "panel sent the pawn")
	var box_uid: String = CardPiles.spawn(engine.ctx, BOX, CardIds.ZONE_KEPT)
	t.ok(box_uid != "", "contraband box is kept")
	var police_uid: String = CardPiles.spawn(engine.ctx, POLICE, CardIds.ZONE_HAND)
	t.ok(police_uid != "", "police check is in hand")
	var police: Dictionary = engine.send(&"slot.roll", {"uid": police_uid})
	t.ok(bool(police.get("ok", false)), "police roll: " + str(police.get("err", "")))
	t.ok(not bool(police.get("success", true)), "failed check uncovers the box")
	var jailed: Dictionary = engine.view().get("open_panel", {})
	t.eq(str(jailed.get("kind", "")), "prison", "arrested opens the prison panel")
	t.ok(asked.find("prison") > asked.find("short"), "prison panel comes after the broke panel")
	var prison_uid: String = str(jailed.get("args", {}).get("uid", ""))
	t.eq(str(engine.query(&"card", {"uid": prison_uid}).get("def", "")), "pr.cell", "prison card is the cell")
	var before: int = engine.command_log().size()
	var prison: CardPrisonPanel = (load(PRISON_SCENE) as PackedScene).instantiate() as CardPrisonPanel
	var rig: Dictionary = Support.mount_stage(root, prison, engine, bus)
	var closed: Array = [false]
	prison.close_requested.connect(func(_reason: Dictionary) -> void:
		closed[0] = true)
	prison.open({"uid": prison_uid})
	await t.frames(2)
	prison.on_reply("try")
	await t.frames(1)
	prison.on_reply("roll")
	var checks: Node = rig["checks"]
	if checks != null and checks.has_method("skip_coins"):
		checks.skip_coins()
	await t.frames(2)
	var toss: Dictionary = _toss_for(tossed, prison_uid)
	t.ok(not toss.is_empty(), "engine tossed for the cell")
	t.eq(prison._faces, toss.get("faces", []), "panel faces match the engine")
	t.eq(prison._need, int(toss.get("need", -1)), "panel need matches the engine")
	t.eq(prison._success, bool(toss.get("success", true)), "panel success matches the engine")
	t.ok(bool(closed[0]), "prison panel closes after the roll")
	t.ok(_logged_after(engine, before, "slot.roll", prison_uid), "panel rolled the cell")
	t.eq(_game_cmds_after(engine, before), 0, "panel sends no game command")
	for node in [short_panel, host, prison, rig["stage"], rig["dialog"], rig["checks"], rig["hand"], bus]:
		if is_instance_valid(node) and node is Node:
			(node as Node).queue_free()
	await t.frames(3)


func _ladder_pay(engine: CardEngine) -> Dictionary:
	var coal: Dictionary = engine.ctx.db.def(COAL)
	var choices: Variant = coal.get("choices", [])
	if typeof(choices) != TYPE_ARRAY:
		return {}
	for row in choices:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		if str((row as Dictionary).get("id", "")) != "buy":
			continue
		var effects: Variant = (row as Dictionary).get("effects", [])
		if typeof(effects) != TYPE_ARRAY:
			continue
		for eff in effects:
			if typeof(eff) != TYPE_DICTIONARY:
				continue
			var pay: Dictionary = eff
			if str(pay.get("op", "")) == "pay" and str(pay.get("short", "")) == "ladder":
				return pay.duplicate(true)
	return {}


func _estate_rows(engine: CardEngine) -> Array:
	var q: Dictionary = engine.query(&"estates")
	var rows: Variant = q.get("estates", [])
	if typeof(rows) != TYPE_ARRAY:
		return []
	return rows


func _estate_status(engine: CardEngine, id: String) -> String:
	for row in _estate_rows(engine):
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == id:
			return str((row as Dictionary).get("status", ""))
	return ""


func _estate_money(engine: CardEngine, id: String) -> int:
	for row in _estate_rows(engine):
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("id", "")) == id:
			return int((row as Dictionary).get("money", 0))
	return -1


func _logged(engine: CardEngine, cmd: String, expect: Dictionary) -> bool:
	return _logged_after(engine, 0, cmd, "", expect)


func _logged_after(engine: CardEngine, start: int, cmd: String, uid: String, expect: Dictionary = {}) -> bool:
	var log: Array = engine.command_log()
	for i in range(start, log.size()):
		var row: Array = log[i]
		if str(row[0]) != cmd:
			continue
		var args: Dictionary = {}
		if row.size() > 1 and typeof(row[1]) == TYPE_DICTIONARY:
			args = row[1]
		if uid != "" and str(args.get("uid", "")) != uid:
			continue
		var hit: bool = true
		for key in expect.keys():
			if str(args.get(key, "")) != str(expect[key]):
				hit = false
		if hit:
			return true
	return false


func _game_cmds_after(engine: CardEngine, start: int) -> int:
	var n: int = 0
	var log: Array = engine.command_log()
	for i in range(start, log.size()):
		var row: Array = log[i]
		if str(row[0]).begins_with("game."):
			n += 1
	return n


func _toss_for(tossed: Array, uid: String) -> Dictionary:
	var found: Dictionary = {}
	for row in tossed:
		if typeof(row) == TYPE_DICTIONARY and str((row as Dictionary).get("uid", "")) == uid:
			found = row
	return found


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return fallback
