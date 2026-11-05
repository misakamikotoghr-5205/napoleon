# K15：对当前仓库跑 missing_text.py。真仓库里的指引步骤和规矩页必须出现在待写清单里；
# 还没有这些文件就打印 NOTE 并跳过。带 stage 的牌，每一拍 ref 都要在待写清单里；
# 还没有演出块就 NOTE 跳过。extras.json 的 ex_* 人名同样：文件还没有就 NOTE 跳过。
# 清单里不得出现真数据的 brief 原文。
# 合同：docs/cards/CARDS_INTERFACES.md §4.5、§11；任务卡 docs/handoff_cards/K15_audit-provenance.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "K15_missing_text_real")
	var prefix := ProjectSettings.globalize_path(t.user_dir()).path_join("mt")
	var output: Array = []
	var args := PackedStringArray(["tools/cards/audit/missing_text.py", "--out=%s" % prefix])
	var code := _python(args, output)
	if code != 0:
		_print_tail(output)
	t.ok(code == 0, "missing_text.py exit %d" % code)
	var json_path := prefix + ".json"
	var md_path := prefix + ".md"
	t.ok(FileAccess.file_exists(json_path), "mt.json written")
	t.ok(FileAccess.file_exists(md_path), "mt.md written")
	if FileAccess.file_exists(json_path) and FileAccess.file_exists(md_path):
		var raw := FileAccess.get_file_as_string(json_path)
		var md := FileAccess.get_file_as_string(md_path)
		var data = JSON.parse_string(raw)
		t.ok(typeof(data) == TYPE_DICTIONARY, "mt.json is an object")
		if typeof(data) == TYPE_DICTIONARY:
			var entries: Array = data.get("entries", [])
			_check_guide(t, entries)
			_check_stage_narration(t, entries, md)
			_check_end_keys(t, entries)
			_check_stage_beats(t, entries)
			_check_extras(t, entries)
			_check_briefs(t, raw + "\n" + md)
	t.finish()


func _check_stage_narration(t, entries: Array, md: String) -> void:
	var by_id := _index(entries)
	for key in ["w0.stage.enter", "w0.stage.at_door", "w0.stage.leave"]:
		var row = by_id.get(key, null)
		t.ok(typeof(row) == TYPE_DICTIONARY, "narration key %s is listed" % key)
		if typeof(row) != TYPE_DICTIONARY:
			continue
		t.ok(str(row.get("owner", "")) == "A", "narration key %s belongs to A" % key)
		t.ok(bool(row.get("w0_stub", true)) == false, "narration key %s is not a W0 stub" % key)
		t.ok(str(row.get("text_file", "")) == "data/cards/text/ui/W0.text.json", "narration key %s is in W0.text.json" % key)
	var stub_at := md.find("## W0 桩用的键")
	if stub_at >= 0:
		var stub := md.substr(stub_at)
		t.ok(stub.find("w0.stage.enter") < 0, "w0.stage.enter is not in the stub section")
		t.ok(stub.find("w0.stage.at_door") < 0, "w0.stage.at_door is not in the stub section")
		t.ok(stub.find("w0.stage.leave") < 0, "w0.stage.leave is not in the stub section")


func _check_end_keys(t, entries: Array) -> void:
	# g0x.end.* are ordinary interface keys when a task has registered them.
	for row in entries:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var id := str(row.get("id", ""))
		if not id.begins_with("g0") or id.find(".end.") < 0:
			continue
		t.ok(str(row.get("type", "")) == "ui_key", "end key %s is a ui key" % id)
		t.ok(str(row.get("owner", "")) == "B", "end key %s belongs to B" % id)
		t.ok(bool(row.get("w0_stub", false)) == false, "end key %s is not a W0 stub" % id)


func _check_stage_beats(t, entries: Array) -> void:
	var staged := _stage_cards()
	if staged.is_empty():
		print("NOTE: no cards with a stage block in res://data/cards; beat ref check skipped")
		return
	var by_id := _index(entries)
	for card in staged:
		var id := str(card.get("id", ""))
		var row = by_id.get(id, null)
		var fields: Array = row.get("fields", []) if typeof(row) == TYPE_DICTIONARY else []
		t.ok(typeof(row) == TYPE_DICTIONARY, "stage card %s is listed" % id)
		for ref in _beat_refs(card):
			t.ok(fields.has(ref), "stage card %s lists beat ref %s" % [id, ref])


func _check_extras(t, entries: Array) -> void:
	var path := "res://data/cards/common/extras.json"
	if not FileAccess.file_exists(path):
		print("NOTE: no data/cards/common/extras.json; extra names skipped")
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var persons = data.get("persons", {}) if typeof(data) == TYPE_DICTIONARY else {}
	var ids: Array = []
	if typeof(persons) == TYPE_DICTIONARY:
		for pid in persons.keys():
			if str(pid).begins_with("ex_"):
				ids.append(str(pid))
	if ids.is_empty():
		print("NOTE: extras.json has no ex_* persons; extra names skipped")
		return
	var by_id := _index(entries)
	for pid in ids:
		var row = by_id.get(pid, null)
		var fields: Array = row.get("fields", []) if typeof(row) == TYPE_DICTIONARY else []
		t.ok(typeof(row) == TYPE_DICTIONARY and str(row.get("type", "")) == "person_name", "extra %s is listed as a person name" % pid)
		t.ok(fields.has("name"), "extra %s needs a name" % pid)


