# K05 `data-1940-people` · 1940 三月人物牌、主线节点

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K05 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K05: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 5**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default、`_schema/person.json`、例子集 | W0（已完成） |
| K01、K03 | 1938、1939 的主线**走向名**（你的条件 `{"story": [...]}` 要用）、老面孔的状态 | W1（按它们 PR 里的走向名表写） |
| K06 | 1940 的事件节点（`s1940.wang_regime` 汪伪政权成立、`s1940.new_official` 新官上任若是事件形状）归 K06——PR 里对分工 | W1（并行） |
| K08 | 碎片 `df.*`（含 1939→1940 “一年后”、`s1940.dossier_link` 关键碎片串起来） | W1（并行） |
| G02 | 首发结尾：`s1940.hook` 之后怎么结束（`game_over` / `g02.ending.*`）是 G02 的事；你只写钩子那张牌 | W1（并行） |
| K09 / K11 / K12 | 留牌、物品、头像占位 | W1（并行） |

- **波次**：W1 开发；W2：1940 数据 strict 全绿、K13 审读（按 K13 的 `[K13→K05]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6））、G06 平衡报告修数。

## 分支

`cards/K05-data-1940-people`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写第三关（1940 年三月，首发最后一关）的人物牌骨架：新官上任后的人、孙府要你表态（站队）、新面孔 `nf1940a`–`nf1940d`、主线节点 `s1940.*` 里人物出面的金色牌，以及**首发结尾的钩子** `s1940.hook`。只写**机制 + brief**。

## 必读

1. 合同 §0、§2.2、§2.5、§3.4 开头与 K05、§3.5（1940 主线节点：`s1940.wang_regime` `s1940.new_official` `s1940.sunfu_stance` `s1940.dossier_link` `s1940.hook`）、§4.1–§4.4、§4.7.1（person 与金色牌）、§4.9、§5.2–§5.3、§7.4.3、§10、§11.2、**§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §三.9（本心、口碑、风声）、§三.11（档案簿）、§四、§五（1940 三月；第三关主线：汪伪政权成立、新官上任、条子升档、孙府要你表态、档案簿关键碎片串起来；首发版本以这一关结尾，留一个往后的钩子）、§九.3、附录。
3. `docs/town/cards/src/era.json` 的 `notes`、`pawn[2]`（3 月 30 日汪伪国民政府在南京成立，伪维新政府并入；新官上任，摊派换了名目）、`launch[2]`。
4. K01、K03 已合入的人物牌与走向名表；例子集 person 牌。

## 要做的事

### A. `data/cards/era/1940/people.json`
- [ ] `persons` 块登记 `nf1940a`–`nf1940d`（`portrait.nf1940a` …、`dossier: true`、brief）。
- [ ] 老面孔在 1940：每人 2–4 张（`p.<人物>.1940.<slug>`），按前两关的走向、人物状态用条件分版本；新官上任后换了身份的人（例：马万利、胡二所在的名目变了）用 `person_state changed` 前后两种牌。
- [ ] 孙府相关（`sunlaoye` 孙德昌、`sunyoung` 孙富贵、`guanjia` 孙福）：表态、作保、借钱、要人情，后果写清对口碑/风声/本心/条子档位的影响。
- [ ] 新面孔各 1–2 张；合计约 40 张人物牌（含节点）。

### B. `data/cards/era/1940/story.json`
- [ ] 人物出面的节点（例 `s1940.sunfu_stance` 孙府要你表态、`s1940.dossier_link` 把关键碎片串起来的那个人、`s1940.hook`）：`gold: true`、`weight: 0` + `schedule`（`stage_day` ≤ 30）、`on_expire` 有 `story … ignored` + 至少一个 `dossier_gap`（V13）；选项用 `story` 记走向。
- [ ] **首发结尾的钩子** `s1940.hook`：一张人物牌（金色），排在这一关后段；它的选项只记 `story` 走向、补碎片、设旗标——**不自己写 `game_over`**（结尾怎么收由 G02 按 `g02.ending.*` 做；brief 里写清钩子指向的后续：哪条线、留下什么悬念、哪块碎片）。
- [ ] 事件形状的节点（`s1940.wang_regime` 汪伪政权成立、`s1940.new_official` 新官上任）归 K06——PR 里对分工。
- [ ] 同一 `stage_day` 最多一张金色牌；列“节点 → 走向名 → 后续条件”表。

### C. 标签、界面键
- [ ] `data/cards/tags/K05.json`、`data/cards/ui_keys/K05.json`（`k05.reason.*` `k05.notice.*`）。
- [ ] 每张：`tags` 至少一个 `omen_*`；`art: "portrait.<人物>"`；`brief`；`_provenance: {"by": "ai", "task": "K05", "date": "<提交当天>"}`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **个别人记仇**：打烊时还没接的客人会走掉（合同 §7.4.7：`kind: "leave"`）。大多数人走了就走了，**不写**；少数会记仇的人物牌写 `effects.on_expire`（例：`{"op": "flag", "key": "grudge_<人物>"}`、`{"op": "rep", "delta": -1}`、`{"op": "counter", "key": "snub_<人物>", "delta": 1}`、`person_state`），后续的牌用条件读旗标/计数器走不同的路；brief 里一句话写明“没接他会怎样”。写了非空 `on_expire` 的牌，A 要写一句正文 `outcomes.ignored`（打烊确认清单里那一句），K15 的待写清单会列出来。在 PR 里列出哪些人记仇、记仇的后果。
- [ ] **金色牌**照旧（V13：`on_expire` 有 `story … ignored` + `dossier_gap`）；它在打烊清单里单独一行（`gold_leave`），正文 `outcomes.ignored` 由 A 写“不理他他就走了”那一句。
- [ ] 来赎的人（`intent: "redeem"`）没接：他走了，当票照旧，之后还可能再来——不用写 `on_expire`。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

数据卡共用的写法：

- 演出块的格式、站位、道具位、效果、拍子见合同 §4.7.24；默认演法见 §7.11.4——**默认够用的牌不写**。
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K05] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K05→K12`。
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

