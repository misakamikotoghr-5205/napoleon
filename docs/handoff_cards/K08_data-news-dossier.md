# K08 `data-news-dossier` · 消息牌、档案簿页与碎片

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K08 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K08: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 8**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default、`_schema/{news,dossier_page,dossier_fragment}.json`、例子集 `data/cards/_examples/{news/news.json,dossier/dossier.json}` | W0（已完成） |
| K01、K03、K05 | 人物牌、金色牌在效果里引用的碎片 id（`dossier` 补、`dossier_gap` 留缺口）——**你要把它们全部定义出来**；新面孔、过路客的 `persons` 块（`dossier: true` 的要有页） | W1（并行；你收集他们 PR 里的“悬空引用”清单） |
| K02/K04/K06、K07、K09 | 事件、条子、夜牌效果里引用的碎片 / 消息（`nw.any.family_word` 由 K09 的回家吃饭发） | W1（并行） |
| K11 | 电报解密用的电码本骨架 `codebook.json`（码 → 词的键）；你写哪些电报要用哪些码，K11 补码 | W1（并行） |
| K16 | 第 6 天周妈的教学消息 `nw.1938.tut_zhouma` 的 `on_read` 补 `df.zhouma.1938.tut_news`——**这块碎片你定义、放进 `dp.zhouma`** | W1（K16 引用你） |

