# 存档、接续、重放（WORLD_MAP_DESIGN §6.7、ARCH §1.7；验收 §15.2 第 3、4、5 条）：引擎层开迷你书、每张图存档读档往返、
# 段切换写检查点（之后的命令日志从检查点算起）、分岔存档、局外记录、按命令日志（含检查点）重放哈希一致、
# 数据改过以后旧存档靠重放接续（改坏了就报 replay_failed，再从本章开头重来）、存档自相矛盾照旧拒绝、v1 存档迁移、
# 调试入口（game.new 的 segment / stage、DEHOUDANG_START）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/OCEAN/run_helpers.gd")
const G = preload("res://scripts/tests/cards/OCEAN/golden_lib.gd")
const Bridge = preload("res://scripts/cards/campaign/ocean_bridge.gd")
const RunReplay = preload("res://scripts/cards/campaign/run/run_replay.gd")
const MapRules = preload("res://scripts/cards/campaign/map/map_rules.gd")

var t: RefCounted


## 让 run_helpers 通过引擎下命令（命令进日志、自动存档），读状态还是读模型
class Driver extends RefCounted:
	var engine: CardEngine
	var state: Dictionary:
		get: return engine._ocean.model.state
	var book: Dictionary:
		get: return engine._ocean.model.book
	var definition: Dictionary:
		get: return engine._ocean.model.definition

	func _init(e: CardEngine) -> void:
		engine = e

	func model():
		return engine._ocean.model

	func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
		return engine.send(cmd, args)

	func scene() -> Dictionary:
		return model().scene()

	func chapter() -> Dictionary:
		return model().chapter()

	func available_choices() -> Array:
		return model().available_choices()

	func event_def(id: String) -> Dictionary:
		return model().event_def(id)

	func is_builtin() -> bool:
		return model().is_builtin()

	func scene_battle(id: String) -> Dictionary:
		return model().scene_battle(id)

	func roster() -> Dictionary:
		return model().roster()

	func rules() -> Dictionary:
		return model().rules()

	func _used(action: String) -> bool:
		return model()._used(action)

	func hash() -> String:
		return model().hash()


func _initialize() -> void:
	t = T.new(self, "OCEAN_run_replay")
	CardSave.set_root(t.user_dir())
	_test_builtin_verify()
	_test_checkpoints_and_branch_files()
	_test_roundtrips()
	_test_consistent_old_hash()
	_test_real_data_change()
	_test_v1_migration()
	_test_debug_entry()
	print("OCEAN run_replay assertions: %d" % t.checks)
	t.finish()


# ---------------------------------------------------------------- 工具

func _engine(dir: String, opts: Dictionary) -> CardEngine:
	var e := CardEngine.new()
	var o := {"save_dir": dir, "seed": 7}
	o.merge(opts, true)
	var r := e.new_game(o)
	t.ok(bool(r.get("ok", false)), "engine starts %s: %s" % [opts, r])
	return e


func _mini_engine(dir: String, extra: Dictionary = {}) -> CardEngine:
	var o := {"campaign": "napoleon", "book": H.MINI}
	o.merge(extra, true)
	return _engine(dir, o)


func _env(path: String) -> Dictionary:
	var env := CardSave.read(path)
	t.ok(bool(env.get("ok", false)), "envelope readable: " + path)
	return env


func _raw(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "", false, true))
	f.close()


func _verify(path: String, label: String) -> void:
	var env := _env(path)
	var v := Bridge.verify(env, path.get_base_dir())
	t.ok(bool(v["ok"]), "%s replays to the same hash: %s" % [label, v])


func _model_hash(e: CardEngine) -> String:
	return e._ocean.model.hash()


# ---------------------------------------------------------------- 单段书也能重放

func _test_builtin_verify() -> void:
	var dir: String = t.user_dir() + "/builtin"
	var e := _engine(dir, {"campaign": "ocean_pawn"})
	e.send(&"day.end", {})
	e.send(&"day.end", {})
	e.send(&"card.choose", {"uid": "story:prologue", "choice": "action:appraise:" + str(e._ocean.model.scene()["appraisals"][0]["id"])})
	var meta: Dictionary = _env(dir + "/suspend.json")["meta"]
	t.eq(str(meta["campaign"]), "ocean_pawn", "single-segment save meta unchanged")
	t.ok(not meta.has("replay_base") and not meta.has("start"), "single-segment save has no book keys")
	_verify(dir + "/suspend.json", "ocean_pawn suspend")


