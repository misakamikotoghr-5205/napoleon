# G06 `ladder-autoplay` · 破产阶梯（家当与抵押、钱不够、街头、牢房）、无头自动玩、蒙特卡洛平衡、黄金种子、性能基准

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.2 G06 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] G06: …` issue。

## 执行者与线号

- 执行者：**GPT**
- 线号：**GPT 线 6**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 阶梯四个类、`CardLadderInstall`、`CardPolicy`/`CardAutoplay`/`CardReplay`/`balance_main.gd` 都是同签名的桩；指令/查询/op 已登记 | W0（已完成） |
| G01 | `CardPiles`（牢房牌进手牌、`order_hand`）、`CardComposer.street_deal`、`CardFirsts` | W1（先合） |
| G03 | 牢房牌的格子与掷铜钱（`pr.cell` 的检定由 G03 跑）、`arrest` 由 G03 的风声到顶经 op 调你 | W1（在你之前合） |
| G04 | `money_short` 钩子、`pay`/`money` op、货架与物品（拿货抵）、`CardCurrency.money` | W1（在你之前合） |
| G05 | 修正项 `pool_pct` 的使用者；危机检查读你的 `ladder` 命名空间 | W1（在你之前合） |
| G02 | 真正的日循环——**自动玩与平衡要它** | W1（在你的阶梯之后、自动玩之前合） |
| K 数据线 | W2 的真数据平衡报告 | W2 |

- **你所在的波次**：
  - **W1-a 破产阶梯**：对着桩做，合并顺序在 G04/G05 之后、G02 之前；
  - **W1-b 自动玩框架**：对着桩搭，G02 合入后接真引擎，**W1 里最后一个合**；W1 的黄金种子只用 `_examples`；
  - **W2**：用真引擎和 K 数据出平衡报告、出 `balance_overrides.json`、加真数据的黄金种子用例（之后每次数据/规则 PR 合入由 Claude 跑 `--update-golden` 重算）。

## 分支

`cards/G06-ladder-autoplay`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase` 跟上。阶梯与自动玩分两个（以上）PR。

## 目标

1. **破产阶梯**：钱不够时“先卖货/拿货抵 → 押家当 → 流落街头”的整条路；五件家当的押、赎、利息、押出后少的本事；铺面月底赎不回 → 街头 → 攒钱赎回铺面爬回来；被抓 → 牢房牌 → 打点/作保/人情掷铜钱 → 出不来这一局结束。
2. **无头自动玩与平衡**：七种策略只用 `send()/view()/query()` 无头玩整局；多种子蒙特卡洛跑出 §12.6 的全部指标；黄金种子回放保证确定性；性能基准。证明“什么都不做也不会卡死”。

## 必读

1. 合同 §0、§2.2、§3.2 G06、§4.6（`ladder.json`、`balance_overrides.json` 的深合并规则）、§4.7.11（estate：`order` `mortgage_value` `interest_pct_month` `while_mortgaged` `lose_if_unredeemed` 与修正项名）、§4.7.13（street）、§4.7.14（prison）、§5.2–§5.3 里归 G06 的 op（`arrest` `estate_seize`、`estate_status`）、§6（`ladder` 命名空间、随机写法、域表）、§7.3（修正项表：你提供 `cap` `deal_count` `intake_blocked` `pool_pct`；钩子表：`stage_start` 15、`month_close` 15、`money_short` 5、`arrested` 由你触发）、§7.4（`estate.*` `short.resolve` `street.redeem_shop`，`estates` `short` 查询，**§7.4.5 钱不够面板的参数**、§7.4.6 街头时发什么牌）、§7.5（EstateView：利息给钱数不给百分比）、§7.9 G06 段（ladder 与 sim）、§10.2（牢房牌排在金色牌之后）、§12.4–§12.6（性能、黄金种子、平衡指标）、§7.10.10、§13–§14。
2. `docs/cards/DESIGN_cards.md` §三.6（大命运触发里的“家当快押光”“流落街头超过几天”）、**§三.7**（破产阶梯）、**§三.8**（被抓、打点、结局）、§四（月底结账）、文末“实现时的理解”第 9、16 条。
3. W0 代码：`scripts/cards/ladder/*.gd`、`scripts/cards/sim/*.gd`（你的起点）、`scripts/cards/loop/card_engine.gd`（`command_log()`；G02 会把失败的指令也记进日志）、`scripts/cards/loop/day_loop.gd`（`set_mode`、`request_panel`）、`scripts/cards/core/card_composer.gd`（`street_deal`）、`scripts/cards/api/card_engine_api.gd`、`scripts/tests/cards/lib/card_t.gd`（`spy`）。
4. 数据：`data/cards/rules/ladder.json`（你的）、`data/cards/_examples/common/{estates,street,prison}.json`、`data/cards/rules/*.json`（平衡覆盖只能覆盖这些里已有的键）。

