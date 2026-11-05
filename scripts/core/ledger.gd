# 客观账本：钱、物、合同（GameJev 07_PLANNED_SPECS: MoneyLedger / PawnContract / Debt / Guarantee / Pledge）
# 不变量：所有账户的蚨总量守恒（钱只会在账户间转移，账本永远不凭空造钱）；
#        每件物品同一时刻只在一个位置；同一物品不能两次出质；同一 request_id 不重复入账。
extends RefCounted

var accounts: Dictionary = {}       # 账户名 -> 整数蚨
var journal: Array = []             # 分录
var items: Dictionary = {}          # 物品ID -> 物品
var contracts: Dictionary = {}      # 当号 -> 活当合同
var debts: Dictionary = {}          # 债务ID -> 借据/借条
var seen_requests: Dictionary = {}  # 去重
var foreign_tickets: Array = []      # 外来当票（如“德字第一九六号”）：只记录，不动钱
var initial_total: int = 0
var next_ticket: int = 1
var next_item: int = 1
var next_journal: int = 1

func open_account(name: String, amount: int) -> void:
	accounts[name] = accounts.get(name, 0) + amount
	initial_total += amount

func balance(name: String) -> int:
	return int(accounts.get(name, 0))

func total() -> int:
	var t := 0
	for k in accounts:
		t += int(accounts[k])
	return t

# 资金转移。余额不足返回空串（不透支、不造钱）。request_id 相同则不重复执行。
func transfer(from: String, to: String, amount: int, reason: String, ref: String = "", request_id: String = "") -> String:
	if amount <= 0:
		return ""
	if request_id != "" and seen_requests.has(request_id):
		return seen_requests[request_id]
	if not accounts.has(from) or not accounts.has(to):
		push_error("未知账户 %s -> %s" % [from, to])
		return ""
	if int(accounts[from]) < amount:
		return ""
	accounts[from] = int(accounts[from]) - amount
	accounts[to] = int(accounts[to]) + amount
	var jid := "J%04d" % next_journal
	next_journal += 1
	journal.append({"id": jid, "from": from, "to": to, "amount": amount, "reason": reason, "ref": ref})
	if request_id != "":
		seen_requests[request_id] = jid
	return jid

# ---------- 物品 ----------
func add_item(def: Dictionary, owner: String, location: String) -> String:
	var id := "I%03d" % next_item
	next_item += 1
	var it := def.duplicate(true)
	it["id"] = id
	it["owner"] = owner
	it["location"] = location
	it["pledged_to"] = ""
	it["history"] = [ "来自%s" % owner ]   # 物件人生（GameJev EXT05）
	items[id] = it
	return id

func move_item(id: String, location: String, new_owner: String = "", note: String = "") -> void:
	var it: Dictionary = items[id]
	it["location"] = location
	if new_owner != "":
		it["owner"] = new_owner
	if note != "":
		it["history"].append(note)

func items_at(location: String) -> Array:
	var out: Array = []
	for id in items:
		if items[id]["location"] == location:
			out.append(id)
	return out

func find_item(def_id: String, location: String = "") -> String:
	var ids := items.keys()
	ids.sort()
	for id in ids:
		var it: Dictionary = items[id]
		if it.get("def_id", "") == def_id and (location == "" or it["location"] == location):
			return id
	return ""

# 某天的收支（日结用）：只看 player 账户进出；满当入库那种不动钱的分录（amount 0）不算收支
func day_flows(from_index: int) -> Dictionary:
	var inc := 0
	var out := 0
	var rows: Array = []
	for i in range(from_index, journal.size()):
		var j: Dictionary = journal[i]
		if int(j["amount"]) <= 0:
			continue
		if j["to"] == "player":
			inc += int(j["amount"])
			rows.append(["收", int(j["amount"]), j["reason"]])
		elif j["from"] == "player":
			out += int(j["amount"])
			rows.append(["付", int(j["amount"]), j["reason"]])
	return {"income": inc, "expense": out, "rows": rows}

