# C07 `fortune` · 黄历条、算命摊、求签、测字

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C07 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C07: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 7**（在第 7 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C07`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。黄历条嵌在 C01 的~~顶栏~~ HUD（1.3：`HUD_ALMANAC` 260×24；C01 用你的冻结接口，先对着 W0 桩）。1.3：算命那一出用 C04 的对话框 `CardDialogBox`、W0 的 `CardStagePanel` / `CardStageScript`——开发时对着 W0 的桩（`CardIds.widget_scene()` 取），合并要等 C04 的对话框 PR（10-21）。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎（G05 的 `CardFortune` `CardAlmanac`）的集成测试和 K16 步骤复测。

## 分支

`cards/C07-fortune`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

v1.1 的“算命”在界面上的三处：①~~顶栏的~~（1.3：HUD 里的）**黄历条**（当天宜××、忌××，玩家自己做过的打个小勾；照着做有小好处、不照做也没事——界面不说规则）；②算命先生/测字摊/城隍庙的**算命面板**（选求签或测字、付钱；1.3：算命那一出——算命先生进门，求签/测字/不算是回话，签诗与解曰、测字的话在对话框里说）；③**求签**（摇签筒 → 一支签 → 签诗与解曰，全是人写的含糊话）与**测字**（从摊上摆的几个字里挑一个 → 按字给一句提示）。签“准”是引擎的事（钉签）；界面上**不出现任何“几天后会来哪张牌”的直接信息**。

## 必读

1. `docs/cards/DESIGN_cards.md` §九.2（算命，主创原话）、§九.4（第 4–7 天依次教黄历宜忌、求签/测字由算命先生教）。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2（~~顶栏 y 0–56~~ 1.3：HUD y 0–30，黄历条 `HUD_ALMANAC`）、§3.3 开头与 C07、§4.5（`fortune_lot#verse/#gloss`、`cezi#char/#has/#none`）、§4.7.3（算命摊事件 `opens_fortune` `cost` `choices: pass`）、§4.7.18（签、测字、黄历数据）、§7.4（`fortune.lot` `fortune.cezi` `card.choose`）、§7.4.3、§7.5（`notice.almanac{id, yi, ji, done}`、`lots`）、§7.8（AlmanacStrip 控件、`fortune` 面板）、§9.3（签为什么准、测字的读法）、§9.4（黄历动作枚举、界面只显示宜忌和做过的勾；正文键 `g05.almanac.<动作>`）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/fortune/{almanac_strip,fortune_panel}.gd`、`scenes/cards/fortune/*.tscn`（W0 桩）、`scripts/cards/ui/table/card_table.gd`（~~黄历条放在顶栏 (666, 8)、196×40~~ 1.3：放在 HUD 的 `HUD_ALMANAC` (420, 3, 260, 24)）、`scripts/cards/mock/mock_scenario.gd`（`fortune.lot` `fortune.cezi` `_almanac`）、`data/cards/_examples/fortune/{lots,cezi,almanac}.json`、`data/cards/_examples/era/common/events.json`（`ev.any.fortune_teller`）。

## 要做的事

