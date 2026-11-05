# C15 screenshots (not in a suite): both games driven by real mouse events pushed into the viewport, with the
# counter stage behind and the card theme on, at 1280x720 under xvfb. --out=<dir> picks the folder.
#   xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --path . --rendering-driver opengl3 --audio-driver Dummy \
#     --resolution 1280x720 -s res://scripts/tests/cards/C15/shot_fragments_decode.gd -- --out=<dir>
extends SceneTree

const H = preload("res://scripts/tests/cards/C15/harness.gd")
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"
const STEPS := "res://scripts/tests/cards/C15/guide_steps.json"

var _out := "/tmp/shots/C15"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(_out)
	root.theme = CardTheme.build_theme()
	_run()


func _run() -> void:
	await _fragments()
	await _letter()
	await _scroll()
	await _decode()
	await _ledger()
	await _guide_shot(&"mg.fragments", "frag_10_guide")
	await _guide_shot(&"mg.decode", "dec_06_guide")
	quit(0)


func _fragments() -> void:
	var ctx := _open(H.FRAG, H.params("ticket_fake.json"))
	_behind(ctx)
	var g = ctx["game"]
	var box := H.take(g)
	await _shot("frag_01_open")
	var o: Vector2 = g.panel_origin()
	var board = g.get("_board")
	var order: Array = board.z_order.duplicate()
	order.reverse()
	var first := int(order[0])
	while g.piece_rot(first) != 0:
		H.click(self, o + g.piece_center(first), MOUSE_BUTTON_RIGHT)
	var from: Vector2 = o + g.piece_center(first)
	var to: Vector2 = o + g.slot_center(first) + Vector2(10, -6)
	H.move(self, from)
	H.button(self, from, true)
	for i in range(1, 4):
		H.move(self, from.lerp(to, float(i) / 6.0), MOUSE_BUTTON_MASK_LEFT)
	await _shot("frag_02_drag")
	for i in range(4, 7):
		H.move(self, from.lerp(to, float(i) / 6.0), MOUSE_BUTTON_MASK_LEFT)
	H.button(self, to, false)
	for k in range(1, order.size()):
		var p := int(order[k])
		while g.piece_rot(p) != 0:
			H.click(self, o + g.piece_center(p), MOUSE_BUTTON_RIGHT)
		H.drag(self, o + g.piece_center(p), o + g.slot_center(p) + Vector2(-8, 5))
		if k == 2:
			await _shot("frag_03_half")
	print("C15 placed " + str(g.placed_count()) + " of " + str(g.avail_count()))
	await _shot("frag_04_whole")
	var L: Dictionary = g.layout()
	var seal: Dictionary = L["seal"]
	H.click(self, g.tool_button("lens").get_global_rect().get_center())
	H.move(self, o + board.seam_mid(int(seal["seam"])) + Vector2(0, 0))
	await _shot("frag_05_lens_on_seal")
	var odd: Array = L["odd"]
	var crossed := 0
	for s in range((L["seams"] as Array).size()):
		var row: Dictionary = L["seams"][s]
		if odd.has(int(row["a"])) != odd.has(int(row["b"])) and crossed < 1:
			H.move(self, o + board.seam_mid(s) + Vector2(60, 0))
			await _shot("frag_06_lens_on_odd_seam")
			break
	H.click(self, g.tool_button("lens").get_global_rect().get_center())
	H.click(self, g.tool_button("light").get_global_rect().get_center())
	await _shot("frag_07_backlight")
	H.click(self, g.tool_button("light").get_global_rect().get_center())
	for s2 in range((L["seams"] as Array).size()):
		var row2: Dictionary = L["seams"][s2]
		if odd.has(int(row2["a"])) or odd.has(int(row2["b"])):
			H.click(self, o + board.seam_mid(s2))
	H.click(self, g.seal_button_rect(2).get_center())
	var plain := -1
	for s3 in range((L["seams"] as Array).size()):
		var row3: Dictionary = L["seams"][s3]
		if not odd.has(int(row3["a"])) and not odd.has(int(row3["b"])):
			plain = s3
	if plain >= 0:
		H.move(self, o + board.seam_mid(plain) + Vector2(0, 3))
	await _shot("frag_08_judged")
	H.click(self, g.tool_button("done").get_global_rect().get_center())
	print("C15 fragments result " + str(box["r"]))
	await _drop(ctx)