# ---------------------------------------------------------------- 检查点、分岔存档、局外记录

func _test_checkpoints_and_branch_files() -> void:
	var dir: String = t.user_dir() + "/cp"
	var e := _mini_engine(dir)
	var d := Driver.new(e)
	t.eq(str(e.command_log()[0][0]), "game.new", "log starts with game.new")
	var meta: Dictionary = _env(dir + "/suspend.json")["meta"]
	t.eq([str(meta["campaign"]), str(meta["book"]), str(meta["segment"]), meta["replay_base"]], ["mini", "mini", "trunk", {}], "book save meta")
	t.eq(str(meta["start"]["book"]), H.MINI, "meta.start names the book file")
	t.ok(FileAccess.file_exists(dir + "/stage_00.json"), "stage file for the first chapter")
	var view := e.view()
	t.ok(not view.is_empty(), "engine view builds for the napoleon book")
	t.ok(bool(e.query(&"campaign.map")["enabled"]), "campaign.map through the engine")
	t.ok(e.query(&"campaign.run").has("meta"), "campaign.run carries the meta record")
	H.to_day(d)
	H.send(d, "campaign.appraise", {"id": "mt_seal"})
	var plan := {"mt_arrive": "mt_take_letter", "mt_march": "mt_swear", "mt_fork": "fork_ocean"}
	var guard := 0
	while str(d.scene()["id"]) != "mt_fork" and guard < 10:
		guard += 1
		H.play_interlude(d)
		t.ok(H.play_scene(d, str(plan.get(str(d.scene()["id"]), ""))), "trunk scene through the engine: " + H.last_error)
	t.ok(FileAccess.file_exists(dir + "/stage_01.json"), "stage file for the second chapter")
	t.ok(FileAccess.file_exists(dir + "/branch.json"), "branch.json written on reaching the fork scene")
	_verify(dir + "/suspend.json", "trunk suspend (log from game.new)")
	H.walk_to(d, "b_fork")
	H.to_day(d)
	var trunk_log := e.command_log().size()
	t.ok(trunk_log > 20, "a long trunk log: %d" % trunk_log)
	t.ok(bool(H.send(d, "campaign.choose", {"choice": "fork_ocean"})["ok"]), "take the ocean branch")
	t.eq(str(d.state["segment"]), "ocean", "now in ocean")
	t.ok(FileAccess.file_exists(dir + "/checkpoint_01.json"), "checkpoint written on the segment switch")
	t.eq(e.command_log(), [], "command log restarts from the checkpoint")
	meta = _env(dir + "/suspend.json")["meta"]
	t.eq(str(meta["replay_base"]["file"]), "checkpoint_01.json", "suspend points at the checkpoint")
	t.eq(str(meta["replay_base"]["hash"]), _model_hash(e), "checkpoint hash = state right after the switch")
	t.eq(_env(dir + "/checkpoint_01.json")["cmd_log"].size(), trunk_log + 1, "checkpoint keeps the whole trunk log")
	_verify(dir + "/checkpoint_01.json", "checkpoint")
	_verify(dir + "/suspend.json", "suspend right after the switch")
	t.ok(bool(Bridge.read_meta(dir)["trunk_cleared"]) and Bridge.read_meta(dir)["branches_reached"] == ["ocean"], "meta: branch reached")
	t.ok(H.play_until(d, {}, false), "ocean branch through the engine: " + H.last_error)
	t.eq(str(d.state["ending"]), "o_mini_alliance", "ocean ending")
	_verify(dir + "/suspend.json", "suspend at the ending (checkpoint + branch log)")
	var m := Bridge.read_meta(dir)
	t.eq(m["endings"].get("ocean", []), ["o_mini_alliance"], "meta records the ending")
	t.ok("baptiste" in m["codex"]["companions_met"], "meta records met companions")
	var info := Bridge.title_info(dir)
	t.eq([str(info["suspend"]["book"]), str(info["suspend"]["segment"]), bool(info["branch"])], ["mini", "ocean", true], "title_info reads suspend meta and branch.json")
	# 卷终进 volumes
	var dir2: String = t.user_dir() + "/cp2"
	var e2 := _mini_engine(dir2, {"segment": "cristo"})
	t.ok(H.play_until(Driver.new(e2), {}, false), "cristo debug start to its volume end")
	t.eq(Bridge.read_meta(dir2)["volumes"].get("cristo", []), ["m_mini_vol_wait"], "meta records the volume ending separately")


