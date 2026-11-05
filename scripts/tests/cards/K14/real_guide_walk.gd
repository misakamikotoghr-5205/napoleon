# Real six-module tutorial walk shared by two profiles. No fabricated views/events/progress;
# UI actions and engine commands drive the actual table.
#   G02:    copied _examples data + G02 private tutorial fixture (frozen firsts regression).
#   FORMAL: the shipped data/cards (no data_root override, no tutorial swap) — the new-save
#           1938 three-day guide that #194/K14 accepts.
extends RefCounted

const Real = preload("res://scripts/tests/cards/G02/real_firsts.gd")
const U = preload("res://scripts/tests/cards/K14/qa_util.gd")
const STEPS := "res://data/cards/guide/steps.json"
const GOLDEN := "res://scripts/tests/cards/G02/golden/firsts_d1_3.json"
const FORMAL_TUTORIAL := "res://data/cards/era/1938/tutorial.json"

const G02 := {"name": "g02", "pawn": "p.g02.d1.pawn", "sell": "p.g02.d1.sell", "buy": "p.g02.d1.buy",
	"slots": "ev.g02.d3.slots", "place": [["self", {"kind": "self"}]]}
const FORMAL := {"name": "formal", "pawn": "p.zhang.1938.tut_pawn", "sell": "p.wu.1938.tut_sell",
	"buy": "p.xiaoding.1938.tut_buy", "slots": "ev.1938.tut_slots", "place": [["who", {"kind": "self"}]], "afford": true,
	"brother_gone_step": true, "handover": true}

var t
var tree: SceneTree
var game: CardGameRoot
var bus: CardEventBus
var enabled := true
var out := ""
var shots := {}
var ticks := 0
var firsts: Array = []
var spy
var profile: Dictionary = G02

func _init(p: Dictionary = G02) -> void:
	profile = p

## G02's private tutorial has no day-1 handover: the brother's gold card is the day-2 farewell, so
## gd.d2.gold and gd.choice come after gd.d2.rules there. Same 21 steps as _test.d1_3.
static func expected_g02() -> Array:
	var steps := expected().duplicate()
	for id in ["gd.d2.gold", "gd.choice"]:
		steps.erase(id)
	var at := steps.find("gd.d2.rules")
	steps.insert(at + 1, "gd.d2.gold")
	steps.insert(at + 2, "gd.choice")
	return steps

static func prepare_data(test) -> String:
	# G02's golden explicitly uses this private tutorial schedule, not the campaign.
	var data_root := Real._data(test)
	var file := FileAccess.open(data_root.path_join("guide/steps.json"), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(STEPS))
	file.close()
	return data_root

static func expected() -> Array:
	return CardDB.read_json(STEPS).get("_test", {}).get("d1_3", [])

# What the real guide actually shows on the formal new save: the 21-step contract plus
# gd.person_state right after gd.d2.keep (see FORMAL brother_gone_step: the brother leaves on day 2).
static func expected_formal() -> Array:
	var steps := expected().duplicate()
	var at := steps.find("gd.d2.keep")
	if at >= 0:
		steps.insert(at + 1, "gd.person_state")
	return steps

