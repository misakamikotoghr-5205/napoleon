# K11 `data-items-mg` · 物品 → 小游戏参数、首发物品表、新物品模板、电码本骨架

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K11 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K11: …` issue。

> **鉴定改版（主创 10-25：“你那个鉴定不能只是点点点，要玩家看出来才算数”）**：本卡下文凡和合同 §3.3、§4.8、§8、附录 H 对不上的，以合同为准。规格新字段（§4.7.15）：银元 `pitch_cents_good` `stack` `well_made_permille` `worn_permille`；称分量 `small_fen` `weight_box`（套子在 `economy.json`）；拼碎片 `seal_offset_px_good/_bad` `ink_mismatch_bad` `stain_permille` `rotate`（1/0）；电码本扉页 `crib`、5127 改作主线“动身与否”的槽。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 11**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default（V22 物品：模板存在、小游戏 kind 已知、参数形状；`templates_extra.json` 文字字段必须为空）、`_schema/item.json`、例子集 `data/cards/_examples/{minigames/items.json,minigames/codebook.json,items/templates_extra.json}` | W0（已完成） |
| G04 | 按你的规格把物品真值换成**物理参数**（§8.2），挑小游戏（`c.mg.pick`）；`launch_items.json` 的读法（合同没定格式，见下） | W1（并行，issue 里对） |
| C12–C15 | 各小游戏要的参数（§8.2 表）；找不同只给布局，布局来自 `data/town/item_templates.json` 的 `appraise.sprites` | W1（并行） |
| K08 | 主线电报要译的意思（你补电码本的码） | W1（并行） |
| K12 | 新模板的物品图占位 `item.<cat>.<variant>` | W1（并行） |
| K16 | 第 1 天教学客人当的东西要能出找不同 | W1（K16 引用你） |

- **波次**：W1。**W1 完成条件之一**：K11 合入（1938 数据 strict 全绿）。
- **W2**：G04 用你的全部物品跑“参数禁用键”检查与三关浸泡；C12–C15 对真参数联调；K13 审读史实依据（按 K13 的 `[K13→K11]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6））。

## 分支

`cards/K11-data-items-mg`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

给首发约 40 件物品定好：哪些模板（现有 28 个变体 + 新增）、每个模板能出哪些鉴定小游戏、物理参数的范围（引擎据此算出给小游戏的物理量——**小游戏只拿物理量，永远不拿真假**，红线 5）；新物品模板（银元几种、银器、金条、文书类……）的骨架（文字字段全空）；解密小游戏的电码本骨架（四位码 → 词的键 + brief，词由 A 写）。

## 必读

1. 合同 §0（红线 1、5）、§2.2、§2.3（`data/codebook.json` 只借码的形状）、§3.4 开头与 K11、§4.1、§4.2（`it.<cat>.<variant>`）、**§4.7.15**（item：`template` `minigames` 各 kind 的参数规格；`templates_extra.json` 同现有模板格式但文字字段全空）、**§4.7.23**（电码本骨架）、§4.8（物品图 id `item.<cat>.<variant>` 64×64）、§4.9（V22、V33）、**§8 全章**（小游戏接口：参数只有物理量；§8.2 每种小游戏的参数与**禁用键** `fake real genuine authentic forged stolen origin market value true_value floor tell benign fake_text real_text est verdict rare grade quality`）、§11.3（旧物品文字是 AI 写的，发行版走 `items.text.json`）、§7.10.10、§11.2。
2. `docs/cards/DESIGN_cards.md` §三.2（鉴定小游戏）、§七（物品约 40 件）、附录（**吹银元：指尖捏住中心猛吹边缘、贴耳听，真币余音细长；银元按枚计价一般不称；金饰、碎银、药材用戥子称**；1935 年法币改革后银元依法不得流通但民间私藏）。
3. `data/town/item_templates.json`（只读：7 类 28 个变体、字段集合、`appraise.sprites`——找不同的部位布局按图片路径或 `proc:<variant>` 索引）；`scripts/sim/item_gen.gd`（只读：模板怎么被用）；`data/codebook.json`（只读：码的形状，**词是 AI 写的，一个也不许拷**）。
4. 例子集：`data/cards/_examples/minigames/items.json`（`it.jewelry.hairpin` 称分量 + 找不同、`it.silver.yuan_a` 吹银元）、`data/cards/_examples/items/templates_extra.json`、`data/cards/_examples/minigames/codebook.json`。
5. W0 校验器 `scripts/cards/core/card_validator.gd` 的 `_check_templates_extra`（`templates_extra.json` 的文字字段只许空串，`id`、`sprite` 除外）与模板合并方式（**`templates_extra.json` 的类别不会覆盖、也不会追加进 `item_templates.json` 已有的同名类别**——新变体必须放在新类别里）。

