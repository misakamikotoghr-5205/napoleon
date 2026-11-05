# 吹银元的声音。每一声都从这枚银元的物理量来（coin_ring_voice.gd）：音高跟 pitch_cents、余音长短跟 ring_ms、
# 沙声跟 buzz（连续，不再只看阈值）。找样本的顺序和曲目一样：人录的 audio/cards/sfx/<id>.ogg →
# AI 线 audio/ai/sfx/manifest.json 里登记的 ai 路径（带 no_ai 特性的包跳过）→ 开发版合成（发行版不合成，静音）。
# 音量跟设置里的“音效”（旧四键文件 user://settings.json 的 sfx，0 = 不出声）。无头或 Dummy 驱动不建播放器。
# 合成（建 AudioStreamWAV、填样本）都写在 `if not CardShip.is_ship():` 里面。主人 C13。合同：§0 红线 1、§8.2、§11.4。
# 样本 id（人录的放 audio/cards/sfx/，AI 线放 audio/ai/sfx/ 并在 manifest.json 登记 _provenance）：
#   coin_ring_ring        银元余音，干、长，约 1.6 秒（按 pitch_cents 改 pitch_scale、按 ring_ms 淡出）
#   coin_ring_buzz        杂音层，约 1.6 秒（音量跟 buzz）
#   coin_ring_clink       两枚相碰，都清脆，约 0.15 秒
#   coin_ring_clink_dull  两枚相碰、其中一枚闷，约 0.15 秒
extends Node

const Voice = preload("res://scripts/cards/minigames/coin_ring/coin_ring_voice.gd")
const SettingsScript = preload("res://scripts/town/settings.gd")

const HUMAN_DIR := "res://audio/cards/sfx/"
const AI_MANIFEST := "res://audio/ai/sfx/manifest.json"
const RING_ID := "coin_ring_ring"
const BUZZ_ID := "coin_ring_buzz"
const CLINK_ID := "coin_ring_clink"
const CLINK_DULL_ID := "coin_ring_clink_dull"
## 32 kHz: the third partial (5.4 x f0) stays under Nyquist for every pitch the specs use (-320..+300 cents).
const MIX := 32000
const BASE_DB := -6.0
const MUTED_DB := -80.0
const FADE_TO_DB := -60.0
## 相碰闷度（0..1000）到这里起换录好的“闷”的那一声；合成是连续的，不用这个。
const CLINK_DULL_FROM := 300

## 设置文件（旧四键）；测试可改写。sfx_override >= 0 时不读文件。
var settings_path: String = "user://settings.json"
var sfx_override: int = -1
## 与 CardArt / CardMusic 同一开关：不带 AI 声明的包不用 AI 线的样本。
var no_ai: bool = OS.has_feature("no_ai")
## 最后一次要出的声音是怎么出的（测试看）：{kind, route: sample|synth|silent|muted, path, volume_db, ...}
var last: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _tween: Tween
var _manifest: Dictionary = {}
var _manifest_read: bool = false
var _synth_cache: Dictionary = {}


## 设置里的音效音量 0..100 → 分贝；0 是不出声（MUTED_DB，不建播放器）。
static func volume_db(sfx: int) -> float:
	if sfx <= 0:
		return MUTED_DB
	return BASE_DB + linear_to_db(clampf(float(sfx) / 100.0, 0.0, 1.0))


func sfx_level() -> int:
	if sfx_override >= 0:
		return clampi(sfx_override, 0, 100)
	var bag = SettingsScript.new(settings_path)
	bag.load_file()
	return clampi(int(bag.sfx), 0, 100)


## 吹一下：spec = {ring_ms, pitch_cents, buzz}，salt 只换装饰。
func play_ring(spec: Dictionary, salt: int = 0) -> Dictionary:
	_stop()
	last = plan_ring(spec, salt)
	_run(last)
	return last


## 两枚相碰：dull_permille 0..1000（两枚里更闷的那一枚有多闷）。
func play_clink(dull_permille: int, salt: int = 0) -> Dictionary:
	_stop()
	last = plan_clink(dull_permille, salt)
	_run(last)
	return last


## 不出声，只说这一声会怎么出（测试和 Dummy 驱动下也能查）。
func plan_ring(spec: Dictionary, salt: int = 0) -> Dictionary:
	var vol := volume_db(sfx_level())
	var ring := clampi(int(spec.get("ring_ms", 400)), 60, 2400)
	var cents := clampi(int(spec.get("pitch_cents", 0)), -600, 600)
	var buzz := clampi(int(spec.get("buzz", 0)), 0, 100)
	var plan := {"kind": "ring", "volume_db": vol, "ring_ms": ring, "pitch_cents": cents, "buzz": buzz,
		"salt": salt, "path": "", "buzz_path": "", "buzz_db": MUTED_DB,
		"pitch_scale": clampf(pow(2.0, float(cents) / 1200.0), 0.25, 4.0)}
	if vol <= MUTED_DB:
		plan["route"] = "muted"
		return plan
	var path := resolve(RING_ID)
	if path != "":
		plan["route"] = "sample"
		plan["path"] = path
		if buzz > 0:
			plan["buzz_path"] = resolve(BUZZ_ID)
			plan["buzz_db"] = vol - 6.0 + linear_to_db(float(buzz) / 100.0)
		return plan
	plan["route"] = "silent" if CardShip.is_ship() else "synth"
	return plan


