# G04 `economy` · 柜台、货架、当票、鉴定桥、物品、货币、月账

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.2 G04 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] G04: …` issue。

> **鉴定改版（主创 10-25：“你那个鉴定不能只是点点点，要玩家看出来才算数”）**：本卡下文凡和合同 §3.3、§4.8、§8、附录 H 对不上的，以合同为准。CardAppraisal 多了私账答案 `econ.appraisals[uid].answer`、`judge` / `record` / `reading` / `doc_params`、说破（Level B）、文书 `econ.readings` 与条件 op `mg_read`、眼力与人脉辅助；柜台 `tier_err` / `accept_err`（付不起的价不再念成成交）。

## 执行者与线号

- 执行者：**GPT**
- 线号：**GPT 线 4**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 你的类、指令、查询、效果/条件 op 都已登记成桩；`card_ledger.gd` 已 `extends "res://scripts/core/ledger.gd"`、覆盖了三个函数的骨架；`CardItems.templates()`、`CardShelf.cap()` 能用 | W0（已完成） |
| G01 | `CardPiles`、`CardFirsts`、`ctx.draw` | W1（先合） |
| G03 | 人物牌的 `choices` 经 `card.choose`（你只在柜台上把它们当按钮列出来）；修正项 `patience_pct`、`appraise_pct` | W1（在你之前合） |
| G06 | 修正项 `intake_blocked`（首饰柜押出）、`cap {zone: shelf}`（库房押出）；接你的 `money_short` 钩子 | W1（在你之后合） |
| K11 | 物品 → 小游戏参数（`data/cards/minigames/items.json`）、`templates_extra.json`——**对着 `_examples` 先做** | W1 数据线 |

- **你所在的波次**：W1；合并顺序 G01 → G03 → **G04/G05**（你和 G05 并列）→ G06 阶梯 → G02。
- **W2**：K11 的首发约 40 件物品的真数据；三关浸泡账本守恒；W2 起 C04/C12–C15 对真引擎联调。

## 分支

`cards/G04-economy`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase` 跟上。

## 目标

做出铺子的钱货流：柜台（当、卖、买、赎、拒，三档价，客人接受/还价/走，最多 5 轮，耐心只用台词体现）；货架（只能卖给来买的人）；当票（倒计时、赎当四种、满当、外来当票只记录）；鉴定桥（挑小游戏、把物品真值换成**物理参数**、收观察键、定清晰度、扣耐心——**永不给真假结论**）；物品生成（只存清洗过的整数字段）；货币与物价；月底开销。账本守恒、无浮点、无中文进状态。

## 必读

1. 合同 §0（红线 3、5）、§2.2、§2.3（`ledger.gd` 继承、`ItemGen`、`appraise.gd` 只读）、§3.2 G04、§4.6（`economy.json`）、§4.7.1（person：`intent` `item` `want` `asking` `floor` `patience_min` `impatience` `term_days` `minigame`）、§4.7.15（item → 小游戏参数）、§4.7.16（主线当票）、§4.8（观察键目录）、§5.2–§5.3 里归 G04 的 op、§6（`econ` 命名空间、随机写法、域表）、§7.3（修正项与钩子表里归 G04 的行，`money_short` 钩子）、§7.4（`counter.*` `mg.*` 指令、`counter`/`stock`/`tickets` 查询、§7.4.3、§7.4.6 查封与来赎）、§7.5（CounterView、ItemView、TicketView、黑名单）、§7.9 G04 段、**§8 全章**（小游戏接口、§8.2 参数与禁用键）、§9.4（黄历动作谁记）、§7.10.10、§12、§13–§14。
2. `docs/cards/DESIGN_cards.md` §三.1（柜台）、§三.2（鉴定小游戏）、文末“实现时的理解”第 8 条；`docs/town/cards/src/era.json` 的 `notes`（当期、月息二到三分、保管费约五厘、跨年满当、吹银元、银元按枚计价、法币）。
3. W0 代码：`scripts/cards/economy/*.gd`（你的起点）、`scripts/cards/api/card_minigame.gd`（小游戏结果格式）、`scripts/cards/mock/mock_scenario.gd` 的 `spot_layout()`（**找不同布局怎么从 ItemGen 转成 §8.2 的格式——照它的输出格式做，不要 preload Mock**）、`scripts/cards/mock/example_minigame.gd`（小游戏怎么读参数）、`scripts/cards/core/card_piles.gd`（`resolve` 的 `extra.almanac`）。
4. 只读复用：`scripts/core/ledger.gd`（`transfer` `add_item` `move_item` `open_pawn` `redeem_amount` `redeem` `tick_contracts` `check_invariants` `to_dict/from_dict`——**不改它**，你的 `card_ledger.gd` 继承并覆盖 `open_pawn`、`redeem_amount`、`tick_contracts`）、`scripts/sim/item_gen.gd`（`ItemGen.generate(templates, pack, s, key, category)`；它的 `s` 里会写浮点缓存、`name` 等中文——**只给它一个临时字典，用完丢掉**）、`data/town/item_templates.json`（只读）、`scripts/core/appraise.gd`（只看部位与痕迹的数据形状，不用它的提示句）。
5. 数据：`data/cards/rules/economy.json`（你的）、`data/cards/_examples/{era/1938/people.json, era/common/passersby.json, minigames/items.json, items/templates_extra.json}`。

