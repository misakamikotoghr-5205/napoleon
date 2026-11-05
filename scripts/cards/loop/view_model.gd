# 视图：只有看得见的东西。先放 G02 自己的（阶段、日期、告示、目标、开着的面板），再合并各模块经修正项 view_section
# 交来的顶层块；每张牌的视图合并各模块的 card_view_part；最后跑隐藏键检查 leaks()。
# 主人 G02；W0 写了能用的版本（隐藏键黑名单冻结）。合同：docs/cards/CARDS_INTERFACES.md §7.5。
class_name CardViewModel
extends RefCounted

## §7.5 的隐藏键黑名单：视图、所有查询结果、引擎发出的所有事件参数里递归都不许出现
const FORBIDDEN_KEYS: Array = ["floor", "market", "value", "true_value", "fake", "real", "stolen", "origin", "rare",
	"rarity", "quality", "conscience", "rep", "heat", "rep_points", "heat_points", "weight", "weights", "arc", "units",
	"prob", "probability", "chance", "pct", "percent", "patience", "pins", "pinned", "foretold", "seed", "draw", "est",
	"ask_w", "claimed", "contraband", "valence", "suggest", "budget", "tell", "tags", "hint_tags", "risk",
	"apprentice_loyalty", "apprentice_skim_pending"]
const _FORBIDDEN_SET: Dictionary = {
	"floor": true, "market": true, "value": true, "true_value": true, "fake": true, "real": true,
	"stolen": true, "origin": true, "rare": true, "rarity": true, "quality": true, "conscience": true,
	"rep": true, "heat": true, "rep_points": true, "heat_points": true, "weight": true, "weights": true,
	"arc": true, "units": true, "prob": true, "probability": true, "chance": true, "pct": true,
	"percent": true, "patience": true, "pins": true, "pinned": true, "foretold": true, "seed": true,
	"draw": true, "est": true, "ask_w": true, "claimed": true, "contraband": true, "valence": true,
	"suggest": true, "budget": true, "tell": true, "tags": true, "hint_tags": true, "risk": true,
	"apprentice_loyalty": true, "apprentice_skim_pending": true,
}


static func build(ctx: CardCtx) -> Dictionary:
	var loop := ctx.state.ns("loop")
	var cal := CardCalendar.today(ctx)
	var st := ctx.db.stage(int(loop.get("stage", 0)))
	var fate := ctx.state.ns("fate")
	var stage_day := int(loop.get("stage_day", 0))
	var v := {
		"v": 1, "phase": str(loop.get("phase", CardIds.PH_BOOT)), "mode": str(loop.get("mode", CardIds.MODE_SHOP)),
		"busy": false,
		# Extra visible fields for sim/autoplay; night_offer_cards keeps the pre-1.3 night card shape. All pass leaks().
		"game_over_reason": str(loop.get("reason", "")),
		"stage_intro": {"bg": str(st.get("intro", {}).get("bg", "")),
			"intro_paras": int(st.get("intro", {}).get("intro_paras", 0))},
		"night_offer_cards": _night_cards_legacy(ctx),
		"date": {"stage": int(loop.get("stage", 0)), "era": str(st.get("era", "")), "y": cal["y"], "m": cal["m"],
			"d": cal["d"], "weekday": cal["weekday"], "stage_day": stage_day, "stage_days": int(st.get("days", 30)),
			"abs_day": int(loop.get("abs_day", 0)), "minute": int(loop.get("minute", 480))},
		"notice": {"weather": str(fate.get("weather", "clear")), "market_day": CardCalendar.is_market_day(ctx, stage_day),
			"news": (loop.get("notices", []) as Array).duplicate(true), "almanac": CardAlmanac.today(ctx),
			"fortune": str(fate.get("month_segment", ""))},
		"caps": {"kept": CardPiles.cap(ctx, CardIds.ZONE_KEPT), "contacts": CardPiles.cap(ctx, CardIds.ZONE_CONTACTS),
			"shelf": CardShelf.cap(ctx)},
		"goals": (loop.get("goals", []) as Array).duplicate(true),
		"night_offers": _night_offers(ctx),
		"stage": _stage_view(ctx),
		"open_panel": (loop.get("open_panel", {"kind": "", "args": {}}) as Dictionary).duplicate(true),
	}
	var sections := ctx.mods.merge(ctx, &"view_section", {})
	for k in sections.keys():
		if v.has(k):
			push_error("CardViewModel: view_section key '%s' collides with a G02 key" % k)
			continue
		v[k] = sections[k]
	return v


## CardView：{uid, def, type, zone, gold, must_resolve, keepable, expires_in, status, art, person, intent, item,
## asking, observations, days_left, attrs, used_today, away_days, can_appraise, panel, actions, slots?, choices?}
static func card_view(ctx: CardCtx, uid: String, detailed: bool) -> Dictionary:
	var c := CardPiles._card_ref(ctx, uid)
	if c.is_empty():
		return {}
	var d: Dictionary = ctx.db._cards.get(str(c["def"]), {}) if ctx.db != null else {}
	var type := str(d.get("type", ""))
	var exp_abs := int(c.get("expires_abs_day", -1))
	var v := {"uid": uid, "def": str(c["def"]), "type": type, "zone": str(c.get("zone", "")),
		"gold": bool(d.get("gold", false)), "must_resolve": must_resolve(d),
		"keepable": (type == "kept" or bool(d.get("keepable", false))) and not bool(d.get("gold", false)),
		"expires_in": exp_abs - ctx.abs_day() if exp_abs >= 0 else -1, "status": str(c.get("status", "open")),
		"art": str(d.get("art", "")), "person": str(d.get("person", "")), "intent": str(d.get("intent", "")),
		"stage": _strip_briefs(d.get("stage", {})) if d.has("stage") else {}, "source": str(d.get("source", "")) if type == "news" else "",
		"item": null, "asking": -1, "observations": [], "days_left": -1, "attrs": d.get("attrs", {}),
		"used_today": false, "away_days": 0, "can_appraise": false, "panel": str(panel_of(d)),
		"actions": ctx.actions.for_card(ctx, uid)}
	var parts := ctx.mods.merge(ctx, &"card_view_part", {"uid": uid, "detailed": detailed})
	v.merge(parts, true)
	return v


