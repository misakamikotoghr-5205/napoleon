# RG1_api: relic_api.gd take / can_take error codes, replacing when the shelf is full (gone + rg1.notice.released),
# the lazily built state.relic (absent until the first take, untouched by reads), the "relics" view block and query
# shapes, dormancy, save / load, no hidden keys, no floats, and the module switched off (examples, enabled false,
# no rules file). ROGUE_V1.md §3.1, §4.3, §4.7, §4.8, §5.4, §6.3. Owner RG1.
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const H = preload("res://scripts/tests/cards/RG1/helper.gd")
const Api = preload("res://scripts/cards/relic/relic_api.gd")

const SIX := ["rl.stub_box", "rl.blue_curtain", "rl.oilpaper_umbrella", "rl.old_almanac", "rl.chen_mortar", "rl.hu2_pipe"]


func _initialize() -> void:
	var t := T.new(self, "RG1_api")
	var bus := CardEventBus.new()
	var spy = t.spy(bus)
	var e := H.engine(t, H.data_root(t), 7, "main", bus)
	var ctx := e.ctx
	_untouched(t, e)
	_errors(t, e)
	_fill_and_replace(t, e)
	_shapes(t, e)
	_dormant(t, e)
	_save_load(t, e)
	_next_stage(t, e)
	_off(t)
	for row in spy.log:
		t.no_leaks(row, "bus event %s" % str(row[0]))
	t.eq(t.find_floats(ctx.state.data), PackedStringArray(), "no floats in state")
	bus.free()
	t.finish()


func _untouched(t, e: CardEngine) -> void:
	var ctx := e.ctx
	t.ok(Api.active(ctx), "module on with the fixture data")
	t.eq(Api.cap(ctx), 6, "cap from rules/relics.json")
	t.ok(not ctx.state.data.has("relic"), "no relic namespace after game.new")
	t.eq(e.view().get("relics"), {"cap": 6, "count": 0, "dormant": false, "held": []}, "empty view block")
	t.eq(e.query(&"relics"), {"ok": true, "err": "", "cap": 6, "count": 0, "dormant": false, "held": []}, "empty query")
	t.ok(H.advance(e, 3, "morning"), "two real days played")
	t.ok(not ctx.state.data.has("relic"), "still no relic namespace after two days")
	var h0 := e.state_hash()
	e.view()
	e.query(&"relics")
	Api.held_ids(ctx)
	Api.gone_ids(ctx)
	Api.is_full(ctx)
	Api.can_take(ctx, "rl.stub_box", "")
	Api.can_take(ctx, "rl.stub_box", "rl.blue_curtain")
	t.eq(e.state_hash(), h0, "views, the query and every API read keep the state hash")
	t.ok(not ctx.state.data.has("relic"), "reads never create the namespace")


func _errors(t, e: CardEngine) -> void:
	var ctx := e.ctx
	t.eq(Api.take(ctx, "rl.no_such", "", "test"), "unknown_def", "unknown id -> unknown_def")
	t.eq(Api.take(ctx, "self.ruhua", "", "test"), "unknown_def", "an id that is not a relic -> unknown_def")
	t.eq(Api.take(ctx, "rl.stub_box", "rl.blue_curtain", "test"), "not_held", "replace that is not on the shelf -> not_held")
	t.ok(not ctx.state.data.has("relic"), "failed takes write nothing")
	ctx.out = []
	t.eq(Api.take(ctx, "rl.stub_box", "", "test"), "", "first take ok")
	var day := ctx.abs_day()
	t.eq(ctx.state.data.get("relic"), {"_v": 1, "held": [{"id": "rl.stub_box", "since": day, "src": "test"}], "gone": []},
		"state.relic after the first take")
	t.eq(ctx.out, [[&"notice", "rl.stub_box#lines.gain", {}], [&"view_changed", ["relics"]]], "gain notice + view_changed")
	t.eq(Api.take(ctx, "rl.stub_box", "", "test"), "not_allowed", "already held -> not_allowed")
	t.eq(Api.can_take(ctx, "rl.stub_box", ""), "not_allowed", "can_take agrees")


