# C04 `counter` · 对话框、柜台的演出（当、卖、买、赎与人物牌的选项）、货架与当票抽屉

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C04 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C04: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 4**（在第 4 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C04`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。小游戏由 C01 的 `CardMiniGameHost` 打开（W0 桩能用，C12–C15 的桩也能开）；物品图、人物头像经 C02 的 `CardArt`（W0 版能用）。1.3：对话框 `CardDialogBox` 归你，C03、C05、C07、C08、C11 的演出都用它，所以对话框是你的第一个 PR、10-21 前合入；柜台那一出要的场景层（C01）、手牌扇（C02）、柜台格子（C03）没合入时用 W0 的桩（`CardIds.widget_scene()` 取）。
- **波次（Wave）**：W1 开发并合入（**W1 完成条件之一**）；W2 补对真引擎（G04 的柜台、定价、客人、当票）的集成测试和 K16 步骤复测。

## 分支

`cards/C04-counter`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

做全游戏共用的对话框（名字条、逐字、点一下继续、跳过、回话），以及柜台那一出：客人走进门、开口报价、东西摆上柜台，你的三档价、不收、细看、选项、回头再说都是回话，客人的回话是对话；来买从货架抽屉挑一件；来赎带当票。客人的底线、真值、真假、耐心数字一个都不上画面——耐心只靠台词和神态。另做货架、当票两个抽屉。

## 必读

1. `docs/cards/DESIGN_cards.md` §一 “示例：第 9 天”、§三.1（柜台：当、卖、买、赎）、§三.2（鉴定小游戏的规矩）、§九.4（第 1 天哥哥在柜台教）。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2、§3.3 开头与 C04、§4.5（人物牌正文：`lines.greet/ask/counter/accept/leave/refused/impatient`、`choices.<id>`）、§4.7.1（person 的来意、`asking`、`choices`）、§4.7.16（当票号键 `g04.ticket.number`）、§7.4（`counter.*` 指令、`mg.request` `mg.report` `card.choose`）、§7.4.3、§7.5（CounterView、ItemView、TicketView；隐藏键黑名单）、§7.8、§8.1（小游戏流程）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/counter/counter_panel.gd`、`scenes/cards/counter/CounterPanel.tscn`（W0 桩）、`scripts/cards/ui/common/w0_stub.gd`（`_counter_step` 是 W0 的自动一步，你的 `autoplay_step()` 要能接替它）、`scripts/cards/mock/mock_scenario.gd`（`_counter_open` `_counter_view` `_tiers` `_counter_offer` `_counter_answer` `_mg_request`）、`scripts/cards/mock/fixtures/day_counter.json`、`scripts/tests/cards/W0/test_table_3days.gd`（第 1 天三位客人靠柜台的自动一步走完）。
4. 只读参考：`scripts/ui/counter_view.gd`（旧版柜台的布局做法；**不拷它的中文**）。

## 要做的事

