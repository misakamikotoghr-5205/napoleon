# 给 Cursor 的开场提示（16 条线：C01–C16）

**怎么用**：开 16 个 Cursor 窗口（或 16 个后台 Agent），每个窗口粘贴下面方框里的**同一段提示**，再按文末的分线表把 `<任务ID>` 和 `<slug>` 换成那一线的任务号和 slug。每条线只做自己那张任务卡；Claude（编排）审每一个 PR。

---

```text
你接手 GitHub 仓库 misakamikotoghr-5205/dehoudang（德厚当：Godot 4.7 + GDScript、GL Compatibility 渲染的民国当铺游戏，正在从“走动的当铺模拟”改成“卡牌游戏”）。你是 Cursor 的一条线，任务号 <任务ID>（slug：<slug>），负责界面 / 控件 / 小游戏 / 新手指引里的一块。其他 37 条线（Cursor 其余 15 条、Grok 16 条、GPT 6 条）同时在做别的部分，所以你只能动自己的文件，依赖别人的地方一律对着 W0 骨架里的桩和 Mock 引擎做，不要等。

【起点】
1. git fetch origin，从分支 claude/festive-ride-vud32a 的 W0 合入点（提交 b87a641 或之后的最新提交；确认 scripts/cards/api/card_ids.gd 存在）切出你的分支：
   git checkout -b cards/<任务ID>-<slug> origin/claude/festive-ride-vud32a
2. 用你自己的 Godot 4.7（4.7-stable）：export GODOT=<Godot 4.7 可执行文件路径>
3. 动手之前先跑一遍基线，应当全绿：
   $GODOT --headless --path . --import
   CARDS_SUITES=W0 bash tools/run_card_tests.sh

【先读（按顺序）】
1. 你的任务卡 docs/handoff_cards/<任务ID>_<slug>.md —— 你的范围、要做的事、只能改的文件、接口、新手指引、测试与验收、交付格式、审核要点，全在里面。
2. docs/cards/CARDS_INTERFACES.md（接口合同，必须遵守）：§0 九条红线与并行规则、§1.2 分辨率、画面与界面做法、§2 归属表、§3.3 开头与你的任务、§7.8 面板与控件、§7.10 新手指引、§11 免 AI 声明、§12 测试与截图、§13 分支与 PR、§14 审核清单，以及任务卡“必读”里点名的章节。**10-13 晚起合同 1.3：游戏画面是像素柜台场景 + 对话框，打牌是玩法、对话是载体——先读 §1.2（改写）、§7.8 的“呈现”一列、§7.11（画面与演出，新）和你任务卡里“10-13 变更二”一节；新控件按 W0 的接口基类写，主人没合入的用 CardIds.widget_scene() 取 W0 的桩。**
3. docs/cards/DESIGN_cards.md（玩法，主创原话）里任务卡点名的章节。优先级：主创原话 > 合同 > 任务卡 > 习惯做法。
4. 任务卡“必读”里列的 W0 骨架代码（scripts/cards/ui/**、scenes/cards/**、scripts/cards/mock/**、scripts/tests/cards/lib/card_t.gd、scripts/tests/cards/W0/**）。旧代码（scripts/town/**、scripts/ui/**、scripts/core/**）只读来参考做法。

【硬规则（违反任何一条，PR 直接退回）】
1. 归属：只改任务卡“只能改这些文件”里的路径，加上你默认拥有的 scripts/tests/cards/<任务ID>/**、scripts/tests/cards/suites/<任务ID>.txt、data/cards/tags/<任务ID>.json、data/cards/ui_keys/<任务ID>.json（以及它们的 .uid/.import）。提交前 git status：Godot 顺手改的别人的 .uid/.import 和 project.godot 一律 git checkout -- 掉。CI 的 check_pr_paths.py 会按归属表拦越界。docs/handoff_cards/ 也不是你的：不要改任务卡，回报写在 PR 描述里。需要别人的文件加东西：开 GitHub issue “[shared] <任务ID>→<对方>: …”，自己先绕过去并标 # TODO(shared#<issue号>)。
2. 免 AI 声明（Steam 包不得需要 AI 内容声明）：代码、测试、工具你随便写；玩家看得到、听得到、读得到的东西——正文、界面文字、人物名字、观察句、美术、配色、音频——你只能做占位：界面键只写“键 + brief”（brief 是干巴巴的说明，不写成能直接上线的文案或台词），数据文件 _meta 里带 "_provenance": {"by": "ai", "task": "<任务ID>", "date": "<今天>"}。绝不写、不改 data/cards/text/**、art/cards/**、audio/cards/**、data/cards/theme/palette.json、legal/**、fonts/**；不往 art/** 或 audio/** 放任何文件。.gd 的字符串字面量只许 ASCII（中文注释可以）；.tscn 里不出现中文（编辑器里填的 text/tooltip_text/placeholder_text 也算）；界面代码不写颜色字面量（只许 Color.WHITE、Color.TRANSPARENT、Color(1, 1, 1, a)），颜色只用 CardTheme 的配色键，文字只用 CardText，图只用 CardArt。不读、不拷旧版的 AI 文字：data/town/onboarding.json、data/town/rules.json、data/codebook.json、scripts/ui/appraise_panel.gd 的提示句、scripts/town/** 里的中文。
3. 确定性：影响游戏状态的随机只有引擎能做（JevRng.draw(seed, domain, key)，scripts/sim/jev_rng.gd）。界面（C01–C11、C16）完全不用 JevRng/randf/randi/randomize/RandomNumberGenerator/Time 影响任何结果（纯装饰的抖动可以用固定种子的 RandomNumberGenerator）。小游戏（C12–C15）内部的随机只用 JevRng.draw(params.seed, "c.mg.<kind>.layout", [i])；同样的参数 + 同样的操作 → 同样的结果。
4. 隐藏数值不上界面：不显示概率、百分比（界面上不许出现“%”）、权重、底价、真值、真假、来路、耐心数字、本心、口碑/风声的点数、扇区份数。口碑/风声只显示五档文字；扇区只显示大小。只显示视图（engine.view()）和查询结果里给的东西。鉴定小游戏只返回观察键，永远不返回“真/假/仿”。
5. 界面只读视图、只发指令：面板继承 CardPanel；只用 engine.send / engine.query / engine.view 和 CardBus（你只“发” ui_event，且只发 CardIds.UI_EVENTS 里归你的那几个）；不自己算规则；不在 CardBus 回调里同步 send()（用 call_deferred）；每个面板实现 autoplay_step()（和玩家走同一条代码路径）。先对着 MockCardEngine 和你自己写在 scripts/tests/cards/<任务ID>/fixtures/ 的夹具开发；所有面板对任意参数都不许报错。
6. 打烊永远可用（主创 10-13 硬性规则，红线 9、合同 §7.4.7）：牌桌上的“打烊 · 下一天”任何时候都能按；你的面板都要能关（关掉 = 它的“算了”，`dismiss()`）；不许用计时器替玩家推进；看你任务卡里的“10-13 变更”一节。
7. 新手指引（主创硬性要求，红线 8）：规矩在戏里讲，由人物开口，第一次遇到时才触发、按天解锁、能回看、能关、不打断、高亮锚点 + 一句气泡。你要用 CardAnchors.register() 登记任务卡“新手指引”一节列的每个锚点、发列出的 ui_event，并在测试里证明列出的指引步骤会亮（挂 GuideOverlay、force(true)、skip_fades = true、load_steps(<你的测试步骤>)、发 first_time、evaluate_now()、断言 active_step()）。first_time 由引擎发，你不发。指引的台词和气泡由人写，你一个字也不写。
8. 冻结接口：不改任何冻结的类名、方法签名、信号、场景路径（W0_skeleton 测试会查）；只有任务卡点名的冻结类写 class_name，其余辅助脚本用 const X = preload("res://…")；新加的公开函数列在 PR 里。合同有错或不够用：开 issue “[api] <任务ID>: …”。设计没写到的：按任务卡的“默认做法”做，代码里标 # TODO(design): …，写进 PR 的“需要主创/编排决定的事”。不许擅自加玩法。
9. 测试全绿：你的测试放 scripts/tests/cards/<任务ID>/，登记在 scripts/tests/cards/suites/<任务ID>.txt（一行“名字|res://脚本|超时秒|参数”，名字只用 ASCII、不带空格），每个脚本用 scripts/tests/cards/lib/card_t.gd，最后一行打印 CARDS TEST PASS <名字>。输出里出现 SCRIPT ERROR / ERROR / WARNING / Parse Error / FAIL: / DATA ERROR / 对象泄漏任何一行都算失败。测试要确定：不 sleep、不依赖墙钟、各用 t.user_dir() 下的路径。W0 的测试清单必须保持全绿。提 PR 前：
   bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
   开发中只跑自己的：CARDS_SUITES=W0,<任务ID> bash tools/run_card_tests.sh
   谁都不改 tools/run_tests.sh、tools/run_card_tests.sh、tools/run_legacy_smoke.sh。
10. 截图（界面和小游戏都要）：截图脚本放在你的测试目录、不进清单，用
   xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s res://scripts/tests/cards/<任务ID>/shot_<名>.gd -- --out=/tmp/shots/<任务ID>
   每个面板 × 每个夹具一张 1280×720 画面截图，任务卡列的每个指引步骤亮起时一张 guide_<步骤 id>.png。传到 PR 描述里；传不了就提交到 scripts/tests/cards/<任务ID>/shots/（里面放一个空的 .gdignore，单个 PR ≤ 4 MB）。没有 xvfb 就在 PR 里写明。
11. 视觉规格：逻辑分辨率 1280×720；Control 节点搭；像素图整数倍放大、TEXTURE_FILTER_NEAREST；字体经 CardTheme.font_title()/font_body()（正文 16–18、牌名 20、面板标题 28–36、最小 14）；弹出面板居中、最大 1100×640；动画只用 Tween、单段 ≤ 0.6 秒、可跳过；键盘可操作（Esc、Enter、Space、Tab、F1 归 C10 的帮助）。性能按合同 §12.4（打开面板 ≤ 50 ms、小游戏每帧 ≤ 4 ms、空闲 _process 不分配内存），测得的数写进 PR。

【交付】
- 一个 PR 只做一件事，可以拆 2–3 个（先骨架 + 测试，再功能 + 截图；W2 再补真引擎集成测试和 K16 指引数据复测）。开发中用 git rebase origin/claude/festive-ride-vud32a 跟上，不留合并提交。
- PR 标题：[<任务ID>] <中文一句话>；目标分支：claude/festive-ride-vud32a。
- PR 描述照 .github/pull_request_template.md 每节填全，并且必须有：改动路径清单；自查全部打勾；两个测试脚本输出的最后 20 行；截图；用到的 JevRng 域（界面：无；小游戏：你的 c.mg.<kind>.layout）；登记的锚点、发的 ui_event、依赖的 first-time；新加的公开函数；悬空引用与依赖；需要主创/编排决定的事；性能实测；最后一节“回报”（照任务卡末尾的表填）。
- Claude 按合同 §14.2 的清单审每一个 PR，结论是合并 / 改了再合（列“必须改”）/ 关掉。“必须改”修完再合。

现在开始：切分支、跑基线、读任务卡，然后先提一个小 PR（替换桩 + 夹具 + 测试骨架 + 锚点）。
```

