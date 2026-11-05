# C09 month-open with the default text fallback (no draft text): unwritten intro paragraphs are skipped,
# never shown as blank pages; with no paragraph written the panel opens on the goals page.
# Framework wrap-up 2026-10-22 (story packs, docs/cards/PLUGINS.md). ASCII fixture text only.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")
const S = preload("res://scripts/tests/cards/C09/c09_support.gd")
const SCENE := "res://scenes/cards/month/MonthOpen.tscn"
const FX := "res://scripts/tests/cards/C09/fixtures/month_open_three.json"


func _initialize() -> void:
	var t := T.new(self, "C09_month_open_skip")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var paras := int(S.stage_1938().get("intro_paras", 0))
	t.ok(paras >= 3, "1938 stage has three intro paragraphs")
	var root_dir: String = t.user_dir() + "/cards"
	H.write(root_dir + "/text/era/1938/stage.text.json",
		{"stage.1938": {"intro": {"p1": "P_ONE", "p2": "", "p3": "P_THREE"}}})
	var pack := S.mount(self, FX)
	CardText.setup(CardDB.load_all(root_dir))
	CardText.set_show_drafts(false)
	var p := S.open_panel(self, pack, SCENE) as CardMonthOpen
	p.refresh(pack["mock"].view())
	await t.frames(1)
	var para_root := p.find_child("Paras", true, false)
	t.eq(para_root.get_child_count(), 2, "only written paragraphs become pages")
	t.eq((p.find_child("P1", true, false) as Label).text, "P_ONE", "first page")
	t.ok(p.find_child("P2", true, false) == null, "empty p2 is skipped")
	t.ok((p.find_child("P1", true, false) as CanvasItem).visible, "p1 starts visible")
	S.tap(p, KEY_SPACE)
	t.ok((p.find_child("P3", true, false) as CanvasItem).visible, "space goes straight to p3")
	t.ok(not S.goals_visible(p), "goals still waiting")
	S.tap(p, KEY_SPACE)
	t.ok(S.goals_visible(p), "then the goals page")
	for c in para_root.get_children():
		t.ok((c as Label).text.strip_edges() != "", "no blank page")
	p.queue_free()
	# nothing written: open on the goals page
	var pack_q := S.mount(self, FX)  # the mock engine sets CardText up with the examples; replace it after
	CardText.setup(CardDB.load_all(t.user_dir() + "/empty"))
	CardText.set_show_drafts(false)
	var q := S.open_panel(self, pack_q, SCENE) as CardMonthOpen
	await t.frames(1)
	t.eq(q.find_child("Paras", true, false).get_child_count(), 0, "no intro pages without text")
	t.ok(S.goals_visible(q), "goals page shows at once")
	var closed := [false]
	q.close_requested.connect(func(_r: Dictionary) -> void: closed[0] = true)
	S.tap(q, KEY_SPACE)
	t.ok(closed[0], "space on the goals page begins (closes)")
	q.queue_free()
	# drafts switched on: every paragraph is a page again (development view)
	CardText.set_show_drafts(true)
	var r := S.open_panel(self, S.mount(self, FX), SCENE) as CardMonthOpen
	await t.frames(1)
	t.eq(r.find_child("Paras", true, false).get_child_count(), paras, "drafts on: every paragraph has a page")
	r.queue_free()
	await t.frames(2)
