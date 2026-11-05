# 剧情 VN 的台词表：把剧情牌正文（一段一段）拆成一句一句，不改写正文。
#   - 一段以“叫法（+说道/答道…）：“……””开头 -> 这个人说的一句（只取引号里的话），引号后面剩下的再看一遍：
#     还是“叫法：“……””就是下一个人说的，否则是一句旁白；
#   - 别的段落是旁白（没有名字牌）；旁白以某个人的叫法开头、里面又有引号（“维尔福敲响天平：“……””）时，
#     这个人上场并被照亮，但这句仍按原文当旁白放；
#   - 太长的一句按句号、感叹号、问号、分号切开（每块不超过 MAX_LINE 个字）。
# 每段第一句带上 vn_cast.json 里这一段的演出（换背景、上场、下场、表情）。没有 class_name。
extends RefCounted

const Data = preload("res://scripts/cards/ui/vn/vn_data.gd")
const MAX_LINE := 150
const COLON := 0xFF1A
## 开引号 -> 关引号（“” 和「」）
const QUOTES := {0x201C: 0x201D, 0x300C: 0x300D}
## 句末：。！？；…
const STOPS := [0x3002, 0xFF01, 0xFF1F, 0xFF1B, 0x2026]
## 跟在句末后面、仍算这一句的：” 」 ）
const TRAIL := [0x201D, 0x300D, 0xFF09]


## 一场的全部台词：paras 是正文段落（顺序同剧情牌 body）。每句：
## {kind: say|narr, who, name, text, para, focus?, dir?}；dir = {bg?: {id, variant}, enter?: [{who, at}], exit?: [id], expr?: {id: expr}}
static func build(scene_id: String, paras: PackedStringArray, presentation: Dictionary = {}) -> Array:
	var out: Array = []
	var spec := Data.scene(scene_id, presentation)
	for i in paras.size():
		var lines := paragraph(paras[i], i)
		if lines.is_empty():
			continue
		var d := directions(spec, i)
		if not d.is_empty():
			lines[0]["dir"] = d
		out.append_array(lines)
	return out


## 一段正文拆成的句子
static func paragraph(text: String, para: int = 0) -> Array:
	var raw: Array = []
	var rest := text.strip_edges()
	var guard := 0
	while rest != "" and guard < 12:
		guard += 1
		var m := speaker(rest)
		if m.is_empty():
			break
		raw.append(_line("say", str(m["who"]), str(m["name"]), str(m["text"]), para))
		rest = str(m["rest"]).strip_edges()
	if rest != "":
		var narr := _line("narr", "", "", rest, para)
		var lead := leading_alias(rest)
		if not lead.is_empty() and _has_quote(rest):
			narr["focus"] = str(lead["who"])
		raw.append(narr)
	var out: Array = []
	for l in raw:
		for piece in chunk(str(l["text"]), MAX_LINE):
			var c: Dictionary = (l as Dictionary).duplicate(true)
			c["text"] = piece
			out.append(c)
	return out


## 开头是不是“叫法（+说道）：“……””：是就回 {who, name, text, rest}，不是回 {}
static func speaker(s: String) -> Dictionary:
	for pair in Data.aliases():
		var alias := str(pair[0])
		if not s.begins_with(alias):
			continue
		var after := s.substr(alias.length())
		var verbs: Array = [""]
		verbs.append_array(Data.say_verbs())
		for v in verbs:
			var verb := str(v)
			if not after.begins_with(verb):
				continue
			var r := after.substr(verb.length())
			if r.length() < 3 or r.unicode_at(0) != COLON or not QUOTES.has(r.unicode_at(1)):
				continue
			var close := String.chr(int(QUOTES[r.unicode_at(1)]))
			var end := r.find(close, 2)
			if end < 0:
				continue
			var said := r.substr(2, end - 2).strip_edges()
			if said == "":
				continue
			return {"who": str(pair[1]), "name": alias, "text": said, "rest": r.substr(end + 1)}
	return {}


## 开头的叫法（不管后面跟什么）：{who, name} 或 {}
static func leading_alias(s: String) -> Dictionary:
	for pair in Data.aliases():
		if s.begins_with(str(pair[0])):
			return {"who": str(pair[1]), "name": str(pair[0])}
	return {}


