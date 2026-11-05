# K13 `review-history` · 史实与敏感审读

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K13 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K13: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 13**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器（`data/cards/rules/*.json` 也被校验：`_meta.owner`、无小数、**`brief` 和 `_` 开头的键以外不许有中文（V05）**）；例子集（工具先对着它跑） | W0（已完成） |
| K01–K11、K16 | 被审读的数据：**对方 PR 合入、并在 PR 里写了“交付”之后**你才开 `[K13→K0x]` 修正 issue；**改由对方在自己的分支做**，你复查（§2.6） | W1 末–W2 |
| K15 | 发行审核第 6 项会调用你的 `wording_lint.py`（扫人写的正文）；`stage_ship.py` 把 `wording.json` 排除出发行包（合同 §2.3、§11.4 第 1 项已定） | W1（并行，issue 里对） |
| G02 | 你核对的 1939 腊月公历起止，在 issue 里交给 G02 写进 `stages.json` | W1 |

- **波次**：W1 先交工具与规则（K 数据随时会合入，工具要先能跑）；W1 末–W2 逐个审读已交付的 K 数据、开 `[K13→K0x]` 修正 issue、复查对方的修改；W3 A 写正文时，K15 的审核用你的工具扫正文。
- **合同缺口（已在合同附录 E 定）**：①`wording.json` 不进发行包（合同 §2.3、§11.4 第 1 项；K15 的 `stage_ship.py` 排除它；词表的中文照旧只放 `_` 开头的键，过 V05）。②**你不跨线改文件**（合同 §2.6）：审读结论走 issue，由数据的主人改；`check_pr_paths.py` 不为 K13 设特例，你所有的 PR 都只动自己的路径。

## 分支

工具与报告：`cards/K13-review-history`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。
**没有跨线分支**：审读出的问题开 issue `[K13→K0x] …`，由对方在他自己的分支改（合同 §2.6）。

## 目标

保证游戏里写到的史实和措辞经得起看：日方扶植的政权一律加“伪”；1945 年写“抗战胜利”；1949 年写“解放”；抗战按“十四年抗战”；1950 年代的运动只作政策和经济事件，不做随机惩罚牌，不写斗争会和暴力；brief 里不出现可以直接拿去用的对白；新手指引的步骤和规矩页 brief 不提概率、点数、本心。做一个可重复跑的措辞检查工具 + 规则文件，逐个审读 K 数据写报告，并对已交付的数据开修正 issue、复查对方的修改。

## 必读

1. 合同 §0（红线 1、3、6、8）、§2.2、§2.6（**K13 不改别人的数据：对方 PR 合入并写了“交付”之后开 issue `[K13→K0x]`，由对方在自己的分支改；你复查**）、§3.4 K13、§4.3（brief 的地位：永不发行）、§4.5（正文覆盖层——W3 起你的工具也扫它）、§4.6（规则文件格式）、§4.9（V05）、§7.10.1 第 8 条（指引不泄露）、§11.2（brief 的写法）、§11.4 第 6 项（审核调用 `wording_lint.py`，“必须改”一条不许有）、§12.7（Python 工具只用标准库）、**§4.7.24（演出块，1.3 新：里面每个 cast、prop、拍子都有 brief）**。
2. `docs/cards/DESIGN_cards.md` 附录“措辞与史实要求”和“来源”、§五（年代表）、§六（解放后：1950–1953 土改、“五反”、统购统销只作政策和经济事件；1956 公私合营收尾不作褒贬）、§九.4。
3. `docs/town/cards/src/era.json`（`notes`、`pawn`、`launch`、`pivot_intro`、`branch_end`、`sources`）——你的规则和报告的依据。
4. `data/cards/rules/stages.json`（1939 腊月的公历起点待你核对，`_doc` 里注明了）。

## 要做的事

