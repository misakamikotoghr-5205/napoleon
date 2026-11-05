# C09 `month-year` · 开月、月底、跳一年、局终

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C09 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C09: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 9**（在第 9 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C09`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。开场数据 `data/cards/era/<年>/stage.json` 由 K02/K04/K06 写（先用 `data/cards/_examples/era/1938/stage.json`）。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎（G02 的开月、月底、跳年、局终与重来本关）的集成测试和 K16 步骤复测。

## 分支

`cards/C09-month-year`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

一关（一个月）的开头和结尾、年与年之间、以及输了以后：①**开月**——时局过场（背景图 + 人写的几段开场 + 本关目标），之后引擎要求打开本月运势轮盘（C06）；②**月底**——利息、开销、当票、目标结果、街坊评语；③**跳一年**——满当的东西、档案簿“一年后”、换币、人脉变化、新面孔，一条一条翻；④**局终**——这一局结束的正文、“从本关开头重来”“从续玩点重来”（主创 10-13 确认）、回标题。

## 必读

1. `docs/cards/DESIGN_cards.md` §四（一关：一个月）、§五（年代表、首发三关的主线）、§三.8（被抓、打点、结局）、§九.4（月底第一次教结账、第一次跳一年教满当与“一年后”）。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2（背景 320×180 ×4）、§3.3 开头与 C09、§4.5（`stage.<年>#intro.p<n>`、`goal#title/#done/#failed`）、§4.7.20（目标）、§4.7.22（开场 `stage.json`：`bg` `intro_paras` `main_goal`）、§7.4（`month.begin` `month.next` `year.next` `game.retry_stage`；查询 `month_report` `year_report` → `{lines:[{key, args}]}`）、§7.5（`goals`、`phase`、`open_panel`）、§7.6（`game_over(reason)`、`request_panel`）、§7.8（`month_open` `month_close` `year_jump` `game_over` 面板）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/month/{month_open,month_close,year_jump_panel,game_over}.gd`、`scenes/cards/month/*.tscn`（W0 桩）、`scripts/cards/ui/table/card_game_root.gd`（`_sync_phase_panel`：开月先开过场，关掉后开引擎要的轮盘）、`scripts/cards/mock/fixtures/{month_open,month_close,year_jump}.json`、`scripts/cards/mock/mock_scenario.gd`（`setup_month_close` `setup_year_jump` `game.retry_stage`）、`data/cards/_examples/era/1938/{stage,goals}.json`。

## 要做的事

