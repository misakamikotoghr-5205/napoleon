# C10 `dossier-help` · 档案簿、规矩页、F1 帮助

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.3 C10 的展开。**优先级：主创原话 > 合同 > 本卡**。本卡和合同对不上时以合同为准，并开 issue `[api] C10: …` 报给 Claude。

## 执行者与线号

- 执行者：**Cursor**
- 线号：**Cursor 线 10**（在第 10 个 Cursor 窗口粘贴 `docs/handoff_cards/PROMPT_Cursor.md` 的提示，`<任务ID>` 换成 `C10`）
- 状态：未开工

## 依赖

- **任务依赖**：W0（提交 `b87a641`）。规矩页骨架由 K16 写（`data/cards/guide/rule_pages.json`；合入前 Mock 用 `data/cards/_examples/guide/rule_pages.json`，3 页）；档案数据由 K08 写（先用例子集的 `dp.linsao` 等）。F1 由 C01 转来；暂停菜单（C16）里的“帮助”也开你的 `help` 面板。
- **波次（Wave）**：W1 开发并合入；W2 补对真引擎（G03 的档案簿、G01 的 `firsts` / `guide_data`）的集成测试和 K16 数据复测。

## 分支

`cards/C10-dossier-help`，从 `claude/festive-ride-vud32a` 切（W0 合入点，标签 W0（提交 `b87a641`）；标签还没打时用该分支最新提交）。用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

①**档案簿**（1.3：左抽屉，左边标签“档案簿”和柜台上的档案簿都开它）：碎片化叙事的载体——人名索引（只列见过的人）、每人一页、碎片按顺序排、缺口画成撕掉/空白（不写“你错过了什么”，只是空着；金色牌没理、交出消息都会留缺口，永远补不上）、“一年后”碎片带年份小签、补齐盖章、新碎片小红点。②**规矩栏**（1.3：档案簿的第二个页签“规矩”，左边标签“规矩”和柜台上的算盘直接翻到这一页）：教过的规矩都能回看——解锁只看 `firsts`（机制第一次出现过就解锁），**和指引开关无关**。③**F1 帮助**：任何时候按 F1 打开（C01 转来）、Esc 或再按 F1 关；两页——操作（按键、一天怎么过）与规矩（同上解锁）。

## 必读

1. `docs/cards/DESIGN_cards.md` §三.11（档案簿：碎片化叙事）、§九.3（金色牌不理 → 档案页留缺口）、§九.4（③ 教过的都能回看：档案簿“规矩”页 + F1 帮助）。
2. `docs/cards/CARDS_INTERFACES.md`：§0、§1.2（输入：F1 任何时候打开帮助，C01 转发）、§3.3 开头与 C10、§4.5（`dossier_page#title`、`dossier_fragment#body`、`rule_page#title/#body`；F1 操作说明是 C10 的界面键 `c10.help.*`，**B 写**）、§4.7.19（档案页与碎片、`kind`、`year_after`）、§4.7.21（规矩页：`order` `unlock_first` `teacher`）、§7.4 查询 `dossier`（DossierView）、`firsts`、`guide_data`（`pages` 只给机制字段）、§7.5（DossierView：还没拿到的碎片不出现、缺口出现）、§7.8（`dossier` `help` 面板）、§7.10.1 第 4 条、§7.10.8、§7.10.10（规矩页起步 26 页）、§11.2、§12、**§1.2（1.3 改写）、§7.11（画面与演出，1.3 新）**。
3. 代码：`scripts/cards/ui/dossier/{dossier_book,help_panel}.gd`、`scenes/cards/dossier/{DossierBook,HelpPanel}.tscn`（W0 桩）、`scripts/cards/ui/table/card_game_root.gd`（F1 的处理）、`scripts/cards/mock/mock_scenario.gd`（`_dossier` `_dossier_view`）、`data/cards/_examples/dossier/dossier.json`、`data/cards/_examples/guide/rule_pages.json`。
4. 只读参考（不实例化、不拷文字）：`scripts/town/help_panel.gd`、`scripts/town/rules.gd`、`data/town/rules.json`（旧版规矩页的做法；**旧文字是 AI 写的，一个字也不许拷**）、`scripts/ui/book_panel.gd`（旧版账簿的翻页做法）。

