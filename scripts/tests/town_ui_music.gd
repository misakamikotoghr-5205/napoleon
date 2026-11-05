# 音乐挂钩：没有音乐导演脚本时静默；有（这里用替身）时按地点/时间/模式发 play / stinger / duck / set_volume_linear。
# godot --headless -s res://scripts/tests/town_ui_music.gd
extends SceneTree

const Common = preload("res://scripts/tests/town_ui_common.gd")
const MusicCues = preload("res://scripts/town/music_cues.gd")

# 替身：接口和 res://scripts/audio/music_director.gd 一致
class FakeDirector extends RefCounted:
	var calls: Array = []
	func play(track_id: String, fade_s: float) -> void:
		calls.append(["play", track_id, fade_s])
	func stinger(id: String) -> void:
		calls.append(["stinger", id])
	func stop(fade_s: float) -> void:
		calls.append(["stop", fade_s])
	func set_volume_linear(v: float) -> void:
		calls.append(["set_volume_linear", v])
	func duck(on: bool) -> void:
		calls.append(["duck", on])

var c

func _initialize() -> void:
	_run()

func _plays(fake) -> Array:
	var out: Array = []
	for row in fake.calls:
		if row[0] == "play":
			out.append(row[1])
	return out

func _has(fake, kind: String, arg) -> bool:
	for row in fake.calls:
		if row[0] == kind and (arg == null or row[1] == arg):
			return true
	return false

func _run() -> void:
	# 没有音乐导演脚本：什么都不做、不报错
	var bare = MusicCues.new(null)
	bare.cue("title")
	bare.stinger("sting_morning")
	bare.duck(true)
	bare.set_volume(0.5)
	bare.stop(1.0)
	c = Common.new(self)
	c.check(not FileAccess.file_exists("res://scripts/audio/music_director.gd") or bare.director == null, "没有宿主时不实例化音乐导演；没有脚本也不报错")
	await c.make_main()
	var main = c.main
	var town = c.town
	var fake := FakeDirector.new()
	main.music.director = fake
	main.music.record = true
	main.music.set_volume(0.4)
	c.check(_has(fake, "set_volume_linear", null) and abs(float(fake.calls[0][1]) - 0.4) < 0.001, "音乐音量 → set_volume_linear")
	main._show_title()
	c.check(_plays(fake) == ["title"], "标题画面 → title（%s）" % str(_plays(fake)))
	main.title_layer.queue_free()
	main.title_layer = null
	town.set_fast(false)
	town.auto_dismiss = true
	town.director_ready.connect(c._on_director)
	town.new_game(5, "常年", true)
	await town.day_started
	await c.until_idle()
	town.seconds_per_minute = 100000.0
	await c.until(func(): return _has(fake, "stinger", "sting_morning"), 300)
	c.check(_has(fake, "stinger", "sting_morning"), "晨间告示 → sting_morning")
	c.check(_plays(fake).back() == "pawnshop", "当铺内部 → pawnshop（%s）" % str(_plays(fake)))
	# 出门：白天
	town.skip_to(480)
	await town.goto("ricehall")
	c.check(_plays(fake).back() == "town_day", "小镇白天 → town_day（%s）" % str(_plays(fake)))
	# 茶馆特写 → teahouse；米行特写沿用
	await town.open_shop("teahouse")
	await c.until(func(): return town.shop_view.is_open, 120)
	c.check(_plays(fake).back() == "teahouse", "茶馆特写 → teahouse")
	town.shop_view.close_shop()
	await c.until_idle()
	await town.open_shop("ricehall")
	await c.until(func(): return town.shop_view.is_open, 120)
	var n_before: int = _plays(fake).size()
	c.check(_plays(fake).back() == "teahouse" and n_before == _plays(fake).size(), "米行特写：曲子不变")
	town.shop_view.close_shop()
	await c.until_idle()
	# 黄昏、夜
	town.skip_to(1100)
	c.check(_plays(fake).back() == "town_dusk", "18:00 后 → town_dusk（%s）" % str(_plays(fake)))
	town.skip_to(1265)
	c.check(_plays(fake).back() == "night", "21:00 后 → night（%s）" % str(_plays(fake)))
	# 柜台会话期间闪避音乐
	# 睡觉：夜里 → night，日结 → sting_day_end；第二天开门的店 → sting_unlock
	await town.goto("bed")
	town.sleep()
	await town.day_finished
	await town.day_started
	await c.until_idle()
	await c.until(func(): return _has(fake, "stinger", "sting_morning") and fake.calls.filter(func(r): return r[0] == "stinger" and r[1] == "sting_morning").size() >= 2, 300)
	c.check(_has(fake, "stinger", "sting_day_end"), "日结 → sting_day_end")
	c.check(_has(fake, "stinger", "sting_unlock") == not town.last_plan.get("unlocked_today", []).is_empty(), "有新开门的店才发 sting_unlock（今天 %s）" % str(town.last_plan.get("unlocked_today", [])))
	c.check(_plays(fake).has("night") and _plays(fake).back() == "pawnshop", "夜里 → night，醒来 → pawnshop")
	# 柜台生意里：duck(true)，办完 duck(false)
	town.skip_to(545)
	await c.until(func(): return not town.visitors.next_ready().is_empty(), 900)
	var started: int = town.counter_started
	var duck_on_seen := false
	await town.goto("counter")
	var guard := 0
	while town.counter_started == started and guard < 900:
		guard += 1
		await process_frame
	guard = 0
	while town.mode != "town" and guard < 900:
		guard += 1
		if main.music.ducked:
			duck_on_seen = true
		await process_frame
	await c.frames(4)
	c.check(_has(fake, "duck", true) or duck_on_seen, "柜台会话里 duck(true)")
	c.check(not main.music.ducked and fake.calls.filter(func(r): return r[0] == "duck").back()[1] == false, "办完 duck(false)")
	# 返回标题 → title 再响
	main._return_to_title()
	await c.frames(3)
	c.check(_plays(fake).back() == "title", "返回标题 → title")
	print("RESULT: ", "OK" if c.failures == 0 else "FAILED (%d)" % c.failures)
	var code: int = 0 if c.failures == 0 else 1
	main.music.director = null
	await c.shutdown()
	quit(code)
