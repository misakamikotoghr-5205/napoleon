# K04 `data-1939-world` · 1939 事件、命运、大命运、生活、目标、开场 + 通用命运

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K04 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K04: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 4**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default、`_schema/{event,fate,big_fate,life,goal}.json`、例子集 `data/cards/_examples/era/common/fate.json`（命运牌例子 `fa.any.fire_next_door`） | W0（已完成） |
| K03 | 1939 主线节点里人物出面的归 K03，事件形状的（城门盘查 `s1939.gate_check`、米行涨价 `s1939.wu_price`）归你——PR 里对分工 | W1（并行） |
| K10 | 你的 1939 大命运（大赌）要被大轮盘扇区引用（V36） | W1（并行，交清单） |
| K08 / K09 / K11 / K12 | 碎片、留牌、物品、美术占位 | W1（并行） |

- **波次**：W1。**通用命运 18 张在第一关就会抽到**——`gd.fate`（第一次命运牌）在第一关基本靠你的通用命运触发，所以 `era/common/fate.json` 请**先交**。
- **W2**：1939 数据 strict 全绿、按 K13 的 `[K13→K04]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6）、G06 平衡报告（命运牌好坏比例是报告指标）修数。

## 分支

`cards/K04-data-1939-world`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写第二关（1939 腊月）的世界：事件（城门盘查、米行涨价、乡下的消息……）、命运、大命运（大赌）、年关生活牌、本关目标（主线“过年前把账结清”）、开场 `stage.json`；另写**全年代通用的命运牌 18 张**（从 K02 移过来）。只写**机制 + brief**。

## 必读

1. 合同 §0、§2.2、§2.5、§3.4 开头与 K04、§3.5（1939 主线节点、目标 id `gl.1939.<slug>`）、§4.1–§4.4、§4.7.3–§4.7.7（event、fate（`valence` 必填）、big_fate（除 `bf.wheel` 外 `weight: 0`）、life）、§4.7.20、§4.7.22、§4.9（V10、V16、V18、V28、V34、V36）、§5.2–§5.3、§9.3（命运牌的 `valence` 决定签的等第；本心低时坏牌先被写进签）、§7.10.10、§11.2、**§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §三.6、§三.12、§四、§五（1939 腊月）、§九.2、附录、“实现时的理解”第 3、5 条。
3. `docs/town/cards/src/era.json` 的 `notes`、`pawn[1]`、`launch[1]`、`sources`（1939 年物价与地方变化）。
4. 例子集：`data/cards/_examples/era/common/{fate,big_fate}.json`、`data/cards/_examples/era/1938/{events,goals,stage}.json`。

## 要做的事

### A. 通用命运（`data/cards/era/common/fate.json`，**先交**）
- [ ] 18 张 `fa.any.<slug>`，`era: ["*"]`（或明确列出的几个年代），`weight > 0`，**`valence` 必填**（`good` `bad` `mixed`；大致好:坏:混 = 5:7:6【待调】）。
- [ ] 形状照 §4.7.4 邻铺失火的例子：2–3 个选项（`choices`），有的带检定格子（掷铜钱），有的直接执行效果；效果用 `rep` `heat` `item_lose` `money` `pay`（`short: "ladder"`）`person_state` `attr`（带 `days` 的临时属性）`deck_mod` `weather` 等；原因键 `k04.reason.*`。
- [ ] 每张至少一个 `omen_*`（签和测字靠它匹配），坏的再加 `bad_omen` 视情况（命运牌有 `valence`，`bad_omen` 主要给没有 valence 的类型用）。
- [ ] 不写和年代绑死的史实（通用牌）；季节性的用 `conditions`（例 `{"weather": "snow"}`）。

### B. 1939（`data/cards/era/1939/{events,fate,big_fate,life,goals,stage}.json`）
- [ ] 事件 10 张（`ev.1939.<slug>`）：城门盘查（设岗、查证件，格子收 `kept` 的证件 / 钱 / 胆大的人）、米行涨价（吴长发）、乡下的消息、年关讨债……；事件形状的主线节点带 `story_node`、`weight: 0` + `schedule`。
- [ ] 命运 4 张（`fa.1939.<slug>`，`valence` 必填）。
- [ ] 大命运 1–2 张（`bf.1939.<slug>`，**`weight: 0`**、`crisis`、`valence`、`choices`）；清单交给 K10。
- [ ] 年关生活牌 3–4 张（`lf.1939.<slug>`：年货、还账、当衣过年、置办……；`season` 含 `3`（冬）、`due_days`、`waivable`、`pay` 用 `short: "ladder"`）。
- [ ] 目标：主线 `gl.1939.<slug>`（“过年前把账结清”，`main: true`、`done_when` 用条件、`eval: "month_close"`）+ ≥ 4 可选。
- [ ] `data/cards/era/1939/stage.json`：`{"_meta": {"owner": "K04", "schema": 1}, "era": "1939", "bg": "bg.stage.1939", "intro_paras": n, "main_goal": "gl.1939.<slug>", "brief": "…", "_provenance": {…}}`。
- [ ] 每张：`tags` 至少一个 `omen_*`（event/fate/life）、`art: "illus.<id>"`、`brief`、`_provenance: {"by": "ai", "task": "K04", "date": "<提交当天>"}`；日程 `stage_day` ≤ 30。

### C. 标签、界面键
- [ ] `data/cards/tags/K04.json`、`data/cards/ui_keys/K04.json`（`k04.reason.*` `k04.notice.*`）。

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
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K04] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K04→K12`。
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

