# Decode: a telegram (or a ledger's private code) in four-digit groups, and the real code book beside it,
# sorted by number, seven lines a page, with number tabs down the side. The player finds each group in the
# book and clicks the line to copy its word under the group. A smudged digit could be either of two; the
# player looks both up and picks the one that makes sense. With a key in use, the first group is the book's
# own number plus the key: the player works the key out and dials it, and pencil lines show each group with
# the key taken off. Whatever the player copies is recorded as their reading; nothing is refused or marked.
# Rule lines under the sheet stay on screen (acceptance fix2): how to copy, what a blot means and which digits
# run together, how a key works. They are rules of the game; they never name this sheet's answer.
# Contract: docs/cards/CARDS_INTERFACES.md 3.3 C15, 4.7.23, 8.1, 8.2. Random domain c.mg.decode.layout.
# Every change goes through apply_op(op); ops_log() replays a game exactly.
# Ops: ["select", g] ["page", p] ["pick", g, code] ["clear", g] ["key", k] ["done"]. Owner C15.
class_name CardDecodeGame
extends CardMiniGame

const SlipSc = preload("res://scripts/cards/minigames/decode/decode_slip.gd")
const Chrome = preload("res://scripts/cards/minigames/mg_chrome.gd")
const DOMAIN := "c.mg.decode.layout"
const BOOK_REAL := "res://data/cards/minigames/codebook.json"
const BOOK_EXAMPLE := "res://data/cards/_examples/minigames/codebook.json"
const PANEL_POS := Vector2(100, 50)
const PANEL_SIZE := Vector2(1080, 620)
const SHEET_RECT := Rect2(34, 62, 480, 420)
const BOOK_RECT := Rect2(540, 62, 466, 420)
const PER_PAGE := 7
const ROW_AT := Vector2(556, 106)
const ROW_SIZE := Vector2(430, 40)
const ROW_STEP := 44.0
const TAB_AT := Vector2(1010, 106)
const TAB_SIZE := Vector2(44, 44)
const TAB_STEP := 46.0
const MAX_TABS := 8
const PREV_AT := Vector2(556, 426)
const NEXT_AT := Vector2(890, 426)
const NAV_SIZE := Vector2(96, 40)
const CRIB_Y := 444.0
## The rule lines under the telegram sheet (acceptance fix2): how to copy, what a blot is and what to do with
## it, which digits run together, and how a key works. Rules of the game only; nothing about this sheet's answer.
const RULES_RECT := Rect2(34, 488, 480, 120)
const DONE_AT := Vector2(690, 510)
const DONE_SIZE := Vector2(180, 44)
const ABORT_SPOT := Vector2(882, 510)
const MAX_CELLS := 12
const ARG_BAD := -999999

var _params: Dictionary = {}
var _built: bool = false
var _done: bool = false
var _cipher: String = "telegraph"
var _codes: PackedStringArray = PackedStringArray()
var _book: Array = []            # [[code, word key], ...] sorted by code
var _smudges: Dictionary = {}    # group -> [digit position, that digit read the other way, the other code]
var _key_shift: int = 0
var _crib: String = ""
var _key: int = 0
var _key_used: bool = false
var _page: int = 0
var _sel: int = 0
var _picked: Array = []          # per group: the code string the player copied, or ""
var _lookups: int = 0
var _units: int = 0
var _ops: Array = []
var _mps: int = 1
var _max_min: int = 30
var _ap: Array = []
var _ap_started: bool = false
var _panel: Panel = null
var _slips: Array = []
var _crib_slip = null
var _rows: Array = []            # [button, code label, word label]
var _tabs: Array = []            # [button, page]
var _prev: Button = null
var _next: Button = null
var _page_label: Label = null
var _key_label: Label = null
var _done_btn: Button = null
var _rules: VBoxContainer = null


func kind() -> StringName:
	return &"decode"


