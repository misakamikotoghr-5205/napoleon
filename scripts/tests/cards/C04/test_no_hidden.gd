# C04: every fixture's panel text comes from CardText, has no percent sign,
# and any number we paint ourselves is asking, a tier, last_price, or a ticket figure.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C04/support.gd")

const CASES := {
	"pawn": "c0002",
	"sell": "c0003",
	"buy": "c0004",
	"redeem_by_rule": "c0008",
	"redeem_sold": "c0009",
	"choices": "c0010",
	"counter_then_leave": "c0002",
	"after_look": "c0021",
	"five_rounds": "c0002",
}


func _initialize() -> void:
	var t := T.new(self, "C04_no_hidden")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var num_re := RegEx.new()
	num_re.compile("-?\\d+")
	for name in CASES.keys():
		var doc = S.read(name)
		t.no_leaks(doc, name)
		var uid := str(CASES[name])
		var shown := _shown(doc, uid)
		var ctx: Dictionary = S.boot(self, name)
		await t.frames(1)
		var panel := S.play(ctx, uid)
		await t.frames(2)
		var bad: PackedStringArray = t.all_text_from_cardtext(panel)
		t.ok(bad.is_empty(), name + " text not from CardText: " + ", ".join(bad))
		# Reskin 10-23: the item row (tags with numbers) now lives in the shared dialog, so check it too.
		var dlg = panel.get("dialog")
		var nodes := _walk(panel)
		if dlg != null and is_instance_valid(dlg) and not panel.is_ancestor_of(dlg):
			var bad_dlg: PackedStringArray = t.all_text_from_cardtext(dlg)
			t.ok(bad_dlg.is_empty(), name + " dialog text not from CardText: " + ", ".join(bad_dlg))
			nodes.append_array(_walk(dlg))
		var allowed := _allowed(shown)
		for n in nodes:
			var txt := _text_of(n)
			if txt == "":
				continue
			t.ok(txt.find("%") < 0, name + " has percent in: " + txt)
			if CardText.issued_contains(txt):
				continue
			var found := num_re.search_all(txt)
			t.ok(not found.is_empty(), name + " non-cardtext text should be a number: " + txt)
			for m in found:
				var v := int(m.get_string())
				t.ok(allowed.has(v), "%s number %d is not asking/tier/last_price/ticket" % [name, v])
		S.free_ctx(ctx)
		await t.frames(1)


func _shown(doc: Dictionary, uid: String) -> Dictionary:
	var key := "counter|{\"uid\":\"%s\"}" % uid
	var q: Dictionary = doc.get("queries", {}).get(key, {})
	if q.has("tiers") and not (q.has("ok") and not bool(q["ok"])):
		return q
	for row in doc.get("responses", []):
		if str(row.get("cmd", "")) == "counter.open":
			return row.get("result", {})
	return q


func _allowed(view: Dictionary) -> Dictionary:
	var set := {}
	if int(view.get("asking", -1)) >= 0:
		set[int(view["asking"])] = true
	var tiers = view.get("tiers", {})
	if typeof(tiers) == TYPE_DICTIONARY:
		for k in ["harsh", "fair", "kind"]:
			set[int(tiers.get(k, 0))] = true
	set[int(view.get("last_price", 0))] = true
	var ticket = view.get("ticket")
	if typeof(ticket) == TYPE_DICTIONARY:
		set[int(ticket.get("no", 0))] = true
		set[int(ticket.get("principal", 0))] = true
		set[int(ticket.get("days_left", 0))] = true
	return set


func _text_of(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	if n is Button:
		return (n as Button).text
	if n is RichTextLabel:
		return (n as RichTextLabel).get_parsed_text()
	return ""


func _walk(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out
