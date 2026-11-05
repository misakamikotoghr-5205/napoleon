# C04: person-card choices are extra replies. A disabled one stays grey and shows its reason.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C04/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C04_choices")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	t.no_leaks(S.read("choices"), "choices fixture")
	var ctx: Dictionary = S.boot(self, "choices")
	await t.frames(1)
	var panel := S.play(ctx, "c0010")
	var mock: MockCardEngine = ctx.mock
	await t.frames(2)
	var listen := S.button(panel, "Choice_listen")
	var gift := S.button(panel, "Choice_gift")
	var reason := S.label(panel, "Reason_gift")
	t.ok(listen != null and not listen.disabled, "listen is enabled")
	t.eq(listen.text, CardText.card("p.brother.1938.farewell", "choices.listen"), "listen wording")
	t.ok(gift != null and gift.disabled, "gift is disabled")
	t.ok(gift.modulate.a < 0.6, "disabled choice is dimmed")
	t.eq(gift.text, CardText.card("p.brother.1938.farewell", "choices.gift"), "gift wording")
	t.ok(reason != null, "reason label")
	if reason != null:
		t.eq(reason.text, CardText.t("g03.reason.money"), "reason text")
	gift.pressed.emit()
	await t.frames(1)
	t.eq(S.cmds(mock), [], "disabled choice sends nothing")
	listen.pressed.emit()
	await t.frames(1)
	t.eq(S.cmds(mock), [["card.choose", {"uid": "c0010", "choice": "listen"}]], "choose listen")
	var stopped := false
	for i in 6:
		var more: bool = panel.autoplay_step()
		await t.frames(1)
		if not more:
			stopped = true
			break
	t.ok(stopped, "choices autoplay stops")
	S.free_ctx(ctx)
	await t.frames(1)
