# C05 `demand` · 条子板与条子面板

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C05 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C05: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 5**（在第 5 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C05`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）；C03 的 `CardSlotWidget` / `CardCoinTossView`（复用，接口已冻结在 W0 桩里，先对着桩做；C03 合入后换成正式版不用改代码）。1.3：演出用 C04 的对话框 `CardDialogBox`、C03 的柜台格子 `CardCounterChecks`、W0 的 `CardStagePanel` / `CardStageScript`——开发时对着 W0 的桩（`CardIds.widget_scene()` 取），合并要等 C04 的对话框 PR（10-21）。
- **波次（Wave）**：W1 开发并合入（W1 内合并在 C03 之后）；W2 补对真引擎（G03 的条子）的集成测试和 K16 步骤复测。

## 分支

`cards/C05-demand`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

胡二每周一送来的“条子”在界面上的两处：~~右栏的~~（10-13 作废，合同 1.3：左边“条子”抽屉里的）**条子板**（每张条子的类别、档位字、剩几天，到期前一天变色）和点开后的**条子面板**（1.3：胡二那一出——胡二进门、条子拍在柜台上、办法是回话、格子在柜台上；要什么、几种办法——交、讲价、顶替、编一个、派人、交消息，都经 `card.choose`；格子放好后 `demand.submit`；“拖一拖”及它在戏里的后果说法；胡二的台词）。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.3（条子：四类、四档、吃亏阶梯、拖一拖）、§三.4（格子与铜钱）、§九.4（胡二第一次送条子时教“条子与七天期限”）。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2、§3.3 开头与 C05、§4.5（demand 的正文字段 `title` `body` `slots.<id>` `outcomes.success/fail` `lines.issue`）、§4.6（`demand_rules.json`：七天、拖一拖 +3 天升一档）、§4.7.6（条子的格式、六种办法的保留 id、各类的 `resolve`、要人/要消息的规则）、§7.4（`card.choose` `slot.*` `demand.submit` `demand.delay`）、§7.4.3、§7.5（CardView `days_left`）、§7.6（`coins_tossed`）、§7.8（DemandBoard 控件、`demand` 面板）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/demand/{demand_board,demand_panel}.gd`、`scenes/cards/demand/*.tscn`（W0 桩）、`scripts/cards/ui/slots/{slot_widget,coin_toss}.gd`（C03 的冻结接口）、`scripts/cards/mock/mock_scenario.gd`（条子相关）、`scripts/cards/mock/fixtures/day_full.json`（有一张条子）、`data/cards/_examples/demand/demands.json`（四类条子与 `ev.any.demand_return` 的例子）。
4. 只读参考：`scripts/core/protection.gd`（旧版保护费的升级阶梯，条子的前身；只看做法）。

## 要做的事

- [ ] **CardDemandBoard**（`demand_board.gd`，`class_name CardDemandBoard`，冻结：`refresh(view)`、`signal demand_pressed(uid)`；~~C01 把它放在右栏 (1056, 64)、216×220~~（10-13 作废，合同 1.3：嵌在你自己的 `CardDemandsDrawer` 左抽屉里，见下方“10-13 变更二”））：每张条子（`view.demands`）一行：类别图标（`CardArt` 的 `icon.demand.<kind>`；清单里没有就开 `[content]` issue，先用本任务的类别字 `c05.kind.<kind>`）、档位字（`c05.tier.<0-3>`：小/中/大/要命，由 B 写；1.3：档位与类别读 CardView 的 `demand: {kind, tier}`）、剩几天（`days_left`，数字）；`days_left <= 1` 用 `danger` 色；点一行 → `demand_pressed(uid)`。条子多于放得下时滚动。
- [ ] **CardDemandPanel**（`demand_panel.gd`，`class_name CardDemandPanel`，kind `demand`）（10-13 作废，合同 1.3：条子面板的居中布局作废，改成 `extends CardStagePanel` 的胡二那一出——下面这些“和引擎说话”的做法照旧，画在哪、怎么画以下方“10-13 变更二”为准）：
  - `open({uid})`：`query("card", {uid})`；胡二的头像（`portrait.hu2`）和一句 `<def>#lines.issue`（1.3：胡二站柜台前、这句在对话框里说）；要什么 `<def>#body`；档位字、剩几天。任何 uid 不许报错。
  - **办法**：`choices` 里的保留 id `pay` `haggle` `substitute` `fabricate` `send_person` `inform`（`enabled` / `reason_key`）~~一排按钮~~（1.3：每个办法一句回话）（文字 `c05.mode.<id>`）→ `send("card.choose", {uid, choice})` → `needs_slots` 时用 C03 的 `CardSlotWidget` 显示这个办法的格子（`query("slots", {uid})`；1.3：`checks.show_checks(uid)`，格子摆在柜台上），放东西 → `slot.place`、拿出来 → `slot.remove`；“N 枚铜钱，要 M 个正面”照 C03 的写法（数字可显示；1.3：柜台上铜钱那一排 + 回话）。
  - **交上去**：`send("demand.submit", {uid})` → `{success}`；有检定的办法（讲价、编一个、要人回来）在总线 `coins_tossed(uid, faces, need, success)` 到来时用 `CardCoinTossView.play(faces, need)` 播；然后显示 `<def>#outcomes.success` / `outcomes.fail`。
  - **拖一拖**：~~按钮~~（1.3：回话 `c05.reply.delay`）→ `send("demand.delay", {uid})` → `{days_left, tier}`；面板和条子板上的天数、档位字更新；~~按钮旁~~（1.3：之后在对话框里说）一句戏里的后果说法（键 `c05.delay.note`，正文由 B 写；你的 `brief` 只写“期限往后推、条子升一档”这层意思，不写成台词，不写数字）。
  - 要人：放进去的人这几天不能用（界面只照视图的 `away_days` 显示）；回来那天的“回来了吗”是一张普通事件牌 `ev.any.demand_return`，走 C03 的格子面板，不在这里。
  - 要消息：交消息时提醒一句（`c05.inform.note`，会伤到那个人——只说后果方向，不提本心）。