# ---------------------------------------------------------------- 每段每张图存档读档往返

func _roundtrip(e: CardEngine, dir: String, label: String) -> void:
	var path := dir + "/rt.json"
	t.ok(bool(e.save_game(path).get("ok", false)), label + " saved")
	var e2 := CardEngine.new()
	var r := e2.load_game(path)
	t.ok(bool(r.get("ok", false)), "%s loaded: %s" % [label, r])
	if bool(r.get("ok", false)):
		t.eq(_model_hash(e2), _model_hash(e), label + ": model hash equal after load")
		t.eq(e2.state_hash(), e.state_hash(), label + ": engine state hash equal after load")
		t.eq(e2.command_log(), e.command_log(), label + ": command log restored")
		t.eq(e2._ocean.replay_base, e._ocean.replay_base, label + ": checkpoint pointer restored")


func _test_roundtrips() -> void:
	var dir: String = t.user_dir() + "/rt"
	for spec in [["trunk", 0], ["trunk", 1], ["conquest", 0], ["ocean", 0], ["ocean", 1], ["cristo", 0]]:
		var e := _mini_engine(dir, {"segment": spec[0], "stage": spec[1], "seed": 13})
		var d := Driver.new(e)
		_roundtrip(e, dir, "%s:%d start" % spec)
		H.to_day(d)
		H.take_mp(d)
		var m := str(MapRules.pick_node(d, MapRules.sheet(d), "muster"))
		H.walk_to(d, m, 2)
		_roundtrip(e, dir, "%s:%d on the map" % spec)
	# 段切换之后（带检查点）
	var e3 := _mini_engine(dir + "/sw")
	var d3 := Driver.new(e3)
	H.to_day(d3)
	H.send(d3, "campaign.appraise", {"id": "mt_seal"})
	t.ok(H.play_until(d3, {"mt_arrive": "mt_take_letter", "mt_fork": "fork_cristo"}), "trunk to cristo")
	_roundtrip(e3, dir + "/sw", "after the switch")
	H.to_day(d3)
	H.send(d3, "campaign.choose", {"choice": "mc_go"})
	_roundtrip(e3, dir + "/sw", "in cristo")


# ---------------------------------------------------------------- 数据改过：重放接续

func _test_consistent_old_hash() -> void:
	var dir: String = t.user_dir() + "/old"
	var e := _mini_engine(dir)
	var d := Driver.new(e)
	H.to_day(d)
	H.send(d, "campaign.appraise", {"id": "mt_seal"})
	H.play_scene(d, "mt_take_letter")
	H.take_mp(d)
	var want := _model_hash(e)
	var raw := _raw(dir + "/suspend.json")
	# 存档自洽，只是写于旧数据：三处哈希一起是旧的 → 按日志在新数据上重放
	raw["db_hash"] = "0ld"
	raw["state"]["db_hash"] = "0ld"
	raw["state"]["ocean"]["definition_hash"] = "0ld"
	_write(dir + "/old_data.json", raw)
	var e2 := CardEngine.new()
	var r := e2.load_game(dir + "/old_data.json")
	t.ok(bool(r.get("ok", false)), "self-consistent old save loads by replay: %s" % r)
	t.eq(str(r.get("meta", {}).get("notice", "")), Bridge.NOTICE_REPLAYED, "load says the progress was recomputed")
	t.eq(bool(r.get("meta", {}).get("db_changed", false)), true, "db_changed reported")
	if bool(r.get("ok", false)):
		t.eq(_model_hash(e2), want, "replayed state equals the live one")
	# 自相矛盾（只改了战役状态里的哈希）= 被改过，照旧拒绝
	var bad := _raw(dir + "/suspend.json")
	bad["state"]["ocean"]["definition_hash"] = "other_data"
	_write(dir + "/tampered.json", bad)
	t.eq(str(CardEngine.new().load_game(dir + "/tampered.json").get("err", "")), "save_invalid", "tampered hash still rejected (wrong_definition semantics)")
	# 单段书同样
	var bdir: String = t.user_dir() + "/old_builtin"
	var b := _engine(bdir, {"campaign": "ocean_pawn"})
	b.send(&"day.end", {})
	b.send(&"day.end", {})
	var bwant := _model_hash(b)
	var braw := _raw(bdir + "/suspend.json")
	braw["db_hash"] = "0ld"
	braw["state"]["db_hash"] = "0ld"
	braw["state"]["ocean"]["definition_hash"] = "0ld"
	_write(bdir + "/old_data.json", braw)
	var b2 := CardEngine.new()
	var br := b2.load_game(bdir + "/old_data.json")
	t.ok(bool(br.get("ok", false)), "single-segment old save replays too: %s" % br)
	if bool(br.get("ok", false)):
		t.eq(_model_hash(b2), bwant, "single-segment replay equals the live one")


