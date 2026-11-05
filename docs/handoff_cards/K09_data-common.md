# K09 `data-common` · 留着的牌、人脉、家当、夜牌、街头、牢房、你自己、群演

> 本卡是 `docs/cards/CARDS_INTERFACES.md`（下称“合同”）§3.4 K09 的展开。**优先级：主创原话 > 合同 > 本卡**。对不上以合同为准，开 `[api] K09: …` issue。

## 执行者与线号

- 执行者：**Grok**
- 线号：**Grok 线 9**

## 依赖

| 依赖 | 什么 | Wave |
|---|---|---|
| W0（提交 `b87a641`） | 校验器 default、`_schema/{kept,contact,estate,night,street,prison,self}.json`、例子集 `data/cards/_examples/common/*.json`（`kp.ma_owes` `kp.mystery_box` `kp.liangmin` `kp.brother_note` `ct.ma` 五件家当、三张夜牌、`st.write_letters`、`pr.cell`、`self.ruhua`） | W0（已完成） |
| G03 / G06 | 留牌进格子的加成与风险（G03 `CardKeptRules`）、人脉被动/坏处/离开、家当押出后的修正项与钱不够阶梯、街头、牢房（G06）——规则在引擎里，你写数据 | W1（并行；以合同为准） |
| K08 | `nw.any.family_word`（回家吃饭发的家人消息） | W1（并行） |
| K10 | 留着的牌的 `incense_units`（香案份数）、人脉 `contact_attr`（香案按哪项属性算） | W1（并行） |
| K12 | 插图与头像占位 | W1（并行） |

- **波次**：W1。**W1 完成条件之一**：K09 合入（1938 数据 strict 全绿）。
- **W2**：G06 平衡报告（抵押、街头、牢房比例）出来后修数；按 K13 的 `[K13→K09]` 审读 issue 在你自己的分支修（K13 不改你的文件，合同 §2.6）。

## 分支

`cards/K09-data-common`，从 `claude/festive-ride-vud32a` 的 W0 合入点（提交 `b87a641`）切；用 `git rebase origin/claude/festive-ride-vud32a` 跟上。

## 目标

写跨年代通用的“手边的东西”：留着的牌约 15、人脉约 11、家当 5、夜牌 6、街头牌约 12、牢房牌 1–2、你自己 `self.ruhua`；1.3 起另加演出里的九个群演（`common/extras.json`，见下方“10-13 变更二”）。只写**机制 + brief**。不做“哥哥的账簿批注”留牌（它会占一个留牌位；账簿只作新手指引里“教的人” `obj.brother_ledger`）。

## 必读

1. 合同 §0、§2.2、§2.5、§3.4 开头与 K09、§3.5（`kp.*` `ct.*` `es.*` `nt.*` `st.*` `pr.cell` `self.ruhua` 的预留 id；系统牌表 `pr.cell`）、§4.1–§4.4、§4.7.2（self）、§4.7.9（kept：`kind` `slot_bonus` `consumed_on_use` `risk` `incense_units` `expires_days`）、§4.7.10（contact：`attrs` `passives` `downsides` `mods` `leave_when` `year_changes`，钩子 `day_start` `deal` `demand_issue` `settle`）、§4.7.11（estate：`order` `mortgage_value` `interest_pct_month` `while_mortgaged` 修正项 `no_intake_cat` `shelf_cap` `deal_count` `pool_weight` `kept_cap` `lose_if_unredeemed`）、§4.7.12（night：带 `choices` 的回家吃饭）、§4.7.13（street）、§4.7.14（prison）、§4.9（V14、V15、V16、V36）、§5.2–§5.3、§7.4.2（留牌满了）、§7.4.6（街头时发什么）、§9.1（香案份数）、§7.10.10、§11.2、**§3.5 的“群演”一段、§4.7.24（演出块，1.3 新）**。
2. `docs/cards/DESIGN_cards.md` §一（夜牌三选一）、§三.5（留着的牌）、§三.7（抵押、流落街头）、§三.8（被抓、打点）、§三.10（人脉）、“实现时的理解”第 7、14、16 条。
3. 例子集 `data/cards/_examples/common/*.json`；`data/cast.json`（人脉对应的人物）。

