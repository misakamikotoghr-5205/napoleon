# K14 `qa-automation` · QA 自动化、截图、指引走查、问题模板

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K14 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K14: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 14**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | `CardGame.tscn`（`CardGameRoot`：`boot(opts)`、`autoplay_step()`、`guide`、`host`、`engine`、`--cards-autoplay`）、Mock 情景模式（一关 30 天）与十个基础夹具、`CardGuide` 的测试钩子（`force` `skip_fades` `tick` `evaluate_now` `shown_log`）、`card_t.gd`（`spy` `anchor_ok` `all_text_from_cardtext` `find_floats` `user_dir`）、`scripts/tests/cards/W0/{test_table_3days,shot_table}.gd`（现成的做法） | W0（已完成） |
| C01–C16 | 真界面：各面板的 `autoplay_step()`、锚点、`ui_event`；C16 的指引引擎；**1.3：画面版截图要 C01 的画面根（目标 10-27）** | W1（滚动合入；你对着当时的集成分支跑） |
| K16 | `data/cards/guide/steps.json` 的 `_test.d1_3`（第 1–3 天应当按顺序亮的步骤） | W1 |
| G01–G06 | 真引擎（`CardEngine`）、`command_log()`、`ctx.state.hash()`、`CardReplay.replay()` | W1 合入后 |
| Claude（W2） | 把 `CardGame` 默认换成真引擎（§13.4 W2）；`boot(opts)` 能吃 `seed` 和测试用的存档目录 | W2 |

- **波次**：W1 对着 Mock 搭好整套走查、截图、问题模板；**W2**：真引擎上的整局走查、三关截图，以及**合同点名的第 1–3 天指引走查与逐步截图**（**W2 完成条件之一**：“新存档第 1–3 天的指引测试在真引擎上绿、每一步有截图”）。

## 分支

`cards/K14-qa-automation`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

用真界面（`CardGame.tscn` + 各面板的 `autoplay_step()`）把游戏自动走一遍，在关键处截图、查红线，并做新手指引的端到端验收：**新存档第 1–3 天，指引步骤按规定顺序亮；开着和关着指引，同一串指令的状态哈希相同；每一步一张截图**。另给人用的问题模板和试玩清单。

## 必读

1. 合同 §0（红线全部——你的检查清单就是它们）、§1.2（分辨率、分区、输入、新手指引那一行）、§2.2、§3.4 K14、§6.1（`ui` 命名空间不进哈希）、§6.3（`c.qa.<x>` 是你的随机域）、§7.2（`CardEngineApi`）、§7.5（视图隐藏键黑名单）、§7.6（总线信号、`ui_event`）、§7.7（Mock 与夹具）、§7.8（`CardPanel.autoplay_step()`、面板表、`CardGameRoot`）、**§7.10 全节**（尤其 §7.10.7 `CardGuide` 的测试钩子、§7.10.8 `--guide=` 与自动试玩默认关、**§7.10.9 K14 一行**、§7.10.10 的 `_test.d1_3` 起步顺序与七处冲突、§7.10.11 教学日）、§12.1–§12.4（测试登记、截图做法、性能）、§13.4（W2 完成条件）、§14.2（审核清单——你的试玩清单要覆盖它的界面部分）、**§1.2（1.3 改写）、§7.8 的“呈现”一列、§7.11（画面与演出，1.3 新）、§12.3（1.3：画面截图）**。
2. `docs/cards/DESIGN_cards.md` §一（一天怎么过）、§四（一关）、§九.4（新手指引的主创原话与节奏）。
3. W0 代码：`scripts/cards/ui/table/card_game_root.gd`（`boot`、`autoplay_step`、`_cmdline_opts`）、`scripts/cards/mock/{mock_engine,mock_scenario}.gd`、`scripts/cards/ui/shell/card_guide.gd`、`scripts/tests/cards/W0/test_table_3days.gd`（**第 1–3 天指引在牌桌上按顺序亮的现成写法：每个 `autoplay_step()` 后 `await t.frames(1)`、`guide.tick(0.5)`、`guide.evaluate_now()`**）、`scripts/tests/cards/W0/shot_table.gd`（截图：等帧 + `RenderingServer.frame_post_draw` 后存视口图）、`scripts/tests/cards/lib/card_t.gd`、`scripts/cards/sim/replay.gd`（G06）、`scripts/cards/loop/card_engine.gd`（`ctx`、`command_log()`）。
4. 现有的旧版截图脚本 `scripts/tests/shot_walkin.gd`（只读参考）。

