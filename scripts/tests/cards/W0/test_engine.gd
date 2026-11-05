# W0 骨架自测②：真引擎 CardEngine 的门面与最小核心——能 new、指令/查询/op 都按合同的主人登记了、事件顺序、busy 防重入、
# 状态里没有浮点、ui 不进哈希也不发事件、存→读哈希一样、first-time 只发一次、发牌确定且 project() 与实际一致、
# 脚本日不随机抽、金色牌排在手牌最前。合同：docs/cards/CARDS_INTERFACES.md §6、§7.2–§7.4、§7.10.6、§10.2。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "W0_engine")
	var bus := CardEventBus.new()
	var spy = t.spy(bus)
	var eng := CardEngine.new(bus)
	var r := eng.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir()})
	t.ok(bool(r.get("ok", false)), "new_game ok")
	t.eq(eng.view().get("phase"), "month_open", "phase after new_game")
	t.eq(spy.log.filter(func(e: Array) -> bool: return e[0] == &"first_time" and str(e[1]) == "month_open").size(), 1, "first month_open fired once")
	t.eq(spy.names().slice(-2), [&"command_done", &"view_changed"], "events end with command_done, view_changed")
	# 登记：指令、查询、op 的主人和合同一致
	for cmd in CardIds.COMMANDS.keys():
		t.eq(eng.command_owner(cmd), CardIds.COMMANDS[cmd], "command %s owner" % cmd)
	for q in CardIds.QUERIES.keys():
		t.eq(eng.query_owner(q), CardIds.QUERIES[q], "query %s owner" % q)
	for op in CardDslShapes.EFFECT_OPS.keys():
		t.eq(eng.ctx.ops.owner_of(op), CardDslShapes.EFFECT_OPS[op], "effect op %s owner" % op)
	t.eq(Array(eng.ctx.conds.known()).size(), CardDslShapes.COND_OPS.size(), "every condition op registered")
	t.no_leaks(eng.view())
	t.eq(t.find_floats(eng.ctx.state.data), PackedStringArray(), "no floats in state")
	# 失败的指令同样以 command_done(ok=false)、view_changed 收尾
	spy.clear()
	r = eng.send(&"counter.offer", {"uid": "c0001", "tier": "fair"})
	t.ok(str(r.get("err", "")) != "", "a command the phase does not allow fails with an error code")
	t.eq(spy.names(), [&"command_done", &"view_changed"], "failed command still ends with command_done, view_changed")
	t.eq(spy.log[0][3], false, "command_done ok=false")
	t.eq(eng.send(&"no.such", {}).get("err"), "bad_args", "unknown command -> bad_args")
	# busy：总线回调里同步 send 得到 busy
	var inner: Array = []
	var cb := func(_c: StringName, _a: Dictionary, _ok: bool) -> void: inner.append(eng.send(&"ui.guide", {"step": "x", "status": "shown"}))
	bus.command_done.connect(cb, CONNECT_ONE_SHOT)
	eng.send(&"card.keep", {"uid": "c9999"})
	t.eq(inner.size(), 1, "callback ran")
	t.eq(inner[0].get("err") if not inner.is_empty() else "", "busy", "send inside a bus callback -> busy")
	# ui.guide：只改 ui，不发事件、不进哈希、不进指令日志
	var h0 := eng.ctx.state.hash()
	var log0 := eng.command_log().size()
	spy.clear()
	t.ok(bool(eng.send(&"ui.guide", {"step": "gd.d1.deal", "status": "shown"}).get("ok")), "ui.guide ok")
	t.eq(spy.log.size(), 0, "ui.guide emits nothing")
	t.eq(eng.ctx.state.hash(), h0, "ui not in state hash")
	t.eq(eng.command_log().size(), log0, "ui.guide not in command log")
	eng.send(&"ui.guide", {"step": "gd.d1.deal", "status": "done"})
	t.eq(eng.query(&"guide_progress")["progress"]["gd.d1.deal"], {"shows": 1, "status": "done", "abs_day": 0}, "progress")
	var gd: Dictionary = eng.query(&"guide_data")
	t.eq((gd["steps"] as Array).map(func(s: Dictionary) -> String: return s["id"]), ["gd.d1.deal", "gd.d1.person", "gd.slots"],
		"guide_data steps in file order")
	t.no_leaks(gd, "guide_data")
	t.ok(not (gd["steps"][0] as Dictionary).has("brief"), "guide_data strips brief")
	t.eq(gd["settings"].get("max_new_per_day"), 16, "guide_data settings = rules(guide)")
	t.eq(eng.query(&"guide_conds", {"ids": ["gd.d1.deal"]}), {"gd.d1.deal": true}, "guide_conds")
	# 存→读：哈希一样；ui 取并集
	var path := t.user_dir() + "/stage_00.json"
	t.ok(bool(eng.save_game(path).get("ok")), "save at month_open")
	var h1 := eng.ctx.state.hash()
	eng.send(&"ui.guide", {"step": "gd.d1.person", "status": "shown"})
	r = eng.load_game(path)
	t.ok(bool(r.get("ok")), "load ok")
	t.eq(eng.ctx.state.hash(), h1, "hash after load")
	t.eq(eng.query(&"guide_progress")["progress"].keys().size(), 2, "ui merged from memory and save")
	# first-time 只发一次
	t.ok(not CardFirsts.mark(eng.ctx, &"month_open", {}), "second mark returns false")
	t.ok(CardFirsts.mark(eng.ctx, &"deal", {}), "first mark returns true")
	t.ok(not CardFirsts.mark(eng.ctx, &"deal", {}), "and only once")
	# 发牌：确定、project() 与实际一致、脚本日不随机抽
	var ctx: CardCtx = eng.ctx
	var loop := ctx.state.ns("loop")
	loop["stage_day"] = 1
	loop["abs_day"] = 1
	t.eq(CardComposer.project(ctx, 1), PackedStringArray(), "scripted day 1: no random cards")
	loop["stage_day"] = 5
	loop["abs_day"] = 5
	var proj := CardComposer.project(ctx, 5)
	t.ok(proj.size() >= 3, "day 5 projects some random cards (%d)" % proj.size())
	var snap := CardState.from_dict(ctx.state.to_dict())
	var dealt := CardComposer.compose(ctx)
	t.eq(Array(dealt).map(func(u: String) -> String: return str(CardPiles.card(ctx, u)["def"])), Array(proj), "compose == project")
	var again := CardComposer.compose(_ctx_with(ctx, snap))
	t.eq(again.size(), dealt.size(), "same state, same deal size")
	t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "no floats after dealing")
	# 金色牌排在手牌最前（发牌、加牌之后都是）
	var gold := CardPiles.spawn(ctx, "p.brother.1938.farewell", CardIds.ZONE_HAND)
	CardPiles.spawn(ctx, "pr.cell", CardIds.ZONE_HAND)
	var hand := CardPiles.list(ctx, CardIds.ZONE_HAND)
	t.eq(hand[0], gold, "gold card first in hand")
	t.eq(str(CardPiles.card(ctx, hand[1])["def"]), "pr.cell", "prison right after gold")
	t.eq(CardPiles.keep(ctx, gold), "not_keepable", "gold card cannot be kept")
	t.no_leaks(eng.view())
	t.no_leaks(eng.query(&"card", {"uid": gold}), "card view")
	bus.free()
	t.finish()


## 同一套登记表，换一份状态（看“同状态同结果”）
func _ctx_with(ctx: CardCtx, st: CardState) -> CardCtx:
	var c := CardCtx.new()
	c.db = ctx.db
	c.ops = ctx.ops
	c.conds = ctx.conds
	c.mods = ctx.mods
	c.hooks = ctx.hooks
	c.actions = ctx.actions
	c.state = st
	return c