- [ ] **同 K02**：每张 1939 事件、1939 命运、大赌都写演出块——例外：带 `opens_wheel` 或 `opens_fortune` 的事件（它们开轮盘叠层或算命先生那一出，默认够用）。每块至少有 `cast` `set` `fx` `walk` `props` 里的一样；事件、命运、大赌没有 `person`，开口的人都要写进 `cast`（例：盘查、查户口的巡警 `ex_patrol` 站 `door_l` / `door_r`；伪军 `ex_soldier` 站门口或 `walk: "troops"`；报信的报童 `ex_newsboy` 站 `door`；下雪、断炊这类用 `fx`：`cold` `dim`）。
- [ ] **通用命运 18 张也要写**（第一关就会抽到，建议先写；例：邻铺失火那类照 W0 例子 `fa.any.fire_next_door` 的演出块写——邻铺伙计 `ex_shopboy` 站 `door`、`fx: ["fire", "smoke"]`，例子在 `scripts/cards/mock/stage_examples.json`，G01 的 1.3 小 PR 合入后挪进例子集）。年关生活牌可选。
- [ ] 生活牌可选（建议 `fx: ["dim"]` 或柜台一角的道具）；`stage.json` 不变；目标（goal）不能带演出块（V40）。
- [ ] 用到群演（`ex_*`）的牌：群演由 K09 在 `data/cards/common/extras.json` 登记——它合入之前 V39 的登记部分在 default 模式只是 NOTE，strict 要它合入；群演的 `walk.*` / `portrait.*` 由 K12 进清单（V42）。
- **数量**：1939 事件 10 + 1939 命运 4 + 大赌（`bf.1939.*`）全部 + 通用命运 18——都除去上面的例外。

**新增 / 作废的交付**

- 新增一个 PR `[K04] 演出块`：动 `data/cards/era/common/fate.json` 和 `data/cards/era/1939/{events,fate,big_fate,life}.json`，G01 的 1.3 小 PR 合入后再提。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件；上文“新手指引”表里的锚点 1.3 没有改名，对你没有要做的事。

**测试与截图**

- `K04_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- 演出块 PR 里 `test_data.gd` 加：除上面的例外，每张该写的牌都有 `stage`，且 `cast` `set` `fx` `walk` `props` 至少一样不空；演出块里每个 `brief` 也过 brief 自查（引号里 ≤ 12 字、不含 `。！？`、伪字）；用到的群演 id 都在 `CardIds.EXTRAS` 里。
- 截图：数据任务照旧不交。

**已经做了的哪些还有效**

- 全部有效；演出块另开 PR。

**日期**：演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提；通用命运第一关就会抽到，尽量跟 1938 的演出块一起 **10-27** 前合入；1939 的跟着你的 1939 数据走，W2 strict 全绿之前合入。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/era/1939/{events,fate,big_fate,life,goals,stage}.json`
- `data/cards/era/common/fate.json`
- 默认拥有：`scripts/tests/cards/K04/**`、`scripts/tests/cards/suites/K04.txt`、`data/cards/tags/K04.json`、`data/cards/ui_keys/K04.json`

## 不能做的事

