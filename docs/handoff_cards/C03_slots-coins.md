# C03 `slots-coins` · 柜台上的格子与铜钱、选项与检定的演出、消息/当票的演出、人脉抽屉、人脉满、留牌满

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C03 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C03: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 3**（在第 3 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C03`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。`CardSlotWidget` 和 `CardCoinTossView` 的公开接口已冻结在 W0 桩里；C05（条子）、C06（轮盘的香案）、C11（牢房）复用它们，所以**W1 里要早合**（先合 SlotWidget + CoinToss 的正式版，再合面板）。1.3：`CardCounterChecks` 跟 SlotWidget + CoinToss 一起早合（10-21）；SlotPanel 的演出用 C04 的对话框 `CardDialogBox` 和 W0 的 `CardStagePanel` / `CardStageScript`，开发时对着 W0 的桩，合并等 C04 的对话框 PR。
- **波次（Wave）**：W1 开发并合入（C01–C04 是 W1 完成条件）；W2 补对真引擎（G03 的格子与铜钱、G01 的 `card.discard`）的集成测试和 K16 步骤复测。

## 分支

`cards/C03-slots-coins`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

打开一张“有格子或有选项”的牌时的~~大牌面板：大图、正文、选项、格子，“N 枚铜钱，要 M 个正面”~~（10-13 作废，合同 1.3：改成在画面里演——话在对话框里说，选项是回话，格子出现在柜台上，“掷铜钱 · N 枚 · 要 M 个正面”是一句回话，见下方“10-13 变更二”），掷 → 铜钱动画 → 结果正文。格子能放五种来源（人、钱、留着的牌、物品、消息），放不放得进由引擎判。另做三个小面板：消息/当票的只读样式（`read`）、人脉满了选一个让出来（`contacts_full`）、留牌满了扔一张（`kept_full`）。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.4（放格子、掷铜钱）、§三.5（留着的牌）、§三.10（人脉）、§九.3（金色牌走选项面板）。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2、§3.3 开头与 C03、§4.4.1–§4.4.3（Slot、Check、Choice）、§4.5（正文字段 `title` `body` `choices.<id>` `slots.<id>` `outcomes.success/fail`）、§7.4（`card.choose` `slot.place` `slot.remove` `slot.roll` `card.read` `card.keep` `card.discard` `contact.release` `mg.request` 与 `source` 格式）、§7.4.2（留牌满了）、§7.4.3（来意与面板）、§7.5（CardView、SlotView、Action）、§7.6（`coins_tossed`）、§7.8（面板表 `slots` `read` `contacts_full` `kept_full`；控件表 SlotWidget、CoinToss）、§7.10、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/slots/{slot_panel,slot_widget,coin_toss,contacts_full,kept_full}.gd` 与 `scenes/cards/slots/*.tscn`（W0 桩）、`scripts/cards/ui/common/{card_panel,w0_stub}.gd`（桩的自动一步怎么走）、`scripts/cards/mock/mock_scenario.gd`（`_slot_views` `_preview` `_choose` `_place` `_roll`）、`scripts/cards/mock/fixtures/{day_full,street_prison}.json`、`scripts/tests/cards/W0/test_table_3days.gd`（第 3 天的查良民证靠 SlotPanel 的自动一步走过去）。

## 要做的事

