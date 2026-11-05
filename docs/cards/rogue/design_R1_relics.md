# R1 · 老物件与博古格：一局里攒起来的“镇店之宝”（肉鸽方向之一：遗物与局内构筑）

> 设计提案，不是合同。优先级照旧：主创原话 > `docs/cards/CARDS_INTERFACES.md`（合同 1.5）> 本文。
> 回应主创 “能不能加一点肉鸽元素”。本文只管一个角度：**一局之内**，从几次选择里挑来的被动物件（遗物 / relic），它们怎么来、怎么起作用、怎么相生相克、怎么在画面里出现，以及怎么接进现有引擎。跨局传承（N06 的 legacy）、地图式路线等不在本文。
> 参考过：`archive/cards/N03-relic-month`（月底三选一，9 件纯数字宝）、`archive/cards/N06-meta-pack`（传承 / 进货 / 小动作 / 阵营 / 造假）、N01/N02/N04/N05；现有引擎 `scripts/cards/**` 与数据 `data/cards/**`（读到 2026-10-22 能玩版）。
> 所有标【待调】的数字是起步值，写在数据里，不写死在代码里。所有 id 是 ASCII；`brief` 以外不写中文。

---

## 〇、一页摘要

- **是什么**：德厚当开了几十年，库房里压着没人赎、没人要的老东西；街上、客人、时局也会把东西塞到你手里。一局里你会挑到 5–7 件“老物件”，摆在柜台后墙的**博古格**上（6 格【待调】）。每件都有**来历**（谁的、哪年、为什么留在这儿）、一条**好处**和（多半）一条**毛病**，都用铺子里的话说，不出现任何数字。
- **从哪来**：①货郎头一回上门（1938 第 8 天，白给二选一，兼新手指引）；②**半月盘货**（每关第 16 天，三选一）；③**新年盘点**（第 2、3 关第 1 天，三选一，月底结账时翻出来的）；④**货郎**周末挑担子来（每周最多一回，用钱买、卖给他、请他带走晦气的）；⑤剧情与命运（逃难人留下的停钟、后门收货第三回塞来的铜香炉、大轮盘翻身段……）。
- **怎么起作用**：全部是被动的；效果只用现有的修正项（`price_pct` `patience_pct` `appraise_pct` `cap` `pool_pct` `deal_count` `intake_blocked` `coins`）和现有的效果 DSL（`rep` `heat` `conscience` `demand_tier` `counter` `peek` `extra_deal` `notice`……），挂在现有钩子上。和人脉、家当、猫、徒弟、条子、黄历、夜牌、香案咬合（相生），也有相克（马万利在，胡二的烟袋就不灵）。
- **肉鸽的手感**：每次只能挑一件、挑了就要权衡格子；同一件东西在不同的局里价值不同（手上有陈文庭，药碾子才值钱；老宅押出去了，樟木箱就不灵）；**晦气的东西**占格子、送不走，但有的能“修好”变成镇店的；一套“柜上三件”凑齐有额外的好处。
- **红线**：不显示任何概率、权重、百分比、底价、本心点数；挑物件永远可以“都放回库房”，满了也不会挂起任何待办，**打烊永远能按**；所有随机走 `ctx.draw`，登记两个新域；同一个种子、同一串指令，挑到的东西一样，读档刷不出别的。
- **工程**：一个新模块 `scripts/cards/relic/**`（装在 K18 收徒之后，自己的命名空间 `relic`，懒建），一种新牌类型 `relic`（前缀 `rl.`），三个效果 op、三个条件 op、五条指令、两个查询、两个面板；别的线只改几行（G02 的 `panel_of`、G03 发一个钩子、G01 读一个目录、G06 的策略）。首发内容 **17 件**（寻常 5、有来历 7、镇店 3（其中 1 件只能由修好座钟得到）、晦气 2）+ 6 张系统牌。
- **先做什么**：引擎骨架 + 8 件不带晦气 / 货郎 / 成套的物件 + 盘货面板 + 博古格抽屉 + 一个指引步骤 + 自动玩策略 → 黄金种子重算一次 → 平衡跑开关对照。再上货郎、晦气、修好、成套与其余 9 件。

---

## 一、玩家体验

### 1.1 一局里的样子（以一局 1938 三月 → 1940 三月为例）

| 什么时候 | 画面里发生什么 | 你在想什么 |
|---|---|---|
| 1938 第 8 天 | 一个挑着两只竹筐的老人进门（货郎，`curio_peddler`），说你父亲当年把两样东西卖给他，“铺子新开张，拿回去镇店”。两样东西摆在柜台上：一把客人落下的油纸伞、一个当票存根匣。他教你：东西摆在后墙的博古格上，各有脾气。 | 第一次见，挑一件看着顺眼的。 |
| 第 15 天 | 猫进店（K18 已有）。 | 留不留猫。 |
| 第 16 天 | **半月盘货**：手里多一张牌“翻库房”。打出它，柜台上摆出三样：豁口的青花猫碗、济生堂的铜药碾、蓝布棉门帘。点“细看”，三件并排，各写着来历、好处、毛病。 | 我留了猫 → 猫碗有用；可陈文庭还不是我的人脉，药碾子只管药材……门帘让客人多等一会，但买家少看见货。 |
| 第 20 天前后的周末 | 货郎又来，担子里三件，标着价钱。 | 钱紧，下回再说；或者把伞卖回给他换几个钱救急。 |
| 第 23 天 | 第三回选“后门收货”。夜里有人塞来一只来路不明的铜香炉，摆上了博古格（晦气，送不走），风声天天往上爬。 | 得找货郎带走它，或者等城隍庙那张牌。 |
| 1938 月底 | 结账面板里多一句：盘点库房，翻出几样老东西，明年开张再看。 | — |
| 1939 第 1 天 | **新年盘点**：三选一，至少一件“有来历的”。胡二落下的旱烟袋：条子来时降一档，可街坊看见你跟他走得近。 | 我有马万利了——烟袋和他相克，不灵。换一件。 |
| 1939 某天 | 逃难的人把一座停了的座钟留下抵饭钱（收下 = 心软，但这是件晦气的东西）。之后三回“整理库房”，钟又走了：变成“走得准的座钟”，镇店的。 | 晦气也能养成宝。 |
| 1940 第 16 天 | 博古格满了（6/6）。盘货翻出祖父的紫檀算盘（镇店的，和存根匣、师父的戥子是一套“柜上三件”）。 | 让出哪一件？送回库房的东西这一局不会再回来。 |
| 1940 局终 | 结局文字后面多几行：博古格上那几件东西后来去了哪儿（每件一句 `epilogue`）。 | 这一局的“我”是靠哪几件东西撑过来的。 |

### 1.2 设计原则

1. **东西有来历，不是加成。** 每件物件是一个具体的人、具体的年头留下的东西：名字是物件（“济生堂的铜药碾”），正文是它的来历，好处和毛病写成铺子里看得见的变化（“客人进门暖和，肯多等一会儿”）。界面和正文里没有“加成、触发、属性、稀有、传说、遗物、BUFF、%、倍”这些词。
2. **每次都是取舍。** 三选一只能拿一件；格子有限；大多数东西带毛病；有的东西要配着人脉、家当、猫、徒弟才值钱；有的相克。
3. **不改核心节奏。** 物件不加新的阶段、不加新的回合；拿物件就是处理一张手牌（和处理客人一样），不处理就按“没理会”放回库房。
4. **不帮 refuser。** 只按打烊的人一件也拿不到；物件奖励的是“做生意”（柜台、鉴定、条子、夜牌），这正好和 #198 的方向一致（主动打法应该比只按打烊强）。
5. **看得见的才写出来。** 价格（货郎的要价、他出的收购价）是钱，看得见；格子数（4/6）看得见；物件的“来历深浅”（寻常 / 有来历 / 镇店 / 晦气）画在框上，看得见；概率、权重、效果的大小、本心——永远看不见。

### 1.3 和 N03 的关系

N03（月底三选一）里好的地方都保留：按权重不放回抽三件、种子定死、可以不拿、新拿的从下一刻起才生效、关掉面板不卡流程。改掉的地方：

| N03 | 本提案 | 为什么 |
|---|---|---|
| 只在月底给，一局三关只有 2 次（最后一关月底拿了也用不上） | 半月盘货 + 新年盘点 + 货郎 + 剧情，一局 6 次左右白给的选择，外加货郎买卖 | 2 次撑不起“构筑”。 |
| 五个纯数字键（`price_pct` `heat_delta` `patience_delta` `extra_slot` `fee_pct`），`fee_pct` 要 G04 新开口子 | 只用现有修正项和 DSL，外加 `when` 条件 | 不碰 G04 当票利息；同时自动获得和人脉、家当、猫、徒弟的咬合。 |
| 没有来历，`brief` 只写数 | 每件有来历、好处、毛病、不灵的时候、结局一句 | 主创要的是“对话是载体”。 |
| 9 件物件：铜秤、铁钱箱、旧算盘、门帘、夜灯、存根匣、茶炉、招牌钉、包袱皮 | 继承其中 5 件的意思：铜秤 → 师父的老戥子；存根匣 / 铁钱箱 → 当票存根匣；旧算盘 → 祖父的紫檀算盘；门帘 → 蓝布棉门帘；夜灯 → 船家的马灯 | 名字和意思不浪费；茶炉、招牌钉、包袱皮留给第二批。 |

---

## 二、规则

### 2.1 名词

| 玩家看到的 | 引擎里 | 说明 |
|---|---|---|
| 老物件 | 牌类型 `relic`，id 前缀 `rl.` | 不进手牌、不进任何牌区；持有的记在命名空间 `relic` |
| 博古格 | `relic.held` + 抽屉 `relics` + 场景热点 `curio` | 后墙上 3×2 六格的木格子，格数是 `cap`（起步 6【待调】） |
| 来历深浅：寻常家什 / 有来历的 / 镇店的 / 晦气的 | `grade`：`plain` / `storied` / `treasure` / `curse` | 画在框上（木框 / 朱漆 / 金箔 / 墨底红绳），文字是界面键；**不叫“稀有度”**（`rare` `rarity` 是视图黑名单键） |
| 好处 / 毛病 / 不灵的时候 | `mods`、`passives`、`downsides`、`dormant_when`、`carried` | 正文字段 `use` / `flaw` / `dormant` |
| 翻库房（半月盘货、新年盘点） | 系统牌 `ev.any.relic_offer`、`ev.any.relic_newyear`、`ev.any.relic_gift`，`opens_relic: "offer"` | 一张手牌，打出就是在柜台上摆出几样东西让你挑 |
| 货郎 | 人物 `curio_peddler`；牌 `p.curio_peddler.1938.first`（头一回）、`p.any.curio_peddler`（之后），`opens_relic: "offer"` / `"shop"` | 进门的客人，走人物牌那一套（没理他打烊时他走掉） |
| 柜上三件 | 成套 `sets.counter_three`（`rules/relics.json`） | 凑齐 2 件、3 件各有一层好处 |
| 修好 / 养熟 | `evolve` | 晦气的东西在条件满足后变成另一件 |

### 2.2 从哪来、一局多少

| 来源 | 牌 / 机制 | 次数（三关一局） | 每次 | 备注 |
|---|---|---|---|---|
| 货郎头一回 | `p.curio_peddler.1938.first`，日程 1938 第 8 天 | 1 | 白给，2 选 1，只出寻常家什 | 兼新手指引 `gd.relic`（货郎开口教） |
| 半月盘货 | `ev.any.relic_offer`，每关第 16 天（`rules/relics.json` 的 `offer.days`） | 3 | 白给，3 选 1，来历深浅按关（下表） | 第一关避开第 15 天猫进店 |
| 新年盘点 | `ev.any.relic_newyear`，第 2、3 关第 1 天 | 2 | 白给，3 选 1，**至少一件有来历或镇店的** | 月底结账面板里只预告一句，真正的挑选在第二天开张，见 2.3 |
| 货郎 | `p.any.curio_peddler`：人物牌库里，只在周六、周日，且 6 天内没来过 | 约 4–8 次露面 | 担子里 3 件（寻常 / 有来历），用钱买 1 件；也收你的物件；也收晦气的东西（你贴钱） | 每回最多买 1 件；买完他就走 |
| 剧情与命运 | 效果 op `relic_gain` / `relic_offer` / `relic_lose`；规则级触发 `triggers` | 0–3 | 白给或被塞给 | 首发：停钟（`ev.any.relic_clock`）、铜香炉（第三回后门收货）；第二批：大轮盘翻身 / 坠底段、档案页补齐、主线人物的选项 |

**数目**：白给的挑选约 6 次 + 货郎买卖 + 剧情，局末一般持有 5–6 件，博古格（6 格）在第三关开始吃紧——从这时起每次挑新的都要让出一件，这是最有意思的决定。

**挑选时各来历深浅的比重**（`offer.grade_weights`，按关；只在引擎里，不上界面）【待调】：

| 关 | 寻常 | 有来历 | 镇店 |
|---|---|---|---|
| 1938（关 0） | 70 | 30 | 0 |
| 1939（关 1） | 45 | 45 | 10 |
| 1940（关 2） | 30 | 50 | 20 |

**翻不出来的时候**：库房（`es.storeroom`）押出去了，盘货只摆 2 件；库房没了或者流落街头，这次盘货不发（同一关里推到下一个能发的日子，过了本关就没了）；在牢里（`ladder.prison.uid` 不空）也推后。最后一关没有月底盘点（局终），改由结局文字回顾博古格。

