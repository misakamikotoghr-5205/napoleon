# ROGUE_V1 · 肉鸽元素第一版实现合同（六包并行）

> 主创原话：“能不能加一点肉鸽元素”。编排代主创定下 v1 范围（见 §0）。本文是 v1 的**实现合同**：六个包照本文并行开发、互不改同一个文件。
> 与 `design_R1_relics.md` / `design_R2_meta.md` / `design_R3_run.md` 冲突时**以本文为准**；本文没写的，照现有合同 `docs/cards/CARDS_INTERFACES.md`（1.5）与现有代码。
> 代码基线：本地分支 `reskin-integ`（`00e36ef6`）。下文所有 `文件:行` 都对这个提交核对过。
> 写法：玩家看得见的字一律走 `CardText`（界面键或牌的正文字段）；`.gd` 里不写中文字符串字面量（注释可以）；id 全 ASCII；`brief` 以外的数据里不写中文。

---

## 0. 一页摘要

**v1 做什么**

1. **一局 = 现有三关连玩**（1938 三月 → 1939 腊月 → 1940 三月）。R3 的“走一趟”整套（周图、世道、关口、家底结局）留到 v2。
2. **每局一个新种子**：第一本账固定 `7`（测试、黄金种子不变）；之后按“档案盐 + 本号 + 换了几次”推导，不读墙钟。标题上显示种子，有“换一个”，玩家也能自己填。同种子 + 同样的选择 = 同一局。
3. **老物件 / 博古格**：12 件（寻常 5、有来历 5、镇店 2；没有晦气、没有货郎商店、没有成套、没有修好），格数 6，满了挑新的必须让出一件。效果**只用现有修正项 kind 和现有 DSL op**；界面和正文只用词，不出现任何效果大小的数字。
4. **周末盘账**：每关第 7、14、21、28 天夜里日结时，从 3 样里挑 1 样（老物件和**客源**混着出）；这一周做成的生意不到 2 笔就只给 2 样。1938 第 0 周只出客源。客源 6 种，改门口来的人（买家多、来当的多……），管到这一关月底。外加 **1938 第 8 天货郎头一回上门**：二选一，只出寻常家什，兼新手引子。**挑不挑都不挡打烊**（不挑 = 过期作废）。
5. **旧账（局外）**：`profile.json` 和局内存档分开；一本账在**局终、被抓局终、或另起一本时**合上（合账）；标题上一个小书架，一本一根书脊、一句铺史；以前各本见过的档案碎片在后来的本子里画成**淡墨（旧墨）**；一个可解锁的开头 `og.shanghai`（合上第一本以后可选：在戏里免掉三天教学日）。引擎**从不读档案文件**：外壳把“本局上下文”经 `game.new` 的 `run` 参数交进去，收获经只读查询 `legacy.harvest` 拿出来。
6. 红线照旧：确定性；隐藏值不上界面；打烊永远能按；黄金种子按合同 §12.5 **在数据合入后一次性重算**（一个只改 `golden.json` 的提交）。

**v1 不做（写明，免得有人顺手做）**：R1 的晦气、修好、成套、货郎买卖、让出按钮（只有“满了换一件”）、物件的 `resolved`/`night`/`month_close` 钩子；R2 的年景、推理、知情回话、`alt_groups`、出身除 `og.shanghai` 以外的、合账大画面、旧账大画面；R3 的全部走一趟内容；**新的 first-time 机制与指引步骤**（见 §15.2，v1.1 补）。

**关键工程决定（理由见各节）**

| 决定 | 为什么 |
|---|---|
| 三个新引擎模块 `scripts/cards/relic/`（RG1）、`scripts/cards/stock/`（RG2）、`scripts/cards/legacy/`（RG5），照 K18 收徒的先例装在六段之后（无 `class_name`、`preload`） | 不碰冻结的六段，安装顺序只追加 |
| 所有共享常量和“插一行”的改动在 **步骤 0** 一次落地（§10），之后六包只改自己的文件 | 消除编译期依赖与同文件冲突 |
| **所有 JSON 数据与规则文件归 RG3**；引擎包的测试用自己的夹具数据根 | 黄金哈希只在 RG3 合入时变一次（规则文件也进 `db_hash`） |
| 新牌类型 `relic`（前缀 `rl.`）、`source`（前缀 `ky.`）只进 `CardIds.TYPE_PREFIX`，**不进** `CardIds.TYPES` | `W0_validator` 要求 `TYPES` 每一类在例子集里都有牌；不加例子牌 → 例子集黄金不因行为变 |
| 数据放 `data/cards/era/common/` 与 `data/cards/era/1938/`，**不放** `data/cards/common/` | `common/**` 归 K09，`K09_data` 测试要求那里每张牌 `_provenance.task == "K09"` |
| 物件美术 id 用 `prop.relic.<slug>`，不用 `relic.<slug>` | `gen_placeholders.py` 不认识的类别会直接退出（`DRAW` 表只有 frame/portrait/illus/item/prop/bg/wheel/icon） |
| 物件“毛病”正文放 `lines.flaw`，不新开 `flaw` 字段 | 校验器 V26 只放行 `TEXT_REQUIRED` 列出的字段和 `lines/outcomes/choices/slots/use`（`card_validator.gd:1049-1059`） |
| 盘账面板由引擎在 `settle` 钩子里 `request_panel`，不进手牌、不加打烊清单行 | 非白天阶段的打烊清单只收 `short` 行（`end_day_rules.gd:11-13`），所以永不挡打烊、永不要确认 |
| 旧墨走单独的查询 `legacy.old_ink`，不改 G03 的 `CardDossier.view` | 不碰 G03；档案簿界面自己合并 |
| `og.shanghai` 免教学日：教学牌的日程加 `when: {"not": {"veteran": true}}`，`CardComposer.is_scripted_day` 问新修正项 `unscripted_day` | 不改 `CardCtx.rules`（不做 R2 的规则覆盖层）；没有 `run` 时两处都恒等 |
| 不加新的 bus 信号 | `CardEventBus` 签名冻结，未知信号 `push_error`（`card_bus.gd:80`） |

---

## 1. 时间线与合并顺序

```
T+0      步骤 0（编排亲自做，约 30–45 分钟；§10 全是可照抄的代码）→ 提交到 reskin-integ
T+0:45   RG1 RG2 RG3 RG4 RG5 RG6 同时从步骤 0 的提交开工（各开分支 rogue/RGx）
T+3:00   合入：RG1 → RG2 → RG5 → RG4 → RG3（此时 G06_golden 变红，预期内）→ RG6
T+3:30   RG6 集成：全套测试（strict）、平衡对照、调数、黄金种子重算（单独一个只改 golden.json 的提交）、文档
```

- **步骤 0 落地后黄金种子不变**（只加常量、桩、空修正项；没有数据）。RG1、RG2、RG4、RG5 合入后也不变（没有数据 → 模块不写状态）。**只有 RG3 合入数据让黄金变**；RG6 的策略改动（会挑东西）也只在有数据时改变行为。所以：RG3 之前任何包让 `G06_golden` 变红都是 bug。
- 各包在自己分支上跑：`GODOT=<4.7.1> CARDS_VALIDATE_MODE=strict CARDS_SUITES=W0,C01,C16,<自己的> tools/run_card_tests.sh`。集成时 RG6 跑全套（不设 `CARDS_SUITES`）。
- 编排若用 `tools/cards/merge_gate.sh`：步骤 0 已在 `docs/cards/ownership.json` 登记 RG1–RG6 的路径（§10.12）。

---

## 2. 名词与 id

| 玩家看到的 | 引擎 / 数据 | 说明 |
|---|---|---|
| 老物件 | 牌类型 `relic`，id `rl.<slug>`，文件 `data/cards/era/common/relics.json` | 不发牌、不进任何区；持有记在命名空间 `relic` |
| 博古格 | 场景热点 `curio`（`CardLayout.CURIO`）、右抽屉面板 `relics`、视图块 `view.relics` | 3×2 六格 |
| 来历深浅：寻常家什 / 有来历的 / 镇店的 | 字段 `depth`：`plain` / `storied` / `treasure` | **不叫 rarity**（`rare` `rarity` 是视图黑名单键，`view_model.gd:8-12`）；也**不能叫 `grade`**（校验器把 `grade` 当整数查，`card_validator.gd:267-270`） |
| 客源（门口常来的人） | 牌类型 `source`，id `ky.<slug>`，文件 `data/cards/era/common/sources.json` | 选中后管到这一关月底，改人物牌库的权重 |
| 周末盘账 | 命名空间 `stock`、叠层面板 `stocktake`、指令 `stock.pick`、查询 `stocktake` | 每关第 7/14/21/28 天夜里 |
| 货郎头一回上门 | 人物牌 `p.stranger_peddler.1938.curios`（复用已登记的过路客 `stranger_peddler` 和立绘 `portrait.stranger_peddler`），效果 op `stock_offer` | 1938 第 8 天 |
| 旧账 / 合账 / 书架 / 旧墨 | 档案文件 `<存档根>/profile.json`（外壳 `CardProfile`）、状态命名空间 `run`、查询 `legacy.harvest` `legacy.old_ink` | |
| 开头：哥哥的铺子 / 上海学过徒 | `og.default` / `og.shanghai`（`data/cards/rules/legacy.json` 的 `openings`），条件 op `veteran`，修正项 `unscripted_day` | 视图里叫 `opening`，**不能叫 `origin`**（黑名单键） |
| 种子 | `game.new {seed}`（已有）；推导与解析 `CardRunSeed`（`scripts/cards/stock/run_seed.gd`） | `seed` 是黑名单键：只在外壳和标题里出现，引擎视图里永远没有 |

---

## 3. 状态命名空间（全部懒建；不进 `CardState.NAMESPACES`）

规矩（三个模块都一样）：

- **懒建**：读用 `ctx.state.data.get("<ns>", {})`（只读，不建键）；只有第一次真要写时才 `ctx.state.ns("<ns>")`。没写过就不存在 → 没有这套数据的局（例子集、`enabled: false`）状态哈希一字不变。
- **不碰别人的命名空间时也不要调 `ns()`**：`CardState.ns()` 会顺手建空字典（`card_state.gd:28-31`）。读别人的用 `ctx.state.data.get(...)`。
- 只放 int / String / bool / Array / Dictionary；不许浮点（`card_t.find_floats` 测）；遍历字典先排序键。
- `CardState.from_dict` 原样保留不认识的命名空间（`card_state.gd:41-46`），存档信封不变，`game.retry_stage` 读回关开头的样子。

### 3.1 `relic`（RG1 独写；RG2 只经 `relic_api.gd` 写）

```json
"relic": {
  "_v": 1,
  "held": [{"id": "rl.stub_box", "since": 8, "src": "stock:p8"}, {"id": "rl.chen_mortar", "since": 14, "src": "stock:w0.1"}],
  "gone": ["rl.blue_curtain"]
}
```

- `held` 按拿到的先后；`since` = 拿到那天的 `abs_day`；`src` 只给日志（`stock:<offer id>` / `test`）。
- `gone`：被让出的，这一局不再出现在任何报价里。

### 3.2 `stock`（RG2 独写）

```json
"stock": {
  "_v": 1,
  "deals": {"0:0": 3, "0:1": 1},
  "offers": {
    "w0.1": {"from": "week", "stage": 0, "week": 1, "abs_day": 14, "deals": 1,
             "items": [{"id": "rl.chen_mortar", "kind": "relic"}, {"id": "ky.dockhands", "kind": "source"}],
             "status": "open", "picked": ""},
    "p8":   {"from": "peddler", "stage": 0, "week": -1, "abs_day": 8, "deals": 0,
             "items": [{"id": "rl.stub_box", "kind": "relic"}, {"id": "rl.oilpaper_umbrella", "kind": "relic"}],
             "status": "picked", "picked": "rl.stub_box"}
  },
  "sources": [{"id": "ky.dockhands", "stage": 0, "since": 14}]
}
```

- `deals` 键 `"<stage>:<week>"`，`week = (stage_day - 1) / 7`（第 1–7 天 = 0 … 第 22–28 天 = 3，第 29–30 天 = 4，不用）。
- 报价 id：周末 `w<stage>.<week>`，货郎 `p<abs_day>`。`status`：`open` / `picked` / `passed`（明说都不要）/ `lapsed`（过了那一天没挑）。
- `sources` 只对 `stage == 当前关` 的生效；新的一关 `stage_start` 时删掉旧关的。

### 3.3 `run`（RG5 独写；只在 `game.new` 给了非空 `run` 时出现）

```json
"run": {"_v": 1, "no": 3, "opening": "og.shanghai", "known": ["df.brother.1938.farewell", "df.linsao.1938.husband"]}
```

- `known`：开局时冻结的“以前各本账见过的碎片”，去重、排序、只留数据库里存在的 `dossier_fragment`。局内**不再改**。
- 没有 `run` = 今天的游戏（零传承恒等）。

---

## 4. 引擎接口

### 4.1 `game.new` 的新参数 `run`（步骤 0 改 `loop_install.gd`，RG5 实现）

```json
{"seed": 1844671223, "stage": 0,
 "run": {"no": 3, "opening": "og.shanghai", "known": ["df.brother.1938.farewell"]}}
```

- `run` 不给或 `{}`：状态里没有 `run` 键，一切照旧。
- `run` 不是字典 → `bad_args`（步骤 0 的代码）。`CardLegacyInstall.check_run(db, run)` 返回 `""` 或错误码，**在建状态之前**调：`no` 不是 ≥1 的整数、`opening` 不是 `rules/legacy.json` `openings` 的键、`known` 不是字符串数组 → `bad_args`。`known` 里数据库没有的 id **静默丢掉**（数据会改版）。
- `init_run(ctx, run)` 在 `CardState.create` 之后、`begin_stage` 之前调，写 `state.run`。
- `run` 在指令日志第一条里（`card_engine.gd:90-91`），回放原样重现；发给界面的 `command_done` 照旧过 `_visible_args`（`run` 的键都不在黑名单里）。
- `seed` 照旧（`loop_install.gd:38-40` 只要整数）。**引擎对种子不需要任何改动**。

### 4.2 指令（新增 1 条）

| 指令 | 参数 | 成功返回 | 主人 | 错误 |
|---|---|---|---|---|
| `stock.pick` | `{"offer": String, "pick": String, "replace"?: String}` | `{"ok": true, "err": "", "offer", "picked", "kind": "relic"/"source"/"", "released": ""/"rl.x"}` | RG2 | `bad_args`（缺参、类型错、没有这个 offer）· `bad_phase`（`game_over`）· `already_resolved`（status 不是 `open`）· `not_allowed`（`pick` 不在这份报价里 / 模块没启用）· `relic_full`（满了没给 `replace`）· `not_held`（`replace` 不在博古格上）· `unknown_def` |

- `pick == ""`：明说都不要 → `status = "passed"`。
- 关于阶段：报价在哪个阶段开着就在哪个阶段能挑（周末报价在 `settle`，货郎报价在 `day`，之后的 `night`/`settle` 也行）；第二天 `day_start` 一律作废。
- 成功后若 `loop.open_panel` 正是这份报价（`kind == "stocktake"` 且 `args.offer` 相同）→ `CardDayLoop.request_panel(ctx, &"", {})` 清掉。
- 物件那一支调 `RelicApi.take(ctx, pick, replace, "stock:" + offer)`（§4.7），把它的错误码原样返回。
- 在 `CardEngine._overflow_pending` 时会得到 `overflow_pending`（现有行为，`card_engine.gd:153-156`），不用管。

### 4.3 查询（新增 4 个）

**`relics {}`（RG1）**

```json
{"ok": true, "err": "", "cap": 6, "count": 2, "dormant": false,
 "held": [{"id": "rl.stub_box", "art": "prop.relic.stub_box", "depth": "plain", "since": 8}]}
```

模块没启用（`rules/relics.json` 的 `enabled` 为假，或数据库里一件 `relic` 都没有）→ `{"ok": true, "err": "", "cap": 6, "count": 0, "dormant": false, "held": []}`。

**`stocktake {"offer"?: String}`（RG2）**

```json
{"ok": true, "err": "", "offer": "w0.1", "from": "week", "stage": 0, "week": 1, "deals": 1, "status": "open", "picked": "",
 "items": [{"id": "rl.chen_mortar", "kind": "relic", "art": "prop.relic.chen_mortar", "depth": "storied"},
           {"id": "ky.dockhands", "kind": "source", "art": "illus.ky.dockhands", "depth": ""}],
 "cap": 6, "full": false,
 "held": [{"id": "rl.stub_box", "art": "prop.relic.stub_box", "depth": "plain"}]}
```

- `offer` 不给或 `""` → 最近一份 `open` 的；没有 → `{"ok": false, "err": "not_allowed"}`。给了但不存在 → `{"ok": false, "err": "bad_args"}`。
- `week`：0 起（界面显示 `week + 1`）；货郎报价是 `-1`。`deals`：这一周做成的笔数（玩家自己做的事，看得见）。
- `held`/`cap`/`full` 来自 `RelicApi`（满了时界面要“让出哪一件”）。

**`legacy.harvest {"close"?: String}`（RG5，只读）**

```json
{"ok": true, "err": "", "no": 3, "phase": "game_over", "reason": "prison",
 "stage": 1, "era": "1939", "stage_day": 17,
 "frags": ["df.brother.1938.farewell", "df.linsao.1938.husband"],
 "chronicle": {"key": "rg5.chronicle.prison.1939", "args": {"d": 17}}}
```

- 没有 `run` 键时 `no` 为 0，其余照给（外壳在第一本账、旧存档上也能收）。
- `frags`：这一本“已得到”的碎片（`CardDossier.view(ctx)` 里 `state == "have"` 的 id，排序）。
- `chronicle` 只在给了 `close` 时有；规则见 §5.6。`close` 取值：`ending` `prison` `abandoned` 或别的（→ `rg5.chronicle.other`）。
- 查询前后 `state_hash()` 不变；结果过 `CardViewModel.leaks()`。

**`legacy.old_ink {}`（RG5，只读）**

```json
{"ok": true, "err": "", "pages": [{"person": "linsao", "fragments": [{"id": "df.linsao.1938.husband", "order": 20}]}]}
```

- = `run.known` 里、这一本既没拿到也没撕成缺口的碎片，按人分页（`def.person`），页按人 id 排序、碎片按 `order` 再按 id 排序。没有 `run` → `pages: []`。

### 4.4 效果 op、条件 op、修正项 kind（新增）

| 种类 | 名字 | 形状（步骤 0 写进 `dsl_shapes.gd`） | 主人 | 语义 |
|---|---|---|---|---|
| 效果 op | `stock_offer` | `{"n": "int", "kinds": "strs", "depths": "strs?", "from": "str"}` | RG2 | 立刻生成一份报价并请界面开 `stocktake`（§5.2）。模块没启用 → 什么都不做 |
| 条件 op | `veteran` | 值 `"bool"` | RG5 | `rules/legacy.json` 里当前 `run.opening` 的 `veteran` 等于值；没有 `run` 时当作 `false` |
| 修正项 kind | `unscripted_day` | `any_true`，参数 `{"stage": int, "stage_day": int}` | 问的人：`CardComposer.is_scripted_day`（步骤 0）；提供者：RG5 | 为真时这一天不当教学脚本日（照常随机发牌） |

