# PROTOTYPE: GameJev living-world ideas ported to a day/slot town generator for 德厚当.
# Every random number is JevRng.draw(seed, domain, [semantic key]) -> no shared RNG stream,
# so player actions never shift weather/market draws, and save/resume replays exactly.
# All state lives in `s` (JSON-safe Dictionary). Pack is read-only.
extends RefCounted

const R = preload("res://jev_rng.gd")

var pack: Dictionary
var s: Dictionary
var intent_chooser: Callable = Callable()   # optional hook: (npc_id, rows:Array, key:String) -> String (e.g. Mind.decide)

func _init(p_pack: Dictionary, seed: int) -> void:
	pack = p_pack
	_validate_pack()
	s = {"seed": seed, "day": 0, "slot": 0, "weather": "晴", "pressures": {}, "wheel_last": {},
		"unlocked": {}, "flags": {}, "flags_today": {}, "stats": {"koubei": 50}, "cash": {"player": 300},
		"npc_cash": {}, "tickets": {}, "known": {}, "seen": {}, "queue": [], "seq": 0,
		"spawns": [], "influence_spent": {}, "stolen_stock": 0, "day_report": {}, "player_rumors": {}}
	for k in pack["pressures"]:
		s["pressures"][k] = float(pack["pressures"][k]["base"])
	for b in pack["buildings"]:
		if pack["buildings"][b].get("unlocked", false):
			s["unlocked"][b] = true
	for n in pack["npcs"]:
		s["npc_cash"][n] = int(pack["npcs"][n].get("cash", 0))
		s["known"][n] = {}

# ---------------------------------------------------------------- validation (GameJev rules)
func _validate_pack() -> void:
	for w in pack["wheels"] + _deck_list():
		var has_quiet := false
		for e in w["outcomes"]:
			if e["id"] == "quiet" and float(e["weight"]) > 0 and e["effects"].is_empty() and int(e["cooldown_days"]) == 0 and not e.has("pressure") and not e.has("when"):
				has_quiet = true
			if w.get("mode", "exogenous") == "exogenous" and e.has("pressure"):
				for k in e["pressure"]:
					assert(pack["pressures"][k]["kind"] != "endogenous", "exogenous wheel cannot read endogenous pressure")
		assert(has_quiet, "each wheel needs an always-eligible quiet outcome")

func _deck_list() -> Array:
	var out: Array = []
	for b in _sorted(pack.get("building_decks", {}).keys()):
		var d: Dictionary = pack["building_decks"][b].duplicate()
		d["id"] = "deck:" + b
		d["building"] = b
		d["mode"] = "endogenous"
		out.append(d)
	return out

# ---------------------------------------------------------------- helpers
func u(domain: String, key: Array) -> float:
	return R.draw(int(s["seed"]), domain, key)

static func _sorted(a: Array) -> Array:
	var b := a.duplicate()
	b.sort()
	return b

func weekday() -> int:
	return (int(pack["time"]["start_weekday"]) + int(s["day"])) % 7

func season() -> int:
	return int(floor(float(s["day"]) / float(pack["time"]["season_days"]))) % 4

func abs_slot() -> int:
	return int(s["day"]) * 6 + int(s["slot"])

func _report(kind: String, v) -> void:
	var r: Dictionary = s["day_report"]
	if not r.has(kind):
		r[kind] = []
	r[kind].append(v)

func cond(c) -> bool:
	if c == null or (c is Dictionary and c.is_empty()):
		return true
	if c.has("all"):
		for x in c["all"]:
			if not cond(x): return false
		return true
	if c.has("any"):
		for x in c["any"]:
			if cond(x): return true
		return false
	if c.has("not"): return not cond(c["not"])
	if c.has("day_gte"): return int(s["day"]) >= int(c["day_gte"])
	if c.has("flag"): return bool(s["flags"].get(c["flag"], false)) or bool(s["flags_today"].get(c["flag"], false))
	if c.has("stat_gte"): return float(s["stats"].get(c["stat_gte"][0], 0)) >= float(c["stat_gte"][1])
	if c.has("pressure_gte"): return float(s["pressures"][c["pressure_gte"][0]]) >= float(c["pressure_gte"][1])
	if c.has("weekday"): return weekday() == int(c["weekday"])
	if c.has("weather"): return s["weather"] == c["weather"]
	if c.has("building"): return s["unlocked"].has(c["building"])
	push_error("unknown condition " + str(c))
	return false