### 2.3 挑、不挑、满了

1. 手上的“翻库房”牌（或货郎）打出去：柜台上摆出 n 件东西（n = 2 或 3），对话框里旁白说来历的开头；回话是“细看这几样”“挑 · <名>”×n“都放回库房”“回头再说”。
2. **挑一件** = 指令 `relic.take {uid, relic}`：这件进博古格，这张牌处理完（`CardPiles.resolve`）。从**下一个修正项询问**起生效（同一次柜台会话已经定下的三档价不变；N03 的“下一天生效”改成“马上，但不追溯”，规则更简单）。
3. **都放回库房** = `relic.pass {uid}`：牌处理完，什么也不拿。没挑的东西这一局还可能在以后的盘货里再出现。
4. **回头再说**：只关演出，牌留在手上（同所有 stage 面板的“算了”）。
5. **打烊时还没挑**：这几张系统牌是 `must_resolve: true`、`effects.on_expire: []` 的事件（V37 合法），打烊清单里是一行 `ignore`，`consequence_key` = `<def>#outcomes.ignored`（人写：“这几样东西又放回库房去了”），要确认；确认后没有任何别的后果。货郎是人物牌：一行 `leave`（他挑着担子走了）。**不新增任何 `END_KINDS`，不新增任何待办。**（盘货牌的 `on_expire` 是空数组，但 G02 只看有没有这个键就用 `<def>#outcomes.ignored`，所以三张盘货牌都要写这句正文；V47 一并查。）
6. **满了**：博古格满（持有数 ≥ `cap`）时挑新的，必须同时说让出哪一件：`relic.take {uid, relic, replace: "rl.xxx"}`；不带 `replace` 返回错误 `relic_full`（`relic_ids.gd`，界面据此弹出“让出哪一件”的那一条，见 §5.4）。**没有“溢出待选”状态**——所以满了也挡不住任何指令、挡不住打烊。晦气的东西不能被让出。
7. **让出去的东西**（`relic.release`、满了时 `replace`、卖给货郎）记进 `relic.gone`，**这一局不会再出现**（不能刷）。
8. **被塞给的**（`relic_gain` 带 `force: true`，以及所有晦气的东西）可以超过格数（显示成 7/6）；超了以后挑新的照样要让出一件，直到回到格数以内。不带 `force` 的 `relic_gain` 在满了时不直接进格子，而是发一张 `ev.any.relic_gift`（只摆这一件，挑 = 让一件换它，不挑 = 不要）。

### 2.4 物件怎么起作用

一件物件 = 四样东西，都只在它**灵**的时候算：

- **常驻修正 `mods`**：和人脉的 `mods` 同一种写法（合同 §4.7.10、§7.3：`pct` 是**乘数**，100 = 不变，**不是** `price_mod` 的增量），每行可以带 `when`（条件 DSL）和 `flaw: true`（这一行算毛病）。物件模块是这些修正项 kind 的又一个提供者，**不改问修正项的人的代码**。
- **被动 `passives` / 毛病 `downsides`**：`{hook, when?, on_actions?, on_night?, effects}`，到了钩子就跑一串现有效果（同人脉的 `passives`）。
- **得失 `effects.on_gain` / `effects.on_lose`**：拿到、失去的那一刻跑一次。
- **不灵 `dormant_when` / `carried`**：`carried: false`（默认）的东西摆在铺子里，流落街头时不灵；`dormant_when` 是额外的不灵条件（例：老宅押出去了，樟木箱搬不出来）。不灵时四样全停，界面上这件东西画暗、写着 `dormant` 那一句。

**修正项与钩子词表**（物件能用的；全是现有机制）：

| `mods` 里的 `mod` | 喂给哪个修正项 kind | 参数 | 例子 |
|---|---|---|---|
| `price_pct` | `price_pct`（G04 `CardPricing.tiers`） | `direction: "pay"/"receive"`，`cat?`/`cats?`，`pct` | 收药材少付一点：`pay`、`cats: ["medicine"]`、`pct: 95` |
| `patience_pct` | `patience_pct`（G04 `CardCustomer.spend_patience`） | `pct` | 客人肯多等：`115` |
| `appraise_pct` | `appraise_pct`（G04 `CardAppraisal`） | `cat?`/`cats?`，`pct` | 书画看得清：`cats: ["art"]`、`120` |
| `shelf_cap` / `kept_cap` | `cap {zone}` | `delta` | 多留一张牌：`kept_cap +1` |
| `deal_count` | `deal_count {type}` | `type`，`delta` | 下雨多一位客人：`person +1`，`when: {"weather": "rain"}` |
| `pool_weight` | `pool_pct {pool, def}` | `pool`，`tags_any?`，`pct` | 买家少看见货：`person`、`["buyer"]`、`85` |
| `no_intake_cat` | `intake_blocked {cat}` | `cat` | （首发不用，留给第二批） |
| `slot_coins` | `coins {uid, slot_id, source}` | `slot_tags_any`，`delta`，`source_kinds`（默认 `["self"]`） | 你本人站进官面上的格子多一枚铜钱 |

| `passives`/`downsides` 的 `hook` | 什么时候（挂在哪个引擎钩子上） | 额外过滤 |
|---|---|---|
| `day_start` | `day_start`，priority 70 | — |
| `demand_issue` | 胡二发条子、算档位之前（G03 新发的钩子 `demand_issue`，见 §4.3） | — |
| `deal` | `deal_composed`，priority 50 | — |
| `resolved` | `card_resolved`，priority 30 | `on_actions`：黄历动作名（`pawn_in` `buy_in` `sell_out` `redeem` `trade` `lend` `meet` `pray`……，G04/G03/G05 已经在记） |
| `night` | `night_chosen`，priority 30 | `on_night`：夜牌 id |
| `settle` | `settle`，priority 45（G03 风声结算 40 之后、G05 黄历奖励 50 之前） | — |
| `month_close` | `month_close`，priority 30（**每关只跑一次**：月账短款会让这个钩子再进来，用 `relic.month_done` 挡住） | — |
| `year_jump` | `year_jump`，priority 60 | — |
| `arrested` / `money_short` | 同名钩子，priority 30 | — |

效果里的 `source` 一律是 `relic:<id>/<字段>/<序号>/<hook>`，所以 `coin_check` 之类的随机键唯一且确定（合同 §5.1）。**物件效果自己不掷随机**；要碰运气只许用看得见的 `coin_check`。

**钳住**：同一种修正，所有物件（含成套）乘起来以后先钳在 `rules/relics.json` 的 `clamp` 里再交出去（例 `price_pay` 85–105、`patience` 80–130），保证怎么叠都不会把柜台玩坏。

### 2.5 相生、相克、成套、修好

- **相生**：`when` 里写现有条件——`has_contact`（陈文庭在，药碾子连书画也看得清）、`flag`（猫在店里）、`estate_status`（老宅押出去，樟木箱不灵）、`has_kept`（手里留着孙府介绍信）、`weather`、`market_day`、`almanac_followed`（新）。
- **相克**：`dormant_when` 里写人脉或旗标（马万利在，胡二的烟袋不灵：两个都降条子档会把条子玩没了）。
- **成套**：`rules/relics.json` 的 `sets`，例“柜上三件”= 祖父的紫檀算盘 + 师父的老戥子 + 当票存根匣；凑 2 件：客人看你这柜上像回事，肯多等一会儿；凑 3 件：每到月底口碑升一档。成套里不灵的那件不算数。
- **修好 / 养熟（`evolve`）**：`{"into": <另一件>, "when": <条件>}`，在 `settle`（priority 46）检查；变了以后原地换掉（占同一格、同一顺序），跑新那件的 `on_gain`，发 `notice` `<新 id>#lines.evolve`。例：停了的座钟，三回“整理库房”（夜牌 `nt.tidy`，计数器 `rl_clock_fix`）后变成走得准的座钟。

### 2.6 晦气的东西（`grade: "curse"`）

- 来路：别人塞给你的（规则级触发，例：第三回“后门收货”）、你心软收下的（逃难人的停钟）、以后大轮盘坠底段。
- 只有毛病（或毛病远大于好处）；`removable: false`：不能让出、满了时也不能拿来换。
- 送走的办法（都是看得见的代价）：①货郎来时“请他带走”（`relic.rid`，你贴他钱，钱数看得见，`rid.money` × 物价指数）；②这件东西自带的去处牌（例：铜香炉进格子两天后发一张 `ev.any.relic_temple`“送到城隍庙去”，花香火钱）；③有的能修好（`evolve`）。
- 指引：第一次拿到晦气的东西，`gd.relic_curse`（算命先生 `suanming` 开口：“这东西晦气，留不得也扔不得”）。

### 2.7 失去

| 怎么失去 | 引擎 | 能不能再出现 |
|---|---|---|
| 满了让出 / 主动让出（抽屉里“送回库房”） | `relic.take {replace}` / `relic.release` | 不能（`relic.gone`） |
| 卖给货郎 | `relic.sell` | 不能 |
| 请货郎带走、送城隍庙（晦气） | `relic.rid` / 效果 `relic_lose` | 不能 |
| 被拿走（数据里的效果：征用、坠底、被查抄） | 效果 `relic_lose {match, pick}` | 不能 |
| 本关重来（`game.retry_stage`） | 读本关开头的存档 | 本关里拿到、失去的都回到本关开头的样子 |

### 2.8 和现有系统的咬合一览

| 系统 | 怎么咬合 | 例子 |
|---|---|---|
| 柜台差价 | `price_pct` 分 `pay` / `receive`；注意它压的是“看得见的三档价”，客人的底线藏着——你付得少了，客人走掉的也多，自带平衡 | 紫檀算盘、铜药碾、老匾木心 |
| 鉴定 | `appraise_pct` 让观察更清楚（只给观察，**永远不给真假**，红线 5） | 猫碗、铜药碾、老戥子 |
| 客人耐心 | `patience_pct` | 门帘、座钟 |
| 人脉 | `when: {"has_contact": …}` 相生；`dormant_when` 相克 | 药碾 × 陈文庭；烟袋 × 马万利 |
| 条子 | `demand_issue` 钩子 + `demand_tier`；`slot_coins` 加官面 / 人情格子的铜钱 | 烟袋、印泥盒 |
| 口碑 / 风声 | `settle` 被动加减；毛病多半在这儿 | 老匾木心（风声不落）、铜香炉 |
| 留牌 | `kept_cap`；`when: {"has_kept": …}` | 存根匣、樟木箱、印泥盒 × 孙府介绍信 |
| 家当与破产阶梯 | `dormant_when: estate_status`；库房押出盘货变少；第二批：“钱不够”面板里多一条“当掉博古格上的一件”（G06） | 樟木箱 × 老宅 |
| 牌库 | `pool_weight` | 门帘（买家少）、算盘（穷客人少来）、银锁（生活牌少） |
| 夜牌 | `night` 钩子 + `on_night` | 马灯 × 后门收货；座钟 × 整理库房 |
| 黄历 | 新条件 `almanac_followed` | 老黄历 |
| 猫 | `when: {"flag": "pet_home"}` | 猫碗 |
| 徒弟 | `month_close` 钩子 + `counter apprentice_loyalty`（K18 已有的计数器） | 老戥子 |
| 武器（只开吓唬） | 首发不碰（`kp.pistol` 被查到只加风声；第二批可以做“樟木箱夹层”让它不被查到，要 G03 加一个 `kept_risk` 的修正项） | — |
| 命运 / 大轮盘 | 段的 `effects` 里 `relic_gain` / `relic_lose`（K10 数据，第二批） | 翻身段给老匾木心；坠底段拿走最好的一件 |
| 求签 | 系统牌带 `omen_wealth`，签照样“准”：签里说“财物进出”，盘货那天就是 | — |
| 档案簿 | 第二批：`dossier_page.on_complete` 给这个人的信物 | — |
| 结局 | 每件一句 `epilogue`，跟在结局文字后面（C09） | — |

### 2.9 红线核对

| 红线 | 本设计 |
|---|---|
| 1 免 AI 声明 | 物件名、来历、好处、毛病、结局句全是正文键，人写（`data/cards/text/relics/**`）；AI 只写 `brief` 和 `text_ai` 基础层占位 |
| 2 确定性 | 只用 `ctx.draw`，新域 `c.relic.offer`、`c.relic.shop`；物件效果不掷随机；修正项按持有顺序乘、钳住，整数运算 |
| 3 隐藏值不上界面 | 视图只给 id、美术、来历深浅、灵不灵、成套几件、货郎的钱数、格数；不给权重、`pct`、效果大小；正文用“量词表”（§5.8）不写数 |
| 4 规矩在戏里讲 | 货郎、算命先生、哥哥的账簿批注开口教 |
| 5 鉴定只给观察 | 物件只能让观察更清楚，没有任何物件给“真 / 假 / 底价” |
| 6 史实措辞 | 来历里的时局按 era.json 的 notes 写（“镇子沦陷那年”“伪维持会”），交 K13 审读 |
| 7 测试红线 | 见 §9 各包的测试 |
| 8 每个机制有指引 | 新机制 6 个，各有步骤与规矩页（§5.7） |
| 9 打烊永远可用 | 挑物件 = 处理一张普通手牌；没挑就按没理会；满了不挂起任何东西；所有面板可关 |

