# core 模块安装：登记 G01 的指令（card.keep card.discard ui.guide）、查询（firsts guide_data guide_progress
# guide_conds）、效果 op（add_card remove_card waive extra_deal）、修正项与钩子。只做登记。
# 主人 G01；W0 写了能用的最小版。合同：docs/cards/CARDS_INTERFACES.md §7.3、§7.4、§7.10.6。
class_name CardCoreInstall
extends RefCounted

const OWNER := "G01"
## guide_data 里步骤与规矩页去掉的字段（§7.4 查询表）
const GUIDE_STRIP: Array[String] = ["brief", "_provenance", "_test", "weight", "era"]


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	engine.register_command(&"card.keep", _cmd_keep, OWNER)
	engine.register_command(&"card.discard", _cmd_discard, OWNER)
	engine.register_command(&"ui.guide", _cmd_ui_guide, OWNER)
	engine.register_query(&"firsts", _q_firsts, OWNER)
	engine.register_query(&"guide_data", _q_guide_data, OWNER)
	engine.register_query(&"guide_progress", _q_guide_progress, OWNER)
	engine.register_query(&"guide_conds", _q_guide_conds, OWNER)
	for op in [&"add_card", &"remove_card", &"waive", &"extra_deal"]:
		ctx.ops.register(op, CardCoreInstall._op.bind(op), CardDslShapes.shape(op), OWNER)
	ctx.mods.register(&"scheduled_cards", _mod_queue, OWNER)
	ctx.mods.register(&"view_section", _view_section, OWNER)
	ctx.mods.register(&"end_rows", _mod_end_rows, OWNER)
	ctx.actions.register(&"*", _actions, OWNER)
	ctx.hooks.on(CardIds.HOOK_STAGE_START, _on_stage_start, 50, OWNER)
	ctx.hooks.on(CardIds.HOOK_DAY_END, _on_end_overflow, 5, OWNER)
	ctx.hooks.on(CardIds.HOOK_DAY_END, _on_day_end, 20, OWNER)
	ctx.hooks.on(CardIds.HOOK_SETTLE, _on_settle, 20, OWNER)


