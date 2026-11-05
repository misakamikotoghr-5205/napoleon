extends SceneTree
## Reproducible economic policy experiment; all transactions use real TownSim
## cash accounts and generated sessions. No wage, replenishment, or fake sales.
## godot --headless --path . --script res://scripts/tests/balance_sim.gd -- --quick
## Default: 3 difficulties x 200 paired seeds x 3 strategies x 30 days.

const Sim = preload("res://scripts/sim/town_sim.gd")
const Pack = preload("res://scripts/sim/town_pack.gd")
const R = preload("res://scripts/sim/jev_rng.gd")
const DIFFICULTIES = ["太平年", "常年", "乱世"]
const STRATEGIES = ["fair", "greedy", "counter_only"]
const DAYS = 30
var errors: Array = []
var runs: Array = []
var seed_count = 200
var report_path = "res://docs/town/balance_report.md"
var json_path = ""
var report_explicit = false
var difficulty_filter = ""
var from_json = ""
var source_hashes: Dictionary = {}
var evidence_hash = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--quick": seed_count = 10
		elif arg.begins_with("--seeds="): seed_count = maxi(1, int(arg.trim_prefix("--seeds=")))
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
			report_explicit = true
		elif arg.begins_with("--json="): json_path = arg.trim_prefix("--json=")
		elif arg.begins_with("--difficulty="): difficulty_filter = arg.trim_prefix("--difficulty=")
		elif arg.begins_with("--from-json="): from_json = arg.trim_prefix("--from-json=")
	if from_json != "":
		_render_archive()
		return
	if difficulty_filter != "" and not DIFFICULTIES.has(difficulty_filter):
		printerr("Unknown difficulty: ", difficulty_filter)
		quit(1)
		return
	if seed_count < 200 and not report_explicit: report_path = "/tmp/dehoudang_balance_smoke.md"
	if seed_count >= 200 and json_path == "": json_path = "/tmp/dehoudang_balance_full.json"
	var input_pack_hash = FileAccess.get_file_as_string("res://data/town/town_pack.json").sha256_text()
	var loaded: Dictionary = Pack.load_pack()
	if loaded.is_empty():
		printerr("Balance pack failed validation")
		quit(1)
		return
	source_hashes["scripts/tests/balance_sim.gd"] = FileAccess.get_file_as_string("res://scripts/tests/balance_sim.gd").sha256_text()
	source_hashes["scripts/core/mind.gd"] = FileAccess.get_file_as_string("res://scripts/core/mind.gd").sha256_text()
	source_hashes["data/town/item_templates.json"] = FileAccess.get_file_as_string("res://data/town/item_templates.json").sha256_text()
	for name in DirAccess.get_files_at("res://scripts/sim"):
		if name.ends_with(".gd"):
			var path = "scripts/sim/" + name
			source_hashes[path] = FileAccess.get_file_as_string("res://" + path).sha256_text()
	for difficulty in DIFFICULTIES:
		if difficulty_filter != "" and difficulty != difficulty_filter: continue
		for index in range(seed_count):
			var exogenous: Array = []
			for strategy in STRATEGIES:
				var result = _run(loaded, difficulty, strategy, 19380000 + index)
				if strategy == "fair": exogenous = result["exogenous"]
				elif result["exogenous"] != exogenous: errors.append("Exogenous divergence %s seed %d %s" % [difficulty, index, strategy])
				runs.append(result)
			if (index + 1) % 25 == 0: print("BALANCE progress ", difficulty, " ", index + 1, "/", seed_count)
		print("BALANCE ", difficulty, " complete")
	var pack_hash = input_pack_hash
	if FileAccess.get_file_as_string("res://data/town/town_pack.json").sha256_text() != pack_hash:
		errors.append("Town pack changed during experiment; this evidence is invalid")
	if json_path != "":
		var output = FileAccess.open(json_path, FileAccess.WRITE)
		if output == null:
			printerr("Cannot write balance evidence: ", json_path)
			quit(1)
			return
		var payload = JSON.stringify({"pack_hash": pack_hash, "seeds": seed_count, "runs": runs, "errors": errors, "source_hashes": source_hashes})
		output.store_string(payload)
		evidence_hash = payload.sha256_text()
	var report = _report(pack_hash)
	var file = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write balance report: ", report_path)
		quit(1)
		return
	file.store_string(report)
	print("BALANCE games=", runs.size(), " days=", runs.size() * DAYS, " failures=", errors.size(), " report=", report_path)
	for message in errors.slice(0, 10): printerr(message)
	quit(0 if errors.is_empty() else 1)

func _render_archive() -> void:
	# Report edits can reuse evidence without silently rerunning a new policy.
	var payload = FileAccess.get_file_as_string(from_json)
	var archived = JSON.parse_string(payload)
	evidence_hash = payload.sha256_text()
	var pack_hash = FileAccess.get_file_as_string("res://data/town/town_pack.json").sha256_text()
	if not archived is Dictionary or archived.get("pack_hash", "") != pack_hash:
		printerr("Archive missing or pack hash differs: ", from_json)
		quit(1)
		return
	seed_count = int(archived.get("seeds", 0))
	runs = archived.get("runs", [])
	errors = archived.get("errors", [])
	source_hashes = archived.get("source_hashes", {})
	if seed_count < 1 or runs.is_empty():
		printerr("Archive contains no completed sample")
		quit(1)
		return
	if seed_count < 200 and not report_explicit: report_path = "/tmp/dehoudang_balance_smoke.md"
	var file = FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write archived balance report: ", report_path)
		quit(1)
		return
	file.store_string(_report(pack_hash))
	print("BALANCE archived games=", runs.size(), " failures=", errors.size(), " report=", report_path)
	quit(0 if errors.is_empty() else 1)