- [ ] **CardCounterPanel**（`counter_panel.gd`，`class_name CardCounterPanel`，kind `counter`）（10-13 作废，合同 1.3：柜台面板的居中布局作废，改成 `extends CardStagePanel` 的柜台那一出——下面这些“和引擎说话”的做法全部照旧，画在哪、怎么画以下方“10-13 变更二”为准：人在场景上、话在对话框里、你的每个选择都是一句回话）：
  - `open({uid})`：`query("counter", {uid})`；还没开柜台（`ok: false` 或没有 `tiers`）→ `send("counter.open", {uid})`，用返回的柜台视图（同 `query("counter")`）。任何 uid 都不许报错（`W0_skeleton` 用 `day_full` 对每个面板 `open({"uid": "c0002"})`）。
  - 客人：~~头像（`portrait.<person>`，48×64 ×4，NEAREST）~~（1.3：人由场景层站到柜台前）、名字 `CardText.person_name(person)`（1.3：对话框的名字条）、来意字（本任务的键 `c04.intent.<intent>`）、开口一句（`CounterView.line_key`；没有时用 `<def>#lines.greet`）。
  - 东西（`ItemView`）：图 `item.<cat>.<variant>`（~~64×64，×3 或 ×4~~ 1.3：`stage.set_items` 摆在柜台上，64×64 ×2）、名字 `CardText.item_text(template, "name")`、类别字、成色档字（`condition_word` 0–4 → `c04.cond.<n>`）、**观察列表**（`observations` → `CardText.obs(key)`；只是观察句，不是结论；1.3：细看之后在对话框里一句一句说）；客人开口报的价 `asking`（≥ 0 时显示数字）。
  - **看看东西**（1.3：“细看”回话，或柜台上的放大镜热点）：`can_appraise` 为真时可点 → `send("mg.request", {uid, item})`（C01 宿主开小游戏，玩完它发 `mg.report`）；收到 `view_changed` 后重新 `query("counter")`，观察列表刷新。
  - **三档价**：~~按钮~~（1.3：三句回话）金额来自 `tiers.harsh/fair/kind`（数字），文字按方向 `direction`（`pay` 你付钱：来当/来卖；`receive` 你收钱：来买、来赎）用 `c04.tier.<harsh|fair|kind>.<pay|receive>`；点 → `send("counter.offer", {uid, tier})` → `{reply, price}`。
  - **客人回话**：`accept` → `<def>#lines.accept`；`counter` → `<def>#lines.counter` + 还价金额（`last_price` 数字）+ “接/不接” → `send("counter.answer", {uid, accept})`；`leave` → `<def>#lines.leave`，面板体面地收尾（~~按钮变“送客”关面板~~ 1.3：客人出门后收场）。最多 5 轮由引擎管，界面只照 `reply` 走。耐心只用 `line_key`（引擎给的“不耐烦”台词）和头像神态（换一张图或抖一下）体现，**不画耐心条、不写数字**。
  - **来买**：~~没挑东西时显示货架网格（`CounterView.stock`，不够就 `query("stock")`；`ItemView` 小格）~~（10-13 作废，合同 1.3：回话“从货架上挑一件”开 `shelf {pick_for: uid}` 抽屉，在抽屉里挑），挑一件 → `send("counter.pick_stock", {uid, item})` → 再出三档价。
  - **来赎**：当票（`TicketView`：号 `CardText.ui("g04.ticket.number", {"n": no})`、东西、当本 `principal`、剩几天 `days_left`）；~~按钮~~（1.3：回话）“照规矩” `by_rule`、“刁难” `squeeze`；东西已经被你卖掉时（引擎给的 `ticket.status`，合同没定取值，先认 `"sold"`，PR 里列出）换成“赔钱” `compensate`、“去买回来” `buy_back` → `send("counter.redeem", {uid, mode})`。
  - **人物牌的选项**：`query("card", {uid}).choices` 作~~柜台上的额外按钮~~（1.3：回话）（文字 `<def>#choices.<id>`，`enabled: false` 灰掉并显示 `reason_key`）→ `send("card.choose", {uid, choice})`。
  - **拒绝**（1.3：回话“不收”）→ `send("counter.refuse", {uid})`（台词 `<def>#lines.refused`）；**先不管**（牌留在手上；1.3：回话“请他先等等，回头再说”）→ `send("counter.close", {uid})` 并关面板。
  - 成交后：来当显示“开了当票”（当票号用 `g04.ticket.number`），来卖显示“东西上了货架”；收到 `card_left(uid)` 后可以关面板。