# ---------------------------------------------------------------- endogenous influence (GameJev _offer_influence, simplified)
func add_influence(key: String, amount: float, source: String) -> float:
	var cap: float = float(pack["influence"]["daily_cap"].get(key, 1.0))
	var bk := "%d:%s" % [int(s["day"]), key]
	var spent: float = float(s["influence_spent"].get(bk, 0.0))
	var accepted: float = signf(amount) * minf(absf(amount), maxf(0.0, cap - spent))
	s["influence_spent"][bk] = spent + absf(accepted)
	var spec: Dictionary = pack["pressures"][key]
	s["pressures"][key] = clampf(float(s["pressures"][key]) + accepted, float(spec["min"]), float(spec["max"]))
	_report("influence", "%s %+.3f (%s)" % [key, accepted, source])
	return accepted

# ---------------------------------------------------------------- day pipeline
func advance_day() -> Dictionary:
	s["day"] = int(s["day"]) + 1
	s["slot"] = 0
	s["flags_today"] = {}
	s["day_report"] = {"day": s["day"], "weekday": weekday()}
	_step_pressures()
	for w in pack["wheels"]:
		_spin(w)
	for d in _deck_list():
		if s["unlocked"].has(d["building"]):
			_spin(d)
	_feeds()
	_unlocks()
	_bills()
	_plan_visits()
	s["day_report"]["weather"] = s["weather"]
	var pr := {}
	for k in _sorted(s["pressures"].keys()):
		pr[k] = snappedf(float(s["pressures"][k]), 0.001)
	s["day_report"]["pressures"] = pr
	return s["day_report"]

func run_slots(player_policy: Callable) -> void:
	# visits happen in their slot; rumors relay slot by slot (delay/ttl measured in slots)
	for sl in range(6):
		s["slot"] = sl
		_deliver_messages()
		for v in s["day_report"].get("visits", []):
			if int(v["slot"]) == sl:
				_on_visit(v, player_policy)
	s["slot"] = 5

func _step_pressures() -> void:
	for k in _sorted(pack["pressures"].keys()):
		var spec: Dictionary = pack["pressures"][k]
		var x: float = float(s["pressures"][k])
		if spec["kind"] == "endogenous":
			x = float(spec["base"]) + (x - float(spec["base"])) * pow(2.0, -1.0 / float(spec["half_life_days"]))
		else:
			x += float(spec.get("revert", 0.0)) * (float(spec["base"]) - x)
			x += float(spec.get("noise", 0.0)) * (2.0 * u("pressure:" + k, [s["day"]]) - 1.0)
		s["pressures"][k] = clampf(x, float(spec["min"]), float(spec["max"]))

# GameJev _spin_wheel: weight * cooldown gate * condition gate * pressure gate/bias * season weight; one keyed draw.
func _spin(w: Dictionary) -> String:
	var rows: Array = []
	for e in w["outcomes"]:
		var weight: float = float(e["weight"])
		var last: int = int(s["wheel_last"].get(w["id"] + ":" + e["id"], -1000000))
		if int(s["day"]) - last < int(e["cooldown_days"]): weight = 0.0
		if e.has("requires_building") and not s["unlocked"].has(e["requires_building"]): weight = 0.0
		if e.has("when") and not cond(e["when"]): weight = 0.0
		for pk in e.get("pressure", {}):
			var p: float = float(s["pressures"][pk])
			var spec: Dictionary = e["pressure"][pk]
			if p < float(spec.get("min", 0.0)): weight = 0.0
			weight *= maxf(0.0, 1.0 + float(spec.get("bias", 0.0)) * p)
		if e.has("season_weights"): weight *= float(e["season_weights"][season()])
		rows.append([e["id"], weight])
	var choice: String = R.weighted_choice(rows, u("wheel:" + w["id"], [s["day"]]))
	s["wheel_last"][w["id"] + ":" + choice] = int(s["day"])
	if choice != "quiet":
		_report("events", w["id"] + "/" + choice)
	for e in w["outcomes"]:
		if e["id"] == choice:
			for eff in e["effects"]:
				_effect(eff, w["id"] + "/" + choice)
	return choice