## 要做的事

### A. 整局走查 `scripts/tests/cards/K14/play_ui.gd`（无头，进清单）
- [ ] `extends SceneTree`；加载 `CardGame.tscn`，`boot({"bus": bus, "seed": <n>, "skip_title": true, "guide": "off"})`（**默认 `--guide=off`**，§7.10.8）；命令行参数（`--` 之后）：`--engine=mock|real`（W1 只有 mock；W2 起默认 real）、`--seed=<n>`、`--days=<n>`（W1 默认 30 = Mock 情景一关；W2 默认三关）、`--guide=on|off`、`--shots=<目录>`（给了才截图——无头下不截）、`--name=<清单名>`。
- [ ] 循环 `game.autoplay_step()`（每步后 `await` 一帧），直到走完 `--days` 或进入 `game_over`；步数上限防卡死（卡住 = 连续 N 步视图不变 → `FAIL`，打印当时的阶段和最上面的面板）。
- [ ] 每一步检查（违反一条就记一个失败，最后汇总）：`CardViewModel.leaks(engine.view())` 为空；最上面的面板和牌桌上所有可见的 `Label` / `RichTextLabel` / `Button` 文字里没有 `%`；`t.all_text_from_cardtext(<面板或牌桌>)` 为空（界面上的字都来自 CardText；1.3：扫整个画面 `game`，含对话框和回话，见下方“10-13 变更二”）；每条指令以 `command_done`、`view_changed` 收尾（`t.spy(bus)`）。
- [ ] 结束时：打印走过的阶段、打开过的面板 kind 集合、亮过的小游戏 kind；断言至少打开过 `counter` `slots` `night` `settle` `month_close` 五种面板（Mock 一关）——W2 加 `wheel` `fortune` `demand` `year_jump`。（1.3 另断言打开过的 `show` 三种都出现过，见下方“10-13 变更二”。）
- [ ] 截图（`--shots=` 时，xvfb 下）：~~关键处各一张 1280×720：开月、本月运势轮盘、柜台、每种出现过的小游戏、条子、夜、日结、月底、跳年、档案簿、街头、牢房~~（10-13 作废，合同 1.3：改成画面版的 1280×720 画面截图，清单见下方“10-13 变更二”）（Mock 情景里没有的——街头、牢房、跳年——用 W0 的夹具 `street_prison` `year_jump` 补拍），文件名 `<序号>_<阶段>_<面板>.png`。

### B. 截图工具
- [ ] `tools/cards/qa/shots.sh`：`xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/cards/K14/play_ui.gd -- --shots=<目录> …`；没有 `xvfb-run` 时只跑无头流程、打印 `NOTE: no xvfb, screenshots skipped`。再调下面两个脚本出拼图和比对。
- [ ] `scripts/tests/cards/K14/sheet.gd`（不进清单）：把一个目录里的截图按文件名排成拼图（Godot 的 `Image.blit_rect`，缩成 1/4）——**拼图用 GDScript 做，不用 Python 第三方包**（§12.7）。
- [ ] `scripts/tests/cards/K14/compare_shots.gd`（不进清单）：两个目录逐张比像素，必须完全一样（同种子两次截图像素一致，§3.4 K14）；不一样的打印文件名和第一处不同的坐标。

