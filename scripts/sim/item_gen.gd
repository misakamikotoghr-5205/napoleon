# 随机当物与柜台规格。只改模拟状态；运行时定义由 TownSim 注册到本次世界。
# 所有平衡参数来自 town_pack.balance.items，模板只存内容与物件基价。
class_name ItemGen
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")

# 同一语义键只能生成一次。保底计数与缓存一起存档，不会因重看柜台而重摇。
static func generate(templates: Dictionary, pack: Dictionary, s: Dictionary, key: Array, category: String = "") -> Dictionary:
	var categories: Dictionary = templates.get("categories", {})
	var cfg: Dictionary = pack.get("balance", {}).get("items", {})
	if categories.is_empty() or cfg.is_empty():
		return {}
	var cache: Dictionary = s.get("item_gen", {"items": {}, "rare_misses": 0, "count": 0})
	var semantic_key: Array = key.duplicate(true)
	semantic_key.append(category)
	var cache_key: String = R.canon(semantic_key)
	var generated: Dictionary = cache.get("items", {})
	if generated.has(cache_key):
		return generated[cache_key].duplicate(true)
	var cat: String = category
	if not categories.has(cat):
		var rows: Array = []
		var ids: Array = categories.keys()
		ids.sort()
		for id in ids:
			rows.append([str(id), float(categories[id].get("weight", 1.0))])
		cat = R.weighted_choice(rows, _draw(s, "item_category", key))
	var content: Dictionary = categories[cat]
	var variants: Array = content.get("variants", [])
	if variants.is_empty():
		return {}
	var variant_rows: Array = []
	for variant in variants:
		variant_rows.append([str(variant["id"]), float(variant.get("weight", 1.0))])
	var variant_id: String = R.weighted_choice(variant_rows, _draw(s, "item_variant", semantic_key))
	var selected: Dictionary = {}
	for variant in variants:
		if str(variant["id"]) == variant_id:
			selected = variant
			break
	var quality_rows: Array = []
	for quality in cfg.get("quality", []):
		quality_rows.append([str(quality["id"]), float(quality["weight"])])
	if quality_rows.is_empty():
		return {}
	var grade: String = R.weighted_choice(quality_rows, _draw(s, "item_quality", semantic_key))
	var quality_mult: float = 1.0
	for quality in cfg["quality"]:
		if str(quality["id"]) == grade:
			quality_mult = float(quality["mult"])
			break
	var condition: float = _range(cfg["condition"], _draw(s, "item_condition", semantic_key))
	var fake: bool = _draw(s, "item_fake", semantic_key) < float(cfg["fake_rate"]) and bool(content.get("can_fake", true))
	var stolen: bool = _draw(s, "item_origin", semantic_key) < float(cfg["stolen_rate"])
	var misses: int = int(cache.get("rare_misses", 0))
	var rare_rate: float = minf(float(cfg["rare_rate_max"]), float(cfg["rare_rate"]) + maxf(0.0, float(int(s.get("day", 0)) - 1)) * float(cfg["rare_gain_per_day"]) + float(misses) * float(cfg["rare_pity_gain"]))
	var pity_after: int = int(cfg["rare_pity_after"])
	var rare: bool = _draw(s, "item_rarity", semantic_key) < rare_rate or (pity_after > 0 and misses >= pity_after - 1)
	var wear_mult: float = maxf(float(cfg["condition_floor"]), condition)
	var value: int = maxi(1, int(round(float(selected["base_price"]) * quality_mult * wear_mult * (float(cfg["rare_mult"]) if rare else 1.0))))
	var market: int = maxi(1, int(round(float(value) * float(cfg["fake_value_mult"])))) if fake else value
	var item_id: String = "gen_item_" + R.sha256_bytes(R.canon([int(s.get("seed", 0)), semantic_key])).hex_encode()
	var initial_est: Array = _estimate(value, cfg["estimate"])
	var actual_est: Array = _estimate(market, cfg["inspect_estimate"])
	var tags: Array = selected.get("tags", []).duplicate(true)
	if rare:
		tags.append(str(content.get("rare_tag", "少见式样")))
	var item: Dictionary = {
		"id": item_id, "def_id": item_id, "template_id": variant_id,
		"name": str(selected["name"]), "cat": cat, "cat_cn": str(content["label"]),
		"market": market, "claimed": value if fake else 0, "fake": fake,
		"grade": grade, "quality": grade, "condition": condition,
		"origin": "stolen" if stolen else "normal", "stolen": stolen,
		"contraband": bool(selected.get("contraband", false)),
		"rarity": "rare" if rare else "common", "rare": rare,
		"est": initial_est, "suggest": int(round(float(value) * float(cfg["buy_suggest"]))),
		"ask_w": float(value), "weight": str(selected.get("weight_text", "")),
		"tags": tags, "sprite": str(selected.get("sprite", "")),
		"ticket_condition": str(selected.get("ticket_condition", selected.get("material", ""))) + "，" + str(grade) + "等，成色约%d成" % maxi(1, int(round(condition * 10.0))),
		"parts": _parts(content, selected, fake, stolen, rare, condition, cfg, actual_est)
	}
	_appraise(templates, item, s, semantic_key)
	generated[cache_key] = item.duplicate(true)
	cache["items"] = generated
	cache["rare_misses"] = 0 if rare else misses + 1
	cache["count"] = int(cache.get("count", 0)) + 1
	s["item_gen"] = cache
	return item

