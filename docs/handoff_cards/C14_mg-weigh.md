# C14 `mg-weigh` · 称分量

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C14 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C14: …` 报给 Claude。

> **鉴定改版（主创 10-25：“你那个鉴定不能只是点点点，要玩家看出来才算数”）**：本卡下文凡和合同 §3.3、§4.8、§8、附录 H 对不上的，以合同为准。称分量改成“自己看定盘针、自己数星、自己比”：参数多了 `small_fen` `zoom` `minor_ticks` `needle_gain`，砝码套每个模板都压得平；支点不再亮金点，面板不写结论；结果交 `measures.call`（1 对得上 … 5 说不好）`read_fen` `commits`；新锚点 `a.mg.weigh.call`。下文“游戏读数、游戏比较”的旧说法作废。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 14**（在第 14 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C14`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）：小游戏基类 `CardMiniGame`、宿主 `CardMiniGameHost`（C01）、例子集里的观察键目录 `data/cards/_examples/minigames/obs/weigh.json`（§4.8 的例子，正式目录由你写）。W2 接 G04 给的真参数（物理量由 K11 的 `it.*` 规格算出）。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎的集成测试和 K16 步骤复测。

## 分支

`cards/C14-mg-weigh`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

金银、米、药材的鉴定小游戏：用戥子（小秤）或杆秤，往秤盘加减砝码、拨秤砣，看秤杆平不平（简单物理），读数；和客人说的分量比。**只给观察**：“对得上”“轻一点点”“轻不少”“重了”“好像轻一些，没压稳”“没称准”——永远不说“掺假/补过”。单位用整数“分”（1 钱 = 10 分）。

## 必读

