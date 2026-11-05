extends SceneTree

const Ledger = preload("res://scripts/core/ledger.gd")
var failures: Array = []

func _init() -> void:
	var book = Ledger.new()
	book.open_account("player", 100)
	book.open_account("borrower", 30)
	var iid: String = book.add_item({"def_id": "heirloom", "name": "金簪", "market": 50}, "borrower", "counter")
	var tid: String = book.open_pawn("borrower", [iid], 20, 1, 7, "原物保管", false)
	check(tid != "", "pawn opens")
	check(not book.renew(tid, 7, 999), "unaffordable renewal fails")
	check(int(book.contracts[tid]["due_day"]) == 8, "failed renewal leaves due date")
	check(book.renew(tid, 7, 2), "renewal succeeds")
	var paid_balance: int = book.balance("borrower")
	check(book.renew(tid, 7, 2) and book.balance("borrower") == paid_balance, "repeat renewal is idempotent")
	check(not book.renew(tid, 7, 3), "same renewal cannot change fee")
	check(int(book.contracts[tid]["due_day"]) == 15, "renewal extends original term")
	book.contracts[tid]["unauthorized_disposal"] = true
	book.move_item(iid, "npc:buyer", "buyer", "提前售出")
	check(not book.redeem(tid, 9), "disposed pledge cannot be silently redeemed")
	check(book.renew(tid, 9, 1), "disposal does not cancel renewal obligation")
	check(book.contracts[tid]["unauthorized_disposal"], "renewal retains disposal obligation")
	book.tick_contracts(30)
	book.tick_contracts(31)
	check(book.items[iid]["location"] == "npc:buyer" and book.items[iid]["owner"] == "buyer", "forfeiture cannot teleport a disposed pledge from its buyer")
	check(book.contracts[tid]["unauthorized_disposal"], "forfeiture retains unauthorized disposal evidence")
	var resumed = Ledger.new()
	resumed.from_dict(JSON.parse_string(JSON.stringify(book.to_dict())))
	check(JSON.stringify(resumed.to_dict()) == JSON.stringify(book.to_dict()), "ledger JSON replay exact")
	check(resumed.check_invariants().is_empty(), "cash and contract invariants")
	for failure in failures:
		print("FAIL: ", failure)
	print("SIM LEDGER: ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
