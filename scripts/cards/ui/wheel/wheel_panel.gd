# 命运轮盘面板：本月运势、大轮盘、庙会、赌摊。扇区只按 arc_deg 从 12 点顺时针画，指针停在 stop_deg。
# 香案复用 CardSlotWidget；放上之后扇区动画变宽。界面不写数字、不写百分号、不按好坏上色。
# 主人 C06。合同：docs/cards/CARDS_INTERFACES.md §3.3 C06、§9.1、§9.2、§7.4、§7.8、§7.10.5。
# Reskin 10-22 (SPEC 10.6, web prototype): the wheel floats on the left (gold ring, alternating gold and
# cream sectors, red pointer, gold hub; sector colours alternate only, they never say good or bad) and a
# dark .modal side sheet on the right holds the title, the incense table, the cost and the buttons.
class_name CardWheelPanel
extends CardPanel

const ARC_TWEEN_SEC := 0.55
const SPIN_SLICE_SEC := 0.55
const SPIN_TURNS := 3
const OFFER_AMOUNT := 10
const FACE_PX := 480
const BOX_SIZE := Vector2(1080, 620)
const SIDE_POS := Vector2(520, 30)
const SIDE_SIZE := Vector2(552, 560)
const PAD := 34.0   # frame 14 + modal padding 20
const RING_R := 240.0   # outer edge of the gold ring (face 480; covers the wheel art's own rim)
const DISC_R := 214.0   # sector radius

# TODO(shared#fast_anim): C16 has not frozen a reader for the fast-animation
# switch (user://cards/settings.json). This bool is the local stand-in: true
# skips tweens and parks the wheel on stop_deg.
var fast_anim: bool = false

var _args: Dictionary = {}
var _uid: String = ""
var _wheel_id: String = ""
var _kind_name: String = ""
var _required: bool = false
var _built: bool = false
var _wheel: Dictionary = {}
var _placed: Array = []
var _placed_sig: String = ""
var _staked: String = ""
var _segment: String = ""
var _stop: float = 0.0
var _spun: bool = false
var _revealed: bool = false
var _spinning: bool = false
var _began: bool = false
var _closed: bool = false
var _did_offer: bool = false
var _did_stake: bool = false
var _did_spin: bool = false
var _jump_anim: bool = false
var _take_queued: bool = false
var _stake_queued: bool = false
var _seg_ids: PackedStringArray = PackedStringArray()
var _seg_arcs: PackedFloat32Array = PackedFloat32Array()
var _seg_from: PackedFloat32Array = PackedFloat32Array()
var _seg_to: PackedFloat32Array = PackedFloat32Array()
var _seg_nodes: Array = []
var _arc_tween: Tween
var _spin_tween: Tween

var _shade: ColorRect
var _box: Panel
var _side: Panel
var _reveal_box: PanelContainer
var _title: Label
var _face: Control
var _art: TextureRect
var _disc: WheelDisc
var _needle: WheelNeedle
var _cap: Label
var _incense: Control
var _slot: CardSlotWidget
var _sticks: StickPile
var _offer: Button
var _takes: HBoxContainer
var _cost: Control
var _cost_money: Label
var _stake_caption: Label
var _stakes: HBoxContainer
var _reveal_title: Label
var _reveal_body: Label
var _err: Label
var _spin_btn: Button
var _continue: Button
var _close: Button


func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void:
	super.bind(p_engine, p_bus)
	if p_bus == null:
		return
	_connect(p_bus.view_changed, _on_view_changed)
	_connect(p_bus.wheel_spun, _on_wheel_spun)
	_connect(p_bus.card_left, _on_card_left)


func open(args: Dictionary) -> void:
	_args = args.duplicate(true)
	_uid = str(_args.get("uid", ""))
	_required = bool(_args.get("required", false))
	if not _built:
		_build()
		_built = true
	_reset_run()
	if _slot != null:
		_slot.bus = bus
	_wheel_id = _resolve_wheel()
	if _wheel_id == "":
		_show_err("missing")
		_try_close.call_deferred()
		return
	_reload()
	_place_box()


func refresh(_view: Dictionary) -> void:
	if _wheel_id == "":
		return
	_reload()


## Every panel can be closed (contract 7.8; the old can_close() rule was voided). Closing an unspun
## month wheel leaves the month unspun; the engine spins it at day end. Kept for callers (b08).
func can_close() -> bool:
	return true


func autoplay_step() -> bool:
	if _closed or engine == null:
		return false
	_jump_anim = true
	if _wheel_id == "":
		_force_done()
	elif not _revealed:
		if not _auto_before():
			_force_done()
	else:
		_on_continue()
	_jump_anim = false
	return true


func _connect(sig: Signal, cb: Callable) -> void:
	if not sig.is_connected(cb):
		sig.connect(cb)


