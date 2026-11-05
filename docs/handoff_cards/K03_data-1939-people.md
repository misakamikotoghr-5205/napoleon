# K03 `data-1939-people` · 1939 腊月人物牌、主线节点

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K03 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K03: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 3**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default、`_schema/person.json`、例子集 | W0（已完成） |
| K01 | 1938 的主线节点**走向名**（你的条件 `{"story": ["s1938.<节点>", "<走向>"]}` 要用）、过路客原型与 `p.any.redeem` | W1（K01 先交走向名表，你可以先按它的 PR 写） |
| K04 | 1939 的事件节点（`s1939.gate_check` 城门盘查、`s1939.wu_price` 米行涨价这类事件形状的节点归 K04）——PR 里对分工 | W1（并行） |
| K08 | 档案碎片 `df.*`（含 1938→1939 的“一年后”碎片，归 K08） | W1（并行） |
| K09 / K11 / K12 | 留牌 `kp.*`、物品模板、头像占位 | W1（并行） |

- **波次**：W1 开发（不在 W1 完成条件里，但越早合越好）；W2：1939 数据 strict 全绿、按 K13 的 `[K13→K03]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6）、G06 平衡报告修数。

## 分支

`cards/K03-data-1939-people`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写第二关（1939 年腊月，年关）的人物牌骨架：老面孔跨年的变化（老了、穷了、走了、换了身份）、年关的来意（赎当、当衣过年的人挤满柜台）、新面孔 `nf1939a`–`nf1939d`、主线节点 `s1939.*` 里人物出面的那几张（主线人物在节点上是**金色角色牌**）。只写**机制 + brief**。

## 必读

1. 合同 §0、§2.2、§2.5、§3.4 开头与 K03、§3.5（人物、新面孔、1939 主线节点：`s1939.year_end` `s1939.gate_check` `s1939.brother_letter` `s1939.wangshan_whereabouts` `s1939.wu_price`）、§4.1–§4.4、§4.7.1（person 与金色牌例子）、§4.9（V01–V16、V28、V33、V34）、§5.2–§5.3（尤其条件 `story` `person_state` `flag` `ticket_open` `has_contact` `dossier_has`）、§7.4.3、§10、§11.2、**§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §三.1、§三.9–§三.11、§四（跳一年：满当、“一年后”、部分人脉离开或变了身份、新面孔）、§五（1939 腊月时局、第二关主线）、§九.3、附录。
3. `docs/town/cards/src/era.json` 的 `notes`、`pawn[1]`（1939 腊月：伪县政府、区公所取代维持会；日商控制茧行、米行；物价持续上涨，米、柴涨得最凶；城门设岗盘查；年关是当铺最忙的时候）、`launch[1]`。
4. K01 已合入的 `data/cards/era/1938/{people,story}.json`（老面孔是谁、1938 的走向名）；例子集 `data/cards/_examples/era/1938/people.json`。
5. 只读剧情事实：`data/cast.json`、`data/story/**`（旧文字不许拷）。

## 要做的事

### A. `data/cards/era/1939/people.json`
- [ ] `persons` 块登记新面孔 `nf1939a`–`nf1939d`（`portrait.nf1939a` …、`dossier: true`、brief）。
- [ ] 老面孔跨年：16 个主要人物里 1939 仍在场的，每人 2–4 张（`p.<人物>.1939.<slug>`）。用条件区分 1938 的结果：例 `{"story": ["s1938.wangshan", "ignored"]}`、`{"person_state": ["linsao", "gone"]}`、`{"flag": "…"}`——同一个人可以有“1938 帮过他”和“1938 没理他”两个版本的牌。哥哥已离家（只在主线的信里出现，那是节点牌）。
- [ ] 年关来意为主：来赎当（`intent: "redeem"`，`conditions` 用 `ticket_open`）、当衣过年（`intent: "pawn"`，`item` 用 `clothing.*`）、年货买卖；`asking` `floor` `patience_min` `impatience` 都写区间【待调】。
- [ ] 新面孔各 1–2 张。
- [ ] 合计约 40 张人物牌（含节点牌）。

### B. `data/cards/era/1939/story.json`
- [ ] 5 个节点（§3.5）里**人物出面的**：例 `s1939.year_end`（年关赎当、当衣过年的主线人物）、`s1939.brother_letter`（哥哥的第一封信——送信的是何启明 `postman`，信本身可以是 K08 的 `kind: "letter"` 消息牌；在 PR 里和 K08 对）、`s1939.wangshan_whereabouts`。事件形状的（`s1939.gate_check`、`s1939.wu_price` 若是事件）归 K04——PR 里对分工。
- [ ] 人物节点牌 `gold: true`、`weight: 0` + `schedule`（`stage_day` ≤ 30）；`on_expire` 必须有 `story … ignored`（或别的“没理他”走向名）和至少一个 `dossier_gap`（V13）；选项用 `story` 记走向；在 PR 里列“节点 → 走向名 → 后续条件”表（K05 跨年要用）。
- [ ] 第二关不是脚本日（`scripted_days` 只有第一关第 1–3 天），日程可以排任何一天；但同一天最多一张金色牌（两张金色牌同一天会互相挤）。

### C. 标签、界面键
- [ ] `data/cards/tags/K03.json`、`data/cards/ui_keys/K03.json`（`k03.reason.*` `k03.notice.*`，只有 brief）。
- [ ] 每张：`tags` 至少一个 `omen_*`；`art: "portrait.<人物>"`；`brief`；`_provenance: {"by": "ai", "task": "K03", "date": "<提交当天>"}`。

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
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K03] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K03→K12`。
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
- [ ] 过路客、来赎的默认演法够用，不用写。
- **数量**：金色牌全部 + ≥ 6 张。

**新增 / 作废的交付**

- 新增一个 PR `[K03] 演出块`：只动 `data/cards/era/1939/people.json` 和 `story.json`，G01 的 1.3 小 PR 合入后再提。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件。上文“新手指引”表里的旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`a.left.contacts` → `a.contacts`，备 `a.hero`），你的牌和测试不用为此改。

**测试与截图**

- `K03_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- 演出块 PR 里 `test_data.gd` 加：所有金色牌都有 `stage`、`intro` ≥ 2 拍、每个选项 id 都有 `after.<id>`（≥ 1 拍）；带 `stage` 的普通人物牌 ≥ 6 张；演出块里每个 `brief` 也过 brief 自查（引号里 ≤ 12 字、不含 `。！？`、伪字）。
- 截图：数据任务照旧不交。

**已经做了的哪些还有效**

- 全部有效；演出块另开 PR。

**日期**：演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提；跟着你的 1939 数据走，W2 strict 全绿之前合入。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/era/1939/people.json`、`data/cards/era/1939/story.json`
- 默认拥有：`scripts/tests/cards/K03/**`、`scripts/tests/cards/suites/K03.txt`、`data/cards/tags/K03.json`、`data/cards/ui_keys/K03.json`

## 不能做的事

1. **不写玩家最终内容**：不写正文字段（V04）；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；brief 以外不出现中文（V05）；brief 不写台词、不写引号里的对白；名字只提议。
2. 不改 K01 的 1938 牌（跨年变化写成你自己的 1939 牌 + 条件）；不改 K08 的档案（“一年后”碎片归 K08）；不改 `_examples/**`、`rules/**`（`stages.json` 的公历日期由 K13 核对后报给 G02）。
3. 不写 `minigame`（V33）；不发明字段、op、条件；不自己加玩法。
4. 史实措辞：1939 年是伪县政府、区公所；日商控制茧行、米行（brief 里写明依据）；不拷旧版 AI 文字。

## 接口

**用到**：§4.7.1 person 格式；§5.2–§5.3（条件 `story` `person_state` `flag` `ticket_open` `dossier_has` 等）；K01 的走向名；预留 id。

**提供**：`nf1939a`–`d` 人物登记（K12 头像、K08 档案页）；1939 节点的金色牌与走向名（K05 跨年引用）；主要人物的 1939 `redeem` 牌（G04 来赎）。

## 新手指引

- **锚点**：数据任务不登记锚点。**first-time**：不发。第二关开始时，大部分机制在第一关已经教过；你的牌主要让这些“事件型”机制第一次出现（如果第一关里没出现过）：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `redeem`（G04） | 年关来赎当的牌（年关是赎当最多的时候） | `gd.redeem`（obj.brother_ledger · `a.counter.redeem`） |
| `gold` `gold_leave`（G02） | 1939 节点的金色牌 | `gd.gold_leave`（obj.brother_ledger · `a.endday.gold_leave`） |
| `dossier_gap`（G03） | 金色牌 `on_expire` | `gd.dossier_gap`（obj.brother_ledger · `a.dossier.gap`） |
| `person_state`（G03） | 老面孔走了、换了身份（效果 `person_state`） | `gd.person_state`（obj.brother_ledger · `a.contacts` 备 `a.hero`） |

- **指引验收（必须有测试）** `scripts/tests/cards/K03/test_guide_support.gd`：
  1. 每张金色牌过 V13（`on_expire` 有 `story` + `dossier_gap`、`keepable` 不为 true、有 `story_node`、`schedule.stage_day` ≤ 30）。
  2. 同一 `stage_day` 最多一张金色牌。
  3. 至少 4 张 `intent: "redeem"` 的主要人物牌（年关赎当，支持 `gd.redeem`）。
  4. 跨年条件里引用的 `s1938.*` 走向名都在 K01 的数据里出现过（不在的打印 `NOTE: dangling story <节点>:<走向>`，不算失败，贴进 PR）。
- **W2**：K14 用真引擎走完三关时，第二关的金色牌与来赎会让上面的步骤亮。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K03.txt`：

```
# K03 1939 腊月人物牌、主线节点（docs/handoff_cards/K03_data-1939-people.md）
K03_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/era/1939/people.json,data/cards/era/1939/story.json,data/cards/tags/K03.json,data/cards/ui_keys/K03.json --name=K03_validate
K03_data|res://scripts/tests/cards/K03/test_data.gd|120|
K03_guide_support|res://scripts/tests/cards/K03/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K03_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：person 牌合计 ≥ 36（约 40）；新面孔 `nf1939a`–`d` 各 ≥ 1；人物出面的 1939 节点都有牌；凡是有 1939 “来当”牌的主要人物都有 1939 `redeem` 牌。
- [ ] 每张：id `p.<人物>.1939.<slug>`、`era: ["1939"]`、`_provenance.task == "K03"`、brief 非空、至少一个 `omen_*`、标签已声明；当/卖牌有 `item` `asking` `floor` `patience_min`。
- [ ] 原因键、告示键 `k03.` 开头且已登记。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；“县政府/区公所/维持会”前有“伪”。
- [ ] 悬空引用报告（`NOTE: dangling <id>`，不算失败）。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K03 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K03] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K03] 1939 老面孔跨年与年关来意`；②`[K03] 1939 新面孔与主线节点金色牌`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表；跨年变化表（人物 → 1938 结果 → 1939 的牌）；节点 → 走向名表；和 K04/K08 的分工；悬空引用；需要主创/编排决定的事；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 金色牌 V13、同一天最多一张；3. 跨年条件引用的走向名真实存在；4. 年关来意占比（赎当、当衣过年）；5. 免 AI 声明与 brief 写法；6. 史实（伪县政府、物价、城门盘查）；7. 抽 5 张读 brief 与机制。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量（老面孔 / 新面孔 / 金色牌 / 来赎） | |
| 跨年变化表、节点 → 走向名表 | |
| 新加的 id、标签、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