### A. 规则 `data/cards/rules/wording.json`
- [ ] 格式：`{"_meta": {"owner": "K13", "schema": 1}, "_doc": […], "rules": [{"id": "puppet_prefix", "level": "must", "scope": ["brief", "text"], "kind": "require_prefix", "_terms": […], "_prefix": "…"}, …]}`。
- [ ] **中文词表只放在以 `_` 开头的键里**（`_terms` `_prefix` `_allow` …）——校验器 V05 只放过 `brief`、`_meta.brief`、`_doc` 和 `_` 开头的键，规则文件里其他位置一个汉字都不许有。规则的 `id`、`level`（`must` 必须改 / `should` 应改 / `hint` 建议）、`scope`（`brief` / `text` / `guide_brief` / `docs`）、`kind` 用 ASCII。
- [ ] 至少这些规则：
  - `puppet_prefix`（must）：维持会、维新政府、县政府/区公所（1938–1945 语境）、国民政府（1940 起的南京政权）、中储券、商统会、清乡委员会等前面必须有“伪”或“汪伪”。
  - `year_1945`（must）：1945 年的胜利写“抗战胜利”（标出“光复”“日本战败”等替代写法给建议）。
  - `year_1949`（must）：1949 年写“解放”。
  - `war_length`（must）：“八年抗战” → “十四年抗战”。
  - `fifties_no_punish`（must）：1950 年代（`era` 是 195x，或 `docs/cards/post1949/**` 里的设计）不出现随机惩罚牌（`weight > 0` 且效果是坏的命运/事件），不写斗争会、批斗等运动场面。
  - `no_violence_detail`（must）：不写暴力细节（词表）。
  - `brief_no_dialogue`（must，scope `brief`/`guide_brief`）：引号（“” ‘’ 「」『』）里的内容超过 12 个字或含 `。！？` → 当成对白。
  - `guide_no_hidden`（must，scope `guide_brief`：`guide_step`、`rule_page` 的 brief，W3 起含它们的正文）：不提概率、几率、百分比、`%`、点数、权重、本心、底价、真假。
  - `no_percent`（must，scope `text`）：正文里没有 `%`。
- [ ] 每条规则的 `_doc` 写依据（era.json 的哪条 note、哪个来源）。

### B. 工具 `tools/cards/review/wording_lint.py`（只用标准库）
- [ ] 命令行：`python3 tools/cards/review/wording_lint.py [<路径或目录>…] [--scope=brief|text|guide_brief|docs|all] [--json=<输出文件>] [--fail-on=must|should]`；不给路径时扫 `data/cards/**`（不含 `_examples/`）的 brief、`data/cards/text/**` 的正文、`docs/cards/post1949/**`。
- [ ] 读 `data/cards/rules/wording.json`；遍历 JSON 时知道“这是哪张牌的哪个字段、牌的 `type` 和 `era`”（`guide_step`/`rule_page` 的 brief 算 `guide_brief`；`era` 用来判 1945/1949/195x 的规则）。
- [ ] 输出一行一个：`LINT MUST <文件>:<牌 id 或键>:<字段> <规则 id> <说明>`（`SHOULD` / `HINT` 同格式），最后 `LINT DONE <n> must, <n> should, <n> hint`；有 `--fail-on` 级别以上的问题退出码 1。
- [ ] **K15 的审核会这样调用**：`wording_lint.py <暂存目录>/data/cards/text --scope=text --fail-on=must`（W3 扫人写的正文）——保持这个调用方式稳定，改了要在 K15 的 issue 里说。
- [ ] 测试：`tools/cards/review/tests/test_wording_lint.py`（`unittest`）+ 夹具 `tools/cards/review/tests/fixtures/`（每条规则一个正例、一个反例：缺“伪”、“八年抗战”、引号对白、指引 brief 里写“概率”、正文里有 `%`……）；GDScript 包装 `scripts/tests/cards/K13/test_wording_lint.gd` 用 `OS.execute("python3", ["-m", "unittest", "discover", "-s", "tools/cards/review/tests"])`，退出码 0 才 PASS（找不到 `python3` 时试 `python`）。**清单里只跑夹具**，不跑全量真数据（真数据里别人的问题不能让所有线的 CI 变红）。

### C. 审读报告 `docs/cards/review/`
- [ ] `docs/cards/review/README.md`：怎么跑工具、规则清单、报告索引、“必须改”的处理状态表（报告 → `[K13→K0x]` issue → 对方的修正 PR → 你的复查结论）。
- [ ] 每个 K 数据任务一份 `docs/cards/review/<ID>.md`（K01–K11、K16）：逐文件列问题（牌 id、字段、原文片段——**只引 brief 的几个字，够定位就行**）、依据（era.json note / 来源链接）、建议改法、级别；工具结果 + 人工通读（工具抓不到的：时间线错位、人物关系矛盾、刻板印象、对真实地名人名的处理）。
- [ ] `docs/cards/review/stages_1939.md`：核对“1939 腊月”的公历起止（农历己卯年十二月对应的公历日期；第二关 30 天落在哪段），结论在 issue 里交给 G02（`[shared] K13→G02: stages.json 1939 起点`）。
- [ ] K16 的步骤与规矩页 brief、`docs/cards/post1949/**` 的设计：按 `guide_no_hidden`、`fifties_no_punish` 重点审。

