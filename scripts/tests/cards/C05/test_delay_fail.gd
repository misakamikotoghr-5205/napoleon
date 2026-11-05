# C05：拖一拖后天数和档位字更新；没办成显示 outcomes.fail；没有 %。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C05/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C05_delay_fail")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var game := S.boot(self, bus, "delay.json")
	await t.frames(2)
	game.host.open_panel(&"demand", {"uid": "d1"})
	await t.frames(1)
	var panel := game.host.top_panel() as CardDemandPanel
	S.skip_dialog(panel)
	await t.frames(1)
	panel._input(S.key(KEY_TAB))
	var focus := panel.get_viewport().gui_get_focus_owner()
	t.ok(focus is Button and (focus as Button).text == CardText.ui("c05.mode.pay"), "tab focuses pay")
	panel._input(S.key(KEY_ENTER))
	var eng := game.engine as MockCardEngine
	t.ok(S.sent_has(eng, "card.choose", {"uid": "d1", "choice": "pay"}), "enter chooses pay")
	panel._input(S.key(KEY_D))
	t.ok(S.sent_has(eng, "demand.delay", {"uid": "d1"}), "D delays")
	await t.frames(1)
	_days(t, panel, 9, "panel days")
	_tier(t, panel, 2, "panel tier")
	var board := game.find_child("DemandBoard", true, false) as CardDemandBoard
	_days(t, board, 9, "board days")
	_tier(t, board, 2, "board tier")
	var danger := (board.find_child("Days", true, false) as Label).get_theme_color("font_color")
	t.ok(danger != CardTheme.color(&"danger"), "9 days is not danger")
	t.eq(S.dialog_line(panel), CardText.ui("c05.delay.note"), "delay note")
	var pct := S.percent_text(game)
	t.ok(pct.is_empty(), "percent " + " | ".join(pct))
	var shown: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(shown.is_empty(), "delay text " + " | ".join(shown))
	var closed := {"on": false}
	panel.close_requested.connect(func(_r: Dictionary) -> void: closed["on"] = true)
	panel._input(S.key(KEY_ESCAPE))
	t.ok(bool(closed["on"]), "esc closes")
	game.queue_free()
	bus.queue_free()
	await t.frames(2)

	var bus2 := CardEventBus.new()
	root.add_child(bus2)
	var game2 := S.boot(self, bus2, "fail.json")
	await t.frames(2)
	game2.host.open_panel(&"demand", {"uid": "f1"})
	await t.frames(1)
	var panel2 := game2.host.top_panel() as CardDemandPanel
	S.skip_dialog(panel2)
	await t.frames(1)
	var haggle := S.reply_button(panel2, "c05.mode.haggle")
	t.ok(haggle != null, "fail haggle reply")
	if haggle != null:
		haggle.pressed.emit()
	var submit := S.reply_button(panel2, "c05.reply.submit")
	t.ok(submit != null, "fail submit reply")
	if submit != null:
		submit.pressed.emit()
	var toss_now := _toss_of(panel2, game2)
	if toss_now != null and toss_now._playing:
		toss_now.skip()
	await t.frames(2)
	t.eq(S.dialog_line(panel2), CardText.card("dm.1938.money.t1", "outcomes.fail"), "fail line")
	var toss := _toss_of(panel2, game2)
	t.ok(toss != null, "fail toss")
	if toss != null:
		t.eq(toss._faces, [false, true], "fail faces")
		t.eq(toss._need, 2, "fail need")
	var pct2 := S.percent_text(panel2)
	t.ok(pct2.is_empty(), "fail percent " + " | ".join(pct2))
	var board2 := game2.find_child("DemandBoard", true, false)
	var pct3 := S.percent_text(board2)
	t.ok(pct3.is_empty(), "board percent " + " | ".join(pct3))
	var shown2: PackedStringArray = t.all_text_from_cardtext(panel2)
	t.ok(shown2.is_empty(), "fail text " + " | ".join(shown2))
	game2.queue_free()
	bus2.queue_free()
	await t.frames(1)


func _days(t, node: Node, n: int, msg: String) -> void:
	var lab := node.find_child("Days", true, false) as Label
	var got := lab.text if lab != null else ""
	t.ok(lab != null and (got == str(n) or got.contains(str(n))), "%s got %s" % [msg, got])


func _tier(t, node: Node, tier: int, msg: String) -> void:
	var lab := node.find_child("Tier", true, false) as Label
	t.eq(lab.text, CardText.ui("c05.tier.%d" % tier), msg)


## 铜钱：W0 桩时演出面板自己摆；真的 C03 柜台检定（C01 的根）时在 game.checks 里（[shared] C01↔C05）
func _toss_of(panel: Node, game: Node) -> CardCoinTossView:
	var toss := panel.find_child("CoinToss", true, false) as CardCoinTossView
	if toss == null:
		toss = game.find_child("CoinToss", true, false) as CardCoinTossView
	return toss
