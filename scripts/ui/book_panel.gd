# 柜台右侧的三本册子：
#   账簿 ledger    —— 钱匣、当日流水、活当（当号/当户/当物/当本/到期）、借据、待办与倒计时（客观账目清楚可见，GameJev UX02）
#   档案簿 notebook —— 对话记录、鉴定结果、消息（标注 亲眼 / 听说 / 推测）、知识页、人物卡、各方（只给模糊印象）
#   鉴别录 medbook  —— 《沈记药材鉴别录》逐页翻，末页“已知假批号”
extends PanelContainer

const Rules = preload("res://scripts/town/rules.gd")   # [onboarding] 规矩一栏

signal closed

var main
var world
var kind: String = "ledger"
var title_lbl: Label
var tabs: HBoxContainer
var body: RichTextLabel
var page_idx: int = 0
var tab: String = ""
var close_btn: Button
var nav: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", UiStyle.box(Color("#f4e2b0"), Color("#2f4670"), 6, 3, 18))
	var v := UiStyle.vbox(6)
	add_child(v)
	var top := UiStyle.hbox(10)
	v.add_child(top)
	title_lbl = UiStyle.title_label("", 30)
	top.add_child(title_lbl)
	tabs = UiStyle.hbox(4)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(tabs)
	v.add_child(UiStyle.hsep(Color("#b0262a")))
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 17)
	body.add_theme_font_size_override("bold_font_size", 19)
	body.add_theme_color_override("default_color", UiStyle.INK)
	v.add_child(body)
	nav = UiStyle.hbox(8)
	v.add_child(nav)
	close_btn = UiStyle.button("合上", 17, "wood")
	close_btn.pressed.connect(_close)
	v.add_child(close_btn)

func _close() -> void:
	visible = false
	emit_signal("closed")

func _turn(d: int) -> void:
	page_idx += d
	_render()

func _set_tab(n: String) -> void:
	tab = n
	page_idx = 0
	_render()

func open(p_kind: String, p_world) -> void:
	kind = p_kind
	world = p_world
	visible = true
	page_idx = 0
	tab = {"ledger": "钱匣", "notebook": "消息", "medbook": ""}.get(kind, "")
	_render()

func _tab_buttons(names: Array) -> void:
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	for n in names:
		var b := UiStyle.button(n, 15, "seal" if n == tab else "paper")
		var nn: String = n
		b.pressed.connect(_set_tab.bind(nn))
		tabs.add_child(b)

func _nav(n_pages: int) -> void:
	for c in nav.get_children():
		nav.remove_child(c)
		c.queue_free()
	if n_pages <= 1:
		return
	var prev := UiStyle.button("◀ 上一页", 15)
	prev.disabled = page_idx <= 0
	prev.pressed.connect(_turn.bind(-1))
	nav.add_child(prev)
	var l := UiStyle.label("第 %d / %d 页" % [page_idx + 1, n_pages], 15, UiStyle.INK_SOFT, false)
	nav.add_child(l)
	var nxt := UiStyle.button("下一页 ▶", 15)
	nxt.disabled = page_idx >= n_pages - 1
	nxt.pressed.connect(_turn.bind(1))
	nav.add_child(nxt)

func _e(s) -> String:
	return str(s).replace("[", "[lb]")

# 已结的合同显示当时结的钱，不按今天重算：赎回看 redeemed_amount，旧存档没有就查赎当那笔账；赔偿看 compensation
func _closed_amount(tid: String, c: Dictionary, st_code: String) -> int:
	match st_code:
		"redeemed":
			if c.has("redeemed_amount"):
				return int(c["redeemed_amount"])
			for j in world.ledger.journal:
				if str(j.get("ref", "")) == tid and str(j.get("reason", "")) == "赎当":
					return int(j["amount"])
			return int(c["principal"])
		"compensated":
			return int(c.get("compensation", 0))
	return world.ledger.redeem_amount(tid, int(world.day))

# 开局时已在当的旧账 signed_day 为负；date_text 把负数当“今天”，这里单独写
func _signed_text(d: int) -> String:
	return world.date_text(d) if d >= 0 else "开张前 %d 天" % -d

