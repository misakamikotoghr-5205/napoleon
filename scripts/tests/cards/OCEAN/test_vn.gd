# 剧情 VN（scripts/cards/ui/vn/）的无头测试 OCEAN_vn：
# 演出表保留远洋战役的 24 个人物、14 场，并覆盖正式拿破仑书的场景/事件；正文拆句（谁在说话、
# 引号后面的旁白、长句切块、不丢字）；面板用真引擎打开：章节卡、打字机（先出全句再下一句）、自动、快进、记录、
# 隐藏和恢复、灰掉的选项写原因、鉴定 -> 观察结果几句话 -> 回到菜单、作出决定 -> 结算 -> 关掉；
# 14 场每一场都经由 VN 打开、鉴定、作出决定一路走到结局；存档读档后 VN 照样从引擎读出已鉴定的线索。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Data = preload("res://scripts/cards/ui/vn/vn_data.gd")
const VnScript = preload("res://scripts/cards/ui/vn/vn_script.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const PANEL := "res://scripts/cards/ui/vn/vn_panel.gd"
const VN_DIR := "res://scripts/cards/ui/vn"
const CAMPAIGN := "res://data/campaigns/ocean_pawn.json"
const BOOK := "res://data/campaigns/napoleon/book.json"
const PALETTE_DEV := "res://data/cards/theme/palette.dev.json"
const ROUTE := [
	["prologue", "secure_passage"], ["scene01", "seal_evidence"],
	["scene02", "expose_sabre"], ["scene03", "audit_accounts"],
	["scene04", "prepare_escape"], ["scene05", "redeem_emperor"],
	["scene06", "establish_rations"], ["scene07", "expose_viper"],
	["scene08", "prepare_operation"], ["scene09", "capture_viper"],
	["scene10", "audit_alliance"], ["scene11", "expose_vigo"],
	["scene12", "cut_orichalcum"], ["finale", "close_ledger"],
]
const SKIP_BATTLE := [
	["campaign.battle_prepare", {}],
	["campaign.battle_begin", {"companions": [], "troops": [], "protagonist": false}],
	["campaign.battle_cmd", {"cmd": "retreat", "args": {}}],
	["campaign.battle_finish", {}],
]

var t
var _def: Dictionary = {}
var _bus: CardEventBus
var _closed_with: Array = []


func _initialize() -> void:
	t = T.new(self, "OCEAN_vn")
	CardText.set_show_drafts(false)
	t.run_async(_body)


func _body() -> void:
	await t.frames(1)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN))
	_def = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	t.ok(not _def.is_empty(), "ocean campaign definition loads")
	CardSave.set_root(t.user_dir())
	_bus = CardEventBus.new()
	root.add_child(_bus)
	_test_cast_data()
	_test_formal_cast()
	_test_ui_data()
	_test_lines()
	_test_scene_scripts()
	_test_house_rules()
	await _test_prologue_flow()
	await _test_full_route()
	await _test_side_decision()
	await _test_save_load()
	_bus.queue_free()
	await t.frames(2)
	CardSave.set_root(CardSave.DEFAULT_ROOT)


# ================================================================ 数据

func _scenes() -> Array:
	return _def.get("scenes", [])


func _paras(scene_id: String) -> PackedStringArray:
	for s in _scenes():
		if str(s.get("id", "")) == scene_id:
			return PackedStringArray(s.get("body", []))
	return PackedStringArray()


