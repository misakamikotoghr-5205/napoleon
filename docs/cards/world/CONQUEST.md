# 主干「鹰旗」与分支「鹰飞」：内容草稿（标签 conquest）

> 2026-11-02。按 ARCH（`wm/arch/ARCH.md`）的契约写的 C 包内容草稿，覆盖主干（土伦 1793 → 厄尔巴 1815-02）和「继续征服」分支（1815—1819 架空）。
> 所有文件都在本目录 `wm/conquest/` 下，只是草稿，没有改仓库。数据都是 JSON，可以直接拷到 ARCH §1.3 约定的路径。
> 校验：`python3 -I tools/check_conquest.py` 当前 **0 个错误**，另有 11 条提醒，都是设计上有意为之或只是间距偏紧（见 §11）。

## 0 结论速览

1. **一局的形状**：主干八章（序章土伦，第一幕意大利写满，第二到第六幕各压成一张小图，终章厄尔巴），在厄尔巴的 `elba_1815` 分三路。走「鹰飞」再打六章，到莱比锡 1819 收在 3 个固定结局加 1 个默认结局。估算主干约 2.5–3 小时（§2.3），鹰飞约 2 小时。
2. **章内二选一**：主干第二到第四幕和鹰飞第四章各有两个战区（东方或阿尔卑斯、多瑙河或普鲁士、西班牙或多瑙河、伊比利亚或海峡）。开场的调令场景写一个互斥旗标，另一边的场景用 `scenes[].when` 跳过，另一半地图节点用 `requires` 锁住。这样每局主干只走一半内容，重玩时另一半是新的。
3. **每章一张世界地图**：主干 8 张、鹰飞 6 张，共 293 个节点，坐标全部来自真实经纬度。土伦和厄尔巴用手绘局部图，坐标是 `xy`。每张图都用新校验器过了 R1–R5、R7，章与章之间过了 R6。
4. **逐章变难**：主干 Boss 依次是 L1/3/5/7/9/10/11/12，鹰飞是 L14/16/18/20/22/24。同章的精英战不超过 Boss−1，遭遇战和随机仗不超过 Boss−2，校验器逐章检查。鹰飞第一章撞上 ARCH 两条规则的冲突，处理办法见 §5.2。
5. **战场**：一共 15 张模板，复杂地形全部用 ARCH §4.2 的新字符。其中 14 张是上一轮画的，本轮补了 `skirmish_sunken_lane`。每张都写了「什么都不做为什么必输」和「为什么一步解不了」，「什么都不做必输」这一条还在每种天时和最低、最高等级下用模拟器验证过。另有 26 张模板按 ARCH §5 的清单留给 B 画，`templates_needed` 里写了地形要点和兜底模板。
6. **伙伴**：17 人。跨段的 5 个人（唐泰斯、法利亚、古尔戈、玛丽、科尔索）照抄远洋的战斗数值，只合并阵营标签。羁绊套 `napoleon` 共 14 条（含 3 条职业羁绊），另有 5 对名羁绊（内核暂无，先写成数据）。
7. **鹰飞的核心钩子**：在战争部截下莫雷尔替唐泰斯写的请愿书，附议人正是杰拉尔·德·维尔福。这时可以放出伊夫堡 34 号；拿着法利亚的半封信，还能连 27 号一起放。这决定能不能拿到结局「回到马赛」：那个世界里从来没有基督山伯爵。

---

## 1 文件清单

| 文件 | 内容 | 生成方式 |
|---|---|---|
| `data/campaigns/napoleon/trunk.json` | 主干段定义：8 章 24 场、22+1 人物、5 件物品、39 个事件（11 场军议、11 个固定、17 个随机）、4 个失败收场 | 上一轮手写；本轮由 `tools/trunk_additions.py` 追加（幂等，可重复跑） |
| `data/campaigns/napoleon/conquest.json` | 鹰飞段定义：6 章 20 场、22 人物、6 件物品、25 个事件、7 个结局（3 固定 + 1 默认 + 3 失败）、`big_fate_extra` 2 项 | `tools/build_conquest.py` |
| `data/campaigns/napoleon/maps/europe.json` | 主干 8 张图（181 个节点） | `tools/build_maps.py` |
| `data/campaigns/napoleon/maps/europe_late.json` | 鹰飞 6 张图（112 个节点） | 同上 |
| `data/campaigns/napoleon/book_conquest_patch.json` | 给 book.json 的内容补丁：两段登记、`branches.conquest` 与灰显原因、`scene_battles`（21 场）、`battle_pool`、`templates_needed`、`shared_flags_add`、`debug_carry` | `build_maps.py` 加 `tools/book_patch_static.json` |
| `data/campaigns/napoleon/companions_conquest.json` | 伙伴总表中主干与鹰飞的 17 行、主角标签、名羁绊 `pairs`、羁绊套 `bond_set_napoleon` | `tools/build_companions.py` |
| `data/campaigns/napoleon/events_common.json` | 全书通用池：13 个幕间插曲（召见、营火、野营夜、查验）和 2 个随机事件 | `tools/build_events_common.py` |
| `data/campaigns/napoleon/enemies_trunk_conquest.json` | 敌人 48 种（7 种现有奥军、34 种 ARCH 原表、7 种本稿新增），外加 17 个反法同盟编组 | 上一轮 |
| `data/campaigns/battle_templates_conquest.json` | 15 张战场模板（battle_templates.json 的 templates 条目形状） | 上一轮 14 张，本轮加 1 张 |
| `data/hd/art_requests/C_conquest.json` | 美术需求 153 条：背景 72、结局插图 4、立绘 26（含 4 条年龄变体）、头像 29、小人 19、图标 3 | `tools/build_art_requests.py` |
| `data/hd/vn_cast_conquest.json` | 剧情演出表：123 个场景和事件 → 背景 id 加主讲人 | 同上 |
| `tools/check_conquest.py` + `tools/check_world.py` | 校验器（§11） | — |
| `tools/build_doc_tables.py` | 根据地图 JSON 生成本文附录的节点表 | — |

重建全部：`for b in trunk_additions build_conquest build_events_common build_companions build_maps build_art_requests build_doc_tables; do python3 -I tools/$b.py; done && python3 -I tools/check_conquest.py`（在本目录下运行）。

---

## 2 主干「鹰旗」

### 2.1 章节

| 章 | 年代 | 战区（二选一） | 场景 | Boss（L） | 精英（L，可绕） | 插曲 |
|---|---|---|---|---|---|---|
| `toulon` 序章 | 1793 | — | toulon_arrival → toulon_mulgrave | 小直布罗陀 `toulon_night` L1（教学） | — | — |
| `italy` 第一幕 | 1796—97 | — | italy_nice → italy_milan → **italy_rivoli** → italy_campo_formio | 里沃利 `rivoli_plateau` L3 | 洛迪桥 L2、阿尔科莱堤道 L2、拉法沃里塔 L2（追击，需旗标 t_favorita_pursuit） | 召见（卡尔诺） |
| `orient_alps` 第二幕 | 1798—1800 | `t_orient` 埃及叙利亚 / `t_alps` 阿尔卑斯 | orient_orders → orient_acre ‖ alps_marengo | 阿卡 `acre` L5 ‖ 马伦哥 `marengo` L5 | 金字塔 L4 ‖ 巴德堡 L4 | 营火 |
| `austerlitz_jena` 第三幕 | 1805—07 | `t_austerlitz` 多瑙河 / `t_prussia` 普鲁士波兰 | boulogne_orders → austerlitz_sun ‖ eylau_snow | 奥斯特里茨 L7 ‖ 埃劳 L7 | 乌尔姆 L6 ‖ 耶拿 L6 | 查验·破译 |
| `iberia_danube` 第四幕 | 1808—09 | `t_spain` 西班牙 / `t_danube` 多瑙河 | bayonne_orders → saragossa_siege ‖ wagram_lobau | 萨拉戈萨 L9 ‖ 瓦格拉姆 L9（grand） | 索莫谢拉 L8 ‖ 阿斯佩恩 L8（拉纳的宿命之地） | 召见（贝尔蒂埃） |
| `russia` 第五幕 | 1812 | — | russia_niemen → russia_borodino（锚点战 L9）→ **russia_berezina** | 别列津纳 `berezina` L10 | 红村 L9 | 野营夜 |
| `collapse` 第六幕 | 1813—14 | — | collapse_lutzen → **collapse_leipzig** → collapse_fontainebleau | 莱比锡 `leipzig` L11（grand） | 德累斯顿 L10、哈瑙 L10（Boss 之后的撤退路上） | 营火 |
| `elba` 终章 | 1814—15 | — | elba_arrival → **elba_night** → elba_1815（分岔） | 码头仓库 `elba_cove` L12 | — | 查验·过秤 |

- 第一幕全部写满：4 场，每场正文 6–9 行，2–3 个查验，3 个抉择。序章 2 场。第二到第六幕每场 4–6 行，标了 `condensed: true`，主线照样走得通。
- 调令场景（orient_orders、boulogne_orders、bayonne_orders）各给一个互斥旗标（`rules.exclusive_flags`），后面两场各带 `when`。
- 伙伴入队的时机：
  - 土伦：巴蒂斯特、科尔索；
  - 尼斯：玛丽、米隆；
  - 米兰：选「先发欠饷」得拉纳，选「收下掉在地上的金币」得缪拉；
  - 阿卡：选「把伤员和病人分开」得拉雷；
  - 东方军团或后备军团的商贩处花金币招：鲁斯塔姆、德塞；
  - 涅曼河：古尔戈、埃布莱；
  - 别列津纳：小皮埃尔。

### 2.2 分岔与可用性

`elba_1815` 是地图上的 `branch` 节点（穆利尼宫），三个抉择各带 `branch`：

| 抉择 | 去向 | 门槛（book.branches.*.requires） | 灰掉时显示的原因 |
|---|---|---|---|
| 随皇帝北上，亲赴前线 | `conquest` | 满足其一：整局累计挣到勋章 ≥ 10；或旗标 `t_guard_oath`（枫丹白露选「写下名字：去厄尔巴」）。另外要求 `hero_ok` | 「皇帝没点你的名：忠诚不够……」/「主角重伤未愈，上不了马」 |
| 以司库身份随驾 | `ocean` | 无（保底） | — |
| 奉命携密信去马赛 | `cristo` | 满足其一：`faria_half_letter`（博洛尼亚固定事件里划掉日课经）；或 `t_pharaon_known` | 「你和马赛没有交集……」 |

拿到 `t_pharaon_known` 的途径有三条，所以伊夫堡线几乎总能打开：
- 土伦图随机槽里的「莫雷尔父子商行的粮船」事件；
- 枫丹白露选「回马赛」；
- 厄尔巴战役段的固定节点「码头·法老号靠岸」。这个节点可绕开，但它就摆在军议到营火的路上。

### 2.3 时长估算

- 每个积累段的最短路线天数由校验器算出（腿数 ÷ 3 + 路线上的锚点战数），列在 `--days` 输出里：
  - 土伦 1 天，意大利 9 天，第二幕 7/11 天，第三幕 7/7 天，第四幕 8/5 天，俄罗斯 13 天，崩落 3 天，厄尔巴 2 天；
  - `days_max` 一律 ≥ 最短天数 + 3（R7）。
- 按 ARCH §2.8 的节奏估：每章约为积累 10 分钟、战役 15–18 分钟、插曲 3–5 分钟。
  - 土伦：教学，约 15 分钟；
  - 意大利：约 40 分钟；
  - 二到六幕：每幕约 20–25 分钟（一半节点因为战区二选一而锁着）；
  - 厄尔巴：约 15 分钟；
  - 合计约 2.5–3 小时。
- 偏长的话，第一刀先砍可绕的精英战：意大利的洛迪、拉法沃里塔，崩落的哈瑙。主线不受影响。

### 2.4 主干新增的事件（本轮）

- **军议 11 场**，每章一场（`pool: fixed`，`council: true`，地图上是 `role: council` 的事件节点）。
  - 三个抉择固定对应三种 Boss 修正（`boss_mod`）：`cp_bonus +2`（开场军令点）、`enemy_morale −2`（敌军心）、`prep_turn +1`（第一波晚一回合到，回合上限同时 +1）。
  - 每场军议的代价各不相同，写在 effects / rogue 里（军需券、情报币、体力……），而且至少有一项不花币。
  - 例：
    - 马伦哥的「替德塞备好回程的马」会写 `t_desaix_close`；
    - 别列津纳的「让埃布莱带工具车先走」会写 `t_eble_ahead`。
- **固定事件 8 个**：
  - 马耳他「骑士团的银库」（刷黑的银门）；
  - 大圣伯纳德山口「修道院」（掏空的松树干拖炮，修道院的账）；
  - 奥格斯堡「两万七千个俘虏」；
  - 柏林「腓特烈的佩剑」（写明来处，得 `t_return_mark`）；
  - 马德里「五月三日之后」；
  - 雷根斯堡「皇帝的脚踝」（拉雷在场才有第三个选项）；
  - 斯摩棱斯克「粮仓」；
  - 蒙米赖「六日战役」。