## 要做的事

### A. 账本与货币（`card_ledger.gd`、`currency.gd`）
- [ ] `card_ledger.gd`（`extends "res://scripts/core/ledger.gd"`，**不写 `class_name`**）覆盖三个函数：`open_pawn` → 合同 id ASCII `t%04d`、当票号是整数、月息整数 `rate_pct`、保管费整数 `storage_permille`、原因码 ASCII（父类写中文当号和浮点月息）；`redeem_amount` → 全整数运算（本金 + 本金 × `rate_pct` × 月数 ÷ 100 + 保管费）；`tick_contracts` → 宽限天数读 `economy.json.ticket.grace_days`、原因码 ASCII。
- [ ] 账本挂到 `ctx.ledger`；`econ.ledger` = 账本 `to_dict()`，读档 `from_dict()`；里面不许有浮点、不许有中文（测试用 `find_floats` 和 CJK 检查）。
- [ ] `CardCurrency`：`money(ctx)`（玩家现金）、`apply_stage(stage)`（`stage_start` 10：币种、物价指数、首局起始钱 `start_money`）、`convert(to, num, den)`（钱和账上一切按 num/den 换算，同步调整总量，守恒）。首发三关不换币。

### B. 物品（`items.gd`）
- [ ] `generate(ctx, key, template_or_cat)`：调 `ItemGen.generate(CardItems.templates(), <pack>, <临时 s>, key, cat)`，`key` 第一个元素固定 `"c"`（随机域 `item_*`）；`<pack>` 从你的 `data/cards/rules/items_balance.json` **在运行时**拼出来——规则文件里只许整数（千分比、整数区间）和 ASCII id，代码里再换成 ItemGen 要的浮点；**不读 `data/town/town_pack.json`**（它不进 Steam 包）。
- [ ] 进状态的只有清洗过的整数字段（`econ.items_meta[I…] = {template, cat, condition_permille, …}`，真值、真假这类隐藏信息可以存在 `econ` 里，但只用整数/布尔/ASCII 串）；不存 ItemGen 的浮点（`condition` `ask_w`…）、中文（`name` `cat_cn`…）、原始缓存。物品文字由 `CardText.item_text(template, field)` 取（人写的 `items.text.json`）。

