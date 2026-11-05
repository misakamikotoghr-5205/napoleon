# C14 (DESIGN 13 test_mouse): a whole round with nothing but mouse events at screen coordinates. The "player"
# reads only the screen: weight faces, the needle's offset in its gate, the stars. It takes the weights off,
# hangs the ones under the claim, drags the poise, follows the needle with the nudge buttons, reads the stars,
# picks a call, hands back. A drag on the beam logs one poise op. Grey buttons do nothing. The host's
# "never mind" button, clicked, aborts; it covers none of the game's buttons.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Fix = preload("res://scripts/tests/cards/C14/weigh_fix.gd")
const R = preload("res://scripts/cards/minigames/weigh/weigh_rules.gd")

var fix


func _initialize() -> void:
	var t := T.new(self, "C14_mouse")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	fix = Fix.new()
	fix.setup_text()
	for name in ["light_small", "steelyard_rice"]:
		await _round(t, fix.params(name), name)
	var rice: Dictionary = fix.params("steelyard_rice")
	rice["weights_fen"] = [100, 200, 500, 1000, 2000, 2000]
	rice["resolution_fen"] = 10
	rice["claimed_fen"] = 7200
	rice["actual_fen"] = 8208
	rice["small_fen"] = 160
	await _round(t, rice, "rice_b2")
	await _enter_mid_drag(t)
	await _click_keeps_preview(t)
	await _host_abort(t)


func _round(t, pars: Dictionary, label: String) -> void:
	var game = fix.open(self, pars)
	await t.frames(2)
	game._beam.set("fast", true)
	var box := {"r": {}, "n": 0}
	game.finished.connect(func(r: Dictionary) -> void:
		box["r"] = r
		box["n"] = int(box["n"]) + 1
	)
	# Grey before the read: clicking a call does nothing.
	await fix.click(self, fix.center(game._call_btns[0]))
	t.eq(int(game._call), 0, label + " grey call ignored")
	# Weights: all off, then the biggest that stay under nine tenths of the claim.
	for i in game._weight_btns.size():
		if game._on[i]:
			await fix.click(self, fix.center(game._weight_btns[i]))
	t.ok(not (game._on as Array).has(true), label + " all weights off by mouse")
	var claimed := int(pars["claimed_fen"])
	var res := int(pars["resolution_fen"])
	var order: Array = range(game._weights.size())
	order.sort_custom(func(a, b) -> bool: return int(game._weights[a]) > int(game._weights[b]))
	var sum := 0
	for i in order:
		if sum + int(game._weights[i]) <= claimed * 9 / 10:
			sum += int(game._weights[i])
			await fix.click(self, fix.center(game._weight_btns[i]))
	# Drag the poise toward the claim: one release, one op.
	var n_ops: int = game.ops_log().size()
	var guess := clampi((claimed - sum) / res, 0, int(game._poise_max))
	var from: Vector2 = game._beam.global_point_for_step(int(game._poise_step))
	await fix.drag(self, from, game._beam.global_point_for_step(guess))
	var after: Array = game.ops_log()
	t.eq(after.size(), n_ops + 1, label + " one drag, one op")
	if after.size() == n_ops + 1:
		t.eq(str(after[after.size() - 1][0]), "poise", label + " the drag op is a poise op")
	t.ok(absi(int(game._poise_step) - guess) <= 1, label + " the poise landed where it was dropped (%d vs %d)" % [game._poise_step, guess])
	# Follow the needle: off to the pan side = goods heavier = poise out.
	var best := 999
	for _k in 400:
		var off := int(game._beam.needle_offset_px())
		if off == 0:
			break
		var prev_step := int(game._poise_step)
		if absi(off) >= 20:
			var to := clampi(prev_step + (10 if off < 0 else -10), 0, int(game._poise_max))
			await fix.drag(self, game._beam.global_point_for_step(prev_step), game._beam.global_point_for_step(to))
		else:
			var btn: Button = game._nudge_out if off < 0 else game._nudge_in
			if btn.disabled:
				break
			await fix.click(self, fix.center(btn))
			var off2 := int(game._beam.needle_offset_px())
			if signi(off2) != signi(off):
				if absi(off2) > absi(off):
					await fix.click(self, fix.center(game._nudge_in if off < 0 else game._nudge_out))
				break
		if int(game._poise_step) == prev_step:
			break
		best = mini(best, absi(int(game._beam.needle_offset_px())))
	t.ok(absi(int(game._beam.needle_offset_px())) <= 2, label + " needle centred by mouse (%d px)" % int(game._beam.needle_offset_px()))
	t.ok(bool(game._level()), label + " the beam is level")
	await fix.click(self, fix.center(game._commit_btn))
	t.ok(bool(game._committed) and game._zoom.visible, label + " commit by mouse opens the star close-up")
	for b in game._weight_btns:
		t.ok(b.disabled, label + " weights grey while reading")
	# The player reads: faces on the hook + stars under the cord, against the claim.
	var read := sum + int(game._poise_step) * res
	var small := int(pars.get("small_fen", claimed * 60 / 1000))
	var cat := "match"
	if absi(read - claimed) > res:
		cat = "heavy" if read > claimed else ("light_small" if claimed - read <= small else "light_much")
	await fix.click(self, fix.center(game._call_btns[Fix.CALLS.find(cat) - 1]))
	t.eq(int(game._call), Fix.CALLS.find(cat), label + " call picked by mouse")
	await fix.click(self, fix.center(game._done_btn))
	await t.frames(1)
	t.eq(int(box["n"]), 1, label + " handed back once")
	t.eq(box["r"].get("observations", []), ["obs.weigh." + cat], label + " the call is the observation")
	t.eq(int(box["r"].get("quality_permille", 0)), 1000, label + " level read is clear")
	t.eq(cat, fix.answer(pars), label + " reading the screen gives the true category")
	var ops: Array = game.ops_log()
	var kinds := {}
	for op in ops:
		kinds[str(op[0])] = true
	t.ok(kinds.has("weight") and kinds.has("poise") and kinds.has("commit") and kinds.has("call") and kinds.has("done"),
		label + " every op came from the mouse: " + str(kinds.keys()))
	game.queue_free()
	await t.frames(1)