- **战区随机池 7 个**：东方、阿尔卑斯、北方、伊比利亚、多瑙河、俄罗斯、崩落各 1 个。加上上一轮的意大利 4 个、土伦 1 个、厄尔巴 2 个、主干通用 3 个，每个随机槽都抽得到合适的事件。
- **改了三处字**：
  - 莫雷尔粮船事件的地点从马赛老港改成萨纳里港，好落在土伦图上；
  - `elba_arrival` 首句兼容「后来自己找来的人」（枫丹白露选了回马赛的情况）；
  - 提普苏丹的使者改为 `pool: fixed`。
- 主干原有人物外，新增一人：康布罗纳（厄尔巴近卫营营长）。

---

## 3 内核需要的几处小扩展（本稿提出，A 定夺）

都是在数据层面加的东西，没写的时候行为不变：

| 键 | 位置 | 含义 | 用途 |
|---|---|---|---|
| `scenes[].when` | 段定义 | 条件为假时整场跳过（`_enter_scene` 往后找下一场） | 章内战区二选一 |
| `sheets[].boss`、`sheets[].muster` 可以写成数组 | 地图 | 取第一个 requires 满足的节点 | 同上 |
| `sheets[].frames` / `nodes[].frame` / `nodes[].offset` / `nodes[].xy_frames` | 地图（只给界面用） | 镜头窗：取第一个 `when` 成立的窗；节点只画在列出的窗里；offset 是标记偏移（用引线指回真实位置）；xy_frames 是同一节点在另一张手绘图上的位置 | 两个战区的图、战役段放大到会战区域 |
| `when` 里的新键 `mustered` | 条件 | 本图已开拔 | 镜头窗 |
| `nodes[].role: "council"`、`events[].council: true`、`choices[].boss_mod` | 地图 / 事件 | 军议节点，抉择带 Boss 修正 | R5 |
| `rogue.recruit` 可以是列表 | 抉择 | 一个抉择招多人 | 土伦、儒安湾 |
| `rogue.trust` | 抉择 | `{pick:2, gain:1}` 让玩家挑两人；或 `{pair:[a,b], gain:1}` | 营火插曲 |
| `events[].chapters` | 通用池 | 插曲只在哪几章播 | R6 |
| `big_fate_extra[].scenes` | 段定义 | 只在这几场战败时提供 | 随驾流放 |
| `rivals[].requires` / `buys_depots` / `extra_if` / `meet.effects` | 地图 | 对手只在某战区出现；对手承包商买走（而不是烧掉）兵站；遭遇时另扣指标 | 白鹳商行、坎贝尔的快艇 |
| `nodes[].fallback` | 地图 | B 的模板还没画好时先用的兜底模板 | 第二到第六幕 |
| `links[].label` | 地图 | 连线的名字（「阿尔巴雷多骡道」「连夜急行军」） | 界面 |
| 模板的 `kill_flags` | 战场 | 击杀某个敌人时，战役层记一个旗标 | 利尼 → 滑铁卢 |

---

## 4 世界地图

### 4.1 底图与坐标

- 欧洲底图用 `wm/geo/europe.json`（墨卡托投影，经度 −12…56，2400×2012）。节点 `geo = [经度×100, 纬度×100]`。
  - 有 50 来个地名在 gazetteer 里，其余的经纬度直接写在 `build_maps.py` 的 EXTRA 表里，都是公开的地理事实。
- 土伦 1793 和厄尔巴是手绘局部图，各给 `xy`（1920×1080）：
  - `xy` 由真实经纬度做局部等距拟合得来，画师照着节点位置描底图（美术需求里有 `map_toulon_1793`、`map_elba`）；
  - 厄尔巴战役段换到费拉约港城图 `map_portoferraio`，那里的 `xy` 是示意布局。

### 4.2 镜头窗（frames）

- 一张图可以有多个镜头窗，界面按顺序取第一个 `when` 成立的窗。例子：
  - 第二幕开场看整个地中海（`med_1798`）。选了东方，镜头推到埃及与西奈（`egypt_1798`）；开拔以后再推到叙利亚海岸（`syria_1799`）。
  - 意大利积累段看整个北意大利，开拔以后推到维罗纳四边形。
  - 滑铁卢战役段的镜头窗只有 1 个经度宽，否则利尼、弗勒吕斯、热纳普会挤在一起。
- 校验器在每个窗里按真实投影算出节点标记的屏幕位置：间距小于 40px 报错，小于 52px 提醒。现在最紧的一对是弗勒吕斯和利尼，48px。

### 4.3 结构（每张图都一样）

1. **积累段**：
   - 起点是本章第一场剧情；
   - 中间有：随机槽（≥ 30%）、驿站（`role: post`，攒印才能开拔）、补给与商贩、营地、固定事件、可绕的精英，以及在路上来回走的对手分遣队；
   - 最后到开拔营地（`role: muster`，积累段节点）。
2. **战役段**：开拔营地 → 军议（council）→ 可绕的精英 → 野营夜（camp）→ Boss。Boss 之后可以再接本章的收尾剧情：坎波福米奥、枫丹白露、滑铁卢村客栈、美泉宫、普罗布斯泰达。
   - 两场仗相邻时，连线必须标 `rush`。全书只有一处：里沃利到拉法沃里塔的「连夜急行军」。
3. **战区二选一的图**：调令场景就是起点，两个战区的节点各带 `requires: {flags:[...]}`。校验器把每个战区当成一个变体分别检查。

### 4.4 R1–R7 怎么满足（校验器逐条检查）

- **R1**：通往 Boss 的每条路都经过开拔营地，所以营地这条自动满足。补给或商贩这条按图检查：去掉所有补给和商贩节点以后，起点到 Boss 必须不通。厄尔巴为此改过：岛上的两个出口都是补给点。
- **R2**：只要随机槽和战斗节点相邻，生成器就去掉这个槽的「战斗」权重，所以不会出现相邻的两场仗（标了 rush 的连线除外）。
- **R3**：除了教学用的土伦（4 个槽，事件权重 8/10，没有固定事件），每个战区变体都至少有 5 个随机槽和 1 个固定事件，随机槽占 30%–38%，期望事件数 ≥ 3。
- **R4**：每个精英都能绕开，并且绕开它以后，本章所有锚点仍然到得了。
- **R5**：去掉军议节点后，开拔营地到 Boss 不通；去掉野营夜后，也不通；Boss 的前一格（战役段内）只能是营地。
- **R6**：
  - 主干的插曲依次是：—、召见、营火、破译、召见、野营夜、营火、过秤；
  - 鹰飞依次是：召见、野营夜、营火、召见、破译、野营夜；
  - 相邻两章都不重复，而且每一种在 `events_common.json` 里都有能抽的事件（带 `chapters` 限定）。
- **R7**：`days_max` ≥ 最短路线天数 + 3，同时比最短天数多出 9 天以上时给提醒（防止太松）。

### 4.5 大富翁的手感

- **兵站套**：伦巴第、尼罗河、多瑙河面包线、卡米诺、仓库线、易北河、拿破仑之路、维斯瓦河。
- **对手分遣队（16 支）**：
  - 巴尔贝山民、白鹳商行车队；
  - 主干后几幕：贝都因骑手、奥军轻骑、普鲁士骠骑兵、游击队、哥萨克、达维多夫的游击队；
  - 厄尔巴：坎贝尔的快艇。它不打仗，遭遇时扣 1 枚情报，民愤 +4；
  - 鹰飞：王党志愿军、对手承包商（只有主干拿过 `t_storks_hostile` 才出现）、普军后卫、蒂罗尔射手、普拉托夫的哥萨克、英军骠骑兵。
- **过路费**：克雷莫纳到摩德纳（去博洛尼亚见法利亚的路要交钱）、塞哥维亚到马德里。
- **航程**：土伦 → 马耳他 → 亚历山大港各 3 天；灰鼻角 → 海斯 1 天。
- **岔路标签**：阿尔巴雷多骡道（`duel_route`），绕开巴德堡。

完整节点表见文末附录（由脚本生成）。

---

## 5 难度

### 5.1 等级表（全局 L，全部写绝对值）

| 段 | 章 | Boss | 精英（≤ Boss−1） | 遭遇战 / 随机槽 / 对手遭遇（≤ Boss−2） |
|---|---|---|---|---|
| 主干 | 土伦 | 1 | — | —（教学：随机槽不出仗） |
| | 意大利 | 3 | 2 | 1 |
| | 第二幕 | 5 | 4 | 3 |
| | 第三幕 | 7 | 6 | 5 |
| | 第四幕 | 9 | 8 | 7 |
| | 俄罗斯 | 10 | 9（博罗季诺锚点战也是 9） | 8 |
| | 崩落 | 11 | 10 | 9 |
| | 厄尔巴 | 12 | — | 10 |
| 鹰飞 | 百日 | 14 | 13（利尼、四臂村） | 12（沙勒罗瓦锚点战也是 12） |
| | 莱茵 | 16 | 15（布鲁塞尔锚点战） | 14 |
| | 维也纳 | 18 | — | 16 |
| | 伊比利亚 / 海峡 | 20 | — | 18 |
| | 涅曼河 | 22 | — | 20 |
| | 最后的同盟 | 24 | — | 22 |

- `scene_battles` 里的 level 都是绝对值，不再加 `level_offset`。offset 只用于没写 level、要按 2·幕−1 推算的旧场景（远洋）。
- 剧情锚点上的仗（博罗季诺、沙勒罗瓦、布鲁塞尔）不算可绕的精英，等级按 ≤ Boss−1 检查，R2 里算作战斗节点。
- 模板的等级段是 [base, base+11]：校验器检查每次用到的 L 都在这个段里。通用遭遇战 base 1 的那几张管 L1–12；base 12 的布拉班特农庄和奥安凹路管 L12–23。

### 5.2 一处 ARCH 规则冲突，以及本稿的读法

ARCH §3.1 有两条规则：「分支第一场 ≥ 主干最后一场 + 1」，以及「同章 battle ≤ Boss − 2」。主干最后一场是 L12，鹰飞第一章 Boss 是 L14，于是遭遇战既要 ≤ 12 又要 ≥ 13，无解。

本稿的读法：
- 分支第一章的 Boss ≥ 主干最后一个 Boss + 2；
- 精英与锚点战 ≥ 主干最后一个 Boss + 1；
- 遭遇战不低于主干最后一个 Boss。

照这个读法，沙勒罗瓦和随机遭遇战是 L12，利尼和四臂村是 L13，滑铁卢是 L14。校验器按这个读法查（`check_conquest.py` 里的 branch-first floor）。如果 A 坚持 ARCH 原文，就要把鹰飞第一章的 Boss 提到 L15，后面依次顺延。

### 5.3 跨战斗修正

- 利尼打死布吕歇尔（`kill_flags` → `k_blucher_down`）：滑铁卢删掉第 11 回合齐滕的那一波。
- 弗勒吕斯军议选「格鲁希每两个钟头报一次信」（`k_grouchy_close`）：滑铁卢多一回合布阵。
- 四臂村占住路口（`k_crossroads_held`）：滑铁卢的大炮群高地多一格可部署。

以上都由战役层在 `battle_prepare` 时翻成 setup 修正，规则内核不用认识这些旗标。

---

## 6 伙伴与羁绊

