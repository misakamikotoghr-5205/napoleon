# 电报机：不是选择题。来电是一串四位数字，对照电码本译出来；回电从电码本选词组（最多四个），再按发报键。
# 每发一次，维持会怀疑 +1（无线电会被侦测）——由剧情数据结算。
extends PanelContainer

signal sent(words)
signal skipped
signal done

var beeper = null
var b_data: Dictionary = {}
var codes: Array = []
var decoded: Array = []
var picked: Array = []
var incoming_box: HBoxContainer
var book_grid: GridContainer
var reply_lbl: Label
var send_btn: Button
var skip_btn: Button
var done_btn: Button
var prompt_lbl: Label
var lamp_t: float = 0.0
var lamp_rect: ColorRect
var select_slot: int = -1
var max_words: int = 4

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.box(Color("#1d2a44"), Color("#5a3f2a"), 5, 3, 16))
	var v := UiStyle.vbox(8)
	add_child(v)
	var top := UiStyle.hbox(10)
	v.add_child(top)
	lamp_rect = ColorRect.new()
	lamp_rect.custom_minimum_size = Vector2(18, 18)
	lamp_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(lamp_rect)
	top.add_child(UiStyle.title_label("电报机", 30, UiStyle.LAMP))
	prompt_lbl = UiStyle.label("", 16, UiStyle.PAPER)
	prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(prompt_lbl)
	v.add_child(UiStyle.label("来电（点一组数字，再在电码本里点对应的词，把它译出来）：", 15, UiStyle.MIST))
	incoming_box = UiStyle.hbox(8)
	v.add_child(incoming_box)
	v.add_child(UiStyle.hsep())
	v.add_child(UiStyle.label("电码本：", 15, UiStyle.MIST))
	book_grid = GridContainer.new()
	book_grid.columns = 7
	book_grid.add_theme_constant_override("h_separation", 6)
	book_grid.add_theme_constant_override("v_separation", 6)
	v.add_child(book_grid)
	v.add_child(UiStyle.hsep())
	reply_lbl = UiStyle.label("", 18, UiStyle.LAMP)
	v.add_child(reply_lbl)
	var row := UiStyle.hbox(8)
	v.add_child(row)
	var clear_btn := UiStyle.button("擦掉重写", 16, "wood")
	clear_btn.pressed.connect(_clear_picked)
	row.add_child(clear_btn)
	send_btn = UiStyle.button("按发报键 ·—·", 18, "seal")
	send_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send_btn.pressed.connect(_send)
	row.add_child(send_btn)
	skip_btn = UiStyle.button("不回", 16, "wood")
	skip_btn.pressed.connect(_skip)
	row.add_child(skip_btn)
	done_btn = UiStyle.button("译好了", 18)
	done_btn.pressed.connect(_done)
	v.add_child(done_btn)

func _clear_picked() -> void:
	picked.clear()
	_refresh()

func _skip() -> void:
	visible = false
	emit_signal("skipped")

func _done() -> void:
	visible = false
	emit_signal("done")

func _select_slot(i: int) -> void:
	select_slot = i
	_refresh()

func open(b: Dictionary) -> void:
	b_data = b
	codes = b.get("incoming_codes", [])
	decoded = []
	for c in codes:
		decoded.append("")
	picked = []
	select_slot = 0 if not codes.is_empty() else -1
	prompt_lbl.text = str(b.get("prompt", ""))
	visible = true
	for c in book_grid.get_children():
		book_grid.remove_child(c)
		c.queue_free()
	for w in b.get("codebook", []):
		var btn := UiStyle.button("%s\n%s" % [w["word"], w["code"]], 15)
		btn.custom_minimum_size = Vector2(110, 44)
		var word: String = w["word"]
		btn.pressed.connect(_book_click.bind(word))
		btn.set_meta("word", word)
		book_grid.add_child(btn)
	_refresh()

func _book_click(word: String) -> void:
	if beeper != null:
		beeper.click()
	if select_slot >= 0 and select_slot < codes.size() and decoded[select_slot] == "":
		if DB.get_db().code_of(word) == str(codes[select_slot]):
			decoded[select_slot] = word
			select_slot = decoded.find("")
		else:
			prompt_lbl.text = "（%s 的电码是 %s，对不上 %s。）" % [word, DB.get_db().code_of(word), codes[select_slot]]
		_refresh()
		return
	if wants_reply() and picked.size() < max_words:
		picked.append(word)
		_refresh()

func wants_reply() -> bool:
	return bool(b_data.get("reply", false))

func all_decoded() -> bool:
	return not decoded.has("")

func _refresh() -> void:
	for c in incoming_box.get_children():
		incoming_box.remove_child(c)
		c.queue_free()
	if codes.is_empty():
		incoming_box.add_child(UiStyle.label("（没有来电）", 15, UiStyle.MIST))
	for i in range(codes.size()):
		var t := "%s\n%s" % [codes[i], decoded[i] if decoded[i] != "" else "？"]
		var b := UiStyle.button(t, 17, "seal" if i == select_slot and decoded[i] == "" else "paper")
		b.custom_minimum_size = Vector2(84, 56)
		var idx := i
		b.pressed.connect(_select_slot.bind(idx))
		incoming_box.add_child(b)
	var codes_out: Array = []
	for w in picked:
		codes_out.append(DB.get_db().code_of(w))
	reply_lbl.text = ("回电：%s　〔%s〕" % [" / ".join(picked), " ".join(codes_out)]) if wants_reply() else ""
	send_btn.visible = wants_reply()
	skip_btn.visible = wants_reply() and bool(b_data.get("allow_skip", false))
	send_btn.disabled = picked.is_empty() or not all_decoded()
	done_btn.visible = not wants_reply()
	done_btn.disabled = not all_decoded()
	if wants_reply() and not all_decoded():
		reply_lbl.text = "（先把来电译出来，再回电。）"

func _send() -> void:
	if picked.is_empty() or not all_decoded():
		return
	if beeper != null:
		beeper.morse(picked.size())
	visible = false
	emit_signal("sent", picked.duplicate())

func _process(d: float) -> void:
	lamp_t += d
	var on := not all_decoded() and int(lamp_t * 3.0) % 2 == 0
	lamp_rect.color = Color("#ffd25a") if on else Color("#5a3f2a")

# 自动试玩：把来电全部译出
func auto_decode() -> void:
	var ans: Array = b_data.get("_answer", [])
	for i in range(codes.size()):
		decoded[i] = str(ans[i]) if i < ans.size() else DB.get_db().word_of(str(codes[i]))
	_refresh()
