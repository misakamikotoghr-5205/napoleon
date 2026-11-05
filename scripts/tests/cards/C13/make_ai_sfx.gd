# 生成 AI 线的吹银元相碰音效（不进清单，手动跑一次；主创 10-25 拍板第 8 条）：
#   coin_ring_clink_dull.ogg  两枚相碰、其中一枚是哑板（闷，约 0.16 秒）
#   coin_ring_clink.ogg       两枚都清脆（同一个模型，闷度 0；成对生成，免得只有闷的那一声有样本）
# 声音全由程序合成（coin_ring_voice.gd 的 clink_voice：几个正弦分音 + 指数衰减 + 一点噪声），没有录音来源。
# 先存 16 位 48 kHz WAV，再用本机 ffmpeg 转 Vorbis q5（和 tools/audio/prepare_ai_audio.py 同样的编码；
# 那个工具要 mp3 输入、按 -16 LUFS 量响度，0.16 秒太短量不出，所以这里直接编码，峰值由模型定）。
# 写进 audio/ai/sfx/<id>.ogg，并在 audio/ai/sfx/manifest.json 的 cues 里登记 human / ai / _provenance。已有文件不覆盖（--force 才覆盖）。
#   $GODOT --headless --path . -s res://scripts/tests/cards/C13/make_ai_sfx.gd -- [--force] [--root=<目录>]
# 之后再跑一次 --import，把新 .ogg 的 .import 一起提交。
extends SceneTree

const Voice = preload("res://scripts/cards/minigames/coin_ring/coin_ring_voice.gd")
const RingAudio = preload("res://scripts/cards/minigames/coin_ring/coin_ring_audio.gd")
const MIX := 48000
const PROVENANCE := "ai:claude:opus-5.5:2026-10-25:c13-clink-synth"
const GENERATOR := "scripts/tests/cards/C13/make_ai_sfx.gd (coin_ring_voice.gd clink_voice; procedural sines with exponential decay and noise; no recorded source)"
const CUES := {"coin_ring_clink_dull": 900, "coin_ring_clink": 0}


func _initialize() -> void:
	var force := false
	var root := ProjectSettings.globalize_path("res://")
	for a in OS.get_cmdline_user_args():
		if a == "--force":
			force = true
		elif a.begins_with("--root="):
			root = a.substr(7)
	root = root.rstrip("/")
	var dir := root + "/audio/ai/sfx"
	DirAccess.make_dir_recursive_absolute(dir)
	var manifest_path := dir + "/manifest.json"
	var doc = {"cues": {}}
	if FileAccess.file_exists(manifest_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("cues")) == TYPE_DICTIONARY:
			doc = parsed
	var ids: Array = CUES.keys()
	ids.sort()
	for id in ids:
		var out := "%s/%s.ogg" % [dir, id]
		if FileAccess.file_exists(out) and not force:
			print("SKIP exists: ", out)
			continue
		var wav_path := OS.get_cache_dir().path_join("dh_%s.wav" % id)
		var v := Voice.clink_voice(int(CUES[id]), 1013)
		var wav := RingAudio.pcm16(Voice.render(v, MIX), MIX)
		var err := wav.save_to_wav(wav_path)
		if err != OK:
			printerr("FAIL save wav ", wav_path, " ", err)
			quit(1)
			return
		var log: Array = []
		var code := OS.execute("ffmpeg", ["-v", "error", "-nostdin", "-y", "-i", wav_path, "-map_metadata", "-1",
			"-ar", str(MIX), "-c:a", "libvorbis", "-q:a", "5", out], log, true)
		DirAccess.remove_absolute(wav_path)
		if code != 0:
			printerr("FAIL ffmpeg ", code, " ", log)
			quit(1)
			return
		var entry: Dictionary = (doc["cues"] as Dictionary).get(id, {})
		entry["human"] = "audio/cards/sfx/%s.ogg" % id
		entry["ai"] = "audio/ai/sfx/%s.ogg" % id
		entry["_provenance"] = PROVENANCE
		entry["generator"] = GENERATOR
		entry["dull_permille"] = int(CUES[id])
		doc["cues"][id] = entry
		print("WROTE ", out)
	var f := FileAccess.open(manifest_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(doc, "  ", true) + "\n")
	f.close()
	print("MANIFEST ", manifest_path)
	quit(0)
