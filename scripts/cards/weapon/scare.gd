# K18：留着短枪时，1940 起给普通客人多一句吓唬。只记机制，不改查询。
# 动手不在这一版。合同 1.4，发出者仍算 G03（选项检定）。
extends RefCounted

const PISTOL := "kp.pistol"
const CHOICE := "scare"
const STAGE_MIN := 2


static func attach(ctx: CardCtx, uid: String, base: Array) -> Array:
	if not _eligible(ctx, uid) or _has(base):
		return base
	var out: Array = base.duplicate()
	out.append(_choice())
	return out


static func mark_dealt(ctx: CardCtx, uid: String) -> void:
	if not _eligible(ctx, uid):
		return
	var d := CardPiles.def_of(ctx, uid)
	CardFirsts.mark(ctx, &"scare", {"uid": uid, "def": str(d.get("id", ""))})


static func _has(base: Array) -> bool:
	for choice in base:
		if typeof(choice) == TYPE_DICTIONARY and str(choice.get("id", "")) == CHOICE:
			return true
	return false


static func _eligible(ctx: CardCtx, uid: String) -> bool:
	var d := CardPiles.def_of(ctx, uid)
	if str(d.get("type", "")) != "person":
		return false
	if bool(d.get("gold", false)) or str(d.get("story_node", "")) != "":
		return false
	if int(ctx.state.ns("loop").get("stage", 0)) < STAGE_MIN:
		return false
	return _pistol_kept(ctx)


static func _pistol_kept(ctx: CardCtx) -> bool:
	for uid in CardPiles.list(ctx, &"kept"):
		if str(CardPiles.card(ctx, uid).get("def", "")) == PISTOL:
			return true
	return false


static func _choice() -> Dictionary:
	return {
		"id": CHOICE,
		"check": {
			"need": 1,
			"slots": [{
				"id": "nerve",
				"accepts": ["self", "contact"],
				"attr": "nerve",
				"required": true,
			}],
			"on_success": [
				{"op": "flag", "key": "weapon_scare_yield", "value": true},
				{"op": "heat", "delta": 1},
				{"op": "rep", "delta": -1},
				{"op": "counter", "key": "weapon_scare_uses", "delta": 1},
			],
			"on_fail": [
				{"op": "flag", "key": "weapon_scare_reported", "value": true},
				{"op": "heat", "delta": 3},
				{"op": "counter", "key": "weapon_scare_uses", "delta": 1},
			],
		},
	}