- [ ] **CardSlotPanel**（`slot_panel.gd`，`class_name CardSlotPanel`，场景 `SlotPanel.tscn`，面板 kind `slots` 与 `read`）（10-13 作废，合同 1.3：居中大牌的画法作废，改成 `extends CardStagePanel` 的演出——下面这些“和引擎说话”的做法照旧，画在哪、怎么画以下方“10-13 变更二”为准）：
  - `open({uid})`：`query("card", {uid})` 取详细 CardView；~~左边大图（小插图 64×48 ×4 或头像 48×64 ×4，NEAREST）、牌名、正文 `CardText.card(def, "body")`~~（1.3：`begin_play(uid)`，人上场、正文在对话框里说）；人物牌（`help` `ask` `story`，含金色牌）照样走这里。
  - 选项：`choices`（`{id, enabled, reason_key, has_check}`）~~一行按钮~~（1.3：每个选项一句回话），文字 `CardText.card(def, "choices." + id)`；`enabled: false` 灰掉并显示 `reason_key` 的正文；点 → `send("card.choose", {uid, choice})`，返回 `needs_slots: true` 时刷出这个选项的格子。
  - 格子：`query("slots", {uid})` → `{slots:[SlotView], coins, auto_heads, need, auto_pass, ready}`；每个 SlotView 一个 `CardSlotWidget`；格子名 `CardText.card(def, "slots." + id)`；~~“N 枚铜钱，要 M 个正面”一行（本任务的键 `c03.coins.line`，参数 `{n}` `{m}`；数字可以显示，§0 红线 3）~~（10-13 作废，合同 1.3：改成回话“掷铜钱” `c03.reply.roll`（`{n}` `{m}`）和柜台上铜钱那一排）；`auto_pass` 时改成“直接过”的键；`required` 没放时掷~~按钮~~（回话）灰。
  - 放东西：拖拽（CardWidget 的 `{"kind": "card", "uid", "zone"}`：`zone` 是 `kept` → `{"kind": "kept", "uid"}`、`contacts` → `contact`、`self` → `{"kind": "self"}`、手牌里的消息 → `news`）；以及~~面板里的~~**选择器**（不拖也能放；1.3：点柜台上的空格子弹出的小框，是 `CardCounterChecks` 里的，不是面板 kind）：你自己（`view.self`，`used_today` 时灰）、人脉列表（`view.contacts`，`used_today`/`away_days` 时灰）、留着的牌、货架物品（`query("stock")`，Mock 返回 `{"items": [ItemView]}`）、钱（~~**CardMoneyPicker**：`scripts/cards/ui/slots/money_picker.gd`，`preload`，不写 `class_name`；拖钱或加减数目~~（10-13 作废，合同 1.3：`CardMoneyPicker` 并进 `CardCounterChecks`，收钱的格子上一对 −/＋））。都发 `send("slot.place", {uid, slot, source})`，`source` 照 §7.4 的格式；拿出来 `send("slot.remove", {uid, slot, index})`。引擎拒绝（`ok: false`）时显示 `reason_key` 的正文；没有 `reason_key` 用本任务的 `c03.err.<错误码>`。
  - 掷：`send("slot.roll", {uid})` → `{faces, heads, need, success}` → `CardCoinTossView.play(faces, need)` → 结束后显示 `CardText.card(def, "outcomes.success" / "outcomes.fail")`，“继续”关面板（1.3：在柜台上播 `checks.play_coins`，结果句在对话框里说，牌走了收场）。
  - `read` 模式（`args.mode == "read"`，消息牌、当票）：~~只有图、正文、“看过了”~~（1.3：正文在对话框里说，“看过了”“留着”“细看”都是回话）→ `send("card.read", {uid})`；带 `minigame` 的（当票、电报、信）多一个“细看”按钮 → `send("mg.request", {uid, "item": ""})`（C01 的宿主开小游戏）；能留的显示“留着” → `send("card.keep", {uid})`。
  - 任何 uid 都不许报错：`W0_skeleton` 会用 `day_full` 夹具对每个面板 `open({"uid": "c0002"})`。