## 要做的事

### A. 家当与抵押（`mortgage.gd`）
- [ ] `ladder.estates[id] = {status:"held"/"mortgaged"/"lost", since_abs_day, principal}`；`stage_start` 15：首局五件家当都在手（按 `order` 排）；跨关保留。
- [ ] `estate.mortgage {estate}`（`day`、`morning`）：押值 = `mortgage_value`（1938 年价）× 物价指数 ÷ 100，经 `money` op 进钱（原因键 `g06.reason.mortgage`），记 `principal`；返回 `{money}`。`estate.redeem {estate}`：付本金（+ 当月应付利息，按 `ladder.json`），状态回 `held`。
- [ ] 押出后少的本事（`while_mortgaged` → 修正项）：`no_intake_cat {cat}` → `intake_blocked {cat}`；`shelf_cap {delta}` → `cap {zone: shelf}`；`kept_cap {delta}` → `cap {zone: kept}`；`deal_count {type, delta}` → `deal_count {type, abs_day}`；`pool_weight {pool, tags_any, pct}` → `pool_pct {pool, def}`（G05 用）。合同 §3.2 里写的“`pool_rows` 的提供者”是笔误，以 §7.3 的表为准：你提供 `pool_pct`。
- [ ] `on_month_close`（`month_close` 15）：每件押着的家当付利息（钱数 = 本金 × `interest_pct_month` ÷ 100，经 `pay {short:"ladder"}`）；`lose_if_unredeemed` 的（铺面）月底还押着 → `lost` → `CardStreet.enter()`。要进月底报告的用 `notice` 事件发（G02 收）。
- [ ] `view()` → `[EstateView {id, status, money, interest_money}]`（**利息给钱数，不给百分比**）；查询 `estates`。
- [ ] 效果 `estate_seize {pick: "best"/"worst"/<id>}`：没收（不是抵押），状态 `lost`；条件 `estate_status [id, "held"/"mortgaged"/"lost"]`。

### B. 钱不够阶梯（`short_ladder.gd`，§7.4.5）
- [ ] `on_short(args)`（`money_short` 5，参数 `{amount, payee, source}`）：按 `ladder.json.short.order` 算能走的路 `options ⊂ ["goods", "estate", "default"]`（有能抵的货才有 `goods`、有没押的家当才有 `estate`、`default` 认了永远有）、`goods`（`[ItemView]`）、`estates`（还没押的 `[EstateView]`）；存进 `ladder.short`；`CardDayLoop.request_panel(ctx, &"short", {amount, payee, source, options, goods, estates})`；第一次记 first `money_short`。
- [ ] `view()`（查询 `short`）返回同样的参数（读档后重开面板用）。
- [ ] `short.resolve {source, by, item?, estate?}`：`goods` → 拿那件货抵（经 G04 的 `item_lose`/`money` op，按看得见的价）再付；`estate` → `CardMortgage.mortgage()` 再付；`default`（认了）→ 这笔不付，执行来源的 `on_short`（`pay` 的 `fail` 语义）；钱凑够了经 `pay` op 把原来那笔付掉；清 `ladder.short`。**流落街头只从“铺面月底赎不回”进**（DESIGN §三.7），不是认了就进。合同没写细的地方（拿货按什么价抵、凑了一半怎么办）用最保守的做法、标 `# TODO(design)`、写进 PR。