## 要做的事

### A. `data/cards/items/templates_extra.json`（新模板）
- [ ] 新类别（**不要用现有 7 类的名字**：`rice clothing jewelry utensils art medicine documents`，同名会被忽略）：例 `silver`（银元几种 `yuan_a` `yuan_b` …、碎银）、`silverware`（银器）、`goldbar`（金条）、`papers`（当票、契据之外的文书）……；每个类别和变体的**字段集合与 `data/town/item_templates.json` 的条目完全一样**（`label` `weight` `scale` `can_fake` `material_label` … 与变体的 `name` `weight` `base_price` `material` `good_text` `worn_text` `fake_text` `real_text` `sprite` `tags` …），**所有文字字段写空串**（名字、质地、成色描述等正文在 `data/cards/text/items.text.json`，A 写）；`sprite` 写 K12 的占位路径 `art/_placeholder/cards/items/<cat>.<variant>.png`（开发版用；界面一律经 `CardArt` 的 `item.<cat>.<variant>`）。
- [ ] `_meta`：`{"owner": "K11", "schema": 1, "brief": "…", "_provenance": {…}}`；每个新类别的史实依据（年份、来源）写在文件顶层的 `_doc` 数组里——**类别和变体里面不要加多余的键**（校验器把类别里非空的字符串都当成正文报 V05，ItemGen 也会读类别的字段）。
- [ ] 把新的 `item.<cat>.<variant>` 美术 id 列给 K12（PR 里列 + 评论）。

### B. `data/cards/items/launch_items.json`（首发物品表，约 40 件）
- [ ] **合同只说了文件名和用途，没给格式**——按下面的起步格式写，并在 PR 里列为“新格式，等 G04 确认”（开 `[shared] K11→G04` issue）：
  ```json
  {"_meta": {"owner": "K11", "schema": 1, "brief": "首发三关会出现的物品"},
   "items": [{"template": "jewelry.hairpin", "eras": ["1938", "1939", "1940"], "weight": 10, "brief": "…"}]}
  ```
  现有 28 个变体全部列入（不想用的 `weight: 0` 并在 brief 写理由）+ 新增的。

### C. `data/cards/minigames/items.json`（物品 → 小游戏参数，牌文件，`it.*`）
- [ ] 首发每个模板一张 `it.<cat>.<variant>`：`type: "item"`、`era: ["*"]`、`weight: 0`、`template`、`minigames`（§8.1 的 kind：`spot` `coin_ring` `weigh` `fragments`；`decode` 只给消息牌用，不放物品上）、各 kind 的规格（照 §4.7.15）：
  - `weigh`：`tool`（`dengzi` 戥子 / `steelyard` 秤）、`claimed_fen`（客人说的分量，整数“分”，1 钱 = 10 分）、`dev_bad_pct`、`dev_worn_pct`——**金饰、碎银、药材用戥子称**。
  - `coin_ring`：`ring_ms_good` `ring_ms_bad` `buzz_good` `buzz_bad` `pitch_cents_bad`——**银元吹，不称**。
  - `spot`：`{}`（布局由 G04 从模板图的部位表生成）——**只给 `data/town/item_templates.json` 的 `appraise.sprites` 里有布局的模板**（那张图的路径或 `proc:<variant>` 在表里）；新类别没有布局，不给 `spot`。
  - `fragments`：字画、文书类（裂开的字画、撕破的契据）：`doc`、`pieces` 区间、`seal_offset_px` 区间等（§8.2 的 `fragments` 一行）。
  - 规格里的 `*_bad`、`dev_bad_pct` 这类**只有引擎读**（用来算物理量），小游戏拿不到；键名里**不用** §8.2 的禁用词（`fake` `real` `genuine` …）。