- [ ] **CardAlmanacStrip**（`almanac_strip.gd`，`class_name CardAlmanacStrip`，冻结 `refresh(view)`）：读 `view.notice.almanac`：宜一排、忌一排，每个动作的字 `CardText.ui("g05.almanac.<动作>")`（键归 G05）；`done` 里有的动作打小勾（玩家自己做过的事，不是隐藏信息）；放不下时省略号截断，悬停显示全部（tooltip 文字同样经 `CardText`）。~~196×40 内两行排得下。~~（10-13 作废，合同 1.3：嵌在 HUD 的 `HUD_ALMANAC`，一行 260×24：宜 ×× 忌 ××）
- [ ] **CardFortunePanel**（`fortune_panel.gd`，`class_name CardFortunePanel`，kind `fortune`）（10-13 作废，合同 1.3：居中的算命面板作废，改成 `extends CardStagePanel` 的算命那一出——下面这些“和引擎说话”的做法照旧，画在哪、怎么画以下方“10-13 变更二”为准）：
  - `open({uid})`：`query("fortune", {uid})` → `{cost, can_lot, can_cezi, cezi:[字 id], last}`；算命先生~~头像（`portrait.suanming`；测字摊、城隍庙按牌的 `art`）~~（1.3：站柜台前）；代价用带参数的界面键 `c07.cost`（`{n}`）；“求签”（`can_lot`）、“测字”（`can_cezi`）两个~~按钮~~（1.3：回话）；“不算” → `send("card.choose", {uid, "choice": "pass"})`（算命摊事件的选项）→ 关。任何 uid 不许报错（`W0_skeleton` 会 `open({"uid": "c0002"})`）。
  - **求签**（~~子界面 `scripts/cards/ui/fortune/lot_view.gd`，`preload`，**不写 `class_name`**——合同 §3.3 里叫 CardLotPanel，但它不在冻结类表里~~（10-13 作废，合同 1.3：签在对话框里说，`lot_view.gd` 不要了））：~~摇签筒动画（Tween，单段 ≤ 0.6 秒，Space 跳过）~~（1.3：对话框里 sys 一句 `c07.sys.shake`）→ `send("fortune.lot", {uid})` → `{lot, grade}` → 一支签：签诗 `CardText.card(lot, "verse")`、解曰 `CardText.card(lot, "gloss")`；等第用字（本任务的键 `c07.grade.<0-4>`：下下/下/中/上/上上，由 B 写），**不显示数字**。
  - **测字**（~~子界面 `scripts/cards/ui/fortune/cezi_view.gd`，`preload`，不写 `class_name`~~（10-13 作废，合同 1.3：字是一排回话，`cezi_view.gd` 不要了））：摊上摆的字（`cezi` 里每个 id 用 `CardText.card(<字 id>, "char")` 显示成~~一张字卡~~ 1.3：一句回话）→ 挑一个 → `send("fortune.cezi", {uid, char})` → `{char, reading}` → 提示 `CardText.card(char, reading)`（`has` 或 `none`）。
  - 结果出来后“好”→ 关面板（牌由引擎 `resolve`）；钱不够（`insufficient_money`）显示原因正文。
  - **不显示**：签对应哪张牌、哪天来、窗口几天、本心、任何权重或概率；`last` 只用来再显示一次刚才那支签。
- [ ] **autoplay_step()**：同一状态同一动作——`can_lot` → 求签；否则 `can_cezi` → 挑第一个字；否则 `pass`；看完结果关面板。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C07.json`（`c07.` 开头，键 + `brief`，`_meta._provenance`）：`c07.btn.lot` `c07.btn.cezi` `c07.btn.pass` `c07.btn.ok` `c07.cost`（`{n}`）`c07.grade.<0-4>` `c07.cezi.pick` `c07.strip.yi` `c07.strip.ji`。黄历动作的字用 G05 的 `g05.almanac.<动作>`，不重复登记。
- [ ] **夹具**（`scripts/tests/cards/C07/fixtures/`，`_meta.owner = "C07"`）：`teller_both.json`（能求签也能测字，摊上 3 个字）、`lot_only.json`、`cezi_only.json`、`after_lot.json`（`last` 有值）、`no_money.json`、`almanac_done.json`（早上黄历宜两样、忌一样，`done` 里有一样）。夹具过 `t.no_leaks()`（不许有 `pins` `foretold` `hint_tags` `tags` 等键）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardAlmanacStrip**：嵌在 HUD 的 `HUD_ALMANAC`（260×24），一行：宜 ×× 忌 ××，做过的打小勾；放不下省略、悬停显示全部。冻结接口不变。
- [ ] **CardAlmanacDrawer**（新：`scenes/cards/fortune/AlmanacDrawer.tscn` + `scripts/cards/ui/fortune/almanac_drawer.gd`，`class_name CardAlmanacDrawer`，kind `almanac`，右抽屉）：今天的宜忌（动作字 `g05.almanac.<动作>`、做过的小勾）、本月运势的段名（`notice.fortune` → `<段 id>#title`）、`view.lots` 里求过的签（签诗 `#verse`）；只读。
- [ ] **CardFortunePanel 改成演出**（`extends CardStagePanel`）：默认算命先生站柜台前；话说完回话：“求签 · 代价”（`c07.reply.lot`，参数 `{n}`，`anchor: "a.fortune.lot"`）、“测字 · 代价”（`c07.reply.cezi`，`anchor: "a.fortune.cezi"`）、“不算”（`c07.reply.pass` → `card.choose {choice: "pass"}` → `after.pass`）；求签 → `fortune.lot` → 摇签筒（`prop` 不需要；对话框里 sys 一句 `c07.sys.shake` 之后）说签：narr `<lot>#verse`、narr `<lot>#gloss`、sys `c07.grade.<0-4>`；测字 → 回话换成摊上的那几个字（每个字一句回话，`ref` = `<cz id>#char`，第一句 `anchor: "a.fortune.chars"`）→ `fortune.cezi` → narr `<cz id>#has` 或 `#none`。不说签对应哪张牌、哪天来。

