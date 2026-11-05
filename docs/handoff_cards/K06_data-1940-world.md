# K06 `data-1940-world` · 1940 事件、命运、大命运、生活、目标、开场 + 通用生活牌

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K06 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K06: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 6**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default、`_schema/{event,fate,big_fate,life,goal}.json`、例子集 `data/cards/_examples/era/common/life.json`（`lf.any.coal_out`） | W0（已完成） |
| K05 | 1940 主线节点里人物出面的归 K05；事件形状的（`s1940.wang_regime` 汪伪政权成立、`s1940.new_official` 新官上任）归你——PR 里对分工 | W1（并行） |
| K07 | “条子升档”是 K07 的 1940 条子 + G03 的 `tier_by_stage`；你的事件只用效果 `demand_tier` 之类已有 op 表现“换名目” | W1（并行） |
| K09 | 夜牌“回家吃饭”能免掉生活牌的坏处（`waive`）——你的通用生活牌标 `waivable` | W1（并行） |
| K10 | 1940 大赌要被大轮盘扇区引用（V36） | W1（并行，交清单） |
| K08 / K11 / K12 | 碎片、物品、美术占位 | W1（并行） |

- **波次**：W1。**通用生活牌在第一关就会发**（每周一两张，`c.sched.life.*`）——`gd.life`（第一次生活牌）在第一关靠你的通用生活牌触发，所以 `era/common/life.json` 请**先交**。
- **W2**：1940 数据 strict 全绿、K13 审读（按 K13 的 `[K13→K06]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6））、G06 平衡报告修数。

## 分支

`cards/K06-data-1940-world`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写第三关（1940 三月）的世界：事件（汪伪成立、新官上任、摊派换名目……）、命运、大命运、生活、目标（主线“在新规矩下站住脚”）、开场 `stage.json`；另写**全年代通用的生活牌约 12 张**（米、煤、看病、学费、喜帖、丧事、过年……，从 K02 移过来）。只写**机制 + brief**。

## 必读

1. 合同 §0、§2.2、§2.5、§3.4 开头与 K06、§3.5、§4.1–§4.4、§4.7.3–§4.7.7（life：`due_days` `waivable` `season`；例子 `lf.any.coal_out`）、§4.7.12（夜牌 `nt.family_dinner` 的 `waive_life` 选项）、§4.7.20、§4.7.22、§4.9、§5.2（`waive` `pay` 的 `short`）、§7.4.6（生活牌不排在脚本日）、§7.10.10、§11.2、**§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §一（每天发什么、夜牌）、§二、§三.6、§四（每周一两张生活牌）、§五（1940 三月）、附录。
3. `docs/town/cards/src/era.json` 的 `notes`、`pawn[2]`、`launch[2]`。
4. 例子集：`data/cards/_examples/era/common/life.json`、`data/cards/_examples/common/night.json`。

## 要做的事

### A. 通用生活牌（`data/cards/era/common/life.json`，**先交**）
- [ ] 约 12 张 `lf.any.<slug>`：米、煤、看病、学费、喜帖（随礼）、丧事、过年、房租、修屋、借贷还钱……；`era: ["*"]`、`weight > 0`。
- [ ] 每张：`due_days`（几天内处理，> 0）、`waivable`（回家吃饭能免坏处，多数为 true）、`season`（0 春 1 夏 2 秋 3 冬；首发三关是 1938 春、1939 冬、1940 春——**春、冬都要有足够的牌**）、`must_resolve: false`、2 个左右选项（付钱 `pay` 且 `short: "ladder"`；或挨过去：临时属性 `attr … days`、`rep`、`person_state ruhua hurt`）、`effects.on_expire`（拖到期限按“挨过去”处理）。照 §4.7.7 煤用完了的例子写。
- [ ] 每张至少一个 `omen_*`（多半是 `omen_family`、`omen_illness`、`omen_wealth`）；原因键 `k06.reason.*`。

### B. 1940（`data/cards/era/1940/{events,fate,big_fate,life,goals,stage}.json`）
- [ ] 事件 10 张（`ev.1940.<slug>`）：汪伪国民政府成立（节点 `s1940.wang_regime`）、新官上任（`s1940.new_official`）、摊派换名目、清点户口……；事件节点带 `story_node`、`weight: 0` + `schedule`。
- [ ] 命运 4 张（`valence` 必填）；大命运 1–2 张（`weight: 0`、`crisis`、`valence`，清单交给 K10）；生活 2–3 张（`season` 含 `0`）。
- [ ] 目标：主线 `gl.1940.<slug>`（“在新规矩下站住脚”）+ ≥ 4 可选。
- [ ] `data/cards/era/1940/stage.json`：`{"_meta": {"owner": "K06", "schema": 1}, "era": "1940", "bg": "bg.stage.1940", "intro_paras": n, "main_goal": "gl.1940.<slug>", "brief": "…", "_provenance": {…}}`。
- [ ] 每张：`tags` 至少一个 `omen_*`、`art`、`brief`、`_provenance: {"by": "ai", "task": "K06", "date": "<提交当天>"}`；日程 ≤ 30 天。

### C. 标签、界面键
- [ ] `data/cards/tags/K06.json`、`data/cards/ui_keys/K06.json`（`k06.reason.*` `k06.notice.*`）。

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
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K06] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K06→K12`。
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