- [ ] **autoplay_step()**：同一状态同一动作——`pay` 可用就选它并把钱放进 `pay: true` 的格子 → `demand.submit`；否则 `substitute`；否则第一个可用的办法；都不行 → `demand.delay`；最后关面板。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C05.json`（`c05.` 开头，键 + `brief`，`_meta._provenance`）：`c05.kind.<money|goods|people|info>` `c05.tier.<0-3>` `c05.mode.<pay|haggle|substitute|fabricate|send_person|inform>` `c05.btn.submit` `c05.btn.delay` `c05.delay.note` `c05.inform.note` `c05.days`（参数 `{n}`）`c05.board.title`。
- [ ] **夹具**（`scripts/tests/cards/C05/fixtures/`，`_meta.owner = "C05"`）：`board_three.json`（三张条子，其中一张剩 1 天）、`money.json`、`goods.json`、`people.json`、`info.json`（四类各一张，带各自的办法和格子）、`delay.json`（`demand.delay` 回 `{days_left: 9, tier: 2}`，视图补丁同步）、`fail.json`（`demand.submit` 回 `success: false`，带 `coins_tossed` 事件）、`people_return.json`（手上有 `ev.any.demand_return`）。~~**条子的档位和类别**：CardView 的字段表里没有，合同缺口——夹具先放 `tier`（int）和 `kind`（String），界面按这两个键读，缺了就不显示（PR 里列出，等 G03 定名）。~~（10-13 作废，合同 1.3：CardView 有了 `demand: {kind, tier}`（G03 的 1.3 增补，Mock 已有），夹具照这个写，临时键 `tier` `kind` 不要了）夹具过 `t.no_leaks()`。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardDemandsDrawer**（新：`scenes/cards/demand/DemandsDrawer.tscn` + `scripts/cards/ui/demand/demands_drawer.gd`，`class_name CardDemandsDrawer`，kind `demands`，左抽屉）：里面嵌 `CardDemandBoard`（冻结接口不变）；每行的类别、档位改读 CardView 的 `demand: {kind, tier}`（G03 的 1.3 增补；Mock 已有；1.2 夹具里的临时键 `tier` `kind` 作废）；点一行 → 收回抽屉、`host.open_panel(&"demand", {uid})`。
- [ ] **CardDemandPanel 改成演出**（`extends CardStagePanel`）：默认胡二站柜台前、`prop.notice` 在柜台中间；说 `#lines.issue`、`#body`；回话：几种办法（`c05.mode.<id>`，`enabled`/`reason_ref`，第一句 `anchor: "a.demand.modes"`）、“拖一拖”（`c05.reply.delay`，`anchor: "a.demand.delay"`）、“回头再说”；选了要格子的办法 → `checks.show_checks(uid)`（同 C03 的做法）+ “交上去”（`c05.reply.submit` → `demand.submit`；有 `coins_tossed` 就 `checks.play_coins`）→ `after.success/fail`；拖一拖 → `demand.delay` → `after.delay`，再说一句 `c05.delay.note`（narr）；演出时柜台上那张条子登记 `a.demand.tier`（`rect_fn` 取 `counter_mid` 道具的矩形）。

**新增 / 作废的交付**