### C. 柜台（`counter.gd`、`pricing.gd`、`customer.gd`）
- [ ] `counter.open {uid}`（来意 `pawn sell buy redeem` 的人物牌）：建 `econ.sessions[uid]`（轮次、剩余耐心分钟、报价……全整数）；客人报价 `c.cust.asking`、底线 `c.cust.floor`、耐心 `c.cust.patience`、要哪类 `c.cust.want`（键 `[abs_day, uid]`）；修正项 `intake_blocked {cat}` 为真（首饰柜押出）→ 客人被挡（回话键说铺子不收），这笔不成；返回 CounterView。
- [ ] `CardPricing.tiers(uid)` → `{harsh, fair, kind, direction}`：**只从客人开口报的价和“看得见的估计”算**（`economy.json.tiers.pay/receive` 的整数百分比 × 修正项 `price_pct`），不露真值、底价、估价区间。“看得见的估计”具体怎么算合同没写：按最保守的做法用玩家看得见的东西（模板基价 × 物价指数 × 成色档），标 `# TODO(design)` 写进 PR。
- [ ] `counter.offer {uid, tier}` → `{reply:"accept"/"counter"/"leave", price}`：`CardCustomer.reply()`（`c.cust.reply [abs_day, uid, round]`，按隐藏底线与剩余耐心）；还价 `counter.answer {uid, accept}`；最多 `max_rounds` 轮后体面结束；讲价与小游戏扣耐心（`patience.offer_min` / `counter_min`、小游戏的 `minutes`，乘修正项 `patience_pct`），耐心尽了按牌的 `impatience`（`leave` / `raise`）。
- [ ] 成交：来当 → 开当票（`CardTickets.open`）、付当本、物品入库；来卖 → 收货上货架；来买 → `counter.pick_stock {uid, item}` 从货架挑（只卖他要的类别）、收钱；每笔走账本 `transfer`，发 `money_changed(old, new, reason_key)`；牌 `CardPiles.resolve(ctx, uid, &"resolved", {"almanac": [...]})`，自动记黄历动作：`pawn_in`（收当成交）`buy_in`（收货成交）`sell_out`（卖给来买的人）`redeem`（赎当）`trade`（任何柜台成交）。执行牌的 `on_accept`/`on_refuse`/`on_leave`。
- [ ] `counter.refuse`（拒绝也算处理，执行 `on_refuse`、`resolve(…, &"refused")`）；`counter.close`（不处理，牌留在手上）。
- [ ] 人物牌上的 `choices`（例“白给他几个钱”）：只在 CounterView 里给出可选项（来自 `CardChoices.options`），选择走 G03 的 `card.choose`，你不执行。
- [ ] 来赎 `counter.redeem {uid, mode}`：`by_rule` 照规矩；`squeeze` 刁难（多收 `redeem.squeeze_pct`，口碑/本心后果经 G03 的 op）；东西已经被你卖掉时才可用的 `compensate`（按当本赔 `compensate_pct`）与 `buy_back`（去买回来）。
- [ ] 查询 `counter {uid}` → CounterView（§7.5：`uid person intent item asking tiers direction round last_reply last_price line_key can_appraise stock ticket`），**没有底价、真假、估价区间、耐心数**；回话台词键来自那张人物牌的 `lines.*`（`line_key` 形如 `<def>#lines.counter`）。

### D. 货架与当票（`shelf.gd`、`tickets.gd`）
- [ ] `CardShelf`：`items/cap/add/remove/view`；上限 `shelf_cap` + 修正项 `cap {zone: shelf}`；价格修正（`price_mod` op 记进 `econ.price_mods`，到期在 `day_start` 40 清）；只能卖给来买的人。ItemView：`{item, template, cat, art, condition_word(0–4), observations, on_shelf_since}`。
- [ ] `CardTickets`：`open(uid, item_id, principal, term_days)` 返回整数当票号；`tick()`（`settle` 10：倒计时、逾期、宽限后满当，用 `notice` 事件报给日结）；`forfeit_all()`（`year_jump` 10：跨年全部满当）；`view()` → TicketView `{no, person, item, principal, days_left, status, foreign}`。
- [ ] 外来当票（`tk.*`，如“德字第一九六号”）：只记录不动钱（`econ.foreign_tickets`，`foreign: true`）；当票号显示用界面键 `g04.ticket.number`（参数 `{n}`）。
- [ ] 来赎的人（`day_start` 40）：到期的当票 `c.redeem.come [ticket_no, abs_day]` × `come_den` < `come_num` 决定今天来不来；主要人物用自己的 `redeem` 牌，其他人用系统牌 `p.any.redeem`（K01 定义；`vars` 里带当票号）；查封期间不来（当票照样倒计时）。

