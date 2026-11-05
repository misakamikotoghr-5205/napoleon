# v0.2 回归：夜里“整理库房”加的价值要一直记在这件东西上（第二晚、日结、挑选列表都看得到）。
# 第一晚整理一件库存 → 跑到第二晚 → 断言 tidy_bonus ≥ 0.05，且 market_now 比“同一行情下未整理”的价高。
# godot --headless -s res://scripts/tests/test_tidy.gd    （失败退出码 1）
extends SceneTree

const Director = preload("res://scripts/core/director.gd")
const Autoplayer = preload("res://scripts/tests/autoplayer.gd")

var director
var ap
var errs: Array = []
var tidied_iid: String = ""
var base_at_tidy: int = 0
var night2_seen: bool = false
var night2_market: int = 0
var t0: int = 0

func _initialize() -> void:
	t0 = Time.get_ticks_msec()
	director = Director.new()
	root.add_child(director)
	director.setup(19380306)
	ap = Autoplayer.new(director, "fair", 19380306)
	# 第一晚只做“整理库房”；第二晚先“对账”再睡（不再整理，看旧的加成是否还在）
	ap.plan = {"night1": ["tidy"], "night2": ["ledger"], "base": "fair"}
	director.beat.connect(_watch)
	director.stop_at = "night2_done"
	director.finished.connect(_done, CONNECT_DEFERRED)
	director.run()

func _process(_d: float) -> bool:
	if Time.get_ticks_msec() - t0 > 120000:
		errs.append("超时")
		_finish()
	return false

# 记下第一晚被整理的那件、以及整理前（同一行情）的价
func _watch(b: Dictionary) -> void:
	if b.get("nowait", false):
		return
	var w = director.world
	# v0.3：库存可能有开局当品，自动试玩随机挑一件——以真正被整理的那件为准
	if director.night_no == 1 and tidied_iid == "":
		for iid in w.ledger.items_at("stock"):
			var it0: Dictionary = w.ledger.items[iid]
			if float(it0.get("tidy_bonus", 0.0)) >= 0.05 or it0.get("history", []).has("夜里整理过"):
				tidied_iid = iid
				# 反推整理前市价（去掉 5% 加成）
				var pm: float = w.price_mod(it0) * (1.0 + float(it0.get("market_bonus", 0.0)))
				base_at_tidy = int(round(float(it0.get("market", 0)) * pm))
				break
	if b["type"] == "night" and int(b["night"]) == 2 and not night2_seen and tidied_iid != "":
		night2_seen = true
		var it: Dictionary = w.ledger.items[tidied_iid]
		night2_market = w.market_now(it)
		var bonus := float(it.get("tidy_bonus", 0.0))
		if bonus < 0.05:
			errs.append("第二晚 tidy_bonus = %.3f（应 ≥ 0.05）" % bonus)
		# 控制行情：同一件东西，同样的行情系数，未整理的价
		var untidied := int(round(float(it.get("market", 0)) * w.price_mod(it) * (1.0 + float(it.get("market_bonus", 0.0)))))
		if night2_market <= untidied:
			errs.append("第二晚 market_now %d 没有高于同行情未整理价 %d" % [night2_market, untidied])
		if not it.get("history", []).has("夜里整理过"):
			errs.append("物件经历里没有“夜里整理过”")
		print("整理过的：%s  整理前 %d → 第二晚 %d（同行情未整理 %d，加成 %.2f）" % [it["name"], base_at_tidy, night2_market, untidied, bonus])

func _done() -> void:
	if tidied_iid == "":
		errs.append("第一晚没有整理任何东西（库存为空？）")
	if not night2_seen:
		errs.append("没有到第二晚")
	_finish()

func _finish() -> void:
	ap = null
	for c in root.get_children():
		c.queue_free()
	await process_frame
	DB.shutdown()
	if errs.is_empty():
		print("TIDY OK")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: ", e)
		quit(1)
