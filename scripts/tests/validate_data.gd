# 数据校验：所有剧情 / 顾客会话 / 物品引用是否有效，条件表达式能否解析，台词里有没有字体缺字。
# godot --headless -s res://scripts/tests/validate_data.gd   （失败退出码 1）
extends SceneTree

const Director = preload("res://scripts/core/director.gd")
const Cond = preload("res://scripts/core/cond.gd")

const HOOKS = ["swap_rice_bag", "give_item", "burn_trash", "ma_fee", "brother_money", "day_close_lines", "share_rumors", "sun_real_deed", "set_door_flag"]
const STATS = ["koubei", "benxin", "suspicion", "chen", "chen_trust"]
const TARGETS = ["pawnbox", "magnifier", "abacus", "scale", "ledger", "notebook", "medbook", "trash", "telegraph", "door_flag", "sign", "lamp", "counter_item"]
const SLOTS = ["清晨", "上午", "中午", "下午", "傍晚", "夜"]

var db
var errs: Array = []
var where: String = ""

func _initialize() -> void:
	db = DB.get_db()
	errs.append_array(db.errors)
	for ch in db.flow.get("chapters", []):
		if not db.scripts.has(ch):
			errs.append("flow 里的章节没有脚本：" + str(ch))
	for id in db.scripts:
		where = "story/" + id
		_steps(db.scripts[id].get("steps", []), false)
	for id in db.sessions:
		where = "sessions/" + id
		var s: Dictionary = db.sessions[id]
		if not db.cast.has(str(s.get("npc", ""))):
			errs.append("%s：npc 不存在 %s" % [where, s.get("npc")])
		if not str(s.get("mode", "")) in ["buy", "pawn", "sell"]:
			errs.append("%s：mode 无效" % where)
		for it in s.get("items", []):
			_item(str(it.get("def", "")))
		for d in s.get("stock", []):
			_item(str(d))
			if not s.get("buyer_prices", {}).has(d):
				errs.append("%s：卖货缺 buyer_prices.%s" % [where, d])
		for k in ["pre", "intro", "on_accept", "on_leave", "outro", "post"]:
			_steps(s.get(k, []), true)
		for ev in s.get("on_inspect", {}):
			_steps(s["on_inspect"][ev], true)
		for e in s.get("extras", []) + s.get("deals", []):
			_cond(e.get("when", ""), true)
			_steps(e.get("steps", []), true)
	for id in db.items:
		var it: Dictionary = db.items[id]
		where = "items/" + id
		for k in ["name", "cat", "market", "parts", "sprite"]:
			if not it.has(k):
				errs.append("%s：缺字段 %s" % [where, k])
		if not ResourceLoader.exists("res://" + str(it.get("sprite", ""))):
			errs.append("%s：缺特写图 %s" % [where, it.get("sprite")])
		for p in it.get("parts", []):
			for k in ["id", "label", "text"]:
				if not p.has(k):
					errs.append("%s：部位缺 %s" % [where, k])
			if not str(p.get("tool", "magnifier")) in ["magnifier", "scale", "book", "hand", "nose"]:
				errs.append("%s：工具无效 %s" % [where, p.get("tool")])
	for id in db.cast:
		if not ResourceLoader.exists("res://art/portraits/%s.png" % id):
			errs.append("缺立绘：" + id)
	for id in db.layout.get("hotspots", {}):
		if id in ["customer", "counter_item"]:
			continue
		if not ResourceLoader.exists("res://art/tools/%s.png" % id):
			errs.append("缺工具图：" + id)
	_glyphs()
	if errs.is_empty():
		print("DATA OK: %d 脚本, %d 会话, %d 物品, %d 人物" % [db.scripts.size(), db.sessions.size(), db.items.size(), db.cast.size()])
		DB.shutdown()
		quit(0)
	else:
		for e in errs:
			printerr("DATA ERROR: ", e)
		DB.shutdown()
		quit(1)

func _item(d: String) -> void:
	if not db.items.has(d):
		errs.append("%s：物品不存在 %s" % [where, d])

func _cond(c, in_session: bool) -> void:
	if str(c) == "":
		return
	var e := Expression.new()
	if e.parse(Cond.rewrite(str(c))) != OK:
		errs.append("%s：条件解析失败 「%s」：%s" % [where, c, e.get_error_text()])
	var sess_only := ["price(", "ask(", "floor(", "suggest(", "selected(", "tells(", "judged_fake(", "rounds("]
	if not in_session:
		for f in sess_only:
			if str(c).find(f) >= 0 and str(c).find("_" + f) < 0:
				errs.append("%s：会话外用了会话函数 「%s」" % [where, c])

