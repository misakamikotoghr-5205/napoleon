# G05 `fate-fortune` · 牌库权重、命运与大命运、命运轮盘、求签测字、黄历

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.2 G05 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] G05: …` issue。

## 执行者与线号

- 执行者：**GPT**
- 线号：**GPT 线 5**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 你的类、指令、查询、效果/条件 op 都已登记成桩；`CardAlmanac.today` 有最小版 | W0（已完成） |
| G01 | `CardComposer.project()`（W0 的桩已可用）、钉签的名额与替身、禁签在发牌里生效、`extra_deal`、`CardPiles.spawn` | W1（先合） |
| G02 | `CardCalendar.is_market_day/week_of`（W0 已能用）、`CardSchedule.due(ctx, 未来某天)`（G02 补）、`CardDayLoop.request_panel` | W1（G02 在你之后合） |
| G03 | `CardMeters`（口碑/风声档、本心）、`CardSlots.mark_person_used`（G03 新加：香案上的人脉“当天算用过”） | W1（在你之前合） |
| G06 | 修正项 `pool_pct`（家当：老宅押出生活牌变多）；`arrested` 钩子；家当状态（危机判断读 `ladder` 命名空间，只读） | W1（在你之后合） |
| K10 | 轮盘、扇区、签、测字、黄历的真数据——**对着 `_examples/fortune/` 先做** | W1 数据线 |

- **你所在的波次**：W1；合并顺序 G01 → G03 → **G04/G05** → G06 阶梯 → G02。
- **W2**：K10 的真数据（每年 6–8 段运势、大轮盘三类、≥30 支签、12–16 个字、≥24 条黄历）上跑签的准确性与轮盘单调性；平衡报告里签准确率必须 100%（G06 统计）。

## 分支

`cards/G05-fate-fortune`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase` 跟上。

## 目标

做出“随机从哪里来”的那一层：每个牌库的整数权重；命运牌的频率与快输时的大轮盘（大命运只发 `bf.wheel` 这一张）；三种命运轮盘（本月运势、大轮盘、庙会/赌摊）与香案加宽、押牌；**签是准的**（读未来发牌 + 钉签）、测字的“无”也准（禁签）、本心低时签更凶；每天的黄历宜忌与照做的小好处；时局压力与天气。界面上只看得到扇区大小、签诗与解曰的键，看不到任何权重、份数、好坏、百分比。

## 必读

1. 合同 §0（红线 2、3）、§2.2、§2.5（**封闭的 `omen_*` 征兆家族**与 `bad_omen`）、§3.2 G05、§4.6（`fate.json` `fortune.json`）、§4.7.3（`opens_fortune` `opens_wheel` `cost`）、§4.7.4（fate 的 `valence`）、§4.7.5（big_fate：只有 `bf.wheel` 由你发）、§4.7.17（wheel / wheel_segment：`arc` `valence` `conditions` `month_mods` `effects`）、§4.7.18（签、测字、黄历）、§5.2–§5.3 里归 G05 的 op、§6（`fate` 命名空间、随机写法、域表——**轮盘的 rows 例外：按显示顺序**）、§7.3（修正项与钩子表里归 G05 的行）、§7.4（`wheel.*` `fortune.*` 指令，`wheel` `fortune` `almanac` 查询，**§7.4.4 轮盘指令**、§7.4.6 钉签与禁签）、§7.5（视图黑名单：`weight weights arc units valence pins pinned foretold hint_tags tags …`）、§7.9 G05 段、**§9 全章**、§7.10.10、§12、§13–§14、**§7.5 的 1.3 增补（CardView 的 `wheel` `fortune`）**。
2. `docs/cards/DESIGN_cards.md` §三.6（命运牌和大命运）、§三.9（本心决定大命运出现哪几张）、§三.12（牌库怎么变）、**§九.1、§九.2**、文末“实现时的理解”第 2–7、17 条。
3. W0 代码：`scripts/cards/fate/*.gd`（你的起点）、`scripts/cards/core/card_composer.gd`（`project()`、`_random_part`、`pool_rows`/`pinned_cards`/`fate_due` 怎么被用）、`scripts/cards/loop/calendar.gd`、`scripts/cards/loop/schedule.gd`、`scripts/cards/loop/view_model.gd`（`notice` 里怎么读你的天气、黄历、运势）。
4. 只读复用：`scripts/sim/pressure_model.gd`（`PressureModel.step(pack, s)` / `add_influence`，域 `"pressure:" + key`、键 `[s.day]`）、`scripts/sim/world_wheel.gd`（`WorldWheel.spin(pack, s, wheel, effect)`，域 `"wheel:" + wheel.id`）、`scripts/sim/jev_rng.gd`（`weighted_choice` 对空表/零权重会 `assert`）。这两个旧模块在自己的 `s` 字典里写**浮点**、默认难度键是中文——**只给它们一个临时字典**（`{seed, day: abs_day, difficulty: "normal", pressures: {…浮点…}, influence_spent, day_report, wheel_last}`），算完把压力换成千分整数存进 `fate.pressures_milli`，临时字典丢掉；`pack` 由你的 `pressures.json`、`daily_wheels.json`（全整数、ASCII）在运行时拼成浮点，不读 `data/town/town_pack.json`（它不进 Steam 包）。
5. 数据：`data/cards/rules/{fate,fortune}.json`（你的）、`data/cards/_examples/fortune/*.json`、`data/cards/_examples/era/common/{events,big_fate,fate}.json`、`data/cards/tags/W0.json`（征兆家族）。

