# 拖拽数据、card_drag_started、留着按钮。悬停放大副本已作废（合同 1.3，放大在 C02_fan）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C02_drag_zoom")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	S.setup_db()
	var view: Dictionary = S.states()["keep_on"].duplicate(true)
	view["zone"] = "hand"
	var bus := CardEventBus.new()
	root.add_child(bus)
	var spy = t.spy(bus)
	var w := S.mount(self, view, &"hand", Vector2(1000, 480))
	w.bus = bus
	await t.frames(1)
	var data: Variant = w._get_drag_data(Vector2(12, 12))
	t.eq(data, {"kind": "card", "uid": str(view["uid"]), "zone": "hand"}, "drag data")
	var drag: Dictionary = _ui(spy, &"card_drag_started")
	t.eq(drag, {"uid": str(view["uid"]), "zone": "hand"}, "drag event")
	spy.clear()
	w.notification(Control.NOTIFICATION_MOUSE_ENTER)
	t.ok(w.get_node_or_null("Zoom") == null, "hover does not spawn a zoom copy")
	t.ok(_ui(spy, &"card_zoomed").is_empty(), "hover does not emit card_zoomed")
	var got: Array = []
	w.action_requested.connect(func(uid: String, act: String) -> void: got.append([uid, act]))
	(w.get_node("Keep") as Button).pressed.emit()
	t.eq(got, [[str(view["uid"]), "keep"]], "keep click")
	w.queue_free()
	bus.free()
	await t.frames(1)


func _ui(spy, ev_name: StringName) -> Dictionary:
	for row in spy.ui_events():
		if row[0] == ev_name:
			return row[1]
	return {}