func _fill_and_replace(t, e: CardEngine) -> void:
	var ctx := e.ctx
	for id in SIX.slice(1):
		t.eq(Api.take(ctx, id, "", "test"), "", "take " + id)
	t.eq(Api.held_ids(ctx), PackedStringArray(SIX), "held in the order taken")
	t.ok(Api.is_full(ctx), "six of six -> full")
	t.eq(Api.can_take(ctx, "rl.camphor_chest", ""), "relic_full", "can_take: full without replace")
	t.eq(Api.take(ctx, "rl.camphor_chest", "", "test"), "relic_full", "full without replace -> relic_full")
	t.eq(Api.take(ctx, "rl.camphor_chest", "rl.sun_inkpad", "test"), "not_held", "full, replace not held -> not_held")
	var before := e.state_hash()
	t.eq(Api.take(ctx, "rl.no_such", "rl.stub_box", "test"), "unknown_def", "unknown id checked before the replace")
	t.eq(e.state_hash(), before, "refused takes leave the state alone")
	ctx.out = []
	t.eq(Api.take(ctx, "rl.camphor_chest", "rl.blue_curtain", "stock:w0.1"), "", "full + replace ok")
	var expect := PackedStringArray(SIX)
	expect.remove_at(1)
	expect.append("rl.camphor_chest")
	t.eq(Api.held_ids(ctx), expect, "replaced one left, new one appended")
	t.eq(Api.gone_ids(ctx), PackedStringArray(["rl.blue_curtain"]), "replaced one is gone")
	t.eq(ctx.out, [[&"notice", "rg1.notice.released", {}], [&"notice", "rl.camphor_chest#lines.gain", {}],
		[&"view_changed", ["relics"]]], "released notice first, then the gain line, then view_changed")
	var last: Dictionary = (ctx.state.data["relic"]["held"] as Array).back()
	t.eq(last.get("src"), "stock:w0.1", "src kept for the log")
	t.eq(Api.take(ctx, "rl.blue_curtain", "rl.stub_box", "test"), "not_allowed", "a released relic never comes back")
	t.eq(Api.can_take(ctx, "rl.blue_curtain", ""), "not_allowed", "can_take: gone -> not_allowed")
	t.ok(Api.is_full(ctx), "still six")


func _shapes(t, e: CardEngine) -> void:
	var ctx := e.ctx
	var held: Array = []
	for row in ctx.state.data["relic"]["held"]:
		var d := ctx.db.def(str(row["id"]))
		held.append({"id": row["id"], "art": "prop.relic." + str(row["id"]).trim_prefix("rl."),
			"depth": str(d.get("depth", "")), "since": row["since"]})
	var block := {"cap": 6, "count": 6, "dormant": false, "held": held}
	var v := e.view()
	t.eq(v.get("relics"), block, "view block {cap, count, dormant, held[{id, art, depth, since}]}")
	var q := e.query(&"relics")
	var want := block.duplicate(true)
	want.merge({"ok": true, "err": ""})
	t.eq(q, want, "query = view block + ok/err")
	t.eq(str(q["held"][0]["depth"]), "plain", "depth word, never a number")
	t.no_leaks(v)
	t.no_leaks(q, "relics query")


func _dormant(t, e: CardEngine) -> void:
	var ctx := e.ctx
	var h := e.state_hash()
	ctx.state.ns("loop")["mode"] = "street"
	t.eq(e.view()["relics"]["dormant"], true, "street mode -> dormant in the view")
	t.eq(e.query(&"relics")["dormant"], true, "street mode -> dormant in the query")
	ctx.state.ns("loop")["mode"] = "shop"
	var ladder := ctx.state.ns("ladder")
	var had: bool = ladder.has("prison")
	var old = ladder.get("prison")
	ladder["prison"] = {"uid": "c9999", "nights": 0}
	t.ok(Api.dormant(ctx), "jailed -> dormant")
	t.eq(e.view()["relics"]["dormant"], true, "jailed -> dormant in the view")
	ladder["prison"] = {}
	t.ok(not Api.dormant(ctx), "an empty prison record -> awake")
	if had:
		ladder["prison"] = old
	else:
		ladder.erase("prison")
	t.ok(not Api.dormant(ctx), "back in the shop -> awake")
	t.eq(e.state_hash(), h, "state restored")


