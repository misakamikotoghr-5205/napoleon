# 求签读取未来随机牌、钉签和日程，选择后钉住征兆。
# 测字无征兆时封住未来随机牌；查询永远不泄露具体牌与日期。
class_name CardFortune
extends RefCounted
const S = preload("res://scripts/cards/fate/fate_support.gd")

static func draw_lot(ctx: CardCtx, uid: String) -> Dictionary:
	var err := _access(ctx, uid, "lot")
	if err != "":
		return {"ok": false, "err": err}
	var spec: Dictionary = ctx.rules("fortune").get("lot", {})
	var candidates := future(ctx)
	var count := int(ctx.state.ns("fate").get("lot_count", 0))
	var chosen := _pick(ctx, candidates, spec, count)
	if chosen.is_empty():
		return {"ok": false, "err": "cond_failed"}
	var grade := _grade(ctx, chosen)
	var lot := _verse(ctx, chosen, grade, count)
	if lot == "":
		return {"ok": false, "err": "unknown_def"}
	S.pay(ctx, cost(ctx, uid), "g05.reason.fortune", uid)
	for row in chosen:
		CardPins.pin(ctx, int(row["day"]), str(row["def"]), "lot:%d" % count)
	var fate := ctx.state.ns("fate")
	fate["lot_count"] = count + 1
	var lots: Array = fate.get("lots", [])
	lots.append({"lot": lot, "abs_day": ctx.abs_day()})
	fate["lots"] = lots
	var last: Dictionary = fate.get("fortune_last", {})
	last[uid] = {"lot": lot, "grade": grade}
	fate["fortune_last"] = last
	return {"ok": true, "err": "", "lot": lot, "grade": grade}

static func _pick(ctx: CardCtx, candidates: Array, spec: Dictionary, count: int) -> Array:
	var rows: Array = []
	var harsh := S.meter(ctx, &"conscience") <= int(spec.get("conscience_harsh_below", -20))
	for i in range(candidates.size()):
		var def := ctx.db.def(str(candidates[i]["def"]))
		var weight := int(spec.get("harsh_bias_pct", 300)) if harsh and bad(def) else 100
		rows.append([str(i), maxi(1, weight)])
	var chosen: Array = []
	for k in range(mini(int(spec.get("pick", 2)), rows.size())):
		var id := JevRng.weighted_choice(rows, ctx.draw("c.lot.pick", [ctx.abs_day(), count, k]))
		chosen.append(candidates[int(id)])
		for j in range(rows.size()):
			if str(rows[j][0]) == id:
				rows.remove_at(j)
				break
	return chosen

static func _grade(ctx: CardCtx, rows: Array) -> int:
	var bad_count := 0
	for row in rows:
		if bad(ctx.db.def(str(row["def"]))):
			bad_count += 1
	var good_count := rows.size() - bad_count
	var key := "bad" if bad_count > good_count else ("good" if good_count > bad_count else "mixed")
	return int(ctx.rules("fortune").get("lot", {}).get("grades", {"bad": 1, "mixed": 2, "good": 3}).get(key, 2))

static func _verse(ctx: CardCtx, chosen: Array, grade: int, count: int) -> String:
	var tags: Array = []
	for row in chosen:
		tags.append_array(S.omens(ctx.db.def(str(row["def"]))))
	var specific: Array = []
	var generic: Array = []
	for id in ctx.db.pool(&"fortune_lot", S.era(ctx)):
		var def := ctx.db.def(id)
		if int(def.get("grade", -1)) != grade:
			continue
		var hints: Array = def.get("hint_tags", [])
		if hints.is_empty():
			generic.append([id, int(def.get("weight", 10))])
		elif S.intersects(hints, tags):
			specific.append([id, int(def.get("weight", 10))])
	var rows := specific if not specific.is_empty() else generic
	return "" if rows.is_empty() else JevRng.weighted_choice(rows, ctx.draw("c.lot.verse", [ctx.abs_day(), count]))

static func cezi(ctx: CardCtx, uid: String, char_id: String) -> Dictionary:
	var err := _access(ctx, uid, "cezi")
	if err != "":
		return {"ok": false, "err": err}
	if not offered(ctx, uid).has(char_id):
		return {"ok": false, "err": "not_allowed"}
	var tags := S.omens(ctx.db.def(char_id))
	var match_row: Dictionary = {}
	for row in future(ctx):
		if S.intersects(tags, S.omens(ctx.db.def(str(row["def"])))):
			match_row = row
			break
	S.pay(ctx, cost(ctx, uid), "g05.reason.fortune", uid)
	var fate := ctx.state.ns("fate")
	var n := int(fate.get("cezi_count", 0))
	if match_row.is_empty():
		for day in range(ctx.abs_day() + 1, ctx.abs_day() + 1 + int(ctx.rules("fortune").get("lot", {}).get("window_days", 3))):
			CardPins.ban(ctx, day, tags, "cezi:%d" % n)
	else:
		CardPins.pin(ctx, int(match_row["day"]), str(match_row["def"]), "cezi:%d" % n)
	fate["cezi_count"] = n + 1
	return {"ok": true, "err": "", "char": char_id, "reading": "none" if match_row.is_empty() else "has"}

