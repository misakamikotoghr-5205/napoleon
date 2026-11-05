# K12：清单里每个美术 id 都能加载，底图尺寸与贴图一致；新手指引那一组不是缺图方块。
# 1.3：柜台三张背景 320×180；批注纸 frame.guide_note 24×24 且带 nine。
# 合同：docs/cards/CARDS_INTERFACES.md §4.8、§7.8；docs/handoff_cards/K12_art-pipeline.md。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")

const GUIDE_PORTRAITS: PackedStringArray = [
	"portrait.brother", "portrait.zhouma", "portrait.hu2", "portrait.suanming", "portrait.postman",
]
const GUIDE_ICONS: PackedStringArray = [
	"icon.obj.notice", "icon.obj.almanac", "icon.obj.brother_ledger",
]


func _initialize() -> void:
	var t := T.new(self, "K12_art_load")
	var doc = CardDB.read_json("res://data/cards/art/manifest.json")
	t.ok(typeof(doc) == TYPE_DICTIONARY, "manifest json")
	if typeof(doc) != TYPE_DICTIONARY:
		t.finish()
		return
	var art: Dictionary = doc.get("art", {})
	var missing := str(doc.get("missing", ""))
	t.ok(art.size() > 0, "manifest has ids")
	t.ok(FileAccess.file_exists("res://" + missing), "missing tile exists")
	var ids: Array = art.keys()
	ids.sort()
	for id in ids:
		var key := str(id)
		var entry: Dictionary = art[id]
		var tex := CardArt.texture(key)
		t.ok(tex != null, "texture " + key)
		if tex == null:
			continue
		var base := CardArt.base_size(key)
		t.ok(tex.get_width() == base.x and tex.get_height() == base.y, "size " + key)
		var ph := str(entry.get("placeholder", ""))
		t.ok(ph != "" and FileAccess.file_exists("res://" + ph), "placeholder file " + key)
	for id2 in GUIDE_PORTRAITS:
		_guide(t, art, id2, missing, Vector2i(48, 64), true)
	for id3 in GUIDE_ICONS:
		_guide(t, art, id3, missing, Vector2i(24, 24), false)
	_guide(t, art, "frame.guide_bubble", missing, Vector2i(36, 50), true)
	for bg_id in ["bg.counter.day", "bg.counter.dusk", "bg.counter.night"]:
		t.ok(art.has(bg_id), "manifest has " + bg_id)
		if not art.has(bg_id):
			continue
		t.eq(CardArt.base_size(bg_id), Vector2i(320, 180), bg_id + " base")
		var bg_tex := CardArt.texture(bg_id)
		t.ok(bg_tex != null, "texture " + bg_id)
		if bg_tex != null:
			t.eq(Vector2i(bg_tex.get_width(), bg_tex.get_height()), Vector2i(320, 180), bg_id + " pixels")
		var bg_path := CardArt.path(bg_id)
		t.ok(bg_path != "" and bg_path != missing, bg_id + " is not the missing tile")
	_guide(t, art, "frame.guide_note", missing, Vector2i(24, 24), true)
	t.finish()


func _guide(t, art: Dictionary, id: String, missing: String, size: Vector2i, want_nine: bool) -> void:
	t.ok(art.has(id), "manifest has " + id)
	if not art.has(id):
		return
	var entry: Dictionary = art[id]
	var ph := str(entry.get("placeholder", ""))
	t.ok(FileAccess.file_exists("res://" + ph), "file " + id)
	t.eq(CardArt.base_size(id), size, id + " base")
	var path := CardArt.path(id)
	t.ok(path != "" and path != missing, id + " is not the missing tile")
	if want_nine and id.begins_with("frame."):
		t.eq(entry.get("nine", []), [6, 6, 6, 6], id + " nine")