## 把迷你书整本拷到 user://，书里的路径改成拷贝的路径（测试改数据用）
func _copy_book(dst: String) -> String:
	DirAccess.make_dir_recursive_absolute(dst + "/maps")
	var src := "res://data/campaigns/napoleon/fixtures"
	for rel in ["mini_trunk.json", "mini_conquest.json", "mini_ocean.json", "mini_cristo.json", "mini_events.json", "mini_ocean_events.json",
			"mini_companions.json", "maps/mini_trunk.json", "maps/mini_conquest.json", "maps/mini_ocean.json", "maps/mini_cristo.json"]:
		var f := FileAccess.open(dst + "/" + rel, FileAccess.WRITE)
		f.store_string(FileAccess.get_file_as_string(src + "/" + rel))
		f.close()
	var book := FileAccess.get_file_as_string(src + "/mini_book.json").replace(src, dst)
	var bf := FileAccess.open(dst + "/mini_book.json", FileAccess.WRITE)
	bf.store_string(book)
	bf.close()
	return dst + "/mini_book.json"


func _edit_json(path: String, fn: Callable) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	fn.call(data)
	_write(path, data)


func _test_real_data_change() -> void:
	var dir: String = t.user_dir() + "/change"
	var book := _copy_book(t.user_dir() + "/book_copy")
	var e := _mini_engine(dir, {"book": book})
	var d := Driver.new(e)
	H.to_day(d)
	H.send(d, "campaign.appraise", {"id": "mt_seal"})
	H.play_scene(d, "mt_take_letter")
	H.take_mp(d)
	var old_state: Dictionary = (d.state as Dictionary).duplicate(true)
	# 只改字：旧存档读回来按新数据重放，状态除了定义哈希一样
	_edit_json(t.user_dir() + "/book_copy/mini_trunk.json", func(data):
		data["scenes"][0]["title"] = "改过的标题")
	var e2 := CardEngine.new()
	var r := e2.load_game(dir + "/suspend.json")
	t.ok(bool(r.get("ok", false)), "text-only data change: old save continues by replay: %s" % r)
	t.eq(str(r.get("meta", {}).get("notice", "")), Bridge.NOTICE_REPLAYED, "replay notice")
	if bool(r.get("ok", false)):
		var now: Dictionary = (e2._ocean.model.state as Dictionary).duplicate(true)
		t.ok(str(now["definition_hash"]) != str(old_state["definition_hash"]), "the new data hash is adopted")
		now.erase("definition_hash")
		old_state.erase("definition_hash")
		t.eq(now, old_state, "everything else is the same state")
		t.ok(bool(e2.send(&"campaign.wait", {}).get("ok", false)), "the replayed game keeps going")
	# 改坏了：日志里用过的抉择没了 → replay_failed；再从本章开头重来（stage 文件重放）
	_edit_json(t.user_dir() + "/book_copy/mini_trunk.json", func(data):
		var choices: Array = data["scenes"][0]["choices"]
		data["scenes"][0]["choices"] = choices.filter(func(ch): return str(ch["id"]) != "mt_take_letter"))
	var e3 := CardEngine.new()
	var r3 := e3.load_game(dir + "/suspend.json")
	t.eq(str(r3.get("err", "")), "replay_failed", "replay that cannot be followed is reported")
	var r4 := e.send(&"game.retry_stage", {})
	t.ok(bool(r4.get("ok", false)), "retry the chapter from its stage file: %s" % r4)
	if bool(r4.get("ok", false)):
		t.eq([str(e._ocean.model.scene()["id"]), str(e._ocean.notice)], ["mt_arrive", Bridge.NOTICE_REPLAYED], "back at the chapter start on the new data")