## 要做的事

### A. `data/cards/common/self.json`
- [ ] `persons` 块登记 `ruhua`（`portrait.ruhua`、`dossier: false`、brief）；牌 `self.ruhua`（`attrs: {eye, tongue, pull, nerve}` 起步值【待调】，照 §4.7.2）。

### B. `data/cards/common/kept.json`（约 15）
- [ ] §3.5 预留：`kp.ma_owes`（人情）`kp.liangmin`（良民证，`kind: "paper"`、`expires_days: 0`、`slot_bonus: [{"slot_tags_any": ["papers"], "auto_pass": true}]`、`consumed_on_use: false`）`kp.sunfu_letter`（孙府介绍信）`kp.gold_bar`（金条，硬货）`kp.blank_ticket`（空白当票）`kp.brother_note`（哥哥的交代，主线信物）`kp.mystery_box`（来路不明的箱子，`risk: [{"op": "arrest", …}]`）`kp.leverage.<人物>`（把柄，几个人各一张）；其余补到约 15（信物 `token`、人情 `favor` …）。**不写 `kp.history_issue`**（解放后，K16 只做设计）。
- [ ] 每张：`kind`、`keepable: true`、`expires_days`（0 = 不失效）、`slot_bonus`（按格子的 `tags` 匹配：`heads` / `auto_pass` / `coins`）、`consumed_on_use`、可选 `risk`、`incense_units`（放上香案算几份，默认 1）、`weight: 0`（留牌只由效果发）、`tags`、`art: "illus.<id>"`、`brief`、`_provenance`。
- [ ] **教学用（合同 §3.4 K09 确认）**：`kp.brother_note`（第 2 天哥哥告别“听他交代完”给的）：`keepable: true`、`expires_days: 0`、`consumed_on_use: false`、`kind: "token"`；brief 写清它在主线里的用处（之后哪条主线的格子吃它的加成）。

### C. `data/cards/common/contacts.json`（约 11）
- [ ] §3.5 预留 `ct.zhouma` `ct.chen` `ct.ma` `ct.xiaoding` `ct.wangshan` `ct.li` `ct.linsao` `ct.zhang` `ct.wu` `ct.guanjia` `ct.postman`：`person`、`attrs`、`passives`（例：陈文庭“书画药材线索更清楚”用修正项 `appraise_pct`——写在 `mods` 里，和 G03 在 issue 里确认格式）、`downsides`、`leave_when`、`year_changes`、`weight: 0`、`tags`、`art: "portrait.<人物>"`、brief。
- [ ] **教学用**：`ct.zhouma`（第 7 天 K16 的教学牌 `contact_gain zhouma` 让她成人脉；第 6、7 天周妈教消息、档案、人脉、口碑风声）：被动要简单、看得见（例：每周一条消息），brief 写清。

### D. `data/cards/common/estates.json`（5）
- [ ] `es.jewel_cabinet`（首饰柜：押着不能收首饰 `no_intake_cat jewelry`）`es.storeroom`（库房：`shelf_cap -4`）`es.counter`（柜台：`deal_count person -1`）`es.old_house`（老宅：`pool_weight life pct 150`）`es.shopfront`（铺面：`lose_if_unredeemed: true`，押出去的那个月照开，月底赎不回 → 街头）；`order`（阶梯建议顺序）、`mortgage_value`（1938 年价）、`interest_pct_month`、`while_mortgaged`、`weight: 0`、`art`、brief。照 §4.7.11。

