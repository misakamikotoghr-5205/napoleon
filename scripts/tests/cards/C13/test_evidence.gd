# 复审二、三（盲测，主创：要玩家看出来才算数）：余音线看得出来、和面板上的规矩对得上、又不是一眼看穿（DESIGN §5.2、§5.3）。
# 用真引擎的参数（G04 appraisal_support.real_ctx：真物品规格、真抽法），三种银元各几十件真的、几十件假的：
# - 足银（旧洋也算）的起伏和柜上甲一样密：一个起伏宽差不到 4.5%，前五个波峰个个落在甲的波峰上（差不到 2 像素）；
# - 哑板（做得好的也算）比甲疏：起伏宽至少多 15%，第四个波峰落后甲至少 6 像素；前五个波峰里总有一个离甲最近的
#   波峰也有 4 像素以上（三分之一个起伏）——面板上“对着甲看前五个波峰，不到第五个就错开了是哑板”说的就是这个；
# - 复审三：也不是一眼的事——最疏的哑板也只比甲疏三成多一点（原来疏到两三倍，一眼就看穿）；
# - 复审三：长短、毛刺挑不出哑板——每一枚哑板的余音长短、毛刺都落在同一种足银（含旧洋）能有的范围里，
#   不比最短的旧洋短、不比最毛的旧洋毛（原来常见的哑板短得没有哪枚旧洋那么短）；只按长短或只按毛刺划一刀，
#   分得最好也只比瞎猜好一点；柜上的乙也一样，长短毛刺像一枚旧洋，只是起伏疏；两枚相碰闷不闷也只跟音高走；
# - 每道线从同一个相位起振，装饰种子只换毛刺、不挪波峰（原来种子会把起点挪半个起伏，同音的也像错开了）；
# - 余音框：甲、乙吹过就各钉一行（甲最上、乙最下），客人的线夹在中间、紧挨着甲；吹客人的乙也不被挤掉
#   （复审三：原来基础眼力只两行，乙和客人的线从来不同时在框里）；还没吹的样洋那一行空着、淡淡写着甲 / 乙；
#   客人的线在样洋的线还在时吹才算比过；
# - 面板上一直有图例和规矩（字都从 CardText 来），放得下、不压别的东西，真假两枚的面板一模一样。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const A = preload("res://scripts/tests/cards/G04/appraisal_support.gd")
const Voice = preload("res://scripts/cards/minigames/coin_ring/coin_ring_voice.gd")
const WaveView = preload("res://scripts/cards/minigames/coin_ring/coin_ring_wave.gd")
const Obs = preload("res://scripts/cards/minigames/coin_ring/coin_ring_obs.gd")
const RingAudio = preload("res://scripts/cards/minigames/coin_ring/coin_ring_audio.gd")
const TEMPLATES := ["silver.yuan_a", "silver.yuan_b", "silver.yuan_c"]
const PER_TRUTH := 100
const TRACE_W := 844.0
## A good coin's wave width is within this factor of the silver sample's (either way).
const SAME_MAX := 1.045
## A dull coin's wave is at least this much wider than the silver sample's.
const SPARSE_MIN := 1.15
## ... and at most this much: the sparsest dull coin still needs a look along the line, not a glance.
const GLANCE_MAX := 1.36
## How many crests the rule on the panel says to compare.
const CRESTS := 5
## Crest index (0-based: the fourth crest) where a dull coin is behind by FAKE_LAG_PX at least.
const PEAK_K := 3
const REAL_LAG_PX := 2
const FAKE_LAG_PX := 6
## Whichever way one pairs the crests (by count or by the nearest), one of the first five is this far off on a dull coin.
const FAKE_NEAR_PX := 4
## Best balanced accuracy a single cut on length alone, or on fuzz alone, may reach (0.5 = a coin toss).
const CUE_MAX := 0.66


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_evidence"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	CardText.setup(CardDB.load_all(CardDB.DEFAULT_ROOT, {}))
	_engine(t)
	_phase(t)
	await _pinned(t)
	await _legend(t)


