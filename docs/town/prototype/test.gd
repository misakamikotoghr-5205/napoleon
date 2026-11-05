extends SceneTree
const R = preload("res://jev_rng.gd")
func _init():
	var cases = [
		[42, "wheel:climate", [1], 0.06858027750188644],
		[42, "wheel:logistics", [3], 0.16148672144953713],
		[19380306, "wheel:town_weather", [12], 0.2881390520385281],
		[19380306, "message_relay", ["event:7", "zhouma", "linsao", 1], 0.232507020285863],
		[19380306, "visit", [3, "xiaoding"], 0.9976656631889068],
		[19380306, "轮盘:米价", [5, "德厚当"], 0.953220035114062],
	]
	var ok := true
	for c in cases:
		var u: float = R.draw(c[0], c[1], c[2])
		var same: bool = u == float(c[3])
		ok = ok and same
		print(c[1], " ", c[2], " -> ", String.num(u, 17), " expected ", String.num(c[3], 17), " ", "OK" if same else "MISMATCH")
	var rd: float = R.replay_draw(42, "A", 0)
	print("replay_draw ", String.num(rd, 17), " ", rd == 0.6700750373336426)
	ok = ok and rd == 0.6700750373336426
	var wc: String = R.weighted_choice([["quiet", 8.0], ["clear", 3.0], ["rain", 2.0], ["gale", 0.5]], 0.9)
	print("weighted_choice ", wc)
	ok = ok and wc == "rain"
	print("ALL_OK" if ok else "FAIL")
	quit()
