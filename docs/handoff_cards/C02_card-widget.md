# C02 `card-widget` · 牌、牌框、金色牌、留牌标记、放大、拖拽、美术解析、手牌扇、英雄头像与人脉小牌

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C02 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C02: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 2**（在第 2 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C02`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。不依赖别的线；牌桌（C01）、格子（C03）、条子板（C05）、夜牌（C08）、档案簿（C10）、家当（C11）都用你的控件，所以**W1 里要早合**（先小 PR：接口不变的正式外观 + 锚点；再补放大、拖拽、草稿样式）。1.3：手牌扇 `CardHandFan` 与英雄头像 `CardHeroBar` 也是你的，并进控件 PR（10-21）；C01 的画面根、C08 的夜牌都用它们，没合入时别人用 W0 的桩（`scenes/cards/_w0/`）。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎的集成测试（G02 的 `CardView`）和 K16 步骤复测。

## 分支

`cards/C02-card-widget`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交，先确认 `scripts/cards/api/card_ids.gd` 存在）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

一张牌的全部样子：所有牌种的正面（和背面）、按类型的牌框、**金色牌框 + 微光**（一眼能认）、今天要了断（`must_resolve`）的小红点、留着的牌右上角剩几天、“这人今天用过了”的灰态、~~悬停放大到 288×400~~（10-13 作废，合同 1.3：手牌扇里悬停是抬起，选中才放大到 288×400，由扇做）、拖拽源、草稿正文的草稿样式；以及美术解析 `CardArt`（美术 id → 正式图 → 占位图 → 缺图方块）。三种尺寸都按整数倍像素显示。

## 必读

1. `docs/cards/DESIGN_cards.md` §二（牌的种类）、§三.5（留着的牌）、§九.3（金色角色牌）、§七“美术”。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2（牌的尺寸 144×200 / 288×400 / 72×100、底图尺寸、整数倍、字体）、§2.4（牌框配色键 `frame_*`、`gold` `gold_glow`）、§3.3 开头与 C02、§4.8（美术清单、美术 id 类别、`legacy`、`missing`）、§7.5（CardView 字段：`expires_in` 与 `days_left` 的区别、`actions`、`used_today`、`away_days`）、§7.8（CardWidget 与 CardArt 的冻结接口、拖拽数据格式）、§7.10.4 / §7.10.5、§10、§11.2、§12.1–§12.4、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/card/{card_widget,card_art}.gd`、`scenes/cards/card/CardWidget.tscn`、`scripts/cards/ui/common/{card_theme,card_anchors}.gd`、`data/cards/art/manifest.json`、`scripts/cards/mock/mock_scenario.gd`（`card_view()` 怎么拼 CardView）、`scripts/cards/mock/fixtures/day_full.json`、`scripts/tests/cards/W0/shot_table.gd`。

## 要做的事