## 要做的事

### A. 牌库权重（`weights.gd`）
- [ ] `rows(ctx, pool)` → `[[def_id, weight_int]]`（按 def_id 排好）：只含当年、`conditions` 满足的牌；权重 = 基础 `weight` × 年代 × 口碑/风声档 × 天气/集市 × 本月运势段的 `month_mods`（`pool` + `tags_any` 或 `valence`）× 临时 `deck_mods`（`deck_mod` op，带天数）× 修正项 `pool_pct {pool, def}`（G06 家当）——全部整数百分比，逐步 `× pct ÷ 100` 向下取整；系数表写进新建的 `weights.json`。权重为 0 的不进表。登记为修正项 `pool_rows {pool}` 的提供者。
- [ ] 修正项 `deal_count {type, abs_day}` 的天气/集市部分（合同 §7.3 写明由你提供）：`type == person` 时集市日 `+deal.json.person.market_bonus`、下雨 `−deal.json.person.rain_penalty`（读 G01 的 `deal.json`，只读）。G01 不再重复加。

### B. 命运与大命运（`fate_trigger.gd`）
- [ ] `fate_due(ctx)`（修正项 `fate_due`）：按 `fate.json.fate`（`min_gap` `max_gap` `num/den` `heat_tier_bonus`）与 `fate.fate_last_abs_day` 决定今天发不发（`c.fate.due [abs_day]`）；**只读**（`project()` 会调）；真的发了在 `deal_composed` 30 里记 `fate_last_abs_day`。
- [ ] `crisis(ctx)` → `&"" / cash_short / arrested / heat_max / street_long`（阈值在 `fate.json.big.crisis`；家当剩几件读 `ladder` 命名空间、街头天数读 `ladder.street`，只读）；`on_crisis(kind)`：经 `big_wheel` op 发一张 `bf.wheel` 到手上——**大命运只发这一张**；每关上限 `max_per_stage`、同一危机一次（`fate.big.crises_used`）。监听 `money_short` 10、`arrested` 10；`heat_max`、`street_long` 在 `day_start` 10 里查。
- [ ] 其他 `bf.*` 一律 `weight: 0`，只由大轮盘扇区的效果（`add_card`）发到手上——你的代码不随机发它们。

