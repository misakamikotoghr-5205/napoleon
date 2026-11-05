# 去当铺的防回潮测试 OCEAN_content（WORLD_MAP_DESIGN §12.3；C 写，A 把它加进远洋测试表）：
# 1. 数据：拿破仑 / 远洋线玩家看得见的数据（§12.3 的清单：ocean_pawn.json、ocean_battle.json 的 text 块、battle_ui.json、
#    data/campaigns/napoleon/**、data/campaigns/text/*.json、hub_ui / vn_ui / vn_cast / map_ui、art_list.json 每一项的 name 和 desc）
#    里 19 个当铺词一个都不许有；键以下划线开头的（_doc 之类）是写给人看的说明，不扫。
# 2. 脚本：ocean_rogue_data.gd 的字已经搬进 data/campaigns/text/ocean_rogue.json，它的字符串字面量不许再有中文，
#    每一行都要在那份 JSON 里有字；远洋线其余脚本（campaign、hub、vn、battle、hd、map 界面）的字符串字面量不许有当铺词。注释不扫。
# 3. 引擎：五条结局路线（golden/ocean_routes.json 的指令）逐步重放，每一步 ocean_view 产出的覆盖层、卡牌、选项、指标名都不许有当铺词。
# 4. 界面：真根场景开远洋战役。标题页没有「当」字；序曲 VN 的标题卡没有「天平」；营地主画面、营地事务面板、手册、暂停、设置、
#    信物、档案、出征名单、日终面板上看得见的字（含悬停提示）没有当铺词。
# 5. 窗口标题等于书名（§12.2 第 10 条，标题页与新局均由 card_game_root 设置）。
# 旧版 1938（data/cards/**、DEHOUDANG_CAMPAIGN=legacy）不扫。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const G = preload("res://scripts/tests/cards/OCEAN/golden_lib.gd")
const View = preload("res://scripts/cards/campaign/ocean_view.gd")
const RogueData = preload("res://scripts/cards/campaign/ocean_rogue_data.gd")

## §12.3 的词表（19 个）
const WORDS := ["当铺", "典当", "当票", "流当", "估值铺", "掌柜", "挂牌", "柜台", "活当", "收当", "盘库", "鉴定", "营业",
	"经营须知", "当物", "赎当", "押当", "典押", "账房先生"]
## 整份扫的数据文件；OPTIONAL 里的还没建（A2 的 map_ui.json），有了就扫
const DATA_FILES := ["res://data/campaigns/ocean_pawn.json", "res://data/campaigns/battle_ui.json",
	"res://data/hd/hub_ui.json", "res://data/hd/vn_ui.json", "res://data/hd/vn_cast.json"]
const OPTIONAL_FILES := ["res://data/hd/map_ui.json"]
## 整个目录递归扫（只看 .json）
const DATA_DIRS := ["res://data/campaigns/napoleon", "res://data/campaigns/text"]
const OCEAN_BATTLE := "res://data/campaigns/ocean_battle.json"
const ART_LIST := "res://data/hd/art_list.json"
const CAMPAIGN := "res://data/campaigns/ocean_pawn.json"
const OCEAN_UI := "res://data/campaigns/text/ocean_ui.json"
const ROGUE_DATA := "res://scripts/cards/campaign/ocean_rogue_data.gd"
const ROGUE_TEXT := "res://data/campaigns/text/ocean_rogue.json"
const SCRIPT_DIRS := ["res://scripts/cards/campaign", "res://scripts/cards/ui/hub", "res://scripts/cards/ui/vn",
	"res://scripts/cards/ui/battle", "res://scripts/cards/ui/hd", "res://scripts/cards/ui/map"]
const CAMP_CARDS := ["signage", "town", "backdoor", "resources", "march", "calendar", "squad", "status"]

var t
var game: CardGameRoot
var _old_campaign := ""
var _had_campaign := false
var _def: Dictionary = {}


func _initialize() -> void:
	_had_campaign = OS.has_environment("DEHOUDANG_CAMPAIGN")
	_old_campaign = OS.get_environment("DEHOUDANG_CAMPAIGN")
	OS.unset_environment("DEHOUDANG_CAMPAIGN")
	t = T.new(self, "OCEAN_content")
	CardText.set_show_drafts(false)
	t.run_async(_body)


