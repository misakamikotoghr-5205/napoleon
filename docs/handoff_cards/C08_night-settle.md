# C08 `night-settle` · 打烊确认、夜牌、日结

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C08 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C08: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 8**（在第 8 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C08`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。牌用 C02 的 `CardWidget`（W0 版能用）；“打烊 · 下一天”按钮在 C01，它发 `day.end {confirm: false}`，要确认时开你的 `end_day` 面板。1.3：夜里和日结的演出用 C04 的对话框 `CardDialogBox`、C02 的手牌扇（夜牌在扇里打）、W0 的 `CardStagePanel` / `CardStageScript`——开发时对着 W0 的桩（`CardIds.widget_scene()` 取），合并要等 C04 的对话框 PR（10-21）。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎（G02 的日循环与金色牌流程）的集成测试和 K16 步骤复测。

## 分支

`cards/C08-night-settle`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

一天的收尾三块：①**打烊确认**——按“打烊 · 下一天”时还有没处理的东西：一行一行列出打烊后会怎样（人写的话），金色牌那一行醒目（v1.1：不理他他就走了，主线按“没理他”走、档案簿留缺口）；玩家点“打烊”才 `day.end {confirm: true}`，点“回去看看”就回牌桌接着处理（主创 10-13：打烊永远可用、绝不卡住，节奏由玩家把握）；②**夜牌**——三张夜牌选一张，带两个选项的（回家吃饭）再选一项（1.3：打烊后是夜里的柜台，手牌扇里是夜牌和“睡了”，打出一张就是今晚做它）；③**日结**——一行一行~~显示~~（1.3：在对话框里说）当票还剩几天、留牌过期、条子剩几天、今天的钱进出、口碑/风声变了哪一档的**文字**、黄历照做的小好处、金色牌走了的那一行、打烊时按没理会结算的每一行；Space 一路继续到第二天早上。

## 必读

1. `docs/cards/DESIGN_cards.md` §一（一天怎么过、夜牌三选一、结算）、§九.3（金色角色牌，主创原话）、§九.4（第 1 天晚上教夜牌与日结）、**§九.5（打烊 · 下一天，主创 10-13 硬性规则）**。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2、§3.3 开头与 C08、§4.7.12（夜牌与 `choices`）、§7.4 与 **§7.4.7**（`day.end {confirm}` → `{step, items}`，要确认时 `must_resolve_pending`；查询 `day.end_preview`；EndRow 的 `kind` 与 `consequence_key`）、`night.choose {def, choice?}`、`settle.next` → `{next_phase}`）、§7.5（`night_offers`）、§7.4 查询 `settle_report`（`{lines:[{key, args}]}`）、§7.8（`end_day` `night` `settle` 面板；面板的“算了”与 `dismiss()`）、§10（金色牌的实现，第 5、6 条打烊流程）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/night/{end_day_confirm,night_panel,settle_panel}.gd`、`scenes/cards/night/*.tscn`（W0 桩）、`scripts/cards/ui/table/card_game_root.gd`（`_on_close_day` 开 `end_day` 的参数；夜、日结每天自动开一次）、`scripts/cards/mock/mock_scenario.gd`（`_end_day` `_end_preview` `_end_rows` `night.choose` `settle.next`）、`scripts/cards/mock/fixtures/{night,settle}.json`、`data/cards/_examples/common/night.json`。

## 要做的事

- [ ] **CardEndDayConfirm**（`end_day_confirm.gd`，`class_name CardEndDayConfirm`，kind `end_day`，`args = {step, items}`——C01 从 `day.end {confirm: false}` 的结果里带来；没有就 `query("day.end_preview")`）：
  - 标题与一句提醒（本任务的键 `c08.end.title` `c08.end.note`；教的人是账簿批注的口吻，由人写）；清单每一行：有 `uid` 的画小牌（`query("card", {uid})` → C02 `CardWidget`，`&"mini"`），旁边 `CardText.t(consequence_key, args)`（人写的“打烊后会怎样”）；`kind == "gold_leave"` 那一行醒目（金框 + `c08.gold.reminder`）；`kind == "wait"` 的行淡一些（`c08.end.wait`：明天接着算，不算损失）。整张清单登记锚点 `a.endday.blocked`，第一行金色牌登记 `a.endday.gold_leave`。
  - 两个按钮：“回去看看”（`c08.btn.back`）→ 关面板、**不发任何指令**；“打烊”（`c08.btn.confirm`）→ `send("day.end", {"confirm": true})`，只发一次，成功后关面板（引擎进夜里，C01 会开夜牌面板）。点一行 → `close_requested({"open_uid": uid})`（C01 宿主按那张牌的 `panel` 打开）。Esc = 回去看看。
  - `step` 不是 `end_day` 时（例：月初本月运势没转，一行 `auto_spin`）照样列出、照样确认。
  - 任何 uid / 空参数不许报错（`W0_skeleton` 会 `open({"uid": "c0002"})`）。