func _render() -> void:
	match kind:
		"ledger": _render_ledger()
		"notebook": _render_notebook()
		"medbook": _render_medbook()

# ---------------- 账簿 ----------------
func _render_ledger() -> void:
	title_lbl.text = "账簿"
	_tab_buttons(["钱匣", "活当", "借据", "待办", "库存"])
	_nav(0)
	var db = world.db if world != null and world.get("db") != null else DB.get_db()      # 小镇：生成的客人在这一局的 db 里
	var t := ""
	match tab:
		"钱匣":
			t += "[b]钱匣：%d 蚨[/b]　（%s蚨）\n\n" % [world.cash(), UiStyle.cn_money(world.cash())]
			var f: Dictionary = world.ledger.day_flows(world.day_journal_start)
			t += "今日　收 %d 蚨　付 %d 蚨\n" % [f["income"], f["expense"]]
			for r in f["rows"]:
				t += "　%s %d 蚨 · %s\n" % [r[0], r[1], _e(r[2])]
			t += "\n[color=#5a3f2a]全部流水（每一笔钱都有来处）：[/color]\n"
			for j in world.ledger.journal:
				if j["from"] == "player" or j["to"] == "player":
					var sign := "+" if j["to"] == "player" else "−"
					var other: String = j["from"] if j["to"] == "player" else j["to"]
					t += "　%s %s%d　%s（%s）\n" % [j["id"], sign, j["amount"], _e(j["reason"]), _e(db.npc_label(other) if db.cast.has(other) else other)]
		"活当":
			if world.ledger.contracts.is_empty():
				t += "（还没有活当。）\n"
			for ft in world.ledger.foreign_tickets:
				t += "[color=#6e1a1c][b]%s[/b]　不在这两天的账上 · %s · 日期 %s · 当户（空）[/color]\n\n" % [_e(ft["no"]), _e(ft.get("hand", "")), _e(ft["date"])]
			for tid in world.ledger.contracts:
				var c: Dictionary = world.ledger.contracts[tid]
				var names: Array = []
				for iid in c["item_ids"]:
					names.append(world.ledger.items[iid]["name"])
				var st_code: String = world.ledger.contract_status(tid, int(world.day))
				var st: String = world.ledger.contract_status_text(tid, int(world.day))
				var signed_day: int = int(c.get("signed_day", c.get("start_day", 0)))
				var due_day: int = int(c["due_day"])
				var redeem_amt: int = _closed_amount(tid, c, st_code)
				var due_note := ""
				match st_code:
					"active":
						due_note = "还有 %d 天" % (due_day - int(world.day))
					"overdue":
						var over: int = int(world.day) - due_day
						var grace_left: int = maxi(0, int(c.get("grace_days", 5)) - over)
						due_note = "逾期 %d 天，可协商宽限剩 %d 天" % [over, grace_left]
					"forfeited":
						due_note = "已满当入库"
					"redeemed":
						# 合入前的存档没有 redeemed_day：只写已赎回，不拿今天顶替
						due_note = ("已于 %s 赎回" % world.date_text(int(c["redeemed_day"]))) if c.has("redeemed_day") else "已赎回"
					"compensated":
						due_note = "原物已失，赔偿 %d 蚨结清" % int(c.get("compensation", 0))
				if c.get("fake_collateral", false):
					t += "[color=#b0262a]⚠ 当物是伪契：赎不回来，满当也卖不掉。[/color]\n"
				if c.get("ticket_old", false):
					t += "[color=#b0262a]⚠ 这张当票成色写了“破旧”，当户来赎时会发现。[/color]\n"
				t += "[b]%s[/b]　%s\n　当户：%s　当物：%s\n　成色：%s　当本：%d 蚨（%s）　月息三分　%s：%d 蚨\n　起当：%s　到期：%s（%s）\n\n" % [tid, st, _e(db.npc_label(c["borrower"])), _e("、".join(names)), _e(c["condition"]), c["principal"], UiStyle.cn_money(int(c["principal"])), "赔偿" if st_code == "compensated" else "赎回", redeem_amt, _signed_text(signed_day), world.date_text(due_day), due_note]
		"借据":
			if world.ledger.debts.is_empty():
				t += "（没有借据、借条。）\n"
			for did in world.ledger.debts:
				var d: Dictionary = world.ledger.debts[did]
				if d["kind"] == "recourse":
					continue
				var who: String = db.npc_label(d["debtor"]) if d["debtor"] != "player" else "你"
				var to: String = db.npc_label(d["creditor"]) if d["creditor"] != "player" else "你"
				t += "[b]%s[/b]　%s 欠 %s：%d 蚨（未还 %d）　%s\n　%s\n\n" % [did, who, to, d["principal"], d["outstanding"], {"active": "未了", "overdue": "逾期", "settled": "已结"}.get(d["status"], d["status"]), _e(d["note"])]
		"待办":
			for td in world.todos:
				var due := ""
				if int(td["due_day"]) >= 0:
					due = "　期限：%s" % world.date_text(int(td["due_day"]))
				t += "· [b]%s[/b]：%s%s\n" % [_e(td["who"]), _e(td["text"]), due]
			var cd: String = world.countdown_text()
			if cd != "":
				t += "\n[color=#b0262a]%s[/color]\n" % cd
			if not world.liabilities.is_empty():
				t += "\n[b]应付[/b]（义务，不是钱匣里的钱）\n"
				for l in world.liabilities:
					t += "· %s：%d 蚨，期限 %s（%s）\n" % [_e(l["what"]), int(l["amount"]), world.date_text(int(l["due_day"])) if int(l["due_day"]) >= 0 else "—", l["status"]]
			if not world.risks.is_empty():
				t += "\n[b]隐患[/b]\n"
				for r in world.risks:
					t += "· [color=#b0262a]%s[/color]（%s）\n" % [_e(r["text"]), r["status"]]
		"库存":
			var any := false
			for loc in ["stock", "pawnbox", "trash", "drawer"]:
				for iid in world.ledger.items_at(loc):
					any = true
					var it: Dictionary = world.ledger.items[iid]
					var tag: String = {"stock": "库房", "pawnbox": "典当盒（活当，东西还是人家的）", "trash": "垃圾箱", "drawer": "抽屉（自家的，不卖）"}[loc]
					var tags := ""
					if not it.get("tags", []).is_empty():
						tags = "　袋上印：" + "、".join(it["tags"])
					t += "· %s　[color=#5a3f2a]%s[/color]%s\n" % [_e(it["name"]), tag, _e(tags)]
			if not any:
				t += "（库房是空的。）\n"
	body.text = t

