# Real engine, example set, seed 7. Day 1 deals an empty hand and a good window
# (grade 3). Place the example stall card, then fortune.lot must succeed and
# return a lot id from the example fortune_lot pool.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var test_name := _arg("--name=", "C07_real_engine")
	var t := T.new(self, test_name)
	_run(t)
	t.finish()


func _run(t) -> void:
	var eng: CardEngine = CardEngine.new()
	var opened: Dictionary = eng.new_game({
		"seed": 7,
		"only_examples": true,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(opened.get("ok", false)), "new game")
	var spun: Dictionary = eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""})
	t.ok(bool(spun.get("ok", false)), "month wheel")
	var month: Dictionary = eng.send(&"month.begin", {})
	t.ok(bool(month.get("ok", false)), "month begin")
	var day: Dictionary = eng.send(&"day.begin", {})
	t.ok(bool(day.get("ok", false)), "day begin")
	var uid: String = _fortune_uid(eng)
	if uid == "":
		uid = CardPiles.spawn(eng.ctx, "ev.any.fortune_teller", CardIds.ZONE_HAND)
	var result: Dictionary = eng.send(&"fortune.lot", {"uid": uid})
	t.ok(bool(result.get("ok", false)), "fortune.lot ok err=" + str(result.get("err", "")))
	var lot_id: String = str(result.get("lot", ""))
	var date: Dictionary = eng.view().get("date", {})
	var pool: PackedStringArray = eng.ctx.db.pool(&"fortune_lot", str(date.get("era", "")))
	t.ok(lot_id != "" and pool.has(lot_id), "lot in example pool: " + lot_id)


func _fortune_uid(eng: CardEngine) -> String:
	var hand: Array = eng.view().get("hand", [])
	for card in hand:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = card
		if str(row.get("panel", "")) == "fortune":
			return str(row.get("uid", ""))
	return ""


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback
