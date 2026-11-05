# 书与段（WORLD_MAP_DESIGN §4、§6、§8.2）：条件小语言、远洋内置规则、读书与全书校验（等级规则、R6、分支登记、跨段旗标、
# 结局与卷终……）的正反例、拿破仑书骨架、调试入口直接开任意段任意章、场景 when、卷终、分岔可用性三种组合与保底、
# 段切换的携带（§4.4）与归档、大命运跳段（随驾流放）、命令旗标 / 击杀旗标 / 条件修正、名额和主角兵力按等级、tally。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/OCEAN/run_helpers.gd")
const Campaign = preload("res://scripts/cards/campaign/ocean_campaign.gd")
const RunBook = preload("res://scripts/cards/campaign/run/run_book.gd")
const RunConditions = preload("res://scripts/cards/campaign/run/run_conditions.gd")
const RunOceanRules = preload("res://scripts/cards/campaign/run/run_ocean_rules.gd")
const BattleApi = preload("res://scripts/cards/campaign/run/run_battle_api.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")
const MapQuery = preload("res://scripts/cards/campaign/map/map_query.gd")
const B2 = preload("res://scripts/cards/campaign/ocean_battle2.gd")
const RogueRules = preload("res://scripts/cards/campaign/ocean_rogue_rules.gd")

var t: RefCounted


func _initialize() -> void:
	t = T.new(self, "OCEAN_run_book")
	CardSave.set_root(t.user_dir())
	_test_conditions()
	_test_ocean_rules()
	_test_load_and_validate()
	_test_book_rejects()
	_test_skeleton_book()
	_test_debug_starts()
	_test_when_and_volume()
	_test_branch_offers()
	_test_switch_and_carry()
	_test_fate_jump()
	_test_battle_wiring()
	_test_roster_and_tally()
	print("OCEAN run_book assertions: %d" % t.checks)
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


func _bundle() -> Dictionary:
	return (RunBook.load_bundle(H.MINI)["book"] as Dictionary).duplicate(true)


## 全书校验（不走按哈希的缓存：测试里改的是同一份数据的副本）
func _errors(b: Dictionary) -> Array:
	b["hash"] = ""
	return RunBook.validate(b)["errors"]


func _expect(prefix: String, label: String, mutate: Callable) -> void:
	var b := _bundle()
	mutate.call(b)
	var errs := _errors(b)
	t.ok(errs.any(func(e): return str(e).begins_with(prefix)), "%s -> %s: %s" % [label, prefix, str(errs).left(300)])


func _scene(def: Dictionary, id: String) -> Dictionary:
	for s in def["scenes"]:
		if str(s["id"]) == id:
			return s
	return {}


## 主干一路打到分岔场景（plan 决定拿哪些旗标）
func _to_fork(seed_value: int, plan: Dictionary, appraise: bool = true) -> RefCounted:
	var c = _mini(seed_value)
	if appraise:
		H.to_day(c)
		_send(c, "campaign.appraise", {"id": "mt_seal"})
	var guard := 0
	while str(c.scene()["id"]) != "mt_fork" and guard < 10 and not H.over(c):
		guard += 1
		H.play_interlude(c)
		t.ok(H.play_scene(c, str(plan.get(str(c.scene()["id"]), ""))), "trunk scene played: " + H.last_error)
	H.play_interlude(c)
	t.eq(str(c.scene()["id"]), "mt_fork", "reached the fork")
	H.walk_to(c, "b_fork")
	H.to_day(c)
	return c


# ---------------------------------------------------------------- 条件

func _test_conditions() -> void:
	var c = _mini(7, {"stage": 1})
	var st: Dictionary = c.state
	st["flags"]["f_a"] = true
	st["flags"]["f_b"] = true
	st["inventory"].append("mini_watch")
	st["rogue"]["tally"]["medal"] = 12
	st["rogue"]["army"]["trust"]["hero|corso"] = 2
	var cases := [
		[{}, ""], [null, ""], [{"flags": ["f_a", "f_b"]}, ""], [{"flags": ["f_a", "f_c"]}, "flags:f_c"],
		[{"any_flags": ["f_c", "f_b"]}, ""], [{"any_flags": ["f_c", "f_d"]}, "any_flags"],
		[{"not_flags": ["f_c"]}, ""], [{"not_flags": ["f_a"]}, "not_flags:f_a"],
		[{"metric": {"heat": [">=", 10]}}, ""], [{"metric": {"heat": [">", 10]}}, "metric:heat"], [{"metric": {"heat": ["<=", 10]}}, ""],
		[{"metric": {"heat": ["<", 10]}}, "metric:heat"], [{"metric": {"heat": ["==", 10]}}, ""], [{"metric": {"morale": ["==", 1]}}, "metric:morale"],
		[{"stat": {"medal_earned": [">=", 10]}}, ""], [{"stat": {"medal_earned": [">=", 13]}}, "stat:medal_earned"],
		[{"stat": {"battles": ["==", 0]}}, ""], [{"coins": {"gold": [">=", 1]}}, ""], [{"coins": {"gold": [">=", 99]}}, "coins:gold"],
		[{"alive": ["baptiste"]}, ""], [{"alive": ["marie"]}, "alive:marie"], [{"items": ["mini_watch"]}, ""], [{"items": ["x"]}, "items:x"],
		[{"count_flags": {"of": ["f_a", "f_b", "f_c"], "min": 2}}, ""], [{"count_flags": {"of": ["f_a", "f_c"], "min": 2}}, "count_flags"],
		[{"scene_done": "mt_arrive"}, ""], [{"scene_done": "mt_fork"}, "scene_done"], [{"hero_ok": true}, ""], [{"hero_ok": false}, "hero_ok"],
		[{"trust": {"corso": [">=", 2]}}, ""], [{"trust": {"corso": [">=", 3]}}, "trust:corso"],
		[{"chapter": ["mt_two"]}, ""], [{"chapter": ["mt_one"]}, "chapter"], [{"segment": ["trunk"]}, ""], [{"segment": ["ocean"]}, "segment"],
		[{"volume": 1}, ""], [{"volume": 2}, "volume"], [{"mustered": false}, ""], [{"mustered": true}, "mustered"],
		[{"any": [{"flags": ["f_c"]}, {"flags": ["f_a"]}]}, ""], [{"any": [{"flags": ["f_c"]}, {"flags": ["f_d"]}]}, "any"],
		[{"not": {"flags": ["f_c"]}}, ""], [{"not": {"flags": ["f_a"]}}, "not"],
		[{"flags": ["f_a"], "metric": {"heat": [">", 50]}}, "metric:heat"], [{"bogus": 1}, "bad_cond"],
	]
	for row in cases:
		t.eq(RunConditions.reason(c, row[0]), row[1], "reason " + JSON.stringify(row[0]))
		t.eq(RunConditions.eval(c, row[0]), row[1] == "", "eval " + JSON.stringify(row[0]))
	t.eq(RunConditions.root("stat:medal_earned"), "stat", "root of a reason key")
	# scene_done：本段排在当前场之前，或者在已归档的段里
	var d = _mini(7)
	H.to_day(d)
	_send(d, "campaign.choose", {"choice": "mt_plain"})
	t.ok(RunConditions.eval(d, {"scene_done": "mt_arrive"}), "scene_done after advancing")
	t.ok(not RunConditions.eval(d, {"scene_done": "mt_battle1"}), "current scene is not done")
	# 形状检查
	for bad in [[{"metric": {"heat": ["=>", 1]}}, "metric:heat"], [{"metric": {"gold": [">=", 1]}}, "metric:gold"], [{"stat": {"luck": [">=", 1]}}, "stat:luck"],
			[{"flags": "f_a"}, "flags"], [{"any": []}, "any"], [{"not": {"zz": 1}}, "not/unknown:zz"], [{"volume": 0}, "volume"],
			[{"count_flags": {"of": ["a"]}}, "count_flags"], [{"hero_ok": 1}, "hero_ok"], [{"x": 1}, "unknown:x"], [[1], "not_object"]]:
		t.eq(RunConditions.check(bad[0]), bad[1], "check rejects " + JSON.stringify(bad[0]))
	t.eq(RunConditions.check({"any": [{"flags": ["a"]}, {"stat": {"medal_earned": [">=", 10]}}], "hero_ok": true}), "", "check accepts a branch condition")
	t.eq(RunConditions.flags_read({"flags": ["a"], "any": [{"not_flags": ["b"]}, {"count_flags": {"of": ["c"], "min": 1}}], "not": {"any_flags": ["d"]}}),
		["a", "b", "c", "d"], "flags read by a condition")


# ---------------------------------------------------------------- 远洋内置规则

func _test_ocean_rules() -> void:
	var c := Campaign.new()
	t.ok(bool(c.load_definition()["ok"]), "ocean_pawn loads")
	var r := RunOceanRules.rules(c.definition)
	t.eq(r["failures"], RunOceanRules.FAILURES, "ocean failures fall back to the built-in table")
	t.eq(str(r["default_ending"]), "bittersweet", "ocean default ending")
	t.eq(r["exclusive_flags"], [["revolution_funded", "refused_funding"]], "ocean exclusive flags")
	t.eq(r["signs"]["red"]["daily"], {"heat": 15}, "ocean red flag keeps the old +15")
	t.eq(r["actions"]["visit_town"]["cost"], 100, "ocean town visit costs 100")
	var ids: Array = []
	for e in r["endings"]:
		ids.append(str(e["id"]))
	t.eq(ids, ["tragedy", "dark", "ghost", "alliance"], "ocean ending priority")
	var specs := RunOceanRules.demand_specs(c.definition)
	t.eq([specs.keys(), str(specs["medicine"]["chapter"]), int(specs["bond"]["cost"])], [["medicine", "bond"], "st_helena", 1000], "ocean scene01 demands")
	var b := _bundle()
	t.eq(RunOceanRules.demand_specs(b["defs"]["trunk"]), {}, "a new segment gets no ocean demands")
	t.eq(RunOceanRules.demand_specs(b["defs"]["ocean"]).keys(), ["o_mini_medicine"], "on_enter demands replace the built-in ones")
	var mixed := RunOceanRules.rules(b["defs"]["ocean"])
	t.eq(mixed["actions"]["visit_town"]["items_by_chapter"], {"mo_two": ["o_mini_herbs"]}, "segment actions override per key")
	t.eq(mixed["actions"]["trade_fair"], RunOceanRules.ACTIONS["trade_fair"], "unwritten actions keep the ocean numbers")
	var builtin := RunBook.builtin(c.definition, "h")
	t.eq([str(builtin["id"]), bool(builtin["builtin"]), str(builtin["start"]), builtin["defs"].keys()], ["ocean_pawn", true, "ocean", ["ocean"]], "built-in single-segment book")


# ---------------------------------------------------------------- 读书、校验

func _test_load_and_validate() -> void:
	var loaded := RunBook.load_bundle(H.MINI)
	t.ok(bool(loaded["ok"]), "mini book bundle loads")
	var b: Dictionary = loaded["book"]
	t.eq(b["defs"].keys(), ["trunk", "conquest", "ocean", "cristo"], "four segments")
	t.eq((b["events"]["ocean"] as Array).size(), 5, "segment events file loaded (book.segments.ocean.events)")
	t.eq((b["events_common"] as Array).size(), 3, "common event pool")
	t.eq(b["companions"].size(), 6, "companion table")
	var v := RunBook.validate(b)
	t.eq(v["errors"], [], "mini book validates")
	var b2 := b.duplicate(true)
	b2["defs"]["trunk"]["scenes"][0]["title"] = "改过的标题"
	t.ok(RunBook.book_hash(b2) != str(b["hash"]), "any text change changes the book hash")
	var c := Campaign.new()
	t.ok(bool(c.load_book(H.MINI)["ok"]), "campaign loads the mini book")
	t.eq([c.is_builtin(), str(c.definition["id"])], [false, "mini_trunk"], "definition is the start segment")
	t.eq(str(c.load_book("res://nope.json")["err"]), "definition_missing", "missing book")
	var chains := RunBook.chains(b)
	t.eq(chains.size(), 3, "three play chains (one per branch)")
	t.eq(chains[0], [["trunk", "mt_one"], ["trunk", "mt_two"], ["conquest", "mk_one"]], "volume-2 chapters are not on the chain")


func _test_book_rejects() -> void:
	_expect("8.2 rule 1", "branch boss not above the trunk boss", func(b):
		b["raw"]["segments"]["conquest"]["scene_battles"]["mk_boss"]["level"] = 3)
	_expect("8.2 rule 2", "elite too close to the boss", func(b):
		MapRules.node_of(MapRules.sheet_of(b, "trunk", "mt_two"), "b_elite")["level"] = 3)
	_expect("8.2 rule 2", "random battle too close to the boss", func(b):
		MapRules.node_of(MapRules.sheet_of(b, "trunk", "mt_two"), "b_slot1")["slot"]["level"] = 2)
	_expect("8.2 rule 2", "rival battle too close to the boss", func(b):
		MapRules.sheet_of(b, "trunk", "mt_two")["rivals"][0]["meet"]["battle"]["level"] = 2)
	_expect("8.2 rule 3", "branch battle below the trunk's final boss", func(b):
		MapRules.node_of(MapRules.sheet_of(b, "conquest", "mk_one"), "k_outpost")["level"] = 2)
	_expect("8.2 rule 4", "next boss not 12% stronger", func(b):
		b["raw"]["segments"]["ocean"]["scene_battles"]["mo_boss2"] = {"template": "elite_a", "level": 6})
	BattleApi.lib()["templates"]["arcole"]["level"] = 6
	_expect("8.2 rule 5", "fixed-level template used away from its level", func(_b): pass)
	BattleApi.lib()["templates"]["arcole"].erase("level")
	BattleApi.lib()["templates"]["major_a"]["base_level"] = 10
	_expect("8.2 rule 5", "padded template used below its base level", func(_b): pass)
	BattleApi.lib()["templates"]["major_a"].erase("base_level")
	t.eq(_errors(_bundle()), [], "template cache restored")
	_expect("R6", "two adjacent chapters with the same interlude", func(b):
		MapRules.sheet_of(b, "conquest", "mk_one")["interlude"] = "audience")
	_expect("R6", "interlude with no event in the pools", func(b):
		MapRules.sheet_of(b, "cristo", "mc_one")["interlude"] = "minigame:ring")
	_expect("branch point trunk:mt_fork", "two unconditional branches", func(b):
		b["raw"]["branches"]["cristo"]["requires"] = {})
	_expect("choice mt_march.sneak", "branch choice not registered", func(b):
		_scene(b["defs"]["trunk"], "mt_march")["choices"].append({"id": "sneak", "label": "x", "branch": "ocean"}))
	_expect("branch cristo: no choice", "registered branch without a choice", func(b):
		var fork := _scene(b["defs"]["trunk"], "mt_fork")
		fork["choices"] = (fork["choices"] as Array).filter(func(ch): return str(ch["id"]) != "fork_cristo"))
	_expect("branch ocean: entry", "branch entry scene missing", func(b):
		b["raw"]["branches"]["ocean"]["entry"] = "no_scene")
	_expect("segment cristo reads flag t_mini_oath", "cross-segment flag not in shared_flags", func(b):
		b["raw"]["shared_flags"] = ["t_mini_letter"])
	_expect("event ev_common_rumor: forbidden key branch", "event with a branch", func(b):
		b["events_common"][0]["branch"] = "ocean")
	_expect("event ev_mk_pool choice listen: forbidden key advance", "event choice with advance", func(b):
		for ev in b["events"]["conquest"]:
			if str(ev["id"]) == "ev_mk_pool":
				ev["choices"][0]["advance"] = false)
	_expect("duplicate scene:mt_arrive", "scene id used twice in the book", func(b):
		b["defs"]["ocean"]["scenes"][0]["id"] = "mt_arrive")
	_expect("duplicate event:ev_mt_pool", "event id used twice", func(b):
		b["events_common"].append({"id": "ev_mt_pool", "choices": [{"id": "x", "label": "x"}]}))
	_expect("segment conquest: volume ending k_mini_vol_win", "volume ending without kind volume", func(b):
		for e in b["defs"]["conquest"]["endings"]:
			if str(e["id"]) == "k_mini_vol_win":
				e.erase("kind"))
	_expect("ending o_mini_plain in", "fixed ending id reused across segments", func(b):
		b["defs"]["cristo"]["endings"].append({"id": "o_mini_plain", "title": "x", "body": []}))
	_expect("scene mc_letter: when", "malformed condition", func(b):
		_scene(b["defs"]["cristo"], "mc_letter")["when"] = {"flags": "t_mini_oath"})
	_expect("big_fate_extra fate_mini_exile: jump", "jump to an unknown segment", func(b):
		b["defs"]["conquest"]["big_fate_extra"][0]["jump"] = "atlantis")
	_expect("event ev_mc_weigh: minigame weigh", "minigame interlude without its appraisal kind", func(b):
		for ev in b["events"]["cristo"]:
			if str(ev["id"]) == "ev_mc_weigh":
				ev["appraisals"][0]["kind"] = "spot")
	_expect("R2", "map errors are part of the book check", func(b):
		MapRules.sheet_of(b, "trunk", "mt_two")["links"].append({"a": "b_elite", "b": "b_slot1", "legs": 1}))
	# load_book 整本拒绝
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(H.MINI))
	raw["branches"]["cristo"]["requires"] = {}
	var path: String = t.user_dir() + "/bad_book.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	var c := Campaign.new()
	var r: Dictionary = c.load_book(path)
	t.eq(str(r["err"]), "book_invalid", "load_book rejects an invalid book")
	t.ok((r.get("errors", []) as Array).size() >= 1, "and says why")


# ---------------------------------------------------------------- 拿破仑书骨架

func _test_skeleton_book() -> void:
	var read := RunBook.read_json(RunBook.NAPOLEON)
	t.ok(bool(read["ok"]), "napoleon book.json parses as an integer tree")
	var raw: Dictionary = read.get("data", {})
	t.eq([str(raw.get("id", "")), str(raw.get("start", "")), int(raw.get("volume", 0))], ["napoleon", "trunk", 2], "default book identity")
	var first := RunBook.read_json(RunBook.VOLUME1)
	t.ok(bool(first["ok"]), "first-volume book remains available")
	t.eq(int(first.get("data", {}).get("volume", 0)), 1, "first-volume path keeps its original identity")
	t.eq((raw.get("segments", {}) as Dictionary).keys(), ["trunk", "conquest", "ocean", "cristo"], "four segments")
	t.eq(str(raw["segments"]["ocean"]["file"]), "res://data/campaigns/ocean_pawn.json", "the ocean branch is the ocean_pawn definition")
	var open := 0
	for seg in raw["branches"]:
		var b: Dictionary = raw["branches"][seg]
		t.eq([str(b["from"]), str(b["scene"]), int(b["level_offset"])], ["trunk", "elba_1815", 12], "branch %s hangs on elba_1815" % seg)
		t.eq(RunConditions.check(b.get("requires", {})), "", "branch %s condition shape" % seg)
		if (b.get("requires", {}) as Dictionary).is_empty():
			open += 1
	t.eq(open, 1, "exactly one fallback branch")
	for card in raw["march_deck"]:
		t.ok(raw["march_cards"].has(card), "deck card %s defined" % card)
	t.ok(raw["debug_carry"].has("branch_point"), "debug carry has the branch point")
	t.eq(raw["carry"]["items"], ["elba_watch", "faria_half", "emperor_letter", "guard_eagle_ribbon"], "carried items (§4.4)")
	var missing: Array = []
	for seg in raw["segments"]:
		for key in ["file", "map"]:
			var p := str(raw["segments"][seg].get(key, ""))
			if p != "" and not FileAccess.file_exists(p):
				missing.append(p)
	if missing.is_empty():
		var c := Campaign.new()
		var r: Dictionary = c.load_book(RunBook.NAPOLEON)
		t.ok(bool(r["ok"]), "napoleon book loads and validates: " + str(r).left(400))
	else:
		print("napoleon book: segment files not written yet (C2): ", missing.size())


