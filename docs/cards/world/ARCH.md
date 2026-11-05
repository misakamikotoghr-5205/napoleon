# 拿破仑线：新表面、新结构的内核架构（ARCH）

> 2026-11-02，标签 arch。只读分析，基线是 `/home/user/dehoudang` 的 31c0b3e5（Godot 4.7.1，GDScript）。
> 旧版 1938 民国战役（`DEHOUDANG_CAMPAIGN=legacy`、`user://cards/`、`scripts/cards/legacy|loop|rules…` 的旧规则）不在本稿范围，一行都不动。
> 本稿是 A/B/C 三个工作包之间的契约：文中的字段名、命令名、文件名就是约定。数值只是起点，最后靠 §3.6 的模拟来校准。

## 0 结论速览

1. **一局的结构**：先走主干「鹰旗」（土伦 1793 → 厄尔巴 1815-02），到分岔点后进入三条分支之一：「鹰飞」继续征服、「远洋」海底两万里、「伊夫堡」基督山伯爵。每一段都有自己的世界地图视图（主干和鹰飞用 `europe`，远洋用 `world`，伊夫堡用 `med` 加几张局部图），也都有自己的几个固定结局。
2. **数据**：用一本「书」`book.json` 把几个「段」串起来。每段由两份文件组成：一份段定义（`ocean_pawn.json` 的超集）和一份地图文件。伙伴总表、通用事件池、调试用的携带模板放在书里。远洋段直接用现有的 `ocean_pawn.json`，其中的 id 全部冻结。
3. **内核不重写**：`ocean_campaign.gd` 就地泛化。文件名、`class_name OceanCampaign`、全部 `campaign.*` 命令名和查询键都不改。状态升到 v2，新增 `segment / run / map / archive` 四个字段。切换段的做法是：归档当前段，按书的规定携带，然后换上新段的定义。
4. **两本书并存**：
   - `ocean_pawn` 是单段书，没有地图，用旧营地。它供回归测试使用，行为要和 31c0b3e5 逐步一致。
   - `napoleon` 是新表面。
   默认书要等到 C 包的最后一步（C3）才切到 `napoleon`。
5. **世界地图取代营地和 12 格大富翁棋盘**：图由节点和连线组成，骰子或行军牌给出行军点（MP）。固定剧情是锚点节点；随机槽在进图时按种子定下，之后不再变。营地事务都改成节点上的动作，原来的命令照用。
6. **难度改用全局等级 L**：主干 L1–12，分支 L13–24。等级表在 L=2a−1 处与现在第 a 幕的数值逐项相同，所以旧模板和旧测试都不受影响。
7. **地形**：新增 28 种，比如虚空、墙、雪/泥/冰/沙、甲板/桅盘/海/浅水/暗礁、街道/房屋/屋顶/牢廊/牢门/墓穴。规则全部由一张表驱动；视线、顶层、黑暗这几条规则只作用于新地形。战场最大 12×7。
8. **敌军按段补齐**：
   - 主干：奥斯曼与马穆鲁克、英军、俄军、普军、西班牙游击队；
   - 远洋：英国水兵、海军陆战队、海盗、岸防炮、炮艇；
   - 伊夫堡：宪兵、狱卒、走私贩、罗马强盗（路易吉·万帕）、刺客。
   新行为一律用标签表达。
9. **去当铺**：玩家看得见的每个当铺概念都换成军需或行军上的含义，机制不变。完整清单见 §6。
10. **工作分三包并行**：A 管引擎和地图，B 管战斗和 3D 战场，C 管内容。先落地 A0（把文字抽出来），之后按 B1 → A1 → C1 → A2 → B2 → C2 → C3 的顺序合并。

---

## 1 战役结构

### 1.1 分岔点（推荐默认）

分岔点放在 **1815 年 2 月 25 日前后的厄尔巴**，即拿破仑 2 月 26 日夜里离岛的前一天。理由有三条：
- 三条分支的史实或原著挂钩都落在 10 天之内：
  - 2 月 24 日，法老号进马赛港（大仲马原著第一章）；
  - 2 月 26 日，皇帝离开厄尔巴；
  - 2 月 28 日，唐泰斯在订婚宴上被捕（本项目的设定日期）；
  - 远洋序曲的日期 1815-08-04（普利茅斯）可以由「随驾」一路接上。
- 主干收在「帝国已倒、皇帝未归」的时刻，三条分支的语气（征服、流亡、复仇）从同一个起点出发，彼此都不显得突兀。
- 主干不需要写滑铁卢。滑铁卢留给「鹰飞」作开场 Boss，这正是「打赢滑铁卢 → 继续征服」的分界。

分岔场景是主干最后一章最后一场 `elba_1815`，类型为 branch。场上三个抉择各带 `"branch": <段 id>`：

| 抉择 | 去向 | 叙事挂钩 | 首段内容 |
|---|---|---|---|
| 「随皇帝北上，亲赴前线」 | `conquest`（鹰飞） | 不倒翁号 → 儒安湾 → 巴黎 → 利尼 → **滑铁卢（赢下）** | 第一章「百日」，Boss 为滑铁卢（L14） |
| 「以司库身份随驾，管钱袋与船」 | `ocean`（远洋） | 百日在后方。滑铁卢以远方战报出现，结果按史实。随后到罗什福尔筹船，登上贝勒罗丰号 | 世界图第一张从「罗什福尔」事件节点出发，接 `prologue`（1815-08-04） |
| 「奉命携密信去马赛」 | `cristo`（伊夫堡） | 到达时恰逢法老号入港。远房族人、王家检察官杰拉尔·德·维尔福埋掉了唐泰斯，也盯上了你 | 第一章「马赛 1815」，以街巷遭遇战开场，随后伊夫堡 |

- 主角是**埃德蒙·德·维尔福**，帝国军需官兼司库，不是当铺掌柜。他与杰拉尔同宗，这层关系是伊夫堡分支的主线张力：揭发杰拉尔，就是亲手毁掉维尔福这个姓。
- 可选的跨段连接：在鹰飞分支里输掉滑铁卢时，大命运多出一项「随驾流放」，选它就跳到远洋段（见 §1.6 的 `segment_jump`）。这样"打输就落回史实"本身成了一种玩法，不算游戏结束。

### 1.2 分支可用性（由主干状态推算）

| 分支 | 硬条件 `requires` | 灰掉时写的原因 | 保底 |
|---|---|---|---|
| `conquest` | 满足其一：`stat.medal_earned ≥ 10`（整局累计挣到的勋章，花掉不减）；或旗标 `t_guard_oath`（1814 年枫丹白露告别时选择不离开）。此外要求 `army.hero_wounded == false` | 「皇帝没点你的名：忠诚不够（累计勋章 ≥ 10，或在枫丹白露立下近卫誓言）」/「主角重伤未愈」 | 否 |
| `ocean` | 无 | — | **是**：书校验要求恰好至少一条无条件分支 |
| `cristo` | 满足其一：旗标 `faria_half_letter`（第一幕故事节点「法利亚的半封信」）；或旗标 `t_pharaon_known`（在主干的马赛节点见过莫雷尔或法老号） | 「你和马赛没有交集」 | 否 |

- 软挂钩只改开局，不挡门：
  - 旗标 `t_mysore_envoy`（埃及幕的「提普苏丹的使者」节点，对应尼摩王子出身的伏笔）：远洋里尼摩的招募价 −1，开局信赖 1。
  - 旗标 `t_storks_hostile`：鹰飞里对手承包商多 1 支。
  - 主干里活着的伙伴可以带进任何分支，阵亡的仍是阵亡。
- 可用性是纯函数：`_choice_error` 碰到带 `branch` 的抉择时，用 `RunConditions.eval(campaign, book.branches[段].requires 并上 choice.requires)` 算；不满足就返回 `branch_locked`，并附上第一条失败条件的原因键。不用冻结。
- 肉鸽解锁存在局外文件 `napoleon_meta.json`（见 §1.7）。
  - 到过分岔点以后，标题页上可以选「从厄尔巴 1815 开局」，用书里的 `debug_carry.branch_point` 标准携带。
  - 打出某分支的任一结局以后，可以「直接开该分支第一章」，用标准携带。
  - 局外只记"解锁了什么"，不攒数值（沿用 v0.9 profile 的原则）。

### 1.3 文件布局

```
data/campaigns/
  ocean_pawn.json                 # 远洋段定义（id 冻结；C 只改文字）
  battle_templates.json           # 战场模板（B 追加，旧模板字节不变）
  ocean_battle.json               # 远洋的战斗数据（伙伴兵种、部队、币制换算、文字）
  napoleon/
    book.json                     # 书：段、分岔、携带、调试携带、行军牌、等级偏移（A 结构，C 填文字）
    companions.json               # 全书伙伴总表（含远洋 8 人；C）
    events_common.json            # 通用行军事件池（C）
    trunk.json  conquest.json  cristo.json   # 三份新段定义（C）
    maps/europe.json  maps/europe_late.json  maps/world.json  maps/med.json   # 段地图（world 的骨架由 A 先交）
    ref_rosters.json              # 各等级的参考名册（B，用于 §3.6）
    fixtures/mini_book.json       # 测试用迷你书：2 章主干 + 3 个迷你分支（A）
  text/ocean_ui.json              # A0 从 ocean_view.gd 抽出的营地/标题/规则文字（之后归 C）
data/hd/map_ui.json               # 地图界面文字（A）
scripts/cards/campaign/
  ocean_campaign.gd               # 泛化后的内核（A）
  run/run_book.gd  run_conditions.gd  run_carry.gd  run_ocean_rules.gd  run_replay.gd   # 新（A）
  map/map_rules.gd  map_query.gd  map_validate.gd                                       # 新（A）
scripts/cards/ui/map/map_panel.gd  map_canvas.gd  map_hand.gd  map_node_card.gd  map_projection.gd   # 新（A）
```

### 1.4 `book.json`（形状定稿；数值是示例）

```json
{
  "id": "napoleon", "version": 1, "start": "trunk",
  "segments": {
    "trunk":    {"file": "res://data/campaigns/napoleon/trunk.json",    "map": "res://data/campaigns/napoleon/maps/europe.json",      "kind": "trunk",  "brand": "鹰旗"},
    "conquest": {"file": "res://data/campaigns/napoleon/conquest.json", "map": "res://data/campaigns/napoleon/maps/europe_late.json", "kind": "branch", "brand": "鹰飞"},
    "ocean":    {"file": "res://data/campaigns/ocean_pawn.json",        "map": "res://data/campaigns/napoleon/maps/world.json",       "kind": "branch", "brand": "远洋",
                 "scene_battles": {"prologue": {"template": "bellerophon_deck", "level": 13}, "scene09": {"template": "skull_reef", "level": 19}}},
    "cristo":   {"file": "res://data/campaigns/napoleon/cristo.json",   "map": "res://data/campaigns/napoleon/maps/med.json",         "kind": "branch", "brand": "伊夫堡"}
  },
  "branches": {
    "conquest": {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "",
                 "requires": {"any": [{"stat": {"medal_earned": [">=", 10]}}, {"flags": ["t_guard_oath"]}], "hero_ok": true}},
    "ocean":    {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "prologue", "requires": {}},
    "cristo":   {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "",
                 "requires": {"any": [{"flags": ["faria_half_letter"]}, {"flags": ["t_pharaon_known"]}]}}
  },
  "carry": {
    "metrics": {"treasury": "chapter_start", "morale": "keep", "heat": "initial", "vitality": ["keep_min", 40],
                "construction": "initial", "exploration": "initial"},
    "treasury_bonus": [1, 4],
    "flags": "all", "items": ["elba_watch", "faria_half"], "rogue": "all", "coin_cap": 20
  },
  "shared_flags": ["faria_half_letter", "t_pharaon_known", "t_guard_oath", "t_mysore_envoy"],
  "companions": "res://data/campaigns/napoleon/companions.json",
  "events_common": "res://data/campaigns/napoleon/events_common.json",
  "bond_set": "napoleon",
  "start_rogue": {"coins": {"gold": 4, "supply": 6, "medal": 2, "intel": 2},
                  "props": ["prop_loaded_dice", "prop_field_ration", "prop_smoke_bomb"], "odd_seed_prop": "prop_spyglass", "even_seed_prop": "prop_barricade"},
  "march_cards": {
    "march_2":  {"mp": 2}, "march_3": {"mp": 3}, "forced_4": {"mp": 4, "effects": {"vitality": -4}},
    "scout_1":  {"mp": 1, "reveal": 2}, "wagon_1": {"mp": 1, "coins": {"supply": 2}},
    "night_2":  {"mp": 2, "ignore_forced": true}, "fair_wind": {"mp": 0, "voyage_minus": 1, "segments": ["ocean"]}
  },
  "march_deck": ["march_2", "march_2", "march_2", "march_3", "march_3", "forced_4", "scout_1", "wagon_1", "night_2"],
  "reward_pct_per_level": 4,
  "hero_hp_max": 24,
  "debug_carry": {
    "branch_point": {"coins": {"gold": 6, "supply": 8, "medal": 10, "intel": 3}, "flags": ["faria_half_letter"],
                     "companions": {"baptiste": 2, "corso": 2, "marie": 1}, "troops": ["line", "line", "grenadier", "jager", "hussar", "artillery"]},
    "conquest": {"from": "branch_point"}, "ocean": {"from": "branch_point"}, "cristo": {"from": "branch_point"}
  }
}
```

- `level_offset`：进入分支时写进 `run.level_offset`。分支段里所有战斗的等级 = 段内写的等级（场景战斗按 `2a−1` 换算）+ offset。单段书 `ocean_pawn` 的 offset 为 0，平衡保持现状。
- `scene_battles`：只在这本书里用新模板替换某场的战斗（键是场景 id，值是 template 和 level）。单段书仍读 `battle_templates.json` 的 `scene_map`。
- 全书校验（`run_book.gd`）要求以下各项**全书唯一**：场景 id、章节 id、事件 id、地图节点 id（地图节点以 `段:节点` 计）。主干的第一章不能叫 `prologue`（远洋已经用了），定为 `toulon`。

### 1.5 段定义 v2（`ocean_pawn.json` 的超集）

v1 的字段全部保留，含义不变：`id / version / title / initial / chapters / characters / items / scenes / endings / tuning`。新增字段都可省略，省略时内核回落到「远洋内置规则」`run_ocean_rules.gd`，它与 31c0b3e5 的硬编码一字不差。所以 **A1 不需要改 `ocean_pawn.json`**，也就不会和 C 冲突。

