# 存档信封、未知命名空间、损坏与未来版本、原子替换和 ui 哈希隔离。
# 主人 G01；合同 §6.1。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_state_save")
	var c := H.ctx()
	c.state.data["future_module"] = {"_v": 3, "amount": 9223372036854775806, "literal": "__g01_int__123", "rows": [1, 2, 3]}
	var hash := c.state.hash()
	c.state.ns("ui")["guide"] = {"gd.test": {"status": "done", "shows": 3}}
	t.eq(c.state.hash(), hash, "ui outside hash")
	CardSave.set_root(t.user_dir())
	t.ok(CardSave.suspend_path().begins_with(t.user_dir()), "root isolation")
	var path := CardSave.suspend_path()
	var log := [["day.begin", {}]]
	t.ok(CardSave.write(path, c.state, {"cmd_log": log, "hint": "TEST"})["ok"], "write")
	var envelope: Dictionary = CardDB.read_json(path)
	t.eq(envelope["format"], CardSave.FORMAT, "envelope format")
	t.ok(not envelope["state"].has("cmd_log"), "log outside state")
	var read := CardSave.read(path)
	t.ok(read["ok"], "read")
	t.eq(read["state"].hash(), c.state.hash(), "hash round trip")
	t.eq(read["state"].data["future_module"], c.state.data["future_module"], "unknown namespace retained")
	t.eq(read["cmd_log"], log, "command log")
	t.eq(t.find_floats(read["state"].data), PackedStringArray(), "integer restored")
	var merged := CardCoreInstall.merge_ui({"guide": {"gd.test": {"shows": 4, "status": "shown"}}}, c.state.ns("ui"))
	t.eq(merged["guide"]["gd.test"]["status"], "done", "done wins union")
	t.eq(merged["guide"]["gd.test"]["shows"], 4, "shows max")
	envelope["v"] = 999
	H.write(path, envelope)
	t.eq(CardSave.read(path)["err"], CardIds.ERR_SAVE_NEWER, "future envelope")
	envelope["v"] = 1
	envelope["state"]["v"] = 999
	H.write(path, envelope)
	t.eq(CardSave.read(path)["err"], CardIds.ERR_SAVE_NEWER, "future state")
	H.write(path, {"format": CardSave.FORMAT, "v": 1, "state": "BROKEN"})
	t.eq(CardSave.read(path)["err"], CardIds.ERR_BAD_ARGS, "malformed state safe")
	t.ok(CardSave.write(path, c.state, {})["ok"], "atomic overwrite corrupt file")
	t.ok(not FileAccess.file_exists(path + ".tmp"), "temp removed")
	t.finish()
