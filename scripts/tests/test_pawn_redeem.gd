# 活当到期与赎回机制测试：
# 1. 当票结构（起当日期 signed_day/start_day、到期日 due_day、月息 rate_month=3%、当期 30 天、宽限期 5 天）
# 2. 状态按世界日期判定：活当期内（day <= due_day）/ 已到期可协商（due_day < day <= due_day + grace）/ 已满当（day > due_day + grace，由 tick_contracts 结账执行）
# 3. 利息与赎回金额计算：月息 3%，不足一月按一月计（向上取整月数，最少 1 个月），赎回付「当本 + 利息」
# 4. 活当期内赎回与逾期宽限期内协商赎回：收款与返物原子执行，当票写“破旧”赎回触发口碑 -3
# 5. 满当（逾期不赎）：物品转入库存（stock）归当铺所有、可转卖，满当入库与转卖均记账且蚨总量守恒
# 6. 账簿面板（book_panel.gd）纯展示：显示每张当票的起当日期、到期日、赎回金额与状态
# godot --headless -s res://scripts/tests/test_pawn_redeem.gd   （失败退出码 1）
extends SceneTree

const World = preload("res://scripts/core/world.gd")
const BookPanel = preload("res://scripts/ui/book_panel.gd")

var errs: Array = []

func _initialize() -> void:
	await _run()

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		errs.append(msg)
		printerr("FAIL: ", msg)

func _def(id: String) -> Dictionary:
	var d: Dictionary = DB.get_db().items[id].duplicate(true)
	d["def_id"] = id
	return d

func _run() -> void:
	_test_ticket_structure_and_interest()
	_test_redeem_active_and_overdue()
	_test_forfeit_to_stock_and_resell()
	await _test_book_panel_display()
	DB.shutdown()
	if errs.is_empty():
		print("PAWN REDEEM OK")
		quit(0)
	else:
		quit(1)