- 新增 `DemandsDrawer` 场景与脚本；界面键 `c05.reply.delay` `c05.reply.submit` `c05.reply.later` `c05.drawer.title`；夹具加 CardView 的 `demand` 字段。
- **作废**：条子板摆在右栏（1056, 64）、条子面板的居中布局、夹具里临时的 `tier` `kind` 键。

**锚点、界面事件、要证明的步骤**

- 锚点不改名（位置见合同 §7.10.5：`a.demand.board` 是条子抽屉里的条子板；`a.demand.tier` 抽屉里第一行先登记，演出时柜台上那张条子道具后登记、盖住前者；`a.demand.modes` `a.demand.delay` 是回话上的锚点）。
- `gd.demand` 改由 C01 证（锚点成了 `a.scene.notewall`）；C05 证 `gd.demand_delay` `gd.demand_people` `gd.demand_inform` `gd.demand_fail`。

**测试与截图**

- 原有测试改用画面根 + 夹具；加“抽屉里点一行 → 开演出”。
- 截图：条子抽屉（三张，一张剩 1 天）、墙上的条子热点、胡二那一出（办法回话）、讲价时柜台上的格子、拖一拖之后、没办成各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 六种办法、拖一拖、交上去、掷铜钱、自动一步与夹具都有效；`CardDemandBoard` 的行有效（读法换成 `demand` 字段）。

**日期**：演出在 C04 对话框合入后，目标 **10-29**。

## 只能改这些文件

- `scenes/cards/demand/**`、`scripts/cards/ui/demand/**`
- 默认拥有：`scripts/tests/cards/C05/**`、`scripts/tests/cards/suites/C05.txt`、`data/cards/tags/C05.json`、`data/cards/ui_keys/C05.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（尤其 C03 的 `slot_widget.gd` / `coin_toss.gd`——要它加东西开 `[shared]` issue 给 C03；`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、旧代码）。
2. **不写最终内容**：胡二的台词、条子的正文、档位字、后果说法都由人写，你只用键 + `brief`；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII，`.tscn` 不出现中文。
3. 不写颜色字面量（到期变色用 `danger` 键）；图只经 `CardArt`。
4. 不露隐藏数值：不显示条子的数目浮动、成功机会、`%`、本心；数目、天数、铜钱数照引擎给的显示。
5. 不放规则：哪些办法能用、要多少钱、拖一拖后几天几档，全看引擎。
6. 不用随机影响结果；不加冻结表以外的 `class_name`；不加 autoload/InputMap。
7. 不发 `first_time`；`slot_drop` 由复用的 SlotWidget 自己发，本任务不另发。

## 接口

**用到**：视图 `demands`（CardView：`uid def days_left status`，~~另读夹具里的 `tier` `kind`~~ 1.3：`demand {kind, tier}`）、`self` `contacts` `kept`；指令 `card.choose {uid, choice}` → `{needs_slots}`、`slot.place` `slot.remove`、`demand.submit {uid}` → `{success}`、`demand.delay {uid}` → `{days_left, tier}`；查询 `card {uid}`、`slots {uid}`、`stock`；总线 `view_changed` `coins_tossed` `card_left`；C03 的 `CardSlotWidget`（`set_slot` `place_requested` `remove_requested`）与 `CardCoinTossView`（`play` `skip` `finished`）；`CardText.card/ui`、`CardArt`、`CardTheme`、`CardAnchors`；1.3：`CardStagePanel` `CardStageScript`（W0）、`CardDialogApi`（C04 的对话框，没合入时用 W0 的桩）、`CardChecksApi`（C03 的柜台格子，同上）。

**提供（冻结）**：`CardDemandBoard`（`refresh` `demand_pressed`）、`CardDemandPanel`（`CardPanel` 接口；1.3 起 `extends CardStagePanel`）；1.3：`CardDemandsDrawer`（kind `demands`）。

## 新手指引

