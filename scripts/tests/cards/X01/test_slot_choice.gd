extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

func _initialize() -> void:
	var t := T.new(self, "X01_slot_choice")
	t.run_async(_body.bind(t))

func _body(t) -> void:
	var fixture: Dictionary = CardDB.read_json("res://scripts/tests/cards/C03/fixtures/event_slots.json")
	var card: Dictionary = fixture.queries['card|{"uid":"c0003"}']
	card["def"] = "p.postman.1938.ask_letter"
	card["choices"] = [{"id": "keep", "enabled": true}, {"id": "skip", "enabled": true}]
	card["slots"] = []
	fixture["responses"] = [{"cmd": "card.choose", "match": {"uid": "c0003", "choice": "keep"},
		"result": {"ok": true, "err": "", "needs_slots": false},
		"events": [["card_left", "c0003", "resolved"]]}]
	var path: String = t.user_dir() + "/postman.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture))
	file.close()
	var bus := CardEventBus.new()
	root.add_child(bus)
	var engine := MockCardEngine.new(bus)
	engine.load_fixture(path)
	var panel: CardSlotPanel = load("res://scenes/cards/slots/SlotPanel.tscn").instantiate()
	panel.bind(engine, bus)
	root.add_child(panel)
	panel.open({"uid": "c0003"})
	panel.dialog.skip()
	await t.frames(2)
	panel.autoplay_step()
	t.eq(engine.sent, [["card.choose", {"uid": "c0003", "choice": "keep"}]], "keep choice is not the read-panel card.keep control")
	t.ok(panel._closed, "postman's choice resolves instead of looping on day eight")
	# Reloading CardText after this persistent widget was built must refresh skip.
	CardText.setup(null)
	panel.dialog.show_lines("probe", [{"kind": "sys", "ref": "c04.dialog.sample"}])
	t.eq(panel.dialog._skip.text, CardText.ui("c04.dialog.skip"), "skip label refreshes with active text database")
	t.ok(CardText.issued_contains(panel.dialog._skip.text), "skip label comes from current CardText")
	panel.queue_free()
	await t.frames(2)
	bus.queue_free()
	await t.frames(2)