### C. 命运轮盘（`wheel.gd`，§9.1–§9.2、§7.4.4）
- [ ] 状态按 `fate.wheels["<轮盘 id>:<牌 uid>"] = {spin_no, incense:[…], stake, result:{segment, stop_mdeg}}` 分开记；本月运势 uid 为 `""`；两张同种轮盘牌各转各的。
- [ ] 段：当年（`wh.big` 另加 `["*"]` 通用段）、`conditions` 满足的段才上盘（**算视图和转的时候都查**；本心不够的大轮盘段不上盘）；按数据顺序从 12 点钟方向顺时针排。
- [ ] 份数 U = 香火钱 ÷ `money_per_unit`（向下取整）+ 每张留着的牌的 `incense_units`（默认 1）+ 每个人脉的 `contact_attr` 属性点，U ≤ `max_units`（轮盘没写就用 `fortune.json.wheel` 的默认）。权重（整数）：好段 `w = arc × (100 + U × unit_widen_pct)`，其余 `w = arc × 100`；`weights(wheel, uid)` 只在引擎内部用。
- [ ] `view(wheel, uid)` → WheelView（§9.1）：`segments:[{id, arc_deg, art}]`（`arc_deg = 360 × w / Σw`，只在视图里是小数）、`incense {accepts, placed, full}`、`cost {money, stake}`、`staked`、`spun`、`result {segment, stop_deg}`；**不给权重、份数、好坏**。查询 `wheel {wheel, uid}`。
- [ ] `offer {wheel, uid, source}` / `withdraw {wheel, uid, index}`：香案收 `money` `kept` `contact`（看轮盘的 `incense.accepts`）；第一次放记 first `incense`；放人脉/留牌的规则同放格子（人当天用过不能再放）。
- [ ] `stake {wheel, uid, kept_uid}`：代价是押牌的轮盘，转之前必须押一张留着的牌，否则 `wheel.spin` → `stake_required`。
- [ ] `spin {wheel, uid}`：先扣代价（钱不够 → `insufficient_money`，**什么都不改**）→ 付掉香火钱（经 `pay` op）、用掉香案上的留牌、人脉当天算用过（调 G03 的 `CardSlots.mark_person_used`——G03 合入后 rebase 接上，之前标 `# TODO(G03 mark_person_used)`）→ `u = ctx.draw("c.wheel." + wheel_id, [abs_day, uid, spin_no])`，`JevRng.weighted_choice(rows, u)`，**rows 按显示顺序**，于是 `stop_deg = 360 × u` 正好落在选中段里；存 `stop_mdeg`（千分之一度整数）；发 `wheel_spun(wheel_id, segment, stop_deg)` → 执行段的 `effects` → 押的牌落在 `bad` 段没了、否则还回来【待调】→ 牌 `CardPiles.resolve`（本月运势没有牌）。
- [ ] 本月运势：`month_open` 10 里 `CardDayLoop.request_panel(ctx, &"wheel", {"wheel": "wh.month", "uid": "", "required": true})`，第一次记 first `month_wheel`；转完 `fate.month_segment` = 段 id、`fate.month_mods` = 段的 `month_mods`（作用一整关）；`stage_start` 30 清掉上一关的运势与大命运计数。
- [ ] 大轮盘：`bf.wheel` 在手上，点牌开 `wheel` 面板（`opens_wheel: wh.big`）。庙会/赌摊：事件牌带 `opens_wheel` + `cost`，或 `wheel_offer` 发的系统牌 `ev.any.wheel_go`（`vars: {wheel, cost}`，用 `CardPiles.spawn(ctx, "ev.any.wheel_go", &"hand", {"vars": …})` 发）。

### D. 求签与测字（`fortune.gd`、`pins.gd`，§9.3）
- [ ] `fortune.lot {uid}`（`uid` 是带 `opens_fortune` 的事件牌）：付 `cost` → 窗口 W = `lot.window_days`（明天起）→ 候选 = `CardComposer.project(ctx, d)` 的随机部分 ∪ `CardPins.pinned(d)` ∪ `CardSchedule.due(ctx, d)`，只取 event fate person life news big_fate、带 `omen_*` 的 → 挑 `lot.pick` 张（`c.lot.pick [abs_day, lot_count, k]`，权重各 100；本心 ≤ `conscience_harsh_below` 时，命运牌 `valence: bad` 的、其他类型带 `bad_omen` 标签的乘 `harsh_bias_pct`）→ 等第（挑出的牌坏的多 → 低、好的多 → 高、一好一坏 → 中；映射写进 `fortune.json`）→ 选签：同等第里 `hint_tags` 与挑出的牌的 `omen_*` 有交集的签按 `c.lot.verse [abs_day, lot_count]` 抽一支，没有就用同等第的泛泛签 → **钉签** `CardPins.pin(ctx, d, def, "lot:<n>")` → `lot_count += 1` → 返回 `{lot, grade}`；视图 `lots` 记 `{lot, abs_day}`。**哪几张牌、哪天来，绝不进视图、事件、查询。**
- [ ] `CardPins`：`fate.pins {abs_day: [def…]}`、`fate.bans {abs_day: [tag…]}`；`pinned()` 是修正项 `pinned_cards {abs_day}` 的提供者；过去的日子清掉。钉住的牌“名额满了就额外发、条件不满足换同征兆替身”由 G01 的发牌做（`c.deal.sub` 是 G01 的域），你只负责记。
- [ ] 测字：`offer_chars()` 今天摊上摆 `cezi.offer` 个字（`c.cezi.offer [abs_day, uid]`）；查询 `fortune {uid}` → `{cost, can_lot, can_cezi, cezi:[char id], last:{lot, grade}}`；`fortune.cezi {uid, char}`：窗口里有带这个字 `tags`（`omen_*`）的牌 → 读法 `has` 并钉住那张；没有 → `none`，给窗口里每一天 `CardPins.ban(ctx, d, 字的 tags, "cezi:<n>")`（随机抽和找替身都跳过；日程、主线、效果点名的不受影响）。返回 `{char, reading}`。
- [ ] 效果 `peek {pool, n}`（小丁“提前看明天一张事件”）：`project()` 算出来并钉住，再发 `notice`（所以看到的一定会来）。

