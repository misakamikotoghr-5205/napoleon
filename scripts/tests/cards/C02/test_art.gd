# CardArt：human、占位、缺图、legacy、底图尺寸、9 宫格边距；实例化一张牌的平均耗时。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")


func _initialize() -> void:
	var t := T.new(self, "C02_art")
	_body(t)
	t.finish()


func _body(t) -> void:
	var portrait := "portrait.zhouma"
	t.eq(CardArt.path(portrait), "art/portraits/zhouma.png", "legacy placeholder path")
	t.ok(CardArt.is_placeholder(portrait), "legacy is placeholder")
	t.ok(not CardArt.is_missing(portrait), "legacy file is not the missing block")
	t.eq(CardArt.base_size(portrait), Vector2i(48, 64), "portrait base")
	t.ok(CardArt.texture(portrait) != null, "portrait texture")
	var hair := "item.medicine.aspirin"
	t.eq(CardArt.path(hair), "art/items/aspirin.png", "item placeholder")
	t.ok(CardArt.is_placeholder(hair), "item placeholder flag")
	t.eq(CardArt.base_size(hair), Vector2i(64, 64), "item base")
	# 10-22 能玩版：batch2 定稿图（I-104、I-110）登记为 AI 图，压过原来的 legacy 旧图。
	var ai_art := {"portrait.linsao": "art/ai/portrait/linsao.png", "item.jewelry.hairpin": "art/ai/item/jewelry.hairpin.png"}
	for ai_id in ai_art:
		t.eq(CardArt.path(ai_id), ai_art[ai_id], ai_id + " resolves to its AI art")
		t.ok(not CardArt.is_placeholder(ai_id), ai_id + " AI art is not a placeholder")
		t.ok(CardArt.texture(ai_id) != null, ai_id + " AI texture")
	var manifest: Dictionary = CardDB.read_json(CardArt.MANIFEST)
	var frame := "frame.gold"
	var frame_entry: Dictionary = (manifest.get("art", {}) as Dictionary).get(frame, {})
	t.eq(CardArt.path(frame), _resolved(manifest, frame_entry), "frame path follows the manifest")
	t.eq(CardArt.base_size(frame), Vector2i(int(frame_entry["base"][0]), int(frame_entry["base"][1])), "frame base")
	t.eq(CardArt.nine_margins(frame), _ints(frame_entry.get("nine", [])), "frame nine")
	var frame_path := CardArt.path(frame)
	if frame_path == "":
		t.ok(CardArt.texture(frame) == null, "no frame texture")
		t.ok(CardArt.is_placeholder(frame) and CardArt.is_missing(frame), "frame missing")
	else:
		t.ok(CardArt.texture(frame) != null, "frame texture")
		t.ok(ResourceLoader.exists("res://" + frame_path), "frame file exists")
		var human := str(frame_entry.get("human", ""))
		if frame_path == human and not bool(frame_entry.get("legacy", false)):
			t.ok(not CardArt.is_placeholder(frame), "human frame is not a placeholder")
		elif frame_path == str(frame_entry.get("ai", "")):
			t.ok(not CardArt.is_placeholder(frame), "AI frame is not a placeholder")
		else:
			t.ok(CardArt.is_placeholder(frame), "fallback frame counts as placeholder")
	var unknown := "c02.absent.art"
	var art_map: Dictionary = manifest.get("art", {})
	t.ok(not art_map.has(unknown), "unknown id is not in the manifest")
	t.eq(CardArt.path(unknown), _resolved(manifest, {}), "unknown path")
	t.eq(CardArt.base_size(unknown), Vector2i.ZERO, "unknown base")
	t.eq(CardArt.nine_margins(unknown), [], "unknown nine")
	t.ok(CardArt.is_placeholder(unknown) and CardArt.is_missing(unknown), "unknown missing")
	_synthetic(t)
	CardArt._m = {}
	CardArt._tex = {}
	t.eq(CardArt.base_size(portrait), Vector2i(48, 64), "manifest restored")
	for i in 5:
		var warm := CardWidget.new()
		warm.free()
	var t0 := Time.get_ticks_usec()
	for i in 100:
		var w := CardWidget.new()
		w.free()
	var avg := float(Time.get_ticks_usec() - t0) / 100.0 / 1000.0
	print("C02_instantiate_avg_ms %.3f" % avg)
	t.ok(avg <= 10.0, "instantiate avg ms %.3f" % avg)
	var view := {"uid": "cperf", "def": "p.linsao.1938.pawn_hairpin", "type": "person", "zone": "hand",
		"gold": false, "art": "portrait.linsao", "actions": []}
	var t1 := Time.get_ticks_usec()
	for i in 100:
		var card := CardWidget.new()
		card.set_card(view)
		card.free()
	var set_avg := float(Time.get_ticks_usec() - t1) / 100.0 / 1000.0
	print("C02_set_card_avg_ms %.3f" % set_avg)


