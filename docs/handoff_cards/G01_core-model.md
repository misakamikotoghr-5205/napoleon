# G01 `core-model` · 卡牌模型、牌堆、发牌组合、存档、校验器、正文、总线、first-time 记录

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.2 G01 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] G01: …` 报给 Claude。

## 执行者与线号

- 执行者：**GPT**
- 线号：**GPT 线 1**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 已给能跑的最小核心：CardDB、CardState、CardCtx、五个登记表、CardPiles、CardComposer、CardSave、CardText、CardFirsts、`ui.guide` 与四个指引查询、default 模式的校验器 | W0（已完成） |
| 无其他前置 | G03/G04/G05/G06/G02 都还是桩：你要用的它们的东西（`CardMeters.tier`、`pinned_cards`、`pool_rows`、`deal_count` 修正项）先对着桩和测试替身做 | — |

- **你所在的波次**：W1 并行开发；**W1 里第一个合并**（合同 §13.4：G01 → G03 → G04/G05 → G06 阶梯 → G02 → G06 自动玩）。
- **W2**：集成分支改用 strict 校验；真数据（约 600 张）上的性能；K 数据合进来以后 NOTE 规则变成真错误时配合修。
- 谁依赖你：全部 37 条线（校验器、CardDB、CardText、CardPiles、CardComposer 的 `project()`、CardFirsts）。所以先发小 PR、早合。

## 分支

`cards/G01-core-model`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；开发中用 `git rebase origin/claude/festive-ride-vud32a` 跟上，不留合并提交。

## 目标

把 W0 的最小核心打磨成首发能用的**确定性、可存读、可校验**的牌模型层：数据库读得全、读得快；牌堆的区、上限、过期、溢出流程完整；每日发牌（日程 → 钉签 → 按权重抽 → 排序）严格可复现、`project()` 只算不改且与实际一致；存档信封稳定、向前兼容；校验器补齐 NOTE / strict / ship 三种模式下的全部规则（V01–V42；V37 是 1.2 加的，V38–V42 是 1.3 加的，见下方两节“10-13 变更”）；正文覆盖层与草稿回退；first-time 记录与新手指引的引擎一侧（`ui` 命名空间、`ui.guide`、四个指引查询）可靠。

## 必读

1. 合同 §0（红线与并行规则）、§2.2（归属表）、§3.2 G01、§4 全章（尤其 §4.1–§4.6、§4.9 校验规则表、§4.10 两套数据）、§5.1–§5.2（`add_card` `remove_card` `waive` `extra_deal` 四个 op）、§6 全章（CardState、随机写法、随机数域登记表）、§7.2–§7.4（门面、CardCtx 与登记表、修正项与钩子表、指令/查询表、§7.4.2 留牌满了、§7.4.6 钉签与发牌矩阵）、§7.5（视图与隐藏键黑名单）、§7.6（总线）、§7.9 G01 段（冻结签名）、§7.10（尤其 §7.10.6、§7.10.10、§7.10.11）、§10.2（手牌顺序）、§11（免 AI 声明）、§12（测试、性能、黄金种子）、§13–§14、**§7.5 的 1.3 增补、§4.7.24（演出块，1.3 新）、§4.9 的 V38–V42 与 1.3 改过的 V27、V30**。
2. `docs/cards/DESIGN_cards.md` §一（一天怎么过、每天发什么牌）、§三.5（留着的牌）、§三.12（牌库怎么变）、§九.4（新手指引）、文末“实现时的理解”第 9、11、13、14、15 条。
3. W0 代码（你接手的起点，**先读完再动手**）：`scripts/cards/core/*.gd`（全部）、`scripts/cards/api/card_ids.gd`（`FIRSTS` `RNG_DOMAINS` `COMMANDS` `QUERIES` `ZONES` `POOLS`）、`scripts/cards/api/dsl_shapes.gd`（op 形状，冻结）、`scripts/cards/loop/card_engine.gd`（门面怎么调你的指令）、`scripts/cards/loop/view_model.gd`（`card_view` 怎么用你的数据）、`scripts/tests/cards/W0/test_engine.gd` 与 `test_validator.gd`（W0 已经测了什么）、`scripts/tests/cards/lib/card_t.gd`（测试工具）。
4. 数据：`data/cards/rules/deal.json`（你的）、`data/cards/_examples/**`（例子集，W1 单测用它）、`data/cards/_schema/*.json`（你的）、`docs/cards/ownership.json`（校验器 V01 用）。
5. 只读参考：`scripts/sim/jev_rng.gd`（`draw`、`weighted_choice` 会对空表或零权重 `assert`）、`scripts/core/save.gd`（旧存档的做法，不要复用它的类）。

## W0 已经给的、还留给你的（TODO(G01) 清单）

- `core_install.gd`：`add_card to:"kept"` 留牌满了的溢出流程；`remove_card` `waive` `extra_deal` 还在 `push_error`；`scheduled_cards` 修正项（队列里 `zone` 不是 `hand` 的牌）是空的；`stage_start` 50 的清理没写。
- `card_piles.gd`：`keep()` 满了只记 first 不走溢出；`discard()` 之后溢出的新牌不进 `kept`；没有过期结算。
- `card_composer.gd`：只按基础权重抽；钉签的名额与额外发、替身（`c.deal.sub`）、禁签、街头/查封/脚本日的矩阵（§7.4.6）、`hand_soft`、`project(d)` 对未来某天的脚本日判断都还没有。
- `card_validator.gd`：NOTE/strict/ship 部分（V09 V11 V12 V16 V17 全查 V18 V19 V21 V27 V29 V34 V36）；ship 模式下 V27 现在“关着门”一律报错。
- `card_db.gd` / `card_text.gd` / `card_save.gd` / `card_state.gd`：能用，缺测试和性能验证。

## 要做的事

### A. CardDB（`scripts/cards/core/card_db.gd`）
- [ ] `load_all(root, {only_examples, ship})` 一次只读一套（§4.10）；`rules/*.json` 和 `tags/W0.json` 两套都读；`balance_overrides.json` 按同名路径深合并在最后（只覆盖已有键）。
- [ ] 人物登记 = `data/cast.json` 的 `npcs` + 所有 `persons` 块；同一个人物 id 登记两次记进 `errors()`（校验器报）。
- [ ] 正文覆盖层按 §4.5 的路径镜像读进来（`text_entry()`），**只读不写**；`hash()` = 机制数据（去掉 `text` 覆盖层、`brief`、`_provenance`、`_doc`、`_meta.brief`、`_test`）的 sha256，全精度 JSON、排序键。
- [ ] `pool(type, era)` 只含 `weight > 0`、年代命中（`*` 或当年）的牌，排好序。
- [ ] 性能：首发约 600 张 `load_all` ≤ 300 ms（无头）。测量用 bench 脚本（见“测试”），不进清单。

### B. CardState / CardSave（`card_state.gd`、`card_save.gd`）
- [ ] 保持 §6.1 的命名空间与 `hash()`（去掉 `ui`、`JSON.stringify(d, "", true, true)` 全精度、sha256）。
- [ ] `from_dict`：整数值浮点还原成 int；顶层 `v` 比自己新 → `save_newer`；不认识的命名空间原样保留；各模块命名空间里的 `_v` 由模块自己迁移（你只保证不丢）。
- [ ] 存档信封 `{format:"dehoudang-cards-save", v, db_hash, saved_at_phase, meta, state, cmd_log}`；`cmd_log` 在信封里不在状态里；存档文件 ≤ 512 KB、写 ≤ 50 ms。
- [ ] `set_root()` / `new_game` 的 `save_dir`：测试一律 `user://test/<清单名>/`（`card_t.user_dir()`），任何代码路径都不碰 `user://cards/`，除非根就是它。

### C. CardPiles（`card_piles.gd`）
- [ ] 区：`hand` `kept` `contacts` `demands` `pending` `discard`；上限 `deal.json.caps` + 修正项 `cap {zone}`；`cap()` 没有上限返回 -1。
- [ ] **`order_hand()` 是手牌排序的唯一写法**：按 (`deal.json.hand_order` 的位置——`gold` 指 `gold:true` 的牌，其余是类型名，没列的排最后；修正项 `hand_sub`；`seq`)。任何往手牌里加牌的路径（`spawn` 到 hand、`move` 到 hand、`compose`、`add_card`、`extra_deal`、牢房牌）之后都调它（§10.2）。
- [ ] 留牌满了（§7.4.2）：`card.keep` 满了 → 记 first `kept_full`、这张牌进 `pending`（`status:"overflow"`）、`CardDayLoop.request_panel(ctx, &"kept_full", {"new_uid": uid})`、返回 `kept_full`；`add_card to:"kept"` 满了同样处理。`card.discard {uid}`（已留着的或新来的那张都行）→ 扔掉的不执行 `on_expire`；有了空位，`pending` 里 `overflow` 的那张随即进 `kept`（重算 `expires_abs_day`、执行 `on_keep`、记 first `keep`）。
- [ ] **新公开函数**（列进 PR）：`static func overflow_uid(ctx) -> String`——有没处理的溢出返回那张牌的 uid，否则 `""`。G02 的门面用它让别的指令返回 `overflow_pending`（`card.discard`、`day.end`、`ui.*`、查询除外——**`day.end` 永远不被拦**，打烊时还没选 = 扔掉新来的，§7.4.7）。
- [ ] 过期：`settle` 钩子 20（合同 §7.3）里，`kept` 区 `expires_abs_day` 到了的执行 `expire()`（`on_expire` → 弃牌 → `card_left(uid, &"expired")`），第一次记 first `kept_expire`。
- [ ] `day_end` 钩子 20：手上没处理的生活牌——`due_days` 没到的留到明天，到了的 `expire()`（执行 `on_expire`）。生活牌的 `due_days` 记在牌实例上（例：`vars.due_abs_day`，只用整数）。
- [ ] `resolve(ctx, uid, outcome, extra)`：进弃牌、`card_left`、`card_resolved` 钩子（`extra.almanac` 原样带上）、执行 `on_resolve`；同一张牌重复 resolve 返回不做事（调用方要处理 `already_resolved`）。
- [ ] **打烊时手上剩下的、不必了断的牌**（1.2 已定，§7.4.7 的表）：能留的（消息、当票、信物）**留在手上**，有 `expires_days` 的从发到手上那天起倒计时，到期在 `settle` 20 和留着的牌一起失效（执行 `on_expire`；没看的消息 `on_read` 不执行）；不能留、没有期限的（算命摊这类）归 G02 按 `pass` 处理。

### D. CardComposer（`card_composer.gd`）——每日发牌（§7.4.6、§7.10.11、§9.3）
- [ ] 顺序：日程（修正项 `scheduled_cards`）→ 钉签（`pinned_cards`）→ 队列（`core.queue` 里当天的）→ 按权重随机抽 → `order_hand()` → `cards_dealt` → `deal_composed` 钩子（参数 `{uids}`）。
- [ ] 随机部分：人物张数 = `person.min..max`（`c.deal.n.person [abs_day]`）+ `rep_tier_bonus[口碑档]`（读 `CardMeters.tier(ctx, &"rep")`，桩阶段返回 0）+ 修正项 `deal_count {type:"person", abs_day}` 之和，最少 0；事件 `event.per_day` + `deal_count`；消息按 `news.num/den`（`c.deal.n.news [abs_day]`）；命运牌看修正项 `fate_due`。**`market_bonus` / `rain_penalty` 不由你加**——合同 §7.3 写明天气/集市的 `deal_count` 由 G05 提供（G05 读 `deal.json` 里这两个数），你只加 `rep_tier_bonus`，避免算两遍。
- [ ] 抽牌：`rows` 来自修正项 `pool_rows {pool}`（G05 的 CardWeights；没有提供者时用基础权重 + `conditions`）；`c.deal.<pool> [abs_day, k]`，`k` 存 `core.draw_k[pool] = {abs_day, k}`，同一天加发、读档后再发都接着数（不会重复同一抽）；同一天不重复同一张；`rows` 为空或总权重为 0 时不抽（`JevRng.weighted_choice` 会 `assert`）。
- [ ] **禁签**：抽之前去掉带 `CardPins.banned(ctx, abs_day)` 里任一标签的牌（随机抽和找替身都跳过；日程、主线、效果点名的不受影响）。
- [ ] **钉签**（§7.4.6、§9.3）：钉住的牌永远发——先占它所属牌库的名额；名额已满或那个牌库今天是 0（查封、街头、脚本日都算）就**额外**发一张；那天它的 `conditions` 不满足，用 `c.deal.sub [abs_day, def_id]` 在同牌库里挑一张 `omen_*` 标签有交集、没被禁签的替身。
- [ ] 发牌矩阵（§7.4.6）：查封时人物牌不随机发（G04 的 `deal_count` 给很大的负数，你夹到 0）；`mode == street` 时不发随机人物/事件/消息，改由 `street_deal()` 发 `deal.json.street_per_day` 张（`c.deal.street`）；脚本日（`scripted_days`）随机部分一张都不抽、命运牌也不发。
- [ ] `hand_soft`：随机部分发到手牌总数达到 `caps.hand_soft` 就停（日程、钉签、金色、系统牌照发）。这是对“软上限”的保守理解，标 `# TODO(design)` 并写进 PR。
- [ ] `project(ctx, abs_day)`：**只算不改**（不写 `draw_k`、不改任何命名空间），和 `compose` 走同一段代码（`mutate=false`）；对未来的 `abs_day` 也要判断那天是不是脚本日（按本关第几天算）、用那天的禁签；`deal_count` 修正项的参数带上 `abs_day`（提供者按它判断那天是否查封/集市）。性能 ≤ 3 ms。
- [ ] `night_offers()`：`night_offer` 张（`c.deal.night`，同样用 `draw_k`），只从 `conditions` 满足的夜牌里抽（`mode` 条件决定街头时有哪些）；`street_deal()` 同理。
- [ ] `extra_deal` 发完也触发 `deal_composed`（参数只含这次加发的 uid），这样 G03/G05 在那里记的 first 不会漏。`add_card` 不触发 `deal_composed`（人脉被动的 `deal` 钩子只在发牌时跑）。

### E. 核心效果 op（`core_install.gd`；形状用 `CardDslShapes.shape(op)`，不另写）
- [ ] `add_card {card, to, in_days?}`：`to` ∈ hand/kept/contacts/pending/queue；`in_days > 0` 或 `to:"queue"` 进 `core.queue`（那天早上发，进手牌的走 compose，进其他区的由你在那天的发牌里放进对应区——补上 `scheduled_cards` 的空实现或在 compose 里一并处理）；进手牌后 `order_hand()`；`to:"kept"` 满了走溢出流程；进 `kept` 记 first `keep`。
- [ ] `remove_card {match:{def?,type?,tags_any?}, from, n}`：按 uid 排序后取前 n 张，进弃牌（`card_left(uid, &"resolved")`），不执行 `on_expire`。
- [ ] `waive {match, n}`：免掉待处理牌的坏处——牌被移走，`on_expire` 不执行。
- [ ] `extra_deal {type, n, day}`：`today` 立刻从那个牌库加抽 n 张（接着 `draw_k` 数）；`tomorrow` 记进队列，明天随机部分之外多抽 n 张。
- [ ] 每个 op 都有正例和形状反例单测（`ctx.ops.validate()` 返回非空）。

### F. CardText（`card_text.gd`）
- [ ] `ui(key)` `card(def, field)` `t("<def>#<field>")` `person_name` `item_text` `obs` `is_draft` `issued_contains`，`{name}` 参数代入。
- [ ] 开发版缺正文：`【稿】`标记（读 `data/cards/_dev/strings.json` 的 `draft_mark`，`.gd` 里不写中文）+ brief；发行版（`CardShip.is_ship()`）缺正文返回 `""`。
- [ ] 静态变量只放配置（`setup(db)` 给的 db、草稿标记、给出过的字），`card_t.finish()` 会 `setup(null)` 清掉。

### G. CardValidator / validate_main（`card_validator.gd`、`validate_main.gd`）
- [ ] 补齐 §4.9 表里 NOTE / strict / ship 列的全部规则：V09、V11（引用：牌 id、碎片、人物、模板、轮盘、段、主线节点、`#` 正文引用）、V12、V16（会进手牌或各区、`weight == 0` 的牌必须被日程/效果/扇区/§3.5 系统牌表引用）、V17 全查（每个 年 × 类 × 档 至少一张）、V18、V19、V21、V27（发行检查全量：每张会出现的牌的必填正文、每个用到的界面键、观察键、人物名、物品名、指引步骤 `say`/`bubble`、规矩页 `title`/`body`、F1 帮助键 `c10.help.*`、开场段落 `stage.<年>#intro.p1..n`、电码本的词；`_provenance` 必须是 `human:`；正文里没有 `%`）、V29、V34、V36；**删掉 ship 模式里“关着门”的那条 V27 错误**（全部检查做完以后）。
- [ ] strict 模式 = default 的错 + 表里 strict 列的错（NOTE 升级为错）；ship 模式按 ship 列。
- [ ] `--only=<路径或 glob,…>` 只报这些文件里的问题（引用检查仍看同一套数据的全部）；`--examples`；`--name`；输出格式与退出码不变（§4.9）。
- [ ] **每条规则（V01–V42，含 W0 已做的；V37 见“10-13 变更”、V38–V42 见“10-13 变更二”）各有一个反例夹具**，放 `scripts/tests/cards/G01/fixtures/bad/<规则号>/`（目录结构仿 `data/cards/`，用 `--root=` 指过去），对应模式下报出那条规则的 `DATA ERROR`。正例夹具里需要“合格式的正文”时，值一律用 ASCII 假字（如 `TXT_1`），**不写任何中文正文**。
- [ ] `RULE_KEYS`（V25 必需键）：别的引擎任务新建的规则文件（`loop` `goals_rules` `currency` `items_balance` `weights` `pressures` `daily_wheels`）要你登记必需键——他们开 `[shared] G0x→G01` issue，你在自己的 PR 里加。
- [ ] 全量校验 ≤ 2 s。

### H. first-time 与新手指引的引擎一侧（`firsts.gd`、`core_install.gd`）
- [ ] `CardFirsts.mark/all` 保持 §7.10.6 的语义（W0 已实现）：不在 `CardIds.FIRSTS` 的 `push_error`；只发一次；`args` 只留 `uid def kind person no`。
- [ ] `ui` 命名空间与 `ui.guide`：只改 `ui`；不发事件、不进指令日志、不进哈希；`merge_ui(mem, saved)`（`done` 优先、`shows` 取大）给 G02 的读档与重来本关用。
- [ ] 查询 `firsts`、`guide_data`（去掉 `brief _provenance _test weight era`，加 `settings = rules("guide")`，过隐藏键检查）、`guide_progress`、`guide_conds {ids}`（逐个算步骤的 `trigger.cond`，只回真/假）。
- [ ] 你自己发的 first（见下文“新手指引”一节）放对地方、各一次。

### I. 其他
- [ ] `stage_start` 钩子 50：清理不属于新年代的手牌与待办（`era` 不含新年代、也不是 `*` 的牌进弃牌，不执行 `on_expire`）。
- [ ] 视图（`view_section` 提供者）：只交 `hand kept contacts pending demands` 五个区的 CardView（经 `CardViewModel.card_view`），不放别的顶层键；CardView 里不出现牌的 `tags`（黑名单）。
- [ ] `data/cards/_schema/*.json`：跟着 §4.7 维护（V03 读 `required`/`properties`）。
- [ ] `data/cards/rules/deal.json`：只改数，不改结构；改了在 PR 里说明。
- [ ] `data/cards/ui_keys/G01.json`：你产生的原因键（例 `g01.reason.kept_full`），每个只写 `brief`；`_meta` 写 `{"owner": "G01", "schema": 1, "brief": "…", "_provenance": {"by": "ai", "task": "G01", "date": "<提交当天>"}}`。
- [ ] 每个文件开头两三行中文注释：干什么、主人 G01、参照合同哪一节。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] `day_end` 5：`overflow_uid()` 不空 → 扔掉新来的那张（和关掉 `kept_full` 面板一样：`card.discard {uid: new_uid}` 的语义，不执行 `on_expire`）。
- [ ] `day_end` 20：生活牌 `due_days` 没到的留到明天（`days_left` 减一），到了的 `expire()`；手上能留的牌（`keepable` 为真、不必了断）留着，倒计时照走。
- [ ] 修正项 `end_rows`（§7.3）：上面这几样各交一行 EndRow（`discard` → `g01.end.discard`；生活牌没到期 `wait` → `g01.end.wait {days}`、今天到期 `ignore` → `<def>#outcomes.ignored`；能留的牌 `wait` → `g01.end.wait {days}`，`-1` 不失效）；**交的行和 `day_end` 里真做的一模一样**。键登记在 `ui_keys/G01.json`（只有 brief）。
- [ ] 发牌：每种牌发几张加完修正项 `deal_count` 后按 0 截断；`night_offers()` 也问 `deal_count {type: "night"}`（G06 在牢里过夜时——`ladder.prison.uid` 不空——把夜牌、街头牌减到 0：当晚就没有夜牌，第二天没有街头牌）。
- [ ] 校验 V37（default 是 NOTE，strict / ship 是错）：`must_resolve` 为真的 event、fate、street、big_fate（`bf.wheel` 除外）要有顶层 `check` 或 `effects` 里有 `on_expire` 键（可以是 `[]`）。V27（ship）加一项：有非空 `on_expire`、会进打烊清单的牌要有正文 `outcomes.ignored`（§4.5）。
- [ ] 测试（进清单）：溢出没选时 `day.end` 不被拦、打烊后新来的被扔掉；生活牌 / 消息 / 当票的 `wait` 行与结算一致；`deal_count` 截断；V37 的正反例夹具。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**（一个小 PR，**10-15 前合入**，K 线的演出块等它）

- [ ] `data/cards/_schema/{person,event,fate,big_fate,life,news,street,prison,demand,night,pawn_ticket}.json` 的 `properties` 加 `"stage": {"type": "object", "description": "演出块（§4.7.24）"}`（可选属性，不进 `required`）。别的类型（`self` `contact` `kept` `estate` `dossier_page` `dossier_fragment` `wheel` `wheel_segment` `fortune_lot` `cezi` `almanac_day` `goal` `guide_step` `rule_page` `item`）不加——它们带 `stage` 由 V40 报。
- [ ] 校验器：对每张带 `stage` 的牌调 `CardDslShapes.check_stage(card)`（W0 写好，`scripts/cards/api/dsl_shapes.gd`，返回 `"Vxx: 说明"` 的列表，管 V38、V39 的本地部分、V40、V41），把返回的 `"Vxx: 说明"` 按规则号报 `DATA ERROR`；补：
  - **V39 的登记部分**：`cast` 的 `who` 是登记过的人物（`data/cast.json` + 各 `persons` 块 + `ruhua`；群演 `ex_*` 在 K09 的 `common/extras.json`）——default 是 NOTE、strict / ship 是错；
  - **V42**（default NOTE、strict / ship 错，读美术清单 `data/cards/art/manifest.json`）：`props[].art`；`set` 不是 `counter` 时的 `bg.<set>`；站 `customer` / `companion` 的人的 `portrait.<who>`；群演（`ex_*`）站门口或街上时的 `walk.<who>`（主要人物没有 `walk.*` 不算错）；
  - **V27 的新内容**（ship）：带演出块的牌里每一拍引用的正文字段（`intro` 与 `after.*` 每拍的 `ref`，§4.5 新加的那一行）、W0 的演出旁白键 `w0.stage.enter` `w0.stage.at_door` `w0.stage.leave`、群演的名字；
  - **V30 的改名提示**：步骤的 `anchor` / `anchor_fallback` 用了 1.3 改了名的 7 个旧锚点（`CardIds.ANCHORS_RENAMED` 的键）——default 模式 NOTE（“已改名为 …”），strict / ship 错。
- [ ] `RULE_KEYS` 里登记 G02 的 `loop.json.dusk_pct`（G02 开 `[shared] G02→G01`）。
- [ ] 测试：V38–V42 各一个反例夹具（报对的规则号）；例子集（Claude 在你合入后把演出块挪进去）default 全绿。

规则与模式一览（合同 §4.9）：

| # | 查什么 | 谁查 | default | strict | ship |
|---|---|---|---|---|---|
| V38 | 演出块的形状（键、枚举、个数上限、拍子 `who ref brief`、`ref` 正则、`brief` 非空、`after` 的键） | `check_stage` | 错 | 错 | 错 |
| V39 | 拍子的 `who` 在场（本地部分）；`cast` 的 `who` 已登记（登记部分） | 本地 `check_stage`；登记部分你 | 本地错，登记 NOTE | 错 | 错 |
| V40 | 只有 person event fate big_fate life news street prison demand night pawn_ticket 能带 `stage` | `check_stage` | 错 | 错 | 错 |
| V41 | 站位不冲突；`set` 不是 `counter` 时不许 `street` 站位和 `walk` | `check_stage` | 错 | 错 | 错 |
| V42 | 演出用到的美术在清单里 | 你 | NOTE | 错 | 错 |

**新增 / 作废的交付**

- 新增：11 个 schema 的 `stage` 属性；校验器挂 V38–V42、V27 与 V30 的新内容；V38–V42 的反例夹具（`scripts/tests/cards/G01/fixtures/bad/V38/` … `V42/`）。
- 作废：上文说的“全部规则 V01–V36”——1.2 加了 V37、1.3 加了 V38–V42，全部规则是 V01–V42（上文已就地改）。

**锚点、界面事件、要证明的步骤**

- 引擎照旧不登记锚点。上文“新手指引”表里的旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`a.left.kept` → `a.hand.kept`），你发的 first 和测试不用为此改。

**测试与截图**

- `G01_validator_rules` 加 V38–V42 的反例（每条在它为“错”的模式下报出那条规则的 `DATA ERROR`、只报那条——例外：V40 的反例（例：`kept` 牌带 `stage`）因为那个类型的 schema 没有 `stage`，同时会报 V03“未知字段”，这一条允许两条都报）；V39 的登记部分和 V42 在 default 下只出 `NOTE`；一个步骤用旧名 `a.top.notice` → default 出 `NOTE`、strict 出 V30 的 `DATA ERROR`。
- 一个正例：带合法演出块的夹具牌（照合同 §4.7.24 的两个例子）在 default 下没有错误。
- 截图：无（本任务无界面）。

**已经做了的哪些还有效**

- 全部有效。

**日期**：这个小 PR **10-15 前合入**（交接页检查点；K01–K09、K16 的演出块 PR 等它，合入前它们写了 `stage` 会被 V03 报“未知字段”）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `scripts/cards/core/**`（含 `.uid`）
- `data/cards/_schema/**`
- `data/cards/rules/deal.json`
- 每个任务默认拥有的：`scripts/tests/cards/G01/**`、`scripts/tests/cards/suites/G01.txt`、`data/cards/tags/G01.json`、`data/cards/ui_keys/G01.json`

`core/card_bus.gd` 归你，但**信号表冻结**（§7.6），只能改 `emit_event` 的内部实现。提交前 `git status` 只应出现上面的路径；Godot 顺手改的别人的 `.import`/`.uid`/`project.godot` 一律 `git checkout --`。

## 不能做的事

- **不写任何玩家看得到的最终内容**：不写、不改 `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`。你能写的“文字”只有：`brief`、`_doc`、`_meta.brief`（干巴巴的设计说明，不写成台词或文案，不写引号里的对白）；你写的 JSON 都带 `_provenance`（牌）或 `_meta._provenance`（键文件），标 `{"by": "ai", "task": "G01", …}`。测试夹具里的“正文”只用 ASCII 假字。
- `scripts/cards/**` 下 `.gd` 的字符串字面量只许 ASCII（中文注释可以）；开发者日志与错误信息用英文。
- 不改 `scripts/cards/api/**`、`scripts/cards/mock/**`、`scripts/tests/cards/lib/**`、`tools/run_*.sh`、`project.godot`、任何已有文件（`scripts/{core,sim,ui,town,audio,persona}/**`、`data/*.json`、`data/town/**` 等）；要它们改，开 `[api]` / `[shared]` issue。
- 不改冻结签名（§7.9 G01 段、§7.3 登记表、§7.6 信号）；新公开函数可以加，PR 里列出。只有冻结表里的类写 `class_name`；辅助脚本用 `const X = preload("res://…")`。
- 不在引擎里用 `randf/randi/randomize/RandomNumberGenerator/Time/OS.get_ticks*` 影响状态；随机只经 `ctx.draw(domain, key)`，domain 只用 §6.3 里归 G01 的；状态里不许有浮点。
- 不许有可变 `static var`（`CardSave` 的根目录、`CardText` 的配置除外）；引擎不 `await`、不碰场景树、不读输入。
- 引擎代码不连 `ui_event`；`ui.guide` 以外不碰 `ui` 命名空间；指引开不开都不改状态。
- 视图、查询、事件参数里不出现 §7.5 的隐藏键；不往视图里放概率、权重、牌的标签。
- 不自己加玩法；合同没写的用最保守的做法 + `# TODO(design): …` + PR 列出。

## 接口

**提供（冻结签名，§7.9 G01 段）**：`CardDB`（`load_all def has ids_of pool persons rules tags text_entry brief_of obs_catalog art_manifest stage hash errors`，W0 另加的 `file_of order_of guide_test ui_keys all_ids read_json list_json …` 保留）· `CardState` · `CardCtx` · `CardOps` `CardConds` `CardMods` `CardHooks` `CardActions` · `CardPiles`（`spawn move zone_of list card def_of keep resolve order_hand discard expire cap`，新加 `overflow_uid`）· `CardComposer`（`compose project night_offers street_deal`）· `CardSave` · `CardText` · `CardValidator` · `CardFirsts` · `CardEventBus`（信号表冻结）。

**登记（`CardCoreInstall.install`）**：
- 指令：`card.keep` `card.discard` `ui.guide`（§7.4）
- 查询：`firsts` `guide_data` `guide_progress` `guide_conds`
- 效果 op：`add_card` `remove_card` `waive` `extra_deal`（§5.2）
- 修正项提供：`scheduled_cards`（队列）、`view_section`（五个区）、`*` 动作（`open` `keep`）
- 钩子：`stage_start` 50（清理旧年代的牌）· `day_end` 5（留牌溢出没选 → 扔掉新来的）· `day_end` 20（生活牌留到明天/到期、手上能留的牌留着）· `settle` 20（留着的牌、手上能留的牌过期）（§7.3 钩子表）
- 修正项提供（1.2）：`end_rows`（溢出、生活牌、手上能留的牌那几行，§7.4.7）
- 随机数域（§6.3，只许用这些）：`c.deal.<pool>`（pool ∈ person event news fate life big_fate night street）`[abs_day, k]` · `c.deal.n.person` · `c.deal.n.news` `[abs_day]` · `c.deal.sub` `[abs_day, def_id]`

**用到（只读或经修正项/钩子）**：修正项 `deal_count`（G03 G04 G05 G06 提供）、`pool_rows`（G05）、`pinned_cards`（G05）、`fate_due`（G05）、`scheduled_cards`（G02 也提供）、`cap`（G03 G06）、`hand_sub`（G02）；`CardPins.banned`（G05 桩）、`CardMeters.tier`（G03 桩）、`CardDayLoop.request_panel`（G02，W0 已能用）、`CardViewModel.card_view`（G02）。桩阶段这些返回空/0，你的代码要对空结果稳健。

**与别的线的约定（PR 里写明）**：
- G02 的门面用你的 `CardPiles.overflow_uid()` 拦别的指令（返回 `overflow_pending`）。
- `deal_count` 的参数带 `abs_day`（你是唯一的调用方；提供者用 `args.get("abs_day", ctx.abs_day())`）。这点和 `market_bonus/rain_penalty` 由 G05 加，一起开 `[api] G01: deal_count 参数与 deal.json 三个加成由谁算` 让 Claude 在合同里写明。

## 新手指引

- **锚点**：引擎不登记锚点（锚点是界面部件的事，§7.10.4）。
- **你必须发的 first-time**（`CardFirsts.mark`，`args` 只放 `uid def kind person no`）：

| 机制 | 什么时候 mark | args | 对应的指引步骤（教的人 · 锚点） |
|---|---|---|---|
| `deal` | 第一次 `compose()` 真的发出了牌（第 1 天 `day.begin`） | `{}` | `gd.d1.deal`（brother · `a.hand`） |
| `person` | 第一张人物牌进手牌（compose、`extra_deal`、`add_card` 任一路径） | `{uid, def}` | `gd.d1.person`（brother · `a.card@{uid}` 备 `a.hand`） |
| `keep` | 第一次手上有能留的牌（`keepable` 的牌进手牌），**或**第一次有牌进 `kept`，两者先到的那个 | `{uid, def}` | `gd.d2.keep`（brother · `a.card.keep@{uid}` 备 `a.hand.kept`） |
| `kept_expire` | 第一次有留着的牌过期（`settle` 20） | `{uid, def}` | `gd.kept_expire`（obj.brother_ledger · `a.hand.kept`） |
| `kept_full` | 第一次留牌满了还要进一张（`card.keep` 或 `add_card to:kept`） | `{uid}` | `gd.kept_full`（obj.brother_ledger · `a.slots.discard`） |
| `life` | 第一张生活牌进手牌 | `{uid, def}` | `gd.life`（obj.brother_ledger · `a.card.days@{uid}`） |
| `news` | 第一张消息牌进手牌 | `{uid, def}` | `gd.news`（zhouma · `a.card@{uid}` 备 `a.hand`） |

- **你支持的步骤**：上表的步骤；另外 `guide_data/guide_progress/guide_conds/firsts` 四个查询是 C16 指引引擎（`CardGuide`）和 C10 规矩页的数据来源，所有步骤都靠它们。
- **指引验收（必须有测试）**：
  1. 上表每个机制：触发一次 → 恰好一条 `first_time`（参数只含白名单键）；再触发 → `mark` 返回 false、不发信号；存→读之后再触发 → 不发。
  2. `firsts` 进状态哈希、`ui` 不进；`ui.guide` 不发任何事件（连 `command_done` 都没有）、不进指令日志；读档时 `ui` 取并集。
  3. `guide_data` 对 `_examples/guide/` 返回文件顺序的步骤、去掉了 `brief` 等字段、`CardViewModel.leaks()` 为空；`guide_conds` 只回真/假。
  4. 新存档（种子 7、例子集）第 1–3 天你负责的 first 的先后：`deal` 早于 `person`（同一次 `day.begin` 内，事件顺序按发生顺序）；第 2 天能留的 `kp.brother_note`（听哥哥交代完由 `add_card to:kept` 发）触发 `keep`。G02 的 `G02_firsts_d1_3` 会把全部机制串起来比对 `_test.d1_3`，你的顺序要和它一致。
- **截图**：本任务无界面，不交截图（新手指引每一步的截图由 C16 `shot_guide.gd` 与 K14 `shot_guide_d1_3.gd` 出）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/G01.txt`（名字只用 ASCII，和 `t.finish()` 打印的一致）：

```
# 名字|脚本|超时秒|参数
G01_validator_rules|res://scripts/tests/cards/G01/test_validator_rules.gd|240|
G01_db|res://scripts/tests/cards/G01/test_db.gd|120|
G01_state_save|res://scripts/tests/cards/G01/test_state_save.gd|120|
G01_piles|res://scripts/tests/cards/G01/test_piles.gd|120|
G01_composer|res://scripts/tests/cards/G01/test_composer.gd|240|--seeds=50
G01_ops|res://scripts/tests/cards/G01/test_ops.gd|120|
G01_text|res://scripts/tests/cards/G01/test_text.gd|120|
G01_firsts|res://scripts/tests/cards/G01/test_firsts.gd|120|
G01_guide_queries|res://scripts/tests/cards/G01/test_guide_queries.gd|120|
```

**每条必须证明的事（合同 §3.2 G01 验收 + §12.2）**：
- [ ] 校验器对 `_examples` default 模式全绿（W0 的 `W0_validate_examples` 继续绿）；V01–V42 每条规则一个反例夹具，在该规则为“错”的模式下报出 `DATA ERROR`，且只报那条规则。
- [ ] 同种子同状态 `compose()` 两次结果相同；`project(d)` 与第 d 天实际发的随机部分一致（无新钉签、状态不变时）；`project()` 前后状态哈希不变。
- [ ] 同一天加发（`extra_deal`）后存→读再加发，不会重复同一抽（`draw_k` 接着数）。
- [ ] 脚本日（`scripted_days`）不抽随机牌，对未来的脚本日 `project()` 也返回空。
- [ ] 钉住的牌一定发：名额满了、牌库今天是 0（查封/街头/脚本日）都额外发；条件不满足时发同征兆替身；禁签的标签在随机抽和替身里都被跳过。
- [ ] 存→读→哈希相同；`find_floats(state)` 为空（发牌、加发、溢出、过期之后都查）。
- [ ] 所有区的上限与过期按 `deal.json`；任何插入之后手牌顺序都符合 §10.2（金色 > 牢房 > 大命运 > 事件 > 命运 > 人物 > 生活 > 消息，同类按 `hand_sub`、`seq`）。
- [ ] 留牌满了再进一张走溢出流程（两种来源：`card.keep`、`add_card to:kept`）；`card.discard` 扔旧的 → 新的进 `kept`；扔新的 → 旧的不动；扔掉的不执行 `on_expire`；`overflow_uid()` 正确。
- [ ] 四个核心 op 正例 + 形状反例。
- [ ] 上面“新手指引”一节的 1–4。
- [ ] 改 `ui` 不改哈希、`ui.guide` 不进指令日志。
- [ ] 确定性：同种子同指令两遍哈希一样；任意阶段（`morning`、`month_open`）存→读→继续，哈希和不存档连续跑一样。
- [ ] 用到的随机域都在 §6.3 G01 名下（开发版 `ctx.draw` 没登记会 `push_error`，测试日志里出现就是失败）。

**W1 测试替身**：别的模块还是桩时，测试里自己往 `ctx.mods` 登记假的 `pinned_cards` / `deal_count` / `pool_rows` 提供者（可以像 W0 `test_engine.gd` 的 `_ctx_with()` 那样另建一份 `CardCtx`，只登记你要的），不要等 G05/G04。

**性能**（§12.4；测墙钟的脚本**不进清单**——清单里的测试不许依赖墙钟）：写 `scripts/tests/cards/G01/bench_core.gd`（无头跑：用脚本在 `t.user_dir()` 下生成约 600 张合成牌的数据根，测 `CardDB.load_all` ≤ 300 ms、全量校验 ≤ 2 s、`project(d)` ≤ 3 ms、`compose` 进 `day.begin` 的预算、存档 ≤ 512 KB / 写 ≤ 50 ms），把数贴进 PR 和“回报”。

**怎么跑**：
```
GODOT=<你的 Godot 4.7> CARDS_SUITES=G01 tools/run_card_tests.sh   # 开发时只跑自己的
GODOT=<你的 Godot 4.7> tools/run_card_tests.sh                    # 提审前全量卡牌测试
GODOT=<你的 Godot 4.7> tools/run_legacy_smoke.sh                  # 旧版冒烟
```
**通过条件**：两个脚本退出码 0；日志里没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有退出泄漏；每个清单测试最后一行是 `CARDS TEST PASS <名字>`。全量 `tools/run_tests.sh` 由 Claude 合并时跑（你有时间也可以本地跑，它末尾会调卡牌测试）。

**截图**：无（本任务无界面）。

## 交付

- **PR 标题**：`[G01] <中文摘要>`，目标分支 `claude/festive-ride-vud32a`。建议拆成：
  1. `[G01] 牌堆溢出与过期、核心四个 op、overflow_uid`（尽早合，别的线要用）
  2. `[G01] 发牌：钉签名额与替身、禁签、发牌矩阵、project 对未来日`
  3. `[G01] 校验器补齐 NOTE/strict/ship 与每条规则的反例夹具`
  4. `[G01] 存档、正文、性能与 first-time 收尾`
- **PR 描述**按 `.github/pull_request_template.md` 每节填满，另外必须有：
  - 改动路径清单（全部在 G01 名下）；
  - 用到的 JevRng 域（只列 §6.3 G01 的）；
  - 发的 first-time 及触发位置（文件:行）；
  - 新加的公开函数（至少 `CardPiles.overflow_uid`）；
  - `deal_count` 参数加 `abs_day`、三个加成谁算的说明，以及对应 `[api]` issue 号；
  - 校验器每条规则对应的反例夹具路径表；
  - 黄金哈希有没有变（G06 的 `golden.json` 合入后），变了解释原因；
  - bench 测得的数；
  - 需要主创/编排决定的事（至少：`hand_soft` 的理解）；
  - 全部完成的那个 PR 写“交付”。

## 审核（Claude 会逐条看）

1. `check_pr_paths.py` 通过；只动了 G01 的路径；`card_bus.gd` 信号表一字未改。
2. 冻结签名没变；新公开函数列出；登记的指令/op/查询/钩子 priority 与 §7.3、§7.4 一致；没有新 `class_name`。
3. 确定性：没有 `randf/Time/OS.get_ticks*` 影响状态；字典遍历先排序；随机键只有整数和字符串；`draw_k` 正确续数；`project()` 真的不改状态（测试里比哈希）。
4. 钉签“永远发”在名额满、查封、街头、脚本日四种情况下都成立（这是 G05 签准不准的根基）。
5. 溢出流程两种来源、两种扔法都对；`overflow_uid` 给 G02 用的语义清楚。
6. 校验器：每条规则都有反例；strict/ship 的升级正确；ship 模式不再“关着门”；V27 覆盖指引步骤、规矩页、F1 帮助键、开场段落、电码本。
7. 存档：信封格式、`save_newer`、未知命名空间保留、`ui` 合并、无浮点。
8. 隐藏信息：`guide_data`、CardView 无黑名单键；牌的 `tags` 不进视图。
9. 免 AI 声明：没有正文；夹具只用 ASCII 假字；`.gd` 字面量无中文。
10. 新手指引：七个 first 各在对的地方、各一次，存读后不再发；`ui` 不进哈希。
11. 函数 ≤ 80 行、无调试打印、错误返回码不崩；bench 数在预算内。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| bench：`load_all` / 全量校验 / `project()` / 存档大小与写入耗时 | |
| 用到的随机域 | |
| 发的 first-time 及位置 | |
| 新加的公开函数 | |
| 开的 issue（`[api]` / `[shared]` / `[design]`） | |
| 悬空依赖（等哪条线的什么） | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
