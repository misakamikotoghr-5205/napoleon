# K16 `guide-data-post1949` · 新手指引步骤与规矩页骨架、教学日的牌、解放后分支设计

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K16 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K16: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 16**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | `CardIds` 的 `FIRSTS`（66 个机制，含预留 `currency` `branch_pick`）、`ANCHORS`、`UI_EVENTS`、`GUIDE_COND_OPS`、`GUIDE_TRIGGER_KEYS`、`PANELS`、`COMMANDS`；校验器 default 模式已做 V30–V33、V35（错）与指引数据形状（`dsl_shapes.gd` 的 `check_guide_step` / `check_rule_page`）；例子集 `data/cards/_examples/guide/`（3 步、3 页、`_test.d1_3`）；W0 的 `CardGuide`（能用的最小挑步骤：`trigger` 各项、priority、`max_shows`、`done_when`、间隔、每天上限、自动完成、备用锚点）；Mock 的 `guide_data`（**真数据里有 `data/cards/guide/*.json` 就读真的，没有才退回例子集**）；`scripts/tests/cards/W0/test_table_3days.gd`（牌桌 + Mock 情景走第 1–3 天、指引按顺序亮的现成写法）；`deal.json.scripted_days: {"0": [1, 2, 3]}` | W0（已完成） |
| K01 | **`suanming` 的人物登记**（`passersby.json` 的 `persons` 块）——你的 `gd.lot` `gd.cezi` 用 `teacher: "suanming"`，V31 在 default 模式就是“错”，K01 那个小 PR 合入前这两步会让校验变红；`p.brother.1938.farewell`（第 2 天金色牌，第一个选项 `listen` 给 `kp.brother_note`） | W1（K01 先合 `passersby.json`） |
| K08 | 第 6 天教学消息补的碎片 `df.zhouma.1938.tut_news`（在 `dp.zhouma` 里；**这个 id 是 K08 / K16 两张卡约定的**） | W1（悬空引用允许，列在 PR） |
| K09 | `kp.brother_note`、`ct.zhouma`（第 7 天 `contact_gain zhouma`） | W1（悬空引用允许） |
| K11 | 能出找不同的物品模板（建议 `jewelry.hairpin`） | W1 |
| G01 | strict 模式的 V29（覆盖）、V34、V36 等（W0 只做了 default 的“错”；**在 G01 补齐之前，覆盖检查靠你自己的测试**） | W1 |
| G02 | 教学牌和主线牌一样走 `schedule`；脚本日只发日程牌 | W1 |
| C16 / C01–C15 | 指引引擎（C16）和各部件的锚点（W0 的桩面板已经登记了各自的锚点，Mock 上能亮；**1.3 的新锚点 `a.scene.*` `a.tab.*` `a.hero` `a.contacts` `a.hand.kept` 要等 C01 的画面根（目标 10-27）才有人登记，之前测试里用替身，见下方“10-13 变更二”**） | W1 |
| K13 | 审读你的步骤与规矩页 brief（不提概率、点数、本心）和解放后的设计（1950 年代规则） | W1 末–W2 |
| K14 | W2 用真引擎走第 1–3 天，`shown_log` 要等于你的 `_test.d1_3` | W2 |
| Claude | 你的 `steps.json` 一合入，Mock 就改读它，W0 的 `W0_table_3days`（拿例子集的 `_test.d1_3` 比）会对不上——**Claude 在你第一个步骤 PR 合入前改 W0 测试**；你不改 W0 文件 | W1 |

- **波次**：W1。**W1 完成条件之一**：K16 的指引步骤、规矩页与 `tutorial.json` 合入。解放后分支设计 W1–W2 交，不阻塞。
- **W2**：各界面任务用你的 `steps.json` 复测自己的指引步骤；K14 真引擎第 1–3 天走查；你按走查结果调 `priority` / `after` / `done_when` / `seconds`。

## 分支

`cards/K16-guide-data-post1949`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

主创 2026-10-13 的硬性要求：**所有机制都必须有新手指引**——①讲在游戏世界里，由人物开口；②第一次遇到时触发，按天逐步解锁；③教过的都能回看（档案簿“规矩”页 + F1）；④不打断节奏；⑤高亮对应的界面元素，一句气泡说“现在可以做什么”；⑥最终教学文字由人类 A 写，AI 只写 brief 与占位。本任务写指引的**数据骨架**：每个机制至少一个步骤（`data/cards/guide/steps.json`）和一页规矩（`rule_pages.json`）、新存档第 1–3 天应当按顺序亮的步骤表 `_test.d1_3`、第一关头几天固定发的教学牌 `data/cards/era/1938/tutorial.json`；另外写解放后两个分支（信托商店/旧货店、茶馆）的牌组**设计文档**。

## 必读

