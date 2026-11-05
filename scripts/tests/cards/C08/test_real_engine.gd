# C08 W2 real engine test: Day 2 leave brother farewell unresolved -> end_day lists gold_leave ->
# confirm -> night -> settle_report has g02.settle.gold_left and SettlePanel speaks it.
# Owner C08. Contract 1.3 section 7.4.7 & 7.11.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const Support = preload("res://scripts/tests/cards/C08/support.gd")


func _initialize() -> void:
	var t := T.new(self, _arg("--name=", "C08_real_engine"))
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var bus := CardEventBus.new()
	root.add_child(bus)
	var eng := CardEngine.new(bus)
	var started: Dictionary = eng.new_game({
		"seed": 7,
		"only_examples": true,
		"save_dir": t.user_dir(),
	})
	t.ok(bool(started.get("ok", false)), "new game ok")
	var host := CardModalHost.new()
	host.bind(eng, bus)
	root.add_child(host)
	t.ok(bool(eng.send(&"wheel.spin", {"wheel": "wh.month", "uid": ""}).get("ok", false)), "month wheel")
	t.ok(bool(eng.send(&"month.begin", {}).get("ok", false)), "month begin")
	t.ok(bool(eng.send(&"day.begin", {}).get("ok", false)), "day 1 begin")
	t.ok(bool(eng.send(&"day.end", {"confirm": true}).get("ok", false)), "day 1 end")
	t.ok(bool(eng.send(&"night.choose", {"def": ""}).get("ok", false)), "day 1 night")
	t.ok(bool(eng.send(&"settle.next", {}).get("ok", false)), "day 1 settle")
	t.ok(bool(eng.send(&"day.begin", {}).get("ok", false)), "day 2 begin")
	t.eq(int(eng.view().get("date", {}).get("stage_day", 0)), 2, "reached day 2")
	var brother_uid := ""
	for card in eng.view().get("hand", []):
		if typeof(card) == TYPE_DICTIONARY and str(card.get("def", "")) == "p.brother.1938.farewell":
			brother_uid = str(card.get("uid", ""))
	t.ok(brother_uid != "", "brother farewell is in hand on day 2")
	var preview: Dictionary = eng.send(&"day.end", {"confirm": false})
	t.ok(not bool(preview.get("ok", true)), "unconfirmed day.end is blocked by unresolved cards")
	t.eq(str(preview.get("err", "")), CardIds.ERR_MUST_RESOLVE, "err is must_resolve_pending")
	var end_panel := host.open_panel(&"end_day", {
		"step": str(preview.get("step", "")),
		"items": preview.get("items", []),
	})
	await t.frames(2)
	t.ok(t.anchor_ok(&"a.endday.gold_leave"), "gold_leave anchor is registered")
	var saw_gold_row := false
	for row in end_panel.find_children("EndRow*", "", true, false):
		if str(row.get_meta("kind", "")) == "gold_leave":
			saw_gold_row = true
			var lab := row.find_child("Consequence", true, false) as Label
			t.eq(lab.text, CardText.t("p.brother.1938.farewell#outcomes.ignored"), "brother gold_leave consequence")
	t.ok(saw_gold_row, "end_day confirm lists brother gold_leave row")
	(Support.child(end_panel, "BtnConfirm") as Button).pressed.emit()
	await t.frames(2)
	t.eq(str(eng.view().get("phase", "")), "night", "confirm advances to night")
	var night_panel := host.open_panel(&"night", {}) as CardNightPanel
	await t.frames(2)
	t.ok(night_panel.autoplay_step(), "night panel autoplay_step")
	await t.frames(2)
	t.eq(str(eng.view().get("phase", "")), "settle", "night choice advances to settle")
	var report: Dictionary = eng.query(&"settle_report", {})
	var saw_report_gold := false
	for line in report.get("lines", []):
		if typeof(line) == TYPE_DICTIONARY and str(line.get("key", "")) == "g02.settle.gold_left":
			saw_report_gold = true
	t.ok(saw_report_gold, "settle_report includes g02.settle.gold_left")
	var settle_panel := host.open_panel(&"settle", {}) as CardSettlePanel
	await t.frames(2)
	settle_panel._reveal_all()
	var refs: Array = []
	for line in settle_panel.dialog.get("_lines"):
		refs.append(str(line.get("ref", "")))
	t.ok(refs.has("g02.settle.gold_left"), "settle dialog speaks g02.settle.gold_left")
	# Report args the words do not print ({n: 1} here, tier indices on a tier change) never become number chips.
	var nums := settle_panel.dialog.get("_nums") as Control
	t.ok(nums != null and nums.get_child_count() == 0, "no number chips under the night report")
	t.ok(settle_panel.autoplay_step(), "settle autoplay advances to morning")
	t.eq(str(eng.view().get("phase", "")), "morning", "reached morning of day 3")
	t.eq(int(eng.view().get("date", {}).get("stage_day", 0)), 3, "stage_day is 3")
	host.queue_free()
	bus.queue_free()
	await t.frames(2)


func _arg(prefix: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with(prefix):
			return str(a).substr(prefix.length())
	return fallback