1. `docs/cards/DESIGN_cards.md` §一“示例：第 9 天”（称分量：比她说的轻一点点）、§三.2（鉴定小游戏：称分量）、附录“史实核对与来源”（金饰、碎银、药材用戥子称）。
2. `docs/cards/CARDS_INTERFACES.md`：§0（红线 5）、§3.3 C14、§4.7.15（`weigh` 规格：`claimed_fen` `dev_bad_pct`…只有引擎读）、§4.8（观察键目录，**例子就是 `weigh.json`**）、§6.3（随机域 `c.mg.weigh.layout`）、§7.10.5、§8（插件接口；`weigh` 参数 `tool: "dengzi"/"steelyard"`、`claimed_fen`、`actual_fen`、`weights_fen`、`resolution_fen`；`measures`：`read_fen` `steps`）、§11.2、§12.2、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/api/card_minigame.gd`、`scripts/cards/minigames/weigh/weigh_game.gd` 与 `scenes/cards/minigames/weigh/WeighGame.tscn`（W0 桩）、`scripts/cards/mock/example_minigame.gd`（`observations_for` 里有一个最简单的称分量观察，可以对照）、`scripts/cards/ui/table/minigame_host.gd`、`data/cards/_examples/minigames/{items,obs/weigh}.json`。

## 要做的事

- [ ] **CardWeighGame**（`weigh_game.gd`，`class_name CardWeighGame`，**改成 `extends CardMiniGame`**）：`kind()` → `&"weigh"`；`start(params)` 只用参数；`autoplay(skill)`；`abort()` 用基类的；分钟数按操作步数算（`minutes_per_step`，不超过 `max_minutes`）。
- [ ] **秤**（代码画：秤杆、秤盘、秤砣、星点刻度——只用配色键）：
  - 戥子 `dengzi`：小、精；杆秤 `steelyard`：大、粗。东西放在秤盘上（图 `CardArt.texture(params.art)`，整数倍、NEAREST）。
  - 物理（整数“分”，内部可以用浮点）：秤盘一侧的力矩 = `actual_fen` + 盘里的砝码；另一侧 = 秤砣位置的刻度读数；差值决定秤杆倾角（阻尼 Tween，单段 ≤ 0.6 秒）；差值在 `resolution_fen` 以内算“平了”。
  - 操作：加/减砝码（`weights_fen` 里的那几个，拖进/拖出秤盘或点选）、左右拨秤砣（一格 = `resolution_fen`）、“读数”（平了以后读出 `read_fen`；没平就读，读数带偏差 → 观察偏含糊）。每步 `steps += 1`。
  - 客人说的分量 `claimed_fen` 用带参数的界面键显示（`c14.claimed`，参数 `{qian}` `{fen}`，A 写成“几钱几分”）。**`actual_fen` 永远不直接显示**——读数只来自玩家自己把秤杆压平后读出来的刻度（刻度上可以有数字，那是秤上本来就有的星点，属于看得见的工具）。
  - 每个操作发 `ui_event("mg_tool", {"kind": "weigh", "tool": "weight"|"poise"|"read"})`。Esc → `abort()`。
- [ ] **结果**：`{"quality_permille": <整数>, "observations": [...], "minutes": n, "measures": {"read_fen": n, "steps": n}, "aborted": false}`。观察：没读数 → `obs.weigh.unsure`；读数时秤杆没平 → `light_vague` 或 `unsure`；平了：`read_fen` 和 `claimed_fen` 差在 `resolution_fen` 内 → `match`；轻一点点 → `light_small`；轻不少 → `light_much`；重 → `heavy`（阈值写成常量，PR 里列出）。`quality_permille` 由“压平了没有、步数、读数误差”算。
- [ ] **autoplay(skill)**：走和玩家同一条代码路径（模拟加砝码、拨秤砣、读数）；skill 高 → 压平再读；skill 低 → 没压平就读。`autoplay(0.2)` 与 `autoplay(0.9)` 清晰度不同；同参数同 skill 同结果。砝码的初始摆放、秤砣起点用 `JevRng.draw(params.seed, "c.mg.weigh.layout", [i])`。
- [ ] **观察键目录** `data/cards/minigames/obs/weigh.json`（`{"_meta": {"owner": "C14", "schema": 1, "kind": "weigh", "_provenance": {...}}, "obs": {...}}`）：至少 §4.8 例子里的六个键（`match` `light_small` `light_much` `heavy` `light_vague` `unsure`），每个带 `fidelity` 和 `brief`（只写观察的意思，不写判词、不写成观察句正文）。
- [ ] **键盘可玩**：1–9 选砝码放上/拿下、←/→ 拨秤砣、Enter 读数、F 交、Esc 放弃。
- [ ] **界面键** `data/cards/ui_keys/C14.json`（`c14.` 开头，键 + `brief`，`_meta._provenance`）：`c14.title` `c14.tool.<dengzi|steelyard>` `c14.claimed`（`{qian}` `{fen}`）`c14.btn.read` `c14.btn.done` `c14.tool.<weight|poise|read>`。
- [ ] **参数夹具**（`scripts/tests/cards/C14/fixtures/`）：`match.json`（实际 = 说的）、`light_small.json`（轻 4%）、`light_much.json`（轻 12%）、`heavy.json`、`steelyard_rice.json`（杆秤、米、粗分辨率）。只放 §8.2 允许的键。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- 合同 1.3 不影响本任务的玩法、参数、结果格式和冻结接口；只改截图。
- 小游戏仍由 C01 的宿主开在叠层之上；入口变成柜台那一出里的“细看”回话或柜台上的放大镜（都发 `mg.request`，C04 做），对你没有影响；小游戏框外的“算了”按钮照旧由 C01 放。

**新增 / 作废的交付**

- 没有新增；也没有作废的。

**锚点、界面事件、要证明的步骤**

- 不变。

**测试与截图**

- 测试不变。
- 截图改成画面版：小游戏叠在柜台画面上（背后看得见客人和柜台），清单照原卡。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 全部。

## 只能改这些文件

- `scenes/cards/minigames/weigh/**`、`scripts/cards/minigames/weigh/**`、`data/cards/minigames/obs/weigh.json`
- 默认拥有：`scripts/tests/cards/C14/**`、`scripts/tests/cards/suites/C14.txt`、`data/cards/tags/C14.json`、`data/cards/ui_keys/C14.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`scripts/cards/api/**`、`mock/**`（含 `example_minigame.gd`、例子集的 `weigh.json`）、C01 的宿主、`data/cards/minigames/items.json`（归 K11）、旧代码）。
2. **不判真假**：观察键无判词；不显示“补过/掺假/足金”；不显示 `actual_fen`、差了百分之几、`%`。
3. **不写最终内容**：观察句、按钮字、“几钱几分”的写法由人写；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
4. 不写颜色字面量（秤杆、刻度只用配色键）。
5. 随机只用 `JevRng.draw(params.seed, "c.mg.weigh.layout", [i])`；不加 `class_name`（`CardWeighGame` 除外）；不加 autoload/InputMap。
6. 不发 `first_time`；只发 `mg_tool`。

## 接口

**用到**：`CardMiniGame`（§8.1）；参数（§8.2 公共字段 + `tool` `claimed_fen` `actual_fen` `weights_fen` `resolution_fen`）；`JevRng.draw`；`CardArt`、`CardText.ui/obs`、`CardTheme`、`CardAnchors`；`CardBus.ui_event`。

**提供（冻结）**：`CardWeighGame`（`res://scenes/cards/minigames/weigh/WeighGame.tscn`）；观察键目录 `obs/weigh.json`。

## 新手指引

- **必须登记的锚点**：`a.mg.weigh.main`（整块）`a.mg.weigh.weights`（砝码那一排）`a.mg.weigh.beam`（秤杆）。
- **必须发的 ui_event**：`mg_tool {kind: "weigh", tool}`。
- **first-time**：不发；依赖 `mg.weigh`。
- **要证明会亮的步骤**：`gd.mg.weigh`（第一次出称分量 → `a.mg.weigh.weights`；教的人默认 `obj.brother_ledger`）。
- **测试做法**：实例化 `WeighGame.tscn`、`start(<match params>)`；挂指引（`GuideOverlay.tscn`，`bind(mock, bus)` → `force(true)` → `skip_fades = true` → `load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"mg.weigh", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.mg.weigh"`；放一个砝码（`mg_tool`）后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C14.txt`：

```
# C14 称分量（docs/handoff_cards/C14_mg-weigh.md）
C14_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/minigames/obs/weigh.json --name=C14_validate
C14_physics|res://scripts/tests/cards/C14/test_physics.gd|120|
C14_determinism|res://scripts/tests/cards/C14/test_determinism.gd|120|
C14_fidelity|res://scripts/tests/cards/C14/test_fidelity.gd|120|
C14_controls|res://scripts/tests/cards/C14/test_controls.gd|120|
C14_guide|res://scripts/tests/cards/C14/test_guide.gd|120|
```

| 测试 | 通过条件 |
|---|---|
| `C14_validate` | 观察键目录过校验器（V23） |
| `test_physics.gd` | 压平后读出的 `read_fen` 与 `actual_fen` 的差 ≤ `resolution_fen`；四个参数夹具压平读数后分别得到 `match` / `light_small` / `light_much` / `heavy`；没压平就读得到含糊的观察 |
| `test_determinism.gd` | 同参数 + 同一串操作两遍结果相同；`autoplay(0.5)` 两遍相同 |
| `test_fidelity.gd` | `autoplay(0.2)` 与 `autoplay(0.9)` 清晰度不同；结果只有 §8.1 的五个键；`quality_permille` 整数；`measures` 只有整数 `read_fen` `steps`；观察键都在目录里 |
| `test_controls.gd` | 键盘能玩完一局；Esc → `aborted: true`；每个操作有 `mg_tool`；界面上任何文字都不含 `actual_fen` 的值、不含 `%`；`t.all_text_from_cardtext()` 为空（秤上的刻度数字只由数字组成，合格） |
| `test_guide.gd` | `gd.mg.weigh` 按做法亮、完成；三个锚点 `t.anchor_ok()` |

另：每帧 CPU ≤ 4 ms（PR 列数）；面板 ≤ 1100×640；无头无报错。

- **W2 加**：`test_real_engine.gd`（真引擎：来当金簪且这次出称分量 → G04 的参数 → `autoplay(0.8)` → `mg.report` 成功）；清单加一行 `C14_guide_k16|res://scripts/tests/cards/C14/test_guide.gd|180|--steps=k16 --name=C14_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C14 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C14/shot_weigh.gd -- --out=/tmp/shots/C14
  ```
- **截图**（不进清单）：戥子开局、秤杆歪着、压平、读数后、杆秤称米各一张；`guide_gd.mg.weigh.png`。1280×720 画面截图（1.3：小游戏叠在柜台画面上拍，见上方“10-13 变更二”）；上传 PR 或提交到 `scripts/tests/cards/C14/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：秤是代码画的，线条干净、只用配色键；物品图整数倍、NEAREST；面板 ≤ 1100×640。

## 交付

- PR 标题 `[C14] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①物理 + 结果 + 观察目录 + 测试；②秤的画法、拖砝码、键盘、截图；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；**用到的 JevRng 域：`c.mg.weigh.layout`**；锚点、`mg_tool`、依赖的 first-time；观察阈值常量；给 A 的观察句待写清单；性能数；“回报”。

## 审核（Claude 重点）

- 界面上看不到 `actual_fen`；观察无判词；读数只来自压平的秤杆。
- 同参数同操作同结果；`autoplay` 两档清晰度不同；随机只用 `c.mg.weigh.layout`。
- 秤是代码画的、只用配色键；没有中文/颜色字面量。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / mg_tool / 证明会亮的步骤 | |
| 观察键清单（给 A） | |
| 性能实测 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
