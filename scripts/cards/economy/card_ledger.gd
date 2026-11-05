# 卡牌账本继承旧账本，仅覆盖典当三个函数；金额和计息全部整数。
# G04；当号和历史原因只使用 ASCII。
extends "res://scripts/core/ledger.gd"
var rate_pct: int = 3
var storage_permille: int = 5
var grace_days: int = 3

func open_pawn(borrower: String, item_ids: Array, principal: int, day: int, term_days: int, condition_text: String,
		ticket_old: bool) -> String:
	if principal < 0 or item_ids.is_empty() or not accounts.has(borrower):
		return ""
	for iid in item_ids:
		if not items.has(iid) or items[iid]["pledged_to"] != "":
			return ""
	var tid := "t%04d" % next_ticket
	var jid := transfer("player", borrower, principal, "g04.reason.pawn_out", tid)
	if principal > 0 and jid == "":
		return ""
	contracts[tid] = {"id": tid, "no": next_ticket, "borrower": borrower, "item_ids": item_ids.duplicate(),
		"principal": principal, "rate_pct": rate_pct, "storage_permille": storage_permille,
		"signed_day": day, "due_day": day + maxi(1, term_days), "term_days": maxi(1, term_days),
		"status": "active", "condition": condition_text if condition_text == condition_text.to_ascii_buffer().get_string_from_ascii() else "", "ticket_old": ticket_old,
		"unauthorized_disposal": false, "renewals": [], "journal": [jid] if jid != "" else []}
	next_ticket += 1
	for iid in item_ids:
		items[iid]["pledged_to"] = tid
		move_item(iid, "pawnbox", borrower, "pawn_in")
	return tid

func redeem_amount(tid: String, day: int) -> int:
	if not contracts.has(tid):
		return 0
	var c: Dictionary = contracts[tid]
	var months: int = maxi(1, (maxi(0, day - int(c["signed_day"])) + 29) / 30)
	var p: int = int(c["principal"])
	return p + p * int(c["rate_pct"]) * months / 100 + p * int(c["storage_permille"]) * months / 1000

func tick_contracts(day: int, _grace: int = 5) -> Array:
	var changed: Array = []
	var ids := contracts.keys()
	ids.sort()
	for tid in ids:
		var c: Dictionary = contracts[tid]
		if str(c["status"]) not in ["active", "overdue"]:
			continue
		if day > int(c["due_day"]) + grace_days:
			c["status"] = "forfeited"
			for iid in c["item_ids"]:
				items[iid]["pledged_to"] = ""
				if str(items[iid]["location"]) == "pawnbox":
					move_item(iid, "stock", "player", "forfeit")
			changed.append(tid)
		elif day > int(c["due_day"]) and c["status"] == "active":
			c["status"] = "overdue"
			changed.append(tid)
	return changed