# 来访意图以客人的视角命名，mode 以当铺的视角命名。
# 没有可出售的库存时改为客人拿当物来询价，绝不凭空增添店内库存。
static func session(templates: Dictionary, pack: Dictionary, s: Dictionary, visit: Dictionary, world = null) -> Dictionary:
	var cfg: Dictionary = pack.get("balance", {}).get("items", {})
	if cfg.is_empty():
		return {}
	var who: String = str(visit.get("who", ""))
	var visit_id: String = str(visit.get("id", "visit"))
	var day: int = int(s.get("day", 0))
	var key: Array = [day, visit_id, who]
	var intent: String = str(visit.get("intent", "pawn"))
	var mode: String = "sell" if intent == "buy" else ("pawn" if intent == "pawn" or intent == "redeem" else "buy")
	var spec: Dictionary = {
		"id": "gen_d%d_%s" % [day, visit_id], "npc": who, "mode": mode,
		"show_floor": false, "hard_floor": false, "fund_button": false,
		"min_inspect": 0, "split": false, "hint": "",
		"pre": [], "intro": [], "on_inspect": {}, "extras": [], "deals": [],
		"on_accept": [], "on_leave": [], "outro": [], "post": [],
		"_item_defs": {}, "_npc_def": _npc_def(templates, pack, who)
	}
	if mode == "sell":
		var stock: Array = _stock(s, world)
		var stock_defs: Array = []
		var prices: Dictionary = {}
		var total: int = 0
		var est_lo: int = 0
		var est_hi: int = 0
		var category: String = str(visit.get("item", ""))
		for item in stock:
			if category != "" and str(item.get("cat", "")) != category:
				continue
			var def_id: String = str(item.get("def_id", item.get("id", "")))
			if def_id == "" or stock_defs.has(def_id):
				continue
			stock_defs.append(def_id)
			var base_market: int = int(item.get("market", 0))
			var market_now: int = int(round(float(base_market) * _price_mod(pack, s, item)))
			var item_key: Array = key + [def_id]
			prices[def_id] = {
				"offer": maxi(1, int(round(float(base_market) * _range(cfg["sell_offer"], _draw(s, "item_buyer_offer", item_key))))),
				"max": maxi(1, int(round(float(base_market) * _range(cfg["sell_max"], _draw(s, "item_buyer_max", item_key)))))
			}
			total += market_now
			var est: Array = item.get("est", [market_now, market_now])
			est_lo += int(est[0])
			est_hi += int(est[1])
			if stock_defs.size() >= int(cfg["buyer_item_limit"]):
				break
		if not stock_defs.is_empty():
			spec["stock"] = stock_defs
			spec["buyer_prices"] = prices
			spec["ask"] = int(round(float(total) * float(cfg["sell_offer"][0])))
			spec["floor"] = int(round(float(total) * float(cfg["sell_max"][1])))
			spec["suggest"] = total
			spec["est"] = [est_lo, est_hi]
			spec["split"] = stock_defs.size() > 1
			spec["intro"] = [{"op": "say", "who": who, "text": str(templates.get("lines", {}).get("buy", "掌柜的，我想看看柜上的货。"))}]
			return spec
		mode = "pawn"
		spec["mode"] = mode
	var item: Dictionary = generate(templates, pack, s, key, str(visit.get("item", "")))
	if item.is_empty():
		return {}
	if intent == "sell_stolen":
		item["stolen"] = true
		item["origin"] = "stolen"
		var categories: Dictionary = templates.get("categories", {})
		var content: Dictionary = categories.get(item["cat"], {})
		for part in item["parts"]:
			if str(part["id"]) == "provenance":
				part["text"] = str(content.get("stolen_text", "底下有被刮掉的旧主人记号，来路需要问清。"))
				part["tell"] = true
				break
		_add_stolen_flaw(templates, item, s, key)
	var item_id: String = str(item["def_id"])
	spec["_item_defs"][item_id] = item
	spec["items"] = [{"def": item_id}]
	var claimed: int = int(item["claimed"]) if bool(item["fake"]) else int(item["market"])
	var current_value: int = maxi(1, int(round(float(claimed) * _price_mod(pack, s, item))))
	var ask_range: Array = cfg["pawn_ask"] if mode == "pawn" else cfg["buy_ask"]
	var floor_range: Array = cfg["pawn_floor"] if mode == "pawn" else cfg["buy_floor"]
	var ask: int = maxi(1, int(round(float(current_value) * _range(ask_range, _draw(s, "item_ask", key)))))
	var floor_v: int = mini(ask, maxi(1, int(round(float(current_value) * _range(floor_range, _draw(s, "item_floor", key))))))
	spec["ask"] = ask
	spec["floor"] = floor_v
	spec["suggest"] = int(round(float(current_value) * float(cfg["pawn_suggest"] if mode == "pawn" else cfg["buy_suggest"])))
	spec["est"] = _estimate(current_value, cfg["estimate"])
	var lines: Dictionary = templates.get("lines", {})
	var line: String = str(lines.get("pawn" if mode == "pawn" else "sell", "掌柜的，看看这件东西能值多少。"))
	spec["intro"] = [{"op": "say", "who": who, "text": line}]
	if mode == "pawn":
		spec["terms"] = {"days": int(cfg["pawn_days"]), "rate_month": float(cfg["pawn_rate"]), "condition": str(item["ticket_condition"])}
	return spec