### E. 黄历（`almanac.gd`，§9.4）
- [ ] `day_start` 10：`c.almanac [stage, stage_day]` 从当年、当季（`season`）的 `almanac_day` 按权重挑一条 → `fate.almanac = {id, done: []}`；`today()` 返回 `{id, yi, ji, done}`（宜忌动作名；正文用界面键 `g05.almanac.<动作>`）。第一次记 first `almanac`（第 1 天就有，步骤第 4 天才亮）。
- [ ] `note(actions)`：`card_resolved` 10（参数里的 `almanac`）、`night_chosen` 10（夜牌的 `almanac` 字段）、你自己往香案放东西时记 `pray`；只记黄历动作枚举里的。
- [ ] `settle` 50：今天做了至少一样宜的、没做任何忌的 → 执行那条的 `reward`，并发一条 `notice`（G02 收进日结报告）；否则什么都不发生（不罚）。

### F. 时局压力与天气（`pressure.gd`）
- [ ] `step_day`（`day_start` 10）：`PressureModel.step` 推进压力（键以 `c_` 开头 → 域 `pressure:c_<key>`）；`WorldWheel.spin` 转天气轮盘 `c_climate`（域 `wheel:c_climate`）→ `fate.weather`；**集市日不抽**，读 G02 的 `CardCalendar.is_market_day`。第一个不是晴天的早上记 first `weather`、第一个集市日记 first `market_day`。
- [ ] `value_milli(key)`；效果 `pressure {key, delta_milli}`（经 `PressureModel.add_influence`，换成浮点再换回千分整数）、`weather {value}`（改今天/明天的天气）。
- [ ] 新建 `pressures.json`、`daily_wheels.json`（整数、ASCII、`_meta.owner: "G05"`），开 `[shared] G05→G01` 登记必需键。

### G. 其他效果 op、条件 op、修正项、视图
- [ ] 效果：`deck_mod` · `fate_now {day}`（经 G01 的 `extra_deal {type:"fate"}`，不自己从命运牌库抽——`c.deal.fate` 是 G01 的域）· `big_wheel {crisis}` · `wheel_offer {wheel, cost?}` · `pressure` · `weather` · `peek`。每个正例 + 形状反例。
- [ ] 条件：`weather` · `market_day`（读日历，不另抽）· `pressure_gte` · `fortune`（本月运势段）· `almanac_yi`。
- [ ] 修正项提供：`pool_rows` `pinned_cards` `fate_due` `deal_count`（天气/集市）`price_pct`（运势里有价格修正时）`view_section`（`lots`）`card_view_part`（轮盘/算命牌：`panel` 之外需要的看得见的信息，如代价钱数）。
- [ ] 钩子监听（§7.3）：`stage_start` 30 · `month_open` 10 · `day_start` 10 · `deal_composed` 30 · `card_resolved` 10 · `night_chosen` 10 · `settle` 50 · `settle` 60（命运计数）· `money_short` 10 · `arrested` 10。
- [ ] **查询结果的形状和 Mock 一样**：界面任务是对着 `MockCardEngine`（`scripts/cards/mock/mock_scenario.gd` 的 `query()` 与十个夹具）写的，W2 换真引擎时形状必须一致。`wheel` → WheelView、`fortune` → `{cost, can_lot, can_cezi, cezi, last}`、`almanac` → `{id, yi, ji, done}`。
- [ ] **界面在等你的（C06 卡里列为合同缺口，PR 里列出）**：轮盘类的牌（`bf.wheel`、`ev.any.wheel_go`、带 `opens_wheel` 的事件）的 CardView 经 `card_view_part` 加 `wheel`（轮盘 id），C06 靠它知道开哪个盘。（10-13：合同 1.3 已把 `wheel` 写进 §7.5，不再是缺口；另加 `fortune`，见下方“10-13 变更二”。）
- [ ] `data/cards/rules/{fate,fortune}.json` 只改数；新建 `weights.json`；`data/cards/ui_keys/G05.json`：`g05.almanac.<动作>`（§9.4 的 12 个动作）、`g05.reason.*`（香火钱、庙会/赌摊的代价）、`g05.notice.*`（偷看到明天的牌、黄历照做的小好处）；只写 `brief`；`_meta._provenance = {"by":"ai","task":"G05","date":"<提交当天>"}`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] `day_end` 15：手上的 `bf.wheel` 没转 → 作废（`card_left(uid, &"expired")`；计入 `fate.big.stage_count`、这种危机记进 `crises_used`，不因为没转再补发——这次翻身的机会错过了）；开着没转的轮盘（香案上放了东西、押了牌）→ 都还回来，不扣香火钱、不用掉留牌。
- [ ] 修正项 `end_rows`：`bf.wheel` 一行 `void`（`g05.end.void`，登记在 `ui_keys/G05.json`）。
- [ ] 月初本月运势没转、玩家按了“打烊 · 下一天”：G02 调你的 `CardWheel.spin(ctx, "wh.month", "")`，结果和玩家自己转一样（香案上已放的照算、发 `wheel_spun`、记 `fate.month_segment`）。
- [ ] 算命摊、庙会、赌摊、`ev.any.wheel_go` 是 `must_resolve: false` 的“今天的机会”：打烊时 G02 按 `pass` 让它们走，你不用管。
- [ ] 测试 `test_end_day.gd`（清单 `G05_end_day`）：`bf.wheel` 不转就打烊 → 作废、同一危机不再发；香案放了钱和留着的牌、不转就打烊 → 钱和牌都在；月初替转的结果与 `wheel.spin` 一致（同种子同香案同段）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**（合同 §7.5 的 1.3 增补；签名一个不改）