static func offer_chars(ctx: CardCtx) -> PackedStringArray:
	return offered(ctx, str(ctx.state.ns("loop").get("open_panel", {}).get("args", {}).get("uid", "")))

static func offered(ctx: CardCtx, uid: String) -> PackedStringArray:
	var ids := ctx.db.pool(&"cezi", S.era(ctx))
	if ids.is_empty():
		return PackedStringArray()
	var offset := int(floor(ctx.draw("c.cezi.offer", [ctx.abs_day(), uid]) * ids.size()))
	var out := PackedStringArray()
	for i in range(mini(ids.size(), int(ctx.rules("fortune").get("cezi", {}).get("offer", 6)))):
		out.append(ids[(offset + i) % ids.size()])
	return out

static func future(ctx: CardCtx) -> Array:
	var out: Array = []
	var window := int(ctx.rules("fortune").get("lot", {}).get("window_days", 3))
	for day in range(ctx.abs_day() + 1, ctx.abs_day() + 1 + window):
		var projected := temporal(ctx, day)
		var ids: Array = Array(CardComposer.project(projected, day))
		ids.append_array(Array(CardPins.pinned(ctx, day)))
		ids.append_array(Array(CardSchedule.due(ctx, day)))
		ids.sort()
		var seen: Dictionary = {}
		for id in ids:
			var def := ctx.db.def(str(id))
			if seen.has(id) or not str(def.get("type", "")) in ["event", "fate", "person", "life", "news", "big_fate"] or S.omens(def).is_empty():
				continue
			seen[id] = true
			out.append({"day": day, "def": str(id)})
	return out

static func temporal(ctx: CardCtx, day: int) -> CardCtx:
	var projected := CardCtx.new()
	projected.db = ctx.db
	projected.state = CardState.from_dict(ctx.state.to_dict())
	projected.ops = ctx.ops
	projected.conds = ctx.conds
	projected.mods = ctx.mods
	projected.hooks = ctx.hooks
	projected.actions = ctx.actions
	var loop := projected.state.ns("loop")
	loop["stage_day"] = int(loop.get("stage_day", 0)) + day - ctx.abs_day()
	loop["abs_day"] = day
	loop["phase"] = "morning"
	return projected

static func bad(def: Dictionary) -> bool:
	return str(def.get("valence", "")) == "bad" if str(def.get("type", "")) in ["fate", "big_fate"] else def.get("tags", []).has("bad_omen")

static func cost(ctx: CardCtx, uid: String) -> int:
	return maxi(0, int(CardPiles.def_of(ctx, uid).get("cost", {}).get("money", 0)))

static func query(ctx: CardCtx, uid: String) -> Dictionary:
	var def := CardPiles.def_of(ctx, uid)
	var opens := str(def.get("opens_fortune", ""))
	return {"cost": cost(ctx, uid), "can_lot": opens in ["lot", "both"], "can_cezi": opens in ["cezi", "both"],
		"cezi": Array(offered(ctx, uid)), "last": ctx.state.ns("fate").get("fortune_last", {}).get(uid, {"lot": "", "grade": 0}).duplicate(true)}

static func _access(ctx: CardCtx, uid: String, kind: String) -> String:
	if str(ctx.state.ns("loop").get("phase", "day")) != "day":
		return "bad_phase"
	var def := CardPiles.def_of(ctx, uid)
	if def.is_empty():
		return "unknown_uid"
	if CardPiles.zone_of(ctx, uid) != CardIds.ZONE_HAND or not str(def.get("opens_fortune", "")) in [kind, "both"]:
		return "not_allowed"
	return "insufficient_money" if cost(ctx, uid) > S.available_money(ctx) else ""

static func peek(ctx: CardCtx, pool: String, n: int) -> void:
	var day := ctx.abs_day() + 1
	var seen := 0
	for id in CardComposer.project(temporal(ctx, day), day):
		if str(ctx.db.def(id).get("type", "")) != pool or seen >= maxi(0, n):
			continue
		CardPins.pin(ctx, day, id, "peek")
		ctx.emit(&"notice", ["g05.notice.peek", {"def": id}])
		seen += 1