### E. 鉴定桥（`appraisal.gd`，§8）
- [ ] `mg.request {uid, item}`：挑小游戏——牌上写了 `minigame`（只有教学人物牌、当票、电报/信）就用它，**一定生效**；否则按物品的 `it.*`（K11）里的 `minigames` 用 `c.mg.pick [abs_day, uid, item_id]` 挑；没有物品的牌（当票、电报）`item` 为空，用牌上的 `minigame`，没有就 `no_minigame`。发 `minigame_requested(uid, item, kind, params)`；返回 `{kind, params}`；第一次出每种小游戏记对应 first。
- [ ] `params_for(item_id, kind)`：公共字段 `{kind, seed, item, art, minutes_per_step, max_minutes}`，`seed = int(u × 2147483647)`，`u = ctx.draw("c.mg.param", [item_id, kind, "seed"])`；专有参数按 §8.2 表——**只有物理量和摆设**：`spot` 只给布局（`parts:[{id, rect, tool}]`、`marks:[{part, kind:"differs"/"wear", fine, seed}]`、`atlas_art`、`ink`、`tools`、`atlas_open`，格式同 Mock 的 `spot_layout()`）；`coin_ring`（`ring_ms` `pitch_cents` `buzz`，按 `it.*` 的 `*_good`/`*_bad` 规格与物品真值算）；`weigh`（`claimed_fen` `actual_fen` `weights_fen` `resolution_fen`，整数“分”）；`fragments`；`decode`（码来自 K11 的 `codebook.json`）。物理量抽签用 `c.mg.param [item_id, kind, i]`。
- [ ] **禁用键**：参数递归不许出现 `CardAppraisal.FORBIDDEN_PARAM_KEYS`（`fake real genuine authentic forged stolen origin market value true_value floor tell benign fake_text real_text est verdict rare grade quality`），**没有例外，`spot` 也一样**。
- [ ] `mg.report {uid, item, result}`：`quality_permille` × 修正项 `appraise_pct` ÷ 100，按 `economy.json.appraise`（≥ `clear_permille` 清楚、≥ `partial_permille` 一半、其余含糊）定这次观察的清晰度；只收在那个小游戏观察目录里、清晰度相符的观察键（不认识的键丢掉）；记到 `econ.items_meta[item].observations`；`minutes` 从客人耐心里扣；返回 `{observations}`。**不决定真假、不影响价格**。

### F. 效果 op 与条件 op
- [ ] 效果：`money {delta, reason}`（花不起按 `partial`）· `pay {amount, payee, reason, short}`（`ladder` → 触发钩子 `money_short {amount, payee, source}`，G06 接手；`partial` 付光为止；`fail` 一分不付并执行同一张牌的 `on_short`）· `item_gain` · `item_lose {match, n, reason}` · `shop_closed {days}`（`econ.shop_closed_until`；第一次记 first `shop_closed`）· `price_mod` · `currency_convert`。
- [ ] 条件：`money_gte` `money_lt` `stock_cat_gte` `stock_has` `ticket_open` `currency`。
- [ ] 每个 op 正例 + 形状反例。

### G. 修正项、钩子、视图
- [ ] 提供：`price_pct {direction, cat, item_id}`（`price_mod`）；`deal_count {type, abs_day}`（查封期间对 `person` 返回足够大的负数，G01 夹到 0——“查封：这几天不随机抽人物牌”）；`view_section`（`money {amount, currency}`、`shelf_count`、`tickets`）；`card_view_part`（`item`、`asking`、`observations`、`can_appraise`，当票相关牌的 `days_left`）。
- [ ] 用到：`intake_blocked`（G06）、`cap`（G06）、`patience_pct`、`appraise_pct`（G03）、`price_pct`（G05 也提供运势）。
- [ ] 钩子监听（§7.3）：`stage_start` 10 · `day_start` 40 · `settle` 10 · `month_close` 10（`CardMonthAccounts.close`：月底开销、当票清点；抵押利息归 G06）· `year_jump` 10（满当）· `year_jump` 20（换币、物价）。要进报告的事用 `notice` 事件发（G02 收进日结/月底报告）。
- [ ] 触发：`money_short`。

- [ ] **查询结果的形状和 Mock 一样**：界面任务是对着 `MockCardEngine`（`scripts/cards/mock/mock_scenario.gd` 的 `query()` 与十个夹具）写的，W2 换真引擎时形状必须一致。合同 §7.4 表里写成数组的查询，`query()` 只能返回字典，按 Mock 的包装键：`stock` → `{"items": [ItemView]}`、`tickets` → `{"tickets": [TicketView]}`；`counter` 直接返回 CounterView。