- [ ] **autoplay_step()**：和玩家同一条路——没开柜台先 `counter.open`；来买且没挑 → 挑 `stock` 第一件；能鉴定且没看过 → `mg.request`（一局只看一次）；上一句是还价 → 接；否则出 `fair`；来赎 → `by_rule`。同一状态永远做同样的事。保持 W0 的 `W0_table_3days` 第 1 天能走完。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C04.json`（`c04.` 开头，键 + `brief`，`_meta._provenance`）：`c04.tier.<tier>.<pay|receive>`（合同 §2.5 的例子）`c04.intent.<intent>` `c04.cond.<0-4>` ~~`c04.btn.look` `c04.btn.accept` `c04.btn.decline` `c04.btn.refuse` `c04.btn.later`~~（10-13 作废，合同 1.3：被回话取代，换成 `c04.reply.look` `c04.reply.accept` `c04.reply.decline` `c04.reply.refuse` `c04.reply.later`）`c04.btn.send_off` `c04.redeem.<mode>` `c04.result.ticket` `c04.result.shelved` `c04.label.asking`。
- [ ] **夹具**（`scripts/tests/cards/C04/fixtures/`，`_meta.owner = "C04"`）：`pawn.json`（可以直接用 W0 的 `day_counter`）、`sell.json`、`buy.json`（货架 3 件）、`redeem_by_rule.json`、`redeem_sold.json`（东西已卖：`compensate`/`buy_back`）、`choices.json`（带“白给他几个钱”一类选项的人物牌）、`counter_then_leave.json`（还价一轮后客人走）、`after_look.json`（看过东西、观察有三条）。夹具过 `t.no_leaks()`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **柜台面板的“算了”**：覆盖 `CardPanel.dismiss()`（C01 的宿主按 Esc 时调它，面板的关掉按钮也调它）= 上文的“先不管”：`send("counter.close", {uid})` 再 `close_requested.emit({})`，客人留在手上（合同 §7.8）。客人已经走了（`card_left`）时只关面板、不发指令。W0 的桩已经这样做（`W0Stub.dismiss`），换成真实现时保留这个语义。
- [ ] 柜台开着、客人还没谈完就按“打烊 · 下一天”：引擎在 `day_end` 8 关掉会话、客人按“没理会”走（个别人记仇），面板不用拦；收到 `card_left(uid)` 或阶段变了就关面板。
- [ ] 小游戏开着时的“算了”归 C01 的小游戏宿主（`abort()` → `mg.report` 的 `aborted: true`），你照常处理 `aborted` 的结果（这次没看清，可以再看或直接出价）。
- [ ] 测试（并进 `test_pawn_sell.gd`）：开着柜台按 Esc（`host.close_top()`）→ `mock.sent` 最后一条是 `counter.close {uid}`、面板关了、牌还在手上。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardDialogBox**（新：`scenes/cards/counter/DialogBox.tscn` + `scripts/cards/ui/counter/dialog_box.gd`，`class_name CardDialogBox extends CardDialogApi`）：§7.11.5 全部——位置 `DIALOG`、高随内容、`set_max_bottom`；名字条、逐字（`chars_per_sec`，用 `_process` 里的累加器，不分配内存）、点一下 / Space / Enter 推进、“跳过 ▸▸”；一段正文按空行拆句；`opt` 的句子正文没写就跳过；回话按钮（记号、灰着时的原因小字、`anchor` 登记与注销、`echo`）；说话的人 `stage.set_talking(who)`；发 `dialog_advanced` `dialog_skipped` `reply_chosen`；锚点 `a.dialog`（显示时）`a.dialog.next`。**这是第一个 PR，10-21 前合入**（C03、C05、C07、C08、C11 的演出都用它）。
- [ ] **CardCounterPanel 改成演出**（`extends CardStagePanel`）：`open({uid})` → `begin_play(uid)` → 没开柜台就 `counter.open`；`stage.set_items([{item, art}])`（来当来卖的东西；锚点 `a.counter.item` 用 `rect_fn` 取 `S_ITEMS` 的屏幕矩形）；`intro` 里 `#lines.ask` 的 `price` 参数补成 `CounterView.asking`；话说完列回话：三档价（`style: "tier"`，`ref` = `c04.tier.<tier>.<pay|receive>`，参数 `{n}` = `tiers.<tier>`，`anchor` = `a.counter.tier.<tier>`）、能细看时“细看”（`style: "look"`，`c04.reply.look`，`anchor: "a.counter.look"`；柜台上的放大镜热点经 `on_hotspot(&"magnifier")` 走同一条路）、人物牌的选项（`style: "choice"`，`<def>#choices.<id>`）、“不收”（`c04.reply.refuse` → `counter.refuse`）、“请他先等等，回头再说”（`style: "later"`，`c04.reply.later` → `dismiss()` = `counter.close`）；出价 → `counter.offer` → 按 `reply` 接 `CardStageScript.lines(script, "accept"|"counter"|"leave")`（`counter` 的 `price` 参数 = `last_price`；显示客人回话那一句时登记 `a.counter.reply`），还价时回话换成“接”/“不接”（`c04.reply.accept` `c04.reply.decline` → `counter.answer`）；`line_key` 是不耐烦的那句时接 `after.impatient`；细看玩完（`mg.report` 后 `view_changed`）把新观察一句一句说出来（narr，`ref` = 观察键，`CardText.obs`）；来买：回话“从货架上挑一件”（`c04.reply.pick`）→ `host` 开 `shelf {pick_for: uid}`，挑了以后东西摆上柜台、再列三档价；来赎：`prop.ticket` 在 `counter_left`、回话“照规矩”“刁难”（东西卖了换成“赔钱”“去买回来”，第一句带 `anchor: "a.counter.redeem"`）→ `counter.redeem`；成交后说 `c04.result.ticket`（`{n}` 当票号）或 `c04.result.shelved`，客人出门（`after.leave` 的默认里有 `w0.stage.leave`）后收场。
- [ ] **CardShelfDrawer**（新：`scenes/cards/counter/ShelfDrawer.tscn` + `scripts/cards/ui/counter/shelf_drawer.gd`，`class_name CardShelfDrawer`，kind `shelf`，右抽屉）：`query("stock")` 的物品格（图 ×1、名字 `CardText.item_text`、类别、成色档的字），`n/上限`；`args.pick_for` 不空时是“挑一件”：点一件 → `send("counter.pick_stock", {uid: pick_for, item})` → 收回（锚点 `a.counter.stock`）；否则只读（锚点 `a.shelf.list`）。
- [ ] **CardTicketsDrawer**（新：`scenes/cards/counter/TicketsDrawer.tscn` + `scripts/cards/ui/counter/tickets_drawer.gd`，`class_name CardTicketsDrawer`，kind `tickets`，右抽屉）：`view.tickets` 每张一行：当票号 `g04.ticket.number`、谁当的、东西、当本、剩几天（数字）；外来当票标出来；只读；锚点 `a.tickets.list`。
- [ ] `autoplay_step()`：对话框没说完先 `skip()`；其余照 1.2 的顺序（开柜台 → 来买挑第一件 → 能细看就细看一次 → 还价就接 → 出公道 → 来赎照规矩），都走 `on_reply`。

