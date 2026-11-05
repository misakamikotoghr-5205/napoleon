# G03 登记指令、查询、冻结 DSL 形状及规则钩子；只做登记。
# 修改规则状态和查询构造分开，查询与界面动作始终只读。
class_name CardRulesInstall
extends RefCounted
const OWNER := "G03"
const H = preload("res://scripts/cards/rules/rules_helpers.gd")
const Scare = preload("res://scripts/cards/weapon/scare.gd")
const Pet = preload("res://scripts/cards/rules/pet.gd")

static func install(engine: CardEngine, ctx: CardCtx) -> void:
	for cmd in [&"card.read", &"card.choose", &"slot.place", &"slot.remove", &"slot.roll", &"demand.submit", &"demand.delay", &"contact.release"]:
		engine.register_command(cmd, _command.bind(cmd), OWNER)
	for q in [&"slots", &"dossier"]: engine.register_query(q, _query.bind(q), OWNER)
	_install_ctx(ctx)

static func _install_ctx(ctx: CardCtx) -> void:
	for op in CardDslShapes.EFFECT_OPS.keys():
		if CardDslShapes.EFFECT_OPS[op] == OWNER: ctx.ops.register(op, CardEffectsCore.run_op.bind(op), CardDslShapes.shape(op), OWNER)
	for op in CardDslShapes.COND_OPS.keys():
		if CardDslShapes.COND_OPS[op] == OWNER: ctx.conds.register(op, CardCondsCore.test_op.bind(op), CardDslShapes.shape(op, true), OWNER)
	ctx.mods.register(&"view_section", _view_section, OWNER)
	ctx.mods.register(&"card_view_part", _card_view_part, OWNER)
	ctx.mods.register(&"end_rows", _end_rows, OWNER)
	ctx.mods.register(&"coins", _coins, OWNER)
	ctx.mods.register(&"patience_pct", _patience, OWNER)
	for kind in [&"appraise_pct", &"deal_count", &"cap", &"pool_pct", &"intake_blocked"]: ctx.mods.register(kind, _contact_mod.bind(kind), OWNER)
	for type in [&"person", &"event", &"fate", &"big_fate", &"life", &"street", &"prison", &"demand", &"news", &"pawn_ticket"]: ctx.actions.register(type, _actions, OWNER)
	ctx.hooks.on(&"stage_start", _stage_start, 20, OWNER)
	ctx.hooks.on(&"day_start", _day_start, 20, OWNER)
	ctx.hooks.on(&"day_start", _issue, 30, OWNER)
	ctx.hooks.on(&"day_start", _contacts_day, 50, OWNER)
	ctx.hooks.on(&"deal_composed", _dealt, 20, OWNER)
	ctx.hooks.on(&"day_end", _day_end, 6, OWNER)
	ctx.hooks.on(&"settle", _settle_demands, 30, OWNER)
	ctx.hooks.on(&"settle", _settle_meters, 40, OWNER)
	ctx.hooks.on(&"year_jump", _year, 30, OWNER)
	Pet.install(ctx)

static func _command(ctx: CardCtx, args: Dictionary, cmd: StringName) -> Dictionary:
	if typeof(args.get("uid")) != TYPE_STRING or str(args["uid"]) == "": return H.error("bad_args")
	var phase := str(ctx.state.ns("loop").get("phase", "boot"))
	if phase not in ["day", "morning", "month_open"]: return H.error("bad_phase")
	var uid := str(args["uid"])
	var result: Dictionary = H.error("bad_args")
	match cmd:
		&"card.read": result = CardChoices.read(ctx, uid)
		&"card.choose":
			if typeof(args.get("choice")) == TYPE_STRING: result = CardChoices.choose(ctx, uid, str(args["choice"]))
		&"slot.place":
			if typeof(args.get("slot")) == TYPE_STRING and _source_valid(args.get("source")): result = CardSlots.place(ctx, uid, str(args["slot"]), args["source"])
		&"slot.remove":
			if typeof(args.get("slot")) == TYPE_STRING and typeof(args.get("index")) == TYPE_INT: result = CardSlots.remove(ctx, uid, str(args["slot"]), int(args["index"]))
		&"slot.roll": result = CardSlots.roll(ctx, uid)
		&"demand.submit": result = CardDemands.submit(ctx, uid)
		&"demand.delay": result = CardDemands.delay(ctx, uid)
		&"contact.release": result = CardEffectsCore.release_contact(ctx, uid)
	H.kept_first(ctx)
	return result

