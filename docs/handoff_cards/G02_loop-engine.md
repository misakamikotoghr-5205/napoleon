# G02 `loop-engine` · 门面 CardEngine、日/周/月/年状态机、日程、金色牌、目标、跳年、视图

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.2 G02 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] G02: …` issue。

## 执行者与线号

- 执行者：**GPT**
- 线号：**GPT 线 2**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 门面的分发、`busy`、事件顺序、模块安装顺序已写好（**这些行为冻结**）；`game.new/save/load`、`card`/`actions` 查询、`begin_stage/open_month/set_phase/request_panel/set_mode`、CardCalendar、CardViewModel 能用；其余是桩 | W0（已完成） |
| G01 | `CardPiles.overflow_uid()`（G01 新加）、`CardComposer.compose/project/night_offers`、`CardCoreInstall.merge_ui` | W1（G01 先合） |
| G03 / G04 / G05 / G06 | 钩子监听、`view_section`/`card_view_part` 提供者、各自的指令 | W1（都在你之前合） |

- **你所在的波次**：W1 并行开发——**对着 G01/G03/G04/G05/G06 的桩开发，不要等**；W1 合并顺序里排在 G01 → G03 → G04/G05 → G06 阶梯之后、G06 自动玩之前，所以你的最后一个 PR 要在它们合入后 rebase、把端到端测试接上真模块。
- **W2**：`CardGame.tscn` 默认换成真引擎（Claude 做）；三关从标题玩到首发结尾；真数据上的第 1–3 天指引走查（K14）要你配合修。
- 谁依赖你：G06 的自动玩、全部界面任务（W2 起对真引擎）、K14。

## 分支

`cards/G02-loop-engine`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

把真引擎的门面和一局的节奏做完：`boot → month_open → morning → day → night → settle → (morning…) → month_close → year_jump → month_open …`，以及 `game_over`（`branch_pick` 预留不做）；日程（主线、教学、每周生活牌）、金色角色牌的打烊流程、本关目标、跳一年、按关存档与续玩点与重来本关、只含看得见信息的视图。每条指令的事件以 `command_done`、`view_changed` 收尾；同一状态的 `view()` 永远一样；三关无头跑通不卡死。

## 必读

1. 合同 §0、§2.2、§3.2 G02、§4.4.4（Schedule）、§4.6（`stages.json` 与规则文件格式）、§4.7.1 金色牌例子、§4.7.12（夜牌带 `choices`）、§4.7.20（goal）、§4.7.22（`stage.json`）、§5.2–§5.3 里归 G02 的 op、§6 全章、§7.2（门面与执行顺序）、§7.3（**钩子表与 priority**、修正项表）、§7.4（指令与查询表、§7.4.1、§7.4.3、§7.4.6）、§7.5（视图、CardView、隐藏键黑名单、视图怎么拼）、§7.6、§7.9 G02 段、§7.10（尤其 §7.10.6、§7.10.10、§7.10.11）、§10 全章（金色牌）、§12（测试、性能、黄金种子）、§13–§14、**§7.5 的 1.3 增补（视图 `stage`、CardView 的 `stage` `source`、`night_offers` 字典）**。
2. `docs/cards/DESIGN_cards.md` §一、§四（一关）、§五（年代表与首发三关）、§九.3（金色牌）、§九.4（新手指引节奏）、文末“实现时的理解”第 1、9、10、11、13、16 条。
3. W0 代码：`scripts/cards/loop/*.gd`（全部，你的起点）、`scripts/cards/core/card_composer.gd` `card_piles.gd` `card_save.gd` `core_install.gd`（`merge_ui`）、`scripts/cards/api/card_ids.gd`（阶段、指令、钩子、`FIRSTS`）、`scripts/cards/*/*_install.gd`（别的模块登记了什么）、`scripts/tests/cards/W0/test_engine.gd`、`scripts/tests/cards/lib/card_t.gd`、`scripts/cards/mock/fixtures/*.json`（十个基础夹具：界面期待的视图长什么样）。
4. 数据：`data/cards/rules/stages.json`（你的）、`data/cards/_examples/era/1938/{people,goals,stage}.json`、`data/cards/_examples/guide/steps.json`（`_test.d1_3`）。
5. 史实：`docs/town/cards/src/era.json` 的 `notes`（`stages.json` 的 `_doc` 和你的界面键 brief 要按它写：伪字、年份写法）。

## 要做的事

### A. 门面 CardEngine（`scripts/cards/loop/card_engine.gd`）——冻结行为不许改
- [ ] 保持 W0 的：指令/查询分发、`busy` 防重入（总线回调里同步 `send` 得 `busy`）、`ctx.out` 事件按序发 → `command_done(cmd, args, ok)` → `view_changed`（最后一条）、`ui.*` 什么都不发不记、模块安装顺序。
- [ ] **指令日志**：凡是进了处理函数的指令都记（`ok` 为假的也记——`card.keep` 遇到留牌满、`day.end {confirm: false}` 第一次返回清单都会改状态：溢出、first-time），`ui.*`、`game.save`、`game.load` 不记；日志放存档信封（`CardSave.write` 的 `meta.cmd_log`），不在状态里。G06 的回放照这个日志重放。PR 里写明这一条，并开 `[api] G02: 指令日志含失败的指令` 让 Claude 在合同 §6.1 补一句。
- [ ] **溢出拦截**（§7.4.2）：`CardPiles.overflow_uid(ctx) != ""` 时，除 `card.discard`、`day.end`（打烊永远不被拦，§7.4.7）、`ui.*`、`game.save`、`game.load`、`game.retry_stage` 外的指令返回 `{ok:false, err:"overflow_pending"}`（照样发 `command_done`、`view_changed`）。`overflow_uid` 是 G01 新加的，**G01 合入后 rebase 再接上**，之前标 `# TODO(G01 overflow_uid)`。
- [ ] **告示栏**：冲刷 `ctx.out` 时，把当天的 `notice` 事件（任何模块的效果 `notice` 或模块自己发的）键与整数参数追加进 `loop.notices`（进入新的早上时清空）。这样别的模块不用写 `loop`。标 `# TODO(design)` 并写进 PR（合同没写效果 `notice` 进不进告示栏）。

### B. 状态机（`day_loop.gd`；`loop` 命名空间只有你写）
- [ ] `game.new`（W0 已有）：成功后阶段 `month_open`；写本关存档 `CardSave.stage_path(stage)`。
- [ ] `month.begin`（`month_open`）：如果 G05 在 `month_open` 钩子里要求了必转的轮盘（`loop.open_panel.kind == "wheel"` 且 `args.required`），本月运势还没转（读 `fate.month_segment`，只读）→ `wheel_pending`；没要求（桩阶段）就直接过。然后进第 1 天早上。
- [ ] **进早上**（内部 `_enter_morning`）：`stage_day += 1`、`abs_day += 1`、钟点回到 `loop.json` 的开门时刻；阶段 `morning`；触发 `day_start` 钩子 `{abs_day}`（G05 天气/黄历、G03 条子、G04 来赎的人……，合同 §7.3：钩子在“发牌前”）；写当天自己的告示（天气 `g02.notice.<weather>`、集市日等）；记 first `notice`；记早上快照（钱、口碑档、风声档，给日结报告比）；覆盖写续玩点 `CardSave.suspend_path()`。早上可以存档、可以押家当（G06 的 `estate.*` 在 `morning` 可用）。
- [ ] `day.begin`（`morning`）：`CardComposer.compose()` → 阶段 `day` → 返回 `{dealt}`；发完检查手牌，有金色牌就记 first `gold`；按日程发出的牌记进 `loop.sched_done`（`once` 用）。
- [ ] `day.end {confirm}`（**打烊 · 下一天**，§7.4.7；1.1 的“挡住 / 金色牌两步确认”作废）：除 `game_over`（`bad_phase`）外任何阶段都能发、永远往前走一步——`day` → 触发 `day_end` 钩子（各模块按 §7.4.7 第 3 条的表结算没处理的东西）→ 夜牌 `CardComposer.night_offers()` 进 `loop.night.offers` → 阶段 `night`，第一次记 first `night`；`night` → 今晚不选夜牌（= `night.choose {def: ""}`）；`settle` → `settle.next`；`morning` → `day.begin`；`month_open` → 本月运势没转就 `CardWheel.spin(ctx, "wh.month", "")` 替玩家转（香案上已放的照算），再 `month.begin`；`month_close` → `month.next`；`year_jump` → `year.next`。`confirm` 为假且清单要确认（`needs_confirm`）→ `{ok: false, err: "must_resolve_pending", step, items, needs_confirm: true}`，**只记 first 和指令日志、别的不改**；否则做那一步、返回 `{step, items}`（外加那一步本来的返回）。参数旧名 `confirm_gold_leave` 在 W1 里当 `confirm` 照收。
- [ ] 查询 `day.end_preview`（§7.4.7）：`{step, needs_confirm, items}`——`day` 阶段合并各模块经修正项 `end_rows` 交的行，加上你自己那几行（金色 `gold_leave`、人物 `leave`、事件/命运/街头/大赌 `ignore`、今天的机会 `pass`；`consequence_key` 按表取 `<def>#outcomes.ignored` / `<def>#outcomes.fail` / `g02.end.*`），按“手牌顺序 → 条子板 → 没选的面板”排；其他阶段按第 2 条的表；跑 `leaks()`。**预览 = 结算**：同一状态下预览的 `items` 和随后 `day.end {confirm: true}` 结算的一模一样。
- [ ] `day_end` 10（你自己的结算）：金色牌 → `CardGoldRule.leave`；人物 → `card_left(uid, &"left")` + 非空 `on_expire`（个别人记仇）；`must_resolve` 的事件/命运/街头/大赌 → 有 `on_expire` 键执行它，没有但有顶层 `check` 执行 `check.on_fail`，都没有就算了，`card_left(uid, &"expired")`；不必了断、不能留、没期限的 → `card_left(uid, &"expired")`（+ 非空 `on_expire`）。**不另加惩罚**。日结报告里每个按没理会结算的行出一行（键 = `consequence_key`）。
- [ ] `night.choose {def, choice?}`（`night`）：`def` 必须在今晚的三张里；带 `choices` 的夜牌必须给 `choice`（否则 `no_such_choice`）；先执行所选项的 `effects` 再执行 `on_choose`；`night_chosen` 钩子 `{def}`（G05 记黄历）→ 阶段 `settle` → 触发 `settle` 钩子（10…70）→ 写日结报告 → 第一次记 first `settle`。
- [ ] `settle.next`（`settle`）：本关天数到了 → 阶段 `month_close`、`month_close` 钩子（10 G04、15 G06、20 G02 目标与评语）、first `month_close`；否则进下一天早上。返回 `{next_phase}`。
- [ ] `month.next`（`month_close`）：还有下一关 → 阶段 `year_jump`、first `year_jump`；最后一关 → 首发结尾：阶段 `game_over`、发 `game_over(&"ending")`、first `game_over`（结尾正文键 `g02.ending.*`）。
- [ ] `year.next`（`year_jump`）：`CardYearJump.run()` → `begin_stage(stage+1)` → `open_month()` → 写新一关的 `stage_%02d.json`。
- [ ] `game.retry_stage`：读当前关的 `stage_%02d.json`，`ui` 取“内存里的 ∪ 存档里的”（`CardCoreInstall.merge_ui`），回到 `month_open`，记 first `retry`（记在读回来的状态上）。
- [ ] `game.load`（W0 已有）：补上——读的是续玩点（`path == CardSave.suspend_path()`）时记 first `resume`；读回来 `loop.open_panel` 不空就重发 `request_panel`（界面据此重开面板）；`db_hash` 不一致照读、`meta.db_changed = true`。
- [ ] 效果 op `goal {id, status}`、`game_over {reason}`（阶段 `game_over`、发 `game_over(reason)`、first `game_over`）；条件 op `day_gte abs_day_gte weekday era stage_gte mode phase goal_status`（W0 写了大半，补 `goal_status`）。
- [ ] 所有指令先查阶段（不对返回 `bad_phase`）、再查参数（`bad_args`）；**失败的指令除 first-time 与 §7.4.2 的溢出外不改状态**。
- [ ] 每个阶段切换都经 `set_phase()`（发 `phase_changed`）。`branch_pick` 首发不可达，`branch_pick` 的 first 不许发。

### C. 存档：按关自动存档、续玩点、重来本关（§6.1、DESIGN“实现理解”第 9 条）
- [ ] 每关开始（新局第 0 关、跳年后的新关）写一次 `stage_%02d.json`，这一关里不再改它；重来本关读它、不重写。
- [ ] 每天早上覆盖写 `suspend.json`。只在 `morning`、`month_open` 存（`game.save` 在别的阶段返回 `bad_phase`）。
- [ ] `loop` 命名空间要升级格式时放 `"_v": n` 自己迁移；不认识的键原样保留。
- [ ] 测试里 `new_game` 一律传 `save_dir = t.user_dir()`。

### D. 日程 CardSchedule（`schedule.gd`）
- [ ] `due(ctx, abs_day)` **只读**（`project()` 也会调它），支持今天和**本关以后的某天**（G05 求签要用）：`stage_day` 一个数 = 那天；两个数 = 窗口里第一个满足 `when` 的那天（未来日按当前状态预计）；只有 `when` = 满足的那天早上（每关最多一次，`once` 默认 true，已发过的看 `loop.sched_done`）；`order` 排先后；年代过滤。
- [ ] 教学牌（K16 的 `data/cards/era/1938/tutorial.json`）和主线牌一样走 `schedule`，你不用特殊处理；W1 时它还不存在，测试用你自己的夹具数据根（见“测试”）。
- [ ] 每周生活牌：这周几张 `c.sched.life.n [stage, week]`（范围写在 `loop.json`）、第 k 张落在哪天 `c.sched.life.day [stage, week, k]`（**避开脚本日**）、是哪一张 `c.sched.life.pick [stage, week, k]`（当年、当季、`conditions` 满足的生活牌按权重）。经修正项 `scheduled_cards` 交给 G01。

### E. 金色牌 CardGoldRule（`gold_rule.gd`，§10）
- [ ] `hand_sub`（W0 已有）：金色牌返回 `schedule.order`，其余 0；**不自己挪牌**（手牌顺序只由 G01 的 `order_hand()` 定）。
- [ ] `leave(ctx, uid)`（`day_end` 10）：发 `card_left(uid, &"gold_left")`、执行 `on_expire`（`story … ignored` + `dossier_gap`，经 `ctx.run`）、牌进弃牌、`loop.gold_left` 记一笔、日结报告一行 `g02.settle.gold_left`。

### F. 目标 CardGoals（`goals.gd`）
- [ ] `pick()`（`stage_start` 40）：主线目标 = 当年 `stage.json` 的 `main_goal`；可选 2 个（个数写在 `goals_rules.json`）从当年 `main:false` 的目标里按权重 `c.goal.pick [stage, k]` 挑，不重复。
- [ ] `evaluate(ctx, when)`：`any_time` 的在 `card_resolved` 20 里查、`month_close` 的在 `month_close` 20 里查 `done_when`（条件，不是格子检定）；执行 `on_done`/`on_fail`；状态 `open/done/failed`。
- [ ] `verdict_key()`：月底评语档 `g02.month.verdict.<n>`（分档规则写在 `goals_rules.json`）。

### G. 跳一年 CardYearJump（`year_jump.gd`）
- [ ] `run()`：`year_jump` 钩子 `{from, to}`（10 G04 满当 · 20 G04 换币物价 · 30 G03 一年后 · 40 G02 人脉跨年 · 50 G01 换牌库）；跳年报告。
- [ ] `year_jump` 40：手上的人脉按 uid 排序，逐条 `year_changes`：`to_era` 是新年代时 `c.year.<person> [stage] × den < num` 就执行它的 `effects`。

### H. 视图 CardViewModel（`view_model.gd`，§7.5）
- [ ] `build()`：先放你的（`v phase mode busy date notice caps goals night_offers open_panel`；1.3 加 `stage`，见下方“10-13 变更二”），再 `ctx.mods.merge(ctx, &"view_section", {})`；`card_view()` 合并 `card_view_part`；**某个模块改了它的视图字段，你的代码不用动**。
- [ ] `notice`：天气（`fate.weather`，只读）、集市（`CardCalendar.is_market_day`）、`news`（`loop.notices`）、黄历（`CardAlmanac.today`）、本月运势段 id（`fate.month_segment`）。
- [ ] `leaks()`：黑名单递归检查；视图里的数组按稳定键排序，**同一状态的 `view()` 永远一样**。
- [ ] 查询 `card`、`actions`（W0 已有）；`settle_report` `month_report` `year_report` → `{lines:[{key, args}]}`。
- [ ] **报告行从哪来**（合同没细写，按这个做并写进 PR）：① 你触发 `settle`/`month_close`/`year_jump` 钩子期间各模块发出的 `notice` 事件（当票逾期、条子剩几天、黄历的小好处、抵押利息……）；② 你自己算的：今天钱的进出（早上快照 vs 现在，`CardCurrency.money`）、口碑/风声换了哪一档（只给档位，不给点数）、金色牌走了、目标结果。只存键和整数参数。

- [ ] **查询结果的形状和 Mock 一样**：界面任务是对着 `MockCardEngine`（`scripts/cards/mock/mock_scenario.gd` 的 `query()` 与十个夹具）写的，W2 换真引擎时形状必须一致。`actions` → `{"actions": [...]}`、三个报告 → `{"lines": [...]}`、`card` 直接返回 CardView；`view()` 的顶层键和 Mock 的 `_to_morning()` 拼出来的一致。
- [ ] **界面在等你的（C08、C09 卡里列为合同缺口）**：开场过场要的 `bg`/`intro_paras`、局终原因、跳年报告行的分组（`section`）、~~夜牌三选一只有牌 id 没有美术和选项~~（10-13 作废，合同 1.3：`night_offers` 的元素改成 `{def, art, choices}`，见下方“10-13 变更二”）。这些都要加视图字段或查询：**先开 `[api] G02: …` 让 Claude 定名**，定了再做，PR 里列出；~~`night_offers` 在定下来之前保持 W0 的格式（牌 id 数组），别改。~~（10-13 作废：1.3 定了，改成字典。）

### I. 数据与键
- [ ] `data/cards/rules/stages.json`：只改数；1939 腊月的公历起点等 K13 在 issue 里给（`_doc` 里注明）。
- [ ] 新建 `data/cards/rules/loop.json`（开门/打烊钟点、每周生活牌张数范围……）和 `goals_rules.json`（可选目标个数、评语分档）：`_meta.owner` 写 `G02`，数全是整数，`_doc` 写说明；开 `[shared] G02→G01` 请 G01 在校验器 `RULE_KEYS` 里登记必需键。
- [ ] `data/cards/ui_keys/G02.json`：`g02.notice.*`（五种天气、集市日……）`g02.settle.*`（含 `gold_left`、钱的进出）`g02.month.verdict.*` `g02.ending.*` `g02.year.*` `g02.reason.*`；每个只写 `brief`（干巴巴的说明，不写成台词）；`_meta._provenance = {"by":"ai","task":"G02","date":"<提交当天>"}`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- 上文 B 节的 `day.end`、`day.end_preview`、`day_end` 10 三条，first-time 表里 `must_resolve` `gold_leave` 两行，验收里的打烊一条都已经按新规则改好。
- [ ] 登记查询 `day.end_preview`（W0 的 `loop_install.gd` 已经登记了桩）；`CardDayLoop.end_day(ctx, confirm)`（参数名改了，个数不变）。
- [ ] 视图不变：`must_resolve` 仍是 CardView 字段（小红点），含义改成“今天要了断”。
- [ ] `game.load {}`（不给 `path`）= 读续玩点；`game_over` 时 `game.retry_stage` 和 `game.load {}` 永远可用。
- [ ] 没有真实时间：引擎没有墙钟，`loop.minute` 只是显示。
- [ ] 测试 `test_next_day.gd`（清单 `G02_next_day`）：每个阶段 `day.end {confirm: true}` 都前进，连续最多 8 次一定进到下一天或局终（`CardIds.END_MAX_STEPS_TO_NEXT_DAY`）；`day_full` 那样的手牌：预览的每一行 `kind` 与结算后 `card_left` 的原因一致，`wait` 的牌还在；`confirm: false` 前后视图一样、`firsts` 多了 `must_resolve` / `gold_leave`；存→读后再打烊结果一样；`game_over` 时 `day.end` 是 `bad_phase`、`game.retry_stage` 能走。W0 的 `W0_next_day` 对 Mock 做的是同一套检查，可以照着写。
- [ ] `ui_keys/G02.json` 加 `g02.end.leave` `g02.end.ignore` `g02.end.pass` `g02.end.skip_night` `g02.end.auto_spin`（只有 brief）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**（合同 §7.5 的 1.3 增补；签名一个不改）

- [ ] **视图加 `stage {set, time, sealed}`**（新顶层块，你自己的 `CardViewModel.build` 出，不需要别的模块交 `view_section`）：`"stage": {"set": "counter", "time": "day", "sealed": false}`。
  - `set`：`"counter"`（铺子开着）· `"street"`（`loop.mode == "street"`）· `"prison"`（手上有 `type == "prison"` 的牌，或 `ladder.prison.uid` 不空）。优先级 prison > street > counter。读 `ladder` 命名空间只读（§6.1 允许）。
  - `time`：`"day"` · `"dusk"` · `"night"`。阶段 `night` `settle` → `night`；阶段 `day` → 设 D = 今天发到手牌的牌数（`core.deals[str(abs_day)]` 的个数），R = 其中现在已不在手牌区的张数（处理掉、走掉、留着、作废都算）；D > 0 且 `R × 100 ≥ D × loop.json.dusk_pct` → `dusk`，否则 `day`；其余阶段 → `day`。
  - `sealed`：今天铺子被查封（`econ.shop_closed_until ≥ abs_day`，只读 G04 的命名空间）。
  - 这三项只是“看得见的样子”，不进任何规则；视图隐藏键检查照旧（三个键都不在黑名单里）。
  - `data/cards/rules/loop.json` 加 `"dusk_pct": 60`（起步【待调】）；开 `[shared] G02→G01` 请 G01 在 `RULE_KEYS` 里登记；`core.deals` 读法不清楚的也在这个 issue 里问 G01。
- [ ] **`card_view` 基础字段加 `stage` 与 `source`**：`stage` = 这张牌定义里的演出块（§4.7.24）的深拷贝、**去掉所有层的 `brief` 键**，没写就是 `{}`；`source` = 消息牌的 `source`（谁说的，人物 id），别的类型 `""`。（`wheel` `fortune` 由 G05、`demand` 由 G03 经 `card_view_part` 交，你的代码不用动。）
- [ ] **`night_offers` 的元素改成 `{def, art, choices}`**：`[{"def": "nt.tidy", "art": "illus.nt.tidy", "choices": []}, {"def": "nt.family_dinner", "art": "illus.nt.family_dinner", "choices": ["waive_life", "family_word"]}]`（`art` 取定义里的 `art`，`choices` 是选项 id 的数组）；`loop.night.offers` 里存的仍是牌 id，只在拼视图时展开；`night.choose` 仍按 `def` 字符串收。界面在 W1 里照收裸字符串，W2 删兼容。1.2 的缺口“夜牌只给 id、没有美术和选项”就此关闭。
- [ ] **形状和 Mock 一样**：W0 的 Mock（`scripts/cards/mock/mock_scenario.gd`）1.3 版已经出 `view.stage`、CardView 的 5 个新字段（`stage` `source` `wheel` `fortune` `demand`）和字典形的 `night_offers`，十个夹具都重生过——你的输出按它对（`G02_view_leaks` 里对夹具跑 `leaks()` 照旧）。
- 引擎**不知道**哪张牌“正在演”：打出一张牌不发指令，演出是界面的事；状态、哈希、黄金种子、存档都不受 1.3 影响。

**新增 / 作废的交付**

- 新增：视图 `stage`；CardView 的 `stage` `source`；`loop.json` 的 `dusk_pct`；测试 `G02_stage_view`。
- 作废：上文 H 节“`night_offers` 在定下来之前保持 W0 的格式（牌 id 数组），别改”——1.3 定了，改成字典。

**锚点、界面事件、要证明的步骤**

- 引擎照旧不登记锚点。`view.stage` 是 C01 的场景层（背景按 `set` + `time`、查封的门旗与封条）、HUD 的时辰与“在街上 / 在牢里 / 今日查封”的前提；`night_offers` 的元素是 C02 手牌扇夜里那几张牌和 C08 夜里那一出的前提。上文“新手指引”表里 `gd.d1.notice` 的锚点已按合同 §7.10.5 的改名表改成 `a.scene.notice`（门边的告示，备 `a.top.date`）；`a.hand.gold` 1.3 起归 C02——你发的 first 和测试不用为此改。

**测试与截图**

- 新增 `G02_stage_view|res://scripts/tests/cards/G02/test_stage_view.gd|120|`（已加进上文清单）：今天发 5 张、处理 2 张是 `day`、处理 3 张是 `dusk`（60）；夜里、日结是 `night`；街头、牢房、查封；视图隐藏键检查照旧绿；CardView 的 `stage` 里没有任何 `brief`、没写演出块的牌是 `{}`、消息牌有 `source`；`night_offers` 的每个元素有 `def` `art` `choices`。`stage` 不进哈希的说法不需要（它是从状态算出来的，本来就不在状态里）。
- 截图：无（本任务无界面）。

**已经做了的哪些还有效**

- 全部有效；这几项可以放进你下一个 PR。

**日期**：视图增补（`stage`、CardView 新字段、`night_offers` 字典）目标 **10-21** 合入（交接页检查点）；你的整套 G02 照旧 10-27 合入。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `scripts/cards/loop/**`（含 `.uid`）
- `data/cards/rules/loop.json`、`data/cards/rules/stages.json`、`data/cards/rules/goals_rules.json`
- 默认拥有：`scripts/tests/cards/G02/**`、`scripts/tests/cards/suites/G02.txt`、`data/cards/tags/G02.json`、`data/cards/ui_keys/G02.json`

## 不能做的事

- **不写玩家最终内容**：不碰 `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`；评语、结尾、告示的正文由人写，你只登记键和 brief；测试夹具的“正文”只用 ASCII 假字。
- 不改门面的冻结行为（分发、`busy`、事件顺序、安装顺序）；不改别的模块的命名空间（`fate`、`econ`、`rules`、`ladder`、`core` 只读）；别的模块要开面板/换模式只经你的 `request_panel()`/`set_mode()`。
- 不改 `scripts/cards/api/**`、`mock/**`、`tests/cards/lib/**`、`tools/run_*.sh`、`project.godot`、已有旧文件；不加 `class_name`（冻结表以外）。
- 引擎里不用 `randf/randi/RandomNumberGenerator/Time/OS.get_ticks*` 影响状态；随机只用 §6.3 G02 名下的 `c.sched.life.*` `c.goal.pick` `c.year.<person>`；状态里没有浮点（钟点是整数分钟）。
- 视图、查询、事件参数里不出现 §7.5 黑名单键；不显示概率、点数、本心；报告里口碑/风声只给档位。
- 引擎代码不连 `ui_event`；指引开不开都不改状态；不发 `branch_pick`。
- 不自己加玩法；合同没写的用最保守的做法 + `# TODO(design)` + PR 列出。

## 接口

**提供（冻结签名，§7.9 G02 段）**：`CardEngine`（`_init(bus)`、`ctx`、`register_command`、`register_query` + CardEngineApi 全部；W0 加的 `command_log clear_command_log has_command has_query command_owner query_owner` 保留）· `CardDayLoop`（`begin_stage open_month begin_day end_day choose_night settle close_month jump_year set_phase advance_minutes request_panel set_mode`）· `CardCalendar` · `CardSchedule.due` · `CardGoldRule`（`hand_sub pending leave`）· `CardGoals`（`pick evaluate verdict_key`）· `CardYearJump.run` · `CardViewModel`（`FORBIDDEN_KEYS build card_view leaks`，W0 加的 `must_resolve panel_of` 保留）。

**登记（`CardLoopInstall.install`）**：
- 指令：`game.new` `game.save` `game.load` `game.retry_stage` `month.begin` `day.begin` `day.end` `night.choose` `settle.next` `month.next` `year.next`
- 查询：`card` `actions` `settle_report` `month_report` `year_report`
- 效果 op：`goal` `game_over`；条件 op：`day_gte` `abs_day_gte` `weekday` `era` `stage_gte` `mode` `phase` `goal_status`
- 修正项提供：`hand_sub`、`scheduled_cards`
- 钩子监听（§7.3）：`stage_start` 40 · `card_resolved` 20 · `day_end` 10 · `settle` 70 · `month_close` 20 · `year_jump` 40
- 钩子触发：`stage_start` `month_open` `day_start` `day_end` `night_chosen` `settle` `month_close` `year_jump`
- 随机数域：`c.sched.life.n` `[stage, week]` · `c.sched.life.day` `c.sched.life.pick` `[stage, week, k]` · `c.goal.pick` `[stage, k]` · `c.year.<person>` `[stage]`

**用到**：G01 `CardComposer.compose/night_offers`、`CardPiles.*`（含新加的 `overflow_uid`）、`CardSave.*`、`CardCoreInstall.merge_ui`、`CardFirsts.mark`；G04 `CardCurrency.money`（报告）；G05 `CardAlmanac.today`、`fate.weather` / `fate.month_segment`（只读）；G03 `CardMeters.tier`（报告与快照）。

**与别的线的约定（写进 PR）**：别的模块要上日结/月底/跳年报告的事，在自己的钩子监听里发 `notice` 事件（键 + 整数参数），你收进报告；`day_start` 在“进早上”时触发（早上视图里就有当天天气、黄历、条子）。

## 新手指引

- **锚点**：引擎不登记锚点。但你给的视图字段是锚点能不能亮的前提：`phase`、`open_panel`、`hand`（`gold`、`must_resolve`）、`night_offers`、`goals`、`date` 必须准确（C02/C08/C09/C01 的锚点 `a.hand.gold`（1.3 起归 C02）`a.endday.*` `a.night.offers` `a.month.goals` `a.top.date` 都靠它们显示；1.3 起视图的 `stage` 也是 C01 画面的前提）。
- **你必须发的 first-time**：

| 机制 | 什么时候 mark | args | 对应步骤（教的人 · 锚点） |
|---|---|---|---|
| `month_open` | 第一次开月（W0 已在 `open_month` 里） | `{}` | `gd.m.open`（brother · `a.month.goals`） |
| `notice` | 第一次进早上、告示出来 | `{}` | `gd.d1.notice`（brother · `a.scene.notice` 备 `a.top.date`） |
| `night` | 第一次进夜里 | `{}` | `gd.d1.night`（brother · `a.night.offers`） |
| `settle` | 第一次日结 | `{}` | `gd.d1.settle`（brother · `a.settle.lines`） |
| `gold` | 第一张金色牌进手牌（`day.begin` 发完后检查） | `{uid, def, person}` | `gd.d2.gold`（brother · `a.card.gold@{uid}` 备 `a.hand.gold`） |
| `must_resolve` | 第一次 `day.end`（`confirm` 真假都算）时清单里有 `leave` `ignore` `void` `stay` `fail` 的行（确认之前记） | `{uid}` | `gd.must`（obj.brother_ledger · `a.endday.blocked`，确认面板开着时亮） |
| `gold_leave` | 第一次 `day.end` 时清单里有 `gold_leave` 行（确认之前记） | `{uid}` | `gd.gold_leave`（obj.brother_ledger · `a.endday.gold_leave`） |
| `month_close` | 第一次月底结账 | `{}` | `gd.month_close`（obj.brother_ledger · `a.mclose.accounts`） |
| `year_jump` | 第一次跳一年 | `{}` | `gd.year_jump`（obj.brother_ledger · `a.year.forfeit`） |
| `game_over` | 第一次局终（含首发结尾） | `{kind}`（`kind` = 原因） | `gd.game_over`（"" · `a.over.retry`） |
| `retry` | 第一次重来本关 | `{}` | `gd.retry`（"" · `a.top.date`） |
| `resume` | 第一次从续玩点接着玩 | `{}` | `gd.resume`（"" · `a.top.date`） |
| `branch_pick` | **预留，首发不发** | — | `gd.branch_pick` |

- **你支持的步骤**：上表全部；另外你是第 1–3 天节奏的“总调度”（`scripted_days`、教学牌的日程），`_test.d1_3` 整串能不能在真引擎上按顺序亮，第一责任在你。
- **指引验收（必须有测试）**：
  1. 上表每个机制恰好一次；第二次不发；存→读后不发。`retry`/`resume` 的 first 记在读回来的状态上：所以“重来本关后哈希等于当时”的断言在**第一次重来之后**做（或比较时去掉 `core.firsts.retry`/`resume` 两项），PR 里写明（这是合同 §3.2 G02 验收与 first-time 规则之间的冲突，已报给 Claude）。
  2. **第 1–3 天 first-time 串（引擎侧的 headless 测试，`G02_firsts_d1_3`）**：新存档、种子 7，用一段固定的指令脚本（转本月运势并往香案放一次钱 → 开月 → 第 1 天按教学客人当/卖/买各走一遍，找不同用一个写死的结果 `mg.report` → 打烊 → 选夜牌 → 日结 → 第 2 天处理哥哥告别（选“听他交代完”）→ 第 3 天处理带格子的事件）跑到第 3 天日结。断言：**每一天**应出现的机制都在当天的 first 串里，而且跨天先后正确（同一条指令里的先后不强求——指引按 `priority` 和 `after` 排）。期望表：W1 用合同 §7.10.10 起步顺序推出的按天机制表——开局（第 1 天之前）`month_open` `month_wheel` `incense`；第 1 天 `notice` `deal` `person` `counter` `mg.spot` `ticket` `shelf` `buyer` `night` `settle`；第 2 天 `gold` `choice` `keep`；第 3 天 `slots` `coins`；K16 合入后改成从 `steps.json` 的 `_test.d1_3` 推（每一步换成它的 `trigger.first`，没有 `trigger.first` 的步骤跳过），两者不一致时报给 Claude。另外：同一串指令跑两遍 first 串完全一样；关不关指引（多发/不发 `ui.guide`）状态哈希一样。完整的 first 串（`[abs_day, cmd, mech, args]`）存成 `scripts/tests/cards/G02/golden/firsts_d1_3.json` 提交，测试逐项比对（带 `--update` 参数时重写，手动跑）；C16 的 `guide_d1..d3` 夹具和 K14 的走查拿它对照。
     - 数据：W1 时 K16 的 `tutorial.json` 还没有，例子集里也没有第 1、3 天的教学牌（脚本日只发日程上的牌，例子集第 1 天会是空手）。做法：测试开始时把 `data/cards/_examples/` 下的牌文件按真数据的目录结构、连同 `data/cards/rules/*.json` 和 `data/cards/tags/W0.json` 拷到 `t.user_dir()/data/`，再写进一份你测试目录里的教学日程牌夹具 `scripts/tests/cards/G02/fixtures/tutorial_d1_3.json`（按 §7.10.11：第 1 天来当（`minigame:"spot"`、物品用能出找不同的模板）/来卖/来买三位、第 3 天一张带格子、`need` 小的事件；全部 `weight: 0` + `schedule`；牌带 `_provenance`、只写 brief、不写正文），然后 `new_game({"seed": 7, "data_root": <那个目录>, "save_dir": …})`。K16 合入后（W2）加一行同名测试改用真数据 `res://data/cards`。
     - 这条测试要 G03/G04/G05 的真实现才能全绿：先写好、**不登记**；你的最后一个 PR（在它们合入之后）登记进清单并必须绿。
- **截图**：本任务无界面，不交截图；新手指引每一步的截图由 C16（Mock 夹具）和 K14（真引擎，W2，`shot_guide_d1_3.gd`）出，你的 `firsts_d1_3.json` 是他们的对照。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/G02.txt`：

```
# 名字|脚本|超时秒|参数
G02_engine_flow|res://scripts/tests/cards/G02/test_engine_flow.gd|180|
G02_three_stages|res://scripts/tests/cards/G02/test_three_stages.gd|300|--seeds=5
G02_view_leaks|res://scripts/tests/cards/G02/test_view_leaks.gd|300|
G02_stage_view|res://scripts/tests/cards/G02/test_stage_view.gd|120|
G02_gold|res://scripts/tests/cards/G02/test_gold.gd|120|
G02_schedule|res://scripts/tests/cards/G02/test_schedule.gd|120|
G02_calendar|res://scripts/tests/cards/G02/test_calendar.gd|60|
G02_goals|res://scripts/tests/cards/G02/test_goals.gd|120|
G02_year_jump|res://scripts/tests/cards/G02/test_year_jump.gd|120|
G02_save_retry|res://scripts/tests/cards/G02/test_save_retry.gd|180|
G02_determinism|res://scripts/tests/cards/G02/test_determinism.gd|300|--seeds=10
G02_firsts|res://scripts/tests/cards/G02/test_firsts.gd|120|
G02_firsts_d1_3|res://scripts/tests/cards/G02/test_firsts_d1_3.gd|180|
G02_next_day|res://scripts/tests/cards/G02/test_next_day.gd|180|
```
（最后一行按上面“指引验收 2”的说明，最后一个 PR 才登记。）

**每条必须证明的事（合同 §3.2 G02 验收 + §10.8 + §12.2）**：
- [ ] 用桩或真模块无头跑完三关（每关 30 天）不卡死：W1 别的模块还是桩时，没处理的牌靠 `day.end {confirm: true}` 按“没理会”结算往前走（§7.4.7；不用再在测试里 `CardPiles.resolve()` 硬处理掉）；真模块合入后同一测试改走真指令。
- [ ] 每条指令（`ui.*` 除外）的事件以 `command_done`、`view_changed` 收尾，失败的也是；`ui.*` 什么都不发。
- [ ] `day.end` 的“未处理清单 + 确认”（§7.4.7）：每个阶段 `day.end {confirm: true}` 都 `ok` 并前进；`confirm: false` 要确认时只改 `firsts`（视图不变）；预览 = 结算（逐行比 `card_left` 的原因）；溢出没选时 `day.end` 不被拦；有金色牌时清单里有它那一行、确认后前进；金色牌过期 → `story` 记“没理他”+ 档案缺口；第二天手牌里没有它；读档后同样；金色牌在手牌第一位（被抓、加发之后也是）；`card.keep` 对它返回 `not_keepable`。
- [ ] 视图递归检查没有任何 §7.5 隐藏键：三关浸泡途中每天每个阶段的 `view()`、**所有查询**的结果、引擎发出的**所有事件参数**（含 `first_time`）；另外对 W0 的十个 Mock 夹具里的 `view` 和 `queries` 也跑一遍 `leaks()`（防夹具和真视图跑偏）。
- [ ] `view()` 对同一状态永远输出同一结果（两次调用、存读之后）。
- [ ] 某个模块的视图字段改了 G02 的代码不用动：测试里另登记一个假的 `view_section`/`card_view_part` 提供者，视图里出现它的键。
- [ ] 按关存档后“重来本关”状态哈希等于当时（第一次重来之后比，见“指引验收 1”）；`ui` 在读档、重来时取并集。
- [ ] 日历：1938-03-01 是星期二、第 7 天是星期一；集市日只按 `market_every`/`market_offset` 算；三关的公历起点与 `stages.json` 一致。
- [ ] 日程：一个数、窗口 + `when`、只有 `when`、`once`；`due()` 对未来某天的结果与那天实际发的日程一致（状态不变时）；`due()`、`project()` 前后哈希不变；生活牌不排在脚本日。
- [ ] 目标：1 主线 + 2 可选、`done_when` 在 `any_time`/`month_close` 正确结算、评语键。
- [ ] 跳年：钩子按 priority 顺序触发；`c.year.<person>` 决定的人脉变化可复现。
- [ ] 确定性：同种子同指令两遍哈希一样；任意 `morning`/`month_open` 存→读→继续，哈希和连续跑一样；`find_floats(state)` 为空。
- [ ] “新手指引”一节的 1、2。

**性能**（bench 脚本 `scripts/tests/cards/G02/bench_loop.gd`，**不进清单**，数贴进 PR）：普通 `send()` ≤ 2 ms；`day.begin` ≤ 10 ms；`settle.next` ≤ 10 ms；无头一关（30 天，固定指令脚本）≤ 1.5 s、三关 ≤ 5 s。

**怎么跑**：
```
GODOT=<你的 Godot 4.7> CARDS_SUITES=G02 tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；日志没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有泄漏；每个清单测试最后一行 `CARDS TEST PASS <名字>`；G06 的黄金种子（合入后）不变，变了在 PR 里解释。

**截图**：无（本任务无界面）。

## 交付

- **PR 标题**：`[G02] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[G02] 状态机：开月、早上、发牌、打烊 · 下一天（清单 + 确认、金色牌）、夜、日结、月底、跳年、局终`
  2. `[G02] 日程、每周生活牌、目标、跳年人脉变化`
  3. `[G02] 存档：按关存档、续玩点、重来本关；指令日志与溢出拦截`
  4. `[G02] 视图与报告收尾、三关浸泡、第 1–3 天 first-time 串`（在 G01/G03/G04/G05/G06 阶梯合入之后）
- **PR 描述**按模板填满，另外必须有：改动路径；用到的随机域；发的 first-time 及位置；新加的公开函数（如有）；“指令日志含失败指令”“告示栏收 notice 事件”“day_start 在进早上时触发”“报告行来源”四条实现理解的说明和对应 issue 号；三关浸泡的种子与结果；`firsts_d1_3.json` 的内容摘要；黄金哈希变化说明；bench 数；需要主创/编排决定的事；完成时写“交付”。

## 审核（Claude 会逐条看）

1. 越界：只动 G02 路径；没改别的命名空间。
2. 门面冻结行为没变（分发、`busy`、事件顺序、安装顺序）；`command_done` 永远倒数第二、`view_changed` 最后。
3. 状态机：每条指令的阶段检查；失败指令除 first 与溢出外不改状态；`bad_phase` 路径齐全；三关跑通、首发结尾可达；`branch_pick` 不可达。
4. 金色牌：§10 第 2–8 条全部有测试。
5. 存档：按关存档只写一次、续玩点每天早上、重来本关与读档的 `ui` 合并、`resume`/`retry` 的 first 与哈希断言的处理写清楚。
6. 视图：黑名单递归检查覆盖视图、所有查询、所有事件；视图稳定；报告只给档位与键。
7. 日程：`due()` 只读、支持未来日（G05 的签要用）；生活牌避开脚本日；随机域只用 G02 的。
8. 确定性与无浮点；黄金哈希变化有解释。
9. 新手指引：12 个 first 各一次；`firsts_d1_3` 测试绿、按天的机制串与 `_test.d1_3` 对得上；指引开关不改哈希。
10. 免 AI 声明：只有键和 brief；夹具 ASCII 假字；`.gd` 字面量无中文。
11. 函数 ≤ 80 行；bench 在预算内。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 三关浸泡（种子、过关、卡住的地方） | |
| `firsts_d1_3.json` 摘要（每天的机制串） | |
| bench：`send` / `day.begin` / `settle.next` / 一关 / 三关 | |
| 用到的随机域 | |
| 发的 first-time 及位置 | |
| 新加的公开函数 | |
| 开的 issue | |
| 悬空依赖 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
