# 打字机逐字音效 + 静音开关：godot --headless -s res://scripts/tests/test_typewriter.gd
# 静音开 / 关两种状态下各跑一遍：逐字推进与嘀嗒、标点停顿、点击/跳过/Instant 立即补全并清停顿。
# 退出码：0 = 通过；1 = 失败。
extends SceneTree

const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const Beeper = preload("res://scripts/ui/beeper.gd")
const MainUI = preload("res://scripts/ui/main.gd")

const LINE := "一二，三四。五六"   # 8 个字：第 3 字逗号、第 6 字句号
const STEP := 0.0234               # 略大于 1/45 秒：每步出一个字

var failures: int = 0
var advanced_count: int = 0
var skipped_count: int = 0

func _initialize() -> void:
	await _run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _run() -> void:
	_test_punct_level()
	for muted in [false, true]:
		await _test_box(muted)
	await _test_main_toggle()
	DB.shutdown()
	print("RESULT: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

func _test_punct_level() -> void:
	_check(Beeper.punct_level("甲") == 0, "plain char is not punctuation")
	_check(Beeper.punct_level("，") == 1 and Beeper.punct_level("、") == 1, "comma-like marks are mid pauses")
	_check(Beeper.punct_level("。") == 2 and Beeper.punct_level("？") == 2 and Beeper.punct_level("…") == 2, "sentence enders are full stops")
	var b = Beeper.new()
	_check(b.tick(" ") == false and b.ticks_sounded == 0, "whitespace does not tick")
	b.set_muted(true)
	_check(b.tick("甲") == false and b.ticks_sounded == 0, "muted beeper does not tick")
	b.set_muted(false)
	_check(b.tick("甲") == true and b.ticks_sounded == 1, "unmuted beeper ticks once per char")
	b.free()

func _new_box(beeper) -> Node:
	var box = DialogueBox.new()
	box.size = Vector2(420, 140)
	root.add_child(box)
	box.beeper = beeper
	box.set_process(false)   # 手动驱动 _process，结果与帧率无关
	advanced_count = 0
	skipped_count = 0
	box.advanced.connect(func(): advanced_count += 1)
	box.skipped.connect(func(): skipped_count += 1)
	return box

func _wait_guard() -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 260:
		await process_frame

func _test_box(muted: bool) -> void:
	var tag := "[muted=%s] " % str(muted)
	var beeper = Beeper.new()
	root.add_child(beeper)
	beeper.set_muted(muted)
	var box = _new_box(beeper)
	await process_frame

	# —— 逐字：每步出一个字、嘀一声（静音时不响）；逗号后停顿
	box.show_line("测试", LINE, Color.WHITE, false, true, 1.0)
	_check(box.is_typing(), tag + "show_line starts typing")
	_check(box.plain_text == LINE, tag + "plain text kept for per-char lookup")
	box._process(STEP)
	_check(box.text_lbl.visible_characters == 1, tag + "one char after one step (got %d)" % box.text_lbl.visible_characters)
	_check(beeper.ticks_sounded == (0 if muted else 1), tag + "first char ticks iff unmuted (got %d)" % beeper.ticks_sounded)
	box._process(STEP)
	box._process(STEP)
	_check(box.text_lbl.visible_characters == 3, tag + "comma shown after three steps")
	_check(box._pause_left > 0.0, tag + "pause armed after comma")
	box._process(0.03)
	_check(box.text_lbl.visible_characters == 3, tag + "still paused after comma")
	box._process(0.06)   # 停顿 0.06 用完，余下 0.03 秒接着打
	_check(box.text_lbl.visible_characters == 4, tag + "typing resumes after comma pause (got %d)" % box.text_lbl.visible_characters)
	# 一大步也不会越过句号：停在句号后
	box._process(1.0)
	_check(box.text_lbl.visible_characters == 6, tag + "big step stops at the full stop (got %d)" % box.text_lbl.visible_characters)
	_check(box._pause_left >= 0.1, tag + "full stop pauses longer than comma")
	# 一帧跳多个字只响一声（不叠音）：前 4 步各 1 声 + 这一大步 1 声
	_check(beeper.ticks_sounded == (0 if muted else 5), tag + "one tick per advance, big jump ticks once (got %d)" % beeper.ticks_sounded)
	_check(box.is_typing(), tag + "still typing during pause")

	# —— 停顿中点击：立即补全整句、清空停顿、不推进；过防抖再点才推进
	box.click()
	_check(not box.is_typing(), tag + "click during pause finishes the line")
	_check(box._pause_left == 0.0, tag + "click clears pending pause")
	_check(box.text_lbl.visible_characters == -1, tag + "click shows full line")
	_check(advanced_count == 0, tag + "first click does not advance")
	var ticks_before: int = beeper.ticks_sounded
	box._process(1.0)
	_check(beeper.ticks_sounded == ticks_before, tag + "no ticks after line completed")
	await _wait_guard()
	box.click()
	_check(advanced_count == 1, tag + "click after guard advances")

	# —— 停顿中「跳过」/ Esc：一步补全并推进
	box.show_line("测试", LINE, Color.WHITE, false, true, 1.0)
	box._process(3 * STEP)
	_check(box._pause_left > 0.0, tag + "paused before skip")
	box.skip()
	_check(not box.is_typing() and box._pause_left == 0.0, tag + "skip finishes and clears pause")
	_check(advanced_count == 2 and skipped_count == 1, tag + "skip advances immediately")

	# —— finish_typing（界面“点空白处”路径）同样清停顿
	box.show_line("测试", LINE, Color.WHITE, false, true, 1.0)
	box._process(3 * STEP)
	box.finish_typing()
	_check(not box.is_typing() and box._pause_left == 0.0 and box.text_lbl.visible_characters == -1, tag + "finish_typing clears pause")
	box.skip()
	_check(advanced_count == 3, tag + "skip after finish_typing advances")

	# —— 自然打完：总时长 = 字数/速度 + 两次停顿，最后一个字也会响
	beeper.ticks_sounded = 0
	box.show_line("测试", LINE, Color.WHITE, false, true, 1.0)
	var elapsed := 0.0
	while box.is_typing() and elapsed < 2.0:
		box._process(STEP)
		elapsed += STEP
	_check(not box.is_typing(), tag + "line finishes on its own")
	_check(elapsed < 8.0 / box.cps + box.PAUSE_STOP + box.PAUSE_MID + 3 * STEP, tag + "punctuation adds only short pauses (%.3f s)" % elapsed)
	_check(beeper.ticks_sounded == (0 if muted else 8), tag + "every char ticked once incl. last (got %d)" % beeper.ticks_sounded)

	# —— 设置里的“瞬间”文字速度：第一帧就出全句，不在标点上停
	var cps_before: float = box.cps
	box.cps = 100000.0
	box.show_line("测试", LINE, Color.WHITE, false, true, 1.0)
	box._process(STEP)
	_check(not box.is_typing() and box.text_lbl.visible_characters == -1 and box._pause_left == 0.0, tag + "instant text speed finishes in one frame")
	box.cps = cps_before

	# —— Instant：不打字、不响、点一下就推进
	beeper.ticks_sounded = 0
	box.instant = true
	box.show_line("测试", LINE, Color.WHITE, false, true, 1.0)
	_check(not box.is_typing() and box._pause_left == 0.0, tag + "instant shows whole line without pause")
	box._process(STEP)
	box.click()
	_check(advanced_count == 4, tag + "instant click advances immediately")
	_check(beeper.ticks_sounded == 0, tag + "instant mode does not tick")

	box.queue_free()
	beeper.queue_free()
	await process_frame

func _test_main_toggle() -> void:
	var main = MainUI.new()
	main.autostart = false
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main.beeper != null and main.dialogue.beeper == main.beeper, "dialogue uses main beeper")
	_check(main.beeper.muted == false, "sound is on by default")
	_check(main.mute_btn != null and main.mute_btn.visible, "mute button visible")
	_check(main.mute_btn.text.contains("开"), "mute button shows on (got %s)" % main.mute_btn.text)
	main.mute_btn.emit_signal("pressed")
	_check(main.beeper.muted == true, "button mutes beeper")
	_check(main.mute_btn.text.contains("关"), "mute button shows off")
	var ev := InputEventKey.new()
	ev.keycode = KEY_M
	ev.pressed = true
	main._unhandled_input(ev)
	_check(main.beeper.muted == false, "M key unmutes beeper")
	main._unhandled_input(ev)
	_check(main.beeper.muted == true, "M key mutes again")
	_check(main.beeper.tick("甲") == false, "muted main beeper stays silent")
	main.queue_free()
	await process_frame