# ---------------------------------------------------------------- 调试入口

func _test_debug_starts() -> void:
	var c := Campaign.new()
	c.load_book(H.MINI)
	t.eq(str(c.new_game({"segment": "atlantis"})["err"]), "bad_args", "unknown segment")
	t.eq(str(c.new_game({"segment": "ocean", "stage": 2})["err"]), "bad_args", "stage out of range")
	t.eq(str(c.new_game({"segment": 3})["err"]), "bad_args", "segment must be a string")
	for spec in [["trunk", 0, "mt_one", ""], ["trunk", 1, "mt_two", "debug"], ["conquest", 0, "mk_one", "debug"], ["conquest", 1, "mk_two", "debug"],
			["ocean", 0, "mo_one", "debug"], ["ocean", 1, "mo_two", "debug"], ["cristo", 0, "mc_one", "debug"]]:
		var d = _mini(5, {"segment": spec[0], "stage": spec[1]})
		var label := "%s:%d" % [spec[0], spec[1]]
		t.eq([str(d.state["segment"]), str(d.chapter()["id"]), str(d.state["run"]["start"]["carry"])], [spec[0], spec[2], spec[3]], label + " opens there")
		t.eq([int(d.state["run"]["chapter_ord"]), d.state["run"]["path"]], [spec[1], [spec[0]]], label + " run bookkeeping")
		t.eq(int(d.state["run"]["level_offset"]), 0 if spec[0] == "trunk" else 12, label + " level offset")
		t.eq(MapRules.enabled(d), spec[2] != "mk_two", label + " map open (volume-2 chapter has no sheet)")
	var o = _mini(5, {"segment": "ocean", "stage": 1})
	t.eq(o.state["rogue"]["coins"], {"gold": 5, "supply": 9, "medal": 11, "intel": 4}, "stage carry replaces the coins (absolute values)")
	t.ok(bool(o.state["rogue"]["companions"]["dantes"]["recruited"]) and int(o.state["rogue"]["companions"]["baptiste"]["level"]) == 2, "stage carry companions")
	t.ok(bool(o.state["flags"].get("t_mini_letter", false)) and "mini_watch" in o.state["inventory"], "branch_point flags and items")
	t.eq((o.state["rogue"]["army"]["troops"] as Array).size(), 6, "branch_point troops")
	var k = _mini(5, {"segment": "conquest"})
	t.ok(bool(k.state["flags"].get("t_mini_oath", false)), "segment carry adds its own flags")
	var fresh = _mini(5)
	t.eq([bool(fresh.state["rogue"]["companions"]["baptiste"]["recruited"]), fresh.state["rogue"]["coins"]], [true, {"gold": 4, "supply": 6, "medal": 2, "intel": 2}], "book start_rogue")
	t.eq(fresh.state["rogue"]["tally"], {"gold": 0, "supply": 0, "medal": 0, "intel": 0}, "tally starts at zero")


# ---------------------------------------------------------------- when 与卷终

