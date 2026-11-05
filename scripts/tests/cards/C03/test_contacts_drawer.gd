# C03：人脉抽屉只读，行能拖，看一眼就关。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C03/harness.gd")
const Kit = preload("res://scripts/cards/ui/slots/drawer_kit.gd")
const DRAWER := "res://scenes/cards/slots/ContactsDrawer.tscn"


func _initialize() -> void:
	var t := T.new(self, "C03_contacts_drawer")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	H.leaks_all(t)
	var pair: Array = H.boot(self, "event_slots")
	var panel := H.open_panel(self, pair[1], pair[0], DRAWER, {}) as CardContactsDrawer
	await t.frames(2)
	var kit_rect: Rect2 = Kit.rect("l")
	t.eq(panel.size, kit_rect.size, "drawer content size")
	# b20: the content sits inside the left drawer frame, under its title row (so it no longer covers the
	# HUD or the frame's 合上), and its text is light on the dark drawer.
	# QA 10-25: the title row is drawer_host.HEAD_H (52, unified in 4bda31a7), so the content starts at y 83, not 74.
	t.eq(Rect2(panel.position, panel.size), kit_rect, "b20 content rect inside DRAWER_L")
	t.ok(panel.position.y >= CardLayout.DRAWER_L.position.y + Kit.DrawerHost.HEAD_H, "b20 below the frame title row")
	t.ok(panel.position.y + panel.size.y <= CardLayout.DRAWER_L.end.y, "b20 content ends inside the drawer")
	var self_row := panel.find_child("RowSelf", true, false)
	t.ok(self_row != null, "self row")
	t.eq(self_row._get_drag_data(Vector2.ZERO), {"kind": "self"}, "self drag")
	var self_name := self_row.find_child("RowName", true, false) as Label
	t.ok(self_name != null and self_name.get_theme_color("font_color").get_luminance() > 0.6,
		"b20 row text is light ink")
	var contact := panel.find_child("Row_contact_c0012", true, false)
	t.eq(contact._get_drag_data(Vector2.ZERO), {"kind": "card", "uid": "c0012", "zone": "contacts"}, "contact drag")
	var kept := panel.find_child("Row_kept_c0020", true, false)
	t.eq(kept._get_drag_data(Vector2.ZERO), {"kind": "card", "uid": "c0020", "zone": "kept"}, "kept drag")
	t.ok(panel.find_child("StateUsed", true, false) != null, "used state")
	# 换皮 10-22：不在几天是一句（c03.state.away，带天数），不再另挂一个光秃秃的数字。
	var away: Label = panel.find_child("StateAway", true, false)
	t.ok(away != null and away.text.contains("2"), "away days in the state line")
	t.ok(away != null and away.is_visible_in_tree() or not panel.is_inside_tree(), "away line shown")
	t.ok(panel.find_child("AwayN", true, false) == null, "no bare away digit")
	t.eq(H.cmds(pair[1], "slot.place").size(), 0, "drawer sends nothing")
	t.eq(pair[1].sent.size(), 0, "drawer is read only")
	H.ui_ok(t, panel)
	var steps: int = await H.drive(self, panel)
	t.eq(steps, 1, "autoplay looks once")
	t.ok(not panel.autoplay_step(), "autoplay finished")
	t.eq(H.cmds(pair[1], "contact.release").size(), 0, "closing the drawer releases nobody")
	await H.drop(self, [panel, pair[0]])