### C. 指引走查
- [ ] **W1（Mock）** `scripts/tests/cards/K14/test_guide_onoff_mock.gd`（无头，进清单）：Mock 情景、种子 7，用 `autoplay_step()` 走 7 天，跑两遍——一遍 `guide.force(true)`、`skip_fades = true`、每步后 `tick(0.5)` + `evaluate_now()`；一遍 `force(false)`。断言：两遍 `mock.sent` 去掉 `ui.guide` 之后**完全相同**（指引不改变玩家/自动试玩的任何操作）；开着那遍 `shown_log` 里每一步都在当前步骤数据里、没有一步超过 `max_shows`；关着那遍 `mock.sent` 里没有任何 `ui.guide`。
- [ ] **W2（真引擎，合同点名）** `scripts/tests/cards/K14/test_guide_d1_3.gd`（无头，进清单）：真引擎、**种子 7、新存档**（存档目录用 `t.user_dir()`，不碰 `user://cards/`）、`guide.force(true)`、`skip_fades = true`；用各面板的 `autoplay_step()` 走开局 + 第 1–3 天（虚拟时钟：每个 `autoplay_step()` 之后 `tick(0.5)` 再 `evaluate_now()`），停在第 4 天早上。断言：
  1. `CardGuide.shown_log` **按顺序等于** `data/cards/guide/steps.json` 的 `_test.d1_3`（`_test` 用 `CardDB.read_json` 直接读——`guide_data` 查询会剥掉它）；
  2. `_test.d1_3` 里每一步都发了 `ui.guide shown` 和 `done`，`query("guide_progress")` 里都是 `done`；
  3. 记下 `engine.command_log()` 和 `engine.ctx.state.hash()`；**同一串指令关着指引再走一遍**（`force(false)`，同样的 `autoplay_step()` 序列）：`command_log()` 相同、状态哈希相同；再用 `CardReplay.replay({seed: 7, …}, log)` 无头回放，哈希相同（G06 的 `CardReplay` 还是桩时这一小项跳过并打印 `NOTE`）；
  4. 第 1–3 天的 `first_time` 串（`t.spy(bus)`）和 G02 的 `scripts/tests/cards/G02/golden/firsts_d1_3.json` 一致（文件还没有时跳过并打印 `NOTE`）。
- [ ] **逐步截图** `scripts/tests/cards/K14/shot_guide_d1_3.gd`（不进清单，xvfb）：同上的走法，每一步亮起时截一张 1280×720 画面截图（1.3：看得见教的人站在柜台一侧或批注纸、锚点发光、气泡），文件名 `<步骤 id>.png`（例 `gd.d1.deal.png`），另出一张拼图 `guide_d1_3_sheet.png`；PR 附拼图和单张。

### D. 文档 `docs/cards/qa/`
- [ ] `README.md`：每个脚本干什么、怎么跑（有/没有 xvfb）、输出在哪、W1/W2 各跑哪些。
- [ ] `bug_template.md`：标题格式 `[bug] <任务ID?>: …`、种子、存档、阶段与第几天、复现步骤（指令序列或 `autoplay_step` 步数）、截图、期望/实际、违反哪条红线（§0 的 1–9）、日志最后 20 行。
- [ ] `playtest_checklist.md`：人试玩时逐条看——**红线逐条检查**：界面上有没有数字化的口碑/风声/概率/权重/底价/真假/本心泄露、有没有 `%`、小游戏有没有判词（“真”“假”“仿”“赝”）、有没有**没教就出现的机制**（新机制第一次出现时有没有指引亮、能不能在档案簿“规矩”栏和 F1 里回看）、指引关掉后一切照常、指引不挡点击和按键、键盘全流程（Esc、Enter、Space、1–9、Tab、F1）、金色牌一眼能认、草稿样式明显、整数倍像素、面板不超出 1100×640；史实措辞（伪字等）。

