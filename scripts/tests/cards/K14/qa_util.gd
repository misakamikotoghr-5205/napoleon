# K14 shared helpers (no class_name). CLI args, view fingerprint, red-line scans.
# Random is not drawn here. A fuzzer, if added, must use JevRng.draw(seed, "c.qa.<name>", key).
extends RefCounted

const STUCK_LIMIT := 8
const STEP_CAP := 6000


static func arg(key: String, default: String = "") -> String:
	var p := "--%s=" % key
	for a in OS.get_cmdline_user_args():
		if a.begins_with(p):
			return a.substr(p.length())
	return default


static func arg_int(key: String, default: int) -> int:
	var s := arg(key, "")
	return default if s == "" else int(s)


## `--chaos` or `--chaos=1`. Absent, `=0`, and `=false` are off.
static func flag(key: String) -> bool:
	var p := "--" + key
	for a in OS.get_cmdline_user_args():
		if a == p:
			return true
		if a.begins_with(p + "="):
			var v := a.substr(p.length() + 1)
			return v != "0" and v != "false" and v != "off"
	return false


static func fingerprint(game: CardGameRoot) -> String:
	var v := game.engine.view()
	var date: Dictionary = v.get("date", {})
	var hand := PackedStringArray()
	for c in v.get("hand", []):
		if typeof(c) == TYPE_DICTIONARY:
			hand.append("%s:%s" % [str(c.get("uid", "")), str(c.get("status", ""))])
	var top := ""
	if game.host != null and game.host.top_panel() != null:
		top = str(game.host.top_kind())
	var mg := ""
	if game.mg_host != null and game.mg_host.is_active() and game.mg_host.current != null:
		mg = str(game.mg_host.current.kind())
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(v.get("phase", "")),
		str(date.get("abs_day", 0)),
		str(date.get("stage_day", 0)),
		str(v.get("money", {}).get("amount", 0)),
		"|".join(hand),
		str(v.get("open_panel", {}).get("kind", "")),
		str(v.get("notice", {}).get("fortune", "")),
		top,
		mg,
	]


## Full stage (abs_day >= days and month_close opened) or a short walk (morning after `days`).
static func reached(v: Dictionary, panels: Dictionary, days: int) -> bool:
	var phase := str(v.get("phase", ""))
	if phase == "game_over":
		return true
	var date: Dictionary = v.get("date", {})
	var sd := int(date.get("stage_day", 0))
	var ad := int(date.get("abs_day", 0))
	if panels.has("month_close") and ad >= days:
		return true
	if phase == "morning" and sd > days:
		return true
	return false


static func percent_in(node: Node) -> PackedStringArray:
	var bad := PackedStringArray()
	if node == null:
		return bad
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
			continue
		var txt := _text_of(n)
		if txt.find("%") >= 0:
			bad.append(txt)
		for i in range(n.get_child_count() - 1, -1, -1):
			stack.append(n.get_child(i))
	return bad


static func foreign_text(t, game: CardGameRoot) -> PackedStringArray:
	# 1.3: the whole screen, so a dialog and its replies are included once C01 mounts them.
	return t.all_text_from_cardtext(game)


static func ascii_snip(s: String) -> String:
	var o := ""
	var n := mini(s.length(), 80)
	for i in range(n):
		var c := s.unicode_at(i)
		o += char(c) if c >= 32 and c < 127 else "?"
	return o


static func sorted_keys(d: Dictionary) -> String:
	var ks: Array = d.keys()
	ks.sort()
	var parts := PackedStringArray()
	for k in ks:
		if str(k) != "":
			parts.append(str(k))
	return ",".join(parts)


static func command_problems(names: Array) -> PackedStringArray:
	var bad := PackedStringArray()
	var n := 0
	for i in range(names.size()):
		if names[i] != &"command_done":
			continue
		n += 1
		if i + 1 >= names.size() or names[i + 1] != &"view_changed":
			if bad.size() < 5:
				bad.append("command_done #%d not followed by view_changed" % n)
	if n == 0:
		bad.append("no command_done on the bus")
	return bad


static func _text_of(n: Node) -> String:
	if n is Label:
		return (n as Label).text
	if n is Button:
		return (n as Button).text
	if n is RichTextLabel:
		return (n as RichTextLabel).get_parsed_text()
	return ""