| 新字段 | 形状 | 取代的硬编码 |
|---|---|---|
| `rules.failures` | `[{ending, reason, when: 条件}]`，按顺序取第一条 | `_check_failure` 里的 vigo、treasury、vitality、heat |
| `rules.endings` / `rules.default_ending` | `[{id, when}]` / String | `_ending()` 与 `PERFECT_FLAGS` |
| `rules.exclusive_flags` | `[["revolution_funded","refused_funding"]]` | `_choice_error` 和 `_valid_state` 里写死的资助互斥 |
| `rules.actions` | `{visit_town:{cost,effects,items_by_chapter}, visit_backdoor:{effects}, trade_fair:{…}, trade_counterfeit:{…,flags}, build:{metric,chapters,cost,gain}, explore:{…}, fund:{chapters,yes,no}}` | `_visit` / `_trade` / `_project` / `_fund` 里的金额和章节 id |
| `scenes[].on_enter.demands` | `[{id,title,due_in,cost,item,on_expire:{effects,flags},on_fulfill:{flags}}]` | `_enter_scene` 里 scene01 的两条催逼，以及 `_expire_demands` / `_demand` / `_valid_state` 的 medicine 与 bond 分支 |
| `scenes[].choices[].branch` | 段 id | 新增：分岔 |
| `scenes[].choices[].requires` | 条件 | 新增：比 `requires_flags` 更强的门槛 |
| `scenes[].choices[].rogue` | `{coins:{gold:1}, props:[…], recruit:"id", troops:["line"], heal:20}` | 新增：剧情直接给币、道具、伙伴 |
| `events` | 事件数组，形状见 §2.6 | 新增：随机剧情池 |
| `big_fate_extra` | `[{id, when, jump?:段, effects}]` | 新增：段专属的大命运项（如鹰飞的「随驾流放」） |
| `gauges` | `{treasury:"军费",…}` | 六项指标在本段的名字（键不变，见 §6） |

**条件小语言**（`run_conditions.gd`）是纯函数，只用整数；一个对象里的各键是"且"的关系：

```
{"flags":[..]} 全有   {"any_flags":[..]} 至少一个   {"not_flags":[..]}
{"metric":{"heat":[">=",100]}}   {"stat":{"medal_earned":[">=",10]}}   {"coins":{"gold":[">=",2]}}
{"alive":["faria"]}（已招募且活着）   {"items":[..]}   {"count_flags":{"of":[..],"min":2}}
{"scene_done":"scene03"}   {"hero_ok":true}   {"any":[c1,c2]}   {"not":c}
```

运算符只有 `>= <= > < ==` 五个。`reason(campaign, cond)` 返回第一条不满足的键，形如 `stat:medal_earned`，界面据此显示原因。

远洋内置规则写成数据大致如下（只是 `run_ocean_rules.gd` 常量的样子）：

```json
"failures": [
  {"ending":"tragedy","reason":"vigo_decoy","when":{"flags":["vigo_decoy_missed"],"metric":{"heat":[">=",100]}}},
  {"ending":"bankruptcy","reason":"treasury","when":{"metric":{"treasury":["<=",0]}}},
  {"ending":"loss","reason":"vitality","when":{"metric":{"vitality":["<=",0]}}},
  {"ending":"blockade","reason":"heat","when":{"metric":{"heat":[">=",100]}}}],
"endings": [
  {"id":"tragedy","when":{"flags":["vigo_decoy_missed"],"metric":{"heat":[">=",100]}}},
  {"id":"dark","when":{"metric":{"treasury":[">",20000],"morale":["<",30]},"flags":["theft_treasure","counterfeit_trade"]}},
  {"id":"ghost","when":{"metric":{"construction":[">=",100],"exploration":[">=",100]},"flags":["refused_funding"]}},
  {"id":"alliance","when":{"flags":["escape_prepared","arsenic_evidence","viper_captured","vigo_decoy_exposed","orichalcum_cut"]}}],
"default_ending": "bittersweet"
```

### 1.6 内核状态 v2 与段切换

v1 的 21 个字段保留，`v` 改为 2，再加 4 个字段：

| 字段 | 形状 | 说明 |
|---|---|---|
| `segment` | String | 当前段的 id；单段书里是 `"ocean"` |
| `run` | `{book, path:[段…], level_offset, chapter_ord, stats:{medal_earned,battles,wins,boss_wins,days}, start:{segment,stage,carry,seed}, events_seen:[…]}` | 跨段的局内数据 |
| `map` | `{}`（本段没有地图）或地图状态（§2.9） | |
| `archive` | `{段: {scene_index, ending, end_reason, day, ledger, clues, used_actions, chapter_balances, demands, map}}` | 已经离开的段 |

字段要点：
- `campaign` 仍是**当前段定义的 id**（`ocean_pawn` / `trunk` / …），`definition_hash` 改为整本书的哈希：按 id 排序后各段哈希相连，再加 `book.json` 本身，取 sha256。
- `ledger / clues / used_actions / chapter_balances / demands` **按段分开**：只装当前段，离开时归档。`_valid_state` 的场景 id 校验因此不用改；归档里的条目按对应段的定义校验（书在载入时就把所有段都读进来了）。
- `day` 整局单调递增，跨段不清零。
- `rogue` 新增 `tally:{gold,supply,medal,intel}`，记一辈子挣到的币（只加不减）；`stat.medal_earned` 从这里取。为此 `_add_coin` 在 `delta > 0` 时同步加 `tally`，`Battle2.finish` 发勋章也改走 `_add_coin`。
- v1 存档读进来时由 `_migrate` 补齐：`segment = "ocean"`、`run` 取默认值、`map = {}`、`archive = {}`、`tally` 全为 0、`v = 2`。

**段切换** `_switch_segment(target)` 只能由两处触发：带 `branch` 的 `campaign.choose`，或带 `jump` 的大命运项。步骤如下，全部在 `send()` 的候选副本里做，失败就整体回滚：
1. 前置：`phase == "day"`，本场的仗已了结（`Battle2.resolved`），`big_fate.pending == false`。
2. `_tick_day()`。用"离开本章"规则让催逼到期，然后 `_check_failure()`；结果是 game_over 就停在这里。
3. 归档当前段：`archive[segment] = {scene_index, ending:"", ledger, clues, used_actions, chapter_balances, demands, map}`。
4. 按 `book.carry` 携带（`run_carry.gd`）：
   - `treasury` 取目标章的 `treasury_start`，再加旧余额 × `treasury_bonus`（1/4，向下取整；币制不同，所以按"军费结余折成经费"处理）；
   - `morale` 保留；
   - `vitality` 保留，但至少 40；
   - `heat / construction / exploration` 取目标段的 `initial`；
   - 旗标全部保留；
   - 物品只留 `items` 列出的几件，其余随归档；
   - `rogue` 全部保留：伙伴的死活、伤痕、等级，部队，道具，币按 `coin_cap` 截断，信赖，tally；`battle2` 重置成 `new_battle2()`，`march / calendar` 重置；
   - `army.chapter` 改为目标章，然后 `top_up_troops`。
5. 换定义：`definition = book.defs[target]`，`campaign = def.id`，`segment = target`；`scene_index` 取 `entry`（为空就取第一场）的下标；`phase = "year_jump"`，界面出章节卡或幕间插曲。
6. `run.path.append(target)`，`run.level_offset = branches[target].level_offset`，`run.chapter_ord += 1`。如果目标段有地图，就 `map = MapRules.open_sheet(target, 第一章)`。
7. `_record("segment_open", {from, to})`，然后 `_enter_scene()`。

**结局**：分支段的最后一场作出推进决定以后，按本段的 `rules.endings` 定结局。主干只有失败收场（军费告罄、兵疲、封锁、讣告、流放），**没有**正常结局。每个分支至少 2 个固定结局，另有 1 个 `default_ending`。`_valid_state` 允许的结局 = 全书 endings 的并集 + 四种失败 + `obituary` + `exile`。

### 1.7 存档、接续、重放

- **保存目录**：不变，仍是 `user://cards/ocean_pawn/`（内部名，玩家看不到；`card_save.gd` 不用改）。两本书共用一个 `suspend.json`，用信封里的 `meta.book` 区分。
- **文件**：

| 文件 | 何时写 | 说明 |
|---|---|---|
| `suspend.json` | 每条有效指令后（现状） | |
| `stage_%02d.json` | 每进一章 | 序号改用 `run.chapter_ord`，整局唯一且递增。开局时的初值 = 开局章在本段里的下标（`new_game` 的 `stage`），所以单段书里它恒等于现在的 `chapter_index`，`game.retry_stage` 的测试不受影响 |
| `branch.json` | 进入分岔场景 `elba_1815` 时 | 标题页「重返分岔」用。分岔是选择，不是随机，所以允许重选 |
| `napoleon_meta.json` | 每次 game_over | 局外记录：`{v:1, endings:{段:[id…]}, branches_reached:[…], trunk_cleared:bool, codex:{companions_met:[…]}}`。只由 bridge 读写，不碰旧的 `profile.json` |

- **信封 meta**：`{campaign, book, segment, stage: chapter_ord, abs_day, cmd_log, start}`。`CardSave.write` 会原样保留额外的 meta 键，这一点已经读过代码确认。
- **确定性**：内核里所有随机都改成 `Battle2.seed_for(seed, 键)`（FNV-1a 32 位），不再有任何"按天数拼公式"的随机。键表如下：

| 用途 | 键 |
|---|---|
| 锚点场景的战斗 | `scene_id`（不变，旧战斗种子不变） |
| 地图上的战斗节点 | `node|<段>|<节点>` |
| 地图骰子 | `dice|<段>|<run 内掷骰序号>`，结果 = `h % 6 + 1` |
| 行军牌组洗牌 | `deck|<段>|<章>`，再用 xorshift32 做 Fisher-Yates |
| 随机槽的类型 | `slot|<段>|<章>|<节点>` |
| 随机槽的事件 | `event|<段>|<章>|<节点>` |
| 天时 | `weather|<战斗键>` |
| 起手道具 | `seed` 的奇偶（不变） |
| 旧棋盘骰子（单段书） | 原公式不变，测试照旧 |

- **重放**：`run_replay.gd` 的 `verify(envelope) -> {ok, at, want, got}` 按以下步骤核对：
  1. 用 `meta.start` 加 `seed` 新开一个引擎；
  2. 依次 `send` 日志里的每条 `[cmd,args]`（跳过 `game.*`）；
  3. 每一步比较 `state_hash`，最后一步和信封的状态比。
  CI 用 `test_run_replay.gd` 对迷你书的「主干 → 每个分支 → 结局」各跑一遍。
- **体积**：`CardSave.write` 超过 512 KiB 会报 `save_too_large`。三小时一局、50 场仗的命令日志可能逼近这个上限，所以：
  - 每次段切换写一次检查点：`branch.json` 带整份状态；`suspend.json` 里 `cmd_log` 只从检查点算起，并带上 `meta.replay_base = {file:"branch.json", hash}`。
  - 归档里的 `ledger` 只留最后 40 条，外加一条 `{type:"summary", …}` 汇总。

### 1.8 远洋段怎样以最小改动变成远洋分支

| 位置 | 现在写死的 | 改成 | 归属 |
|---|---|---|---|
| `ocean_campaign._valid_definition` | `id == "ocean_pawn"`，`version == 1` | id 必须在书里，version ∈ {1,2} | A |
| `new_game` | opts 只认 seed/stage/campaign，且 `campaign == "ocean_pawn"` | 新增 `book`、`segment`、`carry`；campaign ∈ {`ocean_pawn`,`napoleon`} | A |
| `_ending / PERFECT_FLAGS / _check_failure` | 远洋专用 | 读 `rules.*`，缺省回落 `run_ocean_rules` | A |
| `_enter_scene / _expire_demands / _demand` | medicine、bond | 读 `on_enter.demands`，缺省回落 | A |
| `_visit / _trade / _project / _fund` | 金额、章节 id | 读 `rules.actions`；地图模式下还要求当前节点提供这个动作（§2.9） | A |
| `_valid_state` | 字段表、结局表、demand id、`open_panel` | 由书推出 | A |
| `RogueRules.create_initial_rogue` | 起手币和道具 | 读 `book.start_rogue`（缺省值 = 现值） | A |
| `Data.COMPANION_IDS / COMPANIONS`（RogueRules、Battle2、View 都在用） | 8 名伙伴 | `RogueRules.roster(campaign)` 返回全书伙伴表；单段书里就是 Data 里那 8 人 | A |
| `Battle2.prepare` 读 `scene_map[scene]` 的 `act` | 按幕 | 等级 `L = book.scene_battles[s].level`，或 `2·act−1 + run.level_offset`；地图战斗节点用节点自己的 `template/level` | A（用 B 的接口） |
| `Battle2.caps_for / hero_hp / lineup.enemy_morale` | 幕 | `BattleRules.caps(scale,L)`、`12+(L−1)`（上限取书的 `hero_hp_max`）、等级表 | A |
| `OceanView.SIDES` | 9 张营地牌 | 有地图时换成 `SIDES_MAP`（§2.10） | A |
| `ocean_bridge.selected / start / restore / saved_harvest` | 只认 ocean_pawn | 认两本书；常量 `DEFAULT_BOOK`（C3 改成 `"napoleon"`） | A |
| `card_engine.send(game.new)` | campaign ∈ {ocean_pawn, legacy} | 加上 `napoleon`；透传 `segment/stage/book` | A |

**id 冻结规则**（测试和存档都靠这些）：
- 冻结：远洋的场景、章节、抉择、查验（appraisal）、物品、旗标、伙伴、道具、币、羁绊的 id；全部 `campaign.*` 命令名和参数形状；查询键 `campaign / campaign.battle2 / campaign.battle_preview`；牌 uid（`story:* / battle / big_fate / demand:* / item:* / prop:* / companion:*`）；美术 id。
- 允许变：玩家看得见的文字、`v`（1→2，带迁移）、状态里新增的键。

**单段书的回归标准（A 的硬验收）**：
- 对 `test_campaign.gd` 的三条路线，在每一步都计算 `hash_v1(state)`：先去掉 `segment/run/map/archive` 和 `rogue.tally`，并把 `v` 记成 1，再求哈希。
- 这串哈希要与基线 31c0b3e5 录下的 golden 完全相等。golden 由 A0 在基线上录制，存到 `scripts/tests/cards/OCEAN/golden/ocean_routes.json`。