`W0_engine` 测试要求 `EFFECT_OPS` 每个 op 的登记者 = 表里写的主人、登记的条件 op 数 = `COND_OPS` 数（`scripts/tests/cards/W0/test_engine.gd:24-26`），所以步骤 0 的桩就用 `"RG2"`/`"RG5"` 登记。

### 4.5 修正项提供者（只用现有 kind；参数照现有调用点）

| kind | 现有调用点（问的人、参数） | 组合方式 | RG1 物件 | RG2 客源 |
|---|---|---|---|---|
| `price_pct` | `economy/pricing.gd:14`，`{direction: "pay"/"receive", cat, item_id}` | `pct` 连乘（`card_mods.gd:24-29`） | 是 | — |
| `patience_pct` | `economy/customer.gd:31`，`{uid}` | 连乘 | 是 | — |
| `appraise_pct` | `economy/appraisal.gd:68`，`{cat, item_id}` | 连乘 | 是 | — |
| `cap` | `economy/shelf.gd:14` `{zone: &"shelf"}`；`core/card_piles.gd:155` `{zone: &"kept"/…}` | `sum_int` | 是 | — |
| `pool_pct` | `fate/weights.gd:68`，`{pool, def}`（只给 def id，标签/来意自己查 `ctx.db`） | 连乘 | 是 | 是 |
| `deal_count` | `core/card_composer.gd:64`，`{type: pool, abs_day}`（`project()` 预测未来日也走它） | `sum_int` | 是 | 是 |
| `coins` | `rules/slots.gd:139`，`{uid, slot_id, source: {kind, uid?, item?, amount?}}` | `sum_int` | 是 | — |
| `scheduled_cards` / `end_rows` / `intake_blocked` 等 | — | — | 不用 | 不用 |
| `view_section` | `loop/view_model.gd:52` | `merge`，键冲突 `push_error` | 键 `relics` | 键 `stock` |
| `unscripted_day`（新） | `core/card_composer.gd` `is_scripted_day`（步骤 0） | `any_true` | — | — （RG5 提供） |

RG5 另提供 `view_section`（键 `run`）。三个新键 `relics` `stock` `run` 与现有视图键不冲突（现有：`view_model.gd:31-51` 加各模块的 `rep_tier` `heat_tier` `self` `dossier_new` `money` `shelf_count` `tickets` `estates` `apprentice_desk` `pet` 等）。

**提供者的性能规矩**：`pool_pct` 每抽一张牌、每个候选都要问一遍。没有持有的物件 / 没有生效的客源时**第一行就返回 100（或 0 / false）**；查牌的标签用 `ctx.db._cards.get(def_id, {})` 只读，不要 `duplicate`。

### 4.6 钩子与 priority（新增的登记）

| 钩子 | priority | 主人 | 做什么 |
|---|---|---|---|
| `stage_start` | 60 | RG2 | 删掉不是本关的客源；删了就发告示 `rg2.notice.sources_lapsed` |
| `day_start` | 2 | RG5 | `veteran` 且第 0 关第 1 天：发开头告示（`rules/legacy.json` 里 `openings.<id>.notice`） |
| `day_start` | 3 | RG2 | 把 `abs_day` 早于今天的 `open` 报价标成 `lapsed` |
| `day_start` | 25 | RG1 | 物件 `passives`/`downsides` 里 `hook == "day_start"` 的行（在 G03 发条子 `rules_install.gd:30` 的 priority 30 **之前**，所以 `demand_tier` 能落到当天的条子上） |
| `card_resolved` | 35 | RG2 | `args.almanac` 含 `"trade"` → 这一周 `deals` +1（柜台成交都带 `trade`：`economy/counter.gd:135,201` → `economy_support.gd:83` → `card_piles.gd:97-98`） |
| `settle` | 45 | RG1 | 物件 `hook == "settle"` 的行（G03 风声每日回落在 40 之后） |
| `settle` | 80 | RG2 | 周末盘账（G02 写日结报告在 70，`loop_install.gd:33`；本钩子发的告示照样进日结，因为 `choose_night_choice` 在钩子链之后再收一次，`day_loop.gd:197-199`） |

`CardIds.HOOKS` 不加新名字（没有新钩子）。

### 4.7 RG1 对 RG2 公开的 API：`scripts/cards/relic/relic_api.gd`（无 `class_name`，`preload`）

```gdscript
static func active(ctx: CardCtx) -> bool                     # rules relics.enabled 且数据库里至少一件 relic
static func held_ids(ctx: CardCtx) -> PackedStringArray       # 按拿到的先后
static func gone_ids(ctx: CardCtx) -> PackedStringArray
static func cap(ctx: CardCtx) -> int                          # rules relics.cap，默认 6
static func is_full(ctx: CardCtx) -> bool                     # held_ids().size() >= cap()
static func can_take(ctx: CardCtx, id: String, replace: String) -> String
static func take(ctx: CardCtx, id: String, replace: String, src: String) -> String
```

`can_take` / `take` 的错误码（`""` = 成功）：没启用 → `not_allowed`；`id` 不存在或类型不是 `relic` → `unknown_def`；已在 `held` 或 `gone` → `not_allowed`；`replace != ""` 且不在 `held` → `not_held`；`replace == ""` 且已满 → `relic_full`。`take` 成功时：懒建命名空间；有 `replace` 先把它从 `held` 移到 `gone`、发告示 `rg1.notice.released`；再追加 `{id, since: abs_day, src}`；发告示 `<id>#lines.gain`（牌的正文字段，RG3 写）；`ctx.emit(&"view_changed", [["relics"]])`。

步骤 0 给的是桩（签名不变，`active` 已是真实逻辑，`take` 返回 `not_implemented`）；RG1 换成正式实现。

### 4.8 视图（界面读的字段）

```json
"relics": {"cap": 6, "count": 2, "dormant": false,
           "held": [{"id": "rl.stub_box", "art": "prop.relic.stub_box", "depth": "plain", "since": 8}]},
"stock":  {"open": "w0.1", "week_deals": 1,
           "sources": [{"id": "ky.dockhands", "art": "illus.ky.dockhands"}]},
"run":    {"no": 3, "opening": "og.shanghai"},
"open_panel": {"kind": "stocktake", "args": {"offer": "w0.1"}}
```

- `relics`：RG1 模块启用时才有（例子集没有）。`dormant`：流落街头或在牢里时为真（§5.4）。
- `stock`：RG2 模块启用时才有。`open` = 最近一份 `open` 报价的 id，没有为 `""`；`week_deals` = 今天所在这一周已做成几笔。
- `run`：有 `state.run` 时才有。
- `open_panel` 是 G02 已有的字段，盘账时由 RG2 经 `CardDayLoop.request_panel` 填。
- 所有新键都过 `CardViewModel.leaks()`：不出现 `pct` `weight` `value` `tags` `rarity` `origin` `seed` 等（`view_model.gd:8-22`）。**格数（4/6）和本周成交笔数是玩家看得见的计数，可以显示；效果大小一概不显示。**

### 4.9 总线事件（只用现有信号）

| 信号 | 谁发 | 什么时候 |
|---|---|---|
| `request_panel(&"stocktake", {"offer": id})` | RG2 | 周末盘账生成报价、`stock_offer` 生成报价 |
| `notice("rg2.notice.stocktake", {"deals": n})` / `rg2.notice.stocktake_few` | RG2 | 周末盘账那晚（进日结） |
| `notice("<ky id>#lines.gain", {})` | RG2 | 挑了客源 |
| `notice("rg2.notice.passed", {})` | RG2 | `pick == ""` |
| `notice("rg2.notice.sources_lapsed", {})` | RG2 | 换关删客源 |
| `notice("rg2.notice.peddler_empty", {})` | RG2 | `stock_offer` 没东西可摆 |
| `notice("<rl id>#lines.gain", {})` / `notice("rg1.notice.released", {})` | RG1 | 拿到 / 让出 |
| `notice(<opening notice key>, {})` | RG5 | `og.shanghai` 第 1 天早上 |
| `view_changed(["relics"])` / `(["stock"])` | RG1 / RG2 | 状态变了 |
| `game_over(reason)`、`saved(path, ok)`、`command_done(cmd, args, ok)` | 已有 | 外壳（RG5）用来合账、收获、重开 |

### 4.10 随机数域（步骤 0 登记进 `CardIds.RNG_DOMAINS`）

| 域 | 主人 | 键 | 用在 |
|---|---|---|---|
| `c.stock.offer` | RG2 | 周末：`[stage, week, k]`；货郎：`[stage, "p", abs_day, k]`（k = 第几格） | 摆哪几样（`ctx.draw`） |
| `m.run.seed` | RG2 | `[run_no, reroll]`，种子 = 档案盐 | `CardRunSeed.derive`（直接 `JevRng.draw`，不经 `ctx.draw`；登记只为文档） |
| `m.run.seed_text` | RG2 | `[text 前 24 字]`，种子 = 0 | `CardRunSeed.parse` 把非数字的字变成种子 |

物件、客源的效果**不掷随机**；要碰运气只有现有的铜钱格子（`coins` 修正项加一枚铜钱是看得见的）。

---

## 5. 规则与算法

### 5.1 周末盘账（RG2，`settle` priority 80）

```
stage_day ∈ rules.stock.week_days（[7, 14, 21, 28]）才做；week = stage_day / 7 - 1
跳过：模块没启用；loop.mode != "shop"；在牢里（state.data.ladder.prison.uid != ""）；本关这一周已经生成过（offers 里有 w<stage>.<week>）
deals = stock.deals["<stage>:<week>"]（默认 0）
n = rules.offers_full（3）if deals >= rules.deals_needed（2）else rules.offers_few（2）
kinds = ["source"] if "<stage>:<week>" ∈ rules.source_only_weeks（["0:0"]）else rules.slot_kinds 的前 n 个（["relic","source","relic"]）
relic_pool  = ctx.db.pool(&"relic", era)（weight>0、年代合）里 ctx.test(conditions) 为真、不在 RelicApi.held_ids / gone_ids 的；
              RelicApi.active 为假时为空
source_pool = ctx.db.pool(&"source", era) 里 conditions 为真、不在本关已生效客源里的
for k in 0..n-1:
    want = kinds[k]；该 pool（去掉已摆的）空 → 换另一种；两种都空 → 停
    id = JevRng.weighted_choice([[id, weight], …按 id 排序], ctx.draw("c.stock.offer", [stage, week, k]))
items 为空 → 不生成、不开面板
写 offers["w<stage>.<week>"] = {from:"week", stage, week, abs_day, deals, items, status:"open", picked:""}
notice: deals >= deals_needed ? rg2.notice.stocktake {deals} : rg2.notice.stocktake_few {deals}
CardDayLoop.request_panel(ctx, &"stocktake", {"offer": id})
```

- 打烊：盘账在 `settle` 阶段，打烊清单只收 `short` 行（`end_day_rules.gd:11-13`），所以 `day.end {confirm:false}` 直接进下一天；`enter_morning` 先 `request_panel("")`（`day_loop.gd:37`），`day_start` 3 把报价标 `lapsed`。**不新增任何打烊清单行、任何待办。**
- “做成的生意” = `card_resolved` 的 `almanac` 里有 `trade`（收当、收货、卖货、赎当都算）。打烊放走、拒绝不算。这就是“奖励来自做生意”：一周拒绝一切的人只能二选一。

### 5.2 货郎头一回（RG3 数据 + RG2 的 `stock_offer`）

- 人物牌 `p.stranger_peddler.1938.curios`（§6.6）第 8 天按日程发（`schedule: {"stage_day": 8, "order": 50}`；第 8 天原本没有日程牌，已核对）。来意 `story` → 面板是 `slots`（`view_model.gd:95-96`），两个选项：`look`（看看担子）跑 `{"op": "stock_offer", "n": 2, "kinds": ["relic"], "depths": ["plain"], "from": "peddler"}`；`send_off`（送客）什么都不做。选了以后牌就处理完（`rules/choices.gd:43-44`）。
- `stock_offer` 算法同 §5.1，但：报价 id `p<abs_day>`、键 `[stage, "p", abs_day, k]`、`depths` 过滤物件、不限周、`from` 写进记录；已有同 id 的 `open` 报价就只重新 `request_panel`。没东西可摆 → 告示 `rg2.notice.peddler_empty`。
- 没理货郎：打烊时按普通人物牌走掉（清单一行 `leave`、`g02.end.leave`，现有行为）。报价开着没挑：第二天作废。
- 1938 第 0 周（第 7 天）只出客源，所以玩家**第一次见到老物件就是第 8 天的货郎**：他的台词（RG3 写 `lines.greet`、`body`）在戏里讲“东西摆在后墙的博古格上，各有脾气，一回只能留一件”。

### 5.3 挑（`stock.pick`）

1. 校验（§4.2 的错误码）。
2. `kind == "relic"` → `RelicApi.take(...)`；错误原样返回，报价保持 `open`。
3. `kind == "source"` → 追加 `{id, stage, since: abs_day}` 到 `stock.sources`，告示 `<id>#lines.gain`。
4. `status = "picked"`、`picked = id`；清 `open_panel`（若是它）；`view_changed ["stock", "relics"]`。

### 5.4 物件怎么起作用（RG1）

**灵不灵**：`rules.relics.dormant_in_street` 且 `loop.mode == "street"`，或 `dormant_in_prison` 且 `state.data.ladder.prison.uid != ""` → 全部不灵（修正项返回中性值、被动不跑、视图 `dormant: true`）。“铺子不在手里，这些东西都收起来了。”

**常驻修正 `mods`**（每行一个字典；`pct` 是乘数，100 = 不变；`delta` 是整数增减；可选 `when`（条件）与 `flaw: true`（只给正文对照，引擎不看））：

| `mod` | 其余键 | 喂给 | 匹配 |
|---|---|---|---|
| `price_pct` | `direction`（`pay`/`receive`），`cats?`，`pct` | `price_pct` | `direction == args.direction`，`cats` 缺省 = 全部品类，否则含 `args.cat` |
| `patience_pct` | `pct` | `patience_pct` | 全部 |
| `appraise_pct` | `cats?`，`pct` | `appraise_pct` | 同上 |
| `shelf_cap` / `kept_cap` | `delta` | `cap` | `args.zone == &"shelf"` / `&"kept"` |
| `deal_count` | `type`（`person`/`event`/`news`），`delta` | `deal_count` | `type == args.type` |
| `pool_weight` | `pool`，`tags_any?`，`intents?`，`pct` | `pool_pct` | `pool == args.pool`；`tags_any` 缺省或与牌的 `tags` 有交集；`intents` 缺省或含牌的 `intent` |
| `coins` | `source_kind`，`slot_tags_any?`，`delta` | `coins` | `args.source.kind == source_kind`；`slot_tags_any` 缺省或与那一格的 `tags` 有交集（格子用 `CardSlots.slots_of(ctx, args.uid)` 按 `args.slot_id` 找；不会递归） |

- 同一种修正，所有持有物件按持有顺序乘（或加）完，**再钳进** `rules/relics.json` 的 `clamp`（§6.3）才交出去。
- `when` 只许用这些条件 op（RG1 测试查数据）：`all` `any` `not` `flag` `has_contact` `weather` `market_day` `almanac_yi` `estate_status` `stage_gte` `weekday` `heat_tier_gte` `rep_tier_gte`。都便宜、都不问修正项。

**被动 `passives` / 毛病 `downsides`**：`{"hook": "day_start" | "settle", "effects": [...]}`。效果只用现有 op（本 v1 数据用到 `if` `rep` `heat` `demand_tier`）。来源路径 `relic:<id>/<passives|downsides>/<i>/<hook>`。校验器本来就查这两个字段的 `hook`（必须在 `CONTACT_HOOKS`：`day_start` `deal` `demand_issue` `settle`，`card_validator.gd:20, 384-389`）和效果形状；RG1 只实现 `day_start` 与 `settle` 两种，数据里也只许这两种（RG1 测试查）。

### 5.5 客源怎么起作用（RG2）

- `mods` 只许 `pool_weight` 与 `deal_count` 两种行（格式同 §5.4，可带 `when`）。
- 生效范围：`stock.sources` 里 `stage == 当前关` 的。乘完钳进 `rules/stock.json` 的 `clamp`。
- 换关时删掉（`stage_start` 60），发 `rg2.notice.sources_lapsed`。
- 同一种客源这一关已生效时不会再摆出来。

### 5.6 旧账与铺史（RG5 引擎侧）

- `veteran`：`rules.legacy.openings[run.opening].veteran`。
- `unscripted_day` 提供者：`veteran` 且 `args.stage == 0` → `true`。配合 RG3 给 `tutorial.json` 里第 1–3 天的 9 张教学牌（`p.brother.1938.tut_handover` `p.zhang.1938.tut_pawn` `p.wu.1938.tut_sell` `p.xiaoding.1938.tut_buy` `p.sunyoung.1938.tut_pawn` `p.guanjia.1938.tut_buy` `ev.1938.tut_slots` `p.li.1938.tut_sell` `p.postman.1938.tut_buy`）的 `schedule` 加 `"when": {"not": {"veteran": true}}`（日程对单日 `stage_day` 也查 `when`：`loop/schedule.gd:36-38`）。效果：`og.shanghai` 第 1–3 天是普通营业日（随机来客、事件、消息照发），教学牌不来；**哥哥第 2 天照样来告别**（`p.brother.1938.farewell` 在 `story.json`，不动）；第 5–7 天的三张教学牌照发（周妈成人脉的主线要它们）。没有 `run` 时两处恒等。
- 第 1 天早上发开头告示（`rg5.notice.shanghai`，进早上的告示栏）。
- **铺史行**（`legacy.harvest {close}`）：

| `close` | 键 | 参数 |
|---|---|---|
| `ending` | 本心（`CardMeters.value(ctx, &"conscience")`）≥ `rules.legacy.chronicle.kind_at`（20）→ `rg5.chronicle.ending.kind`；≤ `hard_at`（-20）→ `rg5.chronicle.ending.hard`；否则 `rg5.chronicle.ending.plain` | `{}` |
| `prison` | `rg5.chronicle.prison.<era>`（`1938`/`1939`/`1940`） | `{"d": stage_day}` |
| `abandoned` | `rg5.chronicle.abandoned.<era>` | `{"d": stage_day}` |
| 其它 | `rg5.chronicle.other` | `{"d": stage_day}` |

  本心只在引擎里挑键，数值永远不出去（DESIGN §三.9 本来就让本心决定结局文字）。

### 5.7 种子（`CardRunSeed`，步骤 0 给出完整代码，RG2 负责测试）