1. **不写玩家最终内容**：不写正文字段（V04）；不碰人写路径；brief 以外不出现中文；brief 不写台词与引号对白。
2. 大赌 `weight: 0`；不在命运牌里偷偷掷随机——要随机就用看得见的格子检定或 `coin_check`（§5.1）。
3. 不改别人的文件（K02 的 1938 世界牌与通用事件、K06 的通用生活牌、K10 的扇区、`_examples/**`、`rules/**`）。
4. 不写 `minigame`；不发明字段、op、条件；不自己加玩法。
5. 史实措辞：1939 年伪县政府、区公所；日商控制茧行、米行；城门设岗盘查；brief 写依据年份。不拷旧版 AI 文字。

## 接口

**用到**：§4.7.3–§4.7.7、§4.7.20、§4.7.22；§5.2–§5.3；预留 id。

**提供**：通用命运 `fa.any.*`（G05 的命运牌库、签的等第按 `valence`）；1939 大赌（K10 扇区引用）；`gl.1939.*` 与 `stage.json`（G02、C09）；事件节点 `s1939.*`。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `fate`（G05） | 通用命运（第一关就会抽到）、1939 命运 | `gd.fate`（obj.brother_ledger · `a.card@{uid}`） |
| `slots` `coins` `choice`（G03） | 带格子、带选项的命运与事件 | `gd.slots` `gd.coins` `gd.choice` |
| `life`（G01） | 年关生活牌 | `gd.life`（obj.brother_ledger · `a.card.days@{uid}`） |
| `month_open` `month_close`（G02） | `stage.json` 与 1939 目标 | `gd.m.open`（第一关已教）、`gd.month_close` |
| `big_wheel`（G05） | 1939 大赌经大轮盘扇区发到手上（`bf.wheel` 本身归 K02） | `gd.big_wheel` |

- **指引验收（必须有测试）** `scripts/tests/cards/K04/test_guide_support.gd`：
  1. 通用命运里至少 10 张 `weight > 0` 且 `era` 含 `"*"` 或 `"1938"`（第一关能抽到，`gd.fate` 能在第一关第 4 天以后亮）。
  2. 每张通用命运有 `valence`，`good` `bad` `mixed` 三种都有。
  3. 至少 4 张通用命运带选项（`choices`），其中至少 2 张的选项带检定格子（支持 `gd.choice` / `gd.slots`）。
  4. `stage.json` 的 `main_goal` 指向你写的 `main: true` 目标；`bg == "bg.stage.1939"`。
- **W2**：K14 的三关走查；G06 平衡报告的“命运牌好坏比例”。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K04.txt`：

```
# K04 1939 世界牌 + 通用命运（docs/handoff_cards/K04_data-1939-world.md）
K04_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/era/1939/events.json,data/cards/era/1939/fate.json,data/cards/era/1939/big_fate.json,data/cards/era/1939/life.json,data/cards/era/1939/goals.json,data/cards/era/1939/stage.json,data/cards/era/common/fate.json,data/cards/tags/K04.json,data/cards/ui_keys/K04.json --name=K04_validate
K04_data|res://scripts/tests/cards/K04/test_data.gd|120|
K04_guide_support|res://scripts/tests/cards/K04/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K04_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：通用命运 18（± 2）、1939 事件 ≥ 10、1939 命运 4（± 1）、1939 大命运 1–2、1939 生活 3–4、1939 目标 1 主线 + ≥ 4 可选。
- [ ] 每张：id 前缀/类型/年代对；`_provenance.task == "K04"`；brief 非空；event/fate/life 至少一个 `omen_*`；所有 fate 有 `valence`；所有 `bf.*` `weight == 0`；标签已声明。
- [ ] 原因键、告示键 `k04.` 开头且已登记；所有 `pay` 带 `short`。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；“县政府/区公所/维持会”前有“伪”。
- [ ] 悬空引用报告（`NOTE: dangling <id>`）；大赌清单 `NOTE: bigfate_for_k10 <id>`。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K04 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K04] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K04] 通用命运 18 张`（先合）；②`[K04] 1939 事件、命运、大命运、生活、目标与开场`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表与好坏比例；大赌清单；和 K03 的节点分工；悬空引用；史实依据；需要主创/编排决定的事；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 通用命运第一关可抽、`valence` 齐、选项与检定合理；3. 大赌 `weight: 0` 且交给 K10；4. 免 AI 声明与 brief 写法；5. 1939 史实措辞；6. 抽 5 张读 brief 与机制。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量与通用命运的好坏比例 | |
| 大赌清单（给 K10） | |
| 和 K03 的节点分工 | |
| 新加的 id、标签、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
