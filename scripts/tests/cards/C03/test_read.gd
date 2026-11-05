# C03：消息看过了、当票细看、能留的留着。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C03/harness.gd")
const PANEL := "res://scenes/cards/slots/SlotPanel.tscn"


func _initialize() -> void:
	var t := T.new(self, "C03_read")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	H.leaks_all(t)
	await _news(t)
	await _ticket(t)


func _news(t) -> void:
	var pair: Array = H.boot(self, "read_news")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0031", "mode": "read"}) as CardSlotPanel
	await t.frames(2)
	t.ok(not _reply(panel, "read").is_empty(), "read reply")
	t.ok(not _reply(panel, "keep").is_empty(), "keep reply")
	t.ok(_reply(panel, "look").is_empty(), "news has no look")
	t.ok(_reply(panel, "roll").is_empty(), "read hides roll")
	panel.on_reply("keep")
	t.eq(H.cmds(pair[1], "card.keep"), [{"uid": "c0031"}], "keep news")
	panel.on_reply("read")
	t.eq(H.cmds(pair[1], "card.read"), [{"uid": "c0031"}], "read news")
	H.ui_ok(t, panel)
	await H.drop(self, [panel, pair[0]])
	pair = H.boot(self, "read_news")
	panel = H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0031", "mode": "read"})
	var steps: int = await H.drive(self, panel)
	t.ok(steps >= 1, "read autoplay")
	t.eq(H.cmds(pair[1], "card.read"), [{"uid": "c0031"}], "autoplay reads")
	await H.drop(self, [panel, pair[0]])


func _reply(panel: CardSlotPanel, id: String) -> Dictionary:
	for row in panel.reply_rows:
		if str(row.get("id", "")) == id:
			return row
	return {}


func _ticket(t) -> void:
	var pair: Array = H.boot(self, "read_ticket")
	var panel := H.open_panel(self, pair[1], pair[0], PANEL, {"uid": "c0032", "mode": "read"}) as CardSlotPanel
	await t.frames(2)
	t.eq(str(_reply(panel, "look").get("style", "")), "look", "ticket look")
	t.ok(not _reply(panel, "keep").is_empty(), "ticket keep")
	panel.on_reply("look")
	t.eq(H.cmds(pair[1], "mg.request"), [{"uid": "c0032", "item": ""}], "look requests minigame")
	panel.on_reply("keep")
	t.eq(H.cmds(pair[1], "card.keep"), [{"uid": "c0032"}], "keep ticket")
	H.ui_ok(t, panel)
	for id in ["a.slots.first", "a.slots.coins", "a.slots.roll"]:
		t.ok(not CardAnchors.has(StringName(id)), "read mode does not claim %s" % id)
	await H.drop(self, [panel, pair[0]])