func start(params: Dictionary) -> void:
	if _built:
		return
	_built = true
	_params = CardState.int_restore(params.duplicate(true))
	_read_params()
	_picked.resize(_codes.size())
	_picked.fill("")
	_mount()
	set_process_input(true)
	refresh()


## Skill = the chance that each reading is the right one (DESIGN P8). Plays through apply_op and finishes.
func autoplay(skill: float) -> void:
	if _done:
		return
	for op in _plan(skill):
		if _done:
			return
		apply_op(op)
	if not _done:
		apply_op(["done"])


func autoplay_step() -> bool:
	if _done:
		return false
	if not _ap_started:
		_ap = _plan(0.9)
		_ap_started = true
	if _ap.is_empty():
		apply_op(["done"])
		return false
	apply_op(_ap.pop_front())
	return not _done


func abort() -> void:
	if _done:
		return
	_done = true
	super.abort()


## The only way the game changes. Returns false (and changes nothing) when the op does not apply.
func apply_op(op: Array) -> bool:
	if _done or op.is_empty() or typeof(op[0]) != TYPE_STRING:
		return false
	var ok := false
	match str(op[0]):
		"select":
			ok = _op_select(op)
		"page":
			ok = _op_page(op)
		"pick":
			ok = _op_pick(op)
		"clear":
			ok = _op_clear(op)
		"key":
			ok = _op_key(op)
		"done":
			if op.size() != 1:
				return false
			_ops.append(["done"])
			_submit()
			return true
	if ok:
		_ops.append(op.duplicate(true))
		_minutes_spent = mini(_units * _mps, _max_min)
		refresh()
	return ok


func ops_log() -> Array:
	return _ops.duplicate(true)


# ---------------- read-outs ----------------
func is_done() -> bool:
	return _done


func group_count() -> int:
	return _codes.size()


func selected_group() -> int:
	return _sel


func current_page() -> int:
	return _page


func page_count() -> int:
	return maxi(1, int(ceil(float(_book.size()) / float(PER_PAGE))))


func book_codes() -> PackedStringArray:
	var out := PackedStringArray()
	for row in _book:
		out.append(str(row[0]))
	return out


## Codes on the open page, top to bottom.
func page_codes() -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(PER_PAGE):
		var at := _page * PER_PAGE + i
		if at < _book.size():
			out.append(str(_book[at][0]))
	return out


func page_of(code: String) -> int:
	var at := _book_index(code)
	return -1 if at < 0 else int(float(at) / float(PER_PAGE))


func codebook_key(code: String) -> String:
	var at := _book_index(code)
	return "" if at < 0 else str(_book[at][1])


## The book's word for a code (contract field "word" of codebook.text.json).
func word_of(code: String) -> String:
	var key := codebook_key(code)
	return "" if key == "" else CardText.card(key, "word")


func picked(g: int) -> String:
	return str(_picked[g]) if g >= 0 and g < _picked.size() else ""


func key_in_use() -> bool:
	return _key_shift > 0


## Screen rects for mouse tests.
func group_rect(g: int) -> Rect2:
	return (_slips[g] as Control).get_global_rect() if g >= 0 and g < _slips.size() else Rect2()


func row_rect(i: int) -> Rect2:
	return (_rows[i][0] as Control).get_global_rect()


func tab_rects() -> Array:
	var out: Array = []
	for t in _tabs:
		out.append([(t[0] as Control).get_global_rect(), int(t[1])])
	return out


func nav_rect(next_page: bool) -> Rect2:
	return (_next if next_page else _prev).get_global_rect()


func done_rect() -> Rect2:
	return _done_btn.get_global_rect()


## The host's abort spot: after "done".
func abort_rect() -> Rect2:
	return Chrome.abort_at(_panel, ABORT_SPOT)