- [ ] **CardNightPanel**（`night_panel.gd`，`class_name CardNightPanel`，kind `night`）（10-13 作废，合同 1.3：夜牌的居中面板作废，改成 `extends CardStagePanel` 的夜里那一出，夜牌在 C02 的手牌扇里打——下面发的指令照旧，见下方“10-13 变更二”）：~~`view.night_offers` 三张夜牌并排（C02 `CardWidget` 手牌尺寸；夜牌只给了牌 id，CardView 要自己拼最小的 `{"uid": "", "def": <id>, "type": "night", "art": "illus." + <id>, "zone": "night"}`——合同缺口：`night_offers` 是裸 id，没有美术和选项，PR 里列出）~~（1.3：`night_offers` 的元素是 `{def, art, choices}`，最小 CardView 由 C02 的扇拼；W1 里照收裸字符串）；牌名、正文 `CardText.card(def, "title"/"body")`；选一张 → `send("night.choose", {"def": def})`；**带选项的夜牌**：`night_offers` 的一项~~如果是字典 `{def, choices:[{id}]}`（合同缺口的建议格式，夹具先这样给）~~（1.3：`choices` 是选项 id 的数组，不空就是带选项）选它后再选一项（1.3：选项是回话） → `send("night.choose", {def, choice})`，文字 `<def>#choices.<id>`；是裸 id 就当没有选项；**“算了”**：覆盖 `dismiss()`（关掉按钮、Esc）= `send("night.choose", {"def": ""})`（今晚不选，引擎进日结）；牢里过夜时 `night_offers` 为空，只显示“算了”（`c08.night.skip`）。
- [ ] **CardSettlePanel**（`settle_panel.gd`，`class_name CardSettlePanel`，kind `settle`）（10-13 作废，合同 1.3：日结的居中面板作废，改成 `extends CardStagePanel` 的演出，每行在对话框里说一句、回话“天亮了” = `settle.next`，见下方“10-13 变更二”）：`query("settle_report")` → `{lines:[{key, args}]}`，每行 `CardText.t(key, args)`（键归引擎各模块：当票、留牌、条子、钱、档位、黄历、金色牌走了 `g02.settle.gold_left`、打烊时按没理会结算的行——键就是清单里的 `consequence_key`，可能是 `<牌>#outcomes.ignored` 这种牌上的引用……）；一行一行出现（Tween，≤ 0.6 秒一段），Space/Enter 先补全所有行，再按一次 → `send("settle.next")` → 关面板（引擎进早上，C01 开下一天）。数字只出现在键的参数代入里（钱数、天数），口碑/风声只显示档位字。
- [ ] **autoplay_step()**：EndDayConfirm——发 `day.end {confirm: true}`（打烊永远能走）；NightPanel——选第一张，有选项选第一项；SettlePanel——`settle.next`。同一状态同一动作。保持 `W0_table_3days` 能走过第 1、2 天的夜和日结。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C08.json`（`c08.` 开头，键 + `brief`，`_meta._provenance`）：`c08.end.title` `c08.end.note` `c08.end.wait` `c08.btn.back` `c08.btn.confirm` `c08.gold.reminder` `c08.night.skip` ~~`c08.night.title` `c08.night.choose`~~ `c08.settle.title` ~~`c08.btn.next_day`~~（10-13 作废，合同 1.3：这三个不再用，换成 `c08.narr.night_open` `c08.reply.dawn`）。`brief` 只写这句话在哪儿、表达什么意思，不写成台词。
- [ ] **夹具**（`scripts/tests/cards/C08/fixtures/`，`_meta.owner = "C08"`）：`end_day_items.json`（清单各种 `kind` 各一行：`leave`（一行 `g02.end.leave`、一行记仇的 `<牌>#outcomes.ignored`）`ignore` `gold_leave` `pass` `wait`；`day.end {confirm: true}` 的回应把阶段改成 `night`、发对应的 `card_left`）、`end_day_gold.json`（只有金色牌一行；确认后发 `card_left(<uid>, "gold_left")`）、`end_day_prison.json`（牢房 `stay` 一行；另一份 `fail`，确认后进 `game_over`）、`night.json`（W0 的即可）、`night_choices.json`（回家吃饭是 `{def, choices}` 字典；1.3：照合同 §7.5 写成 `{"def", "art", "choices": [选项 id]}`）、`settle_lines.json`（七类行各一，含 `g02.settle.gold_left`）。夹具过 `t.no_leaks()`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- 上文的 CardEndDayConfirm、夜牌的“算了”、键、夹具、测试都已经按新规则改好；1.1 的“挡住 / 只剩金色牌两步确认”（`blocked` `gold_pending` `confirm_gold_leave`）作废。
- W0 已同步：`end_day_confirm.gd` 桩的 `autoplay_step()` 发 `day.end {confirm: true}`；`night_panel.gd` 桩覆盖了 `dismiss()`（今晚不选）；Mock 的 `day_full` / `night` / `street_prison` 夹具里有 `day.end_preview|{}` 查询和 `day.end`（`confirm` 真/假）的回应——你的夹具照这个格式写。
- 日结报告里多了“打烊时按没理会结算的行”（键 = 清单里的 `consequence_key`），显示时一律 `CardText.t`。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardEndDayConfirm**：仍是叠层，做法不变（清单行用 C02 的 `CardWidget` `&"mini"`）。
- [ ] **CardNightPanel 改成演出**（`extends CardStagePanel`，夜里由 C01 自动开）：开场说一句 `c08.narr.night_open`（narr）；手牌扇此时是夜牌 + “睡了”（C02 做）；`on_card_played(uid, def)` 接住：`def == ""` → `night.choose {def: ""}`；夜牌没有选项 → `night.choose {def}`；有选项（`night_offers` 元素的 `choices`）→ 先演这张夜牌（`CardStageScript.resolve` 用夜牌的最小 CardView：背景换演出块的 `set`，例：后门收货 `candle`、发电报 `post`），回话是它的选项（`<def>#choices.<id>`）→ `night.choose {def, choice}`；之后接 `after.done`。“算了” = `night.choose {def: ""}`（照旧）。锚点 `a.night.offers` 用 `rect_fn` 取手牌扇的外框（`CardAnchors.rect(&"a.hand")`）。
- [ ] **CardSettlePanel 改成演出**：`hand.set_away(true)`；背景是夜里的柜台（今晚演的夜牌换了背景就沿用它）；`query("settle_report")` 的每一行在对话框里说一句（sys 或 narr，`ref` = 行的 `key`、`args` 照给）；说完回话一句“天亮了”（`c08.reply.dawn` → `settle.next`）；收场时 `hand.set_away(false)`；锚点 `a.settle.lines` 用 `rect_fn` 取 `CardAnchors.rect(&"a.dialog")`。

