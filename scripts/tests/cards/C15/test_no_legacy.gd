# C15：不读旧电码本、不读旧电报面板；结果只有五个键；界面文字走 CardText。合同 §11.2。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/C15/harness.gd")


func _initialize() -> void:
	var t := T.new(self, "C15_no_legacy")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	var pct := String.chr(37)
	var banned := ["data/" + "codebook.json", "scripts/ui/" + "telegraph_" + "panel.gd"]
	var files := _gd_files("res://scripts/cards/minigames/fragments")
	files.append_array(_gd_files("res://scripts/cards/minigames/decode"))
	t.ok(files.size() >= 7, "scripts present")
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		for needle in banned:
			t.ok(src.find(needle) < 0, path + " avoids " + needle)
		t.ok(src.find(pct) < 0, path + " has no percent sign")
		t.ok(src.find("&\"good\"") < 0 and src.find("&\"bad\"") < 0 and src.find("&\"danger\"") < 0,
			path + " uses no right / wrong colours")
		t.ok(_ascii(src), path + " is ASCII")
	var dec_src := FileAccess.get_file_as_string("res://scripts/cards/minigames/decode/decode_game.gd")
	t.ok(dec_src.find("CardText.card(") >= 0 and dec_src.find("\"word\"") >= 0, "code book words read the contract field word")
	t.ok(dec_src.find("obs/decode.json") < 0, "decode does not read the observation catalog itself")
	var frag_cat = CardDB.read_json("res://data/cards/minigames/obs/fragments.json")
	var dec_cat = CardDB.read_json("res://data/cards/minigames/obs/decode.json")
	_catalog(t, frag_cat, "fragments")
	_catalog(t, dec_cat, "decode")
	var ctx: Dictionary = H.open_game(self, H.FRAG, H.params("ticket196.json"))
	await t.frames(2)
	var bad: PackedStringArray = t.all_text_from_cardtext(ctx["game"])
	t.eq(bad, PackedStringArray(), "frag text")
	var box := H.take(ctx["game"])
	ctx["game"].autoplay(0.9)
	_result(t, box["r"], frag_cat)
	var dec: Dictionary = H.open_game(self, H.DEC, H.params("telegram.json"))
	await t.frames(2)
	var bad2: PackedStringArray = t.all_text_from_cardtext(dec["game"])
	t.eq(bad2, PackedStringArray(), "decode text")
	var dbox := H.take(dec["game"])
	dec["game"].autoplay(0.9)
	_result(t, dbox["r"], dec_cat)
	var led: Dictionary = H.open_game(self, H.DEC, H.params("ledger.json"))
	await t.frames(1)
	var bad3: PackedStringArray = t.all_text_from_cardtext(led["game"])
	t.eq(bad3, PackedStringArray(), "ledger text")
	t.finish()


func _ascii(src: String) -> bool:
	for i in range(src.length()):
		if src.unicode_at(i) > 127:
			return false
	return true


func _gd_files(dir: String) -> Array:
	var out: Array = []
	for name in DirAccess.get_files_at(dir):
		if name.ends_with(".gd"):
			out.append(dir + "/" + name)
	return out


func _catalog(t, doc: Dictionary, kind: String) -> void:
	t.eq(str(doc["_meta"]["kind"]), kind, "kind " + kind)
	for key in doc["obs"].keys():
		var s := str(key)
		t.ok(s.begins_with("obs." + kind + "."), "prefix " + s)
		for w in CardIds.VERDICT_WORDS:
			var hit := s.split(".").has(w) or s.contains("_" + w) or s.contains(w + "_")
			t.ok(not hit, "no verdict " + s)
		var fid := str(doc["obs"][key]["fidelity"])
		# "any" and "hedge" come with the appraisal redesign (DESIGN 3.2, WP1 owns the catalogs).
		t.ok(fid in ["clear", "partial", "vague", "any"], "fidelity " + s)
		var hedge = doc["obs"][key].get("hedge", {})
		if typeof(hedge) == TYPE_DICTIONARY:
			for v in (hedge as Dictionary).values():
				t.ok(str(v) == "" or (doc["obs"] as Dictionary).has(str(v)), "hedge target in catalog " + s)


func _result(t, result: Dictionary, cat: Dictionary) -> void:
	var got: Array = []
	for k in result.keys():
		got.append(str(k))
	got.sort()
	t.eq(got, ["aborted", "measures", "minutes", "observations", "quality_permille"], "five keys")
	t.eq(typeof(result["quality_permille"]), TYPE_INT, "int quality")
	t.eq(result["aborted"], false, "finished")
	for key in result["observations"]:
		t.ok((cat["obs"] as Dictionary).has(str(key)), "known " + str(key))
