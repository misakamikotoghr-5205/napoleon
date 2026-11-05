# 声音从真值来（DESIGN §5.3）：coin_ring_voice.gd 的声音参数、合成出来的样本、余音线都跟着物理量走——
# 音低 → 基音低、过零少、线上的起伏宽；余音短 → 衰减快、样本短、线短；杂音大 → 沙声和毛边多；装饰种子只换花样。
# 相碰：闷的那一声低、宽，清脆的那一声高、窄。音量跟设置里的音效（0 不出声）；找样本 人录 → AI 线 → 开发版合成；
# AI 线的两声相碰登记在 audio/ai/sfx/manifest.json，来源合法、文件在。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const Voice = preload("res://scripts/cards/minigames/coin_ring/coin_ring_voice.gd")
const RingAudio = preload("res://scripts/cards/minigames/coin_ring/coin_ring_audio.gd")
const Obs = preload("res://scripts/cards/minigames/coin_ring/coin_ring_obs.gd")
const MIX := 32000
const GOOD := {"ring_ms": 1400, "pitch_cents": 0, "buzz": 7}
const DULL := {"ring_ms": 480, "pitch_cents": -205, "buzz": 72}
const WORN := {"ring_ms": 1020, "pitch_cents": -5, "buzz": 17}
const WELL := {"ring_ms": 1130, "pitch_cents": -95, "buzz": 30}
const AI_PROV := "^ai:([^:\\s]+?)(?::([^:\\s]+?))?:(\\d{4}-\\d{2}-\\d{2}):(\\S+)$"


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_voice"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	_params(t)
	_samples(t)
	_lines(t)
	_clink(t)
	await _audio(t)
	_manifest(t)


func _params(t) -> void:
	var g := Voice.voice(GOOD, 1)
	var d := Voice.voice(DULL, 1)
	var w := Voice.voice(WELL, 1)
	var o := Voice.voice(WORN, 1)
	t.ok(float(d["f0"]) < float(w["f0"]) and float(w["f0"]) < float(g["f0"]), "lower pitch_cents, lower fundamental")
	t.ok(absf(float(o["f0"]) / float(g["f0"]) - pow(2.0, -5.0 / 1200.0)) < 0.0001, "f0 follows cents exactly")
	t.ok(float(d["tau"]) < float(o["tau"]) and float(o["tau"]) < float(g["tau"]), "shorter ring, faster decay")
	t.eq(int(d["length_ms"]), 480 + Voice.TAIL_MS, "length follows ring_ms")
	t.ok(float(d["noise"]) > float(w["noise"]) and float(w["noise"]) > float(g["noise"]), "more buzz, more sand")
	t.ok(float(d["thump"]) > 0.0 and float(g["thump"]) == 0.0 and float(w["thump"]) == 0.0, "only a short ring thumps")
	var parts: Array = g["partials"]
	t.eq(parts.size(), 3, "three partials")
	for i in range(1, parts.size()):
		t.ok(float(parts[i][2]) < float(parts[0][2]), "upper partials die sooner")
	var salted := Voice.voice(GOOD, 99)
	t.eq([salted["f0"], salted["tau"], salted["noise"], salted["length_ms"]], [g["f0"], g["tau"], g["noise"], g["length_ms"]], "salt keeps the physics")
	t.eq(Voice.voice(GOOD, 1), g, "same spec, same voice")