func refresh() -> void:
	for g in range(_slips.size()):
		var slip = _slips[g]
		slip.selected = g == _sel
		var code := str(_picked[g])
		slip.set_word("" if code == "" else word_of(code))
		if key_in_use():
			slip.set_pencil(true, CardText.ui("c15.decode.minus", {"k": _key}), _pencil(g))
		slip.queue_redraw()
	for i in range(_rows.size()):
		var at := _page * PER_PAGE + i
		var row: Array = _rows[i]
		var b: Button = row[0]
		if at < _book.size():
			b.visible = true
			b.disabled = _done
			(row[1] as Label).text = str(_book[at][0])
			(row[2] as Label).text = CardText.card(str(_book[at][1]), "word")
		else:
			b.visible = false
	if _prev != null:
		_prev.disabled = _page <= 0 or _done
		_next.disabled = _page >= page_count() - 1 or _done
	if _page_label != null:
		_page_label.text = CardText.ui("c15.book.page", {"n": _page + 1})
	if _key_label != null:
		_key_label.text = str(_key)


# ---------------- ops ----------------
func _op_select(op: Array) -> bool:
	if op.size() != 2:
		return false
	var g := _arg(op, 1)
	if g < 0 or g >= _codes.size() or g == _sel:
		return false
	_sel = g
	return true


func _op_page(op: Array) -> bool:
	if op.size() != 2:
		return false
	var p := _arg(op, 1)
	if p < 0 or p >= page_count() or p == _page:
		return false
	_page = p
	_lookups += 1
	_emit_tool("lookup")
	return true


func _op_pick(op: Array) -> bool:
	if op.size() != 3:
		return false
	var g := _arg(op, 1)
	var v := _arg(op, 2)
	if g < 0 or g >= _codes.size() or v < 0:
		return false
	var code := ""
	for c in page_codes():
		if c.is_valid_int() and int(c) == v:
			code = c
	if code == "" or str(_picked[g]) == code:
		return false
	_picked[g] = code
	_units += 1
	_sel = _next_open(g)
	_emit_tool("pick")
	return true


func _op_clear(op: Array) -> bool:
	if op.size() != 2:
		return false
	var g := _arg(op, 1)
	if g < 0 or g >= _codes.size() or str(_picked[g]) == "":
		return false
	_picked[g] = ""
	_sel = g
	_emit_tool("clear")
	return true


func _op_key(op: Array) -> bool:
	if op.size() != 2 or not key_in_use():
		return false
	var k := _arg(op, 1)
	if k < 0 or k > 9 or k == _key:
		return false
	_key = k
	if not _key_used:
		_key_used = true
		_units += 1
	_emit_tool("key")
	return true


static func _arg(op: Array, i: int) -> int:
	if i >= op.size():
		return ARG_BAD
	var v = op[i]
	if typeof(v) == TYPE_INT:
		return int(v)
	if typeof(v) == TYPE_FLOAT and is_finite(v) and float(v) == floorf(v):
		return int(v)
	return ARG_BAD


## After copying into group g: the next empty group after it (wrapping), else g.
func _next_open(g: int) -> int:
	var n := _codes.size()
	for i in range(1, n + 1):
		var h := posmod(g + i, n)
		if str(_picked[h]) == "":
			return h
	return g


# ---------------- result ----------------
func _submit() -> void:
	if _done:
		return
	_done = true
	_minutes_spent = mini(_units * _mps, _max_min)
	refresh()
	finished.emit({
		"quality_permille": _quality(),
		"observations": _observations(),
		"minutes": _minutes_spent,
		"measures": _measures(),
		"aborted": false,
	})


func _decoded() -> int:
	var n := 0
	for c in _picked:
		if str(c) != "":
			n += 1
	return n


func _measures() -> Dictionary:
	var picked_codes: Array = []
	for c in _picked:
		var s := str(c)
		picked_codes.append(int(s) if s != "" and s.is_valid_int() else -1)
	return {"decoded": _decoded(), "lookups": _lookups, "picked": picked_codes, "key": _key}