- [ ] **CardWidget**（`card_widget.gd`，`class_name CardWidget`，冻结接口一个不改：`signal pressed(uid)`、`signal action_requested(uid, action_id)`、`set_card(card_view)`、`set_size_mode(mode)`、`set_highlight(on)`、`get_uid()`、`var bus`）：
  - 牌框：有正式牌框图 `frame.<type>`（金色 `frame.gold`）时用 `NinePatchRect`，边距读清单的 `nine`，底图 36×50 → 手牌 ×4（144×200）、放大 ×8（288×400）、小牌 ×2（72×100）；没有正式图（开发版也可用 K12 的占位图）就用 `CardTheme.frame_style(type, gold)`。
  - 插图：头像 48×64、小插图 64×48、物品 64×64，手牌 ×2、放大 ×4、小牌 ×1；`TEXTURE_FILTER_NEAREST`；节点尺寸 = 底图 × 整数 k，**不许非整数拉伸**（W0 桩用 `EXPAND_IGNORE_SIZE` + 夹尺寸，会出非整数倍，要改掉）。底图尺寸用 `CardArt.base_size()`，查不到按类型给默认（人物/你自己/人脉 48×64，其余 64×48）。
  - 文字：牌名 `CardText.card(def, "title")`（人物牌可配名字 `CardText.person_name(person)`）；来意、类型等小字用本任务的界面键 `c02.intent.<intent>`、`c02.type.<type>`；**草稿样式**：`CardText.is_draft(def + "#title")` 为真时用 `ink_soft` 色 + 斜体（`FontVariation` 的 `variation_transform` 做倾斜，字体子集没有斜体）。
  - 标记：今天要了断的小红点（`must_resolve` 且 `zone == "hand"`，配色 `seal`；不挡打烊，§7.4.7）；**剩几天角标**：`expires_in >= 0` 显示数字（留着的牌、能留的消息）；生活牌（`type == "life"`）在手上时用 `days_left` 显示“几天内处理”的角标（牢房牌 `type == "prison"` 同样用 `days_left`：还能在牢里待几晚，§7.4.7）（样式和 `expires_in` 的不同，见缺口说明）；人脉 `away_days > 0` 显示天数；`used_today` 为真时整张灰（`modulate` 只用 `Color(1, 1, 1, a)` 或配色键）。
  - **金色牌**：`gold: true` → 金框 + 微光（`gold_glow`，Tween 循环呼吸，单段 ≤ 0.6 秒），没有“留着”按钮。“快动画”时改成静态光——~~但读“快动画”开关的接口合同里还没冻结（C16 存在 `user://cards/settings.json`，见 PROMPT 末尾的缺口）：先开 `[shared]` issue，代码里把动画时长集中成常量、留一个 `fast_anim` 布尔，标 `# TODO(shared#<issue号>)`~~（1.3：读开关用冻结的静态读取 `CardSettings.fast_anim()`，合同 §7.8；动画时长照样集中成常量）。
  - 动作：`actions` 里 `keep` 且 `enabled` 时显示“留着”小按钮 → `action_requested(uid, "keep")`；`enabled: false` 时不显示（原因不在牌上讲）。其他动作由面板处理。
  - ~~**悬停放大**：手牌尺寸时鼠标停留 → 在牌上方显示一份 288×400 的放大副本（`top_level`，整块夹在 1280×720 里，不挡鼠标），发 `ui_event card_zoomed {uid}`；移开收起。小牌也可以放大到手牌尺寸（可选）。~~（10-13 作废，合同 1.3：手牌扇里悬停是抬起；选中才放大，由扇在 `PREVIEW_CARD` 摆一张 `&"zoom"` 并发 `card_zoomed`，见下方“10-13 变更二”）
  - **拖拽源**：`_get_drag_data` 返回 `{"kind": "card", "uid": uid, "zone": zone}`（`zone` 照 CardView；~~C01 给你自己那张传 `zone: "self"`~~——1.3：你自己是英雄头像，拖出去是 `{"kind": "self"}`，由 `CardHeroBar` 发）+ 一个小牌预览；发 `ui_event card_drag_started {uid, zone}`。
  - 背面：加公开函数 `set_back(on: bool)`（牌背，用 `frame.<type>` 的背面或配色块；PR 里列为新公开函数），给发牌、牌堆用。
  - 不显示 `asking` 以外的任何价钱；不显示 `%`；牌的 `tags` 本来就不在视图里，别从别处拿。
