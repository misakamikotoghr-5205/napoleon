# C06 `wheel` · 命运轮盘面板（本月运势、大轮盘、庙会/赌摊）

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C06 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C06: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 6**（在第 6 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C06`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）；C03 的 `CardSlotWidget`（香案格复用，先对着 W0 桩做）。
- **波次（Wave）**：W1 开发并合入（W1 内合并在 C03 之后）；W2 补对真引擎（G05 的 `CardWheel`）的集成测试和 K16 步骤复测。

## 分支

`cards/C06-wheel`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

v1.1 的命运轮盘面板，三种转法共用：①每关开头的**本月运势**（`wh.month`，引擎要求打开、必须转）；②快输时那张 `bf.wheel` 打开的**大轮盘**（`wh.big`，翻身／平安／坠底，更凶的皮）；③庙会、赌摊（`wh.fair` `wh.gamble`，花钱或押一张留着的牌）。转之前往**香案**上放香火钱、留着的牌、人脉，好的扇区**动画变宽**——只看扇区大小，**界面上不出现任何数字**。转：按引擎给的 `stop_deg` 缓停，看到的和结果一致，揭晓段的正文。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.6（命运牌和大命运牌）、§九.1（命运轮盘，主创原话）、§九.4（月初第一次教轮盘与香案）。
2. `docs/cards/CARDS_INTERFACES.md`：§0（红线 3：扇区只给大小）、§1.2（轮盘面 120×120 ×4 = 480）、§3.3 开头与 C06、§4.5（`wheel#title`、`wheel_segment#title/#body`）、§4.7.17（轮盘与扇区数据）、§7.4（`wheel.offer` `wheel.withdraw` `wheel.stake` `wheel.spin` `month.begin`）、§7.4.3、§7.4.4（轮盘指令都带 `uid`，本月运势 `""`）、§9.1（WheelView、扇区从 12 点钟顺时针、`stop_deg` 落在选中段里）、§9.2（三种转法）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/wheel/wheel_panel.gd`、`scenes/cards/wheel/WheelPanel.tscn`（W0 桩）、`scripts/cards/ui/common/w0_stub.gd`（W0 的轮盘自动一步：先放 10 个香火钱再转）、`scripts/cards/ui/slots/slot_widget.gd`（C03 的冻结接口）、`scripts/cards/mock/mock_scenario.gd`（`_wheel_view` `_wheel_offer` `_wheel_spin` `_segments`）、`scripts/cards/mock/fixtures/{month_open,month_wheel}.json`、`scripts/cards/ui/table/card_game_root.gd`（开月后谁开轮盘、`month.begin` 什么时候发）。

## 要做的事