- [ ] **同 K02**：每张 1940 事件、1940 命运、大赌都写演出块——例外：带 `opens_wheel` 或 `opens_fortune` 的事件（它们开轮盘叠层或算命先生那一出，默认够用）。每块至少有 `cast` `set` `fx` `walk` `props` 里的一样；事件、命运、大赌没有 `person`，开口的人都要写进 `cast`（例：盘查、查户口的巡警 `ex_patrol` 站 `door_l` / `door_r`；伪军 `ex_soldier` 站门口或 `walk: "troops"`；报信的报童 `ex_newsboy` 站 `door`；下雪、断炊这类用 `fx`：`cold` `dim`）。
- [ ] 通用生活牌 12 张可选（写的话多半是 `fx: ["dim"]` / `["cold"]` 或柜台一角的道具；喜帖、丧事可以有送信的人站 `door`）。
- [ ] 生活牌可选（建议 `fx: ["dim"]` 或柜台一角的道具）；`stage.json` 不变；目标（goal）不能带演出块（V40）。
- [ ] 用到群演（`ex_*`）的牌：群演由 K09 在 `data/cards/common/extras.json` 登记——它合入之前 V39 的登记部分在 default 模式只是 NOTE，strict 要它合入；群演的 `walk.*` / `portrait.*` 由 K12 进清单（V42）。
- **数量**：1940 事件 10 + 1940 命运 4 + 大赌（`bf.1940.*`）全部——都除去上面的例外；通用生活牌 12 张可选。

**新增 / 作废的交付**

- 新增一个 PR `[K06] 演出块`：动 `data/cards/era/1940/{events,fate,big_fate,life}.json`（写通用生活牌的话再加 `data/cards/era/common/life.json`），G01 的 1.3 小 PR 合入后再提。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件；上文“新手指引”表里的锚点 1.3 没有改名，对你没有要做的事。

**测试与截图**

- `K06_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- 演出块 PR 里 `test_data.gd` 加：除上面的例外，每张该写的牌都有 `stage`，且 `cast` `set` `fx` `walk` `props` 至少一样不空；演出块里每个 `brief` 也过 brief 自查（引号里 ≤ 12 字、不含 `。！？`、伪字）；用到的群演 id 都在 `CardIds.EXTRAS` 里。
- 截图：数据任务照旧不交。

**已经做了的哪些还有效**

- 全部有效；演出块另开 PR。

**日期**：演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提；跟着你的 1940 数据走，W2 strict 全绿之前合入。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/era/1940/{events,fate,big_fate,life,goals,stage}.json`
- `data/cards/era/common/life.json`
- 默认拥有：`scripts/tests/cards/K06/**`、`scripts/tests/cards/suites/K06.txt`、`data/cards/tags/K06.json`、`data/cards/ui_keys/K06.json`

## 不能做的事

1. **不写玩家最终内容**（正文字段、人写路径、brief 以外的中文、台词与引号对白）。
2. 不排生活牌的日程（每周生活牌由 G02 的 `c.sched.life.*` 插，不排在脚本日；你只给牌和 `season`）。
3. 不改别人的文件（K02/K04 的世界牌、K07 的条子、K09 的夜牌、K10 的扇区、`_examples/**`、`rules/**`）。
4. 大赌 `weight: 0`；不写 `minigame`；不发明字段、op、条件；不自己加玩法。
5. 史实措辞：**汪伪国民政府**（1940-03-30）、伪维新政府并入；不拷旧版 AI 文字。

