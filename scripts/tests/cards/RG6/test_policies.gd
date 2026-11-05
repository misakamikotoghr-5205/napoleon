# RG6_policies: every autoplay policy on the rogue v1 stocktake overlay (Mock fixtures, ROGUE_V1.md §13 shape):
# the first stock.pick follows the policy's taste (§14 RG6), a full shelf adds replace = oldest held, the pass comes
# last, refuser never picks, idle takes the first item and otherwise only closes the day, trader never mortgages for
# the counter, and the peddler's "look" sorts before "send_off" without reordering any choice id that existed before.
# RG4's §13 fixtures do not exist before the v1 merge, so the fixtures are RG6's own (same shape); once
# scripts/tests/cards/RG4/fixtures/ is there, the independent spec oracle (_spec_first) runs over those files too.
extends SceneTree
const T := preload("res://scripts/tests/cards/lib/card_t.gd")
const Runner := preload("res://scripts/cards/sim/balance_main.gd")
const FX := "res://scripts/tests/cards/RG6/fixtures/"
const RG4_FX := "res://scripts/tests/cards/RG4/fixtures/"
const PICK_KEYS: Array = ["offer", "pick", "replace"]
const PEDDLER_DEF := "p.stranger_peddler.1938.curios"
const DEPTH_ORDER: Array = ["treasure", "storied", "plain"]
const TRADER_SOURCES: Array = ["ky.traveling_buyers", "ky.needy_neighbors"]
const KIND_SOURCES: Array = ["ky.old_customers", "ky.needy_neighbors"]

## fixture -> policy -> expected stock.pick order (item ids, "" = the pass); fair order = the offer's own order.
const ORDERS := {
	"rogue_week": {
		"fair": ["rl.chen_mortar", "ky.traveling_buyers", "rl.blue_curtain", ""],
		"greedy": ["rl.chen_mortar", "rl.blue_curtain", "ky.traveling_buyers", ""],
		"hoarder": ["rl.chen_mortar", "rl.blue_curtain", "ky.traveling_buyers", ""],
		"kind": ["ky.traveling_buyers", "rl.chen_mortar", "rl.blue_curtain", ""]},
	"rogue_few": {
		"fair": ["rl.chen_mortar", "ky.traveling_buyers", ""],
		"greedy": ["rl.chen_mortar", "ky.traveling_buyers", ""],
		"hoarder": ["rl.chen_mortar", "ky.traveling_buyers", ""],
		"kind": ["ky.traveling_buyers", "rl.chen_mortar", ""]},
	"rogue_mix": {
		"fair": ["rl.blue_curtain", "ky.old_customers", "rl.rosewood_abacus", ""],
		"greedy": ["rl.rosewood_abacus", "rl.blue_curtain", "ky.old_customers", ""],
		"hoarder": ["rl.blue_curtain", "rl.rosewood_abacus", "ky.old_customers", ""],
		"kind": ["ky.old_customers", "rl.blue_curtain", "rl.rosewood_abacus", ""]},
	"rogue_sources": {
		"fair": ["ky.dockhands", "ky.needy_neighbors", "ky.traveling_buyers", ""],
		"greedy": ["ky.traveling_buyers", "ky.needy_neighbors", "ky.dockhands", ""],
		"hoarder": ["ky.dockhands", "ky.needy_neighbors", "ky.traveling_buyers", ""],
		"kind": ["ky.needy_neighbors", "ky.dockhands", "ky.traveling_buyers", ""]},
	"rogue_peddler": {
		"fair": ["rl.stub_box", "rl.oilpaper_umbrella", ""],
		"greedy": ["rl.stub_box", "rl.oilpaper_umbrella", ""],
		"hoarder": ["rl.stub_box", "rl.oilpaper_umbrella", ""],
		"kind": ["rl.stub_box", "rl.oilpaper_umbrella", ""]},
}
## Policies that share another one's stocktake order.
const SAME_AS := {"wheel": "fair", "random": "fair", "idle": "fair", "trader": "greedy"}
## The pre-rogue _choice_score preference lists (policy.gd before RG6), for the golden-safety comparison.
const OLD_PREFERRED := {"greedy": ["harsh", "squeeze", "demand", "refuse"], "kind": ["kind", "give", "free", "help"]}


func _initialize() -> void:
	var t: RefCounted = T.new(self, "RG6_policies")
	_registry(t)
	for fixture in ORDERS.keys():
		_orders(t, str(fixture))
	_spec_oracle(t)
	_full(t)
	_full_through_mock(t)
	_closed(t)
	_refuser(t)
	_idle(t)
	_random(t)
	_peddler_card(t)
	_choice_scores(t)
	_trader_counter(t)
	_send_through_mock(t)
	t.finish()


