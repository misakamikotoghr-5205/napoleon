# R3 · 走一趟：一局的结构、选择与加码（肉鸽设计稿）

> 角度：**一局之内的结构、选择、加码**（周图、选客、柜上物件、世道、月底关口、处境、家底与结局、时长）。
> 另两位设计师分别从别的角度做；本稿只在第 11 节写接口，不越界。
> 依据：`docs/cards/DESIGN_cards.md`（主创原话）、`docs/cards/CARDS_INTERFACES.md`（合同 1.5）、`HANDOFF.md` §5.3、`docs/cards/balance/report_2026-10-22_framework.md`、引擎 `scripts/cards/**`、数据 `data/cards/**`、归档提案 `archive/cards/N01`–`N06`。
> 本稿是提案，不是合同。动工前要主创拍板（第 0.3 节），再由编排写进 DESIGN §九.8 和合同新章节。数字都是起步值【待调】。

---

## 0. 给主创的一页

### 0.1 一句话

新开一种玩法 **“走一趟”**：一趟就是一个月。开张前抽三种**处境**挑一种；月初转**天时**（就是现有的命运轮盘）；这个月有四周，每周在**本月的路**上挑一个周牌（集日周、庙会周、宵禁周、查铺周、歇一歇……）；每周末**盘账**：挑**下周门口来谁**（客源，三选一），生意做得够还能挑一样**赏**（柜上物件、人情、门路）；条子没办成，**世道**一档档变紧；月底 29 号有一道**关口**（伪警察所开门、年关讨账、新官上任），要靠这个月攒下的人、货、证件、人情才过得去；月底按**家底**定结局。目标时长 **30–60 分钟一趟**。

原来的三关连着玩（下面叫**本传**）一点不改。走一趟用的是同一套引擎、同一批牌，靠一个新模块把选择和加码叠上去。熟练以后可以开**三幕连走**：1938 → 1939 → 1940 连着走三趟，东西带着走。

### 0.2 为什么能治“全拒最安全”

现在什么都不做只按打烊的 refuser 三关 20/20 全过（报告 10-22）。原因有两层：

- 条子没办成、生活牌过期，对不做生意的人不疼；
- 做生意本身几乎不赚钱。

本稿另外量了一个数：随机人物牌库里**来买的人**占的权重，1938 年 25/211（12%），1939 年 21/320（7%），**1940 年只有 6/287（2%）**（另有通用池 6/59）。所以货架上的东西基本卖不出去，收货就是压钱。

走一趟用结构解决，不靠单调一个数：

1. **赏只给做生意的人**：一周做成两笔以上才有赏；赏会叠加（柜上物件、人情、门路）。
2. **月底关口要的是攒下的东西**：铺保（有门路的人或人情）、证件、像样的货。光有钱、光会打烊过不去；花大钱“认罚”能过，但家底掉一截。
3. **世道会紧**：条子没办成，世道紧一档，下周的条子跟着升档（就是报告里那条“上周没办成，这周加码”，这里写成走一趟的规矩，不改本传）。全拒的人第三周就碰到“拿走家当”和“抓人”那两档。
4. **结局看家底**：家底只用看得见的数算（现钱 + 货架按公道价 + 当出去的本钱 + 没押的家当）。熬过一个月只是最低一档。
5. **选客就是组牌**：挑“行家”“逃难急当的”这类客源，把来买的人、肯低价当的人加进牌库，做生意才有赚头。赚头大的路子往往伤本心、或招风声，不分黑白。

### 0.3 要主创拍板的事

| # | 要定的事 | 本稿的建议 |
|---|---|---|
| 1 | 走一趟是新玩法，还是把本传改成肉鸽 | 新玩法；本传不动（剧本、存档、黄金种子都不受影响） |
| 2 | 一趟多长 | 一个月 = 一趟（30–60 分钟）；三幕连走是解锁后的长局（约 2–2.5 小时） |
| 3 | “闲日”：一周里只有几天坐柜台，别的日子铺子半掩门、只办找上门的事，可以一键“过到有事那天” | 采用。DESIGN §八原话就有“太长就把平淡的日子合并” |
| 4 | 世道：上周条子没办成，这周加码 | 采用，只在走一趟里 |
| 5 | 结局按“家底”（账面）分档 | 采用；账面只用看得见的数，货架上的假货也按看得见的估价算（账面本来就会骗人） |
| 6 | 最赚钱的客源会伤本心（逃难急当的）或招风声（日商茧行的买办） | 采用，符合“贴近生活，不分黑白”；本心照旧不显示 |
| 7 | 走一趟输了能不能“重走这一趟”（同种子） | 能，但这一趟的分记“重走过” |
| 8 | 局外解锁（年份、难度档） | 只做最小的：走到“站住”解锁下一年；难度档名字由主创定（暂称“行路难”一至五） |

---

## 1. 现状：能借用的东西和要补的东西

| 已有（合同里冻结或已实现） | 走一趟怎么用 |
|---|---|
| 牌库权重、修正项 `pool_pct` `deal_count` `scheduled_cards` `price_pct` `patience_pct` `appraise_pct` `cap` `end_rows` `view_section`（§7.3） | 客源、周牌、柜上物件全部挂在这些修正项上，**不改发牌和柜台的代码** |
| 本月运势轮盘 `wh.month`（`fate/wheel.gd`） | 就是“天时”，原样用 |
| 大轮盘、庙会、赌摊 `wh.big` `wh.fair` `wh.gamble`；事件 `ev.any.fair` `ev.any.curfew` `ev.any.market_haggle` `ev.1940.shop_search` | 周牌固定发这些牌 |
| 条子 `rules/demands.gd`、效果 op `demand_tier` | 世道通过 `demand_tier` 加码，不改 `demand_rules.json` |
| 打烊清单与 `end_rows`、`auto_spin` 的先例（`loop/end_day_rules.gd`） | 没选的处境、周牌照 `auto_spin` 的做法“替你选” |
| K18 收徒装在冻结六段之后（`apprentice/apprentice_install.gd`） | 新模块 `scripts/cards/run/` 照这个先例装在最后 |
| 存档：开月一份、每天早上续玩点 | 不变；走一趟的状态在新命名空间 `run` 里一起存 |
| N03 镇店之宝 9 件（`archive/cards/N03-relic-month`） | 直接做成柜上物件的第一批 |
| N06 进货路线、局外传承；N02 禁收令 | 第二版做成“进货周”“查禁周”两种周牌；传承接到 RUN6 |

要补的：一种玩法开关（`game.new` 的 `mode`）、四种新的数据类型（周牌、客源、柜上物件、处境）、一个新模块、四块界面、几条合同常量、模拟里的三种新策略。

---

## 2. 玩家怎么走一趟（1938 三月，一趟约 45–55 分钟）

**标题 → 走一趟**（约 1 分钟）
标题上多一个“走一趟”。选年份（一开始只有民国廿七年三月）、难度档（一开始只有一档）。点“开张”。

**开月**（约 2 分钟）
1. 开月过场照旧三页（时局、铺子、家里）。
2. **处境**：桌上摆三张处境牌，挑一张。比如“哥哥留下的债”（开局多 150；第 20 天赵老三上门要 200）、“老字号底子”（口碑高一档、钱少 60）、“刚遭过贼”（货架空、多 80 现钱）。
3. **天时**：转本月运势轮盘，和本传一样，可以往香案上放东西。
4. **本月的路**：一张月份牌摊开。第一周是固定的“开张”（哥哥教你，第 1–3 天照本传的教学日）。后三周每周两三个周牌可走，月底是关口“伪警察所开门”，牌面上写着它要什么：铺保、证件、见面礼、会说话的人。
5. **第一拨客源**：三张客源挑一张。比如“码头上的人”（银元、杂货多）、“行家”（上海来的买主，只看书画首饰，出手大方）、“逃难急当的”（便宜当东西，压价他也接）。

**第一周 · 开张**（约 15 分钟）
照本传的头七天：哥哥教柜台，第 2 天哥哥走，第 3 天一张带格子的事件，第 5 天算命先生，第 6 天周妈。周牌“开张”开门五天，第 5、7 天是**闲日**：铺子半掩门，门口不来生客，只来赎当的、送信的、主线的人。闲日早上按钮旁多一个“过到有事那天”，一按就过到下一个要你拿主意的时候（中间每天的结果在对话框里一行行说）。

第 7 天（星期一）胡二送来第一张条子。当晚打烊后是**周末盘账**：
- 这周的账：做成 3 笔、进 182 出 141、条子刚来、世道“平”、交了这周的开销 10。
- 下周门口来谁：三张客源挑一张。
- 这周的赏：做成两笔以上，有三样挑一样，比如“铜戥子”（柜上物件：卖货的价硬一点）、“胡二欠的一次人情”（留着的牌，官面格子算 2 个正面）、“陈文庭”（人脉）。
- 下周的路：从“集日周 / 宵禁周 / 歇一歇”里挑一条。

**第二到第四周**（每周约 8–10 分钟）
集日周开门四天，集日那天多来一位客，来买的人多；宵禁周只开两天，门口人少，夜里后门的货便宜，风声也动；查铺周第三天一定查铺，过了多给一样稀有的赏、世道松一档；歇一歇只开一天，能挑一样：风声退一档 / 你自己的某项本事 +1 / 谢绝闲人（以后来打听的人少一半）。

条子按时办成，世道不动；没办成，世道紧一档，下周的条子升一档。第三周起，没办条子的人会碰到“拿走一件家当”。

**月底 · 关口**（约 6 分钟）
第 29 天早上，伪警察所的人站在门口，要你登记铺保。柜台上四个格子：铺保（有门路的人或一张人情）、证件、见面礼（一件像样的货）、会说话的人。世道越紧，要的正面越多。过不去也可以“认罚”交一大笔钱。第 30 天是最后一天。

**这一趟走完**（约 2 分钟）
月底结账照旧。然后是结局：
- 家底：现钱 286、货架按公道价 180、当出去的本钱 75、没押的家当 930，合计 1471，开张时 1350。
- 关口：过了。本月目标：主线完成，可选一个。
- 结局：**站住了**。下面是两三段“街坊怎么说你”。
- 这一趟的分：331。
- 解锁：下回能走民国廿八年腊月。

按钮：“再走一趟”（新种子）、“回标题”。

---

## 3. 规则

### 3.1 一趟的形状

| 玩法 | 怎么开 | 长度 | 本稿管不管 |
|---|---|---|---|
| 本传 | 原来的“开张” | 三关连着，约 4–6 小时 | 不改一行规则 |
| 走一趟（单幕） | `game.new {mode: "run", stage: s, stages: 1}` | 一个月，30–60 分钟 | 本稿主体 |
| 三幕连走 | `game.new {mode: "run", stage: 0, stages: 3}` | 三个月，约 2–2.5 小时 | 同一套规则，跨年时东西带着走（3.13） |

- 一个月 = 4 个“周”（第 1–7、8–14、15–21、22–28 天，按本关天数切，不按星期几）+ **月底两天**（第 29、30 天）。
- 1939、1940 的单幕从该年开局：`stage_start` 已经能从中间某关开新局（G04 定币种和物价指数，G06 建家当，G03 建三项名声）。开局现钱按 `run.json.start_money` 换算物价（3.2）。

### 3.2 开局处境（`og.*`）

- 只在一趟的第一个月有。`stage_start` 时用 `c.run.origin [k]` 从本年代的处境池里不放回抽 3 张（按 `weight`），存进 `run.origin.offers`。
- 玩家在 `month_open` 用 `run.pick {slot: "origin", id}` 挑一张；不挑，进第 1 天早上时替你挑**第一张**，打烊清单里有一行 `auto_pick`（要确认，见 3.14）。
- 处境在第 1 天 `day_start`（priority 1，发牌之前）生效：执行它的 `effects`（钱、留着的牌、把一件家当先押着、排一张以后来的牌……），并把它带的客源、物件放进 `run`。
- 起步 6 张（1938）：

