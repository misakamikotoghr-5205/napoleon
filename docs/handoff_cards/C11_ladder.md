# C11 `ladder` · 家当与抵押、钱不够、街头、牢房

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C11 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C11: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 11**（在第 11 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C11`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）；C03 的 `CardSlotWidget` / `CardCoinTossView`（牢房的格子与掷铜钱，先对着 W0 桩）。街头~~皮~~层嵌在 C01 的~~牌桌上~~画面上（C01 用你的冻结接口；1.3 起只有按钮和一句提示，背景由场景层换）；家当~~面板的入口在 C01 的右栏（C01 卡的默认做法）~~（1.3：右抽屉，入口是 C01 的右标签“家当”、柜台上的钱匣、HUD 上的钱）。1.3：演出用 C04 的对话框 `CardDialogBox`、C03 的柜台格子 `CardCounterChecks`、W0 的 `CardStagePanel` / `CardStageScript`——开发时对着 W0 的桩（`CardIds.widget_scene()` 取），合并要等 C04 的对话框 PR（10-21）。
- **波次（Wave）**：W1 开发并合入（W1 内合并在 C03 之后）；W2 补对真引擎（G06 的破产阶梯）的集成测试和 K16 步骤复测。

## 分支

`cards/C11-ladder`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

破产阶梯在界面上的四块：①**家当面板**（1.3：右抽屉）——五件家当，押出去能换多少钱、每月利息多少钱（钱数，不写百分比）、押了以后少什么本事、赎回；②**钱不够面板**——引擎要求时弹出：拿货抵 / 押家当 / 认了，三条路；③**街头~~皮~~层**——流落街头时~~盖在牌桌上的背景、~~提示、“赎回铺面”按钮（1.3：背景由 C01 的场景层换成街头）；④**牢房面板**（1.3：牢房那一出——牢房背景、格子在柜台上、托人疏通是回话）——牢房牌：放钱打点、人脉作保、留着的牌，掷铜钱；出不来由引擎切到局终，面板不自己判断。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.7（抵押、流落街头）、§三.8（被抓、打点、结局）、§九.4（第一次钱不够教抵押与家当、街头/牢房/打点第一次发生时教）。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2（背景 320×180 ×4）、§3.3 开头与 C11、§4.5（`estate#title/#body/#mortgaged`、`prison`/`street` 的正文字段）、§4.7.11（家当）、§4.7.13（街头）、§4.7.14（牢房）、§7.4（`estate.mortgage` `estate.redeem` → `{money}`、`short.resolve {source, by, item?, estate?}`、`street.redeem_shop`、`slot.*`）、§7.4.5（钱不够面板的参数）、§7.4.6（街头时发什么牌）、§7.5（EstateView `{id, status, money, interest_money}`、`mode`）、§7.8（`estates` `short` `prison` 面板、StreetOverlay 控件）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/ladder/{estate_panel,short_panel,prison_panel,street_overlay}.gd`、`scenes/cards/ladder/*.tscn`（W0 桩）、`scripts/cards/ui/slots/{slot_widget,coin_toss}.gd`（C03 冻结接口）、`scripts/cards/mock/mock_scenario.gd`（`estate.*` `short.resolve` `street.redeem_shop`、`setup_street_prison`）、`scripts/cards/mock/fixtures/street_prison.json`、`data/cards/_examples/common/{estates,prison,street}.json`。

## 要做的事

