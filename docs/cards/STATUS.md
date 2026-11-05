# 卡牌版 · 38 条线状态板

> **10-19 框架版已收尾，本文是 W0–W1 时期的历史记录。现在的状态和下一阶段要做什么，看仓库根目录的 [`HANDOFF.md`](../../HANDOFF.md)。**

> 维护人：Claude。W0 骨架（附录 A）已提交；合入集成分支 `claude/festive-ride-vud32a` （W0 合入点：提交 `b87a641`） 后，下面每条线都可以开工。
> 每条线从 W0（提交 `b87a641`） 切 `cards/<ID>-<slug>`；对着 W0 的桩（同签名、标 `TODO(<ID>)`）和 MockCardEngine 开发，不用等别的线（§0 并行规则）。
> 跑测试：`GODOT=<Godot 4.7> tools/run_card_tests.sh`（清单在 `scripts/tests/cards/suites/<ID>.txt`）+ `tools/run_legacy_smoke.sh`。
> **10-13 晚：合同 1.3（画面与对话）**——见下面一节；状态以 GitHub 上的 PR 为准。
> **10-14 第一轮合并**：19 个合入（X02、K01 K03 K04 K05 K06 K09 K10 K11 K12 K13 K15、C06 C07 C10 C12 C13 C14 C16），其余见 issue #142。
> **注意：W0 骨架的 1.3 代码同步还没做**（新控件接口基类与桩、`CardLayout`、Mock 的 `view.stage`、`check_stage`、`W0_stage` 测试）——拆成任务 **X02**（`docs/handoff_cards/X02_w0-sync-1.3.md`，待主创指派）。表里写的“1.3 的接口基类 … 与桩”在 X02 合入后才有；在那之前界面线照合同 §7.11 的冻结签名先写自己的实现。另外 1.3 的文档没做最后一遍交叉核对，发现前后不一致开 `[api]` issue。（10-14：X02 已合入，见 #140。）

