# 观察目录和清晰度（DESIGN §3.2、§5.5、P3）：
# - 目录：键都以 obs.coin_ring. 开头、无判词；fidelity 只有 clear/partial/vague；hedge 指向同目录里口气更软的那一档；
#   判断键（像足银 / 像哑板 / 都响 / 一枚哑 / 不止一枚哑）都是 clear，各配一个 partial 的 _maybe，vague 落到 unsure；
#   unsure 在哪一档都照记（hedge 指回自己）。老键留着兼容。
# - 清晰度只看过程：+350 两枚样洋都吹过、+350 客人的每一枚都吹过、+300 吹客人那一下样洋的线还留着；不看说得对不对。
# - 结果的形状：五个键、measures 只放玩家的原始操作（整数、布尔、整数数组），键不碰 §7.5 黑名单。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const VERDICT := ["fake", "real", "genuine", "forged", "true", "false", "authentic"]
const CJK_VERDICT := ["真", "假", "仿", "赝", "掺"]
const CLAIMS := ["like_reference", "like_dull_sample", "all_ring", "one_dull", "some_dull"]
const MAYBE := {"like_reference": "like_reference_maybe", "like_dull_sample": "like_dull_maybe", "all_ring": "all_ring_maybe",
	"one_dull": "one_dull_maybe", "some_dull": "some_dull_maybe"}
const OLD := ["ring_long", "ring_short", "dull", "buzzy", "pitch_low", "unlike_reference", "ring_vague"]
const MEASURES := ["blows", "call", "clinked", "clinks", "compared", "listened_ms", "marks"]


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_fidelity"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var db := CardDB.load_all(CardDB.DEFAULT_ROOT, {})
	CardText.setup(db)
	_catalog(t, db.obs_catalog(&"coin_ring"))
	await _clarity(t)
	await _shapes(t)


func _catalog(t, cat: Dictionary) -> void:
	var want: Array = []
	for k in CLAIMS + MAYBE.values() + OLD + ["unsure"]:
		want.append("obs.coin_ring." + str(k))
	want.sort()
	var names: Array = cat.keys()
	names.sort()
	t.eq(names, want, "catalog keys")
	for k in cat.keys():
		var row: Dictionary = cat[k]
		var key := str(k)
		t.ok(str(row.get("fidelity", "")) in ["clear", "partial", "vague"], "fidelity %s" % key)
		t.ok(str(row.get("brief", "")) != "", "brief %s" % key)
		t.ok(not _bad_key(key), "no verdict word in %s" % key)
		for ch in CJK_VERDICT:
			t.ok(not str(row.get("brief", "")).contains(ch), "no verdict in the brief of %s" % key)
		t.ok(CardText.has_text(key), "AI text for %s" % key)
		var hedge = row.get("hedge", {})
		t.eq(typeof(hedge), TYPE_DICTIONARY, "hedge is an object in %s" % key)
		for tier in (hedge as Dictionary).keys():
			var to := str(hedge[tier])
			t.ok(str(tier) in ["clear", "partial", "vague"] and str(tier) != str(row["fidelity"]), "hedge tier %s of %s" % [tier, key])
			t.ok(to == "" or cat.has(to), "hedge target %s of %s is in the catalog" % [to, key])
			if to != "" and cat.has(to) and to != key:
				t.eq(str(cat[to]["fidelity"]), str(tier), "hedge %s -> %s lands on a %s key" % [key, to, tier])
	for c in CLAIMS:
		var row: Dictionary = cat["obs.coin_ring." + c]
		t.eq(row["fidelity"], "clear", "%s is a clear claim" % c)
		t.eq(row.get("hedge", {}).get("partial", ""), "obs.coin_ring." + MAYBE[c], "%s softens to its maybe" % c)
		t.eq(row.get("hedge", {}).get("vague", ""), "obs.coin_ring.unsure", "%s falls to unsure when vague" % c)
	var unsure: Dictionary = cat["obs.coin_ring.unsure"]
	t.eq(unsure["fidelity"], "vague", "unsure is vague")
	t.eq(unsure.get("hedge", {}), {"clear": "obs.coin_ring.unsure", "partial": "obs.coin_ring.unsure"}, "unsure is kept at every tier")