- [ ] **CardEstatePanel**（`estate_panel.gd`，`class_name CardEstatePanel`，kind `estates`）（1.3：呈现为右抽屉，里面那块 388×630，五件一列；内容照旧，见下方“10-13 变更二”）：`query("estates")`（Mock 返回 `{"estates": [EstateView]}`；合同写的是数组，包装键见缺口）或 `view.estates`；五行：图（`es.<id>` 的 `art`，64×48 ×2）、名 `es.<id>#title`、说明 `#body`、押了以后少什么本事 `#mortgaged`、状态字（`c11.status.<held|mortgaged|lost>`）、押出去能换的钱 `money` 与每月利息 `interest_money`（**钱数**，用带参数的键 `c11.money` / `c11.interest`，**不写百分比**）；按钮“押出去” → `send("estate.mortgage", {estate})`、“赎回来” → `send("estate.redeem", {estate})`；失败显示 `reason_key` 的正文（例：阶段不对、钱不够）。
- [ ] **CardShortPanel**（`short_panel.gd`，`class_name CardShortPanel`，kind `short`）：参数来自 `open(args)`（引擎 `request_panel("short", {amount, payee, source, options, goods, estates})`），没有就 `query("short")`；一句“还差多少”（`c11.short.amount`，参数 `{n}`；付给谁 `CardText.ui(payee)`）；三条路按 `options` 显示：**拿货抵**（`goods` 的 ItemView 小格，挑一件 → `send("short.resolve", {source, "by": "goods", item})`）、**押家当**（`estates` 里还没押的，挑一件 → `{source, "by": "estate", estate}`）、**认了**（→ `{source, "by": "default"}`，旁边一句后果说法的键，由人写）。**关面板 = 认了**：覆盖 `dismiss()` 发 `short.resolve {source, by: "default"}`（10-13：没有关不掉的面板，合同 §7.8）。
- [ ] **CardStreetOverlay**（`street_overlay.gd`，`class_name CardStreetOverlay`，冻结：`refresh(view)`、`signal redeem_shop_pressed`）：`view.mode == "street"` 时显示：~~背景 `bg.street`（320×180 ×4，铺在牌桌最底层之上、手牌和各栏之下——层次和 C01 商量好，PR 里写明）~~（10-13 作废，合同 1.3：背景由 C01 的场景层按 `stage.set == "street"` 换，你不画背景；层次是 §7.11.1 的第 7 层）、提示一句（`c11.street.hint`，1.3：放在按钮上方）、~~右下~~“赎回铺面”按钮（1.3：`STREET_REDEEM` (1020, 452, 210, 92)）→ `redeem_shop_pressed`（C01 发 `street.redeem_shop`）。整层除按钮外鼠标穿透。
- [ ] **CardPrisonPanel**（`prison_panel.gd`，`class_name CardPrisonPanel`，kind `prison`，`args.uid` 是牢房牌）（10-13 作废，合同 1.3：牢房面板的居中布局作废，改成 `extends CardStagePanel` 的牢房那一出——下面这些“和引擎说话”的做法照旧，见下方“10-13 变更二”）：~~背景 `bg.prison`~~（1.3：牢房背景由场景层按视图 `set == "prison"` 换）；牌名、正文（1.3：在对话框里说）；三个格子用 C03 的 `CardSlotWidget`（`query("slots", {uid})`：打点的钱、作保的人脉、留着的牌；1.3：`checks.show_checks(uid)`，格子在柜台上）→ `slot.place` / `slot.remove`；“N 枚铜钱，要 M 个正面”（照 C03，数字可显示）；“试一试”（1.3：回话“托人疏通” `c11.reply.try`）→ `send("slot.roll", {uid})` → `CardCoinTossView.play(faces, need)` → 结果正文 `outcomes.success/fail`；**成了**：引擎把牌处理掉，面板关；**不成**：只显示结果正文，然后关面板——**局终由引擎切 `game_over` 阶段，C01 开 C09 的局终面板；本面板不发 `game.*`，也不自己判断**。
- [ ] 四个面板/控件对任意 `args` 不报错（`W0_skeleton` 会 `open({"uid": "c0002"})`）。
- [ ] **autoplay_step()**：Estate——看一眼就关；Short——`options` 有 `goods` 且有货 → 拿第一件抵；否则有 `estate` → 押第一件；否则 `default`；Prison——没放东西时：收钱的格子放 40、有人脉放第一个人脉 → 掷 → 关。同一状态同一动作。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C11.json`（`c11.` 开头，键 + `brief`，`_meta._provenance`）：`c11.status.<held|mortgaged|lost>` `c11.money`（`{n}`）`c11.interest`（`{n}`）`c11.btn.mortgage` `c11.btn.redeem` `c11.short.amount`（`{n}`）`c11.short.<goods|estate|default>` `c11.short.default_note` `c11.street.hint` `c11.street.redeem` `c11.prison.try`（1.3：牢房里那句回话用 `c11.reply.try`）`c11.btn.close`。不再用 `w0.street.redeem`。
- [ ] **夹具**（`scripts/tests/cards/C11/fixtures/`，`_meta.owner = "C11"`）：`estates.json`（三件在、一件押着、一件没了）、`short_all.json`（三条路都能走）、`short_default_only.json`、`street.json`（`mode: street`，手上街头牌）、`prison.json`（可以用 W0 的 `street_prison`）、`prison_fail.json`（`slot.roll` 回 `success: false`，事件里有 `phase_changed(day, game_over)` 与 `game_over("prison")`）。夹具过 `t.no_leaks()`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **牢房**：没处理就在牢里多待一晚——第二天铺子关门、不发人物牌；连续 `ladder.json.prison.max_days`（起步 3【待调】）晚没出来，打烊时按打点失败结算（局终，可以从本关开头或续玩点重来）。牢房牌的 `days_left` = 还能在牢里待几晚：面板上用带参数的键（例 `c11.prison.days`，参数 `{n}`）显示；关面板就回牌桌，牌留在手上，牌桌上的“打烊 · 下一天”照样能按（打烊确认清单里牢房那一行是 `stay` 或 `fail`）。
- [ ] **钱不够**：关面板 = 认了（见上）；打烊时还没选，引擎也按认了结算（清单一行 `short`）。
- [ ] **街头**：街头皮不挡“打烊 · 下一天”按钮（和 C01 对好层次）；街头牌没处理的打烊时按没理会算。
- [ ] 夹具：`prison_stay.json`（`day.end {confirm: false}` 回清单，牢房一行 `stay`，`args {nights: 1, max: 3}`）、`prison_last_night.json`（一行 `fail`，确认后 `phase_changed(day, game_over)` 与 `game_over("prison")`）；测试断言面板显示的天数来自 `days_left`、关掉不发指令。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardEstatePanel 改成右抽屉**（kind `estates`，388×630）：五件家当一列（图、名、说明、押了少什么本事、状态字、押值与每月利息的钱数）、押出去/赎回来按钮；钱匣热点、HUD 的钱、右边标签“家当”都开它。
- [ ] **CardShortPanel**：仍是叠层，不变。
- [ ] **CardStreetOverlay**：街头时只有“赎回铺面”按钮（`STREET_REDEEM` (1020, 452, 210, 92)，`a.street.redeem`）和一句提示（`c11.street.hint`，放在按钮上方）；背景由场景层按 `stage.set == "street"` 换，你不画背景；整层除按钮外鼠标穿透。
- [ ] **CardPrisonPanel 改成演出**（`extends CardStagePanel`）：背景是牢房（视图 `set == "prison"`）；说 `#body`、还能在牢里待几晚（sys `c11.prison.days`，`{n}` = `days_left`）；回话“托人疏通”（`c11.reply.try`）→ `checks.show_checks(uid)`，格子在柜台上；锚点 `a.prison.slots` 用 `rect_fn` 取格子那一块；掷 → `slot.roll` → `checks.play_coins` → `after.success/fail`；不成只说结果，局终由引擎切（照旧）。