### D. 修正 issue（§2.6：你不改别人的文件）
- [ ] 只对已合入、写了“交付”的 K 数据开；每个任务一个 issue，标题 `[K13→K0x] <摘要>`，正文按 `docs/cards/review/<ID>.md` 逐条列：牌 id、字段（只会是 `brief` / `tags`；1.3 起还有演出块里的 `stage.….brief`）、规则 id 与级别、依据、建议改法（给主人参考的说明，不是正文、不写台词）；@ 对方任务的执行者。
- [ ] 对方在自己的分支改完、PR 合入后，你用 `wording_lint.py` 对那几个文件复查，结论写进报告的处理状态表，再在 issue 里确认关闭；“必须改”没改的，在 issue 里标 `blocked` 并告诉 Claude（那条线已结束时 Claude 指派 `X##`）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

- [ ] `wording_lint.py` 的扫描范围加**演出块里的 `brief`**（合同 §4.7.24）：每张牌的 `stage.brief`、`stage.cast[i].brief`、`stage.props[i].brief`、`stage.intro[i].brief`、`stage.after.<键>[i].brief`；规则照旧（缺“伪”字、引号对白等——`brief_no_dialogue` 对拍子的 brief 尤其要紧：拍子的 brief 最容易写成台词）。输出行的字段写成上面这种路径（例 `LINT MUST data/cards/era/1938/events.json:ev.1938.police_check:stage.intro[0].brief brief_no_dialogue …`），按文件、牌 id、路径排序，结果确定。
- [ ] 审读报告里演出块单列一小节（每份 `docs/cards/review/<ID>.md` 里“演出块”一节：哪张牌、哪一拍、问题、建议改法）。
- [ ] 修正 issue 照旧走 `[K13→K0x]`：字段 1.3 起多了演出块里的 `stage.….brief`。

**新增 / 作废的交付**

- 新增：工具的演出块扫描、夹具、报告里的“演出块”一节。作废：无。

**锚点、界面事件、要证明的步骤**

- 工具任务照旧不登记锚点、不发界面事件；新手指引的审读范围不变。

**测试与截图**

- `tools/cards/review/tests/fixtures/` 加一份带演出块的假牌文件：一拍的 brief 里有超过 12 个字的引号内容 → 报 `LINT MUST … stage.intro[0].brief brief_no_dialogue`；一个 `cast` 的 brief 写“维持会”没有“伪” → 报 `puppet_prefix`；干净的一拍不报。`K13_wording_lint` 照旧只跑夹具。
- 截图：不交（工具任务）。

**已经做了的哪些还有效**

- 全部有效。

**日期**：随你下一个工具 PR 一起交；K01、K02、K09、K16 的 1938 演出块（目标 10-27）合入、写了“交付”之后照常审读。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `tools/cards/review/**`、`docs/cards/review/**`、`data/cards/rules/wording.json`
- 默认拥有：`scripts/tests/cards/K13/**`、`scripts/tests/cards/suites/K13.txt`、`data/cards/tags/K13.json`、`data/cards/ui_keys/K13.json`
- **没有例外**：别的任务的数据文件你一个字都不改（§2.6）；`check_pr_paths.py` 按上面这些路径查你的每一个 PR。

## 不能做的事

1. **不写玩家最终内容**：不写、不改 `data/cards/text/**`（A/B 的正文——你只**报告**正文的问题，开 `[content]` issue 给 A/B）；报告里给的“建议改法”是给 A 参考的说明，不是可以直接贴进游戏的成品文字，也不写进任何数据的正文字段。
2. 不改别人的任何文件（包括 `brief` / `tags`）；建议改法只写在报告和 issue 里；对方没写“交付”之前只在报告里记，不开修正 issue。
3. 不改 `data/cards/rules/` 下别人的规则文件；`wording.json` 里中文只放 `_` 开头的键。
4. 工具只用标准库、不联网、确定（同样的输入同样的输出、行按文件名和 id 排序）。
5. 审读不评判主创的玩法设计；只管史实、措辞、敏感内容和红线 3（指引不泄露隐藏数值）。

