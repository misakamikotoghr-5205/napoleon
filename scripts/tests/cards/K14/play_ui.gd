# K14 headless UI walk (suite). Loads CardGame.tscn and drives autoplay_step().
# Args after --: --engine=mock|real --seed=<n> --days=<n> --guide=on|off --shots=<dir> --name=<suite name>
#   --chaos: each step draws JevRng c.qa.chaos and either autoplays, clicks the close-day button,
#   clicks the confirm panel's close / back buttons, or presses Esc on the top panel / minigame.
# W1 default is mock, 30 days, guide off. --engine=real does not pretend a campaign finished while the
# day loop is still a stub (see docs/cards/qa/findings.md). Screenshots only when --shots is set and
# the display server is not headless. No fake PNGs.
# Contract: docs/cards/CARDS_INTERFACES.md section 3.4 K14, section 7.4.7, section 7.8, section 7.11, section 12.1.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const U = preload("res://scripts/tests/cards/K14/qa_util.gd")

# Tabs from contract section 7.11.2. Absent until C01's stage root lands; chaos skips them.
const TAB_IDS: PackedStringArray = [
	"a.tab.contacts", "a.tab.demands", "a.tab.dossier", "a.tab.rules",
	"a.tab.shelf", "a.tab.tickets", "a.tab.estates", "a.tab.settings",
]
const AWAY_LIMIT := 6
const RECOVER_CAP := 8

var _shot_n := 0
var _shot_seen := {}
var _shot_dead := false
var _noted := {}
var _chaos_counts := {}
var _close_btn_missing := false
var _save_dir := ""