### H. 数据与键
- [ ] `data/cards/rules/economy.json`：只改数（月底开销等需要新键时，同步请 G01 更新 `RULE_KEYS`）；新建 `currency.json`（币种与换算，首发只有 `fabi`）、`items_balance.json`（ItemGen 的平衡参数，整数版）：`_meta.owner` 写 `G04`，`_doc` 写说明，开 `[shared] G04→G01` 登记必需键。
- [ ] `data/cards/ui_keys/G04.json`：`g04.reason.*`（`pawn_out` `sell_in` `buy_out` `redeem_in` `interest` `fee` `compensate` …）、`g04.ticket.number`、`g04.cond.0`–`g04.cond.4`（成色档）、`g04.counter.*`（铺子不收这一类等）、`g04.month.*`；只写 `brief`；`_meta._provenance = {"by":"ai","task":"G04","date":"<提交当天>"}`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] `day_end` 8：开着的柜台会话全部关掉（客人走了，不算成交，不扣钱、不发当票）；人物牌本身由 G02 在 `day_end` 10 按 `leave` 结算（记仇的执行它的 `on_expire`）。
- [ ] 来赎的人没接：当票照旧（之后按 `c.redeem.come` 还可能再来）。
- [ ] `shop_closed {days}` op 也给 G06 用：牢里过夜的第二天铺子关门（不随机发人物牌、来赎的不来，§7.4.6 “在牢里”一列）。
- [ ] 测试 `test_end_day.gd`（清单 `G04_end_day`）：柜台开着、出过价就打烊 → 会话没了、钱和货架没变、没有当票；`shop_closed 1` 后第二天没有随机人物牌、没有来赎的。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**合同 1.3 不影响本任务**：1.3 只改界面这一层：柜台那一出用的还是 CounterView 和 `counter.*` 指令（G04）；自动玩只用 `send/view/query`、不建界面（G06）；视图里的 `stage.set == "prison"` 由 G02 读你的 `ladder.prison.uid` 算（G06 不用做什么）。

- 另外两处也不用你做什么：视图里的 `stage.sealed`（今天被查封）由 G02 只读你的 `econ.shop_closed_until` 算；“细看”从柜台那一出的回话或柜台上的放大镜发，还是 `mg.request`。
- 上文“新手指引”一节里的旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`gd.d1.ticket` → 柜台上的账簿 `a.scene.ledger`、备 `a.tab.tickets`；`gd.d1.shelf` → 右边的标签 `a.tab.shelf`；`gd.shop_closed` → 门边的告示 `a.scene.notice`），你发的 first 和测试不用为此改。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `scripts/cards/economy/**`（含 `.uid`）
- `data/cards/rules/economy.json`、`data/cards/rules/currency.json`、`data/cards/rules/items_balance.json`
- 默认拥有：`scripts/tests/cards/G04/**`、`scripts/tests/cards/suites/G04.txt`、`data/cards/tags/G04.json`、`data/cards/ui_keys/G04.json`

## 不能做的事

- **不写玩家最终内容**：不碰 `data/cards/text/**`（含 `items.text.json`）、`art/cards/**`、`audio/cards/**`、`palette.json`、`legal/**`、`fonts/**`；物品名、客人台词、观察句都由人写；测试夹具“正文”只用 ASCII 假字。
- **不改 `scripts/core/ledger.gd`、`scripts/sim/item_gen.gd`、`data/town/item_templates.json`、`scripts/core/appraise.gd`、`scripts/ui/appraise_panel.gd`**（只读复用）；不读 `data/town/town_pack.json`；不引用旧的中文提示句（`appraise.gd` 的 `hit_note`、`appraise_panel.gd` 的判词）。
- **鉴定只给观察，不给结论**：参数里没有禁用键；结果没有真/假/仿；`quality_permille` 不影响价格。
- 视图、查询、事件里没有底价、真值、估价区间、耐心数、`pct`、`floor`、`value`、`est`、`quality` 等黑名单键；界面上不出现百分比——三档价给钱数。
- 只写 `econ` 命名空间；牌的去留经 `CardPiles`，口碑/本心经 G03 的 op（`ctx.run`）。
- 随机只用 `c.cust.*` `c.redeem.come` `c.mg.pick` `c.mg.param` 和 ItemGen 的 `item_*`（键首 `"c"`）；不用 `randf/Time/OS.get_ticks*`；状态里没有浮点、没有中文。
- 不改 `api/**`、`mock/**`、`tests/cards/lib/**`、`tools/run_*.sh`、`project.godot`；不加 `class_name`（`card_ledger.gd` 尤其不许）；引擎代码不连 `ui_event`；不自己加玩法。

