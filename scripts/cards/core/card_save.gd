# 存档：信封 {format, v, db_hash, saved_at_phase, meta, state, cmd_log}，全精度 JSON；指令日志在信封里不在状态里。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §6.1、§7.9（G01 core）。
# 测试一律用 user://test/<清单名>/（card_t.user_dir()），不碰 user://cards/。
class_name CardSave
extends RefCounted

const LEGACY_ROOT := "user://cards"
## The unchanged title screen also uses this property when discovering Continue.
static var DEFAULT_ROOT: String = LEGACY_ROOT if OS.get_environment("DEHOUDANG_CAMPAIGN") == "legacy" else (
	"user://cards/ocean_pawn" if OS.get_environment("DEHOUDANG_CAMPAIGN") == "ocean_pawn" else "user://cards/napoleon-demo")
const FORMAT := "dehoudang-cards-save"

static var _root: String = DEFAULT_ROOT   # 配置（不是游戏状态）


## 测试用 user://test/<清单名>/；new_game 的 save_dir 也走它
static func set_root(dir: String) -> void:
	_root = dir.trim_suffix("/") if dir != "" else DEFAULT_ROOT


static func root() -> String:
	return _root


static func suspend_path() -> String:
	return _root + "/suspend.json"


static func stage_path(stage: int) -> String:
	return _root + "/stage_%02d.json" % stage


static var _known_dirs: Dictionary = {}


## meta 里可以带 cmd_log（[[cmd, args], …]），写进信封顶层；meta.saved_at_phase 不给就取 state.loop.phase
static func write(path: String, state: CardState, meta: Dictionary) -> Dictionary:
	var m := meta.duplicate(false)
	var cmd_log: Array = m.get("cmd_log", [])
	m.erase("cmd_log")
	var env := {"format": FORMAT, "v": CardState.VERSION, "db_hash": str(state.data.get("db_hash", "")),
		"saved_at_phase": str(m.get("saved_at_phase", state.ns("loop").get("phase", ""))), "meta": m,
		"state": state.data, "cmd_log": cmd_log}
	var base_dir := path.get_base_dir()
	if not _known_dirs.has(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
		_known_dirs[base_dir] = true
	var encoded := JSON.stringify(env, "", false, true)
	if encoded.length() > 128 * 1024 and encoded.to_utf8_buffer().size() > 512 * 1024:
		return {"ok": false, "err": "save_too_large"}
	var temp := path + ".tmp"
	var f := FileAccess.open(temp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	f.store_string(encoded)
	var write_err := f.get_error()
	f.close()
	if write_err != OK or DirAccess.rename_absolute(temp, path) != OK:
		DirAccess.remove_absolute(temp)
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	return {"ok": true, "err": ""}


## {ok, err, state: CardState, meta, cmd_log}
static func read(path: String) -> Dictionary:
	var d = CardDB.read_json(path)
	if typeof(d) != TYPE_DICTIONARY or str(d.get("format", "")) != FORMAT:
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var env: Dictionary = d
	if int(env.get("v", 0)) > CardState.VERSION:
		return {"ok": false, "err": CardIds.ERR_SAVE_NEWER}
	if typeof(env.get("state")) != TYPE_DICTIONARY or typeof(env.get("meta", {})) != TYPE_DICTIONARY or typeof(env.get("cmd_log", [])) != TYPE_ARRAY:
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var data: Dictionary = env["state"]
	if not data.has("seed") or not data.has("core") or not data.has("loop"):
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var st := CardState.from_dict(data, false)
	if st == null:
		return {"ok": false, "err": CardIds.ERR_SAVE_NEWER}
	return {"ok": true, "err": "", "state": st, "meta": env.get("meta", {}), "cmd_log": env.get("cmd_log", []),
		"db_hash": str(env.get("db_hash", ""))}


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path)