**新增 / 作废的交付**

- 新增界面键 `c11.reply.try` `c11.reply.later`。
- **作废**：街头“皮”的背景、牢房面板的居中布局、家当面板的居中布局。

**锚点、界面事件、要证明的步骤**

- 不改名（`a.estate.*` 在右抽屉里；`a.street.redeem` 在 `STREET_REDEEM`；`a.prison.slots` 是牢房那一出时柜台上的格子那一块）。
- `gd.mortgage` 多了备用锚点 `a.tab.estates`（C01 的）。

**测试与截图**

- 原有测试改用画面根。
- 截图：家当抽屉、钱不够叠层、街头画面（换背景 + 赎回按钮 + 一张街头牌在演）、牢房那一出（格子在柜台上、铜钱）、牢房天数各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 押/赎、三条路、赎回铺面、牢房的格子与掷、自动一步、“算了”、夹具全部有效；只换呈现。

**日期**：演出目标 **10-29**。

## 只能改这些文件

- `scenes/cards/ladder/**`、`scripts/cards/ui/ladder/**`
- 默认拥有：`scripts/tests/cards/C11/**`、`scripts/tests/cards/suites/C11.txt`、`data/cards/tags/C11.json`、`data/cards/ui_keys/C11.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（C01 的牌桌与~~右栏入口~~（1.3：标签、抽屉宿主与场景层）、C03 的格子与铜钱、C09 的局终、`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、旧代码）。
2. **不写最终内容**：家当的名字与说明、少什么本事、街头提示、牢房正文、后果说法都由人写；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
3. 不写颜色字面量；背景、图只经 `CardArt`。
4. **不露隐藏数值**：利息只给钱数，不写 `%`、月息率；不显示成功机会、风声点数、本心。
5. **不放规则**：能不能押、能不能赎、哪条路能走、牢房成没成、要不要局终，全看引擎。
6. 不用随机影响结果；不加冻结表以外的 `class_name`；不加 autoload/InputMap。
7. 不发 `first_time`；`slot_drop` 由复用的 SlotWidget 发。

