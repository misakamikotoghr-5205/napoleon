# 无头跑完一局不建播放器；静态扫描：合成（AudioStreamWAV.new、填 PCM、生成器）都在 is_ship() 为假的分支里；
# 源码里的音频路径只有 audio/cards/sfx/coin_ring_*.ogg（人录）、audio/ai/sfx/ 的清单和 coin_ring_*.ogg（AI 线）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const SRC := "res://scripts/cards/minigames/coin_ring"
const GUARD := "if not CardShip.is_ship():"


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_audio_guard"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	await _play(t)
	_scan(t)


func _play(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture("v2_stack"), bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	H.click(g, H.center(g._sample_faces[0]))
	H.click(g, H.center(g._coin_faces[2]))
	H.drag(g, H.center(g._coin_faces[0]), H.center(g._coin_faces[2]))
	t.eq(str(g._audio.last.get("kind", "")), "clink", "the clink asked for a sound")
	H.click(g, H.center(g._done_btn))
	t.ok(box[0] != null, "played a round")
	t.eq(g._audio.get_child_count(), 0, "dummy driver created no player")
	t.eq(g._audio._players.size(), 0, "no players kept")
	g2_auto(t)
	await H.drop(self, [g, bus])


func g2_auto(t) -> void:
	# 再走一遍 autoplay，覆盖合成入口被调用前的静音返回。
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, H.fixture("v2_good"), bus)
	g.autoplay(0.8)
	t.eq(g._audio.get_child_count(), 0, "autoplay stays silent")
	g.queue_free()
	bus.queue_free()


func _scan(t) -> void:
	var gen := 0
	var push := 0
	var bad := PackedStringArray()
	for f in DirAccess.get_files_at(SRC):
		if not str(f).ends_with(".gd"):
			continue
		var path := SRC + "/" + str(f)
		var text := FileAccess.get_file_as_string(path)
		var lines := text.split("\n")
		var guarded := _guarded(lines)
		for i in range(lines.size()):
			var line := lines[i]
			var hit := line.contains("AudioStreamGenerator") or line.contains("push_frame") or line.contains("AudioStreamWAV.new") \
				or line.contains("encode_s16") or line.contains("Voice.render(")
			if not hit:
				continue
			if line.contains("AudioStreamWAV.new") or line.contains("AudioStreamGenerator.new"):
				gen += 1
			if line.contains("encode_s16") or line.contains("push_frame") or line.contains("Voice.render("):
				push += 1
			if not guarded.has(i):
				bad.append("%s:%d %s" % [f, i + 1, line.strip_edges()])
		bad.append_array(_paths(str(f), text))
	t.ok(gen > 0, "the synthesized stream is in the source")
	t.ok(push > 0, "filling samples is in the source")
	t.eq(bad.size(), 0, "unguarded or bad path: %s" % " | ".join(bad))


func _guarded(lines: PackedStringArray) -> Dictionary:
	var out := {}
	var guards: Array = []
	for i in range(lines.size()):
		var raw := lines[i]
		var trimmed := raw.strip_edges()
		if trimmed == "" or trimmed.begins_with("#"):
			continue
		var indent := raw.length() - raw.lstrip(" \t").length()
		while not guards.is_empty() and indent <= int(guards.back()):
			guards.pop_back()
		if not guards.is_empty():
			out[i] = true
		if trimmed.begins_with(GUARD):
			guards.append(indent)
	return out


func _paths(name: String, text: String) -> PackedStringArray:
	var bad := PackedStringArray()
	var re := RegEx.new()
	re.compile("\"(res://audio/[^\"\\n]*)\"")
	for m in re.search_all(text):
		var s := m.get_string(1)
		var ok := s in ["res://audio/cards/sfx/", "res://audio/ai/sfx/manifest.json"]
		ok = ok or (s.begins_with("res://audio/cards/sfx/coin_ring_") and s.ends_with(".ogg"))
		ok = ok or (s.begins_with("res://audio/ai/sfx/coin_ring_") and s.ends_with(".ogg"))
		if not ok:
			bad.append("%s path %s" % [name, s])
	return bad