### 1.9 新段怎样复用同一个内核

- 新段只需要提供段定义、地图，再在书里登记，内核代码不分支：它不认识 `trunk`、`cristo` 这些名字，所有差异都写在 `rules`、`actions`、`on_enter`、`events`、`gauges` 里。
- 伙伴：`companions.json` 是全书总表。每人带 `segments`（在哪几段能招）、`battle`（兵种、数值、技能、宿命之地，原来放在 `ocean_battle.json.companions`）和 `bonds`（阵营标签）。
  - 唐泰斯、法利亚在远洋和伊夫堡两段用同一个 id，状态互通。
  - 主干的新伙伴（巴蒂斯特、科尔索、玛丽、小皮埃尔、米隆、拉雷、德塞、拉纳、缪拉……）同表登记。
  - `valid_rogue` 校验"伙伴数 = 总表人数"。
- 羁绊套：`battle_templates.json` 的 `bond_sets` 新增 `napoleon`，以 `ocean` 为基础，再加主干的阵营。一个书只用一套。
- 旗标前缀约定：主干 `t_`，鹰飞 `k_`，伊夫堡 `m_`，远洋保留原名。跨段读取的旗标必须登记在 `shared_flags` 里，校验器会拒绝读取未登记的跨段旗标。
- 币制：每章的 `currency / currency_name / treasury_start` 照旧。新币制（`franc`、`scudo`……）在 `ocean_battle.json.franc_rate` 里补上换算。

### 1.10 调试 / 测试入口

- **引擎**：`game.new {"campaign":"napoleon","segment":"cristo","stage":2,"seed":7}`。
  - 直接开某段第 2 章，套用 `book.debug_carry.cristo`；`run.start` 记下 `carry:"debug"`。
  - 整个过程确定、可重放，不需要任何"作弊命令"。
  - `{"campaign":"ocean_pawn"}` 走单段书回归。
- **命令行**：`--segment=cristo --stage=2 --book=napoleon`。由 `card_game_root._cmdline_opts` 解析，`_start` 透传 `segment/stage/book`（现在只透传 seed、save_dir、only_examples、data_root）。
- **环境变量**：`DEHOUDANG_CAMPAIGN=ocean_pawn|napoleon|legacy`，`selected()` 照此扩展；`DEHOUDANG_START=cristo:2` 只给无头测试用。
- **地图**：`--map-reveal` 只影响界面（雾全开，截图用），不进状态。
- **战斗**：`tools/battle_sweep.gd`（B）按"模板 @ 等级 × 种子"无头跑 `battle_policy`，输出胜率表（§3.6）。
- **测试辅助**：`scripts/tests/cards/OCEAN/run_helpers.gd` 提供 `start(engine, segment, stage, seed)`、`autoplay_to_end(engine)`（地图策略 `map_policy.gd` 加战斗策略 `battle_policy.gd`）。

---

## 2 世界地图层（取代营地和大富翁棋盘）

### 2.1 定位

- 每一段的积累阶段都发生在世界地图上，营地主画面（`hub_panel.gd`）在 napoleon 书里不再出现。
- 一章是一张图，叫一个 sheet。图分两个阶段：
  - **积累段**：自由走动，有随机槽、市镇、营地、商人、敌哨、驿站；
  - **战役段**：盖满驿站印、在 `muster` 节点宣布开拔以后才打开。路线基本是线性的：军议 → 精英战（可绕） → 野营夜 → Boss（本章的锚点会战）。
- 视图（只决定背景图和投影；节点自己给坐标）：
  - `europe`：经度 −11…44，纬度 28…61，含埃及；
  - `world`：经度 −180…60，纬度 −60…70，贝勒罗丰、圣赫勒拿、新厄尔巴、维哥、亚特兰蒂斯、泰晤士都在内；
  - `med`：经度 −2…17，纬度 36…50，马赛、伊夫堡、基督山岛、厄尔巴、罗马、巴黎都在内。
  - 局部图（`xy` 画布坐标，没有投影）：`if_fortress`（伊夫堡牢区）、`paris_1838`、`longwood`（圣赫勒拿岛）。

### 2.2 地图文件形状（定稿）

坐标一律用整数，以满足 `_integer_tree`：`geo = [经度×100, 纬度×100]`；`xy = [x, y]`，在 1920×1080 的画布上，有 `xy` 时优先用它。

```json
{
  "id": "world", "version": 1, "segment": "ocean",
  "views": {
    "world":    {"proj": "equirect", "lon": [-18000, 6000], "lat": [-6000, 7000], "bg": "map_world"},
    "longwood": {"proj": "canvas", "bg": "map_st_helena"}
  },
  "sheets": [{
    "chapter": "st_helena", "view": "longwood", "start": "jamestown", "days_max": 14,
    "stamps_need": 2, "muster": "muster_sh", "boss": "longwood_escape",
    "interlude": "audience",
    "sets": [{"id": "south_coast", "nodes": ["depot_a", "depot_b"], "bonus": {"pass_supply": 1}}],
    "rivals": [{"id": "lowe_patrol", "label": "总督巡逻队", "path": ["n4", "n5", "n6", "n5"], "speed": 1, "start": 0,
                "meet": {"battle": {"template": "skirmish_b", "level": 14}, "toll": {"gold": 1}}, "burns_depots": true}],
    "nodes": [
      {"id": "jamestown", "type": "story", "scene": "scene01", "label": "詹姆斯敦", "xy": [612, 540], "date": "1817-11-01",
       "phase": "accumulate", "fixed": true, "fog": "open", "actions": ["visit:town", "trade:fair", "trade:counterfeit"]},
      {"id": "n4", "type": "slot", "label": "海岸小路", "xy": [760, 470], "fog": "type",
       "slot": {"pool": "st_helena", "kinds": {"event": 5, "supply": 2, "camp": 2, "shop": 1, "battle": 2}, "level": 14}},
      {"id": "post_1", "type": "supply", "role": "post", "label": "信号站", "xy": [880, 420], "pass": {"stamp": 1, "coins": {"intel": 1}}},
      {"id": "n7", "type": "elite", "template": "sea_cave", "level": 15, "label": "南岸海蚀洞", "xy": [980, 640], "weather": ["clear", "storm"], "reward": {"props": ["prop_smoke_bomb"]}},
      {"id": "muster_sh", "type": "camp", "role": "muster", "label": "朗伍德外围", "xy": [1200, 500], "phase": "campaign"},
      {"id": "longwood_escape", "type": "boss", "scene": "scene05", "label": "朗伍德", "xy": [1400, 520], "phase": "campaign", "fixed": true}
    ],
    "links": [
      {"a": "jamestown", "b": "n4", "legs": 2, "supply": 1},
      {"a": "n4", "b": "post_1", "legs": 1, "route": "smuggle_route"},
      {"a": "post_1", "b": "n7", "legs": 2, "toll": {"gold": 1}, "oneway": false},
      {"a": "jamestown", "b": "st_helena_sea", "voyage_days": 3, "requires": {"scene_done": "scene03"}}
    ]
  }]
}
```

**节点字段**：

| 字段 | 类型 | 必需 | 说明 |
|---|---|---|---|
| `id` | String | ✓ | 在段内唯一 |
| `type` | `story/battle/elite/boss/event/camp/supply/shop/branch/slot` | ✓ | `slot` 是随机槽，进图时定成上面某一种 |
| `role` | `post/muster/depot/port/intel/project` | | 同一种 type 下的子用途 |
| `label` / `date` | String | ✓ / | 地名、史实日期（只用于显示） |
| `geo` / `xy` | int[2] | 至少一个 | 见上 |
| `phase` | `accumulate`（默认）/ `campaign` | | 战役段的节点在开拔前锁住 |
| `fixed` | bool | | 锚点或固定节点；`slot` 的这一项为 false |
| `scene` | 场景 id | story / boss / branch | 锚点。顺序必须与本章 `scene_ids` 一致（校验） |
| `template` / `level` | String / int | battle / elite / boss（不带 scene 时） | 带 scene 的节点用场景战斗 |
| `weather` | String[] | | 天时候选，开战时按种子挑一个 |
| `fog` | `open/type/hidden` | | 见 §2.5 |
| `requires` | 条件 | | 解锁条件（§1.5 的条件小语言） |
| `actions` | String[] | | 进入后能办的事，值就是原来的动作 id（§2.9） |
| `pass` | `{coins, metrics, stamp}` | | 每次到达都结算（大富翁"经过起点"） |
| `forced` | bool | | 落到这里必须先结算（敌哨、对手） |
| `once` | bool，默认 true | | 结算后变成 done；`supply` 与 `camp` 默认 false，但每天只能办一次 |
| `slot` | `{pool, kinds:{type:权重}, level}` | slot | |
| `reward` | `{coins, props, troops}` | | 战斗胜利后的额外奖励 |

**连线字段**：

| 字段 | 说明 |
|---|---|
| `a` / `b` | 两端节点 |
| `legs` | 1–4，陆路消耗的 MP |
| `voyage_days` | 大于 0 表示航程：不花 MP，整段用掉 n 天（逐日 `_tick_day`） |
| `supply` | 每次走过消耗的军需券 |
| `toll` | 过路费 |
| `oneway` | 单向 |
| `requires` | 通行条件 |
| `route` | 岔路标签，沿用旧的 `salon_route / duel_route / smuggle_route`，首次踏上给原路线奖励 |
| `rush` | 允许两场战斗紧挨着（§2.8） |

### 2.3 节点类型怎么结算（`campaign.map_enter`）

| type | 进入时 | 完成条件 | 来源（复用） |
|---|---|---|---|
| `story` | 只有 `scene == 当前场景` 才能进，否则锁住，原因「先完成：上一场标题」。进入后打开剧情牌（VN）；这一场有仗时，仗打完才能作推进决定（现状） | 场景推进 | `scenes` |
| `battle/elite/boss` | `campaign.battle_prepare`，战斗键是节点 → 出征名单 → 战斗 → 战果 | 胜利或撤出，或战败后大命运处理完 | Battle2 |
| `event` | 打开事件牌（VN 复用），带查验和抉择 | 作出抉择 | `events` |
| `camp` | 营地菜单，三选一：①周历动作之一（`schedule:*`）②休整（`activity:rest`）③羁绊夜话（`schedule:bond_story`）。`role:muster` 时多一项「开拔」 | 每天一次；muster 开拔后整张图进入战役段 | calendar / activities |
| `supply` | 市镇动作：`visit:town`、`trade:fair/counterfeit`、`build_depot`；`role:intel` 为 `visit:backdoor`；`role:project` 为 `build/explore/fund` | 每天一次 | town / backdoor / resources |
| `shop` | 随军商贩：用金币买道具，招部队（`recruit:troop:*`），招伙伴（`recruit:<id>`，只限 `segments` 含本段的） | 每天一次 | merchant / bazaar / recruit |
| `branch` | 打开分岔剧情牌，三个分支抉择，原因写在灰掉的选项上 | 切换段 | §1.6 |

### 2.4 行军规则（整数、确定）

1. 每个行动日（`phase == "day"`）可以"出一张牌或掷一次骰"，二选一，得到 `map.mp`：
   - `campaign.map_roll {}`：d6，键 `dice|…`。带 `{"steps":1..6}` 时是自选点数，要消耗遥控罗盘骰或 1 枚情报币（沿用旧 `_roll_dice` 的规则）。
   - `campaign.map_card {"index":i}`：打出一张行军牌，得到牌面的 MP 和附带效果。
2. 手牌：每天早上（`settle → morning`）补到 3 张，上限 4。牌组用完后按固定顺序收回弃牌，不再洗。
3. `campaign.map_move {"to":id}`：
   - 前置：有连线（`oneway` 只能按方向走）；`requires` 满足；`legs ≤ mp`；`map.pending` 为空。
   - 扣 `legs`；扣 `supply`。军需券不够时不拦，缺 1 张就体力 −5，记作断粮。
   - 过路费：用 `campaign.map_pay {"how":"gold"|"prop"|"fight"}` 结清。
   - 到达：`pos = to`，应用 `pass` 效果。如果节点 `forced` 且没完成，就设 `pending = to`，必须先 `map_enter`。
   - 一天可以连走几段，每到一个中途节点都结算一次 `pass`（大富翁的"路过"）。
4. 航程连线：要求当天还没移动、`mp == 0`，消耗 `voyage_days` 天（每天 `_tick_day`），然后到达。顺风牌让航程减 1 天，最少 1 天。
5. 日终：`campaign.wait`（原命令，界面上叫「扎营过夜」）→ `_tick_day`：对手移动，`mp` 清零，`days_on_sheet + 1`。
6. **天数预算**：`days_on_sheet > days_max` 以后，每多一天 `map.delay + 1`，本章 Boss 的敌军心因此 +2，最多 +8。到 `days_max + 4` 强制开拔：`pos` 跳到 muster，积累段节点全部锁住。早走有奖励：开拔时剩几天，第一场战役段战斗开场军令点就 +几，最多 +3（设计稿原规则）。

### 2.5 雾、侦察、解锁

- `fog`：
  - `open`：类型和内容全可见；
  - `type`：位置可见，类型显示「?」，离当前位置 2 段连线以内自动揭开；
  - `hidden`：相邻才出现。
- 揭开的节点记入 `map.revealed`，存档会带上。
- `campaign.map_scout {"node":id}`：花 1 枚情报币，揭开该节点，并显示随机槽里定下的类型和等级。黄铜望远镜揭开 2 段以内全部节点。
- 锁住的节点在查询里给 `state:"locked"` 和 `reason`（条件的原因键）。锚点锁的原因固定是 `scene_order`。

### 2.6 固定的与随机的

- **固定**：锚点节点（剧情场景）、Boss、分岔、结局。场景按 `scene_index` 线性推进，与现在的内核完全一样。地图只决定玩家在两场锚点之间做什么、走多久。
- **随机槽**：进入某章那一刻（`open_sheet`）一次性定好，写进 `map.slots[node] = {kind, id, level}`，之后读档、改数据都不再变：
  1. 按节点 id 排序，依次处理每个 `slot` 节点：`h = seed_for(seed, "slot|段|章|节点")`，按 `kinds` 权重定 kind。
  2. kind 为 `event` 时，候选 = 三层池里的可用事件。三层池依次是：本章池 `slot.pool`、本段通用池（`pool: "<段>"`）、全书通用池（`events_common.json`）。可用指 `requires` 在进图那一刻满足、`once` 事件不在 `run.events_seen` 里。用 `event|…` 键按 `weight` 挑一个，并记入 `events_seen`；候选为空就改成 `camp`。
  3. kind 为 `battle` 时，从 `book` 的等级段模板池（§3.3）里用同一个键挑模板，等级取 `slot.level`。
