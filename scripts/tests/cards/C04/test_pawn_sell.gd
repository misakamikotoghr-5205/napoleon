# C04: pawn and sell. open -> look -> fair offer -> accept a counter.
# Five counter rounds end on leave with only the send-off reply.
# autoplay_step walks each fixture to a false return. Same path the player uses.
# 1.3: the card game root plays the card; choices are dialog replies.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C04/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C04_pawn_sell")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in ["pawn", "sell", "counter_then_leave", "five_rounds", "after_look"]:
		t.no_leaks(S.read(name), name)
	await _buttons(t, "pawn", "c0002", "I001", "p.linsao.1938.pawn_hairpin", "ticket")
	await _buttons(t, "sell", "c0003", "I002", "p.stranger_peddler.any.sell_bowl", "shelved")
	await _five(t)
	await _decline(t)
	await _autos(t)
	await _keys(t)
	await _enter(t)
	await _esc(t)
	await _timing(t)


func _buttons(t, fx: String, uid: String, item: String, def_id: String, result_kind: String) -> void:
	var ctx: Dictionary = S.boot(self, fx)
	await t.frames(1)
	var panel := S.play(ctx, uid)
	var mock: MockCardEngine = ctx.mock
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.counter.look"), fx + " look anchor")
	t.ok(t.anchor_ok(&"a.counter.tier.fair"), fx + " fair anchor")
	t.ok(t.anchor_ok(&"a.counter.tier.harsh"), fx + " harsh anchor")
	t.ok(t.anchor_ok(&"a.counter.tier.kind"), fx + " kind anchor")
	t.ok(t.anchor_ok(&"a.counter.item"), fx + " item anchor")
	t.ok(t.anchor_ok(&"a.counter.reply"), fx + " reply anchor")
	t.ok(not CardAnchors.has(&"a.counter.stock"), fx + " stock anchor hidden")
	t.ok(not CardAnchors.has(&"a.counter.redeem"), fx + " redeem anchor hidden")
	_line_ok(t, S.label(panel, "ReplyLine"), def_id, fx + " opening line")
	S.button(panel, "LookButton").pressed.emit()
	await t.frames(1)
	S.button(panel, "TierFair").pressed.emit()
	await t.frames(1)
	_eq_ref(t, S.label(panel, "ReplyLine"), def_id + "#lines.counter", fx + " counter line")
	# Reskin 10-23: the counter price is no longer a loose digit on the scene (NumPrice); it shows in
	# the dialog's item row ("他还价 N 蚨") under the guest's line.
	var price := int((panel.get("_cv") as Dictionary).get("last_price", 0))
	t.ok(price != 0 and _dialog_shows(panel, str(price)), fx + " counter price shown in the dialog")
	S.button(panel, "AcceptButton").pressed.emit()
	await t.frames(1)
	_eq_ref(t, S.label(panel, "ReplyLine"), def_id + "#lines.accept", fx + " accept line")
	# Reskin 10-23: the result is the gold lead line above the replies, no longer a label on the scene.
	_eq_ref(t, S.label(panel, "LeadLine"), "c04.result." + result_kind, fx + " result")
	t.ok(not _scene_text(panel), fx + " counter writes nothing onto the scene")
	var want: Array = [
		["counter.open", {"uid": uid}],
		["mg.request", {"uid": uid, "item": item}],
		["counter.offer", {"uid": uid, "tier": "fair"}],
		["counter.answer", {"uid": uid, "accept": true}],
	]
	t.eq(S.cmds(mock), want, fx + " command order")
	mock = null
	await _drop(t, ctx)


func _five(t) -> void:
	var ctx: Dictionary = S.boot(self, "five_rounds")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	await t.frames(2)
	for i in 5:
		var fair := S.button(panel, "TierFair")
		t.ok(fair != null, "fair button before round %d" % (i + 1))
		if fair == null:
			break
		fair.pressed.emit()
		await t.frames(1)
	_leave_line(t, S.label(panel, "ReplyLine"), "p.linsao.1938.pawn_hairpin")
	t.eq(_button_names(panel), ["SendOffButton"], "after leave only send-off remains")
	var dlg = panel.get("dialog")
	t.ok(dlg != null and is_instance_valid(dlg), "five: panel.dialog bound")
	var send := _unique_send_off(panel)
	t.ok(send != null, "five: unique visible SendOffButton on dialog")
	t.ok(send != null and send.is_visible_in_tree() and not send.disabled, "five: send-off enabled in tree")
	if send != null:
		# Click the real dialog button (production path via reply_chosen → on_reply).
		send.pressed.emit()
		await t.frames(3)
		t.ok(not is_instance_valid(panel) or ctx.game.host.top_panel() != panel, "five: send-off closes counter panel")
	var offers := 0
	for row in S.cmds(ctx.mock):
		if row[0] == "counter.offer" and str(row[1].get("tier", "")) == "fair":
			offers += 1
	t.eq(offers, 5, "five fair offers")
	await _drop(t, ctx)


