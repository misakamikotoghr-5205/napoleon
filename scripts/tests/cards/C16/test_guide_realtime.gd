# C16 real-time tutorial test (TUTORIAL.md P5): no virtual clock. Boots CardGame.tscn as the current
# scene with no arguments, exactly like the shipped exe, as a first launch (player files backed up and
# removed, restored at the end). No skip_fades, no evaluate_now, no tick(): the guide runs on its own
# _process. Only mouse moves and real presses/releases (root.push_input), except the spot minigame which
# is solved with autoplay_current (the only non-click).
#   Reader: reads every bubble and clicks "got it". Asserts gd.m.open lights within 1 s of the goals page,
#     the morning does not auto-start while the notice bubble is up, every day-1 lesson lights in the
#     prototype order, each bubble stays on screen, keeps off the anchor and the visible buttons of the
#     surface on top (button audit b47), and its text is not cut off.
#   Hurried: never clicks "got it", acts every 0.4 s, spins without incense. At least 70% of the day-1
#     lessons still light. Then "turn the guide off" on day 2: the guide stops and guide_hints=false is saved.
# Owner C16. Contract: docs/cards/CARDS_INTERFACES.md section 7.10.7 (10-22 prototype note).
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const SAVE_DIR := "user://cards"
const LEGACY_SETTINGS := "user://settings.json"
const DAY1: Array[String] = ["gd.d1.notice", "gd.d1.deal", "gd.d2.gold", "gd.d1.person", "gd.d1.close", "gd.choice",
	"gd.d1.look", "gd.d1.spot", "gd.d1.tiers", "gd.d1.ticket", "gd.d1.shelf", "gd.d1.buyer", "gd.d1.night",
	"gd.d1.settle"]
## First appearance order for the reader (spot/tiers may swap: got it on look lights tiers at once).
const READER_ORDER: Array[String] = ["gd.m.open", "gd.m.wheel", "gd.m.incense", "gd.d1.notice", "gd.d1.deal",
	"gd.d2.gold", "gd.d1.person", "gd.d1.close", "gd.choice", "gd.d1.look", "gd.d1.ticket", "gd.d1.shelf",
	"gd.d1.buyer", "gd.d1.night", "gd.d1.settle", "gd.d2.rules"]

var t
var game: CardGameRoot = null
var _backup: Dictionary = {}
var _t0 := 0
var _seen: Array = []
var _last := ""
var _looked := {}
var _tries := {}
var _picked := {}
var _pace := 0.5
var _reader := true
var _goals_at := -1.0
var _open_at := -1.0


func _initialize() -> void:
	t = T.new(self, "C16_guide_realtime")
	t.run_async(_body)


func _body() -> void:
	_take_backup()
	await _play(true)
	await _close()
	_wipe()
	await _play(false)
	await _close()
	_restore_backup()


