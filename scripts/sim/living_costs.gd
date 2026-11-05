class_name LivingCosts
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const C = preload("res://scripts/sim/town_cond.gd")

# Generation announces obligations. Only TownSim.pay_bill transfers money.
static func generate(pack: Dictionary, s: Dictionary, world = null) -> Array:
	_ensure(s)
	var out: Array = []
	var day: int = int(s.get("day", 0))
	for spec in pack.get("living_costs", []):
		if not C.test(spec.get("when", {}), pack, s, world):
			continue
		var cost_id: String = str(spec["id"])
		var period: String = str(spec.get("period", "daily"))
		if period == "event" or period == "contract":
			var events: Array = s.get("contract_bills", []) if period == "contract" else s.get("invitations", [])
			var matched := false
			for event in events:
				if not event is Dictionary:
					continue
				if str(event.get("cost_id", "social" if period == "event" else "turnover")) != cost_id:
					continue
				matched = true
				var row: Dictionary = spec.duplicate(true)
				for key in ["label", "amount", "payee", "building", "due_day", "grace_days", "late_effects"]:
					if event.has(key):
						row[key] = event[key]
				var event_id: String = str(event.get("id", "%s:d%d" % [cost_id, int(event.get("due_day", day))]))
				_append_new(out, add(pack, s, row, "%s:%s" % [period, event_id], "bill:%s:%s" % [cost_id, event_id], world))
			# Event costs with a condition may be emitted by a today's event flag.
			# Social costs exclusively follow actual invitations.
			if period == "contract" or matched or cost_id == "social" or not spec.has("when"):
				continue
			var last: int = int(s["cost_last"].get(cost_id, -2147483647))
			if day - last < int(spec.get("cooldown_days", 0)):
				continue
		elif period == "weekly":
			if not C.test({"weekday": int(spec.get("weekday", 0))}, pack, s, world):
				continue
		elif period == "once":
			if s["cost_once"].has(cost_id):
				continue
		elif period != "daily" and period != "monthly":
			continue
		var row: Dictionary = spec.duplicate(true)
		var due: int = day + int(spec.get("due_days", 0))
		if period == "monthly":
			var month_days: int = maxi(1, int(pack.get("balance", {}).get("costs", {}).get("month_days", pack.get("time", {}).get("season_days", 28))))
			var month_day: int = clampi(int(spec.get("due_day", month_days)), 1, month_days)
			due = int(floor(float(maxi(0, day - 1)) / float(month_days))) * month_days + month_day
			if due < day:
				due += month_days
			if day < due - int(spec.get("announce_days", 0)):
				continue
		row["due_day"] = due
		var id: String = "bill:%s:%s" % [cost_id, "once" if period == "once" else "d%d" % due]
		var bill: Dictionary = add(pack, s, row, "living_cost:%s" % cost_id, id, world)
		_append_new(out, bill)
		if not bill.is_empty():
			s["cost_last"][cost_id] = day
			if period == "once":
				s["cost_once"][cost_id] = id
	return out