| id | 名字 | 兵种（费） | 阵营标签 | 入队 | 宿命 / 隐患 |
|---|---|---|---|---|---|
| baptiste | 巴蒂斯特中士 | 工兵 3 | 意大利、军需官 | 土伦 | — |
| corso | 科尔索 | 猎兵 3（远洋原值） | 意大利、军需官、帝国旧部 | 土伦 | — |
| marie | 玛丽·朗热 | 军医 3（远洋原值） | 军需官、家眷、暗影 | 尼斯 | 远洋里她就是朗伍德的洗衣妇，同一个人 |
| muiron | 米隆 | 战列 5 | 意大利、参谋部 | 尼斯 | 宿命：阿尔科莱堤道（命悬一线 −2 枚）；名羁绊「替你挡枪」 |
| lannes | 拉纳 | 掷弹兵 6 | 意大利、将星 | 米兰（发欠饷） | 宿命：阿斯佩恩 |
| murat | 缪拉 | 骠骑兵 4 | 将星、意大利 | 米兰（收回扣） | 隐患：信赖 < 3 的话，崩落一章开始时离队 |
| desaix | 德塞 | 战列 5 | 将星 | 后备军团商贩 | 宿命：马伦哥（沃盖拉军议能让他赶上） |
| larrey | 拉雷 | 军医 3 | 老近卫军、家眷 | 阿卡（分开伤病员） | 被动：他在场时所有伙伴命悬一线 +1 枚 |
| rustam | 鲁斯塔姆 | 骠骑兵 3 | 老近卫军、参谋部 | 东方军团商贩 | 隐患：厄尔巴一章离队 |
| eble | 埃布莱 | 工兵 4 | 博学 | 涅曼河 | 宿命：别列津纳 |
| gourgaud | 古尔戈 | 掷弹兵 6（远洋原值） | 参谋部、帝国旧部、荒岛 | 涅曼河 | — |
| pierre | 小皮埃尔 | 鼓手 3 | 军需官、家眷 | 别列津纳 | 1819 年以前只能留守 |
| drouot | 德鲁奥 | 炮兵 7 | 老近卫军、博学 | 儒安湾 | — |
| cambronne | 康布罗纳 | 掷弹兵 6 | 老近卫军 | 儒安湾 | 宿命：滑铁卢 |
| ney | 内伊 | 骠骑兵 4 | 将星 | 欧塞尔「铁笼」事件 | 鲁莽：上场攻 +1，命悬一线 −1 枚 |
| dantes | 唐泰斯 | 骠骑兵 4（远洋原值） | 远洋、暗影 | 战争部「伊夫堡 34 号」 | — |
| faria | 法利亚 | 工兵 3（远洋原值） | 博学、暗影 | 同上，第二个选项（需 faria_half_letter） | 远洋里的宿命场景照旧 |

- **羁绊套 `napoleon`**：
  - 3 条职业羁绊：炮兵学派、方阵、骑兵预备队；
  - 6 条主干阵营羁绊：意大利军团、军需官的人、随军家眷、老近卫军（效果 workshop）、将星（spoils）、参谋部（intel）；
  - 5 条远洋原样的阵营羁绊：帝国旧部、远洋同盟、暗影密使、博学工坊、荒岛求生。
  - 所有效果都是 `BOND_EFFECTS` 里现成的，内核不用新增效果。同一效果有几条同时生效时取最高档（现规则）。
- **名羁绊（数据先行）**：
  - 老相识：巴蒂斯特 + 玛丽；
  - 替你挡枪：米隆 + 主角；
  - 老对头：拉纳 + 缪拉（不和）；
  - 最后的方阵：康布罗纳 + 内伊；
  - 34 号和 27 号：唐泰斯 + 法利亚。
- **要和远洋包对齐的地方**：
  - 科尔索、玛丽、古尔戈的标签多了主干的那几个（最多 3 个），远洋的两个原标签都还在；
  - 远洋那 3 人（friday、nemo、morel）的行由远洋包写。
  - 注意唐泰斯与远洋的冲突：在鹰飞里放出唐泰斯以后，「随驾流放」就不再提供，因为远洋里的唐泰斯要 1829 年才越狱。

---

## 7 敌军

`enemies_trunk_conquest.json` 按反法同盟分成 17 个编组，模板和 `battle_pool` 只从对应的那一组里取：
- 主干：第一次同盟分土伦、意大利两组，第二次同盟分东方、阿尔卑斯两组，第三次同盟、第四次同盟、半岛、第五次同盟、1812、第六次同盟各一组，厄尔巴的私掠船一组；
- 鹰飞：第七次同盟（百日）、莱茵、维也纳、伊比利亚或海峡、第二次涅曼河、最后的同盟。

本稿在 ARCH §5 之外新增 7 个兵种：

| id | 名字 | hp/攻/防/速 | 类型 | 射程 | 标签 | 为什么要 |
|---|---|---|---|---|---|---|
| piedmontese | 皮埃蒙特步兵 | 6/3/1/1 | 步兵 | 0 | — | 让第一幕前半段的敌人看得出不是奥军 |
| barbet | 巴尔贝游击 | 4/3/0/1 | 步兵 | 2 | ambush | 尼斯后山的山民，从林子里冒出来 |
| tyrolean | 蒂罗尔射手 | 5/4/0/1 | 步兵 | 3 | sniper | 里沃利以后出现，专挑主角和伙伴打 |
| chevauleger | 奥军轻骑 | 8/4/1/2 | 骑兵 | 0 | — | L ≤ 12 的遭遇战不许有猎官，需要一个不带猎官的快骑兵 |
| dutch_belgian | 荷比民兵 | 5/3/0/1 | 步兵 | 0 | — | 1815 年比英军弱一档的兵 |
| brunswicker | 布伦瑞克黑衣兵 | 6/4/0/1 | 步兵 | 0 | skirmisher | 白刃之后后退脱离 |
| blucher | 布吕歇尔 | 16/5/2/2 | 纵队长 | 0 | officer, rally | 利尼的敌将；被「打死」在文案里写成落马被俘 |

---

## 8 战场（本包画了 15 张）

| 模板 | 用在哪里 | 规模 / 尺寸 | L | 天时 | 地形要点 |
|---|---|---|---|---|---|
| `toulon_night` | 序章 Boss（教学） | elite 8×4 | 1 | 雨 | 棱堡墙挡视线、堡门缺口、两条反扑路、G1 英军炮 |
| `montenotte` | 意大利遭遇战 | skirmish 8×3 | 1 | 雾 / 晴 | 断崖（虚空）把山脊切成两段，两条骡道 |
| `lodi_bridge` | 意大利精英 | elite 8×4 | 2 | 晴 | 阿达河单桥长廊；第 5 回合上游露出浅滩，多出一条路 |
| `arcole_dikes` | 意大利精英（战役段） | elite 9×5 | 2 | 雾 / 晴 | 两条堤道、四角沼泽（虚空）、阿尔波内河第 5 回合变浅滩 |
| `rivoli_plateau` | 意大利 Boss | major 10×6 | 3 | 晴 | 四路来敌、峡谷之字路、河对岸的炮位、弹药车爆炸 |
| `la_favorita` | 意大利精英（追击，rush） | elite 9×4 | 2 | 晴 / 雾 | 鹰旗在正中，两边同时来，宫墙挡视线 |
| `skirmish_terraces` | 主干随机槽 | skirmish 7×3 | 1–12 | 晴 / 雨 / 雾 | 梯田石墙挡视线，杀伤区要放在空地上 |
| `skirmish_mill_ford` | 主干随机槽 | skirmish 8×3 | 1–12 | 晴 / 雨 / 泥 | 磨坊（房屋）、浅滩边的烂泥 |
| `skirmish_hamlet` | 主干随机槽 | skirmish 8×4 | 1–12 | 晴 / 雾 / 夜 | 村街、房屋，巴尔贝从鹰旗背后的林子里伏击 |
| `charleroi_bridge` | 鹰飞锚点战 | skirmish 7×3 | 12 | 晴 | 桑布尔河城桥、瓦砾路障、临河房屋 |
| `skirmish_brabant_farm` | 鹰飞随机槽 | skirmish 8×3 | 12–23 | 晴 / 雨 / 泥 | 带围墙的农庄夹在两条路中间 |
| `skirmish_sunken_lane`（新） | 鹰飞随机槽 | skirmish 8×4 | 12–23 | 晴 / 雨 / 泥 | 凹路是烂泥杀伤区，北路干路快一倍，南路抄后路 |
| `ligny` | 鹰飞精英 | elite 9×5 | 13 | 晴 / 雨 | 小溪两座桥、房屋、墓园墙；布吕歇尔第 7 回合亲自冲锋 |
| `quatre_bras` | 鹰飞精英 | elite 9×5 | 13 | 晴 | 三路援军按时间到；博叙林里的敌人挨远程防 +2 |
| `waterloo` | 鹰飞 Boss | epic 12×7 | 14 | 泥 | 普朗斯努瓦，不打威灵顿：守右翼；房屋第 9 回合烧塌成瓦砾；四路普军 |

- 每张的 `notes` 都写了「什么都不做为什么必输」（具体在第几回合漏几个、军心怎么降）和「为什么一步解不了」。
- `--sim` 用 ARCH 的步耗规则逐图、逐天时、逐等级（base、节点等级、base+11）跑了「什么都不做」，结果全部是败。
- 要 B 画的模板共 26 张：ARCH §5 清单里的 18 张，加本稿提议的 8 张（fort_bard、jena、somosierra、aspern、krasnoi、dresden、hanau，以及鹰飞第四章另一条线的 Boss `channel_landing`）。都列在 `templates_needed` 里，每张写了地形要点和兜底模板（elite_a / major_a）。
- `battle_pool_wanted` 还列了 5 张有战区味道的通用遭遇战：沙漠、山地村、雪村、莱茵渡口、多瑙河磨坊。现在第二到第六幕的随机仗打出来是奥军面孔，不对味，需要 B 来补。

---

## 9 剧情

### 9.1 主干

- **序章与第一幕**（上一轮写的）：
  - 数不对的火药桶（土伦炮兵库，揭穿换酒的人）；
  - 小直布罗陀（暴雨夜守棱堡）；
  - 空钱柜和新司令（尼斯：玛丽的欠条、纸底鞋）；
  - 米兰的清单（捐献、欠饷、掉在地上的金币）；
  - 里沃利的月光；
  - 坎波福米奥（第八十四只箱子）。
- **第二到第六幕**：每幕一场调令，加一两场写战区的场景。
- **终章**：二百二十平方公里的帝国、港口的三盏灯、台球桌上的地图（分岔）。
- 跨段伏笔：
  - 法利亚的半封信（博洛尼亚，1796），伊夫堡线和鹰飞都会读；
  - 提普苏丹的使者（开罗）：远洋里尼摩的软挂钩；
  - 法老号的大副（费拉约港码头）。

### 9.2 鹰飞（`conquest.json`）

**第一章 · 百日 1815（写满）**

| 场景 | 日期 | 内容 | 抉择写下的旗标 |
|---|---|---|---|
| k_golfe_juan | 03-01 | 十二只箱子，骡子只够驮八只；德鲁奥、康布罗纳入队 | k_light_chests / k_all_chests / k_paid_cannes |
| k_laffrey | 03-07 | 「你们当中谁要杀他的皇帝，就开枪吧」；当晚发饷 | k_fifth_paid / k_officers_paid / k_paris_promise |
| k_tuileries | 03-20 | 挂毯底下的蜜蜂；莫利安的账；富歇问你和马赛的维尔福是什么关系 | k_bankers / k_requisition_1815 / k_royal_silver |
| k_charleroi | 06-15 | 锚点战（沙勒罗瓦桥 L12）；旺达姆没收到命令 | k_double_couriers / k_charleroi_held / k_charleroi_pushed |
| k_waterloo | 06-18 | Boss（普朗斯努瓦 L14）；「近卫军不投降」 | k_guard_charged / k_plancenoit_held / k_bulow_chased |
| k_waterloo_night | 06-18 夜 | 滑铁卢村客栈里的账：一万伤员、六十把锯子 | **k_wounded_exchanged** / k_pursuit / k_trophies |

本章还有：
- 固定事件：欧塞尔「铁笼」（内伊入队）、战争部「伊夫堡 34 号」（见 §0）；
- 弗勒吕斯军议（格鲁希的命令上没写时辰）；
- 3 个随机事件：联盟军的长矛、旺代又起来了（民愤 ≥ 25 才出现）、驿站的马。

**第二到第六章（压缩）**

| 章 | 场景 | 战场 | 留余地的抉择（计入「鹰的和平」） |
|---|---|---|---|
| 莱茵之秋 1815 | 布鲁塞尔（锚点战 L15）→ 塔列朗在梅斯 → 劳特河（Boss L16） | brussels、rhine_crossing | k_peace_offered |
| 第三次维也纳 1816 | 宁芬堡宫 → 维也纳城墙（Boss L18）→ 美泉宫的锡兵 | vienna_streets | k_vienna_spared、k_son_stays |
| 伊比利亚或海峡 1817 | 布洛涅木屋（二选一）→ 托雷斯韦德拉什 ‖ 多佛尔白崖（Boss L20） | iberia_return ‖ channel_landing | k_spain_amnesty ‖ k_london_parley |
| 第二次涅曼河 1818 | 华沙（面包放在夏天里）→ 科夫诺（Boss L22） | niemen | k_niemen_parley（以及事件里的 k_carters_paid） |
| 最后的同盟 1819 | 五十岁生日 → 第二次民族之战（Boss L24）→ 帐篷里的三样东西 | coalition_final | （歌德事件里的 k_goethe_listened） |

本段其他事件：
- 固定事件 8 个：
  - 铁笼、伊夫堡 34 号；
  - 维也纳来的信（玛丽-路易丝不回来了）；
  - 梅尔克修道院图书馆（主干拿过 `t_return_mark` 才能「原样留下」）；
  - 阿拉皮莱斯的白骨；
  - 美国人的潜水船（富尔顿的学生拿着 1800 年「鹦鹉螺号」的图纸，凡尔纳给尼摩的船起名正是借此）；
  - 提尔西特的木筏；
  - 歌德的茶。