### E. 随机
- [ ] 需要随机（例：随机点按钮的模糊测试）只用 `JevRng.draw(seed, "c.qa.<名>", key)`（§6.3 归你的域）；清单里的测试必须确定。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] `play_ui.gd` 加一个模式 `--chaos`（清单加一行 `K14_next_day_chaos|res://scripts/tests/cards/K14/play_ui.gd|600|--engine=mock --seed=7 --days=10 --chaos --name=K14_next_day_chaos`）：走查中每一步按 `c.qa.chaos` 随机做下面之一——照常 `autoplay_step()`、按牌桌上的“打烊 · 下一天”按钮（真的点按钮节点）、在确认面板里随机点“打烊”或“回去看看”、对最上层面板按 Esc、打开小游戏后 Esc；断言：永远回得到牌桌（`host.top_panel() == null` 在若干步内出现）、天数一直往前走、没有面板关不掉、没有面板关掉后自己弹回来、日志没有 ERROR。W2 加一行 `--engine=real`。
- [ ] `playtest_checklist.md` 加“**红线 9：打烊永远可用**”一节：街头、牢房、每种面板开着、小游戏开着、留牌满、钱不够、月初没转运势时，“打烊 · 下一天”都按得到（关掉面板就回牌桌）；确认面板列的每一行和第二天看到的结果对得上；没有任何东西因为“时间到了”自己往前走。
- [ ] `bug_template.md` 的“违反哪条红线”改成 1–9。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **`play_ui.gd`**：照旧只用 `game.autoplay_step()`（它已经会跳过对话框、点回话、开关抽屉）；每一步的检查加：对话框和回话里的字也都来自 CardText（`t.all_text_from_cardtext(game)` 扫整个画面）、没有 `%`；结束时断言打开过的 `show` 三种都出现过（`stage` `drawer_l`/`drawer_r` `overlay`）——从 `t.spy(bus)` 收到的 `ui_event panel_opened {kind, show}` 里数；C01 的画面根合入（10-27）之前宿主发的 `panel_opened` 还没有 `show`，按 `CardIds.PANEL_SHOW[kind]` 算，三种不全时只打印 `NOTE: show not covered <show>`，合入之后才断言。
- [ ] **`--chaos` 加三种乱按**（`c.qa.chaos` 挑，和 1.2 的几种放在一起）：①随机打开/收回抽屉——在两侧标签的锚点（`a.tab.contacts` … `a.tab.settings`，`CardIds.TABS_L` / `TABS_R`）矩形中心发一次鼠标点击打开，再随机点遮罩、点“合上”或按 Esc 收回；②对话框随机点“跳过”——`game.dialog.skip()`（C01 的公开变量 `dialog`，类型 `CardDialogApi`）；③演出中随机按“回头再说”——就是这一出的“算了”：按 Esc，或对 `game.host.top_panel()` 调 `dismiss()`（合同 §7.8：`counter` → `counter.close`、`night` → `night.choose {def: ""}`、其余只收场、牌留在手上）。断言照旧（永远回得到空柜台的画面、天数往前走、没有关不掉的东西）。C01 的画面根合入之前 `game` 没有 `dialog` 和标签，①②跳过并打印 `NOTE`。
- [ ] **截图（`--shots=`）改成画面版**（1280×720 画面截图，合同 §12.3）：开月过场、本月运势、客人走进门、柜台那一出（三档价回话）、细看小游戏、条子那一出、柜台上的格子与铜钱、夜里的夜牌扇、日结说到一半、月底、跳年、档案簿抽屉、货架抽屉、街头画面、牢房那一出、黄昏的柜台；文件名照旧（`<序号>_<阶段>_<面板>.png`）。Mock 情景里没有的——街头、牢房、跳年——照旧用 W0 的夹具 `street_prison` `year_jump` 补拍；黄昏的柜台在 Mock 情景里处理掉今天六成的牌以后自然出现（`view.stage.time == "dusk"` 时拍）；对话说到一半：在一出开演、对话框 `is_idle()` 为假时拍。
- [ ] **`playtest_checklist.md` 加“画面与对话”一节**：一张牌打出后人上场、对话一句一句、回话就是选择；三档价、天数、铜钱数以外没有数字；口碑风声只有字；抽屉开关、热点都能点；白天到黄昏到夜里；“打烊 · 下一天”在抽屉上面照样能按；字不糊（整数倍）。
- [ ] **W2 的 `shot_guide_d1_3.gd`** 每一步一张画面截图（看得见教的人站在柜台一侧或批注纸、锚点发光、气泡）。
- 画面版截图要等 C01 的画面根合入（目标 10-27，交接页的硬依赖）；之前对着 W0 的桩拍的只算试跑，不贴 PR。

**新增 / 作废的交付**

- 新增：`--chaos` 的三种乱按、`play_ui.gd` 的 `show` 统计、画面版截图清单、试玩清单的“画面与对话”一节。
- 作废：上文 A 节 1.2 的截图清单（“关键处各一张 1280×720”那一串），换成上面的画面版清单。

**锚点、界面事件、要证明的步骤**