| 任务 | slug | 执行方 | 状态 | W0 给的起点 |
|---|---|---|---|---|
| G01 | `core-model` | GPT | 退回：见 #23 评论 | scripts/cards/core/**（W0 已有能用的最小核心：CardDB、CardState、CardCtx、五个登记表、CardPiles、CardComposer、CardSave、CardText、CardFirsts、ui.guide 与指引查询、default 校验） |
| G02 | `loop-engine` | GPT | 退回：见 #91 评论 | scripts/cards/loop/**（CardEngine 分发、busy、事件顺序已能用；日循环 day.begin…year.next 是桩） |
| G03 | `slots-dsl` | GPT | 退回：见 #79 评论 | scripts/cards/rules/**（全是桩；all/any/not 与 CardCoins.toss 已能用） |
| G04 | `economy` | GPT | 进行中（草稿 PR #80） | scripts/cards/economy/**（全是桩；card_ledger.gd 已继承旧账本） |
| G05 | `fate-fortune` | GPT | 进行中（草稿 PR #81） | scripts/cards/fate/**（全是桩） |
| G06 | `ladder-autoplay` | GPT | 等引擎链（#86、#97）：G01–G05 合入后再改 golden，见 PR 评论 | scripts/cards/ladder/**、scripts/cards/sim/**（全是桩） |
| C01 | `table` | Cursor | 冲突，待 rebase（#42） | CardGame.tscn 与牌桌桩（1.2）；1.3 的接口基类 CardStageApi 与桩 _w0/Stage.tscn |
| C02 | `card-widget` | Cursor | 退回：见 #35 评论 | CardWidget、CardArt（W0 桩）；1.3：CardHandApi/CardHeroApi 与桩 |
| C03 | `slots-coins` | Cursor | 冲突，待 rebase（#38） | SlotPanel、SlotWidget、CoinToss、ContactsFull、KeptFull（W0 桩）；1.3：CardChecksApi 与桩、CardStagePanel |
| C04 | `counter` | Cursor | 冲突，待 rebase（#39） | CounterPanel（W0 桩）；1.3：CardDialogApi 与桩、CardStagePanel、CardStageScript |
| C05 | `demand` | Cursor | 退回：见 #67 评论 | DemandPanel、DemandBoard（W0 桩）；1.3：CardStagePanel、CardStageScript |
| C06 | `wheel` | Cursor | 第一份已合入（#34，1e28363） | WheelPanel（W0 桩） |
| C07 | `fortune` | Cursor | 第一份已合入（#36，912337b） | FortunePanel、AlmanacStrip（W0 桩）；1.3：CardStagePanel、CardStageScript |
| C08 | `night-settle` | Cursor | 冲突，待 rebase（#37） | EndDayConfirm、NightPanel、SettlePanel（W0 桩）；1.3：CardStagePanel、CardStageScript |
| C09 | `month-year` | Cursor | 冲突，待 rebase（#33） | MonthOpen、MonthClose、YearJump、GameOver（W0 桩） |
| C10 | `dossier-help` | Cursor | 第一份已合入（#30，a429db5） | DossierBook、HelpPanel（W0 桩） |
| C11 | `ladder` | Cursor | 冲突，待 rebase（#43） | EstatePanel、ShortPanel、PrisonPanel、StreetOverlay（W0 桩）；1.3：CardStagePanel、CardStageScript |
| C12 | `mg-spot` | Cursor | 第一份已合入（#31，5caa5f4） | SpotGame（W0 桩继承示例插件） |
| C13 | `mg-coin-ring` | Cursor | 第一份已合入（#28，cc22b1f） | CoinRingGame（W0 桩） |
| C14 | `mg-weigh` | Cursor | 第一份已合入（#29，dc0038f） | WeighGame（W0 桩） |
| C15 | `mg-fragments-decode` | Cursor | 退回：见 #32 评论 | FragmentsGame、DecodeGame（W0 桩） |
| C16 | `guide-shell` | Cursor | 第一份已合入（#47，8c45de6） | CardGuide（W0 有能用的最小挑步骤）、CardTitle、CardPause、CardSettings、card_music.gd（W0 桩）；1.3：CardLayout 的 GUIDE_* 常量、CardIds.anchor_aliases() |
| K01 | `data-1938-people` | Grok | 第一份已合入（#76，13e1ff7） | data/cards/era/1938/{people,story}.json、era/common/passersby.json |
| K02 | `data-1938-world` | Grok | 退回：见 #59 评论 | 1938 事件/命运/大命运/生活/目标/开场 + 通用事件与大赌 |
| K03 | `data-1939-people` | Grok | 第一份已合入（#69，731fe06） | data/cards/era/1939/{people,story}.json |
| K04 | `data-1939-world` | Grok | 第一份已合入（#58，958a5ae） | 1939 世界牌 + 通用命运 |
| K05 | `data-1940-people` | Grok | 第一份已合入（#57，302f972） | data/cards/era/1940/{people,story}.json |
| K06 | `data-1940-world` | Grok | 第一份已合入（#71，442640a） | 1940 世界牌 + 通用生活牌 |
| K07 | `data-demand` | Grok | 退回：见 #50 评论 | data/cards/demand/** |
| K08 | `data-news-dossier` | Grok | 退回：见 #92 评论 | data/cards/news/**、dossier/** |
| K09 | `data-common` | Grok | 第一份已合入（#63，b8e08ad） | data/cards/common/**；1.3：common/extras.json |
| K10 | `data-fortune` | Grok | 第一份已合入（#83，9f1ba49） | data/cards/fortune/** |
| K11 | `data-items-mg` | Grok | 第一份已合入（#45，d35eb59） | minigames/items.json、codebook.json、items/** |
| K12 | `art-pipeline` | Grok | 第一份已合入（#78，9f7a901） | tools/cards/art/**、art/_placeholder/**、data/cards/art/manifest.json（W0 起了初版）；1.3：新美术类别 |
| K13 | `review-history` | Grok | 第一份已合入（#56，8cf1cda） | tools/cards/review/**、docs/cards/review/** |
| K14 | `qa-automation` | Grok | 退回：见 #93 评论 | tools/cards/qa/**、docs/cards/qa/**（CardGameRoot.autoplay_step() 与 --cards-autoplay 已能用） |
| K15 | `audit-provenance` | Grok | 第一份已合入（#77，0cf599f） | tools/cards/audit/**（W0 有能用的 check_pr_paths.py 与“关着门”的 audit.py 桩） |
| K16 | `guide-data-post1949` | Grok | 退回：见 #89 评论 | data/cards/guide/**、era/1938/tutorial.json、branch/**、docs/cards/post1949/** |
| X02 | `w0-sync-1.3` | GPT | 已合入（#140，69be208） | W0 骨架按合同 1.3 同步（接口基类、桩、CardLayout、check_stage、Mock 的 view.stage、W0_stage） |

> 10-13 晚用 `gh api repos/misakamikotoghr-5205/dehoudang/pulls?state=open` 核过：C 线的草稿是 C01 #42 · C02 #35 · C03 #38 · C04 #39 · C05 #67 · C06 #34 · C07 #36 · C08 #37 · C09 #33 · C10 #30 · C11 #43 · C12 #31 · C13 #28 · C14 #29 · C15 #32 · C16 #47（`cursor/cards-c<nn>-<slug>-d0d4` 分支，都从 `ace460b` 切出）；G02 的 #65 已关。另有 K 线的重复草稿（`cursor/k<nn>-…-9938` 分支：#48 #53 #55 #61 #64 #66 #68 #70 #75 #82 #84 #85 #87 #88 #90 #94），以上表的已提审 PR 为准；#25、#98 是 Cursor 的集成草稿，不是哪条线的交付。

