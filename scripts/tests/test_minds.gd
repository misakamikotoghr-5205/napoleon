# 人格大脑测试：同一笔买卖、同样的出价顺序，不同性格的客人反应不同（GameJev P01/D02）。
# 检查：PersonaResidual 模型已加载且残差非零；第一天四位顾客的让步/求情/离开模式不全相同；同种子结果可复现。
# godot --headless -s res://scripts/tests/test_minds.gd     （失败退出码 1）
extends SceneTree

const World = preload("res://scripts/core/world.gd")
const Session = preload("res://scripts/core/session.gd")

const NPCS = ["xiaoding", "zhang", "wangshan", "li", "linsao", "zhao", "sunyoung", "ma"]
const OFFERS = [40, 55, 65, 75, 85]

func _initialize() -> void:
	var errs: Array = []
	var sigs: Dictionary = {}
	var w = World.new()
	w.setup(19380306)
	if not w.mind.model_ok:
		errs.append("PersonaResidual 模型没有加载")
	print("同一笔：要价 100、底价 50；依次出价 ", OFFERS)
	for id in NPCS:
		var sig := _run(id)
		var again := _run(id)
		if sig != again:
			errs.append("%s：同种子结果不一致（%s / %s）" % [id, sig, again])
		sigs[id] = sig
		print("  %-9s %s" % [id, sig])
	var residual_nonzero := false
	var n: Dictionary = w.npcs["xiaoding"]
	var d: Dictionary = w.mind.decide(n, [{"id": "a", "utility": 0.0, "attrs": {"gain": 0.5}}, {"id": "b", "utility": 0.0, "attrs": {"withdrawal": 0.8}}], {}, "probe")
	for r in d.get("residuals", []):
		if absf(float(r)) > 0.0001:
			residual_nonzero = true
	if not residual_nonzero:
		errs.append("PersonaResidual 残差全为 0")
	var distinct := {}
	for id in ["xiaoding", "zhang", "wangshan", "li"]:
		distinct[sigs[id]] = true
	if distinct.size() < 2:
		errs.append("第一天四位顾客的议价反应完全一样：" + str(sigs))
	DB.shutdown()
	if errs.is_empty():
		print("MINDS OK（%d 种不同的议价模式）" % _count_distinct(sigs))
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: ", e)
		quit(1)

func _count_distinct(sigs: Dictionary) -> int:
	var d := {}
	for k in sigs:
		d[sigs[k]] = true
	return d.size()

# 返回“反应签名”：每次出价后客人的回应（接受 A / 还价 C数字 / 求情 P / 离开 L）
func _run(id: String) -> String:
	var w = World.new()
	w.setup(19380306)
	var s = Session.new()
	s.setup(w, {"id": "probe_" + id, "npc": id, "mode": "buy", "items": [], "ask": 100, "floor": 50, "suggest": 60, "est": [50, 120]})
	var out: Array = []
	for v in OFFERS:
		var r: Dictionary = s.offer(v)
		match r["result"]:
			"accept":
				out.append("A%d" % v)
				break
			"counter":
				out.append("C%d" % s.ask)
			"plead":
				out.append("P")
			"leave":
				out.append("L")
				break
	return " ".join(out)