static func _parts(content: Dictionary, variant: Dictionary, fake: bool, stolen: bool, rare: bool, condition: float, cfg: Dictionary, estimate: Array) -> Array:
	var condition_range: Array = cfg["condition"]
	var well_kept: bool = condition >= (float(condition_range[0]) + float(condition_range[1])) / 2.0
	return [
		{"id": "material", "label": str(content.get("material_label", "看质地")), "text": str(variant.get("material", "表面纹理清楚。")), "tool": "hand", "rect": [4, 4, 56, 18]},
		{"id": "condition", "label": str(content.get("condition_label", "看成色")), "text": str(variant.get("good_text" if well_kept else "worn_text", "有日常使用留下的磨损。")), "tool": "hand", "rect": [4, 24, 56, 18]},
		{"id": "authenticity", "label": str(content.get("authenticity_label", "细看做工与款记")), "text": str(variant.get("fake_text" if fake else "real_text", "做工与外观相合。")) + (str(content.get("rare_text", "式样比寻常货少见。")) if rare else ""), "tool": "magnifier", "rect": [4, 44, 28, 16], "tell": fake, "est": estimate.duplicate()},
		{"id": "provenance", "label": str(content.get("provenance_label", "翻看旧记号")), "text": str(content.get("stolen_text" if stolen else "normal_text", "未见特别记号。")), "tool": "hand", "rect": [34, 44, 26, 16], "tell": stolen}
	]