func _body() -> void:
	var parsed = _json(CAMPAIGN)
	_def = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	t.ok(not _def.is_empty(), "ocean campaign definition loads")
	_test_data()
	_test_rogue_data()
	_test_scripts()
	_test_routes()
	await _test_screens()
	if game != null and is_instance_valid(game):
		game.queue_free()
		game = null
		await t.frames(4)
	if _had_campaign:
		OS.set_environment("DEHOUDANG_CAMPAIGN", _old_campaign)
	else:
		OS.unset_environment("DEHOUDANG_CAMPAIGN")


# ================================================================ 1. 数据

func _test_data() -> void:
	var files: Array = []
	for path in DATA_FILES:
		t.ok(FileAccess.file_exists(path), "scanned file exists: " + path)
		files.append(path)
	for path in OPTIONAL_FILES:
		if FileAccess.file_exists(path):
			files.append(path)
	for dir in DATA_DIRS:
		var found := _files(dir, ".json")
		t.ok(not found.is_empty(), "scanned folder has JSON: " + dir)
		files.append_array(found)
	t.ok(files.has(ROGUE_TEXT) and files.has(OCEAN_UI), "the moved ocean text files are in the scan")
	for path in files:
		var doc = _json(path)
		t.ok(doc != null, "parses: " + path)
		var hits: Array = []
		var n := _scan(doc, path.get_file(), hits)
		t.ok(n > 0, "%s has text to scan" % path)
		t.eq(hits, [], "no pawnshop words in " + path)
	var battle = _json(OCEAN_BATTLE)
	t.ok(typeof(battle) == TYPE_DICTIONARY and battle.has("text"), "ocean_battle.json has its text block")
	if typeof(battle) == TYPE_DICTIONARY:
		var hits: Array = []
		t.ok(_scan(battle.get("text", {}), "ocean_battle.json:text", hits) > 10, "ocean_battle text block scanned")
		t.eq(hits, [], "no pawnshop words in the ocean_battle.json text block")
	var art = _json(ART_LIST)
	var assets: Array = art.get("assets", []) if typeof(art) == TYPE_DICTIONARY else []
	t.ok(assets.size() > 50, "art list has its assets (%d)" % assets.size())
	var art_hits: Array = []
	for a in assets:
		var where := "art_list:%s/%s" % [a.get("kind", ""), a.get("id", "")]
		_scan(str(a.get("name", "")), where + ".name", art_hits)
		_scan(str(a.get("desc", "")), where + ".desc", art_hits)
	t.eq(art_hits, [], "no pawnshop words in art list names and descriptions")
	# 改名表里几处具体的落点（§12.1）
	t.ok(str(_def.get("title", "")).begins_with("远洋") and not str(_def.get("title", "")).contains("当"), "the single-segment book is called 远洋")
	var ui = _json(OCEAN_UI)
	var common: Dictionary = ui.get("common", {}) if typeof(ui) == TYPE_DICTIONARY else {}
	t.eq(str(common.get("c16.title.name", "")), "远洋", "the ocean title name")
	t.eq(str((ui.get("overlays", {}).get("ocean.rules", {}) as Dictionary).get("title", "")), "军需官手册", "the rules page is the quartermaster's manual")
	t.eq(ui.get("sign_names", {}), {"white": "白旗 · 照常行军", "red": "红旗 · 就地征发", "black": "黑旗 · 闭营清点"}, "the three camp flags")
	var endings := {}
	for e in _def.get("endings", []):
		endings[str(e.get("id", ""))] = str(e.get("title", ""))
	t.eq([endings.get("ghost", ""), endings.get("dark", "")], ["永不靠岸的幽灵舰队", "深海利维坦的财政官"], "ghost and dark endings renamed, ids kept")


## 字符串里的当铺词记进 hits（"位置: 词"），返回扫过的字符串数；键以 _ 开头的不扫
func _scan(v: Variant, where: String, hits: Array) -> int:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			for w in WORDS:
				if str(v).contains(w):
					hits.append("%s: %s" % [where, w])
			return 1
		TYPE_DICTIONARY:
			var n := 0
			for k in v:
				if str(k).begins_with("_"):
					continue
				n += _scan(v[k], "%s.%s" % [where, k], hits)
			return n
		TYPE_ARRAY:
			var n := 0
			for i in (v as Array).size():
				n += _scan(v[i], "%s[%d]" % [where, i], hits)
			return n
	return 0