## 要做的事

- [ ] **CardDossierBook**（`dossier_book.gd`，`class_name CardDossierBook`，kind `dossier`）（10-13 作废，合同 1.3：1100×640 的居中册子作废，改成左抽屉，里面那块 368×630——下面的内容逻辑照旧，布局以下方“10-13 变更二”为准）：
  - `query("dossier")` → `{pages:[{person, complete, new, fragments:[{id, order, era, kind, state, new}]}]}`；~~左边人名索引~~（1.3：人名在上面一排可横滑或下拉）（`CardText.person_name(person)`，有新碎片的小红点），~~右边当前一页~~（1.3：页在下面）：页名 `dp.<person>#title`（没有就用人名）、碎片按 `order` 排：`state: "have"` → 正文 `CardText.card(<碎片 id>, "body")` + 来源小字（`c10.kind.<kind>`）；`kind: "year_after"` 的带年份小签（`era`，数字可显示）；`state: "gap"` → **撕痕/空白**（代码画的撕边，配色键），**不显示碎片的任何文字、不写“错过了”**；还没拿到的碎片视图里本来就没有，**不画格子**；`complete` → 盖章（`CardArt` 的 `icon.seal` 一类 id，没有就开 `[content]` issue，先用配色画）。
  - 第三个栏目“规矩”（见下；1.3：上面两个页签“人”“规矩”，`args.tab == "rules"` 时直接打开“规矩”页）。翻页：左右键/滚轮；Esc 关（1.3：= 收回抽屉）。
  - 小红点只照视图的 `new`（合同缺口：没有“标为已读”的指令，红点什么时候消由引擎定；PR 里列出）。
- [ ] **规矩栏**（档案簿里和帮助里共用一个子界面，`scripts/cards/ui/dossier/rules_view.gd`，`preload`，不写 `class_name`）：`query("guide_data").pages`（`{id, order, unlock_first, teacher}`）与 `query("firsts").firsts` 求交：任一 `unlock_first` 在 `firsts` 里 → 解锁；按 `order` 排；标题 `rule.<id>#title`、正文 `rule.<id>#body`；落款口吻 `teacher`（人物 → `CardText.person_name`；`obj.notice` / `obj.almanac` / `obj.brother_ledger` → 本任务的键 `c10.teacher.<obj 名>`；`""` 不落款）。**不读指引开关**：关着指引也照样解锁、照样显示。没解锁的页不出现（不显示“还有几页没解锁”）。
- [ ] **CardHelpPanel**（`help_panel.gd`，`class_name CardHelpPanel`，kind `help`，场景 `res://scenes/cards/dossier/HelpPanel.tscn`）：两页签——“操作”（界面键 `c10.help.*`：按键一览、一天怎么过；**正文由 B 写**，你只写键 + `brief`）、“规矩”（规矩栏子界面）；F1 / Esc 关由 C01 的根处理（帮助开着时 F1 或 Esc 都关它），面板自己的“关”按钮发 `close_requested({})`；开在任何面板、小游戏之上都能显示（C01 的宿主叠层）。
- [ ] 两个面板对任意 `args` 不报错（`W0_skeleton` 会 `open({"uid": "c0002"})`）。
- [ ] **autoplay_step()**：两个面板都是“看一眼就关”：第一次调用 → `close_requested({})`、返回 true；之后返回 false。
- [ ] 不再 `preload` `w0_stub.gd`。
- [ ] **界面键** `data/cards/ui_keys/C10.json`（`c10.` 开头，键 + `brief`，`_meta._provenance`）：`c10.tab.people` `c10.tab.rules` `c10.tab.controls` `c10.kind.<pawn|said|heard|clipping|ticket|letter|year_after>` `c10.teacher.<notice|almanac|brother_ledger>` `c10.help.title` `c10.help.keys.<f1|esc|enter|space|tab|num>` `c10.help.day_flow`（一天怎么过；`brief` 只列要点，不写成教程文案）`c10.btn.close`。
- [ ] **夹具**（`scripts/tests/cards/C10/fixtures/`，`_meta.owner = "C10"`）：`dossier_mixed.json`（三个人：一页有 have/gap/new，一页补齐，一页有 1939 的“一年后”碎片）、`rules_some.json`（`firsts` 里有 `deal` `person` `slots`，`guide: "examples"` 让 Mock 读例子集的 2–3 页规矩）、`rules_guide_off.json`（同上，但根场景用 `--guide=off` / `force(false)`）。夹具过 `t.no_leaks()`。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] **CardDossierBook 改成左抽屉**（kind `dossier`，呈现 `drawer_l`，里面那块 368×630）：上面两个页签“人”“规矩”（`a.dossier.rules_tab` 是“规矩”页签）；“人”：人名一列（可滚动）+ 当前一页（碎片按 `order`、缺口撕痕、“一年后”小签、补齐盖章）——窄了，改成人名在上面一排可横滑或下拉，页在下面；`args.tab == "rules"` 时直接打开“规矩”页（左边标签“规矩”、柜台上的算盘都这样开）。
- [ ] **CardHelpPanel**：仍是叠层（F1），不变。