func _clarity(t) -> void:
	var full: Array = [["blow", -1], ["blow", -2], ["blow", 0], ["call", 2], ["done"]]
	var cases := [
		["v2_good", full, 1000, "both samples, the coin, compared"],
		["v2_good", [["blow", 0], ["call", 2], ["done"]], 350, "only the coin"],
		["v2_good", [["blow", -1], ["blow", -2], ["call", 2], ["done"]], 350, "only the samples"],
		["v2_good", [["blow", -1], ["blow", 0], ["call", 2], ["done"]], 650, "one sample, the coin, compared"],
		["v2_good", [["blow", 0], ["blow", -1], ["blow", -2], ["call", 2], ["done"]], 700, "coin first: not compared"],
		["v2_good", [["call", 1], ["done"]], 0, "nothing heard"],
		["v2_stack", [["blow", -1], ["blow", -2], ["blow", 0], ["blow", 1], ["blow", 2], ["blow", 3], ["done"]], 650, "one coin of the roll not heard"],
		["v2_stack", [["blow", -1], ["blow", -2], ["blow", 0], ["blow", 1], ["blow", 2], ["blow", 3], ["blow", 4], ["done"]], 1000, "every coin of the roll"],
	]
	for row in cases:
		var r: Dictionary = (await H.run_ops(self, H.fixture(row[0]), row[1]))["result"]
		t.eq(r["quality_permille"], row[2], "%s: %s" % [row[0], row[3]])
	# Clarity does not look at the answer: the same ops on a good and a dull coin, and with a right and a wrong call.
	var qs: Array = []
	for name in ["v2_good", "v2_dull", "v2_worn", "v2_wellmade"]:
		for c in [1, 2]:
			var ops := full.duplicate(true)
			ops[3] = ["call", c]
			qs.append(int((await H.run_ops(self, H.fixture(name), ops))["result"]["quality_permille"]))
	t.eq(qs, [1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000], "right or wrong, same process, same clarity")
	# No ghost line (ghosts 0): the sample's line is gone when the coin rings, so it is not a comparison.
	var bare := H.fixture("v2_good")
	bare["ghosts"] = 0
	var r0: Dictionary = (await H.run_ops(self, bare, full))["result"]
	t.eq(r0["quality_permille"], 700, "without a ghost line there is nothing to compare against")
	t.eq(r0["measures"]["compared"], false, "not compared")


func _shapes(t) -> void:
	for name in H.ALL:
		for skill in [0.2, 0.8]:
			var r: Dictionary = (await H.auto(self, H.fixture(name), skill))["result"]
			var keys: Array = r.keys()
			keys.sort()
			t.eq(keys, ["aborted", "measures", "minutes", "observations", "quality_permille"], "%s: result keys" % name)
			t.eq(typeof(r["quality_permille"]), TYPE_INT, "quality is int")
			t.ok(int(r["quality_permille"]) >= 0 and int(r["quality_permille"]) <= 1000, "quality range")
			t.eq(typeof(r["minutes"]), TYPE_INT, "minutes is int")
			t.eq(r["aborted"], false, "not aborted")
			var m: Dictionary = r["measures"]
			var mk: Array = m.keys()
			mk.sort()
			t.eq(mk, MEASURES, "%s: measure keys" % name)
			for k in ["blows", "clinks", "call", "listened_ms"]:
				t.eq(typeof(m[k]), TYPE_INT, "%s is int" % k)
			for k in ["compared", "clinked"]:
				t.eq(typeof(m[k]), TYPE_BOOL, "%s is bool" % k)
			for v in m["marks"]:
				t.eq(typeof(v), TYPE_INT, "marks are ints")
			t.eq(t.find_floats(r).size(), 0, "no floats in the result")
			t.ok(CardAppraisal._valid_result(r), "%s: the engine accepts the result" % name)
			t.no_leaks(m, "%s measures" % name)
			for k in r["observations"]:
				t.ok(str(k).begins_with("obs.coin_ring.") and not _bad_key(str(k)), "observation %s" % k)


func _bad_key(key: String) -> bool:
	for w in VERDICT:
		if key.split(".").has(w) or key.contains("_" + w) or key.contains(w + "_"):
			return true
	return false
