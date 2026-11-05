# 档案簿只展示已得到的碎片和永久缺口；补齐效果只执行一次。
# 一年后的碎片按当前年代和前一块判断，不进行隐藏随机。
class_name CardDossier
extends RefCounted
const H = preload("res://scripts/cards/rules/rules_helpers.gd")

static func add(ctx: CardCtx, frag: String) -> void:
	var d := ctx.db.def(frag)
	if str(d.get("type", "")) != "dossier_fragment": return
	var person := str(d.get("person", ""))
	var row := _row(ctx, person)
	if (row["gaps"] as Array).has(frag) or (row["have"] as Array).has(frag): return
	(row["have"] as Array).append(frag)
	(row["new"] as Array).append(frag)
	ctx.emit(&"dossier_changed", [person, frag, &"added"])
	CardFirsts.mark(ctx, &"dossier", {"person": person})
	if complete(ctx, person) and not bool(row.get("completed", false)):
		row["completed"] = true
		ctx.run(_page(ctx, person).get("effects", {}).get("on_complete", []), "G03:dossier/" + person + "/on_complete")

static func gap(ctx: CardCtx, frag: String) -> void:
	var d := ctx.db.def(frag)
	if str(d.get("type", "")) != "dossier_fragment": return
	var person := str(d.get("person", ""))
	var row := _row(ctx, person)
	if (row["gaps"] as Array).has(frag): return
	(row["have"] as Array).erase(frag)
	(row["new"] as Array).erase(frag)
	(row["gaps"] as Array).append(frag)
	ctx.emit(&"dossier_changed", [person, frag, &"gap"])
	CardFirsts.mark(ctx, &"dossier_gap", {"person": person})

static func year_after(ctx: CardCtx) -> Array:
	var era := str(ctx.db.stage(int(ctx.state.ns("loop").get("stage", 0))).get("era", ""))
	return _year_after(ctx, era)

static func _year_after(ctx: CardCtx, era: String) -> Array:
	var added: Array = []
	for frag in ctx.db.ids_of(&"dossier_fragment"):
		var d := ctx.db.def(frag)
		var eras: Array = d.get("era", [])
		if str(d.get("kind", "")) != "year_after" or not (eras.has(era) or eras.has("*")): continue
		if has_fragment(ctx, str(d.get("year_after_of", ""))) and not has_fragment(ctx, frag):
			add(ctx, frag)
			if has_fragment(ctx, frag):
				added.append(frag)
				CardFirsts.mark(ctx, &"year_after", {"person": str(d.get("person", ""))})
	return added

static func view(ctx: CardCtx, person: String = "") -> Dictionary:
	var pages: Array = []
	var dossier: Dictionary = H.peek(ctx).get("dossier", {})
	var persons := dossier.keys()
	persons.sort()
	for pid in persons:
		if person != "" and str(pid) != person: continue
		var row: Dictionary = dossier[pid]
		var frags: Array = []
		for id in (row.get("have", []) as Array) + (row.get("gaps", []) as Array):
			var d := ctx.db.def(str(id))
			frags.append({"id": str(id), "order": int(d.get("order", 0)), "era": d.get("era", []), "kind": str(d.get("kind", "")), "state": "gap" if (row.get("gaps", []) as Array).has(id) else "have", "new": (row.get("new", []) as Array).has(id)})
		frags.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]) if a["order"] != b["order"] else str(a["id"]) < str(b["id"]))
		pages.append({"person": str(pid), "complete": complete(ctx, str(pid)), "new": (row.get("new", []) as Array).size(), "fragments": frags})
	return {"pages": pages}

static func has_fragment(ctx: CardCtx, frag: String) -> bool:
	var person := str(ctx.db.def(frag).get("person", ""))
	return (H.peek(ctx).get("dossier", {}).get(person, {}).get("have", []) as Array).has(frag)

static func complete(ctx: CardCtx, person: String) -> bool:
	var page := _page(ctx, person)
	var frags: Array = page.get("fragments", [])
	if frags.is_empty(): return false
	for frag in frags:
		if not has_fragment(ctx, str(frag)): return false
	return true

static func _page(ctx: CardCtx, person: String) -> Dictionary:
	for id in ctx.db.ids_of(&"dossier_page"):
		var d := ctx.db.def(id)
		if str(d.get("person", "")) == person: return d
	return {}

static func _row(ctx: CardCtx, person: String) -> Dictionary:
	var dossier: Dictionary = H.state(ctx)["dossier"]
	if not dossier.has(person): dossier[person] = {"have": [], "gaps": [], "new": []}
	return dossier[person]

static func clear_new(ctx: CardCtx) -> void:
	var dossier: Dictionary = H.state(ctx)["dossier"]
	var persons := dossier.keys()
	persons.sort()
	for person in persons: dossier[person]["new"] = []