- **伙伴个人线**：事件 `requires: {"alive":["marie"], "stat":…}`，挂在本段通用池里；信赖越高，权重越大（`weight_by_trust`）。
- **事件形状**：与场景同构，所以 VN 和查验直接复用：

```json
{"id": "ev_storks_scale", "pool": "italy", "weight": 3, "once": true, "requires": {},
 "title": "白鹳商行的秤", "location": "萨沃纳", "speaker": "storks_agent", "body": ["……"],
 "appraisals": [{"id": "short_weight", "kind": "weigh", "label": "当场过秤", "observation": "……"}],
 "choices": [
   {"id": "expose", "label": "揭穿短秤", "requires_clues": ["short_weight"], "rogue": {"coins": {"supply": 4}}, "flags": ["t_storks_hostile"]},
   {"id": "kickback", "label": "收下回扣", "effects": {"treasury": 80}, "rogue": {"coins": {"supply": 2}}, "flags": ["t_kickback"]},
   {"id": "report", "label": "报告司令部", "rogue": {"coins": {"medal": 1}}, "days": 2}]}
```

  - 抉择专属的字段：`rogue`、`days`（消耗天数）、`battle`（`{template, level}`，就地开一场仗）、`reveal`（揭开节点）。
  - 事件里**禁止**出现 `branch`、`ending`、`advance`，校验器会拒绝。随机只发生在中段，结局由锚点场景的 `rules.endings` 决定。
  - 事件里的查验用 `campaign.map_appraise {"id"}`，抉择用 `campaign.map_choose {"choice"}`。使用记录键为 `event:<id>`，存进 `used_actions[当前场景]`，这样不用给 `_valid_state` 加新的分区。

### 2.7 大富翁手感：牌、币、道具落在地图的哪里

| 元素 | 地图上的用法 |
|---|---|
| 骰子 / 行军牌 | 决定每天走多远；牌带附加效果（侦察、辎重、夜行、强行军、顺风） |
| 驿站印（`role:post`） | 路过盖印，攒满 `stamps_need` 才能开拔 |
| 兵站（地产） | 在 `supply` 节点办 `build_depot`（2 金币），之后每次路过军需券 +1，停留时 +3 并且征兵减 1 金；凑齐 `sets` 有额外加成（比如西线、伦巴第）。对手分遣队停到你的兵站上会烧掉它 |
| 过路费 | 连线的 `toll` 和对手守着的节点：付金币、用道具，或者开打 |
| 对手分遣队（`rivals`） | 按 `path` 每天走 `speed` 格，下一步公开。碰上就是强制遭遇（`meet.battle` / `meet.toll`）。打掉一支，本章 Boss 少一波（`boss_waves_minus`） |
| 四种币 | 金币：招募、买东西、兵站、过路费。军需券：路费、出征时折成开场军令点（每 2 张 +1，最多 +4，设计稿原规则）。勋章：晋升、计入忠诚。情报：侦察、揭开猎官、自选骰点 |

道具：原有 8 张。不开地图时效果照旧；开地图时在原有的币和指标效果之外再加：

| 道具 | 地图上的附加效果 |
|---|---|
| `prop_loaded_dice` 遥控罗盘骰 | 今天自选骰点 1–6 |
| `prop_forced_march` 急行军靴 | MP +2 |
| `prop_spyglass` 黄铜望远镜 | 揭开 2 段以内的雾 |
| `prop_barricade` 铁木拒马 | 一支对手停 1 天 |
| `prop_bribe_pouch` 密使金币袋 | 免一次过路费或强制遭遇 |
| `prop_smoke_bomb` 掩护烟幕弹 | 脱离强制节点，不结算 |
| `prop_field_ration` 军粮桶 | 今天的路费军需券全免 |
| `prop_imperial_decree` 鹰徽嘉奖令 | 只有原效果 |

### 2.8 节奏（防单调）

同一张图上就有两个阶段，积累段里有仗，战役段里也有不打仗的节点。`map_validate.gd` 强制以下规则：
- **R1**：从起点到 Boss 的每条路上，至少 1 个 `camp`，至少 1 个 `supply` 或 `shop`。
- **R2**：战斗类节点（battle/elite/boss，以及战斗类随机槽）之间至少隔 1 个非战斗节点，连线标了 `rush` 的除外。
- **R3**：随机槽至少占节点数的 30%，每张图期望事件数 ≥ 3。
- **R4**：`elite` 不在必经路上，可以绕开。
- **R5**：战役段的顺序是 军议（固定事件，方略三选一，改的是 Boss 修正：`cp_bonus`、敌军心 −2、或多 1 回合）→ 精英（可绕）→ 野营夜（camp）→ Boss。
- **R6**：相邻两章的 `interlude` 类型不同。可选的类型：`council` 军议、`audience` 皇帝召见（3–5 道二选一）、`camp_night` 野营夜（5 项里给 3 项，选 1 项）、`bond` 营火夜话（挑两位伙伴，信赖 +1）、`minigame:<weigh|decode|ring|fragments>`（复用 v0.9 的查验小游戏）。幕间插曲在 `year_jump` 阶段以事件形式放出（`pool:"interlude:<类型>"`）。
- **R7**：`days_max ≥ 最短路径天数 + 3`。
- 节奏目标（设计稿）：每章大约是 积累 10 分钟 → 战役 15–18 分钟 → 插曲 3–5 分钟。长仗之后一定接一个轻节点。两场会战不相邻，主干最后两章例外，那里是高潮。

### 2.9 复用与新增

**复用**：

| 旧件 | 去处 |
|---|---|
| `MARCH_BOARD` 的 12 种格子效果（`_apply_tile_effect`） | 节点的 `pass` 与 `actions`：camp、town、recruit、salon、bazaar、duel、smuggle、shrine、gamble、festival、diplomacy、skirmish 各成一个动作 id，`_apply_tile_effect` 原样调用 |
| `ROUTES` 三条路线 | 连线的 `route` 标签，首次踏上时给原路线奖励 |
| `ACTIVITIES` 8 项 | camp、supply、shop 节点的动作 |
| `CALENDAR` 6 项 | camp 节点的周历菜单（`schedule:*`），每次停留排 1 项 |
| 四种币、8 张道具、羁绊、伙伴一条命、部队编制 | 原样 |
| 大命运 | 原样，另加段专属的 `big_fate_extra` |
| 挂牌 red/white/black（`campaign.sign`） | 改名「营令三色旗」，机制不变（§6） |
| 催逼（demands） | 地图顶栏的限期签，到对应节点或点牌交付 |

**新增命令**（只在白天；参数一律严格校验，键或类型不对返回 `bad_args`；失败时状态不变）：

| 命令 | 参数 | 主要的错误码 |
|---|---|---|
| `campaign.map_roll` | `{}` 或 `{"steps":int}` | `already_used`、`missing_item` |
| `campaign.map_card` | `{"index":int}` | `already_used`、`bad_args` |
| `campaign.map_move` | `{"to":String}` | `not_adjacent`、`locked`、`no_mp`、`pending_node`、`fog` |
| `campaign.map_enter` | `{}` | `locked`、`already_used`、`battle_pending` |
| `campaign.map_choose` | `{"choice":String}` | `missing_clue`、`missing_flag`、`insufficient_funds` |
| `campaign.map_appraise` | `{"id":String}` | `already_used` |
| `campaign.map_scout` | `{"node":String}` | `insufficient_funds` |
| `campaign.map_build` | `{}` | `insufficient_funds`、`already_complete` |
| `campaign.map_pay` | `{"how":"gold"|"prop"|"fight"}` | `bad_phase` |

**节点门禁**：书里开了地图时，`campaign.visit / trade / build / explore / fund / schedule / recruit / activity` 额外要求当前节点的 `actions` 里有这一项，否则返回 `wrong_node`。每场一次、每天一次的限制照旧。单段书不受影响。

**新增查询**：
- `campaign.map`：`{enabled, view, sheet, chapter, pos, mp, can_roll, hand:[{index,id,mp}], days, days_max, delay, stamps, stamps_need, depots, nodes:[{id,type,label,xy,state:hidden|fog|open|done|locked|current,reason,level,stars,reachable,cost:{legs,supply,toll}}], links:[{a,b,legs,voyage_days,state}], rivals:[{id,pos,next}], pending}`。只给可见的信息，雾里的节点不透露内容。
- `campaign.run`：`{book, segment, path, level_offset, chapter_ord, branch_offers:[{segment,ok,reason}], meta:{endings,branches_reached}}`。
- `campaign` 查询里新增 `segment`、`map`（摘要）、`run`（摘要）。

**`state.map` 形状**（由 `MapRules.valid` 校验）：

```
{"id", "sheet", "pos", "pending", "mp", "rolled_today", "rolls", "deck":[…], "hand":[…], "discard":[…],
 "visited":[…], "done":[…], "revealed":[…], "slots":{node:{kind,id,level}}, "stamps", "depots":[…],
 "rivals":{id:{step, stopped_until}}, "days_on_sheet", "delay", "mustered", "routes_taken":[…]}
```

### 2.10 界面接线

- **主画面**：`card_game_root._sync_hub` 先看 `query(campaign.map).enabled`：
  - true：建 `map_panel.gd`（满屏），不建 `hub_panel.gd`。顶栏、名册、币、行军箱这几个部件取自 `hub_kit.gd` 和 `hub_panel` 的绘制函数，只读不改。
  - false：照旧建 `hub_panel.gd`，这是单段书的路径。
- **牌桌**：
  - `OceanView.SIDES_MAP = ["order", "squad", "status"]`，再加 `story:<当前场景>`、`battle`、`big_fate`、`node:<当前节点>`、`demand:*`、`prop:*`、`item:*`。
  - `node:<id>` 牌的 choices 是该节点 `actions` 映射出的原有动作 id（`action:visit:town` 等），外加 `action:map_enter`。`ocean_bridge._choice` 只需加上 `map_enter / map_choose / map_build / map_pay` 四个分支。
  - 事件牌 `event:<id>` 的 panel 设为 `vn`，文字走 `ocean.event.<id>` 覆盖层，结构与 `ocean.scene.<id>` 相同。VN 需要支持这一种 def 前缀，这是一处小改，由 A 改，要先和正在修 VN 的代理确认。
- **面板登记**：`modal_host.gd` 的 `SCRIPT_PANELS` 加 `map_shop`、`map_camp`、`map_interlude`，`FULLSCREEN` 加 `map`。
- **自动游玩**：`map_policy.gd`（测试用）每一步给出确定的动作：
  1. 有 pending 就进入；
  2. 掷骰；
  3. 沿最短路走向当前锚点，顺路进入 camp、supply、event 节点；
  4. 事件选第一个可选项；
  5. 有仗交给 `battle_policy`；
  6. 走不动就扎营。

---

## 3 等级难度

### 3.1 定义

- 每个战斗节点有一个整数等级 L，取值 1–24，全局编号：
  - 主干 L1–12：土伦 L1 → 意大利 Boss L3 → 埃及或马伦哥 L5 → 奥斯特里茨或耶拿 L7 → 西班牙或瓦格拉姆 L9 → 俄罗斯或莱比锡 L11 → 厄尔巴 L12；
  - 分支 L13–24。
- 远洋场景的等级 = `12 + 2·act − 1`：

| 场景 | 等级 |
|---|---|
| prologue / scene01 / scene02 | L13 |
| scene03–05 | L15 |
| scene06–07 | L17 |
| scene08–09 | L19 |
| scene10–11 | L21 |
| scene12 / finale | L23 |

- 鹰飞与伊夫堡同样分布在 L13–24，各章 Boss 依次是 L14 / 16 / 18 / 20 / 22 / 24。
- **逐章更难**由书校验强制：
  - 按游玩顺序，Boss 等级严格递增；
  - 同一章内，`battle ≤ Boss − 2`，`elite ≤ Boss − 1`；
  - 分支第一场 ≥ 主干最后一场 + 1。
- 内核兼容：`new_battle` 的 setup 新增 `level`；没给时取 `level = 2·act − 1`。所有按幕的旧调用，结果逐字节不变。状态里新增 `level`、`weather` 两个键，`v` 仍为 2；读旧存档时用 `get` 取默认值，`load_state` 不用改。

### 3.2 等级表（B 写进 `battle_rules.gd` 的常量 `LEVELS`，下标是 L−1）

奇数行 L1、3、5、7、9、11 与现在的 `ACT_HP_PCT / ACT_MORALE_PCT / ACT_ATK_BONUS` 第 1–6 幕**完全相同**。