1. 合同 §0（红线 1、3、4、8）、§2.2、§3.4 K16、§3.5（`gd.<slug>` `rule.<slug>`、教学牌 id `<前缀>.1938.tut_<slug>`、“教的人”里不是人物的 `obj.notice` `obj.almanac` `obj.brother_ledger`、`suanming`、`kp.history_issue`）、§4.1–§4.4、§4.5（指引正文：`data/cards/text/guide/steps.text.json` 的 `say` `bubble`、`rule_pages.text.json` 的 `title` `body`——A 写）、§4.7.1（教学客人可以带 `minigame`：`weight: 0` + `schedule` 的 person）、§4.7.3、§4.7.8、**§4.7.21 全节**（每个字段的含义与默认）、§4.9（V16、V28–V35）、§4.10、§6.1（`ui` 命名空间：指引进度不进哈希）、§7.4.6（脚本日的发牌矩阵）、**§7.10 全节**（规则 10 条、分工、锚点目录、界面事件、`CardFirsts`、`CardGuide` 的做法 8 条、设置与命令行、测试、**§7.10.10 机制与步骤总表 + 26 页规矩 + `_test.d1_3` 起步顺序 + 七处冲突 a–g 的默认做法**、§7.10.11 教学日）、§10（金色牌，第 2 天哥哥告别）、§11.2、§12.1–§12.3、§13.4、**§4.7.24（演出块，1.3 新）、§7.10.5 与 §7.10.10 的 1.3 改表、§7.10.7 第 5 条（教的人在画面里开口）**。
2. `docs/cards/DESIGN_cards.md` **§九.4**（主创原话与节奏表——一字一句对着做）、§六（解放后：选新行当、分支表、收尾）、附录“措辞与史实要求”、文末“实现时的理解”第 11–14 条。
3. `docs/town/cards/src/era.json`：`notes`、`pivot_intro`、`branch_end`（1950–1953 土改、“五反”、统购统销只作政策和经济事件；1956 公私合营收尾不作褒贬）。
4. W0 代码：`scripts/cards/api/card_ids.gd`（上面那些常量）、`scripts/cards/api/dsl_shapes.gd`（`check_guide_step` `check_rule_page`）、`scripts/cards/core/card_validator.gd`（V29–V35 怎么查）、`scripts/cards/ui/shell/card_guide.gd`（挑步骤的逻辑）、`scripts/cards/mock/{mock_engine,mock_scenario}.gd`（`_guide()`；情景模式第 1–3 天发什么、发哪些 first）、`scripts/cards/ui/common/w0_stub.gd`（桩面板登记的锚点）、`scripts/tests/cards/W0/{test_table_3days,shot_table}.gd`、`data/cards/_examples/guide/*.json`、`data/cards/rules/{deal,guide}.json`。
5. 只读参考（**不拷任何文字**）：`scripts/town/guide.gd`、`data/town/onboarding.json`（旧版指引的结构；文字是 AI 写的）、`scripts/town/rules.gd` 与 `data/town/rules.json`、`scripts/town/help_panel.gd`。

## 要做的事

### A. `data/cards/guide/steps.json`（指引步骤）
- [ ] 信封：`{"_meta": {"owner": "K16", "schema": 1, "brief": "…"}, "_test": {"d1_3": [...]}, "cards": [...]}`（`_test` 放顶层，`stage_ship.py` 会剥掉）。
- [ ] **§7.10.10 表里的每一行一个步骤**（起步 66 步：63 行机制、`counter` 一行两步、再加没有机制的 `gd.d1.close` `gd.d2.rules`），id、教的人、锚点（备用锚点）、规矩页照表写；**可以加步骤，不能少机制**（V29：`CardIds.FIRSTS` 的每个机制——含预留的 `currency` `branch_pick`——至少在一个步骤的 `teaches` 里）。
- [ ] 每步字段（§4.7.21）：`id`、`type: "guide_step"`、`era: ["*"]`、`weight: 0`、`teaches`（机制数组；`gd.d1.close` `gd.d2.rules` 这种没有机制的写 `[]`）、`trigger`（只用 `first` `phase` `mode` `stage_gte` `stage_day_gte` `abs_day_gte` `after` `panel` `hand_clear` `cond`；`cond` 只用 `GUIDE_COND_OPS`，V35）、`teacher`（登记过的人物 id、`obj.notice` `obj.almanac` `obj.brother_ledger` 或 `""`，V31）、`anchor` / `anchor_fallback`（`CardIds.ANCHORS` 里的；每张牌的写 `a.card@{uid}` 这种，V30）、`done_when`（`cmd:<CardIds.COMMANDS>`、`ui:<UI_EVENTS>`、`first:<FIRSTS>`、`panel:<面板 kind>`、`timeout`；**`first:` 不能等于本步骤的 `trigger.first`**，V32）、`rule_page`、`priority`、`interrupt`、`max_shows`、`seconds`、`brief`、`_provenance: {"by": "ai", "task": "K16", "date": "<提交当天>"}`。
- [ ] **七处冲突按合同默认做——主创 10-13 已确认**（§7.10.10 a–g）：a 夜牌哥哥第 1 天晚上教（`gd.d1.night`）；b 命运轮盘与香案哥哥在开局教（`gd.m.wheel` `gd.m.incense`）；c 抵押、钱不够、街头、牢房 `teacher: ""`；d 黄历 `obj.almanac`；e 哥哥走后没点名的由 `obj.brother_ledger` 讲；f 口碑风声第 7 天讲（`stage_day_gte: 7`，不等换档）；g 第 3 天也是脚本日。每一处在 brief 里注明“主创已确认 10-13”（原来写的“【待主创确认】”作废）。
- [ ] **`_test.d1_3`**：新存档第 1–3 天应当按顺序亮的步骤。起步顺序（§7.10.10，你定稿）：`gd.m.open` → `gd.m.wheel` → `gd.m.incense` → `gd.d1.notice` → `gd.d1.deal` → `gd.d1.person` → `gd.d1.look` → `gd.d1.spot` → `gd.d1.tiers` → `gd.d1.ticket` → `gd.d1.shelf` → `gd.d1.buyer` → `gd.d1.close` → `gd.d1.night` → `gd.d1.settle` → `gd.d2.rules` → `gd.d2.gold` → `gd.choice` → `gd.d2.keep` → `gd.slots` → `gd.coins`。改了顺序要在 PR 里写理由，并在 C16、K14、G02 的 issue 里通知（他们的测试拿它比）。
- [ ] **让第 1–3 天的顺序站得住**（这几条是本任务的核心难点，测试会逐条验）：
  1. **会在第 1–3 天就第一次出现、但节奏排在后面的机制，步骤必须用 `trigger.stage_day_gte`（或 `abs_day_gte`）挡住**，否则第 1–3 天会多亮步骤：例 `gd.dossier`（第 2 天听哥哥交代完就会补第一块碎片，但节奏是第 6 天周妈教）、`gd.almanac`（第 1 天就有黄历，第 4 天才教）、`gd.market_day` `gd.weather`（第 4 天起）、`gd.news`（第 6 天）、`gd.contact` `gd.tiers`（第 7 天）。逐个机制想一遍“它最早可能在哪天第一次出现”。
  2. **每一步的 `done_when` 要包含自动试玩下一步一定会做的那条指令、那个面板或那个界面事件**（例：`gd.d1.person` 完成于 `panel:counter`；`gd.d1.look` 完成于 `cmd:mg.request`；`gd.d1.spot` 完成于 `cmd:mg.report` 或 `ui:mg_tool`；`gd.d1.tiers` 完成于 `cmd:counter.offer`；`gd.d2.rules` 完成于 `cmd:day.begin`、`panel:dossier`、`panel:help`；1.3 起 `gd.d1.notice` `gd.d1.deal` `gd.d1.person` `gd.d1.shelf` `gd.d1.night` `gd.demand` 还要加界面事件或面板，见下方“10-13 变更二”的表），再加 `timeout` 兜底——否则亮着的一步会一直挡着下一步，等它超时，下一步要高亮的面板可能已经关了。
  3. 同一天里有先后的用 `after` 串起来；`interrupt` 少用（被打断的不算亮过）。
  4. **没有自己的 first、或 first 来得比步骤晚的几步**，用 `after` / `panel` / `hand_clear` / `stage_day_gte` 触发：`gd.m.incense`（香案是放了东西才记 `incense`，合同要求“放之前先亮”——用 `after: ["gd.m.wheel"]` + `panel: "wheel"`，`teaches: ["incense"]`，完成于 `first:incense` / `cmd:wheel.offer` / `cmd:wheel.spin`）、`gd.d1.tiers`（`after: ["gd.d1.look"]` + `panel: "counter"`）、`gd.d1.close`（`hand_clear: true` + `after`）、`gd.d2.rules`（第 2 天早上，`stage_day_gte: 2` + `after: ["gd.d1.settle"]`）。
  5. **开局 + 第 1 天新亮的步骤数 ≤ `data/cards/rules/guide.json` 的 `max_new_per_day`**（现在是 16；起步表是 3 + 12 = 15）；要调这个数开 `[shared] K16→C16`，你不改 `guide.json`。