func _samples(t) -> void:
	var g := Voice.render(Voice.voice(GOOD, 3), MIX)
	var d := Voice.render(Voice.voice(DULL, 3), MIX)
	var w := Voice.render(Voice.voice(WELL, 3), MIX)
	t.eq(g, Voice.render(Voice.voice(GOOD, 3), MIX), "rendering is deterministic")
	t.ok(g != Voice.render(Voice.voice(GOOD, 4), MIX), "the salt changes the noise pattern")
	t.eq(g.size(), int(MIX * (1400 + Voice.TAIL_MS) / 1000.0), "sample count follows ring_ms")
	t.ok(d.size() < g.size(), "a dull ring is shorter")
	for arr in [g, d, w]:
		var peak := 0.0
		for s in arr:
			peak = maxf(peak, absf(s))
		t.ok(peak > 0.2 and peak <= 1.0, "audible and unclipped peak %.2f" % peak)
	# Pitch: the strongest frequency near the fundamental (Goertzel scan, 20..220 ms) is the voice's f0.
	var peaks: Array = []
	for cents in [0, -95, -205]:
		var spec := {"ring_ms": 1400, "pitch_cents": cents, "buzz": 0}
		var hz := _peak_hz(Voice.render(Voice.voice(spec, 3), MIX), 1500.0, 2200.0, 0.02, 0.22)
		var f0 := float(Voice.voice(spec, 3)["f0"])
		t.ok(absf(hz - f0) <= 12.0, "cents %d: the sound peaks at f0 (%.0f Hz vs %.0f Hz)" % [cents, hz, f0])
		peaks.append(hz)
	t.ok(peaks[2] < peaks[1] and peaks[1] < peaks[0], "lower pitch_cents, lower peak %s" % [peaks])
	# Length: energy left after 400 ms.
	t.ok(_energy(g, 0.4, 0.5) > _energy(Voice.render(Voice.voice(WORN, 3), MIX), 0.4, 0.5) * 1.2, "a long ring keeps more energy late")
	t.ok(_energy(Voice.render(Voice.voice(WORN, 3), MIX), 0.4, 0.5) > _energy(d, 0.4, 0.5) * 2.0, "a worn coin still rings longer than a dull one")
	# Buzz: same ring, same pitch, same salt; what buzz adds (the difference) grows with buzz and is not small.
	var clean := Voice.render(Voice.voice({"ring_ms": 1000, "pitch_cents": 0, "buzz": 0}, 3), MIX)
	var light := Voice.render(Voice.voice({"ring_ms": 1000, "pitch_cents": 0, "buzz": 12}, 3), MIX)
	var sandy := Voice.render(Voice.voice({"ring_ms": 1000, "pitch_cents": 0, "buzz": 80}, 3), MIX)
	var e_clean := _energy(clean, 0.02, 0.4)
	var e_light := _diff_energy(light, clean, 0.02, 0.4)
	var e_sandy := _diff_energy(sandy, clean, 0.02, 0.4)
	t.ok(e_sandy > e_light * 10.0, "more buzz, much more sand (%.3f vs %.3f)" % [e_sandy, e_light])
	t.ok(e_sandy > e_clean * 0.08, "at buzz 80 the sand is clearly there (%.3f of %.3f)" % [e_sandy, e_clean])
	t.ok(e_light < e_clean * 0.05, "a good coin's little buzz stays quiet (%.3f of %.3f)" % [e_light, e_clean])


func _lines(t) -> void:
	var width := 844.0
	var g := Voice.trace(GOOD, 5, width)
	var d := Voice.trace(DULL, 5, width)
	var o := Voice.trace(WORN, 5, width)
	var w := Voice.trace(WELL, 5, width)
	t.eq(g.size(), int(width * 1400.0 / float(Voice.VIEW_MS)), "line length follows ring_ms")
	t.ok(d.size() < o.size() and o.size() < g.size(), "dull < worn < good in length")
	t.ok(absi(w.size() - o.size()) < 120, "a well-made dull line is about as long as a worn one (length alone cannot tell)")
	t.ok(Voice.wave_px(-95) > Voice.wave_px(-5) * 1.3, "a low coin draws visibly wider waves")
	t.ok(Voice.wave_px(-205) > Voice.wave_px(-95), "lower still, wider still")
	t.eq(Voice.wave_px(-5), Voice.wave_px(-5), "wave width is pure")
	t.ok(_rough(Voice.trace(DULL, 5, width), 0.0, 0.5) > _rough(Voice.trace({"ring_ms": 480, "pitch_cents": -205, "buzz": 0}, 5, width), 0.0, 0.5) * 1.5,
		"buzz frays the line")
	t.eq(Voice.trace(GOOD, 5, width), g, "lines are deterministic")
	for y in g:
		t.ok(y >= -1.0 and y <= 1.0, "line within the row")
		break