- [ ] `card_view_part` 加 `wheel`（这张牌处理时开哪个轮盘：`bf.wheel` → `"wh.big"`；`ev.any.wheel_go` → 它的 `vars.wheel`；带 `opens_wheel` 的 → 它的值；否则 `""`）与 `fortune`（带 `opens_fortune` 的牌：`"lot"` `"cezi"` `"both"`；否则 `""`）。1.2 的缺口“轮盘牌的轮盘 id”就此关闭；`fortune` 不空的事件，W0 的默认演法让算命先生 `suanming` 站到柜台前。
- 1.3 只改界面这一层：轮盘仍是叠层（C06），算命成了算命先生那一出、签诗与解曰在对话框里说（C07），黄历条进了顶部 HUD；`wheel.*` `fortune.*` 指令和 `wheel` `fortune` `almanac` 查询的形状都不变。

**新增 / 作废的交付**

- 新增：CardView 的 `wheel` `fortune`。
- 作废：无（上文 G 节“界面在等你的”那条已就地标出：1.3 已写进合同）。

**锚点、界面事件、要证明的步骤**

- 引擎照旧不登记锚点；上文“新手指引”表里的锚点 1.3 没有改名（`a.top.weather` 仍是 C01 的，在 HUD 里）。

**测试与截图**

- `G05_view_leaks` 加一条：`bf.wheel` 的 `wheel == "wh.big"`、`ev.any.wheel_go` 的 `wheel` 等于它的 `vars.wheel`、带 `opens_wheel` 的事件等于那个值、别的牌 `""`；`opens_fortune` 为 `lot` / `cezi` / `both` 的牌 `fortune` 对、别的牌 `""`；`leaks()` 为空。
- 截图：无（本任务无界面）。

**已经做了的哪些还有效**

- 全部有效。

**日期**：跟你 10-23 合入的 PR 一起交。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `scripts/cards/fate/**`（含 `.uid`）
- `data/cards/rules/weights.json`、`data/cards/rules/fate.json`、`data/cards/rules/pressures.json`、`data/cards/rules/daily_wheels.json`、`data/cards/rules/fortune.json`
- 默认拥有：`scripts/tests/cards/G05/**`、`scripts/tests/cards/suites/G05.txt`、`data/cards/tags/G05.json`、`data/cards/ui_keys/G05.json`

（`bad_omen` 已从 `tags/G05.json` 移到 `tags/W0.json`，你不用再声明它。）

## 不能做的事

- **不写玩家最终内容**：签诗、解曰、测字的提示、扇区名、黄历宜忌的字都由人写；你只登记键和 brief；不碰 `data/cards/text/**` 等人写路径；测试夹具“正文”只用 ASCII 假字。
- **不泄露隐藏数值**：视图、查询、事件里没有权重、份数、好坏（`valence`）、百分比、钉签内容、本心；`WorldWheel.rows()` 的归一化概率只给开发者，绝不进视图；界面上扇区只有大小。
- **不改 `scripts/sim/pressure_model.gd`、`world_wheel.gd`、`jev_rng.gd`**（只调用）；不读 `town_pack.json`；不改 `api/**`（征兆家族要加走 `[api]` issue）、`mock/**`、`tests/cards/lib/**`、`tools/run_*.sh`、`project.godot`。
- 只写 `fate` 命名空间；牌的发放经 G01（`add_card`/`extra_deal`/`CardPiles.spawn`），面板经 G02 的 `request_panel`，人脉“用过”经 G03。
- 随机只用 `c.fate.due` `c.wheel.<轮盘>` `c.lot.pick` `c.lot.verse` `c.cezi.offer` `c.almanac` 和经旧模块的 `pressure:c_*` `wheel:c_climate`；**集市日不抽**；状态里没有浮点（`stop_mdeg`、`pressures_milli`）。
- 失败的指令（钱不够、没押牌）不改状态。
- 引擎代码不连 `ui_event`；不加 `class_name`（冻结表以外）；不自己加玩法（扇区数、加宽多少、押牌输了怎么算都是【待调】的数，放数据）。

