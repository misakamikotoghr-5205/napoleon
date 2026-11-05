# K14 走查发现的问题

不改别人的代码。下面每条写清现象、谁的活、现在怎么断言。没有另开 GitHub issue：本卡要求问题写在这个目录里。

## W2 与 X01（状态记录，2026-10-22 更新）

本节原来写的是“W2 待 X01、走查未执行”，已过时：

- **X01-a 已合入（#217）。** 正式启动 `--cards` 接真引擎 `CardEngine`；`--cards-mock` 才用 `MockCardEngine`；内嵌调用方（测试、截图）默认仍是 Mock，要真引擎就显式传 `mock: false`。续玩也走真引擎。真引擎三天指引走查已经在必跑清单里：
  - `K14_guide_d1_3`（`scripts/tests/cards/K14/test_guide_d1_3.gd`，G02 夹具的教学日程）：种子 7、新存档、指引开着，第 1–3 天 `shown_log` 按顺序等于 `_test.d1_3`；关着指引时 `command_log()` 和状态哈希相同；`CardReplay.replay` 哈希相同；first 串等于 G02 黄金文件 `firsts_d1_3.json`。
  - `X01_guide_formal_d1_3`（发行数据 `data/cards`，不换教学日程）：`_test.d1_3` 的 21 步按合同顺序都亮过；开关指引的指令日志、状态哈希、回放哈希一致。
  - `X01_boot`、`X01_continue`、`X01_campaign`、`X01_ui_campaign` 覆盖真引擎入口、续玩、整关和经由界面的第一关。
- **X01-b 正在做**（#194、#209）：C07 的黄历抽屉 `AlmanacDrawer.tscn`；删 W0 桩（`scripts/cards/ui/common/w0/**`、`scenes/cards/_w0/**`）和 `card_ids.gd` 里 7 个旧锚点兼容，K16 步骤与 C02/C04/C10/C16 测试换新锚点名；顺带修 `_show_news` 显示原始字典、C03 `counter_checks.gd` 的 `coins_finished` 永远传 false。

仍然没有的：

- **真锚点截图和 `guide_d1_3_sheet.png`。** 本环境 `--headless` 截不了图（见下面“覆盖缺口”第 5 条），`shot_guide_d1_3.gd` 只跑三天的指引检查、打印 `NOTE: headless display ...`、不写 png。没有假图。
- **真引擎经由界面三关走完**不在必跑清单里；`X01_ui_campaign` 只走到第一关结束。
- `scripts/tests/cards/suites/K14.txt` 里 `K14_play_ui_mock`、`K14_next_day_chaos` 仍是 Mock 走查，`--engine=real` 的打烊乱按行没有放进必跑清单。

下面“W1 Mock 走查”是更早的 Mock 记录，不是真引擎结果。

## W1 Mock 走查（种子 7，30 天，guide off）

整进程在登记的 `CARDS_SUITES=W0,K14` 跑次里，30 天走查与其余清单合计约 **27 秒**（机器空一些的时候）。此前单独跑这一条，整进程约 **56 秒**。都是 **402** 步，停在 `month_close` 面板已打开，低于 120 秒预算。没有隐藏键，可见文字里没有 `%`，抽到的 Label / Button 文字都来自 CardText，指令都以 `command_done`、`view_changed` 收尾。

- **阶段**：`month_open` → 反复 `morning` / `day` / `night` / `settle` → `month_close`
- **打开过的面板**：`month_open` `wheel` `counter` `slots` `read` `fortune` `night` `settle` `month_close`
- **小游戏**：`spot` `weigh`
- **指引**（另一条测试，开着走 7 天）：没有 `data/cards/guide/steps.json` 时，第 4 天早上 `shown_log` = `gd.d1.deal`, `gd.d1.person`, `gd.slots`，和例子集 `_test.d1_3` 一致。K16 的真步骤在时，走查在桩的 `_ready` 之后登记与 `K16_d1_3_mock` 相同的 1.3 锚点替身（`a.right.tickets` → `a.scene.ledger` 等 11 对；新名已登记则跳过），第 4 天早上的快照才等于真 `_test.d1_3` 的 21 步。不打替身时下一步 `gd.d1.ticket` 亮不起来，快照停在 9 步。7 天走完按当前步骤数据核对，没有超过 `max_shows`。关着时 `sent` 里没有 `ui.guide`。开/关两遍去掉 `ui.guide` 后指令列表相同。

必看的五种面板（柜台、格子、夜、日结、月底）都打开过。

## 覆盖缺口（不是这次改代码的事）

1. **条子面板没被自动试玩打开。** Mock 第 7 天把条子放在 `demands` 区。`CardGameRoot.autoplay_step()` 只点手牌里带面板的牌，不会去按右栏条子。W1 要求的五种面板不含条子；W2 的 `demand` 截图现在拍不到。归 **C01**（自动试玩要不要点条子）和 **C05**（板子）。不是红线失败。
2. **街头、牢房、跳年、档案簿**不在这一关的自动路径里。给了 `--shots` 且不是 headless 时，用夹具 `street_prison`、`year_jump`、`morning`（再打开档案簿）补拍。归 W0 夹具设计，不是缺陷。
3. **小游戏只有 spot 和 weigh。** 情景随机池没有走到铜钱环、碎片、解密。不伪造另外三种的截图。
4. **例子集物品 brief 里有 `%`**（`data/cards/_examples/minigames/items.json` 金簪那条）。当前桩面板不把这段 brief 画出来，所以走查没失败。谁以后把这段 brief 直接画上界面，会踩红线 3。归 **K11** 的占位措辞，正式正文由人写。
5. **这个环境截不了图。** `--headless` 时 `DisplayServer` 是 `headless`，`play_ui.gd` 打印 `NOTE: headless display, screenshots skipped`，不写文件。机器上有 `xvfb-run`，但起不来显示（`Can't load XCursor`、X11 失败、Wayland 客户端库没有、`Unable to create DisplayServer`）。所以没有 1280×720 png，也没有拼图，没有像素比对。走查改为断言阶段、面板、小游戏和红线，不交假图片。截图不进仓库。

## 步骤 → 第几关第几天

没有 K16 的 `steps.json` 时，只有例子集的 3 步（Mock 情景、种子 7、指引开着）。K16 合入后，第 4 天早上的快照就是真 `_test.d1_3` 的 21 步（开局到第 3 天，顺序以那份 `_test` 为准），不再停在 `gd.d1.tiers`。

| 步骤 | 关 | 天 | 依据 |
|---|---|---|---|
| `gd.d1.deal` | 0 | 第 1 天白天发牌之后 | `shown_log` 在第 4 天早上之前已经记完，且与例子集顺序一致 |
| `gd.d1.person` | 0 | 第 1 天，接在 deal 后面 | 同上 |
| `gd.slots` | 0 | 第 3 天格子（警察查验证）出现时 | 同上；第 4 天早上快照里它是最后一步 |

W2 真引擎逐步对到第几天的完整表还没写；21 步的顺序以 `_test.d1_3` 为准，`X01_guide_formal_d1_3` 断言它（见本文开头）。