| id | 带着什么 | 代价 |
|---|---|---|
| `og.brother_debt` 哥哥留下的债 | 现钱 +150 | 第 20 天生活牌 `lf.1938.run_debt_zhao`（要还 200，到期没还口碑掉一档、赵老三记仇） |
| `og.old_name` 老字号底子 | 口碑上一档；客源“老主顾” | 现钱 −60 |
| `og.robbed` 刚遭过贼 | 现钱 +80 | 货架上限 −2（柜上物件“破门锁”，可在歇一歇里修好） |
| `og.levy_kin` 和维持会沾亲 | 头两周条子降一档（`demand_tier −1` 两次） | 本心 −5；风声起步 +10 |
| `og.neighbors` 邻里帮衬 | 人脉周妈提前到（第 1 天） | 生活牌多一些（`pool_pct` 生活池不适用，改为第 3、10 天各排一张人情生活牌） |
| `og.sick_mother` 家里有病人 | 本心 +5；夜牌“回家吃饭”必出 | 每周多一张看病的生活牌 |

1939、1940 各再写 4–6 张（例：1939“去年的当票”开局带三张别人的当票；1940“孙府的旧情”带 `kp.sunfu_letter` 但风声起步高）。

### 3.3 天时与难度档

- **天时** = 现有本月运势轮盘 `wh.month`。规则、香案、`auto_spin` 全不变。
- **难度档**（`run.level`，0 起）：开局时由标题传进 `game.new {level}`，存进状态，确定性不受影响。每档在 `run.json.levels` 里改几样数（全是整数键，`balance_overrides` 能只改数）：

| 档 | 改什么（起步） |
|---|---|
| 0 | — |
| 1 | 每周开销 ×1.5 |
| 2 | 关口要的正面 +1 |
| 3 | 周末客源只给 2 张 |
| 4 | 世道起步 +1 |

第一版只开 0 档；档的解锁见 RUN6。

### 3.4 本月的路（周图）

**形状**：4 行（第一到第四周）+ 关口。每行 2–3 个节点；节点之间按位置连线，线不交叉。1938 第一行固定是 `wk.1938.open`。

**节点 = 周牌（`wk.*`）**。第一版 7 种 + 年代专属：

| id | 名 | 能在哪几周 | 开门几天 | 这周的牌库 | 固定发的牌（这周第几天） | 赏 | 世道 |
|---|---|---|---|---|---|---|---|
| `wk.any.plain` | 平常周 | 2–4 | 4（第 1、2、4、6 天） | — | — | 普通 | — |
| `wk.any.market` | 集日周 | 2–4 | 4（集日优先） | 来买的 ×1.5；集日那天多一位客；官面事件 ×1.2 | `ev.any.market_haggle`（2） | 普通 | — |
| `wk.any.temple_fair` | 庙会周 | 2–4 | 3 | 买书画首饰的 ×1.3；算命、庙会类事件 ×2 | `ev.any.fair`（3）、`ev.any.fortune_teller`（4） | 普通 | — |
| `wk.any.curfew` | 宵禁周 | 2–4 | 2 | 每天少一位客；夜牌“后门收货”×3 | `ev.any.curfew`（1） | 普通，偏钱和人情 | 风声 +5 |
| `wk.any.inspect` | 查铺周（险） | 3–4 | 3 | 官面、查铺事件 ×1.5 | `ev.any.run_inspect`（3） | 过了：多挑一样，含稀有 | 过了松一档 |
| `wk.any.rest` | 歇一歇 | 2–4 | 1 | — | `ev.any.run_rest`（1） | 没有赏（歇的选项就是赏） | — |
| `wk.any.black` | 黑市周（险） | 3–4 | 3 | 违禁买主；后门 ×2；查铺 ×1.3 | `ev.any.run_black_buyer`（2） | 稀有 | 紧一档 |
| `wk.1938.open` | 开张（固定） | 1938 第 1 周 | 5（第 1–4、6 天） | 本传教学 | 本传日程照发 | 普通 | — |
| `wk.1939.yearend` | 年关周 | 1939 第 4 周 | 5 | 来赎的 ×2；当衣服的 ×1.5 | `ev.1939.year_debt`（3） | 普通 | — |
| `wk.1940.new_rules` | 新规矩周 | 1940 第 2–3 周 | 3 | 官面 ×1.5 | `ev.1940.levy_rename`（1） | 普通 | 紧一档 |

- “开门几天”是看得见的（写在周牌上）；权重、倍数都不显示。
- 每月限制：`wk.any.inspect` 最多 1 个，`wk.any.rest` 最多 2 个；同一行不重复；每行至少一个不是“歇一歇”的。
- **选路**：周末盘账时（或开月时选第一周）用 `run.pick {slot: "week", id: <节点号>}`，只能选和当前节点连着的。没选：进下周第一天早上时替你选**连着的第一个**（最上面那个），打烊清单里一行 `auto_pick`。

### 3.5 一周：开门日、闲日、过到有事那天

- **开门日**：照本传发牌。
- **闲日**：铺子半掩门。修正项 `deal_count` 把人物、事件、消息的随机部分减到 0（和查封同一个写法，§7.4.6）。照发的：日程与主线、金色牌、钉签、条子、生活牌、来赎的人、命运牌、夜牌、走一趟自己排的牌。
- 闲日不是查封：没有查封的后果，门旗不换白；画面上门板半上。
- **过到有事那天**（`run.fast_forward`）：只在“今天是闲日、手上没有要了断的牌”或者夜里、日结、早上时可用。它一步一步做和按“打烊 · 下一天”完全一样的事，遇到下面任何一种就停：
  1. 打烊要确认（`needs_confirm`）；
  2. 早上发到手上的牌里有要了断的、金色的、牢房、生活牌，或引擎要开面板（钱不够、留牌满、人脉满）；
  3. 到了开门日的早上；
  4. 周末盘账的面板要开；
  5. 到了月底结账，或局终；
  6. 最多过 7 天。
- 它是玩家自己按的，不是计时器（红线 9）。“打烊 · 下一天”照旧在、照旧一步一步走。

### 3.6 周末盘账（第 7、14、21、28 天的夜里，日结之后）

模块在 `settle` 钩子里（priority 75）算好下面三样，`request_panel("run_week", {week})`：

1. **这周的账**（只读）：做成几笔（当、收、卖成交的次数）、进出多少钱、条子办成没有、世道变没变、交了多少开销。
2. **下周门口来谁**：3 张客源（`c.run.draft [stage, week, k]`，不放回，按 `weight`，排除已有的；下周的周牌有 `draft_bias` 时，带这些标签的客源权重 ×2）。`run.pick {slot: "draft", id}` 挑一张，或 `id: ""` 都不要。手上最多 `draft.max_held`（4）拨客源；满了要先“谢掉”一拨（`run.pick {slot: "draft", id, drop}`）。
3. **这周的赏**：这周做成 ≥ 2 笔才有；≥ 4 笔，候选里能出稀有的；查铺周过了，多挑一样。候选 3 样（`c.run.reward [stage, week, k]`），从三类里混着抽：柜上物件（`rl.*`）、人情（留着的牌，`run.json.reward.favors`）、门路（人脉，`run.json.reward.contacts`）。`run.pick {slot: "reward", id}` 或 `id: ""`。
4. **下周的路**：见 3.4。第 28 天的盘账没有这一项，换成“月底关口”的预告。

**没选怎么办**：客源和赏没选，就是“过了这村没这店”（清单一行 `pass`，不用确认）；下周的路没选，替你选（一行 `auto_pick`，要确认）。

### 3.7 客源：你的“牌组”

- 客源（`ky.*`）不是手牌，是**门口常来的那拨人**。它做两件事：
  1. 调人物牌库：`pool_mods`（例：带 `buyer` 标签的 ×1.6）；
  2. 放进新人：一批只有挑了这拨客源才会来的人物牌，牌上写 `conditions: {"run_has": "ky.any.connoisseur"}`、`weight > 0`。没挑时条件不满足，这些牌根本不上牌库（本传也一样，所以本传的发牌一张不变）。
- 有的客源带坏处 `drawback`（例：“日商茧行的买办”让查铺事件 ×1.3、每次成交风声 +2）。
- 客源默认管到月底；三幕连走时，`era` 不含下一年的客源跨年作废，`*` 的留下。
- **谢客**：歇一歇里能“谢绝闲人”（柜上物件 `rl.rule.no_idlers`：来打听 `ask` 的人 ×0.5）。这是删牌。
- 第一版 8 拨（每拨带 2–3 张新人物牌，共约 20 张）：

| id | 门口来什么人 | 赚头 | 代价 |
|---|---|---|---|
| `ky.any.connoisseur` 行家 | 上海来的买主，只要书画首饰，预算 105–150%（真值） | 货架变现 | 压价狠了就走；查铺略多 |
| `ky.any.refugee` 逃难急当的 | 来当的人开口价 60–85%、底线 35–55% | 收得便宜 | 压价伤本心（`on_accept` 里写）；求助的人也多 |
| `ky.any.dock` 码头上的人 | 银元、杂货的当和卖；夜里后门多 | 银元好转手 | 风声 |
| `ky.any.regulars` 老主顾 | 来赎的人更多（`redeem` 的牌 ×1.5）；口碑涨得快 | 利息、口碑 | 生意小 |
| `ky.any.students` 学生与先生 | 书、字画、钢笔；打听消息的多 | 档案碎片 | 李敬之一线的风声 |
| `ky.1938.levy_runners` 维持会跑腿的 | 胡二的人常来“顺手”卖东西 | 条子能讲价（多一张 `kp.hu_owes` 的机会） | 本心、风声 |
| `ky.1939.year_clothes` 当衣过年的 | 衣物当得多、赎得也多 | 利息 | 货架占地方 |
| `ky.1940.jp_buyer` 日商茧行的买办 | 什么都收，预算最高 | 最赚 | 每笔成交风声 +2，本心 −2 |

### 3.8 柜上物件（`rl.*`，N03 的镇店之宝）

- 被动，挂在现有修正项上：`price_pct`（分 `direction`）、`patience_pct`、`appraise_pct`（可带 `cats`）、`cap`（货架、留牌）。不新增柜台规则。
- 第一版 12 件：N03 的 9 件（`rl.copper_scale` 铜戥子、`rl.iron_cashbox` 铁钱箱、`rl.old_abacus` 老算盘、`rl.door_curtain` 门帘、`rl.night_lamp` 夜灯、`rl.ticket_stub_box` 存根匣、`rl.tea_stove` 茶炉、`rl.sign_nail` 招牌钉、`rl.cloth_wrap` 包袱皮）+ 3 件“规矩”（`rl.rule.no_idlers` 谢绝闲人、`rl.rule.cash_only` 只收现钱、`rl.rule.lock_fixed` 修好门锁）。
- N03 里的 `fee_pct`（当票月息）和 `heat_delta`（月底风声）没有现成修正项：`heat_delta` 改成每周末执行一次 `heat`；`fee_pct` 第一版不做。
- 柜上物件会**画在柜台上**（道具，`prop.rl.*`），一眼看得见你这趟攒了什么。

### 3.9 世道（`run.press`，五档：松、平、紧、很紧、要命）

- 只显示五档文字（HUD），点数不显示。起步 = 处境给的（默认 0 = 松）+ 难度档。
- **怎么变**（全写在 `run.json.press`，整数键）：
  - 每周末：这周有条子办成、并且没有条子没办成 → 不动；否则 +1。
  - 条子没办成（G03 把条子按 `expired` 结掉时）：再 +1。
  - 查铺周过了、关口过了：−1（关口另见 3.10）。
  - 黑市周、新规矩周：+1。
- **管什么**：
  - 条子加码：周一发条子之前（`day_start` priority 25，G03 发条子是 30），执行 `{"op": "demand_tier", "delta": bias_<档>}`。只在 `demand_rules.issue_weekday` 那天、并且这一周的条子还没发时做（只读 `rules.demand.weeks` 判断，另在 `run.week.bias_done` 记一笔，不会一周加两次）。`demand_tier` 是累加的，G03 发完条子清零，所以和人脉马万利的 −1、处境的 −1 能叠。起步：松 0、平 0、紧 1、很紧 1、要命 2。条子档位 = 年代基础档 + 风声/40 + 这些加码，上限 3（要命档 = 被抓）。
  - 关口挑哪一档（3.10）。
  - 每周开销倍数（3.11）。
