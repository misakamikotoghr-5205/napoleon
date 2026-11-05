# 合同1.2：G01 打烊清单、溢出默认弃置、生活期限及手中可留牌的日结过期。
# 主人 G01；合同 §7.3、§7.4.7、§7.5。测试使用隔离数据根及记录型效果替身。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_end_day")
	var root := _fixture(t)
	_test_rows_and_expiry(t, root)
	_test_overflow(t, root)
	t.finish()

func _fixture(t) -> String:
	var root: String = t.user_dir() + "/cards"
	H.copy_tree("res://scripts/tests/cards/G01/fixtures/good", root)
	var news: Dictionary = CardDB.read_json(root + "/news/news.json")
	news["cards"][0]["expires_days"] = 2
	news["cards"][0]["effects"] = {"on_expire": [{"op": "rep", "delta": 1}],
		"on_read": [{"op": "rep", "delta": 100}], "on_resolve": [{"op": "rep", "delta": 1000}]}
	H.write(root + "/news/news.json", news)
	var kept: Dictionary = CardDB.read_json(root + "/common/kept.json")
	var token: Dictionary = kept["cards"][0].duplicate(true)
	token["id"] = "kp.fixture.token"
	token["keepable"] = true
	token["expires_days"] = 2
	token["effects"] = {"on_expire": [{"op": "rep", "delta": 2}], "on_resolve": [{"op": "rep", "delta": 2000}]}
	kept["cards"].append(token)
	var ticket: Dictionary = token.duplicate(true)
	ticket.merge({"id": "tk.fixture.ticket", "type": "pawn_ticket", "expires_days": 0, "must_resolve": false}, true)
	kept["cards"].append(ticket)
	H.write(root + "/common/kept.json", kept)
	return root

func _engine(root: String, seen: Array, core_only: bool = true) -> CardEngine:
	var e := CardEngine.new()
	if core_only:
		var sample := H.ctx(7, root, false)
		e.ctx.state = sample.state
		e.ctx.db = sample.db
		# 只隔离生命周期夹具的非目标钩子，避免手造 state 调用别的模块的报告/结算。
		e.ctx.hooks = CardHooks.new()
		e.ctx.hooks.on(&"day_end", CardCoreInstall._on_end_overflow, 5, "G01")
		e.ctx.hooks.on(&"day_end", CardCoreInstall._on_day_end, 20, "G01")
		e.ctx.hooks.on(&"settle", CardCoreInstall._on_settle, 20, "G01")
	else:
		# 门面回归必须走真开局：保留 reports、各模块命名空间和真实安装的所有钩子。
		e.new_game({"seed": 7, "data_root": root, "only_examples": false, "save_dir": root + "/saves"})
		e.ctx.state.ns("loop").merge({"abs_day": 5, "stage_day": 5, "phase": "day", "mode": "shop"}, true)
	e.ctx.ops = CardOps.new()
	e.ctx.ops.register(&"rep", func(_c, eff, _s): seen.append(eff.get("delta")), CardDslShapes.shape(&"rep"), "TEST")
	e.ctx.ops.register(&"attr", func(_c, _eff, _s): seen.append("life"), CardDslShapes.shape(&"attr"), "TEST")
	return e

