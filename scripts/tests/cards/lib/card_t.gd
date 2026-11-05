# 卡牌版测试的小工具（W0，Claude）。每个测试：T.new(self, "<清单里的名字>") → 断言 → t.finish()。
# finish() 清 CardText 与 CardAnchors、删掉本测试的 user:// 目录，打印 "CARDS TEST PASS <名字>" 或 "FAIL: …"，然后 quit(0/1)。
# 合同：docs/cards/CARDS_INTERFACES.md §12.1（runner 只认最后一行 CARDS TEST PASS <名字>；任何 WARNING/ERROR 行都算失败）。
#   const T = preload("res://scripts/tests/cards/lib/card_t.gd")
#   func _initialize() -> void:
#       var t := T.new(self, "G03 铜钱数与正面")
#       … t.ok(cond, "说明") / t.eq(a, b, "说明") / t.no_leaks(engine.view())
#       t.finish()
# 要等帧的界面测试：t.run_async(func(): await …)（库里处理 await，结束时自动 finish()）。
# 注意：_initialize 里场景树还没开始跑，加进 root 的节点要等一帧（await t.frames(1)）才算在树里（锚点、_ready 都要它）。
extends RefCounted

var tree: SceneTree
var name: String
var fails := PackedStringArray()
var checks: int = 0
var _finished: bool = false


func _init(p_tree: SceneTree, p_name: String) -> void:
	tree = p_tree
	name = p_name
	DirAccess.make_dir_recursive_absolute(user_dir())
	# 2026-10-22：游戏默认缺字给空串；测试仍按开发版看【稿】+ brief（要测空串的测试自己 set_show_drafts(false)）。
	CardText.set_show_drafts(true)


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)


## 深比较（字典/数组按 JSON 排序键比较，整数值的浮点和整数算相等）
func eq(a, b, msg: String) -> void:
	checks += 1
	if not _same(a, b):
		fails.append("%s: expected %s, got %s" % [msg, _short(b), _short(a)])


## 视图、查询结果、事件参数里没有 §7.5 的隐藏键
func no_leaks(v, msg: String = "view") -> void:
	var bad := CardViewModel.leaks(v)
	ok(bad.is_empty(), "%s leaks hidden keys: %s" % [msg, ", ".join(bad)])


## 所有浮点值的路径（状态里不许有浮点，§6.1）
func find_floats(v, path: String = "") -> PackedStringArray:
	if not _has_float(v):
		return PackedStringArray()
	var out := PackedStringArray()
	match typeof(v):
		TYPE_FLOAT:
			out.append(path if path != "" else "<root>")
		TYPE_DICTIONARY:
			for k in v.keys():
				out.append_array(find_floats(v[k], "%s.%s" % [path, k] if path != "" else str(k)))
		TYPE_ARRAY:
			for i in range(v.size()):
				out.append_array(find_floats(v[i], "%s[%d]" % [path, i]))
	return out


func _has_float(v) -> bool:
	match typeof(v):
		TYPE_FLOAT:
			return true
		TYPE_DICTIONARY:
			for val in v.values():
				if _has_float(val):
					return true
		TYPE_ARRAY:
			for x in v:
				if _has_float(x):
					return true
	return false


## 记下总线上所有信号（含 ui_event）：spy.log = [[信号名, 参数…], …]
func spy(bus: CardEventBus) -> Spy:
	var s := Spy.new()
	for sig in bus.get_signal_list():
		var n := StringName(str(sig["name"]))
		if not (n in CardEventBus.ENGINE_SIGNALS or n == &"ui_event"):
			continue
		var argc: int = (sig["args"] as Array).size()
		var cb: Callable = [s._r0, s._r1, s._r2, s._r3, s._r4][argc]
		bus.connect(n, cb.bind(n))
	return s


## 锚点有面积且整块在 1280×720 里
func anchor_ok(id: StringName) -> bool:
	return anchor_in(id, Rect2(0, 0, 1280, 720))


func anchor_in(id: StringName, rect: Rect2) -> bool:
	var r := CardAnchors.rect(id)
	return r.has_area() and rect.encloses(r)


func anchor_ok_any(ids: Array) -> bool:
	for id in ids:
		if anchor_ok(StringName(str(id))):
			return true
	return false


## 本测试自己的 user:// 目录（开头建、结束删）；存档根、设置文件都指过去
func user_dir() -> String:
	var safe := ""
	for ch in name:
		safe += ch if (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9") or ch == "_" else "_"
	return "user://test/%s_%s" % [safe.substr(0, 40), name.sha256_text().substr(0, 8)]


## 界面上每段非空文字要么是 CardText 给出的，要么只由数字和标点组成；返回不合格的文字
func all_text_from_cardtext(node: Node) -> PackedStringArray:
	var bad := PackedStringArray()
	var re := RegEx.create_from_string("^[0-9\\s.,:;/+\\-()]*$")
	for n in _walk(node):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).get_parsed_text()
		if txt != "" and not CardText.issued_contains(txt) and re.search(txt) == null:
			bad.append(txt)
	return bad


func frames(n: int = 1) -> void:
	for i in range(n):
		await tree.process_frame


## fn 是要 await 的测试体；跑完自动 finish()
func run_async(fn: Callable) -> void:
	await fn.call()
	finish()


func finish() -> void:
	if _finished:
		return
	_finished = true
	CardText.setup(null)
	CardAnchors.clear()
	_rm_tree(user_dir())
	if fails.is_empty() and checks > 0:
		print("CARDS TEST PASS " + name)
		tree.quit(0)
	else:
		if checks == 0:
			fails.append("no checks ran")
		for f in fails:
			print("FAIL: " + f)
		tree.quit(1)


# ---------------- 内部 ----------------
func _same(a, b) -> bool:
	if typeof(a) in [TYPE_DICTIONARY, TYPE_ARRAY] or typeof(b) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		var ra = CardState.int_restore(a) if _has_float(a) else a
		var rb = CardState.int_restore(b) if _has_float(b) else b
		return JSON.stringify(ra, "", true) == JSON.stringify(rb, "", true)
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		return float(a) == float(b)
	if typeof(a) in [TYPE_STRING, TYPE_STRING_NAME] and typeof(b) in [TYPE_STRING, TYPE_STRING_NAME]:
		return str(a) == str(b)
	return a == b


func _short(v) -> String:
	var s := JSON.stringify(v)
	return s if s.length() < 300 else s.substr(0, 300) + "…"


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func _rm_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_rm_tree(dir + "/" + d)
	DirAccess.remove_absolute(dir)


class Spy:
	extends RefCounted
	var log: Array = []

	func count(sig: StringName) -> int:
		var n := 0
		for row in log:
			if row[0] == sig:
				n += 1
		return n

	func names() -> Array:
		return log.map(func(row: Array) -> StringName: return row[0])

	func ui_events() -> Array:
		var out: Array = []
		for row in log:
			if row[0] == &"ui_event":
				out.append([row[1], row[2]])
		return out

	func clear() -> void:
		log = []

	func _r0(n: StringName) -> void:
		log.append([n])

	func _r1(a, n: StringName) -> void:
		log.append([n, a])

	func _r2(a, b, n: StringName) -> void:
		log.append([n, a, b])

	func _r3(a, b, c, n: StringName) -> void:
		log.append([n, a, b, c])

	func _r4(a, b, c, d, n: StringName) -> void:
		log.append([n, a, b, c, d])