- QA 照旧不登记锚点、不发界面事件，只听。1.3 的界面事件（合同 §7.10.5）可以拿来断言和统计：`panel_opened` / `panel_closed {kind, show}`、`drawer_opened` / `drawer_closed {kind, side}`、`hotspot_pressed {id}`（C01）、`hand_selected`（1.3 起由 C02 发）、`hand_played {uid, def, how}`（C02）、`dialog_advanced` `dialog_skipped` `reply_chosen`（C04）。
- 锚点用 1.3 的名字（合同 §7.10.5 的新表与 7 个改名）；W1 里旧名还登记得上、指引新旧互认，W2 删旧名——走查报问题时写清 `CardAnchors.ids()` 里当时是新名还是旧名。
- 你验收的步骤与 `_test.d1_3` 不变。

**测试与截图**

- 清单不加新行：`K14_play_ui_mock`、`K14_guide_onoff_mock`、`K14_next_day_chaos` 照旧，内容按上面加；W2 的 `K14_play_ui_real`、`K14_guide_d1_3` 照旧。
- 截图：上面的画面版清单 + 指引每一步一张；`compare_shots.gd` 照旧（同种子两次截图像素一致——对话框逐字出现会让同一时刻的截图不一样：截图脚本开始时把 `game.dialog.chars_per_sec` 设成 0，“对话说到一半”那张靠停在一批句子的中间一句来拍）。

**已经做了的哪些还有效**

- 走查框架、截图工具、比对、指引开关测试全部有效。

**日期**：画面版截图在 C01 的画面根（10-27）合入后拍；W2 的真引擎第 1–3 天指引走查 + 每步画面截图 **11-05**。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `tools/cards/qa/**`、`docs/cards/qa/**`
- 默认拥有：`scripts/tests/cards/K14/**`、`scripts/tests/cards/suites/K14.txt`、`data/cards/tags/K14.json`、`data/cards/ui_keys/K14.json`
- 截图不提交进仓库（贴 PR）；实在要提交，放 `scripts/tests/cards/K14/shots/`（目录里放空文件 `.gdignore`，单个 PR ≤ 4 MB）。

## 不能做的事

1. 不改界面、引擎、Mock、指引引擎的代码（发现问题：开 `[bug]` issue 给对应任务，附截图与复现）；不改 `scripts/tests/cards/lib/**`、`scripts/tests/cards/W0/**`、`tools/run_*.sh`、`project.godot`。
2. 不写玩家最终内容；测试夹具里要“正文”只用 ASCII 假字。
3. 清单里的测试不许依赖墙钟、不许 sleep、不许截图（截图脚本不进清单）；不碰 `user://cards/`、`user://settings.json`（用 `t.user_dir()`）。
4. 随机只用 `c.qa.*`；走查不改游戏状态以外的东西（例：不往存档根写）。
5. Python 只用标准库（需要的话）；拼图、比对用 GDScript。

## 接口

**用到**：`CardGameRoot`（`boot` `autoplay_step` `engine` `host` `guide` `table` `mg_host`；1.3 加 `stage` `dialog` `hand` `hero` `checks`，C01 的画面根合入后才有）、`CardPanel.autoplay_step()`、`CardGuide`（`force` `skip_fades` `tick` `evaluate_now` `shown_log` `active_step`）、`CardEngineApi`（`view` `send` `query`）、`CardEngine.command_log()`、`ctx.state.hash()`、`CardReplay.replay()`、`CardViewModel.leaks()`、`card_t`（`spy` `anchor_ok` `all_text_from_cardtext`；1.3 加 `anchor_in(id, rect)` `anchor_ok_any(ids)`，新旧锚点名都认时用后者）、`CardAnchors.ids()`。

**提供**：整局走查与截图（Claude 审界面 PR、W2 完成条件）；第 1–3 天指引走查（W2 完成条件）；问题模板与试玩清单（人试玩）。

## 新手指引