func _test_rows_and_expiry(t, root: String) -> void:
	var seen: Array = []
	var e := _engine(root, seen)
	var c := e.ctx
	var life := CardPiles.spawn(c, "lf.any.coal_out", &"hand")
	var news := CardPiles.spawn(c, "nw.1938.wangshan_dock", &"hand")
	var token := CardPiles.spawn(c, "kp.fixture.token", &"hand")
	var ticket := CardPiles.spawn(c, "tk.fixture.ticket", &"hand")
	var before := c.state.hash()
	var rows := c.mods.collect(c, &"end_rows", {})
	t.eq(c.state.hash(), before, "preview never changes gameplay state")
	t.eq(CardViewModel.leaks(rows), PackedStringArray(), "end rows contain no hidden keys")
	t.eq(_row(rows, life), {"uid": life, "def": "lf.any.coal_out", "kind": "wait", "consequence_key": "g01.end.wait", "args": {"days": 2}}, "life before due waits")
	t.eq(_row(rows, ticket)["args"], {"days": -1}, "unlimited ticket waits")
	t.eq(_row(rows, news)["args"], {"days": 2}, "news countdown starts dealt day")
	c.hooks.fire(c, &"day_end", {})
	for uid in [life, news, token, ticket]:
		t.eq(CardPiles.zone_of(c, uid), &"hand", "wait rows retain card " + uid)
	t.eq(seen, [], "waiting has no passive or unread effects")
	c.state.ns("loop")["abs_day"] = 7
	rows = c.mods.collect(c, &"end_rows", {})
	t.eq(_row(rows, life)["kind"], "ignore", "due life ignores")
	t.eq(_row(rows, life)["consequence_key"], "lf.any.coal_out#outcomes.ignored", "due life data consequence")
	t.eq(_row(rows, news)["args"], {"days": 0}, "news expires tonight")
	c.hooks.fire(c, &"day_end", {})
	t.eq(CardPiles.zone_of(c, life), &"discard", "day end executes due life")
	t.eq(CardPiles.zone_of(c, news), &"hand", "news waits until settle")
	t.eq(CardPiles.zone_of(c, token), &"hand", "token waits until settle")
	c.hooks.fire(c, &"settle", {})
	t.eq(CardPiles.zone_of(c, news), &"discard", "settle expires unread news")
	t.eq(CardPiles.zone_of(c, token), &"discard", "settle expires hand token")
	t.eq(CardPiles.zone_of(c, ticket), &"hand", "unlimited ticket survives settle")
	t.eq(seen, ["life", 1, 2], "only expiry effects, no read/resolve passive rewards")
	c.hooks.fire(c, &"settle", {})
	t.eq(seen, ["life", 1, 2], "expiry effects execute once")
	t.eq(t.find_floats(c.state.data), PackedStringArray(), "all deadlines remain integer")
	c.state.ns("loop")["phase"] = "morning"
	t.eq(CardPiles.end_rows(c), [], "morning never abandons unseen cards")

func _test_overflow(t, root: String) -> void:
	var seen: Array = []
	var e := _engine(root, seen, false)
	var c := e.ctx
	c.mods.register(&"cap", func(_c, args): return -999 if str(args.get("zone")) == "kept" else 0, "TEST")
	var uid := CardPiles.spawn(c, "kp.fixture.token", &"hand")
	t.eq(CardPiles.keep(c, uid), CardIds.ERR_KEPT_FULL, "overflow becomes pending")
	var rows := c.mods.collect(c, &"end_rows", {})
	t.eq(_row(rows, uid), {"uid": uid, "def": "kp.fixture.token", "kind": "discard", "consequence_key": "g01.end.discard", "args": {}}, "overflow preview matches default discard")
	t.ok(c.hooks.listeners(&"day_end").has([5, "G01"]), "overflow cleanup registered before other day end hooks")
	# 独立 G01 环境的 G02 仍是桩；有真 G02 时同一测试额外验 day.end 绕过溢出门禁。
	var preview := e.query(&"day.end_preview")
	if str(preview.get("step", "")) == "end_day":
		var actual := e.send(&"day.end", {"confirm": true})
		t.ok(bool(actual.get("ok", false)), "day end allowed despite overflow")
		t.eq(actual.get("items"), preview.get("items"), "preview equals confirmed result")
	else:
		c.hooks.fire(c, &"day_end", {})
	t.eq(CardPiles.zone_of(c, uid), &"discard", "unselected overflow discarded")
	t.eq(CardPiles.overflow_uid(c), "", "overflow gate cleared")
	t.eq(seen, [], "overflow skips expiry and resolve effects")
	t.eq(CardPiles.card(c, uid)["status"], "discarded", "discard status preserved")

func _row(rows: Array, uid: String) -> Dictionary:
	for row in rows:
		if str(row.get("uid", "")) == uid:
			return row
	return {}
