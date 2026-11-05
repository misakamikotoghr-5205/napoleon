# Night and settle borrow the stage, dialog, hand, and checks.
# C01 injects them with bind_stage before open. Until that host lands, use the W0 stubs.
# ensure() returns which widgets this panel spawned so release() can free only those.
# Night/settle skip checks unless already bound — neither panel uses the coin tray.
# No class_name. Owner C08.
extends RefCounted


## Fill panel.stage/dialog/hand (and checks only if already set or need_checks).
## Returns {stage|dialog|checks|hand: bool} for owned spawns.
static func ensure(panel: CardStagePanel, bus: CardEventBus, need_checks: bool = false) -> Dictionary:
	var owned := {"stage": false, "dialog": false, "checks": false, "hand": false}
	if panel.stage == null:
		panel.stage = _find(panel, CardStageApi) as CardStageApi
	if panel.stage == null:
		panel.stage = _spawn(panel, &"stage") as CardStageApi
		owned["stage"] = panel.stage != null
	if panel.dialog == null:
		panel.dialog = _find(panel, CardDialogApi) as CardDialogApi
	if panel.dialog == null:
		panel.dialog = _spawn(panel, &"dialog") as CardDialogApi
		owned["dialog"] = panel.dialog != null
	if panel.checks == null and need_checks:
		panel.checks = _find(panel, CardChecksApi) as CardChecksApi
		if panel.checks == null:
			panel.checks = _spawn(panel, &"checks") as CardChecksApi
			owned["checks"] = panel.checks != null
	if panel.hand == null:
		panel.hand = _find(panel, CardHandApi) as CardHandApi
	if panel.hand == null:
		panel.hand = _spawn(panel, &"hand_fan") as CardHandApi
		owned["hand"] = panel.hand != null
	_tag(panel.stage, bus)
	_tag(panel.dialog, bus)
	_tag(panel.checks, bus)
	_tag(panel.hand, bus)
	_mute_dialog_keys(panel.dialog)
	return owned


## Free only widgets this panel spawned. Shared C01 widgets stay on the table.
static func release(panel: CardStagePanel, owned: Dictionary) -> void:
	_restore_dialog_keys(panel.dialog)
	_free_one(panel, panel.hand if bool(owned.get("hand", false)) else null)
	_free_one(panel, panel.checks if bool(owned.get("checks", false)) else null)
	_free_one(panel, panel.dialog if bool(owned.get("dialog", false)) else null)
	_free_one(panel, panel.stage if bool(owned.get("stage", false)) else null)
	if bool(owned.get("hand", false)):
		panel.hand = null
	if bool(owned.get("checks", false)):
		panel.checks = null
	if bool(owned.get("dialog", false)):
		panel.dialog = null
	if bool(owned.get("stage", false)):
		panel.stage = null


static func _free_one(panel: Node, node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if "bus" in node:
		node.set("bus", null)
	if node.get_parent() == panel:
		panel.remove_child(node)
	node.queue_free()


static func _spawn(panel: Node, widget_name: StringName) -> Node:
	var packed := load(CardIds.widget_scene(widget_name)) as PackedScene
	var node := packed.instantiate()
	panel.add_child(node)
	return node


static func _find(panel: Node, type) -> Node:
	if not panel.is_inside_tree():
		return null
	return _walk(panel.get_tree().root, type)


static func _walk(node: Node, type) -> Node:
	if is_instance_of(node, type) and not _under_panel(node):
		return node
	for child in node.get_children():
		var found := _walk(child, type)
		if found != null:
			return found
	return null


## Widgets owned by another panel stay with that panel. C01's widgets sit on the root.
static func _under_panel(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is CardPanel:
			return true
		parent = parent.get_parent()
	return false


static func _tag(node: Node, bus: CardEventBus) -> void:
	if node != null and "bus" in node:
		node.set("bus", bus)


## C04's DialogBox reads Space / Enter / 1–9 in its own _unhandled_input and
## marks them handled. As a child of the night or settle panel it sees the key
## first, so the panel never got it (night: number select and Enter play;
## settle: Space reveal and dawn; the Space path never reached morning, #146).
## Night and settle route those keys themselves (one key handler, red line 9)
## and drive the dialog through skip() / set_replies(), so the dialog's own key
## input is off while the panel holds it, and restored on release (a shared C01
## dialog goes back to how it was).
const _KEYS_META := &"c08_dialog_keys"


static func _mute_dialog_keys(dialog: Node) -> void:
	if dialog == null or not is_instance_valid(dialog) or dialog.has_meta(_KEYS_META):
		return
	dialog.set_meta(_KEYS_META, dialog.is_processing_unhandled_input() or not dialog.is_node_ready())
	dialog.set_process_unhandled_input(false)
	# Godot turns unhandled input back on at READY for a script that overrides
	# _unhandled_input, so a dialog spawned before the panel is in the tree is
	# muted again once it is ready.
	if not dialog.is_node_ready():
		dialog.ready.connect(_mute_on_ready.bind(dialog), CONNECT_ONE_SHOT)


static func _mute_on_ready(dialog: Node) -> void:
	if is_instance_valid(dialog) and dialog.has_meta(_KEYS_META):
		dialog.set_process_unhandled_input(false)


static func _restore_dialog_keys(dialog: Node) -> void:
	if dialog == null or not is_instance_valid(dialog) or not dialog.has_meta(_KEYS_META):
		return
	dialog.set_process_unhandled_input(bool(dialog.get_meta(_KEYS_META)))
	dialog.remove_meta(_KEYS_META)