- **必须登记的锚点**（名字不变，1.3 位置变了）：`a.demand.board`（整块条子板；1.3：条子抽屉里）`a.demand.days`（第一张条子的天数）`a.demand.tier`（档位字：条子板第一行登记；~~面板开着时面板上的那个~~ 1.3：演出时柜台上那张条子道具后登记、盖住前者）`a.demand.modes`（~~面板上办法那一排~~ 办法的第一句回话）`a.demand.delay`（~~拖一拖按钮~~ “拖一拖”那句回话）。
- **必须发的 ui_event**：无（`slot_drop` 由 SlotWidget 发）。
- **first-time**：不发；依赖 `demand` `demand_delay` `demand_people_return` `demand_inform` `demand_fabricate` `demand_fail`。
- **要证明会亮的步骤**（W1 全部必证）：~~`gd.demand`（第一张条子 → `a.demand.board`）~~（10-13 作废，合同 1.3：改由 C01 证，锚点 `a.scene.notewall`）、`gd.demand_delay`（第一次开条子面板 → `a.demand.delay`）、`gd.demand_people`（第一张“回来了吗” → `a.card@{uid}`，用牌桌宿主 + `people_return` 夹具）、`gd.demand_inform`（第一次开“要消息”的条子 → `a.demand.modes`）、`gd.demand_fail`（第一次没办成 → `a.demand.tier`，条子没了就是备用 `a.scene.notice`）。
- **测试做法**：牌桌宿主 `CardGame.tscn` + `boot({"bus", "fixture": "<本目录夹具>", "skip_title": true})`（~~条子板在牌桌上~~ 1.3：条子板在左边的条子抽屉里）或单开面板；挂指引（`force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`）；~~`bus.first_time.emit(&"demand", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.demand"`；开面板（`panel:demand`）后完成~~（1.3：`gd.demand` 归 C01；拿 `gd.demand_delay` 照样做：`bus.first_time.emit(&"demand_delay", …)` → `evaluate_now()` → `active_step() == "gd.demand_delay"`）。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C05.txt`：

```
# C05 条子（docs/handoff_cards/C05_demand.md）
C05_board|res://scripts/tests/cards/C05/test_board.gd|120|
C05_kinds|res://scripts/tests/cards/C05/test_kinds.gd|180|
C05_modes|res://scripts/tests/cards/C05/test_modes.gd|180|
C05_delay_fail|res://scripts/tests/cards/C05/test_delay_fail.gd|120|
C05_guide|res://scripts/tests/cards/C05/test_guide.gd|180|
```

| 测试 | 通过条件 |
|---|---|
| `test_board.gd` | 三张条子三行；剩 1 天那行用 `danger` 色；点行发 `demand_pressed(uid)`；天数显示等于 `days_left`（1.3：在条子抽屉里测；类别、档位读 `demand {kind, tier}`；抽屉里点一行 → 收回抽屉、开 `demand` 那一出） |
| `test_kinds.gd` | 四类条子各开一次：只出现那一类的办法；正文、胡二台词都来自 `CardText`；`t.all_text_from_cardtext()` 为空 |
| `test_modes.gd` | 六种办法逐个：`card.choose {uid, choice: <保留 id>}` 参数对；`needs_slots` 后格子出现；放东西 → `slot.place`；`demand.submit {uid}`；`coins_tossed` 到来时铜钱动画的正反等于事件的 `faces` |
| `test_delay_fail.gd` | 拖一拖 → `demand.delay {uid}`；返回后面板和条子板的天数、档位字更新；没办成显示 `outcomes.fail`；全程没有 `%` |
| `test_guide.gd` | ~~五个~~ 四个步骤按做法亮、完成（1.3：`gd.demand` 归 C01）；锚点 `t.anchor_ok()` |

另：`autoplay_step()` 能把四类夹具都走完；夹具 `t.no_leaks()`。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：推到第一个星期一，条子板出现条子，开面板 `autoplay_step()` 走完）；清单加一行 `C05_guide_k16|res://scripts/tests/cards/C05/test_guide.gd|180|--steps=k16 --name=C05_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C05 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C05/shot_demand.gd -- --out=/tmp/shots/C05
  ```
- **截图**（不进清单）：~~牌桌上的条子板（含到期前一天变色）一张、四类条子面板各一张、讲价掷铜钱一张、拖一拖后一张、没办成一张~~（10-13 作废，合同 1.3：清单见上方“10-13 变更二”的“测试与截图”；四类条子的那一出各一张照拍）；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图；上传 PR 或提交到 `scripts/tests/cards/C05/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：~~条子板 216×220 内排得下 3 行~~（1.3：条子板在左抽屉里那块 368×630 内）；小插图 64×48 ×2；~~面板居中 ≤ 1100×640~~（10-13 作废，合同 1.3：条子是演出，格子在柜台上）；键盘：Tab 选办法、Enter 确认、D 拖一拖、Esc 关。

## 交付

- PR 标题 `[C05] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①条子板 + 面板骨架 + 测试；②六种办法、拖一拖、掷铜钱、截图；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；需要决定的事（~~CardView 的 `tier` / `kind` 字段名~~ 1.3 已定为 `demand {kind, tier}`）；缺的美术 id；性能数；“回报”。

## 审核（Claude 重点）

- 六种办法都走 `card.choose`，参数对；`demand.submit` / `demand.delay` 不在总线回调里同步发。
- 拖一拖的“后果说法”是键，不是写死的规则说明；没有 `%`、没有数目浮动。
- 复用 C03 的控件，没有改它的文件；`slot_drop` 照样发。

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