func _mock(name: String) -> MockCardEngine:
	var mock := MockCardEngine.new()
	mock.load_fixture(FX + name + ".json")
	return mock


func _policy(name: String, seed_value: int = 7) -> CardPolicy:
	return Runner.POLICIES[name].new(seed_value)


func _picks(actions: Array) -> Array:
	return actions.filter(func(a: Array) -> bool: return str(a[0]) == "stock.pick")


func _pick_ids(actions: Array) -> Array:
	return _picks(actions).map(func(a: Array) -> String: return str(a[1].get("pick", "")))


func _registry(t: RefCounted) -> void:
	for name in ["trader", "idle"]:
		t.ok(Runner.POLICIES.has(name), "balance_main registers " + name)
	for name in Runner.POLICIES.keys():
		t.eq(str(_policy(str(name)).policy_name()), str(name), "policy_name matches its POLICIES key " + str(name))


## Candidate order on every fixture for every policy; the stock block comes before the phase's own command.
func _orders(t: RefCounted, fixture: String) -> void:
	var mock := _mock(fixture)
	var view: Dictionary = mock.view()
	for name in Runner.POLICIES.keys():
		if name == "refuser":
			continue
		var want: Array = ORDERS[fixture][SAME_AS.get(name, name)]
		var candidates: Array = _policy(str(name))._candidates(mock, view)
		t.eq(_pick_ids(candidates), want, "%s %s stock.pick order" % [fixture, name])
		t.ok(not candidates.is_empty() and str(candidates[0][0]) == "stock.pick",
			"%s %s: a stock.pick is the first candidate" % [fixture, name])
		var last_pick: int = -1
		for i in range(candidates.size()):
			if str(candidates[i][0]) == "stock.pick":
				last_pick = i
				_pick_shape(t, candidates[i][1], fixture, view)
		t.ok(last_pick == want.size() - 1, "%s %s: the picks are one block at the front" % [fixture, name])
		if name != "random":
			t.eq(_policy(str(name)).decide(mock, view), candidates[0], "%s %s decide = first candidate" % [fixture, name])


func _pick_shape(t: RefCounted, args: Dictionary, fixture: String, view: Dictionary) -> void:
	var offer: String = str(view.get("open_panel", {}).get("args", {}).get("offer", ""))
	t.eq(str(args.get("offer", "")), offer, fixture + " pick names the open offer")
	for key in args.keys():
		t.ok(str(key) in PICK_KEYS and typeof(args[key]) == TYPE_STRING, fixture + " pick arg is a known string " + str(key))
	t.ok(not args.has("replace"), fixture + " not full: no replace")


## Every fixture with the stocktake overlay open (RG6's own, plus RG4's §13 set once it exists): each policy's first
## candidate is what _spec_first derives from the query alone; refuser proposes no pick; a closed offer gives none.
func _spec_oracle(t: RefCounted) -> void:
	var checked: int = 0
	for path in _fixture_paths():
		var mock := MockCardEngine.new()
		mock.load_fixture(path)
		var view: Dictionary = mock.view()
		var panel: Dictionary = view.get("open_panel", {})
		if str(panel.get("kind", "")) != "stocktake":
			continue
		var query_args: Dictionary = {}
		if str(panel.get("args", {}).get("offer", "")) != "":
			query_args["offer"] = str(panel["args"]["offer"])
		var offer: Dictionary = mock.query(&"stocktake", query_args)
		var open: bool = bool(offer.get("ok", false)) and str(offer.get("status", "")) == "open"
		checked += 1
		for name in Runner.POLICIES.keys():
			var picks: Array = _picks(_policy(str(name))._candidates(mock, view))
			if name == "refuser" or not open:
				t.ok(picks.is_empty(), "%s %s: no pick" % [path.get_file(), name])
			elif name == "random":
				t.eq(picks.size(), offer.get("items", []).size() + 1, path.get_file() + " random: every item + pass")
			else:
				t.eq(picks[0][1] if not picks.is_empty() else {}, _spec_first(str(name), offer),
					"%s %s: first pick follows the section 14 taste" % [path.get_file(), name])
	t.ok(checked >= 6, "spec oracle ran on the stocktake fixtures (%d)" % checked)


func _fixture_paths() -> Array:
	var out: Array = []
	for dir in [FX, RG4_FX]:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		var names: Array = Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".json"))
		names.sort()
		for file_name in names:
			out.append(str(dir) + str(file_name))
	return out