**新增 / 作废的交付**

- 新增上面四个场景与脚本；界面键 `c04.reply.look` `c04.reply.refuse` `c04.reply.later` `c04.reply.accept` `c04.reply.decline` `c04.reply.pick` `c04.dialog.skip` `c04.shelf.title` `c04.shelf.count`（`{n}` `{cap}`）`c04.tickets.title` `c04.tickets.row`（`{n}` `{days}`）`c04.tickets.foreign`（原有的 `c04.tier.*` `c04.redeem.*` `c04.result.*` 照用）；夹具照旧，用画面根跑。
- **作废**：柜台面板的居中布局、面板里的货架网格（→ 货架抽屉的“挑一件”）、`c04.btn.*` 里被回话取代的那几个。

**锚点、界面事件、要证明的步骤**

- 锚点 `a.dialog` `a.dialog.next`（新）、`a.counter.*` 八个（不改名，位置见合同 §7.10.5）、`a.shelf.list` `a.tickets.list`（新）。
- 界面事件 `dialog_advanced` `dialog_skipped` `reply_chosen`（新）。
- 要证明的步骤不变：`gd.d1.look` `gd.d1.tiers` `gd.d1.buyer` `gd.redeem`（`gd.d1.ticket` 由 C01 证）。

**测试与截图**