### E. `data/cards/common/night.json`（6）
- [ ] `nt.tidy` `nt.accounts` `nt.backdoor` `nt.telegraph`（`conditions` 含 `{"day_gte": 3}` 和 `{"flag": "telegraph_ok"}`）`nt.family_dinner`（两个选项：`waive_life` 抵掉一张生活牌的坏处、`family_word` 明天得到 `nw.any.family_word`，照 §4.7.12）`nt.early_sleep`（`extra_deal person 1 tomorrow`）；`conditions` 用 `{"mode": "shop"}`；`effects.on_choose`、`almanac`（黄历动作）、`art`、brief。
- [ ] **第 1 天晚上要有 3 张能选**（`deal.json.night_offer = 3`）：至少 3 张夜牌在第 1 天就满足条件（`gd.d1.night` 要在第 1 天晚上亮）。

### F. `data/cards/common/street.json`（约 12）、`data/cards/common/prison.json`（1–2）
- [ ] 街头牌 `st.beg` `st.odd_job` `st.stall` `st.write_letters` `st.errand` `st.pawn_own` `st.gamble` …：`slots` + `check`（收 `self` 带 `attr`、或钱），成功挣几个钱（`money` + `k09.reason.street_work`）；`weight > 0`；`conditions` 可用 `{"mode": "street"}`。**`st.gamble`（去赌摊）：street 类型没有 `opens_wheel` 字段，用选项效果 `{"op": "wheel_offer", "wheel": "wh.gamble"}`**（发一张 `ev.any.wheel_go`）。
- [ ] 牢房 `pr.cell`（系统牌，`weight: 0`）：格子收钱（打点）、人脉（作保，`attr: "pull"`）、留牌（人情、介绍信、金条）；`check.need`；`on_success` 出来（`heat` 降）；`on_fail: [{"op": "game_over", "reason": "prison"}]`。照 §4.7.14。brief 写明：没处理就在牢里多待一晚（第二天铺子关门、不发人物牌），连续 `ladder.json.prison.max_days` 晚没出来按打点失败结算（§7.4.7）。

### G. 标签、界面键
- [ ] `data/cards/tags/K09.json`；`data/cards/ui_keys/K09.json`（`k09.reason.*`（如 `street_work` `box_returned`）、`k09.arrest.*`（如 `contraband`）、`k09.notice.*`）。

## 10-13 变更：打烊 · 下一天永远可用（合同 1.2：红线 9、§7.4.7；DESIGN §九.5）

> 主创 2026-10-13：“得设计进入下一天的按钮，不能卡住。节奏由主控玩家把握”。牌桌上永远有“打烊 · 下一天”，任何时候都能按；还有牌没处理就先列清单、玩家确认后按“没理会”结算；`day.end` 不再被任何牌挡住；所有面板和小游戏都能关；没有真实时间倒计时。同一天主创回复“同意你说的九点”，原来【待主创确认】的做法都定了（合同附录 F）。本节是这条规则落到本任务的部分；和上文冲突时以本节和合同 §7.4.7 为准。

- [ ] **街头牌**（`must_resolve` 默认为真）：有顶层 `check` 的，没理会 = 当没过（一般就是没挣到钱）；没有顶层 `check` 的必须写 `effects.on_expire`（可以是 `[]`，V37）。brief 里一句话写明没理会的结果。
- [ ] **牢房 `pr.cell`**：见上文 F 节——没处理多待一晚、几晚没出来按 `on_fail` 结算；牌本身的格子与检定不变。
- [ ] **夜牌**：在牢里过夜时不发夜牌（当晚起）；夜里可以不选（“算了”），所以夜牌不用为此加字段。
- [ ] **留着的牌**不在手牌里，打烊不影响；`kp.brother_note` 这类信物在手上没留也不会丢（`keepable`、`expires_days: 0` 的留在手上）。

## 10-13 变更二：画面与对话（合同 1.3：§1.2、§4.7.24、§7.11；DESIGN §九.6）