- 军议 7 场。
- 随机事件 10 个。

### 9.3 鹰飞的结局（`rules.endings`，按顺序取第一个满足的）

| 结局 | 条件 | 一句话 |
|---|---|---|
| `k_return` 回到马赛 | 终场选辞呈，且 `k_dantes_freed` | 法老号进港，唐泰斯和梅尔塞苔丝的婚礼推迟了五年才办；这个世界上从来没有过基督山伯爵 |
| `k_pax` 鹰的和平 | 终场选和约，民愤 < 60，且 9 个「留余地」旗标里至少有 3 个 | 皇帝退回莱茵河，罗马王继位；第十一本账簿上写着「欠款还清」 |
| `k_iron` 铁的欧洲 | 终场选皇冠 | 欧罗巴皇帝；你当上帝国军需总监，签了很多年的征发令 |
| `k_dusk` 鹰落（默认） | 以上都不满足 | 1821 年皇帝死在杜伊勒里宫：赢下了每一场仗，却没赢下一张和约 |

- 失败收场：军费告罄、大军溃散、全境起义（各有鹰飞自己的文字），再加讣告（主角阵亡）。
- `big_fate_extra` 有两项：
  - **随驾流放**：只在滑铁卢战败时出现，跳到远洋段的 prologue。放过唐泰斯以后不提供。
  - **最后的方阵**：滑铁卢或莱比锡 1819 战败时出现，军心回到 40，代价是宿命在这一仗的伙伴必须上场断后。

### 9.4 后续章节要扩写的提纲

- **第二章**：加一场「索瓦涅森林里的威灵顿后卫」（精英，模板待画），以及一场普军在列日的后卫战。
- **第三章**：加蒂罗尔山口精英战，用库夫施泰因的随机槽已经能打到；再加一场「卡尔大公的信」。
- **第四章**：伊比利亚线加罗德里戈城攻城（精英）；海峡线加「查塔姆船坞」（Boss 后的收尾）。
- **第五章**：加维尔纳仓库的回响，读主干的 `t_vilna_reserve` 和 `t_lithuania_taken`，以及沙皇的木筏会谈。
- **终章**：加「格鲁希这次准时到了」（读 `k_grouchy_close`），以及皇帝的病（读 `k_emperor_rest`）。

---

## 10 美术

`data/hd/art_requests/C_conquest.json`，条目形状同 art_list.json，由 B 合入：

- **背景 72 张**：
  - 主干和鹰飞每一场剧情一张；
  - 军议共用一张 `hq_tent`；
  - 随机事件共用十几张通用背景（村街、仓库、码头、宫殿大厅……）；
  - 3 张手绘局部地图：`map_toulon_1793`、`map_elba`、`map_portoferraio`。
  - P0 是序章、第一幕、厄尔巴、百日的场景。
- **立绘 22 个新人物，各配头像**：波拿巴（青年，和现有的 napoleon 是同一张脸）、米隆、拉纳、缪拉、德塞、拉雷、鲁斯塔姆、埃布莱、德鲁奥、康布罗纳、内伊、达武、富歇、格鲁希、塔列朗、罗马王……
- **现有立绘的年龄变体 4 条**：
  - 维尔福 young / 1805 / 1815：要鹰徽怀表，不要天平坠子；
  - 玛丽 cantiniere；
  - 小皮埃尔 drummer（10 岁）；
  - 巴蒂斯特 1793。
- **结局插图 4 张**。
- **战场小人**：12 名伙伴，加本稿新增的 7 个敌人（各配头像）。
- **地图图标 3 个**：军议、对手、兵站（ARCH 原有 11 个之外）。

演出表 `vn_cast_conquest.json` 给出 123 个场景和事件的背景 id 与主讲人。

---

## 11 校验器（`tools/check_conquest.py`）

检查内容：

- **战场模板**：
  - 字符、尺寸；
  - 路线：起点必须是红门、舱口、牢门或伏兵出生格，终点必须是鹰旗，相邻两格连续，在首次使用时和最终地形下都可走；
  - 定点单位（炮、post）的 at 格；
  - 命令格可站；
  - 「什么都不做必输」的模拟（每个天时 × base、节点等级、base+11 三个等级）；
  - 等级目标（只提醒）。
- **段定义**：
  - 内核 v1 的 `_valid_definition` 规则：场景顺序、查验种类、抉择键、effects 只用六项指标；
  - v2 扩展的键与条件小语言；
  - 每场至少一个不设门槛的抉择；
  - 事件不许带 branch / advance；
  - 招募的伙伴必须在伙伴表里；
  - 结局读到的旗标必须有人写；
  - 旗标前缀。
- **地图**：
  - 节点和连线的形状；
  - 每场剧情恰好对应一个锚点；锚点按场景顺序可达（按战区变体分别算）；
  - 战役段只能经开拔营地进入；
  - R1–R5、R7；
  - 等级规则；
  - 模板存在，或已列入 templates_needed；
  - 对手走的是真实连线；
  - 每个镜头窗里的节点间距。
- **书**：
  - battle_pool 里每张模板都在自己的等级段内；
  - R6；
  - 鹰飞第一章的等级下限（§5.2）。
- **文字**：ARCH §6 的防回潮词表（0 命中），以及 data 下不许有浮点数。

现有 11 条提醒：
- 7 张模板的回合上限比等级表目标多 1：montenotte、arcole_dikes、两张主干通用遭遇战、三张 L12 遭遇战。这是有意的，多这一回合，「什么都不做必输」才成立。
- 4 对节点标记间距在 43–51px 之间（≥ 40 是硬下限）。

---

## 12 待主创或 A、B 拍板

1. **§5.2 的等级读法**：或者照 ARCH 原文，把鹰飞整体上移 1 级。
2. **§3 的小扩展**：特别是 `scenes[].when` 和镜头窗（frames）。不要 frames 的话，第二到第四幕得拆成独立的章，调令放进上一章的收尾。
3. **主干体量**：现在是 8 章。ARCH 风险 2 建议第一版做 4 张图。本稿的建议是保留 8 章，但第二到第六幕每张图的积累段可以先只开放一个战区。
4. **唐泰斯被放出后与远洋的矛盾**：现在的做法是直接关掉随驾流放。另一种做法是远洋包为「唐泰斯已在队伍里」写一套替代文字。
5. **B 画模板的顺序建议**：elba_cove（主干最后一战）、acre 和 marengo（第二幕）、austerlitz，然后是本稿提议的 7 张。

---

## 附录 · 地图节点表（脚本生成）

<!-- TABLES:BEGIN -->

### 主干 `maps/europe.json`

#### toulon（11 个节点，days_max 6，驿站印 1，插曲 —）

镜头：`toulon`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `ollioules` | 奥利乌勒·炮兵库 | 剧情 | 积累 | 1793-11-20 | 场景 `toulon_arrival` |
| `beausset` | 博塞 | 随机槽 | 积累 |  | 池 toulon：事件8 补给1 营地1 |
| `evenos` | 埃弗诺 | 随机槽 | 积累 |  | 池 toulon：事件8 补给1 营地1 |
| `bandol` | 邦多勒 | 随机槽 | 积累 |  | 池 toulon：事件8 补给1 营地1 |
| `sanary` | 萨纳里港 | 补给·港口 | 积累 |  |  |
| `six_fours` | 六炉村 | 随机槽 | 积累 |  | 池 toulon：事件8 补给1 营地1 |
| `sans_peur` | 无畏者炮台 | 补给·驿站 | 积累 |  |  |
| `la_seyne` | 拉塞讷营地 | 营地·开拔 | 积累 |  |  |
| `dugommier_hq` | 杜戈米埃的军议 | 事件·军议 | 战役 | 1793-12-11 | 事件 `ev_council_toulon` |
| `caire_foot` | 凯尔高地脚下（雨夜） | 营地 | 战役 |  |  |
| `petit_gibraltar` | 小直布罗陀棱堡 | Boss | 战役 | 1793-12-17 | 场景 `toulon_mulgrave`；toulon_night L1 |

连线：ollioules–beausset 1；ollioules–evenos 1；ollioules–sanary 2（军需 1）；beausset–bandol 1；bandol–sanary 1；sanary–six_fours 1；six_fours–la_seyne 1；evenos–sans_peur 1；ollioules–sans_peur 2；sans_peur–la_seyne 1；la_seyne–dugommier_hq 1；dugommier_hq–caire_foot 1；caire_foot–petit_gibraltar 1

#### italy（25 个节点，days_max 18，驿站印 2，插曲 audience）

镜头：`italy_quad`（{"mustered": true}）、`italy_wide`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `nice` | 尼斯·军团司令部 | 剧情 | 积累 | 1796-03-27 | 场景 `italy_nice` |
| `oneglia` | 奥内利亚 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 |
| `loano` | 洛阿诺驿站 | 补给·驿站 | 积累 | 1796-04 |  |
| `montenotte` | 蒙特诺特 | 遭遇战 | 积累 | 1796-04-12 | montenotte L1；天时 fog/clear |
| `ceva` | 切瓦 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 遭遇战2 L1 |
| `cherasco` | 切拉斯科（停战） | 营地 | 积累 | 1796-04-28 |  |
| `alessandria` | 亚历山德里亚仓库 | 补给 | 积累 |  |  |
| `tortona` | 托尔托纳 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 遭遇战2 L1 |
| `pavia` | 帕维亚 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 遭遇战2 L1 |
| `piacenza` | 皮亚琴察渡口 | 补给·驿站 | 积累 | 1796-05-07 |  |
| `lodi` | 洛迪 | 精英 | 积累 | 1796-05-10 | lodi_bridge L2；天时 clear |
| `milan` | 米兰·塞尔贝洛尼宫 | 剧情 | 积累 | 1796-05-15 | 场景 `italy_milan` |
| `cremona` | 克雷莫纳的随军商贩 | 商贩 | 积累 |  |  |
| `brescia` | 布雷西亚 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 遭遇战2 L1 |
| `modena` | 摩德纳 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 |
| `bologna` | 博洛尼亚·斯帕达府 | 事件 | 积累 | 1796-06-24 | 事件 `ev_faria_half_letter`；需 {"scene_done": "italy_milan"} |
| `castiglione` | 卡斯蒂廖内 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 |
| `legnago` | 莱尼亚戈 | 随机槽 | 积累 |  | 池 italy：事件5 补给2 营地2 商贩1 遭遇战2 L1 |
| `peschiera` | 佩斯基耶拉（开拔） | 营地·开拔 | 积累 |  |  |
| `verona` | 维罗纳军议 | 事件·军议 | 战役 | 1796-11-14 | 事件 `ev_council_italy` |
| `arcole` | 阿尔科莱 | 精英 | 战役 | 1796-11-15 | arcole_dikes L2；天时 fog/clear |
| `villafranca` | 维拉弗兰卡营火 | 营地 | 战役 |  |  |
| `rivoli` | 里沃利高原 | Boss | 战役 | 1797-01-14 | 场景 `italy_rivoli`；rivoli_plateau L3 |
| `la_favorita` | 拉法沃里塔 | 精英 | 战役 | 1797-01-16 | la_favorita L2；需 {"flags": ["t_favorita_pursuit"]}；天时 clear/fog |
| `campo_formio` | 坎波福米奥·帕塞里亚诺 | 剧情 | 战役 | 1797-10-17 | 场景 `italy_campo_formio` |

连线：nice–oneglia 2；oneglia–loano 1；oneglia–ceva 2（军需 1）；loano–montenotte 1；loano–ceva 1；ceva–cherasco 1；montenotte–cherasco 2；montenotte–alessandria 2；cherasco–alessandria 2；alessandria–tortona 1；alessandria–pavia 2；tortona–piacenza 2；piacenza–lodi 1；pavia–milan 1；lodi–milan 1；piacenza–cremona 1；lodi–cremona 1；milan–brescia 2；cremona–brescia 2；cremona–modena 2（过路费 {"gold": 1}）；modena–bologna 1；brescia–castiglione 1；castiglione–peschiera 1；modena–legnago 2；legnago–peschiera 2（军需 1）；castiglione–legnago 2；peschiera–verona 1；verona–arcole 1；arcole–villafranca 2；verona–villafranca 1；villafranca–rivoli 2；rivoli–la_favorita 2（急行 True）；rivoli–campo_formio 4；la_favorita–campo_formio 4

对手：巴尔贝山民（barbets，路线 ceva→cherasco→ceva→loano，遭遇 skirmish_terraces L1）；白鹳商行车队（storks_convoy，路线 alessandria→tortona→piacenza→cremona→piacenza→tortona）

兵站套：lombardy = alessandria+piacenza+cremona

#### orient_alps（33 个节点，days_max 14，驿站印 2，插曲 bond）

