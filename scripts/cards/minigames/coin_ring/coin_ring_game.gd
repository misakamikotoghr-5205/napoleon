# 吹银元（appraise/DESIGN.md §5）：柜上有铺子自己的两枚样洋，足银的（甲）和哑板（乙，拴红线）。点哪枚就捏住吹哪枚，
# 余音同时画成一道线（甲的那道钉在最上面、乙的钉在最下面一直留着，客人的夹在中间，旧的留淡影）。客人的银元（一枚或一摞）也一样吹；
# 一摞的可以拖一枚碰另一枚。面板上一直写着怎么看线（线长 = 余音、疏密 = 声高、毛刺 = 杂音）和比的规矩
# （长短、毛刺会骗人，疏密不会：比甲疏的是哑板）——这是规矩，不是这一枚的答案。
# 听完了玩家自己说：单枚说“像足银的 / 像哑板 / 说不好”，一摞的一枚一枚标“响 / 哑”。游戏不揭底，
# 交回的观察就是玩家的判断（说错了照样交）；清晰度只看过程。主人 C13。合同：docs/cards/CARDS_INTERFACES.md §8、§3.3 C13。
# 一切输入都化成整数 op 走 apply_op（鼠标、键盘、自动玩、测试同一条路），ops_log() 能原样重放。
# 随机只用 c.mg.coin_ring.layout：[5000..] 每枚声音的装饰（噪声花样），[9000 + i] 自动玩第 i 个判断判不判对。
class_name CardCoinRingGame
extends CardMiniGame

const RingAudio = preload("res://scripts/cards/minigames/coin_ring/coin_ring_audio.gd")
const WaveView = preload("res://scripts/cards/minigames/coin_ring/coin_ring_wave.gd")
const Obs = preload("res://scripts/cards/minigames/coin_ring/coin_ring_obs.gd")
const Face = preload("res://scripts/cards/minigames/coin_ring/coin_ring_face.gd")
const Chrome = preload("res://scripts/cards/minigames/mg_chrome.gd")

const LAYOUT_DOMAIN := "c.mg.coin_ring.layout"
const PANEL_POS := Vector2(140, 40)
const PANEL_SIZE := Vector2(1000, 640)
const GOOD := -1
const DULL := -2
const CLINK_ROW := -9
const MAX_COINS := 5
const SAMPLE_ART := "item.silver.yuan_a"
## 没有 samples 参数时（老引擎）：足银样洋 = reference（再没有就用这个），哑板样洋 = 规格默认坏区间的中值。
const DEFAULT_GOOD := {"ring_ms": 1450, "pitch_cents": 0, "buzz": 8}
const DEFAULT_DULL := {"ring_ms": 1100, "pitch_cents": -67, "buzz": 14}
const DRAG_PX := 10.0
const GHOST_OFFSET := Vector2(18, -10)
const SALT_BASE := 5000
const AUTO_BASE := 9000

# 面板里的坐标（面板 1000x640 @ (140, 40)；DESIGN §5.9 的屏幕坐标减去面板原点）。
const COIN_ONE := Rect2(404, 72, 192, 192)
const STACK_Y := 80.0
const STACK_STEP := 144.0
const CHIP_Y := 216.0
const CHIP_H := 36.0
const WAVE_RECT := Rect2(34, 272, 932, 160)
const SAMPLE_RECTS := [Rect2(34, 448, 128, 128), Rect2(178, 448, 128, 128)]
const CAPTION_Y := 582.0
const NOTE_RECT := Rect2(340, 436, 626, 22)
const CALL_RECTS := [Rect2(340, 460, 180, 44), Rect2(532, 460, 180, 44), Rect2(724, 460, 180, 44)]
const TRIES_RECT := Rect2(340, 532, 300, 28)
const DONE_RECT := Rect2(660, 580, 160, 44)
const ABORT_SPOT := Vector2(832, 580)
## 怎么看线、怎么比（规矩，不是答案）：单枚放在银元左右两边的空处（左边看线、右边比法），
## 一摞放在单枚三个选项的位置。
const LEGEND_ONE := Rect2(34, 66, 344, 160)
const RULE_ONE := Rect2(622, 66, 344, 160)
const LEGEND_STACK := Rect2(340, 460, 626, 70)
const LEGEND_PAD := Vector2(14, 10)
const LEGEND_KEYS := ["c13.legend.len", "c13.legend.wave", "c13.legend.fuzz"]
const RULE_KEYS := ["c13.rule.trick", "c13.rule.pitch"]

## 宿主没注入时，沿父节点找 CardMiniGameHost.bus，再退到自动加载。
var bus: CardEventBus = null
var params: Dictionary = {}
## 快动画（测试可直接打开）；也读 CardSettings.fast_anim()。
var fast_anim: bool = false