### C. 街头（`street.gd`，§7.4.6）
- [ ] `enter()`：`CardDayLoop.set_mode(ctx, &"street")`（`loop` 命名空间只有 G02 写，你只调它）、`ladder.street.since_abs_day`；第一次记 first `street`。街头时每天的牌由 G01 的 `street_deal()` 发（`deal.json.street_per_day` 张）；人物、事件、消息不随机发；主线、金色、条子、命运照发（§7.4.6 矩阵，原来【待主创确认】的几处主创 10-13 已确认）；街头一样能打烊，没处理的街头牌按没理会算（§7.4.7）。
- [ ] `shop_price()` = 铺面押值 × `street.redeem_shop_pct` ÷ 100 × 物价指数 ÷ 100；`street.redeem_shop {}`（`day`，街头）：钱够 → 付、铺面 `held`、`set_mode(&"shop")`；不够 → `insufficient_money`、不改状态。之前押出去的家当按原价赎（`estate.redeem`）。
- [ ] 街头里要随机的地方（熟人帮不帮你）只用 `c.street.<x> [abs_day, …]`。

### D. 牢房（`prison.gd`）
- [ ] `arrest(reason)`（`arrest` op 的执行）：`CardPiles.spawn(ctx, "pr.cell", &"hand")`（G01 的 `order_hand()` 会把它排在金色牌之后、其他牌之前）、`CardDayLoop.request_panel(ctx, &"prison", {"uid": uid})`、触发 `arrested` 钩子 `{reason}`（G05 查危机）、第一次记 first `prison`。
- [ ] 牢房牌的格子与掷铜钱由 G03 跑（`pr.cell` 数据里 `on_success`/`on_fail`：出来 / `game_over`）；你不自己判断出没出来。牢房里要随机的地方只用 `c.prison.<x>`。
- [ ] **没处理就在牢里多待一晚**（§7.4.7）：`day_end` 25 牢房牌还在手上 → 留着、`ladder.prison = {uid, nights}` 的 `nights` 加一，执行 `{"op": "shop_closed", "days": 1}`（第二天铺子关门：不随机发人物牌、来赎的不来），`ladder.prison.uid` 不空时修正项 `deal_count` 把 `night`、`street` 减到 0（当晚就在牢里过夜：没有夜牌，夜里只有“算了”；第二天没有街头牌）；到第 `ladder.json.prison.max_days`（起步 3【待调】，你加进 `ladder.json`，开 `[shared] G06→G01` 登记必需键）晚 → 执行 `pr.cell` 的 `check.on_fail`（`game_over`，原因 `prison`）。出来了（掷成）清掉 `ladder.prison`。牢房牌的 `card_view_part` 给 `days_left` = 还能待几晚。

### E. 自动玩（`scripts/cards/sim/`）
- [ ] `CardPolicy`（基类，签名冻结：`policy_name()`、`decide(engine, view) -> [cmd, args]`，没得做返回 `[]`）；七个策略放 `scripts/cards/sim/policies/{fair,greedy,kind,random,refuser,wheel,hoarder}.gd`（`extends "res://scripts/cards/sim/policy.gd"`，**不写 `class_name`**，用 `preload`）。策略的随机只用 `JevRng.draw(<种子>, "c.ai.<policy>", [<种子>, <步数>])`（种子在构造策略时传进去——视图里没有种子，也不许有）。
  - `fair` 公道价、`greedy` 压价/刁难/押牌、`kind` 厚道价/白给、`random` 每步随机合法动作、`refuser` 能拒就拒、什么都不做，每天只按 `day.end {confirm: true}`（证明不卡死）、`wheel` 庙会赌摊都去转/香案放满、`hoarder` 留牌留到满、不出货。
- [ ] `CardAutoplay.play(engine, policy, until)`（卡住时先发 `day.end {confirm: true}` 往前走——它永远可用；连它都失败就是引擎的 bug，测试失败，不再“体面结束”）：`until = {stages, days, max_steps}`；循环“读 `view()` → 策略 `decide` → `send`”，处理所有阶段（`month_open` 的本月运势轮盘、`morning`、`day`、`night`、`settle`、`month_close`、`year_jump`、`game_over`）和引擎要求开的面板（`open_panel`：`short` `kept_full` `contacts_full` `prison` `wheel` …）；小游戏用写死的确定结果走 `mg.report`；**只用 `send()/view()/query()`，不碰 `ctx`、不发 `ui.guide`**；同一个 `[cmd, args]` 连续失败、或若干步没有进展 → 改发 `day.end {confirm: true}` 往前走（策略下一步照常）；`day.end {confirm: true}` 本身失败（不是 `game_over`）→ 立即返回 `ok: false` 并写原因（测试判失败）。返回 `{ok, stages_cleared, days, game_over_reason, steps, hash}`。
- [ ] `CardReplay.record(engine)` = 指令日志（G02 的 `command_log()`，含失败的指令）；`replay(opts, log)`：新建引擎、`new_game(opts)`、按序重放（日志里打头的 `game.new` 跳过或照放，二者一致）→ 返回最终状态哈希。