func _effect(eff: Dictionary, src: String) -> void:
	match eff["op"]:
		"weather": s["weather"] = eff["value"]
		"pressure_add":
			if pack["pressures"][eff["key"]]["kind"] == "endogenous":
				add_influence(eff["key"], float(eff["value"]), src)
			else:
				var spec: Dictionary = pack["pressures"][eff["key"]]
				s["pressures"][eff["key"]] = clampf(float(s["pressures"][eff["key"]]) + float(eff["value"]), float(spec["min"]), float(spec["max"]))
		"news": _report("news", "%s（%s）" % [eff["text"], eff["via"]])
		"flag_today": s["flags_today"][eff["key"]] = true
		"bill":
			var amt: int = int(eff["min"]) + int(floor(u("bill:" + src, [s["day"]]) * float(int(eff["max"]) - int(eff["min"]) + 1)))
			_report("bills", {"label": eff["label"], "amount": amt, "payee": eff["payee"]})
		"rumor": plant(eff["key"], eff["origin"], 1.0)
		"spawn_visit": s["spawns"].append({"due": int(s["day"]) + int(eff.get("delay_days", 0)), "who": eff["who"], "intent": eff["intent"], "item": eff.get("item", "")})
		"npc_feel": _report("npc_feel", "%s@%s %s+%.2f" % [eff["key"], eff["where"], eff["key"], float(eff["value"])])
		"institution": _institution(eff["id"], eff["act"])
		_: push_error("unknown effect " + eff["op"])

func _institution(inst: String, act: String) -> void:
	var spec: Dictionary = pack["institutions"][inst]["acts"][act]
	if act == "raid":
		var fine: int = int(spec["fine_min"]) + int(floor(u("raid_fine", [s["day"]]) * float(int(spec["fine_max"]) - int(spec["fine_min"]) + 1)))
		var paid: int = mini(fine, int(s["cash"]["player"]))   # a fine never materializes missing money
		s["cash"]["player"] = int(s["cash"]["player"]) - paid
		var seized: int = int(s["stolen_stock"])
		s["stolen_stock"] = 0
		_report("institution", "%s/%s fine=%d paid=%d seized=%d" % [inst, act, fine, paid, seized])
	_report("news", spec["news"])

func _feeds() -> void:
	for f in pack["influence"].get("feeds", []):
		var x: float = float(s["pressures"][f["from"]])
		if x > float(f["above"]):
			add_influence(f["to"], (x - float(f["above"])) * float(f["gain"]) * 10.0, "feed:" + f["from"])

func _unlocks() -> void:
	for b in _sorted(pack["buildings"].keys()):
		var spec: Dictionary = pack["buildings"][b]
		if not s["unlocked"].has(b) and spec.has("unlock") and cond(spec["unlock"]):
			s["unlocked"][b] = true
			_report("unlocks", b)
			if spec.has("news"): _report("news", spec["news"])

# Variable daily survival pressure: base * driving pressure * season * triangular jitter (two keyed draws).
func _bills() -> void:
	var total := 0
	for c in pack["living_costs"]:
		if c.has("when") and not cond(c["when"]): continue
		if c["period"] == "weekly" and weekday() != int(c["weekday"]): continue
		var x: float = float(c["base"])
		if c.has("scale"): x *= float(s["pressures"][c["scale"]])
		if c.has("season_mult"): x *= float(c["season_mult"][season()])
		var j: float = float(c.get("jitter", 0.0))
		x *= 1.0 + j * (u("cost:" + c["id"], [s["day"], 0]) + u("cost:" + c["id"], [s["day"], 1]) - 1.0)
		var amt: int = maxi(0, int(round(x)))
		if amt > 0:
			_report("bills", {"label": c["label"], "amount": amt, "payee": c["payee"]})
	for b in s["day_report"].get("bills", []):
		total += int(b["amount"])
	s["day_report"]["bill_total"] = total
	var paid: int = mini(total, int(s["cash"]["player"]))
	s["cash"]["player"] = int(s["cash"]["player"]) - paid
	s["day_report"]["unpaid"] = total - paid

# Which NPCs come to the pawnshop today and why (GameJev: needs + commitments + schedule + knowledge, keyed draws).
func _npc_location(n: String, slot: int) -> String:
	var sch: Dictionary = pack["npcs"][n]["schedule"]
	var row: Array = sch["default"]
	if sch.has("weekday:%d" % weekday()): row = sch["weekday:%d" % weekday()]
	if sch.has("weather:" + str(s["weather"])): row = sch["weather:" + str(s["weather"])]
	return row[slot]

func _npc_present(n: String) -> bool:
	var spec: Dictionary = pack["npcs"][n]
	return not spec.has("requires_building") or s["unlocked"].has(spec["requires_building"])