func _steps(steps: Array, in_session: bool) -> void:
	for st in steps:
		if typeof(st) != TYPE_DICTIONARY:
			errs.append("%s：步骤不是对象" % where)
			continue
		var op := str(st.get("op", ""))
		if not Director.KNOWN_OPS.has(op):
			errs.append("%s：未知 op %s" % [where, op])
		_cond(st.get("when", ""), in_session)
		match op:
			"say", "tutorial":
				var w := str(st.get("who", "narr"))
				if w != "you" and w != "narr" and w != "patrol" and not db.cast.has(w):     # patrol：宵禁巡夜的，演出时由 curfew.gd 临时登记
					errs.append("%s：说话人不存在 %s" % [where, w])
				if op == "tutorial" and not TARGETS.has(str(st.get("target", ""))):
					errs.append("%s：教学目标无效 %s" % [where, st.get("target")])
			"choice":
				for o in st.get("options", []):
					_cond(o.get("when", ""), in_session)
					_steps(o.get("steps", []), in_session)
			"if":
				_cond(st.get("cond", ""), in_session)
				_steps(st.get("then", []), in_session)
				_steps(st.get("else", []), in_session)
			"session":
				if not db.sessions.has(str(st.get("id", ""))):
					errs.append("%s：会话不存在 %s" % [where, st.get("id")])
			"run":
				if not db.scripts.has(str(st.get("script", ""))):
					errs.append("%s：脚本不存在 %s" % [where, st.get("script")])
			"call":
				if not HOOKS.has(str(st.get("fn", ""))):
					errs.append("%s：钩子不存在 %s" % [where, st.get("fn")])
			"page":
				if not db.pages.has(str(st.get("id", ""))):
					errs.append("%s：知识页不存在 %s" % [where, st.get("id")])
			"item", "move_item":
				if st.has("def"):
					_item(str(st["def"]))
			"stat":
				var s := str(st.get("stat", ""))
				var ok: bool = STATS.has(s) or s.begins_with("faction:") or (s.begins_with("favor:") and db.cast.has(s.substr(6)))
				if not ok:
					errs.append("%s：数值名无效 %s" % [where, s])
			"slot":
				if not SLOTS.has(str(st.get("to", ""))):
					errs.append("%s：时段无效 %s" % [where, st.get("to")])
			"var":
				if st.has("expr"):
					_cond(st["expr"], in_session)
			"telegraph":
				for w in st.get("incoming", []):
					if db.code_of(str(w)) == "????":
						errs.append("%s：电码本没有 %s" % [where, w])
				for r in st.get("replies", []):
					_cond(r.get("when", ""), in_session)
					_steps(r.get("steps", []), in_session)
				_steps(st.get("default_steps", []), in_session)
				_steps(st.get("skip_steps", []), in_session)
			"reprice", "end", "set_judged", "select":
				if not in_session:
					errs.append("%s：会话外用了 %s" % [where, op])

# 字体覆盖：所有数据文本里的字都要在正文字体里（否则会显示豆腐块）
func _glyphs() -> void:
	var f: FontFile = load("res://fonts/NotoSerifSC-Regular-subset.otf")
	var seen := {}
	var missing := ""
	for path in ["res://data/cast.json", "res://data/pages.json", "res://data/factions.json", "res://data/medbook.json", "res://data/codebook.json", "res://data/night.json"] + _all("res://data/story") + _all("res://data/sessions") + _all("res://data/items") + _town_json("res://data/town"):
		var txt := FileAccess.get_file_as_string(path)
		for i in range(txt.length()):
			var c := txt.unicode_at(i)
			if c < 0x2E80 or seen.has(c):
				continue
			seen[c] = true
			if not f.has_char(c):
				missing += char(c)
	if missing != "":
		errs.append("正文字体缺字（会显示豆腐块）：" + missing + "  → 运行 python3 tools/build_fonts.py")

func _all(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(dir + "/" + f)
	return out

func _town_json(dir: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	out.append_array(_all(dir))
	for child in DirAccess.get_directories_at(dir):
		out.append_array(_town_json(dir + "/" + child))
	return out