**新增 / 作废的交付**

- 没有新增文件。
- **作废**：档案簿 1100×640 的居中布局。

**锚点、界面事件、要证明的步骤**

- 锚点不改名（`a.dossier.page` `a.dossier.gap` `a.dossier.rules_tab` 在抽屉框里）。
- `gd.d2.rules` 的锚点是 C01 的 `a.tab.rules`（完成于 `panel:dossier` 或 `panel:help`）；C10 照旧证 `gd.news`（`a.card@{uid}`，备用 `a.hand`）`gd.dossier_gap` `gd.year_after`，`gd.dossier` 改由 C01 证。

**测试与截图**

- 加“`args.tab = "rules"` 直接开规矩页”；锚点在抽屉框里。
- 截图：档案簿抽屉（有缺口、有“一年后”）、规矩页、帮助各一张。全部 1280×720 画面截图（合同 §12.3）。

**已经做了的哪些还有效**

- 档案簿与规矩栏的内容逻辑、解锁规则、帮助全部有效；只换布局。

**日期**：档案簿抽屉目标 **10-29**。

## 只能改这些文件

- `scenes/cards/dossier/**`、`scripts/cards/ui/dossier/**`
- 默认拥有：`scripts/tests/cards/C10/**`、`scripts/tests/cards/suites/C10.txt`、`data/cards/tags/C10.json`、`data/cards/ui_keys/C10.json`
- 及其 `.uid` / `.import`。多出来的别人的路径、`project.godot` 一律 `git checkout --`。

## 不能做的事

1. 不改归属表外的文件（`data/cards/guide/**`（归 K16）、`data/cards/dossier/**`（归 K08）、C01 的 F1 处理、C16 的暂停、`scripts/cards/api/**`、`mock/**`、`ui/common/**`、`tests/cards/lib/**`、`tests/cards/W0/**`、旧代码）。
2. **不写最终内容**：碎片正文、页名、规矩页标题与正文、F1 的操作说明全部由人写（A/B）；**不拷 `data/town/rules.json`、`data/town/onboarding.json`、`scripts/town/help_panel.gd` 的任何文字**；不碰 `data/cards/text/**`、`art/**`、`audio/**`、`palette.json`、`legal/**`、`fonts/**`；`.gd` 字面量只许 ASCII、`.tscn` 不出现中文。
3. 不写颜色字面量（撕痕、红点、印章底色都用配色键）；图只经 `CardArt`。
4. 不露隐藏信息：缺口不泄露碎片内容；不显示“还差几块”“错过了什么”；规矩页不提概率、点数、本心（正文由人写，K13 审）。
5. 不放规则：解锁只照 `firsts` 与 `unlock_first`；不读、不依赖指引开关和指引进度。
6. 不用随机影响结果（撕边形状这类装饰可以用固定种子的 `RandomNumberGenerator`，种子取碎片 id 的哈希）；不加冻结表以外的 `class_name`；不加 autoload/InputMap。
7. 不发 `first_time`；本任务没有 `ui_event` 要发。