### F. 平衡与报告（`balance_main.gd`、`tools/cards/balance/`、`docs/cards/balance/`）
- [ ] `balance_main.gd` 命令行：`--seeds=200 --seed_from= --seed_to= --policies=fair,greedy,… --stages=3 --data=examples|real --out=<目录> --date=YYYY-MM-DD --update-golden`；**引擎里不碰时间**，报告文件名的日期由 `run.sh` 用 `--date=$(date +%F)` 传进来。
- [ ] `tools/cards/balance/run.sh`：按 `JOBS` 把种子拆成多个进程，汇总成 `docs/cards/balance/report_<日期>.md` + `.json`（Python 只用标准库）。
- [ ] 指标（§12.6，每策略 × 每关）：过关率；局终原因分布；月底钱的中位数/10%/90%；口碑、风声档位分布（每天）；条子按类 × 档的完成/拖延/失败；抵押了几件、流落街头比例与天数、爬回来比例；牢房次数与出来比例；大命运（大轮盘）次数与三类扇区分布；命运牌好坏比例；每天手牌张数分布；格子检定按“铜钱数 − 要的正面”分组的成功率；**签的准确率（必须 100%）**；黄历照做率；每关用时（步数）。统计靠总线监听（`card_t.spy` 同款）和查询，不读引擎内部。
- [ ] `data/cards/rules/balance_overrides.json`：只覆盖已有键、不改结构（校验器 V25 查）；每个改动在报告里写依据。W1 不改数，W2 用真数据出。

### G. 黄金种子与性能基准
- [ ] `scripts/tests/cards/golden/golden.json`：`{"cases": [{"seed": 7, "policy": "fair", "data": "examples", "days": 30, "hashes": [{"abs_day": 10, "hash": "…"}, …]}]}`；W1 只用 `_examples`（不受内容改动影响）；W2 起加真数据用例。测试脚本 `scripts/tests/cards/golden/test_golden.gd` 回放并逐项比对；`balance_main.gd --update-golden` 重写（只在行为确实改了时，由 Claude 跑或在 PR 里解释）。
- [ ] 性能基准 `scripts/cards/sim/bench_main.gd`（**不进清单**）：对 §12.4 的引擎项（`load_all`、`day.begin`、`settle.next`、`project`、`fortune.lot`、无头一关/三关、存档大小）跑一遍，输出表格；结果写进报告。

- [ ] **查询结果的形状和 Mock 一样**：界面任务是对着 `MockCardEngine`（`scripts/cards/mock/mock_scenario.gd` 的 `query()` 与十个夹具）写的，W2 换真引擎时形状必须一致。合同 §7.4 表里写成数组的查询，`query()` 只能返回字典，按 Mock 的包装键：`estates` → `{"estates": [EstateView]}`；`short` 直接返回 §7.4.5 的参数字典。