- 叙事：胡二看你办事痛不痛快。办得痛快，上面不来烦你；拖着不办，下回的条子就更狠。

### 3.10 月底关口（boss）

- 每月一道，第 29 天早上由模块排进手牌（`scheduled_cards`），是一张 `type: event`、带 `boss` 标签、`must_resolve: true` 的牌，有演出块（官员站门口）。
- 三档（`.t0` `.t1` `.t2`），按第 29 天时的世道挑：松/平 → t0，紧/很紧 → t1，要命 → t2。档越高，要的正面越多、过不去的后果越重。
- 两个选项：
  - **照办**：柜台上四个格子 + 掷铜钱。格子刻意要“攒出来的东西”：铺保（人脉按门路，或带 `official`/`favor` 的留着的牌）、证件（`papers`）、见面礼（**只收货架上的东西**，不收钱）、会说话的人（口才）。
  - **认罚**：交一大笔钱（1938 t0 起步 180，按物价换算），`short: "ladder"`，钱不够走破产阶梯。算过了关，但记为“花钱过的”。
- 没理会（打烊时还在手上）：按“照办没过”结算（`on_expire`）。
- 过了：`{"op": "run_boss", "result": "passed"}`、口碑上一档、世道 −1；三幕连走时下个月的处境候选多一张。
- 没过：拿走一件家当（`estate_seize worst`）、风声上一档、记 `failed`；t2 没过 = 被抓（`arrest`）。
- 三年的关口：

| 年 | 关口 | 要什么 | 史实依据 |
|---|---|---|---|
| 1938 三月底 | `ev.1938.boss.police_station` 伪警察所开门 · 登记铺保 | 铺保、证件、见面礼、会说话的人 | DESIGN §五：月底伪维新政府成立，警察所开门 |
| 1939 腊月底 | `ev.1939.boss.year_end` 年关 · 三路讨账 | 现货（米、炭、布）、赎当的钱、口才、人情 | DESIGN §五：年关赎当、米柴涨价 |
| 1940 三月底 | `ev.1940.boss.new_official` 新官上任 · 请你当保长 | 门路、孙府介绍信或人情、见面礼、胆量（推掉时） | DESIGN §九.7 官场开头（K17） |

1940 关口和 K17“请你当保长”是同一场戏：照办里多一个“应下”（不掷铜钱：过关，但风声、本心照 K17 的后果走）。

### 3.11 开销

- 每周末交一次开销：`upkeep.per_week`（起步 10）× 物价指数 /100 × 世道倍数（松平 100、紧 120、很紧 140、要命 160）/100。`pay`，`short: "ladder"`。
- 本传的月开销（G04 `month_expenses`）照旧在月底收。走一趟一个月的固定开销合计约 70（1938）。
- 叙事：灯油、伙食、门口的“孝敬”。

### 3.12 家底、结局与分

**家底**（只用看得见的数）：

| 项 | 怎么算 | 从哪里来 |
|---|---|---|
| 现钱 | 钱 | `view.money` |
| 货架 | 每件按“卖给人时的公道价”（`economy.json.tiers.receive.fair` × 看得见的估价 × `price_pct`） | G04 新加的公开函数 `CardShelf.book_value(ctx)` |
| 当出去的本钱 | 没赎、没满当的当票的当本 | `TicketView.principal` |
| 家当 | 没押、没丢的家当的押值 | `EstateView.money` |

- 押家当换来的钱进了现钱，家当这一项少同样的数：押家当本身不改家底，利息才改。这就修掉了报告里“最后一关押光家当、现金虚高”的问题。
- 货架上的假货按看得见的估价算：账面会骗人，这不泄露真假。
- **折合**：家底 × 100 / 物价指数，跨年可比。
- **开张家底**：第 1 天发牌前（处境生效后）记一次。

**结局档**（`run.json.endings`，按顺序取第一条满足的）：

| id | 名 | 条件 |
|---|---|---|
| `fallen` | 败落 | 局终（牢里没出来、或月底在街头） |
| `thrived` | 兴旺 | 关口照办过了；折合家底比开张 ≥ +150；主线目标完成 |
| `stood` | 站住 | 关口过了（照办或认罚）；折合家底 ≥ 开张 |
| `endured` | 熬过 | 其余 |

三幕连走另加 `old_name` 老字号：三道关口都照办过了，且最后折合家底比开张 ≥ +400。

**这一趟的分**（看得见，带明细）= 折合家底 − 开张家底 + 加分（`run.json.score.bonus`）：关口照办过了 120、认罚过的 0、主线目标 60、每个可选目标 30、每补齐一页档案 10、难度档 × 50。

**结局正文**：界面键 `run1.end.<档>.p1…pN`；同一档按本心分三种写法（本心只在引擎里选键，不显示）。

### 3.13 三幕连走：跨年带什么

- 带：钱、货架、当票（跨年照本传满当）、家当、人脉、留着的牌、柜上物件、本心口碑风声、档案。
- 不带：era 不含新年的客源；周图重新生成；世道 = max(0, 世道 − 2)，上一道关口没过则不减。
- 第二、三个月没有处境，改成“这一年带来的”：三张二选一的“年景”加成（例：多一拨客源、多一件物件、风声退一档），同一个 `run.pick {slot: "origin"}` 指令，数据类型仍是 `origin`，`era` 写下一年。

### 3.14 打烊永远能按：没选的东西怎么办

| 没选的 | 什么时候替你定 | 打烊清单的行 | 要确认吗 |
|---|---|---|---|
| 处境 | 第 1 天早上 `day_start` | `auto_pick`，`run1.end.auto_origin` | 要（在 `month_open` 阶段，和 `auto_spin` 同屏） |
| 第一周的路、第一拨客源 | 同上 | `auto_pick` / `pass` | 路要；客源不要 |
| 下周的路 | 下周第一天早上 | `auto_pick`，`run1.end.auto_week` | 要（在 `settle` 阶段） |
| 这周的客源、赏 | 同上 | `pass`，`run1.end.pass_offer` | 不要 |
| 关口牌 | 打烊时 | 照现有 `ignore`（`on_expire`） | 要 |

- 所有走一趟的面板都能关（“先合上”），关了回到牌桌，“打烊 · 下一天”照样按得到。
- 不卡死不变式（§7.4.7 第 4 条）对走一趟一样成立，模糊测试要覆盖（第 10 节）。

### 3.15 存档、重来、确定性

- 状态里只有整数、字符串；所有抽取走登记过的 `c.run.*` 域，键里只有 `stage`、`week`、`k`、`row`。
- 开月存档在 `month_open`：走一趟的 `run` 命名空间在 `stage_start` 就建好了，所以开月存档里就有周图和处境候选；“重来本关”回到同样的周图、同样的候选。
- 重走一趟（`game.retry_stage`）：照合同永远能用；这一趟记 `run.retried = true`，分数旁边写“重走过”。
- 种子照旧不显示（`seed` 是禁用键）。

### 3.16 红线逐条核对

| 红线 | 走一趟怎么守 |
|---|---|
| 1 免 AI 声明 | 新数据只有 `brief`；正文进 `text_ai/**`（带来源）和以后的人写层；新美术进清单走 `art/ai/**` |
| 2 确定性 | 只用 `ctx.draw` + 新登记的 `c.run.*` 域；`run.fast_forward` 等于一串 `day.end`，有哈希相等测试 |
| 3 隐藏数值 | 视图里只有：周牌 id、开门几天、客源和物件的 id、世道档、钱数、家底各项钱数、分数、关口的铜钱与正面；不给权重、倍数、世道点数、关口档的门槛 |
| 4 规矩在戏里讲 | 每个新机制一个 first-time 和指引步骤、一页规矩（第 6.8 节） |
| 5 鉴定不给结论 | 不碰小游戏；家底用看得见的估价 |
| 6 史实措辞 | 伪警察所、伪区公所、汪伪；不写血腥 |
| 7 测试红线 | 新测试照 `card_t` 写，日志干净 |
| 8 新机制有指引 | 见 6.8 |
| 9 打烊永远可用 | 3.14；`run.fast_forward` 只是可选的快捷，不替代、不挡住 `day.end` |

---

## 4. 数据格式与例子

新目录 `data/cards/run/`（主人 RUN2），新规则文件 `data/cards/rules/run.json`（主人 RUN1）。四种新类型，id 前缀：

| 类型 | 前缀 | 例 | 进不进牌库 |
|---|---|---|---|
| `week` 周牌 | `wk.` | `wk.any.market` | 不进；只由周图用 |
| `source` 客源 | `ky.` | `ky.any.connoisseur` | 不进；只由周末盘账发 |
| `relic` 柜上物件 | `rl.` | `rl.copper_scale` | 不进 |
| `origin` 处境 | `og.` | `og.brother_debt` | 不进 |

关口、歇一歇、查铺周、黑市周的牌都是普通的 `event`（`weight: 0`），客源带进来的新人是普通的 `person`。所有数字是整数；骨架里不写正文；除 `brief` 外没有中文。

### 4.1 `data/cards/rules/run.json`

所有以后要调的数都写成**标量整数键**（不写成数组），这样 `balance_overrides.json` 能只改数（报告里 G06_report_schema 的“numeric override only”）。

```json
{
  "_meta": {"owner": "RUN1", "schema": 1},
  "_doc": ["走一趟：周图、闲日、选客、赏、世道、开销、关口、家底与结局。DESIGN §九.8（待主创确认）。数字是起步值，待调。"],
  "weeks": 4, "week_days": 7, "boss_day": 29,
  "start_money": {"stage_0": 340, "stage_1": 540, "stage_2": 750},
  "map": {
    "nodes_min": 2, "nodes_max": 3, "edge_split_num": 1, "edge_split_den": 2,
    "cap_inspect": 1, "cap_rest": 2, "default": "top",
    "fixed": {"1938": {"row_0": "wk.1938.open"}, "1939": {"row_3": ""}, "1940": {}}
  },
  "draft": {"offers": 3, "max_held": 4, "bias_mult": 2},
  "reward": {
    "offers": 3, "earn_deals": 2, "rare_deals": 4, "elite_extra": 1,
    "favors": {"kp.hu_owes": 10, "kp.zhao_favor": 8, "kp.blank_ticket": 8, "kp.gold_bar": 3},
    "contacts": {"chen": 4, "wu": 4, "guanjia": 3, "zhang": 3},
    "rare_favors": {"kp.gold_bar": 1, "kp.sunfu_letter": 1}
  },
  "upkeep": {"per_week": 10, "press_mult_0": 100, "press_mult_1": 100, "press_mult_2": 120, "press_mult_3": 140, "press_mult_4": 160},
  "press": {"max": 4, "week_up": 1, "fail_up": 1, "elite_down": 1, "boss_down": 1, "carry_down": 2,
            "bias_0": 0, "bias_1": 0, "bias_2": 1, "bias_3": 1, "bias_4": 2,
            "boss_t1_from": 2, "boss_t2_from": 4},
  "idle": {"zero_person": 1, "zero_event": 1, "zero_news": 1},
  "fast_forward": {"max_days": 7},
  "bosses": {"1938": "ev.1938.boss.police_station", "1939": "ev.1939.boss.year_end", "1940": "ev.1940.boss.new_official"},
  "score": {"boss_passed": 120, "boss_bought": 0, "main_goal": 60, "optional_goal": 30, "dossier_page": 10, "level": 50},
  "endings": {"thrived_gain": 150, "stood_gain": 0, "old_name_gain": 400},
  "levels": {"lv1_upkeep_mult": 150, "lv2_boss_need": 1, "lv3_draft_offers": 2, "lv4_press_start": 1}
}
```

关口三档的 id 由 `bosses.<年>` 加 `.t0` `.t1` `.t2` 组成。