- [ ] **brief 的写法**：干巴巴地写“谁在什么时候、指着哪里、讲清哪条规矩、玩家现在可以做什么”，供 A 写 `say`（教的人一句话）和 `bubble`（锚点旁一句“现在可以做什么”）——**不写成台词、不写引号里的对白**；**不提概率、几率、百分比、`%`、点数、权重、本心、底价、真假**（红线 3、§7.10.1 第 8 条；K13 会审）；规矩在戏里讲（红线 4）：brief 里写清这句话从谁嘴里、以什么身份说出来。

### B. `data/cards/guide/rule_pages.json`（规矩页，26 页起步）
- [ ] §7.10.10 末尾列的 26 页一页不少：`rule.day` `rule.night` `rule.person` `rule.counter` `rule.appraise` `rule.ticket` `rule.shelf` `rule.gold` `rule.kept` `rule.slots` `rule.demand` `rule.fate` `rule.wheel` `rule.almanac` `rule.fortune` `rule.news` `rule.dossier` `rule.contact` `rule.tiers` `rule.life` `rule.month` `rule.year` `rule.ladder` `rule.prison` `rule.retry` `rule.branch`；每页的 `unlock_first` 照表（任一个机制在 `firsts` 里就解锁，和指引开关无关）、`order`（在档案簿“规矩”栏和 F1 帮助里的排序）、`teacher`（落款口吻，可以 `""`）、`era: ["*"]`、`weight: 0`、`brief`（这一页讲清哪些规矩——写成要点，不写成正文）、`_provenance`。
- [ ] 每个 `CardIds.FIRSTS` 机制至少在一页的 `unlock_first` 里（V29 的后半）。

### C. `data/cards/era/1938/tutorial.json`（教学日的牌，§7.10.11）
- [ ] 信封 `{"_meta": {"owner": "K16", "schema": 1, "brief": "…"}, "cards": [...]}`；**全部 `weight: 0` + `schedule`**（`{"stage_day": d, "order": n}`），id `<前缀>.1938.tut_<slug>`，`era: ["1938"]`，每张至少一个 `omen_*`、`art`、`brief`、`_provenance`；效果里的原因键 `k16.reason.*`（登记在 `ui_keys/K16.json`）。
- [ ] **第 1 天**（`order` 1–3）：来当 `p.<人物>.1938.tut_pawn`（`intent: "pawn"`、`item: {"template": "jewelry.hairpin"}` 或 K11 确认的别的能出找不同的模板、**`minigame: "spot"`**——这样第 1 天一定出找不同）；来卖 `p.<人物>.1938.tut_sell`（东西进货架；**也写 `minigame: "spot"`**，免得随机出称分量/吹银元，多亮步骤）；来买 `p.<人物>.1938.tut_buy`（`want.cats` 含来卖那件的类别，让他买得到）。
- [ ] **第 2 天**：哥哥告别是 K01 的 `p.brother.1938.farewell`（金色，`order: 1`）；你再加 1–2 位普通客人（`order` 2 起；只用当/卖/买，有东西的写 `minigame: "spot"`；不带选项，不引出新机制）。
- [ ] **第 3 天**：带格子的事件 `ev.1938.tut_slots`（`slots` 收 `self` 和 `money`，`check.need` 1，成功/失败都只有小后果——让玩家第一次放格子、掷铜钱时不吃大亏）+ 两位普通客人（同第 2 天的规则）。
- [ ] **第 5 天**：算命先生 `ev.1938.tut_fortune`（`opens_fortune: "both"`、`cost: {"money": 小数目}`、`must_resolve: false`、一个“不算”的选项 `pass`；人物口吻是 `suanming`）。
- [ ] **第 6 天**：周妈的消息 `nw.1938.tut_zhouma`（`kind: "rumor"`、`source: "zhouma"`、`keepable: true`、`expires_days` 几天、`must_resolve: false`、`effects.on_read: [{"op": "dossier", "frag": "df.zhouma.1938.tut_news"}]`）。
- [ ] **第 7 天**：`ev.1938.tut_contact`（周妈成了人脉：一个选项，效果 `{"op": "contact_gain", "person": "zhouma"}`；第 7 天也是第一张条子来的日子，别再加别的）。
- [ ] 第 4–7 天不是脚本日，照常随机抽；教学牌靠日程插进去。
- [ ] 教学客人用 `data/cast.json` 已有的人物（不依赖 K01 的 `persons` 块），**不用** `brother`（他是第 1–2 天的教的人）和 `hu2`；尽量避开 1938 有主线节点的人（`wangshan` `zhao` `linsao` `ma`）；在 PR 里列出用了谁，请 K01 确认不和他的牌冲突。