func _initialize() -> void:
	var t := T.new(self, U.arg("name", "K14_play_ui"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var mode := U.arg("engine", "mock")
	var seed := U.arg_int("seed", 7)
	var guide := U.arg("guide", "off")
	var shots := U.arg("shots", "")
	var chaos := U.flag("chaos")
	var days := U.arg_int("days", 90 if mode == "real" else 30)
	if mode != "mock" and mode != "real":
		t.ok(false, "engine must be mock or real")
		return
	# Saves go under this test's own user:// dir, never the player's user://cards (contract 12.1).
	_save_dir = t.user_dir()
	var bus := CardEventBus.new()
	root.add_child(bus)
	await t.frames(1)
	if mode == "real":
		var blocked: bool = await _real_blocked(t, seed)
		if blocked:
			bus.queue_free()
			await t.frames(1)
			return
	var spy = t.spy(bus)
	var game := _boot(bus, {"seed": seed, "skip_title": true, "guide": guide})
	var guide_on := guide == "on"
	game.guide.skip_fades = true
	game.guide.force(guide_on)
	await t.frames(2)
	if chaos:
		_chaos_preface(game)
	var report: Dictionary = await _walk(t, game, days, guide_on, shots, chaos, seed)
	await t.frames(2)
	_assert_walk(t, game, spy, report, days, mode, chaos)
	if shots != "" and not _shot_dead:
		game.queue_free()
		CardAnchors.clear()
		await t.frames(2)
		await _fixture_shots(bus, shots)
	else:
		game.queue_free()
	bus.queue_free()
	await t.frames(2)


## Honest W2 gate. Returns true when the caller must not walk a mock table and call it a real campaign.
func _real_blocked(t, seed: int) -> bool:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var probe := CardEngine.new(bus)
	var r: Dictionary = probe.new_game({"seed": seed, "only_examples": true, "save_dir": t.user_dir()})
	t.ok(bool(r.get("ok", false)), "real new_game ok")
	t.eq(str(probe.view().get("phase", "")), "month_open", "real new_game phase")
	t.no_leaks(probe.view(), "real boot view")
	var month_err := str(probe.send(&"month.begin", {}).get("err", ""))
	var day_err := str(probe.send(&"day.begin", {}).get("err", ""))
	var game := _boot(bus, {"seed": seed, "skip_title": true, "guide": "off"})
	await t.frames(2)
	var root_real := game.engine is CardEngine
	var loop_stub := month_err == "not_implemented" or day_err == "not_implemented"
	var blocked := loop_stub or not root_real
	if blocked:
		if loop_stub:
			t.eq(month_err, "not_implemented", "month.begin returns not_implemented")
			t.eq(day_err, "not_implemented", "day.begin returns not_implemented")
		else:
			t.ok(true, "day loop commands are no longer not_implemented")
		if root_real:
			t.ok(loop_stub, "CardEngine is on the table but the day loop is still a stub")
		else:
			t.ok(game.engine is MockCardEngine, "CardGameRoot.engine is MockCardEngine")
		print("NOTE: W2 blocked pending X01: real day loop and/or CardGameRoot still stub; campaign walk not executed")
	game.queue_free()
	bus.queue_free()
	await t.frames(1)
	return blocked


func _boot(bus: CardEventBus, opts: Dictionary) -> CardGameRoot:
	var game: CardGameRoot = load(CardIds.ROOT_SCENE).instantiate()
	var o := opts.duplicate()
	o["bus"] = bus
	o["mock"] = opts.has("fixture") or U.arg("engine", "mock") == "mock"
	o["save_dir"] = _save_dir if _save_dir != "" else CardSave.root()
	game.boot(o)
	root.add_child(game)
	return game


func _walk(t, game: CardGameRoot, days: int, guide_on: bool, shots: String, chaos: bool, seed: int) -> Dictionary:
	var phases: Array = []
	var panels := {}
	var mgs := {}
	var issues := PackedStringArray()
	var steps := 0
	var idle := 0
	var stopped := false
	var meta := {
		"saw_table": false, "left": false, "came_back": 0, "bounces": 0,
		"unclosable": "", "day0": -1, "day_back": false, "max_away": 0,
	}
	var away := 0
	var was_table := false
	while steps < U.STEP_CAP:
		var v := _observe(game, phases, panels, mgs)
		_track_day(meta, v)
		var at_table := _at_table(game)
		if at_table:
			meta["saw_table"] = true
			if was_table == false and bool(meta["left"]):
				meta["came_back"] = int(meta["came_back"]) + 1
			was_table = true
			away = 0
		else:
			meta["left"] = true
			was_table = false
			away += 1
			meta["max_away"] = maxi(int(meta["max_away"]), away)
		_check_view(t, game, issues)
		if shots != "":
			await _shot_current(game, shots, v)
		if U.reached(v, panels, days):
			stopped = true
			break
		if chaos and away > AWAY_LIMIT:
			var back: bool = await _recover(t, game, meta)
			steps += 1
			if not back:
				var top := str(game.host.top_kind()) if game.host != null else ""
				meta["unclosable"] = "phase=%s top=%s" % [str(game.engine.view().get("phase", "")), top]
				break
			away = 0
			was_table = true
			meta["saw_table"] = true
			meta["came_back"] = int(meta["came_back"]) + 1
			continue
		var before := _fp(game)
		if chaos:
			await _chaos_act(t, game, seed, steps, guide_on, meta)
		else:
			game.autoplay_step()
			await t.frames(1)
			if guide_on:
				game.guide.tick(0.5)
				game.guide.evaluate_now()
		if _fp(game) == before:
			idle += 1
		else:
			idle = 0
		steps += 1
		if idle >= U.STUCK_LIMIT:
			var top2 := str(game.host.top_kind()) if game.host != null else ""
			t.ok(false, "stuck %d steps at phase=%s stage_day=%s top=%s" % [
				idle, str(game.engine.view().get("phase", "")),
				str(game.engine.view().get("date", {}).get("stage_day", 0)), top2])
			break
	var vend := _observe(game, phases, panels, mgs)
	_track_day(meta, vend)
	_check_view(t, game, issues)
	if not stopped and steps >= U.STEP_CAP:
		t.ok(false, "step cap %d at phase=%s" % [U.STEP_CAP, str(vend.get("phase", ""))])
	return {
		"phases": phases, "panels": panels, "mgs": mgs, "issues": issues,
		"steps": steps, "view": vend, "chaos": meta,
	}


func _observe(game: CardGameRoot, phases: Array, panels: Dictionary, mgs: Dictionary) -> Dictionary:
	var v := game.engine.view()
	var phase := str(v.get("phase", ""))
	if phase != "" and (phases.is_empty() or phases[phases.size() - 1] != phase):
		phases.append(phase)
	if game.host != null and game.host.top_panel() != null:
		panels[str(game.host.top_kind())] = true
	if game.mg_host != null and game.mg_host.is_active() and game.mg_host.current != null:
		mgs[str(game.mg_host.current.kind())] = true
	return v


func _check_view(t, game: CardGameRoot, issues: PackedStringArray) -> void:
	for k in CardViewModel.leaks(game.engine.view()):
		_add(issues, "view leak: " + str(k))
	var pct := U.percent_in(game)
	if not pct.is_empty():
		_add(issues, "percent in visible text: " + U.ascii_snip(pct[0]))
	var foreign := U.foreign_text(t, game)
	if not foreign.is_empty():
		_add(issues, "text not from CardText: " + U.ascii_snip(foreign[0]))


func _add(issues: PackedStringArray, msg: String) -> void:
	if issues.size() < 8 and not issues.has(msg):
		issues.append(msg)


func _assert_walk(t, game: CardGameRoot, spy, report: Dictionary, days: int, mode: String, chaos: bool) -> void:
	var panels: Dictionary = report["panels"]
	for ev in spy.ui_events():
		if ev[0] == &"panel_opened":
			panels[str(ev[1].get("kind", ""))] = true
	var v: Dictionary = report["view"]
	var issues: PackedStringArray = report["issues"]
	if issues.is_empty():
		t.ok(true, "no leaks, percent signs, or foreign text")
	else:
		for msg in issues:
			t.ok(false, msg)
	var names: Array = []
	for n in spy.names():
		if n != &"ui_event":
			names.append(n)
	var tails := U.command_problems(names)
	if tails.is_empty():
		t.ok(true, "commands end with command_done, view_changed")
	else:
		for msg in tails:
			t.ok(false, msg)
	t.ok(U.reached(v, panels, days), "walk reached days=%d phase=%s abs=%s" % [
		days, str(v.get("phase", "")), str(v.get("date", {}).get("abs_day", 0))])
	if mode == "mock" and days >= 30 and not chaos:
		for k in ["counter", "slots", "night", "settle", "month_close"]:
			t.ok(panels.has(k), "opened panel " + k)
	_note_shows(spy)
	if chaos:
		_assert_chaos(t, report)
	var phase_s := ",".join(PackedStringArray(report["phases"]))
	print("K14 COVERAGE phases=%s panels=%s minigames=%s steps=%d" % [
		phase_s, U.sorted_keys(panels), U.sorted_keys(report["mgs"]), int(report["steps"])])


func _track_day(meta: Dictionary, v: Dictionary) -> void:
	var ad := int(v.get("date", {}).get("abs_day", 0))
	if int(meta["day0"]) < 0:
		meta["day0"] = ad
	elif ad < int(meta.get("last_day", ad)):
		meta["day_back"] = true
	meta["last_day"] = ad


func _at_table(game: CardGameRoot) -> bool:
	var panel_up := game.host != null and game.host.top_panel() != null
	var mg_up := game.mg_host != null and game.mg_host.is_active()
	return not panel_up and not mg_up


func _fp(game: CardGameRoot) -> String:
	return "%s|%d" % [U.fingerprint(game), _panel_depth(game)]


func _panel_depth(game: CardGameRoot) -> int:
	if game.host == null:
		return 0
	var n := 0
	for c in game.host.get_children():
		if c is CardPanel and not (c as Node).is_queued_for_deletion():
			n += 1
	return n


func _bump(name: String) -> void:
	_chaos_counts[name] = int(_chaos_counts.get(name, 0)) + 1


func _note_once(key: String, msg: String) -> void:
	if _noted.has(key):
		return
	_noted[key] = true
	print(msg)


func _chaos_preface(game: CardGameRoot) -> void:
	var dlg = game.get("dialog")
	if dlg == null or not (dlg as Object).has_method("skip"):
		print("NOTE: dialog not covered; chaos skip not run")
	else:
		_noted["dialog"] = true
	if not _tabs_present():
		print("NOTE: tabs not covered; chaos drawer not run")
	else:
		_noted["tabs"] = true
	if _close_day_button(game) == null:
		_close_btn_missing = true
		print("NOTE: close-day button node not mounted; chaos uses day.end")


func _tabs_present() -> bool:
	for id in TAB_IDS:
		if CardAnchors.has(StringName(id)):
			return true
	return false


func _chaos_act(t, game: CardGameRoot, seed: int, step: int, guide_on: bool, meta: Dictionary) -> void:
	var actions := _chaos_actions(game)
	var u := JevRng.draw(seed, "c.qa.chaos", ["act", step])
	var idx := int(u * float(actions.size()))
	if idx >= actions.size():
		idx = actions.size() - 1
	var name := str(actions[idx])
	_bump(name)
	match name:
		"autoplay":
			if game.host != null and game.host.top_kind() == &"end_day":
				_bump("autoplay_end_day")
			game.autoplay_step()
			await t.frames(1)
			if guide_on:
				game.guide.tick(0.5)
				game.guide.evaluate_now()
		"close_day", "day_end":
			_press_close_day(game)
			await t.frames(2)
		"confirm_close":
			_press_confirm(game, true)
			await t.frames(2)
		"confirm_back":
			var before := _snap(game)
			_press_confirm(game, false)
			await t.frames(2)
			_note_bounce(game, before, meta)
		"esc_panel", "later":
			var before_esc := _snap(game)
			_press_esc_panel(game)
			await t.frames(2)
			_note_bounce(game, before_esc, meta)
		"esc_mg":
			_esc_minigame(game)
			await t.frames(2)
		"dialog_skip":
			_dialog_skip(game)
			await t.frames(1)
		"drawer":
			await _chaos_drawer(t, game, seed, step, meta)
		_:
			game.autoplay_step()
			await t.frames(1)


func _chaos_actions(game: CardGameRoot) -> PackedStringArray:
	var a := PackedStringArray()
	a.append("autoplay")
	# A minigame sits above the panel. Esc goes to the game, not the panel under it.
	if game.mg_host != null and game.mg_host.is_active():
		a.append("esc_mg")
		return a
	if _at_table(game):
		a.append("close_day" if not _close_btn_missing else "day_end")
	if game.host != null and game.host.top_kind() == &"end_day":
		a.append("confirm_close")
		a.append("confirm_back")
	if game.host != null and game.host.top_panel() != null:
		a.append("esc_panel")
		a.append("later")
	if _noted.has("dialog") and game.get("dialog") != null:
		a.append("dialog_skip")
	if _noted.has("tabs"):
		a.append("drawer")
	return a


func _press_close_day(game: CardGameRoot) -> void:
	var btn := _close_day_button(game)
	if btn != null:
		btn.pressed.emit()
		return
	_close_btn_missing = true
	_note_once("btn", "NOTE: close-day button node not mounted; chaos uses day.end")
	# Same path the button's pressed handler calls (day.end {confirm:false}, then the confirm panel).
	game._on_close_day()


func _press_confirm(game: CardGameRoot, yes: bool) -> void:
	var top := game.host.top_panel() if game.host != null else null
	if top == null:
		return
	var named := _button_text(top, CardText.ui("w0.btn.close_day"))
	var primary := _button_text(top, CardText.ui("w0.btn.primary"))
	var back := _button_text(top, CardText.ui("w0.btn.close"))
	if yes:
		var go: Button = named if named != null else primary
		if go != null:
			go.pressed.emit()
			return
		_note_once("end_yes", "NOTE: end_day confirm button not mounted; chaos uses day.end {confirm:true}")
		if top.has_method("autoplay_step") and top.autoplay_step():
			return
		game.engine.send(&"day.end", {"confirm": true})
		return
	if back != null:
		back.pressed.emit()
		return
	_note_once("end_back", "NOTE: end_day back button not mounted; chaos uses dismiss")
	top.dismiss()


func _press_esc_panel(game: CardGameRoot) -> void:
	# CardGameRoot Esc with a panel open is host.close_top() -> CardPanel.dismiss().
	if game.host != null and game.host.top_panel() != null:
		game.host.close_top()


func _esc_minigame(game: CardGameRoot) -> void:
	if game.mg_host == null or not game.mg_host.is_active():
		return
	var mg := game.mg_host.current
	if mg == null:
		return
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	if mg.has_method("_unhandled_key_input"):
		mg._unhandled_key_input(ev)
	elif mg.has_method("_unhandled_input"):
		mg._unhandled_input(ev)
	if game.mg_host.is_active() and game.mg_host.current == mg:
		mg.abort()


func _dialog_skip(game: CardGameRoot) -> void:
	var dlg = game.get("dialog")
	if dlg != null and (dlg as Object).has_method("skip"):
		(dlg as Object).call("skip")
		return
	_note_once("dialog", "NOTE: dialog not covered; chaos skip not run")


func _chaos_drawer(t, game: CardGameRoot, seed: int, step: int, meta: Dictionary) -> void:
	var ids: PackedStringArray = PackedStringArray()
	for id in TAB_IDS:
		if CardAnchors.has(StringName(id)):
			ids.append(id)
	if ids.is_empty():
		_note_once("tabs", "NOTE: tabs not covered; chaos drawer not run")
		return
	var ti := int(JevRng.draw(seed, "c.qa.chaos", ["tab", step]) * float(ids.size()))
	if ti >= ids.size():
		ti = ids.size() - 1
	var rect := CardAnchors.rect(StringName(ids[ti]))
	if rect.has_area():
		_click_at(game, rect.get_center())
	await t.frames(1)
	var how := int(JevRng.draw(seed, "c.qa.chaos", ["drawer_close", step]) * 3.0)
	if how == 0:
		_click_at(game, Vector2(640, 360))
	elif how == 1:
		var top := game.host.top_panel() if game.host != null else null
		var shut := _button_text(top, CardText.ui("w0.btn.close")) if top != null else null
		if shut != null:
			shut.pressed.emit()
		elif game.host != null and game.host.top_panel() != null:
			var before := _snap(game)
			game.host.close_top()
			await t.frames(1)
			_note_bounce(game, before, meta)
			return
	else:
		var before_esc := _snap(game)
		_press_esc_panel(game)
		await t.frames(1)
		_note_bounce(game, before_esc, meta)
		return
	await t.frames(1)


func _click_at(game: Node, pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	var vp := game.get_viewport()
	if vp != null:
		vp.push_input(down)
		vp.push_input(up)


func _snap(game: CardGameRoot) -> Dictionary:
	var v := game.engine.view()
	var id := 0
	if game.host != null and game.host.top_panel() != null:
		id = game.host.top_panel().get_instance_id()
	return {
		"kind": str(game.host.top_kind()) if game.host != null else "",
		"id": id,
		"phase": str(v.get("phase", "")),
		"day": int(v.get("date", {}).get("abs_day", 0)),
		"depth": _panel_depth(game),
	}


func _note_bounce(game: CardGameRoot, before: Dictionary, meta: Dictionary) -> void:
	if before.is_empty() or int(before.get("id", 0)) == 0:
		return
	if game.host == null or game.host.top_panel() == null:
		return
	var top := game.host.top_panel()
	if top.get_instance_id() == int(before["id"]):
		meta["unclosable"] = str(before["kind"])
		return
	var v := game.engine.view()
	var same := str(game.host.top_kind()) == str(before["kind"])
	var phase := str(v.get("phase", "")) == str(before["phase"])
	var day := int(v.get("date", {}).get("abs_day", 0)) == int(before["day"])
	if same and phase and day and _panel_depth(game) >= int(before["depth"]):
		meta["bounces"] = int(meta["bounces"]) + 1


func _recover(t, game: CardGameRoot, meta: Dictionary) -> bool:
	for _i in range(RECOVER_CAP):
		if _at_table(game):
			return true
		if game.mg_host != null and game.mg_host.is_active():
			_esc_minigame(game)
			await t.frames(2)
			continue
		if game.host != null and game.host.top_panel() != null:
			var before := _snap(game)
			_press_esc_panel(game)
			await t.frames(2)
			_note_bounce(game, before, meta)
			if game.host.top_panel() != null and game.host.top_panel().get_instance_id() == int(before["id"]):
				meta["unclosable"] = str(before["kind"])
				return false
			continue
		await t.frames(1)
	return _at_table(game)


func _close_day_button(game: CardGameRoot) -> Button:
	var root_n: Node = game.table if game.table != null else game
	return _button_text(root_n, CardText.ui("w0.btn.close_day"))


func _button_text(n: Node, text: String) -> Button:
	if n == null or text == "":
		return null
	var stack: Array = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is Button and (cur as Button).text == text:
			return cur as Button
		for i in range(cur.get_child_count() - 1, -1, -1):
			stack.append(cur.get_child(i))
	return null


func _assert_chaos(t, report: Dictionary) -> void:
	var c: Dictionary = report["chaos"]
	var v: Dictionary = report["view"]
	var end_day := int(v.get("date", {}).get("abs_day", 0))
	var phase := str(v.get("phase", ""))
	t.ok(bool(c["saw_table"]), "chaos saw an empty table (top_panel==null)")
	t.ok(not bool(c["left"]) or int(c["came_back"]) > 0, "chaos got back to the table after leaving it")
	t.ok(int(c["bounces"]) == 0, "chaos: a closed panel popped back open")
	t.ok(str(c["unclosable"]) == "", "chaos: panel would not close (%s)" % str(c["unclosable"]))
	t.ok(not bool(c["day_back"]), "chaos: abs_day went backwards")
	t.ok(end_day > int(c["day0"]) or phase == "game_over", "chaos: days advanced %s -> %s phase=%s" % [
		str(c["day0"]), str(end_day), phase])
	if _close_btn_missing:
		t.ok(int(_chaos_counts.get("day_end", 0)) > 0, "chaos used day.end (button node missing)")
	else:
		t.ok(int(_chaos_counts.get("close_day", 0)) > 0, "chaos clicked the close-day button")
	var parts := PackedStringArray()
	var keys: Array = _chaos_counts.keys()
	keys.sort()
	for k in keys:
		parts.append("%s=%s" % [str(k), str(_chaos_counts[k])])
	print("K14 CHAOS %s returns=%s bounces=%s max_away=%s abs=%s->%s" % [
		" ".join(parts), str(c["came_back"]), str(c["bounces"]), str(c["max_away"]),
		str(c["day0"]), str(end_day)])
	if int(_chaos_counts.get("esc_mg", 0)) == 0 and (report["mgs"] as Dictionary).is_empty():
		print("NOTE: no minigame opened; chaos Esc-on-minigame not run")


func _note_shows(spy) -> void:
	var order := ["stage", "drawer_l", "drawer_r", "overlay"]
	var counts := {"stage": 0, "drawer_l": 0, "drawer_r": 0, "overlay": 0}
	var saw := false
	var ps := _panel_show_map()
	for ev in spy.ui_events():
		if ev[0] != &"panel_opened":
			continue
		var args: Dictionary = ev[1]
		var show := ""
		if args.has("show"):
			saw = true
			show = str(args["show"])
		elif not ps.is_empty():
			show = str(ps.get(str(args.get("kind", "")), ""))
		if counts.has(show):
			counts[show] = int(counts[show]) + 1
	var bits := PackedStringArray()
	for k in order:
		bits.append("%s:%d" % [k, int(counts[k])])
	print("K14 SHOW " + ",".join(bits))
	if not saw:
		print("NOTE: show not covered")
		return
	for k in order:
		if int(counts[k]) == 0:
			print("NOTE: show not covered " + k)


func _panel_show_map() -> Dictionary:
	var scr := load("res://scripts/cards/api/card_ids.gd") as Script
	if scr == null:
		return {}
	var m: Dictionary = scr.get_script_constant_map()
	if not m.has("PANEL_SHOW") or typeof(m["PANEL_SHOW"]) != TYPE_DICTIONARY:
		return {}
	return m["PANEL_SHOW"]


func _shot_current(game: CardGameRoot, dir: String, v: Dictionary) -> void:
	if _shot_dead:
		return
	if DisplayServer.get_name() == "headless":
		if not _shot_dead:
			print("NOTE: headless display, screenshots skipped")
			_shot_dead = true
		return
	var phase := str(v.get("phase", "na"))
	if game.mg_host != null and game.mg_host.is_active() and game.mg_host.current != null:
		await _save_shot(dir, phase, "mg_" + str(game.mg_host.current.kind()))
	if game.host != null and game.host.top_panel() != null:
		await _save_shot(dir, phase, str(game.host.top_kind()))


func _save_shot(dir: String, phase: String, panel: String) -> void:
	if _shot_dead or _shot_seen.has(panel):
		return
	_shot_seen[panel] = true
	var path := _abs_dir(dir)
	DirAccess.make_dir_recursive_absolute(path)
	await RenderingServer.frame_post_draw
	var tex := root.get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.get_width() <= 0:
		print("NOTE: viewport image empty, screenshots skipped")
		_shot_dead = true
		return
	var fn := "%03d_%s_%s.png" % [_shot_n, phase, panel]
	_shot_n += 1
	img.save_png(path.path_join(fn))
	print("SHOT ", path.path_join(fn))


func _fixture_shots(bus: CardEventBus, dir: String) -> void:
	await _shot_fixture(bus, dir, "street_prison", "day", "prison", true)
	await _shot_fixture(bus, dir, "year_jump", "year_jump", "year_jump", false)
	await _shot_fixture(bus, dir, "morning", "morning", "dossier", false)


func _shot_fixture(bus: CardEventBus, dir: String, fixture: String, phase: String, panel: String, also_street: bool) -> void:
	var game := _boot(bus, {"fixture": fixture, "skip_title": true, "guide": "off"})
	game.guide.force(false)
	game.guide.skip_fades = true
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if panel == "dossier":
		game.host.open_panel(&"dossier", {})
		await process_frame
		await process_frame
	await _save_shot(dir, phase, panel)
	if also_street and game.host.top_panel() != null:
		game.host.close_top()
		await process_frame
		await process_frame
		await _save_shot(dir, "day", "street")
	game.queue_free()
	CardAnchors.clear()
	await process_frame
	await process_frame


func _abs_dir(dir: String) -> String:
	if dir.begins_with("res://") or dir.begins_with("user://"):
		return ProjectSettings.globalize_path(dir)
	return dir