func _reset_run() -> void:
	_spun = false
	_revealed = false
	_spinning = false
	_began = false
	_closed = false
	_did_offer = false
	_did_stake = false
	_did_spin = false
	_jump_anim = false
	_segment = ""
	_stop = 0.0
	_staked = ""
	_placed = []
	_placed_sig = ""
	_wheel = {}
	_kill_tweens()
	if _face != null:
		_face.rotation = 0.0
		_face.pivot_offset = Vector2(FACE_PX, FACE_PX) * 0.5
	if _disc != null:
		_disc.selected = -1
		_disc.queue_redraw()
	if _reveal_title != null:
		_reveal_title.visible = false
		_reveal_body.visible = false
		_reveal_title.text = ""
		_reveal_body.text = ""
		_continue.visible = false
		_spin_btn.disabled = false
		_spin_btn.visible = true
		_close.visible = true
		_reveal_box.visible = false
		_show_err("")
		_layout_side()


func _kill_tweens() -> void:
	if _arc_tween != null and _arc_tween.is_valid():
		_arc_tween.kill()
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
	_arc_tween = null
	_spin_tween = null


func _resolve_wheel() -> String:
	var given := str(_args.get("wheel", ""))
	if given != "":
		return given
	if engine == null:
		return ""
	var cv: Dictionary = engine.query(&"card", {"uid": _uid})
	if str(cv.get("wheel", "")) != "":
		return str(cv.get("wheel", ""))
	if str(cv.get("opens_wheel", "")) != "":
		return str(cv.get("opens_wheel", ""))
	if str(cv.get("def", "")) == "bf.wheel":
		return "wh.big"
	return ""


func _on_view_changed(_topics: PackedStringArray) -> void:
	if _wheel_id == "":
		return
	_reload()


func _on_wheel_spun(wheel_id: String, segment_id: String, stop_deg: float) -> void:
	if wheel_id != _wheel_id:
		return
	_play_spin(segment_id, stop_deg)


func _on_card_left(uid: String, _reason: StringName) -> void:
	# 揭晓留在面板上，等“继续”。牌被引擎 resolve 时不自动收起。
	if uid != _uid or _uid == "":
		return


func _reload() -> void:
	if engine == null or _wheel_id == "":
		return
	var wv: Dictionary = engine.query(&"wheel", {"wheel": _wheel_id, "uid": _uid})
	if not wv.has("segments"):
		_show_err("missing")
		return
	_wheel = wv
	_kind_name = str(wv.get("kind", ""))
	if _kind_name == "":
		_kind_name = _wheel_id.trim_prefix("wh.")
	_apply_chrome()
	var inc: Dictionary = wv.get("incense", {})
	_take_placed(inc.get("placed", []) if typeof(inc.get("placed")) == TYPE_ARRAY else [])
	var staked := str(wv.get("staked", ""))
	if staked != "":
		_staked = staked
	_present_segments(wv.get("segments", []))
	_sync_incense()
	_fill_cost()
	if bool(wv.get("spun", false)) and not _spun:
		var res: Dictionary = wv.get("result", {})
		_play_spin(str(res.get("segment", "")), float(res.get("stop_deg", 0.0)))


func _take_placed(qp: Array) -> void:
	var sig := JSON.stringify(qp)
	if sig == _placed_sig:
		return
	_placed_sig = sig
	_placed = qp.duplicate(true)


func _present_segments(segs: Array) -> void:
	if typeof(segs) != TYPE_ARRAY:
		return
	if not _ids_match(segs):
		_build_seg_nodes(segs)
	var to := PackedFloat32Array()
	for s in segs:
		to.append(float((s as Dictionary).get("arc_deg", 0.0)))
	if _seg_arcs.size() != to.size():
		_snap_arcs(to)
		return
	var changed := false
	for i in to.size():
		if absf(float(to[i]) - float(_seg_arcs[i])) > 0.05:
			changed = true
	if not changed:
		return
	if fast_anim or _jump_anim or not is_inside_tree():
		_snap_arcs(to)
		return
	_seg_from = _seg_arcs.duplicate()
	_seg_to = to
	if _arc_tween != null and _arc_tween.is_valid():
		_arc_tween.kill()
	_arc_tween = create_tween()
	_arc_tween.tween_method(_on_arc_t, 0.0, 1.0, ARC_TWEEN_SEC).set_trans(Tween.TRANS_LINEAR)


func _ids_match(segs: Array) -> bool:
	if segs.size() != _seg_ids.size():
		return false
	for i in segs.size():
		if str((segs[i] as Dictionary).get("id", "")) != _seg_ids[i]:
			return false
	return true


func _snap_arcs(to: PackedFloat32Array) -> void:
	_seg_from = to.duplicate()
	_seg_to = to.duplicate()
	_seg_arcs = to.duplicate()
	_push_arcs()


func _on_arc_t(t: float) -> void:
	if _seg_from.size() != _seg_to.size():
		return
	_seg_arcs = PackedFloat32Array()
	for i in _seg_to.size():
		_seg_arcs.append(lerpf(float(_seg_from[i]), float(_seg_to[i]), t))
	_push_arcs()


func _push_arcs() -> void:
	for i in _seg_nodes.size():
		var arc := float(_seg_arcs[i]) if i < _seg_arcs.size() else 0.0
		(_seg_nodes[i] as Node).set_meta("arc_deg", arc)
	if _disc != null:
		_disc.arcs = _seg_arcs.duplicate()
		_disc.queue_redraw()
	_layout_segs()