### D. 解放后分支设计 `docs/cards/post1949/`（只写设计，不写代码、不写正文；`data/cards/branch/**` 预留、首发不读——**这一轮不往里放数据**）
- [ ] `README.md`：范围（只做设计；首发不实现）、目录、史实措辞规则摘录（era.json notes + `branch_end`）。
- [ ] `transition.md`：1949 关结尾到选新行当（G02 预留的 `branch_pick` 阶段）：解锁条件表（人脉——周妈线开茶馆、陈文庭线开中药铺、李敬之线教书；钱和家当——开局本钱；档案簿——认识的人；本心和风声——有些行当选不了，或开局带 `kp.history_issue`）；`kp.history_issue`（历史问题牌）的机制设计：留着的牌、什么时候被翻出来——**只在按年份日程发的政策事件里作为条件被查，不做成随机惩罚**；存档怎么带过去（新的命名空间，不改已有命名空间的含义，§6.1）；新手指引：`gd.branch_pick` / `rule.branch`（已预留），新行当的新机制要新的 first-time 和锚点——列成提议清单（`CardIds` 是封闭的，实现时走 `[api]`）。
- [ ] `trust_store.md`（信托商店 / 旧货店）与 `teahouse.md`（茶馆）：每个分支的**牌组清单与机制**——人物（寄卖人、旧主顾 / 茶客、说书人……）、事件、消息（茶馆消息最多，最适合碎片叙事）、风险、生活牌；条子换成新年代的“任务”和“通知”——写清它们映射到现有条子机制的哪部分（类、档、期限、办法）、哪部分不同；每类牌写数量（【待调】）和 2–3 张样例的**机制骨架表**（字段用合同 §4 的格式列，brief 一栏写设计说明，不写正文）；老面孔在新行当里重新出现、换了身份。
- [ ] `minigames.md`：新小游戏（信托商店沿用鉴定类；茶馆的泡茶、记茶钱、听书）：每个的**物理参数**（像 §8.2 那样只给物理量和摆设）、观察键（像 §4.8 那样，**不判对错**）、锚点与 `mg_tool` 的工具名提议、分钟数怎么算。
- [ ] `policy_events.md`：1950–1953 的土地改革、“五反”、统购统销——**只作为政策和经济事件**（查账、乡下的当户不再来、凭票买粮），按年份用日程发、`weight: 0`、没有随机的坏结果，**不写斗争会和暴力**；1956 年初公私合营收尾（例“德厚当改为公私合营信托商店，你成了私方人员”这一类的结局机制），结局文字由 A 写、不作褒贬。
- [ ] 其他四个行当（中药铺、杂货铺、修理铺、教书/代写书信）各一段方向说明即可。

### E. 标签、界面键
- [ ] `data/cards/tags/K16.json`（教学牌用到的新标签，如有）；`data/cards/ui_keys/K16.json`（`k16.reason.*` `k16.notice.*`，只有 brief）。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **三个步骤的触发和讲法变了**（合同 §7.4.7 第 5 条、§7.10.10）：
  - `gd.d1.close`（`teacher: "brother"`，锚点 `a.btn.close_day`）：第 1 天手上要了断的都处理完了（`hand_clear: true` + `after`），讲“打烊 · 下一天”这个按钮——**任何时候都能按、节奏你定**；还有没处理的也能按，会先列给你看。`teaches: []` 不变。
  - `gd.must`（`teaches: ["must_resolve"]`，`obj.brother_ledger`）：`trigger: {"first": "must_resolve", "panel": "end_day"}`，锚点 `a.endday.blocked`（确认面板里的清单）、备用 `a.btn.close_day`；`done_when: ["cmd:day.end", "ui:panel_closed", "timeout"]`；讲没处理的会怎样（客人走、个别人记仇、事件按没理会、条子接着算、牢房多待一晚），确认了才打烊。
  - `gd.gold_leave`（`teaches: ["gold_leave"]`，`obj.brother_ledger`）：`trigger: {"first": "gold_leave", "panel": "end_day"}`，锚点 `a.endday.gold_leave`（清单里金色牌那一行）、备用 `a.endday.blocked`；讲“不理他他就走了”。它和 `gd.must` 同时能亮时它先（`priority` 大一点）。
  - `gd.prison`：brief 加一句“没处理就在牢里多待一晚，几晚没出来就结束”。
- [ ] 规矩页 `rule.day` 的 brief 加上“打烊 · 下一天随时能按；没处理的按没理会结算；没有时间限制”；`rule.gold` 加“打烊时没理他他就走了”；`rule.prison` 加牢里过夜的规矩。
- [ ] `_test.d1_3` 不变（第 1–3 天按教学日程不会出现要确认的打烊）。
- [ ] 教学牌：`ev.1938.tut_slots` 有顶层 `check`（没理会 = 当没过，后果要小）；`ev.1938.tut_contact` 没有顶层 `check`，**必须写 `on_expire`**（V37）——建议 `[{"op": "contact_gain", "person": "zhouma"}]`（周妈自己找上门，不让第 7 天的人脉指引因为没点开而落空），PR 里列出；`ev.1938.tut_fortune` 是 `must_resolve: false`（今天的机会）；`nw.1938.tut_zhouma` 没看会留在手上倒计时。
- [ ] `test_guide_coverage.gd` 的常量表照合同 §7.10.10 新的三行改（`gd.must` `gd.gold_leave` 的 `trigger.panel`、锚点）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

数据卡共用的写法：