# ================================================================ 2. 脚本

func _test_rogue_data() -> void:
	var src := FileAccess.get_file_as_string(ROGUE_DATA)
	t.ok(src.length() > 1000, "ocean_rogue_data.gd reads")
	var lits := _strings(src)
	t.ok(lits.size() > 50, "ocean_rogue_data.gd has its id literals (%d)" % lits.size())
	var cjk: Array = []
	for lit in lits:
		if _non_ascii(lit):
			cjk.append(lit)
	t.eq(cjk, [], "ocean_rogue_data.gd has no Chinese string literals (its text is in %s)" % ROGUE_TEXT)
	var text = _json(ROGUE_TEXT)
	t.ok(typeof(text) == TYPE_DICTIONARY, ROGUE_TEXT + " parses")
	if typeof(text) != TYPE_DICTIONARY:
		return
	var tables := {"coins": RogueData.COINS.values(), "props": RogueData.PROPS.values(), "bonds": RogueData.BONDS.values(),
		"companions": RogueData.COMPANIONS.values(), "march_board": RogueData.MARCH_BOARD, "routes": RogueData.ROUTES.values(),
		"activities": RogueData.ACTIVITIES.values(), "calendar_actions": RogueData.CALENDAR_ACTIONS.values(),
		"big_fates": RogueData.BIG_FATES.values()}
	t.eq(text.keys().filter(func(k) -> bool: return not str(k).begins_with("_")), tables.keys(), "%s has exactly the nine tables" % ROGUE_TEXT.get_file())
	for table in tables:
		var section: Dictionary = text.get(table, {})
		var rows: Array = tables[table]
		t.ok(not rows.is_empty(), "OceanRogueData %s has rows" % table)
		var missing: Array = []
		for row in rows:
			var id := str(row.get("id", ""))
			if not section.has(id) or str(row.get("name", "")) == "" or str(row.get("name", "")) != str(section[id].get("name", "")):
				missing.append(id)
		t.eq(missing, [], "every OceanRogueData %s row has its name from %s" % [table, ROGUE_TEXT])
		t.eq(section.size(), rows.size(), "%s.%s has no stray rows" % [ROGUE_TEXT.get_file(), table])
	t.ok(RogueData.COMPANIONS.is_read_only() and (RogueData.COMPANIONS["marie"] as Dictionary).is_read_only(), "merged tables stay read-only like the old constants")
	t.eq([str(RogueData.COMPANIONS["marie"]["name"]), str(RogueData.COMPANIONS["corso"]["name"])], ["玛丽·朗热", "科尔索"], "the two old companion names are gone")


func _test_scripts() -> void:
	var n := 0
	var hits: Array = []
	for dir in SCRIPT_DIRS:
		for path in _files(dir, ".gd"):
			n += 1
			for lit in _strings(FileAccess.get_file_as_string(path)):
				for w in WORDS:
					if lit.contains(w):
						hits.append("%s: %s" % [path.get_file(), w])
	t.ok(n >= 20, "ocean-line scripts scanned (%d)" % n)
	t.eq(hits, [], "no pawnshop words in ocean-line script string literals")


# ================================================================ 3. 引擎产出的字

func _test_routes() -> void:
	var doc = G.read_json(G.ROUTES_PATH)
	t.ok(typeof(doc) == TYPE_DICTIONARY, "golden routes load")
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var texts := {}
	for ending in G.ENDINGS:
		var c: RefCounted = G.new_campaign()
		t.ok(c != null, "new campaign for route " + ending)
		if c == null:
			continue
		_collect(c, texts)
		var bad := ""
		for cmd in doc["routes"][ending]["commands"]:
			var res: Dictionary = c.send(StringName(str(cmd[0])), G._int_tree(cmd[1]))
			if not bool(res.get("ok", false)) and bad == "":
				bad = "%s %s: %s" % [cmd[0], cmd[1], res]
			_collect(c, texts)
		t.eq(bad, "", "route %s replays" % ending)
		t.eq(str(c.state.get("ending", "")), ending, "route %s reaches its ending" % ending)
	t.ok(texts.size() > 500, "the routes produce plenty of text (%d strings)" % texts.size())
	var all := "\n".join(PackedStringArray(texts.keys()))
	for part in ["军需官手册", "营令三色旗", "白旗 · 照常行军", "军费", "体力与士气", "查验"]:
		t.ok(all.contains(part), "the routes show the new wording: " + part)
	var hits: Array = []
	for s in texts:
		for w in WORDS:
			if str(s).contains(w):
				hits.append("%s in: %s" % [w, str(s).left(60)])
	t.eq(hits.slice(0, 8), [], "no pawnshop words in anything ocean_view produced on the five routes (%d hits)" % hits.size())


