# C09 game over: ending copy, retry, return to title.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C09/c09_support.gd")
const SCENE := "res://scenes/cards/month/GameOver.tscn"
const FX := "res://scripts/tests/cards/C09/fixtures/game_over_prison.json"


func _initialize() -> void:
	var t := T.new(self, "C09_game_over")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var fx = CardDB.read_json(FX)
	var args: Dictionary = fx["view"]["open_panel"]["args"]
	var pack := S.mount(self, FX)
	var mock: MockCardEngine = pack["mock"]
	t.no_leaks(mock.view(), "game over view")
	var p := S.open_panel(self, pack, SCENE) as CardGameOver
	p.open(args)
	p.open({"uid": "c0002"})
	p.open(args)
	await t.frames(1)
	var ending := p.find_child("Ending", true, false) as Label
	t.eq(ending.text, CardText.t("g02.ending.prison"), "ending uses g02.ending.prison")
	t.ok(ending.text.strip_edges() != "", "the prison ending has words (the data's game_over reason)")
	t.ok(t.anchor_ok(&"a.over.retry"), "retry anchor %s" % CardAnchors.rect(&"a.over.retry"))
	t.ok(t.all_text_from_cardtext(p).is_empty(), "text from CardText: %s" % ", ".join(t.all_text_from_cardtext(p)))
	t.ok(not S.has_percent(p), "no percent sign")
	var retry_result := [{"missing": true}]
	p.close_requested.connect(func(r: Dictionary) -> void: retry_result[0] = r)
	(p.find_child("Retry", true, false) as Button).pressed.emit()
	t.eq(S.count_cmd(mock, "game.retry_stage"), 1, "retry sends game.retry_stage")
	t.eq(mock.sent.filter(func(row): return str(row[0]) == "game.retry_stage")[0][1], {}, "retry args")
	t.eq(retry_result[0], {}, "retry closes without to_title")
	(p.find_child("Retry", true, false) as Button).pressed.emit()
	t.eq(S.count_cmd(mock, "game.retry_stage"), 1, "retry is sent once")
	_title(t)
	_bus_reason(t)
	_override(t)
	_keys(t)
	_resume(t)
	_autoplay(t)
	t.finish()


func _title(t) -> void:
	var pack := S.mount(self, FX)
	var p := S.open_panel(self, pack, SCENE)
	var args: Dictionary = CardDB.read_json(FX)["view"]["open_panel"]["args"]
	p.open(args)
	var result := [{}]
	p.close_requested.connect(func(r: Dictionary) -> void: result[0] = r)
	(p.find_child("Title", true, false) as Button).pressed.emit()
	t.eq(result[0], {"to_title": true}, "title button asks C01 to return")
	t.eq(S.count_cmd(pack["mock"], "game.retry_stage"), 0, "title does not retry")


func _bus_reason(t) -> void:
	var pack := S.mount(self, FX)
	var p: CardGameOver = load(SCENE).instantiate()
	p.bind(pack["mock"], pack["bus"])
	root.add_child(p)
	pack["bus"].game_over.emit(&"prison")
	p.open({})
	var ending := p.find_child("Ending", true, false) as Label
	t.eq(ending.text, CardText.t("g02.ending.prison"), "reason remembered from game_over")


func _override(t) -> void:
	var pack := S.mount(self, FX)
	var p: CardGameOver = load(SCENE).instantiate()
	p.bind(pack["mock"], pack["bus"])
	root.add_child(p)
	pack["bus"].game_over.emit(&"street")
	p.open({"reason": "prison"})
	var ending := p.find_child("Ending", true, false) as Label
	t.eq(ending.text, CardText.t("g02.ending.prison"), "open args.reason wins over the bus")


func _keys(t) -> void:
	var pack := S.mount(self, FX)
	var p := S.open_panel(self, pack, SCENE)
	var result := [{"missing": true}]
	p.close_requested.connect(func(r: Dictionary) -> void: result[0] = r)
	S.tap(p, KEY_ESCAPE)
	t.eq(result[0], {"to_title": true}, "escape returns to the title")
	t.eq(S.count_cmd(pack["mock"], "game.retry_stage"), 0, "escape does not retry")
	t.eq(S.count_cmd(pack["mock"], "game.load"), 0, "escape does not load")
	var pack2 := S.mount(self, FX)
	var p2 := S.open_panel(self, pack2, SCENE)
	S.tap(p2, KEY_SPACE)
	t.eq(S.count_cmd(pack2["mock"], "game.retry_stage"), 1, "space retries")


func _resume(t) -> void:
	CardSave.set_root(t.user_dir())
	var args: Dictionary = CardDB.read_json(FX)["view"]["open_panel"]["args"]
	var pack := S.mount(self, FX)
	var p := S.open_panel(self, pack, SCENE)
	p.open(args)
	var resume := p.find_child("Resume", true, false) as Button
	t.ok(resume.disabled, "resume is disabled without a suspend file")
	resume.pressed.emit()
	t.eq(S.count_cmd(pack["mock"], "game.load"), 0, "a disabled resume sends nothing")
	var path := CardSave.suspend_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{}\n")
	f.close()
	p.refresh(pack["mock"].view())
	t.ok(not resume.disabled, "resume enables when the suspend file exists")
	var result := [{"missing": true}]
	p.close_requested.connect(func(r: Dictionary) -> void: result[0] = r)
	resume.pressed.emit()
	t.eq(S.count_cmd(pack["mock"], "game.load"), 1, "resume sends game.load")
	t.eq(pack["mock"].sent.filter(func(row): return str(row[0]) == "game.load")[0][1], {}, "game.load args are empty")
	t.eq(result[0], {}, "resume does not return to the title")
	t.eq(S.count_cmd(pack["mock"], "game.retry_stage"), 0, "resume does not retry the stage")
	var pack2 := S.mount(self, FX)
	var p2 := S.open_panel(self, pack2, SCENE)
	p2.open(args)
	var gone := [{"missing": true}]
	p2.close_requested.connect(func(r: Dictionary) -> void: gone[0] = r)
	p2.dismiss()
	t.eq(gone[0], {"to_title": true}, "dismiss returns to the title")
	t.eq(S.count_cmd(pack2["mock"], "game.retry_stage"), 0, "dismiss does not retry")
	t.eq(S.count_cmd(pack2["mock"], "game.load"), 0, "dismiss does not load")


func _autoplay(t) -> void:
	var a := S.mount(self, FX)
	var b := S.mount(self, FX)
	var pa := S.open_panel(self, a, SCENE)
	var pb := S.open_panel(self, b, SCENE)
	t.eq(S.drain(pa), S.drain(pb), "autoplay length matches")
	t.eq(a["mock"].sent, b["mock"].sent, "autoplay commands match")
	t.eq(S.count_cmd(a["mock"], "game.retry_stage"), 1, "autoplay retries once")
	t.ok(not pa.autoplay_step(), "autoplay stops")