- `derive(salt, run_no, reroll)`：`run_no <= 1 且 reroll <= 0` → `7`；否则 `1 + int(JevRng.draw(salt, "m.run.seed", [run_no, reroll]) * (MAX_SEED - 1))`，`MAX_SEED = 2147483646`。
- `parse(text)`：去空白；空 → `-1`（用建议的种子）；1–18 位纯数字 → 原值（越界折回 `1..MAX_SEED`）；别的字 → `1 + int(JevRng.draw(0, "m.run.seed_text", [前 24 字]) * (MAX_SEED - 1))`。
- 盐默认 0 → 每台机器第 2 本账的种子相同。这是有意的（不读墙钟、可复现）；以后要每台机器不同，建档时取一次墙钟作盐（R2 D6），不在 v1。
- 种子优先级（外壳）：命令行 / `boot` 参数里的 `seed`（测试、自动玩）> 标题种子框里的字 > 档案的建议值。

---

## 6. 数据（全部归 RG3；下文是 v1 的确切内容，起步数值【待调】）

### 6.1 文件清单

| 路径 | `_meta.owner` | 内容 |
|---|---|---|
| `data/cards/era/common/relics.json` | `RG3` | 12 件老物件（§6.4） |
| `data/cards/era/common/sources.json` | `RG3` | 6 种客源（§6.5） |
| `data/cards/era/1938/curio_peddler.json` | `RG3` | 货郎头一回（§6.6） |
| `data/cards/rules/relics.json` | `RG3` | §6.3 |
| `data/cards/rules/stock.json` | `RG3` | §6.3 |
| `data/cards/rules/legacy.json` | `RG3` | §6.3 |
| `data/cards/era/1938/tutorial.json`（K16 的文件，`_meta.owner` 不改） | `K16` | 9 张牌的 `schedule` 加 `when`（§5.6） |
| `data/cards/text_ai/era/common/relics.text.json`、`sources.text.json`、`data/cards/text_ai/era/1938/curio_peddler.text.json` | 文件级 `_meta._provenance` = `ai:claude:opus-5.5:2026-10-25:rogue-v1` | AI 基础层正文（§6.7） |
| `data/cards/art/manifest.json`（K12 的文件） | `K12` | 19 个美术 id（§12） |
| `tools/cards/art/gen_ai_rogue.py`、`art/ai/prop/relic.*.png`、`art/ai/illus/ky.*.png`、`art/ai/prop/curio.png`（+ `.import`）、`art/_placeholder/cards/**` 里这 19 个占位 | — | 程序画（§12） |

`_schema/relic.json`、`_schema/source.json` 在步骤 0（§10.9）。

### 6.2 牌的公共字段

`relic`：`id` `type` `era`（v1 一律 `["*"]`）`weight` `depth` `conditions?` `mods` `passives?` `downsides?` `art` `brief` `_provenance`（`{"by": "ai", "task": "RG3", "date": "2026-10-25"}`）。
`source`：`id` `type` `era` `weight` `conditions?` `mods` `art` `brief` `_provenance`。
**不许出现的键**：`title` `body` `name` `lines` `text` `label` `desc`（V04，任何深度都查）、`grade` `tier` `order`（V07 当整数查）、`tags`（v1 不用，免得要登记标签）。

### 6.3 三个规则文件（全文）

`data/cards/rules/relics.json`

```json
{
  "_meta": {"owner": "RG3", "schema": 1, "brief": "老物件与博古格（肉鸽 v1）：格数、不灵的时候、同类修正的钳子。数字待调，不上界面。"},
  "_doc": [
    "cap: bookshelf cells. Picking past it needs a replace.",
    "dormant_in_street / dormant_in_prison: held relics do nothing while the shop is lost or the player is jailed.",
    "clamp: the product (pct kinds) or the sum (delta kinds) over all held relics is clamped before it is returned."
  ],
  "enabled": true,
  "cap": 6,
  "dormant_in_street": true,
  "dormant_in_prison": true,
  "clamp": {
    "price_pay_min": 90, "price_pay_max": 105,
    "price_receive_min": 95, "price_receive_max": 115,
    "patience_min": 85, "patience_max": 125,
    "appraise_min": 90, "appraise_max": 140,
    "pool_min": 50, "pool_max": 200,
    "shelf_cap_min": -1, "shelf_cap_max": 2,
    "kept_cap_min": 0, "kept_cap_max": 1,
    "deal_count_min": 0, "deal_count_max": 1,
    "coins_min": 0, "coins_max": 1
  }
}
```

`data/cards/rules/stock.json`

```json
{
  "_meta": {"owner": "RG3", "schema": 1, "brief": "周末盘账与客源（肉鸽 v1）：哪几天盘账、生意做够几笔给几样、哪几格出什么、钳子。"},
  "_doc": [
    "week_days: stage days whose settle runs the stocktake; week = day / 7 - 1.",
    "offers_full if this week's deals >= deals_needed, else offers_few.",
    "slot_kinds: kind wanted for each slot; an empty pool falls back to the other kind.",
    "source_only_weeks: '<stage>:<week>' keys that offer sources only (1938 week 0: the peddler on day 8 introduces relics).",
    "clamp: product over active sources per pool / sum per deal type."
  ],
  "enabled": true,
  "week_days": [7, 14, 21, 28],
  "deals_needed": 2,
  "offers_full": 3,
  "offers_few": 2,
  "slot_kinds": ["relic", "source", "relic"],
  "source_only_weeks": ["0:0"],
  "clamp": {"pool_min": 50, "pool_max": 250, "deal_count_min": 0, "deal_count_max": 1}
}
```

`data/cards/rules/legacy.json`

```json
{
  "_meta": {"owner": "RG3", "schema": 1, "brief": "旧账（肉鸽 v1）：可选的开头与解锁门槛、铺史行按本心分档的门槛。"},
  "_doc": [
    "openings: veteran openings skip the tutorial cards of days 1-3 (their schedule.when) and those days are dealt normally.",
    "unlock_closed: closed ledgers needed before the title offers this opening (shell rule).",
    "chronicle.kind_at / hard_at: conscience thresholds for the ending chronicle line (engine only, never shown)."
  ],
  "openings": {
    "og.default": {"veteran": false, "notice": "", "unlock_closed": 0, "order": 0},
    "og.shanghai": {"veteran": true, "notice": "rg5.notice.shanghai", "unlock_closed": 1, "order": 10}
  },
  "chronicle": {"kind_at": 20, "hard_at": -20}
}
```

模块读规则一律带默认值（`ctx.rules("relics").get("cap", 6)` 这种），**文件不存在时模块视为没启用**。`ctx.rules()` 返回的字典不是副本（`card_ctx.gd:53-54`），只读、不许改。

### 6.4 十二件老物件（`data/cards/era/common/relics.json` 的 `cards`）

> 每件都核对过：用到的 kind、op、条件都存在（§4.5 的调用点；op 见 `dsl_shapes.gd:11-15`（`rep` `heat` `if` `demand_tier`），条件见 `dsl_shapes.gd:26-36`）；品类在 `data/town/item_templates.json` + `items/templates_extra.json`（`art clothing documents jewelry medicine rice utensils goldbar papers silver silverware`）；人脉 id `chen` `ma` 在 `common/contacts.json`；旗标 `pet_home` `pet_lost` 由 G03 的猫写；家当 `es.old_house`；`demand_rules.issue_weekday` 是 0（星期一）；带 `official` 标签的格子有 13 个；人物标签 `poor` 存在。

```json
{
  "_meta": {"owner": "RG3", "schema": 1, "brief": "老物件 12 件（肉鸽 v1）：寻常 5、有来历 5、镇店 2。效果只用现有修正项和效果 op。"},
  "cards": [
    {"id": "rl.cat_bowl", "type": "relic", "era": ["*"], "weight": 10, "depth": "plain",
     "conditions": {"any": [{"flag": "pet_home"}, {"flag": "pet_lost"}]},
     "mods": [
       {"mod": "appraise_pct", "pct": 110, "when": {"all": [{"flag": "pet_home"}, {"not": {"flag": "pet_lost"}}]}},
       {"mod": "patience_pct", "pct": 90, "flaw": true, "when": {"flag": "pet_lost"}}
     ],
     "art": "prop.relic.cat_bowl",
     "brief": "豁口的青花猫碗。留过猫以后才会摆出来。猫在店里：所有品类鉴定观察清楚一点（appraise 110）。猫走丢了：客人耐心少一点（patience 90，毛病）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.stub_box", "type": "relic", "era": ["*"], "weight": 10, "depth": "plain",
     "mods": [
       {"mod": "kept_cap", "delta": 1},
       {"mod": "shelf_cap", "delta": -1, "flaw": true}
     ],
     "art": "prop.relic.stub_box",
     "brief": "当票存根匣：多留一张牌（kept_cap +1）；匣子占地方，货架少一格（shelf_cap -1，毛病）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.blue_curtain", "type": "relic", "era": ["*"], "weight": 10, "depth": "plain",
     "mods": [
       {"mod": "patience_pct", "pct": 115},
       {"mod": "pool_weight", "pool": "person", "intents": ["buy"], "pct": 85, "flaw": true}
     ],
     "art": "prop.relic.blue_curtain",
     "brief": "蓝布棉门帘：客人进门暖和，肯多等（patience 115）；过路的买家少看见货（来买的人 pool 85，毛病）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.oilpaper_umbrella", "type": "relic", "era": ["*"], "weight": 10, "depth": "plain",
     "mods": [
       {"mod": "deal_count", "type": "person", "delta": 1, "when": {"weather": "rain"}}
     ],
     "art": "prop.relic.oilpaper_umbrella",
     "brief": "客人落下的油纸伞：下雨天多一位客人进门（deal_count person +1，抵掉 G05 的雨天少一位）。没有毛病。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.old_almanac", "type": "relic", "era": ["*"], "weight": 10, "depth": "plain",
     "mods": [
       {"mod": "price_pct", "direction": "pay", "pct": 96, "when": {"almanac_yi": "pawn_in"}},
       {"mod": "price_pct", "direction": "receive", "pct": 104, "when": {"almanac_yi": "sell_out"}}
     ],
     "art": "prop.relic.old_almanac",
     "brief": "祖父批过的老黄历：宜收当的日子三档价压低一点（pay 96），宜出货的日子卖价硬一点（receive 104）。没有毛病。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.chen_mortar", "type": "relic", "era": ["*"], "weight": 6, "depth": "storied",
     "mods": [
       {"mod": "appraise_pct", "cats": ["medicine"], "pct": 125},
       {"mod": "price_pct", "direction": "pay", "cats": ["medicine"], "pct": 95},
       {"mod": "appraise_pct", "cats": ["art"], "pct": 120, "when": {"has_contact": "chen"}},
       {"mod": "pool_weight", "pool": "event", "tags_any": ["search"], "pct": 115, "flaw": true}
     ],
     "art": "prop.relic.chen_mortar",
     "brief": "济生堂的铜药碾（陈家老先生抵在这儿没赎）：药材鉴定清楚得多（125）、收药材三档价低一点（pay 95）；陈文庭是人脉时书画也看得清（120）。毛病：查铺的事多一点（event search 115）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.hu2_pipe", "type": "relic", "era": ["*"], "weight": 6, "depth": "storied",
     "mods": [],
     "passives": [
       {"hook": "day_start", "effects": [
         {"op": "if", "cond": {"all": [{"weekday": 0}, {"not": {"has_contact": "ma"}}]},
          "then": [{"op": "demand_tier", "delta": -1}]}]}
     ],
     "downsides": [
       {"hook": "day_start", "effects": [
         {"op": "if", "cond": {"all": [{"weekday": 0}, {"not": {"has_contact": "ma"}}]},
          "then": [{"op": "rep", "delta": -2}]}]}
     ],
     "art": "prop.relic.hu2_pipe",
     "brief": "胡二落下的旱烟袋：每周一胡二来发条子前（day_start 25 早于 G03 发条子 30），这张条子降一档（demand_tier -1）；街坊看见你跟他走得近，口碑掉一点（rep -2，毛病）。马万利是人脉时两样都不灵（两个降档会把条子玩没）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.camphor_chest", "type": "relic", "era": ["*"], "weight": 6, "depth": "storied",
     "mods": [
       {"mod": "kept_cap", "delta": 1, "when": {"estate_status": ["es.old_house", "held"]}},
       {"mod": "shelf_cap", "delta": 2, "when": {"estate_status": ["es.old_house", "held"]}}
     ],
     "art": "prop.relic.camphor_chest",
     "brief": "老宅的樟木箱：多留一张牌、货架多两格；老宅押出去或丢了就搬不出来，两样都不灵（这就是它的毛病）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.master_steelyard", "type": "relic", "era": ["*"], "weight": 6, "depth": "storied",
     "mods": [
       {"mod": "appraise_pct", "cats": ["jewelry", "silver", "silverware", "goldbar", "medicine"], "pct": 120},
       {"mod": "patience_pct", "pct": 92, "flaw": true}
     ],
     "art": "prop.relic.master_steelyard",
     "brief": "师父的老戥子：金银首饰药材称得准，鉴定清楚一些（120）；太较真，客人嫌你磨蹭（patience 92，毛病）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.sun_inkpad", "type": "relic", "era": ["*"], "weight": 6, "depth": "storied",
     "mods": [
       {"mod": "coins", "source_kind": "self", "slot_tags_any": ["official"], "delta": 1},
       {"mod": "pool_weight", "pool": "event", "tags_any": ["official"], "pct": 115, "flaw": true}
     ],
     "art": "prop.relic.sun_inkpad",
     "brief": "孙府的朱砂印泥盒：你本人站进官面上的格子多一枚铜钱（coins +1，铜钱数本来就看得见）；官面上的事找上门多一点（event official 115，毛病）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.rosewood_abacus", "type": "relic", "era": ["*"], "weight": 3, "depth": "treasure",
     "conditions": {"stage_gte": 1},
     "mods": [
       {"mod": "price_pct", "direction": "pay", "pct": 95},
       {"mod": "price_pct", "direction": "receive", "pct": 105},
       {"mod": "pool_weight", "pool": "person", "tags_any": ["poor"], "pct": 60, "flaw": true}
     ],
     "art": "prop.relic.rosewood_abacus",
     "brief": "祖父的紫檀算盘（镇店的，第 2 关起才摆出来）：进出的账都往铺子偏（pay 95 / receive 105）；精明出了名，穷人家少来很多（person poor 60，毛病）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},

    {"id": "rl.old_signboard", "type": "relic", "era": ["*"], "weight": 3, "depth": "treasure",
     "conditions": {"stage_gte": 1},
     "mods": [
       {"mod": "price_pct", "direction": "receive", "pct": 110}
     ],
     "passives": [
       {"hook": "settle", "effects": [{"op": "if", "cond": {"market_day": true}, "then": [{"op": "rep", "delta": 1}]}]}
     ],
     "downsides": [
       {"hook": "settle", "effects": [{"op": "heat", "delta": 1}]}
     ],
     "art": "prop.relic.old_signboard",
     "brief": "老匾“德厚”的木心（镇店的，第 2 关起）：来买的人肯多出（receive 110）；集市日口碑涨一点（rep +1）。毛病：太招眼，风声不会自己落下去（每晚 heat +1，正好抵掉每日回落 1）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}}
  ]
}
```

货郎二选一的池子（`depth == "plain"` 且条件为真）：第 8 天还没有猫 → `rl.stub_box` `rl.blue_curtain` `rl.oilpaper_umbrella` `rl.old_almanac` 四选二。

### 6.5 六种客源（`data/cards/era/common/sources.json`）

```json
{
  "_meta": {"owner": "RG3", "schema": 1, "brief": "客源 6 种（肉鸽 v1）：周末盘账时挑，管到这一关月底，改门口来的人。只用 pool_weight 与 deal_count。"},
  "cards": [
    {"id": "ky.traveling_buyers", "type": "source", "era": ["*"], "weight": 10,
     "mods": [
       {"mod": "pool_weight", "pool": "person", "intents": ["buy"], "pct": 180},
       {"mod": "pool_weight", "pool": "person", "intents": ["ask"], "pct": 80}
     ],
     "art": "illus.ky.traveling_buyers",
     "brief": "跑单帮的买主：来买东西的多（buy 180），光打听不办事的少一点（ask 80）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},
    {"id": "ky.needy_neighbors", "type": "source", "era": ["*"], "weight": 10,
     "mods": [
       {"mod": "pool_weight", "pool": "person", "intents": ["pawn"], "pct": 170},
       {"mod": "pool_weight", "pool": "person", "intents": ["help"], "pct": 130}
     ],
     "art": "illus.ky.needy_neighbors",
     "brief": "急等钱用的街坊：来当东西的多（pawn 170），求帮忙的也多（help 130）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},
    {"id": "ky.junk_runners", "type": "source", "era": ["*"], "weight": 10,
     "mods": [
       {"mod": "pool_weight", "pool": "person", "intents": ["sell"], "pct": 170},
       {"mod": "pool_weight", "pool": "event", "tags_any": ["police", "search"], "pct": 115}
     ],
     "art": "illus.ky.junk_runners",
     "brief": "收旧货的门路：来卖东西给你的多（sell 170）；来路杂，查铺、巡警的事多一点（event 115）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},
    {"id": "ky.old_customers", "type": "source", "era": ["*"], "weight": 10,
     "mods": [
       {"mod": "pool_weight", "pool": "person", "intents": ["redeem"], "pct": 170},
       {"mod": "deal_count", "type": "person", "delta": 1, "when": {"market_day": true}}
     ],
     "art": "illus.ky.old_customers",
     "brief": "老主顾：来赎当的多（redeem 170），集市日多一位客人（deal_count +1）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},
    {"id": "ky.dockhands", "type": "source", "era": ["*"], "weight": 10,
     "mods": [
       {"mod": "pool_weight", "pool": "person", "tags_any": ["dock", "boat", "merchant"], "pct": 200},
       {"mod": "pool_weight", "pool": "news", "tags_any": ["omen_water"], "pct": 150}
     ],
     "art": "illus.ky.dockhands",
     "brief": "码头上的人：脚夫船家行商常来（person dock/boat/merchant 200），水边的消息多（news omen_water 150）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}},
    {"id": "ky.big_households", "type": "source", "era": ["*"], "weight": 10,
     "mods": [
       {"mod": "pool_weight", "pool": "person", "tags_any": ["landlord", "steward", "sunfu"], "pct": 180},
       {"mod": "pool_weight", "pool": "event", "tags_any": ["official"], "pct": 120}
     ],
     "art": "illus.ky.big_households",
     "brief": "大户人家的管事：地主、管家、孙府的人常来（person 180）；官面上的事也跟着多（event official 120）。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}}
  ]
}
```

（人物来意分布见 `scripts/tests` 外的统计：三关都有 `buy` `pawn` `sell` `redeem` `ask` `help`；标签 `dock` `boat` `merchant` `landlord` `steward` `sunfu` `police` `search` `official` `omen_water` 都已登记。）

