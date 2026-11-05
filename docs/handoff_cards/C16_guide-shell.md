# C16 `guide-shell` · 新手指引引擎 + 卡牌版的标题、暂停、设置、曲目

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C16 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C16: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 16**（在第 16 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C16`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）：W0 已给了能用的最小 `CardGuide`（挑步骤、`trigger` 各项、priority、max_shows、`done_when`、timeout、间隔、每天上限、自动完成、备用锚点）、`CardAnchors`（冻结）、三个总线信号 `first_time` `command_done` `ui_event`、Mock 对指引查询的回答、例子集的 3 步指引。引擎一侧（`CardFirsts`、`ui.guide`、`guide_data` 等查询）是 G01 的，W0 已能用。步骤与规矩页骨架由 Grok 的 K16 写（`data/cards/guide/{steps,rule_pages}.json`）。
- **波次（Wave）**：W1 开发并**尽早合入**（**W1 完成条件之一**：C16 的指引引擎合入；各界面任务 W2 的指引复测都靠它）；W2：K14 用真引擎走第 1–3 天并逐步截图，你配合修问题，并把自己的测试换成 K16 的 `steps.json` 再跑一遍。

## 分支

`cards/C16-guide-shell`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

主创 2026-10-13 的硬性要求：**所有机制都必须有新手指引**。本任务做指引的引擎和覆盖层：①讲在游戏世界里——由人物开口（~~左下角教的人头像 + 一句话~~（10-13 作废，合同 1.3：教的人在画面里开口——人物站到柜台一侧说一句、物件用一张批注纸，见下方“10-13 变更二”）），不是说明书弹窗；②第一次遇到某机制时才触发（引擎发 `first_time`），按天逐步解锁，一次只亮一步、每天新亮的有上限；③教过的都能回看（规矩页在 C10；进度存档在 `ui` 命名空间），设置里能关；④不打断节奏——整层鼠标穿透、不吃按键、不暂停引擎，自动试玩和测试里能关；⑤高亮对应的界面元素（锚点外框发光）+ 锚点旁一句气泡说“现在可以做什么”；⑥文字只有人写（AI 只写 brief，`say` `bubble` 由 A 写）。另做卡牌版的外壳：标题、暂停、设置（含“新手提示：开/关”）、曲目。

## 必读

1. `docs/cards/DESIGN_cards.md` §九.4（新手指引：主创原话与节奏表，全部读）、§一、§九.3。
2. `docs/cards/CARDS_INTERFACES.md`：§0（红线 4、8）、§1.2（新手指引那一行：layer 100、一次只亮一处、颜色键 `guide_glow` `guide_bubble` `guide_ink`；音乐那一行）、§2.3（`settings.gd` 构造时传路径；`pause_menu.gd`、`settings_panel.gd`、`guide.gd`、`onboarding.json` 只读参考）、§3.3 C16、§4.6（`rules/guide.json`）、§4.7.21（`guide_step` / `rule_page` 的全部字段与含义）、§6.1（`ui` 命名空间：不进哈希、读档和重来取并集）、§7.4（`ui.guide`；查询 `firsts` `guide_data` `guide_progress` `guide_conds`）、§7.6（三个信号与单向规则）、§7.8（`pause` `settings` 面板、`CardTitle` 控件）、**§7.10 全节**（规则、分工、锚点、界面事件、引擎一侧、CardGuide 接口与做法 8 条、设置与命令行、测试、66 个机制的步骤总表与规矩页、七处冲突的默认做法、教学日）、§11.2、§12.1–§12.4、§13.4（W1 完成条件）、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/shell/{card_guide,card_title,card_pause,card_settings,card_music}.gd`、`scenes/cards/shell/*.tscn`（W0）、`scripts/cards/ui/common/card_anchors.gd`、`scripts/cards/core/{card_bus,firsts,core_install}.gd`（`ui.guide`、`guide_data_of`）、`scripts/cards/mock/mock_engine.gd`（`_guide()`、`ui.guide` 在内存里更新进度）、`scripts/cards/ui/table/card_game_root.gd`（怎么挂指引、`--guide=`、`set_cmdline`）、`scripts/tests/cards/W0/{test_table_3days,shot_table}.gd`（指引在牌桌上前三天按顺序亮的现成测试）、`data/cards/_examples/guide/{steps,rule_pages}.json`、`data/cards/rules/guide.json`。
4. 只读参考（**重写做法，不实例化、不改、不拷任何文字**）：`scripts/town/guide.gd`（挑步骤、渐隐、进度）、`data/town/onboarding.json`（旧步骤的结构；文字是 AI 写的，一个字也不许拷）、`scripts/town/pause_menu.gd`、`scripts/town/settings_panel.gd`、`scripts/town/settings.gd`（`music` `sfx` `text_speed` `guide_hints` 四个键、`load_file()` `save_file()`）、`scripts/audio/music_director.gd`（第 13 行写死旧曲目清单，卡牌版不用它）。

