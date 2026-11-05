# 验货“找不同”验收：对着图鉴，用朱笔圈出不对的地方。
# 圈中 / 圈空 / 圈太大不算 / 墨有限 / 细处非放大镜不揭 / 旧痕批注 / 破绽画法确定（同种子同像素；生成的假货位置随物品变）/
# 生成物品的破绽随存档走 / 再验一次圈还在 / Esc 先收验货 / 序章哥哥教圈的步骤 / 墨用完不卡死。
extends SceneTree

const AppraisePanel = preload("res://scripts/ui/appraise_panel.gd")
const Appraise = preload("res://scripts/core/appraise.gd")
const FlawRender = preload("res://scripts/core/flaw_render.gd")
const Session = preload("res://scripts/core/session.gd")
const World = preload("res://scripts/core/world.gd")
const Items = preload("res://scripts/sim/item_gen.gd")
const Sim = preload("res://scripts/sim/town_sim.gd")
const SaveState = preload("res://scripts/core/save.gd")
const Ledger = preload("res://scripts/core/ledger.gd")

var failures: int = 0

func _initialize() -> void:
	await _run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _run() -> void:
	_test_fit()
	await _test_sulfa_hits_and_misses()
	await _test_ink_limit_and_reopen()
	await _test_magnifier_gate_and_benign()
	await _test_tutorial_coach()
	_test_deterministic_render()
	_test_generated_placement()
	_test_save_round_trip()
	_test_no_softlock()
	await _test_esc_closes()
	_test_glyphs()
	FlawRender.clear_cache()
	Appraise.clear_cache()
	DB.shutdown()
	print("RESULT: ", "OK" if failures == 0 else "FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)

# ---------------- 夹具 ----------------
func _world(seed_v: int = 7):
	var w = World.new()
	w.setup(seed_v)
	return w

func _session(w, defs: Array, extra: Dictionary = {}):
	var items: Array = []
	for d in defs:
		items.append({"def": d})
	var spec := {"id": "probe_appraise", "npc": "xiaoding", "mode": "buy", "items": items,
		"ask": 50, "floor": 25, "suggest": 40, "est": [10, 90], "min_inspect": 0}
	spec.merge(extra, true)
	var s = Session.new()
	s.setup(w, spec)
	return s

func _panel():
	var p = AppraisePanel.new()
	p.size = Vector2(920, 610)
	root.add_child(p)
	await process_frame
	return p

func _center(p, pid: String) -> Vector2:
	return p.part_local_rect(pid).get_center()

# ---------------- 圈的拟合 ----------------
func _test_fit() -> void:
	var ring: Array = []
	for k in 24:
		var a := TAU * k / 24.0
		ring.append(Vector2(30, 20) + Vector2(cos(a), sin(a)) * 6.0)
	var f: Dictionary = Appraise.fit_circle(ring)
	_check(f["ok"] and (f["center"] as Vector2).distance_to(Vector2(30, 20)) < 0.3 and absf(float(f["radius"]) - 6.0) < 0.3, "a drawn ring fits to its centre and mean radius")
	var line: Array = []
	for k in 20:
		line.append(Vector2(10 + k, 10))
	_check(not Appraise.fit_circle(line)["ok"], "a straight stroke is not a circle (no ink spent)")
	_check(not Appraise.fit_circle([Vector2(3, 3), Vector2(3, 3)])["ok"], "a click is not a circle")

# ---------------- 假磺胺：两处圈中、一处圈空、圈太大 ----------------
func _test_sulfa_hits_and_misses() -> void:
	var w = _world()
	w.unlocked["medbook"] = true
	var s = _session(w, ["sulfa_fake"])
	var iid: String = s.item_ids[0]
	var p = await _panel()
	p.open(s, iid)
	_check(p.has_ref() and str(p.ref.get("key", "")) == "med_sulfa", "fake sulfa compares against the genuine sulfa page (medbook unlocks it)")
	_check(s.ink_max(iid) == 4, "the 鉴别录 for this category adds one stroke (3 + 1)")
	_check(not FlawRender.same_pixels(p._ref_img, p._hand_soft), "the fake in hand looks different from the reference")
	var r1: Dictionary = p.circle_at(_center(p, "powder"), 30.0, "hand")
	_check(r1["kind"] == "hit" and s.inspected[iid].has("powder"), "circling the white powder by hand reveals it")
	_check(str(r1["text"]).find("和图鉴不一样") >= 0, "the note says it differs from the reference")
	var r2: Dictionary = p.circle_at(_center(p, "label"), 26.0, "hand")
	_check(r2["kind"] == "hit" and s.inspected[iid].has("label") and w.flags.get("found_fake_sulfa", false), "circling the printed maker's mark reveals it and sets the story flag")
	var before: int = s.inspected_total()
	var r3: Dictionary = p.circle_at(Vector2(290, 30), 18.0, "hand")
	_check(r3["kind"] == "miss" and s.inspected_total() == before, "an empty corner is a miss and reveals nothing")
	_check(str(r3["text"]) == "这里看不出和图鉴有什么不同。", "miss note is objective: 这里看不出和图鉴有什么不同")
	var r4: Dictionary = p.circle_at(Vector2(160, 160), 150.0, "hand")
	_check(r4["kind"] == "oversize" and s.inspected_total() == before, "a huge circle around everything does not count")
	_check(s.ink_left(iid) == 0 and s.circles[iid].size() == 4, "every stroke (hit, miss, oversize) costs ink")
	var r5: Dictionary = p.circle_at(_center(p, "batch"), 20.0, "book")
	_check(r5["kind"] == "no_ink" and not s.inspected[iid].has("batch"), "no ink, no more circles")
	for c in s.circles[iid]:
		_check(str(c.get("text", "")).find("底价") < 0 and str(c.get("text", "")).find("心里") < 0, "notes never reveal price or the customer's mind: " + str(c.get("text", "")).substr(0, 12))
	p.queue_free()
	await process_frame

# ---------------- 墨与再验一次 ----------------
func _test_ink_limit_and_reopen() -> void:
	var w = _world()
	var s = _session(w, ["rice_sunji"])
	var iid: String = s.item_ids[0]
	var p = await _panel()
	p.open(s, iid)
	_check(s.ink_max(iid) == 3, "rice: three strokes (no 鉴别录 for rice)")
	p.circle_at(_center(p, "bag"), 40.0, "hand")
	_check(s.inspected[iid].has("bag") and not s.pending_events.is_empty(), "the 孙记 stamp on the bag is found by circling it (story event queued)")
	p.circle_at(_center(p, "grain"), 40.0, "hand")
	_check(s.inspected[iid].has("grain") and s.inspected[iid].has("color"), "one hand circle on the rice pile reveals the two looks at the same spot")
	p.circle_at(Vector2(300, 300), 12.0, "hand")
	_check(s.ink_left(iid) == 0, "three strokes used")
	var r: Dictionary = p.circle_at(_center(p, "smell"), 25.0, "nose")
	_check(r["kind"] == "no_ink" and not s.inspected[iid].has("smell"), "fourth stroke refused")
	p._on_close()
	_check(not p.visible, "put down")
	p.open(s, iid)
	_check(s.circles[iid].size() == 3 and s.ink_left(iid) == 0, "再验一次 re-opens with the circles already drawn and no ink refilled")
	_check(p.notes.text.find("①") >= 0 and p.notes.text.find("③") >= 0, "numbered notes are pinned again")
	p.queue_free()
	await process_frame

# ---------------- 细处要放大镜；旧痕的批注 ----------------
func _test_magnifier_gate_and_benign() -> void:
	var w = _world(11)
	var s = _session(w, ["coin_fake"])
	var iid: String = s.item_ids[0]
	var p = await _panel()
	p.open(s, iid)
	var it: Dictionary = s.item(iid)
	var insc := Rect2i(27, 14, 10, 10)
	_check(not FlawRender.region_differs(p._ref_img, p._hand_soft, insc), "the broken inscription cannot be seen with the naked eye")
	_check(FlawRender.region_differs(p._ref_img, p._hand_sharp, insc), "the broken inscription shows under the magnifier")
	_check(FlawRender.region_differs(p._ref_img, p._hand_soft, Rect2i(49, 24, 10, 16)), "the notched rim is visible without the magnifier")
	var r1: Dictionary = p.circle_at(_center(p, "inscription"), 28.0, "hand")
	_check(r1["kind"] == "tool" and not s.inspected[iid].has("inscription"), "circling the fine inscription by eye does not reveal it")
	_check(str(r1["text"]).find("放大镜") >= 0, "it says to switch to the magnifier")
	var r2: Dictionary = p.circle_at(_center(p, "inscription"), 28.0, "magnifier")
	_check(r2["kind"] == "hit" and s.inspected[iid].has("inscription"), "with the magnifier the same circle reveals it")
	var r3: Dictionary = p.circle_at(_center(p, "face"), 32.0, "hand")
	_check(r3["kind"] == "hit" and s.inspected[iid].has("face"), "the worn shiny patch can be circled")
	var c3: Dictionary = s.circles[iid][2]
	_check(str(c3["tone"]) == "benign" and str(c3["text"]).find("和图鉴不一样") >= 0 and str(c3["text"]).find("不一定是毛病") >= 0, "benign difference: differs from the reference, may be normal wear")
	_check(not it.get("_tell_noted", false) or s.inspected[iid].has("inscription"), "only real tells write the '有破绽' note")
	p.queue_free()
	await process_frame

# ---------------- 序章：哥哥一步步教 ----------------
func _test_tutorial_coach() -> void:
	var w = _world(5)
	var iid: String = w.ledger.add_item(_def("coin_fake"), "player", "counter")
	var s = Session.new()
	s.world = w
	s.mode = "practice"
	s._add(iid)
	var p = await _panel()
	p.atlas_open = false
	p.open(s, "", true)
	_check(p.coach_box.visible and p.coach_lbl.text.find("图鉴翻开") >= 0, "tutorial step 1: open the 图鉴 page")
	_check(p.close_btn.disabled, "cannot put the practice coin down before circling anything")
	p.open_atlas()
	_check(p.coach_lbl.text.find("放大镜") >= 0, "tutorial step 2: compare, pick the magnifier")
	p.set_tool("magnifier")
	_check(p.coach_lbl.text.find("圈起来") >= 0, "tutorial step 3: circle the difference")
	p.circle_at(_center(p, "inscription"), 26.0, "magnifier")
	_check(p.coach_lbl.text.find("就是这儿") >= 0 and not p.close_btn.disabled, "a hit is praised and the coin can be put down")
	var done := {"v": false}
	p.done_practice.connect(func(): done["v"] = true)
	p._on_close()
	_check(done["v"] and not p.visible, "看完了 finishes the practice")
	var pro: Dictionary = DB.get_db().scripts.get("prologue", {})
	var lines := ""
	for st in pro.get("steps", []):
		lines += str(st.get("text", "")) + str(st.get("item", "")) + str(st.get("def", ""))
	_check(lines.find("coin_fake") >= 0 and lines.find("图鉴") >= 0 and lines.find("朱笔圈") >= 0 and lines.find("放大镜") >= 0, "prologue: the brother teaches 图鉴 → compare → magnifier → circle with the coin")
	p.queue_free()
	await process_frame

func _def(id: String) -> Dictionary:
	var d: Dictionary = DB.get_db().items[id].duplicate(true)
	d["def_id"] = id
	return d

# ---------------- 破绽画法确定 ----------------
func _test_deterministic_render() -> void:
	var it: Dictionary = _def("coin_fake")
	var a: Image = FlawRender.hand_image(it, 123, true)
	var b: Image = FlawRender.hand_image(it, 123, true)
	_check(FlawRender.same_pixels(a, b), "same seed → same pixels")
	var c: Image = FlawRender.hand_image(it, 999, true)
	_check(not FlawRender.same_pixels(a, FlawRender.base_image(it)), "flaws are actually painted")
	_check(FlawRender.same_pixels(c, FlawRender.hand_image(it, 999, true)), "another seed is just as repeatable")
	for key in ["robe", "coat", "qipao", "scarf", "bangle", "jade", "tinpot", "clock", "bowl", "landscape", "calligraphy"]:
		var img: Image = FlawRender.proc_base(key)
		var solid := 0
		for y in 64:
			for x in 64:
				if img.get_pixel(x, y).a > 0.5:
					solid += 1
		_check(solid > 400 and FlawRender.same_pixels(img, FlawRender.proc_base(key)), "drawn base for spriteless item: " + key)

# ---------------- 生成的假货：破绽落点随物品变、同键同图 ----------------
func _gen_env(seed_v: int, fake_rate: float) -> Array:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/town_pack.json"))
	var templates = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/item_templates.json"))
	pack["balance"]["items"]["fake_rate"] = fake_rate
	return [pack, templates, {"seed": seed_v, "day": 3, "pressures": {}, "stock": []}]

func _auth_rect(item: Dictionary) -> Array:
	for p in item["parts"]:
		if str(p["id"]) == "authenticity":
			return p["rect"]
	return []

func _test_generated_placement() -> void:
	var env: Array = _gen_env(42, 1.0)
	var rects: Dictionary = {}
	var pics: Dictionary = {}
	var all_fake := true
	for k in 8:
		var item: Dictionary = Items.generate(env[1], env[0], env[2], ["probe", k], "rice")
		all_fake = all_fake and bool(item["fake"])
		var fl: Array = item.get("flaws", [])
		var has_fake_flaw := false
		for f in fl:
			if str(f["part"]) == "authenticity" and not bool(f.get("benign", false)) and bool(f.get("fine", false)):
				has_fake_flaw = true
				_check(Rect2i(int(_auth_rect(item)[0]), int(_auth_rect(item)[1]), int(_auth_rect(item)[2]), int(_auth_rect(item)[3])) == FlawRender.flaw_rect(item, f), "flaw sits on the authenticity part's rect")
		_check(has_fake_flaw, "generated fake carries a fine (magnifier) flaw")
		rects[str(_auth_rect(item))] = true
		var img: Image = FlawRender.hand_image(item, 0, true)
		pics[img.get_data().hex_encode().sha256_text()] = true
		var again: Dictionary = Items.generate(env[1], env[0], env[2], ["probe", k], "rice")
		_check(again == item and FlawRender.same_pixels(img, FlawRender.hand_image(again, 0, true)), "same key → same item, same flaw pixels")
		var ref_img: Image = FlawRender.load_sprite(str(Appraise.ref_entry(null, item)["sprite"]))
		var r: Array = _auth_rect(item)
		_check(FlawRender.region_differs(ref_img, img, Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))), "the fake's flaw shows under the magnifier vs the reference")
	_check(all_fake, "forced fake rate makes fakes")
	_check(rects.size() >= 2, "different items → different flaw placement (%d spots)" % rects.size())
	_check(pics.size() >= 2, "different items → different flaw pixels")
	var other: Array = _gen_env(43, 1.0)
	var moved := false
	for k in 8:
		var a: Dictionary = Items.generate(env[1], env[0], env[2], ["probe", k], "rice")
		var b: Dictionary = Items.generate(other[1], other[0], other[2], ["probe", k], "rice")
		if str(_auth_rect(a)) != str(_auth_rect(b)) or a.get("flaws", []) != b.get("flaws", []):
			moved = true
	_check(moved, "different world seed → different flaw choices")
	for cat in ["clothing", "jewelry", "utensils", "art", "medicine", "documents"]:
		var item2: Dictionary = Items.generate(env[1], env[0], env[2], ["probe_cat", cat], cat)
		var img2: Image = FlawRender.hand_image(item2, 0, true)
		var base2: Image = FlawRender.base_image(item2)
		_check(not item2.get("flaws", []).is_empty() and not FlawRender.same_pixels(img2, base2), "generated %s fake gets painted flaws" % cat)