func _layout_segs() -> void:
	var cursor := 0.0
	var center := Vector2(FACE_PX, FACE_PX) * 0.5
	for i in _seg_nodes.size():
		var sweep := float(_seg_arcs[i]) if i < _seg_arcs.size() else 0.0
		var mid := cursor + sweep * 0.5
		var rad := deg_to_rad(mid) - PI * 0.5
		var node := _seg_nodes[i] as Control
		var at := center + Vector2(cos(rad), sin(rad)) * 140.0
		node.position = at - node.size * 0.5
		cursor += sweep


func _build_seg_nodes(segs: Array) -> void:
	for n in _seg_nodes:
		if is_instance_valid(n):
			var node := n as Node
			if node.get_parent() != null:
				node.get_parent().remove_child(node)
			node.free()
	_seg_nodes = []
	_seg_ids = PackedStringArray()
	_seg_arcs = PackedFloat32Array()
	for i in segs.size():
		var seg: Dictionary = segs[i]
		var id := str(seg.get("id", ""))
		_seg_ids.append(id)
		var box := Control.new()
		box.name = "Seg%d" % i
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_meta("seg_id", id)
		box.set_meta("arc_deg", float(seg.get("arc_deg", 0.0)))
		var art_id := str(seg.get("art", ""))
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = CardArt.texture(art_id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var base := CardArt.base_size(art_id)
		if base.x <= 0 or base.y <= 0:
			base = Vector2i(16, 16)
		var shown := Vector2(base * 2)
		icon.custom_minimum_size = shown
		icon.size = shown
		icon.position = Vector2((120.0 - shown.x) * 0.5, 0.0)
		var lab := _label(_safe(CardText.card(id, "title"), "c06.segment.name"), 20, id + "#title")
		lab.add_theme_font_override("font", CardTheme.font_title())
		# Long names get a smaller brush size so they stay on one line (prototype: long sector names 20
		# against 24; QA 10-25: a 7-character name wrapped and lost its last character to the clip).
		var name_w := CardTheme.font_title().get_string_size(lab.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		if name_w > 120.0:
			lab.add_theme_font_size_override("font_size", maxi(14, floori(20.0 * 118.0 / name_w)))
		lab.add_theme_color_override("font_color", _ink(CardText.is_draft(id + "#title")))
		lab.position = Vector2(0, shown.y)
		lab.size = Vector2(120, 52)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.size = Vector2(120, shown.y + 52.0)
		box.add_child(icon)
		box.add_child(lab)
		_face.add_child(box)
		_seg_nodes.append(box)


func _apply_chrome() -> void:
	var big := _kind_name == "big"
	var key := _title_key()
	_title.text = CardText.ui(key)
	_title.add_theme_color_override("font_color", _side_ink(CardText.is_draft(key), true))
	var art_id := str(_wheel.get("art", ""))
	if art_id == "":
		art_id = "wheel." + _kind_name
	_art.texture = CardArt.texture(art_id)
	var fills: Array = []
	for i in 3:
		fills.append(_sector_color(i))
	_disc.fills = fills
	_disc.ring = CardTheme.color(&"gold_pale")
	_disc.rim = CardTheme.color(&"title_shadow")
	_disc.rim_gold = CardTheme.color(&"seal_dark" if big else &"gold_deep")
	_disc.edge = CardTheme.with_alpha(&"ink", 0.55)
	_disc.hub_hi = CardTheme.color(&"gold_hi")
	_disc.hub_lo = CardTheme.color(&"gold_deep")
	_disc.queue_redraw()
	_needle.tint = CardTheme.color(&"seal")
	_needle.shade = CardTheme.with_alpha(&"card_shadow", 0.5)
	_needle.queue_redraw()
	_sticks.tint = CardTheme.color(&"gold_deep")
	_sticks.tip = CardTheme.color(&"seal")
	_sticks.queue_redraw()
	if _cap != null:
		_cap.add_theme_color_override("font_color", _side_ink(CardText.is_draft("c06.incense.title"), true))
	if _stake_caption != null:
		_stake_caption.add_theme_color_override("font_color", _side_ink(CardText.is_draft("c06.cost.stake")))


## Sector fills alternate (prototype gold / cream; the big wheel dark red / red). They carry no meaning:
## the view has no good or bad (contract 9.1). Index 2 is the odd last sector next to the first.
func _sector_color(i: int) -> Color:
	var keys: Array = [&"wheel_good_a", &"wheel_mid_a", &"wheel_good_b"]
	if _kind_name == "big":
		keys = [&"wheel_bad_a", &"wheel_bad_b", &"wheel_mid_b"]
	return CardTheme.color(keys[clampi(i, 0, 2)])


func _title_key() -> String:
	if ["month", "big", "fair", "gamble"].has(_kind_name):
		return "c06.title." + _kind_name
	return "c06.title.month"


## Ink for text drawn on the sectors.
func _ink(draft: bool) -> Color:
	if _kind_name == "big":
		return CardTheme.color(&"paper_old" if draft else &"card_band_ink")
	return CardTheme.color(&"ink_soft" if draft else &"ink")


## Ink for text on the dark side sheet; headings gold.
func _side_ink(draft: bool, heading: bool = false) -> Color:
	if draft:
		return CardTheme.color(&"text_3")
	return CardTheme.color(&"gold_hi" if heading else &"hud_ink")


func _sync_incense() -> void:
	if _slot == null:
		return
	_slot.set_slot(_uid, {
		"id": "incense",
		"accepts": _accepts(),
		"placed": _placed.duplicate(true),
	})
	_scrub(_slot)
	_layout_incense()
	_sticks.sticks = _stick_count()
	_sticks.queue_redraw()
	if not _take_queued:
		_take_queued = true
		_rebuild_takes.call_deferred()


func _rebuild_takes() -> void:
	_take_queued = false
	if _takes == null:
		return
	for c in _takes.get_children():
		c.free()
	for i in _placed.size():
		var b := _button("c06.incense.take")
		b.name = "Take"
		b.set_meta("index", i)
		b.pressed.connect(_withdraw.bind(i))
		_takes.add_child(b)


func _fill_cost() -> void:
	var cost: Dictionary = _wheel.get("cost", {})
	var money := int(cost.get("money", 0))
	_cost_money.visible = money > 0
	if money > 0:
		_cost_money.text = CardText.ui("c06.cost.money", {"n": money})
		var draft := CardText.is_draft("c06.cost.money")
		_cost_money.add_theme_color_override("font_color", _side_ink(draft))
	_stake_caption.visible = _needs_stake()
	if _needs_stake():
		_stake_caption.text = CardText.ui("c06.cost.stake")
	_layout_side()
	if not _stake_queued:
		_stake_queued = true
		_rebuild_stakes.call_deferred()


func _rebuild_stakes() -> void:
	_stake_queued = false
	if _stakes == null:
		return
	for c in _stakes.get_children():
		c.free()
	if not _needs_stake() or engine == null:
		return
	var kept: Array = engine.view().get("kept", [])
	for row in kept:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var uid := str(row.get("uid", ""))
		var title := CardText.card(str(row.get("def", "")), "title")
		if title == "" or _leaks_text(title):
			title = CardText.ui("c06.stake.pick")
		var b := _button_text(title)
		b.name = "Stake"
		b.set_meta("kept_uid", uid)
		b.disabled = _staked == uid
		b.pressed.connect(_stake_uid.bind(uid))
		_stakes.add_child(b)


func _stick_count() -> int:
	var n := 0
	for p in _placed:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		if str(p.get("kind", "")) == "money":
			n += mini(maxi(int(p.get("amount", 0)), 1), 12)
		else:
			n += 1
	return n


func _accepts() -> Array:
	var inc: Dictionary = _wheel.get("incense", {})
	var acc = inc.get("accepts", [])
	return acc if typeof(acc) == TYPE_ARRAY else []


func _needs_stake() -> bool:
	return bool((_wheel.get("cost", {}) as Dictionary).get("stake", false))


func _on_slot_remove(_slot_id: String, index: int) -> void:
	_withdraw(index)


func _on_place(_slot_id: String, source: Dictionary) -> void:
	if engine == null or _wheel_id == "" or _revealed:
		return
	var before := _placed_sig
	var r := engine.send(&"wheel.offer", {
		"wheel": _wheel_id, "uid": _uid, "source": source.duplicate(true)})
	if _placed_sig != before:
		_sync_incense()
		return
	if bool(r.get("ok", false)):
		_placed.append(source.duplicate(true))
		_sync_incense()
	else:
		_show_err(str(r.get("err", "")))


func _offer_bundle() -> void:
	_on_place("incense", {"kind": "money", "amount": OFFER_AMOUNT})


func _withdraw(index: int) -> void:
	if engine == null or _wheel_id == "" or _revealed:
		return
	var before := _placed_sig
	var r := engine.send(&"wheel.withdraw", {"wheel": _wheel_id, "uid": _uid, "index": index})
	if _placed_sig != before:
		_sync_incense()
		return
	if bool(r.get("ok", false)) and index >= 0 and index < _placed.size():
		_placed.remove_at(index)
		_sync_incense()
	elif not bool(r.get("ok", false)):
		_show_err(str(r.get("err", "")))


func _stake_uid(kept_uid: String) -> void:
	if engine == null or _wheel_id == "" or _revealed or kept_uid == "":
		return
	var r := engine.send(&"wheel.stake", {"wheel": _wheel_id, "uid": _uid, "kept_uid": kept_uid})
	if bool(r.get("ok", false)):
		_staked = kept_uid
		_show_err("")
		_fill_cost()
	else:
		_show_err(str(r.get("err", "")))


func _spin() -> void:
	if engine == null or _wheel_id == "" or _revealed or _spinning:
		return
	var r := engine.send(&"wheel.spin", {"wheel": _wheel_id, "uid": _uid})
	if not bool(r.get("ok", false)):
		_show_err(str(r.get("err", "")))
		return
	_play_spin(str(r.get("segment", "")), float(r.get("stop_deg", 0.0)))


func _play_spin(segment_id: String, stop_deg: float) -> void:
	if segment_id == "":
		return
	if _same_stop(segment_id, stop_deg) and (_revealed or _spinning):
		return
	_segment = segment_id
	_stop = stop_deg
	_spun = true
	_show_err("")
	if _spin_tween != null and _spin_tween.is_valid():
		_spin_tween.kill()
		_spin_tween = null
	if fast_anim or _jump_anim or not is_inside_tree():
		_finish_spin()
		return
	_spinning = true
	_spin_btn.disabled = true
	_begin_spin_tween()


func _same_stop(segment_id: String, stop_deg: float) -> bool:
	return segment_id == _segment and absf(stop_deg - _stop) < 0.01


func _begin_spin_tween() -> void:
	var end_rad := -deg_to_rad(_stop)
	var total := end_rad - deg_to_rad(360.0 * float(SPIN_TURNS))
	var start := _face.rotation
	var delta := total - start
	var n := SPIN_TURNS + 1
	_face.pivot_offset = _face.size * 0.5
	_spin_tween = create_tween()
	for i in n:
		var dest := start + delta * float(i + 1) / float(n)
		var step := _spin_tween.tween_property(_face, "rotation", dest, SPIN_SLICE_SEC)
		step.set_trans(Tween.TRANS_QUAD)
		step.set_ease(Tween.EASE_OUT if i == n - 1 else Tween.EASE_IN_OUT)
	_spin_tween.tween_callback(_finish_spin)


func _finish_spin() -> void:
	_spinning = false
	if _face != null:
		_face.pivot_offset = _face.size * 0.5
		_face.rotation = -deg_to_rad(_stop)
	_revealed = true
	if _disc != null:
		_disc.selected = _index_of(_segment)
		_disc.queue_redraw()
	_reveal_title.text = _safe(CardText.card(_segment, "title"), "c06.segment.name")
	_reveal_body.text = _safe(CardText.card(_segment, "body"), "c06.segment.body")
	_reveal_title.add_theme_color_override("font_color", _side_ink(CardText.is_draft(_segment + "#title"), true))
	_reveal_body.add_theme_color_override("font_color", _side_ink(CardText.is_draft(_segment + "#body")))
	_reveal_title.visible = true
	_reveal_body.visible = true
	_reveal_box.visible = true
	_continue.visible = true
	_spin_btn.disabled = true
	# After the reveal "continue" is the only way on; the old "close" next to it did the same thing (b08).
	_spin_btn.visible = false
	_close.visible = false
	_show_err("")
	_layout_side()


func _index_of(id: String) -> int:
	for i in _seg_ids.size():
		if _seg_ids[i] == id:
			return i
	return -1


func _on_continue() -> void:
	if not _revealed:
		return
	_try_close()


func _try_close() -> void:
	if not can_close():
		return
	if _wheel_id == "wh.month" and _revealed and not _began:
		_began = true
		if engine != null:
			engine.send(&"month.begin", {})
	_closed = true
	close_requested.emit({})


func _force_done() -> void:
	if _closed:
		return
	if can_close():
		_try_close()
	else:
		_closed = true


func _auto_before() -> bool:
	if _accepts().has("money") and _placed.is_empty() and not _did_offer:
		_did_offer = true
		_offer_bundle()
		return true
	if _needs_stake() and _staked == "" and not _did_stake:
		_did_stake = true
		var kept: Array = engine.view().get("kept", [])
		if not kept.is_empty() and typeof(kept[0]) == TYPE_DICTIONARY:
			_stake_uid(str(kept[0].get("uid", "")))
			return true
	if not _did_spin:
		_did_spin = true
		_spin()
		return true
	return false


func _show_err(code: String) -> void:
	if _err == null:
		return
	if code == "":
		_err.text = ""
		_err.visible = false
		_layout_side()
		return
	var key := "c06.err.missing"
	if ["stake_required", "insufficient_money", "missing"].has(code):
		key = "c06.err." + code
	_err.text = CardText.ui(key)
	_err.visible = true
	_layout_side()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	if (event as InputEventKey).echo or not _built:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_try_close()
	elif key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		if _revealed:
			_on_continue()
		else:
			_spin()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _built:
		_place_box()


## Centre the box in the panel's own space. The host pins the panel at CardLayout.OVERLAY_MAX (90, 40),
## so centring against the viewport put it 100 px right of centre and over the right tabs (b09).
func _place_box() -> void:
	_box.size = BOX_SIZE
	if size.x >= BOX_SIZE.x and size.y >= BOX_SIZE.y:
		_box.position = ((size - BOX_SIZE) * 0.5).round()
		return
	var origin := get_global_transform_with_canvas().origin if is_inside_tree() else position
	_box.position = ((Vector2(1280, 720) - BOX_SIZE) * 0.5).round() - origin


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	# The modal host already dims the table (meta "shade"); a second shade would darken a box over it.
	_shade.color = Color.TRANSPARENT if has_meta("shade") else CardTheme.color(&"shade")
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_box = Panel.new()
	_box.name = "Box"
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.size = BOX_SIZE
	_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_box)
	_build_face()
	_build_side()
	_register_anchors()
	_wire_focus()


func _build_face() -> void:
	_face = Control.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.position = Vector2(16, 70)
	_face.size = Vector2(FACE_PX, FACE_PX)
	_face.pivot_offset = Vector2(FACE_PX, FACE_PX) * 0.5
	_box.add_child(_face)
	_art = TextureRect.new()
	_art.name = "WheelArt"
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.position = Vector2.ZERO
	_art.size = Vector2(FACE_PX, FACE_PX)
	_face.add_child(_art)
	_disc = WheelDisc.new()
	_disc.name = "Disc"
	_disc.position = Vector2.ZERO
	_disc.size = Vector2(FACE_PX, FACE_PX)
	_face.add_child(_disc)
	_needle = WheelNeedle.new()
	_needle.name = "Needle"
	_needle.size = Vector2(32, 40)
	_needle.position = _face.position + Vector2(FACE_PX * 0.5 - 16.0, FACE_PX * 0.5 - RING_R - 10.0)
	_needle.z_index = 2
	_box.add_child(_needle)


func _build_side() -> void:
	_side = Panel.new()
	_side.name = "Side"
	_side.mouse_filter = Control.MOUSE_FILTER_STOP
	_side.position = SIDE_POS
	_side.size = SIDE_SIZE
	_side.add_theme_stylebox_override("panel", CardTheme.modal_style())
	_box.add_child(_side)
	var w := SIDE_SIZE.x - PAD * 2.0
	_title = _label("", 28, "c06.title.month")
	_title.name = "Title"
	_title.add_theme_font_override("font", CardTheme.font_title())
	_title.position = Vector2(PAD, PAD - 6.0)
	_title.size = Vector2(w, 42)
	_side.add_child(_title)
	_cap = _label(CardText.ui("c06.incense.title"), 20, "c06.incense.title")
	_cap.add_theme_font_override("font", CardTheme.font_title())
	_cap.position = Vector2(PAD, 82)
	_cap.size = Vector2(w, 34)
	_side.add_child(_cap)
	_incense = Control.new()
	_incense.name = "Incense"
	_incense.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incense.position = Vector2(PAD, 114)
	_incense.size = Vector2(w, 136)
	_side.add_child(_incense)
	_slot = CardSlotWidget.new()
	_slot.name = "IncenseSlot"
	_slot.position = Vector2(0, 4)
	_incense.add_child(_slot)
	_slot.place_requested.connect(_on_place)
	_slot.remove_requested.connect(_on_slot_remove)
	_sticks = StickPile.new()
	_sticks.name = "Sticks"
	_sticks.size = Vector2(130, 60)
	_incense.add_child(_sticks)
	_offer = _button("c06.incense.offer")
	_offer.name = "Offer"
	_incense.add_child(_offer)
	_offer.pressed.connect(_offer_bundle)
	_takes = HBoxContainer.new()
	_takes.name = "Takes"
	_takes.size = Vector2(150, 44)
	_takes.add_theme_constant_override("separation", 6)
	_incense.add_child(_takes)
	_layout_incense()
	_cost = Control.new()
	_cost.name = "Cost"
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost.position = Vector2(PAD, 262)
	_cost.size = Vector2(w, 116)
	_side.add_child(_cost)
	_cost_money = _label("", 16, "c06.cost.money")
	_cost_money.name = "CostMoney"
	_cost_money.position = Vector2(0, 0)
	_cost_money.size = Vector2(w, 28)
	_cost_money.visible = false
	_cost.add_child(_cost_money)
	_stake_caption = _label("", 16, "c06.cost.stake")
	_stake_caption.position = Vector2(0, 30)
	_stake_caption.size = Vector2(w, 28)
	_stake_caption.visible = false
	_cost.add_child(_stake_caption)
	_stakes = HBoxContainer.new()
	_stakes.name = "Stakes"
	_stakes.position = Vector2(0, 62)
	_stakes.size = Vector2(w, 48)
	_stakes.add_theme_constant_override("separation", 8)
	_cost.add_child(_stakes)
	# Result: the prototype's gold-barred note (row_note_style gold, 4 px).
	_reveal_box = PanelContainer.new()
	_reveal_box.name = "RevealBox"
	_reveal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal_box.position = Vector2(PAD, 384)
	_reveal_box.size = Vector2(w, 92)
	_reveal_box.custom_minimum_size = Vector2(w, 92)
	var note := CardTheme.row_note_style(&"gold_hi", 4)
	note.bg_color = CardTheme.with_alpha(&"gold_hi", 0.14)
	_reveal_box.add_theme_stylebox_override("panel", note)
	_reveal_box.visible = false
	_side.add_child(_reveal_box)
	var reveal_col := VBoxContainer.new()
	reveal_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal_col.add_theme_constant_override("separation", 2)
	_reveal_box.add_child(reveal_col)
	_reveal_title = _label("", 20, "")
	_reveal_title.name = "RevealTitle"
	_reveal_title.add_theme_font_override("font", CardTheme.font_title())
	_reveal_title.custom_minimum_size = Vector2(w - 30.0, 34)
	_reveal_title.clip_text = false
	_reveal_title.visible = false
	reveal_col.add_child(_reveal_title)
	_reveal_body = _label("", 16, "")
	_reveal_body.name = "RevealBody"
	_reveal_body.custom_minimum_size = Vector2(w - 30.0, 44)
	_reveal_body.clip_text = false
	_reveal_body.visible = false
	reveal_col.add_child(_reveal_body)
	_err = _label("", 16, "c06.err.missing")
	_err.name = "Err"
	_err.position = Vector2(PAD, 384)
	_err.size = Vector2(w, 80)
	_err.visible = false
	_err.add_theme_color_override("font_color", CardTheme.color(&"bad"))
	_side.add_child(_err)
	var row_y := SIDE_SIZE.y - PAD - 44.0
	_spin_btn = _button("c06.btn.spin")
	_spin_btn.name = "Spin"
	_spin_btn.theme_type_variation = &"PrimaryButton"
	_spin_btn.position = Vector2(PAD, row_y)
	_side.add_child(_spin_btn)
	_spin_btn.pressed.connect(_spin)
	_continue = _button("c06.btn.continue")
	_continue.name = "Continue"
	_continue.theme_type_variation = &"PrimaryButton"
	_continue.position = Vector2(PAD, row_y)
	_continue.visible = false
	_side.add_child(_continue)
	_continue.pressed.connect(_on_continue)
	_close = _button("c06.btn.close")
	_close.name = "Close"
	_close.position = Vector2(PAD + _spin_btn.size.x + 12.0, row_y)
	_side.add_child(_close)
	_close.pressed.connect(_try_close)
	_layout_side()


## Side sheet as tall as what it shows, centred on the wheel: title; before the reveal the incense table,
## the cost (only when the wheel has one) and an error line; after it the gold-barred result; then buttons.
func _layout_side() -> void:
	if _side == null or _reveal_box == null or _spin_btn == null:
		return
	var y := PAD + 50.0
	var before := not _revealed
	_cap.visible = before
	_incense.visible = before
	var has_cost := before and (_cost_money.visible or _stake_caption.visible)
	# The cost block stays (guide anchor a.wheel.cost); without a cost it is a 1 px strip taking no room.
	_cost.visible = before
	_cost.size.y = 116.0 if has_cost else 1.0
	if before:
		_cap.position.y = y
		y += 36.0
		_incense.position.y = y
		y += _incense.size.y + 14.0
		_cost.position.y = y
		if has_cost:
			y += _cost.size.y + 6.0
	else:
		_reveal_box.position.y = y
		y += _reveal_box.size.y + 16.0
	if _err.visible:
		_err.position.y = y
		_err.size.y = 52.0
		y += 56.0
	for b in [_spin_btn, _continue, _close]:
		(b as Control).position.y = y
	var h := y + 44.0 + PAD
	_side.size = Vector2(SIDE_SIZE.x, h)
	_side.position = Vector2(SIDE_POS.x, round((BOX_SIZE.y - h) * 0.5))


## Sticks and the offer button sit right of the incense slot, read from the slot's real size (b10: they used
## to start at x 136 over a 160-wide slot and cover its drop corner).
func _layout_incense() -> void:
	if _slot == null or _sticks == null:
		return
	var slot_sz := _slot.get_combined_minimum_size()
	slot_sz.x = maxf(slot_sz.x, _slot.size.x)
	slot_sz.y = maxf(slot_sz.y, _slot.size.y)
	var x := _slot.position.x + slot_sz.x + 12.0
	_sticks.position = Vector2(x, 4)
	_offer.position = Vector2(x, 70)
	_takes.position = Vector2(x + _offer.size.x + 10.0, 70)
	_incense.size.y = maxf(_slot.position.y + slot_sz.y, 116.0)


func _register_anchors() -> void:
	CardAnchors.register(&"a.wheel.face", _face)
	CardAnchors.register(&"a.wheel.incense", _incense)
	CardAnchors.register(&"a.wheel.cost", _cost)
	CardAnchors.register(&"a.wheel.spin", _spin_btn)


func _wire_focus() -> void:
	for b in [_offer, _slot, _spin_btn, _continue, _close]:
		b.focus_mode = Control.FOCUS_ALL
	_offer.focus_next = _offer.get_path_to(_slot)
	_offer.focus_neighbor_bottom = _offer.focus_next
	_slot.focus_next = _slot.get_path_to(_spin_btn)
	_slot.focus_neighbor_bottom = _slot.focus_next
	_spin_btn.focus_next = _spin_btn.get_path_to(_continue)
	_spin_btn.focus_neighbor_top = _spin_btn.get_path_to(_slot)
	_spin_btn.focus_neighbor_right = _spin_btn.focus_next
	_continue.focus_next = _continue.get_path_to(_close)
	_continue.focus_neighbor_left = _continue.get_path_to(_spin_btn)
	_close.focus_next = _close.get_path_to(_offer)


func _label(text: String, size: int, draft_ref: String) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.clip_text = true
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab.add_theme_font_override("font", CardTheme.font_body())
	lab.add_theme_font_size_override("font_size", maxi(size, 14))
	var draft := draft_ref != "" and CardText.is_draft(draft_ref)
	lab.add_theme_color_override("font_color", _side_ink(draft))
	return lab


func _button(key: String) -> Button:
	return _button_text(CardText.ui(key))


## Wood button from the card theme (primary set by the caller).
func _button_text(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.custom_minimum_size = Vector2(130, 40)
	b.size = Vector2(140, 42)
	b.focus_mode = Control.FOCUS_ALL
	return b


func _safe(text: String, fallback_key: String) -> String:
	if text != "" and not _leaks_text(text):
		return text
	var fb := CardText.ui(fallback_key)
	if _leaks_text(fb):
		return ""
	return fb


func _leaks_text(text: String) -> bool:
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 37 or (c >= 48 and c <= 57):
			return true
	return false


func _scrub(n: Node) -> void:
	if n is Label and _leaks_text((n as Label).text):
		(n as Label).text = ""
	for c in n.get_children():
		_scrub(c)


class WheelDisc extends Control:
	var arcs: PackedFloat32Array = PackedFloat32Array()
	var fills: Array = []
	var ring: Color = Color.WHITE
	var rim: Color = Color.WHITE
	var rim_gold: Color = Color.WHITE
	var edge: Color = Color.WHITE
	var hub_hi: Color = Color.WHITE
	var hub_lo: Color = Color.WHITE
	var selected: int = -1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		fills = [CardTheme.color(&"wheel_good_a"), CardTheme.color(&"wheel_mid_a"), CardTheme.color(&"wheel_good_b")]
		ring = CardTheme.color(&"gold_pale")
		rim = CardTheme.color(&"title_shadow")
		rim_gold = CardTheme.color(&"gold_deep")
		edge = CardTheme.with_alpha(&"ink", 0.55)
		hub_hi = CardTheme.color(&"gold_hi")
		hub_lo = CardTheme.color(&"gold_deep")

	func _draw() -> void:
		if size.x < 2.0:
			return
		var center := size * 0.5
		var k := minf(size.x, size.y) / float(CardWheelPanel.FACE_PX)
		var radius := CardWheelPanel.DISC_R * k
		var outer := CardWheelPanel.RING_R * k
		# Prototype ring: an 8 px dark rim outside an 11 px gold band.
		draw_circle(center, outer, rim)
		draw_circle(center, outer - 8.0 * k, rim_gold)
		draw_circle(center, radius + 2.0 * k, rim)
		if arcs.is_empty():
			_hub(center, k)
			return
		var n := arcs.size()
		var cursor := 0.0
		for i in n:
			var sweep := float(arcs[i])
			if sweep > 0.01:
				_fan(center, radius, cursor, sweep, _fill(i, n))
			cursor += sweep
		cursor = 0.0
		for i in n:
			draw_line(center, center + _at(cursor, radius), edge, 1.5, true)
			cursor += float(arcs[i])
		if selected >= 0 and selected < n:
			var start := 0.0
			for i in selected:
				start += float(arcs[i])
			_outline(center, radius - 2.0, start, float(arcs[selected]))
		_hub(center, k)

	func _fill(i: int, n: int) -> Color:
		if fills.size() < 3:
			return Color.WHITE
		if n > 1 and n % 2 == 1 and i == n - 1:
			return fills[2]
		return fills[i % 2]

	func _hub(center: Vector2, k: float) -> void:
		draw_circle(center, 31.0 * k, rim)
		draw_circle(center, 28.0 * k, hub_lo)
		draw_circle(center - Vector2(4, 5) * k, 19.0 * k, hub_hi)

	func _fan(center: Vector2, radius: float, cursor: float, sweep: float, fill: Color) -> void:
		var steps := clampi(int(sweep / 4.0), 2, 48)
		var pts := PackedVector2Array()
		pts.append(center)
		for s in steps + 1:
			pts.append(center + _at(cursor + sweep * float(s) / float(steps), radius))
		draw_colored_polygon(pts, fill)

	func _outline(center: Vector2, radius: float, cursor: float, sweep: float) -> void:
		var steps := clampi(int(sweep / 4.0), 2, 48)
		var pts := PackedVector2Array()
		pts.append(center)
		for s in steps + 1:
			pts.append(center + _at(cursor + sweep * float(s) / float(steps), radius))
		pts.append(center)
		draw_polyline(pts, ring, 4.0, true)

	func _at(deg: float, radius: float) -> Vector2:
		var rad := deg_to_rad(deg) - PI * 0.5
		return Vector2(cos(rad), sin(rad)) * radius


class WheelNeedle extends Control:
	var tint: Color = Color.WHITE
	var shade: Color = Color.TRANSPARENT

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint = CardTheme.color(&"seal")

	func _draw() -> void:
		var mid := size.x * 0.5
		var tri := PackedVector2Array([Vector2(mid, size.y), Vector2(1.0, 2.0), Vector2(size.x - 1.0, 2.0)])
		var drop := PackedVector2Array()
		for p in tri:
			drop.append(p + Vector2(0, 3))
		draw_colored_polygon(drop, shade)
		draw_colored_polygon(tri, tint)


class StickPile extends Control:
	var sticks: int = 0
	var tint: Color = Color.WHITE
	var tip: Color = Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint = CardTheme.color(&"gold_deep")
		tip = CardTheme.color(&"seal")

	func _draw() -> void:
		var n := mini(sticks, 12)
		for i in n:
			var x := 6.0 + float(i) * 10.0
			draw_line(Vector2(x, 10.0), Vector2(x + 2.0, size.y - 4.0), tint, 3.0)
			draw_rect(Rect2(x - 1.5, 4.0, 4.0, 6.0), tip)