## 接口

**提供（冻结签名，§7.9 G05 段）**：`CardWeights.rows` · `CardFateTrigger`（`fate_due crisis on_crisis`）· `CardWheel`（`view offer withdraw stake spin weights`）· `CardFortune`（`draw_lot cezi offer_chars`）· `CardAlmanac`（`today note settle`）· `CardPins`（`pin pinned ban banned`）· `CardPressure`（`step_day value_milli`）· `CardFateInstall.install`。

**登记（`CardFateInstall.install`）**：
- 指令：`wheel.offer` `wheel.withdraw` `wheel.stake` `wheel.spin` `fortune.lot` `fortune.cezi`（都带 `uid`，本月运势为 `""`）
- 查询：`wheel {wheel, uid}` `fortune {uid}` `almanac {}`
- 效果 op：`deck_mod` `fate_now` `big_wheel` `wheel_offer` `pressure` `weather` `peek`；条件 op：`weather` `market_day` `pressure_gte` `fortune` `almanac_yi`
- 修正项提供：`pool_rows` `pinned_cards` `fate_due` `deal_count`（天气/集市）`price_pct`（运势）`view_section` `card_view_part`；用到：`pool_pct`（G06）
- 钩子监听：见上 G 节
- 随机数域：`c.fate.due` `[abs_day]` · `c.wheel.<wheel_id>` `[abs_day, uid, spin_no]` · `c.lot.pick` `[abs_day, lot_count, k]` · `c.lot.verse` `[abs_day, lot_count]` · `c.cezi.offer` `[abs_day, uid]` · `c.almanac` `[stage, stage_day]` · `pressure:c_<key>` `[abs_day]`（经 PressureModel）· `wheel:c_climate` `[abs_day]`（经 WorldWheel）

**与别的线的约定（写进 PR）**：`deal_count` 的天气/集市加成由你算（读 `deal.json`），G01 不再加；`deal_count` 参数里有 `abs_day`；`CardSchedule.due` 要支持未来日（G02）；`mark_person_used`（G03）。

## 新手指引

- **锚点**：引擎不登记锚点；WheelView（`segments` `incense` `cost` `spun`）是 C06 的 `a.wheel.face/incense/cost/spin` 的前提，`fortune` 查询是 C07 的 `a.fortune.lot/cezi/chars` 的前提，`notice.almanac`、`notice.weather`、`notice.market_day` 是 C07 `a.almanac` 与 C01 `a.top.weather` 的前提。
- **你必须发的 first-time**：

| 机制 | 什么时候 mark | args | 对应步骤（教的人 · 锚点） |
|---|---|---|---|
| `month_wheel` | 第一次要转本月运势（`month_open` 10 请求面板时） | `{}` | `gd.m.wheel`（brother · `a.wheel.face`） |
| `incense` | 第一次往香案上放东西（`wheel.offer` 成功） | `{}` | `gd.m.incense`（brother · `a.wheel.incense`；步骤 `after: gd.m.wheel`，放之前先亮） |
| `almanac` | 第一个早上黄历出来（第 1 天） | `{}` | `gd.almanac`（obj.almanac · `a.almanac`；`stage_day_gte: 4`） |
| `market_day` | 第一个集市日早上 | `{}` | `gd.market_day`（obj.notice · `a.top.weather`；`stage_day_gte: 4`） |
| `weather` | 第一个不是晴天的早上 | `{}` | `gd.weather`（obj.notice · `a.top.weather`；`stage_day_gte: 4`） |
| `fate` | 第一张命运牌进手牌（`deal_composed` 30） | `{uid, def}` | `gd.fate`（obj.brother_ledger · `a.card@{uid}`） |
| `big_wheel` | 第一张 `bf.wheel` 进手牌（在你发它的地方记） | `{uid}` | `gd.big_wheel`（obj.brother_ledger · `a.card@{uid}` 备 `a.wheel.face`） |
| `lot` / `cezi` | 第一张能求签 / 能测字的牌进手牌（`opens_fortune` 为 `lot`/`both` / `cezi`/`both`） | `{uid, def}` | `gd.lot` `gd.cezi`（suanming · `a.fortune.lot` / `a.fortune.cezi` 备 `a.card@{uid}`） |
| `fair_wheel` | 第一张庙会牌进手牌（`opens_wheel: wh.fair` 或 `wheel_go` 的 `vars.wheel == wh.fair`） | `{uid}` | `gd.fair_wheel`（obj.notice · `a.wheel.cost` 备 `a.card@{uid}`） |
| `wheel_stake` | 第一次看到“押一张留着的牌”的代价（代价是押牌的轮盘牌进手牌） | `{uid}` | 同 `gd.fair_wheel` |
| `gamble_wheel` | 第一张赌摊牌进手牌 | `{uid}` | `gd.gamble_wheel`（"" · `a.wheel.cost` 备 `a.card@{uid}`） |

  （`wheel_offer` 用 `CardPiles.spawn` 发的 `ev.any.wheel_go` 不经 `deal_composed`，在你发它的地方顺手记。）