**新增 / 作废的交付**

- 新增界面键 `c08.narr.night_open` `c08.reply.dawn`。
- **作废**：夜牌三选一的居中面板、日结的居中面板；`c08.night.title` `c08.night.choose` `c08.btn.next_day` 不再用。

**锚点、界面事件、要证明的步骤**

- 锚点不改名（`a.night.offers` 是夜里的手牌扇，`a.settle.lines` 是日结时的对话框）。
- `gd.d1.night` 的 `done_when` 多了 `ui:hand_played`（K16 改）。

**测试与截图**

- `C08_night` 改成：夜里扇里打一张夜牌 → `mock.sent` 有对的 `night.choose`；带选项的夜牌回话；“睡了”；Esc。
- `C08_settle` 改成：日结行都在对话框里、来自 CardText，回话“天亮了” → `settle.next`。
- 截图：确认清单（各种 kind）、夜里的柜台与夜牌扇、回家吃饭的两个选项回话、后门收货换烛光、日结说到一半、天亮各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 确认面板全部有效；夜牌与日结发的指令、自动一步、夹具都有效（`night_offers` 改成字典，1.2 的“裸 id 当没有选项”照收）。

**日期**：演出目标 **10-29**。

## 只能改这些文件

- `scenes/cards/night/**`、`scripts/cards/ui/night/**`
- 默认拥有：`scripts/tests/cards/C08/**`、`scripts/tests/cards/suites/C08.txt`、`data/cards/tags/C08.json`、`data/cards/ui_keys/C08.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（C01 的打烊按钮与宿主、C02 的牌、`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、旧代码）。
2. **不写最终内容**：金色牌的提醒、日结每一行、夜牌的字都由人写；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
3. 不写颜色字面量；图只经 `CardArt`。
4. 不露隐藏数值：日结不显示口碑/风声点数、本心、概率、`%`。
5. 不放规则：清单里有什么、每行会怎样、夜牌有哪些，全看引擎；面板打开时不发 `day.end`，只在玩家点“打烊”时发 `day.end {confirm: true}`；不替玩家确认。
6. 不用随机影响结果；不加冻结表以外的 `class_name`；不加 autoload/InputMap。
7. 不发 `first_time`；本任务没有 `ui_event` 要发。

