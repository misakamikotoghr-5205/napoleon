# 游戏状态（CardGameState）：只含 int / String / bool / Array / Dictionary，不许有浮点；按模块分命名空间，
# 每个命名空间只有它的主人写。主人 G01；W0 写了能用的最小版。合同：docs/cards/CARDS_INTERFACES.md §6.1。
class_name CardState
extends RefCounted

const VERSION := 1
## 顶层命名空间（主人）：core G01 · loop G02 · rules G03 · econ G04 · ladder G06 · fate G05 · ui G01（只经 ui.guide 写）
const NAMESPACES: Array[String] = ["core", "loop", "rules", "econ", "ladder", "fate", "ui"]

var data: Dictionary = {}
var _self_uid_cache: String = ""
var _self_uid_cards_size: int = -1


## 只建空命名空间；各模块在 stage_start 钩子里填初值。opts: {difficulty, db_hash}
static func create(seed: int, opts: Dictionary) -> CardState:
	var st := CardState.new()
	st.data = {"v": VERSION, "seed": seed, "difficulty": str(opts.get("difficulty", "normal")),
		"db_hash": str(opts.get("db_hash", ""))}
	for ns_name in NAMESPACES:
		st.data[ns_name] = {}
	st.data["core"] = {"uid_seq": 0, "deal_seq": 0, "cards": {}, "queue": [], "deals": {}, "draw_k": {}, "firsts": {},
		"zones": {"hand": [], "kept": [], "contacts": [], "demands": [], "pending": [], "discard": []}}
	return st


## data[name]，不存在就建
func ns(name: String) -> Dictionary:
	if not data.has(name) or typeof(data[name]) != TYPE_DICTIONARY:
		data[name] = {}
	return data[name]


func to_dict() -> Dictionary:
	return data.duplicate(true)


## 把 JSON 读回来的整数值浮点数还原成 int；校验 v；不认识的命名空间原样保留。
## v 比自己新时返回 null（调用方报 save_newer）。
static func from_dict(d: Dictionary, restore_ints: bool = true) -> CardState:
	var restored: Dictionary = int_restore(d) if restore_ints else d
	if int(restored.get("v", 0)) > VERSION:
		return null
	var st := CardState.new()
	st.data = restored
	for ns_name in NAMESPACES:
		st.ns(ns_name)
	return st


## 去掉 "ui" 后 JSON.stringify(d, "", true, true)（排序键、全精度）的 sha256
func hash() -> String:
	var d := data.duplicate(false)
	d.erase("ui")
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(JSON.stringify(d, "", true, true).to_utf8_buffer())
	return ctx.finish().hex_encode()


## 新的牌 uid："c%04d"，core.uid_seq 递增
func new_uid() -> String:
	var core := ns("core")
	var n := int(core.get("uid_seq", 0)) + 1
	core["uid_seq"] = n
	return "c%04d" % n


## 递归把整数值的浮点数变回 int（JSON 读回来的数都是浮点）
static func int_restore(v):
	match typeof(v):
		TYPE_FLOAT:
			if is_finite(v) and v == floorf(v) and absf(v) < 9.0e15:
				return int(v)
			return v
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(int_restore(x))
			return arr
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v.keys():
				out[k] = int_restore(v[k])
			return out
	return v