## W0 交付（附录 A）

- 接口：`scripts/cards/api/`（CardEngineApi、CardMiniGame、CardIds、CardShip、CardDslShapes）。
- 能跑的最小核心与全部模块的桩；六个 `*_install.gd` 按 core → rules → economy → ladder → fate → loop 接好；每个指令、查询、效果/条件 op 都已按合同的主人登记（桩返回 `not_implemented`）。
- Mock：`MockCardEngine`（夹具回放 + 情景模式）、十个基础夹具（`scripts/cards/mock/fixtures/`，由 `build_fixtures.gd` 生成）。
- 界面：§7.8 两张表里每个面板和控件、§8.1 的五个小游戏都有同接口的桩场景；`CardGame.tscn` 能用 `--cards` 打开、能自动走（`--cards-autoplay=<步数>`）。
- 数据：`data/cards/_examples/`（§4 的全部例子 + 引用闭合的几张 + 指引例子 3 步 3 页）、`rules/*.json` 初值、`tags/W0.json`、`ui_keys/W0.json`、`_dev/strings.json`、`theme/palette.dev.json`、`art/manifest.json` 初版、`_schema/*.json`。
- 测试：`scripts/tests/cards/lib/card_t.gd`、`suites/W0.txt`（10-13 加了 `W0_next_day`）、`tools/run_card_tests.sh`、`tools/run_legacy_smoke.sh`；`tools/run_tests.sh` 末尾调用前者。
- 审核：`tools/cards/audit/check_pr_paths.py`（能用）、`audit.py`（关着门的桩）、`cjk_allowlist.json`；`.github/`（PR 模板、issue 模板、CODEOWNERS、`workflows/cards.yml`）。

## 10-13 晚：合同 1.3（画面与对话）

主创看了纯文字牌桌版的试玩：“主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”看完按这个方向重做的网页原型说“不错”。合同升到 1.3（§1.2、§4.7.24、§7.11、附录 G），DESIGN 加 §九.6，任务卡各加“10-13 变更二”一节，原型入库 `docs/cards/prototype/`。W0 同步（只动 Claude 的文件）：CardIds 1.3 常量、CardLayout、画面控件的接口基类与桩（`scenes/cards/_w0/`）、CardStagePanel、CardStageScript、check_stage、Mock 的 `view.stage` 等、夹具重生、新测试 `W0_stage`。

**日期后移**：C02、C03 控件与 C04 对话框 10-21；C16 指引引擎 10-23；C01 画面根与 C04 柜台演出 10-27；其余演出 10-29；**W1 完成 10-30**（原 10-27）；W2 11-02 → 11-13；**首个可玩 1938 关 11-13**（原 11-10）；W3 11-16 起。G01 的 1.3 小 PR 10-15（K 线的演出块等它）。

## 10-13：合同 1.2（打烊永远可用）

主创 10-13 回复“同意你说的九点”（原来【待主创确认】的都定了），并定下硬性规则“打烊 · 下一天永远可用、绝不卡住、节奏由玩家把握”。合同升到 1.2（红线 9、§7.4.7、附录 F），DESIGN 加 §九.5，任务卡各加“10-13 变更”一节，W0 骨架同步（Mock 的 `day.end` 不再挡、`day.end_preview`、`CardPanel.dismiss()`、新测试 `W0_next_day`）。38 条线仍是“可以开工”；已开工的线 rebase 后按交接板 `docs/handoff_cards/README.md` 第 10 节自己那一行改。

## 交接包审计（2026-10-13）

合同、`ownership.json`、38 张任务卡、开场提示和骨架逐条比对过，修订见合同附录 E；`ownership.json` 与合同 §2.2 逐条一致，每个路径只有一个主人。

## 还没做的 W0 项（需要编排决定）

- Steam 导出预设与 `application/run/main_scene.ship` 覆盖（要改 `export_presets.cfg` 与 `project.godot`，本次只加了 autoload）。
- 记下 W0 合入点（提交 `b87a641`）、把 `cards.yml` 的两个 job（`paths`、`tests`——后者含卡牌测试和旧版冒烟两步）设成集成分支的必过检查、A/B 提交 `legal/human_authors.json`、CODEOWNERS 换成 A/B 的账号。
- G01 的 1.3 小 PR 合入后，把 Mock 的 stage_examples.json 挪进例子集。