func _test_ticket_structure_and_interest() -> void:
	var w = World.new()
	w.setup(19380306)
	w.day = 2
	var iid: String = w.ledger.add_item(_def("hairpin"), "linsao", "counter")
	var cash_before: int = w.cash()
	var lin_before: int = w.ledger.balance("linsao")
	var tid: String = w.ledger.open_pawn("linsao", [iid], 100, w.day, 30, "足金梅花簪，微磨", false)
	_check(tid == "德字第一号", "当号编号正确: " + tid)
	var c: Dictionary = w.ledger.contracts[tid]
	_check(int(c["signed_day"]) == 2 and int(c["start_day"]) == 2, "起当日期为第 2 天")
	_check(int(c["term_days"]) == 30 and int(c["due_day"]) == 32, "当期 30 天，到期日为第 32 天")
	_check(is_equal_approx(float(c["rate_month"]), 0.03), "月息为 3%")
	_check(w.cash() == cash_before - 100 and w.ledger.balance("linsao") == lin_before + 100, "活当放款 100 蚨资金转移守恒")
	_check(w.ledger.items[iid]["location"] == "pawnbox" and w.ledger.items[iid]["pledged_to"] == tid, "当物入典当盒并标记质押")

	# 状态按世界日期判定
	_check(w.ledger.contract_status(tid, 2) == "active" and w.ledger.contract_status_text(tid, 2) == "活当期内", "第 2 天（起当日）状态：活当期内")
	_check(w.ledger.contract_status(tid, 15) == "active" and w.ledger.contract_status_text(tid, 15) == "活当期内", "第 15 天状态：活当期内")
	_check(w.ledger.contract_status(tid, 32) == "active" and w.ledger.contract_status_text(tid, 32) == "活当期内", "第 32 天（到期日当天）状态：活当期内")
	_check(w.ledger.contract_status(tid, 33) == "overdue" and w.ledger.contract_status_text(tid, 33) == "已到期可协商", "第 33 天（逾期第 1 天）状态：已到期可协商")
	_check(w.ledger.contract_status(tid, 37) == "overdue" and w.ledger.contract_status_text(tid, 37) == "已到期可协商", "第 37 天（宽限第 5 天）状态：已到期可协商")
	# 合入 integration 后：满当以 tick_contracts 实际结账为准（小镇在日终结账，宽限最后一天当户仍能来赎），
	# contract_status 不替还没结账的合同预报满当；先看未结账时的状态，再按第 38 天结账。
	_check(w.ledger.contract_status(tid, 38) == "overdue", "第 38 天未结账前：仍是已到期可协商（不预报满当）")
	w.ledger.tick_contracts(38)
	_check(w.ledger.contract_status(tid, 38) == "forfeited" and w.ledger.contract_status_text(tid, 38) == "已满当", "第 38 天（过宽限期）结账后状态：已满当")

	# 利息与赎回金额：不足一月按一月计，月息 3%
	_check(w.ledger.redeem_months(tid, 2) == 1 and w.ledger.redeem_interest(tid, 2) == 3 and w.ledger.redeem_amount(tid, 2) == 103, "起当当日（不足一月按一月计）：本 100 + 息 3 = 103 蚨")
	_check(w.ledger.redeem_months(tid, 16) == 1 and w.ledger.redeem_amount(tid, 16) == 103, "起当 14 天（不足一月按一月计）：103 蚨")
	_check(w.ledger.redeem_months(tid, 32) == 1 and w.ledger.redeem_amount(tid, 32) == 103, "起当满 30 天（到期日）：103 蚨")
	_check(w.ledger.redeem_months(tid, 33) == 2 and w.ledger.redeem_interest(tid, 33) == 6 and w.ledger.redeem_amount(tid, 33) == 106, "第 33 天（31 天，跨入第 2 个月）：本 100 + 息 6 = 106 蚨")

	# 非整百当本四舍五入校验（160 蚨 × 3% = 4.8 → 5 蚨，赎回 165 蚨）
	var iid2: String = w.ledger.add_item(_def("deed_zhao"), "zhao", "counter")
	var tid2: String = w.ledger.open_pawn("zhao", [iid2], 160, 2, 30, "红契", false)
	_check(w.ledger.redeem_interest(tid2, 20) == 5 and w.ledger.redeem_amount(tid2, 20) == 165, "160 蚨当本 1 个月利息四舍五入为 5 蚨，赎回 165 蚨")
	_check(w.ledger.redeem_interest(tid2, 35) == 10 and w.ledger.redeem_amount(tid2, 35) == 170, "160 蚨当本 2 个月利息四舍五入为 10 蚨，赎回 170 蚨")

	# open_pawn 不钳制 term_days（传 0 原样记录）；宽限记默认 5 天。
	# 合入 integration 后 open_pawn 保持 7 个参数（卡牌版 card_ledger.gd 覆盖它，子类不能少参数），不再单传月息 / 宽限；
	# 也不存 forfeit_day 这种派生栏（续当只改 due_day，派生栏会过期），满当日按 due_day + grace_days 现算。
	var iid3: String = w.ledger.add_item(_def("hairpin"), "linsao", "counter")
	var tid3: String = w.ledger.open_pawn("linsao", [iid3], 50, 2, 0, "梅花簪", false)
	var c3: Dictionary = w.ledger.contracts[tid3]
	_check(int(c3["term_days"]) == 0 and int(c3["due_day"]) == 2 and int(c3["grace_days"]) == 5, "open_pawn 不钳制 term_days，宽限取默认 5 天")
	_check(w.ledger.check_invariants().is_empty(), "结构与计息校验后账本不变量成立")