---

## 三、数据格式

### 3.1 文件与归属（提议）

| 路径 | 主人（提议的任务号） | 内容 |
|---|---|---|
| `data/cards/relics/relics.json` | R02 | 17 件物件（type `relic`） |
| `data/cards/relics/system.json` | R02 | 系统牌与货郎：`ev.any.relic_offer` `ev.any.relic_newyear` `ev.any.relic_gift` `ev.any.relic_clock` `ev.any.relic_temple` `p.curio_peddler.1938.first` `p.any.curio_peddler` `p.stranger_waixiang.any.lock_claim`；`persons` 块登记 `curio_peddler` |
| `data/cards/rules/relics.json` | R01 | 格数、盘货日程、比重、钳子、货郎、成套、规则级触发 |
| `data/cards/tags/R02.json` · `data/cards/ui_keys/R01.json` · `ui_keys/R02.json` · `ui_keys/R05.json` | 各自 | 标签 `relic` `curio`；原因键、打烊键、界面键 |
| `data/cards/text_ai/relics/relics.text.json` · `system.text.json` | R02（`ai_paths`） | AI 基础层占位，文件级 `_meta._provenance` |
| `data/cards/text/relics/**` | **只归人（A）** | 正式正文 |
| `data/cards/_schema/relic.json` | G01（R00 时由 Claude 一并加） | 字段说明 |

`ev.any.relic_*` 这几张事件牌 id 第二段用 `any`，人物牌 `p.curio_peddler.*` 第二段用人物 id，合 §4.2。

### 3.2 `relic` 的字段

公共字段（合同 §4.3）里 `relic` 用到的：`id` `type` `era` `weight` `tags` `conditions` `art` `brief` `_provenance`。`relic` 不能带 `stage`、`slots`、`check`、`choices`、`schedule`、`gold`、`keepable`、`must_resolve`、`expires_days`。

| 字段 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `grade` | String | 必填 | `plain` `storied` `treasure` `curse`（`relic_ids.gd` 的 `GRADES`） |
| `weight` | int | 10 | 在同一来历深浅里被摆出来的权重；`0` = 只能由效果给（`relic_gain` / `evolve`） |
| `sources` | [String] | `["offer", "peddler"]` | 能出现在哪种挑选里：`offer`（盘货、货郎头一回）`peddler`（货郎担子）；空数组 = 只能由效果给 |
| `conditions` | Cond | `{}` | 摆出来之前要满足（例：没留过猫就不摆猫碗）；拿到以后不再查 |
| `price` | int | 0 | 货郎的要价（1938 年价，按 `econ.price_index` 换算；看得见）；`peddler` 来源必填 > 0 |
| `carried` | bool | false | true = 随身的东西，流落街头时照样灵 |
| `dormant_when` | Cond | `{}` | 满足时不灵（`{}` = 从不因为这条不灵） |
| `mods` | [ModRow] | `[]` | 常驻修正（§2.4 的表），每行 `{"mod": …, …参数, "when"?: Cond, "flaw"?: bool}` |
| `passives` | [HookRow] | `[]` | 好处：`{"hook": …, "when"?: Cond, "on_actions"?: […], "on_night"?: […], "effects": […]}` |
| `downsides` | [HookRow] | `[]` | 毛病，同上 |
| `effects` | `{on_gain?, on_lose?}` | `{}` | 拿到 / 失去时各跑一次 |
| `evolve` | `{into, when}` | 无 | 满足 `when` 时原地变成 `into`（必须是 `relic`，`weight` 一般为 0） |
| `set` | String | `""` | 成套 id（`rules/relics.json` 的 `sets` 里有） |
| `removable` | bool | `grade != "curse"` | false = 不能让出、不能拿来换；晦气的恒为 false |
| `rid` | `{money}` | 无 | 晦气的东西请货郎带走要贴的钱（1938 年价）；`curse` 必填 |

**正文字段**（`data/cards/text/relics/relics.text.json`，键同 id；合同 §4.5 的必填表加一行）：

| 字段 | 必填 | 是什么 |
|---|---|---|
| `title` | 是 | 物件名（“济生堂的铜药碾”） |
| `body` | 是 | 来历，2–4 句：谁的、哪年、怎么留在德厚当 |
| `use` | 有好处时 | 好处，一句，铺子里看得见的变化 |
| `flaw` | 有毛病时（`downsides` 非空、任一 `mods` 行 `flaw: true`、或 `curse`） | 毛病，一句 |
| `dormant` | 有 `dormant_when` 或 `carried: false` 时 | 不灵的时候怎么说（“老宅押出去了，箱子搬不出来”） |
| `epilogue` | 是 | 结局里一句：后来这件东西去了哪儿 |
| `lines.gain` | 否 | 拿到时的一句 |
| `lines.fire` `lines.*` | 否 | 效果里 `notice` 用的句子（例：胡二瞥见烟袋，口气软了） |
| `lines.evolve` | 有人 `evolve.into` 指向它时 | 变过来那一刻的一句 |

### 3.3 系统牌的新字段

事件牌、人物牌可以多带（合同 §4.7.1 / §4.7.3 的专有字段加两项，V-规则见 §4.7）：

| 字段 | 值 | 含义 |
|---|---|---|
| `opens_relic` | `"offer"` / `"shop"` | 这张牌处理时开物件面板（`CardView.panel = "relic"`） |
| `relic_offer` | `{"n": 1–3, "grades"?: [grade…], "guarantee"?: "storied", "source": String}` | `offer` 的参数：摆几件、只从哪几种来历里挑（不写 = 按关的比重）、至少一件不低于哪种、来源名（只给日志和界面选句子） |
| `relic_shop` | `{"n": 1–3, "grades": [grade…]}` | `shop` 的参数 |

### 3.4 `data/cards/rules/relics.json`（全文，起步值）

```json
{
  "_meta": {"owner": "R01", "schema": 1, "brief": "老物件与博古格的规则和起步数值。数字待调，不上界面。"},
  "_doc": [
    "cap: bookshelf cells. Forced gains may exceed it; choosing a new relic past it needs replace.",
    "offer.days: system offer cards scheduled per stage; postponed to the next eligible day of the same stage.",
    "offer.grade_weights: per stage index; hidden.",
    "clamp: product of all relic multipliers of one kind is clamped before it is returned to the asking module.",
    "peddler: weekend-only, at most once in peddler.gap_days days; buy_back_pct of price when you sell to him.",
    "triggers: rule-level sources that are not attached to a held relic."
  ],
  "enabled": true,
  "cap": 6,
  "offer": {
    "days": [
      {"stage": 0, "stage_day": 16, "card": "ev.any.relic_offer"},
      {"stage": 1, "stage_day": 1, "card": "ev.any.relic_newyear"},
      {"stage": 1, "stage_day": 16, "card": "ev.any.relic_offer"},
      {"stage": 2, "stage_day": 1, "card": "ev.any.relic_newyear"},
      {"stage": 2, "stage_day": 16, "card": "ev.any.relic_offer"}
    ],
    "grade_weights": [
      {"plain": 70, "storied": 30, "treasure": 0},
      {"plain": 45, "storied": 45, "treasure": 10},
      {"plain": 30, "storied": 50, "treasure": 20}
    ],
    "storeroom_mortgaged_n": 2,
    "skip_when": {"any": [{"mode": "street"}, {"estate_status": ["es.storeroom", "lost"]}]}
  },
  "peddler": {
    "card": "p.any.curio_peddler",
    "gap_days": 6,
    "buy_back_pct": 40,
    "takes_per_visit": 1
  },
  "clamp": {
    "price_pay": [85, 105],
    "price_receive": [95, 120],
    "patience": [80, 130],
    "appraise": [90, 150],
    "pool": [50, 200]
  },
  "sets": {
    "counter_three": {
      "members": ["rl.rosewood_abacus", "rl.master_steelyard", "rl.stub_box"],
      "tiers": [
        {"need": 2, "mods": [{"mod": "patience_pct", "pct": 108}], "passives": []},
        {"need": 3, "mods": [], "passives": [{"hook": "month_close", "effects": [{"op": "rep", "tier": 1}]}]}
      ]
    }
  },
  "triggers": [
    {
      "id": "backdoor_censer",
      "hook": "night",
      "on_night": ["nt.backdoor"],
      "counter": "r01_backdoor_nights",
      "at": 3,
      "effects": [{"op": "relic_gain", "relic": "rl.bronze_censer", "force": true}]
    }
  ]
}
```

（`counter` 是 G03 `rules.counters` 里的计数器，用现有 `counter` op 加；`at` 到了只触发一次，`relic.triggered` 记下。）

### 3.5 系统牌（两张全文，其余列表）