# ---------------- 存档：生成的破绽随存档走 ----------------
func _test_save_round_trip() -> void:
	var pack = JSON.parse_string(FileAccess.get_file_as_string("res://data/town/town_pack.json"))
	pack["balance"]["items"]["fake_rate"] = 1.0
	var w = _world(19380306)
	var sim = Sim.new()
	sim.setup(pack, 19380306, w)
	var item: Dictionary = Items.generate(sim.templates, pack, sim.s, ["save_probe", 1], "jewelry")
	var iid: String = w.ledger.add_item(item, "stranger:fence#1", "counter")
	var pixels: Image = FlawRender.hand_image(w.ledger.items[iid], w.world_seed, true)
	var text := JSON.stringify(SaveState._encode_state({"ledger": SaveState.object_state_to_dict(w.ledger), "sim": sim.to_dict()}), "", true, true)
	var back: Dictionary = SaveState._decode_state(JSON.parse_string(text))
	var ledger2 = Ledger.new()
	SaveState.object_state_from_dict(ledger2, back["ledger"])
	var loaded: Dictionary = ledger2.items[iid]
	_check(loaded.get("flaws", []) == w.ledger.items[iid].get("flaws", []) and not loaded.get("flaws", []).is_empty(), "flaw choices survive save/load")
	_check(str(_auth_rect(loaded)) == str(_auth_rect(w.ledger.items[iid])), "part placement survives save/load")
	_check(FlawRender.same_pixels(pixels, FlawRender.hand_image(loaded, w.world_seed, true)), "the loaded item renders the same pixels")
	var sim2 = Sim.new()
	sim2.setup(pack, 19380306)
	sim2.from_dict(SaveState._encode_state(back["sim"], false))
	var regen: Dictionary = Items.generate(sim2.templates, pack, sim2.s, ["save_probe", 1], "jewelry")
	_check(regen.get("flaws", []) == item.get("flaws", []) and _auth_rect(regen) == _auth_rect(item), "the generator cache keeps the same flaws after load")
	sim.world = null
	w.town = null