func _resolved(manifest: Dictionary, entry: Dictionary) -> String:
	var legacy := bool(entry.get("legacy", false))
	var human := str(entry.get("human", ""))
	var ai := str(entry.get("ai", ""))
	var placeholder := str(entry.get("placeholder", ""))
	var missing := str(manifest.get("missing", ""))
	var human_ok := human != "" and ResourceLoader.exists("res://" + human)
	if human_ok and not legacy:
		return human
	if not OS.has_feature("no_ai") and ai != "" and ResourceLoader.exists("res://" + ai):
		return ai
	if CardShip.is_ship():
		return ""
	if legacy and human_ok:
		return human
	if placeholder != "" and ResourceLoader.exists("res://" + placeholder):
		return placeholder
	if missing != "" and ResourceLoader.exists("res://" + missing):
		return missing
	return ""


func _ints(values: Variant) -> Array:
	var out: Array = []
	if typeof(values) != TYPE_ARRAY:
		return out
	for v in values:
		out.append(int(v))
	return out


func _synthetic(t) -> void:
	CardArt._m = {
		"missing": "art/items/coin.png",
		"art": {
			"t.human": {"base": [16, 16], "human": "art/items/coin.png", "placeholder": "art/items/missing-nope.png"},
			"t.human_over_ai": {"base": [16, 16], "human": "art/items/coin.png", "ai": "art/items/hairpin.png", "placeholder": "art/portraits/linsao.png"},
			"t.ai": {"base": [24, 24], "human": "art/cards/nope.png", "ai": "art/portraits/linsao.png", "placeholder": "art/items/hairpin.png"},
			"t.ph": {"base": [32, 32], "human": "art/cards/nope.png", "ai": "art/ai/nope.png", "placeholder": "art/items/hairpin.png"},
			"t.miss": {"base": [8, 8], "human": "", "placeholder": "art/nope.png"},
			"t.legacy": {"base": [64, 64], "human": "art/items/coin.png",
				"placeholder": "art/items/hairpin.png", "legacy": true},
		},
	}
	CardArt._tex = {}
	t.eq(CardArt.path("t.human"), "art/items/coin.png", "human wins")
	t.ok(not CardArt.is_placeholder("t.human"), "human not placeholder")
	t.ok(not CardArt.is_missing("t.human"), "human not missing")
	t.ok(CardArt.texture("t.human") != null, "human texture")
	t.eq(CardArt.base_size("t.human"), Vector2i(16, 16), "human base")
	t.eq(CardArt.path("t.human_over_ai"), "art/items/coin.png", "human overrides ai automatically")
	t.ok(not CardArt.is_placeholder("t.human_over_ai"), "human over ai is not placeholder")
	t.eq(CardArt.path("t.ai"), "art/portraits/linsao.png", "ai wins when human is absent")
	t.ok(not CardArt.is_placeholder("t.ai"), "ai art is not placeholder")
	t.ok(not CardArt.is_missing("t.ai"), "ai art is not missing")
	t.eq(CardArt.path("t.ph"), "art/items/hairpin.png", "placeholder when human and ai files are absent")
	t.ok(CardArt.is_placeholder("t.ph") and not CardArt.is_missing("t.ph"), "placeholder flags")
	t.eq(CardArt.path("t.miss"), "art/items/coin.png", "falls through to missing")
	t.ok(CardArt.is_missing("t.miss") and CardArt.is_placeholder("t.miss"), "missing flags")
	t.eq(CardArt.path("t.legacy"), "art/items/coin.png", "dev returns legacy file")
	t.ok(CardArt.is_placeholder("t.legacy"), "legacy counts as placeholder")
	t.ok(not CardArt.is_missing("t.legacy"), "legacy file is not the missing block")