- [ ] **CardSlotWidget**（`slot_widget.gd`，冻结：`signal place_requested(slot_id, source)`、`signal remove_requested(slot_id, index)`、`set_slot(card_uid, slot_view)`、`var bus`）：显示 `wants`（格子的性质，本任务的键 `c03.wants.<tag>`）、已放的每样东西（小图 + 这样给几枚铜钱 `coins`、直接算的正面 `heads`、`auto_pass` 标记）和合计；每样一个“拿出来”；接受拖拽 `{"kind": "card"…}`、`{"kind": "money", "amount": n}`，以及本任务的选择器发来的 `{"kind": "item", "item": "I004"}`、`{"kind": "self"}`（这两种拖拽格式合同没写，PR 里列出）；**`slot_view` 里没有 `coins` 键时不显示铜钱数**（C06 的香案复用时用）；放下时自己发 `ui_event slot_drop {uid, slot, kind}`（复用它的 C05/C06/C11 因此也会发）。
- [ ] **CardCoinTossView**（`coin_toss.gd`，冻结：`signal finished`、`play(faces, need)`、`skip()`）：每枚铜钱 Tween 翻面（单段 ≤ 0.6 秒，可以错开）；最后正反和 `faces` 一模一样；显示正面数和要几个（数字）；Space 或 `skip()` 立刻显示最终结果；`finished` 每次 `play` 只发一次。“快动画”：~~读开关的接口没冻结（见 PROMPT 末尾缺口），先开 `[shared]` issue，留 `fast_anim` 布尔、标 `# TODO(shared#<issue号>)`~~ 1.3：用冻结的静态读取 `CardSettings.fast_anim()`（合同 §7.8）。
- [ ] **CardContactsFull**（`contacts_full.gd`，kind `contacts_full`）：列出现有人脉（`view.contacts`）和新来的那位（`args` 里给的；合同没写参数名，先认 `args.new_uid`，没有就看 `view.pending` 里 `type == "contact"` 的，PR 里列出），选一个让出来 → `send("contact.release", {uid})`；**关面板（按钮、Esc、宿主关）= 新来的那个不留**：覆盖 `dismiss()` 发 `contact.release {uid: new_uid}`（10-13：没有关不掉的面板，合同 §7.8）。
- [ ] **CardKeptFull**（`kept_full.gd`，kind `kept_full`，`args.new_uid`）：五张留着的牌 + 新来的那张（CardWidget 小牌），选一张扔 → `send("card.discard", {uid})`；**关面板（按钮、Esc、宿主关）= 扔掉新来的那张**，同样发 `card.discard {uid: new_uid}`；每次打开恰好发一次 `card.discard`（被宿主直接释放时在 `_exit_tree` 里用 `call_deferred` 补发）。
- [ ] **autoplay_step()**（每个面板，和玩家走同一条代码路径，同一状态永远做同样的事）：SlotPanel——选第一个 `enabled` 的选项 → 有收 `self` 的格子放你自己、收钱的放 20 → 掷 → 关；`read` → `card.read` → 关；ContactsFull → 让出第一个；KeptFull → 扔新来的那张。保持 W0 的 `W0_table_3days` 能走过第 3 天的格子事件。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C03.json`（`c03.` 开头，键 + `brief`，`_meta._provenance`）：`c03.coins.line`（`{n}` `{m}`）`c03.coins.auto_pass` `c03.btn.roll` `c03.btn.continue` `c03.btn.read` `c03.btn.look`（细看）`c03.btn.keep` `c03.btn.remove` `c03.wants.<tag>` `c03.err.<code>` `c03.contacts_full.title` `c03.kept_full.title` `c03.picker.*`。
- [ ] **夹具**（`scripts/tests/cards/C03/fixtures/`，`_meta.owner = "C03"`）：`event_slots.json`（查良民证：证件/钱/胆大的人三格）、`fate_choices.json`（邻铺失火：三个选项，第一个带检定格子）、`gold_story.json`（哥哥告别：两个选项）、`slot_reject.json`（`slot.place` 返回 `ok: false, err: "slot_reject", reason_key`）、`read_news.json`、`read_ticket.json`（`tk.1938.de196`，带 `minigame`）、`contacts_full.json`、`kept_full.json`、`roll_fail.json`。夹具过 `t.no_leaks()`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **每个面板都能关**：SlotPanel / `read` 关掉只是回牌桌（格子里放的东西留着；打烊时引擎会把没掷的东西还回来）；KeptFull 关 = 扔掉新来的那张（照旧）；ContactsFull 关 = 新来的那个不留（`contact.release {uid: new_uid}`，引擎 `request_panel("contacts_full", {new_uid})` 给参数）。两个“满了”面板都覆盖 `dismiss()`（W0 的桩已经这样做，照着换成真实现）。
- [ ] 打烊时没选也不卡：引擎在 `day_end` 里按同样的默认结算（合同 §7.4.7 的表：`discard` `release` 两行），所以面板不用拦人。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardSlotPanel 改成演出**（`extends CardStagePanel`，kind `slots` 与 `read`，§7.11.4）：`open({uid})` → `begin_play(uid)`；话说完列回话：每个选项一句（`style: "choice"`，`ref` = `<def>#choices.<id>`，`enabled`/`reason_ref` 照 `query("card").choices`，第一句带 `anchor: "a.slots.choices"`）+ “回头再说”（`style: "later"`，`c03.reply.later`，= `dismiss()`）；选了 → `card.choose` → `needs_slots` 时 `checks.show_checks(uid)`、`hand.set_low(true)`、`stage.set_dim_tools(true)`、`dialog.set_max_bottom(404)`，回话换成“掷铜钱”（`style: "roll"`，`c03.reply.roll`，参数 `{n}` 枚、`{m}` 个正面，`anchor: "a.slots.roll"`；`required` 没放时 `enabled: false`）；`checks.changed` 后刷新这句；掷 → `slot.roll` → `checks.play_coins(faces, need)` → `coins_finished` 后说一句 sys（`c03.sys.roll`，`{heads}` `{need}`）→ `CardStageScript.lines(script, "success"/"fail")`；没有检定的选项直接接 `after.<选项 id>`；牌走了（`card_left`）收场。`read` 模式：回话“看过了”（`c03.reply.read` → `card.read`）、能留的“留着”（`c03.reply.keep` → `card.keep`）、带 `minigame` 的“细看”（`style: "look"`，`c03.reply.look` → `mg.request {uid, item: ""}`）。
- [ ] **CardCounterChecks**（新：`scenes/cards/slots/CounterChecks.tscn` + `scripts/cards/ui/slots/counter_checks.gd`，`class_name CardCounterChecks extends CardChecksApi`）：§7.11.7 全部——按 `CardLayout.slot_rect(i, n)` 摆 `CardSlotWidget`（160×120）；收钱的格子里一对 −/＋（`c03.money.minus` `c03.money.plus`，每次一份 `money_per_coin`）；点空格子弹一个小选择器（不拖也能放：你自己、人脉、留着的牌、货架物品、消息，`query("stock")`），选择器是本控件里的小框，不是面板 kind；铜钱那一排按 `coin_rect`；锚点 `a.slots.first` `a.slots.coins` `a.slots.money`。`CardMoneyPicker` 并进这里。
- [ ] **CardContactsDrawer**（新：`scenes/cards/slots/ContactsDrawer.tscn` + `scripts/cards/ui/slots/contacts_drawer.gd`，`class_name CardContactsDrawer`，kind `contacts`，左抽屉）：你、人脉、留着的牌各一行（图、名字、四项属性点数或留着的牌的用处 `<def>#use`、状态：今天用过了 / 不在 n 天 / 剩 n 天）；每行能拖出去放格子（数据同头像、人脉、CardWidget）；只读，不发指令。
- [ ] `CardSlotWidget`、`CardCoinTossView` 冻结接口不变，样子改成柜台上的尺寸（格子 160×120，铜钱 48×48）；`CardContactsFull`、`CardKeptFull` 仍是叠层，不变。
- [ ] `autoplay_step()`：对话框没说完先 `dialog.skip()`；然后照 1.2 的顺序（第一个能选的选项 → 放你自己 / 钱 20 → 掷 → 收场），都走 `on_reply`。