- [ ] **锚点**：每次 `set_card()` 先注销旧的，再登记 `a.card@<uid>`（整张牌）、能留的登记 `a.card.keep@<uid>`（“留着”按钮）、有剩几天角标的登记 `a.card.days@<uid>`（角标）、金色牌登记 `a.card.gold@<uid>`（金框）；出树自动注销（`CardAnchors` 已处理）。
- [ ] **CardArt**（`card_art.gd`，`class_name CardArt`，冻结：`texture` `path` `is_placeholder` `base_size`）：读 `data/cards/art/manifest.json`；先 `human`（文件存在），**发行版只认 `human`**，开发版再 `placeholder`，再清单的 `missing`；`legacy: true` 的条目按占位对待（发行版不返回）；纹理缓存（只读缓存可以用 `static var`）；可加 `nine_margins(art_id) -> Array`（PR 里列出）。
- [ ] **界面键**：`data/cards/ui_keys/C02.json`（`c02.` 开头，键 + `brief`，`_meta` 带 `_provenance`），例：`c02.btn.keep` `c02.intent.<pawn|sell|buy|redeem|help|ask|story>` `c02.type.<type>` `c02.days.badge`（参数 `{n}`）。不再用 `w0.card.keep`。
- [ ] **夹具**（`scripts/tests/cards/C02/fixtures/`）：`all_examples.json`——例子集里每张会进手牌/各区的牌一张 CardView（person、金色 person、self、contact、event、fate、big_fate、demand、life、news、kept、estate、night、street、prison、pawn_ticket），由本目录的 `build_fixtures.gd` 用 `preload("res://scripts/cards/mock/mock_scenario.gd")` 生成（只调用，不改它）或手写；另有 `states.json`（同一张牌的：草稿/非草稿、`used_today`、`away_days`、`expires_in` 1 天、金色、必须处理、能留/不能留）。夹具过 `t.no_leaks()`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] 必须处理的小红点（`must_resolve`）的意思改了：**今天要有个了断**——打烊时还在手上就按“没理会”结算；它不再“挡住打烊”。小红点照画，样式不变。
- [ ] 牢房牌也显示 `days_left` 角标（还能在牢里待几晚）；手上能留的消息、信物从发到手上那天起就有 `expires_in`（以前只有留着以后才有），角标照 `expires_in` 画。
- [ ] C08 的打烊确认清单用你的 `CardWidget`（`&"mini"`）画每一行的牌；金色牌那一行要一眼认得出。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardHandFan**（新：`scenes/cards/card/HandFan.tscn` + `scripts/cards/ui/card/hand_fan.gd`，`class_name CardHandFan extends CardHandApi`）：§7.11.6 全部——白天排 `view.hand`（严格按引擎顺序）+ `view.kept`；夜里排 `night_offers` + “睡了”；扇形公式、悬停抬起到 380、`set_low` +56、`set_away`；点一下选中 → 预览（`CardWidget` `&"zoom"` 摆在 `PREVIEW_CARD`，旁边 `PREVIEW_BTNS`：“打出” `c02.btn.play`、能留的“留着” `c02.btn.keep`、“放回手里” `c02.btn.back`）并发 `card_zoomed`；拖出扇区 = 交给场景层的 `card_dropped`；`play_selected()` `play_uid()`；`card_played` + `hand_played {uid, def, how}`、`card_selected` + `hand_selected {uid}`。
- [ ] **CardHeroBar**（新：`scenes/cards/card/HeroBar.tscn` + `scripts/cards/ui/card/hero_bar.gd`，`class_name CardHeroBar extends CardHeroApi`）：英雄头像（`HERO`、`frame.hero`、`portrait.ruhua` 上半截 ×2、名字、四项属性点数、`used_today` 的戳 `c02.hero.used`）+ 人脉小牌（`CONTACT_MINIS`、`CardWidget` `&"mini"`、`away_days` 灰着显示天数）；拖出去的数据：头像 `{"kind": "self"}`（`card_drag_started {uid: <self uid>, zone: "self"}`）、人脉照 CardWidget；点了 `person_pressed(uid)`。
- [ ] **CardWidget**：1.2 的“悬停放大到 288×400 的副本”作废（手牌扇里悬停是抬起；选中才放大，由扇做）；其余照旧。夜牌和“睡了”的最小 CardView 由扇拼好再 `set_card`；牌面上给留着的牌画“留”角标（`c02.kept.badge`）。

**新增 / 作废的交付**

- 新增上面两个场景与脚本；界面键 `c02.btn.play` `c02.btn.back` `c02.night.none` `c02.hero.used` `c02.kept.badge`；夹具 `fan_15.json`（10 张手牌含金色 + 5 张留着的）`fan_night.json`（夜里三张夜牌，其中一张带 choices）`hero_states.json`（今天用过了、人脉一个不在三天）。
- **作废**：悬停放大副本。

**锚点、界面事件、要证明的步骤**

- 锚点 `a.hand` `a.hand.gold`（从 C01 接过来）`a.hand.kept` `a.hand.preview` `a.hero` `a.contacts`，加上原有的四个牌锚点。
- 界面事件 `hand_selected`（从 C01 接过来）`hand_played`（新）`card_zoomed` `card_drag_started`（`zone` 可以是 `self` `contacts`）。
- 要证明会亮的步骤：原有的 `gd.d1.person` `gd.d2.gold` `gd.d2.keep` `gd.kept_expire` `gd.life` `gd.news` `gd.fate` `gd.demand_people` `gd.big_wheel`，加上 `gd.d1.deal`（`a.hand`）、`gd.contact`（`a.contacts`）、`gd.kept_risk`（`a.hand.kept`）、`gd.person_state`（`a.contacts`，备用 `a.hero`）。