### 4.2 周牌 `wk.*`（`data/cards/run/weeks.json`）

```json
{
  "id": "wk.any.market", "type": "week", "era": ["*"], "weight": 10,
  "rows": [1, 2, 3],
  "busy": {"n": 4, "prefer": "market_day"},
  "deal_mods": [{"type": "person", "delta": 1, "when": "market_day"}],
  "pool_mods": [
    {"pool": "person", "tags_any": ["buyer"], "pct": 150},
    {"pool": "event", "tags_any": ["official"], "pct": 120}
  ],
  "cards": [{"card": "ev.any.market_haggle", "day": 2}],
  "draft_bias": ["buyer", "trade"],
  "reward": "common",
  "press": 0,
  "art": "icon.wk.market",
  "brief": "集日周：这周开门四天，集日优先开门，集日那天多来一位客；来买东西的多一些，官面上的事也多一点。第 2 天一定有赶集讨价的事。周末做成两笔以上能挑一样普通的赏。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

字段：

| 字段 | 说明 |
|---|---|
| `rows` | 能出现在第几周（0 起；1938 第 0 行固定） |
| `busy` | `{"days": [1,2,4,6]}` 写死第几天开门；或 `{"n": 4, "prefer": "market_day"}`：先挑这周的集日，再从前往后补满 n 天。不抽签 |
| `deal_mods` | 开门日的张数增减；`when: "market_day"` 只在集日 |
| `pool_mods` | 这一周的牌库倍数（`pct` 是乘数，100 不变），形状同 `weights.json.factors` |
| `cards` | 这一周第几天（1–7）固定发的牌；闲日也发 |
| `draft_bias` | 周末给客源时，带这些标签的权重 ×`draft.bias_mult` |
| `reward` | `common` / `rare` / `none` / `elite`（`elite`：这周的 `cards` 里带 `elite` 标签的牌过了才多挑一样、含稀有） |
| `press` | 走这一周世道变几档（周末结算） |

歇一歇的选择牌（普通事件）：

```json
{
  "id": "ev.any.run_rest", "type": "event", "era": ["*"], "weight": 0,
  "tags": ["run", "home", "omen_family"], "must_resolve": false,
  "choices": [
    {"id": "cool", "effects": [{"op": "heat", "tier": -1}], "brief": "关门躲几天：风声退一档"},
    {"id": "train", "effects": [{"op": "attr", "who": "ruhua", "attr": "eye", "delta": 1}], "brief": "跟着陈先生学看东西：眼力 +1（不过期）"},
    {"id": "no_idlers", "effects": [{"op": "run_grant", "id": "rl.rule.no_idlers"}], "brief": "门口挂牌谢绝闲人：以后来打听的人少一半"},
    {"id": "fix_lock", "conditions": {"run_has": "rl.broken_lock"}, "effects": [{"op": "run_grant", "id": "rl.rule.lock_fixed"}], "brief": "修好门锁：货架恢复"}
  ],
  "art": "illus.ev.any.run_rest",
  "brief": "歇一歇这周第一天：四选一（修门锁只在刚遭过贼时出现）。不选就过去了，没有别的后果。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

### 4.3 客源 `ky.*` 和它带来的人

```json
{
  "id": "ky.any.connoisseur", "type": "source", "era": ["*"], "weight": 8,
  "tags": ["buyer", "trade"], "rarity": "common",
  "pool_mods": [{"pool": "person", "tags_any": ["buyer"], "pct": 160}],
  "drawback": [{"pool": "event", "tags_any": ["search"], "pct": 115}],
  "adds": ["p.any.run_connoisseur.buy_art", "p.any.run_connoisseur.buy_jewelry"],
  "lasts": "month",
  "art": "illus.ky.connoisseur",
  "brief": "行家：上海来的买主常来，只要书画和首饰，出手比镇上人大方；来买的人整体多一些。坏处：查铺略多。管到月底。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

`adds` 只给校验器对账（V44：两边都要写到）；真正让人上牌库的是人物牌自己的条件：

```json
{
  "id": "p.any.run_connoisseur.buy_art", "type": "person", "person": "ex_connoisseur", "era": ["*"], "weight": 12,
  "tags": ["buyer", "outsider", "omen_wealth"],
  "intent": "buy", "want": {"cats": ["art", "jewelry"], "budget_pct": [105, 150]},
  "patience_min": [40, 90], "impatience": "leave",
  "conditions": {"run_has": "ky.any.connoisseur"},
  "art": "portrait.ex_connoisseur",
  "brief": "上海来的行家，只看书画和首饰，出价比镇上人大方；压价压狠了就走。只有挑了“行家”这拨客源才会来。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

（`ex_connoisseur` 登记在同文件的 `persons` 块里。）本传里 `run_has` 恒为假，这些牌不上牌库，发牌结果和现在一模一样。

逃难急当的那拨，赚头和本心写在牌上：

```json
{
  "id": "p.any.run_refugee.pawn_coat", "type": "person", "person": "ex_refugee", "era": ["*"], "weight": 10,
  "tags": ["poor", "refugee", "omen_road"], "intent": "pawn",
  "item": {"cat": "clothing"}, "asking": {"pct": [60, 85]}, "floor": {"pct": [35, 55]},
  "patience_min": [60, 120], "impatience": "raise",
  "conditions": {"run_has": "ky.any.refugee"},
  "effects": {"on_accept": [{"op": "if", "cond": {"flag": "run_last_tier_harsh"}, "then": [{"op": "conscience", "delta": -2}]}]},
  "art": "portrait.ex_refugee",
  "brief": "逃难来的人当一件棉袍，开口就低，压价也接。用压价收下，本心掉一点（看不见）。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

（`run_last_tier_harsh`：模块在 `card_resolved` 里按 `almanac` 带回的成交档设的旗标；如果 G04 能在 `extra` 里带上成交档，就不用这个旗标，第 5.6 节列为可选的小改动。）

### 4.4 柜上物件 `rl.*`

```json
{
  "id": "rl.copper_scale", "type": "relic", "era": ["*"], "weight": 12, "rarity": "common",
  "tags": ["counter"],
  "mods": [
    {"kind": "price_pct", "direction": "receive", "pct": 106},
    {"kind": "patience_pct", "pct": 95}
  ],
  "weekly": [],
  "prop": {"art": "prop.rl.copper_scale", "at": "counter_l"},
  "art": "illus.rl.copper_scale",
  "brief": "铜戥子（N03 的铜秤）：卖货时价硬一点；客人等你称的工夫略短。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

`mods[].kind` 只许 `price_pct`（带 `direction`，可带 `cats`）、`patience_pct`、`appraise_pct`（可带 `cats`）、`cap`（带 `zone`，`delta` 整数）、`pool_pct`（同 `pool_mods`）。`weekly` 是每周末执行的效果数组（N03 的 `heat_delta` 写成 `[{"op": "heat", "delta": -2}]`）。

N03 九件换算成这套写法（起步）：

| id | mods | weekly |
|---|---|---|
| `rl.copper_scale` | receive 106；patience 95 | — |
| `rl.iron_cashbox` | cap shelf +1 | heat +2 |
| `rl.old_abacus` | pay 97；patience 95 | — |
| `rl.door_curtain` | receive 96；patience 120 | — |
| `rl.night_lamp` | — | heat −2 |
| `rl.ticket_stub_box` | cap shelf +1；cap kept +1 | heat +1 |
| `rl.tea_stove` | receive 97；patience 130 | heat +1 |
| `rl.sign_nail` | receive 106；pay 97 | heat +2 |
| `rl.cloth_wrap` | receive 95；cap shelf +2 | — |

### 4.5 处境 `og.*`

```json
{
  "id": "og.brother_debt", "type": "origin", "era": ["1938"], "weight": 10,
  "effects": [
    {"op": "money", "delta": 150, "reason": "run1.reason.origin"},
    {"op": "add_card", "card": "lf.1938.run_debt_zhao", "to": "queue", "in_days": 19}
  ],
  "press": 0, "sources": [], "relics": [],
  "art": "illus.og.brother_debt",
  "brief": "哥哥走前借了赵老三的钱留给你周转：开局多 150；第 20 天赵老三上门要 200（生活牌，三天内还）。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

### 4.6 关口（`ev.<年>.boss.<名>.t<档>`）

```json
{
  "id": "ev.1938.boss.police_station.t1", "type": "event", "era": ["1938"], "weight": 0,
  "tags": ["boss", "official", "police", "omen_official"],
  "must_resolve": true,
  "choices": [
    {"id": "comply",
     "check": {"slots": [
         {"id": "guarantor", "accepts": ["contact", "kept"], "attr": "pull", "tags": ["official", "favor"], "required": true, "brief": "铺保：有门路的人，或一张官面、人情的留牌"},
         {"id": "papers", "accepts": ["kept"], "tags": ["papers"], "brief": "证件"},
         {"id": "gift", "accepts": ["item"], "max": 2, "brief": "见面礼：货架上像样的东西，最多两件"},
         {"id": "talker", "accepts": ["self", "contact"], "attr": "tongue", "brief": "会说话的人"}],
       "need": 4,
       "on_success": [{"op": "run_boss", "result": "passed"}, {"op": "rep", "tier": 1}, {"op": "run_press", "delta": -1}, {"op": "notice", "key": "run1.boss.passed"}],
       "on_fail": [{"op": "run_boss", "result": "failed"}, {"op": "estate_seize", "pick": "worst"}, {"op": "heat", "tier": 1}, {"op": "flag", "key": "police_knows_name"}]},
     "brief": "照办：登记铺保，放人、证件、礼、会说话的人，掷铜钱，要 4 个正面"},
    {"id": "buy_off",
     "effects": [{"op": "pay", "amount": 220, "payee": "levy", "reason": "run1.reason.boss_fine", "short": "ladder"}, {"op": "run_boss", "result": "bought"}],
     "brief": "认罚：交 220 了事（算过关，但不加口碑、不减世道）"}
  ],
  "effects": {"on_expire": [{"op": "run_boss", "result": "failed"}, {"op": "estate_seize", "pick": "worst"}, {"op": "heat", "tier": 1}]},
  "stage": {"set": "counter", "cast": [{"who": "ex_police_chief", "at": "door_l", "look": "stand", "brief": "伪警察所所长"}, {"who": "ex_police", "at": "door_r", "look": "stand", "brief": "跟班的巡警"}],
            "props": [{"art": "prop.register_book", "at": "counter_c", "brief": "铺保登记簿"}],
            "intro": [{"who": "ex_police_chief", "ref": "ev.1938.boss.police_station.t1#body", "brief": "所长交代来意"}], "brief": "所长和巡警站在门口"},
  "art": "illus.ev.1938.boss.police_station",
  "brief": "月底关口（世道紧/很紧时这一档）：伪警察所开门，各铺要登记铺保。照办：四个格子要 4 个正面；认罚：交 220（按物价换算的是 t0 的 180 加码）。没过或没理会：拿走一件家当、风声上一档、警察记下名字。",
  "_provenance": {"by": "ai", "task": "RUN2", "date": "2026-10-25"}
}
```

关口的 `need` 起步：t0 = 3、t1 = 4、t2 = 5（t2 没过 = `arrest`）。认罚的钱 t0/t1/t2 = 180/220/300（1938），其它年按物价指数写在各自的牌上。

### 4.7 状态 `run` 命名空间（只有 RUN1 写）

```json
"run": {
  "_v": 1, "level": 0, "first_stage": 0, "last_stage": 0, "retried": false,
  "origin": {"offers": ["og.brother_debt", "og.old_name", "og.robbed"], "pick": "og.brother_debt"},
  "map": {"stage": 0,
          "rows": [[{"n": "r0c0", "node": "wk.1938.open"}],
                   [{"n": "r1c0", "node": "wk.any.market"}, {"n": "r1c1", "node": "wk.any.curfew"}, {"n": "r1c2", "node": "wk.any.rest"}],
                   [{"n": "r2c0", "node": "wk.any.temple_fair"}, {"n": "r2c1", "node": "wk.any.plain"}],
                   [{"n": "r3c0", "node": "wk.any.inspect"}, {"n": "r3c1", "node": "wk.any.rest"}, {"n": "r3c2", "node": "wk.any.market"}]],
          "edges": [["r0c0", "r1c0"], ["r0c0", "r1c1"], ["r0c0", "r1c2"], ["r1c0", "r2c0"], ["r1c1", "r2c0"], ["r1c1", "r2c1"], ["r1c2", "r2c1"], ["r2c0", "r3c0"], ["r2c0", "r3c1"], ["r2c1", "r3c1"], ["r2c1", "r3c2"]],
          "path": ["r0c0", "r1c0"], "next": ""},
  "week": {"index": 1, "node": "wk.any.market", "first_abs_day": 8, "busy": [8, 9, 11, 13],
           "deals": 2, "money_start": 381, "demand_done": 0, "demand_failed": 0, "elite": ""},
  "offers": {"week": -1, "draft": [], "reward": []},
  "sources": [{"id": "ky.any.connoisseur", "since_abs_day": 1}],
  "relics": [{"id": "rl.copper_scale", "since_abs_day": 8}],
  "press": 1,
  "boss": {"def": "", "result": ""},
  "score": {"start": 1500, "start_index": 100, "end": 0, "ending": ""},
  "log": [{"week": 0, "node": "wk.1938.open", "deals": 3, "draft": "ky.any.connoisseur", "reward": "rl.copper_scale", "press": 1}]
}
```

本传的局里**没有** `run` 这个键（模块读的时候用 `ctx.state.data.get("run", {})`，绝不调 `ns("run")`），所以本传的状态哈希只因为 `db_hash` 变。

### 4.8 视图 `view.run`（RUN1 经 `view_section` 交；本传不交这个键）

```json
"run": {
  "level": 0, "week": 1, "node": "wk.any.market", "today": "busy", "open_days_left": 2,
  "press_tier": 1, "pending": "",
  "sources": ["ky.any.connoisseur"], "relics": ["rl.copper_scale"],
  "map": {"rows": [[{"n": "r0c0", "node": "wk.1938.open", "open_days": 5}], "..."],
          "edges": [["r0c0", "r1c0"], "..."], "path": ["r0c0", "r1c0"], "reachable": [], "boss": "ev.1938.boss.police_station"},
  "offers": {"origin": [], "draft": [], "reward": []},
  "week_ledger": {"deals": 2, "money_in": 120, "money_out": 85, "upkeep": 0, "demand": "open"},
  "networth": {"cash": 381, "shelf": 96, "tickets": 60, "estates": 1010, "total": 1547, "start": 1500},
  "result": {}
}
```

- 键全部过 `CardViewModel.FORBIDDEN_KEYS`（没有 `weight` `pct` `tags` `value` `seed` `rep` `heat`）。
- `result` 在局终才有：`{"ending": "stood", "gain": 121, "score": 331, "lines": [{"key": "run1.score.boss_passed", "args": {"money": 120}}, …], "retried": false}`。

### 4.9 正文键

- 新类型的必填正文（加进合同 §4.5 的表）：`week` → `title` `body`；`source` → `title` `body`；`relic` → `title` `body`；`origin` → `title` `body`。
- 界面键：`run1.*`（引擎的原因、告示、打烊清单行、结局段落）、`run3.*`（界面标签、按钮）、`run4.*` 不用（指引步骤用 `gd.run.*`、规矩页用 `rule.run.*`）。
- AI 基础层照 W2 #212 写进 `data/cards/text_ai/run/*.text.json`，`_meta._provenance` 登记；人写层以后覆盖。

---

## 5. 引擎改动

### 5.1 合同与常量（Claude；`[api]`）

| 文件 | 改什么 |
|---|---|
| `scripts/cards/api/card_ids.gd` | `TYPES` 加 `week` `source` `relic` `origin`；id 前缀表加 `wk.` `ky.` `rl.` `og.`；`COMMANDS` 加 `run.pick` `run.fast_forward`；查询加 `run`；`END_KINDS` 加 `auto_pick`；`PANELS` / `PANEL_SCENES` / `PANEL_SHOW` 加 `run_origin` `run_map` `run_week` `run_end`（都是 `overlay`）；`FIRSTS` 加 `run_origin` `run_map` `run_idle` `run_fast` `run_week_end` `run_draft` `run_reward` `run_press` `run_boss` `run_end`；`ANCHORS` 加 `a.run.origin` `a.run.map` `a.run.map.reachable` `a.run.week.ledger` `a.run.week.draft` `a.run.week.reward` `a.run.week.next` `a.top.run` `a.btn.fast_forward` `a.run.end` `a.drawer.sources` `a.drawer.relics`；`UI_EVENTS` 加 `run_map_opened` `run_offer_viewed`；`RNG_DOMAINS` 加 `c.run.map` `c.run.edge` `c.run.origin` `c.run.draft` `c.run.reward`（主人 RUN1） |
| `scripts/cards/api/dsl_shapes.gd` | 效果 op `run_press {delta}` `run_grant {id}` `run_boss {result: passed/bought/failed}`；条件 op `run_mode true/false` `run_has <id>` `run_week <wk id>` `run_press_gte <n>`；新类型字段的形状函数 `check_week` `check_source` `check_relic` `check_origin` |
| `docs/cards/CARDS_INTERFACES.md` | 新章 §15“走一趟”：本稿第 3–5 节的规则、状态、视图、指令；§4.5 必填正文表；§6.3 随机域；§7.3 修正项提供者表补 RUN1；§7.4.7 第 2 条“非白天阶段的清单还收 `auto_pick` 行” |
| `docs/cards/ownership.json` | `scripts/cards/run/**` → RUN1；`data/cards/run/**` → RUN2；`data/cards/rules/run.json` → RUN1；`scenes/cards/run/**`、`scripts/cards/ui/run/**` → RUN3；`data/cards/guide/run_*.json` → RUN4；新策略文件 → RUN5 |

### 5.2 G01（小改）

| 文件 · 函数 | 改什么 |
|---|---|
| `core/card_db.gd` `CARD_DIRS` | 加 `"run"` |
| `core/card_state.gd` `create()` | `opts.mode == "run"` 时在顶层写 `"mode": "run"`、`"level": n`；本传不写这两个键（哈希不变） |
| `core/card_validator.gd`、`validation_extra.gd` | V03 认新类型；V16 的“被引用”加上：`run.json.bosses` 派生的三档、周牌 `cards`、处境 `effects` 里的 `add_card`、`run_grant` 的 id；新规则 V43（周牌：`rows` 在 0–3、`busy.days` 在 1–7、`busy.n` 1–7、`cards[].day` 1–7、引用的牌存在且 `weight: 0` 或带 `run` 标签）、V44（客源：`adds` 里每张人物牌的 `conditions` 含 `run_has` 指回这张客源，反之亦然）、V45（物件：`mods[].kind` 只许 5 种）、V46（处境：`era` 合法、效果合法）、V47（关口：三档齐、`must_resolve`、有 `on_expire`、每档 `need` 递增） |
| `data/cards/_schema/` | `week.json` `source.json` `relic.json` `origin.json` |

### 5.3 G02（小改）

| 文件 · 函数 | 改什么 |
|---|---|
| `loop/loop_install.gd` `_cmd_new` | 收 `mode`（`"story"` / `"run"`，默认 `"story"`）、`stages`（≥ 1）、`level`（≥ 0）；`mode == "run"` 时传给 `CardState.create`，并在 `loop` 里写 `last_stage = stage + stages − 1`（本传不写） |
| `loop/day_loop.gd` `close_month` | 下一关不存在**或** `stage ≥ loop.last_stage`（有这个键时）→ `finish_game(ctx, "ending")` |
| `loop/end_day_rules.gd` `preview` | 非白天阶段除了 `short` 行，也收 `kind == "auto_pick"` 的行 |

本传里这三处的行为都不变（没有 `mode`、没有 `last_stage`、没有 `auto_pick` 行）。

### 5.4 新模块 `scripts/cards/run/`（RUN1）

照收徒的先例：没有 `class_name`，`preload`；`CardEngine._init` 在 `_ApprenticeInstall.install` 之后加一行 `_RunInstall.install(self, ctx)`（这一行归 W0/Claude 的冻结顺序，走 `[api]`）。

| 文件 | 内容 |
|---|---|
| `run_install.gd` | `install(engine, ctx)`：登记下表的指令、查询、op、条件、修正项、钩子 |
| `run_ids.gd` | 本模块常量：指令名、面板名、`slot` 取值、正文键前缀 |
| `run_state.gd` | `active(ctx) -> bool`（`state.data.get("mode") == "run"`）、`peek(ctx) -> Dictionary`（只读，不建键）、`ns(ctx)`（只在 active 时建）、`view_section(ctx, args)` |
| `run_map.gd` | `generate(ctx, stage) -> Dictionary`、`reachable(ctx) -> Array`、`pick(ctx, n) -> String`、`default_pick(ctx) -> String` |
| `run_week.gd` | `plan(ctx, node_id, first_abs_day) -> Array`（开门日）、`is_idle(ctx, abs_day) -> bool`、`deal_count(ctx, args) -> int`、`scheduled(ctx, args) -> Array`、`begin_week(ctx)`、`count(ctx, args)`（`card_resolved`）、`week_end(ctx, args)`（`settle`） |
| `run_build.gd` | `pool_pct` `price_pct` `patience_pct` `appraise_pct` `cap` 五个修正项；`grant(ctx, id)`；`apply_origin(ctx)`；`year_jump(ctx, args)` |
| `run_offers.gd` | `roll_origin(ctx)`、`roll_week_end(ctx)`（客源、赏）、`pick(ctx, args)`、`auto_pick_due(ctx, args)`（`day_start` priority 1）、`end_rows(ctx, args)` |
| `run_press.gd` | `tier(ctx)`、`add(ctx, delta, why)`、`before_demand(ctx, args)`（`day_start` priority 25） |
| `run_boss.gd` | `variant(ctx, abs_day) -> String`、`record(ctx, result)` |
| `run_score.gd` | `networth(ctx) -> Dictionary`、`close(ctx, args)`（`month_close` priority 30：算家底、结局档、分；末月写 `run.score`） |
| `run_ff.gd` | `fast_forward(ctx, args) -> Dictionary` |

**登记表**：

| 种类 | 名 | 说明 |
|---|---|---|
| 指令 | `run.pick {slot, id, drop?}` | `slot` ∈ `origin` `week` `draft` `reward`；阶段：`origin`、第一周的 `week`/`draft` 在 `month_open`，其余在 `settle`（周末）；错误码沿用 `bad_phase` `bad_args` `not_allowed` `already_resolved` |
| 指令 | `run.fast_forward {}` | 见 5.5；返回 `{ok, err, days: [{abs_day, lines}], stopped}` |
| 查询 | `run {}` | 同 `view.run`，外加当前候选的 CardView 摘要（`def`、`art`） |
| 效果 op | `run_press` `run_grant` `run_boss` | 见 5.1 |
| 条件 op | `run_mode` `run_has` `run_week` `run_press_gte` | 本传里 `run_mode` 为假，其余也为假 |
| 修正项 | `pool_pct` `deal_count` `scheduled_cards` `price_pct` `patience_pct` `appraise_pct` `cap` `end_rows` `view_section` | 本传里分别返回 100、0、`[]`、100、100、100、0、`[]`、`{}` |
| 钩子 | `stage_start` 45 | 建 `run`（首月）、抽处境候选、生成周图；跨年时周图重生成 |
| 钩子 | `day_start` 1 | 到期没选的替你选；第 1 天应用处境、记开张家底；周首日 `begin_week` |
| 钩子 | `day_start` 25 | 周一发条子前按世道加码（G03 是 30） |
| 钩子 | `card_resolved` 30 | 记成交（`almanac` 含 `trade`）、记条子办成/没办成（`type == demand`，`outcome` 为 `resolved` / `expired`） |
| 钩子 | `settle` 75 | 周末：开销、物件的 `weekly`、世道、候选、`request_panel("run_week")` |
| 钩子 | `month_close` 30 | 家底、结局、分（G02 目标结算在 20 之后） |
| 钩子 | `year_jump` 60 | 客源跨年、世道回落 |

### 5.5 关键算法

**周图生成**（`run_map.generate`，纯函数，只依赖种子、`stage` 和数据）：

```text
for r in 0..weeks-1:
  if fixed[era]["row_r"] 有值: row = [它]
  else:
    n = nodes_min + floor(draw("c.run.map", [stage, r, "n"]) * (nodes_max - nodes_min + 1))
    cands = 周牌里 era 合、rows 含 r、未超本月上限的，按 id 排序
    取 n 个：weighted_choice(cands, draw("c.run.map", [stage, r, k]))，不放回；
             这一行全是 rest 时把最后一个换成 plain
    行内按 run.json 的显示顺序排（plain, market, temple_fair, curfew, inspect, black, rest）
edges（r → r+1，a = 本行个数，b = 下一行个数）：
  第 i 个连 j0 = floor(i * b / a)；若 j0 + 1 < b 且 draw("c.run.edge", [stage, r, i]) < num/den，再连 j0 + 1
  下一行没人连到的 j，补一条从 floor(j * a / b) 来的
（单调连线不交叉；第 0 行之前有个虚拟起点，全连）
```

**开门日**（`run_week.plan`）：`busy.days` 直接换成 abs_day；`busy.n`：先取这周里 `CardCalendar.is_market_day` 为真的天（`prefer: "market_day"`），再从前往后补满。不抽签。

**闲日的修正项**（`run_week.deal_count`）：`type ∈ {person, event, news}` 且 `is_idle(abs_day)` → 返回 −99（发牌那边加完按 0 截断，§7.3）；开门日按周牌 `deal_mods`。`abs_day` 用参数里的（`project()` 预测未来日时也对）。

**排进来的牌**（`run_week.scheduled`）：本周周牌的 `cards`（按 `first_abs_day + day − 1` 对日子）；`boss_day` 那天返回 `run_boss.variant()`（按那天的世道选档）；处境排的牌走 `queue`，不在这里。纯函数，`project()` 调它不改状态；同一天只会被 `compose` 发一次。

**过到有事那天**（`run_ff.fast_forward`）：

```text
前提：active；阶段 ∈ {day(闲日且手上没有要了断的牌), night, settle, morning}，否则 err "not_idle"
steps = 0; days = []
loop:
  if steps >= 8 * fast_forward.max_days: stopped = "max"; break
  phase = loop.phase
  if phase == "month_close" or "game_over": stopped = phase; break
  if phase == "settle" and open_panel.kind == "run_week": stopped = "week_end"; break
  if phase == "morning" and not is_idle(下一天的 abs_day): stopped = "busy_day"; break
  r = CardDayLoop.end_day(ctx, false)          # 和按一次“打烊 · 下一天”完全一样
  if r.err == "must_resolve_pending": stopped = "confirm"; break
  steps += 1
  if phase == "settle": days.append({abs_day, lines: 日结报告的行})
  if phase == "morning"（刚发完牌）and（手上有 must_resolve / gold / prison / 新的 life 牌，或 open_panel 不空）:
     stopped = "cards"; break
return {ok: true, days, stopped}
```

测试保证：同一状态下 `run.fast_forward` 的结果状态哈希，和逐条发 `day.end {confirm: false}` 直到同样的停点完全一样。

**家底**（`run_score.networth`）：现钱用 `CardCurrency.money(ctx)`；货架用 G04 新加的 `CardShelf.book_value(ctx) -> int`；当本用 `CardTickets.view(ctx)` 里 `status ∈ {active, overdue}` 且 `foreign == false` 的 `principal`；家当用 G06 的家当视图里 `status == "held"` 的 `money`。全是视图里本来就看得见的数。

### 5.6 其他模块（只加公开函数，不改规则）

| 主人 | 加什么 |
|---|---|
| G04 | `CardShelf.book_value(ctx) -> int`（每件货架物品按 `tiers.receive.fair` 和 `price_pct` 算出的卖价之和，只用看得见的估价）。可选：`_deal` 在 `E.end` 的 `actions` 里带上成交档（`"tier:harsh"`），客源牌就不用旗标 |
| G06 | 无（家当视图已公开）；模拟见 RUN5 |
| G03 / G05 | 无 |

### 5.7 Mock 与夹具（Claude）

`scripts/cards/mock/mock_engine.gd` 认 `run.pick`、`run.fast_forward`、查询 `run`；新夹具 `run_origin`、`run_map`、`run_week_end`、`run_idle_day`、`run_boss`、`run_end`（`scripts/cards/mock/fixtures/`），让 RUN3 不等 RUN1。

---

## 6. 界面（1280×720，照网页原型的样子）

整体风格照原型：深木色底、米黄纸面（`paper`）、墨色字（`ink`）、朱印（`seal`）、金框（`gold`）。所有字来自 `CardText`；颜色只用配色键（新键 `run_map_line` `run_map_node` `run_map_done` `run_press_1`…`run_press_5`，开发版写进 `palette.dev.json`，正式由 A 写）。叠层面板照 `OVERLAY_MAX` 1100×640，居中在 (90, 40)。

### 6.1 标题上的“走一趟”（C16 的标题，RUN3 加一块）

```text
┌──────────────────────────── 1280×720 标题（压暗）────────────────────────────┐
│                                德厚当                                         │
│                          [ 开张 ]（本传）                                     │
│                          [ 走一趟 ]  ← 新                                     │
│                          [ 接着玩 ] [ 设置 ] [ 退出 ]                          │
│   ┌──── 走一趟（叠层 720×420，居中）───────────────────────────┐           │
│   │  走哪一年： [民国廿七年三月] [廿八年腊月（锁）] [廿九年三月（锁）] │           │
│   │  难度：    [一] [二（锁）] …     三幕连走：[ ] （锁）             │           │
│   │                                   [ 开张 ]  [ 算了 ]              │           │
│   └────────────────────────────────────────────────────────────┘           │
```

开张 = `new_game({seed, mode: "run", stage, stages, level})`。种子照标题现在的做法给，界面上不显示。

### 6.2 开月：处境（`run_origin`，C09 的开月流程里插一页）

```text
┌ 叠层 1100×640 ──────────────────────────────────────────────────────────────┐
│ 民国廿七年三月 · 你是怎么接下这间铺子的                         [先合上 Esc]  │
│                                                                              │
│    ┌──────────┐        ┌──────────┐        ┌──────────┐                     │
│    │ 处境牌     │        │ 处境牌     │        │ 处境牌     │  每张 288×400     │
│    │ 64×48 插图 │        │           │        │           │  x = 150 / 496 / 842│
│    │ ×4        │        │           │        │           │  y = 120            │
│    │ 名        │        │           │        │           │                     │
│    │ 正文两三行 │        │           │        │           │                     │
│    └──────────┘        └──────────┘        └──────────┘                     │
│                                                                              │
│                    [ 就这样开张 ]（选中一张后才亮）                            │
└──────────────────────────────────────────────────────────────────────────────┘
```

顺序：开月过场三页 → 处境 → 本月运势轮盘（原样）→ 本月的路（选第一周、第一拨客源）。1938 的第一周固定，这一页只看图、挑客源。

### 6.3 本月的路（`run_map`）

```text
┌ 叠层 1100×640，月份牌纸面 ─────────────────────────────────────────────────┐
│ 民国廿七年三月 · 本月的路                     世道：平          [合上 Esc]   │
│   第一周         第二周          第三周          第四周          月底         │
│   初一–初七      初八–十四       十五–廿一       廿二–廿八       廿九–三十     │
│                  ┌───┐          ┌───┐          ┌───┐                        │
│   ┌───┐ ──────── │集 │ ──────── │庙 │ ──────── │查 │ ──┐    ┌─────────┐    │
│   │开 │ ╲        └───┘ ╲        └───┘ ╲      ╱ └───┘   ╲   │  关口    │    │
│   │张 │  ╲       ┌───┐  ╲       ┌───┐  ╲    ╱  ┌───┐     ─  │ 伪警察所 │    │
│   └───┘   ─────  │禁 │ ──────── │平 │ ──────── │歇 │ ────── │  开门    │    │
│   （朱印）       └───┘          └───┘          └───┘   ╱   │ 144×200  │    │
│                  ┌───┐                         ┌───┐ ─     └─────────┘    │
│                  │歇 │ ──────────────────────  │集 │                        │
│                  └───┘                         └───┘                        │
│ ─────────────────────────────────────────────────────────────────────────── │
│ 集日周 · 开门四天（初八、初九、十一、十三）                   ┌ 放大的周牌 ┐ │
│ 集日那天多一位客；来买东西的多一些，官面上的事也多一点。      │ 288×400    │ │
│ 走完：生意做成两笔以上，能挑一样赏。                          │ 在右下     │ │
│                                    [ 就走这条 ]  [ 再想想 ]   └────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

- 节点是 72×100 的小牌（周牌插图 + 一个字的图标），列 x = 150、360、570、780，关口在 x = 960（144×200）；行 y = 130、250、370。
- 走过的节点盖朱印、连线变实；能走的节点发光（锚点 `a.run.map.reachable`）；走不到的压暗。
- 点关口：放大看它的格子（“要：铺保、证件、见面礼、会说话的人”），不显示档位门槛。
- HUD 上的“本周”（6.5）点一下也能打开这张图。

### 6.4 周末盘账（`run_week`，第 7、14、21、28 天夜里，日结面板之后）

```text
┌ 叠层 1100×640 ─ 第一周过完了 · 三月初七 夜 ─────────────────────────────────┐
│ ┌ 这周的账（340）──┐ ┌ 下周门口来谁（400）───────┐ ┌ 这周的赏（300）──┐ │
│ │ 做成 3 笔生意       │ │ ┌────┐ ┌────┐ ┌────┐  │ │ ┌──┐ ┌──┐ ┌──┐  │ │
│ │ 进 182 · 出 141     │ │ │客源│ │客源│ │客源│  │ │ │物│ │情│ │门│  │ │
│ │ 交开销 10           │ │ │144 │ │×200│ │    │  │ │ │件│ │  │ │路│  │ │
│ │ 条子：办成了        │ │ └────┘ └────┘ └────┘  │ │ └──┘ └──┘ └──┘  │ │
│ │ 世道：平（没变）    │ │ 门口已有：行家（1/4）  │ │ 72×100，悬停放大 │ │
│ │                     │ │ [ 都不要，门口照旧 ]   │ │ [ 这回不要了 ]   │ │
│ └─────────────────────┘ └────────────────────────┘ └──────────────────┘ │
│              [ 看看下周的路 → ]（打开 6.3）       [ 先合上 ]              │
└──────────────────────────────────────────────────────────────────────────────┘
```

- 没赏的那周，右栏只有一句（哥哥的账簿批注或胡二的话）：“这周没做成几笔生意，没人往柜上送东西。”
- 第 28 天的盘账没有“下周的路”，换成关口的预告。
- 锚点：`a.run.week.ledger` `a.run.week.draft` `a.run.week.reward` `a.run.week.next`。

### 6.5 柜台画面上的变化

| 地方 | 变化 | 主人 |
|---|---|---|
| HUD_STATUS（684, 3, 200, 24） | 走一趟时写“二周 · 集日 · 开门”或“二周 · 闲日”，后面一个世道字（“紧”），颜色 `run_press_n`；锚点 `a.top.run`；点它开本月的路 | C01（RUN3 交文字） |
| 左标签第五个（0, 436, 44, 78） | “客源”抽屉：已有的客源小牌、管到哪天 | RUN3 |
| 右标签第五个（1236, 436, 44, 78） | “柜上”抽屉：柜上物件 | RUN3 |
| 柜台上 | 柜上物件画成道具（最多 4 件，道具位 `counter_l` `counter_r` `shelf_top` `wall_hook`） | C01 场景层，读 `view.run.relics` |
| 门口 | 闲日门板半上（场景层效果 `fx: half_shutter`，新配色和底图） | C01 |
| “打烊 · 下一天”上方（1020, 470, 210, 72） | 闲日、夜里、日结时多一个“过到有事那天”（`a.btn.fast_forward`），发 `run.fast_forward`；打烊按钮本身不变 | C01 |
| 对话框 | 快过之后，把 `days[].lines` 一天一段说出来（“初九：赎当一位……”），能跳过 | C04 |

### 6.6 月底关口

用现有的演出（§7.11.4）和柜台格子（C03）：两个官员站门口（`door_l` `door_r`），登记簿摆柜台上，四个格子出在柜台上，铜钱在柜台上翻。牌框用新的“关”字框 `frame.boss`（不是金色牌，金色只给人物）。回话是“照办”“认罚 · 220”“请他先等等”。

### 6.7 这一趟走完（`run_end`，局终叠层；C09 的局终在走一趟里换成它）

```text
┌ 叠层 1100×640 ─ 这一趟走完了 · 民国廿七年三月 ──────────────────────────────┐
│ ┌ 结局图 320×180 ×2 = 640×360 ─┐  ┌ 家底 ──────────────────────────┐      │
│ │                                │  │ 现钱                    286     │      │
│ │                                │  │ 货架（按公道价）        180     │      │
│ │                                │  │ 当出去的本钱             75     │      │
│ │                                │  │ 没押的家当              930     │      │
│ └────────────────────────────────┘  │ 合计 1471 （开张时 1350）       │      │
│ 站住了。                             │ 月底关口：照办过了       +120   │      │
│ （结局正文两三段，街坊怎么说你）      │ 主线目标              +60       │      │
│                                      │ 可选目标 1 个         +30       │      │
│                                      │ 这一趟的分             331      │      │
│                                      └────────────────────────────────┘      │
│ 下回能走：民国廿八年腊月                    [ 再走一趟 ]   [ 回标题 ]       │
└──────────────────────────────────────────────────────────────────────────────┘
```

- 败落时左边换牢房或街头的图，家底照算。
- “再走一趟”= 新种子、同样的年份和难度；“重走这一趟”只在败落时出现（= `game.retry_stage`，分数旁写“重走过”）。

### 6.8 新手指引与规矩页（RUN4，红线 4、8）

| first-time | 什么时候 | 谁教 | 锚点 | 规矩页 |
|---|---|---|---|---|
| `run_origin` | 开月第一次看处境 | 1938：哥哥；别的年：`obj.brother_ledger` | `a.run.origin` | `rule.run.origin` |
| `run_map` | 第一次打开本月的路 | `obj.brother_ledger`（哥哥留下的月份牌） | `a.run.map.reachable` | `rule.run.map` |
| `run_idle` | 第一个闲日早上 | `obj.notice`（门上的告示：今日半掩门） | `a.top.run` | `rule.run.idle` |
| `run_fast` | 第一次出现“过到有事那天” | `obj.notice` | `a.btn.fast_forward` | 同上 |
| `run_week_end` | 第一次周末盘账 | `obj.brother_ledger` | `a.run.week.ledger` | `rule.run.week` |
| `run_draft` | 第一次挑客源 | 周妈（1938 第 7 天她刚成人脉）；别的年 `obj.brother_ledger` | `a.run.week.draft` | `rule.run.sources` |
| `run_reward` | 第一次有赏 | `obj.brother_ledger` | `a.run.week.reward` | `rule.run.relics` |
| `run_press` | 世道第一次变紧 | 胡二 | `a.top.run` | `rule.run.press` |
| `run_boss` | 关口牌第一次发到手上 | `obj.notice`（警察所的布告） | `a.card@{uid}` | `rule.run.boss` |
| `run_end` | 第一次走完一趟 | `obj.brother_ledger` | `a.run.end` | `rule.run.networth` |

步骤 `gd.run.*` 的 `say`/`bubble` 先写 AI 基础层，A 以后覆盖。

### 6.9 美术清单（K12 登记）

图标 `icon.wk.*` 9、插图 `illus.ky.*` 8、`illus.rl.*` 12、道具 `prop.rl.*` 12、`illus.og.*` 6（1938）、关口插图 3、群演立绘 `portrait.ex_connoisseur` `ex_refugee` `ex_police_chief` 等约 6、结局图 `bg.run_end.*` 4、牌框 `frame.week` `frame.boss`、月份牌底纸 1、门板半上效果 1。第一版照现有的 `tools/cards/art/gen_ai_*.py` 出程序像素画。

---

## 7. 平衡：怎么让“全拒”不再最好，怎么用模拟查

### 7.1 走一趟里各策略会怎样（预期，要用模拟证实）

| 策略 | 走一趟会碰到什么 | 预期结局 |
|---|---|---|
| refuser（只按打烊） | 第一周条子没办 → 世道 +2；第二周条子升到中档（查封三天，不疼）→ 再 +2；第三周起大档“拿走家当”、风声 ≥ 40 后要命档“抓人”；关口没理会 → 再丢一件家当；没成交，没有赏 | 败落或熬过；家底 −300 上下 |
| payer（不做生意，但条子、关口、生活牌都用钱了结） | 世道不涨；条子 4 张约 150；开销约 70；关口照办过不去（见面礼只收货，铺保要人脉或人情，它都没有），只能认罚 180–220 | 熬过；偶尔站住；家底 −350 上下 |
| trader（公道价做生意，修好报告里说的策略毛病） | 有赏、有人情，关口照办能过；买卖靠客源有了买主 | 站住为主 |
| drafter（trader + 会挑周、客源、赏） | 买主多、物件加价，关口稳过 | 站住到兴旺 |

### 7.2 每条杠杆打在谁身上

| 杠杆 | 打在 refuser | 打在 payer | 打在做生意的人 | 在哪里调 |
|---|---|---|---|---|
| 世道（没办成就加码） | 重 | 无 | 轻（偶尔失手） | `run.json.press.*` |
| 关口要货、要人情、要人脉 | 重 | 重（只能认罚） | 轻 | 关口牌的格子与 `need` |
| 赏要成交两笔 | 拿不到 | 拿不到 | 拿得到 | `reward.earn_deals` |
| 每周开销 | 中 | 中 | 中（但有进账） | `upkeep.per_week` |
| 客源带来买主、便宜货 | 无用 | 无用 | 有用 | 客源 `pool_mods`、新人物牌的 `budget_pct` `asking` `floor` |
| 结局按家底 | 低 | 低 | 高 | `endings.*` |

### 7.3 模拟要加的东西（RUN5）

| 文件 | 加什么 |
|---|---|
| `scripts/cards/sim/balance_main.gd` | 参数 `--mode=run` `--stage=N` `--stages=K` `--level=L`，传进 `game_opts`；输出带 `mode` |
| `scripts/cards/sim/policy.gd` | `_candidates` 认三个新面板：`run_origin`、`run_week`（挑客源、赏、下周的路）、闲日的 `run.fast_forward`；默认挑法（第一个）给 trader、payer；挑法钩子 `_run_choice(kind, offers)` 给 drafter 覆盖 |
| `scripts/cards/sim/policies/payer.gd` | 柜台一律 `counter.refuse`；条子选 `pay` / `substitute`；关口先试照办，放得下就放，否则认罚；生活牌付钱 |
| `scripts/cards/sim/policies/trader.gd` | fair，加上报告里的三条修正：不为柜台押铺面；有钱就赎家当（`estate.redeem`）；风声到第 3 档不再“编一个” |
| `scripts/cards/sim/policies/drafter.gd` | trader + 挑选启发：客源先要买主（≤ 2 拨），再要便宜货；赏先要加价物件，关口前要 `official`/`papers` 的人情；路：手上有证件或人情就走查铺周，风声 ≥ 3 档或押着家当就走歇一歇，否则集日 > 庙会 > 平常；闲日一律快过 |
| `scripts/cards/sim/policies/drafter_blind.gd` | 柜台同 drafter，走一趟的选择全随机（域 `c.ai.drafter_blind`）——用来证明“选择有用” |
| `scripts/cards/sim/telemetry.gd` | 每关多一块 `run`：走过的周牌、开门天数、闲日天数、快过次数、每周成交数、拿到的客源和赏、每周世道档、条子各档、关口档与结果（`passed`/`bought`/`failed`/`void`）、开张与月底家底、结局档、分；全部从 `view.run` 和总线读，不碰引擎内部 |
| `scripts/cards/sim/fuzz_actions.gd` | 合法动作加 `run.pick`（从 `view.run.offers` 和 `reachable` 里取）、`run.fast_forward`；不合法动作加 `run.pick {slot: "week", id: "r9c9"}`、`run.pick {slot: "x"}` |
| `scripts/cards/sim/fuzz_runner.gd` | 每三局有一局 `mode: "run"`，`stages` 随机 1–3 |
| `tools/cards/balance/run_mode.sh` | 照 `w2_run.sh` 复制生产数据跑：`--mode=run`，七种策略 + payer、trader、drafter、drafter_blind |
| `tools/cards/balance/aggregate.py` | 走一趟的表：结局档分布、家底增减 p10/中位/p90、关口三种结果的比例、第 4 周世道档分布、丢家当件数、局终率、开门天数、每开门日步数 |

命令：

```sh
# 单幕 1938，50 种子
GODOT=<Godot 4.7.1> SEEDS=50 JOBS=4 bash tools/cards/balance/run_mode.sh <输出目录> \
  --stage=0 --stages=1 --policies=refuser,payer,trader,drafter,drafter_blind,greedy,random
# 三幕连走
GODOT=<Godot 4.7.1> SEEDS=50 JOBS=4 bash tools/cards/balance/run_mode.sh <输出目录> --stage=0 --stages=3
# 对照：本传，确认数字一个不动
GODOT=<Godot 4.7.1> SEEDS=20 JOBS=2 bash tools/cards/balance/w2_run.sh after <输出目录>
```

### 7.4 验收（第一轮调数的目标）

| # | 指标 | 目标 |
|---|---|---|
| A1 | refuser：结局 ≥ 站住 | ≤ 5% |
| A2 | payer：结局 ≥ 站住 | ≤ 25%；家底增减中位数 < 0 |
| A3 | trader：结局 ≥ 站住 | ≥ 50%；败落 ≤ 25% |
| A4 | drafter：结局 ≥ 站住 | ≥ 60%；兴旺 ≥ 15% |
| A5 | drafter 家底增减中位数 − payer 的 | ≥ 开张现钱的 40%（1938 约 136） |
| A6 | drafter − drafter_blind（选择有用） | 家底增减中位数差 ≥ 开张现钱的 15%；站住率差 ≥ 10 个百分点 |
| A7 | 选择多样 | drafter 选得最多的周牌占比 ≤ 50%；每件物件都被拿过 |
| A8 | 不卡死 | 所有策略 `ok`；`G06_no_deadlock` 含走一趟的局全过 |
| A9 | 时长代理 | 单幕开门日 12–18 天；drafter 每趟步数 ≤ 本传 fair 同年一关步数的 55% |
| A10 | 本传不动 | 本传 140 局逐局结果与改前相同（只差 `db_hash`），见 10.3 |

20 个种子只够探索，验收用 50 个；一局 = 2 个百分点。

### 7.5 先调哪几个数

1. 先跑基线，看 A1–A3。refuser 太好 → 调 `press.week_up` / `bias_*`；payer 太好 → 关口认罚的钱、`upkeep.per_week`。
2. trader 太差 → 先查是策略的毛病还是经济：看成交数和每笔毛利；毛利不够 → 调客源人物牌的 `budget_pct`、`asking`、`floor`，不动 `economy.json`（那是本传的数）。
3. A6 不过（选择没用）→ 拉开周牌之间的差：集日的买主倍数、查铺周的赏。
4. 最后看时长：开门日太多 → 减周牌的 `busy.n`。

每批改动只动 `run.json` 和 `data/cards/run/**`，本传的黄金种子、报告不受影响。

### 7.6 时长核算（单幕，人玩）

假设：开门日 2.5–3.5 分钟（4–5 张牌、对话、偶尔小游戏），1938 教学日约 2 分钟，闲日连快过约 10 秒，关口那天约 5 分钟，周末盘账约 1 分钟，开月和结局共约 4 分钟。

| 年 | 开门日 | 闲日 | 估计 |
|---|---|---|---|
| 1938 | 第一周 5（含教学 3）+ 后三周 9–11 + 月底 2 = 16–18 | 12–14 | 约 45–60 分钟 |
| 1939 / 1940 | 四周 12–14 + 月底 2 = 14–16 | 14–16 | 约 40–55 分钟 |

要用真人试玩各量 3 局核对（K14 的真点脚本可以量“每开门日的点击数”做代理）。

---

## 8. 先做什么：1938 单幕的竖切

**目标**：最早拿到两个答案——走一趟能不能让“全拒”变成最差的选择；一趟是不是 30–60 分钟。

| 做 | 不做（第二版） |
|---|---|
| 1938 单幕；三幕连走只留开关不开放 | 1939、1940 的处境、关口、年景 |
| 周牌 6 种：`wk.1938.open` `plain` `market` `temple_fair` `curfew` `rest` | 查铺周、黑市周、年代专属周 |
| 客源 6 拨（connoisseur、refugee、dock、regulars、students、levy_runners）+ 约 15 张新人物牌 | 其余客源 |
| 物件：N03 的 9 件 + `rl.rule.no_idlers` | 其余“规矩”物件 |
| 处境 6 张 | 年景 |
| 关口：1938 伪警察所三档 | 1939、1940 关口 |
| 世道、开销、闲日、过到有事那天、家底、四档结局、分 | 难度档（只留 0）、局外解锁（只做“解锁 1939”的标记） |
| 界面：处境页、本月的路、周末盘账、走完一趟、HUD 状态、快过按钮、两个抽屉 | 柜台上画物件道具（先只在抽屉里） |
| 模拟：payer、trader、drafter、drafter_blind；跑 A1–A10 | — |

竖切完成的标准：A1–A4、A8、A10 过；一位没玩过的人走一趟 1938，时长在 30–60 分钟内。

---

## 9. 拆包

七个包，RUN0 先合；之后 RUN1–RUN4 可以同时做（都对着 RUN0 的合同、Mock 和例子集）；RUN5 等 RUN1 能跑；RUN6 最后。

### RUN0 · 合同与地基（Claude + G01 + G02 的小改）

- **改**：5.1 全部；5.2 全部；5.3 全部；`card_engine.gd` 装模块那一行；Mock 与夹具（5.7）；`data/cards/_examples/run/` 例子集（每种新类型一张，加一个 `run.json`）；`scripts/cards/run/run_install.gd` 的**桩**（登记全部指令、修正项，返回中性值）。
- **测**：`RUN0_story_neutral`（本传三关 5 个种子：没有 `run` 键、没有 `mode` 键、没有 `c.run.*` 抽取、各修正项返回中性值、视图里没有 `run`）；校验器 default/strict 对例子集全绿；`W0_next_day` 照过。
- **黄金**：数据和规则文件加了，`db_hash` 变，本传黄金要重生。照 §12.5 单独一个提交，只改 `golden.json`，写明“只有 db_hash 变；10.3 的对照脚本确认本传每天的钱款流水与改前相同”。
- **完成**：合同新章节合入；其余包能对着桩开工。

### RUN1 · 引擎模块（新主人 RUN1）

- **改**：`scripts/cards/run/**`（5.4、5.5），`data/cards/rules/run.json`，`data/cards/ui_keys/RUN1.json`，`data/cards/tags/RUN1.json`；G04 的 `CardShelf.book_value`（开 `[shared] RUN1→G04`）。
- **测**（`scripts/tests/cards/RUN1/`，清单 `suites/RUN1.txt`）：
  - `RUN1_map`：1000 个种子，周图合法（行数、个数、上限、连通、不交叉、1938 第 0 行固定）、同种子同图；
  - `RUN1_idle`：闲日不随机发人物、事件、消息；日程、金色、条子、来赎、命运照发；
  - `RUN1_fast_forward`：六种停法各一例；和逐条 `day.end` 的哈希相等；
  - `RUN1_picks`：四种 `slot` 的正反例；没选时替你选；`day.end_preview` 的 `auto_pick` 行与结算一致；
  - `RUN1_press`：涨、不涨、松一档；周一加码落到条子档位；
  - `RUN1_boss`：按世道挑档；照办过、认罚、没过、没理会四条路；
  - `RUN1_score`：家底每一项和 `view` / 查询里看得见的数逐项相等；押家当不改家底；四档结局；
  - `RUN1_save`：任意早上存读后哈希一样；`game.retry_stage` 回到同一张图、同样的候选；
  - 通用：确定性两遍哈希一样、没有浮点、随机域都登记过、视图隐藏键检查、每个 first-time 恰好一次。
- **完成**：例子集上 RUN1 全绿；真数据上 refuser 和 fair 各跑一趟不卡死。

### RUN2 · 数据（K 类线）

- **改**：`data/cards/run/weeks.json` `sources.json` `relics.json` `origins_1938.json` `bosses_1938.json` `people_run.json`（带 `persons` 块）`events_run.json`（`ev.any.run_rest` 等）；`data/cards/tags/RUN2.json`；`data/cards/ui_keys/RUN2.json`；美术清单条目（K12 一并出程序像素画）；`data/cards/text_ai/run/**` 基础层正文。
- **测**：`RUN2_validate`（strict 全绿，V43–V47）；数量统计（周牌 ≥ 6、客源 ≥ 6、新人物 ≥ 15、物件 ≥ 10、处境 ≥ 6、关口三档）；史实措辞（K13 的 `tools/cards/review/`）。
- **完成**：strict、ship（带 AI 声明版）0 错。

### RUN3 · 界面（C 类线）

- **改**：`scenes/cards/run/RunOrigin.tscn` `RunMap.tscn` `RunWeekEnd.tscn` `RunEnd.tscn` `SourcesDrawer.tscn` `RelicsDrawer.tscn`，`scripts/cards/ui/run/**`，`data/cards/ui_keys/RUN3.json`；对 C01（HUD 文字、快过按钮、第五个标签、门板半上）、C09（开月流程插页、局终换叠层）、C16（标题的“走一趟”）各开 `[shared]`。
- **测**：Mock 夹具上每个面板能实例化、`bind` 各状态不报错；点击发出的指令对（`mock.sent`）；`autoplay_step()` 走完；Esc 关得掉；所有字来自 `CardText`；锚点在 `CardLayout` 的位置；X01 真点冒烟加一条“走一趟”路线（标题 → 走一趟 → 处境 → 轮盘 → 本月的路 → 第 1 天 → 打烊 → … → 第 7 天周末盘账）。
- **截图**：6.1–6.7 每屏一张 1280×720。
- **完成**：真引擎上用鼠标从标题点到第 8 天，0 报错。

### RUN4 · 指引与规矩页（K16 / C16 类）

- **改**：`data/cards/guide/run_steps.json`、`run_rule_pages.json`（或并进现有文件，看 K16 的归属），`text_ai` 基础层。
- **测**：strict 模式 V29–V36 全绿；`RUN4_guide_walk`：真引擎走一趟第 1–8 天，每个新 first-time 的步骤都亮过一次；开关指引哈希相同。

### RUN5 · 模拟与平衡（G06 类）

- **改**：7.3 的全部；`docs/cards/balance/report_<日期>_run.md`。
- **测**：`G06_no_deadlock_*` 加走一趟的局后照过；新黄金用例（10.2）；`test_aggregate.py` 加走一趟的列。
- **完成**：一份报告，写清 A1–A10 每条过没过、用的覆盖文件和种子。

### RUN6 · 局外解锁（C16 类，可后做）

- **改**：标题读写 `user://cards/run_meta.json`（只存每年、每档走到过的最好结局；不进状态、不进哈希）；设置里“全部解锁”（给测试和试玩）。
- **测**：文件坏了、没有时照常开局；测试一律用 `card_t` 给的目录。
- 如果另一位设计师做“局外传承”，就接在这个文件上，不改引擎。

---

## 10. 测试与黄金

### 10.1 不卡死

`G06_no_deadlock` 现在是三段各 250 个种子。加走一趟后：每段里每三局有一局 `mode: "run"`（`stages` 1–3 随机），随机动作里混进 `run.pick`、`run.fast_forward` 的合法和不合法写法，继续断言 §7.4.7 第 4 条的 1–4。另加一条专门的：从周末盘账、处境没选、关口牌在手、快过停在“要确认”这四种状态出发，连按 `day.end {confirm: true}` 最多 8 次一定进到下一天或局终。

### 10.2 黄金种子

- 本传的用例：RUN0 合入时重生一次（只因 `db_hash`），之后 RUN1–RUN5 都不该再让本传的用例变。
- 新用例（RUN5 加进 `golden.json`）：`{"seed": 7, "policy": "drafter", "data": "real", "mode": "run", "stage": 0, "stages": 1, "days": 30, "hashes": [第 10、20、30 天]}`，以及一个 `examples` 数据的同类用例。之后改走一趟的数据或规则，按 §12.5 在 PR 里写原因、加 `golden-change` 标签。

### 10.3 本传不动的对照

RUN0 合入前，照 10-22 报告的诊断做法写一个只读对照脚本（放临时目录，不入库）：同一种子、同一策略，在改前、改后两个提交各跑本传三关，逐条记下指令和 `money_changed(old, new, reason)`，要求逐条相同；状态哈希相同（计算时去掉 `db_hash`）。结果写进 RUN0 的 PR。

---

## 11. 和另外两份设计的接口、风险、还没定的

### 11.1 接口

| 别的方向可能做的 | 怎么接 |
|---|---|
| 局外传承、解锁、永久成长 | 只经 RUN6 的 `run_meta.json` 和 `game.new` 的参数（`level`、开局多给的处境候选）进局；不进状态里的规则 |
| 牌面协同、新物件、新客源 | 用本稿的 `relic` / `source` 类型和 `mods` 写法；新修正项另开 `[api]` |
| 经济公式（收价、买家预算、利息） | 本稿不改 `economy.json`；走一趟里靠客源人物牌自己的 `asking`/`floor`/`budget_pct` 调。如果经济线改了本传的公式，走一趟跟着变，RUN5 重跑 |
| 剧情、正文 | 走一趟复用本传的主线牌；本稿新加的正文只有周牌、客源、物件、处境、关口和结局 |

### 11.2 风险

| 风险 | 处理 |
|---|---|
| 闲日让主线节点挤在开门日以外 | 日程、金色牌在闲日照发，快过遇到就停；1938 第一周固定，教学不受影响 |
| `run.fast_forward` 一次发出很多事件，界面乱 | 界面在它返回后按 `days` 演一段“这几天”，中间的阶段面板不弹（RUN3 对 C01 的 `[shared]` 里写清） |
| 关口太硬，trader 也过不去 | 认罚永远在；`need` 和认罚的钱都是整数键，先按 A3 调 |
| 赚钱的客源伤本心，玩家看不见本心 | 和本传一致：本心只影响结局正文、大轮盘的段、签；结局正文里有回声 |
| 走一趟和本传共用数据，改一边伤另一边 | 走一趟的东西只在 `data/cards/run/**` 和 `run.json`，新人物牌都带 `run_has`；RUN0_story_neutral 和 10.3 守着 |
| 加了四种类型，校验器、正文覆盖层、清单都要认 | 都放在 RUN0 一次做完，其余包不碰 |

### 11.3 还没定的（除 0.3 外）

1. 难度档的名字和每档内容。
2. 三幕连走第二、三个月的“年景”候选怎么写。
3. 认罚算不算“站住”（本稿：算，但不算“兴旺”）。
4. 周末盘账要不要也给“卖掉一件柜上物件换钱”（第二版）。
5. N02 的禁收令做成“查禁周”、N06 的进货路线做成“进货周”（第二版）。