### 6.6 货郎头一回（`data/cards/era/1938/curio_peddler.json`）

```json
{
  "_meta": {"owner": "RG3", "schema": 1, "brief": "肉鸽 v1：1938 第 8 天货郎头一回上门，二选一老物件，兼引子。复用已登记的过路客 stranger_peddler。"},
  "cards": [
    {"id": "p.stranger_peddler.1938.curios", "type": "person", "person": "stranger_peddler",
     "era": ["1938"], "weight": 0, "tags": ["peddler", "omen_wealth"], "intent": "story",
     "schedule": {"stage_day": 8, "order": 50},
     "choices": [
       {"id": "look", "effects": [{"op": "stock_offer", "n": 2, "kinds": ["relic"], "depths": ["plain"], "from": "peddler"}],
        "brief": "看看担子里的：摊开两样旧东西，挑一样摆上博古格"},
       {"id": "send_off", "effects": [], "brief": "不看了，送他出门"}
     ],
     "art": "portrait.stranger_peddler",
     "brief": "挑担收旧货也卖旧货的货郎，说铺子新换了掌柜，担子里有两样当年从德厚当收走的老东西，拿回来镇店。看了就开盘账叠层（只出寻常家什，二选一，白给）；不看就走。没理他，打烊时他挑担走了，没有别的后果。",
     "_provenance": {"by": "ai", "task": "RG3", "date": "2026-10-25"}}
  ]
}
```

### 6.7 正文（AI 基础层；RG3 写）

| 对象 | 必有字段 | 可选 |
|---|---|---|
| 每件 `rl.*` | `title`（物件名）`body`（来历 2–4 句：谁的、哪年、怎么留在德厚当）`use`（好处，一句铺子里看得见的变化）`lines.gain`（摆上格子那一刻） | `lines.flaw`（**有任一 `flaw: true` 行或 `downsides` 时必有**） |
| 每种 `ky.*` | `title` `body`（2–3 句：是些什么人）`use` `lines.gain` | `lines.flaw`（有第二行“副作用”时写） |
| `p.stranger_peddler.1938.curios` | `title` `body` `lines.greet` `choices.look` `choices.send_off` | `outcomes.ignored` |

措辞规矩（RG3 的测试查，K13 审读）：

- **不出现阿拉伯数字、`%`、“倍”“成”“几分”**；不写机制名（不写“耐心”“鉴定”“权重”“档位”“修正”“概率”）；禁用词：加成、触发、冷却、属性、稀有、传说、史诗、遗物、装备、BUFF。
- 量词表：效果小写“一点 / 稍微”，中等写“不少 / 明显”，大写“多得多”。看得见的计数可以直说“一张牌”“两格”“一位客人”“一枚铜钱”。
- 好处 / 毛病写铺子里看得见的变化：“客人肯多等一会儿”“药材一比就知道成色”“查铺的人进门先看它”“条子来时松一档”。
- 时局措辞照 `era.json` 的 notes（伪、沦陷，不写血腥）。

样稿（RG3 可改字，不可改意思）：

| id | title | use | lines.flaw |
|---|---|---|---|
| `rl.cat_bowl` | 豁口的青花猫碗 | 猫蹲在柜上陪着，你看东西时眼神定一些。 | 猫要是走丢了，碗空着，你总往门口看，客人也等不了多久。 |
| `rl.stub_box` | 当票存根匣 | 要紧的单据有地方压着，能多留下一张牌。 | 匣子占了货架一角。 |
| `rl.blue_curtain` | 蓝布棉门帘 | 客人进门暖和，肯多等一会儿。 | 帘子挡着，过路的买家少看见货。 |
| `rl.oilpaper_umbrella` | 客人落下的油纸伞 | 下雨天门口借伞的人多，总有一位顺脚进来。 | — |
| `rl.old_almanac` | 祖父批过的老黄历 | 照着黄历上的“宜”办事，进出的价都顺手一点。 | — |
| `rl.chen_mortar` | 济生堂的铜药碾 | 药材放在碾子边一比，成色一眼就看出来，收药材也压得住价；陈文庭在，书画也看得清些。 | 药碾摆在明处，查药材的人进门先看它。 |
| `rl.hu2_pipe` | 胡二落下的旱烟袋 | 胡二瞥见烟袋，这一周的条子松一档。 | 街坊看见你跟他走得近，背后有话。马万利在跟前时，这烟袋就不顶用了。 |
| `rl.camphor_chest` | 老宅的樟木箱 | 箱子搬到铺里，多留一张牌，货架也宽出两格。 | 老宅一押出去，箱子就搬不出来了。 |
| `rl.master_steelyard` | 师父的老戥子 | 金银首饰药材，戥子一称就有数。 | 太较真，客人嫌你磨蹭。 |
| `rl.sun_inkpad` | 孙府的朱砂印泥盒 | 你自己出面办官面上的事，手里多一分底气。 | 官面上的事找上门的也多了。 |
| `rl.rosewood_abacus` | 祖父的紫檀算盘 | 算珠一响，进出的账都往铺子这边偏。 | 精明出了名，穷人家宁可多走两条街。 |
| `rl.old_signboard` | 老匾“德厚”的木心 | 来买的人肯多出；赶集的日子，街上都在说德厚当。 | 太招眼，风声一直落不下去。 |

客源样稿：`ky.traveling_buyers` 跑单帮的买主 / `ky.needy_neighbors` 急等钱用的街坊 / `ky.junk_runners` 收旧货的门路 / `ky.old_customers` 老主顾 / `ky.dockhands` 码头上的人 / `ky.big_households` 大户人家的管事。

### 6.8 为什么这些数据能过校验（RG3 自查清单）

- 校验器 V03 按 `_schema/<type>.json` 查字段（步骤 0 提供 `relic` `source` 两个 schema）。
- V02 前缀：`CardIds.TYPE_PREFIX` 步骤 0 加了 `relic → rl`、`source → ky`。
- V10：`conditions` `passives` `downsides` `choices.*.effects` `schedule.when` 都按 `CardDslShapes` 查；`stock_offer` 与 `veteran` 步骤 0 已登记形状。`mods` 校验器不看，RG1 的测试看。
- V12（strict 报错）：每个 `art` 必须在 `manifest.json` 里 → RG3 同一提交加清单。
- V26：正文条目必须对得上牌或界面键，字段必须被允许：步骤 0 在 `TEXT_REQUIRED` 加了 `"relic": ["title", "body", "use"]`、`"source": ["title", "body", "use"]`；`lines.*` 总是允许（`card_validator.gd:1049-1059`）。
- V16 可达：货郎牌 `weight 0` 有 `schedule`，可达。`relic`/`source` 不在 `DEALT`，不查。
- V34 人物牌要有 `omen_*` 标签：有 `omen_wealth`。V09 标签都已登记（`peddler` 已被 `p.stranger_peddler.any.sell_bowl` 用）。

---

## 7. 界面

### 7.1 面板 kind 与参数（步骤 0 已登记 `PANEL_SCENES` / `PANELS` / `PANEL_SHOW`）

| kind | 呈现 | 场景 / 脚本（RG4） | `open(args)` | 谁开 |
|---|---|---|---|---|
| `stocktake` | `overlay` | `scenes/cards/rogue/StocktakePanel.tscn` / `scripts/cards/ui/rogue/stocktake_panel.gd` | `{"offer": String}`（可缺：取最近一份 open） | 引擎 `request_panel`（根的 `_sync_phase_panel` 按 `view.open_panel` 自动开，每块每天一次，`card_game_root.gd:456-490`）；抽屉里“还有一份没挑的”按钮 |
| `relics` | `drawer_r` | `scenes/cards/rogue/RelicsDrawer.tscn` / `scripts/cards/ui/rogue/relics_drawer.gd` | `{}` | 场景热点 `curio`（步骤 0 的 `HOTSPOT_PANELS`，根 `_on_hotspot` 通用路由 `card_game_root.gd:813-832`） |

两块面板都 `extends CardPanel`（`ui/common/card_panel.gd`）：Esc / “合上” / 点遮罩只关（`dismiss()` 默认行为），关掉**不发任何指令**。抽屉标题键 `rg4.drawer.relics`（步骤 0 在 `modal_host.gd` 的 `DRAWER_TITLES` 加了）。

**W0 冒烟测试会用 `day_full` 夹具实例化每个面板并 `open({"uid": "c0002"})`**（`scripts/tests/cards/W0/test_skeleton.gd:265-290`）：两块面板在视图没有 `relics`/`stock`、查询返回 `not_implemented` 时必须安静地显示空状态，不许 `push_error`、不许打印 WARNING。

### 7.2 盘账叠层 `stocktake`（叠层范围 `CardLayout.OVERLAY_MAX` = (90, 40, 1100, 640)）

```
(90,40) ┌───────────────────────────── 1100 × 640 ──────────────────────────────┐
        │ 第2周盘账                      (130,60, 1020×36, 标题字 26, gold_hi)      │
        │ 这周做成了 3 笔生意。           (130,100, 1020×24, 16, hud_ink)            │
        │ [生意做得少，只翻出两样。]       （只在 items == 2 且 from == week 时）      │
        │  ┌──── 288×400 ────┐ ┌──── 288×400 ────┐ ┌──── 288×400 ────┐  y 140–540 │
        │  │有来历的   (朱漆框)│ │客源      (翠框)  │ │寻常家什  (木框)  │            │
        │  │   ┌────────┐    │ │  ┌──────────┐   │ │   ┌────────┐    │ 物件 32×32×4│
        │  │   │ 128px  │    │ │  │ 128×96   │   │ │   │        │    │ 客源 64×48×2│
        │  │   └────────┘    │ │  └──────────┘   │ │   └────────┘    │            │
        │  │ 济生堂的铜药碾    │ │ 码头上的人        │ │ 蓝布棉门帘        │ title 20   │
        │  │ 来历两三行……     │ │ 是些什么人……      │ │ ……               │ body ≤4 行 │
        │  │ 好处 一句        │ │ 好处 一句         │ │ 好处 一句        │            │
        │  │ 毛病 一句        │ │ 管到这个月底       │ │ 毛病 一句        │            │
        │  │  [ 就要这件 ]    │ │  [ 就请这拨人 ]   │ │  [ 就要这件 ]    │ y+356, 36高│
        │  └─────────────────┘ └─────────────────┘ └─────────────────┘            │
        │            [ 都不要 ] (400,556, 200×44)     [ 回头再说 ] (680,556, 200×44)  │
        └──────────────────────────────────────────────────────────────────────────┘
```

- 三张卡 x0 = 176（n=3）或 336（n=2），间距 32，y = 140。卡内纵向：深浅标签 10–30（`rg4.depth.<d>` 或 `rg4.kind.source`），图 36–164，名 172–196，来历 200–276（16px，最多 4 行，超出省略），好处 280–318（小标签 `rg4.stock.use` + `use` 正文），毛病 320–352（`rg4.stock.flaw` + `lines.flaw`，`CardText.has_text` 为假就不画；客源画 `rg4.stock.source_until`），按钮 356–392。
- 框色用现有配色键（不新加）：`plain` → `wood`，`storied` → `seal`，`treasure` → `frame_gold`，客源 → `jade`；纸面 `paper`，字 `ink`。来历深浅只有“框 + 两三个字”，**没有任何星级、数字、百分号**。
- 标题：`from == "week"` → `rg4.stock.title.week {n: week+1}`；`from == "peddler"` → `rg4.stock.title.peddler`，副行 `rg4.stock.peddler_sub`，不显示成交笔数。
- 按钮：物件卡 `就要这件` → `stock.pick {offer, pick: id}`（若 `full` → 先进“让出一件”）；客源卡 `就请这拨人` → `stock.pick {offer, pick: id}`；`都不要` → `stock.pick {offer, pick: ""}`；`回头再说` → 只关。成功后关；失败（如 `already_resolved`）显示 `rg2.reason.offer_closed` 一行并关。
- **满了：让出一件**（`full == true` 且挑的是物件）：底部 y 552–672 换成：提示 `rg4.stock.full`（130, 552, 1020×24）；一排已持有物件 64×64（×2），x0 = 418，间距 12，y 580；`让出它，摆上新的`（900, 588, 220×40）→ `stock.pick {offer, pick, replace}`；`那就不要了`（900, 632, 220×36）→ 回到三张卡。
- `refresh(view)`：重新问 `stocktake`；`status != "open"` → 自己关掉（玩家在叠层开着时按了打烊、或第二天作废）。
- 键盘：`1`–`3` 选卡（金边），Enter = 选中那张的主按钮，Esc = 关；让出那一步 `1`–`6` 选、Enter 确认、Esc 回退。
- `autoplay_step()`：`status == "open"` → 挑 `items[0]`（物件且满 → `replace = held[0].id`），发指令，返回 `true`；否则返回 `false`。同一状态永远做同样的事。
- 锚点：三张卡所在的行注册 `a.stock.offers`。

### 7.3 博古格抽屉 `relics`（右抽屉内容区 `drawer_host.content_rect("r")`）

- 顶行：`rg4.relics.count {n, cap}`（“摆了 n 件，一共 cap 格”，计数可见）；`dormant` 时下面一行 `rg4.relics.dormant`，所有行压暗（`ink_soft`）。
- 每件一行 400×96：物件图 ×2（64）、名、深浅词、`use` 一行、`lines.flaw` 一行（有才画）。没有物件 → `rg4.relics.empty`。
- 分隔后一节 `rg4.relics.sources`：每种生效客源一行（名 + `use` + `rg4.stock.source_until`）；没有 → `rg4.relics.sources_empty`。
- `view.stock.open != ""` → 顶部一个按钮 `rg4.relics.pending` → `close_requested.emit({"next": {"kind": "stocktake", "args": {"offer": open}}})`（根的 `_on_follow_up` 会开它，`card_game_root.gd:751-757`）。
- 锚点 `a.relics.list`。视图里没有 `relics`/`stock` 键时（例子集、Mock 的 `day_full`）显示空状态。

### 7.4 场景里的博古格（`scripts/cards/ui/table/card_stage.gd`，RG4）

- 热点按钮由 `CardIds.HOTSPOTS` 自动建（`card_stage.gd:227-247`），贴图自动取 `"prop." + id` = `prop.curio`（`card_stage.gd:468`），街头 / 牢里自动隐藏，锚点 `a.scene.curio` 自动注册（`card_stage.gd:485-487`）。**RG4 在 `card_stage.gd` 里只加三处**：`_build()` 热点循环之后挂一个 `CurioShelf`（新文件 `scripts/cards/ui/rogue/curio_shelf.gd`，`mouse_filter = IGNORE`，点击照样落到热点）；`refresh(view)` 里 `_curio.refresh(view, <curio 热点可见>, fast)`；`clear_play()` 不动它。
- `CurioShelf`：`view.relics.held` 前 6 件按顺序画在 `CardLayout.curio_cell(i)`（64×64，贴图 `CardArt.texture(art)`，最近邻）；`dormant` → `modulate = CardTheme.color(&"ink_soft")`；夜里（`view.stage.time == "night"`）→ `night_tint`；新出现的一格闪一下 `gold`（0.3 秒，`fast` 时不闪）。
- 不加悬停文字（热点已有发光）。

### 7.5 标题（`scripts/cards/ui/shell/card_title.gd`，RG4；数据与动作由 RG5 的外壳给）

在现有标题上加一个右下角的盒子 `RunBox`（新文件 `scripts/cards/ui/rogue/title_run_box.gd`，`card_title.gd` 只负责建它、转发），矩形 (744, 400, 456, 280)，底色 `scene_void` 0.72 透明。**`set_rogue()` 没被调用时整个盒子不显示**（Mock、测试、自动玩时标题和今天一模一样）。

```
(744,400) ┌──────────────── 456 × 280 ────────────────┐
          │ 这是第3本账                (16, 12) 16px    │
          │ 种子 [ 1844671223    ] [换一个]  y 44        │  LineEdit 180×32，SmallButton
          │ 开头 [哥哥的铺子] [上海学过徒]    y 88        │  只在 ≥2 个开头已解锁时显示
          │ 旧账                              y 132       │
          │ ▌▌▌▌▌  一本一根书脊 24×100，间距 4，最多 16 根 │  y 156–256，最新的在右
          │ 第2本 · 腊月第17天被带走，没能出来过年。 y 262  │  悬停/聚焦书脊才显示
          └────────────────────────────────────────────┘
```

**公开接口（冻结；RG5 照这个调）**

```gdscript
## data:
##   "run_no": int                          # 按“开张”会开的第几本（profile.next_no()）
##   "seed": int                            # 种子框里预填的值
##   "openings": [{"id": "og.default", "unlocked": true}, {"id": "og.shanghai", "unlocked": false}]
##   "opening": "og.default"                # 当前选中
##   "shelf": [{"no": 1, "key": "rg5.chronicle.prison.1939", "args": {"d": 17}, "reason": "prison", "opening": "og.default"}]  # 旧→新
##   "notice_key": ""                       # 非空时盒子顶上显示一次（如 rg5.toast.profile_reset）
func set_rogue(data: Dictionary) -> void
func seed_text() -> String          # 种子框原文；盒子没显示时 ""
func opening_id() -> String         # 选中的开头；盒子没显示时 "og.default"
```

- `chose` 信号（冻结签名）多两个动作值：`&"reseed"`（按“换一个”）、`&"opening"`（换了开头）。原来的四个动作和 `ACTIONS` 常量不动。
- 开头按钮的字：`rg5.opening.<id 去掉 "og.">`（`rg5.opening.default` / `rg5.opening.shanghai`）。书脊颜色：`ending` → `gold`，`prison` → `seal`，`abandoned`/其它 → `wood`；书脊上竖排 `rg4.title.book_no {n}`；悬停 / 聚焦显示 `rg4.title.book_no {n}` + ` · ` + `CardText.ui(key, args)`。
- **键盘**（C16 的测试锁着：标题焦点从“new”开始、上下左右只在四颗按钮里绕、Tab 不跑出标题）：种子框不进四颗按钮的环；**焦点在种子框时**，`_handle_key` 只处理 Enter（= `chose(&"new")`）和 Esc（交还焦点给 `new`），其余键全部交给 LineEdit（否则 W/A/S/D、空格会被标题吃掉）。书脊、开头按钮只用鼠标（v1）。
- 所有字来自 `CardText`（`t.all_text_from_cardtext` 只查 Label/Button/RichTextLabel；种子数字是纯数字，规则允许）。

### 7.6 档案簿旧墨（`scripts/cards/ui/dossier/dossier_book.gd`，RG5）