- **你支持的步骤**：上表全部；开局的 `gd.m.wheel → gd.m.incense` 在 `_test.d1_3` 里（第一关 `month_open` 时哥哥教轮盘和香案），第 5 天算命先生教求签测字（K16 教学牌 `ev.1938.tut_fortune`）。
- **指引验收（必须有测试）**：上表每个机制恰好一次、第二次不发、存→读后不发、`args` 只含白名单键；新局第一次 `month_open` 后 first 串里有 `month_wheel`，第一次 `wheel.offer` 后有 `incense`，第 1 天早上有 `almanac`。
- **截图**：本任务无界面，不交截图（轮盘与算命面板截图由 C06、C07 出，步骤截图由 C16、K14 出）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/G05.txt`（签的准确性按种子分四行并行跑）：

```
# 名字|脚本|超时秒|参数
G05_weights|res://scripts/tests/cards/G05/test_weights.gd|120|
G05_fate_trigger|res://scripts/tests/cards/G05/test_fate_trigger.gd|120|--seeds=50
G05_wheel_math|res://scripts/tests/cards/G05/test_wheel_math.gd|180|--seeds=200
G05_wheel_flow|res://scripts/tests/cards/G05/test_wheel_flow.gd|120|
G05_lot_accuracy_a|res://scripts/tests/cards/G05/test_lot_accuracy.gd|600|--seed_from=0 --seed_to=250 --lots=3 --name=G05_lot_accuracy_a
G05_lot_accuracy_b|res://scripts/tests/cards/G05/test_lot_accuracy.gd|600|--seed_from=250 --seed_to=500 --lots=3 --name=G05_lot_accuracy_b
G05_lot_accuracy_c|res://scripts/tests/cards/G05/test_lot_accuracy.gd|600|--seed_from=500 --seed_to=750 --lots=3 --name=G05_lot_accuracy_c
G05_lot_accuracy_d|res://scripts/tests/cards/G05/test_lot_accuracy.gd|600|--seed_from=750 --seed_to=1000 --lots=3 --name=G05_lot_accuracy_d
G05_lot_harsh|res://scripts/tests/cards/G05/test_lot_harsh.gd|300|--seeds=500
G05_cezi|res://scripts/tests/cards/G05/test_cezi.gd|180|--seeds=200
G05_almanac|res://scripts/tests/cards/G05/test_almanac.gd|120|
G05_pressure_weather|res://scripts/tests/cards/G05/test_pressure_weather.gd|120|--seeds=20
G05_ops_conds|res://scripts/tests/cards/G05/test_ops_conds.gd|120|
G05_view_leaks|res://scripts/tests/cards/G05/test_view_leaks.gd|120|
G05_determinism_save|res://scripts/tests/cards/G05/test_determinism_save.gd|180|
G05_firsts|res://scripts/tests/cards/G05/test_firsts.gd|120|
G05_end_day|res://scripts/tests/cards/G05/test_end_day.gd|120|
```
（一个测试脚本被清单引用多次时，`T.new(self, <名字>)` 的名字从命令行参数 `--name=` 读，保证 `t.finish()` 打印的 `CARDS TEST PASS <名字>` 和那一行一致。）

**每条必须证明的事（合同 §3.2 G05 验收 + §12.2）**：
- [ ] **签的准确性**：1000 个种子 × 每个求 3 次签，签里写到的牌 **100%** 在窗口内发出（或同征兆的替身）；W1 里 G02 的日循环还是桩，测试自己推进 `loop.abs_day/stage_day` 并调 `CardComposer.compose()`（像 W0 `test_engine.gd` 那样），G02 合入后加一个走真指令的版本。
- [ ] 测字“无”的读法在窗口内保持为真（窗口里随机发出的牌没有一张带那个字的标签；日程/主线点名的不算）；“有”的读法那张牌一定发。
- [ ] 本心低时挑坏牌的比例显著更高（统计测试：同一批种子，本心高/低各跑一遍，比例差超过固定阈值；种子固定所以结果确定）。
- [ ] 香案放得越多好扇区越宽（单调：U 从 0 到 `max_units`，好段的总 `arc_deg` 不减）；停针角度 `stop_deg` 落在抽中扇区的角度范围里（多种子）。
- [ ] 视图里没有权重、没有百分比、没有扇区好坏（`leaks()` 对 `wheel` `fortune` `almanac` 查询、`view()`、所有事件参数）。
- [ ] 段的 `conditions` 不满足时这一段不上盘（视图和转都不出现）。
- [ ] 押的牌落在坏段没了、其他段还回来；没押就转 → `stake_required`；钱不够 → `insufficient_money` 且状态哈希不变。
- [ ] 两张同种轮盘牌各转各的（`fate.wheels` 两个键、两个结果）。
- [ ] 黄历奖励只在“做了宜、没做忌”时给；没照做什么也不发生。
- [ ] 大命运：只发 `bf.wheel`；每关上限、同一危机一次；`bf.wheel` 没处理就打烊 → 作废（计入上限、这种危机算用过，不补发）。
- [ ] 集市日不抽（同一关不同种子的集市日完全一样，等于日历算的）。
- [ ] 确定性：同种子同指令两遍哈希一样；存→读→继续一致；`find_floats` 为空（压力、角度都是整数）；随机域只用 G05 的。
- [ ] “新手指引”一节的验收。

**W1 测试替身**：`CardSchedule.due(未来日)`、`mark_person_used`、`pool_pct`、`arrested` 还没有真实现时，单测里另建 `CardCtx` 登记假提供者；不要等。

**性能**（bench `scripts/tests/cards/G05/bench_fate.gd`，不进清单）：`fortune.lot` ≤ 15 ms；`wheel.spin` ≤ 2 ms；`pool_rows` 一次 ≤ 1 ms（例子集）/ 真数据下发一天牌整体 ≤ 10 ms 的份额。

**怎么跑**：
```
GODOT=<你的 Godot 4.7> CARDS_SUITES=G05 tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_card_tests.sh
GODOT=<你的 Godot 4.7> tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；日志没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有泄漏；每个清单测试最后一行 `CARDS TEST PASS <名字>`；G06 黄金种子（合入后）不变或已解释。