## Each copied group is recorded as the player's reading (obs.decode.<the code they copied>), right or wrong.
func _observations() -> Array:
	var out: Array = []
	for c in _picked:
		var s := str(c)
		if s != "" and not out.has("obs.decode." + s):
			out.append("obs.decode." + s)
	if _decoded() < _codes.size() or out.is_empty():
		out.append("obs.decode.partial")
	return out


func _quality() -> int:
	var n := _codes.size()
	if n <= 0:
		return 0
	var done_n := _decoded()
	var q := int(float(done_n * 1000) / float(n))
	if done_n < n:
		q = mini(q, 340)
	return mini(q, 1000)


# ---------------- autoplay ----------------
## Per group g: open its page and copy it; JevRng [9000 + g] under skill = the right reading, otherwise the
## other reading of a smudged digit (or the line next to it in the book). With a key: [9100] under skill =
## the right key, otherwise a wrong one, and the pencil lines then lead every lookup astray.
func _plan(skill: float) -> Array:
	var ops: Array = []
	var seed_v := int(_params.get("seed", 0))
	var k := 0
	if key_in_use():
		k = _key_shift
		if JevRng.draw(seed_v, DOMAIN, [9100]) >= skill:
			k = posmod(_key_shift + 1 + int(JevRng.draw(seed_v, DOMAIN, [9101]) * 8.0), 10)
		if k != _key:
			ops.append(["key", k])
	var page := _page
	var sel := _sel
	for g in range(_codes.size()):
		var right := _shifted(_codes[g], -1, -1, _key_shift - k)
		var target := right
		if JevRng.draw(seed_v, DOMAIN, [9000 + g]) >= skill:
			target = _wrong_reading(g, right, k)
		var at := _book_index(target)
		if at < 0:
			continue
		if g != sel:
			ops.append(["select", g])
		var p := int(float(at) / float(PER_PAGE))
		if p != page:
			ops.append(["page", p])
			page = p
		ops.append(["pick", g, int(target)])
		sel = g
		for i in range(1, _codes.size() + 1):
			if g + i < _codes.size():
				sel = g + i
				break
	ops.append(["done"])
	return ops


func _wrong_reading(g: int, right: String, k: int) -> String:
	if _smudges.has(g):
		var alt := _shifted(str(_smudges[g][2]), -1, -1, _key_shift - k)
		if alt != right and _book_index(alt) >= 0:
			return alt
	var at := _book_index(right)
	if at < 0:
		at = _nearest(right)
	if at < 0:
		return ""
	var other := at + 1 if at + 1 < _book.size() else at - 1
	if other < 0:
		return ""
	return str(_book[other][0])


## code with digit d replaced by v (d = -1: none), every digit moved by delta (mod 10).
static func _shifted(code: String, d: int, v: int, delta: int) -> String:
	var out := ""
	for i in range(code.length()):
		var ch := code.substr(i, 1)
		var n := int(ch) if ch.is_valid_int() else 0
		if i == d:
			n = v
		out += str(posmod(n + delta, 10))
	return out


func _book_index(code: String) -> int:
	for i in range(_book.size()):
		if str(_book[i][0]) == code:
			return i
	return -1


func _nearest(code: String) -> int:
	if _book.is_empty() or not code.is_valid_int():
		return -1
	var best := 0
	var v := int(code)
	for i in range(_book.size()):
		if absi(int(str(_book[i][0])) - v) < absi(int(str(_book[best][0])) - v):
			best = i
	return best


## The pencil line of group g: each shown digit minus the dialled key (-1 under the blot).
func _pencil(g: int) -> Array:
	var out: Array = []
	var shown := _shown(_codes[g])
	var sm_at := -1
	if _smudges.has(g):
		sm_at = int(_smudges[g][0])
	for d in range(shown.size()):
		out.append(-1 if d == sm_at else posmod(int(shown[d]) - _key, 10))
	return out