# ---------------- 档案簿 ----------------
func _render_notebook() -> void:
	title_lbl.text = "档案簿"
	_tab_buttons(["消息", "鉴定", "对话", "知识", "规矩", "人物", "各方"])
	var db = world.db if world != null and world.get("db") != null else DB.get_db()      # 小镇：生成的客人在这一局的 db 里
	var t := ""
	var src := {"seen": "[color=#4a6a3a]〔亲眼〕[/color]", "heard": "[color=#2f4670]〔听说〕[/color]", "inferred": "[color=#b0262a]〔推测〕[/color]"}
	match tab:
		"消息", "鉴定", "对话":
			var kinds: Array = {"消息": ["消息", "街景", "线索", "借条", "人物", "势力", "行情", "口碑"], "鉴定": ["鉴定"], "对话": ["对话"]}[tab]
			var lines: Array = []
			for e in world.notebook:
				if kinds.has(e["kind"]):
					var via := ""
					if str(e.get("via", "")) != "" and db.cast.has(str(e["via"])) and e["source"] != "seen":
						via = "（%s）" % db.npc_label(str(e["via"]))
					lines.append("[color=#7b5638]%s %s[/color] %s%s %s" % [_short_date(int(e["day"])), world.SLOTS[int(e["slot"])], src.get(e["source"], ""), via, _e(e["text"])])
			lines.reverse()
			var per := 14
			var pages := maxi(1, int(ceil(lines.size() / float(per))))
			page_idx = clampi(page_idx, 0, pages - 1)
			_nav(pages)
			t = "\n".join(lines.slice(page_idx * per, page_idx * per + per))
			if lines.is_empty():
				t = "（还没有记下什么。人说过的话，过两天就会变。）"
		"知识", "规矩":
			var ids: Array = Rules.page_ids(world, tab == "规矩")      # [onboarding] 规矩页单独一栏
			_nav(ids.size())
			if ids.is_empty():
				t = "（还没有。）" if tab == "知识" else "（还没有人跟你说过规矩。哥哥、周妈、马保长，到时候都会说；说过的会记在这里。）"
			else:
				page_idx = clampi(page_idx, 0, ids.size() - 1)
				var pg: Dictionary = Rules.page(world, str(ids[page_idx]))
				if pg.is_empty():
					pg = db.pages.get(ids[page_idx], {})
				t = "[b]%s[/b]\n\n%s" % [_e(pg.get("title", "")), _e(pg.get("body", ""))]
		"人物":
			_nav(0)
			var passers := 0
			for id in world.npcs:
				var n: Dictionary = world.npcs[id]
				var fam: float = float(n["rel"].get("player", {}).get("familiarity", 0.0))
				if fam <= 0.0 and id != "brother" and id != "chen":
					continue
				# 小镇：没名没姓的过路客人、生客（walkin:… / stranger:…）不一人一张，末尾合成一行
				if str(id).begins_with("walkin:") or str(id).begins_with("stranger:"):
					passers += 1
					continue
				var def: Dictionary = db.cast.get(id, {})
				t += "[b]%s[/b]（%s）　%s\n　%s\n\n" % [_e(def.get("label", id)), _e(def.get("name", "")), _e(def.get("identity", "")) if id in ["brother", "chen"] else "", _e(def.get("look", ""))]
			if passers > 0:
				t += "[color=#5a3f2a]过路客人：接待过 %d 位[/color]\n" % passers
		"各方":
			_nav(0)
			t += "[color=#5a3f2a]（陈叔叔用棋子讲的。谁是谁，要自己慢慢看。）[/color]\n\n"
			for f in db.factions.get("factions", []):
				var v: int = int(world.faction_trust.get(f["key"], 0))
				t += "[b]%s · %s[/b]　印象：%s\n　%s\n\n" % [_e(f.get("piece", "")), _e(f["key"]), world.fuzzy_trust(v), _e(f.get("line", ""))]
	body.text = t