---

## 分线表（每个窗口一条线）

| 线 | 任务 | slug | 任务卡 | 粘贴说明 | 这一线的重点 |
|---|---|---|---|---|---|
| 线 1 | C01 | `table` | `docs/handoff_cards/C01_table.md` | 在第 1 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C01`、`<slug>` 换成 `table` | 画面根、场景层、HUD、两侧标签与抽屉宿主、打烊按钮、叠层与小游戏宿主、指引宿主、F1/Esc、配色；W1 必须合入（目标 10-27） |
| 线 2 | C02 | `card-widget` | `docs/handoff_cards/C02_card-widget.md` | 在第 2 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C02`、`<slug>` 换成 `card-widget` | 牌、牌框、金色牌、角标、放大、拖拽、CardArt、手牌扇、英雄头像；别人都用它，先合小 PR（10-21） |
| 线 3 | C03 | `slots-coins` | `docs/handoff_cards/C03_slots-coins.md` | 在第 3 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C03`、`<slug>` 换成 `slots-coins` | 柜台上的格子与铜钱、选项与检定的演出、消息/当票的演出、人脉抽屉、人脉满、留牌满；SlotWidget/CoinToss/CounterChecks 先合（10-21，C05/C06/C11 复用） |
| 线 4 | C04 | `counter` | `docs/handoff_cards/C04_counter.md` | 在第 4 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C04`、`<slug>` 换成 `counter` | 对话框、柜台的演出（当、卖、买、赎与人物牌的选项）、货架与当票抽屉；对话框 10-21 先合（别人的演出都用它）；W1 必须合入 |
| 线 5 | C05 | `demand` | `docs/handoff_cards/C05_demand.md` | 在第 5 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C05`、`<slug>` 换成 `demand` | 条子板与条子面板（条子抽屉 + 胡二那一出）：六种办法、拖一拖；合并在 C03 与 C04 的对话框之后 |
| 线 6 | C06 | `wheel` | `docs/handoff_cards/C06_wheel.md` | 在第 6 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C06`、`<slug>` 换成 `wheel` | 命运轮盘：本月运势、大轮盘、庙会/赌摊、香案加宽、停针一致、界面无数字；合并在 C03 之后 |
| 线 7 | C07 | `fortune` | `docs/handoff_cards/C07_fortune.md` | 在第 7 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C07`、`<slug>` 换成 `fortune` | 黄历条、算命摊、求签、测字（黄历条进 HUD、黄历抽屉、算命那一出）；不泄露“几天后来什么牌” |
| 线 8 | C08 | `night-settle` | `docs/handoff_cards/C08_night-settle.md` | 在第 8 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C08`、`<slug>` 换成 `night-settle` | 打烊确认（未处理清单 + 确认，红线 9）、夜里打夜牌、日结在对话框里说 |
| 线 9 | C09 | `month-year` | `docs/handoff_cards/C09_month-year.md` | 在第 9 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C09`、`<slug>` 换成 `month-year` | 开月过场、月底、跳一年、局终与重来 |
| 线 10 | C10 | `dossier-help` | `docs/handoff_cards/C10_dossier-help.md` | 在第 10 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C10`、`<slug>` 换成 `dossier-help` | 档案簿（左抽屉；缺口）、规矩栏（只看 firsts）、F1 帮助 |
| 线 11 | C11 | `ladder` | `docs/handoff_cards/C11_ladder.md` | 在第 11 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C11`、`<slug>` 换成 `ladder` | 家当与抵押、钱不够、街头、牢房（家当抽屉、牢房那一出、街头按钮）；合并在 C03 之后 |
| 线 12 | C12 | `mg-spot` | `docs/handoff_cards/C12_mg-spot.md` | 在第 12 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C12`、`<slug>` 换成 `mg-spot` | 找不同：从旧验货面板分出来重写，只给观察，不改旧文件 |
| 线 13 | C13 | `mg-coin-ring` | `docs/handoff_cards/C13_mg-coin-ring.md` | 在第 13 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C13`、`<slug>` 换成 `mg-coin-ring` | 吹银元：波形与声音；占位声只在非发行版合成 |
| 线 14 | C14 | `mg-weigh` | `docs/handoff_cards/C14_mg-weigh.md` | 在第 14 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C14`、`<slug>` 换成 `mg-weigh` | 称分量：戥子/杆秤的简单物理，读数只来自压平的秤杆 |
| 线 15 | C15 | `mg-fragments-decode` | `docs/handoff_cards/C15_mg-fragments-decode.md` | 在第 15 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C15`、`<slug>` 换成 `mg-fragments-decode` | 拼碎片（主线当票）+ 解密（电报）；不读旧 `data/codebook.json` |
| 线 16 | C16 | `guide-shell` | `docs/handoff_cards/C16_guide-shell.md` | 在第 16 个窗口粘贴本提示，并把 `<任务ID>` 换成 `C16`、`<slug>` 换成 `guide-shell` | 新手指引引擎（第 1–3 天按顺序亮、每步截图）+ 标题、暂停、设置、曲目；教的人在画面里开口；W1 必须合入（目标 10-23） |

**合并先后**（大家同时开工，只是合并有先后）：C02、C03 的控件 PR 与 C04 的对话框先合（10-21；C05、C06、C11 复用格子和铜钱，C03/C05/C07/C08/C11 的演出用对话框）；C16 的指引引擎、C01 的画面根尽早合；C01–C04 + C16 是 W1 的完成条件。W2 由 Claude 把牌桌默认换成真引擎，各线再补一个对真引擎的集成测试，并用 K16 的 `data/cards/guide/steps.json` 复测自己的指引步骤。

**已知的合同缺口**（已报编排，合同更新前按任务卡里的“默认做法”做，代码里标 `TODO(design)` / `TODO(shared#…)`）：面板请求打开别的面板/回标题的 `close_requested(result)` 约定（C01 实现）；开月过场拿不到 `stage.json` 的背景和段数、跳年的行没有分组、局终原因不在视图里（C09）；拖拽“物品”的格式（C03，1.3 起 `{"kind": "item", "item"}` 写进合同了）。（其余几条 1.3 已关闭）