func _shown(code: String) -> Array:
	var out: Array = []
	for i in range(code.length()):
		var ch := code.substr(i, 1)
		out.append(posmod((int(ch) if ch.is_valid_int() else 0) + _key_shift, 10))
	return out


# ---------------- params ----------------
func _read_params() -> void:
	_cipher = str(_params.get("cipher", "telegraph"))
	_mps = maxi(1, int(_params.get("minutes_per_step", 1)))
	_max_min = maxi(0, int(_params.get("max_minutes", 30)))
	_codes = PackedStringArray()
	var codes = _params.get("codes", [])
	if typeof(codes) == TYPE_ARRAY:
		for c in codes:
			_codes.append(_code_str(c))
	_key_shift = posmod(int(_params.get("key_shift", 0)), 10)
	_crib = _code_str(_params.get("crib", "")) if str(_params.get("crib", "")) != "" else ""
	_book = _read_book()
	# The sheet holds MAX_CELLS groups; longer lists only come from a telegram without its own codes (B6).
	var room := MAX_CELLS - (1 if key_in_use() and _crib != "" else 0)
	if _codes.size() > room:
		_codes = _codes.slice(0, room)
	_smudges = {}
	var raw = _params.get("smudges", [])
	if typeof(raw) == TYPE_ARRAY:
		for row in raw:
			if typeof(row) != TYPE_ARRAY or (row as Array).size() < 3:
				continue
			var g := int(row[0])
			var d := int(row[1])
			if g < 0 or g >= _codes.size() or d < 0 or d >= _codes[g].length() or _smudges.has(g):
				continue
			var alt := _smudge_alt(_codes[g], d, row[2])
			if alt != "":
				_smudges[g] = [d, int(alt.substr(d, 1)), alt]


## The other reading of code with digit d smudged. Contract: the whole code the player would look up
## ("5127", key already taken off); a bare 0-9 number is the older digit-only form. "" when it does not fit.
static func _smudge_alt(code: String, d: int, raw) -> String:
	var alt := ""
	var bare := typeof(raw) == TYPE_INT or (typeof(raw) == TYPE_FLOAT and is_finite(raw) and float(raw) == floorf(raw))
	if bare and int(raw) >= 0 and int(raw) <= 9:
		alt = code.substr(0, d) + str(int(raw)) + code.substr(d + 1)
	elif bare or typeof(raw) == TYPE_STRING:
		alt = _code_str(raw)
	if alt.length() != code.length() or alt == code or not alt.substr(d, 1).is_valid_int():
		return ""
	for i in range(code.length()):
		if i != d and alt.substr(i, 1) != code.substr(i, 1):
			return ""
	return alt


static func _code_str(v) -> String:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return str(int(v)).pad_zeros(4)
	return str(v)


## params.book ([[code, key], ...]); without it, the code book file as before (older engines).
func _read_book() -> Array:
	var out: Array = []
	var raw = _params.get("book", null)
	if typeof(raw) == TYPE_ARRAY:
		for row in raw:
			if typeof(row) == TYPE_ARRAY and (row as Array).size() >= 2:
				out.append([_code_str(row[0]), str(row[1])])
	else:
		var path := BOOK_REAL if FileAccess.file_exists(BOOK_REAL) else BOOK_EXAMPLE
		var doc = CardDB.read_json(path)
		if typeof(doc) == TYPE_DICTIONARY:
			var rows = doc.get("codes", {})
			if typeof(rows) == TYPE_DICTIONARY:
				for code in rows.keys():
					var r = rows[code]
					if typeof(r) == TYPE_DICTIONARY:
						out.append([str(code), str(r.get("key", ""))])
			if _crib == "" and str(doc.get("crib", "")) != "":
				_crib = str(doc.get("crib", ""))
	out.sort_custom(func(a, b): return str(a[0]) < str(b[0]))
	return out


