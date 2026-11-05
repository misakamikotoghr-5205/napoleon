# RG1_zero: the example set (no relic cards) played by the fair autoplay policy for ten days never grows a "relic"
# namespace and its view never shows a "relics" block; the relics query answers an empty shelf; a second run with
# the same seed hashes the same. Zero identity for data without relics (ROGUE_V1.md §1, §3). Owner RG1.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fair = preload("res://scripts/cards/sim/policies/fair.gd")
const Api = preload("res://scripts/cards/relic/relic_api.gd")


func _initialize() -> void:
	var t := T.new(self, "RG1_zero")
	var hashes: Array = []
	for run in range(2):
		var e := CardEngine.new()
		var r := e.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir() + "/run%d" % run})
		t.ok(bool(r.get("ok", false)), "examples game %d" % run)
		t.ok(not Api.active(e.ctx), "no relic cards in the example set -> module off")
		var policy = Fair.new(7)
		for until in [3, 6, 10]:
			var res: Dictionary = CardAutoplay.play(e, policy, {"days": until, "max_steps": 6000})
			t.ok(bool(res.get("ok", false)), "fair autoplay to day %d: %s" % [until, res.get("game_over_reason", "")])
			t.ok(not e.ctx.state.data.has("relic"), "day %d: no relic namespace" % until)
			t.ok(not e.view().has("relics"), "day %d: no relics view block" % until)
		t.ok(int(e.view()["date"]["abs_day"]) >= 10, "ten days played")
		t.eq(e.query(&"relics"), {"ok": true, "err": "", "cap": 6, "count": 0, "dormant": false, "held": []},
			"relics query: empty shelf")
		hashes.append(e.state_hash())
	t.eq(hashes[0], hashes[1], "same seed, same hash")
	t.finish()