> 主创 2026-10-13 晚看了纯文字牌桌版的试玩：“不对吧，你这个为啥没有画面。我想的就是深空当铺那种二维的，然后牌在最下面跟炉石传说一样，旁边有一些能打开关闭的功能。主要还是看画面跟别人对话，不是打牌。打牌是玩法，对话是载体。”编排按这个方向重做了网页原型（`docs/cards/prototype/`），主创看完说“不错”。合同升到 1.3：画面是 320×180 的像素柜台场景整数 4 倍铺满 1280×720，上面一层界面（HUD、左上的对话框、最下面的炉石式手牌扇、英雄头像与人脉小牌、两侧标签与抽屉、右侧中下的“打烊 · 下一天”）；打出一张牌就在画面里“演”，你的选择是对话框里的“回话”。九条红线、免 AI 声明、归属、隐藏数值、已有的冻结签名都不变。本节是落到本任务的部分；和上文冲突时以本节和合同 §7.11 为准。

**要做的事**

数据卡共用的写法：

- 演出块的格式、站位、道具位、效果、拍子见合同 §4.7.24；默认演法见 §7.11.4——**默认够用的牌不写**。
- **什么时候能写**：G01 的 1.3 小 PR（schema 加 `stage`、校验器挂 V38–V42）合入之后（目标 10-15）。在那之前写了会被 V03 报“未知字段”。所以演出块**另开一个 PR**（标题 `[K09] 演出块`），你手上已经提审的 PR 不用为 1.3 改。
- 只写 id、站位、道具、效果和对白的**键**（`ref`）；每拍必须有 `brief`（谁、说什么意思，干巴巴的；不写台词、不写引号对白）。对白的键自己起：`lines.<名>`（人说的）、`outcomes.<名>`（旁白结果），名字只用 `[a-z0-9_]`；正文由 A 写在 `data/cards/text/**` 那张牌的条目下。
- 说话的人只能是这张牌的 `person` 或本块 `cast` 里的人（V39）；群演用 `ex_*`（§3.5，K09 登记）；沈如花自己说的话用 `who: "me"`。
- 用到的 `prop.*`、`bg.*`、群演的 `walk.*` / `portrait.*` 要在美术清单里（V42，strict）；清单里没有的开 `[shared] K09→K12`。
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

- [ ] **新文件 `data/cards/common/extras.json`（群演，先交，单独一个小 PR）**：`{"_meta": {"owner": "K09", "schema": 1, "brief": "演出里的群演"}, "persons": {…}, "cards": []}`，九个群演 `ex_patrol` `ex_soldier` `ex_newsboy` `ex_girl` `ex_shopboy` `ex_oldman` `ex_porter` `ex_student` `ex_hu2_man`，每个 `{"portrait": "portrait.<id>", "dossier": false, "brief": "<谁，史实措辞照 era.json；名字由 A 定>"}`（合同 §3.5 的“群演”一段：巡警、伪军、报童/跑腿带话的、对门的姑娘、邻铺的伙计、老先生、过路人/码头扛包的、学生、胡二的人（只作剪影））。这个文件里没有 `stage`，**不用等 G01 的 1.3 小 PR**，尽早合——K02、K04、K06、K08、K16 的演出块用群演，V39 的登记部分（strict）要它。
- [ ] **六张夜牌写演出块**：
  - 整理库房 `nt.tidy`：`props: [{"art": "prop.shelf", "at": "door_notice"}]`（货架图 208×50、画面里 ×4，放 `wall_right` 会出画面右边框，所以放门上正中；夜里门板上着）；
  - 对账 `nt.accounts`：`props` 账簿 + 算盘（`prop.ledger` @ `counter_left`、`prop.abacus` @ `counter_right`）；
  - 后门收货 `nt.backdoor`：`set: "candle"`；
  - 发电报 `nt.telegraph`：`set: "post"`、`cast: [{"who": "postman", "at": "customer"}]`；
  - 回家吃饭 `nt.family_dinner`：`fx: ["warm"]`（两个选项 `waive_life` `family_word` 想接话就写 `after.waive_life` / `after.family_word`，可选）；
  - 早点睡 `nt.early_sleep`：`fx: ["dim"]`。