func _run(base: Dictionary, difficulty: String, strategy: String, seed: int) -> Dictionary:
	var pack = base.duplicate(true)
	pack["default_difficulty"] = difficulty
	var sim = Sim.new(pack, seed)
	var initial_cash = int(sim.s["cash"]["player"])
	var result = {"difficulty": difficulty, "strategy": strategy, "seed": seed, "initial_cash": initial_cash,
		"cash": [], "costs": [], "weekly_costs": [], "tight": 0, "hunger_days": 0, "debt_days": 0,
		"ill_days": 0, "survived": true, "heat_crossed": false, "max_heat": 0.0,
		"police_day": 0, "rare_first": 0, "rare_days": [], "rare_items": 0, "koubei": 50,
		"trade_profit": 0, "stolen_deals": 0, "witnessed_stolen": 0, "deals": {"buy": 0, "pawn": 0, "sell": 0, "redeem": 0}, "exogenous": []}
	var basis: Dictionary = {}
	var counted_items: Dictionary = {}
	var hunger_streak = 0
	for day in range(1, DAYS + 1):
		sim.start_day()
		var exo = {"weather": sim.s["weather"], "rice": sim.s["pressures"]["rice_price"], "med": sim.s["pressures"]["med_price"], "rent": sim.s["pressures"]["rent_index"], "wheels": []}
		for row in sim.s["day_report"].get("wheels", []):
			if str(row.get("mode", "")) == "exogenous": exo["wheels"].append(row)
		result["exogenous"].append(exo)
		if result["police_day"] == 0 and bool(sim.s["unlocked"].get("police", false)): result["police_day"] = day
		# Obligations are paid before new lending, and income is never borrowed
		# from hypothetical buyers. Pay again after today's actual transactions.
		_pay_due(sim)
		for visit in sim.visits_today():
			var appointment = int(ceil(float(visit["minute"]) / 15.0)) * 15
			sim.set_minute(appointment)
			if int(sim.s["minute"]) >= int(visit["minute"]) + int(visit["patience_min"]):
				sim.visit_missed(str(visit["id"]))
				continue
			var session: Dictionary = visit.get("session", {})
			for item in ([] if str(visit["intent"]) in ["redeem", "gossip", "inspect"] else session.get("_item_defs", {}).values()):
				var iid = str(item.get("def_id", item.get("id", "")))
				if counted_items.has(iid): continue
				counted_items[iid] = true
				if bool(item.get("rare", false)):
					result["rare_items"] += 1
					if result["rare_first"] == 0: result["rare_first"] = day
					if not result["rare_days"].has(day): result["rare_days"].append(day)
			_trade(sim, visit, strategy, basis, result)
			result["max_heat"] = maxf(result["max_heat"], float(sim.s["pressures"]["heat"]))
			result["heat_crossed"] = result["heat_crossed"] or float(sim.s["pressures"]["heat"]) >= 0.3
		_pay_due(sim)
		# Going out buys no automatic profit. This policy visits the open
		# teahouse for delivered information; the stationary policy does not.
		if strategy != "counter_only":
			for npc in sim.npcs_at("茶馆"): sim.hear(str(npc))
		var summary = sim.end_day()
		var due_cost = 0
		var hungry = false
		var debt = false
		var ill = false
		for bill in sim.s["bills"]:
			if int(bill["due_day"]) == day: due_cost += int(bill["amount"])
			if int(bill["due_day"]) > day or int(bill["paid"]) >= int(bill["amount"]): continue
			debt = true
			if str(bill["cost_id"]) == "food" and int(bill["due_day"]) == day: hungry = true
			if str(bill["cost_id"]) == "medicine" and day > int(bill["due_day"]) + int(bill["grace_days"]): ill = true
		result["costs"].append(due_cost)
		result["cash"].append(int(summary["cash"]))
		var trailing_total = 0
		for cost in result["costs"].slice(maxi(0, day - 7)): trailing_total += int(cost)
		var daily_cost = float(trailing_total) / mini(day, 7)
		if int(summary["cash"]) < 3.0 * daily_cost: result["tight"] += 1
		if hungry: result["hunger_days"] += 1
		if debt: result["debt_days"] += 1
		if ill: result["ill_days"] += 1
		hunger_streak = hunger_streak + 1 if hungry else 0
		if hunger_streak >= 3: result["survived"] = false
		result["max_heat"] = maxf(result["max_heat"], float(sim.s["pressures"]["heat"]))
		result["heat_crossed"] = result["heat_crossed"] or float(sim.s["pressures"]["heat"]) >= 0.3
		var actual_total = 0
		for amount in sim.s["cash"].values():
			if int(amount) < 0: errors.append("Negative cash %s/%s/%d/%d" % [difficulty, strategy, seed, day])
			actual_total += int(amount)
		if actual_total != int(sim.s["initial_total"]): errors.append("Cash conservation %s/%s/%d/%d" % [difficulty, strategy, seed, day])
	for week in range(4):
		var amount = 0
		for cost in result["costs"].slice(week * 7, week * 7 + 7): amount += int(cost)
		result["weekly_costs"].append(amount)
	result["koubei"] = int(sim.s["stats"].get("koubei", 50))
	return result

func _pay_due(sim) -> void:
	var bills: Array = sim.bills()
	bills.sort_custom(func(a, b):
		var rank_a = _bill_rank(a, int(sim.s["day"]))
		var rank_b = _bill_rank(b, int(sim.s["day"]))
		if rank_a != rank_b: return rank_a < rank_b
		if int(a["due_day"]) != int(b["due_day"]): return int(a["due_day"]) < int(b["due_day"])
		return str(a["id"]) < str(b["id"]))
	for bill in bills:
		if int(bill["due_day"]) <= int(sim.s["day"]) and str(bill["status"]) in ["due", "overdue"]:
			sim.pay_bill(str(bill["id"]), int(bill["amount"]) - int(bill["paid"]), "balance:%s:%d:%d" % [bill["id"], sim.s["day"], sim.s["cash_journal"].size()])

func _bill_rank(bill: Dictionary, day: int) -> int:
	if int(bill["due_day"]) == day:
		match str(bill["cost_id"]):
			"food": return 0
			"fuel": return 1
			"medicine": return 2
	return 3 if str(bill["cost_id"]) == "food" else 4

