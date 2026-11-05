# 世界地图内核（WORLD_MAP_DESIGN §5、§7）：开图时一次定下的随机槽和牌组、骰子与行军牌、连线 / 雾 / 锁、节点门禁、
# 驿站印与开拔（含「锚点没走完不许开拔」）、军议改 Boss、过路费 / 对手 / 强制节点、兵站与成套加成、道具和营令旗的地图效果、
# 航程、事件与插曲、天数预算与强制开拔、查询不漏雾里的东西、校验器认迷你书并拒绝 R1–R12 的反例、每张图存档往返。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/OCEAN/run_helpers.gd")
const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const MapValidate = preload("res://scripts/cards/campaign/map/map_validate.gd")
const MapQuery = preload("res://scripts/cards/campaign/map/map_query.gd")
const RunBook = preload("res://scripts/cards/campaign/run/run_book.gd")
const View = preload("res://scripts/cards/campaign/ocean_view.gd")
const B2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_map")
	CardSave.set_root(t.user_dir())
	_test_open_sheet()
	_test_dice_and_cards()
	_test_move_rules()
	_test_fog_and_scout()
	_test_gates()
	_test_muster()
	_test_council_and_boss_mods()
	_test_tolls_and_forced()
	_test_rivals()
	_test_depots_and_sets()
	_test_props_and_signs()
	_test_voyage()
	_test_events_and_interludes()
	_test_days_budget()
	_test_query()
	_test_validator_accepts_mini()
	_test_validator_rejects()
	_test_save_restore_each_map()
	print("OCEAN map assertions: %d" % t.checks)
	t.finish()


# ---------------------------------------------------------------- 工具

func _mini(seed_value: int = 7, extra: Dictionary = {}) -> RefCounted:
	var c = H.new_mini(seed_value, extra)
	t.ok(c != null, "mini book starts " + str(extra) + " " + H.last_error)
	return c


func _send(c, cmd: String, args: Dictionary = {}) -> Dictionary:
	var r: Dictionary = H.send(c, cmd, args)
	t.ok(bool(r["ok"]), "%s %s ok (%s)" % [cmd, args, H.last_error])
	return r


func _reject(c, cmd: String, args: Dictionary, err: String, label: String) -> void:
	var before: String = c.hash()
	var r: Dictionary = c.send(StringName(cmd), args)
	t.eq([bool(r["ok"]), str(r["err"])], [false, err], label)
	t.eq(c.hash(), before, label + " leaves state unchanged")


func _map(c) -> Dictionary:
	return c.state["map"]


## 直接把人放到某个节点上（只用来布置测试场景；之后的命令都走正路）
func _put(c, id: String, mp: int = 0) -> void:
	_map(c)["pos"] = id
	_map(c)["mp"] = mp
	_map(c)["pending"] = ""
	_map(c)["pending_kind"] = ""
	MapRules.reveal_around(c)


func _bundle() -> Dictionary:
	var loaded := RunBook.load_bundle(H.MINI)
	return (loaded["book"] as Dictionary).duplicate(true)


func _sheet(b: Dictionary, seg: String, ch: String) -> Dictionary:
	return MapRules.sheet_of(b, seg, ch)


func _node(sheet: Dictionary, id: String) -> Dictionary:
	return MapRules.node_of(sheet, id)


# ---------------------------------------------------------------- 开图

func _test_open_sheet() -> void:
	var a = _mini(7)
	var b = _mini(7)
	t.eq(_map(a), _map(b), "same seed: same sheet, slots, deck and hand")
	t.eq(str(_map(a)["sheet"]), "mt_one", "first chapter opens its sheet")
	t.eq(str(_map(a)["pos"]), "a_arrive", "player starts on the start node")
	t.eq((_map(a)["hand"] as Array).size(), 3, "hand is dealt to 3 cards")
	t.ok("a_slot1" in _map(a)["revealed"], "fog:type node two links away is revealed")
	var slot: Dictionary = _map(a)["slots"]["a_slot1"]
	t.ok(str(slot["kind"]) in MapRules.SLOT_KINDS, "slot rolled to a known kind")
	if str(slot["kind"]) == "event":
		t.ok(not a.event_def(str(slot["id"])).is_empty() and str(slot["id"]) in a.state["run"]["events_seen"], "event slot picked a real event and marked it seen")
	var differs := false
	for s in range(8, 20):
		var c = H.new_mini(s, {"stage": 1})
		var d = H.new_mini(7, {"stage": 1})
		if _map(c)["slots"] != _map(d)["slots"] or _map(c)["deck"] != _map(d)["deck"]:
			differs = true
			break
	t.ok(differs, "other seeds roll other slots or decks")
	# 读档以后随机槽原样（不再重掷）
	var c2 = _mini(9, {"stage": 1})
	var snap: Dictionary = c2.snapshot()
	var r = Campaign.new()
	r.load_book(H.MINI)
	t.ok(bool(r.restore(snap)["ok"]), "restore a fresh sheet")
	t.eq(_map(r)["slots"], snap["map"]["slots"], "slots survive save/load untouched")
	# 和战斗节点相邻的槽去掉 battle 权重（只剩 battle 时变成营地）
	var c3 = _mini(7, {"stage": 1})
	var node := _node(MapRules.sheet(c3), "b_slot4")
	node["slot"] = {"pool": "mt_two", "kinds": {"battle": 5}, "level": 1}
	MapRules.open_sheet(c3, "mt_two")
	t.eq(str(_map(c3)["slots"]["b_slot4"]["kind"]), "camp", "battle weight dropped next to the elite (R2)")


# ---------------------------------------------------------------- 骰子与行军牌