# ---------------- 墨用完不卡死 ----------------
func _test_no_softlock() -> void:
	var w = _world()
	var s = _session(w, ["rice_sunji"], {"min_inspect": 3})
	var iid: String = s.item_ids[0]
	_check(s.needs_more_inspection(), "brother wants three looks")
	for i in 3:
		s.add_circle(iid, {"c": [60, 60], "r": 2, "kind": "miss", "pids": [], "text": "", "tone": "miss", "pts": []})
	_check(not s.needs_more_inspection(), "after the ink is spent the counter is not blocked")
	var s2 = _session(w, ["newspapers"], {"require": ["newspapers.weigh", "newspapers.flip"]})
	_check(s2.needs_more_inspection(), "required parts still asked for while ink remains")

# ---------------- Esc 先收验货 ----------------
func _test_esc_closes() -> void:
	var w = _world()
	var s = _session(w, ["rice_jing_a"])
	var p = await _panel()
	var closed := {"v": false}
	p.closed.connect(func(): closed["v"] = true)
	p.open(s)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	p._input(ev)
	_check(not p.visible and closed["v"], "Esc puts the item down (closes the inspect view first)")
	p.queue_free()
	await process_frame

# ---------------- 验货界面上的字都在字体里（不出豆腐块） ----------------
func _test_glyphs() -> void:
	var f: FontFile = load("res://fonts/NotoSerifSC-Regular-subset.otf")
	var missing := ""
	for path in ["res://scripts/ui/appraise_panel.gd", "res://scripts/core/appraise.gd", "res://scripts/sim/item_gen.gd"]:
		var txt := FileAccess.get_file_as_string(path)
		for i in range(txt.length()):
			var ch := txt.unicode_at(i)
			if ch >= 0x2E80 and not f.has_char(ch) and missing.find(char(ch)) < 0:
				missing += char(ch)
	_check(missing == "", "appraise UI text has every glyph in the body font" + ("" if missing == "" else "：缺 " + missing))