func play(test, scene_tree: SceneTree, boot_options: Dictionary, screenshot_dir: String = "") -> Dictionary:
	t = test
	tree = scene_tree
	enabled = str(boot_options.get("guide", "")) == "on"
	out = screenshot_dir
	bus = CardEventBus.new()
	tree.root.add_child(bus)
	spy = t.spy(bus)
	game = load(CardIds.ROOT_SCENE).instantiate()
	var options := boot_options.duplicate(true)
	t.eq(options.get("mock"), false, "caller explicitly requests real engine")
	t.ok(str(options.get("save_dir", "")).begins_with(t.user_dir() + "/"), "isolated real save directory")
	if profile["name"] == "formal":
		t.ok(not options.has("data_root") and not options.has("only_examples"), "formal walk boots shipped data/cards")
	options.merge({"bus": bus, "seed": 7, "skip_title": true})
	game.boot(options)
	tree.root.add_child(game)
	bus.first_time.connect(_first)
	game.guide.skip_fades = true
	game.guide.force(enabled)
	await t.frames(2)
	var root_real := game.engine is CardEngine
	t.ok(root_real, "root_real: tutorial uses CardEngine")
	if not root_real:
		await _cleanup()
		return {}
	t.eq(str(game.engine.view().get("phase", "")), "month_open", "real new_game stays at month_open")
	t.no_leaks(game.engine.view(), "real boot view")
	# Read the month introduction through its actual panel, stopping at the goals.
	while not CardAnchors.has(&"a.month.goals") and ticks < 2500:
		game.autoplay_step()
		await _frame()
	await _step("gd.m.open")
	game.autoplay_step()
	await _frame()
	await _step("gd.m.wheel")
	await _ack() # The reader presses "got it"; the incense lesson follows before anything is offered.
	await _step("gd.m.incense")
	_send(&"wheel.offer", {"wheel": "wh.month", "uid": "", "source": {"kind": "money", "amount": 1}})
	await _frame()
	game.autoplay_step() # Wheel autoplay spins and reveals before the continue action.
	await _frame()
	game.autoplay_step()
	await _frame()
	await _step("gd.d1.notice")
	_send(&"day.begin")
	await _frame()
	await _step("gd.d1.deal")
	var handover := ""
	if bool(profile.get("handover", false)):
		# Day 1 of the shipped tutorial: the brother's gold handover comes first (prototype order).
		handover = _uid("p.brother.1938.tut_handover")
		_select(handover)
		await _frame()
		await _step("gd.d2.gold")
		await _ack()
	var pawn := _uid(str(profile["pawn"]))
	if handover == "":
		_select(pawn)
		await _frame()
	await _step("gd.d1.person")
	await _ack()
	await _step("gd.d1.close")
	await _ack()
	if handover != "":
		game.hand.play_uid(handover)
		await _frame()
		await _step("gd.choice")
		_send(&"card.choose", {"uid": handover, "choice": "listen"})
		await _close_play()
		_select(pawn)
		await _frame()
	game.hand.play_uid(pawn)
	await _frame()
	await _step("gd.d1.look")
	var cv := game.engine.query(&"counter", {"uid": pawn})
	var item := str(cv.get("item", {}).get("item", ""))
	_send(&"mg.request", {"uid": pawn, "item": item})
	await _frame()
	await _step("gd.d1.spot")
	game.mg_host.autoplay_current(1.0)
	await _frame()
	await _step("gd.d1.tiers")
	_offer(pawn)
	await _frame()
	await _step("gd.d1.ticket")
	await _close_play()
	var seller := _uid(str(profile["sell"]))
	_select(seller)
	await _frame()
	game.hand.play_uid(seller)
	await _frame()
	_offer(seller)
	await _frame()
	await _step("gd.d1.shelf")
	await _close_play()
	var buyer := _uid(str(profile["buy"]))
	_select(buyer)
	game.hand.play_uid(buyer)
	await _frame()
	await _step("gd.d1.buyer")
	var stock: Array = game.engine.query(&"counter", {"uid": buyer}).get("stock", [])
	t.ok(not stock.is_empty(), "real teaching buyer has stock")
	if not stock.is_empty():
		var stock_id := str(stock[0]) if typeof(stock[0]) == TYPE_STRING else str(stock[0].get("item", stock[0].get("id", "")))
		_send(&"counter.pick_stock", {"uid": buyer, "item": stock_id})
	_offer(buyer)
	await _close_play()
	_send(&"day.end", {"confirm": true})
	await _frame()
	await _step("gd.d1.night")
	_night()
	await _frame()
	await _step("gd.d1.settle")
	game.autoplay_step() # Settle panel sends settle.next and restores the hand.
	await _frame()
	await _step("gd.d2.rules")
	_send(&"day.begin")
	await _frame()
	var gold := _uid("p.brother.1938.farewell")
	if handover == "":
		await _step("gd.d2.gold")
	else:
		# Shipped day 2 deals a card that can be kept, so keeping is taught first thing.
		await _step("gd.d2.keep")
		await _ack()
	_select(gold)
	game.hand.play_uid(gold)
	await _frame()
	if handover == "":
		await _step("gd.choice")
	_send(&"card.choose", {"uid": gold, "choice": "listen"})
	await _frame()
	if handover == "":
		await _step("gd.d2.keep")
	var note := _uid("kp.brother_note")
	if note != "" and str(game.engine.query(&"card", {"uid": note}).get("zone", "")) == "hand":
		_send(&"card.keep", {"uid": note})
	if handover == "":
		await _ack()
	if bool(profile.get("brother_gone_step", false)):
		# Formal K01 data: "listen" sets brother person_state=gone on day 2, so the real guide also
		# teaches gd.person_state (not in _test.d1_3). The reader presses got it.
		await _step("gd.person_state")
		await _ack()
	await _close_play()
	_send(&"day.end", {"confirm": true})
	await _frame()
	_night()
	await _frame()
	game.autoplay_step() # Settle panel sends settle.next and restores the hand.
	await _frame()
	_send(&"day.begin")
	await _frame()
	var event := _uid(str(profile["slots"]))
	await _step("gd.slots")
	_select(event)
	await _frame()
	game.hand.play_uid(event)
	await _frame()
	await _step("gd.coins")
	for row in profile["place"]:
		_send(&"slot.place", {"uid": event, "slot": str(row[0]), "source": row[1]})
	_send(&"slot.roll", {"uid": event})
	_send(&"day.end", {"confirm": true})
	await _close_play()
	_night()
	await _frame()
	game.autoplay_step() # Settle panel sends settle.next and restores the hand.
	await _frame()
	t.eq(str(game.engine.view().get("phase", "")), "morning", "real walk reaches morning")
	t.eq(int(game.engine.view().get("date", {}).get("stage_day", 0)), 4, "real walk completes three days")
	t.ok(ticks < 2500, "real walk stays within original step cap")
	var eng := game.engine as CardEngine
	var result := {"log": Array(game.guide.shown_log), "cmds": eng.command_log(),
		"hash": eng.ctx.state.hash(), "progress": eng.query(&"guide_progress").get("progress", {}),
		"firsts": firsts.duplicate(true), "events": spy.ui_events(), "shots": shots.duplicate()}
	print("K14 REAL GUIDE profile=%s root_real=%s on=%s day=%d ticks=%d shown=%d" % [profile["name"], root_real, enabled,
		int(game.engine.view().get("date", {}).get("stage_day", 0)), ticks, result["log"].size()])
	await _cleanup()
	return result

