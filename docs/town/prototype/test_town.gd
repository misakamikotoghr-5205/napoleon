extends SceneTree
const Sim = preload("res://town_sim.gd")

func accept_all(v: Dictionary, sim) -> String:
	return "accept"
func refuse_stolen(v: Dictionary, sim) -> String:
	return "refuse" if v["intent"] == "sell_stolen" else "accept"

func norm(x) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(x, "", true)), "", true)

func run(seed: int, days: int, policy: Callable, verbose := false) -> Array:
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://town_pack.json"))
	var sim = Sim.new(pack, seed)
	var reports: Array = []
	for d in range(days):
		var r: Dictionary = sim.advance_day()
		sim.run_slots(policy)
		reports.append(JSON.parse_string(JSON.stringify(sim.s["day_report"])))
		if verbose:
			var vis: Array = []
			for v in r.get("visits", []):
				vis.append("%s:%s@%d" % [v["who"], v["intent"], int(v["slot"])])
			var bills: Array = []
			for b in r.get("bills", []):
				bills.append("%s%d" % [b["label"], int(b["amount"])])
			print("D%02d wd%d %s rice=%.2f heat=%.2f unrest=%.2f | bills=%d %s | ev=%s | visits=%s | unlock=%s | heard=%s | inst=%s | cash=%d" % [int(r["day"]), int(r["weekday"]), r["weather"], r["pressures"]["rice_price"], r["pressures"]["heat"], r["pressures"]["unrest"], int(r["bill_total"]), ",".join(bills), str(r.get("events", [])), ",".join(vis), str(r.get("unlocks", [])), str(r.get("player_heard", [])), str(r.get("institution", [])), int(sim.s["cash"]["player"])])
	return [sim, reports]

func _init():
	var ok := true
	var a = run(1938, 21, accept_all, true)
	var b = run(1938, 21, accept_all)
	var same := norm(a[1]) == norm(b[1]) and norm(a[0].s) == norm(b[0].s)
	print("deterministic same seed: ", same); ok = ok and same
	# save at day 10 (JSON round trip), resume to 21
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://town_pack.json"))
	var c = Sim.new(pack, 1938)
	for d in range(10):
		c.advance_day(); c.run_slots(accept_all)
	var saved: String = c.save_json()
	var e = Sim.new(pack, 0)
	e.load_json(saved)
	for d in range(11):
		e.advance_day(); e.run_slots(accept_all)
	var resumed := norm(e.s) == norm(a[0].s)
	print("save/resume identical: ", resumed); ok = ok and resumed
	var other = run(7, 21, accept_all)
	var differs := norm(other[1]) != norm(a[1])
	print("other seed differs: ", differs); ok = ok and differs
	# exogenous independence: refusing stolen goods changes heat/civic, never climate/market draws
	var f = run(1938, 21, refuse_stolen)
	var exo_same := true
	var endo_diff := false
	for i in range(21):
		var ea: Array = []
		var eb: Array = []
		for x in a[1][i].get("events", []):
			if x.begins_with("climate/") or x.begins_with("market/"): ea.append(x)
		for x in f[1][i].get("events", []):
			if x.begins_with("climate/") or x.begins_with("market/"): eb.append(x)
		if ea != eb or a[1][i]["weather"] != f[1][i]["weather"] or a[1][i]["pressures"]["rice_price"] != f[1][i]["pressures"]["rice_price"]:
			exo_same = false
		if a[1][i]["pressures"]["heat"] != f[1][i]["pressures"]["heat"]:
			endo_diff = true
	print("exogenous wheels independent of player: ", exo_same, "  heat differs by policy: ", endo_diff)
	ok = ok and exo_same
	print("ALL_OK" if ok else "FAIL")
	quit()