- **波次**：W1。1938 的档案碎片是 **W1 完成条件“1938 数据 strict 全绿、悬空引用为 0”** 的关键——K01/K02 的金色牌、事件都引用碎片。
- **W2**：跨年“一年后”碎片在真引擎里跑通；按 K13 的 `[K13→K08]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6）。

## 分支

`cards/K08-data-news-dossier`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写消息牌（行情、线索、流言、信、报纸、电报，约 40 张，三年）和档案簿（碎片化叙事）：每个人物一页 `dp.<人物>`，每个主要人物 ≥ 5 块碎片 `df.*`（来源：当了什么、说了什么、别人提起、剪报、当票上的字、信），跨年的“一年后”碎片，补齐一页的奖励，哪些碎片会因为交人/金色牌没理而成缺口；系统牌 `nw.any.family_word`。只写**机制 + brief**；碎片正文、消息正文全由 A 写。

## 必读

1. 合同 §0、§2.2、§2.5、§3.4 开头与 K08、§3.5（人物、新面孔、过路客、系统牌表 `nw.any.family_word`）、§4.1–§4.4、**§4.7.8**（news：`kind` `source` `info_about` `minigame`（只有 `telegram` / `letter` 能带 `decode` / `fragments`）`on_read` `on_inform`）、**§4.7.19**（dossier_page / dossier_fragment：`fragments` 顺序、`order`、`kind`、`year_after_of`、`on_complete`）、§4.9（V16、V21、V33、V34）、§5.2（`dossier` `dossier_gap` `contact_gain` `person_state`）、§7.5（DossierView：还没拿到的碎片不出现，缺口出现）、§10（金色牌没理 → 缺口）、§7.10.10、§11.2、**§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §二、§三.11（档案簿：碎片化叙事）、§四（跳一年：档案簿补“一年后”）、§五（三年主线）、§九.4（第 4–7 天：消息牌与档案簿碎片由周妈教）。
3. `docs/town/cards/src/era.json` 的 `notes`、`launch`、`pawn[0..2]`。
4. 例子集：`data/cards/_examples/news/news.json`、`data/cards/_examples/dossier/dossier.json`（林嫂一页、哥哥一页、王山一页）。
5. 只读剧情事实：`data/cast.json`（`edges`）、`data/story/**`、`data/pages.json`（旧档案页结构，文字是 AI 写的不许拷）。

## 要做的事

### A. 档案簿（`data/cards/dossier/` 下，建议按人分文件或按年分文件，例 `pages.json` + `fragments_1938.json` …）
- [ ] 每个人物一页 `dp.<人物>`（`type: "dossier_page"`、`person`、`era: ["*"]`、`weight: 0`、`fragments`（按 `order` 排的碎片 id 列表）、`effects.on_complete`（补齐的奖励：多半是 `contact_gain`，或设旗标给结局用）、`brief`、`_provenance`）：16 个主要人物 + 新面孔（`nf1938a`–`nf1940d`，`dossier: true` 的）+ 有页的过路客。
- [ ] 碎片 `df.<人物>.<年>.<slug>`（`type: "dossier_fragment"`、`person`、`era`、`weight: 0`、`order`（同页不重复）、`kind`：`pawn` `said` `heard` `clipping` `ticket` `letter` `year_after`）：每个主要人物 ≥ 5 块。
- [ ] **“一年后”碎片**：`kind: "year_after"`、`year_after_of: <更早一年的那块>`（1938→1939、1939→1940）；brief 写清“只有拿到了前一年那块才会补这一块”。
- [ ] **会成缺口的碎片**：在 brief 里写明“哪张牌的哪个结果会让它变缺口”（金色牌没理、把消息交给条子 `on_inform`……），并在 PR 里列一张“碎片 → 补它的牌 / 让它成缺口的牌”的对照表。
- [ ] **收集所有引用**：K01/K02/K03/K04/K05/K06/K07/K09/K16 的数据里出现的每个 `df.*`（`dossier` / `dossier_gap` / `year_after_of`）都要在你这里有定义；`dp.*` 也一样。合入前在本地 grep 一遍全部真数据（`test_data.gd` 也打印没覆盖的）。
- [ ] **教学用（合同 §3.4 K08 确认）**：`dp.zhouma` 里有一块 `df.zhouma.1938.tut_news`（`kind: "heard"` 或 `said`、`era: ["1938"]`），这是 K16 第 6 天的教学消息 `nw.1938.tut_zhouma` 的 `on_read` 补的那块（**这个 id 是 K08/K16 两张任务卡约定的，§3.5 没列，PR 里列为新 id**）。周妈这一页补齐后建议的奖励是 `contact_gain zhouma`（和 K16 第 7 天的教学牌不冲突：人脉已在就不重复给，由 G03 处理）。
- [ ] 哥哥一页 `dp.brother` 至少包含 K01 金色牌用的 `df.brother.1938.farewell`（听完交代得到 / 没理就是缺口）和 `df.brother.1938.farewell_cold`（争吵那条路）。

### B. 消息牌（`data/cards/news/` 下，建议按年分文件）
- [ ] 约 40 张 `nw.<年>.<slug>`（三年各约 13）：`kind` 六种都有（`price` 行情、`lead` 线索、`rumor` 流言、`letter` 信、`paper` 报纸、`telegram` 电报）、`source`（谁说的，人物 id 可空）、`info_about`（关于谁；能交给“要消息”的条子）、`keepable: true` + `expires_days`（留着几天）、`must_resolve: false`、`effects.on_read`（多半是 `dossier` 补碎片）、`effects.on_inform`（交给条子：伤到那个人——`dossier_gap`、`person_state`、`conscience`）、至少一个 `omen_*`、`art: "illus.nw.<kind>"` 或 `illus.<id>`。
- [ ] **电报解密**：至少一张主线电报 `kind: "telegram"`、`minigame: "decode"`（V33 允许），brief 写清要译出的是哪几个意思；把需要的码和词的意思交给 K11 的电码本（PR 里列）。可以有一封信 `kind: "letter"`、`minigame: "fragments"`（撕破的信拼回来）。
- [ ] 系统牌 `nw.any.family_word`（`era: ["*"]`、`weight: 0`、`kind: "rumor"` 或 `letter`、`source` 家里人；K09 的夜牌“回家吃饭”选“明天得到一张家人的消息”发它）。
- [ ] 原因键、告示键 `k08.*`（在 `ui_keys/K08.json`）。

### C. 标签、界面键
- [ ] `data/cards/tags/K08.json`、`data/cards/ui_keys/K08.json`。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] 消息牌（`must_resolve: false`、`keepable: true`）打烊时没看也没留：**留在手上**，从发到手上那天起按 `expires_days` 倒计时，到期就过去了（`on_read` 不执行，那块碎片没拿到；`on_expire` 可选）。所以 `expires_days` 要给得合理（流言几天、信和电报长一些），brief 里写明“没看会错过什么”。
- [ ] 电报、信（带 `minigame` 的）同上。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

数据卡共用的写法：

- 演出块的格式、站位、道具位、效果、拍子见合同 §4.7.24；默认演法见 §7.11.4——**默认够用的牌不写**。
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K08] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K08→K12`。
- 校验：default 模式没有 V38 V40 V41 和 V39 本地部分的错；W2 起 strict 全绿。
- 史实：伪军、伪维持会的人在 brief 里照 era.json 的措辞（加“伪”字）。

写法要点（合同 §4.7.24、§4.9 V38–V42 的摘要；落笔前对一遍）：

- 键只有 `set cast props fx walk intro after brief`；`cast` ≤ 3 个、每个只有 `who at look brief`；`props` ≤ 4 个、每个只有 `art at brief`（`art` 合 `^prop\.[a-z0-9_]+$`）；`fx` ≤ 3 个、不重复；`intro` ≤ 12 拍、`after` 每组 ≤ 8 拍，每拍只有 `who ref brief`。
- 能用的值（W0 冻结的 `CardIds` 常量）：`set` ∈ `counter` `candle` `street` `prison` `temple` `dock` `market` `teahouse` `ricehall` `pharmacy` `post` `baogong`（`STAGE_SETS`）；站位 `at` ∈ `customer`（柜台前）`companion`（柜台一侧）`door` `door_l` `door_r`（门口）`street`（门外街上走过）（`STAGE_SPOTS`）；`look` ∈ `stand` `walk` `shadow`（`CAST_LOOKS`）；道具位 ∈ `counter_left` `counter_mid` `counter_right` `door_side` `door_notice` `wall_right`（`PROP_SPOTS`）；`fx` ⊂ `rain` `fire` `smoke` `predawn` `dim` `cold` `warm` `drip` `shake` `seal`（`STAGE_FX`）；`walk` ∈ `crowd` `patrol` `troops` `refugees` `hu2_men` `none`（`STAGE_WALKS`）。
- 站位规则（V38、V41）：同一个站位只站一个人；`door` 不和 `door_l` / `door_r` 同时用；`look: walk` 只配 `at: street`，`at: street` 只配 `look: walk` 或 `shadow`；`set` 不是 `counter` 时不许用 `street` 站位、也不许写 `walk`。
- `ref` 只许 `body`、`lines.<名>`、`outcomes.<名>`、`choices.<id>`；演出块里不许出现 `text` `title` `body` `label` `name` `lines` `desc` 这些**键名**（V04），写在 `ref` 的**值**里可以。
- `after` 的键：`accept` `counter` `leave` `refused` `impatient` `look` `success` `fail` `read` `keep` `delay` `lot` `cezi` `pass` `done`（`STAGE_AFTER_KEYS`）或这张牌自己的选项 id；选了一句回话，对话框先把那句话以“你说的”显示出来，再接 `after.<键>`（第一拍就是 `who: "me"` 时不重复）。`after` 的键会原样进 CardView（G02 只去掉 `brief`），所以选项 id 别和合同 §7.5 的隐藏键黑名单（`CardViewModel.FORBIDDEN_KEYS`：`floor` `market` `value` `tell` `risk` `tags` …）重名。
- `cast`、`props` 每一项也写一句 `brief`（K13 审读、K15 出包时剥掉）。

本任务：

- [ ] **`kind` 为 `telegram` 的消息牌写演出块**：何启明送电报——`cast: [{"who": "postman", "at": "customer", "brief": …}]`、`props: [{"art": "prop.telegraph_open", "at": "counter_mid", "brief": …}]`。
- [ ] **`kind` 为 `letter` 的消息牌写演出块**：何启明送信——`cast: [{"who": "postman", "at": "customer", "brief": …}]`、`props: [{"art": "prop.letter", "at": "counter_mid", "brief": …}]`（`prop.letter` 24×32 由 K12 生成，表在合同 §4.8“画面用的美术”）。
- [ ] 这两种都**自己写 `intro`**（例两拍：`{"who": "postman", "ref": "lines.greet", "brief": "何启明说有一封电报 / 信"}`、`{"who": "", "ref": "body", "brief": "旁白：电报 / 信上说的事"}`）：消息牌默认演法的说话人是 `source`（谁说的），你把 `cast` 换成何启明以后，不写 `intro` 就会让不在场的 `source` 开口；消息牌没有 `person`，拍子的 `who` 只能是 `""`、`"me"` 或 `postman`（V39）。
- [ ] 别的种类：有 `source` 的默认够用（`source` 那个人走进门站到柜台前说）；没有 `source` 的默认是报童 `ex_newsboy` 站门口——都不用写。
- [ ] 档案页、碎片不受影响（`dossier_page` `dossier_fragment` 不能带演出块，V40）；`nw.any.family_word` 用默认演法。
- **数量**：每张 `telegram`、`letter` 消息牌都写；其余不写。

**新增 / 作废的交付**

- 新增一个 PR `[K08] 演出块`：只动 `data/cards/news/**`，G01 的 1.3 小 PR 合入后再提。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件。上文“新手指引”表里 `gd.dossier` 的锚点已按合同 §7.10.5 的改名表改成 1.3 的名字（`a.right.dossier` → `a.scene.notebook`，柜台上的档案簿；备 `a.tab.dossier`），你的数据和测试不用为此改。
- 消息牌在画面里：打出一张消息牌 = 说消息的人进门开口（C03 的 `read` 那一出），回话是“看过了 / 留着”，带 `minigame` 的电报和信多一句“细看”（发 `mg.request`）。

**测试与截图**

- `K08_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- 演出块 PR 里 `test_data.gd` 加：每张 `kind` 为 `telegram` / `letter` 的消息牌都有 `stage`，`cast` 里有 `postman`、`props` 里有 `prop.telegraph_open` / `prop.letter`、`intro` 非空；演出块里每个 `brief` 也过 brief 自查。
- 截图：数据任务照旧不交。

**已经做了的哪些还有效**

- 全部有效（消息牌、档案页、碎片、一年后、引用收集）；演出块另开 PR。

**日期**：演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提；1938 的几张尽量跟 1938 的演出块一起 **10-27** 前合入，其余跟着各年的数据走。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/news/**`、`data/cards/dossier/**`
- 默认拥有：`scripts/tests/cards/K08/**`、`scripts/tests/cards/suites/K08.txt`、`data/cards/tags/K08.json`、`data/cards/ui_keys/K08.json`

## 不能做的事

1. **不写玩家最终内容**：碎片的 `body`、页的 `title`、消息的 `title` `body` 全由 A 写；brief 只写“这块讲什么事实、从哪来”，不写成能直接用的段落，不写引号里的对白；brief 以外不出现中文。
2. 不改别人的牌（引用你碎片的牌由它们的主人改）；不改 K11 的电码本、`_examples/**`、`data/pages.json` 等旧文件。
3. 不在非 `telegram` / `letter` 的消息上写 `minigame`（V33）；不发明字段、op、条件。
4. 史实措辞（伪字、年份写法；剪报类碎片写的时局事件要和 era.json 的年表一致）；不拷旧版 AI 文字。

## 接口

**用到**：§4.7.8、§4.7.19；§5.2 `dossier` `dossier_gap` `contact_gain` `person_state` `conscience` `flag`。

**提供**：所有 `dp.*` `df.*`（G03 的 CardDossier、C10 的档案簿、K01–K07/K09/K16 引用）；消息牌（G01 发牌、G03 的条子 `inform`、C03 的 `read` 面板——1.3 起是“说消息的人进门”那一出、C15 的解密）；`nw.any.family_word`（K09 夜牌）；`df.zhouma.1938.tut_news`（K16 教学）。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `news`（G01） | 第一张消息牌（教学是 K16 第 6 天周妈的消息；之后是你的随机消息） | `gd.news`（zhouma · `a.card@{uid}`；`stage_day_gte: 6`） |
| `dossier`（G03） | 第一块碎片（第 6 天周妈消息 `on_read` 补 `df.zhouma.1938.tut_news`） | `gd.dossier`（zhouma · `a.scene.notebook` 备 `a.tab.dossier`） |
| `dossier_gap`（G03） | 第一次留缺口（金色牌没理、交消息） | `gd.dossier_gap`（obj.brother_ledger · `a.dossier.gap`） |
| `year_after`（G03） | 第一块“一年后”碎片（第一次跳一年） | `gd.year_after`（obj.brother_ledger · `a.year.after` 备 `a.dossier.page`） |
| `mg.decode`（G04） | 主线电报 `minigame: "decode"` | `gd.mg.decode`（postman · `a.mg.decode.book`） |
| `mg.fragments`（G04） | 撕破的信 `minigame: "fragments"`（主线当票在 K01） | `gd.mg.fragments` |

- **指引验收（必须有测试）** `scripts/tests/cards/K08/test_guide_support.gd`：
  1. `dp.zhouma` 存在，`fragments` 含 `df.zhouma.1938.tut_news`，那块碎片存在、`era` 含 `1938`。
  2. `dp.brother` 含 `df.brother.1938.farewell` 和 `df.brother.1938.farewell_cold`。
  3. 至少一张 `kind: "telegram"`、`minigame: "decode"` 的消息；`nw.any.family_word` 存在且 `weight == 0`。
  4. 每块 `year_after` 碎片的 `year_after_of` 存在、年代更早，且两块在同一页（V21）；1938→1939、1939→1940 各 ≥ 4 块。
- **W2**：K14 三关走查（第 6 天 `gd.news → gd.dossier`、跳年后 `gd.year_after`）。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K08.txt`：

```
# K08 消息牌、档案簿（docs/handoff_cards/K08_data-news-dossier.md）
K08_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/news/**,data/cards/dossier/**,data/cards/tags/K08.json,data/cards/ui_keys/K08.json --name=K08_validate
K08_data|res://scripts/tests/cards/K08/test_data.gd|120|
K08_guide_support|res://scripts/tests/cards/K08/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K08_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：消息 ≥ 36（约 40），六种 `kind` 都有；16 个主要人物每人一页、每页 ≥ 5 块；新面孔中 `dossier: true` 的都有页。
- [ ] 每页：`fragments` 里的 id 都存在、`person` 一致、同页 `order` 不重复（V21）；每块碎片恰好属于一页。
- [ ] 每张消息：`_provenance.task == "K08"`、brief 非空、至少一个 `omen_*`、`minigame` 只在 `telegram`/`letter` 上；`info_about` 是登记过的人物。
- [ ] **引用覆盖报告**：扫描全部真数据里的 `df.*` / `dp.*` 引用，没有定义的打印 `NOTE: dangling <id> (referenced by <牌 id>)`——**永远只打印、不断言**（别的线合入新引用时不能让所有人的 CI 变红）；W1 完成前要清零，由 Claude 在波次关口用 strict 校验（V11）把关，你在 PR 里贴当时的报告。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；伪政权名前有“伪”。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K08 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K08] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K08] 1938 档案页与碎片（含哥哥、周妈教学碎片）`（先合，W1 完成条件）；②`[K08] 1938 消息牌与 nw.any.family_word`；③`[K08] 1939、1940 消息与“一年后”碎片`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表（每人几块、每种来源几块、每年几张消息）；“碎片 → 补它的牌 / 成缺口的牌”对照表；给 K11 的电码需求；新 id（含 `df.zhouma.1938.tut_news`）；引用覆盖报告；需要主创/编排决定的事；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 引用覆盖：别的线引用的碎片都有定义；3. 一年后碎片的链、缺口的来源清楚；4. 教学碎片在周妈一页；5. 免 AI 声明（碎片 brief 不是段落正文）；6. 剪报类的史实；7. 抽 5 块碎片读 brief。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量（页 / 碎片 / 一年后 / 消息分类） | |
| 碎片对照表 | |
| 给 K11 的电码需求 | |
| 新加的 id、标签、界面键 | |
| 引用覆盖（还悬空的） | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