## Real engine params: the rule on the panel holds for every coin, and the evidence is not a glance giveaway.
func _engine(t) -> void:
	var c := A.real_ctx(41)
	var cfg: Dictionary = c.rules("economy").get("appraise", {}).get("coin_ring", {})
	for tpl in TEMPLATES:
		var spec: Dictionary = c.db.def("it." + str(tpl)).get("coin_ring", {})
		var ring_good: Array = spec["ring_ms_good"]
		var buzz_good: Array = spec["buzz_good"]
		# What a good coin of this kind can sound like (a worn one included), straight from the spec and the rules.
		var ring_lo := int(ring_good[0]) * (100 - int((cfg.get("worn_ring_cut_pct", [15, 30]) as Array)[1])) / 100
		var ring_hi := int(ring_good[1])
		var buzz_hi := int(buzz_good[1]) + int((cfg.get("worn_buzz_add", [0, 10]) as Array)[1])
		var real_ratio := Vector2(INF, -INF)
		var fake_ratio := Vector2(INF, -INF)
		var real_lag := 0
		var fake_lag := 1 << 20
		var fake_near := 1 << 20
		var rings := {"real": [], "fake": []}
		var buzzes := {"real": [], "fake": []}
		var outside: Array = []
		var n := {"real": 0, "fake": 0}
		var sample_dull := {}
		for fake in [false, true]:
			for id in A.items_of(c, str(tpl), fake, PER_TRUTH, "fix2ev"):
				var b := CardAppraisal._build(c, id, &"coin_ring", {})
				var p: Dictionary = b["params"]
				var good: Dictionary = (p["samples"] as Array)[0]
				var dull_s: Dictionary = (p["samples"] as Array)[1]
				t.eq(str(good.get("id", "")), "good", "%s: the first sample is the silver one" % tpl)
				t.eq(str(dull_s.get("id", "")), "dull", "%s: the second sample is the dull one" % tpl)
				sample_dull = dull_s
				var ref := _crests(good)
				var bad: Array = b["answer"]["bad"]
				for i in range((p["coins"] as Array).size()):
					var coin: Dictionary = p["coins"][i]
					var ratio := Voice.wave_px(int(coin["pitch_cents"])) / Voice.wave_px(int(good["pitch_cents"]))
					var mine := _crests(coin)
					var side := "fake" if bad.has(i) else "real"
					n[side] += 1
					(rings[side] as Array).append(int(coin["ring_ms"]))
					(buzzes[side] as Array).append(int(coin["buzz"]))
					if int(coin["ring_ms"]) < ring_lo or int(coin["ring_ms"]) > ring_hi or int(coin["buzz"]) > buzz_hi or int(coin["buzz"]) < int(buzz_good[0]):
						outside.append([side, coin])
					t.eq(Obs.sounds_dull(coin, good), bad.has(i), "%s: the autoplay ear agrees with the truth (%s)" % [tpl, coin])
					# A clink goes by pitch alone too: a worn coin clinks clean, every dull one dulls the pair.
					t.eq(Obs.clink_dullness(coin, good, good) >= RingAudio.CLINK_DULL_FROM, bad.has(i),
						"%s: the clink is dull exactly when the coin is (%s)" % [tpl, coin])
					if bad.has(i):
						fake_ratio = Vector2(minf(fake_ratio.x, ratio), maxf(fake_ratio.y, ratio))
						fake_lag = mini(fake_lag, int(mine[PEAK_K]) - int(ref[PEAK_K]))
						fake_near = mini(fake_near, _worst_near(mine, ref))
					else:
						real_ratio = Vector2(minf(real_ratio.x, ratio), maxf(real_ratio.y, ratio))
						for k in range(CRESTS):
							real_lag = maxi(real_lag, absi(int(mine[k]) - int(ref[k])))
		var cue_ring := _best_cut(rings["real"], rings["fake"])
		var cue_buzz := _best_cut(buzzes["real"], buzzes["fake"])
		print("C13 evidence %s: good ratio %.3f..%.3f crest lag<=%d px | dull ratio %.3f..%.3f 4th crest lag>=%d px nearest>=%d px | cut on length %.2f, on fuzz %.2f" % [
			tpl, real_ratio.x, real_ratio.y, real_lag, fake_ratio.x, fake_ratio.y, fake_lag, fake_near, cue_ring, cue_buzz])
		t.ok(n["real"] >= PER_TRUTH and n["fake"] >= PER_TRUTH, "%s: sampled %s" % [tpl, n])
		# The tell, as the rule on the panel says it.
		t.ok(real_ratio.x >= 1.0 / SAME_MAX and real_ratio.y <= SAME_MAX,
			"%s: every good coin is as dense as the silver sample (wave ratio %.3f..%.3f)" % [tpl, real_ratio.x, real_ratio.y])
		t.ok(real_lag <= REAL_LAG_PX, "%s: a good coin's first five crests sit on the silver one's (max lag %d px)" % [tpl, real_lag])
		t.ok(fake_ratio.x >= SPARSE_MIN, "%s: every dull coin is sparser than the silver sample (min ratio %.3f)" % [tpl, fake_ratio.x])
		t.ok(fake_lag >= FAKE_LAG_PX, "%s: a dull coin's fourth crest falls visibly behind (min lag %d px)" % [tpl, fake_lag])
		t.ok(fake_near >= FAKE_NEAR_PX, "%s: one of a dull coin's first five crests is off the silver ones however paired (min %d px)" % [tpl, fake_near])
		# Not a glance.
		t.ok(fake_ratio.y <= GLANCE_MAX, "%s: the sparsest dull coin is only %.2fx the silver spacing (a look, not a glance)" % [tpl, fake_ratio.y])
		# Length and fuzz never give a coin away: every coin sounds like some good coin of its kind, and one cut on
		# either barely beats a coin toss.
		t.eq(outside, [], "%s: every coin's length and fuzz lie inside what a good (or worn) coin can have [%d..%d ms, fuzz <= %d]" % [tpl, ring_lo, ring_hi, buzz_hi])
		t.ok(cue_ring <= CUE_MAX, "%s: length alone sorts the coins no better than %.2f" % [tpl, cue_ring])
		t.ok(cue_buzz <= CUE_MAX, "%s: fuzz alone sorts the coins no better than %.2f" % [tpl, cue_buzz])
		t.ok((rings["fake"] as Array).max() > (rings["real"] as Array).min() and (rings["fake"] as Array).min() < (rings["real"] as Array).max(),
			"%s: long and short coins on both sides" % tpl)
		# The dull sample shows the rule, not a shortcut: as long and as fuzzy as a worn coin could be, only sparser.
		t.ok(int(sample_dull["ring_ms"]) >= ring_lo and int(sample_dull["ring_ms"]) <= ring_hi and int(sample_dull["buzz"]) <= buzz_hi,
			"%s: the dull sample's length and fuzz are a good coin's too (%s)" % [tpl, sample_dull])
		# Spec bounds (whatever the draws): the closest dull pitch against the lowest silver sample the jitter allows,
		# the farthest against the highest; the whole good band against both.
		var pitch_good: Array = spec["pitch_cents_good"]
		var pitch_bad: Array = spec["pitch_cents_bad"]
		var jit := int(cfg.get("sample_jitter_pct", 3))
		var mid := (int(pitch_good[0]) + int(pitch_good[1])) / 2
		var closest := Voice.wave_px(int(pitch_bad[1])) / Voice.wave_px(mid - jit)
		var farthest := Voice.wave_px(int(pitch_bad[0])) / Voice.wave_px(mid + jit)
		t.ok(closest >= SPARSE_MIN, "%s: the spec's closest dull coin is still %.3fx sparser" % [tpl, closest])
		t.ok(farthest <= GLANCE_MAX, "%s: the spec's sparsest dull coin is only %.3fx (not a glance)" % [tpl, farthest])
		t.ok(Voice.wave_px(int(pitch_good[0])) / Voice.wave_px(mid + jit) <= SAME_MAX
			and Voice.wave_px(int(pitch_good[1])) / Voice.wave_px(mid - jit) >= 1.0 / SAME_MAX, "%s: the whole good band reads as the same density" % tpl)
		t.ok(mid + jit - int(pitch_good[0]) < Obs.PITCH_EAR_CENTS and mid - jit - int(pitch_bad[1]) > Obs.PITCH_EAR_CENTS,
			"%s: the autoplay ear's line sits between the bands" % tpl)