func _test_when_and_volume() -> void:
	var c = _mini(5, {"segment": "cristo"})
	H.to_day(c)
	var day := int(c.state["day"])
	_send(c, "campaign.choose", {"choice": "mc_go"})
	t.eq(str(c.scene()["id"]), "mc_boss", "scene whose when is false is skipped")
	t.eq(int(c.state["day"]), day + 1, "skipping costs no extra day")
	var d = _mini(5, {"segment": "cristo"})
	d.state["flags"]["t_mini_oath"] = true
	H.to_day(d)
	_send(d, "campaign.choose", {"choice": "mc_go"})
	t.eq(str(d.scene()["id"]), "mc_letter", "scene whose when holds is played")
	# 卷终：本卷最后一场作出推进决定 → volume_endings 第一个成立的，否则 default
	var k = _mini(5, {"segment": "conquest"})
	t.ok(H.play_until(k, {}, false), "conquest mini plays to the end: " + H.last_error)
	t.eq([str(k.state["ending"]), str(k.state["end_reason"])], ["k_mini_vol_dusk", "volume"], "volume-2 chapter ends the run with the default volume ending")
	var w = _mini(5, {"segment": "conquest"})
	w.state["flags"]["k_mini_scout"] = true
	t.ok(H.play_until(w, {}, false), "conquest with scouting: " + H.last_error)
	t.eq(str(w.state["ending"]), "k_mini_vol_win", "volume ending picked by its condition")
	# 固定结局（远洋：rules.endings，否则 default_ending）
	var o = _mini(5, {"segment": "ocean", "stage": 1})
	t.ok(H.play_until(o, {"mo_end": "mo_ally"}, false), "ocean chapter 2 to the finale: " + H.last_error)
	t.eq([str(o.state["ending"]), str(o.state["end_reason"])], ["o_mini_alliance", "finale"], "fixed ending by rules.endings")
	var p = _mini(5, {"segment": "ocean", "stage": 1})
	t.ok(H.play_until(p, {"mo_end": "mo_alone"}, false), "ocean alone: " + H.last_error)
	t.eq(str(p.state["ending"]), "o_mini_plain", "default ending")
	# 互斥旗标、失败收场
	var x = _mini(5, {"segment": "ocean", "stage": 1})
	x.state["flags"]["o_mini_ally"] = true
	x.state["scene_index"] = 5
	x.state["map"]["pos"] = "p_end"
	H.to_day(x)
	var rows: Array = x.available_choices()
	t.eq(str(rows[1]["reason"]), "already_used", "exclusive flags block the other choice")
	var f = _mini(5, {"segment": "ocean"})
	H.to_day(f)
	f.state["metrics"]["treasury"] = 0
	H.send(f, "campaign.wait")
	t.eq([str(f.state["ending"]), str(f.state["end_reason"])], ["bankruptcy", "treasury"], "rules.failures end the run")


# ---------------------------------------------------------------- 分岔

func _offers(c) -> Dictionary:
	var out := {}
	for row in MapQuery.run(c)["branch_offers"]:
		out[str(row["segment"])] = [bool(row["ok"]), str(row["reason_root"])]
	return out


func _test_branch_offers() -> void:
	var only_ocean = _to_fork(21, {"mt_arrive": "mt_plain", "mt_march": "mt_march_on"}, false)
	t.eq(_offers(only_ocean), {"conquest": [false, "any"], "ocean": [true, ""], "cristo": [false, "any"]}, "nothing earned: only the ocean fallback")
	var r: Dictionary = only_ocean.send(&"campaign.choose", {"choice": "fork_cristo"})
	t.eq(str(r["err"]), "branch_locked", "a locked branch cannot be taken")
	var two = _to_fork(22, {"mt_arrive": "mt_take_letter", "mt_march": "mt_march_on"})
	t.eq(_offers(two), {"conquest": [false, "any"], "ocean": [true, ""], "cristo": [true, ""]}, "the letter opens the cristo branch")
	var all = _to_fork(23, {"mt_arrive": "mt_take_letter", "mt_march": "mt_swear"})
	t.eq(_offers(all), {"conquest": [true, ""], "ocean": [true, ""], "cristo": [true, ""]}, "letter and oath open every branch")
	all.state["rogue"]["army"]["hero_wounded"] = true
	t.eq(_offers(all)["conquest"], [false, "hero_ok"], "a wounded hero cannot march")
	all.state["rogue"]["army"]["hero_wounded"] = false
	var q := MapQuery.run(all)
	t.eq([str(q["book"]), str(q["segment"]), q["path"], int(q["volume"])], ["mini", "trunk", ["trunk"], 1], "campaign.run basics")
	# 三条分支各自打到收场
	for target in ["conquest", "ocean", "cristo"]:
		var c = _to_fork(30, {"mt_arrive": "mt_take_letter", "mt_march": "mt_swear"})
		_send(c, "campaign.choose", {"choice": "fork_" + target})
		t.eq(str(c.state["segment"]), target, "switched to " + target)
		t.ok(H.play_until(c, {}, false), target + " plays to its end: " + H.last_error)
		var want := {"conquest": ["k_mini_vol_dusk", "volume"], "ocean": ["o_mini_alliance", "finale"], "cristo": ["m_mini_vol_wait", "volume"]}
		if target == "ocean":
			want["ocean"] = ["o_mini_alliance", "finale"]
		t.eq([str(c.state["ending"]), str(c.state["end_reason"])], want[target], target + " reaches a fixed ending or a volume ending")
		t.eq(c.state["run"]["path"], ["trunk", target], target + " path")


# ---------------------------------------------------------------- 段切换与携带

