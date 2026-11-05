# C01 `table` · 画面根、场景层、HUD、两侧标签与抽屉宿主、打烊按钮、叠层与小游戏宿主、指引宿主、配色

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C01 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C01: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 1**（在第 1 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C01`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。牌桌里嵌的控件和面板全用 W0 的同接口桩先做，不等别人：C02 `CardWidget`、~~C05 `CardDemandBoard`~~、C07 `CardAlmanacStrip`、C10 `CardHelpPanel`、C11 `CardStreetOverlay`、C16 `GuideOverlay`/`CardTitle`/`CardPause`。1.3：画面上的新控件（C02 的 `hand_fan` `hero_bar`、C03 的 `checks`、C04 的 `dialog`）和还没有场景的面板一律经 `CardIds.widget_scene()` / `panel_scene()` 取，主人没合入时拿到 W0 的桩（`scenes/cards/_w0/`）；C05 的条子板改由 C05 自己的 `demands` 抽屉嵌，C01 不再直接摆它。
- **波次（Wave）**：W1 开发并合入（**W1 完成条件之一**：C01–C04 + C16 必须在 W1 合入）；W2 由 Claude 指派，把默认引擎换成 G02 的 `CardEngine`（`--cards-mock` 保留）并补对真引擎的集成测试。

## 分支

`cards/C01-table`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交，先确认 `scripts/cards/api/card_ids.gd` 存在）。开发中用 `git rebase origin/claude/festive-ride-vud32a` 跟上，不留合并提交。

## 目标

把 W0 能跑的桩做成正式画面：320×180 的像素柜台场景整数 4 倍铺满 1280×720（CardStage）、顶部一条 HUD、两侧标签与抽屉宿主、右侧中下任何时候都能按的“打烊 · 下一天”；把 C02 的手牌扇与头像、C03 的柜台格子、C04 的对话框按 §7.11.1 的层次摆进来；打出一张牌就开它的演出、热点和 HUD 点了开对应的抽屉；面板宿主按“呈现”分三路（演出 / 抽屉 / 叠层）；小游戏宿主、最上层的新手指引宿主、F1、Esc、键盘全流程、配色 CardTheme。

## 必读

1. `docs/cards/DESIGN_cards.md` §一（一天怎么过）、§九.3（金色角色牌）、§九.4（新手指引）、**§九.5（打烊 · 下一天，主创 10-13 硬性规则）**。
2. `docs/cards/CARDS_INTERFACES.md`：§0（九条红线、并行规则）、**§7.4.7（打烊 · 下一天）**、§1.2（分辨率、画面分区、尺寸、字体、输入、动画、配色、新手指引那一行）、§2.2 / §2.4（归属表、配色键）、§3.3 开头与 C01、§7.2、§7.4（指令）与 §7.4.3（来意与面板）、§7.5（视图）、§7.6（CardBus）、§7.7（Mock 与夹具）、§7.8（面板表、控件表、根场景）、§7.10.4 / §7.10.5 / §7.10.7 / §7.10.8（锚点、界面事件、CardGuide、命令行）、§8.1（小游戏宿主流程）、§10.2（手牌顺序）、§11.2（AI 不许做的）、§12.1–§12.4（测试、截图、性能）、§13–§14、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码（W0 已经能跑，先读懂再改）：`scripts/cards/ui/table/{card_game_root,card_table,modal_host,minigame_host}.gd`、`scenes/cards/CardGame.tscn`、`scenes/cards/table/CardTable.tscn`、`scripts/cards/ui/common/{card_theme,card_panel,card_anchors,w0_stub}.gd`、`scripts/cards/mock/{mock_engine,mock_scenario}.gd` 与 `scripts/cards/mock/fixtures/*.json`、`scripts/tests/cards/lib/card_t.gd`、`scripts/tests/cards/W0/{test_table_3days,test_skeleton,shot_table}.gd`、`data/cards/theme/palette.dev.json`。
4. 只读参考（不实例化、不拷文字）：`scripts/ui/style.gd`（`UiStyle.title_font()/body_font()`）、`scripts/town/town_ui.gd`、`scripts/town/modal.gd`、`scripts/town/hud.gd`（旧版的样式和弹窗做法）。

## 要做的事

- [ ] **CardGameRoot**（`card_game_root.gd`，`class_name CardGameRoot`）：保留冻结的 `engine`、`host`、`boot(opts)`，以及 W0 加的 `autoplay_step()`、`guide`、`table`、`mg_host`、`title`、`bus`（K14、C16、各界面测试都在用；PR 里列为公开接口）。选引擎：`--cards-mock=<夹具路径或名字>` → Mock 夹具模式；不给 → W1 用 Mock 情景模式（W2 换成 `CardEngine`）。命令行 `--seed=<n>`、`--guide=on|off`（交给 `guide.set_cmdline()`；`--cards-mock` 和 `--cards-autoplay` 下不给时默认 `off`）、`--cards-autoplay=<步数>`（保留 W0 的行为和输出 `CARDS AUTOPLAY <阶段> <第几天>`，`tools/run_legacy_smoke.sh` 在用）。启动先进 C16 的 `CardTitle`。
- [ ] **按阶段开面板**：保留并整理 W0 的 `_sync_phase_panel()`：开月先开 `month_open` 过场，关掉后开引擎要的面板（`view.open_panel` / `request_panel`）；`night` `settle` `month_close` `year_jump` `game_over` 每天自动开一次；全部 `call_deferred`，不在 CardBus 回调里同步 `send()`。
- [ ] ~~**CardTable**（`card_table.gd`，`CardTable.tscn` 的根，不写 `class_name`）按 §1.2 分区，坐标写成常量：~~（10-13 作废，合同 1.3：牌桌分区整个作废，换成场景层 `CardStage` + HUD + 两侧标签与抽屉 + 摆别人的控件，坐标只用 `CardLayout`，见下方“10-13 变更二”；`CardTable.tscn` 可以留作画面的容器，也可以删，PR 里写明。下面各栏里要显示的东西搬到了：日期、天气、黄历条、钱、口碑/风声 → HUD；告示 → 门边的告示热点与早上对话框说一遍；你自己、人脉 → C02 的英雄头像与人脉小牌；留着的牌 → C02 的手牌扇；条子 → C05 的条子抽屉；当票、货架、家当、档案簿 → 标签与柜台热点）
  - ~~顶栏 y 0–56：日期（`view.date`；数字或带参数的界面键）、天气与集市（`g05.weather.<天气>`、集市用本任务的键）、告示一行（`notice.news[0]` 经 `CardText.ui`）、黄历条位置（嵌 C07 的 `AlmanacStrip.tscn`）、钱（`money.amount` 数字 + 本任务的币种键）、口碑/风声**五档文字**（`g03.tier.rep.<0–4>`、`g03.tier.heat.<0–4>`，绝不显示点数）。~~
  - ~~左栏 x 0–232：你自己（`view.self`，传给 CardWidget 时补 `type:"self"`、`zone:"self"`）、人脉（≤3，`view.contacts`）、留着的牌（≤5，`view.kept`，角标由 C02 画 `expires_in`）。~~
  - ~~中间 x 232–1048：上半 y 64–360 柜台桌面（当前处理的那张牌可放大摆在这里、货架入口、当票条）；下半 y 380–712 手牌行。~~
  - ~~右栏 x 1048–1280：条子板（嵌 C05 的 `DemandBoard.tscn`）、当票（`view.tickets`：号、剩几天，数字）、货架入口（`shelf_count`/`caps.shelf` 数字）、档案簿入口（`dossier_new` > 0 时小红点）、**家当入口**（见下方“默认做法”）、右下角“打烊 · 下一天”（任何时候都能按，见下方“10-13 变更”）。~~
  - 街头模式（`view.mode == "street"`）叠 C11 的 `StreetOverlay.tscn`（1.3：摆在第 7 层，背景由场景层按 `stage.set == "street"` 换，§7.11.1）。
- [ ] ~~**手牌行**（`card_table.gd` 内或 `scripts/cards/ui/table/hand_row.gd`，`preload`，不写 `class_name`）：**严格按 `view.hand` 的顺序**（引擎的 `order_hand()` 已把金色牌排最左），界面不排序；≤7 张平铺，>7 张扇形叠放，9 张也不出 816 宽的手牌区；1–9 键选第 N 张；牌用 C02 的 `CardWidget`（尺寸 `&"hand"` 144×200）。~~（10-13 作废，合同 1.3：手牌是 C02 的炉石式手牌扇 `CardHandFan`，C01 只摆它、接它的 `card_played`；`hand_row.gd` 不要了。“严格按引擎顺序、界面不排序”照旧，由 C02 做）
- [ ] **接控件信号**：~~`CardWidget.pressed(uid)` → 发 `ui_event hand_selected {uid}` → 按 `query("card").panel` 开面板（§7.4.3；`none` 不开）~~（10-13 作废，合同 1.3：点牌 = C02 的手牌扇选中放大并发 `hand_selected`；打出才开演出，路由见下方“10-13 变更二”）；`CardWidget.action_requested(uid, "keep")` → `send("card.keep", {uid})`（其他 action id：`discard` → `card.discard`、`read` → 开 `read` 面板、`choose:<id>` → 开 `slots` 面板）；~~`CardDemandBoard.demand_pressed(uid)` → 开 `demand`~~（10-13 作废，合同 1.3：条子板在 C05 的 `demands` 抽屉里，点一行由抽屉自己开 `demand`）；`CardStreetOverlay.redeem_shop_pressed` → `send("street.redeem_shop")`；~~档案簿入口 → 开 `dossier`；家当入口 → 开 `estates`；货架入口 → 货架抽屉（见下）~~（10-13 作废，合同 1.3：入口是两侧标签与柜台热点，§7.11.8、§7.11.9）；“打烊 · 下一天” → `send("day.end", {"confirm": false})`，返回 `must_resolve_pending` 时开 `end_day` 面板，参数 `{step, items}`（**任何阶段都能按**，见下方“10-13 变更”）。
- [ ] **CardModalHost**（`modal_host.gd`，`class_name CardModalHost`，冻结 `open_panel(kind, args)`）：按 §7.8 面板表实例化；~~场景不存在时用**本任务自己的**占位面板（`scripts/cards/ui/table/placeholder_panel.gd`，不再 `preload` `w0_stub.gd`——它归 Claude，所有桩换完后删除）~~（10-13 作废，合同 1.3：场景路径一律 `CardIds.panel_scene(kind)`，缺场景用 W0 的 `PanelStub`；不再 `preload` `w0_stub.gd` 照旧）；可以叠几层（F1 帮助开在别的面板上面）；弹出面板居中、最大 1100×640、下面一层 `shade` 遮罩（1.3：只有呈现为 `overlay` 的这样开；`stage` 进演出层、`drawer_l/drawer_r` 进抽屉宿主，见下方“10-13 变更二”）；开/关时发 `ui_event panel_opened/panel_closed {kind}`（**所有面板都发**；1.3 多带 `show`：`{kind, show}`）；收到 `view_changed` 后对每层调 `refresh(view)`。
- [ ] **面板请求的约定**（合同没写，本任务实现，PR 里列出，Claude 补进合同）：`close_requested(result)` 里 `result.next = {kind, args}` → 关掉后开这个面板；`result.open_uid = "<uid>"` → 关掉后按那张牌的 `panel` 开；`result.to_title = true` → 回标题；`result.quit = true` → 退出。~~面板可选实现 `can_close()`~~（10-13 作废：没有关不掉的面板；Esc 调最上层面板的 `dismiss()`——它的“算了”，合同 §7.8）。
- [ ] **CardMiniGameHost**（`minigame_host.gd`，`class_name CardMiniGameHost`）：听 `minigame_requested` → 按 §8.1 表实例化 → `start(params)`；放在面板之上、指引之下；Esc → `current.abort()`；小游戏框上另放一个看得见的“算了”按钮（键 `c01.btn.mg_abort`）→ `current.abort()`，只用鼠标也关得掉（合同 §7.8，红线 9）；`finished` → `engine.send.call_deferred("mg.report", {uid, item, result})`；保留 `is_active()`、`autoplay_current(skill)`。
- [ ] **指引宿主**：最上层 `CanvasLayer`（layer 100）放 C16 的 `GuideOverlay.tscn`，整层所有节点 `mouse_filter = MOUSE_FILTER_IGNORE`；`guide.bind(engine, bus)`；`guide.set_enabled(<settings.guide_hints>)`（设置文件路径可由 `boot(opts.settings_path)` 注入，测试不碰 `user://settings.json`）。换场景/回标题时 `CardAnchors.clear()`。
- [ ] **外壳接线**：根场景实例化 C16 的曲目节点 `preload("res://scripts/cards/ui/shell/card_music.gd").new()` 加进树（C16 加的 `bind(bus)` 还没合入时用 `if music.has_method("bind"): music.call("bind", bus)`），标题时 `play(&"title")`；开 `settings` 面板时传 `{"settings_path": <boot 的 settings_path>, "cards_settings_path": <同目录下的 cards/settings.json>}`（测试不碰 `user://settings.json`）。
- [ ] **键盘**（不加 InputMap，直接判 `keycode`）：F1 任何时候开 `help`（C10），帮助开着再按 F1 或 Esc 关；Esc 调最上层面板的 `dismiss()`（它的“算了”，合同 §7.8；1.3 的顺序：小游戏 → 叠层 → 抽屉 → 演出 → 暂停）；没有面板时开 `pause`（C16）；~~1–9 选手牌（没有面板时）~~（10-13 作废，合同 1.3：对话框列着回话时 1–9 选第 N 句回话，否则 `hand.select_index`）；Tab 在可点的东西间移动（按钮 `focus_mode`）；Enter 确认焦点；~~Space 交给最上层面板（跳过动画/继续）~~（10-13 作废，合同 1.3：Space / Enter 先推对话框的下一句，说完了、有选中的手牌时 Enter = 打出，§1.2 的“输入”一行）。小游戏开着时 Esc 交给小游戏。
- [ ] ~~**货架抽屉**（默认做法，见下）：`scripts/cards/ui/table/shelf_drawer.gd`（`preload`）：`query("stock")` 的物品列表（`ItemView`：图、名字 `CardText.item_text(template, "name")`、类别、成色档的字），只读；关掉回牌桌。不是面板表里的 kind，不发 `panel_opened`。~~（10-13 作废，合同 1.3：货架是 C04 的 `shelf` 抽屉，面板表里有这个 kind；C01 只管右标签“货架”和抽屉框）
- [ ] **CardTheme**（`scripts/cards/ui/common/card_theme.gd`）：冻结 `color(key)`、`frame_style(type, gold)`、`font_title()`、`font_body()`；有 `palette.json` 用它，没有且 `!CardShip.is_ship()` 退回 `palette.dev.json`，发行版缺 `palette.json` → `push_error`；键不存在开发版 `push_error` 返回 `Color.MAGENTA`。可以加公开辅助（例：`font_size(role)`、`panel_style()`），PR 里列出。只用 §2.4 的键；要新键开 `[shared]` issue 给 Claude。
- [ ] **界面键**：`data/cards/ui_keys/C01.json`（键以 `c01.` 开头，只写键 + `brief`，`_meta` 带 `_provenance`），例：~~`c01.zone.self` `c01.zone.contacts` `c01.zone.kept` `c01.zone.tickets` `c01.btn.shelf` `c01.btn.dossier` `c01.btn.estates`~~（10-13 作废，合同 1.3：随牌桌分区作废）`c01.btn.close_day`（1.3 拆成 `c01.btn.close_day.<step>` 等，见下方“10-13 变更二”）`c01.btn.mg_abort` ~~`c01.top.market`~~ `c01.money.unit.fabi` ~~`c01.top.date`（参数 `{y} {m} {d} {weekday}`）~~（10-13 作废，合同 1.3：改叫 `c01.hud.market`、`c01.hud.date`（参数 `{y} {m} {d} {weekday} {day} {days}`））。不再用 `w0.*` 键。
- [ ] **夹具**（`scripts/tests/cards/C01/fixtures/`，§7.7 格式，`_meta.owner = "C01"`）：除 W0 的十个基础夹具外，至少 `market_rain.json`（集市日、下雨、口碑 3 档/风声 2 档、告示两行）、`full_left.json`（5 张留着的牌含剩 1 天的、3 个人脉含今天用过的、3 张条子、4 张当票）、`street.json`（`mode: street`，手上是街头牌）、`gold_only.json`（只剩金色牌，点打烊返回 `must_resolve_pending`，清单里一行 `kind: "gold_leave"`）。夹具本身要过 `t.no_leaks()`。
- [ ] 保持 W0 的清单全绿（`W0_table_3days` 用 `autoplay_step()`、`table._on_card_pressed()`、`host.top_panel()` 走前三天；`W0_skeleton` 检查冻结签名、每个场景能实例化）。合理的改动让 W0 测试的假设失效时，开 `[shared]` issue 给 Claude，不改 W0 的测试。

**默认做法（合同没写到的，先这样做，代码里标 `# TODO(design): …`，写进 PR“需要主创/编排决定的事”）**：
1. ~~货架入口打开本任务自己的只读货架抽屉（§7.8 面板表没有 `shelf` kind）。~~（10-13 作废，合同 1.3：货架是 C04 的 `shelf` 抽屉）
2. ~~右栏加“家当”入口开 `estates` 面板（合同的右栏清单里没有，但 C11 的家当面板需要入口；不加新锚点）。~~（10-13 作废，合同 1.3：家当的入口是右标签“家当”、柜台上的钱匣、HUD 上的钱）
3. 上面的 `close_requested(result)` 约定（`can_close()` 10-13 作废，改用 `CardPanel.dismiss()`，合同 §7.8）。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **“打烊 · 下一天”按钮**（锚点 `a.btn.close_day`，界面键 `c01.btn.close_day`）永远显示、**任何阶段都能按**（街头、牢房里也一样；`game_over` 时换成去局终面板）：按下 → `send("day.end", {"confirm": false})`；`ok` → 不用再做什么（引擎已经往前走了一步）；`err == "must_resolve_pending"` → 开 C08 的 `end_day`，参数 `{step, items}`。界面不自己判断能不能打烊、不自己替玩家确认。
- [ ] **引擎要的面板只自动开一次**：`view.open_panel` 每个 `(kind, args.uid, abs_day)` 自动开一次，关掉后不再自己弹回来（W0 的 `_sync_phase_panel` 已经这样做），玩家可以从牌桌上点那张牌再开——所以永远回得到牌桌、按得到按钮。
- [ ] **Esc = 最上层面板的“算了”**：宿主调 `CardPanel.dismiss()`（W0 已加在基类，默认直接关；夜牌、留牌满、人脉满、钱不够的面板覆盖它，先发默认指令再关，合同 §7.8）。`can_close()` 约定作废——没有关不掉的面板。没有面板时 Esc 开暂停。
- [ ] **小游戏也关得掉**：小游戏宿主在小游戏框上放“算了”按钮（= `abort()`，Esc 同样），关掉后回到柜台面板，结果按 `aborted: true` 交给引擎。
- [ ] 没有任何计时器替玩家推进：不许用 `Timer` / `_process` 到点自动发 `day.end` `settle.next` `night.choose` 之类的指令（`--cards-autoplay` 与测试除外）。
- [ ] 自动试玩卡住时用 `day.end {confirm: true}` 往前走（W0 的 `_autoplay_day` 已经这样做）。
- [ ] 测试 `test_next_day.gd`（清单 `C01_next_day`）：十个基础夹具 + 自己的夹具，每个都按一次按钮——要确认的开了 `end_day`、`mock.sent` 最后一条是 `day.end {confirm: false}`，不用确认的直接前进；`street_prison`（街头 + 牢房）照样能按；`game_over` 时按钮开局终面板；`CardIds.PANELS` 里每种面板开着时 Esc 都能关掉、回到牌桌（`host.top_panel() == null`），该发的“算了”指令发了；小游戏的“算了”按钮 → `mg.report` 的 `aborted: true`；引擎要的面板关掉后不再弹回来；Mock 情景模式只按“打烊 · 下一天”（要确认就确认）能从新局走到第 2 关第一天早上。W0 的 `W0_next_day` 已经有一份做法可以照着写。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **画面的层次**（§7.11.1）：`CardGameRoot` 子节点从下到上：`CardStage`、C03 的 `checks`、演出层、C04 的 `dialog`、HUD、C02 的 `hero_bar` 与 `hand_fan`、标签、C11 的街头层、抽屉宿主、打烊按钮、`CardModalHost`（叠层）、`CardMiniGameHost`、CanvasLayer 100 的 `GuideOverlay`。别人的控件一律 `load(CardIds.widget_scene(&"<名>")).instantiate()`，变量按接口基类声明（`CardDialogApi` `CardHandApi` `CardHeroApi` `CardChecksApi`）；主人还没合入时拿到的是 W0 的桩，照样能跑。保留 W0 加的公开接口（`autoplay_step()` `guide` `table` `mg_host` `title` `bus`），另加 `stage` `dialog` `hand` `hero` `checks`（PR 里列出）；保留私有函数名 `_on_close_day()` `_sync_phase_panel()`（W0 的测试在调）。
- [ ] **CardStage**（新：`scenes/cards/table/CardStage.tscn` + `scripts/cards/ui/table/card_stage.gd`，`class_name CardStage extends CardStageApi`）：§7.11.3 全部——背景按 `CardStageScript.bg_id()`、交叉淡入 0.6 秒；人按站位上场、走进门、离场；夜里的 `night_tint` / `night_dark`、烛光、牢房冷色；门外路人、雨、查封（门旗换白 + 封条 `seal_paper`）、风声第 3 档以上门外的影子；9 个热点（`TextureButton`，`set_dim_tools`）；接拖放（`card_dropped`）；锚点 `a.scene*`。坐标只用 `CardLayout`。
- [ ] **HUD**（`scripts/cards/ui/table/hud.gd`，`preload`）：§7.11.10；嵌 C07 的 `AlmanacStrip.tscn`（`HUD_ALMANAC`，260×24）；点钱 → `estates`，点黄历条 → `almanac`；锚点 `a.top.date` `a.top.weather` `a.top.money` `a.top.rep` `a.top.heat`。
- [ ] **标签与抽屉宿主**（`scripts/cards/ui/table/drawer_host.gd`，`preload`）：§7.11.8：8 个标签（`TABS_L` `TABS_R`、`icon.tab.<名>`、`c01.tab.<名>`、角标）、左/右抽屉框（标题行 + “合上” `c01.btn.drawer_close`）、遮罩（`scrim`，点它收回）；同一时间一个抽屉；开/关发 `panel_opened/closed {kind, show}` 和 `drawer_opened/closed {kind, side}`；锚点 `a.tab.*`。
- [ ] **CardModalHost**（冻结 `open_panel(kind, args) -> CardPanel` 不变）：按 `CardIds.PANEL_SHOW[kind]` 分三路——`stage` → 演出层，一次只演一出（新的来了先 `dismiss()` 旧的，等它 `close_requested` 后 `end_play()` 再释放），实例化后 `bind()` → `bind_stage(stage, dialog, checks, hand)` → `open(args)`，把 `dialog.reply_chosen` 接到它的 `on_reply`（实例不是 `CardStagePanel` 的——主人还没迁——按 `overlay` 开，人照样先上场，§7.8）；`drawer_l/drawer_r` → 抽屉宿主；`overlay` → 叠层栈（1.2 的做法，居中、最大 1100×640、`shade`）。场景路径一律 `CardIds.panel_scene(kind)`（缺场景用 W0 的 `PanelStub`，不再 `preload` `w0_stub.gd`）。`top_panel()` / `top_kind()` / `close_top()` 的顺序：叠层顶 → 抽屉 → 演出。开叠层面板时要是 `args.uid` 不空，先 `stage.play(CardStageScript.resolve(cv, view))`（只换背景、上人，不说话），关掉后 `stage.clear_play()`。
- [ ] **打出一张牌的路由**（§7.11.4 第 1 条）：`hand.card_played`、`stage.card_dropped`（数据 `{"kind": "card", "zone": "hand"|"kept"}` 才算）、键盘 1–9 + Enter；夜里交给 `night` 那一出；能留的牌在预览里点“留着” → `send("card.keep", {uid})`（`CardWidget.action_requested` 照旧也接）。
- [ ] **热点路由**（§7.11.9）、头像/人脉点了开 `contacts`。
- [ ] **早上的告示**：每天第一次进 `day` 阶段，`notice.news` 不空就让对话框说一遍（每条一句 narr，`ref` 就是那个键）。
- [ ] **键盘**（§1.2 的“输入”一行）：Space/Enter、1–9（列着回话时选回话：`dialog` 的第 N 句；否则 `hand.select_index`）、Esc（小游戏 → 叠层 → 抽屉 → 演出 → 暂停）、F1、Tab。
- [ ] **对话框的速度**：boot 时 `load("res://scripts/town/settings.gd").new(<settings_path>).text_cps()` 设给 `dialog.chars_per_sec`；`CardSettings.fast_anim(<cards_settings_path>)` 为真、`--cards-mock`、`--cards-autoplay` 下设 0；设置面板改了以后重设（组 `card_settings_listeners`，方法 `on_settings_changed()`）。
- [ ] **“打烊 · 下一天”**：位置改成 `END_DAY` (1020, 556, 210, 92)，在抽屉之上（按下先收回抽屉）；字随 `day.end_preview.step` 换（§7.11.11）；1.2 的做法（`confirm:false` → `end_day`、局终开局终面板）照旧。
- [ ] **autoplay_step()**：小游戏 → 叠层顶的 `autoplay_step()`（false 就关）→ 抽屉开着就收回 → 演出（对话框 `is_idle()` 为假先 `skip()`；否则演出的 `autoplay_step()`，false 就收场）→ 按阶段推进；白天打牌改成 `hand.play_uid(uid)`（和玩家同一条路），每张牌最多打两次（照 W0）。`--cards-autoplay` 的输出不变。

**新增 / 作废的交付**

- 新增 `CardStage.tscn` `card_stage.gd` `hud.gd` `drawer_host.gd`、界面键 `c01.tab.<contacts|demands|dossier|rules|shelf|tickets|estates|settings>` `c01.btn.drawer_close` `c01.hud.time.<day|dusk|night>` `c01.hud.market` `c01.hud.status.<street|prison|sealed>` `c01.hud.fortune`（`{seg}`）`c01.hud.date`（`{y} {m} {d} {weekday} {day} {days}`）`c01.btn.close_day.<end_day|skip_night|next_day|open_day|begin_month|month_next|year_next|game_over>` `c01.btn.close_day.left`（`{n}`）`c01.btn.close_day.done`、夹具 `dusk.json`（处理掉六成以上：`stage.time: "dusk"`）`sealed_rain.json`（查封 + 下雨 + 风声 3 档）。
- **作废**：1.2 的牌桌分区（顶栏 56、左栏、右栏、柜台桌面、手牌行）、`hand_row.gd`、`shelf_drawer.gd`（货架归 C04 的 `shelf` 抽屉）、右栏的家当入口按钮（→ 右标签“家当”与钱匣热点）、把 C05 的条子板嵌右栏（→ C05 的 `demands` 抽屉）、默认做法第 1、2 条（货架抽屉、家当入口）。`CardTable.tscn` 可以留作画面的容器，也可以删（PR 里写明）。

**锚点、界面事件、要证明的步骤**

- 锚点改成合同 §7.10.5 表里 C01 那一行：`a.top.date` `a.top.weather` `a.top.money` `a.top.rep` `a.top.heat` `a.btn.close_day` · 场景 `a.scene` `a.scene.customer` `a.scene.notice` `a.scene.ledger` `a.scene.notebook` `a.scene.calendar` `a.scene.cashbox` `a.scene.magnifier` `a.scene.notewall` · 标签 `a.tab.contacts` `a.tab.demands` `a.tab.dossier` `a.tab.rules` `a.tab.shelf` `a.tab.tickets` `a.tab.estates` `a.tab.settings`（`a.hand` `a.hand.gold` 交给 C02；7 个旧名 `a.top.notice` `a.left.self` `a.left.contacts` `a.left.kept` `a.right.tickets` `a.right.shelf` `a.right.dossier` 不再登记）。
- 界面事件 `panel_opened/closed {kind, show}`、`drawer_opened/closed {kind, side}`、`hotspot_pressed {id}`（`hand_selected` 改由 C02 发）。
- 要证明会亮的步骤：`gd.d1.notice`（`a.scene.notice`）、`gd.tiers`（`a.top.rep`）、`gd.d1.close`（`a.btn.close_day`）、`gd.market_day` `gd.weather`（`a.top.weather`）、`gd.d1.ticket`（`a.scene.ledger`）、`gd.d1.shelf`（`a.tab.shelf`）、`gd.d2.rules`（`a.tab.rules`）、`gd.dossier`（`a.scene.notebook`）、`gd.demand`（`a.scene.notewall`，从 C05 挪来）、`gd.shop_closed`（`a.scene.notice`）、`gd.retry` `gd.resume`（`a.top.date`）；`gd.d1.deal` `gd.contact` `gd.kept_expire` `gd.kept_risk` `gd.person_state` 改由 C02 证明。

**测试与截图**

- 清单改成（名字不变的照旧，新增两行）：`C01_layout`（每个基础夹具 + 自己的夹具：C01 的锚点 `t.anchor_in(id, CardLayout.<常量>)` 都在规定的矩形里；HUD、对话框最大框、手牌扇的带、头像与人脉、标签、打烊按钮两两不重叠；字都来自 CardText；没有 `%`；口碑风声只有档位字）、`C01_input`（新键盘规则）、`C01_host`（`CardIds.PANELS` 每个 kind 开到对的那一层、`panel_opened` 带对的 `show`；一次只演一出；抽屉一次一个；Esc 顺序；`result.next/open_uid/to_title` 约定照旧）、`C01_minigame_host`、`C01_guide_host`、`C01_theme`（加画面配色键）、`C01_autoplay`、`C01_next_day`（加：抽屉开着按按钮先收回；演出开着按按钮照样走），**新增** `C01_stage|res://scripts/tests/cards/C01/test_stage.gd|180|`（`stage.time` 三种对应 `bg.counter.<time>`、`set` 街头/牢房换背景、查封与下雨、热点 9 个的路由、`card_dropped` → 开对的演出、站位矩形 = `CardLayout.spot()`、进场动画在“快动画”下立即到位、夜里人物的 `modulate == night_tint`）、`C01_hud|res://scripts/tests/cards/C01/test_hud.gd|120|`（各格内容来自 CardText 与视图、点钱/黄历开对的抽屉）。
- 截图（`shot_table.gd`）：十个基础夹具各一张画面 `C01_<夹具>.png`；`dusk` `sealed_rain` 各一张；8 个抽屉各开一张（内容是主人的或桩）；帮助、暂停各一张；街头、牢房各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- `CardGameRoot` 的选引擎、命令行、标题、F1、Esc 暂停、设置路径注入、曲目、指引宿主、小游戏宿主（含“算了”按钮）、`close_requested(result)` 约定、引擎要的面板每个只自动开一次、自动试玩框架、`CardTheme` 全部有效；`CardModalHost` 的叠层栈与 `panel_opened/closed` 有效（多带 `show`、多两路）。要换的是 `CardTable` 的分区与手牌行（换成场景层 + HUD + 标签抽屉 + 摆别人的控件）。

**日期**：合并目标从 10-23 改到 **10-27**。

## 只能改这些文件

- `scenes/cards/CardGame.tscn`、`scenes/cards/table/**`、`scripts/cards/ui/table/**`、`scripts/cards/ui/common/card_theme.gd`
- 默认拥有：`scripts/tests/cards/C01/**`、`scripts/tests/cards/suites/C01.txt`、`data/cards/tags/C01.json`、`data/cards/ui_keys/C01.json`
- 以及上述文件的 `.uid` / `.import` sidecar。`git status` 里出现别的路径（包括 `project.godot`、别人的 `.uid`）一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件：尤其 `scripts/cards/api/**`（含 1.3 的 `card_layout.gd`）、`scripts/cards/mock/**`（含夹具）、`scripts/cards/ui/common/{card_panel,card_anchors,w0_stub}.gd`（1.3 另有 `card_stage_panel.gd` `card_stage_script.gd` `card_{stage,dialog,hand,hero,checks}_api.gd` 与 `w0/**`、`scenes/cards/_w0/**`，都归 Claude）、`scripts/tests/cards/lib/**`、`scripts/tests/cards/W0/**`、别的 C 任务的场景和脚本（嵌进来的控件只调用它们的冻结接口）、`project.godot`、`tools/run_*.sh`、`.github/**`、所有旧代码。
2. **不写玩家能看到的最终内容**：不建、不改 `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`；`.gd` 字符串字面量只许 ASCII，`.tscn` 里不出现中文（编辑器里填的 `text`/`tooltip_text`/`placeholder_text` 也算）；所有字经 `CardText`，新键只在 `ui_keys/C01.json` 写键 + `brief`（干巴巴的说明，不写成能直接上线的文案）。
3. 不画正式美术、不往 `art/**` 放图：图只经 `CardArt`；背景、底色、框用 `CardTheme` 的配色键和 StyleBox；不写颜色字面量（只许 `Color.WHITE`、`Color.TRANSPARENT`、`Color(1, 1, 1, a)`）。
4. 不露隐藏数值：不显示 `%`、点数、底价、权重、本心、口碑/风声点数；只显示视图里给的。
5. 不放规则：不重排手牌、不自己判断能不能打烊、不算钱；一切问引擎。不在总线回调里同步 `send()`。
6. 不用 `JevRng`/`randf`/`randi`/`randomize`/`Time` 影响任何结果（纯装饰的抖动可以用固定种子的 `RandomNumberGenerator`）。
7. 不加 `class_name`（冻结表里的 `CardGameRoot` `CardModalHost` `CardMiniGameHost` `CardTheme`，以及 1.3 加的 `CardStage` 除外）、autoload、InputMap、插件、项目设置。
8. 不发 `first_time`；只发归你的 `ui_event`（`panel_opened` `panel_closed` ~~`hand_selected`~~；1.3：`drawer_opened` `drawer_closed` `hotspot_pressed`，`hand_selected` 改归 C02）；不登记不归你的锚点（测试里摆的替身除外）。
9. 不读、不拷旧版 AI 文字（`data/town/onboarding.json`、`data/town/rules.json`、`scripts/town/**` 里的中文）。
10. 不擅自加玩法。

## 接口

**用到**
- `CardEngineApi`（§7.2）：`new_game` `view` `send` `query` `is_busy`；Mock：`MockCardEngine.new(bus)`、`load_fixture(path)`、`sent`。
- 指令：`month.begin` `day.begin` `day.end {confirm}` `card.keep` `card.discard` `street.redeem_shop` `mg.report`（宿主转发）、`game.new`。查询：`card {uid}`（`panel` 字段，§7.4.3）、`stock`（Mock 返回 `{"items": [ItemView]}`）、`firsts`、`day.end_preview`（§7.4.7）。
- CardBus 信号（§7.6）：`view_changed` `request_panel` `minigame_requested` `phase_changed` `game_over` `ui_event`（只为 `panel_closed` 后重新同步面板）。
- 视图字段（§7.5）：`phase` `mode` `date` `notice{weather, market_day, news, almanac}` `money` `rep_tier` `heat_tier` `self` `hand` `kept` `contacts` `demands` `caps` `shelf_count` `tickets` `goals` `open_panel` `dossier_new`。
- 嵌入控件的冻结接口（§7.8 第二张表）：`CardWidget`（`set_card` `set_size_mode` `pressed` `action_requested` `get_uid`）、`CardDemandBoard`（`refresh` `demand_pressed`）、`CardAlmanacStrip`（`refresh`）、`CardStreetOverlay`（`refresh` `redeem_shop_pressed`）、`CardTitle`（`chose`）、`CardGuide`（`bind` `set_enabled` `set_cmdline`（W0 加）`force` `evaluate_now` `tick`）、`CardPanel`（`bind` `open` `refresh` `autoplay_step` `close_requested`）、`CardMiniGame`（`start` `autoplay` `abort` `finished`）。
- **1.3 加**（§7.11，W0 冻结）：`CardLayout`（全部坐标常量与 `screen` `spot` `prop_rect` `slot_rect` `coin_rect`）、接口基类 `CardStageApi`（你来实现）`CardDialogApi` `CardHandApi` `CardHeroApi` `CardChecksApi`、`CardStagePanel`（`bind_stage` `begin_play` `end_play` `on_reply` `on_card_played` `on_hotspot`）、`CardStageScript`（`resolve` `lines` `bg_id` `speaker`）、`CardSettings.fast_anim()`、`scripts/town/settings.gd` 的 `text_cps()`；视图 `stage {set, time, sealed}`、CardView 的 `stage`（G02 合入前没有这些键时按合同 §7.11.3 兜底）。
- `CardAnchors.register/clear`（§7.10.4）、`CardText.ui/card/t/item_text/is_draft`、`CardArt.texture/base_size`、`CardIds.PANEL_SCENES/MINIGAME_SCENES/WIDGET_SCENES/ROOT_SCENE`（1.3 加 `PANEL_SHOW` `panel_scene()` `widget_scene()` `TABS_L` `TABS_R` `TAB_PANELS` `HOTSPOTS` `HOTSPOT_PANELS`）。

**提供（冻结或列在 PR 里）**
- `CardGameRoot`：`engine` `host` `boot(opts)`（冻结）；`autoplay_step() -> bool` `guide` `table` `mg_host` `title` `bus`（W0 加，保留）；1.3 另加 `stage` `dialog` `hand` `hero` `checks`（PR 列出）。
- `CardStage`（`extends CardStageApi`，§7.11.3 的冻结接口，1.3）。
- `CardModalHost.open_panel(kind, args) -> CardPanel`（冻结）；`close_panel` `close_top` `top_panel` `top_kind` `is_open` `refresh`（W0 加，保留）。
- `CardTheme.color/frame_style/font_title/font_body`（冻结）。
- `close_requested(result)` 约定（新，PR 列出）；宿主 Esc 调 `CardPanel.dismiss()`（W0 加在基类，§7.8）。

## 新手指引

- **必须登记的锚点**（§7.10.5，C01 名下全部 23 个，1.3）：`a.top.date` `a.top.weather`（时辰、天气与集市）`a.top.money` `a.top.rep` `a.top.heat` `a.btn.close_day`；场景 `a.scene`（整个场景）`a.scene.customer`（有人站柜台前时）`a.scene.notice`（门边的告示）`a.scene.ledger`（账簿）`a.scene.notebook`（档案簿）`a.scene.calendar`（黄历）`a.scene.cashbox`（钱匣）`a.scene.magnifier`（放大镜）`a.scene.notewall`（墙上的条子，有条子时）；标签 `a.tab.contacts` `a.tab.demands` `a.tab.dossier` `a.tab.rules` `a.tab.shelf` `a.tab.tickets` `a.tab.estates` `a.tab.settings`。~~`a.hand`（手牌行）`a.hand.gold`（手牌最左的金色牌位）~~（10-13 作废，合同 1.3：改归 C02 的手牌扇）；1.2 的 `a.top.notice` `a.left.self` `a.left.contacts` `a.left.kept` `a.right.tickets` `a.right.shelf` `a.right.dossier` 改了名（新名依次是 `a.scene.notice` `a.hero` `a.contacts` `a.hand.kept` `a.scene.ledger` `a.tab.shelf` `a.scene.notebook`，§7.10.5 的改名表），不再登记。
- **必须发的 ui_event**：`panel_opened {kind, show}`、`panel_closed {kind, show}`（宿主：演出、抽屉、叠层都发）、`drawer_opened/closed {kind, side}`、`hotspot_pressed {id}`（1.3 新）；~~`hand_selected {uid}`~~（10-13 作废，合同 1.3：改由 C02 发）。
- **first-time**：本任务不发（`first_time` 由引擎发）；依赖的有 `deal` `notice` `tier_rep` `tier_heat` `market_day` `weather` `ticket` `shelf` `contact` `kept_expire` `kept_risk` `person_state` `shop_closed` `retry` `resume`（1.3：`deal` `contact` `kept_expire` `kept_risk` `person_state` 那几步改由 C02 证明；`demand` 那一步从 C05 挪来）。
- **要证明会亮的步骤**（§7.10.10，1.3 的锚点）：W1 必证——`gd.d1.notice`（`a.scene.notice`）、`gd.tiers`（`a.top.rep`，`stage_day_gte: 7`）、`gd.d1.close`（`a.btn.close_day`，`trigger.hand_clear`）、`gd.market_day` 与 `gd.weather`（`a.top.weather`，`stage_day_gte: 4`）。顺带证明（同一个测试里加几行即可）：`gd.d1.ticket`（`a.scene.ledger`）、`gd.d1.shelf`（`a.tab.shelf`）、`gd.d2.rules`（`a.tab.rules`）、`gd.dossier`（`a.scene.notebook`）、`gd.demand`（`a.scene.notewall`，从 C05 挪来）、`gd.retry` / `gd.resume`（`a.top.date`）、`gd.shop_closed`（`a.scene.notice`）——主锚点在 C01 的步骤全部要有一行断言（审计核对过：除下面两个预留的，每一步都由某个界面任务证明会亮）。~~`gd.d1.deal`（`a.hand`）、`gd.contact`（`a.left.contacts`）、`gd.kept_expire` 与 `gd.kept_risk`（`a.left.kept`）、`gd.person_state`（`a.left.contacts`，备用 `a.left.self`）~~（10-13 作废，合同 1.3：这几步的锚点归 C02，改由 C02 证明）。预留、首发不证：`gd.currency`（`a.top.money`，首发三关不换币）、`gd.branch_pick`（锚点 `a.branch.list` 预留，解放后才有主人）。
- **指引宿主本身**：GuideOverlay 在 CanvasLayer 100；整层鼠标穿透（指引亮着时点手牌照样点得到）；`--guide=` 的优先级在 C16 之下照 §7.10.7 第 1 条；F1 帮助、Esc 暂停不受指引影响。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C01.txt`（名字不带空格、只用 ASCII；每个脚本最后一行打印 `CARDS TEST PASS <名字>`）：

```
# C01 牌桌（docs/handoff_cards/C01_table.md）
C01_layout|res://scripts/tests/cards/C01/test_layout.gd|240|
C01_input|res://scripts/tests/cards/C01/test_input.gd|180|
C01_host|res://scripts/tests/cards/C01/test_host.gd|180|
C01_minigame_host|res://scripts/tests/cards/C01/test_minigame_host.gd|120|
C01_guide_host|res://scripts/tests/cards/C01/test_guide_host.gd|180|
C01_theme|res://scripts/tests/cards/C01/test_theme.gd|60|
C01_autoplay|res://scripts/tests/cards/C01/test_autoplay.gd|240|
C01_next_day|res://scripts/tests/cards/C01/test_next_day.gd|240|
C01_stage|res://scripts/tests/cards/C01/test_stage.gd|180|
C01_hud|res://scripts/tests/cards/C01/test_hud.gd|120|
```

（最后两行是 1.3 新增，见上方“10-13 变更二”的“测试与截图”。）

| 测试 | 通过条件 |
|---|---|
| `test_layout.gd` | 十个基础夹具 + 自己的夹具逐个 `boot({"bus", "fixture", "skip_title": true})`：~~15 个锚点 `t.anchor_ok()`；顶栏/左栏/柜台桌面/手牌区/右栏五块互不重叠；`day_full` 的 9 张手牌全在手牌区内，第一张就是 `view.hand[0]` 且是金色牌、x 最小~~（10-13 作废，合同 1.3：改成 C01 的锚点 `t.anchor_in(id, CardLayout.<常量>)` 都在规定的矩形里；HUD、对话框最大框、手牌扇的带、头像与人脉、标签、打烊按钮两两不重叠）；`t.all_text_from_cardtext(game)` 为空；任何 Label/Button 文字里没有 `%`；口碑/风声处只出现档位文字 |
| `test_input.gd` | ~~1–9 键 → `hand_selected` + 对应面板 `panel_opened`~~（10-13 作废，合同 1.3：1–9 列着回话时选回话，否则手牌扇 `select_index` → `hand_selected`；Space/Enter 推对话框、Enter 打出选中的牌；Esc 顺序小游戏 → 叠层 → 抽屉 → 演出 → 暂停）；F1 在画面和任一面板之上都能开 `help`、F1/Esc 关；没有面板时 Esc 开 `pause`；任何面板上 Esc 都关掉它（调 `dismiss()`）；Tab 能在按钮间移焦点 |
| `test_host.gd` | `CardIds.PANELS` 里每个 kind 都能开（`minigame` 除外），不报错，`panel_opened`/`panel_closed` 成对（1.3：开到对的那一层、带对的 `show`；一次只演一出；抽屉一次一个）；不在表里的 kind 开占位面板不报错；`result.next` / `open_uid` / `to_title` 三种约定生效；打开面板 ≤ 50 ms（PR 里列测得数） |
| `test_minigame_host.gd` | `day_counter` 夹具发 `mg.request` → 宿主实例化小游戏 → `autoplay_current(0.8)` → `mock.sent` 里有 `mg.report {uid, item, result}`（result 只有 `quality_permille` `observations` `minutes` `measures` `aborted`）；Esc → `aborted: true` |
| `test_guide_host.gd` | GuideOverlay 的父节点是 layer 100 的 CanvasLayer；它和所有子孙 `mouse_filter == IGNORE`；亮着一步时在手牌中心模拟一次鼠标点击（`Input.parse_input_event` 或 viewport `push_input`），`CardWidget.pressed` 照样发出；`--cards-mock` 下不给 `--guide` 时 `is_enabled()` 为假；按 §3.3 开头的做法（`force(true)`、`skip_fades = true`、`load_steps(<本目录的 guide_steps.json>)`、`bus.first_time.emit(...)`、`evaluate_now()`）证明上面列的每一步 `active_step()` 正确，做 `done_when` 里的动作后变成 `""` 且 `mock.sent` 有 `ui.guide {status: "done"}` |
| `test_theme.gd` | §2.4 的每个配色键都能取到（不是 MAGENTA）；15 种类型 + 金色的 `frame_style` 都返回 StyleBox；静态扫描自己的 `.gd`：字符串字面量没有中文、没有颜色字面量；自己的 `.tscn` 没有中文 |
| `test_autoplay.gd` | Mock 情景模式、种子 7：只用 `autoplay_step()` 从新局走到第 4 天早上不卡死；12 张牌 + 面板打开时空闲帧 `Performance.get_monitor(OBJECT_COUNT)` 不增长 |
| `test_next_day.gd` | 见下方“10-13 变更”最后一条：每个夹具按一次“打烊 · 下一天”（要确认的开 `end_day`、`mock.sent` 最后一条是 `day.end {confirm: false}`；不用确认的视图的阶段或日子变了）；`game_over` 时按钮开局终面板；`CardIds.PANELS` 每种面板 Esc 都关得掉、该发的“算了”指令发了；小游戏的“算了”按钮 → `mg.report` 里 `aborted: true`；引擎要的面板关掉后不再弹回来；情景模式只按按钮走到第 2 关第一天早上 |

- **W2 加**：`test_real_engine.gd`（`CardEngine.new(bus)` + `new_game({"seed": 7, "only_examples": true, "save_dir": t.user_dir()})`，用 `autoplay_step()` 走完第 1 天不报错）；清单加一行 `C01_guide_host_k16|res://scripts/tests/cards/C01/test_guide_host.gd|180|--steps=k16 --name=C01_guide_host_k16`（脚本从 `--name=` 取清单名；`--steps=k16` 时改用 `mock.query(&"guide_data")`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  $GODOT --headless --path . --import
  CARDS_SUITES=W0,C01 bash tools/run_card_tests.sh               # 开发中
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh # 提 PR 前，全绿
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C01/shot_table.gd -- --out=/tmp/shots/C01
  ```
- **截图**（脚本不进清单，参考 `scripts/tests/cards/W0/shot_table.gd`：等 4 帧 + `RenderingServer.frame_post_draw` 后存 viewport 图）：`shot_table.gd` → ~~十个基础夹具 + 自己的夹具各一张 `C01_<夹具>.png`、帮助盖在牌桌上一张、暂停一张~~（10-13 作废，合同 1.3：清单见上方“10-13 变更二”的“测试与截图”）；`shot_guide.gd` → 上面列的每个指引步骤亮起时一张 `guide_<步骤 id>.png`。全部 1280×720 画面截图。截图传到 PR 描述；传不了图就提交到 `scripts/tests/cards/C01/shots/`（目录里放空文件 `.gdignore`，单个 PR ≤ 4 MB）。没有 xvfb 的环境在 PR 里说明，由 K14/Claude 补拍。
- **视觉规格**：~~§1.2 的分区坐标一个不差~~（10-13 作废，合同 1.3：坐标只用 `CardLayout`，§7.11.2，一个不差）；像素图整数倍、`TEXTURE_FILTER_NEAREST`；字体 `CardTheme.font_title()/font_body()`，正文 16–18、牌名 20、面板标题 28–36、最小 14；动画只用 Tween、单段 ≤ 0.6 秒；颜色只用配色键；集显 60 fps。

## 交付

- PR 标题：`[C01] <中文摘要>`，目标分支 `claude/festive-ride-vud32a`。建议拆成：~~①牌桌分区 + 宿主 + 测试骨架；②键盘、货架抽屉、家当入口、截图~~（10-13 作废，合同 1.3：①画面根的层次 + `CardStage` + 宿主分三路 + 测试骨架；②HUD、标签与抽屉、热点与打出的路由、键盘、截图）；③（W2）真引擎集成测试 + K16 步骤复测。
- PR 描述按 `.github/pull_request_template.md` 填全，必须有：改动路径清单；自查全部打勾；`run_card_tests.sh` 与 `run_legacy_smoke.sh` 的最后 20 行；1280×720 画面截图（每个夹具一张 + 每个指引步骤一张）；用到的 JevRng 域（本任务：无）；登记的锚点、发的 `ui_event`、依赖的 first-time；新加/保留的公开函数（含 `close_requested` 约定；`dismiss()` 是 W0 基类的）；悬空引用与依赖（嵌的哪些控件还是桩）；需要主创/编排决定的事（上面的默认做法；1.3 起第 1、2 条作废，只剩第 3 条）；性能数（打开面板、刷新 12 张牌）；最后一节“回报”（见下）。

## 审核（Claude 按 §14.2 逐条过，本任务重点）

- `check_pr_paths.py` 通过；没碰 `w0_stub.gd` 以外的 Claude 文件，且不再 `preload` 它。
- ~~分区坐标与 §1.2 一致、截图无重叠；9 张手牌不出界；金色牌永远第一张（界面没有排序代码）。~~（10-13 作废，合同 1.3：坐标与 `CardLayout` 一致、整数倍、字不进场景层、画面截图里 HUD/对话框/手牌扇/头像/标签/打烊按钮不重叠；手牌顺序归 C02）
- 宿主：每个面板都发 `panel_opened/closed`（1.3 带 `show`，按“呈现”分三路，一次只演一出）；缺场景占位不报错；小游戏宿主只转发 `mg.report`；不在总线回调里同步 `send()`。
- 指引层在 layer 100、全部鼠标穿透、没有 `_input/_gui_input`；`--guide` 默认值对；F1/Esc 行为对。
- 没有中文字面量、颜色字面量、`%`、点数；`CardTheme` 退回规则对。
- `W0_*` 清单仍全绿；`--cards-autoplay` 输出没变。

## 回报（执行者填写）

> `docs/handoff_cards/` 归 Claude，执行者**不要改本文件**（改了 PR 路径检查会失败）。把下面这张表填好，贴在 PR 描述最后一节“回报”，Claude 合并时抄回来。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（清单名 → 通过；贴最后 20 行） | |
| 截图（文件名列表或 PR 附件） | |
| 登记的锚点 / 发的 ui_event / 证明会亮的步骤 | |
| 新加或保留的公开函数 | |
| 性能实测 | |
| 合同或数据缺口（编号列出） | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
