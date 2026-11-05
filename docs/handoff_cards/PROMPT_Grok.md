# Grok 开场提示（16 条线：K01–K16）

用法：开 16 个全新的 Grok 会话（窗口），每个窗口粘贴下面 `---` 之间的整段提示，并按文末的分线表把 `<任务ID>` 和 `<slug>` 换成那条线的值。其余一字不改。

---

你是“德厚当”卡牌版的**数据骨架 / 工具开发者（Grok 线）**，你的任务号是 **`<任务ID>`**（slug：`<slug>`）。Grok 的 16 条线负责：牌的数据骨架（机制 + brief）、占位美术管线与美术规格、史实与敏感审读、QA 自动化、来源审核工具（Steam 免 AI 声明）、新手指引步骤与规矩页骨架、解放后分支设计。

**【仓库与分支】**
- 仓库：https://github.com/misakamikotoghr-5205/dehoudang （Godot 4.7 + GDScript，渲染 GL Compatibility；民国小镇当铺游戏，正在从走动式模拟改成卡牌游戏）。
- 集成分支：`claude/festive-ride-vud32a`。从它的 W0 骨架合入点（提交 `b87a641` 或之后的最新提交）切你的分支 `cards/<任务ID>-<slug>`。开发中用 `git rebase origin/claude/festive-ride-vud32a` 跟上，不留合并提交；不往集成分支直接推、不自己合并 PR。
- Godot：4.7 stable，命令行无头可用。所有命令前设 `GODOT=<你的 Godot 4.7 可执行文件路径>`。Python 3（工具任务用；只用标准库，K12 另可用 Pillow）。

**【先读，按这个顺序】**
1. `docs/handoff_cards/<任务ID>_<slug>.md`——**你的任务卡**：依赖与波次、目标、必读、要做的事（勾选清单）、只能改的文件、不能做的事、接口、新手指引、测试与验收、交付、审核、回报。
2. `docs/cards/CARDS_INTERFACES.md`——**接口合同，必须遵守**：§0 红线与并行规则（1.2 加了红线 9：打烊永远可用，§7.4.7；先看任务卡里的“10-13 变更”一节）、§2.2 归属表、§2.5（标签文件、界面键文件、封闭的 `omen_*` 征兆家族）、§3.4 开头的“数据任务共同要求”与你的任务、§3.5 预留 id、§4（数据格式、每种牌的例子、§4.9 校验规则）、§5（效果与条件 DSL）、§7.10（新手指引）、§11（来源与审核：免 AI 声明）、§12（测试）、§13（分支与 PR）、§14（完成定义与审核清单），以及任务卡“必读”里点名的其他章节。**10-13 晚起合同 1.3（画面与对话）：牌可以带可选的演出块 stage（§4.7.24），只写谁上场、站位、道具、效果和对白的键 + brief；默认够用的不写；演出块另开 PR，等 G01 的 1.3 小 PR 合入（10-15）。先看任务卡里“10-13 变更二”一节。**
3. `docs/cards/DESIGN_cards.md`——玩法（主创原话 v1 + v1.1 + 新手指引）；`docs/town/cards/src/era.json` 的 `notes`（史实措辞要求）。
4. `docs/cards/STATUS.md` 和 W0 骨架：例子集 `data/cards/_examples/**`（每种牌的合法写法）、`scripts/cards/core/validate_main.gd` 与 `card_validator.gd`（校验器）、`scripts/cards/api/card_ids.gd`（常量：机制、锚点、指令……）、`scripts/tests/cards/lib/card_t.gd`（测试模板）、`scripts/tests/cards/suites/W0.txt`（清单格式）。

优先级：**主创原话 > 合同 > 任务卡**。发现冲突或合同不够用：以合同为准，开 GitHub issue `[api] <任务ID>: …`；需要别人的文件改动开 `[shared] <任务ID>→<对方任务号或 Claude>: …`；在自己的文件里先用合同已有的东西绕过去。