- [ ] **每张街头牌写演出块**：`set`（`street` `dock` `market` `ricehall` `teahouse` 等，照牌的意思）+ `cast: [{"who": "ruhua", "at": "door"}]`（赌一把那张 `st.gamble` 用 `ex_porter`）。街头时 `set` 不是 `counter`，所以不许写 `walk`、不许用 `street` 站位（V41）；沈如花自己说的话用 `who: "me"`。
- [ ] **`pr.cell` 写 `{"set": "prison"}`**（再加 1–2 拍 `intro` 可选）。
- [ ] 你自己、人脉、留着的牌、家当**不许**带演出块（V40）。
- **数量**：群演 9、夜牌 6、街头牌全部、牢房 1–2。

**新增 / 作废的交付**

- 新增：`data/cards/common/extras.json`（小 PR，先交）；一个 PR `[K09] 演出块`（`night.json` `street.json` `prison.json`，G01 的 1.3 小 PR 合入后再提）。
- 作废：无。

**锚点、界面事件、要证明的步骤**

- 数据任务照旧不登记锚点、不发界面事件。上文“新手指引”表里的旧锚点名已按合同 §7.10.5 的改名表改成 1.3 的名字（`a.left.kept` → `a.hand.kept`，留着的牌进了手牌扇；`a.left.contacts` → `a.contacts`，人脉成了头像旁的小牌，备 `a.tab.contacts`），你的数据和测试不用为此改。
- 夜牌在画面里：打烊后的夜里，手牌扇里是今晚的夜牌和“睡了”，打出一张就是今晚做它（C02、C08）；`gd.d1.night` 的 `done_when` 多了 `ui:hand_played`（K16 改）。

**测试与截图**

- `K09_validate` 照旧（default 绿；G01 的 1.3 小 PR 合入后它也查 V38–V41）。
- `extras.json` 的 PR 里 `test_data.gd` 加：九个群演都在、和 `CardIds.EXTRAS` 一致、每个 `portrait == "portrait.<id>"`、`dossier == false`、brief 非空。
- 演出块 PR 里 `test_data.gd` 加：六张夜牌都有 `stage`；每张街头牌都有 `stage`、`set` 不是 `counter`、`cast` 非空；`pr.cell` 的 `stage.set == "prison"`；`self` `contact` `kept` `estate` 类型的牌都没有 `stage`；演出块里每个 `brief` 也过 brief 自查。
- 截图：数据任务照旧不交。

**已经做了的哪些还有效**

- 全部有效；`extras.json` 与演出块另开 PR。

**日期**：`extras.json` 尽早（不等 G01）；演出块 PR 在 G01 的 1.3 小 PR（10-15）合入后提，**10-27** 前合入（1938 的演出块，见交接页检查点）。

## 只能改这些文件

与合同 §2.2 / `docs/cards/ownership.json` 完全一致：

- `data/cards/common/**`
- 默认拥有：`scripts/tests/cards/K09/**`、`scripts/tests/cards/suites/K09.txt`、`data/cards/tags/K09.json`、`data/cards/ui_keys/K09.json`

## 不能做的事

1. **不写玩家最终内容**（正文字段——留牌的 `use`、家当的 `mortgaged` 也是正文，A 写；人写路径；brief 以外的中文；台词与引号对白）。
2. 不做“哥哥的账簿批注”留牌；不写 `kp.history_issue`。
3. 不改 `data/cards/rules/**`（留牌上限 `deal.json.caps` 归 G01、阶梯顺序 `ladder.json` 归 G06）；不改别人的数据、`_examples/**`。
4. 不写 `minigame`；不发明字段、op、条件；家当的 `while_mortgaged` 只用合同 §4.7.11 列的五种修正项。人脉的 `mods` 合同只说“同家当的格式”，而 G03 要从人脉读 `appraise_pct`（陈文庭）这类不在五种里的修正项——**写法先和 G03 在 `[shared] K09→G03` issue 里定，定之前用 `{"mod": "appraise_pct", "cats": […], "pct": n}` 并在 PR 里标“待 G03 确认”**（校验器目前不查 `mods` 的形状）；不自己加玩法。
5. 史实措辞（良民证、伪政权名）；不拷旧版 AI 文字（`data/night.json` 是旧夜晚，只读）。