# ---------------- building ----------------
func _mount() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade := ColorRect.new()
	shade.color = CardTheme.color(&"shade")
	shade.position = Vector2.ZERO
	shade.size = Vector2(1280, 720)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = Panel.new()
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.clip_contents = true
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", Chrome.frame())
	add_child(_panel)
	_panel.add_child(Chrome.title(CardText.ui("c15.decode.title"), CardText.is_draft("c15.decode.title"), PANEL_SIZE.x))
	_build_sheet()
	_build_rules()
	_build_book()
	_done_btn = Chrome.button(CardText.ui("c15.btn.done_decode"), true)
	_done_btn.position = DONE_AT
	_done_btn.size = DONE_SIZE
	_done_btn.custom_minimum_size = DONE_SIZE
	_done_btn.pressed.connect(_on_done)
	_panel.add_child(_done_btn)
	CardAnchors.register(&"a.mg.decode.main", _panel)


func _build_sheet() -> void:
	var sheet := Chrome.plate(Chrome.well(), SHEET_RECT.position, SHEET_RECT.size)
	_panel.add_child(sheet)
	if CardIds.is_known_anchor("a.mg.decode.sheet"):
		CardAnchors.register(&"a.mg.decode.sheet", sheet)
	var band := ColorRect.new()
	band.color = CardTheme.color(&"indigo" if _cipher == "telegraph" else &"wood_mid")
	band.position = Vector2(8, 8)
	band.size = Vector2(SHEET_RECT.size.x - 16.0, 12)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(band)
	var cells: Array = []
	if key_in_use() and _crib != "":
		cells.append(-1)
	for g in range(_codes.size()):
		cells.append(g)
	var compact := cells.size() > 6
	var shown := mini(cells.size(), MAX_CELLS)
	for i in range(shown):
		var g := int(cells[i])
		var slip = SlipSc.new()
		slip.game = self
		slip.index = g
		slip.compact = compact
		if compact:
			slip.position = Vector2(50 + posmod(i, 3) * 154, 82 + int(float(i) / 3.0) * 90)
			slip.size = Vector2(148, 84)
		else:
			slip.position = Vector2(50 + posmod(i, 2) * 232, 86 + int(float(i) / 2.0) * 120)
			slip.size = Vector2(224, 112)
		if g < 0:
			slip.crib = true
			slip.digits = _shown(_crib)
		else:
			slip.digits = _shown(_codes[g])
			if _smudges.has(g):
				var sm: Array = _smudges[g]
				slip.smudge_at = int(sm[0])
				slip.smudge_pair = [posmod(int(_codes[g].substr(int(sm[0]), 1)) + _key_shift, 10),
					posmod(int(sm[1]) + _key_shift, 10)]
				slip.blot_seed = _blot_seed(g)
			_slips.append(slip)
		_panel.add_child(slip)
		slip.build()
		if g < 0:
			_crib_slip = slip
	if key_in_use():
		_build_key_row()


## Rule lines on the dark sheet under the telegram. The blot lines only when this sheet has a blot, the key line
## only when a key is in use; the pairs come from the slip's own table (the same pairs the engine smudges).
func _build_rules() -> void:
	_rules = VBoxContainer.new()
	_rules.name = "Rules"
	_rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rules.position = RULES_RECT.position
	_rules.size = RULES_RECT.size
	_rules.add_theme_constant_override("separation", 2)
	_panel.add_child(_rules)
	_rule_line("RuleFind", "c15.decode.rule.find", {})
	if not _smudges.is_empty():
		_rule_line("RuleBlot", "c15.decode.rule.blot", {})
		_rule_line("RulePairs", "c15.decode.rule.pairs", {"pairs": pairs_text()})
	if key_in_use():
		_rule_line("RuleKey", "c15.decode.rule.key", {})


func _rule_line(node_name: String, key: String, args: Dictionary) -> void:
	var l := Chrome.note(CardText.ui(key, args), CardText.is_draft(key))
	l.name = node_name
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(RULES_RECT.size.x, 0)
	_rules.add_child(l)