### H. 数据与键
- [ ] `data/cards/rules/ladder.json`：只改数（新键同步请 G01 更新 `RULE_KEYS`）。
- [ ] `data/cards/ui_keys/G06.json`：`g06.reason.*`（`mortgage` `interest` `redeem_estate` `redeem_shop` `seize`）、`g06.short.*`、`g06.street.*`、`g06.prison.*`、`g06.month.*`；只写 `brief`；`_meta._provenance = {"by":"ai","task":"G06","date":"<提交当天>"}`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] `day_end` 7：钱不够没选（`ladder.short` 不空）→ `short.resolve {by: "default"}`（认了）。`day_end` 25：牢房（见上文 D 节）。修正项 `end_rows`：牢房一行 `stay`（`g06.end.stay {nights, max}`）或 `fail`（`g06.end.fail {nights, max}`）、钱不够一行 `short`（`g06.end.short`）；键登记在 `ui_keys/G06.json`。
- [ ] 街头模式照样能打烊：没处理的街头牌按没理会算（它们的 `check.on_fail` 或 `on_expire`，由 G02 执行）。
- [ ] **模糊测试 `scripts/tests/cards/G06/test_no_deadlock.gd`**（合同 §7.4.7 第 4 条，清单拆成 4 行共 1000 局，每局一个种子，例子集数据，`save_dir = t.user_dir()`）：每局新开一局，走 `--days` 天（或局终）；种子号是 25 的倍数的那一局（每行 10 局）改走 `--long_days`（默认 32）天，跨过月底、跳年、第 2 关开月，让 `month_close` `year_jump` `month_open` 也被乱点到；每一步按 `c.ai.fuzz [seed, step]` 随机挑——**合法的**（从视图和查询拼：手上随便一张牌的面板指令、格子放东西/掷、柜台出价/拒/关、留牌、扔牌、押家当、赎家当、街头赎铺面、钱不够三条路、人脉让出、香案放/拿/转、求签测字、夜牌选/不选、日结、月底、跳年、局终重来）、**不合法的**（错的 uid、错的阶段、错的参数）、**随机打烊**（约 15%，`confirm` 真假各半）、**早上随机存读**（`game.save` → 新引擎 `game.load`）。逐条断言：① 不是 `game_over` 时 `day.end {confirm: true}` 永远 `ok`，`confirm: false` 只会 `ok` 或 `must_resolve_pending`；② `day.end_preview` 永远能答、过隐藏键检查、`needs_confirm` 与 `items` 一致，紧接着的 `day.end {confirm: true}` 结算的就是这张清单；③ 每 25 步做一次“逃生检查”：连续 `day.end {confirm: true}` 最多 8 次，`abs_day` 变大或进 `game_over`；④ `game_over` 时 `game.retry_stage` 能走、回到 `month_open`；⑤ 没有 `push_error`、状态里没有浮点；⑥ 每 50 个种子抽一局用 `CardReplay` 重放，哈希一致。卡死就打印种子和最后 20 条指令。另外 `balance_main.gd --fuzz=1000 --stages=3` 进平衡跑（三关全长，不进清单），报告里写一行“打烊不卡死：1000/1000”。
- [ ] 自动玩：任何策略遇到不会处理的状态都可以靠 `day.end {confirm: true}` 往前走；`refuser` 每天只按它。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**合同 1.3 不影响本任务**：1.3 只改界面这一层：柜台那一出用的还是 CounterView 和 `counter.*` 指令（G04）；自动玩只用 `send/view/query`、不建界面（G06）；视图里的 `stage.set == "prison"` 由 G02 读你的 `ladder.prison.uid` 算（G06 不用做什么）。

- 只有一处要跟着看：G02 把视图的 `night_offers` 元素改成了字典 `{def, art, choices}`（合同 §7.5 的 1.3 增补；W1 里在 G02 合入之前还可能是裸的牌 id 字符串）。你的策略和 `test_no_deadlock.gd` 在夜里挑夜牌时两种都认：字典取 `def`、带 `choices` 的再挑一个选项 id 发 `night.choose {def, choice}`；字符串就当 `{def: <它>, choices: []}`。
- 上文“新手指引”一节里 `gd.mortgage` 1.3 多了备用锚点 `a.tab.estates`（右边的“家当”标签；家当面板 1.3 起是右抽屉），你发的 first 和测试不用为此改。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `scripts/cards/ladder/**`、`scripts/cards/sim/**`（含 `policies/`、`.uid`）
- `data/cards/rules/ladder.json`、`data/cards/rules/balance_overrides.json`
- `scripts/tests/cards/golden/**`、`docs/cards/balance/**`、`tools/cards/balance/**`
- 默认拥有：`scripts/tests/cards/G06/**`、`scripts/tests/cards/suites/G06.txt`、`data/cards/tags/G06.json`、`data/cards/ui_keys/G06.json`

## 不能做的事