## §14 RG6 restated independently of policy.gd: fair / wheel / idle take the offer's first item; greedy and trader the
## deepest relic (offer order on ties), else the buyer, else the pawner source, else the first source; hoarder the first
## relic; kind the old customers, else the needy neighbours, else the first source, else the first relic. A relic on a
## full shelf replaces held[0].
func _spec_first(name: String, offer: Dictionary) -> Dictionary:
	var items: Array = offer.get("items", [])
	var relics: Array = items.filter(func(i: Dictionary) -> bool: return str(i.get("kind", "")) == "relic")
	var sources: Array = items.filter(func(i: Dictionary) -> bool: return str(i.get("kind", "")) == "source")
	var first: Dictionary = items[0] if not items.is_empty() else {}
	match name:
		"greedy", "trader":
			first = _deepest(relics) if not relics.is_empty() else _preferred(sources, TRADER_SOURCES)
		"hoarder":
			first = relics[0] if not relics.is_empty() else first
		"kind":
			first = _preferred(sources, KIND_SOURCES) if not sources.is_empty() else first
	var pick: Dictionary = {"offer": str(offer.get("offer", "")), "pick": str(first.get("id", ""))}
	var held: Array = offer.get("held", [])
	if bool(offer.get("full", false)) and str(first.get("kind", "")) == "relic" and not held.is_empty():
		pick["replace"] = str(held[0].get("id", ""))
	return pick


func _deepest(relics: Array) -> Dictionary:
	for depth in DEPTH_ORDER:
		for item in relics:
			if str(item.get("depth", "")) == depth:
				return item
	return relics[0]


func _preferred(sources: Array, ids: Array) -> Dictionary:
	for id in ids:
		for item in sources:
			if str(item.get("id", "")) == str(id):
				return item
	return sources[0] if not sources.is_empty() else {}


func _full(t: RefCounted) -> void:
	var mock := _mock("rogue_full")
	var view: Dictionary = mock.view()
	for name in ["fair", "greedy", "trader", "hoarder", "kind", "wheel"]:
		for action in _picks(_policy(name)._candidates(mock, view)):
			var pick: String = str(action[1].get("pick", ""))
			if pick.begins_with("rl."):
				t.eq(str(action[1].get("replace", "")), "rl.stub_box", "full %s: relic %s replaces the oldest" % [name, pick])
			else:
				t.ok(not action[1].has("replace"), "full %s: no replace on %s" % [name, pick if pick != "" else "pass"])
	t.eq(_policy("fair").decide(mock, view), [&"stock.pick", {"offer": "w0.1", "pick": "rl.chen_mortar",
		"replace": "rl.stub_box"}], "full fair decide")
	t.eq(_policy("kind").decide(mock, view), [&"stock.pick", {"offer": "w0.1", "pick": "ky.traveling_buyers"}],
		"full kind takes the source, no replace")
	t.eq(_policy("idle").decide(mock, view), [&"stock.pick", {"offer": "w0.1", "pick": "rl.chen_mortar",
		"replace": "rl.stub_box"}], "full idle decide")


## §13 rogue_full answers relic_full to a bare relic pick and ok with replace: what the policies send is the ok one.
func _full_through_mock(t: RefCounted) -> void:
	var bare := _mock("rogue_full")
	t.eq(str(bare.send(&"stock.pick", {"offer": "w0.1", "pick": "rl.chen_mortar"}).get("err", "")), "relic_full",
		"full fixture: a bare relic pick is refused")
	for name in ["fair", "greedy", "trader", "hoarder", "idle"]:
		var mock := _mock("rogue_full")
		var action: Array = _policy(name).decide(mock, mock.view())
		t.eq(action[1].get("replace", ""), "rl.stub_box", name + " full: sends the replace")
		var result: Dictionary = mock.send(action[0], action[1])
		t.ok(bool(result.get("ok", false)), "%s full pick accepted: %s" % [name, JSON.stringify(action)])
		t.eq(str(result.get("released", "")), "rl.stub_box", name + " full: the oldest is released")
		var held: Array = mock.view().get("relics", {}).get("held", [])
		t.eq(held.size(), 6, name + " full: still six on the shelf")
		t.ok(not held.any(func(h: Dictionary) -> bool: return str(h.get("id", "")) == "rl.stub_box"),
			name + " full: the released one is gone from the shelf")


