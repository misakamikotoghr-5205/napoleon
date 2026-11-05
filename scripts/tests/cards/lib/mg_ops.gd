# 小游戏测试小工具（鉴定改版，主创 10-25：要玩家看出来才算数；合同 §8.1 apply_op/ops_log、§12.2 小游戏必测）。
# 主人 Claude（WP0）。不写 class_name：const MgOps = preload("res://scripts/tests/cards/lib/mg_ops.gd")。
#   open(parent, scene, params)            实例化并 start(params)
#   autoplay(game, skill)                  -> {"result", "ops"}（ops = game.ops_log()）
#   replay(game, ops)                      逐个 apply_op -> {"result", "rejected": [下标…]}
#   diff(a, b)                             两个结果字典不同的键路径
#   replay_check(parent, scene, params, skills)  A autoplay(x) -> ops -> B 回放 -> 结果逐键相等；返回问题清单
#   text_problems(node, kind, allowed)     界面文字里的“%”、观察键正文、不在 allowed 里的数字
#   colors(node)                           界面节点用到的颜色集合（判对判错两局应一样）
#   engine_cases(kind, fake, n, seed)      真引擎（G04）给的参数 + 私账答案，给判断往返测试用
#   judge(kind, answer, result)            = CardAppraisal.judge（G04 的判分，只给测试看）
extends RefCounted

const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")
const E = preload("res://scripts/cards/economy/economy_support.gd")

## Templates per kind used for engine cases (real data, launch set).
const CASE_TEMPLATES := {"spot": "jewelry.hairpin", "coin_ring": "silver.yuan_a", "weigh": "jewelry.hairpin",
	"fragments": "art.landscape"}
const DOC_CASES := {"decode": "nw.1940.chen_code", "fragments": "tk.1938.de196"}


## Instantiates a minigame from a .tscn or .gd path under parent and starts it. Returns null on failure.
static func open(parent: Node, scene_or_script: String, params: Dictionary) -> CardMiniGame:
	var res = load(scene_or_script)
	var node: Node = null
	if res is PackedScene:
		node = (res as PackedScene).instantiate()
	elif res is Script:
		node = (res as Script).new()
	if not (node is CardMiniGame):
		if node != null:
			node.free()
		return null
	parent.add_child(node)
	(node as CardMiniGame).start(params.duplicate(true))
	return node as CardMiniGame


## Captures the next finished(result) of the game.
static func _catch(game: CardMiniGame) -> Array:
	var box: Array = []
	game.finished.connect(func(r: Dictionary) -> void: box.append(r.duplicate(true)), CONNECT_ONE_SHOT)
	return box


static func autoplay(game: CardMiniGame, skill: float) -> Dictionary:
	var box := _catch(game)
	game.autoplay(skill)
	var ops: Array = game.call("ops_log") if game.has_method("ops_log") else []
	return {"result": box[0] if not box.is_empty() else {}, "ops": ops}


static func replay(game: CardMiniGame, ops: Array) -> Dictionary:
	var box := _catch(game)
	var rejected: Array = []
	for i in range(ops.size()):
		if not bool(game.call("apply_op", (ops[i] as Array).duplicate(true))):
			rejected.append(i)
	return {"result": box[0] if not box.is_empty() else {}, "rejected": rejected}