## 接口

**提供（冻结签名，§7.9 G04 段）**：`CardCounter`（`open offer answer pick_stock redeem refuse close view`）· `CardPricing.tiers` · `CardCustomer`（`reply spend_patience`）· `CardShelf`（`items cap add remove view`）· `CardTickets`（`open tick forfeit_all view`）· `CardAppraisal`（`FORBIDDEN_PARAM_KEYS request params_for report`）· `CardItems`（`generate templates`）· `CardCurrency`（`apply_stage convert money`）· `CardMonthAccounts.close` · `CardEconomyInstall.install`。

**登记（`CardEconomyInstall.install`）**：
- 指令：`counter.open` `counter.offer` `counter.answer` `counter.pick_stock` `counter.redeem` `counter.refuse` `counter.close` `mg.request` `mg.report`
- 查询：`counter` `stock` `tickets`
- 效果 op：`money` `pay` `item_gain` `item_lose` `shop_closed` `price_mod` `currency_convert`；条件 op：`money_gte` `money_lt` `stock_cat_gte` `stock_has` `ticket_open` `currency`
- 修正项提供：`price_pct` `deal_count`（查封）`view_section` `card_view_part`
- 钩子监听：`stage_start` 10 · `day_start` 40 · `settle` 10 · `month_close` 10 · `year_jump` 10 · `year_jump` 20；触发 `money_short`
- 随机数域：`c.cust.asking` `c.cust.floor` `c.cust.patience` `c.cust.want` `[abs_day, uid]` · `c.cust.reply` `[abs_day, uid, round]` · `c.redeem.come` `[ticket_no, abs_day]` · `c.mg.pick` `[abs_day, uid, item_id]` · `c.mg.param` `[item_id, kind, i]`（`i = "seed"` 抽布局种子）· `item_*`（`["c", abs_day, uid, …]`）

**给小游戏的契约（C12–C15 照它做）**：参数格式 §8.2；结果 `{quality_permille:int, observations:[key], minutes:int, measures:{}, aborted:bool}`；观察键目录 `data/cards/minigames/obs/<kind>.json`（各小游戏任务的）。

## 新手指引

- **锚点**：引擎不登记锚点；CounterView 的字段（`item` `can_appraise` `tiers` `last_reply` `stock` `ticket`）是 C04 的锚点 `a.counter.item/look/tier.*/reply/stock/redeem` 能不能显示的前提，`tickets`、`shelf_count` 是 ~~C01 `a.right.tickets`/`a.right.shelf`~~（10-13 作废，合同 1.3：C01 两侧标签的角标 `a.tab.tickets` `a.tab.shelf` 与 C04 的当票、货架抽屉 `a.tickets.list` `a.shelf.list`）的前提，务必准确。
- **你必须发的 first-time**：