- [ ] **同 K01**：所有 `gold: true` 的牌写演出块——`intro` ≥ 2 拍，每个选项一组 `after.<选项 id>`（≥ 1 拍；没有选项、是当/卖/赎来意的金色牌，写 `after.accept` 和 `after.leave` 各一组）；需要换背景或站门口的写 `set` / `cast`（例：后门来的 `set: "candle"`、站门口没进柜台的 `at: "door"`）。
- [ ] **另挑 ≥ 6 张普通人物牌写演出块**：后门来的、带东西上柜台的（当品以外的道具，例 `prop.trunk` `prop.letter` `prop.ticket`；当品本身由 C04 用 `set_items` 摆）、有人陪着来的（陪同站 `companion`）。跨年变了身份的老面孔可以用 `companion` 带一个人来。
- [ ] 首发结尾的钩子 `s1940.hook` 是金色牌，也照第一条写（演出块只管怎么演，不写 `game_over`）。
- [ ] 过路客、来赎的默认演法够用，不用写。
- **数量**：金色牌全部 + ≥ 6 张。

**新增 / 作废的交付**

- 新增一个 PR `[K05] 演出块`：只动 `data/cards/era/1940/people.json` 和 `story.json`，G01 的 1.3 小 PR 合入后再提。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件。上文“新手指引”表里的旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`a.left.contacts` → `a.contacts`，备 `a.hero`），你的牌和测试不用为此改。

**测试与截图**

- `K05_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- 演出块 PR 里 `test_data.gd` 加：所有金色牌都有 `stage`、`intro` ≥ 2 拍、每个选项 id 都有 `after.<id>`（≥ 1 拍）；带 `stage` 的普通人物牌 ≥ 6 张；演出块里每个 `brief` 也过 brief 自查（引号里 ≤ 12 字、不含 `。！？`、伪字）。
- 截图：数据任务照旧不交。

**已经做了的哪些还有效**

- 全部有效；演出块另开 PR。

**日期**：演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提；跟着你的 1940 数据走，W2 strict 全绿之前合入。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/era/1940/people.json`、`data/cards/era/1940/story.json`
- 默认拥有：`scripts/tests/cards/K05/**`、`scripts/tests/cards/suites/K05.txt`、`data/cards/tags/K05.json`、`data/cards/ui_keys/K05.json`