var _built: bool = false
var _done: bool = false
var _seed: int = 0
var _coins: Array = []
var _good: Dictionary = {}
var _dull: Dictionary = {}
var _art_id: String = ""
var _tries_total: int = 0
var _tries_left: int = 0
## 余音框中间轮着放几道客人的线（ghosts；不钉样洋时就是框里一共几道）。
var _rolling: int = 1
var _clink_ok: bool = false
var _step_min: int = 1
var _max_min: int = 30
var _blows: int = 0
var _clinks: int = 0
var _marks: Array = []
var _call: int = 0
var _listened_ms: int = 0
var _heard_good: bool = false
var _heard_dull: bool = false
var _heard_coin: Array = []
var _compared: bool = false
var _clinked: bool = false
## 轮着留在余音框里的线（不含钉住的样洋）。
var _held: Array = []
## 余音框钉住两枚样洋（ghosts >= 1 时）：甲在第一行、乙在最后一行；_good_pinned / _dull_pinned = 吹过了、钉在那儿了。
var _pin: bool = true
var _good_pinned: bool = false
var _dull_pinned: bool = false
var _salts: Dictionary = {}
var _ops: Array = []
## 键盘的“手”在哪一枚上（GOOD / DULL / 客人的第几枚）；按过键才画出来。
var _cursor: int = GOOD
var _cursor_shown: bool = false

var _panel: Panel
var _coin_row: Control
var _coin_faces: Array = []
var _samples: Control
var _sample_faces: Array = []
var _wave: WaveView
var _legend: Control
var _audio: RingAudio
var _call_btns: Array = []
var _chips: Array = []
var _dots: HBoxContainer
var _done_btn: Button
var _ghost: TextureRect
var _press_who: int = -100
var _press_pos := Vector2.ZERO
var _dragging: bool = false


func kind() -> StringName:
	return &"coin_ring"


func start(p_params: Dictionary) -> void:
	_clear_children()
	_read_params(p_params)
	_build_shell()
	_build_coins()
	_build_samples()
	_build_wave()
	_build_judgment()
	_build_legend()
	_build_foot()
	_build_audio()
	_register()
	_built = true
	_refresh()


## skill = 每个判断判对的概率（DESIGN P8）。先吹两枚样洋，再逐枚吹客人的；一摞的还剩吹次就碰一下；
## 判断用自动玩的“耳朵”（Obs.sounds_dull）出对的那一项，draw[9000 + i] >= skill 时换成相反的那一项。
func autoplay(skill: float) -> void:
	if _done or not _built:
		return
	var n := _coins.size()
	var order: Array = []
	if _tries_left >= n + 2:
		order = [GOOD, DULL]
	elif _tries_left >= n + 1:
		order = [GOOD]
	for i in range(n):
		order.append(i)
	for who in order:
		apply_op(["blow", who])
	if n >= 2 and _clink_ok and _tries_left > 0:
		apply_op(["clink", 0, 1])
	if n <= 1:
		var right := Obs.CALL_UNSURE
		if n == 1:
			right = Obs.CALL_DULL if Obs.sounds_dull(_coins[0], _good) else Obs.CALL_GOOD
		var wrong := Obs.CALL_GOOD if right == Obs.CALL_DULL else (Obs.CALL_DULL if right == Obs.CALL_GOOD else Obs.CALL_GOOD)
		apply_op(["call", right if _auto_right(0, skill) else wrong])
	else:
		for i in range(n):
			var right := Obs.MARK_DULL if Obs.sounds_dull(_coins[i], _good) else Obs.MARK_RING
			var wrong := Obs.MARK_RING if right == Obs.MARK_DULL else Obs.MARK_DULL
			apply_op(["mark", i, right if _auto_right(i, skill) else wrong])
	apply_op(["done"])


func _auto_right(i: int, skill: float) -> bool:
	return JevRng.draw(_seed, LAYOUT_DOMAIN, [AUTO_BASE + i]) < skill


## 唯一改局面的入口。不合法就返回 false、什么都不改。op 只含整数和短 ASCII 串：
##   ["blow", who]  who = -1 足银样洋、-2 哑板样洋、0..n-1 客人的第几枚；花一次吹次
##   ["clink", i, j] 客人的两枚相碰；花一次吹次
##   ["mark", i, m] 一摞里第 i 枚标 0 没定 / 1 响 / 2 哑
##   ["call", c]    单枚：1 像足银的、2 像哑板、3 说不好
##   ["done"]       听好了
func apply_op(op: Array) -> bool:
	if _done or not _built or op.is_empty():
		return false
	var name := str(op[0])
	var args: Array = []
	for k in range(1, op.size()):
		if not _is_int(op[k]):
			return false
		args.append(int(op[k]))
	var ok := false
	match name:
		"blow":
			ok = args.size() == 1 and _blow(args[0])
		"clink":
			ok = args.size() == 2 and _clink(args[0], args[1])
		"mark":
			ok = args.size() == 2 and _mark(args[0], args[1])
		"call":
			ok = args.size() == 1 and _set_call(args[0])
		"done":
			ok = args.is_empty()
	if not ok:
		return false
	var logged: Array = [name]
	logged.append_array(args)
	_ops.append(logged)
	if name == "done":
		_finish()
	return true


