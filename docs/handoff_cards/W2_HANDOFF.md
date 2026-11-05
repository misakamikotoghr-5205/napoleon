# W2 交接：Google argon / GPT-6.1 sol 接手，美术走 Google AI Ultra（主创 10-18 定）

> **10-19 框架版已收尾，W2 结束。台词、美术批量、正式音乐留到下一阶段，见仓库根目录的 [`HANDOFF.md`](../../HANDOFF.md)。下面是 W2 当时的交接原文。**

集成分支 `claude/festive-ride-vud32a`。设计：`docs/cards/DESIGN_cards.md`（§九.5 打烊、§九.6 画面与对话、§九.7 随进度开放的系统）；合同：`docs/cards/CARDS_INTERFACES.md`；收尾记录：`docs/TODO_REMAINING.md`；网页原型（画面样子的样板）：`docs/cards/prototype/`。

## 现在的状态（10-18，Claude 在提交 ccda2bc 上实测）

- W1 的 38 个任务都已合入（含 C01 新牌桌、C04、C08、C11），首发新系统猫、收徒、武器（吓唬）、官场开头、按钮换字也已合入。
- **1938–1940 全部数据 strict 校验 0 错**（1115 张牌）——W1 完成条件 ② 达成。
- 旧版冒烟全绿。卡牌测试 305 项里 11 项红（见任务 2）。注意：Claude 用的是 Godot 4.7-stable，各线用 4.7.1；**统一用 4.7.1**，先在 4.7.1 上复跑确认。
- `--cards` 进去的牌桌**仍是 Mock 引擎**，真引擎还没接到牌桌上（任务 1）。

## 谁做什么

- **GPT-6.1 sol**：引擎侧与集成——任务 1、2、5、6。
- **Google argon**：界面与工具——任务 3、4，美术管线 7b。
- **美术生成**：用 Google AI Ultra 订阅里的图像生成工具（Gemini 应用里的图像生成 / Imagen、Whisk 等；视频工具可做预告片），按任务 7 出图；谁有订阅谁生成，argon 负责后处理和接入。
- 领取照任务板规矩（#99）：在任务 issue 下评论 `/claim <线名>`；分支 `cards/<任务号>-<slug>`；PR 写 `Refs #<issue>`。
- **合并**：用 `tools/cards/merge_gate.sh`（按计划文件一批批合、红了拆开逐个测，只留全绿的），再跑全量 `tools/run_tests.sh`，绿了推集成分支。合并人由主创指定（默认 GPT-6.1 sol）。

## 任务