## 接口

**用到**：视图 `mode` `estates` `money`；查询 `estates`、`short`、`slots {uid}`、`card {uid}`、`stock`；指令 `estate.mortgage {estate}` / `estate.redeem {estate}` → `{money}`、`short.resolve {source, by, item?, estate?}`、`slot.place` `slot.remove` `slot.roll`；总线 `request_panel`（`short`、`prison`）`coins_tossed` `phase_changed` `game_over` `view_changed`；C03 `CardSlotWidget` `CardCoinTossView`；`CardText.card/ui`、`CardArt`、`CardTheme`、`CardAnchors`；1.3：`CardStagePanel` `CardStageScript`（W0）、`CardDialogApi`（C04 的对话框）、`CardChecksApi`（C03 的柜台格子；没合入时都用 W0 的桩）、`CardLayout.STREET_REDEEM`、视图 `stage.set`。

**提供（冻结）**：`CardEstatePanel`（1.3：呈现为右抽屉）、`CardShortPanel`、`CardPrisonPanel`（1.3 起 `extends CardStagePanel`）（`CardPanel` 接口）；`CardStreetOverlay`（`refresh` `redeem_shop_pressed`）。新增（PR 列出）：`dismiss()` 覆盖（`short`：认了）。

## 新手指引

- **必须登记的锚点**（名字不变，1.3 位置变了）：`a.estate.list`（五件家当那一列；1.3：右抽屉里）`a.estate.mortgage`（第一件能押的“押出去”按钮）`a.short.options`（三条路那一排）`a.street.redeem`（“赎回铺面”按钮；1.3：`STREET_REDEEM`）`a.prison.slots`（牢房的格子那一块；1.3：牢房那一出时柜台上的格子那一块，用 `rect_fn` 取）。
- **必须发的 ui_event**：无（宿主发 `panel_opened`；`slot_drop` 由 SlotWidget 发）。
- **first-time**：不发；依赖 `money_short` `mortgage` `street` `prison`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.money_short`（第一次钱不够 → `a.short.options`）、`gd.mortgage`（→ `a.estate.mortgage`；1.3 备用 C01 的 `a.tab.estates`）、`gd.street`（第一次流落街头 → `a.street.redeem`；用牌桌宿主 + `street` 夹具）、`gd.prison`（第一次进牢房 → `a.prison.slots`）。这几步的教的人默认 `""`（合同 §7.10.10 冲突 c，待主创定）。
- **测试做法**：开面板（夹具）或牌桌宿主；挂指引（`force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"prison", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.prison"`；放一样东西（`ui:slot_drop`）或掷（`cmd:slot.roll`）后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C11.txt`：