func _test_cast_data() -> void:
	var cast := Data.cast()
	t.ok(not cast.is_empty(), "vn_cast.json loads")
	var chars := Data.chars()
	var art_chara := {}
	for a in HdArt.assets("chara"):
		art_chara[str(a["id"])] = true
	var bgs := {}
	for a in HdArt.assets("bg"):
		bgs[str(a["id"])] = a
	t.ok(chars.has(Data.protagonist()), "protagonist is a cast character")
	var people: Array = _def.get("characters", [])
	t.eq(people.size(), 24, "the ocean campaign has 24 characters")
	var seen_alias := {}
	for p in people:
		var id := str(p["id"])
		t.ok(chars.has(id), "vn_cast covers character " + id)
		var row: Dictionary = chars.get(id, {})
		var aliases: Array = row.get("aliases", [])
		t.ok(not aliases.is_empty(), "character %s has aliases" % id)
		for a in aliases:
			t.ok(not seen_alias.has(str(a)) or seen_alias[str(a)] == id, "alias %s names one character" % a)
			seen_alias[str(a)] = id
		var art := Data.art_id(id)
		t.ok(art_chara.has(art) or bool(row.get("placeholder_only", false)),
			"character %s has a chara art id in art_list (%s) or is placeholder_only" % [id, art])
		# 正式名字里的第一个叫法要能在名字里找到（叫法不是凭空编的）
		var full := str(p.get("name", ""))
		t.ok(aliases.any(func(x: Variant) -> bool: return full.contains(str(x))), "an alias of %s appears in its name %s" % [id, full])
	# 正文里每个“叫法：“”开头的台词都认得出说话的人
	var alias_list := Data.aliases()
	for i in range(1, alias_list.size()):
		t.ok(str(alias_list[i - 1][0]).length() >= str(alias_list[i][0]).length(), "aliases are sorted longest first")
	t.eq(Data.max_on_stage(), 3, "at most three on stage")
	var scenes: Dictionary = cast.get("scenes", {})
	t.ok(scenes.size() >= _scenes().size(), "the shared stage table contains all ocean scenes")
	for s in _scenes():
		var sid := str(s["id"])
		var spec := Data.scene(sid)
		t.ok(not spec.is_empty(), "vn_cast has scene " + sid)
		var n := (s.get("body", []) as Array).size()
		var bg_rows: Array = spec.get("bg", [])
		t.ok(not bg_rows.is_empty(), sid + " has a background")
		if not bg_rows.is_empty():
			t.eq(bg_rows[0].get("at"), 0, sid + " first background starts at paragraph 0")
		for b in bg_rows:
			var bid := str(b.get("id", ""))
			t.ok(bgs.has(bid), "%s background %s is in art_list" % [sid, bid])
			var at = b.get("at")
			t.ok((typeof(at) == TYPE_STRING and at == "choices") or (typeof(at) != TYPE_STRING and int(at) >= 0 and int(at) < n),
				"%s background %s switches at a real paragraph (%s)" % [sid, bid, str(at)])
			var variant := str(b.get("variant", ""))
			if variant != "":
				var listed: Array = bgs.get(bid, {}).get("variants", [])
				t.ok(listed.has(variant) or variant in HdPlaceholder.MOODS, "%s variant %s is listed or a mood" % [bid, variant])
		var used_in_ok := false
		for b in bg_rows:
			if sid in bgs.get(str(b.get("id", "")), {}).get("used_in", []):
				used_in_ok = true
		t.ok(used_in_ok, sid + " uses a background the art list made for it")
		for c in spec.get("cast", []):
			t.ok(chars.has(str(c.get("who", ""))), "%s cast %s is known" % [sid, c.get("who")])
			t.ok(str(c.get("at", "")) in Data.POSITIONS, "%s cast position %s" % [sid, c.get("at")])
		var speaker := str(s.get("speaker", ""))
		var on_stage := (spec.get("cast", []) as Array).any(func(c: Dictionary) -> bool: return str(c["who"]) == speaker)
		for key in spec.get("enter", {}):
			for c in spec["enter"][key]:
				on_stage = on_stage or str(c.get("who", "")) == speaker
		t.ok(on_stage, "%s puts its speaker %s on stage" % [sid, speaker])
		for field in ["enter", "exit", "expr"]:
			var table: Dictionary = spec.get(field, {})
			for key in table:
				t.ok(str(key).is_valid_int() and int(key) >= 0 and int(key) < n, "%s %s paragraph %s exists" % [sid, field, key])
				var rows = table[key]
				if field == "enter":
					for c in rows:
						t.ok(chars.has(str(c.get("who", ""))) and str(c.get("at", "")) in Data.POSITIONS, "%s enter row %s" % [sid, c])
				elif field == "exit":
					for who in rows:
						t.ok(chars.has(str(who)), "%s exit %s is known" % [sid, who])
				else:
					for who in rows:
						t.ok(chars.has(str(who)), "%s expr for %s is known" % [sid, who])
						t.ok(str(rows[who]) in Data.EXPRS, "%s expr %s is a known expression" % [sid, rows[who]])
	t.eq(Data.EXPRS, HdArt.data().get("kinds", {}).get("chara", {}).get("exprs", []), "VN expressions match the art list")


## The full book shares one cast table; every authored scene/event has usable staging.
func _test_formal_cast() -> void:
	var chars := Data.chars()
	var aliases := {}
	var art_ids := {}
	var background_ids := {}
	for art in HdArt.assets("chara"):
		art_ids[str(art["id"])] = true
	for art in HdArt.assets("bg"):
		background_ids[str(art["id"])] = true
	for id in chars:
		var row: Dictionary = chars[id]
		t.ok(not row.get("aliases", []).is_empty(), "shared cast aliases: " + str(id))
		t.ok(art_ids.has(Data.art_id(str(id))) or bool(row.get("placeholder_only", false)), "shared cast art: " + str(id))
		for alias in row.get("aliases", []):
			t.ok(not aliases.has(str(alias)) or str(aliases[alias]) == str(id), "shared alias has one speaker: " + str(alias))
			aliases[str(alias)] = str(id)
	var book := _read_definition(BOOK)
	var rows: Array = []
	for seg in book.get("segments", {}):
		var part: Dictionary = book["segments"][seg]
		var definition := _read_definition(str(part.get("file", "")))
		for character in definition.get("characters", []):
			t.ok(chars.has(str(character.get("id", ""))), "formal character is mapped: %s/%s" % [seg, character.get("id", "")])
		rows.append_array(definition.get("scenes", []))
		rows.append_array(definition.get("events", []))
		if str(part.get("events", "")) != "":
			rows.append_array(_read_definition(str(part["events"])).get("events", []))
	rows.append_array(_read_definition(str(book.get("events_common", ""))).get("events", []))
	t.ok(rows.size() > ROUTE.size(), "formal book contributes scenes and events beyond the old ocean route")
	for row in rows:
		var sid := str(row.get("id", ""))
		var speaker := str(row.get("speaker", ""))
		t.ok(speaker == "" or chars.has(speaker), sid + " speaker is mapped")
		var spec := Data.scene(sid)
		t.ok(not spec.is_empty(), sid + " has formal staging")
		var backgrounds: Array = spec.get("bg", [])
		t.ok(not backgrounds.is_empty(), sid + " has a usable background")
		for background in backgrounds:
			t.ok(background_ids.has(str(background.get("id", ""))), sid + " background resolves to registered art")
		var cast_rows: Array = spec.get("cast", [])
		t.ok(cast_rows.size() <= Data.max_on_stage(), sid + " fits the stage")
		for actor in cast_rows:
			t.ok(chars.has(str(actor.get("who", ""))) and str(actor.get("at", "")) in Data.POSITIONS, sid + " actor has a valid place")
		for id in spec.get("art", {}):
			t.ok(chars.has(str(id)) and art_ids.has(str(spec["art"][id])), sid + " art override uses an existing placeholder")
		var lines := VnScript.build(sid, PackedStringArray(row.get("body", [])))
		t.ok(not lines.is_empty(), sid + " prose builds into VN lines")
		for line in lines:
			if str(line.get("kind", "")) == "say":
				t.ok(chars.has(str(line.get("who", ""))), sid + " dialogue resolves its speaker")


