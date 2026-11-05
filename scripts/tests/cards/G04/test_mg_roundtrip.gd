# G04 鉴定改版收尾（DESIGN §13 test_mg_roundtrip，五路小游戏都合进来以后）：真引擎参数 → 真场景 autoplay → 引擎 judge。
# autoplay(1.0) 交回的判断一件也不冤枉人，能说中的都说中；autoplay(0.0) 在没毛病的东西上会冤枉人；
# 观察按真目录的 hedge 规则记得下来；op 回放一致（lib/mg_ops.gd）。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const MgOps = preload("res://scripts/tests/cards/lib/mg_ops.gd")

const SCENES := {
	"spot": "res://scenes/cards/minigames/spot/SpotGame.tscn",
	"coin_ring": "res://scenes/cards/minigames/coin_ring/CoinRingGame.tscn",
	"weigh": "res://scenes/cards/minigames/weigh/WeighGame.tscn",
	"fragments": "res://scenes/cards/minigames/fragments/FragmentsGame.tscn",
	"decode": "res://scenes/cards/minigames/decode/DecodeGame.tscn",
}


func _initialize() -> void:
	var t := T.new(self, "G04_mg_roundtrip")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await t.frames(1)
	var holder := Control.new()
	root.add_child(holder)
	var db := CardDB.load_all(CardDB.DEFAULT_ROOT, {})
	CardText.setup(db)
	for kind in ["spot", "coin_ring", "weigh", "fragments", "decode"]:
		var cases: Array = []
		if kind == "decode":
			cases = MgOps.engine_cases(&"decode", false, 1)
		else:
			cases = MgOps.engine_cases(StringName(kind), false, 3) + MgOps.engine_cases(StringName(kind), true, 3)
		t.ok(not cases.is_empty(), "%s: engine cases" % kind)
		var wrong_at_zero := 0
		var sound_cases := 0
		for c in cases:
			var params: Dictionary = c["params"]
			var good := _play(holder, kind, params, 1.0)
			var v := MgOps.judge(StringName(kind), c["answer"], good)
			t.ok(not good.is_empty() and not bool(good.get("aborted", true)), "%s: autoplay(1.0) finishes" % kind)
			t.eq(int(v["wrong"]), 0, "%s (fake=%s): a perfect clerk wrongs nobody" % [kind, c["fake"]])
			if kind == "spot":
				t.ok(int(v["right"]) + int(v["soft"]) >= 1, "spot: a perfect clerk names what is there")
				var differs := 0
				for mk in c["answer"]["marks"]:
					differs += 1 if str(mk[1]) == "differs" else 0
				t.eq(int(v["right"]), differs, "spot: every tampered or scraped mark is named (fake=%s)" % c["fake"])
			elif kind == "coin_ring" and bool(c["fake"]):
				t.ok(int(v["right"]) >= 1, "coin fake: the dull coin is named")
			elif kind == "fragments" and bool(c["fake"]):
				t.ok(int(v["right"]) >= 1, "fragments fake: the odd paper or the offset seal is named")
			elif kind == "decode":
				t.eq(int(v["right"]), (c["answer"]["codes"] as Array).size(), "decode: every group copied right")
			elif kind == "weigh" and str(c["answer"]["cat"]) in ["light_much", "heavy"]:
				t.eq(int(v["right"]), 1, "weigh: a clearly short or heavy weight is named")
			var kept := CardAppraisal.record(db.obs_catalog(StringName(kind)), "clear", good.get("observations", []))
			t.ok(not kept.is_empty(), "%s: the perfect clerk's claims are recorded at full clarity" % kind)
			var bad := _play(holder, kind, params, 0.0)
			var v0 := MgOps.judge(StringName(kind), c["answer"], bad)
			if not bool(c["fake"]):
				sound_cases += 1
				wrong_at_zero += int(v0["wrong"])
			if kind == "spot" or kind == "coin_ring":
				if not bool(c["fake"]):
					t.ok(int(v0["wrong"]) >= 1, "%s sound: a careless clerk wrongs the customer" % kind)
			if kind == "decode":
				t.ok(int(v0["wrong"]) >= 1, "decode: a careless clerk copies a wrong word")
			t.eq(MgOps.replay_check(holder, str(SCENES[kind]), params, [0.0, 0.8, 1.0]), PackedStringArray(), "%s: op replay" % kind)
		if kind in ["spot", "coin_ring", "fragments"]:
			t.ok(sound_cases == 0 or wrong_at_zero >= 1, "%s: careless play on sound goods produces wrongs" % kind)
	holder.queue_free()
	await t.frames(2)


func _play(holder: Node, kind: String, params: Dictionary, skill: float) -> Dictionary:
	var game := MgOps.open(holder, str(SCENES[kind]), params)
	if game == null:
		return {}
	var r: Dictionary = MgOps.autoplay(game, skill)["result"]
	game.queue_free()
	return r