func _trade(sim, visit: Dictionary, strategy: String, basis: Dictionary, result: Dictionary) -> void:
	var session: Dictionary = visit.get("session", {})
	var npc = str(visit["who"])
	var vid = str(visit["id"])
	var outcome = {"accepted": false}
	var greedy = strategy == "greedy"
	var mode = str(session.get("mode", ""))
	var price = 0
	if str(visit["intent"]) in ["gossip", "inspect"]:
		sim.visit_result(vid, outcome)
		return
	if str(visit["intent"]) == "redeem" and sim.s["tickets"].has(npc):
		var ticket: Dictionary = sim.s["tickets"][npc]
		var elapsed = maxi(0, int(sim.s["day"]) - int(ticket["signed_day"]))
		var interest = int(ceil(float(ticket["principal"]) * float(ticket["rate_month"]) * elapsed / 30.0))
		price = int(ticket["principal"]) + interest
		if price <= int(sim.s["cash"].get(npc, 0)):
			outcome = {"accepted": true, "price": price}
			result["deals"]["redeem"] += 1
			result["trade_profit"] += interest
	elif mode == "sell":
		var ids: Array = []
		var cost_basis = 0
		for iid in session.get("stock", []):
			var item: Dictionary = {}
			for candidate in sim.s["stock"]:
				if str(candidate.get("def_id", candidate.get("id", ""))) == str(iid): item = candidate; break
			if item.is_empty(): continue
			var quote: Dictionary = session.get("buyer_prices", {}).get(iid, {})
			if quote.is_empty(): continue
			var amount = int(round(_market_now(sim, item) * (1.02 if greedy else 0.95)))
			# Hidden NPC limit is an acceptance guard, never the player quote.
			if amount > int(quote["max"]): continue
			if price + amount > int(sim.s["cash"].get(npc, 0)): continue
			price += amount
			cost_basis += int(basis.get(iid, item.get("market", 0)))
			ids.append(str(iid))
		if price > 0 and not ids.is_empty():
			outcome = {"accepted": true, "price": price, "stock": ids}
			result["deals"]["sell"] += 1
			result["trade_profit"] += price - cost_basis
	elif mode in ["buy", "pawn"]:
		var items: Array = session.get("_item_defs", {}).values()
		var ethical = not items.is_empty()
		for item in items:
			var observed = _inspect_signals(item)
			if observed["fake"] or (not greedy and observed["stolen"]): ethical = false
		# Pure TownSim has one outstanding ticket per NPC; do not overwrite it.
		if mode == "pawn" and sim.s["tickets"].has(npc): ethical = false
		var lending = 0
		for ticket in sim.s["tickets"].values(): lending += int(ticket["principal"])
		var inspected = 0.0
		for item in items:
			var estimate: Array = _inspect_signals(item)["estimate"]
			inspected += (float(estimate[0]) + float(estimate[1])) / 2.0 * _scale(sim, item)
		price = int(round(inspected * (0.45 if greedy else 0.60)))
		# The policy observes inspection estimates. NPC floor is only a
		# settlement eligibility guard, not an observable or quote input.
		if price < int(session.get("floor", 0)): ethical = false
		var cash = int(sim.s["cash"]["player"])
		# Keep today's still-unpaid obligations. No future oracle is used.
		var reserve = 0
		var daily_essentials = 0
		for bill in sim.s["bills"]:
			if int(bill["due_day"]) == int(sim.s["day"]) and str(bill["cost_id"]) in ["food", "fuel", "medicine"]: daily_essentials += int(bill["amount"])
		reserve += 2 * daily_essentials
		if mode == "pawn" and lending + price > float(result["initial_cash"]) * 0.20: ethical = false
		for bill in sim.s["bills"]:
			if int(bill["due_day"]) <= int(sim.s["day"]): reserve += maxi(0, int(bill["amount"]) - int(bill["paid"]))
		if ethical and price > 0 and price <= cash - reserve:
			outcome = {"accepted": true, "price": price}
			result["deals"][mode] += 1
			for item in items:
				basis[str(item["def_id"])] = price
	if greedy and bool(outcome.get("accepted", false)) and mode in ["buy", "pawn"]:
		for item in session.get("_item_defs", {}).values():
			if bool(item.get("stolen", false)):
				sim.player_act("accept_stolen", {"actor": npc, "building": "pawnshop", "event_id": vid, "item_id": str(item["def_id"])})
				result["stolen_deals"] += 1
				for effect in sim.s.get("norm_results", {}).get(vid, {}).get("effects", []):
					if str(effect.get("op", "")) == "rumor": result["witnessed_stolen"] += 1
	sim.visit_result(vid, outcome)
	if bool(outcome.get("accepted", false)):
		var settled = false
		for actual in sim.s["visits"]:
			if str(actual["id"]) == vid: settled = bool(actual.get("outcome", {}).get("settled", false)); break
		if not settled: errors.append("Unsettled real trade %s" % vid)

func _inspect_signals(item: Dictionary) -> Dictionary:
	var result = {"fake": false, "stolen": false, "estimate": [0, 0]}
	for part in item.get("parts", []):
		if str(part.get("id", "")) == "authenticity":
			result["fake"] = bool(part.get("tell", false))
			result["estimate"] = part.get("est", [0, 0]).duplicate()
		elif str(part.get("id", "")) == "provenance": result["stolen"] = bool(part.get("tell", false))
	return result

func _scale(sim, item: Dictionary) -> float:
	var cfg: Dictionary = sim.pack.get("prices", {}).get(str(item.get("cat", "")), {})
	return float(sim.s["pressures"].get(str(cfg.get("scale", "")), 1.0))

func _market_now(sim, item: Dictionary) -> float:
	return float(item["market"]) * _scale(sim, item)

func _select(difficulty: String, strategy: String) -> Array:
	return runs.filter(func(row): return row["difficulty"] == difficulty and row["strategy"] == strategy)

func _values(rows: Array, key: String) -> Array:
	var values: Array = []
	for row in rows: values.append(float(row[key]))
	return values

func _mean(values: Array) -> float:
	var total = 0.0
	for value in values: total += float(value)
	return total / values.size() if not values.is_empty() else 0.0

func _quantile(values: Array, q: float) -> float:
	if values.is_empty(): return 0.0
	var sorted = values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(ceil(q * sorted.size())) - 1, 0, sorted.size() - 1)])

func _wilson(count: int, n: int) -> String:
	var z = 1.959963984540054
	var p = float(count) / n
	var denom = 1.0 + z * z / n
	var center = (p + z * z / (2.0 * n)) / denom
	var half = z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n)) / denom
	return "%.1f–%.1f%%" % [(center - half) * 100.0, (center + half) * 100.0]

func _rate(count: int, total: int) -> String:
	return "%.1f%% (%s)" % [float(count) / total * 100.0, _wilson(count, total)]

