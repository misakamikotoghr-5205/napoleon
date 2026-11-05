# C16 测试用的假引擎：只回答指引查询，并记下 send。不写 class_name。
extends CardEngineApi

var sent: Array = []
var view_d: Dictionary = {}
var data: Dictionary = {"steps": [], "settings": {}}
var firsts: Dictionary = {}
var progress: Dictionary = {}
var conds: Dictionary = {}


func new_game(_opts: Dictionary) -> Dictionary:
	return {"ok": true, "err": ""}


func load_game(_path: String) -> Dictionary:
	return {"ok": true, "err": "", "meta": {}}


func save_game(_path: String) -> Dictionary:
	return {"ok": true, "err": ""}


func view() -> Dictionary:
	return view_d.duplicate(true)


func send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
	sent.append([str(cmd), args.duplicate(true)])
	if cmd == &"ui.guide":
		_note_guide(args)
	return {"ok": true, "err": ""}


func query(q: StringName, args: Dictionary = {}) -> Dictionary:
	if q == &"guide_data":
		return data.duplicate(true)
	if q == &"guide_progress":
		return {"progress": progress.duplicate(true)}
	if q == &"firsts":
		return {"firsts": firsts.duplicate(true)}
	if q == &"guide_conds":
		var out: Dictionary = {}
		for id in args.get("ids", []):
			out[str(id)] = bool(conds.get(str(id), false))
		return out
	return {}


func is_busy() -> bool:
	return false


func _note_guide(args: Dictionary) -> void:
	var step := str(args.get("step", ""))
	var status := str(args.get("status", ""))
	var row: Dictionary = progress.get(step, {})
	if status == "shown":
		row["shows"] = int(row.get("shows", 0)) + 1
	if str(row.get("status", "")) != "done":
		row["status"] = status
	var date = view_d.get("date")
	row["abs_day"] = int(date.get("abs_day", 0)) if typeof(date) == TYPE_DICTIONARY else 0
	if not row.has("shows"):
		row["shows"] = 0
	progress[step] = row