func ops_log() -> Array:
	return _ops.duplicate(true)


## 玩家关掉（Esc 或宿主的“算了”）：只扣已经花掉的钟点，交空观察。
func abort() -> void:
	if _done:
		return
	_done = true
	_end_drag()
	if _audio != null:
		_audio.stop()
	super.abort()


## The host's abort spot: right of "listened" in the bottom row (DESIGN §5.9: (972, 620) on screen).
func abort_rect() -> Rect2:
	if _panel == null:
		return Rect2()
	return Chrome.abort_at(_panel, ABORT_SPOT, Chrome.BUTTON_H)


## 键盘（合同 §1.2、§8.2：键盘能玩完；Esc = abort()），和鼠标走同一批 op：
## ← / → 把“手”在 甲、乙、客人的几枚之间挪（一圈金线），Space / Enter 吹手上这枚；一摞时 C 拿手上这枚碰下一枚；
## 单枚 1 / 2 / 3 = 像足银的 / 像哑板 / 说不好；一摞给手上这枚标 1 响、2 哑、3 / 0 / Delete 没定；F 听好了。
## 在 _input 里接（GUI 之前），手牌那边有焦点时方向键也不会被焦点导航吃掉；F1 和带 Ctrl / Alt 的键不管。
func _input(event: InputEvent) -> void:
	if not _built or _done or not is_inside_tree():
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
	if code == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		abort()
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	if _on_key(code):
		get_viewport().set_input_as_handled()


func _on_key(code: int) -> bool:
	if code == KEY_LEFT or code == KEY_RIGHT:
		_move_cursor(-1 if code == KEY_LEFT else 1)
	elif code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		_show_cursor()
		apply_op(["blow", _cursor])
	elif code == KEY_C:
		_show_cursor()
		if _cursor >= 0 and _coins.size() >= 2:
			apply_op(["clink", _cursor, (_cursor + 1) % _coins.size()])
	elif code == KEY_F:
		apply_op(["done"])
	else:
		return _judge_key(_digit(code))
	return true


## 数字键：单枚是三个选项，一摞是给手上这枚标记。别的键不管。
func _judge_key(d: int) -> bool:
	if _coins.size() < 2:
		if d < Obs.CALL_GOOD or d > Obs.CALL_UNSURE:
			return false
		apply_op(["call", d])
		return true
	if d < 0 or d > 3:
		return false
	_show_cursor()
	if _cursor >= 0:
		apply_op(["mark", _cursor, [Obs.MARK_UNSET, Obs.MARK_RING, Obs.MARK_DULL, Obs.MARK_UNSET][d]])
	return true


static func _digit(code: int) -> int:
	if code >= KEY_0 and code <= KEY_9:
		return code - KEY_0
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return code - KEY_KP_0
	if code == KEY_DELETE or code == KEY_BACKSPACE:
		return 0
	return -1


## 挪“手”：甲 → 乙 → 客人的第一枚 …… 绕回甲。还没画出来时第一下只把它画出来。
func _move_cursor(step: int) -> void:
	if not _cursor_shown:
		_show_cursor()
		return
	var order: Array = [GOOD, DULL]
	order.append_array(range(_coins.size()))
	var at := maxi(order.find(_cursor), 0)
	_cursor = int(order[posmod(at + step, order.size())])
	_sync_cursor()


func _show_cursor() -> void:
	_cursor_shown = true
	_sync_cursor()


func _sync_cursor() -> void:
	for k in range(_sample_faces.size()):
		(_sample_faces[k] as Face).set_cursor(_cursor_shown and _cursor == (GOOD if k == 0 else DULL))
	for i in range(_coin_faces.size()):
		(_coin_faces[i] as Face).set_cursor(_cursor_shown and _cursor == i)


# ---------------- 局面 ----------------