func _plan_visits() -> void:
	var visits: Array = []
	for n in _sorted(pack["npcs"].keys()):
		if not _npc_present(n): continue
		var spec: Dictionary = pack["npcs"][n]
		var vs: Dictionary = spec["visit"]
		var cash: float = float(s["npc_cash"][n])
		var need: float = clampf((float(vs["need_scale"]) - cash) / float(vs["need_scale"]), 0.0, 1.0)
		var unknown_rumors := 0
		for key in s["known"][n]:
			if not s["player_rumors"].has(key): unknown_rumors += 1
		var p: float = float(vs["base"]) + 0.25 * need + 0.08 * mini(unknown_rumors, 3) + float(vs.get("heat_gain", 0.0)) * float(s["pressures"]["heat"])
		if s["tickets"].has(n): p += 0.4
		if s["flags_today"].has("market_day"): p += 0.1
		if s["weather"] == "雨": p -= 0.05
		if u("visit", [s["day"], n]) >= clampf(p, 0.0, 0.95): continue
		var rows: Array = []
		for it in _sorted(vs["intents"].keys()):
			var w: float = float(vs["intents"][it])
			match it:
				"redeem": if not s["tickets"].has(n): w = 0.0
				"pawn": w *= 0.3 + need
				"gossip": if unknown_rumors == 0: w = 0.0
				"buy": w *= 1.0 - need
				"inspect": w *= 1.0 + 4.0 * float(s["pressures"]["heat"])
			rows.append([it, w])
		var total := 0.0
		for r in rows: total += float(r[1])
		if total <= 0.0: continue
		var intent: String
		if intent_chooser.is_valid():
			intent = intent_chooser.call(n, rows, "intent_%d" % int(s["day"]))
		else:
			intent = R.weighted_choice(rows, u("intent", [s["day"], n]))
		visits.append({"who": n, "intent": intent, "slot": _visit_slot(n)})
	# strangers: count and archetype drawn from pressure-biased deck
	var st: Dictionary = pack["strangers"]["per_day"]
	var expect: float = float(st["base"]) + float(st["unrest_gain"]) * float(s["pressures"]["unrest"])
	if s["flags_today"].has("market_day"): expect += float(st["market_day_bonus"])
	var count: int = mini(int(st["max"]), int(floor(expect + u("stranger_count", [s["day"]]))))
	for k in range(count):
		var rows2: Array = []
		for a in pack["strangers"]["archetypes"]:
			var w2: float = float(a["weight"]) * maxf(0.0, 1.0 + float(a.get("unrest_bias", 0.0)) * float(s["pressures"]["unrest"]))
			if a.has("requires_building") and not s["unlocked"].has(a["requires_building"]): w2 = 0.0
			rows2.append([a["id"], w2])
		var arch: String = R.weighted_choice(rows2, u("stranger", [s["day"], k]))
		var aspec: Dictionary = {}
		for a in pack["strangers"]["archetypes"]:
			if a["id"] == arch: aspec = a
		var irows: Array = []
		for it in _sorted(aspec["intents"].keys()): irows.append([it, float(aspec["intents"][it])])
		var intent2: String = R.weighted_choice(irows, u("stranger_intent", [s["day"], k]))
		visits.append({"who": "stranger:%s#%d" % [arch, k], "intent": intent2, "slot": 1 + int(floor(u("stranger_slot", [s["day"], k]) * 4.0))})
	# deck-spawned visits (e.g. the fence who stole rice from 米行)
	var keep: Array = []
	for sp in s["spawns"]:
		if int(sp["due"]) == int(s["day"]):
			visits.append({"who": sp["who"], "intent": sp["intent"], "slot": 2, "item": sp["item"]})
		elif int(sp["due"]) > int(s["day"]):
			keep.append(sp)
	s["spawns"] = keep
	s["day_report"]["visits"] = visits

func _visit_slot(n: String) -> int:
	var rows: Array = []
	for sl in range(1, 5):   # 上午..傍晚
		rows.append([str(sl), 3.0 if _npc_location(n, sl) == "pawnshop" else 1.0])
	return int(R.weighted_choice(rows, u("visit_slot", [s["day"], n])))

func _on_visit(v: Dictionary, player_policy: Callable) -> void:
	var decision: String = player_policy.call(v, self)
	if v["intent"] == "sell_stolen" and decision == "accept":
		s["stolen_stock"] = int(s["stolen_stock"]) + 1
		_norm("accept_stolen", "pawnshop", v["who"])
	if v["intent"] == "gossip" and pack["npcs"].has(v["who"]):
		for key in _sorted(s["known"][v["who"]].keys()):
			if not s["player_rumors"].has(key):
				var k: Dictionary = s["known"][v["who"]][key]
				s["player_rumors"][key] = true
				_report("player_heard", "%s 说：%s（%d 手，可信 %.2f）" % [v["who"], rumor_text(key, int(k["hops"])), int(k["hops"]) + 1, float(k["conf"])])
				break
	if v["intent"] == "pawn" and pack["npcs"].has(v["who"]) and decision == "accept":
		s["tickets"][v["who"]] = {"due": int(s["day"]) + 7}
		s["npc_cash"][v["who"]] = int(s["npc_cash"][v["who"]]) + 10
	if v["intent"] == "redeem" and s["tickets"].has(v["who"]) and int(s["npc_cash"][v["who"]]) >= 11:
		s["tickets"].erase(v["who"])
		s["npc_cash"][v["who"]] = int(s["npc_cash"][v["who"]]) - 11
		s["cash"]["player"] = int(s["cash"]["player"]) + 11