func _test_switch_and_carry() -> void:
	var c = _to_fork(40, {"mt_arrive": "mt_take_letter", "mt_march": "mt_swear"})
	c.state["metrics"]["treasury"] = 1000
	c.state["metrics"]["morale"] = 77
	c.state["metrics"]["vitality"] = 30
	c.state["metrics"]["heat"] = 55
	c.state["rogue"]["coins"]["supply"] = 45
	c.state["inventory"].append("stray_item")
	c.state["rogue"]["companions"]["corso"]["alive"] = false
	var day := int(c.state["day"])
	var ledger_rows: int = (c.state["ledger"] as Array).size()
	var ord := int(c.state["run"]["chapter_ord"])
	_send(c, "campaign.choose", {"choice": "fork_ocean"})
	var st: Dictionary = c.state
	t.eq([str(st["segment"]), str(st["campaign"]), str(c.scene()["id"]), str(st["phase"])], ["ocean", "mini_ocean", "mo_dock", "year_jump"], "now in the ocean branch")
	t.eq(int(st["metrics"]["treasury"]), 2000 + 1000 / 4, "treasury = chapter start + old balance / 4")
	t.eq([int(st["metrics"]["morale"]), int(st["metrics"]["vitality"]), int(st["metrics"]["heat"])], [77, 40, 10], "morale kept, vitality at least 40, heat reset")
	t.ok(bool(st["flags"].get("t_mini_letter", false)) and bool(st["flags"].get("o_mini_followed", false)), "flags kept, branch flag written")
	t.eq(st["inventory"], ["mini_watch"], "only the carried items come along")
	t.eq(int(st["rogue"]["coins"]["supply"]), 20 + 2, "coins capped at 20 when leaving, then the new scene's usual +2 supply")
	t.ok(not bool(st["rogue"]["companions"]["corso"]["alive"]), "the dead stay dead")
	t.eq([str(st["rogue"]["battle2"]["phase"]), str(st["rogue"]["army"]["chapter"])], ["none", "mo_one"], "battle reset, army on the new chapter")
	t.ok(int(st["day"]) > day, "day keeps counting across segments")
	t.eq([st["run"]["path"], int(st["run"]["level_offset"]), int(st["run"]["chapter_ord"])], [["trunk", "ocean"], 12, ord + 1], "run bookkeeping")
	var arch: Dictionary = st["archive"]["trunk"]
	t.eq(str(_scene(c.book["defs"]["trunk"], "mt_fork")["id"]), "mt_fork", "fork scene")
	t.eq(int(arch["scene_index"]), 4, "archive keeps the trunk scene index")
	t.ok((arch["ledger"] as Array).size() <= Campaign.ARCHIVE_LEDGER + 1 and str(arch["ledger"][-1]["type"]) == "summary", "archived ledger trimmed with a summary")
	t.ok(int(arch["ledger"][-1]["rows"]) > ledger_rows, "summary counts every trunk row")
	t.eq([str(st["ledger"][0]["type"]), str(st["ledger"][0]["from"]), str(st["ledger"][0]["to"])], ["segment_open", "trunk", "ocean"], "new segment ledger starts with segment_open")
	t.eq(str(st["map"]["sheet"]), "mo_one", "the branch's first sheet is open")
	t.ok(RunConditions.eval(c, {"scene_done": "mt_march"}), "archived scenes count as done")
	# 往返
	var r := Campaign.new()
	r.load_book(H.MINI)
	t.ok(bool(r.restore(JSON.parse_string(JSON.stringify(c.snapshot())))["ok"]), "restore after a segment switch")
	t.eq(r.hash(), c.hash(), "hash equal after the switch round trip")


# ---------------------------------------------------------------- 大命运跳段