func _index(entries: Array) -> Dictionary:
	var by_id := {}
	for row in entries:
		if typeof(row) == TYPE_DICTIONARY:
			by_id[str(row.get("id", ""))] = row
	return by_id


func _stage_cards() -> Array:
	var out: Array = []
	for folder in ["era", "demand", "news", "dossier", "common", "fortune", "guide"]:
		_collect_stage_dir("res://data/cards".path_join(folder), out)
	var items := "res://data/cards/minigames/items.json"
	if FileAccess.file_exists(items):
		_cards_in_file(items, out)
	return out


func _collect_stage_dir(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var child := path.path_join(name)
			if dir.current_is_dir():
				if name != "_examples":
					_collect_stage_dir(child, out)
			elif name.ends_with(".json") and name != "stage.json":
				_cards_in_file(child, out)
		name = dir.get_next()
	dir.list_dir_end()


func _cards_in_file(path: String, out: Array) -> void:
	if not FileAccess.file_exists(path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return
	var cards = data.get("cards", [])
	if typeof(cards) != TYPE_ARRAY:
		return
	for card in cards:
		if typeof(card) != TYPE_DICTIONARY or str(card.get("id", "")) == "":
			continue
		var stage = card.get("stage", null)
		if typeof(stage) == TYPE_DICTIONARY and not stage.is_empty():
			out.append(card)


func _beat_refs(card: Dictionary) -> PackedStringArray:
	var refs := PackedStringArray()
	var stage: Dictionary = card.get("stage", {})
	var intro = stage.get("intro", [])
	if typeof(intro) == TYPE_ARRAY:
		for beat in intro:
			_take_ref(beat, refs)
	var after = stage.get("after", {})
	if typeof(after) == TYPE_DICTIONARY:
		for key in after.keys():
			var beats = after[key]
			if typeof(beats) != TYPE_ARRAY:
				continue
			for beat in beats:
				_take_ref(beat, refs)
	return refs


func _take_ref(beat, refs: PackedStringArray) -> void:
	if typeof(beat) != TYPE_DICTIONARY:
		return
	var ref := str(beat.get("ref", ""))
	if ref != "":
		refs.append(ref)


func _check_guide(t, entries: Array) -> void:
	var steps := _cards("res://data/cards/guide/steps.json", "guide_step")
	var rules := _cards("res://data/cards/guide/rule_pages.json", "rule_page")
	if steps.is_empty():
		print("NOTE: no guide steps in res://data/cards/guide/steps.json; say/bubble check skipped")
	if rules.is_empty():
		print("NOTE: no rule pages in res://data/cards/guide/rule_pages.json; title/body check skipped")
	var by_id := {}
	for row in entries:
		if typeof(row) == TYPE_DICTIONARY:
			by_id[str(row.get("id", ""))] = row
	for card in steps:
		var id := str(card.get("id", ""))
		var row = by_id.get(id, null)
		var fields: Array = row.get("fields", []) if typeof(row) == TYPE_DICTIONARY else []
		t.ok(typeof(row) == TYPE_DICTIONARY, "guide step %s is listed" % id)
		t.ok(fields.has("say") and fields.has("bubble"), "guide step %s needs say and bubble" % id)
	for card in rules:
		var id := str(card.get("id", ""))
		var row = by_id.get(id, null)
		var fields: Array = row.get("fields", []) if typeof(row) == TYPE_DICTIONARY else []
		t.ok(typeof(row) == TYPE_DICTIONARY, "rule page %s is listed" % id)
		t.ok(fields.has("title") and fields.has("body"), "rule page %s needs title and body" % id)


func _cards(path: String, kind: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return []
	var cards = data.get("cards", [])
	if typeof(cards) != TYPE_ARRAY:
		return []
	var out: Array = []
	for card in cards:
		if typeof(card) == TYPE_DICTIONARY and str(card.get("type", "")) == kind and str(card.get("id", "")) != "":
			out.append(card)
	return out


func _check_briefs(t, blob: String) -> void:
	var briefs := PackedStringArray()
	_scan_tree("res://data", briefs)
	var seen := {}
	for brief in briefs:
		if seen.has(brief):
			continue
		seen[brief] = true
		if blob.find(brief) >= 0:
			t.ok(false, "brief leaked (len %d, U+%04X)" % [brief.length(), brief.unicode_at(0)])


func _scan_tree(path: String, briefs: PackedStringArray) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var child := path.path_join(name)
			if dir.current_is_dir():
				if name != "_examples":
					_scan_tree(child, briefs)
			elif name.ends_with(".json"):
				_briefs_in(FileAccess.get_file_as_string(child), briefs)
		name = dir.get_next()
	dir.list_dir_end()


func _briefs_in(text: String, briefs: PackedStringArray) -> void:
	var data = JSON.parse_string(text)
	if data != null:
		_walk(data, briefs)


func _walk(v, briefs: PackedStringArray) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				var child = v[k]
				if str(k) == "brief" and typeof(child) == TYPE_STRING and str(child).length() >= 8:
					briefs.append(str(child))
				else:
					_walk(child, briefs)
		TYPE_ARRAY:
			for item in v:
				_walk(item, briefs)


func _python(args: PackedStringArray, output: Array) -> int:
	var code := OS.execute("python3", args, output, true)
	if code == -1:
		output.clear()
		code = OS.execute("python", args, output, true)
	return code


func _print_tail(output: Array) -> void:
	var start := maxi(0, output.size() - 40)
	for i in range(start, output.size()):
		var line := str(output[i]).strip_edges()
		if line != "":
			print(line)