- [ ] **CardWheelPanel**（`wheel_panel.gd`，`class_name CardWheelPanel`，kind `wheel`）：
  - `open(args)`：`args = {wheel, uid, required?}`（本月运势由引擎 `request_panel("wheel", {wheel: "wh.month", uid: "", required: true})` 要求打开）；`args.wheel` 为空时：先看 `query("card", {uid}).wheel`（~~合同缺口：CardView 没有这个字段，G05 应当用 `card_view_part` 给；PR 里列出~~ 1.3：CardView 有了 `wheel`，G05 的 1.3 增补，Mock 已有），没有就 `bf.wheel` → `wh.big`，其余开 `query("card")` 拿不到就提示并关面板（不报错）。任何 uid 不许报错（`W0_skeleton` 会 `open({"uid": "c0002"})`）。
  - `query("wheel", {wheel, uid})` → WheelView（`segments[{id, arc_deg, art}]`、`incense{accepts, placed, full}`、`cost{money, stake}`、`staked`、`spun`、`result`）。
  - **盘面**：底图 `wheel.<kind>`（120×120 ×4 = 480×480，NEAREST）；扇区按数据顺序从 12 点钟方向**顺时针**用 `arc_deg` 画（`draw_colored_polygon` / `draw_arc`，颜色用配色键，不同段交替 `paper` / `paper_old` 之类）；每段图标 `CardArt` 的段 `art`（×2）和段名 `CardText.card(<段 id>, "title")`；指针固定在 12 点钟。**不写任何数字、不写 `%`、不分好坏地上色**（好坏是隐藏的）。
  - **香案**：复用 C03 的 `CardSlotWidget`，`set_slot(uid, {"id": "incense", "accepts": incense.accepts, "placed": incense.placed})`（不给 `coins` 键 → 不显示铜钱数）；`place_requested` → `send("wheel.offer", {wheel, uid, source})`；`remove_requested` → `send("wheel.withdraw", {wheel, uid, index})`；香火钱用 C03 的放钱方式（拖钱/选择器），放了几份不写数，用香的根数/小图堆起来表示。收到 `view_changed` 后重新 `query("wheel")`，各段 `arc_deg` 用 Tween 从旧值过渡到新值（≤ 0.6 秒），所以“放了以后好段变宽”是看得见的动画。
  - **代价**：`cost.money > 0` → 用带参数的界面键 `c06.cost.money`（参数 `{n}`，A/B 把它写成文字；**面板上不直接画阿拉伯数字**）；`cost.stake` → “押一张留着的牌”选择器（`view.kept` 小牌）→ `send("wheel.stake", {wheel, uid, kept_uid})`；没押就转会得到 `stake_required`，显示原因正文。
  - **转**：`send("wheel.spin", {wheel, uid})` → `{segment, stop_deg}`；盘（或指针）转若干整圈后缓停，最终相对 12 点钟的角度 = `stop_deg`（落在选中段的范围里，§9.1 已保证）；停下后亮出那一段：`<段 id>#title`、`#body`；钱不够（`insufficient_money`）显示原因正文、不转。
  - **皮**：`wh.big` 用更凶的配色组合与底图 `wheel.big`；`wh.fair` / `wh.gamble` 各用自己的底图；配色只用键。
  - **本月运势**（`wh.month`，`required: true`）：没转之前也能关（10-13：没有关不掉的面板；关了回牌桌，牌桌上按“打烊 · 下一天”= 引擎替玩家转，香案上已经放的照算，合同 §7.4.7）；揭晓后“继续” → `send("month.begin")` 并关面板（合同只说“段的正文 → `month.begin`”，没指定谁发；默认由本面板发，PR 里列出）。其他轮盘揭晓后“继续”只关面板（牌由引擎 `resolve`）。
- [ ] **autoplay_step()**：同一状态同一动作——没转过：香案收钱且什么都没放 → 放 10 个香火钱（和 W0 桩一致，`W0_table_3days` 和 Mock 夹具都按这个走）；要押牌且没押 → 押 `view.kept` 第一张；然后 `wheel.spin`；揭晓后（本月运势）`month.begin`；关。动画在自动一步里直接跳到结果。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C06.json`（`c06.` 开头，键 + `brief`，`_meta._provenance`）：`c06.btn.spin` `c06.btn.continue` `c06.incense.title` `c06.cost.money`（`{n}`）`c06.cost.stake` `c06.stake.pick` `c06.title.<month|big|fair|gamble>`（轮盘名也可以用 `wh.<id>#title`，二选一，PR 写明）。
- [ ] **夹具**（`scripts/tests/cards/C06/fixtures/`，`_meta.owner = "C06"`）：W0 的 `month_open` / `month_wheel` 之外，`month_widen.json`（`wheel.offer` 的回应把好段的 `arc_deg` 变大、其余变小）、`big.json`（手上 `bf.wheel`，三类段）、`fair.json`（花钱的庙会）、`gamble_stake.json`（押牌的赌摊；先 `stake_required`，押了再转）、`no_money.json`（`insufficient_money`）。每个夹具的 `wheel.spin` 回应都给 `stop_deg`，且落在它说的那一段的角度里。夹具过 `t.no_leaks()`（WheelView 里不许有 `weight` `units` `valence` `arc` 等黑名单键）。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] 所有轮盘面板随时能关：关了不发指令，香案上放的东西留着（转之前都能 `wheel.withdraw` 拿回来）；打烊时还没转，引擎会把香案上的东西和押的牌还回来（`bf.wheel` 这张作废——这次大轮盘错过了）。
- [ ] 本月运势：月初没转就关了面板，牌桌上的“打烊 · 下一天”会先弹确认（清单一行 `auto_spin`），确认后引擎替玩家转；你的面板要能显示引擎替转的结果（`wheel_spun` 事件 + `query("wheel")` 的 `spun`/`result`），下次打开看到的是已经转过的盘。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] 轮盘仍是叠层（`overlay`），做法不变。C01 开轮盘之前会让场景层按这张牌的演出块换背景（例：庙会换 `bg.temple`），你不用管；轮盘面板背后能看见画面，`shade` 照旧。本月运势由引擎要求打开、或从开月过场之后打开，都不变。