func _blow(who: int) -> bool:
	if _tries_left <= 0:
		return false
	var spec := _spec_of(who)
	if spec.is_empty():
		return false
	_tries_left -= 1
	_blows += 1
	_listened_ms += int(spec.get("ring_ms", 0))
	if who == GOOD:
		_heard_good = true
	elif who == DULL:
		_heard_dull = true
	else:
		_heard_coin[who] = true
	_hold(who)
	_cursor = who
	if who >= 0 and (_good_pinned or _dull_pinned or _held.has(GOOD) or _held.has(DULL)):
		_compared = true
	_spend()
	_emit_tool("blow")
	if _wave != null:
		_wave.fast_anim = _fast()
		_wave.add_line(who, spec, _salt(who), _row_label(who), _row_pips(who))
	var face := _face_of(who)
	if face != null:
		face.pinch(_fast())
	if _audio != null:
		_audio.play_ring(spec, _salt(who))
	_refresh()
	return true


func _clink(i: int, j: int) -> bool:
	var n := _coins.size()
	if not _clink_ok or _tries_left <= 0 or i == j or i < 0 or j < 0 or i >= n or j >= n:
		return false
	_tries_left -= 1
	_clinks += 1
	_clinked = true
	_hold(CLINK_ROW)
	_spend()
	_emit_tool("clink")
	var d := Obs.clink_dullness(_coins[i], _coins[j], _good)
	var salt := _salt(100 + mini(i, j) * 8 + maxi(i, j))
	if _wave != null:
		_wave.fast_anim = _fast()
		_wave.add_line(CLINK_ROW, {}, salt, CardText.ui("c13.label.clink"), 0, d)
	for k in [i, j]:
		var face := _face_of(k)
		if face != null:
			face.pinch(_fast())
	if _audio != null:
		_audio.play_clink(d, salt)
	_refresh()
	return true


func _mark(i: int, m: int) -> bool:
	if _coins.size() < 2 or i < 0 or i >= _coins.size() or m < Obs.MARK_UNSET or m > Obs.MARK_DULL:
		return false
	_marks[i] = m
	_emit_tool("mark")
	_refresh()
	return true


func _set_call(c: int) -> bool:
	if _coins.size() >= 2 or c < Obs.CALL_GOOD or c > Obs.CALL_UNSURE:
		return false
	_call = c
	_emit_tool("call")
	_refresh()
	return true


func _finish() -> void:
	_done = true
	_end_drag()
	var n := _coins.size()
	var all_heard := n > 0
	for h in _heard_coin:
		all_heard = all_heard and bool(h)
	var marks: Array = _marks.duplicate()
	if n <= 1:
		marks = [_mark_for_call(_call)] if n == 1 else []
	_refresh()
	finished.emit({
		"quality_permille": Obs.quality_permille(_heard_good and _heard_dull, all_heard, _compared),
		"observations": Obs.observations(n, _call, _marks),
		"minutes": _minutes_spent,
		"measures": {"blows": _blows, "clinks": _clinks, "marks": marks, "call": _call,
			"listened_ms": _listened_ms, "compared": _compared, "clinked": _clinked},
		"aborted": false,
	})


func _mark_for_call(c: int) -> int:
	if c == Obs.CALL_GOOD:
		return Obs.MARK_RING
	if c == Obs.CALL_DULL:
		return Obs.MARK_DULL
	return Obs.MARK_UNSET


## 余音框里留着的线（和画面上一样）：甲、乙各钉一行，客人的（和相碰的）轮着放中间 ghosts 行。
func _hold(who: int) -> void:
	if _pin and who == GOOD:
		_good_pinned = true
		return
	if _pin and who == DULL:
		_dull_pinned = true
		return
	_held.append(who)
	while _held.size() > _rolling:
		_held.pop_front()


func _spend() -> void:
	_minutes_spent = mini((_blows + _clinks) * _step_min, _max_min)


func _spec_of(who: int) -> Dictionary:
	if who == GOOD:
		return _good
	if who == DULL:
		return _dull
	if who >= 0 and who < _coins.size():
		return _coins[who]
	return {}


func _salt(k: int) -> int:
	if not _salts.has(k):
		_salts[k] = int(JevRng.draw(_seed, LAYOUT_DOMAIN, [SALT_BASE + k + 2]) * 1000000.0)
	return int(_salts[k])


static func _is_int(v) -> bool:
	if typeof(v) == TYPE_INT:
		return true
	return typeof(v) == TYPE_FLOAT and float(v) == floorf(float(v)) and absf(float(v)) < 1000000.0