- **不写玩家最终内容**：家当、街头、牢房的正文都由人写；你只登记键和 brief；报告是开发文档（不进包），可以写中文说明，但不写成游戏文案；测试夹具“正文”只用 ASCII 假字。
- 平衡覆盖**只改数、不改结构**，不覆盖不存在的键；不改别人的规则文件本身（只经 `balance_overrides.json`）。
- 自动玩、平衡只用 `send()/view()/query()`；不碰 `ctx`、不改状态、不发 `ui.guide`；策略不读隐藏信息（视图里本来就没有）。
- 只写 `ladder` 命名空间；模式经 `CardDayLoop.set_mode`、面板经 `request_panel`、钱和物品经 G04 的 op、牌经 G01。
- 引擎里随机只用 `c.street.*` `c.prison.*`；策略只用 `c.ai.<policy>`；不用 `randf/Time/OS.get_ticks*` 影响状态（bench 测墙钟可以，但 bench 不进清单、不影响状态）。
- **不许悄悄更新黄金哈希**：哈希变了必须在 PR 里解释（行为改了还是 bug）。
- 不改 `api/**`、`mock/**`、`tests/cards/lib/**`、`tools/run_*.sh`、`project.godot`、旧文件；不加 `class_name`（冻结表以外：只有 `CardMortgage CardShortLadder CardStreet CardPrison CardLadderInstall CardAutoplay CardPolicy CardReplay`）；引擎代码不连 `ui_event`；不自己加玩法。

## 接口

**提供（冻结签名，§7.9 G06 段）**：`CardMortgage`（`mortgage redeem on_month_close view`）· `CardShortLadder`（`on_short view resolve`）· `CardStreet`（`enter redeem_shop shop_price`）· `CardPrison.arrest` · `CardLadderInstall.install` · `CardPolicy`（`policy_name decide`）· `CardAutoplay.play` · `CardReplay`（`record replay`）。

**登记（`CardLadderInstall.install`，安装顺序在 economy 之后）**：
- 指令：`estate.mortgage` `estate.redeem` `short.resolve` `street.redeem_shop`
- 查询：`estates` `short`
- 效果 op：`arrest` `estate_seize`；条件 op：`estate_status`
- 修正项提供：`cap`（库房押出：货架 `zone: shelf` 变小；家当带 `kept_cap` 时：留牌 `zone: kept`）`deal_count`（柜台押出：人物 −1）`intake_blocked`（首饰柜押出）`pool_pct`（老宅押出：生活牌变多）`view_section`（`estates`）
- 钩子监听：`stage_start` 15 · `month_close` 15 · `money_short` 5；触发：`arrested`
- 随机数域：`c.street.<x>` `c.prison.<x>` `[abs_day, …]` · `c.ai.<policy>` `[seed, step]`

**用到**：G01 `CardPiles.spawn`、`CardComposer.street_deal`、`CardFirsts.mark`；G02 `CardDayLoop.set_mode/request_panel`、`command_log()`；G04 `money`/`pay`/`item_lose` op、`CardShelf.view`、`CardCurrency.money`；G03 牢房检定；CardEngineApi 全部（自动玩）。

## 新手指引

- **锚点**：引擎不登记锚点；EstateView 与 `short` 面板参数是 C11 的 `a.estate.list/mortgage`、`a.short.options` 的前提，`mode == street` 是 `a.street.redeem` 的前提，牢房的 `request_panel("prison")` 是 `a.prison.slots` 的前提。
- **你必须发的 first-time**（这四个的“教的人”待主创定，合同默认 `""`【冲突 c】）：

| 机制 | 什么时候 mark | args | 对应步骤（教的人 · 锚点） |
|---|---|---|---|
| `money_short` | 第一次钱不够付（`money_short` 5 里 `request_panel("short")` 时） | `{}` | `gd.money_short`（"" · `a.short.options`） |
| `mortgage` | 第一次要用到家当面板：引擎看不到“打开面板”，在第一次 `short` 面板给出 `estate` 这条路时、或第一次 `estate.mortgage`/`estate.redeem` 成功时（先到者）记；步骤靠锚点 `a.estate.mortgage` 只在家当面板开着时可见来对上时机——PR 里写明 | `{}` | `gd.mortgage`（"" · `a.estate.mortgage` 备 `a.tab.estates`） |
| `street` | 第一次流落街头（`CardStreet.enter`） | `{}` | `gd.street`（"" · `a.street.redeem`） |
| `prison` | 第一次进牢房（`CardPrison.arrest`） | `{uid}` | `gd.prison`（"" · `a.prison.slots`） |