func _button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.position = pos
	ev.global_position = pos
	root.push_input(ev, true)
	await process_frame


## Enter while the poise is still held: the poise is put down where the beam shows it, then the stars are read
## there (reading, frozen beam and close-up agree); the drag is over, and after "weigh again" the beam follows
## the keys and the nudge buttons again.
func _enter_mid_drag(t) -> void:
	var pars: Dictionary = fix.params("light_small")
	var game = fix.open(self, pars)
	await t.frames(2)
	game._beam.set("fast", true)
	var res := int(pars["resolution_fen"])
	var from_step := int(game._poise_step)
	var to_step := from_step + 12 if from_step + 12 <= int(game._poise_max) else from_step - 12
	var p0: Vector2 = game._beam.global_point_for_step(from_step)
	var p1: Vector2 = game._beam.global_point_for_step(to_step)
	await fix.move(self, p0)
	await _button(p0, true)
	for k in range(1, 6):
		await fix.move(self, p0.lerp(p1, float(k) / 5.0), MOUSE_BUTTON_MASK_LEFT)
	var shown := int(game._drag_step)
	t.ok(bool(game._drag) and shown != from_step, "mid-drag: the beam shows step %d, the poise op is not logged yet" % shown)
	t.eq(int(game._beam.poise_step), shown, "mid-drag: the beam draws the held poise")
	var n_ops: int = game.ops_log().size()
	await fix.tap(self, KEY_ENTER)
	t.ok(bool(game._committed), "Enter mid-drag reads the stars")
	t.ok(not bool(game._drag), "Enter ends the drag")
	t.eq(int(game._poise_step), shown, "the poise is put down where the beam showed it")
	t.eq(int(game._read_fen), int(game._indicated_at(shown)), "the reading is the shown step")
	t.eq(int(game._beam.poise_step), shown, "the frozen beam shows the read step")
	t.eq(int(game._zoom.poise_fen), shown * res, "the close-up shows the read step")
	var ops: Array = game.ops_log()
	t.eq(ops.slice(n_ops), [["poise", shown], ["commit"]], "one poise op, then the read")
	await _button(p1, false)
	await t.frames(1)
	t.eq(game.ops_log().size(), ops.size(), "the late release does nothing")
	game.apply_op(["again"])
	await t.frames(1)
	var key := KEY_RIGHT if int(game._poise_step) < int(game._poise_max) else KEY_LEFT
	await fix.tap(self, key)
	t.eq(int(game._beam.poise_step), int(game._poise_step), "after weigh-again the beam follows the arrow keys")
	var nudge: Button = game._nudge_in if int(game._poise_step) > 0 else game._nudge_out
	await fix.click(self, fix.center(nudge))
	t.eq(int(game._beam.poise_step), int(game._poise_step), "and the nudge buttons")
	t.eq(int(game._zoom.poise_fen), int(game._poise_step) * res, "the close-up keeps up too")
	game.queue_free()
	await t.frames(1)


## A click on a star (press and release, no motion) puts the poise on the step the press showed, although the
## beam swings under the mouse as soon as the poise moves (ten-liang bar, about 4 px a step).
func _click_keeps_preview(t) -> void:
	var pars: Dictionary = fix.params("light_small")
	pars["claimed_fen"] = 1005
	pars["actual_fen"] = 980
	pars["small_fen"] = 20
	pars["weights_fen"] = [10, 20, 20, 50, 100, 200, 500]
	var game = fix.open(self, pars)
	await t.frames(2)
	game._beam.set("fast", true)
	for i in game._weights.size():
		if bool(game._on[i]) != (i != 2):
			game.apply_op(["weight", i])
	game.apply_op(["poise", 0])
	await t.frames(1)
	var before := float(game._beam.tilt)
	var target := int(game._poise_max)
	var gp: Vector2 = game._beam.global_point_for_step(target) + Vector2(0, -8)
	var local: Vector2 = game._beam.get_global_transform().affine_inverse() * gp
	var preview := int(game._beam.step_at(local))
	await fix.click(self, gp)
	t.eq(int(game._poise_step), preview, "a click puts the poise on the star it showed (%d)" % preview)
	t.ok(signf(float(game._beam.tilt)) != signf(before), "the beam swung the other way (%.3f -> %.3f)" % [before, float(game._beam.tilt)])
	t.ok(int(game._beam.step_at(local)) != preview, "measured again on the swung beam the mouse is on another step")
	game.queue_free()
	await t.frames(1)


func _host_abort(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var host := CardMiniGameHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	host._on_requested("c0001", "I001", &"weigh", fix.params("match"))
	await t.frames(3)
	var mg = host.current
	var abort := host.get_node("Abort") as Button
	var r := abort.get_global_rect()
	for b in [mg._commit_btn, mg._again_btn, mg._done_btn, mg._nudge_in, mg._nudge_out]:
		t.ok(not (b as Control).get_global_rect().intersects(r), "abort clear of " + str(b.name))
	var box := {"r": {}}
	mg.finished.connect(func(res: Dictionary) -> void: box["r"] = res)
	await fix.click(self, r.get_center())
	await t.frames(2)
	t.eq(bool(box["r"].get("aborted", false)), true, "clicking never-mind aborts")
	t.ok(not host.is_active(), "the host closed the game")
	host.queue_free()
	bus.queue_free()
	await t.frames(2)
