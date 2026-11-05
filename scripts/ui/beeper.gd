# 音效：对白“嘀嘀”声（按人物音高区分，不用人声配音）、算盘珠/点击声、电报滴答。全部程序合成，无外部素材。
extends Node

var player: AudioStreamPlayer
var playback: AudioStreamGeneratorPlayback = null
var rate: float = 22050.0
var enabled: bool = true
var muted: bool = false   # 游戏内静音开关（M 键 / 右上角按钮）；默认有声
var ticks_sounded: int = 0   # 逐字嘀嗒实际“该响”的次数（静音、空白不计；无界面下也计，供测试）

signal mute_changed(muted)

# 句读：句末降得多、句中降得少；嘀嗒时长与对白停顿都按这个分级
const PUNCT_STOP := "。！？!?…"
const PUNCT_PAUSE := "，、；：,;:—"

func _ready() -> void:
	if DisplayServer.get_name() == "headless" or str(AudioServer.get_driver_name()) == "Dummy":
		enabled = false   # 无界面测试不开音频（哑音频驱动下生成器会在退出时残留）
		return
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = rate
	gen.buffer_length = 0.5
	player.stream = gen
	player.volume_db = -14.0
	add_child(player)
	player.play()
	playback = player.get_stream_playback()

func set_muted(m: bool) -> void:
	if muted == m:
		return
	muted = m
	emit_signal("mute_changed", muted)

func toggle_mute() -> void:
	set_muted(not muted)

func _tone(freq: float, dur: float, vol: float = 0.25, square: bool = true) -> void:
	if muted or not enabled or playback == null:
		return
	var n := int(rate * dur)
	if playback.get_frames_available() < n:
		return
	var phase := 0.0
	for i in range(n):
		phase += freq / rate
		var s := (1.0 if fmod(phase, 1.0) < 0.5 else -1.0) if square else sin(phase * TAU)
		var env := 1.0 - float(i) / n
		playback.push_frame(Vector2.ONE * s * vol * env)

# 木头碰撞（卸门板 / 上门板）：低频噪声衰减
func _thud(times: int) -> void:
	if muted or not enabled or playback == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in range(times):
		var n := int(rate * 0.09)
		if playback.get_frames_available() < n * 2:
			return
		var lp := 0.0
		for i in range(n):
			lp = lp * 0.86 + rng.randf_range(-1.0, 1.0) * 0.14
			var env := pow(1.0 - float(i) / n, 2.0)
			playback.push_frame(Vector2.ONE * (lp * 2.2 + sin(i * TAU * 90.0 / rate) * 0.3) * env * 0.5)
		for i in range(int(rate * 0.07)):
			playback.push_frame(Vector2.ZERO)

func play(name: String) -> void:
	match name:
		"door_open", "door_close":
			_thud(3)
		"coins":
			for i in range(3):
				_tone(2400.0 + i * 380.0, 0.03, 0.12, false)
		"stamp":
			_thud(1)
		"page":
			_tone(300.0, 0.02, 0.05)
		"boots":
			_thud(2)

func beep(pitch: float = 1.0) -> void:
	_tone(520.0 * pitch, 0.035, 0.12)

# 打字机逐字嘀嗒：一字一声，极短；标点降调（句末更低），空白不响。返回是否“该响”。
static func punct_level(ch: String) -> int:
	if ch == "":
		return 0
	if PUNCT_STOP.contains(ch):
		return 2
	if PUNCT_PAUSE.contains(ch):
		return 1
	return 0

func tick(ch: String, pitch: float = 1.0) -> bool:
	if muted or ch.strip_edges() == "":
		return false
	ticks_sounded += 1
	match punct_level(ch):
		2:
			_tone(520.0 * pitch * 0.62, 0.05, 0.10)
		1:
			_tone(520.0 * pitch * 0.8, 0.03, 0.10)
		_:
			_tone(520.0 * pitch, 0.018, 0.11)
	return true

func click() -> void:
	_tone(1400.0, 0.012, 0.18)

func morse(n: int) -> void:
	for i in range(mini(n * 3, 10)):
		_tone(760.0, 0.05 if i % 3 != 1 else 0.13, 0.15, false)

func _exit_tree() -> void:
	playback = null
	if player != null:
		player.stop()
		player.stream = null