func _closed(t: RefCounted) -> void:
	var mock := _mock("rogue_closed")
	var view: Dictionary = mock.view()
	for name in Runner.POLICIES.keys():
		var candidates: Array = _policy(str(name))._candidates(mock, view)
		t.ok(_picks(candidates).is_empty(), "lapsed offer: no stock.pick for " + str(name))
		if name != "refuser":
			t.eq(candidates[0], [&"settle.next", {}], "lapsed offer: %s goes on with settle.next" % name)
	t.eq(_policy("idle").decide(mock, view), [&"day.end", {"confirm": true}], "lapsed offer: idle closes the day")


func _refuser(t: RefCounted) -> void:
	for fixture in ["rogue_week", "rogue_few", "rogue_full", "rogue_peddler", "rogue_peddler_card"]:
		var mock := _mock(fixture)
		var view: Dictionary = mock.view()
		var refuser: CardPolicy = _policy("refuser")
		t.eq(refuser.decide(mock, view), [&"day.end", {"confirm": true}], fixture + ": refuser only closes the day")
		t.ok(_picks(refuser._candidates(mock, view)).is_empty(), fixture + ": refuser candidates never pick")


## idle: the first untried item in offer order, never the pass; then refuser behaviour.
func _idle(t: RefCounted) -> void:
	var mock := _mock("rogue_week")
	var view: Dictionary = mock.view()
	var idle: CardPolicy = _policy("idle")
	t.eq(idle.decide(mock, view), [&"stock.pick", {"offer": "w0.1", "pick": "rl.chen_mortar"}], "idle takes the first")
	t.eq(idle.decide(mock, view), [&"stock.pick", {"offer": "w0.1", "pick": "ky.traveling_buyers"}],
		"idle: same view after a failed pick tries the next item")
	t.eq(idle.decide(mock, view), [&"stock.pick", {"offer": "w0.1", "pick": "rl.blue_curtain"}], "idle third item")
	t.eq(idle.decide(mock, view), [&"day.end", {"confirm": true}], "idle never passes explicitly; closes the day")
	var sources := _mock("rogue_sources")
	t.eq(_policy("idle").decide(sources, sources.view()), [&"stock.pick", {"offer": "w0.0", "pick": "ky.dockhands"}],
		"idle takes the first source")
	var peddler := _mock("rogue_peddler")
	t.eq(_policy("idle").decide(peddler, peddler.view()), [&"stock.pick", {"offer": "p8", "pick": "rl.stub_box"}],
		"idle takes a free peddler pick if the overlay is open")
	var card := _mock("rogue_peddler_card")
	t.eq(_policy("idle").decide(card, card.view()), [&"day.end", {"confirm": true}], "idle never looks at the peddler")
	var counter := _mock("rogue_counter_poor")
	t.eq(_policy("idle").decide(counter, counter.view()), [&"day.end", {"confirm": true}], "idle skips the counter")


func _random(t: RefCounted) -> void:
	var mock := _mock("rogue_week")
	var view: Dictionary = mock.view()
	var candidates: Array = _policy("random", 11)._candidates(mock, view)
	var seen: Dictionary = {}
	for seed_value in range(1, 41):
		var first: Array = _policy("random", seed_value).decide(mock, view)
		t.eq(_policy("random", seed_value).decide(mock, view), first, "random is deterministic for seed %d" % seed_value)
		t.ok(candidates.has(first), "random picks one of the candidates")
		seen[JSON.stringify(first)] = true
	t.ok(seen.size() >= 2, "random spreads over several candidates")


func _peddler_card(t: RefCounted) -> void:
	var mock := _mock("rogue_peddler_card")
	var view: Dictionary = mock.view()
	for name in ["fair", "greedy", "kind", "hoarder", "wheel", "trader"]:
		var candidates: Array = _policy(name)._candidates(mock, view)
		t.eq(candidates[0], [&"card.choose", {"uid": "c0100", "choice": "look"}], name + ": look before send_off")
		t.ok(candidates.has([&"card.choose", {"uid": "c0100", "choice": "send_off"}]), name + ": send_off still offered")
		t.eq(_policy(name).decide(mock, view), candidates[0], name + " decides to look")
	var policy: CardPolicy = _policy("fair")
	var look: Array = policy.decide(mock, view)
	t.ok(bool(mock.send(look[0], look[1]).get("ok", false)), "mock accepts card.choose look")
	t.eq(policy.decide(mock, mock.view()), [&"stock.pick", {"offer": "p8", "pick": "rl.stub_box"}],
		"after look the peddler offer is picked from the overlay")