**新增 / 作废的交付**

- 新增 `CounterChecks` `ContactsDrawer` 两个场景与脚本；界面键 `c03.reply.later` `c03.reply.roll`（`{n}` `{m}`）`c03.reply.read` `c03.reply.keep` `c03.reply.look` `c03.sys.roll`（`{heads}` `{need}`）`c03.money.minus` `c03.money.plus` `c03.drawer.title` `c03.state.used` `c03.state.away`（`{n}`）`c03.state.days`（`{n}`）；夹具照旧（`event_slots` `fate_choices` `gold_story` `roll_fail` 用画面根跑）+ `stage_police.json`（查良民证带演出块：两个巡警站门口）。
- **作废**：SlotPanel 的居中大牌布局、“N 枚铜钱，要 M 个正面”那一行放在面板里的做法（改成回话和铜钱那一排）、`money_picker.gd` 作为独立面板。

**锚点、界面事件、要证明的步骤**

- 锚点不改名；位置变了：`a.slots.first` `a.slots.coins` `a.slots.money` 在柜台上，`a.slots.roll` `a.slots.choices` 是回话上的锚点（经 Reply 的 `anchor`），`a.slots.release` `a.slots.discard` 在叠层里。
- 界面事件 `slot_drop` 不变。
- 要证明的步骤不变（`gd.slots` `gd.coins` `gd.choice` `gd.contacts_full` `gd.kept_full`）。

