# 确定性（合同 §8.2、§6.3；DESIGN P8）：同参数同操作同结果（鼠标点两遍、autoplay 两遍）；
# 小游戏里的随机只用 JevRng.draw(params.seed, "c.mg.coin_ring.layout", [i])，下标分段：[5000..] 声音装饰、[9000..] 自动玩；
# 没有 randf/randi 之类；声音模型和余音线不碰随机；合成一声、画一道线都够快。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const Voice = preload("res://scripts/cards/minigames/coin_ring/coin_ring_voice.gd")
const SRC := "res://scripts/cards/minigames/coin_ring"


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_determinism"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var fix := H.fixture("v2_stack")
	var a: Dictionary = await _mouse(t, fix)
	var b: Dictionary = await _mouse(t, fix)
	t.eq(a, b, "same clicks, same result")
	t.ok(not a.is_empty(), "mouse round finished")
	for skill in [0.3, 0.8]:
		var x: Dictionary = await H.auto(self, fix, skill)
		var y: Dictionary = await H.auto(self, fix, skill)
		t.eq(x, y, "autoplay %.1f twice" % skill)
	await _salts(t)
	_sources(t)
	_perf(t)


func _mouse(t, fix: Dictionary) -> Dictionary:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var g := H.open(self, fix, bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	for f in [g._sample_faces[0], g._coin_faces[1], g._sample_faces[1], g._coin_faces[4]]:
		H.click(g, H.center(f))
	H.drag(g, H.center(g._coin_faces[0]), H.center(g._coin_faces[2]))
	H.click(g, H.center(g._chips[1]))
	H.click(g, H.center(g._chips[4]))
	H.click(g, H.center(g._chips[4]))
	H.click(g, H.center(g._done_btn))
	var out := {"result": box[0] if box[0] != null else {}, "ops": g.ops_log()}
	await H.drop(self, [g, bus])
	return out


## 装饰种子：同一枚每次吹都一样；不同的枚不一样；只从布局域来。
func _salts(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var fix := H.fixture("v2_stack")
	var g := H.open(self, fix, bus)
	var s0 := g._salt(0)
	t.eq(g._salt(0), s0, "a coin keeps its salt")
	t.ok(g._salt(1) != s0, "another coin has another salt")
	var seed := int(fix["seed"])
	t.eq(s0, int(JevRng.draw(seed, "c.mg.coin_ring.layout", [CardCoinRingGame.SALT_BASE + 2]) * 1000000.0), "salt from c.mg.coin_ring.layout [5002]")
	await H.drop(self, [g, bus])


func _sources(t) -> void:
	var text := ""
	for f in DirAccess.get_files_at(SRC):
		if str(f).ends_with(".gd"):
			text += _code(FileAccess.get_file_as_string(SRC + "/" + str(f)))
	for bad in ["randf(", "randi(", "randomize(", "RandomNumberGenerator", "randf_range(", "randi_range(", "Time.get_ticks", "OS.get_unix"]:
		t.ok(not text.contains(bad), "no %s" % bad)
	var re := RegEx.new()
	re.compile("c\\.mg\\.[A-Za-z0-9_.]+")
	var found := {}
	for m in re.search_all(text):
		found[m.get_string()] = true
	t.eq(found.keys(), ["c.mg.coin_ring.layout"], "one rng domain")
	var draws := RegEx.new()
	draws.compile("JevRng\\.draw\\(([^,]+),\\s*([^,]+),")
	var calls := draws.search_all(text)
	t.ok(calls.size() >= 2, "layout draws for decoration and autoplay")
	for m in calls:
		t.eq(m.get_string(1).strip_edges(), "_seed", "draws use params.seed")
		t.eq(m.get_string(2).strip_edges(), "LAYOUT_DOMAIN", "draws use the layout domain")
	var voice := _code(FileAccess.get_file_as_string(SRC + "/coin_ring_voice.gd"))
	t.ok(not voice.contains("JevRng"), "the sound model is pure")


func _code(src: String) -> String:
	var out := ""
	for line in src.split("\n"):
		var cut := line.find("#")
		out += (line if cut < 0 else line.substr(0, cut)) + "\n"
	return out


func _perf(t) -> void:
	var spec := {"ring_ms": 1600, "pitch_cents": -40, "buzz": 70}
	var t0 := Time.get_ticks_usec()
	var frames := Voice.render(Voice.voice(spec, 9), 22050)
	var render_us := int(Time.get_ticks_usec() - t0)
	var t1 := Time.get_ticks_usec()
	for _j in range(20):
		Voice.trace(spec, 9, 844.0)
	var trace_us := int((Time.get_ticks_usec() - t1) / 20)
	print("C13 perf render_us=%d trace_us=%d frames=%d" % [render_us, trace_us, frames.size()])
	t.ok(render_us < 250000, "a ring synthesizes in under 250 ms")
	t.ok(trace_us < 8000, "a sound line computes in under 8 ms")