- 演出块的格式、站位、道具位、效果、拍子见合同 §4.7.24；默认演法见 §7.11.4——**默认够用的牌不写**。
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K16] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K16→K12`。
- 校验：default 模式没有 V38 V40 V41 和 V39 本地部分的错；W2 起 strict 全绿。
- 史实：伪军、伪维持会的人在 brief 里照 era.json 的措辞（加“伪”字）。

写法要点（合同 §4.7.24、§4.9 V38–V42 的摘要；落笔前对一遍）：

- 键只有 `set cast props fx walk intro after brief`；`cast` ≤ 3 个、每个只有 `who at look brief`；`props` ≤ 4 个、每个只有 `art at brief`（`art` 合 `^prop\.[a-z0-9_]+$`）；`fx` ≤ 3 个、不重复；`intro` ≤ 12 拍、`after` 每组 ≤ 8 拍，每拍只有 `who ref brief`。
- 能用的值（W0 冻结的 `CardIds` 常量）：`set` ∈ `counter` `candle` `street` `prison` `temple` `dock` `market` `teahouse` `ricehall` `pharmacy` `post` `baogong`（`STAGE_SETS`）；站位 `at` ∈ `customer`（柜台前）`companion`（柜台一侧）`door` `door_l` `door_r`（门口）`street`（门外街上走过）（`STAGE_SPOTS`）；`look` ∈ `stand` `walk` `shadow`（`CAST_LOOKS`）；道具位 ∈ `counter_left` `counter_mid` `counter_right` `door_side` `door_notice` `wall_right`（`PROP_SPOTS`）；`fx` ⊂ `rain` `fire` `smoke` `predawn` `dim` `cold` `warm` `drip` `shake` `seal`（`STAGE_FX`）；`walk` ∈ `crowd` `patrol` `troops` `refugees` `hu2_men` `none`（`STAGE_WALKS`）。
- 站位规则（V38、V41）：同一个站位只站一个人；`door` 不和 `door_l` / `door_r` 同时用；`look: walk` 只配 `at: street`，`at: street` 只配 `look: walk` 或 `shadow`；`set` 不是 `counter` 时不许用 `street` 站位、也不许写 `walk`。
- `ref` 只许 `body`、`lines.<名>`、`outcomes.<名>`、`choices.<id>`；演出块里不许出现 `text` `title` `body` `label` `name` `lines` `desc` 这些**键名**（V04），写在 `ref` 的**值**里可以。
- `after` 的键：`accept` `counter` `leave` `refused` `impatient` `look` `success` `fail` `read` `keep` `delay` `lot` `cezi` `pass` `done`（`STAGE_AFTER_KEYS`）或这张牌自己的选项 id；选了一句回话，对话框先把那句话以“你说的”显示出来，再接 `after.<键>`（第一拍就是 `who: "me"` 时不重复）。`after` 的键会原样进 CardView（G02 只去掉 `brief`），所以选项 id 别和合同 §7.5 的隐藏键黑名单（`CardViewModel.FORBIDDEN_KEYS`：`floor` `market` `value` `tell` `risk` `tags` …）重名。
- `cast`、`props` 每一项也写一句 `brief`（K13 审读、K15 出包时剥掉）。

本任务：

- [ ] **`steps.json` 按合同 §7.10.10 的 1.3 改表改锚点、备用锚点、`done_when`**（下表 19 行，照抄合同；表里“`X`（`Y`）”的意思是锚点 X、备用锚点 Y）；`_test.d1_3` 不变；`test_guide_coverage.gd` 的常量表照改。**这条要在你手上的 PR（#89）合入之前改好**（旧锚点名在 default 模式下只是 NOTE，strict 会红——你清单里的 `K16_validate_strict` 就是 strict）。

| 步骤 | 改哪 | 1.2 | 1.3 |
|---|---|---|---|
| `gd.d1.notice` | 锚点（备用） | `a.top.notice` | `a.scene.notice`（`a.top.date`）；`done_when` 加 `ui:hotspot_pressed` `ui:dialog_advanced` |
| `gd.d1.deal` | done_when | — | 加 `ui:hand_played` |
| `gd.d1.person` | done_when | — | 加 `ui:hand_played` |
| `gd.d1.ticket` | 锚点（备用） | `a.right.tickets` | `a.scene.ledger`（`a.tab.tickets`） |
| `gd.d1.shelf` | 锚点；done_when | `a.right.shelf` | `a.tab.shelf`；加 `panel:shelf` |
| `gd.d1.buyer` | 备用锚点 | — | `a.tab.shelf` |
| `gd.d1.night` | done_when | — | 加 `ui:hand_played` |
| `gd.d2.rules` | 锚点；done_when | `a.right.dossier` | `a.tab.rules`；`done_when` 是 `cmd:day.begin` `panel:dossier` `panel:help` `timeout` |
| `gd.d2.keep` | 备用锚点 | `a.left.kept` | `a.hand.kept` |
| `gd.almanac` | 备用锚点 | — | `a.scene.calendar` |
| `gd.dossier` | 锚点（备用） | `a.right.dossier` | `a.scene.notebook`（`a.tab.dossier`） |
| `gd.contact` | 锚点（备用） | `a.left.contacts` | `a.contacts`（`a.tab.contacts`） |
| `gd.demand` | 锚点（备用）；done_when | `a.demand.board` | `a.scene.notewall`（`a.tab.demands`）；加 `panel:demands` `panel:demand` |
| `gd.demand_fail` | 备用锚点 | `a.top.notice` | `a.scene.notice` |
| `gd.shop_closed` | 锚点 | `a.top.notice` | `a.scene.notice` |
| `gd.kept_expire` · `gd.kept_risk` | 锚点 | `a.left.kept` | `a.hand.kept` |
| `gd.person_state` | 锚点（备用） | `a.left.contacts`（`a.left.self`） | `a.contacts`（`a.hero`） |
| `gd.dossier_gap` | 备用锚点 | `a.right.dossier` | `a.scene.notebook` |
| `gd.mortgage` | 备用锚点 | — | `a.tab.estates` |

  规矩页、教的人、节奏、`_test.d1_3` 都不变。1.3 起 `done_when` 能用的新值：`ui:hand_played` `ui:hotspot_pressed` `ui:dialog_advanced` `ui:dialog_skipped` `ui:reply_chosen` `ui:drawer_opened` `ui:drawer_closed`，以及新抽屉的 `panel:contacts` `panel:demands` `panel:shelf` `panel:tickets` `panel:almanac`（V32 照 `CardIds.UI_EVENTS` / `PANELS` 查）。
- [ ] **第 1–3 天的 Mock 测试加一个“新名替身”**：C01 的画面根合入（目标 10-27）之前，集成分支上的牌桌还是 W0 的桩，只登记 1.2 的旧名（`a.top.notice` `a.left.*` `a.right.*`）；C16 的指引引擎合入（目标 10-23）之前，`CardGuide` 也不会新旧互认——找不到锚点的步骤不亮，`gd.d1.ticket` `gd.d1.shelf` `gd.d2.rules` 会卡住整串。所以 `test_d1_3_mock.gd` 和 `shot_d1_3.gd` 在 `boot` 之后、开始走之前登记一组只在测试里用的替身：对下面每一对，新名还没人登记、旧名登记了，就 `CardAnchors.register(<新名>, game, func(): return CardAnchors.rect(<旧名>))`——`CardIds.ANCHORS_RENAMED` 的 7 对（`a.top.notice` → `a.scene.notice`、`a.left.self` → `a.hero`、`a.left.contacts` → `a.contacts`、`a.left.kept` → `a.hand.kept`、`a.right.tickets` → `a.scene.ledger`、`a.right.shelf` → `a.tab.shelf`、`a.right.dossier` → `a.scene.notebook`），再加 `a.right.tickets` → `a.tab.tickets`、`a.right.dossier` → `a.tab.rules` 和 `a.tab.dossier`、`a.left.contacts` → `a.tab.contacts`。C01 合入后新名有人登记，替身自动不起作用；W2（X01 删旧名时）把这段删掉。这是测试里摆的替身，不算你登记锚点。
- [ ] **教学牌写演出块**（G01 的 1.3 小 PR 合入后另开 PR）：
  - `ev.1938.tut_slots`：一个巡警站门口来查东西——`cast: [{"who": "ex_patrol", "at": "door"}]`，`intro` 2 拍（巡警 `lines.greet`、旁白 `body`）；格子与检定不变，`after.success` / `after.fail` 默认够用（旁白 `outcomes.success` / `outcomes.fail`）。
  - `ev.1938.tut_contact`：周妈站柜台前——`cast: [{"who": "zhouma", "at": "customer"}]`，`intro` 2 拍（周妈 `lines.greet`、旁白 `body`），`after.<选项 id>` 1 拍（周妈说一句，`lines.<名>` 自己起）。
  - `tut_pawn` / `tut_sell` / `tut_buy`、`tut_fortune`、`tut_zhouma` 用默认演法，不用写。
  - `ex_patrol` 是群演：K09 的 `common/extras.json` 合入之前 V39 的登记部分在 default 模式只是 NOTE（你的 `K16_validate_strict` 不查 `tutorial.json`）；`walk.ex_patrol` 由 K12 进清单（V42）。
- [ ] 规矩页 brief 不用改（操作说明在 C10 的帮助里）。
- **数量**：步骤改 20 步（上表 19 行）；教学牌演出块 2 张。

**新增 / 作废的交付**

- 改：`steps.json` 的锚点、备用锚点、`done_when`；`test_guide_coverage.gd` 的常量表；`test_d1_3_mock.gd` / `shot_d1_3.gd` 的新名替身。新增一个 PR `[K16] 演出块`（只动 `tutorial.json`）。
- 作废：步骤里的 7 个旧锚点名（`CardIds.ANCHORS_RENAMED` 的键，上表“1.2”那一列里的 `a.top.notice` `a.left.*` `a.right.*`）——W1 里旧名还登记得上、指引新旧互认，但 V30 在 strict / ship 报错，W2 由 X01 删掉。

**锚点、界面事件、要证明的步骤**

- 你照旧不登记锚点、不发界面事件；锚点、界面事件只用合同 §7.10.5 的 1.3 新表（`CardIds.ANCHORS`、`UI_EVENTS`）；`hand_selected` 1.3 起由 C02 发。
- 教的人 1.3 起在画面里开口：人物站到柜台一侧（`GUIDE_TEACHER`）说 `say`，物件（`obj.notice` `obj.almanac` `obj.brother_ledger`）用一张批注纸，气泡 `bubble` 照旧在锚点旁（合同 §7.10.7 第 5 条）——brief 照旧写清“从谁嘴里、以什么身份说、指着哪里、现在可以做什么”，不用写画面怎么摆。

**测试与截图**

- `test_guide_coverage.gd`：常量表照上表改；`K16_validate_strict` 绿（strict 下不许出现 7 个旧名）。
- `test_d1_3_mock.gd`：加上替身后在集成分支上照样按 `_test.d1_3` 的顺序亮（PR 里贴结果）；C01 的画面根合入后新名有人登记、替身不起作用，也照样亮（W2 的各界面任务复测与 K14 走查会再验）。
- 演出块 PR 里 `test_tutorial.gd` 加：`ev.1938.tut_slots` 有 `stage`、`cast[0] == {who: "ex_patrol", at: "door"}`、`intro` 2 拍；`ev.1938.tut_contact` 有 `stage`、`cast` 里周妈站 `customer`、`intro` 2 拍、每个选项 id 都有 `after.<id>`（1 拍）；演出块里每个 `brief` 也过 brief 自查。
- 截图：`shot_d1_3.gd`、`shot_all_steps.gd` 改成 1280×720 画面截图（合同 §12.3：看得见教的人站在柜台一侧或批注纸、锚点发光、气泡）；`shot_all_steps.gd` 里锚点在抽屉里的步骤（`a.shelf.list` `a.tickets.list` `a.dossier.*` `a.estate.*` 等）用 `host.open_panel(<抽屉 kind>)` 打开抽屉再拍。

**已经做了的哪些还有效**

- 全部有效（锚点除外）：步骤的机制、触发、教的人、规矩页、`_test.d1_3`、教学日的牌、解放后分支设计都不用改。

**日期**：锚点在 #89 合入之前改好（第 1–3 天步骤目标 10-20 合入）；教学牌的演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提，**10-27** 前合入（1938 的演出块，见交接页检查点）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/guide/**`、`data/cards/era/1938/tutorial.json`、`data/cards/branch/**`、`docs/cards/post1949/**`
- 默认拥有：`scripts/tests/cards/K16/**`、`scripts/tests/cards/suites/K16.txt`、`data/cards/tags/K16.json`、`data/cards/ui_keys/K16.json`