func _test_redeem_active_and_overdue() -> void:
	var w = World.new()
	w.setup(19380306)
	w.day = 2
	# 给林嫂补充足够赎当的资金（从船行汇款，保持账本守恒）
	w.ledger.transfer("船行", "linsao", 150, "丈夫汇款")
	var iid: String = w.ledger.add_item(_def("hairpin"), "linsao", "counter")
	var tid: String = w.ledger.open_pawn("linsao", [iid], 100, 2, 30, "破旧", true)
	w.add_risk("ticket_old", tid, "林嫂来赎时会发现当票写成了“破旧”")

	# 活当期内，未满当的当物不可当作自有库存转卖
	var premature_sell: String = w.ledger.sell_stock_item(iid, "zhouma", 120)
	_check(premature_sell == "", "活当期内当物在典当盒，不能提前转卖")

	# 第 20 天正常赎回（含“破旧”隐患触发口碑 -3）
	w.day = 20
	var cash_before: int = w.cash()
	var koubei_before: int = w.koubei
	var ok: bool = w.redeem_contract(tid)
	_check(ok, "第 20 天活当期内赎回成功")
	_check(w.cash() == cash_before + 103, "赎回入账 103 蚨（本 100 + 息 3）")
	_check(w.ledger.items[iid]["location"] == "npc:linsao" and w.ledger.items[iid]["pledged_to"] == "", "赎回后当物归还林嫂并解除质押")
	_check(w.ledger.contract_status(tid, 20) == "redeemed" and w.ledger.contract_status_text(tid, 20) == "已赎回", "赎回后状态为已赎回")
	_check(w.koubei == koubei_before - 3, "当票写“破旧”赎回时触发口碑 -3")
	_check(not w.ledger.redeem(tid, 21), "已赎回当票不可二次赎回")

	# 逾期宽限期内（已到期可协商）赎回：按 2 个月计息
	w.day = 2
	w.ledger.transfer("sunlaoye", "zhao", 350, "筹款")
	var iid2: String = w.ledger.add_item(_def("deed_zhao"), "zhao", "counter")
	var tid2: String = w.ledger.open_pawn("zhao", [iid2], 300, 2, 30, "红契一纸", false)
	w.day = 34   # 到期日 32，第 34 天属于逾期 2 天（宽限期内）
	_check(w.ledger.contract_status(tid2, w.day) == "overdue" and w.ledger.contract_status_text(tid2, w.day) == "已到期可协商", "第 34 天处于已到期可协商状态")
	var cash_before2: int = w.cash()
	var ok2: bool = w.ledger.redeem(tid2, w.day)
	_check(ok2, "已到期可协商期内（第 34 天）赎回成功")
	_check(w.cash() == cash_before2 + 318, "第 34 天赎回按 2 个月计息收 318 蚨（本 300 + 息 18）")

	# 赎回返物不改变所有权（当物原主不是当户时，owner 保持原主不被改写为 borrower）
	w.ledger.transfer("sunlaoye", "xiaoding", 100, "筹款")
	var iid_borrowed: String = w.ledger.add_item(_def("hairpin"), "sunlaoye", "counter")
	var tid_borrowed: String = w.ledger.open_pawn("xiaoding", [iid_borrowed], 50, 2, 30, "借来的簪", false)
	_check(w.ledger.items[iid_borrowed]["owner"] == "sunlaoye", "当入时当物原主保持为 sunlaoye")
	var ok_borrowed: bool = w.ledger.redeem(tid_borrowed, 10)
	_check(ok_borrowed and w.ledger.items[iid_borrowed]["location"] == "npc:xiaoding" and w.ledger.items[iid_borrowed]["owner"] == "sunlaoye", "赎回后当物返给当户但所有权 owner 仍保持原主 sunlaoye 不被改写")

	# redeem() 不设未声明的 fake_collateral / day < signed_day 拒赎守卫
	var iid_fc: String = w.ledger.add_item(_def("hairpin"), "xiaoding", "counter")
	var tid_fc: String = w.ledger.open_pawn("xiaoding", [iid_fc], 20, 5, 30, "测试当物", false)
	w.ledger.contracts[tid_fc]["fake_collateral"] = true
	_check(w.ledger.redeem(tid_fc, 3), "redeem() 无未声明的 fake_collateral 或 day < signed_day 拒赎守卫")
	_check(w.ledger.check_invariants().is_empty(), "赎回流程后账本不变量成立")

