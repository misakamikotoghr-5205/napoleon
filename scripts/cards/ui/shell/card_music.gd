# 卡牌版曲目：读 data/cards/audio/music.json。普通/带 AI 声明版按人工 → AI →（开发/试玩版）旧曲 → 静音查找；
# 不带声明版（导出特性 no_ai，见 #218 的 export_presets.cfg）只认人工，绝不选 AI，缺曲静音，
# 正式包缺人工曲由 K15 审核报错（#212-3/#202）。
# legacy 层（10-22 能玩版）：指向 v0.4 的 audio/music/*.ogg，和美术 legacy 一样只在非发行版（不是 CardShip.is_ship()）用；
# 发行版、no_ai 都跳过。曲子一律循环（ogg 导入是 loop=false，照 scripts/audio/music_director.gd 的 _apply_loop 在流上设）。
# 主人 C16；#212-1，W2_HANDOFF.md 的 10-18 决定。
extends Node

const MANIFEST := "res://data/cards/audio/music.json"
const PHASE_CUE := {
	"boot": "day",
	"month_open": "day",
	"morning": "day",
	"day": "day",
	"night": "night",
	"settle": "day",
	"month_close": "month_close",
	"year_jump": "year_jump",
}

var _cues: Dictionary = {}
var _player: AudioStreamPlayer
var _volume: float = 1.0
var _path: String = ""
## 与 CardArt（#218）同一开关：OS.has_feature("no_ai")。测试可改写以验证纯人工包。
var no_ai: bool = OS.has_feature("no_ai")
## 旧曲层只在非发行版用（和 CardArt 的 legacy 一样）。测试可改写。
var allow_legacy: bool = not CardShip.is_ship()


func _ready() -> void:
	_load()
	_player = AudioStreamPlayer.new()
	add_child(_player)


## cue: title / day / night / month_close / year_jump. Missing files stay silent.
## 同一首已经在放（比如 morning → day 都是 day）就接着放，不从头再来。
func play(cue: StringName) -> void:
	if _player == null:
		return
	var path := _resolve(str(cue))
	if path != "" and path == _path and _player.stream != null and (_player.playing or _dummy_audio()):
		_apply_volume()
		return
	_player.stop()
	_path = ""
	if path == "":
		_player.stream = null
		return
	var res = load(path)
	if not (res is AudioStream):
		_player.stream = null
		return
	_loop(res as AudioStream)
	_player.stream = res as AudioStream
	_path = path
	_apply_volume()
	if _dummy_audio():
		return
	_player.play()


func set_volume(linear: float) -> void:
	_volume = clampf(linear, 0.0, 1.0)
	_apply_volume()


## Listen for phase_changed and swap cues. Listed for C01 to call.
func bind(p_bus: CardEventBus) -> void:
	if p_bus == null:
		return
	if not p_bus.phase_changed.is_connected(_on_phase):
		p_bus.phase_changed.connect(_on_phase)


func _on_phase(_from: StringName, to: StringName) -> void:
	var key := str(to)
	if not PHASE_CUE.has(key):
		return
	play(StringName(str(PHASE_CUE[key])))


func _load() -> void:
	var doc = CardDB.read_json(MANIFEST)
	if typeof(doc) != TYPE_DICTIONARY:
		return
	var cues = doc.get("cues")
	if typeof(cues) == TYPE_DICTIONARY:
		_cues = cues


func _resolve(cue: String) -> String:
	var entry = _cues.get(cue)
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	var layers: Array[String] = ["human"]
	if not no_ai:
		layers.append("ai")
		if allow_legacy:
			layers.append("legacy")
	for layer: String in layers:
		var relative := str(entry.get(layer, ""))
		if relative == "":
			continue
		var path := "res://" + relative
		# ResourceLoader also recognizes imported resources in exported packs.
		if ResourceLoader.exists(path) or FileAccess.file_exists(path):
			return path
	return ""


## Card cues are loops (title / day / night / month_close / year_jump all hold a scene).
func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		var ogg: AudioStreamOggVorbis = stream
		ogg.loop = true
		ogg.loop_offset = 0.0
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true


func _apply_volume() -> void:
	if _player == null:
		return
	if _volume <= 0.0:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(_volume)


func _dummy_audio() -> bool:
	if OS.has_feature("headless"):
		return true
	var name := AudioServer.get_driver_name()
	return name == "Dummy" or name == ""