func _test_dice_and_cards() -> void:
	var c = _mini(7)
	_reject(c, "campaign.map_roll", {}, "bad_phase", "no rolling before the day starts")
	H.to_day(c)
	_reject(c, "campaign.map_roll", {"steps": "4"}, "bad_args", "steps must be an int")
	_reject(c, "campaign.map_roll", {"steps": 7}, "bad_args", "steps 1..6")
	_reject(c, "campaign.map_roll", {"dice": 1}, "bad_args", "unknown key")
	var want := MapRules.seed_for(int(c.state["seed"]), "dice|trunk|0") % 6 + 1
	var r := _send(c, "campaign.map_roll")
	t.eq(int(r["steps"]), want, "dice = seed_for(seed, dice|seg|n) % 6 + 1")
	t.eq(int(_map(c)["mp"]), want, "dice give MP")
	t.eq(int(c.state["run"]["dice"]), 1, "dice counter is per run")
	_reject(c, "campaign.map_roll", {}, "already_used", "one roll per day")
	_reject(c, "campaign.map_card", {"index": 0}, "already_used", "roll or card, not both")
	H.next_day(c)
	t.eq(int(_map(c)["mp"]), 0, "MP is cleared overnight")
	t.ok("prop_loaded_dice" in c.state["rogue"]["props"], "starts with the compass dice")
	_send(c, "campaign.map_roll", {"steps": 4})
	t.eq(int(_map(c)["mp"]), 4, "chosen steps with the compass dice")
	t.ok(not "prop_loaded_dice" in c.state["rogue"]["props"], "compass dice consumed")
	H.next_day(c)
	var intel := int(c.state["rogue"]["coins"]["intel"])
	_send(c, "campaign.map_roll", {"steps": 5})
	t.eq(int(c.state["rogue"]["coins"]["intel"]), intel - 1, "chosen steps cost one intel without the dice")
	H.next_day(c)
	c.state["rogue"]["coins"]["intel"] = 0
	_reject(c, "campaign.map_roll", {"steps": 2}, "missing_item", "no dice and no intel")
	_reject(c, "campaign.map_card", {}, "bad_args", "card needs an index")
	_reject(c, "campaign.map_card", {"index": 9}, "bad_args", "index out of the hand")
	var hand: Array = (_map(c)["hand"] as Array).duplicate()
	var card := MapRules.card_def(c, str(hand[0]))
	var rc := _send(c, "campaign.map_card", {"index": 0})
	t.eq(int(rc["mp"]), int(card.get("mp", 0)), "card gives its MP")
	t.ok(str(hand[0]) in _map(c)["discard"] and (_map(c)["hand"] as Array).size() == 2, "played card goes to the discard")
	H.next_day(c)
	t.eq((_map(c)["hand"] as Array).size(), 3, "hand refilled to 3 every morning")
	# 牌组抽完按固定顺序收回弃牌
	_map(c)["deck"] = []
	_map(c)["discard"] = ["march_3", "march_2"]
	_map(c)["hand"] = ["scout_1"]
	MapRules._refill_hand(c)
	t.eq(_map(c)["hand"], ["scout_1", "march_3", "march_2"], "empty deck: discards come back in order, no reshuffle")


# ---------------------------------------------------------------- 走路

func _test_move_rules() -> void:
	var c = _mini(7)
	H.to_day(c)
	_reject(c, "campaign.map_move", {"to": "a_post"}, "no_mp", "no MP yet")
	_reject(c, "campaign.map_move", {"to": "a_muster"}, "not_adjacent", "not adjacent")
	_reject(c, "campaign.map_move", {"to": "nowhere"}, "bad_args", "unknown node")
	_reject(c, "campaign.map_move", {"to": 3}, "bad_args", "to must be a string")
	_send(c, "campaign.map_roll", {"steps": 3})
	var supply := int(c.state["rogue"]["coins"]["supply"])
	_send(c, "campaign.map_move", {"to": "a_post"})
	t.eq(str(_map(c)["pos"]), "a_post", "moved one leg")
	t.eq([int(_map(c)["mp"]), int(_map(c)["stamps"])], [2, 1], "leg paid; post stamped on arrival")
	t.eq(int(c.state["rogue"]["coins"]["supply"]), supply + 1, "pass effect paid on arrival")
	_send(c, "campaign.map_move", {"to": "a_muster"})
	t.eq([str(_map(c)["pos"]), int(_map(c)["mp"])], ["a_muster", 0], "a 2-leg link costs 2 MP")
	t.ok("a_post" in _map(c)["visited"] and "a_muster" in _map(c)["visited"], "visited nodes recorded")
	H.next_day(c)
	_send(c, "campaign.map_roll", {"steps": 2})
	_reject(c, "campaign.map_move", {"to": "a_council"}, "locked", "campaign-phase nodes are locked before muster")
	_send(c, "campaign.map_move", {"to": "a_post"})
	t.eq(int(_map(c)["stamps"]), 1, "a post stamps only once")
	# 连线的军需券；不够照走，缺一张体力 −5
	var d = _mini(7, {"stage": 1})
	H.to_day(d)
	_put(d, "b_supply", 2)
	d.state["rogue"]["coins"]["supply"] = 0
	var vit := int(d.state["metrics"]["vitality"])
	_send(d, "campaign.map_move", {"to": "b_slot1"})
	t.eq(int(d.state["metrics"]["vitality"]), vit - 5, "short one supply: vitality -5")
	t.ok(d.state["ledger"].any(func(row): return str(row.get("type", "")) == "map_starve"), "starvation is in the ledger")
	_put(d, "b_supply", 2)
	d.state["rogue"]["coins"]["supply"] = 3
	_send(d, "campaign.map_move", {"to": "b_slot1"})
	t.eq(int(d.state["rogue"]["coins"]["supply"]), 2, "link supply cost paid in supply coins")