# ---------- 活当合同（PawnContract） ----------
# 默认当期 30 天、宽限 5 天、月息三分；计息按 30 天一月，不足一月按一月计。
const DEFAULT_PAWN_TERM_DAYS := 30
const DEFAULT_PAWN_GRACE_DAYS := 5
const DEFAULT_PAWN_RATE_MONTH := 0.03
const PAWN_STATUS_TEXT := {
	"active": "活当期内",
	"overdue": "已到期可协商",
	"forfeited": "已满当",
	"redeemed": "已赎回",
	"compensated": "已赔偿结清",
}

# 当铺放款：钱从钱匣到当户；物品进典当盒，所有权仍是当户的，铺子只有保管权。
# 签名须与卡牌版 card_ledger.gd 的覆盖一致（子类不能少参数），宽限与月息取默认值记在合同上。
func open_pawn(borrower: String, item_ids: Array, principal: int, day: int, term_days: int, condition_text: String, ticket_old: bool) -> String:
	for iid in item_ids:
		if items[iid]["pledged_to"] != "":
			return ""   # 不能重复出质
	var jid := ""
	if principal > 0:
		jid = transfer("player", borrower, principal, "活当放款", "", "pawn|%s|%s" % [borrower, ",".join(item_ids)])
		if jid == "":
			return ""
	var tid := "德字第%s号" % _cn_num(next_ticket)
	next_ticket += 1
	contracts[tid] = {"id": tid, "borrower": borrower, "item_ids": item_ids.duplicate(), "principal": principal,
		"rate_month": DEFAULT_PAWN_RATE_MONTH, "signed_day": day, "start_day": day, "term_days": term_days,
		"due_day": day + term_days, "grace_days": DEFAULT_PAWN_GRACE_DAYS, "status": "active",
		"condition": condition_text, "ticket_old": ticket_old,
		"unauthorized_disposal": false, "renewals": [], "journal": [jid] if jid != "" else []}
	for iid in item_ids:
		items[iid]["pledged_to"] = tid
		move_item(iid, "pawnbox", "", "当入德厚当（%s）" % tid)
	return tid

# 当票状态代码：active（活当期内）/ overdue（已到期可协商）/ forfeited（已满当）/ redeemed（已赎回），其它结清状态原样返回。
# 传入世界日期时，仍在当的合同过了到期日即算“已到期可协商”；满当只认 tick_contracts 实际执行的结果——
# 小镇在日终结账时才满当，宽限最后一天当户仍能来赎，账簿不能提前写成“已满当”。
func contract_status(tid: String, day: int = -1) -> String:
	if not contracts.has(tid):
		return ""
	var c: Dictionary = contracts[tid]
	var cur := str(c.get("status", "active"))
	if day < 0 or not cur in ["active", "overdue"]:
		return cur
	return "overdue" if day > int(c["due_day"]) else "active"

# 当票中文状态（活当期内 / 已到期可协商 / 已满当 / 已赎回）
func contract_status_text(tid: String, day: int = -1) -> String:
	var st := contract_status(tid, day)
	return str(PAWN_STATUS_TEXT.get(st, st))

# 按日期推算：到期日当天及以前为活当；过到期日、未过宽限为已到期可协商；过宽限为满当。
# grace < 0 时用合同自己的宽限天数（旧存档没有这一栏，按默认 5 天）。
func _status_by_date(c: Dictionary, day: int, grace: int) -> String:
	var due := int(c["due_day"])
	var g := grace if grace >= 0 else int(c.get("grace_days", DEFAULT_PAWN_GRACE_DAYS))
	if day <= due:
		return "active"
	if day <= due + g:
		return "overdue"
	return "forfeited"