func _read_params(p_params: Dictionary) -> void:
	params = p_params.duplicate(true)
	_done = false
	_seed = int(params.get("seed", 0))
	_coins = []
	var rows = params.get("coins", [])
	if typeof(rows) == TYPE_ARRAY:
		for row in rows:
			if typeof(row) == TYPE_DICTIONARY and _coins.size() < MAX_COINS:
				_coins.append(_clean_spec(row))
	var ref = params.get("reference", {})
	var reference: Dictionary = _clean_spec(ref) if typeof(ref) == TYPE_DICTIONARY and not (ref as Dictionary).is_empty() else {}
	_good = reference if not reference.is_empty() else DEFAULT_GOOD.duplicate()
	_dull = DEFAULT_DULL.duplicate()
	var samples = params.get("samples", [])
	if typeof(samples) == TYPE_ARRAY:
		var plain: Array = []
		for s in samples:
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var id := str(s.get("id", ""))
			if id == "good":
				_good = _clean_spec(s)
			elif id == "dull":
				_dull = _clean_spec(s)
			else:
				plain.append(s)
		# Samples without ids: first = the good one, second = the dull one.
		if plain.size() >= 1 and not _has_id(samples, "good"):
			_good = _clean_spec(plain[0])
		if plain.size() >= 2 and not _has_id(samples, "dull"):
			_dull = _clean_spec(plain[1])
	_art_id = str(params.get("art", ""))
	_tries_total = maxi(int(params.get("tries", 3)), 0)
	_tries_left = _tries_total
	# ghosts 0：框里只一道最近的线；1..：甲、乙各钉一行，中间 ghosts 行（最多两行）放客人的。
	var ghosts := clampi(int(params.get("ghosts", 1)), 0, WaveView.MAX_ROWS - 2)
	_pin = ghosts >= 1
	_rolling = ghosts if _pin else 1
	_good_pinned = false
	_dull_pinned = false
	_clink_ok = _coins.size() >= 2 and bool(params.get("clink", true))
	_step_min = maxi(int(params.get("minutes_per_step", 1)), 0)
	_max_min = maxi(int(params.get("max_minutes", 30)), 0)
	_minutes_spent = 0
	_blows = 0
	_clinks = 0
	_marks = []
	_heard_coin = []
	for _i in range(_coins.size()):
		_marks.append(Obs.MARK_UNSET)
		_heard_coin.append(false)
	_call = Obs.CALL_NONE
	_listened_ms = 0
	_heard_good = false
	_heard_dull = false
	_compared = false
	_clinked = false
	_held = []
	_salts = {}
	_ops = []
	_cursor = GOOD
	_cursor_shown = false


static func _has_id(rows: Array, id: String) -> bool:
	for s in rows:
		if typeof(s) == TYPE_DICTIONARY and str(s.get("id", "")) == id:
			return true
	return false


static func _clean_spec(row: Dictionary) -> Dictionary:
	return {"ring_ms": int(row.get("ring_ms", 0)), "pitch_cents": int(row.get("pitch_cents", 0)),
		"buzz": int(row.get("buzz", 0))}


# ---------------- 画面 ----------------

func _clear_children() -> void:
	_built = false
	_audio = null
	_wave = null
	_legend = null
	_panel = null
	_coin_row = null
	_samples = null
	_dots = null
	_done_btn = null
	_ghost = null
	_coin_faces = []
	_sample_faces = []
	_call_btns = []
	_chips = []
	_press_who = -100
	_dragging = false
	var old := get_children()
	for c in old:
		remove_child(c)
		c.free()


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = CardTheme.color(&"shade")
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", Chrome.frame())
	_panel.position = PANEL_POS
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	add_child(_panel)
	var title := Chrome.title(CardText.ui("c13.title"), CardText.is_draft("c13.title"), PANEL_SIZE.x)
	title.clip_text = true
	_panel.add_child(title)


func _build_coins() -> void:
	_coin_row = Control.new()
	_coin_row.name = "Coins"
	_coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_coin_row)
	var n := maxi(_coins.size(), 1)
	var stack := _coins.size() >= 2
	var tex := CardArt.texture(_art_id)
	var px := _art_px(_art_id, 128 if stack else 192)
	var face_w := float(px.x) + Face.PAD * 2.0
	var step := maxf(STACK_STEP, face_w + 16.0) if stack else face_w
	var width := step * float(n - 1) + face_w
	if stack:
		_coin_row.position = Vector2(round((PANEL_SIZE.x - width) * 0.5), STACK_Y - Face.PAD)
	else:
		_coin_row.position = COIN_ONE.position - Vector2(Face.PAD, Face.PAD)
	_coin_row.size = Vector2(width, float(px.y) + Face.PAD * 2.0)
	for i in range(n):
		var face := Face.new()
		face.name = "Coin%d" % i
		face.setup(tex, px, false, i + 1 if stack else 0)
		face.position = Vector2(step * float(i), 0)
		face.tooltip_text = CardText.ui("c13.tool.blow")
		if i < _coins.size():
			face.gui_input.connect(_on_coin_input.bind(i))
		else:
			face.set_live(false)
		_coin_row.add_child(face)
		_coin_faces.append(face)
		if stack:
			var chip := _small_button("c13.mark.unset")
			chip.name = "Mark%d" % i
			chip.position = _coin_row.position + face.position + Vector2(Face.PAD, CHIP_Y - _coin_row.position.y)
			chip.size = Vector2(px.x, CHIP_H)
			chip.pressed.connect(_on_chip.bind(i))
			_panel.add_child(chip)
			_chips.append(chip)
	if not stack:
		var cap := _note("c13.coin.this")
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cap.position = Vector2(COIN_ONE.position.x - 220.0, COIN_ONE.end.y - 28.0)
		cap.size = Vector2(200, 24)
		_panel.add_child(cap)