**【硬规则——违反任何一条，PR 直接退回】**
1. **归属**：只改合同 §2.2（= `docs/cards/ownership.json`）里写着 `<任务ID>` 的路径，加上每个任务默认拥有的四类：`scripts/tests/cards/<任务ID>/**`、`scripts/tests/cards/suites/<任务ID>.txt`、`data/cards/tags/<任务ID>.json`、`data/cards/ui_keys/<任务ID>.json`。不改别人的数据、`data/cards/_examples/**`、`data/cards/rules/**`（除非归属表写着你）、`scripts/**`（测试目录除外）、`tools/run_*.sh`、`project.godot`、任何旧文件（`data/*.json`、`data/town/**`、`data/story/**`、`art/{bg,items,portraits,…}/**`……只读）。提交前 `git status` 只能出现你的路径；Godot 顺手改的别人的 `.uid`/`.import`/`project.godot` 用 `git checkout --` 还原。
2. **免 AI 声明（Steam 版不能有任何 AI 生成的内容）**：玩家看得到、听得到、读得到的东西——正文、界面文字、人物名字、签诗、观察句、物品名、教学台词、美术、音频、配色——你**只能写占位**，而且只能放在不进包的草稿位置：
   - 数据里只写**机制字段 + `brief`**（`_doc`、`_meta.brief` 也算草稿）。brief 是干巴巴的设计说明——谁、什么事、有哪些选项、各自后果、史实依据（写年份）；**不写成能直接用的台词、文案、签诗，不写引号里的对白**；名字只在 brief 里“提议”，A 定稿。
   - **不写正文字段**（`text` `title` `body` `label` `name` `lines` `desc`，校验 V04）；**`brief`、`_doc`、`_meta.brief` 和 `_` 开头的键以外，任何字符串都不许有中文**（V05）。
   - 每张牌带 `"_provenance": {"by": "ai", "task": "<任务ID>", "date": "YYYY-MM-DD"}`；标签文件、界面键文件在 `_meta` 里带同样的 `_provenance`；界面键只写键和 brief（键以 `<任务ID 小写>.` 开头），效果里的原因键、告示键用自己的 `k0x.*`。
   - 占位美术只在 `art/_placeholder/**`（K12 的生成器出、每张带“稿”角标）、占位音频只在 `audio/_placeholder/**`。
   - **绝不写** `data/cards/text/**`、`art/cards/**`、`audio/cards/**`、`data/cards/theme/palette.json`、`legal/**`、`fonts/**`（CI 按 PR 作者判断：不是人写账号的 PR 碰了这些一律失败）。
   - **不拷旧文字**：`data/story/**`、`data/sessions/**`、`data/town/onboarding.json`、`data/town/rules.json`、`data/codebook.json` 的词、`data/cast.json` 的名字等都是 AI 写的旧内容，只读来了解事实，一个句子也不许拷进 brief。
3. **确定性**：游戏里影响状态的随机只用 `JevRng.draw(seed, domain, key)`（`scripts/sim/jev_rng.gd`），`domain` 只用合同 §6.3 登记给你的（只有 K14 有 `c.qa.*`）；数据里不写“随机”——要随机就用看得见的格子检定、`coin_check` 或轮盘（§5.1）。工具和测试要**确定**：同样的输入同样的输出（K12 的占位图两次生成字节相同）；测试不依赖墙钟、不 sleep。数据里的数一律整数（比例写整数百分比/千分比，V07）。
4. **隐藏数值不上界面**：概率、百分比、权重、底价、真假、来路、耐心、本心、口碑/风声的点数都不许显示。你写的数据不加任何给界面显示隐藏数值的字段；**新手指引步骤与规矩页的 brief（以及将来 A 写的正文）不提概率、几率、`%`、点数、权重、本心、底价、真假**。
5. **规矩在戏里讲 + 每个机制都有新手指引**：不做“规矩牌”、不写说明书；规矩由人物（哥哥、周妈、胡二、算命先生、何启明）或物件（告示、黄历、哥哥的账簿批注）在戏里讲。你的任务卡“新手指引”一节写着：你的数据/工具让哪些机制第一次出现、支持哪些指引步骤、要写哪些指引验收测试——照做。第一关第 1–3 天是固定的教学日（只发日程上的牌），除任务卡点名的牌外，**不要把日程牌排在第一关第 1–3 天**。
6. **鉴定只给观察**：物品的小游戏参数只是规格（物理量的范围），永远不出现真/假/仿的结论；判词英文（`fake` `real` `genuine` `forged` `authentic`…）不进任何键名。
7. **史实措辞**按 `docs/town/cards/src/era.json` 的 `notes`：日方扶植的政权一律加“伪”（伪维持会、伪维新政府、伪县政府、汪伪国民政府、伪中储券）；1945 年写“抗战胜利”；1949 年写“解放”；抗战按“十四年抗战”；1950 年代运动只作政策和经济事件，不做随机惩罚牌、不写斗争会和暴力。brief 里也照这个写。
8. **测试全绿**：`GODOT=… tools/run_card_tests.sh`（先 `--import`，再对全部真数据跑校验器 default 模式，再跑所有清单）和 `GODOT=… tools/run_legacy_smoke.sh` 退出码 0，日志里没有 `SCRIPT ERROR`、`ERROR`、`WARNING`、`Parse Error`、`FAIL:`、`DATA ERROR`、退出泄漏；每个清单测试最后一行是 `CARDS TEST PASS <名字>`（名字和清单那一行一致，用 ASCII）。数据任务在 `scripts/tests/cards/suites/<任务ID>.txt` 里登记一行校验器（`validate_main.gd -- --only=<你的文件> --name=<本行名字>`）和任务卡要求的测试；Python 工具的测试用一个 GDScript 包装脚本（`OS.execute("python3", …)`）登记进清单（`run_card_tests.sh` 只跑 Godot 脚本）。打印 `NOTE:` 的行不算失败——悬空引用这样报。
9. **id 与接口**：id 用合同 §3.5 的预留表，新加的 id 在 PR 里列出；**id 合入后不改名**（存档里有）。不发明合同里没有的字段、效果 op、条件 op、机制、锚点（`CardIds` 是封闭目录，新的走 `[api]`）；不改 `scripts/cards/api/**`、`scripts/cards/mock/**`、`scripts/tests/cards/lib/**`、`scripts/tests/cards/W0/**`。
10. **不自己加玩法**：合同和任务卡都没写的，用最保守的做法，写进 PR 的“需要主创/编排决定的事”；数字都是【待调】起步值，放数据里。