**测试与截图**

- **新增** `C02_fan|res://scripts/tests/cards/C02/test_fan.gd|180|`（顺序：金色在最左、留着的接在后面；每张的位置与转角合 §7.11.6 的公式、整排在 x 372–1008 加转角的余量里；悬停顶边 380、转角 0；`set_low`/`set_away`；`select_index` → `hand_selected`；`play_selected`/`play_uid`/拖进场景 → `card_played` + `hand_played` 的 `how` 对；夜里有“睡了”、打它 `def == ""`）、`C02_hero|res://scripts/tests/cards/C02/test_hero.gd|120|`（头像与三张人脉小牌的矩形 = `CardLayout`；拖拽数据；`used_today`、`away_days` 的样子；`person_pressed`）。
- 截图：扇 3 / 7 / 10 / 15 张各一张（金色、留着的、剩 1 天角标都看得见）、悬停一张、选中预览一张、`set_low` 一张、夜里扇一张、头像与人脉（用过了、不在）一张、拖拽中一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- `CardWidget`（牌框、整数倍插图、金框微光、角标、灰态、草稿样式、拖拽源、背面）与 `CardArt` 全部有效；只是悬停放大副本不要了。

**日期**：控件 PR（含扇与头像）合并目标从 10-20 改到 **10-21**。

## 只能改这些文件

- `scenes/cards/card/**`、`scripts/cards/ui/card/**`
- 默认拥有：`scripts/tests/cards/C02/**`、`scripts/tests/cards/suites/C02.txt`、`data/cards/tags/C02.json`、`data/cards/ui_keys/C02.json`
- 以及它们的 `.uid` / `.import`。`git status` 里多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`scripts/cards/api/**`、`scripts/cards/mock/**`、`scripts/cards/ui/common/**`、`scripts/tests/cards/lib/**`、`scripts/tests/cards/W0/**`、`data/cards/art/manifest.json`（归 K12）、别的任务的场景、旧代码）。
2. **不写最终内容、不画正式美术**：不建/不改 `data/cards/text/**`、`art/cards/**`、`art/_placeholder/**`（占位图归 K12 的生成器）、`audio/**`、`palette.json`、`legal/**`、`fonts/**`。缺的美术 id 开 `[content]` issue（给 A，抄送 K12），界面先用 `CardArt` 的缺图方块。`.gd` 字面量只许 ASCII、`.tscn` 不出现中文；新键只写键 + `brief`。
3. 不写颜色字面量（只许 `Color.WHITE`、`Color.TRANSPARENT`、`Color(1, 1, 1, a)`）；颜色只用 `CardTheme`。
4. 不露隐藏数值（不显示 `%`、权重、标签、底价、真值）；只显示 CardView 里给的。
5. 不放规则：能不能留由 `actions` 决定，不自己按类型猜。
6. 不用随机影响结果；不加别的 `class_name`（1.3 加的 `CardHandFan` `CardHeroBar` 除外）；不加 autoload/InputMap。
7. 不发 `first_time`；只发 `card_zoomed`、`card_drag_started`（1.3 加 `hand_selected`（从 C01 接过来）、`hand_played`）。

## 接口

**用到**：CardView（§7.5）：`uid def type zone gold must_resolve keepable expires_in days_left status art person intent item asking attrs used_today away_days actions`；1.3：视图 `hand` `kept` `self` `contacts` `night_offers`（元素是 `{def, art, choices}`，W1 里照收裸字符串）、`CardLayout`（`FAN` `PREVIEW_CARD` `PREVIEW_BTNS` `HERO` `CONTACT_MINIS`）、接口基类 `CardHandApi` `CardHeroApi`（W0，你来实现）；`CardText.card/person_name/ui/is_draft`；`CardTheme.color/frame_style/font_*`；`CardAnchors.register/unregister`；`CardBus.ui_event`（注入的 `bus`，没注入用 `/root/CardBus`）；`data/cards/art/manifest.json`（只读）。

