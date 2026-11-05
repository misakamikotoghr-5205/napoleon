## Earned squad promotions must reach the real battlefield in volume two.
## Every state change uses public commands on the authored Toulon opening.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Policy = preload("res://scripts/tests/cards/OCEAN/napoleon_policy.gd")
const Replay = preload("res://scripts/cards/campaign/run/run_replay.gd")
const Bridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const COMPANION := "baptiste"
var t: RefCounted

func _initialize() -> void:
	t = T.new(self, "OCEAN_napoleon_promotion")
	CardSave.set_root(t.user_dir())
	var env := {}
	for key in ["DEHOUDANG_CAMPAIGN", "DEHOUDANG_START"]:
		env[key] = [OS.has_environment(key), OS.get_environment(key)]
		OS.unset_environment(key)
	_case("napoleon", 2)
	_case("napoleon_volume1", 1)
	for key in env:
		if env[key][0]:
			OS.set_environment(key, env[key][1])
		else:
			OS.unset_environment(key)
	print("OCEAN promotion assertions: %d" % t.checks)
	t.finish()

func _send(engine: CardEngine, cmd: StringName, args: Dictionary = {}) -> bool:
	var result := engine.send(cmd, args)
	t.ok(result.get("ok", false), str(cmd) + " " + str(args) + " -> " + str(result))
	return bool(result.get("ok", false))

func _row(rows: Array, key: String, value: String) -> Dictionary:
	for row in rows:
		if str(row.get(key, "")) == value:
			return row
	return {}

func _companion(engine: CardEngine) -> Dictionary:
	return _row(engine.query(&"campaign").get("companions", []), "id", COMPANION)

func _battle(engine: CardEngine) -> Dictionary:
	return engine.query(&"campaign").get("battle2", {})

func _case(book: String, volume: int) -> void:
	var prefix := "v%d" % volume
	var baseline := CardEngine.new()
	var opened := baseline.new_game({"book": book, "seed": 30, "save_dir": t.user_dir() + "/" + prefix})
	t.ok(opened.get("ok", false), prefix + " authored opening starts")
	if not opened.get("ok", false):
		return
	t.eq(baseline.query(&"campaign.run").get("volume"), volume, prefix + " version gate")
	var policy := Policy.new()
	policy.train_for_campaign = false
	var reached: bool = policy.finish(baseline, 100, "toulon_mulgrave")
	t.ok(reached, prefix + " reaches first battle through legal play: " + policy.last_error)
	if not reached:
		return
	t.eq(policy.battles.size(), 0, prefix + " no previous battles or fixture mutations")
	var before := _companion(baseline)
	t.ok(before.get("recruited", false), prefix + " opening story recruited Baptiste")
	var path: String = t.user_dir() + "/" + prefix + "-before.json"
	t.ok(baseline.save_game(path).get("ok", false), prefix + " saves earned prebattle checkpoint")
	var promoted := CardEngine.new()
	t.ok(promoted.load_game(path).get("ok", false), prefix + " forks identical legal checkpoint")
	var option := _row(promoted.query(&"card", {"uid": "squad"}).get("choices", []), "id", "action:promote:" + COMPANION)
	t.ok(option.get("enabled", false), prefix + " squad promotion is publicly enabled")
	var medals := int(promoted.query(&"campaign").get("coins", {}).get("medal", 0))
	if not _send(promoted, &"card.choose", {"uid": "squad", "choice": "action:promote:" + COMPANION}):
		return
	var after := _companion(promoted)
	t.eq(after.get("level"), int(before["level"]) + 1, prefix + " promotion increases level")
	t.eq(after.get("max_hp"), int(before["max_hp"]) + 25, prefix + " roster gains 25 HP")
	t.eq(after.get("atk"), int(before["atk"]) + 6, prefix + " roster gains six attack")
	t.eq(promoted.query(&"campaign").get("coins", {}).get("medal"), medals - 1, prefix + " promotion spends an earned medal")
	if not _send(baseline, &"campaign.battle_prepare") or not _send(promoted, &"campaign.battle_prepare"):
		return
	t.eq(_battle(promoted).get("template"), _battle(baseline).get("template"), prefix + " compares the same first battlefield")
	var initial := _row(_battle(baseline).get("lineup", {}).get("candidates", []), "id", COMPANION)
	var grown := _row(_battle(promoted).get("lineup", {}).get("candidates", []), "id", COMPANION)
	var hp_delta := 25 if volume == 2 else 0
	var atk_delta := 6 if volume == 2 else 0
	var public_army := _row(promoted.query(&"campaign").get("army", {}).get("companions", []), "id", COMPANION)
	t.eq(public_army.get("max_hp"), int(initial.get("max_hp", 0)) + hp_delta, prefix + " public army shows the effective promoted health")
	t.eq(grown.get("max_hp"), int(initial.get("max_hp", 0)) + hp_delta, prefix + " lineup follows the versioned promotion rule")
	t.eq(grown.get("atk"), int(initial.get("atk", 0)) + atk_delta, prefix + " lineup attack follows the versioned promotion rule")
	var deployed: Array = []
	for engine in [baseline, promoted]:
		if not _send(engine, &"campaign.battle_begin", {"companions": [COMPANION], "troops": [], "protagonist": false}):
			return
		var spot := {}
		for cell in _battle(engine).get("view", {}).get("grid", {}).get("cells", []):
			var args := {"unit": COMPANION, "col": cell["col"], "row": cell["row"], "facing": "right"}
			if engine.query(&"campaign.battle_preview", {"cmd": "deploy", "args": args}).get("ok", false):
				spot = args
				break
		t.ok(not spot.is_empty(), prefix + " public preview supplies a legal deployment")
		if spot.is_empty() or not _send(engine, &"campaign.battle_cmd", {"cmd": "deploy", "args": spot}):
			return
		deployed.append(_row(_battle(engine).get("view", {}).get("battle_units", []), "uid", COMPANION))
	t.eq(deployed[1].get("max_hp"), int(deployed[0].get("max_hp", 0)) + hp_delta, prefix + " actual deployed unit gets the intended HP")
	t.eq(deployed[1].get("atk"), int(deployed[0].get("atk", 0)) + atk_delta, prefix + " actual deployed unit gets the intended attack")
	var public_battle := _battle(promoted)
	var before_hash := promoted.state_hash()
	var saved: String = t.user_dir() + "/" + prefix + "-deployed.json"
	t.ok(promoted.save_game(saved).get("ok", false), prefix + " saves promoted deployed unit")
	t.ok(promoted.load_game(saved).get("ok", false), prefix + " loads promoted deployed unit")
	t.eq(promoted.state_hash(), before_hash, prefix + " save/load restores exact state")
	t.eq(_battle(promoted), public_battle, prefix + " save/load preserves all public battlefield stats")
	t.eq(_companion(promoted), after, prefix + " save/load preserves promoted roster")
	var log := promoted.command_log()
	t.ok(["card.choose", {"uid": "squad", "choice": "action:promote:" + COMPANION}] in log, prefix + " promotion is a replayable public command")
	var verified := Replay.verify(CardSave.read(saved), t.user_dir(), Bridge.new_model, Bridge.dispatch_model)
	t.ok(verified.get("ok", false), prefix + " full command replay reproduces promoted battle: " + str(verified))