## "1/7  2/7  3/8  0/8  4/9  5/6": the digits a smudge can run together (a rule, not this sheet's answer).
static func pairs_text() -> String:
	var parts := PackedStringArray()
	for pr in SlipSc.PAIRS:
		parts.append(str(int(pr[0])) + "/" + str(int(pr[1])))
	return "  ".join(parts)


## The rule lines shown, top to bottom (tests).
func rule_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if _rules != null:
		for c in _rules.get_children():
			if c is Label:
				out.append((c as Label).text)
	return out


## A few blot squares from the layout domain (decoration range), the same for both readings.
func _blot_seed(g: int) -> Array:
	var out: Array = []
	var seed_v := int(_params.get("seed", 0))
	for i in range(5):
		out.append([JevRng.draw(seed_v, DOMAIN, [5000 + g * 10 + i]), JevRng.draw(seed_v, DOMAIN, [5500 + g * 10 + i])])
	return out


func _build_key_row() -> void:
	var y := CRIB_Y
	var x := 50.0
	if _crib != "":
		var crib_l := _paper_label(CardText.ui("c15.decode.crib"), 16)
		crib_l.position = Vector2(x, y)
		crib_l.size = Vector2(60, 32)
		_panel.add_child(crib_l)
		var digits_l := _paper_label(_crib, 20)
		digits_l.position = Vector2(x + 62, y - 2)
		digits_l.size = Vector2(80, 32)
		_panel.add_child(digits_l)
	var key_l := _paper_label(CardText.ui("c15.decode.key"), 16)
	key_l.position = Vector2(270, y)
	key_l.size = Vector2(60, 32)
	_panel.add_child(key_l)
	var minus := Chrome.button("-")
	minus.position = Vector2(336, y - 2)
	minus.size = Vector2(36, 34)
	minus.pressed.connect(_on_key.bind(-1))
	_panel.add_child(minus)
	_key_label = _paper_label(str(_key), 22)
	_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_label.position = Vector2(376, y - 4)
	_key_label.size = Vector2(36, 34)
	_panel.add_child(_key_label)
	var plus := Chrome.button("+")
	plus.position = Vector2(416, y - 2)
	plus.size = Vector2(36, 34)
	plus.pressed.connect(_on_key.bind(1))
	_panel.add_child(plus)


func _build_book() -> void:
	var book := Chrome.plate(Chrome.well(), BOOK_RECT.position, BOOK_RECT.size)
	_panel.add_child(book)
	var title := _paper_label(CardText.ui("c15.book.title"), 22)
	title.add_theme_font_override("font", CardTheme.font_title())
	title.add_theme_color_override("font_color", CardTheme.color(&"seal_dark"))
	title.position = BOOK_RECT.position + Vector2(16, 6)
	title.size = Vector2(300, 34)
	_panel.add_child(title)
	CardAnchors.register(&"a.mg.decode.book", book)
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color.TRANSPARENT
	idle.border_color = CardTheme.with_alpha(&"ink_3", 0.35)
	idle.border_width_bottom = 1
	var lit := CardTheme.flat_style(&"gold_pale", &"gold_hi", 1, 3)
	for i in range(PER_PAGE):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = ROW_AT + Vector2(0, ROW_STEP * float(i))
		b.size = ROW_SIZE
		b.custom_minimum_size = ROW_SIZE
		for s in [&"normal", &"disabled", &"focus"]:
			b.add_theme_stylebox_override(s, idle)
		for s2 in [&"hover", &"pressed", &"hover_pressed"]:
			b.add_theme_stylebox_override(s2, lit)
		b.pressed.connect(_on_row.bind(i))
		var code_l := _paper_label("", 20)
		code_l.position = Vector2(10, 6)
		code_l.size = Vector2(80, 28)
		b.add_child(code_l)
		var word_l := _paper_label("", 20)
		word_l.position = Vector2(104, 6)
		word_l.size = Vector2(ROW_SIZE.x - 114.0, 28)
		word_l.clip_text = true
		b.add_child(word_l)
		_panel.add_child(b)
		_rows.append([b, code_l, word_l])
	_prev = Chrome.button(CardText.ui("c15.book.prev"))
	_prev.position = PREV_AT
	_prev.size = NAV_SIZE
	_prev.pressed.connect(_on_turn.bind(-1))
	_panel.add_child(_prev)
	_next = Chrome.button(CardText.ui("c15.book.next"))
	_next.position = NEXT_AT
	_next.size = NAV_SIZE
	_next.pressed.connect(_on_turn.bind(1))
	_panel.add_child(_next)
	_page_label = _paper_label("", 16)
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.position = Vector2(PREV_AT.x + NAV_SIZE.x, PREV_AT.y + 8)
	_page_label.size = Vector2(NEXT_AT.x - PREV_AT.x - NAV_SIZE.x, 24)
	_panel.add_child(_page_label)
	_build_tabs()