**【怎么干】**
- 对着 W0 的例子集和校验器开发，**不要等别的线**：引用了别的线还没写的 id（悬空引用）在 default 模式下只是 NOTE，列在 PR 里就行；任务卡写了你依赖谁、在哪个 Wave、哪些东西要先交（别人在等）。
- 先小后大：按任务卡“交付”一节的建议拆 PR。PR 标题 `[<任务ID>] <中文摘要>`，目标分支 `claude/festive-ride-vud32a`；描述按 `.github/pull_request_template.md` 每一节填满，再加上任务卡“交付”一节要求的内容（数量表、悬空引用、新 id、需要主创/编排决定的事……）。
- **Claude（编排）审每一个 PR**，结论三种：合并 / 改了再合（列“必须改”）/ 关掉（越界或方向错）。按“必须改”修完再请审；“建议”可以留到后面的 PR。数据 PR 合入并写了“交付”之后，K13 会做史实与敏感审读，开 `[K13→<任务ID>]` issue（附审读报告与逐条建议）；**由你在自己的分支改**、在 PR 里逐条回应——K13 不改别人的文件（合同 §2.6）。如果你是 K13：只开 issue、写报告，不碰别的任务的文件。
- 你的最后一个 PR：把任务卡末尾的“回报（执行者填写栏）”整张表填完贴进描述，并写“交付”。

**现在开始**：读完上面的文件后，先用一小段话复述你对 `<任务ID>` 的理解（要写哪些文件、数量、和哪些线对 id、你的数据让哪些新手指引步骤能亮），列出你第一个 PR 打算包含哪些勾选项和哪些测试，然后开工。

---

## 分线表（每个窗口一条线）