func _build_samples() -> void:
	_samples = Control.new()
	_samples.name = "Samples"
	_samples.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r0: Rect2 = SAMPLE_RECTS[0]
	var r1: Rect2 = SAMPLE_RECTS[1]
	_samples.position = r0.position
	_samples.size = Vector2(r1.end.x - r0.position.x, r0.size.y + 46.0)
	_panel.add_child(_samples)
	var tex := CardArt.texture(SAMPLE_ART)
	var px := _art_px(SAMPLE_ART, 128)
	for k in range(2):
		var who := GOOD if k == 0 else DULL
		var rect: Rect2 = SAMPLE_RECTS[k]
		var face := Face.new()
		face.name = "SampleGood" if who == GOOD else "SampleDull"
		face.setup(tex, px, who == DULL, 0)
		face.position = rect.position - r0.position + (rect.size - face.size) * 0.5
		face.tooltip_text = CardText.ui("c13.tool.blow")
		face.gui_input.connect(_on_sample_input.bind(who))
		_samples.add_child(face)
		_sample_faces.append(face)
		var tag := Chrome.label(CardText.ui("c13.label.a" if who == GOOD else "c13.label.b"), 16,
			CardText.is_draft("c13.label.a" if who == GOOD else "c13.label.b"))
		tag.add_theme_color_override("font_color", Chrome.paper_ink(false))
		tag.position = face.position + Vector2(10, 6)
		tag.size = Vector2(28, 22)
		_samples.add_child(tag)
		var key := "c13.sample.good" if who == GOOD else "c13.sample.dull"
		var cap := _note(key)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.position = Vector2(rect.position.x - r0.position.x - 8.0, CAPTION_Y - r0.position.y)
		cap.size = Vector2(rect.size.x + 16.0, 22)
		_samples.add_child(cap)


func _build_wave() -> void:
	var inset := Chrome.plate(Chrome.inset(), WAVE_RECT.position, WAVE_RECT.size)
	inset.name = "WaveInset"
	_panel.add_child(inset)
	_wave = WaveView.new()
	_wave.name = "Wave"
	_wave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave.position = WAVE_RECT.position
	_wave.size = WAVE_RECT.size
	_panel.add_child(_wave)
	_wave.setup(_rolling, _fast(), _pin, {GOOD: CardText.ui("c13.label.a"), DULL: CardText.ui("c13.label.b")})


func _build_judgment() -> void:
	var note := _note("c13.note.stack" if _coins.size() >= 2 else "c13.note")
	note.name = "Note"
	note.position = NOTE_RECT.position
	note.size = NOTE_RECT.size
	note.clip_text = true
	_panel.add_child(note)
	if _coins.size() >= 2:
		return
	var keys := ["c13.call.like_good", "c13.call.like_dull", "c13.call.unsure"]
	for k in range(3):
		var b := Chrome.button(CardText.ui(keys[k]))
		b.name = "Call%d" % (k + 1)
		var rect: Rect2 = CALL_RECTS[k]
		b.position = rect.position
		b.size = rect.size
		b.custom_minimum_size = rect.size
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_call.bind(k + 1))
		_panel.add_child(b)
		_call_btns.append(b)


## How to read the lines and what to compare, always on screen (rules of the game, the same for every coin).
## One coin: two small plates either side of the coin, "how to read a line" on the left and "how to compare" on
## the right. A roll: three lines where a single coin's calls would be (the legend on one line, then the rules).
func _build_legend() -> void:
	_legend = Control.new()
	_legend.name = "Legend"
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.size = PANEL_SIZE
	_panel.add_child(_legend)
	if _coins.size() >= 2:
		var box := _legend_box(LEGEND_STACK, false)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 24)
		box.add_child(row)
		for key in LEGEND_KEYS:
			row.add_child(_legend_line(key, 14, -1.0))
		for key in RULE_KEYS:
			box.add_child(_legend_line(key, 14, -1.0, true))
		return
	var read := _legend_box(LEGEND_ONE, true)
	read.add_child(_legend_line("c13.legend.title", 16, -1.0, true))
	for key in LEGEND_KEYS:
		read.add_child(_legend_line(key, 15, -1.0))
	var rule := _legend_box(RULE_ONE, true)
	rule.add_child(_legend_line("c13.rule.title", 16, -1.0, true))
	for key in RULE_KEYS:
		rule.add_child(_legend_line(key, 14, RULE_ONE.size.x - LEGEND_PAD.x * 2.0, true))


