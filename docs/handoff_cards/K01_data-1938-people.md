# K01 `data-1938-people` · 1938 人物牌、主线节点（含金色牌）、过路客

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K01 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K01: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 1**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default 模式（V01–V08、V10、V13–V15、V28、V33 等“错”的规则）、`_schema/person.json`、例子集 `data/cards/_examples/era/{1938,common}/*.json`、`tags/W0.json`（`omen_*`） | W0（已完成） |
| K08 | 你在效果里引用的档案碎片 `df.*`、档案页 `dp.*`（`dossier` / `dossier_gap`）——**悬空引用允许**，列在 PR 里 | W1（并行） |
| K09 | `kp.brother_note`（哥哥告别“听他交代完”给的留牌）、`kp.*` 其他留牌 | W1（并行） |
| K11 | 来当/来卖的物品模板（`templates_extra.json` 的新模板）；用 `data/town/item_templates.json` 已有的 28 个变体不需要等 | W1（并行） |
| K12 | 新面孔、新过路客原型、算命先生的占位头像（`portrait.<id>`）——你在 `persons` 块里写 id，K12 生成 | W1（并行） |
| K16 | 教学日的牌（第 1–3、5–7 天）是 K16 的 `tutorial.json`；**K16 的指引步骤用 `suanming` 当教的人，校验 V31 要求它已登记——你的 `passersby.json` 要尽早合入** | W1（K16 在你之后合） |

- **波次**：W1。**W1 完成条件之一**：K01 合入，且 1938 数据 strict 校验全绿（允许的悬空引用清单为空，需要 K08/K09/K11 也合入后由你补齐引用）。
- **W2**：K13 审读你的数据，开 `[K13→K01]` issue（附审读报告与逐条建议），**你在自己的分支改**、在 PR 里逐条回应（K13 不改你的文件，合同 §2.6）；G06 用真数据出平衡报告；你按报告与审读意见修数。

## 分支