func plan_clink(dull_permille: int, salt: int = 0) -> Dictionary:
	var vol := volume_db(sfx_level())
	var d := clampi(dull_permille, 0, 1000)
	var plan := {"kind": "clink", "volume_db": vol, "dull_permille": d, "salt": salt, "path": "",
		"sample_id": CLINK_DULL_ID if d >= CLINK_DULL_FROM else CLINK_ID}
	if vol <= MUTED_DB:
		plan["route"] = "muted"
		return plan
	var path := resolve(str(plan["sample_id"]))
	if path != "":
		plan["route"] = "sample"
		plan["path"] = path
		return plan
	plan["route"] = "silent" if CardShip.is_ship() else "synth"
	return plan


## 样本 id → 能放的路径：人录的 → AI 线登记的（no_ai 跳过）→ ""。
func resolve(id: String) -> String:
	var human := HUMAN_DIR + id + ".ogg"
	if ResourceLoader.exists(human):
		return human
	if no_ai:
		return ""
	var entry = _cues().get(id)
	if typeof(entry) != TYPE_DICTIONARY:
		return ""
	var rel := str(entry.get("ai", ""))
	if not rel.begins_with("audio/ai/sfx/") or not rel.ends_with(".ogg"):
		return ""
	var path := "res://" + rel
	return path if ResourceLoader.exists(path) else ""


func stop() -> void:
	_stop()


func _cues() -> Dictionary:
	if not _manifest_read:
		_manifest_read = true
		var doc = CardDB.read_json(AI_MANIFEST) if FileAccess.file_exists(AI_MANIFEST) else null
		if typeof(doc) == TYPE_DICTIONARY and typeof(doc.get("cues")) == TYPE_DICTIONARY:
			_manifest = doc["cues"]
	return _manifest


func _exit_tree() -> void:
	_stop()


func _run(plan: Dictionary) -> void:
	if _silent() or str(plan.get("route", "")) in ["muted", "silent"]:
		return
	var vol := float(plan["volume_db"])
	if str(plan["route"]) == "sample":
		var stream := load(str(plan["path"])) as AudioStream
		if stream == null:
			return
		var player := _spawn(stream, vol)
		if str(plan["kind"]) == "ring":
			player.pitch_scale = float(plan["pitch_scale"])
			_fade(player, int(plan["ring_ms"]))
			if str(plan["buzz_path"]) != "":
				var buzz := load(str(plan["buzz_path"])) as AudioStream
				if buzz != null:
					_fade(_spawn(buzz, float(plan["buzz_db"])), int(plan["ring_ms"]))
		return
	if not CardShip.is_ship():
		var wav := _synth(plan)
		if wav != null:
			_spawn(wav, vol)


func _spawn(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = db
	_players.append(player)
	add_child(player)
	player.play()
	return player


func _fade(player: AudioStreamPlayer, ms: int) -> void:
	if not is_inside_tree():
		return
	if _tween == null or not is_instance_valid(_tween) or not _tween.is_running():
		_tween = create_tween().set_parallel(true)
	_tween.tween_property(player, "volume_db", FADE_TO_DB, maxf(0.05, float(ms) / 1000.0))


func _silent() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var name := str(AudioServer.get_driver_name())
	return name == "Dummy" or name == ""


func _stop() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	for p in _players:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
			p.free()
	_players.clear()


## 开发版合成：声音模型 → 16 位单声道 PCM。同一枚吹第二遍用缓存。
func _synth(plan: Dictionary) -> AudioStreamWAV:
	if not CardShip.is_ship():
		var key := JSON.stringify(plan, "", true)
		if _synth_cache.has(key):
			return _synth_cache[key]
		var v: Dictionary
		if str(plan["kind"]) == "clink":
			v = Voice.clink_voice(int(plan["dull_permille"]), int(plan["salt"]))
		else:
			v = Voice.voice({"ring_ms": plan["ring_ms"], "pitch_cents": plan["pitch_cents"], "buzz": plan["buzz"]},
				int(plan["salt"]))
		var wav := pcm16(Voice.render(v, MIX), MIX)
		_synth_cache[key] = wav
		return wav
	return null


## 样本数组 → AudioStreamWAV（AI 线生成样本的脚本也用它存 .wav）。
static func pcm16(frames: PackedFloat32Array, mix_rate: int) -> AudioStreamWAV:
	if not CardShip.is_ship():
		var bytes := PackedByteArray()
		bytes.resize(frames.size() * 2)
		for i in range(frames.size()):
			bytes.encode_s16(i * 2, int(clampf(frames[i], -1.0, 1.0) * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = mix_rate
		wav.stereo = false
		wav.data = bytes
		return wav
	return null