func _clink(t) -> void:
	var bright := Voice.render(Voice.clink_voice(0, 2), MIX)
	var dull := Voice.render(Voice.clink_voice(900, 2), MIX)
	t.eq(bright.size(), dull.size(), "a clink is a clink long")
	t.ok(_peak_hz(dull, 400.0, 7000.0, 0.008, 0.06) < 2000.0 and _peak_hz(bright, 400.0, 7000.0, 0.008, 0.06) > 2500.0,
		"the dull clink is low, the clean one high")
	var sharp := Voice.clink_trace(0, 2, 844.0)
	var thud := Voice.clink_trace(900, 2, 844.0)
	t.ok(_peak(sharp) > _peak(thud) * 1.4, "clean clink: a tall spike; dull: a low bump")
	t.ok(_width(thud) > _width(sharp) * 2, "the dull bump is wider")
	var good_s := {"ring_ms": 1400, "pitch_cents": 0, "buzz": 7}
	t.ok(Obs.clink_dullness(GOOD, WORN, good_s) < RingAudio.CLINK_DULL_FROM, "a worn good coin clinks clean")
	t.ok(Obs.clink_dullness(GOOD, DULL, good_s) > 800, "a dull coin makes the pair clink dull")
	t.ok(Obs.clink_dullness(WELL, GOOD, good_s) >= RingAudio.CLINK_DULL_FROM, "a well-made dull coin still dulls the clink")
	t.eq(Obs.clink_dullness(GOOD, DULL, good_s), Obs.clink_dullness(DULL, GOOD, good_s), "order does not matter")


func _audio(t) -> void:
	t.eq(RingAudio.volume_db(0), RingAudio.MUTED_DB, "sfx 0 is silent")
	t.ok(RingAudio.volume_db(100) > RingAudio.volume_db(50) and RingAudio.volume_db(50) > RingAudio.volume_db(10), "louder setting, louder sound")
	t.ok(absf(RingAudio.volume_db(100) - RingAudio.BASE_DB) < 0.001, "full setting plays at the base level")
	var a := RingAudio.new()
	root.add_child(a)
	await t.frames(1)
	var settings: String = t.user_dir() + "/settings.json"
	var f := FileAccess.open(settings, FileAccess.WRITE)
	f.store_string(JSON.stringify({"music": 70, "sfx": 0, "text_speed": 1, "guide_hints": true}))
	f.close()
	a.settings_path = settings
	t.eq(a.sfx_level(), 0, "reads the sfx setting from the settings file")
	t.eq(a.plan_ring(GOOD)["route"], "muted", "sfx 0: nothing plays")
	t.eq(a.plan_clink(900)["route"], "muted", "sfx 0: no clink either")
	a.sfx_override = 60
	var ring := a.plan_ring(DULL, 4)
	t.ok(absf(float(ring["volume_db"]) - RingAudio.volume_db(60)) < 0.001, "volume follows the setting")
	t.eq(ring["route"], "synth", "no recorded ring yet: the dev build synthesizes")
	t.ok(absf(float(ring["pitch_scale"]) - pow(2.0, -205.0 / 1200.0)) < 0.0001, "a ring sample would be pitched by pitch_cents")
	var thud := a.plan_clink(900, 4)
	t.eq(thud["sample_id"], "coin_ring_clink_dull", "a dull pair uses the dull clink")
	t.eq(thud["route"], "sample", "the AI clink sample is found")
	t.eq(thud["path"], "res://audio/ai/sfx/coin_ring_clink_dull.ogg", "through the AI manifest")
	var ping := a.plan_clink(0, 4)
	t.eq(ping["path"], "res://audio/ai/sfx/coin_ring_clink.ogg", "a clean pair uses the clean clink")
	a.no_ai = true
	t.eq(a.resolve("coin_ring_clink_dull"), "", "a no_ai build skips AI samples")
	t.eq(a.plan_clink(900)["route"], "synth", "and synthesizes in a dev build")
	a.no_ai = false
	a.play_ring(GOOD, 1)
	a.play_clink(900, 1)
	t.eq(a.get_child_count(), 0, "the Dummy driver creates no player")
	a.queue_free()
	await t.frames(1)