func _short_date(d: int) -> String:
	if d == 0:
		return "初四"
	return world.date_text(d).split(" ")[1].split("·")[0].strip_edges() if world.date_text(d).split(" ").size() > 1 else ""

# ---------------- 鉴别录 ----------------
func _render_medbook() -> void:
	title_lbl.text = "《沈记药材鉴别录》"
	_tab_buttons([])
	var db = world.db if world != null and world.get("db") != null else DB.get_db()      # 小镇：生成的客人在这一局的 db 里
	var pages: Array = db.medbook.get("pages", [])
	var n := pages.size() + 2
	page_idx = clampi(page_idx, 0, n - 1)
	_nav(n)
	var t := ""
	if page_idx == 0:
		t = "[b]批号规则[/b]\n\n" + _e(db.medbook.get("rules", ""))
	elif page_idx == n - 1:
		t = "[b]末页 · 已知假批号（第一版）[/b]\n\n"
		for fb in db.medbook.get("fake_batches", []):
			t += "　[color=#b0262a]%s[/color]\n" % _e(fb)
	else:
		var p: Dictionary = pages[page_idx - 1]
		t = "[b]%s[/b]\n厂家：%s　厂码：%s\n\n[color=#4a6a3a]正品[/color]：%s\n[color=#b0262a]常见假货[/color]：%s\n有效期：%s　价值：%s\n风险：%s" % [_e(p.get("name", "")), _e(p.get("maker", "")), _e(p.get("code", "")), _e(p.get("real", "")), _e(p.get("fake", "")), _e(p.get("life", "")), _e(p.get("value", "")), _e(p.get("risk", ""))]
	body.text = t