## 接口

**用到**：指令 `day.end {confirm: true}`（只在玩家点“打烊”时）、`night.choose {def, choice?}`（`def: ""` = 今晚不选）、`settle.next` → `{next_phase}`；查询 `card {uid}`、`settle_report`、`day.end_preview`；视图 `night_offers`（1.3：元素是 `{def, art, choices}`）`hand` `phase`；1.3：`CardStagePanel`（`on_card_played` 接夜里打出的夜牌）`CardStageScript`（W0）、`CardDialogApi`（C04 的对话框）、`CardHandApi.set_away`（C02 的手牌扇；没合入时都用 W0 的桩）；总线 `view_changed` `card_left`（`gold_left`）`phase_changed`；C02 `CardWidget`；`CardText.card/ui`、`CardArt`、`CardTheme`、`CardAnchors`；C01 的 `close_requested({"open_uid"})` 约定。

**提供（冻结）**：`CardEndDayConfirm`、`CardNightPanel`、`CardSettlePanel`（`CardPanel` 接口；1.3 起后两个 `extends CardStagePanel`）；`CardNightPanel.dismiss()` 覆盖成“今晚不选”。

## 新手指引

- **必须登记的锚点**：`a.endday.blocked`（确认面板里的清单）`a.endday.gold_leave`（清单里金色牌那一行）`a.night.offers`（~~三张夜牌~~ 1.3：夜里的手牌扇，用 `CardAnchors.register(…, rect_fn)` 取扇的外框）`a.settle.lines`（~~日结的行~~ 1.3：日结时的对话框）。
- **必须发的 ui_event**：无（宿主发 `panel_opened`）。
- **first-time**：不发；依赖 `must_resolve` `gold_leave` `night` `settle`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.must`（第一次按打烊时手上还有要了断的牌，确认面板开着 → `a.endday.blocked`）、`gd.gold_leave`（第一次按打烊时金色牌还在 → `a.endday.gold_leave`）、`gd.d1.night`（第一次进夜里 → `a.night.offers`；1.3：`done_when` 多了 `ui:hand_played`）、`gd.d1.settle`（第一次日结 → `a.settle.lines`）。
- **测试做法**：开面板（夹具）或牌桌宿主 + `night` / `settle` 夹具；挂指引（`force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"night", {})` → `evaluate_now()` → `active_step() == "gd.d1.night"`；`night.choose` 成功（`cmd:night.choose`；1.3：或扇里打出夜牌 `ui:hand_played`）后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C08.txt`：

```
# C08 打烊、夜牌、日结（docs/handoff_cards/C08_night-settle.md）
C08_end_day|res://scripts/tests/cards/C08/test_end_day.gd|120|
C08_night|res://scripts/tests/cards/C08/test_night.gd|120|
C08_settle|res://scripts/tests/cards/C08/test_settle.gd|120|
C08_flow|res://scripts/tests/cards/C08/test_flow.gd|240|
C08_guide|res://scripts/tests/cards/C08/test_guide.gd|180|
```