func _decline(t) -> void:
	var ctx: Dictionary = S.boot(self, "counter_then_leave")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	await t.frames(2)
	S.button(panel, "TierFair").pressed.emit()
	await t.frames(1)
	S.button(panel, "DeclineButton").pressed.emit()
	await t.frames(1)
	t.eq(_button_names(panel), ["SendOffButton"], "decline: only send-off")
	var dlg2 = panel.get("dialog")
	t.ok(dlg2 != null and is_instance_valid(dlg2), "decline: panel.dialog bound")
	var send2 := _unique_send_off(panel)
	t.ok(send2 != null and send2.is_visible_in_tree() and not send2.disabled, "decline: unique enabled SendOffButton")
	if send2 != null:
		send2.pressed.emit()
		await t.frames(3)
		t.ok(not is_instance_valid(panel) or ctx.game.host.top_panel() != panel, "decline: send-off closes panel")
	var answer: Array = S.cmds(ctx.mock).filter(func(r: Array) -> bool: return r[0] == "counter.answer")
	t.eq(answer, [["counter.answer", {"uid": "c0002", "accept": false}]], "decline sends accept false")
	await _drop(t, ctx)


func _autos(t) -> void:
	await _auto(t, "pawn", "c0002", "I001")
	await _auto(t, "sell", "c0003", "I002")
	await _auto(t, "counter_then_leave", "c0002", "I001")
	var ctx: Dictionary = S.boot(self, "five_rounds")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	await t.frames(1)
	t.ok(await _until_stop(t, panel), "five_rounds autoplay stops")
	await _drop(t, ctx)
	var seen: Dictionary = S.boot(self, "after_look")
	await t.frames(1)
	var p2 := S.play(seen, "c0021")
	await t.frames(1)
	t.ok(await _until_stop(t, p2), "after_look autoplay stops")
	var names: Array = S.cmds(seen.mock).map(func(r: Array) -> String: return str(r[0]))
	t.ok(not names.has("mg.request"), "after_look does not look again")
	t.ok(names.has("counter.offer"), "after_look still offers")
	await _drop(t, seen)


func _auto(t, fx: String, uid: String, item: String) -> void:
	var ctx: Dictionary = S.boot(self, fx)
	await t.frames(1)
	var panel := S.play(ctx, uid)
	await t.frames(1)
	t.ok(await _until_stop(t, panel), fx + " autoplay stops")
	var want: Array = [
		["counter.open", {"uid": uid}],
		["mg.request", {"uid": uid, "item": item}],
		["counter.offer", {"uid": uid, "tier": "fair"}],
		["counter.answer", {"uid": uid, "accept": true}],
	]
	t.eq(S.cmds(ctx.mock), want, fx + " autoplay commands")
	await _drop(t, ctx)


func _keys(t) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	await t.frames(2)
	# Before a look: 1 look, 2 harsh, 3 fair, 4 kind.
	# After the look reply goes away, fair is the second reply.
	_key(panel, KEY_1)
	await t.frames(1)
	_key(panel, KEY_2)
	await t.frames(1)
	var want: Array = [
		["counter.open", {"uid": "c0002"}],
		["mg.request", {"uid": "c0002", "item": "I001"}],
		["counter.offer", {"uid": "c0002", "tier": "fair"}],
	]
	t.eq(S.cmds(ctx.mock), want, "keys 1 look, then 2 fair")
	await _drop(t, ctx)
	for tier in [["2", KEY_2, "harsh"], ["4", KEY_4, "kind"]]:
		var c2: Dictionary = S.boot(self, "pawn")
		await t.frames(1)
		var p2 := S.play(c2, "c0002")
		await t.frames(2)
		_key(p2, int(tier[1]))
		await t.frames(1)
		var hit: Array = S.cmds(c2.mock).filter(func(r: Array) -> bool: return r[0] == "counter.offer")
		t.eq(hit, [["counter.offer", {"uid": "c0002", "tier": tier[2]}]], "key %s offers %s" % [tier[0], tier[2]])
		await _drop(t, c2)


# b15: Enter with the dialog idle offers the fair price, then takes his counter, then sees him off.
# The root's _on_key calls confirm_key(); the panel's own _unhandled_input goes the same way.
func _enter(t) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	await t.frames(2)
	t.ok(panel.confirm_key(), "enter: first press acts")
	await t.frames(1)
	_key(panel, KEY_ENTER)
	await t.frames(1)
	var want: Array = [
		["counter.open", {"uid": "c0002"}],
		["counter.offer", {"uid": "c0002", "tier": "fair"}],
		["counter.answer", {"uid": "c0002", "accept": true}],
	]
	t.eq(S.cmds(ctx.mock), want, "enter offers fair, then accepts the counter")
	t.ok(panel.confirm_key(), "enter: third press sees the guest off")
	await t.frames(3)
	t.ok(not is_instance_valid(panel) or ctx.game.host.top_panel() != panel, "enter: send-off closes the counter")
	await _drop(t, ctx)


func _dialog_shows(panel: Node, needle: String) -> bool:
	var dlg = panel.get("dialog")
	if dlg == null or not is_instance_valid(dlg):
		return false
	for n in _walk(dlg):
		if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text.contains(needle):
			return true
	return false


