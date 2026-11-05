# 吹银元的“声音模型”：一枚银元（ring_ms 余音长短、pitch_cents 音高、buzz 杂音）+ 装饰种子 → 声音参数和余音线。
# 声音（开发版合成、AI 线的样本生成）和画面上的余音线都从这里来，所以听到的和看到的是同一样东西。
# 纯函数，不读引擎、不读随机数；同样的输入永远给同样的输出（装饰噪声用自己的整数 LCG）。主人 C13。
# 设计：appraise/DESIGN.md §5.3（余音线长短跟 ring_ms、疏密跟 pitch_cents、毛边跟 buzz）。
extends RefCounted

const BASE_HZ := 2000.0            # pitch_cents 0 的基音
const PARTIALS := [[1.0, 0.45], [2.76, 0.2], [5.4, 0.09]]   # 圆片的分音比和响度（照原型 ringSound）
const PARTIAL_DECAY_EXP := 0.35    # 高分音衰减得快：tau / ratio^0.35
const RING_DB := 50.0              # ring_ms = 基音衰到 -50 dB 的时间
const NOISE_MAX := 0.35            # buzz 100 时沙声的响度
const AM_MAX := 0.55               # buzz 100 时余音被“搓”的深度
const THUMP_HZ := 190.0
const THUMP_MAX := 0.32
const THUMP_FROM_MS := 800         # 余音短于这个才有闷的“咚”
const STRIKE := 0.22               # 指甲弹的那一下（所有银元一样）
const TAIL_MS := 120
const VIEW_MS := 2000              # 余音线整宽代表的毫秒
const WAVE_PX := 12.0              # pitch_cents 0 时余音线一个起伏的像素宽
const WAVE_CENTS := 200.0          # 画面上的疏密比耳朵听的夸大：每低 200 音分，起伏宽一倍
const CLINK_MS := 160


## 一枚银元的声音参数。salt 只换装饰（噪声花样、分音的细微响度），不动长短、高低、杂音。
static func voice(spec: Dictionary, salt: int = 0) -> Dictionary:
	var ring := clampi(int(spec.get("ring_ms", 400)), 60, 2400)
	var cents := clampi(int(spec.get("pitch_cents", 0)), -600, 600)
	var buzz := clampi(int(spec.get("buzz", 0)), 0, 100)
	var f0 := BASE_HZ * pow(2.0, float(cents) / 1200.0)
	var tau := float(ring) / 1000.0 / (RING_DB / 20.0 * log(10.0))
	var parts: Array = []
	for i in range(PARTIALS.size()):
		var ratio: float = PARTIALS[i][0]
		var amp: float = PARTIALS[i][1] * (0.9 + 0.2 * _unit(salt, 11 + i))
		parts.append([f0 * ratio, amp, tau / pow(ratio, PARTIAL_DECAY_EXP)])
	var thump := clampf(float(THUMP_FROM_MS - ring) / 500.0, 0.0, 1.0) * THUMP_MAX
	return {
		"f0": f0, "tau": tau, "partials": parts, "noise": float(buzz) / 100.0 * NOISE_MAX,
		"am": float(buzz) / 100.0 * AM_MAX, "thump": thump, "thump_hz": THUMP_HZ * pow(2.0, float(cents) / 1200.0),
		"length_ms": ring + TAIL_MS, "ring_ms": ring, "cents": cents, "buzz": buzz, "salt": salt,
	}


