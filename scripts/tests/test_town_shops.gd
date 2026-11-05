# 店铺特写配置：能加载、动作 kind 在白名单、脚本存在、条件能解析；pay_bills 的 payee 对得上账单；
# 另外把 data/** 里所有 cond/when 在 flag() 取到字符串/整数/小数/布尔/null 时都求一遍值（cond_types_check.gd），
# Expression 不短路，flag('x') == 'abc' 遇到数字会报 Invalid operands。
# godot --headless -s res://scripts/tests/test_town_shops.gd
extends SceneTree

const Cond = preload("res://scripts/core/cond.gd")
const CondTypes = preload("res://scripts/tests/cond_types_check.gd")

const KINDS = ["buy", "sell_to_shop", "pay_bills", "talk", "script", "appraise", "letters", "negotiate", "leave"]
const SHOPS = ["teahouse", "ricehall", "pharmacy", "baogong", "post", "market"]

var errs: Array = []
var bill_payees: Dictionary = {}   # town_pack 里账单真正的收款方；pay_bills 的 payee 必须在里面

func _initialize() -> void:
	_load_bill_payees()
	for id in SHOPS:
		_shop("res://data/town/shops/%s.json" % id)
	var stats := {}
	errs.append_array(CondTypes.run(stats))
	if int(stats.get("conds", 0)) < 150:
		errs.append("条件体检只扫到 %d 条，数据目录读不全？" % int(stats.get("conds", 0)))
	if errs.is_empty():
		print("TOWN SHOPS OK (%d shops, %d conditions type-checked)" % [SHOPS.size(), int(stats.get("conds", 0))])
		quit(0)
		return
	for e in errs:
		printerr("FAIL: ", e)
	quit(1)

func _load_bill_payees() -> void:
	var j := JSON.new()
	var path := "res://data/town/town_pack.json"
	if not FileAccess.file_exists(path) or j.parse(FileAccess.get_file_as_string(path)) != OK:
		errs.append("读不到 " + path)
		return
	for row in j.data.get("living_costs", []):
		if str(row.get("payee", "")) != "":
			bill_payees[str(row["payee"])] = true
	if bill_payees.is_empty():
		errs.append("town_pack 没有任何账单收款方")

func _shop(path: String) -> void:
	if not FileAccess.file_exists(path):
		errs.append("缺少 " + path)
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		errs.append("JSON 失败 " + path)
		return
	var shop: Dictionary = j.data
	if str(shop.get("_provenance", "")) == "":
		errs.append(path + " 缺 _provenance")
	if shop.get("greeting", []).size() < 8:
		errs.append(path + " 招呼少于 8")
	if shop.get("topics", []).size() < 5:
		errs.append(path + " 话题少于 5")
	var actions: Array = shop.get("actions", [])
	if actions.size() < 4 or actions.size() > 7:
		errs.append("%s 动作数 %d 不在 4–7" % [path, actions.size()])
	for act in actions:
		var kind := str(act.get("kind", ""))
		if not KINDS.has(kind):
			errs.append("%s 动作 kind 不在白名单：%s" % [path, kind])
		if kind == "pay_bills" and act.has("payee") and not bill_payees.has(str(act["payee"])):
			errs.append("%s 动作 %s 的 payee「%s」不是任何账单的收款方（应为 %s 之一）" % [path, act.get("id", ""), act["payee"], ", ".join(bill_payees.keys())])
		if kind == "script":
			var sid := str(act.get("script", ""))
			var sp := "res://data/story/%s.json" % sid
			if not FileAccess.file_exists(sp):
				errs.append("%s 脚本不存在 %s" % [path, sid])
			else:
				var sj := JSON.new()
				if sj.parse(FileAccess.get_file_as_string(sp)) != OK or str(sj.data.get("id", "")) != sid:
					errs.append("脚本 id 不符 " + sid)
		_when(path, str(act.get("when", "")))
	for g in shop.get("greeting", []):
		_when(path, str(g.get("when", "")))
	for t in shop.get("topics", []):
		_when(path, str(t.get("when", "")))

func _when(path: String, expr: String) -> void:
	if expr == "":
		return
	var e := Expression.new()
	if e.parse(Cond.rewrite(expr)) != OK:
		errs.append("%s 条件解析失败 「%s」%s" % [path, expr, e.get_error_text()])