# ---------------------------------------------------------------- v1 存档

func _test_v1_migration() -> void:
	var dir: String = t.user_dir() + "/v1"
	var e := _engine(dir, {"campaign": "ocean_pawn"})
	e.send(&"day.end", {})
	e.send(&"day.end", {})
	e.send(&"day.end", {})
	var live: Dictionary = (e._ocean.model.state as Dictionary).duplicate(true)
	var raw := _raw(dir + "/suspend.json")
	var ocean: Dictionary = raw["state"]["ocean"]
	for key in ["segment", "run", "map", "archive"]:
		ocean.erase(key)
	ocean["rogue"].erase("tally")
	ocean["v"] = 1
	_write(dir + "/v1.json", raw)
	var e2 := CardEngine.new()
	var r := e2.load_game(dir + "/v1.json")
	t.ok(bool(r.get("ok", false)), "v1 save loads: %s" % r)
	if bool(r.get("ok", false)):
		var st: Dictionary = e2._ocean.model.state
		t.eq([int(st["v"]), str(st["segment"]), str(st["run"]["start"]["carry"]), st["map"], st["archive"]], [2, "ocean", "migrated", {}, {}], "v1 migrated to v2")
		t.eq(st["rogue"]["tally"], {"gold": 0, "supply": 0, "medal": 0, "intel": 0}, "tally added")
		t.eq(G.hash_v1(st), G.hash_v1(live), "hash_v1 of the migrated save equals the live game")


# ---------------------------------------------------------------- 调试入口

func _test_debug_entry() -> void:
	var dir: String = t.user_dir() + "/debug"
	var e := _mini_engine(dir, {"segment": "cristo", "stage": 0})
	t.eq([str(e._ocean.model.state["segment"]), str(e._ocean.model.chapter()["id"])], ["cristo", "mc_one"], "game.new segment/stage opens there")
	OS.set_environment("DEHOUDANG_START", "ocean:1")
	var e2 := _mini_engine(dir + "/env")
	OS.unset_environment("DEHOUDANG_START")
	t.eq([str(e2._ocean.model.state["segment"]), str(e2._ocean.model.chapter()["id"])], ["ocean", "mo_two"], "DEHOUDANG_START picks segment and stage")
	var bad := CardEngine.new()
	t.eq(str(bad.new_game({"campaign": "napoleon", "book": H.MINI, "segment": "nowhere", "save_dir": dir + "/bad"}).get("err", "")), "bad_args", "unknown segment rejected")
	t.eq(str(bad.new_game({"campaign": "ocean_pawn", "book": H.MINI, "save_dir": dir + "/bad"}).get("err", "")), "bad_args", "ocean_pawn with a book path is contradictory")
	t.eq(str(bad.new_game({"campaign": "napoleon", "book": "/etc/passwd", "save_dir": dir + "/bad"}).get("err", "")), "bad_args", "book must be a res:// or user:// path")
	var nap := CardEngine.new()
	var r := nap.new_game({"campaign": "napoleon", "save_dir": dir + "/nap"})
	if FileAccess.file_exists("res://data/campaigns/napoleon/trunk.json"):
		t.ok(bool(r.get("ok", false)), "napoleon book starts once C2 wrote it")
	else:
		t.eq(str(r.get("err", "")), "definition_missing", "napoleon book reports its missing segment files until C2")