## New scores keep every pairwise order of the real choice ids (golden safety); "look" sits just above unmatched ids.
func _choice_scores(t: RefCounted) -> void:
	var ids: Array = _real_choice_ids()
	t.ok(ids.size() > 50, "real data has many choice ids")
	t.ok(not ids.has("look"), "only the rogue peddler card uses the exact choice id look")
	for name in Runner.POLICIES.keys():
		var policy: CardPolicy = _policy(str(name))
		var old: Array = OLD_PREFERRED.get(str(name), ["fair", "accept", "help"])
		var flips: int = 0
		for a in ids:
			for b in ids:
				if (_old_score(old, a) > _old_score(old, b)) != (policy._choice_score(a) > policy._choice_score(b)):
					flips += 1
		t.eq(flips, 0, "%s: no pre-rogue choice pair changes order" % name)
		t.ok(policy._choice_score("look") > policy._choice_score("send_off"), str(name) + ": look > send_off")
		t.ok(policy._choice_score("look") < policy._choice_score(str(old[old.size() - 1])),
			str(name) + ": look below every preferred word")


func _old_score(preferred: Array, choice_id: String) -> int:
	for word in preferred:
		if choice_id.contains(str(word)):
			return preferred.size() - preferred.find(word)
	return 0


## Choice ids of every real card except the rogue v1 peddler (RG3's p.stranger_peddler.1938.curios, the one "look").
func _real_choice_ids() -> Array:
	var db: CardDB = CardDB.load_all("res://data/cards", {})
	var seen: Dictionary = {}
	for type_name in CardIds.TYPE_PREFIX.keys():
		for id in db.ids_of(StringName(str(type_name))):
			if id == PEDDLER_DEF:
				continue
			for choice in db.def(id).get("choices", []):
				if typeof(choice) == TYPE_DICTIONARY and str(choice.get("id", "")) != "":
					seen[str(choice["id"])] = true
	var out: Array = seen.keys()
	out.sort()
	return out


func _trader_counter(t: RefCounted) -> void:
	var mock := _mock("rogue_counter_poor")
	var view: Dictionary = mock.view()
	var fair: Array = _policy("fair")._counter(mock, "c0002", view)
	var trader: Array = _policy("trader")._counter(mock, "c0002", view)
	t.ok(fair.any(func(a: Array) -> bool: return str(a[0]) == "estate.mortgage"), "fair mortgages when cash is short")
	t.ok(not trader.any(func(a: Array) -> bool: return str(a[0]) == "estate.mortgage"), "trader never mortgages")
	t.eq(trader, fair.filter(func(a: Array) -> bool: return str(a[0]) != "estate.mortgage"),
		"trader = fair counter minus the mortgages")
	t.eq(trader[0], [&"counter.offer", {"uid": "c0002", "tier": "fair"}], "trader offers the fair tier")
	t.eq(trader[trader.size() - 1], [&"counter.refuse", {"uid": "c0002"}], "trader can still refuse")
	var policy: CardPolicy = _policy("trader")
	t.eq(policy.decide(mock, view), [&"counter.offer", {"uid": "c0002", "tier": "fair"}], "trader decide: fair offer")
	t.eq(policy.decide(mock, view), [&"counter.refuse", {"uid": "c0002"}], "trader: after a failed offer it refuses")


## The chosen picks are commands the Mock (and §4.2) accepts: ok for the offered item and the pass, nothing ui.*.
func _send_through_mock(t: RefCounted) -> void:
	for name in ["fair", "greedy", "trader", "hoarder", "kind", "idle"]:
		var mock := _mock("rogue_week")
		var action: Array = _policy(name).decide(mock, mock.view())
		t.ok(not str(action[0]).begins_with("ui."), name + " never sends ui.*")
		var result: Dictionary = mock.send(action[0], action[1])
		t.ok(bool(result.get("ok", false)), "%s pick accepted: %s" % [name, JSON.stringify(action)])
		t.eq(str(mock.view().get("open_panel", {}).get("kind", "")), "", name + ": overlay cleared after the pick")
		t.ok(_picks(_policy(name)._candidates(mock, mock.view())).is_empty(), name + ": nothing left to pick")
	var mock := _mock("rogue_week")
	var pass_action: Array = _picks(_policy("fair")._candidates(mock, mock.view())).back()
	t.eq(pass_action, [&"stock.pick", {"offer": "w0.1", "pick": ""}], "the pass is the last pick")
	t.ok(bool(mock.send(pass_action[0], pass_action[1]).get("ok", false)), "mock accepts the pass")