**提供（冻结）**：§7.8 第二张表的 `CardWidget` 与 `CardArt` 全部接口；拖拽数据 `{"kind": "card", "uid", "zone"}`；1.3：`CardHandFan`（`CardHandApi` 的全部接口）、`CardHeroBar`（`CardHeroApi`），头像拖出去 `{"kind": "self"}`。新增（PR 里列出）：`set_back(on)`、可选的 `CardArt.nine_margins()`。

## 新手指引

- **必须登记的锚点**：`a.card@<uid>`、`a.card.keep@<uid>`、`a.card.days@<uid>`、`a.card.gold@<uid>`（数据里写 `@{uid}`，由 CardGuide 用 `first_time` 的 `args.uid` 代入）；1.3 加 `a.hand`（整排扇的外框）`a.hand.gold`（第一张是金色牌时那张）（这两个从 C01 接过来）`a.hand.kept`（留着的牌那几张的外框）`a.hand.preview`（预览里的“打出”）`a.hero` `a.contacts`。
- **必须发的 ui_event**：`card_zoomed {uid}`、`card_drag_started {uid, zone}`；1.3 加 `hand_selected {uid}`（从 C01 接过来）、`hand_played {uid, def, how}`。
- **first-time**：不发；依赖 `person` `gold` `keep` `kept_expire` `life` `news` `fate` `demand_people_return` `big_wheel`（1.3 加 `deal` `contact` `kept_risk` `person_state`）。
- **要证明会亮的步骤**：W1 必证——`gd.d1.person`（`a.card@{uid}`，备用 `a.hand`）、`gd.d2.gold`（`a.card.gold@{uid}`，备用 `a.hand.gold`）、`gd.d2.keep`（`a.card.keep@{uid}`，备用 `a.hand.kept`）、`gd.kept_expire`（`a.hand.kept`，用画面根证明扇里留着的牌带剩几天角标时这一步亮）。1.3 从 C01 接过来：`gd.d1.deal`（`a.hand`；照旧 W1 必证）、`gd.contact`（`a.contacts`）、`gd.kept_risk`（`a.hand.kept`）、`gd.person_state`（`a.contacts`，备用 `a.hero`）。顺带证明：`gd.life`（`a.card.days@{uid}`）、`gd.news` 与 `gd.fate`（`a.card@{uid}`）、`gd.demand_people`（“回来了吗”那张牌的 `a.card@{uid}`）、`gd.big_wheel`（`bf.wheel` 的 `a.card@{uid}`，备用 `a.wheel.face` 由 C06 证明）。另证：主锚点所在的牌换成别的牌后，这一步换用备用锚点（或渐隐），不悬空。
- **测试做法**：牌桌宿主 `CardGame.tscn` + `boot({"bus": bus, "fixture": "day_full", "skip_title": true, "guide": "on"})`（W0 夹具，9 张手牌含金色牌、留着的牌），或单独把 CardWidget 摆进测试场景；`game.guide.force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`，`bus.first_time.emit(&"gold", {"uid": <金色牌 uid>})` → `evaluate_now()` → `active_step() == "gd.d2.gold"`。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C02.txt`：

```
# C02 牌（docs/handoff_cards/C02_card-widget.md）
C02_examples|res://scripts/tests/cards/C02/test_examples.gd|180|
C02_states|res://scripts/tests/cards/C02/test_states.gd|120|
C02_drag_zoom|res://scripts/tests/cards/C02/test_drag_zoom.gd|120|
C02_anchors|res://scripts/tests/cards/C02/test_anchors.gd|120|
C02_art|res://scripts/tests/cards/C02/test_art.gd|60|
C02_guide|res://scripts/tests/cards/C02/test_guide.gd|180|
C02_fan|res://scripts/tests/cards/C02/test_fan.gd|180|
C02_hero|res://scripts/tests/cards/C02/test_hero.gd|120|
```

（最后两行是 1.3 新增，见上方“10-13 变更二”的“测试与截图”。）

| 测试 | 通过条件 |
|---|---|
| `test_examples.gd` | `all_examples.json` 每张牌三种尺寸都能 `set_card` 不报错；控件尺寸正好 144×200 / 288×400 / 72×100；每个插图节点尺寸是底图的整数倍、`texture_filter == NEAREST`；`t.all_text_from_cardtext(widget)` 为空；没有 `%` |
| `test_states.gd` | 金色牌有金框和光、没有“留着”按钮；`must_resolve` 只在手牌里有红点；`expires_in = 1` 显示 `1`、`-1` 不显示；生活牌显示 `days_left` 角标；`used_today` 灰；草稿样式在 `is_draft` 时生效 |
| `test_drag_zoom.gd` | `_get_drag_data()` 等于 `{"kind": "card", "uid", "zone"}`；发了 `card_drag_started {uid, zone}`；~~鼠标进入 → `card_zoomed {uid}` 且放大副本 288×400 整块在屏幕内、鼠标穿透~~（10-13 作废，合同 1.3：`card_zoomed` 在扇里选中时发，测在 `C02_fan`）；`action_requested(uid, "keep")` 在点“留着”时发出 |
| `test_anchors.gd` | 四种锚点按条件登记、`t.anchor_ok()`；`set_card` 换成另一张牌后旧 uid 的锚点 `has()` 为假；`queue_free` 后全部注销 |
| `test_art.gd` | 清单里有 `human` 文件 → 用它；没有 → 占位；都没有 → `missing`；`base_size` 对；`is_placeholder` 对；实例化一张 CardWidget ≤ 1 ms（取 100 张的平均，PR 里列数） |
| `test_guide.gd` | 上面“新手指引”列的每一步按做法亮、做 `done_when` 后完成；牌换掉后不悬空 |

- **W2 加**：`test_real_engine.gd`（真引擎 `day.begin` 后每张手牌的 CardView 都能渲染，没有报错）；清单加一行 `C02_guide_k16|res://scripts/tests/cards/C02/test_guide.gd|180|--steps=k16 --name=C02_guide_k16`（同一个脚本：从 `--name=` 取自己在清单里的名字打印 PASS 行，`--steps=k16` 时用 `load_steps(mock.query(&"guide_data"))`——K16 合入后 Mock 读 `data/cards/guide/steps.json`）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C02 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C02/shot_cards.gd -- --out=/tmp/shots/C02
  ```
- **截图**（不进清单）：`shot_cards.gd` → §4 每个例子的拼表三张（`C02_sheet_hand.png`、`C02_sheet_zoom.png`、`C02_sheet_mini.png`）、状态拼表（金色、红点、角标、灰态、草稿）、画面上 `day_full` 一张、~~悬停放大一张~~（10-13 作废，合同 1.3：换成上方“10-13 变更二”列的扇、预览、头像截图）；`shot_guide.gd` → 每个指引步骤一张 `guide_<步骤 id>.png`。全部 1280×720 画面截图；上传 PR，或提交到 `scripts/tests/cards/C02/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：三种尺寸、整数倍放大、NEAREST；牌名 20 号（小牌 14 号）；金色牌在手牌里**一眼能认**（框色 `frame_gold` + `gold_glow`）；草稿样式明显（灰、斜）。