func _save_load(t, e: CardEngine) -> void:
	var path: String = t.user_dir() + "/rg1_api_save.json"
	t.ok(bool(e.save_game(path).get("ok", false)), "save in the morning")
	var h := e.state_hash()
	var held := Api.held_ids(e.ctx)
	var other := H.engine(t, H.data_root(t), 7, "other")
	t.ok(bool(other.load_game(path).get("ok", false)), "load into a second engine on the same data")
	t.eq(other.state_hash(), h, "same hash after load")
	t.eq(Api.held_ids(other.ctx), held, "same shelf after load")
	t.eq(Api.gone_ids(other.ctx), PackedStringArray(["rl.blue_curtain"]), "gone survives the save")
	t.eq(t.find_floats(other.ctx.state.data), PackedStringArray(), "no floats after load")
	t.eq(other.view()["relics"], e.view()["relics"], "same view block after load")


## A run is the three stages played on: begin_stage (what year.next ends with) only merges loop keys, so the shelf
## and the released relics carry over.
func _next_stage(t, e: CardEngine) -> void:
	var held := Api.held_ids(e.ctx)
	var gone := Api.gone_ids(e.ctx)
	CardDayLoop.begin_stage(e.ctx, 1)
	CardDayLoop.open_month(e.ctx)
	t.eq(int(e.view()["date"]["stage"]), 1, "stage 1 begun")
	t.eq(Api.held_ids(e.ctx), held, "a new stage keeps the shelf")
	t.eq(Api.gone_ids(e.ctx), gone, "released relics stay gone")
	t.eq(int(e.view()["relics"]["count"]), held.size(), "view block after the stage change")


func _off(t) -> void:
	var ex := CardEngine.new()
	t.ok(bool(ex.new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir() + "/ex"}).get("ok", false)), "examples game")
	t.ok(not Api.active(ex.ctx), "examples have no relics -> off")
	t.eq(Api.take(ex.ctx, "rl.stub_box", "", "test"), "not_allowed", "module off -> not_allowed")
	t.ok(not ex.view().has("relics"), "examples view has no relics block")
	t.eq(ex.query(&"relics"), {"ok": true, "err": "", "cap": 6, "count": 0, "dormant": false, "held": []}, "off query")
	t.ok(not ex.ctx.state.data.has("relic"), "examples state has no relic namespace")
	var off := H.engine(t, H.data_root(t, {"enabled": false}, "cards_off"), 7, "off")
	t.ok(not Api.active(off.ctx), "enabled false -> off")
	t.eq(Api.take(off.ctx, "rl.stub_box", "", "test"), "not_allowed", "enabled false -> not_allowed")
	t.ok(not off.view().has("relics"), "enabled false -> no view block")
	t.eq(off.query(&"relics")["held"], [], "enabled false -> empty query")
	t.ok(not off.ctx.state.data.has("relic"), "enabled false -> no relic namespace")
	# §6.3: no rules/relics.json = the module is off, even with relic cards in the data (like stock_state.active).
	var bare := H.data_root(t, {}, "cards_norules")
	DirAccess.remove_absolute(bare + "/rules/relics.json")
	var nr := H.engine(t, bare, 7, "norules")
	t.ok(nr.ctx.rules("relics").is_empty() and not nr.ctx.db.ids_of(&"relic").is_empty(), "relic cards, no rules file")
	t.ok(not Api.active(nr.ctx), "no rules/relics.json -> off")
	t.eq(Api.take(nr.ctx, "rl.stub_box", "", "test"), "not_allowed", "no rules file -> not_allowed")
	t.ok(not nr.view().has("relics"), "no rules file -> no view block")
	t.ok(not nr.ctx.state.data.has("relic"), "no rules file -> no relic namespace")