## A column of lines at rect (panel coordinates), on a dark inset plate when plated.
func _legend_box(rect: Rect2, plated: bool) -> VBoxContainer:
	if plated:
		var plate := Chrome.plate(Chrome.inset(), rect.position, rect.size)
		plate.name = "Plate%d" % _legend.get_child_count()
		_legend.add_child(plate)
	var box := VBoxContainer.new()
	box.name = "Lines%d" % _legend.get_child_count()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3 if plated else 1)
	var pad := LEGEND_PAD if plated else Vector2.ZERO
	box.position = rect.position + pad
	box.size = rect.size - pad * 2.0
	_legend.add_child(box)
	return box


## One legend line from CardText: the legend in the secondary ink, titles and rules in the body ink.
## wrap_w > 0 wraps the line at that width; otherwise it is one line, sized to its text.
func _legend_line(key: String, font_size: int, wrap_w: float, strong: bool = false) -> Label:
	var draft := CardText.is_draft(key)
	var l := Chrome.label(CardText.ui(key), font_size, draft)
	l.name = key.get_slice(".", 1) + "_" + key.get_slice(".", 2)
	l.add_theme_color_override("font_color", Chrome.ink(draft) if strong else CardTheme.color(&"text_3" if draft else &"text_2"))
	if wrap_w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(wrap_w, 0)
	return l


func _build_foot() -> void:
	var row := HBoxContainer.new()
	row.name = "Tries"
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.position = TRIES_RECT.position
	row.size = TRIES_RECT.size
	_panel.add_child(row)
	var label := _note("c13.tries")
	label.clip_text = false
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 6)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_dots)
	_done_btn = Chrome.button(CardText.ui("c13.btn.done"), true)
	_done_btn.name = "Done"
	_done_btn.position = DONE_RECT.position
	_done_btn.size = DONE_RECT.size
	_done_btn.custom_minimum_size = DONE_RECT.size
	_done_btn.add_theme_font_size_override("font_size", 16)
	_done_btn.pressed.connect(func() -> void: apply_op(["done"]))
	_panel.add_child(_done_btn)


func _build_audio() -> void:
	_audio = RingAudio.new()
	_audio.name = "Audio"
	add_child(_audio)


func _register() -> void:
	CardAnchors.register(&"a.mg.coin_ring.main", _panel)
	CardAnchors.register(&"a.mg.coin_ring.blow", _coin_row)
	CardAnchors.register(&"a.mg.coin_ring.ear", _wave)
	# WP0 may add this anchor for a new guide step; register it only once it exists.
	if CardIds.is_known_anchor("a.mg.coin_ring.samples"):
		CardAnchors.register(&"a.mg.coin_ring.samples", _samples)


func _note(key: String) -> Label:
	var l := Chrome.note(CardText.ui(key), CardText.is_draft(key))
	l.clip_text = true
	return l


func _small_button(key: String) -> Button:
	var b := Chrome.button(CardText.ui(key))
	b.theme_type_variation = &"SmallButton"
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 16)
	return b


static func _art_px(art_id: String, cap: int) -> Vector2i:
	var base := CardArt.base_size(art_id)
	if base.x < 1 or base.y < 1:
		base = Vector2i(64, 64)
	var k := maxi(mini(cap / base.x, cap / base.y), 1)
	return Vector2i(base.x * k, base.y * k)


func _refresh() -> void:
	if _panel == null:
		return
	var open := not _done and _tries_left > 0
	for i in range(_coin_faces.size()):
		(_coin_faces[i] as Face).set_live(open and i < _coins.size())
	for f in _sample_faces:
		(f as Face).set_live(open)
	for k in range(_call_btns.size()):
		_pen(_call_btns[k], _call == k + 1)
		(_call_btns[k] as Button).disabled = _done
	for i in range(_chips.size()):
		var m := int(_marks[i])
		var chip := _chips[i] as Button
		chip.text = CardText.ui(["c13.mark.unset", "c13.mark.ring", "c13.mark.dull"][m])
		_pen(chip, m != Obs.MARK_UNSET)
		chip.disabled = _done
	if _done_btn != null:
		_done_btn.disabled = _done
	_sync_cursor()
	_rebuild_dots()


