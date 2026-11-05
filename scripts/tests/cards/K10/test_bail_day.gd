# K10 V36 补丁（#162 GPT P1）：ws.1938.big.zhuidi_levy 发 bf.1938.bail_shop 必须尊重目标牌 day_gte:28。
# 第 27 天跑扇区效果：只抬热、手里没有 bail_shop；第 28 天再跑：发到手上。两天 heat 均 +6。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const BF := "bf.1938.bail_shop"
const SEG := "ws.1938.big.zhuidi_levy"


func _initialize() -> void:
	var t := T.new(self, "K10_bail_day")
	_assert_cond_form(t)
	_assert_day(t, 27, false)
	_assert_day(t, 28, true)
	t.finish()


func _assert_day(t, day: int, expect: bool) -> void:
	var bus := CardEventBus.new()
	var e := CardEngine.new(bus)
	var r := e.new_game({"seed": 3, "stage": 0, "only_examples": false, "save_dir": t.user_dir() + "/d%d" % day})
	t.ok(bool(r.get("ok")), "new_game day %d" % day)
	e.ctx.state.ns("loop")["stage_day"] = day
	e.ctx.state.ns("loop")["abs_day"] = day
	e.ctx.state.ns("loop")["phase"] = "day"
	var heat0 := CardMeters.value(e.ctx, &"heat")
	var before := _has(e, BF)
	var seg: Dictionary = e.ctx.db.def(SEG)
	e.ctx.run(seg.get("effects", []), "K10:test/" + SEG)
	var after := _has(e, BF)
	var heat1 := CardMeters.value(e.ctx, &"heat")
	t.eq(before, false, "day %d: not already holding" % day)
	t.eq(after, expect, "day %d: bail_shop dealt=%s" % [day, expect])
	t.eq(heat1 - heat0, 6, "day %d: heat +6 unconditional" % day)
	bus.free()


func _has(e: CardEngine, def_id: String) -> bool:
	for c in e.view().get("hand", []):
		if str(c.get("def", "")) == def_id: return true
	return false


func _assert_cond_form(t) -> void:
	var raw := FileAccess.get_file_as_string("res://data/cards/fortune/segments_1938.json")
	var data = JSON.parse_string(raw)
	var n := 0
	for d in (data.get("cards", data) if data is Dictionary else data):
		if d is Dictionary and str(d.get("id", "")) == SEG:
			n += _walk(t, d.get("effects", []))
	t.ok(n > 0, "zhuidi_levy has at least one if.cond")


func _walk(t, v) -> int:
	var n := 0
	if v is Array:
		for x in v: n += _walk(t, x)
	elif v is Dictionary:
		if v.has("cond") and v["cond"] is Dictionary:
			var c: Dictionary = v["cond"]
			n += 1
			t.ok(not c.has("op"), "cond has no 'op' key: %s" % JSON.stringify(c))
			t.eq(c.size(), 1, "cond is single-key object: %s" % JSON.stringify(c))
			if c.has("day_gte"): t.eq(int(c["day_gte"]), 28, "day_gte is 28")
		for k in v: n += _walk(t, v[k])
	return n
