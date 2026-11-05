# 吹银元：把玩家的判断换成观察键、按过程算清晰度。观察 = 玩家自己说的话，说错了照样交（DESIGN P2）；
# 清晰度只看玩家在屏幕上做过什么（两枚样洋听没听过、客人的每枚听没听过、有没有对着样洋的余音比），
# 不看说得对不对（P3）。主人 C13。合同：docs/cards/CARDS_INTERFACES.md §8.1、§8.2、§4.8；设计 appraise/DESIGN.md §5.5。
extends RefCounted

const PREFIX := "obs.coin_ring."
const CALL_NONE := 0
const CALL_GOOD := 1
const CALL_DULL := 2
const CALL_UNSURE := 3
const MARK_UNSET := 0
const MARK_RING := 1
const MARK_DULL := 2
const Q_SAMPLES := 350
const Q_COINS := 350
const Q_COMPARED := 300
## 耳朵分得出来的“偏低”：比足银样洋低这么多音分以上，听着就和哑板一路（自动玩的耳朵）。
## 复审三：足银和甲最多差十一音分，哑板至少低四十二音分（规格的 pitch_cents_bad 收紧了），门槛放在中间。
const PITCH_EAR_CENTS := 25
## 相碰的闷只跟音高走（规矩：长短、毛刺都骗人）：比甲低 CLINK_FROM_CENTS 以内一点不闷，低 CLINK_FULL_CENTS 以上闷到底。
const CLINK_FROM_CENTS := 12
const CLINK_FULL_CENTS := 62


## 单枚（n == 1）看 call，一摞看 marks。没定的、没说的都记“说不好”。
static func observations(n: int, call: int, marks: Array) -> Array:
	if n <= 1:
		match call:
			CALL_GOOD:
				return [PREFIX + "like_reference"]
			CALL_DULL:
				return [PREFIX + "like_dull_sample"]
		return [PREFIX + "unsure"]
	var dull := 0
	var unset := 0
	for i in range(n):
		var m := int(marks[i]) if i < marks.size() else MARK_UNSET
		if m == MARK_DULL:
			dull += 1
		elif m != MARK_RING:
			unset += 1
	var out: Array = []
	if dull == 1:
		out.append(PREFIX + "one_dull")
	elif dull >= 2:
		out.append(PREFIX + "some_dull")
	elif unset == 0:
		out.append(PREFIX + "all_ring")
	if unset > 0:
		out.append(PREFIX + "unsure")
	return out


## 过程分：+350 两枚样洋都吹过，+350 客人的每一枚都吹过，+300 吹客人的那一下样洋的余音线还留在框里。
static func quality_permille(samples_heard: bool, coins_heard: bool, compared: bool) -> int:
	var q := 0
	if samples_heard:
		q += Q_SAMPLES
	if coins_heard:
		q += Q_COINS
	if compared:
		q += Q_COMPARED
	return clampi(q, 0, 1000)


## 一枚听起来像不像哑板（只看物理量和柜上的足银样洋）：自动玩的“耳朵”，测试也用它出答案。
static func sounds_dull(coin: Dictionary, good: Dictionary) -> bool:
	return int(good.get("pitch_cents", 0)) - int(coin.get("pitch_cents", 0)) > PITCH_EAR_CENTS


## 两枚相碰有多闷（0..1000，连续）：取两枚里更“哑”的那一枚。只看比甲低多少（复审三：旧洋余音短、毛刺多，
## 碰起来照样清脆；原来短和毛也算闷，旧洋碰出来半闷，和规矩“长短、毛刺都骗人”对不上）。
static func clink_dullness(a: Dictionary, b: Dictionary, good: Dictionary) -> int:
	return maxi(_dullness(a, good), _dullness(b, good))


static func _dullness(coin: Dictionary, good: Dictionary) -> int:
	var low := int(good.get("pitch_cents", 0)) - int(coin.get("pitch_cents", 0)) - CLINK_FROM_CENTS
	return clampi(low * 1000 / (CLINK_FULL_CENTS - CLINK_FROM_CENTS), 0, 1000)