## 接口

**用到**：`docs/town/cards/src/era.json`；所有 K 数据文件（只读）；`data/cards/text/**`（W3，只读）。

**提供**：`wording_lint.py`（K15 的审核第 6 项调用；Claude 审 PR 时也跑）；`wording.json`；审读报告；`stages.json` 1939 日期的核对结论（给 G02）。

## 新手指引

- **锚点**：不登记（工具任务）。**first-time**：不发。
- **你支持的步骤**：全部 66 个机制的指引步骤与 26 页规矩（K16 的 `steps.json` / `rule_pages.json`）的 brief，以及 W3 起 A 写的 `say` `bubble` `title` `body`：规则 `guide_no_hidden`（不提概率、点数、本心、`%`）、`brief_no_dialogue`、史实规则都覆盖它们（红线 3、§7.10.1 第 8 条）。
- **指引验收（必须有测试）**：`tools/cards/review/tests/fixtures/` 里有一份假的 `steps.json`（两步：一步 brief 写了“概率”或“%”或“本心”，一步干净）和一份假的 `rule_pages.json`；单测断言第一步报 `LINT MUST … guide_no_hidden`、第二步没有；同样一份假的 `data/cards/text/guide/steps.text.json` 里 `bubble` 含 `%` → 报 `no_percent`。
- **审读**：K16 交付后，`docs/cards/review/K16.md` 必须逐步过一遍（66 个机制的步骤 + 26 页规矩），结论写进报告。
- **截图**：不交截图（工具任务）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K13.txt`：

```
# K13 措辞检查工具（docs/handoff_cards/K13_review-history.md）
K13_wording_lint|res://scripts/tests/cards/K13/test_wording_lint.gd|180|
K13_rules_valid|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/rules/wording.json,data/cards/tags/K13.json,data/cards/ui_keys/K13.json --name=K13_rules_valid
```

**通过条件**：
- [ ] 措辞检查对夹具里的正反例全对（合同 §12.2 K13）；每条规则至少一个正例一个反例。
- [ ] `wording.json` 过校验器（无中文在非 `_` 键、无小数、`_meta.owner == "K13"`）。
- [ ] 工具对 `data/cards/_examples/**` 跑一遍不崩（PR 贴输出）；对当时已合入的真数据跑一遍，结果写进对应报告。
- [ ] `tools/run_card_tests.sh` 与 `tools/run_legacy_smoke.sh` 全绿；无 `SCRIPT ERROR` `ERROR` `WARNING` `FAIL:`、无泄漏；每行 `CARDS TEST PASS <名字>`。

**怎么跑**：
```bash
python3 tools/cards/review/wording_lint.py --scope=all
python3 -m unittest discover -s tools/cards/review/tests
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K13 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```

## 交付

- **PR 标题**：`[K13] <中文摘要>`（工具、规则、报告），目标 `claude/festive-ride-vud32a`；修正走 issue `[K13→K0x] <中文摘要>`，不是 PR。建议：①`[K13] 措辞检查工具、规则与夹具测试`（先合）；②`[K13] 1939 腊月公历核对`（报告 + 给 G02 的 issue）；③每个 K 数据交付后 `[K13] <ID> 审读报告`；④每份报告对应的 `[K13→<ID>]` 修正 issue（和复查结论）。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；工具对真数据的统计（must/should/hint 各几条、分布在哪些任务）；报告链接；修正 issue 的清单与处理状态；开出的 `[content]`、`[shared]` issue；完成写“交付”。

## 审核（Claude 重点）

1. 越界（只动自己的三类路径，没碰别人的数据；修正全走 issue）；2. 规则覆盖 era.json 的全部 notes 与指引不泄露；3. 工具确定、只用标准库、K15 的调用方式稳定；4. 规则文件中文只在 `_` 键；5. 报告有依据、有建议、不写成品正文；6. 1939 日期结论清楚。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（工具 / 报告，按顺序）；修正 issue 链接与处理状态 | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 规则清单（id / 级别 / 依据） | |
| 各任务审读结论（must / should / hint 数） | |
| 1939 腊月公历起止结论 | |
| 开的 issue | |
| 合同或数据缺口 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