**截图**：无（本任务无界面）。

## 交付

- **PR 标题**：`[G05] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[G05] 牌库权重、命运牌频率、天气与压力、黄历`
  2. `[G05] 命运轮盘：本月运势、大轮盘、庙会赌摊、香案与押牌`
  3. `[G05] 求签与测字：读未来发牌、钉签与禁签、本心低签更凶`
  4. `[G05] 大命运危机触发与 first-time 收尾`
- **PR 描述**按模板填满，另外必须有：改动路径；用到的随机域；发的 first-time 及位置；新加的公开函数（如有）；签准确率测试的种子范围与结果（必须 100%）；本心统计测试的比例；轮盘单调性测试的结果；`pressures.json`/`daily_wheels.json` 与旧 `town_pack.json` 的对应；黄金哈希变化说明；bench 数；需要主创/编排决定的事（扇区数、加宽多少、押牌输了怎么算、等第映射都是【待调】）；完成时写“交付”。

## 审核（Claude 会逐条看）

1. 越界：只动 G05 路径；`pressure_model.gd` `world_wheel.gd` `jev_rng.gd` 未改；没读 `town_pack.json`。
2. **签准**：1000 种子 × 3 签 100%；钉签进状态、到日子由 G01 发；替身同征兆；测字“无”加禁签。
3. 轮盘数学：rows 按显示顺序、`stop_deg = 360u` 落在段内；香案单调；`conditions` 不满足的段不上盘。
4. **隐藏信息**：视图/查询/事件无权重、份数、好坏、百分比、钉签内容、本心。
5. 只写 `fate` 命名空间；发牌经 G01；面板经 G02；人脉用过经 G03。
6. 大命运只发 `bf.wheel`；上限与同一危机一次。
7. 黄历只奖不罚；集市日不抽。
8. 新手指引：12 个 first 的记录点、各一次。
9. 确定性、无浮点、存读一致；失败指令不改状态；函数 ≤ 80 行。
10. 免 AI 声明：只有键和 brief；`.gd` 字面量无中文。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 签准确率（种子范围、签数、命中率） | |
| 本心统计（高/低本心挑坏牌的比例） | |
| 轮盘单调性与停针一致的结果 | |
| bench 数（`fortune.lot` / `wheel.spin` / `pool_rows`） | |
| 用到的随机域 | |
| 发的 first-time 及位置 | |
| 新加的公开函数 | |
| 开的 issue | |
| 悬空依赖（G02 未来日日程、G03 mark_person_used、G06 pool_pct、K10 数据……） | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