func _test_forfeit_to_stock_and_resell() -> void:
	var w = World.new()
	w.setup(19380306)
	w.day = 1
	var iid: String = w.ledger.add_item(_def("hairpin"), "linsao", "counter")
	var tid: String = w.ledger.open_pawn("linsao", [iid], 120, 1, 30, "足金梅花簪", true)
	var j_before: int = w.ledger.journal.size()

	# 到第 33 天（到期日 31，逾期 2 天）：tick_contracts 进入 overdue
	var ch1: Array = w.ledger.tick_contracts(33)
	_check(ch1.has(tid) and w.ledger.contracts[tid]["status"] == "overdue", "第 33 天 tick_contracts 转为 overdue（已到期可协商）")
	_check(w.ledger.items[iid]["location"] == "pawnbox", "宽限期内物品仍在典当盒（pawnbox）")

	# 到第 37 天（超过 due_day 31 + grace 5 = 36）：tick_contracts 转为 forfeited（已满当），物品进 stock 并记一笔账
	var ch2: Array = w.ledger.tick_contracts(37)
	_check(ch2.has(tid) and w.ledger.contracts[tid]["status"] == "forfeited", "第 37 天 tick_contracts 转为 forfeited（已满当）")
	_check(w.ledger.contract_status_text(tid, 37) == "已满当", "满当后状态文本为已满当")
	_check(w.ledger.items[iid]["location"] == "stock" and w.ledger.items[iid]["owner"] == "player" and w.ledger.items[iid]["pledged_to"] == "", "满当后物品转入库存 stock 且归当铺所有")
	_check(not w.ledger.items[iid].has("cost") and is_zero_approx(float(w.ledger.items[iid].get("market_bonus", 0.0))), "_forfeit_contract 不覆盖当物 cost 且不对 ticket_old 设 market_bonus")
	_check(w.ledger.items_at("stock").has(iid), "items_at('stock') 包含满当物品")
	_check(w.ledger.journal.size() == j_before + 1 and str(w.ledger.journal[-1]["ref"]) == tid, "满当入库在账本 journal 记一笔账")
	_check(not w.ledger.redeem(tid, 37), "满当后当户不可再赎回")

	# sell_stock_item 拒绝 buyer 为 player
	var self_sell: String = w.ledger.sell_stock_item(iid, "player", 180)
	_check(self_sell == "" and w.ledger.items[iid]["location"] == "stock", "sell_stock_item 拒绝 buyer 为 player，不产生 npc:player 异常状态")

	# 满当物品进库存后可转卖并记一笔账
	var cash_before_sell: int = w.cash()
	var j_before_sell: int = w.ledger.journal.size()
	var sell_jid: String = w.ledger.sell_stock_item(iid, "sunlaoye", 180)
	_check(sell_jid != "", "满当入库后的物品可转卖")
	_check(w.cash() == cash_before_sell + 180, "转卖满当物品后钱匣增加 180 蚨")
	_check(w.ledger.items[iid]["location"] == "npc:sunlaoye" and w.ledger.items[iid]["owner"] == "sunlaoye", "转卖后物品归买家")
	_check(w.ledger.journal.size() == j_before_sell + 1, "转卖满当物品再记一笔分录")

	# 来自 fake_collateral 当票的当物：满当入库后 sell_stock_item 必须拒绝转卖（伪契满当也卖不掉）
	var iid_fake: String = w.ledger.add_item(_def("deed_zhao"), "sunyoung", "counter")
	var tid_fake: String = w.ledger.open_pawn("sunyoung", [iid_fake], 80, 1, 30, "伪造红契", false)
	w.ledger.contracts[tid_fake]["fake_collateral"] = true
	w.ledger.tick_contracts(38)
	_check(w.ledger.items[iid_fake]["location"] == "stock", "伪契满当后进入库房 stock")
	var fake_sell: String = w.ledger.sell_stock_item(iid_fake, "sunlaoye", 100)
	_check(fake_sell == "" and w.ledger.items[iid_fake]["location"] == "stock" and w.ledger.items[iid_fake]["owner"] == "player", "伪契（fake_collateral）满当入库后不可转卖")

	# redeem() 失败无副作用：逾期宽限期内当户余额不足、或跨日直接到第 40 天（已过宽限期）尝试 redeem，拒绝赎回且不产生移库、记账或状态改写副作用
	var iid2: String = w.ledger.add_item(_def("deed_zhao"), "zhao", "counter")
	var tid2: String = w.ledger.open_pawn("zhao", [iid2], 100, 1, 30, "红契", false)
	# 把赵老三余额转走，使其不够赎当（需 106 蚨）
	var zhao_bal: int = w.ledger.balance("zhao")
	if zhao_bal > 0:
		w.ledger.transfer("zhao", "sunlaoye", zhao_bal, "暂存")
	var j_before_fail: int = w.ledger.journal.size()
	var ok_insufficient: bool = w.ledger.redeem(tid2, 33)
	_check(not ok_insufficient and w.ledger.contracts[tid2]["status"] == "active" and w.ledger.items[iid2]["location"] == "pawnbox" and w.ledger.journal.size() == j_before_fail, "逾期宽限期内余额不足 redeem() 失败时无状态改写、移库或记账副作用")
	if zhao_bal > 0:
		w.ledger.transfer("sunlaoye", "zhao", zhao_bal, "归还")
	j_before_fail = w.ledger.journal.size()
	# 合入 integration 后：能不能赎以合同实际状态为准（小镇补还原物时会把满当合同改回 overdue 再赎），
	# 所以先由 tick_contracts 在第 40 天结账满当，再验证满当后的 redeem() 失败无副作用。
	var ch_late: Array = w.ledger.tick_contracts(40)
	_check(ch_late.has(tid2) and w.ledger.contracts[tid2]["status"] == "forfeited" and w.ledger.items[iid2]["location"] == "stock" and w.ledger.journal.size() == j_before_fail + 1, "满当由 tick_contracts 统一完成移库与记账")
	j_before_fail = w.ledger.journal.size()
	var ok_late: bool = w.ledger.redeem(tid2, 40)
	_check(not ok_late, "超过宽限期（第 40 天）结账满当后不可赎回")
	_check(w.ledger.contracts[tid2]["status"] == "forfeited" and w.ledger.items[iid2]["location"] == "stock" and w.ledger.journal.size() == j_before_fail, "redeem() 失败返回 false 时无移库、无记账、无状态改写副作用")
	_check(w.ledger.check_invariants().is_empty(), "满当与转卖后账本不变量（蚨总量守恒）成立")