func _read_definition(path: String) -> Dictionary:
	t.ok(path != "" and FileAccess.file_exists(path), "formal VN input exists: " + path)
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	t.ok(typeof(data) == TYPE_DICTIONARY, "formal VN input is an object: " + path)
	return data if typeof(data) == TYPE_DICTIONARY else {}


func _test_ui_data() -> void:
	var src := ""
	for f in DirAccess.get_files_at(VN_DIR):
		if f.ends_with(".gd"):
			src += FileAccess.get_file_as_string(VN_DIR + "/" + f)
	var re := RegEx.create_from_string("Data\\.text\\(\"([a-z_]+)\"")
	var keys := {}
	for m in re.search_all(src):
		keys[m.get_string(1)] = true
	t.ok(keys.size() >= 20, "VN code reads its words from vn_ui.json (%d keys)" % keys.size())
	for k in keys:
		t.ok(Data.text(str(k)) != "", "vn_ui.json has text." + str(k))
	for code in ["missing_clue", "missing_flag", "missing_item", "insufficient_funds", "already_used", "bad_phase"]:
		t.ok(Data.reason(code, {"needs": "x"}) != "", "vn_ui.json explains reason " + code)
	t.ok(Data.text("zz_missing") == "", "a missing UI key is empty, never the key name")
	t.eq(Data.text("date", {"y": 1815, "m": 8, "d": 4}).contains("1815"), true, "date format fills its numbers")


# ================================================================ 拆句

func _test_lines() -> void:
	var a := VnScript.paragraph("玛丽：“是蒙托隆将军让我带出来的。陛下用了总督府送来的糖和酒，疼得厉害。”你把可疑的布片收进补给栈的后间，决定先查验证据，再安排药品。", 1)
	t.eq(a.size(), 2, "speaker line plus remainder narration")
	if a.size() == 2:
		t.eq([a[0]["kind"], a[0]["who"], a[0]["name"]], ["say", "marie", "玛丽"], "Marie speaks")
		t.eq(a[0]["text"], "是蒙托隆将军让我带出来的。陛下用了总督府送来的糖和酒，疼得厉害。", "only the quoted words are spoken")
		t.eq([a[1]["kind"], a[1]["who"], a[1]["text"]], ["narr", "", "你把可疑的布片收进补给栈的后间，决定先查验证据，再安排药品。"], "the rest is narration")
		t.eq([a[0]["para"], a[1]["para"]], [1, 1], "lines remember their paragraph")
	var b := VnScript.paragraph(_paras("scene04")[1])
	t.eq(b.map(func(l: Dictionary) -> String: return str(l["who"])), ["dantes", "villefort"], "a reply after a quote (答道) is the next speaker")
	if b.size() == 2:
		t.eq(b[1]["text"], "我守在这块火山岩上，替皇帝看管最后一口铁箱。", "the reply keeps its words")
	var c := VnScript.paragraph(_paras("prologue")[3])
	t.eq(c.size(), 1, "a pure quote paragraph is one line")
	if c.size() == 1:
		t.eq([c[0]["kind"], c[0]["who"]], ["say", "villefort"], "the protagonist speaks the prologue's last line")
	var d := VnScript.paragraph(_paras("prologue")[1])
	t.eq(d.size(), 1, "a paragraph with a quote in the middle stays narration")
	if d.size() == 1:
		t.eq(d[0]["kind"], "narr", "mid-paragraph quote is narration")
		t.ok(not d[0].has("focus"), "narration not opening with a name lights nobody")
	var e := VnScript.paragraph(_paras("scene06")[1])
	t.eq(e.size(), 1, "name + action + quote is one narration line")
	if e.size() == 1:
		t.eq([e[0]["kind"], e[0].get("focus", "")], ["narr", "villefort"], "an action quote lights its speaker")
	var f := VnScript.paragraph(_paras("scene01")[0])
	t.eq([f.size(), f[0]["kind"], f[0].has("focus")], [1, "narr", false], "a name inside narration is not a speaker")
	var g := VnScript.paragraph("玛丽·朗热夫人冒雨送来旧亚麻布。")
	t.eq(g[0]["kind"], "narr", "a long alias without a colon is narration")
	t.eq(VnScript.speaker("唐泰斯：“没有收尾的引号").is_empty(), true, "an unclosed quote is not a spoken line")
	t.eq(VnScript.speaker("拿破仑：“”").is_empty(), true, "an empty quote is not a spoken line")
	t.eq(VnScript.speaker("蒙托隆转述：“船票。”")["who"], "montholon", "say verbs between name and colon")
	t.eq(VnScript.speaker("尼摩船长：「深海。」")["text"], "深海。", "corner quotes work too")
	# 长句切块：每块不超过上限，拼回去一字不差
	var long := ""
	for i in 12:
		long += "这是第%d句比较长的叙述，用来检验按句号切开的规则。" % i
	var parts := VnScript.chunk(long, 60)
	t.ok(parts.size() > 1, "a long line is split")
	t.eq("".join(parts), long, "splitting keeps every character")
	t.ok(Array(parts).all(func(p: String) -> bool: return p.length() <= 60), "every chunk fits the limit")
	var hard := VnScript.chunk("甲".repeat(130), 50)
	t.eq(Array(hard).map(func(p: String) -> int: return p.length()), [50, 50, 30], "a sentence without stops is hard-cut")


