# 四种锚点按条件登记；换牌注销旧 uid；出树全部注销。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const S = preload("res://scripts/tests/cards/C02/support.gd")


func _initialize() -> void:
	var t := T.new(self, "C02_anchors")
	t.run_async(_body.bind(t))


func _body(t) -> void:
	S.setup_db()
	var states := S.states()
	var keep: Dictionary = states["keep_on"]
	var w := S.mount(self, keep, &"hand", Vector2(80, 80))
	await t.frames(1)
	var uid := str(keep["uid"])
	t.ok(t.anchor_ok(StringName("a.card@" + uid)), "card anchor")
	t.ok(t.anchor_ok(StringName("a.card.keep@" + uid)), "keep anchor")
	t.ok(not CardAnchors.has(StringName("a.card.gold@" + uid)), "no gold anchor")
	t.ok(not CardAnchors.has(StringName("a.card.days@" + uid)), "no days yet")
	var exp: Dictionary = states["expires_1"].duplicate(true)
	exp["actions"] = [{"id": "keep", "enabled": true, "reason_key": ""}]
	w.set_card(exp)
	await t.frames(1)
	t.ok(t.anchor_ok(StringName("a.card@" + uid)), "card still")
	t.ok(t.anchor_ok(StringName("a.card.keep@" + uid)), "keep still")
	t.ok(t.anchor_ok(StringName("a.card.days@" + uid)), "days anchor")
	var gold: Dictionary = states["gold"]
	w.set_card(gold)
	await t.frames(1)
	t.ok(t.anchor_ok(StringName("a.card@" + uid)), "gold card")
	t.ok(t.anchor_ok(StringName("a.card.gold@" + uid)), "gold anchor")
	t.ok(not CardAnchors.has(StringName("a.card.keep@" + uid)), "gold drops keep anchor")
	var life: Dictionary = states["life"]
	var life_uid := str(life["uid"])
	w.set_card(life)
	await t.frames(1)
	t.ok(not CardAnchors.has(StringName("a.card@" + uid)), "old uid gone")
	t.ok(not CardAnchors.has(StringName("a.card.gold@" + uid)), "old gold gone")
	t.ok(not CardAnchors.has(StringName("a.card.keep@" + uid)), "old keep gone")
	t.ok(not CardAnchors.has(StringName("a.card.days@" + uid)), "old days gone")
	t.ok(t.anchor_ok(StringName("a.card@" + life_uid)), "life card")
	t.ok(t.anchor_ok(StringName("a.card.days@" + life_uid)), "life days")
	t.ok(not CardAnchors.has(StringName("a.card.gold@" + life_uid)), "life not gold")
	w.queue_free()
	await t.frames(1)
	t.ok(not CardAnchors.has(StringName("a.card@" + life_uid)), "freed card")
	t.ok(not CardAnchors.has(StringName("a.card.days@" + life_uid)), "freed days")
	t.ok(not CardAnchors.has(StringName("a.card.gold@" + uid)), "freed gold")