# Used by event/institution effects too, so every obligation shares the same
# persistent schema and semantic deduplication. Empty means already announced.
static func add(pack: Dictionary, s: Dictionary, spec: Dictionary, source: String, bill_id: String, world = null) -> Dictionary:
	_ensure(s)
	for existing in s["bills"]:
		if str(existing.get("id", "")) == bill_id:
			return {}
	var day: int = int(s.get("day", 0))
	var cost_id: String = str(spec.get("id", bill_id))
	var expected: float = float(spec.get("base", spec.get("amount", spec.get("min", 0))))
	var scale: String = str(spec.get("scale", ""))
	if not scale.is_empty():
		expected *= float(s.get("pressures", {}).get(scale, 1.0))
	var seasonal: Array = spec.get("season_mult", [])
	if not seasonal.is_empty():
		var days: int = maxi(1, int(pack.get("time", {}).get("season_days", 28)))
		var season: int = posmod(int(floor(float(day) / float(days))), seasonal.size())
		expected *= float(seasonal[season])
	var weather_mult: Dictionary = spec.get("weather_mult", {})
	expected *= float(weather_mult.get(str(s.get("weather", "")), 1.0))
	var difficulty = s.get("difficulty", "常年")
	var setting: Dictionary = difficulty if difficulty is Dictionary else pack.get("difficulty", {}).get(str(difficulty), {})
	expected *= float(setting.get("cost_mult", 1.0))
	var jitter: float = maxf(0.0, float(spec.get("jitter", 0.0)))
	var low: int = maxi(0, int(spec.get("min", round(expected * maxf(0.0, 1.0 - jitter)))))
	var high: int = maxi(low, int(spec.get("max", round(expected * (1.0 + jitter)))))
	var amount: int
	if spec.has("amount"):
		amount = clampi(int(spec["amount"]), low, high)
	elif not spec.has("base") and spec.has("min") and spec.has("max"):
		amount = low + int(floor(R.draw(int(s.get("seed", 0)), "bill:" + source, [bill_id]) * float(high - low + 1)))
	else:
		var noise: float = R.draw(int(s.get("seed", 0)), "cost:" + cost_id, [bill_id, 0]) + R.draw(int(s.get("seed", 0)), "cost:" + cost_id, [bill_id, 1]) - 1.0
		amount = clampi(int(round(expected * (1.0 + jitter * noise))), low, high)
	if amount <= 0:
		return {}
	var date: String = "第%d日" % day
	if world != null and world is Object and world.has_method("date_text"):
		date = str(world.call("date_text", day))
	var costs: Dictionary = pack.get("balance", {}).get("costs", {})
	var bill: Dictionary = {"id": bill_id, "cost_id": cost_id, "label": str(spec.get("label", cost_id)), "amount": amount,
		"payee": str(spec.get("payee", "")), "building": str(spec.get("building", "")),
		"due_day": int(spec.get("due_day", day + int(spec.get("due_days", 0)))), "status": "due", "paid": 0,
		"source": source, "date": date, "created_day": day, "min": low, "max": high, "range": [low, high],
		"grace_days": maxi(0, int(spec.get("grace_days", costs.get("default_grace_days", 0)))),
		"late_effects": spec.get("late_effects", []).duplicate(true), "late_applied": {}, "overdue_notified": false}
	s["bills"].append(bill)
	return bill

# Return visible notices plus declared effects for TownSim's effect coordinator.
# Never repay obligations or apply random hidden debits at night.
static func end_day(pack: Dictionary, s: Dictionary, world = null) -> Array:
	_ensure(s)
	var out: Array = []
	var day: int = int(s.get("day", 0))
	for bill in s["bills"]:
		if str(bill.get("status", "due")) in ["paid", "waived"]:
			continue
		if int(bill.get("paid", 0)) >= int(bill.get("amount", 0)):
			bill["status"] = "paid"
			continue
		var late_days: int = day - int(bill.get("due_day", day))
		if late_days <= 0:
			continue
		bill["status"] = "overdue"
		if not bool(bill.get("overdue_notified", false)):
			bill["overdue_notified"] = true
			out.append({"bill_id": bill["id"], "source": bill["source"], "date": bill["date"],
				"text": "%s尚未付清，还可向%s商量宽限。" % [bill["label"], bill["payee"]], "effects": []})
		var grace: int = maxi(0, int(bill.get("grace_days", pack.get("balance", {}).get("costs", {}).get("default_grace_days", 0))))
		if late_days <= grace:
			continue
		if not bill.has("late_applied"):
			bill["late_applied"] = {}
		var effects: Array = bill.get("late_effects", [])
		for i in range(effects.size()):
			var stage: Dictionary = effects[i]
			var marker: String = str(i)
			if bill["late_applied"].has(marker) or late_days < maxi(grace + 1, int(stage.get("after_days", grace + 1))):
				continue
			if not C.test(stage.get("when", {}), pack, s, world):
				continue
			bill["late_applied"][marker] = day
			var effect: Dictionary = stage.duplicate(true)
			for key in ["after_days", "text", "when"]:
				effect.erase(key)
			out.append({"bill_id": bill["id"], "source": "overdue:" + str(bill["id"]), "date": "第%d日" % day,
				"text": str(stage.get("text", "%s拖欠已过宽限，掌柜需尽早安排。" % bill["label"])), "effects": [effect]})
	return out

static func _ensure(s: Dictionary) -> void:
	for key in ["cost_once", "cost_last"]:
		if not s.has(key):
			s[key] = {}
	if not s.has("bills"):
		s["bills"] = []

static func _append_new(out: Array, bill: Dictionary) -> void:
	if not bill.is_empty():
		out.append(bill)