- `_read_pages()`：问完 `dossier` 后再问 `legacy.old_ink`（Mock 返回 `not_implemented` → 当作没有）；把旧墨碎片并进同一个人的页（`state: "old"`，已有同 id 的不并）；只有旧墨的人加一页（`complete: false, new: 0, old_only: true`），索引格子名字压暗。
- `_add_frag()`：接受 `state == "old"`：走 `_fill_have` 的画法，整行 `modulate = CardTheme.with_alpha(&"ink_soft", 0.6)`，右上角一个小标签 `rg5.dossier.old_ink`；页底（有旧墨时）一行 `rg5.dossier.old_ink_hint`。
- 淡墨**不算数**：引擎的补齐、`dossier_has` 条件只认这一本拿到的（引擎本来就只看 `have`，不用改）。C10 现有测试必须照绿。

---

## 8. 外壳与档案文件（RG5）

### 8.1 文件与职责

| 文件 | 内容 |
|---|---|
| `scripts/cards/meta/card_profile.gd`（`class_name CardProfile`） | 档案文件读写、并账、合账、编本局上下文、标题数据。纯数据，不依赖引擎 |
| `scripts/cards/meta/run_keeper.gd`（无 `class_name`，`extends Node`） | 根场景里的一个节点：听总线（`saved` `game_over` `command_done`），在开局 / 标题时和 `CardProfile` 打交道 |
| `scripts/cards/ui/table/card_game_root.gd`（只加约 15 行） | 建 keeper；`_show_title` 后 `keeper.on_title(title)`；`_start` 用 `keeper.new_game_options(title)`，成功后 `keeper.after_new_game()`；`_on_title` 多两个动作 `reseed` `opening` 交给 keeper |

**keeper 只在交互式路径上启用**：`engine is CardEngine` 且没有 `skip_title`、没有 `autoplay`、没有 `fixture`。否则 `_start()` 的行为一字不改（`{"seed": int(_opts.get("seed", 7))}`）——自动玩、命令行、所有 Mock 测试照旧可复现。

### 8.2 `profile.json`（路径 `CardSave.root() + "/profile.json"`；测试在 `user://test/<名字>/`）

```json
{
  "format": "dehoudang-cards-profile", "v": 1, "salt": 0,
  "runs_started": 3,
  "current": {"no": 3, "seed": 1844671223, "status": "open", "opening": "og.default",
              "last": {"stage": 1, "era": "1939", "stage_day": 12}},
  "reroll": 0,
  "frags": {"df.brother.1938.farewell": 1, "df.linsao.1938.husband": 2},
  "guide_done": ["gd.d1.deal", "gd.d1.person"],
  "chronicle": [
    {"no": 1, "seed": 7, "opening": "og.default", "reason": "prison", "key": "rg5.chronicle.prison.1939",
     "args": {"d": 17}, "stage": 1, "stage_day": 17},
    {"no": 2, "seed": 99117, "opening": "og.default", "reason": "ending", "key": "rg5.chronicle.ending.plain",
     "args": {}, "stage": 2, "stage_day": 30}
  ]
}
```

- 只有集合和“第几本第一次见到”，**没有可以攒的数**。`absorb` 是并集（同一收获并两次 = 并一次，先后无关）。
- 写法照 `CardSave.write`：全精度 JSON、先写 `.tmp` 再改名。读坏了 → 改名 `profile.broken.json`，新建一份，标题提示 `rg5.toast.profile_reset`，**不挡开张**。`v` 比自己新 → 不改名、不覆盖，这次只在内存里用一份新档（不写盘），标题同样提示 `rg5.toast.profile_reset`。
- 第一次带旧账功能启动、档案不存在但 `suspend.json` 存在 → 认作第一本：`runs_started = 1, current = {no: 1, seed: 7, status: "open", opening: "og.default"}`。

### 8.3 `CardProfile` API

```gdscript
const FORMAT := "dehoudang-cards-profile"
const VERSION := 1
var data: Dictionary
var was_reset: bool
static func path_in(dir: String) -> String
static func load_or_new(dir: String, suspend_exists: bool) -> CardProfile
func save() -> bool
func next_no() -> int                                    # runs_started + 1
func suggest_seed() -> int                               # CardRunSeed.derive(salt, next_no(), reroll)
func reroll_seed() -> int                                # reroll += 1；返回 suggest_seed()
func closed_count() -> int                               # chronicle.size()
func openings(db: CardDB) -> Array                       # [{id, unlocked}]，按 order；unlocked = closed_count() >= unlock_closed
func run_context(db: CardDB, opening: String) -> Dictionary   # {"no": next_no(), "opening", "known": frags 的键里 db 里存在的 dossier_fragment，排序}
func begin_run(seed_value: int, opening: String) -> void # runs_started += 1；current = {no, seed, status:"open", opening, last:{}}；reroll = 0
func absorb(harvest: Dictionary) -> void                 # frags 并集（记第一次的本号）；current.last = {stage, era, stage_day}
func close_run(harvest: Dictionary, reason: String) -> void   # 先 absorb；chronicle 按 no upsert（同一本再合上就替换那一条）；current.status = "closed"
func close_abandoned() -> void                           # 引擎里已没有这本的状态时：用 current.last 拼 rg5.chronicle.abandoned.<era>
func reopen() -> void                                    # current.status = "open"（重来本关 / 续玩以后）
func note_guide(progress: Dictionary) -> void            # guide_progress 查询结果里 status == "done" 的步骤并进 guide_done
func title_data(db: CardDB, forced_seed: int, opening: String) -> Dictionary   # §7.5 的 data；forced_seed > 0 时预填它
```

### 8.4 一本账的一生（keeper）

```
标题出现           → title.set_rogue(profile.title_data(db, opts.seed 或 -1, 选中的开头))
按“换一个”        → profile.reroll_seed()；save；刷新标题
换开头            → 记下；刷新标题
按“开张”          → ① 若 current.status == "open"：
                         引擎还有状态（view().phase != "boot"）→ harvest {close:"abandoned"} → close_run
                         否则 → close_abandoned()
                      ② seed = opts.seed（若有）> CardRunSeed.parse(title.seed_text())（≥1）> suggest_seed()
                      ③ options = {seed, run: profile.run_context(db, opening)} + 原有 save_dir/only_examples/data_root
                   → engine.new_game(options)
                   → 成功：删掉旧的 suspend.json（新局到第一天早上才写续玩点；这之前留着的是上一本的）；
                           profile.begin_run(seed, opening)；save；
                           对 guide_done 里每一步 engine.send(&"ui.guide", {"step": s, "status": "done"})（ui.* 不进日志、不进哈希、不发 command_done）
bus.saved(ok)      → 延迟一帧：absorb(query legacy.harvest {})；note_guide(query guide_progress {})；save
bus.game_over(r)   → 延迟一帧：close_run(query legacy.harvest {close: r}, r)；save；飘字 rg5.toast.closed
bus.command_done("game.retry_stage" 或 "game.load", ok) 且 current.status == "closed" → reopen()；save
```

- 收获查询失败（Mock、旧状态）就跳过，不报错。
- `X01_continue` 锁着：续玩只发 `game.load`、不改 `suspend.json`、不改 `stage_00.json`——keeper 在续玩路径上**只读档案、只写 `profile.json`**。
- 解锁：`og.shanghai` 在合上第一本以后出现在标题上（`unlock_closed: 1`）。

---

## 9. CardIds / CardLayout / 其它常量（步骤 0 一次加完）

| 表 | 加什么 |
|---|---|
| `CardIds.TYPE_PREFIX` | `"relic": "rl"`, `"source": "ky"` |
| `CardIds.TYPES` | **不加**（理由见 §0） |
| `CardIds.COMMANDS` | `&"stock.pick": "RG2"` |
| `CardIds.QUERIES` | `&"relics": "RG1"`, `&"stocktake": "RG2"`, `&"legacy.harvest": "RG5"`, `&"legacy.old_ink": "RG5"` |
| `CardIds.MODS` | `&"unscripted_day"` |
| `CardIds.PANEL_SCENES` / `PANELS` / `PANEL_SHOW` | `stocktake` → `res://scenes/cards/rogue/StocktakePanel.tscn`，`overlay`；`relics` → `res://scenes/cards/rogue/RelicsDrawer.tscn`，`drawer_r` |
| `CardIds.HOTSPOTS` / `HOTSPOT_PANELS` | `&"curio"` / `&"curio": [&"relics", {}]` |
| `CardIds.ANCHORS` | `&"a.scene.curio": "RG4"`, `&"a.stock.offers": "RG4"`, `&"a.relics.list": "RG4"` |
| `CardIds.RNG_DOMAINS` | `["c.stock.offer", "RG2", false]`, `["m.run.seed", "RG2", false]`, `["m.run.seed_text", "RG2", false]` |
| `CardIds.FIRSTS` / `GUIDE_*` / `UI_EVENTS` / `HOOKS` | **不加** |
| `CardLayout` | `S_CURIO := Rect2i(237, 60, 52, 38)`；`CURIO := Rect2(948, 240, 208, 152)`；`CURIO_CELL := Vector2(64, 64)`；`S_HOTSPOTS`/`HOTSPOTS` 加 `curio`（同上两个矩形）；`static func curio_cell(i: int) -> Rect2` |
| `CardDslShapes` | `EFFECT_OPS[&"stock_offer"] = "RG2"`，`EFFECT_PARAMS[&"stock_offer"]`；`COND_OPS[&"veteran"] = "RG5"`，`COND_VALUES[&"veteran"] = "bool"` |
| `CardValidator.TEXT_REQUIRED` | `"relic": ["title", "body", "use"]`, `"source": ["title", "body", "use"]` |
| 各模块自己的常量 | `scripts/cards/relic/relic_ids.gd`、`scripts/cards/stock/stock_ids.gd`、`scripts/cards/legacy/legacy_ids.gd`（`card_ids.gd` 头注释：模块常量放自己的 `<模块>_ids.gd`） |

**博古格的位置**：场景格 (237, 60, 52, 38) → 屏幕 (948, 240, 208, 152)，在右墙护墙板上方。已核对不压：便条墙 (856,216,72,104) 右边界 928 < 948；油灯 (1168,272,…) 左边界 1168 > 1156；黄历 (1000,56,96,136) 下边界 192 < 240；预览按钮 (800,272,148,140) 右边界 948 = 博古格左边界（相接不重叠）；墙底 400 > 392。`companion` 站位与它重叠，但现有数据里没有一张牌用 `companion`（已 grep）；指引老师 `GUIDE_TEACHER` 叠在上层可以接受。六格：场景里每格 16×16（框左右各 2 px、上下各 3 px），屏幕上 64×64，物件 32×32 画 ×2 正好填满一格。

---

## 10. 步骤 0：契约骨架补丁（编排在开工前一次提交；之后这些文件 v1 里谁都不再改）

> 全部代码可直接照抄。提交前：`$GODOT --headless --path . --import`（生成新 `.gd.uid`，一起提交），然后 `CARDS_VALIDATE_MODE=strict tools/run_card_tests.sh` 全绿，`G06_golden` 不变。

### 10.1 `scripts/cards/api/card_ids.gd`

```gdscript
# TYPE_PREFIX 字典最后一行 "dossier_page": …, "guide_step": "gd", "rule_page": "rule", 之后加：
	"relic": "rl", "source": "ky",
# （TYPES 不改）

# COMMANDS 里 &"ui.guide": "G01", 之后加：
	&"stock.pick": "RG2",

# QUERIES 里 &"day.end_preview": "G02", 之后加：
	&"relics": "RG1", &"stocktake": "RG2", &"legacy.harvest": "RG5", &"legacy.old_ink": "RG5",

# MODS 末尾：
	&"view_section", &"card_view_part", &"end_rows", &"unscripted_day"]

# PANEL_SCENES 里 &"almanac": … 之后加：
	&"stocktake": "res://scenes/cards/rogue/StocktakePanel.tscn",
	&"relics": "res://scenes/cards/rogue/RelicsDrawer.tscn",

# PANELS 末尾 &"minigame"] 改成：
	&"contacts", &"demands", &"shelf", &"tickets", &"almanac", &"minigame", &"stocktake", &"relics"]

# PANEL_SHOW 里加：
	&"stocktake": &"overlay", &"relics": &"drawer_r",

# HOTSPOTS / HOTSPOT_PANELS：
const HOTSPOTS: Array[StringName] = [&"magnifier", &"abacus", &"cashbox", &"ledger", &"notebook", &"calendar",
	&"notice", &"notewall", &"lamp", &"curio"]
const HOTSPOT_PANELS := {&"abacus": [&"dossier", {"tab": "rules"}], &"cashbox": [&"estates", {}],
	&"ledger": [&"tickets", {}], &"notebook": [&"dossier", {}], &"calendar": [&"almanac", {}], &"notewall": [&"demands", {}],
	&"curio": [&"relics", {}]}

# ANCHORS 末尾 &"a.tickets.list": "C04", 之后加：
	&"a.scene.curio": "RG4", &"a.stock.offers": "RG4", &"a.relics.list": "RG4",

# RNG_DOMAINS 里 ["c.mock", "W0", false], 之前加：
	["c.stock.offer", "RG2", false], ["m.run.seed", "RG2", false], ["m.run.seed_text", "RG2", false],
```

头注释加一行：`# Rogue v1 (docs/cards/rogue/ROGUE_V1.md §9): relic/source prefixes, stock.pick, relics/stocktake/legacy.* queries, stocktake/relics panels, curio hotspot, c.stock.offer.`

### 10.2 `scripts/cards/api/card_layout.gd`

```gdscript
# 常量区（S_DOOR_FLAG / DOOR_FLAG 之后）：
const S_CURIO := Rect2i(237, 60, 52, 38)
const CURIO := Rect2(948, 240, 208, 152)
const CURIO_CELL := Vector2(64, 64)

# S_HOTSPOTS 末尾 &"lamp": Rect2i(292, 68, 20, 32), 之后：
	&"curio": Rect2i(237, 60, 52, 38),
# HOTSPOTS 末尾 &"lamp": Rect2(1168, 272, 80, 128), 之后：
	&"curio": Rect2(948, 240, 208, 152),

# 文件末尾：
## Rogue v1: the i-th curio shelf cell (0..5, row-major, 3 x 2), screen coordinates; 64 x 64 each.
static func curio_cell(i: int) -> Rect2:
	if i < 0 or i >= 6:
		return Rect2()
	return Rect2(CURIO.position + Vector2(8.0 + float(i % 3) * 64.0, 12.0 + float(i / 3) * 64.0), CURIO_CELL)
```

### 10.3 `scripts/cards/api/dsl_shapes.gd`

```gdscript
# EFFECT_OPS 末尾 &"goal": "G02", &"game_over": "G02", 之后：
	&"stock_offer": "RG2",
# COND_OPS 末尾 &"almanac_yi": "G05", 之后：
	&"veteran": "RG5",
# EFFECT_PARAMS 末尾 &"game_over": {"reason": "str"}, 之后：
	&"stock_offer": {"n": "int", "kinds": "strs", "depths": "strs?", "from": "str"},
# COND_VALUES 末尾 &"almanac_yi": "e:…", 之后：
	&"veteran": "bool",
```

### 10.4 `scripts/cards/core/card_validator.gd`

```gdscript
# TEXT_REQUIRED 里 "rule_page": ["title", "body"], "item": [], "almanac_day": [], 之后：
	"relic": ["title", "body", "use"], "source": ["title", "body", "use"],
```

### 10.5 `scripts/cards/loop/card_engine.gd`

```gdscript
const _ApprenticeInstall = preload("res://scripts/cards/apprentice/apprentice_install.gd")
const _RelicInstall = preload("res://scripts/cards/relic/relic_install.gd")
const _StockInstall = preload("res://scripts/cards/stock/stock_install.gd")
const _LegacyInstall = preload("res://scripts/cards/legacy/legacy_install.gd")
…
	_ApprenticeInstall.install(self, ctx)
	# Rogue v1 (ROGUE_V1.md): relics, weekly stocktake and sources, run context. Appended after K18; never reorder.
	_RelicInstall.install(self, ctx)
	_StockInstall.install(self, ctx)
	_LegacyInstall.install(self, ctx)
```

### 10.6 `scripts/cards/loop/loop_install.gd`（`_cmd_new`）

```gdscript
const _LegacyInstall = preload("res://scripts/cards/legacy/legacy_install.gd")
…
static func _cmd_new(ctx: CardCtx, opts: Dictionary, weak: WeakRef) -> Dictionary:
	for key in ["seed", "stage"]:
		if opts.has(key) and typeof(opts[key]) != TYPE_INT:
			return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	# Rogue v1 (ROGUE_V1.md §4.1): optional run context from the shell; absent or {} keeps today's state byte for byte.
	if opts.has("run") and typeof(opts["run"]) != TYPE_DICTIONARY:
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var db := CardDB.load_all(str(opts.get("data_root", CardDB.DEFAULT_ROOT)),
		{"only_examples": bool(opts.get("only_examples", false)), "ship": CardShip.is_ship()})
	if db.stage(int(opts.get("stage", 0))).is_empty() or not db.errors().is_empty():
		return {"ok": false, "err": CardIds.ERR_BAD_ARGS}
	var run: Dictionary = opts.get("run", {})
	var run_err: String = _LegacyInstall.check_run(db, run)
	if run_err != "":
		return {"ok": false, "err": run_err}
	ctx.db = db
	CardText.setup(db)
	CardSave.set_root(str(opts.get("save_dir", CardSave.DEFAULT_ROOT)))
	ctx.state = CardState.create(int(opts.get("seed", 0)), {"difficulty": str(opts.get("difficulty", "normal")), "db_hash": db.hash()})
	ctx.ledger = null
	_LegacyInstall.init_run(ctx, run)
	var engine: CardEngine = weak.get_ref()
	engine.clear_command_log()
	CardDayLoop.begin_stage(ctx, int(opts.get("stage", 0)))
	CardDayLoop.open_month(ctx)
	return {"ok": true, "err": ""}
```

### 10.7 `scripts/cards/core/card_composer.gd`（`is_scripted_day`）

```gdscript
static func is_scripted_day(ctx: CardCtx) -> bool:
	var loop := ctx.state.ns("loop")
	var days: Array = ctx.rules("deal").get("scripted_days", {}).get(str(int(loop.get("stage", 0))), [])
	if not days.has(int(loop.get("stage_day", 0))):
		return false
	# Rogue v1 (RG5): a veteran opening plays the tutorial days as ordinary days. No provider = unchanged.
	return not ctx.mods.any_true(ctx, &"unscripted_day", {"stage": int(loop.get("stage", 0)),
		"stage_day": int(loop.get("stage_day", 0))})
```

### 10.8 `scripts/cards/ui/table/modal_host.gd`

```gdscript
const DRAWER_TITLES := {&"almanac": "c01.drawer.almanac", &"estates": "c01.drawer.estates", &"relics": "rg4.drawer.relics"}
```