func _play(reader: bool) -> void:
	_reader = reader
	_pace = 0.5 if reader else 0.4
	_seen = []
	_last = ""
	_looked = {}
	_tries = {}
	_picked = {}
	_goals_at = -1.0
	_open_at = -1.0
	_t0 = Time.get_ticks_msec()
	var who := "reader" if reader else "hurried"
	change_scene_to_file(CardIds.ROOT_SCENE)
	for _i in range(120):
		await process_frame
		game = current_scene as CardGameRoot
		if game != null and game.engine != null and game.title != null:
			break
	t.ok(game != null and game.title != null, who + ": CardGame.tscn boots to the title with no args")
	if game == null or game.title == null:
		return
	game.allow_quit = false
	t.ok(game.engine is CardEngine, who + ": real engine")
	t.ok(game.guide.is_enabled(), who + ": a first launch has the guide on")
	t.eq(game.guide.skip_fades, false, who + ": real time (no skip_fades)")
	await _wait(0.5)
	await _click(game.title.get_node_or_null("new") as Button, "title new")
	var guard := 0
	while guard < 400 and _now() < 150.0:
		guard += 1
		var v := game.engine.view()
		var phase := str(v.get("phase", ""))
		var day := int(v.get("date", {}).get("stage_day", 0))
		if day >= 2 and phase in ["morning", "day"]:
			break
		if reader and await _read_bubble():
			continue
		await _act(phase)
		await _wait(_pace)
	var v2 := game.engine.view()
	t.eq(int(v2.get("date", {}).get("stage_day", 0)), 2, who + ": reached day 2 (%.0f s)" % _now())
	if reader:
		var waited := 0.0
		while game.guide.active_step() == "" and waited < 3.0:
			await _wait(0.2)
			waited += 0.2
	var ids: Array = []
	for row in _seen:
		ids.append(row[0])
	print("C16_REALTIME %s seen=%s" % [who, JSON.stringify(ids)])
	var lit := 0
	for id in DAY1:
		if ids.has(id):
			lit += 1
	if reader:
		for id in DAY1:
			t.ok(ids.has(id), "reader: day 1 lesson lit: " + id)
		var at := -1
		for id in READER_ORDER:
			var i := ids.find(id)
			t.ok(i > at, "reader: %s lights in order (at %d after %d)" % [id, i, at])
			at = maxi(at, i)
		t.ok(_goals_at >= 0.0 and _open_at >= 0.0 and _open_at - _goals_at <= 1.0,
			"reader: gd.m.open within 1 s of the goals page (%.2f s)" % (_open_at - _goals_at))
	else:
		t.ok(float(lit) >= 0.7 * float(DAY1.size()), "hurried: at least 70%% of day 1 lessons lit (%d of %d)" % [lit, DAY1.size()])
		await _turn_off()


func _close() -> void:
	if game != null and is_instance_valid(game):
		game.queue_free()
	game = null
	await process_frame
	await process_frame
	CardAnchors.clear()


## Reader: a bubble is up. Check it once, read it, press "got it".
func _read_bubble() -> bool:
	var g := game.guide
	var cur := g.active_step()
	if cur == "":
		return false
	await _wait(0.4)
	if g.active_step() != cur:
		return true
	_check_bubble(cur)
	if cur == "gd.d1.notice":
		t.eq(str(game.engine.view().get("phase", "")), "morning", "reader: the morning waits while the notice bubble is up")
	await _wait(0.6)
	if g.active_step() != cur:
		return true
	await _click(g.get_node("Chrome/Bubble/Ok") as Button, "got it on " + cur)
	# A reader looks up before acting: longer than the guide's 0.3 s gap, so a waiting step shows first.
	await _wait(0.5)
	return true


func _check_bubble(step: String) -> void:
	var g := game.guide
	var b := g.get_node("Chrome/Bubble") as Control
	var br := b.get_global_rect()
	var tx := g.get_node("Chrome/Bubble/Text") as Label
	t.ok(b.is_visible_in_tree() and g.get_node("Chrome").modulate.a > 0.5, step + ": bubble visible")
	t.ok(Rect2(0, 0, 1280, 720).encloses(br), step + ": bubble inside 1280x720")
	t.eq(tx.get_visible_line_count(), tx.get_line_count(), step + ": text not cut off")
	t.ok(tx.text.strip_edges() != "", step + ": bubble has its line")
	var glow: Rect2 = g.get("_glow_rect")
	t.ok(not br.intersects(glow), step + ": bubble keeps off the glowing anchor")
	for r in _top_buttons():
		t.ok(not br.intersects(r), "%s: bubble keeps off a visible button at %s" % [step, r])


## Buttons the player can see on top: the open overlay / minigame, else the table (not the guide's own).
func _top_buttons() -> Array:
	var top: Node = game
	if game.mg_host != null and game.mg_host.is_active():
		top = game.mg_host
	elif game.host.top_overlay() != null:
		top = game.host.top_overlay()
	var out: Array = []
	_buttons(top, out)
	return out