**测试与截图**

- `C03_slot_panel` 改成用画面根 + 夹具打出那张牌：`panel_opened {kind: "slots", show: "stage"}`、对话框的句子来自 `CardStageScript.lines`（演出块的覆盖默认）、选项回话 → `mock.sent` 有 `card.choose`、格子出现在 `CardLayout.slot_rect`、掷 → `slot.roll`、结果句。
- `C03_sources` 加拖头像（`{"kind": "self"}`）、拖人脉小牌、拖扇里留着的牌；`C03_coin_toss` 在柜台上播；`C03_full_panels` 不变；**新增** `C03_contacts_drawer|res://scripts/tests/cards/C03/test_contacts_drawer.gd|120|`。
- 截图：选项回话列出、柜台上 1/2/3 个格子（放了人、钱、留着的牌）、铜钱翻到一半、结果句、`read`（消息、当票带“细看”）、人脉抽屉、人脉满、留牌满各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- `CardSlotWidget`（拖放、显示放了什么、拿出来、`slot_drop`）、`CardCoinTossView`（和 `faces` 一致、可跳过）、放钱的逻辑、`ContactsFull`/`KeptFull`、每个面板的自动一步与“算了”、全部夹具和对 `mock.sent` 的断言都有效；要换的是 SlotPanel 的画法（居中面板 → 演出 + 回话 + 柜台格子）。

**日期**：`CounterChecks` 与控件 PR 合并目标 **10-21**；演出（`slots` `read`）在 C04 的对话框合入后，目标 **10-29**。

## 只能改这些文件