## Number tabs down the book's edge: the first page of each three-digit head.
func _build_tabs() -> void:
	var heads: Array = []
	var last := ""
	for i in range(_book.size()):
		var head := str(_book[i][0]).substr(0, 3)
		if head != last:
			heads.append([head, int(float(i) / float(PER_PAGE))])
			last = head
	var picked_heads: Array = heads
	if heads.size() > MAX_TABS:
		picked_heads = []
		for t in range(MAX_TABS):
			picked_heads.append(heads[int(float(t * heads.size()) / float(MAX_TABS))])
	var style := CardTheme.flat_style(&"paper_old", &"umber", 1, 3)
	var lit := CardTheme.flat_style(&"gold_pale", &"gold_hi", 1, 3)
	for t2 in range(picked_heads.size()):
		var row: Array = picked_heads[t2]
		var b := Button.new()
		b.text = str(row[0])
		b.focus_mode = Control.FOCUS_NONE
		b.position = TAB_AT + Vector2(0, TAB_STEP * float(t2))
		b.size = TAB_SIZE
		b.custom_minimum_size = TAB_SIZE
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", CardTheme.color(&"ink"))
		b.add_theme_color_override("font_hover_color", CardTheme.color(&"ink"))
		b.add_theme_color_override("font_pressed_color", CardTheme.color(&"ink"))
		for s in [&"normal", &"disabled", &"focus"]:
			b.add_theme_stylebox_override(s, style)
		for s2 in [&"hover", &"pressed", &"hover_pressed"]:
			b.add_theme_stylebox_override(s2, lit)
		b.pressed.connect(_on_tab.bind(int(row[1])))
		_panel.add_child(b)
		_tabs.append([b, int(row[1])])


func _paper_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", CardTheme.font_body())
	l.add_theme_font_size_override("font_size", maxi(14, font_size))
	l.add_theme_color_override("font_color", CardTheme.color(&"ink"))
	return l


func _on_row(i: int) -> void:
	var at := _page * PER_PAGE + i
	if at < _book.size() and str(_book[at][0]).is_valid_int():
		apply_op(["pick", _sel, int(str(_book[at][0]))])


func _on_turn(d: int) -> void:
	apply_op(["page", _page + d])


func _on_tab(p: int) -> void:
	apply_op(["page", p])


func _on_key(d: int) -> void:
	apply_op(["key", posmod(_key + d, 10)])


func _on_done() -> void:
	apply_op(["done"])


func _emit_tool(tool: String) -> void:
	var bus := _bus()
	if bus == null:
		return
	bus.ui_event.emit(&"mg_tool", {"kind": "decode", "tool": tool})


func _bus() -> CardEventBus:
	var n: Node = self
	while n != null:
		var found = n.get("bus")
		if found is CardEventBus:
			return found as CardEventBus
		n = n.get_parent()
	return null


func _input(event: InputEvent) -> void:
	if _done or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		abort()
		get_viewport().set_input_as_handled()