## True when the counter panel itself (not its dialog/stage widgets) shows any text.
func _scene_text(panel: Node) -> bool:
	var dlg = panel.get("dialog")
	for n in _walk(panel):
		if dlg != null and is_instance_valid(dlg) and (n == dlg or (dlg as Node).is_ancestor_of(n)):
			continue
		if n is Label and (n as Label).is_visible_in_tree() and (n as Label).text != "":
			return true
	return false


func _esc(t) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	var panel := S.play(ctx, "c0002")
	await t.frames(1)
	var game = ctx.game
	game.host.close_top()
	await t.frames(1)
	var sent: Array = S.cmds(ctx.mock)
	t.ok(not sent.is_empty(), "esc sent a command")
	if not sent.is_empty():
		t.eq(sent[sent.size() - 1], ["counter.close", {"uid": "c0002"}], "esc closes the counter")
	t.ok(game.host.top_panel() == null, "panel is closed")
	var card: Dictionary = ctx.mock.query(&"card", {"uid": "c0002"})
	t.eq(str(card.get("zone", "")), "hand", "card stays in hand")
	await _drop(t, ctx)


func _timing(t) -> void:
	var ctx: Dictionary = S.boot(self, "pawn")
	await t.frames(1)
	var t0 := Time.get_ticks_usec()
	var panel := S.play(ctx, "c0002")
	var open_samples: Array = [Time.get_ticks_usec() - t0]
	for _i in 2:
		t0 = Time.get_ticks_usec()
		panel.open({"uid": "c0002"})
		open_samples.append(Time.get_ticks_usec() - t0)
	open_samples.sort()
	var open_us: int = int(open_samples[open_samples.size() / 2])
	await t.frames(1)
	var rebuild_samples: Array = []
	for _i in 3:
		t0 = Time.get_ticks_usec()
		panel._render()
		rebuild_samples.append(Time.get_ticks_usec() - t0)
	rebuild_samples.sort()
	var rebuild_us: int = int(rebuild_samples[rebuild_samples.size() / 2])
	print("C04 open_us %d rebuild_us %d" % [open_us, rebuild_us])
	# Box headless open/rebuild ~1.2s after DemandPanel preload; budget matches C08-style warm slack.
	t.ok(open_us < 2000000, "open() %d us" % open_us)
	t.ok(rebuild_us < 2000000, "rebuild %d us" % rebuild_us)
	await _drop(t, ctx)


func _until_stop(t, panel: CardCounterPanel) -> bool:
	for i in 8:
		var more: bool = panel.autoplay_step()
		await t.frames(1)
		if not more:
			return true
	return false


func _eq_ref(t, lab: Label, ref: String, msg: String) -> void:
	t.ok(lab != null, msg + " label")
	if lab == null:
		return
	t.eq(str(lab.get_meta("text_ref", "")), ref, msg + " key")
	t.eq(lab.text, CardText.t(ref), msg + " text")


func _line_ok(t, lab: Label, def_id: String, msg: String) -> void:
	t.ok(lab != null, msg + " label")
	if lab == null:
		return
	var ref := str(lab.get_meta("text_ref", ""))
	var ok := ref == def_id + "#lines.greet" or ref == def_id + "#body" or ref == def_id + "#lines.ask"
	t.ok(ok, msg + " key " + ref)
	t.eq(lab.text, CardText.t(ref), msg + " text")


func _leave_line(t, lab: Label, def_id: String) -> void:
	t.ok(lab != null, "leave label")
	if lab == null:
		return
	var ref := str(lab.get_meta("text_ref", ""))
	var ok := ref == def_id + "#lines.leave" or ref == "w0.stage.leave"
	t.ok(ok, "fifth round leaves (" + ref + ")")


func _button_names(panel: Node) -> Array:
	# Shared root dialog (C01 1.3) is not a child of the play panel; walk bound dialog by node identity.
	var names: Array = []
	var seen: Dictionary = {}
	var roots: Array = [panel]
	var dlg = panel.get("dialog")
	if dlg != null and is_instance_valid(dlg):
		roots.append(dlg)
	for root in roots:
		for n in _walk(root):
			if seen.has(n):
				continue
			seen[n] = true
			if n is Button and (n as Button).is_visible_in_tree() and str(n.name) != "SkipButton":
				var nm := str(n.name)
				if nm not in names:
					names.append(nm)
	names.sort()
	return names


func _unique_send_off(panel: Node) -> Button:
	var dlg = panel.get("dialog")
	var candidates: Array = []
	var roots: Array = [panel]
	if dlg != null and is_instance_valid(dlg):
		roots.append(dlg)
	var seen: Dictionary = {}
	for root in roots:
		for n in _walk(root):
			if seen.has(n):
				continue
			seen[n] = true
			if n is Button and str(n.name) == "SendOffButton" and (n as Button).is_visible_in_tree() and not (n as Button).disabled:
				candidates.append(n)
	if candidates.size() == 1:
		return candidates[0] as Button
	return null


func _key(panel: CardCounterPanel, code: int) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code as Key
	panel._unhandled_input(ev)


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func _drop(t, ctx: Dictionary) -> void:
	S.free_ctx(ctx)
	await t.frames(2)
