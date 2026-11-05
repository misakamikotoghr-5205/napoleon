# 调用只读 ItemGen；临时缓存和中文文字用后丢弃，只存整数和 ASCII。
# G04；规则文件用千分比，运行时转换为旧生成器的浮点参数。spot 痕迹带 FlawRender 的画法名 look；craft 1 = 少见或上等货（假痕更细，鉴定改版）。
class_name CardItems
extends RefCounted
const E = preload("res://scripts/cards/economy/economy_support.gd")

static func generate(ctx: CardCtx, key: Array, template_or_cat: String) -> Dictionary:
	E.ensure(ctx)
	if key.is_empty() or str(key[0]) != "c":
		return {"ok": false, "err": "bad_args"}
	var e := ctx.state.ns("econ")
	if not e.has("generated"):
		e["generated"] = {}
	var cache_key := JevRng.canon(key + [template_or_cat])
	if e["generated"].has(cache_key):
		return {"ok": true, "err": "", "item": str(e["generated"][cache_key])}
	if not ctx.ledger.has_meta("item_templates"):
		ctx.ledger.set_meta("item_templates", templates())
	var defs: Dictionary = ctx.ledger.get_meta("item_templates").duplicate()
	var cat := template_or_cat.get_slice(".", 0)
	var cats: Dictionary = (defs.get("categories", {}) as Dictionary).duplicate()
	defs["categories"] = cats
	if template_or_cat.contains("."):
		var selected: Array = []
		for variant in cats.get(cat, {}).get("variants", []):
			if str(variant["id"]) == template_or_cat.get_slice(".", 1):
				selected.append(variant)
		if selected.is_empty():
			return {"ok": false, "err": "unknown_template"}
		cats[cat] = (cats[cat] as Dictionary).duplicate()
		cats[cat]["variants"] = selected
	var raw := ItemGen.generate(defs, _pack(ctx), {"seed": ctx.seed(), "day": ctx.abs_day()}, key, cat)
	if raw.is_empty():
		return {"ok": false, "err": "unknown_template"}
	var template := str(raw["cat"]) + "." + str(raw["template_id"])
	var id: String = ctx.ledger.add_item({"template": template, "cat": str(raw["cat"])}, "world", "customer")
	ctx.ledger.items[id]["history"] = ["generated"]
	var base: int = 1
	for variant in defs["categories"][raw["cat"]]["variants"]:
		if str(variant["id"]) == str(raw["template_id"]):
			base = int(variant["base_price"])
	var m := {"template": template, "cat": str(raw["cat"]), "condition_permille": int(round(float(raw["condition"]) * 1000)),
		"base_price": base, "market": int(raw["market"]), "fake": bool(raw["fake"]), "stolen": bool(raw["stolen"]),
		"art": "item." + template, "observations": [], "on_shelf_since": -1, "spot": _layout(raw, template),
		"craft": 1 if bool(raw.get("rare", false)) or str(raw.get("grade", "")) == "a" else 0}
	e["items_meta"][id] = m
	e["generated"][cache_key] = id
	E.sync(ctx)
	return {"ok": true, "err": "", "item": id}

static func templates() -> Dictionary:
	var base = CardDB.read_json("res://data/town/item_templates.json")
	var out: Dictionary = base if typeof(base) == TYPE_DICTIONARY else {}
	var extra = CardDB.read_json("res://data/cards/items/templates_extra.json")
	if typeof(extra) != TYPE_DICTIONARY:
		extra = CardDB.read_json("res://data/cards/_examples/items/templates_extra.json")
	if typeof(extra) == TYPE_DICTIONARY:
		var cats: Dictionary = out.get("categories", {})
		var ids: Array = extra.get("categories", {}).keys()
		ids.sort()
		for k in ids:
			if not cats.has(k):
				cats[k] = extra["categories"][k]
			else:
				var found: Array = []
				for row in cats[k].get("variants", []):
					found.append(str(row["id"]))
				for row in extra["categories"][k].get("variants", []):
					if not found.has(str(row["id"])):
						cats[k]["variants"].append(row)
		out["categories"] = cats
	return out

static func _pack(ctx: CardCtx) -> Dictionary:
	var cfg: Dictionary = ctx.rules("items_balance").get("items", {})
	var out: Dictionary = {}
	for k in cfg.keys():
		var v = cfg[k]
		if k == "quality":
			var rows: Array = []
			for row in v:
				rows.append({"id": str(row["id"]), "weight": int(row["weight"]), "mult": float(row["mult_permille"]) / 1000.0})
			out[k] = rows
		elif k in ["rare_pity_after"]:
			out[k] = int(v)
		elif typeof(v) == TYPE_ARRAY:
			out[k] = [float(v[0]) / 1000.0, float(v[1]) / 1000.0]
		else:
			out[k] = float(v) / 1000.0
	return {"balance": {"items": out}}

static func _layout(raw: Dictionary, template: String) -> Dictionary:
	var parts: Array = []
	for p in raw.get("parts", []):
		var r: Array = p.get("rect", [0, 0, 8, 8])
		parts.append({"id": str(p["id"]), "rect": [int(r[0]), int(r[1]), int(r[2]), int(r[3])],
			"tool": "lens" if str(p.get("tool", "")) == "magnifier" else "eye"})
	var marks: Array = []
	for f in raw.get("flaws", []):
		marks.append({"part": str(f["part"]), "kind": "wear" if bool(f.get("benign", false)) else "differs", "look": str(f.get("kind", "")),
			"fine": 800 if bool(f.get("fine", false)) else 300, "seed": int(f.get("seed", 0))})
	return {"parts": parts, "marks": marks, "atlas_art": "item." + template, "ink": 3,
		"tools": ["eye", "lens", "atlas"], "atlas_open": true}
