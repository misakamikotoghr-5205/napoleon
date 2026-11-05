# 策略尊重公开 used_today；真实掷完后不再候选自己，第二天恢复。
# G06；合同1.2 §7.4.3、§12.6；只在测试搭场景时用ctx，不用于决策。
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Scenario := preload("res://scripts/tests/cards/G06/scenario.gd")
const FuzzActions := preload("res://scripts/cards/sim/fuzz_actions.gd")


func _initialize() -> void:
	var t: RefCounted = T.new(self, "G06_policy_sources")
	var data_root: String = Scenario.build(t.user_dir() + "/data")
	var file: FileAccess = FileAccess.open(data_root + "/_examples/g06_self_probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"cards": [{"id": "ev.g06.self_probe", "type": "event", "era": ["*"],
		"weight": 0, "must_resolve": true, "brief": "TEST_SELF",
		"slots": [{"id": "actor", "accepts": ["self"], "attr": "nerve", "required": true, "max": 1}],
		"check": {"need": 1, "on_success": [], "on_fail": []},
		"_provenance": {"by": "ai", "task": "G06", "date": "2026-10-13"}}]}))
	file = null
	var e: CardEngine = CardEngine.new()
	t.ok(e.new_game({"seed": 7, "only_examples": true, "data_root": data_root,
		"save_dir": t.user_dir()}).get("ok", false), "real new game")
	e.send(&"day.end", {"confirm": true})
	e.send(&"day.begin", {})
	var policy: CardPolicy = CardPolicy.new(7)
	var uid: String = CardPiles.spawn(e.ctx, "ev.g06.self_probe", &"hand")
	t.eq(policy._sources("self", e, e.view(), {}, false), [{"kind": "self"}], "unused self is a legal candidate")
	t.ok(_has_self(FuzzActions.legal_actions(e, e.view()), uid), "fuzz includes unused self")
	t.ok(e.send(&"slot.place", {"uid": uid, "slot": "actor", "source": {"kind": "self"}}).get("ok", false), "real self placement")
	t.ok(e.send(&"slot.roll", {"uid": uid}).get("ok", false), "real self toss")
	t.ok(e.view().get("self", {}).get("used_today", false), "public view reports today use")
	var second: String = CardPiles.spawn(e.ctx, "ev.g06.self_probe", &"hand")
	t.eq(e.send(&"slot.place", {"uid": second, "slot": "actor", "source": {"kind": "self"}}).get("err", ""),
		"person_busy", "actual rule rejects repeat self use")
	t.eq(policy._sources("self", e, e.view(), {}, false), [], "policies suppress known used self")
	t.ok(not _has_self(FuzzActions.legal_actions(e, e.view()), second), "fuzz suppresses known used self")
	e.send(&"day.end", {"confirm": true})
	e.send(&"day.end", {"confirm": true})
	e.send(&"day.end", {"confirm": true})
	e.send(&"day.begin", {})
	t.ok(not e.view().get("self", {}).get("used_today", true), "new day restores self availability")
	t.eq(policy._sources("self", e, e.view(), {}, false), [{"kind": "self"}], "policies restore self next day")
	var third: String = CardPiles.spawn(e.ctx, "ev.g06.self_probe", &"hand")
	t.ok(_has_self(FuzzActions.legal_actions(e, e.view()), third), "fuzz restores self next day")
	t.finish()


func _has_self(actions: Array, uid: String) -> bool:
	for action in actions:
		if str(action[0]) == "slot.place" and str(action[1].get("uid", "")) == uid \
				and str(action[1].get("source", {}).get("kind", "")) == "self":
			return true
	return false