## 要做的事

### A. 指引引擎 `CardGuide`（`scripts/cards/ui/shell/card_guide.gd`，`GuideOverlay.tscn` 的根，接口冻结）

- [ ] 冻结接口一个不改：`shown_log` `skip_fades` `bind(engine, bus)` `set_enabled(on)` `is_enabled()` `force(on)` `evaluate_now()` `active_step()` `tick(delta_s)` `load_steps(data)`；保留 W0 加的 `set_cmdline(mode)`（C01 在用，PR 里列为公开接口）。
- [ ] **开关**（§7.10.7 第 1 条）：`force()` > 命令行 `--guide=on|off`（C01 解析后 `set_cmdline`）> 设置 `guide_hints`。关着时什么都不亮、**不发 `ui.guide`**、`shown_log` 不长。
- [ ] **记事**（第 2 条）：听 `first_time`（记机制和 `args`）、`command_done`（`ok` 的记 `cmd:<cmd>`）、`ui_event`（记 `ui:<name>`；`panel_opened` 另记 `panel:<kind>` 并维护开着的面板）、`phase_changed`、`view_changed`（重读 `view()`）。启动时、以及 `cmd:game.load` / `cmd:game.retry_stage` / `cmd:game.new` 之后用 `query("firsts")`、`query("guide_progress")`、`query("guide_data")` 重建（读档、重来本关后教过的不再教）。
- [ ] **挑步骤**（第 3 条）：每次事件后和 `tick` 时：没有正在亮的、离上一步结束已过 `gap_ms`、今天新亮的没到 `max_new_per_day` → 在“能亮”的步骤里挑 `priority` 最大的（同 priority 按文件顺序）。“能亮” = 没完成、亮过的次数 < `max_shows`、`trigger` 全满足（`first` `phase`（可以是数组）`mode` `stage_gte` `stage_day_gte` `abs_day_gte` `after` `panel` `hand_clear` `cond`——`cond` 用 `query("guide_conds", {ids})`，只拿真/假）、主锚点或备用锚点 `CardAnchors.has()`（1.3：新旧锚点名互认，见下方“10-13 变更二”）。锚点里的 `{uid}` 用那次 `first_time` 的 `args.uid` 代入。**按 `trigger.first` 预先建索引**，每次挑步骤 ≤ 1 ms。
- [ ] **interrupt**：`interrupt: true` 的步骤可以打断正在亮的、`priority` 比它小的那一步（被打断的快速渐隐，**不算亮过**）。
- [ ] **自动完成**（第 4 条）：能亮的步骤，`done_when` 里某个 `first:<m>` 在它能亮之前就已经记下了 → 不亮，悄悄发 `ui.guide {step, status: "done"}`。
- [ ] **亮**（第 5 条）：发 `ui.guide {step, status: "shown"}`（`call_deferred`，不在总线回调里同步 `send`）、`shown_log` 追加、`ui_event("guide_shown", {step})`；锚点外框发光（`guide_glow`，跟着 `CardAnchors.rect()` 每帧走）；**气泡** `CardText.t("<step>#bubble")`：贴着锚点、**不盖住锚点**、整块在 1280×720 里、最宽 `bubble_max_w`，底框用 `CardArt` 的 `frame.guide_bubble`（九宫格；没有就用 `guide_bubble` 配色的 StyleBox），字色 `guide_ink`；**教的人**：~~左下角头像——人物 `portrait.<person>`、物件 `icon.obj.<名>`（`obj.notice` `obj.almanac` `obj.brother_ledger`）、`""` 不放头像——加一句 `CardText.t("<step>#say")`~~（10-13 作废，合同 1.3：改成 §7.10.7 第 5 条的 1.3 写法——人物站到 `GUIDE_TEACHER` 开口、物件用批注纸，见下方“10-13 变更二”；那句话照旧是 `CardText.t("<step>#say")`）。主锚点没了换备用；都没了就快速渐隐（`fade_fast_ms`），不算完成、不算亮过。
- [ ] **结束**（第 6 条）：亮起之后发生了 `done_when` 里任一个（`cmd:` `ui:` `first:` `panel:` `timeout`）→ 渐隐（`fade_out_ms`）、`ui.guide {step, status: "done"}`、`ui_event("guide_done", {step})`。到 `seconds`（没写用 `default_seconds`）：`done_when` 有 `timeout` 算完成；没有就渐隐、算亮过一次（以后还会再亮，直到 `max_shows`）。
- [ ] **不挡**（第 7 条）：所有节点 `mouse_filter = MOUSE_FILTER_IGNORE`；**不实现** `_input` / `_unhandled_input` / `_gui_input` / `_unhandled_key_input`；除 `ui.guide` 外不发任何指令；`autoplay_step()` 不看它。
- [ ] **渐显渐隐**：`fade_in_ms` / `fade_out_ms` / `fade_fast_ms`（Tween，读 `rules/guide.json`；`skip_fades = true` 时全按 0、计时只靠显式 `tick()`）。
- [ ] **性能**（第 8 条）：挑步骤 ≤ 1 ms（70 个步骤时）；空闲时 `_process` 不分配内存（不在 `_process` 里建字典、数组、字符串拼接）。
- [ ] **设置联动**：`CardGuide` 在 `_ready` 时加入组 `card_guide`，设置面板改开关时 `get_tree().call_group("card_guide", "set_enabled", on)`（两个文件都归你）。
- [ ] **参数文件** `data/cards/rules/guide.json`（归你；只改数，整数毫秒；`_meta.owner` 保持 `C16`）。