- [ ] **CardMonthOpen**（`month_open.gd`，`class_name CardMonthOpen`，kind `month_open`）：全屏过场：背景 `bg.stage.<年>`（320×180 ×4 = 1280×720，NEAREST）、开场段落 `CardText.t("stage.<年>#intro.p<n>")` 一段一段淡入（Space/Enter 下一段）、最后本关目标（`view.goals`：主线一条加两条可选，`<目标 id>#title`；主线标出来）；“开始” → 关面板（C01 接着开引擎要求的本月运势轮盘）。**合同缺口**：`bg` 和 `intro_paras` 在视图和查询里都没有——W1 先用 `CardDB.read_json("res://data/cards/era/<年>/stage.json")`（没有就读 `res://data/cards/_examples/era/<年>/stage.json`）只取 `bg` `intro_paras` 两个机制字段，标 `# TODO(shared#<issue号>)`，PR 里列出等 G02 给查询；**不读、不显示它的 `brief`**。
- [ ] **CardMonthClose**（`month_close.gd`，`class_name CardMonthClose`，kind `month_close`）：`query("month_report")` → 每行 `CardText.ui(key, args)`（利息、开销、当票清点、目标结果、评语 `g02.month.verdict.*`）；目标逐条显示达成/没达成（`goal#done` / `goal#failed`）；钱数只在键的参数里出现；“下个月” → `send("month.next")` → 关。
- [ ] **CardYearJumpPanel**（`year_jump_panel.gd`，`class_name CardYearJumpPanel`，kind `year_jump`）：`query("year_report")` 的行**分页逐条翻**（Space/Enter 下一条）：满当的东西、档案簿“一年后”碎片、换币、人脉变化、新面孔；翻完 → `send("year.next")` → 关。分组：合同缺口——行没有“属于哪一类”的字段；W1 先认行里的 `section`（`forfeit` `after` `currency` `contacts` `faces`，夹具给），没有就按顺序一页一行，PR 里列出等 G02 定。
- [ ] **CardGameOver**（`game_over.gd`，`class_name CardGameOver`，kind `game_over`）：结局正文 `g02.ending.<reason>`（`reason` 从 `open(args).reason` 取；没有就从总线 `game_over(reason)` 记下的取；合同缺口：视图里没有局终原因，PR 里列出）；“从本关开头重来” → `send("game.retry_stage")` → 关；**“从续玩点重来”** → `send("game.load", {})`（不给 `path` = 续玩点；`CardSave.exists(CardSave.suspend_path())` 为假时按钮变灰）→ 关；“回标题” → `close_requested({"to_title": true})`（C01 的约定）；关掉 / Esc = 回标题。
- [ ] 四个面板对任意 `args` 不报错（`W0_skeleton` 会 `open({"uid": "c0002"})`）。
- [ ] **autoplay_step()**：MonthOpen——跳过段落、关；MonthClose——`month.next`；YearJump——翻一页，翻完 `year.next`；GameOver——`game.retry_stage`。同一状态同一动作。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C09.json`（`c09.` 开头，键 + `brief`，`_meta._provenance`）：`c09.btn.begin` `c09.btn.next_month` `c09.btn.next_year` `c09.btn.retry` `c09.btn.title` `c09.goals.title` `c09.goals.main` `c09.goals.done` `c09.goals.failed` `c09.year.page`（参数 `{i}` `{n}`）。
- [ ] **夹具**（`scripts/tests/cards/C09/fixtures/`，`_meta.owner = "C09"`）：W0 的 `month_open` / `month_close` / `year_jump` 之外，`month_close_goals.json`（主线达成、一条可选没达成、评语一行）、`year_jump_sections.json`（五类各一两行，带 `section`）、`game_over_prison.json`（`open_panel: {kind: "game_over", args: {reason: "prison"}}`）。夹具过 `t.no_leaks()`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **每个面板都能关**：开月过场、月底、跳年关了就回牌桌（阶段不变），牌桌上按“打烊 · 下一天”= 往前走（`month_open` 时替玩家转本月运势再开月、`month_close` = `month.next`、`year_jump` = `year.next`，合同 §7.4.7 第 2 条）。局终面板关 = 回标题。
- [ ] **局终的两条路**：从本关开头（`game.retry_stage`）或从续玩点（`game.load {}`）重来——主创 10-13 确认的“每关 + 每天续玩点”；牢房连续几晚没出来按打点失败的局终（原因 `prison`）也一样。夹具 `game_over_prison.json` 加 `game.load {}` 的回应。
- [ ] `test_game_over.gd`（你自己的清单里加一条，或并进现有的局终测试）：两条路各发对指令；没有续玩点时“从续玩点重来”不可点；Esc 回标题（`close_requested({"to_title": true})`）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] 四个面板仍是叠层，做法不变；`month_open` 仍是全屏过场。月底、跳年时背后是夜里的柜台（C01 的场景层按 `stage.time` 画），不用你管。

**新增 / 作废的交付**

- 没有新增；也没有作废的。

**锚点、界面事件、要证明的步骤**

- 不变。

**测试与截图**

- 截图改成画面版（叠在场景上）：开月过场、月底、跳年、局终各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 全部。

## 只能改这些文件

- `scenes/cards/month/**`、`scripts/cards/ui/month/**`
- 默认拥有：`scripts/tests/cards/C09/**`、`scripts/tests/cards/suites/C09.txt`、`data/cards/tags/C09.json`、`data/cards/ui_keys/C09.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`data/cards/era/**`（归 K02/K04/K06）、`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、C01、旧代码）。
2. **不写最终内容**：开场段落、目标、评语、结局、跳年的每一行都由人写；不显示任何 `brief`；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
3. 不写颜色字面量；背景只经 `CardArt`。
4. 不露隐藏数值：月底和跳年不显示口碑/风声点数、本心、概率、`%`。
5. 不放规则：目标成没成、满当了什么、重来回到哪，全看引擎。
6. 史实措辞照 `docs/town/cards/src/era.json` 的 notes——但措辞都在人写的正文里，你的 `brief` 也照写（“伪”字等）。
7. 不用随机影响结果；不加冻结表以外的 `class_name`；不加 autoload/InputMap。
8. 不发 `first_time`；本任务没有 `ui_event` 要发。

## 接口

**用到**：视图 `phase` `date{stage, era}` `goals` `open_panel`；查询 `month_report` `year_report`（`{lines:[{key, args, section?}]}`）；指令 `month.next` `year.next` `game.retry_stage`；总线 `game_over(reason)` `view_changed` `phase_changed`；`CardDB.read_json`（只读 `stage.json` 的 `bg` `intro_paras`，临时）；`CardText.t/ui/card`、`CardArt`、`CardTheme`、`CardAnchors`；C01 的 `close_requested({"to_title": true})` 约定。

**提供（冻结）**：`CardMonthOpen`、`CardMonthClose`、`CardYearJumpPanel`、`CardGameOver`（`CardPanel` 接口）。

## 新手指引

- **必须登记的锚点**：`a.month.goals`（开月的目标那块）`a.mclose.accounts`（月底的账）`a.year.forfeit`（满当那一页）`a.year.after`（“一年后”那一页）`a.over.retry`（“从本月开头重来”按钮）。只在那一页/那一块显示时登记。
- **必须发的 ui_event**：无（宿主发 `panel_opened`）。
- **first-time**：不发；依赖 `month_open` `month_close` `year_jump` `year_after` `game_over` `retry`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.m.open`（第一次开月 → `a.month.goals`）、`gd.month_close`（→ `a.mclose.accounts`）、`gd.year_jump`（→ `a.year.forfeit`）、`gd.year_after`（→ `a.year.after`，备用 C10 的 `a.dossier.page`）、`gd.game_over`（→ `a.over.retry`）、`gd.retry`（第一次重来本关 → C01 的 `a.top.date`，用牌桌宿主证明）。
- **测试做法**：开面板（夹具）或牌桌宿主 + W0 的 `month_open` 夹具；挂指引（`force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"month_open", {})` → `evaluate_now()` → `active_step() == "gd.m.open"`（目标那块显示出来以后）；关面板（`ui:panel_closed`）或超时后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C09.txt`：

```
# C09 开月、月底、跳年、局终（docs/handoff_cards/C09_month-year.md）
C09_month_open|res://scripts/tests/cards/C09/test_month_open.gd|120|
C09_month_close|res://scripts/tests/cards/C09/test_month_close.gd|120|
C09_year_jump|res://scripts/tests/cards/C09/test_year_jump.gd|120|
C09_game_over|res://scripts/tests/cards/C09/test_game_over.gd|120|
C09_guide|res://scripts/tests/cards/C09/test_guide.gd|180|
```

| 测试 | 通过条件 |
|---|---|
| `test_month_open.gd` | 背景是 `bg.stage.1938`、整数倍；段落数等于 `intro_paras`，每段来自 `CardText`；目标三条（主线标出）；没有显示任何 `brief` 原文以外的东西（开发版的【稿】+ brief 来自 `CardText`，算合格）；关面板后 C01 开轮盘（牌桌宿主里 `panel_opened {kind: "wheel"}`） |
| `test_month_close.gd` | 每行 `CardText.ui(key, args)`；目标达成/没达成显示对；“下个月” → `month.next` |
| `test_year_jump.gd` | 一页一条，Space 翻到底后 `year.next` 恰好一次；`section` 为 `forfeit` / `after` 的页登记对应锚点 |
| `test_game_over.gd` | 结局正文用 `g02.ending.prison`；重来 → `game.retry_stage`；回标题 → `close_requested({"to_title": true})` |
| `test_guide.gd` | 六个步骤按做法亮、完成；锚点 `t.anchor_ok()` |

所有测试另查：`t.all_text_from_cardtext()` 为空；没有 `%`；夹具 `t.no_leaks()`；`autoplay_step()` 能把每个面板走完。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：新局开月过场 → 本月运势 → 推到月底 → 月底账 → 跳年；以及一次局终 → 重来本关，阶段回到 `month_open`）；清单加一行 `C09_guide_k16|res://scripts/tests/cards/C09/test_guide.gd|180|--steps=k16 --name=C09_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C09 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C09/shot_month.gd -- --out=/tmp/shots/C09
  ```
- **截图**（不进清单）：开月（第一段、目标）、月底、跳年每类一页、局终各一张；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图（1.3：叠在场景上拍，见上方“10-13 变更二”）；上传 PR 或提交到 `scripts/tests/cards/C09/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：开月全屏背景 ×4；标题用 `font_title()` 28–36 号；段落 18 号、行距舒展；面板（月底、跳年、局终）居中 ≤ 1100×640；“快动画”时段落直接全出（~~读开关的接口没冻结，先开 `[shared]` issue、留 `fast_anim` 布尔、标 `# TODO(shared#<issue号>)`~~ 1.3：用冻结的静态读取 `CardSettings.fast_anim()`，合同 §7.8）；键盘：Space/Enter 下一段/下一页、Esc 关（10-13：都能关；开月过场、跳年没翻完就关了，回牌桌，按“打烊 · 下一天”照样往前走）。

## 交付

- PR 标题 `[C09] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①四个面板骨架 + 测试；②过场动画、分页、截图；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；需要决定的事（`stage.json` 的读法、`year_report` 的 `section`、局终原因的来源）；缺的美术 id（各年开场背景）；性能数；“回报”。

## 审核（Claude 重点）

- 开场、目标、评语、结局全部来自 `CardText`；不显示 `brief`；读 `stage.json` 只取 `bg` `intro_paras` 并标了 `TODO(shared#…)`。
- 跳年翻完才 `year.next`、只发一次；重来发 `game.retry_stage`。
- 没有中文/颜色字面量、`%`。

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