## 接口

**用到**：§4.7.2、§4.7.9–§4.7.14；§5.2（`arrest` `game_over` `money` `heat` `waive` `add_card` `extra_deal` `price_mod` `wheel_offer` `contact_gain` `person_state` …）、§5.3。

**提供**：`self.ruhua`（G03 属性）、留牌（G03 格子加成、G05 香案份数、G01 留牌满了）、人脉（G03 被动、~~C01 左栏~~（10-13 作废，合同 1.3：C02 的人脉小牌与 C03 的人脉抽屉））、家当（G06 抵押与修正项、C11）、夜牌（G02 夜里三选一、C08；1.3 起在 C02 的手牌扇里打）、街头（G06、C11）、`pr.cell`（G06 `arrest` 发）。

## 新手指引

- **锚点**：不登记。**first-time**：不发。你的数据决定：

| 机制（发出者） | 你的哪张牌让它出现 | 支持的步骤（教的人 · 锚点） |
|---|---|---|
| `keep`（G01） | `kp.brother_note`（第 2 天） | `gd.d2.keep`（brother · `a.card.keep@{uid}` 备 `a.hand.kept`） |
| `night`（G02） | 第 1 天晚上的三张夜牌 | `gd.d1.night`（brother · `a.night.offers`） |
| `kept_expire`（G01） | 有 `expires_days > 0` 的留牌过期 | `gd.kept_expire`（obj.brother_ledger · `a.hand.kept`） |
| `kept_full`（G01） | 留牌满 5 张又进一张 | `gd.kept_full`（obj.brother_ledger · `a.slots.discard`） |
| `kept_risk`（G03） | 带 `risk` 的留牌（`kp.mystery_box`、把柄） | `gd.kept_risk`（obj.brother_ledger · `a.hand.kept`） |
| `contact`（G03） | `ct.zhouma`（第 7 天教学牌让她成人脉） | `gd.contact`（zhouma · `a.contacts` 备 `a.tab.contacts`） |
| `contacts_full`（G03） | 人脉满 3 个又来一个 | `gd.contacts_full`（obj.brother_ledger · `a.slots.release`） |
| `mortgage` `money_short`（G06） | 家当（钱不够时押） | `gd.mortgage` `gd.money_short`（"" · `a.estate.mortgage` / `a.short.options`） |
| `street`（G06） | 街头牌 | `gd.street`（"" · `a.street.redeem`） |
| `prison`（G06） | `pr.cell` | `gd.prison`（"" · `a.prison.slots`） |

- **指引验收（必须有测试）** `scripts/tests/cards/K09/test_guide_support.gd`：
  1. `kp.brother_note` 存在：`type == "kept"`、`keepable == true`、`expires_days == 0`。
  2. `ct.zhouma` 存在：`person == "zhouma"`、`attrs` 四项齐。
  3. 至少 3 张夜牌的 `conditions` 在“第一关第 1 天、铺子开着”时为真（测试里只认 `mode`、`day_gte`、`flag` 三种：`day_gte` ≤ 1、没有要求旗标）；`nt.family_dinner` 有 `waive_life` 和 `family_word` 两个选项，后者 `add_card nw.any.family_word`。
  4. 至少 2 张留牌 `expires_days > 0`（`gd.kept_expire` 有机会亮）；至少 1 张有 `risk`；`pr.cell` 的 `on_fail` 有 `game_over`。
  5. 五件家当齐，`es.shopfront.lose_if_unredeemed == true`。
- **W2**：K14 真引擎第 1–3 天走查里 `gd.d1.night`（第 1 天）、`gd.d2.keep`（第 2 天）靠你的数据；三关走查里阶梯与牢房的步骤。**截图**：数据任务不交截图。