| L | 敌兵力% | 敌军心% | 敌攻+ | 敌防+ | Boss 猎官 | Boss 精英 | 精英战猎官 | 遭遇战猎官 | Boss 回合 | 精英/遭遇回合 | ★ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 100 | 100 | 0 | 0 | 0 | 1 | 0 | 0 | 11 | 8/6 | 1 |
| 2 | 108 | 104 | 0 | 0 | 0 | 1 | 0 | 0 | 11 | 8/6 | 1 |
| 3 | 115 | 109 | 0 | 0 | 1 | 2 | 0 | 0 | 11 | 8/6 | 1 |
| 4 | 122 | 113 | 0 | 0 | 1 | 2 | 0 | 0 | 11 | 8/6 | 1 |
| 5 | 130 | 117 | 1 | 0 | 1 | 2 | 0 | 0 | 11 | 8/6 | 1 |
| 6 | 137 | 125 | 1 | 0 | 1 | 2 | 0 | 0 | 11 | 8/6 | 2 |
| 7 | 145 | 134 | 1 | 0 | 2 | 3 | 0 | 0 | 12 | 8/6 | 2 |
| 8 | 152 | 138 | 1 | 0 | 2 | 3 | 0 | 0 | 12 | 8/6 | 2 |
| 9 | 160 | 142 | 2 | 0 | 2 | 3 | 1 | 0 | 12 | 8/6 | 2 |
| 10 | 170 | 154 | 2 | 0 | 2 | 3 | 1 | 0 | 12 | 8/6 | 2 |
| 11 | 180 | 167 | 2 | 0 | 3 | 4 | 1 | 0 | 12 | 8/6 | 3 |
| 12 | 188 | 172 | 2 | 0 | 3 | 4 | 1 | 0 | 12 | 8/6 | 3 |
| 13 | 196 | 177 | 3 | 0 | 3 | 4 | 1 | 1 | 13 | 9/7 | 3 |
| 14 | 204 | 182 | 3 | 0 | 3 | 4 | 1 | 1 | 13 | 9/7 | 3 |
| 15 | 212 | 187 | 3 | 1 | 4 | 5 | 1 | 1 | 13 | 9/7 | 3 |
| 16 | 220 | 192 | 3 | 1 | 4 | 5 | 1 | 1 | 13 | 9/7 | 4 |
| 17 | 228 | 197 | 4 | 1 | 4 | 5 | 2 | 1 | 13 | 9/7 | 4 |
| 18 | 236 | 202 | 4 | 1 | 4 | 5 | 2 | 1 | 13 | 9/7 | 4 |
| 19 | 244 | 207 | 4 | 1 | 5 | 6 | 2 | 1 | 14 | 9/7 | 4 |
| 20 | 252 | 212 | 4 | 1 | 5 | 6 | 2 | 1 | 14 | 9/7 | 4 |
| 21 | 260 | 217 | 5 | 2 | 5 | 6 | 2 | 2 | 14 | 9/7 | 5 |
| 22 | 270 | 222 | 5 | 2 | 5 | 6 | 2 | 2 | 14 | 9/7 | 5 |
| 23 | 280 | 227 | 5 | 2 | 6 | 6 | 2 | 2 | 14 | 9/7 | 5 |
| 24 | 290 | 232 | 5 | 2 | 6 | 6 | 2 | 2 | 14 | 9/7 | 5 |

公式（表格是准的，公式只是帮助理解）：
- 敌攻加成：`(L+3)/4 − 1`；敌防加成：`max(0, (L−9)/6)`。两者都只加在原值大于 0 的敌人身上，与现在的攻加成规则一致。
- 兵力：L ≥ 11 时 `180 + 8(L−11)`，L ≥ 22 起每级 +10。军心：L ≥ 11 时 `167 + 5(L−11)`。
- 猎官：Boss `(L+1)/4`；精英战 `(L−1)/8`；遭遇战 `max(0,(L−5)/8)`。精英数：Boss `min(6, 1+(L+1)/4)`。
- 回合：Boss `11+(L−1)/6`，精英 `8+(L−1)/12`，遭遇 `6+(L−1)/12`。
- 星级：`1+(L−1)/5`。
- 斩首令：原规则是「第 4 幕起」，改为 L ≥ 7，且不在遭遇战。
- 主角兵力：`min(hero_hp_max, 12+(L−1))`，在 L=2a−1 处等于原来的 `12+2(a−1)`。

猎官、精英、回合三列是**模板编写目标**，不是运行时硬改：
- 校验器检查模板在其等级段内达到这三列（猎官和精英按 `lv_min` 生效后的波次计数）。
- 运行时只做这几件事：按表缩放兵力、军心、攻、防；按 `lv_min` 开关波次和单位；按 `pad` 补兵（§3.3）。
- 旧字段 `act_min` 按 `lv_min = 2·act_min − 1` 解释，等价性：L=2·act−1 时，`L ≥ 2a−1 ⇔ act ≥ a`。

### 3.3 规模、尺寸、名额、补兵

| 节点 | L1–6 | L7–12 | L13–18 | L19–24 |
|---|---|---|---|---|
| battle（scale skirmish） | 7×3 | 7×3 / 8×3 | 8×4 | 8×4 / 9×4 |
| elite（scale elite） | 8×4 | 8×4 / 9×4 | 9×5 | 10×5 |
| boss（major → grand → epic） | 9×5 | 9×5 / 10×5 | 10×6（grand） | 11×6 / 12×7（epic） |

- `SCALES` 新增：
  - `grand`（大会战，默认 10×6，法郎 260，勋章 4，金币 1）；
  - `epic`（决战，默认 12×7，法郎 320，勋章 5，金币 2）。
- 模板可以写 `size:[cols,rows]` 覆盖 scale 的默认尺寸，范围 5×3 到 12×7。scale 只决定名额和奖赏。
- **在场 / 伙伴名额** `BattleRules.caps(scale, L)`：
  - 旧三档：L ≤ 11 时取原数组的第 `(L+1)/2` 项，等于现状；
  - L ≥ 12：skirmish 5/2（L ≥ 13 时 6/2），elite 6/3（L ≥ 13 时 7/3），major 9/5，grand 10/5（L ≥ 19 时 11/6），epic 11/6（L ≥ 19 时 12/6）。
- **补兵**：模板写 `"base_level": b, "pad": {"kind": "redcoat", "every": 6}` 时，每一波补 `max(0, (L−b)/every)` 个该兵种，这类模板适用 L ∈ [b, b+11]。旧模板没有 `pad`，不受影响。
- **战斗模板池**（随机槽用，写在 `book.json` 的 `battle_pool`）按段和等级段列出，例如 `{"trunk": {"1-6": ["skirmish_a","skirmish_b","skirmish_c"], …}, "ocean": {"13-18": ["beach_landing","shipwreck_beach"], …}}`。
- **奖赏**：只在战役层缩放，规则内核的 `result()` 不变。napoleon 书的法郎 × `(100 + 4·(L−1))/100`；分支段 L ≥ 13 的 Boss 勋章 +1。单段书不缩放。

### 3.4 显示

- **出征名单和地图节点**：显示「Lv 14 · ★★★」、规模、尺寸、回合、敌军心、天时，以及**推荐战力**：
  - `enemy_power = Σ(本场所有会出现的敌人) hp(L) × (atk(L) + def(L) + 2·spd + (range>0 ? 2 : 0)) / 10`，炮按 `hp × (atk+4) / 10` 算，`pad` 补的兵也算在内；
  - `party_power = Σ(出征名单) max_hp × (atk + def + block) / 10`，主角上阵时也计入；
  - 推荐值 = `enemy_power × 110 / 100`，系数按 §3.6 校准。
  - 界面写「推荐 1320 / 当前 1180」：当前 ≥ 推荐为金色，≥ 80% 为琥珀色，否则红色。
- B 提供 `BattleRules.power(template_id, L, setup)`（纯函数），A 在 `lineup()` 和 `campaign.map` 里调用。

### 3.5 兼容保证（B 的硬验收）

- `test_battle_v2.gd` 一字不改，全部通过。
- 新增 golden：对 `battle_templates.json` 里现有的 7 张模板，取第 1–6 幕、种子 1–3，各跑一条固定的 60 步随机指令序列（沿用 `test_battle_v2` 的生成器），记录 `JSON.stringify(result)` 和去掉 `level`、`weather` 两个新键之后的状态哈希。改动之后必须逐条相等。

### 3.6 用自动打法模拟来校验（`test_battle_levels.gd` 与 `tools/battle_sweep.gd`）

- 打法：`battle_policy.gd`，它是确定性的、比较弱的打法。B 更新它的 GROUND/HIGH 判断，改为调用 `Rules.can_stand`。
- 参考名册 `ref_rosters.json`，按 L 给出"按进度应有的队伍"：
  - 部队数 `min(8, 4 + L/4)`；
  - 伙伴数 = 当前等级的伙伴名额；
  - 伙伴数值 × `(100 + 5(L−1))/100`，近似晋升的效果；
  - 主角不上阵。
  - 另有 `R1`：固定的起步名册。
- 指标（N 是种子数：默认 8，设 `DEHOUDANG_SWEEP=1` 时 30）：
  - `W(T,L,R)`：胜率；
  - `S(T,L,R)`：安全余量，胜局取 `100 × 最终军心 / 开场军心`，败局计 0，求均值。
- **验收**（每个模板只在自己的等级段 `[b, b+11]` 内取 L = b、b+3、b+6、b+9 四点）：
  - **A1 单调**：固定名册 R(b) 下，W 不升；S 严格下降，每一步至少降 5 分。
  - **A2 没有白给**：参考名册 R(L) 下，遭遇战 W ≤ 95% 且 S ≤ 85，精英战 W ≤ 90%，Boss W ≤ 85%。弱打法都能轻松大胜，说明这一级太简单了。
  - **A3 打得过**：参考名册 R(L) 下，遭遇战 W ≥ 50%，精英战 ≥ 35%，Boss ≥ 25%。真人的目标胜率（Boss 从第一章 85% 降到最后 50%）要靠试玩去调。
  - **A4 被动必输**：现有的「只按交火」「只放主角」两项测试扩展到所有模板 × 上面四个 L，全部失败。
  - **A5 逐章更难**：沿书的游玩顺序，相邻两章的 Boss 满足 `enemy_power(k+1) ≥ enemy_power(k) × 112/100`。由书校验加 B 的 `power()` 检查。
  - **A6 确定、整数**：同一种子两次跑出的 `result` 相等；状态、视图、预演、结算里都没有浮点数（沿用现有检查）。
- 默认跑冒烟子集：每个模板取 2 个 L × 3 个种子，控制在 240 秒内。完整扫描由 `tools/battle_sweep.gd` 输出 `docs/cards/balance/levels.md` 表格。

---

## 4 复杂地形

### 4.1 现状（读代码确认）

- 地形是单字符地图，`TERRAIN_CHARS` 有 11 种，外加工兵筑出的胸墙。
- 站位：`GROUND`（平地、道路、村庄、树林、桥、浅滩）和 `HIGH`（高地、胸墙）；`ENEMY_WALK` 限定敌人能走的格子；敌人只沿模板给定的路线走。
- 地形效果只有两条：村庄双方防 +2，树林双方挨远程时防 +2。
- 河和沼泽既不能站也不能走。射程图样不看地形，没有视线概念。
- 尺寸由 scale 固定：7×3、8×4、9×5。
- 3D 场地（`field_terrain.gd`）按地形取顶面高度、贴图和摆件；行列数从视图读，本身不写死尺寸。

### 4.2 地形规则表（B 在 `battle_rules.gd` 里新建 `TERRAIN` 表）

`GROUND / HIGH / ENEMY_WALK` 三个常量保留，但改由这张表推出，界面和打法照旧能引用；另新增 `TOP`。

| 字符 | id | 名称 | 站位 | 敌人可走 | 步耗 | 防+ | 远防+ | 挡视线 | 层 | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|
| `.` | plain | 平地 | ground | ✓ | 1 | 0 | 0 | | 1 | 旧 |
| `^` | high | 高地 | high | | | 0 | 0 | | 2 | 旧 |
| `=` | road | 道路 | ground | ✓ | 1 | | | | 1 | 旧 |
| `v` | village | 村庄 | ground | ✓ | 1 | 2 | | | 1 | 旧，对双方都生效 |
| `w` | woods | 树林 | ground | ✓ | 1 | | 2 | | 1 | 旧，对双方都生效 |
| `~` | river | 河 | none | | | | | | 0 | 旧 |
| `b` | bridge | 桥 | ground | ✓ | 1 | | | | 1 | 旧 |
| `f` | ford | 浅滩 | ground | ✓ | 1 | | | | 1 | 旧，逻辑层取 1（3D 里照样下沉） |
| `m` | marsh | 沼泽 | none | | | | | | 0 | 旧 |
| `G` | gate | 红门 | none | 起点 | 1 | | | | 1 | 旧，可以有多个 |
| `E` | eagle | 鹰旗 | none | 终点 | 1 | | | | 1 | 旧，可以有多个 |
| `+` | earthwork | 胸墙 | high | | | | | | 2 | 预先筑好（id 原本就有） |
| `_` | void | 虚空 | none | | | | | | – | 不属于战场：不画，射程跳过，冲锋到此停；视线不挡 |
| `#` | wall | 墙 | none | | | | | ✓ | 3 | 事件可以把它变成瓦砾（轰开缺口） |
| `;` | rubble | 瓦砾 | ground | ✓ | 2 | 1 | | | 1 | |
| `s` | snow | 雪地 | ground | ✓ | 2 | | | | 1 | |
| `u` | mud | 泥地 | ground | ✓ | 2 | | | | 1 | 骠骑兵冲锋进入就停 |
| `i` | ice | 冰面 | ground | ✓ | 1 | | | | 1 | 事件「冰裂」可以把它变成河（§4.3） |
| `a` | sand | 沙地 | ground | ✓ | 1 | | | | 1 | |
| `n` | dune | 沙丘 | high | | | | | | 2 | |
| `o` | well | 水井/绿洲 | ground | ✓ | 1 | | | | 1 | 沙漠天时的补水点 |
| `d` | deck | 甲板 | ground | ✓ | 1 | | | | 1 | |
| `q` | quarterdeck | 艉楼/艏楼 | high | | | | | | 2 | 舰炮的 at 格 |
| `t` | rigging | 桅盘 | top | | | | | | 3 | 只有猎兵类能上 |
| `\|` | mast | 桅杆 | none | | | | | ✓ | 3 | |
| `W` | sea | 海 | none | 只有船 | | | | | 0 | 炮艇的 at 格 |
| `-` | shallows | 浅水 | none | ✓ | 2 | | | | 0 | 登陆、涉水 |
| `*` | reef | 暗礁 | none | | | | | | 0 | |
| `,` | beach | 沙滩 | ground | ✓ | 1 | | | | 1 | 岸防炮的 at 格 |
| `c` | cave | 洞穴 | ground | ✓ | 1 | | 2 | ✓ | 1 | 敌炮不瞄准洞里的单位 |
| `k` | dock | 码头 | ground | ✓ | 1 | | | | 1 | |
| `p` | plank | 跳板 | ground | ✓ | 1 | | | | 1 | 登船路线可以从这里起 |
| `H` | hatch | 舱口 | none | 起点 | 1 | | | | 1 | 出生格，同红门 |
| `S` | street | 街道 | ground | ✓ | 1 | | | | 1 | |
| `B` | building | 房屋 | ground | | | 2 | | ✓ | 1 | 我方可以进驻，敌人不走；视线穿不过去，但屋里的单位能向外射击 |
| `R` | rooftop | 屋顶 | top | | | | | | 3 | 只有猎兵类能上 |
| `C` | corridor | 牢廊 | ground | ✓ | 1 | | | | 1 | 黑暗 |
| `L` | cell | 牢房 | ground | | | 1 | | | 1 | |
| `D` | door | 牢门 | none | 起点或途经 | 1 | | | | 1 | 出生格；事件可以把它锁成墙 |
| `K` | catacomb | 墓穴 | ground | ✓ | 1 | | | | 1 | 黑暗 |