## 打烊前必须处理吗：§4.7 开头的类型默认 + 牌自己的 must_resolve 字段
static func must_resolve(d: Dictionary) -> bool:
	if d.has("must_resolve"):
		return bool(d["must_resolve"])
	return CardIds.MUST_RESOLVE_TYPES.has(StringName(str(d.get("type", ""))))


## 牌 → 面板 kind（§7.4.3）
static func panel_of(d: Dictionary) -> StringName:
	var type := str(d.get("type", ""))
	match type:
		"person":
			return &"counter" if ["pawn", "sell", "buy", "redeem"].has(str(d.get("intent", ""))) else &"slots"
		"event":
			if str(d.get("opens_wheel", "")) != "" or str(d.get("id", "")) == "ev.any.wheel_go":
				return &"wheel"
			return &"fortune" if str(d.get("opens_fortune", "")) != "" else &"slots"
		"big_fate":
			return &"wheel" if str(d.get("opens_wheel", "")) != "" else &"slots"
		"fate", "life", "street":
			return &"slots"
		"demand":
			return &"demand"
		"prison":
			return &"prison"
		"news", "pawn_ticket":
			return &"read"
	return &"none"


## 违规路径（空 = 干净）：递归找 FORBIDDEN_KEYS 里的键
static func leaks(v) -> PackedStringArray:
	var out := PackedStringArray()
	if _has_leak(v):
		_walk(v, "", out)
	return out


static func _has_leak(v) -> bool:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				if _FORBIDDEN_SET.has(str(k)) or _has_leak(v[k]):
					return true
		TYPE_ARRAY:
			for x in v:
				if _has_leak(x):
					return true
	return false


static func _walk(v, path: String, out: PackedStringArray) -> void:
	match typeof(v):
		TYPE_DICTIONARY:
			for k in v.keys():
				var p := "%s.%s" % [path, k] if path != "" else str(k)
				if _FORBIDDEN_SET.has(str(k)):
					out.append(p)
				_walk(v[k], p, out)
		TYPE_ARRAY:
			for i in range(v.size()):
				_walk(v[i], "%s[%d]" % [path, i], out)


static func _night_cards_legacy(ctx: CardCtx) -> Array:
	var out: Array = []
	for id in ctx.state.ns("loop").get("night", {}).get("offers", []):
		var d := ctx.db.def(str(id))
		var choices: Array = []
		for choice in d.get("choices", []):
			choices.append({"id": str(choice.get("id", ""))})
		out.append({"def": str(id), "type": "night", "art": str(d.get("art", "")), "choices": choices})
	return out


static func _night_offers(ctx: CardCtx) -> Array:
	var out: Array = []
	for id in ctx.state.ns("loop").get("night", {}).get("offers", []):
		var d := ctx.db.def(str(id))
		var choices: Array = []
		for choice in d.get("choices", []):
			choices.append(str(choice.get("id", "")))
		out.append({"def": str(id), "art": str(d.get("art", "")), "choices": choices})
	return out


static func _stage_view(ctx: CardCtx) -> Dictionary:
	var loop := ctx.state.ns("loop")
	var phase := str(loop.get("phase", CardIds.PH_BOOT))
	var set_name := "counter"
	if _in_prison(ctx):
		set_name = "prison"
	elif str(loop.get("mode", CardIds.MODE_SHOP)) == "street":
		set_name = "street"
	var time := "night" if phase in ["night", "settle"] else "day"
	if phase == "day" and _is_dusk(ctx):
		time = "dusk"
	var closed_until := int(ctx.state.ns("econ").get("shop_closed_until", -1))
	return {"set": set_name, "time": time, "sealed": closed_until >= ctx.abs_day()}


static func _in_prison(ctx: CardCtx) -> bool:
	if str(ctx.state.ns("ladder").get("prison", {}).get("uid", "")) != "":
		return true
	for uid in CardPiles.list(ctx, CardIds.ZONE_HAND):
		if str(CardPiles.def_of(ctx, uid).get("type", "")) == "prison":
			return true
	return false


static func _is_dusk(ctx: CardCtx) -> bool:
	var deals: Array = ctx.state.ns("core").get("deals", {}).get(str(ctx.abs_day()), [])
	if deals.is_empty():
		return false
	var removed := 0
	for uid in deals:
		if CardPiles.zone_of(ctx, str(uid)) != CardIds.ZONE_HAND:
			removed += 1
	var pct := int(ctx.rules("loop").get("dusk_pct", 60))
	return removed * 100 >= deals.size() * pct


static func _strip_briefs(v):
	match typeof(v):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key in v.keys():
				if str(key) != "brief":
					out[key] = _strip_briefs(v[key])
			return out
		TYPE_ARRAY:
			var out: Array = []
			for row in v:
				out.append(_strip_briefs(row))
			return out
	return v