### B. 外壳

- [ ] **CardTitle**（`card_title.gd`，`class_name CardTitle`，冻结 `signal chose(action)`：`&"new"` `&"continue"` `&"settings"` `&"quit"`）：背景（`CardArt` 的 `bg.title`，320×180 ×4；没有就配色）、标题字体 `CardTheme.font_title()`（标题文字是界面键，A/B 写）、四个按钮；“继续”只在 `CardSave.exists(CardSave.suspend_path())` 时可点；键盘上下选、Enter 确认。
- [ ] **CardPause**（`card_pause.gd`，`class_name CardPause`，kind `pause`）：照 `scripts/town/pause_menu.gd` 的做法**重写**：继续（关）、存档说明（一句界面键：自动存档在每天早上，不提供手动存档——以 G02 的实现为准）、设置 → `close_requested({"next": {"kind": "settings", "args": {}}})`、帮助 → `close_requested({"next": {"kind": "help", "args": {}}})`（C10 的面板）、回标题 → `close_requested({"to_title": true})`、退出 → `close_requested({"quit": true})`（`close_requested` 的这几个约定由 C01 的宿主实现，见 C01 卡）。
- [ ] **CardSettings**（`card_settings.gd`，`class_name CardSettings`，kind `settings`；1.3：呈现为右抽屉 388×630）：音乐音量、音效音量、文字速度、**新手提示：开/关**（写 `settings.gd` 的 `guide_hints`，并 `call_group("card_guide", "set_enabled", on)`）、快动画（卡牌版独有）。存法（§3.3 C16）：旧的四个键用 `scripts/town/settings.gd`（`load(…).new(path)`；路径来自 `open(args.settings_path)`，没有用 `user://settings.json`）；`fast_anim` 存在你自己的 `user://cards/settings.json`（路径来自 `args.cards_settings_path`）——**不往 `user://settings.json` 塞新键**。加一个公开的静态读取 `static func fast_anim(path: String = "user://cards/settings.json") -> bool`（PR 里列出，供 C02/C03/C06/C07/C08/C09 的动画用；~~合同还没冻结这个接口，开 `[api]` issue 请 Claude 定~~ 1.3：合同 §7.8 已冻结这个签名，C01 也用它定对话框速度）。测试一律用 `t.user_dir()` 下的路径。
- [ ] **曲目** `scripts/cards/ui/shell/card_music.gd`（`extends Node`，不写 `class_name`，`preload` 用）+ `data/cards/audio/music.json`：格式由你定并写进 PR（建议 `{"_meta": {"owner": "C16", "schema": 1}, "cues": {"title": {"human": "audio/cards/music/title.ogg", "placeholder": "audio/_placeholder/music/title.ogg", "legacy": "audio/music/<旧曲>.ogg"}, "day": …, "night": …, "month_close": …, "year_jump": …}}`）；`play(cue)` 先找 `human`（B 做），没有且 `!CardShip.is_ship()` 再找 `placeholder`，再找 `legacy`（**旧版曲目只在 `!CardShip.is_ship()` 时可以借来当占位**）；都没有就静音、不报错；`set_volume(linear)`；加 `bind(bus)`：听 `phase_changed` 自动切曲（PR 里列出）。C01 的根场景负责把它加进树（见 C01 卡；如 C01 还没接，开 `[shared]` issue）。不用 `music_director.gd`。无头、Dummy 驱动不报错。
- [ ] 外壳面板对任意 `args` 不报错（`W0_skeleton` 会 `open({"uid": "c0002"})`）；不再 `preload` `w0_stub.gd`；`autoplay_step()`：暂停 → 继续（关）；设置 → 关。
- [ ] **界面键** `data/cards/ui_keys/C16.json`（`c16.` 开头，键 + `brief`，`_meta._provenance`）：`c16.title.<new|continue|settings|quit>` `c16.title.name` `c16.pause.<resume|save_note|settings|help|title|quit>` `c16.settings.<music|sfx|text_speed|guide_hints|fast_anim>` `c16.settings.on` `c16.settings.off`（设置里“新手提示”那一行的字由 B 写，§7.10.2）。不再用 `w0.title.*`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] 指引引擎本身不用改接口。三个步骤的触发和讲法变了（K16 写数据，你的 21 步测试步骤与夹具照改）：`gd.d1.close`（第 1 天手上要了断的都处理完了，`hand_clear`）讲“打烊 · 下一天”随时能按、节奏你定；`gd.must`、`gd.gold_leave` 改成在 C08 的确认面板上亮（`trigger.first` + `trigger.panel: "end_day"`，锚点 `a.endday.blocked` / `a.endday.gold_leave`），讲没处理的会怎样。
- [ ] 你的夹具 `guide_d1..d3` 里 `command_done` 的 `day.end` 参数改成 `{"confirm": false}` / `{"confirm": true}`（1.1 的 `confirm_gold_leave` 作废）；第 1–3 天按教学日程不会出现要确认的打烊，`_test.d1_3` 不变。
- [ ] `CardGuide` 除了 `ui.guide` 不发任何指令（照旧）——指引的 `seconds`、渐隐只管指引自己，**绝不因为时间到了替玩家推进**（红线 9）。
- [ ] 外壳：暂停菜单、设置面板 Esc 都能关；标题的“继续”= 续玩点（主创 10-13 确认：每关开头 + 每天早上的续玩点）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **教的人**（§7.10.7 第 5 条的 1.3 写法）：人物 → 没有叠层、对话框没显示时在 `GUIDE_TEACHER` 画站着的人（`stage.<人物>`，没有用 `portrait.<人物>`，×4，夜里乘 `night_tint`），那句话放 `GUIDE_SAY`；对话框显示着（`CardAnchors.has(&"a.dialog")`）或叠层开着时不画人，只在 `GUIDE_SAY`（叠层开着用 `GUIDE_SAY_LOW`）里放 64×64 头像 + 那句话；物件 → 批注纸（`frame.guide_note`，没有用 `guide_note` 色）+ 物件图标；`""` → 只有那句话。叠层开没开：听 `panel_opened/closed` 的 `show`。气泡的规矩不变。
- [ ] **锚点新旧互认**：找锚点时先步骤写的，没有就试 `CardIds.ANCHORS_RENAMED` 里它的新名（或旧名），再试备用锚点。
- [ ] **CardSettings 改成右抽屉**（kind `settings`，388×630）；冻结静态读取 `static func fast_anim(path: String = "user://cards/settings.json") -> bool`；改了设置以后 `get_tree().call_group("card_settings_listeners", "on_settings_changed")`（C01 据此重设对话框速度）。暂停仍是叠层；暂停里的“设置”开设置抽屉。
- [ ] 你自己的 21 步测试步骤（`guide_steps` 夹具）按合同 §7.10.10 的 1.3 改表改锚点和 `done_when`。