| 机制 | 什么时候 mark | args | 对应步骤（教的人 · 锚点） |
|---|---|---|---|
| `counter` | 第一次 `counter.open` 成功 | `{uid, person}` | `gd.d1.look`，再 `gd.d1.tiers`（brother · `a.counter.look`；`a.counter.tier.fair`） |
| `mg.spot` | 第一次 `mg.request` 出找不同 | `{uid, kind}` | `gd.d1.spot`（brother · `a.mg.spot.atlas` 备 `a.mg.spot.main`） |
| `ticket` | 第一张当票开出 | `{no}` | `gd.d1.ticket`（brother · `a.scene.ledger` 备 `a.tab.tickets`） |
| `shelf` | 第一件东西上货架 | `{}` | `gd.d1.shelf`（brother · `a.tab.shelf`） |
| `buyer` | 第一次打开来买的客人的柜台（`counter.open`，`intent: buy`） | `{uid, person}` | `gd.d1.buyer`（brother · `a.counter.stock`） |
| `redeem` | 第一次打开来赎的柜台（`counter.open`，`intent: redeem`） | `{uid, person}` | `gd.redeem`（obj.brother_ledger · `a.counter.redeem`） |
| `shop_closed` | 第一次被查封（`shop_closed` op） | `{}` | `gd.shop_closed`（obj.notice · `a.scene.notice`） |
| `mg.coin_ring` / `mg.weigh` / `mg.fragments` / `mg.decode` | 第一次出这种小游戏 | `{uid, kind}` | `gd.mg.coin_ring` `gd.mg.weigh` `gd.mg.fragments`（obj.brother_ledger）· `gd.mg.decode`（postman） |
| `currency` | **预留**：第一次换币（首发三关不换币，不会发生） | `{}` | `gd.currency` |

- **你支持的步骤**：上表全部；第 1 天的 `gd.d1.look → gd.d1.spot → gd.d1.tiers → gd.d1.ticket → gd.d1.shelf → gd.d1.buyer` 全靠你（教学客人：来当的牌带 `minigame: "spot"`，**一定**出找不同；来卖的东西上货架；来买的要货架上那一类）。
- **指引验收（必须有测试）**：上表每个机制恰好一次、第二次不发、存→读后不发、`args` 只含白名单键；用 W0 夹具同款的教学客人（`weight: 0` + `schedule` + `minigame: "spot"`，放你测试目录的夹具里）走一遍第 1 天的柜台：先后发出 `counter` → `mg.spot` → `ticket` → `shelf` → `buyer`；不管种子是什么，`minigame` 那张牌出的都是 `spot`（跑 50 个种子）。
- **截图**：本任务无界面，不交截图（步骤截图由 C16、K14 出；柜台那一出的画面截图由 C04 出）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/G04.txt`：

```
# 名字|脚本|超时秒|参数
G04_ledger|res://scripts/tests/cards/G04/test_ledger.gd|120|
G04_items|res://scripts/tests/cards/G04/test_items.gd|120|--seeds=50
G04_counter|res://scripts/tests/cards/G04/test_counter.gd|180|
G04_pricing_customer|res://scripts/tests/cards/G04/test_pricing_customer.gd|120|--seeds=50
G04_shelf_tickets|res://scripts/tests/cards/G04/test_shelf_tickets.gd|120|
G04_redeem|res://scripts/tests/cards/G04/test_redeem.gd|120|
G04_appraisal_params|res://scripts/tests/cards/G04/test_appraisal_params.gd|180|--seeds=20
G04_appraisal_report|res://scripts/tests/cards/G04/test_appraisal_report.gd|120|
G04_ops_conds|res://scripts/tests/cards/G04/test_ops_conds.gd|120|
G04_soak_invariants|res://scripts/tests/cards/G04/test_soak_invariants.gd|300|--seeds=10
G04_determinism_save|res://scripts/tests/cards/G04/test_determinism_save.gd|180|
G04_firsts|res://scripts/tests/cards/G04/test_firsts.gd|120|
G04_end_day|res://scripts/tests/cards/G04/test_end_day.gd|120|
```

**每条必须证明的事（合同 §3.2 G04 验收 + §12.2）**：
- [ ] 账本守恒：`ledger.check_invariants()` 在三关浸泡（W1 用你自己的测试驱动逐天触发你的钩子；G02 合入后改走真引擎）里每天为空；换币时同步调整总量。
- [ ] 三档价、还价、耐心走人（`leave`）与涨价（`raise`）；最多 5 轮后体面结束；拒绝也算处理。
- [ ] 传给小游戏的参数：**对每个物品（例子集 + W2 起 K11 的全部）× 它能出的每种小游戏**递归检查，没有一个禁用键（**没有例外**，`spot` 也一样）；同物品同种类参数可复现。
- [ ] `mg.report`：清晰度按 `quality_permille × appraise_pct` 分三档；不在目录里的键被丢掉；没有判词；扣了耐心；不影响价格。
- [ ] 首饰柜押出后（测试里登记一个返回真的 `intake_blocked` 替身；G06 合入后用真的）来当首饰的被挡（客人说铺子不收）。
- [ ] 当票号是整数、合同 id 是 ASCII（`t0001`…）；`econ` 里没有浮点（`find_floats`）和中文（CJK 正则）。
- [ ] 赎当四种办法；`compensate`/`buy_back` 只在东西已被卖掉时可用；跨年满当；外来当票不动钱。
- [ ] 人物牌的选项在柜台上走得通（CounterView 列出来，`card.choose` 交给 G03）。
- [ ] 教学客人牌上的 `minigame` 一定生效。
- [ ] 视图、查询（`counter` `stock` `tickets`）、事件参数递归无黑名单键；CounterView 里没有底价、真假、估价区间。
- [ ] 确定性：同种子同指令两遍哈希一样；`morning`/`month_open` 存→读→继续一致；随机域只用 G04 的。
- [ ] “新手指引”一节的验收。

**W1 测试替身**：G06 的 `intake_blocked`/`cap`、G02 的日循环还是桩：单测里另建 `CardCtx` 登记假提供者，逐天直接 `ctx.hooks.fire(...)` 驱动你的监听；不要等。

**性能**（bench `scripts/tests/cards/G04/bench_economy.gd`，不进清单）：`counter.*`/`mg.*` 普通 `send()` ≤ 2 ms；`settle` 10 的当票倒计时 ≤ 2 ms；存档里 `econ` 的大小（三关末）在总预算 512 KB 内。

**怎么跑**：
```
GODOT=<你的 Godot 4.7> CARDS_SUITES=G04 tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；日志没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有泄漏；每个清单测试最后一行 `CARDS TEST PASS <名字>`；G06 黄金种子（合入后）不变或已解释。旧版冒烟必须绿——它证明你没碰坏 `ledger.gd`/`ItemGen` 的旧用户。