## 不能做的事

1. **不写最终教学文字（红线 1、§7.10.1 第 9 条）**：`say` `bubble` `title` `body` 全由 A 写在 `data/cards/text/guide/**`；你不建、不改 `data/cards/text/**`；brief 以外不出现中文（V05）；**不拷旧版 `data/town/onboarding.json`、`data/town/rules.json`、`scripts/town/guide.gd` 的任何文字**。
2. **brief 不泄露隐藏数值（红线 3）**：不提概率、点数、本心、权重、底价、真假、`%`。
3. 不改 `scripts/cards/api/card_ids.gd`（`FIRSTS` `ANCHORS` `UI_EVENTS` 是封闭目录——要新机制、新锚点走 `[api]`）；不改 `data/cards/rules/guide.json`（C16）、`deal.json`（G01）；不改 `data/cards/_examples/**`、`scripts/tests/cards/W0/**`（`W0_table_3days` 的调整由 Claude 做）。
4. 不改 K01 的哥哥告别、K08 的碎片、K09 的留牌与人脉（只引用）。
5. 解放后分支只写设计文档：不写代码、不写正文、不往 `data/cards/branch/**` 放数据；1950 年代不做随机惩罚牌、不写斗争会和暴力（红线 6）。
6. 不自己加玩法：步骤只讲已有的机制；教学牌不引出教学日以外的新机制。