func _test_scene_scripts() -> void:
	for s in _scenes():
		var sid := str(s["id"])
		var paras := _paras(sid)
		var lines := VnScript.build(sid, paras)
		t.ok(lines.size() >= paras.size(), sid + " has at least one line per paragraph")
		# 不丢字：每段拆出来的句子拼起来，正好是原段落去掉“叫法（说道）：“”和”这几个字
		for i in paras.size():
			var mine := lines.filter(func(l: Dictionary) -> bool: return int(l["para"]) == i)
			t.ok(not mine.is_empty(), "%s paragraph %d has lines" % [sid, i])
			var covered := 0
			for l in mine:
				t.ok(paras[i].contains(str(l["text"])), "%s line text comes from paragraph %d" % [sid, i])
				covered += str(l["text"]).length()
			var said := mine.filter(func(l: Dictionary) -> bool: return l["kind"] == "say").size()
			t.ok(covered <= paras[i].length() and covered >= paras[i].length() - said * 12,
				"%s paragraph %d keeps its prose (%d of %d chars)" % [sid, i, covered, paras[i].length()])
			if i > 0:
				var spec := VnScript.directions(Data.scene(sid), i)
				if not spec.is_empty():
					t.eq(mine[0].get("dir", {}), spec, "%s paragraph %d carries its stage directions" % [sid, i])
		var op := VnScript.opening(sid)
		t.ok(str(op.get("bg", {}).get("id", "")) != "", sid + " opening background")
	t.eq(VnScript.choices_bg("scene03").get("id"), "shop_back_room", "scene03 moves to the back room for the choices")
	t.eq(VnScript.opening("scene03")["bg"]["id"], "royal_oak_tavern", "scene03 opens in the tavern")
	var s05 := VnScript.build("scene05", _paras("scene05"))
	var bg_line := s05.filter(func(l: Dictionary) -> bool: return l.has("dir") and l["dir"].has("bg"))
	t.ok(not bg_line.is_empty() and str(bg_line[0]["dir"]["bg"]["id"]) == "sea_cave", "scene05 switches to the sea cave mid-scene")
	t.eq(VnScript.opening("scene10")["bg"], {"id": "new_elba_shoal", "variant": "night"}, "scene10 opens on the night sea")


## scripts/cards/ui/vn/ 守仓库规矩：没有 class_name、没有颜色字面量、字符串字面量只有 ASCII、用到的 hd_* 键都在 palette.dev.json
func _test_house_rules() -> void:
	var palette = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_DEV))
	var colors: Dictionary = palette.get("colors", {}) if typeof(palette) == TYPE_DICTIONARY else {}
	var files := DirAccess.get_files_at(VN_DIR)
	var n := 0
	for f in files:
		if not f.ends_with(".gd"):
			continue
		n += 1
		var path := VN_DIR + "/" + f
		var src := FileAccess.get_file_as_string(path)
		var code := _strip_comments(src)
		t.ok(RegEx.create_from_string("(?m)^class_name\\s").search(code) == null, f + ": no class_name")
		t.ok(RegEx.create_from_string("Color\\s*\\(|Color8\\s*\\(|Color\\.html|Color\\.from_").search(code) == null, f + ": no colour literals")
		for lit in _strings(src):
			var ascii := true
			for i in lit.length():
				if lit.unicode_at(i) > 127:
					ascii = false
			t.ok(ascii, "%s: ASCII string literal '%s'" % [f, lit])
			if lit.begins_with("hd_") and RegEx.create_from_string("^hd_[a-z0-9_]+$").search(lit) != null:
				t.ok(colors.has(lit), "%s: palette key %s exists" % [f, lit])
	t.ok(n >= 5, "VN scripts are there (%d)" % n)


func _strip_comments(src: String) -> String:
	var out := ""
	var in_str := false
	var i := 0
	while i < src.length():
		var c := src.unicode_at(i)
		if in_str and c == 92:
			out += src.substr(i, 2)
			i += 2
			continue
		if c == 34:
			in_str = not in_str
		if c == 35 and not in_str:
			while i < src.length() and src.unicode_at(i) != 10:
				i += 1
			continue
		out += src.substr(i, 1)
		i += 1
	return out