# ---------------- 验货“找不同”：部位落在图上的哪儿、画哪些破绽 / 旧痕 ----------------
# 只用本物品语义键的确定抽签（与价钱、真假的抽签分开的域，不改动既有的数值）。
# 选定的位置和破绽写进物品定义（parts[].rect、flaws[]），随存档走；画法见 scripts/core/flaw_render.gd。
const SLOTS := ["authenticity", "provenance", "material", "condition"]
const BENIGN_NOTES := {"shine": "这一处磨得发亮", "scuff": "有几道擦痕", "repair": "有一道旧补的针脚", "chip": "边上磕了个小口", "watermark": "有一圈旧水渍", "stain": "有一块旧污渍", "yellow": "有些发黄的粒子"}

static func _appraise(templates: Dictionary, item: Dictionary, s: Dictionary, key: Array) -> void:
	var rules: Dictionary = templates.get("appraise", {})
	var cat_rules: Dictionary = rules.get("categories", {}).get(str(item["cat"]), {})
	var sprite_key: String = str(item.get("sprite", ""))
	if sprite_key == "":
		sprite_key = "proc:" + str(item.get("template_id", ""))
	var spots: Dictionary = rules.get("sprites", {}).get(sprite_key, {})
	if spots.is_empty():
		return
	var used: Array = []
	var rects: Dictionary = {}
	for slot in SLOTS:
		var pool: Array = spots.get(slot, spots.get("pool", []))
		var free: Array = []
		for r in pool:
			if not used.has(r):
				free.append(r)
		if free.is_empty():
			for r in spots.get("pool", []):
				if not used.has(r):
					free.append(r)
		if free.is_empty():
			continue
		var pick: Array = free[mini(free.size() - 1, int(floor(_draw(s, "item_spot_" + slot, key) * float(free.size()))))]
		used.append(pick)
		rects[slot] = pick.duplicate()
	for part in item["parts"]:
		if rects.has(str(part["id"])):
			part["rect"] = rects[str(part["id"])].duplicate()
	var flaws: Array = []
	if bool(item["fake"]):
		flaws.append(_flaw(cat_rules.get("fake", ["speck"]), "authenticity", true, false, "", s, key, "fake"))
	var condition_part: Dictionary = _part(item, "condition")
	if str(condition_part.get("text", "")) != "" and _is_worn_text(templates, item, str(condition_part["text"])):
		var kind := _choice(cat_rules.get("worn", ["scuff"]), s, "item_flaw_worn_kind", key)
		flaws.append(_flaw([kind], "condition", false, true, str(BENIGN_NOTES.get(kind, "有些旧痕")), s, key, "worn"))
	elif _draw(s, "item_flaw_wear", key) < float(cat_rules.get("wear_rate", 0.4)):
		var kind2 := _choice(cat_rules.get("wear", ["scuff"]), s, "item_flaw_wear_kind", key)
		flaws.append(_flaw([kind2], "material", false, true, str(BENIGN_NOTES.get(kind2, "有些旧痕")), s, key, "wear"))
	item["flaws"] = flaws
	if bool(item["stolen"]):
		_add_stolen_flaw(templates, item, s, key)

static func _add_stolen_flaw(templates: Dictionary, item: Dictionary, s: Dictionary, key: Array) -> void:
	if not item.has("flaws"):
		return
	for f in item["flaws"]:
		if str(f.get("part", "")) == "provenance":
			return
	var cat_rules: Dictionary = templates.get("appraise", {}).get("categories", {}).get(str(item["cat"]), {})
	item["flaws"].append(_flaw([str(cat_rules.get("stolen", "scrape"))], "provenance", false, false, "", s, key, "stolen"))

