# C10 测试小工具。不写 class_name。主人 C10。
extends RefCounted


static func leaks_fixture(t, path: String) -> void:
	var data = CardDB.read_json(path)
	if typeof(data) != TYPE_DICTIONARY:
		t.ok(false, path + " is not an object")
		return
	if data.has("view"):
		t.no_leaks(data["view"], path + " view")
	var qs = data.get("queries", {})
	if typeof(qs) == TYPE_DICTIONARY:
		for k in qs.keys():
			t.no_leaks(qs[k], path + " " + str(k))


static func find_meta(root: Node, key: StringName, val: String) -> Node:
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta(key) and str(n.get_meta(key)) == val:
			return n
		var kids: Array = n.get_children()
		for i in range(kids.size() - 1, -1, -1):
			stack.append(kids[i])
	return null


static func meta_values(root: Node, key: StringName) -> Array:
	var out: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta(key):
			out.append(str(n.get_meta(key)))
		for c in n.get_children():
			stack.append(c)
	return out


static func has_text(n: Node) -> bool:
	if n == null:
		return false
	if n is Label and str((n as Label).text) != "":
		return true
	if n is Button and str((n as Button).text) != "":
		return true
	if n is RichTextLabel and str((n as RichTextLabel).get_parsed_text()) != "":
		return true
	if n is LineEdit and str((n as LineEdit).text) != "":
		return true
	for c in n.get_children():
		if has_text(c):
			return true
	return false


static func has_percent(n: Node) -> bool:
	var blob := ""
	if n is Label:
		blob = (n as Label).text
	elif n is Button:
		blob = (n as Button).text
	elif n is RichTextLabel:
		blob = (n as RichTextLabel).get_parsed_text()
	if blob.find("%") >= 0:
		return true
	for c in n.get_children():
		if has_percent(c):
			return true
	return false


static func tap(tree: SceneTree, key: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = key
	down.physical_keycode = key
	down.pressed = true
	down.echo = false
	tree.root.push_input(down)
	await tree.process_frame
	var up := InputEventKey.new()
	up.keycode = key
	up.physical_keycode = key
	up.pressed = false
	tree.root.push_input(up)
	await tree.process_frame


static func source_ok(t, path: String) -> void:
	var src := FileAccess.get_file_as_string(path)
	t.ok(src.length() > 40, path + " is readable")
	t.ok(src.find("w0_stub") < 0, path + " does not preload w0_stub")
	t.ok(src.find("randf(") < 0 and src.find("randi(") < 0, path + " does not call global rand")
	t.ok(src.find("Color(") < 0 and src.find("Color.") < 0, path + " has no color literal")
	t.ok(src.find("%") < 0, path + " has no percent sign")
	for needle in ["guide_progress", "is_enabled", ".force(", "set_enabled"]:
		t.ok(src.find(needle) < 0, path + " does not read guide switch via " + needle)