**截图**：无（本任务无界面）。

## 交付

- **PR 标题**：`[G04] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[G04] 账本（card_ledger 整数化）、货币、物品清洗`
  2. `[G04] 柜台：三档价、客人回话与耐心、当卖买拒、货架`
  3. `[G04] 当票与赎当四种、来赎的人、满当、外来当票`
  4. `[G04] 鉴定桥：挑小游戏、物理参数、观察与清晰度；first-time 收尾`
- **PR 描述**按模板填满，另外必须有：改动路径；用到的随机域；发的 first-time 及位置；新加的公开函数（如有）；`items_balance.json` 与旧 `town_pack.json` 的对应表（哪些浮点换成了千分比）；“看得见的估计”怎么算；禁用键检查覆盖了哪些物品 × 小游戏；账本守恒浸泡的种子数；黄金哈希变化说明；bench 数；需要主创/编排决定的事；完成时写“交付”。

## 审核（Claude 会逐条看）

1. 越界：只动 G04 路径；`ledger.gd`、`item_gen.gd`、`item_templates.json`、`appraise*.gd` 一字未改；没读 `town_pack.json`。
2. `card_ledger.gd` 没有 `class_name`、只覆盖三个函数、全整数、ASCII id 与原因码。
3. 隐藏信息：CounterView/ItemView/TicketView 无黑名单键；三档价只从报价和看得见的估计来。
4. **鉴定红线**：参数无禁用键（抽查 `spot` 的 `marks` 只有 `part kind fine seed`）；结果无判词；清晰度不影响价格。
5. 账本守恒、无浮点、无中文进状态。
6. 黄历动作在成交时带上；`money_short` 只在 `short:"ladder"` 时触发。
7. 查封：不随机发人物牌、来赎的人不来、当票照样倒计时。
8. 新手指引：第 1 天教学客人一定出找不同；12 个 first 的记录点与参数。
9. 确定性、存读一致；函数 ≤ 80 行。
10. 免 AI 声明：只有键和 brief；`.gd` 字面量无中文。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 禁用键检查覆盖（物品数 × 小游戏种类） | |
| 账本守恒浸泡（种子数、天数、结果） | |
| bench 数 | |
| 用到的随机域 | |
| 发的 first-time 及位置 | |
| 新加的公开函数 | |
| 开的 issue | |
| 悬空依赖（K11 数据、G06 修正项……） | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
