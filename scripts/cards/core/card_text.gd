# 一切可见文字的唯一来源：按字段查 剧情插件 packs/<id>/text/** → 人写层 → AI 层（#212；CardDB.text_value）。
# 都缺时默认给空串，界面用 has_text() 跳过空的那一拍；只有打开开发开关（命令行 -- --show-drafts，或项目设置
# dehoudang/cards/show_drafts = true，或测试里 set_show_drafts(true)）才给【稿】+ brief（草稿样式），
# 【稿】字样读 data/cards/_dev/strings.json；发行版永远不给【稿】。框架版收尾默认（2026-10-22），主创可改。
# 主人 G01；W0 写了能用的版本。合同：docs/cards/CARDS_INTERFACES.md §4.5、§7.8、§7.9（G01 core）；docs/cards/PLUGINS.md。
# 覆盖层格式：牌 {"<id>": {"title": …, "lines": {"greet": …}, "choices": {"<id>": …}, "_provenance": …}}；
# 界面键与观察键 {"<键>": {"t": …, "_provenance": …}}；人物 {"<人物 id>": {"name": …}}；物品 {"item.<cat>.<variant>": {…}}。
class_name CardText
extends RefCounted

const DEV_STRINGS := "res://data/cards/_dev/strings.json"
const SHOW_DRAFTS_SETTING := "dehoudang/cards/show_drafts"

static var _db: CardDB = null           # 配置（setup 时给），不是游戏状态
static var _draft_mark: String = ""
static var _draft_mark_read: bool = false
static var _issued: Dictionary = {}     # 开发版：给出过的字（界面测试用 issued_contains）
static var _show_drafts_override: int = -1  # -1 = 看命令行 / 项目设置；0 关；1 开（不随 setup 清掉）
static var _show_drafts_env: int = -1       # 命令行 / 项目设置读一次的结果


static func setup(db: CardDB) -> void:
	_db = db
	_issued = {}
	_draft_mark = ""
	_draft_mark_read = false


## 开发开关：缺字时是否显示【稿】+ brief。测试库 card_t.gd 打开它以保持老测试的开发版行为。
static func set_show_drafts(on: bool) -> void:
	_show_drafts_override = 1 if on else 0


static func shows_drafts() -> bool:
	if _is_ship():
		return false
	if _show_drafts_override >= 0:
		return _show_drafts_override == 1
	if _show_drafts_env < 0:
		var on := bool(ProjectSettings.get_setting(SHOW_DRAFTS_SETTING, false))
		var args := OS.get_cmdline_user_args()
		if args.has("--show-drafts"):
			on = true
		elif args.has("--hide-drafts"):
			on = false
		_show_drafts_env = 1 if on else 0
	return _show_drafts_env == 1


## 界面键（ui_keys/<ID>.json 登记的键；正文在 text/ui/<ID>.text.json 的 "t"）
static func ui(key: String, args: Dictionary = {}) -> String:
	var value := _value(key, "t")
	if value != "":
		return _issue(_fmt(value, args))
	return _draft(_fmt(_brief(key), args), key)


## 牌上的字段：field 是 "title" "body" "lines.greet" "choices.<id>" "slots.<id>" "outcomes.fail" 这类点路径
static func card(def_id: String, field: String, args: Dictionary = {}) -> String:
	var value := _value(def_id, field)
	if value != "":
		return _issue(_fmt(value, args))
	return _draft(_fmt(_brief(def_id + "#" + field), args), def_id + "#" + field)


## "key" 或 "<def>#<field>"
static func t(ref: String, args: Dictionary = {}) -> String:
	var at := ref.find("#")
	if at >= 0:
		return card(ref.substr(0, at), ref.substr(at + 1), args)
	return ui(ref, args)


static func person_name(person: String) -> String:
	var value := _value(person, "name")
	if value != "":
		return _issue(value)
	return _draft(_brief(person), person)


## 物品文字：template = "<cat>.<variant>"，覆盖层键 item.<cat>.<variant>
static func item_text(template: String, field: String) -> String:
	var value := _value("item." + template, field)
	if value != "":
		return _issue(value)
	return _draft("", "item." + template + "#" + field)


## 观察键（正文在 text/minigames/obs/<kind>.text.json 的 "t"）
static func obs(key: String) -> String:
	return ui(key)


## 有没有真正文（任一层给了非空字）。界面遇到 false 就跳过这一拍 / 这一页，不显示空白。
static func has_text(ref: String) -> bool:
	return not is_draft(ref)


## 各层都没有这段正文才用草稿样式；AI 不是 human 来源证明。
static func is_draft(ref: String) -> bool:
	var at := ref.find("#")
	if at >= 0:
		return _value(ref.substr(0, at), ref.substr(at + 1)) == ""
	for k in ["t", "name"]:
		if _value(ref, k) != "":
			return false
	return true


## 开发版：这段字是不是 CardText 给出过的（界面测试用；发行版永远 false）
static func issued_contains(s: String) -> bool:
	return _issued.has(s)


# ---------------- 内部 ----------------
static func _value(id: String, field: String) -> String:
	if _db == null:
		return ""
	return _db.text_value(id, field)


static func _brief(ref: String) -> String:
	return _db.brief_of(ref) if _db != null else ""


static func _fmt(s: String, args: Dictionary) -> String:
	return s.format(args) if not args.is_empty() else s


static func _draft(brief: String, ref: String) -> String:
	if not shows_drafts():
		return ""
	if not _draft_mark_read:
		_draft_mark_read = true
		var d = CardDB.read_json(DEV_STRINGS)
		if typeof(d) == TYPE_DICTIONARY:
			_draft_mark = str(d.get("draft_mark", ""))
	return _issue(_draft_mark + (brief if brief != "" else ref))


static func _issue(s: String) -> String:
	if not _is_ship() and s != "":
		_issued[s] = true
		# 对话框按空行把一段正文拆成几句演（dialog_box._append_line），拆出来的每一段也算 CardText 给的
		if s.contains("\n\n"):
			for part in s.split("\n\n", false):
				_issued[part] = true
	return s


static func _is_ship() -> bool:
	return CardShip.is_ship() or (_db != null and _db.ship)