镜头：`syria_1799`（{"flags": ["t_orient"], "mustered": true}）、`egypt_1798`（{"flags": ["t_orient"]}）、`marengo_1800`（{"flags": ["t_alps"], "mustered": true}）、`alps_1800`（{"flags": ["t_alps"]}）、`med_1798`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `toulon_1798` | 土伦港（三百艘船） | 剧情 | 积累 | 1798-05-10 | 场景 `orient_orders` |
| `malta` | 马耳他·骑士团的银库 | 事件 | 积累 | 1798-06-12 | 事件 `ev_malta_silver`；需 {"flags": ["t_orient"]} |
| `alexandria` | 亚历山大港 | 补给·港口 | 积累 | 1798-07-02 | 需 {"flags": ["t_orient"]} |
| `aboukir` | 阿布基尔 | 随机槽 | 积累 |  | 池 orient：事件6 补给2 营地1 商贩1 遭遇战2 L3；需 {"flags": ["t_orient"]} |
| `rosetta` | 罗塞塔驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_orient"]} |
| `damanhur` | 达曼胡尔 | 随机槽 | 积累 |  | 池 orient：事件6 补给2 营地1 商贩1；需 {"flags": ["t_orient"]} |
| `pyramids` | 金字塔下 | 精英 | 积累 | 1798-07-21 | pyramids L4；需 {"flags": ["t_orient"]}；天时 desert |
| `cairo` | 开罗·司令部 | 事件 | 积累 |  | 事件 `ev_mysore_envoy`；需 {"flags": ["t_orient"]} |
| `bilbeis` | 比勒拜斯 | 随机槽 | 积累 |  | 池 orient：事件6 补给2 营地1 商贩1 遭遇战2 L3；需 {"flags": ["t_orient"]} |
| `suez` | 苏伊士 | 随机槽 | 积累 |  | 池 orient：事件6 补给2 营地1 商贩1；需 {"flags": ["t_orient"]} |
| `salheyeh` | 萨利希耶的骆驼市 | 商贩 | 积累 |  | 需 {"flags": ["t_orient"]} |
| `katia` | 卡蒂亚 | 随机槽 | 积累 |  | 池 orient：事件6 补给2 营地1 商贩1；需 {"flags": ["t_orient"]}；天时 desert |
| `el_arish` | 阿里什 | 随机槽 | 积累 |  | 池 orient：事件6 补给2 营地1 商贩1 遭遇战2 L3；需 {"flags": ["t_orient"]}；天时 desert |
| `gaza` | 加沙驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_orient"]} |
| `jaffa` | 雅法（开拔） | 营地·开拔 | 积累 | 1799-03-07 | 需 {"flags": ["t_orient"]} |
| `dijon` | 第戎·后备军仓库 | 补给 | 积累 | 1800-04 | 需 {"flags": ["t_alps"]} |
| `geneva` | 日内瓦 | 随机槽 | 积累 |  | 池 alps：事件6 补给2 营地1 商贩1 遭遇战2 L3；需 {"flags": ["t_alps"]} |
| `lausanne` | 洛桑驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_alps"]} |
| `villeneuve` | 维尔讷沃 | 随机槽 | 积累 |  | 池 alps：事件6 补给2 营地1 商贩1；需 {"flags": ["t_alps"]} |
| `great_st_bernard` | 大圣伯纳德山口 | 事件 | 积累 | 1800-05-20 | 事件 `ev_st_bernard`；需 {"flags": ["t_alps"]}；天时 snow |
| `aosta` | 奥斯塔 | 随机槽 | 积累 |  | 池 alps：事件6 补给2 营地2 商贩1；需 {"flags": ["t_alps"]} |
| `fort_bard` | 巴德堡 | 精英 | 积累 | 1800-05-21 | fort_bard L4；需 {"flags": ["t_alps"]} |
| `ivrea` | 伊夫雷亚驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_alps"]} |
| `vercelli` | 韦尔切利 | 随机槽 | 积累 |  | 池 alps：事件6 补给2 营地1 商贩1；需 {"flags": ["t_alps"]} |
| `novara` | 诺瓦拉 | 随机槽 | 积累 |  | 池 alps：事件6 补给2 营地1 商贩1 遭遇战2 L3；需 {"flags": ["t_alps"]} |
| `milan_1800` | 米兰（再入城） | 商贩 | 积累 | 1800-06-02 | 需 {"flags": ["t_alps"]} |
| `stradella` | 斯特拉代拉（开拔） | 营地·开拔 | 积累 |  | 需 {"flags": ["t_alps"]} |
| `caesarea` | 凯撒利亚军议 | 事件·军议 | 战役 |  | 事件 `ev_council_acre`；需 {"flags": ["t_orient"]} |
| `haifa` | 迦密山下的营火 | 营地 | 战役 |  | 需 {"flags": ["t_orient"]} |
| `acre` | 阿卡城下 | Boss | 战役 | 1799-05-10 | 场景 `orient_acre`；acre L5；需 {"flags": ["t_orient"]} |
| `voghera` | 沃盖拉军议 | 事件·军议 | 战役 |  | 事件 `ev_council_marengo`；需 {"flags": ["t_alps"]} |
| `san_giuliano` | 圣朱利亚诺营火 | 营地 | 战役 |  | 需 {"flags": ["t_alps"]} |
| `marengo` | 马伦哥平原 | Boss | 战役 | 1800-06-14 | 场景 `alps_marengo`；marengo L5；需 {"flags": ["t_alps"]} |

连线：toulon_1798–malta 航 3 天（需 {"flags": ["t_orient"]}）；malta–alexandria 航 3 天；alexandria–aboukir 1；aboukir–rosetta 1；alexandria–damanhur 1；rosetta–damanhur 1；damanhur–pyramids 2；pyramids–cairo 1；damanhur–cairo 3（军需 1）；cairo–bilbeis 1；bilbeis–suez 2（军需 1）；bilbeis–salheyeh 1；salheyeh–katia 2（军需 1）；katia–el_arish 2（军需 1）；el_arish–gaza 2；gaza–jaffa 1；toulon_1798–dijon 4（需 {"flags": ["t_alps"]}）；dijon–geneva 2；dijon–lausanne 3；geneva–lausanne 1；lausanne–villeneuve 1；geneva–villeneuve 2；villeneuve–great_st_bernard 2（军需 1）；great_st_bernard–aosta 1；aosta–fort_bard 1；fort_bard–ivrea 1；aosta–ivrea 3（军需 2，岔路 "duel_route"）；ivrea–vercelli 2；vercelli–novara 1；ivrea–novara 2；novara–milan_1800 2；milan_1800–stradella 2；jaffa–caesarea 1；caesarea–haifa 1；haifa–acre 1；stradella–voghera 1；voghera–san_giuliano 1；san_giuliano–marengo 1

对手：贝都因骑手（bedouin_raiders，路线 bilbeis→salheyeh→katia→salheyeh，遭遇 skirmish_mill_ford L3）

兵站套：nile = alexandria+rosetta+gaza

#### austerlitz_jena（31 个节点，days_max 15，驿站印 2，插曲 minigame:decode）

镜头：`moravia_1805`（{"flags": ["t_austerlitz"], "mustered": true}）、`poland_1807`（{"flags": ["t_prussia"], "mustered": true}）、`north_1805`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `boulogne` | 布洛涅营地 | 剧情 | 积累 | 1805-08-27 | 场景 `boulogne_orders` |
| `amiens` | 亚眠 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1 遭遇战2 L5；需 {"flags": ["t_austerlitz"]} |
| `reims` | 兰斯驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_austerlitz"]} |
| `strasbourg` | 斯特拉斯堡面包站 | 补给 | 积累 |  | 需 {"flags": ["t_austerlitz"]} |
| `stuttgart` | 斯图加特 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1；需 {"flags": ["t_austerlitz"]} |
| `ulm` | 乌尔姆 | 精英 | 积累 | 1805-10-20 | ulm L6；需 {"flags": ["t_austerlitz"]}；天时 rain/mud |
| `donauworth` | 多瑙沃特 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1 遭遇战2 L5；需 {"flags": ["t_austerlitz"]} |
| `augsburg` | 奥格斯堡·两万七千个俘虏 | 事件 | 积累 | 1805-10-22 | 事件 `ev_ulm_prisoners`；需 {"flags": ["t_austerlitz"]} |
| `munich` | 慕尼黑宿营 | 营地 | 积累 |  | 需 {"flags": ["t_austerlitz"]} |
| `braunau` | 布劳瑙 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1 遭遇战2 L5；需 {"flags": ["t_austerlitz"]} |
| `passau_1805` | 帕绍 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1；需 {"flags": ["t_austerlitz"]} |
| `linz` | 林茨驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_austerlitz"]} |
| `vienna_1805` | 维也纳（开拔） | 营地·开拔 | 积累 | 1805-11-13 | 需 {"flags": ["t_austerlitz"]} |
| `mainz` | 美因茨仓库 | 补给 | 积累 |  | 需 {"flags": ["t_prussia"]} |
| `wurzburg` | 维尔茨堡 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1 遭遇战2 L5；需 {"flags": ["t_prussia"]} |
| `fulda_1806` | 富尔达 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1 遭遇战2 L5；需 {"flags": ["t_prussia"]} |
| `bamberg` | 班贝格驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_prussia"]} |
| `hof` | 霍夫 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1；需 {"flags": ["t_prussia"]} |
| `jena` | 耶拿 | 精英 | 积累 | 1806-10-14 | jena L6；需 {"flags": ["t_prussia"]}；天时 fog |
| `leipzig_1806` | 莱比锡 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1 遭遇战2 L5；需 {"flags": ["t_prussia"]} |
| `berlin_1806` | 柏林·腓特烈的佩剑 | 事件 | 积累 | 1806-10-27 | 事件 `ev_frederick_sword`；需 {"flags": ["t_prussia"]} |
| `kustrin` | 屈斯特林要塞的军火库 | 商贩 | 积累 |  | 需 {"flags": ["t_prussia"]} |
| `posen` | 波森驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_prussia"]} |
| `thorn_1807` | 托伦 | 随机槽 | 积累 |  | 池 north：事件6 补给2 营地1 商贩1 遭遇战2 L5；需 {"flags": ["t_prussia"]} |
| `warsaw_1807` | 华沙（开拔） | 营地·开拔 | 积累 |  | 需 {"flags": ["t_prussia"]} |
| `brunn` | 布吕恩军议 | 事件·军议 | 战役 |  | 事件 `ev_council_austerlitz`；需 {"flags": ["t_austerlitz"]} |
| `zuran` | 祖兰山的草把火 | 营地 | 战役 | 1805-12-01 | 需 {"flags": ["t_austerlitz"]} |
| `austerlitz_field` | 普拉岑高地 | Boss | 战役 | 1805-12-02 | 场景 `austerlitz_sun`；austerlitz L7；需 {"flags": ["t_austerlitz"]} |
| `osterode` | 奥斯特罗德军议 | 事件·军议 | 战役 |  | 事件 `ev_council_eylau`；需 {"flags": ["t_prussia"]} |
| `landsberg_ep` | 兰茨贝格雪夜 | 营地 | 战役 |  | 需 {"flags": ["t_prussia"]} |
| `eylau_field` | 埃劳墓地 | Boss | 战役 | 1807-02-08 | 场景 `eylau_snow`；eylau L7；需 {"flags": ["t_prussia"]}；天时 snow |

连线：boulogne–amiens 2（需 {"flags": ["t_austerlitz"]}）；amiens–reims 2；reims–strasbourg 3（军需 1）；strasbourg–stuttgart 2；stuttgart–ulm 1；stuttgart–donauworth 2；ulm–augsburg 1；donauworth–augsburg 1；augsburg–munich 1；munich–braunau 2；braunau–passau_1805 1；passau_1805–linz 2；braunau–linz 3（军需 1）；linz–vienna_1805 3（军需 1）；boulogne–mainz 4（军需 1，需 {"flags": ["t_prussia"]}）；mainz–wurzburg 2；mainz–fulda_1806 2；wurzburg–bamberg 1；fulda_1806–bamberg 2；bamberg–hof 1；hof–jena 1；hof–leipzig_1806 2；jena–berlin_1806 3；leipzig_1806–berlin_1806 2；berlin_1806–kustrin 1；kustrin–posen 3（军需 1）；berlin_1806–posen 4（军需 2）；posen–thorn_1807 2；thorn_1807–warsaw_1807 2（军需 1）；posen–warsaw_1807 4（军需 2）；vienna_1805–brunn 2；brunn–zuran 1；zuran–austerlitz_field 1；warsaw_1807–osterode 3（军需 1）；osterode–landsberg_ep 2（军需 1）；landsberg_ep–eylau_field 1

对手：奥军轻骑巡逻（kienmayer_hussars，路线 munich→braunau→passau_1805→braunau，遭遇 skirmish_hamlet L5）；普鲁士骠骑兵（prussian_hussars，路线 hof→leipzig_1806→berlin_1806→leipzig_1806，遭遇 skirmish_mill_ford L5）

