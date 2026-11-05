# K07 `data-demand` · 条子（4 类 × 4 档 × 3 年）

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K07 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K07: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 7**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default（V17 条子形状、V15 格子）、`_schema/demand.json`、例子集 `data/cards/_examples/demand/demands.json`（四类各一张 + `ev.any.demand_return`）、`data/cards/rules/demand_rules.json` 初值（G03 的） | W0（已完成） |
| G03 | 条子的规则（每周一发、七天、拖一拖、按档吃亏阶梯、六种办法的选项 id、要人回来的检定）——你只写数据，规则在 `demand_rules.json` 和 G03 代码里 | W1（并行；规则以合同 §4.7.6 为准） |
| K08 | 要消息的条子交出的消息牌（`on_inform`）在 K08 | W1（并行） |
| K11 | 要货的条子要的物品类别（`cat`）用现有 7 类或 K11 的新类 | W1（并行） |
| K12 | 条子插图 `illus.dm.<kind>`、类别图标（C05 用 `icon.demand.<kind>`） | W1（并行） |

- **波次**：W1。**W1 完成条件之一**：K07 合入（1938 数据 strict 全绿）。
- **W2**：G06 平衡报告“条子按类 × 档的完成/拖延/失败”出来后按报告修数；按 K13 的 `[K13→K07]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6）。

## 分支

`cards/K07-data-demand`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写胡二每周一送来的“条子”：要钱、要货、要人、要消息四类，小/中/大/要命四档，1938、1939、1940 三年每年换说法，共 48 张；每张的数目、要的货、要几个人、要谁的消息，讲价/顶替/编一个的检定格子，可选的按卡覆盖吃亏效果；外加系统牌 `ev.any.demand_return`（派出去的人“回来了吗”）。只写**机制 + brief**。

## 必读

1. 合同 §0、§2.2、§2.5（原因键用 `k07.*`）、§3.4 开头与 K07、§3.5（条子 id `dm.<1938|1939|1940>.<money|goods|people|info>.t<0-3>`；系统牌表 `ev.any.demand_return` 归你）、§4.4.1–§4.4.2（格子、检定；`pay: true` 的格子）、§4.6 的 `demand_rules.json`（`issue_weekday` `deadline_days` `delay` `tier_by_stage` `tier_heat_step` `max_tier` `fail` 四档阶梯）、**§4.7.6 全节**（`kind` `tier` `deadline_days` `resolve` `on_fail`；六种办法的保留 id `pay` `haggle` `substitute` `fabricate` `send_person` `inform`——**数据里不写 `choices`**）、§4.9（V15、V17：每个年 × 类 × 档至少一张）、§5.2–§5.3、§7.4.3、§7.10.10（条子相关的步骤）、§11.2。
2. `docs/cards/DESIGN_cards.md` §三.3（条子：胡二每周一张、七天、拖一拖、四档）、§三.10、§五（每年的时局：1938 伪维持会、1939 伪县政府与区公所、1940 汪伪成立后新官上任、摊派换名目）、附录、“实现时的理解”第 13 条（第一张条子在第 7 天）。
3. `docs/town/cards/src/era.json` 的 `notes`、`pawn[0..2]`。
4. 只读参考：`scripts/core/protection.gd` 与 `data/town/protection.json`（旧版保护费的升级阶梯，是条子的前身；文字是 AI 写的，不许拷）；例子集 `data/cards/_examples/demand/demands.json`。

## 要做的事

### A. 48 张条子（`data/cards/demand/` 下，文件名建议 `demands_1938.json` `demands_1939.json` `demands_1940.json`）
- [ ] 每个 年 × 类 × 档 一张：`id: "dm.<年>.<kind>.t<tier>"`、`type: "demand"`、`era: ["<年>"]`、`weight: 10`（同一年同一类同一档只有一张时权重无所谓；以后加变体再分）、`kind`、`tier`、`tags`（`levy` `official` …，在 `tags/K07.json` 声明）、`resolve`、`slots`、`art: "illus.dm.<kind>"`、`brief`、`_provenance: {"by": "ai", "task": "K07", "date": "<提交当天>"}`。
- [ ] **`resolve` 按类**（§4.7.6，V17：只许本类的键 + `haggle` `substitute` `fabricate`）：
  - 要钱 `{"money": {"amount", "jitter_pct", "heat_tier_pct"}, "haggle": {"slots": […], "need", "tier_down"}}`；格子 `{"id": "cash", "accepts": ["money"], "pay": true}`。
  - 要货 `{"goods": {"cat", "n"}, "substitute": {"money"}}`；格子 `{"accepts": ["item"], "item_match": {"cat": …}, "pay": true}`。
  - 要人 `{"people": {"n", "away_days", "return_check": {"attr", "need"}}, "substitute": {"money"}}`；格子收 `self` / `contact`（带 `attr`）。
  - 要消息 `{"info": {"n"}, "fabricate": {"attr", "need", "on_fail": […]}}`；格子收 `news`。
- [ ] 数目随档位和年份涨（物价指数在 `stages.json`：1938 = 100、1939 = 160、1940 = 220；你的 `amount` 写 1938 年价还是当年价，**和 G03/G04 在 issue 里确认后写进 `_meta.brief`**）【待调】。
- [ ] **第一张条子不能太凶（合同 §3.4 K07 确认）**：第一关第 7 天（1938-03-07 星期一）发第一张；`tier_by_stage[0] = 0`，所以是 `t0`（风声高时可能 +1）。1938 的 `t0` 四张：数目小（要钱 ≤ 起始钱 340 的十分之一左右【待调】）、要货 1 件常见货、要人 `away_days` 短、要消息的“编一个”`need` ≤ 1。
- [ ] 可选 `on_fail`（按卡覆盖默认的四档吃亏阶梯）：只在有特别理由时写，brief 写清理由；默认阶梯 t0 罚钱、t1 查封三天、t2 拿走一件家当、t3 被抓。
- [ ] 每年换说法：brief 写清这一年的名目和依据（1938 伪维持会摊派；1939 伪县政府、区公所；1940 汪伪成立后新官上任、换名目）。
- [ ] **系统牌 `ev.any.demand_return`**（`type: "event"`、`era: ["*"]`、`weight: 0`、`must_resolve: true`、至少一个 `omen_*`）：要人条子派出去的人回来那天由 G03 发进手牌，当场按他的属性掷（看得见）；格子与检定的形状照例子集的那张写，brief 写清“没回来 = `person_state gone`”。和 G03 在 issue 里确认它需要哪些字段。

### B. 标签、界面键
- [ ] `data/cards/tags/K07.json`；`data/cards/ui_keys/K07.json`（`k07.reason.*`：交钱、罚款；`k07.notice.*`）。胡二送条子时的台词是牌的正文 `lines.issue`（A 写），不是你的键。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] 条子不在手牌里，打烊不影响它：没到期就接着计时（`settle` 30 照旧按档吃亏）。你的 48 张不用为打烊加字段。
- [ ] **系统牌 `ev.any.demand_return`**（“回来了吗”，在手牌里、`must_resolve: true`）：打烊时没理会会怎样要写明（V37）——它有顶层 `check` 的话默认当没过（= 人没回来，`person_state gone`），这对玩家太狠；**建议写 `effects.on_expire`：人自己回来了、只是晚了（例 `{"op": "person_state", "person": …, "state": "away", "days": 1}` 这类，具体由你定，人物 id 由引擎按 `vars` 填的写法和 G03 在 issue 里对齐）**，brief 写明，PR 里列出。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**合同 1.3 不影响本任务**：条子的默认演法（胡二站柜台前、条子拍在柜台上）够用；演出块可选（建议要人、要货的高档写 `walk: "hu2_men"`）。`ev.any.demand_return` 可选。

- 要写的话：另开一个 PR `[K07] 演出块`，等 G01 的 1.3 小 PR（10-15）合入后再提；格式见合同 §4.7.24，规则见 §4.9 V38–V42。条子牌没有 `person`，胡二是默认演法替你摆上来的——你一旦自己写 `intro` / `after` 让胡二开口，就要把 `{"who": "hu2", "at": "customer"}` 也写进 `cast`（V39）；只写 `walk` / `fx` / `props` 的话不用管。`after` 的键可以用 `success` `fail` `delay` 和六种办法的 id（`pay` `haggle` `substitute` `fabricate` `send_person` `inform`，W0 的 `CardDslShapes.check_stage` 对条子另认这六个）；每拍必须有 `brief`，只写键、不写台词。
- 1.3 起界面读条子的类别和档位用 CardView 的 `demand: {kind, tier}`（G03 出），你的数据不用为此改。
- 下文“新手指引”表里的旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`gd.demand` 的锚点改成墙上的条子 `a.scene.notewall`、备 `a.tab.demands`；`a.top.notice` → `a.scene.notice`），数据任务不登记锚点，对你没有要做的事。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/demand/**`
- 默认拥有：`scripts/tests/cards/K07/**`、`scripts/tests/cards/suites/K07.txt`、`data/cards/tags/K07.json`、`data/cards/ui_keys/K07.json`