# 计息月数：按 30 天为一月，不足一月按一月计（向上取整，最少 1 个月）
func redeem_months(tid: String, day: int) -> int:
	var c: Dictionary = contracts[tid]
	var elapsed := maxi(0, day - int(c["signed_day"]))
	return maxi(1, int(ceil(float(elapsed) / float(DEFAULT_PAWN_TERM_DAYS))))

# 赎当利息：当本 × 月息 × 计息月数（四舍五入为整数蚨）
func redeem_interest(tid: String, day: int) -> int:
	var c: Dictionary = contracts[tid]
	var months := redeem_months(tid, day)
	return int(round(float(c["principal"]) * float(c.get("rate_month", DEFAULT_PAWN_RATE_MONTH)) * months))

# 赎回金额 = 当本 + 利息
func redeem_amount(tid: String, day: int) -> int:
	var c: Dictionary = contracts[tid]
	return int(c["principal"]) + redeem_interest(tid, day)

# 同一天同一当号只续一次；付款成功才延长，原物处置义务始终保留。
func renew(tid: String, day: int, fee: int) -> bool:
	if not contracts.has(tid) or fee < 0:
		return false
	var c: Dictionary = contracts[tid]
	if not str(c["status"]) in ["active", "overdue"]:
		return false
	for row in c["renewals"]:
		if int(row["day"]) == day:
			return int(row["fee"]) == fee
	var jid := ""
	if fee > 0:
		jid = transfer(str(c["borrower"]), "player", fee, "续当息", tid, "renew|%s|%d" % [tid, day])
		if jid == "":
			return false
	var term := int(c.get("term_days", int(c["due_day"]) - int(c["signed_day"])))
	c["term_days"] = maxi(1, term)
	c["due_day"] = maxi(day, int(c["due_day"])) + int(c["term_days"])
	c["status"] = "active"
	c["renewals"].append({"day": day, "fee": fee, "due_day": c["due_day"], "journal": jid})
	if jid != "":
		c["journal"].append(jid)
	return true

func to_dict() -> Dictionary:
	return {"accounts": accounts.duplicate(true), "journal": journal.duplicate(true),
		"items": items.duplicate(true), "contracts": contracts.duplicate(true), "debts": debts.duplicate(true),
		"seen_requests": seen_requests.duplicate(true), "foreign_tickets": foreign_tickets.duplicate(true),
		"initial_total": initial_total, "next_ticket": next_ticket, "next_item": next_item, "next_journal": next_journal}

func from_dict(d: Dictionary) -> void:
	d = _restore_numbers(d)
	accounts = d.get("accounts", {}).duplicate(true)
	journal = d.get("journal", []).duplicate(true)
	items = d.get("items", {}).duplicate(true)
	contracts = d.get("contracts", {}).duplicate(true)
	debts = d.get("debts", {}).duplicate(true)
	seen_requests = d.get("seen_requests", {}).duplicate(true)
	foreign_tickets = d.get("foreign_tickets", []).duplicate(true)
	initial_total = int(d.get("initial_total", 0))
	next_ticket = int(d.get("next_ticket", 1))
	next_item = int(d.get("next_item", 1))
	next_journal = int(d.get("next_journal", 1))

static func _restore_numbers(value):
	if value is Dictionary:
		var restored := {}
		for key in value:
			restored[key] = _restore_numbers(value[key])
		return restored
	if value is Array:
		var restored: Array = []
		for entry in value:
			restored.append(_restore_numbers(entry))
		return restored
	if value is float and is_finite(value) and value == floor(value) and absf(value) < 9.0e15:
		return int(value)
	return value