### 10.9 `data/cards/_schema/relic.json` 与 `source.json`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "res://data/cards/_schema/relic.json",
  "title": "card type relic",
  "description": "Rogue v1 old object on the curio shelf (docs/cards/rogue/ROGUE_V1.md section 6). Never dealt; held in state.relic. Player text (title, body, use, lines.flaw, lines.gain) lives in text/** and text_ai/**.",
  "type": "object",
  "required": ["id", "type", "era", "brief", "_provenance", "depth", "art"],
  "properties": {
    "id": {"type": "string", "description": "rl.<slug>"},
    "type": {"type": "string", "description": "relic"},
    "era": {"type": "array", "items": {"type": "string"}, "description": "['*'] in v1"},
    "weight": {"type": "integer", "description": "Offer weight; 0 = never offered"},
    "tags": {"type": "array", "items": {"type": "string"}, "description": "Unused in v1"},
    "conditions": {"type": "object", "description": "Must hold for the relic to be offered; checked at offer time only"},
    "depth": {"type": "string", "description": "plain | storied | treasure; shown as words, never as rarity"},
    "mods": {"type": "array", "items": {"type": "object"}, "description": "Standing modifier rows, ROGUE_V1 section 5.4; pct is a multiplier, 100 = unchanged"},
    "passives": {"type": "array", "items": {"type": "object"}, "description": "{hook: day_start|settle, effects: [existing DSL ops]}"},
    "downsides": {"type": "array", "items": {"type": "object"}, "description": "Same shape as passives; the flaw"},
    "art": {"type": "string", "description": "prop.relic.<slug>, 32x32"},
    "brief": {"type": "string", "description": "Designer note with the real numbers; never shown"},
    "_provenance": {"type": "object", "description": "{by, task, date}"}
  }
}
```

`source.json`：同上，`$id`/`title`/`description` 改成 source（“Rogue v1 customer source picked at the weekly stocktake; lasts until the end of the stage”），`required` 去掉 `depth`，`properties` 去掉 `depth` `passives` `downsides`，`mods` 说明改成“only pool_weight and deal_count rows”，`art` 说明改成 `illus.ky.<slug>, 64x48`。

### 10.10 引擎桩（签名就是正式签名；各包换掉函数体）

`scripts/cards/relic/relic_ids.gd`

```gdscript
# Rogue v1 relics: module constants. Owner RG1 (docs/cards/rogue/ROGUE_V1.md §4). No class_name.
extends RefCounted

const OWNER := "RG1"
const NS := "relic"
const DEPTHS: Array[String] = ["plain", "storied", "treasure"]
const ERR_RELIC_FULL := "relic_full"
const ERR_NOT_HELD := "not_held"
const Q_RELICS := &"relics"
```

`scripts/cards/relic/relic_api.gd`

```gdscript
# Rogue v1 relics: the only write path into state.relic (RG2 calls take()). Owner RG1. No class_name; preload it.
extends RefCounted


static func active(ctx: CardCtx) -> bool:
	return bool(ctx.rules("relics").get("enabled", true)) and not ctx.db.ids_of(&"relic").is_empty()


static func held_ids(_ctx: CardCtx) -> PackedStringArray:
	return PackedStringArray()


static func gone_ids(_ctx: CardCtx) -> PackedStringArray:
	return PackedStringArray()


static func cap(ctx: CardCtx) -> int:
	return int(ctx.rules("relics").get("cap", 6))


static func is_full(ctx: CardCtx) -> bool:
	return held_ids(ctx).size() >= cap(ctx)


static func can_take(_ctx: CardCtx, _id: String, _replace: String) -> String:
	return CardIds.ERR_NOT_IMPLEMENTED


static func take(_ctx: CardCtx, _id: String, _replace: String, _src: String) -> String:
	return CardIds.ERR_NOT_IMPLEMENTED
```

`scripts/cards/relic/relic_install.gd`

```gdscript
# Rogue v1 relics: registration only. Owner RG1. Installed after K18 (card_engine.gd). No class_name.
extends RefCounted

const Ids = preload("res://scripts/cards/relic/relic_ids.gd")


static func install(engine: CardEngine, _ctx: CardCtx) -> void:
	engine.register_query(Ids.Q_RELICS, _q_relics, Ids.OWNER)


static func _q_relics(_ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"ok": true, "err": "", "cap": 6, "count": 0, "dormant": false, "held": []}
```

`scripts/cards/stock/stock_ids.gd`

```gdscript
# Rogue v1 weekly stocktake and customer sources: module constants. Owner RG2. No class_name.
extends RefCounted

const OWNER := "RG2"
const NS := "stock"
const DOMAIN := "c.stock.offer"
const PANEL := &"stocktake"
const CMD_PICK := &"stock.pick"
const Q_STOCKTAKE := &"stocktake"
const OP_OFFER := &"stock_offer"
```

`scripts/cards/stock/stock_install.gd`

```gdscript
# Rogue v1 stocktake: registration only. Owner RG2. Installed after relics (card_engine.gd). No class_name.
extends RefCounted

const Ids = preload("res://scripts/cards/stock/stock_ids.gd")


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	engine.register_command(Ids.CMD_PICK, _cmd_pick, Ids.OWNER)
	engine.register_query(Ids.Q_STOCKTAKE, _q_stocktake, Ids.OWNER)
	ctx.ops.register(Ids.OP_OFFER, _op_offer, CardDslShapes.shape(Ids.OP_OFFER), Ids.OWNER)


static func _cmd_pick(_ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}


static func _q_stocktake(_ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}


static func _op_offer(_ctx: CardCtx, _eff: Dictionary, _source: String) -> void:
	pass
```

`scripts/cards/stock/run_seed.gd`（**完整实现**，RG2 只加测试）

```gdscript
# Seeds for new runs: run 1 is always 7; later runs derive from the profile salt, the run number and how many times
# the title's reroll was pressed. Never reads the wall clock (red line 2). Typed text maps deterministically to a seed.
# Owner RG2 (docs/cards/rogue/ROGUE_V1.md §5.7). Pure functions, usable by the engine and the shell.
class_name CardRunSeed
extends RefCounted

const FIRST_RUN_SEED := 7
const MAX_SEED := 2147483646
const DOMAIN := "m.run.seed"
const TEXT_DOMAIN := "m.run.seed_text"
const TEXT_MAX := 24


static func derive(salt: int, run_no: int, reroll: int) -> int:
	if run_no <= 1 and reroll <= 0:
		return FIRST_RUN_SEED
	return 1 + int(JevRng.draw(salt, DOMAIN, [run_no, reroll]) * float(MAX_SEED - 1))


## -1 = empty (use the suggested seed). Digits are used as is (folded into 1..MAX_SEED); any other text is hashed.
static func parse(text: String) -> int:
	var s := text.strip_edges()
	if s == "":
		return -1
	if RegEx.create_from_string("^[0-9]{1,18}$").search(s) != null:
		var v := int(s)
		return v if v >= 1 and v <= MAX_SEED else 1 + posmod(v - 1, MAX_SEED)
	return 1 + int(JevRng.draw(0, TEXT_DOMAIN, [s.substr(0, TEXT_MAX)]) * float(MAX_SEED - 1))


static func text(seed_value: int) -> String:
	return str(seed_value)
```

`scripts/cards/legacy/legacy_ids.gd`

```gdscript
# Rogue v1 run context (old ledger): module constants. Owner RG5. No class_name.
extends RefCounted

const OWNER := "RG5"
const NS := "run"
const Q_HARVEST := &"legacy.harvest"
const Q_OLD_INK := &"legacy.old_ink"
const COND_VETERAN := &"veteran"
const MOD_UNSCRIPTED := &"unscripted_day"
```

`scripts/cards/legacy/legacy_install.gd`

```gdscript
# Rogue v1 run context: registration plus the two calls CardLoopInstall._cmd_new makes. Owner RG5. No class_name.
extends RefCounted

const Ids = preload("res://scripts/cards/legacy/legacy_ids.gd")


static func install(engine: CardEngine, ctx: CardCtx) -> void:
	engine.register_query(Ids.Q_HARVEST, _q_harvest, Ids.OWNER)
	engine.register_query(Ids.Q_OLD_INK, _q_old_ink, Ids.OWNER)
	ctx.conds.register(Ids.COND_VETERAN, _cond_veteran, CardDslShapes.shape(Ids.COND_VETERAN, true), Ids.OWNER)


## Before the state exists. "" = ok, otherwise an error code (bad_args).
static func check_run(_db: CardDB, _run: Dictionary) -> String:
	return ""


## Right after CardState.create, before begin_stage. An empty run writes nothing (zero identity).
static func init_run(_ctx: CardCtx, _run: Dictionary) -> void:
	pass


static func _q_harvest(_ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"ok": false, "err": CardIds.ERR_NOT_IMPLEMENTED}


static func _q_old_ink(_ctx: CardCtx, _args: Dictionary) -> Dictionary:
	return {"ok": true, "err": "", "pages": []}


static func _cond_veteran(_ctx: CardCtx, value: Variant) -> bool:
	return not bool(value)
```

### 10.11 界面桩

`scripts/cards/ui/rogue/stocktake_panel.gd` 与 `relics_drawer.gd`（两个文件内容一样，只改第一行注释）：

```gdscript
# Rogue v1 weekly stocktake / peddler pick overlay (stocktake). Owner RG4; step-0 stub, RG4 replaces the body.
extends CardPanel
```

`scenes/cards/rogue/StocktakePanel.tscn`（`RelicsDrawer.tscn` 同样，节点名与脚本路径换掉）：

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/cards/ui/rogue/stocktake_panel.gd" id="1_script"]

[node name="StocktakePanel" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_script")
```

### 10.12 `docs/cards/ownership.json`

`tasks` 末尾加 `"RG1", "RG2", "RG3", "RG4", "RG5", "RG6"`；`paths` 末尾加（`_owner_of` 先匹配先赢，所以 K16/K12/C01/C10/C16/G06 原有的文件仍归原主人，下面列出的是“这一轮允许 RGx 改”的共享路径）：

```json
"RG1": ["scripts/cards/relic/**", "data/cards/text_ai/ui/RG1.text.json"],
"RG2": ["scripts/cards/stock/**", "data/cards/text_ai/ui/RG2.text.json"],
"RG3": ["data/cards/era/common/relics.json", "data/cards/era/common/sources.json", "data/cards/era/1938/curio_peddler.json",
        "data/cards/rules/relics.json", "data/cards/rules/stock.json", "data/cards/rules/legacy.json",
        "data/cards/text_ai/era/common/relics.text.json", "data/cards/text_ai/era/common/sources.text.json",
        "data/cards/text_ai/era/1938/curio_peddler.text.json",
        "tools/cards/art/gen_ai_rogue.py", "art/ai/prop/relic.*", "art/ai/prop/curio.*", "art/ai/illus/ky.*",
        "art/_placeholder/cards/props/relic.*", "art/_placeholder/cards/props/curio.*", "art/_placeholder/cards/illus/ky.*",
        "art/_placeholder/cards/manifest.json", "data/cards/era/1938/tutorial.json", "data/cards/art/manifest.json"],
"RG4": ["scenes/cards/rogue/**", "scripts/cards/ui/rogue/**", "data/cards/text_ai/ui/RG4.text.json",
        "scripts/cards/ui/table/card_stage.gd", "scripts/cards/ui/shell/card_title.gd"],
"RG5": ["scripts/cards/legacy/**", "scripts/cards/meta/**", "data/cards/text_ai/ui/RG5.text.json",
        "scripts/cards/ui/table/card_game_root.gd", "scripts/cards/ui/dossier/dossier_book.gd"],
"RG6": ["docs/cards/rogue/**", "scripts/cards/sim/**", "tools/cards/balance/**", "scripts/tests/cards/golden/golden.json",
        "scripts/tests/cards/G06/test_no_deadlock.gd", "docs/cards/balance/**", "docs/cards/CARDS_INTERFACES.md",
        "docs/cards/DESIGN_cards.md", "docs/cards/ownership.json", "data/cards/rules/balance_overrides.json"]
```

`_doc` 加一句：`Rogue v1 (2026-10-25, ROGUE_V1.md): RG1-RG6 as listed; shared paths keep their real owners and return after the v1 merge.`

`default_owned` 已经让每个任务拥有 `scripts/tests/cards/{ID}/**`、`suites/{ID}.txt`、`tags/{ID}.json`、`ui_keys/{ID}.json`。

### 10.13 步骤 0 的自检

- `W0_engine`：`stock.pick` 的主人是 RG2、四个新查询的主人对、`stock_offer` 的主人是 RG2、条件 op 数 = `COND_OPS` 数。
- `W0_skeleton`：`PANEL_SHOW` 覆盖 `PANELS`、两个新场景存在且根是 `CardPanel`、`day_full` 冒烟实例化不报错、`curio` 热点矩形在屏内、三个新锚点合法。
- `W0_stage`：`HOTSPOTS[curio] == screen(S_HOTSPOTS[curio])`。
- `C01_stage`：点 `curio` 打开 `relics`（桩抽屉）。
- 数据校验 strict 全绿（没有新数据）；`G06_golden` 原样通过。

---

## 11. 界面键（名字 + 一句 brief + 基础层正文）

> 规矩：每个包在自己的 `data/cards/ui_keys/RGx.json` 登记（`_meta.owner = "RGx"`，键以 `rgx.` 开头，V24），并在 `data/cards/text_ai/ui/RGx.text.json` 写基础层（`{"<key>": {"t": "…"}}`，文件级 `_meta._provenance = "ai:claude:opus-5.5:2026-10-25:rogue-v1"`）。**V26 要求正文条目的键已登记**，所以键和正文都由用它的那个包自己写，不跨包。下表的正文可直接照抄（不得出现阿拉伯数字以外的效果数；`{n}` `{deals}` `{d}` `{cap}` 是看得见的计数 / 日子）。

**RG1**

| 键 | brief | 基础层 `t` |
|---|---|---|
| `rg1.notice.released` | 满了换一件时，被让出的那件送回库房 | 让出去的那件包好，送回了库房。 |

**RG2**

| 键 | brief | `t` |
|---|---|---|
| `rg2.notice.stocktake` | 周末盘账，生意做够了（参数 deals） | 周末盘账：这周做成了 {deals} 笔生意，库房里翻出几样东西，门口也有人来打听。 |
| `rg2.notice.stocktake_few` | 周末盘账，生意做得少（参数 deals） | 周末盘账：这周只做成 {deals} 笔，翻出来的不多。 |
| `rg2.notice.passed` | 盘账时明说都不要 | 这回都没要，东西包好放回去了。 |
| `rg2.notice.sources_lapsed` | 换关时客源散了 | 过了这一阵，门口常来的那几拨人散了。 |
| `rg2.notice.peddler_empty` | 货郎担子里没有合适的 | 货郎翻了翻担子，没什么合适的。 |
| `rg2.reason.offer_closed` | 这份报价已挑过或过期（界面错误句） | 这一份已经挑过，或者过了时候。 |

**RG4**

| 键 | brief | `t` |
|---|---|---|
| `rg4.drawer.relics` | 博古格抽屉标题 | 博古格 |
| `rg4.depth.plain` | 来历深浅：寻常 | 寻常家什 |
| `rg4.depth.storied` | 来历深浅：有来历 | 有来历的 |
| `rg4.depth.treasure` | 来历深浅：镇店 | 镇店的 |
| `rg4.kind.source` | 客源卡左上角 | 客源 |
| `rg4.stock.title.week` | 盘账叠层标题（参数 n = 第几周） | 第{n}周盘账 |
| `rg4.stock.title.peddler` | 货郎报价标题 | 货郎的担子 |
| `rg4.stock.peddler_sub` | 货郎报价副行 | 挑一样摆上博古格，另一样他挑走。 |
| `rg4.stock.deals` | 这周成交笔数（参数 deals） | 这周做成了 {deals} 笔生意。 |
| `rg4.stock.few` | 只给两样时的说明 | 生意做得少，只翻出两样。 |
| `rg4.stock.take_relic` | 物件卡按钮 | 就要这件 |
| `rg4.stock.take_source` | 客源卡按钮 | 就请这拨人 |
| `rg4.stock.pass` | 都不要 | 都不要 |
| `rg4.stock.later` | 只关 | 回头再说 |
| `rg4.stock.use` | 好处小标签 | 好处 |
| `rg4.stock.flaw` | 毛病小标签 | 毛病 |
| `rg4.stock.source_until` | 客源管多久 | 管到这个月底 |
| `rg4.stock.full` | 满了要让出一件的说明 | 博古格满了。要摆这件，得先让出一件——送回库房，这一局不会再翻出来。 |
| `rg4.stock.replace_ok` | 确认让出 | 让出它，摆上新的 |
| `rg4.stock.replace_cancel` | 不换了 | 那就不要了 |
| `rg4.relics.count` | 抽屉顶行（参数 n、cap） | 摆了 {n} 件，一共 {cap} 格 |
| `rg4.relics.empty` | 抽屉空状态 | 格子还空着。周末盘账、货郎上门，会翻出老东西来。 |
| `rg4.relics.dormant` | 流落街头 / 在牢里时 | 铺子不在手里，这些东西都收起来了，不顶用。 |
| `rg4.relics.sources` | 客源一节标题 | 门口常来的 |
| `rg4.relics.sources_empty` | 没有客源 | 还没有。周末盘账时可以挑。 |
| `rg4.relics.pending` | 还有一份没挑的按钮 | 还有一份没挑的 |
| `rg4.title.run_no` | 标题盒顶行（参数 n） | 这是第{n}本账 |
| `rg4.title.seed` | 种子标签 | 种子 |
| `rg4.title.reseed` | 换一个种子 | 换一个 |
| `rg4.title.opening` | 开头标签 | 开头 |
| `rg4.title.shelf` | 书架标签 | 旧账 |
| `rg4.title.book_no` | 书脊（参数 n） | 第{n}本 |

**RG5**

| 键 | brief | `t` |
|---|---|---|
| `rg5.notice.shanghai` | 上海学过徒的开头，第一天早上 | 她在上海银楼学过三年徒。哥哥临走只交代了几句，柜上的规矩不用再一样样教了。 |
| `rg5.opening.default` | 开头：哥哥的铺子 | 哥哥的铺子：从头学起 |
| `rg5.opening.shanghai` | 开头：上海学过徒 | 上海学过徒：不用教，直接开张 |
| `rg5.chronicle.ending.kind` | 铺史：收尾，本心高 | 三年熬过来了，街坊说德厚当的柜台还是热的。 |
| `rg5.chronicle.ending.plain` | 铺史：收尾 | 三年熬过来了，铺子还开着。 |
| `rg5.chronicle.ending.hard` | 铺史：收尾，本心低 | 三年熬过来了，铺子还开着，只是没人再提德厚当的“厚”字。 |
| `rg5.chronicle.prison.1938` | 铺史：1938 被抓（参数 d） | 民国二十七年三月第{d}天，人被带走，铺子落了锁。 |
| `rg5.chronicle.prison.1939` | 铺史：1939 腊月被抓 | 腊月第{d}天被带走，没能出来过年。 |
| `rg5.chronicle.prison.1940` | 铺史：1940 被抓 | 民国二十九年三月第{d}天，人被带走，这本账停在那一页。 |
| `rg5.chronicle.abandoned.1938` | 铺史：1938 另起一本 | 民国二十七年三月第{d}天，账本合上了，没再往下记。 |
| `rg5.chronicle.abandoned.1939` | 铺史：1939 另起一本 | 腊月第{d}天，账本合上了，没再往下记。 |
| `rg5.chronicle.abandoned.1940` | 铺史：1940 另起一本 | 民国二十九年三月第{d}天，账本合上了，没再往下记。 |
| `rg5.chronicle.other` | 铺史：别的原因 | 这本账在第{d}天合上了。 |
| `rg5.toast.closed` | 合账飘字 | 这本账合上了，放上了书架。 |
| `rg5.toast.profile_reset` | 档案读不出来 | 旧账读不出来，另起了一本旧账簿。 |
| `rg5.dossier.old_ink` | 旧墨碎片的小印 | 旧账 |
| `rg5.dossier.old_ink_hint` | 有旧墨的页底一句 | 淡墨的是旧账上见过的；这一本还得自己问出来。 |