func _test_book_panel_display() -> void:
	var w = World.new()
	w.setup(19380306)
	w.day = 2
	var iid: String = w.ledger.add_item(_def("hairpin"), "linsao", "counter")
	var tid: String = w.ledger.open_pawn("linsao", [iid], 160, 2, 30, "足金梅花簪", false)

	var panel = BookPanel.new()
	root.add_child(panel)
	await process_frame
	panel.open("ledger", w)
	panel._set_tab("活当")
	var txt_active: String = panel.body.text
	_check(txt_active.find(tid) >= 0 and txt_active.find("活当期内") >= 0, "账簿显示当号与状态「活当期内」")
	_check(txt_active.find(w.date_text(32)) >= 0 and txt_active.find("165 蚨") >= 0, "账簿显示到期日与当前赎回金额 165 蚨")

	w.day = 34
	panel._render()
	var txt_overdue: String = panel.body.text
	_check(txt_overdue.find("已到期可协商") >= 0 and txt_overdue.find("170 蚨") >= 0, "世界日期到第 34 天时账簿显示「已到期可协商」与 2 个月赎回金额 170 蚨")

	w.day = 38
	w.ledger.tick_contracts(w.day)
	panel._render()
	var txt_forfeited: String = panel.body.text
	_check(txt_forfeited.find("已满当") >= 0, "世界日期到第 38 天时账簿显示「已满当」")

	# 已赎回当票：即使世界日期继续推进到第 40 天（按当前日期重算会变成 2 个月 170 蚨），账簿仍显示实际赎回时的 redeemed_amount（165 蚨）
	w.day = 2
	w.ledger.transfer("船行", "linsao", 200, "汇款")
	var iid_r: String = w.ledger.add_item(_def("hairpin"), "linsao", "counter")
	var tid_r: String = w.ledger.open_pawn("linsao", [iid_r], 160, 2, 30, "银簪", false)
	w.day = 20
	_check(w.ledger.redeem(tid_r, 20), "第 20 天以 165 蚨赎回 tid_r")
	w.day = 40
	panel._render()
	var txt_redeemed: String = panel.body.text
	_check(txt_redeemed.find("已赎回") >= 0 and txt_redeemed.find("赎回：165 蚨") >= 0, "已赎回当票在第 40 天仍显示实际 redeemed_amount（165 蚨），不按当前日期重算")

	# 合入前的旧存档：赎回时没存 redeemed_*。金额从赎当那笔账取，日期不拿今天顶替
	var cr: Dictionary = w.ledger.contracts[tid_r]
	for k in ["redeemed_day", "redeemed_amount", "redeemed_interest", "redeemed_months"]:
		cr.erase(k)
	panel._render()
	var txt_old: String = panel.body.text
	_check(txt_old.find("赎回：165 蚨") >= 0 and txt_old.find("已于 %s 赎回" % w.date_text(40)) < 0, "旧存档的已赎回当票显示当时的 165 蚨，不显示今天为赎回日")

	# 赔偿结清：显示赔的钱，不显示按今天重算的赎回价，括号里不空
	cr["status"] = "compensated"
	cr["compensation"] = 150
	panel._render()
	var txt_comp: String = panel.body.text
	_check(txt_comp.find("赔偿：150 蚨") >= 0 and txt_comp.find("赔偿 150 蚨结清") >= 0 and txt_comp.find("（）") < 0, "赔偿结清的当票显示赔偿 150 蚨，到期备注不空")

	# 开局前已在当的旧账：起当日写“开张前 N 天”，不显示今天
	cr["signed_day"] = -27
	panel._render()
	_check(panel.body.text.find("开张前 27 天") >= 0, "开局前签的当票起当日显示「开张前 27 天」")

	panel.queue_free()
	await process_frame