# 满当：在库原物归铺子、进库房可卖；已售出/被扣存的原物不能凭空回到货架，提前处置记录仍留在合同。
# 满当另记一笔不动钱的分录（amount 为 0，蚨总量不变）。
func _forfeit_contract(tid: String, day: int) -> void:
	var c: Dictionary = contracts[tid]
	if c["status"] == "forfeited":
		return
	c["status"] = "forfeited"
	c["forfeited_day"] = day
	var stocked: Array = []
	for iid in c["item_ids"]:
		items[iid]["pledged_to"] = ""
		if items[iid]["location"] == "pawnbox":
			move_item(iid, "stock", "player", "满当，归德厚当")   # 在库原物满当，进货架可卖
			stocked.append(str(items[iid].get("name", iid)))
		else:
			items[iid]["history"].append("当期及宽限已过，原物不在库；原处置记录保留")
	var jid := "J%04d" % next_journal
	next_journal += 1
	var reason: String = ("满当入库：%s" % "、".join(stocked)) if not stocked.is_empty() else "满当：原物不在库"
	journal.append({"id": jid, "from": c["borrower"], "to": "player", "amount": 0, "principal": int(c["principal"]),
		"reason": reason, "ref": tid, "day": day})
	c["journal"].append(jid)

# 赎当：收款与返物要么一起成功要么一起失败（失败时无移库、记账或状态改写）。
# 能不能赎以合同实际状态为准：满当由 tick_contracts 执行；小镇补还原物时会把满当合同改回 overdue 再赎。
func redeem(tid: String, day: int) -> bool:
	if not contracts.has(tid):
		return false
	var c: Dictionary = contracts[tid]
	if c["status"] != "active" and c["status"] != "overdue":
		return false
	for iid in c["item_ids"]:
		if items[iid]["location"] != "pawnbox":
			return false   # 原物不在（被提前处置），不能装作正常赎回
	var amt := redeem_amount(tid, day)
	var jid := transfer(c["borrower"], "player", amt, "赎当", tid, "redeem|" + tid)
	if jid == "":
		return false
	for iid in c["item_ids"]:
		items[iid]["pledged_to"] = ""
		move_item(iid, "npc:" + c["borrower"], "", "赎回")
	c["status"] = "redeemed"
	c["redeemed_day"] = day
	c["redeemed_amount"] = amt
	c["redeemed_interest"] = amt - int(c["principal"])   # 按实际收款算，子类覆盖 redeem_amount 时也对得上
	c["redeemed_months"] = redeem_months(tid, day)
	c["journal"].append(jid)
	return true

# 到期转“已到期可协商”，过宽限转满当（死当）；按日期推算，隔几天才结账也一次到位。未到条件不能当作自有旧货。
func tick_contracts(day: int, grace: int = -1) -> Array:
	var changed: Array = []
	for tid in contracts:
		var c: Dictionary = contracts[tid]
		var prev := str(c["status"])
		if not prev in ["active", "overdue"]:
			continue
		var next_st := _status_by_date(c, day, grace)
		if next_st == "forfeited":
			_forfeit_contract(tid, day)
			changed.append(tid)
		elif next_st == "overdue" and prev == "active":
			c["status"] = "overdue"
			changed.append(tid)
	return changed

func _is_fake_collateral_item(iid: String) -> bool:
	if items.has(iid) and items[iid].get("fake", false):
		return true
	for tid in contracts:
		var c: Dictionary = contracts[tid]
		if c.get("fake_collateral", false) and c.get("item_ids", []).has(iid):
			return true
	return false

# 转卖库房物品（含满当入库后的当物）：仅 location=="stock" 且未出质的当铺自有物可售，伪契不可卖，buyer 不可为 player，记一笔账
func sell_stock_item(iid: String, buyer: String, price: int) -> String:
	if not items.has(iid) or price <= 0 or buyer == "" or buyer == "player":
		return ""
	var it: Dictionary = items[iid]
	if it.get("location", "") != "stock" or it.get("owner", "") != "player" or it.get("pledged_to", "") != "":
		return ""
	if _is_fake_collateral_item(iid):
		return ""
	var jid := transfer(buyer, "player", price, "转卖：%s" % str(it.get("name", iid)), iid, "sell_stock|%s|%d" % [iid, journal.size()])
	if jid == "":
		return ""
	move_item(iid, "npc:" + buyer, buyer, "转卖给%s（%d 蚨）" % [buyer, price])
	return jid