- **新增** `C04_dialog|res://scripts/tests/cards/C04/test_dialog.gd|120|`（逐字：`chars_per_sec = 40` 时用 `_process(delta)` 推进的字数对；点一下先补全再下一句；`skip`；空行拆句；`opt` 且正文是草稿的句子被跳过；回话的 `enabled`/原因；回话锚点登记与注销；`echo`；三个界面事件；`set_max_bottom`；所有字来自 CardText）。
- `C04_pawn_sell` 等原有测试改成用画面根 + 夹具打出那张牌、点回话（断言 `mock.sent` 照旧）。
- **新增** `C04_drawers|res://scripts/tests/cards/C04/test_drawers.gd|120|`（货架只读与“挑一件”、当票抽屉）。
- 截图：客人走进门（一半）、开口那句、东西摆上柜台、三档价回话、还价、成交、来买开货架挑一件、来赎带当票、带选项的人物牌、细看之后的观察句、货架抽屉、当票抽屉各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 柜台的全部“和引擎说话”的逻辑（开柜台、三档价、还价、挑货、四种赎法、选项、拒绝、先不管、“算了” = `counter.close`）、自动一步、夹具与对 `mock.sent` 的断言都有效；要换的是画法（居中面板 → 对话框 + 柜台上的东西 + 抽屉）。

**日期**：对话框 **10-21**；柜台演出与两个抽屉 **10-27**（原 10-23）。

## 只能改这些文件

