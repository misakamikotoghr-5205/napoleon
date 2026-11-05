# 对白框点击规则的无界面单元测试：godot --headless -s res://scripts/tests/test_dialogue.gd
# 退出码：0 = 通过；1 = 失败。
extends SceneTree

const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")

var advanced_count: int = 0
var failures: int = 0

func _initialize() -> void:
	_run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _run() -> void:
	var box = DialogueBox.new()
	box.size = Vector2(1280, 180)
	box.custom_minimum_size = Vector2(1280, 180)
	root.add_child(box)
	box.advanced.connect(func(): advanced_count += 1)
	await process_frame

	var text := "一二三四五六七八九十甲乙丙丁戊己庚辛壬癸"  # 20 个字符
	box.show_line("测试", text, Color("#e8c88a"), false, true, 1.0)
	_check(box.is_typing() == true, "show_line starts typing")
	_check(box.full_plain_len == 20, "full_plain_len is 20 for a 20-char line (got %d)" % box.full_plain_len)

	# 连续两次立即点击：第一次补全本句，第二次因 180 ms 防抖不推进
	box.click()
	box.click()
	_check(advanced_count == 0, "two immediate clicks do not emit advanced")
	_check(box.is_typing() == false, "typing is false after first click")

	# 等待超过防抖时间后点击 → 推进
	# 用真实时间等（无界面模式下场景计时器可能比墙钟快）
	var t_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 260:
		await process_frame
	box.click()
	_check(advanced_count == 1, "click after 250 ms emits advanced once (got %d)" % advanced_count)

	# instant 模式：无防抖，立即推进
	advanced_count = 0
	box.instant = true
	box.show_line("测试", "短句", Color.WHITE, false, true, 1.0)
	_check(box.is_typing() == false, "instant show_line is not typing")
	box.click()
	_check(advanced_count == 1, "instant mode click advances immediately")

	box.queue_free()
	await process_frame
	print("RESULT: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)