## 接口

**用到**：`CardIds.FIRSTS` `ANCHORS` `ANCHORS_RENAMED`（1.3）`CARD_ANCHORS` `UI_EVENTS` `GUIDE_COND_OPS` `GUIDE_TRIGGER_KEYS` `GUIDE_TEACHER_OBJECTS` `PANELS` `COMMANDS`；§4.7.21 的格式；教学牌用 §4.7.1 / §4.7.3 / §4.7.8 的格式。

**提供**：
- `steps.json` / `rule_pages.json`：G01 的查询 `guide_data`（去掉 `brief` `_provenance` `_test` `weight` `era`）→ C16 的 `CardGuide` 挑步骤、C10 的规矩栏与 F1 帮助；Mock 的 `guide_data`。
- `_test.d1_3`：C16 的 `test_guide_d1_3`、K14 的 `test_guide_d1_3`（真引擎）、G02 的 `G02_firsts_d1_3`（把每一步换成它的 `trigger.first` 推出按天的机制表）、各界面任务 W2 的复测（`--steps=k16`）。
- `tutorial.json`：G02 的 `CardSchedule`、G04（教学客人的 `minigame: "spot"` 一定生效）。
- 待写清单：K15 的 `missing_text.py` 按你的步骤和规矩页列给 A。

## 新手指引

本任务**就是**新手指引的数据。

- **锚点**：不登记（数据任务；你引用的锚点都在 `CardIds.ANCHORS` 里，由各 C 任务登记）。**first-time**：不发（引擎发；你的 `trigger.first` / `teaches` / `unlock_first` 用它们）。
- **支持的步骤**：全部（66 个机制、起步 66 步、26 页规矩）。
- **指引验收（必须有测试，全部进清单，无头）**：
  1. `test_guide_coverage.gd`（G01 的 strict 规则合入前，覆盖检查靠它）：`CardIds.FIRSTS` 的每个机制（含预留两个）至少在一个步骤的 `teaches` 里、至少在一页的 `unlock_first` 里；§7.10.10 表里的每一行（测试里写成常量表：步骤 id → 机制、教的人、锚点、备用锚点、规矩页）都有对应步骤且这几项一致（和表不同的必须在常量表旁注明理由，并在 PR 里列出）；26 页规矩齐、`unlock_first` 照表；每个步骤的 `rule_page` 存在；`_test.d1_3` 的每一步都存在，且每一步的 `trigger.after` 里的步骤都排在它前面；开局 + 第 1 天的步骤数（`_test.d1_3` 里 `gd.m.*` 与 `gd.d1.*` 的个数）≤ `data/cards/rules/guide.json` 的 `max_new_per_day`；所有步骤与规矩页的 brief 不含“概率 几率 百分 % 点数 权重 本心 底价 真假”，引号里不超过 12 个字、不含 `。！？`。
  2. `test_tutorial.gd`：教学牌按 §7.10.11——第 1 天来当 / 来卖 / 来买三张（`order` 1–3），来当的 `minigame == "spot"`、模板在 `data/town/item_templates.json` 的 `appraise.sprites` 里有布局（图路径或 `proc:<variant>`）；来买的 `want.cats` 含来卖那件的类别；第 1–3 天的教学牌只有 `pawn` `sell` `buy` 来意和第 3 天那张事件，有东西的都 `minigame == "spot"`；`ev.1938.tut_slots` 的 `check.need` ≤ 1、格子收 `self` 和 `money`；`ev.1938.tut_fortune` 的 `opens_fortune == "both"`、`cost.money > 0`；`nw.1938.tut_zhouma` 的 `on_read` 补 `df.zhouma.1938.tut_news`；`ev.1938.tut_contact` 有 `contact_gain zhouma`；全部 `weight == 0`、`schedule.stage_day` 是 1、2、3、5、6、7 之一、id 合 `*.1938.tut_*`、至少一个 `omen_*`、`_provenance.task == "K16"`。
  3. **`test_d1_3_mock.gd`——新存档第 1–3 天按顺序触发规定步骤的 headless 测试（W1，Mock）**：照 `W0_table_3days` 的写法——加载 `CardGame.tscn`，`boot({"bus": bus, "seed": 7, "skip_title": true, "guide": "on"})`，`guide.force(true)`、`skip_fades = true`，循环 `autoplay_step()` → `await` 一帧 → `guide.tick(0.5)` → `guide.evaluate_now()`，到第 4 天早上停；断言 `guide.shown_log` **按顺序等于** `data/cards/guide/steps.json` 的 `_test.d1_3`（`_test` 用 `CardDB.read_json` 直接读）；每一步都发了 `ui.guide shown` 和 `done`（看 `mock.sent`）；没有 `_test.d1_3` 以外的步骤亮。（Mock 情景第 1–3 天发的是例子集的牌，不是你的 `tutorial.json`——这条测的是你的**步骤数据**在真牌桌上能不能按顺序亮；用你的教学牌在真引擎上走是 K14 的 W2 测试。）