func _report(pack_hash: String) -> String:
	var lines: Array = ["# T07 可复现数值实验", "", "生成日期：2026-10-11；Godot %s；town pack SHA-256 `%s`。" % [Engine.get_version_info()["string"], pack_hash], "",
		"样本：%d 难度 × %d 个配对种子 × 3 策略 × 30 日 = %d 局 / %d 模拟日。种子为 19380000 至 %d。%s" % [int(runs.size() / (seed_count * STRATEGIES.size())), seed_count, runs.size(), runs.size() * DAYS, 19380000 + seed_count - 1, "这是 quick 烟测，不能代替 200 种子全量报告。" if seed_count < 200 else "全量样本。"], "",
		"运行：`Godot_v4.7-stable_linux.x86_64 --headless --path . --script res://scripts/tests/balance_sim.gd -- --json=/tmp/dehoudang_balance.json`。`--quick` 使用 10 种子并默认写 `/tmp/dehoudang_balance_smoke.md`，不会覆盖全量报告；`--seeds=N`、`--report=PATH` 可改样本量/输出；`--from-json=PATH` 仅重渲染同一pack哈希的已归档结果，不重跑策略。", "",
		"## 测量边界与策略", "",
		"本实验调用 T01 的真实 TownSim、来访规划、当物生成、票据、账单与转账接口；开局无库存。T04 整合游戏另有五件开局库存（粳米、籼米、旧报纸、辞源、阿司匹林）、周妈 24 蚨旧当票、家庭米12/柴炭8/灯油8；实物家庭储备能覆盖部分早期账单。此处不把这些资产偷偷加入 T01 基线，故本表不是 T04 整合版存活率。所有买卖资金来自有限的 `s.cash`：陌生人的一次性入场预算来自其真实生成会话，不补充工资、不虚构每日营收、不用零预算买家买货。每日检查非负余额和总现金守恒，三策略同种子的天气、米价、药价与外生轮盘轨迹完全相同。", "",
		"本政策遍历真实生成的全部验货 parts，仅从 authenticity/provenance 的 tell 和验货估值作判断，假设全部线索都检查成功（完美验货近似，未运行真实 Session 技能/情绪博弈）。公道：验货得到估值与真假/来源线索后拒收假货和赃物，按验货估值中点的 60% 收购/放款，按与 World.market_now / T04 货架标价相同的已验货自有库存市价的 95% 售货。贪心：按验货估值的 45% 收购/放款、同一自有库存市价的 102% 售货，也收赃并触发真实规则。顾客隐藏底价/最高价仅用于判断是否接受固定报价，绝不作为玩家报价输入；超出有限余额的买家不能成交。只守柜台：同公道价格，但不向茶馆在场邻居询问已送达的消息。两种出门策略目前只询问消息，没有未实现的外部转售渠道。", "",
		"三策略每 15 分钟接一次柜台批次（来客到达后顺延至下一刻钟），严格在生成的等待耐心内接客；现场见证只来自真实已到达仍在等候的顾客和同行者，过期来访算错过。三策略先保当日饭、燃料和药，再还旧伙食欠款及其他到期账单（不抹旧债、不把还旧账误算为今天有饭），保留当日已公告伙食/燃料/药款两倍的流动资金（仅用当日信息），30 日长当贷款余额上限为开局资金的 20%，再以剩余资金成交，当日收款后再付款；不读取未来价格或天气。不覆盖同一 NPC 的活当票，不出售尚未解除质押的货。赎当仅在生成 redeem 来访、有效票据和有限顾客余额同时满足时发生，收本息后归还物品。", "",
		"**经济生存**定义为 30 日内未连续 3 日当日伙食款欠付；这是明确的流动性指标，不是尚未纳入的 T04 故事/人物健康死亡判定。被标记失败的局仍运行到D30，现金、费用、毛利和风险均对全部局统计，不只取幸存局。断粮日=当日伙食欠付；欠账日=任何已到期款未清；病情风险日=药款超真实宽限未清。初始 `mother_sick=true` 是母亲背景设定，不将它误算为玩家每天生病。口碑为真实 `s.stats.koubei`，不人为按策略增减。", "",
		"吃紧日：夜间现金 < 最近至多 7 日实际到期费用均值 × 3。每周吃紧频次按 30 日计数 × 7/30。周费用按到期日计入第 1–7、8–14、15–21、22–28 日四个完整周（含修缮、维持费、人情、月租）；29–30 日不混成完整周。P90 为 nearest-rank。利润栏只计已实现售货毛利和赎当利息，未扣家用与罚费；不把未售库存/活当本金当收入。全量错误为0才支持所有计入交易确实成交。", "",
		"## 策略结果", "", "|难度|策略|经济存活率（95% Wilson CI）|每周吃紧日|周费用均值 / P90|P90/均值|已实现交易毛利均值|断粮 / 欠账 / 病险日均值|口碑均值|热度≥0.3局比例（95% CI）|警察所D22前开门（95% CI）|", "|---|---|---|---:|---|---:|---:|---|---:|---:|---:|"]
	if not source_hashes.is_empty():
		lines.insert(4, "实际运行脚本 SHA-256 `%s`；归档原始JSON保留源文件指纹。%s" % [source_hashes.get("scripts/tests/balance_sim.gd", "未记录"), "本次只从归档重渲染报告。" if from_json != "" else ""])
	if evidence_hash != "":
		lines.insert(5, "结果JSON `%s`，SHA-256 `%s`；包含逐局30日现金/费用、配对外生轨迹、成交/风险计数和源码指纹。" % [from_json if from_json != "" else json_path, evidence_hash])
	for difficulty in DIFFICULTIES:
		for strategy in STRATEGIES:
			var rows = _select(difficulty, strategy)
			if rows.is_empty(): continue
			var weekly: Array = []
			var alive = 0
			var heat = 0
			var early = 0
			for row in rows:
				weekly.append_array(row["weekly_costs"])
				if row["survived"]: alive += 1
				if row["heat_crossed"]: heat += 1
				if int(row["police_day"]) > 0 and int(row["police_day"]) < 22: early += 1
			var average = _mean(weekly)
			lines.append("|%s|%s|%.1f%% (%s)|%.2f|%.2f / %.0f|%.3f|%.2f|%.2f / %.2f / %.2f|%.1f|%s|%s|" % [difficulty, strategy, float(alive) / rows.size() * 100, _wilson(alive, rows.size()), _mean(_values(rows, "tight")) * 7.0 / DAYS, average, _quantile(weekly, 0.9), _quantile(weekly, 0.9) / average, _mean(_values(rows, "trade_profit")), _mean(_values(rows, "hunger_days")), _mean(_values(rows, "debt_days")), _mean(_values(rows, "ill_days")), _mean(_values(rows, "koubei")), _rate(heat, rows.size()), _rate(early, rows.size())])
	lines.append_array(["", "周费用分布池为每策略 %d 个完整周，同一局的周并非独立，因此未把周数冒充独立生存样本。生存 CI 的独立样本单位是种子/局；本报告分位数为该固定种子样本的描述量，不承诺总体分位数置信区间。三策略使用相同种子，不能视为三倍独立环境样本。" % (seed_count * 4), "", "## 现金曲线（P10 / P50 / P90，蚨）", "", "|难度|策略|D1|D7|D14|D21|D28|D30|", "|---|---|---|---|---|---|---|---|"])
	for difficulty in DIFFICULTIES:
		for strategy in STRATEGIES:
			var rows = _select(difficulty, strategy)
			if rows.is_empty(): continue
			var cells: Array = [difficulty, strategy]
			for day in [1, 7, 14, 21, 28, 30]:
				var values: Array = []
				for row in rows: values.append(row["cash"][day - 1])
				cells.append("%.0f / %.0f / %.0f" % [_quantile(values, 0.1), _quantile(values, 0.5), _quantile(values, 0.9)])
			lines.append("|" + "|".join(cells) + "|")
	lines.append_array(["", "## 稀有当物到达与交易覆盖", "", "稀有到达指当日真实生成的输入当物（包括拒收物），按生成 ID 去重；不是售出或赚到利润。首次到达分位数以30日内至少见过一次稀有物的局为条件样本；未见局的0不参与分位数，单列未见率和直方图。", "", "|难度|策略|已见局首次稀有日 P10 / P50 / P90|30日未见率|每局稀有件均值|买入 / 放款 / 售出 / 赎回笔数均值|", "|---|---|---|---:|---:|---|"])
	for difficulty in DIFFICULTIES:
		for strategy in STRATEGIES:
			var rows = _select(difficulty, strategy)
			if rows.is_empty(): continue
			var first: Array = []
			var missing = 0
			var deal_means: Array = []
			for row in rows:
				if int(row["rare_first"]) > 0: first.append(row["rare_first"])
				else: missing += 1
			for mode in ["buy", "pawn", "sell", "redeem"]:
				var values: Array = []
				for row in rows: values.append(row["deals"][mode])
				deal_means.append("%.2f" % _mean(values))
			lines.append("|%s|%s|%.0f / %.0f / %.0f|%.1f%%|%.2f|%s|" % [difficulty, strategy, _quantile(first, 0.1), _quantile(first, 0.5), _quantile(first, 0.9), float(missing) / rows.size() * 100, _mean(_values(rows, "rare_items")), " / ".join(deal_means)])
	lines.append_array(["", "## 完整逐周费用", "", "|难度|策略|第1周均值/P90|第2周均值/P90|第3周均值/P90|第4周均值/P90|", "|---|---|---|---|---|---|"])
	for difficulty in DIFFICULTIES:
		for strategy in STRATEGIES:
			var rows = _select(difficulty, strategy)
			if rows.is_empty(): continue
			var cells: Array = [difficulty, strategy]
			for week in range(4):
				var values: Array = []
				for row in rows: values.append(row["weekly_costs"][week])
				cells.append("%.2f / %.0f" % [_mean(values), _quantile(values, 0.9)])
			lines.append("|" + "|".join(cells) + "|")
	lines.append_array(["", "## 真实见证与稀有首到直方图", "", "|难度|策略|每局实际收赃 / 产生目击流言的成交数|首次稀有D1–7 / D8–14 / D15–21 / D22–28 / D29–30 / 未见局数|", "|---|---|---|---|"])
	for difficulty in DIFFICULTIES:
		for strategy in STRATEGIES:
			var rows = _select(difficulty, strategy)
			if rows.is_empty(): continue
			var buckets = [0, 0, 0, 0, 0, 0]
			for row in rows:
				var first = int(row["rare_first"])
				var index = 5 if first == 0 else mini(4, int((first - 1) / 7.0))
				buckets[index] += 1
			var counts: Array = []
			for count in buckets: counts.append(str(count))
			lines.append("|%s|%s|%.2f / %.2f|%s|" % [difficulty, strategy, _mean(_values(rows, "stolen_deals")), _mean(_values(rows, "witnessed_stolen")), " / ".join(counts)])
	var current: Dictionary = Pack.load_pack()
	lines.append_array(["", "## 数字调整（相对上游整合755c201未调数值）", "", "|已有字段|上游|本次|作用|", "|---|---:|---:|---|"])
	for difficulty in DIFFICULTIES:
		var original = {"太平年": 360, "常年": 300, "乱世": 260}[difficulty]
		lines.append("|difficulty.%s.initial_cash|%d|%d|增加有限开局周转；不是每日补贴|" % [difficulty, original, int(current["difficulty"][difficulty]["initial_cash"])])
	lines.append("|living_costs.food.jitter|0.15|%s|提高已公告日费用波动；伙食基础价仍为4|" % str(current["living_costs"][0]["jitter"]))
	lines.append("|living_costs.rent.base|30|%s|提前七天公告的月末费用；实际仍受min/max约束|" % str(current["living_costs"][5]["base"]))
	if int(current["living_costs"][5]["max"]) != 36:
		lines.append("|living_costs.rent.max|36|%s|容许已公告月末账单达到调整后的基础费用|" % str(current["living_costs"][5]["max"]))
	lines.append("|communication.relay_probability|0.45|%s|仍沿真实社交边、延迟、衰减与TTL传播|" % str(current["communication"]["relay_probability"]))
	lines.append("|balance.items.stolen_rate|0.07|%s|提高真实来源风险机会|" % str(current["balance"]["items"]["stolen_rate"]))
	lines.append("|visit_config.companion_probability|0.12|%s|增加真实同行来访；见证仍受存在与耐心限制|" % str(current["visit_config"]["companion_probability"]))
	lines.append("|norms.fence_goods.heat|0.25|%s|经真实目击/延迟传播后提高机构重视程度|" % str(current["norms"][0]["heat"]))
	lines.append_array(["", "## 实现限制与回报", "", "T01 的真实生成交易尚不按公道/压价更新口碑，因此本表全部口碑样本均为50；未验证真实T04 Session的口碑目标，不合成口碑变化。真正的人物饥饿、疲劳、病情以及 T04 作者故事后果需要整合版游戏另测。无头政策没有模拟地图行走、完整 Session 耗时和玩家验货失误，仅用刻钟接客窗口处理来访过期，所报告的是明确策略下的经济边界。", "", "生产数据只允许已有数字字段调整。脚本没有添加任何 pack 字段或改写 TownSim。现金守恒/非负/外生独立检查失败数：%d。" % errors.size(), "", "## Python / GDScript 对照", "", "附下列独立审计快照（2026-10-11）。它记录当时的公式模块 SHA-256，不冒称每次经济模拟重跑时也重跑 Python；当前四份源码是否仍匹配快照由脚本检查。", ""])
	var fair_rows = _select("常年", "fair")
	var greedy_rows = _select("常年", "greedy")
	if not fair_rows.is_empty() and not greedy_rows.is_empty():
		var survival = _mean(_values(fair_rows, "survived"))
		var tight = _mean(_values(fair_rows, "tight")) * 7.0 / DAYS
		var weekly: Array = []
		for row in fair_rows: weekly.append_array(row["weekly_costs"])
		var ratio = _quantile(weekly, 0.9) / _mean(weekly)
		var profit_gap = _mean(_values(greedy_rows, "trade_profit")) - _mean(_values(fair_rows, "trade_profit"))
		var heat_gap = _mean(_values(greedy_rows, "heat_crossed")) - _mean(_values(fair_rows, "heat_crossed"))
		lines.append_array(["", "## 常年默认目标判定", "", "|目标|实测|判定|", "|---|---|---|"])
		lines.append("|公道经济存活 ≥90%%|%.1f%%|%s|" % [survival * 100, "达到" if survival >= 0.9 else "未达"])
		lines.append("|公道每周吃紧 ≥1 日|%.2f|%s|" % [tight, "达到" if tight >= 1.0 else "未达"])
		lines.append("|P90 周费用 / 均值 ≤1.6|%.3f|%s|" % [ratio, "达到" if ratio <= 1.6 else "未达"])
		lines.append("|贪心已实现交易毛利更高|差 %.2f 蚨|%s|" % [profit_gap, "达到" if profit_gap > 0 else "未达"])
		lines.append("|贪心越热度线明显更多（预定义差 ≥15 个百分点）|差 %.1f 个百分点|%s|" % [heat_gap * 100, "达到" if heat_gap >= 0.15 else "未达"])
	else:
		lines.append("常年未运行，本次不评价默认难度目标。")
	if pack_hash != "6e5171a6cd54a3b82637135686b85dd2a6cbbe60a6e6fbb5a8c7c9289a19ac68" and not fair_rows.is_empty():
		var current_weekly: Array = []
		for row in fair_rows: current_weekly.append_array(row["weekly_costs"])
		lines.append_array(["", "## 首轮完整样本与本次对照", "",
			"首轮同一200种子的原始结果 `/tmp/dehoudang_balance_full_original.json`，SHA-256 `44c5c26e20d27ddf2878f9b31ed44f3af00dc2f3493b990c6ec09bb571a1983a`；原始运行源码 `/tmp/dehoudang_balance_full_sources`，脚本SHA-256 `e78553a9250f8f71ffd520cf8041c038ad2101bff3353c94a53bbba9e76df7db`。首轮pack SHA-256 `6e5171a6cd54a3b82637135686b85dd2a6cbbe60a6e6fbb5a8c7c9289a19ac68`。",
			"前50/100个种子用于探索候选，最终200种子包含这些样本。下列区间与达标判断描述所列固定种子，不能当作独立留出集验证。报价、验货、支付优先级及资金储备政策与首轮相同。最终输入另外保留上游755c201的社交链接与角色更新，因此首轮与本次差异不能全部归因于十项数字调整。", "",
			"|常年fair|样本局数|经济存活|每周吃紧|周费均值/P90|P90/均值|交易毛利|", "|---|---:|---:|---:|---|---:|---:|",
			"|首轮|200|90.0%|0.868|78.0525 / 105|1.345248|332.655|"])
		lines.append("|本次|%d|%.1f%%|%.6f|%.4f / %.0f|%.6f|%.3f|" % [fair_rows.size(), _mean(_values(fair_rows, "survived")) * 100, _mean(_values(fair_rows, "tight")) * 7.0 / DAYS, _mean(current_weekly), _quantile(current_weekly, 0.9), _quantile(current_weekly, 0.9) / _mean(current_weekly), _mean(_values(fair_rows, "trade_profit"))])
	lines.append_array(["", "上述判定只对明确的 T01 经济政策成立；健康/口碑及 T04 完整地图玩法仍需整合验证。脚本退出码检查现金与外生轨迹等不变量，目标未达会明确留在报告中，不把正常运行冒充平衡达标。", ""])
	if pack_hash == "6ca302edac71c7c4d986309fe8b4d3cfb4239627a8771de8d5a4ec5014957bf0":
		lines.append(BOUNDARY_AUDIT.replace("{BASE_CI}", _wilson(176, 200)).replace("{CAND_CI}", _wilson(168, 200)))
	for path in AUDIT_HASHES:
		var matches = FileAccess.get_file_as_string(path).sha256_text() == AUDIT_HASHES[path]
		lines.append("审计源码 `%s`：%s。" % [path, "当前文件匹配独立核验快照" if matches else "已变更，下面历史审计不能证明当前文件"])
	lines.append(PYTHON_AUDIT)
	return "\n".join(lines)