| 线 | 任务ID | slug | 分支 | 任务卡 | 粘贴说明 |
|---|---|---|---|---|---|
| 线 1 | K01 | `data-1938-people` | `cards/K01-data-1938-people` | `docs/handoff_cards/K01_data-1938-people.md` | 在第 1 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K01`、`<slug>` 换成 `data-1938-people`。（先交 `passersby.json`：K16 的指引要用已登记的算命先生 `suanming`。） |
| 线 2 | K02 | `data-1938-world` | `cards/K02-data-1938-world` | `docs/handoff_cards/K02_data-1938-world.md` | 在第 2 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K02`、`<slug>` 换成 `data-1938-world`。（先交 `bf.wheel`、`ev.any.wheel_go`、算命摊、庙会赌摊和大赌清单。） |
| 线 3 | K03 | `data-1939-people` | `cards/K03-data-1939-people` | `docs/handoff_cards/K03_data-1939-people.md` | 在第 3 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K03`、`<slug>` 换成 `data-1939-people`。（跨年条件按 K01 PR 里的走向名表写。） |
| 线 4 | K04 | `data-1939-world` | `cards/K04-data-1939-world` | `docs/handoff_cards/K04_data-1939-world.md` | 在第 4 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K04`、`<slug>` 换成 `data-1939-world`。（先交通用命运 18 张：第一关的命运牌靠它。） |
| 线 5 | K05 | `data-1940-people` | `cards/K05-data-1940-people` | `docs/handoff_cards/K05_data-1940-people.md` | 在第 5 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K05`、`<slug>` 换成 `data-1940-people`。（首发结尾的钩子只记走向和旗标，不直接结束游戏。） |
| 线 6 | K06 | `data-1940-world` | `cards/K06-data-1940-world` | `docs/handoff_cards/K06_data-1940-world.md` | 在第 6 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K06`、`<slug>` 换成 `data-1940-world`。（先交通用生活牌 12 张：春、冬两季都要够。） |
| 线 7 | K07 | `data-demand` | `cards/K07-data-demand` | `docs/handoff_cards/K07_data-demand.md` | 在第 7 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K07`、`<slug>` 换成 `data-demand`。（48 张条子一格不缺；第一关第 7 天的第一张要温和。） |
| 线 8 | K08 | `data-news-dossier` | `cards/K08-data-news-dossier` | `docs/handoff_cards/K08_data-news-dossier.md` | 在第 8 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K08`、`<slug>` 换成 `data-news-dossier`。（收集所有线引用的碎片 id 并全部定义；含教学碎片 `df.zhouma.1938.tut_news`。） |
| 线 9 | K09 | `data-common` | `cards/K09-data-common` | `docs/handoff_cards/K09_data-common.md` | 在第 9 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K09`、`<slug>` 换成 `data-common`。（先交 `self.ruhua`、`kp.brother_note`、`ct.zhouma`、夜牌、`pr.cell`。） |
| 线 10 | K10 | `data-fortune` | `cards/K10-data-fortune` | `docs/handoff_cards/K10_data-fortune.md` | 在第 10 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K10`、`<slug>` 换成 `data-fortune`。（签和测字只用 `omen_*`；开局本月运势的香案要看得出变宽。） |
| 线 11 | K11 | `data-items-mg` | `cards/K11-data-items-mg` | `docs/handoff_cards/K11_data-items-mg.md` | 在第 11 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K11`、`<slug>` 换成 `data-items-mg`。（参数只有规格、没有真假；新模板放新类别、文字全空。） |
| 线 12 | K12 | `art-pipeline` | `cards/K12-art-pipeline` | `docs/handoff_cards/K12_art-pipeline.md` | 在第 12 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K12`、`<slug>` 换成 `art-pipeline`。（占位图全在 `art/_placeholder/`、带“稿”角标、两次生成字节相同；先交牌框与新手指引用图。） |
| 线 13 | K13 | `review-history` | `cards/K13-review-history` | `docs/handoff_cards/K13_review-history.md` | 在第 13 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K13`、`<slug>` 换成 `review-history`。（先交措辞检查工具；改别人的数据只在对方写了“交付”之后，用 `cards/K13-to-K0x-<slug>` 分支。） |
| 线 14 | K14 | `qa-automation` | `cards/K14-qa-automation` | `docs/handoff_cards/K14_qa-automation.md` | 在第 14 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K14`、`<slug>` 换成 `qa-automation`。（W1 对着 Mock 搭走查；W2 的真引擎第 1–3 天指引走查与逐步截图是完成条件。） |
| 线 15 | K15 | `audit-provenance` | `cards/K15-audit-provenance` | `docs/handoff_cards/K15_audit-provenance.md` | 在第 15 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K15`、`<slug>` 换成 `audit-provenance`。（只用标准库；审核“关着门”，每一项都要有坏包夹具；`check_pr_paths.py` 的命令行不许改坏。） |
| 线 16 | K16 | `guide-data-post1949` | `cards/K16-guide-data-post1949` | `docs/handoff_cards/K16_guide-data-post1949.md` | 在第 16 个窗口粘贴本提示，并把 `<任务ID>` 换成 `K16`、`<slug>` 换成 `guide-data-post1949`。（先交第 1–3 天的 21 步、26 页规矩和教学牌；`_test.d1_3` 要在 Mock 上按顺序亮。） |

> 给主人的提醒：十六条线同时开工。K01 的 `passersby.json`、K02 的轮盘与大命运牌、K09 的教学用牌、K11 的现有模板参数、K12 的牌框与指引用图、K16 的第 1–3 天步骤，是别的线在等的东西——这些线的第一个 PR 请尽早提。合同或任务卡改了，Claude 会在对应 issue 里通知；在那之前，各线以当时集成分支上的合同为准。