# GameJev _norms: detection requires a present authority; rapport/forgiveness reduce chance; plus a bragging rumor.
func _norm(act: String, building: String, actor: String) -> void:
	for rule in pack["norms"]:
		if rule["act"] != act or rule["building"] != building: continue
		var eid := "%s@%d.%d:%s" % [act, int(s["day"]), int(s["slot"]), actor]
		var witnesses: Array = []
		for n in _sorted(pack["npcs"].keys()):
			if _npc_present(n) and "authority" in pack["npcs"][n]["roles"] and _npc_location(n, int(s["slot"])) == building:
				witnesses.append(n)
		if not witnesses.is_empty() and u("norm_detection", [eid, rule["id"]]) < float(rule["detect_probability"]):
			add_influence("heat", float(rule["heat"]), "witnessed:" + eid)
		plant(rule["rumor"], actor if pack["npcs"].has(actor) else "zhouma", 0.8)

# ---------------------------------------------------------------- rumor network (GameJev _enqueue_observation/_deliver_message)
func plant(key: String, origin: String, conf: float) -> void:
	var root := "%s@%d" % [key, int(s["day"])]
	_enqueue(root, key, origin, origin, 0, conf, 0, [], abs_slot())

func _enqueue(root: String, key: String, recipient: String, reporter: String, hops: int, conf: float, delay: int, visited: Array, origin_slot: int) -> void:
	var comm: Dictionary = pack["communication"]
	var due: int = abs_slot() + delay
	if due - origin_slot > int(comm["ttl_slots"]) or conf < float(comm["min_confidence"]): return
	var dk := root + "|" + recipient
	if s["seen"].has(dk): return          # dedup BEFORE queueing: first path wins, loops cannot multiply evidence
	s["seen"][dk] = true
	s["seq"] = int(s["seq"]) + 1
	s["queue"].append([due, int(s["seq"]), {"root": root, "key": key, "to": recipient, "via": reporter, "hops": hops, "conf": conf, "visited": visited, "origin": origin_slot}])
	if delay == 0: _deliver_messages()

func _deliver_messages() -> void:
	s["queue"].sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	while not s["queue"].is_empty() and int(s["queue"][0][0]) <= abs_slot():
		var m: Dictionary = s["queue"].pop_front()[2]
		var who: String = m["to"]
		if not s["known"][who].has(m["key"]):
			s["known"][who][m["key"]] = {"hops": int(m["hops"]), "conf": float(m["conf"]), "via": m["via"], "at": abs_slot()}
		if "authority" in pack["npcs"][who]["roles"] and _npc_present(who):
			for rule in pack["norms"]:
				if rule["rumor"] == m["key"]:
					add_influence("heat", float(rule["heat"]) * float(m["conf"]), "heard:" + who)
		var comm: Dictionary = pack["communication"]
		if int(m["hops"]) >= int(comm["max_hops"]): continue
		var visited: Array = m["visited"].duplicate()
		visited.append(who)
		var links: Dictionary = pack["npcs"][who].get("links", {})
		for dst in _sorted(links.keys()):
			if dst in visited or not pack["npcs"].has(dst): continue
			var p: float = float(comm["relay_probability"]) * float(links[dst])
			if u("relay", [m["root"], who, dst, int(m["hops"]) + 1]) >= p: continue
			_enqueue(m["root"], m["key"], dst, who, int(m["hops"]) + 1, float(m["conf"]) * float(comm["confidence_decay"]), int(comm["delay_slots"]), visited, int(m["origin"]))

func rumor_text(key: String, hops: int) -> String:
	var v: Array = pack["rumors"].get(key, [key])
	return v[mini(hops, v.size() - 1)]

# ---------------------------------------------------------------- save / load
func save_json() -> String:
	return JSON.stringify(s, "", true, true)

func load_json(text: String) -> void:
	s = JSON.parse_string(text)