- [ ] 整数：区间写 `[lo, hi]`，单值写整数（V07、V22）。
- [ ] brief 写史实依据（怎么验、为什么）；`_provenance: {"by": "ai", "task": "K11", "date": "<提交当天>"}`。

### D. `data/cards/minigames/codebook.json`（电码本骨架）
- [ ] 照 §4.7.23：`{"_meta": {"owner": "K11", "schema": 1, "brief": "…"}, "codes": {"0417": {"key": "cb.word.0417", "brief": "…"}}}`；四位数字码（形状借旧 `data/codebook.json`，**词一个也不拷**）；`key` = `cb.word.<码>`；brief 只写“这个码表示哪类意思”（例“一个常用的地名用字”），词由 A 写在 `data/cards/text/codebook.text.json`。
- [ ] 数量：覆盖 K08 列出的主线电报要译的全部意思 + 足够的干扰码（≥ 60 个【待调】）。

### E. 标签、界面键
- [ ] `data/cards/tags/K11.json`（如有）；`data/cards/ui_keys/K11.json`（如有，`k11.*`）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**合同 1.3 不影响本任务**：物品在柜台上用 `item.*` ×2 摆出来，规格不变；小游戏仍由 C01 的宿主开在叠层之上，入口是柜台那一出里的“细看”回话或柜台上的放大镜（都发 `mg.request`）——你的参数、物品表、模板、电码本一样不用改。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/minigames/items.json`、`data/cards/minigames/codebook.json`、`data/cards/items/**`
- 默认拥有：`scripts/tests/cards/K11/**`、`scripts/tests/cards/suites/K11.txt`、`data/cards/tags/K11.json`、`data/cards/ui_keys/K11.json`

## 不能做的事

1. **不写玩家最终内容**：物品名、质地、成色、真/假描述、电码本的词全由 A 写；`templates_extra.json` 的文字字段只许空串；brief 以外不出现中文。
2. **鉴定只给观察（红线 5）**：参数规格里不出现真假结论；`spot` 不写 `tell`/`benign`；不改小游戏的观察键目录（`data/cards/minigames/obs/*.json` 归 C12–C15）。
3. 不改 `data/town/item_templates.json`、`data/codebook.json`、`scripts/sim/item_gen.gd`、`scripts/core/appraise.gd`（只读）；不改 `data/cards/rules/items_balance.json`（G04）。
4. 不发明小游戏 kind（`seal` `sniff` 是预留，首发不用）；不发明字段（新格式只有 `launch_items.json`，已在上面说明）。
5. 史实措辞与依据（银元按枚计价、吹听余音；法币改革后银元不得流通但民间私藏）；不拷旧版 AI 文字。

## 接口

**用到**：§4.7.15、§4.7.23、§8.2；`data/town/item_templates.json` 的模板与 `appraise.sprites`（只读）。

**提供**：`it.*`（G04 的 `CardAppraisal` 挑小游戏、算物理参数；C12–C15 收参数）；新模板（G04 的 `CardItems`、K12 出物品图占位、A 在 `items.text.json` 写物品文字）；`launch_items.json`（G04，格式待确认）；电码本骨架（C15 的解密、A 写词）。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪份数据让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `mg.spot`（G04） | 能出 `spot` 的模板（第 1 天教学客人固定出找不同，物品用这种模板） | `gd.d1.spot`（brother · `a.mg.spot.atlas` 备 `a.mg.spot.main`） |
| `mg.coin_ring`（G04） | 银元类 `coin_ring` | `gd.mg.coin_ring`（obj.brother_ledger · `a.mg.coin_ring.blow`） |
| `mg.weigh`（G04） | 金饰、碎银、药材 `weigh` | `gd.mg.weigh`（obj.brother_ledger · `a.mg.weigh.weights`） |
| `mg.fragments`（G04） | 字画、文书 `fragments`（主线当票 `tk.1938.de196` 在 K01，用 `documents.receipt`） | `gd.mg.fragments`（obj.brother_ledger · `a.mg.fragments.board`） |
| `mg.decode`（G04） | 电码本（主线电报在 K08） | `gd.mg.decode`（postman · `a.mg.decode.book`） |

- **教学要求（合同 §3.4 K11 确认）**：至少一个能出 `spot` 的模板给 K16 第 1 天的来当客人用（建议 `jewelry.hairpin`——W0 的 `day_counter` 夹具已经用真 ItemGen 生成过它的找不同布局）；第 1–3 天的教学客人带的东西都固定出找不同（K16 写 `minigame: "spot"`），所以这些模板的 `it.*` 必须含 `spot`。
- **指引验收（必须有测试）** `scripts/tests/cards/K11/test_guide_support.gd`：
  1. `it.jewelry.hairpin` 存在且 `minigames` 含 `spot`；`documents.receipt` 模板存在（`tk.1938.de196` 的 `item_template`）。
  2. 五种首发小游戏里 `spot` `coin_ring` `weigh` `fragments` 各至少被 2 个首发模板用到（每个机制都有机会第一次出现）。
  3. 所有含 `spot` 的 `it.*`，其模板的图（`sprite`，空串时用 `proc:<variant>`）在 `item_templates.json` 的 `appraise.sprites` 里。
  4. 电码本里每个码 4 位数字、`key == "cb.word.<码>"`、brief 非空。
- **W2**：K14 真引擎第 1 天走查里 `gd.d1.look → gd.d1.spot` 靠 hairpin 的找不同；C12–C15 用你的参数联调。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K11.txt`：

```
# K11 物品 → 小游戏参数、首发物品表、新模板、电码本（docs/handoff_cards/K11_data-items-mg.md）
K11_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/minigames/items.json,data/cards/minigames/codebook.json,data/cards/items/**,data/cards/tags/K11.json,data/cards/ui_keys/K11.json --name=K11_validate
K11_data|res://scripts/tests/cards/K11/test_data.gd|120|
K11_guide_support|res://scripts/tests/cards/K11/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K11_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：`launch_items.json` ≈ 40（≥ 36）件、现有 28 个变体全部列入；每个列入且 `weight > 0` 的模板都有 `it.*`；每个 `it.*` 至少一种小游戏。
- [ ] 每个 `it.*` 的模板存在（`item_templates.json` ∪ `templates_extra.json`）；参数键名不含禁用词；区间 `lo ≤ hi`、全是整数。
- [ ] `templates_extra.json`：类别名不和现有 7 类重名；字段集合和现有模板一致；文字字段全是空串（`id`、`sprite` 除外）。
- [ ] 每张：`_provenance.task == "K11"`、brief 非空。
- [ ] 打印新物品图 id 清单 `NOTE: art_for_k12 item.<cat>.<variant>`（不算失败）。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K11 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K11] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K11] 现有 28 个模板的小游戏参数与首发物品表`（先合：G04、C12、K16 在等）；②`[K11] 新物品模板（银元、银器、金条、文书）`；③`[K11] 电码本骨架`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；物品 × 小游戏的对照表；新模板清单（给 K12 的美术 id）；`launch_items.json` 的格式与 G04 的确认情况；史实依据；需要主创/编排决定的事；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 参数只有规格、没有真假、键名无禁用词；3. `spot` 只给有布局的模板；4. 新模板文字全空、类别不重名；5. 电码本没有一个词；6. 史实（银元吹不称、戥子称金饰药材）；7. 教学用的 hairpin 能出找不同。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 物品 × 小游戏对照表 | |
| 新模板与美术 id（给 K12） | |
| `launch_items.json` 格式与确认 | |
| 电码本码数 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
