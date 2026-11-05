# 真模块拘留留宿：清单一致、夜牌与街头被抑制、次日关铺及成功出来。
# G06；合同1.2 §7.4.6–§7.4.7；场景使用私有例子补齐，不改共享数据。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario := preload("res://scripts/tests/cards/G06/scenario.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_prison_integration")
	var data_root: String = Scenario.build(t.user_dir() + "/data")
	var e: CardEngine = CardEngine.new()
	t.ok(e.new_game({"seed": 7, "only_examples": true, "data_root": data_root,
		"save_dir": t.user_dir()}).get("ok", false), "real new game")
	t.ok(e.send(&"day.end", {"confirm": true}).get("ok", false), "automatic month opening")
	t.ok(e.send(&"day.begin", {}).get("ok", false), "open first day")
	e.ctx.run([{"op": "arrest", "reason": "TEST_ARREST"}], "TEST_ARREST")
	CardDayLoop.set_mode(e.ctx, &"street")
	var uid: String = str(e.ctx.state.ns("ladder")["prison"]["uid"])
	t.eq(e.query(&"card", {"uid": uid}).get("days_left"), 3, "public prison nights remaining")
	var preview: Dictionary = e.query(&"day.end_preview")
	t.no_leaks(preview, "real prison preview")
	var row: Dictionary = {}
	for candidate in preview.get("items", []):
		if str(candidate.get("uid", "")) == uid:
			row = candidate
	t.eq(row.get("kind", ""), "stay", "prison offers stay consequence")
	t.eq(row.get("args", {}), {"nights": 1, "max": 3}, "preview uses next night")
	var ended: Dictionary = e.send(&"day.end", {"confirm": true})
	t.ok(ended.get("ok", false), "real prison day end")
	t.eq(ended.get("items", []), preview.get("items", []), "preview exactly matches prison execution")
	t.eq(e.view().get("night_offers", []), [], "jailed night has no offers")
	t.eq(CardPiles.zone_of(e.ctx, uid), &"hand", "prison remains in hand overnight")
	t.eq(e.ctx.state.ns("ladder")["prison"]["nights"], 1, "real night counted once")
	t.eq(e.query(&"card", {"uid": uid}).get("days_left"), 2, "public timer decremented")
	t.ok(e.ctx.mods.sum_int(e.ctx, &"deal_count", {"type": "person", "abs_day": 2}) < 0, "next day random visitors blocked")
	t.ok(e.send(&"day.end", {"confirm": true}).get("ok", false), "skip jailed night")
	t.ok(e.send(&"day.end", {"confirm": true}).get("ok", false), "advance real settlement")
	t.eq(e.view().get("date", {}).get("abs_day", 0), 2, "next day reached")
	t.ok(e.send(&"day.begin", {}).get("ok", false), "jailed day two begins")
	for card in e.view().get("hand", []):
		t.ok(str(card.get("type", "")) != "street", "no street card while jailed")
	CardPiles.resolve(e.ctx, uid, &"success")
	t.ok(e.ctx.state.ns("ladder")["prison"].is_empty(), "real resolution clears prison")
	t.eq(e.ctx.mods.sum_int(e.ctx, &"deal_count", {"type": "night"}), 0, "night suppression removed on release")
	t.eq(t.find_floats(e.ctx.state.data), PackedStringArray(), "real prison state uses integers")
	t.finish()