func _collect(model, texts: Dictionary) -> void:
	View.setup_text(model)
	_gather(View._overlay, texts)
	_gather(View.build(model), texts)
	_gather(View.query(model, &"campaign").get("gauges", []), texts)
	for uid in View.SIDES + ["big_fate"]:
		_gather(View.card(model, uid, true), texts)


func _gather(v: Variant, texts: Dictionary) -> void:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			if _non_ascii(str(v)):
				texts[str(v)] = true
		TYPE_DICTIONARY:
			for k in v:
				_gather(v[k], texts)
		TYPE_ARRAY:
			for x in v:
				_gather(x, texts)


# ================================================================ 4–5. 界面

func _test_screens() -> void:
	game = load(CardIds.ROOT_SCENE).instantiate() as CardGameRoot
	root.add_child(game)
	await t.frames(2)
	var bus := root.get_node("CardBus") as CardEventBus
	game.boot({"mock": false, "bus": bus, "guide": "off", "campaign": "ocean_pawn",
		"save_dir": t.user_dir() + "/saves", "settings_path": t.user_dir() + "/settings.json"})
	game.allow_quit = false
	game.stage.fast = true
	game.host.fast = true
	await t.frames(3)
	t.ok(game.title != null, "the ocean campaign opens on its title")
	if game.title == null:
		return
	var title := _text(game.title)
	t.ok(title.contains("远洋"), "the title shows the ocean name")
	t.ok(not title.contains("当"), "the title page has no 当 at all: " + _around(title, "当"))
	_clean(title, "title page")
	_test_window_title()
	(game.title.get_node_or_null("new") as Button).pressed.emit()
	await t.frames(4)
	_clean(_text(game.host.top_panel()), "chapter card")
	await _to_day()
	var hub = game.hub
	t.ok(hub != null and hub.is_visible_in_tree(), "the hub is up")
	if hub == null:
		return
	_clean(_text(hub), "hub")
	for uid in CAMP_CARDS:
		var b: Button = hub.card_button(uid)
		t.ok(b != null, "hub card " + uid)
		if b == null:
			continue
		b.pressed.emit()
		await t.frames(3)
		_clean(_text(game.host.top_panel()), "camp panel " + uid)
		await _close_all()
	for pair in [["BtnHubRules", "rules"], ["BtnHubRelics", "relics"], ["BtnHubDossier", "dossier"]]:
		var b := hub.find_child(pair[0], true, false) as Button
		t.ok(b != null, "hub button " + pair[1])
		if b == null:
			continue
		b.pressed.emit()
		await t.frames(3)
		var text := _text(game.host.top_panel())
		if pair[1] == "rules":
			t.ok(text.contains("军需官手册"), "the rules page is the quartermaster's manual")
		_clean(text, pair[1] + " page")
		await _close_all()
	for btn in ["", "settings", "help"]:
		(hub.find_child("BtnHubMenu", true, false) as Button).pressed.emit()
		await t.frames(3)
		t.eq(str(game.host.top_kind()), "pause", "the menu button opens the pause menu")
		var pause := game.host.top_panel()
		if btn == "":
			_clean(_text(pause), "pause menu")
		else:
			var b: Button = null
			if pause != null:
				b = pause.find_child(btn, true, false) as Button
			t.ok(b != null, "pause button " + btn)
			if b != null:
				b.pressed.emit()
				await t.frames(3)
				_clean(_text(game.host.top_panel()), "pause " + btn)
		await _close_all()
	await _test_prologue_card(hub)
	(hub.card_button("battle") as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "battle_lineup", "the battle card opens the lineup")
	_clean(_text(game.host.top_panel()), "battle lineup")
	await _close_all()
	(hub.end_button() as Button).pressed.emit()
	await t.frames(3)
	t.eq(str(game.host.top_kind()), "settle", "the end button opens the night panel")
	_clean(_text(game.host.top_panel()), "night panel")
	await _close_all()