func _manifest(t) -> void:
	var doc = CardDB.read_json("res://audio/ai/sfx/manifest.json")
	t.eq(typeof(doc), TYPE_DICTIONARY, "AI sfx manifest")
	var cues: Dictionary = doc.get("cues", {}) if typeof(doc) == TYPE_DICTIONARY else {}
	var re := RegEx.create_from_string(AI_PROV)
	for id in ["coin_ring_clink_dull", "coin_ring_clink"]:
		var e: Dictionary = cues.get(id, {})
		t.eq(str(e.get("human", "")), "audio/cards/sfx/%s.ogg" % id, "%s: a human recording replaces it" % id)
		t.eq(str(e.get("ai", "")), "audio/ai/sfx/%s.ogg" % id, "%s: AI path" % id)
		t.ok(re.search(str(e.get("_provenance", ""))) != null, "%s: provenance ai:<tool>:<model>:<date>:<id>" % id)
		t.ok(FileAccess.file_exists("res://audio/ai/sfx/%s.ogg" % id), "%s: file exists" % id)
		var stream := load("res://audio/ai/sfx/%s.ogg" % id) as AudioStream
		t.ok(stream != null and stream.get_length() > 0.1 and stream.get_length() < 0.3, "%s: about 0.15 s" % id)


## Goertzel power scan: the frequency (5 Hz steps) with the most energy in [lo, hi] over a time span.
func _peak_hz(a: PackedFloat32Array, lo: float, hi: float, from_s: float, to_s: float) -> float:
	var i0 := int(from_s * MIX)
	var i1 := mini(int(to_s * MIX), a.size())
	var best := lo
	var best_p := -1.0
	var f := lo
	while f <= hi:
		var k := 2.0 * cos(TAU * f / float(MIX))
		var s1 := 0.0
		var s2 := 0.0
		for i in range(i0, i1):
			var s0 := a[i] + k * s1 - s2
			s2 = s1
			s1 = s0
		var p := s1 * s1 + s2 * s2 - k * s1 * s2
		if p > best_p:
			best_p = p
			best = f
		f += 5.0
	return best


func _diff_energy(a: PackedFloat32Array, b: PackedFloat32Array, from_s: float, to_s: float) -> float:
	var e := 0.0
	for i in range(int(from_s * MIX), mini(int(to_s * MIX), mini(a.size(), b.size()))):
		e += (a[i] - b[i]) * (a[i] - b[i])
	return e


func _energy(a: PackedFloat32Array, from_s: float, to_s: float) -> float:
	var e := 0.0
	for i in range(int(from_s * MIX), mini(int(to_s * MIX), a.size())):
		e += a[i] * a[i]
	return e


## Sample-to-sample roughness: mean |x[i] - (x[i-1] + x[i+1]) / 2| over a span (fraction of the array for lines).
func _rough(a: PackedFloat32Array, from_f: float, to_f: float) -> float:
	var i0 := maxi(1, int(from_f * (MIX if a.size() > 4000 else a.size())))
	var i1 := mini(a.size() - 1, int(to_f * (MIX if a.size() > 4000 else a.size())))
	if i1 <= i0:
		return 0.0
	var s := 0.0
	for i in range(i0, i1):
		s += absf(a[i] - (a[i - 1] + a[i + 1]) * 0.5)
	return s / float(i1 - i0)


func _peak(a: PackedFloat32Array) -> float:
	var p := 0.0
	for y in a:
		p = maxf(p, absf(y))
	return p


## How many pixels carry more than a third of the peak.
func _width(a: PackedFloat32Array) -> int:
	var p := _peak(a)
	var first := -1
	var last := -1
	for i in range(a.size()):
		if absf(a[i]) > p / 3.0:
			if first < 0:
				first = i
			last = i
	return last - first