func _test_fog_and_scout() -> void:
	var c = _mini(7, {"stage": 1})
	H.to_day(c)
	t.ok("b_slot1" in _map(c)["revealed"], "type fog within 2 links revealed")
	t.ok(not "b_slot3" in _map(c)["revealed"], "type fog 3 links away stays dark")
	t.ok(not MapRules.visible(c, "b_slot2"), "hidden node invisible from afar")
	var q := MapQuery.map(c)
	var ids: Array = []
	for n in q["nodes"]:
		ids.append(str(n["id"]))
	t.ok(not "b_slot2" in ids, "query leaves hidden nodes out")
	for n in q["nodes"]:
		if str(n["id"]) == "b_slot3":
			t.eq([str(n["type"]), str(n["state"]), n.has("scene"), n.has("level")], ["?", "fog", false, false], "fogged node shows only '?'")
	var intel := int(c.state["rogue"]["coins"]["intel"])
	_send(c, "campaign.map_scout", {"node": "b_slot3"})
	t.ok("b_slot3" in _map(c)["revealed"] and int(c.state["rogue"]["coins"]["intel"]) == intel - 1, "scouting costs one intel")
	_reject(c, "campaign.map_scout", {"node": "b_slot3"}, "already_used", "scout twice")
	_reject(c, "campaign.map_scout", {"node": "zzz"}, "bad_args", "scout unknown node")
	c.state["rogue"]["coins"]["intel"] = 0
	_reject(c, "campaign.map_scout", {"node": "b_elite"}, "insufficient_funds", "scouting without intel")
	# 相邻的 hidden 会自己出现；没揭开就走 = fog
	_put(c, "b_elite", 2)
	t.ok("b_slot2" in _map(c)["revealed"], "hidden node appears when adjacent")
	_map(c)["revealed"].erase("b_slot2")
	_reject(c, "campaign.map_move", {"to": "b_slot2"}, "fog", "cannot walk into unrevealed hidden fog")
	# 黄铜望远镜（单数种子起手就有）：两段以内全揭开
	var s = _mini(7, {"stage": 1})
	H.to_day(s)
	t.ok("prop_spyglass" in s.state["rogue"]["props"], "odd seed starts with the spyglass")
	_send(s, "campaign.use_prop", {"id": "prop_spyglass"})
	t.ok("b_slot4" in _map(s)["revealed"] and "b_supply" in _map(s)["revealed"], "spyglass reveals within two links")


# ---------------------------------------------------------------- 节点门禁

func _test_gates() -> void:
	var c = _mini(7)
	H.to_day(c)
	_reject(c, "campaign.visit", {"place": "town"}, "wrong_node", "no town visit on a story node")
	_put(c, "a_post")
	_send(c, "campaign.visit", {"place": "town"})
	_reject(c, "campaign.choose", {"choice": "mt_plain"}, "wrong_node", "story choices only on the scene anchor")
	_reject(c, "campaign.appraise", {"id": "mt_seal"}, "wrong_node", "story appraisal only on the scene anchor")
	_reject(c, "campaign.activity", {"id": "rest"}, "wrong_node", "rest only where the node offers it")
	_put(c, "a_muster")
	_send(c, "campaign.activity", {"id": "rest"})
	_send(c, "campaign.schedule", {"action": "train"})
	_put(c, "a_arrive")
	_send(c, "campaign.appraise", {"id": "mt_seal"})
	_send(c, "campaign.choose", {"choice": "mt_ask"})
	t.eq(str(c.scene()["id"]), "mt_arrive", "a non-advancing choice keeps the scene")
	# 商贩：招部队、招登记在本段的伙伴
	var d = _mini(7, {"stage": 1})
	H.to_day(d)
	_put(d, "b_shop")
	d.state["rogue"]["coins"]["gold"] = 9
	_send(d, "campaign.recruit", {"id": "troop:line"})
	_send(d, "campaign.recruit", {"id": "marie"})
	t.ok(bool(d.state["rogue"]["companions"]["marie"]["recruited"]), "recruited marie at the shop")
	_reject(d, "campaign.recruit", {"id": "dantes"}, "wrong_node", "only the companions the shop lists")
	var gold_before := int(d.state["rogue"]["coins"]["gold"])
	_send(d, "campaign.map_build")
	_send(d, "campaign.recruit", {"id": "troop:jager"})
	t.eq(int(d.state["rogue"]["coins"]["gold"]), gold_before - 2 - 0, "at a depot troops cost 1 gold less")
	MapRules.node_of(MapRules.sheet(d), "b_shop")["actions"].append("recruit:ney")
	_reject(d, "campaign.recruit", {"id": "ney"}, "wrong_segment", "ney is not in the trunk")
	# 催逼：在写了它的节点（或书里 demand_nodes 登记的节点）交付
	var o = _mini(7, {"segment": "ocean", "stage": 1})
	H.to_day(o)
	t.eq(str(o.state["demands"][0]["id"]), "o_mini_medicine", "scene on_enter issued the demand")
	t.eq(str(o.state["demands"][0]["title"]), "岛上缺药", "demand title from the segment data")
	_put(o, "p_market")
	_send(o, "campaign.visit", {"place": "town"})
	t.ok("o_mini_herbs" in o.state["inventory"], "town visit gives this chapter's item (rules.actions)")
	_put(o, "p_post")
	_reject(o, "campaign.demand", {"id": "o_mini_medicine", "action": "fulfill"}, "wrong_node", "demand only where it can be handed in")
	o.book["raw"]["segments"]["ocean"]["demand_nodes"] = {"o_mini_medicine": ["mo_two:p_post"]}
	_send(o, "campaign.demand", {"id": "o_mini_medicine", "action": "fulfill"})
	t.ok(bool(o.state["flags"].get("o_mini_med_ok", false)), "fulfilled demand sets its flag")


# ---------------------------------------------------------------- 开拔