`cards/K01-data-1938-people`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641` 或之后的最新提交）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上，不留合并提交。

## 目标

写 1938 年三月这一关的人物牌骨架：16 个主要人物各 2–4 种来意、7 个主线节点里人物的那几张（主线人物在节点上是**金色角色牌**：当天必须处理，不理他就走，主线按“没理他”走、档案页留缺口）、4 个新面孔、8 种过路客原型、系统牌 `p.any.redeem`、主线当票 `tk.1938.de196`，并在 `passersby.json` 里登记算命先生 `suanming`（新手指引里教求签测字的人）。只写**机制 + brief**；名字、台词、正文全由人（A）写。

## 必读

1. 合同 §0（红线 1、2、6、8）、§2.2、§2.5（标签与界面键文件；**`omen_*` 封闭家族**；原因键用自己的 `k01.*`）、§3.4 开头的“数据任务共同要求”与 K01、§3.5（**预留 id 全表**：人物、新面孔、过路客、主线节点、当票、系统牌）、§4.1–§4.4（文件信封、id 规则、公共字段、格子/检定/选项/日程/效果钩子）、§4.5（正文覆盖层：你**不写**，但要知道 A 会按你的 id 写哪些字段）、§4.7.1（person：`intent` `item` `want` `asking` `floor` `patience_min` `impatience` `term_days` `minigame_hint` `choices`；**金色牌的例子**）、§4.7.16（pawn_ticket）、§4.9（V01–V16、V28、V33、V34）、§4.10、§5.2–§5.3（效果与条件 op）、§7.4.3（来意 → 面板）、§10（金色角色牌的实现）、§7.10.10–§7.10.11（新手指引节奏表与教学日）、§11.2（brief 的写法）、§12.1–§12.2、§13–§14、**§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §二、§三.1（柜台）、§三.9–§三.11、§五（1938 时局与首发主线）、§九.3（金色角色牌）、§九.4、附录“措辞与史实要求”、文末“实现时的理解”第 1、13、15 条。
3. `docs/town/cards/src/era.json` 的 `notes`（伪字、年份写法）、`launch[0]`（第一关主线）、`pawn[0]`（1938 时局）。
4. 例子集：`data/cards/_examples/era/1938/{people,story}.json`、`data/cards/_examples/era/common/passersby.json`（格式照它们写，id 不要照抄例子集的 slug 以外的东西——例子集和真数据分两套读，同 id 不冲突，§4.10）。
5. 只读了解剧情事实（**旧文字是 AI 写的，一个句子也不许拷进 brief**）：`data/cast.json`（16 个主要人物与关系 `edges`）、`data/story/**`、`data/sessions/**`、`docs/town/DESIGN_v04_town.md`；物品模板 `data/town/item_templates.json`（类别与变体 id）。
6. W0 代码：`scripts/cards/core/validate_main.gd`（命令行）、`scripts/cards/core/card_validator.gd`（你会碰到的规则）、`scripts/tests/cards/lib/card_t.gd`（测试模板）、`scripts/tests/cards/suites/W0.txt`（清单格式）。

## 要做的事

### A. `data/cards/era/common/passersby.json`（**先交，单独一个小 PR**）
- [ ] `_meta`：`{"owner": "K01", "schema": 1, "brief": "…"}`。
- [ ] `persons` 块登记 9 个人物：过路客原型 `stranger_refugee` `stranger_peddler` `stranger_collector` `stranger_fence`（已有旧立绘，头像 id `portrait.<id>`）、`stranger_waixiang`（外乡人）`stranger_boatman` `stranger_student` `stranger_widow`（新，头像由 K12 出占位），以及**算命先生 `suanming`**（`portrait.suanming`，`dossier: false`）。每个写 `portrait`、`dossier`、`brief`（谁、什么身份、名字由 A 定）。
- [ ] 8 种原型各 1–2 张人物牌，`era: ["*"]`、`weight > 0`，来意覆盖当/卖/买/求助/打听（外乡人可以带柜台上的额外选项，例“白给他几个钱”，`choices` → `card.choose`）。
- [ ] 系统牌 `p.any.redeem`：`intent: "redeem"`、`weight: 0`、`person` 用一个过路客原型（例子集用 `stranger_refugee`）、带一个 `omen_*`；brief 写清“G04 按当票生成来赎当的过路人，主要人物用自己的 redeem 牌”。

### B. `data/cards/era/1938/people.json`
- [ ] `persons` 块登记新面孔 `nf1938a`–`nf1938d`（`portrait.nf1938a` …、`dossier: true`、brief：身份、年纪、和铺子的关系、名字提议由 A 定稿）。
- [ ] 16 个主要人物（`data/cast.json` 的 `brother chen xiaoding zhang wangshan li linsao zhouma zhao sunyoung ma hu2 sunlaoye guanjia wu postman`）在 1938 的人物牌：除哥哥外每人 2–4 种来意（`pawn` `sell` `buy` `redeem` `help` `ask`），新面孔各 1–2 张；合计（含 A 节的过路客）约 45 张。
- [ ] 每张：`id` = `p.<人物>.1938.<slug>`；`type: "person"`；`person`；`era: ["1938"]`；`weight`（随机牌 > 0；只靠日程发的 = 0 + `schedule`）；`tags` 至少一个 `omen_*`（其余标签在 `data/cards/tags/K01.json` 声明）；`intent`；`art: "portrait.<人物>"`；`brief`；`_provenance: {"by": "ai", "task": "K01", "date": "<提交当天>"}`。
- [ ] 按来意的机制字段：当/卖 `item`（`{"template": "<cat>.<variant>"}` 或 `{"cat": "<cat>"}`，模板来自 `data/town/item_templates.json`，新模板等 K11）+ `asking.pct` 区间 + `floor.pct` 区间 + `patience_min` 区间 + `impatience`（`leave`/`raise`）+ 可选 `term_days`；买 `want: {"cats": […], "budget_pct": [lo, hi]}`；赎：凡是有“来当”牌的主要人物都要有自己的 `intent: "redeem"` 牌（`conditions: {"ticket_open": "<人物>"}`）；求助/打听：`choices`（可带 `check` 和格子）或 `slots` + `check`。数都是整数【待调】起步值。
- [ ] 不写 `minigame`（V33：只有教学牌能固定小游戏）；可以写 `minigame_hint`（不约束）。
- [ ] 效果：`on_accept` `on_refuse` `on_leave` 里用 `dossier`（补碎片）、`conscience`、`rep`、`heat`、`person_state`、`story`、`flag`；`reason` 用 `k01.reason.*`、告示用 `k01.notice.*`（登记在 `data/cards/ui_keys/K01.json`，只有键和 brief）。
- [ ] 条件：`person_state`、`story`、`flag`、`day_gte`、`ticket_open` 等（§5.3），只用合同里有的 op。

### C. `data/cards/era/1938/story.json`（主线节点）
- [ ] 7 个节点（§3.5）：`s1938.brother_farewell` `s1938.ticket196` `s1938.wangshan` `s1938.zhao_borrow` `s1938.linsao_term` `s1938.ma_levy` `s1938.police_open`。**人物出面的节点**由你写那张人物牌，`story_node` 填节点 id，**`gold: true`**（v1.1：主线人物在主线节点上以金色牌框出现），`weight: 0` + `schedule`（`stage_day` ≤ 30，V28）。`s1938.police_open`（月底伪维新政府成立、警察所开门）是事件，归 K02 的 `events.json`——你在 PR 里和 K02 对一下：哪些节点是人物牌（你）、哪些是事件牌（K02）。
- [ ] **每张金色牌**：`intent: "story"`（只有选项）或当/卖/赎等来意；`keepable` 不写或写 `false`；`effects.on_expire` 里**必须**有 `{"op": "story", "node": "<同一节点>", "outcome": "ignored"}`（或别的“没理他”走向名）和至少一个 `{"op": "dossier_gap", "frag": "df.<人物>.1938.<slug>"}`（V13）；各选项用 `story` 记走向（走向名 `[a-z0-9_]`），后续的牌用条件 `{"story": ["<节点>", "<走向>"]}` 走不同的路。
- [ ] **哥哥告别（教学要用，合同 §3.4 K01 确认）**：`p.brother.1938.farewell`：`gold: true`、`story_node: "s1938.brother_farewell"`、`schedule: {"stage_day": 2, "order": 1}`、**第一个选项**是“听他交代完”（id `listen`），效果含 `{"op": "add_card", "card": "kp.brother_note", "to": "kept"}`（第 2 天的留牌指引靠它）和 `dossier`；第二个选项“和他争”（`argue`）；`on_expire` = `story … ignored` + `dossier_gap df.brother.1938.farewell`。照合同 §4.7.1 的例子写，碎片 id 和 K08 对齐。
- [ ] 主线当票 `tk.1938.de196`（§4.7.16，`type: "pawn_ticket"`）：`number: 196`、`item_template: "documents.receipt"`、`foreign: true`、`keepable: true`、`must_resolve: false`、`story_node: "s1938.ticket196"`、`minigame: "fragments"`、`weight: 0` + `schedule`（按主线日程发到手牌）、`art: "illus.tk.de196"`。
- [ ] **日程约束（为了新手指引的第 1–3 天和种子无关）**：第一关第 1–3 天是脚本日（`deal.json.scripted_days`），只发日程上的牌。你的牌里**只有 `p.brother.1938.farewell` 排在第 2 天**；其他任何日程牌 `stage_day` ≥ 4，且尽量不和 K16 的教学牌（第 5、6、7 天）挤同一天。

### D. 标签、界面键
- [ ] `data/cards/tags/K01.json`：你用到的、`tags/W0.json` 里没有的标签（`{"_meta": {"owner": "K01", "schema": 1, "_provenance": {…}}, "tags": {"boat": {"brief": "…"}}}`），每个一句 brief。
- [ ] `data/cards/ui_keys/K01.json`：`k01.reason.*`、`k01.notice.*`（键以 `k01.` 开头，只有 `brief`）。

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
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K01] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K01→K12`。
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

- [ ] **所有 `gold: true` 的牌写演出块**：`intro` ≥ 2 拍，每个选项一组 `after.<选项 id>`（≥ 1 拍；没有选项、是当/卖/赎来意的金色牌，写 `after.accept` 和 `after.leave` 各一组）；需要换背景或站门口的写 `set` / `cast`（例：王山走后门 → `set: "candle"`；哥哥告别站 `door`、带 `prop.trunk`、`fx: ["predawn"]`，照合同 §4.7.24 的例子）。
- [ ] **哥哥告别 `p.brother.1938.farewell`** 直接照合同 §4.7.24 的第二个例子写：哥哥站 `door`；`prop.trunk` 在 `door_side`；`fx: ["predawn"]`；`intro` 三拍（旁白 `body`、哥哥 `lines.greet`、哥哥 `lines.charge`）；`after.listen` 两拍、`after.argue` 两拍（`argue` 第一拍是 `who: "me"`）。选项 id 仍是 `listen` `argue`（第 2 天的指引靠它）。
- [ ] **另挑 ≥ 6 张普通人物牌写演出块**：后门来的（`set: "candle"`）、带东西上柜台的（这里的“东西”是当品以外的道具，例 `prop.trunk` `prop.letter` `prop.ticket`，摆 `counter_left` / `counter_right`；当品本身不用写，C04 用 `set_items` 摆物品图）、有人陪着来的（陪同站 `companion`，`who` 是登记过的人物；陪同开口的那拍 `who` 写他）。
- [ ] 过路客、`p.any.redeem` 不用写（默认演法：人走进门站到柜台前、开口、报价）。
- **数量**：金色牌全部 + ≥ 6 张。

**新增 / 作废的交付**

- 新增一个 PR `[K01] 演出块`：只动 `data/cards/era/1938/people.json` 和 `story.json`（`passersby.json` 不用动），G01 的 1.3 小 PR 合入后再提。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件。上文“新手指引”表里两个旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`a.left.kept` → `a.hand.kept`、`a.left.contacts` → `a.contacts`），你的牌和测试不用为此改。
- 哥哥告别在画面里：第 2 天它是手牌扇最左边的金色牌（`a.card.gold@{uid}`），打出后哥哥站在门口开口，“听他交代完 / 和他争”是对话框里的回话（`a.slots.choices` 1.3 起是第一句选项回话）；`gd.d2.gold → gd.choice → gd.d2.keep` 的顺序不变。

**测试与截图**

- `K01_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- 演出块 PR 里 `test_data.gd` 加：所有金色牌都有 `stage`、`intro` ≥ 2 拍、每个选项 id 都有 `after.<id>`（≥ 1 拍）；带 `stage` 的普通人物牌 ≥ 6 张；演出块里每个 `brief`（`cast`、`props`、拍子）也过上面的 brief 自查（引号里 ≤ 12 字、不含 `。！？`、伪字）。
- 截图：数据任务照旧不交（画面截图由 C 线、K14 出）。

**已经做了的哪些还有效**

- 全部有效（人物牌、主线节点、金色牌、过路客、当票、测试）；演出块另开 PR。

**日期**：演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提，**10-27** 前合入（1938 的演出块，见交接页检查点）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/era/1938/people.json`、`data/cards/era/1938/story.json`、`data/cards/era/common/passersby.json`
- 默认拥有：`scripts/tests/cards/K01/**`、`scripts/tests/cards/suites/K01.txt`、`data/cards/tags/K01.json`、`data/cards/ui_keys/K01.json`
- 及它们的 `.uid` / `.import`（如果 Godot 生成）。`git status` 里多出来的别人的文件、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. **不写玩家最终内容（红线 1）**：不写 `text` `title` `body` `label` `name` `lines` `desc` 这些正文字段（V04）；不建、不改 `data/cards/text/**`、`art/**`、`audio/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`。名字只在 brief 里“提议”，A 定稿。**brief 以外的任何字符串不许有中文**（V05）。
2. **brief 的写法**（§11.2）：干巴巴的设计说明——谁、什么事、有哪些选项、各自后果、史实依据（写明年份）。**不写成能直接拿去用的台词或文案，不写引号里的对白**（引号只用来标名称，例“德字第一九六号”）。
3. **不拷旧文字**：`data/story/**`、`data/sessions/**`、`data/cast.json` 的名字、`data/town/**` 的文字都是 AI 写的旧内容，只读来了解剧情事实。
4. **史实措辞**（红线 6）：日方扶植的政权一律加“伪”（伪维持会、伪维新政府、伪县政府）；brief 里也照写。
5. 不改别人的文件：`data/cards/_examples/**`（W0）、K02 的 `events.json` 等、K08 的档案、K09 的留牌、`data/cast.json`、`data/cards/rules/**`、`tags/W0.json`、`scripts/**`。要别人加东西：开 `[shared] K01→<任务号>: …` issue。
6. 不发明合同里没有的字段、效果 op、条件 op、来意、小游戏（新需求开 `[api]` issue）；不写 `minigame`（教学牌除外，教学牌归 K16）；不自己加玩法。
7. id 合入后不改名（存档里有）；用 §3.5 的预留 id，新加的 id 在 PR 里列出。

## 接口

**用到**：合同 §4.7.1 的 person 格式、§4.7.16 的 pawn_ticket 格式；§5.2 效果 op（`story` `dossier` `dossier_gap` `add_card` `conscience` `rep` `heat` `person_state` `flag` `money` `pay` `notice` `coin_check` `contact_gain` …）、§5.3 条件 op；预留 id（§3.5）；`omen_*` 标签（`tags/W0.json`）。

**提供（别的线按 id 引用你）**：
- 人物登记：`stranger_*`（8 个）、`suanming`、`nf1938a`–`nf1938d`（K12 出头像、K08 出档案页、K16 用 `suanming` 当教的人、C07 用 `portrait.suanming`）。
- 系统牌 `p.any.redeem`（G04 发）；金色牌 `p.brother.1938.farewell` 等（G02 的金色牌流程、C02 的金色牌框）；当票 `tk.1938.de196`（G04/C15 的拼碎片）。
- 主线节点走向名（`story` 条件里用）：在 PR 里列一张表“节点 → 走向名 → 后续牌的条件”，K03/K05 跨年会引用。
- 你引用、但归别人定义的 id（`df.*` `dp.*` `kp.*` 模板）：PR 的“悬空引用”一节逐个列出，给 K08/K09/K11 对照。

## 新手指引

- **锚点**：数据任务不登记锚点（锚点是界面部件的事，§7.10.4）。
- **first-time**：数据任务不发 first（引擎发，§7.10.6）；但你的牌决定下面这些机制**什么时候第一次出现**：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `gold`（G02） | `p.brother.1938.farewell`，第 2 天 | `gd.d2.gold`（brother · `a.card.gold@{uid}`） |
| `choice`（G03） | 同上（第一张带选项的牌） | `gd.choice`（brother · `a.slots.choices`） |
| `keep`（G01） | 同上，选“听他交代完”得 `kp.brother_note` | `gd.d2.keep`（brother · `a.card.keep@{uid}` 备 `a.hand.kept`） |
| `gold_leave`（G02） | 任何一张金色牌被放着不理到打烊 | `gd.gold_leave`（obj.brother_ledger · `a.endday.gold_leave`） |
| `dossier_gap`（G03） | 金色牌 `on_expire` 的 `dossier_gap` | `gd.dossier_gap`（obj.brother_ledger · `a.dossier.gap`） |
| `redeem`（G04） | 主要人物的 `redeem` 牌、`p.any.redeem` | `gd.redeem`（obj.brother_ledger · `a.counter.redeem`） |
| `mg.fragments`（G04） | `tk.1938.de196`（`minigame: "fragments"`） | `gd.mg.fragments`（obj.brother_ledger · `a.mg.fragments.board`） |
| `person_state`（G03） | 效果里的 `person_state` | `gd.person_state`（obj.brother_ledger · `a.contacts` 备 `a.hero`） |
| —（教的人登记） | `passersby.json` 的 `persons.suanming` | `gd.lot` `gd.cezi` 的 `teacher: "suanming"`（V31 要求已登记） |

- **指引验收（必须有测试）** `scripts/tests/cards/K01/test_guide_support.gd`（读真数据 `CardDB.load_all("res://data/cards", {})`，只断言你自己的文件）：
  1. `p.brother.1938.farewell` 存在：`gold == true`、`story_node == "s1938.brother_farewell"`、`schedule.stage_day == 2`、`weight == 0`、`choices[0].id == "listen"` 且它的 `effects` 里有 `add_card kp.brother_note to kept`；`on_expire` 有 `story`（outcome 非空）和 `dossier_gap`。
  2. `suanming` 在 `passersby.json` 的 `persons` 块里，带 `portrait: "portrait.suanming"`。
  3. 你的所有日程牌：除哥哥告别外 `stage_day` ≥ 4（第 1–3 天的指引测试与种子无关的前提）；所有金色牌都过 V13 的要求。
  4. `p.any.redeem` 存在、`weight == 0`、`intent == "redeem"`。
- **W2**：K14 用真引擎走第 1–3 天（`test_guide_d1_3.gd`），第 2 天的 `gd.d2.gold → gd.choice → gd.d2.keep` 靠你的哥哥告别牌按顺序亮；走查失败且原因在你的数据时，你修。
- **截图**：数据任务不交截图（步骤截图由 C16、K14 出）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K01.txt`：

```
# K01 1938 人物牌、主线节点、过路客（docs/handoff_cards/K01_data-1938-people.md）
K01_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/era/1938/people.json,data/cards/era/1938/story.json,data/cards/era/common/passersby.json,data/cards/tags/K01.json,data/cards/ui_keys/K01.json --name=K01_validate
K01_data|res://scripts/tests/cards/K01/test_data.gd|120|
K01_guide_support|res://scripts/tests/cards/K01/test_guide_support.gd|120|
```
（W2、G01 的 strict 规则合入后加一行同参数、`--mode=strict`、`--name=K01_validate_strict` 的；那时悬空引用必须为 0。）

**`test_data.gd` 必须断言**（模板见合同 §12.1，`T.new(self, "K01_data")`）：
- [ ] 数量：`people.json` + `passersby.json` 的 person 牌合计 ≥ 40；16 个主要人物里除 `brother` 外每人 1938 牌 ≥ 2；新面孔 `nf1938a`–`d` 各 ≥ 1；过路客 8 种原型各 ≥ 1；`story.json` 覆盖 §3.5 里除 `s1938.police_open` 以外的 6 个节点；`tk.1938.de196` 存在。
- [ ] 每张牌：id 前缀与类型对、`era` 对、`_provenance.task == "K01"` 且日期格式 `YYYY-MM-DD`、brief 非空、至少一个 `omen_*`（V34）、标签都在某个 `tags/*.json` 里声明（V09 的 strict 要求，提前自查）。
- [ ] 凡是 `intent: "pawn"` 的主要人物都有自己的 `redeem` 牌；当/卖牌都有 `item`、`asking`、`floor`、`patience_min`；买牌都有 `want.cats`。
- [ ] 原因键、告示键都以 `k01.` 开头且在 `ui_keys/K01.json` 里。
- [ ] brief 写法自查：引号（“” ‘’ 「」）里的内容 ≤ 12 个字、不含 `。！？`（不写对白）；brief 里出现“维持会/维新政府/县政府”时前面有“伪”。
- [ ] **悬空引用报告（不算失败）**：效果和条件里引用的 `df.*` `dp.*` `kp.*` `ct.*` 牌 id、物品模板，不在当前真数据里的，逐个打印 `NOTE: dangling <id>`——贴进 PR。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7 可执行文件>
CARDS_SUITES=K01 bash tools/run_card_tests.sh      # 先 --import，再跑真数据 default 校验，再跑你的清单
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；日志没有 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、没有退出泄漏；每个清单测试最后一行 `CARDS TEST PASS <名字>`；第 2 步“数据校验（default）”对全部真数据绿。

## 交付

- **PR 标题** `[K01] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议拆成：
  1. `[K01] 过路客原型、算命先生登记与 p.any.redeem`（**尽早合**，K16 在等 `suanming`）
  2. `[K01] 1938 主要人物与新面孔的人物牌`
  3. `[K01] 1938 主线节点：金色牌、哥哥告别、德字第一九六号当票`
- **PR 描述**按 `.github/pull_request_template.md` 每节填满，另外必须有：改动路径；`run_card_tests.sh` 与 `run_legacy_smoke.sh` 的最后 20 行；数量统计表（每个人物几张、每种来意几张、金色牌几张）；**节点 → 走向名 → 后续条件**表；新加的 id（§3.5 以外的）；新标签；悬空引用清单（`NOTE: dangling …` 原样贴）；和 K02 对过的“哪些节点是人物牌、哪些是事件牌”；需要主创/编排决定的事（例：哪些节点的人物用金色牌、`asking/floor` 的起步值）；全部完成时写“交付”。

## 审核（Claude 重点）

1. 越界：只动三个数据文件和默认拥有的四类路径。
2. 金色牌：每张都过 V13；`on_expire` 记“没理他”且留缺口；哥哥告别第 2 天、第一个选项 `listen` 给 `kp.brother_note`。
3. 第 1–3 天只有哥哥告别一张日程牌；所有日程 ≤ 30 天。
4. 免 AI 声明：没有正文字段、brief 以外无中文、brief 不是台词；名字只是提议。
5. 史实：伪字、1938 时局对得上（伪维持会管事、3 月 28 日伪维新政府成立）。
6. 抽 5 张牌读 brief 与机制是否对得上（来意、物品、后果）；数量达标；`omen_*` 齐。
7. 新手指引：`suanming` 已登记；哥哥告别的形状满足 `gd.d2.gold → gd.choice → gd.d2.keep`。

## 回报（执行者填写栏）

> 执行者**不要改本文件**。把下表填好贴在最后一个 PR 描述的“回报”一节。

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量（主要人物 / 新面孔 / 过路客 / 金色牌 / 当票） | |
| 节点 → 走向名表 | |
| 新加的 id、标签、界面键 | |
| 悬空引用（给 K08/K09/K11） | |
| 和 K02 的节点分工 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