## Paths where two values differ (dictionaries by key, arrays by index; int and float of equal value are equal).
static func diff(a, b, path: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	if typeof(a) == TYPE_DICTIONARY and typeof(b) == TYPE_DICTIONARY:
		var keys := {}
		for k in a.keys():
			keys[k] = true
		for k in b.keys():
			keys[k] = true
		for k in keys.keys():
			var p := "%s.%s" % [path, k] if path != "" else str(k)
			if not a.has(k) or not b.has(k):
				out.append(p)
			else:
				out.append_array(diff(a[k], b[k], p))
		return out
	if typeof(a) == TYPE_ARRAY and typeof(b) == TYPE_ARRAY:
		if a.size() != b.size():
			out.append(path + "[size]")
			return out
		for i in range(a.size()):
			out.append_array(diff(a[i], b[i], "%s[%d]" % [path, i]))
		return out
	if typeof(a) in [TYPE_INT, TYPE_FLOAT] and typeof(b) in [TYPE_INT, TYPE_FLOAT]:
		if float(a) != float(b):
			out.append(path)
		return out
	if typeof(a) != typeof(b) or a != b:
		out.append(path)
	return out


## Contract 12.2 replay: for each skill, A.autoplay(x) -> ops_log -> fresh B replays every op -> identical result.
## Returns human-readable problems (empty = pass). Frees both instances.
static func replay_check(parent: Node, scene_or_script: String, params: Dictionary, skills: Array = [0.0, 0.3, 0.8, 1.0]) -> PackedStringArray:
	var out := PackedStringArray()
	for skill in skills:
		var a := open(parent, scene_or_script, params)
		if a == null or not a.has_method("apply_op") or not a.has_method("ops_log"):
			out.append("%s: no apply_op / ops_log" % scene_or_script)
			if a != null:
				a.queue_free()
			return out
		var played := autoplay(a, float(skill))
		var b := open(parent, scene_or_script, params)
		var again := replay(b, played["ops"])
		if (played["result"] as Dictionary).is_empty():
			out.append("skill %s: autoplay did not finish" % skill)
		if not (again["rejected"] as Array).is_empty():
			out.append("skill %s: replay rejected ops %s" % [skill, again["rejected"]])
		var d := diff(played["result"], again["result"])
		if not d.is_empty():
			out.append("skill %s: replayed result differs at %s" % [skill, ", ".join(d)])
		a.queue_free()
		b.queue_free()
	return out


## No-reveal scan of the visible text under node: any "%", any observation text of this kind (the minigame must
## never write its own verdict), and any number not in allowed (ink, tries, weight faces, the claimed weight,
## star numbers, codes...). Pass allowed = [] to skip the number check.
static func text_problems(node: Node, kind: StringName, allowed: Array, db: CardDB = null) -> PackedStringArray:
	var out := PackedStringArray()
	var obs_texts := {}
	if db != null:
		for key in db.obs_catalog(kind).keys():
			var s := CardText.obs(str(key))
			if s.strip_edges() != "":
				obs_texts[s] = str(key)
	var allowed_set := {}
	for n in allowed:
		allowed_set[str(n)] = true
	var digits := RegEx.create_from_string("[0-9]+")
	for n in _walk(node):
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is Button:
			txt = (n as Button).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).get_parsed_text()
		if txt == "" or not _shown(n):
			continue
		if txt.contains("%"):
			out.append("percent sign: " + txt)
		if obs_texts.has(txt):
			out.append("observation text on screen (%s): %s" % [obs_texts[txt], txt])
		if not allowed.is_empty():
			for m in digits.search_all(txt):
				if not allowed_set.has(m.get_string()):
					out.append("number %s not allowed: %s" % [m.get_string(), txt])
	return out


## Colours used by visible canvas items: modulate, self_modulate, ColorRect.color, font colour overrides.
## Two runs that judged right and wrong should give the same set (no colour by correctness).
static func colors(node: Node) -> Dictionary:
	var out := {}
	for n in _walk(node):
		if not (n is CanvasItem) or not _shown(n):
			continue
		var ci := n as CanvasItem
		out[ci.modulate.to_html()] = true
		out[ci.self_modulate.to_html()] = true
		if n is ColorRect:
			out[(n as ColorRect).color.to_html()] = true
		if n is Control:
			for key in ["font_color", "default_color"]:
				if (n as Control).has_theme_color_override(key):
					out[(n as Control).get_theme_color(key).to_html()] = true
	return out


## Real-engine cases: [{"params", "answer", "fake"}]. Items use the launch templates above; documents use the
## main-line cards. Answers are the G04 private record (tests only).
static func engine_cases(kind: StringName, fake: bool, n: int, seed: int = 7) -> Array:
	var c := A.real_ctx(seed)
	var out: Array = []
	if kind == &"decode":
		var d := c.db.def(str(DOC_CASES["decode"]))
		var b := CardAppraisal._build(c, "", kind, d)
		return [{"params": b["params"], "answer": b["answer"], "fake": false}]
	var tpl := str(CASE_TEMPLATES.get(str(kind), ""))
	for id in A.items_of(c, tpl, fake, n, "mg_ops"):
		var b2 := CardAppraisal._build(c, str(id), kind, {})
		out.append({"params": b2["params"], "answer": b2["answer"], "fake": fake})
	return out


static func judge(kind: StringName, answer: Dictionary, result: Dictionary) -> Dictionary:
	return CardAppraisal.judge(kind, answer, result)


## Visible along the CanvasItem chain (works before the first frame and outside a visible window).
static func _shown(n: Node) -> bool:
	var cur: Node = n
	while cur is CanvasItem:
		if not (cur as CanvasItem).visible:
			return false
		cur = cur.get_parent()
	return true


static func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