## 不能做的事

1. **不写玩家最终内容**（正文字段、人写路径、brief 以外的中文、台词与引号对白）；名字只提议。
2. 不写结局文字，不在数据里直接结束游戏（`game_over` 归 G02 的首发结尾流程）。
3. 不改 K01/K03 的牌、K06 的事件、K08 的档案、`_examples/**`、`rules/**`。
4. 不写 `minigame`；不发明字段、op、条件；不自己加玩法。
5. 史实措辞：**汪伪国民政府**（1940 年 3 月 30 日在南京成立，伪维新政府并入）、新官上任、摊派换名目；不拷旧版 AI 文字。

## 接口

**用到**：§4.7.1；§5.2–§5.3；K01/K03 的走向名；预留 id。

**提供**：`nf1940a`–`d` 人物登记（K12、K08）；1940 节点金色牌与走向名；`s1940.hook`（G02 首发结尾判断用它的走向/旗标——PR 里写清旗标名）。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `gold` `gold_leave`（G02） | 1940 节点金色牌（含钩子） | `gd.gold_leave`（obj.brother_ledger · `a.endday.gold_leave`） |
| `dossier_gap`（G03） | 金色牌 `on_expire` | `gd.dossier_gap` |
| `person_state`（G03） | 换了身份、离开（`person_state changed/gone`） | `gd.person_state`（obj.brother_ledger · `a.contacts` 备 `a.hero`） |
| `game_over`（G02，首发结尾） | `s1940.hook` 的走向被 G02 用来收尾 | `gd.game_over`（"" · `a.over.retry`） |

- **指引验收（必须有测试）** `scripts/tests/cards/K05/test_guide_support.gd`：
  1. 每张金色牌过 V13；同一 `stage_day` 最多一张金色牌。
  2. `s1940.hook` 有一张牌，`gold: true`，没有 `game_over` 效果；它的选项至少设一个旗标或 `story` 走向（G02 收尾要读）。
  3. 跨年条件里引用的 `s1938.*` `s1939.*` 走向名在 K01/K03 数据里存在（不在的打印 `NOTE: dangling story …`，不算失败）。
- **W2**：K14 三关走查到首发结尾；`gd.game_over` 在结尾的局终面板上亮。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K05.txt`：

```
# K05 1940 三月人物牌、主线节点（docs/handoff_cards/K05_data-1940-people.md）
K05_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/era/1940/people.json,data/cards/era/1940/story.json,data/cards/tags/K05.json,data/cards/ui_keys/K05.json --name=K05_validate
K05_data|res://scripts/tests/cards/K05/test_data.gd|120|
K05_guide_support|res://scripts/tests/cards/K05/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K05_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：person 牌合计 ≥ 36（约 40）；`nf1940a`–`d` 各 ≥ 1；孙府三人在 1940 各 ≥ 1 张；人物出面的 1940 节点都有牌。
- [ ] 每张：id `p.<人物>.1940.<slug>`、`era: ["1940"]`、`_provenance.task == "K05"`、brief 非空、至少一个 `omen_*`、标签已声明；当/卖牌机制字段齐；有“来当”的主要人物有 1940 `redeem` 牌。
- [ ] 原因键、告示键 `k05.` 开头且已登记。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；“国民政府”前有“汪伪”、“维新政府/维持会/县政府”前有“伪”。
- [ ] 悬空引用报告（`NOTE: dangling <id>`）。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K05 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K05] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K05] 1940 老面孔、孙府与新面孔`；②`[K05] 1940 主线节点金色牌与首发结尾钩子`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表；节点 → 走向名表；钩子的旗标与指向；和 K06/G02 的分工；悬空引用；需要主创/编排决定的事；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 金色牌 V13、同一天最多一张；3. 钩子不直接结束游戏、旗标写清；4. 免 AI 声明与 brief 写法；5. 史实（汪伪国民政府、新官上任）；6. 抽 5 张读 brief 与机制。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量（老面孔 / 新面孔 / 孙府 / 金色牌） | |
| 节点 → 走向名表；钩子旗标 | |
| 新加的 id、标签、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
