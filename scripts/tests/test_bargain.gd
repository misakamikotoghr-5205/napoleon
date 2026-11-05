# v0.2 回归：讨价还价不会无限循环。
# 1) 卖货（周妈买米）一直要价高于她的最高价 → 最多 5 轮她就走，会话关闭；
# 2) 收货（小丁卖米）一直出价低于底价 → 最多 5 轮他就走；
# 3) 在“客人出价—最高价”之间的公道要价，若干种子里至少有一半能在 5 轮内成交；
# 4) 对所有带人格的顾客，任何出价序列都在 6 轮内结束（成交或离开）。
# godot --headless -s res://scripts/tests/test_bargain.gd   （失败退出码 1）
extends SceneTree

const World = preload("res://scripts/core/world.gd")
const Session = preload("res://scripts/core/session.gd")

var errs: Array = []

func _initialize() -> void:
	_case_sell_spam()
	_case_buy_lowball()
	_case_fair_mid()
	_case_all_terminate()
	DB.shutdown()
	if errs.is_empty():
		print("BARGAIN OK")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: ", e)
		quit(1)

func _world(seed_v: int):
	var w = World.new()
	w.setup(seed_v)
	return w

func _sell_session(w, npc: String = "zhouma"):
	w.ledger.add_item(_def("rice_sunji"), "player", "stock")
	var s = Session.new()
	s.setup(w, {"id": "probe_sell", "npc": npc, "mode": "sell", "stock": ["rice_sunji"], "buyer_prices": {"rice_sunji": {"offer": 55, "max": 75}}})
	return s

func _def(id: String) -> Dictionary:
	var d: Dictionary = DB.get_db().items[id].duplicate(true)
	d["def_id"] = id
	return d

func _case_sell_spam() -> void:
	var w = _world(1)
	var s = _sell_session(w)
	var n := 0
	var last := ""
	while not s.closed and n < 20:
		n += 1
		last = s.offer(s.floor_v + 30)["result"]
		if last == "accept":
			break
	if last != "leave" or not s.closed:
		errs.append("卖货一直要高价：%d 轮后结果 %s、closed=%s（应在 5 轮内离开）" % [n, last, str(s.closed)])
	elif n > 5:
		errs.append("卖货一直要高价：拖到第 %d 轮才离开（上限 5）" % n)
	print("卖货高价连发：第 %d 轮 %s" % [n, last])

func _case_buy_lowball() -> void:
	var w = _world(2)
	var s = Session.new()
	s.setup(w, {"id": "probe_buy", "npc": "xiaoding", "mode": "buy", "items": [], "ask": 50, "floor": 25, "suggest": 40, "est": [40, 90]})
	var n := 0
	var last := ""
	while not s.closed and n < 20:
		n += 1
		last = s.offer(15)["result"]
		if last == "accept":
			break
	if last != "leave" or n > 5:
		errs.append("收货一直压价：%d 轮后 %s（应在 5 轮内离开）" % [n, last])
	print("收货压价连发：第 %d 轮 %s" % [n, last])

func _case_fair_mid() -> void:
	var ok := 0
	for sd in range(1, 11):
		var w = _world(100 + sd)
		var s = _sell_session(w)
		var mid := int((s.ask + s.floor_v) / 2.0)
		for i in range(5):
			var r: String = s.offer(mid)["result"]
			if r == "accept":
				ok += 1
				break
			if r == "leave":
				break
	print("公道中间价成交：%d / 10 个种子" % ok)
	if ok < 5:
		errs.append("公道中间价只在 %d/10 个种子里成交（应 ≥ 5）" % ok)

func _case_all_terminate() -> void:
	for npc in ["xiaoding", "zhang", "wangshan", "li", "linsao", "zhouma", "zhao", "sunyoung", "ma", "guanjia"]:
		if not DB.get_db().cast.has(npc):
			continue
		for mode in ["buy", "sell"]:
			var w = _world(7)
			var s
			if mode == "sell":
				s = _sell_session(w, npc)
			else:
				s = Session.new()
				s.setup(w, {"id": "probe", "npc": npc, "mode": "buy", "items": [], "ask": 100, "floor": 60, "suggest": 60, "est": [50, 120]})
			var n := 0
			var v: int = 40 if mode == "buy" else int(s.floor_v) + 10
			while not s.closed and n < 12:
				n += 1
				if s.offer(v)["result"] == "accept":
					break
			if n > 6:
				errs.append("%s（%s）谈了 %d 轮还没结束" % [npc, mode, n])