## 序曲 VN：标题卡写场景标题，没有「天平」；读到抉择菜单，菜单上的字也干净
func _test_prologue_card(hub) -> void:
	# 快动画会跳过开场章节卡：开 VN 这一下先关掉
	game.host.fast = false
	(hub.card_button("story:prologue") as Button).pressed.emit()
	await t.frames(3)
	game.host.fast = true
	t.eq(str(game.host.top_kind()), "vn", "the story card opens the VN")
	var p := game.host.top_panel()
	if p == null:
		return
	t.eq(str(p.call("state")), "title", "the prologue opens on its title card")
	var card := _text(p)
	var scene_title := ""
	for s in _def.get("scenes", []):
		if str(s.get("id", "")) == "prologue":
			scene_title = str(s.get("title", ""))
	t.ok(scene_title != "" and card.contains(scene_title), "the title card shows the prologue title " + scene_title)
	t.ok(not card.contains("天平"), "the prologue title card has no 天平: " + _around(card, "天平"))
	_clean(card, "prologue title card")
	p.call("skip_all")
	await t.frames(2)
	_clean(_text(p), "prologue choices")
	await _close_all()


func _test_window_title() -> void:
	var shown := str(game.get_window().title)
	var hits: Array = []
	_scan(shown, "window title", hits)
	t.eq(hits, [], "no pawnshop words in the window title")
	var names := [str(_def.get("title", ""))]
	var ui = _json(OCEAN_UI)
	if typeof(ui) == TYPE_DICTIONARY:
		names.append(str(ui.get("common", {}).get("c16.title.name", "")))
	t.ok(shown in names, "the window title is the book name: %s (want one of %s)" % [shown, names])


func _to_day() -> void:
	for _i in range(40):
		if str(game.engine.view().get("phase", "")) == "day" and game.host.top_panel() == null:
			await t.frames(2)
			return
		var p := game.host.top_panel()
		if p != null:
			_clean(_text(p), "phase panel " + str(game.host.top_kind()))
			p.autoplay_step()
		else:
			(game.hub.end_button() as Button).pressed.emit()
		await t.frames(3)
	t.ok(false, "reach the day: " + str(game.engine.view().get("phase", "")))


func _close_all() -> void:
	for _i in range(6):
		if game.host.top_panel() == null:
			return
		game.host.close_top()
		await t.frames(2)
	t.ok(game.host.top_panel() == null, "panels close")


func _clean(text: String, where: String) -> void:
	t.ok(text.strip_edges() != "", where + " shows text")
	var hits: Array = []
	_scan(text, where, hits)
	t.eq(hits, [], "no pawnshop words on screen (%s)" % where)


func _around(text: String, word: String) -> String:
	var i := text.find(word)
	return "" if i < 0 else text.substr(maxi(0, i - 12), 24 + word.length()).replace("\n", " ")


# ================================================================ 小工具

## 看得见的字：Label、Button、RichTextLabel、LineEdit 和各控件的悬停提示
func _text(node: Node) -> String:
	var out := PackedStringArray()
	if node == null:
		return ""
	for c in _walk(node):
		if c is CanvasItem and not (c as CanvasItem).is_visible_in_tree():
			continue
		if c is Label or c is Button or c is LineEdit:
			out.append(str(c.text))
		elif c is RichTextLabel:
			out.append((c as RichTextLabel).get_parsed_text())
		if c is Control and (c as Control).tooltip_text != "":
			out.append((c as Control).tooltip_text)
	return "\n".join(out)


func _walk(node: Node) -> Array:
	var out: Array = [node]
	for c in node.get_children():
		out.append_array(_walk(c))
	return out


func _files(dir: String, ext: String) -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d, ext))
	return out


func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _non_ascii(s: String) -> bool:
	return s.to_utf8_buffer().size() != s.length()


## .gd 里的字符串字面量（先去掉注释）
func _strings(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for m in re.search_all(_strip_comments(src)):
		out.append(m.get_string(1))
	return out


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
		if c == 10:
			in_str = false
		if c == 34:
			in_str = not in_str
		if c == 35 and not in_str:
			while i < src.length() and src.unicode_at(i) != 10:
				i += 1
			continue
		out += src.substr(i, 1)
		i += 1
	return out
