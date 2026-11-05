# 转前转后：面板文字没有阿拉伯数字（代价那一行除外）、没有百分号；文字都来自 CardText；夹具不漏隐藏键。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C06/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C06_no_numbers")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	for name in S.FIXTURES:
		var fix := S.read_fix(name)
		t.no_leaks(S.wheel_query(fix), name + " wheel")
		t.no_leaks(fix.get("view", {}), name + " view")
		if fix.has("widen_to"):
			t.no_leaks(fix.get("widen_to"), name + " widen_to")
		var pack := S.boot(self)
		var mock: MockCardEngine = pack["mock"]
		mock.load_fixture(S.FIX + name + ".json")
		var panel := S.open_panel(self, mock, pack["bus"], S.args_of(fix))
		panel.fast_anim = true
		await t.frames(2)
		_text_ok(t, panel, name + " before")
		if name == "gamble_stake":
			S.press(panel, "Spin")
			await t.frames(1)
			_text_ok(t, panel, name + " stake error")
			S.press(panel, "Stake")
			await t.frames(1)
			_text_ok(t, panel, name + " staked")
			S.press(panel, "Spin")
		else:
			S.press(panel, "Spin")
		await t.frames(1)
		_text_ok(t, panel, name + " after")
		panel.queue_free()
		(pack["bus"] as Node).queue_free()
		await t.frames(1)


func _text_ok(t, panel: Node, label: String) -> void:
	var bad := S.bad_panel_text(panel)
	t.ok(bad.is_empty(), "%s digits or percent: %s" % [label, ", ".join(bad)])
	var leaked: PackedStringArray = t.all_text_from_cardtext(panel)
	t.ok(leaked.is_empty(), "%s text not from CardText: %s" % [label, ", ".join(leaked)])