- **锚点**：不登记（QA 任务只读 `CardAnchors`）。**ui_event**：不发（只用 `t.spy(bus)` 听）。**first-time**：不发。
- **你验收的步骤**：`_test.d1_3` 的全部（§7.10.10 起步顺序：`gd.m.open` → `gd.m.wheel` → `gd.m.incense` → `gd.d1.notice` → `gd.d1.deal` → `gd.d1.person` → `gd.d1.look` → `gd.d1.spot` → `gd.d1.tiers` → `gd.d1.ticket` → `gd.d1.shelf` → `gd.d1.buyer` → `gd.d1.close` → `gd.d1.night` → `gd.d1.settle` → `gd.d2.rules` → `gd.d2.gold` → `gd.choice` → `gd.d2.keep` → `gd.slots` → `gd.coins`，以 K16 定稿的 `_test.d1_3` 为准）；W2 的三关走查里顺带记下每个亮过的步骤和它亮的那天（输出一张“步骤 → 第几关第几天”的表，给 K16 调节奏）。
- **指引验收（必须有测试）**：C 节的 `test_guide_onoff_mock.gd`（W1）与 `test_guide_d1_3.gd`（W2）；**截图**：`shot_guide_d1_3.gd` 每一步一张、PR 附拼图。走查失败时：在 PR / issue 里写清是哪一步没亮或顺序不对、那时的阶段、开着的面板、锚点是否存在（`CardAnchors.ids()`），指给原因所在的任务（K16 数据、C16 引擎、某个 C 任务的锚点、G 任务的 first）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K14.txt`：

```
# K14 QA 自动化（docs/handoff_cards/K14_qa-automation.md）
K14_play_ui_mock|res://scripts/tests/cards/K14/play_ui.gd|600|--engine=mock --seed=7 --days=30 --name=K14_play_ui_mock
K14_guide_onoff_mock|res://scripts/tests/cards/K14/test_guide_onoff_mock.gd|300|
```
W2 加：
```
K14_play_ui_real|res://scripts/tests/cards/K14/play_ui.gd|900|--engine=real --seed=7 --name=K14_play_ui_real
K14_guide_d1_3|res://scripts/tests/cards/K14/test_guide_d1_3.gd|600|
```
（同一个脚本被引用多次时，`T.new(self, <名字>)` 的名字从 `--name=` 读。）

**通过条件**：
- [ ] W1：Mock 上的整套界面走查能跑完一关（30 天）不卡死、无隐藏键、无 `%`、文字都来自 CardText；指引开/关两遍的操作序列相同。
- [ ] W2：真引擎三关走完（或体面地结束）；第 1–3 天 `shown_log == _test.d1_3`；开/关指引状态哈希相同；同种子两次截图像素一致（`compare_shots.gd` 结果贴 PR）；每一步一张截图。
- [ ] `tools/run_card_tests.sh` 与 `tools/run_legacy_smoke.sh` 全绿；无 `SCRIPT ERROR` `ERROR` `WARNING` `FAIL:`、无泄漏；每行 `CARDS TEST PASS <名字>`。
- [ ] 性能：Mock 一关走查无头 ≤ 120 秒（贴实测）。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K14 bash tools/run_card_tests.sh
bash tools/cards/qa/shots.sh /tmp/shots/K14_run1 && bash tools/cards/qa/shots.sh /tmp/shots/K14_run2
$GODOT --headless --path . -s res://scripts/tests/cards/K14/compare_shots.gd -- --a=/tmp/shots/K14_run1 --b=/tmp/shots/K14_run2
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
  -s res://scripts/tests/cards/K14/shot_guide_d1_3.gd -- --out=/tmp/shots/K14_guide
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```

## 交付

- **PR 标题** `[K14] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K14] Mock 整局走查、截图脚本、问题模板与试玩清单`（W1）；②`[K14] 指引开关走查（Mock）`（W1）；③`[K14] 真引擎三关走查与截图`（W2）；④`[K14] 第 1–3 天指引走查与逐步截图（真引擎）`（W2）。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；截图拼图（关键处、指引每一步）；两次截图的像素比对结果；走过的阶段 / 面板 / 小游戏清单；“步骤 → 第几关第几天”表；发现的问题清单（每条一个 issue 链接，指给负责的任务）；性能实测；完成写“交付”。

## 审核（Claude 重点）

1. 越界（只动 QA 目录与默认拥有的路径）；2. 清单里的测试确定、无 sleep、不碰 `user://cards/`；3. 第 1–3 天走查严格按 `_test.d1_3`、开关哈希对比真的跑了；4. 截图每一步一张、像素一致；5. 试玩清单覆盖九条红线；6. 发现的问题都开了 issue、指对了人。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| Mock 走查：阶段 / 面板 / 小游戏覆盖 | |
| 第 1–3 天指引走查结果（真引擎） | |
| 开/关指引哈希对比 | |
| 截图拼图链接（关键处、每一步） | |
| 像素比对结果 | |
| 发现的问题（issue 链接） | |
| 合同或数据缺口 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