兵站套：danube_bread = reims+strasbourg+linz

#### iberia_danube（29 个节点，days_max 12，驿站印 2，插曲 audience）

镜头：`aragon_1809`（{"flags": ["t_spain"], "mustered": true}）、`lobau_1809`（{"flags": ["t_danube"], "mustered": true}）、`west_1808`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `bayonne` | 巴约讷·马拉克城堡 | 剧情 | 积累 | 1808-05-10 | 场景 `bayonne_orders` |
| `pamplona` | 潘普洛纳驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_spain"]} |
| `vitoria` | 维多利亚 | 随机槽 | 积累 |  | 池 iberia：事件6 补给2 营地1 商贩1；需 {"flags": ["t_spain"]} |
| `burgos` | 布尔戈斯 | 随机槽 | 积累 |  | 池 iberia：事件6 补给2 营地1 商贩1 遭遇战2 L7；需 {"flags": ["t_spain"]} |
| `aranda` | 阿兰达 | 随机槽 | 积累 |  | 池 iberia：事件6 补给2 营地1 商贩1；需 {"flags": ["t_spain"]} |
| `somosierra` | 索莫谢拉 | 精英 | 积累 | 1808-11-30 | somosierra L8；需 {"flags": ["t_spain"]}；天时 fog |
| `segovia` | 塞哥维亚 | 随机槽 | 积累 |  | 池 iberia：事件6 补给2 营地1 商贩1 遭遇战2 L7；需 {"flags": ["t_spain"]} |
| `madrid_1808` | 马德里·五月三日 | 事件 | 积累 | 1808-12-04 | 事件 `ev_dos_de_mayo`；需 {"flags": ["t_spain"]} |
| `toledo` | 托莱多的刀匠街 | 商贩 | 积累 |  | 需 {"flags": ["t_spain"]} |
| `soria` | 索里亚 | 随机槽 | 积累 |  | 池 iberia：事件6 补给2 营地1 商贩1 遭遇战2 L7；需 {"flags": ["t_spain"]} |
| `calatayud` | 卡拉塔尤德驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_spain"]} |
| `tudela` | 图德拉（开拔） | 营地·开拔 | 积累 |  | 需 {"flags": ["t_spain"]} |
| `bordeaux` | 波尔多 | 随机槽 | 积累 |  | 池 danube：事件6 补给2 营地1 商贩1 遭遇战2 L7；需 {"flags": ["t_danube"]} |
| `paris_1809` | 巴黎·战争部的仓库 | 商贩 | 积累 |  | 需 {"flags": ["t_danube"]} |
| `chalons` | 沙隆 | 随机槽 | 积累 |  | 池 danube：事件6 补给2 营地1 商贩1 遭遇战2 L7；需 {"flags": ["t_danube"]} |
| `strasbourg_1809` | 斯特拉斯堡驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_danube"]} |
| `augsburg_1809` | 奥格斯堡 | 随机槽 | 积累 |  | 池 danube：事件6 补给2 营地1 商贩1 遭遇战2 L7；需 {"flags": ["t_danube"]} |
| `ratisbon` | 雷根斯堡·皇帝的脚踝 | 事件 | 积累 | 1809-04-23 | 事件 `ev_ratisbon_wound`；需 {"flags": ["t_danube"]} |
| `passau_1809` | 帕绍驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["t_danube"]} |
| `linz_1809` | 林茨 | 随机槽 | 积累 |  | 池 danube：事件6 补给2 营地1 商贩1 遭遇战2 L7；需 {"flags": ["t_danube"]} |
| `melk_1809` | 梅尔克 | 随机槽 | 积累 |  | 池 danube：事件6 补给2 营地1 商贩1；需 {"flags": ["t_danube"]} |
| `vienna_1809` | 维也纳（开拔） | 营地·开拔 | 积累 | 1809-05-13 | 需 {"flags": ["t_danube"]} |
| `alagon` | 阿拉贡军议 | 事件·军议 | 战役 |  | 事件 `ev_council_saragossa`；需 {"flags": ["t_spain"]} |
| `casetas` | 卡塞塔斯的废磨坊 | 营地 | 战役 |  | 需 {"flags": ["t_spain"]} |
| `saragossa_city` | 萨拉戈萨 | Boss | 战役 | 1809-02-10 | 场景 `saragossa_siege`；saragossa L9；需 {"flags": ["t_spain"]} |
| `ebersdorf` | 埃伯斯多夫军议 | 事件·军议 | 战役 |  | 事件 `ev_council_wagram`；需 {"flags": ["t_danube"]} |
| `aspern` | 阿斯佩恩-埃斯灵 | 精英 | 战役 | 1809-05-21 | aspern L8；需 {"flags": ["t_danube"]}；天时 clear |
| `lobau` | 洛鲍岛营地 | 营地 | 战役 |  | 需 {"flags": ["t_danube"]} |
| `wagram_field` | 瓦格拉姆 | Boss | 战役 | 1809-07-05 | 场景 `wagram_lobau`；wagram L9；需 {"flags": ["t_danube"]}；天时 rain/clear |

连线：bayonne–pamplona 2（需 {"flags": ["t_spain"]}）；pamplona–vitoria 2；vitoria–burgos 2；burgos–aranda 2；aranda–somosierra 1；somosierra–madrid_1808 2；aranda–segovia 2；segovia–madrid_1808 2（过路费 {"gold": 1}）；madrid_1808–toledo 2；madrid_1808–calatayud 4（军需 1）；aranda–soria 2；soria–calatayud 2；soria–tudela 2；calatayud–tudela 2；bayonne–bordeaux 2（需 {"flags": ["t_danube"]}）；bordeaux–paris_1809 4（军需 1）；paris_1809–chalons 2；chalons–strasbourg_1809 3；strasbourg_1809–augsburg_1809 3（军需 1）；augsburg_1809–ratisbon 2；ratisbon–passau_1809 2；augsburg_1809–passau_1809 3（军需 1）；passau_1809–linz_1809 1；linz_1809–melk_1809 2；melk_1809–vienna_1809 2；linz_1809–vienna_1809 4（军需 1）；tudela–alagon 2；alagon–casetas 1；casetas–saragossa_city 1；vienna_1809–ebersdorf 1；ebersdorf–aspern 1；aspern–lobau 1；ebersdorf–lobau 1；lobau–wagram_field 2

对手：游击队（guerrilla_band，路线 vitoria→burgos→aranda→burgos，遭遇 skirmish_terraces L7）

兵站套：camino = pamplona+calatayud

#### russia（16 个节点，days_max 17，驿站印 2，插曲 camp_night）

镜头：`retreat_1812`（{"mustered": true}）、`russia_1812`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `kovno_1812` | 科夫诺·涅曼河浮桥 | 剧情 | 积累 | 1812-06-24 | 场景 `russia_niemen` |
| `vilna_1812` | 维尔纳仓库 | 补给 | 积累 | 1812-06-28 |  |
| `minsk` | 明斯克 | 随机槽 | 积累 |  | 池 russia：事件6 补给2 营地1 商贩1 遭遇战2 L8 |
| `glubokoye` | 格卢博科耶 | 随机槽 | 积累 |  | 池 russia：事件6 补给2 营地1 商贩1 遭遇战2 L8 |
| `polotsk` | 波洛茨克 | 随机槽 | 积累 |  | 池 russia：事件6 补给2 营地1 商贩1 |
| `vitebsk` | 维捷布斯克驿站 | 补给·驿站 | 积累 |  |  |
| `smolensk` | 斯摩棱斯克（还在烧） | 事件 | 积累 | 1812-08-18 | 事件 `ev_smolensk_granary` |
| `dorogobuzh` | 多罗戈布日 | 随机槽 | 积累 |  | 池 russia：事件6 补给2 营地1 商贩1 遭遇战2 L8 |
| `vyazma` | 维亚济马驿站 | 补给·驿站 | 积累 |  |  |
| `gzhatsk` | 格扎茨克 | 随机槽 | 积累 |  | 池 russia：事件6 补给2 营地1 商贩1 |
| `borodino_field` | 博罗季诺 | 剧情 | 积累 | 1812-09-07 | 场景 `russia_borodino`；borodino L9 |
| `moscow` | 莫斯科（大火之后） | 营地·开拔 | 积累 | 1812-10-19 |  |
| `maloyaroslavets` | 小雅罗斯拉韦茨军议 | 事件·军议 | 战役 | 1812-10-25 | 事件 `ev_council_retreat` |
| `krasnoi` | 红村 | 精英 | 战役 | 1812-11-17 | krasnoi L9；天时 snow |
| `orsha` | 奥尔沙（埃布莱留下的工具车） | 营地 | 战役 | 1812-11-20 |  |
| `studianka` | 斯图江卡·别列津纳河 | Boss | 战役 | 1812-11-27 | 场景 `russia_berezina`；berezina L10；天时 snow |

连线：kovno_1812–vilna_1812 2；vilna_1812–glubokoye 3（军需 1）；vilna_1812–minsk 3（军需 1）；glubokoye–polotsk 2；glubokoye–vitebsk 3；polotsk–vitebsk 2；minsk–vitebsk 4（军需 2）；vitebsk–smolensk 3（军需 1）；smolensk–dorogobuzh 2；dorogobuzh–vyazma 1；smolensk–vyazma 3（军需 2）；vyazma–gzhatsk 1；gzhatsk–borodino_field 1；vyazma–borodino_field 2（军需 1）；borodino_field–moscow 2；moscow–maloyaroslavets 2；maloyaroslavets–krasnoi 4（军需 2）；krasnoi–orsha 2；maloyaroslavets–orsha 4（军需 3）；orsha–studianka 2（军需 1）

对手：哥萨克（cossacks，路线 dorogobuzh→vyazma→gzhatsk→vyazma，遭遇 skirmish_hamlet L8）；达维多夫的游击队（partisans，路线 polotsk→glubokoye→vilna_1812→minsk→vilna_1812→glubokoye，遭遇 skirmish_mill_ford L8）

兵站套：magazines = vilna_1812+vitebsk+vyazma

#### collapse（20 个节点，days_max 10，驿站印 2，插曲 bond）

镜头：`france_1814`（{"scene_done": "collapse_leipzig"}）、`leipzig_1813`（{"mustered": true}）、`saxony_1813`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `lutzen` | 吕岑 | 剧情 | 积累 | 1813-05-02 | 场景 `collapse_lutzen` |
| `halle` | 哈雷 | 随机槽 | 积累 |  | 池 collapse：事件6 补给2 营地1 商贩1 遭遇战2 L9 |
| `naumburg` | 瑙姆堡 | 随机槽 | 积累 |  | 池 collapse：事件6 补给2 营地1 商贩1 |
| `altenburg` | 阿尔滕堡 | 随机槽 | 积累 |  | 池 collapse：事件6 补给2 营地1 商贩1 遭遇战2 L9 |
| `chemnitz` | 开姆尼茨驿站 | 补给·驿站 | 积累 |  |  |
| `dresden_1813` | 德累斯顿 | 精英 | 积累 | 1813-08-26 | dresden L10；天时 rain |
| `meissen` | 迈森 | 随机槽 | 积累 |  | 池 collapse：事件6 补给2 营地1 商贩1 |
| `bautzen` | 包岑 | 随机槽 | 积累 |  | 池 collapse：事件6 补给2 营地1 商贩1 |
| `gorlitz` | 格尔利茨 | 随机槽 | 积累 |  | 池 collapse：事件6 补给2 营地1 商贩1 遭遇战2 L9 |
| `torgau` | 托尔高要塞的军需库 | 商贩 | 积累 |  |  |
| `wittenberg` | 维滕贝格驿站 | 补给·驿站 | 积累 |  |  |
| `duben` | 迪本（开拔） | 营地·开拔 | 积累 | 1813-10-10 |  |
| `eilenburg` | 艾伦堡军议 | 事件·军议 | 战役 |  | 事件 `ev_council_leipzig` |
| `wachau` | 瓦豪的营火 | 营地 | 战役 |  |  |
| `leipzig_field` | 莱比锡·普罗布斯泰达 | Boss | 战役 | 1813-10-18 | 场景 `collapse_leipzig`；leipzig L11 |
| `erfurt_1813` | 爱尔福特（收拢残部） | 营地 | 战役 | 1813-10-24 |  |
| `hanau` | 哈瑙 | 精英 | 战役 | 1813-10-30 | hanau L10 |
| `mainz_1813` | 美因茨（伤寒营） | 营地 | 战役 |  |  |
| `montmirail` | 蒙米赖·六日战役 | 事件 | 战役 | 1814-02-11 | 事件 `ev_six_days` |
| `fontainebleau_1814` | 枫丹白露·白马庭院 | 剧情 | 战役 | 1814-04-20 | 场景 `collapse_fontainebleau` |

