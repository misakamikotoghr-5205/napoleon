# 正文覆盖、参数、各类引用、草稿回退和记录清理。
# 主人 G01；合同 §4.5、§7.9。
extends SceneTree
const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/G01/helper.gd")

func _initialize() -> void:
	var t := T.new(self, "G01_text")
	var root := t.user_dir() + "/cards"
	H.copy_tree("res://data/cards", root)
	H.remove_tree(root + "/text_ai")   # 这里只测人写层和兜底；AI 基础层另有 G01_text_ai
	H.write(root + "/text/test.text.json", {
		"p.linsao.1938.pawn_hairpin": {"title": "TXT_{name}", "lines": {"greet": "TXT_GREETING"}},
		"g01.test": {"t": "TXT_UI_{n}"}, "linsao": {"name": "TXT_PERSON"},
		"item.jewelry.hairpin": {"name": "TXT_ITEM"}, "obs.weigh.match": {"t": "TXT_OBS"}})
	CardText.setup(CardDB.load_all(root, {"only_examples": true}))
	t.eq(CardText.card("p.linsao.1938.pawn_hairpin", "title", {"name": "A"}), "TXT_A", "card params")
	t.eq(CardText.t("p.linsao.1938.pawn_hairpin#lines.greet"), "TXT_GREETING", "dotted card ref")
	t.eq(CardText.ui("g01.test", {"n": 3}), "TXT_UI_3", "ui params")
	t.eq(CardText.person_name("linsao"), "TXT_PERSON", "person")
	t.eq(CardText.item_text("jewelry.hairpin", "name"), "TXT_ITEM", "item")
	t.eq(CardText.obs("obs.weigh.match"), "TXT_OBS", "observation")
	t.ok(not CardText.is_draft("g01.test"), "human ui not draft")
	t.ok(CardText.is_draft("p.linsao.1938.pawn_hairpin#body"), "missing field draft")
	var fallback := CardText.card("p.linsao.1938.pawn_hairpin", "body")
	t.ok(fallback != "", "dev fallback nonempty")
	t.ok(CardText.issued_contains(fallback), "issued registry")
	CardText.setup(CardDB.load_all(root, {"only_examples": true, "ship": true}))
	t.eq(CardText.card("p.linsao.1938.pawn_hairpin", "body"), "", "ship missing text empty")
	t.ok(not CardText.issued_contains("TXT_PERSON"), "ship issued registry empty")
	CardText.setup(null)
	t.ok(not CardText.issued_contains(fallback), "setup clears registry")
	t.finish()