```
# C11 破产阶梯界面（docs/handoff_cards/C11_ladder.md）
C11_estates|res://scripts/tests/cards/C11/test_estates.gd|120|
C11_short|res://scripts/tests/cards/C11/test_short.gd|120|
C11_street|res://scripts/tests/cards/C11/test_street.gd|120|
C11_prison|res://scripts/tests/cards/C11/test_prison.gd|120|
C11_guide|res://scripts/tests/cards/C11/test_guide.gd|180|
```

| 测试 | 通过条件 |
|---|---|
| `test_estates.gd` | 五行；押 → `estate.mortgage {estate}`、赎 → `estate.redeem {estate}`；钱和利息是数字、全面板没有 `%`；状态字对 |
| `test_short.gd` | 三条路各走一次：`short.resolve` 的 `source` `by` `item` / `estate` 参数对；只有 `default` 时只显示一条；关掉 / Esc → `short.resolve {by: "default"}` |
| `test_street.gd` | 牌桌宿主 + `street` 夹具：街头~~皮~~层可见（1.3：只有按钮和提示，按钮在 `STREET_REDEEM`；背景是场景层的事，不在这里测）、按钮可点（发 `redeem_shop_pressed`，C01 转成 `street.redeem_shop`）；`mode: shop` 时不可见；除按钮外鼠标穿透 |
| `test_prison.gd` | （1.3：用画面根打出牢房牌，格子在柜台上、“托人疏通”是回话）放钱/人脉/留着的牌 → `slot.place`；掷 → `slot.roll {uid}`；动画正反等于 `faces`；`prison_fail`：面板只显示结果然后关，`mock.sent` 里**没有** `game.*` 指令 |
| `test_guide.gd` | 四个步骤按做法亮、完成；五个锚点 `t.anchor_ok()` |

另：`t.all_text_from_cardtext()` 为空；夹具 `t.no_leaks()`；`autoplay_step()` 能把每个夹具走完。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：付不起一笔 `short: "ladder"` 的钱 → 钱不够面板 → 押首饰柜；被抓 → 牢房面板 → 掷）；清单加一行 `C11_guide_k16|res://scripts/tests/cards/C11/test_guide.gd|180|--steps=k16 --name=C11_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C11 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C11/shot_ladder.gd -- --out=/tmp/shots/C11
  ```
- **截图**（不进清单）：~~家当面板~~、钱不够（三条路、只剩认了）、~~街头牌桌、牢房（空格子、放了东西、掷完）~~（10-13 作废，合同 1.3：家当、街头、牢房的截图换成上方“10-13 变更二”的清单）各一张；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图；上传 PR 或提交到 `scripts/tests/cards/C11/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：面板居中 ≤ 1100×640（1.3：只有钱不够这样；家当是右抽屉 388×630，牢房是演出）；~~背景 320×180 ×4~~（1.3：背景归 C01 的场景层）；家当小插图 ×2；键盘：Tab 选、Enter 确认、Esc 关~~（`short` 不能关）~~（10-13 作废：没有关不掉的面板，`short` 关 = 认了，见上方“10-13 变更”）。

## 交付

- PR 标题 `[C11] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①家当与钱不够 + 测试；②街头皮、牢房、截图；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；需要决定的事（教的人待定、~~街头皮的层次~~ 1.3 已定为 §7.11.1 第 7 层）；缺的美术 id（`bg.street` `bg.prison`）；性能数；“回报”。

## 审核（Claude 重点）

- 利息只给钱数，没有 `%`；牢房失败后面板不发任何 `game.*`。
- `short.resolve` 参数对；~~`short` 必须选一条~~（10-13 作废：关 = 认了，发 `short.resolve {by: "default"}`）。
- 街头皮除按钮外鼠标穿透、不挡手牌；没有中文/颜色字面量。

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
| 缺的美术 id | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