func _strings(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for m in re.search_all(_strip_comments(src)):
		out.append(m.get_string(1))
	return out


# ================================================================ 面板

func _engine() -> CardEngine:
	var engine := CardEngine.new(_bus)
	t.ok(engine.new_game({"campaign": "ocean_pawn", "seed": 1815, "save_dir": t.user_dir() + "/ocean"}).get("ok", false), "engine starts the ocean campaign")
	_to_day(engine)
	return engine


func _to_day(engine: CardEngine) -> void:
	for _i in range(6):
		var phase := str(engine.view().get("phase", ""))
		if phase in ["day", "game_over"]:
			return
		engine.send(&"campaign.wait", {})
	t.eq(engine.view().get("phase"), "day", "engine reaches the day")


func _open(engine: CardEngine, scene_id: String, fast: bool) -> Control:
	var p: Control = load(PANEL).new()
	p.set("fast", fast)
	root.add_child(p)
	p.call("bind", engine, _bus)
	_closed_with = []
	p.connect("close_requested", func(r: Dictionary) -> void: _closed_with.append(r))
	p.call("open", {"uid": "story:" + scene_id})
	await t.frames(1)
	return p


func _drop(p: Control) -> void:
	if p != null and is_instance_valid(p):
		p.queue_free()
	await t.frames(2)


func _button(p: Control, id: String) -> Button:
	for b in _walk(p):
		if b is Button and str(b.get_meta("reply_id", "")) == id and b.is_visible_in_tree():
			return b
	return null


func _test_prologue_flow() -> void:
	var engine := _engine()
	var p := await _open(engine, "prologue", false)
	t.ok(p.is_visible_in_tree(), "VN panel is on screen")
	t.ok(p.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "VN root uses linear filtering with mipmaps")
	t.eq(p.call("state"), "title", "a new scene opens on its title card")
	var text := _visible_text(p)
	t.ok(text.contains("序曲：贝勒罗丰号的双面怀表"), "title card shows the scene title")
	t.ok(text.contains("1815年8月4日"), "title card shows the date")
	t.ok(text.contains("贝勒罗丰号底舱"), "title card shows the location")
	# 序曲的“部”和场次标题是同一句话：章节卡只写大标题，不再重复一行小字
	t.ok(not text.contains("序曲·贝勒罗丰号的双面怀表"), "prologue title card does not repeat the chapter line")
	var bg := p.find_child("Bg_bellerophon_hold", true, false)
	t.ok(bg != null, "prologue background is the Bellerophon hold")
	var stage: Control = p.call("vn_stage")
	t.eq(stage.call("actor_ids"), [], "the stage is empty under the title card")
	# 打字机：点一下先出全句，再点下一句
	p.call("advance")
	t.eq(p.call("state"), "line", "a click ends the title card")
	# 第 0 段是“你是埃德蒙·德·维尔福……”的旁白：台上空着，免得把蒙托隆当成“你”；第 1 段他才上台
	t.eq(stage.call("actor_ids"), [], "the framing narration plays on an empty stage")
	t.ok(bool(p.call("is_typing")), "the first line types out")
	var first: Dictionary = p.call("current_line")
	p.call("advance")
	t.ok(not bool(p.call("is_typing")), "a click completes the line")
	t.eq(p.call("current_line"), first, "completing does not skip the line")
	var label := p.find_child("Line", true, false) as Label
	t.ok(label != null and label.visible_characters == -1 and label.text == str(first["text"]), "the whole line is visible")
	var arrow := p.find_child("Next", true, false) as Control
	t.ok(arrow != null and arrow.visible, "the advance arrow shows when the line is complete")
	p.call("advance")
	t.ok(p.call("current_line") != first, "the next click shows the next line")
	for _i in range(12):
		if int(p.call("current_line").get("para", 0)) >= 1:
			break
		p.call("advance")
		p.call("advance")
	t.eq(stage.call("actor_ids"), ["montholon"], "Montholon steps on stage when he puts the watch on the counter")
	var chip := stage.find_child("NameChip", true, false) as Control
	t.ok(chip != null and _visible_text(chip).contains("蒙托隆"), "placeholder actors wear a name chip at shoulder height")
	if chip != null:
		# 名字牌在占位剪影的下巴（画布 y≈507）以下，挂在肩线上，不压脸
		var holder := chip.get_parent() as Control
		var mid := chip.position.y + chip.size.y * 0.5
		t.ok(mid > holder.size.y * 560.0 / 1800.0 and mid < holder.size.y * 680.0 / 1800.0, "the name chip sits on the shoulder line, not the face")
	# 打字机按时间走：40 字每秒左右
	var before := label.visible_characters
	p.call("_process", 0.25)
	t.ok(label.visible_characters >= before + 8 and label.visible_characters <= before + 12, "typewriter runs at about 40 chars/s")
	# 空格键 = 点一下
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	p.call("_unhandled_input", key)
	t.ok(not bool(p.call("is_typing")), "Space completes the line")
	# 自动：读完自己接下一句
	p.call("set_auto", true)
	t.ok(bool(p.call("is_auto")), "auto mode on")
	var at := str(p.call("current_line").get("text", ""))
	p.call("_process", 30.0)
	t.ok(str(p.call("current_line").get("text", "")) != at, "auto mode advances by itself")
	p.call("set_auto", false)
	# 两个人在台上：说话的人亮、另一个暗
	var l3: Dictionary = p.call("current_line")
	while str(l3.get("who", "")) != "villefort" and str(p.call("state")) == "line":
		p.call("advance")
		p.call("advance")
		l3 = p.call("current_line")
	t.eq(str(l3.get("who", "")), "villefort", "the protagonist speaks in the prologue")
	t.eq(stage.call("actor_ids"), ["villefort", "montholon"], "the protagonist enters on the left")
	t.eq(stage.call("focused"), "villefort", "the speaker is lit")
	await create_timer(0.6).timeout
	var vil := (stage.call("actor_node", "villefort") as Control).get_parent() as Control
	var mon := (stage.call("actor_node", "montholon") as Control).get_parent() as Control
	t.ok(vil.modulate.r > mon.modulate.r + 0.2, "the listener is dimmed")
	t.ok(vil.scale.x > mon.scale.x, "the listener is slightly smaller")
	var plate := p.find_child("NamePlate", true, false) as Control
	t.ok(plate != null and plate.visible and _visible_text(plate).contains("维尔福"), "the name plate shows the speaker")
	t.eq(stage.call("expr_of", "montholon"), "normal", "expression hints apply (montholon back to normal)")
	# 记录
	p.call("open_log")
	t.ok(bool(p.call("is_log_open")), "backlog opens")
	t.ok(not (p.find_child("Top", false, false) as Control).visible, "the top bar steps aside while the backlog is open")
	t.ok(not (stage.find_child("NameChip", true, false) as Control).visible, "name chips hide under the backlog")
	var log: Array = p.call("log_entries")
	t.ok(log.size() >= 4, "backlog holds every line so far (%d)" % log.size())
	t.ok(log.any(func(r: Dictionary) -> bool: return str(r["name"]) == "维尔福" and str(r["text"]).contains("大军团的账簿")), "backlog names the speaker")
	t.ok(str(log[0]["text"]).contains("架空历史"), "backlog starts from the first line")
	var log_text := _visible_text(p.find_child("LogList", true, false))
	t.ok(log_text.contains("架空历史") and log_text.contains("大军团的账簿"), "backlog overlay lists past lines")
	p.call("dismiss")
	t.ok(not bool(p.call("is_log_open")) and _closed_with.is_empty(), "Esc closes the backlog first, not the panel")
	# 隐藏
	p.call("set_hidden", true)
	t.ok(bool(p.call("is_hidden")) and not (p.find_child("Ui", false, false) as Control).visible, "hide removes the text box")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	p.call("_gui_input", click)
	t.ok(not bool(p.call("is_hidden")) and (p.find_child("Ui", false, false) as Control).visible, "any click restores the UI")
	t.eq(str(p.call("current_line").get("who", "")), "villefort", "the restoring click does not advance")
	# 快进：一路到抉择，然后自己停
	p.call("set_skip", true)
	for _i in range(60):
		if str(p.call("state")) == "choices":
			break
		p.call("_process", 0.1)
	t.eq(p.call("state"), "choices", "skip runs to the choice menu")
	t.ok(not bool(p.call("is_skipping")), "skip stops at the choice menu")
	await t.frames(2)
	var chips_on := (stage.find_children("NameChip", "", true, false) as Array).filter(func(c: Node) -> bool: return (c as CanvasItem).visible)
	t.eq(chips_on.size(), 0, "no ghost name chips behind the choice menu")
	# 抉择菜单：鉴定和决定都是选项，灰的写原因
	var buttons: Array = p.call("choice_buttons")
	var ids: Array = buttons.map(func(b: Button) -> String: return str(b.get_meta("reply_id")))
	t.eq(ids.filter(func(x: String) -> bool: return x.begins_with("action:appraise:")).size(), 4, "four appraisals are choices")
	t.ok(ids.has("action:choose:secure_passage") and ids.has("action:choose:buy_passage"), "both decisions are choices")
	t.ok(_button(p, "later") != null, "the menu keeps the later choice")
	# 抉择时顶栏画在压暗层上面：真鼠标点“记录”照样打开记录；右边写着账面（金库、同盟威望……）
	var log_btn := p.find_child("BtnLog", true, false) as Button
	t.ok(log_btn != null and log_btn.is_visible_in_tree() and not log_btn.disabled, "the log button stays live while choosing")
	if log_btn != null:
		var click_at := log_btn.get_global_rect().get_center()
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = click_at
			ev.global_position = click_at
			root.push_input(ev, true)
		await t.frames(1)
		t.ok(bool(p.call("is_log_open")), "a real click on the log button opens the backlog during the choice menu")
		p.call("close_log")
	var hide_btn := p.find_child("BtnHide", true, false) as Button
	t.ok(hide_btn != null and not hide_btn.disabled, "hide stays live while choosing")
	var gauges := p.find_child("Gauges", true, false) as Control
	var gtext := _visible_text(gauges) if gauges != null else ""
	t.ok(gauges != null and gauges.is_visible_in_tree() and gtext.contains("军费") and gtext.contains("同盟威望") and gtext.contains("敌方警戒"),
		"the choice menu shows the treasury and gauges: " + gtext.replace("\n", " "))
	var locked := _button(p, "action:choose:secure_passage")
	t.ok(locked != null and locked.disabled, "the evidence choice is locked before appraisal")
	var reason := locked.find_child("Reason", false, false) as Label if locked != null else null
	t.ok(reason != null and reason.text.contains("察看 VI 刻度与内圈刻字") and reason.text.contains("破译夹层里的半封信"),
		"its reason names the missing appraisals: " + (reason.text if reason != null else "?"))
	var waiting := _button(p, "action:choose:buy_passage")
	var wr := waiting.find_child("Reason", false, false) as Label if waiting != null else null
	t.ok(waiting != null and waiting.disabled and wr != null and wr.text == CardText.ui("ocean.reason.battle"),
		"the other decision waits for the battle")
	t.ok(locked != null and locked.text == "查明夹层，留下密信，用金表圈换随行名额", "choice shows its authored label")
	# 鉴定 -> 观察结果 -> 回到菜单
	var app := _button(p, "action:appraise:watch_mark")
	app.pressed.emit()
	t.eq(p.call("state"), "line", "an appraisal plays its observation")
	var obs: Dictionary = p.call("current_line")
	t.eq(obs.get("kind"), "clue", "the observation is a clue line")
	t.ok(str(obs.get("text", "")).contains("C. S. — 1498"), "the observation text is shown")
	t.ok(str(obs.get("name", "")).contains("察看 VI 刻度与内圈刻字"), "the plate names the appraisal")
	p.call("advance")
	p.call("advance")
	t.eq(p.call("state"), "choices", "after the observation the menu returns")
	t.ok(_button(p, "action:appraise:watch_mark") == null, "a finished appraisal leaves the menu")
	await t.frames(2)
	t.ok(_visible_text(p.find_child("Clues", true, false)).contains("C. S. — 1498"), "the clue panel lists the observation")
	for aid in ["watch_weight", "watch_ring", "faria_letter"]:
		var b := _button(p, "action:appraise:" + aid)
		t.ok(b != null and not b.disabled, "appraisal %s is available" % aid)
		if b != null:
			b.pressed.emit()
			p.call("skip_all")
	t.eq(p.call("state"), "choices", "all appraisals done, back on the menu")
	var still := _button(p, "action:choose:secure_passage")
	var still_reason := still.find_child("Reason", false, false) as Label if still != null else null
	t.ok(still != null and still.disabled and still_reason != null and still_reason.text == CardText.ui("ocean.reason.battle"),
		"with the evidence in hand the choice now only waits for the battle")
	# 稍后 = 关面板（不发指令）
	var count := engine.command_log().size()
	_button(p, "later").pressed.emit()
	t.eq(_closed_with, [{}], "later closes the panel with no follow-up")
	t.eq(engine.command_log().size(), count, "later sends no command")
	await _drop(p)
	# 重开：看过的场次直接到菜单，记录里有全文
	for c in SKIP_BATTLE:
		t.ok(engine.send(StringName(c[0]), c[1]).get("ok", false), "engine settles the prologue battle: " + c[0])
	p = await _open(engine, "prologue", false)
	t.eq(p.call("state"), "choices", "a seen scene reopens on its choices")
	t.ok((p.call("log_entries") as Array).size() >= 8, "reopened backlog holds the whole scene")
	t.ok((p.call("log_entries") as Array).any(func(r: Dictionary) -> bool: return str(r["kind"]) == "clue"), "reopened backlog holds the appraised clues")
	# 作出决定 -> 结算 -> 关掉
	var go := _button(p, "action:choose:secure_passage")
	t.ok(go != null and not go.disabled, "the evidence choice is open after the battle")
	var morale := _gauge(engine, "morale")
	go.pressed.emit()
	t.eq(engine.command_log().back(), ["card.choose", {"uid": "story:prologue", "choice": "action:choose:secure_passage"}],
		"the decision goes through card.choose")
	t.eq(_gauge(engine, "morale"), morale + 5, "the decision's effect is applied by the engine")
	t.eq(p.call("current_line").get("kind"), "pick", "the decision is echoed")
	t.ok(bool(p.call("is_typing")), "the echo types out too")
	p.call("advance")
	p.call("advance")
	var res: Dictionary = p.call("current_line")
	t.eq(res.get("kind"), "result", "then the outcome")
	t.ok(str(res.get("text", "")).contains("同盟威望 +5"), "the outcome lists the effects: " + str(res.get("text", "")))
	t.ok(str(res.get("text", "")).contains("怀表"), "the outcome lists the item taken in")
	p.call("set_skip", true)
	for _i in range(20):
		p.call("_process", 0.1)
	t.eq(_closed_with, [], "skip never closes the panel by itself")
	var rest: Array = (p.call("lines") as Array).slice((p.call("lines") as Array).size() - 3)
	t.ok(rest.any(func(l: Dictionary) -> bool: return str(l.get("text", "")).contains("第一部")), "the outcome names the next part")
	t.ok(rest.any(func(l: Dictionary) -> bool: return str(l.get("text", "")).contains("詹姆斯敦的雨水")), "the outcome names the next scene")
	p.call("set_skip", false)
	for _i in range(6):
		if not _closed_with.is_empty():
			break
		p.call("advance")
	t.eq(_closed_with, [{}], "the last click after the outcome closes the panel")
	await _drop(p)


func _gauge(engine: CardEngine, id: String) -> int:
	for g in engine.query(&"campaign").get("gauges", []):
		if str(g["id"]) == id:
			return int(g["amount"])
	return -1


## 14 场都经由 VN：打开（章节卡、台词）、鉴定、作出决定、结算、关掉，一路到结局
func _test_full_route() -> void:
	var engine := _engine()
	var opened := 0
	for step in ROUTE:
		var sid := str(step[0])
		_to_day(engine)
		t.eq(engine.query(&"campaign").get("scene_id"), sid, "route reaches " + sid)
		if str(engine.query(&"campaign").get("scene_id", "")) != sid:
			return
		if sid == "scene01":
			for c in [["campaign.visit", {"place": "town"}], ["campaign.demand", {"id": "medicine", "action": "fulfill"}],
					["campaign.demand", {"id": "bond", "action": "fulfill"}]]:
				t.ok(engine.send(StringName(c[0]), c[1]).get("ok", false), "scene01 side command " + str(c[0]))
		# 第十一、十二场：仗还没打时决定全是灰的（每行多一行原因），菜单最高；先这样打开看菜单放不放得下
		var late_battle := sid in ["scene11", "scene12"]
		if not late_battle:
			for c in SKIP_BATTLE:
				engine.send(StringName(c[0]), c[1])
		var p := await _open(engine, sid, true)
		opened += 1
		t.eq(p.call("state"), "line", sid + " starts on its first line in fast mode")
		var spec := Data.scene(sid)
		var bg0 := str(spec["bg"][0]["id"])
		t.ok(p.find_child("Bg_" + bg0, true, false) != null, "%s opens on background %s" % [sid, bg0])
		var first: Dictionary = p.call("current_line")
		t.ok(str(first.get("text", "")) != "", sid + " first line has text")
		p.call("skip_all")
		t.eq(p.call("state"), "choices", sid + " reaches its choices")
		if late_battle:
			await t.frames(2)
			var menu := p.find_child("Menu", true, false) as Control
			var later := _button(p, "later")
			var mr := menu.get_global_rect() if menu != null else Rect2()
			t.ok(menu != null and mr.position.y >= 56.0 and mr.end.y <= 720.0,
				"%s: the whole choice menu fits on screen before the battle (%s)" % [sid, str(mr)])
			t.ok(later != null and later.is_visible_in_tree() and later.get_global_rect().end.y <= 716.0,
				sid + ": later / replay stay on screen")
			for c in SKIP_BATTLE:
				engine.send(StringName(c[0]), c[1])
			p.refresh(engine.view())
			await t.frames(2)
		var stage: Control = p.call("vn_stage")
		t.ok((stage.call("actor_ids") as Array).size() <= 3, sid + " keeps at most three on stage")
		t.ok((stage.call("actor_ids") as Array).size() >= 1, sid + " has somebody on stage")
		var cbg := VnScript.choices_bg(sid)
		if not cbg.is_empty():
			t.ok(p.find_child("Bg_" + str(cbg["id"]), true, false) != null, sid + " switches background for the choices")
		var apps: Array = (p.call("choice_buttons") as Array).filter(
			func(b: Button) -> bool: return str(b.get_meta("reply_id")).begins_with("action:appraise:"))
		for b in apps:
			var id := str(b.get_meta("reply_id"))
			var again := _button(p, id)
			if again == null:
				continue
			again.pressed.emit()
			t.eq(str(p.call("current_line").get("kind", "")), "clue", sid + " appraisal shows an observation " + id)
			p.call("skip_all")
			t.eq(p.call("state"), "choices", sid + " appraisal returns to the menu " + id)
		var pick := _button(p, "action:choose:" + str(step[1]))
		t.ok(pick != null and not pick.disabled, "%s decision %s is open" % [sid, step[1]])
		if pick == null or pick.disabled:
			print("OCEAN VN REASONS " + str((p.call("choice_buttons") as Array).map(
				func(b: Button) -> String: return str(b.get_meta("reply_id")) + "=" + str(b.disabled))))
			await _drop(p)
			return
		pick.pressed.emit()
		t.eq(str(p.call("current_line").get("kind", "")), "pick", sid + " echoes the decision")
		for _i in range(8):
			if not _closed_with.is_empty():
				break
			p.call("advance")
		t.eq(_closed_with, [{}], sid + " closes after the outcome")
		await _drop(p)
	t.eq(opened, ROUTE.size(), "every scene opened through the VN")
	t.eq(engine.view().get("phase"), "game_over", "the VN route reaches an ending")
	t.no_leaks(engine.view(), "VN route view")


## 不推进剧情的决定（一次性的暗账）：放完结算回到菜单，这一项不能再选
func _test_side_decision() -> void:
	var engine := CardEngine.new(_bus)
	t.ok(engine.new_game({"campaign": "ocean_pawn", "seed": 1815, "save_dir": t.user_dir() + "/ocean3", "stage": 3}).get("ok", false), "engine starts at the nautilus part")
	_to_day(engine)
	t.eq(engine.query(&"campaign").get("scene_id"), "scene10", "the nautilus part opens on scene10")
	var p := await _open(engine, "scene10", true)
	t.ok(p.find_child("Bg_new_elba_shoal", true, false) != null, "scene10 opens on the shoal at night")
	p.call("skip_all")
	t.ok(p.find_child("Bg_nautilus_cabin", true, false) != null, "scene10 moves into the cabin")
	var side := _button(p, "action:choose:theft_treasure")
	t.ok(side != null and not side.disabled, "the one-time side decision is open before the battle")
	if side == null:
		await _drop(p)
		return
	side.pressed.emit()
	t.eq(str(p.call("current_line").get("kind", "")), "pick", "the side decision is echoed")
	p.call("advance")
	t.eq(str(p.call("current_line").get("kind", "")), "result", "its effects are shown")
	p.call("advance")
	t.eq(p.call("state"), "choices", "a decision that keeps the scene returns to the menu")
	t.eq(_closed_with, [], "and does not close the panel")
	var again := _button(p, "action:choose:theft_treasure")
	t.ok(again == null or again.disabled, "the one-time decision cannot be taken twice")
	if again != null:
		var why := again.find_child("Reason", false, false) as Label
		t.ok(why != null and why.text == Data.reason("already_used"), "its reason says it was done")
	await _drop(p)


## 存档读档：VN 只读引擎，读档后的新引擎打开同一场，已鉴定的线索照样在
func _test_save_load() -> void:
	var engine := _engine()
	for c in SKIP_BATTLE:
		engine.send(StringName(c[0]), c[1])
	t.ok(engine.send(&"card.choose", {"uid": "story:prologue", "choice": "action:appraise:watch_ring"}).get("ok", false), "appraise before saving")
	var path: String = t.user_dir() + "/vn_save.json"
	t.ok(engine.save_game(path).get("ok", false), "save mid scene")
	var loaded := CardEngine.new(_bus)
	t.ok(loaded.load_game(path).get("ok", false), "load into a new engine")
	var p := await _open(loaded, "prologue", true)
	p.call("skip_all")
	t.eq(p.call("state"), "choices", "loaded scene reaches its choices")
	t.ok(_button(p, "action:appraise:watch_ring") == null, "the saved appraisal is not offered again")
	t.ok(_visible_text(p.find_child("Clues", true, false)).contains("底盖中央发闷"), "the saved clue is listed after loading")
	t.ok((p.call("lines") as Array).any(func(l: Dictionary) -> bool: return str(l.get("kind", "")) == "clue"), "the saved clue is replayed as a line")
	p.call("dismiss")
	t.eq(_closed_with, [{}], "dismiss on the menu closes the panel")
	await _drop(p)


# ================================================================ 小工具

func _visible_text(node: Node) -> String:
	if node == null:
		return ""
	var texts := PackedStringArray()
	for child in _walk(node):
		if child is CanvasItem and not child.is_visible_in_tree():
			continue
		if child is Label or child is Button:
			texts.append(str(child.text))
	return "\n".join(texts)


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for child in node.get_children():
		out.append_array(_walk(child))
	return out