## 太长的一句按句末切成几块，每块不超过 limit 个字（一句本身就超长时硬切）
static func chunk(text: String, limit: int) -> PackedStringArray:
	var out := PackedStringArray()
	if text.length() <= limit or limit <= 0:
		out.append(text)
		return out
	var sentences := PackedStringArray()
	var cur := ""
	var i := 0
	while i < text.length():
		var c := text.unicode_at(i)
		cur += text.substr(i, 1)
		i += 1
		if c in STOPS:
			while i < text.length() and (text.unicode_at(i) in TRAIL or text.unicode_at(i) in STOPS):
				cur += text.substr(i, 1)
				i += 1
			sentences.append(cur)
			cur = ""
	if cur != "":
		sentences.append(cur)
	var block := ""
	for s in sentences:
		if block != "" and block.length() + s.length() > limit:
			out.append(block)
			block = ""
		block += s
		while block.length() > limit:
			out.append(block.left(limit))
			block = block.substr(limit)
	if block != "":
		out.append(block)
	return out


## 第 para 段开头的演出（vn_cast.json 的这一场）；没有回 {}
static func directions(spec: Dictionary, para: int) -> Dictionary:
	var d := {}
	var key := str(para)
	for b in spec.get("bg", []):
		if typeof(b) == TYPE_DICTIONARY and typeof(b.get("at")) != TYPE_STRING and int(b.get("at", -1)) == para and para > 0:
			d["bg"] = {"id": str(b.get("id", "")), "variant": str(b.get("variant", ""))}
	var enter = spec.get("enter", {}).get(key, [])
	if typeof(enter) == TYPE_ARRAY and not enter.is_empty():
		d["enter"] = (enter as Array).duplicate(true)
	var leave = spec.get("exit", {}).get(key, [])
	if typeof(leave) == TYPE_ARRAY and not leave.is_empty():
		d["exit"] = (leave as Array).duplicate(true)
	var expr = spec.get("expr", {}).get(key, {})
	if typeof(expr) == TYPE_DICTIONARY and not expr.is_empty():
		d["expr"] = (expr as Dictionary).duplicate(true)
	return d


## 开场：第 0 段的背景和站在台上的人 {bg: {id, variant}, cast: [{who, at}]}
static func opening(scene_id: String, presentation: Dictionary = {}) -> Dictionary:
	var spec := Data.scene(scene_id, presentation)
	var bg := {}
	for b in spec.get("bg", []):
		if typeof(b) != TYPE_DICTIONARY:
			continue
		if bg.is_empty() or (typeof(b.get("at")) != TYPE_STRING and int(b.get("at", -1)) == 0):
			bg = {"id": str(b.get("id", "")), "variant": str(b.get("variant", ""))}
		if typeof(b.get("at")) != TYPE_STRING and int(b.get("at", -1)) == 0:
			break
	var cast_rows: Array = []
	for c in spec.get("cast", []):
		if typeof(c) == TYPE_DICTIONARY and str(c.get("who", "")) != "":
			cast_rows.append({"who": str(c["who"]), "at": str(c.get("at", "center"))})
	return {"bg": bg, "cast": cast_rows}


## 读完正文、出抉择时换的背景（vn_cast.json 里 at = "choices"）；没有回 {}
static func choices_bg(scene_id: String, presentation: Dictionary = {}) -> Dictionary:
	for b in Data.scene(scene_id, presentation).get("bg", []):
		if typeof(b) == TYPE_DICTIONARY and str(b.get("at", "")) == "choices":
			return {"id": str(b.get("id", "")), "variant": str(b.get("variant", ""))}
	return {}


## 一句别的（鉴定结果、抉择、结算、提示）：plate 是名字牌上的字（空 = 不显示名字牌）
static func extra(kind: String, plate: String, text: String) -> Dictionary:
	return {"kind": kind, "who": "", "name": plate, "text": text, "para": -1}


static func _line(kind: String, who: String, name: String, text: String, para: int) -> Dictionary:
	return {"kind": kind, "who": who, "name": name, "text": text, "para": para}


static func _has_quote(s: String) -> bool:
	for q in QUOTES:
		if s.find(String.chr(int(q))) >= 0:
			return true
	return false