几条约定：
- 「站位」决定我方哪些兵种能部署：`ground` 给 place=ground 或 any 的兵种；`high` 给 place=high 或 any 的兵种；`top` 只给 `CLASSES[cls].top == true` 的兵种，目前只有 `jager`（含猎兵兵种的伙伴）。
- 「步耗」只用在敌人沿路线移动时：每走一格扣该格的步耗，速度不够就停在原地；旧地形全是 1，所以旧行为不变。
- 校验：路线中段的格子必须是敌人可走的格子。

### 4.3 新规则细则（只对新地形生效）

- **视线**：
  - 小火器（我方 line、jager；敌方 range > 0 且不是炮的单位）需要视线；炮兵和敌炮是曲射，不看视线。
  - 视线用整数 Bresenham 算：沿长轴逐格前进，平局时取行号较小的一侧。两端之间（不含两端）只要有「挡视线」的格子就不通。
  - 我方的射程图样本来就是直线，效果等于「图样在第一个挡视线的格子处截断」。
  - 敌方远程锁定和出手时，额外要求视线通；不通就只能打挡住它的那个单位。
- **顶层**（层 3，即 `t` 和 `R`）：站在顶层的射手，射程图样长 +1（横队 1–3 格，猎兵 1–4 格）；目标格的层 ≤ 1 时攻 +1。敌方桅顶射手同理。敌炮选目标时把顶层当高地处理（排在地面单位后面）。
- **黑暗**（`C`、`K`，以及 night 天时）：射手所站的格子是黑暗格时，射程 −1，最少 1。
- **洞穴**：`_gun_pick` 跳过站在洞里的单位，洞里的单位挨远程时防 +2。
- **事件改地形时格子上有单位**（`_begin_turn`）：
  - 我方单位所站的格子变得不能站（比如冰裂成河）：单位退回部署栏，状态 `bar`，冷却 2 回合，不算倒下，不退军令点；拒马直接移除。
  - 敌人所站的格子变得不能走：敌人移除，按击杀扣敌军心，日志写「落水 / 坠落」。
  - 旧模板的事件只会把河变成浅滩，没有这两种情况，所以旧行为不变。
- **击杀触发的事件**：模板的 `events` 允许写 `{"on_kill": "turnkey_chief", "cell": "D3", "terrain": "corridor"}`，用来表现杀掉典狱长、牢门打开。在 e 步、清点阵亡（`_sweep`）之后结算。
- **出生格**：路线起点 ∈ {gate, hatch, door}。带 `ambush` 或 `boarder` 标签的波次，还可以从模板 `spawns` 里列出的格子出生（村庄、树林、街道、墓穴、跳板）。
- **路线时效**：路线可以写 `"until": 回合`。校验器只检查从首次使用到 `until + 路线长度` 这段时间里的地形，这样「锁门」「炸桥」才有可能实现。没写 `until` 的路线仍按现在的规则检查「首次使用时」和「最终地形」两个时刻。
- **多门、多鹰旗**：现在就允许，并保持允许。任何一面鹰旗被走进都扣军心。

### 4.4 天时（`state.weather`，开战时定下，战斗中不再变）

| 天时 | 规则 |
|---|---|
| clear | — |
| rain | 小火器攻 −1，伤害仍至少 1；炮不受影响 |
| mud | 敌骑兵（type 为 cavalry）在所有格子的步耗 +1；我方骠骑兵冲锋距离 −1 |
| snow | 我方每回合军令点 −1（3→2）；军医回复 −1 |
| fog | 来敌提前公开的回合数 −1（2→1；情报羁绊三档时 3→2） |
| night | 所有远程射程 −1（同黑暗）；来敌提前公开的回合数 −1 |
| desert | 第 3、6、9……回合的 e 步：我方在场单位如果 1 格内（含本格）没有水井，兵力 −1，但不会因此倒下（最低留 1） |
| storm | 每回合 e 步结束时，桅盘上的我方单位兵力 −1（最低留 1）；敌炮艇每 3 回合开一炮（平时 2 回合） |

天时由节点 `weather` 列表按 `weather|…` 键挑选，节点没写就用模板默认值，再没有就是 clear。旧状态读进来没有 weather 键时按 clear 处理。

### 4.5 `battle_rules.gd` 要改的地方（函数级）

| 位置 | 改动 |
|---|---|
| `TERRAIN_CHARS / TERRAIN_NAMES` | 补齐 §4.2 的全部地形 |
| 新增 `TERRAIN` 表 | 各地形的规则；新增 `TOP`；由表推出 `GROUND / HIGH / ENEMY_WALK`；新增 `can_stand(cls, terrain)`、`walk_cost(terrain, enemy)` |
| `SCALES` | 加 `grand`、`epic`；新增 `caps(scale, L)` |
| 新增 `LEVELS`、`level_of_act(a)`、`row(L)` | 保留 `ACT_*` 常量，仅为兼容 |
| `new_battle` | 支持 `size`、`level`、`weather`、`lv_min`、`pad`；`state` 加 `level`、`weather` |
| `validate_template` | 检查尺寸上限、新字符、虚空格不在路线上、出生格、`until`、at 格的地形（按敌兵种的 `at_terrain`）、`post/top/boat` 标签与站位一致、等级段目标（警告级） |
| `_spawn_wave` | 用 `LEVELS[L]` 的兵力、攻、防，并按 `pad` 补兵 |
| `_unit_def / _enemy_def / _dmg_to_unit` | 防和远防改由表驱动，旧地形数值相同 |
| `_place_err` | 改用 `can_stand` |
| `_move_enemy` | 按步耗扣速度预算，并处理 mud 天时 |
| `_pattern_cells` | 跳过虚空格，处理视线截断、顶层 +1、黑暗 −1 |
| `_pick_ranged_target / _ranged_valid_target` | 加视线判断和黑暗 |
| `_gun_pick` | 跳过洞穴，处理顶层 |
| `_hussar_charge` | 遇到不能走的格子、虚空、墙、泥地就停 |
| `_begin_turn` | 事件改地形时处理格子上的单位，并支持 `on_kill` 事件 |
| `_cp_gain / _horizon / _step_e` | snow、fog、night、desert、storm |
| `_decapitation` | 条件改为 `L ≥ 7` |
| `view` | 加 `level`、`weather`、`cells[].tier / los / stand / dark` |
| `load_state` | 不变（v 仍为 2，新键用 get 取默认值） |

确定性：只用整数；战斗中仍然没有随机数；天时和补兵都在进场时定下。

### 4.6 3D 场地与美术清单需要什么（B）

**`field_terrain.gd`**：
- 新地形的顶面高度 `TOP`：
  - sea 0.0（有波纹）、shallows 0.06、reef 0.04（加礁石摆件）；
  - deck 0.30、quarterdeck 0.62、rigging 1.10（桅上小平台）；
  - wall 0.90、building 0.18（加房屋摆件）、rooftop 0.75；
  - corridor、cell、door 0.18（暗石材质），catacomb 0.12；
  - snow、mud、ice、sand、well 0.18，dune 0.5；
  - void 不建地块，四周的底座沿不规则外轮廓走。
- `FLOW` 加 sea、shallows。侧面贴图新增 `side_wood`（船体）、`side_stone`（墙和牢）、`side_sand`。

**`field_props.gd` / `battle_board.gd`**：
- 新摆件：mast、rigging_top、ship_rail、ship_cannon、wall_segment、house_c、roof、cell_bars、prison_door、ossuary、reef_rocks、palm、well、ice_cracks、snow_pine。
- `HATS / GEAR / CAVALRY / GUNS` 补上 §5 的新敌人。炮艇用船体网格。
- 天时特效：雨、雪粒子，雾（WorldEnvironment），夜间灯光，沙尘，风暴（浪加轻微倾斜）。

**相机与界面**：
- `field_cam.fit` 要验证 12×7 在 1280×720 逻辑画布、去掉 HUD 安全区以后，每格不小于 44 像素（可点击）。
- 列标签用 A–L。
- `battle_lineup_panel` 的小地图、`battle_panel` 的图例和可部署高亮改用 `Rules.can_stand`，不再直接读 `Rules.GROUND`。

**文字**：`battle_ui.json` 补 `legend_order / legend_swatch / enemy_char`，覆盖全部新地形和新敌人；`hud_portrait.gd` 补帽型。

**`data/hd/art_list.json`**（只由 B 写；A 和 C 把需求写在 `data/hd/art_requests/<包>.json`，由 B 合入）：
- `tex`：snow、mud、ice、sand、dune_top、well、deck_planks、quarterdeck_planks、sea、shallows、reef、beach、cave_floor、dock_planks、plank、hatch、cobbles、building_floor、roof_tiles、prison_stone、cell_floor、catacomb_floor、rubble；
- `side`：side_wood、side_stone、side_sand；
- `prop`：上面列出的新摆件；
- `unit` 与 `face`：§5 的每个新敌人和新伙伴；
- 地图背景 `bg`：map_europe、map_world、map_med、map_st_helena、map_if_fortress、map_paris；
- 新增一个 kind `icon`：`art/hd/icon/{id}.png`，256×256，透明底。用于地图节点圆章，共 11 种：story、battle、elite、boss、event、camp、supply、shop、branch、muster、post。

---

## 5 敌军名册（`ENEMIES` 形状）

形状照旧：`{name, hp, atk, def, spd, type, range, tags}`，数值是 L1 基线，运行时按等级表缩放。新增两个可选键：`at_terrain`（允许出现的 at 格地形）、`move`（`foot` 默认，或 `boat`）。`type` 仍只有 infantry/cavalry/elite/leader/wagon/gun 六种，`KILL_ENEMY_MORALE` 不变。

**内核要认识的新标签**：

| 标签 | 规则 |
|---|---|
| `pierce` | 挡住它需要的空余阻挡值 +1（普通敌人 1→2，重型 2→3），占用的阻挡值照常（马穆鲁克冲锋「无视 1 点阻挡」） |
| `skirmisher` | c 步之后如果还活着，下一回合 b 步先后退 1 格，并脱离阻挡；每 2 回合一次（复用 `retreat_turn / _knockback`） |
| `ambush` | 这一波从模板 `spawns` 里的格子出生 |
| `boarder` | 路线起点可以是跳板或舱口 |
| `post` | 定点不动的远程，spd 为 0，用 `at` 波次出场（不再只限于炮） |
| `top` | 只能出现在顶层的 at 格 |
| `stealth` | 离我方所有单位都超过 2 格时，视图里显示为「?」（隐去兵种、名字、标签和兵力）。规则不变，预演只给伤害数 |
| `loot` | 走进鹰旗时照常扣军心，另记 `state.loot + 1`；战后每个 loot 让法郎 −15%，最低到 0 |
| `ransom` | 走进鹰旗时另记 `state.ransom + 1`；战后每个 ransom 扣 1 金币，最低到 0 |
| `arrest` | 主角在它的白刃下倒下时不掷铜钱，直接被俘（`result.captured` 里有 hero）。战役层据此转入大命运「被捕」，伊夫堡分支可以借它进入牢狱章 |
| `rally` | 同纵队攻 +2，取代纵队长原来的 +1 |
| `boat` | 只能站在海格（at 格） |
| `short` | 炮只瞄与自己列差 ≤ 4 的格子 |
| `rocket` | 打准星格，同时以半伤打准星格靠鹰旗方向（列号 −1）的那一格 |
| `sniper` | 远程挑目标时优先主角和伙伴，其次精英、军官 |

现有标签 `hunter / heavy / officer / execute` 不变。

**主干**（意大利已有奥军：whitecoat、grenz、dragoon、hungarian、leader、wagon、gun）：

| id | 名字 | hp | 攻 | 防 | 速 | type | 射程 | 标签 |
|---|---|---|---|---|---|---|---|---|
| mamluk | 马穆鲁克骑兵 | 9 | 6 | 1 | 2 | cavalry | 0 | pierce |
| janissary | 耶尼切里 | 11 | 5 | 1 | 1 | elite | 0 | heavy |
| nizam | 奥斯曼步兵 | 6 | 3 | 0 | 1 | infantry | 0 | |
| bedouin | 贝都因骑手 | 6 | 3 | 0 | 2 | cavalry | 0 | skirmisher |
| bey | 贝伊 | 11 | 4 | 2 | 1 | leader | 0 | officer |
| ottoman_gun | 奥斯曼炮 | 8 | 6 | 0 | 0 | gun | 99 | |
| redcoat | 英军战列步兵 | 7 | 4 | 1 | 1 | infantry | 0 | |
| rifleman | 绿夹克步枪兵 | 5 | 4 | 0 | 1 | infantry | 3 | sniper |
| highlander | 高地兵 | 12 | 5 | 2 | 1 | elite | 0 | heavy |
| foot_guards | 英军近卫步兵 | 14 | 5 | 3 | 1 | elite | 0 | heavy |
| scots_grey | 苏格兰灰骑兵 | 11 | 6 | 1 | 2 | cavalry | 0 | hunter |
| rocket | 康格里夫火箭 | 6 | 5 | 0 | 0 | gun | 99 | rocket |
| british_gun | 英军炮 | 9 | 6 | 1 | 0 | gun | 99 | |
| brigadier | 英军旅长 | 11 | 3 | 2 | 1 | leader | 0 | officer |
| ru_line | 俄军步兵 | 8 | 3 | 1 | 1 | infantry | 0 | |
| ru_grenadier | 俄军掷弹兵 | 13 | 4 | 2 | 1 | elite | 0 | heavy |
| ru_jaeger | 俄军猎兵 | 5 | 3 | 0 | 1 | infantry | 2 | |
| cossack | 哥萨克 | 7 | 4 | 0 | 2 | cavalry | 0 | hunter, skirmisher |
| cuirassier | 胸甲骑兵 | 14 | 6 | 2 | 2 | cavalry | 0 | heavy |
| opolchenie | 俄国民兵 | 5 | 2 | 0 | 1 | infantry | 0 | |
| ru_gun | 俄军炮 | 9 | 6 | 1 | 0 | gun | 99 | |
| ru_general | 俄军将领 | 12 | 4 | 2 | 1 | leader | 0 | officer |
| landwehr | 普鲁士后备军 | 6 | 3 | 0 | 1 | infantry | 0 | |
| fusilier | 普军燧发枪兵 | 6 | 3 | 1 | 1 | infantry | 2 | |
| uhlan | 普军枪骑兵 | 9 | 5 | 1 | 2 | cavalry | 0 | hunter, pierce |
| pr_grenadier | 普军掷弹兵 | 12 | 4 | 2 | 1 | elite | 0 | heavy |
| pr_gun | 普军炮 | 8 | 6 | 1 | 0 | gun | 99 | |
| pr_general | 普军将领 | 13 | 4 | 2 | 1 | leader | 0 | officer, rally |
| guerrillero | 西班牙游击队员 | 5 | 4 | 0 | 1 | infantry | 0 | ambush |
| bandolero | 山地神枪手 | 4 | 4 | 0 | 0 | infantry | 3 | ambush, post |
| es_lancer | 西班牙枪骑兵 | 8 | 5 | 0 | 2 | cavalry | 0 | pierce |
| es_regular | 西班牙正规军 | 6 | 3 | 1 | 1 | infantry | 0 | |
| partisan_chief | 游击头领 | 9 | 4 | 1 | 1 | leader | 0 | officer, ambush |