static func _source_valid(source) -> bool:
	if typeof(source) != TYPE_DICTIONARY or typeof(source.get("kind")) != TYPE_STRING: return false
	for key in source.keys():
		if str(key) not in ["kind", "uid", "item", "amount"]: return false
		if str(key) == "amount" and typeof(source[key]) != TYPE_INT: return false
		if str(key) != "amount" and typeof(source[key]) != TYPE_STRING: return false
	return str(source["kind"]) in ["self", "contact", "money", "kept", "news", "item"]

static func _query(ctx: CardCtx, args: Dictionary, q: StringName) -> Dictionary:
	if q == &"dossier": return CardDossier.view(ctx, str(args.get("person", "")))
	var uid := str(args.get("uid", ""))
	if CardPiles.card(ctx, uid).is_empty(): return H.error("unknown_uid")
	var p := CardSlots.preview(ctx, uid)
	p["slots"] = CardSlots.slot_views(ctx, uid)
	return p

static func _view_section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var cards: Dictionary = ctx.state.ns("core").get("cards", {})
	var self_uid := ctx.state._self_uid_cache
	if ctx.state._self_uid_cards_size != cards.size() or (self_uid != "" and str(cards.get(self_uid, {}).get("def", "")) != "self.ruhua"):
		self_uid = ""
		for uid in cards.keys():
			if str(cards[uid].get("def", "")) == "self.ruhua" and (self_uid == "" or str(uid) > self_uid):
				self_uid = str(uid)
		ctx.state._self_uid_cache = self_uid
		ctx.state._self_uid_cards_size = cards.size()
	var count := 0
	var dossier: Dictionary = H.peek(ctx).get("dossier", {})
	for pid in dossier.keys():
		count += (dossier[pid].get("new", []) as Array).size()
	return {"rep_tier": CardMeters.tier(ctx, &"rep"), "heat_tier": CardMeters.tier(ctx, &"heat"), "self": {"uid": self_uid, "def": "self.ruhua", "attrs": H.attrs(ctx, "ruhua"), "used_today": int(H.person_peek(ctx, "ruhua").get("used_abs_day", -1)) == ctx.abs_day()}, "dossier_new": count}