**新增 / 作废的交付**

- 没有新增文件。
- **作废**：“左下角教的人头像”的画法。

**锚点、界面事件、要证明的步骤**

- 不变（`a.settings.guide_toggle` 在设置抽屉里）。

**测试与截图**

- 加 `C16_teacher|res://scripts/tests/cards/C16/test_teacher.gd|120|`（人物步骤：没有对话框时站着的人在 `GUIDE_TEACHER`、话在 `GUIDE_SAY`；登记一个占位的 `a.dialog` 后不画人；叠层开着用 `GUIDE_SAY_LOW`；物件步骤用批注纸；旧锚点名的步骤找得到新名登记的锚点；全部节点鼠标穿透）。
- 截图：第 1–3 天 21 步每步一张画面截图（看得见教的人站在柜台一侧或批注纸、锚点发光、气泡）；标题、暂停、设置抽屉各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 指引引擎（挑步骤、interrupt、自动完成、渐隐、存进度、开关、测试钩子）、标题、暂停、曲目全部有效；换的是教的人的画法、找锚点的互认、设置的呈现。

**日期**：指引引擎合并目标从 10-20 改到 **10-23**。

## 只能改这些文件

- `scenes/cards/shell/**`、`scripts/cards/ui/shell/**`、`data/cards/rules/guide.json`、`data/cards/audio/music.json`
- 默认拥有：`scripts/tests/cards/C16/**`、`scripts/tests/cards/suites/C16.txt`、`data/cards/tags/C16.json`、`data/cards/ui_keys/C16.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件：`scripts/cards/ui/common/card_anchors.gd`（冻结，Claude）、`scripts/cards/core/**`（`CardFirsts`、`ui.guide`、指引查询归 G01）、`scripts/cards/mock/**`、`data/cards/guide/**`（K16）、`data/cards/_examples/**`、C01 的根场景、C10 的规矩页与帮助、`scripts/town/**`（只读）、`scripts/audio/music_director.gd`、`audio/**`（`audio/cards/**` 归 B、`audio/_placeholder/**` 归 K12）。
2. **不写最终内容**：教的人说的话（`say`）、气泡（`bubble`）、标题、暂停与设置里的字全由人写（A 写指引正文，B 写界面字）；**不拷 `data/town/onboarding.json`、`scripts/town/guide.gd`、`pause_menu.gd`、`settings_panel.gd` 里的任何中文**；不碰 `data/cards/text/**`、`art/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
3. 不写颜色字面量（发光、气泡、遮罩只用 `guide_glow` `guide_bubble` `guide_ink` 等配色键）；头像、物件图标、气泡框只经 `CardArt`。
4. **指引不改游戏**：除 `ui.guide` 外不发任何指令；不连引擎内部；`ui_event` 只发 `guide_shown` `guide_done`；不吃输入、不暂停、不挡点击；开着和关着指引，同一种子同一串指令的状态哈希相同（K14 在 W2 验）。
5. 不露隐藏信息：指引只显示 `say`/`bubble`（人写；K13 审措辞、K15 查 `%`）；不显示步骤 id、`priority`、计数。
6. 不用随机；不加冻结表以外的 `class_name`（`CardGuide` `CardTitle` `CardPause` `CardSettings` 之外不写）；不加 autoload/InputMap/音频总线（`project.godot` 不许改）。
7. 不发 `first_time`。

## 接口

**用到**：`CardEngineApi.view/send/query`；指令 `ui.guide {step, status}`（只改 `ui`、不发事件、不进日志，§7.10.6）；查询 `firsts` `guide_data`（`{steps, pages, settings}`）`guide_progress` `guide_conds {ids}`；CardBus `first_time` `command_done` `ui_event` `phase_changed` `view_changed`；`CardAnchors.rect/has`；`CardText.t/ui`（`<step>#say`、`<step>#bubble`）；`CardArt`（`portrait.<person>`、`icon.obj.<名>`、`frame.guide_bubble`、`bg.title`；1.3 加 `stage.<person>`、`frame.guide_note`）；1.3：`CardLayout.GUIDE_TEACHER/GUIDE_SAY/GUIDE_SAY_LOW`、`CardIds.ANCHORS_RENAMED` 与 `anchor_aliases()`、界面事件 `panel_opened/closed` 的 `show`；`CardTheme`；`CardSave.exists/suspend_path`；`scripts/town/settings.gd`（只调用）。

**提供（冻结）**：`CardGuide`（§7.10.7 全部接口 + `set_cmdline`）、`CardTitle.chose`、`CardPause`、`CardSettings`（`CardPanel` 接口）、`GuideOverlay.tscn` 路径。新增（PR 列出，等合同确认）：`CardSettings.fast_anim()`（1.3 已冻结，§7.8）、组名 `card_settings_listeners`（1.3，C01 听它）、`card_music.gd` 的 `bind(bus)`、`music.json` 格式、组名 `card_guide`。

## 新手指引

- **必须登记的锚点**：`a.settings.guide_toggle`（设置里“新手提示”那一行；1.3：在设置抽屉里）`a.pause.help`（暂停里的“帮助”按钮）。
- **必须发的 ui_event**：`guide_shown {step}`、`guide_done {step}`。
- **first-time**：不发；指引引擎消费全部 66 个机制（`CardIds.FIRSTS`）的 `first_time`。
- **要证明会亮的步骤**：**新存档第 1–3 天按顺序**亮出 `_test.d1_3` 规定的步骤（§7.10.10 起步顺序：`gd.m.open` → `gd.m.wheel` → `gd.m.incense` → `gd.d1.notice` → `gd.d1.deal` → `gd.d1.person` → `gd.d1.look` → `gd.d1.spot` → `gd.d1.tiers` → `gd.d1.ticket` → `gd.d1.shelf` → `gd.d1.buyer` → `gd.d1.close` → `gd.d1.night` → `gd.d1.settle` → `gd.d2.rules` → `gd.d2.gold` → `gd.choice` → `gd.d2.keep` → `gd.slots` → `gd.coins`），并且**每一步一张截图**。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C16.txt`：

```
# C16 新手指引与外壳（docs/handoff_cards/C16_guide-shell.md）
C16_guide_d1_3|res://scripts/tests/cards/C16/test_guide_d1_3.gd|240|--name=C16_guide_d1_3
C16_guide_d1_3_examples|res://scripts/tests/cards/C16/test_guide_d1_3.gd|240|--steps=examples --name=C16_guide_d1_3_examples
C16_guide_rules|res://scripts/tests/cards/C16/test_guide_rules.gd|180|
C16_guide_switch|res://scripts/tests/cards/C16/test_guide_switch.gd|120|
C16_guide_overlay|res://scripts/tests/cards/C16/test_guide_overlay.gd|120|
C16_shell|res://scripts/tests/cards/C16/test_shell.gd|240|
C16_settings|res://scripts/tests/cards/C16/test_settings.gd|120|
C16_music|res://scripts/tests/cards/C16/test_music.gd|60|
C16_teacher|res://scripts/tests/cards/C16/test_teacher.gd|120|
```

（最后一行是 1.3 新增，见上方“10-13 变更二”的“测试与截图”。）

| 测试 | 通过条件 |
|---|---|
| `test_guide_d1_3.gd`（无头，进清单） | 夹具 `guide_d1` `guide_d2` `guide_d3`（`scripts/tests/cards/C16/fixtures/`：新存档第 1–3 天按教学日程会发出的事件序列——视图变化、`first_time`、`command_done`、`ui_event`、`tick`——加上每一步要用的锚点矩形；测试场景里**自己摆占位 Control 登记锚点**，真部件的锚点由各 C 任务自己测；可以用 Mock 夹具，也可以在本目录写一个 `extends CardEngineApi` 的测试用假引擎）。默认用本目录按 §7.10.10 写的 21 步测试步骤 `guide_steps_full.json`（锚点、机制名、`after`、`done_when` 都用真的，`_test.d1_3` 照上面的顺序）：`CardGuide.shown_log` **按顺序等于** `_test.d1_3`；每一步都发了 `ui.guide shown` 和 `done`。`--steps=examples` 用 `data/cards/_examples/guide/steps.json`（3 步）。K16 合入后加一行 `C16_guide_d1_3_k16|res://scripts/tests/cards/C16/test_guide_d1_3.gd|240|--steps=k16 --name=C16_guide_d1_3_k16`（同一个脚本从 `--name=` 取清单名打印 PASS 行）：读 `data/cards/guide/steps.json` 的步骤和 `_test.d1_3`（用 `CardDB.read_json` 直接读 `_test`，`guide_data` 会剥掉它）。 |
| `test_guide_rules.gd` | 各一个单测：priority（大的先）、同 priority 按文件顺序、interrupt（打断小的、被打断的不算亮过）、`max_shows`（没完成最多再亮几次）、间隔 `gap_ms`（间隔内不亮）、每天上限 `max_new_per_day`（换天重置）、自动完成（`first:` 早已记下 → 不亮、发 `done`）、备用锚点（主锚点没有用备用）、锚点消失（快速渐隐、不算完成不算亮过）、`timeout`（有 → 完成；没有 → 算亮过一次）、`after` 链、`hand_clear`、`panel`、`cond`（`guide_conds` 回假时不亮）、`{uid}` 代入 |
| `test_guide_switch.gd` | 关着（设置、命令行、`force(false)` 三种）时：什么都不亮、`shown_log` 为空、`mock.sent` 里**没有** `ui.guide`；优先级 `force` > 命令行 > 设置；亮着时 `set_enabled(false)` 立刻收起；`game.load` 之后按 `guide_progress` 重建，已完成的不再亮 |
| `test_guide_overlay.gd` | 覆盖层和所有子孙 `mouse_filter == IGNORE`；脚本里没有 `_input` `_unhandled_input` `_gui_input` `_unhandled_key_input`；气泡整块在 1280×720 内、不和锚点矩形相交、宽 ≤ `bubble_max_w`；~~教的人：人物用 `portrait.<id>`、物件用 `icon.obj.<名>`、`""` 没有头像~~（10-13 作废，合同 1.3：教的人的画法测在 `C16_teacher`）；气泡和台词来自 `CardText.t("<step>#bubble"/"#say")`；70 个步骤时挑一次 ≤ 1 ms（PR 列数）；空闲 60 帧 `Performance.get_monitor(OBJECT_COUNT)` 不增长 |
| `test_shell.gd` | 牌桌根场景：标题 → 新局 → 牌桌 → Esc 暂停 → 回标题 → 继续，往返三次，结束时没有对象泄漏；没有续玩点时“继续”不能点（`CardSave.set_root(t.user_dir())`）；暂停的“设置/帮助/回标题/退出”发出对应的 `close_requested` result |
| `test_settings.gd` | 用 `t.user_dir()` 下的两个路径：改音量、文字速度、新手提示、快动画 → 写进文件；`user://settings.json` 那份只有原来的四个键；关“新手提示” → 组里的 `CardGuide.is_enabled()` 为假；`CardSettings.fast_anim(<测试路径>)` 读得对 |
| `test_music.gd` | `music.json` 的每个曲目键都能解析（文件不存在时静音不报错）；`human` 路径只在 `audio/cards/music/` 下、`placeholder` 只在 `audio/_placeholder/` 下；静态扫描：引用 `legacy` / `audio/music/` 的代码在 `!CardShip.is_ship()` 分支里；无头 `play()` 不报错 |

另：保持 W0 的 `W0_table_3days`（真的牌桌 + Mock 情景 + 例子集 3 步）全绿。

- **截图**（不进清单，§7.10.9、§12.3）：`scripts/tests/cards/C16/shot_guide.gd`——xvfb 下用 `guide_d1`–`guide_d3` 夹具走一遍，**每一步一张 1280×720 画面截图**（1.3：看得见教的人站在柜台一侧或批注纸、锚点发光、气泡），文件名 `<步骤 id>.png`（例 `gd.d1.deal.png`），外加一张拼图 `guide_d1_3_sheet.png`；`shot_shell.gd`——标题、暂停、设置（1.3：设置抽屉）各一张。上传 PR，或提交到 `scripts/tests/cards/C16/shots/`（放 `.gdignore`，≤ 4 MB）。
- **W2 加**：`--steps=k16` 的清单行（见上）；配合 K14 的 `test_guide_d1_3.gd`（真引擎、种子 7、新存档、`--guide=on`，`shown_log` 等于 `_test.d1_3`；同一串指令关着指引再走一遍，状态哈希相同）把发现的问题修掉。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C16 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C16/shot_guide.gd -- --out=/tmp/shots/C16
  ```
- **视觉规格**：一次只亮一处；外框发光 `guide_glow`（不改被高亮部件本身）；气泡 `frame.guide_bubble` / `guide_bubble` 底、`guide_ink` 字、正文 16 号、最宽 360（`bubble_max_w`）；~~教的人头像在左下角（48×64 ×2，NEAREST），台词在头像右边一行~~（10-13 作废，合同 1.3：人物站在 `GUIDE_TEACHER`（48×64 ×4，NEAREST），话在 `GUIDE_SAY`；对话框或叠层开着时只放 64×64 头像 + 那句话；物件用批注纸）；渐显 300 ms、渐隐 700 ms、快速 250 ms（读 `guide.json`）；标题用 `font_title()`。

## 交付

- PR 标题 `[C16] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①指引引擎补全（interrupt、渐隐、气泡、教的人、性能索引）+ `test_guide_rules` / `test_guide_switch` / `test_guide_overlay`（**尽早合**）；②第 1–3 天夹具与 `test_guide_d1_3` + 逐步截图；③标题、暂停、设置、曲目 + 测试；④（W2）K16 数据复测、配合 K14。
- PR 描述按模板填全：改动路径；自查打勾；最后 20 行；**第 1–3 天每一步的截图（拼图 + 单张）**；JevRng 域（无）；登记的锚点、发的 `ui_event`；新公开接口（`set_cmdline` 保留、`fast_anim()`、`bind(bus)`、组名、`music.json` 格式）；需要主创/编排决定的事（§7.10.10 的七处冲突 a–g 按默认做了哪些、`close_requested` 约定依赖 C01）；性能数（挑一步 ≤ 1 ms）；“回报”。

## 审核（Claude 重点）

- 八条做法逐条对（§7.10.7）：开关优先级、记事、挑步骤、自动完成、亮、结束、不挡、性能。
- 关着指引：不亮、不发 `ui.guide`；覆盖层没有任何输入处理、全部鼠标穿透；只发 `ui.guide` 一种指令。
- 第 1–3 天顺序测试绿、每一步有截图；`W0_table_3days` 仍绿。
- 设置只写四个旧键 + 自己的 `user://cards/settings.json`；旧曲目只在 `!is_ship()` 下引用。
- 没有拷旧 `onboarding.json` / `guide.gd` / `pause_menu.gd` 的文字；没有中文/颜色字面量。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 第 1–3 天逐步截图 | |
| 登记的锚点 / 发的 ui_event | |
| 新加或保留的公开接口 | |
| 性能实测（挑一步、空闲帧） | |
| 七处冲突（a–g）的处理 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
