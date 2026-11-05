# K14 QA 自动化

无头走查、截图、指引开关、问题模板。合同 §3.4 K14、§12.1–§12.3。本目录只描述怎么跑，不改界面和引擎。

## W1 已交付 / W2 待 X01

| 项 | 状态 |
|---|---|
| Mock 情景一关（30 天）无头走查 `play_ui.gd` | **已交付**。种子 7、`--guide=off`。402 步。和 W0 一起跑完约 27 秒；单独跑约 56 秒。都低于 120 秒预算 |
| 指引开/关 `test_guide_onoff_mock.gd` | **已交付**。种子 7、走 7 天。两遍去掉 `ui.guide` 后指令相同。开着那遍第 4 天早上的 `shown_log` 等于例子集 `_test.d1_3`（`gd.d1.deal` → `gd.d1.person` → `gd.slots`） |
| 问题模板、试玩清单、本说明 | **已交付** |
| 真引擎三关走查、第 1–3 天指引逐步截图 | **W2 待 X01**。见 `findings.md`。`test_guide_d1_3.gd` 只断言桩，不把 Mock 走查说成真引擎通过 |

K16 的 `data/cards/guide/steps.json` 还没进这棵树。第 1–3 天顺序对的是 W0 例子集 `data/cards/_examples/guide/steps.json` 的 `_test.d1_3`，不是合同 §7.10.10 那 21 步。K16 合入后，`test_guide_onoff_mock.gd` 会改读真文件里的 `_test`。

## 脚本

| 文件 | 进清单？ | 做什么 |
|---|---|---|
| `scripts/tests/cards/K14/play_ui.gd` | 是（Mock，两条） | 加载 `CardGame.tscn`，`autoplay_step()` 走完 `--days`。每步查隐藏键、可见文字里的 `%`、整棵画面的字是否来自 CardText（含以后的对话框）、指令是否以 `command_done` + `view_changed` 收尾。连续 8 步视图和最上面的面板都不变 → 失败。`--chaos` 时每步用 `c.qa.chaos` 乱按打烊、确认面板、Esc。结束时统计 `panel_opened` 的 `show`；现在没有 `show` 就打印 `NOTE: show not covered`，不失败 |
| `scripts/tests/cards/K14/test_guide_onoff_mock.gd` | 是 | Mock、种子 7、7 天，指引强制开/关各一遍 |
| `scripts/tests/cards/K14/test_guide_d1_3.gd` | 是 | W2 门。现在断言 `month.begin` / `day.begin` 为 `not_implemented`，且 `CardGameRoot` 仍是 Mock |
| `scripts/tests/cards/K14/qa_util.gd` | 否（被上面 preload） | 参数、指纹、红线扫描。不抽随机数 |
| `scripts/tests/cards/K14/sheet.gd` | 否 | 把目录里的 png 按文件名排成拼图，缩到 1/4（`Image.blit_rect`） |
| `scripts/tests/cards/K14/compare_shots.gd` | 否 | 两个目录逐张比像素。不同则打印文件名和第一处坐标 |
| `scripts/tests/cards/K14/shot_guide_d1_3.gd` | 否 | W2：真引擎上每一步一张 `<步骤 id>.png`。现在只打印 NOTE，不写假图 |
| `tools/cards/qa/shots.sh` | 否 | 有 `xvfb-run` 就截图再拼图；没有就无头走查并打印 `NOTE: no xvfb, screenshots skipped` |

清单：`scripts/tests/cards/suites/K14.txt`。

命令行（`--` 之后）：`--engine=mock|real`、`--seed=<n>`、`--days=<n>`（Mock 默认 30，real 默认 90）、`--guide=on|off`（默认 off）、`--shots=<目录>`（给了才截图）、`--chaos`（打烊乱按；清单行 `K14_next_day_chaos`）、`--name=<清单名>`。

随机：清单里的走查除 `--chaos` 外不抽数。`--chaos` 只用 `JevRng.draw(seed, "c.qa.chaos", key)`。Mock 情景内部用的是 `c.mock`，不是本任务的域。W2 的 `--engine=real` 打烊行先不进必跑清单（没有显示服务器，日循环仍是桩）。

## 怎么跑

```bash
export GODOT=/path/to/Godot_v4.7
# 清单（无头，不截图）
CARDS_SUITES=K14 bash tools/run_card_tests.sh

# 有 xvfb：关键处截图 + 拼图。再跑一遍，比像素
bash tools/cards/qa/shots.sh /tmp/shots/K14_run1
K14_SHOTS_BASE=/tmp/shots/K14_run1 bash tools/cards/qa/shots.sh /tmp/shots/K14_run2
# 也可以手动比（两个目录都已经含 sheet.png 时，拼图也会被比进去）
"$GODOT" --headless --path . -s res://scripts/tests/cards/K14/compare_shots.gd -- \
  --a=/tmp/shots/K14_run1 --b=/tmp/shots/K14_run2

# 只有拼图
"$GODOT" --headless --path . -s res://scripts/tests/cards/K14/sheet.gd -- \
  --dir=/tmp/shots/K14_run1 --out=/tmp/shots/K14_run1/sheet.png

# W2 指引逐步截图（现在会 NOTE 后退出，不写 png）
xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 --audio-driver Dummy --path . \
  -s res://scripts/tests/cards/K14/shot_guide_d1_3.gd -- --out=/tmp/shots/K14_guide
```

没有能用的显示时（没有 `xvfb-run`，或 `xvfb-run` 起不来 X11/Wayland），`shots.sh` 打印 NOTE，再跑同一条无头走查，不写 png。本工作环境就是后一种：`xvfb-run` 在，但 `DisplayServer` 创建失败，所以这次没有截图、没有拼图、没有像素比对。`--headless` 单独跑并带上 `--shots` 时，脚本同样只打印 NOTE，不写假图。

`--headless` 下 `DisplayServer` 名字是 `headless`，视口图不可用。`play_ui.gd` 打印 `NOTE: headless display, screenshots skipped`，不写假 png。截图必须走 xvfb + opengl3，不要加 `--headless`。

输出：

- 走查日志一行 `K14 COVERAGE phases=... panels=... minigames=... steps=...`
- 指引日志一行 `K14 GUIDE on_day4=... on_full=...`
- 截图文件名 `<序号>_<阶段>_<面板>.png`（小游戏是 `mg_<kind>`）
- 拼图默认 `<目录>/sheet.png`
- Mock 情景里没有的街头、牢房、跳年、档案簿，只在给了 `--shots` 且不是 headless 时，用夹具 `street_prison`、`year_jump`、`morning` 补拍

截图不进仓库。

## 发现的问题

列在 `findings.md`。不改别人的代码。