## X of the first CRESTS crests of a coin's line, drawn without fuzz (fuzz never moves the wave underneath).
static func _crests(spec: Dictionary) -> Array:
	var ys := Voice.trace({"ring_ms": int(spec["ring_ms"]), "pitch_cents": int(spec["pitch_cents"]), "buzz": 0}, 0, TRACE_W)
	var out: Array = []
	for i in range(1, ys.size() - 1):
		if ys[i] > 0.0 and ys[i] > ys[i - 1] and ys[i] >= ys[i + 1]:
			out.append(i)
			if out.size() == CRESTS:
				return out
	while out.size() < CRESTS:
		out.append(-1000)
	return out


## The largest, over a line's first five crests, of the distance to the nearest of the silver line's crests.
static func _worst_near(mine: Array, ref: Array) -> int:
	var worst := 0
	var wave := float(ref[1]) - float(ref[0])
	var more: Array = ref.duplicate()
	for k in range(4):
		more.append(int(round(float(ref[ref.size() - 1]) + wave * float(k + 1))))
	for x in mine:
		var best := 1 << 20
		for r in more:
			best = mini(best, absi(int(x) - int(r)))
		worst = maxi(worst, best)
	return worst


## Balanced accuracy of the best single cut on one number (either side called dull).
static func _best_cut(real: Array, fake: Array) -> float:
	var cuts: Array = real + fake
	cuts.sort()
	var best := 0.5
	for cut in cuts:
		var real_below := 0
		var fake_below := 0
		for v in real:
			real_below += 1 if int(v) <= int(cut) else 0
		for v in fake:
			fake_below += 1 if int(v) <= int(cut) else 0
		var low := (float(fake_below) / float(fake.size()) + 1.0 - float(real_below) / float(real.size())) * 0.5
		best = maxf(best, maxf(low, 1.0 - low))
	return best