const BOUNDARY_AUDIT = """## 35日边界诊断：30日达标不等于长期达标

独立审计在上游整合755c201之后另跑常年fair、同一200种子，各35日。两版开局340、伙食jitter0.65、其他政策/数字相同，仅月租base/max从36改为66；临时工程延长窗口，没有改生产脚本的30日默认。基线pack SHA-256为`43daae3da0b2a202473204ab76fd03f4060808649506982dd3b8e0770c3848a8`，候选为本报告当前`6ca302edac71c7c4d986309fe8b4d3cfb4239627a8771de8d5a4ec5014957bf0`。200对35日外生轨迹完全相同、现金D1–27相同，候选每局只在D28多一笔30蚨真实到期费；候选35日的前30日现金、费用、外生与30日候选逐种子完全一致。整合前的87.5%/84.5%是历史输入结果，不作为当前输入证据。

|配对常年fair，200局|D30经济存活|D35经济存活（95% Wilson CI）|5完整周均值/P90|P90/均值|D35现金P10/P50/P90|D31–35断粮/欠账/病险人日|
|---|---:|---|---|---:|---|---|
|匹配基线，租36|91.0%|88.0% ({BASE_CI})|74.937 / 104|1.387832|11 / 111 / 313|58 / 73 / 39|
|最终候选，租66|91.0%|84.0% ({CAND_CI})|80.937 / 134|1.655609|2 / 95 / 285|91 / 118 / 55|

D31–35基线新增6局失败、候选新增14局失败。配对比较中候选独有失败8局，基线独有失败0局：新增月租使35日经济存活率降低4个百分点。D35现金均值143.410→128.545，35日交易毛利394.150→392.210。候选35日存活未达90%，五周费用比也超过1.6；本次30日目标通过不能解释为35日、长期或T04真实健康玩法已经平衡。当天饭优先于D28租费，加上连续3日欠伙食的生存定义，确实会把一部分月末后果推到D31以后，这个风险没有隐去。

五周费用重新从每局35个原始`costs`按D1–7、8–14、15–21、22–28、29–35汇总，共1000个周；候选35日JSON的`weekly_costs`仍只存前四周，因此不能直接拿它充当五周统计。两局各自的周仍相关，独立样本单位是200个配对种子。

证据：基线`/tmp/line13_t07_new755_base340_j65_r36_35_results.json`，SHA-256 `3d06cea9a57a42446ae70c104ef3d9c0d68f28c66afb999c56139afcbf7d3fba`；候选`/tmp/line04_t07_integrated340_j65_r66_35_results.json`，SHA-256 `085164ef6c2b70ea582829c98336e76eef299565d4bd906f9d5bbffddf335635`；独立配对重算`/tmp/line04_t07_integrated340_j65_r66_35_paired.json`，SHA-256 `87a40fe12b6295e470d8577575670bde73c710e1b21485d3330e159b6b97c280`。另一路独立核对`/tmp/line13_t07_new755_matched35_paired_metrics.json`，SHA-256 `099e276f231e3ed8a86c8225e43502bf7ab6b2c33d3118fcdca70610a6a79801`。

复跑保留的隔离工程（脚本SHA分别为`a7495657d9e350fcd1009b2dcd261e606e1861ac96b639986859f6386b3b9d94`、`4505541413161b5373fc0c331f6bdd4c2fd636b67a07ce6bc30e19f641ee51f0`；临时只筛常年fair）：

```sh
Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/line13_t07_new755_base340_j65_r36_35_project_6adjebbx --script res://scripts/tests/balance_sim.gd -- --seeds=200 --report=/tmp/base35.md --json=/tmp/base35.json
Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/line04_t07_integrated340_j65_r66_35__5024opg --script res://scripts/tests/balance_sim.gd -- --seeds=200 --report=/tmp/candidate35.md --json=/tmp/candidate35.json
```

上述`--path`工程的临时源码/manifest保留在`/tmp`。移机复现须隔离复制相同输入/源码，设置`DAYS=35`且只筛常年fair，基线另将rent.base/max还原36；五周统计从`costs`重算。生产脚本没有未实现的`--days=35`参数。
"""