---

## 12. 美术

> 现在由 RG3 用程序画（`tools/cards/art/gen_ai_rogue.py`，照 `gen_ai_small.py` 的写法：逐像素画、只用 `palette.dev.json` 的颜色、确定性 PNG（只有 IHDR/IDAT/IEND）、不写字、`random.Random(sha256(art_id) 前 8 字节)`、`--check` 字节对比、同时写 `.import`（`art_common.render_png_import`））。占位用 `python3 tools/cards/art/gen_placeholders.py --only=prop.relic.`、`--only=prop.curio`、`--only=illus.ky.` 生成（这三个类别它认识）。清单条目照现有写法：`{"base": [w, h], "human": "art/cards/…", "ai": "art/ai/…", "_provenance": "ai:claude:opus-5.5:2026-10-25:art-rogue", "placeholder": "art/_placeholder/cards/…"}`。`python3 tools/cards/art/check_manifest.py` 必须 `ART CHECK OK`。

| 美术 id | 底图 | `ai` / `human` / `placeholder` 路径 | 显示 | 画什么（也是以后 Google 订单的说明） |
|---|---|---|---|---|
| `prop.curio` | 52×38 | `art/ai/prop/curio.png` · `art/cards/props/curio.png` · `art/_placeholder/cards/props/curio.png` | 场景 ×4 | 挂在墙上的博古格：深色木框，3×2 个空格，每格内部 16×16（框左右 2 px、上下 3 px、格间 0），格子背面略暗 |
| `prop.relic.cat_bowl` | 32×32 | `art/ai/prop/relic.cat_bowl.png` · `art/cards/props/relic.cat_bowl.png` · `art/_placeholder/cards/props/relic.cat_bowl.png` | ×2 格子 / 抽屉，×4 卡 | 豁口的青花小碗，碗沿缺一角，碗里一点猫食 |
| `prop.relic.stub_box` | 32×32 | 同上规律 | 同上 | 小木匣，盖半开，露出一沓发黄的当票存根 |
| `prop.relic.blue_curtain` | 32×32 | | | 叠起来的一截蓝布棉门帘，边上一块补丁 |
| `prop.relic.oilpaper_umbrella` | 32×32 | | | 收拢的油纸伞，赭黄伞面，竹骨伞柄 |
| `prop.relic.old_almanac` | 32×32 | | | 线装老黄历，书页卷角，夹着一条红纸 |
| `prop.relic.chen_mortar` | 32×32 | | | 铜药碾：船形碾槽带一只碾轮，铜色有绿锈 |
| `prop.relic.hu2_pipe` | 32×32 | | | 长杆旱烟袋：铜烟锅、玉嘴，系一只小烟荷包 |
| `prop.relic.camphor_chest` | 32×32 | | | 樟木小箱，铜包角，铜锁扣 |
| `prop.relic.master_steelyard` | 32×32 | | | 戥子：细秤杆、小铜秤盘、秤砣，挂一截丝绳 |
| `prop.relic.sun_inkpad` | 32×32 | | | 圆形瓷印泥盒，盖子掀开，朱红印泥 |
| `prop.relic.rosewood_abacus` | 32×32 | | | 紫檀算盘，深红黑框，珠子发亮 |
| `prop.relic.old_signboard` | 32×32 | | | 一截旧匾的木心，暗金残笔画（抽象笔触，不可读） |
| `illus.ky.traveling_buyers` | 64×48 | `art/ai/illus/ky.traveling_buyers.png` · `art/cards/illus/ky.traveling_buyers.png` · `art/_placeholder/cards/illus/ky.traveling_buyers.png` | ×2 卡 | 两个外地口音、拎布包的买主在柜台前张望货架 |
| `illus.ky.needy_neighbors` | 64×48 | 同上规律 | | 街坊抱着包袱在门口排着，神色发急 |
| `illus.ky.junk_runners` | 64×48 | | | 挑两只箩筐的收旧货人，筐里杂物 |
| `illus.ky.old_customers` | 64×48 | | | 熟面孔的老主顾拿着当票，朝柜台点头 |
| `illus.ky.dockhands` | 64×48 | | | 码头脚夫和船家，背后是水边和桅杆 |
| `illus.ky.big_households` | 64×48 | | | 穿长衫的大户管事，身后跟着拎包袱的小厮 |

不需要新图的：货郎立绘复用 `portrait.stranger_peddler`；卡框、书脊、标题盒、旧墨小印都用配色画（`wood` `seal` `frame_gold` `jade` `paper` `ink` `ink_soft` `gold` `scene_void`，已核对都在 `palette.dev.json`）。**Google 订单（以后）**：上表 19 个 id，人画进 `human` 路径即覆盖 AI 图（`CardArt.path` 的查找顺序 human → ai → placeholder，`card_art.gd:28-49`）。

---

## 13. Mock 夹具（RG4 在 `scripts/tests/cards/RG4/fixtures/` 里写，不等引擎）

做法：把 W0 的基础夹具（`scripts/cards/mock/fixtures/*.json`）拷过来改。Mock 的夹具模式：`view` 原样给；查询按键 `"<查询名>|<参数 JSON，键排序、无空格>"` 查表（`mock_engine.gd:117-131`）；指令按 `responses` 里第一条 `cmd` 相同且 `match` 的键值都相等的回（`"once": true` 用一次就不再匹配），套 `patch`（`set` `append` `remove_from` `merge`，`path` 用点分）、发 `events`。

| 夹具 | 基于 | 改什么 |
|---|---|---|
| `rogue_week.json` | `settle.json` | 视图加 `relics`（持有 2 件：`rl.stub_box`、`rl.oilpaper_umbrella`）、`stock {open:"w0.1", week_deals:3, sources:[ky.dockhands]}`、`open_panel {kind:"stocktake", args:{offer:"w0.1"}}`；查询 `stocktake|{"offer":"w0.1"}` → 3 样（`rl.chen_mortar` storied、`ky.traveling_buyers`、`rl.blue_curtain` plain），`full:false`，`deals:3`，`week:1`；`stocktake|{}` 同上；`relics|{}`；回应：`stock.pick {offer:"w0.1", pick:"rl.chen_mortar"}` → ok + patch（`relics.held` append、`relics.count` 3、`stock.open` ""、`open_panel` 清空）+ 事件 `["notice","rl.chen_mortar#lines.gain",{}]`；`stock.pick {offer:"w0.1", pick:""}` → ok + 清 `open`/`open_panel`；`stock.pick {offer:"w0.1"}` 兜底 → ok；`day.end` 两条照 `settle.json` |
| `rogue_few.json` | `rogue_week.json` | 查询只 2 样（1 物件 1 客源），`deals:1`，`stock.week_deals:1` |
| `rogue_full.json` | `rogue_week.json` | 持有 6 件（`relics.count` 6）；查询 `full:true`、`held` 6 件；回应：`stock.pick {offer, pick:"rl.chen_mortar"}`（没有 replace）→ `{"ok": false, "err": "relic_full"}`；`stock.pick {offer, pick:"rl.chen_mortar", replace:"rl.stub_box"}` → ok |
| `rogue_peddler.json` | `day_full.json` | 白天；`open_panel {stocktake, {offer:"p8"}}`；查询 `stocktake|{"offer":"p8"}` → `from:"peddler"`、`week:-1`、2 件 plain；回应同上 |
| `rogue_drawer.json` | `day_full.json` | `relics` 4 件（含 `rl.camphor_chest` storied、`rl.rosewood_abacus` treasure）、`stock.sources` 2 种、`stock.open` "" |
| `rogue_drawer_pending.json` | `rogue_drawer.json` | `stock.open:"w0.1"` + `stocktake|{"offer":"w0.1"}` 查询 |
| `rogue_street.json` | `street_prison.json` | `relics.dormant:true`，持有 3 件 |
| `rogue_closed.json` | `rogue_week.json` | 查询 `status:"lapsed"`（测试叠层自己关掉） |

RG5 的档案簿测试夹具 `scripts/tests/cards/RG5/fixtures/dossier_old_ink.json`：基于 C10 的 `dossier_mixed.json`，加查询 `legacy.old_ink|{}`（一页已有的人加 2 块旧墨、一页只有旧墨的人）。

---

## 14. 六个工作包

> 每包：开分支 `rogue/RGx`（从步骤 0 的提交）；只改“拥有”栏的文件；测试清单 `scripts/tests/cards/suites/RGx.txt`（每行 `名字|脚本|超时秒|参数`，最后一行必须打印 `CARDS TEST PASS <名字>`，日志里不许有 ERROR/WARNING）；`.gd` 函数 ≤ 80 行、不写中文字符串字面量、遍历字典先排序、整数运算。**需要改不归自己的文件时，不要改**：在交付报告“需要别人改的”一节写出确切 diff，编排或 RG6 集成时处理。

### RG1 · 老物件引擎模块

- **拥有**：`scripts/cards/relic/**`（换掉步骤 0 的桩：`relic_install.gd` `relic_api.gd`，新增 `relic_mods.gd` `relic_hooks.gd` `relic_view.gd`，`relic_ids.gd` 可加常量）；`data/cards/ui_keys/RG1.json`；`data/cards/text_ai/ui/RG1.text.json`；`scripts/tests/cards/RG1/**`；`suites/RG1.txt`。
- **做什么**：§3.1 状态；§4.7 API；§4.5 七个修正项提供者（`price_pct` `patience_pct` `appraise_pct` `cap` `pool_pct` `deal_count` `coins`）带 `when` 与钳子；§5.4 不灵；§4.6 两个钩子（`day_start` 25、`settle` 45）跑 `passives`/`downsides`；`view_section`（键 `relics`）；查询 `relics`。不登记任何指令。
- **依赖**：步骤 0。不依赖任何别的包（数据用自己的夹具）。
- **测试数据**：`scripts/tests/cards/RG1/fixtures/relics.json`（= §6.4 原文）与 `rules_relics.json`（= §6.3）；助手把 `res://data/cards` 拷到 `t.user_dir() + "/cards"`（照 `scripts/tests/cards/G01/helper.gd` 的 `copy_tree`），再把两份夹具写到 `era/common/relics.json` 与 `rules/relics.json`（RG3 合入后照样覆盖同名文件），`CardEngine.new().new_game({"seed": 7, "data_root": root, "save_dir": t.user_dir()})`。给物件直接调 `RelicApi.take(engine.ctx, id, "", "test")`；问修正项直接 `engine.ctx.mods.pct(engine.ctx, &"price_pct", {...})`。
- **测试**（每个一个文件）：
  - `RG1_api`：`take` 的五个错误码各一例；满了换一件（`gone`、告示 `rg1.notice.released`）；没拿过时状态里**没有** `relic` 键；视图与查询形状；`t.no_leaks`；`find_floats` 为空。
  - `RG1_mods`：七个 kind 各一正一反（含 `when` 为真 / 假）；钳子（两件 pay 乘到 90 以下被钳回）；`pool_pct` 的 `tags_any` 与 `intents` 都对；`coins` 只给 `self` 进 `official` 格子（用真实数据里带 `official` 标签的格子）；流落街头（`loop.mode = "street"`）和在牢里时全部中性。
  - `RG1_hooks`：`rl.hu2_pipe` 周一（`weekday 0`）早上 `demand.tier_bias` 被 G03 发条子用掉、那张条子档位低一档、口碑掉；有人脉 `ma` 时都不发生；`rl.old_signboard` 集市日 settle 口碑涨、每晚风声 +1；确定性（同种子两遍哈希一样）；任意早上存 → 读 → 再走，哈希一样。
  - `RG1_data`：读 `res://data/cards/era/common/relics.json`（不存在就读夹具）：每行 `mod` 在 §5.4 表里、参数齐、`pct` 是 1–400 的整数、`when` 过 `CardDslShapes.check_cond` 且只用 §5.4 白名单 op、`passives`/`downsides` 的 `hook` 只有 `day_start`/`settle`、`depth` 合法、`art` 以 `prop.relic.` 开头。
  - `RG1_zero`：例子集 fair 自动玩 10 天：状态里没有 `relic`、视图里没有 `relics`。
  - `RG1_validate`：`validate_main.gd --only=data/cards/ui_keys/RG1.json,data/cards/text_ai/ui/RG1.text.json`。
- **完成标准**：上面全绿；`W0`、`G01`–`G06`（含 `G06_golden`）照绿。
- **不许碰**：`card_ids.gd` `card_layout.gd` `dsl_shapes.gd` `card_engine.gd` 等步骤 0 的文件；别人的命名空间（只读，且不调 `ns()`）；任何 `data/cards/**`（除了自己的 ui 键文件）；`scripts/cards/stock/**`。

### RG2 · 周末盘账、客源、`stock_offer`、种子

- **拥有**：`scripts/cards/stock/**`（换掉桩；新增 `stock_state.gd` `stock_offers.gd` `stock_mods.gd` `stock_view.gd`；`run_seed.gd` 已是完整代码，可修 bug 不可改签名）；`data/cards/ui_keys/RG2.json`；`data/cards/text_ai/ui/RG2.text.json`；`scripts/tests/cards/RG2/**`；`suites/RG2.txt`。
- **做什么**：§3.2 状态；§4.2 `stock.pick`；§4.3 查询 `stocktake`；§4.4 op `stock_offer`；§4.5 `pool_pct` `deal_count`（客源）；§4.6 四个钩子；§5.1–§5.3、§5.5 算法；`view_section`（键 `stock`）。物件那一支只经 `preload("res://scripts/cards/relic/relic_api.gd")` 的 `active/held_ids/gone_ids/cap/is_full/take`。
- **依赖**：步骤 0。合入顺序在 RG1 之后（在 RG1 合入前，物件那一支的 `take` 是桩，只返回 `not_implemented`——这一支的端到端测试放 RG6）。
- **测试数据**：同 RG1 的拷贝法，写 `era/common/sources.json`（§6.5）、`era/common/relics.json`（§6.4）、`era/1938/curio_peddler.json`（§6.6）、`rules/stock.json`（§6.3）。做成交易直接 `engine.ctx.hooks.fire(engine.ctx, &"card_resolved", {"uid": "", "outcome": &"resolved", "almanac": ["pawn_in", "trade"]})`。往前走用 `day.end {confirm: true}`。
- **测试**：
  - `RG2_seed`：`derive(0,1,0) == 7`；`derive` 对 run 2..200 × reroll 0..3 两两不同、都在 `1..MAX_SEED`；`parse("")==-1`、`parse("12345")==12345`、`parse("0")`/超大数折回、`parse("德厚当")` 两次相同且合法；两台引擎同种子同指令哈希逐日相同；种子 7 与 `derive(0,2,0)` 第 1 天发的牌不同。
  - `RG2_stocktake`：走到第 7 天日结：`view.open_panel == {kind:"stocktake", args:{offer:"w0.0"}}`、只有客源（`0:0` 只出客源）、0 笔成交 → 2 样；第 14 天前做 2 笔 → 3 样且混着出；`stock.pick` 客源 → `view.stock.sources`、`pool_pct` 对 `intent: "buy"` 的人物牌真的变大（直接问 `ctx.mods.pct`）；`pick ""` → `passed`；再挑 → `already_resolved`；第二天 → `lapsed`；报价开着时 `day.end {confirm:false}` 直接进下一天（不要确认）；同种子同指令报价一样；读早上的续玩点重来，报价一样；`t.no_leaks`（视图、查询、事件参数）；换关（`year.next`）后客源清掉、有告示。
  - `RG2_peddler`：第 8 天货郎在手牌；`card.choose {uid, choice:"look"}` → 报价 `p8`、2 件、都是 `plain`、`open_panel` 对；`send_off` → 没有报价；不理他打烊 → 正常走掉。
  - `RG2_zero`：例子集 10 天：没有 `stock` 键、视图没有 `stock`、从没开过 `stocktake`。
  - `RG2_validate`：ui 键与基础层。
- **完成标准**：全绿；`W0`、`G01`–`G06`（含 `G06_golden`）照绿。
- **不许碰**：步骤 0 的文件；`scripts/cards/relic/**`（只 `preload` API）；`state.relic`（只经 API 写）；任何 `data/cards/**`（除自己的 ui 键文件）。

### RG3 · 数据、基础层正文、程序美术

- **拥有**：§6.1 的全部文件；`tools/cards/art/gen_ai_rogue.py`；§12 的 PNG / `.import` / 占位与占位清单条目；`scripts/tests/cards/RG3/**`；`suites/RG3.txt`。共享：`data/cards/era/1938/tutorial.json`（只给 9 张牌的 `schedule` 加 `when`，别的一个字不动，`_meta` 不动）、`data/cards/art/manifest.json`（只加 19 条）。
- **做什么**：照抄 §6.3–§6.6（可调字、不调结构）；写 §6.7 的正文；§5.6 的教学牌 `when`；§12 的程序画与清单。
- **依赖**：步骤 0（`stock_offer`/`veteran` 的形状、`TEXT_REQUIRED`、两个 schema）。不依赖任何引擎包——校验器只看数据。
- **测试**：
  - `RG3_validate`：`validate_main.gd --mode=strict --only=data/cards/era/common/relics.json,data/cards/era/common/sources.json,data/cards/era/1938/curio_peddler.json,data/cards/era/1938/tutorial.json,data/cards/rules/relics.json,data/cards/rules/stock.json,data/cards/rules/legacy.json,data/cards/text_ai/era/common/relics.text.json,data/cards/text_ai/era/common/sources.text.json,data/cards/text_ai/era/1938/curio_peddler.text.json,data/cards/art/manifest.json --name=RG3_validate`。
  - `RG3_data`：12 件（plain 5 / storied 5 / treasure 2）、6 种；每件 `title` `body` `use` `lines.gain` 有字，有毛病的有 `lines.flaw`；货郎五个字段有字；所有这些正文没有 `[0-9０-９%％]`、没有 §6.7 的禁用词；所有 `art` 在清单里；`tutorial.json` 恰好 9 张（§5.6 列的）带 `{"not": {"veteran": true}}`、其余 3 张没带。
  - `RG3_art`（python，放进 suite 用 `OS.execute` 或单独跑）：`gen_ai_rogue.py --check` 字节一致；`check_manifest.py` 输出 `ART CHECK OK`。