## 测试与验收标准

**清单** `scripts/tests/cards/suites/K09.txt`：

```
# K09 通用牌：留牌、人脉、家当、夜牌、街头、牢房、你自己（docs/handoff_cards/K09_data-common.md）
K09_validate|res://scripts/cards/core/validate_main.gd|120|--only=data/cards/common/**,data/cards/tags/K09.json,data/cards/ui_keys/K09.json --name=K09_validate
K09_data|res://scripts/tests/cards/K09/test_data.gd|120|
K09_guide_support|res://scripts/tests/cards/K09/test_guide_support.gd|120|
```
（W2 加 `--mode=strict` 的同一行，名字 `K09_validate_strict`。）

**`test_data.gd` 必须断言**：
- [ ] 数量：留牌 ≥ 13（约 15）、人脉 = 11（§3.5 全部）、家当 = 5、夜牌 = 6（§3.5 全部）、街头 ≥ 10（约 12）、牢房 1–2、`self.ruhua` 1。
- [ ] §3.5 预留的 id 都在（`kp.history_issue` 除外）；`ruhua` 在 `self.json` 的 `persons` 块登记。
- [ ] 每张：`_provenance.task == "K09"`、brief 非空、标签已声明；kept 都 `keepable: true`（V14）；收人的格子都有 `attr`（V15）；`pr.cell` 与所有留牌、人脉、家当 `weight == 0`。
- [ ] 原因键、逮捕原因键 `k09.` 开头且已登记。
- [ ] brief 自查：引号里 ≤ 12 字、不含 `。！？`；伪政权名前有“伪”。
- [ ] 悬空引用报告（`NOTE: dangling <id>`，例 `nw.any.family_word` 在 K08 合入前）。

**怎么跑**：
```bash
export GODOT=<你的 Godot 4.7>
CARDS_SUITES=K09 bash tools/run_card_tests.sh
bash tools/run_card_tests.sh && bash tools/run_legacy_smoke.sh
```
**通过条件**：退出码 0；无 `SCRIPT ERROR` `ERROR` `WARNING` `Parse Error` `FAIL:` `DATA ERROR`、无泄漏；每行 `CARDS TEST PASS <名字>`；真数据 default 校验绿。

## 交付

- **PR 标题** `[K09] <中文摘要>`，目标 `claude/festive-ride-vud32a`。建议：①`[K09] 你自己、哥哥的交代、周妈人脉、夜牌、牢房`（先合：第 1–3 天教学与 `pr.cell` 在等）；②`[K09] 留牌、人脉、家当`；③`[K09] 街头牌`。
- **PR 描述**按模板填满，另外：改动路径；最后 20 行；数量表；留牌加成表（留牌 → 匹配的格子标签 → 加成）；家当表（押值、利息、押出后的损失）；和 G03/G06 确认过的修正项格式；悬空引用；需要主创/编排决定的事；完成写“交付”。

## 审核（Claude 重点）

1. 越界；2. 教学用的 `kp.brother_note`、`ct.zhouma`、第 1 天三张夜牌；3. 家当修正项只用合同里的五种；人脉 `mods` 的写法和 G03 对过；4. `st.gamble` 用 `wheel_offer` 而不是不存在的字段；5. 免 AI 声明与 brief 写法；6. 抽 5 张读 brief 与机制。

## 回报（执行者填写栏）

| 项 | 填写 |
|---|---|
| PR 链接（按顺序） | |
| 最后一个提交号 | |
| `run_card_tests.sh` 结果（最后 20 行） | |
| `run_legacy_smoke.sh` 结果（最后 20 行） | |
| 数量（留牌 / 人脉 / 家当 / 夜牌 / 街头 / 牢房） | |
| 留牌加成表、家当表 | |
| 新加的 id、标签、界面键 | |
| 悬空引用 | |
| 合同或数据缺口 | |
| 需要主创/编排决定的事 | |
| 已知问题、留给后面的事 | |
| 是否“交付” | |