## 不能做的事

1. **不写玩家最终内容**（正文字段——包括胡二的台词 `lines.issue`、结果 `outcomes.*`；人写路径；brief 以外的中文；台词与引号对白）。
2. 不改 `data/cards/rules/demand_rules.json`（G03 的；四档阶梯、拖一拖的天数要改走 `[shared] K07→G03`）；不在数据里写 `choices`（办法由 G03 按 `kind` 和 `resolve` 生成）。
3. 不改别人的文件（K08 的消息、K09 的人脉、`_examples/**`）。
4. 不写 `minigame`；不发明字段、op、条件；不自己加玩法（例：不加第五类条子）。
5. 史实措辞：伪维持会、伪县政府、汪伪；不写暴力细节；不拷旧版 `protection.json` 的文字。

## 接口

**用到**：§4.7.6 条子格式、§4.4.1 格子（`pay: true`、`item_match`）、§5.2 效果（`heat` `pay` `shop_closed` `estate_seize` `arrest` `person_state`）。

**提供**：48 张条子（G03 的 `c.demand.kind/pick/amt` 抽、C05 的条子板与面板显示 `kind`、`tier`、`days_left`——1.3 起是条子抽屉和胡二那一出，类别和档位读 CardView 的 `demand {kind, tier}`）；`ev.any.demand_return`（G03 发）。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `demand`（G03） | 第一张条子（第一关第 7 天，1938 `t0`） | `gd.demand`（hu2 · `a.scene.notewall` 备 `a.tab.demands`；讲条子与七天期限） |
| `demand_delay`（G03） | 第一次打开条子面板 | `gd.demand_delay`（hu2 · `a.demand.delay`） |
| `demand_people_return`（G03） | `ev.any.demand_return` 进手牌 | `gd.demand_people`（obj.brother_ledger · `a.card@{uid}`） |
| `demand_inform` `demand_fabricate`（G03） | 第一次打开“要消息”的条子 | `gd.demand_inform`（obj.brother_ledger · `a.demand.modes`） |
| `demand_fail`（G03） | 条子到期没办成 | `gd.demand_fail`（hu2 · `a.demand.tier` 备 `a.scene.notice`） |
| `shop_closed`（G04） | 默认阶梯 t1 没办成 → 查封三天 | `gd.shop_closed`（obj.notice · `a.scene.notice`） |