## 接口

**用到**：查询 `dossier {person?}`（DossierView）、`firsts`、`guide_data`（`pages`）；视图 `dossier_new`；总线 `dossier_changed(person, frag_id, kind)` `view_changed`；`CardText.person_name/card/ui`、`CardArt`、`CardTheme`、`CardAnchors`。

**提供（冻结）**：`CardDossierBook`（1.3：呈现为左抽屉，认 `args.tab = "rules"`）、`CardHelpPanel`（`CardPanel` 接口）；`HelpPanel.tscn` 路径不变（C01、C16 按 kind `help` 开它）。

## 新手指引

- **必须登记的锚点**：`a.dossier.page`（当前一页）`a.dossier.gap`（这一页第一个缺口）`a.dossier.rules_tab`（规矩栏的页签）`a.help.rules`（帮助里的规矩页签）（1.3：名字不变，前三个在左抽屉框里）。
- **必须发的 ui_event**：无（宿主发 `panel_opened {kind: "dossier"/"help"}`；1.3 带 `show`，档案簿另有 `drawer_opened {kind: "dossier", side: "left"}`）。
- **first-time**：不发；依赖 `news` `dossier` `dossier_gap` `year_after`；规矩栏的解锁依赖全部 66 个机制的 `firsts`。
- **要证明会亮的步骤**（W1 全部必证）：`gd.news`（第一张消息牌 → `a.card@{uid}`，备用 `a.hand`；用牌桌宿主）、~~`gd.dossier`（第一块碎片 → C01 的 `a.right.dossier`；用牌桌宿主）~~（10-13 作废，合同 1.3：改由 C01 证，锚点 `a.scene.notebook`）、`gd.dossier_gap`（第一次留缺口 → `a.dossier.gap`，备用 `a.scene.notebook`）、`gd.year_after`（备用锚点 `a.dossier.page`：C09 的跳年页不在时，档案簿里那一页亮）、`gd.d2.rules`（第 2 天早上回看规矩 → C01 的 `a.tab.rules`，完成于打开 `dossier` 或 `help` 面板）。
- **另证**：关着指引（`guide.force(false)`）时规矩栏照样按 `firsts` 解锁；F1/Esc 在每种面板之上都能开关帮助（用牌桌宿主逐个开面板再按 F1）。
- **测试做法**：牌桌宿主 `CardGame.tscn` + `boot({"bus", "fixture": "<本目录夹具>", "skip_title": true})`；挂指引（`force(true)`、`skip_fades = true`、`load_steps(<本目录 guide_steps.json>)`）；`bus.first_time.emit(&"dossier_gap", {"person": "brother"})` → 打开档案簿 → `evaluate_now()` → `active_step() == "gd.dossier_gap"`。

## 测试与验收标准

清单 `scripts/tests/cards/suites/C10.txt`：

```
# C10 档案簿与帮助（docs/handoff_cards/C10_dossier-help.md）
C10_dossier|res://scripts/tests/cards/C10/test_dossier.gd|120|
C10_rules|res://scripts/tests/cards/C10/test_rules.gd|120|
C10_help_keys|res://scripts/tests/cards/C10/test_help_keys.gd|240|
C10_guide|res://scripts/tests/cards/C10/test_guide.gd|180|
```