```json
{
  "id": "ev.any.relic_offer",
  "type": "event",
  "era": ["*"],
  "weight": 0,
  "tags": ["shop", "relic", "omen_wealth"],
  "must_resolve": true,
  "opens_relic": "offer",
  "relic_offer": {"n": 3, "source": "midmonth"},
  "effects": {"on_expire": []},
  "stage": {
    "set": "counter",
    "intro": [
      {"who": "", "ref": "body", "brief": "旁白：半个月一回翻库房，几样压在箱底的老东西摆上柜台"},
      {"who": "me", "ref": "lines.look", "brief": "沈如花自言自语：这几样留哪件"}
    ],
    "after": {
      "done": [{"who": "", "ref": "outcomes.done", "brief": "旁白：挑中的那件擦干净，摆上后墙的博古格"}],
      "pass": [{"who": "", "ref": "outcomes.pass", "brief": "旁白：都包好放回库房"}]
    }
  },
  "art": "illus.ev.any.relic_offer",
  "brief": "半月盘货：引擎在每关第 16 天经 scheduled_cards 发这张；处理它开物件面板，柜台上摆 3 件按本关比重挑出的老物件，挑一件或都放回。打烊时没处理按没理会：放回库房，无别的后果。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

```json
{
  "id": "p.any.curio_peddler",
  "type": "person",
  "person": "curio_peddler",
  "era": ["*"],
  "weight": 6,
  "tags": ["peddler", "relic", "omen_wealth"],
  "intent": "story",
  "opens_relic": "shop",
  "relic_shop": {"n": 3, "grades": ["plain", "storied"]},
  "conditions": {
    "all": [
      {"any": [{"weekday": 5}, {"weekday": 6}]},
      {"any": [{"stage_gte": 1}, {"day_gte": 9}]},
      {"mode": "shop"}
    ]
  },
  "effects": {"on_expire": []},
  "stage": {
    "props": [{"art": "prop.peddler_baskets", "at": "door_side", "brief": "门边放下的两只竹筐"}],
    "intro": [
      {"who": "curio_peddler", "ref": "lines.greet", "brief": "货郎放下担子，问有没有旧东西要出手，顺带说担子里有几样好东西"}
    ],
    "after": {
      "done": [{"who": "curio_peddler", "ref": "lines.sold", "brief": "货郎收了钱，挑起担子出门"}],
      "pass": [{"who": "curio_peddler", "ref": "lines.bye", "brief": "货郎说下礼拜再来"}]
    }
  },
  "art": "portrait.curio_peddler",
  "brief": "货郎（挑担收旧货、也卖旧货的老人，和沈家上一辈打过交道）。只在周六周日来；引擎的 pool_pct 在他 6 天内来过时把他压到 0。处理他开物件面板 shop：担子里 3 件标价；买一件他就走；也收你博古格上的东西、也替你带走晦气的东西（你贴钱）。没理他，打烊时他挑担走了，无别的后果。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

| id | 类型 | 怎么来 | 要点 |
|---|---|---|---|
| `ev.any.relic_newyear` | event | `offer.days`，第 2、3 关第 1 天 | `relic_offer: {"n": 3, "guarantee": "storied", "source": "newyear"}`；正文讲“去年月底盘点翻出来的” |
| `ev.any.relic_gift` | event | 不带 `force` 的 `relic_gain` 遇上满格时由引擎发 | `relic_offer: {"n": 1, "source": "gift"}`；那件东西由引擎记在 `relic.offers[uid]` |
| `p.curio_peddler.1938.first` | person | `schedule: {"stage_day": 8, "order": 50}`，`era: ["1938"]`，`weight: 0` | `opens_relic: "offer"`，`relic_offer: {"n": 2, "grades": ["plain"], "source": "peddler_first"}`；第一次出现发 first `relic`，指引 `gd.relic` |
| `ev.any.relic_clock` | event | `era: ["1938", "1939"]`，`weight: 4`，`conditions: {"day_gte": 10}` | 逃难的人留下停了的座钟抵饭钱。选项 `take`：`relic_gain rl.stopped_clock force` + `conscience +2`；`refuse`：无。`on_expire: []` |
| `ev.any.relic_temple` | event | 铜香炉的 `on_gain`：`add_card … to: "queue", in_days: 2` | 选项 `send`（`cost.money` 10【待调】）：`relic_lose rl.bronze_censer` + `conscience +2`；`keep`：无。`on_expire: []` |
| `p.stranger_waixiang.any.lock_claim` | person | `schedule: {"when": {"all": [{"has_relic": "rl.silver_lock"}, {"counter_gte": ["r01_lock_days", 6]}, {"not": {"flag": "r01_lock_settled"}}]}}`，`weight: 0` | 外乡人来认那把长命锁：`give_back` / `sell_back` / `keep`（例 5） |

`persons` 块：`"curio_peddler": {"portrait": "portrait.curio_peddler", "dossier": false, "brief": "挑担子收旧货也卖旧货的老人，六十来岁，和沈家上一辈打过交道；名字由 A 定"}`。

### 3.6 美术 id（K12 清单新增）

| id | 底图 | 显示 | 用在 |
|---|---|---|---|
| `relic.<slug>` ×17 | 32×32 | 场景博古格 ×2（64 px）、抽屉 ×2、细看 ×4（128 px） | 物件本身 |
| `frame.relic.plain` / `.storied` / `.treasure` / `.curse` | 九宫格 36×50，边距 6 | ×4（细看卡 288×400）、×2（抽屉行） | 来历深浅的框 |
| `prop.curio_shelf` | 52×38 | 场景 ×4 | 后墙的博古格本体 |
| `prop.peddler_baskets` | 32×24 | 场景 ×4 | 货郎的竹筐 |
| `portrait.curio_peddler` / `walk.curio_peddler` | 48×64 / 64×128 | 同人物 | 货郎 |
| `illus.ev.any.relic_offer` `illus.ev.any.relic_newyear` `illus.ev.any.relic_gift` `illus.ev.any.relic_clock` `illus.ev.any.relic_temple` | 64×48 | 手牌 ×2 | 系统牌插图 |

配色键（`palette.dev.json` 由 Claude 加初值，`palette.json` 由 A 定）：`relic_plain` `relic_storied` `relic_treasure` `relic_curse` `relic_dim`（不灵时压暗）。

### 3.7 五个完整的例子

> 下面五件是合法数据（`relic` 类型按本文 §3.2 的字段表）。“口吻样稿”只是给 A 看方向的**占位**，不进 `data/cards/text/**`。

#### 例 1 · 寻常家什，和猫相生：豁口的青花猫碗

```json
{
  "id": "rl.cat_bowl",
  "type": "relic",
  "era": ["*"],
  "grade": "plain",
  "weight": 10,
  "sources": ["offer", "peddler"],
  "price": 30,
  "conditions": {"any": [{"flag": "pet_home"}, {"flag": "pet_lost"}]},
  "tags": ["cat"],
  "carried": false,
  "mods": [
    {"mod": "appraise_pct", "pct": 110, "when": {"all": [{"flag": "pet_home"}, {"not": {"flag": "pet_lost"}}]}},
    {"mod": "patience_pct", "pct": 90, "flaw": true, "when": {"flag": "pet_lost"}}
  ],
  "passives": [],
  "downsides": [],
  "effects": {"on_gain": [{"op": "notice", "key": "rl.cat_bowl#lines.gain"}]},
  "art": "relic.cat_bowl",
  "brief": "隔壁裁缝家搬走时留下的青花小碗，缺了个口。只在留过猫之后才会摆出来。猫在店里：所有品类鉴定观察清楚一点（appraise_pct 110，乘数）。猫走丢了：碗空着，你心神不宁，客人耐心少一点（patience_pct 90，毛病）。流落街头时不灵。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

口吻样稿（占位）：`title` 豁口的青花猫碗 · `use` 猫蹲在柜上陪着，你看东西的时候眼神定一些。 · `flaw` 猫不在，碗空着，你总往门口看，客人等不了多久。 · `dormant` 铺子都没了，碗也不知道放在哪儿。 · `epilogue` 那只碗后来一直放在柜台底下，谁也没再提那条缺口。

#### 例 2 · 有来历的，和人脉相生、给柜台和鉴定：济生堂的铜药碾

```json
{
  "id": "rl.chen_mortar",
  "type": "relic",
  "era": ["*"],
  "grade": "storied",
  "weight": 8,
  "sources": ["offer", "peddler"],
  "price": 70,
  "conditions": {},
  "tags": ["medicine", "chen"],
  "carried": false,
  "mods": [
    {"mod": "appraise_pct", "cats": ["medicine"], "pct": 125},
    {"mod": "price_pct", "direction": "pay", "cats": ["medicine"], "pct": 95},
    {"mod": "appraise_pct", "cats": ["art"], "pct": 120, "when": {"has_contact": "chen"}},
    {"mod": "pool_weight", "pool": "event", "tags_any": ["search"], "pct": 115, "flaw": true}
  ],
  "passives": [
    {
      "hook": "resolved",
      "on_actions": ["buy_in"],
      "when": {"has_contact": "chen"},
      "effects": [{"op": "notice", "key": "rl.chen_mortar#lines.fire"}]
    }
  ],
  "downsides": [],
  "effects": {},
  "art": "relic.chen_mortar",
  "brief": "陈文庭父亲早年抵在德厚当、没赎回去的铜药碾。药材（medicine）鉴定清楚得多（appraise 125），收药材时三档价都低一点（pay 95：付得少，客人走的也多）。陈文庭是人脉时，书画（art）也看得清一点（120），收药材成交时他会提一句（只有 notice，无数值）。毛病：药材查得紧，查铺类事件（tag search）多一点（pool 115）。流落街头时不灵。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

口吻样稿（占位）：`use` 药材放在碾子边上一比，成色好坏一眼就看出来；收药材也压得住价。 · `flaw` 药碾子摆在明处，查药材的人进门先看它。 · `lines.fire` 陈文庭来坐，摸了摸碾槽：“这是我爹的东西。”

#### 例 3 · 镇店的，成套，好处大、毛病也重：祖父的紫檀算盘

```json
{
  "id": "rl.rosewood_abacus",
  "type": "relic",
  "era": ["*"],
  "grade": "treasure",
  "weight": 6,
  "sources": ["offer"],
  "price": 0,
  "conditions": {"stage_gte": 1},
  "tags": ["counter"],
  "carried": false,
  "set": "counter_three",
  "mods": [
    {"mod": "price_pct", "direction": "pay", "pct": 95},
    {"mod": "price_pct", "direction": "receive", "pct": 105},
    {"mod": "pool_weight", "pool": "person", "tags_any": ["poor"], "pct": 60, "flaw": true}
  ],
  "passives": [],
  "downsides": [
    {"hook": "resolved", "on_actions": ["pawn_in"], "effects": [{"op": "conscience", "delta": -1}]}
  ],
  "effects": {"on_gain": [{"op": "notice", "key": "rl.rosewood_abacus#lines.gain"}]},
  "art": "relic.rosewood_abacus",
  "brief": "祖父开德厚当时用的紫檀算盘，沦陷那年收进库房。第 2 关起才可能在盘货里摆出来，只出现在盘货（不进货郎担子）。好处：收当、收货时三档价低一点（pay 95），卖货时三档价高一点（receive 105）。毛病：精明出了名，穷人家的客人（person 牌 tag poor）少来很多（pool 60）；每收一回当，本心掉一点（隐藏，不上界面）。柜上三件之一。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

口吻样稿（占位）：`use` 算珠一响，进出的账都往铺子这边偏一点。 · `flaw` 街上都说德厚当的算盘打得精，穷人家宁可多走两条街。算得多了，心也跟着硬。

#### 例 4 · 晦气的，能修好：停了的座钟（附：走得准的座钟）

```json
{
  "id": "rl.stopped_clock",
  "type": "relic",
  "era": ["*"],
  "grade": "curse",
  "weight": 0,
  "sources": [],
  "price": 0,
  "conditions": {},
  "tags": ["clock"],
  "carried": false,
  "removable": false,
  "rid": {"money": 20},
  "mods": [
    {"mod": "patience_pct", "pct": 85, "flaw": true}
  ],
  "passives": [
    {
      "hook": "night",
      "on_night": ["nt.tidy"],
      "effects": [
        {"op": "counter", "key": "rl_clock_fix", "delta": 1},
        {"op": "notice", "key": "rl.stopped_clock#lines.fire"}
      ]
    }
  ],
  "downsides": [],
  "evolve": {"into": "rl.running_clock", "when": {"counter_gte": ["rl_clock_fix", 3]}},
  "effects": {"on_gain": [{"op": "notice", "key": "rl.stopped_clock#lines.gain"}]},
  "art": "relic.stopped_clock",
  "brief": "逃难的人留下抵饭钱的座钟，指针停在镇子沦陷那天的钟点（只由 ev.any.relic_clock 的 take 选项给，force）。毛病：柜上的钟不走，客人心里发慌，耐心少不少（patience 85）。不能让出；货郎来时可以贴钱请他带走（rid 20，1938 年价）。每选一回夜牌“整理库房”（nt.tidy）记一笔 rl_clock_fix 并说一句；满 3 笔后原地变成 rl.running_clock。流落街头时不灵（包括毛病）。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

```json
{
  "id": "rl.running_clock",
  "type": "relic",
  "era": ["*"],
  "grade": "treasure",
  "weight": 0,
  "sources": [],
  "price": 0,
  "conditions": {},
  "tags": ["clock"],
  "carried": false,
  "mods": [
    {"mod": "patience_pct", "pct": 115},
    {"mod": "deal_count", "type": "person", "delta": 1, "when": {"market_day": true}}
  ],
  "passives": [],
  "downsides": [],
  "effects": {},
  "art": "relic.running_clock",
  "brief": "修好的座钟，只能由 rl.stopped_clock 的 evolve 得到。好处：客人肯多等（patience 115）；集市日早开门，多一位客人（deal_count person +1）。没有毛病。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

口吻样稿（占位）：停钟 `body` 一个逃难的人把它背了一路，说钟是那天停的，他不想再听它走。 · `lines.fire` 你拆开后盖，擦了一夜，摆锤动了一下又停了。 · 走钟 `lines.evolve` 天快亮的时候，钟自己走了起来，滴答声满屋子都是。 · `epilogue` 那座钟后来一直走着，比镇上的哪一座都准。

（史实措辞交 K13：“镇子沦陷那天”，不写日期细节、不写血腥。）

#### 例 5 · 有来历的，毛病是“迟早有人来认”：外乡人的长命锁

```json
{
  "id": "rl.silver_lock",
  "type": "relic",
  "era": ["*"],
  "grade": "storied",
  "weight": 7,
  "sources": ["offer"],
  "price": 0,
  "conditions": {"not": {"flag": "r01_lock_settled"}},
  "tags": ["family", "stranger"],
  "carried": true,
  "mods": [
    {"mod": "pool_weight", "pool": "life", "pct": 70},
    {"mod": "slot_coins", "slot_tags_any": ["family"], "delta": 1}
  ],
  "passives": [
    {"hook": "settle", "effects": [{"op": "counter", "key": "r01_lock_days", "delta": 1}]}
  ],
  "downsides": [],
  "effects": {
    "on_gain": [{"op": "notice", "key": "rl.silver_lock#lines.gain"}],
    "on_lose": [{"op": "flag", "key": "r01_lock_settled"}]
  },
  "art": "relic.silver_lock",
  "brief": "一个外乡人当给德厚当、再没回来赎的孩子的长命锁（银）。随身带（carried，街头也灵）。好处：家里的生活牌少来不少（pool life 70）；你本人站进 family 格子多一枚铜钱。每过一夜记一笔 r01_lock_days；满 6 笔后，外乡人（stranger_waixiang）来认这把锁（p.stranger_waixiang.any.lock_claim 的日程），这就是它的毛病：东西不是你的。失去时置 r01_lock_settled，之后不会再摆出来。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

来认锁的那张牌（同一个例子的一部分）：

```json
{
  "id": "p.stranger_waixiang.any.lock_claim",
  "type": "person",
  "person": "stranger_waixiang",
  "era": ["*"],
  "weight": 0,
  "tags": ["stranger", "family", "omen_stranger"],
  "intent": "story",
  "schedule": {
    "when": {"all": [{"has_relic": "rl.silver_lock"}, {"counter_gte": ["r01_lock_days", 6]}, {"not": {"flag": "r01_lock_settled"}}]},
    "once": true
  },
  "choices": [
    {
      "id": "give_back",
      "effects": [
        {"op": "relic_lose", "relic": "rl.silver_lock", "reason": "r02.reason.lock_returned"},
        {"op": "rep", "delta": 3},
        {"op": "conscience", "delta": 3}
      ],
      "brief": "还给他，不要钱"
    },
    {
      "id": "sell_back",
      "effects": [
        {"op": "relic_lose", "relic": "rl.silver_lock", "reason": "r02.reason.lock_sold_back"},
        {"op": "money", "delta": 20, "reason": "r02.reason.lock_sold_back"}
      ],
      "brief": "让他拿钱赎回去（他只凑得出一点）"
    },
    {
      "id": "keep",
      "effects": [
        {"op": "flag", "key": "r01_lock_settled"},
        {"op": "conscience", "delta": -4}
      ],
      "brief": "不认，说早就满当了"
    }
  ],
  "effects": {"on_expire": [{"op": "flag", "key": "r01_lock_settled"}, {"op": "conscience", "delta": -2}]},
  "art": "portrait.stranger_waixiang",
  "brief": "外乡人回来认那把长命锁。还给他：锁没了，口碑涨、本心涨；让他赎：锁没了，进一点钱；不认：锁留下，本心掉，以后他不再来。没理他：他在门口站了一会儿走了，本心掉一点，以后也不再来。",
  "_provenance": {"by": "ai", "task": "R02", "date": "2026-10-25"}
}
```

口吻样稿（占位）：`use` 锁挂在格子上，家里那些不顺心的事好像也少了。 · `flaw` 东西是别人家孩子的，迟早有人来认。

### 3.8 首发 17 件一览

| id | 名（brief 用，正式名由 A 定） | 来历深浅 | 来源 | 好处（词） | 毛病（词） | 咬合 / 机制 |
|---|---|---|---|---|---|---|
| `rl.cat_bowl` | 豁口青花猫碗 | 寻常 | 盘货、货郎 | 猫在：看东西清楚一点 | 猫丢：客人等不久 | `when flag pet_home` · `appraise_pct` / `patience_pct` |
| `rl.stub_box` | 当票存根匣 | 寻常 | 盘货、货郎、货郎头一回 | 多留一张牌 | 货架少一格 | `kept_cap +1` / `shelf_cap -1` · 柜上三件 |
| `rl.blue_curtain` | 蓝布棉门帘 | 寻常 | 盘货、货郎 | 客人肯多等一会儿 | 过路的买家少看见货 | `patience_pct 115` / `pool person buyer 85` |
| `rl.oilpaper_umbrella` | 客人落下的油纸伞 | 寻常 | 盘货、货郎、货郎头一回 | 下雨天多一位客人进门 | 无 | `deal_count person +1` `when weather rain` · `carried` |
| `rl.old_almanac` | 祖父批过的老黄历 | 寻常 | 盘货、货郎 | 照黄历做事的那天，口碑涨一点 | 无 | `settle` + 新条件 `almanac_followed` · `carried` |
| `rl.chen_mortar` | 济生堂的铜药碾 | 有来历 | 盘货、货郎 | 药材看得清、收得便宜；陈文庭在，书画也看得清 | 查铺的事多一点 | 例 2 |
| `rl.hu2_pipe` | 胡二落下的旱烟袋 | 有来历 | 盘货、货郎 | 条子来时降一档 | 条子来时口碑掉一点、本心掉一点；马万利在就不灵 | `demand_issue`：`demand_tier -1` / `rep -2` `conscience -1` · `dormant_when has_contact ma` · `carried` |
| `rl.sun_inkpad` | 孙府的朱砂印泥盒 | 有来历 | 盘货、货郎 | 你站进官面上的格子多一枚铜钱；手里有孙府介绍信再多一枚 | 官面上的事找上门多一点 | `slot_coins official +1`（+1 `when has_kept kp.sunfu_letter`）/ `pool event official 115` |
| `rl.camphor_chest` | 老宅的樟木箱 | 有来历 | 盘货 | 多留一张牌、货架多两格 | 老宅押出去就搬不出来，不灵 | `kept_cap +1` `shelf_cap +2` · `dormant_when estate_status old_house mortgaged/lost` |
| `rl.boat_lantern` | 船家的马灯 | 有来历 | 盘货、货郎 | 后门收货那晚风声不涨；水边的消息多一点 | 来路不明的东西收多了，口碑掉一点 | `night on_night nt.backdoor`：`heat -3` / `rep -1` · `pool news omen_water 130`（和铜香炉的“第三回后门收货”互相勾着） |
| `rl.master_steelyard` | 师父的老戥子 | 有来历 | 盘货、货郎 | 金银、首饰、药材称得准；有徒弟时月底徒弟更念你的好 | 太较真，客人嫌你磨蹭 | `appraise cats [jewelry silver silverware goldbar medicine] 120` · `month_close when has_contact tudi`：`counter apprentice_loyalty +5` / `patience 92` · 柜上三件 |
| `rl.silver_lock` | 外乡人的长命锁 | 有来历 | 盘货 | 生活牌少来；家里的格子多一枚铜钱 | 迟早有人来认 | 例 5 |
| `rl.old_signboard` | 老匾“德厚”的木心 | 镇店 | 盘货（第 2 关起）；第二批：大轮盘翻身段 | 来买的人肯多出一点；口碑每晚涨一点 | 太招眼：风声不会自己落下去 | `price receive 110` · `settle rep +1` / `settle heat +1`（抵掉每天自然回落的 1） |
| `rl.rosewood_abacus` | 祖父的紫檀算盘 | 镇店 | 盘货（第 2 关起） | 进出的账都往铺子偏 | 穷客人少来；收当多了心硬 | 例 3 · 柜上三件 |
| `rl.running_clock` | 走得准的座钟 | 镇店 | 只由修好停钟得到 | 客人肯多等；集市日多一位客人 | 无 | 例 4 |
| `rl.stopped_clock` | 停了的座钟 | 晦气 | `ev.any.relic_clock` 收下 | — | 客人等不久 | 例 4 · `evolve` |
| `rl.bronze_censer` | 来路不明的铜香炉 | 晦气 | 第三回后门收货（规则级触发） | — | 风声每天涨不少 | `settle heat +2` · `on_gain` 两天后发 `ev.any.relic_temple` · `rid 30` |

---

## 四、引擎改动

### 4.1 新模块 `scripts/cards/relic/**`（R01；无 `class_name`，一律 `preload`，同 K18）

| 文件 | 做什么 | 主要函数（全是 `static func`，第一个参数 `ctx: CardCtx`） |
|---|---|---|
| `relic_install.gd` | 只做登记：指令、查询、效果 op、条件 op、修正项、钩子、动作 | `install(engine: CardEngine, ctx: CardCtx) -> void` |
| `relic_ids.gd` | 常量：`OWNER := "R01"`、`NS := "relic"`、`GRADES`、`MOD_KINDS`、`HOOKS`、`ERR_RELIC_FULL := "relic_full"`、`ERR_NOT_REMOVABLE := "not_removable"`、原因键 `r01.reason.*`、打烊键 `r01.end.*` | — |
| `relic_state.gd` | 命名空间的读写（**懒建**：没碰过就不存在）、持有列表、格数、`gone` | `peek(ctx) -> Dictionary`（只读，没有返回 `{}`）· `ensure(ctx) -> Dictionary` · `held_ids(ctx) -> PackedStringArray`（按拿到的先后）· `has(ctx, id) -> bool` · `cap(ctx) -> int` · `gain(ctx, id, src) -> void` · `lose(ctx, id, reason) -> void` · `replace(ctx, old_id, new_id, src) -> void` |
| `relic_effects.gd` | “灵不灵”、修正项提供者、钳子、钩子跑被动、成套、修好、规则级触发 | `is_dormant(ctx, id) -> bool` · `active_rows(ctx, field: String) -> Array`（`[[id, row], …]`，含成套层；已过 `when` 与不灵）· `prov_price_pct(ctx, args) -> int` · `prov_patience_pct` · `prov_appraise_pct` · `prov_cap -> int` · `prov_pool_pct` · `prov_deal_count -> int` · `prov_intake_blocked -> bool` · `prov_coins -> int` · `run_hook(ctx, hook: String, args: Dictionary) -> void` · `check_evolve(ctx) -> void` · `run_triggers(ctx, hook, args) -> void` |
| `relic_offers.gd` | 盘货日程、摆东西（抽）、货郎担子与价钱、五条指令 | `scheduled(ctx, args) -> Array`（修正项 `scheduled_cards`）· `bind_dealt(ctx, args) -> void`（`deal_composed`：给新发的系统牌建报价记录）· `draw_offer(ctx, key_base: Array, n: int, grades: Dictionary, guarantee: String, sources: String) -> PackedStringArray` · `shop_price(ctx, id) -> int` · `sell_price(ctx, id) -> int` · `rid_price(ctx, id) -> int` · `cmd_take / cmd_pass / cmd_sell / cmd_rid / cmd_release(ctx, args) -> Dictionary` |
| `relic_view.gd` | 视图块、牌视图块、两个查询 | `view_section(ctx, args) -> Dictionary` · `card_view_part(ctx, args) -> Dictionary` · `q_relics(ctx, args) -> Dictionary` · `q_offer(ctx, args) -> Dictionary` |

每个文件开头两三行中文注释（主人、合同哪一节）；函数 ≤ 80 行；遍历字典先排序；整数运算。

### 4.2 状态：命名空间 `relic`（R01 独写；别人只读）

```json
"relic": {
  "_v": 1,
  "held": [{"id": "rl.cat_bowl", "since_abs_day": 8, "src": "c0042"}, {"id": "rl.stopped_clock", "since_abs_day": 19, "src": "relic:trigger"}],
  "gone": ["rl.blue_curtain"],
  "offers": {"c0042": {"mode": "offer", "ids": ["rl.cat_bowl", "rl.stub_box"], "prices": [0, 0], "status": "taken", "taken": "rl.cat_bowl", "abs_day": 8}},
  "offer_done": {"0": [16]},
  "peddler_last_abs_day": 20,
  "month_done": {"0": true},
  "triggered": {"backdoor_censer": true}
}
```

- **懒建**：`ensure()` 只在第一次真要写的时候调（发了系统牌、拿到东西、触发计数）。没碰过就不存在，所以**对已有存档和没有物件数据的例子集，状态哈希一个字也不变**（只有 `db_hash` 会因为多了规则文件而变，见 §6）。
- 不进 `CardState.NAMESPACES`（加进去会让每局第 0 天就多一个空字典，所有黄金哈希全变）；`CardState.from_dict` 本来就原样保留不认识的命名空间。
- 只有 int / String / bool / Array / Dictionary；没有浮点（`find_floats` 测）。
- `offers` 在牌离场后的下一个 `day_start` 清掉（只留 `status` 为 `open` 的），存档不会越来越大。

### 4.3 改到别人的地方（都很小；按合同走 `[api]` / `[shared]`）

| 文件 | 主人 | 改什么 | 为什么 |
|---|---|---|---|
| `scripts/cards/api/card_ids.gd` | Claude（`[api]`） | `TYPES` / `TYPE_PREFIX` 加 `relic`→`rl`；`COMMANDS` 加 `relic.take` `relic.pass` `relic.sell` `relic.rid` `relic.release`（值 `R01`）；`QUERIES` 加 `relics` `relic_offer`；`PANEL_SCENES` / `PANELS` / `PANEL_SHOW` 加 `relic`（`stage`）、`relics`（`drawer_r`）；`CARD_PANELS` 加 `relic`；`HOTSPOTS` 加 `curio`，`HOTSPOT_PANELS` 加 `curio → relics`；`HOOKS` 加 `demand_issue`；`EFFECT_HOOKS` 加 `on_gain` `on_lose`；`FIRSTS` 加 `relic` `relic_full` `relic_shop` `relic_curse` `relic_dormant` `relic_evolve`（值 `R01`）；`ANCHORS` 加 `a.scene.curio`（C01）`a.relic.objects` `a.relic.compare` `a.relic.replace` `a.relic.shop` `a.relics.list`（R05）；`RNG_DOMAINS` 加 `["^c\\.relic\\.(offer|shop)$", "R01", true]`；`GUIDE_COND_OPS` 加 `has_relic` | 常量冻结表 |
| `scripts/cards/api/dsl_shapes.gd` | Claude（`[api]`） | `EFFECT_OPS` 加 `relic_gain {relic, force?}` `relic_lose {relic? \| match{grade?, tags_any?}, pick?: "newest"/"oldest"/"best", reason}` `relic_offer {source, n, grades?}`；`COND_OPS` 加 `has_relic` `relic_count_gte` `almanac_followed`；`relic` 的形状函数（mods / passives / evolve / rid / relic_offer / relic_shop） | 校验器从第一天按它查 |
| `scripts/cards/api/card_layout.gd` | Claude（`[api]`） | `S_CURIO := Rect2i(237, 60, 52, 38)`、`CURIO := Rect2(948, 240, 208, 152)`；`S_HOTSPOTS` / `HOTSPOTS` 加 `curio`；`static func curio_cell(i: int) -> Rect2`（3×2，每格 64×64，屏幕坐标） | 画面坐标冻结 |
| `scripts/cards/loop/card_engine.gd` | G02（`[shared]`） | `const _RelicInstall = preload("res://scripts/cards/relic/relic_install.gd")`，在 `_ApprenticeInstall.install(self, ctx)` **之后**加一行 `_RelicInstall.install(self, ctx)` | 安装顺序“六段 + 收徒”之后接，不插入、不重排 |
| `scripts/cards/loop/view_model.gd` | G02（`[shared]`） | `panel_of(d)` 开头：`if str(d.get("opens_relic", "")) != "": return &"relic"` | 物件面板 |
| `scripts/cards/rules/demands.gd` | G03（`[shared]`） | `CardDemands.issue()` 里 `CardRulesInstall.contact_hook(ctx, "demand_issue")` 下面加 `ctx.hooks.fire(ctx, &"demand_issue", {})`（算档位之前） | 烟袋这类物件要和人脉一样在算档前降档 |
| `scripts/cards/rules/slots.gd` | G03（`[shared]`） | `_source_view` 里给 `coins` 修正项的参数多带 `"wants": slot.get("tags", [])`（只加键，不改语义） | 物件按格子性质加铜钱，不用回头查牌（回头查会递归进 `slot_views`） |
| `scripts/cards/core/card_db.gd` | G01（`[shared]`） | `CARD_DIRS` 加 `"relics"` | 读 `data/cards/relics/**` |
| `scripts/cards/core/card_validator.gd` · `validation_extra.gd` | G01（`[shared]`） | 正文必填表加 `"relic": ["title", "body", "epilogue"]`，允许字段加 `use flaw dormant epilogue lines.* `；V43–V47（下表）；person / event 允许 `opens_relic` `relic_offer` `relic_shop` | — |
| `data/cards/_schema/relic.json`；`event.json` `person.json` 加三个字段 | G01 | — | — |
| `scripts/cards/sim/policy.gd` · `fuzz_actions.gd` · `telemetry.gd` · `balance_main.gd` | G06（`[shared]` 或 R03） | 策略会挑物件（§6.4）；模糊测试乱发五条新指令；遥测记物件 | 平衡与黄金种子 |
| `data/cards/guide/steps.json` · `rule_pages.json` | K16（跨线新增，同 K17 的 `gd.office`） | 6 个步骤、2 页规矩（§5.7） | 红线 8 |
| `data/cards/art/manifest.json`、`tools/cards/art/gen_ai_relic.py` | K12 | §3.6 的美术 id 与生成器 | — |
| `scripts/cards/ui/table/card_stage.gd`（C01） | C01（`[shared]`） | 场景里画博古格与上面的物件（读 `view.relics`），热点 `curio`，锚点 `a.scene.curio` | — |
| `scripts/cards/ui/month/*`（C09） | C09（第二批） | 月底面板一句“盘点”预告；局终在结局文字后列 `epilogue` | — |
| `data/cards/theme/palette.dev.json` | Claude | 5 个配色键 | — |
| `docs/cards/CARDS_INTERFACES.md` · `ownership.json` · `DESIGN_cards.md` | Claude / 主创 | 新 §4.7.25 `relic`、§5 新 op、§6.3 新域、§7.4 新指令、§7.5 新视图块、§7.8 新面板、§7.10.10 新机制、§7.11.2 新坐标；归属表加 R 线 | 合同 |

**新校验规则**（default / strict / ship 都算错，除非注明）：

| 编号 | 查什么 |
|---|---|
| V43 | `relic` 的形状：`grade` ∈ `GRADES`；`mods` 每行的 `mod` ∈ 物件能用的 8 种、参数齐、`pct` 是 1–400 的整数；`passives`/`downsides` 的 `hook` ∈ 物件钩子表，`on_actions` ⊂ `ALMANAC_ACTIONS`，`on_night` 每个都是 `night` 牌；`when` / `dormant_when` / `conditions` 过条件形状；`sources` ⊂ `["offer", "peddler"]`；`peddler` 来源 `price > 0` |
| V44 | `curse` ⇒ `removable` 不为 true、有 `rid.money > 0`、`weight == 0`、`sources == []`（晦气的只能被塞给） |
| V45 | `evolve.into` 是存在的 `relic`、不指向自己、没有环；`set` 在 `rules/relics.json` 的 `sets` 里；`sets` 的成员都是 `relic` |
| V46 | 所有 `relic_gain` / `relic_lose` / `has_relic` 指向存在的 `relic`；`opens_relic` 只在 person / event 上，`offer` 必带 `relic_offer`、`shop` 必带 `relic_shop`；`rules/relics.json` 的 `offer.days[].card` / `peddler.card` 存在且 `opens_relic` 对得上 |
| V47 | 正文（strict 起）：`use` 与好处、`flaw` 与毛病、`dormant` 与不灵条件一一对上（§3.2 的表）；ship 缺字报错 |

### 4.4 指令、查询、视图

| 指令 | 参数 | 返回（除 ok/err） | 阶段 | 错误 |
|---|---|---|---|---|
| `relic.take` | `{uid, relic, replace?: ""}` | `{gained, released, price}` | `day` | `unknown_uid` · `not_allowed`（这张牌的报价里没有它 / 已处理）· `relic_full`（满了没给 `replace`）· `not_removable`（`replace` 是晦气的）· `insufficient_money`（货郎的价）· `already_resolved` |
| `relic.pass` | `{uid}` | — | `day` | `unknown_uid` · `already_resolved` |
| `relic.sell` | `{uid, relic}`（`uid` = 在场的货郎） | `{money}` | `day` | `not_allowed`（不是货郎 / 没有这件 / 晦气的）|
| `relic.rid` | `{uid, relic}` | `{money}`（付出去的，正数） | `day` | `not_allowed` · `insufficient_money` |
| `relic.release` | `{relic}` | — | `day` `morning` | `not_allowed` · `not_removable` |

- `take` 成交（货郎）时 `CardPiles.resolve(ctx, uid, &"resolved", {"almanac": ["trade"]})`；白给的不记黄历动作。货郎买完一件即离场（`takes_per_visit`），卖给他、请他带走不离场；`pass` = 送客。
- 失败的指令只返回错误码 + `reason_key`（`r01.reason.*`），不改状态。

| 查询 | 参数 | 返回 |
|---|---|---|
| `relics` | `{}` | `{cap, held: [RelicView], sets: [{set, have, need_next, on: bool}]}` |
| `relic_offer` | `{uid}` | `{uid, mode: "offer"/"shop", source, items: [{id, art, grade, price}], full: bool, can_sell: [{id, price}], can_rid: [{id, price}], status}` |

- **RelicView** `{id, art, grade, dormant: bool, removable: bool, set: String, since_day: int}`。
- **视图**：`view_section` 交顶层块 `"relics": {"cap": 6, "count": 4, "held": [RelicView…]}`；牌视图 `card_view_part` 对带 `opens_relic` 的牌交 `"relic_mode": "offer"/"shop"`。
- 键名全部避开黑名单（不用 `rarity` `weight` `pct` `value` `tags`……）；G02 的递归检查照样跑。
- **事件**：不加新信号。拿到、失去、变都发 `notice`（`rl.<slug>#lines.gain` 之类）和 `view_changed`（topic `relics`）；钱经 `money` / `pay` op 照常发 `money_changed`；first-time 照常。

### 4.5 摆东西（抽）的算法（`relic_offers.gd`）

```
draw_offer(ctx, key_base, n, grades, guarantee, sources):
  pool = ctx.db.pool(&"relic", era) 里 weight > 0、sources 含 <sources>、conditions 满足、
         不在 held、不在 gone 的；按 id 排序
  picked = []
  for slot in 0..n-1:
    rows_g = grades 里在 pool − picked 中还有货的那几种，[[grade, w]]，按 GRADES 的顺序
    if rows_g 空: break
    g = JevRng.weighted_choice(rows_g, ctx.draw("c.relic.offer", key_base + [slot, "g"]))
    rows = pool − picked 里 grade == g 的 [[id, weight]]（按 id 排序）
    picked.append(JevRng.weighted_choice(rows, ctx.draw("c.relic.offer", key_base + [slot, "r"])))
  if guarantee != "" and picked 里没有 ≥ guarantee 的 and pool 里有:
    rows = pool − picked[0..n-2] 里 ≥ guarantee 的
    picked[n-1] = JevRng.weighted_choice(rows, ctx.draw("c.relic.offer", key_base + [n-1, "q"]))
  return picked
```

- 盘货：`key_base = [stage, stage_day]`；n = 牌上的 `relic_offer.n`，库房押着取 `storeroom_mortgaged_n`；`grades` = 牌上写的或本关比重。
- 货郎：域 `c.relic.shop`，`key_base = [abs_day, uid]`；价格 = `price × econ.price_index / 100`（看得见）；卖给他 = `price × buy_back_pct / 100 × price_index / 100`；带走晦气 = `rid.money × price_index / 100`。
- 抽是在**发牌那一刻**（`deal_composed`）做一次、记进 `relic.offers[uid]`；之后查询只读记录。同一种子、同一串指令一定同样；读早上的续玩点重来，发出来的还是那几件（读档刷不出别的）。

### 4.6 钩子与 priority（R01 登记）

| 钩子 | priority | 做什么 |
|---|---|---|
| `day_start` | 70 | 清掉已离场的报价记录；物件 `day_start` 被动 |
| `demand_issue`（新） | — | 物件 `demand_issue` 被动（在 G03 算档位之前） |
| `deal_composed` | 50 | 给今天发出的 `opens_relic` 牌建报价；物件 `deal` 被动；first `relic` / `relic_shop` |
| `card_resolved` | 30 | 物件 `resolved` 被动（按 `on_actions` 过滤）；规则级触发 |
| `night_chosen` | 30 | 物件 `night` 被动；规则级触发（后门收货计数） |
| `settle` | 45 | 物件 `settle` 被动；46：`check_evolve`；不灵状态变化时发 first `relic_dormant` |
| `month_close` | 30 | 物件 `month_close` 被动，`relic.month_done[stage]` 挡住重入 |
| `year_jump` | 60 | 物件 `year_jump` 被动 |
| `arrested` / `money_short` | 30 | 同名被动 |
| `day_end` | 12 | 已离场的报价记录标 `lapsed`（G02 在 10 已按没理会处理了牌本身） |

修正项提供者：`price_pct` `patience_pct` `appraise_pct` `cap` `pool_pct` `deal_count` `intake_blocked` `coins` `scheduled_cards` `view_section` `card_view_part`。`pool_pct` 另管货郎：他 `gap_days` 天内来过时对 `p.any.curio_peddler` 返回 0。`scheduled_cards` 对 `abs_day` 算出那天的关内日子，`offer.days` 里到期、本关没发过、`skip_when` 不成立、不在牢里的，就返回那张牌（`CardComposer.project()` 预测未来也走它，所以签照样准）。

---

## 五、界面（1280×720，网页原型的样子）

### 5.1 场景里的博古格（常驻）

```
y 0  ┌──────────────────────────────────────────────────────────────────────────────────┐
     │德厚当 民国廿八年腊月初一·星期一 晴 宜收当 忌出行             412 蚨 口碑 有人提起 风声 平静│ HUD
y 30 ├────┬──────────────────────────────────────────────────────────────────────────┬────┤
     │人脉│   [窗]         [告示]  ┌────────── 门 ──────────┐ [招牌]  ┌黄历┐           │货架│
     │    │                        │                        │         └────┘           │    │
     │条子│                        │       (客人立绘)        │ [条子墙]                  │当票│
     │    │                        │                        │        ┌─ 博古格 ─┐       │    │
     │档案│                        │                        │        │▣  ▣  ▣ │ [灯]  │家当│
     │    │                        │                        │        │▣  ▣  · │       │    │
     │规矩│                        └────────────────────────┘        └────────┘       │设置│
y400 ├────┴──────────────────────────────────────────────────────────────────────────┴────┤
     │ [放大镜] [算盘]              (柜台上的东西)                 [账簿]  [档案簿]          │
     │ [钱匣]                                                     ┌──────────────┐        │
     │ ┌沈如花┐ [人脉][人脉][人脉]     ╲ 手 牌 扇 ╱                 │ 打烊 · 下一天 │        │
y720 └──────────────────────────────────────────────────────────────────────────────────┘
```

- 博古格 `CardLayout.CURIO` = (948, 240, 208, 152)：底图 `prop.curio_shelf` 52×38 ×4；3×2 六格，每格 64×64，物件 `relic.<slug>` 32×32 ×2。拿到的先后从左上往右下摆；超过格数的（被塞的）摆在格子顶上（最多 2 件）。
- 不灵的物件画暗（配色 `relic_dim`）；晦气的物件格子挂一根红绳（`relic_curse`）。
- 悬停一格：一行小字（物件名 + 不灵时那句 `dormant`）。点博古格（热点 `curio`）= 开右抽屉 `relics`。
- 不挡别的：对话框在左上、指引里教的人站在 (944, 144, 192, 256) 时盖在格子前面（教的人在上层），右抽屉打开时盖住它。

### 5.2 盘货：在画面里演（`relic` 面板，呈现 `stage`）

打出“翻库房”这张牌：

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ HUD                                                                              │
│ ┌─ 对话框 (52,38,380,…) ───────────┐        ┌──── 门 ────┐                       │
│ │ 旁白                              │        │  (空柜台)   │      博古格 ▣▣▣       │
│ │ 半个月一回翻库房。压在箱底的几样  │        │            │             ▣▣·       │
│ │ 老东西擦了擦，摆上了柜台。        │        └────────────┘                       │
│ │ ─────────────────────────────── │                                              │
│ │ 1 细看这几样                      │                                              │
│ │ 2 挑 · 豁口的青花猫碗             │                                              │
│ │ 3 挑 · 济生堂的铜药碾             │                                              │
│ │ 4 挑 · 蓝布棉门帘                 │                                              │
│ │ 5 都放回库房                      │                                              │
│ │ 6 回头再说                        │                                              │
│ └──────────────────────────────────┘                                              │
│ 柜台 ─────────── [碗]          [药碾]          [门帘] ───────────── (prop 位)       │
│                (128,138)       (160,138)       (192,138)  场景坐标，×2 画         │
│ 头像 人脉        ╲ 手牌扇 ╱                                    [打烊 · 下一天]      │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- 三件东西用 `counter_left` / `counter_mid` / `counter_right` 三个道具位，按 ×2 画（64 px），柜台物件的写法同合同 §1.2；只有两件时用左右两个。
- 点柜台上任一件 = “细看”。回话“挑 · <名>”直接挑；满了时见 §5.4。
- “回头再说”/ Esc = 收场，牌留在手上（stage 面板的“算了”）。

### 5.3 细看：三件并排（叠层，面板自己画，`a.relic.compare`）

```
                 (160,96) ┌──────────────────────── 960 × 528 ────────────────────────┐
                          │  库房里翻出来的                                       [合上]│
                          │ ┌──── 288×400 ────┐ ┌──── 288×400 ────┐ ┌──── 288×400 ────┐│
                          │ │ 寻常家什    木框 │ │ 有来历的  朱漆框 │ │ 寻常家什   木框 ││
                          │ │   ┌────────┐    │ │   ┌────────┐    │ │   ┌────────┐   ││
                          │ │   │ 32×32  │    │ │   │  ×4    │    │ │   │ 128px  │   ││
                          │ │   │  ×4    │    │ │   │        │    │ │   │        │   ││
                          │ │   └────────┘    │ │   └────────┘    │ │   └────────┘   ││
                          │ │ 豁口的青花猫碗   │ │ 济生堂的铜药碾   │ │ 蓝布棉门帘      ││
                          │ │ 隔壁裁缝家搬走  │ │ 陈家老先生当年  │ │ 母亲那年冬天缝  ││
                          │ │ 时留下的……      │ │ 抵在这儿……      │ │ 的……            ││
                          │ │ 好处 猫蹲在柜上 │ │ 好处 药材一比就 │ │ 好处 客人肯多等 ││
                          │ │ 陪着，你看得更… │ │ 知道成色……      │ │ 一会儿          ││
                          │ │ 毛病 猫不在时…  │ │ 毛病 查药材的人 │ │ 毛病 买家少看见 ││
                          │ │                 │ │ 进门先看它      │ │ 货              ││
                          │ │ 铺子没了就不灵  │ │ 铺子没了就不灵  │ │ 铺子没了就不灵  ││
                          │ │  [ 就要这件 ]   │ │  [ 就要这件 ]   │ │  [ 就要这件 ]   ││
                          │ └─────────────────┘ └─────────────────┘ └─────────────────┘│
                          │           [ 都放回库房 ]              [ 回头再说 ]          │
                          └────────────────────────────────────────────────────────────┘
```

- 卡用手牌的“选中放大”尺寸 288×400（合同 §1.2），框 `frame.relic.<grade>` ×4；物件图 ×4 = 128 px；名 20 px（标题字）；来历 16 px 最多 4 行，超出“…”，点开看全文；“好处”“毛病”两个小标签用配色 `good` / `seal`，后面是人写的一句；有 `dormant` 的写在最下一行（`ink_soft`）。
- 有陈文庭时药碾子的“好处”句子后面多一行“陈文庭在：……”（正文键 `rl.chen_mortar#lines.with_chen`，可省）——条件相生要让玩家看见“和谁有关”，但不说多大。
- 没有任何数字、百分号、星级；来历深浅只用框和左上角两个字。
- 能用键盘：1–3 选卡、Enter = 就要这件、Esc = 合上。

### 5.4 满了：让出一件（`a.relic.replace`）

在 5.3 的叠层下半截换成：

```
                          │  博古格满了。要摆这件，就得让出一件（送回库房，这一局不会再翻出来）：   │
                          │  [▣ 存根匣] [▣ 油纸伞] [▣ 门帘] [▣ 药碾] [▣ 印泥盒] [▣ 停钟·送不走]     │
                          │  选中：油纸伞                 [ 让出它，摆上新的 ]   [ 那就不要了 ]     │
```

- 6 个 64×64 小格（×2），晦气的灰着写“送不走”。“那就不要了”回到 5.3。确认才发 `relic.take {uid, relic, replace}`。

### 5.5 货郎（`relic` 面板，`mode: "shop"`）

货郎立绘站柜台前、竹筐 `prop.peddler_baskets` 放门边。对话框回话：“看看担子里的”“把博古格上的东西卖给他”“请他把晦气的东西带走”“送客”。三个回话各开同一个叠层的三页：

- **担子里的**：三张 288×400 卡，按钮“买下 · 45 蚨”（钱数看得见；钱不够按钮灰，原因句 `r01.reason.money`）；买一件他就走。
- **卖给他**：博古格六格，每格下面“卖 · 18 蚨”；晦气的不收。
- **晦气的**：只列晦气的，“请他带走 · 贴 20 蚨”。

### 5.6 博古格抽屉（右抽屉 `relics`，420×690，`a.relics.list`）

```
┌─────────────── 博古格 · 4/6 ──────────[合上]┐
│ ▣ 济生堂的铜药碾          有来历的          │
│   陈家老先生当年抵在这儿……  (点开看全文)     │
│   好处 药材一比就知道成色……                 │
│   毛病 查药材的人进门先看它                 │
│                                [送回库房]   │
│ ─────────────────────────────────────────── │
│ ▣ 老宅的樟木箱            有来历的   (暗)   │
│   不灵：老宅押出去了，箱子搬不出来           │
│ ─────────────────────────────────────────── │
│ ▣ 停了的座钟              晦气的   [红绳]   │
│   毛病 柜上的钟不走，客人心里发慌            │
│                                  送不走      │
│ ─────────────────────────────────────────── │
│ 柜上三件：有了两件                          │
│   凑齐两件：客人看你这柜上像回事……           │
└─────────────────────────────────────────────┘
```

- 每行 400×~120：物件 ×2（64 px）、名、来历深浅两个字、来历一行、好处 / 毛病各一句、状态（暗 = 不灵、红绳 = 晦气）。“送回库房”= `relic.release`（先在行内确认一句“送回去就不会再翻出来了”）。
- 格数 4/6 是看得见的数（同货架 3/6），不算隐藏值。
- “合上”、点遮罩、Esc 只关（同合同 §7.8 新抽屉的规矩）。

### 5.7 演出、新手指引、月底与结局

- **拿到**：东西先出现在柜台中间（`counter_mid`），对话框一句 `lines.gain`（可省），然后 0.6 秒飞进它的格子，格子亮一下（`gold_glow`）。快动画开着时直接出现在格子里。
- **修好**：格子里的停钟换成走钟，`warm` 效果一闪，对话框一句 `lines.evolve`。
- **被拿走**：格子空出来，一句 `notice`（数据写的原因）。
- **月底结账**（C09，第二批）：账目最后一行预告“盘点库房，翻出几样老东西，明年开张摆上柜”（界面键）。**局终**（C09）：结局文字后面列“博古格上还摆着”，每件一句 `epilogue`。

**新手指引**（K16 的 `steps.json` 跨线新增；`rule_pages.json` 加两页）：

| 步骤 | 机制 `first` | 谁教 | 锚点（备用） | 讲什么（brief） | 完成 |
|---|---|---|---|---|---|
| `gd.relic` | `relic` | `curio_peddler`（1938 第 8 天他头一回进门） | `a.relic.objects`（`a.hand`） | 老东西摆在后墙的博古格上，各有脾气：有的帮你，有的拖累你；一回只能留一件 | `cmd:relic.take` `cmd:relic.pass` `timeout` |
| `gd.relic_shelf` | `relic` | `obj.brother_ledger` | `a.scene.curio`（`a.relics.list`） | 第一次拿到东西后：点博古格看它们的来历；格子有数 | `panel:relics` `timeout` |
| `gd.relic_full` | `relic_full` | `obj.brother_ledger` | `a.relic.replace` | 满了要让出一件；送回去的不会再翻出来 | `cmd:relic.take` `timeout` |
| `gd.relic_shop` | `relic_shop` | `curio_peddler` | `a.relic.shop` | 他周末来；买、卖、请他带走晦气的，都是现钱 | `cmd:relic.pass` `cmd:relic.take` `timeout` |
| `gd.relic_curse` | `relic_curse` | `suanming` | `a.scene.curio` | 这东西晦气，留不得也扔不得：找货郎、找城隍庙，或者想法子修好 | `timeout` |
| `gd.relic_dormant` | `relic_dormant` | `obj.brother_ledger` | `a.scene.curio` | 东西暗了是不灵了，看抽屉里那句话 | `panel:relics` `timeout` |
| （`relic_evolve` 由 `gd.relic_curse` 的规矩页一并讲） | `relic_evolve` | — | — | 规矩页 `rule.relic_curse` 里写“有的能修好” | — |

规矩页：`rule.relic`（`unlock_first: ["relic", "relic_full", "relic_shop", "relic_dormant"]`）、`rule.relic_curse`（`["relic_curse", "relic_evolve"]`）。

### 5.8 文案约定（给 A，不进代码）

- **量词表**（只用词，不用数）：效果小（≤ 5%，一档以内）写“一点 / 稍微”；中等（6–15%）写“不少 / 明显”；大（> 15%）写“大不一样 / 多得多”。能数得清的游戏物件可以直说（“多留一张牌”“货架多两格”“多一位客人”），因为格数、张数本来就在画面上。
- 好处、毛病写**铺子里看得见的变化**，不写机制名：不写“耐心”“鉴定清晰度”“权重”“档位”，写“客人肯多等”“一比就知道成色”“这类事找上门多一点”“条子来时松一点”。
- 来历写**人、年、为什么留在这儿**，2–4 句，不写结论；时局措辞照 era.json（伪字、沦陷、不写血腥）。
- 禁用词：加成、触发、冷却、属性、稀有、传说、史诗、遗物、装备、BUFF、%、倍、概率。
- 来历深浅的四个词（界面键 `r05.grade.*`）：寻常家什、有来历的、镇店的、晦气的。

---

## 六、存档、确定性、黄金种子

### 6.1 确定性

- 随机只有两处：摆盘货（`c.relic.offer`，键 `[stage, stage_day, slot, "g"/"r"/"q"]`）、货郎担子（`c.relic.shop`，键 `[abs_day, uid, slot, …]`）。都在发牌那一刻抽一次、记下来。
- 物件效果不掷随机；修正项按持有顺序乘（`CardMods.pct` 每步向下取整，顺序固定所以结果固定），再钳住。
- 遍历持有列表、成套、报价记录都先排序（持有列表本身就是有序数组）。
- 规则级触发（铜香炉）是计数，不是随机：第三回后门收货一定来，玩家能摸出规律。

### 6.2 存档

- 命名空间 `relic` 跟着 `CardSave` 走，信封不变；`_v: 1` 给以后迁移。
- 旧存档（没有 `relic`）照读：物件系统从空开始；`db_hash` 不同所以 `meta.db_changed = true`（合同已允许）。
- `game.retry_stage` 读本关开头的 `stage_XX.json`：本关里拿到、失去、修好的都回到本关开头（和留牌、人脉一样）。
- 续玩点（每天早上）：盘货牌在白天发，读早上的续玩点重来，发出来的还是同一张牌、同样三件。
- 存档大小：每件物件几十字节，报价记录每天清。远低于 512 KB 预算。

### 6.3 黄金种子（合同 §12.5）

| 合入步骤 | 例子集用例（`only_examples`） | 真数据用例 | 怎么证明 |
|---|---|---|---|
| R00 常量与形状、R01 引擎（无数据） | 不变 | 不变 | 模块看到 `rules("relics")` 为空就什么都不登记进状态；`G06_golden` 必须照旧绿 |
| R03 策略（引擎和策略都在，数据还没有） | 不变 | 不变 | 同上 |
| R02 数据（`rules/relics.json` + `relics/**`） | **变**，只因 `db_hash`（规则文件被例子集也读进来） | **变**：第 8 天货郎、第 16 天盘货进手牌，策略开始挑 | 例子集：照宠物猫那次（`docs/cards/balance/golden_changes_2026-10-16_pet.md`）的做法，把状态里的 `db_hash` 置空后，新旧 10/20/30 天的“blanked”哈希完全相同；例子集没有 `ev.any.relic_offer`，`scheduled_cards` 先查 `ctx.db.has()`，所以行为不变。真数据：写 `docs/cards/balance/golden_changes_<日期>_relics.md` 说明原因（新系统牌、策略挑选），标签 `golden-change`，单独一个只改 `golden.json` 的提交 |

建议合入顺序 R00 → R01 → R03 → R02，这样黄金哈希只重算一次。

### 6.4 自动玩策略（G06）

策略只看视图和查询，看不到效果：

| 策略 | 物件 |
|---|---|
| `fair` | 打出盘货牌，挑第一件不需要让出的；满了就“都放回”；货郎：送客 |
| `greedy` | 挑来历最深的（镇店 > 有来历 > 寻常），满了让出最浅的、可让的；货郎钱够就买 |
| `hoarder` | 能拿就拿，满了让出最早的；从不卖 |
| `kind` | 同 `fair`；长命锁来认时“还给他” |
| `wheel` · `random` | `random` 随机挑一个合法动作（包括让出、卖、带走） |
| `refuser` | 什么都不做（拿不到任何物件——这是有意的） |

遥测加：每局拿到哪些、何时拿到、局末持有、被让出 / 卖出、修好次数、晦气持有天数；报告加一节“物件”：各件被挑率、持有与不持有时的过关率差、月底现金差。

---

## 七、平衡风险与对策

| 风险 | 表现 | 对策 |
|---|---|---|
| 滚雪球 | 差价物件 + 鉴定 + 货架叠起来，后两关钱多到条子没压力 | 同类修正乘积钳住（`clamp`）；差价压的是看得见的三档价，客人底线藏着，付得少走得多；镇店的都带重毛病；格子 6 |
| 条子被玩没 | 烟袋 + 马万利两个降档 | 烟袋 `dormant_when has_contact ma`（相克）；档位本来就有下限 0 |
| 风声死循环 | 铜香炉 + 老匾 + 马万利，风声只涨不落，被抓 | 香炉自带去处牌（城隍庙）和货郎“带走”；老匾的毛病只抵掉自然回落、不额外加；平衡报告看“持有晦气的天数 × 被抓率” |
| 物件变现太赚 | 白给的物件卖给货郎换钱，一局多出两三百蚨 | `buy_back_pct` 起步 40【待调】；只能卖给在场的货郎（每周最多一回）；卖了就不会再出现 |
| refuser 问题（#198）更显眼 | 主动打法有了物件更强，refuser 照样能活 | 本系统不解决 #198，但方向一致（拉开主动和被动的差距）；条子后果仍待主创定 |
| 选择太多看不过来 | 三件并排，每件来历 + 好处 + 毛病 | 好处、毛病各一句；来历最多 4 行；场景里只看图 |
| 词不达意 | “一点”“不少”写得不一致，玩家被误导 | §5.8 量词表；K13 审读正文时对着 `brief` 里的真数查 |
| 隐藏值从侧面漏 | 有人写“多赚一成” | 禁用数字；`brief` 只给 A 看；发行审核扫正文里的 `%` 和数字（K15 已有 `%` 检查） |
| 指引过载 | 1938 第 4–7 天已经很密 | 第一次在第 8 天，由货郎一个人讲；其余等第一次发生时才讲 |
| 性能 | `pool_pct` 每抽一张都问一遍 | 每个提供者只遍历 ≤ 8 件、每件 ≤ 4 行；`when` 只用便宜的条件；物件定义缓存成不可变常量（允许的 `static var` 例外）；预算 `day.begin` ≤ 10 ms 照测 |
| 存档兼容 | 改了 `relic` 字段含义 | `_v` 迁移；物件 id 合入后不改名（存档里有） |
| 不卡死 | 满了、货郎在、盘货牌在、晦气的在，任何组合下打烊 | 没有新待办；`G06_no_deadlock` 加五条新指令后 ≥ 1000 局 |

---

## 八、先做什么

**第一刀（能玩的最小一片）**：

1. R00：常量、形状、坐标、合同章节（Claude）。
2. R01：引擎骨架——命名空间、`relic.take` / `relic.pass` / `relic.release`、满了要 `replace`、八种修正、`day_start` `settle` `night` `resolved` `demand_issue` 五个钩子、不灵、钳子、盘货日程与抽、视图与两个查询。**先不做**：货郎买卖、晦气、修好、成套、规则级触发。
3. R02-lite：8 件——`rl.cat_bowl` `rl.stub_box` `rl.blue_curtain` `rl.oilpaper_umbrella` `rl.chen_mortar` `rl.hu2_pipe` `rl.camphor_chest` `rl.rosewood_abacus`（`set` 先空着）；系统牌 `ev.any.relic_offer` `ev.any.relic_newyear` `p.curio_peddler.1938.first`；`text_ai` 占位。
4. R05-lite：盘货演出 + 细看叠层 + 让出一件 + 博古格抽屉；R06：场景博古格与热点；R07：`gd.relic` `gd.relic_shelf` `gd.relic_full` 三步与 `rule.relic`。
5. R03：`fair` / `greedy` / `hoarder` 会挑；黄金种子重算一次；平衡跑“物件开 / 关”（`balance_overrides.json` 里 `{"relics": {"enabled": false}}`）各 20 种子 × 7 策略 × 3 关，对照过关率与月底现金。

**这一刀要回答的问题**：三选一好不好玩、6 格紧不紧、量词表写出来玩家懂不懂、差价物件会不会把后两关玩坏。

**第二刀**：货郎买卖、晦气两件与城隍庙、座钟修好、长命锁来认、柜上三件、其余 9 件、月底预告与结局一句、`relic_dormant` `relic_curse` `relic_shop` 指引。
**第三刀（跨线内容）**：大轮盘翻身 / 坠底段给、拿物件（K10）；档案页补齐给信物（K08）；主线人物的选项给物件（K01/K03/K05）；“钱不够”面板里当掉一件（G06）；吓唬与樟木箱夹层（要 G03 的 `kept_risk` 修正项）。

---

## 九、实施拆包（互相独立，能并行）

> 任务号用 `R00`–`R08`（避开 K18 一号三用的问题；编排可改）。每个包都按合同 §13 的 PR 模板交，PR 路径检查 `check_pr_paths.py --task=<号>`。

| 包 | 谁做（建议） | 文件 | 依赖 | 交付与测试 | 规模 |
|---|---|---|---|---|---|
| **R00 常量与合同** | Claude | `scripts/cards/api/{card_ids,dsl_shapes,card_layout}.gd`、`data/cards/_schema/relic.json`（+ event/person 三个字段）、`palette.dev.json`、合同 §4.7.25 / §5 / §6.3 / §7.4 / §7.5 / §7.8 / §7.10.10 / §7.11.2、`ownership.json`、`DESIGN_cards.md`（主创点头后）、`_examples` 里一件例子物件（只在 `_examples/relics/` 下，例子集也读） | 主创同意写进 DESIGN | `W0` 测试照绿；新形状函数的正反例；`CardIds.rng_owner("c.relic.offer") == "R01"` | S |
| **R01 引擎模块** | GPT（引擎线） | `scripts/cards/relic/**`、`data/cards/rules/relics.json`（**先不提交**，测试用自己的夹具根）、`data/cards/ui_keys/R01.json`、`scripts/tests/cards/R01/**`、`suites/R01.txt`；`[shared]` 几处小改（各几行）：G02 `card_engine.gd` 安装、G02 `view_model.gd` `panel_of`、G03 `demands.gd` 发钩子、G03 `slots.gd` 带 `wants`、G01 `card_db.gd` `CARD_DIRS`、G01 校验器 V43–V47 | R00 | 单测：八种修正各正反例；五个钩子；不灵；钳子；满了与 `replace`；`relic_full` `not_removable`；`relic_gain force` 超格；`relic_gain` 满了发 `ev.any.relic_gift`；三个 op、三个条件的正例与形状反例；first 各一次、存读后不再发；**确定性**（同种子两遍哈希一样）；**存读一致**（任意阶段存读再走，哈希一样）；`find_floats` 为空；视图与两个查询、所有事件过 `CardViewModel.leaks()`；**每个阶段 `day.end {confirm: true}` 都前进**（手上有盘货牌、货郎、满格时）；预览 = 结算（盘货牌那一行是 `ignore`）；`month_close` 重入只跑一次；没有数据时状态哈希与主线一字不差。测试数据：用 `t.user_dir()` 下拷一份 `res://data/cards` 再放进夹具物件，`new_game({data_root})` | M |
| **R02 数据与占位正文** | Grok（数据线） | `data/cards/relics/{relics,system}.json`、`data/cards/rules/relics.json`（主人 R01，随本包一起合入，好让黄金种子只变一次）、`data/cards/tags/R02.json`、`data/cards/ui_keys/R02.json`、`data/cards/text_ai/relics/**`（AI 基础层，`_meta._provenance`）、`scripts/tests/cards/R02/**` | R00（R01 合入后才有行为） | `validate_main --only=data/cards/relics/… --name=R02_validate` default 全绿、strict V43–V47；数目测试（17 件：寻常 5 / 有来历 7 / 镇店 3 / 晦气 2；每件有 `epilogue`；晦气的都有去处）；K13 审读 `brief` 与正文措辞 | M |
| **R03 自动玩、模糊测试、遥测、黄金种子** | GPT（G06 线）或 R03 | `scripts/cards/sim/{policy,fuzz_actions,telemetry,balance_main}.gd`、`tools/cards/balance/**`、`docs/cards/balance/golden_changes_<日期>_relics.md`、`golden.json`（单独提交） | R01（R02 合入时重算黄金） | 策略单测（看到 `relic` 面板会挑 / 会让 / 会送客）；`G06_no_deadlock` 加五条指令仍 ≥ 1000 局全过；黄金：例子集 blanked 相等、真数据说明原因；平衡报告“物件开 / 关”对照 | M |
| **R04 美术** | 美术线（K12 路径） | `tools/cards/art/gen_ai_relic.py`、`art/ai/relic/*.png`（17 + 框 4 + 博古格 + 竹筐 + 货郎头像与行走 + 系统牌插图 5）、`data/cards/art/manifest.json` 登记 `_provenance` | R00（id 表） | 生成器两次输出字节相同；清单覆盖（V42）；×2 / ×4 看得清（附截图） | M |
| **R05 物件面板与抽屉** | Cursor（界面线） | `scenes/cards/relic/{RelicPanel,RelicsDrawer}.tscn`、`scripts/cards/ui/relic/**`（`RelicPanel extends CardStagePanel`，`RelicsDrawer extends CardPanel`）、`data/cards/ui_keys/R05.json`、`scripts/tests/cards/R05/**`（Mock 夹具 `relic_offer` `relic_offer_full` `relic_shop` `relics_drawer`） | R00；对 Mock 开发，不等 R01 | 实例化与各夹具渲染不报错；回话 / 按钮发出的指令和参数（`mock.sent`）对；`autoplay_step()` 走完盘货、让出、货郎三条路；键盘；所有字来自 CardText；锚点在 `CardLayout` 的矩形里；“回头再说”/ Esc 不发指令；截图（演出、细看、让出、货郎三页、抽屉） | M |
| **R06 场景里的博古格** | C01 主人（`[shared]`） | `scripts/cards/ui/table/card_stage.gd`（及场景）：读 `view.relics` 画格子与物件、暗与红绳、热点 `curio` → 抽屉 `relics`、锚点 `a.scene.curio`；拿到 / 修好的小动画 | R00、R04（缺图时画占位） | `X01_click_smoke` 照绿；点博古格开抽屉；锚点；截图（白天 / 黄昏 / 夜里三个时段都看得清） | S |
| **R07 新手指引** | K16 主人（跨线新增） | `data/cards/guide/steps.json`（6 步）、`rule_pages.json`（2 页）、`text_ai/guide/**` 占位 | R00 | V29 覆盖新机制；V35 只用看得见的条件；K14 真引擎指引走查到第 16 天（盘货）截图 | S |
| **R08 跨线内容（第三刀）** | 各数据主人 | K10 `segments_*.json`（翻身段 `relic_gain rl.old_signboard`、坠底段 `relic_lose {pick: "best"}`）；K08 `pages.json` 的 `on_complete`；K01/K03/K05 主线选项；G06 “钱不够”面板加“当掉一件”；C09 月底预告与结局 `epilogue` | R01、R02 | 各自的校验与测试；平衡复跑 | M |

**并行关系**：R00 先合；然后 R01、R02、R04、R05、R07 同时开工（R05 对 Mock、R02 对校验器、R04 对清单）；R03 在 R01 之后；R06 在 R04 之后（有占位也能先做）；R02 最后合，黄金种子随它重算一次。

---

## 十、需要主创 / 编排决定的事

1. **加不加。** HANDOFF §5.4 写明 N01–N06 “动工前要主创先写进 DESIGN”。本提案同样：主创点头后由编排写进 `DESIGN_cards.md`（建议放 §九.8“博古格与老物件”），再改合同。
2. **来历深浅要不要画在框上。** 本文主张画（木框 / 朱漆 / 金箔 / 墨底红绳 + 两个字），因为它不是概率也不是数；如果主创觉得太“游戏”，可以只在细看里写一句来历，框统一。
3. **格数 6、一局约 6 次白给的挑选** 合不合适。
4. **盘货的时点**：每关第 16 天 + 新年第一天（本文），还是严格只在月底（N03）？本文把“月底盘点”放到第二天开张，是为了不在 `month_close` 阶段加新的待办，打烊和跳年的流程一行不改。
5. **货郎能不能用钱买、能不能把白给的东西卖给他**（变现阀门）。
6. **晦气的东西**：逃难人的停钟（“停在镇子沦陷那天”）这类时局细节请 K13 和主创看一遍措辞。
7. **本心相关的毛病**（紫檀算盘“心也跟着硬”）：用一句话暗示一个看不见的东西在动，是否可以。
8. **最后一关不盘点**，结局里回顾博古格。
9. **和另外两个肉鸽方向的接口**：如果有跨局传承，可以在 `game.new` 的参数里加 `start_relics: [rl.*]`（本文预留，不实现）；如果有路线 / 事件地图，盘货牌可以由地图节点发（`relic_offer` op 已有）。

---

## 附：给实现方的检查清单（交 PR 前逐条过）

- [ ] 没有任何视图字段、查询结果、事件参数里出现 `rarity` `weight` `pct` `value` `tags` 等黑名单键。
- [ ] 界面上没有数字（钱、格数、天数除外）、没有 `%`。
- [ ] 任何状态下 `day.end {confirm: true}` 都前进；盘货牌没处理时清单里是 `ignore` 一行，货郎是 `leave` 一行。
- [ ] 满了不产生任何待办；`relic.take` 没给 `replace` 只返回 `relic_full`。
- [ ] 只用 `c.relic.offer` / `c.relic.shop` 两个域；物件效果里没有隐藏随机。
- [ ] `month_close` 重入只跑一次物件的 `month_close` 被动。
- [ ] 没有物件数据时，状态哈希和合入前一字不差。
- [ ] 每个新机制有 first-time、指引步骤、规矩页、锚点。
- [ ] 正文全走 CardText；`.gd` 里没有中文字面量；AI 写的只在 `brief` 和 `text_ai/**`。