1. **X01 真引擎接上牌桌**：`CardGameRoot` 默认用 `CardEngine`（`--cards-mock` 保留给测试）；新局从标题进 1938 年三月第 1 天，能玩满 30 天 → 月底结账 → 跳年过场 → 1939 腊月；删掉 W0 桩（`scripts/cards/ui/common/w0/**`、`scenes/cards/_w0/**`、`w0_stub.gd`）和 CardIds 里 7 个改名前的旧锚点兼容；W0 测试跟着改。验收：无头自动玩 1938 一整关不报错、打烊永远能按（`G06_no_deadlock` 绿）、K14 真引擎第 1–3 天指引走查绿并每步截图。
2. **测试转绿**（4.7.1 上复跑后仍红的）：C07 六项（`C07_lot` `C07_cezi` `C07_no_foretell` `C07_guide` `C07_real_k` `C07_guide_k16`，多为退出泄漏告警）、`K12_art_load`、K14 三项（`K14_guide_onoff_mock` `K14_next_day_chaos` `K14_play_ui_mock`）、`W0_skeleton`。还开着的 PR 照任务板处理：N01–N06 新玩法数据骨架（#164 #165 #169 #170 #171 #172）走门禁合入；重复的旧复测 PR（#174 #175 #177 #179）关掉；#176 问作者；#98 #25 不合。
3. **画面问题**（截图见 Claude 10-18 的回报）：① 门口客人被画成 4×4 一整张行走图——要切出一帧（`walk.*` 是帧表）；② 顶栏日期、天气、黄历、钱、口碑文字互相压——每格限宽、超了省略；③ C04 的截图脚本 `scripts/tests/cards/C04/shot_counter.gd` 跑 400 秒超时，查卡在哪。
4. **导入卫生**：K12 生成器写的 `art/_placeholder/cards/**.png.import` 里的 uid 和缓存路径 Godot 导入时会改写（每次导入都出 16 个改动）——让生成器不写 `.import`，或写成 Godot 4.7.1 认的样子并提交一次稳定版本。`docs/.gdignore` 已加（Godot 不再导入 docs 里的截图）。CI 的 Godot 版本钉到 4.7.1。
5. **数值**：G06 用真数据出平衡报告（七个策略三关），改 `balance_overrides.json`，报告进 `docs/cards/balance/`。
6. **K13 审读修正与 1938 内容收口**：K13 的审读意见逐条在数据里改；悬空引用保持为 0。
7. **美术（Google AI Ultra）**：
   - 7a **定风格**：按 `docs/cards/ART_SPEC.md` 的尺寸和调色板，各出 3–5 个候选——柜台场景（320×180）、人物半身（48×64）、行走图（64×128 帧表）、物品（64×64）、牌框、小插图（64×48）。主创挑定，提示词模板写进 `docs/cards/art/PROMPTS.md`（风格词、负面词、尺寸、调色板、光源）。
   - 7b **批量生产与接入**：清单 `data/cards/art/manifest.json` 共 422 个 id（bg 18、portrait 47、walk 30、item 41、prop 39、illus 175、frame 19、icon 49、wheel 4）。生成后用脚本（`tools/art/pixlib.py` 的调色板）缩到准确像素尺寸、量化到调色板、去抗锯齿，放到新目录 **`art/ai/<类别>/<id>.png`**；清单每条加 `ai` 路径和来源 `_provenance: "ai:google-<工具名>:<日期>:<提示词 id>"`；`CardArt` 查找顺序改成 **human → ai → placeholder**（C02 的文件，合同 §4.8 一并改）。
   - 7c **审核与 Steam**：AI 生成的图在 Steam 上要做 AI 内容声明。K15 审核工具把 `art/ai/**` 记为“AI 生成、需声明”；出包预设分两种：带 AI 声明版（用 `art/ai/**`）和不带声明版（只用 `human`，缺的报错）。人画的图以后放 `art/cards/**` 会自动顶替 AI 图。**主创 10-18 已定：这一版先用 AI 美术、带 AI 声明发**；不带声明的版本等人画的图补齐后再出。

## 规矩照旧

九条红线（打烊永远能按等）、隐藏数值不显示、伪字与不写血腥、新机制要有新手指引、各线只改归属表里自己的文件（新路径在 `docs/cards/ownership.json` 登记）。

## 主创 10-18 补充决定：这一版暂时全用 AI，先把管线跑通

美术、音乐、音效、台词正文**这一版都可以用 AI 生成**，先跑通“生成 → 后处理 → 登记来源 → 进游戏”的整条管线，以后再逐项换成人做的。统一做法（三类一样）：

| 类别 | AI 产物放哪 | 人做的放哪（以后） | 运行时查找顺序 |
|---|---|---|---|
| 美术 | `art/ai/<类别>/<id>.png` | `art/cards/**` | human → ai → placeholder |
| 音乐 / 音效 | `audio/ai/<music|sfx>/<id>.ogg` | `audio/cards/**` | human → ai → 静音占位 |
| 台词正文 | `data/cards/text_ai/**`（与 `data/cards/text/**` 同结构、同键） | `data/cards/text/**` | human → ai → 开发版显示【稿】+ brief |

- 每个 AI 产物都要登记来源：`_provenance: "ai:<工具>:<模型>:<日期>:<提示词或任务 id>"`（台词写在每个文件的 `_meta` 里，图和声音写在清单里）。
- AI 线可以写 `*_ai/**` 和 `art/ai/**`、`audio/ai/**`，**人写路径（`data/cards/text/**`、`art/cards/**`、`audio/cards/**`）仍然只归人**；归属表与 `check_pr_paths.py` 照此登记新路径。
- 这一版在 Steam 上做 AI 内容声明（美术、音频、文字都写上）；K15 审核工具按来源统计 AI 产物，出包分“带声明版”和“不带声明版”（后者只用人做的，缺的报错）。
- 台词写法照设计：贴近生活、不分黑白、伪字、不写血腥、1950 年代只写成政策事件；对话是载体，每张牌的演出块（合同 §4.7.24）引用的键都要有正文。
