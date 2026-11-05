# 曲目按人工 → AI →（非发行版）旧曲 legacy → 静音查找；no_ai（不带声明版）只认人工，AI 文件、旧曲在也不选。
# 曲子循环；同一首不从头重放。临时资源只在本测试目录生成并清除，不触碰正式音频。
# 主人 C16；合同 §3.3 C16、§12.1；#212-1 与 W2_HANDOFF.md 的 10-18 决定。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Music = preload("res://scripts/cards/ui/shell/card_music.gd")
const CUES: Array[String] = ["title", "day", "night", "month_close", "year_jump"]
## 10-22 能玩版：卡牌 cue 借 v0.4 旧曲（框架版收尾默认，主创可改）。
const LEGACY := {
	"title": "audio/music/title.ogg", "day": "audio/music/pawnshop.ogg", "night": "audio/music/night.ogg",
	"month_close": "audio/music/town_dusk.ogg", "year_jump": "audio/music/title.ogg",
}


func _initialize() -> void:
	var t := T.new(self, "C16_music")
	t.run_async(_body.bind(t))


func _body(t: RefCounted) -> void:
	var doc: Dictionary = CardDB.read_json("res://data/cards/audio/music.json")
	var cues: Dictionary = doc.get("cues", {})
	for cue: String in CUES:
		var entry: Dictionary = cues.get(cue, {})
		t.eq(entry.get("human"), "audio/cards/music/%s.ogg" % cue, cue + " human path")
		t.eq(entry.get("ai"), "audio/ai/music/%s.ogg" % cue, cue + " AI path")
		t.eq(entry.get("legacy"), LEGACY[cue], cue + " legacy path")
		t.ok(ResourceLoader.exists("res://" + str(LEGACY[cue])), cue + " legacy track exists")

	var folder := "scripts/tests/cards/C16/_music_%s" % OS.get_process_id()
	t.eq(DirAccess.make_dir_recursive_absolute("res://" + folder), OK, "create fixture directory")
	var human := folder + "/human.tres"
	var ai := folder + "/ai.tres"
	var missing := folder + "/missing.ogg"
	for path: String in [human, ai]:
		var stream := AudioStreamWAV.new()
		stream.data = PackedByteArray([0, 0, 0, 0])
		t.eq(ResourceSaver.save(stream, "res://" + path), OK, "save temporary audio resource")

	var bus := CardEventBus.new()
	root.add_child(bus)
	var node := Music.new()
	root.add_child(node)
	await t.frames(1)
	t.eq(node._cues, cues, "ready loads the production manifest")
	t.eq(node.allow_legacy, not CardShip.is_ship(), "legacy layer follows CardShip.is_ship()")
	var prod_player := node.get_child(0) as AudioStreamPlayer
	for cue: String in CUES:
		var entry: Dictionary = cues.get(cue, {})
		var want := ""
		for layer: String in ["human", "ai", "legacy"]:
			var rel := str(entry.get(layer, ""))
			if rel != "" and ResourceLoader.exists("res://" + rel):
				want = "res://" + rel
				break
		node.play(StringName(cue))
		t.ok(prod_player.stream != null, cue + " production cue is not silent")
		if prod_player.stream != null:
			t.eq(prod_player.stream.resource_path, want, cue + " production cue picks the first existing layer")
			if prod_player.stream is AudioStreamOggVorbis:
				t.ok((prod_player.stream as AudioStreamOggVorbis).loop, cue + " production cue loops")
	node.play(&"day")
	var day_stream := prod_player.stream
	node.play(&"day")
	t.ok(prod_player.stream == day_stream and day_stream != null, "same cue keeps the current stream")
	node._cues = {
		"human": {"human": human, "ai": ai},
		"ai": {"human": missing, "ai": ai},
		"ai_only": {"ai": ai},
		"silent": {"human": missing, "ai": missing, "placeholder": human},
		"legacy": {"human": missing, "ai": missing, "legacy": ai},
		"empty": {"human": "", "ai": ""},
		"malformed": "invalid entry",
		"night": {"ai": ai},
	}
	var player := node.get_child(0) as AudioStreamPlayer
	t.ok(player != null, "player exists")
	for cue: String in ["human", "ai", "ai_only"]:
		var expected := "res://" + (human if cue == "human" else ai)
		t.eq(node._resolve(cue), expected, cue + " selects the correct layer")
		node.play(StringName(cue))
		t.ok(player.stream != null, cue + " loads an audio stream")
		if player.stream != null:
			t.eq(player.stream.resource_path, expected, cue + " assigns the selected stream")
	t.eq(node._resolve("legacy"), "res://" + ai, "legacy layer is used after human and AI in non-ship builds")
	node.allow_legacy = false
	t.eq(node._resolve("legacy"), "", "legacy layer is skipped when legacy is not allowed (ship)")
	node.play(&"legacy")
	t.eq(player.stream, null, "ship build stays silent without human/AI tracks")
	node.allow_legacy = true
	for cue: String in ["silent", "empty", "malformed", "unknown"]:
		node.play(&"human")
		t.eq(node._resolve(cue), "", cue + " resolves to silence")
		node.play(StringName(cue))
		t.eq(player.stream, null, cue + " clears the previous stream")
		t.ok(not player.playing, cue + " stops playback")
	node.set_volume(0.0)
	t.eq(player.volume_db, -80.0, "zero volume mutes")
	node.set_volume(0.4)
	t.ok(is_equal_approx(player.volume_db, linear_to_db(0.4)), "volume is applied")
	node.bind(bus)
	bus.phase_changed.emit(&"morning", &"night")
	t.ok(player.stream != null, "phase_changed loads AI night cue")
	if player.stream != null:
		t.eq(player.stream.resource_path, "res://" + ai, "phase_changed selects AI night cue")

	# 负例：no_ai 包里 AI 文件确实存在也不许选，缺人工曲就静音（正式包缺项由审核报错）。
	t.ok(not OS.has_feature("no_ai"), "test runner is not a no_ai build")
	t.eq(node.no_ai, false, "default mode follows OS.has_feature(no_ai)")
	t.ok(ResourceLoader.exists("res://" + ai), "AI fixture really exists for the no_ai negative case")
	node.no_ai = true
	t.eq(node._resolve("human"), "res://" + human, "no_ai still selects human")
	node.play(&"human")
	t.ok(player.stream != null and player.stream.resource_path == "res://" + human, "no_ai plays human stream")
	for cue: String in ["ai", "ai_only", "night", "silent", "legacy"]:
		node.play(&"human")
		t.eq(node._resolve(cue), "", cue + " never selects AI under no_ai")
		node.play(StringName(cue))
		t.eq(player.stream, null, cue + " is silent under no_ai")
		t.ok(not player.playing, cue + " does not play under no_ai")
	node.play(&"human")
	bus.phase_changed.emit(&"morning", &"night")
	t.eq(player.stream, null, "no_ai phase_changed does not fall back to AI night cue")
	node.no_ai = false
	t.eq(node._resolve("ai"), "res://" + ai, "normal mode selects AI again")
	node.queue_free()
	bus.queue_free()
	await t.frames(1)
	for path: String in [human, ai]:
		t.eq(DirAccess.remove_absolute("res://" + path), OK, "remove temporary audio resource")
	t.eq(DirAccess.remove_absolute("res://" + folder), OK, "remove fixture directory")