func _frame() -> void:
	await t.frames(1)
	game.guide.tick(0.5)
	game.guide.evaluate_now()
	ticks += 1

## The reader presses "got it" on the bubble that is up (10-22 prototype flow).
func _ack() -> void:
	if enabled:
		game.guide.acknowledge()
	await _frame()

func _step(id: String) -> void:
	if not enabled:
		return
	t.eq(game.guide.active_step(), id, "real tutorial checkpoint " + id)
	if game.guide.active_step() != id or out == "":
		return
	# A headless run still checks every checkpoint; it never creates fake PNGs.
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	t.eq(game.guide.active_step(), id, "guide still visible at capture " + id)
	var img := tree.root.get_texture().get_image()
	t.ok(img != null and not img.is_empty(), "rendered screenshot " + id)
	if img == null or img.is_empty():
		return
	t.eq(img.get_size(), Vector2i(1280, 720), "screenshot dimensions " + id)
	var path := out.path_join("%02d_%s.png" % [shots.size() + 1, id])
	var err := img.save_png(path)
	t.eq(err, OK, "save screenshot " + id)
	if err == OK:
		shots[id] = path
		print("SHOT ", path)

func _send(cmd: StringName, args: Dictionary = {}) -> Dictionary:
	var result := game.engine.send(cmd, args)
	t.ok(bool(result.get("ok", false)), "real command %s: %s" % [cmd, result.get("err", "")])
	return result

func _offer(uid: String) -> void:
	var tier := "kind"
	if bool(profile.get("afford", false)):
		tier = _affordable_tier(uid)
	var result := _send(&"counter.offer", {"uid": uid, "tier": tier})
	if str(result.get("reply", "")) == "counter":
		_send(&"counter.answer", {"uid": uid, "accept": true})

# Formal data: the guide tells the player to offer the middle price the first time (gd.d1.tiers), and
# the 10-22 tutorial prices make that work for pawn -> sell -> buy on day 1. The formal walk follows the
# advice when the shop pays and asserts the till covers it; when the shop sells it asks the kind price.
func _affordable_tier(uid: String) -> String:
	var cv: Dictionary = game.engine.query(&"counter", {"uid": uid})
	var tiers: Dictionary = cv.get("tiers", {})
	var cash := CardCurrency.money((game.engine as CardEngine).ctx)
	print("K14 REAL GUIDE till uid=%s intent=%s cash=%d tiers=%s" % [uid, cv.get("intent", ""), cash, tiers])
	if str(cv.get("direction", "")) != "pay" or tiers.is_empty():
		return "kind"
	t.ok(int(tiers.get("fair", 0)) <= cash, "till covers the fair offer the guide recommends for " + uid)
	return "fair"

func _night() -> void:
	var offers: Array = game.engine.view().get("night_offers", [])
	t.ok(not offers.is_empty(), "real night offers exist")
	if offers.is_empty():
		return
	# Same rule as G02's real firsts: nt.tidy when dealt, otherwise the first real offer.
	var row: Dictionary = offers[0]
	for offer in offers:
		if str(offer.get("def", "")) == "nt.tidy":
			row = offer
	var panel := game.host.play_panel() as CardNightPanel
	t.ok(panel != null, "actual night panel is open")
	if panel == null:
		return
	panel.on_card_played("", str(row.get("def", "")))
	if not row.get("choices", []).is_empty():
		panel.on_reply(str(row["choices"][0]))

func _uid(def_id: String) -> String:
	var uid := Real._uid(game.engine as CardEngine, def_id)
	t.ok(uid != "", "real tutorial dealt " + def_id)
	return uid

func _select(uid: String) -> void:
	var hand: Array = game.engine.view().get("hand", [])
	for i in hand.size():
		if str(hand[i].get("uid", "")) == uid:
			game.hand.select_index(i)
			return
	t.ok(false, "select actual hand card " + uid)

func _close_play() -> void:
	if game.host.play_panel() != null:
		game.host.close_panel(game.host.play_panel())
	await _frame()

func _first(mechanism: StringName, args: Dictionary) -> void:
	var commands := (game.engine as CardEngine).command_log()
	firsts.append([int(game.engine.view().get("date", {}).get("abs_day", 0)),
		str(commands.back()[0]), str(mechanism), args.duplicate(true)])

func _cleanup() -> void:
	game.queue_free()
	bus.queue_free()
	CardAnchors.clear()
	await t.frames(2)
