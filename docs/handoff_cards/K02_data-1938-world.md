# K02 `data-1938-world` · 1938 事件、命运、大命运、生活、目标、开场 + 通用事件与大赌

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K02 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K02: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 2**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default 模式、`_schema/{event,fate,big_fate,life,goal}.json`、`stage.json` 的检查、例子集 `data/cards/_examples/era/{1938,common}/*.json` | W0（已完成） |
| K10 | 轮盘 `wh.big` `wh.fair` `wh.gamble`（你的事件用 `opens_wheel` 指过去）；**大赌牌只由 K10 的大轮盘扇区发到手上**（V36：每张 `bf.*`（除 `bf.wheel`）都要被某个扇区引用） | W1（并行，互相对 id） |
| K09 | 格子里收的留着的牌、效果里发的 `kp.*`（例：`kp.mystery_box`） | W1（并行） |
| K08 | 效果里补的档案碎片 `df.*` | W1（并行） |
| K01 | 主线节点的分工：人物出面的节点归 K01，`s1938.police_open` 这类事件节点归你 | W1（并行，PR 里对一下） |
| K12 | 你写的美术 id（`illus.*`、`bg.stage.1938`）由 K12 出占位 | W1（并行） |

- **波次**：W1。**W1 完成条件之一**：K02 合入，1938 数据 strict 校验全绿（悬空引用为 0）。
- **W2**：K13 审读（按 K13 的 `[K13→K02]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6））、G06 平衡报告；你按意见修数。

## 分支

`cards/K02-data-1938-world`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写第一关（1938 年三月）的“世界”：事件牌（含带格子的检定、庙会/赌摊/算命摊）、命运牌、大命运（快输时那张 `bf.wheel` + 只由大轮盘扇区发出的“大赌”）、生活牌、本关目标、开场 `stage.json`，以及跨年代通用的事件与大赌。只写**机制 + brief**；正文全由人写。原来的“规矩牌”取消——规矩由新手指引在戏里讲（§7.10），不占手牌。

## 必读

1. 合同 §0（红线 1、2、6、8）、§2.2、§2.5（`omen_*`；原因键用 `k02.*`）、§3.4 开头与 K02、§3.5（`bf.wheel`、`bf.any.*` 四张预留、系统牌表里的 `ev.any.wheel_go` 与 `bf.wheel`、目标 id `gl.<年>.<slug>`）、§4.1–§4.4、§4.7.3（event：`opens_fortune` `opens_wheel` `cost`；算命摊例子）、§4.7.4（fate：`valence` 必填）、§4.7.5（big_fate：**只有 `bf.wheel` 由 G05 发，其余 `weight: 0`**）、§4.7.7（life：`due_days` `waivable` `season`）、§4.7.20（goal：`done_when` 是条件、`eval`）、§4.7.22（`stage.json`）、§4.9（V10、V13–V16、V18、V28、V34、V36）、§5.2–§5.3、§7.4.3（事件走 `slots` 面板，轮盘牌走 `wheel`，算命摊走 `fortune`）、§9.2（三种转法）、§7.10.10–§7.10.11、§11.2、**§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §二、§三.4（放格子掷铜钱）、§三.6（命运与大命运）、§三.12、§四（一关）、§五（1938 时局、首发主线）、§九.1–§九.2、附录、文末“实现时的理解”第 5、6 条。
3. `docs/town/cards/src/era.json` 的 `notes`、`pawn[0]`、`launch[0]`、`sources`（史实依据写进 brief）。
4. 例子集：`data/cards/_examples/era/1938/{events,goals,stage}.json`、`data/cards/_examples/era/common/{events,big_fate}.json`、`data/cards/_examples/fortune/{wheels,segments_1938}.json`。
5. 只读剧情事实：`data/story/**`、`data/town/storylets.json`、`docs/town/DESIGN_v04_town.md`（旧文字是 AI 写的，不许拷）。

## 要做的事

### A. 通用（`data/cards/era/common/events.json`、`data/cards/era/common/big_fate.json`）
- [ ] 通用事件 10 张（`ev.any.<slug>`，`era: ["*"]`）：至少包含——
  - 算命摊 `ev.any.fortune_teller`（`opens_fortune: "both"`、`cost: {"money": n}`、`must_resolve: false`、一个“不算”的选项 `pass`；照 §4.7.3 例子）；可以再有测字摊/城隍庙抽签各一张（`opens_fortune: "cezi"` / `"lot"`）。
  - 庙会 1 张（`opens_wheel: "wh.fair"`、`cost: {"money": n}`）、赌摊 1 张（`opens_wheel: "wh.gamble"`、`cost: {"stake": true}`——押一张留着的牌）。
  - 系统牌 `ev.any.wheel_go`（`weight: 0`、`must_resolve: false`；G05 的 `wheel_offer` 效果发它，`vars: {wheel, cost}` 由引擎填；brief 写清“处理它 = 打开那个轮盘；没理会 = 这次不去”）。
  - 其余是带格子检定的事件（§4.7.3 查良民证那样：`slots` + `check`，失败/成功效果）。
- [ ] 通用大命运：`bf.wheel`（`weight: 0`、`opens_wheel: "wh.big"`、`tags` 含 `big`；照 §4.7.5 例子）+ 大赌 4–6 张：至少 §3.5 预留的 `bf.any.mystery_box` `bf.any.sun_guarantee` `bf.any.house_offer` `bf.any.ship_ticket`。**大赌一律 `weight: 0`**，写 `crisis`（适合哪种危机：`cash_short` `arrested` `heat_max` `street_long`）、`valence`、`choices`。
- [ ] 把大赌的 id 清单交给 K10（PR 描述里列出 + 在 K10 的 PR 下评论），K10 的大轮盘扇区用 `add_card` 发它们。

### B. 1938（`data/cards/era/1938/{events,fate,big_fate,life,goals,stage}.json`）
- [ ] 事件 10 张（`ev.1938.<slug>`）：查良民证（`ev.1938.police_check`，可以照 §4.7.3 例子）、伪维持会摊派相关、码头/船、月底警察所开门（主线节点 `s1938.police_open`：`story_node`、`weight: 0` + `schedule`（月底），和 K01 对齐）……带格子、选项、检定为主。
- [ ] 命运 4 张（`fa.1938.<slug>`，`valence` 必填：`good` `bad` `mixed`）。通用命运 18 张归 K04，不是你。
- [ ] 大命运 1–2 张（`bf.1938.<slug>`，`weight: 0`，同 A 节的大赌规则）。
- [ ] 生活牌 2–3 张（`lf.1938.<slug>`）：`due_days`、`waivable`、`season`（三月 = 春 `0`）、`choices`、`on_expire`；付钱用 `pay` 且 `short: "ladder"`（付不起走 G06 的钱不够阶梯）。通用生活牌 12 张归 K06。
- [ ] 目标（`gl.1938.<slug>`）：1 个主线 `gl.1938.keep_shop`（`main: true`，“撑过第一个月，保住铺面”，`done_when` 用条件 op，例 `{"estate_status": ["es.shopfront", "held"]}`，`eval: "month_close"`）+ ≥ 4 个可选（`main: false`、`weight` > 0，例“月底前赎回首饰柜”“补齐周妈那一页”）。
- [ ] `data/cards/era/1938/stage.json`（§4.7.22，不是牌文件）：`{"_meta": {"owner": "K02", "schema": 1}, "era": "1938", "bg": "bg.stage.1938", "intro_paras": 3, "main_goal": "gl.1938.keep_shop", "brief": "…", "_provenance": {…}}`；brief 写三段各讲什么（时局、铺子、家里）和史实依据。开场段落的正文 `stage.1938#intro.p1…p3` 由 A 写。
- [ ] **日程约束**：第一关第 1–3 天是脚本日（只发日程牌），**你的牌一律不排在第 1–3 天**；`schedule` 的 `stage_day` ≤ 30（V28）。
- [ ] 每张：`era`、`weight`、`tags` 至少一个 `omen_*`（event/fate/life，V34）、`art`（`illus.<牌 id>`）、`brief`、`_provenance: {"by": "ai", "task": "K02", "date": "<提交当天>"}`；原因键 `k02.reason.*`、告示键 `k02.notice.*`；黄历动作写在选项的 `almanac` 里（§9.4 枚举）。

### C. 标签、界面键
- [ ] `data/cards/tags/K02.json`（新标签 + brief）；`data/cards/ui_keys/K02.json`（`k02.*`，只有 brief）。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **每张事件、命运、街头、大赌都要想清楚“打烊时还没处理”会怎样**（合同 §7.4.7、校验 V37）：有顶层 `check` 的，没理会 = 当没过（执行 `check.on_fail`），可以不写；**没有顶层 `check` 的（只有选项的）必须写 `effects.on_expire`**——一般和最消极的那个选项一样（例：邻铺失火没理会 = 当关门躲），真的没有后果就写 `[]`；brief 里一句话写明。写了非空 `on_expire` 的，A 要写正文 `outcomes.ignored`。
- [ ] **“今天的机会”类事件写 `must_resolve: false`**：算命摊、测字摊、城隍庙、庙会、赌摊（带 `opens_fortune` / `opens_wheel` 的）、`ev.any.wheel_go`——没理会就是机会过去了，没有别的后果。
- [ ] `bf.wheel` 不用写：没处理就作废（这次大轮盘错过了），引擎管。大赌（扇区发来的 `bf.*`）按上面第一条写 `on_expire`（例 `bf.any.mystery_box`：没理他 = 不收，`[]`）。
- [ ] 生活牌照旧：`on_expire` = 拖到期限按“挨过去”处理；打烊时没到期就留到明天。
- [ ] 主线事件（如 `s1938.police_open` 这类）也要写没理会的结果；不能让主线因为没点开而断掉——没理会时主线怎么走写进 `on_expire`（用 `story` 记一个走向）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

数据卡共用的写法：

- 演出块的格式、站位、道具位、效果、拍子见合同 §4.7.24；默认演法见 §7.11.4——**默认够用的牌不写**。
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K02] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K02→K12`。
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

- [ ] **每张事件、命运、大赌都写演出块**——例外：`bf.wheel`、`ev.any.wheel_go`、带 `opens_wheel` 或 `opens_fortune` 的事件（它们开轮盘叠层或算命先生那一出，默认够用）。每块至少有 `cast` `set` `fx` `walk` `props` 里的一样。事件、命运、大赌没有 `person`，开口的人都要写进 `cast`。例：
  - 查良民证 `ev.1938.police_check`：照合同 §4.7.24 第一个例子——两个巡警 `ex_patrol` 站 `door_l` / `door_r`、`walk: "patrol"`、`intro` 两拍、`after.success` / `after.fail`。
  - 米价涨：报童 `ex_newsboy` 站 `door`。
  - 失火：邻铺伙计 `ex_shopboy` 站 `door` + `fx: ["fire", "smoke"]`。
  - 宵禁：`walk: "patrol"` + `props: [{"art": "prop.notice", "at": "door_notice"}]`。
  - 伪军过境：`walk: "troops"`（brief 写“伪军”）。
- [ ] 生活牌可选（建议 `fx: ["dim"]` 或柜台一角的道具）。
- [ ] 例外的那几张想写也可以（可选）：例如庙会写 `{"set": "temple"}`——C01 开轮盘叠层之前会让场景层先按这张牌的演出块换城隍庙背景、上人（合同 §7.4.3）。
- [ ] `stage.json` 不变；目标（goal）不能带演出块（V40）。
- [ ] 用到群演（`ex_*`）的牌：群演由 K09 在 `data/cards/common/extras.json` 登记——它合入之前 V39 的登记部分在 default 模式只是 NOTE，strict 要它合入；群演的 `walk.*` / `portrait.*` 由 K12 进清单（V42）。
- **数量**：1938 事件 10 + 通用事件 10 + 1938 命运 4 + 大赌全部（`bf.any.*`、`bf.1938.*`）——都除去上面的例外。

**新增 / 作废的交付**

- 新增一个 PR `[K02] 演出块`：动 `data/cards/era/1938/{events,fate,big_fate,life}.json` 和 `data/cards/era/common/{events,big_fate}.json`，G01 的 1.3 小 PR 合入后再提。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件；上文“新手指引”表里的锚点 1.3 没有改名，对你没有要做的事。带格子的事件在画面里：格子摆在柜台上（`a.slots.first` `a.slots.coins`），选项是对话框里的回话（`a.slots.choices`）。

**测试与截图**

- `K02_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- 演出块 PR 里 `test_data.gd` 加：除上面的例外，每张 event / fate / big_fate 都有 `stage`，且 `cast` `set` `fx` `walk` `props` 至少一样不空；演出块里每个 `brief` 也过 brief 自查（引号里 ≤ 12 字、不含 `。！？`、伪字）；用到的群演 id 都在 `CardIds.EXTRAS` 里。
- 截图：数据任务照旧不交。

**已经做了的哪些还有效**

- 全部有效；演出块另开 PR。

**日期**：演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提，**10-27** 前合入（1938 的演出块，见交接页检查点）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/era/1938/{events,fate,big_fate,life,goals,stage}.json`
- `data/cards/era/common/{events,big_fate}.json`
- 默认拥有：`scripts/tests/cards/K02/**`、`scripts/tests/cards/suites/K02.txt`、`data/cards/tags/K02.json`、`data/cards/ui_keys/K02.json`

## 不能做的事

1. **不写玩家最终内容**：不写正文字段（V04）；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；brief 以外不出现中文（V05）。brief 干巴巴，不写台词、不写告示原文、不写引号里的对白。
2. **不做“规矩牌”**（`ev.rule.*` 已取消）；不做“哥哥的账簿批注”留牌。
3. **大赌不进随机牌库**：除 `bf.wheel` 外的 `bf.*` 一律 `weight: 0`（V36）；`bf.wheel` 本身也是 `weight: 0`（由 G05 在危机时发）。
4. 不写 `minigame`（V33）；不发明字段、op、条件（开 `[api]`）。
5. 不改别人的文件（K01 的人物牌、K04 的通用命运、K06 的通用生活牌、K10 的轮盘、`_examples/**`、`rules/**`）。
6. 史实措辞（红线 6）：伪维持会、伪维新政府（3 月 28 日在南京成立）、伪县政府；brief 里也照写。不拷旧版 AI 文字。
7. 不往第 1–3 天排日程。

## 接口

**用到**：§4.7.3–§4.7.7、§4.7.20、§4.7.22 的格式；§5.2 效果（`heat` `rep` `conscience` `flag` `story` `kept_risk` `pay` `money` `item_lose` `add_card` `person_state` `coin_check` `wheel_offer` `fate_now` `deck_mod` `shop_closed` …）与 §5.3 条件；预留 id（§3.5）。

**提供**：`bf.wheel`（G05 危机时发）、`ev.any.wheel_go`（G05 `wheel_offer` 发）、`ev.any.fortune_teller`（算命摊）、大赌 `bf.any.*` / `bf.1938.*`（K10 扇区引用）、`gl.1938.*`（G02 目标、C09 开月）、`stage.json`（C09 开月过场）、事件节点 `s1938.police_open`。

## 新手指引

- **锚点**：数据任务不登记锚点。**first-time**：不发（引擎发），但你的数据决定下面这些机制第一次出现：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `month_open`（G02） | `stage.json` + 主线目标（开月过场里显示目标） | `gd.m.open`（brother · `a.month.goals`） |
| `slots` `coins`（G03） | 带格子的事件（第 3 天的教学事件是 K16 的；之后靠你的随机事件） | `gd.slots` `gd.coins`（obj.brother_ledger · `a.slots.first` / `a.slots.coins`） |
| `choice`（G03） | 带选项的事件 | `gd.choice` |
| `fate`（G05） | 1938 命运牌（+ K04 的通用命运） | `gd.fate`（obj.brother_ledger · `a.card@{uid}`） |
| `big_wheel`（G05） | `bf.wheel` | `gd.big_wheel`（obj.brother_ledger · `a.card@{uid}` 备 `a.wheel.face`） |
| `life`（G01） | 1938 生活牌（+ K06 的通用生活牌） | `gd.life`（obj.brother_ledger · `a.card.days@{uid}`） |
| `lot` `cezi`（G05） | `ev.any.fortune_teller`（教学是 K16 第 5 天的 `ev.1938.tut_fortune`） | `gd.lot` `gd.cezi`（suanming · `a.fortune.lot` / `a.fortune.cezi`） |
| `fair_wheel` `wheel_stake` `gamble_wheel`（G05） | 庙会事件、赌摊事件（`cost: {"stake": true}`）、`ev.any.wheel_go` | `gd.fair_wheel`（obj.notice · `a.wheel.cost`）、`gd.gamble_wheel`（"" · `a.wheel.cost`） |
| `month_close`（G02） | 目标在月底结算 | `gd.month_close`（obj.brother_ledger · `a.mclose.accounts`） |

- **指引验收（必须有测试）** `scripts/tests/cards/K02/test_guide_support.gd`：
  1. `stage.json` 的 `main_goal` 指向你写的、`main: true` 的目标；`bg` 是 `bg.stage.1938`；`intro_paras` ≥ 1。
  2. `bf.wheel` 存在，`weight == 0`、`opens_wheel == "wh.big"`；`ev.any.wheel_go` 存在、`weight == 0`。
  3. `ev.any.fortune_teller` 存在，`opens_fortune == "both"`、`cost.money > 0`；至少一张 `opens_wheel == "wh.fair"` 的事件、一张 `opens_wheel == "wh.gamble"` 的事件，其中至少一张 `cost.stake == true`。
  4. 1938 年至少 3 张 `weight > 0`、带 `slots` + `check` 的事件（第一关第 4 天以后能随机抽到带格子的牌）；每张 fate 有 `valence`；每张 life 有 `due_days > 0` 且 `season` 含 `0`（三月）。
  5. 你的所有日程牌 `stage_day` ≥ 4。
- **W2**：K14 的真引擎走查；G05 的危机触发会发你的 `bf.wheel`。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K02.txt`：

```
# K02 1938 世界牌 + 通用事件与大赌（docs/handoff_cards/K02_data-1938-world.md）
K02_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/era/1938/events.json,data/cards/era/1938/fate.json,data/cards/era/1938/big_fate.json,data/cards/era/1938/life.json,data/cards/era/1938/goals.json,data/cards/era/1938/stage.json,data/cards/era/common/events.json,data/cards/era/common/big_fate.json,data/cards/tags/K02.json,data/cards/ui_keys/K02.json --name=K02_validate
K02_data|res://scripts/tests/cards/K02/test_data.gd|120|
K02_guide_support|res://scripts/tests/cards/K02/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K02_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：通用事件 ≥ 10、1938 事件 ≥ 10、1938 命运 = 4（± 1）、通用大赌 4–6、1938 大命运 1–2、1938 生活 2–3、1938 目标 1 主线 + ≥ 4 可选。
- [ ] 每张：id 前缀/类型/年代对；`_provenance.task == "K02"`；brief 非空；event/fate/life 至少一个 `omen_*`；标签都已声明。
- [ ] 所有 `bf.*` 的 `weight == 0`；所有 fate 有 `valence`；目标的 `done_when` 只用 §5.3 的条件 op。
- [ ] 原因键、告示键以 `k02.` 开头且已登记。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；“维持会/维新政府/县政府”前有“伪”。
- [ ] 悬空引用报告：`kp.*` `df.*` 模板、`wh.*`、引用到的人物，不在真数据里的打印 `NOTE: dangling <id>`（不算失败）；另外打印 `NOTE: bigfate_for_k10 <id>`（每张大赌一行，给 K10 对）。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K02 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有泄漏；每行最后一行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K02] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[K02] bf.wheel、ev.any.wheel_go、算命摊、庙会与赌摊、通用大赌`（先合：K10、K16、G05 在等这些 id）
  2. `[K02] 通用事件与 1938 事件`
  3. `[K02] 1938 命运、大命运、生活、目标与开场`
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表；大赌清单（给 K10）；和 K01 的节点分工；悬空引用；新 id 与标签；史实依据（年份）；需要主创/编排决定的事；全部完成写“交付”。

## 审核（Claude 重点）

1. 越界：只动 8 个数据文件和默认拥有的路径。
2. 大命运：只有 `bf.wheel` 打开大轮盘；大赌全 `weight: 0` 且清单交给了 K10。
3. 轮盘与算命摊的事件：`opens_wheel` / `opens_fortune` / `cost` 写对；赌摊押牌。
4. 不排第 1–3 天；没有规矩牌。
5. 免 AI 声明与 brief 写法；史实措辞。
6. 抽 5 张事件读格子、检定、后果是否合设计。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量（通用事件 / 1938 事件 / 命运 / 大命运 / 生活 / 目标） | |
| 大赌清单（给 K10） | |
| 和 K01 的节点分工 | |
| 新加的 id、标签、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