func _test_fate_jump() -> void:
	var c = _mini(5, {"segment": "conquest"})
	H.play_scene(c, "")
	t.eq(str(c.scene()["id"]), "mk_boss", "at the conquest boss scene")
	H.to_day(c)
	H.muster(c)
	H.walk_to(c, "k_boss")
	H.to_day(c)
	_send(c, "campaign.map_enter")
	_send(c, "campaign.battle_prepare")
	_send(c, "campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false})
	for _i in range(40):
		if str(c.state["rogue"]["battle2"]["state"].get("phase", "")) != "command":
			break
		H.send(c, "campaign.battle_cmd", {"cmd": "fight", "args": {}})
	_send(c, "campaign.battle_finish")
	t.ok(bool(c.state["rogue"]["big_fate"]["pending"]), "lost the boss: big fate pending")
	var opts := RogueRules.big_fate_options(c)
	t.ok("fate_mini_exile" in opts and opts.size() == 4, "segment fate option offered on its scene: " + str(opts))
	_send(c, "campaign.big_fate", {"choice": "fate_mini_exile"})
	t.eq([str(c.state["segment"]), c.state["run"]["path"]], ["ocean", ["conquest", "ocean"]], "exile jumps to the ocean branch")
	t.ok("fate_mini_exile" in c.state["run"]["fate_once"], "once-per-run fate recorded")
	t.eq(str(c.state["ledger"][0].get("via", "")), "fate:fate_mini_exile", "segment_open says it came from the fate")
	t.ok(c.state["archive"].has("conquest"), "conquest archived")


# ---------------------------------------------------------------- 战斗接线

func _test_battle_wiring() -> void:
	var c = _mini(5, {"segment": "conquest"})
	c.state["flags"]["k_mini_scout"] = true
	H.play_scene(c, "")
	H.to_day(c)
	H.muster(c, "cp")
	H.walk_to(c, "k_boss")
	H.to_day(c)
	_send(c, "campaign.map_enter")
	_send(c, "campaign.battle_prepare")
	var b2: Dictionary = c.state["rogue"]["battle2"]
	t.eq([str(b2["template"]), int(b2["level"]), int(b2["act"])], ["rivoli", 7, 4], "boss template and absolute level from the book")
	t.eq(int(b2["mods"].get("prep_turn", 0)), 1, "mods_when: scouting gives a prep turn")
	t.ok(int(b2["mods"].get("cp_bonus", 0)) >= 2, "council cp bonus")
	var lu: Dictionary = B2.lineup(c)
	t.eq(lu["caps"], BattleApi.caps("major", 7), "caps by scale and level")
	t.eq(int(lu["protagonist"]["hp"]), mini(24, 12 + 6), "hero hp = min(hero_hp_max, 12 + L - 1)")
	t.eq(str(lu["weather"]) in ["clear", "rain", "mud", "snow", "fog", "night", "desert", "storm"], true, "weather chosen")
	var high = _mini(5, {"segment": "ocean", "stage": 1})
	t.eq(B2.hero_hp_level(high, 20), 24, "hero hp capped by the book (24)")
	var single := Campaign.new()
	single.load_definition()
	single.new_game({"seed": 1})
	t.eq(B2.hero_hp_level(single, 20), 20, "single-segment book keeps the old cap (20)")
	# 命令旗标、击杀旗标
	B2._battle_flags(c, {"order_flag": "m_test_order", "template": "rivoli"}, {"order_done": true})
	t.ok(bool(c.state["flags"].get("m_test_order", false)), "order_flag set when the order is done")
	B2.lib()["templates"]["rivoli"]["kill_flags"] = {"elite": "k_test_kill"}
	B2._battle_flags(c, {"order_flag": "", "template": "rivoli"}, {"killed_kinds": {"elite": 1}})
	B2.lib()["templates"]["rivoli"].erase("kill_flags")
	t.ok(bool(c.state["flags"].get("k_test_kill", false)), "kill_flags set from result.killed_kinds")
	# 空模板：这一场没有仗（C24）
	var o = _mini(5, {"segment": "ocean"})
	o.state["scene_index"] = 1
	t.eq(str(o.scene()["id"]), "scene07", "ocean scene07")
	t.ok(not B2.has_battle(o) and B2.resolved(o), "empty template: no battle in this book")
	var single_sb: Dictionary = B2.lib()["scene_map"]["scene07"]
	t.eq(str(single_sb["template"]), "elite_a", "the single-segment book still has its scene07 battle")
	# 伙伴的 available_from（C28）
	var prof: Dictionary = o.roster()["profiles"]["faria"]
	t.eq(B2.available_from(o, prof, {"template": "major_a"}), 0, "available_from is per segment")
	o.state["segment"] = "cristo"
	t.eq(B2.available_from(o, prof, {"template": "major_a"}), 3, "available_from on the listed template")
	o.state["segment"] = "ocean"


# ---------------------------------------------------------------- 名册与 tally

func _test_roster_and_tally() -> void:
	var c = _mini(5)
	var roster: Dictionary = c.roster()
	t.eq(roster["ids"], ["baptiste", "corso", "marie", "ney", "dantes", "faria"], "book roster from companions.json")
	t.eq(int(roster["profiles"]["ney"]["hp"]), 13, "battle profile from the table")
	t.eq((c.state["rogue"]["companions"] as Dictionary).size(), 6, "rogue has every roster row")
	t.ok(RogueRules.valid_rogue(c.state["rogue"], roster["ids"]), "rogue valid against the book roster")
	t.ok(not RogueRules.valid_rogue(c.state["rogue"]), "and not against the single-segment roster")
	var medal := int(c.state["rogue"]["coins"]["medal"])
	RogueRules._add_coin(c.state["rogue"], "medal", 3)
	RogueRules._add_coin(c.state["rogue"], "medal", -2)
	t.eq([int(c.state["rogue"]["coins"]["medal"]), int(c.state["rogue"]["tally"]["medal"])], [medal + 1, 3], "tally counts only what was earned")
	t.eq(RunConditions.stat(c, "medal_earned"), 3, "stat medal_earned reads the tally")
	H.to_day(c)
	_send(c, "campaign.appraise", {"id": "mt_seal"})
	_send(c, "campaign.choose", {"choice": "mt_take_letter"})
	t.eq(int(c.state["rogue"]["tally"]["medal"]), 4, "story rogue coins go through the tally")