# ---------- 借据 / 借条（Debt）与担保（Guarantee） ----------
func open_debt(kind: String, debtor: String, creditor: String, principal: int, day: int, due_day: int, cash_moves: bool, note: String) -> String:
	var did := "D%02d" % (debts.size() + 1)
	var jid := ""
	if cash_moves:
		jid = transfer(creditor, debtor, principal, "借出", did, "debt|" + did)
		if jid == "":
			return ""
	debts[did] = {"id": did, "kind": kind, "debtor": debtor, "creditor": creditor, "principal": principal, "outstanding": principal,
		"signed_day": day, "due_day": due_day, "status": "active", "payments": [], "guarantee": {}, "note": note, "dispute": false}
	return did

# 还款：能力（现金）与意愿分开——这里只执行，意愿由 NPC 大脑决定；现金不足时最多付出手头的
func pay_debt(did: String, amount: int, payer: String = "") -> int:
	var d: Dictionary = debts[did]
	if d["status"] == "settled":
		return 0
	if payer == "":
		payer = d["debtor"]
	var amt := mini(amount, int(d["outstanding"]))
	amt = mini(amt, balance(payer))
	if amt <= 0:
		return 0
	var jid := transfer(payer, d["creditor"], amt, "还款" if payer == d["debtor"] else "担保代偿", did)
	if jid == "":
		return 0
	d["outstanding"] = int(d["outstanding"]) - amt
	d["payments"].append({"payer": payer, "amount": amt, "journal": jid})
	if int(d["outstanding"]) <= 0:
		d["status"] = "settled"
	return amt

func set_guarantee(did: String, guarantor: String, limit: int) -> void:
	debts[did]["guarantee"] = {"guarantor": guarantor, "limit": limit, "paid": 0}

# 担保代偿：不超过担保上限；代偿后原债权相应减少（不会重复收钱），担保人对债务人取得追偿权
func call_guarantee(did: String) -> int:
	var d: Dictionary = debts[did]
	var g: Dictionary = d["guarantee"]
	if g.is_empty():
		return 0
	var room := int(g["limit"]) - int(g["paid"])
	var paid := pay_debt(did, mini(room, int(d["outstanding"])), g["guarantor"])
	g["paid"] = int(g["paid"]) + paid
	if paid > 0:
		open_debt("recourse", d["debtor"], g["guarantor"], paid, 0, 0, false, "代偿后追偿（%s）" % did)
	return paid

func tick_debts(day: int) -> void:
	for did in debts:
		var d: Dictionary = debts[did]
		if d["status"] == "active" and int(d["due_day"]) > 0 and day > int(d["due_day"]):
			d["status"] = "overdue"   # 逾期是状态，不等于人品

# ---------- 校验（冒烟测试用） ----------
func check_invariants() -> Array:
	var errs: Array = []
	if total() != initial_total:
		errs.append("蚨总量不守恒：%d != %d" % [total(), initial_total])
	for k in accounts:
		if int(accounts[k]) < 0:
			errs.append("账户为负：%s" % k)
	var pledged := {}
	for tid in contracts:
		var c: Dictionary = contracts[tid]
		if c["status"] in ["active", "overdue"]:
			for iid in c["item_ids"]:
				if pledged.has(iid):
					errs.append("物品重复出质：%s" % iid)
				pledged[iid] = tid
	for did in debts:
		var d: Dictionary = debts[did]
		var paid := 0
		for p in d["payments"]:
			paid += int(p["amount"])
		if paid + int(d["outstanding"]) != int(d["principal"]):
			errs.append("债务 %s 未结与已还不平" % did)
	return errs

static func _cn_num(n: int) -> String:
	var digits := ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
	var s := ""
	for ch in str(n):
		s += digits[int(ch)]
	return s