static func _flaw(kinds: Array, part: String, fine: bool, benign: bool, note: String, s: Dictionary, key: Array, tag: String) -> Dictionary:
	var f: Dictionary = {"part": part, "kind": _choice(kinds, s, "item_flaw_kind_" + tag, key), "fine": fine, "benign": benign,
		"seed": int(floor(_draw(s, "item_flaw_seed_" + tag, key) * 2147483647.0))}
	if note != "":
		f["note"] = note
	return f

static func _choice(options: Array, s: Dictionary, domain: String, key: Array) -> String:
	if options.is_empty():
		return ""
	return str(options[mini(options.size() - 1, int(floor(_draw(s, domain, key) * float(options.size()))))])

static func _part(item: Dictionary, pid: String) -> Dictionary:
	for part in item["parts"]:
		if str(part["id"]) == pid:
			return part
	return {}

static func _is_worn_text(templates: Dictionary, item: Dictionary, text: String) -> bool:
	for v in templates.get("categories", {}).get(str(item["cat"]), {}).get("variants", []):
		if str(v.get("id", "")) == str(item.get("template_id", "")):
			return text == str(v.get("worn_text", ""))
	return false

static func _npc_def(templates: Dictionary, pack: Dictionary, who: String) -> Dictionary:
	if not who.begins_with("stranger:") and not who.begins_with("walkin:"):      # walkin:<原型>#… 是只守铺子版的过路客人（scripts/core/walkin.gd）
		var resident: Dictionary = pack.get("npcs", {}).get(who, {}).duplicate(true)
		resident["id"] = who
		resident["name"] = str(resident.get("name", who))
		resident["label"] = str(resident.get("label", resident["name"]))
		resident["lines"] = resident.get("lines", templates.get("npc_lines", {})).duplicate(true)
		return resident
	var archetype_id: String = who.substr(who.find(":") + 1).split("#")[0]
	var archetype: Dictionary = {}
	for entry in pack.get("strangers", {}).get("archetypes", []):
		if str(entry.get("id", "")) == archetype_id:
			archetype = entry
			break
	var names: Dictionary = templates.get("stranger_names", {})
	var npc: Dictionary = archetype.get("npc", {}).duplicate(true)
	npc["id"] = who
	npc["name"] = str(archetype.get("name", names.get(archetype_id, "过路客")))
	npc["label"] = str(archetype.get("label", npc["name"]))
	npc["identity"] = str(archetype.get("identity", npc["name"]))
	npc["portrait"] = str(archetype.get("portrait", templates.get("stranger_portrait", "")))
	npc["cash"] = int(archetype.get("cash", 0))
	npc["lines"] = templates.get("npc_lines", {}).duplicate(true)
	return npc

static func _stock(s: Dictionary, world) -> Array:
	var out: Array = []
	if world != null:
		var ids: Array = world.ledger.items_at("stock")
		ids.sort()
		for id in ids:
			var item: Dictionary = world.ledger.items[id]
			if str(item.get("owner", "")) == "player" and str(item.get("pledged_to", "")) == "":
				out.append(item)
	elif s.get("stock", []) is Array:
		for item in s.get("stock", []):
			if item is Dictionary:
				out.append(item)
	return out

static func _price_mod(pack: Dictionary, s: Dictionary, item: Dictionary) -> float:
	var prices: Dictionary = pack.get("prices", {})
	var category: Dictionary = prices.get(str(item.get("cat", "")), {})
	var scale: String = str(category.get("scale", ""))
	return float(s.get("pressures", {}).get(scale, 1.0)) if scale != "" else 1.0

static func _draw(s: Dictionary, domain: String, key: Array) -> float:
	return R.draw(int(s.get("seed", 0)), domain, key)

static func _range(bounds: Array, draw: float) -> float:
	return float(bounds[0]) + (float(bounds[1]) - float(bounds[0])) * draw

static func _estimate(value: int, ratios: Array) -> Array:
	return [maxi(0, int(floor(float(value) * float(ratios[0])))), maxi(0, int(ceil(float(value) * float(ratios[1]))))]