**远洋**：

| id | 名字 | hp | 攻 | 防 | 速 | type | 射程 | 标签 / at_terrain |
|---|---|---|---|---|---|---|---|---|
| marine | 皇家海军陆战队 | 7 | 4 | 1 | 1 | infantry | 0 | boarder |
| sailor | 英国水兵 | 6 | 3 | 0 | 2 | infantry | 0 | boarder |
| marine_sharpshooter | 桅顶射手 | 4 | 4 | 0 | 0 | infantry | 3 | post, top / [rigging] |
| boatswain | 水手长 | 10 | 4 | 1 | 1 | leader | 0 | officer, boarder |
| pirate | 海盗 | 6 | 4 | 0 | 1 | infantry | 0 | loot, boarder |
| pirate_captain | 海盗船长 | 12 | 5 | 1 | 1 | leader | 0 | officer, loot |
| coast_gun | 岸防炮 | 12 | 7 | 2 | 0 | gun | 99 | / [high, dune, beach] |
| carronade | 卡隆炮 | 8 | 8 | 0 | 0 | gun | 99 | short / [deck, quarterdeck] |
| gunboat | 炮艇 | 10 | 6 | 2 | 0 | gun | 99 | boat / [sea] |
| raider_captain | 毒蛇号舰长 | 14 | 5 | 2 | 1 | leader | 0 | officer, hunter（第九场 Boss；名字由 C 定） |

**伊夫堡**（人物都来自 1844 年的大仲马原著，属公有领域；不借用任何现代改编）：

| id | 名字 | hp | 攻 | 防 | 速 | type | 射程 | 标签 |
|---|---|---|---|---|---|---|---|---|
| gendarme | 宪兵 | 7 | 3 | 2 | 1 | infantry | 0 | arrest |
| mounted_gendarme | 骑宪兵 | 9 | 4 | 1 | 2 | cavalry | 0 | arrest, hunter |
| prison_guard | 狱卒 | 8 | 3 | 1 | 1 | infantry | 0 | |
| turnkey_chief | 典狱长 | 11 | 3 | 2 | 1 | leader | 0 | officer（模板 `on_kill` 开门） |
| customs | 海关缉私兵 | 6 | 3 | 1 | 1 | infantry | 2 | |
| smuggler | 走私贩 | 6 | 3 | 0 | 2 | infantry | 0 | stealth |
| bandit | 罗马强盗 | 6 | 4 | 0 | 1 | infantry | 0 | ambush, ransom |
| bandit_marksman | 强盗枪手 | 4 | 4 | 0 | 0 | infantry | 3 | post, stealth |
| vampa | 路易吉·万帕 | 14 | 5 | 2 | 1 | leader | 0 | officer, ransom |
| assassin | 刺客 | 8 | 7 | 1 | 2 | elite | 0 | hunter, execute, stealth |
| benedetto | 贝内代托 | 13 | 6 | 1 | 2 | elite | 0 | hunter, execute |
| national_guard | 国民自卫军 | 7 | 3 | 1 | 1 | infantry | 0 | |

每段的模板 id 清单要在 B1 之前定下，B 写模板，C 在地图里引用：
- **主干**：toulon_night、montenotte、lodi_bridge、arcole（已有）、rivoli（已有）、pyramids（沙漠）、acre（沙漠 + 墙）、marengo、ulm、austerlitz（冰面 + 冰裂事件）、eylau（雪）、saragossa（街道 + 房屋）、wagram（grand）、borodino（grand）、berezina（冰裂成河）、leipzig（grand）、elba_cove（沙滩 + 码头）。
- **鹰飞**：ligny、waterloo（epic、泥地）、brussels、rhine_crossing、vienna_streets、iberia_return、niemen、coalition_final（epic）。
- **远洋**（经 `scene_battles` 替换现有的通用图）：bellerophon_deck、jamestown_streets、sea_cave、longwood_escape、shipwreck_beach、skull_reef、viper_boarding、vigo_seabed（虚空 + 浅水）、atlantis（虚空）、thames_estuary（epic 海战）。
- **伊夫堡**：marseille_arrest、if_corridors（夜）、tiboulen_swim（暗礁 + 浅水）、monte_cristo_cave、san_sebastiano（墓穴）、auteuil_garden（夜）、paris_rooftops（grand）、cristo_final（epic）。

---

## 6 去当铺改名表

**原则**：只换玩家看得见的字和美术描述；机制、id、命令、存档键一律不动。「天平」不算当铺意象：保留为「军需官的秤」，只在剧情里偶尔出现；标题纹章换成鹰徽加罗盘。

| 旧（当铺义） | 新（军需 / 行军义） | 机制 |
|---|---|---|
| 远洋当铺（标题、品牌） | 见 §7；各段品牌：鹰旗 / 鹰飞 / 远洋 / 伊夫堡 | — |
| 当铺 / 估值铺 / 海鸥号估值铺 / 海鸥号当铺前堂 | 海鸥号补给栈（法国侨民开的船具补给栈，暗中接济朗伍德） | 场景地点文字 |
| 掌柜 | 军需官 / 补给栈主 | 人物身份 |
| 柜台 | 案桌 / 补给台 / 作战桌（看语境） | 文字 |
| 挂牌（白 / 红 / 黑） | 营令三色旗：白旗·照常行军；红旗·征发（每日警戒 +15）；黑旗·闭营清点（每日军费 −10，警戒 −10） | `campaign.sign` 不变 |
| 平价典当 / 军需特收 / 闭门盘库 | 照常行军 / 征发 / 闭营清点 | 同上 |
| 鉴定（appraise） | 查验：察看（spot）、过秤（weigh）、听音（ring）、破译（decode） | `campaign.appraise` 不变 |
| 已鉴定的线索 | 已查验的线索 | VN 文字 |
| 当票 | 调拨凭单 / 军需凭单 | 文字 |
| 流当 / 流当品 / 流当军需桶 / 流当任务凭证 / 流当大印 / 《流当通知单》 | 封存 / 罚没品 / 三层封存军需桶 / 封存任务凭证 / 军需总监大印 / 《缴获清单》 | 物品名、场景标题 |
| 活当 / 活当赎回 / 活当票 | 金蝉脱壳 / 秘密转运 / 转运凭单 | scene05 标题、抉择 |
| 收当 | 收购 | 文字 |
| 抵押 / 抵押清单 / 抵押木匣 | 担保 / 担保清单 / 押运木匣 | 文字 |
| 赎回（当物义） | 改写成转运；人质义的「赎回」保留 | 文字 |
| 营业 / 营业日 / 营业时间 | 行动日 / 当值时间（「现在不是行动时间」） | 文字 |
| 经营须知 | 军需官手册 | 规矩页 |
| 开张 · 今日行动 / 结账 · 等待明日 | 拔营 · 今日行动 / 扎营 · 等待明日 | 日程按钮 |
| 夜 · 结账 / 第 N 日的账 | 夜 · 点名 / 第 N 日军需 | 日终面板 |
| 金库储备（指标） | 军费（各章再加币制后缀） | `treasury` 键不变 |
| 生命与动力 | 体力与士气 | `vitality` 键不变 |
| 柜台挂牌 / 街区暗访 / 后门密访 / 资源与援助 / 行军棋盘 / 据点周历 / 金库与航海日志（营地牌） | 营令 / 市镇补给（地图节点）/ 密探联络（地图节点）/ 工程与援助（地图节点）/ 世界地图 / 营地日程（地图节点）/ 军需账簿与航海日志 | 牌 uid 不变 |
| 永不靠岸的幽灵当铺（结局） | 永不靠岸的幽灵舰队 | 结局 id `ghost` 不变 |
| 深海利维坦的账房先生 / 深海账房（插图） | 深海利维坦的财政官 / 深海金库 | `dark` 不变 |
| 「带着当铺账本」「现在开当铺」 | 「带着帝国军需账簿」「流亡皇帝的司库」 | 标题引子、立绘说明 |
| 学徒、守店（小皮埃尔、星期五） | 勤务兵、守营 | 人物身份 |
| 航海旧账、书架上的账本（局外记录） | 战役档案、回忆录书架 | 局外记录 |

**需要改字的文件和键**（全部属于拿破仑 / 远洋线；旧版 1938 一个不碰）：

1. `data/campaigns/ocean_pawn.json`
   - `title`；
   - `chapters[prologue].title`、`chapters[new_elba].title`；
   - `characters[villefort].role`，以及 `characters[pierre].role`、`characters[friday].role`；
   - `items[forfeit_barrel].name`；
   - 场景：
     - `scenes[prologue]`：`title`、`body[1]`、`body[2]`；
     - `scenes[scene01]`：`title`、`location`、`body[1]`、`body[2]`、`appraisals[linen_report].label`；
     - `scenes[scene02]`：`location`、`body[0]`、`body[1]`、`appraisals[sabre_mark].observation`；
     - `scenes[scene03]`：`body[0]`、`appraisals[morrel_credit].label`；
     - `scenes[scene04]`：`body[2]`、`body[3]`、`appraisals[vial_balance].label`、`appraisals[vial_balance].observation`；
     - `scenes[scene05]`：`title`、`body[1–3]`、`appraisals[escape_roll].label`、`choices[redeem_emperor].label`；
     - `scenes[scene06]`：`body[0–2]`、`choices[establish_rations].label`；
     - `scenes[scene07]`：`body[0]`、`appraisals[chest_weight].observation`、`choices[expose_viper].label`；
     - `scenes[scene08]`：`title`、`body[0–2]`、`choices[prepare_operation].label`；
     - `scenes[scene09]`：`body[2]`、`choices[rescue_only].label`；
     - `scenes[scene10]`：`body[1]`、`body[2]`、`appraisals[alliance_accounts].observation`；
     - `scenes[scene12]`：`title`、`body[0]`、`choices[cut_orichalcum].label`；
     - `scenes[finale]`：`title`、`body[0–3]`、`appraisals[final_balance].label`、`choices[close_ledger].label`；
   - 结局：`endings[alliance].body[0]`、`endings[alliance].body[1]`，`endings[ghost].title`，`endings[dark].body[0]`、`endings[dark].body[1]`，`endings[tragedy].body[1]`；
   - `design_notes[5]`。
2. `data/hd/hub_ui.json`
   - 品牌与计数：`brand`、`story_appraise`；
   - 提示与规矩：`tip_rules`、`rules_body`、`title_hint`；
   - 营地牌：`cards.signage.label`、`cards.status.kicker`，以及 `cards.*` 的全部 label；
   - 挂牌与副标题：`sign.white/red/black`、`sub.signage/town/backdoor`；
   - 原因：`reason.bad_phase`；
   - 阶段面板：`phase.settle_kicker`、`phase.settle_title`、`phase.year_kicker`、`phase.over_note`；
   - 信物：`relics.empty`；
   - 指标：`gauge.treasury/vitality`、`gauge_tip.*`。
3. `data/hd/vn_ui.json`
   - 查验相关：`group_appraise`、`clues_title`、`clues_empty`、`plate_appraise`、`plate_clue`；
   - 原因：`reason.missing_clue`、`reason.bad_phase`；
   - 账簿相关：`result_chapter`、`ending`。
4. `data/campaigns/ocean_battle.json`：`text.chronicle_obituary`、`text.obituary_body[1]`（「天平」「账簿」改写）。
5. `data/campaigns/battle_ui.json`：`text.result_done`（「记进账簿」改成「记进战史」）。
6. `scripts/cards/campaign/ocean_view.gd`：由 A0 抽进 `data/campaigns/text/ocean_ui.json`，之后由 C 改。
   - 常量：`SIGN_NAMES`、`METRIC_NAMES`；
   - 第 541 行：物品的 `use` 文字；
   - 第 570–573 行：`fallback_endings`（bittersweet、bankruptcy、blockade 里有「远洋当铺」「天平」）；
   - 覆盖层：`ocean.signage`、`ocean.town`、`ocean.backdoor`、`ocean.resources`、`ocean.march`、`ocean.calendar`、`ocean.squad`、`ocean.big_fate`、`ocean.status`、`ocean.rules`；
   - 日程按钮与原因：`c01.btn.close_day.*`、`c09.btn.*`、`ocean.reason.locked`；
   - 标题与暂停：`_common_text` 里的 `c16.title.name/new/continue/tagline/blurb/hint`、`c16.pause.*`；
   - 局外记录：`rg4.title.*`、`rg4.title.shelf_empty`、`rg5.toast.closed`、`rg5.chronicle.other`、`ocean.chronicle.*`、`rg4.relics.empty`；
   - `_dynamic_text` 里的 signage、town、resources 正文和 `ocean.goal` 的默认值「远洋当铺」；
   - 第 933 行：`【已鉴定 · …】`；
   - 第 1041 行：账目里的「鉴定：」；
   - 第 1048 行：账目里的「营业 · 日结」。