- **完成标准**：上面全绿；`CARDS_VALIDATE_MODE=strict` 全量数据校验 0 错；`K12_*`、`K13_wording_lint`、`K15_*`、`K16_*`、`W0_validator`（“real data: default ok”）照绿。**`G06_golden` 会红（db_hash 与真数据行为变了），这是预期，在交付里写明，RG6 重算。**
- **不许碰**：任何 `.gd`；`golden.json`；`balance_overrides.json`；别人的 ui 键文件和 `text_ai/ui/*`；`tutorial.json` 里 `when` 以外的字段。
- **交给 RG6 的**：合入以后，三个 `data/cards/era/**` 数据文件里的**数字**（`weight` `pct` `delta`）的调整权归 RG6（只改数字，改完通知 RG3）。

### RG4 · 界面：盘账叠层、博古格抽屉、场景博古格、标题种子 / 书架盒

- **拥有**：`scenes/cards/rogue/**`、`scripts/cards/ui/rogue/**`（`stocktake_panel.gd` `relics_drawer.gd` `curio_shelf.gd` `title_run_box.gd`，可再拆小文件）；共享：`scripts/cards/ui/table/card_stage.gd`（只加 §7.4 三处）、`scripts/cards/ui/shell/card_title.gd`（只加 §7.5 的盒子与三个公开函数、键盘例外）；`data/cards/ui_keys/RG4.json`、`data/cards/text_ai/ui/RG4.text.json`；`scripts/tests/cards/RG4/**`（含 §13 夹具）；`suites/RG4.txt`。
- **做什么**：§7.2、§7.3、§7.4、§7.5。
- **依赖**：步骤 0 + Mock 夹具。不等任何引擎包。正文：`CardText` 对没有的键给草稿（测试照样算“来自 CardText”）；RG3 合入后自动显示正式基础层。
- **测试**：
  - `RG4_stocktake`：五个夹具（week / few / full / peddler / closed）：渲染不报错；按钮发的指令与参数对（`mock.sent`）；满了走“让出一件”、发带 `replace` 的那条；“回头再说”、Esc 不发指令；`refresh` 时 `status != open` 自己关；键盘 1–3 / Enter / Esc；`autoplay_step` 挑第一样；所有字来自 CardText；界面上没有 `%`、除成交笔数外没有数字；锚点 `a.stock.offers` 在 `OVERLAY_MAX` 里。
  - `RG4_drawer`：`rogue_drawer` 4 行 + 客源两行；`rogue_street` 压暗 + `rg4.relics.dormant`；`day_full`（没有 `relics`/`stock`）显示空状态不报错；`rogue_drawer_pending` 的按钮 → `close_requested {"next": {"kind": "stocktake", …}}`；锚点 `a.relics.list`。
  - `RG4_shelf`：用 Mock 根（`boot({"mock": true, "fixture": <rogue_drawer>, "skip_title": true})`）：4 个物件画在 `CardLayout.curio_cell(0..3)`；点热点 `curio` 开 `relics`；街头时热点和物件都隐藏；锚点 `a.scene.curio` 在 `CardLayout.CURIO` 里。
  - `RG4_title`：单独实例化 `CardTitle.tscn`：不调 `set_rogue` 时盒子不显示、C16 的焦点规矩不变；调了以后种子框显示 `seed`、“换一个”发 `chose(&"reseed")`、开头切换发 `chose(&"opening")` 且 `opening_id()` 对、未解锁的开头不显示那一排；焦点在种子框时输入 `w` `a` `s` `d` 空格进框不移动按钮焦点，Enter 发 `chose(&"new")`；书脊数 = `shelf.size()`、悬停显示铺史句；三次进出标题对象数不涨（同 C16 的 +8 容差）。
  - `RG4_validate`：ui 键与基础层。
  - 截图脚本 `shot_rogue.gd`（不进 suite）：叠层三张、两张、满了、货郎、抽屉、街头、场景博古格（白天 / 夜里）、标题盒。
- **完成标准**：上面全绿；`W0`、`C01`、`C02`、`C08`、`C16`、`X01_click_smoke`（Mock 那部分）照绿。
- **不许碰**：`card_game_root.gd`（RG5 的）、`modal_host.gd`/`drawer_host.gd`（步骤 0 已改完）、`dossier_book.gd`（RG5 的）、任何引擎代码、`mock_engine.gd`、W0 的基础夹具。

### RG5 · 旧账：引擎上下文、档案文件、合账、标题接线、旧墨、`og.shanghai`

- **拥有**：`scripts/cards/legacy/**`（换掉桩；新增 `legacy_run.gd` `legacy_harvest.gd`）；`scripts/cards/meta/**`（`card_profile.gd` `run_keeper.gd`）；共享：`scripts/cards/ui/table/card_game_root.gd`（只加 §8.1 的约 15 行）、`scripts/cards/ui/dossier/dossier_book.gd`（§7.6）；`data/cards/ui_keys/RG5.json`、`data/cards/text_ai/ui/RG5.text.json`；`scripts/tests/cards/RG5/**`；`suites/RG5.txt`。
- **做什么**：§3.3、§4.1、§4.3（两个查询）、§4.4（`veteran`、`unscripted_day`）、§4.6（`day_start` 2）、§5.6、§7.6、§8 全部。
- **依赖**：步骤 0。标题那一侧对着 §7.5 的冻结接口写（RG4 合入前，`title.has_method("set_rogue")` 为假就跳过，不报错）。
- **测试数据**：引擎测试同 RG1 的拷贝法，写 `rules/legacy.json`（§6.3），并给拷贝里的 `era/1938/tutorial.json` 9 张牌加 `when`（同 §5.6），测完不留。
- **测试**：
  - `RG5_engine`：不给 `run` / 给 `{}` → 状态里没有 `run`、视图没有 `run`、10 天哈希与不改代码时相同（用 `G06_golden` 的例子集用例对照）；合法 `run` → `state.run`（`known` 去重排序、丢掉不存在的 id）；四种坏参数 → `bad_args` 且 `ctx.state` 不变；`og.shanghai`：第 1 天手牌里没有教学牌、有随机来客，第 2 天哥哥告别照来，第 1 天早上告示是 `rg5.notice.shanghai`；`og.default`：第 1 天就是教学牌（与今天一致）；`legacy.harvest` 只读（前后哈希相同）、过 `leaks`、`frags` 对；`close` 四种键（`ending` 三档：直接改 `rules.conscience` 计数器前后各问一次）；`legacy.old_ink` 页与排序。
  - `RG5_profile`：新建 / 读坏档（改名 broken、`was_reset`）/ 原子写；`begin_run` 递增、第一本 7；`reroll_seed` 变；`absorb` 幂等且可交换（打乱顺序并两次结果相同）；`close_run` 同号替换；`reopen`；`close_abandoned` 用 `last`；`openings` 合上一本后解锁 `og.shanghai`；`run_context` 过滤；`title_data` 形状；`note_guide` 并集；旧 `suspend.json` 认领。
  - `RG5_root`：真引擎根（`boot({"mock": false, "save_dir": t.user_dir(), "guide": "off"})`）：标题出来、`set_rogue` 被调（RG4 未合入时跳过这几条断言）；种子框写 `12345` 按开张 → 引擎种子 12345、`run.no == 1`；直接调 keeper 的 game_over 处理（`prison`）→ 档案一条铺史、`current.status == "closed"`；回标题 → 书架一根、`og.shanghai` 可选；选它开张 → `run.no == 2`、`run.opening == "og.shanghai"`、种子 = `derive(0, 2, 0)`、旧的 `suspend.json` 被删；`game.retry_stage` 后 `reopen`。命令行带 `seed` 时用它。
  - `RG5_dossier`：`dossier_old_ink` 夹具：旧墨行 `c10_state == "old"`、压暗、有小印；只有旧墨的人有一页；Mock 没有这个查询时档案簿照旧（跑一遍 C10 的 `dossier_mixed`）。
  - `RG5_validate`：ui 键与基础层。
- **完成标准**：上面全绿；`W0`、`C09`、`C10`、`C16`、`X01_continue`、`X01_campaign`、`X01_ui_campaign`、`K14_*`、`K16_*` 照绿。
- **不许碰**：`card_title.gd`（RG4 的；只调它的三个公开函数）、`card_stage.gd`、步骤 0 的文件、`dossier.gd`（G03）、`choices.gd`、任何 `data/cards/**`（除自己的 ui 键文件）。

### RG6 · 自动玩策略、平衡对照、黄金种子、合同与文档、集成

- **拥有**：`scripts/cards/sim/**`（`policy.gd`、新 `policies/trader.gd` `policies/idle.gd`、`balance_main.gd` 的 `POLICIES`、`fuzz_actions.gd`、`telemetry.gd`）；`tools/cards/balance/**`（`aggregate.py` 加一张表、新 `rogue_ab.sh`）；`scripts/tests/cards/G06/test_no_deadlock.gd`（只加新指令的覆盖）；`scripts/tests/cards/golden/golden.json`（**单独一个只改它的提交**）；`docs/cards/balance/**`；`docs/cards/rogue/**`（把本文拷成 `docs/cards/rogue/ROGUE_V1.md`，附 R1–R3 三份提案）；`docs/cards/CARDS_INTERFACES.md`；`docs/cards/DESIGN_cards.md`；`docs/cards/ownership.json`（步骤 0 之后的维护）；`data/cards/rules/balance_overrides.json`；RG3 交出后三个数据文件里的数字；`scripts/tests/cards/RG6/**`；`suites/RG6.txt`。
- **第一阶段（与别人并行，约 1.5 小时）**：
  - `policy.gd` `_candidates`：`open_panel.kind == "stocktake"` 时问 `stocktake`，`status == "open"` → 每样一条 `stock.pick`（物件且 `full` → 带 `replace = held[0].id`），最后一条 `{pick: ""}`；顺序按策略：`fair`/`wheel` 原顺序；`greedy`/`trader` 物件优先（treasure > storied > plain）、客源优先 `ky.traveling_buyers` `ky.needy_neighbors`；`hoarder` 物件优先；`kind` 客源优先（`ky.old_customers` `ky.needy_neighbors`）；`random` 照基类随机。`_choice_score` 让 `look` 排在 `send_off` 前面。`refuser.decide` 不变（永远只打烊）。
  - `trader.gd`：柜台按 fair 档，**不为柜台押家当**（去掉 `_counter` 里的 `estate.mortgage`），会挑盘账。
  - `idle.gd`：除了盘账叠层开着时挑第一样，其余同 refuser（量“拒绝一切但白拿”的收益）。
  - `fuzz_actions.gd`：合法 `stock.pick`（取自查询）与不合法（`offer: "w9.9"`、`pick: "rl.nope"`、空参数）。
  - `telemetry.gd`：每局记报价次数、每份几样、挑了什么、每周成交笔数。
- **第二阶段（全部合入后，约 1.5 小时）**：
  - 集成：`CARDS_VALIDATE_MODE=strict tools/run_card_tests.sh` 全量；只有**因为本 v1 合理改变的行为**才改测试期望（例如 `golden.json`），其余红的交回对应包修。
  - `RG6_rogue_flow`（真数据）：fair 30 天：第 7/14/21/28 天开报价、第 8 天货郎 2 件 plain、至少拿到 1 件物件 1 种客源；每天视图与 `relics`/`stocktake` 查询过 `leaks`；指令回放哈希相同；第 10 天早上存读后逐日哈希相同；refuser 30 天：从不发 `stock.pick`、没有 `relic` 键、每次 `day.end {confirm:true}` 都前进；`stock.pick` 物件满了不带 `replace` → `relic_full`、带 → 成功且 `gone` 里有。
  - `RG6_policies`：用 RG4 的 Mock 夹具，每种策略在 `stocktake` 上的第一条候选符合上面的偏好；refuser 不挑。
  - `G06_no_deadlock` ≥ 1000 局全过（带新指令）。
  - **平衡对照**（`tools/cards/balance/rogue_ab.sh`）：把 `data/cards` 拷两份，B 份的 `balance_overrides.json` 加 `{"relics": {"enabled": false}, "stock": {"enabled": false}}`（两个规则文件都有 `enabled` 键，`_override_walk` 允许）；种子 1–20 × 策略 `refuser,fair,trader,idle` × 三关；`aggregate.py` 出表；报告 `docs/cards/balance/report_2026-10-25_rogue_v1.md`。**验收**（20 种子只够探索，过不了就写清楚）：
    - A1 refuser：开 / 关两边三关过关数差 ≤ 1、月底现金中位数差 ≤ 5%（它从不挑，只受第 8 天货郎占一个日程位的影响）。
    - A2 trader：开 ≥ 关的过关数；第 2、3 关月底现金中位数 开 ≥ 关 × 1.10。
    - A3 fair：开的过关数 ≥ 关 − 1（不倒退）。
    - A4 差距拉开：（trader 开 − refuser 开）第 3 关月底现金中位数 >（trader 关 − refuser 关）。
    - A5 拒绝不划算：idle 的（开 − 关）现金收益 < trader 的（开 − 关）收益。
    - A6 trader 拿到 3 样的周 ≥ 60%；idle ≤ 10%。
    - A7 覆盖：12 件、6 种在全部局里都被摆出过；trader 或 random 每件都挑过至少一次。
    - 调数只改 `rules/relics.json` / `rules/stock.json` 的标量键（经 `balance_overrides.json`）或 RG3 交出的数据数字，最多三批，每批写进报告。
  - **黄金种子**：照合同 §12.5，在集成头上 `balance_main.gd --data=examples … --update-golden --golden-out=<临时>` 与 `--data=real` 各跑一次（种子 7、fair、30 天），合成新的 `golden.json`（两条用例都保留），**一个只改 `golden.json` 的提交**；写 `docs/cards/balance/golden_changes_2026-10-25_rogue_v1.md`：原因（规则文件与数据进 `db_hash`；真数据第 8 天货郎、第 7/14/21/28 天盘账、fair 会挑）；附诊断：例子集用例把状态里的 `db_hash` 置空后，新旧逐日哈希相同（例子集没有 rogue 数据，行为不变）。
  - **文档**：`CARDS_INTERFACES.md` 加一章“肉鸽 v1”（链到 `docs/cards/rogue/ROGUE_V1.md`），并同步 §2.2 归属表、§6.3 随机域、§7.3 修正项与钩子表、§7.4 指令查询、§7.5 视图键、§7.8 面板、§7.11.2 坐标；`DESIGN_cards.md` 加一节记下主创的话和编排定的 v1 范围（明写“编排代主创记”）；`ownership.json` 在 v1 合完后把共享路径还给原主人。
- **完成标准**：全量测试（strict）绿；`G06_golden` 用新基线绿；平衡报告写完 A1–A7 每条过没过；文档提交。
- **不许碰**：引擎模块与界面代码（发现 bug 交回对应包）；RG3 交出前的数据。

### 14.1 共享文件一览（谁改、别人怎么办）

| 文件 | 唯一改它的 | 别人需要改时 |
|---|---|---|
| `scripts/cards/api/card_ids.gd`、`card_layout.gd`、`dsl_shapes.gd`、`core/card_validator.gd`、`core/card_composer.gd`、`loop/card_engine.gd`、`loop/loop_install.gd`、`ui/table/modal_host.gd`、`data/cards/_schema/{relic,source}.json` | 步骤 0（编排） | v1 内不再改；确实需要 → 交付报告里写 diff，RG6 在集成时加 |
| `docs/cards/ownership.json` | 步骤 0，之后 RG6 | 同上 |
| `scripts/cards/ui/table/card_stage.gd`、`ui/shell/card_title.gd` | RG4 | RG5 只调 `set_rogue/seed_text/opening_id` |
| `scripts/cards/ui/table/card_game_root.gd`、`ui/dossier/dossier_book.gd` | RG5 | RG4 不需要（热点、面板都走通用路由） |
| `data/cards/era/1938/tutorial.json`、`data/cards/art/manifest.json` | RG3 | — |
| `scripts/cards/sim/**`、`golden.json`、`balance_overrides.json`、`CARDS_INTERFACES.md`、`DESIGN_cards.md` | RG6 | — |
| `scripts/cards/relic/relic_api.gd` | RG1 | RG2 只 `preload` 调用，签名冻结 |
| `scripts/cards/stock/run_seed.gd` | RG2 | RG5 只调用，签名冻结 |

---

## 15. 红线核对与 v1 之后

### 15.1 红线

| 红线 | 怎么守 | 谁测 |
|---|---|---|
| 确定性 | 只用 `ctx.draw("c.stock.offer", …)`；报价在生成那一刻抽完记下；物件效果不掷随机；修正项按持有顺序乘、钳住、整数运算；种子不读墙钟 | RG1_hooks、RG2_seed、RG2_stocktake、RG6_rogue_flow |
| 隐藏值不上界面 | 视图 / 查询 / 事件只有 id、美术、深浅词、灵不灵、格数、成交笔数；正文不写数；铺史按本心挑键但不出数 | 各包 `no_leaks`；RG3_data 查正文 |
| 打烊永远能按 | 盘账在 `settle` 不进清单；货郎是普通人物牌；满了只是指令返回 `relic_full`，不挂任何待办；所有面板 Esc 只关 | RG2_stocktake、RG6_rogue_flow、`G06_no_deadlock` |
| 黄金种子 | 步骤 0 与所有代码包不动黄金；RG3 合入时预期变；RG6 一次重算并写原因 | RG6 |
| 免 AI 声明 | 新正文只在 `text_ai/**`（带 `_provenance`）与 `brief`；新美术在 `art/ai/**`；人写层以后覆盖 | RG3、K15 |

### 15.2 留到 v1.1 / v2

- **指引（红线 8）**：v1 不加 `FIRSTS`（加了就要同时动 `W0_skeleton` 的 70/各线计数、`K16_guide_coverage` 的 70 步 / 26 页 / `PAGE_IDS` / `table_71010.json`）。v1 靠货郎台词在戏里讲。v1.1：`FIRSTS` 加 `curio`（RG1，第一次拿到物件）、`stocktake`（RG2，第一次开盘账），K16 加 `gd.curio` `gd.stocktake` 两步与 `rule.curio` 一页，同一波改上述两个测试的计数。
- 物件：让出按钮、晦气与修好、成套、货郎买卖、`resolved`/`night`/`month_close` 钩子、结局里每件一句 `epilogue`。
- 旧账：合账大画面、旧账大画面、更多开头（`og.1939` 等）、年景、推理、知情回话、`alt_groups`、`CardCtx.rules` 覆盖层、档案盐每台机器不同。
- 走一趟（R3 全部）。