| 测试 | 通过条件 |
|---|---|
| `test_dossier.gd` | （1.3：在左抽屉里测；`args.tab = "rules"` 直接开规矩页；锚点在抽屉框里）索引只列视图里的人；碎片按 `order`；`have` 显示正文、`gap` 画撕痕且这个节点里**没有任何文字**、视图里没有的碎片没有节点（缺口和没拿到可区分）；“一年后”有年份签；补齐有章；`t.all_text_from_cardtext()` 为空 |
| `test_rules.gd` | `firsts` 含 `deal` 时解锁 `rule.day`、不含 `slots` 时没有 `rule.slots`；按 `order` 排；指引关着时结果一样；标题正文来自 `rule.<id>#title/#body` |
| `test_help_keys.gd` | 牌桌宿主里：没有面板、开着 `counter`/`slots`/`wheel`/`night`/`dossier`、开着小游戏时，按 F1 都开出 `help`、再按 F1 或 Esc 关掉（`panel_opened/closed {kind: "help"}` 成对）；“操作”页的字来自 `c10.help.*` |
| `test_guide.gd` | ~~五个~~ 四个步骤按做法亮、完成（1.3：`gd.dossier` 归 C01）；四个锚点 `t.anchor_ok()` |

另：`autoplay_step()` 第一次关面板、之后返回 false；没有 `%`；夹具 `t.no_leaks()`。

- **W2 加**：`test_real_engine.gd`（真引擎、例子集：拿到一块碎片、留一个缺口后打开档案簿，`query("dossier")` 的内容都画出来）；清单加一行 `C10_rules_k16|res://scripts/tests/cards/C10/test_rules.gd|120|--steps=k16 --name=C10_rules_k16`（脚本从 `--name=` 取清单名）（K16 合入后 `guide_data.pages` 有 26 页：`firsts` 全有时 26 页全解锁，按 `order` 排）。
- **命令**：
  ```bash
  export GODOT=<你的 Godot 4.7 可执行文件>
  CARDS_SUITES=W0,C10 bash tools/run_card_tests.sh
  bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
  xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . \
    -s res://scripts/tests/cards/C10/shot_dossier.gd -- --out=/tmp/shots/C10
  ```
- **截图**（不进清单）：~~档案簿索引、一页有缺口、补齐盖章、“一年后”、规矩栏、F1 帮助两页、帮助盖在柜台面板上~~（10-13 作废，合同 1.3：清单见上方“10-13 变更二”的“测试与截图”）各一张；`shot_guide.gd` 每个步骤一张 `guide_<步骤 id>.png`。1280×720 画面截图；上传 PR 或提交到 `scripts/tests/cards/C10/shots/`（放 `.gdignore`，≤ 4 MB）。
- **视觉规格**：~~面板居中 ≤ 1100×640，像一本摊开的册子（左索引右正文）~~（10-13 作废，合同 1.3：档案簿是左抽屉，里面那块 368×630，人名在上、页在下；帮助仍是叠层，居中 ≤ 1100×640）；正文 16–18 号、标题 28 号；撕痕一眼能看出是“撕掉了”，和“还没有”不一样；键盘：左右翻页、Tab 切栏、Esc 关。

## 交付

- PR 标题 `[C10] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①档案簿 + 规矩栏 + 测试；②F1 帮助、撕痕与盖章、截图；③（W2）真引擎 + K16 数据复测。
- PR 描述按模板：改动路径；自查打勾；最后 20 行；截图；JevRng 域（无）；锚点、依赖的 first-time；需要决定的事（新碎片红点怎么消）；缺的美术 id；给 B 的界面键清单（`c10.help.*`）；性能数；“回报”。

## 审核（Claude 重点）

- 缺口不泄露内容、和“没拿到”可区分；没有“你错过了 X”。
- 规矩解锁只看 `firsts`，代码里没有读指引开关；F1/Esc 在每个面板上都行。
- 没有拷旧版 `rules.json` / `help_panel.gd` 的文字；没有中文/颜色字面量、`%`。

## 回报（执行者填写）

> 执行者**不要改本文件**。把下表贴在 PR 描述最后一节“回报”。

| 项 | 填写 |
|---|---|
| 分支 / PR 链接 | |
| 做了什么（文件 → 内容） | |
| 测试结果（贴最后 20 行） | |
| 截图 | |
| 登记的锚点 / 证明会亮的步骤 | |
| 给 B 的界面键清单 | |
| 缺的美术 id | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 遗留 / 没做 | |