- `scenes/cards/slots/**`、`scripts/cards/ui/slots/**`
- 默认拥有：`scripts/tests/cards/C03/**`、`scripts/tests/cards/suites/C03.txt`、`data/cards/tags/C03.json`、`data/cards/ui_keys/C03.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、别的任务的场景和脚本、旧代码）。
2. **不写最终内容**：不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII，`.tscn` 不出现中文；新键只写键 + `brief`。
3. 不写颜色字面量；颜色、框只用 `CardTheme`；图只用 `CardArt`。
4. 不露隐藏数值：不显示成功的机会、百分比、权重；只显示铜钱数、要几个正面、每样给几枚（引擎给的）。
5. **不放规则**：不自己算铜钱、不自己判能不能放、不自己判成败——全看 `slot.place` / `query("slots")` / `slot.roll` 的结果；动画的正反只照引擎给的 `faces`。
6. 不用随机影响结果（铜钱翻转的圈数这类装饰可以用固定种子的 `RandomNumberGenerator`）；不加冻结表以外的 `class_name`（`CardMoneyPicker` 不写；1.3 加的 `CardCounterChecks` `CardContactsDrawer` 在冻结表里）；不加 autoload/InputMap。
7. 不发 `first_time`；只发 `slot_drop`。

## 接口

**用到**：指令 `card.choose {uid, choice}` → `{needs_slots}`、`slot.place {uid, slot, source}` → `{coins}`、`slot.remove {uid, slot, index}`、`slot.roll {uid}` → `{faces, heads, need, success}`、`card.read {uid}`、`card.keep {uid}`、`card.discard {uid}`、`contact.release {uid}`、`mg.request {uid, item: ""}`；查询 `card {uid}`（`choices`、`slots`）、`slots {uid}`、`stock`；视图 `self` `contacts` `kept` `pending`；总线 `view_changed` `coins_tossed`（别处触发的掷币也可以播）`card_left`（这张牌被处理完时关面板）；`CardText.card/ui/t/obs`、`CardArt`、`CardTheme`、`CardAnchors`；1.3：`CardStagePanel` `CardStageScript`（W0）、`CardDialogApi`（C04 的对话框，没合入时用 W0 的桩）、`CardHandApi.set_low`、`CardStageApi.set_dim_tools`、`CardChecksApi`（你来实现）、`CardLayout.slot_rect/coin_rect`。

**提供（冻结）**：面板 `CardSlotPanel`（`slots`、`read`；1.3 起 `extends CardStagePanel`）、`CardContactsFull`、`CardKeptFull`（`CardPanel` 接口）；控件 `CardSlotWidget`、`CardCoinTossView`（§7.8）；1.3：`CardCounterChecks`（`CardChecksApi` 的全部接口）、`CardContactsDrawer`（kind `contacts`）。新增（PR 列出）：`dismiss()` 覆盖（ContactsFull、KeptFull）、拖拽来源 `{"kind": "item"}` / `{"kind": "self"}`、`slot_view` 没有 `coins` 时不显示铜钱。

## 新手指引

- **必须登记的锚点**（名字不变，1.3 位置变了）：`a.slots.first`（柜台上第一个格子）`a.slots.coins`（~~“N 枚铜钱，要 M 个正面”那一行~~ 柜台上铜钱那一排）`a.slots.roll`（~~掷按钮~~ “掷铜钱”那句回话）`a.slots.money`（~~放钱的选择器~~ 第一个收钱格子的 −/＋）`a.slots.choices`（~~选项那一行~~ 第一句选项回话）`a.slots.release`（人脉满面板的列表）`a.slots.discard`（留牌满面板的列表）。
- **必须发的 ui_event**：`slot_drop {uid, slot, kind}`（SlotWidget 自己发）。
- **first-time**：不发；依赖 `slots` `coins` `choice` `contacts_full` `kept_full`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.slots`（`a.slots.first`，备用 `a.card@{uid}`）、`gd.coins`（`a.slots.coins`）、`gd.choice`（`a.slots.choices`）、`gd.contacts_full`（`a.slots.release`）、`gd.kept_full`（`a.slots.discard`）。
- **测试做法**：用自己的夹具开面板（或牌桌宿主 `CardGame.tscn` + `boot({"bus", "fixture": "<本目录夹具路径>", "skip_title": true})`），挂 `GuideOverlay.tscn`（`bind(mock, bus)` → `force(true)` → `skip_fades = true` → `load_steps(<本目录 guide_steps.json>)`），`bus.first_time.emit(&"slots", {"uid": …})` → `evaluate_now()` → `active_step() == "gd.slots"`；做 `done_when` 的动作（例如放一样东西触发 `ui:slot_drop`）后完成。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C03.txt`：

```
# C03 格子与铜钱（docs/handoff_cards/C03_slots-coins.md）
C03_slot_panel|res://scripts/tests/cards/C03/test_slot_panel.gd|180|
C03_sources|res://scripts/tests/cards/C03/test_sources.gd|120|
C03_coin_toss|res://scripts/tests/cards/C03/test_coin_toss.gd|120|
C03_full_panels|res://scripts/tests/cards/C03/test_full_panels.gd|120|
C03_read|res://scripts/tests/cards/C03/test_read.gd|120|
C03_guide|res://scripts/tests/cards/C03/test_guide.gd|180|
C03_contacts_drawer|res://scripts/tests/cards/C03/test_contacts_drawer.gd|120|
```

（最后一行是 1.3 新增；`C03_slot_panel` `C03_sources` `C03_coin_toss` 的 1.3 通过条件见上方“10-13 变更二”的“测试与截图”。）

| 测试 | 通过条件 |
|---|---|
| `test_slot_panel.gd` | 三种牌（事件、命运带选项、金色人物带选项）都能开；选项 → `mock.sent` 里 `card.choose {uid, choice}` 参数对；`needs_slots` 后出格子；~~“N 枚铜钱”一行~~（1.3：“掷铜钱”那句回话的 `{n}` `{m}`）的数等于 `query("slots")` 的 `coins`/`need`；`slot_reject` 夹具显示 `reason_key` 的正文；`autoplay_step()` 能把三种牌都走完 |
| `test_sources.gd` | 人、钱、留着的牌、物品、消息五种来源（拖拽和选择器各走一次）发出的 `slot.place` 的 `source` 都照 §7.4 格式；拿出来发 `slot.remove {uid, slot, index}`；每次放下都有 `slot_drop` ui_event；`slot_view` 没有 `coins` 时不显示铜钱 |
| `test_coin_toss.gd` | `play(faces, need)` 后读铜钱节点的正反，和 `faces` 完全一致；`skip()` 后结果不变；`finished` 恰好一次；面板里掷完显示的结果正文和 `success` 对应（1.3：在柜台上铜钱那一排播，结果句在对话框里） |
| `test_full_panels.gd` | KeptFull：选一张已留的 → `card.discard {uid: 那张}`；按关闭/Esc/宿主关 → `card.discard {uid: new_uid}`；每次打开恰好一次；ContactsFull → `contact.release {uid}`；关掉 / Esc → `contact.release {uid: new_uid}` |
| `test_read.gd` | 消息 → `card.read`；当票的“细看” → `mg.request {uid, item: ""}`；能留的显示“留着”并发 `card.keep` |
| `test_guide.gd` | 五个步骤按做法亮、完成后 `mock.sent` 有 `ui.guide {status: "done"}`；锚点都 `t.anchor_ok()` |

所有测试另查：`t.all_text_from_cardtext(panel)` 为空；没有 `%`；夹具过 `t.no_leaks()`。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：发出查良民证 → 开面板 → `autoplay_step()` 走完，`coins_tossed` 的正反和动画一致）；清单加一行 `C03_guide_k16|res://scripts/tests/cards/C03/test_guide.gd|180|--steps=k16 --name=C03_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C03 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C03/shot_slots.gd -- --out=/tmp/shots/C03
  ```
- **截图**（不进清单）：~~每个夹具一张（`C03_<夹具>.png`），掷铜钱动画中间一张、结束一张，`read` 模式两张~~（10-13 作废，合同 1.3：清单见上方“10-13 变更二”的“测试与截图”）；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图；上传 PR 或提交到 `scripts/tests/cards/C03/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：~~面板居中、≤ 1100×640；大图整数倍（×4）~~（10-13 作废，合同 1.3：`slots` `read` 是演出，格子 160×120、铜钱 48×48 摆在柜台上，坐标用 `CardLayout`；`contacts_full` `kept_full` 仍是叠层，居中 ≤ 1100×640）；铜钱图用 `CardArt`（`icon.coin.head` / `icon.coin.tail` 这类 id，清单里没有就开 `[content]` issue，先用配色画圆）；正文 16–18 号、面板标题 28–36 号；键盘：Tab 选按钮、Enter 确认、Space 跳过动画/继续、Esc 关（= 面板的“算了”，`dismiss()`）。

## 交付

- PR 标题 `[C03] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①SlotWidget + CoinToss 正式版 + 测试（尽早合，C05/C06/C11 在等；1.3：`CounterChecks` 并进这个 PR，10-21 合）；②SlotPanel、read、两个满了的面板、截图（1.3：SlotPanel 的演出与 `ContactsDrawer`，等 C04 的对话框合入，10-29）；③（W2）真引擎 + K16 复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、`slot_drop`、依赖的 first-time；新公开函数与新拖拽格式；需要决定的事（`contacts_full` 的参数名、拖拽格式）；性能数（打开面板 ≤ 50 ms）；“回报”。

## 审核（Claude 重点）

- 动画结果和引擎 `faces` 一致；跳过不丢结果；界面不算规则。
- 五种来源的 `source` 格式；引擎拒绝时有正文；`slot_drop` 总是发。
- `kept_full` 的两种结束方式都恰好发一次 `card.discard`。
- `W0_table_3days` 仍绿；面板对任意 uid 不报错；没有中文/颜色字面量和 `%`。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / 发的 ui_event / 证明会亮的步骤 | |
| 新加的公开函数、拖拽格式 | |
| 性能实测 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