## 交付

- PR 标题 `[C02] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①正式外观 + 整数倍 + 锚点 + 测试（尽早合，别人在等）；②放大、拖拽、背面、草稿样式、截图（1.3：手牌扇与头像并进控件 PR，10-21 合）；③（W2）真引擎 + K16 步骤复测。
- PR 描述按模板填全：改动路径；自查打勾；两个脚本的最后 20 行；截图；JevRng 域（无）；锚点、`ui_event`、依赖的 first-time；新公开函数（`set_back`、`nine_margins`）；缺的美术 id 清单（给 A/K12）；需要决定的事（生活牌角标用 `days_left`）；性能数；“回报”。

## 审核（Claude 重点）

- 冻结接口一个不差（`W0_skeleton` 会查参数个数和信号）；拖拽数据格式对。
- 截图：三种尺寸、整数倍、金色牌一眼能认、草稿样式明显；没有 `%`、没有标签/价钱泄露。1.3：手牌扇严格按引擎顺序、位置合扇形公式；头像与人脉小牌的矩形 = `CardLayout`。
- CardArt 发行版不返回占位或 `legacy` 图。
- 锚点随 `set_card` 换、出树注销；没有颜色字面量、中文字面量。

## 回报（执行者填写）

> 执行者**不要改本文件**（`docs/handoff_cards/` 归 Claude）。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（清单名 → 通过；贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / 发的 ui_event / 证明会亮的步骤 | |
| 新加的公开函数 | |
| 缺的美术 id（给 A/K12） | |
| 性能实测 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