**新增 / 作废的交付**

- 没有新增；也没有作废的。

**锚点、界面事件、要证明的步骤**

- 不变。

**测试与截图**

- 截图改成画面版（叠在场景上）：本月运势、放香以后变宽、停针、大轮盘、押牌各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 全部。

## 只能改这些文件

- `scenes/cards/wheel/**`、`scripts/cards/ui/wheel/**`
- 默认拥有：`scripts/tests/cards/C06/**`、`scripts/tests/cards/suites/C06.txt`、`data/cards/tags/C06.json`、`data/cards/ui_keys/C06.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（C03 的 SlotWidget 只调用；`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、旧代码）。
2. **不写最终内容**：段名、段的正文、代价的文字由人写；不画正式的轮盘面（底图经 `CardArt`，占位由 K12 出）；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文；扇区颜色只用配色键。
3. **不露隐藏数值**：不显示权重、份数、加宽了多少、好坏、概率、`%`、任何阿拉伯数字；扇区只有大小。
4. 不放规则：不自己算 `arc_deg`、不自己选段、不自己判断钱够不够；停针角度只照 `stop_deg`。
5. 不用随机影响结果（转几整圈这类装饰可以用固定种子的 `RandomNumberGenerator`，不影响 `stop_deg`）；不加冻结表以外的 `class_name`；不加 autoload/InputMap。
6. 不发 `first_time`；`slot_drop` 由 SlotWidget 发。

## 接口

**用到**：查询 `wheel {wheel, uid}`（WheelView，§9.1）、`card {uid}`；指令 `wheel.offer {wheel, uid, source}`、`wheel.withdraw {wheel, uid, index}`、`wheel.stake {wheel, uid, kept_uid}`、`wheel.spin {wheel, uid}` → `{segment, stop_deg}`、`month.begin`；视图 `kept` `contacts` `self` `money`；总线 `view_changed` `wheel_spun(wheel_id, segment_id, stop_deg)`（别处触发的转也能播）`card_left`；C03 `CardSlotWidget`；`CardText.card/ui`、`CardArt`、`CardTheme`、`CardAnchors`。

**提供（冻结）**：`CardWheelPanel`（`CardPanel` 接口）。新增（PR 列出）：本月运势揭晓后由本面板发 `month.begin`。

## 新手指引

- **必须登记的锚点**：`a.wheel.face`（盘面）`a.wheel.incense`（香案格）`a.wheel.cost`（代价那块：花钱或押牌）`a.wheel.spin`（转的按钮）。
- **必须发的 ui_event**：无（`slot_drop` 由 SlotWidget 发；宿主发 `panel_opened {kind: "wheel"}`）。
- **first-time**：不发；依赖 `month_wheel` `incense` `big_wheel` `fair_wheel` `gamble_wheel` `wheel_stake`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.m.wheel`（第一次要转本月运势 → `a.wheel.face`）、`gd.m.incense`（`after: gd.m.wheel`，放香之前先亮 → `a.wheel.incense`；完成于放下东西 `ui:slot_drop` 或 `first:incense`）、`gd.big_wheel`（第一张 `bf.wheel` → `a.card@{uid}`，面板开着时备用 `a.wheel.face`）、`gd.fair_wheel`（→ `a.wheel.cost`）、`gd.gamble_wheel`（→ `a.wheel.cost`）。
- **测试做法**：开 `wheel` 面板（夹具）或用牌桌宿主 + W0 的 `month_open` 夹具；挂指引（`force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"month_wheel", {})` → `evaluate_now()` → `active_step() == "gd.m.wheel"`；完成后 `gd.m.incense` 接着亮；往香案放东西后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C06.txt`：