## Every line starts at the same point in the same phase; the decoration seed only changes the fuzz.
func _phase(t) -> void:
	for cents in [8, 0, -8, -64, -200]:
		var spec := {"ring_ms": 1400, "pitch_cents": cents, "buzz": 0}
		var ys := Voice.trace(spec, 3, TRACE_W)
		t.eq(ys, Voice.trace(spec, 77, TRACE_W), "the seed does not move a clean line (%d c)" % cents)
		t.ok(absf(ys[0]) < 0.001 and ys[1] > 0.0, "every line starts on the axis going up (%d c)" % cents)
	var fuzzy := {"ring_ms": 1400, "pitch_cents": 0, "buzz": 40}
	t.ok(Voice.trace(fuzzy, 3, TRACE_W) != Voice.trace(fuzzy, 77, TRACE_W), "the seed still changes the fuzz")
	var same := {"ring_ms": 900, "pitch_cents": 0, "buzz": 20}
	t.eq(_crests(same), _crests({"ring_ms": 1500, "pitch_cents": 0, "buzz": 0}), "length does not move the crests")


## The two samples' lines stay in the box once blown: 甲 on top, 乙 at the bottom, the customer's line between,
## right under 甲 (blind re-check 2: with the basic eye 乙 was pushed out as soon as the coin was blown).
func _pinned(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var fix := H.fixture("v2_wellmade")
	fix["ghosts"] = 1
	fix["tries"] = 8
	var g := H.open(self, fix, bus)
	var box: Array = [null]
	g.finished.connect(func(r: Dictionary) -> void: box[0] = r)
	await t.frames(1)
	var w = g._wave
	t.eq(w.cap, 3, "ghosts 1: three rows (silver, the coin, dull)")
	t.ok(w.size.y / float(w.cap) >= 40.0, "every row keeps room for the wave (%.0f px)" % (w.size.y / float(w.cap)))
	var rows0: Array = w.shown_rows()
	t.ok(w.pin and (rows0[0] as Dictionary).is_empty() and (rows0[2] as Dictionary).is_empty(), "before the samples are blown their rows wait empty")
	t.eq([w.slot_who(0), w.slot_who(1), w.slot_who(2)], [-1, 0, -2], "the top row waits for 甲, the bottom one for 乙")
	var marks := _row_texts(w)
	t.eq([marks[0], marks[2]], [CardText.ui("c13.label.a"), CardText.ui("c13.label.b")], "the empty sample rows are marked 甲 and 乙")
	g.apply_op(["blow", 0])
	t.eq(w.held(), [0], "coin first: the sample rows are still empty")
	t.eq(g._compared, false, "a coin blown with no sample line in the box is not a comparison")
	g.apply_op(["blow", -1])
	g.apply_op(["blow", -2])
	t.eq(w.held(), [-1, 0, -2], "after both samples the coin's line is still there, between them")
	g.apply_op(["blow", 0])
	t.eq(w.held(), [-1, 0, -2], "the coin's line right under the pinned silver line, 乙 still at the bottom")
	var rows: Array = w.shown_rows()
	t.eq([int(rows[0]["who"]), int(rows[1]["who"]), int(rows[2]["who"])], [-1, 0, -2], "silver, the coin, dull")
	t.eq(w.alpha_of(rows[0]), WaveView.PIN_ALPHA, "the silver line keeps its pinned strength")
	t.eq(w.alpha_of(rows[2]), WaveView.PIN_ALPHA, "the dull line keeps its pinned strength")
	t.ok(WaveView.PIN_ALPHA >= 0.7 and WaveView.PIN_ALPHA > WaveView.FADED_ALPHA, "the pinned lines are not faded ghosts")
	t.eq(w.alpha_of(rows[1]), 1.0, "the line just blown at full strength")
	t.eq(g._compared, true, "blown next to the pinned sample lines: compared")
	g.apply_op(["blow", -2])
	g.apply_op(["blow", -1])
	t.eq(w.held(), [-1, 0, -2], "blowing a sample again never pushes the coin out")
	g.apply_op(["call", 2])
	g.apply_op(["done"])
	t.eq(int((box[0] as Dictionary).get("quality_permille", -1)) if box[0] != null else -1, 1000, "both samples, the coin, compared")
	await H.drop(self, [g])
	# Only 乙 blown, then the coin: still a comparison (乙's line is in the box).
	g = H.open(self, fix, bus)
	await t.frames(1)
	g.apply_op(["blow", -2])
	g.apply_op(["blow", 0])
	t.eq(g._compared, true, "blown next to the pinned dull line: compared")
	await H.drop(self, [g])
	# Eye aid (ghosts 2): one more row for the customer's lines; the newest stays right under 甲, the older fades.
	fix["ghosts"] = 2
	g = H.open(self, fix, bus)
	await t.frames(1)
	for who in [-1, -2, 0, 0]:
		g.apply_op(["blow", who])
	t.eq(g._wave.cap, 4, "ghosts 2: four rows")
	t.eq(g._wave.held(), [-1, 0, 0, -2], "ghosts 2: silver, the two latest coin lines, dull")
	t.eq(g._wave.alpha_of(g._wave.shown_rows()[1]), 1.0, "the newest right under the silver line")
	t.eq(g._wave.alpha_of(g._wave.shown_rows()[2]), WaveView.FADED_ALPHA, "the older coin line fades")
	await H.drop(self, [g])
	# No ghosts: one row, just the latest line.
	fix["ghosts"] = 0
	g = H.open(self, fix, bus)
	await t.frames(1)
	for who in [-1, -2, 0]:
		g.apply_op(["blow", who])
	t.eq([g._wave.cap, g._wave.held()], [1, [0]], "ghosts 0: one row with the latest line")
	await H.drop(self, [g, bus])


static func _row_texts(w: Control) -> Array:
	var out: Array = []
	for c in w.get_children():
		if c is Label:
			out.append((c as Label).text if (c as Label).visible else "")
	return out


## The legend and the two rules: on screen for every coin, from CardText, fitting, clear of everything else,
## and the same whatever the truth.
func _legend(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var seen := {}
	for name in ["v2_good", "v2_dull", "v2_wellmade", "v2_stack"]:
		var g := H.open(self, H.fixture(name), bus)
		await t.frames(2)
		var legend: Control = g._legend
		t.ok(legend != null and legend.is_inside_tree(), name + ": legend on the panel")
		if legend == null:
			await H.drop(self, [g])
			continue
		var labels := _labels(legend)
		var texts: Array = []
		for l in labels:
			texts.append((l as Label).text)
		var stack := (H.fixture(name)["coins"] as Array).size() >= 2
		var keys: Array = CardCoinRingGame.LEGEND_KEYS + CardCoinRingGame.RULE_KEYS
		if not stack:
			keys = keys + ["c13.legend.title", "c13.rule.title"]
		for key in keys:
			t.ok(texts.has(CardText.ui(key)) and CardText.ui(key) != "", "%s: %s on screen" % [name, key])
		t.eq(t.all_text_from_cardtext(legend), PackedStringArray(), name + ": legend text from CardText")
		seen[name] = texts
		var frame: Rect2 = g._panel.get_global_rect()
		var others: Array = []
		for c in g._coin_faces + g._sample_faces + g._call_btns + g._chips + [g._done_btn, g._wave]:
			others.append(c)
		for path in ["Note", "Tries", "Samples"]:
			if g._panel.get_node_or_null(path) != null:
				others.append(g._panel.get_node(path))
		for c in g._panel.get_children():
			if c is Label and c != g._panel.get_node_or_null("Note"):
				others.append(c)   # the title and the coin's caption
		for l in labels:
			var r := (l as Control).get_global_rect()
			t.ok(frame.encloses(r), "%s: %s inside the frame" % [name, l.name])
			for o in others:
				t.ok(not r.intersects((o as Control).get_global_rect()), "%s: %s clear of %s" % [name, l.name, o.name])
		for box in legend.get_children():
			if box is VBoxContainer:
				var need := (box as Control).get_combined_minimum_size()
				t.ok(need.y <= (box as Control).size.y + 0.5 and need.x <= (box as Control).size.x + 0.5,
					"%s: %s fits (%s in %s)" % [name, box.name, need, (box as Control).size])
		if not stack:
			var abort := g.abort_rect()
			for l in labels:
				t.ok(not (l as Control).get_global_rect().intersects(abort), "%s: %s clear of the abort spot" % [name, l.name])
		await H.drop(self, [g])
	t.eq(seen.get("v2_good", []), seen.get("v2_dull", []), "the same legend for a good and a dull coin")
	t.eq(seen.get("v2_good", []), seen.get("v2_wellmade", []), "the same legend for a well-made dull coin")
	await H.drop(self, [bus])


static func _labels(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Label:
			out.append(c)
		out.append_array(_labels(c))
	return out