static func _card_view_part(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var uid := str(args.get("uid", ""))
	var d := CardPiles.def_of(ctx, uid)
	var out: Dictionary = {}
	var person := str(d.get("person", ""))
	if person != "":
		var row := H.person_peek(ctx, person)
		out["used_today"] = int(row.get("used_abs_day", -1)) == ctx.abs_day()
		out["away_days"] = maxi(0, int(row.get("until_abs_day", -1)) - ctx.abs_day())
		if str(d.get("type", "")) in ["self", "contact"]: out["attrs"] = H.attrs(ctx, person)
	if str(d.get("type", "")) == "demand":
		out["days_left"] = CardDemands.days_left(ctx, uid)
		out["demand"] = {"kind": str(d.get("kind", "")), "tier": CardDemands.tier_of(ctx, uid)}
		out["amount"] = CardDemands.amount(ctx, uid)
	if bool(args.get("detailed", false)):
		out["slots"] = CardSlots.slot_views(ctx, uid)
		out["choices"] = CardChoices.options(ctx, uid)
	return out

static func _actions(ctx: CardCtx, uid: String) -> Array:
	var result: Array = []
	if str(CardPiles.def_of(ctx, uid).get("type", "")) in ["news", "pawn_ticket"]: result.append({"id": "read", "enabled": H.open_error(ctx, uid) == "", "reason_key": ""})
	for choice in CardChoices.options(ctx, uid): result.append({"id": "choose:" + str(choice["id"]), "enabled": choice["enabled"], "reason_key": choice["reason_key"]})
	return result

static func _coins(_ctx: CardCtx, _args: Dictionary) -> int:
	# CardMeters.attr already includes temporary modifiers; do not count them twice.
	return 0

static func _patience(ctx: CardCtx, _args: Dictionary) -> int:
	var tiers: Array = ctx.rules("meters").get("rep", {}).get("patience_pct_by_tier", [100, 100, 100, 100, 100])
	return int(tiers[mini(CardMeters.tier(ctx, &"rep"), tiers.size() - 1)])

# 人脉常驻修正（mods，同家当 while_mortgaged 的格式）；pct 一律是乘数，100 不变。
static func _contact_mod(ctx: CardCtx, args: Dictionary, kind: StringName) -> Variant:
	var total := 100 if kind in [&"appraise_pct", &"pool_pct"] else 0
	for uid in CardPiles.list(ctx, &"contacts"):
		var d := CardPiles.def_of(ctx, uid)
		if str(H.person_peek(ctx, str(d.get("person", ""))).get("state", "ok")) in ["gone", "away", "jailed", "hurt"]: continue
		for mod in d.get("mods", []):
			var name := str(mod.get("mod", ""))
			if kind == &"cap" and ((name == "shelf_cap" and str(args.get("zone", "")) == "shelf") or (name == "kept_cap" and str(args.get("zone", "")) == "kept")):
				total += int(mod.get("delta", 0))
			elif kind == &"deal_count" and name == "deal_count" and str(mod.get("type", "")) == str(args.get("type", "")): total += int(mod.get("delta", 0))
			elif kind == &"appraise_pct" and name == "appraise_pct" and _cat_matches(mod, str(args.get("cat", ""))): total = total * int(mod.get("pct", 100)) / 100
			elif kind == &"pool_pct" and name == "pool_weight" and str(mod.get("pool", "")) == str(args.get("pool", "")) and _tags_match(ctx, mod, str(args.get("def", ""))): total = total * int(mod.get("pct", 100)) / 100
			elif kind == &"intake_blocked" and name == "no_intake_cat" and str(mod.get("cat", "")) == str(args.get("cat", "")): return true
	return false if kind == &"intake_blocked" else total

# cat 写单个、cats 写一组；两个都不写就对所有品类生效。
static func _cat_matches(mod: Dictionary, cat: String) -> bool:
	if not mod.has("cat") and not mod.has("cats"): return true
	return (mod.has("cat") and str(mod["cat"]) == cat) or (typeof(mod.get("cats")) == TYPE_ARRAY and (mod["cats"] as Array).has(cat))

# tags_any 为空表示整个牌库都算（同 G06 家当 pool_weight）。
static func _tags_match(ctx: CardCtx, mod: Dictionary, def_id: String) -> bool:
	var tags: Array = mod.get("tags_any", [])
	return tags.is_empty() or H.intersects(tags, ctx.db.def(def_id).get("tags", []))

static func contact_hook(ctx: CardCtx, hook: String) -> void:
	var uids := CardPiles.list(ctx, &"contacts")
	uids.sort()
	for uid in uids:
		if CardPiles.zone_of(ctx, uid) != &"contacts": continue
		var d := CardPiles.def_of(ctx, uid)
		var person := str(d.get("person", ""))
		if str(H.person_peek(ctx, person).get("state", "ok")) in ["gone", "away", "jailed", "hurt"]: continue
		for field in ["passives", "downsides"]:
			var rows: Array = d.get(field, [])
			for i in range(rows.size()):
				if str(rows[i].get("hook", "")) == hook: ctx.run(rows[i].get("effects", []), uid + "/" + field + "/" + str(i) + "/" + hook)
		for i in range((d.get("leave_when", []) as Array).size()):
			var leave: Dictionary = d["leave_when"][i]
			if ctx.test(leave.get("cond", {})):
				ctx.run(leave.get("effects", []), uid + "/leave_when/" + str(i))
				CardEffectsCore.lose_contact(ctx, person)
				break

static func _stage_start(ctx: CardCtx, _args: Dictionary) -> void:
	CardMeters.initialize(ctx)
	H.kept_first(ctx)

static func _day_start(ctx: CardCtx, _args: Dictionary) -> void:
	CardMeters.expire_mods(ctx)
	CardDemands.return_people(ctx)
	H.kept_first(ctx)

static func _issue(ctx: CardCtx, _args: Dictionary) -> void:
	CardDemands.issue(ctx)
	H.kept_first(ctx)

static func _contacts_day(ctx: CardCtx, _args: Dictionary) -> void:
	contact_hook(ctx, "day_start")
	H.kept_first(ctx)

static func _dealt(ctx: CardCtx, args: Dictionary) -> void:
	for uid in args.get("uids", []):
		var d := CardPiles.def_of(ctx, str(uid))
		var has_slots := not (d.get("slots", []) as Array).is_empty()
		if (d.get("tags", []) as Array).has("office"): CardFirsts.mark(ctx, &"office", {"uid": str(uid), "def": str(d.get("id", ""))})
		if not (d.get("choices", []) as Array).is_empty(): CardFirsts.mark(ctx, &"choice", {"uid": str(uid), "def": str(d.get("id", ""))})
		for choice in d.get("choices", []):
			if choice.has("check"): has_slots = true
		if has_slots:
			CardFirsts.mark(ctx, &"slots", {"uid": str(uid), "def": str(d.get("id", ""))})
			CardFirsts.mark(ctx, &"coins", {"uid": str(uid)})
		Scare.mark_dealt(ctx, str(uid))
	contact_hook(ctx, "deal")
	H.kept_first(ctx)

static func _settle_demands(ctx: CardCtx, _args: Dictionary) -> void:
	CardDemands.on_settle(ctx)
	H.kept_first(ctx)

static func _settle_meters(ctx: CardCtx, _args: Dictionary) -> void:
	var r := H.state(ctx)
	if int(r.get("meters_settled_abs_day", -1)) == ctx.abs_day(): return
	r["meters_settled_abs_day"] = ctx.abs_day()
	var cfg: Dictionary = ctx.rules("meters").get("heat", {})
	if CardMeters.value(ctx, &"heat") >= int(cfg.get("arrest_at", 100)):
		ctx.run([{"op": "arrest", "reason": "g03.arrest.heat"}], "G03:settle/arrest")
	CardMeters.add(ctx, &"heat", -int(cfg.get("decay_per_day", 1)), "G03:settle/decay")
	H.kept_first(ctx)

static func _year(ctx: CardCtx, args: Dictionary) -> void:
	var era := str(ctx.db.stage(int(ctx.state.ns("loop").get("stage", 0))).get("era", ""))
	CardDossier._year_after(ctx, str(args.get("to", era)))
	H.kept_first(ctx)

static func _end_rows(ctx: CardCtx, _args: Dictionary) -> Array:
	var out: Array = []
	var demands := Array(CardPiles.list(ctx, &"demands"))
	demands.sort_custom(func(a: String, b: String) -> bool:
		var da := CardDemands.days_left(ctx, a)
		var db := CardDemands.days_left(ctx, b)
		return da < db if da != db else a < b)
	for uid in demands:
		var d := CardPiles.def_of(ctx, str(uid))
		out.append({"uid": str(uid), "def": str(d.get("id", "")), "kind": "wait", "consequence_key": "g03.end.demand", "args": {"days": maxi(0, CardDemands.days_left(ctx, str(uid)) - 1)}})
	var pending := str(H.peek(ctx).get("contact_pending", ""))
	if CardPiles.zone_of(ctx, pending) == &"pending" and str(CardPiles.def_of(ctx, pending).get("type", "")) == "contact":
		out.append({"uid": pending, "def": str(CardPiles.card(ctx, pending).get("def", "")), "kind": "release", "consequence_key": "g03.end.release", "args": {}})
	return out

static func _day_end(ctx: CardCtx, _args: Dictionary) -> void:
	var pending := str(H.peek(ctx).get("contact_pending", ""))
	if CardPiles.zone_of(ctx, pending) == &"pending":
		CardEffectsCore.release_contact(ctx, pending)
	CardSlots.return_unrolled(ctx)
	H.kept_first(ctx)