| 测试 | 通过条件 |
|---|---|
| `test_end_day.gd` | 清单行数和 `kind` 对，每行文字来自 `CardText.t(consequence_key, args)`；点一行 → `close_requested` 的 result 是 `{"open_uid": uid}`；开面板时 `mock.sent` 里**没有** `day.end`，点“打烊”后恰好一条 `day.end {confirm: true}`；“回去看看”和 Esc 不发任何指令；金色牌那一行有 `a.endday.gold_leave` |
| `test_night.gd` | 三张夜牌显示（1.3：在手牌扇里，外加“睡了”）；选普通的（1.3：扇里打出）→ `night.choose {def}`；选回家吃饭 → 再选一项（1.3：回话）→ `night.choose {def, choice}`；裸 id 的夜牌当没有选项；关掉 / Esc → `night.choose {def: ""}`（1.3：打“睡了”也是）；`night_offers` 为空时只有“算了” |
| `test_settle.gd` | 每一行都来自 `CardText.ui(key, args)`（`t.all_text_from_cardtext()` 为空；1.3：行在对话框里说）；Space 先补全再 `settle.next`（1.3：说完后回话“天亮了” → `settle.next`）；没有 `%`、没有口碑/风声点数 |
| `test_flow.gd` | Mock 情景模式、种子 7，用牌桌宿主走到第 1 天晚上，之后**只按 Space/Enter**（用 `Input.parse_input_event` 送键；1.3：外加数字键——夜里选夜牌或“睡了”、日结里选“天亮了”那句回话）能一路走到第 2 天早上（`view.phase == "morning"`、`stage_day == 2`）；另一条：第 1 天一张牌都不处理，点“打烊 · 下一天”→ Enter 确认 → Space 一路 → 第 2 天早上 |
| `test_guide.gd` | 四个步骤按做法亮、完成；四个锚点 `t.anchor_ok()` |

另：`autoplay_step()` 能把每个夹具走完；夹具 `t.no_leaks()`。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：第 2 天不处理哥哥告别 → 按“打烊 · 下一天” → 清单里有他那一行 → 确认 → 日结里有金色牌走了那一行）；清单加一行 `C08_guide_k16|res://scripts/tests/cards/C08/test_guide.gd|180|--steps=k16 --name=C08_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C08 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C08/shot_night.gd -- --out=/tmp/shots/C08
  ```
- **截图**（不进清单）：打烊确认清单（各种行）、只有金色牌一行、牢房 stay / fail、~~夜牌三选一、回家吃饭的二选一、日结（行出了一半、全部）~~（10-13 作废，合同 1.3：夜里与日结的截图换成上方“10-13 变更二”的清单）各一张；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图；上传 PR 或提交到 `scripts/tests/cards/C08/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：面板居中 ≤ 1100×640（1.3：只有打烊确认这样；夜里和日结是演出）；~~夜牌 144×200 并排~~（1.3：夜牌在 C02 的手牌扇里）；金色牌一眼能认（C02 的金框）；日结行正文 16–18 号；“快动画”时日结行一次出完（~~读开关的接口没冻结，先开 `[shared]` issue、留 `fast_anim` 布尔、标 `# TODO(shared#<issue号>)`~~ 1.3：用冻结的静态读取 `CardSettings.fast_anim()`，合同 §7.8）；键盘：1/2/3 选夜牌（1.3：由 C01 的根转给手牌扇或回话）、Enter 确认（确认面板里 Enter = “打烊”）、Space 继续、Esc 关（= 那个面板的“算了”：确认面板 = 回去看看，夜牌面板 = 今晚不选）。

## 交付

- PR 标题 `[C08] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①打烊确认清单（含金色牌那一行）+ 测试；②夜牌、日结、Space 流程、截图（1.3：②换成夜里与日结的演出，等 C04 的对话框合入，10-29）；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；需要决定的事（~~`night_offers` 的格式~~ 1.3 已定为 `{def, art, choices}`）；性能数；“回报”。

## 审核（Claude 重点）

- 打烊确认：面板打开时不发 `day.end`，点“打烊”才发 `day.end {confirm: true}`、只发一次；“回去看看” / Esc 不发指令；每行文字来自 `consequence_key`。
- 日结每行都是正文键；没有数字化的口碑/风声、`%`。
- `open_uid` 约定与 C01 一致；Space 能一路走到第二天早上。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / 证明会亮的步骤 | |
| 新加的公开函数 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
