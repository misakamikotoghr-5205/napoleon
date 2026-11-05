# K10 `data-fortune` · 轮盘与扇区、签、测字、黄历

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K10 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K10: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 10**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default（V18 轮盘、V19 签、V20 黄历动作）、`_schema/{wheel,wheel_segment,fortune_lot,cezi,almanac_day}.json`、例子集 `data/cards/_examples/fortune/*.json`、`tags/W0.json`（**封闭的 `omen_*` 家族**）、`data/cards/rules/fortune.json` 的默认（G05 的） | W0（已完成） |
| G05 | 轮盘数学（§9.1：份数、加宽、`arc_deg`、停针）、求签读未来发牌与钉签（§9.3）、测字的禁签、黄历奖励（§9.4）——规则在引擎里，你写数据 | W1（并行；以合同为准） |
| K02 / K04 / K06 | 大赌牌 `bf.*`（大轮盘扇区用 `add_card` 发它们；**V36：每张 `bf.*`（除 `bf.wheel`）都要被某个扇区引用**）；庙会/赌摊/算命摊事件的 `opens_wheel` / `opens_fortune` / `cost` | W1（并行；他们 PR 里给大赌清单） |
| K12 | 轮盘面 `wheel.<kind>`、扇区图标 `icon.ws.<slug>` 的占位 | W1（并行） |