const AUDIT_HASHES = {
	"res://scripts/sim/jev_rng.gd": "09760b7fd54b72dc37f7a63b20a84599641baad65df9a56252be09848e06e1ff",
	"res://scripts/sim/pressure_model.gd": "1c731f4ccef0960ced27d3ef649ac3fc27c7d96523d40f2ee071e4b2ecdfe2e0",
	"res://scripts/sim/world_wheel.gd": "acdbb2af52bda233323b133f4d431194aeb37febdc8b91920244c50496c5819d",
	"res://scripts/sim/town_cond.gd": "8e0578ad11e57adc7d8d59edc6addd230a92d8f77d21f0cf1275ee4a58d4a36f",
}
const PYTHON_AUDIT = """### Independent Python/GDScript reference audit (line 16)

Scope: a read-only, standalone Godot project copied four simulation modules to `/tmp/t07-python-reference.kp1aT5`; no repository files were edited. Runtime: Python 3.12.14 and Godot 4.7.stable.official.5b4e0cb0f. Sample generator seed is `20261011`.

The original GameJev Python archive and `gamejev_living/randomness.py` were not available under `/workspace`. The Python runner explicitly reconstructs the published formula in `docs/town/research/gamejev_code.md` sections 1.1–1.4, 2.2 and 5.4, including the documented town adaptations. Historical vectors obtain their complete seeds from `docs/town/prototype/test.gd` and `scripts/tests/test_sim_rules.gd`. This validates the documented formula and exported historical vectors; it does not claim a direct execution comparison against the unavailable original archive.

Inputs containing non-integer floats are transferred as IEEE-754 little-endian hex and restored before either formula runs. Outputs compare IEEE-754 bytes, avoiding Godot decimal JSON parsing differences. Semantic keys independently undergo a normal Godot JSON stringify/parse round-trip. Totals accumulate in source order; a separate Python 3.12 built-in compensated-sum comparison is retained below.

| Test family | Cases | Fully exact cases |
|---|---:|---:|
| rng | 1000 | 1000 |
| replay | 1000 | 1000 |
| choices | 1000 | 1000 |
| pressure | 200 | 200 |
| wheel | 200 | 200 |
| rng_roundtrip | 1000 | 1000 |

All main comparisons are exact: pressure has 2600/2600 scalar checks and wheel has 7362/7362 scalar checks (including identifiers, cooldown updates, effects and preview purity). Wheel floating fields separately comprise 1,600 raw weights, 1,600 normalized probabilities and 200 draws. Maximum main absolute error is zero. Wheel preview preserves the entire input state, and spin logs, chosen effects and cooldown dates match the Python reference.

RNG cases cover Chinese, emoji, accented text, U+2028/U+2029, quotes, backslashes, common JSON control escapes, negative and large seeds, bools, nested arrays and integer keys. Choice cases include zero weights, `u=0`, `u=0.9`, random draws and the largest double below 1. Pressure cases cover exogenous mean reversion/noise (including difficulty noise 0/.7/1/1.8), endogenous half-life decay, [0,1] clamping, positive/negative influence and repeated daily-cap spending. Wheel cases cover exogenous/endogenous modes; cooldown blocked, exact-boundary and eligible cases; four seasons including zero seasonal weights; building locks; pressure minimum and bias clamps; difficulty tempo 0/.4/1/1.8; and all/any/not, day, weekday, season, weather, flag, stats, pressure, building and NPC relation conditions. Inputs are valid semantic cases; malformed-input rejection is outside this reference audit.

| Historical vector seed | Method/domain | Key | Python and GDScript value | Result |
|---|---|---|---|---|
| `42` | `wheel:climate` | `[1]` | `0.068580277501886444` | exact |
| `42` | `wheel:logistics` | `[3]` | `0.16148672144953713` | exact |
| `19380306` | `wheel:town_weather` | `[12]` | `0.28813905203852808` | exact |
| `19380306` | `message_relay` | `["event:7", "zhouma", "linsao", 1]` | `0.23250702028586301` | exact |
| `19380306` | `visit` | `[3, "xiaoding"]` | `0.99766566318890681` | exact |
| `19380306` | `轮盘:米价` | `[5, "德厚当"]` | `0.95322003511406195` | exact |
| `42` | `replay_draw` | `["A", 0]` | `0.6700750373336426` | exact |
| `19380306` | `replay_draw` | `["德厚当", 9]` | `0.73660400636362544` | exact |

The historical weighted selection `[quiet:8, clear:3, rain:2, gale:.5]` at `u=.9` returns `rain` in both implementations.

Observed wheel coverage:

| Gate/category | Count |
|---|---:|
| mode:exogenous | 100 |
| difficulty:清闲 | 50 |
| season:0 | 66 |
| choice:quiet | 146 |
| cooldown:eligible | 1118 |
| building:pass | 201 |
| when:block | 419 |
| season_weight:positive | 1268 |
| cooldown:block | 282 |
| when:pass | 381 |
| mode:endogenous | 100 |
| difficulty:常年 | 50 |
| building:block | 399 |
| pressure_min:pass | 949 |
| bias:positive | 1333 |
| pressure_min:block | 451 |
| bias:clamped_zero | 67 |
| difficulty:多事 | 50 |
| difficulty:停转 | 50 |
| choice:event | 54 |
| season:1 | 66 |
| season_weight:zero | 132 |
| season:2 | 34 |
| season:3 | 34 |

Comparison boundaries:

- Replacing explicit source-order accumulation with Python 3.12 built-in `sum(float)` changes 68 displayed probabilities across 16/200 wheel cases, with maximum absolute error `2.2204460492503131e-16`. Raw weights, draws and all 200 selected outcomes remain exact. These are compensated-sum rounding differences; the formula reference retains the source-order behavior.
- Godot 4.7 JSON parses `0.9999999999999999` as `1.0` and changes several other input doubles by small amounts. The encoded float input transfer deliberately verifies formulas on identical binary inputs; this observation is not hidden by a tolerance.
- Godot strings replace NUL U+0000 with U+FFFD before canonicalization. `JevRng.canon` matches Python for the other 31 tested U+0001–U+001F controls. Godot's ordinary JSON stringify emits invalid standard JSON for many low controls; U+000B becomes an unsupported `\v` escape and fails Godot's own parse. Production-style Unicode and common escape keys pass all 1,000 round-trips. Details are in `edge.gd` / `edges.json`.

Exact source fingerprints (the standalone copies are byte-identical):

| Source | SHA-256 | Copy equal |
|---|---|---|
| `scripts/sim/jev_rng.gd` | `09760b7fd54b72dc37f7a63b20a84599641baad65df9a56252be09848e06e1ff` | True |
| `scripts/sim/pressure_model.gd` | `1c731f4ccef0960ced27d3ef649ac3fc27c7d96523d40f2ee071e4b2ecdfe2e0` | True |
| `scripts/sim/world_wheel.gd` | `acdbb2af52bda233323b133f4d431194aeb37febdc8b91920244c50496c5819d` | True |
| `scripts/sim/town_cond.gd` | `8e0578ad11e57adc7d8d59edc6addd230a92d8f77d21f0cf1275ee4a58d4a36f` | True |

Artifact fingerprints:

| Standalone artifact | SHA-256 |
|---|---|
| `reference.py` | `5662600632444f161ccb604f02bbfd8f3731fd063a7d66b07f71af9080efd956` |
| `test.gd` | `8b2613afb06df29346e948759c84ae75849ee4c5918c01b0e84a110e9caa1b2f` |
| `inputs.json` | `56193ff970b52e24986a5ce0359eac689dcb617fc2bcc304268dc7aa9ccdd108` |
| `expected.json` | `8fd847f0958c31cadaed37e269f56d9bb8b058ab7e7affd4aa59b0ed2dc9820f` |
| `actual.json` | `1065258ee66ca3c73c2cb4b77a040d2fe6c2115235717e4f1fd844c0b33d486c` |
| `comparison.json` | `09fb8175f5eb618143a3c4df476977f7c08344225dc7fcb97719cf8b7bf43a7f` |
| `comparison_python312_sum.json` | `2d855d44ecd54bea5c3eebf4f5a828beeb3fc5a946b23228296d00e236aba3db` |

Reproduce the main audit with the retained standalone files:

```bash
python3 /tmp/t07-python-reference.kp1aT5/reference.py
/workspace/tools/godot47/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/t07-python-reference.kp1aT5 --script res://test.gd
python3 /tmp/t07-python-reference.kp1aT5/reference.py compare
```

For the documented native-sum rounding comparison, `python3 /tmp/t07-python-reference.kp1aT5/reference.py compare native-sum` intentionally returns exit status 1 with the differing probability bytes. To rerun control/decimal boundaries, use the same Godot command with `--script res://edge.gd`. `/tmp/t07-python-reference.kp1aT5/write_audit.py` regenerates this audit section from the retained outputs and hashes. Raw results are `comparison.json`, `comparison_python312_sum.json`, `godot.log`, `edges.json` and `edge.log`.
"""
