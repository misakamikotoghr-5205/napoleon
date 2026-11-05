# gd.mg.coin_ring 会亮，用鼠标点一枚样洋吹一下（mg_tool）后完成；三个锚点都在画面里。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C13/harness.gd")
const GUIDE := "res://scenes/cards/shell/GuideOverlay.tscn"


func _initialize() -> void:
	var t := T.new(self, H.arg("name", "C13_guide"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var mock := MockCardEngine.new(bus)
	if H.arg("steps") == "k16":
		# CardGuide._date_ok reads engine.view().date.stage_day (MockCardEngine.view).
		var date: Dictionary = {"stage": 0, "stage_day": 4, "abs_day": 4}
		mock._view = {"phase": "day", "mode": "shop", "date": date, "hand": []}
	var g := H.open(self, H.fixture("good"), bus)
	await t.frames(1)
	for id in ["a.mg.coin_ring.main", "a.mg.coin_ring.blow", "a.mg.coin_ring.ear"]:
		var rect := CardAnchors.rect(StringName(id))
		t.ok(t.anchor_ok(StringName(id)), "anchor %s rect %s" % [id, rect])
	var guide := (load(GUIDE) as PackedScene).instantiate() as CardGuide
	root.add_child(guide)
	guide.bind(mock, bus)
	guide.force(true)
	guide.skip_fades = true
	if H.arg("steps") == "k16":
		guide.load_steps(mock.query(&"guide_data"))
	else:
		guide.load_steps(H.guide_steps())
	bus.first_time.emit(&"mg.coin_ring", {"uid": "c0013"})
	guide.evaluate_now()
	t.eq(guide.active_step(), "gd.mg.coin_ring", "step lit")
	H.click(g, H.center(g._sample_faces[0]))
	t.eq(g.ops_log(), [["blow", -1]], "the click reached the coin under the guide")
	t.eq(guide.active_step(), "", "blow completes the step")
	t.ok(guide.shown_log.has("gd.mg.coin_ring"), "shown log")
	await H.drop(self, [guide, g, bus])
	mock = null