连线：lutzen–naumburg 1；lutzen–altenburg 1；lutzen–halle 1；halle–wittenberg 3；naumburg–altenburg 2；altenburg–chemnitz 1；chemnitz–dresden_1813 2；altenburg–torgau 3；dresden_1813–meissen 1；meissen–torgau 2；dresden_1813–bautzen 2；bautzen–gorlitz 1；gorlitz–torgau 4（军需 1）；chemnitz–meissen 2；torgau–wittenberg 1；torgau–duben 1；wittenberg–duben 1；duben–eilenburg 1；eilenburg–wachau 2；wachau–leipzig_field 1；leipzig_field–erfurt_1813 3（军需 1）；erfurt_1813–hanau 3；hanau–mainz_1813 1；erfurt_1813–mainz_1813 4（军需 2）；mainz_1813–montmirail 4；montmirail–fontainebleau_1814 2

对手：哥萨克（cossacks_1813，路线 bautzen→gorlitz→bautzen→dresden_1813，遭遇 skirmish_hamlet L9）

兵站套：elbe = chemnitz+wittenberg

#### elba（16 个节点，days_max 9，驿站印 2，插曲 minigame:weigh）

镜头：`portoferraio_1815`（{"mustered": true}）、`elba_island`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `portoferraio` | 费拉约港 | 剧情 | 积累 | 1814-05-04 | 场景 `elba_arrival` |
| `san_martino` | 圣马蒂诺别墅（开拔） | 营地·开拔 | 积累 |  |  |
| `procchio` | 普罗基奥的盐仓（密探联络） | 补给·密探 | 积累 |  |  |
| `marciana` | 马尔恰纳 | 随机槽 | 积累 |  | 池 elba：事件6 营地2 商贩1 |
| `marina_di_campo` | 坎波海滨 | 随机槽 | 积累 |  | 池 elba：事件6 补给2 营地1 商贩1 |
| `lacona` | 拉科纳 | 随机槽 | 积累 |  | 池 elba：事件6 补给2 营地1 商贩1 遭遇战2 L10 |
| `capoliveri` | 卡波利韦里 | 随机槽 | 积累 |  | 池 elba：事件6 补给2 营地1 |
| `porto_longone` | 隆戈内港要塞 | 补给·驿站 | 积累 |  |  |
| `rio_marina` | 里奥铁矿 | 补给·工程 | 积累 |  |  |
| `volterraio` | 沃尔泰拉约古堡（信号塔） | 补给·驿站 | 积累 |  |  |
| `cavo` | 卡沃 | 随机槽 | 积累 |  | 池 elba：事件6 补给2 营地1 商贩1 遭遇战2 L10 |
| `forte_falcone` | 法尔科内堡军议 | 事件·军议 | 战役 |  | 事件 `ev_council_elba` |
| `molo` | 码头·法老号靠岸 | 事件 | 战役 | 1815-02-20 | 事件 `ev_pharaon_elba` |
| `forte_stella` | 星堡的夜 | 营地 | 战役 |  |  |
| `darsena` | 码头仓库 | Boss | 战役 | 1815-02-24 | 场景 `elba_night`；elba_cove L12 |
| `mulini` | 穆利尼宫 | 分岔 | 战役 | 1815-02-25 | 场景 `elba_1815` |

连线：portoferraio–volterraio 1；portoferraio–procchio 2；procchio–san_martino 1；procchio–marciana 2（军需 1）；procchio–marina_di_campo 1；marciana–marina_di_campo 2；marina_di_campo–lacona 1；lacona–san_martino 1；lacona–capoliveri 1；capoliveri–porto_longone 1；porto_longone–rio_marina 2；volterraio–rio_marina 1；volterraio–porto_longone 2；rio_marina–cavo 1；volterraio–cavo 2；san_martino–forte_falcone 1；forte_falcone–forte_stella 1；forte_falcone–molo 1；molo–forte_stella 1；forte_stella–darsena 1；darsena–mulini 1

对手：坎贝尔上校的快艇（campbell_cutter，路线 porto_longone→rio_marina→cavo→volterraio→porto_longone）

### 鹰飞 `maps/europe_late.json`

#### hundred_days（27 个节点，days_max 16，驿站印 2，插曲 audience）

镜头：`belgium_1815`（{"mustered": true}）、`france_1815`（{"scene_done": "k_laffrey"}）、`route_napoleon`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `golfe_juan` | 儒安湾 | 剧情 | 积累 | 1815-03-01 | 场景 `k_golfe_juan` |
| `grasse` | 格拉斯 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 |
| `castellane` | 卡斯特拉讷 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 遭遇战2 L12 |
| `digne` | 迪涅驿站 | 补给·驿站 | 积累 |  |  |
| `sisteron` | 锡斯特龙 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 |
| `gap` | 加普 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 遭遇战2 L12 |
| `laffrey` | 拉弗雷·相遇的草地 | 剧情 | 积累 | 1815-03-07 | 场景 `k_laffrey` |
| `grenoble` | 格勒诺布尔兵工厂 | 补给 | 积累 | 1815-03-07 |  |
| `vienne` | 维埃纳 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 遭遇战2 L12 |
| `lyon_1815` | 里昂（丝绸商与新兵） | 商贩 | 积累 | 1815-03-10 |  |
| `macon` | 马孔 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 遭遇战2 L12 |
| `chalon` | 沙隆驿站 | 补给·驿站 | 积累 |  |  |
| `auxerre` | 欧塞尔·内伊的铁笼 | 事件 | 积累 | 1815-03-17 | 事件 `ev_ney_auxerre` |
| `fontainebleau_1815` | 枫丹白露 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 遭遇战2 L12 |
| `paris_1815` | 巴黎·杜伊勒里宫 | 剧情 | 积累 | 1815-03-20 | 场景 `k_tuileries` |
| `war_ministry` | 战争部·档案室 | 事件 | 积累 |  | 事件 `ev_morrel_petition`；需 {"scene_done": "k_tuileries"} |
| `soissons` | 苏瓦松 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 |
| `laon` | 拉昂 | 随机槽 | 积累 |  | 池 hundred_days：事件5 补给2 营地2 商贩1 遭遇战2 L12 |
| `avesnes` | 阿韦讷驿站 | 补给·驿站 | 积累 |  |  |
| `beaumont` | 博蒙（北方军团集结） | 营地·开拔 | 积累 | 1815-06-14 |  |
| `charleroi` | 沙勒罗瓦桥 | 剧情 | 战役 | 1815-06-15 | 场景 `k_charleroi`；charleroi_bridge L12 |
| `fleurus` | 弗勒吕斯军议 | 事件·军议 | 战役 | 1815-06-16 | 事件 `ev_council_fleurus` |
| `ligny` | 利尼 | 精英 | 战役 | 1815-06-16 | ligny L13；天时 clear/rain |
| `quatre_bras` | 四臂村 | 精英 | 战役 | 1815-06-16 | quatre_bras L13；天时 clear |
| `genappe` | 热纳普的雨夜 | 营地 | 战役 | 1815-06-17 |  |
| `waterloo_field` | 滑铁卢·普朗斯努瓦 | Boss | 战役 | 1815-06-18 | 场景 `k_waterloo`；waterloo L14；天时 mud |
| `waterloo_inn` | 滑铁卢村·客栈 | 剧情 | 战役 | 1815-06-18 | 场景 `k_waterloo_night` |

连线：golfe_juan–grasse 1；grasse–castellane 2；golfe_juan–castellane 2（军需 1）；castellane–digne 1；digne–sisteron 1；sisteron–gap 1；digne–gap 2（军需 1）；gap–laffrey 2；sisteron–laffrey 3（军需 1）；laffrey–grenoble 1；grenoble–vienne 2；vienne–lyon_1815 1；grenoble–lyon_1815 3（军需 1）；lyon_1815–macon 2；macon–chalon 1；chalon–auxerre 3；lyon_1815–auxerre 4（军需 2）；auxerre–fontainebleau_1815 2；fontainebleau_1815–paris_1815 1；auxerre–paris_1815 3（军需 1）；paris_1815–war_ministry 1；paris_1815–soissons 2；war_ministry–soissons 2；soissons–laon 1；laon–avesnes 2；avesnes–beaumont 1；soissons–avesnes 3（军需 1）；beaumont–charleroi 1；charleroi–fleurus 1；fleurus–ligny 1；fleurus–quatre_bras 1；ligny–genappe 2；quatre_bras–genappe 1；fleurus–genappe 2；genappe–waterloo_field 1；waterloo_field–waterloo_inn 1

对手：王党志愿军（royalist_volunteers，路线 macon→chalon→macon→lyon_1815，遭遇 skirmish_brabant_farm L12）；对手承包商（白鹳商行）（rival_contractor，路线 laon→avesnes→laon→soissons）

兵站套：route_napoleon = digne+grenoble

#### rhine（15 个节点，days_max 12，驿站印 2，插曲 camp_night）

镜头：`lauter_1815`（{"mustered": true}）、`lowlands_rhine`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `brussels_1815` | 布鲁塞尔 | 剧情 | 积累 | 1815-06-20 | 场景 `k_brussels`；brussels L15 |
| `antwerp_1815` | 安特卫普 | 随机槽 | 积累 |  | 池 rhine：事件5 补给2 营地2 商贩1 |
| `namur` | 那慕尔驿站 | 补给·驿站 | 积累 |  |  |
| `liege` | 列日 | 随机槽 | 积累 |  | 池 rhine：事件5 补给2 营地2 商贩1 遭遇战2 L14 |
| `maastricht` | 马斯特里赫特 | 随机槽 | 积累 |  | 池 rhine：事件5 补给2 营地2 商贩1 |
| `luxembourg` | 卢森堡要塞 | 补给·驿站 | 积累 |  |  |
| `thionville` | 蒂永维尔 | 随机槽 | 积累 |  | 池 rhine：事件5 补给2 营地2 商贩1 遭遇战2 L14 |
| `metz_1815` | 梅斯·会议厅 | 剧情 | 积累 | 1815-07-20 | 场景 `k_ultimatum` |
| `verdun` | 凡尔登 | 随机槽 | 积累 |  | 池 rhine：事件5 补给2 营地2 商贩1 遭遇战2 L14 |
| `nancy` | 南锡·维也纳来的信 | 事件 | 积累 |  | 事件 `ev_marie_louise_letter` |
| `saverne` | 萨韦尔讷山口的骡马市 | 商贩 | 积累 |  |  |
| `strasbourg_1815` | 斯特拉斯堡（开拔） | 营地·开拔 | 积累 |  |  |
| `haguenau` | 阿格诺军议 | 事件·军议 | 战役 |  | 事件 `ev_council_rhine` |
| `seltz` | 塞尔茨渡口的营火 | 营地 | 战役 |  |  |
| `wissembourg` | 维桑堡防线·劳特河 | Boss | 战役 | 1815-09-02 | 场景 `k_rhine`；rhine_crossing L16；天时 rain/clear |

连线：brussels_1815–antwerp_1815 2；brussels_1815–namur 2；antwerp_1815–maastricht 3；namur–liege 2；liege–maastricht 1；namur–luxembourg 3（军需 1）；liege–luxembourg 3；maastricht–luxembourg 4（军需 1）；luxembourg–thionville 1；thionville–metz_1815 1；luxembourg–metz_1815 2；metz_1815–verdun 2；metz_1815–nancy 2；nancy–saverne 2；metz_1815–saverne 3（军需 1）；saverne–strasbourg_1815 1；strasbourg_1815–haguenau 1；haguenau–seltz 1；seltz–wissembourg 1

对手：普军后卫（prussian_rearguard，路线 liege→namur→liege→maastricht，遭遇 skirmish_brabant_farm L14）

#### vienna（15 个节点，days_max 12，驿站印 2，插曲 bond）

镜头：`vienna_1816`（{"mustered": true}）、`danube_1816`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `munich_1816` | 慕尼黑·宁芬堡宫 | 剧情 | 积累 | 1816-04-10 | 场景 `k_bavaria` |
| `landshut` | 兰茨胡特 | 随机槽 | 积累 |  | 池 vienna：事件5 补给2 营地2 商贩1 |
| `kufstein` | 库夫施泰因（蒂罗尔山口） | 随机槽 | 积累 |  | 池 vienna：事件4 营地1 遭遇战3 L16 |
| `salzburg` | 萨尔茨堡驿站 | 补给·驿站 | 积累 |  |  |
| `passau_1816` | 帕绍驿站 | 补给·驿站 | 积累 |  |  |
| `braunau_1816` | 布劳瑙 | 随机槽 | 积累 |  | 池 vienna：事件5 补给2 营地2 商贩1 遭遇战2 L16 |
| `linz_1816` | 林茨的多瑙河船坞 | 商贩 | 积累 |  |  |
| `wels` | 韦尔斯 | 随机槽 | 积累 |  | 池 vienna：事件5 补给2 营地2 商贩1 |
| `steyr` | 施泰尔 | 随机槽 | 积累 |  | 池 vienna：事件5 补给2 营地2 商贩1 遭遇战2 L16 |
| `melk` | 梅尔克修道院的图书馆 | 事件 | 积累 |  | 事件 `ev_melk_library` |
| `st_polten` | 圣珀尔滕（开拔） | 营地·开拔 | 积累 |  |  |
| `purkersdorf` | 普尔克斯多夫军议 | 事件·军议 | 战役 |  | 事件 `ev_council_vienna` |
| `laxenburg` | 拉克森堡的林苑 | 营地 | 战役 |  |  |
| `vienna_1816` | 维也纳城墙 | Boss | 战役 | 1816-06-12 | 场景 `k_vienna`；vienna_streets L18 |
| `schoenbrunn` | 美泉宫 | 剧情 | 战役 | 1816-06-14 | 场景 `k_schoenbrunn` |