func _letter() -> void:
	var ctx := _open(H.FRAG, H.params("letter_missing.json"))
	_behind(ctx)
	var g = ctx["game"]
	var o: Vector2 = g.panel_origin()
	var board = g.get("_board")
	var order: Array = board.z_order.duplicate()
	order.reverse()
	for p2 in order:
		var p := int(p2)
		while g.piece_rot(p) != 0:
			H.click(self, o + g.piece_center(p), MOUSE_BUTTON_RIGHT)
		H.drag(self, o + g.piece_center(p), o + g.slot_center(p))
	await _shot("frag_09_letter_gap")
	await _drop(ctx)


func _scroll() -> void:
	var ctx := _open(H.FRAG, H.params("scroll8.json"))
	_behind(ctx)
	await _shot("frag_11_scroll_open")
	await _drop(ctx)


func _decode() -> void:
	var fix := H.params("chen_code.json")
	var ctx := _open(H.DEC, fix)
	_behind(ctx)
	var g = ctx["game"]
	var box := H.take(g)
	await _shot("dec_01_open")
	var codes: Array = fix["codes"]
	for j in range(codes.size()):
		H.click(self, g.group_rect(j).position + Vector2(20, 20))
		var code := str(codes[j])
		if j == 1:
			code = "5127"
		var want: int = g.page_of(code)
		for tab in g.tab_rects():
			if int(tab[1]) <= want and int(tab[1]) > g.current_page():
				H.click(self, (tab[0] as Rect2).get_center())
		var guard := 0
		while g.current_page() != want and guard < 20:
			H.click(self, g.nav_rect(g.current_page() < want).get_center())
			guard += 1
		if j == 0:
			H.move(self, g.row_rect(g.page_codes().find(code)).get_center())
			await _shot("dec_02_page_hover")
		H.click(self, g.row_rect(g.page_codes().find(code)).get_center())
		if j == 2:
			await _shot("dec_03_some")
	await _shot("dec_04_all")
	H.click(self, g.done_rect().get_center())
	print("C15 decode result " + str(box["r"]))
	await _drop(ctx)


func _ledger() -> void:
	var fix := H.params("ledger_key.json")
	var ctx := _open(H.DEC, fix)
	_behind(ctx)
	var g = ctx["game"]
	var panel: Control = g.get("_panel")
	var plus := Vector2.ZERO
	for c in panel.get_children():
		if c is Button and (c as Button).text == "+":
			plus = (c as Button).get_global_rect().get_center()
	for i in range(int(fix["key_shift"])):
		H.click(self, plus)
	H.click(self, g.group_rect(1).position + Vector2(20, 20))
	await _shot("dec_05_key")
	await _drop(ctx)


## Opens the game the way the table does: the host gets minigame_requested and shows its own abort button.
func _open(scene: String, fix: Dictionary) -> Dictionary:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	var host := CardMiniGameHost.new()
	host.bind(mock, bus)
	root.add_child(host)
	var kind := &"fragments" if scene == H.FRAG else &"decode"
	host._on_requested("c0001", "", kind, fix)
	return {"bus": bus, "mock": mock, "host": host, "game": host.current}


func _drop(ctx: Dictionary) -> void:
	if ctx.has("stage"):
		(ctx["stage"] as Node).queue_free()
	H.close(ctx)
	await process_frame


func _behind(ctx: Dictionary) -> void:
	var stage = load(CardIds.widget_scene(&"stage")).instantiate()
	stage.bus = ctx["bus"]
	var host: Node = ctx["host"]
	root.add_child(stage)
	root.move_child(stage, host.get_index())
	stage.refresh({"stage": {"set": "counter", "time": "day"}, "demands": []})
	stage.play({
		"set": "counter",
		"cast": [{"who": "postman", "at": "customer", "look": "stand"}],
		"props": [],
	})
	ctx["stage"] = stage


func _guide_shot(mech: StringName, file_name: String) -> void:
	var scene := H.FRAG if mech == &"mg.fragments" else H.DEC
	var fix := H.params("ticket_fake.json" if mech == &"mg.fragments" else "chen_code.json")
	var ctx := _open(scene, fix)
	_behind(ctx)
	var guide = load(GUIDE).instantiate()
	root.add_child(guide)
	guide.bind(ctx["mock"], ctx["bus"])
	guide.force(true)
	guide.skip_fades = true
	guide.load_steps(CardDB.read_json(STEPS))
	await process_frame
	await process_frame
	(ctx["bus"] as CardEventBus).first_time.emit(mech, {"uid": "c0099"})
	guide.evaluate_now()
	await _shot(file_name)
	guide.queue_free()
	await _drop(ctx)


func _shot(file_name: String) -> void:
	for i in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	var path := _out.path_join(file_name + ".png")
	img.save_png(path)
	print("SHOT " + path)