func _test_muster() -> void:
	var c = _mini(7)
	H.to_day(c)
	_put(c, "a_muster")
	_map(c)["stamps"] = 1
	_reject(c, "campaign.map_muster", {}, "scene_order", "muster before the accumulate anchors are done (C5)")
	_put(c, "a_arrive")
	_send(c, "campaign.choose", {"choice": "mt_plain"})
	t.eq(str(c.scene()["id"]), "mt_battle1", "story advanced to the boss scene")
	t.ok("a_arrive" in _map(c)["done"], "the anchor is done")
	H.to_day(c)
	_put(c, "a_post")
	_reject(c, "campaign.map_muster", {}, "wrong_node", "muster only on the muster node")
	_put(c, "a_muster")
	_map(c)["stamps"] = 0
	_reject(c, "campaign.map_muster", {}, "stamps", "muster needs the post stamps")
	_map(c)["stamps"] = 1
	var days := int(_map(c)["days_on_sheet"])
	_send(c, "campaign.map_muster")
	t.ok(bool(_map(c)["mustered"]), "mustered")
	t.eq(int(_map(c)["cp_early"]), clampi(6 - days, 0, 3), "early arrival bonus = days left, at most 3")
	_reject(c, "campaign.map_muster", {}, "already_used", "muster once")
	t.eq(MapRules.lock_reason(c, _node(MapRules.sheet(c), "a_slot1")), "mustered", "accumulate nodes lock after muster")
	t.eq(MapRules.lock_reason(c, _node(MapRules.sheet(c), "a_council")), "", "campaign nodes unlock after muster")