- **波次**：W1。**W1 完成条件之一**：K10 合入（1938 数据 strict 全绿）。
- **W2**：G05 在你的真数据上跑签的准确性（1000 种子 100%）与轮盘单调性；G06 平衡报告（大轮盘三类扇区分布、签准确率、黄历照做率）出来后修数；K13 审读（按 K13 的 `[K13→K10]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6））。

## 分支

`cards/K10-data-fortune`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写 v1.1 的“命运轮盘”与“算命”数据：四个轮盘（本月运势 `wh.month`、大轮盘 `wh.big`、庙会 `wh.fair`、赌摊 `wh.gamble`）的定义（香案收什么、每样算几份、每份加宽多少、代价）、各年代的扇区（扇区内容随年代变）、签（≥ 30 支）、测字的字（12–16 个）、黄历条目（≥ 24 条）。签诗、解曰、字、提示、扇区名的**正文全部留给 A**；brief 只写征兆和吉凶方向。**界面上不显示百分比、权重、好坏——只看扇区大小**（红线 3）。

## 必读

1. 合同 §0（红线 1、3）、§2.2、§2.5（**`omen_*` 封闭家族：签的 `hint_tags` 和字的 `tags` 只许用它们**）、§3.4 开头与 K10、§3.5（`wh.*` 四个轮盘 id；大命运 `bf.*`）、§4.1–§4.4、**§4.7.17**（wheel：`kind` `incense {accepts, money_per_unit, contact_attr, unit_widen_pct, max_units}` `cost`；wheel_segment：`wheel` `arc` `valence`（`good`/`neutral`/`bad`，隐藏）`conditions`（转的时候查，不满足不上盘——v1 §三.9 本心决定大命运出现哪几张）`month_mods`（只有 `wh.month`）`effects`（数组））、**§4.7.18**（fortune_lot：`grade` 0–4、`hint_tags`；cezi：`tags`；almanac_day：`season` `yi` `ji` `reward`；**黄历动作枚举**）、§4.6 的 `fortune.json`（默认份数、加宽、`max_units`、签窗口）、§4.9（V18、V19、V20、V34、V36）、**§9 全章**（轮盘数学、三种转法、签为什么准、黄历）、§7.10.10、§11.2。
2. `docs/cards/DESIGN_cards.md` **§九.1、§九.2**（主创原话：命运轮盘三种用法、香案、不显示百分比；算命：黄历宜忌、求签、测字、本心低签更凶）、§三.6、§三.9、“实现时的理解”第 2–7、17 条。
3. 例子集：`data/cards/_examples/fortune/{wheels,segments_1938,lots,cezi,almanac}.json`。
4. `docs/town/cards/src/era.json` 的 `notes`（黄历、签文里如出现时局，措辞同样要求）。

## 要做的事

### A. `data/cards/fortune/wheels.json`（4 个轮盘）
- [ ] `wh.month`（`kind: "month"`；香案收 `money` `kept` `contact`；`money_per_unit`、`contact_attr: "pull"`、`unit_widen_pct`、`max_units`；`cost: {}`）、`wh.big`（`kind: "big"`；香案同上；`cost: {}`）、`wh.fair`（`kind: "fair"`；`cost: {"money": n}`）、`wh.gamble`（`kind: "gamble"`；`cost: {"stake": true}`——押一张留着的牌）。`art: "wheel.<kind>"`、`weight: 0`、brief、`_provenance`。数【待调】，起步可用 `fortune.json.wheel` 的默认（每 5 个钱一份、每份加宽 15%、最多 6 份）。

### B. 扇区（`data/cards/fortune/segments_1938.json` `segments_1939.json` `segments_1940.json`；全年代通用的 `era: ["*"]` 段可以另放 `segments_any.json`——你的目录 `data/cards/fortune/**` 都归你，PR 里列出新文件名）
- [ ] **本月运势** `wh.month`：每年 6–8 段（`ws.<年>.month.<slug>`），含“财星高照”一类好段（`month_mods: [{"pool": "person", "tags_any": ["buyer"], "pct": 130}]`：买家多一些）、“流年不利”一类坏段（`month_mods: [{"pool": "fate", "valence": "bad", "pct": 140}]`：命运牌坏的多）和几段平常的；`arc` 整数（画在盘上的基础大小）、`valence`、`art: "icon.ws.<slug>"`。
- [ ] **大轮盘** `wh.big`：三类——翻身（`good`）、平安（`neutral`）、坠底（`bad`）——每年各 2–3 段（可以加 `era: ["*"]` 的通用段）；段的 `effects` 常见是 `{"op": "add_card", "card": "bf.<…>", "to": "hand"}`（发一张大赌到手上）；**每张大赌（K02/K04/K06 的 `bf.*`，`bf.wheel` 除外）至少被一个段引用（V36）**；翻身段用 `conditions` 按本心挡（例 `{"conscience_gte": -20}`，阈值【待调】）——本心太低时好段不上盘。
- [ ] **庙会** `wh.fair` 6 段、**赌摊** `wh.gamble` 6 段（`era: ["*"]` 或按年）：效果是小得小失（钱、口碑、一张留着的牌、一条消息……）；赌摊的坏段让押的牌没了（引擎做，§7.4.4），你只写段的 `valence` 和效果。
- [ ] 每段：`type: "wheel_segment"`、`wheel`、`era`、`weight: 0`、`arc > 0`、`valence`、`effects`（数组）、`brief`（这一段是什么运势、对牌局的影响；**不写段名正文**）、`_provenance: {"by": "ai", "task": "K10", "date": "<提交当天>"}`。

### C. `data/cards/fortune/lots.json`（签，≥ 30）
- [ ] `lot.g<等第>.<omen 家族去掉 omen_ 前缀>`（例 `lot.g1.official`）：`grade` 0 下下 · 1 下 · 2 中 · 3 上 · 4 上上；`hint_tags` 只用 `omen_*`（一支签一个家族）；**每个等第至少 6 个家族**，外加**每个等第一支 `hint_tags: []` 的“泛泛”签兜底**（例 `lot.g1.any`）；`era: ["*"]`、`weight: 10`。
- [ ] brief 只写“哪个等第、哪个征兆家族、吉凶方向”；签诗 `verse`、解曰 `gloss` 由 A 写，要含糊、不点名哪张牌。

### D. `data/cards/fortune/cezi.json`（测字，12–16 个）
- [ ] `cz.<拼音>`（例 `cz.shui`）：`tags` 只用 `omen_*`（1–2 个）；`era: ["*"]`、`weight: 10`；brief 写“哪个字、对应哪个征兆、‘有’与‘无’各提示什么方向”。字本身（`char`）和提示（`has` `none`）是正文，A 写；**id 里的拼音是你的提议**，A 定字。
- [ ] 十个 `omen_*` 家族里至少 8 个有字对应。

### E. `data/cards/fortune/almanac.json`（黄历，≥ 24）
- [ ] `alm.<slug>`：`season`（0–3 数组）、`yi`、`ji`（只用 §9.4 的 12 个动作：`pawn_in` `buy_in` `sell_out` `redeem` `trade` `meet` `travel` `pray` `repair` `rest` `lend` `wed`，V20）、`reward`（照做——做了宜的、没做忌的——的小好处：`rep +1`、`heat -1`、小钱……；**没有惩罚**）、`era: ["*"]`、`weight`。
- [ ] 每个季节 ≥ 6 条；首发三关是春（1938、1940）和冬（1939），春、冬都要充足。

### F. 标签、界面键
- [ ] `data/cards/tags/K10.json`（如果用到 `omen_*` 以外的标签——签和字**只许**用 `omen_*`）；`data/cards/ui_keys/K10.json`（`k10.reason.*`：香火钱、庙会/赌摊的钱；`k10.notice.*`）。黄历动作的字（`g05.almanac.<动作>`）归 G05，不是你。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**合同 1.3 不影响本任务**：轮盘是叠层（C01 开在画面正中，画面在下面照常；庙会的演出块可以先换城隍庙背景，那是 K02 的事），签诗、解曰、测字的话改在对话框里说（C07），黄历条进了顶部 HUD——你的轮盘、扇区、签、字、黄历数据一样不用改。轮盘、扇区、签、字、黄历这几类数据也不能带演出块（V40）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/fortune/**`
- 默认拥有：`scripts/tests/cards/K10/**`、`scripts/tests/cards/suites/K10.txt`、`data/cards/tags/K10.json`、`data/cards/ui_keys/K10.json`

## 不能做的事

1. **不写玩家最终内容**：签诗、解曰、字、提示、扇区名与正文、轮盘标题全由 A 写；brief 不写成签诗或谜面，不写引号里的对白；brief 以外不出现中文（**字的 id 用拼音，不用汉字**）。
2. **不新增征兆家族**（`omen_*` 是封闭集合，加新家族走 `[api]`）；签和字不用 `omen_*` 以外的标签。
3. 不改 `data/cards/rules/fortune.json`（G05 的；默认份数、签窗口、本心阈值要改走 `[shared] K10→G05`）；不改 K02/K04/K06 的大赌牌（只引用）。
4. 黄历只奖不罚（§9.4）；首发三关的扇区可以有坏段（坠底、流年不利），但效果只走合同里的 op，brief 不写暴力细节。
5. 不发明字段、op、条件；不自己加玩法（例：不加第五个轮盘）。

## 接口

**用到**：§4.7.17–§4.7.18 的格式；§5.2（`add_card` `money` `rep` `heat` `deck_mod` `weather` `fate_now` …）、§5.3（`conscience_gte` 等）；大赌 id（K02/K04/K06）。

**提供**：`wh.*` 与扇区（G05 的 `CardWheel`、C06 的轮盘面板按 `arc_deg` 画）；签、字（G05 的 `CardFortune`、C07）；黄历（G05 的 `CardAlmanac`、C07 的黄历条）。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪份数据让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `month_wheel`（G05） | `wh.month` + 1938 本月运势扇区（开局就转） | `gd.m.wheel`（brother · `a.wheel.face`） |
| `incense`（G05） | `wh.month.incense`（香案收钱/留牌/人脉） | `gd.m.incense`（brother · `a.wheel.incense`；放之前先亮） |
| `almanac`（G05） | 黄历条目（第 1 天就有，步骤第 4 天才亮） | `gd.almanac`（obj.almanac · `a.almanac`） |
| `lot` `cezi`（G05） | 签、字（第 5 天教学算命先生） | `gd.lot` `gd.cezi`（suanming · `a.fortune.lot` / `a.fortune.cezi`） |
| `big_wheel`（G05） | `wh.big` 的扇区 | `gd.big_wheel`（obj.brother_ledger · `a.wheel.face`） |
| `fair_wheel` `wheel_stake` `gamble_wheel`（G05） | `wh.fair` / `wh.gamble`（押牌） | `gd.fair_wheel`（obj.notice · `a.wheel.cost`）、`gd.gamble_wheel`（"" · `a.wheel.cost`） |

- **教学要求（合同 §3.4 K10 确认）**：
  - **开局的轮盘指引要看得出香案的作用**：1938 本月运势至少一段好段，放满香案（`U = max_units`）后，好段合计的角度至少是不放时的 1.5 倍【待调】——按 §9.1 的整数公式算。
  - **第 4 天起的黄历条目覆盖柜台动作**：春季条目里至少一半的 `yi` 含 `pawn_in` `buy_in` `sell_out` `trade` `redeem` 之一（玩家第 4 天照着做得到）。
- **指引验收（必须有测试）** `scripts/tests/cards/K10/test_guide_support.gd`：
  1. 用 §9.1 的公式（份数 U、好段 `w = arc × (100 + U × unit_widen_pct)`、其余 `w = arc × 100`、`arc_deg = 360 × w / Σw`，整数运算到最后一步）算 1938 `wh.month`：`U = 0` 与 `U = max_units` 时好段合计角度之比 ≥ 1.5；U 从 0 到 `max_units` 单调不减。
  2. 春季（`season` 含 0）的黄历条目 ≥ 6，其中 ≥ 50% 的 `yi` 含柜台动作。
  3. 每个等第（0–4）有一支泛泛签；所有签、字的标签都在 `omen_*` 家族里。
  4. 大赌引用报告：当前真数据里每张 `type == "big_fate"` 且 `id != "bf.wheel"` 的牌，没被任何 `wh.big` 扇区的 `add_card` 引用的打印 `NOTE: bigfate_unreferenced <id>`——**只打印、不断言**（K02/K04/K06 合入新大赌时不能让所有人的 CI 变红）；你的扇区里 `add_card` 指向的牌不存在的也打印 `NOTE: dangling <id>`。W1/W2 关口由 strict 校验（V36）把关，你在 PR 里贴报告并清零。
- **W2**：K14 真引擎第 1–3 天走查里开局 `gd.m.wheel → gd.m.incense` 靠 `wh.month`；G05 的签准确性测试跑你的签。**截图**：数据任务不交截图（轮盘面板截图归 C06）。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K10.txt`：

```
# K10 轮盘、签、测字、黄历（docs/handoff_cards/K10_data-fortune.md）
K10_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/fortune/**,data/cards/tags/K10.json,data/cards/ui_keys/K10.json --name=K10_validate
K10_data|res://scripts/tests/cards/K10/test_data.gd|120|
K10_guide_support|res://scripts/tests/cards/K10/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K10_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：4 个轮盘；本月运势每年 6–8 段（每年 ≥ 1 好、≥ 1 坏）；大轮盘每年三类各 ≥ 2 段（含通用段）；庙会 6 段、赌摊 6 段（每个年代可用的段 ≥ 3，V18）；签 ≥ 30（五个等第 × ≥ 6 家族 + 每等第一支泛泛）；字 12–16；黄历 ≥ 24、每季 ≥ 6。
- [ ] 每张：`_provenance.task == "K10"`、brief 非空；扇区 `arc > 0`、`valence` 合法、`month_mods` 只出现在 `wh.month` 的段上；黄历动作都在枚举里、`reward` 里没有让钱减少或档位变坏的效果。
- [ ] 原因键 `k10.` 开头且已登记；字的 id 只有 ASCII。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`（不写签诗）。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K10 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K10] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K10] 四个轮盘与 1938 扇区`（先合：开局轮盘指引在等）；②`[K10] 签、测字、黄历`；③`[K10] 1939、1940 扇区与大赌引用`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表；1938 本月运势的加宽计算（U = 0 / max 时各段角度）；大赌引用表（扇区 → 大赌）；征兆家族覆盖表（签 × 等第、字 × 家族）；新文件名；需要主创/编排决定的事（加宽多少、本心阈值、押牌输了怎么算都是【待调】）；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 签/字只用 `omen_*`、每等第有泛泛签；3. 加宽单调、开局看得出变宽；4. 大赌全部被扇区引用；5. 黄历只奖不罚、春冬覆盖、第 4 天起能照做；6. 免 AI 声明（brief 不是签诗、字 id 不用汉字）；7. 视图不会因你的数据泄露好坏（`valence` 只在数据里）。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量（轮盘 / 各类扇区 / 签 / 字 / 黄历） | |
| 1938 本月运势加宽计算 | |
| 大赌引用表 | |
| 新文件、新 id、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