- **截图**（不进清单，xvfb，§12.3）：
  - `shot_d1_3.gd`：同 3 的走法，**每一步亮起时一张 1280×720 画面截图**（1.3：看得见教的人站在柜台一侧或批注纸、锚点发光、气泡），文件名 `<步骤 id>.png`，外加拼图 `guide_d1_3_sheet.png`。
  - `shot_all_steps.gd`：**其余每一个步骤各一张**——对每一步：选最接近的 W0 夹具（`scripts/cards/mock/fixtures/`）开牌桌，必要时 `host.open_panel(<锚点所属的面板 kind>)`，用 `guide.load_steps()` 只给这一步（`trigger` 清空，只留锚点，验的是锚点位置、气泡与教的人（1.3：站在柜台一侧的人或批注纸）能不能摆下），`force(true)` + `evaluate_now()` 后截图；摆不出来的（例：预留的 `a.branch.list`、需要小游戏开着的锚点）列进“未截清单”并写原因。
  - 两组截图都附在 PR（拼图 + 单张；传不了图就提交到 `scripts/tests/cards/K16/shots/`，目录放 `.gdignore`，≤ 4 MB）。
- **W2**：各界面任务用你的 `steps.json` 复测；K14 真引擎第 1–3 天走查；你按走查结果调数据（`_test.d1_3` 变了要通知 C16、K14、G02）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K16.txt`：

```
# K16 新手指引步骤与规矩页、教学日的牌（docs/handoff_cards/K16_guide-data-post1949.md）
K16_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/guide/steps.json,data/cards/guide/rule_pages.json,data/cards/era/1938/tutorial.json,data/cards/tags/K16.json,data/cards/ui_keys/K16.json --name=K16_validate
K16_validate_strict|res://scripts/cards/core/validate_main.gd|120|--mode=strict --only=data/cards/guide/steps.json,data/cards/guide/rule_pages.json --name=K16_validate_strict
K16_guide_coverage|res://scripts/tests/cards/K16/test_guide_coverage.gd|120|
K16_tutorial|res://scripts/tests/cards/K16/test_tutorial.gd|120|
K16_d1_3_mock|res://scripts/tests/cards/K16/test_d1_3_mock.gd|300|
```
（`K16_validate_strict` 只查指引两个文件——`tutorial.json` 在 W1 有允许的悬空引用；G01 的 strict 规则合入后它会真正查 V29、V34、V36。）

**通过条件**（合同 §3.4 K16 验收、§7.10.9 K16 一行）：
- [ ] 校验器 strict 模式 V29–V36 对自己的文件全绿（G01 补齐前以 `test_guide_coverage.gd` 为准）。
- [ ] `_test.d1_3` 里的步骤都存在、顺序合 §7.10.10 的节奏；Mock 上第 1–3 天按顺序亮（`K16_d1_3_mock`）。
- [ ] 教学日的牌齐、引用闭合（悬空的列在 PR：`df.zhouma.1938.tut_news`（K08）、`ct.zhouma` / `kp.brother_note`（K09）……）。
- [ ] 每一步都有截图（第 1–3 天一组 + 其余步骤一组 + 未截清单）。
- [ ] 两个分支的完整牌组设计；遵守 era.json notes；只有 brief 和设计，没有正文。
- [ ] `tools/run_card_tests.sh` 与 `tools/run_legacy_smoke.sh` 全绿（`W0_table_3days` 若因 Mock 改读你的步骤而变红，见“依赖”最后一行——在 PR 里注明，不改 W0 文件）；无 `SCRIPT ERROR` `ERROR` `WARNING` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=W0,K16 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
  -s res://scripts/tests/cards/K16/shot_d1_3.gd -- --out=/tmp/shots/K16_d1_3
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
  -s res://scripts/tests/cards/K16/shot_all_steps.gd -- --out=/tmp/shots/K16_all
```

## 交付

- **PR 标题** `[K16] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[K16] 第 1–3 天的 21 步、26 页规矩、_test.d1_3 与第 1–3 天的教学牌`（**尽早合**：C16、C10、K14、G02 在等；含 `test_d1_3_mock` 与逐步截图）
  2. `[K16] 其余机制的指引步骤（覆盖全部 66 个机制）`（`gd.lot` `gd.cezi` 等 `suanming` 教的步骤等 K01 的 `passersby.json` 合入后再提）
  3. `[K16] 第 5–7 天的教学牌`
  4. `[K16] 解放后分支设计：信托商店、茶馆`
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；**机制 × 步骤 × 规矩页的覆盖表**（66 行）；和 §7.10.10 表不同的地方及理由；七处冲突的处理（主创已确认）；`_test.d1_3` 定稿（与起步顺序的差异）；教学客人用了谁（请 K01 确认）；悬空引用；第 1–3 天截图拼图 + 其余步骤截图拼图 + 未截清单；需要主创/编排决定的事（七处冲突全部【待主创确认】）；完成写“交付”。

## 审核（Claude 重点）

1. 越界：只动指引两个文件、`tutorial.json`、`post1949` 文档和默认拥有的路径；没碰 `card_ids.gd`、`guide.json`、W0 测试。
2. 覆盖：66 个机制都有步骤和规矩页；表里的教的人、锚点、规矩页一致（不同处有理由）。
3. 第 1–3 天：`_test.d1_3` 在 Mock 上按顺序亮；挡住提前出现的机制（`stage_day_gte`）；`done_when` 能推进；每天新亮步数在上限内。
4. 教学牌：第 1 天一定出找不同、来买买得到、第 3 天格子不吃大亏、第 5–7 天的牌与 K08/K09 的 id 对上。
5. 免 AI 声明：没有 `say` `bubble` `title` `body`；brief 不是台词、不泄露数值；没拷旧 onboarding 文字。
6. 解放后设计：只作政策和经济事件、无随机惩罚、无暴力、结局不作褒贬；新机制列成 `[api]` 提议。
7. 截图：每一步一张。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 覆盖表（机制 → 步骤 → 规矩页） | |
| `_test.d1_3` 定稿与改动理由 | |
| 和 §7.10.10 不同的地方 | |
| 七处冲突的处理 | |
| 教学客人用的人物 | |
| 截图拼图链接（第 1–3 天 / 其余步骤 / 未截清单） | |
| 悬空引用 | |
| 解放后设计文档清单 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