## 接口

**用到**：§4.7.3–§4.7.7、§4.7.20、§4.7.22；§5.2–§5.3（`pay` `waive` `attr` `person_state` `rep` `heat` `demand_tier` `story` …）。

**提供**：通用生活牌（G02 每周插、K09 的回家吃饭免坏处、G06 老宅押出生活牌变多）；1940 大赌（K10）；`gl.1940.*` 与 `stage.json`；事件节点 `s1940.wang_regime` `s1940.new_official`。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `life`（G01） | 通用生活牌（第一关第 4 天以后的每周生活牌） | `gd.life`（obj.brother_ledger · `a.card.days@{uid}` 备 `a.card@{uid}`；讲“几天内处理、回家吃饭能免坏处”） |
| `money_short`（G06） | 生活牌 `pay` 的 `short: "ladder"` 付不起 | `gd.money_short`（"" · `a.short.options`） |
| `fate` `big_wheel` `slots` `choice` | 1940 命运、事件 | 同 K02/K04 |
| `month_open` `month_close` | `stage.json`、1940 目标 | `gd.month_close` |

- **指引验收（必须有测试）** `scripts/tests/cards/K06/test_guide_support.gd`：
  1. 通用生活牌里至少 6 张 `season` 含 `0`（春，第一关能发）、至少 4 张含 `3`（冬，第二关）；每张 `due_days > 0`（`gd.life` 的锚点 `a.card.days@{uid}` 要有剩几天的角标）。
  2. 至少一半通用生活牌 `waivable == true`；至少 4 张有 `pay` 且 `short == "ladder"`（第一次钱不够从这里来）。
  3. 每张生活牌有 `on_expire`（拖到期限有后果）。
  4. `stage.json` 的 `main_goal` 指向你写的 `main: true` 目标；`bg == "bg.stage.1940"`。
- **W2**：K14 三关走查。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K06.txt`：

```
# K06 1940 世界牌 + 通用生活牌（docs/handoff_cards/K06_data-1940-world.md）
K06_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/era/1940/events.json,data/cards/era/1940/fate.json,data/cards/era/1940/big_fate.json,data/cards/era/1940/life.json,data/cards/era/1940/goals.json,data/cards/era/1940/stage.json,data/cards/era/common/life.json,data/cards/tags/K06.json,data/cards/ui_keys/K06.json --name=K06_validate
K06_data|res://scripts/tests/cards/K06/test_data.gd|120|
K06_guide_support|res://scripts/tests/cards/K06/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K06_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：通用生活 ≈ 12（≥ 10）、1940 事件 ≥ 10、1940 命运 4（± 1）、1940 大命运 1–2、1940 生活 2–3、1940 目标 1 主线 + ≥ 4 可选。
- [ ] 每张：id 前缀/类型/年代对；`_provenance.task == "K06"`；brief 非空；event/fate/life 至少一个 `omen_*`；fate 有 `valence`；`bf.*` `weight == 0`；标签已声明；`season` 的值都在 0–3。
- [ ] 原因键、告示键 `k06.` 开头且已登记；所有 `pay` 带 `short`。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；“国民政府”前有“汪伪”、其余伪政权名前有“伪”。
- [ ] 悬空引用报告（`NOTE: dangling <id>`）；大赌清单 `NOTE: bigfate_for_k10 <id>`。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K06 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K06] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K06] 通用生活牌 12 张`（先合）；②`[K06] 1940 事件、命运、大命运、生活、目标与开场`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表；生活牌的季节分布；大赌清单；和 K05 的节点分工；悬空引用；需要主创/编排决定的事；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 通用生活牌：`due_days`、`waivable`、季节覆盖春冬、`on_expire`、`short: "ladder"`；3. 大赌交 K10；4. 免 AI 声明与 brief 写法；5. 1940 史实措辞；6. 抽 5 张读 brief 与机制。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量；生活牌季节分布 | |
| 大赌清单（给 K10） | |
| 和 K05 的节点分工 | |
| 新加的 id、标签、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