## 把声音参数合成单声道样本（-1..1）。只在开发版的合成路径和 AI 样本生成里用。
## 最多五个分音（相碰用五个、余音用三个），展开写成局部变量，免得热循环里查 Variant 数组。
static func render(v: Dictionary, mix_rate: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var count := maxi(int(float(mix_rate) * float(v.get("length_ms", 400)) / 1000.0), 1)
	out.resize(count)
	var nyq := float(mix_rate) * 0.45
	var cw := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var sw := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var amp := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var dk := PackedFloat64Array([1.0, 1.0, 1.0, 1.0, 1.0])
	var used := 0
	for p in v.get("partials", []):
		if used >= 5 or float(p[0]) >= nyq or float(p[1]) <= 0.0:
			continue
		var w := TAU * float(p[0]) / float(mix_rate)
		cw[used] = cos(w)
		sw[used] = sin(w)
		amp[used] = float(p[1])
		dk[used] = exp(-1.0 / (maxf(float(p[2]), 0.001) * float(mix_rate)))
		used += 1
	var c0 := 1.0
	var s0 := 0.0
	var c1 := 1.0
	var s1 := 0.0
	var c2 := 1.0
	var s2 := 0.0
	var c3 := 1.0
	var s3 := 0.0
	var c4 := 1.0
	var s4 := 0.0
	var a0 := amp[0]
	var a1 := amp[1]
	var a2 := amp[2]
	var a3 := amp[3]
	var a4 := amp[4]
	var w0c := cw[0]
	var w0s := sw[0]
	var d0 := dk[0]
	var w1c := cw[1]
	var w1s := sw[1]
	var d1 := dk[1]
	var w2c := cw[2]
	var w2s := sw[2]
	var d2 := dk[2]
	var w3c := cw[3]
	var w3s := sw[3]
	var d3 := dk[3]
	var w4c := cw[4]
	var w4s := sw[4]
	var d4 := dk[4]
	var noise_amp := float(v.get("noise", 0.0))
	var am := float(v.get("am", 0.0)) * 4.0
	var thump := float(v.get("thump", 0.0))
	var tw := TAU * float(v.get("thump_hz", THUMP_HZ)) / float(mix_rate)
	var t_env := 1.0
	var t_decay := exp(-1.0 / (0.06 * float(mix_rate)))
	var fund_env := 1.0
	var fund_decay := exp(-1.0 / (maxf(float(v.get("tau", 0.2)), 0.001) * float(mix_rate)))
	var strike_n := maxi(int(0.006 * float(mix_rate)), 1)
	var attack_n := maxi(int(0.003 * float(mix_rate)), 1)
	var state := (int(v.get("salt", 0)) * 2654435761 + 97) & 0x7fffffff
	var lp := 0.0
	var slow := 0.0
	for n in range(count):
		state = (state * 1103515245 + 12345) & 0x7fffffff
		var white := float(state) / 1073741824.0 - 1.0
		lp += (white - lp) * 0.35
		slow += (white - slow) * 0.02
		var t := c0
		c0 = t * w0c - s0 * w0s
		s0 = s0 * w0c + t * w0s
		a0 *= d0
		var ring := s0 * a0
		if used > 1:
			t = c1
			c1 = t * w1c - s1 * w1s
			s1 = s1 * w1c + t * w1s
			a1 *= d1
			ring += s1 * a1
		if used > 2:
			t = c2
			c2 = t * w2c - s2 * w2s
			s2 = s2 * w2c + t * w2s
			a2 *= d2
			ring += s2 * a2
		if used > 3:
			t = c3
			c3 = t * w3c - s3 * w3s
			s3 = s3 * w3c + t * w3s
			a3 *= d3
			ring += s3 * a3
		if used > 4:
			t = c4
			c4 = t * w4c - s4 * w4s
			s4 = s4 * w4c + t * w4s
			a4 *= d4
			ring += s4 * a4
		ring *= 1.0 + am * slow
		var sample := ring * minf(1.0, float(n) / float(attack_n))
		sample += (white - lp) * noise_amp * fund_env
		if thump > 0.0:
			sample += sin(tw * float(n)) * thump * t_env
			t_env *= t_decay
		if n < strike_n:
			sample += white * STRIKE * (1.0 - float(n) / float(strike_n))
		fund_env *= fund_decay
		out[n] = clampf(sample * 0.8, -1.0, 1.0)
	return out


## 两枚相碰：dull_permille 0 = 两枚都清脆，1000 = 里面有一枚很闷。连续变化，不是开关。
static func clink_voice(dull_permille: int, salt: int = 0) -> Dictionary:
	var d := clampf(float(dull_permille) / 1000.0, 0.0, 1.0)
	var parts: Array = []
	for row in [[3150.0, 0.34, 0.070], [4720.0, 0.2, 0.050], [6830.0, 0.1, 0.035]]:
		parts.append([row[0], row[1] * (1.0 - d), row[2]])
	for row in [[820.0, 0.36, 0.034], [1310.0, 0.16, 0.024]]:
		parts.append([row[0], row[1] * d, row[2]])
	return {
		"f0": 3150.0, "tau": lerpf(0.07, 0.03, d), "partials": parts, "noise": lerpf(0.05, 0.16, d),
		"am": 0.0, "thump": 0.3 * d, "thump_hz": 160.0, "length_ms": CLINK_MS, "ring_ms": CLINK_MS,
		"cents": 0, "buzz": 0, "salt": salt, "dull_permille": int(d * 1000.0),
	}


## 余音线：一枚银元在宽 width 像素的框里画多长、每个像素的起伏（-1..1）。
## 长短跟 ring_ms（VIEW_MS 占满整宽），疏密跟 pitch_cents（夸大了的），毛边跟 buzz。
## 每枚都从同一个起点、同一个相位起振（弹的那一下一样），所以两道线的起伏对得齐不齐只看音高：
## 和甲一样高的一路对齐，低了的几个起伏之内就错开（DESIGN 5.3；fix2：原来装饰种子会挪起点，同音的也像错开了）。
## salt 只换毛边的花样。
static func trace(spec: Dictionary, salt: int, width: float) -> PackedFloat32Array:
	var v := voice(spec, salt)
	var ring := int(v["ring_ms"])
	var n := clampi(int(width * float(ring) / float(VIEW_MS)), 4, maxi(int(width), 4))
	var wave := wave_px(int(v["cents"]))
	var buzz := float(v["buzz"]) / 100.0
	var out := PackedFloat32Array()
	out.resize(n)
	var state := (salt * 40503 + 7) & 0x7fffffff
	for i in range(n):
		state = (state * 1103515245 + 12345) & 0x7fffffff
		var jag := float(state) / 1073741824.0 - 1.0
		var t := float(i) / float(n)
		var env := pow(1.0 - t, 1.5)
		var y := sin(TAU * float(i) / wave) * env
		y += jag * buzz * 0.55 * maxf(env, 0.25)
		out[i] = clampf(y, -1.0, 1.0)
	return out


## 相碰的线：清脆 = 高、窄的尖峰；闷 = 低、宽的鼓包。返回每个像素的起伏（-1..1），宽约框的三分之一。
static func clink_trace(dull_permille: int, salt: int, width: float) -> PackedFloat32Array:
	var d := clampf(float(dull_permille) / 1000.0, 0.0, 1.0)
	var n := maxi(int(width * 0.36), 8)
	var center := float(n) * 0.18
	var half_w := lerpf(5.0, 34.0, d)
	var height := lerpf(1.0, 0.42, d)
	var wave := lerpf(5.0, 22.0, d)
	var out := PackedFloat32Array()
	out.resize(n)
	var state := (salt * 69069 + 3) & 0x7fffffff
	for i in range(n):
		state = (state * 1103515245 + 12345) & 0x7fffffff
		var jag := float(state) / 1073741824.0 - 1.0
		var x := float(i) - center
		var env := exp(-(x * x) / (2.0 * half_w * half_w)) if x < 0.0 else exp(-x / (half_w * 1.6))
		var y := sin(TAU * float(i) / wave) * env * height + jag * 0.08 * env * d
		out[i] = clampf(y, -1.0, 1.0)
	return out


## 余音线上一个起伏的像素宽：越低越宽。
static func wave_px(cents: int) -> float:
	return clampf(WAVE_PX * pow(2.0, -float(cents) / WAVE_CENTS), 5.0, 60.0)


## 0..1 的确定小数（装饰用）。
static func _unit(salt: int, k: int) -> float:
	var h := (salt * 2246822519 + k * 3266489917 + 374761393) & 0xffffffff
	h = ((h ^ (h >> 15)) * 2246822519) & 0xffffffff
	h = ((h ^ (h >> 13)) * 3266489917) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0