- `scenes/cards/counter/**`、`scripts/cards/ui/counter/**`
- 默认拥有：`scripts/tests/cards/C04/**`、`scripts/tests/cards/suites/C04.txt`、`data/cards/tags/C04.json`、`data/cards/ui_keys/C04.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、C01 的小游戏宿主、C12–C15 的小游戏、旧代码 `scripts/ui/counter_view.gd`）。
2. **不写最终内容**：客人台词、物品名字、观察句、当票上的字全由人写（`data/cards/text/**`），你只用键；不碰 `art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII，`.tscn` 不出现中文；新键只写键 + `brief`。
3. 不写颜色字面量；图只经 `CardArt`。
4. **隐藏信息**：任何时候界面上没有底价、真值、估价区间、真假、来路、耐心数字、成功机会、`%`；三档价只显示引擎给的金额；观察只显示观察句。
5. 不放规则：不自己算三档价、不判断客人接不接、不算轮数。
6. 不用随机影响结果；不加别的 `class_name`（1.3 加的 `CardDialogBox` `CardShelfDrawer` `CardTicketsDrawer` 除外）；不加 autoload/InputMap。
7. 不发 `first_time`；~~本任务没有 `ui_event` 要发~~（1.3：对话框发 `dialog_advanced` `dialog_skipped` `reply_chosen`）（开关面板的事件由 C01 的宿主发）。

## 接口

**用到**：指令 `counter.open {uid}` `counter.offer {uid, tier}` → `{reply, price}` `counter.answer {uid, accept}` → `{reply, price}` `counter.pick_stock {uid, item}` `counter.redeem {uid, mode}` → `{reply}` `counter.refuse {uid}` `counter.close {uid}` `mg.request {uid, item}` → `{kind, params}` `card.choose {uid, choice}`；查询 `counter {uid}`（CounterView：`uid person intent item asking tiers direction round last_reply last_price line_key can_appraise stock ticket`）、`card {uid}`（`choices`）、`stock`；总线 `view_changed` `card_left` `money_changed`（可以在面板上闪一下钱数）；`CardText.person_name/item_text/obs/card/ui`、`CardArt`、`CardTheme`、`CardAnchors`；1.3：`CardStagePanel` `CardStageScript`（W0）、`CardDialogApi`（你来实现）、`CardStageApi.set_items/set_talking`、`CardLayout`（`DIALOG` `S_ITEMS`）、`CardSettings.fast_anim()`（对话框速度由 C01 设）。

**提供（冻结）**：`CardCounterPanel`（`CardPanel` 接口；1.3 起 `extends CardStagePanel`）；1.3：`CardDialogBox`（`CardDialogApi` 的全部接口）、`CardShelfDrawer`（kind `shelf`）、`CardTicketsDrawer`（kind `tickets`）。

## 新手指引

- **必须登记的锚点**（`a.counter.*` 名字不变，1.3 位置变了）：`a.counter.item`（东西那块；1.3：柜上的东西）`a.counter.look`（~~“看看东西”按钮~~ “细看”那句回话）`a.counter.tier.harsh` `a.counter.tier.fair` `a.counter.tier.kind`（~~三个价钮~~ 三档价的回话）`a.counter.reply`（客人回话；1.3：那一句显示时的对话框正文）`a.counter.stock`（~~来买时的货架网格~~ 货架抽屉“挑一件”的格子）`a.counter.redeem`（来赎的几种办法；1.3：第一句办法回话）；1.3 加 `a.dialog`（对话框，显示时）`a.dialog.next`（“跳过”）`a.shelf.list`（货架抽屉）`a.tickets.list`（当票抽屉）。只在对应的东西显示时登记（例：不是来买就不登记 `a.counter.stock`）。
- **必须发的 ui_event**：~~无~~ 1.3：`dialog_advanced {uid}` `dialog_skipped {uid}` `reply_chosen {uid, reply}`（宿主发 `panel_opened {kind: "counter", show: "stage"}`）。
- **first-time**：不发；依赖 `counter` `buyer` `redeem` `ticket` `shelf` `mg.spot`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.d1.look`（第一次开柜台 → `a.counter.look`）、`gd.d1.tiers`（`after: gd.d1.look` → `a.counter.tier.fair`）、`gd.d1.buyer`（第一次开来买的柜台 → `a.counter.stock`）、`gd.redeem`（→ `a.counter.redeem`）；另用画面根证明 `gd.d1.ticket`（来当成交后第一张当票 → C01 的 `a.scene.ledger`，备用 `a.tab.tickets`）。
- **测试做法**：开 `counter` 面板（夹具），挂 `GuideOverlay.tscn`（`bind(mock, bus)` → `force(true)` → `skip_fades = true` → `load_steps(<本目录 guide_steps.json>)`），`bus.first_time.emit(&"counter", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.d1.look"`；点“看看东西”（1.3：“细看”回话；`mg.request` 成功 → `cmd:mg.request`）后完成，再证 `gd.d1.tiers`。夹具的 `guide_progress` 可以预填前面步骤的 `done`。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C04.txt`：

```
# C04 柜台（docs/handoff_cards/C04_counter.md）
C04_pawn_sell|res://scripts/tests/cards/C04/test_pawn_sell.gd|180|
C04_buy|res://scripts/tests/cards/C04/test_buy.gd|120|
C04_redeem|res://scripts/tests/cards/C04/test_redeem.gd|120|
C04_choices|res://scripts/tests/cards/C04/test_choices.gd|120|
C04_no_hidden|res://scripts/tests/cards/C04/test_no_hidden.gd|120|
C04_guide|res://scripts/tests/cards/C04/test_guide.gd|180|
C04_dialog|res://scripts/tests/cards/C04/test_dialog.gd|120|
C04_drawers|res://scripts/tests/cards/C04/test_drawers.gd|120|
```

（最后两行是 1.3 新增；原有测试 1.3 起都用画面根 + 夹具打出那张牌、点回话，断言 `mock.sent` 照旧，见上方“10-13 变更二”的“测试与截图”。）

| 测试 | 通过条件 |
|---|---|
| `test_pawn_sell.gd` | 来当、来卖各一条夹具走通：`counter.open` → `mg.request {uid, item}` → `counter.offer {uid, tier: "fair"}` → 还价时 `counter.answer {uid, accept: true}`；`mock.sent` 的顺序和参数完全对；回话显示的正文键是那张牌的 `lines.*`；最多 5 轮后体面结束（`leave` 后只剩“送客”） |
| `test_buy.gd` | 来买：~~货架网格~~（1.3：回话“从货架上挑一件” → 货架抽屉 `shelf {pick_for: uid}`）→ `counter.pick_stock {uid, item}` → 三档价~~按钮~~（回话）文字用 `receive` 那一套 |
| `test_redeem.gd` | 照规矩、刁难各发 `counter.redeem {uid, mode}`；东西已卖时只显示 `compensate` / `buy_back` |
| `test_choices.gd` | 人物牌的选项作~~额外按钮~~（1.3：回话）→ `card.choose {uid, choice}`；`enabled: false` 的灰且显示原因正文 |
| `test_no_hidden.gd` | 每个夹具打开后遍历所有 Label/Button/RichTextLabel：`t.all_text_from_cardtext()` 为空；没有 `%`；出现的数字只能是 `asking`、三档金额、`last_price`、当票号与当本与剩几天（逐个比对）；夹具本身 `t.no_leaks()` |
| `test_guide.gd` | 上面列的步骤按做法亮、完成；锚点 `t.anchor_ok()` |

另：`autoplay_step()` 能把每个夹具走完（返回 false 结束）；打开面板 ≤ 50 ms（PR 列数）。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集，第 1 天三位客人各开一次柜台走完，`ledger` 没有报错）；清单加一行 `C04_guide_k16|res://scripts/tests/cards/C04/test_guide.gd|180|--steps=k16 --name=C04_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C04 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C04/shot_counter.gd -- --out=/tmp/shots/C04
  ```
- **截图**（不进清单）：~~每个夹具一张 `C04_<夹具>.png`（来当、看过东西有观察、还价中、走人、来卖、来买挑货、来赎两种、带选项）~~（10-13 作废，合同 1.3：清单见上方“10-13 变更二”的“测试与截图”），`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图；上传 PR 或提交到 `scripts/tests/cards/C04/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：~~面板居中 ≤ 1100×640~~（10-13 作废，合同 1.3：柜台是演出，对话框在 `DIALOG`，东西在 `S_ITEMS`，两个抽屉是右抽屉 388×630）；头像、物品整数倍放大、NEAREST；~~价钮三个并排、大小一样，`fair` 默认焦点；键盘：1/2/3 选三档（只在面板里）、L 看看东西~~（10-13 作废，合同 1.3：三档价是回话，1–9 选第 N 句回话由 C01 的根转发）、Enter 确认、Esc 先不管（`counter.close`）。

## 交付

- PR 标题 `[C04] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议（1.3）：①对话框 `CardDialogBox` + `C04_dialog`（10-21 前合入，别人的演出在等）；②柜台那一出（来当/来卖 + 三档价、来买、来赎、选项）+ 两个抽屉 + 截图（10-27）；~~①来当/来卖 + 三档价 + 测试；②来买、来赎、选项、截图~~；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；新公开函数（无，或列出）；需要决定的事（`ticket.status` 的取值）；性能数；“回报”。

## 审核（Claude 重点）

- 任何状态下界面上都没有底价、真假、估价区间、耐心数字、`%`（逐个截图看）。
- 指令参数和顺序对；`mg.request` 带 `item`；不在总线回调里同步 `send()`。
- 回话台词来自那张人物牌的 `lines.*`；观察只用 `CardText.obs`。
- `W0_table_3days` 第 1 天仍能走完。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / 证明会亮的步骤 | |
| 新加的公开函数 | |
| 性能实测 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
