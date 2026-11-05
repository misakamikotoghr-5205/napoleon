# 德厚当 · 卡牌版 —— 接口合同（38 条并行线共同遵守）

> **版本** 1.5 · 2026-10-18 · 维护人：Claude（编排）。1.0 之后按评审意见修订（新手指引、免 AI 声明的漏洞、确定性与存档、共享文件与接口歧义），改动摘要见附录 D；同日交接包审计的修订（归属表与 `ownership.json` 逐条一致、K13 不再跨线改文件、字体归人、发行排除补齐等）见附录 E。**1.2**：主创确认“九点”（原来【待主创确认】的都定了）、新硬性规则“打烊 · 下一天永远可用、绝不卡住”（红线 9、§7.4.7），见附录 F。**1.3**：主创 10-13 晚定下“画面与对话”——游戏画面是像素柜台场景 + 界面层，打牌是玩法、对话是载体（§1.2、§4.7.24、§7.11），见附录 G。
> **1.4（10-15）**：K17/K18 首发系统，见 §九.7。
> **1.5（2026-10-18，W2 #202/#212）**：AI 资源路径 ai_paths、human→ai→占位/静音查找、Steam 两种出包变体、§11.6 改由 K15 维护。
> **肉鸽 v1（2026-10-25，主创：“能不能加一点肉鸽元素。给我多子代理一起做”，授权编排“你自己决定”）**：老物件与博古格、周末盘账与客源、货郎头一回、每局新种子、旧账（局外档案、书架、旧墨、`og.shanghai`）。六个包 RG1–RG6 照实现合同 `docs/cards/rogue/ROGUE_V1.md` 并行做完、已合入；本合同新加 §15“肉鸽 v1”，并同步 §2.1/§2.2、§4.2、§5.2/§5.3、§6.3、§7.1、§7.3、§7.4、§7.5、§7.8、§7.10.5、§7.11.2/§7.11.3/§7.11.9。签名冻结的东西一个没改，只追加。
> **设计依据**：`docs/cards/DESIGN_cards.md`（v1 + v1.1 + 新手指引 + 打烊 · 下一天 + 画面与对话，主创原话）。本合同只规定“怎么做、谁做、接口长什么样”，不改玩法。
> **优先级**：主创原话 > 本合同 > 任务卡说明 > 习惯做法。合同有错或不够用：开 GitHub issue，标题 `[api] <任务ID>: …`，由 Claude 改合同并通知受影响的线；**任何执行方都不许自己改接口签名、改别人的文件**。
> **仓库**：https://github.com/misakamikotoghr-5205/dehoudang ，集成分支 `claude/festive-ride-vud32a`。
> **执行方**：Cursor 16 条线（C01–C16，界面、控件、小游戏、新手指引引擎、前端接入）· Grok 16 条线（K01–K16，牌的数据骨架、占位美术管线、史实与敏感审读、QA 自动化、来源审核工具、新手指引步骤与规矩页骨架、解放后分支设计）· GPT 6 条线（G01–G06，引擎、后端、破产阶梯、数值）· Claude 建第 0 波骨架（W0）、审每一个 PR、合并、集成。
> 标 **【待调】** 的数字是起步值，写在数据里，不许写死在代码里。

---

## 目录

- §0 红线与并行规则
- §1 架构总览、分辨率与界面做法（a）
- §2 目录与归属表（b）
- §3 任务编号与 38 条任务（c）
- §4 数据格式：每种牌的 JSON、例子、校验规则（d）；§4.7.24 演出块 stage
- §5 效果与条件 DSL（e）
- §6 状态模型 CardState 与随机数域登记（f）
- §7 模块接口：类名、方法签名、指令表、视图、CardBus、钩子、Mock（g）；**§7.4.7 打烊 · 下一天**；**§7.10 新手指引**；**§7.11 画面与演出**
- §8 小游戏插件接口（h）
- §9 命运轮盘与算命接口（i）
- §10 金色角色牌的实现（j）
- §11 来源与审核：免 AI 声明（k）
- §12 测试、代码风格、性能预算（l）
- §13 分支、PR、合并波次（m）
- §14 完成定义与 Claude 的审核清单（n）
- **§15 肉鸽 v1**（2026-10-25；实现合同全文 `docs/cards/rogue/ROGUE_V1.md`）
- 附录 A：W0 骨架交付清单 · 附录 B：给三家执行方的开场提示 · 附录 C：术语对照 · 附录 D：1.1 修订摘要 · 附录 E：交接包审计修订 · 附录 F：1.2 修订（打烊永远可用） · 附录 G：1.3 修订（画面与对话） · 附录 H：鉴定改版（10-25，看出来才算数）

---

## 0. 红线与并行规则

**九条红线**（违反任何一条，PR 直接退回）：

1. **免 AI 声明。** AI 可以随便写代码、测试、工具。玩家看得到、听得到、读得到的东西——正文、界面文字、人物名字、美术、配色、音频——AI 只能做**占位**，占位只许放在明确标记的草稿位置：数据里的 `brief` 字段、`art/_placeholder/**`、`audio/_placeholder/**`、开发版运行时生成的占位（见 §11）。AI 不许写、不许改：`data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`。Steam 包只含卡牌版，旧版的代码、文字、美术、音乐不进包（§11.6）。导出审核不过，不出包。
2. **确定性。** 影响游戏状态的随机只用 `JevRng.draw(seed, domain, key)`（`scripts/sim/jev_rng.gd`），通过 `ctx.draw(domain, key)` 调用；`domain` 必须在 §6.3 登记。禁止 `randf()/randi()/randomize()/RandomNumberGenerator/Time/OS.get_ticks*` 影响状态。同一种子 + 同一串指令 → 同一个状态哈希。
3. **隐藏数值不上界面。** 不显示：概率、百分比、权重、底价、真值、真假、来路、耐心、本心、口碑和风声的点数、扇区的权重数。可以显示：钱、铜钱数和要几个正面、天数（当票、条子、留牌）、人物属性点数、口碑/风声的**五档文字**、扇区的**大小**（画出来，不写数）。界面上不许出现“%”。
4. **规矩在戏里讲。** 不弹“机制说明”。规矩由人物、告示、哥哥的账簿批注、胡二的话来讲（正文由人写）；界面提示也只用戏里的话。落地方式就是新手指引（§7.10），不另做占手牌的“规矩牌”。
5. **鉴定只给观察，不给结论。** 小游戏只返回观察（观察键），永远不返回“真/假/仿”；引擎传给小游戏的参数是物理量（重量、余音、印章偏移），不是“fake: true”（§8）。（主创 10-25：“要玩家看出来才算数”——观察是玩家自己的判断，可以错；对错只在 G04 的私账里，§8.1。）
6. **史实措辞**按 `docs/town/cards/src/era.json` 的 notes：日方扶植的政权一律加“伪”字；1945 年写“抗战胜利”；1949 年写“解放”；抗战按“十四年抗战”；1950 年代运动只写政策和经济事件，不做随机惩罚牌，不写斗争会和暴力。
7. **测试红线。** `tools/run_tests.sh` 和 `tools/run_card_tests.sh` 的输出里出现 `SCRIPT ERROR`、`ERROR`、`WARNING`、`Parse Error`、`FAIL:`、`DATA ERROR` 任何一行都算失败；退出时对象泄漏（`ObjectDB instances leaked`、`RID … leaked`）也是 WARNING，算失败。
8. **每个机制都有新手指引。** `CardIds.FIRSTS` 里的每个机制都有至少一个戏里的指引步骤（人物开口、第一次遇到时触发、高亮对应的界面元素、一句气泡说“现在可以做什么”）和一页“规矩”（档案簿“规矩”页与 F1 帮助里能回看）。新机制没有 first-time 事件、新界面没有锚点和指引步骤，PR 退回。指引可以在设置里关掉；开关不改变任何游戏状态（§7.10）。
9. **打烊永远可用、绝不卡住。**（主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”）牌桌上永远有“打烊 · 下一天”；`day.end` 除了局终任何阶段都能用、永远往前走，不被任何牌挡住——还有没处理的牌只列清单、等玩家确认，确认后按“没理会”结算；所有面板和小游戏都能关（“算了”）；没有真实时间的倒计时，不自动跳天。哪个改动让某个能到达的状态按不动“下一天”，PR 退回（§7.4.7）。

**并行规则**：

- 每个文件、每个目录**只有一个主人**（§2）。只改归属表里写着你的任务号的路径，加上你自己的测试目录、清单文件、标签文件、界面键文件。
- 需要改共享文件或别人的文件：开 issue `[shared] <你的ID>→<对方ID或 Claude>: …`，写清楚要什么；在自己的代码里先用接口里已有的东西绕过去，标 `# TODO(shared#<issue号>)`。
- 依赖别的线还没做完的东西：对着 W0 骨架里的**桩**（同签名、简陋实现）和 **Mock 引擎**开发，不要等。
- 设计没写到的地方：按本合同的“实现理解”做；合同也没写的，用最保守的做法先实现，代码里标 `# TODO(design): …`，PR 里写进“需要主创/编排决定的事”。**不许擅自加玩法。**
- Godot 会顺手改别人的 `.import` / `.uid` 和 `project.godot`：提交前 `git status` 只应出现你自己的路径；多出来的（包括 `project.godot`）`git checkout --` 掉。
- **全局类名**：只有 §7 冻结表里的类、或在 PR 里列出并经 Claude 同意的新公开类可以写 `class_name`；其余辅助脚本一律 `const X = preload("res://…")`。两个文件写了同一个 `class_name`，只有合到一起才报错，会让所有线的测试一起挂。
- **常量**：`scripts/cards/api/card_ids.gd`（`CardIds`）里的常量在 W0 就把 v1 + v1.1 + 新手指引要用的列全了；之后各模块新加的指令名、错误码、原因码放在自己目录下的 `<模块>_ids.gd`（例 `scripts/cards/economy/economy_ids.gd`，`const` 脚本，不写 `class_name`），不去改 `card_ids.gd`。
- **“牌桌”一词**：1.3 起指整个游戏画面（场景层 + 界面层，§1.2）；红线 9 的“牌桌上永远有‘打烊 · 下一天’”= 画面上永远有（位置见 §7.11.2）。

---

## 1. 架构总览、分辨率与界面做法（a）

### 1.1 分层

```
 data/cards/**（机制骨架 JSON + brief，AI 可写）        data/cards/text/**（正文覆盖层，只有人写）
        │                                                         │
        ▼                                                         ▼
 CardDB（G01：读、合并、索引、规则文件、平衡覆盖）────── CardText（G01：按键取正文，逐字段查 剧情插件 → 人写层 → AI 层；缺字默认空串，开发开关开时显示【稿】+brief，【稿】字样读 data/cards/_dev/strings.json）
        │
        ▼
 CardEngine（G02 门面，继承 CardEngineApi）
   ├─ CardCtx（G01）：state(CardState) · db · bus · ops · conds · mods · hooks · actions
   ├─ 模块 install() 时登记自己的指令、效果 op、条件 op、修正项、钩子、动作：
   │     core(G01) → rules(G03) → economy(G04) → ladder(G06) → fate(G05) → loop(G02)
   ├─ send(cmd, args) → 改 state → 依次把可见事件（含 first_time）发到 CardBus → command_done → view_changed → 返回结果
   └─ view() → 只含可见信息的快照（CardViewModel 白名单，G02）
        │                                     ▲
        │ CardBus（autoload：引擎→界面；唯一例外 ui_event）│ send()/query()（界面→引擎的唯一入口）
        ▼                                     │
 scenes/cards/** 界面：画面根与场景层、HUD、标签与抽屉、打烊按钮 C01 · 牌、手牌扇、头像与人脉 C02 · 柜台上的格子与铜钱、人脉抽屉 C03 ·
                 对话框与柜台演出、货架/当票抽屉 C04 · 条子 C05 · 轮盘 C06 · 黄历与算命 C07 · 打烊确认、夜与日结 C08 ·
                 开关月与跳年 C09 · 档案簿与 F1 帮助 C10 · 家当/钱不够/街头/牢房 C11 · 指引与外壳 C16（§7.11）
 GuideOverlay（C16，C01 最上层 CanvasLayer，鼠标穿透）：听 first_time / command_done / ui_event，
                 按 CardAnchors 里各部件登记的锚点高亮，教的人开口（§7.10）
 scripts/cards/minigames/** 小游戏插件（C12–C15）：start(params) → finished(result)
 MockCardEngine（W0）：同一个 CardEngineApi，按夹具回放 —— 第 1 波界面全对它开发
 CardAutoplay（G06）：只用 send()/view() 无头玩整局；K14 用面板的 autoplay_step() 走真界面
```

要点：

- **引擎是纯逻辑**：`RefCounted`，不依赖场景树，不 `await`，不读输入，不画东西；无头测试直接 new 出来跑。
- **界面只读视图、只发指令**：界面永远不改 state，不自己算规则（比如“这个格子能不能放”要问引擎）。
- **总线基本单向**：CardBus 承载“引擎→界面”的事件；**唯一例外**是 `ui_event`（界面发出、只给新手指引听，引擎永远不连它，§7.6）。界面→引擎只有 `send()` / `query()`。
- **一切可见文字来自 CardText**（人写的覆盖层），一切颜色来自 CardTheme（读 `palette.json`；开发版没有时读 `palette.dev.json`），一切图来自 CardArt（读美术清单）。`.gd` 里不出现中文字符串字面量、不出现颜色字面量；`.tscn` 里也不许有中文（在编辑器里填进 `text`、`tooltip_text`、`placeholder_text` 的字同样算，§11.4 第 5 项会扫）。一张牌“怎么演”来自牌视图的 `stage`（数据里的演出块，§4.7.24）和 W0 的 `CardStageScript` 默认表，界面不读 CardDB。
- **扩展靠登记，不靠改别人的文件**：G04 要加一个效果 op，就在 `scripts/cards/economy/economy_install.gd` 里 `ctx.ops.register(...)`；G03 的文件不用动。

### 1.2 分辨率、画面与界面做法

| 项 | 规定 |
|---|---|
| 逻辑分辨率 | **1280×720**，沿用 `project.godot` 现有设置：`stretch/mode="canvas_items"`、`aspect="keep"`。任何任务都不改项目设置。正式游戏只做 PC 1280×720（网页原型的手机竖屏不做）。 |
| 画面 = 场景层 + 界面层 | **场景层**：320×180 的像素柜台场景（背景、门外的街、人、柜台上的工具与东西、效果），整数 **4 倍**铺满 1280×720。**界面层**：Control 节点（HUD、对话框、手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、“打烊 · 下一天”、柜台上的格子与铜钱、叠层面板、小游戏、指引）。层次和坐标见 §7.11。 |
| 场景层的做法 | 一律用 **Control 下的 TextureRect / TextureButton 组合**：根是 1280×720 的 Control（`CardStage`，C01），每个精灵按场景坐标 × 4 摆放，节点尺寸 = 底图尺寸 × 整数 k（背景、立绘、工具、道具 k=4，柜台上的物品 k=2，门口的行走图 k=8，街上的行走图 k=4），`texture_filter = TEXTURE_FILTER_NEAREST`。**不用 SubViewport、不用 Node2D**（理由：柜台上的物品要按 2 倍画，SubViewport 里缩一半会丢像素；锚点、点击、拖放都在同一个 1280×720 坐标系里，不用换算）。场景坐标 (sx, sy) → 屏幕 (4·sx, 4·sy)；所有坐标常量在 `CardLayout`（W0，`scripts/cards/api/card_layout.gd`，冻结，§7.11.2）。 |
| 像素插图 | 头像、物品、事件小插图、轮盘面、场景与道具都是像素图，按**整数倍**放大显示（`TEXTURE_FILTER_NEAREST`，节点尺寸 = 底图尺寸 × 整数 k）；不许非整数拉伸。例外只有一处：手牌扇里没被悬停的牌可以转 ±6° 以内（§7.11.6），悬停、选中、拖拽时转回 0°。 |
| 文字层 | 字都在界面层（对话框、回话、HUD、标签、抽屉、面板），**不进场景层**；场景层只有图。 |
| 字体 | 正文 Noto Serif SC（`res://fonts/NotoSerifSC-Regular-subset.otf`），标题马善政（`res://fonts/MaShanZheng-Title-subset.ttf`），通过现有 `UiStyle.body_font()` / `UiStyle.title_font()` 取。字号：正文与对话 16–18，HUD 15，回话 17，名字条 22，牌名 20，面板标题 28–36，最小 14。字体是子集（第三方 OFL 字体；`fonts/**` 只有人改，§2.2）：W3 加正文后由 B 跑 `tools/build_fonts.py`（脚本归 Claude）重建子集。 |
| 牌的尺寸 | 手牌 **144×200**；选中放大 **288×400**；小牌（人脉小牌、抽屉里的牌、打烊清单）**72×100**；英雄头像框 **108×144**。 |
| 底图尺寸（K12 出占位，A 出正式） | 头像 48×64（手牌里 ×2，选中放大 ×4，**柜台前的立绘 ×4**）；事件/命运/条子/留牌等小插图 64×48（×2 / ×4）；物品 64×64（柜台上 ×2，小游戏里 ×4 起）；牌框 9 宫格底图 36×50、边距 6（×4 显示）；**场景背景 320×180（×4 = 1280×720）**；**行走图 64×128（16×32 一帧，门口 ×8、街上 ×4）**；**柜台工具与道具按各自底图（×4，§4.8）**；对话框框 48×48 九宫格（×2）；英雄头像框 27×36 九宫格（×4）；轮盘面 120×120（×4 = 480）；图标 16×16 或 24×24。 |
| 画面分区（1280×720） | 场景铺满整屏；HUD 是最上面一条 y 0–30；对话框在左上（x 52、y 38、宽 380、高随内容 180–482，底边 ≤ 520，不压手牌扇和头像）；手牌扇在最下面 x 372–1008；英雄头像 x 12–120、人脉小牌 x 128–356（y 566–710）；左标签 x 0–44、右标签 x 1236–1280（y 100 起，每个 44×78）；左抽屉 x 0–400、右抽屉 x 860–1280（y 30–720）；“打烊 · 下一天” (1020, 556, 210, 92)，任何时候都能按（§7.4.7）；叠层面板居中，最大 1100×640。全部常量见 §7.11.2。 |
| 输入 | 鼠标：点、拖（手牌拖进画面 = 打出；头像、人脉、留着的牌拖进柜台上的格子；钱用格子上的加减或拖钱；牌和钱拖进香案）。键盘：**Space / Enter**：对话框里还有没说完的句子就下一句（逐字中先补全这一句）；说完了、有选中的手牌时 Enter = 打出。**1–9**：对话框列着回话时选第 N 句回话，否则选第 N 张手牌（放大看）。**Esc**：小游戏 → 它的 `abort()`；否则关最上层（叠层面板 → 抽屉 → 正在演的这一出，都 = 它的“算了”，§7.8）；什么都没开时暂停。Tab 在可点的东西间移动。**F1 任何时候打开帮助（规矩页，C10；C01 转发；Esc 关）**。不新增 InputMap 动作，直接判断 `InputEventKey.keycode`。 |
| 动画 | 只用 Tween；单段 ≤ 0.6 秒（白天/黄昏/夜里换背景交叉淡入 0.6 秒；客人从街上走到门口 0.6 秒、立绘上滑 0.25 秒）；对话框逐字出现的速度用 `scripts/town/settings.gd` 的 `text_cps()`（已有）；设置里“快动画”开着时全部跳过、文字一下子显示完。动画期间面板自己挡输入，引擎不知道动画；**没有任何动画、计时会替玩家推进**（红线 9）。 |
| 配色 | CardTheme（C01）读 `data/cards/theme/palette.json` 的键（§2.4）。这个文件**只有 A 建、只有 A 写**；W0 只写 `data/cards/theme/palette.dev.json`。CardTheme：有 `palette.json` 用它；没有且 `!CardShip.is_ship()` 时退回 `palette.dev.json`；发行版没有 `palette.json` → 审核失败（§11.4）。场景里代码画的效果（雨、火光、夜色、封条、影子）只许用配色键。 |
| 音乐 | `music_director.gd` 写死了旧版曲目清单 `res://audio/music/music.json`（第 13 行），卡牌版不用它。C16 写 `scripts/cards/ui/shell/card_music.gd`，读 `data/cards/audio/music.json`（曲目键 → `audio/cards/music/*`（B 做）或开发版的 `audio/_placeholder/**`）；旧版曲目只在 `!CardShip.is_ship()` 时可以借来当占位。 |
| 新手指引 | C01 最上层 CanvasLayer（layer 100）上的 GuideOverlay（C16）：一次只亮一处——锚点外框发光 + 锚点旁一句气泡（现在可以做什么）+ **教的人在画面里开口**（人物站到柜台一侧、物件用一张批注纸，§7.10.7）；整层鼠标穿透、不吃按键、不暂停引擎；颜色键 `guide_glow` `guide_bubble` `guide_ink` `guide_note`（§7.10）。 |

---

## 2. 目录与归属表（b）

### 2.1 目录树

```
scripts/cards/
  api/                card_engine_api.gd · card_minigame.gd · card_ids.gd · card_ship.gd · dsl_shapes.gd · card_layout.gd   W0（Claude，冻结）
  core/               模型、DB、状态、牌堆、发牌、存档、校验、正文、总线、登记表、first-time 记录            G01
  loop/               门面、日/周/月/年、日程、金色牌、目标、跳年、视图                                   G02
  rules/              格子与铜钱、效果/条件核心、属性与口碑风声本心、条子、档案簿                         G03
  economy/            柜台、定价、客人、货架、当票（card_ledger）、鉴定桥、物品、货币、月账                 G04
  fate/               牌库权重、命运触发、轮盘、求签测字、黄历、钉签、压力与天气                          G05
  ladder/             家当与抵押、钱不够阶梯、街头、牢房                                                 G06
  sim/                自动玩、策略、蒙特卡洛、回放                                                       G06
  mock/               MockCardEngine 与基础夹具                                                          W0（Claude）
  ui/common/          card_panel.gd · card_anchors.gd · card_stage_panel.gd · card_stage_script.gd · card_{stage,dialog,hand,hero,checks}_api.gd · w0/（W0 桩）（W0 冻结）· card_theme.gd（W0 建桩 → C01）
  ui/table/ C01 · ui/card/ C02 · ui/slots/ C03 · ui/counter/ C04 · ui/demand/ C05 · ui/wheel/ C06
  ui/fortune/ C07 · ui/night/ C08 · ui/month/ C09 · ui/dossier/ C10 · ui/ladder/ C11
  ui/shell/ C16（新手指引引擎 card_guide.gd、标题、暂停、设置、曲目 card_music.gd）
  minigames/spot/ C12 · minigames/coin_ring/ C13 · minigames/weigh/ C14 · minigames/fragments/ C15 · minigames/decode/ C15
  relic/ RG1（老物件）· stock/ RG2（周末盘账、客源、种子 run_seed.gd）· legacy/ RG5（本局上下文、旧账查询）   肉鸽 v1（§15），装在 K18 之后
  meta/ RG5（外壳的档案文件 card_profile.gd、根场景里的 run_keeper.gd）· ui/rogue/ RG4（盘账叠层、博古格抽屉、场景博古格、标题 RunBox）
scenes/cards/
  CardGame.tscn       C01（牌桌版的根场景）
  _w0/                W0 的桩场景（Stage、DialogBox、HandFan、HeroBar、CounterChecks、PanelStub）  W0（Claude）——X01-b 已删
  table/ C01 · card/ C02 · slots/ C03 · counter/ C04 · demand/ C05 · wheel/ C06 · fortune/ C07
  night/ C08 · month/ C09 · dossier/ C10（含 HelpPanel）· ladder/ C11 · shell/ C16（含 GuideOverlay）
  minigames/spot/ C12 · coin_ring/ C13 · weigh/ C14 · fragments/ C15 · decode/ C15
  rogue/ RG4（StocktakePanel.tscn、RelicsDrawer.tscn；肉鸽 v1）
data/cards/
  _schema/            每种牌的字段说明（JSON）                                                G01
  _examples/          §4 的全部例子 + 指引样例 _examples/guide/（自成一套，和真数据从不一起读，§4.10）   W0
  _dev/strings.json   开发版专用字串（【稿】标记等），导出排除                                  W0（Claude）
  rules/              规则与数值，按文件分主人（§2.2）
  tags/<ID>.json      各任务自己引入的标签（W0.json 里有封闭的 omen_* 征兆家族，§2.5）          各任务
  ui_keys/<ID>.json   各任务自己用到的界面/提示文字键（只有键和 brief）                         各任务
  era/common/         passersby.json K01 · events.json big_fate.json K02 · fate.json K04 · life.json K06 · relics.json sources.json RG3（肉鸽 v1）
  era/1938/           people.json story.json K01 · events.json fate.json big_fate.json life.json goals.json stage.json K02 · tutorial.json K16 · curio_peddler.json RG3（肉鸽 v1）
  era/1939/           people.json story.json K03 · events.json fate.json big_fate.json life.json goals.json stage.json K04
  era/1940/           people.json story.json K05 · events.json fate.json big_fate.json life.json goals.json stage.json K06
  demand/             条子（4 类 × 4 档 × 3 年）与吃亏阶梯                                     K07
  news/  dossier/     消息牌；档案簿页与碎片                                                  K08
  common/             kept.json contacts.json estates.json night.json street.json prison.json self.json extras.json（群演）   K09
  fortune/            wheels.json segments_1938.json segments_1939.json segments_1940.json lots.json cezi.json almanac.json   K10
  guide/              steps.json rule_pages.json（新手指引步骤与规矩页骨架，§7.10）            K16
  branch/             解放后分支的数据（预留，首发不读）                                       K16
  minigames/items.json  物品 → 小游戏参数 · minigames/codebook.json 电码本骨架（码 → 键 + brief）   K11
  minigames/obs/<kind>.json  各小游戏的观察键目录（键 + brief）                               C12–C15（各管各的 kind）
  items/              templates_extra.json（新增物品模板，如银元）· launch_items.json         K11
  art/manifest.json   美术 id → 底图尺寸、正式路径、AI 路径、占位路径                          K12
  audio/music.json    卡牌版曲目键 → 音频路径（human / ai / 非发行版的 legacy 旧曲，_provenance 登记来源；不带声明版还会有 stage 剥离产出的 audio/sfx.json）  C16
  theme/palette.dev.json  开发配色初值                                                       W0（Claude）
  theme/palette.json  正式配色                                                               **只有人写（A）**
  text/**             正文覆盖层                                                             **只有人写（A/B）**
  text_ai/**          AI 台词正文层（与 text/** 同结构、同键，文件级五段 _meta._provenance 登记来源）  AI 线（G01/各线）
art/cards/**          正式美术                                                               **只有人画（A/外包）**
art/ai/**             AI 生成美术（art/ai/<类别>/<id>.png，清单登记 _provenance）              AI 线（K12/美术线）
art/_placeholder/**   占位美术（生成器产出，导出时排除）                                       K12
audio/cards/**        正式音频                                                               **只有人做（B）**
audio/ai/**           AI 生成音频（audio/ai/<music|sfx>/<id>.ogg，音效清单固定在 audio/ai/sfx/manifest.json 登记 cues 与 _provenance）  AI 线（C16/K12/音频线）
audio/_placeholder/** 占位音频（如果需要）                                                    K12
tools/cards/art/ K12 · tools/cards/review/ K13 · tools/cards/qa/ K14 · tools/cards/audit/ K15（cjk_allowlist.json 归 Claude）· tools/cards/balance/ G06
scripts/tests/cards/
  lib/                测试小工具 card_t.gd                                                    W0（Claude）
  suites/<ID>.txt     各任务的测试清单（runner 只读这里）                                      各任务
  <ID>/               各任务的测试脚本、夹具、截图脚本                                          各任务
  golden/             黄金种子回放                                                            G06
docs/cards/
  DESIGN_cards.md · CARDS_INTERFACES.md · STATUS.md · ownership.json · prototype/（网页原型与截图）   Claude
  ART_SPEC.md · art/** K12 · review/ K13 · qa/ K14 · audit/ K15 · post1949/ K16 · balance/ G06
  rogue/（肉鸽 v1 的实现合同 ROGUE_V1.md 与 R1–R3 三份提案）   Claude
legal/                ASSET_PROVENANCE.csv · human_authors.json（A、B 的 GitHub 账号）· AUDIT_SIGNOFF.md   人（A/B）
fonts/                两个字体子集（第三方 OFL 字体，B 用 tools/build_fonts.py 重建）              人（A/B）
docs/handoff_cards/   38 张任务卡、三份开场提示、交接板 README                                   Claude
.github/              CODEOWNERS · workflows/ · pull_request_template.md · ISSUE_TEMPLATE/   Claude
```

### 2.2 归属表（权威；W0 会生成同内容的 `docs/cards/ownership.json` 给工具用，两者不一致以本表为准）

| 路径 | 主人 | 备注 |
|---|---|---|
| `scripts/cards/api/**` | Claude | 冻结；改签名走 `[api]` issue |
| `scripts/cards/mock/**` | Claude | 界面任务要新夹具，放自己的 `scripts/tests/cards/<ID>/fixtures/` |
| `scripts/cards/ui/common/card_panel.gd`、`card_anchors.gd`、`card_stage_panel.gd`、`card_stage_script.gd`、`card_stage_api.gd`、`card_dialog_api.gd`、`card_hand_api.gd`、`card_hero_api.gd`、`card_checks_api.gd` | Claude | 面板基类、锚点登记、画面控件的接口基类与默认演法，冻结。W0 桩（`w0_stub.gd`、`w0/**`、`_w0/**`）已在框架版收尾（X01-b）删除 |
| `scripts/cards/ui/common/card_theme.gd` | C01 | W0 建桩 |
| `scripts/cards/core/**`、`data/cards/_schema/**`、`data/cards/rules/deal.json`、`data/cards/text_ai/**` | G01 | `core/card_bus.gd` 由 Claude 在 W0 登记为 autoload `CardBus`，信号表（§7.6）W0 写好、冻结；`data/cards/text_ai/**` 为 W2（#212）AI 台词层 |
| `scripts/cards/loop/**`、`data/cards/rules/{loop,stages,goals_rules}.json` | G02 | |
| `scripts/cards/rules/**`、`data/cards/rules/{slots,meters,demand_rules}.json` | G03 | |
| `scripts/cards/economy/**`、`data/cards/rules/{economy,currency,items_balance}.json` | G04 | |
| `scripts/cards/fate/**`、`data/cards/rules/{weights,fate,pressures,daily_wheels,fortune}.json` | G05 | |
| `scripts/cards/ladder/**`、`data/cards/rules/ladder.json`、`scripts/cards/sim/**`、`data/cards/rules/balance_overrides.json`、`scripts/tests/cards/golden/**`、`docs/cards/balance/**`、`tools/cards/balance/**` | G06 | `golden/golden.json` 的哈希在 G06 交付后由 Claude 在合并时重算（§12.5）——这是合并步骤，不是第二个主人 |
| `scenes/cards/CardGame.tscn`、`scenes/cards/table/**`、`scripts/cards/ui/table/**` | C01 | |
| `scenes/cards/card/**`、`scripts/cards/ui/card/**` | C02 | |
| `scenes/cards/slots/**`、`scripts/cards/ui/slots/**` | C03 | |
| `scenes/cards/counter/**`、`scripts/cards/ui/counter/**` | C04 | |
| `scenes/cards/demand/**`、`scripts/cards/ui/demand/**` | C05 | |
| `scenes/cards/wheel/**`、`scripts/cards/ui/wheel/**` | C06 | |
| `scenes/cards/fortune/**`、`scripts/cards/ui/fortune/**` | C07 | |
| `scenes/cards/night/**`、`scripts/cards/ui/night/**` | C08 | |
| `scenes/cards/month/**`、`scripts/cards/ui/month/**` | C09 | |
| `scenes/cards/dossier/**`、`scripts/cards/ui/dossier/**` | C10 | 含规矩页与 F1 帮助（`HelpPanel.tscn`） |
| `scenes/cards/ladder/**`、`scripts/cards/ui/ladder/**` | C11 | |
| `scenes/cards/minigames/spot/**`、`scripts/cards/minigames/spot/**`、`data/cards/minigames/obs/spot.json` | C12 | 含从旧验货面板分出来的 `spot_panel.gd` |
| `…/minigames/coin_ring/**`、`data/cards/minigames/obs/coin_ring.json` | C13 | |
| `…/minigames/weigh/**`、`data/cards/minigames/obs/weigh.json` | C14 | |
| `…/minigames/fragments/**`、`…/minigames/decode/**`、`data/cards/minigames/obs/{fragments,decode}.json` | C15 | |
| `scenes/cards/shell/**`、`scripts/cards/ui/shell/**`、`data/cards/rules/guide.json`、`data/cards/audio/music.json`、`audio/ai/**` | C16 | 新手指引引擎与覆盖层、标题、暂停、设置、曲目 |
| `data/cards/era/1938/{people,story}.json`、`data/cards/era/common/passersby.json` | K01 | |
| `data/cards/era/1938/{events,fate,big_fate,life,goals,stage}.json`、`data/cards/era/common/{events,big_fate}.json` | K02 | |
| `data/cards/era/1939/{people,story}.json` | K03 | |
| `data/cards/era/1939/{events,fate,big_fate,life,goals,stage}.json`、`data/cards/era/common/fate.json` | K04 | |
| `data/cards/era/1940/{people,story}.json` | K05 | |
| `data/cards/era/1940/{events,fate,big_fate,life,goals,stage}.json`、`data/cards/era/common/life.json` | K06 | |
| `data/cards/demand/**` | K07 | |
| `data/cards/news/**`、`data/cards/dossier/**` | K08 | |
| `data/cards/common/**` | K09 | |
| `data/cards/fortune/**` | K10 | |
| `data/cards/minigames/items.json`、`data/cards/minigames/codebook.json`、`data/cards/items/**` | K11 | |
| `tools/cards/art/**`、`art/_placeholder/**`、`audio/_placeholder/**`、`art/ai/**`、`audio/ai/**`、`data/cards/art/manifest.json`、`docs/cards/ART_SPEC.md`、`docs/cards/art/**` | K12 | |
| `tools/cards/review/**`、`docs/cards/review/**`、`data/cards/rules/wording.json` | K13 | **不改别人的数据**：审读结论开 `[K13→K0x]` issue，由数据的主人改（§2.6） |
| `tools/cards/qa/**`、`docs/cards/qa/**` | K14 | |
| `tools/cards/audit/{check_pr_paths,audit,stage_ship,missing_text}.py`、`tools/cards/audit/{verdict_words.json,README.md}`、`tools/cards/audit/{tests,fixtures}/**`、`docs/cards/audit/**` | K15 | 逐个文件列出（同目录的 `cjk_allowlist.json` 归 Claude）；要新文件开 `[api] K15→Claude`，Claude 同时改本表和 `ownership.json` |
| `data/cards/guide/**`、`data/cards/era/1938/tutorial.json`、`data/cards/branch/**`、`docs/cards/post1949/**` | K16 | |
| `data/cards/era/1940/officialdom.json` | K17 | **1.4**（§九.7 官场开头）；指引步骤 `gd.office` 作为跨线新增写在 K16 的 `steps.json` |
| `scripts/cards/apprentice/**`、`data/cards/era/1939/apprentice.json`、`data/cards/rules/apprentice.json` | K18 | 收徒。跨线文件见 §3.4 K18 与 #187，并写进 `ownership.json` |
| `data/cards/era/1938/pet.json`、`data/cards/rules/pet.json`、`docs/handoff_cards/K18_pet-cat.md` | K18 | 宠物（店里的猫）。跨线文件见配套 `[api]` |
| `scripts/cards/weapon/**`、`data/cards/era/1939/weapon.json`、`docs/handoff_cards/K18_weapon-scare.md`、`docs/handoff_cards/K18_1940_scare.png` | K18 | 武器只开吓唬。合同 1.4 暂时挂在 K18 名下的共享文件（choices、rules_install、card_ids、slot_panel、counter_panel、指引步骤与规矩页、几处测试、本合同与 `ownership.json`）已在框架版收尾（10-19）时还回 G03 / C03 / C04 / K16 / Claude。G01 正例夹具同时保留 `apprentice`、`pet` 与 `scare` |
| `scripts/cards/relic/**` | RG1 | 肉鸽 v1 老物件模块（§15）。`relic_api.gd` 是写 `state.relic` 的唯一入口，RG2 只 `preload` 调用，签名冻结 |
| `scripts/cards/stock/**` | RG2 | 肉鸽 v1 周末盘账、客源、`stock.pick`、`stock_offer`。`run_seed.gd`（`CardRunSeed`）签名冻结，外壳（RG5）只调用 |
| `data/cards/era/common/{relics,sources}.json`、`data/cards/era/1938/curio_peddler.json`、`data/cards/rules/{relics,stock,legacy}.json` | RG3 | 肉鸽 v1 的牌与规则文件（`_meta.owner = "RG3"`）。平衡调数照旧经 `balance_overrides.json`（G06）；物件、客源、货郎的 AI 基础层正文在 `data/cards/text_ai/era/**`（`ai_paths`），美术与生成器 `tools/cards/art/gen_ai_rogue.py` 归 K12 |
| `scenes/cards/rogue/**`、`scripts/cards/ui/rogue/**` | RG4 | 肉鸽 v1 盘账叠层 `stocktake`、博古格抽屉 `relics`、场景博古格 `curio_shelf.gd`、标题 RunBox `title_run_box.gd` |
| `scripts/cards/legacy/**`、`scripts/cards/meta/**` | RG5 | 肉鸽 v1 本局上下文与旧账查询（引擎，`legacy/`）；档案文件 `CardProfile` 与根场景里的 `run_keeper.gd`（外壳，`meta/`） |
| `scripts/tests/cards/<ID>/**`、`scripts/tests/cards/suites/<ID>.txt`、`data/cards/tags/<ID>.json`、`data/cards/ui_keys/<ID>.json` | 各任务自己 | 每个任务都有，不用登记 |
| `packs/**`（剧情插件，`docs/cards/PLUGINS.md`） | 写剧情的人（各管自己的 `packs/<id>/**`；`ownership.json` 的 `paths.packs`） | **框架版收尾默认（2026-10-22），主创可改**。不在 `human_only`、也不在 `ai_paths`：作者类别写在 `packs/<id>/pack.json` 的 `source`；`source: "human"` 的插件按人写层处理，`check_pr_paths.py` 拒绝不在 `human_authors.json` 的作者改它 |
| `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**` | **AI 线（`ai_paths`）** | W2（2026-10-18，#212 / #202）：AI 线可写，须登记 `_provenance: "ai:<工具>:<模型>:<日期>:<提示词或任务 id>"`（美术支持 `ai:google-<工具名>:<日期>:<提示词 id>`）；`check_pr_paths.py` 允许 AI 线修改 |
| `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`（`ASSET_PROVENANCE.csv`、`human_authors.json`、`AUDIT_SIGNOFF.md`）、`fonts/**`（第三方 OFL 字体的子集，B 跑 `tools/build_fonts.py` 重建） | **人（A/B）** | 作者不在 `legal/human_authors.json` 里的 PR 一律不许碰（CODEOWNERS + 必过的 CI 检查拦，§11.5） |
| 其余一切（`project.godot`、`export_presets.cfg`、`scenes/Main.tscn`、`scripts/ui/main.gd`、`tools/run_tests.sh`、`tools/run_card_tests.sh`、`tools/package*.sh`、`tools/build_fonts.py`、`.github/**`、`docs/cards/{DESIGN_cards,CARDS_INTERFACES,STATUS}.md`、`docs/cards/ownership.json`、`docs/cards/prototype/**`、`docs/cards/rogue/**`（肉鸽 v1 实现合同与三份提案）、`docs/handoff_cards/**`（任务卡、开场提示、交接板；执行方只读）、不在任务目录里的目录占位 `.gitkeep`（`data/cards/era/*/`、`data/cards/audio/`、`data/cards/minigames/obs/`）、`scripts/tests/cards/lib/**`、`data/cards/_examples/**`、`data/cards/_dev/**`、`data/cards/theme/palette.dev.json`、`tools/cards/audit/cjk_allowlist.json`、`tools/run_legacy_smoke.sh`，以及**所有已有文件**：`scripts/{core,sim,ui,town,audio,persona}/**`、`data/*.json`、`data/town/**`、`data/items/**`、`art/{bg,items,portraits,tools,ui,town}/**`、`audio/music/**`、`model/**`） | Claude | 已有代码只读、只调用；需要改开 `[shared]` issue |

**肉鸽 v1 的共享路径（2026-10-25，`ROGUE_V1.md` §10.12、§14.1）**：v1 期间 `ownership.json` 临时把别人的路径也挂在 RGx 名下（已有文件按 `_owner_of` 先匹配先赢，主人没变，只是 `check_pr_paths.py --task=RGx` 放行）：RG3 的 `data/cards/era/1938/tutorial.json`（只给 9 张教学牌的 `schedule` 加 `when`）、`data/cards/art/manifest.json`、`art/_placeholder/cards/manifest.json`、`art/ai/**` 与 `art/_placeholder/**` 里的 `relic.*` `curio.*` `ky.*`、`tools/cards/art/gen_ai_rogue.py`；RG4 的 `scripts/cards/ui/table/card_stage.gd`、`scripts/cards/ui/shell/card_title.gd`；RG5 的 `scripts/cards/ui/table/card_game_root.gd`、`scripts/cards/ui/dossier/dossier_book.gd`；RG6 的 `scripts/cards/sim/**`、`tools/cards/balance/**`、`docs/cards/balance/**`、`scripts/tests/cards/golden/golden.json`、`scripts/tests/cards/G06/test_no_deadlock.gd`、`data/cards/rules/balance_overrides.json`、`docs/cards/rogue/**`、本合同、`DESIGN_cards.md`、`ownership.json`；各 RGx 的 `data/cards/text_ai/ui/RGx.text.json`。**v1 合完后全部还给原主人**：K16、K12、C01、C16、C10、G06、G01 / AI 线（`text_ai/**` 本来就在 `ai_paths` 里）、Claude（`docs/cards/rogue/**` 记在 Claude 名下）。RGx 只留上表五行里它们自己新建的模块目录和数据文件；RG6 不再拥有路径（只剩默认的 `scripts/tests/cards/RG6/**` 与 `suites/RG6.txt`），同 X01 的先例。步骤 0 改过的 `scripts/cards/api/*.gd`、`core/card_validator.gd`、`core/card_composer.gd`、`loop/card_engine.gd`、`loop/loop_install.gd`、`ui/table/modal_host.gd`、`_schema/{relic,source}.json` 一直归原主人（Claude、G01、G02、C01），v1 内由编排一次改完（`ROGUE_V1.md` §10）。

### 2.3 共享资源的使用规则

- **已有代码只调用，不改**：`JevRng`、`PressureModel`、`WorldWheel`、`ItemGen`、`TownCond`（只借形状）、`ledger.gd`（`preload`，没有 class_name；G04 用 `card_ledger.gd` **继承**它、覆盖三个函数，§3.2 G04）、`appraise.gd`、`flaw_render.gd`（C12 只 `preload` 来算和画）、`UiStyle`、`TownUI`、`settings.gd`（构造时传路径，测试用自己的路径）、`modal.gd`。要它们加东西：`[shared]` issue。
- **只读来参考做法、不实例化、不拷文字**：`appraise_panel.gd`（C12 分出自己的 `spot_panel.gd`）、`scripts/town/guide.gd` 与 `data/town/onboarding.json`（C16 照它的挑步骤做法重写，旧文字是 AI 写的，不许拷）、`scripts/town/rules.gd` 与 `data/town/rules.json`、`scripts/town/help_panel.gd`（C10）、`scripts/town/pause_menu.gd`、`settings_panel.gd`（C16）、`scripts/core/protection.gd` 与 `data/town/protection.json`（G03：保护费的升级阶梯就是条子的前身）、`music_director.gd`（C16）、`data/codebook.json`（K11 只借码的形状，词由 A 重写）。
- **项目设置**：W0 由 Claude 加 autoload `CardBus="*res://scripts/cards/core/card_bus.gd"`；导出预设由 Claude 维护。**Steam 预设只含卡牌版，分两种出包变体**（§11.6，#202 / #212）：① **带 AI 声明版**（`Steam (AI Disclosure)`，自定义特性 `ship,ai_disclosure`；包含 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**` 及人工资源，运行时按 `human → ai` 查找）；② **不带声明版**（`Steam (No AI Disclosure)`，自定义特性 `ship,no_ai`；排除 `art/ai/*`、`audio/ai/*`、`data/cards/text_ai/*`，只用人工资源，缺的报错）。两者均把 `application/run/main_scene.ship` 覆盖成 `res://scenes/cards/CardGame.tscn`；只导出这个场景的依赖 + `data/cards/**`（运行时按路径读的数据）+ 白名单里的旧数据（`data/town/item_templates.json`、`data/cast.json`）；排除 `art/_placeholder/*`、`audio/_placeholder/*`、`data/cards/_examples/*`、`data/cards/_dev/*`、`data/cards/theme/palette.dev.json`、`data/cards/rules/wording.json`（K13 的措辞规则，开发用，中文在 `_` 键里）、`data/cards/branch/*`（解放后分支，首发不读）、`scripts/tests/*`、`tools/*`、`docs/*`，以及旧版目录 `scripts/town/*`（只放行 `scripts/town/settings.gd`：`CardSettings` 用它读写旧的四个设置键；框架版收尾补，主创可改）、`scenes/` 下非卡牌场景、`data/town/*`（模板除外）、`data/codebook.json`、`art/{bg,portraits,tools,ui,town}/*`、`audio/music/*`。开发预设照旧导出全部。任务不加 autoload、不加插件、不加 InputMap、不改渲染设置。
- **主入口**：W0 在 `scripts/ui/main.gd` 加命令行 `--cards`（直接进 `res://scenes/cards/CardGame.tscn`）；旧标题画面的“卡牌版”入口在 W2 由 Claude 加，**只在非发行版**（发行版主场景就是卡牌版，旧版不进包）。卡牌版自己的标题、暂停、设置在 C16。
- **sidecar 文件**：`.uid`、`.import` 跟着它的文件走，主人提交。

### 2.4 配色键（`data/cards/theme/palette.json` 人写；W0 的 `palette.dev.json` 是开发初值；界面只用键）

`paper` `paper_old` `ink` `ink_soft` `wood` `wood_mid` `wood_dark` `lamp` `seal` `gold` `gold_glow` `jade` `indigo` `mist` `good` `danger` `shade`（半透明遮罩） · 牌框：`frame_person` `frame_self` `frame_contact` `frame_event` `frame_fate` `frame_big_fate` `frame_demand` `frame_life` `frame_news` `frame_kept` `frame_estate` `frame_night` `frame_street` `frame_prison` `frame_gold` · 新手指引：`guide_glow` `guide_bubble` `guide_ink` · 画面（1.3）：`scene_void` `hud_bg` `hud_ink` `dialog_bg` `dialog_ink` `dialog_name` `dialog_me` `dialog_sys` `reply_bg` `reply_hover` `reply_ink` `reply_off` `tab_bg` `tab_on` `drawer_bg` `drawer_ink` `scrim` `btn_day` `btn_day_ready` `btn_day_confirm` `btn_day_night` `btn_day_ink` `night_tint` `night_dark` `candle_tint` `cold_tint` `warm_tint` `predawn` `lamp_glow` `rain` `fire_glow` `smoke` `seal_paper` `silhouette` `hero_ring` `guide_note`。
要新键：开 `[shared]` issue，Claude 在 `palette.dev.json` 里加开发初值，A 再在 `palette.json` 里定正式值。

### 2.5 标签文件与界面键文件（每个任务一份，互不冲突）

`data/cards/tags/K01.json`：
```json
{"_meta": {"owner": "K01", "schema": 1},
 "tags": {"boat": {"brief": "船、船工、码头"}, "pregnant": {"brief": "怀孕"}}}
```
`data/cards/ui_keys/C04.json`（键必须以本任务号小写开头）：
```json
{"_meta": {"owner": "C04", "schema": 1},
 "keys": {"c04.tier.harsh.pay": {"brief": "来当/来卖时的‘压价’按钮"},
          "c04.tier.kind.receive": {"brief": "来买时的‘厚道价’按钮（价低）"}}}
```
标签在任何一个标签文件里声明过就能用；两个文件声明同一个标签，校验器打 `NOTE:`（不算失败），以先读到的为准。引擎任务发出的提示文字键（告示、日结行、原因）同样登记在 `ui_keys/G0x.json`，键以 `g0x.` 开头。

- **数据里用到的原因键、告示键**（效果里的 `reason`、`notice.key`）：K 任务用**自己的**键 `k0x.reason.*`、`k0x.notice.*`，登记在自己的 `ui_keys/K0x.json`；不借用引擎任务的键（不然每条数据线都要等那条引擎线合并）。引擎自己产生的原因（利息、当本、查封……）才用 `g0x.*`。
- **征兆标签（封闭集合）**：`tags/W0.json` 定义 `omen_*` 家族，只有这些能用来做签和测字的匹配，加新家族走 `[api]` issue：`omen_official` 官面纸上 · `omen_water` 水边船码头 · `omen_far` 远方来信 · `omen_wealth` 财物进出 · `omen_illness` 病痛 · `omen_fire` 火光 · `omen_family` 家宅 · `omen_stranger` 生人 · `omen_dispute` 口舌官司 · `omen_road` 出行道路；另有 `bad_omen`（凶兆，原在 `tags/G05.json`，移到 W0）。每张 event、fate、person、life、news 至少带一个 `omen_*`（V34）；K10 的签 `hint_tags` 和测字的 `tags` 只用 `omen_*`。
- **例子集**（`data/cards/_examples/`）的键可以用任何前缀，登记在 `_examples/ui_keys.json`（W0）。

### 2.6 跨线改动

- **K13 不改别人的数据**（每个文件只有一个改它的任务，PR 路径检查不设特例）：审读问题写进 `docs/cards/review/<ID>.md`（逐条：牌 id、字段、规则、依据、建议改法——建议只针对 `brief` / `tags`，是给主人的说明，不是正文），对方 PR 合入并写了“交付”之后开 issue `[K13→K0x] …`；**数据的主人**在自己的分支 `cards/K0x-<slug>` 里改、在 PR 里逐条回应，K13 用 `wording_lint.py` 复查后在 issue 里确认关闭。那条线已经结束时，由 Claude 指派 `X##` 修补。
- **W2 的集成改动**：由 Claude 指派，PR 标题 `[X##] …`，在 PR 里写清楚碰了哪些不是自己的文件以及谁同意了。
- 其他任何跨线改动都走 issue。

---

## 3. 任务编号与 38 条任务（c）

### 3.1 编号

| 前缀 | 执行方 | 线数 | 管什么 |
|---|---|---|---|
| `G01`–`G06` | GPT | 6 | 引擎、后端、破产阶梯、数值 |
| `C01`–`C16` | Cursor | 16 | 界面场景、控件、小游戏、新手指引引擎、前端接入 |
| `K01`–`K16` | Grok | 16 | 牌的数据骨架（机制 + brief）、占位美术管线与美术规格、史实与敏感审读、QA 自动化、来源审核工具、新手指引步骤与规矩页骨架、解放后分支设计 |
| `K18` | Grok | 追加 | 收徒（§九.7，#182 第 3 条）。不改原来的 16 条线编号 |
| `W0` | Claude | — | 第 0 波骨架（附录 A），所有线从它切分支 |
| `X01`… | Claude 指派 | — | W2 集成修补、追加任务 |

分支名 `cards/<ID>-<slug>`，slug 用下表里的。每条线可以开多个 PR（先小后大），每个 PR 都过同一套检查。

每条任务都**默认拥有**：`scripts/tests/cards/<ID>/**`、`scripts/tests/cards/suites/<ID>.txt`、`data/cards/tags/<ID>.json`、`data/cards/ui_keys/<ID>.json`；下表的“归属”只列其余路径。“RNG”一列是允许用的随机数域（§6.3）。

**新手指引（红线 8，§7.10）**：引擎任务的卡片列出它必须发的 first-time 机制（`CardFirsts.mark`），验收都加一条：“自己发的每个 first 恰好一次；存→读之后不再发”。界面任务的卡片有“新手指引”一节：必须登记的锚点、必须发的 `ui_event`、测试里要证明会触发的指引步骤（§7.10.9）。数据任务确认教学要用到的牌。

### 3.2 GPT：引擎、后端、破产阶梯、数值（G01–G06）

#### G01 `core-model` · 卡牌模型、牌堆、发牌组合、存档、校验器、正文、总线、first-time 记录
- **范围**：CardDB（读全部牌文件、合并覆盖层与平衡覆盖、按类型/年代建牌库索引、人物登记 = `data/cast.json` + 各文件的 `persons` 块；**例子集和真数据是两套，一次只读其中一套**，§4.10）；CardValidator（§4.9 全部规则，三种模式，命令行 `validate_main.gd`，带 `--name=`；W0 已把 default 模式下是“错”的规则全做了，G01 补齐 NOTE/strict/ship 部分）；CardState（命名空间、`to_dict/from_dict/hash`，§6；哈希不含 `ui`、用全精度 JSON）；CardCtx 与五个登记表（ops/conds/mods/hooks/actions，§7.3）；CardPiles（区：手牌、留着的、人脉、条子、待办、弃牌；上限、过期、`keep`；**`order_hand()` 是手牌排序的唯一写法**，每次往手牌里加牌后调用，§10.2；留牌满了的溢出与 `card.discard`，§7.4）；CardComposer（每日发牌：日程 + 钉签 + 按权重抽 + 排序；`deal.json.scripted_days` 列出的日子不随机抽；每个牌库的抽牌计数存 `core.draw_k`；`project()` 只算不改；夜牌三选一；街头三张；各模式发什么见 §7.4.6 的矩阵）；CardSave（存/读/版本、按关存档路径、续玩点；存档根目录可设：`set_root()` 与 `new_game` 的 `save_dir`；指令日志放在存档信封里，不在状态里）；CardText（正文覆盖层、界面键、开发版草稿回退；【稿】字样读 `data/cards/_dev/strings.json`）；CardEventBus（§7.6 的信号；W0 已写好，签名冻结）；**CardFirsts**（`core.firsts`、`mark/all`、查询 `firsts`，§7.10.6）；新手指引的引擎一侧：`ui` 命名空间与指令 `ui.guide`，查询 `guide_data` `guide_progress` `guide_conds`。核心效果 op：`add_card` `remove_card` `waive` `extra_deal`。**打烊**（§7.4.7）：`day_end` 5 留牌溢出没选 → 扔掉新来的；`day_end` 20 生活牌留到明天/到期、手上能留的牌留着接着倒计时；这几行经修正项 `end_rows` 交；每种牌发几张加完修正项按 0 截断，`night_offers()` 也问 `deal_count {type: "night"}`（在牢里过夜时 G06 用它把夜牌、街头牌减到 0）；校验 V37。**1.3**：`data/cards/_schema/` 的 person event fate big_fate life news street prison demand night pawn_ticket 加可选属性 `stage`；校验器对带 `stage` 的牌调 `CardDslShapes.check_stage` 报 V38–V41，补 V39 的登记部分、V42、V27 的新内容（演出拍子引用的正文、`w0.stage.*`、群演名字）和 V30 的改名提示（§4.9）。这一步是一个小 PR，10-15 前合入（K 线的演出块等它）。
- **归属**：`scripts/cards/core/**`，`data/cards/_schema/**`，`data/cards/rules/deal.json`。
- **依赖**：W0。
- **RNG**：`c.deal.*`。
- **first-time**：`deal` `person` `keep` `kept_expire` `kept_full` `life` `news`（什么时候算“第一次”见 §7.10.10）。
- **验收**：校验器对 `_examples` 全绿，对每条规则各有一个反例夹具会报 `DATA ERROR`；同种子同状态 `compose()` 两次结果相同，`project(d)` 与第 d 天实际发的随机部分一致（无新钉签、状态不变时）；同一天加发（`extra_deal`）后存→读再加发，不会重复同一抽；脚本日不抽随机牌；钉住的牌一定发（名额满了就多发一张）；存→读→哈希相同；`find_floats(state)` 为空（状态里一个浮点数都没有）；所有区的上限与过期按 `deal.json`；任何插入之后手牌顺序都符合 §10.2；留牌满了再进一张走溢出流程；自己发的每个 first 恰好一次，存→读后不再发；改 `ui` 不改哈希、`ui.guide` 不进指令日志；打烊时自己那几行（溢出、生活牌、能留的牌）预览 = 结算；性能见 §12.4。

#### G02 `loop-engine` · 门面 CardEngine、日/周/月/年状态机、日程、金色牌、目标、跳年、视图
- **范围**：CardEngine（实现 CardEngineApi；指令/查询分发；`busy` 防重入；把 `ctx.out` 里的可见事件按序发到 bus，**然后发 `command_done`，最后一条 `view_changed`**；指令日志交给 CardSave 放进存档信封）；CardDayLoop（阶段：`boot→month_open→morning→day→night→settle→(morning…)→month_close→year_jump→month_open…`，以及 `game_over`、`branch_pick`；`request_panel()`、`set_mode()` 给别的模块调用——`loop` 命名空间只有 G02 写）；CardCalendar（真实公历日期、星期、**集市日只按 `stages.json` 的 `market_every`/`market_offset` 算**、钟点显示）；CardSchedule（`schedule` 字段的主线牌、教学牌（K16 的 `tutorial.json`）、每周生活牌插入：几张 `c.sched.life.n`、哪天 `c.sched.life.day`、哪张 `c.sched.life.pick`；生活牌不排在脚本日）；CardGoldRule（§10；只提供手牌排序的子键 `hand_sub` 和打烊时金色牌走掉，不自己挪手牌）；**打烊 · 下一天**（§7.4.7：`day.end` 任何阶段往前走一步、查询 `day.end_preview`、合并各模块经 `end_rows` 交的清单、`day_end` 10 结算人物/事件/命运/街头/大赌/今天的机会、月初替玩家转本月运势、不卡死不变式）；CardGoals（1 主线 + 2 可选，月底结算 `done_when`，评语档）；CardYearJump（调各模块的跳年钩子、人脉跨年变化）；按关自动存档 + 续玩点 + 重来本关（读档、重来时保留当前的 `ui`，§7.10.6）；CardViewModel（§7.5 视图与隐藏键黑名单；各模块经修正项 `view_section` / `card_view_part` 交来自己那一块，G02 只合并、跑泄露检查）。效果 op：`goal` `game_over`；条件 op：`day_gte` `abs_day_gte` `weekday` `era` `stage_gte` `mode` `phase` `goal_status`。界面键：告示行、日结行、月底的评语（`g02.month.verdict.*`）、局终与首发结尾（`g02.ending.*`）。**1.3**：视图加 `stage {set, time, sealed}`（§7.5；`loop.json` 新键 `dusk_pct`）；CardView 加 `stage`（定义里的演出块去掉 `brief`）与 `source`（消息牌）；`night_offers` 的元素改成 `{def, art, choices}`；测试 `G02_stage_view`。
- **归属**：`scripts/cards/loop/**`，`data/cards/rules/{loop,stages,goals_rules}.json`。
- **依赖**：W0（对着 G01/G03/G04/G05/G06 的桩开发）。
- **RNG**：`c.sched.*` `c.goal.*` `c.year.*`。
- **first-time**：`notice` `month_open` `gold` `gold_leave` `must_resolve` `night` `settle` `month_close` `year_jump` `game_over` `retry` `resume` `branch_pick`（预留）。
- **验收**：用桩或真模块无头跑完三关（每关 30 天）不卡死；`day.end` 的“未处理清单 + 确认”（§7.4.7：每个阶段都前进、预览 = 结算、没确认只记 first）与金色牌走掉；金色牌过期 → `story` 记“没理他”+ 档案缺口；视图递归检查没有任何 §7.5 的隐藏键；按关存档后“重来本关”状态哈希等于当时（第一次重来会在读回来的状态上记 `core.firsts.retry`，比较时去掉 `core.firsts` 里的 `retry` / `resume` 两项，或在第一次重来之后再比；§7.10.6）；`view()` 对同一状态永远输出同一结果；每条指令（`ui.*` 除外）的事件以 `command_done`、`view_changed` 收尾；某个模块的视图字段改了，G02 的代码不用动；自己发的每个 first 恰好一次，存→读后不再发。

#### G03 `slots-dsl` · 放格子与掷铜钱、效果/条件 DSL、属性与三项名声、条子、档案簿
- **范围**：CardOps / CardConds 的执行与形状校验（§5；形状函数用 W0 的 `dsl_shapes.gd`，不另写一套）；核心效果与条件 op（§5.2、§5.3 里归 G03 的全部）；CardSlots（能不能放、放、拿出、预览、掷）；CardCoins（`c.coin`）；CardChoices（选项、选项里的检定；条子的几种办法也是选项：保留 id `pay` `haggle` `substitute` `fabricate` `send_person` `inform`，§4.7.6）；CardMeters（口碑、风声、本心、属性；档位；风声到顶 → `arrest`；档位文字键 `g03.tier.rep.0`–`g03.tier.rep.4`、`g03.tier.heat.0`–`g03.tier.heat.4` 登记在 `ui_keys/G03.json`）；CardKeptRules（留着的牌进格子的加成、风险）；CardDemands（条子：每周一发、七天、拖一拖、按类结算、按档吃亏阶梯；参考 `scripts/core/protection.gd` 里保护费的升级阶梯，只读）；CardDossier（碎片、缺口、一年后、补齐解锁）。修正项提供：`coins`、`patience_pct`、`appraise_pct`（人脉被动，如陈文庭“书画药材线索更清楚”）、`view_section`（名声档位、人脉、条子那几块）。**打烊**（§7.4.7）：`day_end` 6 人脉满了没选 → 新来的不留、格子里放了还没掷的还回来；条子在清单里的行（`end_rows`）；人脉满了时 `request_panel("contacts_full", {new_uid})`（关面板 = 新来的不留）。**1.3**：`card_view_part` 给条子加 `demand {kind, tier}`。
- **归属**：`scripts/cards/rules/**`，`data/cards/rules/{slots,meters,demand_rules}.json`。
- **依赖**：W0。
- **RNG**：`c.coin` `c.demand.*`。
- **first-time**：`choice` `slots` `coins` `demand` `demand_delay` `demand_people_return` `demand_inform` `demand_fabricate` `demand_fail` `dossier` `dossier_gap` `year_after` `contact` `contacts_full` `tier_rep` `tier_heat` `person_state` `kept_risk` `office`（K17：带 office 标签的牌第一次发到手上） `scare`（K18：1940 起留着枪时，发到普通客人记一次）。
- **验收**：§5 每个归 G03 的 op 都有单测（含形状错误）；铜钱数 = 属性点 + 钱/档 + 物品 + 留牌，`auto_pass` 与 `heads` 正确；同一人一天只能放一次；同一天两个 `coin_check` 掷出的是不同的铜钱（来源路径不同，§5.1）；条子 7 天到期、拖一拖 +3 天升一档、四档吃亏阶梯；六种条子办法都经 `card.choose` 走通；要消息条子交出消息 → 执行那张消息的 `on_inform`；档案簿缺口不能再补；打烊时人脉满没选、格子没掷的处理对，条子行的天数与 `days_left` 一致；自己发的每个 first 恰好一次，存→读后不再发。

#### G04 `economy` · 柜台、货架、当票、鉴定桥、物品、货币、月账
- **范围**：CardCounter（当/卖/买/赎/拒，三档价 `harsh/fair/kind`，客人接受/还价/走，最多 5 轮；人物牌上的 `choices`（例：外乡人“白给他几个钱”）在柜台上作为额外按钮，经 `card.choose` 交给 G03；来赎四种：照规矩 `by_rule`、刁难 `squeeze`、东西已经被你卖了时赔钱 `compensate` 或去买回来 `buy_back`）；CardPricing（三档价只从客人报价和“看得见的估计”算，不露真值）；CardCustomer（隐藏底线、耐心分钟数；小游戏和讲价扣耐心）；CardShelf（上限、价格修正、只能卖给来买的人）；CardTickets（用 **`scripts/cards/economy/card_ledger.gd`**：`extends "res://scripts/core/ledger.gd"`，不写 `class_name`，覆盖 `open_pawn`、`redeem_amount`、`tick_contracts`——月息用整数 `rate_pct`、保管费 `storage_permille`、当票号是整数、合同 id 是 ASCII `t%04d`、原因码是 ASCII、宽限天数读 `economy.json`；倒计时、赎当、刁难、提前卖了要赔；跨年满当；外来当票 `tk.*` 只记录不动钱）；CardAppraisal（挑小游戏：牌上写了 `minigame` 就用它，否则 `c.mg.pick`；把物品真值换成**物理参数**和证据的样子，`spot` 只给布局（§8.2），真货假货的证据**数量同分布**（痕迹几处、在哪个部位、一摞几枚都一样，只有样子不同）；**这一回的答案只记在 `econ.appraisals[uid].answer`**（私账：不进参数、视图、查询、事件、`report` 的返回值）；收观察：观察是玩家的判断，按 `quality_permille` × 修正项 `appraise_pct` 定清晰度，再按目录的 `fidelity`/`hedge`（§4.8）记下，**不按对错过滤**；静态 `CardAppraisal.judge(kind, answer, result) -> {right, wrong, soft}` 对答案，只进私账；**说破**（Level B，主创 10-25）：来当/来卖的会话里第一次没放弃的 `report` 结算一次——说中了真破绽客人改口让价（`asking`、`floor` 往下），冤枉了客人他不服（耐心掉一截、`floor` 往上抬，不扣口碑），只说中旧痕之类客人稍让；只改会话的 `asking` `floor` `patience`，看得见的只有客人一句话（`line_key` = `g04.counter.lever.<caught|soft|offended>`，下一条指令清掉；人物牌可用自己的 `lines.caught` 等覆盖）和改过的开价；没有客人的文书（当票、信、电报）不结算说破，记 `econ.readings[<牌 def id>] = right/partial/wrong`（条件 op `mg_read`，主线这一版不按它分剧情）；眼力 `CardMeters.attr(ctx, "ruhua", &"eye")` 和懂行的人脉（`appraise_pct` 高于 `economy.json` 的 `appraise.expert_pct`）换成参数里的辅助字段（§8.2）；扣耐心）；CardItems（`ItemGen.generate` + `data/town/item_templates.json` + K11 的 `templates_extra.json`；**进状态的只有清洗过的整数字段**——`condition_permille` 等，不存 ItemGen 的浮点和中文名、不存它的原始缓存，§6.1）；CardCurrency（换币、物价指数）；CardMonthAccounts（月底：开销、当票清点；抵押利息归 G06）。`pay` 付不起且 `short: "ladder"` 时触发钩子 `money_short`，阶梯由 G06 接手。效果 op 与条件 op 见 §5 里归 G04 的。**打烊**（§7.4.7）：`day_end` 8 关掉开着的柜台会话（不算成交）；来赎的人没接：当票照旧（之后按 `c.redeem.come` 还可能再来）；`shop_closed` op 也给 G06 的牢房用（牢里过夜的第二天铺子关门）。
- **归属**：`scripts/cards/economy/**`，`data/cards/rules/{economy,currency,items_balance}.json`。
- **依赖**：W0；物品参数依赖 K11 的数据（对着 `_examples` 先做）。
- **RNG**：`c.cust.*` `c.redeem.*` `c.mg.pick` `c.mg.param`（键第三位可以是 `"<名>.<序号>"`；没物品的文书用 `"doc:<def id>"` 代替空物品 id，§6.3），以及 ItemGen 自带的 `item_*` 域（键第一个元素固定为 `"c"`）。
- **first-time**：`counter` `mg.spot` `mg.coin_ring` `mg.weigh` `mg.fragments` `mg.decode` `ticket` `shelf` `buyer` `redeem` `shop_closed` `currency`（预留：首发三关不换币）。
- **验收**：账本守恒（`ledger.check_invariants()` 三关浸泡测试为空，换币时同步调整总量）；三档价、还价、耐心走人；传给小游戏的参数递归检查没有 §8.2 的禁用键（**没有例外**，`spot` 也一样）；首饰柜押出后（G06 提供 `intake_blocked`）来当首饰的被挡（客人说铺子不收）；当票号是整数、合同 id 是 ASCII、`econ` 里没有浮点和中文；赎当四种办法；人物牌的选项在柜台上走得通；教学客人牌上的 `minigame` 一定生效；自己发的每个 first 恰好一次，存→读后不再发。鉴定（主创 10-25）：答案不出私账；500 件真货和 500 件假货的痕迹数、部位、一摞枚数同分布；每个称分量模板的声称区间两端都压得平；`judge` 表驱动；说破每个会话只结算一次、放弃的不结算；乱点不占便宜（全说“不一样”在真货上是冤枉、在假货上不算识破）；没有 `hedge` 的老目录照旧；老小游戏（不交新 measures）不结算、不报错。

#### G05 `fate-fortune` · 牌库权重、命运与大命运、命运轮盘、求签测字、黄历
- **范围**：CardWeights（每个牌库每张牌的整数权重：基础权重 × 年代 × 口碑/风声档 × 天气/集市 × 本月运势 × 临时修正 × 家当修正（G06 的 `pool_rows` 修正项））；CardFateTrigger（命运牌频率；危机检测 → 发 `bf.wheel`（大命运**只发这一张**；其他 `bf.*` 一律 `weight: 0`，只由扇区效果发到手上），每关上限、同一危机一次）；CardWheel（§9.1–9.2：扇区（段的 `conditions` 转的时候查）、香案加宽、代价与押牌、转、结果；按 `<轮盘>:<牌 uid>` 分开记）；CardFortune（§9.3：求签读未来发牌、挑牌、定等第、选签、钉签；测字，“无”的读法给窗口加禁签）；CardAlmanac（§9.4：每天宜忌、记录当天做过的事、照做奖励）；CardPins（钉签、禁签与替身）；CardPressure（复用 `PressureModel.step` / `WorldWheel.spin` 做时局压力、天气；**集市日不由 G05 抽**，读 G02 的 `CardCalendar.is_market_day`）。效果 op：`deck_mod` `fate_now` `big_wheel` `wheel_offer` `pressure` `weather` `peek`；条件 op：`weather` `market_day`（读日历）`pressure_gte` `fortune` `almanac_yi`。**打烊**（§7.4.7）：`day_end` 15 `bf.wheel` 没处理就作废（计入本关次数、这种危机算用过，不补发）、开着没转的轮盘把香案上的东西和押的牌还回来；`bf.wheel` 那一行经 `end_rows` 交；月初没转的本月运势由 G02 调 `CardWheel.spin` 替玩家转。**1.3**：`card_view_part` 加 `wheel`（这张牌开哪个轮盘）与 `fortune`（`opens_fortune`）。
- **归属**：`scripts/cards/fate/**`，`data/cards/rules/{weights,fate,pressures,daily_wheels,fortune}.json`。
- **依赖**：W0；G01 的 `project()`（对着桩先做，桩的 `project()` 可用）。
- **RNG**：`c.fate.*` `c.wheel.*` `c.lot.*` `c.cezi.*` `c.almanac`，以及经 PressureModel/WorldWheel 的 `pressure:c_*` `wheel:c_climate`。
- **first-time**：`month_wheel` `incense` `fate` `big_wheel` `fair_wheel` `gamble_wheel` `wheel_stake` `almanac` `lot` `cezi` `market_day` `weather`。
- **验收**：签的准确性：1000 个种子 × 每个求 3 次签，签里写到的牌 100% 在窗口内发出（或同征兆的替身）；测字“无”的读法在窗口内保持为真；香案放得越多好扇区越宽（单调），停针角度落在抽中扇区内；视图里没有权重、没有百分比、没有扇区好坏；本心低时挑坏牌的比例显著更高（统计测试）；段的 `conditions` 不满足时这一段不上盘；押的牌落在坏段没了、其他段还回来；两张同种轮盘牌各转各的；`bf.wheel` 没处理就作废、不补发，没转的轮盘退还香案与押牌；黄历奖励只在“做了宜、没做忌”时给；自己发的每个 first 恰好一次，存→读后不再发。

#### G06 `ladder-autoplay` · 破产阶梯（家当与抵押、钱不够、街头、牢房）、无头自动玩、蒙特卡洛平衡、黄金种子、性能基准
- **范围**：**破产阶梯**（`scripts/cards/ladder/**`，安装顺序在 economy 之后：`CardLadderInstall`）：CardMortgage（五件家当、利息、赎回、押出后少的本事——作为修正项 `cap` `deal_count` `intake_blocked` `pool_rows` 的提供者；铺面月底赎不回 → 街头）；CardShortLadder（“钱不够”阶梯：听 `money_short` 钩子 → `CardDayLoop.request_panel(ctx, "short", …)` → `short.resolve`，先卖货/拿货抵 → 押家当 → 街头）；CardStreet（街头模式、每天 3 张、攒钱赎回铺面）；CardPrison（被抓 → 牢房牌进手牌；没处理就在牢里多待一晚——第二天铺子关门、不发人物牌、街头牌和夜牌；连续 `ladder.json.prison.max_days`（起步 3【待调】）晚没出来按打点失败 → `game_over`，§7.4.7）；打烊时 `day_end` 7 钱不够没选 → 认了、25 牢房，这两行经 `end_rows` 交。效果 op：`arrest` `estate_seize`；条件 op：`estate_status`；指令：`estate.mortgage` `estate.redeem` `short.resolve` `street.redeem_shop`；查询：`estates` `short`。**自动玩与平衡**：CardAutoplay（只用 `send()`/`view()`/`query()`；卡住时用 `day.end {confirm: true}` 往前走）；**不卡死模糊测试** `G06_no_deadlock`（§7.4.7 第 4 条，≥ 1000 局）；策略 `fair` `greedy` `kind` `random` `refuser` `wheel` `hoarder`（§12.6）；命令行 `scripts/cards/sim/balance_main.gd`（多种子 × 策略 × 关，`JOBS` 并行由 `tools/cards/balance/run.sh` 拆进程）；报告 `docs/cards/balance/report_<日期>.md` + `.json`；平衡覆盖 `data/cards/rules/balance_overrides.json`（只改数，不改结构）；黄金种子回放（§12.5）；性能基准。
- **归属**：`scripts/cards/ladder/**`，`data/cards/rules/ladder.json`，`scripts/cards/sim/**`，`data/cards/rules/balance_overrides.json`，`scripts/tests/cards/golden/**`，`docs/cards/balance/**`，`tools/cards/balance/**`。
- **依赖**：W1 对着桩搭阶梯和自动玩框架；W2 用真引擎和 K 数据出报告。
- **RNG**：`c.street.*` `c.prison.*` `c.ai.*`。
- **first-time**：`money_short` `mortgage` `street` `prison`。
- **验收**：钱不够阶梯按“先卖货/拿货抵 → 押家当 → 街头”走；`short` 面板的参数（§7.4.5）齐；铺面月底赎不回 → 街头 → 攒够钱回来；牢房失败 → `game_over`；首饰柜押出后 `intake_blocked` 为真；所有策略三关跑完不卡死（`refuser` 也能走到月底或体面地结束）；`G06_no_deadlock` ≥ 1000 局随机乱点 + 随机打烊不卡死；牢房没处理多待一晚、到期按打点失败；钱不够没选时打烊按认了；报告含 §12.6 的全部指标；黄金种子在同一提交上可复现；平衡覆盖只覆盖已有键（校验器会查）；自己发的每个 first 恰好一次，存→读后不再发。

### 3.3 Cursor：界面、控件、小游戏、新手指引、前端接入（C01–C16）

所有界面任务的共同要求：面板继承 `CardPanel`（§7.8）；只调用 `engine.send/query/view`，只听 CardBus（自己只**发** `ui_event`）；文字全走 `CardText`，颜色全走 `CardTheme`，图全走 `CardArt`；每个面板实现 `autoplay_step()`；在自己的夹具上能独立跑（`MockCardEngine`）；测试里断言发出的指令（`mock.sent`）；`.gd` 和 `.tscn` 里都没有中文。

**每个界面任务的“新手指引”一节**写着三样东西（总表 §7.10.5）：① 必须用 `CardAnchors.register()` 登记的锚点；② 必须发的 `ui_event`；③ 测试里要证明会触发的指引步骤（§7.10.10）。测试统一这样做：用自己的夹具打开面板/牌桌后，断言自己的每个锚点 `CardAnchors.has()` 为真、`rect()` 非空且整块在 1280×720 里；用总线监听断言列出的 `ui_event` 发出来了；把 C16 的 `CardGuide`（W0 有可用的桩）`force(true)` 挂上，发出对应的 `first_time` 后 `evaluate_now()`，断言 `active_step()` 就是那一步。W1 用自己测试目录里的测试步骤（`load_steps()`，锚点和机制名用真的）；W2 换成 K16 的 `steps.json` 再跑一遍。

#### C01 `table` · 画面根、场景层、HUD、两侧标签与抽屉宿主、打烊按钮、叠层与小游戏宿主、指引宿主、配色
- **范围**：`CardGame.tscn`（CardGameRoot：选引擎、标题、按阶段和 `view.open_panel` 开面板、打出一张牌的路由 §7.11.4、热点的路由 §7.11.9、键盘 §1.2）；`CardStage` 场景层（§7.11.3）；HUD（§7.11.10，嵌 C07 的黄历条）；两侧标签与抽屉宿主（§7.11.8）；`CardModalHost` 按 §7.8 的“呈现”分三路（演出层、抽屉、叠层），一次只演一出；“打烊 · 下一天”（§7.11.11）；`CardMiniGameHost`；指引宿主（CanvasLayer 100）；`CardTheme`；街头时摆 C11 的街头层；摆 C02 的手牌扇与头像、C03 的柜台格子、C04 的对话框（都用 `CardIds.widget_scene()`）。
- **归属**：`scenes/cards/CardGame.tscn`、`scenes/cards/table/**`、`scripts/cards/ui/table/**`、`scripts/cards/ui/common/card_theme.gd`。
- **依赖**：W0（CardWidget/SlotWidget/嵌入控件的桩、GuideOverlay 桩）。
- **新手指引**：锚点 `a.top.date` `a.top.weather` `a.top.money` `a.top.rep` `a.top.heat` `a.btn.close_day`、场景 `a.scene` `a.scene.customer` `a.scene.notice` `a.scene.ledger` `a.scene.notebook` `a.scene.calendar` `a.scene.cashbox` `a.scene.magnifier` `a.scene.notewall`、标签 `a.tab.contacts` `a.tab.demands` `a.tab.dossier` `a.tab.rules` `a.tab.shelf` `a.tab.tickets` `a.tab.estates` `a.tab.settings`（1.3；`a.hand` `a.hand.gold` 改归 C02，7 个旧名见 §7.10.5 的改名表）；`ui_event`：`panel_opened {kind, show}` `panel_closed {kind, show}`（宿主：演出、抽屉、叠层都发）、`drawer_opened {kind, side}` `drawer_closed {kind, side}`、`hotspot_pressed {id}`（`hand_selected` 改由 C02 发）；要证明的步骤：告示 `gd.d1.notice`（`a.scene.notice`）、口碑风声档位 `gd.tiers`、打烊 `gd.d1.close`、集市与天气 `gd.market_day` `gd.weather`、当票 `gd.d1.ticket`（`a.scene.ledger`）、货架 `gd.d1.shelf`（`a.tab.shelf`）、回看规矩 `gd.d2.rules`（`a.tab.rules`）、档案簿 `gd.dossier`（`a.scene.notebook`）、条子 `gd.demand`（`a.scene.notewall`）、查封 `gd.shop_closed`（`a.scene.notice`）、`gd.retry` `gd.resume`（`a.top.date`）（预留的 `gd.currency` 首发不证；`gd.d1.deal` `gd.contact` `gd.kept_expire` `gd.kept_risk` `gd.person_state` 改由 C02 证明）。
- **验收**：十个基础夹具（附录 A）每个都能打开、截图无重叠；9 张手牌不出界；每种面板 kind 都能开（缺场景时占位）；键盘全流程；F1 在每个夹具里都能开帮助、Esc 关；GuideOverlay 在最上层且点击能穿过它点到手牌；没有一处中文字面量或颜色字面量。

#### C02 `card-widget` · 牌、牌框、金色牌、留牌标记、放大、拖拽、美术解析、手牌扇、英雄头像与人脉小牌
- **范围**：CardWidget（所有牌种的正面/背面；牌框按类型；**金色牌框 + 微光**；今天要了断（`must_resolve`）的小红点；留着的牌右上角剩几天（`expires_in`）；“这人今天用过了”的灰态；选中放大到 288×400（1.3：1.2 的“悬停放大副本”作废——手牌扇里悬停是抬起，选中才放大，由扇做）；拖拽源 `{"kind":"card","uid":…}`；显示草稿正文时的草稿样式）；CardArt（美术 id → 正式图 → 占位图 → 缺图方块，读 `data/cards/art/manifest.json`；有正式牌框图时用 9 宫格贴图，没有用 StyleBox + 调色板键）。CardHandFan 与 CardHeroBar（§7.11.6）：炉石式扇形、悬停抬起、选中放大与“打出”、拖进画面、留着的牌在扇里带“留”角标、夜里扇里是夜牌与“睡了”；英雄头像、人脉小牌（拖进格子）。
- **归属**：`scenes/cards/card/**`、`scripts/cards/ui/card/**`。
- **依赖**：W0。
- **新手指引**：每个 CardWidget 在 `set_card()` 时登记 `a.card@<uid>`，有“留着”动作的登记 `a.card.keep@<uid>`，有剩几天角标的登记 `a.card.days@<uid>`，金色牌登记 `a.card.gold@<uid>`（换牌、出树时自动注销）；**1.3** 加上手牌扇与头像的 `a.hand`（整排扇的外框）`a.hand.gold`（这两个从 C01 接过来）`a.hand.kept` `a.hand.preview` `a.hero` `a.contacts`；`ui_event`：`hand_selected {uid}`（从 C01 接过来）`hand_played {uid, def, how}`（1.3）`card_zoomed {uid}` `card_drag_started {uid, zone}`（`zone` 可以是 `hand` `kept` `contacts` `self`）；要证明的步骤：人物牌 `gd.d1.person`、金色牌 `gd.d2.gold`、留牌与过期 `gd.d2.keep` `gd.kept_expire`；以及主锚点是 `a.card@{uid}` / `a.card.days@{uid}` 的 `gd.life` `gd.news` `gd.fate` `gd.demand_people` `gd.big_wheel`；1.3 起再加发牌与手牌 `gd.d1.deal`（`a.hand`）、人脉 `gd.contact`（`a.contacts`）、带风险的留牌 `gd.kept_risk`（`a.hand.kept`）、人的状态 `gd.person_state`（`a.contacts`，备用 `a.hero`）。
- **验收**：§4 的每个例子渲染成牌（截图拼表）；三种尺寸整数倍；金色牌一眼能认；拖拽数据格式对；没有 `%`。

#### C03 `slots-coins` · 柜台上的格子与铜钱、选项与检定的演出、消息/当票的演出、人脉抽屉、人脉满、留牌满
- **范围**：`CardSlotPanel`（stage：有选项或格子的牌、求助/打听/主线来意、事件/命运/生活/大赌/街头；read：消息、当票）照 §7.11.4 演：选项是回话、格子在柜台上；`CardCounterChecks`（§7.11.7）；`CardSlotWidget`、`CardCoinTossView`（冻结接口不变，摆到柜台上）；`CardContactsDrawer`（人脉抽屉：你、人脉、留着的牌的本事与状态，拖出去放格子）；`CardContactsFull`、`CardKeptFull`（叠层，做法不变）。
- **归属**：`scenes/cards/slots/**`、`scripts/cards/ui/slots/**`。
- **依赖**：W0（SlotWidget 公共接口已冻结在 W0 桩里）。
- **新手指引**：锚点 `a.slots.first`（柜台上第一个格子）`a.slots.coins`（铜钱那一排）`a.slots.roll` `a.slots.money` `a.slots.choices` `a.slots.release`（人脉满）`a.slots.discard`（留牌满）；`ui_event`：`slot_drop {uid, slot, kind}`（由 SlotWidget 自己发，所以复用它的 C05/C06/C11 也会发）；要证明的步骤：放格子与掷铜钱 `gd.slots` `gd.coins`、选项 `gd.choice`、人脉满 `gd.contacts_full`、留牌满 `gd.kept_full`。
- **验收**：放人、放钱、放留着的牌、放物品、放消息五种来源；引擎拒绝时显示原因键的正文；掷完动画的正反和引擎结果一致；跳过动画不丢结果；留牌满的两种结束方式都发 `card.discard`。

#### C04 `counter` · 对话框、柜台的演出（当、卖、买、赎与人物牌的选项）、货架与当票抽屉
- **范围**：`CardDialogBox`（§7.11.5）；`CardCounterPanel`（stage）：客人进门、开口、东西摆上柜台、三档价/不收/细看/选项/回头再说是回话、客人的回话是对话（台词键 `lines.*`）；来买时开 `shelf` 抽屉挑一件；来赎带当票道具；`CardShelfDrawer`（货架：只读，来买时挑一件）；`CardTicketsDrawer`（当票：号、东西、当本、剩几天）。
- **归属**：`scenes/cards/counter/**`、`scripts/cards/ui/counter/**`。
- **依赖**：W0；小游戏由 C01 的宿主打开。
- **新手指引**：锚点 `a.counter.item` `a.counter.look` `a.counter.tier.harsh` `a.counter.tier.fair` `a.counter.tier.kind` `a.counter.reply` `a.counter.stock` `a.counter.redeem`，1.3 加 `a.dialog` `a.dialog.next` `a.shelf.list` `a.tickets.list`；`ui_event`（1.3）：`dialog_advanced {uid}` `dialog_skipped {uid}` `reply_chosen {uid, reply}`；要证明的步骤：看看东西 `gd.d1.look`、三档出价 `gd.d1.tiers`、来买与货架 `gd.d1.buyer`、来赎 `gd.redeem`（当票 `gd.d1.ticket` 用 C01 的 `a.scene.ledger`）。
- **验收**：当、卖、买、赎各一条夹具走通，另有带选项的人物牌一条；任何时候界面上没有底价、真假、估价区间；最多 5 轮后体面结束。

#### C05 `demand` · 条子板与条子面板
- **范围**：`CardDemandsDrawer`（左抽屉，嵌 `CardDemandBoard`）；`CardDemandPanel`（stage）：胡二进门、条子拍在柜台上、办法是回话、格子在柜台上、拖一拖是回话。
- **归属**：`scenes/cards/demand/**`、`scripts/cards/ui/demand/**`。
- **依赖**：W0、C03 的 SlotWidget（用 W0 桩先做）。
- **新手指引**：锚点 `a.demand.board` `a.demand.days` `a.demand.tier` `a.demand.modes` `a.demand.delay`；要证明的步骤：拖一拖 `gd.demand_delay`、要人回来的检定 `gd.demand_people`、交消息与编一个 `gd.demand_inform`、没办成 `gd.demand_fail`（条子与七天 `gd.demand` 1.3 起由 C01 证，锚点成了 `a.scene.notewall`）。
- **验收**：四类条子各一条夹具；六种办法的指令参数对；拖一拖后天数和档位字更新；没办成时的结果显示；条子上显示当前办法要交的钱（CardView `amount`，§7.5），自动放钱只放这么多（#73）。

#### C06 `wheel` · 命运轮盘面板（本月运势、大轮盘、庙会/赌摊）
- **范围**：CardWheelPanel：按 `arc_deg` 画扇区（扇区图标/字来自段的美术和正文），指针；香案格（SlotWidget，放钱/留着的牌/人脉，放了以后扇区**动画变宽**）；代价（花钱、押一张留着的牌 → `wheel.stake`）；转：`wheel.spin` → 按 `stop_deg` 缓停 → 揭晓段的正文；大轮盘换更凶的皮。所有轮盘指令都带 `uid`（本月运势为 `""`，§7.4）。面板随时能关（香案上的东西留着，转之前都能拿回来）；本月运势没转就关了，牌桌上按“打烊 · 下一天”会替玩家转（§7.4.7）。1.3：轮盘仍是叠层；画面在叠层下面照常（轮盘牌的演出块可换城隍庙背景，由 C01 在开面板时让场景层先演）。
- **归属**：`scenes/cards/wheel/**`、`scripts/cards/ui/wheel/**`。
- **依赖**：W0、C03 桩。
- **新手指引**：锚点 `a.wheel.face` `a.wheel.incense` `a.wheel.cost` `a.wheel.spin`；要证明的步骤：本月运势与香案 `gd.m.wheel` `gd.m.incense`、大轮盘 `gd.big_wheel`、庙会/赌摊与押牌 `gd.fair_wheel` `gd.gamble_wheel`。
- **验收**：停针角度和引擎结果一致（测试读节点旋转）；界面上没有任何数字；三种轮盘各一条夹具，另有押牌一条。

#### C07 `fortune` · 黄历条、算命摊、求签、测字
- **范围**：`CardAlmanacStrip`（HUD 里一行 260×24）；`CardAlmanacDrawer`（右抽屉：今天的宜忌和做过的小勾、本月运势段名、求过的签）；`CardFortunePanel`（stage）：算命先生进门，求签/测字/不算是回话，签诗与解曰、测字的话在对话框里说，测字的字是一排回话。
- **归属**：`scenes/cards/fortune/**`、`scripts/cards/ui/fortune/**`。
- **依赖**：W0。
- **新手指引**：锚点 `a.almanac` `a.fortune.lot` `a.fortune.cezi` `a.fortune.chars`；要证明的步骤：黄历宜忌 `gd.almanac`、求签 `gd.lot`、测字 `gd.cezi`。
- **验收**：签文正文只来自 CardText；界面上不出现“几天后会发哪张牌”的任何直接信息。

#### C08 `night-settle` · 打烊确认、夜牌、日结
- **范围**：`CardEndDayConfirm`（叠层，做法不变）；`CardNightPanel`（stage）：打烊后的夜里柜台，手牌扇里是夜牌与“睡了”，打出一张 = `night.choose`，带选项的夜牌的选项是回话；`CardSettlePanel`（stage）：日结的每一行在对话框里说，手牌收下去，天亮 = `settle.next`。
- **归属**：`scenes/cards/night/**`、`scripts/cards/ui/night/**`。
- **新手指引**：锚点 `a.endday.blocked`（确认面板里的清单）`a.endday.gold_leave`（清单里金色牌那一行）`a.night.offers` `a.settle.lines`；要证明的步骤：没处理的会怎样 `gd.must`、金色牌走 `gd.gold_leave`（都在确认面板上亮）、夜牌 `gd.d1.night`、日结 `gd.d1.settle`。
- **验收**：确认面板打开时不发指令、点“打烊”才发且只发一次 `day.end {confirm: true}`、“回去看看”什么都不发；清单每行都是正文键；夜牌“算了” = `night.choose {def: ""}`；日结行全部是正文键；Space 一路继续到第二天早上。

#### C09 `month-year` · 开月、月底、跳一年、局终
- **范围**：CardMonthOpen（时局过场：背景图 + 正文段落（来自本年的 `stage.json`，§4.7.22）+ 本关目标；然后由引擎要求打开本月运势轮盘）；CardMonthClose（月底账：利息、开销、当票、目标结果、街坊评语正文）；CardYearJumpPanel（一年过去：满当的东西、档案簿“一年后”、换币、人脉变化、新面孔，逐条翻）；CardGameOver（这一局结束的正文；“从本关开头重来” → `game.retry_stage`；“从续玩点重来” → `game.load {}`（有续玩点才能点）；回标题；关面板 = 回标题）。1.3：四个面板仍是叠层，画面在下面（月底、跳年时场景是夜里的柜台）。
- **归属**：`scenes/cards/month/**`、`scripts/cards/ui/month/**`。
- **新手指引**：锚点 `a.month.goals` `a.mclose.accounts` `a.year.forfeit` `a.year.after` `a.over.retry`；要证明的步骤：开月与目标 `gd.m.open`、月底结账 `gd.month_close`、跳一年与满当 `gd.year_jump`、一年后 `gd.year_after`、局终与重来 `gd.game_over` `gd.retry`。
- **验收**：四个面板各有夹具；重来本关发出正确指令。

#### C10 `dossier-help` · 档案簿、规矩页、F1 帮助
- **范围**：`CardDossierBook`（左抽屉；人名索引 + 一页、碎片、缺口、“一年后”、补齐盖章；第二页签“规矩”= 规矩栏，`args.tab = "rules"` 直接打开它）；`CardHelpPanel`（叠层，F1）。
- **归属**：`scenes/cards/dossier/**`、`scripts/cards/ui/dossier/**`。
- **新手指引**：锚点 `a.dossier.page` `a.dossier.gap` `a.dossier.rules_tab` `a.help.rules`；要证明的步骤：消息与碎片 `gd.news` `gd.dossier`、缺口 `gd.dossier_gap`、一年后 `gd.year_after`（档案簿里的那一页）、回看规矩 `gd.d2.rules`。
- **验收**：缺口和未得到的碎片在界面上可区分（缺口=撕痕，未得到=不显示格子），且都不泄露碎片内容；规矩栏的解锁只看 `firsts`（夹具里关掉指引照样解锁）；F1/Esc 在每个面板之上都能开关帮助。

#### C11 `ladder` · 家当与抵押、钱不够、街头、牢房
- **范围**：`CardEstatePanel`（右抽屉）；`CardShortPanel`（叠层，不变）；`CardStreetOverlay`（街头时的“赎回铺面”按钮与一句提示，背景由场景层换）；`CardPrisonPanel`（stage：牢房背景、格子在柜台上、托人疏通是回话）。
- **归属**：`scenes/cards/ladder/**`、`scripts/cards/ui/ladder/**`。
- **新手指引**：锚点 `a.estate.list` `a.estate.mortgage` `a.short.options` `a.street.redeem` `a.prison.slots`；要证明的步骤：钱不够与抵押 `gd.money_short` `gd.mortgage`、街头 `gd.street`、牢房与打点 `gd.prison`。
- **验收**：四个面板各有夹具；牢房失败后由引擎切到 `game_over`，面板不自己判断。

#### C12 `mg-spot` · 找不同（从旧验货面板分出来）
- **范围**：CardSpotGame（继承 CardMiniGame）。旧的 `scripts/ui/appraise_panel.gd` **不实例化、不改**：它按 `parts[].tell` 把找到的地方涂红（第 381 行）、数 `tells_left`（第 434 行）、有“我看这是假货”勾选（第 306 行），`appraise.gd` 的 `hit_note` 把判断写死在中文里——这些都违反红线 1 和 5，又不在 `scripts/cards/**` 下，审核扫不到。C12 把需要的部分**分**到自己的 `scripts/cards/minigames/spot/spot_panel.gd`：没有 tell/benign 的着色、没有“假货”勾选、没有教学文字；所有文字走 CardText；只 `preload` 读 `appraise.gd`、`flaw_render.gd` 来算圈中和画痕迹。参数只有布局和证据的样子（§8.2：部位矩形、哪种工具看得见、每处痕迹的画法 `look` 和小矩形 `at`、本品类的图例 `legend`、眼力辅助）。**主创 10-25：要玩家看出来才算数**——玩家自己在东西上点出和图鉴不一样的那一处、说它是“旧痕”还是“不一样”（钉一处花 1 笔墨、2 分钟；翻图鉴 1 分钟），结果是玩家的判断 `obs.spot.<部位>.<differs|wear>`（没钉而翻过图鉴：`obs.spot.nothing_found`），口气由过程分决定（翻没翻图鉴、用没用放大镜，§8.1），判错照记；不画部位框和部位名，不按对错着色，不写“还剩几处”；`apply_op`/`ops_log`（§8.1），`autoplay(skill)` = 每个判断判对的概率。观察键目录 `obs/spot.json`。1.3：小游戏仍由 C01 的宿主开在叠层之上，画面在下面；入口是柜台演出里的“细看”回话或柜台上的放大镜（都发 `mg.request`），小游戏本身不变。
- **归属**：`scenes/cards/minigames/spot/**`、`scripts/cards/minigames/spot/**`、`data/cards/minigames/obs/spot.json`。
- **新手指引**：锚点 `a.mg.spot.main` `a.mg.spot.atlas`（图鉴）`a.mg.spot.lens`（放大镜）`a.mg.spot.tag`（图钉清单与钉下以后的“旧痕 / 不一样”，10-25 新加）；`ui_event`：`mg_tool {kind:"spot", tool}`；要证明的步骤：`gd.d1.spot`。
- **验收**：不改任何旧文件；夹具物品（金簪、字画、米；其中金簪的布局由 W0 的 `day_counter` 夹具用真 ItemGen 生成）各跑一遍自动玩；结果没有判词键；参数里没有 `tell` `fake` 之类的键；§12.2 的小游戏必测（判断往返、op 回放、不露底、纯鼠标、老参数能玩完）。

#### C13 `mg-coin-ring` · 吹银元
- **范围**：CardCoinRingGame（主创 10-25 改）：柜上铺子自己的两枚样洋（足银的、拴红线的哑板）和客人的银元（一枚或一摞）；点哪枚吹哪枚，余音同时画成一道线（长短、疏密、毛边），留淡影好比（声音关着时线就是全部信息）；客人的两枚相碰听闷不闷；玩家**自己说**像足银的还是像哑板，一摞的一枚一枚标“响 / 哑”；不再有时机条（手速不是耳力）。声音：Steam 版只放 B 录的样本（`audio/cards/sfx/coin_ring_*.ogg`），按参数改音高/衰减；开发版没有样本时用运行时合成的占位声（`CardShip.is_ship()` 为假时才允许）。观察键目录 `obs/coin_ring.json`。波形是代码画的，只用调色板键（见 K12 的 `ART_SPEC.md`）。1.3：小游戏仍由 C01 的宿主开在叠层之上，画面在下面；入口是柜台演出里的“细看”回话或柜台上的放大镜（都发 `mg.request`），小游戏本身不变。
- **归属**：`…/minigames/coin_ring/**`、`data/cards/minigames/obs/coin_ring.json`。
- **新手指引**：锚点 `a.mg.coin_ring.main` `a.mg.coin_ring.blow` `a.mg.coin_ring.ear` `a.mg.coin_ring.samples`（两枚样洋，10-25 新加）；`ui_event`：`mg_tool`；要证明的步骤：`gd.mg.coin_ring`。
- **验收**：同参数同操作同结果；无头下不报音频错误（Dummy 驱动）；`autoplay(skill)` = 判对的概率，过程分（两枚样洋都吹过、真的比过）决定口气；§12.2 的小游戏必测。

#### C14 `mg-weigh` · 称分量
- **范围**：CardWeighGame：戥子或秤，加减砝码、拖秤砣，秤杆平衡（简单物理）；客人说的分量。主创 10-25：玩家**自己看定盘针**判断平没平、按“看星”后自己数星读数、自己和客人说的比，说出“对得上/轻一点点/轻了不少/反倒重了/说不好”；游戏不替你读、不替你比，支点不再亮金点。单位用整数“分”（1 钱 = 10 分）。观察键目录 `obs/weigh.json`。秤杆是代码画的，只用调色板键。1.3：小游戏仍由 C01 的宿主开在叠层之上，画面在下面；入口是柜台演出里的“细看”回话或柜台上的放大镜（都发 `mg.request`），小游戏本身不变。
- **归属**：`…/minigames/weigh/**`、`data/cards/minigames/obs/weigh.json`。
- **新手指引**：锚点 `a.mg.weigh.main` `a.mg.weigh.weights` `a.mg.weigh.beam` `a.mg.weigh.call`（五个说法，10-25 新加）；`ui_event`：`mg_tool`；要证明的步骤：`gd.mg.weigh`。
- **验收**（10-25）：`test_physics` 照旧；压不平的老参数也能“看星”+“说不好”交回；§12.2 的小游戏必测。

#### C15 `mg-fragments-decode` · 拼碎片 + 解密
- **范围**：CardFragmentsGame：把撕破的当票、裂开的字画碎片拖动、旋转、吸附拼回；拼好后玩家自己看骑缝印两半对不对得上、在墨接不上的拼缝上打叉（主创 10-25；所有碎片描边一样，异纸不再描红，水渍是干扰；鉴定复审 fix2 10-25：异纸只在缝上看得出——它那半截跨缝笔画错开 1–2 点、颜色发褐，对着光看纸纹到它的缝上接不上，纸色不变；跨缝笔画只落在浅色纸面上；水渍对它那道缝左右对称；桌面底下常驻几行规矩，只讲记号的意思、不讲这张的答案）、看“当字”笔画；观察键目录 `obs/fragments.json`。主线当票“德字第一九六号”走这个。CardDecodeGame：电报四位码对照电码本、账本暗语；主线专用；玩家自己翻电码本（引擎在参数 `book` 里给整本，小游戏不再自己读文件；没有 `book` 时照旧读）、自己找码抄词，洇了的码挑读法，加了码的先拿本号对出加了几；抄错照记、不拒收（10-25）；电码本是 K11 的骨架 `data/cards/minigames/codebook.json`（码 → 键）+ A 写的 `data/cards/text/codebook.text.json`（**不读**旧的 `data/codebook.json`，那是 AI 写的旧内容）；观察 = 译出的片段键；观察键目录 `obs/decode.json`。1.3：小游戏仍由 C01 的宿主开在叠层之上，画面在下面；入口是柜台演出里的“细看”回话或柜台上的放大镜（都发 `mg.request`），小游戏本身不变。
- **归属**：`…/minigames/fragments/**`、`…/minigames/decode/**`、`data/cards/minigames/obs/{fragments,decode}.json`。
- **新手指引**：锚点 `a.mg.fragments.main` `a.mg.fragments.board` `a.mg.fragments.seal` `a.mg.fragments.seam`（拼缝，10-25 新加）`a.mg.decode.main` `a.mg.decode.book` `a.mg.decode.sheet`（电报纸，10-25 新加）；`ui_event`：`mg_tool`；要证明的步骤：`gd.mg.fragments` `gd.mg.decode`。
- **验收**（10-25）：主线三件文书（`tk.1938.de196`、`nw.1939.brother_torn`、`nw.1940.chen_code`）用真数据各跑一遍；§12.2 的小游戏必测。

#### C16 `guide-shell` · 新手指引引擎 + 卡牌版的标题、暂停、设置、曲目
- **范围**：**新手指引引擎**（§7.10）：`scenes/cards/shell/GuideOverlay.tscn` + `scripts/cards/ui/shell/card_guide.gd`（`CardGuide`）——挑步骤（priority、interrupt、间隔、渐隐、`max_shows`、`after`、`done_when`、自动完成、每天新步骤上限）、锚点高亮、气泡、教的人头像与台词、存进度（`ui.guide`）、开关、测试钩子；做法照 `scripts/town/guide.gd` 的逻辑**重写**（只读，不改它；不拷 `data/town/onboarding.json` 的任何文字）；参数文件 `data/cards/rules/guide.json`。外壳：CardTitle（新局/继续/设置/退出；读 `CardSave` 的续玩点决定“继续”能不能点）、CardPause（Esc：继续/存档说明/设置/帮助（开 C10 的 `help`）/回标题/退出，按 `scripts/town/pause_menu.gd` 的做法重写一份，不改旧文件）、CardSettings（音量、文字速度、新手提示开关、快动画；见下）；曲目：`scripts/cards/ui/shell/card_music.gd` + `data/cards/audio/music.json`（标题、白天、夜、月底、跳年），不用 `music_director.gd`。1.3：教的人在画面里开口（人物站到 `GUIDE_TEACHER`、物件用批注纸，§7.10.7）；锚点按 `CardIds.ANCHORS_RENAMED` 新旧互认；`CardSettings` 呈现为右抽屉，并冻结静态读取 `fast_anim()`（§7.8）。
- **设置怎么存**：旧的四个键（`music` `sfx` `text_speed` `guide_hints`）用 `scripts/town/settings.gd` 读写 `user://settings.json`（构造时传路径，测试传自己的路径）；卡牌版独有的键（`fast_anim`）存在 C16 自己的 `user://cards/settings.json`——不往 `user://settings.json` 里塞新键（`settings.gd` 的 `save_file()` 只写它那四个键，塞进去的会在下次存时丢掉）。
- **归属**：`scenes/cards/shell/**`、`scripts/cards/ui/shell/**`、`data/cards/rules/guide.json`、`data/cards/audio/music.json`。
- **新手指引**：锚点 `a.settings.guide_toggle` `a.pause.help`；指引引擎本身的验收见下。
- **验收**：标题→新局→牌桌→Esc→回标题→继续 往返不泄漏；设置改动写入并在牌桌生效（文字速度、音量、快动画、新手提示）；**指引（无头）**：自己测试目录里的夹具 `guide_d1` `guide_d2` `guide_d3`（新存档第 1–3 天按教学日程会发出的事件），`CardGuide.shown_log` 按顺序等于 `_test.d1_3`（K16 合入前用 C16 自己照表 7.10.10 写的 21 步测试步骤，另用 `_examples/guide/steps.json` 跑一遍；K16 合入后加一行读真 `steps.json`）；关着指引时什么都不亮、不发 `ui.guide`；priority/interrupt/max_shows/间隔/每天上限/自动完成各有单测；**截图**：xvfb 下每一步一张 1280×720（截图脚本不进清单）。

### 3.4 Grok：数据骨架、美术管线、审读、QA、审核工具、指引骨架、分支设计（K01–K16）

数据任务的共同要求：只写**机制骨架 + brief**；**不写 `text`**，不写正式名字（名字的提议写在 brief 里，A 定稿）；brief 写成干巴巴的设计说明——谁、什么事、有哪些选项、各自后果、史实依据——**不写成可以直接拿去用的台词或文案，不写引号里的对白**；数字都是起步值；每个文件过校验器默认模式；悬空引用（引用了别的任务还没写的 id）列在 PR 里；id 用 §3.5 的预留表；每张 event、fate、person、life、news 至少带一个 `omen_*` 征兆标签（§2.5）；效果里的原因键、告示键用自己的 `k0x.*`（§2.5）；**打烊时没处理会怎样要写明**（§7.4.7）：事件、命运、街头、大赌（`must_resolve` 为真、没有顶层 `check` 的）必须写 `effects.on_expire`（没有后果就写 `[]`，V37），人物牌只有个别记仇的人写 `on_expire`，“今天的机会”类事件写 `must_resolve: false`，brief 里一句话写明没理会的结果。

#### K01 `data-1938-people` · 1938 人物牌、主线节点（含金色牌）、过路客
- **范围**：1938 年在场的 16 个主要人物各 2–4 种来意（当、卖、买、赎、求助、打听）；主线节点 `s1938.*`（§3.5）对应的人物牌，主线人物在节点上 `gold: true`（必须带 `on_expire` 的 `story` + `dossier_gap`）；新面孔 `nf1938a–d`（`persons` 块里写 brief 和头像 id）；过路客 8 种原型（`era: ["*"]`，放 `era/common/passersby.json`）；系统牌 `p.any.redeem`（§3.5）；在 `passersby.json` 的 `persons` 块登记算命先生 `suanming`（新手指引里教求签测字的人）。**1.3**：金色牌都写演出块（`intro` ≥ 2 拍、每个选项一组 `after`），另外各挑 ≥ 6 张普通人物牌写演出块（后门、带道具、带陪同）；见 §4.7.24。
- **教学要用的牌（确认）**：哥哥告别 `p.brother.1938.farewell` 在第 2 天、`gold: true`、**第一个选项**是“听他交代完”并给 `kp.brother_note`（第 2 天的留牌指引靠它）。
- **数量**：约 45 张人物牌 + 7 个主线节点。
- **归属**：`data/cards/era/1938/{people,story}.json`、`data/cards/era/common/passersby.json`。

#### K02 `data-1938-world` · 1938 事件、命运、大命运、生活、目标、开场 + 通用事件与大赌
- **范围**：通用事件 10 + 1938 事件 10；1938 命运 4（`valence` 必填）；大命运：`bf.wheel`（转大轮盘的那张，§9.2）+ 通用“大赌”4–6 张 + 1938 1–2 张——**大赌一律 `weight: 0`**，只由大轮盘扇区的效果发到手上；1938 生活牌 2–3；1938 目标（1 主线 + ≥4 可选，完成条件写在 `done_when`）；`era/1938/stage.json`（开场 brief、背景图 id、目标 id，§4.7.22）；庙会/赌摊/算命摊事件（带 `opens_wheel` 或 `opens_fortune`，和 `ev.any.wheel_go` 一样写 `must_resolve: false`：今天的机会，过了就没了）至少各一张；系统牌 `ev.any.wheel_go`（`wheel_offer` 发的“去转”行动牌，§9.2）。原来的“规矩牌”取消——规矩改由新手指引在戏里讲（§7.10），不占手牌。**1.3**：每张事件、命运、大赌（`bf.wheel` 和开轮盘、开算命的除外）都写演出块，至少有 `cast`、`set`、`fx`、`walk`、`props` 里的一样；生活牌可选。
- **教学要用的牌（确认）**：`bf.wheel`、`ev.any.wheel_go`、算命摊事件 `ev.any.fortune_teller`（K16 的教学日程另有一张第 5 天的）。
- **归属**：`data/cards/era/1938/{events,fate,big_fate,life,goals,stage}.json`、`data/cards/era/common/{events,big_fate}.json`。

#### K03 `data-1939-people` · 1939 腊月人物牌、主线节点
- **范围**：老面孔跨年的变化（老了、穷了、走了、换了身份）；年关来意（赎当、当衣过年）；新面孔 `nf1939a–d`；主线节点 `s1939.*`（含金色牌）。**数量**：约 40 张 + 5 节点。**1.3**：金色牌都写演出块（`intro` ≥ 2 拍、每个选项一组 `after`），另外各挑 ≥ 6 张普通人物牌写演出块（后门、带道具、带陪同）；见 §4.7.24。
- **归属**：`data/cards/era/1939/{people,story}.json`。

#### K04 `data-1939-world` · 1939 事件、命运、大命运、生活、目标、开场 + 通用命运
- **范围**：1939 事件 10（城门盘查、米行涨价、乡下的消息……）、命运 4、大命运 1–2（`weight: 0`）、年关生活牌 3–4、目标（主线“过年前把账结清”+ ≥4 可选）、`era/1939/stage.json`；**通用命运 18**（`era/common/fate.json`，从 K02 移过来；`valence` 必填）。**1.3**：每张事件、命运、大赌（`bf.wheel` 和开轮盘、开算命的除外）都写演出块，至少有 `cast`、`set`、`fx`、`walk`、`props` 里的一样；生活牌可选。
- **归属**：`data/cards/era/1939/{events,fate,big_fate,life,goals,stage}.json`、`data/cards/era/common/fate.json`。

#### K05 `data-1940-people` · 1940 三月人物牌、主线节点
- **范围**：新官上任后的人；孙府站队；新面孔 `nf1940a–d`；主线节点 `s1940.*`（含金色牌、首发结尾的钩子）。**数量**：约 40 张 + 5 节点。**1.3**：金色牌都写演出块（`intro` ≥ 2 拍、每个选项一组 `after`），另外各挑 ≥ 6 张普通人物牌写演出块（后门、带道具、带陪同）；见 §4.7.24。
- **归属**：`data/cards/era/1940/{people,story}.json`。

#### K06 `data-1940-world` · 1940 事件、命运、大命运、生活、目标、开场 + 通用生活牌
- **范围**：1940 事件 10（汪伪成立、新官上任、摊派换名目……）、命运 4、大命运 1–2（`weight: 0`）、生活 2–3、目标（主线“在新规矩下站住脚”+ ≥4 可选）、`era/1940/stage.json`；**通用生活牌约 12**（`era/common/life.json`，从 K02 移过来：米、煤、看病、学费、喜帖、丧事、过年……，`due_days`、`waivable`）。**1.3**：每张事件、命运、大赌（`bf.wheel` 和开轮盘、开算命的除外）都写演出块，至少有 `cast`、`set`、`fx`、`walk`、`props` 里的一样；生活牌可选。
- **归属**：`data/cards/era/1940/{events,fate,big_fate,life,goals,stage}.json`、`data/cards/era/common/life.json`。

#### K07 `data-demand` · 条子（4 类 × 4 档 × 3 年）
- **范围**：48 张条子 `dm.<年>.<类>.t<档>`，每年换说法（brief 写清这一年的名目）；每张的数目、要的货、要几个人、要谁的消息；格子与讲价/顶替/编一个的检定（选项 id 用 §4.7.6 的保留 id）；可选的按卡覆盖吃亏效果（默认按 `demand_rules.json` 的四档阶梯）；要人条子“可能回不来”的回来检定（看得见的铜钱）；系统牌 `ev.any.demand_return`（“回来了吗”的那张事件）。
- **教学要用的牌（确认）**：1938 第一个星期一（第 7 天）发的那张条子按 `tier_by_stage` 是小档以上，别太凶。
- **归属**：`data/cards/demand/**`。

#### K08 `data-news-dossier` · 消息牌、档案簿页与碎片
- **范围**：消息牌约 40（三年；行情、线索、流言、信、报纸、电报；`info_about` 与 `on_inform`；电报可以带 `minigame: "decode"`）；每个人物一页 `dp.<person>`（16 主要人物 + 新面孔 + 有页的过路客）；碎片 `df.*`（每个主要人物 ≥5 块；来源：当了什么、说了什么、别人提起、剪报、当票上的字、信）；“一年后”碎片（1938→1939、1939→1940）；补齐解锁（人脉或结局牌）；哪些碎片会因交人/金色牌没理而成缺口；系统牌 `nw.any.family_word`（回家吃饭得到的家人消息）。**1.3**：`kind` 为 `telegram`、`letter` 的消息牌写演出块（何启明 + `prop.telegraph_open` / `prop.letter`）。
- **教学要用的牌（确认）**：K16 第 6 天的周妈消息补的那块碎片在 `dp.zhouma` 里有位置。
- **归属**：`data/cards/news/**`、`data/cards/dossier/**`。

#### K09 `data-common` · 留着的牌、人脉、家当、夜牌、街头、牢房、你自己
- **范围**：留着的牌约 15（人情、证件、硬货、把柄、空白当票、信物；过期、加成、风险、香案单位）；人脉约 11（属性、被动、坏处、离开条件、跨年变化）；家当 5（押值、利息、押出后的本事损失、铺面的特殊规则）；夜牌 6（回家吃饭带两个 `choices`，§4.7.12）；街头牌约 12（每张有顶层 `check` 或 `on_expire`，V37）；牢房牌 `pr.cell`（系统牌）1–2（brief 写明：没处理就在牢里多待一晚，连续 `prison.max_days` 晚没出来按打点失败，§7.4.7）；`self.ruhua`（起始属性）。不做“哥哥的账簿批注”留牌（它会占一个留牌位）；哥哥的账簿只作新手指引里“教的人”`obj.brother_ledger`。**1.3**：`data/cards/common/extras.json` 登记九个群演（§3.5）；六张夜牌、每张街头牌、`pr.cell` 写演出块（夜牌换背景与道具、街头换背景、牢房 `set: prison`）。
- **教学要用的牌（确认）**：`kp.brother_note`（第 2 天）、`ct.zhouma`（第 7 天的人脉指引）。
- **归属**：`data/cards/common/**`。

#### K10 `data-fortune` · 轮盘与扇区、签、测字、黄历
- **范围**：四个轮盘定义 `wh.month` `wh.big` `wh.fair` `wh.gamble`（香案收什么、每样算几份、每份加宽多少【待调】、代价）；扇区按年代：本月运势每年 6–8 段（含财星高照、流年不利一类）；大轮盘三类（翻身/平安/坠底）每年各 2–3 段，段可带 `conditions`（v1 §三.9：本心决定大命运出现哪几张）；庙会 6 段、赌摊 6 段；签 ≥ 30 支（五个等第 × 六个以上征兆家族，外加每等第一支“泛泛”的）；测字的字 12–16 个；黄历条目 ≥ 24（宜/忌用 §9.4 的动作枚举）。签的 `hint_tags` 和字的 `tags` **只用 `omen_*`**（§2.5）。签诗、解曰、字、提示的正文全部留给 A；brief 只写征兆和吉凶方向。
- **教学要用的牌（确认）**：第 4 天起的黄历条目覆盖收当/出货这类柜台动作；1938 本月运势至少一段好的能被香案明显撑宽（开局轮盘指引要看得出来）。
- **归属**：`data/cards/fortune/**`。

#### K11 `data-items-mg` · 物品 → 小游戏参数、首发物品表、新物品模板、电码本骨架
- **范围**：首发约 40 件物品的清单（`launch_items.json`：对 `data/town/item_templates.json` 已有的 28 个变体 + 新增）；新增模板（`templates_extra.json`：银元几种、银器、金条、当票/文书类等，格式同现有模板，图 id 指向占位）；每个模板能出哪些小游戏、物理参数的范围（`minigames/items.json`，§4.7.15）；**电码本骨架** `minigames/codebook.json`（四位码 → 词的键 + brief，§4.7.23；词由 A 写）。史实依据写在 brief（银元按枚计价一般不称；金饰、碎银、药材用戥子称；吹银元听余音）。
- **教学要用的牌（确认）**：至少一个能出 `spot` 的模板（K16 第 1 天的来当客人用）。
- **归属**：`data/cards/minigames/items.json`、`data/cards/minigames/codebook.json`、`data/cards/items/**`。

#### K12 `art-pipeline` · 占位美术生成器、美术清单、给画师的美术规格
- **范围**：`tools/cards/art/gen_placeholders.py`（Python 3 + Pillow，可复用 `tools/art/pixlib.py` 的调色板做法；确定性；每张图左上角打“稿”角标）生成：牌框 15 种（含金色）、头像（缺的人物用剪影，已有立绘的可以从 `art/portraits/` 缩放/描边）、小插图（按卡牌 id 生成带类别图标的水墨风占位）、背景、轮盘面、图标（含指引里“教的人”的物件图标 `icon.obj.notice` `icon.obj.almanac` `icon.obj.brother_ledger`、指引气泡框 `frame.guide_bubble`）；`data/cards/art/manifest.json`（所有美术 id、底图尺寸、9 宫格边距、正式路径、占位路径）；`docs/cards/ART_SPEC.md`（给 A/外包：每种图的尺寸、整数倍、调色板、光源、层、导出格式、文件名、交付清单、来源记录要求；并写明**代码画出来的小游戏画面**（吹银元的波形、秤杆、碎片描边）算代码、不算美术，但只许用调色板键）。**1.3**：§4.8 的新美术类别（`bg.*`、`stage.*`、`walk.*`、`prop.*`、`frame.dialog`、`frame.hero`、`icon.tab.*`）进清单与生成器；旧图按 legacy 占位；ART_SPEC 写场景与交付清单。
- **归属**：`tools/cards/art/**`、`art/_placeholder/**`、`audio/_placeholder/**`、`data/cards/art/manifest.json`、`docs/cards/ART_SPEC.md`。
- **验收**：生成器两次运行字节相同；清单覆盖所有已合并数据里引用的美术 id（有命令行检查）；占位总量 ≤ 20 MB。

#### K13 `review-history` · 史实与敏感审读
- **范围**：措辞检查工具 `tools/cards/review/wording_lint.py`（规则在 `data/cards/rules/wording.json`：缺“伪”字、1945/1949 的写法、1950 年代不做惩罚牌、不写暴力细节、brief 里不许出现引号对白等）；逐文件审读报告 `docs/cards/review/<ID>.md`（问题、依据、建议）；对已交付的 K 数据开 `[K13→K0x]` 修正 issue、由数据的主人改（§2.6），包括 K16 的指引步骤和规矩页 brief（不许提概率、点数、本心）；核对 `stages.json` 的公历起止（1939 腊月）并在 issue 里给 G02。**1.3**：审读范围加演出块里的 brief。
- **归属**：`tools/cards/review/**`、`docs/cards/review/**`、`data/cards/rules/wording.json`。

#### K14 `qa-automation` · QA 自动化、截图、指引走查、问题模板
- **范围**：`scripts/tests/cards/K14/play_ui.gd`（加载 `CardGame.tscn`，默认 `--guide=off`，用各面板的 `autoplay_step()` 走完一关，关键处截图：开月、轮盘、柜台、各小游戏、条子、夜、日结、月底、跳年、档案簿、街头、牢房）；`tools/cards/qa/shots.sh`（xvfb-run + opengl3；没有 xvfb 时跳过截图只跑流程）；截图拼图与对比（同种子两次截图像素一致）；**W2 的指引走查** `scripts/tests/cards/K14/test_guide_d1_3.gd`（真引擎、种子 7、新存档、`--guide=on`，走第 1–3 天：`CardGuide.shown_log` 按顺序等于 `steps.json._test.d1_3`；同一串指令关着指引再走一遍，状态哈希相同；截图脚本 `shot_guide_d1_3.gd` 每一步一张）；`docs/cards/qa/bug_template.md`、`playtest_checklist.md`（含红线逐条检查：界面上有没有数字泄露、% 号、判词、没教就出现的机制）。**1.3**：走查与截图改成画面版（§12.3）：演出、抽屉、叠层、对话框都走一遍。
- **归属**：`tools/cards/qa/**`、`docs/cards/qa/**`。
- **依赖**：W1 对着 Mock 搭；W2 跑真引擎。

#### K15 `audit-provenance` · 来源审核工具（Steam 免 AI 声明）
- **范围**：`tools/cards/audit/stage_ship.py`（把导出用的文件拷到暂存目录，剥掉所有 `brief`、`_provenance`、`_doc`、`_meta.brief`、`_test`，去掉 `art/_placeholder/**`、`audio/_placeholder/**`、`data/cards/_examples/**`、`data/cards/_dev/**`、`palette.dev.json`、`data/cards/rules/wording.json`、`data/cards/branch/**` 和旧版目录（§2.3））；`tools/cards/audit/audit.py`（§11.4 全部检查，非零退出即不许出包）；`tools/cards/audit/check_pr_paths.py <base> <head> --author=<login>`（作者不在 `legal/human_authors.json` 里就按 AI 线查：碰了人写路径失败；按 `docs/cards/ownership.json` 检查越界；§11.5）；`tools/cards/audit/missing_text.py`（给 A/B 的待写清单：id、类型、要写哪些字段——含指引步骤 `say`/`bubble`、规矩页 `title`/`body`、帮助的界面键、开场段落、电码本的词；**不带 brief 原文**，只带机制要点：类型、选项 id、格子 id、谁、教哪个机制）；判词词表 `tools/cards/audit/verdict_words.json`。**1.3**：待写清单加演出拍子引用的字段、`w0.stage.*`、群演名字；`stage_ship.py` 确认剥掉演出块里的 brief。
- **归属**：`tools/cards/audit/{check_pr_paths,audit,stage_ship,missing_text}.py`、`tools/cards/audit/{verdict_words.json,README.md}`、`tools/cards/audit/{tests,fixtures}/**`、`docs/cards/audit/**`（逐个文件；同目录的 `cjk_allowlist.json` 归 Claude）。
- **验收**：对一个人造的“坏包”（夹具）逐项报错；对空正文的现状报出完整待写清单；标准库之外不依赖第三方包。

#### K16 `guide-data-post1949` · 新手指引步骤与规矩页骨架、教学日的牌、解放后分支设计
- **范围**：① **新手指引数据**（§7.10）：`data/cards/guide/steps.json`（每个 `CardIds.FIRSTS` 机制至少一步，按 §7.10.10 的节奏表；`_test.d1_3` 写新存档第 1–3 天应当按顺序亮的步骤）与 `data/cards/guide/rule_pages.json`（每个机制至少进一页规矩）；只写 brief 和机制字段，`say`/`bubble`/`title`/`body` 留给 A；brief 不提概率、点数、本心。② **教学日的牌** `data/cards/era/1938/tutorial.json`（§7.10.11：第 1 天来当/来卖/来买三位、第 3 天一张带格子的事件、第 5 天算命先生、第 6 天周妈的消息、第 7 天得到人脉；id `*.1938.tut_*`，全部 `weight: 0` + `schedule`）。③ **解放后分支设计**：`docs/cards/post1949/`：信托商店/旧货店、茶馆两个分支的牌组设计（人物、事件、消息、风险、生活牌清单与机制；条子换成“任务”和“通知”的做法；新小游戏：泡茶、记茶钱、听书；和当铺年代的衔接：人脉、档案簿、本心、历史问题牌 `kp.history_issue`）；严格按 era.json notes：1950–1953 的土改、“五反”、统购统销只作政策和经济事件，不做随机惩罚牌，1956 公私合营收尾不作褒贬。分支只写设计，不写代码、不写正文；`data/cards/branch/**` 预留，首发不读。**1.3**：步骤的锚点按 §7.10.10 新表改（7 个改名、几处备用锚点与 `done_when`）；教学牌 `ev.1938.tut_slots`、`ev.1938.tut_contact` 写演出块。
- **归属**：`data/cards/guide/**`、`data/cards/era/1938/tutorial.json`、`data/cards/branch/**`、`docs/cards/post1949/**`。
- **验收**：校验器 strict 模式下 V29–V36 对自己的文件全绿；`_test.d1_3` 里的步骤都存在、顺序合节奏表；新存档第 1–3 天在真牌桌 + Mock 上按 `_test.d1_3` 的顺序亮（headless，进清单），每一步一张截图；教学日的牌引用闭合（悬空的列在 PR 里）。

#### K17 `officialdom-open` · 官场开头（**1.4**，§九.7，#182 第 5 条）
- **范围**：1940 关的金色牌 `p.ma.1940.baozhang`“请你当保长”（第 14 天，马万利升区公所、保甲重编，要你接保长）与档案碎片 `df.ma.1940.baozhang_*`；四种走向 `take` 接下 / `nominal` 挂名暗里护街坊 / `buy_off` 打点推掉 / `refuse` 当面回绝，打烊没理 = `ignored`。机制 `office`（G03 在发牌钩子里对带 `office` 标签的牌记 first）、指引步骤 `gd.office`（规矩页 `rule.gold`）。
- **给后续官场线与 1945 肃奸的旗标**：`story.s1940.baozhang` = 走向；`office_post` = `"baozhang"`（take/nominal）；`office_baozhang_take` `office_baozhang_nominal` `office_shield_neighbors` `office_baozhang_buy_off` `office_baozhang_refuse` `office_foe_ma`（对头） `office_baozhang_ignored`；计数 `sujian_marks`（take +2、nominal +1；1945 肃奸清算读它）。后续的牌只读这些键，不另起名字。
- **归属**：`data/cards/era/1940/officialdom.json`。**验收**：`K17_baozhang`（每个走向的旗标、first office、不撞其他金色牌的日子、没有检定也没有 `game_over`——“下一天”照常能按）。
#### K18 `apprentice` · 收徒（§九.7，#182 第 3 条；合同 1.4，#187）
- **范围**：1939 第 11 天人物牌 `p.tudi.1939.ask`（留下 / 话硬 / 不收；不理走 `on_expire`）。人脉 `ct.tudi` 四项本事每月轮流 +1，上限 `rules/apprentice.json` 的 `attr_cap`。隐藏计数 `apprentice_loyalty`、`apprentice_skim_pending`（进 §7.5 黑名单）。你不在铺（`mode == street`，或手上有未处理的牢房牌）且徒弟在人脉里：他看铺，客人少、他自己定价体现在回来的翻账 `ev.any.apprentice_audit`，不改发牌器。忠心低于 `steal_at` / `tip_at` 月底各排一次 `ev.any.apprentice_steal`、`ev.any.apprentice_tip`（透给胡二，风声升一档，不局终）；达到 `succeed_at` 且月数达到 `succeed_months` 排一次 `ev.any.apprentice_succeed`。钱用 `money` 差额，不用 `pay`。家人看铺不做。台词不写。
- **归属**：`scripts/cards/apprentice/**`、`data/cards/era/1939/apprentice.json`、`data/cards/rules/apprentice.json`。跨线（#187）：`card_ids.gd` 的 `FIRSTS`、`card_engine.gd` 在六段安装之后追加安装、`view_model.gd` 两个隐藏键、`hero_bar.gd` 徒弟小牌用 `jade`、`day_loop.gd` 的公开方法 `CardDayLoop.open_pre_ending_window(ctx, owner) -> bool`（G02×K18 最小共享：只在末关 `month_close`、且 `month_pending` 为假、`open_panel.kind` 不是 `short` 时把阶段临时改回 `day`；否则返回 false，并在末关记下 `loop.pre_ending_due`。`close_month` 在月钩子之后重算 pending、确认没有新短款、也没有阶梯局终时才打开该窗口，并 fire `pre_ending_window` `{owner}` 让主人发牌；窗口打烊不请空 short 面板、不硬写 `month_pending`，恢复 `month_close` 后走原来的 `close_month`，不重跑 day_end / 夜牌 / settle）、`gd.apprentice` 与 `rule.contact` 的 `unlock_first`、W0/K16 的计数测试。门禁另补两处跨线测试（不改生产逻辑）：`scripts/tests/cards/G01/fixtures/good/guide/coverage.json` 的正例 `teaches` / `unlock_first` 加上 `apprentice`、`pet` 与 `scare`（并入 #191 后 FIRSTS 为 70，含 office + pet + apprentice + scare，strict/ship 的 V29 才认这套夹具）；`scripts/tests/cards/K09/test_data.gd` 的人脉全集计入 `ct.tudi`（11→12）。
- **新手指引**：机制 `apprentice` 由 K18 在 `deal_composed` 发出；步骤 `gd.apprentice`，教的人 `obj.brother_ledger`，锚点 `a.contacts`（备用 `a.tab.contacts`），规矩页 `rule.contact`。
- **验收**：default 校验自己的数据文件无 DATA ERROR；收下后有人脉且视图不漏忠心；月底长一项本事；低忠心排队偷与通风，高忠心且满月数排队接班；街头或牢房看铺，回来翻账，不理也结账；`day.end {confirm:true}` 不卡住；存读后 first 不重发。

#### K18 `weapon-scare` · 武器只开吓唬（合同 1.4，#182 第 4 条，DESIGN §九.7）
- **范围**：1939 年有人把短枪拿来当，藏成留着的牌 `kp.pistol`（不当成可赎的当票）。1940 起（`loop.stage >= 2`）且枪在留着的牌里，普通客人的回话多一句吓唬：胆量检定，过了对方让开，没过对方去报官。金色牌和带 `story_node` 的主线不加这句。动手不在这一版。
- **归属**：`scripts/cards/weapon/**`、`data/cards/era/1939/weapon.json`。跨线改动暂时写在 K18 名下，见 §2.2，合并后还回原主人。
- **依赖**：G03 的选项与检定、G01 的 `add_card` / `CardFirsts`、K16 的规矩页 `rule.kept`。
- **first-time**：`scare`（发出者记在 G03：发牌时这句回话已经在普通客人身上）。
- **验收**：1939 藏枪后没有吓唬，打烊确认仍能往下走；1940 有枪才出现吓唬，没枪、金色、主线都没有；吓住 / 没吓住的旗标、风声、口碑按数据走，枪还留着；没有 `act` 选项。

#### K18 `pet-cat` · 宠物（店里的猫）（§九.7，#182 第 2 条）
- **范围**：1938 第一关中段一只猫。小牌位（锚点 `a.pet`，不是新区）：每天多看一眼（找不同的墨次或吹银元的次数 +1，当天一次，不是永久眼力）、猫在的夜里米货不掉成色、日结陪一晚（隐藏刻度，界面不写数）、住满几夜可能走丢并排出找猫。进店牌 `ev.1938.cat_arrive`（第 15 天，`weight` 0），找猫 `ev.1938.find_cat`（只由走丢排入，不自己走回）。机制 `pet`（发出者 G03），指引 `gd.pet`（账簿批注，第 2 天之后），规矩并进 `rule.contact`，不新加页。计数在 `rules.pet`，旗标在 `rules.flags`。数字【待调】，见 `rules/pet.json`。从没留过猫的局不写这块状态。不能挡住 `day.end`。
- **归属**：`data/cards/era/1938/pet.json`、`data/cards/rules/pet.json`、`docs/handoff_cards/K18_pet-cat.md`。挂载和牌位改了 G03 / G04 / C02 / Claude 的文件，记在配套 `[api]`。
- **验收**：`K18_pet` 证明留下、多看一眼只消耗一次、在店的夜里米不霉、走丢才霉、找猫入队、`day.end` 仍往前走；校验器 default 对自己的文件全绿；与收徒、吓唬并入后 `FIRSTS` 70（含 office + pet + apprentice + scare），指引步骤 70，规矩页仍 26。

### 3.5 预留 id（跨线引用就用这些；新加的在自己 PR 里列出）

**人物**（`data/cast.json` 已有）：`brother` 沈如松 · `chen` 陈文庭 · `xiaoding` 小丁 · `zhang` 张慧娟 · `wangshan` 王山 · `li` 李敬之 · `linsao` 林嫂 · `zhouma` 周妈 · `zhao` 赵老三 · `sunyoung` 孙富贵 · `ma` 马万利 · `hu2` 胡二 · `sunlaoye` 孙德昌 · `guanjia` 孙福 · `wu` 吴长发 · `postman` 何启明。主角 `ruhua` 沈如花（K09 的 `self.json` 里登记）。
**新面孔**：`nf1938a`–`nf1938d`（K01）· `nf1939a`–`nf1939d`（K03）· `nf1940a`–`nf1940d`（K05）· `nf_pistol`（K18，1939 拿短枪来的生人，不要档案页）。
**过路客原型**（K01）：`stranger_refugee` `stranger_peddler` `stranger_collector` `stranger_fence`（已有立绘）· `stranger_waixiang`（外乡人）`stranger_boatman` `stranger_student` `stranger_widow`。算命先生 `suanming`（K01 在 `passersby.json` 的 `persons` 块登记；新手指引里教求签测字）。
**指引里“教的人”里不是人物的**（不进人物登记，美术 id `icon.obj.<名>`）：`obj.notice` 告示 · `obj.almanac` 黄历 · `obj.brother_ledger` 哥哥的账簿批注（哥哥第 2 天走后，规矩由它讲）。
**群演**（演出里的配角，不是牌上的人物；K09 在 `data/cards/common/extras.json` 的 `persons` 块登记，`dossier: false`；名字由 A 写在 `persons.text.json`；立绘 `portrait.<id>`、行走图 `walk.<id>`）：`ex_patrol` 巡警 · `ex_soldier` 伪军 · `ex_newsboy` 报童/跑腿带话的 · `ex_girl` 对门的姑娘 · `ex_shopboy` 邻铺的伙计 · `ex_oldman` 老先生 · `ex_porter` 过路人/码头扛包的 · `ex_student` 学生 · `ex_hu2_man` 胡二的人（只作剪影）。新群演走 `[api]` issue（`CardIds.EXTRAS`）。

**主线节点**（`story_node`）：
| 1938（K01/K02） | 1939（K03/K04） | 1940（K05/K06） |
|---|---|---|
| `s1938.brother_farewell` 哥哥第二天离家 | `s1939.year_end` 年关赎当、当衣过年 | `s1940.wang_regime` 汪伪政权成立 |
| `s1938.ticket196` 德字第一九六号 | `s1939.gate_check` 城门盘查 | `s1940.new_official` 新官上任、条子升档 |
| `s1938.wangshan` 王山 | `s1939.brother_letter` 哥哥的第一封信 | `s1940.sunfu_stance` 孙府要你表态 |
| `s1938.zhao_borrow` 赵老三借三百 | `s1939.wangshan_whereabouts` 王山的下落 | `s1940.dossier_link` 关键碎片串起来 |
| `s1938.linsao_term` 林嫂的当期 | `s1939.wu_price` 米行吴长发涨价 | `s1940.hook` 首发结尾的钩子 · **1.4** `s1940.baozhang` 请你当保长（K17） |
| `s1938.ma_levy` 马万利的摊派 | | |
| `s1938.police_open` 月底伪维新政府成立、警察所开门 | `s1939.apprentice` 有人来求留下看铺 | |
| | `s1939.apprentice_hand` 徒弟接班 | |

**留着的牌**（K09）：`kp.ma_owes` 马万利欠你一次 · `kp.liangmin` 良民证 · `kp.sunfu_letter` 孙府介绍信 · `kp.gold_bar` 一根金条 · `kp.blank_ticket` 空白当票 · `kp.brother_note` 哥哥的交代（主线信物）· `kp.mystery_box` 来路不明的箱子（大命运“收下”后得到） · `kp.leverage.<person>` 某人的把柄 · `kp.history_issue` 历史问题牌（解放后，K16 预留，首发不用）· `kp.pistol` 藏起来的短枪（K18，1939 藏下，1940 起才能吓唬；被查到只加风声，不直接抓人）。（没有“哥哥的账簿批注”留牌：它会占一个留牌位；账簿只作指引里教的人 `obj.brother_ledger`。）
**人脉**（K09）：`ct.zhouma` `ct.chen` `ct.ma` `ct.xiaoding` `ct.wangshan` `ct.li` `ct.linsao` `ct.zhang` `ct.wu` `ct.guanjia` `ct.postman`。**学徒**（K18）：`ct.tudi`。
**家当**（K09）：`es.jewel_cabinet` 首饰柜 · `es.storeroom` 库房 · `es.counter` 柜台 · `es.old_house` 老宅 · `es.shopfront` 铺面。
**夜牌**（K09）：`nt.tidy` 整理库房 · `nt.accounts` 对账 · `nt.backdoor` 后门收货 · `nt.telegraph` 发电报 · `nt.family_dinner` 回家吃饭 · `nt.early_sleep` 早点睡。
**街头**（K09）：`st.beg` `st.odd_job` `st.stall` `st.write_letters` `st.errand` `st.pawn_own` `st.gamble`（开 `wh.gamble`）…；**牢房**：`pr.cell`。**你**：`self.ruhua`。
**大命运**（K02 通用）：`bf.wheel`（转大轮盘的那张，危机时由 G05 发）· `bf.any.mystery_box` · `bf.any.sun_guarantee` · `bf.any.house_offer` · `bf.any.ship_ticket`（这四张和各年的大赌一律 `weight: 0`，只由大轮盘扇区的效果发到手上）。
**轮盘**（K10）：`wh.month` 本月运势 · `wh.big` 大轮盘 · `wh.fair` 庙会 · `wh.gamble` 赌摊。
**条子**（K07）：`dm.<1938|1939|1940>.<money|goods|people|info>.t<0-3>`。
**当票**（K01）：`tk.1938.de196` 德字第一九六号。
**新手指引**（K16）：步骤 `gd.<slug>`、规矩页 `rule.<slug>`（起步清单 §7.10.10）；教学日的牌 `<前缀>.1938.tut_<slug>`（`tutorial.json`）。原来的“规矩牌” `ev.rule.*` 取消。
**目标**：`gl.<年>.<slug>`。**开场**：每年一份 `era/<年>/stage.json`（§4.7.22）。

**系统牌**（引擎在规则里自己发的牌；定义归下表的任务，引擎只按 id 发）：

| id | 谁发 | 定义归 | 是什么 |
|---|---|---|---|
| `ev.any.demand_return` | G03 | K07 | 要人条子派出去的人回来那天的“回来了吗”事件 |
| `ev.any.wheel_go` | G05（`wheel_offer`） | K02 | “去转一次”的行动牌，`vars: {wheel, cost}` |
| `nw.any.family_word` | K09 的夜牌效果 | K08 | 回家吃饭得到的家人消息（`nw.*` 归 K08 的目录） |
| `p.any.redeem` | G04 | K01 | 来赎当的过路人（主要人物用自己的 redeem 牌） |
| `pr.cell` | G06（`arrest`） | K09 | 牢房 |
| `bf.wheel` | G05（危机） | K02 | 转大轮盘 |

---

## 4. 数据格式（d）

所有数据文件 UTF-8、2 空格缩进、合法 JSON（不许注释、不许尾逗号）。数字：计数、钱、天数、点数一律整数；比例一律写成**整数百分比**（`pct`）或整数千分比（`permille`）或分子分母（`num`/`den`），**不写小数**（存档和随机键只认整数）。

### 4.1 文件信封

每个牌文件（`era/**`（`stage.json` 除外，§4.7.22）`demand/**` `news/**` `dossier/**` `common/**` `fortune/**` `guide/**` `minigames/items.json` `_examples/**`）：

```json
{
  "_meta": {"owner": "K01", "schema": 1, "brief": "1938 年三月的人物牌"},
  "persons": {
    "nf1938a": {"portrait": "portrait.nf1938a", "dossier": true, "brief": "新面孔甲：码头扛包的，三十来岁；名字由 A 定"}
  },
  "cards": []
}
```

- `_meta.owner` 必须等于归属表里这个路径的主人（校验器查）。
- `persons` 块可选：本文件引入的新人物。人物登记 = `data/cast.json` 的 `npcs` + 所有 `persons` 块；同一个人物 id 只能登记一次。
- `cards` 里一张牌一个对象。

### 4.2 id 规则

- 正则 `^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$`，全小写 ASCII，点分段。**合入后不改名**（存档里有）；要改找 Claude。
- 第一段按类型固定：

| 类型 | 前缀 | 例 |
|---|---|---|
| person | `p.` | `p.linsao.1938.pawn_hairpin` |
| self | `self.` | `self.ruhua` |
| contact | `ct.` | `ct.zhouma` |
| event | `ev.` | `ev.1938.police_check`、`ev.any.wheel_go` |
| fate | `fa.` | `fa.any.fire_next_door` |
| big_fate | `bf.` | `bf.wheel`、`bf.any.mystery_box` |
| demand | `dm.` | `dm.1938.money.t1` |
| life | `lf.` | `lf.any.coal_out` |
| news | `nw.` | `nw.1938.wangshan_dock` |
| kept | `kp.` | `kp.ma_owes` |
| estate | `es.` | `es.jewel_cabinet` |
| night | `nt.` | `nt.tidy` |
| street | `st.` | `st.write_letters` |
| prison | `pr.` | `pr.cell` |
| item（物品→小游戏参数） | `it.` | `it.jewelry.hairpin` |
| pawn_ticket | `tk.` | `tk.1938.de196` |
| wheel | `wh.` | `wh.month` |
| wheel_segment | `ws.` | `ws.1938.month.caixing` |
| fortune_lot | `lot.` | `lot.g1.official` |
| cezi | `cz.` | `cz.shui` |
| almanac_day | `alm.` | `alm.shoudang` |
| dossier_page | `dp.` | `dp.linsao` |
| dossier_fragment | `df.` | `df.linsao.1938.hairpin` |
| goal | `gl.` | `gl.1938.keep_shop` |
| guide_step（新手指引步骤） | `gd.` | `gd.d1.deal` |
| rule_page（规矩页） | `rule.` | `rule.slots` |
| relic（老物件，肉鸽 v1） | `rl.` | `rl.stub_box`（只进 `CardIds.TYPE_PREFIX`，不进 `TYPES`；不发牌、不进任何区，§15） |
| source（客源，肉鸽 v1） | `ky.` | `ky.dockhands`（同上） |

- 第二段：人物 id、年代（`1938`）或 `any`（通用）、主题。
- 标签、人物 id、动作名、类别名同样只用 `[a-z0-9_]`。
- 主线节点 id：`s<年>.<slug>`（§3.5）。美术 id 见 §4.8。

### 4.3 公共字段（所有牌）

| 字段 | 类型 | 默认 | 含义 | 谁填 |
|---|---|---|---|---|
| `id` | String | 必填 | §4.2 | K/G |
| `type` | String | 必填 | §4.2 的类型名 | |
| `era` | Array[String] | 必填 | `["1938"]`、`["1938","1939"]` 或 `["*"]`（所有年代） | |
| `weight` | int | 10 | 在牌库里的基础权重（整数）；`0` = 不随机抽，只靠日程/效果发 | |
| `tags` | Array[String] | `[]` | 标签（要在某个 `tags/*.json` 里声明） | |
| `gold` | bool | false | 金色角色牌（§10）；只有 `person` 且有 `story_node` 才能为 true | |
| `story_node` | String | `""` | 主线节点 id | |
| `keepable` | bool | 按类型 | 能不能留在手里（`kept` 类恒为 true；`gold` 恒为 false） | |
| `expires_days` | int | 0 | 留着以后几天失效；0 = 不失效 | |
| `must_resolve` | bool | 按类型 | 今天要有个了断：打烊（确认后）还在手上就按“没理会”结算（§7.4.7）；**不挡打烊**。默认见 §4.7 开头 | |
| `conditions` | Cond | `{}` | 进牌库/被发出的条件（§5.3） | |
| `schedule` | Schedule | 无 | 按日程发（§4.4.4） | |
| `slots` | Array[Slot] | `[]` | 牌面上的格子（§4.4.1） | |
| `check` | Check | 无 | 格子的检定（§4.4.2） | |
| `choices` | Array[Choice] | `[]` | 选项（§4.4.3） | |
| `effects` | Dict[钩子名 → Array[Effect]] | `{}` | 各时刻执行的效果（§4.4.5） | |
| `art` | String | `""` | 美术 id（§4.8） | |
| `stage` | Dictionary | 无 | 演出块：谁上场、背景、道具、效果、对白的键（§4.7.24）；只许 person event fate big_fate life news street prison demand night pawn_ticket 带 | K/G |
| `brief` | String | 必填 | 设计说明（AI/策划写，**永不发行**） | |
| `_provenance` | Dict | 必填 | `{"by": "ai", "task": "K01", "date": "2026-10-14"}` | |

- 逻辑上每张牌都有 `text{title, body, choices, slots, lines, outcomes…}`，**只有人写**；物理上它放在正文覆盖层文件里（§4.5），由 CardDB 读进来合到牌上。所以骨架文件里**不许出现** `text`、`title`、`body`、`label`、`name`、`lines`、`desc` 等正文字段（校验 V04）。演出块 `stage` 里的对白也只是键（`ref`），正文同样在覆盖层。
- 头像、插图都用美术 id：人物牌的 `art` 一般就是那个人物的 `portrait.<person>`。
- **除了 `brief`、`_meta.brief`、`_doc` 以外的任何字符串都不许含中文**（校验器查 CJK 字符）。
- `minigame`（固定出哪个小游戏）只许出现在：pawn_ticket；`kind` 为 `telegram` / `letter` 的 news；`weight: 0` 且有 `schedule` 的 person（新手教学用）。其他牌由 G04 按物品数据随机挑（V33）。
- 未知字段报错；以 `_` 开头的字段（`_doc`、`_provenance`）放行。

### 4.4 子结构

#### 4.4.1 Slot（格子）

```json
{"id": "cash", "accepts": ["money"], "attr": "", "tags": ["official"], "money_per_coin": 10,
 "item_match": {"cat": "rice"}, "required": false, "max": 1, "pay": false, "brief": "钱"}
```

| 字段 | 说明 |
|---|---|
| `id` | 卡内唯一，`[a-z0-9_]` |
| `accepts` | `money` `self` `contact` `kept` `item` `news` 的子集 |
| `attr` | 收人时按哪项属性给铜钱：`eye` 眼力 · `tongue` 口才 · `pull` 门路 · `nerve` 胆量 |
| `tags` | 格子的性质（`official` 官面、`papers` 证件、`favor` 人情……），留着的牌的加成按它匹配 |
| `money_per_coin` | 放钱时每多少钱给 1 枚铜钱（省略用 `slots.json` 的默认）【待调】 |
| `item_match` | 收物品时的要求（`cat` / `template`） |
| `required` | 必须放了东西才能掷 |
| `max` | 最多放几样（默认 1） |
| `pay` | true = 放进来的钱是“交上去”（条子），不是用来换铜钱 |

#### 4.4.2 Check（检定）

```json
{"need": 2, "on_success": [], "on_fail": []}
```
放进格子的东西合计：人 = 属性点数枚铜钱；钱 = 数目 ÷ `money_per_coin`（向下取整）；物品、消息 = `slots.json` 里的 `item_coins` / `news_coins`；留着的牌 = 它的 `slot_bonus`（可能是若干**正面**直接算数，或 `auto_pass` 直接过）。掷出的正面 + 直接算数的正面 ≥ `need` 就成；有 `auto_pass` 直接成，不掷。铜钱上限 `slots.json.max_coins`【待调】。

#### 4.4.3 Choice（选项）

```json
{"id": "move_goods", "conditions": {}, "cost": {"money": 0},
 "effects": [],
 "check": {"slots": [{"id": "man", "accepts": ["self", "contact"], "attr": "nerve"}], "need": 2,
           "on_success": [], "on_fail": []},
 "almanac": ["repair"], "brief": "搬货（掷胆量）"}
```
- 选了有 `check` 的选项：先打开它的格子，放好后掷；没有 `check` 的直接执行 `effects`。
- `cost.money` 选这个选项要先付的钱；付不起选项变灰（原因键 `g03.reason.money`）。
- `almanac`：这个选项算黄历里的哪些动作（§9.4）。

#### 4.4.4 Schedule（日程）

```json
{"stage_day": 2, "order": 1}
{"stage_day": [5, 9], "when": {"heat_tier_gte": 1}, "order": 2}
{"when": {"story": ["s1938.wangshan", "met"]}, "once": true}
```
- `stage_day` 一个数 = 那一天；两个数 = 窗口里第一个满足 `when` 的那天；只有 `when` = 满足当天早上发（每关最多一次，`once` 默认 true）。
- `order` 同一天多张时的先后（金色牌照样排在最前）。

#### 4.4.5 效果钩子名

| 钩子 | 什么时候 | 用在哪些类型 |
|---|---|---|
| `on_deal` | 发到手上时 | 全部 |
| `on_resolve` | 以任何方式处理完以后（在具体钩子之后） | 全部 |
| `on_expire` | 期限到了还没处理：打烊确认后还在手上、要了断的牌（人物——个别人记仇、金色牌、事件、命运、街头、大赌，§7.4.7）；生活牌到期；留着的牌、手上能留的牌过期；条子到期见 §7 | 全部 |
| `on_accept` / `on_refuse` / `on_leave` | 成交 / 你拒绝 / 客人等不下去走了 | person |
| `on_keep` / `on_play` | 留下 / 打进格子或香案 | kept 和可留的牌 |
| `on_read` / `on_inform` | 看了 / 当消息交给条子 | news |
| `on_choose` | 选了这张夜牌（带 `choices` 的夜牌先执行所选项的 `effects`） | night |
| `on_complete` | 档案页补齐 | dossier_page |
| `on_done` / `on_fail` | 目标达成 / 没达成 | goal |

### 4.5 正文覆盖层（只有人写）

> **框架版收尾默认（2026-10-22，Claude），主创可改**：正文分四层，CardText 逐字段从上往下找第一个非空字符串——
> 1）剧情插件 `packs/<id>/text/**`（路径、键与 `data/cards/text/**` 一一镜像；每个插件一层，按清单 `pack.json` 的 `order` 叠放，`order` 大的、同 `order` 时 id 靠后的在上）；
> 2）人写层 `data/cards/text/**`；3）AI 基础层 `data/cards/text_ai/**`；4）都没有：默认空串（界面用 `CardText.has_text()` 跳过空的拍子），开发开关（`-- --show-drafts` 或项目设置 `dehoudang/cards/show_drafts`）开着时才给【稿】+ brief。
> 各层分开存，不合并（插件只写 `body` 时牌名照旧用下面的层）。插件清单字段、来源规则（`source: human|ai`，`_provenance` 分别照人写层 / AI 层的格式）、坏插件只警告并跳过、发行与 AI 声明见 `docs/cards/PLUGINS.md`。只带正文的插件不改 `CardDB.hash()`。
> 正文层（人写坏文件、`text_ai/**`、插件）的问题记进 `CardDB.warnings()`，不进 `errors()`，不挡新局；`validate_main.gd` 照样报 V26（插件）/ V27（不带声明版出现 AI 插件、发行缺字）。

- 路径镜像：`data/cards/<相对路径>.json` 的正文在 `data/cards/text/<相对路径>.text.json`。例：`data/cards/era/1938/people.json` → `data/cards/text/era/1938/people.text.json`。
- 界面键：`data/cards/ui_keys/<ID>.json` → `data/cards/text/ui/<ID>.text.json`；观察键：`data/cards/minigames/obs/<kind>.json` → `data/cards/text/minigames/obs/<kind>.text.json`；人物名字：`data/cards/text/persons.text.json`；物品：`data/cards/text/items.text.json`（键 `item.<cat>.<variant>`）；新手指引：`data/cards/guide/steps.json` → `data/cards/text/guide/steps.text.json`、`rule_pages.json` → `data/cards/text/guide/rule_pages.text.json`；开场：`data/cards/era/<年>/stage.json` → `data/cards/text/era/<年>/stage.text.json`（键 `stage.<年>`）；电码本：`data/cards/text/codebook.text.json`（键同 `codebook.json` 里的 `key`）；F1 帮助的操作说明是 C10 的界面键 `c10.help.*`（B 写）。

```json
{
  "_meta": {"owner": "A", "schema": 1},
  "p.linsao.1938.pawn_hairpin": {
    "title": "……", "body": "……",
    "lines": {"greet": "……", "ask": "……", "counter": "……", "accept": "……", "leave": "……", "refused": "……", "impatient": "……"},
    "_provenance": "human:A:2026-11-20"
  }
}
```
```json
{"_meta": {"owner": "B", "schema": 1},
 "c04.tier.harsh.pay": {"t": "……", "_provenance": "human:B:2026-12-01"}}
```

- 正文引用写法（效果 `notice`、视图里的 `*_key` 字段）：界面键直接写（`g04.reason.sell`）；牌上的字段写成 `<牌 id>#<字段路径>`（`ev.1938.police_check#outcomes.fail`）。占位参数写 `{name}`，由 `CardText` 代入。
- `_provenance` 在人工层 `data/cards/text/**` 只认 `^human:(A|B):\d{4}-\d{2}-\d{2}$`；在 W2（10-18，#212）新增的 AI 台词层 `data/cards/text_ai/**`（与 `data/cards/text/**` 同结构、同键，AI 线可写；人写层仍只归人）在文件 `_meta._provenance` 登记 `ai:<工具>:<模型>:<日期>:<提示词或任务 id>`，`CardText` 按字段查找顺序为 `human → ai → 开发版【稿】+ brief`（不带声明版出包时排除 `text_ai/**`；2026-10-22 起最上面多一层剧情插件，缺字默认空串，见本节开头）。
- 各类型发行时必须有的正文字段：

| 类型 | 必填字段 |
|---|---|
| person | `title` `body` `lines.greet`，按来意：当/卖/买 `lines.accept` `lines.leave` `lines.refused`；有选项的 `choices.<id>` |
| self / contact | `title` `body` |
| event / fate / big_fate / life / street / prison | `title` `body` `choices.<id>` `slots.<id>`；有检定的 `outcomes.success` `outcomes.fail` |
| demand | `title` `body` `slots.<id>` `outcomes.success` `outcomes.fail` `lines.issue` |
| news | `title` `body` |
| kept | `title` `body` `use` |
| estate | `title` `body` `mortgaged` |
| night | `title` `body` |
| wheel | `title` |
| wheel_segment | `title` `body` |
| fortune_lot | `verse` `gloss` |
| cezi | `char` `has` `none` |
| dossier_page / dossier_fragment | `title` / `body` |
| goal | `title` `done` `failed` |
| pawn_ticket | `body` |
| guide_step | `say`（教的人说的一句）`bubble`（锚点旁的气泡：现在可以做什么） |
| rule_page | `title` `body` |
| stage（`stage.<年>`） | `intro.p1` … `intro.p<n>`（n = `intro_paras`） |
| 电码本的词 | `word` |
| 有非空 `effects.on_expire`、会出现在打烊清单里的牌（person event fate big_fate street life） | 另加 `outcomes.ignored`（打烊确认里“没理会会怎样”那一句，§7.4.7） |
| 带演出块 `stage` 的牌 | `stage.intro` 与 `stage.after.*` 里每一拍的 `ref` 指向的字段（`body` `lines.*` `outcomes.*` `choices.*`） |

- 对话框会把一段正文里的空行（`\n\n`）拆成几句依次说；名字用 `{name}`、报价用 `{price}` 这类参数（§4.7.24）。演出旁白的通用句（“某人进了门”“某人出了门”）是 W0 的界面键 `w0.stage.enter` `w0.stage.at_door` `w0.stage.leave`（参数 `{name}`，A 写在 `data/cards/text/ui/W0.text.json`）。

- **允许的字段** = 本类型的必填字段 + `lines.*` `outcomes.*` `choices.*` `slots.*` `use`（例：`ct.ma#lines.leave` 合法）；别的字段 V26 报错。

- 缺正文（框架版收尾默认，主创可改）：默认返回空串，`CardText.has_text(ref)` 为假，界面跳过这一拍 / 这一页（对话框不演空句，开月过场不翻空页）。开发开关开着时（非发行版；命令行 `-- --show-drafts`、项目设置 `dehoudang/cards/show_drafts`、测试库 `card_t.gd` 默认打开）`CardText` 返回草稿标记 + 该牌（或该键）的 `brief`，界面用草稿样式（灰、斜）显示。草稿标记（`【稿】`）放在 `data/cards/_dev/strings.json` 的 `draft_mark`（`.gd` 里不能写中文；`_dev/` 不进包）。发行版永远不给草稿——K15 的审核保证发行包里不缺。

### 4.6 规则文件（`data/cards/rules/*.json`）

格式：`{"_meta": {"owner": "G03", "schema": 1}, "_doc": ["……"], <键>: <值>}`；值全是整数/字符串/数组/对象。`balance_overrides.json`（G06）按同名文件、同名路径深合并在最后：`{"slots": {"money_per_coin": 12}}`。W0 按下面填初值，之后由主人维护。

```json
{"_meta": {"owner": "G01", "schema": 1},
 "person": {"min": 3, "max": 4, "market_bonus": 1, "rain_penalty": 1, "rep_tier_bonus": [0, 0, 0, 1, 1]},
 "event": {"per_day": 1}, "news": {"num": 1, "den": 2},
 "night_offer": 3, "street_per_day": 3,
 "caps": {"kept": 5, "contacts": 3, "hand_soft": 10},
 "hand_order": ["gold", "prison", "big_fate", "event", "fate", "person", "life", "news"],
 "scripted_days": {"0": [1, 2, 3]}}
```
（`deal.json`。`hand_order` 里的 `gold` 指 `gold: true` 的牌，其余是类型名，没列出的类型排在最后；只由 `CardPiles.order_hand()` 用（§10.2）【先后：主创已确认 10-13】。`scripted_days`：关号 → 本关第几天；这几天只发日程、钉签和队列里的牌，**不随机抽**任何牌库（新手教学日，§7.10.11）【主创已确认 10-13】。）

```json
{"_meta": {"owner": "G03", "schema": 1},
 "head": {"num": 1, "den": 2}, "money_per_coin": 10, "item_coins": 1, "news_coins": 1, "max_coins": 12,
 "person_once_per_day": true}
```
（`slots.json`）

```json
{"_meta": {"owner": "G03", "schema": 1},
 "rep": {"min": 0, "max": 100, "start": 10, "tiers": [0, 20, 40, 60, 80]},
 "heat": {"min": 0, "max": 100, "start": 0, "tiers": [0, 20, 40, 60, 80], "arrest_at": 100, "decay_per_day": 1},
 "conscience": {"min": -100, "max": 100, "start": 0, "low": -20, "very_low": -50},
 "attr": {"min": 0, "max": 6}}
```
（`meters.json`）

```json
{"_meta": {"owner": "G03", "schema": 1},
 "issue_weekday": 0, "deadline_days": 7, "delay": {"days": 3, "tier_up": 1, "max": 1},
 "tier_by_stage": [0, 1, 1], "tier_heat_step": 40, "max_tier": 3,
 "fail": {"t0": [{"op": "pay", "amount": 30, "payee": "levy", "reason": "g03.reason.fine", "short": "partial"}],
          "t1": [{"op": "shop_closed", "days": 3}],
          "t2": [{"op": "estate_seize", "pick": "worst"}],
          "t3": [{"op": "arrest", "reason": "g03.arrest.demand"}]}}
```
（`demand_rules.json`）

```json
{"_meta": {"owner": "G04", "schema": 1},
 "start_money": 340, "shelf_cap": 12, "max_rounds": 5,
 "tiers": {"pay": {"harsh": 55, "fair": 75, "kind": 95}, "receive": {"harsh": 130, "fair": 105, "kind": 85}},
 "patience": {"offer_min": 10, "counter_min": 10},
 "ticket": {"term_days": 15, "grace_days": 3, "rate_pct_month": 3, "storage_permille_month": 5},
 "redeem": {"squeeze_pct": 20, "come_num": 2, "come_den": 3, "compensate_pct": 120},
 "appraise": {"clear_permille": 700, "partial_permille": 350}}
```
（`economy.json`；`tiers.pay` 是“你付钱”时相对客人报价的百分比，`receive` 是“你收钱”时相对看得见的估价的百分比——都只用看得见的数算；`compensate_pct` 东西已被你卖掉时按当本赔多少【待调】；`appraise` 是小游戏 `quality_permille` 的清楚/一半门槛【待调】）

```json
{"_meta": {"owner": "G06", "schema": 1},
 "mortgage": {"interest_due": "month_close"},
 "short": {"order": ["goods", "estate", "street"]},
 "street": {"redeem_shop_pct": 100},
 "prison": {"max_days": 3}}
```
（`ladder.json`，G06：抵押利息什么时候付、钱不够阶梯的顺序、赎回铺面按押值的百分比【待调】；`prison.max_days` 牢房连续几晚没出来按打点失败【待调】（§7.4.7）——1.2 新加的键，G06 加进自己的 `ladder.json`（W0 建的初值文件），开 `[shared] G06→G01` 在 `RULE_KEYS` 里登记必需键）

```json
{"_meta": {"owner": "C16", "schema": 1},
 "gap_ms": 2000, "fade_in_ms": 300, "fade_out_ms": 700, "fade_fast_ms": 250,
 "default_seconds": 16, "max_new_per_day": 16, "bubble_max_w": 360}
```
（`guide.json`，C16：新手指引两步之间的间隔、渐显渐隐、默认亮多久、每天最多新亮几步、气泡最宽多少像素【待调】；规则文件里没有小数，时间都用毫秒整数）

```json
{"_meta": {"owner": "G05", "schema": 1},
 "fate": {"min_gap": 3, "max_gap": 4, "num": 1, "den": 2, "heat_tier_bonus": [0, 0, 1, 1, 2]},
 "big": {"max_per_stage": 2, "once_per_crisis": true,
         "crisis": {"cash_short": {"estates_left_lte": 1}, "arrested": {}, "heat_max": {}, "street_long": {"days_gte": 3}}}}
```
（`fate.json`）

```json
{"_meta": {"owner": "G05", "schema": 1},
 "lot": {"window_days": 3, "pick": 2, "conscience_harsh_below": -20, "harsh_bias_pct": 300},
 "cezi": {"offer": 6},
 "almanac": {"reward_rule": "yi_done_and_no_ji"},
 "wheel": {"default_money_per_unit": 5, "default_unit_widen_pct": 15, "default_max_units": 6}}
```
（`fortune.json`）

`stages.json`（G02）：
```json
{"_meta": {"owner": "G02", "schema": 1},
 "stages": [
  {"index": 0, "era": "1938", "start": "1938-03-01", "days": 30, "currency": "fabi", "price_index": 100, "market_every": 5, "market_offset": 2},
  {"index": 1, "era": "1939", "start": "1940-01-09", "days": 30, "currency": "fabi", "price_index": 160, "market_every": 5, "market_offset": 0, "_doc": "1939 腊月按农历；公历起点待 K13 核对"},
  {"index": 2, "era": "1940", "start": "1940-03-01", "days": 30, "currency": "fabi", "price_index": 220, "market_every": 5, "market_offset": 1}
 ]}
```

### 4.7 每种牌的格式与例子

下面每个例子都是合法数据，W0 会原样放进 `data/cards/_examples/`（例子集，和真数据分开读，§4.10；例子用的原因键登记在 `_examples/ui_keys.json`）。各类型的**默认**：`must_resolve` 为 true 的有 person、event、fate、big_fate、street、prison；`keepable` 默认 false，kept 恒 true。`must_resolve` 的含义见 §4.3（1.2 起：今天要了断、打烊时按没理会结算，不挡打烊）；每种牌打烊时没处理会怎样见 §7.4.7 的表。

#### 4.7.1 person（人物牌）

专有字段：`person`（人物 id）· `intent`：`pawn` 来当 · `sell` 来卖 · `buy` 来买 · `redeem` 来赎 · `help` 求助 · `ask` 打听 · `story` 主线（只有选项）· `item`（当/卖：`template` 或 `cat`）· `want`（买：`cats`、`budget_pct`）· `asking`（客人开口报的价，相对看得见的估价：`pct` 区间）· `floor`（隐藏底线：`pct` 区间）· `patience_min`（隐藏耐心分钟区间）· `impatience`：`leave` 或 `raise` · `term_days`（当期，省略用 `economy.json`）· `minigame_hint`（建议的小游戏，**不约束**，引擎仍按物品数据随机）· `minigame`（**固定**出这个小游戏；只许用在 `weight: 0` 且有 `schedule` 的牌上，给新手教学用，V33）· `choices`（柜台上的额外按钮，例“白给他几个钱”，经 `card.choose`）。

```json
{
  "id": "p.linsao.1938.pawn_hairpin", "type": "person", "person": "linsao",
  "era": ["1938"], "weight": 10, "tags": ["woman", "boat", "poor", "omen_water"],
  "intent": "pawn",
  "item": {"template": "jewelry.hairpin"},
  "asking": {"pct": [90, 120]}, "floor": {"pct": [55, 75]},
  "patience_min": [60, 120], "impatience": "leave", "term_days": 15,
  "conditions": {"not": {"person_state": ["linsao", "gone"]}},
  "effects": {
    "on_accept": [{"op": "dossier", "frag": "df.linsao.1938.hairpin"}],
    "on_refuse": [{"op": "conscience", "delta": -1}]
  },
  "art": "portrait.linsao",
  "brief": "船工的妻子，怀孕八个月，来当一支金簪；簪子分量略轻，像补过。来当后得当票，15 天到期。",
  "_provenance": {"by": "ai", "task": "K01", "date": "2026-10-14"}
}
```

金色角色牌（主线人物在主线节点上）：

```json
{
  "id": "p.brother.1938.farewell", "type": "person", "person": "brother",
  "era": ["1938"], "weight": 0, "tags": ["family", "story", "omen_far", "omen_family"],
  "gold": true, "story_node": "s1938.brother_farewell", "intent": "story",
  "schedule": {"stage_day": 2, "order": 1},
  "choices": [
    {"id": "listen", "effects": [
      {"op": "story", "node": "s1938.brother_farewell", "outcome": "listened"},
      {"op": "add_card", "card": "kp.brother_note", "to": "kept"},
      {"op": "dossier", "frag": "df.brother.1938.farewell"}], "brief": "听他交代完"},
    {"id": "argue", "effects": [
      {"op": "story", "node": "s1938.brother_farewell", "outcome": "argued"},
      {"op": "dossier", "frag": "df.brother.1938.farewell_cold"}], "brief": "和他争"}
  ],
  "effects": {"on_expire": [
    {"op": "story", "node": "s1938.brother_farewell", "outcome": "ignored"},
    {"op": "dossier_gap", "frag": "df.brother.1938.farewell"}]},
  "art": "portrait.brother",
  "brief": "第二天哥哥离家，把铺子交给你并留一句交代。没理他：他留下字条走了，交代没听全，档案页缺这一块。",
  "_provenance": {"by": "ai", "task": "K01", "date": "2026-10-14"}
}
```

来买的人：`"intent": "buy", "want": {"cats": ["art"], "budget_pct": [80, 130]}`（预算相对物品真值，隐藏）。来赎：一般由 G04 按当票生成；主要人物要有自己的 `redeem` 牌（`"intent": "redeem"`，台词不同），其他人用 `p.any.redeem`（K01 写在 `passersby.json`）。过路客原型：`"person": "stranger_waixiang", "era": ["*"]`。新手教学的来当客人（K16）：`"weight": 0, "schedule": {"stage_day": 1, "order": 1}, "minigame": "spot"`——这样第 1 天一定出找不同。

**个别人记仇**（§7.4.7）：打烊时还没接的客人走掉；要记仇的那几位写 `"effects": {"on_expire": [{"op": "flag", "key": "grudge_linsao"}, {"op": "rep", "delta": -1}]}` 这类，后续的牌用条件读旗标；不记仇的不写。

#### 4.7.2 self（你自己）

```json
{
  "id": "self.ruhua", "type": "self", "person": "ruhua", "era": ["*"], "weight": 0,
  "attrs": {"eye": 2, "tongue": 1, "pull": 1, "nerve": 1},
  "art": "portrait.ruhua",
  "brief": "主角沈如花自己，可以放进格子；属性会随事件成长。起始属性待调。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```
（K09 在 `self.json` 的 `persons` 块里登记 `ruhua`。）

#### 4.7.3 event（事件牌）

```json
{
  "id": "ev.1938.police_check", "type": "event", "era": ["1938"], "weight": 10,
  "tags": ["official", "police", "search", "omen_official"],
  "slots": [
    {"id": "paper", "accepts": ["kept"], "tags": ["papers"], "brief": "证件"},
    {"id": "cash", "accepts": ["money"], "tags": ["official"], "money_per_coin": 10, "brief": "钱"},
    {"id": "man", "accepts": ["self", "contact"], "attr": "nerve", "brief": "胆大的人"}
  ],
  "check": {"need": 2,
    "on_success": [],
    "on_fail": [{"op": "heat", "tier": 1}, {"op": "flag", "key": "police_knows_name"}, {"op": "kept_risk", "tags_any": ["contraband", "leverage"]}]},
  "art": "illus.ev.1938.police_check",
  "brief": "警察挨家查良民证。放良民证（留着的牌，证件）直接过；没有就放钱和胆大的人掷铜钱，要 2 个正面。没过：风声上一档，警察记下名字；手上来路不明的东西会被翻出来。",
  "_provenance": {"by": "ai", "task": "K02", "date": "2026-10-14"}
}
```

算命摊、庙会这类事件用 `opens_fortune`（`"lot"` `"cezi"` `"both"`）、`opens_wheel`（轮盘 id）和 `cost`：
```json
{
  "id": "ev.any.fortune_teller", "type": "event", "era": ["*"], "weight": 4, "tags": ["fortune", "omen_stranger"],
  "must_resolve": false, "opens_fortune": "both", "cost": {"money": 3},
  "choices": [{"id": "pass", "effects": [], "brief": "不算"}],
  "art": "illus.ev.any.fortune_teller",
  "brief": "街口来了个算命先生（也可以是测字摊）。花几个钱求一支签或测个字；不算就走过去。",
  "_provenance": {"by": "ai", "task": "K02", "date": "2026-10-14"}
}
```

#### 4.7.4 fate（命运牌）

专有：`valence`：`good` `bad` `mixed`（隐藏，用于权重和签的等第）。

```json
{
  "id": "fa.any.fire_next_door", "type": "fate", "era": ["*"], "weight": 6,
  "valence": "mixed", "tags": ["fire", "disaster", "omen_fire"],
  "choices": [
    {"id": "move_goods",
     "check": {"slots": [{"id": "man", "accepts": ["self", "contact"], "attr": "nerve", "max": 2}], "need": 2,
               "on_success": [{"op": "rep", "delta": 3}],
               "on_fail": [{"op": "item_lose", "match": {"pick": "best"}, "n": 1, "reason": "k04.reason.fire"},
                           {"op": "person_state", "person": "ruhua", "state": "hurt", "days": 2}]},
     "almanac": ["repair"], "brief": "搬货（掷胆量）"},
    {"id": "call_police", "effects": [{"op": "heat", "delta": 5}, {"op": "item_lose", "match": {"pick": "any"}, "n": 1, "reason": "k04.reason.fire"}], "brief": "报警"},
    {"id": "shut_door", "effects": [{"op": "item_lose", "match": {"pick": "any"}, "n": 2, "reason": "k04.reason.fire"}, {"op": "rep", "delta": -3}], "brief": "关门躲"}
  ],
  "effects": {"on_expire": [{"op": "item_lose", "match": {"pick": "any"}, "n": 2, "reason": "k04.reason.fire"}, {"op": "rep", "delta": -3}]},
  "art": "illus.fa.any.fire_next_door",
  "brief": "邻铺失火，火往这边烧。①搬货（掷胆量）②报警（风声动）③关门躲（损货、口碑掉）。没理会（打烊时还没处理）：当关门躲算。",
  "_provenance": {"by": "ai", "task": "K04", "date": "2026-10-14"}
}
```

#### 4.7.5 big_fate（大命运）

v1.1：快输时发的那张是 `bf.wheel`，处理它 = 转大轮盘；v1 的“大赌”是扇区落下后发到手上的牌。**只有 `bf.wheel` 由 G05 在危机时发**；其他大命运牌一律 `weight: 0`，只由大轮盘扇区的效果（`add_card`）发到手上（V36）。专有：`opens_wheel`、`crisis`（这张大赌适合哪种危机，K10 排扇区时参考）、`valence`。

```json
{
  "id": "bf.wheel", "type": "big_fate", "era": ["*"], "weight": 0, "tags": ["big"],
  "opens_wheel": "wh.big",
  "art": "illus.bf.wheel",
  "brief": "快输的时候出现：处理它就是转一次大轮盘（翻身／平安／坠底），转之前可以往香案上放东西。",
  "_provenance": {"by": "ai", "task": "K02", "date": "2026-10-14"}
}
```
```json
{
  "id": "bf.any.mystery_box", "type": "big_fate", "era": ["1938", "1939", "1940"], "weight": 0,
  "crisis": ["cash_short"], "valence": "mixed", "tags": ["contraband", "stranger"],
  "choices": [
    {"id": "take", "effects": [{"op": "money", "delta": 300, "reason": "k02.reason.bigfate"}, {"op": "add_card", "card": "kp.mystery_box", "to": "kept"}], "brief": "收下"},
    {"id": "decline", "effects": [], "brief": "不收"}
  ],
  "effects": {"on_expire": []},
  "art": "illus.bf.any.mystery_box",
  "brief": "陌生人出大价钱请你保管一箱东西七天。收下：钱够还清抵押；箱子成了留着的牌，被查到直接被抓。没理他（打烊时还没处理）：当不收，人走了。",
  "_provenance": {"by": "ai", "task": "K02", "date": "2026-10-14"}
}
```

#### 4.7.6 demand（条子）

专有：`kind`：`money` `goods` `people` `info` · `tier` 0–3（小/中/大/要命）· `deadline_days`（省略用 `demand_rules.json`）· `resolve`（按类，见下）· `on_fail`（可选，覆盖默认阶梯）。

```json
{
  "id": "dm.1938.money.t1", "type": "demand", "era": ["1938"], "weight": 10,
  "kind": "money", "tier": 1, "tags": ["levy", "official"],
  "resolve": {
    "money": {"amount": 60, "jitter_pct": 15, "heat_tier_pct": 10},
    "haggle": {"slots": [
        {"id": "favor", "accepts": ["kept"], "tags": ["favor"]},
        {"id": "talker", "accepts": ["self", "contact"], "attr": "tongue"}],
      "need": 2, "tier_down": 1}
  },
  "slots": [{"id": "cash", "accepts": ["money"], "pay": true}],
  "art": "illus.dm.money",
  "brief": "维持会摊派（伪维持会名目），七天内交 60 蚨上下。可以直接交钱；或放人情牌、口才高的人去讲价，成了降一档。办不成按中档吃亏：查封三天。",
  "_provenance": {"by": "ai", "task": "K07", "date": "2026-10-14"}
}
```
其他三类的 `resolve`：
```json
{"goods": {"cat": "rice", "n": 1}, "substitute": {"money": 50}}
{"people": {"n": 1, "away_days": 7, "return_check": {"attr": "nerve", "need": 1}}, "substitute": {"money": 40}}
{"info": {"n": 1}, "fabricate": {"attr": "nerve", "need": 2, "on_fail": [{"op": "heat", "tier": 1}]}}
```
- **办法都是选项**，经 `card.choose {uid, choice}` 选，id 保留（数据里不用写 `choices`，G03 按 `kind` 和 `resolve` 生成可选的几项）：`pay` 交（钱/货放进 `pay: true` 的格子）· `haggle` 讲价（`resolve.haggle` 的格子与检定，成了降 `tier_down` 档）· `substitute` 顶替（交 `resolve.substitute` 的钱）· `fabricate` 编一个（`resolve.fabricate` 的检定）· `send_person` 派人（要人）· `inform` 交消息（要消息）。选好、格子放好以后 `demand.submit` 结算；`demand.delay` 是拖一拖。
- 要货：从货架放合适的物品；或交 `substitute` 的钱。
- 要人：放你自己或一个人脉，他这 `away_days` 天不能用；回来那天发系统牌 `ev.any.demand_return`（K07，“回来了吗”），用他的属性当场掷（看得见），不成就是没回来（`person_state` → `gone`）。
- 要消息：放一张留着的消息牌（会执行那张消息的 `on_inform`，伤到那个人）；或“编一个”：掷胆量，不成按 `on_fail`。

#### 4.7.7 life（生活牌）

专有：`due_days`（几天内处理）· `waivable`（回家吃饭能免掉坏处）· `season`（季节，0 春…3 冬）。

```json
{
  "id": "lf.any.coal_out", "type": "life", "era": ["*"], "weight": 8, "tags": ["home", "fuel", "omen_family"],
  "season": [3, 0], "due_days": 3, "waivable": true, "must_resolve": false,
  "choices": [
    {"id": "buy", "effects": [{"op": "pay", "amount": 12, "payee": "coal_shop", "reason": "k06.reason.coal", "short": "ladder"}], "brief": "买煤"},
    {"id": "endure", "effects": [{"op": "attr", "who": "ruhua", "attr": "nerve", "delta": -1, "days": 3}], "brief": "挨冻"}
  ],
  "effects": {"on_expire": [{"op": "attr", "who": "ruhua", "attr": "nerve", "delta": -1, "days": 3}]},
  "art": "illus.lf.any.coal_out",
  "brief": "煤用完了。买煤，或者挨冻（几天里胆量少一点）。拖到期限当挨冻处理；回家吃饭能免掉坏处。",
  "_provenance": {"by": "ai", "task": "K06", "date": "2026-10-14"}
}
```

#### 4.7.8 news（消息牌）

专有：`kind`：`price` `lead` `rumor` `letter` `paper` `telegram` · `source`（谁说的，人物 id 可空）· `info_about`（关于谁；可以交给要消息的条子）· `minigame`（只有 `telegram`/`letter` 可以带：`decode` 或 `fragments`；点牌 → `mg.request {uid}`，不带物品）。

```json
{
  "id": "nw.1938.wangshan_dock", "type": "news", "era": ["1938"], "weight": 6,
  "kind": "rumor", "source": "zhouma", "info_about": "wangshan",
  "keepable": true, "expires_days": 5, "must_resolve": false, "tags": ["info", "dock", "omen_water"],
  "effects": {
    "on_read": [{"op": "dossier", "frag": "df.wangshan.1938.dock"}],
    "on_inform": [{"op": "dossier_gap", "frag": "df.wangshan.1938.trust"}, {"op": "person_state", "person": "wangshan", "state": "away", "days": 10}, {"op": "conscience", "delta": -3}]
  },
  "art": "illus.nw.rumor",
  "brief": "周妈说王山昨晚在码头出现过。看了补王山一块碎片；留着能交给‘要消息’的条子，交了会伤到王山，档案页断掉一块。",
  "_provenance": {"by": "ai", "task": "K08", "date": "2026-10-14"}
}
```

#### 4.7.9 kept（留着的牌）

专有：`kind`：`favor` `paper` `hard` `leverage` `blank_ticket` `token` · `slot_bonus`（进格子时的加成，按格子的 `tags` 匹配；`heads` 直接算几个正面，或 `auto_pass` 直接过，或 `coins` 加几枚铜钱）· `consumed_on_use` · `risk`（带着它被查到时）· `incense_units`（放上香案算几份）。

```json
{
  "id": "kp.ma_owes", "type": "kept", "era": ["*"], "weight": 0,
  "kind": "favor", "keepable": true, "expires_days": 20, "tags": ["favor", "official"],
  "slot_bonus": [{"slot_tags_any": ["official"], "heads": 3}],
  "consumed_on_use": true, "incense_units": 2,
  "art": "illus.kp.ma_owes",
  "brief": "马万利欠你一次：放进任何官面上的格子算 3 个正面；用了就没了；20 天后不灵了。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```
```json
{
  "id": "kp.mystery_box", "type": "kept", "era": ["*"], "weight": 0,
  "kind": "hard", "keepable": true, "expires_days": 7, "tags": ["contraband"],
  "slot_bonus": [],
  "risk": [{"op": "arrest", "reason": "k09.arrest.contraband"}],
  "effects": {"on_expire": [{"op": "money", "delta": 100, "reason": "k09.reason.box_returned"}]},
  "art": "illus.kp.mystery_box",
  "brief": "替陌生人保管的箱子。七天后他来取、再给一笔；这期间被查到（kept_risk 命中 contraband）就直接被抓。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```
良民证：`"kind": "paper", "expires_days": 0, "tags": ["papers"], "slot_bonus": [{"slot_tags_any": ["papers"], "auto_pass": true}], "consumed_on_use": false`。

#### 4.7.10 contact（人脉）

专有：`person` · `attrs` · `passives`（`{"hook": 钩子, "effects": […]}`，钩子：`day_start` `deal` `demand_issue` `settle`）· `downsides`（同格式）· `mods`（常驻修正，同家当的 `while_mortgaged` 格式，另加 `appraise_pct {cat?/cats?, pct}`；`mods` 里的 `pct` 一律是**乘数**，100 = 不变、140 = 乘 1.4，和效果 op `price_mod` 的增量写法不同（框架版收尾默认，主创可改）；人物状态是 `away` `hurt` `jailed` `gone` 时不生效）· `leave_when`（`{"cond": …, "effects": […]}`）· `year_changes`（跨年：`{"to_era": "1939", "num": 1, "den": 3, "effects": […]}`）。

```json
{
  "id": "ct.ma", "type": "contact", "person": "ma", "era": ["1938", "1939", "1940"], "weight": 0,
  "attrs": {"eye": 1, "tongue": 2, "pull": 3, "nerve": 1}, "tags": ["official"],
  "passives": [{"hook": "demand_issue", "effects": [{"op": "demand_tier", "delta": -1}]}],
  "downsides": [{"hook": "day_start", "effects": [{"op": "heat", "delta": 2}]}],
  "leave_when": [{"cond": {"flag": "ma_offended"}, "effects": [{"op": "notice", "key": "ct.ma#lines.leave"}]}],
  "year_changes": [{"to_era": "1940", "num": 1, "den": 2, "effects": [{"op": "person_state", "person": "ma", "state": "changed"}]}],
  "art": "portrait.ma",
  "brief": "马万利（伪维持会任命的保长）：条子降一档，但风声每天涨。1940 年新官上任后可能换了身份。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```

#### 4.7.11 estate（家当）

专有：`order`（阶梯建议顺序）· `mortgage_value`（1938 年价，按物价指数换算）· `interest_pct_month` · `while_mortgaged`（修正列表）· `lose_if_unredeemed`（月底赎不回就没了）。
修正项（`mod`）：`no_intake_cat {cat}` 不能收这一类 · `shelf_cap {delta}` · `deal_count {type, delta}` · `pool_weight {pool, tags_any, pct}` · `kept_cap {delta}`。

```json
{
  "id": "es.jewel_cabinet", "type": "estate", "era": ["*"], "weight": 0, "order": 1,
  "mortgage_value": 80, "interest_pct_month": 5,
  "while_mortgaged": [{"mod": "no_intake_cat", "cat": "jewelry"}],
  "lose_if_unredeemed": false,
  "art": "illus.es.jewel_cabinet",
  "brief": "首饰柜：押出去换现钱，每月付利息；押着的时候不能收首饰。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```
其余：库房 `shelf_cap -4`；柜台 `deal_count person -1`；老宅 `pool_weight life pct 150`；铺面 `lose_if_unredeemed: true`（押出去的那个月照开，月底赎不回 → 街头）。

#### 4.7.12 night（夜牌）

```json
{
  "id": "nt.tidy", "type": "night", "era": ["*"], "weight": 10, "conditions": {"mode": "shop"},
  "effects": {"on_choose": [{"op": "price_mod", "scope": "shelf", "pct": 5, "days": 1}]},
  "almanac": ["repair"],
  "art": "illus.nt.tidy",
  "brief": "整理库房：货架上的东西擦洗归置，明天卖的时候稍好出手。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```
发电报：`"conditions": {"all": [{"day_gte": 3}, {"flag": "telegraph_ok"}]}`；早点睡：`{"op": "extra_deal", "type": "person", "n": 1, "day": "tomorrow"}`。夜牌可以带 `choices`（二选一这类）；选的时候 `night.choose {def, choice}`：

```json
{
  "id": "nt.family_dinner", "type": "night", "era": ["*"], "weight": 10, "conditions": {"mode": "shop"},
  "choices": [
    {"id": "waive_life", "effects": [{"op": "waive", "match": {"type": "life"}, "n": 1}], "brief": "抵掉一张生活牌的坏处"},
    {"id": "family_word", "effects": [{"op": "add_card", "card": "nw.any.family_word", "to": "hand", "in_days": 1}], "brief": "明天得到一张家人的消息"}
  ],
  "art": "illus.nt.family_dinner",
  "brief": "回家吃饭：一家人吃顿饭；二选一——抵掉一张生活牌的坏处，或者明天得到一张家人的消息。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```

#### 4.7.13 street（街头）

```json
{
  "id": "st.write_letters", "type": "street", "era": ["*"], "weight": 10, "tags": ["street", "letter"],
  "slots": [{"id": "you", "accepts": ["self"], "attr": "tongue"}],
  "check": {"need": 1, "on_success": [{"op": "money", "delta": 6, "reason": "k09.reason.street_work"}], "on_fail": []},
  "art": "illus.st.write_letters",
  "brief": "流落街头时：替人写信挣几个钱（掷口才）。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```

#### 4.7.14 prison（牢房）

```json
{
  "id": "pr.cell", "type": "prison", "era": ["*"], "weight": 0, "tags": ["prison"],
  "slots": [
    {"id": "bribe", "accepts": ["money"], "tags": ["official"], "money_per_coin": 20, "max": 3},
    {"id": "bail", "accepts": ["contact"], "attr": "pull", "tags": ["official"]},
    {"id": "favor", "accepts": ["kept"], "tags": ["official", "papers", "favor"], "max": 2}
  ],
  "check": {"need": 3,
    "on_success": [{"op": "heat", "delta": -30}],
    "on_fail": [{"op": "game_over", "reason": "prison"}]},
  "art": "illus.pr.cell",
  "brief": "被抓进牢房：放钱打点、人脉作保、留着的牌（人情、介绍信、金条），掷铜钱。成了出来（代价是放进去的东西）；不成，这一局结束，可从本月开头重来。",
  "_provenance": {"by": "ai", "task": "K09", "date": "2026-10-14"}
}
```
（1.2，§7.4.7：没处理就在牢里多待一晚——第二天铺子关门、不发人物牌；连续 `ladder.json.prison.max_days` 晚没出来按 `check.on_fail` 结算，可以从本关开头或续玩点重来。牢房牌视图里的 `days_left` = 还能在牢里待几晚。）

#### 4.7.15 item（物品 → 小游戏参数，K11）

```json
{
  "id": "it.jewelry.hairpin", "type": "item", "era": ["*"], "weight": 0,
  "template": "jewelry.hairpin",
  "minigames": ["weigh", "spot"],
  "weigh": {"tool": "dengzi", "claimed_fen": [280, 320], "dev_bad_pct": [3, 8], "dev_worn_pct": [0, 2]},
  "spot": {},
  "brief": "金簪：戥子称分量或对图鉴找不同。补过、掺假的分量轻 3%–8%，旧的轻 0%–2%。",
  "_provenance": {"by": "ai", "task": "K11", "date": "2026-10-14"}
}
```
```json
{
  "id": "it.silver.yuan_a", "type": "item", "era": ["*"], "weight": 0,
  "template": "silver.yuan_a",
  "minigames": ["coin_ring"],
  "coin_ring": {"ring_ms_good": [1200, 1600], "ring_ms_bad": [300, 700], "buzz_good": [0, 15], "buzz_bad": [40, 90], "pitch_cents_bad": [-300, -80]},
  "brief": "银元一种（具体版别由 A 定）。按枚计价、一般不称；吹一下贴耳听余音：足银余音细长，掺铜的短、闷、有杂音。",
  "_provenance": {"by": "ai", "task": "K11", "date": "2026-10-14"}
}
```
- `template` = `<cat>.<variant>`，指向 `data/town/item_templates.json` 或 `data/cards/items/templates_extra.json`。
- `templates_extra.json` 和现有模板同格式，但**所有文字字段写成空串**（名字、质地、成色描述等正文在 `data/cards/text/items.text.json`，由 A 写；开发版显示【稿】+ 本条 brief）。
- 参数里的 `*_bad`、`dev_bad_pct` 这类**规格**只有引擎（G04）读，用来算物理量；小游戏拿到的只有物理量（§8.2）。
- **10-25 鉴定改版的规格字段**（都可选，缺了引擎用 `economy.json` 的 `appraise.*` 默认）：
  - `coin_ring`：`pitch_cents_good`（足银的音高区间）`stack`（一摞几枚，默认 `[1, 1]`）`well_made_permille`（坏的里做得好的哑板比例）`worn_permille`（好的里旧洋比例）。
  - `weigh`：`small_fen`（“轻一点点”的上限，品类规矩，不是这件的真值；缺了按声称 × `appraise.weigh.small_permille`）`weight_box`（手边哪套砝码，套子在 `appraise.weigh.boxes`；缺了用 `tool` 同名的那套；写了 `weights_fen` 数组则直接用）`resolution_fen`（米 10）。
  - `fragments`：`seal_offset_px_good` / `seal_offset_px_bad`（真货 `[0, 0]`；坏货 `[0, 2]`，抽到不足 `appraise.fragments.seal_off_px` 时按对得上算；偏也只偏 2 px，拼好一眼看不出、放大镜里看得出，鉴定复审 r2）`ink_mismatch_bad`（坏货里异纸几块；坏货至少一样证据）`stain_permille`（水渍，真假一样）`rotate`（散开时转着：规格写整数 1 / 0，字画 1；参数里是 bool）；随机东西最多 `appraise.fragments.item_pieces_max`（6）块。只有老字段 `seal_offset_px` 的规格照旧（真假同区间）。
  - 文书（不是物品，写在牌上：当票 `fragments`、消息 `decode` / `fragments`）：`fragments` 同上，但 `seal_offset_px`、`ink_mismatch`（异纸的碎片下标）直接写；`decode`：`codes`（真码，必写；不写时引擎随便挑 `appraise.decode.groups_default` 组）`cipher` `message` `smudges`（洇几个字，减眼力 / 2，最少 0，默认 1）`key_shift`（加码 0–9，默认 0）`crib`（本号；缺了用电码本扉页的 `crib`）。可选 `smudge_alts`（码串数组，鉴定复审 fix2 10-25）：洇字另一读法里写的人查过、放进整封读不通的码；有它时引擎只从这几条（或本子里根本没有的码）里挑，本子里别的码一律不出，保证真读法是唯一读得通的。
  - spot 的痕迹总数、细处比例、`at` 大小、判分容差放在 `economy.json` 的 `appraise.spot`（不在规格里）。
- **首发物品清单 `data/cards/items/launch_items.json`**（K11；#44，框架版收尾默认，主创可改）：
  ```json
  {"_meta": {"owner": "K11", "schema": 1, "brief": "…", "_provenance": {…}}, "_doc": ["…"],
   "items": [{"template": "jewelry.hairpin", "eras": ["1938", "1939", "1940"], "weight": 10, "brief": "…"}]}
  ```
  `template` = `<cat>.<variant>`（同上，不重复）；`eras` = 打算在哪几关出；`weight` = 打算的出现权重，整数 ≥ 0，0 表示首发不用（`brief` 写理由）；`brief` 写验法和史实依据。**引擎不读这个文件**：柜台上的物品照旧由人物牌给的模板或品类经 G04 的 `economy/items.gd` 生成，`eras`、`weight` 在游戏里不起作用。它只是 K11 的清单：K11 的测试拿它核对（≥ 36 件；现有 28 个变体和 `templates_extra.json` 的新变体都列入；`weight > 0` 的模板都有 `it.*`），K15 的 `missing_text.py` 按它列物品正文 `item.<template>` 的待写清单。要让 G04 按它抽物品，先改合同。

#### 4.7.16 pawn_ticket（主线当票）

```json
{
  "id": "tk.1938.de196", "type": "pawn_ticket", "era": ["1938"], "weight": 0,
  "number": 196, "holder": "", "item_template": "documents.receipt", "foreign": true,
  "keepable": true, "expires_days": 0, "must_resolve": false,
  "story_node": "s1938.ticket196", "minigame": "fragments",
  "art": "illus.tk.de196",
  "brief": "主线当票“德字第一九六号”：不是这间铺子开的（外来当票），只记录不动钱；撕成几片，拼回去能看出当字和印章。",
  "_provenance": {"by": "ai", "task": "K01", "date": "2026-10-14"}
}
```
（当票上的号码由界面键 `g04.ticket.number`（参数 `{n}`）排成“德字第……号”，A 写那条键的正文。当票牌按主线日程发到**手牌**，能留着；在手牌或留着的牌里点它 → `mg.request {uid}`（不带物品，用牌上的 `minigame`）；拼完由 G04 记成外来当票（`TicketView.foreign = true`，不动钱），牌照常 `resolve`。）

#### 4.7.17 wheel 与 wheel_segment（命运轮盘，K10）

```json
{
  "id": "wh.month", "type": "wheel", "era": ["*"], "weight": 0, "kind": "month",
  "incense": {"accepts": ["money", "kept", "contact"], "money_per_unit": 5, "contact_attr": "pull", "unit_widen_pct": 15, "max_units": 6},
  "cost": {},
  "art": "wheel.month",
  "brief": "每关开头转一次，定这个月的运势。香案上放香火钱、留着的牌、人脉，好的扇区变宽。",
  "_provenance": {"by": "ai", "task": "K10", "date": "2026-10-14"}
}
```
```json
{
  "id": "ws.1938.month.caixing", "type": "wheel_segment", "wheel": "wh.month", "era": ["1938"], "weight": 0,
  "arc": 3, "valence": "good",
  "month_mods": [{"pool": "person", "tags_any": ["buyer"], "pct": 130}],
  "effects": [],
  "art": "icon.ws.caixing",
  "brief": "财星高照：这个月来买东西的人多一些。",
  "_provenance": {"by": "ai", "task": "K10", "date": "2026-10-14"}
}
```
```json
{
  "id": "ws.1938.month.liunian", "type": "wheel_segment", "wheel": "wh.month", "era": ["1938"], "weight": 0,
  "arc": 3, "valence": "bad",
  "month_mods": [{"pool": "fate", "valence": "bad", "pct": 140}],
  "effects": [],
  "art": "icon.ws.liunian",
  "brief": "流年不利：这个月命运牌坏的多。",
  "_provenance": {"by": "ai", "task": "K10", "date": "2026-10-14"}
}
```
```json
{
  "id": "ws.any.big.fanshen_ship", "type": "wheel_segment", "wheel": "wh.big", "era": ["*"], "weight": 0,
  "arc": 2, "valence": "good", "conditions": {"conscience_gte": -20},
  "effects": [{"op": "add_card", "card": "bf.any.ship_ticket", "to": "hand"}],
  "art": "icon.ws.fanshen",
  "brief": "翻身：手上来了一张去上海的船票（大赌，见 bf.any.ship_ticket）。本心太低时这一段不上盘（例，阈值待调）。",
  "_provenance": {"by": "ai", "task": "K10", "date": "2026-10-14"}
}
```
- `kind`：`month` `big` `fair` `gamble`。`cost`：`{"money": n}` 或 `{"stake": true}`（押一张留着的牌）。
- 段：`arc`（整数，画在盘上的基础大小）· `valence`：`good` `neutral` `bad`（大轮盘：翻身=good、平安=neutral、坠底=bad；**隐藏**，视图不给）· `conditions`（转的时候查；不满足，这一段这次不上盘——v1 §三.9“本心决定大命运出现哪几张”靠它）· `month_mods`（只有 `wh.month` 用，作用一整关）· `effects`（落到这一段时执行）。

#### 4.7.18 fortune_lot（签）、cezi（测字）、almanac_day（黄历，K10）

```json
{
  "id": "lot.g1.official", "type": "fortune_lot", "era": ["*"], "weight": 10,
  "grade": 1, "hint_tags": ["omen_official"],
  "brief": "下签，官面家族：征兆是官面上、纸上的事找上门。签诗、解曰由 A 写，要含糊，不点名哪张牌。",
  "_provenance": {"by": "ai", "task": "K10", "date": "2026-10-14"}
}
```
（`grade`：0 下下 · 1 下 · 2 中 · 3 上 · 4 上上。每个等第还要一支 `hint_tags: []` 的“泛泛”签兜底。签的 `hint_tags`、测字的 `tags` 只用 §2.5 的 `omen_*`，牌上也都带 `omen_*`，所以一定对得上。）

```json
{
  "id": "cz.shui", "type": "cezi", "era": ["*"], "weight": 10,
  "tags": ["omen_water"],
  "brief": "‘水’字：水边、船、码头。窗口里有 omen_water 征兆的牌就给‘有’的提示，没有给‘无’的提示。",
  "_provenance": {"by": "ai", "task": "K10", "date": "2026-10-14"}
}
```
```json
{
  "id": "alm.shoudang", "type": "almanac_day", "era": ["*"], "weight": 10, "season": [0, 1, 2, 3],
  "yi": ["pawn_in", "meet"], "ji": ["travel"],
  "reward": [{"op": "rep", "delta": 1}],
  "brief": "宜收当、会友；忌出行。照着做（做了宜的、没做忌的）：口碑涨一点。",
  "_provenance": {"by": "ai", "task": "K10", "date": "2026-10-14"}
}
```
黄历动作枚举（§9.4）：`pawn_in` 收当 · `buy_in` 收货 · `sell_out` 出货 · `redeem` 赎当 · `trade` 交易 · `meet` 会友 · `travel` 出行 · `pray` 祭祀 · `repair` 修造 · `rest` 安床 · `lend` 借贷 · `wed` 嫁娶。

#### 4.7.19 dossier_page 与 dossier_fragment（档案簿，K08）

```json
{
  "id": "dp.linsao", "type": "dossier_page", "person": "linsao", "era": ["*"], "weight": 0,
  "fragments": ["df.linsao.1938.hairpin", "df.linsao.1938.husband", "df.linsao.1938.neighbors", "df.linsao.1939.after_hairpin", "df.linsao.1939.child"],
  "effects": {"on_complete": [{"op": "contact_gain", "person": "linsao"}]},
  "brief": "林嫂一页：补齐后林嫂成为人脉。",
  "_provenance": {"by": "ai", "task": "K08", "date": "2026-10-14"}
}
```
```json
{
  "id": "df.linsao.1939.after_hairpin", "type": "dossier_fragment", "person": "linsao", "era": ["1939"], "weight": 0,
  "order": 4, "kind": "year_after", "year_after_of": "df.linsao.1938.hairpin",
  "brief": "一年后：金簪一直没人来赎，原因（由 A 写）。只有拿到了 1938 的那块才会补这一块。",
  "_provenance": {"by": "ai", "task": "K08", "date": "2026-10-14"}
}
```
（`kind`：`pawn` 当了什么 · `said` 说了什么 · `heard` 别人提起 · `clipping` 剪报 · `ticket` 当票上的字 · `letter` 信 · `year_after` 一年后。）

#### 4.7.20 goal（本关目标，K02/K04/K06）

```json
{
  "id": "gl.1938.keep_shop", "type": "goal", "era": ["1938"], "weight": 0, "main": true,
  "done_when": {"estate_status": ["es.shopfront", "held"]}, "eval": "month_close",
  "effects": {"on_done": [], "on_fail": []},
  "brief": "主线目标：撑过第一个月，保住铺面。",
  "_provenance": {"by": "ai", "task": "K02", "date": "2026-10-14"}
}
```
（`done_when` 是条件（§5.3），不是格子检定 `check`；`main: false` 的是可选目标，`weight` 决定被挑中的机会；`eval`：`month_close` 或 `any_time`。）

#### 4.7.21 guide_step 与 rule_page（新手指引，K16；机制见 §7.10）

```json
{
  "id": "gd.d1.person", "type": "guide_step", "era": ["*"], "weight": 0,
  "teaches": ["person"],
  "trigger": {"first": "person", "phase": "day", "mode": "shop", "after": ["gd.d1.deal"]},
  "teacher": "brother",
  "anchor": "a.card@{uid}", "anchor_fallback": "a.hand",
  "done_when": ["panel:counter", "cmd:counter.open", "timeout"],
  "rule_page": "rule.person",
  "priority": 60, "interrupt": false, "max_shows": 2, "seconds": 16,
  "brief": "哥哥指着第一个进门的人：这是今天来的客人，点开他看他要干什么；拒绝也算处理，但不能当没看见。",
  "_provenance": {"by": "ai", "task": "K16", "date": "2026-10-14"}
}
```

| 字段 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `teaches` | [机制] | 必填（可以是 `[]`） | 这一步教哪些机制（`CardIds.FIRSTS`）；V29 按它数覆盖 |
| `trigger.first` | 机制 | — | `firsts` 里有它了才可能亮；锚点里的 `{uid}` 取那次 `first_time` 的 `args.uid` |
| `trigger.phase` | 阶段名或数组 | — | 当前阶段（`view.phase`） |
| `trigger.mode` | `shop` / `street` | — | |
| `trigger.stage_gte` · `trigger.stage_day_gte` · `trigger.abs_day_gte` | int | — | 第几关起 · 本关第几天起（“按天逐步解锁”）· 开局第几天起 |
| `trigger.after` | [步骤 id] | `[]` | 这些步骤都已完成 |
| `trigger.panel` | 面板 kind | — | 这个面板开着 |
| `trigger.hand_clear` | bool | — | 手上没有要了断（`must_resolve`）的牌了（界面从 `view.hand` 算） |
| `trigger.cond` | Cond | — | 只许用看得见的条件 op（V35）；引擎用查询 `guide_conds` 算，界面拿到的只是真/假 |
| `teacher` | String | 必填 | 人物 id、`obj.notice`、`obj.almanac`、`obj.brother_ledger`，或 `""`（不借人物口吻的旁白，只用在 §7.10.10 标【冲突 c】的几处，主创已确认） |
| `anchor` · `anchor_fallback` | 锚点 id | 必填 · `""` | 高亮哪里（§7.10.5）；主锚点不在屏幕上时用备用的 |
| `done_when` | [token] | 必填 | 这一步亮起来**之后**发生任一个就算完成：`cmd:<指令>`（那条指令 ok）· `ui:<事件名>` · `first:<机制>` · `panel:<kind>`（那个面板打开了）· `timeout`（到 `seconds` 秒算完成） |
| `rule_page` | 规矩页 id | 必填 | 对应的规矩页 |
| `priority` | int | 50 | 同时有几步能亮时大的先；一样大按文件里的顺序 |
| `interrupt` | bool | false | 可以打断正在亮的、`priority` 比它小的那一步（被打断的不算亮过） |
| `max_shows` | int | 2 | 没完成就渐隐的，最多再亮几次 |
| `seconds` | int | `guide.json.default_seconds` | 亮多久；`done_when` 里没写 `timeout` 的，到点渐隐、算亮过一次，以后还会再亮 |

```json
{
  "id": "rule.slots", "type": "rule_page", "era": ["*"], "weight": 0,
  "order": 40, "unlock_first": ["slots", "coins"], "teacher": "obj.brother_ledger",
  "brief": "放格子与掷铜钱：格子标着要什么；人按属性点、钱按数目换铜钱；正面够了就成；有的留着的牌直接算正面。",
  "_provenance": {"by": "ai", "task": "K16", "date": "2026-10-14"}
}
```
- `unlock_first`：任一个机制在 `firsts` 里，这一页就进档案簿“规矩”栏和 F1 帮助（C10）；和指引开关无关。`order` 是排序。`teacher` 是落款口吻（可以为 `""`）。
- 文件顶层可以有 `_test`（`stage_ship.py` 会剥掉）：`{"d1_3": ["gd.m.open", …]}` 是新存档第 1–3 天应当按顺序亮的步骤（C16、K14 的测试拿它比）。

#### 4.7.22 开场 stage.json（每年一份，K02/K04/K06）

```json
{
  "_meta": {"owner": "K02", "schema": 1},
  "era": "1938", "bg": "bg.stage.1938", "intro_paras": 3, "main_goal": "gl.1938.keep_shop",
  "brief": "开场过场：小镇沦陷不久，伪维持会管事，出入查良民证；哥哥要走。三段：时局、铺子、家里。",
  "_provenance": {"by": "ai", "task": "K02", "date": "2026-10-14"}
}
```
（不是牌文件；`data/cards/era/<年>/stage.json`。C09 开月过场用：背景图 `bg`、`intro_paras` 段正文（`stage.<年>#intro.p1` …，A 写）、主线目标；两个可选目标照旧由 G02 从 `main: false` 的目标牌里按权重挑。）

#### 4.7.23 电码本骨架 codebook.json（K11）

```json
{
  "_meta": {"owner": "K11", "schema": 1, "brief": "解密小游戏的电码本：四位码 → 词的键；词由 A 写"},
  "codes": {
    "0417": {"key": "cb.word.0417", "brief": "一个常用的地名用字（具体由 A 定）"},
    "2201": {"key": "cb.word.2201", "brief": "表示“货”一类意思的字（具体由 A 定）"}
  }
}
```
（`data/cards/minigames/codebook.json`；词的正文在 `data/cards/text/codebook.text.json`，`{"cb.word.0417": {"word": "……", "_provenance": "human:A:…"}}`。旧的 `data/codebook.json` 是 AI 写的旧内容，卡牌版不读。）

#### 4.7.24 演出块 stage（可选；1.3，画面与对话）

一张牌打出后“怎么演”：谁上场、站哪、换什么背景、柜台上摆什么、有什么效果、先说哪几句、某个结果之后接哪几句。**大部分牌不用写**——W0 的 `CardStageScript` 按类型有默认演法（§7.11.4 的默认表）；要特别演的牌才写。演出块里**只有 id、键和 brief**，对白正文由人写在覆盖层（§4.5）。

能带 `stage` 的类型：person event fate big_fate life news street prison demand night pawn_ticket（V40）。

```json
{
  "id": "ev.1938.police_check", "type": "event", "…": "（其余字段照旧）",
  "stage": {
    "cast": [{"who": "ex_patrol", "at": "door_l", "brief": "巡警甲站门口左边"},
             {"who": "ex_patrol", "at": "door_r", "brief": "巡警乙站门口右边"}],
    "walk": "patrol",
    "intro": [
      {"who": "ex_patrol", "ref": "lines.greet", "brief": "巡警拍门，叫开门查良民证，例行公事的口气"},
      {"who": "", "ref": "body", "brief": "旁白：挨家挨户查证件的场面"}
    ],
    "after": {
      "success": [{"who": "ex_patrol", "ref": "lines.pass", "brief": "巡警看过证件，挥手放过"}],
      "fail": [{"who": "ex_patrol", "ref": "lines.noted", "brief": "巡警把名字记在本子上"},
               {"who": "", "ref": "outcomes.fail", "brief": "旁白：没过的后果"}]
    }
  }
}
```

金色牌的例子（哥哥告别，`p.brother.1938.farewell`）：
```json
"stage": {
  "cast": [{"who": "brother", "at": "door", "brief": "哥哥提着箱子站在门口，没进柜台"}],
  "props": [{"art": "prop.trunk", "at": "door_side", "brief": "哥哥的藤箱"}],
  "fx": ["predawn"],
  "intro": [
    {"who": "", "ref": "body", "brief": "旁白：天没亮，哥哥要走"},
    {"who": "brother", "ref": "lines.greet", "brief": "哥哥开口：要走了，铺子交给你"},
    {"who": "brother", "ref": "lines.charge", "brief": "哥哥要交代的事的开头"}
  ],
  "after": {
    "listen": [{"who": "brother", "ref": "lines.after_listen", "brief": "哥哥交代完，把账簿推过来"},
               {"who": "", "ref": "outcomes.listen", "brief": "旁白：哥哥出了门"}],
    "argue": [{"who": "me", "ref": "lines.me_argue", "brief": "你顶了他一句"},
              {"who": "brother", "ref": "lines.after_argue", "brief": "哥哥叹口气，不再多说"}]
  }
}
```

| 键 | 类型 | 默认 | 含义 |
|---|---|---|---|
| `set` | String | 视图的 `stage.set` | 背景：`counter`（柜台，按时段用 `bg.counter.day/dusk/night`）`candle`（后门烛光）`street` `prison` `temple`（城隍庙）`dock`（码头）`market`（集市）`teahouse` `ricehall` `pharmacy` `post`（邮电代办）`baogong`（保公所）——`CardIds.STAGE_SETS`；不是 `counter` 时用 `bg.<set>` |
| `cast` | Array（≤ 3） | 按类型（§7.11.4） | 上场的人：`{"who": 人物 id, "at": 站位, "look": 样子, "brief": …}`。`who` 是登记过的人物（含 `ruhua` 与群演 `ex_*`，§3.5）；`at`：`customer`（柜台前，立绘 ×4）`companion`（柜台一侧）`door`（门口正中，行走图 ×8）`door_l` `door_r`（门口左右）`street`（门外街上走过，行走图 ×4）——`CardIds.STAGE_SPOTS`；`look`：`stand`（默认）`walk`（只用于 `street`）`shadow`（剪影，配色 `silhouette`）——`CardIds.CAST_LOOKS` |
| `props` | Array（≤ 4） | 按类型 | 柜台上、门边的道具：`{"art": "prop.<名>", "at": 道具位, "brief": …}`；道具位（道具底边的中点，场景坐标）：`counter_left` (128,138) · `counter_mid` (160,138) · `counter_right` (192,138) · `door_side` (186,100) · `door_notice` (160,66) · `wall_right` (226,84)——`CardIds.PROP_SPOTS`；道具按底图尺寸 ×4 画 |
| `fx` | Array（≤ 3，不重复） | `[]` | 效果：`rain` `fire` `smoke` `predawn` `dim` `cold` `warm` `drip` `shake` `seal`——`CardIds.STAGE_FX`；都由代码用配色键画 |
| `walk` | String | 白天/黄昏的柜台有零星路人 | 门外走过的人：`crowd`（赶集的）`patrol`（巡警走过）`troops`（伪军一队）`refugees`（逃难的）`hu2_men`（胡二的人，剪影）`none`（没人）——`CardIds.STAGE_WALKS`；只在 `set == "counter"` 且不是夜里时有 |
| `intro` | Array（≤ 12 拍） | 按类型（§7.11.4） | 上场后说的话，一拍一句：`{"who": …, "ref": …, "brief": …}` |
| `after` | Dictionary | 按类型 | 某个结果之后接的话：键是 `CardIds.STAGE_AFTER_KEYS`（`accept` `counter` `leave` `refused` `impatient` `look` `success` `fail` `read` `keep` `delay` `lot` `cezi` `pass` `done`）或这张牌自己的选项 id；值是拍子数组（≤ 8） |
| `brief` | String | — | 整个演出的说明（可选） |

**一拍**（`intro`、`after.*` 的元素）：
- `who`：`""` = 旁白；`"me"` = 沈如花说的话；否则是说话的人（必须是本牌的 `person` 或本块 `cast` 里的某个 `who`，V39）。
- `ref`：这张牌正文里的字段路径，只许 `body`、`lines.<名>`、`outcomes.<名>`、`choices.<id>`（正则 `^(body|lines\.[a-z0-9_]+|outcomes\.[a-z0-9_]+|choices\.[a-z0-9_]+)$`）；正文由 A 写在这张牌的覆盖层条目里（§4.5，`lines.*` `outcomes.*` 本来就是允许的字段）。
- `brief`：**必填**，干巴巴写这一句是谁、说什么意思（给 A 写正文用），不写成台词、不写引号对白（§11.2）。
- 注意：演出块里**不许出现** `text` `title` `body` `label` `name` `lines` `desc` 这些键名（V04）——所以拍子用 `ref` 指向正文字段，值里写 `"body"`、`"lines.greet"` 是可以的。

**结果之后**：选了一个回话之后，先显示“你说的那句”（回话本身的文字，以 `me` 的样子），再接 `after.<键>`；如果 `after.<键>` 的第一拍就是 `who: "me"`，就不再重复显示回话。没写 `after.<键>` 的按默认表（§7.11.4）。

**正文怎么取**：每一拍 = `CardText.t("<牌 id>#<ref>", args)`；`args` 里界面自动补 `name`（说话人的名字 `CardText.person_name(who)`）和这一出要用的数（例：报价 `price`，由演这一出的面板补）。一段正文里有空一行（`\n\n`）的，拆成几句依次说。默认表里标“可省”的拍子，正文还没写（`CardText.is_draft()` 为真）或是空串就跳过；数据里写明的拍子一律显示（开发版显示【稿】+ brief）。

### 4.8 观察键目录、美术清单

```json
{
  "_meta": {"owner": "C14", "schema": 1, "kind": "weigh"},
  "obs": {
    "obs.weigh.match":       {"fidelity": "clear",   "brief": "称出来和客人说的分量对得上"},
    "obs.weigh.light_small": {"fidelity": "clear",   "brief": "比说的轻一点点（一钱上下）"},
    "obs.weigh.light_much":  {"fidelity": "clear",   "brief": "比说的轻不少"},
    "obs.weigh.heavy":       {"fidelity": "clear",   "brief": "比说的重"},
    "obs.weigh.light_vague": {"fidelity": "partial", "brief": "好像轻一些，戥子没压稳"},
    "obs.weigh.unsure":      {"fidelity": "vague",   "brief": "没称准，说不好"}
  }
}
```
（`data/cards/minigames/obs/weigh.json`；键必须以 `obs.<kind>.` 开头，键里不许出现判词英文：`fake` `real` `genuine` `forged` `true` `false` `authentic`。`spot` 的观察按部位：`obs.spot.<部位>.differs`（和图鉴不一样）· `.wear`（旧痕）· `.plain`（看不出什么）· `.unclear`（没看清）；部位 id 来自物品模板的部位表，C12 在 `obs/spot.json` 里列全。）

**10-25 鉴定改版（主创：要玩家看出来才算数）**：观察是玩家的判断，目录多两样东西——
```json
"obs.weigh.light_small": {"fidelity": "clear", "hedge": {"partial": "obs.weigh.light_vague", "vague": "obs.weigh.unsure"}, "brief": "比说的轻一点点（一钱上下）"},
"obs.weigh.unsure":      {"fidelity": "any",   "brief": "没称准，说不好"}
```
- `hedge`：清晰度不够这一档时换成同目录里的哪一条（口气软一些的说法）；值写 `""` 表示这一档不记。校验器（V23）查：档名只许 `clear`/`partial`/`vague`，值是 `""` 或本目录里的键。
- `fidelity: "any"`：哪一档都照记（“说不好”“没找出什么”“这组码我抄的是 xxxx”）。
- G04 的规则（`CardAppraisal.record`）：这一档或 `any` → 记原键；否则有 `hedge` → 记 `hedge[档]`（空串不记）；否则（老目录）→ 不记。**不看对错。**
- spot 新键：`obs.spot.<部位>.differs_maybe` `.wear_maybe`（partial）、`obs.spot.nothing_found`（any）；`.plain` 留着兼容、不再发。其余各种的新键见各小游戏的目录（C13–C15）。

```json
{
  "_meta": {"owner": "K12", "schema": 1},
  "art": {
    "portrait.linsao": {"base": [48, 64], "human": "art/cards/portraits/linsao.png", "ai": "art/ai/portrait/linsao.png", "_provenance": "ai:google-imagen:2026-10-18:p01", "placeholder": "art/_placeholder/cards/portraits/linsao.png"},
    "illus.ev.1938.police_check": {"base": [64, 48], "human": "art/cards/illus/ev.1938.police_check.png", "placeholder": "art/_placeholder/cards/illus/ev.1938.police_check.png"},
    "frame.gold": {"base": [36, 50], "nine": [6, 6, 6, 6], "human": "art/cards/frames/gold.png", "placeholder": "art/_placeholder/cards/frames/gold.png"},
    "item.jewelry.hairpin": {"base": [64, 64], "human": "", "placeholder": "art/items/hairpin.png", "legacy": true}
  }
}
```
（`data/cards/art/manifest.json`。美术 id 类别：`portrait.<person>` 48×64 · `illus.<牌 id 或 类别>` 64×48 · `item.<cat>.<variant>` 64×64 · `frame.<类型或 gold>` 9 宫格 36×50 · `bg.<名>` 320×180 · `wheel.<kind>` 120×120 · `icon.<名>` 16×16/24×24；**1.3 新加**：`stage.<person>` 48×64（柜台前的立绘，可选，没有就用 `portrait.<person>`）· `walk.<person>` 64×128（行走图：16×32 一帧，4 行 = 朝下/左/右/上，4 列 = 站、迈左脚、站、迈右脚，脚点 (8,30)）· `prop.<名>`（柜台工具与道具，按下表的底图尺寸，画面里 ×4）· `frame.dialog` 48×48 九宫格边距 7（×2）· `frame.hero` 27×36 九宫格边距 6（×4）· `frame.guide_note` 24×24 九宫格边距 6（×2）· `icon.tab.<名>` 24×24。`legacy: true` 指向 v0.4.2 的旧图（AI 产出，按占位对待）。**W2（10-18，#201/#202/#212）**：AI 生成美术放 `art/ai/<类别>/<id>.png`，清单条目加 `ai` 路径与 `_provenance: "ai:google-<工具名>:<日期>:<提示词 id>"`（或 `ai:<工具>:<模型>:<日期>:<提示词 id>`）；`CardArt` 查找顺序为 **human → ai → placeholder**（不带 AI 声明版带 `no_ai` 特性时跳过 `ai`，人画的图放 `art/cards/**` 自动顶替 AI 图），再不存在用 `art/_placeholder/cards/missing.png`。同理，AI 音乐音效放 `audio/ai/<music|sfx>/<id>.ogg`，清单登记 `_provenance`，查找顺序为 **human → ai → 静音占位**。**10-22 能玩版（框架版收尾默认，主创可改）**：`data/cards/audio/music.json` 每个 cue 可另带 `legacy`（v0.4 旧曲 `audio/music/*.ogg`），只在非发行版（不是 `CardShip.is_ship()`，也不带 `no_ai`）排在 ai 之后用，和美术 legacy 一样；卡牌曲目一律循环播放，音量取设置里的音乐音量。）

**画面用的美术**（1.3；K12 进清单与生成器，§3.4 K12）：

| id | 底图 | 画面里 | 占位（legacy: true 的旧图，或 K12 生成） | 首发必需 |
|---|---|---|---|---|
| `bg.counter.day` `bg.counter.dusk` `bg.counter.night` | 320×180（同一构图：门 112,8,96,92；柜台面 y 100） | ×4 | `art/bg/counter_day.png` `counter_dusk.png` `counter_night.png` | ✓ |
| `bg.candle` | 320×180 | ×4 | `art/bg/candle.png` | ✓ |
| `bg.prison` | 320×180 | ×4 | K12 生成（从 `art/bg/candle.png` 调冷色） | ✓ |
| `bg.street` `bg.market` | 320×180 | ×4 | `art/town/shops/market_bg.png` | ✓ |
| `bg.temple` | 320×180 | ×4 | K12 生成（集市图压暖色 + 灯笼杆） | ✓ |
| `bg.dock` | 320×180 | ×4 | `art/bg/title.png` | ✓ |
| `bg.teahouse` `bg.ricehall` `bg.pharmacy` `bg.post` `bg.baogong` | 320×180 | ×4 | `art/town/shops/{teahouse,ricehall,pharmacy,post,baogong}_bg.png` | 用到才要 |
| `bg.title` · `bg.stage.<年>` | 320×180 | ×4 | `art/bg/title.png` · K12 生成 | ✓ |
| `walk.<person>` | 64×128 | 门口 ×8、街上 ×4 | `art/town/chars/<id>.png`（brother chen guanjia li linsao ma postman ruhua sunyoung wangshan wu xiaoding zhang zhao zhouma stranger_collector stranger_fence stranger_peddler stranger_refugee）；`walk.hu2` 借 `stranger_collector`；`walk.suanming` 借 `passerby_3`；群演 `walk.ex_patrol` = `patrol.png`、`walk.ex_newsboy` = `passerby_0`、`walk.ex_girl` = `passerby_1`、`walk.ex_shopboy` = `passerby_2`、`walk.ex_oldman` = `passerby_3`、`walk.ex_porter` = `passerby_4`、`walk.ex_student` = `passerby_5`、`walk.ex_soldier` 由 K12 从 `patrol.png` 调色生成、`walk.ex_hu2_man` = `stranger_collector` | 群演 ✓；主要人物可选 |
| `portrait.ex_*` | 48×64 | 柜台前 ×4 | K12 从对应行走图朝下第一帧 ×2 贴在 (8,0) 生成（和 `ruhua.png` 一样的做法） | 站柜台前的群演 ✓ |
| `stage.<person>` | 48×64 | ×4 | 不建清单条目也行：界面没有就用 `portrait.<person>` | 可选 |
| `prop.magnifier` 30×20 · `prop.abacus` 52×22 · `prop.scale` 40×20 · `prop.ledger` 40×26 · `prop.notebook` 40×26 · `prop.cashbox` 48×26 · `prop.medbook` 36×16 · `prop.trash` 30×28 · `prop.telegraph` / `prop.telegraph_open` 38×28 · `prop.lamp` / `prop.lamp_off` 20×32 · `prop.calendar` 24×34 · `prop.candle` 8×16 · `prop.sign` 26×34 · `prop.door_flag` / `prop.door_flag_red` / `prop.door_flag_white` 12×40 | 见左 | ×4 | `art/tools/<名>.png`（`prop.cashbox` = `pawnbox.png`、`prop.door_flag_*` = `door_flag_*.png`） | 热点用到的（`prop.magnifier` `prop.abacus` `prop.cashbox` `prop.ledger` `prop.notebook` `prop.calendar` `prop.lamp` `prop.lamp_off`）✓；其余用到才要 |
| `prop.notice` 24×32 · `prop.notice_wall` 18×26 · `prop.ticket` 24×32 · `prop.letter` 24×32 · `prop.stamp` 24×24 · `prop.coin` 16×16 | 见左 | ×4 | `prop.notice` K12 生成（`art/town/ui/notice_paper.png` 缩到 24×32 的占位）；`prop.letter` K12 生成（同一张 `notice_paper.png` 缩到 24×32、压一道折痕、右上角盖 `art/ui/stamp.png` 缩成 8×8 的邮戳）；`prop.notice_wall` = `art/town/props/notice_wall.png`；`prop.ticket` K12 从 `art/ui/ticket_blank.png` 缩成 24×32；`prop.stamp` = `art/ui/stamp.png`；`prop.coin` = `art/town/ui/coin_icon.png` | ✓ |
| `prop.trunk` 16×14 · `prop.boat` 48×22 · `prop.broom` 8×22 · `prop.rice_sacks` 20×16 · `prop.shelf` 208×50 · `prop.lantern_post` 16×34 · `prop.bench` 26×12 · `prop.bed` 32×28 · `prop.back_door` 16×32 · `prop.clothes_rack` 32×40 · `prop.storeroom_door` 32×46 · `prop.cat` 14×12 | 见左 | ×4 | `art/town/props/<名>.png` | 用到才要 |
| `frame.dialog` | 48×48，边距 7 | ×2 | `art/town/ui/dialog_frame.png` | ✓ |
| `frame.hero` · `frame.guide_note` | 27×36 边距 6 · 24×24 边距 6 | ×4 · ×2 | K12 生成 | ✓ |
| `icon.tab.contacts` `icon.tab.demands` `icon.tab.dossier` `icon.tab.rules` `icon.tab.shelf` `icon.tab.tickets` `icon.tab.estates` `icon.tab.settings` | 24×24 | ×1 | K12 生成 | ✓ |
| `icon.coin.head` · `icon.coin.tail` | 16×16 | 柜台上 ×3 | K12 生成（1.2 的清单里还没有这两个 id，1.3 起要） | ✓ |

- 柜台上的物品用 `item.*`（64×64）×2；手牌、英雄头像、人脉小牌照 §1.2。
- 场景里代码画的效果（雨、火光、烟、夜色、封条、影子、灯光）算代码、不算美术，只许用配色键（同小游戏的代码画面）。
- **给 A / 外包的交付清单**（K12 写进 `ART_SPEC.md`，首发必需的打 ✓）：上表打 ✓ 的全部；每个主要人物 1 张头像（同时是柜台前的立绘）；群演 9 个的头像与行走图；主要人物的行走图（可选，有了客人会从街上走进来）；三张柜台背景的构图必须和旧图一致（门、窗、柜台面、桌下的位置不变——坐标常量都按它定）。

### 4.9 校验规则（CardValidator，G01；W0 先把 default 模式的“错”全做了）

命令行：`$GODOT --headless --path . -s res://scripts/cards/core/validate_main.gd -- [--mode=default|strict|ship] [--root=res://data/cards] [--examples] [--only=<路径或 glob，可多个，逗号分隔>] [--name=<测试名>]`。
输出：每个问题一行 `DATA ERROR: <文件>: <id>: <规则号> <说明>`（会让测试失败）或 `NOTE: …`（不算失败）；然后一行 `CARDS VALID <牌数> cards, <错误数> errors`；没有错误时最后一行 `CARDS TEST PASS <测试名>`（`--name` 的值，原样；不给时为 `validate`），有错误退出码 1。登记进清单时 `--name` 必须和清单那一行的名字一样，runner 才认（§12.1）。`--only` 只报这些文件里的问题（引用检查仍然看同一套数据的全部）。`--examples` 读例子集，不给读真数据（§4.10）。

| # | 规则 | default | strict | ship |
|---|---|---|---|---|
| V01 | JSON 能解析；有 `_meta.owner`、`_meta.schema`；`owner` 与归属表一致 | 错 | 错 | 错 |
| V02 | id 合 §4.2 正则、前缀与类型一致、在同一套数据里唯一（§4.10） | 错 | 错 | 错 |
| V03 | `type` 认识；该类型必填字段齐；没有未知字段（`_` 开头除外） | 错 | 错 | 错 |
| V04 | 骨架文件里没有正文字段（`text` `title` `body` `label` `name` `lines` `desc`） | 错 | 错 | 错 |
| V05 | 除 `brief` `_meta.brief` `_doc` 外的字符串没有 CJK 字符 | 错 | 错 | 错 |
| V06 | 每张牌有非空 `brief` 和 `_provenance` | 错 | 错 | — |
| V07 | 数值类型对：计数/钱/天数/百分比是整数；`weight ≥ 0`；`need` 0–12 | 错 | 错 | 错 |
| V08 | `era` 是 `stages.json` 里的年代或 `*` | 错 | 错 | 错 |
| V09 | 标签都在某个 `tags/*.json` 里声明 | NOTE | 错 | 错 |
| V10 | 效果 op 认识、参数形状对（`ctx.ops.validate`）；条件 op 认识、形状对 | 错 | 错 | 错 |
| V11 | 引用存在：牌 id、碎片、人物、模板、轮盘、段、主线节点、正文键（`#` 引用） | NOTE | 错 | 错 |
| V12 | 美术 id 在 `data/cards/art/manifest.json` 里 | NOTE | 错 | 错 |
| V13 | `gold: true` ⇒ `type == person`、有 `story_node`、`keepable` 不为 true、`on_expire` 里有 `story` 和 `dossier_gap` | 错 | 错 | 错 |
| V14 | `type == kept` ⇒ `keepable` 为 true；`keepable` ⇒ `expires_days ≥ 0` | 错 | 错 | 错 |
| V15 | 格子：卡内 id 唯一；`accepts` 合法；收人必须有 `attr`；收钱的 `money_per_coin > 0`（或用默认）；有 `check` 必须有格子 | 错 | 错 | 错 |
| V16 | 会进手牌或各区的类型（person event fate big_fate demand life news kept night street prison pawn_ticket）里 `weight == 0` 的牌必须被日程、效果、扇区或 §3.5 的系统牌表引用到（否则永远发不出来）；guide_step、rule_page、wheel、wheel_segment、item、goal 等不查 | NOTE | 错 | 错 |
| V17 | 条子：`kind`、`tier` 合法；`resolve` 与 `kind` 对应；每个（年 × 类 × 档）至少一张 | 形状错 | 全查 | 全查 |
| V18 | 轮盘：每个轮盘每个年代 ≥3 段；`wh.big` 三种 `valence` 都有；`arc > 0` | NOTE | 错 | 错 |
| V19 | 签：每个等第至少一支泛泛签；`grade` 0–4 | NOTE | 错 | 错 |
| V20 | 黄历动作都在 §9.4 枚举里 | 错 | 错 | 错 |
| V21 | 档案：碎片的人物有页；同页 `order` 不重复；`year_after_of` 存在且年代更早 | NOTE | 错 | 错 |
| V22 | 物品：模板存在；`minigames` 都是已知的 kind；参数形状对（§8.2） | 错 | 错 | 错 |
| V23 | 观察目录：键前缀对、无判词英文；`fidelity` 合法 | 错 | 错 | 错 |
| V24 | 界面键：以主人任务号小写开头（例子集除外）；全局唯一 | 错 | 错 | 错 |
| V25 | 规则文件：必需键齐、类型对；`balance_overrides.json` 只覆盖已有键 | 错 | 错 | 错 |
| V26 | 正文覆盖层：键对得上已有 id；字段在 §4.5 允许的范围（必填 + `lines.*` `outcomes.*` `choices.*` `slots.*` `use`）；`_provenance` 合格式 | 错 | 错 | 错 |
| V27 | 发行检查：发行年代里每张会出现的牌、每个用到的界面键、观察键、人物名、物品名、指引步骤、规矩页、F1 帮助键、开场段落、电码本的词、带演出块的牌里每一拍引用的正文字段（§4.5 新加的那一行）、W0 的演出旁白键 `w0.stage.*`、群演的名字，§4.5 的必填正文都在且 `_provenance` 是 human；这些正文里没有 `%` | — | — | 错 |
| V28 | 金色牌、`schedule` 指向的 `stage_day` 不超过该关天数 | 错 | 错 | 错 |
| V29 | 新手指引覆盖：`CardIds.FIRSTS` 的每个机制至少在一个步骤的 `teaches` 里、至少在一页规矩的 `unlock_first` 里 | NOTE | 错 | 错 |
| V30 | 步骤的 `anchor`、`anchor_fallback` 在 `CardIds.ANCHORS` 目录里（`a.card@{uid}` 这类按 `@` 前面的部分查）。1.3 改了名的 7 个旧锚点（§7.10.5）：W1 里 default 模式下 NOTE（“已改名为 …”），strict / ship 错；X01-b 删掉旧名和 `CardIds.ANCHORS_RENAMED` 以后，旧名和别的未知锚点一样，三种模式都错。 | 错 | 错 | 错 |
| V31 | 步骤和规矩页的 `teacher` 是登记过的人物 id、`obj.notice`、`obj.almanac`、`obj.brother_ledger` 或 `""`；`rule_page` 指向存在的规矩页 | 错 | 错 | 错 |
| V32 | `done_when` 每一项是 `cmd:<CardIds 的指令>`、`ui:<CardIds.UI_EVENTS>`、`first:<CardIds.FIRSTS>`、`panel:<面板 kind>` 或 `timeout`；`first:` 不许等于本步骤的 `trigger.first`；`trigger.first`、`teaches`、`unlock_first` 都在 `CardIds.FIRSTS` 里；`after` 指向存在的步骤且不成环 | 错 | 错 | 错 |
| V33 | `minigame` 字段只出现在 pawn_ticket、`kind` 为 telegram/letter 的 news、`weight: 0` 且有 `schedule` 的 person 上；值是已知的小游戏 kind | 错 | 错 | 错 |
| V34 | event、fate、person、life、news 每张至少一个 `omen_*` 标签；签的 `hint_tags`、测字的 `tags` 只用 `omen_*` | NOTE | 错 | 错 |
| V35 | 步骤的 `trigger.cond` 只用 `CardIds.GUIDE_COND_OPS` 里看得见的条件 op（`flag` `story` `day_gte` `abs_day_gte` `stage_gte` `mode` `phase` `has_contact` `has_kept` `demand_open` `money_gte` `money_lt` `estate_status` `weather` `market_day`）| 错 | 错 | 错 |
| V36 | §3.5 的系统牌都在且 `weight: 0`；`bf.*` 除 `bf.wheel` 外都是 `weight: 0` 并被某个扇区引用 | NOTE | 错 | 错 |
| V37 | `must_resolve`（按类型默认或自己写）为真的 event、fate、street、big_fate（`bf.wheel` 除外）：有顶层 `check`，或者 `effects` 里有 `on_expire` 键（可以是 `[]`）——“打烊时没理会”的后果必须是写下来的决定（§7.4.7） | NOTE | 错 | 错 |
| V38 | 演出块 `stage` 的形状：只有 `set cast props fx walk intro after brief` 这些键；`set` ∈ `STAGE_SETS`；`cast` ≤ 3 个，每个只有 `who at look brief`，`at` ∈ `STAGE_SPOTS`、`look` ∈ `CAST_LOOKS`，`look: walk` 只配 `at: street`，`at: street` 只配 `walk` 或 `shadow`；`props` ≤ 4 个，每个只有 `art at brief`，`art` 合 `^prop\.[a-z0-9_]+$`，`at` ∈ `PROP_SPOTS`；`fx` ⊂ `STAGE_FX` 且不重复、≤ 3；`walk` ∈ `STAGE_WALKS`；`intro` ≤ 12 拍、`after` 每个值 ≤ 8 拍，每拍只有 `who ref brief`、`ref` 合 §4.7.24 的正则、`brief` 非空；`after` 的键 ∈ `STAGE_AFTER_KEYS` ∪ 本牌的选项 id（`type == "demand"` 另加 §4.7.6 的六种办法 id `CardIds.DEMAND_MODES`） | 错 | 错 | 错 |
| V39 | 演出里的人：每拍的 `who` 只能是 `""`、`"me"`、本牌的 `person` 或本块 `cast` 里出现的 `who`（本地部分）；`cast` 的 `who` 是登记过的人物（`data/cast.json` + 各 `persons` 块 + `ruhua`）（登记部分） | 本地部分错，登记部分 NOTE | 错 | 错 |
| V40 | 只有 person event fate big_fate life news street prison demand night pawn_ticket 能带 `stage` | 错 | 错 | 错 |
| V41 | 站位不冲突：`cast` 里同一个站位只站一个；`door` 不和 `door_l`/`door_r` 同时用；`set` 不是 `counter` 时不许用 `street` 站位，也不许写 `walk` | 错 | 错 | 错 |
| V42 | 演出用到的美术在 `data/cards/art/manifest.json` 里：`props[].art`；`set` 不是 `counter` 时的 `bg.<set>`；站 `customer`/`companion` 的人的 `portrait.<who>`；群演（`ex_*`）站门口或街上时的 `walk.<who>`（主要人物没有 `walk.*` 不算错：回退成立绘直接滑进来） | NOTE | 错 | 错 |

**V11 引擎代入模板（Hengrui 2026-10-15 裁决）**：引用值完整等于 `{person}`、`{uid}` 或 `{item}` 时属于引擎代入白名单，V11 仅跳过其静态引用存在性检查；其他花括号写法、未知变量或拼接字符串仍按原规则校验。静态豁免不免除引擎在实际发牌时完成代入并解析到真实存在的对象；`ev.any.demand_return` 的 `{person}` 必须对应当次派出去的人，由 G03 的真实引擎测试验证。

W1 期间各数据任务以 **default** 全绿为准；W2 起集成分支以 **strict** 全绿为准；发行前 **ship** 全绿（K15 的审核会调用它）。

**W0 的校验器已经实现 default 模式下所有“错”的规则**（V01–V08、V10、V13–V15、V17 的形状部分、V20、V22–V26、V28、V30–V33、V35），以及 §5.2/§5.3 每个 op 和指引数据的形状（`scripts/cards/api/dsl_shapes.gd`，§5.1）。G01 只补 NOTE/strict/ship 的部分。所以 W1 里先合进去的 K 数据，不会因为 G01 后来补规则而突然变红。

**1.3**：V38、V39 的本地部分、V40、V41 的全部检查写在 W0 的 `CardDslShapes.check_stage(card)`（`scripts/cards/api/dsl_shapes.gd`，返回 `"Vxx: 说明"` 的列表）；G01 在校验器里对每张带 `stage` 的牌调用它、把结果按规则号报出来，再补 V39 的登记部分、V42、V27 的新内容和 V30 的改名提示，并在 `data/cards/_schema/` 的 11 个类型里加 `stage` 属性（§3.2 G01 的 1.3 小 PR，10-15 前合入；合入之前任何数据文件都不要写 `stage`，否则 V03 报“未知字段”）。

### 4.10 两套数据：例子集与真数据

- **例子集** `data/cards/_examples/**`（W0）：§4 的全部例子 + 让引用闭合的最少几张 + `_examples/guide/`（3 个步骤、3 页规矩、`_test.d1_3`）+ `_examples/ui_keys.json` + `_examples/tags.json`。例子用了一部分真数据的预留 id（`kp.ma_owes`、`ct.ma`、`es.*`、`nt.tidy`、`pr.cell`、`bf.wheel`、`wh.month`、`p.brother.1938.farewell`、`tk.1938.de196`……）。
- **真数据**：`data/cards/**` 去掉 `_examples/**`、`_schema/**`、`_dev/**`。
- CardDB、校验器、Mock **一次只读一套**：`only_examples: true` / `--examples` 读例子集，否则读真数据；`rules/*.json` 和 `tags/W0.json` 两套都读。V02 的唯一性只在同一套里查——K09 加 `kp.ma_owes` 不会和例子撞，任何 PR 的默认校验都不会因此变红。
- G06 的 W1 黄金种子、各引擎任务的单测用例子集；W2 起的集成测试用真数据。

---

## 5. 效果与条件 DSL（e）

### 5.1 总规则

- **效果**是数组，按顺序执行；每一项是 `{"op": "<名>", …参数}`。**条件**是 `TownCond` 同形状的单键对象：`{"all": […]}`、`{"any": […]}`、`{"not": {…}}`、`{"<op>": 值}`；空对象 `{}` 为真。
- **数据里不写代码**：不用 `scripts/core/cond.gd` 那种 Expression 字符串。条件 op 的名字和语义沿用 `cond.gd` 的函数词汇（对照见 §5.3 末），形状沿用 `scripts/sim/town_cond.gd`（`all/any/not/day_gte/weekday/weather/flag/pressure_gte` 语义相同）——数据可校验、可审核、不会执行任意代码。
- **每个 op 只有一个主人**（下表“主人”列），主人在自己模块的 `install()` 里登记：`ctx.ops.register(op, handler, shape, owner)` / `ctx.conds.register(op, fn, shape, owner)`。handler 签名 `func(ctx: CardCtx, eff: Dictionary, source: String) -> void`；条件 fn 签名 `func(ctx: CardCtx, value) -> bool`；shape 签名 `func(value_or_eff) -> String`（空串 = 合法，否则是错误说明，校验器用）。**所有 op 的 shape 函数都在 W0 的 `scripts/cards/api/dsl_shapes.gd`（`CardDslShapes`）里**，主人登记时传 `CardDslShapes.shape(&"<op>")`；W0 的校验器从第一天就按它查数据。要改形状走 `[api]` issue。
- 效果**不偷偷掷随机**：要随机就用看得见的 `coin_check`（玩家看得见铜钱）或轮盘；`ctx.draw` 只给登记过的模块内部用（发牌、客人底线等，本来就藏着的东西）。
- 效果产生的“看得见的事”（钱变了、档位变了、牌走了、提示一行）通过 `ctx.emit()` 记进 `ctx.out`，指令结束时由门面按顺序发到 CardBus。
- `source` = 触发它的牌 uid 或 `"<模块>:<事由>"`，用于日志和去重。`CardOps.run(ctx, effects, source)` 给数组里第 i 个效果传 `source + "/" + str(i)`（嵌套的 `then`/`else`/`on_success`/`on_fail` 再往后接 `/then/<i>` 这类），所以每个效果都有唯一的**来源路径**；`coin_check` 用它进随机键（§6.3），同一张牌同一天的两个 `coin_check` 不会掷出同样的铜钱。
- 数字参数一律整数。

### 5.2 效果 op

| op | 参数 | 语义 | 主人 |
|---|---|---|---|
| `rep` | `delta:int` 或 `tier:int` | 口碑点数加减；`tier:+1` = 升到上一档的门槛（已在最高档不动），`-1` 同理 | G03 |
| `heat` | `delta` 或 `tier` | 风声；到 `meters.json` 的 `arrest_at` → 立即执行 `arrest` | G03 |
| `conscience` | `delta:int` | 本心（永不显示） | G03 |
| `attr` | `who:"ruhua"或人物 id, attr, delta:int, days?:int` | 属性加减；有 `days` 是临时的，到期自动还原 | G03 |
| `flag` | `key, value?=true` | 设旗标（`value` 可为 bool/int/String） | G03 |
| `flag_clear` | `key` | 清旗标 | G03 |
| `counter` | `key, delta:int` | 计数器 | G03 |
| `story` | `node, outcome` | 记主线走向，同时设旗标 `story.<node>` = outcome | G03 |
| `dossier` | `frag` | 补一块档案碎片（已是缺口的不能补；重复补无效） | G03 |
| `dossier_gap` | `frag` | 那一页留缺口（永久） | G03 |
| `notice` | `key, args?:{}` | 告示/日志一行（正文键） | G03 |
| `if` | `cond, then:[…], else?:[…]` | 条件分支 | G03 |
| `coin_check` | `coins:int, need:int, then:[…], else?:[…]` | 当场掷铜钱（发 `coins_tossed`，看得见）；随机键用来源路径（§5.1） | G03 |
| `person_state` | `person, state:"ok"/"hurt"/"jailed"/"away"/"gone"/"changed", days?:int` | 人物状态；`away`/`hurt`/`jailed` 有天数，期间不能放进格子、不会来柜台 | G03 |
| `contact_gain` / `contact_lose` | `person` | 得到/失去人脉（满了要你选一个让出来：引擎发 `request_panel("contacts_full")`） | G03 |
| `demand_tier` | `delta:int` | 下一张条子的档位偏移（人脉被动用） | G03 |
| `kept_risk` | `tags_any:[…]` | 手上带这些标签的留着的牌，依次执行它们的 `risk` | G03 |
| `add_card` | `card, to:"hand"/"kept"/"contacts"/"pending"/"queue", in_days?=0` | 发一张指定的牌；`in_days>0` 进日程队列，那天早上发；进手牌后 `CardPiles.order_hand()`；`to:"kept"` 而留牌满了：新牌先进 `pending`（`status:"overflow"`），引擎 `request_panel("kept_full", {new_uid})`，等玩家 `card.discard`（§7.4） | G01 |
| `remove_card` | `match:{def?,type?,tags_any?}, from:"hand"/"kept"/"pending"/"any", n=1` | 拿走牌 | G01 |
| `waive` | `match, n=1` | 免掉待处理牌的坏处：它被移走，`on_expire` 不执行 | G01 |
| `extra_deal` | `type, n=1, day:"today"/"tomorrow"` | 多发几张 | G01 |
| `money` | `delta:int, reason` | 进钱 / 花钱；花不起时按 `pay` 的 `short:"partial"` 处理 | G04 |
| `pay` | `amount:int, payee, reason, short:"ladder"/"partial"/"fail"` | 付钱。不够：`ladder` 触发钩子 `money_short`，由 G06 走“钱不够”阶梯（§7.4 `short.resolve`）；`partial` 付光为止；`fail` 一分不付并执行同一张牌的 `on_short` | G04 |
| `item_gain` | `template?/cat?, n=1` | 东西进货架 | G04 |
| `item_lose` | `match:{cat?,template?,pick:"best"/"worst"/"any"}, n=1, reason` | 东西没了 | G04 |
| `estate_seize` | `pick:"best"/"worst"/<家当 id>` | 拿走一件家当（没收，不是抵押） | G06 |
| `shop_closed` | `days:int` | 查封：这几天不**随机**抽人物牌（日程、钉签、金色牌照发，§7.4.6）；G06 也用它表示“牢里过夜的第二天铺子关门”（§7.4.7） | G04 |
| `arrest` | `reason` | 被抓 → 牢房牌 `pr.cell` 进手牌（`order_hand()` 把它排在金色牌之后、其他牌之前，§10.2）、`request_panel("prison")` | G06 |
| `price_mod` | `scope:"shelf"/"cat", cat?, pct:int, days:int` | 卖价临时修正：只改你卖货收钱（`receive`）这一头。`pct` 是**带符号的增量**：`5` = 涨 5%，`-8` = 落 8%；同时生效的几条相加，合计后不低于 `economy.json.price_mod_min_pct`【待调，起步 10】，卖价不会被压到零（框架版收尾默认，主创可改） | G04 |
| `currency_convert` | `to, num:int, den:int` | 换币：钱和账上一切按 num/den 换算 | G04 |
| `deck_mod` | `pool, tags_any?, def?, valence?, pct:int, days:int` | 临时调牌库权重（百分比） | G05 |
| `fate_now` | `day:"today"/"tomorrow"` | 立刻/明天发一张命运牌 | G05 |
| `big_wheel` | `crisis` | 发一张 `bf.wheel`（计入每关上限） | G05 |
| `wheel_offer` | `wheel, cost?` | 给一次去转的机会：发一张系统牌 `ev.any.wheel_go`（K02），`vars: {wheel, cost}`；处理它 = 打开那个轮盘（§9.2） | G05 |
| `pressure` | `key, delta_milli:int` | 内生压力（经 `PressureModel.add_influence`） | G05 |
| `weather` | `value:"clear"/"rain"/"fog"/"wind"/"snow"` | 改今天/明天的天气 | G05 |
| `peek` | `pool, n=1` | 提前看明天这个牌库的头 n 张：G05 用 `project()` 算出来并**钉住**，再发 `notice`（所以看到的一定会来） | G05 |
| `goal` | `id, status:"done"/"failed"` | 目标结果 | G02 |
| `game_over` | `reason` | 这一局结束 → `game_over` 阶段 | G02 |
| `stock_offer` | `n:int, kinds:["relic"/"source"…], depths?:["plain"/"storied"/"treasure"…], from:String` | 肉鸽 v1：立刻摆一份报价（id `p<abs_day>`）并 `request_panel("stocktake", {offer})`；货郎头一回用它（`p.stranger_peddler.1938.curios` 的 `look`）。没东西可摆发告示 `rg2.notice.peddler_empty`；模块没启用什么都不做（§15） | RG2 |

### 5.3 条件 op

| op | 值 | 语义 | 主人 |
|---|---|---|---|
| `all` / `any` / `not` | `[…]` / `[…]` / `{…}` | 组合 | G03 |
| `flag` | `key` | 旗标为真（bool/非零/非空串） | G03 |
| `flag_eq` | `[key, 值]` | 旗标等于 | G03 |
| `counter_gte` | `[key, n]` | 计数器 ≥ n | G03 |
| `story` | `[node, outcome]` | 主线走向 | G03 |
| `rep_tier_gte` / `rep_tier_lte` | `n` | 口碑档（0–4） | G03 |
| `heat_tier_gte` / `heat_tier_lte` | `n` | 风声档 | G03 |
| `conscience_gte` / `conscience_lte` | `n` | 本心（只在引擎里用） | G03 |
| `attr_gte` | `[who, attr, n]` | 属性 | G03 |
| `has_contact` | `person` | 有这个人脉 | G03 |
| `has_kept` | `{def?, tags_any?}` | 手上留着 | G03 |
| `person_state` | `[person, state]` | 人物状态 | G03 |
| `dossier_has` / `dossier_page_complete` | `frag` / `person` | 档案 | G03 |
| `demand_open` | `kind` 或 `"*"` | 手上有没办完的条子 | G03 |
| `day_gte` | `n` | 本关第几天 ≥ n | G02 |
| `abs_day_gte` | `n` | 从开局算第几天 | G02 |
| `weekday` | `n`（0 周一 … 6 周日） | 今天星期几 | G02 |
| `era` | `"1938"` | 当前年代 | G02 |
| `stage_gte` | `n` | 第几关（0 起） | G02 |
| `mode` | `"shop"` / `"street"` | 铺子开着 / 流落街头 | G02 |
| `phase` | 阶段名 | 当前阶段 | G02 |
| `goal_status` | `[id, status]` | 目标 | G02 |
| `money_gte` / `money_lt` | `n` | 钱 | G04 |
| `stock_cat_gte` | `[cat, n]` | 货架上这一类有几件 | G04 |
| `stock_has` | `template` | 货架上有这件 | G04 |
| `ticket_open` | `person` | 这个人有没赎的当票 | G04 |
| `mg_read` | `[def_id, "right"/"partial"/"wrong"]` | 这张文书（当票、信、电报）读得对不对（10-25；G04 记在 `econ.readings`；首发主线不按它分剧情） | G04 |
| `estate_status` | `[id, "held"/"mortgaged"/"lost"]` | 家当 | G06 |
| `currency` | `id` | 当前币种 | G04 |
| `weather` | `value` | 今天天气 | G05 |
| `market_day` | `true/false` | 集市日（读 G02 的 `CardCalendar.is_market_day`，不另抽） | G05 |
| `pressure_gte` | `[key, milli:int]` | 压力（千分整数） | G05 |
| `fortune` | 段 id | 本月运势落在哪一段 | G05 |
| `almanac_yi` | 动作名 | 今天黄历宜这个 | G05 |
| `veteran` | `true/false` | 肉鸽 v1：这本账的开头（`run.opening`）在 `rules/legacy.json` 里的 `veteran` 等于值；没有 `run` 当作 `false`（教学牌的日程 `when: {"not": {"veteran": true}}`，§15） | RG5 |

与 `scripts/core/cond.gd` 的对照：`c_flag`/`c_is` → `flag`/`flag_eq`；`c_stat` → `attr_gte`；`c_cash` → `money_gte`；`c_day` → `day_gte`；`c_stock_has` → `stock_has`；`c_stock_cat` → `stock_cat_gte`；`c_var` → `counter_gte`。柜台会话里的 `c_price/c_ask/c_floor…` 在卡牌版里不进数据（底线藏在 G04 里）。

---

## 6. 状态模型 CardState 与随机数域登记（f）

### 6.1 CardState（即 CardGameState）

`CardState.data` 是一个只含 `int / String / bool / Array / Dictionary` 的字典（**不许有浮点数**：比例存整数百分比、压力存千分整数、角度存千分之一度）。顶层按模块分命名空间，**每个命名空间只有它的主人写**，别的模块只读（要改就调主人提供的函数或发效果 op）：

```json
{
  "v": 1, "seed": 12345, "difficulty": "normal", "db_hash": "…",
  "core": {
    "uid_seq": 41, "deal_seq": 57,
    "cards": {"c0007": {"uid": "c0007", "def": "p.linsao.1938.pawn_hairpin", "zone": "hand", "seq": 55,
                        "dealt_abs_day": 9, "expires_abs_day": -1, "status": "open",
                        "placed": {}, "choice": "", "item_id": "", "vars": {}}},
    "zones": {"hand": ["c0007"], "kept": [], "contacts": [], "demands": [], "pending": [], "discard": []},
    "queue": [{"def": "nw.any.family_word", "abs_day": 10, "zone": "hand"}],
    "deals": {"9": ["c0005", "c0006", "c0007"]},
    "draw_k": {"person": {"abs_day": 9, "k": 3}, "event": {"abs_day": 9, "k": 1}},
    "firsts": {"month_open": 0, "deal": 1, "person": 1, "counter": 1}
  },
  "loop": {
    "phase": "day", "mode": "shop", "stage": 0, "stage_day": 9, "abs_day": 9, "minute": 540,
    "goals": [{"id": "gl.1938.keep_shop", "main": true, "status": "open"}],
    "night": {"offers": [], "chosen": "", "choice": ""},
    "gold_left": [], "reports": {"settle": {}, "month": {}, "year": {}},
    "open_panel": {"kind": "", "args": {}}
  },
  "rules": {
    "meters": {"rep": 10, "heat": 0, "conscience": 0},
    "attrs": {"ruhua": {"eye": 2, "tongue": 1, "pull": 1, "nerve": 1}},
    "attr_mods": [], "flags": {}, "counters": {}, "story": {},
    "persons": {"xiaoding": {"state": "ok", "until_abs_day": 0, "used_abs_day": 0}},
    "demand": {"tier_bias": 0, "issued": {}},
    "dossier": {"linsao": {"have": [], "gaps": [], "new": []}},
    "attempts": {}
  },
  "econ": {
    "ledger": {}, "currency": "fabi", "price_index": 100,
    "sessions": {}, "items_meta": {"I004": {"template": "jewelry.hairpin", "cat": "jewelry", "condition_permille": 820, "observations": []}},
    "price_mods": [], "shop_closed_until": 0, "foreign_tickets": []
  },
  "ladder": {
    "estates": {"es.shopfront": {"status": "held", "since_abs_day": 0, "principal": 0}},
    "street": {"since_abs_day": 0}, "short": {}, "prison": {"uid": "", "nights": 0}
  },
  "fate": {
    "pressures_milli": {"c_unrest": 300}, "wheel_last": {}, "influence_spent": {},
    "weather": "rain",
    "month_segment": "", "month_mods": [], "deck_mods": [],
    "pins": {"12": ["fa.any.fire_next_door"]}, "bans": {"12": ["omen_water"]},
    "fate_last_abs_day": 6, "big": {"stage_count": 0, "crises_used": []},
    "wheels": {"wh.month:": {"spin_no": 1, "incense": [], "stake": "", "result": {"segment": "", "stop_mdeg": 0}}},
    "almanac": {"id": "", "done": []}, "lots": [], "lot_count": 0
  },
  "ui": {"guide": {"gd.d1.deal": {"shows": 1, "status": "done", "abs_day": 1}}}
}
```

- **钱和物品、当票**都在 `econ.ledger`（G04 的 `card_ledger.gd`——继承 `scripts/core/ledger.gd`——的 `to_dict()`；读档时 `from_dict()`）。账本里的数全是整数（月息 `rate_pct`、保管费 `storage_permille`），合同 id、原因码全是 ASCII（`t0001`），当票号是整数；ItemGen 生成的物品只存清洗过的整数字段（`condition_permille` 等），不存浮点（`condition`、`ask_w`）、不存中文（`name`、`cat_cn`、`ticket_condition`、中文标签）、不存它的原始缓存。界面看到的 uid：牌 `c0007`（`core.uid_seq` 递增，`"c%04d"`），物品用账本的物品 id（`I001`）。
- **`ladder`** 命名空间是 G06 的（家当、街头、钱不够、牢里过了几晚）；**`ui`** 命名空间是 G01 的，只经指令 `ui.guide` 写（新手指引的进度，§7.10.6）：只有整数和字符串；**不进状态哈希、不进黄金种子**；新局为空；读档和“重来本关”时取“当前内存里的 ∪ 存档里的”（`done` 优先、`shows` 取大），所以重来一关不会把教过的再教一遍。
- **没有浮点**：G01 的测试对三关浸泡途中每天的状态跑 `card_t.find_floats(state.data)`，必须为空。
- `CardState` 方法（G01）：
  ```gdscript
  class_name CardState
  extends RefCounted
  var data: Dictionary
  static func create(seed: int, opts: Dictionary) -> CardState   # 只建空命名空间；各模块在 stage_start 钩子里填初值
  func ns(name: String) -> Dictionary                              # data[name]，不存在就建
  func to_dict() -> Dictionary                                     # data.duplicate(true)
  static func from_dict(d: Dictionary, restore_ints: bool = true) -> CardState   # 把 JSON 读回来的整数值浮点数还原成 int；校验 v（比自己新返回 null）；不认识的命名空间原样保留。restore_ints 可选、默认 true，只传一个参数照旧；调用方已经还原过整数时传 false（例 CardSave.read 经 CardDB.read_json 读档）（#205）
  func hash() -> String                                            # 去掉 "ui" 后 JSON.stringify(d, "", true, true)（排序键、全精度）的 sha256
  func new_uid() -> String
  ```
- 存档文件（CardSave，G01）：`{"format": "dehoudang-cards-save", "v": 1, "db_hash": "…", "saved_at_phase": "morning", "meta": {"stage": 0, "abs_day": 9}, "state": {…}, "cmd_log": [[cmd, args], …]}`（同样用全精度 JSON 写）。**指令日志在信封里，不在状态里**（状态小、哈希稳；`ui.*` 指令不记）。路径：`<根>/stage_%02d.json`（每关开头，不覆盖）、`<根>/suspend.json`（每天早上覆盖的续玩点）；根默认 `user://cards`，可以 `CardSave.set_root()` 或 `new_game({save_dir})` 改——测试一律用 `user://test/<清单名>/`（`card_t` 给、跑完清掉），并行的测试不会抢同一个文件。`db_hash` 不一致时照样读，`meta.db_changed = true`。只在 `morning` 和 `month_open` 阶段存（这时没有打开的柜台会话）。
- 模块升级存档格式：在自己的命名空间里放 `"_v": n`，读档时自己迁移。顶层 `v` 只增不减：读到比自己新的 `v` 返回 `err: "save_newer"`；解放后分支要的东西放进新的命名空间，不改已有命名空间的含义（向前兼容）。

### 6.2 随机的写法

```gdscript
var u: float = ctx.draw("c.coin", [ctx.abs_day(), uid, attempt, i])   # [0,1)
var pick: String = JevRng.weighted_choice(rows, u)                     # rows: [[id, weight_int], …]，按 id 排好序（轮盘例外：按扇区显示顺序，§9.1）
```
- 键只用整数和字符串；JSON 读回来的数先 `int()`。
- 遍历字典改状态或抽签前**先按键排序**。
- 一次决定只抽一次：同一个键重复调用得到同一个数（这正是“读档不能刷”的保证）；同一张牌要多次掷，用 `rules.attempts[uid]` 计数放进键里。
- `ctx.draw()` 在开发版里检查 domain **精确命中** `CardIds.RNG_DOMAINS`（下表逐行登记成精确串或正则 + 主人任务号；不用前缀匹配——`c.mg.` 这个前缀分不清 G04 和 C12–C15），没登记的 `push_error`（会让测试失败）。

### 6.3 随机数域登记表（只许用自己的）

| 域 | 主人 | 键 | 用途 |
|---|---|---|---|
| `c.deal.<pool>`（pool：person event news fate life big_fate night street） | G01 | `[abs_day, k]` | 今天第 k 次从这个牌库抽；k 存在 `core.draw_k`，同一天加发、读档后再发都接着数，不会重复同一抽 |
| `c.deal.n.person` · `c.deal.n.news` | G01 | `[abs_day]` | 今天几张人物、有没有消息 |
| `c.deal.sub` | G01 | `[abs_day, def_id]` | 钉住的牌到时候不能发，找同征兆的替身 |
| `c.sched.life.n` · `c.sched.life.day` · `c.sched.life.pick` | G02 | `[stage, week]` · `[stage, week, k]` · `[stage, week, k]` | 这周几张生活牌、第 k 张落在哪天（避开脚本日）、是哪一张 |
| `c.goal.pick` | G02 | `[stage, k]` | 挑可选目标 |
| `c.year.<person>` | G02 | `[stage]` | 跨年人脉变化 |
| `c.coin` | G03 | `[abs_day, uid, attempt, i]` | 铜钱正反；格子检定用牌 uid，`coin_check` 用它的来源路径（§5.1，含牌 uid 和效果序号） |
| `c.demand.kind` · `c.demand.pick` · `c.demand.amt` | G03 | `[stage, week]` · `[stage, week, kind]` · `[stage, week]` | 本周条子的类、哪一张、数目浮动 |
| `c.cust.asking` · `c.cust.floor` · `c.cust.patience` · `c.cust.want` | G04 | `[abs_day, uid]` | 客人报价、底线、耐心、要哪类 |
| `c.cust.reply` | G04 | `[abs_day, uid, round]` | 客人这一轮怎么回 |
| `c.redeem.come` | G04 | `[ticket_no, abs_day]` | 当户今天来不来赎 |
| `c.mg.pick` | G04 | `[abs_day, uid, item_id]` | 这次出哪个小游戏 |
| `c.mg.param` | G04 | `[item_id, kind, i]` | 物理参数；`i = "seed"` 抽小游戏的布局种子：`params.seed = int(u × 2147483647)`；10-25 起 `i` 可以是 `"<名>.<序号>"`（例 `"bad.0"`、`"authenticity.at"`）；没物品的文书用 `"doc:<def id>"` 代替空 `item_id` |
| `c.street.<x>` · `c.prison.<x>` | G06 | `[abs_day, …]` | 街头、牢房 |
| `item_*`（ItemGen 自带的域） | G04 | `["c", abs_day, uid, …]` | 物品生成；键第一个元素固定 `"c"` |
| `pressure:c_<key>`（经 PressureModel） | G05 | `[abs_day]` | 时局压力（键名以 `c_` 开头） |
| `wheel:c_climate`（经 WorldWheel） | G05 | `[abs_day]` | 天气（**集市日不抽**，按 `stages.json` 的日历算） |
| `c.fate.due` | G05 | `[abs_day]` | 今天发不发命运牌 |
| `c.wheel.<wheel_id>` | G05 | `[abs_day, uid, spin_no]` | 轮盘停在哪（`uid` 是那张牌，本月运势为 `""`） |
| `c.lot.pick` · `c.lot.verse` | G05 | `[abs_day, lot_count, k]` · `[abs_day, lot_count]` | 挑哪几张写进签、选哪支签 |
| `c.cezi.offer` | G05 | `[abs_day, uid]` | 今天这个摊上摆哪几个字 |
| `c.almanac` | G05 | `[stage, stage_day]` | 今天的黄历 |
| `c.ai.<policy>` | G06 | `[seed, step]` | 自动玩的随机策略 |
| `c.mg.spot.layout` · `c.mg.coin_ring.layout` · `c.mg.weigh.layout` · `c.mg.fragments.layout` · `c.mg.decode.layout` | C12 · C13 · C14 · C15 · C15 | `[i]`，种子参数是 `params.seed`：`JevRng.draw(params.seed, 域, [i])`；下标分段（10-25）：`[0, 999]` 摆设、`[5000, 5999]` 装饰、`[9000, 9999]` 自动玩（`autoplay(skill)` 用 `[9000 + i] < skill` 定第 i 个判断判对，`[9100 + i]` 定怎么判错） | 小游戏的摆放、碎片形状等（只影响画面和手感） |
| `c.stock.offer` | RG2 | 周末盘账 `[stage, week, k]`；货郎（`stock_offer`）`[stage, "p", abs_day, k]`（k = 第几格） | 肉鸽 v1：报价里摆哪几样（`JevRng.weighted_choice`，行按 id 排好序）；报价生成那一刻抽完、记进 `stock.offers`，读档、重来都是同一份（§15） |
| `m.run.seed` | RG2 | `[run_no, reroll]`，种子 = 档案盐（v1 恒为 0） | 肉鸽 v1：`CardRunSeed.derive(salt, run_no, reroll)` 给新一本账推一个种子（第一本、没换过 = 7）；外壳直接调 `JevRng.draw`，不经 `ctx.draw`、不影响局内状态，登记只为文档 |
| `m.run.seed_text` | RG2 | `[text 前 24 字]`，种子 = 0 | 肉鸽 v1：`CardRunSeed.parse(text)` 把标题种子框里不是纯数字的字变成种子（纯数字照用，折回 `1..2147483646`；空 = `-1` 用建议种子） |
| `c.qa.<x>` | K14 | 任意 | QA 脚本 |
| `c.mock` | W0 | 任意 | Mock |

C01–C11 不用 JevRng（界面不抽签，结果都来自引擎）。界面里纯装饰的抖动（灰尘、铜钱翻转的圈数）可以用 `RandomNumberGenerator`，但必须固定种子，且不影响任何结果。

---

## 7. 模块接口（g）

所有 `class_name` 一律以 `Card` 开头（避开现有的 `TownSim` `ItemGen` `DB` 等）。下面写到的类、方法、信号、参数名都是**冻结的**；W0 给每个类建桩（同签名，返回 `{"ok": false, "err": "not_implemented"}` 或最简单的结果），主人只改函数体、加私有函数。要加公开方法：可以加，但要在 PR 里列出来；要改已有签名：`[api]` issue。**只有本章、§8.1 和 §7.10 表里的类写 `class_name`**；新的公开类要在 PR 里列出、Claude 同意后才加；辅助脚本一律 `const X = preload("res://…")`（§0）。

`CardIds` 在 W0 就列全了 v1 + v1.1 + 新手指引要用的常量：阶段、模式、类型、属性、指令名、查询名、错误码、钩子名、面板 kind、小游戏 kind、黄历动作、`FIRSTS`（§7.10.10）、`ANCHORS` 与 `UI_EVENTS`（§7.10.5）、`GUIDE_COND_OPS`（V35）、`RNG_DOMAINS`（§6.3）。之后各模块新加的常量放自己的 `<模块>_ids.gd`，不改 `card_ids.gd`。

### 7.1 文件与类

| 文件 | class_name | 主人 |
|---|---|---|
| `scripts/cards/api/card_engine_api.gd` | `CardEngineApi`（`@abstract`） | Claude |
| `scripts/cards/api/card_minigame.gd` | `CardMiniGame`（`@abstract`，extends Control） | Claude |
| `scripts/cards/api/card_ids.gd` | `CardIds`（常量：阶段、类型、属性、指令名、错误码、钩子名、面板 kind） | Claude |
| `scripts/cards/api/card_ship.gd` | `CardShip`（`is_ship()` = `OS.has_feature("ship")`） | Claude |
| `scripts/cards/api/dsl_shapes.gd` | `CardDslShapes`（§5.2/§5.3 每个 op、指引数据的形状函数；校验器和各模块的登记都用它） | Claude |
| `scripts/cards/api/card_layout.gd` | `CardLayout`（画面坐标常量，§7.11.2） | Claude |
| `scripts/cards/core/card_bus.gd` | `CardEventBus`（extends Node；autoload 名 `CardBus`） | G01 |
| `scripts/cards/core/card_db.gd` · `card_state.gd` · `card_ctx.gd` · `card_registries.gd`（`CardOps` `CardConds` `CardMods` `CardHooks` `CardActions`） · `card_piles.gd` · `card_composer.gd` · `card_save.gd` · `card_text.gd` · `card_validator.gd` · `validate_main.gd` · `firsts.gd` · `core_install.gd`（`CardCoreInstall`） | `CardDB` `CardState` `CardCtx` … `CardPiles` `CardComposer` `CardSave` `CardText` `CardValidator` `CardFirsts` | G01 |
| `scripts/cards/loop/card_engine.gd` · `day_loop.gd` · `calendar.gd` · `schedule.gd` · `gold_rule.gd` · `goals.gd` · `year_jump.gd` · `view_model.gd` · `loop_install.gd` | `CardEngine` `CardDayLoop` `CardCalendar` `CardSchedule` `CardGoldRule` `CardGoals` `CardYearJump` `CardViewModel` `CardLoopInstall` | G02 |
| `scripts/cards/rules/slots.gd` · `coins.gd` · `choices.gd` · `effects_core.gd` · `conds_core.gd` · `meters.gd` · `kept_rules.gd` · `demands.gd` · `dossier.gd` · `rules_install.gd` | `CardSlots` `CardCoins` `CardChoices` `CardEffectsCore` `CardCondsCore` `CardMeters` `CardKeptRules` `CardDemands` `CardDossier` `CardRulesInstall` | G03 |
| `scripts/cards/economy/counter.gd` · `pricing.gd` · `customer.gd` · `shelf.gd` · `tickets.gd` · `card_ledger.gd`（不写 class_name） · `appraisal.gd` · `items.gd` · `currency.gd` · `month_accounts.gd` · `economy_install.gd` | `CardCounter` `CardPricing` `CardCustomer` `CardShelf` `CardTickets` `CardAppraisal` `CardItems` `CardCurrency` `CardMonthAccounts` `CardEconomyInstall` | G04 |
| `scripts/cards/ladder/mortgage.gd` · `short_ladder.gd` · `street.gd` · `prison.gd` · `ladder_install.gd` | `CardMortgage` `CardShortLadder` `CardStreet` `CardPrison` `CardLadderInstall` | G06 |
| `scripts/cards/fate/weights.gd` · `fate_trigger.gd` · `wheel.gd` · `fortune.gd` · `almanac.gd` · `pins.gd` · `pressure.gd` · `fate_install.gd` | `CardWeights` `CardFateTrigger` `CardWheel` `CardFortune` `CardAlmanac` `CardPins` `CardPressure` `CardFateInstall` | G05 |
| `scripts/cards/sim/autoplay.gd` · `policy.gd` · `policies/*.gd` · `replay.gd` · `balance_main.gd` | `CardAutoplay` `CardPolicy` `CardReplay` | G06 |
| `scripts/cards/relic/relic_install.gd` · `relic_api.gd` · `relic_mods.gd` · `relic_hooks.gd` · `relic_view.gd` · `relic_ids.gd`（肉鸽 v1） | 都不写 `class_name`（`preload`） | RG1 |
| `scripts/cards/stock/run_seed.gd` · `stock_install.gd` · `stock_pick.gd` · `stock_offers.gd` · `stock_mods.gd` · `stock_state.gd` · `stock_view.gd` · `stock_ids.gd`（肉鸽 v1） | `CardRunSeed`（`run_seed.gd`；外壳也调，签名冻结）· 其余不写 | RG2 |
| `scripts/cards/legacy/legacy_install.gd` · `legacy_run.gd` · `legacy_harvest.gd` · `legacy_ids.gd`（肉鸽 v1） | 都不写 | RG5 |
| `scripts/cards/meta/card_profile.gd` · `run_keeper.gd`（肉鸽 v1，外壳） | `CardProfile` · `run_keeper.gd` 不写（`extends Node`，根场景 `preload`） | RG5 |
| `scripts/cards/ui/rogue/stocktake_panel.gd` · `relics_drawer.gd`（`extends CardPanel`）· `curio_shelf.gd` · `title_run_box.gd` · `offer_card.gd` · `release_row.gd` · `rogue_ui.gd`（肉鸽 v1） | 都不写 | RG4 |
| `scripts/cards/mock/mock_engine.gd` | `MockCardEngine` | Claude |
| `scripts/cards/ui/common/card_panel.gd` · `card_anchors.gd` · `card_theme.gd` | `CardPanel`（演出面板的子类 `CardStagePanel` 见下两行）`CardAnchors`（Claude） · `CardTheme`（C01） | |
| `scripts/cards/ui/common/card_stage_api.gd` · `card_dialog_api.gd` · `card_hand_api.gd` · `card_hero_api.gd` · `card_checks_api.gd` | `CardStageApi` `CardDialogApi` `CardHandApi` `CardHeroApi` `CardChecksApi`（接口基类，§7.11） | Claude |
| `scripts/cards/ui/common/card_stage_panel.gd` · `card_stage_script.gd` | `CardStagePanel` `CardStageScript`（§7.11.4） | Claude |
| `scripts/cards/ui/shell/card_guide.gd` | `CardGuide`（新手指引引擎，§7.10.7） | C16 |
| `scripts/cards/ui/table/card_stage.gd` | `CardStage` | C01 |
| `scripts/cards/ui/card/hand_fan.gd` · `hero_bar.gd` | `CardHandFan` `CardHeroBar` | C02 |
| `scripts/cards/ui/slots/counter_checks.gd` · `contacts_drawer.gd` | `CardCounterChecks` `CardContactsDrawer` | C03 |
| `scripts/cards/ui/counter/dialog_box.gd` · `shelf_drawer.gd` · `tickets_drawer.gd` | `CardDialogBox` `CardShelfDrawer` `CardTicketsDrawer` | C04 |
| `scripts/cards/ui/demand/demands_drawer.gd` | `CardDemandsDrawer` | C05 |
| `scripts/cards/ui/fortune/almanac_drawer.gd` | `CardAlmanacDrawer` | C07 |

### 7.2 CardEngineApi（界面、自动玩、测试唯一能碰的引擎接口）

```gdscript
@abstract
class_name CardEngineApi
extends RefCounted

var bus: CardEventBus = null            # 由创建者注入；无头测试自己 new 一个

@abstract func new_game(opts: Dictionary) -> Dictionary
	# opts: {seed:int, difficulty:"normal", stage:int=0, data_root:String="res://data/cards", only_examples:bool=false, save_dir:String="user://cards"}
	# 返回 {ok, err}；成功后阶段为 month_open
@abstract func load_game(path: String) -> Dictionary      # {ok, err, meta}
@abstract func save_game(path: String) -> Dictionary      # {ok, err}；只在 morning / month_open 可存
@abstract func view() -> Dictionary                       # §7.5；同一状态永远返回同样内容
@abstract func send(cmd: StringName, args: Dictionary = {}) -> Dictionary   # §7.4；永远返回 {ok:bool, err:String, …}
@abstract func query(q: StringName, args: Dictionary = {}) -> Dictionary    # §7.4；只读
@abstract func is_busy() -> bool                          # send 正在执行（防重入）
```

- `send()` 的执行顺序：检查阶段与参数 → 改状态 → **依次把 `ctx.out` 里的事件发到 bus**（`first_time` 也在里面，按发生顺序）→ 发 `command_done(cmd, args, ok)` → 发 `view_changed` → 返回结果。失败的指令同样发 `command_done`（`ok = false`）和 `view_changed`。例外：`ui.*` 指令只改 `ui` 命名空间，什么事件都不发、不进指令日志。界面**不要在 CardBus 回调里同步调用 `send()`**（会得到 `err: "busy"`），要调就 `call_deferred`。
- 结果里的错误码（`CardIds.ERR_*`）：`""`（成功）`bad_phase` `bad_args` `unknown_uid` `unknown_def` `not_allowed` `cond_failed` `insufficient_money` `slot_full` `slot_reject` `slot_required` `person_busy` `kept_full` `not_keepable` `must_resolve_pending` `gold_pending` `wheel_pending` `already_resolved` `no_such_choice` `stock_empty` `estate_state` `stake_required` `no_minigame` `overflow_pending` `save_newer` `busy` `not_implemented`。失败时可以带 `reason_key`（正文键）给界面显示。1.2 起：`must_resolve_pending` = `day.end {confirm: false}` 时还有要确认的清单（不再是“挡住”）；`gold_pending` 不再返回；`day.end` 不受 `overflow_pending` 拦截（§7.4.7）。
- **诊断函数 `CardEngine.state_hash() -> String`**（G02，#41）：只在真引擎 `CardEngine` 上，不在 `CardEngineApi` 里，Mock 没有。返回当前状态的 `CardState.hash()`（§6.1，不含 `ui`）；还没开局返回 `""`。只读：不改状态、不发事件、不进指令日志，不交出状态对象和任何隐藏值。给自动玩、回放、黄金种子、平衡脚本和测试比对状态用（G06 的 `scripts/cards/sim/cached_api.gd` 转发它）；界面不许调，哈希也不给玩家看。

### 7.3 CardCtx 与登记表（G01）

```gdscript
class_name CardCtx
extends RefCounted
var state: CardState
var db: CardDB
var bus: CardEventBus
var ops: CardOps
var conds: CardConds
var mods: CardMods
var hooks: CardHooks
var actions: CardActions
var out: Array = []                                         # 本次指令的可见事件 [[信号名, 参数…], …]
var ledger                                                  # G04 挂上的账本对象（economy/card_ledger.gd，继承 scripts/core/ledger.gd）
func seed() -> int
func abs_day() -> int
func draw(domain: String, key: Array) -> float               # JevRng.draw(seed(), domain, key) + 开发版检查登记
func emit(signal_name: StringName, args: Array) -> void      # 追加到 out
func run(effects: Array, source: String) -> void             # = ops.run(self, effects, source)
func test(cond) -> bool                                      # = conds.test(self, cond)
func rules(name: String) -> Dictionary                       # = db.rules(name)

class_name CardOps            # 效果 op
func register(op: StringName, handler: Callable, shape: Callable, owner: String) -> void
func run(ctx: CardCtx, effects: Array, source: String) -> void
func validate(effect: Dictionary) -> String
func known() -> PackedStringArray

class_name CardConds          # 条件 op
func register(op: StringName, fn: Callable, shape: Callable, owner: String) -> void
func test(ctx: CardCtx, cond) -> bool
func validate(cond) -> String

class_name CardMods           # 修正项：谁都能提供，谁都能问
func register(kind: StringName, provider: Callable, owner: String) -> void   # provider: func(ctx, args) -> Variant
func sum_int(ctx: CardCtx, kind: StringName, args: Dictionary) -> int        # 各提供者返回 int 相加
func pct(ctx: CardCtx, kind: StringName, args: Dictionary) -> int            # 各提供者返回百分比，连乘（100 为不变）
func collect(ctx: CardCtx, kind: StringName, args: Dictionary) -> Array      # 各提供者返回数组，拼起来
func any_true(ctx: CardCtx, kind: StringName, args: Dictionary) -> bool
func merge(ctx: CardCtx, kind: StringName, args: Dictionary) -> Dictionary  # 各提供者返回 Dictionary，按登记顺序合并；键冲突 push_error（view_section / card_view_part 用）

class_name CardHooks          # 生命周期钩子
func on(name: StringName, fn: Callable, priority: int, owner: String) -> void   # fn: func(ctx, args: Dictionary) -> void
func fire(ctx: CardCtx, name: StringName, args: Dictionary = {}) -> void         # 按 priority 从小到大，同 priority 按登记顺序

class_name CardActions        # 手牌上的动作（视图里的 actions）
func register(type: StringName, provider: Callable, owner: String) -> void      # provider: func(ctx, uid) -> Array[Dictionary]
func for_card(ctx: CardCtx, uid: String) -> Array
```

**模块安装顺序**（CardEngine 构造时，W0 已写好前六段）：`CardCoreInstall.install(engine, ctx)` → `CardRulesInstall` → `CardEconomyInstall` → `CardLadderInstall` → `CardFateInstall` → `CardLoopInstall`。K18 的收徒模块接在这六段之后（合同 1.4，无 `class_name`，`preload`），不插入、不重排前六段。肉鸽 v1 的三个模块再接在收徒之后：`relic/relic_install.gd`（RG1）→ `stock/stock_install.gd`（RG2）→ `legacy/legacy_install.gd`（RG5），同样无 `class_name`、只追加、不重排（§15）。每个 `install(engine: CardEngine, ctx: CardCtx) -> void` 只做登记：指令（`engine.register_command`）、查询（`engine.register_query`）、效果/条件 op、修正项、钩子、动作。**不许有可变的 `static var`**（缓存不可变数据除外；`CardSave` 的存档根目录这种配置除外），一切状态在 `ctx.state`。`loop` 命名空间只有 G02 写：别的模块要开面板用 `CardDayLoop.request_panel()`，要换模式用 `CardDayLoop.set_mode()`。

**修正项 kind**（谁提供 → 谁问）：

| kind | 参数 | 返回 | 提供者 | 使用者 |
|---|---|---|---|---|
| `deal_count` | `{type}` | int 增减 | G04（查封）、G06（柜台押出 −1；在牢里过夜时——`ladder.prison.uid` 不空——把 `night`、`street` 减到 0）、G05（天气/集市）、G03（人脉被动）；肉鸽 v1：RG1（老物件 `mods` 的 `deal_count {type, delta}`，钳子 `rules/relics.json` `clamp.deal_count_*`）、RG2（这一关生效的客源，钳子 `rules/stock.json` `clamp.deal_count_*`）——两家都用问的人给的 `type`，`project()` 预测未来日也照问 | G01 发牌（加完按 0 截断；`night_offers()` 也问 `{type: "night"}`） |
| `pool_rows` | `{pool}` | `[[def, weight]]` | G05（CardWeights） | G01 发牌、`project()` |
| `scheduled_cards` | `{abs_day}` | `[def, …]` | G02（CardSchedule）、G01（`queue`） | G01 |
| `pinned_cards` | `{abs_day}` | `[def, …]` | G05（CardPins） | G01 |
| `fate_due` | `{}` | bool | G05 | G01 |
| `pool_pct` | `{pool, def}` | 百分比 | G06（家当：老宅押出生活牌变多）、G03（人脉 `mods` 里的 `pool_weight`：王山、林嫂、孙府管家；`tags_any` 空 = 整个牌库）（框架版收尾默认，主创可改）；肉鸽 v1：RG1（老物件 `mods` 的 `pool_weight {pool, tags_any?, intents?, pct}`）、RG2（这一关生效的客源，同形状）——都只看 `args.def` 在 `ctx.db` 里的标签与来意，没有持有的物件 / 生效的客源时第一行就返回 100（每个候选都要问一遍） | G05（CardWeights） |
| `cap` | `{zone}` | int 增减 | G06（家当：库房）、G03、RG1（老物件 `mods` 的 `shelf_cap` → `{zone: shelf}`、`kept_cap` → `{zone: kept}`，各有钳子） | G01（kept/contacts）、G04（货架） |
| `intake_blocked` | `{cat}` | bool | G06（首饰柜押出）、G03（人脉 `mods` 里的 `no_intake_cat`） | G04 柜台 |
| `price_pct` | `{direction, cat, item_id}` | 百分比 | G04（`price_mod`：把各条增量加起来再换成百分比，`100 + Σpct`，有下限，§5.2）、G05（运势）、RG1（老物件 `mods` 的 `price_pct {direction, cats?, pct}`，按 `direction` 分两组钳子） | G04 |
| `coins` | `{uid, slot_id, source}` | int 增减 | G03（临时属性、受伤）、RG1（老物件 `mods` 的 `coins {source_kind, slot_tags_any?, delta}`：放进去的东西是这一类、格子带这些标签才加） | G03 |
| `patience_pct` | `{uid}` | 百分比 | G03（口碑）、RG1（老物件 `mods` 的 `patience_pct {pct}`） | G04 |
| `appraise_pct` | `{cat, item_id}` | 百分比 | G03（人脉 `mods` 里的 `appraise_pct {cat?/cats?, pct}`，例：陈文庭 `cats: ["art", "medicine"], pct: 120` 让书画、药材的线索更清楚；`cat` 写一类、`cats` 写一组，都不写 = 所有品类）（框架版收尾默认，主创可改）、RG1（老物件 `mods` 的 `appraise_pct {cats?, pct}`，同样乘在 `quality_permille` 上） | G04（乘到 `quality_permille` 上再定清晰度） |
| `hand_sub` | `{uid}` | int | G02（金色牌返回 `schedule.order`，其余 0） | G01（`order_hand()` 的子键） |
| `view_section` | `{}` | Dictionary（要放进视图顶层的键值） | G01、G03、G04、G05、G06 各交自己那一块；肉鸽 v1：RG1 交 `relics`、RG2 交 `stock`、RG5 交 `run`（§7.5） | G02（合并；键冲突是程序错误） |
| `card_view_part` | `{uid, detailed}` | Dictionary（这张牌视图里本模块的字段） | G03（格子、选项、条子天数）、G04（物品、报价、观察、能不能看东西）、G05（轮盘/算命信息）、G06 | G02（合并） |
| `end_rows` | `{}` | `[EndRow]`（打烊清单里归本模块的行，§7.4.7） | G01（溢出、生活牌、能留的牌）、G02（人物、金色、事件、命运、街头、大赌、今天的机会）、G03（人脉满、条子）、G05（`bf.wheel`）、G06（牢房、钱不够） | G02（`day.end_preview` 与 `day.end` 合并、排序） |
| `unscripted_day` **（肉鸽 v1）** | `{stage, stage_day}` | bool（`any_true`） | RG5（这本账的开头 `veteran` 且是第 0 关时为真） | G01（`CardComposer.is_scripted_day`：`deal.json` 的 `scripted_days` 里那一天，有提供者说真就不当教学脚本日、照常随机发牌；没有提供者 = 照旧） |

**钩子**（名字、谁触发、谁听、priority）：

| 钩子 | 触发者 | 参数 | 监听（priority 主人：做什么） |
|---|---|---|---|
| `stage_start` | G02 | `{stage}` | 10 G04：币种、物价指数、首局的钱 · 15 G06：首局的家当 · 20 G03：首局的口碑/风声/本心/属性 · 30 G05：清本月运势与大命运计数 · 40 G02：挑目标 · 50 G01：清理不属于新年代的手牌与待办 · 60 RG2（肉鸽 v1）：删掉不是本关的客源，删了发告示 `rg2.notice.sources_lapsed` |
| `month_open` | G02 | `{}` | 10 G05：`CardDayLoop.request_panel(ctx, &"wheel", {wheel: "wh.month", uid: "", required: true})` |
| `day_start` | G02（发牌前） | `{abs_day}` | 2 RG5（肉鸽 v1）：开头 `veteran` 且第 0 关第 1 天，发开头告示（`rules/legacy.json` 的 `openings.<id>.notice`） · 3 RG2（肉鸽 v1）：早于今天的 `open` 报价标成 `lapsed`，标了就发告示 `rg2.notice.lapsed`（早上的告示板说那份收回去了） · 10 G05：压力、天气、黄历（集市日读日历） · 20 G03：到期的临时属性还原、人物回来 · 25 RG1（肉鸽 v1）：持有物件 `passives`/`downsides` 里 `hook == "day_start"` 的行（在发条子之前，`demand_tier` 落到当天的条子上；不灵时不跑） · 30 G03：周一发条子 · 40 G04：安排来赎的人、货架价格修正到期、查封到期 · 50 G03：人脉被动 `day_start` |
| `deal_composed` | G01（已经 `order_hand()` 过） | `{uids}` | 20 G03：人脉被动 `deal`；first-time `slots` `choice` · 30 G05：first-time `fate` `big_wheel` `lot` `cezi` `fair_wheel` `gamble_wheel` |
| `card_resolved` | 处理牌的模块（经 `CardPiles.resolve(ctx, uid, outcome, extra)`） | `{uid, outcome, almanac:[…]}`（`almanac` 来自 `extra.almanac`） | 10 G05：黄历记事 · 20 G02：目标与主线记账 · 35 RG2（肉鸽 v1）：`almanac` 含 `"trade"`（柜台成交都带）→ 这一周成交笔数 +1 |
| `day_end` | G02（`day.end` 白天那一步，确认后） | `{}` | 5 G01：留牌溢出没选 → 扔掉新来的 · 6 G03：人脉满没选 → 新来的不留；格子里没掷的还回来 · 7 G06：钱不够没选 → 认了 · 8 G04：关掉开着的柜台会话 · 10 G02：金色牌走掉、人物走掉（记仇的执行 `on_expire`）、事件/命运/街头/大赌按没理会、今天的机会过去 · 15 G05：`bf.wheel` 作废、没转的轮盘退还香案和押牌 · 20 G01：生活牌留到明天/到期、手上能留的牌留着 · 25 G06：牢房多待一晚或到期失败（§7.4.7 的表） |
| `night_chosen` | G02 | `{def}` | 10 G05：黄历记事 |
| `settle` | G02 | `{}` | 10 G04：当票倒计时、逾期、满当 · 20 G01：留着的牌过期 · 30 G03：条子剩几天、到期吃亏 · 40 G03：风声自然回落、到顶被抓 · 45 RG1（肉鸽 v1）：持有物件 `hook == "settle"` 的行 · 50 G05：黄历奖励 · 60 G05：命运计数 · 70 G02：写日结报告 · 80 RG2（肉鸽 v1）：本关第 7/14/21/28 天（`rules/stock.json` 的 `week_days`）周末盘账——铺子开着、不在牢里、这一周还没开过时摆 2 或 3 样、发告示、`request_panel("stocktake", {offer})`（钱不够面板开着时只记下报价、不抢面板）；告示照样进日结（`CardDayLoop.choose_night_choice` 在整条 settle 钩子链之后才用 `finish_settle` 收这段时间发的告示） |
| `month_close` | G02 | `{}` | 10 G04：开销、当票清点 · 15 G06：抵押利息、铺面赎不回 → 街头 · 20 G02：目标结算、评语 |
| `year_jump` | G02 | `{from, to}` | 10 G04：当票全部满当 · 20 G04：换币、物价 · 30 G03：档案“一年后” · 40 G02：人脉跨年变化 · 50 G01：换牌库 |
| `money_short` | G04 | `{amount, payee, source}` | 5 G06：钱不够阶梯（`request_panel("short", …)`） · 10 G05：危机检查（大命运） |
| `arrested` | G06 | `{reason}` | 10 G05：危机检查 |

### 7.4 指令与查询（`send` / `query`）

阶段：`boot` `month_open` `morning` `day` `night` `settle` `month_close` `year_jump` `game_over` `branch_pick`（1949 之后，首发不用）。模式：`shop` `street`。

| 指令 | 参数 | 返回（除 ok/err） | 阶段 | 主人 |
|---|---|---|---|---|
| `game.new` | 同 `new_game` 的 opts；肉鸽 v1 加可选 `run: {no:int≥1, opening?:String, known?:[frag id]}`（外壳交进来的本局上下文；不给或 `{}` = 今天的游戏，状态一字不变；不是字典、`no` 不对、`opening` 不在 `rules/legacy.json` 的 `openings` 里、`known` 不是字符串数组 → `bad_args`；`known` 里数据库没有的碎片静默丢掉，§15） | — | 任意 | G02（`run` 的检查与写入：RG5） |
| `game.save` / `game.load` | `{path}`（`game.load` 不给 `path` = 续玩点） | `{meta}` | 见 §6.1 | G02 |
| `game.retry_stage` | `{}` | — | `game_over` 或任意 | G02 |
| `month.begin` | `{}` | — | `month_open`（本月轮盘转过后，否则 `wheel_pending`） | G02 |
| `day.begin` | `{}` | `{dealt:[uid]}` | `morning` | G02 |
| `day.end` | `{confirm:bool=false}`（打烊 · 下一天，§7.4.7） | `{step, items}`；要确认时 `ok: false`、`err: "must_resolve_pending"`、带 `items` | 除 `game_over` 外任意 | G02 |
| `night.choose` | `{def, choice?:""}` | —（带 `choices` 的夜牌要给 `choice`；`def: ""` = 今晚不选，“算了”） | `night` | G02 |
| `settle.next` | `{}` | `{next_phase}` | `settle` | G02 |
| `month.next` / `year.next` | `{}` | — | `month_close` / `year_jump` | G02 |
| `card.keep` | `{uid}` | — | `day` | G01 |
| `card.discard` | `{uid}` | — | 任意（留牌溢出时，§7.4.2） | G01 |
| `card.read` | `{uid}` | — | `day` | G03 |
| `card.choose` | `{uid, choice}` | `{needs_slots:bool}`（人物牌的选项、条子的办法 §4.7.6 都走它） | `day` | G03 |
| `slot.place` | `{uid, slot, source}` | `{coins:int}` | `day` | G03 |
| `slot.remove` | `{uid, slot, index}` | — | `day` | G03 |
| `slot.roll` | `{uid}` | `{faces:[bool], heads:int, need:int, success:bool}` | `day` | G03 |
| `demand.submit` | `{uid}` | `{success:bool}`（按已选的办法结算） | `day` | G03 |
| `demand.delay` | `{uid}` | `{days_left:int, tier:int}` | `day` | G03 |
| `contact.release` | `{uid}` | —（人脉满了时让出一个，或主动断交） | 任意（引擎要求时） | G03 |
| `counter.open` | `{uid}` | 柜台视图（同 `query("counter")`） | `day` | G04 |
| `counter.offer` | `{uid, tier:"harsh"/"fair"/"kind"}` | `{reply:"accept"/"counter"/"leave", price:int}` | `day` | G04 |
| `counter.answer` | `{uid, accept:bool}` | `{reply, price}` | `day` | G04 |
| `counter.pick_stock` | `{uid, item}` | — | `day` | G04 |
| `counter.redeem` | `{uid, mode:"by_rule"/"squeeze"/"compensate"/"buy_back"}` | `{reply}`（后两种只在东西已经被你卖掉时可用） | `day` | G04 |
| `counter.refuse` | `{uid}` | — | `day` | G04 |
| `counter.close` | `{uid}` | —（不处理，牌留在手上） | `day` | G04 |
| `mg.request` | `{uid, item:""}` | `{kind, params}`（同时发 `minigame_requested`）；`item` 为空时用牌上的 `minigame`（当票、电报、信），没有就 `no_minigame` | `day` | G04 |
| `mg.report` | `{uid, item, result}` | `{observations:[key]}` | `day` | G04 |
| `estate.mortgage` / `estate.redeem` | `{estate}` | `{money:int}` | `day` `morning` | G06 |
| `short.resolve` | `{source, by:"goods"/"estate"/"default", item?, estate?}` | — | 任意（引擎要求时） | G06 |
| `street.redeem_shop` | `{}` | — | `day`（街头） | G06 |
| `wheel.offer` | `{wheel, uid, source}` | — | 轮盘打开时 | G05 |
| `wheel.withdraw` | `{wheel, uid, index}` | — | 同上 | G05 |
| `wheel.stake` | `{wheel, uid, kept_uid}` | — | 同上（代价是押牌的轮盘） | G05 |
| `wheel.spin` | `{wheel, uid}` | `{segment:String, stop_deg:float}` | 同上（§7.4.4） | G05 |
| `fortune.lot` | `{uid}` | `{lot:String, grade:int}` | `day` | G05 |
| `fortune.cezi` | `{uid, char}` | `{char:String, reading:"has"/"none"}` | `day` | G05 |
| `stock.pick` **（肉鸽 v1）** | `{offer:String, pick:String, replace?:String}`（`pick: ""` = 都不要；别的键 → `bad_args`） | `{offer, picked, kind:"relic"/"source"/"", released:""/"rl.x"}` | 报价开着的那一阶段起都行（周末报价在 `settle`，货郎报价在 `day`），第二天 `day_start` 作废；`game_over` → `bad_phase` | RG2（物件那一支调 RG1 的 `relic_api.gd` `take`，错误码原样返回） |
| `ui.guide` | `{step, status:"shown"/"done"}` | — | 任意 | G01（只改 `ui`；不发事件、不进日志，§7.10.6） |

`source`（放进格子/香案的东西）：`{"kind": "money", "amount": 10}` · `{"kind": "self"}` · `{"kind": "contact", "uid": "c0012"}` · `{"kind": "kept", "uid": "c0020"}` · `{"kind": "item", "item": "I004"}` · `{"kind": "news", "uid": "c0031"}`。

| 查询 | 参数 | 返回 | 主人 |
|---|---|---|---|
| `card` | `{uid}` | 详细 CardView（含 `slots`、`choices`） | G02（合并各模块的 `card_view_part`） |
| `actions` | `{uid}` | `[Action]` | G02 |
| `slots` | `{uid}` | `{slots:[SlotView], coins, auto_heads, need, auto_pass, ready}` | G03 |
| `counter` | `{uid}` | CounterView | G04 |
| `stock` / `tickets` | `{}` | `[ItemView]` / `[TicketView]` | G04 |
| `estates` | `{}` | `[EstateView]` | G06 |
| `short` | `{}` | §7.4.5 的参数（读档后重开面板用） | G06 |
| `wheel` | `{wheel, uid}` | WheelView（§9.1） | G05 |
| `fortune` | `{uid}` | `{cost:int, can_lot:bool, can_cezi:bool, cezi:[char id], last:{lot, grade}}` | G05 |
| `almanac` | `{}` | `{id, yi:[…], ji:[…], done:[…]}` | G05 |
| `dossier` | `{person?}` | DossierView | G03 |
| `settle_report` / `month_report` / `year_report` | `{}` | `{lines:[{key, args}]}` | G02 |
| `firsts` | `{}` | `{firsts:{mech: abs_day}}` | G01 |
| `guide_data` | `{}` | `{steps:[…], pages:[…], settings:{…}}`（步骤与规矩页只给机制字段，去掉 `brief` `_provenance` `_test` `weight` `era`；`settings` = `rules("guide")`） | G01 |
| `guide_progress` | `{}` | `{progress:{step:{shows, status, abs_day}}}` | G01 |
| `guide_conds` | `{ids:[step]}` | `{<step>: bool}`（逐个算 `trigger.cond`） | G01 |
| `day.end_preview` | `{}` | `{step, needs_confirm, items:[EndRow]}`（打烊确认的清单，§7.4.7） | G02 |
| `relics` **（肉鸽 v1）** | `{}` | `{cap, count, dormant, held:[{id, art, depth, since}]}`（按拿到的先后）；模块没启用 = `{cap: 6, count: 0, dormant: false, held: []}` | RG1 |
| `stocktake` **（肉鸽 v1）** | `{offer?}` | `{offer, from:"week"/"peddler", stage, week（0 起；货郎 -1）, deals（这一周做成几笔，看得见）, status:"open"/"picked"/"passed"/"lapsed", picked, items:[{id, kind, art, depth}], cap, full, held:[{id, art, depth}]}`；`offer` 不给或 `""` = 最近一份 `open` 的，没有 → `not_allowed`；给了但没有这份 → `bad_args`；别的键不管（面板 `open()` 的参数原样交进来也行） | RG2 |
| `legacy.harvest` **（肉鸽 v1）** | `{close?:String}` | `{no（没有 run 时 0）, phase, reason, stage, era, stage_day, frags:[这一本拿到的碎片，排序], chronicle?:{key, args}}`（只在给了 `close` 时有：`ending` 按本心挑 `rg5.chronicle.ending.<kind/plain/hard>`、`prison` / `abandoned` → `rg5.chronicle.<reason>.<era>` 带 `{d}`、别的 → `rg5.chronicle.other`）；只读，前后 `state_hash()` 相同 | RG5 |
| `legacy.old_ink` **（肉鸽 v1）** | `{}` | `{pages:[{person, fragments:[{id, order}]}]}`：`run.known` 里这一本既没拿到也没撕成缺口的碎片，按人分页（页按人 id、碎片按 `order` 再按 id）；没有 `run` → `pages: []` | RG5 |

#### 7.4.1 通用

- 每条指令的事件以 `command_done`、`view_changed` 收尾（§7.2）；`ui.*` 例外。
- 面板 kind 和来意的对应见 §7.4.3；引擎要求开面板一律经 `CardDayLoop.request_panel()`（发 `request_panel` 信号并写 `loop.open_panel`）。

#### 7.4.2 留牌满了与 `card.discard`

- 留着的牌到上限（`deal.json.caps.kept` + 修正项 `cap`）时又要进一张（`card.keep` 返回 `kept_full`；`add_card to:"kept"` 进 `pending`、`status:"overflow"`）：引擎发 first-time `kept_full`，`request_panel("kept_full", {new_uid})`。
- 玩家 `card.discard {uid}` 扔掉一张——可以是已经留着的，也可以是新来的那张；有了空位，新牌随即进 `kept`。面板关掉不选 = C03 发 `card.discard {uid: new_uid}`。扔掉的牌不执行 `on_expire`。
- 溢出没处理时，别的指令返回 `overflow_pending`（`card.discard`、`day.end`、`query` 除外；打烊时还没选 = 扔掉新来的，§7.4.7）。

#### 7.4.3 来意与面板

| 牌 / 来意 | 面板 kind（主人） | 呈现 | 走的指令 |
|---|---|---|---|
| person：`pawn` `sell` `buy` `redeem` | `counter`（C04） | `stage` | `counter.*`；牌上的 `choices` 作柜台上的额外按钮 → `card.choose` |
| person：`help` `ask` `story`（含金色牌） | `slots`（C03） | `stage` | `card.choose`、`slot.*` |
| event、fate、life、street、big_fate（大赌） | `slots`（C03） | `stage` | `card.choose`、`slot.*` |
| `bf.wheel`、`ev.any.wheel_go`、带 `opens_wheel` 的事件 | `wheel`（C06） | `overlay` | `wheel.*` |
| 带 `opens_fortune` 的事件 | `fortune`（C07） | `stage` | `fortune.*` |
| demand | `demand`（C05） | `stage` | `card.choose`（办法）、`slot.*`、`demand.submit` / `demand.delay` |
| prison | `prison`（C11） | `stage` | `slot.*` |
| news、pawn_ticket | `read`（C03 的 SlotPanel 只读样式） | `stage` | `card.read`；带 `minigame` 的 → `mg.request {uid}` |

呈现为 `stage` 的，打出这张牌就在画面里演（§7.11.4）；呈现为 `overlay` 的，C01 开叠层之前先让场景层按这张牌的演出块换背景、上人（不说话）。

#### 7.4.4 轮盘指令

- 所有轮盘指令和查询都带 `uid`：那张牌（`bf.wheel`、`ev.any.wheel_go`、带 `opens_wheel` 的事件）；本月运势 `wh.month` 用 `""`。状态按 `fate.wheels["<轮盘>:<uid>"]` 分开记，两张同种轮盘牌各转各的。
- `wheel.stake {wheel, uid, kept_uid}`：代价是押牌的轮盘，转之前必须押一张留着的牌（没押就 `wheel.spin` → `stake_required`）。
- `wheel.spin`：先扣代价（钱不够 → `insufficient_money`，不转），付掉香火钱、用掉香案上的留牌，转，执行段的 `effects`，押的牌落在 `bad` 段没了、否则还回来【待调】，最后把那张牌 `resolve`。

#### 7.4.5 钱不够面板的参数

`request_panel("short", {amount, payee, source, options, goods, estates})`：`amount` 还差多少钱、`payee` 付给谁（原因键）、`source` 哪张牌或哪件事、`options` ⊂ `["goods", "estate", "default"]`（能走的路：拿货抵 / 押家当 / 认了）、`goods` 能拿来抵的货 `[ItemView]`、`estates` 还没押的家当 `[EstateView]`。`query("short")` 返回同样的东西。玩家选完 `short.resolve`。

#### 7.4.6 钉签、查封、街头时发什么牌

- **钉住的牌永远发**：先占它所属牌库的名额；名额已满或那个牌库今天是 0（查封、街头、脚本日都算）就**额外**发一张。那天它的 `conditions` 不满足才换同征兆的替身（§9.3）；同牌库里找不到合法的同征兆替身，就**照发原来钉住的那张**（框架版收尾默认，主创可改）。所以签永远准。
- **手牌软上限**（`deal.json.caps.hand_soft` + 修正项 `cap {zone: "hand"}`）**只限随机抽的部分**：日程、主线、队列、钉签和效果点名发的牌（`add_card`、`extra_deal`）照发，不受上限限制；随机部分最多补到“上限 − 手上已有 − 今天这些固定发的”，不够就少发或不发（框架版收尾默认，主创可改）。
- **禁签**（测字读出“无”时加的）：窗口里随机抽、找替身都跳过带那些标签的牌；日程、主线、效果点名发的牌不受影响。

| 牌 | 铺子开着 | 查封（`shop_closed`） | 流落街头 | 脚本日（`scripted_days`） | 在牢里（牢房牌在手上过夜的第二天，§7.4.7） |
|---|---|---|---|---|---|
| 人物牌（随机） | 照发 | **不发** | 不发（换街头三张） | 不发 | **不发** |
| 日程、主线、金色、教学的牌 | 照发 | 照发 | 照发【主创已确认 10-13】 | 照发 | 照发 |
| 钉住的牌 | 照发 | 照发（额外） | 照发（额外） | 照发（额外） | 照发（额外） |
| 事件、消息（随机） | 照发 | 照发 | 不发 | 不发 | 照发（街头时不发） |
| 命运牌 | 照发 | 照发 | 照发 | 不发 | 照发 |
| `bf.wheel`（危机） | 照发 | 照发 | 照发 | 照发 | 照发 |
| 生活牌（每周） | 照发 | 照发 | 照发 | 不排在这几天 | 照发 |
| 条子（每周一） | 照发 | 照发 | 照发【主创已确认 10-13】 | 照发 | 照发 |
| 来赎当的人 | 照来 | 不来（当票照样倒计时） | 不来【主创已确认 10-13】 | 照来 | 不来（当票照样倒计时） |
| 街头牌（每天 3 张） | — | — | 照发 | — | **不发** |
| 夜牌 | 照发 | 照发 | 按 `mode` 条件 | 照发 | **不发**（夜里只有“算了”） |

#### 7.4.7 打烊 · 下一天（红线 9；主创 2026-10-13 硬性规则）

主创原话：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”（DESIGN §九.5）。本节取代 1.1 里“必须处理的牌没处理完不能打烊”的做法（`day.end` 返回 `must_resolve_pending` 挡住、只剩金色牌返回 `gold_pending` 两步确认）：**`day.end` 不再被任何牌挡住，只做“未处理清单 + 确认”。**

**1. 指令与查询**

| | 参数 | 返回（除 ok/err） | 阶段 |
|---|---|---|---|
| 查询 `day.end_preview` | `{}` | `{step, needs_confirm, items:[EndRow]}` | 任意（`game_over` 时 `step: ""`、`items: []`） |
| 指令 `day.end` | `{confirm: bool = false}`（1.1 的 `confirm_gold_leave` 在 W1 里当 `confirm` 的别名照收，W2 已删：现在带它返回 `bad_args`，#24） | 做了：`{step, items}`，外加那一步本来的返回（例 `open_day` 的 `dealt`）；要确认：`{ok: false, err: "must_resolve_pending", step, items, needs_confirm: true}` | 除 `game_over`（`bad_phase`）外任意；**不受 §7.4.2 的溢出拦截** |

- **EndRow** `{uid, def, kind, consequence_key, args}`：`uid`/`def` 是那张牌（不是牌的行为空串）；`kind` 见第 3 条（`CardIds.END_KINDS`）；`consequence_key` 是正文键——`<def>#outcomes.ignored`、`<def>#outcomes.fail` 或 `g0x.end.*` 界面键，界面一律 `CardText.t(consequence_key, args)`；`args` 只放看得见的整数（天数 `days`、牢里第几晚 `nights`、最多几晚 `max`）。整个结果过 §7.5 的隐藏键检查。
- `needs_confirm` = `items` 里至少有一行的 `kind` 不在 `CardIds.END_NO_CONFIRM_KINDS`（`wait` `pass` `skip_night`）里。
- **预览 = 结算**：同一状态下 `day.end_preview` 的 `items` 和紧接着 `day.end {confirm: true}` 返回、真正结算的 `items` 完全一样（同顺序）。
- `confirm: false` 且 `needs_confirm`：只记 first（第 5 条）和指令日志，别的都不改，返回清单；`confirm: false` 且不用确认、或 `confirm: true`：直接做那一步。

**2. 每个阶段做的那一步**（`step`，`CardIds.END_STEPS`）

| 阶段 | `step` | 做什么 | 清单 |
|---|---|---|---|
| `day` | `end_day` | 触发 `day_end` 钩子，各模块按第 3 条的表结算没处理的东西 → 夜牌 → `night`（牢房到期则进 `game_over`） | 第 3 条的表 |
| `night` | `skip_night` | 今晚不选夜牌（= `night.choose {def: ""}`）→ `settle` | 一行 `skip_night`（不用确认） |
| `settle` | `next_day` | = `settle.next` | 空 |
| `morning` | `open_day` | = `day.begin`（发牌、进白天；没看过的牌不替玩家放弃） | 空 |
| `month_open` | `begin_month` | 本月运势还没转：替玩家转一次（`CardWheel.spin(ctx, "wh.month", "")`，香案上已经放的照算）；然后 = `month.begin` | 没转时一行 `auto_spin`（要确认） |
| `month_close` | `month_next` | = `month.next` | 空 |
| `year_jump` | `year_next` | = `year.next` | 空 |
| `game_over` | — | `bad_phase`；往前走用 `game.retry_stage`（本关开头）或 `game.load {}`（不给 `path` = 续玩点），两条都永远可用 | — |
| `boot` | — | `bad_phase`：还没开局（界面在标题上，牌桌还不存在），不算“能到达的局内状态” | — |
| `branch_pick` | — | 预留：首发三关到不了（G02 验收“`branch_pick` 不可达”）；解放后的分支上线时，合同先给这个阶段定一步，红线 9 同样适用 | — |

- **不是白天时还有没选的钱不够**（`short` 面板开着；#96）：上表写“空”的阶段（`settle` `morning` `month_close` `year_jump`）和 `night`、`month_open`，清单里都先列一行 `short`（G06 经 `end_rows` 交，`g06.end.short`，要确认），再是本阶段自己的行。确认后先 `short.resolve {by: "default"}` 认了，再做这一步；认了进了 `game_over` 就停在那里。`month_close` 的月账短款会一笔接一笔来：每笔都按 default 认了、写进月报，再接着月结，直到离开 `month_close`（`day_loop.gd` 的 `_advance_month`）；预览只列当时开着的那一笔。

**3. 白天打烊时没处理的东西怎么结算**（确认之后，`day_end` 钩子里各主人按 priority 做；清单的行由同一个主人经修正项 `end_rows` 交，§7.3）

| 没处理的东西 | `kind` | 结算 | `consequence_key` | 主人 · `day_end` priority |
|---|---|---|---|---|
| 留牌溢出没选（`pending` 里 `status: overflow`） | `discard` | 扔掉新来的那张（= 关掉 `kept_full` 面板；不执行 `on_expire`） | `g01.end.discard` | G01 · 5 |
| 人脉满了没选（`contacts_full`） | `release` | 新来的那个不留（= 关掉面板） | `g03.end.release` | G03 · 6 |
| 格子里放了还没掷的东西 | —（不成行） | 还回来：钱没花、留着的牌还在、人今天算用过 | — | G03 · 6 |
| 钱不够没选（`short`） | `short` | `short.resolve {by: "default"}`（认了） | `g06.end.short` | G06 · 7 |
| 柜台开着的会话 | —（人物那一行管） | 关掉会话，不算成交 | — | G04 · 8 |
| 金色角色牌 | `gold_leave` | `CardGoldRule.leave`：`card_left(uid, &"gold_left")`、执行 `on_expire`（主线“没理他” + 档案缺口，V13；§10） | `<def>#outcomes.ignored` | G02 · 10 |
| 人物牌（含来赎的人：当票照旧，他之后还可能再来） | `leave` | 客人走掉 `card_left(uid, &"left")`；`on_expire` 非空就执行——**个别人记仇写在这里**（`flag` `counter` `rep` `person_state`……） | `on_expire` 非空 → `<def>#outcomes.ignored`，否则 `g02.end.leave` | G02 · 10 |
| `must_resolve` 为真的事件、命运、街头、大赌（`bf.*` 除 `bf.wheel`） | `ignore` | 按“没理会”结算：`effects` 里有 `on_expire` 键就执行它（可以是 `[]`）；没有、但有顶层 `check` → 执行 `check.on_fail`（当没过）；都没有 → 没有后果（V37 要数据写明）；`card_left(uid, &"expired")` | `<def>#outcomes.ignored` / `<def>#outcomes.fail` / `g02.end.ignore` | G02 · 10 |
| `must_resolve` 为假、不能留、没有期限的牌（算命摊、庙会、赌摊、`ev.any.wheel_go`……；没写 `keepable: true` 的消息牌也在这一类：没看就过去了，`on_read` 不执行） | `pass` | 今天的机会过去了：`card_left(uid, &"expired")`；`on_expire` 非空就执行（一般没有） | `g02.end.pass` | G02 · 10 |
| `bf.wheel`（大轮盘） | `void` | 作废、不转：这张计入本关次数、这种危机算用过（不因为没转再补发）；`card_left(uid, &"expired")`；开着没转的轮盘把香案上的东西、押的牌都还回来 | `g05.end.void` | G05 · 15 |
| 生活牌，`due_days` 没到 | `wait` | 留到明天，`days_left` 减一 | `g01.end.wait` `{days}` | G01 · 20 |
| 生活牌，今天到期 | `ignore` | `CardPiles.expire()`：执行 `on_expire`（挨过去） | `<def>#outcomes.ignored` | G01 · 20 |
| 手上能留的牌（消息、当票、信物：`keepable` 为真、不必了断） | `wait` | 留在手上；有 `expires_days` 的从发到手上那天起照样倒计时，到期在 `settle` 20 失效（执行 `on_expire`；没看的消息 `on_read` 不执行，碎片没拿到） | `g01.end.wait` `{days}`（`-1` 不失效） | G01 · 20 |
| 牢房 `pr.cell`，没到最后一晚 | `stay` | 牌留在手上，`ladder.prison.nights` 加一；当晚就在牢里过夜（夜牌为空，夜里只有“算了”）；第二天铺子关门（G06 执行 `{"op": "shop_closed", "days": 1}`：不随机发人物牌、来赎的不来），也不发街头牌（`ladder.prison.uid` 不空时 G06 的修正项 `deal_count` 把 `night`、`street` 减到 0） | `g06.end.stay` `{nights, max}` | G06 · 25 |
| 牢房，第 `ladder.json.prison.max_days`（起步 3【待调】）晚 | `fail` | 按打点失败结算：执行 `pr.cell` 的 `check.on_fail`（`game_over`，原因 `prison`）；可以从本关开头或续玩点重来 | `g06.end.fail` `{nights, max}` | G06 · 25 |
| 条子板上的条子 | `wait` | 不在手上，照旧倒计时（`settle` 30；今晚到期的照样按档吃亏） | `g03.end.demand` `{days}` | G03 |

- 清单的顺序：先手牌（`order_hand()` 的顺序），再条子板（按剩几天），最后是没选的面板（溢出、人脉满、钱不够）。
- 日结报告：按“没理会”结算的每一行（`kind` 不是 `wait` `pass` `skip_night` 的）各出一行，键和参数同清单（金色牌另有 `g02.settle.gold_left` 照旧）。
- “没理会”的后果只来自数据（`on_expire` / `check.on_fail`）和上表；**引擎不许自己另加惩罚**（不另罚钱、不另降口碑）。
- 上表的 `g0x.end.*` 界面键由各主人登记在自己的 `ui_keys/G0x.json`（只有 brief）。

**4. 不卡死（never-deadlock）不变式**——红线 9；G06 的模糊测试 `G06_no_deadlock` 守着（§12.2）：

1. 任何能到达的状态（任何阶段、任何模式——街头、牢房里——任何面板开着或引擎要求的面板没处理、留牌溢出、钱不够），`query("day.end_preview")` 都能答。
2. 不是 `game_over` 时，`send("day.end", {"confirm": true})` 永远 `ok: true`，而且状态往前走（阶段变了，或 `abs_day` 变大）。
3. 从任何不是 `game_over` 的状态，连续 `day.end {confirm: true}` 最多 `CardIds.END_MAX_STEPS_TO_NEXT_DAY`（8）次，`abs_day` 一定变大，或者进了 `game_over`。
4. `game_over` 时 `game.retry_stage` 永远 `ok`、回到本关 `month_open`；有续玩点时 `game.load {}` 也是。
5. 没有任何真实时间：引擎没有墙钟；界面不许因为时间到了自动发 `day.end`、`settle.next`、`night.choose` 这类推进指令（自动试玩、测试除外）；`loop.minute` 只是显示；指引的 `seconds` 只管指引自己渐隐。
6. 所有面板、小游戏都能关（§7.8 的“算了”）；C01 对引擎要的面板（`open_panel`）每个 `(kind, uid, 第几天)` 只自动开一次，关掉后不再自己弹回来——所以永远回得到牌桌、按得到“打烊 · 下一天”。

**5. first-time 与新手指引**

- `must_resolve`（G02）：第一次 `day.end`（`confirm` 真假都算）时清单里有 `kind` ∈ `CardIds.END_MUST_KINDS`（`leave` `ignore` `void` `stay` `fail`）的行——**确认之前**记，`args {uid}` 取第一行。步骤 `gd.must`（`obj.brother_ledger`，锚点 `a.endday.blocked` = 确认面板里的清单）在确认面板上讲：打烊随时能按；没处理的会怎样（客人走、个别人记仇、事件按没理会、条子接着算、牢房多待一天）；确认了才打烊。
- `gold_leave`（G02）：第一次 `day.end` 时清单里有 `gold_leave` 行——确认之前记，`args {uid}`。步骤 `gd.gold_leave`（锚点 `a.endday.gold_leave` = 清单里金色牌那一行）讲“不理他他就走了”。
- `gd.d1.close`（第 1 天手上必须了断的都处理完了）讲“打烊 · 下一天”这个按钮：随时能按、节奏你定。
- **id 都不改，含义改了**（附录 F）：机制 `must_resolve` `gold_leave`、锚点 `a.endday.blocked` `a.endday.gold_leave` `a.btn.close_day`、步骤 `gd.must` `gd.gold_leave` `gd.d1.close`、面板 kind `end_day`、错误码 `must_resolve_pending`；错误码 `gold_pending` 不再返回（常量保留、不复用）。

**6. 测试**（详见各任务卡）：G02——每个阶段 `day.end {confirm: true}` 都前进、预览 = 结算、没确认时只改 `firsts`、两个 first 各一次、存读后同样；G01 / G03 / G04 / G05 / G06——自己那几行的结算与 `end_rows` 交的行一致；**G06——模糊测试 `G06_no_deadlock`：≥ 1000 局**（每局一个种子；其中每 25 局有一局走满一关多两天，跨过月底、跳年、开月），随机合法和不合法的指令 + 随机 `day.end`（`confirm` 真假都有）+ 早上随机存读，逐条断言上面第 4 条的 1–4，并抽样回放比哈希；C01 / C08——按钮、确认面板、各面板的“算了”；K14——整局走查里随时乱按“打烊 · 下一天”。W0 的 `W0_next_day` 对 Mock 情景做了同样的检查（300 局）。

### 7.5 视图 `view()`（G02 的 CardViewModel；**只有看得见的东西**）

```json
{
  "v": 1, "phase": "day", "mode": "shop", "busy": false,
  "date": {"stage": 0, "era": "1938", "y": 1938, "m": 3, "d": 9, "weekday": 2, "stage_day": 9, "stage_days": 30, "abs_day": 9, "minute": 540},
  "notice": {"weather": "rain", "market_day": false, "news": ["g02.notice.rain"], "almanac": {"id": "alm.shoudang", "yi": ["pawn_in", "meet"], "ji": ["travel"], "done": []}, "fortune": "ws.1938.month.caixing"},
  "stage": {"set": "counter", "time": "day", "sealed": false},
  "money": {"amount": 340, "currency": "fabi"},
  "rep_tier": 1, "heat_tier": 0,
  "self": {"uid": "c0001", "def": "self.ruhua", "attrs": {"eye": 2, "tongue": 1, "pull": 1, "nerve": 1}, "used_today": false},
  "hand": [], "kept": [], "contacts": [], "pending": [], "demands": [],
  "caps": {"kept": 5, "contacts": 3, "shelf": 12},
  "shelf_count": 4, "tickets": [], "estates": [],
  "goals": [{"id": "gl.1938.keep_shop", "main": true, "status": "open"}],
  "night_offers": [{"def": "nt.tidy", "art": "illus.nt.tidy", "choices": []}],
  "open_panel": {"kind": "", "args": {}},
  "lots": [{"lot": "lot.g1.official", "abs_day": 7}],
  "dossier_new": 2
}
```
- CardView：`{uid, def, type, zone, gold, must_resolve, keepable, expires_in, status, art, person, intent, item, asking, observations, days_left, attrs, used_today, away_days, can_appraise, panel, actions, slots?, choices?}`；`panel` ∈ `counter` `slots` `demand` `wheel` `fortune` `prison` `read` `none`（§7.4.3）；`asking` 是客人开口报的价（看得见），`-1` 表示没有。**`must_resolve`**：今天要了断（牌上的小红点；打烊时按没理会结算，§7.4.7）；**`expires_in`**：留着的牌、手上能留的牌（消息、信物）还有几天失效（`-1` 不失效）；**`days_left`**：条子、生活牌、当票还有几天到期，牢房牌还能在牢里待几晚（`-1` 没有期限）——两个都是看得见的天数，C02 的角标用 `expires_in`，条子板、日结用 `days_left`；1.3 加 `stage` `source` `wheel` `fortune` `demand`，条子另有 `amount`（本节末“1.3 增补”的表）。
- Action：`{id:"open"/"keep"/"discard"/"refuse"/"read"/"choose:<id>", enabled:bool, reason_key:String}`。
- SlotView：`{id, accepts, attr, wants, required, max, placed:[{kind, uid?, amount?, item?, coins:int, heads:int, auto_pass:bool}], coins:int}`。
- ItemView：`{item, template, cat, art, condition_word:int(0–4 成色档), observations:[key], on_shelf_since:int}`；TicketView：`{no:int, person, item, principal:int, days_left:int, status, foreign:bool}`；EstateView：`{id, status, money:int, interest_money:int}`（利息给钱数，不给百分比）。
- DossierView：`{pages: [{person, complete: bool, new: int, fragments: [{id, order, era, kind, state: "have"/"gap", new: bool}]}]}`——只列见过的人；还没拿到的碎片**不出现**，缺口出现（画成撕痕）。
- CounterView：`{uid, person, intent, item:ItemView或null, asking:int, tiers:{harsh:int, fair:int, kind:int}, direction:"pay"/"receive", round:int, last_reply:String, last_price:int, line_key:String, can_appraise:bool, stock:[item], ticket:TicketView或null, tier_err:{harsh, fair, kind}, accept_err:String}`。`tier_err` / `accept_err`（10-25）：这一档价 / 客人还的价现在成不了交的原因码（`""` = 能；`money_short` 柜上的钱不够付，`shelf_full` 货架满了，`stock_missing`）；`counter.offer` / `counter.answer {accept: true}` 遇到这种价直接回这个错误码，不算一轮、不扣耐心、**不记成客人答应**（成不了的交易绝不念成成交），界面把这一条回话变灰、下面写原因（`c04.reason.money_short` 等）。
- **隐藏键黑名单**（`CardViewModel.FORBIDDEN_KEYS`，视图和所有查询结果里递归不许出现）：`floor` `market` `value` `true_value` `fake` `real` `stolen` `origin` `rare` `rarity` `quality` `conscience` `rep` `heat` `rep_points` `heat_points` `weight` `weights` `arc` `units` `prob` `probability` `chance` `pct` `percent` `patience` `pins` `pinned` `foretold` `seed` `draw` `est` `ask_w` `claimed` `contraband` `valence` `suggest` `budget` `tell` `tags` `hint_tags` `risk` `apprentice_loyalty` `apprentice_skim_pending`。（牌的 `tags` 里有 `contraband`、`bad_omen`、`omen_*`，视图里不给牌的标签；格子的性质在 SlotView 里改叫 `wants`。两个 `apprentice_*` 键是 K18 的隐藏忠心和待翻的克扣。）G02 的测试对每个夹具状态的 `view()`、所有查询结果、引擎发出的所有事件参数（含 `first_time`）做递归检查；任何任务往视图里加字段都要过这一关。
- **布局种子是黑名单 `seed` 的唯一例外**（#46）：事件 `minigame_requested(uid, item_id, kind, params)` 的 `params.seed`（§8.2，G04 用 `c.mg.param` 抽的小游戏布局种子）和找不同的 `params.marks[i].seed`（给 `FlawRender` 画痕迹）只决定画面怎么摆，可以出现。只有这两个精确路径；本局的主种子（`game.new` 的 `seed`、状态里的 `seed`）照旧隐藏——视图、查询结果、别的事件、`params` 里别的位置出现 `seed` 仍然算漏。`command_done` 的指令参数先去掉黑名单键再发（`CardEngine._visible_args`）。G02 的事件检查（`scripts/tests/cards/G02/real_firsts.gd`）只放过这两个路径，并断言它们是整数、不等于本局主种子。
- **视图怎么拼**：`CardViewModel.build()` 先放 G02 自己的（阶段、日期、目标、开着的面板），再 `ctx.mods.merge(ctx, &"view_section", {})` 把各模块交来的顶层块合进去（键冲突是程序错误）；每张牌的 `card_view()` 用 `ctx.mods.merge(ctx, &"card_view_part", {uid, detailed})` 合并各模块的字段；最后跑 `leaks()`。模块要给视图加字段：在自己的 install 里登记提供者，不用改 G02 的代码。
- **肉鸽 v1 的三个顶层块**（2026-10-25，经 `view_section` 交来；只在有这套东西时出现——例子集、没有肉鸽数据、规则文件 `enabled: false` 时一个都没有，视图和状态哈希一字不变）：
```json
"relics": {"cap": 6, "count": 2, "dormant": false,
           "held": [{"id": "rl.stub_box", "art": "prop.relic.stub_box", "depth": "plain", "since": 8}]},
"stock":  {"open": "w0.1", "week_deals": 1, "sources": [{"id": "ky.dockhands", "art": "illus.ky.dockhands"}]},
"run":    {"no": 3, "opening": "og.shanghai"}
```
  - `relics`（RG1，模块启用 = `rules/relics.json` 的 `enabled` 为真且数据库里至少一件 `relic`）：`held` 按拿到的先后，`since` 是拿到那天的 `abs_day`，`depth` ∈ `plain` `storied` `treasure`（来历深浅，界面只画框和两三个字）；`dormant`：流落街头或在牢里（`rules/relics.json` 的 `dormant_in_street` / `dormant_in_prison`），这时物件的修正项和钩子一概不起作用。
  - `stock`（RG2，模块启用 = `rules/stock.json` 在且 `enabled` 为真，并且数据库里有客源或物件模块启用）：`open` = 最近一份还开着的报价 id（没有为 `""`）；`week_deals` = 今天所在这一周已做成几笔；`sources` = 这一关生效的客源（管到这一关月底）。
  - `run`（RG5）：有 `state.run`（外壳经 `game.new {run}` 交进来）才有。
  - 盘账时 `open_panel` = `{"kind": "stocktake", "args": {"offer": "<报价 id>"}}`（G02 已有的字段，RG2 经 `CardDayLoop.request_panel` 填；`stock.pick` 成功后清掉）。
  - 黑名单不加键，三块都过 `leaks()`。格数（`count` / `cap`）和这一周的成交笔数是玩家看得见的计数，可以显示；效果大小一概不出。`seed` `origin` `rarity` 本来就是黑名单键，所以种子只在外壳和标题里出现、深浅叫 `depth`、开头叫 `opening`（§15）。

**1.3 增补（画面与对话；全部归现有任务，签名一个不改）**：

1. **`view.stage`（新顶层块，G02 出，经 G02 自己的 `CardViewModel.build`；不需要别的模块交 `view_section`）**：
```json
"stage": {"set": "counter", "time": "day", "sealed": false}
```
   - `set`：`"counter"`（铺子开着）· `"street"`（`loop.mode == "street"`）· `"prison"`（手上有 `type == "prison"` 的牌，或 `ladder.prison.uid` 不空）。优先级 prison > street > counter。G02 读 `ladder` 命名空间只读（§6.1 允许）。
   - `time`：`"day"` · `"dusk"` · `"night"`。阶段 `night` `settle` → `night`；阶段 `day` → 设 D = 今天发到手牌的牌数（`core.deals[str(abs_day)]` 的个数），R = 其中现在已不在手牌区的张数（处理掉、走掉、留着、作废都算）；D > 0 且 `R × 100 ≥ D × loop.json.dusk_pct` → `dusk`，否则 `day`；其余阶段 → `day`。`dusk_pct` 是 G02 的 `data/cards/rules/loop.json` 新键，起步 **60【待调】**（G02 加进自己的文件，开 `[shared] G02→G01` 在 `RULE_KEYS` 里登记）。
   - `sealed`：今天铺子被查封（`econ.shop_closed_until ≥ abs_day`，G02 只读 G04 的命名空间）。
   - 这三项只是“看得见的样子”，不进任何规则；视图隐藏键检查照旧（三个键都不在黑名单里）。
2. **CardView 增补字段**（Mock 照做）：

| 字段 | 类型 | 谁出 | 含义 |
|---|---|---|---|
| `stage` | Dictionary | G02（`card_view` 基础字段） | 这张牌定义里的演出块（§4.7.24）的深拷贝，**去掉所有 `brief` 键**；没写就是 `{}` |
| `source` | String | G02（基础字段） | 消息牌的 `source`（谁说的，人物 id）；别的类型 `""` |
| `wheel` | String | G05（`card_view_part`） | 这张牌处理时开哪个轮盘：`bf.wheel` → `"wh.big"`；`ev.any.wheel_go` → `vars.wheel`；带 `opens_wheel` 的事件 → 它的值；否则 `""`（1.2 的缺口“轮盘牌的轮盘 id”就此关闭） |
| `fortune` | String | G05（`card_view_part`） | 带 `opens_fortune` 的牌：`"lot"` `"cezi"` `"both"`；否则 `""` |
| `demand` | Dictionary | G03（`card_view_part`） | 条子：`{"kind": "money"\|"goods"\|"people"\|"info", "tier": 0–3}`；别的类型不给这个键（1.2 的缺口“条子的档位/类别”就此关闭） |
| `amount` | int | G03（`card_view_part`，`CardDemands.amount`） | 条子：按现在的办法要交的钱（看得见的钱数，不是隐藏值）。还没选办法、或要钱条子选了“交” → 发条子时定下的钱数；“讲价” → 降一档那张条子的钱数；“顶替” → `resolve.substitute.money`；别的办法 0；交完以后是实交的钱数。别的类型不给这个键。C05 把它显示在条子上、写在“交上去”后面，自动放钱只放这么多（现钱不够就放全部现钱）；Mock 和旧夹具没有这个键时 C05 照旧（#73 补登；框架版收尾默认，主创可改） |

3. **`view.night_offers` 的元素改成字典**（G02）：`[{"def": "nt.tidy", "art": "illus.nt.tidy", "choices": []}, {"def": "nt.family_dinner", "art": "illus.nt.family_dinner", "choices": ["waive_life", "family_word"]}]`（`art` 取定义里的 `art`，`choices` 是选项 id 的数组）。界面在 W1 里照收裸字符串（当成 `{def, art: "", choices: []}`），W2 删兼容。1.2 的缺口“夜牌只给 id、没有美术和选项”就此关闭。
4. 引擎**不知道**哪张牌“正在演”：演出是界面的事（打出一张牌不发指令；该发的照旧——`counter.open`、`card.choose`、`card.read`……）。所以引擎、状态、哈希、黄金种子、存档都不受 1.3 影响。

### 7.6 CardEventBus（G01；autoload 名 `CardBus`；“引擎→界面”，唯一例外 `ui_event`）

```gdscript
class_name CardEventBus
extends Node
signal phase_changed(from: StringName, to: StringName)
signal view_changed(topics: PackedStringArray)               # 界面重新读 engine.view()；topics 提示哪块变了
signal cards_dealt(uids: PackedStringArray)
signal card_updated(uid: String)
signal card_left(uid: String, reason: StringName)            # resolved / refused / left / expired / gold_left / seized / informed
signal coins_tossed(uid: String, faces: Array, need: int, success: bool)
signal wheel_spun(wheel_id: String, segment_id: String, stop_deg: float)
signal money_changed(old_amount: int, new_amount: int, reason_key: String)
signal tier_changed(meter: StringName, old_tier: int, new_tier: int)          # 只有 &"rep" 和 &"heat"
signal dossier_changed(person: String, frag_id: String, kind: StringName)    # added / gap
signal notice(key: String, args: Dictionary)
signal minigame_requested(uid: String, item_id: String, kind: StringName, params: Dictionary)
signal request_panel(kind: StringName, args: Dictionary)     # 引擎要求界面打开某个面板（月轮盘、牢房、钱不够……）
signal game_over(reason: StringName)
signal saved(path: String, ok: bool)
signal first_time(mech: StringName, args: Dictionary)           # 某机制第一次出现（CardFirsts.mark，§7.10.6）；args 只放 uid/def/kind/person
signal command_done(cmd: StringName, args: Dictionary, ok: bool) # G02 门面在每条指令（ui.* 除外）的最后 view_changed 之前发
signal ui_event(name: StringName, args: Dictionary)             # 只有界面发（CardIds.UI_EVENTS，§7.10.5）；引擎永远不连它
```
- 引擎在 `send()` 结束前按 `ctx.out` 的顺序发；每个指令倒数第二条是 `command_done`、最后一条一定是 `view_changed`（`ui.*` 指令什么都不发）。
- **单向规则只有一个例外**：`ui_event` 由界面发，只给新手指引（C16 的 `CardGuide`）和测试听；引擎代码里不许 `connect` 它（Claude 审核时 grep），所以它永远影响不到游戏状态。
- 无头测试：`var bus := CardEventBus.new()`，用完 `bus.free()`。引擎代码**不直接引用** autoload `CardBus`，只用注入的 `bus`。

### 7.7 MockCardEngine 与夹具（W0）

```gdscript
class_name MockCardEngine
extends CardEngineApi
var sent: Array = []                                   # 收到过的 [cmd, args]，界面测试断言用
func load_fixture(path: String) -> void
```
夹具（`scripts/cards/mock/fixtures/*.json` 是 W0 的十个基础夹具；各界面任务的放自己的 `scripts/tests/cards/<ID>/fixtures/`）：
```json
{
  "_meta": {"owner": "C04", "schema": 1, "brief": "白天：林嫂来当金簪，柜台已打开"},
  "view": {},
  "queries": {"counter|{\"uid\":\"c0007\"}": {}, "slots|{\"uid\":\"c0005\"}": {}, "wheel|{\"uid\":\"\",\"wheel\":\"wh.month\"}": {}, "firsts|{}": {"firsts": {"deal": 1, "person": 1}}},
  "responses": [
    {"cmd": "counter.offer", "match": {"tier": "fair"},
     "result": {"ok": true, "err": "", "reply": "accept", "price": 45},
     "patch": [{"op": "set", "path": "money.amount", "value": 295}, {"op": "remove_from", "path": "hand", "uid": "c0007"}],
     "events": [["money_changed", 340, 295, "g04.reason.pawn_out"], ["card_left", "c0007", "resolved"], ["first_time", "ticket", {"no": 1}], ["view_changed", ["hand", "money"]]]},
    {"cmd": "*", "result": {"ok": true, "err": ""}}
  ]
}
```
- `responses` 按顺序找第一条 `cmd` 相同、`match` 里的键值都相等的；`"*"` 兜底。`patch` 的 op：`set`（点路径）、`append`、`remove_from`（按 uid）、`merge`。
- **查询键只有一种写法**：`<查询名>|<参数的 JSON，键排序、无空格>`（`JSON.stringify(args, "", true)`），没有参数写 `|{}`；Mock 用同一个函数算键。
- Mock 在每条指令的事件后面自动补 `command_done`（夹具里不用写），放在最后的 `view_changed` 前面；夹具没写 `view_changed` 时补一条。
- Mock 回答新手指引的查询：`guide_data` 读 `data/cards/guide/*.json`（夹具写 `"guide": "examples"` 时读 `_examples/guide/`），`guide_progress` 从夹具的 `"guide_progress"` 取、`ui.guide` 在内存里更新它，`firsts` 从夹具的查询取。
- W0 的十个基础夹具：`month_open`、`month_wheel`、`morning`、`day_full`（9 张手牌含金色牌、留牌、人脉、条子）、`day_counter`（金簪的 `spot` 布局由真 ItemGen 生成后按 §8.2 转好，C12 不用等 G04）、`night`、`settle`、`month_close`、`year_jump`、`street_prison`。每个夹具都带它那一刻应有的 `firsts|{}` 查询结果、`day.end_preview|{}` 查询结果和 `day.end` 的回应（`confirm` 真、假各一条，1.2；情景模式照 §7.4.7 实现了打烊 · 下一天，`W0_next_day` 测不卡死）。1.3：每个夹具的视图都带 `stage`；有演出块的例子牌的 CardView 带 `stage`；`night_offers` 是字典；G01 的 1.3 小 PR 合入前，例子牌的演出块放在 `scripts/cards/mock/stage_examples.json`（Mock 读它补进 CardView），合入后挪进 `_examples` 再删掉。

### 7.8 界面：面板基类、面板表、共用控件

```gdscript
class_name CardPanel
extends Control
signal close_requested(result: Dictionary)
var engine: CardEngineApi
var bus: CardEventBus
func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void   # 连上 bus 信号；子类 super() 后再连自己的
func open(args: Dictionary) -> void                                # 宿主打开时调用
func refresh(view: Dictionary) -> void                             # 收到 view_changed 后宿主调用
func autoplay_step() -> bool                                       # 做一个合理的动作（发一条指令或推进动画），没得做返回 false；同一状态永远做同样的事
func dismiss() -> void                                             # 1.2：“算了”——关掉按钮和宿主的 Esc 都调它；默认 close_requested.emit({})
```

面板表（C01 的 `CardModalHost.open_panel(kind, args)` 按这张表实例化；场景不存在时显示占位面板，不报错）：

“呈现”：`stage` = 在画面里演 + 对话框（`CardStagePanel` 的子类，§7.11.4；一次只演一出）· `drawer_l` / `drawer_r` = 左/右抽屉（§7.11.8）· `overlay` = 画面正中的叠层（下面一层 `shade` 遮罩，最大 1100×640，可以叠几层）· `host` = 宿主自己管。

| kind | 场景 | 根脚本 class | 主人 | 呈现 |
|---|---|---|---|---|
| `counter` | `res://scenes/cards/counter/CounterPanel.tscn` | `CardCounterPanel`（extends `CardStagePanel`） | C04 | stage |
| `slots` | `res://scenes/cards/slots/SlotPanel.tscn` | `CardSlotPanel`（extends `CardStagePanel`） | C03 | stage |
| `read` | `res://scenes/cards/slots/SlotPanel.tscn`（`{"mode": "read"}`） | `CardSlotPanel` | C03 | stage |
| `demand` | `res://scenes/cards/demand/DemandPanel.tscn` | `CardDemandPanel`（extends `CardStagePanel`） | C05 | stage |
| `fortune` | `res://scenes/cards/fortune/FortunePanel.tscn` | `CardFortunePanel`（extends `CardStagePanel`） | C07 | stage |
| `prison` | `res://scenes/cards/ladder/PrisonPanel.tscn` | `CardPrisonPanel`（extends `CardStagePanel`） | C11 | stage |
| `night` | `res://scenes/cards/night/NightPanel.tscn` | `CardNightPanel`（extends `CardStagePanel`） | C08 | stage |
| `settle` | `res://scenes/cards/night/SettlePanel.tscn` | `CardSettlePanel`（extends `CardStagePanel`） | C08 | stage |
| `contacts` **（新）** | `res://scenes/cards/slots/ContactsDrawer.tscn` | `CardContactsDrawer` | C03 | drawer_l |
| `demands` **（新）** | `res://scenes/cards/demand/DemandsDrawer.tscn` | `CardDemandsDrawer` | C05 | drawer_l |
| `dossier` | `res://scenes/cards/dossier/DossierBook.tscn` | `CardDossierBook` | C10 | drawer_l（`args.tab = "rules"` 时直接翻到“规矩”页） |
| `shelf` **（新）** | `res://scenes/cards/counter/ShelfDrawer.tscn` | `CardShelfDrawer` | C04 | drawer_r（`args.pick_for = <uid>` 时是“来买：挑一件”的样子） |
| `tickets` **（新）** | `res://scenes/cards/counter/TicketsDrawer.tscn` | `CardTicketsDrawer` | C04 | drawer_r |
| `estates` | `res://scenes/cards/ladder/EstatePanel.tscn` | `CardEstatePanel` | C11 | drawer_r |
| `almanac` **（新）** | `res://scenes/cards/fortune/AlmanacDrawer.tscn` | `CardAlmanacDrawer` | C07 | drawer_r |
| `relics` **（肉鸽 v1）** | `res://scenes/cards/rogue/RelicsDrawer.tscn` | `scripts/cards/ui/rogue/relics_drawer.gd`（extends `CardPanel`，不写 class_name） | RG4 | drawer_r（场景热点 `curio` 开它；抽屉标题 `rg4.drawer.relics`，登记在 `modal_host.gd` 的 `DRAWER_TITLES`） |
| `settings` | `res://scenes/cards/shell/CardSettings.tscn` | `CardSettings` | C16 | drawer_r |
| `wheel` | `res://scenes/cards/wheel/WheelPanel.tscn` | `CardWheelPanel` | C06 | overlay |
| `end_day` | `res://scenes/cards/night/EndDayConfirm.tscn` | `CardEndDayConfirm` | C08 | overlay |
| `month_open` | `res://scenes/cards/month/MonthOpen.tscn` | `CardMonthOpen` | C09 | overlay（全屏过场） |
| `month_close` | `res://scenes/cards/month/MonthClose.tscn` | `CardMonthClose` | C09 | overlay |
| `year_jump` | `res://scenes/cards/month/YearJump.tscn` | `CardYearJumpPanel` | C09 | overlay |
| `game_over` | `res://scenes/cards/month/GameOver.tscn` | `CardGameOver` | C09 | overlay |
| `short` | `res://scenes/cards/ladder/ShortPanel.tscn` | `CardShortPanel` | C11 | overlay |
| `contacts_full` | `res://scenes/cards/slots/ContactsFull.tscn` | `CardContactsFull` | C03 | overlay |
| `kept_full` | `res://scenes/cards/slots/KeptFull.tscn` | `CardKeptFull` | C03 | overlay |
| `help` | `res://scenes/cards/dossier/HelpPanel.tscn` | `CardHelpPanel` | C10 | overlay |
| `pause` | `res://scenes/cards/shell/CardPause.tscn` | `CardPause` | C16 | overlay |
| `stocktake` **（肉鸽 v1）** | `res://scenes/cards/rogue/StocktakePanel.tscn` | `scripts/cards/ui/rogue/stocktake_panel.gd`（extends `CardPanel`，不写 class_name） | RG4 | overlay（引擎 `request_panel`，根的 `_sync_phase_panel` 按 `view.open_panel` 自动开；`open({offer?})`） |
| `minigame` | 按 §8.1 表 | （宿主 `CardMiniGameHost`） | C01 | host（在叠层之上） |

- 场景还不存在时：宿主用 `CardIds.panel_scene(kind)`（真场景存在就用它，否则 W0 的 `res://scenes/cards/_w0/PanelStub.tscn`），所以缺场景不报错。`PanelStub` 有 `var kind: StringName`，宿主实例化后、`open()` 之前设上。
  - **X01-b**：表里每个 kind 都有主人的场景了（最后一个是 C07 的 `AlmanacDrawer.tscn`），W0 的 `PanelStub`、`w0_stub.gd` 和 `CardIds.PANEL_STUB` 删掉。`CardIds.panel_scene(kind)` 只返回表里的路径（`minigame` 和表外的 kind 返回 `""`）；宿主遇到没登记场景的 kind 什么都不开、`open_panel` 返回 `null`、不报错、不发指令（框架版收尾默认，主创可改）。W0 测试改成查“表里每个 kind 的场景都在、根是 `CardPanel`”。
  - **`almanac` 抽屉**（C07 `CardAlmanacDrawer`）：只读，从上到下是今天的宜、忌（`g05.almanac.<动作>`，`done` 里有的打小勾，宜忌都打）、本月运势的段名（`notice.fortune` → `<段 id>#title`）、求过的签（`view.lots`，新的在上，最多 8 支，只显示签诗 `#verse`，不显示等第、日子和任何数）；某一块没有就写 `c07.drawer.none`。开着时 `a.almanac` 指到抽屉里今天的宜忌（HUD 的黄历条被遮罩盖住），关了退回 HUD。“合上”、点遮罩、Esc 都是 `dismiss()`，只关；`autoplay_step()` 看一眼就关。（框架版收尾默认，主创可改）
- 主人还没迁过来的面板（呈现是 `stage`，但根脚本还不是 `CardStagePanel` 的子类，例如 1.2 写好的 `CardCounterPanel`）：宿主照 `overlay` 开它（居中叠层），不调 `bind_stage()`，但仍先 `stage.play(CardStageScript.resolve(cv, view))` 让人站上来；W1 结束前各主人都要迁完（§3.2 各卡的 1.3 范围）。
- 新增的抽屉 kind（`contacts` `demands` `shelf` `tickets` `almanac`）和改成抽屉的 `dossier` `estates` `settings`：`dismiss()` 只关、不发指令。
- **肉鸽 v1 的两块面板**（RG4，§15；W0 的 `day_full` 冒烟会 `open({"uid": "c0002"})` 它们，视图没有 `relics` / `stock`、查询返回 `not_implemented` 时安静地显示空状态）：
  - `stocktake` 叠层：只问 `stocktake` 查询，摆 2 或 3 张卡（物件框按深浅 `wood` / `seal` / `frame_gold`，客源 `jade`）；“就要这件 / 就请这拨人” → `stock.pick {offer, pick}`（物件且 `full` → 先进“让出一件”，再 `stock.pick {offer, pick, replace}`）；“都不要” → `stock.pick {offer, pick: ""}`；“回头再说”、Esc、点遮罩 = `dismiss()`，只关、不发指令（让出那一步 Esc 先退回三张卡）；成功后关，并回 `close_requested {"say": [这次 `stock.pick` 往 `view.notice.news` 里添的告示]}`（物件 / 客源的 `#lines.gain`、`rg1.notice.released`、`rg2.notice.passed`），根的 `_on_follow_up` 马上在对话框里说（对话框开着就接在后面，比如夜里的日结）——夜里挑的告示天亮就清，不说玩家就看不见；失败（如 `already_resolved`）显示 `rg2.reason.offer_closed` 一行并关；`refresh()` 重新问查询，报价不再 `open` 就自己关（自己的 `stock.pick` 还没返回时不关）；副行（周末盘账）多一句 `rg4.stock.how`；卡片悬停显示整段来历（`body`）；键盘 1–3 选卡、Enter 按主按钮，让出那一步 1–6 选、Enter 确认；`autoplay_step()` 挑 `items[0]`（物件且满 → `replace = held[0].id`）。界面上除这一周的成交笔数外没有数字、没有 `%`。
  - `relics` 抽屉：只读。顶行“摆了 n 件，一共 cap 格”（`rg4.relics.count`），不灵时一行 `rg4.relics.dormant`、各行压暗；每件一行（图 ×2、名、深浅词、整段来历 `body`、`use`、有毛病才画 `lines.flaw`）；下面一节这一关的客源；`view.stock.open != ""` 时顶上一个按钮 `rg4.relics.pending` → `close_requested.emit({"next": {"kind": "stocktake", "args": {"offer": open}}})`（根的 `_on_follow_up` 开它）。`dismiss()` 只关。
  - `dossier`（C10 的档案簿，RG5 加的）：问完 `dossier` 再问 `legacy.old_ink`（Mock 没有就当没有），把以前各本账见过、这一本还没有的碎片画成**旧墨**（`state: "old"`，整行压淡、右上小印 `rg5.dossier.old_ink`、页底 `rg5.dossier.old_ink_hint`）；只有旧墨的人另加一页，索引格子名字压暗。旧墨不算数：补齐和 `dossier_has` 只认这一本拿到的。

**每个面板都能关（“算了”，红线 9）**：关掉按钮和 Esc 都等于这个面板的“算了”。宿主 Esc 时调 `CardPanel.dismiss()`（1.2 新加，默认 = `close_requested.emit({})`）；有默认做法的面板覆盖它，先发那条指令再关：`night` → `night.choose {def: ""}`（今晚不选）· `kept_full` → `card.discard {uid: new_uid}`（扔掉新来的）· `contacts_full` → `contact.release {uid: new_uid}`（新来的不留）· `short` → `short.resolve {by: "default"}`（认了）· `counter` → `counter.close`（客人还在手上）· `game_over` → 回标题；其余（`slots` `read` `demand` `wheel` `fortune` `prison` `end_day` `settle` `month_open` `month_close` `year_jump` `dossier` `estates` `help` `pause` `settings`）只关面板、不发指令，东西都留着，往前走靠“打烊 · 下一天”；小游戏 Esc = `abort()`，另外 C01 的 `CardMiniGameHost` 在小游戏框上放一个看得见的“算了”按钮（= `abort()`），只用鼠标也关得掉。没有关不掉的面板（C01 卡原来的 `can_close()` 约定作废）。1.3 加两句：`stage` 的面板“算了”= 这一出先放一放（`counter` → `counter.close`，客人留在手上；`night` → `night.choose {def: ""}`；其余只收场、不发指令，牌留在手上）；抽屉“算了”= 收回。

画面上的控件：

新控件都有一个 **W0 的接口基类**（Claude，冻结，`scripts/cards/ui/common/`）：主人的实现 `extends` 它；用它的别的线只按基类的类型写（`var dialog: CardDialogApi`），所以主人还没合入时用 W0 的桩（`res://scenes/cards/_w0/*.tscn`）照样能跑。取场景一律 `CardIds.widget_scene(name)`（真场景存在用它，否则用桩）。**X01-b**：各主人的控件都合入了，W0 的控件桩（`scripts/cards/ui/common/w0/**`、`scenes/cards/_w0/**`）和 `CardIds.WIDGET_STUBS` 删掉；`widget_scene(name)` 只返回 `WIDGET_SCENES` 里主人的路径。W0 的 `W0_stage` 测试改对着真控件验同一组冻结接口。

| 控件 | 场景（`CardIds.WIDGET_SCENES` 的名） | 接口基类（W0） → 实现 class | 主人 | 冻结的公开接口 |
|---|---|---|---|---|
| 场景层 | `res://scenes/cards/table/CardStage.tscn`（`stage`） | `CardStageApi` → `CardStage` | C01 | 见 §7.11.3 |
| 对话框 | `res://scenes/cards/counter/DialogBox.tscn`（`dialog`） | `CardDialogApi` → `CardDialogBox` | C04 | 见 §7.11.5 |
| 手牌扇 | `res://scenes/cards/card/HandFan.tscn`（`hand_fan`） | `CardHandApi` → `CardHandFan` | C02 | 见 §7.11.6 |
| 英雄头像与人脉小牌 | `res://scenes/cards/card/HeroBar.tscn`（`hero_bar`） | `CardHeroApi` → `CardHeroBar` | C02 | 见 §7.11.6 |
| 柜台上的格子与铜钱 | `res://scenes/cards/slots/CounterChecks.tscn`（`checks`） | `CardChecksApi` → `CardCounterChecks` | C03 | 见 §7.11.7 |
| 牌 | `res://scenes/cards/card/CardWidget.tscn`（`card`） | `CardWidget` | C02 | （1.2 原样）`signal pressed(uid: String)` · `signal action_requested(uid: String, action_id: String)` · `func set_card(card_view: Dictionary) -> void` · `func set_size_mode(mode: StringName) -> void`（`&"hand"` 144×200 / `&"zoom"` 288×400 / `&"mini"` 72×100）· `func set_highlight(on: bool) -> void` · `func get_uid() -> String` · 拖拽数据 `{"kind": "card", "uid": uid, "zone": zone}`；1.3：`set_size_mode` 的 `&"zoom"` 288×400 改叫“选中放大”，用在手牌扇的预览；拖拽数据照旧 `{"kind": "card", "uid", "zone"}` |
| 美术解析 | — | `CardArt`（静态） | C02 | （1.2 原样）`static func texture(art_id: String) -> Texture2D` · `static func path(art_id: String) -> String` · `static func is_placeholder(art_id: String) -> bool` · `static func base_size(art_id: String) -> Vector2i` |
| 格子 | `res://scenes/cards/slots/SlotWidget.tscn`（`slot`） | `CardSlotWidget` | C03 | （1.2 原样）`signal place_requested(slot_id: String, source: Dictionary)` · `signal remove_requested(slot_id: String, index: int)` · `func set_slot(card_uid: String, slot_view: Dictionary) -> void` · 接受拖拽 `{"kind":"card"…}` 和 `{"kind":"money","amount":n}`；1.3 起摆在柜台上（160×120，§7.11.7），也收 `{"kind": "self"}`（拖头像）和 `{"kind": "item", "item"}` |
| 掷铜钱 | `res://scenes/cards/slots/CoinToss.tscn`（`coin_toss`） | `CardCoinTossView` | C03 | （1.2 原样）`signal finished` · `func play(faces: Array, need: int) -> void` · `func skip() -> void`；1.3 起在柜台上那一排（§7.11.7） |
| 条子板 | `res://scenes/cards/demand/DemandBoard.tscn`（`demand_board`） | `CardDemandBoard` | C05 | （1.2 原样）`func refresh(view: Dictionary) -> void` · `signal demand_pressed(uid: String)`；1.3 起嵌在“条子”抽屉里 |
| 黄历条 | `res://scenes/cards/fortune/AlmanacStrip.tscn`（`almanac_strip`） | `CardAlmanacStrip` | C07 | （1.2 原样）`func refresh(view: Dictionary) -> void`；1.3 起嵌在 HUD 里，一行 260×24 |
| 街头层 | `res://scenes/cards/ladder/StreetOverlay.tscn`（`street_overlay`） | `CardStreetOverlay` | C11 | （1.2 原样）`func refresh(view: Dictionary) -> void` · `signal redeem_shop_pressed`；1.3 起只有“赎回铺面”按钮和一句提示（背景由场景层按 `stage.set == "street"` 换），整层除按钮外鼠标穿透 |
| 标题 | `res://scenes/cards/shell/CardTitle.tscn`（`title`） | `CardTitle` | C16 | （1.2 原样）`signal chose(action: StringName)`（`&"new"` `&"continue"` `&"settings"` `&"quit"`）；**肉鸽 v1（RG4 加，冻结）**：`chose` 多两个动作 `&"reseed"`（按“换一个”）`&"opening"`（换了开头），`ACTIONS` 常量不变；`func set_rogue(data: Dictionary) -> void`（外壳给右下角 RunBox 的数据：`run_no` `seed` `openings:[{id, unlocked}]` `opening` `shelf:[{no, key, args, reason, opening}]`（旧→新）`notice_key`；集成审读补 `open_no`（还没合上的那本，没有 = 0；非 0 时首行说 `rg4.title.run_open`“第 open 本还没合上，开张会合上它、另起第 n 本”）；进树前调也行，`_ready` 里再建）· `func seed_text() -> String`（种子框原文；盒子没显示时 `""`）· `func opening_id() -> String`（选中的开头；盒子没显示时 `"og.default"`）。不调 `set_rogue` 时标题和以前一模一样（Mock、测试、自动玩）；焦点在种子框时只认 Enter（= `chose(&"new")`）和 Esc（焦点还给“开张”），别的键都交给输入框，C16 的焦点规矩不变 |
| 新手指引 | `res://scenes/cards/shell/GuideOverlay.tscn`（`guide`） | `CardGuide` | C16 | 见 §7.10.7 |
| 设置的读取 | — | `CardSettings`（静态函数） | C16 | **1.3 冻结**：`static func fast_anim(path: String = "user://cards/settings.json") -> bool`（快动画开没开）；对话框的打字速度用 `scripts/town/settings.gd` 的 `text_cps()`（已有，C01 读后设给对话框；它返回 float，C01 取整后赋给 `chars_per_sec`）。1.2 的缺口“快动画开关没有冻结的读取接口”就此关闭 |

W0 给新控件建了接口基类和桩（附录 A、附录 G）；主人只替换实现，不改场景路径和公开接口。每个控件、面板在 `_ready`/`open` 时用 `CardAnchors.register()` 登记 §7.10.5 里归自己的锚点。

- 根场景 `res://scenes/cards/CardGame.tscn`（`CardGameRoot`，C01）：公开 `var engine: CardEngineApi`、`var host: CardModalHost`、`func boot(opts: Dictionary) -> void`；命令行 `--cards-mock=<夹具路径>`、`--seed=<n>`。**X01-b（发行阻断）**：默认是真引擎 `CardEngine`——发行包（主场景 `CardGame.tscn`、不带参数）、`Main.tscn` 的 `--cards`、`boot()` 不给 `mock` 都是；只有命令行 `--cards-mock[=夹具]` 或 `boot({mock: true})` 才用 `MockCardEngine`，要 Mock 的测试和截图一律显式写 `mock: true`（测试 `X01_boot_ship`）。
- 文字：`CardText.ui(key, args)`、`CardText.card(def_id, field, args)`、`CardText.t("<def>#<field>")`、`CardText.is_draft(key)`（草稿样式用）。颜色：`CardTheme.color(&"seal")`、`CardTheme.frame_style(type: StringName, gold: bool) -> StyleBox`、`CardTheme.font_title()`/`font_body()`。

### 7.9 各模块的公开函数（冻结签名）

所有模块函数都是 `static func`，第一个参数是 `ctx: CardCtx`（下面省略类型）。返回字典的一律带 `ok`/`err`。

**G01 core**
```gdscript
class_name CardDB            # extends RefCounted
static func load_all(root: String = "res://data/cards", opts: Dictionary = {}) -> CardDB   # opts: {only_examples: bool, ship: bool}；剧情插件另见下（2026-10-22）：packs、pck_dirs、enable_packs、disable_packs、no_packs、no_ai
func def(id: String) -> Dictionary                      # 只读副本；没有返回 {}
func has(id: String) -> bool
func ids_of(type: StringName) -> PackedStringArray     # 排好序
func pool(type: StringName, era: String) -> PackedStringArray   # weight>0、年代命中、排好序
func persons() -> Dictionary                           # cast.json + persons 块
func rules(name: String) -> Dictionary                 # rules/<name>.json 深合并 balance_overrides
func tags() -> Dictionary
func text_entry(id: String) -> Dictionary              # 覆盖层原样（可能为空）
func brief_of(ref: String) -> String                   # 牌 id、界面键、观察键都行
func obs_catalog(kind: StringName) -> Dictionary
func art_manifest() -> Dictionary
func stage(index: int) -> Dictionary
func hash() -> String                                  # 机制数据（不含 text、brief、_provenance）的 sha256
func errors() -> PackedStringArray
# 2026-10-22 框架版收尾（剧情插件，docs/cards/PLUGINS.md；主创可改）：
func text_value(id: String, field: String) -> String   # 逐字段：插件 → 人写 → AI；没有返回 ""
func text_source(id: String, field: String) -> String  # "pack:<id>" "human" "ai" 或 ""
func pack_hit(id: String, field: String) -> Dictionary # 给出这段字的最上层插件 {pack, source, provenance, value}；没有 {}
func pack_text_entry(pack_id: String, id: String) -> Dictionary
func ai_text_entry(id: String) -> Dictionary           # AI 层原样（text_entry 只给人写层）
func packs() -> Array                                  # 找到的插件 {id, dir, state: loaded|disabled|skipped, reason, name, version, order, source, …}
func warnings() -> PackedStringArray                   # 正文层的问题（不挡新局）

class_name CardPiles
static func spawn(ctx, def_id: String, zone: StringName, extra: Dictionary = {}) -> String   # 新 uid
static func move(ctx, uid: String, zone: StringName) -> String                               # 错误码，"" 成功
static func zone_of(ctx, uid: String) -> StringName
static func list(ctx, zone: StringName) -> PackedStringArray
static func card(ctx, uid: String) -> Dictionary
static func def_of(ctx, uid: String) -> Dictionary
static func keep(ctx, uid: String) -> String
static func resolve(ctx, uid: String, outcome: StringName, extra: Dictionary = {}) -> void    # 处理完：进弃牌、发 card_left、触发 card_resolved（extra.almanac 原样带上）、执行 on_resolve
static func order_hand(ctx) -> void                                   # 手牌排序的唯一写法：按 (deal.json.hand_order 的先后, hand_sub, seq)；每次往手牌里加牌后调
static func discard(ctx, uid: String) -> String                       # card.discard：扔掉，不执行 on_expire；错误码，"" 成功
static func expire(ctx, uid: String) -> void                          # 执行 on_expire、移走
static func cap(ctx, zone: StringName) -> int

class_name CardComposer
static func compose(ctx) -> PackedStringArray            # 发今天的牌（日程 → 钉签 → 按权重抽 → 排序），返回新 uid
static func project(ctx, abs_day: int) -> PackedStringArray   # 只算不改：用当前状态算那一天随机部分会抽到的 def
static func night_offers(ctx) -> PackedStringArray
static func street_deal(ctx) -> PackedStringArray

class_name CardSave
const DEFAULT_ROOT := "user://cards"
static func set_root(dir: String) -> void                # 测试用 user://test/<清单名>/；new_game 的 save_dir 也走它
static func root() -> String
static func suspend_path() -> String                    # <根>/suspend.json
static func stage_path(stage: int) -> String            # <根>/stage_%02d.json
static func write(path: String, state: CardState, meta: Dictionary) -> Dictionary
static func read(path: String) -> Dictionary            # {ok, err, state: CardState, meta}
static func exists(path: String) -> bool

class_name CardText
static func setup(db: CardDB) -> void
static func ui(key: String, args: Dictionary = {}) -> String
static func card(def_id: String, field: String, args: Dictionary = {}) -> String
static func t(ref: String, args: Dictionary = {}) -> String           # "key" 或 "<def>#<field>"
static func person_name(person: String) -> String
static func item_text(template: String, field: String) -> String
static func obs(key: String) -> String
static func is_draft(ref: String) -> bool
static func issued_contains(s: String) -> bool          # 开发版：这段字是不是 CardText 给出过的（界面测试用）
# 2026-10-22 框架版收尾（主创可改）：
static func has_text(ref: String) -> bool               # 任一层有非空字；界面为假时跳过这一拍
static func set_show_drafts(on: bool) -> void           # 开发开关（测试库默认开）
static func shows_drafts() -> bool                      # 发行版永远 false

class_name CardValidator
static func validate(root: String, mode: StringName, opts: Dictionary = {}) -> Dictionary   # {errors: PackedStringArray, notes: PackedStringArray, cards: int}；opts: {examples: bool, only: PackedStringArray}

class_name CardFirsts
static func mark(ctx, mech: StringName, args: Dictionary = {}) -> bool   # §7.10.6
static func all(ctx) -> Dictionary
```

**G02 loop**
```gdscript
class_name CardEngine        # extends CardEngineApi
func _init(p_bus: CardEventBus = null) -> void
var ctx: CardCtx
func register_command(cmd: StringName, handler: Callable, owner: String) -> void   # handler: func(ctx, args) -> Dictionary
func register_query(q: StringName, handler: Callable, owner: String) -> void

class_name CardDayLoop
static func begin_stage(ctx, stage: int) -> void
static func open_month(ctx) -> Dictionary
static func begin_day(ctx) -> Dictionary
static func end_day(ctx, confirm: bool) -> Dictionary          # §7.4.7 打烊 · 下一天（1.2 起参数名 confirm）
static func choose_night(ctx, def_id: String) -> Dictionary
static func settle(ctx) -> Dictionary
static func close_month(ctx) -> Dictionary
static func jump_year(ctx) -> Dictionary
static func set_phase(ctx, phase: StringName) -> void
static func advance_minutes(ctx, minutes: int) -> void
static func request_panel(ctx, kind: StringName, args: Dictionary) -> void   # 写 loop.open_panel 并 emit request_panel；别的模块要开面板只用它
static func set_mode(ctx, mode: StringName) -> void                         # &"shop" / &"street"（G06 用）
static func open_pre_ending_window(ctx, owner: String) -> bool             # 1.4 K18：末关月账完成后的结局前白天窗口；短款未清返回 false（#187）

class_name CardCalendar
static func today(ctx) -> Dictionary                    # {y, m, d, weekday, stage_day, abs_day, minute}
static func date_of(ctx, stage_day: int) -> Dictionary
static func is_market_day(ctx, stage_day: int) -> bool
static func week_of(ctx, stage_day: int) -> int

class_name CardSchedule
static func due(ctx, abs_day: int) -> PackedStringArray     # scheduled_cards 修正项的提供者

class_name CardGoldRule
static func hand_sub(ctx, uid: String) -> int            # hand_sub 修正项的提供者：金色牌返回 schedule.order，其余 0（不自己挪牌）
static func pending(ctx) -> PackedStringArray
static func leave(ctx, uid: String) -> void

class_name CardGoals
static func pick(ctx) -> void
static func evaluate(ctx, when: StringName) -> void
static func verdict_key(ctx) -> String

class_name CardYearJump
static func run(ctx) -> Dictionary

class_name CardViewModel
const FORBIDDEN_KEYS: Array = []                        # §7.5 的黑名单（字符串）
static func build(ctx) -> Dictionary
static func card_view(ctx, uid: String, detailed: bool) -> Dictionary
static func leaks(v) -> PackedStringArray                # 违规路径；空 = 干净
```

**G03 rules**
```gdscript
class_name CardSlots
static func slots_of(ctx, uid: String) -> Array          # 牌面格子，或已选选项的检定格子
static func can_place(ctx, uid: String, slot_id: String, source: Dictionary) -> String
static func place(ctx, uid: String, slot_id: String, source: Dictionary) -> Dictionary
static func remove(ctx, uid: String, slot_id: String, index: int) -> Dictionary
static func preview(ctx, uid: String) -> Dictionary      # {coins, auto_heads, need, auto_pass, ready}
static func roll(ctx, uid: String) -> Dictionary         # {faces, heads, need, success}

class_name CardCoins
static func toss(ctx, uid: String, attempt: int, n: int) -> Array    # Array[bool]，c.coin

class_name CardChoices
static func options(ctx, uid: String) -> Array           # [{id, enabled, reason_key, has_check}]
static func choose(ctx, uid: String, choice_id: String) -> Dictionary

class_name CardMeters
static func value(ctx, meter: StringName) -> int
static func tier(ctx, meter: StringName) -> int
static func add(ctx, meter: StringName, delta: int, source: String) -> void
static func bump_tier(ctx, meter: StringName, steps: int, source: String) -> void
static func attr(ctx, who: String, attr: StringName) -> int
static func add_attr(ctx, who: String, attr: StringName, delta: int, days: int, source: String) -> void

class_name CardKeptRules
static func bonus(ctx, kept_uid: String, slot: Dictionary) -> Dictionary   # {coins, heads, auto_pass}
static func run_risk(ctx, tags_any: Array, source: String) -> void

class_name CardDemands
static func issue(ctx) -> String
static func submit(ctx, uid: String) -> Dictionary
static func delay(ctx, uid: String) -> Dictionary
static func days_left(ctx, uid: String) -> int
static func on_settle(ctx) -> void

class_name CardDossier
static func add(ctx, frag: String) -> void
static func gap(ctx, frag: String) -> void
static func year_after(ctx) -> Array
static func view(ctx, person: String = "") -> Dictionary
```

**G04 economy**
```gdscript
class_name CardCounter
static func open(ctx, uid: String) -> Dictionary
static func offer(ctx, uid: String, tier: StringName) -> Dictionary
static func answer(ctx, uid: String, accept: bool) -> Dictionary
static func pick_stock(ctx, uid: String, item_id: String) -> Dictionary
static func redeem(ctx, uid: String, mode: StringName) -> Dictionary
static func refuse(ctx, uid: String) -> Dictionary
static func close(ctx, uid: String) -> Dictionary
static func view(ctx, uid: String) -> Dictionary

class_name CardPricing
static func tiers(ctx, uid: String) -> Dictionary        # {harsh, fair, kind, direction}

class_name CardCustomer
static func reply(ctx, uid: String, price: int) -> Dictionary
static func spend_patience(ctx, uid: String, minutes: int) -> StringName    # &"" / &"raise" / &"leave"

class_name CardShelf
static func items(ctx) -> PackedStringArray
static func cap(ctx) -> int
static func add(ctx, item: Dictionary, source: String) -> String
static func remove(ctx, item_id: String, reason: String) -> void
static func view(ctx) -> Array

class_name CardTickets
static func open(ctx, uid: String, item_id: String, principal: int, term_days: int) -> int   # 当票号（整数；合同 id 是 ASCII 的 t%04d）
static func tick(ctx) -> void
static func forfeit_all(ctx) -> Array
static func view(ctx) -> Array

class_name CardAppraisal
const FORBIDDEN_PARAM_KEYS: Array = []                  # §8.2（字符串）
static func request(ctx, uid: String, item_id: String) -> Dictionary        # {ok, kind, params}
static func params_for(ctx, item_id: String, kind: StringName) -> Dictionary
static func report(ctx, uid: String, item_id: String, result: Dictionary) -> Dictionary

class_name CardItems
static func generate(ctx, key: Array, template_or_cat: String) -> Dictionary
static func templates() -> Dictionary                    # 现有模板 + templates_extra

class_name CardCurrency
static func apply_stage(ctx, stage: Dictionary) -> void
static func convert(ctx, to: String, num: int, den: int) -> void
static func money(ctx) -> int

class_name CardMonthAccounts
static func close(ctx) -> Dictionary
```

**G05 fate**
```gdscript
class_name CardWeights
static func rows(ctx, pool: StringName) -> Array         # [[def_id, weight_int]]，按 def_id 排好

class_name CardFateTrigger
static func fate_due(ctx) -> bool
static func crisis(ctx) -> StringName                    # &"" / &"cash_short" / &"arrested" / &"heat_max" / &"street_long"
static func on_crisis(ctx, kind: StringName) -> void

class_name CardWheel                                     # uid：那张牌；本月运势为 ""
static func view(ctx, wheel_id: String, uid: String) -> Dictionary
static func offer(ctx, wheel_id: String, uid: String, source: Dictionary) -> Dictionary
static func withdraw(ctx, wheel_id: String, uid: String, index: int) -> Dictionary
static func stake(ctx, wheel_id: String, uid: String, kept_uid: String) -> Dictionary
static func spin(ctx, wheel_id: String, uid: String) -> Dictionary    # {ok, segment, stop_deg}
static func weights(ctx, wheel_id: String, uid: String) -> Array      # [[segment_id, w]]，只在引擎内部用

class_name CardFortune
static func draw_lot(ctx, uid: String) -> Dictionary
static func cezi(ctx, uid: String, char_id: String) -> Dictionary
static func offer_chars(ctx) -> PackedStringArray

class_name CardAlmanac
static func today(ctx) -> Dictionary
static func note(ctx, actions: Array) -> void
static func settle(ctx) -> void

class_name CardPins
static func pin(ctx, abs_day: int, def_id: String, source: String) -> void
static func pinned(ctx, abs_day: int) -> PackedStringArray
static func ban(ctx, abs_day: int, tags: Array, source: String) -> void   # 测字“无”：这天随机抽和找替身跳过带这些标签的牌
static func banned(ctx, abs_day: int) -> PackedStringArray

class_name CardPressure
static func step_day(ctx) -> void
static func value_milli(ctx, key: String) -> int
```

**G06 ladder**
```gdscript
class_name CardMortgage
static func mortgage(ctx, estate_id: String) -> Dictionary
static func redeem(ctx, estate_id: String) -> Dictionary
static func on_month_close(ctx) -> void
static func view(ctx) -> Array

class_name CardShortLadder
static func on_short(ctx, args: Dictionary) -> void       # money_short 钩子：算 options/goods/estates，request_panel("short", …)
static func view(ctx) -> Dictionary                       # query("short")
static func resolve(ctx, args: Dictionary) -> Dictionary  # short.resolve

class_name CardStreet
static func enter(ctx) -> void
static func redeem_shop(ctx) -> Dictionary
static func shop_price(ctx) -> int

class_name CardPrison
static func arrest(ctx, reason: String) -> void
```

**G06 sim**
```gdscript
class_name CardPolicy        # extends RefCounted
func policy_name() -> StringName
func decide(engine: CardEngineApi, view: Dictionary) -> Array   # [cmd: StringName, args: Dictionary]；没得做返回 []

class_name CardAutoplay
static func play(engine: CardEngineApi, policy: CardPolicy, until: Dictionary) -> Dictionary
	# until: {stages:int, days:int, max_steps:int}；返回 {ok, stages_cleared, days, game_over_reason, steps, hash}

class_name CardReplay
static func record(engine: CardEngineApi) -> Array      # 指令日志
static func replay(opts: Dictionary, log: Array) -> String   # 最终状态哈希
```

### 7.10 新手指引（红线 8；主创 2026-10-13 硬性要求，DESIGN §九.4）

#### 7.10.1 规则

1. **每个机制都有指引**：`CardIds.FIRSTS` 里的每个机制（§7.10.10，共 70 个，含两个预留；**1.4** `office` + K18 `pet` + K18 `apprentice` + `scare`）至少有一个指引步骤（`teaches` 里有它）和一页规矩（`unlock_first` 里有它）——校验 V29。
2. **在戏里讲**：每一步由“教的人”开口——人物站到柜台一侧（§7.11.2 的 `GUIDE_TEACHER`）说一句 `say`，物件（告示、黄历、哥哥的账簿批注）用一张批注纸说；锚点旁一句气泡 `bubble`，说“现在可以做什么”。没有说明书弹窗。
3. **第一次遇到时才讲，按天逐步解锁**：引擎在机制第一次出现时发 `first_time`；步骤再用 `stage_day_gte`、`after` 排开，每天新亮的步骤有上限（`guide.json.max_new_per_day`）。
4. **教过的能回看**：规矩页进档案簿“规矩”栏和 F1 帮助（C10）；解锁只看 `firsts`，和指引开关无关。
5. **能关**：设置里“新手提示”开关（沿用 `settings.gd` 已有的 `guide_hints`）；命令行 `--guide=on|off`；自动试玩和 K14 的整局走查默认关。
6. **不打断**：一次只亮一步；整层鼠标穿透、不吃按键（F1 归 C10）、不暂停引擎、不挡任何面板的 `autoplay_step()`；两步之间留间隔。
7. **高亮锚点**：每个界面部件把自己的锚点矩形登记到 `CardAnchors`；步骤按锚点 id 找位置。
8. **不泄露**：台词和气泡不提概率、点数、本心和任何 §0 红线 3 里的隐藏数值（K13 审措辞，K15 审 `%`）。
9. **文字只有人写**：步骤、规矩页的骨架只有 `brief`（K16）；`say` `bubble` `title` `body` 在 `data/cards/text/guide/**`（A 写）；开发版显示【稿】+ brief。
10. **指引不改游戏**：`firsts` 不管指引开没开都记；指引进度在 `ui` 命名空间，不进状态哈希。同一种子、同一串指令，开着指引和关着指引的状态哈希相同（K14 的 W2 测试）。

#### 7.10.2 分工

| 部分 | 主人 | 位置 |
|---|---|---|
| 三个信号 `first_time` `command_done` `ui_event`（写在 G01 的 `card_bus.gd` 里，签名冻结）；锚点登记 `CardAnchors`；GuideOverlay/HelpPanel/CardGuide 的桩（`CardGuide` 的桩已能挑步骤：`trigger` 各项、priority、`max_shows`、`done_when`、timeout、间隔、每天上限、自动完成、备用锚点；没有 interrupt、渐显渐隐、气泡排版和按 `trigger.first` 建的索引——这些归 C16） | Claude（W0） | `scripts/cards/core/card_bus.gd`、`scripts/cards/ui/common/card_anchors.gd`、各桩场景 |
| `CardFirsts`、`core.firsts`、查询 `firsts` `guide_data` `guide_progress` `guide_conds`、`ui` 命名空间与指令 `ui.guide` | G01 | `scripts/cards/core/firsts.gd`、`core_install.gd` |
| 各机制第一次出现时 `CardFirsts.mark()` | 表 7.10.10 的“发出者” | 各自模块 |
| `command_done` | G02（门面） | `scripts/cards/loop/card_engine.gd` |
| 指引引擎与覆盖层：挑步骤、高亮、气泡、教的人、渐隐、存进度、开关、测试钩子；参数 `rules/guide.json` | C16 | `scenes/cards/shell/GuideOverlay.tscn`、`scripts/cards/ui/shell/card_guide.gd` |
| 宿主（最上层 CanvasLayer）、F1 转给帮助、`--guide=` 命令行 | C01 | `scenes/cards/CardGame.tscn` |
| 规矩栏、F1 帮助面板 | C10 | `scenes/cards/dossier/**` |
| 各部件的锚点与 `ui_event` | 各 C 任务（表 7.10.5） | 各自目录 |
| 步骤与规矩页骨架（brief + 机制字段）、`_test.d1_3`、教学日的牌 | K16 | `data/cards/guide/{steps,rule_pages}.json`、`data/cards/era/1938/tutorial.json` |
| 步骤与规矩页正文；F1 帮助的操作说明、设置里那一行的界面字 | A；B | `data/cards/text/guide/**`；`data/cards/text/ui/{C10,C16}.text.json` |
| 真引擎上第 1–3 天的指引走查与逐步截图 | K14（W2） | `scripts/tests/cards/K14/test_guide_d1_3.gd`、`shot_guide_d1_3.gd` |

#### 7.10.3 数据格式

步骤 `guide_step` 和规矩页 `rule_page` 的字段、例子见 §4.7.21；正文覆盖层见 §4.5；参数文件 `rules/guide.json` 见 §4.6。补充：

- 步骤按 `steps.json` 里的顺序参加挑选；同 `priority` 时前面的先。
- 锚点里的 `{uid}` 用触发它的那次 `first_time` 的 `args.uid` 代入；没有 uid 的机制，步骤只能用固定锚点。
- `done_when` 只认**这一步亮起来之后**发生的事；亮之前就满足了的，见 §7.10.7 第 4 条“自动完成”。

#### 7.10.4 锚点登记 CardAnchors（W0，Claude，冻结）

```gdscript
class_name CardAnchors
extends RefCounted
static func register(id: StringName, node: Control, rect_fn: Callable = Callable()) -> void
	# 只存 node 的 instance id（和可选的 rect_fn: func() -> Rect2，视口坐标，给只想高亮控件里一小块的部件用）；
	# node 发 tree_exiting 时自动注销。同一个 id 后登记的盖住先登记的。
static func unregister(id: StringName, node: Control) -> void   # 只注销这个 node 登记的那一条
static func rect(id: StringName) -> Rect2     # 视口坐标（1280×720 逻辑像素）；节点已释放、不在树里或 is_visible_in_tree() 为假 → Rect2()
static func has(id: StringName) -> bool       # rect(id) 有面积
static func ids() -> PackedStringArray        # 排好序；测试、截图脚本用
static func clear() -> void                   # card_t.finish() 调；C01 换场景时调
```
- 每张牌的锚点写成 `a.card@<uid>`（例 `a.card@c0007`）；数据里写 `a.card@{uid}`。
- 只存 instance id，不持有 Control 引用，所以不会泄漏、不会悬空。这是界面层唯一允许的可变静态表（引擎里仍不许有可变 `static var`）。
- 锚点 id 是封闭目录 `CardIds.ANCHORS`（id → 主人任务，表 7.10.5）；新锚点走 `[api]` issue。

#### 7.10.5 锚点与界面事件目录（`CardIds.ANCHORS`、`CardIds.UI_EVENTS`）

| 主人 | 锚点 |
|---|---|
| C01 | `a.top.date` `a.top.weather`（时辰、天气与集市）`a.top.money` `a.top.rep` `a.top.heat` `a.btn.close_day` · 场景：`a.scene`（整个场景）`a.scene.customer`（有人站柜台前时）`a.scene.notice`（门边的告示）`a.scene.ledger`（账簿）`a.scene.notebook`（档案簿）`a.scene.calendar`（黄历）`a.scene.cashbox`（钱匣）`a.scene.magnifier`（放大镜）`a.scene.notewall`（墙上的条子，有条子时）· 标签：`a.tab.contacts` `a.tab.demands` `a.tab.dossier` `a.tab.rules` `a.tab.shelf` `a.tab.tickets` `a.tab.estates` `a.tab.settings` |
| C02 | `a.hand`（手牌扇）`a.hand.gold`（第一张是金色牌时那张）`a.hand.kept`（扇里留着的牌）`a.hand.preview`（预览里的“打出”）`a.hero`（英雄头像）`a.contacts`（人脉小牌）`a.card@<uid>` `a.card.keep@<uid>` `a.card.days@<uid>` `a.card.gold@<uid>` |
| C03 | `a.slots.first`（柜台上第一个格子）`a.slots.coins`（铜钱那一排）`a.slots.money`（第一个收钱格子的 −/＋）`a.slots.roll`（“掷铜钱”那句回话）`a.slots.choices`（第一句选项回话）`a.slots.release`（人脉满）`a.slots.discard`（留牌满） |
| C04 | `a.dialog`（对话框，显示时）`a.dialog.next`（“跳过”）`a.counter.item`（柜上的东西）`a.counter.look`（“细看”那句回话）`a.counter.tier.harsh` `a.counter.tier.fair` `a.counter.tier.kind`（三档价的回话）`a.counter.reply`（客人回话那一句显示时的对话框正文）`a.counter.stock`（货架抽屉“挑一件”的格子）`a.counter.redeem`（来赎的第一句办法回话）`a.shelf.list`（货架抽屉）`a.tickets.list`（当票抽屉） |
| C05 | `a.demand.board`（条子抽屉里的条子板）`a.demand.days`（第一张条子的天数）`a.demand.tier`（档位字：抽屉里第一行；演出时柜台上那张条子道具后登记、盖住前者）`a.demand.modes`（办法的第一句回话）`a.demand.delay`（“拖一拖”那句回话） |
| C06 | `a.wheel.face` `a.wheel.incense` `a.wheel.cost` `a.wheel.spin` |
| C07 | `a.almanac`（HUD 里的黄历条）`a.fortune.lot` `a.fortune.cezi`（两句回话）`a.fortune.chars`（测字时第一个字的回话） |
| C08 | `a.endday.blocked`（确认面板里的清单）`a.endday.gold_leave`（清单里金色牌那一行）`a.night.offers`（夜里的手牌扇，用 `CardAnchors.register(…, rect_fn)` 取扇的外框）`a.settle.lines`（日结时的对话框） |
| C09 | `a.month.goals` `a.mclose.accounts` `a.year.forfeit` `a.year.after` `a.over.retry` |
| C10 | `a.dossier.page` `a.dossier.gap` `a.dossier.rules_tab` `a.help.rules` |
| C11 | `a.estate.list` `a.estate.mortgage` `a.short.options` `a.street.redeem` `a.prison.slots`（牢房那一出时柜台上的格子那一块） |
| C12 | `a.mg.spot.main` `a.mg.spot.atlas` `a.mg.spot.lens` `a.mg.spot.tag`（10-25：图钉清单与钉下以后的选择） |
| C13 | `a.mg.coin_ring.main` `a.mg.coin_ring.blow` `a.mg.coin_ring.ear` `a.mg.coin_ring.samples`（10-25：两枚样洋） |
| C14 | `a.mg.weigh.main` `a.mg.weigh.weights` `a.mg.weigh.beam` `a.mg.weigh.call`（10-25：五个说法） |
| C15 | `a.mg.fragments.main` `a.mg.fragments.board` `a.mg.fragments.seal` `a.mg.fragments.seam`（10-25：拼缝） `a.mg.decode.main` `a.mg.decode.book` `a.mg.decode.sheet`（10-25：电报纸） |
| C16 | `a.settings.guide_toggle` `a.pause.help` |
| RG4（肉鸽 v1） | `a.scene.curio`（场景里的博古格热点，`card_stage.gd` 按 `HOTSPOTS` 自动登记）`a.stock.offers`（盘账叠层里三张卡那一行，在 `OVERLAY_MAX` 里）`a.relics.list`（博古格抽屉里的那一列，裁到滚动窗口里）。v1 不加指引步骤（§15） |
| 预留 | `a.branch.list`（解放后选行当；首发不做） |

**1.3 改了名的 7 个**（`CardIds.ANCHORS_RENAMED`，旧 → 新；W1 里旧名照样登记得上、指引新旧互认，V30 在 default 模式下只给 NOTE；W2 由 X01 删掉旧名）。**X01-b 已删**：旧名不在 `CardIds.ANCHORS` 里了，`ANCHORS_RENAMED`、`CardIds.anchor_aliases()` 和界面上替旧名补登记的代码一起删；K16 步骤和各线测试只写新名。下表只留作对照：

| 旧（1.2） | 新（1.3） | 为什么 |
|---|---|---|
| `a.top.notice` | `a.scene.notice` | 告示从顶栏挪到门边 |
| `a.left.self` | `a.hero` | 你自己成了英雄头像 |
| `a.left.contacts` | `a.contacts` | 人脉成了头像旁的小牌 |
| `a.left.kept` | `a.hand.kept` | 留着的牌进了手牌扇 |
| `a.right.tickets` | `a.scene.ledger` | 当票的入口是账簿（备用 `a.tab.tickets`） |
| `a.right.shelf` | `a.tab.shelf` | 货架的入口是右边的标签 |
| `a.right.dossier` | `a.scene.notebook` | 档案簿的入口是柜台上的档案簿（备用 `a.tab.dossier`；回看规矩的那一步改用 `a.tab.rules`） |

主人变了的：`a.hand` `a.hand.gold` 从 C01 改归 C02（手牌扇是 C02 的）。

| 界面事件 | 谁发 | 参数 |
|---|---|---|
| `panel_opened` / `panel_closed` | C01（宿主；演出、抽屉、叠层都发） | `{kind, show}`（`show` ∈ `stage` `drawer_l` `drawer_r` `overlay`） |
| `drawer_opened` / `drawer_closed` **（新）** | C01 | `{kind, side}`（`side` ∈ `left` `right`） |
| `hotspot_pressed` **（新）** | C01（场景层） | `{id}`（`CardIds.HOTSPOTS`） |
| `hand_selected` | **C02**（1.2 是 C01） | `{uid}`（点一下 = 选中放大） |
| `hand_played` **（新）** | C02 | `{uid, def, how}`（`how` ∈ `drag` `button` `key` `auto`；夜里打夜牌 `uid` 为 `""`，“睡了” `def` 也为 `""`） |
| `card_zoomed` / `card_drag_started` | C02 | `{uid}` / `{uid, zone}`（`zone` 可以是 `hand` `kept` `contacts` `self`） |
| `slot_drop` | C03（SlotWidget 自己发） | `{uid, slot, kind}` |
| `dialog_advanced` **（新）** | C04 | `{uid}`（推到下一句） |
| `dialog_skipped` **（新）** | C04 | `{uid}` |
| `reply_chosen` **（新）** | C04 | `{uid, reply}` |
| `mg_tool` | C12–C15 | `{kind, tool}` |
| `guide_shown` / `guide_done` | C16 | `{step}` |

#### 7.10.6 引擎这边（G01；各模块发 first）

```gdscript
class_name CardFirsts
static func mark(ctx, mech: StringName, args: Dictionary = {}) -> bool
	# mech 必须在 CardIds.FIRSTS 里（否则 push_error）。core.firsts 里还没有它 → 记 {mech: abs_day}、
	# ctx.emit(&"first_time", [mech, args])、返回 true；已经有了 → 什么都不做、返回 false。
static func all(ctx) -> Dictionary            # core.firsts 的只读副本
```
- 什么时候 `mark`：表 7.10.10 的“什么时候算第一次”；各模块在自己的代码里调。`args` 只放看得见的（`uid` `def` `kind` `person` `no`）。
- 引擎根本不知道指引开没开，所以 `firsts` 总是记、总是发；它在状态里、进哈希，存→读之后同一个机制不会再发。
- `ui` 命名空间：`{"guide": {<step>: {"shows": int, "status": "shown"|"done", "abs_day": int}}}`，只有指令 `ui.guide` 写；`ui.*` 不发事件、不发 `command_done`、不进指令日志；状态哈希、黄金种子都不含 `ui`；新局为空；读档、`game.retry_stage` 取“当前内存里的 ∪ 存档里的”（`done` 优先、`shows` 取大）。
- 查询：`firsts`；`guide_data`（步骤与规矩页的机制字段，去掉 `brief` `_provenance` `_test` `weight` `era`，外加 `settings` = `rules("guide")`；照样过隐藏键检查）；`guide_progress`；`guide_conds {ids}`（逐个算步骤的 `trigger.cond`，只回真/假）。

#### 7.10.7 界面这边：CardGuide（C16，接口冻结）

```gdscript
class_name CardGuide
extends Control                                # GuideOverlay.tscn 的根；整层 mouse_filter = IGNORE
var shown_log: PackedStringArray = []          # 测试钩子：本次运行按顺序亮过的步骤 id
var skip_fades: bool = false                   # 测试钩子：渐显渐隐、两步之间的间隔按 0 算
func bind(p_engine: CardEngineApi, p_bus: CardEventBus) -> void
func set_enabled(on: bool) -> void             # 设置开关（C16 的设置面板调；存盘由设置面板做）
func is_enabled() -> bool
func force(on: bool) -> void                   # 测试钩子：无视设置和命令行
func evaluate_now() -> void                    # 测试钩子：马上挑一次步骤（不等帧和间隔）
func active_step() -> String                   # 正在亮的步骤 id；没有为 ""
func tick(delta_s: float) -> void              # 推进计时（渐隐、超时、间隔）；平时 _process 调，测试用它走虚拟时钟
func load_steps(data: Dictionary) -> void      # 测试钩子：不经引擎直接给步骤数据（各界面任务 W1 用自己的测试步骤）
```

做法（照 `scripts/town/guide.gd` 的逻辑重写，只读不改，不拷 `data/town/onboarding.json` 的文字）：

1. **开关**：`force()` > 命令行 `--guide=on|off` > 设置 `guide_hints`。关着时什么都不亮、不发 `ui.guide`。
2. **记事**：听 `first_time`（记下机制和它的 `args`）、`command_done`（`ok` 的记 `cmd:<cmd>`）、`ui_event`（记 `ui:<name>`；`panel_opened` 另记 `panel:<kind>`）、`phase_changed`、`view_changed`（重读 `view()`）。启动和读档后用 `query("firsts")`、`query("guide_progress")`、`query("guide_data")` 重建。
3. **挑步骤**（每次事件后、`tick` 时）：没有正在亮的、离上一步结束已过 `gap_ms`、今天新亮的没到 `max_new_per_day` → 在“能亮”的步骤里挑 `priority` 最大的（同 priority 按文件顺序）。“能亮” = 没完成、亮过的次数 < `max_shows`、`trigger` 全部满足（`cond` 用 `query("guide_conds")`）、锚点或备用锚点 `CardAnchors.has()`。
4. **自动完成**：能亮的步骤，`done_when` 里某个 `first:<m>` 在它能亮之前就已经记下了（玩家已经做过）→ 不亮，悄悄发 `ui.guide done`。
5. **亮**：发 `ui.guide {step, status:"shown"}`（`call_deferred`）、`shown_log` 追加、`ui_event("guide_shown", {step})`；锚点外框发光（`CardTheme` 的 `guide_glow`）；气泡 `CardText.t("<step>#bubble")` 贴着锚点、不盖住锚点、整块在 1280×720 里、最宽 `bubble_max_w`；教的人：人物（`brother` `zhouma` `hu2` `suanming` `postman` 等）→ 没有叠层开着、对话框没显示（`CardAnchors.has(&"a.dialog")` 为假）时，在 `CardLayout.GUIDE_TEACHER` 画他的 `stage.<人物>`（没有用 `portrait.<人物>`，48×64 ×4；夜里乘 `night_tint`），一句 `CardText.t("<step>#say")` 放在 `GUIDE_SAY`；对话框显示着或叠层开着时不画站着的人，只在 `GUIDE_SAY`（叠层开着用 `GUIDE_SAY_LOW`）里放 64×64 的头像 + 那句话。物件（`obj.notice` `obj.almanac` `obj.brother_ledger`）→ 那句话写在一张批注纸上（`frame.guide_note` 九宫格，没有就 `guide_note` 色），左边是物件图标 `icon.obj.<名>`。`""` → 只有那句话。都不挡鼠标。外框每帧跟着 `CardAnchors.rect()` 走；主锚点没了换备用；都没了就快速渐隐，不算完成、不算亮过。找锚点时新旧名互认：步骤写的锚点没有，就试 `CardIds.ANCHORS_RENAMED` 里它的新名（或旧名），再试备用锚点（W1 过渡用，W2 删）。X01-b 已删新旧互认：只认步骤写的锚点和它的备用锚点。
6. **结束**：亮起之后发生了 `done_when` 里任一个 → 渐隐、`ui.guide done`、`ui_event("guide_done", {step})`。到 `seconds`：有 `timeout` 算完成，没有就算亮过一次（以后还会再亮）。被 `interrupt` 的步骤打断：快速渐隐，不算亮过。
7. **不挡**：所有节点 `mouse_filter = IGNORE`；不实现 `_input`/`_unhandled_input`/`_gui_input`；除 `ui.guide` 外不发任何指令；`autoplay_step()` 不看它。
8. **性能**：每次挑步骤 ≤ 1 ms（步骤按 `trigger.first` 预先建索引）。

**主创 10-22：照网页原型**（`docs/cards/prototype/scene_demo.html` 的 `#guide` / `.gbub`；主创试玩说“开局那些教程也没有”）。下面几条改了上面第 3、5、6、7 条和 §7.10.9 里“覆盖层每个节点 `mouse_filter == IGNORE`”，其余照旧：

- **一个气泡说整句话**：左边教的人（人物 `portrait.<人>` 取头肩 ×2，64×84，2px `guide_edge` 框；物件 `icon.obj.<名>` ×2，不加框），右上名字（界面键 `c16.guide.who.<teacher>`，`guide_who` 色），下面 `CardText.t("<step>#say")` 整句、自动换行、不截字；底 `guide_bubble`、3px `guide_edge`、圆角 12、`shade` 投影；物件老师用批注纸样（底 `guide_note`、边 `guide_note_edge`、毛笔字 18）。宽 520。`bubble` 短句不再画（数据和正文照旧保留）。原来左下角的头像和一句话条取消。
- **位置**：照锚点挑。候选依次是原型位 (444, 384)、`GUIDE_SAY` (452, 36)、右上、右中、`GUIDE_SAY_LOW` 一带……；不压住发光的锚点，也不压住**最上面那一层**里看得见的按钮（叠层或小游戏开着时只看它们的，否则看整张桌；按钮审计 b47），尽量不压对话框、选中的牌、柜台上的格子和手牌扇。手牌不是 Button 但能点：桌面和夜里时手牌扇连同悬停抬起的高度（y 380 起）按按钮算。
- **教的人站进画面**：人物老师在 `GUIDE_TEACHER` 站 `portrait.<人>` ×4（夜里乘 `night_tint`），条件是没有叠层或抽屉盖着桌面、柜台一侧没人（场景 `Cast` 层里没有他本人、也没有站 `companion` 的）、博古格上没有物件（肉鸽 v1：`CURIO` 整个在 `GUIDE_TEACHER` 里，`view.relics.count > 0` 时他不站）。气泡也躲开开着的侧抽屉（权重同按钮）；盘账叠层 `stocktake` 上只亮 `a.stock.*` 的锚点，别处的指引等叠层关了再说。原文“对话框没显示”改成这条，因为白天对话框一直显示着天气句。
- **呼吸高亮**：锚点外 2px `guide_hl_gold` + 4px `guide_hl_red`，Tween 两段各 0.6 秒循环，亮的一端外圈 14px 金光；快动画时静态。
- **两个按钮吃鼠标**：气泡右下“知道了”（`c16.guide.ok`；还有别的步骤此刻能亮时是 `c16.guide.ok_more`“知道了（还有 {n} 条）”）和“关掉指引”（`c16.guide.off`）。只有这两个 Button 是 `MOUSE_FILTER_STOP`、`focus_mode = NONE`，其余节点照旧 IGNORE；仍然不实现 `_input` 系列、不吃按键。知道了 = 这一步完成（发 `ui.guide done` 和 `guide_done`），0.3 秒后排着的下一步亮。淡出中的气泡（这一步已经收了）两个按钮立刻改回 IGNORE，不挡下一屏的点击；藏起时字清空，下次亮再向 CardText 要。关掉指引 = 马上收起、写 `settings.gd` 的 `guide_hints = false`（路径用宿主的 `settings_path`，空就不写）、画面上方飘一句 `c16.guide.off_flash`；这个选择压过 `--guide=on`。
- **不按时间收**：`seconds` 为 0 表示不计时，亮着直到点“知道了”或做了 `done_when` 里的事（K16 的步骤全是 0）。`seconds > 0` 照旧（测试步骤用）。
- **挑步骤**：每 0.25 秒心跳重挑一次（锚点后出现也能亮，不用等总线事件）；面板可以 `call_group("card_guide", "anchors_changed")` 叫它马上重挑（C09 的开月面板翻到目标页时这样叫）。叠层或小游戏开着时，指着桌面的步骤（锚点 `a.hand*` `a.card*` `a.scene*` `a.tab.*` `a.top.*` `a.btn.*` `a.dialog*` `a.counter.*` `a.slots.first/coins/…` 等）不亮、已亮的让位，只亮那一层自己的锚点（轮盘 `a.wheel.*`、小游戏 `a.mg.*`、打烊确认 `a.endday.*`、开月 `a.month.*`……）；侧抽屉盖住的桌面锚点同理。正在亮的是“自由”步骤（没有 `trigger.panel`、锚点在桌面上）时，两种步骤可以接过气泡（被换下的不算亮过，排回去）：绑着眼前面板或叠层的；它的机制在气泡亮起之后才第一次发生的。被换下、被盖住、阶段过了的步骤记为“起了头”，之后发生它的 `done_when` 也算完成。绑面板的步骤（有 `trigger.panel`）该讲的那一刻玩家已经做了它的 `done_when` 的，就不再讲（悄悄 `ui.guide done`）。阶段过了还没亮过的步骤记为跳过，`trigger.after` 认“完成或跳过”。锚点没了：亮够 2 秒算亮过一次，不够当没亮。
- **新公开方法**（PR 里列出，接口其余冻结照旧）：`acknowledge()`（知道了；按钮和自动试玩、测试都可以叫）、`is_pending() -> bool`（有气泡，或此刻有步骤能亮）、`anchors_changed()`。
- **早上自动开张**：C01 在 `guide.is_pending()` 为真（有气泡，或此刻有一步要亮；指引关着、或当天新步数到顶时为假）时一直等，不设上限；读完点知道了才开张。打烊按钮（早上是“开张”）照样随时能按，不想听的玩家自己开张。
- **新配色键**：`guide_edge` `guide_note_edge` `guide_who` `guide_hl_gold` `guide_hl_red`（开发值在 `palette.dev.json`，键名照换皮规格 §3.3）。
- **数据（K16）**：`_test.d1_3` 照新节奏改成 `gd.m.open → gd.m.wheel → gd.m.incense →（第 1 天）gd.d1.notice → gd.d1.deal → gd.d2.gold → gd.d1.person → gd.d1.close → gd.choice → gd.d1.look → gd.d1.spot → gd.d1.tiers → gd.d1.ticket → gd.d1.shelf → gd.d1.buyer → gd.d1.night → gd.d1.settle →（第 2 天）gd.d2.rules → gd.d2.keep →（第 3 天）gd.slots → gd.coins`：第 1 天早上照原型连着讲手里的牌、金框的牌（第 1 天发哥哥的交代 `p.brother.1938.tut_handover`，金框，`tutorial.json`；第 2 天的告别照旧）、来的人、打烊（`gd.d1.close` 不再等手上清空，排在当天别的指引后面）。跨阶段的 `after` 去掉，只留同一面板里的先后（`gd.m.wheel → gd.m.incense`、`gd.d1.look → gd.d1.tiers`、`gd.slots → gd.coins`）。第 1–3 天教学客人的要价让“照指引出公道价”的当 → 卖 → 买走得通（§7.10.11）。
- **测试**：虚拟时钟的走查（`C16_guide_d1_3*`、`K16_d1_3_mock`、`K14_guide_*`、`X01_guide_formal_d1_3`）只证数据和顺序，走查里“读的人”点知道了；真时钟的证据是 `C16_guide_realtime`（像发行包那样无参数启动、当作第一次启动、只用鼠标真点，不设 `skip_fades`、不调 `evaluate_now`）。

#### 7.10.8 设置、命令行、自动试玩

- `--guide=on|off`：C01 解析后交给 CardGuide；不给就按设置。`--cards-mock` 下、G06 的自动玩（根本不建界面）、K14 的 `play_ui.gd` 默认 `off`；K14 的指引走查和 C16 的测试显式打开。
- 设置面板里的“新手提示：开/关”一行（锚点 `a.settings.guide_toggle`）写 `settings.gd` 的 `guide_hints`（这个键已经存在，C16 不往 `user://settings.json` 里加新键）。
- 关着指引：不亮、不发 `ui.guide`；规矩栏照样按 `firsts` 解锁；F1 帮助照样能开。

#### 7.10.9 测试与验收

| 谁 | 测什么 |
|---|---|
| G01–G06 | 自己发的每个 first 恰好一次（第二次 `mark` 返回 false、不发信号）；存→读之后不再发；`firsts` 进哈希、`ui` 不进 |
| C01–C15 | §3.3 开头的做法：自己的锚点在夹具里 `has()`、矩形非空且在 1280×720 内；列出的 `ui_event` 发出来了（总线监听）；列出的步骤会亮（W1 用测试步骤，W2 用 K16 的 `steps.json`） |
| C16（无头，进清单） | 夹具 `guide_d1` `guide_d2` `guide_d3`（新存档第 1–3 天按教学日程会发出的事件，含 `tick`；测试场景里自己摆占位 Control 登记要用的锚点——真部件的锚点由各 C 任务自己测）：`CardGuide.shown_log` 按顺序等于 `_test.d1_3`（K16 合入前用 C16 自己照表 7.10.10 写的 21 步测试步骤，另用 `_examples/guide/steps.json` 跑一遍；K16 合入后加 `--steps=k16` 一行读真 `steps.json`）；关着时什么都不亮、不发 `ui.guide`；priority / interrupt / max_shows / 间隔 / 每天上限 / 自动完成 / 锚点消失换备用 各有单测；覆盖层每个节点 `mouse_filter == IGNORE` |
| C16（截图，不进清单） | `scripts/tests/cards/C16/shot_guide.gd`：xvfb 下每一步一张 1280×720，文件名 `<步骤 id>.png` |
| K16 | strict 模式 V29–V36 对自己的文件全绿；`_test.d1_3` 里的步骤都存在、顺序合 §7.10.10 |
| K14（W2，真引擎） | `test_guide_d1_3.gd`：种子 7、新存档、`--guide=on`，用各面板的 `autoplay_step()` 走第 1–3 天（虚拟时钟：每个 `autoplay_step()` 之后 `tick(0.5)` 再 `evaluate_now()`）：`shown_log` 按顺序等于 `_test.d1_3`；同一串指令 `--guide=off` 再走一遍，状态哈希相同；`shot_guide_d1_3.gd` 每一步一张截图，PR 附拼图 |

完成条件（§13.4）：W1 要 K16 的步骤与规矩页、C16 的指引引擎合入；W2 要 K14 的第 1–3 天测试在真引擎上绿。

#### 7.10.10 机制与步骤总表（`CardIds.FIRSTS`；节奏【待调】；K16 照它写 `steps.json`，可以加步骤，不能少机制）

教的人：`brother` 哥哥沈如松（只在第 1–2 天）· `obj.brother_ledger` 哥哥留下的账簿批注 · `zhouma` 周妈 · `hu2` 胡二 · `suanming` 算命先生 · `postman` 何启明 · `obj.notice` 告示 · `obj.almanac` 黄历 · `""` 不借人物口吻。

| 机制 | 发出者 | 什么时候算“第一次” | 步骤 | 教的人 | 锚点（备用） | 规矩页 | 节奏 |
|---|---|---|---|---|---|---|---|
| `month_open` | G02 | 第一次开月（本关目标出来） | `gd.m.open` | brother | `a.month.goals` | `rule.month` | 开局（第 1 天之前） |
| `month_wheel` | G05 | 第一次要转本月运势 | `gd.m.wheel` | brother | `a.wheel.face` | `rule.wheel` | 开局【冲突 b】 |
| `incense` | G05 | 第一次往香案上放东西 | `gd.m.incense`（`after: gd.m.wheel`，放之前先亮） | brother | `a.wheel.incense` | `rule.wheel` | 开局 |
| `notice` | G02 | 第一个早上告示出来 | `gd.d1.notice` | brother | `a.scene.notice`（`a.top.date`） | `rule.day` | 第 1 天早上 |
| `deal` | G01 | 第一次 `day.begin` 发牌 | `gd.d1.deal` | brother | `a.hand` | `rule.day` | 第 1 天 |
| `person` | G01 | 第一张人物牌进手牌 | `gd.d1.person` | brother | `a.card@{uid}`（`a.hand`） | `rule.person` | 第 1 天 |
| `counter` | G04 | 第一次打开柜台 | `gd.d1.look`，再 `gd.d1.tiers` | brother | `a.counter.look`；`a.counter.tier.fair` | `rule.counter` | 第 1 天 |
| `mg.spot` | G04 | 第一次出找不同 | `gd.d1.spot` | brother | `a.mg.spot.atlas`（`a.mg.spot.main`） | `rule.appraise` | 第 1 天（教学客人固定出找不同） |
| `ticket` | G04 | 第一张当票 | `gd.d1.ticket` | brother | `a.scene.ledger`（`a.tab.tickets`） | `rule.ticket` | 第 1 天 |
| `shelf` | G04 | 第一件东西上货架 | `gd.d1.shelf` | brother | `a.tab.shelf` | `rule.shelf` | 第 1 天 |
| `buyer` | G04 | 第一次打开来买的客人的柜台 | `gd.d1.buyer` | brother | `a.counter.stock`（`a.tab.shelf`） | `rule.shelf` | 第 1 天 |
| — | — | 第 1 天必须了断的牌都处理完了（`trigger.hand_clear`）：讲“打烊 · 下一天”随时能按、节奏你定 | `gd.d1.close` | brother | `a.btn.close_day` | `rule.day` | 第 1 天 |
| `night` | G02 | 第一次进夜里 | `gd.d1.night` | brother | `a.night.offers` | `rule.night` | 第 1 天晚上【冲突 a】 |
| `settle` | G02 | 第一次日结 | `gd.d1.settle` | brother | `a.settle.lines` | `rule.day` | 第 1 天 |
| — | — | 第 2 天早上：回看规矩（档案簿“规矩”栏、F1） | `gd.d2.rules` | brother | `a.tab.rules` | `rule.day` | 第 2 天 |
| `gold` | G02 | 第一张金色牌进手牌 | `gd.d2.gold`（教“当天必须处理、不能留”） | brother | `a.card.gold@{uid}`（`a.hand.gold`） | `rule.gold` | 第 2 天（哥哥告别） |
| `choice` | G03 | 第一次打开带选项的牌 | `gd.choice` | brother | `a.slots.choices` | `rule.person` | 第 2 天 |
| `keep` | G01 | 第一次手上有能留的牌，或第一次有牌进“留着的” | `gd.d2.keep` | brother | `a.card.keep@{uid}`（`a.hand.kept`） | `rule.kept` | 第 2 天（听哥哥交代完得 `kp.brother_note`） |
| `slots` | G03 | 第一张带格子的牌进手牌 | `gd.slots` | obj.brother_ledger | `a.slots.first`（`a.card@{uid}`） | `rule.slots` | 第 3 天（教学事件） |
| `coins` | G03 | 第一次打开带格子的面板（看到“N 枚铜钱，要 M 个正面”） | `gd.coins` | obj.brother_ledger | `a.slots.coins` | `rule.slots` | 第 3 天 |
| `almanac` | G05 | 第一个早上黄历出来（第 1 天就有） | `gd.almanac`（`stage_day_gte: 4`） | obj.almanac | `a.almanac`（`a.scene.calendar`） | `rule.almanac` | 第 4 天【冲突 d】 |
| `lot` | G05 | 第一张能求签的牌进手牌 | `gd.lot` | suanming | `a.fortune.lot`（`a.card@{uid}`） | `rule.fortune` | 第 5 天（教学算命先生） |
| `cezi` | G05 | 第一张能测字的牌进手牌 | `gd.cezi` | suanming | `a.fortune.cezi`（`a.card@{uid}`） | `rule.fortune` | 第 5 天 |
| `news` | G01 | 第一张消息牌进手牌 | `gd.news`（`stage_day_gte: 6`） | zhouma | `a.card@{uid}`（`a.hand`） | `rule.news` | 第 6 天（周妈的消息） |
| `dossier` | G03 | 第一块档案碎片 | `gd.dossier` | zhouma | `a.scene.notebook`（`a.tab.dossier`） | `rule.dossier` | 第 6 天 |
| `contact` | G03 | 第一次得到人脉 | `gd.contact` | zhouma | `a.contacts`（`a.tab.contacts`） | `rule.contact` | 第 7 天（周妈成了人脉） |
| `tier_rep` `tier_heat` | G03 | 第一次口碑 / 风声换档 | `gd.tiers`（`stage_day_gte: 7`，不等换档） | zhouma | `a.top.rep` | `rule.tiers` | 第 7 天 |
| `demand` | G03 | 第一张条子发下来 | `gd.demand` | hu2 | `a.scene.notewall`（`a.tab.demands`） | `rule.demand` | 第一个星期一（1938-03-01 是星期二，第 7 天） |
| `demand_delay` | G03 | 第一次打开条子面板 | `gd.demand_delay` | hu2 | `a.demand.delay` | `rule.demand` | 同上 |
| `demand_people_return` | G03 | 第一张“回来了吗”进手牌 | `gd.demand_people` | obj.brother_ledger | `a.card@{uid}` | `rule.demand` | 事件 |
| `demand_inform` `demand_fabricate` | G03 | 第一次打开“要消息”的条子 | `gd.demand_inform` | obj.brother_ledger | `a.demand.modes` | `rule.demand` | 事件 |
| `demand_fail` | G03 | 第一次条子到期没办成 | `gd.demand_fail` | hu2 | `a.demand.tier`（`a.scene.notice`） | `rule.demand` | 事件 |
| `shop_closed` | G04 | 第一次被查封 | `gd.shop_closed` | obj.notice | `a.scene.notice` | `rule.demand` | 事件 |
| `must_resolve` | G02 | 第一次按打烊时手上还有要了断的牌（确认之前记；步骤 `trigger.panel: "end_day"`，在确认面板上讲没处理的会怎样，§7.4.7） | `gd.must` | obj.brother_ledger | `a.endday.blocked` | `rule.day` | 事件 |
| `gold_leave` | G02 | 第一次按打烊时金色牌还没处理（确认之前记；`trigger.panel: "end_day"`） | `gd.gold_leave` | obj.brother_ledger | `a.endday.gold_leave` | `rule.gold` | 事件 |
| `fate` | G05 | 第一张命运牌进手牌 | `gd.fate` | obj.brother_ledger | `a.card@{uid}` | `rule.fate` | 第一次命运牌 |
| `life` | G01 | 第一张生活牌进手牌（几天内处理；回家吃饭能免坏处） | `gd.life` | obj.brother_ledger | `a.card.days@{uid}`（`a.card@{uid}`） | `rule.life` | 第一次（教学日不排生活牌） |
| `kept_expire` | G01 | 第一次有留着的牌过期 | `gd.kept_expire` | obj.brother_ledger | `a.hand.kept` | `rule.kept` | 事件 |
| `kept_full` | G01 | 第一次留牌满了还要进一张 | `gd.kept_full` | obj.brother_ledger | `a.slots.discard` | `rule.kept` | 事件 |
| `kept_risk` | G03 | 第一次手上有带风险的留牌 | `gd.kept_risk` | obj.brother_ledger | `a.hand.kept` | `rule.kept` | 事件 |
| `contacts_full` | G03 | 第一次人脉满了 | `gd.contacts_full` | obj.brother_ledger | `a.slots.release` | `rule.contact` | 事件 |
| `person_state` | G03 | 第一次有人受伤、被扣、走了 | `gd.person_state` | obj.brother_ledger | `a.contacts`（`a.hero`） | `rule.contact` | 事件 |
| `redeem` | G04 | 第一次有人来赎（含刁难、东西卖了要赔） | `gd.redeem` | obj.brother_ledger | `a.counter.redeem` | `rule.ticket` | 事件（当期 15 天，一般在第 16 天前后） |
| `mg.coin_ring` | G04 | 第一次出吹银元 | `gd.mg.coin_ring` | obj.brother_ledger | `a.mg.coin_ring.blow` | `rule.appraise` | 事件 |
| `mg.weigh` | G04 | 第一次出称分量 | `gd.mg.weigh` | obj.brother_ledger | `a.mg.weigh.weights` | `rule.appraise` | 事件 |
| `mg.fragments` | G04 | 第一次出拼碎片 | `gd.mg.fragments` | obj.brother_ledger | `a.mg.fragments.board` | `rule.appraise` | 事件（主线当票） |
| `mg.decode` | G04 | 第一次出解密 | `gd.mg.decode` | postman | `a.mg.decode.book` | `rule.appraise` | 事件（主线电报） |
| `market_day` | G05 | 第一个集市日 | `gd.market_day`（`stage_day_gte: 4`） | obj.notice | `a.top.weather` | `rule.day` | 第 4 天以后 |
| `weather` | G05 | 第一个不是晴天的早上 | `gd.weather`（`stage_day_gte: 4`） | obj.notice | `a.top.weather` | `rule.day` | 第 4 天以后 |
| `money_short` | G06 | 第一次钱不够付 | `gd.money_short` | `""` | `a.short.options` | `rule.ladder` | 第一次钱不够【冲突 c】 |
| `mortgage` | G06 | 第一次打开家当面板 | `gd.mortgage` | `""` | `a.estate.mortgage`（`a.tab.estates`） | `rule.ladder` | 同上【冲突 c】 |
| `big_wheel` | G05 | 第一张 `bf.wheel` 进手牌 | `gd.big_wheel` | obj.brother_ledger | `a.card@{uid}`（`a.wheel.face`） | `rule.wheel` | 第一次快输 |
| `fair_wheel` `wheel_stake` | G05 | 第一张庙会牌进手牌；第一次看到“押一张留着的牌”的代价 | `gd.fair_wheel` | obj.notice | `a.wheel.cost`（`a.card@{uid}`） | `rule.wheel` | 事件 |
| `gamble_wheel` | G05 | 第一张赌摊牌进手牌 | `gd.gamble_wheel` | `""` | `a.wheel.cost`（`a.card@{uid}`） | `rule.wheel` | 事件 |
| `street` | G06 | 第一次流落街头 | `gd.street` | `""` | `a.street.redeem` | `rule.ladder` | 事件【冲突 c】 |
| `prison` | G06 | 第一次进牢房（打点、作保、掷铜钱；没处理就多待一晚，几晚没出来就结束） | `gd.prison` | `""` | `a.prison.slots` | `rule.prison` | 事件【冲突 c】 |
| `game_over` | G02 | 第一次局终 | `gd.game_over` | `""` | `a.over.retry` | `rule.retry` | 事件 |
| `retry` | G02 | 第一次重来本关 | `gd.retry` | `""` | `a.top.date` | `rule.retry` | 事件 |
| `resume` | G02 | 第一次从续玩点接着玩 | `gd.resume` | `""` | `a.top.date` | `rule.retry` | 事件 |
| `month_close` | G02 | 第一次月底结账 | `gd.month_close` | obj.brother_ledger | `a.mclose.accounts` | `rule.month` | 月底第一次 |
| `year_jump` | G02 | 第一次跳一年（满当） | `gd.year_jump` | obj.brother_ledger | `a.year.forfeit` | `rule.year` | 第一次跳一年 |
| `year_after` | G03 | 第一块“一年后”碎片 | `gd.year_after` | obj.brother_ledger | `a.year.after`（`a.dossier.page`） | `rule.dossier` | 第一次跳一年 |
| `dossier_gap` | G03 | 第一次留缺口 | `gd.dossier_gap` | obj.brother_ledger | `a.dossier.gap`（`a.scene.notebook`） | `rule.dossier` | 事件 |
| `currency` | G04 | 第一次换币 | `gd.currency` | obj.notice | `a.top.money` | `rule.year` | 预留（首发三关不换币） |
| `branch_pick` | G02 | 解放后第一次选行当 | `gd.branch_pick` | `""` | `a.branch.list` | `rule.branch` | 预留（解放后选新行当时再教新行当的牌） |
| `office` | G03 | **1.4** 带 `office` 标签的牌第一次发到手上（官场线开头） | `gd.office` | obj.brother_ledger | `a.card.gold@{uid}`（`a.hand.gold`） | `rule.gold` | 1940 第 14 天 |
| `pet` | G03 | 猫第一次留在店里（留下或找回来的当刻，不等第二天） | `gd.pet` | obj.brother_ledger | `a.pet`（`a.contacts`） | `rule.contact` | 1938 第一关中段（第 15 天） |
| `apprentice` | K18 | 1939 第一次有人来求留下看铺 | `gd.apprentice` | obj.brother_ledger | `a.contacts`（`a.tab.contacts`） | `rule.contact` | 1939 第 11 天 |
| `scare` | G03 | 1940 起留着枪，第一次发到普通客人（不是金色、不是主线） | `gd.scare` | obj.brother_ledger | `a.card@{uid}`（`a.hand`） | `rule.kept` | 1940 |

**1.3 改了的格**（上表已经按 1.3 写；`done_when` 不在上表里，K16 照这张表改 `steps.json`）：

| 步骤 | 改哪 | 1.2 | 1.3 |
|---|---|---|---|
| `gd.d1.notice` | 锚点（备用） | `a.top.notice` | `a.scene.notice`（`a.top.date`）；`done_when` 加 `ui:hotspot_pressed` `ui:dialog_advanced` |
| `gd.d1.deal` | done_when | — | 加 `ui:hand_played` |
| `gd.d1.person` | done_when | — | 加 `ui:hand_played` |
| `gd.d1.ticket` | 锚点（备用） | `a.right.tickets` | `a.scene.ledger`（`a.tab.tickets`） |
| `gd.d1.shelf` | 锚点；done_when | `a.right.shelf` | `a.tab.shelf`；加 `panel:shelf` |
| `gd.d1.buyer` | 备用锚点 | — | `a.tab.shelf` |
| `gd.d1.night` | done_when | — | 加 `ui:hand_played` |
| `gd.d2.rules` | 锚点；done_when | `a.right.dossier` | `a.tab.rules`；`done_when` 是 `cmd:day.begin` `panel:dossier` `panel:help` `timeout` |
| `gd.d2.keep` | 备用锚点 | `a.left.kept` | `a.hand.kept` |
| `gd.almanac` | 备用锚点 | — | `a.scene.calendar` |
| `gd.dossier` | 锚点（备用） | `a.right.dossier` | `a.scene.notebook`（`a.tab.dossier`） |
| `gd.contact` | 锚点（备用） | `a.left.contacts` | `a.contacts`（`a.tab.contacts`） |
| `gd.demand` | 锚点（备用）；done_when | `a.demand.board` | `a.scene.notewall`（`a.tab.demands`）；加 `panel:demands` `panel:demand` |
| `gd.demand_fail` | 备用锚点 | `a.top.notice` | `a.scene.notice` |
| `gd.shop_closed` | 锚点 | `a.top.notice` | `a.scene.notice` |
| `gd.kept_expire` · `gd.kept_risk` | 锚点 | `a.left.kept` | `a.hand.kept` |
| `gd.person_state` | 锚点（备用） | `a.left.contacts`（`a.left.self`） | `a.contacts`（`a.hero`） |
| `gd.dossier_gap` | 备用锚点 | `a.right.dossier` | `a.scene.notebook` |
| `gd.mortgage` | 备用锚点 | — | `a.tab.estates` |

规矩页、教的人、节奏、`_test.d1_3` 都不变。§7.10.9 表里 C01–C15 那一行的“矩形非空且在 1280×720 内”照旧。

规矩页（起步 26 页，`unlock_first` 任一个出现就解锁）：`rule.day`（deal notice settle must_resolve market_day weather）· `rule.night`（night）· `rule.person`（person choice）· `rule.counter`（counter）· `rule.appraise`（mg.spot mg.coin_ring mg.weigh mg.fragments mg.decode）· `rule.ticket`（ticket redeem）· `rule.shelf`（shelf buyer）· `rule.gold`（gold gold_leave office）· `rule.kept`（keep kept_expire kept_full kept_risk scare）· `rule.slots`（slots coins）· `rule.demand`（demand demand_delay demand_people_return demand_inform demand_fabricate demand_fail shop_closed）· `rule.fate`（fate）· `rule.wheel`（month_wheel incense big_wheel fair_wheel gamble_wheel wheel_stake）· `rule.almanac`（almanac）· `rule.fortune`（lot cezi）· `rule.news`（news）· `rule.dossier`（dossier dossier_gap year_after）· `rule.contact`（contact contacts_full person_state apprentice pet）· `rule.tiers`（tier_rep tier_heat）· `rule.life`（life）· `rule.month`（month_open month_close）· `rule.year`（year_jump currency）· `rule.ladder`（money_short mortgage street）· `rule.prison`（prison）· `rule.retry`（game_over retry resume）· `rule.branch`（branch_pick）。

`_test.d1_3` 起步顺序（K16 定稿；新存档、教学日程、各面板 `autoplay_step()` 选第一个合理动作）：
`gd.m.open` → `gd.m.wheel` → `gd.m.incense` →（第 1 天）`gd.d1.notice` → `gd.d1.deal` → `gd.d1.person` → `gd.d1.look` → `gd.d1.spot` → `gd.d1.tiers` → `gd.d1.ticket` → `gd.d1.shelf` → `gd.d1.buyer` → `gd.d1.close` → `gd.d1.night` → `gd.d1.settle` →（第 2 天）`gd.d2.rules` → `gd.d2.gold` → `gd.choice` → `gd.d2.keep` →（第 3 天）`gd.slots` → `gd.coins`。

**主创的节奏和机制对不上的地方**（合同按默认做；主创 2026-10-13 已确认：“同意你说的九点”）：

- **a 夜牌**：节奏写“第 2 天（哥哥离家前）”教夜牌，可第 1 天晚上就要选夜牌。默认：哥哥在第 1 天晚上教（`gd.d1.night`）。
- **b 命运轮盘**：第一关的本月运势在第 1 天之前就要转。默认：哥哥在开局（第一关 `month_open`）教轮盘和香案（`gd.m.wheel` `gd.m.incense`）；这也就是“月初第一次”。
- **c 抵押谁教**：节奏写“教的人待定”。默认 `teacher: ""`；钱不够、街头、牢房同样先用 `""`。
- **d 黄历谁教**：没写。默认 `obj.almanac`。
- **e 哥哥走后谁讲**：节奏没点名的（放格子、命运牌、生活牌、留牌过期……）默认 `obj.brother_ledger`（哥哥留下的账簿批注；红线 4 本来就列了它）。
- **f 口碑与风声档位**：节奏排在第 4–7 天，可档位不一定在那几天变。默认第 7 天讲，不等换档。
- **g 第 3 天**：为了第 1–3 天的指引测试与种子无关，第 3 天也是脚本日（§7.10.11）。

#### 7.10.11 教学日（第一关头几天固定）

- **为什么**：第 1 天的节奏要一个来当的客人、他的东西要出找不同；可 `minigame_hint` 不约束、`c.mg.pick` 随机挑，金簪大约一半时候才出找不同。第 1–3 天的指引测试也要和种子无关。
- **`deal.json.scripted_days: {"0": [1, 2, 3]}`**：第一关第 1–3 天只发日程、钉签和队列里的牌，不随机抽（人物、事件、消息、命运都不抽；生活牌不排在这几天）【主创已确认 10-13】。
- **`data/cards/era/1938/tutorial.json`（K16）**，全部 `weight: 0` + `schedule`，id `<前缀>.1938.tut_<slug>`：
  - 第 1 天：来当 `p.<人物>.1938.tut_pawn`（`minigame: "spot"`，物品用能出找不同的模板）、来卖 `p.<人物>.1938.tut_sell`（东西进货架）、来买 `p.<人物>.1938.tut_buy`（要货架上那一类）；`order` 1–3。
  - 第 2 天：哥哥告别是 K01 的 `p.brother.1938.farewell`（金色）；外加一两位普通客人。
  - 第 3 天：带格子的事件 `ev.1938.tut_slots`（`need` 小）+ 两位普通客人。
  - 第 5 天：算命先生 `ev.1938.tut_fortune`（`opens_fortune: "both"`）。第 6 天：周妈的消息 `nw.1938.tut_zhouma`（`on_read` 补一块 `dp.zhouma` 的碎片）。第 7 天：`ev.1938.tut_contact`（周妈成了人脉，`contact_gain`）。第 4–7 天不是脚本日，照常随机抽，教学牌靠日程插进去。
- 强制小游戏只许在这种牌上（V33）；其余照旧按物品数据随机。

### 7.11 画面与演出（1.3；主创 2026-10-13 晚“画面与对话”）

主创原话：“主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体”（DESIGN §九.6）。本节规定画面的层次、坐标、各控件的冻结接口，和“一张牌怎么演”。原型：`docs/cards/prototype/`（只看做法，坐标以本节为准）。

#### 7.11.1 层次（CardGameRoot 的子节点，从下到上；C01 负责摆）

| 层 | 是什么 | 主人 |
|---|---|---|
| 0 | `CardStage` 场景层（背景、门外的街、人、工具热点、柜台上的东西与道具、效果） | C01 |
| 1 | `CardCounterChecks` 柜台上的格子与铜钱 | C03 |
| 2 | 演出层：正在演的那一个 `CardStagePanel`（自己不画大块界面，只指挥场景层、对话框、格子） | 各演出的主人 |
| 3 | `CardDialogBox` 对话框 | C04 |
| 4 | HUD（含 C07 的黄历条） | C01 |
| 5 | `CardHeroBar` 英雄头像与人脉小牌；`CardHandFan` 手牌扇与选中预览（扇在头像之上） | C02 |
| 6 | 两侧标签 | C01 |
| 7 | `CardStreetOverlay`（街头时） | C11 |
| 8 | 抽屉宿主：遮罩（点它 = 收回）+ 左/右抽屉 | C01 |
| 9 | “打烊 · 下一天”按钮（在抽屉之上，抽屉开着也能按：按下先收回抽屉再走） | C01 |
| 10 | 叠层宿主 `CardModalHost`：`shade` 遮罩 + 居中面板（可叠几层） | C01 |
| 11 | 小游戏宿主 `CardMiniGameHost` | C01 |
| CanvasLayer 100 | `GuideOverlay` 新手指引（整层鼠标穿透） | C16（C01 摆） |

拖拽中的牌影子 `top_level`，在最上面。

#### 7.11.2 坐标（`CardLayout`，W0，`scripts/cards/api/card_layout.gd`，冻结；“场景”是 320×180 的场景坐标，屏幕 = ×4）

| 常量 | 场景坐标 (x, y, w, h) | 屏幕坐标 | 说明 |
|---|---|---|---|
| `SCALE` | — | 4 | |
| `S_WALL` | 0, 0, 320, 100 | 0, 0, 1280, 400 | 墙 |
| `S_DOOR` | 112, 8, 96, 92 | 448, 32, 384, 368 | 门洞（白天/黄昏看得见街，夜里是门板）；门外走过的人裁在这里面 |
| `S_COUNTER` | 0, 100, 320, 50 | 0, 400, 1280, 200 | 柜台面；人物的下边压在 y=100 这条线上 |
| `S_UNDER` | 0, 150, 320, 30 | 0, 600, 1280, 120 | 桌下（让给手牌） |
| 站位 `customer` | 136, 36, 48, 64 | 544, 144, 192, 256 | 柜台前（立绘 ×4） |
| 站位 `companion` | 236, 36, 48, 64 | 944, 144, 192, 256 | 柜台一侧（陪同、作保的人；指引里教的人也站这） |
| 站位 `door` | 144, 36, 32, 64 | 576, 144, 128, 256 | 门口正中（行走图第一帧 ×8） |
| 站位 `door_l` / `door_r` | 128, 36, 32, 64 / 160, 36, 32, 64 | 512 / 640, 144, 128, 256 | 门口左右两个人 |
| 站位 `street` | y 66，x 116→192，16×32 | y 264，x 464→768，64×128 | 门外街上走过（行走图 ×4，6 帧/秒） |
| `S_ITEMS` | 116, 104, 88, 42 | 464, 416, 352, 168 | 柜上的东西：1 件 32×32 居中（屏幕 128×128，物品底图 ×2）；2 件并排间距 4；最多 2 件 |
| 道具位 | 见 §4.7.24 | ×4 | 道具底边中点 |
| 热点 `magnifier` | 8, 106, 30, 20 | 32, 424, 120, 80 | 放大镜 → 细看东西 |
| 热点 `abacus` | 42, 104, 52, 22 | 168, 416, 208, 88 | 算盘 → 规矩（`dossier {tab: "rules"}`） |
| 热点 `cashbox` | 6, 124, 48, 26 | 24, 496, 192, 104 | 钱匣 → 家当（`estates`） |
| 热点 `ledger` | 222, 106, 40, 26 | 888, 424, 160, 104 | 账簿 → 当票（`tickets`） |
| 热点 `notebook` | 268, 106, 40, 26 | 1072, 424, 160, 104 | 档案簿 → `dossier` |
| 热点 `calendar` | 250, 14, 24, 34 | 1000, 56, 96, 136 | 黄历 → `almanac` |
| 热点 `notice` | 84, 56, 24, 32 | 336, 224, 96, 128 | 门边的告示 → 对话框里说一遍今天的告示 |
| 热点 `notewall` | 214, 54, 18, 26 | 856, 216, 72, 104 | 墙上的条子（有没办完的条子才有）→ `demands` |
| 热点 `lamp` | 292, 68, 20, 32 | 1168, 272, 80, 128 | 油灯（只在夜里能点：点灯/熄灯，纯装饰） |
| 热点 `curio` **（肉鸽 v1）** | 237, 60, 52, 38（`S_CURIO`） | 948, 240, 208, 152（`CURIO`） | 博古格 → `relics` 抽屉（贴图 `prop.curio`，空架子）；在右墙护墙板上方，和便条墙、油灯、黄历都不压，预览按钮右边界 948 = 它的左边界（相接不重叠）；`companion` 站位与它重叠，现有数据里没有牌用 `companion`；街头、牢房时随热点一起隐藏 |
| 博古格六格 `curio_cell(i)` **（肉鸽 v1）** | 每格 16×16（框左右各 2、上下各 3） | `CURIO.position + (8 + (i % 3) × 64, 12 + (i / 3) × 64)`，各 64×64（`CURIO_CELL`）；i = 0..5，按行 3×2，越界返回 `Rect2()` | 持有的前 6 件物件按拿到的先后画在这里（32×32 底图 ×2，最近邻；RG4 的 `curio_shelf.gd`，鼠标穿透） |
| 装饰 `sign` / `door_flag` | 212, 14, 26, 34 / 96, 14, 12, 40 | 848, 56, 104, 136 / 384, 56, 48, 160 | 招牌、门旗（夜里不画；查封那天门旗换白） |
| `S_SHADOW` | 116, 30, 12, 70 | 464, 120, 48, 280 | 风声到第 3 档以上时门外的影子（白天/黄昏） |
| 格子 `S_SLOTS` | y 102，宽 40、高 30、间距 6，以 x=160 为中线，最多 4 个 | y 408，160×120、间距 24，以 x=640 为中线 | 要放格子时出现在柜台上（多于 4 个时每个宽 30） |
| 铜钱 `S_COINS` | y 133，12×12、间距 2，以 x=160 为中线，最多 14 枚 | y 532，48×48（铜钱图 16×16 ×3）、间距 8 | |
| `HUD` | — | 0, 0, 1280, 30 | 半透明一条，压在场景上 |
| `HUD_DATE` | — | 12, 3, 300, 24 | 日期 · 星期 · 第几天（锚点 `a.top.date`） |
| `HUD_WEATHER` | — | 316, 3, 100, 24 | 时辰（`stage.time` 的字）· 天气 · 集市日（`a.top.weather`） |
| `HUD_ALMANAC` | — | 420, 3, 260, 24 | C07 的黄历条（`a.almanac`）；点它开 `almanac` |
| `HUD_STATUS` | — | 684, 3, 200, 24 | 在街上 / 在牢里 / 今日查封 / 本月运势的段名 |
| `HUD_MONEY` | — | 888, 3, 120, 24 | 钱（`a.top.money`）；点它开 `estates` |
| `HUD_REP` / `HUD_HEAT` | — | 1012, 3, 124, 24 / 1140, 3, 128, 24 | 口碑、风声的**文字档**（`a.top.rep` `a.top.heat`） |
| `DIALOG` | — | x 52、y 38、宽 380；高随内容 180–482（底边 ≤ 520，`DIALOG_MAX_BOTTOM`）；柜台上有格子时底边 ≤ 404 | 对话框（`a.dialog`）。底边 520 = 手牌扇带的顶边，最大框和 `FAN`、`HERO` 不重叠（原来 ≤ 570 会压住手牌扇 60×50、头像 68×4，#139）；回话多到放不下时 C04 压低每行的高度，不往下长（框架版收尾默认，主创可改） |
| `FAN` | — | x 372–1008（中线 690），牌 144×200 | 手牌扇（§7.11.6） |
| `PREVIEW_CARD` / `PREVIEW_BTNS` | — | 496, 112, 288, 400 / 800, 360, 200, 152 | 选中一张牌时的放大与按钮（打出 / 留着 / 放回手里） |
| `HERO` | — | 12, 566, 108, 144 | 英雄头像（`a.hero`） |
| `CONTACT_MINIS` | — | (128, 610)、(206, 610)、(284, 610)，各 72×100 | 人脉小牌（`a.contacts` 是三张的外框）；多于 3 个时间距收紧，仍在 x 128–356 里 |
| `TABS_L` / `TABS_R` | — | x 0 / x 1236，每个 44×78，y = 100、184、268、352 | 左：人脉 `contacts`、条子 `demands`、档案簿 `dossier`、规矩（`dossier {tab: "rules"}`）；右：货架 `shelf`、当票 `tickets`、家当 `estates`、设置 `settings` |
| `DRAWER_L` / `DRAWER_R` | — | 0, 30, 400, 690 / 860, 30, 420, 690 | 抽屉（头一行：标题 + “合上”） |
| `END_DAY` | — | 1020, 556, 210, 92 | “打烊 · 下一天”（`a.btn.close_day`） |
| `STREET_REDEEM` | — | 1020, 452, 210, 92 | 街头时的“赎回铺面”（C11，`a.street.redeem`） |
| `OVERLAY_MAX` | — | 1100×640，居中 | 叠层面板最大尺寸 |
| 盘账叠层 `stocktake` **（肉鸽 v1）** | — | 整块 = `OVERLAY_MAX`（90, 40, 1100×640）；标题 130, 60, 1020×36；副行 130, 100；卡 288×400、间距 32、y 140，3 张时 x0 = 176、2 张时 x0 = 336；“都不要” 400, 556, 200×44；“回头再说” 680, 556, 200×44；满了“让出一件”那一排从 y 552 起 | RG4 的 `stocktake_panel.gd` / `offer_card.gd`（代码里是叠层内坐标，= 屏幕 − (90, 40)） |
| 标题 RunBox **（肉鸽 v1）** | — | 744, 400, 456, 280（底 `scene_void` 0.72） | 盒内：第几本账 y 12 · 种子框 180×32 与“换一个” y 44 · 开头 y 88（≥ 2 个开头解锁才显示）· “旧账” y 132 · 书脊 24×100、间距 4、最多 16 根、y 156，最新的在右 · 悬停 / 聚焦那根的铺史 y 260；只在外壳调了 `set_rogue()` 后出现（RG4 的 `title_run_box.gd`） |
| `GUIDE_SAY` / `GUIDE_SAY_LOW` | — | 452, 36, 480, 104 / 16, 588, 520, 116 | 指引：教的人的一句话；叠层开着时用 LOW |
| `GUIDE_TEACHER` | 236, 36, 48, 64 | 944, 144, 192, 256 | 指引：教的人站的地方（= `companion`） |

函数：`static func screen(r: Rect2i) -> Rect2`（场景矩形 × 4）、`static func spot(name: StringName) -> Rect2`（站位的屏幕矩形）、`static func prop_rect(at: StringName, base: Vector2i) -> Rect2`（道具位 + 底图尺寸 → 屏幕矩形）、`static func slot_rect(i: int, n: int) -> Rect2`、`static func coin_rect(i: int, n: int) -> Rect2`。肉鸽 v1 加 `static func curio_cell(i: int) -> Rect2` 与常量 `S_CURIO` `CURIO` `CURIO_CELL`；`S_HOTSPOTS` / `HOTSPOTS` 各加一行 `curio`（步骤 0 一次加完；`W0_stage` 照旧逐个查 `HOTSPOTS[id] == screen(S_HOTSPOTS[id])`）。

#### 7.11.3 场景层 `CardStage`（C01；接口基类 `CardStageApi`，W0）

```gdscript
class_name CardStageApi
extends Control                                    # 1280×720，铺满；空处鼠标穿透（热点和接拖放的那块除外）
signal hotspot_pressed(id: StringName)              # CardIds.HOTSPOTS 里的一个（发 ui_event hotspot_pressed {id}）
signal card_dropped(data: Dictionary)               # 有东西拖进画面（y 30–560 之间）：CardWidget 的 {"kind":"card","uid","zone"}
func refresh(view: Dictionary) -> void              # 背景（stage.set + stage.time）、天气、查封、风声影子、门外路人、热点显隐
func play(script: Dictionary) -> void               # 开演：CardStageScript.resolve() 的结果（换背景、上场、道具、效果）
func clear_play() -> void                           # 收场：人走（反向动画）、道具收、背景回到 view 的
func set_items(items: Array) -> void                # 柜上的东西 [{"item": "I004", "art": "item.jewelry.hairpin"}]，最多 2 件（锚点 a.counter.item 由 C04 登记）
func set_talking(who: String) -> void               # 正在说话的人轻轻上下动（1 场景像素）；"" = 没人
func set_dim_tools(on: bool) -> void                # 柜台上有格子时工具压暗、不能点
func spot_rect(spot: StringName) -> Rect2           # 站位的屏幕矩形（= CardLayout.spot）
```
做法：
- 视图里没有 `stage` 块（1.2 的夹具、G02 的 1.3 PR 合入之前）：一律当成 `{"set": "counter", "time": "day", "sealed": false}`；`CardStageScript.bg_id()` 也照这个兜底。CardView 没有 `stage` `source` `wheel` `fortune` `demand` 这几个键时同样当成空（`{}` 或 `""`），默认演法表照常生效。
- 背景：`CardStageScript.bg_id()`；换背景交叉淡入 0.6 秒。夜里（`stage.time == "night"`）人和柜上的东西 `modulate = CardTheme.color(&"night_tint")`，没点灯时整张再盖 `night_dark`；`set == "candle"` 时人用 `candle_tint`；`set == "prison"` 时整张盖 `cold_tint`。
- 人：站 `customer`/`companion` 的用 `stage.<who>`，没有就用 `portrait.<who>`（48×64 ×4）；站门口的用 `walk.<who>` 朝下第一帧 ×8，没有就用立绘 ×4 底边对齐；`look: shadow` 用 `silhouette` 色。白天/黄昏进柜台的人：有 `walk.<who>` 就先在门外从门边走到门中（0.6 秒）再换立绘上滑 72 像素进场（0.25 秒）；没有就只上滑。夜里不走街，直接淡入。离场反过来。
- 门外路人：`set == "counter"`、不是夜里、没查封时，按演出块的 `walk`；没写就有零星路人（只是装饰，用固定种子的 `RandomNumberGenerator`，种子 = `abs_day`）。下雨（`notice.weather == "rain"` 或 `fx` 有 `rain`）门洞里画雨丝。
- 热点：`CardIds.HOTSPOTS`（`magnifier` `abacus` `cashbox` `ledger` `notebook` `calendar` `notice` `notewall` `lamp`，肉鸽 v1 加 `curio`），用 `TextureButton`（图 `prop.<名>`，`notewall` 用 `prop.notice_wall`，夜里 `lamp` 熄灯用 `prop.lamp_off`）；`notewall` 只在 `view.demands` 不空时出现；街头、牢房的背景没有柜台工具；`set_dim_tools(true)` 时全部压暗、不能点。点了发 `hotspot_pressed`（C01 的根按 §7.11.9 转去开抽屉或交给正在演的那一出）。
- 锚点：`a.scene`（整个场景）、`a.scene.customer`（有人站柜台前时）、`a.scene.notice` `a.scene.ledger` `a.scene.notebook` `a.scene.calendar` `a.scene.cashbox` `a.scene.magnifier` `a.scene.notewall`（显示时）。

#### 7.11.4 演出 `CardStagePanel` 与默认演法 `CardStageScript`（都是 W0，Claude，冻结）

```gdscript
class_name CardStagePanel
extends CardPanel                                   # 呈现为 stage 的面板都继承它
var stage: CardStageApi                             # 宿主在 open() 之前注入
var dialog: CardDialogApi
var checks: CardChecksApi
var hand: CardHandApi
func bind_stage(p_stage: CardStageApi, p_dialog: CardDialogApi, p_checks: CardChecksApi, p_hand: CardHandApi) -> void
func begin_play(uid: String) -> Dictionary          # 取 query("card", {uid})，CardStageScript.resolve()，stage.play()，dialog.show_lines(uid, intro)；返回脚本
func end_play() -> void                             # stage.clear_play()、dialog.clear()、checks.hide_checks()、hand.set_low(false)
func on_reply(reply_id: String) -> void             # 宿主把 dialog.reply_chosen 接到这里；子类覆盖
func on_card_played(uid: String, def_id: String) -> bool   # 演着的时候又打出一张：true = 这一出接住了（例：夜里打夜牌、把留着的牌打进格子）；false = 宿主先 dismiss() 这一出再开新的
func on_hotspot(id: StringName) -> bool             # 热点交给这一出：true = 接住了（例：柜台这一出接住放大镜）
```

```gdscript
class_name CardStageScript
extends RefCounted
static func resolve(card_view: Dictionary, view: Dictionary) -> Dictionary
	# → {"uid", "def", "type", "person", "set", "cast": [{who, at, look}], "props": [{art, at}], "fx": [], "walk": "", "intro": [Line], "after": {key: [Line]}}
static func lines(script: Dictionary, key: String) -> Array     # "intro" 或 after 的键；没写的按下面的默认表
static func bg_id(script: Dictionary, view: Dictionary) -> String  # set == counter → "bg.counter.<view.stage.time>"；否则 "bg.<set>"
static func speaker(script: Dictionary) -> String               # 默认说话的人
```
Line（一句）= `{"kind": "say"|"narr"|"sys"|"me", "who": String, "ref": String, "args": Dictionary, "opt": bool}`；`ref` 是 CardText 引用（`<def>#<字段>` 或界面键）；`opt: true` 的在正文没写时跳过（§4.7.24）。

**默认演法表**（演出块没写的部分按它；写了的覆盖同一项）：

| 牌 | `cast` | `set` / 道具 | `intro` | `after` 的默认 |
|---|---|---|---|---|
| person（全部来意，含金色） | `[{who: person, at: customer}]` | 视图的；来赎时加 `prop.ticket` @ `counter_left`（柜上的东西由 C04 用 `set_items` 摆） | narr `w0.stage.enter` {name}（可省；站 `door` 时用 `w0.stage.at_door`）→ say `#lines.greet` → narr `#body` →（当/卖/买/赎）say `#lines.ask` {price}（可省） | `accept` say `#lines.accept` · `counter` say `#lines.counter` {price} · `leave` say `#lines.leave` → narr `w0.stage.leave` · `refused` say `#lines.refused` → narr `w0.stage.leave` · `impatient` say `#lines.impatient`（可省） · `<选项 id>` narr `#outcomes.<id>`（可省） · `success`/`fail` narr `#outcomes.success`/`#outcomes.fail` |
| event / fate / big_fate / street / prison | `[]`；带 `opens_fortune`（牌视图 `fortune` 不空）的事件 `[{who: "suanming", at: customer}]` | 视图的（prison 牌在视图 `set == prison` 时就是牢房） | （cast 第一位站 customer/door*/companion 时）say `#lines.greet`（可省）→ narr `#body` | `<选项 id>` narr `#outcomes.<id>`（可省）· `success`/`fail` narr `#outcomes.success`/`fail` · `pass` narr `#outcomes.pass`（可省）· `lot`/`cezi` 无（C07 自己说签诗、测字） |
| life | `[]` | 视图的 | narr `#body` | 同上 |
| news | `source` 不空 → `[{who: source, at: customer}]`；否则 `[{who: "ex_newsboy", at: door}]` | 视图的 | say `#lines.greet`（可省）→ narr `#body` | `read`、`keep` 无 |
| demand | `[{who: "hu2", at: customer}]` | 视图的；`prop.notice` @ `counter_mid` | say `#lines.issue` → narr `#body` | `success`/`fail` narr `#outcomes.success`/`fail` · `delay` narr `#outcomes.delay`（可省） |
| pawn_ticket | `[]` | 视图的；`prop.ticket` @ `counter_mid` | narr `#body` | `read` 无 |
| night | `[]` | `counter`（夜里）；演出块可换 `candle` `post` 等 | narr `#body` | `done` narr `#outcomes.done`（可省） |

（“say”的说话人：person → 它的 `person`；demand → `hu2`；news → `source` 或 `ex_newsboy`；其余 → `cast` 第一位。）

**一出戏怎么走**（所有 `stage` 面板一样）：
1. C01 的根收到“打出”（手牌扇 `card_played`、拖进画面 `card_dropped`、键盘 1–9 + Enter）：夜里 → 交给正在演的 `night` 这一出的 `on_card_played`；白天有一出正在演 → 先问它 `on_card_played`，false 就 `dismiss()` 它；然后 `query("card", {uid}).panel`，`none` 不演，否则 `host.open_panel(panel, {uid})`。打出一张牌**不发指令**。
2. 宿主实例化面板 → `bind(engine, bus)` → `bind_stage(...)` → `open(args)`；面板在 `open` 里调 `begin_play(uid)`（人上场、对话框开说），再做本来要做的事（例：柜台 `counter.open`）。
3. 句子说完，面板 `dialog.set_replies([...])` 列回话；玩家选一句 → `on_reply(id)` → 发指令 → 按结果 `dialog.show_lines(uid, CardStageScript.lines(script, <结果键>), true)`。
4. 要放格子的：`checks.show_checks(uid)`、`hand.set_low(true)`、`stage.set_dim_tools(true)`、`dialog` 底边 ≤ 404；回话里有“掷铜钱”；掷了用 `checks.play_coins(faces, need)`。
5. 收场：这张牌 `card_left(uid)` 或阶段变了 → 面板 `close_requested.emit({})`；宿主先 `end_play()` 再释放。一次只演一出。
6. `autoplay_step()`：对话框还有没说完的句子 → `dialog.skip()`；否则走和玩家一样的 `on_reply(id)`；同一状态永远做同样的事。

#### 7.11.5 对话框 `CardDialogBox`（C04；接口基类 `CardDialogApi`，W0）

```gdscript
class_name CardDialogApi
extends Control                                     # 位置 CardLayout.DIALOG；没有句子、没有回话时隐藏
signal advanced(index: int)                         # 推到下一句（点一下、Space、Enter；发 ui_event dialog_advanced {uid}）
signal lines_done                                   # 这一批都显示完了
signal reply_chosen(reply_id: String)               # 选了一句回话（发 ui_event reply_chosen {uid, reply}）
var chars_per_sec: int = 40                         # 逐字速度；0 = 一下子显示完（快动画、测试、自动试玩）
func show_lines(uid: String, lines: Array, append: bool = false) -> void   # Line 见 §7.11.4
func set_replies(replies: Array) -> void            # Reply 见下；空数组 = 没有回话
func clear() -> void
func skip() -> void                                 # “跳过”：直接显示到这一批最后一句（发 ui_event dialog_skipped {uid}）
func is_idle() -> bool                              # 没在打字、没有剩下的句子
func has_replies() -> bool
func set_max_bottom(y: int) -> void                 # 520（默认，`CardLayout.DIALOG_MAX_BOTTOM`；给更大的值按 520 算）或 404（柜台上有格子）
func current_uid() -> String
```
Reply（一句回话）= `{"id": String, "ref": String, "args": Dictionary, "enabled": bool, "reason_ref": String, "style": "choice"|"tier"|"look"|"roll"|"wheel"|"later", "anchor": String, "echo": bool}`：`ref` + `args` 是这句回话的字（`CardText.t`）；`enabled: false` 灰着、下面一行小字 `reason_ref`；`style` 决定前面的记号（◆ 选项与三档价、◇ 细看、▶ 掷铜钱与去转轮盘、· 回头再说）；`anchor` 不空时对话框替回话的主人用 `CardAnchors.register(anchor, 这个按钮)` 登记（回话清掉时注销）；`echo`（默认 true）= 选了以后先把这句话以 `me` 显示出来。
样子：`frame.dialog` 九宫格 ×2（没有就 `dialog_bg` 的 StyleBox）；顶上名字条（说话人 `CardText.person_name(who)`，`dialog_name` 色，22 号标题字）+ 右上角“跳过 ▸▸”（`a.dialog.next`）；正文 18 号，一次显示一句，逐字出现，右下角 ▼ 表示点一下继续；上一句“你说的”小字留在顶上；`narr` 不带名字条、`sys` 小字（`dialog_sys` 色，只放看得见的数：正面几个、要几个）、`me` 带“沈如花”名字条（`dialog_me` 色）。正文里空一行就拆成两句。说话的人 → `stage.set_talking(who)`。

#### 7.11.6 手牌扇 `CardHandFan` 与英雄头像 `CardHeroBar`（C02；接口基类 `CardHandApi`、`CardHeroApi`，W0）

```gdscript
class_name CardHandApi
extends Control
signal card_played(uid: String, def_id: String, how: StringName)  # how: &"drag" &"button" &"key" &"auto"（发 ui_event hand_played {uid, def, how}）
signal card_selected(uid: String)                   # 点一下 = 选中放大（发 ui_event hand_selected {uid}）
func refresh(view: Dictionary) -> void
func set_low(on: bool) -> void                      # 柜台上有格子时整排往下让 56
func set_away(on: bool) -> void                     # 日结说话时整排收到屏幕下面
func select_index(i: int) -> void                   # 1–9 键（0 起）
func play_selected() -> bool                        # Enter
func play_uid(uid: String) -> bool                  # 自动试玩用：和“打出”按钮走同一条路，how = &"auto"
func card_rect(uid: String) -> Rect2
```
- 排什么：白天 = `view.hand`（**严格按引擎给的顺序**，金色牌在最左）+ `view.kept`（接在后面，带“留”角标和剩几天 `expires_in`）；夜里 = `view.night_offers`（每张拼成 `{uid: "", def, type: "night", zone: "night", art}`）+ 一张“睡了”（`{uid: "", def: ""}`，界面键 `c02.night.none`）；别的阶段空。
- 扇形：n 张、中线 x=690；间距 = n>1 ? min(115, 492/(n−1)) : 0；第 i 张 t = (i − (n−1)/2)/max(1,(n−1)/2)；转角 = t × min(6, 2 + 1.2n) 度（以牌的底边中点下方 80 像素为轴，`pivot_offset = (72, 280)`）；顶边 y = 544 + round(16·t²)（牌下面 24 像素出屏）。悬停：顶边升到 380、转回 0°、放到最上面；`set_low(true)` 再往下 56；`set_away(true)` 顶边 760。
- 打出：拖出扇区到画面（交给 `CardStage.card_dropped`，由 C01 的根判断）或选中后点预览旁的“打出”（`c02.btn.play`）；留着的牌、人脉、头像拖进柜台上的格子由格子接（`slot_drop`）；能留的牌在预览里多一个“留着”（`action_requested(uid, "keep")`，C01 发 `card.keep`）。
- 英雄头像：`frame.hero` 108×144（没有就 `hero_ring` 色的 StyleBox）里是 `portrait.ruhua` 的上半截 ×2、名字、四项属性点数（看得见的数）、“今天用过了”的戳（`used_today`）；拖出去是 `{"kind": "self"}`。人脉小牌：`CardWidget` `&"mini"`，拖出去是 `{"kind": "card", "uid", "zone": "contacts"}`；不在的（`away_days > 0`）灰着、显示天数。点头像或人脉 → `person_pressed(uid)`（C01 开 `contacts` 抽屉）。
```gdscript
class_name CardHeroApi
extends Control
signal person_pressed(uid: String)                  # 你自己 = view.self.uid
func refresh(view: Dictionary) -> void
```
- 锚点（C02）：`a.hand`（整排扇的外框）、`a.hand.gold`（第一张是金色牌时那张）、`a.hand.kept`（留着的牌那几张的外框；没有就不登记）、`a.hand.preview`（预览里的“打出”）、`a.hero`、`a.contacts`；每张牌照旧 `a.card@<uid>` 等（CardWidget 自己登记）。

#### 7.11.7 柜台上的格子与铜钱 `CardCounterChecks`（C03；接口基类 `CardChecksApi`，W0）

```gdscript
class_name CardChecksApi
extends Control                                     # 摆在柜台那一条（屏幕 y 400–600）；空处鼠标穿透
signal changed                                      # 放进 / 拿出以后（演出据此刷新“掷铜钱 · N 枚 · 要 M 个正面”那句回话）
signal coins_finished(success: bool)
func show_checks(card_uid: String) -> void          # query("slots", {uid})，按 CardLayout.slot_rect 摆 CardSlotWidget；没有格子就不摆
func hide_checks() -> void
func is_shown() -> bool
func preview() -> Dictionary                        # 最近一次 query("slots") 的 {coins, auto_heads, need, auto_pass, ready}
func play_coins(faces: Array, need: int) -> void    # 在铜钱那一排播 CardCoinTossView
func skip_coins() -> void
```
- 每个格子 160×120：格子名、放进去的东西（小图 + 给几枚铜钱）、“拿出来”；收钱的格子上有 −/＋（每次加减 `money_per_coin` 的钱，C03 的键 `c03.money.minus` `c03.money.plus`）。铜钱那一排：掷之前显示 N 枚背面朝上的铜钱和“要 M 个正面”（数字可以显示，红线 3）。
- 锚点（C03）：`a.slots.first`（第一个格子）`a.slots.coins`（铜钱那一排）`a.slots.money`（第一个收钱格子的 −/＋）；`a.slots.roll`、`a.slots.choices` 是回话上的锚点（C03 的演出在 Reply 里写 `anchor`）。
- `coins_finished(success)`（#209，X01-b 补明）：铜钱播完（或 `skip_coins()`）时发一次；`success` 和引擎 `coins_tossed` 的成败同一个算法——最近一次 `preview()` 的 `auto_pass` 为真，或 `faces` 里的正面数 + `auto_heads` ≥ `need`。签名不变；接收方可以照旧用引擎给的成败。

#### 7.11.8 抽屉与标签（C01 摆框，内容是各主人的面板）

- 标签：左右各 4 个（§7.11.2）；图标 `icon.tab.<名>`（24×24，没有就字），竖排两三个字（界面键 `c01.tab.<名>`）；角标（看得见的数）：条子数（有剩 1 天的用 `danger`）、当票数、货架 `n/上限`、人脉旁边是留着的牌数。锚点 `a.tab.contacts` `a.tab.demands` `a.tab.dossier` `a.tab.rules` `a.tab.shelf` `a.tab.tickets` `a.tab.estates` `a.tab.settings`。
- 点标签 = `host.open_panel(kind, args)`（规矩 = `dossier {tab: "rules"}`）；同一时间只开一个抽屉，开另一个先收回这个；点遮罩、“合上”、Esc = 抽屉面板的 `dismiss()`。宿主开/关抽屉时发 `ui_event panel_opened/closed {kind, show}`，另发 `drawer_opened/closed {kind, side}`。
- 抽屉面板就是普通的 `CardPanel`（`open/refresh/autoplay_step/dismiss`），尺寸是抽屉框里面那块（左 368×630、右 388×630，框内边距 16、标题行 44）；`autoplay_step()` 看一眼就关（返回 true 一次）。

#### 7.11.9 热点转到哪（C01 的根）

`ledger` → `tickets` · `notebook` → `dossier` · `calendar` → `almanac` · `cashbox` → `estates` · `abacus` → `dossier {tab: "rules"}` · `notewall` → `demands` · `notice` → 对话框空着时说一遍今天的告示（`view.notice.news` 每条一句 narr，`ref` 就是那个键；X01-b：元素是裸键（Mock、§7.5 的例子）或真引擎的 `{key, args}`，后者 `ref = key`、`args` 原样交给 `CardText`，不把字典原样显示）· `magnifier` → 先交给正在演的那一出 `on_hotspot(&"magnifier")`（柜台那一出：能细看就 `mg.request`），没人接就什么都不做 · `lamp` → 夜里点灯/熄灯（纯画面）· `curio`（肉鸽 v1）→ `relics`（`CardIds.HOTSPOT_PANELS` 通用路由）。HUD 上点钱 → `estates`，点黄历条 → `almanac`；点头像或人脉 → `contacts`。

#### 7.11.10 HUD（C01）

一条 1280×30，`hud_bg` 半透明压在场景上，字 15 号 `hud_ink`；格子见 §7.11.2。日期用本任务的键（参数 `{y} {m} {d} {weekday} {day} {days}`）；时辰 `c01.hud.time.<day|dusk|night>`；天气 `g05.weather.<天气>`、集市 `c01.hud.market`；状态 `c01.hud.status.<street|prison|sealed>`，本月运势 `c01.hud.fortune`（参数 `{seg}` = `<段 id>#title`）；钱是数字 + 币种键；口碑、风声**只有五档文字**（`g03.tier.rep.<0–4>` `g03.tier.heat.<0–4>`）。

#### 7.11.11 “打烊 · 下一天”（C01）

位置 `END_DAY`，在抽屉之上、叠层之下（叠层开着时它被 `shade` 盖住，关掉叠层就回来）；**任何阶段都能按**，做法照 §7.4.7（`day.end {confirm:false}`，要确认就开 `end_day`；局终时开局终面板）。按下时先收回抽屉、正在演的那一出不用先收（打烊后它的牌会走，`card_left` 到了它自己收场）。字：主行 `c01.btn.close_day.<step>`（`step` 取 `day.end_preview` 的 `step`：`end_day` `skip_night` `next_day` `open_day` `begin_month` `month_next` `year_next`；局终 `c01.btn.close_day.game_over`），白天第二行 `c01.btn.close_day.left`（参数 `{n}` = 手上 `must_resolve` 的牌数）或 `c01.btn.close_day.done`；没有要了断的牌时用 `btn_day_ready` 色，确认清单开着时 `btn_day_confirm`，夜里 `btn_day_night`。

#### 7.11.12 不变的

引擎接口、指令、查询、CardBus 信号、`CardPanel`、`CardMiniGame`、`CardAnchors`、`CardGuide` 的冻结签名一个不改；1.2 的“打烊 · 下一天”、所有面板都能关、引擎要的面板每个只自动开一次，照旧。

---

## 8. 小游戏插件接口（h）

### 8.1 接口与宿主

```gdscript
@abstract
class_name CardMiniGame
extends Control
signal finished(result: Dictionary)
@abstract func kind() -> StringName
@abstract func start(params: Dictionary) -> void          # 只用 params 搭局面；不读引擎、不读存档
@abstract func autoplay(skill: float) -> void              # 0.0–1.0；用和玩家一样的代码路径自己玩完（测试、自动试玩用）
func abort() -> void                                       # 玩家关掉：finished({quality_permille: 0, observations: [], minutes: minutes_spent(), measures: {}, aborted: true})
func minutes_spent() -> int
```

约定（10-25 鉴定改版；**不进基类**，基类和宿主不改）：每个小游戏都有
```gdscript
func apply_op(op: Array) -> bool   # 唯一改局面的入口；op 里只有整数和短 ASCII 串（坐标先量化成物品图 / 板面的整数像素）；不合法返回 false、什么都不改
func ops_log() -> Array            # 执行过的 op，按顺序（深拷贝）
```
鼠标、键盘、自动玩、测试都化成 op 走 `apply_op`；同一份参数 + 同一串 op → 同一个结果字典（连 `measures`、`minutes`、`quality_permille`）。`autoplay(skill)` 的 `skill` 读作“**每个判断判对的概率**”：第 i 个判断 `JevRng.draw(params.seed, "c.mg.<kind>.layout", [9000 + i]) < skill` 判对，否则按 `[9100 + i]` 定怎么判错，然后照样 `apply_op`，最后 `["done"]`。宿主的 `autoplay_current(skill)` 签名不变；牌桌自动走的 0.8 = 八成判对。

结果：
```json
{"quality_permille": 820, "observations": ["obs.weigh.light_small"], "minutes": 6, "measures": {"read_fen": 291}, "aborted": false}
```
- `quality_permille` 0–1000 的整数：**过程分**，只决定观察清不清楚、旁白的口气（G04 先乘修正项 `appraise_pct`，再按 `economy.json.appraise`：≥ 700 清楚、≥ 350 一半、其余含糊【待调】），**不决定真假**。10-25 起只许用玩家在屏幕上看得见的过程算（翻没翻图鉴、用没用放大镜、两枚样洋听没听过、按“看星”那一刻秤平不平、拼齐了没有），**不许用“判对了几个”**。小游戏内部可以用浮点算，交出来的一律是整数（结果会进指令日志）。
- `quality_permille` 不影响价格；**说破会影响价格（主创 10-25）**：玩家的判断对不对由 G04 拿 `measures` 私下对答案（`CardAppraisal.judge`），来当 / 来卖的会话里第一次没放弃的鉴定结算一次——说中了真破绽客人改口让价，冤枉了客人他不服、耐心掉一截、底价抬高（§3.2 G04）。对错的数不回给界面，`report` 的返回值仍只有 `{ok, err, observations}`。
- `observations`：观察**键**，来自本小游戏的观察目录（§4.8），正文由人写。10-25 起观察是**玩家自己的判断**（判错的照样交），外加少量描述键（“拼完了能看清当字”）。**永远不返回判词**；引擎**绝不按对错过滤**（一过滤，留下的就等于“真的”）。
- `minutes`：花掉的钟点，引擎从客人耐心里扣（§9 之外的唯一副作用）。每个判断性动作扣钟点，摆弄（换工具、转碎片、翻页、拨砝码）不扣或少扣；没有真实时间的倒计时。
- `measures`：玩家的原始操作（整数、布尔、整数数组；格式见 §8.2），只给引擎判分和自动玩用，不显示；**不放对错**。键避开 §7.5 的黑名单（不叫 `pins` `weights` `weight` `verdict` 之类）。小游戏里不给对错反馈：不变色、不打钩、不写“还剩几处”；玩家做的记号一律用玩家的笔的颜色（`gold_hi`），不用 `good` `bad` `danger` `seal`。

流程：柜台那一出里点“细看”回话或柜台上的放大镜 → `send("mg.request", {uid, item})`（当票、电报这类没有物品的牌：`{uid}`，用牌上的 `minigame`）→ 引擎发 `minigame_requested(uid, item, kind, params)` → C01 的 `CardMiniGameHost` 按下表实例化、`start(params)` → 玩家玩 → `finished(result)` → 宿主 `send("mg.report", {uid, item, result})` → 引擎把观察（玩家的判断）记到物品上、私下对答案、扣耐心，会话里第一次鉴定结算说破 → 柜台面板刷新（对话框念完观察，客人接一句 `line_key` 里的 `g04.counter.lever.*`，三档价跟着新开价变）。

| kind | 场景 | class | 主人 | 首发 |
|---|---|---|---|---|
| `spot` 找不同 | `res://scenes/cards/minigames/spot/SpotGame.tscn` | `CardSpotGame` | C12 | ✓ |
| `coin_ring` 吹银元 | `res://scenes/cards/minigames/coin_ring/CoinRingGame.tscn` | `CardCoinRingGame` | C13 | ✓ |
| `weigh` 称分量 | `res://scenes/cards/minigames/weigh/WeighGame.tscn` | `CardWeighGame` | C14 | ✓ |
| `fragments` 拼碎片 | `res://scenes/cards/minigames/fragments/FragmentsGame.tscn` | `CardFragmentsGame` | C15 | ✓ |
| `decode` 解密 | `res://scenes/cards/minigames/decode/DecodeGame.tscn` | `CardDecodeGame` | C15 | ✓（主线） |

（对印章、闻摸不在首发；留 kind 名 `seal`、`sniff`。）每个小游戏登记锚点 `a.mg.<kind>.main` 和自己的工具锚点（§7.10.5），用到工具时发 `ui_event("mg_tool", {kind, tool})`。

### 8.2 参数（引擎 → 小游戏；只有**物理量**和摆设）

公共字段：`{"kind": "weigh", "seed": <int>, "item": "<物品 id 或空>", "art": "<美术 id>", "minutes_per_step": 1, "max_minutes": 30}`。`seed` 由 G04 用 `c.mg.param [item_id, kind, "seed"]` 抽（`int(u × 2147483647)`）。

| kind | 专有参数（10-25 新加的粗体；小游戏缺新参数时用保守默认，照旧能玩完） | 结果 `measures`（10-25 起） |
|---|---|---|
| `spot` | **只有布局和证据的样子**：`parts: [{"id": "authenticity", "rect": [x, y, w, h], "tool": "eye"/"lens"}]`（部位在物品图上的整数矩形、哪种工具看得出；**不画出来**）；`marks: [{"part", "kind": "differs"/"wear", **"look"**: FlawRender 画法名, **"at": [x, y, w, h]**（这一处痕迹在物品图上的小矩形，痕迹只画在这里）, "fine": 0–1000（≥ 500 只在镜片里看得见）, "seed": int}]`——每件固定 3 处、每部位至多一处，`authenticity` `provenance` 一律各一处，真货假货一样多；**`legend: {"wear": [look…], "differs": [look…]}`**（本品类的图例：“用旧了常见” / “不该有的”，品类知识，同品类每件一样；有懂行的人脉时给全）；`atlas_art`（图鉴图）；`atlas_open`（10-25 起 false：要自己翻开）；`ink:int`（墨 = 3 + 眼力 / 2，猫 +1）；**`lens_px:int`**（镜片半径，屏幕像素）；**`blink:bool`**（能“按住对照”）；`tools:[…]`。不给 ItemGen 的物品字典、不给 `tell`/`benign`/`fake_text`/`real_text`/`est` | `spots: [[x, y, tag], …]`（物品图像素；tag 1 旧痕、2 不一样；最后留着的图钉）`ink_used:int` `atlas:bool` `lens:bool`（旧：`strokes` `hits`） |
| `coin_ring` | `coins: [{"id": "a", "ring_ms": 1350, "pitch_cents": -40, "buzz": 12}]`（客人的，1–5 枚；一摞时 `id` 依次 `a` `b` …）；`reference: {"ring_ms", "pitch_cents", "buzz"}`（标准声 = 足银样洋，兼容老参数）；**`samples: [{"id": "good", …}, {"id": "dull", …}]`**（铺子的足银样洋、哑板样洋；先足银后哑板）；`tries:int`（吹次 = 4 + 眼力 / 2，猫 +1）；**`ghosts:int`**（最多留几道余音淡影）；**`clink:bool`**（能相碰，两枚以上） | `blows` `clinks` `marks: [0/1/2…]`（一摞：0 没定、1 响、2 哑）`call:int`（单枚：1 像足银、2 像哑板、3 说不好）`listened_ms` `compared:bool` `clinked:bool` |
| `weigh` | `tool: "dengzi"/"steelyard"`；`claimed_fen:int`（客人说的分量）；`actual_fen:int`；`weights_fen:[…]`（手边的砝码，每个模板都配得平）；`resolution_fen:int`；**`small_fen:int`**（“轻一点点”的上限，品类规矩）；**`zoom:int`**（星点放大倍数）；**`minor_ticks:bool`**（每个分度一个小星）；**`needle_gain:int`**（定盘针放大） | `read_fen`（最后一次“看星”时秤砣 + 砝码指示的分量）`steps` `commits:int` `call:int`（1 对得上、2 轻一点点、3 轻了不少、4 反倒重了、5 说不好） |
| `fragments` | `doc: "pawn_ticket"/"scroll"/"letter"`；`pieces:int`；`seal_offset_px:int`；`ink_mismatch:[piece]`（异纸的碎片下标）；`dangzi_marks:int`（当字笔画处数）；`missing_piece:int`（-1 没缺）；**`stain:int`**（水渍那一块的下标，-1 没有；真假都可能有）；**`rotate:bool`**（散开时转着）；**`lens_px:int`**；**`backlight:bool`**（能“对着光看”） | `placed` `rotations` `seal_checked:bool` `seams: [[a, b], …]`（打了叉的拼缝，a < b，排序）`seal_call:int`（1 对得上、2 错开了） |
| `decode` | `cipher: "telegraph"/"ledger"`；`message: "<消息 id>"`；`codes: ["5120", …]`（真码，来自牌上的 `decode.codes`）；`book_words:["cb.word.5120", …]`（兼容）；**`book: [[code, key], …]`**（整本电码本按码排好；小游戏不再自己读文件）；**`smudges: [[g, d, alt], …]`**（第 g 组第 d 位洇了；`alt` 是看成另一个数时要查的码，已经减过加码，多半也是本子里有的码）；**`key_shift:int`**（加码 0–9，0 = 明码；电报上显示每位 + k 再取个位）；**`crib:str`**（扉页上的本号；加了码时电报第一组是本号加码） | `decoded` `lookups` `picked: [码或 −1, …]`（每组抄的码，整数）`key:int` |

- 键都避开 §7.5 的黑名单（视图、事件参数里递归检查；`minigame_requested` 只放过 `params.seed` 和 `params.marks[i].seed`）；`measures` 也一样。
- G04 的判分（只进私账）：spot 每个图钉找 `at` 外扩容差（粗 2、细 1 像素）含它的那处——说“不一样”而那处是 differs 算说中，是旧痕或哪处都不沾算冤枉，说“旧痕”而是旧痕算说中旧痕，说“旧痕”而是 differs 不算；coin_ring 说哑而坏算说中、说哑而好算冤枉；weigh 说轻了不少 / 反倒重了而答案相同算说中、答案是对得上 / 轻一点点算冤枉，说轻一点点而答案也是算说中旧痕；fragments 打叉的缝有一边是异纸算找到（每块一次）、两边都不是算冤枉，骑缝印说错开了而偏了算说中、没偏算冤枉；decode 每组抄对算对、抄错算错。漏看不算冤枉（漏看的代价是你自己被骗）。
- **禁用键**（`CardAppraisal.FORBIDDEN_PARAM_KEYS`；G04 的测试对每个物品、每种小游戏的参数递归检查，**没有例外**）：`fake` `real` `genuine` `authentic` `forged` `stolen` `origin` `market` `value` `true_value` `floor` `tell` `benign` `fake_text` `real_text` `est` `verdict` `rare` `grade` `quality`。
- 物理量由 G04 按 K11 的规格（`it.*`）和物品真值算出，抽签用 `c.mg.param`。证据真假**同分布**：凡是数得出来的（痕迹几处、在哪个部位、一摞几枚、几道缝有字）真货假货一样，只有样子（痕迹画法、余音音色、星点、墨色和接口、洇字）跟着真值变；干扰（旧痕、旧洋、水渍、轻一点点）真假都有。
- 辅助（10-25）由 G04 按眼力（`CardMeters.attr(ctx, "ruhua", &"eye")`，0–6）、懂行的人脉（`appraise_pct` 高于 `appraise.expert_pct`）和店里的猫算好放进参数，小游戏不读引擎：墨、镜片、按住对照、吹次、淡影、放大、小星、针、对光、少洇几个字；公式在 `economy.json` 的 `appraise.aids`。
- 小游戏内部的随机（碎片怎么撕、砝码怎么摆）只用 `JevRng.draw(params.seed, "c.mg.<kind>.layout", [i])`——种子参数是 `params.seed`，键只有 `[i]`（§6.3）。
- 同样的 `params` + 同样的操作 → 同样的结果。
- 不许在小游戏里出现“真”“假”“仿”“赝”等判词（文字由人写，观察键目录的 brief 也不写判词；K15 的词表会查）。找不同不用旧的 `appraise_panel.gd`（它按 `tell` 着色、数剩几处、有“我看这是假货”勾选），C12 分出自己的 `spot_panel.gd`（§3.3 C12）。
- 小游戏面板不超过 1100×640，键盘可玩（Esc = `abort()`）。无头运行不报音频错误（Dummy 驱动）。

---

## 9. 命运轮盘与算命接口（i）

### 9.1 轮盘的视图与数学（G05）

视图 `query("wheel", {"wheel": "wh.month", "uid": ""})`：
```json
{
  "wheel": "wh.month", "uid": "", "kind": "month", "art": "wheel.month",
  "segments": [
    {"id": "ws.1938.month.caixing", "arc_deg": 64.8, "art": "icon.ws.caixing"},
    {"id": "ws.1938.month.liunian", "arc_deg": 43.2, "art": "icon.ws.liunian"}
  ],
  "incense": {"accepts": ["money", "kept", "contact"], "placed": [{"kind": "money", "amount": 10}, {"kind": "contact", "uid": "c0012"}], "full": false},
  "cost": {"money": 0, "stake": false}, "staked": "",
  "spun": false, "result": {"segment": "", "stop_deg": 0.0}
}
```
- 扇区按数据顺序从指针处（12 点钟方向）顺时针排开。只给 `arc_deg`（画图用），**不给权重、份数、好坏**。界面不写任何数字。段的 `conditions` 在算视图和转的时候查，不满足的段这次不上盘（不出现在 `segments` 里）。
- 份数 U：香火钱 ÷ `money_per_unit`（向下取整）+ 每张留着的牌的 `incense_units`（默认 1）+ 每个人脉的 `contact_attr` 属性点；U ≤ `max_units`。
- 权重（整数）：好段 `w = arc × (100 + U × unit_widen_pct)`；其余 `w = arc × 100`。`arc_deg = 360 × w / Σw`。所以放得越多，好段越宽、其他段按比例变窄。
- 转：`u = ctx.draw("c.wheel." + wheel_id, [abs_day, uid, spin_no])`，按权重用 `JevRng.weighted_choice` 选段——这里的 rows **按扇区的显示顺序（数据顺序）排，不按 id 排序**；于是 `stop_deg = 360 × u` 正好落在选中段的角度范围里（界面按它缓停，看到的和结果一致）。存档存 `stop_mdeg`（千分之一度整数）。
- 香案上的东西：香火钱转之前付掉；留着的牌用掉；人脉当天算用过（不消耗）【待调】。转之前可以 `wheel.withdraw` 拿回来。

### 9.2 三种转法

| 转法 | 怎么来 | 流程 | 结果 |
|---|---|---|---|
| ① 本月运势 `wh.month` | `month_open` 钩子里 G05 调 `CardDayLoop.request_panel(ctx, &"wheel", {"wheel": "wh.month", "uid": "", "required": true})` | 开月过场 → 轮盘（可放香案）→ `wheel.spin` → 段的正文 → `month.begin` | `fate.month_segment` = 段 id；段的 `month_mods` 作用整关（G05 的权重读它）；段的 `effects` 立刻执行 |
| ② 大轮盘 `wh.big` | 危机（§DESIGN 三.6 的触发，`fate.json` 的阈值）→ G05 发 `bf.wheel`（每关上限、同一危机一次；大命运**只发这一张**）；牌在手上，`panel: "wheel"` | 点牌 → 轮盘（可放香案）→ 转 | 落在翻身／平安／坠底的某一段：执行段的 `effects`（常见是发一张 v1 的“大赌”牌到手上） |
| ③ 庙会/赌摊 `wh.fair` `wh.gamble` | 事件牌带 `opens_wheel` 和 `cost`；或效果 `wheel_offer` 发的系统牌 `ev.any.wheel_go`（`vars: {wheel, cost}`） | 点牌 → 付钱（`wheel.spin` 时扣）或 `wheel.stake` 押一张留着的牌 → 可放香案 → 转 | 段的 `effects`；押的牌：落在 `bad` 段没了，否则还回来【待调】 |

扇区内容随年代变：段的 `era` 决定这一关有哪些段（`wh.big` 允许 `["*"]` 的通用段 + 当年的段）。

### 9.3 求签（G05）——签为什么“准”

`fortune.lot {uid}`（`uid` 是算命摊之类的事件牌）：

1. 付 `cost`（牌上写的钱）。
2. 窗口 W = `fortune.json.lot.window_days`【待调，起步 3】。对 d = 明天 … 明天 + W − 1：候选 = `CardComposer.project(ctx, d)` 的随机部分 ∪ 已经钉住的 ∪ 日程上那天要发的。只取 event、fate、person、life、news、big_fate 类型、且带 `omen_*` 标签的牌（V34 保证前五类都带）。
3. 挑 `pick` 张（起步 2）写进签：按 `c.lot.pick` 抽，每张的抽中权重 = 100；**本心 ≤ `conscience_harsh_below` 时，`valence: bad` 的（人物牌、事件牌没有 valence，按标签 `bad_omen`，W0 在 `tags/W0.json` 声明）乘 `harsh_bias_pct`**——本心越低越先听到坏消息。
4. 等第：挑出来的牌里坏的多 → 低；好的多 → 高；一好一坏 → 中（具体映射写在 `fortune.json`）。
5. 选签：同等第里 `hint_tags`（只用 `omen_*`）和挑出来的牌的 `omen_*` 标签有交集的签，按 `c.lot.verse` 抽一支；没有就用同等第的泛泛签。
6. **钉签**：`CardPins.pin(ctx, d, def, "lot:<n>")`。到了第 d 天，CardComposer 先发钉住的牌（占它所属牌库的名额；名额满了或那个牌库今天是 0 就额外发，§7.4.6）；那天它的 `conditions` 不满足（人走了），就用 `c.deal.sub` 在同牌库里挑一张**标签有交集**的替身——签说的征兆照样应验。同牌库里没有合法的同征兆替身（都不满足条件，或被禁签挡掉），就照发原来钉住的那张，不让签落空、也不报错（框架版收尾默认，主创可改）。
7. 返回 `{lot, grade}`；视图的 `lots` 里记一行。**哪几张牌、哪天来都不进视图**。

所以签永远“准”，玩家只看到人写的签诗和解曰（含糊的征兆）。

测字 `fortune.cezi {uid, char}`：`query("fortune")` 给出今天这个摊上摆的 `cezi.offer` 个字（`c.cezi.offer [abs_day, uid]` 抽）。玩家挑一个：窗口里有带这个字 `tags`（`omen_*`）的牌 → 读法 `has`，并把那张牌钉住；没有 → `none`，并给窗口里的每一天加**禁签** `CardPins.ban(ctx, d, 字的 tags, "cezi:<n>")`：那几天随机抽和找替身都跳过带这些标签的牌，所以“无”也一直是真的（日程、主线、效果点名发的牌不受影响；正文本来就含糊，不说死）。正文：`cz.<id>#has` / `#none`（人写，含糊）。

`peek` 效果（小丁“提前看明天一张事件”）也走 `project` + 钉签，所以看到的一定会来。

### 9.4 黄历（G05）

- 每天早上 `c.almanac [stage, stage_day]` 从当年、当季的 `almanac_day` 里按权重挑一条，进 `view.notice.almanac`（宜、忌的动作名；正文用界面键 `g05.almanac.<动作>`）。
- 动作怎么记：处理牌的模块调 `CardPiles.resolve(ctx, uid, outcome, {"almanac": [动作…]})`，`card_resolved` 钩子参数里就带上 `almanac`；选项、夜牌数据里的 `almanac` 字段；G04 自动记 `pawn_in`（收当成交）`buy_in`（收货成交）`sell_out`（卖给来买的人）`redeem`（赎当）`trade`（任何柜台成交）`lend`（押家当、借钱给人）；G05 自己记 `pray`（往香案上放东西）；G03 记 `meet`（把人脉放进格子）。
- 日结：今天**做了至少一样宜的、没做任何忌的** → 执行那条黄历的 `reward`（小好处）；否则什么都不发生（不罚）。
- 界面只显示宜忌和“今天做过的”小勾（玩家自己做过的事，不是隐藏信息）。

---

## 10. 金色角色牌的实现（j）

1. **数据**：`type: "person"`、`gold: true`、`story_node` 必填、`keepable` 不能为 true、`effects.on_expire` 里必须有 `{"op": "story", "node": <同一节点>, "outcome": "ignored"}`（或别的“没理他”的走向名）和至少一个 `dossier_gap`。校验器 V13 查。一般 `weight: 0` + `schedule`。
2. **发牌与顺序**：CardSchedule 在节点那天把它交给 CardComposer。手牌顺序只由 G01 的 `CardPiles.order_hand()` 定：先按 `deal.json.hand_order`——**金色牌 > 牢房 > 大命运 > 事件 > 命运 > 人物 > 生活 > 消息**【主创已确认 10-13】——同一类里按修正项 `hand_sub`（G02 的 `CardGoldRule.hand_sub`：金色牌给 `schedule.order`），再按发到手上的先后（`seq`）。每次往手牌里加牌（发牌、`add_card`、`extra_deal`、`arrest` 的牢房牌）之后都调它，所以任何牌都排不到金色牌前面；被抓时牢房牌排在金色牌之后、其他牌之前。G02 没有挪牌的钩子。
3. **不能留**：`card.keep` 对它返回 `not_keepable`；视图里 `keepable: false`；界面不显示“留着”。
4. **处理**：和普通人物牌一样（`intent: "story"` 走选项面板 `slots`；也可以是当/卖/赎等来意走柜台）。处理完照常 `CardPiles.resolve`。
5. **打烊**（1.2 起，§7.4.7）：`day.end` 不再被任何牌挡住。按“打烊 · 下一天”时金色牌还在手上：清单里它是 `kind: "gold_leave"` 的一行（`consequence_key` = `<def>#outcomes.ignored`，人写的“不理他他就走了”），和别的没处理的东西一起等玩家确认；确认后 `day.end {confirm: true}`。
6. **走掉**：`day_end` 钩子 10 里 `CardGoldRule.leave(uid)`：发 `card_left(uid, &"gold_left")`，执行 `on_expire`（主线按“没理他”记下、档案页留缺口），牌进弃牌。`loop.gold_left` 记一笔，日结报告里有一行（人写的正文键 `g02.settle.gold_left`）。
7. **之后**：主线后续的牌用条件 `{"story": ["<节点>", "ignored"]}` 走另一条路；`CardDossier` 里那块碎片是缺口，永远补不上，档案簿里画成撕掉的样子（C10）。
8. **测试**（G02）：金色牌在手牌第一位（被抓、加发之后也是）；`card.keep` 被拒；有金色牌时 `day.end {confirm: false}` 返回 `must_resolve_pending`、清单里有它那一行、状态不变（只记 first），`confirm: true` 后前进；`story` 与缺口正确；第二天手牌里没有它；读档后同样；第一次进手牌发 first-time `gold`，第一次打烊时它在清单里发 `gold_leave`。
9. **新手指引**：哥哥告别那张金色牌在第 2 天，由 `gd.d2.gold` 讲“当天必须处理、不能留到明天”；第一次带着金色牌按打烊时，`gd.gold_leave` 在确认面板上讲“不理他他就走了”（§7.10.10）。

---

## 11. 来源与审核：免 AI 声明（k）

### 11.1 什么算“玩家消费的内容”

游戏里、商店页、预告片、宣传图里一切看得见、听得见、读得到的：正文、界面文字、人物名字、签诗、观察句、物品名、美术（含牌框、图标、配色）、音乐、音效。**代码、测试、工具、数值、数据结构、`brief` 不算**（但 `brief` 不进发行包，§11.4）。

### 11.2 AI 能放占位的地方（只有这些）

| 占位 | 位置 | 规则 |
|---|---|---|
| 设计说明 | 数据里的 `brief`、`_doc`、`_meta.brief`（含演出块 `stage` 里每个 cast、prop、拍子的 `brief`） | 干巴巴的说明：谁、什么事、选项、后果、史实依据。不写成能直接用的台词、文案、签诗；不写引号里的对白；演出块只写 id、站位、道具、效果和对白的键（`ref`），不写对白本身 |
| 占位美术 | `art/_placeholder/**`（K12 生成器产出） | 每张左上角带“稿”角标；`art/_placeholder/cards/manifest.json` 记生成器名和种子；导出排除 |
| 占位音频 | `audio/_placeholder/**`；或运行时合成 | 运行时合成只在 `CardShip.is_ship() == false` 时允许 |
| 开发版显示 | `CardText` 的草稿回退 | 只在非发行版且开发开关开着（`--show-drafts`，2026-10-22 起默认关、缺字给空串）；显示时带【稿】标记（字样在 `data/cards/_dev/strings.json`）和草稿样式 |
| 开发配色 | `data/cards/theme/palette.dev.json`（W0） | 只在非发行版读；正式配色 `palette.json` 只有 A 建 |
| 新手指引 | 步骤与规矩页的 `brief`（K16） | 同“设计说明”；`say` `bubble` `title` `body` 只有 A 写 |

AI 不许：写 `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`；在 `.gd` 里写中文字符串字面量（`scripts/cards/**` 下字符串字面量只许 ASCII；中文注释可以）；在 `scenes/cards/**/*.tscn` 里写中文（在编辑器里填进 `text`、`tooltip_text`、`placeholder_text` 的字也算）；在 `scripts/cards/ui/**`、`scripts/cards/minigames/**` 里写颜色字面量（`Color("#…")`、`Color(r, g, b)`；`Color.WHITE`、`Color.TRANSPARENT`、`Color(1, 1, 1, a)` 这类调透明度的除外）。

### 11.3 人做的内容怎么登记

- 正文：覆盖层每一条带 `"_provenance": "human:A:YYYY-MM-DD"`（剧情、牌面、签、观察句、人物名、物品文字）或 `"human:B:…"`（界面文字）。
- 美术、音频：`legal/ASSET_PROVENANCE.csv` 每个发行文件一行：`path, sha256, author, method, source_file, license, license_file, order_no, no_ai_proof, date, reviewer`（同交付计划）。分层源文件、工程文件不进仓库的发行路径。
- 配色：`palette.json`（只有 A 建）的 `_meta._provenance` 为 `human:A:…`。
- 遗留内容：v0.4.2 的 `art/items/**`、`art/portraits/**`、`audio/music/**`、`data/town/item_templates.json` 的文字、`data/cast.json` 的名字、`data/codebook.json` 的词、`data/town/onboarding.json` 与 `rules.json` 的文字、`scripts/town/**` 等旧脚本里的中文都是 AI 产出，卡牌版一律当**占位**（美术清单里 `legacy: true`；名字、物品文字、电码本的词走覆盖层；新手指引重写）。发行版引用到它们 = 审核失败；旧版目录不进 Steam 包（§2.3）。

### 11.4 K15 的审核（`tools/cards/audit/audit.py`，任何一项不过就非零退出、不许出包）

> **W2（2026-10-18，#202 / #212）两种出包与 AI 来源统计**：这一版先跑通全 AI 管线（`art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**`），每个 AI 产物登记 `_provenance: "ai:<工具>:<模型>:<日期>:<提示词或任务 id>"`（美术兼容 `ai:google-<工具名>:<日期>:<提示词 id>`；AI 台词 `data/cards/text_ai/**` 要求严格五段文件级 `_meta._provenance`；AI 音乐清单登记在 `data/cards/audio/music.json`，AI 音效清单固定在 `audio/ai/sfx/manifest.json`）。K15 审核工具把 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**` 记为**“AI 生成、需声明”**，按类别与来源（`_provenance`）统计并列出全部 AI 产物；`stage_ship.py` 与 `audit.py` 支持两种变体：`--variant=ai-disclosure`（带 AI 声明版，默认）与 `--variant=no-disclosure`（不带声明版 / 仅人工，缺人工资源或含 AI 资源即报错）。人做的资源放 `art/cards/**`、`audio/cards/**`、`data/cards/text/**` 会自动顶替同 id 的 AI 资源。

1. 暂存目录（`stage_ship.py` 产出）里没有：任何 `brief` / `_doc` / `_meta.brief` / `_test` 键，以及骨架上的 `_provenance` 对象（只保留正文、配色 `_meta` 与清单中登记的字符串 `_provenance`，含 `audio/ai/sfx/manifest.json`）；`art/_placeholder/`、`audio/_placeholder/`、`data/cards/_examples/`、`data/cards/_dev/`、`data/cards/theme/palette.dev.json`、`data/cards/rules/wording.json`、`data/cards/branch/`、`scripts/tests/`、`tools/`、`docs/` 下的文件；§2.3 列的旧版目录。不带声明版（`--variant=no-disclosure`）中也不许出现 `art/ai/`、`audio/ai/`、`data/cards/text_ai/`（`audio/ai/sfx/manifest.json` 中的音效条目在 stage 时剥去 `ai`/`_provenance` 并写入 `data/cards/audio/sfx.json`，强制要求对应人工音效）。
2. 用 `validate_main.gd --mode=ship` 跑数据：`data/cards/text/**` 里每一条 `_provenance` 必须是 `human:(A|B):YYYY-MM-DD`；带 AI 声明版中 `data/cards/text_ai/**` 的每个文件 `_meta._provenance` 必须为严格五段格式 `ai:<工具>:<模型>:YYYY-MM-DD:<提示词或任务 id>`（与 `CardDB._load_ai_text` 一致，拒受四段、缺文件 `_meta._provenance` 或条目冲突来源，且 `CardValidator` 同步传播 `db.errors()`）。
3. 每个被引用的美术 id 与音频条目（`data/cards/audio/music.json` 及 `audio/ai/sfx/manifest.json` / `data/cards/audio/sfx.json`）：人做的 `art/cards/**` / `audio/cards/**` 存在时优先采用并核对 `ASSET_PROVENANCE.csv`（`sha256`、作者在 `human_authors.json`、非 AI `method`）；人做的不存在时，不带声明版直接报错，带 AI 声明版查清单 `ai` 路径（`art/ai/**` / `audio/ai/**` 下文件存在且 `_provenance` 为合法 `ai:...`）；没有 `legacy: true` 的未覆盖引用。
4. 发行包里的每个图片、音频文件：不在 v0.4.2 的哈希黑名单里；人工路径文件在 `ASSET_PROVENANCE.csv` 里（白名单）；`art/ai/**`、`audio/ai/**` 下的文件在不带声明版中报错，在带 AI 声明版中必须在清单里登记合法 `ai:...` 来源并记为“AI 生成、需声明”。
5. **发行包里每一个** `.gd` `.json` `.tscn` `.tres`（不只 `scripts/cards/**`）：`data/cards/text/**`（及带声明版的 `data/cards/text_ai/**`）以外不许有 CJK，除非在 `tools/cards/audit/cjk_allowlist.json`（Claude 维护）里逐个文件写了原因（例：`scripts/sim/item_gen.gd`、`scripts/core/ledger.gd` 里从不显示的内部字；`data/town/item_templates.json` 的旧名字——发行版显示走 `items.text.json`）；界面脚本没有颜色字面量（唯一例外：`scripts/cards/ui/common/card_theme.gd` 读配色文件时用 `Color.html` 把十六进制串转成颜色，登记在 `audit.py` 的 `COLOR_PARSE_EXCEPTIONS`，只放过这一个文件里的 `Color.html(`，同一文件里别的颜色字面量照查；`CardTheme.color()` 缺键时开发版 `push_error`，两种版本都退回配色键 `mist`，发行版不出洋红——#74，框架版收尾默认，主创可改）；没有调用运行时占位音频合成的代码路径在 ship 特性下可达（静态检查 `CardShip.is_ship()` 守卫）；旧版曲目只在 `!is_ship()` 下引用。
6. 正文里没有判词（`tools/cards/audit/verdict_words.json`，只查观察句、签、测字的正文）；正文（含指引步骤、规矩页、F1 帮助）里没有 `%`；措辞检查（调用 K13 的 `wording_lint.py`）没有“必须改”。
7. 字体覆盖：发行正文里用到的每个字都在两个字体子集里（K15 用 Python 标准库读两个子集字体的 `cmap` 表；不 import `tools/build_fonts.py`——它依赖第三方 `fontTools`）。
8. `data/cards/theme/palette.json` 存在，且 `_meta._provenance` 是 `human:A:…`（发行版不许退回开发配色）。
9. 导出后（§11.6）对 `.pck` 的文件清单再跑一次第 1 项和第 4 项。
10. 报告写到 `docs/cards/audit/last_audit.md`（时间、提交号、出包变体、每项结果、按类别与来源统计的全部 AI 产物清单）。

### 11.5 PR 路径检查（`tools/cards/audit/check_pr_paths.py <base> <head> --author=<PR 作者>`）

- **谁算 AI**：PR 作者的 GitHub 账号不在 `legal/human_authors.json`（A、B 的账号，人维护）里的，一律按 AI 线查——不看分支名，也不信数据里自己写的 `human:…` 字样。AI 线的改动里出现 `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**` → 失败。AI 产物路径 `art/ai/**`、`audio/ai/**`、`data/cards/text_ai/**` 登记在 `ownership.json` 的 `ai_paths` / `paths.ai`，AI 线可写。
- 改动路径不在 `docs/cards/ownership.json` 里这个任务名下（加上每个任务默认拥有的四类路径与 `ai_paths`）→ 失败，列出越界文件。
- 人写的分支用 `content/<主题>`（A）和 `ui-text/<主题>`（B），只许改人写路径。
- `.github/CODEOWNERS`（W0）：`data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**` 的 code owner 是 A/B 的账号，这些路径没有他们的 review 合不进去。
- `check_pr_paths.py`（参数 `--author=<PR 作者>`）和 `run_card_tests.sh` 在 W0 就接进 CI（`.github/workflows/cards.yml`），并在集成分支上设成**必过检查**（required status）；Claude 审每个 PR 时也再跑一遍。

### 11.6 出包流程（`tools/package_steam.sh`）

支持两种出包变体：`--variant=ai-disclosure`（带 AI 声明版，预设 `"Steam (AI Disclosure)"`，特性 `ship,ai_disclosure`）与 `--variant=no-disclosure`（不带声明版 / 仅人工，预设 `"Steam (No AI Disclosure)"`，特性 `ship,no_ai`）。流程：`stage_ship.py <staging> --variant=<变体>` → `validate_main.gd --mode=ship`（在暂存目录上）→ `audit.py <staging> --variant=<变体>` → `godot --headless --path <staging> --export-release "<预设>" <输出>`（**从暂存目录导出**，不从仓库导出——从仓库导出会把每个 `brief` 带进包；Steam 预设只含卡牌版、带 `ship` 特性，§2.3）→ 列出导出的 `.pck` 里的文件，再跑一次第 1 项（没有 brief、占位、例子、旧版目录；不带声明版没有 `*_ai` / `art/ai` / `audio/ai`）和第 4 项（每个图片、音频都在来源清单或 AI 清单里）。任何一步失败，脚本非零退出。Steam 接入（成就、云存档、商店页素材清单）由 Claude 在 W2 做。

---

## 12. 测试、代码风格、性能预算（l）

### 12.1 测试怎么登记、怎么跑

- 每个任务把自己的测试放 `scripts/tests/cards/<ID>/`，在 `scripts/tests/cards/suites/<ID>.txt` 里登记，一行一个：
  ```
  # 名字|脚本|超时秒|参数
  G03 铜钱数与正面|res://scripts/tests/cards/G03/test_slots.gd|120|
  G03 条子七天与拖一拖|res://scripts/tests/cards/G03/test_demands.gd|120|--seeds=20
  ```
- `tools/run_card_tests.sh`（W0，Claude）：先 `--import`，再跑数据校验（default 模式；W2 起 strict），再按文件名顺序读所有清单，并行跑每个脚本：`timeout <秒> $GODOT --headless --path . -s <脚本> -- <参数>`；日志里有 §0 第 7 条的任何一行、退出码非零、或**最后一行不是** `CARDS TEST PASS <名字>` → 失败。`GODOT` 环境变量指向 Godot 4.7，`JOBS` 控制并行。`tools/run_tests.sh` 末尾调用它（W0 加）。**谁都不改 `run_tests.sh`、`run_card_tests.sh`、`run_legacy_smoke.sh`。**
- **并行不抢文件**：每个测试的 `user://` 子目录由 `card_t` 按名字给（`user://test/<名字>/`，开头建、结束删）；存档根（`CardSave.set_root()` / `new_game` 的 `save_dir`）和设置文件路径（`settings.gd` 构造时传）都指过去。任何测试不许碰 `user://cards/`、`user://settings.json`。
- **校验器登记进清单**：那一行的名字不带空格，参数里 `--name` 和它一样，例：`K01_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/era/1938/people.json,data/cards/era/1938/story.json --name=K01_validate`。
- **PR 里跑什么**：`tools/run_card_tests.sh` 全量 + `tools/run_legacy_smoke.sh`（W0 写的旧版冒烟，几分钟内跑完，证明没碰坏旧游戏）。全量 `tools/run_tests.sh` 由 Claude 在合并时跑——38 条线每条都跑全量旧测试太慢。
- 测试脚本模板（`scripts/tests/cards/lib/card_t.gd` 由 W0 提供）：
  ```gdscript
  extends SceneTree
  const T = preload("res://scripts/tests/cards/lib/card_t.gd")

  func _initialize() -> void:
  	var t := T.new(self, "G03 铜钱数与正面")
  	var bus := CardEventBus.new()
  	var eng := CardEngine.new(bus)
  	t.ok(eng.new_game({"seed": 7, "only_examples": true}).ok, "new_game")
  	# … t.eq(a, b, "说明") / t.ok(cond, "说明") / t.no_leaks(eng.view())
  	bus.free()
  	t.finish()      # CardText.setup(null)、CardAnchors.clear()、删掉本测试的 user:// 目录（免得退出时报泄漏）；打印 CARDS TEST PASS <名字> 或 FAIL: … ，然后 quit(0/1)
  ```
  需要等帧的界面测试用 `t.run_async(func(): …)`（库里处理 `await process_frame`）。库里还有：`t.user_dir()`（本测试的 `user://` 目录）、`t.find_floats(v)`（返回所有浮点值的路径）、`t.spy(bus)`（记下总线上所有信号，含 `ui_event`）、`t.anchor_ok(id)`（锚点有面积且在 1280×720 内）。
- 测试要**确定**：同样的提交跑一百遍结果一样；不许依赖墙钟、不许 sleep。

### 12.2 每类任务必须有的测试

| 任务 | 必须有 |
|---|---|
| G01–G06 | 每个公开函数的单测；自己登记的每个效果/条件 op 的正例和形状反例；**确定性**（同种子同指令两遍哈希一样）；**存读一致**（任意阶段存→读→继续，哈希一样）；用到的随机域都在 §6.3；状态里没有浮点（`find_floats`）；自己发的每个 first-time 恰好一次、存读后不再发 |
| G02 | 视图隐藏键递归检查（每个基础夹具状态 + 三关浸泡途中每天）；三关无头跑通；`day.end` 每个阶段都前进、预览 = 结算（§7.4.7） |
| G04 | 账本守恒；小游戏参数禁用键检查 |
| G05 | 签的准确性（1000 种子）；轮盘单调与停针一致 |
| G06 | 钱不够阶梯、抵押、街头、牢房各有单测；每个策略三关不卡死；**`G06_no_deadlock` 模糊测试 ≥ 1000 局**（随机指令 + 随机打烊 + 随机存读，§7.4.7 第 4 条）；黄金种子回放 |
| C01–C16 | 用 Mock + 自己的夹具：场景能实例化、`bind` 后各状态渲染不报错；点按钮/拖拽发出的指令和参数对（断言 `mock.sent`）；`autoplay_step()` 能把自己的流程走完；键盘操作；`CardViewModel.leaks()` 不适用于界面，但界面上显示的每段文字都来自 CardText（库里的 `t.all_text_from_cardtext(node)` 遍历 Label/RichTextLabel/Button，断言每段非空文字要么 `CardText.issued_contains()` 为真，要么只由数字和标点组成）；**新手指引**：自己的锚点、`ui_event`、指引步骤（§3.3 开头）；**1.3**：自己的演出 / 抽屉 / 控件用画面根 `CardGame.tscn` + 夹具测（主人还没合入的控件由 `CardIds.widget_scene()` 取 W0 的桩顶上）：打出一张牌后断言 `panel_opened {kind, show}`、对话框的句子都来自 CardText（`t.all_text_from_cardtext` 也扫对话框和回话）、回话发出的指令（`mock.sent`）对、`autoplay_step()` 能演完；锚点用 `CardLayout` 的矩形断言在对的位置（`t.anchor_in(id, rect)`） |
| C16 | 新手指引：`guide_d1`–`guide_d3` 夹具对 `_test.d1_3`；开关；priority / interrupt / max_shows / 间隔 / 每天上限 / 自动完成 / 备用锚点各一个单测（§7.10.9） |
| C12–C15 | 同参数同操作同结果；结果里没有不在目录里的键；结果是整数 `quality_permille`；10-25 起：**判断往返**（`autoplay(1.0)` 交回的判断全对、`autoplay(0.0)` 全错、`0.5` 介于两者，用和 G04 `judge` 同规则的测试判）、**op 回放**（A 实例 `autoplay(x)` → `ops_log()` → B 实例逐个 `apply_op` → 结果字典逐键相等；`x` 取 0.0/0.3/0.8/1.0）、**不露底**（界面文字不出现观察键正文和“%”，只出现允许的数；判对判错两局节点颜色集合一样）、**纯鼠标**走通一局、**老参数**（mock 旧形状）能玩完；工具 `scripts/tests/cards/lib/mg_ops.gd` |
| K01–K11、K16 | 校验器 default 模式对自己的文件全绿（清单里登记一行调用 `validate_main.gd -- --only=<自己的路径> --name=<本行名字>`）；数量达标的统计测试（脚本数自己的牌）；K16 另加 strict 模式 V29–V36 |
| K12 | 生成器两次输出字节相同；清单覆盖检查 |
| K13 | 措辞检查对夹具里的正反例 |
| K14 | Mock 上的整套界面走查能跑完；W2：真引擎第 1–3 天的指引走查、开关指引哈希相同 |
| K15 | “坏包”夹具逐项报错；好包通过 |

### 12.3 界面截图

- 无头（`--headless`）下 Control 布局能跑，但不能截图。截图用 `xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -s <截图脚本> -- --out=<目录>`（参考现有 `scripts/tests/shot_walkin.gd` 的做法：等 4 帧 + `RenderingServer.frame_post_draw` 后存 viewport 图）。
- 界面任务的 PR 附 1280×720 的**画面截图**：整个画面（场景 + HUD + 手牌扇 + 头像 + 标签 + 打烊按钮），自己的东西在画面里该在的地方——演出：人上场后、对话说到一半、回话列出来、检定时柜台上的格子与铜钱、结果；抽屉：打开时（画面在后面）；叠层：盖在画面上。每个任务要拍的清单在任务卡“10-13 变更二”一节。环境里没有 xvfb 就在 PR 里说明，由 K14/Claude 补拍。截图脚本不登记进清单。
- 新手指引**每一步**一张画面截图：C16 的 `shot_guide.gd`（Mock 夹具）、K14 的 `shot_guide_d1_3.gd`（真引擎），文件名 `<步骤 id>.png`，PR 附拼图；截图里看得见教的人站在柜台一侧（或批注纸）、锚点发光、气泡。

### 12.4 性能预算

| 项 | 预算 |
|---|---|
| `CardDB.load_all`（首发全部数据，约 600 张） | ≤ 300 ms（无头） |
| 校验器全量 | ≤ 2 s |
| 普通 `send()` | ≤ 2 ms；`day.begin`（发牌 + 钩子）≤ 10 ms；`settle.next` ≤ 10 ms |
| `project(d)` | ≤ 3 ms；`fortune.lot` ≤ 15 ms |
| 无头自动玩一关（30 天） | ≤ 1.5 s；三关 ≤ 5 s |
| 平衡跑（200 种子 × 3 策略 × 3 关，JOBS=6） | ≤ 10 分钟 |
| 存档文件 | ≤ 512 KB；写 ≤ 50 ms |
| 界面 | GL Compatibility、1280×720；场景层（背景 + ≤ 8 个人 + 9 个热点 + 道具 + 效果）+ 15 张手牌 + 对话框逐字，集显 60 fps；开一出演出 / 开抽屉 / 开叠层面板 ≤ 50 ms；实例化一张 CardWidget ≤ 1 ms；空闲时 `_process` 不分配内存（逐字、门外路人、说话的人上下动都不在 `_process` 里建字典、数组、拼字符串） |
| 小游戏 | 每帧 CPU ≤ 4 ms |
| 新手指引 | 每次挑步骤 ≤ 1 ms；覆盖层空闲时 `_process` 不分配内存 |
| 内存 | 整个游戏 ≤ 400 MB |
| 占位美术 | 总量 ≤ 20 MB |

### 12.5 黄金种子（G06）

- `scripts/tests/cards/golden/golden.json`：`{"cases": [{"seed": 7, "policy": "fair", "data": "examples", "days": 30, "hashes": [{"abs_day": 10, "hash": "…"}, …]}]}`。
- W1 只用 `_examples` 数据（`only_examples: true`），不受内容改动影响；W2 起加真数据的用例，**每次合入数据或规则 PR 后由 Claude 重算**（`balance_main.gd --update-golden`），PR 里写原因。
- 引擎任务的 PR 让黄金哈希变了：必须在 PR 里解释为什么变（行为改了还是 bug），不许悄悄更新。G06 以外的任务**不改** `golden.json`（它归 G06）：`G06_golden` 因此变红时，在 PR 里解释、加标签 `golden-change`；Claude 审核同意后在该 PR 分支上追加一个只改 `golden.json` 的提交（`--update-golden`）再合并。
- 哈希不含 `ui`（§6.1），所以新手指引开不开都不影响黄金种子；`firsts` 在哈希里（它是引擎状态，和指引开关无关）。

### 12.6 平衡报告的指标（G06）

每策略 × 每关：过关率；局终原因分布（牢房、……）；月底钱的中位数/10%/90%；口碑、风声档位分布（每天）；条子按类 × 档的完成/拖延/失败；抵押了几件、流落街头比例与天数、爬回来比例；牢房次数与出来比例；大命运（大轮盘）次数与三类扇区分布；命运牌好坏比例；每天手牌张数分布；格子检定：按“铜钱数 − 要的正面”分组的成功率；签的准确率（必须 100%；验收靠 G05 的离线测试 `G05_lot_accuracy_a`–`_d`（`scripts/tests/cards/G05/test_lot_accuracy.gd`，种子 0–999 各求 3 签，每支签钉的牌或同征兆替身都要来）。公开门面不暴露签钉了哪几张牌，平衡报告只经门面跑，所以报告里的 `lot_accuracy` 可以是 `verified: 0`、`rate: null`，这不算不合格，也不能写成“100%”——#41；框架版收尾默认，主创可改）；黄历照做率；每关用时（步数）。`refuser` 策略的作用是证明“什么都不做也不会卡死”（它每天只按 `day.end {confirm: true}`）。

### 12.7 代码风格

- GDScript 4.7；**静态类型**（变量、参数、返回值都写类型）；Tab 缩进；行宽 ≤ 120；文件名 snake_case，class_name `Card` 开头的 PascalCase（只有冻结表里的类写 class_name，§0）；私有成员 `_` 开头；常量全大写。
- 引擎代码：`RefCounted`；不 `await`；不碰场景树；不读输入；函数 ≤ 80 行，超过就拆；字典遍历先排序；整数运算算钱；`push_error` 只用于程序错误（会让测试失败），玩家操作不合法返回错误码。
- 界面代码：不放规则；文字、颜色、图都走 CardText / CardTheme / CardArt；动画用 Tween；`queue_free` 清理；不在 `_process` 里每帧 `view()`（收到 `view_changed` 再读）。
- 每个文件开头两三行中文注释：这个文件干什么、主人任务号、参照合同哪一节。
- 字符串字面量只许 ASCII（§11.2）；开发者日志和错误信息用英文。
- 不加第三方插件、GDExtension；Python 工具只用标准库（K12 可用 Pillow，K15 只用标准库）。
- 不写网络访问；游戏代码只写存档根目录（默认 `user://cards/`）、`user://settings.json`（只经 `settings.gd`）、`user://cards/settings.json`（C16）和测试输出目录。

---

## 13. 分支、PR、合并波次（m）

### 13.1 分支与提交

- 从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切 `cards/<ID>-<slug>`；做的过程中用 `git rebase origin/claude/festive-ride-vud32a` 跟上，不留合并提交。
- 提交信息用中文写清楚做了什么（参照仓库现有风格：一句话摘要，空一行，要点列表）。
- 一个 PR 只做一件事；大的任务拆成几个 PR（先骨架和测试，再功能）。PR 标题 `[<ID>] <中文摘要>`，目标分支 `claude/festive-ride-vud32a`。
- 人写内容的分支：`content/<主题>`（A）、`ui-text/<主题>`（B）。

### 13.2 PR 模板（W0 放到 `.github/pull_request_template.md`）

```markdown
## [<ID>] <一句话>

### 范围
- 任务：docs/cards/CARDS_INTERFACES.md §3 <ID>
- 改动路径（必须都在归属表里本任务名下）：

### 自查（全部打勾才提审）
- [ ] 只改了本任务的路径（含 .uid/.import），没碰共享文件、别人的文件
- [ ] 没改 scripts/cards/api/**、mock/**、tests/cards/lib/**；没改任何冻结签名（新加的公开函数列在下面）
- [ ] tools/run_card_tests.sh 全绿；tools/run_legacy_smoke.sh 全绿（贴最后 20 行；全量 run_tests.sh 由 Claude 合并时跑）
- [ ] 新测试都登记在 scripts/tests/cards/suites/<ID>.txt，每个最后一行打印 CARDS TEST PASS
- [ ] 输出里没有 SCRIPT ERROR / ERROR / WARNING / Parse Error / 泄漏
- [ ] 随机只用 ctx.draw / JevRng.draw，用到的 domain 都在 §6.3 的本任务名下（列在下面）
- [ ] 视图、查询、界面里没有概率、百分比、权重、底价、真假、本心、口碑/风声点数
- [ ] 没写玩家正文、正式美术、音频；.gd 字符串字面量和 .tscn 里都没有中文；界面颜色只走 CardTheme
- [ ] 只有冻结表里的类（或下面列出的新公开类）写了 class_name；辅助脚本用 preload
- [ ] 新手指引：新机制发了 first-time（名字在 CardIds.FIRSTS）；界面登记了归自己的锚点、发了规定的 ui_event；测试证明对应的指引步骤会亮；引擎代码没连 ui_event
- [ ] 打烊永远可用（红线 9）：没有新的路径让 day.end 失败或不前进；新面板都能关（dismiss() 的“算了”）；没理会的后果只来自数据；没有真实时间的倒计时
- [ ] 画面与对话（1.3）：坐标只用 CardLayout；演出走 CardStagePanel / CardStageScript，字都从 CardText 来（对话框和回话也是）；锚点、界面事件用 1.3 的名字；附画面截图
- [ ] 占位只在 brief / art/_placeholder/ / audio/_placeholder/
- [ ] 数据：validate_main.gd 默认模式没有 DATA ERROR；悬空引用列在下面
- [ ] 引擎：同种子跑两遍哈希一样；存→读→继续哈希一样；黄金哈希没变（变了在下面解释）
- [ ] 界面：附 1280×720 截图；键盘能操作；autoplay_step 能走完
- [ ] 性能在 §12.4 预算内（列出测得的数）

### 用到的 JevRng 域
### 发的 first-time / 登记的锚点 / 发的 ui_event
### 新加的公开函数
### 悬空引用 / 依赖别的任务的地方
### 需要主创/编排决定的事
### 已知问题、留给后面的事
### 交付（本任务全部完成时写“交付”）
```

### 13.3 审核流程

1. 执行方提 PR → 自动检查（W0 起就是集成分支上的**必过** CI：`check_pr_paths.py --author`、`run_card_tests.sh`、校验器、`run_legacy_smoke.sh`；人写路径另有 CODEOWNERS）。
2. **Claude 审每一个 PR**（§14.2 清单），结论三种：合并 / 改了再合（列“必须改”）/ 关掉（越界或方向错）。“必须改”修完再合；“建议”可以留到后面的 PR。
3. K 数据的 PR 合并后，K13 做史实与敏感审读，问题开 `[K13→K0x]` issue，由数据的主人在自己的分支修（§2.6）。
4. 合并方式：squash，提交信息用 PR 标题 + 要点。合并顺序见 §13.4。
5. issue 标签：`[api]` 合同/接口、`[shared]` 共享文件、`[design]` 需要主创定的、`[bug]`、`[content]` 给 A/B 的正文和美术需求。

### 13.4 合并波次

| 波次 | 谁 | 内容 | 进入条件 | 完成条件 |
|---|---|---|---|---|
| **W0 骨架** | Claude | 附录 A 全部 | 本合同合入 | 骨架合入（W0 合入点：提交 `b87a641`）；`run_card_tests.sh` 绿；38 条线开工 |
| **W1 并行开发** | 38 条线 | 引擎对着桩、界面对着 Mock、数据对着校验器 default、工具对着夹具 | W0（提交 `b87a641`） | G01–G05 全部合入，G06 的破产阶梯合入；C01–C04 合入；**C16 的新手指引引擎合入**；K01、K02、K07、K09、K10、K11 合入；**K16 的指引步骤、规矩页与 `tutorial.json` 合入**；1938 数据 strict 校验全绿（允许的悬空引用清单为空） |
| **W2 集成** | Claude + 原主人 | CardGame 默认换成真引擎（`--cards-mock` 保留）；每个界面任务补一个对真引擎的集成测试（自己的测试目录）；K 数据悬空引用补齐；G06 用真数据出平衡报告、出 `balance_overrides.json`；K13 修正；K14 用真界面走完三关并截图；**K14 的第 1–3 天指引走查（真引擎）与逐步截图**；各界面任务用 K16 的 `steps.json` 复测自己的指引步骤；K15 审核演练（预期失败项 = 还没写的正文和美术，作为给 A/B 的清单）；Claude 做 Steam 接入（成就、云存档） | W1 完成条件 | 三关可以从标题玩到首发结尾；所有测试绿；strict 校验绿；**新存档第 1–3 天的指引测试在真引擎上绿、每一步有截图**；审核只剩“正文/美术未写”这一类 |
| **W3 内容** | A（正文、美术）、B（界面文字、音频）；AI 线只修 bug | 按 `missing_text.py` 的清单写正文、画图、录音，登记来源 | W2 完成条件 | `validate --mode=ship` 绿；`audit.py` 0 违规；A、B 签 `AUDIT_SIGNOFF.md` |

W1 内部的合并先后（不是开工先后，大家同时开工）：G01 → G03 → G04/G05 → G06 的破产阶梯 → G02 → G06 的自动玩；C02、C03 早于用它们的 C05、C06、C11；C16 的指引引擎早于各界面任务的 W2 指引复测；K 数据随时（只要校验器 default 绿）。**开工只依赖 W0**（桩、Mock、例子集、夹具）；合并的硬依赖（谁必须先合）逐条列在 `docs/handoff_cards/README.md` §3.1，是一张无环图——W1 的节点只依赖 W0 和别的 W1 节点，不依赖 W2。

---

## 14. 完成定义与 Claude 的审核清单（n）

### 14.1 完成定义（DoD）

| 类别 | 完成 = |
|---|---|
| 引擎（G01–G05、G06 的破产阶梯） | §3 的范围全部做完；§7 的签名一个不差；登记了自己的指令/op/钩子/修正项；表 7.10.10 里归自己的 first-time 都发了、各一次；§12.2 的测试齐且绿；确定性与存读一致；状态里没有浮点；视图无隐藏键；性能达标；每个文件有头注释 |
| 数值（G06） | 七个策略三关跑通；报告含 §12.6 全部指标；黄金种子可复现；平衡覆盖只动已有键并在报告里说明每个改动的依据 |
| 界面（C01–C11、C16） | 对 Mock 的所有夹具状态都能正确显示和操作；发出的指令与参数被测试断言；`autoplay_step` 走得完；键盘可用；1280×720 截图附上；没有中文字面量（`.gd`、`.tscn`）、颜色字面量；没有任何隐藏数值；锚点、`ui_event`、指引步骤有测试；W2 后对真引擎的集成测试绿；1.3：按 §7.11 摆在画面里（演出 / 抽屉 / 叠层），画面截图附上 |
| 小游戏（C12–C15） | 实现 `CardMiniGame`；参数按 §8.2；结果只有观察键和整数 `quality_permille`；锚点与 `mg_tool`；观察目录写好（键 + brief + 清晰度）；`autoplay` 两档清晰度不同；确定；键盘可玩；无头无报错 |
| 数据（K01–K11） | 数量达到 §3.4；每张牌机制完整、`brief` 合 §11.2 的写法；没有正文字段、没有中文（brief 除外）；id 按预留表；标签已声明；default 校验绿；悬空引用列清；史实依据在 brief 里写明来源年份 |
| 工具（K12、K14、K15） | 命令行一条能跑、README 写在对应 docs 目录；有测试；确定；不联网 |
| 审读（K13） | 每个 K 数据文件一份报告；措辞检查工具和规则；“必须改”都已修正或开了 issue |
| 指引数据与设计（K16） | 每个 `CardIds.FIRSTS` 机制有步骤和规矩页（V29 strict 绿）；`_test.d1_3` 合节奏表；教学日的牌齐；两个分支的完整牌组设计；遵守 era.json notes；只有 brief 和设计，没有正文 |
| **打烊 · 下一天（全体，红线 9）** | `day.end` 在任何能到达的状态（`game_over` 除外）都 `ok` 并前进；预览 = 结算；每种牌没处理时的结局按 §7.4.7 的表、数据写在 `on_expire`（V37）；所有面板能关；G06 的 `G06_no_deadlock`（≥ 1000 局）和 W0 的 `W0_next_day` 绿 |
| **新手指引（全体）** | 每个机制有发出者、有步骤、有规矩页；每个界面部件登记了 §7.10.5 的锚点；V29–V36 strict 绿；C16 的第 1–3 天无头测试和 K14 的真引擎测试绿，每一步有截图；开关指引状态哈希相同；发行前步骤与规矩页正文由 A 写齐（V27） |
| **画面与对话（全体，1.3）** | 一张牌打出后在画面里演、对话框里回话；抽屉与标签、热点、HUD、手牌扇、头像按 §7.11；演出块数据过 V38–V42；锚点与界面事件按 §7.10.5 新表 |

### 14.2 Claude 的审核清单（每个 PR 逐条过）

1. **越界**：`check_pr_paths.py` 通过；没有碰共享文件和别人的文件；sidecar 文件只有自己的。
2. **合同**：冻结签名没变；新公开函数合理且列出；指令、op、钩子、修正项、随机域都按 §5–§7 登记在本任务名下；`class_name` 只在冻结表里（或已同意）；新常量在自己的 `<模块>_ids.gd`。
3. **确定性**：没有 `randf/randi/RandomNumberGenerator/Time` 影响状态；字典遍历排序；随机键只有整数和字符串；状态里没有浮点数；黄金哈希的变化有解释。
4. **隐藏信息**：视图、查询、事件参数、小游戏参数里没有黑名单键；界面上没有 `%`、没有数字化的口碑/风声/概率；扇区只有大小。
5. **免 AI 声明**：没有正文、正式美术、音频；brief 的写法合规；占位都在占位路径；`.gd` 字面量、`.tscn` 无中文、界面无颜色字面量；运行时占位音频有 `is_ship()` 守卫；没有引用旧版的 AI 文字（`onboarding.json`、`codebook.json`、`appraise_panel.gd` 的提示句）。
6. **鉴定**：小游戏不判真假；观察键目录无判词；参数只有物理量。
7. **史实**：伪字、年份写法、1950 年代规则（数据任务由 K13 再审一遍）。
8. **测试**：清单登记了；每个测试最后一行 PASS；覆盖 §12.2 要求；没有 WARNING/ERROR/泄漏；全量 `run_tests.sh` 绿。
9. **质量**：函数 ≤ 80 行；没有死代码和调试打印；错误路径返回错误码而不是崩；没有重复造已有的轮子（JevRng、PressureModel、WorldWheel、ItemGen、Ledger、appraise_panel、UiStyle、settings）。
10. **性能**：PR 里报的数在预算内，抽查一项。
11. **界面**：截图看过：分区不重叠、整数倍像素、金色牌一眼能认、草稿样式明显；键盘走一遍。
12. **数据**：抽 5 张牌读 brief 和机制是否对得上设计；数量；id 规范。
13. **PR 描述**：模板每节都填了；“需要主创/编排决定的事”转成 `[design]` issue。
14. **新手指引**：新机制有 first-time（名字在 `CardIds.FIRSTS`）、有步骤和规矩页；新界面登记了锚点、发了规定的 `ui_event`，测试证明步骤会亮；引擎代码没连 `ui_event`；指引只写 `ui`；步骤和规矩页的 brief 不提概率、点数、本心。
15. **打烊永远可用**（红线 9、§7.4.7）：改动有没有让某个状态按不动“打烊 · 下一天”（新错误码会不会拦住 `day.end`、新面板关不关得掉、有没有引擎要的面板会一直弹回来）；没理会的后果只来自数据和 §7.4.7 的表、引擎没另加惩罚；界面没有因为时间到了自动推进；`G06_no_deadlock`、`W0_next_day` 绿。
16. **画面与对话**（1.3，§7.11）：坐标与 `CardLayout` 一致、整数倍、字不进场景层；演出一次只一出、能“算了”、收场干净；对话的每句都是 CardText；回话发的指令对；没有用数字画口碑风声、没有 %；演出块只写键和 brief。

---

## 15. 肉鸽 v1（2026-10-25；实现合同 `docs/cards/rogue/ROGUE_V1.md`）

> 主创原话：“能不能加一点肉鸽元素。给我多子代理一起做”，并授权编排“你自己决定”。v1 的范围由编排定，记在 `DESIGN_cards.md` §九.8（**编排代主创记**）。
> **实现合同全文：[`docs/cards/rogue/ROGUE_V1.md`](rogue/ROGUE_V1.md)**（状态、接口、算法、数据原文、界面坐标、步骤 0、六个包 RG1–RG6、红线核对）。同目录 `design_R1_relics.md`（老物件）`design_R2_meta.md`（旧账）`design_R3_run.md`（走一趟）是三份提案，只作背景；冲突时以 `ROGUE_V1.md` 为准。
> 本章是总览和索引：接口细节已经同步进本合同各节（下表最后一列）。本章、各节与 `ROGUE_V1.md` 和代码有出入时，以代码和 `ROGUE_V1.md` 为准，开 `[api]` issue 改本合同。签名冻结的东西 v1 一个没改，只追加。

### 15.1 v1 做了什么

1. **一局 = 现有三关连玩**（1938 三月 → 1939 腊月 → 1940 三月）。R3 的“走一趟”（周图、世道、关口、家底结局）留到 v2。
2. **每局一个新种子**：第一本账固定 `7`（测试、黄金种子不变）；之后 `CardRunSeed.derive(档案盐, 本号, 换了几次)`，不读墙钟。标题上显示种子，有“换一个”，玩家也能自己填（纯数字照用，别的字确定地变成种子）。同种子 + 同样的选择 = 同一局。
3. **老物件 / 博古格**（RG1）：12 件（寻常家什 5、有来历的 5、镇店的 2），6 格，满了挑新的必须让出一件（让出的这一局不再出现）。效果只用现有修正项 kind 和现有 DSL op，界面和正文只用词、不出效果大小。流落街头、在牢里时不灵。
4. **周末盘账与客源**（RG2）：每关第 7、14、21、28 天夜里日结时从 3 样里挑 1 样（老物件和客源混着出）；这一周做成的生意不到 2 笔只给 2 样；1938 第 0 周只出客源。客源 6 种，改门口来的人（买家多、来当的多……），管到这一关月底。**1938 第 8 天货郎头一回上门**（人物牌 `p.stranger_peddler.1938.curios`，`look` → `stock_offer` 两件寻常家什，兼新手引子）。**挑不挑都不挡打烊**：不挑 = 第二天作废（`lapsed`）。
5. **旧账（局外）**（RG5）：档案文件 `<存档根>/profile.json`（`CardProfile`）和局内存档分开；一本账在局终、被抓局终、或另起一本时合上（合账）；标题上一个小书架，一本一根书脊、一句铺史；以前各本见过的档案碎片在后来的本子里画成**旧墨**；开头 `og.shanghai`（合上第一本以后可选：第一关的教学日照常随机发牌，第 1 天早上一句开头告示）。**引擎从不读档案文件**：外壳把本局上下文经 `game.new {run}` 交进去，收获经只读查询 `legacy.harvest` 拿出来。
6. 数据、基础层正文、程序美术（RG3）；界面：盘账叠层、博古格抽屉、场景博古格、标题 RunBox（RG4）；自动玩策略（新 `trader` `idle`，`policy.gd` 在盘账叠层开着时按策略偏好挑）、`fuzz_actions` 与 `telemetry` 认 `stock.pick`、平衡对照 `tools/cards/balance/rogue_ab.sh`、黄金种子、本合同与 DESIGN、集成（RG6）。

**集成时改过的原有数据（唯一一处）**：孙府印泥盒（`rl.sun_inkpad`）的 `coins` 行要“你本人站进带 `official` 标签的格子”，可原来带 `official` 的格子都不收本人。编排定方案 A：给十个官面事件（`ev.1938.police_check` `road_pass` `rice_line` `night_patrol`、`ev.1939.gate_check` `patrol`、`ev.1940.household_count` `shop_search`、`ev.any.rain_leak` `market_haggle`）收 `[self, contact]` 的 `man` 格加 `"tags": ["official"]`（K02 / K04 / K06 的文件；例子集不动；格子视图里这个格子的 `wants` 因此是“官面”）。

### 15.2 v1 不做（写明，免得有人顺手做）

R1 的晦气、修好、成套、货郎买卖、单独的“让出”按钮（只有“满了换一件”）、物件的 `resolved` / `night` / `month_close` 钩子；R2 的年景、推理、知情回话、`alt_groups`、`og.shanghai` 以外的开头、合账大画面、旧账大画面、`CardCtx.rules` 覆盖层、每台机器不同的档案盐；R3 的走一趟全部；**新的 first-time 机制与指引步骤**（§15.6）。

### 15.3 接口一览（都已同步进本合同各节）

| 东西 | 名字 | 主人 | 详见 |
|---|---|---|---|
| 牌类型 | `relic`（前缀 `rl.`）· `source`（前缀 `ky.`）：只进 `CardIds.TYPE_PREFIX`，**不进** `CardIds.TYPES`（`W0_validator` 要求 `TYPES` 每类在例子集里都有牌）；不发牌、不进任何区；`TEXT_REQUIRED` 都是 `title` `body` `use`，毛病写在 `lines.flaw`；来历深浅字段叫 `depth`（`plain` `storied` `treasure`，不叫 `rarity`/`grade`） | RG3 写数据；`_schema/{relic,source}.json` 步骤 0 | §4.2、`ROGUE_V1.md` §2、§6 |
| 状态命名空间 | `relic`（RG1；RG2 只经 `relic_api.gd` 写）· `stock`（RG2）· `run`（RG5，只在 `game.new` 给了非空 `run` 时出现）。全部懒建、不进 `CardState.NAMESPACES`；读别人的用 `ctx.state.data.get(...)`，不调 `ns()` | RG1 · RG2 · RG5 | `ROGUE_V1.md` §3 |
| 指令 | `stock.pick {offer, pick, replace?}` | RG2 | §7.4 |
| 查询 | `relics` · `stocktake {offer?}` · `legacy.harvest {close?}` · `legacy.old_ink` | RG1 · RG2 · RG5 · RG5 | §7.4 |
| `game.new` 新参数 | `run: {no, opening?, known?}`（`CardLoopInstall._cmd_new` 在建状态之前调 `legacy_install.check_run`，`CardState.create` 之后、`begin_stage` 之前调 `init_run`） | RG5 | §7.4 |
| 效果 op / 条件 op | `stock_offer {n, kinds, depths?, from}` / `veteran`（值 bool） | RG2 / RG5 | §5.2 / §5.3 |
| 修正项 | 新 kind `unscripted_day`（`any_true`，RG5 提供，G01 的 `CardComposer.is_scripted_day` 问）；现有 kind 的新提供者：RG1 `price_pct` `patience_pct` `appraise_pct` `cap` `pool_pct` `deal_count` `coins`，RG2 `pool_pct` `deal_count`；`view_section` 新键 `relics`（RG1）`stock`（RG2）`run`（RG5）。每种都有钳子（`rules/relics.json` / `rules/stock.json` 的 `clamp`）；没有持有的物件 / 生效的客源时提供者第一行就返回中性值 | 见左 | §7.3、§7.5 |
| 钩子 | `stage_start` 60 RG2 · `day_start` 2 RG5、3 RG2、25 RG1 · `card_resolved` 35 RG2 · `settle` 45 RG1、80 RG2（`CardIds.HOOKS` 不加新名字） | 见左 | §7.3 |
| 安装顺序 | 收徒（K18）之后：`relic_install` → `stock_install` → `legacy_install`，只追加 | 步骤 0 | §7.3 |
| 随机数域 | `c.stock.offer`（局内，`ctx.draw`）· `m.run.seed` `m.run.seed_text`（外壳，直接 `JevRng.draw`，不影响局内状态） | RG2 | §6.3 |
| 错误码 | 模块自己的 `relic_full`（物件满了没给 `replace`）、`not_held`（`replace` 不在博古格上），常量在 `relic_ids.gd`；其余照 `CardIds.ERR_*`：`bad_args` `bad_phase` `already_resolved` `not_allowed` `unknown_def` | RG1 / RG2 | §7.4 |
| 视图 | `relics` `stock` `run` 三块；`open_panel {kind: "stocktake", args: {offer}}`；黑名单不加键 | RG1 · RG2 · RG5 | §7.5 |
| 总线事件 | 不加新信号：`request_panel(&"stocktake", {offer})`、`notice`（`rg2.notice.*`、`rg1.notice.released`、`<rl/ky id>#lines.gain`、开头告示）、`view_changed(["relics"] / ["stock"])`；外壳用已有的 `saved` `game_over` `command_done` 合账 | 见左 | §7.6、`ROGUE_V1.md` §4.9 |
| 面板 | `stocktake`（overlay，`scenes/cards/rogue/StocktakePanel.tscn`）· `relics`（drawer_r，`scenes/cards/rogue/RelicsDrawer.tscn`）；档案簿的旧墨 | RG4 · RG4 · RG5 | §7.8 |
| 热点与坐标 | `curio`（`CardLayout.S_CURIO` / `CURIO`、`CURIO_CELL`、`curio_cell(i)`）→ `relics`；盘账叠层、标题 RunBox 的位置 | 步骤 0 / RG4 | §7.11.2、§7.11.9 |
| 锚点 | `a.scene.curio` `a.stock.offers` `a.relics.list` | RG4 | §7.10.5 |
| 标题 | `CardTitle.set_rogue(data)` / `seed_text()` / `opening_id()`，`chose` 加 `&"reseed"` `&"opening"`（冻结；外壳只调这三个） | RG4 | §7.8 |
| 外壳 | `CardProfile`（`scripts/cards/meta/card_profile.gd`，档案文件读写、并账、合账、本局上下文、标题数据）；`run_keeper.gd`（根场景里的节点，只在交互式真引擎路径上：没有 `skip_title`、`autoplay`、`fixture`；否则 `_start()` 的开局一字不改）；续玩路径只读存档、只写 `profile.json` | RG5 | `ROGUE_V1.md` §8 |
| 规则文件 | `rules/relics.json`（`enabled` `cap` `dormant_in_street` `dormant_in_prison` `clamp`）· `rules/stock.json`（`enabled` `week_days` `deals_needed` `offers_full` `offers_few` `slot_kinds` `source_only_weeks` `clamp`）· `rules/legacy.json`（`openings` `chronicle`）。都进 `db_hash`；数字【待调】，平衡调数经 `balance_overrides.json`（两个规则文件都有 `enabled`，平衡对照的“关”那一份就是 `{"relics": {"enabled": false}, "stock": {"enabled": false}}`） | RG3 | `ROGUE_V1.md` §6.3 |
| 数据 | `era/common/relics.json`（12 件）· `era/common/sources.json`（6 种）· `era/1938/curio_peddler.json`（货郎，复用过路客 `stranger_peddler`）；`era/1938/tutorial.json` 的 9 张教学牌 `schedule` 加 `when: {"not": {"veteran": true}}`；正文在 `data/cards/text_ai/era/**`；美术 `prop.relic.<slug>` `prop.curio` `illus.ky.<slug>`（`tools/cards/art/gen_ai_rogue.py`） | RG3 | `ROGUE_V1.md` §6、§12 |
| 界面键 | `data/cards/ui_keys/RG{1,2,4,5}.json` + 基础层 `data/cards/text_ai/ui/RG{1,2,4,5}.text.json`（RG3、RG6 没有界面键） | 各包 | §2.5、`ROGUE_V1.md` §11 |
| 测试 | `suites/RG1.txt`–`RG6.txt`（`RG1_zero` `RG2_zero` `RG6_sim_zero` 守零身份，`RG6_rogue_flow` 真数据 30 天端到端）；`G06_no_deadlock` 覆盖 `stock.pick`；Mock 夹具在 `scripts/tests/cards/RG4/fixtures/` | 各包 | `ROGUE_V1.md` §13、§14 |

### 15.4 不变式（红线怎么守）

- **零身份**：没有肉鸽数据（例子集）、规则文件 `enabled: false`、`game.new` 不给 `run` 或给 `{}` 时，三个模块不写状态、视图没有新键、状态哈希与 v1 之前一字相同。只读一律 `ctx.state.data.get(...)`，第一次真要写才 `ctx.state.ns()`。
- **确定性（红线 2）**：局内随机只有 `ctx.draw("c.stock.offer", …)`；报价在生成那一刻抽完、记进状态（读档、重来都是同一份）；物件、客源的效果不掷随机；修正项按持有先后乘、每一步取整、最后钳住；种子不读墙钟。同种子 + 同指令 → 同哈希（`RG2_seed`、`RG2_stocktake`、`RG6_rogue_flow`）。
- **隐藏值不上界面（红线 3）**：视图、查询、事件只有 id、美术、深浅词、灵不灵、格数、成交笔数；正文不写数（`RG3_data` 查 `[0-9０-９%％]` 与禁用词）；铺史按本心挑键，但本心的数不出引擎。
- **打烊永远能按（红线 9）**：盘账由 `settle` 钩子 `request_panel`，不进手牌、不加打烊清单行；货郎是普通人物牌；满了只是 `stock.pick` 返回 `relic_full`，不挂任何待办；两块面板 Esc 只关；`G06_no_deadlock`（≥ 1000 局，带新指令）。
- **黄金种子（§12.5）**：步骤 0 和所有代码包不动黄金；RG3 合入数据时预期变（规则文件与数据进 `db_hash`；真数据第 8 天货郎、第 7/14/21/28 天盘账、`fair` 会挑）；由 RG6 的平衡那一步照 §12.5 一次重算，**一个只改 `golden.json` 的提交**，原因与诊断写在 `docs/cards/balance/golden_changes_2026-10-25_rogue_v1.md`；平衡对照（A1–A7）写在 `docs/cards/balance/report_2026-10-25_rogue_v1.md`。
- **免 AI 声明（红线 1）**：新正文只在 `data/cards/text_ai/**`（文件级 `_meta._provenance = "ai:claude:opus-5.5:2026-10-25:rogue-v1"`）与 `brief`；新美术在 `art/ai/**` 与 `art/_placeholder/**`；人写层以后照常覆盖。

### 15.5 归属

v1 合完后的归属见 §2.2 与 `docs/cards/ownership.json`：RG1–RG5 各留自己新建的模块目录和数据文件；v1 期间临时挂在 RGx 名下的共享路径已全部还给原主人；RG6 不再拥有路径。以后改肉鸽的接口照本合同 §0 的规矩走 `[api]` issue。

### 15.6 留到 v1.1 / v2

- **指引（红线 8）是 v1 有意、写明的例外**：v1 不加 `CardIds.FIRSTS`（加了就要同一波改 `W0_skeleton` 的 70 / 各线计数、`K16_guide_coverage` 的 70 步 / 26 页 / `PAGE_IDS` / `table_71010.json`），v1 靠货郎的台词在戏里讲。v1.1 补：`FIRSTS` 加 `curio`（RG1，第一次拿到物件）、`stocktake`（RG2，第一次开盘账），K16 加 `gd.curio` `gd.stocktake` 两步与 `rule.curio` 一页，同一波改上面两个测试的计数。
- 物件：让出按钮、晦气与修好、成套、货郎买卖、`resolved` / `night` / `month_close` 钩子、结局里每件一句 `epilogue`。
- 旧账：合账大画面、旧账大画面、更多开头（`og.1939` 等）、年景、推理、知情回话、`alt_groups`、`CardCtx.rules` 覆盖层、每台机器不同的档案盐。
- 走一趟（R3 全部，v2）。

---

## 附录 A：W0 骨架交付清单（Claude，在任何一条线开工前合入）

1. 目录与 `.gitkeep`；`docs/cards/ownership.json`（与 §2.2 一致：C15 拿解密、C16 拿指引、K16 拿指引数据、G06 拿破产阶梯）；`docs/cards/STATUS.md`（38 条线的状态板）；在 issue 里给 A/B `legal/human_authors.json` 的模板，由他们自己提交。
2. `scripts/cards/api/`：`card_engine_api.gd`、`card_minigame.gd`、`card_ids.gd`（阶段、模式、类型、属性、指令名、查询名、错误码、钩子名、面板 kind（含 `help` `kept_full` `read`）、小游戏 kind、黄历动作、`FIRSTS`、`ANCHORS`、`UI_EVENTS`、`GUIDE_COND_OPS`、`RNG_DOMAINS`——v1 + v1.1 + 新手指引一次列全）、`card_ship.gd`、`dsl_shapes.gd`（§5.2/§5.3 每个 op 和指引数据的形状）。
3. **能跑的最小核心**（G01 接手打磨）：CardDB（读例子集或真数据之一、规则、标签、界面键）、CardState（哈希去掉 `ui`、全精度 JSON）、CardCtx、五个登记表、CardEventBus（含 `first_time` `command_done` `ui_event`）、CardPiles（含 `order_hand`、`discard`）、CardComposer（只按基础权重抽、`draw_k`、`scripted_days`、`project()` 可用）、CardSave（`set_root`）、CardText（含草稿回退，读 `_dev/strings.json`）、CardFirsts、`ui` 命名空间与 `ui.guide`、查询 `firsts` `guide_data` `guide_progress` `guide_conds`、CardValidator（**default 模式下所有“错”的规则**：V01–V08、V10、V13–V15、V17 形状、V20、V22–V26、V28、V30–V33、V35）、`validate_main.gd`（带 `--name`）。
4. 其余所有 §7.1 / §7.9 的类：同签名的桩（返回 `{"ok": false, "err": "not_implemented"}` 或最简单的值），六个 `*_install.gd`（含 `CardLadderInstall`）已按顺序接好；CardEngine 的指令分发、`busy`、事件按序发出、`command_done` 已能工作。
5. `MockCardEngine` + 十个基础夹具（§7.7：查询键一种写法、自动补 `command_done`、回答指引查询、每个夹具带 `firsts`；`day_counter` 的金簪布局由真 ItemGen 生成）。
6. 界面公共件：`card_panel.gd`、`card_anchors.gd`（冻结）、`card_theme.gd` 初版（→ C01）；§7.8 两张表里**每一个**面板和控件的桩场景（同接口）：`CardWidget` / `CardArt`（→ C02）、`CardSlotWidget` / `CardCoinTossView` / `CardKeptFull`（→ C03）、`CardDemandBoard`（→ C05）、`CardAlmanacStrip`（→ C07）、`CardStreetOverlay`（→ C11）、`CardHelpPanel`（→ C10）、`CardTitle`、`GuideOverlay` / `CardGuide`（→ C16；桩已能挑步骤，范围见 §7.10.2）、`CardModalHost` 与 `CardGame.tscn`（→ C01）。
7. 数据：`data/cards/_examples/`（§4 全部例子，加上让它们引用闭合所需的最少几张；`_examples/guide/`：3 个步骤、3 页规矩、`_test.d1_3`；`_examples/ui_keys.json`、`_examples/tags.json`）；`rules/*.json` 初值（§4.6，含 `deal.json` 的新 `hand_order` 与 `scripted_days`、`ladder.json`、`guide.json`）；`tags/W0.json`（`omen_*` 家族与 `bad_omen`）；`theme/palette.dev.json` 开发初值（**不建 `palette.json`**）；`_dev/strings.json`；`art/manifest.json` 初版（→ K12）；`ui_keys/W0.json`。
8. 测试：`scripts/tests/cards/lib/card_t.gd`（每个测试自己的 `user://` 目录、`find_floats`、`spy`、`anchor_ok`；`finish()` 清 CardText 与 CardAnchors）；`tools/run_card_tests.sh`；`tools/run_legacy_smoke.sh`；`tools/run_tests.sh` 末尾调用前者；`suites/W0.txt`（骨架自测：引擎能 new、Mock 能回放、校验器对例子全绿、桩的签名与合同一致、`find_floats` 为空、`ui` 不进哈希）。
9. 项目：autoload `CardBus`；导出预设：开发预设照旧 + **只含卡牌版的 Steam 预设**（§2.3：`ship` 特性、主场景覆盖、排除占位/例子/开发文件/旧版目录）；`scripts/ui/main.gd` 加 `--cards`。
10. `.github/pull_request_template.md`（§13.2）、`.github/ISSUE_TEMPLATE/`（api、shared、design、bug、content）、`.github/CODEOWNERS`（人写路径归 A/B）、`.github/workflows/cards.yml`（`check_pr_paths.py --author`、`run_card_tests.sh`、`run_legacy_smoke.sh`），在集成分支上设成必过检查。
11. `tools/cards/audit/cjk_allowlist.json` 初版（发行包里旧文件的中文逐个写原因）。
12. 记下 W0 合入点（提交 `b87a641`），在 `STATUS.md` 里把 38 条线标为“可以开工”。
13. **1.3（10-13 晚）**：`CardLayout`；画面控件的接口基类（`CardStageApi` `CardDialogApi` `CardHandApi` `CardHeroApi` `CardChecksApi`）、`CardStagePanel`、`CardStageScript`；W0 桩（`scenes/cards/_w0/`）；`CardIds` 的 1.3 常量（`PANEL_SHOW`、`HOTSPOTS`、`STAGE_*`、`EXTRAS`、新锚点与改名表、新界面事件、`panel_scene()`、`widget_scene()`）；`CardDslShapes.check_stage`；Mock 的 `view.stage` 等；例子集的群演与（G01 合入后）演出块；`palette.dev.json` 的画面配色；W0 测试跟着改、新测试 `W0_stage`。

## 附录 B：给三家执行方的开场提示（复制粘贴，把 `<ID>` 换成任务号）

**通用（每条线都发）**
> 你接手 GitHub 仓库 misakamikotoghr-5205/dehoudang（Godot 4.7 + GDScript 的民国当铺游戏，正在改成卡牌游戏）。任务号 `<ID>`。从 W0 合入点（提交 `b87a641`）（分支 `claude/festive-ride-vud32a`）切分支 `cards/<ID>-<slug>`。先读 `docs/cards/DESIGN_cards.md`（玩法，主创原话）和 `docs/cards/CARDS_INTERFACES.md`（接口合同，必须遵守），重点读 §0 红线、§2 归属表、§3 里你的任务、以及你的任务涉及的章节。只改归属表里你的路径。随机只用 `ctx.draw`；界面上不出现隐藏数值；玩家能看到的文字、美术、音频你只能放占位（brief、`art/_placeholder/`），绝不写 `data/cards/text/**`、`art/cards/**`。每个机制都要有新手指引（红线 8、§7.10）：机制第一次出现要发 first-time，界面部件要登记锚点。“打烊 · 下一天”永远可用：你的改动不能让任何状态卡住、按不动下一天（红线 9、§7.4.7）。`GODOT=<你的 Godot 4.7 路径> tools/run_card_tests.sh` 和 `tools/run_legacy_smoke.sh` 全绿后，按 `.github/pull_request_template.md` 开 PR 回 `claude/festive-ride-vud32a`。设计上拿不准的写进 PR 的“需要主创/编排决定的事”，不要自己加玩法。10-13 晚起合同 1.3：游戏画面是像素柜台场景 + 对话框，打牌是玩法、对话是载体（§1.2、§4.7.24、§7.11）；先看你的任务卡里“10-13 变更二”一节。

**GPT（G01–G06）加一句**
> 你写引擎：纯 `RefCounted`、静态类型、整数运算、状态只放在 `CardState` 你自己的命名空间里；在你的 `*_install.gd` 里登记指令、效果/条件 op、钩子和修正项；在你任务卡列出的每个机制第一次出现的地方调 `CardFirsts.mark`；对着 W0 的桩开发，别等别的线。确定性、存读一致、状态里没有浮点、视图无隐藏键都要有测试。

**Cursor（C01–C16）加一句**
> 你写界面：继承 `CardPanel`，只用 `engine.send/query/view` 和 CardBus；对着 `MockCardEngine` 和你自己写的夹具开发；文字全走 `CardText`、颜色全走 `CardTheme`、图全走 `CardArt`；`.gd` 和 `.tscn` 里不写中文、`.gd` 里不写颜色字面量；实现 `autoplay_step()`；用 `CardAnchors.register` 登记你任务卡“新手指引”一节列的锚点、发规定的 `ui_event`，测试证明对应的指引步骤会亮；PR 附 1280×720 截图。

**Grok（K01–K16）加一句**
> 你写数据骨架或工具：数据只写机制和 brief（干巴巴的设计说明，不写台词、不写正文字段、brief 以外不出现中文），id 用合同 §3.5 的预留表，史实措辞照 era.json 的 notes（伪字等）；每张 event/fate/person/life/news 带一个 `omen_*` 标签，原因键用你自己的 `k0x.*`；每个文件过 `validate_main.gd` 默认模式；工具确定、不联网、只用标准库（K12 可以用 Pillow）。

## 附录 C：术语对照

| 中文 | 标识符 | 中文 | 标识符 |
|---|---|---|---|
| 人物牌 | `person` | 你自己 | `self` / `ruhua` |
| 人脉 | `contact` | 留着的牌 | `kept` |
| 事件牌 | `event` | 命运牌 / 大命运 | `fate` / `big_fate` |
| 条子 | `demand` | 生活牌 | `life` |
| 消息牌 | `news` | 家当 | `estate` |
| 夜牌 | `night` | 街头 / 牢房 | `street` / `prison` |
| 当票 | `pawn_ticket` / ticket | 货架 | shelf |
| 格子 / 检定 | slot / check | 铜钱 / 正面 | coin / head |
| 眼力 口才 门路 胆量 | `eye` `tongue` `pull` `nerve` | 口碑 风声 本心 | `rep` `heat` `conscience` |
| 压价 公道 厚道 | `harsh` `fair` `kind` | 来当 来卖 来买 来赎 求助 打听 | `pawn` `sell` `buy` `redeem` `help` `ask` |
| 要钱 要货 要人 要消息 | `money` `goods` `people` `info` | 小 中 大 要命 | tier `0` `1` `2` `3` |
| 命运轮盘 / 扇区 / 香案 | wheel / segment / incense | 本月运势 / 大轮盘 / 庙会 / 赌摊 | `wh.month` / `wh.big` / `wh.fair` / `wh.gamble` |
| 翻身 平安 坠底 | valence `good` `neutral` `bad` | 签 / 测字 / 黄历 | `fortune_lot` / `cezi` / `almanac_day` |
| 宜 / 忌 | `yi` / `ji` | 钉签 | pin |
| 档案簿 / 页 / 碎片 / 缺口 | dossier / page / fragment / gap | 一年后 | `year_after` |
| 金色角色牌 | `gold` | 主线节点 | `story_node` |
| 打烊 · 下一天 | `day.end`（清单 `day.end_preview`） | 日结 | settle |
| 没理会（打烊时还没处理） | ignore / `on_expire` | 今天要了断 | `must_resolve` |
| 跳一年 | year jump | 流落街头 / 爬回来 | street mode / `street.redeem_shop` |
| 抵押 / 赎回 | mortgage / redeem | 钱不够阶梯 | short ladder |
| 正文覆盖层 | text overlay | 设计说明 | `brief` |
| 新手指引 / 指引步骤 | guide / `guide_step` | 规矩页 | `rule_page` |
| 第一次遇到 | `first_time` / `firsts` | 锚点 | anchor（`a.*`） |
| 教的人 | teacher | 气泡 / 台词 | `bubble` / `say` |
| 教学日 | `scripted_days` | 系统牌 | system card |
| 征兆标签 | `omen_*` | 禁签 | ban |
| 破产阶梯 | ladder（G06） | 留牌满了 | `kept_full` |
| 画面（场景层 + 界面层） | — | 场景 / 演出 | stage / play（`CardStage`、`CardStagePanel`） |
| 对话框 / 回话 | dialog / reply（`CardDialogBox`） | 手牌扇 / 打出 | hand fan / play（`CardHandFan`、`hand_played`） |
| 英雄头像 / 人脉小牌 | hero / contact minis（`CardHeroBar`） | 抽屉 / 标签 | drawer / tab |
| 热点（柜台上的工具） | hotspot（`CardIds.HOTSPOTS`） | 群演 | extras（`ex_*`，§3.5） |
| 时段 白天/黄昏/夜里 | `stage.time` `day`/`dusk`/`night` | | |

## 附录 D：1.1 修订摘要（对 1.0）

**A. 新手指引**（主创 2026-10-13 硬性要求）：红线 8；§7.10 全节（规则、分工、三个总线信号、`CardAnchors`、锚点与界面事件目录、`CardFirsts` 与 `ui` 命名空间、`CardGuide` 接口与做法、设置与命令行、测试、66 个机制的步骤总表与规矩页、教学日）；数据格式 §4.7.21、校验 V29–V35（指引）与 V36（系统牌、大赌）；C16 改为 `guide-shell`（指引引擎 + 外壳），解密并入 C15（`mg-fragments-decode`），C10 加规矩栏与 F1 帮助，K16 改为 `guide-data-post1949`；K02 的规矩牌和 `kp.brother_ledger` 取消；每张界面任务卡加“新手指引”一节，每张引擎任务卡列 first-time；`deal.json.scripted_days` 与 `tutorial.json`；主创节奏与机制的七处冲突列出默认做法（§7.10.10）。

**B. 免 AI 声明的漏洞**：找不同从旧面板分出、参数只给布局、去掉例外（C12、§8.2）；Steam 包只含卡牌版、所有发行文件查中文、`.tscn` 也查、中文白名单（§2.3、§11.4）；电码本改成 K11 的骨架 + A 写的词；卡牌版曲目自己管（C16）；W0 只写 `palette.dev.json`（§1.2）；按 PR 作者判断 AI、CODEOWNERS、必过 CI（§11.5）；从暂存目录导出并复查 `.pck`（§11.6）。

**C. 确定性、存档、测试**：`card_ledger.gd` 继承旧账本（整数月息、整数当票号、ASCII id）；状态里不许有浮点、全精度哈希、`quality_permille`；测试各用各的 `user://` 目录；例子集与真数据分开读（§4.10）；校验器 `--name`；W0 校验器做全 default 错误规则 + `dsl_shapes.gd`；目标改用 `done_when`、§4.5 写明允许的正文字段；随机：每周生活牌挑哪张、`draw_k`、`coin_check` 的来源路径、小游戏布局种子与键、精确的随机域登记、集市日只按日历。

**D. 共享文件与接口**：手牌顺序只由 `order_hand()` 定（金色牌在最前）；必须处理的牌以 §4.7 默认为准；轮盘指令带 `uid`、`wheel.stake`、`ev.any.wheel_go`；条子的六种办法走 `card.choose`；来意与面板对照、人物牌选项上柜台、赎当四种；`short` 面板参数、`kept_full` 面板与 `card.discard`；没有物品的牌也能开小游戏；夜牌可带选项；大命运只发 `bf.wheel`、扇区可带条件；K 数据用自己的原因键；封闭的 `omen_*` 征兆标签；系统牌归属表；钉签、查封、街头的发牌矩阵；视图按修正项拼、`tags` 等进黑名单；嵌入控件都有桩；卡牌版设置独立存；破产阶梯移到 G06；`class_name` 只在冻结表里；`resolve()` 带 `extra`；开场 `stage.json`、评语与档位文字键有主人；`appraise_pct` 修正项；新常量放各模块自己的 `_ids.gd`。

**评审的可选项**：采纳——测字“无”加禁签（§9.3）；指令日志移到存档信封（§6.1）；Mock 查询键一种写法（§7.7）；`expires_in` 与 `days_left` 分开定义（§7.5）；`card_t.finish()` 清理（§12.1）；PR 跑新测试 + 旧版冒烟、合并时跑全量（§12.1）；`project.godot` 也要 checkout 掉（§0）；【稿】字样放数据里（§4.5）；G03 参考保护费阶梯（§3.2）；解放后的预留（`data/cards/branch/**`、`kp.history_issue`、存档 `v` 向前兼容）；Steam 接入归 Claude 在 W2（§11.6、§13.4）；`day_counter` 夹具带真布局（§7.7）；ART_SPEC 写明代码画的小游戏画面只用调色板键（K12）。部分采纳——K02 减负：通用命运给 K04、通用生活牌给 K06；通用事件留在 K02（算命摊、庙会、赌摊和 `ev.any.wheel_go` 是教学和轮盘要用的，放一起好对）。不采纳——校验器移到 K15：它要用引擎登记的 op 形状和 CardDB，留在 G01；W0 已经先把 default 规则做全，G01 的负担不重。

## 附录 E：交接包审计修订（2026-10-13，开工前）

对合同、`ownership.json`、38 张任务卡、三份开场提示、交接板和 W0 骨架做了一遍机械审计（脚本逐条比对路径、机制、锚点、步骤、依赖与线号），按结果改了这些地方（都不改玩法、不改冻结接口）：

1. **归属表 = `ownership.json`，逐条一致**：K15 改成逐个文件列出（原来合同写 `tools/cards/audit/**`，`ownership.json` 写具体文件）；补上 `docs/handoff_cards/**`、`scripts/cards/ui/common/w0_stub.gd`、不在任务目录里的 `.gitkeep`（都归 Claude）。
2. **`fonts/**` 只有一个主人**：原来同时在 Claude 名下和“只许人改”的名单里；改为归人（A/B），子集由 B 跑 `tools/build_fonts.py`（脚本仍归 Claude）；红线 1、§11.2、§11.5 一并列上。§11.4 第 7 项改为 K15 用标准库读 `cmap`。
3. **K13 不再跨线改文件**（§2.6）：审读结论走 `[K13→K0x]` issue，由数据的主人改；`check_pr_paths.py` 不用为 K13 设特例。
4. **发行排除补齐**（§2.3、§11.4 第 1 项、§3.4 K15）：`data/cards/rules/wording.json`、`data/cards/branch/**`。
5. **黄金哈希**（§2.2、§12.5）：别的任务不改 `golden.json`，哈希变了由 Claude 在合并时重算。
6. **G02“重来本关哈希等于当时”与 `retry` first 的冲突**：比较时去掉 `core.firsts` 的 `retry` / `resume`（§3.2）。
7. **新手指引**：C01、C02 的“要证明的步骤”补全（每个步骤都有一个界面任务证明它会亮，预留的 `gd.currency` `gd.branch_pick` 除外）；C16 与 K16 的验收写明第 1–3 天的无头测试与逐步截图、K16 合入前 C16 用自己的 21 步测试步骤；W0 的 `CardGuide` 桩能力按骨架实写（§7.10.2）；K16 验收 V29–V36。
8. **与骨架对齐**：例子集是 3 步 3 页（不是 2 页）；V12 的路径是 `data/cards/art/manifest.json`。
9. **依赖**：开工只依赖 W0；合并的硬依赖列成无环图（交接板 §3.1）。

## 附录 F：1.2 修订（2026-10-13：主创确认“九点”；打烊永远可用）

主创 2026-10-13 的两句话：“同意你说的九点”（PDF v1.2 第九节的九条，即 DESIGN“实现时的理解”第 1、2、3、5、6、7、9、12、13、15、16、17 条）；“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”（DESIGN §九.5）。合同跟着改：

1. **原来【待主创确认】的都定了**：大命运并入大轮盘（§4.7.5、§9.2）、每关 + 每天续玩点（§6.1）、第一关头三天固定（`scripted_days`、§7.10.11）、手牌先后（`deal.json.hand_order`、§10.2）、流落街头时哪些照旧（§7.4.6）、押牌与香案（§9.1、§9.2，数字仍【待调】）、哥哥走后由账簿批注接着教与 a–g 节奏（§7.10.10）、求签为什么准（§9.3）。标记改成【主创已确认 10-13】，做法不变。
2. **红线 9 与 §7.4.7（新）**：“打烊 · 下一天”永远可用、绝不卡住。`day.end {confirm}` 除 `game_over` 外任何阶段都往前走一步（白天 → 夜 → 日结 → 早上；夜里 = 不选夜牌；开月时替玩家转本月运势）；新查询 `day.end_preview` 给“未处理清单”（EndRow `{uid, def, kind, consequence_key, args}`）；每种没处理的东西怎么结算是一张表（客人走、个别人记仇写在 `on_expire`、事件/命运/街头/大赌按没理会、金色牌按没理他、条子接着计时、大轮盘作废、牢房多待一晚、连续 `prison.max_days` 晚没出来按打点失败）；不卡死不变式（任何状态最多 8 次 `day.end` 一定进到下一天或局终），G06 的 `G06_no_deadlock`（≥ 1000 局）守着；没有真实时间、不自动跳天。
3. **id 不变、含义改了**：`must_resolve`（牌的字段与 CardView 字段）= 今天要了断、打烊时按没理会结算，不再挡打烊；错误码 `must_resolve_pending` = `day.end {confirm: false}` 时要确认（不再是挡住），`gold_pending` 不再返回；`day.end` 的参数 `confirm_gold_leave` 改名 `confirm`（W1 里旧名照收），返回 `{blocked, gold_pending}` 改成 `{step, items}`；first `must_resolve` = 第一次按打烊时手上还有要了断的牌、`gold_leave` = 第一次按打烊时金色牌还在（都在确认之前记）；锚点 `a.endday.blocked` = 确认面板里的清单、`a.endday.gold_leave` = 清单里金色牌那一行、`a.btn.close_day` = “打烊 · 下一天”按钮；步骤 `gd.must` `gd.gold_leave` 改在确认面板上亮、`gd.d1.close` 讲“随时能按”；面板 kind `end_day` 就是这张确认清单。
4. **新增**：`CardIds.Q_DAY_END_PREVIEW` `END_STEPS` `END_KINDS` `END_NO_CONFIRM_KINDS` `END_MUST_KINDS` `END_MAX_STEPS_TO_NEXT_DAY`；查询 `day.end_preview`（G02）；修正项 `end_rows`；`CardPanel.dismiss()`（面板的“算了”，§7.8；C01 卡原来的 `can_close()` 约定作废）；校验 V37；`ladder.json.prison.max_days` 与 `ladder.prison`；`day_end` 钩子的 priority 5–25；§7.4.6 加“在牢里”一列；`night.choose {def: ""}`、`game.load {}`（续玩点）；§4.5 的 `outcomes.ignored`；§13.2 自查一行、§14.1 一行、§14.2 第 15 条。
5. **W0 骨架同步**：Mock 情景模式的 `day.end` 不再挡（照 §7.4.7）、加 `day.end_preview`；十个夹具重新生成（每个都带 `day.end_preview|{}` 和 `day.end` 的回应）；例子集的 `fa.any.fire_next_door` `bf.any.mystery_box` `bf.any.ship_ticket` 补了 `on_expire`；`CardPanel.dismiss()`、宿主 Esc 调它；W0 的桩（牌桌按钮——局终时改开局终面板、确认面板、夜牌 / 留牌满 / 人脉满 / 钱不够 / 柜台 / 局终的“算了”、G02 的 `day.end_preview` 查询桩、`day_loop.end_day` 的参数名）跟着改；十个夹具都录了 `day.end` `confirm` 真、假各一条回应；新测试 `W0_next_day`（含每个夹具按一次按钮、每种面板 Esc 都关得掉）。已开工的线 rebase 时，W0 桩文件冲突以集成分支的版本为底，再把自己的实现按本附录改。

## 附录 G：1.3 修订（2026-10-13 晚：画面与对话）

主创看了纯文字牌桌版的网页试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（docs/cards/prototype/），主创看完说“不错”。合同跟着改（九条红线、免 AI 声明、归属、首发三关、隐藏数值、已有的冻结签名都不变）：

1. **作废**：§1.2 的“Control 牌桌，不用 2D 场景、不用 SubViewport”与“牌桌分区”（顶栏 56、左栏、右栏、柜台桌面、手牌行）；有格子/选项的牌开居中大面板、柜台面板的居中布局；条子板钉在右栏、黄历条在 196×40 的顶栏格、街头“皮”盖住牌桌；C01 的货架抽屉（货架成了 C04 的 shelf 抽屉）；新手指引“左下角教的人头像”；7 个锚点的旧名（改名表 §7.10.5，W1 里旧名还认，W2 删）；“1–9 永远选手牌”（列着回话时选回话）。
2. **新增**：画面 = 场景层 + 界面层（§1.2）；§7.11 画面与演出（层次、坐标 CardLayout、场景层 CardStage、演出 CardStagePanel 与默认演法 CardStageScript、对话框 CardDialogBox、手牌扇 CardHandFan 与英雄头像 CardHeroBar、柜台上的格子 CardCounterChecks、抽屉与标签、热点、HUD、打烊按钮）；§4.7.24 演出块 stage 与校验 V38–V42（V27、V30 加内容）；视图 stage {set, time, sealed}、CardView 的 stage source wheel fortune demand、night_offers 字典（G02、G03、G05）；面板表加“呈现”列与 5 个抽屉 kind（contacts demands shelf tickets almanac）；新锚点 a.scene.* a.tab.* a.hero a.contacts a.hand.kept a.hand.preview a.dialog a.dialog.next a.shelf.list a.tickets.list；新界面事件 hand_played drawer_opened/closed hotspot_pressed dialog_advanced dialog_skipped reply_chosen（hand_selected 改归 C02，panel_opened 多一个 show）；群演 ex_*（K09 登记）；美术类别 stage.* walk.* prop.* frame.dialog frame.hero frame.guide_note icon.tab.*；画面配色键；CardSettings.fast_anim() 冻结；§12.3 改成画面截图；§14 加一条。
3. **W0 骨架同步（Claude，只动 Claude 的文件）**：见附录 A 第 13 项。C 线自己的 W0 桩文件（CardTable、CounterPanel 等）这次**不动**，由主人在自己的分支里换成 1.3 的做法；新控件主人还没合入时由 W0 桩顶上，所以 W0 的测试和 --cards 照样能跑。
4. **已开工的线怎么 rebase**：所有线 rebase 到包含 1.3 的集成分支；W0 桩文件冲突一律以集成分支的版本为底，再把自己的实现照任务卡“10-13 变更二”一节改。引擎线、数据线手上的 PR 不用为 1.3 改（例外：K16 的锚点、K12 的美术类别、G01/G02/G03/G05 的小增补另开小 PR）；数据线的演出块等 G01 的 1.3 小 PR 合入后另开一个 PR。界面线已经写好的“和引擎说话”的部分——发什么指令、问什么查询、自动一步怎么走、夹具、对 mock.sent 的断言——**全部还有效**；要换的是“画在哪、怎么画”：居中面板改成演出（回话 + 柜台上的格子）或抽屉，锚点改名、换位置，截图改成画面版。

## 附录 H：鉴定改版（2026-10-25，主创：“你那个鉴定不能只是点点点，要玩家看出来才算数”）

编排拍板（主创授权“你自己决定”）：说破（Level B）做；图例做（画出“旧痕”和“动过手脚”各长什么样，不写结论）；每件固定 3 处痕迹；一摞银元模板这一版不做；主线拼碎片、解密做对做错不分剧情（只影响记下来的观察和价钱）；冤枉人不扣口碑；眼力数值照设计初值。

1. **改了意思**：观察 = 玩家的判断（§0 红线 5 括注、§8.1）；`quality_permille` 只看过程；§8.1 原“不影响价格”改成“说破会影响价格（主创 10-25）”；`autoplay(skill)` = 判对的概率。
2. **新增**：`econ.appraisals[uid].answer`（私账）、`CardAppraisal.judge` / `record` / `reading` / `weigh_cat` / `doc_params(ctx, doc, kind)`（没物品的文书的参数；冻结的 `params_for` 签名不变）、说破（§3.2 G04）、`econ.readings` 与条件 op `mg_read`（§5.3）；观察目录的 `hedge` 和 `fidelity: "any"`（§4.8，`CardIds.OBS_FIDELITY` 加 `any`，校验 V23 查 hedge）；§8.2 新参数与 measures；`apply_op` / `ops_log` 约定（不进基类）；K11 规格新字段（§4.7.15）；`economy.json` 的 `appraise.{expert_pct, aids, spot, coin_ring, weigh, fragments, decode, lever}`；新锚点 `a.mg.spot.tag` `a.mg.coin_ring.samples` `a.mg.weigh.call` `a.mg.fragments.seam` `a.mg.decode.sheet`；界面键 `g04.counter.lever.<caught|soft|offended>`；`news` / `pawn_ticket` 牌可以写 `decode` / `fragments` 规格；§6.3 的 `c.mg.param` 键与小游戏随机下标分段；§12.2 小游戏必测；测试小工具 `scripts/tests/cards/lib/mg_ops.gd`。
3. **兼容**：小游戏缺新参数时用保守默认；引擎遇到没有 `hedge` 的老目录照旧只收这一档的键；老小游戏不交新 measures 时说破不结算、不报错。五个小游戏谁先合都行。
4. **顺手修**：B1（整批观察因换档丢失）、B2（大件压不平）、B3（印偏、异纸和真假无关）、B5（痕迹数量位置泄底、`atlas_open` 恒真）、B6（主线电报列出整本电码本）、B8（文书共用一个布局种子）、B10（眼力没用上）、B11（引擎记住这个会话鉴定过了）；B12 的引擎一半（hedge / any 规则），目录一半在 C15 的 `obs/decode.json`。