# ---------------- 指令 ----------------
static func _cmd_keep(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var err := CardPiles.keep(ctx, str(args.get("uid", "")))
	return {"ok": err == "", "err": err}


static func _cmd_discard(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var err := CardPiles.discard(ctx, str(args.get("uid", "")))
	return {"ok": err == "", "err": err}


## ui.guide {step, status:"shown"/"done"}：只改 ui 命名空间；不发事件、不进指令日志、不进哈希（§7.10.6）
static func _cmd_ui_guide(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var step := str(args.get("step", ""))
	var status := str(args.get("status", ""))
	if step == "" or not (status == "shown" or status == "done"):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var ui := ctx.state.ns("ui")
	if not ui.has("guide"):
		ui["guide"] = {}
	var g: Dictionary = ui["guide"]
	var row: Dictionary = g.get(step, {"shows": 0, "status": "shown", "abs_day": ctx.abs_day()})
	if status == "shown":
		row["shows"] = int(row.get("shows", 0)) + 1
	if str(row.get("status", "")) != "done":
		row["status"] = status
	row["abs_day"] = ctx.abs_day()
	g[step] = row
	return {"ok": true, "err": ""}


## 读档、重来本关时 ui 取“当前内存里的 ∪ 存档里的”（done 优先、shows 取大）
static func merge_ui(mem: Dictionary, saved: Dictionary) -> Dictionary:
	var out: Dictionary = saved.duplicate(true)
	var g: Dictionary = out.get("guide", {})
	var mg: Dictionary = mem.get("guide", {})
	for step in mg.keys():
		var a: Dictionary = mg[step]
		var b: Dictionary = g.get(step, {})
		var row := a.duplicate(true)
		row["shows"] = maxi(int(a.get("shows", 0)), int(b.get("shows", 0)))
		if str(b.get("status", "")) == "done":
			row["status"] = "done"
		g[step] = row
	out["guide"] = g
	return out


# ---------------- 查询 ----------------
static func _q_firsts(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"firsts": CardFirsts.all(ctx)}


static func _q_guide_data(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return guide_data_of(ctx.db)


static func _q_guide_progress(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"progress": (ctx.state.ns("ui").get("guide", {}) as Dictionary).duplicate(true)}


static func _q_guide_conds(ctx: CardCtx, args: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for step in args.get("ids", []):
		var d := ctx.db.def(str(step))
		out[str(step)] = ctx.test(d.get("trigger", {}).get("cond", {})) if not d.is_empty() else false
	return out


## 步骤与规矩页的机制字段（按文件里的顺序），外加 settings = rules("guide")。Mock 也用它。
static func guide_data_of(db: CardDB) -> Dictionary:
	if not db._guide_data_cache.is_empty():
		return db._guide_data_cache.duplicate(true)
	var steps: Array = []
	var pages: Array = []
	for pair in [[&"guide_step", steps], [&"rule_page", pages]]:
		var ids := Array(db.ids_of(pair[0]))
		ids.sort_custom(func(a, b) -> bool: return db.order_of(str(a)) < db.order_of(str(b)))
		for id in ids:
			var d := db.def(str(id))
			for k in GUIDE_STRIP:
				d.erase(k)
			if d.has("trigger"):
				d["trigger"].erase("cond")
			(pair[1] as Array).append(d)
	db._guide_data_cache = {"steps": steps, "pages": pages, "settings": db.rules("guide")}
	return db._guide_data_cache.duplicate(true)


# ---------------- 效果 op ----------------
static func _op(ctx: CardCtx, eff: Dictionary, source: String, op: StringName) -> void:
	match op:
		&"add_card":
			_op_add_card(ctx, eff)
		&"remove_card":
			_op_remove_card(ctx, eff)
		&"waive":
			_op_waive(ctx, eff)
		&"extra_deal":
			_op_extra_deal(ctx, eff)
		_:
			push_error("CardCoreInstall: unknown op '%s' at %s" % [op, source])


static func _op_add_card(ctx: CardCtx, eff: Dictionary) -> void:
	var def_id := str(eff.get("card", ""))
	var to := str(eff.get("to", "hand"))
	var in_days := int(eff.get("in_days", 0))
	if in_days > 0 or to == "queue":
		(ctx.state.ns("core")["queue"] as Array).append({
			"def": def_id,
			"abs_day": ctx.abs_day() + maxi(1, in_days),
			"zone": "hand" if to == "queue" else to,
		})
		return
	var spawn_zone := CardIds.ZONE_HAND if to == "kept" else StringName(to)
	var uid := CardPiles.spawn(ctx, def_id, spawn_zone)
	if uid == "":
		return
	if to == "kept":
		CardPiles.keep(ctx, uid)
	ctx.emit(&"cards_dealt", [PackedStringArray([uid])])


static func _op_remove_card(ctx: CardCtx, eff: Dictionary) -> void:
	var from := str(eff.get("from", "any"))
	var zones: Array = [&"hand", &"kept", &"pending"] if from == "any" else [StringName(from)]
	_discard_matches(ctx, eff.get("match", {}), maxi(0, int(eff.get("n", 1))), zones)


static func _op_waive(ctx: CardCtx, eff: Dictionary) -> void:
	_discard_matches(ctx, eff.get("match", {}), maxi(0, int(eff.get("n", 1))),
		[&"hand", &"pending", &"demands"])


static func _op_extra_deal(ctx: CardCtx, eff: Dictionary) -> void:
	var pool := StringName(str(eff.get("type", "")))
	var n := maxi(0, int(eff.get("n", 1)))
	if str(eff.get("day", "today")) == "tomorrow":
		(ctx.state.ns("core")["queue"] as Array).append({
			"pool": str(pool), "n": n, "abs_day": ctx.abs_day() + 1, "zone": "hand",
		})
		return
	CardComposer.extra_deal(ctx, pool, n)


static func _discard_matches(ctx: CardCtx, match_d: Dictionary, n: int, zones: Array) -> void:
	var uids := PackedStringArray()
	for zone in zones:
		for uid in CardPiles.list(ctx, zone):
			if _card_matches(ctx, uid, match_d):
				uids.append(uid)
	uids.sort()
	for i in range(mini(n, uids.size())):
		CardPiles.discard(ctx, uids[i])


static func _card_matches(ctx: CardCtx, uid: String, match_d: Dictionary) -> bool:
	var card := CardPiles.card(ctx, uid)
	var def := CardPiles.def_of(ctx, uid)
	if match_d.has("def") and str(card.get("def", "")) != str(match_d["def"]):
		return false
	if match_d.has("type") and str(def.get("type", "")) != str(match_d["type"]):
		return false
	var wanted: Array = match_d.get("tags_any", [])
	if not wanted.is_empty():
		var tags: Array = def.get("tags", [])
		for tag in wanted:
			if tags.has(tag):
				return true
		return false
	return true

# ---------------- 修正项与钩子 ----------------
## 队列由 CardComposer 唯一消费（含非手牌区域）；修正项保持纯读取，避免发牌重复。
static func _mod_queue(_ctx: CardCtx, _args: Dictionary) -> Array:
	return []


## 视图里的区（G01 交来的那一块）
static func _view_section(ctx: CardCtx, _args: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for z in [&"hand", &"kept", &"contacts", &"pending", &"demands"]:
		var arr: Array = []
		for uid in CardPiles.list(ctx, z):
			arr.append(CardViewModel.card_view(ctx, uid, false))
		out[str(z)] = arr
	return out


## 所有牌都有的动作：open（有面板的）、keep（能留的、还在手上的）。G03/G04 等再按类型补 refuse、read、choose:<id>
static func _actions(ctx: CardCtx, uid: String) -> Array:
	var out: Array = []
	var d := CardPiles.def_of(ctx, uid)
	if CardViewModel.panel_of(d) != &"none":
		out.append({"id": "open", "enabled": true, "reason_key": ""})
	var keepable := (str(d.get("type", "")) == "kept" or bool(d.get("keepable", false))) and not bool(d.get("gold", false))
	if keepable and CardPiles.zone_of(ctx, uid) == CardIds.ZONE_HAND:
		out.append({"id": "keep", "enabled": true, "reason_key": ""})
	return out


static func _on_stage_start(ctx: CardCtx, args: Dictionary) -> void:
	var era := str(ctx.db.stage(int(args.get("stage", ctx.state.ns("loop").get("stage", 0)))).get("era", ""))
	for zone in [CardIds.ZONE_HAND, CardIds.ZONE_PENDING]:
		for uid in CardPiles.list(ctx, zone):
			var eras: Array = CardPiles.def_of(ctx, uid).get("era", [])
			if not (eras.has("*") or eras.has(era)):
				CardPiles.move(ctx, uid, CardIds.ZONE_DISCARD)
				ctx.emit(&"card_left", [uid, &"resolved"])


static func _on_day_end(ctx: CardCtx, _args: Dictionary) -> void:
	CardPiles.end_day(ctx)


static func _on_end_overflow(ctx: CardCtx, _args: Dictionary) -> void:
	var uid := CardPiles.overflow_uid(ctx)
	while uid != "":
		CardPiles.discard(ctx, uid)
		uid = CardPiles.overflow_uid(ctx)


static func _mod_end_rows(ctx: CardCtx, _args: Dictionary) -> Array:
	return CardPiles.end_rows(ctx)


static func _on_settle(ctx: CardCtx, _args: Dictionary) -> void:
	CardPiles.settle_kept(ctx)