func _test_council_and_boss_mods() -> void:
	var c = _mini(7)
	H.to_day(c)
	_send(c, "campaign.choose", {"choice": "mt_plain"})
	H.to_day(c)
	_put(c, "a_muster")
	_map(c)["stamps"] = 1
	_send(c, "campaign.map_muster")
	var early := int(_map(c)["cp_early"])
	_put(c, "a_council")
	var r := _send(c, "campaign.map_enter")
	t.eq([str(r["kind"]), str(r["event"])], ["event", "ev_mt_council1"], "council is a fixed event")
	_send(c, "campaign.map_choose", {"choice": "prep"})
	t.eq(_map(c)["boss_mod"], {"cp_bonus": 0, "enemy_morale": 0, "prep_turn": 1}, "council choice sets the boss mod")
	t.ok("a_council" in _map(c)["done"], "council done")
	_reject(c, "campaign.map_enter", {}, "already_used", "council once")
	_map(c)["delay"] = 3
	_map(c)["boss_waves_minus"] = 1
	_put(c, "a_boss")
	_send(c, "campaign.map_enter")
	_send(c, "campaign.battle_prepare")
	var b2: Dictionary = c.state["rogue"]["battle2"]
	var waves: int = (B2.lib()["templates"]["elite_a"]["waves"] as Array).size()
	t.eq([str(b2["key"]), str(b2["kind"]), str(b2["node_kind"]), int(b2["level"])], ["mt_battle1", "scene", "boss", 1], "boss battle keyed by scene, level from the book")
	t.eq(int(b2["mods"].get("prep_turn", 0)), 1, "council prep turn reaches the boss")
	t.eq(int(b2["mods"].get("enemy_morale", 0)), 6, "3 days late: enemy morale +6")
	t.eq(b2["mods"].get("drop_waves", []), [waves - 1], "beaten rival: boss loses its last wave")
	t.eq([int(b2["mods"].get("cp_bonus", 0)), int(b2["mods"].get("_cp_early", 0))], [0, early], "early arrival noted for the first campaign battle (not a council bonus)")
	var lu: Dictionary = B2.lineup(c)
	t.eq(int(lu["turn_limit"]), int(B2.lib()["templates"]["elite_a"]["turn_limit"]) + 1, "lineup shows the extra prep turn")
	t.ok(int(lu["level"]) == 1 and int(lu["stars"]) >= 1 and int(lu["recommended"]) >= int(lu["power"]), "lineup shows level, stars, power")
	c.state["rogue"]["coins"]["supply"] = 7
	lu = B2.lineup(c)
	t.eq([int(lu["cp_opening"]), int(lu["cp_council"])], [early + 3, 0], "lineup previews the opening command points")
	_send(c, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
	t.eq(int(_map(c)["cp_early"]), 0, "early bonus used up by the first campaign battle")
	t.eq(int(c.state["rogue"]["coins"]["supply"]), 1, "supply turned into opening command points: 2 per point, at most 4")
	H.resolve_battle(c)
	t.ok(B2.resolved(c), "boss battle resolved by retreat")
	_send(c, "campaign.choose", {"choice": "mt_after1"})
	t.eq([str(_map(c)["sheet"]), str(c.state["phase"])], ["mt_two", "year_jump"], "next chapter opens its own sheet")
	t.eq(str(_map(c)["interlude"]), "ev_mt_audience", "the chapter's interlude is dealt at open")


# ---------------------------------------------------------------- 过路费、强制节点

func _test_tolls_and_forced() -> void:
	var c = _mini(7, {"segment": "conquest"})
	H.to_day(c)
	_put(c, "k_post", 1)
	var gold := int(c.state["rogue"]["coins"]["gold"])
	_send(c, "campaign.map_move", {"to": "k_fixed"})
	t.eq([str(_map(c)["pending"]), str(_map(c)["pending_kind"])], ["k_fixed", "toll"], "toll link: pending toll on arrival")
	_reject(c, "campaign.map_enter", {}, "pending_node", "settle the toll first")
	_reject(c, "campaign.map_roll", {}, "pending_node", "no new MP while a toll is pending")
	_reject(c, "campaign.map_pay", {"how": "fight"}, "bad_args", "nobody to fight at a toll")
	_send(c, "campaign.map_pay", {"how": "gold"})
	t.eq([int(c.state["rogue"]["coins"]["gold"]), str(_map(c)["pending"])], [gold - 1, ""], "paid the toll in gold")
	_reject(c, "campaign.map_pay", {"how": "gold"}, "bad_phase", "nothing to pay")
	# 没钱没金币袋就走不过去；有金币袋就用它
	_put(c, "k_post", 1)
	c.state["rogue"]["coins"]["gold"] = 0
	_reject(c, "campaign.map_move", {"to": "k_fixed"}, "insufficient_funds", "no gold for the toll")
	c.state["rogue"]["props"].append("prop_bribe_pouch")
	_send(c, "campaign.map_move", {"to": "k_fixed"})
	_send(c, "campaign.map_pay", {"how": "prop"})
	t.ok(not "prop_bribe_pouch" in c.state["rogue"]["props"], "bribe pouch pays the toll")
	# 强制节点：落上去必须先进；夜行牌不停；烟幕弹脱身
	_put(c, "k_slot4", 1)
	_send(c, "campaign.map_move", {"to": "k_outpost"})
	t.eq([str(_map(c)["pending"]), str(_map(c)["pending_kind"])], ["k_outpost", "forced"], "forced node holds the player")
	_reject(c, "campaign.map_move", {"to": "k_slot4"}, "pending_node", "cannot walk away from a forced node")
	var smoke = c.snapshot()
	_send(c, "campaign.map_enter")
	t.eq(str(c.state["rogue"]["battle2"]["phase"]), "lineup", "forced battle node prepares its battle")
	t.eq(str(c.state["rogue"]["battle2"]["key"]), "node|conquest|k_outpost", "node battle key")
	t.eq(int(c.state["rogue"]["battle2"]["level"]), 4, "node battle level from the node")
	_reject(c, "campaign.map_move", {"to": "k_slot4"}, "battle_pending", "cannot leave mid-encounter")
	H.resolve_battle(c)
	t.ok("k_outpost" in _map(c)["done"] and (_map(c)["encounter"] as Dictionary).is_empty(), "battle node done after the battle")
	c.restore(smoke)
	_send(c, "campaign.use_prop", {"id": "prop_smoke_bomb"})
	t.eq(str(_map(c)["pending"]), "", "smoke bomb slips out of a forced node")
	var n = _mini(7, {"segment": "conquest"})
	H.to_day(n)
	_put(n, "k_slot4")
	_map(n)["hand"] = ["night_2"]
	_send(n, "campaign.map_card", {"index": 0})
	_send(n, "campaign.map_move", {"to": "k_outpost"})
	t.eq(str(_map(n)["pending"]), "", "night march ignores forced nodes")
	_map(n)["mp"] = 2
	_send(n, "campaign.map_move", {"to": "k_elite"})
	t.eq(str(_map(n)["pos"]), "k_elite", "rush link allows two battle nodes in a row")


func _test_rivals() -> void:
	var c = _mini(8, {"stage": 1})
	H.to_day(c)
	var r: Dictionary = MapRules.sheet(c)["rivals"][0]
	t.eq(MapRules.rival_pos(c, r), "b_slot4", "rival starts on its path")
	var heat := int(c.state["metrics"]["heat"])
	_put(c, "b_shop", 1)
	_send(c, "campaign.map_move", {"to": "b_slot4"})
	t.eq([str(_map(c)["pending_kind"]), str(_map(c)["meet"])], ["rival", "b_raiders"], "walking onto the rival is a forced meeting")
	t.eq(int(c.state["metrics"]["heat"]), heat + 2, "meeting effects applied")
	_reject(c, "campaign.map_enter", {}, "battle_pending", "settle the rival first")
	var snap = c.snapshot()
	_send(c, "campaign.map_pay", {"how": "gold"})
	t.eq(str(_map(c)["pending"]), "", "paid off the rival")
	c.restore(snap)
	_send(c, "campaign.map_pay", {"how": "fight"})
	t.eq(str(c.state["rogue"]["battle2"]["key"]), "rival|trunk|b_raiders", "rival battle key")
	var enc: Dictionary = (_map(c)["encounter"] as Dictionary).duplicate(true)
	H.resolve_battle(c)
	t.ok(not bool(_map(c)["rivals"]["b_raiders"]["beaten"]), "a retreat does not beat the rival")
	MapRules.battle_settled(c, enc, "victory")
	t.ok(bool(_map(c)["rivals"]["b_raiders"]["beaten"]) and int(_map(c)["boss_waves_minus"]) == 1, "beaten rival: boss waves minus 1")
	# 每天走一步；停在兵站上就烧掉；拒马让它停一天
	var d = _mini(8, {"stage": 1})
	H.to_day(d)
	var rr: Dictionary = MapRules.sheet(d)["rivals"][0]
	_map(d)["depots"] = ["b_elite"]
	H.next_day(d)
	t.eq(MapRules.rival_pos(d, rr), "b_elite", "rival moves one step a day")
	t.ok(not "b_elite" in _map(d)["depots"] and d.state["ledger"].any(func(row): return str(row.get("type", "")) == "depot_lost"), "rival burns the depot it stops on")
	d.state["rogue"]["props"].append("prop_barricade")
	_send(d, "campaign.use_prop", {"id": "prop_barricade"})
	H.next_day(d)
	t.eq(MapRules.rival_pos(d, rr), "b_elite", "barricade stops the rival for a day")
	H.next_day(d)
	t.eq(MapRules.rival_pos(d, rr), "b_slot2", "then it moves on")


# ---------------------------------------------------------------- 兵站

func _test_depots_and_sets() -> void:
	var c = _mini(7, {"segment": "conquest"})
	H.to_day(c)
	_reject(c, "campaign.map_build", {}, "wrong_node", "no depot on a story node")
	_put(c, "k_post")
	c.state["rogue"]["coins"]["gold"] = 1
	_reject(c, "campaign.map_build", {}, "insufficient_funds", "a depot costs 2 gold")
	c.state["rogue"]["coins"]["gold"] = 6
	var supply := int(c.state["rogue"]["coins"]["supply"])
	_send(c, "campaign.map_build")
	t.eq([int(c.state["rogue"]["coins"]["gold"]), int(c.state["rogue"]["coins"]["supply"])], [4, supply], "depot built: -2 gold")
	_reject(c, "campaign.map_build", {}, "already_complete", "one depot per node")
	H.next_day(c)
	t.eq(int(c.state["rogue"]["coins"]["supply"]), supply + 3, "a night on your own depot: +3 supply")
	H.to_day(c)
	_put(c, "k_land", 1)
	supply = int(c.state["rogue"]["coins"]["supply"])
	_send(c, "campaign.map_move", {"to": "k_post"})
	t.eq(int(c.state["rogue"]["coins"]["supply"]), supply + 1, "passing an own depot: +1 supply")
	_put(c, "k_depot2")
	_send(c, "campaign.map_build")
	_put(c, "k_land", 1)
	supply = int(c.state["rogue"]["coins"]["supply"])
	_send(c, "campaign.map_move", {"to": "k_post"})
	t.eq(int(c.state["rogue"]["coins"]["supply"]), supply + 2, "complete set: one more supply when passing")


# ---------------------------------------------------------------- 道具与营令旗

func _test_props_and_signs() -> void:
	var c = _mini(7, {"stage": 1})
	H.to_day(c)
	c.state["rogue"]["props"].append("prop_forced_march")
	_send(c, "campaign.use_prop", {"id": "prop_forced_march"})
	t.eq(int(_map(c)["mp"]), 2, "forced-march boots: MP +2")
	_send(c, "campaign.use_prop", {"id": "prop_field_ration"})
	_put(c, "b_supply", 1)
	var supply := int(c.state["rogue"]["coins"]["supply"])
	_send(c, "campaign.map_move", {"to": "b_slot1"})
	t.eq(int(c.state["rogue"]["coins"]["supply"]), supply, "field ration: today's supply costs waived")
	var b = _mini(7, {"stage": 1})
	H.to_day(b)
	_send(b, "campaign.sign", {"sign": "black"})
	_send(b, "campaign.map_roll", {"steps": 3})
	t.eq(int(_map(b)["mp"]), 2, "black flag: MP -1")
	var red = _mini(7, {"stage": 1})
	H.to_day(red)
	_send(red, "campaign.sign", {"sign": "red"})
	_put(red, "b_march", 1)
	var s0 := int(red.state["rogue"]["coins"]["supply"])
	_send(red, "campaign.map_move", {"to": "b_shop"})
	t.eq(int(red.state["rogue"]["coins"]["supply"]), s0 + 1, "red flag: +1 supply per pass")
	var h0 := int(red.state["metrics"]["heat"])
	H.next_day(red)
	t.eq(int(red.state["metrics"]["heat"]), h0 + 10, "red flag daily heat from rules.signs")


# ---------------------------------------------------------------- 航程

func _test_voyage() -> void:
	var c = _mini(7, {"segment": "ocean"})
	H.to_day(c)
	_put(c, "o_port")
	var day := int(c.state["day"])
	_send(c, "campaign.map_move", {"to": "o_muster"})
	t.eq([str(_map(c)["pos"]), int(c.state["day"])], ["o_muster", day + 2], "a 2-day voyage spends two days")
	var d = _mini(7, {"segment": "ocean"})
	H.to_day(d)
	_put(d, "o_port", 1)
	_reject(d, "campaign.map_move", {"to": "o_muster"}, "no_mp", "voyage only with no MP in hand")
	_put(d, "o_port")
	_map(d)["hand"] = ["fair_wind"]
	_send(d, "campaign.map_card", {"index": 0})
	day = int(d.state["day"])
	_send(d, "campaign.map_move", {"to": "o_muster"})
	t.eq(int(d.state["day"]), day + 1, "fair wind shortens the voyage by a day")
	var forced = _mini(7)
	H.to_day(forced)
	_send(forced, "campaign.choose", {"choice": "mt_plain"})
	_put(forced, "a_arrive")
	_map(forced)["days_on_sheet"] = 9
	MapRules.link_between(MapRules.sheet(forced), "a_arrive", "a_post")["voyage_days"] = 7
	day = int(forced.state["day"])
	_send(forced, "campaign.map_move", {"to": "a_post"})
	t.eq([_map(forced)["pos"], _map(forced)["mustered"], int(forced.state["day"])], ["a_muster", true, day + 1], "forced muster interrupts a voyage on its actual day")
	t.ok(not "a_post" in _map(forced)["visited"], "interrupted voyage does not award arrival")
	t.ok("a_muster" in _map(forced)["visited"], "forced muster records the reachable destination")
	t.eq(MapRules.lock_reason(forced, _node(MapRules.sheet(forced), "a_council")), "", "campaign route stays accessible after interrupted voyage")


# ---------------------------------------------------------------- 事件与插曲

func _test_events_and_interludes() -> void:
	var c = _mini(7, {"segment": "conquest"})
	H.to_day(c)
	_put(c, "k_fixed")
	var r := _send(c, "campaign.map_enter")
	t.eq(str(r["event"]), "ev_mk_fixed", "fixed event node opens its event")
	_reject(c, "campaign.map_choose", {"choice": "free"}, "missing_clue", "choice needs its clue")
	var a := _send(c, "campaign.map_appraise", {"id": "mk_lock"})
	t.eq(str(a["observation"]), "锁是新的。", "event appraisal returns its observation")
	_reject(c, "campaign.map_appraise", {"id": "mk_lock"}, "already_used", "appraise once")
	_send(c, "campaign.map_choose", {"choice": "free"})
	t.ok(bool(c.state["rogue"]["companions"]["ney"]["recruited"]) and bool(c.state["flags"].get("k_mini_scout", false)), "event choice: rogue.recruit list and flags")
	t.ok("k_fixed" in _map(c)["done"] and str(_map(c)["event"]) == "", "event done")
	t.ok("k_outpost" in _map(c)["revealed"], "event reveal opens fog")
	t.ok("event:ev_mk_fixed" in c.state["used_actions"][str(c.scene()["id"])], "event use is recorded under the current scene")
	_reject(c, "campaign.map_enter", {}, "already_used", "fixed event once")
	# 插曲：问答（召见），每题二选一，答完才算完成
	var q = _mini(7, {"stage": 1})
	t.eq(str(q.state["phase"]), "month_open", "debug start opens at month_open")
	_send(q, "campaign.map_choose", {"choice": "q1:a"})
	_reject(q, "campaign.map_choose", {"choice": "q1:b"}, "already_used", "one answer per question")
	t.eq(str(_map(q)["interlude"]), "ev_mt_audience", "interlude stays until every question is answered")
	_send(q, "campaign.map_choose", {"choice": "q2:b"})
	t.eq(str(_map(q)["interlude"]), "", "audience complete")
	# 野营夜：按种子给 3 项
	var k = _mini(7, {"segment": "conquest"})
	var ev: Dictionary = k.event_def(str(_map(k)["interlude"]))
	t.eq(str(ev.get("interlude", "")), "camp_night", "camp night dealt")
	var offer := MapRules.event_choices(k, ev)
	t.eq(offer.size(), 3, "camp night offers 3 of its 4 choices")
	var k2 = _mini(7, {"segment": "conquest"})
	t.eq(MapRules.event_choices(k2, ev), offer, "offer is seeded")
	# 营火夜话：挑两位伙伴，信赖 +1
	var o = _mini(7, {"segment": "ocean"})
	t.eq(str(_map(o)["interlude"]), "ev_mo_bond", "bond interlude dealt")
	_reject(o, "campaign.map_choose", {"choice": "talk", "pick": ["ney"]}, "bad_args", "only recruited companions can be picked")
	_send(o, "campaign.map_choose", {"choice": "talk", "pick": ["baptiste", "corso"]})
	var trust: Dictionary = o.state["rogue"]["army"]["trust"]
	t.eq([int(trust.get("hero|baptiste", 0)), int(trust.get("hero|corso", 0)), int(trust.get("hero|marie", 0))], [1, 1, 0], "bond night trust +1 for the two picked")
	# 小游戏插曲：查验后才能揭穿
	var m = _mini(7, {"segment": "cristo"})
	t.eq(str(_map(m)["interlude"]), "ev_mc_weigh", "minigame interlude dealt")
	_reject(m, "campaign.map_choose", {"choice": "expose"}, "missing_clue", "weigh first")
	_send(m, "campaign.map_appraise", {"id": "mc_scale"})
	_send(m, "campaign.map_choose", {"choice": "expose"})
	# 随机槽里的事件：进去打完；once 事件这一局不会再出
	var s = _mini(7, {"stage": 1})
	H.to_day(s)
	var picked := ""
	for id in _map(s)["slots"]:
		if str(_map(s)["slots"][id]["kind"]) == "event":
			picked = str(id)
			break
	t.ok(picked != "", "some slot rolled an event")
	if picked != "":
		_put(s, picked)
		var er := _send(s, "campaign.map_enter")
		t.eq(str(er["event"]), str(_map(s)["slots"][picked]["id"]), "slot event opens")
		H.play_event(s)
		t.ok(picked in _map(s)["done"], "slot event done")


# ---------------------------------------------------------------- 天数预算

func _test_days_budget() -> void:
	var c = _mini(7)
	H.to_day(c)
	for _i in range(8):
		H.next_day(c)
	t.eq(int(_map(c)["delay"]), int(_map(c)["days_on_sheet"]) - 6, "every day past days_max adds a delay")
	t.ok(not bool(_map(c)["mustered"]), "no forced muster while the accumulate anchor is pending (C5)")
	var d = _mini(7)
	H.to_day(d)
	_send(d, "campaign.choose", {"choice": "mt_plain"})
	for _i in range(12):
		H.next_day(d)
		if bool(_map(d)["mustered"]):
			break
	t.ok(bool(_map(d)["mustered"]) and str(_map(d)["pos"]) == "a_muster", "forced muster at days_max + 4")
	t.eq(int(_map(d)["days_on_sheet"]), 10, "forced on day days_max + 4")
	t.ok(d.state["ledger"].any(func(row): return str(row.get("type", "")) == "map_muster" and bool(row.get("forced", false))), "forced muster in the ledger")


# ---------------------------------------------------------------- 查询

func _test_query() -> void:
	var c = _mini(7, {"stage": 1})
	H.to_day(c)
	var q := MapQuery.map(c)
	for key in ["enabled", "view", "frames", "sheet", "chapter", "pos", "mp", "can_roll", "hand", "days", "days_max", "delay", "stamps",
			"stamps_need", "depots", "boss_mod", "mustered", "nodes", "links", "rivals", "pending", "teaser"]:
		t.ok(q.has(key), "campaign.map has " + key)
	t.eq([bool(q["enabled"]), str(q["view"]), str(q["pos"]), int(q["days_max"])], [true, "field", "b_march", 8], "map query basics")
	t.ok((q["hand"] as Array).all(func(h): return h.has("index") and h.has("id") and h.has("mp") and h.has("label")), "hand rows")
	var boss := {}
	for n in q["nodes"]:
		if str(n["id"]) == "b_boss":
			boss = n
	t.eq([str(boss.get("state", "")), str(boss.get("reason", ""))], ["locked", "muster"], "boss locked until muster")
	t.eq([int(boss.get("level", 0)), str(boss.get("template", ""))], [3, "major_a"], "boss node shows level and template")
	t.ok(int(boss.get("power", 0)) > 0 and int(boss.get("stars", 0)) >= 1, "boss node shows power and stars")
	t.ok(t.find_floats(q).is_empty(), "map query has no floats")
	var view: Dictionary = View.query(c, &"campaign")
	t.eq([str(view["segment"]), bool(view["map"]["enabled"]), str(view["run"]["book"])], ["trunk", true, "mini"], "campaign query carries segment/map/run summaries")
	var off = _mini(7, {"stage": 1})
	var no_map := Campaign.new()
	no_map.load_definition()
	no_map.new_game({"seed": 1})
	t.eq(MapQuery.map(no_map), {"enabled": false}, "single-segment book has no map")
	t.eq(off != null, true, "query fixture alive")


# ---------------------------------------------------------------- 校验器

func _test_validator_accepts_mini() -> void:
	var b := _bundle()
	for seg in ["trunk", "conquest", "ocean", "cristo"]:
		var v := MapValidate.validate(b, seg)
		t.eq(v["errors"], [], "mini map %s passes R1-R12" % seg)


func _expect(seg: String, prefix: String, label: String, mutate: Callable) -> void:
	var b := _bundle()
	mutate.call(b)
	var errs: Array = MapValidate.validate(b, seg)["errors"]
	t.ok(errs.any(func(e): return str(e).begins_with(prefix)), "%s -> %s: %s" % [label, prefix, str(errs).left(300)])


func _test_validator_rejects() -> void:
	_expect("trunk", "R1", "path that skips every camp", func(b):
		var sh := _sheet(b, "trunk", "mt_two")
		sh["links"].append({"a": "b_slot3", "b": "b_council", "legs": 1})
		sh["links"].append({"a": "b_council", "b": "b_boss", "legs": 1}))
	_expect("trunk", "R1", "path that skips every supply/shop", func(b):
		_sheet(b, "trunk", "mt_two")["links"].append({"a": "b_march", "b": "b_slot4", "legs": 1}))
	_expect("trunk", "R2", "two battle nodes adjacent", func(b):
		_sheet(b, "trunk", "mt_two")["links"].append({"a": "b_elite", "b": "b_slot1", "legs": 1}))
	_expect("trunk", "R3", "too few slots", func(b):
		for n in _sheet(b, "trunk", "mt_two")["nodes"]:
			if str(n["type"]) == "slot":
				n["type"] = "camp"
				n.erase("slot"))
	_expect("trunk", "R4", "elite on the only way", func(b):
		var sh := _sheet(b, "trunk", "mt_two")
		sh["links"] = (sh["links"] as Array).filter(func(l): return not ((l["a"] == "b_slot3" and l["b"] == "b_muster") or (l["a"] == "b_slot4" and l["b"] == "b_slot3") or (l["a"] == "b_slot1" and l["b"] == "b_slot3"))))
	_expect("trunk", "R5", "campaign node linked back to accumulate", func(b):
		_sheet(b, "trunk", "mt_two")["links"].append({"a": "b_slot3", "b": "b_camp", "legs": 1}))
	_expect("trunk", "R5", "muster in the campaign phase", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_muster")["phase"] = "campaign")
	_expect("trunk", "R5", "no council", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_council")["role"] = "")
	_expect("trunk", "R7", "days_max too short", func(b):
		_sheet(b, "trunk", "mt_two")["days_max"] = 2)
	_expect("trunk", "R7", "not enough stamps on the map", func(b):
		_sheet(b, "trunk", "mt_two")["stamps_need"] = 3)
	_expect("trunk", "R8", "scene without an anchor", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_fork").erase("scene"))
	_expect("trunk", "R8", "anchor type does not match the battle scale", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_boss")["type"] = "battle")
	_expect("trunk", "R8", "accumulate anchor after a campaign anchor", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_fork")["phase"] = "accumulate")
	_expect("trunk", "R9", "unreachable node", func(b):
		_sheet(b, "trunk", "mt_two")["nodes"].append({"id": "b_island", "type": "camp", "label": "x", "xy": [100, 1000]}))
	_expect("trunk", "R9", "rival walks without a link", func(b):
		_sheet(b, "trunk", "mt_two")["rivals"][0]["path"] = ["b_march", "b_boss"])
	_expect("trunk", "R10", "missing template", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_elite")["template"] = "no_such_template")
	_expect("trunk", "R10", "battle slot with no battle_pool band", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_slot1")["slot"]["level"] = 40)
	_expect("ocean", "R11", "demand that cannot be reached in time", func(b):
		for s in b["defs"]["ocean"]["scenes"]:
			if str(s["id"]) == "mo_isle":
				s["on_enter"]["demands"][0]["due_in"] = 0)
	_expect("trunk", "R12", "markers too close on screen", func(b):
		_node(_sheet(b, "trunk", "mt_two"), "b_slot3")["xy"] = [660, 160])
	_expect("conquest", "R12", "geo markers too close on screen", func(b):
		var a := _node(_sheet(b, "conquest", "mk_one"), "k_slot1")
		var bb := _node(_sheet(b, "conquest", "mk_one"), "k_slot3")
		bb["geo"] = [int(a["geo"][0]) + 1, int(a["geo"][1])])
	_expect("trunk", "trunk:mt_two: unknown view", "unknown view", func(b):
		_sheet(b, "trunk", "mt_two")["view"] = "nowhere")
	# 地图状态校验（存档用）
	var c = _mini(7)
	var m: Dictionary = (_map(c) as Dictionary).duplicate(true)
	t.ok(MapRules.valid(c.book, "trunk", m), "live map state is valid")
	var bad := m.duplicate(true)
	bad["pos"] = "nowhere"
	t.ok(not MapRules.valid(c.book, "trunk", bad), "unknown pos rejected")
	bad = m.duplicate(true)
	bad["extra"] = 1
	t.ok(not MapRules.valid(c.book, "trunk", bad), "extra key rejected")
	bad = m.duplicate(true)
	bad["slots"]["a_slot1"]["kind"] = "dragon"
	t.ok(not MapRules.valid(c.book, "trunk", bad), "unknown slot kind rejected")


# ---------------------------------------------------------------- 存档往返

func _roundtrip(c, label: String) -> void:
	var r = Campaign.new()
	r.load_book(H.MINI)
	var snap: Dictionary = JSON.parse_string(JSON.stringify(c.snapshot()))
	t.ok(bool(r.restore(snap)["ok"]), label + ": restore ok")
	t.eq(r.hash(), c.hash(), label + ": hash equal after save/load")


func _test_save_restore_each_map() -> void:
	for spec in [["trunk", 0], ["trunk", 1], ["conquest", 0], ["ocean", 0], ["ocean", 1], ["cristo", 0]]:
		var c = _mini(11, {"segment": spec[0], "stage": spec[1]})
		_roundtrip(c, "%s:%d fresh" % spec)
		H.to_day(c)
		H.take_mp(c)
		var path := H.path_to(c, str(MapRules.pick_node(c, MapRules.sheet(c), "muster")))
		if not path.is_empty() and int(MapRules.link_between(MapRules.sheet(c), str(_map(c)["pos"]), str(path[0])).get("legs", 1)) <= int(_map(c)["mp"]):
			H.send(c, "campaign.map_move", {"to": str(path[0])})
		_roundtrip(c, "%s:%d after a move" % spec)