## 玩家的笔：选中的那一项一圈金边、金字（不分对错，DESIGN P5）。
func _pen(b: Button, on: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		if on:
			var sb := CardTheme.button_style(&"btn_top", &"btn_bot", &"gold_hi", 10.0, 4.0, 6)
			b.add_theme_stylebox_override(state, sb)
		else:
			b.remove_theme_stylebox_override(state)
	for slot in ["font_color", "font_hover_color", "font_pressed_color"]:
		if on:
			b.add_theme_color_override(slot, CardTheme.color(&"gold_hi"))
		else:
			b.remove_theme_color_override(slot)


func _rebuild_dots() -> void:
	if _dots == null:
		return
	for c in _dots.get_children():
		_dots.remove_child(c)
		c.free()
	for i in range(_tries_total):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = CardTheme.color(&"gold_hi" if i < _tries_left else &"line")
		_dots.add_child(dot)


func _row_label(who: int) -> String:
	if who == GOOD:
		return CardText.ui("c13.label.a")
	if who == DULL:
		return CardText.ui("c13.label.b")
	return CardText.ui("c13.label.coin")


func _row_pips(who: int) -> int:
	return who + 1 if who >= 0 and _coins.size() >= 2 else 0


func _face_of(who: int) -> Face:
	if who == GOOD and _sample_faces.size() > 0:
		return _sample_faces[0]
	if who == DULL and _sample_faces.size() > 1:
		return _sample_faces[1]
	if who >= 0 and who < _coin_faces.size():
		return _coin_faces[who]
	return null


func _fast() -> bool:
	return fast_anim or CardSettings.fast_anim()


# ---------------- 鼠标 → op ----------------

func _on_sample_input(event: InputEvent, who: int) -> void:
	if not (event is InputEventMouseButton) or _done:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var face := _face_of(who)
	if mb.pressed:
		_press_who = who
		return
	if _press_who == who and face != null and Rect2(Vector2.ZERO, face.size).has_point(mb.position):
		apply_op(["blow", who])
	_press_who = -100


func _on_coin_input(event: InputEvent, i: int) -> void:
	if _done:
		return
	var face := _face_of(i)
	if face == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var at := face.global_position + mb.position
		if mb.pressed:
			_press_who = i
			_press_pos = at
			_dragging = false
			return
		if _press_who != i:
			return
		var target := _coin_at(at)
		if _dragging:
			if target >= 0 and target != i:
				apply_op(["clink", i, target])
		elif target == i:
			apply_op(["blow", i])
		_end_drag()
	elif event is InputEventMouseMotion and _press_who == i:
		var at := face.global_position + (event as InputEventMouseMotion).position
		if not _dragging and _clink_ok and _tries_left > 0 and at.distance_to(_press_pos) > DRAG_PX:
			_dragging = true
			_show_ghost(i)
		if _dragging and _ghost != null:
			# Held by its lower-left edge, so the coin under the cursor (the one it will hit) stays visible.
			_ghost.global_position = at + GHOST_OFFSET - Vector2(0, _ghost.size.y)
			var target := _coin_at(at)
			for k in range(_coin_faces.size()):
				(_coin_faces[k] as Face).set_hover(k == target and k != i)


func _coin_at(at: Vector2) -> int:
	for i in range(mini(_coin_faces.size(), _coins.size())):
		if (_coin_faces[i] as Control).get_global_rect().has_point(at):
			return i
	return -1


func _show_ghost(i: int) -> void:
	var face := _face_of(i)
	if face == null:
		return
	_ghost = TextureRect.new()
	_ghost.name = "DragCoin"
	_ghost.texture = face.art().texture
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_SCALE
	_ghost.size = face.art().size
	_ghost.modulate = Color(1, 1, 1, 0.7)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)


func _end_drag() -> void:
	if _dragging:
		for f in _coin_faces:
			(f as Face).set_hover(false)
	_press_who = -100
	_dragging = false
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _on_call(c: int) -> void:
	apply_op(["call", c])


func _on_chip(i: int) -> void:
	if i < 0 or i >= _marks.size():
		return
	apply_op(["mark", i, (int(_marks[i]) + 1) % 3])


# ---------------- 总线 ----------------

func _emit_tool(tool: String) -> void:
	var found := _resolve_bus()
	if found == null:
		return
	found.ui_event.emit(&"mg_tool", {"kind": "coin_ring", "tool": tool})


func _resolve_bus() -> CardEventBus:
	if bus != null:
		return bus
	var node: Node = get_parent()
	while node != null:
		var candidate = node.get("bus")
		if candidate is CardEventBus:
			return candidate
		node = node.get_parent()
	if is_inside_tree():
		var auto := get_node_or_null("/root/CardBus")
		if auto is CardEventBus:
			return auto
	return null