- **指引验收（必须有测试）** `scripts/tests/cards/K07/test_guide_support.gd`：
  1. 1938 的四张 `t0` 都存在；要钱的 `amount` ≤ 40（起步阈值【待调】，测试里写成常量并在 PR 说明）、要人的 `away_days` ≤ 7、要消息的 `fabricate.need` ≤ 1。
  2. 每张要人条子有 `resolve.people.return_check`（看得见的回来检定）；每张要消息条子有 `resolve.fabricate`（`gd.demand_inform` 讲“交消息或编一个”）；每张要钱条子有 `haggle`。
  3. `ev.any.demand_return` 存在、`weight == 0`、`type == "event"`、有 `omen_*`。
- **W2**：K14 三关走查里第 7 天亮 `gd.demand`（`_test.d1_3` 只到第 3 天，不含条子）。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K07.txt`：

```
# K07 条子（docs/handoff_cards/K07_data-demand.md）
K07_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/demand/**,data/cards/tags/K07.json,data/cards/ui_keys/K07.json --name=K07_validate
K07_data|res://scripts/tests/cards/K07/test_data.gd|120|
K07_guide_support|res://scripts/tests/cards/K07/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K07_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] **48 张齐**：三年 × 四类 × 四档每格恰好 ≥ 1 张（V17 的 strict 要求，提前自查），id 与 `kind`/`tier`/`era` 一致。
- [ ] 同一年同一类，档位越高要的越多（钱数、货数、人数、离开天数、检定 `need` 不减）；同一类同一档，年份越晚数目不减（按你在 `_meta.brief` 里写的计价口径）。
- [ ] 每张：`_provenance.task == "K07"`、brief 非空、标签已声明、`resolve` 只含本类键 + `haggle/substitute/fabricate`、至少一个 `pay: true` 的格子（要人、要消息除外）。
- [ ] 原因键 `k07.` 开头且已登记。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；伪政权名前有“伪”/“汪伪”。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K07 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K07] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K07] 1938 条子 16 张与 ev.any.demand_return`（先合）；②`[K07] 1939、1940 条子`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；4 × 4 × 3 的数目表（钱数/货/人/消息、`need`）；计价口径（1938 年价还是当年价）；悬空引用；需要主创/编排决定的事（数目、阈值）；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 48 张齐、形状过 V17、档位单调；3. 第一张条子温和；4. 不写 `choices`、不改 G03 的规则文件；5. 免 AI 声明与 brief 写法；6. 每年名目的史实措辞。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 4 × 4 × 3 数目表、计价口径 | |
| 新加的标签、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
