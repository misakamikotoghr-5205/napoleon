# 使用全部真实模块验证拿货抵、原来源认了、短缺读档参数与月底续接。
# G06；合同 §7.4.5。测试搭场景经 G04 的 op，绝不直接改 econ。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario := preload("res://scripts/tests/cards/G06/scenario.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_economy_integration")
	var data_root: String = Scenario.build(t.user_dir() + "/data")
	var file: FileAccess = FileAccess.open(data_root + "/_examples/g06_short_probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"cards": [{"id": "ev.g06.short_probe", "type": "event", "era": ["*"],
		"weight": 0, "brief": "TEST_SHORT", "effects": {"on_short": [{"op": "flag", "key": "g06_default"},
			{"op": "counter", "key": "g06_default_calls", "delta": 1}]},
		"_provenance": {"by": "ai", "task": "G06", "date": "2026-10-13"}}]}))
	file = null
	var e: CardEngine = CardEngine.new()
	t.ok(e.new_game({"seed": 7, "only_examples": true, "data_root": data_root,
		"save_dir": t.user_dir()}).get("ok", false), "real new game")
	var source: String = CardPiles.spawn(e.ctx, "ev.g06.short_probe", &"hand")
	e.ctx.run([{"op": "money", "delta": -CardCurrency.money(e.ctx), "reason": "g06.short.payment"}], "TEST_DRAIN")
	e.ctx.run([{"op": "item_gain", "cat": "jewelry", "n": 1}], "TEST_GOODS")
	var items: PackedStringArray = CardShelf.items(e.ctx)
	t.ok(not items.is_empty(), "real goods on shelf")
	e.ctx.run([{"op": "pay", "amount": 1, "payee": "TEST_BANK", "reason": "g06.short.payment", "short": "ladder"}], source)
	var panel: Dictionary = e.query(&"short")
	t.eq(panel["options"], ["goods", "estate", "default"], "real available route order")
	t.eq(panel["amount"], 1, "visible amount is shortage")
	t.ok(e.send(&"short.resolve", {"source": panel["source"], "by": "goods", "item": items[0]}).get("ok", false), "selected goods pays")
	t.ok(not CardShelf.items(e.ctx).has(items[0]), "only selected goods removed")
	t.ok(e.query(&"short").is_empty(), "real payment resolved")
	t.ok(not e.ctx.state.ns("econ").has("pending_payment"), "successful payment clears economy cache")
	e.ctx.run([{"op": "money", "delta": -CardCurrency.money(e.ctx), "reason": "g06.short.payment"}], "TEST_DRAIN")
	e.ctx.run([{"op": "pay", "amount": 50, "payee": "TEST_BANK", "reason": "g06.short.payment", "short": "ladder"}], source)
	panel = e.query(&"short")
	var restored: CardState = CardState.from_dict(e.ctx.state.to_dict())
	e.ctx.state = restored
	t.eq(e.query(&"short"), panel, "real pending panel survives state restore")
	t.ok(e.send(&"short.resolve", {"source": panel["source"], "by": "default"}).get("ok", false), "real default resolves")
	t.ok(e.ctx.test({"flag": "g06_default"}), "original source on_short executed")
	t.eq(e.view()["mode"], "shop", "default does not become street")
	t.ok(not e.ctx.state.ns("econ").has("pending_payment"), "default clears economy cache")
	e.ctx.run([{"op": "pay", "amount": 50, "payee": "TEST_BANK", "reason": "g06.short.payment", "short": "ladder"}], source)
	panel = e.query(&"short")
	e.ctx.run([{"op": "money", "delta": 100, "reason": "g06.short.payment"}], "TEST_GIFT")
	var funded: int = CardCurrency.money(e.ctx)
	t.ok(e.send(&"short.resolve", {"source": panel["source"], "by": "default"}).get("ok", false), "funded default resolves")
	t.eq(CardCurrency.money(e.ctx), funded, "funded default never pays")
	t.eq(e.ctx.state.ns("rules").get("counters", {}).get("g06_default_calls", 0), 2, "on_short once per default")
	t.ok(not e.ctx.state.ns("econ").has("pending_payment"), "funded default clears cache")
	t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "real integrated state integer-only")
	t.finish()