- **你支持的步骤**：上表四步；另外你的自动玩是“指引开关不改状态”的旁证（自动玩从不发 `ui.guide`，K14 在 W2 做开/关两遍的哈希对比）。
- **指引验收（必须有测试）**：上表每个机制恰好一次、第二次不发、存→读后不发、`args` 只含白名单键；自动玩全程的指令日志里没有任何 `ui.*`。
- **截图**：本任务无界面，不交截图（C11 出画面截图、C16/K14 出步骤截图）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/G06.txt`（黄金种子测试放在你拥有的 `scripts/tests/cards/golden/` 下，也登记在这个清单里）：

```
# 名字|脚本|超时秒|参数
G06_mortgage|res://scripts/tests/cards/G06/test_mortgage.gd|120|
G06_short_ladder|res://scripts/tests/cards/G06/test_short_ladder.gd|120|
G06_street|res://scripts/tests/cards/G06/test_street.gd|120|
G06_prison|res://scripts/tests/cards/G06/test_prison.gd|120|
G06_ops_conds_mods|res://scripts/tests/cards/G06/test_ops_conds_mods.gd|120|
G06_firsts|res://scripts/tests/cards/G06/test_firsts.gd|120|
G06_determinism_save|res://scripts/tests/cards/G06/test_determinism_save.gd|180|
G06_policies_no_stall|res://scripts/tests/cards/G06/test_policies_no_stall.gd|600|--stages=3 --seeds=3
G06_replay|res://scripts/tests/cards/G06/test_replay.gd|300|
G06_report_schema|res://scripts/tests/cards/G06/test_report_schema.gd|300|
G06_golden|res://scripts/tests/cards/golden/test_golden.gd|300|
G06_no_deadlock_a|res://scripts/tests/cards/G06/test_no_deadlock.gd|600|--seed_from=1 --seed_to=250 --days=6 --name=G06_no_deadlock_a
G06_no_deadlock_b|res://scripts/tests/cards/G06/test_no_deadlock.gd|600|--seed_from=251 --seed_to=500 --days=6 --name=G06_no_deadlock_b
G06_no_deadlock_c|res://scripts/tests/cards/G06/test_no_deadlock.gd|600|--seed_from=501 --seed_to=750 --days=6 --name=G06_no_deadlock_c
G06_no_deadlock_d|res://scripts/tests/cards/G06/test_no_deadlock.gd|600|--seed_from=751 --seed_to=1000 --days=6 --name=G06_no_deadlock_d
```
（`G06_policies_no_stall` `G06_replay` `G06_report_schema` `G06_golden` `G06_no_deadlock_*` 要 G02 的真日循环：在自动玩那个 PR（G02 合入后）里登记。`test_report_schema` 把报告写到 `t.user_dir()`，不写进 `docs/`。）

**每条必须证明的事（合同 §3.2 G06 验收 + §12.2）**：
- [ ] 钱不够阶梯按“先卖货/拿货抵 → 押家当 → 街头”走；`short` 面板的参数（§7.4.5：`amount payee source options goods estates`）齐，`query("short")` 读档后返回同样的东西；`default` 执行来源的 `on_short`。
- [ ] 五件家当各自押出后少的本事生效（不能收首饰、货架变小、每天少一张人物牌、生活牌变多、铺面）；首饰柜押出后 `intake_blocked {cat: jewelry}` 为真；EstateView 没有百分比。
- [ ] 铺面月底赎不回 → 街头（`mode == street`、每天 3 张街头牌）→ 攒够钱 `street.redeem_shop` 回来；钱不够不改状态。
- [ ] 被抓 → `pr.cell` 在手牌里、排在金色牌之后；牢房失败 → `game_over`（由数据里的 `on_fail` 经 G02 的 op 执行，面板不自己判断）。
- [ ] 所有策略三关跑完不卡死：每局都走到三关结束或局终，返回 `ok: true`；`refuser`（每天只按 `day.end {confirm: true}`）同样（1.2 起不再接受“体面结束”）。
- [ ] **`G06_no_deadlock`：随机乱点 + 随机打烊 ≥ 1000 局不卡死**（见上方“10-13 变更”；四行清单全绿 = 1000/1000）。
- [ ] 牢房：没处理多待一晚（当晚没有夜牌；第二天没有随机人物牌、街头牌）、第 `max_days` 晚打烊进 `game_over`；钱不够没选时打烊按认了。
- [ ] 报告含 §12.6 的全部指标（`test_report_schema` 检查 `.json` 的键齐全）；签的准确率 100%。
- [ ] 黄金种子在同一提交上可复现（同一用例跑两遍哈希一样；`replay(record())` 的哈希等于连续跑的哈希）。
- [ ] 平衡覆盖只覆盖已有键（校验器会查；你的测试再查一遍）。
- [ ] 确定性：同种子同指令两遍哈希一样；`morning`/`month_open` 存→读→继续一致；`find_floats` 为空；随机域只用 G06 的。
- [ ] “新手指引”一节的验收。

**W1 测试替身**：W1-a 阶梯阶段 G02 的日循环、G04 的钱可能还是桩：单测里另建 `CardCtx` 登记假的 `money`/`pay`/`money_gte`、直接 `ctx.hooks.fire(ctx, &"money_short", …)` / `&"month_close"` 驱动；不要等。

**性能**（bench 不进清单，数写进 PR 和报告）：无头自动玩一关（30 天）≤ 1.5 s、三关 ≤ 5 s；平衡跑 200 种子 × 3 策略 × 3 关、`JOBS=6` ≤ 10 分钟；§12.4 引擎各项（见上 G 节）。

**怎么跑**：
```
GODOT=<你的 Godot 4.7> CARDS_SUITES=G06 tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_legacy_smoke.sh
GODOT=<你的 Godot 4.7> JOBS=6 tools/cards/balance/run.sh --seeds=200 --policies=fair,greedy,kind --stages=3 --data=examples
```
**通过条件**：退出码 0；日志没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有泄漏；每个清单测试最后一行 `CARDS TEST PASS <名字>`；黄金种子绿（变了在 PR 里解释）。

**截图**：无（本任务无界面）。

## 交付

- **PR 标题**：`[G06] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[G06] 破产阶梯：家当与抵押、钱不够、街头、牢房`（W1-a，G04/G05 之后）
  2. `[G06] 无头自动玩、七种策略、回放与黄金种子（例子集）`（W1-b，G02 之后）
  3. `[G06] 平衡跑与报告、性能基准`（W1-b/W2）
  4. `[G06] 真数据平衡报告与 balance_overrides`（W2）
- **PR 描述**按模板填满，另外必须有：改动路径；用到的随机域；发的 first-time 及位置（含 `mortgage` 记在哪个引擎时刻）；新加的公开函数（如有）；“认了”的语义与“街头只从铺面进”的理解；策略各自做什么；报告路径与关键数字（过关率、局终原因、签准确率）；黄金哈希（新加或变了的用例与原因）；bench 数；平衡覆盖的每个改动与依据；需要主创/编排决定的事；完成时写“交付”。

## 审核（Claude 会逐条看）

1. 越界：只动 G06 路径；平衡覆盖只覆盖已有键。
2. 阶梯顺序与 `short` 参数齐全；街头只从铺面进；赎回、爬回来、牢房失败都走得通。
3. 修正项：五件家当的本事都映射到 §7.3 的修正项（`pool_pct` 不是 `pool_rows`）。
4. 只写 `ladder`；模式与面板经 G02；钱经 G04。
5. 自动玩只用 `send/view/query`；不发 `ui.*`；`refuser` 不卡死；七种策略都能跑三关。
6. 回放与黄金种子：日志含失败指令、回放哈希一致；黄金哈希变化有解释。
7. 报告：§12.6 指标齐全；签准确率 100%。
8. 确定性：策略随机只用 `c.ai.<policy>`；引擎随机只用 `c.street.*`/`c.prison.*`；无浮点。
9. 隐藏信息：EstateView 只有钱数；报告是开发文档不进包。
10. 新手指引：四个 first 各一次。
11. 性能数在预算内；函数 ≤ 80 行。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 七种策略三关结果（过关率、局终原因、卡住的地方） | |
| 平衡报告路径与关键数字 | |
| 黄金种子用例与哈希 | |
| bench 数（一关 / 三关 / 平衡跑 / §12.4 各项） | |
| 用到的随机域 | |
| 发的 first-time 及位置 | |
| 新加的公开函数 | |
| 开的 issue | |
| 悬空依赖 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