连线：munich_1816–landshut 2；munich_1816–kufstein 2；kufstein–salzburg 2；landshut–passau_1816 2；landshut–braunau_1816 2；braunau_1816–passau_1816 1；braunau_1816–salzburg 2；salzburg–steyr 3（军需 1）；passau_1816–linz_1816 2；linz_1816–wels 1；wels–steyr 1；linz_1816–melk 2；steyr–melk 2；melk–st_polten 1；linz_1816–st_polten 3（军需 1）；st_polten–purkersdorf 2；purkersdorf–laxenburg 2；laxenburg–vienna_1816 1；vienna_1816–schoenbrunn 1

对手：蒂罗尔射手（tyrolean_riflemen，路线 kufstein→salzburg→kufstein，遭遇 skirmish_brabant_farm L16）

#### iberia_channel（26 个节点，days_max 11，驿站印 2，插曲 audience）

镜头：`torres_1817`（{"flags": ["k_iberia"], "mustered": true}）、`kent_1817`（{"flags": ["k_channel"], "mustered": true}）、`iberia_1817`（{"flags": ["k_iberia"]}）、`channel_1817`（{"flags": ["k_channel"]}）、`west_1817`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `boulogne_1817` | 布洛涅·皇帝的木屋 | 剧情 | 积累 | 1817-03-01 | 场景 `k_choice_1817` |
| `bayonne_1817` | 巴约讷驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["k_iberia"]} |
| `vitoria_1817` | 维多利亚 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1；需 {"flags": ["k_iberia"]} |
| `burgos_1817` | 布尔戈斯 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1 遭遇战2 L18；需 {"flags": ["k_iberia"]} |
| `valladolid` | 巴利亚多利德 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1；需 {"flags": ["k_iberia"]} |
| `salamanca` | 萨拉曼卡·阿拉皮莱斯的白骨 | 事件 | 积累 |  | 事件 `ev_arapiles_bones`；需 {"flags": ["k_iberia"]} |
| `ciudad_rodrigo` | 罗德里戈城 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1 遭遇战2 L18；需 {"flags": ["k_iberia"]} |
| `guarda` | 瓜达 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1；需 {"flags": ["k_iberia"]} |
| `coimbra` | 科英布拉驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["k_iberia"]} |
| `santarem` | 圣塔伦（开拔） | 营地·开拔 | 积累 |  | 需 {"flags": ["k_iberia"]} |
| `etaples` | 埃塔普勒的平底船 | 补给·驿站 | 积累 |  | 需 {"flags": ["k_channel"]} |
| `abbeville` | 阿布维尔 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1 遭遇战2 L18；需 {"flags": ["k_channel"]} |
| `saint_omer` | 圣奥梅尔驿站 | 补给·驿站 | 积累 |  | 需 {"flags": ["k_channel"]} |
| `cassel` | 卡塞勒 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1 遭遇战2 L18；需 {"flags": ["k_channel"]} |
| `lille` | 里尔 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1；需 {"flags": ["k_channel"]} |
| `dunkirk` | 敦刻尔克·美国人的潜水船 | 事件 | 积累 |  | 事件 `ev_fulton_nautilus`；需 {"flags": ["k_channel"]} |
| `ostend` | 奥斯坦德 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1；需 {"flags": ["k_channel"]} |
| `bruges` | 布鲁日 | 随机槽 | 积累 |  | 池 iberia_channel：事件5 补给2 营地2 商贩1 遭遇战2 L18；需 {"flags": ["k_channel"]} |
| `antwerp_1817` | 安特卫普造船厂 | 商贩 | 积累 |  | 需 {"flags": ["k_channel"]} |
| `calais` | 加来（开拔） | 营地·开拔 | 积累 |  | 需 {"flags": ["k_channel"]} |
| `alenquer` | 阿伦克尔军议 | 事件·军议 | 战役 |  | 事件 `ev_council_torres`；需 {"flags": ["k_iberia"]} |
| `sobral` | 索布拉尔的雨夜 | 营地 | 战役 |  | 需 {"flags": ["k_iberia"]} |
| `torres_vedras` | 托雷斯韦德拉什防线 | Boss | 战役 | 1817-10-14 | 场景 `k_torres_vedras`；iberia_return L20；需 {"flags": ["k_iberia"]} |
| `gris_nez` | 灰鼻角军议 | 事件·军议 | 战役 |  | 事件 `ev_council_channel`；需 {"flags": ["k_channel"]} |
| `hythe` | 海斯海滩的夜 | 营地 | 战役 |  | 需 {"flags": ["k_channel"]} |
| `dover` | 多佛尔的白崖 | Boss | 战役 | 1817-08-19 | 场景 `k_dover`；channel_landing L20；需 {"flags": ["k_channel"]} |

连线：boulogne_1817–bayonne_1817 4（军需 1，需 {"flags": ["k_iberia"]}）；bayonne_1817–vitoria_1817 2；vitoria_1817–burgos_1817 2；burgos_1817–valladolid 2；valladolid–salamanca 2；salamanca–ciudad_rodrigo 2；ciudad_rodrigo–guarda 2；guarda–coimbra 2（军需 1）；salamanca–coimbra 4（军需 2）；coimbra–santarem 2；boulogne_1817–etaples 1（需 {"flags": ["k_channel"]}）；etaples–abbeville 2；boulogne_1817–saint_omer 2（需 {"flags": ["k_channel"]}）；abbeville–saint_omer 3；saint_omer–cassel 1；cassel–lille 2；cassel–dunkirk 2；lille–bruges 2；dunkirk–ostend 2；ostend–bruges 1；bruges–antwerp_1817 2；dunkirk–calais 2；saint_omer–calais 2；etaples–calais 3（军需 1）；santarem–alenquer 2；alenquer–sobral 1；sobral–torres_vedras 1；calais–gris_nez 1；gris_nez–hythe 航 1 天；hythe–dover 1

#### niemen（14 个节点，days_max 12，驿站印 2，插曲 minigame:decode）

镜头：`niemen_1818`（{"mustered": true}）、`poland_1818`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `warsaw_1818` | 华沙·王宫 | 剧情 | 积累 | 1818-05-03 | 场景 `k_warsaw` |
| `posen_1818` | 波森驿站 | 补给·驿站 | 积累 |  |  |
| `plock` | 普沃茨克 | 随机槽 | 积累 |  | 池 niemen：事件5 补给2 营地2 商贩1 遭遇战2 L20 |
| `thorn` | 托伦 | 随机槽 | 积累 |  | 池 niemen：事件5 补给2 营地2 商贩1 |
| `danzig` | 但泽的粮商 | 商贩 | 积累 |  |  |
| `konigsberg` | 柯尼斯堡 | 随机槽 | 积累 |  | 池 niemen：事件5 补给2 营地2 商贩1 遭遇战2 L20 |
| `tilsit_1818` | 提尔西特·河心的木筏 | 事件 | 积累 |  | 事件 `ev_tilsit_raft` |
| `ostrolenka` | 奥斯特罗文卡 | 随机槽 | 积累 |  | 池 niemen：事件5 补给2 营地2 商贩1 |
| `bialystok` | 比亚韦斯托克 | 随机槽 | 积累 |  | 池 niemen：事件5 补给2 营地2 商贩1 遭遇战2 L20 |
| `grodno` | 格罗德诺仓库 | 补给·驿站 | 积累 |  |  |
| `vilkaviskis` | 维尔卡维什基斯（开拔） | 营地·开拔 | 积累 |  |  |
| `mariampol` | 马里扬波尔军议 | 事件·军议 | 战役 |  | 事件 `ev_council_niemen` |
| `pilviskiai` | 皮尔维什基艾的营火 | 营地 | 战役 |  |  |
| `kovno_1818` | 科夫诺·涅曼河 | Boss | 战役 | 1818-06-24 | 场景 `k_niemen`；niemen L22 |

连线：warsaw_1818–plock 2；plock–posen_1818 3；warsaw_1818–ostrolenka 2；plock–thorn 2；posen_1818–thorn 2；thorn–danzig 3；danzig–konigsberg 3（军需 1）；konigsberg–tilsit_1818 2；tilsit_1818–vilkaviskis 2；ostrolenka–bialystok 2；bialystok–grodno 1；grodno–vilkaviskis 3（军需 1）；ostrolenka–thorn 3；konigsberg–grodno 4（军需 1）；vilkaviskis–mariampol 1；mariampol–pilviskiai 1；pilviskiai–kovno_1818 2

对手：普拉托夫的哥萨克（cossacks_1818，路线 bialystok→grodno→bialystok→ostrolenka，遭遇 skirmish_brabant_farm L20）

兵站套：vistula = posen_1818+grodno

#### last_coalition（15 个节点，days_max 12，驿站印 2，插曲 camp_night）

镜头：`leipzig_1819`（{"mustered": true}）、`germany_1819`（默认）

| 节点 | 地名 | 类型 | 阶段 | 日期 | 说明 |
|---|---|---|---|---|---|
| `paris_1819` | 巴黎·杜伊勒里宫 | 剧情 | 积累 | 1819-08-15 | 场景 `k_paris_1819` |
| `reims_1819` | 兰斯 | 随机槽 | 积累 |  | 池 last_coalition：事件5 补给2 营地2 商贩1 |
| `chalons_1819` | 沙隆 | 随机槽 | 积累 |  | 池 last_coalition：事件5 补给2 营地2 商贩1 遭遇战2 L22 |
| `metz_1819` | 梅斯驿站 | 补给·驿站 | 积累 |  |  |
| `kaiserslautern` | 凯泽斯劳滕 | 随机槽 | 积累 |  | 池 last_coalition：事件5 补给2 营地2 商贩1 遭遇战2 L22 |
| `mainz_1819` | 美因茨的军火库 | 商贩 | 积累 |  |  |
| `frankfurt` | 法兰克福 | 随机槽 | 积累 |  | 池 last_coalition：事件5 补给2 营地2 商贩1 遭遇战2 L22 |
| `fulda` | 富尔达 | 随机槽 | 积累 |  | 池 last_coalition：事件5 补给2 营地2 商贩1 |
| `erfurt` | 爱尔福特驿站 | 补给·驿站 | 积累 |  |  |
| `weimar` | 魏玛·歌德的花园小屋 | 事件 | 积累 |  | 事件 `ev_goethe_tea` |
| `naumburg_1819` | 瑙姆堡（开拔） | 营地·开拔 | 积累 |  |  |
| `lutzen_1819` | 吕岑军议 | 事件·军议 | 战役 |  | 事件 `ev_council_final` |
| `markkleeberg` | 马克克莱贝格的最后一夜 | 营地 | 战役 |  |  |
| `leipzig_1819` | 莱比锡·第二次民族之战 | Boss | 战役 | 1819-10-18 | 场景 `k_leipzig_1819`；coalition_final L24 |
| `probstheida` | 普罗布斯泰达·皇帝的帐篷 | 剧情 | 战役 | 1819-10-19 | 场景 `k_final` |

连线：paris_1819–reims_1819 3；paris_1819–chalons_1819 4（军需 1）；reims_1819–chalons_1819 1；reims_1819–metz_1819 3；chalons_1819–metz_1819 3；metz_1819–kaiserslautern 2；kaiserslautern–mainz_1819 2；metz_1819–mainz_1819 4（军需 1）；mainz_1819–frankfurt 1；frankfurt–fulda 2；mainz_1819–fulda 3（军需 1）；fulda–erfurt 2；erfurt–weimar 1；weimar–naumburg_1819 1；erfurt–naumburg_1819 2；naumburg_1819–lutzen_1819 1；lutzen_1819–markkleeberg 1；markkleeberg–leipzig_1819 1；leipzig_1819–probstheida 1

对手：英军骠骑兵（british_hussars，路线 fulda→frankfurt→fulda→erfurt，遭遇 skirmish_brabant_farm L22）

<!-- TABLES:END -->