7. `scripts/cards/campaign/ocean_rogue_data.gd`：只改字，id 不动。MARCH_BOARD、ACTIVITIES、CALENDAR_ACTIONS 的说明里「金库储备」「生命与动力」统一改用新的指标名；道具名本来就没有当铺词。
8. `data/hd/art_list.json`（由 B 合入 C 的需求）：
   - `bg/jamestown_shop`：id 不改，改 name 和 desc（补给栈，不要当进来的物件）；
   - `bg/shop_back_room`、`bg/granite_palace_exchange`（「柜台」改成「交易台」）；
   - `bg/title`：天平和账簿改成鹰徽、罗盘、三条航路；
   - `cg/ending_ghost`、`cg/ending_dark`；
   - `chara/villefort`（「现在开当铺」改成「流亡皇帝的司库」，天平坠子改成鹰徽怀表）；
   - `unit/villefort`（「拿账簿」改成「拿调拨凭单与指挥刀」）。
9. 界面代码：
   - `scripts/cards/ui/hub/hub_title.gd`：Emblem 不再画天平，改成鹰徽、罗盘和三枚分支徽章（A）；注释同步改。
   - `hub_panel.gd`、`hub_card_panel.gd`、`vn_panel.gd`、`vn_script.gd` 里只有注释提到当铺词，顺手改掉即可，不影响行为。
10. 测试里的文字断言（C 改，与文字同一个提交）：
    - `scripts/tests/cards/OCEAN/test_ui.gd:73`：`contains("远洋当铺")` 改成新标题；
    - `test_ui.gd:177`：`"当铺"` 改成新结局里的字；
    - `test_hub.gd:254`：`"远洋当铺经营须知"` 改成「军需官手册」；
    - `test_hub.gd:157`：本来就是反向断言（不能出现「柜台」），保留。
11. **防回潮**：新增 `test_content.gd`。扫描拿破仑 / 远洋线所有玩家可见的数据和 `text/ocean_ui.json`，词表为 当铺、典当、当票、流当、估值铺、掌柜、挂牌、柜台、活当、收当、盘库、鉴定、营业、经营须知，必须 0 命中。docs、注释和旧版目录不扫。

---

## 7 标题与身份

**三个暂定名**（都不含「当」字）：
1. **《鹰旗军需官》**，副题「一七九三—一八一五 · 三条路」。推荐这一个：它就是主角的身份，三条分支都套得上，也与设计稿的暂名一脉相承。
2. **《一八一五：鹰、潮与伊夫堡》**：把三条分支直接写在题上，好记，但会剧透分岔。
3. **《皇帝的军需官》**：更通俗，适合做商店页标题，但离开拿破仑以后的分支在题里没有着落。

**标题页**（`hub_title.gd` 仍继承 CardTitle，信号和按钮名不变）：
- **左栏**：
  - 题签小字「一七九三 · 土伦 → 一八一五 · 厄尔巴 → ？」；
  - 金色大标题；
  - 不含当铺的引子；
  - 按钮：「出征」（新局，从主干开始）、「接续战役」（下面一行小字写段、章、日期，比如「远洋 · 圣赫勒拿 · 1818-06」）、「篇章」（有解锁时才出现）、「设置」、「离开」。
- **右侧纹章**：鹰徽压在三叉罗盘上，四周三枚分支徽章：鹰（鹰飞）、鹦鹉螺（远洋）、城堡（伊夫堡）。
  - 没到过的分支暗着；
  - 到过的分支亮起，并标出这条分支的结局收集数，比如「2/4」；
  - 数据来自 `OceanBridge.title_info()`，它读 `napoleon_meta.json` 和 `suspend.json` 的 meta。
- **「篇章」抽屉**：
  - 「主干 · 土伦 1793」：总是可选；
  - 「分岔 · 厄尔巴 1815」：到过分岔点以后解锁，用标准携带；
  - 「鹰飞 / 远洋 / 伊夫堡 · 第一章」：打出该分支任一结局以后解锁，用标准携带。
  - 选中后发出 `chose(&"chapter")`，并把 `title.chosen_start = {segment, stage, carry:"standard"}` 交给 `RunKeeper.new_game_options` 合进 `game.new`。
  - `_run_context` 里的 opening 仍是 `og.default`，所以不碰 v0.9 的出身表。
- **右下旧账盒**：种子、换一个种子的功能保留；「航海旧账」改名「战役档案」。

---

## 8 工作包与合并

### 8.0 A0（先合，约半天，A 来做）

- 把 `ocean_view.gd` 里所有玩家可见的中文搬到 `data/campaigns/text/ocean_ui.json`，按 §6 第 6 条的键名组织，`ocean_view` 改成从这份 JSON 读。
- 在基线上录两份 golden：`golden/ocean_routes.json`（§1.8）和 `golden/battle_templates.json`（§3.5）。
- 验收：现有 9 套 OCEAN 测试全绿，显示的文字逐字不变。

### 8.1 A：战役引擎、分段、世界地图（逻辑 + 界面）

- **改**：
  - `scripts/cards/campaign/ocean_campaign.gd`、`ocean_rogue_rules.gd`（只改逻辑：roster 解析、tally、地图上的道具效果、节点门禁）、`ocean_battle2.gd`（战斗键改为节点、等级接线、名额和主角兵力按等级）、`ocean_bridge.gd`、`ocean_view.gd`（只改结构）；
  - `scripts/cards/loop/card_engine.gd`（`game.new` 接受 `napoleon` 和 segment/stage/book）；
  - `scripts/cards/ui/table/card_game_root.gd`（命令行参数、`_start` 透传、营地换成地图。这个文件正在被修界面的代理改动，只动 `_cmdline_opts`、`_start`、`_sync_hub` 三处，先发一条消息说明）；
  - `scripts/cards/ui/table/modal_host.gd`（登记新面板）；
  - `scripts/cards/ui/hub/hub_title.gd`（纹章和篇章抽屉的结构，文字由 C 写）；
  - `tools/run_ocean_tests.sh`（唯一写手，B 和 C 的新测试由 A 加进列表）。
- **新建**：
  - `scripts/cards/campaign/run/*`、`scripts/cards/campaign/map/*`、`scripts/cards/ui/map/*`；
  - `data/campaigns/napoleon/book.json`（结构）、`maps/world.json`（远洋 14 个锚点加随机槽骨架）、`fixtures/mini_book.json`；
  - `data/hd/map_ui.json`；
  - `docs/cards/RUN_ENGINE.md`、`docs/cards/WORLD_MAP.md`。
- **测试**：`test_run_book.gd`、`test_map.gd`、`test_run_replay.gd`、`test_map_ui.gd`，以及 `run_helpers.gd`、`map_policy.gd`。
- **验收**：
  1. 现有 9 套全绿，单段书的 `hash_v1` 序列与 golden 相等；
  2. 迷你书能走通「主干 → 三个分支各自 → 固定结局」，三种可用性组合（只有远洋 / 远洋加伊夫堡 / 全开）都对，保底分支总在；
  3. 在每一段、每一张图上存档读档往返以后状态哈希相等，v1 存档能迁移；
  4. 命令日志重放（含检查点）哈希一致；
  5. 用调试入口直接开任意段、任意章；
  6. 地图规则 R1–R7 的校验器能拒绝反例；
  7. `map_ui` 的截图（地图主画面、节点牌、行军手牌、雾、对手）。

### 8.2 B：战斗内核（地形、等级、敌军、天时、大尺寸）+ 3D 战场 + 美术清单

- **改**：
  - `scripts/cards/campaign/battle/battle_rules.gd`；
  - `data/campaigns/battle_templates.json`（只追加；旧的 7 张模板字节不变；新增 `bond_sets.napoleon`）；
  - `data/campaigns/battle_ui.json`；
  - `scripts/cards/ui/battle/battle_board.gd`、`field/*.gd`、`hud/hud_portrait.gd`；
  - `battle_panel.gd`、`battle_lineup_panel.gd`（只改地形和敌人相关的几处：图例、小地图、可部署判断）；
  - `scripts/tests/cards/OCEAN/battle_policy.gd`；
  - `data/hd/art_list.json`（唯一写手）；
  - `docs/cards/BATTLE_V2.md`（地形、等级、敌军、天时四节）。
- **新建**：`test_battle_terrain.gd`、`test_battle_levels.gd`、`data/campaigns/napoleon/ref_rosters.json`、`tools/battle_sweep.gd`、§5 列出的新模板。
- **先交给 A 的接口**（第 1–2 天交，写在 `BATTLE_V2.md`）：
  - `level_of_act(a)`、`row(L)`、`caps(scale, L)`、`power(tpl, L, setup)`、`can_stand(cls, terrain)`；
  - `new_battle(tpl, {level, weather, …})`；
  - 视图新增的 `level`、`weather`、`cells[].tier/los/stand/dark`。
- **验收**：
  1. `test_battle_v2.gd` 一字不改全绿，旧模板 golden 相等；
  2. 每种新地形都有单测：站位、步耗、防、远防、视线、层、黑暗、洞穴、事件改地形（我方退栏、敌人落水）、`on_kill`、`until`；
  3. 每种天时都有单测；
  4. 新标签逐条有单测；
  5. 一张 12×7 的不规则（带虚空格）模板通过校验并能打完，3D 截图里每格不小于 44 像素；
  6. 等级验收 A1–A6；
  7. 美术清单的校验脚本通过，新条目都有占位图。

### 8.3 C：内容（去当铺文字 + 远洋分支数据 + 新段数据）

- **改**（只改字，id、数值、结构不动）：
  - `data/campaigns/ocean_pawn.json`、`data/hd/hub_ui.json`、`data/hd/vn_ui.json`、`data/hd/vn_cast.json`（加新场景的演出表）；
  - `data/campaigns/ocean_battle.json` 的 text 块；
  - `data/campaigns/text/ocean_ui.json`（A0 之后归 C）；
  - `scripts/cards/campaign/ocean_rogue_data.gd` 里的字符串；
  - §6 第 10 条的四处测试断言；
  - `docs/cards/OCEAN_CAMPAIGN.md`。
- **新建**：
  - `data/campaigns/napoleon/trunk.json`、`conquest.json`、`cristo.json`；
  - `companions.json`、`events_common.json`；
  - `maps/europe.json`、`maps/europe_late.json`、`maps/med.json`，以及给 `world.json` 补内容；
  - `data/hd/art_requests/C.json`；
  - `test_content.gd`。
- **验收**：
  1. 防回潮词表 0 命中；
  2. A 的书校验和地图校验全部通过；
  3. `map_policy` 自动游玩能让三个分支各自至少有一条路线打到固定结局；
  4. 每个新场景在 VN 里都有背景和立绘位，人物都登记了；
  5. 每个分支至少 2 个固定结局加 1 个默认结局，主干在分岔点的三个抉择都有可用性文字。

### 8.4 文件归属（防撞）

| 文件 | 唯一写手 | 其他包怎么配合 |
|---|---|---|
| `ocean_campaign.gd`、`ocean_rogue_rules.gd`、`ocean_battle2.gd`、`ocean_bridge.gd`、`ocean_view.gd`、`card_engine.gd`、`card_game_root.gd`、`modal_host.gd`、`run_ocean_tests.sh` | A | B 只提供接口，C 只改 JSON |
| `battle_rules.gd`、`battle_templates.json`、`battle_ui.json`、`field/*`、`battle_board.gd`、`battle_policy.gd`、`art_list.json` | B | A 和 C 通过 `art_requests/*.json` 提需求；新模板的 id 清单见 §5 |
| `ocean_pawn.json`、`hub_ui.json`、`vn_ui.json`、`vn_cast.json`、`text/ocean_ui.json`、`ocean_rogue_data.gd`、`napoleon/*.json`（book.json 的结构字段由 A 写） | C | A 在 `book.json` 里只写结构字段，C 只写文字和内容字段（同一个文件里按键分工，合并时由 A 复核） |

### 8.5 合并顺序

1. **A0**：抽出文字，录 golden。
2. 三包并行开工：A1（内核、书、地图规则）、B1（规则内核、等级、地形、天时、敌军）、C1（`ocean_pawn.json`、hub/vn 的 JSON、`text/ocean_ui.json` 去当铺）。
3. 合并第一轮：
   - **B1** 先合：纯增量，golden 相等；
   - **A1** 再合：用 B1 的接口；
   - **C1** 最后：文字加四处测试断言。
   每次合并后都跑全部 OCEAN 测试和旧版冒烟（`tools/run_tests.sh` 里旧版那一段），确保旧版不受影响。
4. 第二轮并行：A2（地图界面、标题篇章、map_policy）、B2（新模板、3D 场地、天时特效、美术清单）、C2（三份新段定义、三张图、伙伴、事件）。
5. 合并第二轮：**A2 → B2 → C2**。
6. **C3**：通过 B 合入美术文字；`DEFAULT_BOOK` 改成 `napoleon`；`test_ui` 和 `test_hub` 的开局改成显式选 `ocean_pawn` 书作回归，另外新增一套 napoleon 书的界面冒烟。
7. **终验**：自动游玩三个分支各一局；给主创出截图和平衡表。

---

## 9 风险与待主创拍板

1. **分岔点在 1815-02**：这意味着「远洋」分支的百日王朝只能在后方经过，滑铁卢以远方战报出现。如果主创希望三条分支都亲历滑铁卢，就把分岔点移到 6 月 18 日战后，代价是伊夫堡分支的 2 月挂钩要改写成「回马赛找唐泰斯」，节奏就不如现在顺。
2. **主干的体量**：沿用设计稿的「序章加 6 幕」，主干就要 6 张图。第一版建议先做 4 张（土伦、意大利、埃及或马伦哥二选一、崩落到厄尔巴），等级照样连续，校验器只要求 Boss 等级递增，不要求章节数固定。
3. **存档体积**：长局的命令日志要靠 §1.7 的检查点控制；B2 合入以后要实测一整局的 `suspend.json` 大小。
4. **棋盘去留**：单段书保留旧棋盘和营地，只用于回归测试。等 C3 切换默认书、napoleon 书稳定下来以后，再决定是否把 `MARCH_BOARD` 只当作节点效果表保留。
5. **与修界面的代理撞文件**：A 动 `card_game_root.gd`、`modal_host.gd`、`hub_title.gd`、VN 对事件前缀的支持，B 动 battle 的各块面板，开工前都要先发消息、按小提交合并。
6. **待拍板**：
   - 三个暂定名选哪一个；
   - 「随驾流放」这条跨段大命运要不要做；
   - 伊夫堡分支的牢狱章要不要像原著那样跳 14 年（建议做成「数年一格」的局部图，每格是一段牢中岁月）。