func _buttons(n: Node, out: Array) -> void:
	if n == game.guide:
		return
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is BaseButton and (n as Control).is_visible_in_tree() and (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
		out.append((n as Control).get_global_rect())
	for c in n.get_children():
		_buttons(c, out)


## Hurried player on day 2: press "turn the guide off" on the first bubble.
func _turn_off() -> void:
	var g := game.guide
	var waited := 0.0
	while g.active_step() == "" and waited < 6.0:
		await _wait(0.2)
		waited += 0.2
	t.ok(g.active_step() != "", "hurried: a bubble is up on day 2 (" + g.active_step() + ")")
	if g.active_step() == "":
		return
	await _click(g.get_node("Chrome/Bubble/Off") as Button, "turn the guide off")
	await _wait(0.3)
	t.eq(g.active_step(), "", "turn off hides the bubble")
	t.eq(g.is_enabled(), false, "turn off stops the guide")
	t.ok((g.get_node("Flash") as Control).visible, "turn off says where to turn it back on")
	var bag = load("res://scripts/town/settings.gd").new(LEGACY_SETTINGS)
	t.ok(bag.load_file(), "settings saved")
	t.eq(bool(bag.guide_hints), false, "guide_hints=false saved for the next launch")
	await _wait(1.0)
	t.eq(g.active_step(), "", "stays off")


# ---------------- playing like a player ----------------
func _act(phase: String) -> void:
	var host := game.host
	if game.mg_host != null and game.mg_host.is_active():
		await _wait(0.3)
		game.mg_host.autoplay_current(0.8)
		return
	if str(host.top_kind()) == "shelf":
		for b in _walk(host.top_panel()):
			if b is Button and (b as Button).name != "CloseButton" and (b as Button).is_visible_in_tree() and not (b as Button).disabled:
				await _click(b, "shelf pick")
				return
	var reply := _pick_reply()
	if reply != null:
		await _click(reply, "reply " + str(reply.get_meta("reply_id", "")))
		return
	if game.dialog != null and not game.dialog.is_idle():
		var frame := game.dialog.get_node_or_null("Frame") as Control
		if frame != null and frame.is_visible_in_tree():
			await _click_at(_center(frame) + Vector2(0, -20), frame, "dialog advance")
			return
	var top := host.top_panel()
	var kind := str(host.top_kind())
	if kind == "month_open":
		var goals := top.find_child("Goals", true, false) as Control
		if goals != null and not goals.is_visible_in_tree():
			await _click_at(Vector2(640, 300), top, "month page")
			return
		await _click(top.find_child("Begin", true, false) as Button, "month begin")
		return
	if kind == "wheel":
		var spin := top.find_child("Spin", true, false) as Button
		var cont := top.find_child("Continue", true, false) as Button
		var err := top.find_child("Err", true, false) as Label
		if cont != null and cont.is_visible_in_tree():
			await _click(cont, "wheel continue")
			return
		if err != null and err.visible and err.text != "":
			var offer := top.find_child("Offer", true, false) as Button
			if offer != null and offer.is_visible_in_tree() and not offer.disabled:
				await _click(offer, "wheel offer")
				return
		if spin != null and spin.is_visible_in_tree() and not spin.disabled:
			await _click(spin, "wheel spin")
			await _wait(3.0)
		return
	if kind == "end_day":
		await _click(top.find_child("BtnConfirm", true, false) as Button, "end-day confirm")
		return
	if kind == "night" or (phase == "night" and top == null):
		await _play_card(true)
		return
	if top != null:
		if not top.autoplay_step():
			host.close_panel(top)
		return
	if phase == "morning" and not _reader and game.guide.active_step() != "":
		# The morning waits as long as a bubble is up (no cap); the hurried player opens the shop himself.
		var end := game.get("_end") as Button
		await _click(end, "open the shop over the bubble")
		await _wait(0.3)
		t.ok(str(game.engine.view().get("phase", "")) != "morning", "hurried: the shop button works while the guide waits")
		return
	if phase == "day":
		var cards: Array = game.hand.get("_cards")
		for i in cards.size():
			var u := str((cards[i] as Dictionary).get("uid", ""))
			if int(_tries.get(u, 0)) < 2:
				_tries[u] = int(_tries.get(u, 0)) + 1
				await _play_card(false, i)
				return
		await _click(game.get("_end") as Button, "close day")


func _play_card(night: bool, want := 0) -> void:
	var fan = game.hand
	var cards: Array = fan.get("_cards")
	var slots: Array = fan.get("_slots")
	if cards.is_empty():
		return
	var pick := want
	if night:
		for i in cards.size():
			if str((cards[i] as Dictionary).get("def", "")) == "":
				pick = i
	if pick >= slots.size():
		return
	var slot := slots[pick] as Control
	await _hover(_center(slot))
	await _wait(0.2)
	await _click(slot, "hand card %d" % pick)
	await _wait(0.3)
	await _click(fan.get_node_or_null("PreviewButtons/Play") as Button, "hand play")


func _pick_reply() -> Button:
	if game.dialog == null:
		return null
	var btns: Array = []
	for n in _walk(game.dialog):
		if n is Button and (n as Button).has_meta("reply_id") and (n as Button).is_visible_in_tree() and not (n as Button).disabled:
			btns.append(n)
	if btns.is_empty():
		return null
	var uid := game.dialog.current_uid()
	var want := ["choice:listen", "tier:fair", "accept", "pick", "dawn", "roll"]
	if int(_picked.get(uid, 0)) >= 1:
		want = ["tier:fair", "accept", "dawn", "roll", "refuse"]
	if not _looked.has(uid):
		want.push_front("look")
	for w in want:
		for b in btns:
			if str(b.get_meta("reply_id")) == w:
				if w == "look":
					_looked[uid] = true
				if w == "pick":
					_picked[uid] = int(_picked.get(uid, 0)) + 1
				return b
	for b in btns:
		var id := str(b.get_meta("reply_id"))
		if id.begins_with("tier:") or id.begins_with("choice:"):
			return b
	for b in btns:
		if str(b.get_meta("reply_id")) not in ["later", "refuse", "decline", "look", "send_off"]:
			return b
	for b in btns:
		if str(b.get_meta("reply_id")) == "send_off":
			return b
	return btns[0]


# ---------------- time, input ----------------
func _now() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
		_watch()


func _watch() -> void:
	if game == null or game.guide == null:
		return
	if _goals_at < 0.0 and CardAnchors.has(&"a.month.goals"):
		_goals_at = _now()
	var cur := game.guide.active_step()
	if cur == _last:
		return
	_last = cur
	if cur == "":
		return
	if cur == "gd.m.open" and _open_at < 0.0:
		_open_at = _now()
	var known := false
	for row in _seen:
		if row[0] == cur:
			known = true
	if not known:
		_seen.append([cur, _now(), str(game.engine.view().get("phase", ""))])


func _center(c: Control) -> Vector2:
	return c.get_global_transform_with_canvas() * (c.size * 0.5)


func _hover(at: Vector2) -> Control:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	root.push_input(mv, true)
	await process_frame
	_watch()
	return root.gui_get_hovered_control()


func _click(c: Control, label: String) -> bool:
	if c == null or not c.is_visible_in_tree():
		print("C16_REALTIME skip invisible ", label)
		return false
	return await _click_at(_center(c), c, label)


func _click_at(at: Vector2, owner: Control, label: String) -> bool:
	var hit := await _hover(at)
	var ok := hit != null and (hit == owner or owner.is_ancestor_of(hit))
	if not ok:
		# The guide must never sit on what the player clicks (b47); anything else is the walk's problem.
		var path := str(hit.get_path()) if hit != null else "<none>"
		t.ok(not path.contains("GuideOverlay"), "%s: the guide does not take the click (%s)" % [label, path])
		print("C16_REALTIME blocked %s at %s by %s" % [label, at, path])
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		ev.global_position = at
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(ev, true)
		await process_frame
		_watch()
	return ok


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


# ---------------- first launch: player files ----------------
func _take_backup() -> void:
	_backup = {}
	for path in _player_files():
		_backup[path] = FileAccess.get_file_as_bytes(path)
	_wipe()


func _wipe() -> void:
	for path in _player_files():
		DirAccess.remove_absolute(path)


func _restore_backup() -> void:
	_wipe()
	for path in _backup.keys():
		DirAccess.make_dir_recursive_absolute(str(path).get_base_dir())
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_backup[path])
			f.close()


func _player_files() -> Array:
	var out: Array = []
	if FileAccess.file_exists(LEGACY_SETTINGS):
		out.append(LEGACY_SETTINGS)
	if DirAccess.dir_exists_absolute(SAVE_DIR):
		for f in DirAccess.get_files_at(SAVE_DIR):
			out.append(SAVE_DIR.path_join(f))
	return out
