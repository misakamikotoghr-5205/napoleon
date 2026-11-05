# 德厚当 · 卡牌版 —— 任务交接板（38 条并行线）

> **10-19 框架版已收尾，本文是 W0–W1 时期的历史记录。现在的状态和下一阶段要做什么，看仓库根目录的 [`HANDOFF.md`](../../HANDOFF.md)。**

> **维护人**：Claude（编排）· 2026-10-13 · 仓库 https://github.com/misakamikotoghr-5205/dehoudang · 集成分支 `claude/festive-ride-vud32a`
> **这页是什么**：卡牌版开发的总入口：改了什么、谁做什么、什么时候合、38 条任务的清单、PR 怎么提、Claude 怎么审。**这页只是索引和流程，规范在合同里**——优先级：主创原话（`docs/cards/DESIGN_cards.md`）> 接口合同（`docs/cards/CARDS_INTERFACES.md`）> 任务卡（本目录）> 本页。
> **执行方不改本目录里的任何文件**（任务卡、开场提示、本页都归 Claude）；进度和回报写在自己的 PR 里，状态由 Claude 在合并后更新（本页第 4 节与 `docs/cards/STATUS.md` 同步，两处不一致以 `STATUS.md` 为准）。
> 走动版的旧交接板 `docs/handoff/README.md`（T01–T07，已全部合并）只作存档，不再派任务。
> **最新变更**：10-13 晚 **画面与对话**（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6；原型 docs/cards/prototype/）；10-13 打烊永远可用（合同 1.2）——见[第 10 节 变更记录](#10-变更记录)，每条线都看一眼自己那一行。

## 目录

1. [改了什么：从走动的当铺模拟改成卡牌游戏](#1-改了什么从走动的当铺模拟改成卡牌游戏)
2. [角色](#2-角色)
3. [波次、合并顺序与目标日期](#3-波次合并顺序与目标日期)
4. [任务板：38 条任务](#4-任务板38-条任务)
5. [新手指引（主创 2026-10-13 硬性要求）与指引引擎归谁](#5-新手指引主创-2026-10-13-硬性要求与指引引擎归谁)
6. [PR 流程与 Claude 审核关](#6-pr-流程与-claude-审核关)
7. [硬规则摘要](#7-硬规则摘要)
8. [开场提示与任务卡](#8-开场提示与任务卡)
9. [Claude 的待办（开工前与 W1 中）](#9-claude-的待办开工前与-w1-中)
10. [变更记录](#10-变更记录)

---

## 1. 改了什么：从走动的当铺模拟改成卡牌游戏

v0.4.2「只守铺子」是走动式的小镇当铺模拟。主创 2026-10-12 定下**卡牌版玩法设计 v1**、2026-10-13 定下 **v1.1** 与**新手指引硬性要求**，游戏改成卡牌游戏：

- **每天发一手牌**：进门的人（人物牌：当、卖、买、赎、求助、打听）、街上的事（事件牌）、命运牌、生活牌（米、煤、看病、人情……）、消息牌；夜里三张夜牌选一张；日结。一个月是一关，月底结账，打完跳一年（满当、档案簿“一年后”）。首发三关：1938 年 3 月、1939 年腊月、1940 年 3 月；1949 年解放后按攒下的东西选新行当（预留，首发不做）。
- **核心机制**：柜台三档出价（压价 / 公道 / 厚道）；鉴定小游戏只给含糊的观察（找不同、吹银元、称分量、拼碎片、解密）；放格子、掷铜钱（看得见的检定）；留着的牌；胡二的条子（每周一张、七天期限、四类四档）；命运与大命运；抵押与流落街头（破产阶梯）、牢房与打点；口碑 / 风声（只给五档文字）、本心（藏着）；人脉；档案簿碎片化叙事。
- **v1.1 新增**：**命运轮盘**（每关开头转一次定本月运势；快输时大命运改成转“大轮盘”：翻身 / 平安 / 坠底；庙会、赌摊可以自己选去转；转之前往“香案”放香火钱、留着的牌、人脉让好扇区变宽——只看扇区大小，不显示百分比；扇区随年代变）；**算命**（每天告示上的黄历宜忌；算命先生 / 测字摊 / 城隍庙求签——签文含糊地预示接下来几天真的会抽到的牌，由种子决定所以签是“准”的；测字按挑的字给提示；本心低时签更凶）；**金色角色牌**（主线人物在主线节点上以金色牌框出现、排在手牌最前、当天必须处理，不处理他就走了，主线按“没理他”走、档案簿留下缺口）。
- **新手指引**：所有机制都必须有在戏里讲的新手指引（第 5 节）。
- **旧代码只读复用、不改**：`JevRng`（唯一的随机来源）、`town_sim.gd` 的牌库权重思路、`WorldWheel`、`PressureModel`、`ItemGen`、`ledger.gd`（G04 的 `card_ledger.gd` 继承它）、`cond.gd`（借形状）、`save.gd`、`protection.gd`（保护费的升级阶梯 → 条子）、`appraise.gd` + `flaw_render.gd`（C12 只 `preload` 来算和画；`appraise_panel.gd` 只参考、不实例化）、`UiStyle` / `TownUI`、`settings.gd`、`pause_menu.gd` / `guide.gd` / `help_panel.gd`（只参考做法）、`music_director.gd`（只参考）。旧版照旧能玩（开发版用 `--cards` 进卡牌版）；**Steam 包只含卡牌版**，旧版的代码、文字、美术、音乐不进包。
- **画面与对话**（10-13 晚，主创：“打牌是玩法，对话是载体”）：画面是像素柜台场景（320×180 整数 4 倍），客人走进门、在对话框里说话，你的选择是回话；手牌是最下面的炉石式扇形，沈如花的头像在左边；两侧标签抽屉；“打烊 · 下一天”在右侧中下。

**设计与规范文档**

| 文档 | 是什么 | 谁维护 |
|---|---|---|
| [`docs/town/cards/德厚当_卡牌版_玩法设计.pdf`](../town/cards/德厚当_卡牌版_玩法设计.pdf) | 玩法设计 v1 + v1.1 的 PDF（主创定稿） | 主创 / Claude 排版 |
| [`docs/town/cards/src/build_design.py`](../town/cards/src/build_design.py) · [`era.json`](../town/cards/src/era.json) | PDF 的生成源（HTML 写在 Python 字符串里）；年代表与**史实措辞要求**（`notes`：“伪”字、1945、1949、1950 年代） | 同上 |
| [`docs/cards/DESIGN_cards.md`](../cards/DESIGN_cards.md) | 上面两份的 Markdown 版 + v1.1（§九.1–九.3）+ 新手指引（§九.4）+ 打烊 · 下一天（§九.5）+ 画面与对话（§九.6），给读不了 PDF 的执行方；文末“实现时的理解”标明**不是主创原话** | Claude |
| [`docs/cards/CARDS_INTERFACES.md`](../cards/CARDS_INTERFACES.md) | **接口合同 1.3**：九条红线、目录与归属表、38 条任务的范围与验收、数据格式与校验规则、DSL、状态与随机数域、冻结接口、画面与演出、小游戏插件、轮盘与签、金色牌、免 AI 声明与审核、测试与性能、PR 与波次、完成定义与审核清单 | Claude（改合同走 `[api]` issue） |
| [`docs/cards/prototype/`](../cards/prototype/) | 网页原型（画面与对话的样子）+ 截图 + 说明；只看做法，坐标以合同 §7.11 为准 | Claude |
| [`docs/cards/STATUS.md`](../cards/STATUS.md) | 38 条线的实时状态板 | Claude |
| [`docs/cards/ownership.json`](../cards/ownership.json) | 归属表的机器可读版（CI 的路径检查按它查） | Claude |
| [`docs/town/plan/德厚当_交付时间线与里程碑.pdf`](../town/plan/德厚当_交付时间线与里程碑.pdf) | 2026-10-12 按走动版排的交付计划（文字锁定 1/8、发售 1/28）。卡牌版要按本页的波次重排 **【待主创定】** | Claude |

---

## 2. 角色

| 角色 | 谁 | 做什么 | 不做什么 |
|---|---|---|---|
| 主创 | A、B（两人团队） | 定玩法；回答 `[design]` issue；定【待调】的数（合同里原来“【待主创确认】”的几处，主创 10-13 已回复“同意你说的九点”）；开三家执行方的窗口并贴开场提示 | — |
| **人 A** | 剧情 · 美术 | **所有最终的玩家正文**（剧情、牌面、人物名、签诗与解曰、测字提示、观察句、物品文字、开场段落、电码本的词、新手指引台词 `say` / 气泡 `bubble`、规矩页 `title` / `body`）；**所有正式美术**（牌框、头像、插图、背景、轮盘面、图标；外包也按禁 AI 合同）；正式配色 `palette.json`；W3 主力 | 不用 AI 生成任何发行内容 |
| **人 B** | AI 辅助编程 · 音乐 | AI 辅助写代码（代码 PR 和三家一样走 CI 与 Claude 审核）；**音乐与音效**（`audio/cards/**`）；界面文字（按钮、F1 帮助的操作说明、设置里“新手提示”那一行——合同 §11.3 记 `human:B`）；字体子集（`fonts/**`：W3 加正文后跑 Claude 维护的 `tools/build_fonts.py`） | 发行内容（音频、界面文字）不用 AI 生成；**AI 辅助的代码 PR 和手写内容的 PR 分开**：代码走普通分支、不碰人写路径；手写内容只走 `ui-text/<主题>` 分支 |
| **Claude** | 编排 / 监督 / 审核 | W0 骨架、合同与任务卡、本页与 `STATUS.md`；**审每一个 PR**（第 6 节）并合并（squash）；W2 集成（把牌桌默认换成真引擎、`X##` 修补任务）；黄金种子重算；`cjk_allowlist.json`；Steam 导出预设、`tools/package_steam.sh`、Steam 接入（成就、云存档） | 不写玩家正文、正式美术、音频 |
| **Cursor** | 16 条线：C01–C16 | 界面场景、控件、小游戏、**新手指引引擎**（C16）、前端接入 | 不写正文、美术、配色、音频 |
| **Grok** | 16 条线：K01–K16 | 牌的数据骨架（机制 + `brief`）、占位美术管线与美术规格、史实与敏感审读、QA 自动化、来源审核工具、**新手指引步骤与规矩页骨架**（K16）、解放后分支设计 | 不写正文字段，`brief` 不写成台词 |
| **GPT** | 6 条线：G01–G06 | 引擎、后端、破产阶梯、无头自动玩与数值平衡 | 不产出说明文字（只给错误码和正文**键**） |

三家共 **38 条线同时开工**；每条线只改归属表里写着自己任务号的路径，依赖别人还没做完的东西一律对着 W0 的**桩**和 **Mock 引擎**做，不等（合同 §0 并行规则）。

---

## 3. 波次、合并顺序与目标日期

> **下表所有日期都是目标，不是承诺。** 今天 2026-10-13（周二）。滑了由 Claude 在 `STATUS.md` 里重排并通知受影响的线。

| 波次 | 时间（目标） | 谁 | 内容 | 进入条件 | 完成条件（合同 §13.4） |
|---|---|---|---|---|---|
| **W0 骨架** | 已完成 10-13；**10-14 前**合入集成分支（W0 合入点：提交 `b87a641`） | Claude | 合同附录 A：冻结接口、能跑的最小核心、全部模块的同签名桩、Mock 引擎与十个夹具、指引的桩（`CardGuide` 最小挑步骤、`CardAnchors`）、`--cards` 牌桌、测试清单与 runner、审核钩子、`.github/` | 合同 1.1 | 合入（W0 合入点：提交 `b87a641`）；`run_card_tests.sh` 绿；CI 设成必过；38 条线开工 |
| **W1 并行开发（对着 Mock / 桩）** | **≈ 10-14 → 10-30** | 38 条线 | 引擎对着桩、界面对着 Mock、数据对着校验器 default 模式、工具对着夹具 | W0（提交 `b87a641`） | G01–G05 合入，G06 的破产阶梯合入；C01–C04 合入；**C16 的新手指引引擎合入**；K01、K02、K07、K09、K10、K11 合入；**K16 的指引步骤、规矩页与 `tutorial.json` 合入**；1938 数据 strict 校验全绿（允许的悬空引用清单为空） |
| **W2 集成** | **≈ 11-02 → 11-13** | Claude + 原主人 | 牌桌默认换成真引擎（`--cards-mock` 保留）；每个界面任务补一个对真引擎的集成测试、用 K16 的 `steps.json` 复测自己的指引步骤；K 数据悬空引用补齐；G06 真数据平衡报告与 `balance_overrides.json`；K13 修正；K14 真界面走查与截图、**第 1–3 天指引走查（真引擎）与逐步截图**；K15 审核演练（失败项 = 还没写的正文和美术 = 给 A/B 的清单）；Claude 做 Steam 接入 | W1 完成条件 | 三关可以从标题玩到首发结尾；所有测试绿；strict 校验绿；**新存档第 1–3 天的指引测试在真引擎上绿、每一步有截图**；审核只剩“正文 / 美术未写”这一类 |
| **W3 内容** | **≈ 11-16 起**（结束日按重排后的交付计划 **【待主创定】**） | A（正文、美术）、B（界面文字、音频）；AI 线只修 bug | 按 K15 `missing_text.py` 的待写清单写正文、画图、录音，登记来源 | W2 完成条件 | `validate --mode=ship` 绿；`audit.py` 0 违规；A、B 签 `AUDIT_SIGNOFF.md` |

**首个可玩的 1938 关：目标 11-13（W2 末）**——从标题进第一关、玩满 30 天、月底结账、跳年过场，全用占位正文（开发版显示【稿】+ brief）和占位美术，第 1–3 天的新手指引在真引擎上按顺序亮。三关通到首发结尾是 W2 的完成条件，目标同日；1939 / 1940 的数据如果拖后，1938 关先出可玩版，剩下的由 Claude 开 `X##` 任务收尾。

**W1 里的合并先后**（不是开工先后——大家同时开工，只是合并有先后）：

- 引擎：**G01 → G03 → G04 / G05 → G06 破产阶梯 → G02 → G06 自动玩**。
- 界面：**C02、C03 的控件 PR 与 C04 的对话框先合**（10-21；C03/C05/C07/C08/C11 的演出用对话框）；C16 的指引引擎、C01 的画面根尽早合；C16 早于各界面任务 W2 的指引复测。
- 数据：随时可合（只要校验器 default 绿）。**别人在等的先交**：K01 的 `passersby.json`（算命先生 `suanming`）、K02 的 `bf.wheel` `ev.any.wheel_go` 与算命摊 / 庙会 / 赌摊、K04 的通用命运、K06 的通用生活牌、K09 的教学用牌（`self.ruhua` `kp.brother_note` `ct.zhouma` 夜牌 `pr.cell`）、K11 的现有模板参数、K12 的牌框与指引用图、K16 的第 1–3 天步骤。演出块（1.3）另开 PR，等 G01 的 1.3 小 PR 合入（10-15）。

**依赖图：开工 vs 合并**（合同 §13.4；交接包审计时用脚本验过无环）

- **开工只依赖 W0**：38 条线在 W0（提交 `b87a641`）上同时开工，别人的东西一律先用 W0 的桩、`MockCardEngine`、`_examples`、自己的夹具；“主要依赖”一列里的线都是**软依赖**（接口已冻结，对着桩做，等对方合入后再接真的）。
- **合并的硬依赖**（左边的 PR 要等右边先合入才能合；没列的 PR 只依赖 W0，随时可合）：

| 要合的 | 先要合入 | 为什么 |
|---|---|---|
| G03 | G01 | `CardPiles` / `CardFirsts` 的真实现 |
| G04、G05 | G03 | 选项、格子、名声的真实现 |
| G06 破产阶梯 | G04、G05 | `money_short` 钩子、`pay`、危机检查 |
| G02 最后一个 PR（接真模块） | G06 破产阶梯 | 端到端测试要全部真模块 |
| G06 自动玩 / 黄金种子 | G02 | 要真的日循环 |
| C01、C03、C08、C10 | C02 的控件 PR | 嵌 `CardWidget` 的正式版（接口不变，只是先后） |
| C05、C06、C11 | C03 的控件 PR | 复用 `CardSlotWidget` / `CardCoinTossView` |
| K16 第 2 个 PR（`suanming` 教的步骤） | K01 的 `passersby.json` PR | V31 要 `suanming` 已登记 |
| K01–K09、K16 的演出块 PR | G01 的 1.3 小 PR | schema 里有 stage 才不报 V03 |
| C03、C05、C07、C08、C11 的演出 PR | C04 的对话框 PR | 演出用 CardDialogBox（开发时用 W0 的桩，合并要真的） |
| K14 画面版截图 | C01 的画面根 | 截图要真画面 |
| **W1 完成**（`STATUS.md` 宣布） | G01–G05、G06 破产阶梯、C01–C04、C16、K01、K02、K07、K09、K10、K11、K16 前三个 PR（步骤、规矩页、`tutorial.json`） | 合同 §13.4 |
| X01（Claude 把牌桌默认换成真引擎） | W1 完成 | — |
| K14 真引擎走查、K15 审核演练、K13 审读 issue、各界面任务 W2 复测 | X01（K13 另等对方写“交付”） | W2 |

所有边都从 W1 指向更早的 W1 或 W0，W2 只依赖 W1——没有环，也没有 W1 的任务要等 W2。

**检查点（全部是目标）**

| 日期 | 检查点 |
|---|---|
| 10-13（二） | 合同 1.1/1.2、W0、38 张任务卡、开场提示；**晚上：合同 1.3（画面与对话）、W0 同步、任务卡“10-13 变更二”** |
| 10-14（三） | W0 合入（提交 `b87a641`）、38 条线开工（已开工）；1.3 合入集成分支，各线 rebase |
| 10-15（四） | **G01 的 1.3 小 PR**（schema 加 stage、V38–V42）合入——K 线的演出块从这天起可以提 |
| 10-16（五） | 每条线第一个小 PR 提审（先骨架 + 测试） |
| 10-20（二） | G01、G03 合入；K16 第 1–3 天步骤合入（锚点已按 1.3 改好；`W0_table_3days` 在 1.3 的 W0 同步里已改成新旧锚点都认） |
| 10-21（三） | **C02 控件（牌、手牌扇、头像）、C03 控件（格子、铜钱、柜台格子）、C04 的对话框**合入（原 10-20 的 C02/C03 后移 1 天；对话框新加，其他演出等它）；G02 的视图增补（`stage`、CardView 新字段、`night_offers` 字典）合入 |
| 10-23（五） | G04、G05、G06 阶梯合入；**C16 指引引擎**合入（原 10-20，后移 3 天）；K01、K02、K07、K09、K10、K11 的骨架 PR 合入 |
| 10-27（二） | **C01 画面根（场景层、HUD、标签抽屉、宿主）与 C04 柜台演出、货架/当票抽屉**合入（原 10-23，后移 4 天）；G02、G06 自动玩合入；1938 的演出块（K01 K02 K09 K16）与 K12 的新美术类别合入 |
| 10-29（四） | C03 C05 C07 C08 C11 的演出合入；C10 档案簿抽屉合入 |
| 10-30（五） | 1938 strict 全绿、悬空为 0；**W1 完成条件检查**（原 10-27，后移 3 天） |
| 11-02（一） | W2 开始：X01（默认换真引擎；删 7 个旧锚点名与兼容；W0 的 `w0_stub.gd` 和 `_w0/` 桩在主人都合入后删） |
| 11-05（四） | 各界面任务对真引擎的集成测试与 K16 步骤复测；**K14 真引擎第 1–3 天指引走查 + 每步画面截图** |
| 11-09（一） | G06 真数据平衡报告；K15 审核演练；K13 审读修正 |
| 11-13（五） | **首个可玩 1938 关（画面版）**；W2 完成条件检查 |
| 11-16（一）起 | W3：A / B 写正文、画图（含柜台三张背景、群演、道具）、录音 |

---

## 4. 任务板：38 条任务

状态：`待开工`（W0 已合入）→ `进行中` → `已提审` → `改了再合` → `已合并（部分）` → `交付`（最后一个 PR 写了“交付”）→ `W2 集成中` → `完成`。**粗体**的“完成条件”= 合同 §13.4 点名的波次完成条件。依赖只列主要的，全部见各任务卡“依赖”一节；**所有依赖都可以先对着 W0 的桩、Mock、`_examples` 做，不用等**。

### GPT（6 条线）：引擎、后端、破产阶梯、数值

| ID | 执行方 · 线 | 任务 | 主要依赖 | 波次 | 状态 |
|---|---|---|---|---|---|
| [G01](G01_core-model.md) | GPT 线 1 | `core-model` 卡牌模型、牌堆、发牌组合、存档、校验器、正文、总线、first-time 记录 | W0 | W1 · 合并① · **完成条件** | 待开工 |
| [G02](G02_loop-engine.md) | GPT 线 2 | `loop-engine` 门面 CardEngine、日/周/月/年状态机、日程、金色牌、目标、跳年、视图 | W0；G01、G03、G04、G05、G06 阶梯（对着桩做，最后一个 PR 接真模块） | W1 · 合并⑤ · **完成条件** | 待开工 |
| [G03](G03_slots-dsl.md) | GPT 线 3 | `slots-dsl` 放格子与掷铜钱、效果/条件 DSL、属性与三项名声、条子、档案簿 | W0；G01；钱（G04）、`arrest`（G06）先用桩 | W1 · 合并② · **完成条件** | 待开工 |
| [G04](G04_economy.md) | GPT 线 4 | `economy` 柜台、货架、当票、鉴定桥、物品、货币、月账 | W0；G01、G03；G06 的修正项先用桩；K11 物品数据（先用 `_examples`） | W1 · 合并③ · **完成条件** | 待开工 |
| [G05](G05_fate-fortune.md) | GPT 线 5 | `fate-fortune` 牌库权重、命运与大命运、命运轮盘、求签测字、黄历 | W0；G01（`project()`）、G03；G02 的 `CardSchedule.due`、G06 先用桩；K10 数据（先用 `_examples`） | W1 · 合并③ · **完成条件** | 待开工 |
| [G06](G06_ladder-autoplay.md) | GPT 线 6 | `ladder-autoplay` 破产阶梯（家当与抵押、钱不够、街头、牢房）、无头自动玩、蒙特卡洛平衡、黄金种子、性能基准 | W0；阶梯：G01、G03、G04、G05；自动玩：G02；平衡报告：K 数据 | W1 · 阶梯合并④（**完成条件**）、自动玩合并⑥；W2 平衡报告 | 待开工 |

### Cursor（16 条线）：界面、控件、小游戏、新手指引引擎、前端接入

| ID | 执行方 · 线 | 任务 | 主要依赖 | 波次 | 状态 |
|---|---|---|---|---|---|
| [C01](C01_table.md) | Cursor 线 1 | `table` 画面根、场景层、HUD、两侧标签与抽屉宿主、打烊按钮、叠层与小游戏宿主、**指引宿主**、配色 | W0（嵌入的控件和面板全用桩） | W1 · 尽早合 · **完成条件** | 待开工 |
| [C02](C02_card-widget.md) | Cursor 线 2 | `card-widget` 牌、牌框、金色牌、留牌标记、放大、拖拽、美术解析、手牌扇、英雄头像 | W0 | W1 · 早合（C01/C03/C05/C08/C10/C11 用它） | 待开工 |
| [C03](C03_slots-coins.md) | Cursor 线 3 | `slots-coins` 柜台上的格子与铜钱、选项与检定的演出、消息/当票的演出、人脉抽屉、人脉满、留牌满 | W0 | W1 · 早合（C05/C06/C11 复用）· **完成条件** | 待开工 |
| [C04](C04_counter.md) | Cursor 线 4 | `counter` 对话框、柜台的演出（当、卖、买、赎与人物牌的选项）、货架与当票抽屉 | W0（小游戏由 C01 的宿主打开，先用桩） | W1 · **完成条件** | 待开工 |
| [C05](C05_demand.md) | Cursor 线 5 | `demand` 条子板与条子面板（条子抽屉 + 胡二那一出） | W0；C03 的 SlotWidget / CoinToss（先用桩） | W1 · C03 之后合 | 待开工 |
| [C06](C06_wheel.md) | Cursor 线 6 | `wheel` 命运轮盘面板（本月运势、大轮盘、庙会/赌摊） | W0；C03 的 SlotWidget（香案，先用桩） | W1 · C03 之后合 | 待开工 |
| [C07](C07_fortune.md) | Cursor 线 7 | `fortune` 黄历条、算命摊、求签、测字（黄历条进 HUD、黄历抽屉、算命那一出） | W0 | W1 | 待开工 |
| [C08](C08_night-settle.md) | Cursor 线 8 | `night-settle` 打烊确认、夜里打夜牌、日结在对话框里说 | W0（牌用 C02 的桩） | W1 | 待开工 |
| [C09](C09_month-year.md) | Cursor 线 9 | `month-year` 开月、月底、跳一年、局终 | W0；K02/K04/K06 的 `stage.json`（先用 `_examples`） | W1 | 待开工 |
| [C10](C10_dossier-help.md) | Cursor 线 10 | `dossier-help` 档案簿（左抽屉）、**规矩页**、**F1 帮助** | W0；K16 的规矩页、K08 的档案（先用 `_examples`） | W1 | 待开工 |
| [C11](C11_ladder.md) | Cursor 线 11 | `ladder` 家当与抵押、钱不够、街头、牢房（家当抽屉、牢房那一出、街头按钮） | W0；C03（牢房的格子与铜钱，先用桩） | W1 · C03 之后合 | 待开工 |
| [C12](C12_mg-spot.md) | Cursor 线 12 | `mg-spot` 找不同（从旧验货面板分出来重写） | W0（`day_counter` 夹具带真 ItemGen 布局） | W1 | 待开工 |
| [C13](C13_mg-coin-ring.md) | Cursor 线 13 | `mg-coin-ring` 吹银元 | W0；W2 接 G04 / K11 的参数；W3 B 录的声音样本 | W1 | 待开工 |
| [C14](C14_mg-weigh.md) | Cursor 线 14 | `mg-weigh` 称分量 | W0；W2 接 G04 / K11 的参数 | W1 | 待开工 |
| [C15](C15_mg-fragments-decode.md) | Cursor 线 15 | `mg-fragments-decode` 拼碎片 + 解密 | W0；K11 的电码本骨架、K08 的电报（先用 `_examples`） | W1 | 待开工 |
| [C16](C16_guide-shell.md) | Cursor 线 16 | `guide-shell` **新手指引引擎**（`CardGuide` + 覆盖层）+ 卡牌版的标题、暂停、设置、曲目；教的人在画面里开口 | W0（`CardGuide` 最小版、`CardAnchors`、指引查询）；K16 的步骤（先用 `_examples`） | W1 · 尽早合 · **完成条件** | 待开工 |

### Grok（16 条线）：数据骨架、美术管线、审读、QA、审核工具、指引骨架、分支设计

| ID | 执行方 · 线 | 任务 | 主要依赖 | 波次 | 状态 |
|---|---|---|---|---|---|
| [K01](K01_data-1938-people.md) | Grok 线 1 | `data-1938-people` 1938 人物牌、主线节点（含金色牌）、过路客 | W0；K08 / K09 / K11 / K12 / K16 并行对 id | W1 · **完成条件**；先交 `passersby.json` | 待开工 |
| [K02](K02_data-1938-world.md) | Grok 线 2 | `data-1938-world` 1938 事件、命运、大命运、生活、目标、开场 + 通用事件与大赌 | W0；K10、K09、K08、K01、K12 并行对 id | W1 · **完成条件**；先交 `bf.wheel` 等 | 待开工 |
| [K03](K03_data-1939-people.md) | Grok 线 3 | `data-1939-people` 1939 腊月人物牌、主线节点 | W0；K01 的走向名表；K04、K08 并行 | W1（越早越好）；W2 strict 绿 | 待开工 |
| [K04](K04_data-1939-world.md) | Grok 线 4 | `data-1939-world` 1939 事件、命运、大命运、生活、目标、开场 + 通用命运 | W0；K03、K10、K08 并行 | W1；先交通用命运 18 张 | 待开工 |
| [K05](K05_data-1940-people.md) | Grok 线 5 | `data-1940-people` 1940 三月人物牌、主线节点 | W0；K01 / K03 的走向名表；K06、K08、G02 并行 | W1；W2 strict 绿 | 待开工 |
| [K06](K06_data-1940-world.md) | Grok 线 6 | `data-1940-world` 1940 事件、命运、大命运、生活、目标、开场 + 通用生活牌 | W0；K05、K07、K09、K10 并行 | W1；先交通用生活牌 | 待开工 |
| [K07](K07_data-demand.md) | Grok 线 7 | `data-demand` 条子（4 类 × 4 档 × 3 年） | W0；G03 的规则（以合同为准）；K08、K11、K12 | W1 · **完成条件** | 待开工 |
| [K08](K08_data-news-dossier.md) | Grok 线 8 | `data-news-dossier` 消息牌、档案簿页与碎片 | W0；收集 K01 / K03 / K05 等引用的碎片 id；K11、K16 | W1（1938 悬空为 0 的关键） | 待开工 |
| [K09](K09_data-common.md) | Grok 线 9 | `data-common` 留着的牌、人脉、家当、夜牌、街头、牢房、你自己、群演 | W0；G03 / G06 的规则；K08、K10、K12 | W1 · **完成条件**；先交教学用牌 | 待开工 |
| [K10](K10_data-fortune.md) | Grok 线 10 | `data-fortune` 轮盘与扇区、签、测字、黄历 | W0；G05 的规则；K02 / K04 / K06 的大赌清单；K12 | W1 · **完成条件** | 待开工 |
| [K11](K11_data-items-mg.md) | Grok 线 11 | `data-items-mg` 物品 → 小游戏参数、首发物品表、新物品模板、电码本骨架 | W0；G04、C12–C15、K08、K12、K16 | W1 · **完成条件** | 待开工 |
| [K12](K12_art-pipeline.md) | Grok 线 12 | `art-pipeline` 占位美术生成器、美术清单、给画师的美术规格；画面美术类别 | W0（清单初版）；各 K / C 线的美术 id（滚动）；Claude 在 CI 装 Pillow | W1 生成器；W2 补齐 | 待开工 |
| [K13](K13_review-history.md) | Grok 线 13 | `review-history` 史实与敏感审读 | W0；K01–K11、K16 写了“交付”之后；K15 | W1 工具；W1 末–W2 审读 | 待开工 |
| [K14](K14_qa-automation.md) | Grok 线 14 | `qa-automation` QA 自动化、截图、**指引走查**、问题模板 | W0（牌桌、Mock、`CardGuide` 测试钩子）；C01–C16、K16、G01–G06；Claude 在 W2 换真引擎 | W1 Mock 走查；**W2 真引擎第 1–3 天走查（完成条件）** | 待开工 |
| [K15](K15_audit-provenance.md) | Grok 线 15 | `audit-provenance` 来源审核工具（Steam 免 AI 声明） | W0（`check_pr_paths.py`、“关着门”的 `audit.py`）；G01 的 ship 校验、K13、K12；Claude 的 Steam 预设；A / B（W3） | W1 工具；W2 演练；W3 0 违规 | 待开工 |
| [K16](K16_guide-data-post1949.md) | Grok 线 16 | `guide-data-post1949` **新手指引步骤与规矩页骨架**、教学日的牌、解放后分支设计 | W0；K01（`suanming`、哥哥告别）、K08、K09、K11；C16；Claude 先改 W0 测试 | W1 · **完成条件**；分支设计 W1–W2 | 待开工 |
| [K17](K17_officialdom-open.md) | Grok（1.4 跨线，#182 第 5 条） | `officialdom-open` **官场开头**：1940 金色牌“请你当保长”、first `office`、指引 `gd.office` | 合同 1.4（#183）；G03 发牌钩子；K16 `steps.json`、规矩页 `rule.gold` | 1.4 | 进行中（PR #184） |
| [K18](K18_apprentice.md) | Grok（#182 第 3 条） | `apprentice` 收徒：会成长的人脉、隐藏忠心、不在铺时看铺、偷/通风/接班 | 合同 1.4（#187）；§九.7 | 首发 1939 | 进行中 |

---

## 5. 新手指引（主创 2026-10-13 硬性要求）与指引引擎归谁

**主创原话（硬性要求）**：所有机制都必须有新手指引。①讲在游戏世界里：由人物开口，不是系统说明书弹窗；②第一次遇到某机制时触发，按天逐步解锁，不一次灌给玩家；③教过的都能回看（档案簿“规矩”页 + F1 帮助），可以在设置里关掉；④不打断节奏，自动试玩 / 测试里可以关；⑤高亮对应的界面元素（锚点），一句气泡说清楚“现在可以做什么”；⑥最终教学文字由人类 A 写，AI 只写 brief 与占位。落到合同里是**红线 8**和 **§7.10** 全节（数据格式 §4.7.21，校验 V29–V36）。原来的“规矩牌”取消——规矩由指引在戏里讲，不占手牌。

### 5.1 指引引擎归 C16

**指引引擎（`CardGuide` + `GuideOverlay`）归 Cursor 线 16 的 C16 `guide-shell`**——并入原来的 C16，和卡牌版的标题、暂停、设置、曲目放在一起（设置里的“新手提示：开 / 关”、暂停里的“帮助”都在这个外壳里）。为了三家线数不变，原 C16 的解密小游戏并进 C15（`mg-fragments-decode`），C10 加规矩栏与 F1 帮助，K16 改为 `guide-data-post1949`。**线数仍是 Cursor 16、Grok 16、GPT 6。**

| 部分 | 主人 | 位置 / 接口 |
|---|---|---|
| 三个总线信号 `first_time` `command_done` `ui_event`（签名冻结）；锚点登记 `CardAnchors`（冻结）；`CardGuide` / `GuideOverlay` / `HelpPanel` 的桩（W0 的 `CardGuide` 已能按 `trigger` 挑步骤） | Claude（W0，已交） | `scripts/cards/core/card_bus.gd`、`scripts/cards/ui/common/card_anchors.gd` |
| **指引引擎与覆盖层**：挑步骤（priority、interrupt、间隔、`max_shows`、`after`、`done_when`、自动完成、每天新步骤上限）、锚点高亮、气泡、教的人头像与台词、渐隐、存进度、开关、测试钩子；参数 `rules/guide.json` | **C16（Cursor 线 16）** | `scenes/cards/shell/GuideOverlay.tscn`、`scripts/cards/ui/shell/card_guide.gd` |
| 引擎一侧：`CardFirsts`（`core.firsts`）、`ui` 命名空间与指令 `ui.guide`、查询 `firsts` `guide_data` `guide_progress` `guide_conds` | G01 | `scripts/cards/core/firsts.gd`、`core_install.gd` |
| 每个机制第一次出现时 `CardFirsts.mark()`（66 个机制各有一个发出者） | G01–G06（合同表 7.10.10） | 各自模块 |
| `command_done`（每条指令收尾） | G02 | `scripts/cards/loop/card_engine.gd` |
| 指引宿主（最上层 CanvasLayer 100、整层鼠标穿透）、F1 转帮助、`--guide=on|off` | C01 | `scenes/cards/CardGame.tscn` |
| 规矩栏（档案簿）、F1 帮助面板（解锁只看 `firsts`，和指引开关无关） | C10 | `scenes/cards/dossier/**` |
| 各界面部件的锚点与 `ui_event` | C01–C16 各自（合同表 7.10.5） | 各自目录 |
| **步骤与规矩页骨架**（`brief` + 机制字段，正文留空）、`_test.d1_3`、教学日的牌 | **K16（Grok 线 16）** | `data/cards/guide/{steps,rule_pages}.json`、`data/cards/era/1938/tutorial.json` |
| 步骤与规矩页的 brief 审措辞（不提概率、点数、本心） | K13 | `tools/cards/review/**` |
| 待写清单里列出每步的 `say` / `bubble`、每页的 `title` / `body`；发行审核查正文齐、无 `%` | K15 | `tools/cards/audit/**` |
| 真引擎上第 1–3 天的指引走查与逐步截图 | K14（W2） | `scripts/tests/cards/K14/test_guide_d1_3.gd`、`shot_guide_d1_3.gd` |
| 步骤与规矩页**正文**；F1 帮助的操作说明、设置里那一行 | 人 A；人 B | `data/cards/text/guide/**`；`data/cards/text/ui/{C10,C16}.text.json` |

### 5.2 合同定义的指引系统（全部已冻结，见合同 §7.10）

- **步骤数据格式**（`guide_step`，§4.7.21）：`id`（`gd.<slug>`）、`teaches`（教哪些机制）、`trigger`（`first` 机制第一次出现 · `phase` · `mode` · `stage_gte` / `stage_day_gte` / `abs_day_gte` 按天解锁 · `after` 前置步骤 · `panel` · `hand_clear` · `cond` 只许看得见的条件）、`teacher`（人物 id 或 `obj.notice` / `obj.almanac` / `obj.brother_ledger`，或 `""`）、`anchor` + `anchor_fallback`（锚点 id，`a.card@{uid}` 用那次 `first_time` 的 `uid` 代入）、`done_when`（`cmd:` `ui:` `first:` `panel:` `timeout`）、`rule_page`（对应规矩页）、`priority` `interrupt` `max_shows` `seconds`、`brief`。气泡和台词的**文字键**就是 `<步骤 id>#bubble` / `<步骤 id>#say`，正文在 A 写的覆盖层里；开发版显示【稿】+ brief。规矩页 `rule_page`：`id`（`rule.<slug>`）、`order`、`unlock_first`、`teacher`、`brief`。
- **锚点注册 API**（`CardAnchors`，§7.10.4）：`register(id, node, rect_fn)` / `unregister` / `rect` / `has` / `ids` / `clear`；只存 instance id，节点离树自动注销；锚点 id 是封闭目录 `CardIds.ANCHORS`（每个 id 有一个主人任务），新锚点走 `[api]` issue。
- **first-time 事件**（§7.10.6）：机制第一次出现时模块调 `CardFirsts.mark(ctx, &"<机制>", {uid, def, kind, person, no})` → 记进 `core.firsts` → CardBus 发 `first_time(mech, args)`。机制名是封闭目录 `CardIds.FIRSTS`（66 个，含预留 `currency` `branch_pick`）。引擎不知道指引开没开，`firsts` 总是记、进状态哈希，存→读后不再发；**引擎代码不连 `ui_event`**。
- **进度存档**：`ui` 命名空间 `{"guide": {<步骤>: {shows, status, abs_day}}}`，只有指令 `ui.guide` 写；不发事件、不进指令日志、**不进状态哈希和黄金种子**；读档、重来本关取并集（教过的不再教）。
- **跳过 / 关闭**：设置“新手提示”（沿用 `settings.gd` 的 `guide_hints`）；命令行 `--guide=on|off`；`--cards-mock`、G06 的自动玩、K14 的整局走查默认关。关着指引：什么都不亮、不发 `ui.guide`；规矩栏照样按 `firsts` 解锁；F1 照样能开。**开关不改变任何游戏状态**——同种子同指令，开着和关着指引的状态哈希相同。
- **不打断**：一次只亮一步、每天新亮的有上限、两步之间留间隔；整层鼠标穿透、不吃按键、不暂停引擎、不挡任何面板的 `autoplay_step()`。
- **测试钩子**（`CardGuide`，§7.10.7）：`shown_log`（按顺序亮过的步骤）、`skip_fades`、`force(on)`、`evaluate_now()`、`active_step()`、`tick(delta_s)`（虚拟时钟）、`load_steps(data)`（不经引擎直接给测试步骤）。

### 5.3 节奏（主创给的建议节奏，【待调】；完整 66 行见合同表 7.10.10）

| 什么时候 | 教的人 | 步骤（按亮的顺序） | first-time 发出者 | 锚点主人 |
|---|---|---|---|---|
| 开局（第 1 天之前；= 月初第一次） | 哥哥沈如松 | `gd.m.open` → `gd.m.wheel` → `gd.m.incense`（开月与目标、命运轮盘与香案） | G02、G05 | C09、C06 |
| 第 1 天 | 哥哥（在柜台教） | `gd.d1.notice` → `gd.d1.deal` → `gd.d1.person` → `gd.d1.look` → `gd.d1.spot` → `gd.d1.tiers` → `gd.d1.ticket` → `gd.d1.shelf` → `gd.d1.buyer` → `gd.d1.close` → `gd.d1.night` → `gd.d1.settle`（告示、发牌与手牌、人物牌、看看东西、找不同、三档出价、当票、货架只能等买家、打烊、夜牌、日结） | G02、G01、G04 | C01、C02、C04、C12、C08 |
| 第 2 天（哥哥离家前） | 哥哥 | `gd.d2.rules` → `gd.d2.gold` → `gd.choice` → `gd.d2.keep`（回看规矩、金色牌当天必须处理、选项、留着的牌） | G02、G03、G01 | C01、C02、C03 |
| 第 3 天（教学事件） | 哥哥留下的账簿批注 | `gd.slots` → `gd.coins`（放格子与掷铜钱） | G03 | C03 |
| 第 4 天起 | 黄历；告示 | `gd.almanac`（黄历宜忌）；`gd.market_day` `gd.weather` | G05 | C07；C01 |
| 第 5 天 | 算命先生 | `gd.lot` `gd.cezi`（求签、测字） | G05 | C07 |
| 第 6 天 | 周妈 | `gd.news` `gd.dossier`（消息牌与档案簿碎片） | G01、G03 | C02、C01 |
| 第 7 天 | 周妈；胡二 | `gd.contact` `gd.tiers`（人脉、口碑与风声档位）；`gd.demand` `gd.demand_delay`（条子与七天期限、拖一拖；1938-03-01 是星期二，第一个星期一是第 7 天） | G03 | C02、C01、C05 |
| 第一次发生时 | 账簿批注 / 告示 / 胡二 / 何启明 / `""` | 命运牌 `gd.fate`、生活牌 `gd.life`、留牌过期 / 满 / 风险、人脉满、人物状态、必须处理 `gd.must`、金色牌走 `gd.gold_leave`、来赎 `gd.redeem`、其他小游戏、条子的各种结局、查封、**钱不够与抵押** `gd.money_short` `gd.mortgage`、**大轮盘**（第一次快输）`gd.big_wheel`、庙会 / 赌摊 / 押牌、**街头** `gd.street`、**牢房与打点** `gd.prison`、局终 / 重来 / 续玩 | G01–G06 | C01–C15 |
| 月底第一次 | 账簿批注 | `gd.month_close`（结账） | G02 | C09 |
| 第一次跳一年 | 账簿批注 | `gd.year_jump` `gd.year_after`（满当与“一年后”） | G02、G03 | C09、C10 |
| 预留 | — | `gd.currency`（换币，首发不换）、`gd.branch_pick`（解放后选新行当时再教新行当的牌） | G04、G02 | 预留锚点 `a.branch.list` |

第 1–3 天是固定的**教学日**（`deal.json.scripted_days`：第一关第 1–3 天只发日程牌，不随机抽），教学牌在 K16 的 `tutorial.json`，所以第 1–3 天的指引测试和种子无关。`_test.d1_3`（新存档第 1–3 天应当按顺序亮的 21 步）就是上表前四行。

**节奏和机制对不上的七处（合同 §7.10.10 a–g），按默认做，主创 10-13 已确认**：a 夜牌第 1 天晚上就要选，默认哥哥第 1 天晚上教；b 本月运势在第 1 天之前就要转，默认开局教轮盘和香案；c 抵押（以及钱不够、街头、牢房）谁教没定，默认 `teacher: ""`；d 黄历谁教没写，默认 `obj.almanac`；e 哥哥走后没点名的，默认哥哥留下的账簿批注 `obj.brother_ledger`；f 口碑风声档位默认第 7 天讲、不等换档；g 第 3 天也设成脚本日。

### 5.4 每张任务卡里的“新手指引”一节

- **界面任务（C01–C16）**：①必须用 `CardAnchors.register()` 登记的锚点；②必须发的 `ui_event`；③测试里要证明会亮的指引步骤——做法统一：用自己的夹具打开面板，断言每个锚点 `has()` 且整块在 1280×720 内；总线监听断言 `ui_event` 发出来了；挂上 `CardGuide`、`force(true)`、发对应的 `first_time` 后 `evaluate_now()`，断言 `active_step()` 就是那一步（W1 用自己测试目录里的测试步骤，W2 换成 K16 的 `steps.json` 再跑一遍）。PR 附每个步骤亮起时的截图 `guide_<步骤 id>.png`。
- **引擎任务（G01–G06）**：列出自己必须发的 first-time 机制与时机；验收都有一条“自己发的每个 first 恰好一次；存→读之后不再发；`firsts` 进哈希、`ui` 不进”。G02 另有引擎侧的第 1–3 天 first 串测试（`G02_firsts_d1_3`）。
- **数据任务（K01–K11、K16）**：写明自己的哪张牌让哪个机制第一次出现、支持哪些步骤；确认教学要用的牌。**K16 就是指引数据本身**（起步 66 步、26 页规矩、教学日的牌）。**工具任务（K12–K15）**：教的人头像与物件图标、措辞审读、待写清单与审核、走查。

### 5.5 验收（合同 §7.10.9、§14.1）

1. **C16（无头，进清单）**：夹具 `guide_d1` `guide_d2` `guide_d3`（新存档第 1–3 天按教学日程会发出的事件），`CardGuide.shown_log` **按顺序等于** `_test.d1_3`（K16 合入前用 C16 自己照合同表 7.10.10 写的 21 步测试步骤，另跑一遍 `_examples`；K16 合入后加 `--steps=k16` 一行读真 `steps.json`）；关着时什么都不亮、不发 `ui.guide`；priority / interrupt / max_shows / 间隔 / 每天上限 / 自动完成 / 备用锚点各有单测；覆盖层全部鼠标穿透。**截图**：`shot_guide.gd` 在 xvfb 下**每一步一张 1280×720**（`<步骤 id>.png`）+ 拼图，附在 PR。
2. **K14（W2，真引擎，W2 完成条件）**：`test_guide_d1_3.gd`——种子 7、新存档、`--guide=on`，用各面板的 `autoplay_step()` 走第 1–3 天，`shown_log` 按顺序等于 `_test.d1_3`；同一串指令 `--guide=off` 再走一遍，状态哈希相同；`shot_guide_d1_3.gd` **每一步一张截图**，PR 附拼图。
3. **K16**：strict 模式 V29–V36 对自己的文件全绿（每个机制至少一步、至少进一页规矩）；`_test.d1_3` 的步骤都存在、顺序合节奏表。
4. **C01–C15**：自己的锚点、`ui_event`、指引步骤都有测试（见 5.4）。**G01–G06**：自己的 first 恰好一次、存读后不再发。
5. **发行前**：步骤与规矩页正文由 A 写齐（V27），审核无 `%`、过措辞检查。

---

## 6. PR 流程与 Claude 审核关

### 6.1 分支与提交

- 从集成分支 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切 **`cards/<ID>-<slug>`**（例 `cards/C16-guide-shell`）。**分支名必须照这个格式**：CI 的路径检查按分支名认任务号，再按 `docs/cards/ownership.json` 查越界。K13 不跨线改文件（审读结论开 `[K13→K0x]` issue，由数据的主人在自己的分支改，合同 §2.6）；人写内容用 `content/<主题>`（A）、`ui-text/<主题>`（B）；W2 集成修补 `X##` 由 Claude 指派。
- 开发中用 `git rebase origin/claude/festive-ride-vud32a` 跟上，不留合并提交（rebase 后对自己的分支 `git push --force-with-lease`）。不往集成分支直接推、不自己合并、不 approve 别人的 PR、不改别人的 PR。
- 提交信息用中文写清楚做了什么（一句话摘要，空一行，要点列表）。提交前 `git status` 只能出现自己的路径；Godot 顺手改的别人的 `.uid` / `.import` 和 `project.godot` 用 `git checkout --` 还原。
- **一个 PR 只做一件事**，先小后大（先骨架 + 测试，再功能 + 截图；W2 再补真引擎集成测试与 K16 指引复测）。PR 标题 **`[<ID>] <中文摘要>`**，目标分支 `claude/festive-ride-vud32a`。

### 6.2 PR 模板

[`.github/pull_request_template.md`](../../.github/pull_request_template.md)（W0 放的，合同 §13.2）：开 PR 时自动带出。**每一节都要填**：范围与改动路径、自查清单（**全部打勾才提审**）、用到的 JevRng 域、发的 first-time / 登记的锚点 / 发的 ui_event、新加的公开函数、悬空引用与依赖、需要主创 / 编排决定的事、已知问题、截图、交付；最后一个 PR 再把任务卡末尾的“回报”表填完贴上并写“交付”。模板末尾折叠着 Claude 的审核清单（合同 §14.2），提审前可以对着自查。

### 6.3 标签

**PR 标签**（Claude 在仓库里建；执行方开 PR 时加上前三类，加不了就在 PR 里写明，Claude 补）：

| 类 | 标签 | 含义 |
|---|---|---|
| 执行方 | `cursor` `grok` `gpt` `human` | 谁的线；`human` = A / B 的人写内容 PR（CODEOWNERS 要他们本人 review） |
| 波次 | `W1` `W2` `W3` | 这个 PR 属于哪一波 |
| 审核状态 | `needs-review` → `changes-requested` / `approved` · `blocked` | 请 Claude 审 → 改了再合 / 通过（等合并顺序）· 卡在别的线或 issue 上 |
| 提醒 | `guide` · `golden-change` · `contract-gap` | 涉及新手指引（first-time、锚点、步骤、规矩页）· 黄金种子的哈希变了（PR 里必须解释）· 碰到合同缺口、等 `[api]` / `[shared]` issue |

**issue 标签**（`.github/ISSUE_TEMPLATE/` 已有模板，合同 §13.3）：`api`（合同或冻结接口要改，标题 `[api] <ID>: …`）、`shared`（要改共享文件或别人的文件，`[shared] <你的ID>→<对方>: …`，代码里先绕过去并标 `# TODO(shared#<号>)`）、`design`（设计没写到、要主创定的）、`bug`、`content`（给 A / B 的正文、美术、音频需求——只写需要什么，不写内容本身）。

### 6.4 怎么请求审核

1. 本地 `GODOT=<Godot 4.7> tools/run_card_tests.sh` 和 `tools/run_legacy_smoke.sh` 全绿（开发中可以 `CARDS_SUITES=W0,<ID>` 只跑自己的）；PR 模板的自查全部打勾。
2. CI 的必过检查全绿：`cards / paths`（`check_pr_paths.py --author --branch`：作者不在 `legal/human_authors.json` 的一律按 AI 线查，碰人写路径即失败；按归属表查越界）和 `cards / tests`（卡牌测试 + 旧版冒烟）。人写路径另有 CODEOWNERS。
3. 把 PR 从 Draft 改成 **Ready for review**，加标签 **`needs-review`**（加不了标签就评论一行 `请 Claude 审核`）。Claude 按这个标签和评论拉待审的 PR（也会订阅 PR 动态），目标是一个工作日内给出结论。
4. 主人（A / B）也可以直接把 PR 链接发给 Claude 的会话，效果一样。

### 6.5 Claude 审核关

- **每个 PR 都由 Claude 审**，按合同 §14.2 的十六条逐条过：越界 · 合同（冻结签名、登记、`class_name`）· 确定性 · 隐藏信息 · 免 AI 声明 · 鉴定 · 史实 · 测试（含合并时跑全量 `tools/run_tests.sh`）· 质量 · 性能 · 界面截图 · 数据抽查 · PR 描述 · **新手指引** · **打烊永远可用** · **画面与对话**。另看任务卡末尾“审核（Claude 重点）”一节。
- **结论三种**（以 PR review 的形式贴出，正文开头写“Claude 审核”）：
  - **合并**：Approve + 标签 `approved`；Claude 按第 3 节的合并先后 **squash 合并**（提交信息 = PR 标题 + 要点），合并后跑全量 `run_tests.sh`、需要时重算黄金种子、更新 `STATUS.md` 和本页第 4 节、在相关 issue 里通知依赖它的线。
  - **改了再合**：Request changes + 标签 `changes-requested`，评论里分“必须改”和“建议”。“必须改”修完再合；“建议”可以留到后面的 PR。修完 push 到同一分支，评论“已按必须改修完：1… 2…”，把标签换回 `needs-review`。
  - **关掉**：越界、方向错、擅自加玩法，关闭并写明原因和下一步。
- “需要主创 / 编排决定的事”由 Claude 转成 `[design]` issue；合同不够用的由 Claude 改合同（`[api]`）并通知受影响的线。
- 数据 PR 合并、写了“交付”之后，K13 做史实与敏感审读，开 `[K13→K0x]` issue（附审读报告与逐条建议，只涉及 `brief` 和标签）；**数据的主人**在自己的分支改、在 PR 里逐条回应；那条线已经结束时 Claude 指派 `X##`（合同 §2.6）。
- 别的任务的 PR 让黄金哈希变了（`G06_golden` 变红、标签 `golden-change`、PR 里写了原因）：Claude 同意后在该 PR 分支上追加一个只改 `scripts/tests/cards/golden/golden.json` 的提交（`--update-golden`）再合并；执行方不改 G06 的文件（合同 §12.5）。
- A / B 的人写内容 PR：Claude 只审技术面（键对得上、格式、`_provenance` 是 `human:A|B:日期`、来源清单），**不改、不润色人写的正文**。

### 6.6 GitHub 任务板与自助领取（10-13 晚）

所有任务都贴到了 GitHub 上，各家 bot 线自己领。总入口是索引 issue **#99**（https://github.com/misakamikotoghr-5205/dehoudang/issues/99，“任务板：怎么领取任务（所有线必读）”），里面有 39 个任务 issue 的总表（#100–#138，标题 `[任务] <ID> <slug> · <中文名>`：G01–G06、C01–C16、K01–K16、X02）。规矩摘要（以 #99 为准）：

- **只领 `open-task`**：只领标签是 `open-task`（没人做）的任务；“当前状态”里已经写了 PR 的任务不要另起一份，要帮忙就在那个 PR 里评论。K 线每个任务已有两份 PR，只保留一份、由主创决定，不要再开第三份。
- **怎么领**：在任务 issue 下评论 `/claim <线名>`（例 `/claim grok-07`、`/claim cursor-03`、`/claim gpt-2`）；能加标签就把 `open-task` 换成 `claimed`，能 assign 就 assign 自己；以最早的有效 `/claim` 为准。
- **一条线同一时间只领一个任务。**
- **24 小时规则**：领了以后 24 小时内要有提交或草稿 PR，否则视为放弃，别人可以评论 `/claim` 接手（@ 原来的人）。
- **后续工作**：任务 issue 里列的“1.3 之后可以另领的后续工作”（演出块 PR、对话框 PR、新美术类别等），主人 24 小时内没动手的，别的线可以评论 `/claim <线名> <条目>` 只接那一条，分支用 `cards/<ID>-<slug>-<后缀>`。
- **分支与 PR 照旧**（6.1–6.4）：分支 `cards/<ID>-<slug>`、从集成分支最新提交切；PR 标题 `[<ID>] <中文摘要>`、目标分支 `claude/festive-ride-vud32a`、描述里写 `Refs #<任务 issue 号>`。`cursor/...` 这种分支名认不出任务号，路径检查不算通过。
- **合并依赖、红线、免 AI 声明、归属表照旧**（第 3 节硬依赖表、第 7 节、`docs/cards/ownership.json`）。
- **做完**：PR 合入后在 issue 里评论“交付”，issue 由维护者关闭；合同问题开 `[api]`，要改别人的文件开 `[shared]`。

---

## 7. 硬规则摘要

合同 §0 的**九条红线**（违反任何一条，PR 直接退回）：

1. **免 AI 声明**：Steam 版不能需要 AI 内容声明。AI 可以随便写代码、测试、工具；玩家看得到、听得到、读得到的东西（正文、界面文字、人物名字、签诗、观察句、物品名、美术、配色、音频）AI 只能做**占位**，只放在明确标记的草稿位置：数据里的 `brief` / `_doc` / `_meta.brief`（干巴巴的设计说明，不写成台词、不写引号里的对白）、`art/_placeholder/**`、`audio/_placeholder/**`、开发版运行时的【稿】回退。AI 不写、不改 `data/cards/text/**`（正文覆盖层，`_provenance: human:A|B:日期`）、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`；`.gd` 字符串字面量只许 ASCII，`.tscn` 不出现中文，界面代码不写颜色字面量。发行包从暂存目录导出、剥掉所有 `brief`，**K15 的审核任何一项不过就不出包**。
2. **确定性**：影响游戏状态的随机只用 `JevRng.draw(seed, domain, key)`（`scripts/sim/jev_rng.gd`，经 `ctx.draw`），`domain` 必须在合同 §6.3 登记在本任务名下；禁止 `randf/randi/randomize/RandomNumberGenerator/Time/OS.get_ticks*` 影响状态；状态里没有浮点。同种子 + 同一串指令 → 同一个状态哈希，回放可复现。
3. **隐藏数值不上界面**：不显示概率、百分比（界面上不许出现“%”）、权重、底价、真值、真假、来路、耐心、本心、口碑 / 风声的点数、扇区权重。口碑 / 风声只给**五档文字**；扇区只画大小；本心完全藏着。
4. **规矩在戏里讲**：不弹机制说明；由人物、告示、黄历、哥哥的账簿批注、胡二的话来讲（正文人写）；落地方式就是新手指引。
5. **鉴定只给观察**：小游戏只回观察键（含糊的观察，永远不是“真 / 假 / 仿”）；引擎给小游戏的只有物理量。
6. **史实措辞**按 `era.json` 的 `notes`：日方扶植的政权一律加“伪”字；1945 年写“抗战胜利”；1949 年写“解放”；抗战按“十四年抗战”；1950 年代运动只写政策和经济事件，不做随机惩罚牌、不写斗争会和暴力。`brief` 里也照这个写。
7. **测试红线**：`tools/run_tests.sh` 与 `tools/run_card_tests.sh` 的输出里出现 `SCRIPT ERROR` / `ERROR` / `WARNING` / `Parse Error` / `FAIL:` / `DATA ERROR` 任何一行、或退出时对象泄漏，都算失败。测试登记在 `scripts/tests/cards/suites/<ID>.txt`，每个脚本最后一行打印 `CARDS TEST PASS <名字>`；测试确定（不 sleep、不依赖墙钟、各用自己的 `user://` 目录）。**谁都不改** `run_tests.sh`、`run_card_tests.sh`、`run_legacy_smoke.sh`。
8. **每个机制都有新手指引**（第 5 节）：新机制没有 first-time、新界面没有锚点和指引步骤，PR 退回；指引开关不改任何游戏状态。
9. **打烊永远可用、绝不卡住**（主创 10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”）：牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、确认后按“没理会”结算；`day.end` 不被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时（合同 §7.4.7）。

**画面与对话（1.3）**：坐标只用 CardLayout；字不进场景层；一张牌在画面里演、选择是回话；演出块只写键和 brief；锚点、界面事件用 1.3 的名字（合同 §7.10.5、§7.11）。

**并行规则**：每个文件只有一个主人（合同 §2.2 / `ownership.json`），只改自己的路径加四类默认路径（`scripts/tests/cards/<ID>/**`、`suites/<ID>.txt`、`data/cards/tags/<ID>.json`、`data/cards/ui_keys/<ID>.json`）；不改 `scripts/cards/api/**`、`mock/**`、`scripts/tests/cards/lib/**`、`project.godot` 和任何旧文件（只读、只调用）；只有冻结表里的类写 `class_name`；新常量放自己目录下的 `<模块>_ids.gd`；**不许擅自加玩法**——合同没写的用最保守的做法、标 `# TODO(design)`、写进 PR。

---

## 8. 开场提示与任务卡

**开场提示**（主人在每个窗口粘贴同一段提示，再按文末的分线表把 `<任务ID>` 和 `<slug>` 换成那一线的值）：

| 执行方 | 线数 | 开场提示 |
|---|---|---|
| GPT | 6（G01–G06） | [PROMPT_GPT.md](PROMPT_GPT.md) |
| Cursor | 16（C01–C16） | [PROMPT_Cursor.md](PROMPT_Cursor.md) |
| Grok | 16（K01–K16） | [PROMPT_Grok.md](PROMPT_Grok.md) |

**任务卡**（每张都是合同 §3 对应任务的展开；结构相同：执行者与线号 · 依赖与波次 · 分支 · 目标 · 必读 · 要做的事（勾选清单）· 只能改这些文件 · 不能做的事 · 接口 · **新手指引** · 测试与验收标准 · 交付 · 审核（Claude 重点）· 回报（执行者填写，贴进 PR，不改卡））：

- **GPT**：[G01](G01_core-model.md) · [G02](G02_loop-engine.md) · [G03](G03_slots-dsl.md) · [G04](G04_economy.md) · [G05](G05_fate-fortune.md) · [G06](G06_ladder-autoplay.md)
- **Cursor**：[C01](C01_table.md) · [C02](C02_card-widget.md) · [C03](C03_slots-coins.md) · [C04](C04_counter.md) · [C05](C05_demand.md) · [C06](C06_wheel.md) · [C07](C07_fortune.md) · [C08](C08_night-settle.md) · [C09](C09_month-year.md) · [C10](C10_dossier-help.md) · [C11](C11_ladder.md) · [C12](C12_mg-spot.md) · [C13](C13_mg-coin-ring.md) · [C14](C14_mg-weigh.md) · [C15](C15_mg-fragments-decode.md) · [C16](C16_guide-shell.md)
- **Grok**：[K01](K01_data-1938-people.md) · [K02](K02_data-1938-world.md) · [K03](K03_data-1939-people.md) · [K04](K04_data-1939-world.md) · [K05](K05_data-1940-people.md) · [K06](K06_data-1940-world.md) · [K07](K07_data-demand.md) · [K08](K08_data-news-dossier.md) · [K09](K09_data-common.md) · [K10](K10_data-fortune.md) · [K11](K11_data-items-mg.md) · [K12](K12_art-pipeline.md) · [K13](K13_review-history.md) · [K14](K14_qa-automation.md) · [K15](K15_audit-provenance.md) · [K16](K16_guide-data-post1949.md) · [K17](K17_officialdom-open.md)（1.4） · [K18](K18_apprentice.md)

**每条线开工的第一件事**：切分支 → `$GODOT --headless --path . --import` → `CARDS_SUITES=W0 bash tools/run_card_tests.sh` 跑基线（应当全绿）→ 读任务卡与合同 → 用一小段话复述自己的理解、列出第一个 PR 的勾选项和测试 → 开工。

---

## 9. Claude 的待办（开工前与 W1 中）

**W0 收尾（开工前，10-14 前）**

- [x] （10-13 已完成，合并而非 rebase）`cards/plan`（从 `ec5d68e` 切出）合到集成分支当前的 `78ab977`（v1.1 设计 PDF，只动了 `docs/town/cards/`，不冲突），合入 `claude/festive-ride-vud32a`，记下 W0 合入点（提交 `b87a641`）。
- [ ] 集成分支保护：`cards.yml` 的 `paths`、`tests` 两个 job 设成必过检查；只有 Claude 合并。（需要仓库主人在 GitHub 设置里操作：Settings → Branches → 给 `claude/festive-ride-vud32a` 加保护规则。）
- [ ] 建第 6.3 节的 PR 标签。（需要仓库主人在 GitHub 的 Labels 页面建；没建也不影响开工。）
- [ ] Steam 导出预设（`ship` 特性、`application/run/main_scene.ship` 覆盖、排除列表）——要改 `export_presets.cfg` 与 `project.godot`。
- [ ] 开 issue 请 A / B 提交 `legal/human_authors.json`（他们自己的 GitHub 账号）；之后把 `.github/CODEOWNERS` 换成他们的账号。
- [ ] `STATUS.md` 把 38 条线标为“可以开工”，主人开窗口、贴开场提示。

**W1 中（任务卡里已经点名、等 Claude 定的）**

- [ ] K16 第一个步骤 PR 合入前改 `W0_table_3days`（Mock 会改读真 `steps.json`）。
- [ ] 合同缺口转 `[api]` issue 并在合同里定：面板之间的 `close_requested(result)` 约定（C01；`can_close()` 1.2 作废，改为 `CardPanel.dismiss()`，§7.8）；~~`CardSettings.fast_anim()` 的冻结读取接口（C16）~~（1.3 已关）；~~CardView 里条子的档位 / 类别（G03 → C05）、轮盘牌的轮盘 id（G05 → C06）~~（1.3 已关）；~~夜牌的美术与选项~~（1.3 已关）、开月过场的背景与段数、跳年报告的分组、局终原因（G02 → C08 / C09）；档案簿“标为已读”（C10）；~~货架与家当在牌桌上的入口（C01）~~（1.3 已关：标签、热点、HUD）；拖拽“你自己”和“物品”的格式（C03）；`deal_count` 的参数（G01 / G05）；指令日志含失败的指令（G02）。（`retry` / `resume` 的 first 与“重来本关后哈希等于当时”的冲突已在合同 §3.2 G02 验收里定：比较时去掉这两项。）
- [x] 审核与路径检查的缺口（K13 / K15 卡附录）——交接包审计时已在合同里定（附录 E）：`wording.json` 与 `data/cards/branch/**` 排除出发行包（§2.3、§11.4）；K13 不跨线改文件，`check_pr_paths.py` 不设特例（§2.6）；`ownership.json` 与合同 §2.2 逐条一致（K15 逐个文件列出）；字体覆盖检查用标准库读 `cmap`（§11.4 第 7 项）；`fonts/**` 只归人（A/B）。
- [ ] CI 装 Pillow（K12 的字节确定性测试要用）。
- [x] 新手指引七处冲突（第 5.3 节 a–g）和合同里其余【待主创确认】——主创 10-13 回复“同意你说的九点”，全部确认（合同附录 F）。
- [ ] W3 结束日期请主创定；交付计划按卡牌版重排。
- [ ] PDF（`docs/town/cards/src/build_design.py`）第九节“待你确认的几处”第 1 条还写着“普通牌必须处理完才能打烊”：下次出 PDF 时改成“打烊 · 下一天”（DESIGN §九.5）并标“已确认”。
- [ ] G01 的 1.3 小 PR 合入后：把 scripts/cards/mock/stage_examples.json 的演出块挪进 data/cards/_examples/ 对应的牌、删掉这个文件、重生夹具。
- [ ] W2（X01）：删 CardIds 里 7 个改名前的锚点与 ANCHORS_RENAMED 的兼容、CardGuide 的新旧互认、night_offers 裸字符串的兼容；主人都合入后删 scripts/cards/ui/common/w0/**、scenes/cards/_w0/**、w0_stub.gd。
- [ ] 正式美术排期（A / 外包）加画面类：三张柜台背景、街头/牢房/城隍庙/码头、群演 9 个的头像与行走图、柜台工具与道具约 30 件、对话框/头像框/批注纸、8 个标签图标（清单见 K12 的 ART_SPEC.md）。

---

## 10. 变更记录

- **10-13 晚补记**：合同 1.3 的 W0 骨架代码同步拆成 X02（`X02_w0-sync-1.3.md`，待指派；归属见 `ownership.json` 的 `X02`）。X02 合入前，任务卡里提到的 `CardStageApi` `CardDialogApi` `CardHandApi` `CardHeroApi` `CardChecksApi` `CardStagePanel` `CardStageScript` `CardLayout` 与 `scenes/cards/_w0/` 桩还不存在，照合同 §7.11 的签名先写。
- **10-13 晚补记二**：任务贴到 GitHub 上自助领取——索引 issue #99，39 个任务 issue #100–#138（X02 是唯一的 `open-task`），规矩见 [6.6](#66-github-任务板与自助领取10-13-晚)。

### 2026-10-13 晚 · 画面与对话（合同 1.3；DESIGN §九.6）

**为什么**：主创看了纯文字牌桌版的网页试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”，让写进设计和任务。

**变了什么**（详见合同附录 G）：画面 = 320×180 的像素柜台场景整数 4 倍铺满 1280×720 + 一层界面（§1.2、§7.11）；打出一张牌就在画面里“演”：人走进门、在左上角的对话框里一句一句说，你的选择是回话，格子出现在柜台上（§7.11.4）；手牌是最下面的炉石式扇形，沈如花的头像在左边、人脉是小牌；两侧标签打开抽屉（人脉、条子、档案簿、规矩 / 货架、当票、家当、设置）；柜台上的工具是热点；顶部一条 HUD；“打烊 · 下一天”在右侧中下，永远能按（红线 9 不变）。数据多了可选的演出块 `stage`（§4.7.24，校验 V38–V42），只写键和 brief；视图多了 `stage`、CardView 多了 5 个字段、`night_offers` 成了字典。九条红线、免 AI 声明、归属、首发三关、隐藏数值、已有的冻结签名都不变。

**每条线要做的**（各任务卡新加了“10-13 变更二”一节）：

| 线 | 变了什么 |
|---|---|
| G01 | 一个小 PR（10-15）：11 个类型的 schema 加 `stage`；校验器挂 V38–V42（default 部分 W0 已写在 `CardDslShapes.check_stage`）、V27/V30 加内容 |
| G02 | 视图加 `stage {set, time, sealed}`（`loop.json.dusk_pct` 60）；CardView 加 `stage` `source`；`night_offers` 改字典 |
| G03 · G05 | CardView 加 `demand {kind, tier}`（G03）、`wheel` `fortune`（G05） |
| G04 · G06 | 不受影响 |
| C01 | 画面根：场景层 `CardStage`、HUD、两侧标签与抽屉宿主、打烊按钮挪到 (1020, 556)；面板宿主按“呈现”分演出/抽屉/叠层；打出与热点的路由；牌桌分区作废；合并 10-27 |
| C02 | 加手牌扇 `CardHandFan`、头像与人脉 `CardHeroBar`；悬停放大副本作废；合并 10-21 |
| C03 | 选项成回话、格子搬上柜台（`CardCounterChecks`）、人脉抽屉；SlotPanel 成了演出 |
| C04 | 对话框 `CardDialogBox`（10-21 先合）；柜台成了演出；货架、当票抽屉；合并 10-27 |
| C05 | 条子板进左抽屉；条子成了胡二那一出 |
| C06 · C09 · C12–C15 | 基本不变（叠层），截图改画面版 |
| C07 | 黄历条进 HUD（260×24）、黄历抽屉、算命那一出 |
| C08 | 打烊确认不变；夜里在手牌扇里打夜牌；日结在对话框里说 |
| C10 | 档案簿成左抽屉（“规矩”是它的第二页，左边“规矩”标签直接开） |
| C11 | 家当成右抽屉；牢房成一出；街头只剩“赎回铺面”按钮 |
| C16 | 教的人在画面里开口；锚点新旧互认；设置成右抽屉；`CardSettings.fast_anim()` 冻结；合并 10-23 |
| K01 · K03 · K05 | 金色牌都写演出块 + 各 ≥ 6 张人物牌（另开 PR，等 G01 的小 PR） |
| K02 · K04 · K06 | 事件、命运、大赌都写演出块（另开 PR） |
| K07 · K10 · K11 | 不受影响 |
| K08 | 电报、信写演出块 |
| K09 | `common/extras.json` 九个群演；夜牌、街头牌、牢房写演出块 |
| K12 | 新美术类别（场景背景、行走图、道具、对话框框、头像框、批注纸、标签图标）进清单与生成器；ART_SPEC 加“画面” |
| K13 | 审读加演出块的 brief |
| K14 | 走查与截图改画面版；`--chaos` 加抽屉、跳过、回头再说 |
| K15 | 待写清单加演出拍子、`w0.stage.*`、群演名字 |
| K16 | 步骤锚点按新表改（合入 #89 之前）；两张教学牌写演出块 |
| W0（Claude） | `CardIds` 1.3 常量、`CardLayout`、5 个接口基类、`CardStagePanel`、`CardStageScript`、`check_stage`、6 个桩、Mock 的 `stage` 等、夹具重生、例子集群演、W0 配色、`W0_stage` 测试；C 线自己的桩文件不动 |

**已开工的线**：rebase 到包含 1.3 的集成分支；W0 桩文件冲突以集成分支为底。你已经写好的“和引擎说话”的部分（指令、查询、自动一步、夹具、对 `mock.sent` 的断言）全部还有效；要换的是“画在哪、怎么画”。数据线、引擎线手上的 PR 不用为 1.3 改（K16 的锚点、K12 的美术类别、G01/G02/G03/G05 的小增补除外）。

### 2026-10-13 · 10-13 打烊永远可用（合同 1.2；DESIGN v1.2 §九.5）

**为什么**：主创 10-13 回复：“同意你说的九点。然后得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。前半句确认了 PDF v1.2 第九节的九条（DESIGN“实现时的理解”里原来标【待主创确认】的都改成【主创已确认 10-13】，做法不变）；后半句是新的硬性规则，落成合同的**红线 9** 和 **§7.4.7**：牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单（每样会怎样，人写的话）、玩家确认后按“没理会”结算——没接的人走掉（个别人记仇）、事件/命运按没理会、金色牌按没理他、条子接着计时、大轮盘作废、牢房多待一晚（连续 3 晚【待调】没出来按打点失败，可从本关开头或续玩点重来）；所有面板和小游戏都能关；没有真实时间倒计时、不自动跳天。**它取代 1.1 里“必须处理的牌没处理完不能打烊”的做法**：`day.end` 不再被任何牌挡住。

**接口上变了什么**（详见合同附录 F）：`day.end {confirm}`（旧参数 `confirm_gold_leave` W1 里照收）除 `game_over` 外任何阶段都往前走一步；新查询 `day.end_preview`（`{step, needs_confirm, items:[{uid, def, kind, consequence_key, args}]}`）；错误码 `must_resolve_pending` 的意思改成“要确认”，`gold_pending` 不再返回；`must_resolve` 改成“今天要了断”；first `must_resolve` / `gold_leave` 改成“第一次按打烊时清单里有……”（确认之前记）；锚点 `a.endday.*` 和步骤 `gd.must` `gd.gold_leave` `gd.d1.close` id 不变、改在确认面板上亮；新修正项 `end_rows`、`day_end` 钩子 priority 5–25、校验 V37、`CardPanel.dismiss()`（面板的“算了”，`can_close()` 作废）、`ladder.json.prison.max_days`、`night.choose {def: ""}`、`game.load {}` = 续玩点。**不卡死不变式**：从任何状态连按最多 8 次“打烊 · 下一天”一定进到下一天或局终。

**每条线要做的**（各任务卡新加了“10-13 变更”一节，和上文冲突时以那一节和合同 §7.4.7 为准）：

| 线 | 变了什么 |
|---|---|
| G01 | `day_end` 5 留牌溢出没选 → 扔新来的；`day_end` 20 生活牌、手上能留的牌留到明天接着倒计时（原来的 `TODO(design)` 已定）；`end_rows` 交这几行；`deal_count` 按 0 截断、夜牌也问它；`day.end` 不受溢出拦截；校验 V37 与 `outcomes.ignored`（V27） |
| G02 | `day.end` 重写（每个阶段一步、清单 + 确认、预览 = 结算、月初替转运势）；新查询 `day.end_preview`；`day_end` 10 结算人物/事件/命运/街头/大赌/今天的机会；两个 first 的时机；新测试 `G02_next_day` |
| G03 | `day_end` 6 人脉满没选 → 新来的不留、格子里没掷的还回来；`end_rows`（人脉满、条子）；新测试 `G03_end_day` |
| G04 | `day_end` 8 关掉柜台会话；`shop_closed` 给牢房用；新测试 `G04_end_day` |
| G05 | `day_end` 15 `bf.wheel` 没转就作废（计入上限）、没转的轮盘退还香案和押牌；月初替转；新测试 `G05_end_day` |
| G06 | 牢房多待一晚 / 到期失败（`ladder.prison`、`prison.max_days`、`deal_count`）；`day_end` 7 钱不够没选 → 认了；**模糊测试 `G06_no_deadlock`（4 行共 1000 局，随机乱点 + 随机打烊 + 随机存读）**；自动玩卡住用 `day.end` 往前走、`refuser` 每天只按它 |
| C01 | “打烊 · 下一天”按钮任何阶段都能按（局终时开局终面板）；引擎要的面板每个只自动开一次；Esc = 面板的 `dismiss()`；`can_close()` 作废；小游戏框上加“算了”按钮（= `abort()`）；不许计时自动推进；新测试 `C01_next_day` |
| C02 | 小红点的意思改成“今天要了断”；牢房牌显示 `days_left`；手上能留的牌有 `expires_in` |
| C03 | 人脉满面板关 = 新来的不留（覆盖 `dismiss()`）；`can_close()` 去掉 |
| C04 | 柜台面板的“算了”（覆盖 `dismiss()`）= 先不管：`counter.close` 再关，客人留在手上；打烊时柜台开着由引擎关会话 |
| C06 | 轮盘面板随时能关；月初没转运势由“打烊 · 下一天”替转；`can_close()` 去掉 |
| C08 | 打烊确认面板改成“未处理清单 + 打烊 / 回去看看”；夜牌“算了” = 今晚不选；键、夹具、测试、截图照改 |
| C09 | 局终两条路：从本关开头 / 从续玩点；面板都能关（局终关 = 回标题） |
| C11 | 钱不够面板关 = 认了；牢房面板显示还能待几晚、关了牌留在手上；街头皮不挡按钮 |
| C16 | `gd.d1.close` `gd.must` `gd.gold_leave` 的讲法与触发（数据归 K16）；夹具里 `day.end` 参数改名；指引绝不替玩家推进 |
| K01 · K03 · K05 | 个别记仇的人写 `on_expire`（PR 里列出）；金色牌照旧 |
| K02 · K04 · K06 | 没有顶层 `check` 的事件、命运、大赌必须写 `on_expire`（V37）；算命摊、庙会、赌摊、`ev.any.wheel_go` 写 `must_resolve: false`；主线事件写没理会时主线怎么走 |
| K07 | `ev.any.demand_return` 写 `on_expire`（建议：人晚一天自己回来） |
| K08 | 消息没看留在手上倒计时，到期碎片就错过了——`expires_days` 给合理 |
| K09 | 街头牌 V37；`pr.cell` 的 brief 写明牢里过夜的规矩 |
| K14 | `play_ui.gd --chaos` 随机乱按“打烊 · 下一天”和 Esc 的走查；试玩清单加红线 9 |
| K15 | 待写清单列出 `outcomes.ignored`；发行检查 V27 跟着查 |
| K16 | 三个步骤（`gd.d1.close` `gd.must` `gd.gold_leave`）的触发与 brief；`rule.day` `rule.gold` `rule.prison` 的 brief；`ev.1938.tut_contact` 写 `on_expire`；七处冲突改注“主创已确认 10-13” |
| 其余（C05 C07 C10 C12–C15 K10–K13） | 只有通用规则：面板都能关（`dismiss()` 默认就是关；小游戏 Esc = `abort()`，“算了”按钮由 C01 的宿主放）、不许计时推进；任务卡没改 |
| W0（Claude，已做） | `CardIds`（`day.end_preview`、`END_*` 常量、修正项 `end_rows`、错误码注释）；Mock 情景模式的 `day.end` 照 §7.4.7（不挡、清单、牢房多晚、局终）；十个夹具重生成（都带 `day.end_preview|{}` 和 `day.end` `confirm` 真、假各一条回应）；例子集三张大赌/命运补 `on_expire`；`CardPanel.dismiss()`、宿主 Esc 调它、六个桩面板的“算了”（夜牌、留牌满、人脉满、钱不够、柜台、局终）；牌桌按钮（局终时开局终面板）、确认面板桩、G02 的 `day.end_preview` 查询桩、`end_day(ctx, confirm)`；新测试 `W0_next_day`（Mock 上每个阶段前进、预览 = 结算、牢房、300 局乱点不卡死、十个夹具各按一次按钮、每种面板 Esc 都关得掉、局终按钮） |

**已开工的线**：rebase 到包含本次提交的集成分支；W0 桩文件冲突以集成分支的版本为底，再按自己那一行改。
