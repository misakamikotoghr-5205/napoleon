# Rogue v1: the relics standing in the scene's curio shelf (the curio hotspot's prop.curio is the empty shelf).
# The first six held relics, in the order they were taken, each 32x32 art x2 in CardLayout.curio_cell(i), nearest
# filter. Resting relics (shop lost / jailed) are dimmed with ink_soft; at night they take night_tint; a relic that
# just arrived flashes gold once (0.3 s, never with fast animations). Never takes the mouse: clicks fall through to
# the curio hotspot under it. Hidden whenever that hotspot is hidden (street, prison), and dimmed with it while a
# panel locks the tools (the hotspot redraws when it is locked or freed). No hover words. While an offer waits to be
# picked (view.stock.open, e.g. after "later"), a gold frame lies around the shelf, even an empty one: that is where
# the drawer's "one left to pick" button is.
# CardStage builds it after its hotspot loop and calls refresh(view, hotspot_visible, fast). No class_name.
# Owner RG4. Contract: docs/cards/rogue/ROGUE_V1.md sections 4.8, 7.4, 9, 12.
extends Control

const Ui = preload("res://scripts/cards/ui/rogue/rogue_ui.gd")

const CELLS := 6
const FLASH_S := 0.3
const FLASH_ALPHA := 0.75

var _hotspot: Control = null
var _shown: bool = false
var _ids: PackedStringArray = PackedStringArray()
var _seen_data: bool = false
var _flashes: int = 0
var _sig: String = ""
var _tint_now: Color = Color.WHITE
var _pending: bool = false
var _mark: Panel = null


func _init() -> void:
	name = "CurioShelf"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	visible = false


## Keep in step with the curio hotspot: whenever the stage hides it (street, prison sets, a play's set),
## the relics go with it.
func follow(hotspot: Control) -> void:
	_hotspot = hotspot
	if hotspot != null and not hotspot.visibility_changed.is_connected(_sync_visible):
		hotspot.visibility_changed.connect(_sync_visible)
	if hotspot != null and not hotspot.draw.is_connected(_match_hotspot):
		hotspot.draw.connect(_match_hotspot)


## view.relics.held -> cells; hotspot_visible: the curio hotspot is up; fast: no flash.
func refresh(view: Dictionary, hotspot_visible: bool, fast: bool) -> void:
	var relics := Ui.dict(view.get("relics", {}))
	var held := Ui.array(relics.get("held", []))
	var ids := PackedStringArray()
	var arts: Array = []
	for row in held:
		if typeof(row) != TYPE_DICTIONARY or str(row.get("id", "")) == "":
			continue
		if ids.size() >= CELLS:
			break
		ids.append(str(row["id"]))
		arts.append(str(row.get("art", "")))
	var fresh := PackedStringArray()
	if _seen_data:
		for id in ids:
			if not _ids.has(id):
				fresh.append(id)
	_seen_data = _seen_data or not relics.is_empty()
	_ids = ids
	var sig := ",".join(ids) + "|" + ",".join(PackedStringArray(arts))
	if sig != _sig:
		_sig = sig
		_rebuild(ids, arts)
	_tint_now = _tint(view, bool(relics.get("dormant", false)))
	_set_pending(str(Ui.dict(view.get("stock", {})).get("open", "")) != "")
	_match_hotspot()
	_shown = hotspot_visible
	_sync_visible()
	if not fast and is_inside_tree() and visible:
		for id in fresh:
			_flash(ids.find(id))


func ids() -> PackedStringArray:
	return _ids


## Cells on screen (CardLayout.curio_cell), in held order.
func cell_rects() -> Array:
	var out: Array = []
	for child in get_children():
		if child is TextureRect and child.has_meta("item"):
			out.append(Rect2((child as Control).position, (child as Control).size))
	return out


func flashes() -> int:
	return _flashes


## The gold frame shown while an offer waits (tests).
func pending_mark() -> Control:
	return _mark if _pending else null


## Own tint (resting / night) times the hotspot's (ink_soft while a panel locks the tools).
func _match_hotspot() -> void:
	var dim := _hotspot.modulate if _hotspot != null else Color.WHITE
	modulate = _tint_now * dim


func _sync_visible() -> void:
	var hot := _hotspot == null or _hotspot.visible
	visible = _shown and hot and (not _ids.is_empty() or _pending)


func _set_pending(on: bool) -> void:
	_pending = on
	if on and _mark == null:
		_mark = Panel.new()
		_mark.name = "Pending"
		_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mark.position = CardLayout.CURIO.position - Vector2(4, 4)
		_mark.size = CardLayout.CURIO.size + Vector2(8, 8)
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = CardTheme.color(&"gold_hi")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(4)
		sb.shadow_color = CardTheme.with_alpha(&"gold_glow", 0.6)
		sb.shadow_size = 10
		_mark.add_theme_stylebox_override("panel", sb)
		add_child(_mark)
	if _mark != null:
		_mark.visible = on


func _rebuild(ids: PackedStringArray, arts: Array) -> void:
	for child in get_children():
		if child is TextureRect:
			remove_child(child)
			child.queue_free()
	for i in ids.size():
		var cell := CardLayout.curio_cell(i)
		var pic := Ui.art(str(arts[i]), cell.size)
		pic.name = "Cell%d" % i
		pic.set_meta("item", ids[i])
		pic.position = cell.position
		add_child(pic)


func _tint(view: Dictionary, dormant: bool) -> Color:
	if dormant:
		return CardTheme.color(&"ink_soft")
	var stage := Ui.dict(view.get("stage", {}))
	if str(stage.get("time", "")) == "night":
		return CardTheme.color(&"night_tint")
	return Color.WHITE


## A gold square over the new cell, fading out in 0.3 s.
func _flash(i: int) -> void:
	if i < 0 or i >= CELLS:
		return
	var cell := CardLayout.curio_cell(i)
	var glow := ColorRect.new()
	glow.name = "Flash%d" % i
	glow.color = CardTheme.with_alpha(&"gold", FLASH_ALPHA)
	glow.position = cell.position
	glow.size = cell.size
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	_flashes += 1
	var tw := glow.create_tween()
	tw.tween_property(glow, "modulate:a", 0.0, FLASH_S)
	tw.tween_callback(glow.queue_free)