```
# C06 命运轮盘（docs/handoff_cards/C06_wheel.md）
C06_month|res://scripts/tests/cards/C06/test_month.gd|180|
C06_stop_angle|res://scripts/tests/cards/C06/test_stop_angle.gd|120|
C06_kinds|res://scripts/tests/cards/C06/test_kinds.gd|180|
C06_no_numbers|res://scripts/tests/cards/C06/test_no_numbers.gd|120|
C06_guide|res://scripts/tests/cards/C06/test_guide.gd|180|
```

| 测试 | 通过条件 |
|---|---|
| `test_month.gd` | 本月运势：没转前关掉不发任何指令、`mock.sent` 不变；放香 → `wheel.offer {wheel: "wh.month", uid: "", source}`；拿回 → `wheel.withdraw`；`month_widen` 的回应后，好段节点的角度大小**单调变大**、其余变小、总和 360；转 → 揭晓 → “继续” → `mock.sent` 里有 `month.begin` |
| `test_stop_angle.gd` | 每个夹具：动画结束（或 `skip`）后读盘面/指针节点的旋转，换算成相对 12 点钟的角度，和 `stop_deg` 相差 ≤ 0.5°，且落在选中段的角度范围里（由 `segments` 的 `arc_deg` 顺时针累加算出） |
| `test_kinds.gd` | 大轮盘、庙会（花钱）、赌摊（押牌：先 `stake_required` 显示原因，押 `wheel.stake {wheel, uid, kept_uid}` 后再转）各走通；`no_money` 显示原因正文、不播转动 |
| `test_no_numbers.gd` | 每个夹具、转前转后：面板里所有 Label/Button/RichTextLabel 的文字不含 `[0-9]`（唯一例外是代价那一行：它是带参数 `{n}` 的界面键，数字怎么写由 A 定——合同“界面上没有任何数字”和“庙会要花钱”之间的取舍已报编排）、不含 `%`；`t.all_text_from_cardtext()` 为空；夹具 `t.no_leaks()` |
| `test_guide.gd` | 五个步骤按做法亮、完成；四个锚点 `t.anchor_ok()` |

另：`autoplay_step()` 能把每个夹具走完；动画单段 ≤ 0.6 秒（揭晓前的缓停可以分几段，每段 ≤ 0.6 秒）；打开面板 ≤ 50 ms。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集、新局：开月 → 本月运势放香、转、`month.begin`，停针与引擎的 `fate.wheels` 结果一致）；清单加一行 `C06_guide_k16|res://scripts/tests/cards/C06/test_guide.gd|180|--steps=k16 --name=C06_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C06 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C06/shot_wheel.gd -- --out=/tmp/shots/C06
  ```
- **截图**（不进清单）：本月运势空香案、放了香（好段变宽）、转动中、揭晓各一张；大轮盘、庙会、赌摊（押牌）各一张；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图（1.3：轮盘叠在场景上拍，见上方“10-13 变更二”）；上传 PR 或提交到 `scripts/tests/cards/C06/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：盘面 480×480 整数倍；面板居中 ≤ 1100×640；扇区只有大小；“快动画”时直接停到结果（~~读开关的接口没冻结，先开 `[shared]` issue、留 `fast_anim` 布尔、标 `# TODO(shared#<issue号>)`~~ 1.3：用冻结的静态读取 `CardSettings.fast_anim()`，合同 §7.8）；键盘：Space/Enter 转或继续、Tab 在香案和按钮间移动、Esc 关~~（本月运势没转前不能关）~~（10-13 作废：没有关不掉的面板，本月运势没转也能关，见上方“10-13 变更”）。

## 交付

- PR 标题 `[C06] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①盘面 + 停针 + 本月运势 + 测试；②香案加宽动画、代价、押牌、三种皮、截图；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；新公开函数与“谁发 `month.begin`”；需要决定的事（~~CardView 的 `wheel` 字段~~ 1.3 已有、代价的显示）；性能数；“回报”。

## 审核（Claude 重点）

- 停针角度和 `stop_deg` 一致（测试读节点旋转）；扇区顺序从 12 点钟顺时针、按数据顺序。
- 界面上没有任何数字、`%`、好坏着色；香案加宽是动画、可以看出来。
- 指令都带 `wheel` 和 `uid`（本月运势 `uid: ""`）；`month.begin` 只在本月运势揭晓后发一次。

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