**新增 / 作废的交付**

- 新增 `AlmanacDrawer`；界面键 `c07.reply.lot` `c07.reply.cezi` `c07.reply.pass` `c07.sys.shake` `c07.drawer.title` `c07.drawer.fortune` `c07.drawer.lots`。
- **作废**：子界面 `lot_view.gd` `cezi_view.gd`（签、字都在对话框里）。

**锚点、界面事件、要证明的步骤**

- 锚点不改名（`a.fortune.*` 成了回话上的锚点）。
- 步骤不变（`gd.almanac` 的备用锚点是 C01 的 `a.scene.calendar`）。

**测试与截图**

- 原有测试改用画面根 + 夹具；加 `C07_almanac_drawer|res://scripts/tests/cards/C07/test_almanac_drawer.gd|120|`。
- 截图：HUD 的黄历条（有小勾）、黄历抽屉、算命先生进门、签诗与解曰、测字的一排字、测字的提示各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 黄历条的内容、求签/测字/不算的指令与自动一步、夹具都有效；摇签筒、字卡的画法换成对话框。

**日期**：演出目标 **10-29**。

## 只能改这些文件

- `scenes/cards/fortune/**`、`scripts/cards/ui/fortune/**`
- 默认拥有：`scripts/tests/cards/C07/**`、`scripts/tests/cards/suites/C07.txt`、`data/cards/tags/C07.json`、`data/cards/ui_keys/C07.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、C01 的顶栏、旧代码）。
2. **不写最终内容**：签诗、解曰、字、测字的提示、黄历动作的字、等第的字全部由人写；**你的 `brief` 也不写成签诗或谜语**，只写“这个按钮干什么”；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
3. 不写颜色字面量；图只经 `CardArt`（签筒、签、字卡用美术 id，没有就开 `[content]` issue，先用配色画）。
4. **不露隐藏信息**：不显示签将应验的牌、日子、窗口长度、本心、概率、`%`、等第数字。
5. 不放规则：黄历“照做有没有好处”不在界面上算，也不提示“你今天照做了”；只打勾表示做过。
6. 不用随机影响结果（签筒抖几下这种装饰可以用固定种子的 `RandomNumberGenerator`）；不加冻结表以外的 `class_name`；不加 autoload/InputMap。
7. 不发 `first_time`；本任务没有 `ui_event` 要发。

## 接口

**用到**：视图 `notice.almanac{id, yi, ji, done}`、`lots`、`money`；查询 `fortune {uid}`、`almanac`、`card {uid}`；指令 `fortune.lot {uid}` → `{lot, grade}`、`fortune.cezi {uid, char}` → `{char, reading}`、`card.choose {uid, choice: "pass"}`；总线 `view_changed` `card_left`；`CardText.card/ui`、`CardArt`、`CardTheme`、`CardAnchors`；1.3：视图 `notice.fortune`（本月运势的段）、`CardStagePanel` `CardStageScript`（W0）、`CardDialogApi`（C04 的对话框，没合入时用 W0 的桩）。

**提供（冻结）**：`CardAlmanacStrip.refresh(view)`、`CardFortunePanel`（`CardPanel` 接口；1.3 起 `extends CardStagePanel`）；1.3：`CardAlmanacDrawer`（kind `almanac`）。

## 新手指引

- **必须登记的锚点**（名字不变，1.3 位置变了）：`a.almanac`（黄历条整块；1.3：HUD 里）`a.fortune.lot`（~~求签按钮~~ “求签”那句回话）`a.fortune.cezi`（~~测字按钮~~ “测字”那句回话）`a.fortune.chars`（~~摆出来的那排字~~ 测字时第一个字的回话）。
- **必须发的 ui_event**：无（宿主发 `panel_opened {kind: "fortune"}`）。
- **first-time**：不发；依赖 `almanac` `lot` `cezi`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.almanac`（第一个早上黄历出来，`stage_day_gte: 4` → `a.almanac`，1.3 备用 C01 的 `a.scene.calendar`；用画面根 + `almanac_done` 夹具，日期在第 4 天以后）、`gd.lot`（第一张能求签的牌 → `a.fortune.lot`，备用 `a.card@{uid}`）、`gd.cezi`（→ `a.fortune.cezi`，备用 `a.card@{uid}`）。
- **测试做法**：牌桌宿主 `CardGame.tscn` + `boot({"bus", "fixture": "<本目录夹具>", "skip_title": true})` 或单开面板；挂指引（`force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"lot", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.lot"`；求签（`cmd:fortune.lot`）后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C07.txt`：

```
# C07 黄历与算命（docs/handoff_cards/C07_fortune.md）
C07_strip|res://scripts/tests/cards/C07/test_strip.gd|120|
C07_lot|res://scripts/tests/cards/C07/test_lot.gd|120|
C07_cezi|res://scripts/tests/cards/C07/test_cezi.gd|120|
C07_no_foretell|res://scripts/tests/cards/C07/test_no_foretell.gd|120|
C07_guide|res://scripts/tests/cards/C07/test_guide.gd|180|
C07_almanac_drawer|res://scripts/tests/cards/C07/test_almanac_drawer.gd|120|
```

（最后一行是 1.3 新增；原有测试 1.3 起用画面根 + 夹具，见上方“10-13 变更二”的“测试与截图”。）

| 测试 | 通过条件 |
|---|---|
| `test_strip.gd` | 宜两样、忌一样各显示；`done` 里的那样有勾；文字都来自 `CardText`；放在 ~~196×40~~ 260×24（1.3，HUD 里一行）里不出界 |
| `test_lot.gd` | 求签 → `mock.sent` 有 `fortune.lot {uid}`；签诗、解曰来自 `CardText.card(lot, "verse"/"gloss")`（1.3：在对话框里）；等第是字不是数字；跳过动画不丢结果；钱不够显示原因 |
| `test_cezi.gd` | 摆出的字数（1.3：字的回话句数）等于 `cezi` 的长度；挑第二个 → `fortune.cezi {uid, char: <第二个 id>}`；提示来自 `CardText.card(char, reading)` |
| `test_no_foretell.gd` | 每个夹具所有状态：面板与黄历条的文字里没有 `[0-9]`（代价除外，代价用带参数的键）、没有 `%`；`t.all_text_from_cardtext()` 为空；夹具 `t.no_leaks()` |
| `test_guide.gd` | 三个步骤按做法亮、完成；四个锚点 `t.anchor_ok()` |

另：`autoplay_step()` 能把每个夹具走完；“不算”发 `card.choose {uid, choice: "pass"}`。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：手上有算命摊牌时开面板、求签，结果的 `lot` 在例子集里；黄历条显示真引擎的宜忌）；清单加一行 `C07_guide_k16|res://scripts/tests/cards/C07/test_guide.gd|180|--steps=k16 --name=C07_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C07 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C07/shot_fortune.gd -- --out=/tmp/shots/C07
  ```
- **截图**（不进清单）：~~牌桌顶栏的黄历条（有勾）一张、算命面板三种状态、摇签中、出签、测字摆字、测字结果各一张~~（10-13 作废，合同 1.3：清单见上方“10-13 变更二”的“测试与截图”）；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图；上传 PR 或提交到 `scripts/tests/cards/C07/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：黄历条 ~~196×40~~ 260×24（1.3）、最小字号 14；~~面板居中 ≤ 1100×640；头像 48×64 ×4 NEAREST；签、字卡用配色键的纸色~~（10-13 作废，合同 1.3：算命是演出，签与字都在对话框里；黄历抽屉是右抽屉 388×630）；“快动画”时直接出签（~~读开关的接口没冻结，先开 `[shared]` issue、留 `fast_anim` 布尔、标 `# TODO(shared#<issue号>)`~~ 1.3：用冻结的静态读取 `CardSettings.fast_anim()`，合同 §7.8）；键盘：Tab 选按钮/字、Enter 确认、Space 跳过摇签、Esc 关。

## 交付

- PR 标题 `[C07] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①黄历条 + 算命面板骨架 + 测试；②求签、测字子界面、动画、截图（1.3：②换成算命那一出 + 黄历抽屉，等 C04 的对话框合入，10-29）；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；需要决定的事（签的等第是否显示成字）；缺的美术 id；性能数；“回报”。

## 审核（Claude 重点）

- 签文、提示只来自 `CardText`；界面上不出现任何“几天后会发哪张牌”的信息；等第不是数字。
- 黄历条只显示宜忌和玩家做过的勾，不说奖励规则。
- ~~Lot/Cezi 子界面没有写 `class_name`~~（1.3：子界面作废）；没有中文/颜色字面量。

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
