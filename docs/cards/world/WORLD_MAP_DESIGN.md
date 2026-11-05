# 《鹰旗军需官》实现规格：世界地图、等级难度、复杂地形、主干加三条分支（WORLD_MAP_DESIGN）

> 2026-11-02，标签 synth。本稿把 `wm/geo`、`wm/arch/ARCH.md`、`wm/conquest`、`wm/ocean`、`wm/cristo` 五份输入合成一份实现规格，并对照仓库代码核过（§2）。
> **基线**：`/home/user/dehoudang` 的 HEAD `0bf260eb`。ARCH 写的是 `31c0b3e5`，两者之间内核、战斗规则和 `ocean_pawn.json` 一个字节没变（只改了界面、`ocean_battle.json` 和 `battle_ui.json` 的说明文字），所以 golden 直接在 `0bf260eb` 上录。
> **效力**：本稿是 A/B/C 三个实现包之间唯一的契约。本稿写到的地方以本稿为准；本稿没提的细节，按 ARCH.md 同名小节执行（§1 列出了本稿推翻 ARCH 的每一处）。
> **范围**：只动拿破仑线（远洋战役那套内核和界面）。旧版 1938（`DEHOUDANG_CAMPAIGN=legacy`、`user://cards/` 下的旧存档、`scripts/cards/legacy|loop|rules` 的旧规则、`project.godot` 的工程名）一行不动。
> **配套数据**（本目录 `data/`，脚本在 `tools/`，都可重跑）：`enemies_final.json`（111 种敌军定稿）、`levels_final.json`（四段各章等级与 Boss 战力目标，脚本自检 0 错）、`enemies_table.md`、`companions_table.md`。

---

## 0 结论速览

1. **对玩家来说，这是另一款游戏**。工作名《鹰旗军需官》。主角埃德蒙·德·维尔福是帝国军需官兼司库，不是当铺掌柜。所有玩家看得见的当铺字眼、当铺美术和天平纹章都换掉，机制和 id 不动；19 个词的防回潮测试必须 0 命中（§12）。
2. **一局的形状**：先走主干「鹰旗」（土伦 1793 → 厄尔巴 1815-02，8 章），在厄尔巴的 `elba_1815` 分成三条路：
   - 「鹰飞」：继续征服，打赢滑铁卢；
   - 「远洋」：海底两万里，流亡 → 圣赫勒拿 → 新厄尔巴 → 鹦鹉螺号；
   - 「伊夫堡」：基督山伯爵，唐泰斯、伊夫堡、法利亚、宝藏、巴黎复仇。
   远洋是保底分支，永远开放；另外两条由主干里的表现决定（§4）。
3. **每一段都在世界地图上玩**：主干和鹰飞用 `europe`，远洋用 `world`，伊夫堡用 `med`，再加 9 张局部画布图（土伦、厄尔巴、费拉约港、比斯开、圣赫勒拿、新厄尔巴、马赛、伊夫堡、巴黎）。底图用的是 Natural Earth 矢量，在代码里画；局部图要画师出图，出图之前用代码画占位。一章就是一张图，分积累段和战役段（§5、§7）。
4. **内核不重写**：`ocean_campaign.gd` 就地泛化成「书 → 段 → 章 → 场」，`campaign.*` 的命令名、查询键和远洋的全部 id 都冻结。单段书 `ocean_pawn` 留着做回归，每一步的 `hash_v1` 都要等于 golden（§6.1）。
5. **难度用全局等级 L1–24**：主干 Boss 依次是 L1/3/5/7/9/10/11/12。分支 Boss 分别是：
   - 鹰飞 L14/16/18/20/22/24；
   - 远洋 L13/16/20/24；
   - 伊夫堡 L14/16/18/21/24。
   所有等级都写绝对值。验收看三样：模拟胜率单调、推荐战力相邻章 ≥ ×1.12、自动打法打得过但不白给（§8）。
6. **复杂地形**：在现有 11 种之上新增 28 种，一共 40 种（含工兵筑的胸墙），全部表驱动。另加视线、顶层、黑暗、洞穴、事件改地形、击杀开门这几条规则，8 种天时，战场最大 12×7（§9）。
7. **敌军 111 种**：7 种现有，55 种出自 ARCH，49 种是三个内容包新增的。三包里同 id 的数值全部一致，没有冲突。新行为只靠 15 个标签表达（§10）。
8. **伙伴 28 人**，一张总表。跨段同 id 同数值，一条命；还是用一套羁绊 `napoleon`（§11）。
9. **第一卷（本轮实现）**：
   - 主干 8 章全程可玩，第二到第四幕各开一个战区；
   - 远洋完整，14 场、4 张图、5 个结局；
   - 鹰飞第一章「百日」打到滑铁卢之夜，收在卷终（3 种，按抉择分）；
   - 伊夫堡第一、二章打到逃出伊夫堡，收在卷终（2 种）；
   - 未开放的章在地图上画成预告节点。
   第二卷只需要把书里的 `volume` 改成 2，再补模板和后几章的文字（§13）。
10. **三个包并行**：A 管引擎和地图，B 管战斗和 3D 战场，C 管内容。先合 A0（抽文字、录 golden），再按 B1 → A1 → C1 → A2 → B2 → C2 → C3 的顺序合并（§15）。

---

## 1 冲突裁决（输入之间、输入与代码之间）

每条格式：分歧 → **裁决** → 理由。

| # | 分歧 | 裁决 | 理由 |
|---|---|---|---|
| C1 | ARCH §1.4 写「分支等级 = 段内等级 + offset」，示例里却写 `prologue: level 13`；三个内容包都按绝对值写 | **所有 `level` 一律是绝对 L**（场景战斗、地图节点、随机槽、对手遭遇、模板池）。`level_offset` 只用在一处：没写 level、还按 `scene_map` 的幕推算的旧场景，L = 2a−1 + offset | 三包一致，校验器最好写 |
| C2 | ARCH 要求「分支第一场 ≥ 主干最后一场 + 1」，又要求「同章 battle ≤ Boss−2」。主干最后是 L12，鹰飞第一章 Boss 是 L14，遭遇战无解 | 改成四条（§8.2）：① 按游玩顺序 Boss 严格递增；② 同章精英 ≤ Boss−1，遭遇和随机仗 ≤ Boss−2；③ **分支段任何一场仗都不低于主干最终 Boss（L12）**；④ 相邻两章 Boss 推荐战力 ≥ ×1.12 | 鹰飞、伊夫堡第一章（遭遇 12 / 精英 13 / Boss 14）和远洋序曲（只有 Boss 13）都成立 |
| C3 | 地图视图：ARCH 写 europe −11…44/28…61、world equirect −180…60、med −2…17/36…50；geo 实际交付的是 europe 墨卡托 −12…56、world 米勒全球、med 墨卡托 −6…30 | **以 geo 交付的底图为准**。视图写 `{"proj":"mercator|miller|canvas","base":"europe|world|med","bg":…}`，投影参数从底图的 `view` 读，地图文件里不再写经纬度范围 | 锡兰、阿拉伯隧道在东经 30–80°；geo 已经做完 |
| C4 | 底图路径：conquest 和 cristo 写全路径，ocean 写 id | **写 id**，解析到 `res://data/campaigns/napoleon/maps/geo/<id>.json`（由 A 从 `wm/geo` 拷入，只给界面用，不受整数规则约束） | 改两包只是字符串替换 |
| C5 | muster：ARCH 示例写 `phase:"campaign"`（开拔前就被锁住）；ocean 改成积累段并加 `requires scene_done`；conquest 和 cristo 都没加门槛（会锁死：提前开拔，积累段的锚点就再也到不了） | muster 一律是**积累段**节点。`campaign.map_muster` 由内核把关：**当前场景的锚点必须已在战役段**（等于积累段的锚点全部走完），而且驿站印够数。数据里写不写 `requires` 都无所谓。到 `days_max+4` 的强制开拔也只在积累段锚点走完时生效，否则只累计拖延惩罚 | 规则放进内核，三包数据都不用改，也不可能锁死 |
| C6 | 军议的 Boss 修正：主干和伊夫堡用 `prep_turn`，远洋用 `turns`；敌军心修正 −2、−3、−4 都有 | `boss_mod = {cp_bonus:0..4, enemy_morale:-4..0, prep_turn:0..1}`。远洋的 `turns` 改名为 `prep_turn`（含义是第一波晚一回合到，回合上限 +1） | 一个字段，三种效果 |
| C7 | 幕间插曲三套写法：conquest 用 `rogue.trust{pick|pair}`、`chapters`；ocean 用 `questions`、`offer`、`pick_companions`；cristo 用 `bond_pick`、`minigame`、`chapter` | 定稿见 §6.5：audience 用 `questions`（1–5 题，每题二选一）；camp_night 用 `offer:n`；bond 用抉择上的 `rogue.trust`；minigame 写成事件里的一项查验（`appraisals[].kind`）；插曲只在 `chapters:[…]` 列出的章播 | 复用现有的查验小游戏和 rogue 结算 |
| C8 | 唐泰斯的时间线：conquest 以为远洋里的唐泰斯 1829 年才越狱，所以放了他就关掉「随驾流放」。仓库里的 `ocean_pawn.json` 写着唐泰斯 1819 年已经有基督山资金，1821 年亲自登岛 | **远洋的前提：百日王朝里，主角签的释放令放出了唐泰斯和法利亚**（采用 ocean 稿）。「随驾流放」的条件改成 `not_flags:["k_petition_returned"]`：只有把请愿书退回给杰拉尔的那一局不提供。放过唐泰斯的那一局恰好与远洋前提一致；没见过请愿书的，由马尔梅松牌的回叙补上 | 与现有远洋数据一致；伊夫堡分支照原著走十四年 |
| C9 | 杰拉尔的人物 id：conquest 写 `gerard_villefort`，cristo 写 `gerard` | **`gerard`**，conquest 改 | 他是伊夫堡分支的主角级人物 |
| C10 | 莫雷尔：人物表里是 `morrel`（远洋称「船长」），伙伴表里是 `morel`；cristo 称他船东 | 两个 id 都冻结，指同一个人：老莫雷尔，法老号的**船东**。远洋人物 `role` 里的「船长」由 C 改成「船东」（只改字） | 远洋 id 冻结；原著里他就是船东 |
| C11 | `vampa` 既是敌军 id（亚壁古道的 Boss），又是伙伴 id（打退以后可以招） | 两个都保留。它们在不同的命名空间（`ENEMIES` 和伙伴表），美术按约定加前缀：`unit/enemy_vampa`、`unit/vampa` | 约定本来就是这样，运行时不会撞 |
| C12 | 失败结局的文字：trunk 和 conquest 写在 `endings`（同 id 在两段重复），cristo 写在 `rules.failure_text` | 一律写在本段的 `endings` 里，id 用 `bankruptcy/loss/blockade/exile`。**这四个 id 允许跨段重复**，其余结局 id 必须全书唯一。cristo 的 `failure_text` 并入 `endings` | 内核按「本段 endings」找文字 |
| C13 | 远洋的事件、指标名、场景战斗：ARCH 让它们写进段定义，但 `ocean_pawn.json` 只能改字 | `book.segments.<段>` 允许覆盖四项：`gauges`、`events`（文件路径）、`scene_battles`、`demand_nodes`。远洋这四项都写在书里，事件放在 `napoleon/ocean_events.json` | 单段书的数据不受影响 |
| C14 | 一个抉择招多人：conquest 用 `rogue.recruit:[…]`；地图招募：ocean 写 `recruit:<id>`，conquest 和 cristo 写通用的 `recruit:companion` | `rogue.recruit` 可以是字符串，也可以是数组。地图动作**只认显式的 `recruit:<id>`**；`recruit:companion` 在合并时由 C 的脚本按伙伴表的招募点展开 | 校验器能双向核对 |
| C15 | 天时：conquest 写数组，ocean 和 cristo 写字符串 | 模板和节点的 `weather` 一律是数组，字符串在合并时转换 | 一种写法 |
| C16 | 立绘变体：conquest 写 `variants:[…]`，cristo 写 `variant_of + variant`，没有 id | 变体就是一个**独立的 chara id**：`<人>_<变体>`，例如 `villefort_1793`、`dantes_prisoner`。演出表每场可以写 `art:{人物:立绘id}` 覆盖 | `hd_art` 不用加变体维度 |
| C17 | 名羁绊（成对，conquest 5 对、cristo 6 对）、留守效果（`keep`）、隐患离队（缪拉、鲁斯塔姆） | **第一卷都只作数据，不进内核，界面也不显示**；第二卷再实现（§13.3） | 现有的名额、宿命和一条命已经撑得起「派谁上」的戏 |
| C18 | cristo 的三种新命令 `escape/extract/protect` | 第一卷不做。模板的 `order` 用它们各自的退路（`hold/no_leak`），原提案搬进 `order_next` 键留到第二卷（校验器忽略这个键） | 内核现在只有 hold 和 no_leak |
| C19 | cristo 羁绊 `bandits`（赎金不扣金币）和 `marseille_folk` 三档（街巷开场军令点 +1）用了内核没有的效果 | 删掉 `bandits`，万帕的阵营标签只留 `smugglers`；`marseille_folk` 只留 2 档（camp_family 本来就只有 2 档） | 羁绊只能用 `BOND_EFFECTS` 里现成的九种效果 |
| C20 | 重复的地图节点功能：conquest 和 cristo 有 `muster` 动作，ocean 用 role | `role:muster` 的节点自动有「开拔」，`actions` 里写不写 `muster` 都可以 | — |
| C21 | 主干的第二到第四幕各有两个战区，可 B 第一卷画不完六张 Boss 图 | 第一卷每幕只开一个战区：东方（阿卡）、奥斯特里茨、西班牙（萨拉戈萨）。另一边的调令抉择挂 `requires:{volume:2}`，灰显「第二卷开放」 | 这三个战区地形最有代表性（沙漠加墙、冰裂、街巷），还能接上尼摩的伏笔 |
| C22 | ARCH §3.3 的尺寸分档（比如 L1–6 的 Boss 用 9×5），conquest 的里沃利在 L3 就是 10×6 | 尺寸分档只给提醒；硬限制是 5×3 到 12×7，名额由 scale 决定 | 内容需要大图，平衡靠推荐战力和扫描 |
| C23 | 防回潮词表：ARCH 14 个词，ocean 20 个（多了 账房、估值） | 定稿 19 个：ARCH 的 14 个，加上 当物、赎当、押当、典押、账房先生。「账房」和「估值」本身不禁：莫雷尔商行的账房是原著的词 | 不误伤原著用词 |
| C24 | 远洋的四场不打仗（scene01/03/07/10）要内核认「空模板」 | 采纳：`scene_battles[s] = {"template": ""}` 表示这一场在本书里没有仗 | 防止「读剧情 → 打一仗」的单调交替，约 3 行代码 |
| C25 | 地图上的动作次数：ARCH 说「每场一次、每天一次照旧」，可地图上有十几个市镇节点 | **内核的次数限制不变**：`visit/trade/build/explore` 仍是每场一次，`activity` 和 `schedule` 照旧。节点只决定「在哪儿办」。节点自己的收益来自 `pass`、兵站和事件 | 经济不会因为节点多而翻倍 |
| C26 | 营令三色旗的叫法：ARCH 是「照常行军 / 征发 / 闭营清点」，ocean 是「照常补给 / 征发军需 / 熄灯清点」 | 全书统一：白旗「照常行军」、红旗「就地征发」、黑旗「闭营清点」。地图模式下各色旗有地图效果（§7.4） | 在内核里红旗本来只有代价，没有好处 |
| C27 | 伙伴的宿命：conquest 写 `battle.fated{templates}`，cristo 写 `fated:"模板"`，ocean 写 `fated:{段:场景}`，现有的写法是 `fated_scene` | 定稿 `fated: [{"seg":…, "scene"|"template":…}]`。单段书照旧读 `ocean_battle.json` 的 `fated_scene` | §11.2 |
| C28 | 伊夫堡第二章唐泰斯和法利亚还在牢里，不能上阵 | 采纳 `available_from:{seg, template, turn}`：名册里能选他们，战斗里要到第 N 回合才能部署（B 在 roster 条目上加 `from_turn`） | 伊夫堡之夜是本卷高潮 |
| C29 | 跨段物品：`elba_watch` 和 `faria_half` 在四份段定义里各写一遍，描述不同 | 允许同 id 出现在几段里，但 `name` 必须一致（校验器检查）；描述可以按段写。`emperor_letter` 由 `carry_the_letter` 抉择发出，并加进 `book.carry.items` | — |
| C30 | 旗标前缀：分岔抉择在主干场景里写下 `k_marched / o_followed / m_letter_carried` | 允许，例外只有一处：带 `branch` 的抉择可以写目标段前缀的旗标。新增的远洋旗标统一用 `o_` 前缀，远洋原有旗标保留原名 | — |

---

## 2 代码核对（逐条读过仓库）

| 结论 | 证据（`0bf260eb`） | 对实现的影响 |
|---|---|---|
| 内核与 31c0b3e5 一致 | `git diff --stat 31c0b3e5 0bf260eb -- scripts/cards/campaign data/campaigns scripts/cards/loop scripts/cards/core` 只有两个 JSON 的说明文字 | golden 在 HEAD 上录 |
| **存档与定义哈希强绑定** | `_valid_state` 要求 `saved.definition_hash == _definition_hash`（ocean_campaign.gd:626），而定义哈希覆盖整份 JSON（包括文字） | C 每改一个字，旧的 `suspend.json` 就读不回来。A 加上「哈希不符时用命令日志重放」（§6.7） |
| **账目里有正文** | `_record("appraisal", {…, "observation": …})`（:186）、`_record("battle2", {…, "battle": 模板名})` | ARCH 的 `hash_v1` 除了去掉 `segment/run/map/archive/rogue.tally`、记 `v=1`，**还要去掉 `definition_hash` 和账目里的 `observation` 与 `battle` 两个字段**，否则 C1 一改字 golden 就失效 |
| 动作次数按场计 | `_used` 和 `_use` 只看 `used_actions[当前场景]`（:495） | §1 C25 |
| 红旗只有代价 | `_tick_day` 里红旗每天警戒 +15，别处没有任何收益（:373） | §7.4 给每色旗一个地图效果 |
| 战斗地图尺寸由 scale 写死 | `validate_template` 要求 `map` 的行数和列数等于 `SCALES[scale]` 的行列（battle_rules.gd:818 起） | B 要支持 `size`，同时加 `grand` 和 `epic` 两档 |
| 命令类型只有两种 | `order.type ∈ {hold, no_leak}`，回合上限 1–20 | C18；epic 14 回合在上限之内 |
| 斩首令 | `int(state["act"]) < 4` 就不发（:1794） | 改成 L ≥ 7，与 L = 2a−1 等价 |
| 主角兵力 | `ocean_battle.json.protagonist = {hp 12, hp_per_act 2, hp_max 20}` | 单段书上限仍是 20，napoleon 书取 `book.hero_hp_max = 24` |
| 勋章不走 `_add_coin` | `Battle2.finish` 直接 `clampi` 勋章（ocean_battle2.gd:286） | 加 `tally` 时改走 `_add_coin` |
| 币制换算有默认值 | `franc_to_treasury` 遇到不认识的币制按 `[1,1]` 算 | 土伦的 `livre` 显式补 `[1,1]` |
| 骰子公式 | `_roll_dice` 用 `seed*31+day*17+…`，不是 FNV | 单段书保留原公式，地图骰子用 `seed_for` |
| 存档上限 | `card_save.gd:48`：超过 512 KiB 报 `save_too_large` | 检查点（ARCH §1.7 原样采纳） |
| 窗口标题 | `project.godot` 的 `config/name="德厚当"`，导出名同样 | **当铺名会出现在窗口标题上**。A 在拿破仑线运行时调用 `DisplayServer.window_set_title("鹰旗军需官")`；工程名和旧版导出预设不动（§12.3） |
| 当铺字眼分布 | `ocean_pawn.json` 49 处、`ocean_view.gd` 19、`hub_ui.json` 11、`vn_ui.json` 7、`art_list.json` 7；界面代码里的命中**全是注释**（vn_panel 5、hub_panel 4、hub_card_panel 3、hub_pause_panel 2、hub_title、modal_host、card_game_root、vn_script 各 1） | ARCH §6 的清单漏了 `hub_pause_panel.gd`（0bf260eb 新加的文件）和 `test_vn.gd:370/374`；`hub_title.gd` 的天平纹章是代码画的图，也要换 |
| 测试套数 | `tools/run_ocean_tests.sh` 跑 9 套：campaign、ui、battle_v2、battle_campaign、hd_kit、vn、battle_field、battle_hud、hub | 新测试由 A 加进这个列表 |
| 远洋伙伴数值 | conquest 的 5 个跨段伙伴与 `ocean_battle.json.companions` 逐项相同（脚本核对） | 无冲突 |
| 敌军数值 | 三包同 id 的敌人，数值和标签全部相同；现有 7 种也没被改（脚本核对） | 名册直接合并 |
| 战力公式 | 用 cristo 的 `battle_lib.counts` 复算：远洋 403/658/898/1432、伊夫堡 530/631 与各稿一致；主干已画的两张是土伦 58、里沃利 111，鹰飞滑铁卢 524 | §8.3 的战力链以这些实测值为锚 |

---

## 3 游戏身份

- **工作名**：《鹰旗军需官》，副题「一七九三 · 土伦 → 一八一五 · 厄尔巴 → 三条路」。
  - 名字就是主角的身份，三条分支都套得上；
  - 题里没有「当」字；
  - 不剧透分岔。
- **备选**：
  - 《一八一五：鹰、潮与伊夫堡》：好记，但剧透了分岔；
  - 《皇帝的军需官》：通俗，可离开拿破仑以后的两条分支在题里没有着落。
- **主角**：埃德蒙·德·维尔福。
  - 马赛人，1793 年在土伦炮兵库当书记，后来是意大利军团的军需文书，最后做到近卫军军需司库；
  - 与王家检察官杰拉尔·德·维尔福同宗。伊夫堡分支的主线张力就在这里：揭发杰拉尔，等于亲手毁掉「维尔福」这个姓。
- **反复出现的物件**：厄尔巴双面金怀表（不再是天平）。
  - 主干终章拿到；
  - 远洋序曲里换来船票；
  - 第四场与另一半密信合璧；
  - 悲剧结局里漂向远方。
  「军需官的秤」只在剧情里偶尔出现，不再是象征。
- **段的品牌**（标题徽章、读档行、章节卡都用）：

| 段 | 品牌 | 副题 | 徽章 |
|---|---|---|---|
| `trunk` | 鹰旗 | 一七九三—一八一五 | 鹰 |
| `conquest` | 鹰飞 | 继续征服 · 一八一五—一八一九 | 展翅的鹰 |
| `ocean` | 远洋 | 海底两万里 · 一八一五—一八三五 | 鹦鹉螺 |
| `cristo` | 伊夫堡 | 基督山伯爵 · 一八一五—一八三八 | 城堡 |

- **标题页**（`hub_title.gd` 仍继承 CardTitle，信号和按钮名不变）：
  - 左栏：
    - 题签小字；
    - 金色大标题；
    - 引子：「帝国的每一枚法郎都记在他的账上。一八一五年二月，厄尔巴岛的码头上，他要选一条路。」
    - 按钮：「出征」「接续战役」「篇章」「设置」「离开」。「接续战役」下面一行小字写段、章和日期；「篇章」只在有解锁时出现。
  - 右侧纹章：鹰徽压在三叉罗盘上，四周三枚分支徽章。没到过的分支是暗的；到过的分支亮起，并写出这条分支的结局收集数，例如「2/5」。数据由 `OceanBridge.title_info()` 读 `napoleon_meta.json` 和 `suspend.json` 的 meta。
  - 右下旧账盒：种子框保留；「航海旧账」改名为「战役档案」。

---

## 4 一局的结构

### 4.1 主干「鹰旗」（8 章）

| 章 id | 标题 | 年代 | 视图 | 场景（第一卷可玩） | Boss | 插曲 |
|---|---|---|---|---|---|---|
| `toulon` | 序章 · 土伦 1793 | 1793 | `toulon_1793`（局部） | toulon_arrival → toulon_mulgrave | 小直布罗陀 `toulon_night` L1（教学） | — |
| `italy` | 第一幕 · 意大利 | 1796—97 | `europe` | italy_nice → italy_milan → italy_rivoli → italy_campo_formio | 里沃利 `rivoli_plateau` L3 | 召见（卡尔诺） |
| `orient_alps` | 第二幕 · 东方或阿尔卑斯 | 1798—1800 | `europe` | orient_orders → orient_acre（阿尔卑斯线 alps_marengo 第二卷开放） | 阿卡 `acre` L5 | 营火 |
| `austerlitz_jena` | 第三幕 · 奥斯特里茨或埃劳 | 1805—07 | `europe` | boulogne_orders → austerlitz_sun（eylau_snow 第二卷） | 奥斯特里茨 `austerlitz` L7 | 破译 |
| `iberia_danube` | 第四幕 · 西班牙或瓦格拉姆 | 1808—09 | `europe` | bayonne_orders → saragossa_siege（wagram_lobau 第二卷） | 萨拉戈萨 `saragossa` L9 | 召见（贝尔蒂埃） |
| `russia` | 第五幕 · 俄罗斯 | 1812 | `europe` | russia_niemen → russia_borodino（锚点战 L9）→ russia_berezina | 别列津纳 `berezina` L10 | 野营夜 |
| `collapse` | 第六幕 · 崩落 | 1813—14 | `europe` | collapse_lutzen → collapse_leipzig → collapse_fontainebleau | 莱比锡 `leipzig` L11 | 营火 |
| `elba` | 终章 · 厄尔巴 | 1814—15 | `elba_1814` / `portoferraio_1815` | elba_arrival → elba_night → **elba_1815**（分岔） | 码头仓库 `elba_cove` L12 | 过秤 |

- 序章和第一幕写满：每场正文 6–9 行，2–3 个查验，3 个抉择。第二到第六幕和终章是压缩写法（每场 4–6 行，`condensed:true`），主线照样走得通。
- 调令场景（orient_orders、boulogne_orders、bayonne_orders）各写一个互斥旗标（`rules.exclusive_flags`），两个战区的场景各带 `when`。第一卷里第二个抉择挂 `requires:{"volume":2}`。
- 主干**没有正常结局**，只有四种失败收场：
  - `bankruptcy` 军费告罄；
  - `loss` 大军溃散；
  - `blockade` 全区起义；
  - `exile` 污名，即大命运转中流放。
  另有讣告 `obituary`（主角阵亡）。
- 时长估计 2.5–3 小时。偏长的话，第一刀砍可绕的精英战（洛迪、拉法沃里塔、哈瑙），主线不受影响。

### 4.2 分岔点：厄尔巴 1815-02-25

- 分岔场景是 `elba_1815`（穆利尼宫），地图上是 `branch` 节点，位于终章 Boss 之后的战役段。
- 选在这一天的理由：三条分支的挂钩都落在十天之内。
  - 2 月 24 日，法老号进马赛港（大仲马原著第一章）；
  - 2 月 26 日，皇帝离开厄尔巴；
  - 2 月 28 日，唐泰斯被捕；
  - 8 月 4 日的远洋序曲，可以由「随驾」一路接过去。
- 三个抉择：

| 抉择 id | 文案 | 去向 | 硬条件（`book.branches.<段>.requires`） | 灰掉时的原因 | 发的物品和旗标 |
|---|---|---|---|---|---|
| `march_with_emperor` | 随皇帝北上，亲赴前线 | `conquest` | `any:[ stat.medal_earned ≥ 10 , flags:[t_guard_oath] ]`，并且 `hero_ok` | 「皇帝没点你的名：忠诚不够（整局累计挣到勋章 ≥ 10，或在枫丹白露写下名字随驾厄尔巴）」/「主角重伤未愈，上不了马」 | `k_marched`；`elba_watch` |
| `follow_as_treasurer` | 以司库身份随驾，管钱袋与船 | `ocean` | 无（保底；书校验要求恰好有一条无条件分支） | — | `o_followed`；`elba_watch` |
| `carry_the_letter` | 奉命携密信去马赛 | `cristo` | `any:[ flags:[faria_half_letter] , flags:[t_pharaon_known] ]` | 「你和马赛没有交集：没拿到法利亚的半封信，也没见过莫雷尔或法老号」 | `m_letter_carried`；`elba_watch`、`emperor_letter` |

- 可用性是纯函数：`RunConditions.eval(campaign, branches[段].requires 并上 choice.requires)`。不满足就返回 `branch_locked`，并带上第一条失败条件的原因键。
- 拿到 `t_pharaon_known` 有三条路：
  - 土伦图随机槽里的「莫雷尔父子商行的粮船」事件；
  - 枫丹白露选「回马赛」；
  - 厄尔巴战役段的固定节点「码头·法老号靠岸」，可绕开，但就摆在路上。
  所以伊夫堡线几乎总能开。
- `faria_half_letter`：第一幕博洛尼亚的固定事件「法利亚的半封信」。去博洛尼亚的路要交过路费。

### 4.3 软挂钩（只改开局，不挡门）

| 主干旗标 | 鹰飞 | 远洋 | 伊夫堡 |
|---|---|---|---|
| `t_mysore_envoy`（开罗的提普苏丹使者） | — | 尼摩招募价 −1，开局信赖 1 | — |
| `t_pharaon_known` | — | 唐泰斯、莫雷尔各信赖 +1 | （门槛之一） |
| `t_dantes_letter`（在费拉约港亲手把信交给唐泰斯） | 请愿书一节多一行 | 唐泰斯信赖 +1 | 开场多一行旁白；人心 −3，唐泰斯信赖 +1 |
| `faria_half_letter` | 可以把伊夫堡 27 号一起放出来 | 法利亚信赖 +1 | 第二章「拼上那半封信」可选 |
| `t_guard_oath` | （门槛之一） | 进入时威望 +5 | — |
| `t_storks_hostile` | 第一章多一支对手承包商 | — | — |
| `t_morrel_credit` | — | — | 起手金币 +1 |
| `t_went_home` | — | — | 第一章开局多揭开两个节点 |

跨段读取的旗标必须登记在 `book.shared_flags` 里，校验器拒绝读未登记的跨段旗标：

```
faria_half_letter, t_pharaon_known, t_guard_oath, t_mysore_envoy, t_dantes_letter, t_storks_hostile,
t_vilna_reserve, t_lithuania_taken, t_saragossa_terms, t_saragossa_storm, t_marie_paid, t_ponds_mercy,
t_return_mark, t_morrel_credit, t_went_home
```

### 4.4 携带（段切换时）

采用 ARCH §1.6 的 `_switch_segment` 七步，全部在 `send()` 的候选副本里做，失败就整体回滚。携带规则定稿：

| 项 | 规则 |
|---|---|
| 军费 | 目标章的 `treasury_start`，加旧余额 × 1/4。币制不同时先折算：旧币 → 法郎 → 目标币，用 `ocean_battle.json.franc_rate`，整数、向下取整 |
| 士气（morale） | 保留（各段名字不同，键不变） |
| 体力（vitality） | 保留，至少 40 |
| heat / construction / exploration | 取目标段的 `initial` |
| 旗标 | 全部保留 |
| 物品 | 只留 `elba_watch`、`faria_half`、`emperor_letter`、`guard_eagle_ribbon`，其余随归档 |
| rogue | 全部保留：伙伴的死活、伤痕、等级，部队，道具，信赖，tally。四种币各自截到 20；`battle2`、`march`、`calendar` 重置 |
| 部队 | `army.chapter` 改成目标章，然后 `top_up_troops` |

### 4.5 三条分支

#### 鹰飞 `conquest`（继续征服，1815—1819 架空）

| 章 | 第一卷 | 场景 | Boss L | 插曲 |
|---|---|---|---|---|
| `hundred_days` 第一章 · 百日 1815 | **可玩，写满** | k_golfe_juan → k_laffrey → k_tuileries → k_charleroi（锚点战 L12）→ k_waterloo → k_waterloo_night | 滑铁卢·普朗斯努瓦 `waterloo` L14（epic 12×7，泥地） | 召见 |
| `rhine` 第二章 · 莱茵之秋 | 预告 | k_brussels（L15）→ k_ultimatum → k_rhine | `rhine_crossing` L16 | 野营夜 |
| `vienna` 第三章 · 第三次维也纳 1816 | 预告 | k_bavaria → k_vienna → k_schoenbrunn | `vienna_streets` L18 | 营火 |
| `iberia_channel` 第四章 · 伊比利亚或海峡 1817 | 预告 | k_choice_1817 → k_torres_vedras ‖ k_dover | `iberia_return` ‖ `channel_landing` L20 | 召见 |
| `niemen` 第五章 · 第二次涅曼河 1818 | 预告 | k_warsaw → k_niemen | `niemen` L22 | 破译 |
| `last_coalition` 终章 · 最后的同盟 1819 | 预告 | k_paris_1819 → k_leipzig_1819 → k_final | `coalition_final` L24（epic） | 野营夜 |

- 第一章的精英战是利尼和四臂村，都是 L13。
  - 利尼打死布吕歇尔（模板 `kill_flags` → `k_blucher_down`）：滑铁卢第 11 回合齐滕那一波不来；
  - 弗勒吕斯军议选「格鲁希每两个钟头报一次信」（`k_grouchy_close`）：滑铁卢多一回合布阵；
  - 四臂村占住路口（`k_crossroads_held`）：滑铁卢大炮群那片高地多一格能部署。
  这些都由 A 在 `battle_prepare` 时翻译成 setup 的 `mods`（§6.6），规则内核不认识这些旗标。
- 第一章的核心钩子是固定事件「伊夫堡 34 号」：在战争部截下莫雷尔替唐泰斯写的请愿书，附议人就是杰拉尔。三个抉择：
  - 放 34 号：得 `k_dantes_freed`，唐泰斯入队；
  - 34 号、27 号一起放：需要 `faria_half_letter`，唐泰斯和法利亚都入队；
  - 退回杰拉尔：得 `k_petition_returned`。
- 固定结局（`rules.endings`，按顺序取第一个满足的；第二卷才能打到）：

| id | 标题 | 条件 |
|---|---|---|
| `k_return` | 回到马赛 | 终场选辞呈，并且有 `k_dantes_freed` |
| `k_pax` | 鹰的和平 | 终场选和约，民愤 < 60，9 个「留余地」旗标里至少有 3 个 |
| `k_iron` | 铁的欧洲 | 终场选皇冠 |
| `k_dusk` | 鹰落（默认） | — |

- **第一卷卷终**（`rules.volume_endings`，按顺序取第一个满足的）：`k_waterloo_night` 作完决定后结束这一局。
  - `k_vol1_mercy`「胜利之夜」：有 `k_wounded_exchanged`，把一万伤员换了回来；
  - `k_vol1_pursuit`「追到布鲁塞尔」：有 `k_pursuit`；
  - `k_vol1`「鹰飞·待续」：默认。
  卷终单独记进 meta，不算进结局收集数。
- 段专属大命运（`big_fate_extra`）：
  - **随驾流放**：只在 `k_waterloo` 战败时出现，条件是 `not_flags:[k_petition_returned]`。选了就跳到远洋段，从序曲图的马尔梅松接上；士气 −6。
  - **最后的方阵**：只在滑铁卢和莱比锡 1819 战败时出现。士气回到 40，体力 −10；宿命落在这一仗的伙伴必须上场断后。
- 指标名：军费 / 士气 / 民愤 / 体力 / 工事 / 测绘。

#### 远洋 `ocean`（海底两万里；现有 14 场换皮）

| 章 | 视图 | 锚点（场景 → 节点） | 场景战斗（napoleon 书） | Boss L | 插曲 |
|---|---|---|---|---|---|
| `prologue` 序曲 · 贝勒罗丰号的双面怀表 | `biscay`（画布） | 马尔梅松（固定事件 `ev_o_malmaison`，1815-06-29）……prologue → `plymouth`（Boss） | `bellerophon_deck` L13（grand 10×6） | 13 | 召见（百日·杜伊勒里宫） |
| `st_helena` 第一部 · 黑岩孤岛与基督山的幽灵 | `longwood`（画布） | scene01 `jamestown`、scene02 `wharf`、scene03 `royal_oak`、scene04 `sea_cave`、scene05 `longwood` | 01 无；02 `jamestown_streets` L14；03 无；04 `sea_cave` L15；05 `longwood_escape` L16 | 16 | 野营夜 |
| `new_elba` 第二部 · 新厄尔巴的鹰徽配给账 | `new_elba`（画布） | scene06 `wreck_shoal`、scene07 `granite_exchange`、scene08 `granite_workshop`、scene09 `skull_reef` | 06 `shipwreck_beach` L17；07 无；08 `viper_boarding` L19；09 `skull_reef` L20 | 20 | 营火 |
| `nautilus` 第三部 · 海底两万里与四海同盟 | `world`（米勒） | scene10 `new_elba_port`、scene11 `vigo`、scene12 `atlantis`、finale `thames` | 10 无；11 `vigo_seabed` L22；12 `atlantis` L22；finale `thames_estuary` L24 | 24 | 听音（管风琴） |

- 地图上额外的仗：
  - `deadwood_camp`：精英，L15，可绕；
  - `ice_shelf`：支线遭遇，L21，冰面裂成海；
  - `squid_platform`：精英，L23，巨型章鱼，可绕。
- 随机池 `battle_pool.ocean`：

| 等级段 | 模板 |
|---|---|
| 13–16 | signal_hill、beach_landing |
| 17–20 | beach_landing、reef_crossing |
| 21–24 | reef_crossing、nautilus_deck_raid |

- 结局沿用现在的规则：alliance、ghost、dark、tragedy，默认 bittersweet。标题页按 5 个计收集数（x/5）。
- 失败收场有军费告罄、封锁线合拢、最后的灯火，另加讣告。
- 催逼（demands）在地图上的交付点：药品送到 `hutts_gate`，一千先令保证金交到 `plantation`。
- 段专属大命运：
  - 基督山伯爵出钱赎人：唐泰斯活着，每局一次；
  - 鹦鹉螺号紧急下潜：第十场以后可选，丢下被俘的人换取脱身。
- 指标名：军费 / 同盟威望 / 敌方警戒 / 体力与士气 / 岛屿建设 / 深海探索。
- 杰拉尔线用三张牌串起来：马尔梅松的批注、百日召见里的一问、通用事件「族人的消息」。它只影响热度和威望，不决定结局。
- 单段书 `ocean_pawn` 仍按 `scene_map` 和旧模板打仗，开局仍是 starter 三人。

#### 伊夫堡 `cristo`（基督山伯爵，大仲马 1844，公有领域）

- 主角**不坐牢**。他带着皇帝的第二封信去马赛，收信人是杰拉尔的父亲努瓦蒂埃，可他晚到了半天。
- 之后十四年，他靠伊夫堡驻军的**面包合同**进出要塞的厨房：给 27 号送药，给地道送工具。

| 章 | 第一卷 | 视图 | 锚点场景 | Boss L | 精英 L | 插曲 |
|---|---|---|---|---|---|---|
| `marseille` 第一章 · 马赛 1815 | **可玩，写满** | `marseille_1815`（画布） | c_landfall → c_reserve → c_gerard → c_petition → c_white_june | `marseille_arrest` 14（grand） | `catalans_cove` 13 | 营火 |
| `if_years` 第二章 · 伊夫堡岁月 1816—1829 | **可玩，写满** | `if_fortress`（画布，一张图跨十三年） | c_if_contract → c_bread_34 → c_faria_27 → c_morgiou（锚点战 L15）→ c_faria_dies → c_if_night | `if_corridors` 16（grand，夜） | `janina_lake` 15（6 天航程的远方节点） | 破译 |
| `montecristo` 第三章 · 基督山 1829 | 预告 | `med` | c_tiboulen → c_livorno → c_montecristo | `monte_cristo_cave` 18 | `tiboulen_swim` 17 | 野营夜 |
| `mediterranean` 第四章 · 地中海 1829—1838 | 预告 | `med`（加 `rome_city` 镜头） | c_caderousse → c_morrel_rescue → c_carnival → c_san_sebastiano | `san_sebastiano` 21 | `appian_way` 20 | 召见 |
| `paris_1838` 第五章 · 巴黎 1838 | 预告 | `paris_1838`（画布） | c_champs_elysees → c_auteuil → c_peers → c_danglars → c_trial | `cristo_final` 24（epic） | `auteuil_garden` 22、`paris_rooftops` 23 | 过秤 |

- 唯一的架空岔口：第二章带上药（`m_faria_medicine`），法利亚就能活过第三次发作，和唐泰斯一起出逃，成为后三章的伙伴（一条命）。
- 第二章唐泰斯和法利亚都在牢里：名册里有他们，但只能在 `if_corridors` 第 9 回合以后上阵（C28）。
- 固定结局（终场 `c_trial` 三选一；第二卷才能打到）：

| id | 标题 | 条件 |
|---|---|---|
| `m_wait_hope` | 等待与希望 | 选慈悲，并且有 `m_valentine_saved`，人心 ≥ 50 |
| `m_full_ledger` | 伯爵的清单 | 选清算，三个仇人都倒下，卷宗 ≥ 100 |
| `m_name` | 维尔福这个姓 | 选保姓 |
| `m_count` | 基督山伯爵（默认） | — |

- **第一卷卷终**（`rules.volume_endings`）：`c_if_night` 作完决定以后结束这一局。
  - `m_vol1_two`「两个人的海」：有 `m_faria_lives`，法利亚和唐泰斯一起游向蒂布朗岛；
  - `m_vol1`「伊夫堡·待续」：默认，画面停在唐泰斯从麻袋里割开一道口子。
- 段专属大命运 `m_cell_35`：被宪兵带 `arrest` 标签的白刃打倒、主角被俘时可选「关进伊夫堡 35 号」。一年以后由莫雷尔担保放出：体力 −20、人心 −8、追缉 −40，地道 +15。
- 指标名：经费 / 人心 / 追缉 / 体力 / 地道 / 卷宗。

### 4.6 肉鸽：局外解锁与重玩

- 局外记录 `napoleon_meta.json`：`{v:1, endings:{段:[id…]}, volumes:{段:[id…]}, branches_reached:[…], trunk_cleared, codex:{companions_met:[…]}}`。
  - 只记解锁了什么，不攒数值（沿用 v0.9 profile 的原则）；
  - 只由 bridge 读写，不碰旧的 `profile.json`。
- 「篇章」抽屉：
  - 「主干 · 土伦 1793」：总是可选；
  - 「分岔 · 厄尔巴 1815」：到过分岔点以后解锁，用 `debug_carry.branch_point` 的标准携带；
  - 「鹰飞 / 远洋 / 伊夫堡 · 第一章」：打出这条分支的任一结局或卷终以后解锁。
- 重玩的变化来自：
  - 进图时按种子定下的随机槽和事件；
  - 战区二选一（第二卷全开）；
  - 三条分支的门槛；
  - 软挂钩；
  - 伙伴的死活；
  - 「随驾流放」这种跨段改道。

---

## 5 世界地图：怎么走

### 5.1 视图与底图

| 视图 | 投影 | 底图（geo 已交付，Natural Earth 公有领域） | 用在 |
|---|---|---|---|
| `europe` | 墨卡托，经度 −12…56，纬度 24…63，画布 2400×2012 | `maps/geo/europe.json`：158 块陆地，34 条河 | 主干第一到第六幕、鹰飞 |
| `world` | 米勒，全球，2400×1402，x 方向回绕 | `maps/geo/world.json`：453 块陆地，含冰盖 | 远洋鹦鹉螺号一章 |
| `med` | 墨卡托，经度 −6…30，纬度 34…51.5，2400×1606 | `maps/geo/med.json`：195 块陆地，16 条河 | 伊夫堡第三、四章 |
| 局部画布（`proj:"canvas"`，1920×1080，节点写 `xy`） | — | 画师出图；出图之前用代码画占位（羊皮纸、海岸线草图、节点网） | 土伦 1793、厄尔巴 1814、费拉约港 1815、比斯开 1815、圣赫勒拿全岛、新厄尔巴、马赛 1815、伊夫堡、巴黎 1838 |

- 三张地理底图**在代码里画**（`map_canvas.gd`）：陆地多边形、湖、河流，配羊皮纸着色器。不需要画师出图。`art_list` 里的 `map_europe/world/med` 是可选的叠加纹理。
- 节点坐标：
  - 地理视图写 `geo:[经度×100, 纬度×100]`，由界面按底图 `view` 的公式投影；
  - 画布视图写 `xy`；
  - 同时写了两个的，`xy` 优先。
- **镜头**：
  - `sheets[].frames` 是镜头窗列表，每个窗写 `{id, when, center:geo|xy, zoom}`，界面取第一个 `when` 成立的窗；
  - 没写 frames 时，框住所有可见节点，世界图默认放大 2 倍、以当前节点居中；
  - 可以缩放（1–3 倍）和拖动；
  - 节点标记在屏幕上的间距要 ≥ 40 px，小于 52 px 给提醒（校验器按投影算）；
  - `nodes[].offset` 是标记偏移，画一条引线指回真实位置；
  - `xy_frames` 是同一节点在另一张手绘图上的位置。
  这些都只给界面用，不进状态。
- `--map-reveal` 只影响界面（雾全开，截图用）。

### 5.2 一章一张图（sheet）

- **积累段**：从本章第一场剧情的锚点出发。地图上散着：
  - 随机槽（至少 30%）；
  - 驿站（盖印）、补给点、商贩、营地；
  - 固定事件、可绕的精英战；
  - 来回走的对手分遣队。
  锚点场景按 `scene_index` 线性推进，与现在的内核完全一样。地图只决定玩家在两场锚点之间做什么、走多久。
- **开拔**（`role:muster` 节点，`campaign.map_muster`）有三个条件：
  1. 当前场景的锚点在战役段（也就是积累段的锚点都走完了）；
  2. 驿站印 ≥ `stamps_need`；
  3. 本场的仗已了结。
  开拔以后积累段节点全部锁住，战役段节点解锁。
- **战役段**：军议（council，三选一 `boss_mod`）→ 精英（可绕）→ 野营夜（camp）→ Boss（本章的锚点会战）→ 可以再接本章的收尾剧情（例如坎波福米奥、枫丹白露、滑铁卢之夜、`elba_1815`）。

### 5.3 行军规则（全是整数，完全确定）

1. 每个行动日（`phase == "day"`）二选一，得到 `map.mp`：
   - 掷骰 `campaign.map_roll {}`：d6，种子键 `dice|<段>|<run 内掷骰序号>`，结果 = `h % 6 + 1`；
   - 自选点数 `{"steps":1..6}`：消耗一枚遥控罗盘骰，或 1 枚情报币；
   - 出牌 `campaign.map_card {"index":i}`：一张行军牌，拿到牌面的 MP 和附带效果。
2. 手牌：每天早上补到 3 张，上限 4 张。牌组在进图时按 `deck|<段>|<章>` 用 xorshift32 洗一次，抽完了按固定顺序收回弃牌，不再洗。
3. `campaign.map_move {"to":id}`：
   - 前置：两点之间有连线（`oneway` 只能顺着走）；`requires` 满足；`legs ≤ mp`；没有 `pending`。
   - 扣 `legs`，再扣连线的 `supply`（军需券）。券不够也照走，缺一张体力 −5，记作断粮。
   - 到达：`pos = to`，结算节点的 `pass`。节点是 `forced` 并且还没完成的，设 `pending = to`，必须先 `map_enter`。
   - 一天可以连走几段，每到一个中途节点都结算一次 `pass`（大富翁的「路过」）。
4. 过路费：连线的 `toll` 或对手守着的节点，用 `campaign.map_pay {"how":"gold"|"prop"|"fight"}` 结清。
5. 航程连线（`voyage_days > 0`）：当天还没移动、`mp == 0` 时才能走；消耗 `voyage_days` 天（每天跑一次 `_tick_day`）然后到达。顺风牌让航程少 1 天，最少 1 天。雅科波留守的效果（第二卷）同样是少 1 天。
6. 日终 `campaign.wait`，界面上叫「扎营过夜」→ `_tick_day`：对手移动，`mp` 清零，`days_on_sheet + 1`。
7. **天数预算**：
   - `days_on_sheet > days_max` 以后，每多一天 `map.delay + 1`，本章 Boss 的敌军心因此 +2，最多 +8。
   - 到 `days_max + 4` 时，如果积累段锚点已经走完就强制开拔（`pos` 跳到 muster），否则只继续累计 delay（C5）。
   - 早走有奖励：开拔时还剩几天，第一场战役段战斗开场军令点就 +几，最多 +3。

### 5.4 雾、侦察、锁

- `fog`：
  - `open`：全部可见；
  - `type`：看得见位置，类型显示「?」，离当前位置 2 段连线以内自动揭开；
  - `hidden`：相邻才出现。
- 揭开的节点记进 `map.revealed`，存档会带上。
- `campaign.map_scout {"node":id}`：花 1 枚情报币，揭开这个节点，并显示随机槽定下的类型和等级。黄铜望远镜揭开 2 段以内的全部节点。
- 锁住的节点在查询里给 `state:"locked"` 和 `reason`（条件的原因键）。锚点没轮到时原因固定是 `scene_order`；第二卷内容的原因是 `volume`。

### 5.5 固定与随机

- **固定**：锚点（剧情场景）、Boss、分岔、结局、固定事件节点（`type:event` 加 `event:<id>`）、军议。
- **随机槽**在 `open_sheet` 那一刻一次性定下，写进 `map.slots[节点] = {kind, id, level}`，之后读档、改数据都不再变：
  1. 按节点 id 排序，依次处理每个 `slot`：`h = seed_for(seed, "slot|段|章|节点")`，按 `kinds` 的权重定 kind。和战斗节点相邻的槽，生成时要去掉 `battle` 权重（R2）。
  2. kind 为 `event`：候选是三层池里此刻可用的事件。三层依次是本章池 `slot.pool`、本段通用池（`pool:"<段>"`）、全书通用池 `events_common.json`。「可用」指 `requires` 满足、`chapters` 包含本章、`once` 事件不在 `run.events_seen` 里。用 `event|…` 键按权重挑一个，`weight_by_trust` 按信赖加权，选中的记进 `events_seen`。候选为空就改成 `camp`。
  3. kind 为 `battle`：从 `book.battle_pool[段]` 里覆盖 `slot.level` 的那一档，用同一个键挑模板，等级取 `slot.level`。
- 事件里**禁止**出现 `branch`、`ending`、`advance`，校验器会拒绝。随机只发生在中段，结局由锚点场景的 `rules.endings` 决定。

### 5.6 对手分遣队（rivals）

```json
{"id": "lowe_patrol", "label": "总督巡逻队", "path": ["n4","n5","n6","n5"], "speed": 1, "start": 0,
 "requires": {"flags": ["t_storks_hostile"]},
 "meet": {"battle": {"template": "signal_hill", "level": 14}, "toll": {"gold": 1}, "effects": {"heat": 4}},
 "burns_depots": true, "buys_depots": false, "boss_waves_minus": 1}
```

- 每天按 `path` 走 `speed` 格，下一步是公开的。
- 碰上就是强制遭遇：
  - 有 `meet.battle` 就开打；
  - 也可以付 `meet.toll`；
  - 道具「密使金币袋」能免一次。
- `meet.effects` 遭遇时另扣指标（例如坎贝尔的快艇：情报 −1、民愤 +4）。
- `burns_depots`：停在你的兵站上就烧掉它；`buys_depots`：对手承包商买走它（效果同烧掉，文字不同）。
- 打掉一支，本章 Boss 少 `boss_waves_minus` 波。
- 对手只能走真实存在的连线（校验器检查）；遭遇战的等级 ≤ Boss−2。

### 5.7 新增命令（只在白天；参数严格校验，键或类型不对返回 `bad_args`；失败时状态不变）

| 命令 | 参数 | 主要错误码 |
|---|---|---|
| `campaign.map_roll` | `{}` 或 `{"steps":int}` | `already_used`、`missing_item` |
| `campaign.map_card` | `{"index":int}` | `already_used`、`bad_args` |
| `campaign.map_move` | `{"to":String}` | `not_adjacent`、`locked`、`no_mp`、`pending_node`、`fog` |
| `campaign.map_enter` | `{}` | `locked`、`already_used`、`battle_pending` |
| `campaign.map_choose` | `{"choice":String}`，问答题写 `{"choice":"<题id>:a"}` | `missing_clue`、`missing_flag`、`insufficient_funds` |
| `campaign.map_appraise` | `{"id":String}` | `already_used` |
| `campaign.map_scout` | `{"node":String}` | `insufficient_funds` |
| `campaign.map_build` | `{}` | `insufficient_funds`、`already_complete` |
| `campaign.map_pay` | `{"how":"gold"|"prop"|"fight"}` | `bad_phase`、`insufficient_funds` |
| `campaign.map_muster` | `{}` | `scene_order`、`stamps`、`battle_pending` |

- **节点门禁**：书里开了地图时，下面这些命令都要求玩家当前所在节点的 `actions` 里有这一项，否则返回 `wrong_node`：
  - `campaign.visit / trade / build / explore / fund / schedule / recruit / activity / demand`；
  - `campaign.appraise / choose`（剧情）：要求 `pos` 正好在当前场景的锚点上。
  次数限制照旧（C25）。单段书不受影响。
- 事件里的查验和抉择，使用记录写成 `event:<id>` 和 `event:<id>:<抉择或题>`，存进 `used_actions[当前场景]`，这样 `_valid_state` 不用加新的分区。

### 5.8 新增查询

- `campaign.map`：

  ```
  {enabled, view, frames, sheet, chapter, pos, mp, can_roll,
   hand:[{index,id,mp,label}], days, days_max, delay, stamps, stamps_need, depots, boss_mod, mustered,
   nodes:[{id,type,role,label,xy|geo,state:hidden|fog|open|done|locked|current,reason,level,stars,power,reachable,cost:{legs,supply,toll}}],
   links:[{a,b,legs,voyage_days,state,label}], rivals:[{id,label,pos,next}], pending, teaser:[…]}
  ```

  只给看得见的东西；雾里的节点不透露内容。
- `campaign.run`：`{book, volume, segment, path, level_offset, chapter_ord, branch_offers:[{segment,ok,reason}], meta:{endings,volumes,branches_reached}}`。
- `campaign` 查询里新增 `segment`、`map`（摘要）、`run`（摘要）。

### 5.9 `state.map` 的形状（由 `MapRules.valid` 校验）

```
{"id","sheet","pos","pending","mp","rolled_today","rolls","deck":[…],"hand":[…],"discard":[…],
 "visited":[…],"done":[…],"revealed":[…],"slots":{node:{kind,id,level}},"stamps","depots":[…],
 "rivals":{id:{step,stopped_until,beaten}},"days_on_sheet","delay","mustered","routes_taken":[…],
 "boss_mod":{cp_bonus,enemy_morale,prep_turn},"cp_early":int}
```

---

## 6 数据结构定稿

### 6.1 内核状态 v2 与回归哈希

- 采纳 ARCH §1.6 的字段（`segment / run / map / archive`、`rogue.tally`）和 `_switch_segment` 的七个步骤。`run` 里另加 `volume`。
- **`hash_v1(state)`** 用于单段书的回归：
  1. 去掉 `segment / run / map / archive / rogue.tally / definition_hash`；
  2. 每条 ledger 里去掉 `observation` 和 `battle` 两个键；
  3. 把 `v` 记成 1；
  4. 用 `JSON.stringify(…, "", true).sha256_text()` 求哈希。
  A0 在 `0bf260eb` 上，对 `test_campaign.gd` 的三条路线每一步录一次，存到 `scripts/tests/cards/OCEAN/golden/ocean_routes.json`。

### 6.2 `book.json`（`data/campaigns/napoleon/book.json`）

A 写结构字段，C 写文字和内容字段。下面是定稿形状，数值都是起点：

```json
{
  "id": "napoleon", "version": 1, "volume": 1, "start": "trunk",
  "title": {"name": "鹰旗军需官", "sub": "一七九三 · 土伦 → 一八一五 · 厄尔巴 → 三条路"},
  "segments": {
    "trunk":    {"file": "res://data/campaigns/napoleon/trunk.json",    "map": "res://data/campaigns/napoleon/maps/europe.json",      "kind": "trunk",  "brand": "鹰旗", "badge": "eagle",
                 "scene_battles": {"toulon_mulgrave": {"template": "toulon_night", "level": 1}, "italy_rivoli": {"template": "rivoli_plateau", "level": 3}}},
    "conquest": {"file": "res://data/campaigns/napoleon/conquest.json", "map": "res://data/campaigns/napoleon/maps/europe_late.json", "kind": "branch", "brand": "鹰飞", "badge": "eagle_flight",
                 "scene_battles": {"k_charleroi": {"template": "charleroi_bridge", "level": 12},
                                   "k_waterloo": {"template": "waterloo", "level": 14,
                                                  "mods_when": [{"when": {"flags": ["k_blucher_down"]}, "mods": {"drop_waves": [12]}},
                                                                {"when": {"flags": ["k_grouchy_close"]}, "mods": {"prep_turn": 1}},
                                                                {"when": {"flags": ["k_crossroads_held"]}, "mods": {"terrain": [{"cell": "B2", "terrain": "high"}]}}]}}},
    "ocean":    {"file": "res://data/campaigns/ocean_pawn.json",        "map": "res://data/campaigns/napoleon/maps/world.json",       "kind": "branch", "brand": "远洋", "badge": "nautilus",
                 "events": "res://data/campaigns/napoleon/ocean_events.json",
                 "gauges": {"treasury": "军费", "morale": "同盟威望", "heat": "敌方警戒", "vitality": "体力与士气", "construction": "岛屿建设", "exploration": "深海探索"},
                 "scene_battles": {"prologue": {"template": "bellerophon_deck", "level": 13}, "scene01": {"template": ""}},
                 "demand_nodes": {"medicine": ["st_helena:hutts_gate"], "bond": ["st_helena:plantation"]}},
    "cristo":   {"file": "res://data/campaigns/napoleon/cristo.json",   "map": "res://data/campaigns/napoleon/maps/med.json",         "kind": "branch", "brand": "伊夫堡", "badge": "castle",
                 "scene_battles": {"c_white_june": {"template": "marseille_arrest", "level": 14, "order_flag": "m_morrel_kept"}}}
  },
  "branches": {
    "conquest": {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "",
                 "requires": {"any": [{"stat": {"medal_earned": [">=", 10]}}, {"flags": ["t_guard_oath"]}], "hero_ok": true},
                 "reasons": {"any": "…", "hero_ok": "…"}, "offer": "…"},
    "ocean":    {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "prologue", "requires": {}, "offer": "…"},
    "cristo":   {"from": "trunk", "scene": "elba_1815", "level_offset": 12, "entry": "",
                 "requires": {"any": [{"flags": ["faria_half_letter"]}, {"flags": ["t_pharaon_known"]}]}, "reasons": {"any": "…"}, "offer": "…"}
  },
  "carry": {"metrics": {"treasury": "chapter_start", "morale": "keep", "heat": "initial", "vitality": ["keep_min", 40],
                        "construction": "initial", "exploration": "initial"},
            "treasury_bonus": [1, 4], "flags": "all",
            "items": ["elba_watch", "faria_half", "emperor_letter", "guard_eagle_ribbon"], "rogue": "all", "coin_cap": 20},
  "shared_flags": ["…见 §4.3…"],
  "companions": "res://data/campaigns/napoleon/companions.json",
  "events_common": "res://data/campaigns/napoleon/events_common.json",
  "bond_set": "napoleon",
  "start_rogue": {"coins": {"gold": 4, "supply": 6, "medal": 2, "intel": 2},
                  "props": ["prop_loaded_dice", "prop_field_ration", "prop_smoke_bomb"], "odd_seed_prop": "prop_spyglass", "even_seed_prop": "prop_barricade",
                  "companions": []},
  "start_troops": {"toulon": ["line", "line", "jager"], "italy": ["line", "line", "jager", "artillery"], "…": ["…每个新章一行；远洋四章沿用 ocean_battle.json 的现值…"]},
  "march_cards": {"march_2": {"mp": 2}, "march_3": {"mp": 3}, "forced_4": {"mp": 4, "effects": {"vitality": -4}},
                  "scout_1": {"mp": 1, "reveal": 2}, "wagon_1": {"mp": 1, "coins": {"supply": 2}}, "night_2": {"mp": 2, "ignore_forced": true},
                  "fair_wind": {"mp": 0, "voyage_minus": 1}, "dive_3": {"mp": 3, "ignore_forced": true}},
  "march_deck": ["march_2", "march_2", "march_2", "march_3", "march_3", "forced_4", "scout_1", "wagon_1", "night_2"],
  "march_deck_extra": {"ocean": {"prologue": ["fair_wind"], "nautilus": ["dive_3", "dive_3", "fair_wind"]}},
  "battle_pool": {"trunk": {"1-6": ["skirmish_terraces", "skirmish_mill_ford", "skirmish_hamlet"], "7-12": ["skirmish_terraces", "skirmish_mill_ford", "skirmish_hamlet"]},
                  "conquest": {"12-23": ["skirmish_brabant_farm", "skirmish_sunken_lane"]},
                  "ocean": {"13-16": ["signal_hill", "beach_landing"], "17-20": ["beach_landing", "reef_crossing"], "21-24": ["reef_crossing", "nautilus_deck_raid"]},
                  "cristo": {"12-17": ["alley_ambush", "coast_road"], "18-23": ["alley_ambush", "coast_road"]}},
  "reward_pct_per_level": 4, "hero_hp_max": 24,
  "meta": {"count_endings": {"conquest": ["k_return", "k_pax", "k_iron", "k_dusk"], "ocean": ["alliance", "ghost", "dark", "tragedy", "bittersweet"],
                             "cristo": ["m_wait_hope", "m_full_ledger", "m_name", "m_count"]}},
  "debug_carry": {
    "branch_point": {"coins": {"gold": 6, "supply": 8, "medal": 10, "intel": 3}, "flags": ["faria_half_letter", "t_pharaon_known"],
                     "items": ["elba_watch", "faria_half"], "companions": {"baptiste": 2, "corso": 2, "marie": 1},
                     "troops": ["line", "line", "grenadier", "jager", "hussar", "artillery"]},
    "conquest": {"from": "branch_point", "flags_add": ["t_guard_oath"], "stages": {}},
    "ocean":    {"from": "branch_point", "stages": {"1": {"companions": {"dantes": 1, "faria": 1, "gourgaud": 1, "marie": 1}, "troops": ["…"], "coins": {"…": 0}}}},
    "cristo":   {"from": "branch_point", "flags_add": ["m_letter_carried"], "stages": {"2": {"flags_add": ["m_denunciation", "m_bargain", "m_stay_marseille"], "companions": {"morel": 1, "caderousse": 1}}}}
  }
}
```

- `stages` 里的每一档都是**完整的绝对值**，叠在 `from` 上，不是逐档累加（采用 ocean 的写法）。conquest 的 `per_stage` 公式由 C 展开成逐档。
- 单段书 `ocean_pawn` 没有 book 文件：bridge 内置一个只有一段 `ocean`、没有地图、offset 为 0 的书。

### 6.3 段定义 v2（`trunk.json / conquest.json / cristo.json`；`ocean_pawn.json` 不加字段）

v1 的字段全部保留：`id / version / title / initial / chapters / characters / items / scenes / endings / tuning`。新增字段都可以省略，省略时回落到 `run_ocean_rules.gd`，它和现在的硬编码一字不差。

| 字段 | 形状 | 说明 |
|---|---|---|
| `brand`、`gauges` | String、`{六项指标: 名}` | 显示用 |
| `chapters[].volume` | int，默认 1 | 大于 `book.volume` 的章不能进：在进它之前，按 `rules.volume_endings` 结束这一局 |
| `scenes[].when` | 条件 | 为假就整场跳过：`_advance_scene` 往后找下一场，连续跳过的场不扣天数 |
| `scenes[].choices[].branch / requires / rogue / days` | 见 ARCH §1.5 | `rogue = {coins, props, recruit: id 或 [id…], troops, heal, trust:{pick:n,gain:g} 或 {pair:[a,b],gain:g}}` |
| `rules.failures / endings / default_ending / exclusive_flags / actions` | 见 ARCH §1.5 | 远洋规则写成数据就是 ARCH §1.5 那份 |
| `rules.volume_endings` / `rules.default_volume_ending` | `[{id, when}]` / 结局 id | 本卷最后一场作出推进决定时，按顺序取第一个满足的。每条都要在 `endings` 里有正文，并带 `"kind":"volume"` |
| `rules.signs` | `{white:{daily,map}, red:{…}, black:{…}}` | §7.4；省略时用现行数值 |
| `scenes[].on_enter.demands` | 见 ARCH | 远洋那两条催逼，回落规则里写死 |
| `events` | 事件数组（§6.5） | 远洋的事件写在 `book.segments.ocean.events` 指向的文件里 |
| `big_fate_extra` | `[{id, title, desc, scenes?:[…], when?:条件, jump?:段, effects, rogue?, once_per_run?:bool}]` | 只在 `scenes` 列出的那几场战败时提供 |
| `endings[].kind` | `"fixed"`（默认）/`"volume"`/`"failure"` | 失败结局 id 可以跨段重复（C12） |

**条件小语言**（`run_conditions.gd`，纯函数，只用整数；一个对象里的各键是「且」）：

```
{"flags":[..]} 全有      {"any_flags":[..]} 至少一个      {"not_flags":[..]} 一个都没有
{"metric":{"heat":[">=",100]}}    {"stat":{"medal_earned":[">=",10]}}    {"coins":{"gold":[">=",2]}}
{"alive":["faria"]}（已招募且活着）  {"items":[..]}  {"count_flags":{"of":[..],"min":2}}  {"scene_done":"scene03"}
{"hero_ok":true}  {"trust":{"murat":[">=",3]}}  {"chapter":[..]}  {"segment":[..]}  {"volume":2}  {"mustered":true}
{"any":[c1,c2]}  {"not":c}
```

- 运算符只有 `>= <= > < ==` 五个。
- `reason(campaign, cond)` 返回第一条不满足的键（例如 `stat:medal_earned`），界面据此写原因。
- `{"volume":n}` 的意思是 `book.volume ≥ n`。

### 6.4 地图文件（`maps/*.json`）

```json
{"id": "world", "version": 1, "segment": "ocean",
 "views": {"world": {"proj": "miller", "base": "world", "bg": "map_world"},
           "longwood": {"proj": "canvas", "bg": "map_st_helena"}},
 "sheets": [{
   "chapter": "st_helena", "view": "longwood", "start": "jamestown", "days_max": 12, "stamps_need": 2,
   "muster": "muster_longwood", "boss": "longwood", "interlude": "camp_night",
   "frames": [{"id": "island", "when": {}, "center": [960, 540], "zoom": 100}],
   "years": {"marks": [{"scene": "c_bread_34", "label": "1816"}]},
   "sets": [{"id": "south_coast", "nodes": ["rupert_bay", "lots_wife"], "bonus": {"pass_supply": 1}}],
   "rivals": [ "…见 §5.6…" ],
   "nodes": [ "…见下表…" ],
   "links": [{"a": "jamestown", "b": "n4", "legs": 2, "supply": 1, "label": "海岸小路"},
             {"a": "a", "b": "b", "voyage_days": 3, "requires": {"scene_done": "scene03"}},
             {"a": "rivoli", "b": "la_favorita", "legs": 2, "rush": true}]
 }]}
```

- `muster` 和 `boss` 都可以写成数组，取第一个 `requires` 成立的节点（用于战区二选一）。
- `years.marks` 只给界面：顶栏的年份刻度，用在跨很多年的图上。

**节点字段**：

| 字段 | 类型 | 必需 | 说明 |
|---|---|---|---|
| `id` | String | ✓ | 段内唯一；全书以 `段:节点` 计唯一 |
| `type` | `story/battle/elite/boss/event/camp/supply/shop/branch/slot/teaser` | ✓ | `teaser` 是新加的：第二卷内容的预告，不能进，只显示锁和 `teaser` 文字 |
| `role` | `post/muster/depot/port/intel/project/council` | | `council` 是军议，挂在 `type:event` 上 |
| `label` / `date` | String | ✓ / | 地名；史实日期（只显示） |
| `geo` / `xy` | int[2] | 至少一个 | |
| `frame` / `offset` / `xy_frames` | | | 只给界面 |
| `phase` | `accumulate`（默认）/ `campaign` | | |
| `fixed` | bool | | |
| `scene` | 场景 id | story / boss / branch，或带剧情战的 elite、battle | 锚点；顺序必须和本章 `scene_ids` 一致 |
| `event` | 事件 id | 固定事件节点 | |
| `template` / `level` / `weather` / `reward` / `fallback` | | 不带 scene 的战斗节点 | `fallback` 是 B 还没画好时用的兜底模板（第一卷只许出现在可绕的精英上） |
| `fog` / `requires` / `actions` / `pass` / `forced` / `once` / `slot` | 见 ARCH §2.2 | | |
| `demands` | String[] | | 能在这里交付的催逼 id |
| `teaser` | String | teaser 节点 | 一句预告 |

**动作词表**（`actions` 的值；左边是动作 id，右边是它对应的命令）：

| 动作 | 命令 |
|---|---|
| `visit:town` / `visit:backdoor` | `campaign.visit {place}` |
| `trade:fair` / `trade:counterfeit` | `campaign.trade {kind}` |
| `build` / `explore` / `fund` | `campaign.build` / `campaign.explore` / `campaign.fund`（章节限制读 `rules.actions`） |
| `build_depot` | `campaign.map_build` |
| `schedule:<recruit|train|bond_story|diplomacy|festival|smuggle>` | `campaign.schedule {action}` |
| `activity:<salon|duel|gamble|merchant|rest|smuggle|festival|diplomacy>` | `campaign.activity {id}` |
| `recruit:troop` / `recruit:<伙伴 id>` | `campaign.recruit` |
| `tile:<camp|town|recruit|salon|bazaar|duel|smuggle|shrine|gamble|festival|diplomacy|skirmish>` | 进入时调用一次 `_apply_tile_effect` |
| `muster` | 可写可不写（C20） |

**连线字段**：`a`、`b`、`legs`（1–4）、`voyage_days`、`supply`、`toll`、`oneway`、`requires`、`route`（`salon_route / duel_route / smuggle_route`，第一次踏上时给原路线的奖励）、`rush`、`label`。

### 6.5 事件（`events` 数组；三层池共用一个形状，和场景同构，所以 VN 与查验直接复用）

```json
{"id": "ev_storks_scale", "pool": "italy", "weight": 3, "once": true, "requires": {}, "chapters": ["italy"],
 "title": "…", "location": "…", "speaker": "storks_agent", "date": "1796-05", "body": ["…"],
 "appraisals": [{"id": "short_weight", "kind": "weigh", "label": "当场过秤", "observation": "…"}],
 "choices": [{"id": "expose", "label": "揭穿短秤", "requires_clues": ["short_weight"], "rogue": {"coins": {"supply": 4}}, "flags": ["t_storks_hostile"]},
             {"id": "report", "label": "报告司令部", "rogue": {"coins": {"medal": 1}}, "days": 2}],
 "weight_by_trust": {"companion": "marie", "per_trust": 2}}
```

| 种类 | 池 | 特有字段 |
|---|---|---|
| 随机事件 | 本章池 / `<段>` / 通用池 | — |
| 固定事件 | `pool:"fixed"`，由节点的 `event` 指定 | — |
| 军议 | `pool:"fixed"`，`council:true` | 三个抉择各带 `boss_mod`（C6）；探索可以解锁第四个方略（`requires_flags`） |
| 插曲 · 召见 | `interlude:audience` | `questions:[{id, q, a:{抉择形状}, b:{抉择形状}}]`，1–5 题，题与题互不影响，答完整张牌算完成 |
| 插曲 · 野营夜 | `interlude:camp_night` | `offer:3`：choices 写 3–5 项，按 `interlude|段|章` 的种子挑 `offer` 项，玩家选 1 项 |
| 插曲 · 营火夜话 | `interlude:bond` | 抉择上写 `rogue.trust:{pick:2,gain:1}`（玩家挑两位在队伙伴）或 `{pair:[a,b],gain:1}` |
| 插曲 · 小游戏 | `interlude:minigame:<weigh|decode|ring|fragments>` | 至少一项 `appraisals[].kind` 等于这种小游戏，并且至少一个抉择 `requires_clues` 它（复用 v0.9 的查验小游戏） |

- 插曲在 `year_jump` 阶段以事件牌放出，候选按 `chapters` 过滤。
- 抉择专属的字段：`rogue`、`days`、`battle:{template,level}`（就地开一场仗）、`reveal`、`boss_mod`、`items`、`effects`、`flags`。
- 禁止出现的字段：`branch`、`ending`、`advance`。

### 6.6 战斗模板与开战参数（B）

模板（`battle_templates.json` 的 `templates` 条目）新增的可选键：

| 键 | 说明 |
|---|---|
| `size:[cols,rows]` | 覆盖 scale 的默认尺寸，范围 5×3 到 12×7 |
| `level` | 只作说明：这张图设计时挂在哪个等级的节点上 |
| `base_level` 与 `pad:{kind,every}` | 补兵模板：每一波补 `max(0,(L−b)/every)` 个，适用 L ∈ [b, b+11] |
| `lv_min` | 波次或单位的等级门槛，取代 `act_min`；`act_min = a` 按 `lv_min = 2a−1` 解释 |
| `weather:[…]` | 天时候选，节点没写就用这里 |
| `spawns:[格]` | 伏兵出生格 |
| `tutorial:true` | 教学战，免查等级段目标 |
| `objective:{type,desc}` | 给界面的胜利条件说明 |
| `kill_flags:{敌兵种: 旗标}` | 打死这种敌人时，战役层记一个旗标 |
| `order_next` | 第二卷的命令提案；校验器忽略 |
| `routes[].until` | 路线时效（ARCH §4.3） |
| `events[].on_kill` | 击杀触发改地形（ARCH §4.3） |

`new_battle(tpl, setup)` 的 setup 新增：

- `level`：没给时取 `2·act−1`；
- `weather`；
- `mods`：`{cp_bonus, enemy_morale, prep_turn, drop_waves:[波次下标], terrain:[{cell,terrain}]}`；
- `roster[].from_turn`：伙伴最早能部署的回合（C28）。

`result()` 新增 `killed_kinds:{兵种:数量}`、`loot`、`ransom`。`order_done` 本来就在 `end` 里。

### 6.7 存档、接续、重放

- 采纳 ARCH §1.7：
  - `suspend.json` 每条有效指令后写，`stage_%02d.json` 每进一章写，`branch.json` 进入分岔场景时写，`napoleon_meta.json` 每次 game_over 写；
  - 信封 meta 带 `book` 和 `start`；
  - 所有随机统一用 `seed_for(seed, 键)`；
  - 每次段切换写一个检查点。
- **新增：定义哈希不符时的接续**（§2 的强绑定）：
  1. bridge 读档时如果拿到 `save_invalid`，并且原因是定义哈希不符，就用 `run_replay` 从 `meta.start`（或 `replay_base` 检查点）加 `cmd_log`，在新数据上重放一遍；
  2. 每一步都成功，就接受重放出来的状态，并提示一句「数据已更新，进度已按新版重算」；
  3. 有一步失败，就提供「从本章开头重来」，读 `stage_NN.json`，同样重放。
  旧测试 `wrong_definition` 的语义不变：内核层仍然拒绝，宽容只在 bridge 层。

---

## 7 节点、节奏与大富翁手感

### 7.1 节点怎么结算（`campaign.map_enter`）

| type | 进入时 | 完成条件 |
|---|---|---|
| `story` | 只有 `scene == 当前场景` 时才能进，否则锁住，原因 `scene_order`。进入后打开剧情牌（VN）；这一场有仗的，打完才能作推进决定 | 场景推进 |
| `battle/elite/boss` | `campaign.battle_prepare`，战斗键是节点（带 scene 的用场景键）→ 出征名单 → 战斗 → 战果 | 胜利或撤出，或者战败后大命运处理完 |
| `event` | 打开事件牌（VN），有查验和抉择；`role:council` 的是军议 | 作出抉择 |
| `camp` | 营地菜单三选一：周历动作之一（`schedule:*`）、休整（`activity:rest`）、羁绊夜话（`schedule:bond_story`）；`role:muster` 多一项「开拔」 | 每天一次 |
| `supply` | 市镇动作：`visit:town`、`trade:*`、`build_depot`；`role:intel` 是 `visit:backdoor`；`role:project` 是 `build/explore/fund` | 每天一次；每场次数照旧 |
| `shop` | 随军商贩：用金币买道具（`activity:merchant`），招部队（`recruit:troop`），招伙伴（`recruit:<id>`，只限 `segments` 里有本段的伙伴） | 每天一次 |
| `branch` | 分岔剧情牌：三个分支抉择，灰掉的写原因 | 切换段 |
| `teaser` | 进不去，显示预告 | — |

### 7.2 节奏规则（`map_validate.gd` 强制）

- **R1**：从起点到 Boss 的每条路上，至少 1 个 camp，至少 1 个 supply 或 shop。
  检查方法：去掉所有 camp（或者去掉所有 supply 和 shop）以后，起点到 Boss 必须不通。
- **R2**：战斗类节点之间不相邻，标了 `rush` 的连线除外。
  战斗类节点包括 battle、elite、boss、带剧情战的锚点，以及权重里有 battle 的随机槽。
- **R3**：随机槽占节点数 ≥ 30%，每张图的期望事件数 ≥ 3。教学章土伦免检。
- **R4**：每个精英都能绕开。去掉它以后，本章所有锚点和 Boss 仍然到得了。
- **R5**：战役段的顺序是 muster → 军议（唯一）→ [精英] → 野营夜（唯一的 camp）→ Boss。
  - 去掉军议，或者去掉野营夜，Boss 都到不了；
  - 战役段节点不连回积累段；
  - muster 是积累段节点（C5）。
- **R6**：相邻两章的插曲类型不同。跨段也查：主干最后一章对每条分支的第一章。
  - 现在的序列：
    - 主干：—、召见、营火、破译、召见、野营夜、营火、过秤；
    - 鹰飞：召见、野营夜、营火、召见、破译、野营夜；
    - 远洋：召见、野营夜、营火、听音；
    - 伊夫堡：营火、破译、野营夜、召见、过秤。
  - 每种插曲在池里都要有能抽到的事件。
- **R7**：`days_max ≥ 最短天数 + 3`；比最短天数多出 9 天以上时提醒。
  最短天数的算法：按每天 3 MP 算；航程按天数照算；路线要依次经过本章积累段的锚点，并凑够驿站印。
- **R8**（本稿新增）：
  - 每场剧情恰好对应一个锚点，并且按 `scene_ids` 的顺序；
  - Boss 节点带本章最后一场带仗的场景；
  - 锚点的 type 要和这一场的战斗规模一致；
  - 战区变体（`requires` 不同）分别检查。
- **R9**：每个节点在某个变体里从起点都到得了；对手只走真实存在的连线。
- **R10**：等级规则（§8.2）。地图上用到的每张模板都必须存在，否则要列在 `templates_needed` 里，并且这个节点属于第二卷。
- **R11**：每个催逼的交付节点，都能在期限之内从发出它的那一场走到。
- **R12**：每个镜头窗里节点标记的间距 ≥ 40 px（小于 52 提醒）。

节奏目标（设计稿）：
- 每章大约是积累 10 分钟 → 战役 15–18 分钟 → 插曲 3–5 分钟；
- 长仗之后一定接一个轻节点；
- 两场会战不相邻，只有主干最后两章例外，那里是高潮；
- 远洋有四场纯文戏（C24），专门打破「读剧情 → 打一仗」的交替。

### 7.3 手牌、币、道具落在哪里

| 元素 | 在地图上 | 在战场上 |
|---|---|---|
| 行军牌（手牌 3–4 张）/ 骰子 | 决定每天走多远；牌带附加效果：侦察、辎重、夜行、强行军、顺风、潜航 | — |
| 军令牌（战斗牌组） | — | 原样：齐射、刺刀、佯动、号手、炮火、后撤、征发、皇帝的命令 |
| 金币 | 招募、买道具、建兵站（2 枚）、过路费 | — |
| 军需券 | 连线的路费；每 2 张在出征时折成开场军令点 +1，最多 +4 | 开场军令点 |
| 勋章 | 晋升；`tally` 计入忠诚，是鹰飞的门槛 | 战后奖赏 |
| 情报 | 侦察、自选骰点 | 揭开猎官 |
| 驿站印（`role:post`） | 路过盖印，攒满 `stamps_need` 才能开拔 | — |
| 兵站（地产） | 在 supply 节点花 2 金建。之后每次路过军需券 +1，停留时 +3，征兵便宜 1 金；凑齐 `sets` 另有加成；对手停上来会烧掉或买走 | — |
| 对手分遣队 | 公开的下一步、强制遭遇、过路费 | 打掉一支，Boss 少一波 |
| 军议 `boss_mod` | 三选一 | 开场军令点、敌军心、多一回合布阵 |
| 早到奖励 | 开拔时还剩的天数 | 第一场战役段战斗开场军令点 +1~3 |

8 张道具：不开地图时效果照旧；开地图时在原效果之外再加：

| 道具 | 地图上的附加效果 |
|---|---|
| 遥控罗盘骰 | 今天自选骰点 1–6 |
| 帝国急行军靴 | MP +2 |
| 黄铜单筒望远镜 | 揭开 2 段以内的雾 |
| 铁木拒马路障 | 一支对手停 1 天 |
| 密使金币袋 | 免一次过路费或强制遭遇 |
| 炼金掩护烟幕弹 | 脱离强制节点，不结算 |
| 朗姆酒与军粮桶 | 今天的路费军需券全免 |
| 帝国鹰徽嘉奖令 | 只有原效果 |

### 7.4 营令三色旗在地图上的意思（C26；napoleon 书写在 `rules.signs`，单段书照旧）

| 旗 | 每天（`daily`） | 地图上（`map`） |
|---|---|---|
| 白旗 · 照常行军 | — | — |
| 红旗 · 就地征发 | 警戒（民愤 / 追缉）+10 | 每结算一次节点的 `pass`，另得军需券 +1 |
| 黑旗 · 闭营清点 | 军费 −10，警戒 −10 | 当天 MP −1（最少 1） |

数值是起点。C 的自动游玩要验证两条：全程挂白旗不会因警戒失败；全程挂红旗的那一局能打到第二章以后。

---

## 8 等级难度

### 8.1 等级表（B 写进 `battle_rules.gd`，常量 `LEVELS`，下标是 L−1）

- 奇数行 L1/3/5/7/9/11 与现在第 1–6 幕的 `ACT_HP_PCT / ACT_MORALE_PCT / ACT_ATK_BONUS` **完全相同**，所以旧模板和旧测试都不受影响。
- `ACT_*` 三个常量保留，只为兼容。
- 「猎官 / 精英 / 回合」几列是**模板编写目标**：校验器按等级段检查，运行时不硬改。

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

其他按等级变化的项：

- 敌攻、敌防的加成只加在原值大于 0 的敌人身上。
- 斩首令：改为 L ≥ 7 才发，并且不在遭遇战发。
- 主角兵力 = `min(hero_hp_max, 12 + (L−1))`。napoleon 书的上限是 24，单段书是 20。
- 名额 `caps(scale, L)`：
  - L ≤ 11：取现有数组的第 `(L+1)/2` 项，等于现状；
  - L ≥ 12：

    | scale | 在场 / 伙伴 | L 更高时 |
    |---|---|---|
    | skirmish | 5/2 | L ≥ 13：6/2 |
    | elite | 6/3 | L ≥ 13：7/3 |
    | major | 9/5 | — |
    | grand | 10/5 | L ≥ 19：11/6 |
    | epic | 11/6 | L ≥ 19：12/6 |

- 新增两档 `SCALES`：
  - `grand` 大会战：默认 10×6，法郎 260，勋章 4，金币 1；
  - `epic` 决战：默认 12×7，法郎 320，勋章 5，金币 2。
- 奖赏只在战役层缩放，规则内核的 `result()` 不变：
  - napoleon 书的法郎 × `(100 + 4·(L−1))/100`；
  - 分支段 L ≥ 13 的 Boss 勋章 +1；
  - 单段书不缩放。

### 8.2 等级规则（书校验加地图校验，硬性）

1. 按游玩顺序，各章 Boss 的 L **严格递增**（主干 → 每条分支，各自成链）。
2. 同一章内：精英（含带剧情战的精英锚点）≤ Boss−1；遭遇战、随机槽、对手遭遇、带剧情战的遭遇锚点都 ≤ Boss−2。
3. 分支段的任何一场仗 ≥ 主干最终 Boss 的 L，也就是 L12（C2）。
4. 相邻两章（同一条游玩链上）的 Boss：`power(k+1) ≥ power(k) × 112/100`。power 由 B 的 `BattleRules.power(tpl, L, setup)` 计算，公式是 ARCH §3.4，`pad` 补的兵也算在内。
5. 带补兵的模板（有 `base_level`）只能用在 L ∈ [b, b+11]。没有补兵的模板只能用在模板写的 `level` 上（±1）。
6. 教学战（`tutorial:true`）免查第 4、5 条之外的目标。

### 8.3 各段各章定稿（绝对 L；`data/levels_final.json`，脚本自检 0 错）

**主干**：

| 章 | Boss（模板 · L） | 精英 L | 遭遇和随机仗 ≤ | Boss 战力（实测 / 目标） | 状态 |
|---|---|---|---|---|---|
| toulon | toulon_night · 1 | — | 不出仗 | 58 | 已画 |
| italy | rivoli_plateau · 3 | 洛迪、阿尔科莱、拉法沃里塔 · 2 | 1 | 111 | 已画 |
| orient_alps | acre · 5 | pyramids · 4 | 3 | 目标 150 | B 第一卷画 |
| austerlitz_jena | austerlitz · 7 | ulm · 6（可兜底） | 5 | 目标 172 | B 第一卷画 |
| iberia_danube | saragossa · 9 | somosierra · 8（可兜底） | 7 | 目标 200 | B 第一卷画 |
| russia | berezina · 10 | borodino 锚点 · 9；krasnoi · 9（可兜底） | 8 | 目标 228 | B 第一卷画 |
| collapse | leipzig · 11（grand） | dresden、hanau · 10（可兜底） | 9 | 目标 262 | B 第一卷画 |
| elba | elba_cove · 12 | — | 10 | 目标 300，**上限 359**（≤ 403/1.12，接远洋序曲） | B 第一卷画 |

**鹰飞**：

| 章 | Boss · L | 精英或锚点 · L | 遭遇 ≤ | 战力 |
|---|---|---|---|---|
| hundred_days | waterloo · 14（epic 12×7） | ligny、quatre_bras · 13；charleroi_bridge 锚点 · 12 | 12 | **524**（已画） |
| rhine | rhine_crossing · 16 | brussels 锚点 · 15 | 14 | 目标 590（第二卷） |
| vienna | vienna_streets · 18 | — | 16 | 目标 665（第二卷） |
| iberia_channel | iberia_return ‖ channel_landing · 20 | — | 18 | 目标 750（第二卷） |
| niemen | niemen · 22 | — | 20 | 目标 845（第二卷） |
| last_coalition | coalition_final · 24（epic） | — | 22 | 目标 950（第二卷） |

**远洋**（全部已画）：

| 章 | Boss · L | 其他仗 · L | 遭遇 ≤ | 战力 |
|---|---|---|---|---|
| prologue | bellerophon_deck · 13 | 无（规则 2、3 夹住了，对手只收过路费） | — | 403 |
| st_helena | longwood_escape · 16 | sea_cave 锚点、deadwood_camp · 15；jamestown_streets 锚点 · 14 | 14 | 658 |
| new_elba | skull_reef · 20 | viper_boarding 锚点 · 19；shipwreck_beach 锚点 · 17 | 18 | 898 |
| nautilus | thames_estuary · 24（epic） | squid_platform · 23；vigo_seabed 锚点 · 22；atlantis 锚点 · 22；ice_shelf · 21 | 22 | 1432 |

**伊夫堡**：

| 章 | Boss · L | 精英或锚点 · L | 遭遇 ≤ | 战力 |
|---|---|---|---|---|
| marseille | marseille_arrest · 14（grand） | catalans_cove · 13 | 12 | 530（已画） |
| if_years | if_corridors · 16（grand，夜） | morgiou_cove 锚点 · 15；janina_lake · 15（可兜底） | 14 | 631（已画） |
| montecristo | monte_cristo_cave · 18 | tiboulen_swim 锚点 · 17 | 16 | 目标 710（第二卷） |
| mediterranean | san_sebastiano · 21 | appian_way · 20 | 19 | 目标 830（第二卷） |
| paris_1838 | cristo_final · 24（epic） | auteuil_garden 锚点 · 22；paris_rooftops · 23 | 22 | 目标 960（第二卷） |

- 战力链（相邻比值都 ≥ 1.12）：

  | 链 | 各章 Boss 战力 |
  |---|---|
  | 主干 | 58 → 111 → 150 → 172 → 200 → 228 → 262 → 300 |
  | 远洋 | 403 → 658 → 898 → 1432 |
  | 鹰飞 | 524 → 590 → 665 → 750 → 845 → 950 |
  | 伊夫堡 | 530 → 631 → 710 → 830 → 960 |

  三条分支的第一个 Boss 都大于主干最后一个（300）× 1.12。
- **风险（来自 ocean 稿）**：L13 的贝勒罗丰号有 30 个敌人、6 个精英，对刚出主干的队伍可能偏重。等 elba_cove 实测以后，按规则 4 回头校准。必要时把第 10、11 回合那两波各删一个朱安老兵。

### 8.4 显示

- 出征名单和地图节点上显示：
  - 「Lv 14 · ★★★」；
  - 规模和尺寸、回合、敌军心、天时；
  - **推荐战力**：推荐 = `enemy_power × 110/100`，我方当前 = `Σ max_hp × (atk+def+block)/10`，主角上阵时也算进去。
- 写成「推荐 1320 / 当前 1180」：当前 ≥ 推荐为金色，≥ 80% 为琥珀色，否则红色。系数按 §8.5 的扫描校准。

### 8.5 单调性验收（B；`test_battle_levels.gd` 与 `tools/battle_sweep.gd`）

- **打法**：`battle_policy.gd`，确定、偏弱。B 把它的 GROUND/HIGH 判断改成调用 `Rules.can_stand`。
- **参考名册** `napoleon/ref_rosters.json`，按 L 给出「按进度应有的队伍」：
  - 部队 `min(8, 4+L/4)`；
  - 伙伴数取当时的名额，伙伴数值 × `(100+5(L−1))/100`；
  - 主角不上阵。
  - 另有一份固定的起步名册 R1。
- **指标**：
  - W = 胜率；
  - S = 安全余量：胜局取 `100 × 最终军心 / 开场军心`，败局计 0，取均值；
  - 种子数默认 8，设 `DEHOUDANG_SWEEP=1` 时 30。
- 补兵模板在 b、b+3、b+6、b+9 四个等级各测一次；其余模板只测它的使用等级。

| 编号 | 要求 |
|---|---|
| A1 单调 | 固定名册 R(b) 下，等级升高时 W 不升；S 严格下降，每一档至少降 5 分 |
| A2 不白给 | 参考名册 R(L) 下：遭遇战 W ≤ 95% 且 S ≤ 85；精英 W ≤ 90%；Boss W ≤ 85% |
| A3 打得过 | 参考名册 R(L) 下：遭遇战 W ≥ 50%，精英 ≥ 35%，Boss ≥ 25% |
| A4 被动必输 | 「只按交火」「只放主角」（每个能站的格、四个朝向都试）在所有模板、所有使用等级下全部失败 |
| A5 逐章更难 | §8.2 第 4 条；由书校验调用 `power()` 检查 |
| A6 确定、整数 | 同一种子跑两次 `result` 相等；状态、视图、预演、结算里都没有浮点数 |

- 冒烟子集：每个模板取 2 个等级 × 3 个种子，控制在 240 秒内。完整扫描输出 `docs/cards/balance/levels.md`。
- **兼容（硬验收）**：
  - `test_battle_v2.gd` 一字不改，全部通过；
  - 新增 golden：现有 7 张模板 × 第 1–6 幕 × 种子 1–3，各跑一条固定的 60 步指令序列。`JSON.stringify(result)` 和去掉 `level`、`weather` 两个键以后的状态哈希都要逐条相等。

---

## 9 地形（定稿）

### 9.1 地形表（B 在 `battle_rules.gd` 里新建 `TERRAIN` 表；`GROUND / HIGH / ENEMY_WALK` 改由这张表推出，新增 `TOP`）

三个内容包和本稿用的都是 ARCH §4.2 这一套字符，没有冲突。第一卷已画的模板用到了除 `K`（墓穴）和 `o`（水井）以外的全部字符；这两种由主干的沙漠图和第二卷用上。

| 字符 | id | 名称 | 站位 | 敌可走 | 步耗 | 防+ | 远防+ | 挡视线 | 层 | 备注 |
|---|---|---|---|---|---|---|---|---|---|---|
| `.` | plain | 平地 | ground | ✓ | 1 | | | | 1 | 旧 |
| `^` | high | 高地 | high | | | | | | 2 | 旧 |
| `=` | road | 道路 | ground | ✓ | 1 | | | | 1 | 旧 |
| `v` | village | 村庄 | ground | ✓ | 1 | 2 | | | 1 | 旧，对双方都生效 |
| `w` | woods | 树林 | ground | ✓ | 1 | | 2 | | 1 | 旧，对双方都生效 |
| `~` | river | 河 | none | | | | | | 0 | 旧 |
| `b` | bridge | 桥 | ground | ✓ | 1 | | | | 1 | 旧 |
| `f` | ford | 浅滩 | ground | ✓ | 1 | | | | 1 | 旧 |
| `m` | marsh | 沼泽 | none | | | | | | 0 | 旧 |
| `G` | gate | 红门 | none | 起点 / 途经 | 1 | | | | 1 | 旧，可以有多个 |
| `E` | eagle | 鹰旗 | none | 终点 | 1 | | | | 1 | 旧，可以有多个；走进任何一面都扣军心 |
| `+` | earthwork | 胸墙 | high | | | | | | 2 | 预先筑好，或由工兵筑出 |
| `_` | void | 虚空 | none | | | | | | – | 不画；射程跳过；冲锋到这里停；不挡视线；不能在路线上 |
| `#` | wall | 墙 | none | | | | | ✓ | 3 | 事件可以把它变成瓦砾 |
| `;` | rubble | 瓦砾 | ground | ✓ | 2 | 1 | | | 1 | |
| `s` | snow | 雪地 | ground | ✓ | 2 | | | | 1 | |
| `u` | mud | 泥地 | ground | ✓ | 2 | | | | 1 | 骠骑兵冲锋进来就停 |
| `i` | ice | 冰面 | ground | ✓ | 1 | | | | 1 | 事件「冰裂」可以把它变成河或海 |
| `a` | sand | 沙地 | ground | ✓ | 1 | | | | 1 | |
| `n` | dune | 沙丘 | high | | | | | | 2 | |
| `o` | well | 水井 / 绿洲 | ground | ✓ | 1 | | | | 1 | 沙漠天时的补水点 |
| `d` | deck | 甲板 | ground | ✓ | 1 | | | | 1 | |
| `q` | quarterdeck | 艉楼 / 艏楼 | high | | | | | | 2 | 舰炮的 at 格 |
| `t` | rigging | 桅盘 | top | | | | | | 3 | 只有猎兵类上得去 |
| `\|` | mast | 桅杆 | none | | | | | ✓ | 3 | |
| `W` | sea | 海 | none | 只有船 | | | | | 0 | 炮艇的 at 格 |
| `-` | shallows | 浅水 | none | ✓ | 2 | | | | 0 | 登陆、涉水；我方不能站 |
| `*` | reef | 暗礁 | none | | | | | | 0 | |
| `,` | beach | 沙滩 | ground | ✓ | 1 | | | | 1 | 岸防炮的 at 格；涨潮事件可以把它变成浅水 |
| `c` | cave | 洞穴 | ground | ✓ | 1 | | 2 | ✓ | 1 | 敌炮不瞄洞里的单位 |
| `k` | dock | 码头 | ground | ✓ | 1 | | | | 1 | |
| `p` | plank | 跳板 | ground | ✓ | 1 | | | | 1 | 接舷路线可以从这里起 |
| `H` | hatch | 舱口 | none | 起点 | 1 | | | | 1 | 出生格 |
| `S` | street | 街道 | ground | ✓ | 1 | | | | 1 | |
| `B` | building | 房屋 | ground | | | 2 | | ✓ | 1 | 我方能进驻，敌人不走；视线穿不过，屋里的单位能向外射击 |
| `R` | rooftop | 屋顶 | top | | | | | | 3 | 只有猎兵类上得去 |
| `C` | corridor | 牢廊 | ground | ✓ | 1 | | | | 1 | 黑暗 |
| `L` | cell | 牢房 | ground | | | 1 | | | 1 | |
| `D` | door | 牢门 | none | 起点 / 途经 | 1 | | | | 1 | 出生格；事件或 `on_kill` 可以把它锁成墙 |
| `K` | catacomb | 墓穴 | ground | ✓ | 1 | | | | 1 | 黑暗 |

几条约定：

- **站位**决定我方哪些兵种能部署：
  - `ground` 给 place = ground 或 any 的兵种；
  - `high` 给 place = high 或 any 的兵种；
  - `top` 只给 `CLASSES[cls].top == true` 的兵种：现在只有 `jager`，以及猎兵兵种的伙伴（科尔索、万帕）；
  - `none` 谁都不能站。
- **步耗**只用在敌人沿路线移动的时候：每走一格扣该格的步耗，速度不够就停在原地。旧地形全是 1，所以旧行为不变。
- **校验**：
  - 路线中段的格子必须是敌人可走的；
  - 起点必须是 G、H、D，或者是 `spawns` 里列出的伏兵格（村庄、树林、街道、墓穴、跳板）；
  - 终点必须是 E。

### 9.2 只对新地形生效的规则

- **视线**：
  - 小火器（我方 line 和 jager；敌方 range > 0 并且不是炮的单位）需要视线；炮是曲射，不看视线。
  - 用整数 Bresenham 算：沿长轴逐格前进，平局时取行号较小的一侧。两端之间（不含两端）只要有一格挡视线就不通。
  - 我方的射程图样遇到第一个挡视线的格子就截断。
  - 敌方远程在锁定目标和出手时都要求视线通；不通时只能打挡住它的那个单位。
- **顶层**（层 3，也就是 `t` 和 `R`）：
  - 站在顶层的射手射程 +1：横队 1–3 格，猎兵 1–4 格；
  - 打层 ≤ 1 的目标时攻 +1；
  - 敌方的桅顶射手同理；
  - 敌炮选目标时，把顶层上的单位当高地处理，排在地面单位后面。
- **黑暗**（`C`、`K`，以及夜间天时）：射手站在黑暗格上时射程 −1，最少 1。
- **洞穴**：`_gun_pick` 跳过洞里的单位；洞里的单位挨远程时防 +2。
- **事件改地形时格子上有单位**（在 `_begin_turn` 里处理）：
  - 我方单位脚下变得不能站（冰裂、涨潮）：退回部署栏，冷却 2 回合，不算倒下，不退军令点；拒马直接移除。
  - 敌人脚下变得不能走：直接移除，按击杀扣敌军心，日志写「落水」或「坠落」。
  - 旧模板的事件只会把河变成浅滩，碰不到这两种情况。
- **击杀触发**：`events:[{"on_kill":"turnkey_chief","cell":"D3","terrain":"wall"}]`。在 e 步、清点阵亡（`_sweep`）之后结算。
- **路线时效**：路线可以写 `"until": 回合`，校验器只检查从首次使用到 `until + 路线长度` 这一段时间的地形，这样「锁门」「炸桥」才做得出来。没写 `until` 的路线按现规则检查。

### 9.3 天时（`state.weather`，开战时按 `weather|<战斗键>` 从候选里挑一个，战斗中不再变）

| 天时 | 规则 |
|---|---|
| clear | — |
| rain | 小火器攻 −1，伤害仍至少 1；炮不受影响 |
| mud | 敌骑兵在所有格子上步耗 +1；我方骠骑兵冲锋距离 −1 |
| snow | 我方每回合军令点 −1（3 变 2）；军医回复 −1 |
| fog | 来敌提前公开的回合数 −1（2 变 1；情报羁绊三档时 3 变 2） |
| night | 所有远程射程 −1（同黑暗）；来敌提前公开的回合数 −1 |
| desert | 第 3、6、9……回合的 e 步：我方在场单位如果 1 格内（含本格）没有水井，兵力 −1，但不会因此倒下（最低留 1） |
| storm | 每回合 e 步结束时，桅盘上的我方单位兵力 −1（最低留 1）；敌炮艇每 3 回合开一炮（平时 2 回合） |

旧状态读进来没有 `weather` 键时按 clear 处理。

### 9.4 `battle_rules.gd` 的改动清单（函数级；B）

| 位置 | 改动 |
|---|---|
| `TERRAIN_CHARS / TERRAIN_NAMES` | 补齐 §9.1 |
| 新增 `TERRAIN`、`TOP`、`can_stand(cls, terrain)`、`walk_cost(terrain, enemy)` | 由表推出 `GROUND / HIGH / ENEMY_WALK` |
| `SCALES` | 加 `grand`、`epic`；新增 `caps(scale, L)` |
| 新增 `LEVELS`、`level_of_act(a)`、`row(L)`、`power(tpl, L, setup)` | `ACT_*` 保留，只为兼容 |
| `ENEMIES` | 照抄 `data/enemies_final.json`（111 种）；现有 7 种字节不变 |
| `CLASSES.jager` | 加 `top: true` |
| `new_battle` | 支持 `size`、`level`、`weather`、`lv_min`、`pad`、`mods`、`roster[].from_turn`；状态加 `level`、`weather`、`loot`、`ransom` |
| `validate_template` | 检查：尺寸上限；新字符；虚空不在路线上；出生格；`until`；at 格的地形（敌兵种的 `at_terrain`）；`post/top/boat` 标签与站位一致；等级段目标（提醒级） |
| `_spawn_wave` | 用 `LEVELS[L]` 的兵力、攻、防，按 `pad` 补兵，`ambush` 的波次从 `spawns` 出生 |
| `_unit_def / _enemy_def / _dmg_to_unit` | 防和远防改由表驱动；旧地形数值相同 |
| `_place_err` / `_deploy_block_reason` | 改用 `can_stand`；`from_turn` 没到时返回 `not_yet` |
| `_move_enemy` | 按步耗扣速度预算；处理 mud 天时；处理 `skirmisher` 后退 |
| `_pattern_cells` | 跳过虚空；视线截断；顶层 +1；黑暗 −1 |
| `_pick_ranged_target / _ranged_valid_target` | 加视线和黑暗；`sniper` 优先挑主角和伙伴 |
| `_gun_pick` | 跳过洞穴；顶层当高地；`short` 只瞄列差 ≤ 4；`rocket` 溅射 |
| `_hussar_charge` | 遇到不能走的格子、虚空、墙、泥地就停 |
| `_begin_turn` | 事件改地形时处理格子上的单位；`on_kill` 事件 |
| `_cp_gain / _horizon / _step_e` | snow、fog、night、desert、storm |
| `_reach_eagle` | 带 `loot`、`ransom` 的敌人另记计数 |
| `_hurt` | `arrest`：主角被这种敌人的白刃打倒时不掷铜钱，直接被俘 |
| `_decapitation` | 条件改成 L ≥ 7，不在遭遇战 |
| `view` | 加 `level`、`weather`、`cells[].tier / los / stand / dark`；`stealth` 敌人离我方所有单位都超过 2 格时显示为「?」 |
| `result` | 加 `killed_kinds`、`loot`、`ransom` |
| `load_state` | 不变（v 仍是 2，新键用 get 取默认值） |

确定性：只用整数；战斗中仍然没有随机数；天时和补兵都在进场时定下。

### 9.5 3D 场地与界面（B）

- `field_terrain.gd`：
  - 新地形的顶面高度 `TOP`：
    - sea 0.0（带波纹）、shallows 0.06、reef 0.04；
    - deck 0.30、quarterdeck 0.62、rigging 1.10；
    - wall 0.90、building 0.18（加房屋摆件）、rooftop 0.75；
    - corridor、cell、door 0.18（暗石材质），catacomb 0.12；
    - snow、mud、ice、sand、well 0.18，dune 0.5；
    - void 不建地块，底座沿不规则的外轮廓走。
  - `FLOW` 加 sea 和 shallows。
  - 新增侧面贴图 `side_wood`、`side_stone`、`side_sand`。
- `field_props.gd` / `battle_board.gd`：
  - 新摆件：桅杆、桅盘、船舷、舰炮、墙段、房屋、屋顶、牢栅、牢门、骨堆、礁石、棕榈、水井、冰裂、雪松；
  - `HATS / GEAR / CAVALRY / GUNS` 补齐新敌人，炮艇用船体网格；
  - 天时特效：雨和雪粒子、雾（WorldEnvironment）、夜间灯光、沙尘、风暴（浪加轻微倾斜）。
- `field_cam.fit`：12×7 在 1280×720 的逻辑画布上、去掉 HUD 安全区以后，每格不小于 44 px。列标签用 A–L。
- `battle_lineup_panel` 的小地图、`battle_panel` 的图例和可部署高亮，都改用 `Rules.can_stand`。
- `battle_ui.json`：补 `legend_order / legend_swatch / enemy_char`，覆盖全部地形和敌人。

---

## 10 敌军名册（定稿）

- 形状照旧：`{name, hp, atk, def, spd, type, range, tags}`。数值是 L1 基线，运行时按 `LEVELS` 缩放。
- 新增两个可选键：
  - `at_terrain`：允许出现的 at 格地形；
  - `move`：默认 `foot`，船是 `boat`。
- `type` 仍然只有 infantry / cavalry / elite / leader / wagon / gun 六种，`KILL_ENEMY_MORALE` 不变。
- 机器可读的定稿在 `data/enemies_final.json`（111 种）。三包同 id 的敌人数值和标签全部一致；现有 7 种没被改动。

**内核要认识的标签**（现有的 `hunter / heavy / officer / execute` 不变）：

| 标签 | 规则 |
|---|---|
| `pierce` | 挡住它需要的空余阻挡值 +1（普通 1 变 2，重型 2 变 3），占用的阻挡值照常 |
| `skirmisher` | c 步之后如果还活着，下一回合 b 步先后退 1 格并脱离阻挡；每 2 回合一次 |
| `ambush` | 这一波从模板 `spawns` 里的格子出生 |
| `boarder` | 路线起点可以是跳板或舱口 |
| `post` | 定点不动的远程，spd 为 0，用 `at` 波次出场 |
| `top` | 只能出现在顶层的 at 格 |
| `stealth` | 离我方所有单位都超过 2 格时，视图里显示为「?」（兵种、名字、标签、兵力都隐去）；规则不变，预演只给伤害数 |
| `loot` | 走进鹰旗时照常扣军心，另记 `loot + 1`；战后每个 loot 让法郎 −15%，最低到 0 |
| `ransom` | 走进鹰旗时另记 `ransom + 1`；战后每个扣 1 金币，最低到 0 |
| `arrest` | 主角在它的白刃下倒下时不掷铜钱，直接被俘，战役层转入大命运「被捕」（伊夫堡另有「35 号牢房」一项） |
| `rally` | 同纵队攻 +2，取代纵队长原来的 +1 |
| `boat` | 只能站在海格（at 格） |
| `short` | 炮只瞄与自己列差 ≤ 4 的格子 |
| `rocket` | 打准星格，同时以半伤打准星格靠鹰旗方向（列号 −1）的那一格 |
| `sniper` | 远程挑目标时优先主角和伙伴，其次精英和军官 |

**美术家族**：111 种敌人不必各画一套小人。B 可以给 `ENEMIES` 加一个可选键 `art`，让同一国别、同一兵种共用小人和头像，例如 `pr_line` 家族涵盖 landwehr 和 fusilier。没写 `art` 时，美术 id 就是 `enemy_<id>`。

**全表**（按阵营分组；来源一栏中，「现有」是仓库里已有的，「ARCH」出自 ARCH §5，「新增」注明是哪个内容包加的）：

**奥军与意大利战区（第一幕；前 7 种是现有的）**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `whitecoat` | 白衣步兵 | 6/3/1/1 | 步兵 | — | — | — | 现有 |
| `grenz` | 格伦茨猎兵 | 5/3/0/1 | 步兵 | 2 | — | — | 现有 |
| `dragoon` | 龙骑兵 | 10/5/1/2 | 骑兵 | — | hunter | — | 现有 |
| `hungarian` | 匈牙利掷弹兵 | 12/4/2/1 | 精英 | — | heavy | — | 现有 |
| `leader` | 纵队长 | 10/3/2/1 | 纵队长 | — | officer | — | 现有 |
| `wagon` | 弹药车 | 4/0/0/1 | 辎重 | — | — | — | 现有 |
| `gun` | 奥军炮 | 8/6/1/0 | 炮 | 炮 | — | — | 现有 |
| `piedmontese` | 皮埃蒙特步兵 | 6/3/1/1 | 步兵 | — | — | — | 新增(trunk/conquest) |
| `barbet` | 巴尔贝游击 | 4/3/0/1 | 步兵 | 2 | ambush | — | 新增(trunk/conquest) |
| `tyrolean` | 蒂罗尔射手 | 5/4/0/1 | 步兵 | 3 | sniper | — | 新增(trunk/conquest) |
| `chevauleger` | 奥军轻骑 | 8/4/1/2 | 骑兵 | — | — | — | 新增(trunk/conquest) |

**奥斯曼与马穆鲁克**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `mamluk` | 马穆鲁克骑兵 | 9/6/1/2 | 骑兵 | — | pierce | — | ARCH |
| `janissary` | 耶尼切里 | 11/5/1/1 | 精英 | — | heavy | — | ARCH |
| `nizam` | 奥斯曼步兵 | 6/3/0/1 | 步兵 | — | — | — | ARCH |
| `bedouin` | 贝都因骑手 | 6/3/0/2 | 骑兵 | — | skirmisher | — | ARCH |
| `bey` | 贝伊 | 11/4/2/1 | 纵队长 | — | officer | — | ARCH |
| `ottoman_gun` | 奥斯曼炮 | 8/6/0/0 | 炮 | 炮 | — | — | ARCH |

**英军**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `redcoat` | 英军战列步兵 | 7/4/1/1 | 步兵 | — | — | — | ARCH |
| `rifleman` | 绿夹克步枪兵 | 5/4/0/1 | 步兵 | 3 | sniper | — | ARCH |
| `highlander` | 高地兵 | 12/5/2/1 | 精英 | — | heavy | — | ARCH |
| `foot_guards` | 英军近卫步兵 | 14/5/3/1 | 精英 | — | heavy | — | ARCH |
| `scots_grey` | 苏格兰灰骑兵 | 11/6/1/2 | 骑兵 | — | hunter | — | ARCH |
| `rocket` | 康格里夫火箭 | 6/5/0/0 | 炮 | 炮 | rocket | — | ARCH |
| `british_gun` | 英军炮 | 9/6/1/0 | 炮 | 炮 | — | — | ARCH |
| `brigadier` | 英军旅长 | 11/3/2/1 | 纵队长 | — | officer | — | ARCH |
| `redcoat_grenadier` | 英军掷弹兵连 | 12/5/2/1 | 精英 | — | heavy | — | 新增(ocean) |
| `mounted_orderly` | 传令骑兵 | 8/4/1/2 | 骑兵 | — | hunter | — | 新增(ocean) |
| `navy_captain` | 皇家海军舰长 | 14/4/2/1 | 纵队长 | — | officer、rally | — | 新增(ocean) |
| `rocket_boat` | 火箭艇 | 6/5/0/0 | 炮 | 炮 | rocket、boat | sea | 新增(ocean) |
| `steam_sloop` | 明轮炮舰 | 14/7/2/0 | 炮 | 炮 | boat | sea | 新增(ocean) |
| `dutch_belgian` | 荷比民兵 | 5/3/0/1 | 步兵 | — | — | — | 新增(trunk/conquest) |
| `brunswicker` | 布伦瑞克黑衣兵 | 6/4/0/1 | 步兵 | — | skirmisher | — | 新增(trunk/conquest) |

**俄军**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `ru_line` | 俄军步兵 | 8/3/1/1 | 步兵 | — | — | — | ARCH |
| `ru_grenadier` | 俄军掷弹兵 | 13/4/2/1 | 精英 | — | heavy | — | ARCH |
| `ru_jaeger` | 俄军猎兵 | 5/3/0/1 | 步兵 | 2 | — | — | ARCH |
| `cossack` | 哥萨克 | 7/4/0/2 | 骑兵 | — | hunter、skirmisher | — | ARCH |
| `cuirassier` | 胸甲骑兵 | 14/6/2/2 | 骑兵 | — | heavy | — | ARCH |
| `opolchenie` | 俄国民兵 | 5/2/0/1 | 步兵 | — | — | — | ARCH |
| `ru_gun` | 俄军炮 | 9/6/1/0 | 炮 | 炮 | — | — | ARCH |
| `ru_general` | 俄军将领 | 12/4/2/1 | 纵队长 | — | officer | — | ARCH |

**普军**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `landwehr` | 普鲁士后备军 | 6/3/0/1 | 步兵 | — | — | — | ARCH |
| `fusilier` | 普军燧发枪兵 | 6/3/1/1 | 步兵 | 2 | — | — | ARCH |
| `uhlan` | 普军枪骑兵 | 9/5/1/2 | 骑兵 | — | hunter、pierce | — | ARCH |
| `pr_grenadier` | 普军掷弹兵 | 12/4/2/1 | 精英 | — | heavy | — | ARCH |
| `pr_gun` | 普军炮 | 8/6/1/0 | 炮 | 炮 | — | — | ARCH |
| `pr_general` | 普军将领 | 13/4/2/1 | 纵队长 | — | officer、rally | — | ARCH |
| `blucher` | 布吕歇尔 | 16/5/2/2 | 纵队长 | — | officer、rally | — | 新增(trunk/conquest) |

**西班牙**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `guerrillero` | 西班牙游击队员 | 5/4/0/1 | 步兵 | — | ambush | — | ARCH |
| `bandolero` | 山地神枪手 | 4/4/0/0 | 步兵 | 3 | ambush、post | — | ARCH |
| `es_lancer` | 西班牙枪骑兵 | 8/5/0/2 | 骑兵 | — | pierce | — | ARCH |
| `es_regular` | 西班牙正规军 | 6/3/1/1 | 步兵 | — | — | — | ARCH |
| `partisan_chief` | 游击头领 | 9/4/1/1 | 纵队长 | — | officer、ambush | — | ARCH |

**海上（远洋）**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `marine` | 皇家海军陆战队 | 7/4/1/1 | 步兵 | — | boarder | — | ARCH |
| `sailor` | 英国水兵 | 6/3/0/2 | 步兵 | — | boarder | — | ARCH |
| `marine_sharpshooter` | 桅顶射手 | 4/4/0/0 | 步兵 | 3 | post、top | rigging | ARCH |
| `boatswain` | 水手长 | 10/4/1/1 | 纵队长 | — | officer、boarder | — | ARCH |
| `pirate` | 海盗 | 6/4/0/1 | 步兵 | — | loot、boarder | — | ARCH |
| `pirate_brute` | 海盗打手 | 12/6/1/1 | 精英 | — | heavy、loot | — | 新增(ocean) |
| `pirate_captain` | 海盗船长 | 12/5/1/1 | 纵队长 | — | officer、loot | — | ARCH |
| `coast_gun` | 岸防炮 | 12/7/2/0 | 炮 | 炮 | — | high、dune、beach | ARCH |
| `coast_sniper` | 崖顶狙击手 | 4/4/0/0 | 步兵 | 3 | post、sniper | high、dune、rooftop | 新增(ocean) |
| `carronade` | 卡隆炮 | 8/8/0/0 | 炮 | 炮 | short | deck、quarterdeck | ARCH |
| `gunboat` | 炮艇 | 10/6/2/0 | 炮 | 炮 | boat | sea | ARCH |
| `raider_captain` | 罗伯茨舰长 | 14/5/2/1 | 纵队长 | — | officer、hunter | — | ARCH |

**1815 保王党与圣赫勒拿**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `royalist_bravo` | 保王党刺客 | 6/4/0/1 | 步兵 | — | boarder | — | 新增(cristo/ocean) |
| `royalist_marksman` | 保王党枪手 | 5/4/0/1 | 步兵 | 2 | sniper、boarder | — | 新增(cristo/ocean) |
| `royalist_chief` | 保王党头目 | 10/4/1/1 | 纵队长 | — | officer、boarder | — | 新增(cristo/ocean) |
| `chouan` | 朱安老兵 | 12/5/2/1 | 精英 | — | heavy、boarder | — | 新增(ocean) |
| `verdet` | 绿衫志愿兵 | 6/3/0/1 | 步兵 | — | — | — | 新增(cristo) |
| `bow_runner` | 弓街探员 | 6/3/1/1 | 步兵 | — | stealth、arrest | — | 新增(ocean) |
| `jack_runner` | 独眼杰克 | 11/4/1/1 | 纵队长 | — | officer、arrest、stealth | — | 新增(ocean) |

**深海与南极（远洋）**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `diver` | 头盔潜水员 | 8/4/2/1 | 步兵 | — | boarder | — | 新增(ocean) |
| `harpoon_diver` | 鱼叉潜水员 | 5/4/1/1 | 步兵 | 2 | — | — | 新增(ocean) |
| `smith_agent` | 史密斯 | 12/4/2/1 | 纵队长 | — | officer、stealth | — | 新增(ocean) |
| `shark` | 鲨鱼 | 8/5/0/2 | 骑兵 | — | hunter | — | 新增(ocean) |
| `great_shark` | 大白鲨 | 13/6/1/2 | 精英 | — | pierce | — | 新增(ocean) |
| `squid` | 巨型章鱼 | 16/5/1/1 | 精英 | — | heavy、execute | — | 新增(ocean) |
| `squid_arm` | 章鱼触手 | 5/3/0/1 | 步兵 | — | pierce | — | 新增(ocean) |
| `sealer` | 海豹猎人 | 7/4/0/1 | 步兵 | — | — | — | 新增(ocean) |
| `harpooner` | 捕鲸鱼叉手 | 6/5/0/1 | 步兵 | 2 | sniper | — | 新增(ocean) |
| `sealer_boss` | 海豹船船长 | 12/4/1/1 | 纵队长 | — | officer、rally | — | 新增(ocean) |

**伊夫堡：马赛与牢狱**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `gendarme` | 宪兵 | 7/3/2/1 | 步兵 | — | arrest | — | ARCH |
| `mounted_gendarme` | 骑宪兵 | 9/4/1/2 | 骑兵 | — | arrest、hunter | — | ARCH |
| `national_guard` | 国民自卫军 | 7/3/1/1 | 步兵 | — | — | — | ARCH |
| `ng_grenadier` | 国民自卫军掷弹兵 | 12/4/2/1 | 精英 | — | heavy | — | 新增(cristo) |
| `prison_guard` | 狱卒 | 8/3/1/1 | 步兵 | — | — | — | ARCH |
| `turnkey_chief` | 典狱长 | 11/3/2/1 | 纵队长 | — | officer | — | ARCH |
| `if_soldier` | 伊夫堡守军 | 7/3/1/1 | 步兵 | — | — | — | 新增(cristo) |
| `if_veteran` | 守军老军士 | 12/4/2/1 | 精英 | — | heavy | — | 新增(cristo) |
| `wall_sentry` | 墙头哨兵 | 4/4/0/0 | 步兵 | 3 | post、sniper | high | 新增(cristo) |
| `fort_gun` | 伊夫堡炮台 | 10/6/1/0 | 炮 | 炮 | — | high | 新增(cristo) |
| `customs` | 海关缉私兵 | 6/3/1/1 | 步兵 | 2 | — | — | ARCH |
| `customs_officer` | 海关稽查官 | 10/3/2/1 | 纵队长 | — | officer | — | 新增(cristo) |
| `revenue_cutter` | 缉私快艇 | 9/5/1/0 | 炮 | 炮 | boat、short | sea | 新增(cristo) |
| `smuggler` | 走私贩 | 6/3/0/2 | 步兵 | — | stealth | — | ARCH |
| `rival_smuggler_boss` | 对头帮的船老大 | 12/5/1/1 | 纵队长 | — | officer、stealth | — | 新增(cristo) |
| `thug` | 码头打手 | 7/4/0/1 | 步兵 | — | — | — | 新增(cristo) |
| `thug_marksman` | 黑枪手 | 4/4/0/0 | 步兵 | 3 | post、stealth、sniper | rooftop、high | 新增(cristo) |
| `thug_boss` | 打手头子 | 11/4/1/1 | 纵队长 | — | officer | — | 新增(cristo) |

**伊夫堡：罗马、东方与巴黎**

| id | 名字 | 兵力/攻/防/速 | 类型 | 射程 | 标签 | at 格 | 来源 |
|---|---|---|---|---|---|---|---|
| `bandit` | 罗马强盗 | 6/4/0/1 | 步兵 | — | ambush、ransom | — | ARCH |
| `bandit_marksman` | 强盗枪手 | 4/4/0/0 | 步兵 | 3 | post、stealth | high、rooftop、woods | ARCH |
| `vampa` | 路易吉·万帕 | 14/5/2/1 | 纵队长 | — | officer、ransom | — | ARCH |
| `papal_carabinier` | 教皇宪兵 | 8/4/2/1 | 步兵 | — | arrest | — | 新增(cristo) |
| `papal_dragoon` | 教皇龙骑兵 | 10/5/1/2 | 骑兵 | — | hunter | — | 新增(cristo) |
| `sbirro` | 教廷密探 | 6/3/1/1 | 步兵 | — | stealth、arrest | — | 新增(cristo) |
| `arnaut` | 阿尔瑙特枪手 | 6/4/0/1 | 步兵 | 2 | skirmisher | — | 新增(cristo) |
| `assassin` | 刺客 | 8/7/1/2 | 精英 | — | hunter、execute、stealth | — | ARCH |
| `benedetto` | 贝内代托 | 13/6/1/2 | 精英 | — | hunter、execute | — | ARCH |
| `municipal_guard` | 巴黎市政卫队 | 12/4/3/1 | 精英 | — | heavy | — | 新增(cristo) |
| `convict` | 土伦苦役犯 | 7/4/0/1 | 步兵 | — | loot | — | 新增(cristo) |
| `police_agent` | 治安密探 | 6/3/1/1 | 步兵 | — | stealth、arrest | — | 新增(cristo) |

---

## 11 伙伴总表（`data/campaigns/napoleon/companions.json`）

### 11.1 名单（28 人；跨段同 id 同数值；一条命，死了就一直是死的）

| id | 名字 | 兵种 | 兵力/攻/防/阻挡 | 费 | 可出现的段 | 来源 |
|---|---|---|---|---|---|---|
| `baptiste` | 巴蒂斯特中士 | 工兵 | 14/3/2/1 | 3 | conquest、cristo、ocean、trunk | 主干/鹰飞稿 |
| `corso` | 科尔索 | 猎兵 | 8/4/0/0 | 3 | conquest、cristo、ocean、trunk | 主干/鹰飞稿 |
| `marie` | 玛丽·朗热 | 军医 | 10/0/1/0 | 3 | conquest、cristo、ocean、trunk | 主干/鹰飞稿 |
| `muiron` | 米隆 | 战列 | 16/5/1/2 | 5 | trunk | 主干/鹰飞稿 |
| `lannes` | 拉纳 | 掷弹 | 20/5/3/3 | 6 | trunk、conquest | 主干/鹰飞稿 |
| `murat` | 缪拉 | 骠骑 | 12/6/1/1 | 4 | trunk | 主干/鹰飞稿 |
| `desaix` | 德塞 | 战列 | 16/5/2/2 | 5 | trunk | 主干/鹰飞稿 |
| `larrey` | 拉雷 | 军医 | 10/0/1/0 | 3 | trunk、conquest | 主干/鹰飞稿 |
| `rustam` | 鲁斯塔姆 | 骠骑 | 11/5/1/1 | 3 | trunk | 主干/鹰飞稿 |
| `eble` | 埃布莱 | 工兵 | 14/3/2/1 | 4 | trunk、conquest | 主干/鹰飞稿 |
| `gourgaud` | 古尔戈 | 掷弹 | 22/4/3/3 | 6 | conquest、ocean、trunk | 主干/鹰飞稿 |
| `pierre` | 小皮埃尔 | 鼓手 | 8/1/0/1 | 3 | trunk、conquest、ocean | 主干/鹰飞稿 |
| `drouot` | 德鲁奥将军 | 炮兵 | 9/7/1/0 | 7 | trunk、conquest | 主干/鹰飞稿 |
| `cambronne` | 康布罗纳将军 | 掷弹 | 22/5/3/3 | 6 | trunk、conquest | 主干/鹰飞稿 |
| `ney` | 内伊元帅 | 骠骑 | 13/6/1/1 | 4 | conquest | 主干/鹰飞稿 |
| `dantes` | 埃德蒙·唐泰斯 | 骠骑 | 12/6/1/1 | 4 | conquest、cristo、ocean | 主干/鹰飞稿 |
| `faria` | 法利亚神甫 | 工兵 | 14/3/2/1 | 3 | conquest、cristo、ocean | 主干/鹰飞稿 |
| `friday` | 星期五 | 鼓手 | 10/2/0/1 | 3 | ocean | 远洋（现有） |
| `nemo` | 尼摩 | 炮兵 | 9/7/0/0 | 7 | ocean | 远洋（现有） |
| `morel` | 莫雷尔 | 战列 | 16/5/1/2 | 5 | cristo、ocean | 远洋（现有） |
| `caderousse` | 卡德鲁斯 | 战列 | 14/4/1/2 | 3 | cristo | 伊夫堡稿 |
| `jacopo` | 雅科波 | 炮兵 | 10/6/0/0 | 6 | cristo | 伊夫堡稿 |
| `bertuccio` | 贝尔图乔 | 工兵 | 14/4/2/1 | 3 | cristo | 伊夫堡稿 |
| `haydee` | 海黛 | 军医 | 9/0/1/0 | 3 | cristo | 伊夫堡稿 |
| `ali` | 阿里 | 掷弹 | 20/5/3/3 | 6 | cristo | 伊夫堡稿 |
| `maximilien` | 马克西米利安·莫雷尔 | 骠骑 | 12/6/1/1 | 4 | cristo | 伊夫堡稿 |
| `vampa` | 路易吉·万帕 | 猎兵 | 9/5/0/0 | 4 | cristo | 伊夫堡稿 |
| `albert` | 阿尔贝·德·莫尔塞夫 | 战列 | 13/4/1/2 | 4 | cristo | 伊夫堡稿 |

- 单段书仍用 `ocean_rogue_data.gd` 的 8 人加 `ocean_battle.json.companions`。napoleon 书里，`RogueRules.roster(campaign)` 返回这张总表，`valid_rogue` 要求伙伴数等于总表人数。
- 招募点（各稿已核对，C 合并时由脚本双向检查）：

  | 段 | 伙伴 → 招募点 |
  |---|---|
  | 主干 | 土伦：巴蒂斯特、科尔索<br>尼斯：玛丽、米隆<br>米兰：拉纳（先发欠饷）或缪拉（收下金币）<br>阿卡：拉雷<br>商贩：鲁斯塔姆、德塞<br>涅曼河：古尔戈、埃布莱<br>别列津纳：小皮埃尔 |
  | 鹰飞 | 儒安湾：德鲁奥、康布罗纳<br>欧塞尔「铁笼」：内伊<br>「伊夫堡 34 号」：唐泰斯，和法利亚（需要半封信） |
  | 远洋 | 罗什福尔：唐泰斯、法利亚<br>富拉：古尔戈<br>东印度公司货栈：玛丽、莫雷尔<br>星期五的村子：科尔索、星期五<br>水力锻炉：巴蒂斯特<br>新厄尔巴港、里约：尼摩 |
  | 伊夫堡 | c_landfall：莫雷尔<br>c_reserve 或事件：卡德鲁斯<br>c_morgiou：雅科波<br>c_faria_dies：唐泰斯；法利亚需要药<br>第二卷：贝尔图乔、海黛、阿里、马克西米利安、万帕、阿尔贝 |

  主干里活下来的伙伴原样带进任何分支。分支里已经在队的，招募动作显示「已在队中」。

### 11.2 每一行的形状（定稿）

```json
"lannes": {
  "name": "拉纳", "short": "拉纳", "segments": ["trunk", "conquest"],
  "bonds": ["italy", "marshal"], "bonds_by_segment": {"cristo": ["…"]},
  "battle": {"cls": "grenadier", "hp": 20, "atk": 5, "def": 3, "block": 3, "cost": 6, "skill": "bayonet_charge", "skill_title": "…", "role": "掷弹兵 · 勇将"},
  "recruit": [{"seg": "trunk", "scene": "italy_milan", "choice": "pay_soldiers_first"},
              {"seg": "ocean", "node": "st_helena:company_store", "gold": 2}],
  "fated": [{"seg": "trunk", "template": "aspern"}], "fated_coins": -2,
  "available_from": {"seg": "cristo", "template": "if_corridors", "turn": 9},
  "hooks": [{"when": {"flags": ["t_mysore_envoy"]}, "seg": "ocean", "gold": -1, "trust": 1}],
  "keep": "…（第二卷）", "relic": "…（第二卷）", "leaves": "…（第二卷）", "note": "…"
}
```

- `fated` 命中时的效果和现在一样：兵力 −1/4，命悬一线 −2 枚（`fated_coins` 可以覆盖）。
- 主角行 `hero.bonds = ["italy","quartermaster","imperial"]`，可以按段覆盖。

### 11.3 羁绊套 `napoleon`（B 写进 `battle_templates.json.bond_sets.napoleon`）

| 类 | 羁绊 |
|---|---|
| 职业（3） | 炮兵学派、方阵、骑兵预备队 |
| 主干阵营（6） | 意大利军团（army_of_italy）、军需官的人、随军家眷、老近卫军（workshop）、将星（spoils）、参谋部（intel） |
| 远洋原样（5） | 帝国旧部（army_of_italy）、远洋同盟（spoils）、暗影密使（intel）、博学工坊（workshop）、荒岛求生 |
| 伊夫堡（5） | 马赛老街坊（camp_family，只有 2 档）、走私帮（spoils）、伯爵府（intel）、东方（workshop，只有 2 档）、巴黎社交界（spoils，只有 2 档） |

所有效果都是 `BOND_EFFECTS` 里现成的；同一效果有几条同时生效时取最高档；最多 3 条同时生效（现规则）。

---

## 12 去当铺（定稿）

**原则**：只换玩家看得见的字和美术描述；机制、id、命令、存档键一律不动。存档目录 `user://cards/ocean_pawn/`、环境变量值 `ocean_pawn`、单段书的 id 都是内部名，玩家看不见，保留。

### 12.1 改名表

| 旧（当铺义） | 新 | 落在哪里 |
|---|---|---|
| 远洋当铺（标题、品牌） | 《鹰旗军需官》；单段书和远洋分支叫「远洋」 | 标题页、读档行、窗口标题 |
| 当铺 / 估值铺 / 海鸥号估值铺 / 海鸥号当铺前堂 | 海鸥号补给栈（法国侨民开的船具补给栈，暗中接济朗伍德）/ 补给栈的货棚 / 补给栈后间 | 场景地点 |
| 掌柜 | 军需官 / 补给栈主 | 人物身份 |
| 柜台 | 案桌 / 配给台 / 作战桌 / 交易台（看语境） | 正文 |
| 挂牌（白 / 红 / 黑）；平价典当 / 军需特收 / 闭门盘库 | 营令三色旗：白旗·照常行军 / 红旗·就地征发 / 黑旗·闭营清点 | `campaign.sign` 不变 |
| 鉴定 / 已鉴定的线索 | 查验：察看（spot）、过秤（weigh）、听音（ring）、破译（decode）/ 已查验的线索 | `campaign.appraise` 不变 |
| 当票 | 调拨凭单 / 军需凭单 | 正文 |
| 流当、流当品、三层流当军需桶、流当任务凭证、流当大印、《流当通知单》 | 封存、罚没品、三层封存军需桶、封存任务凭证、军需总监大印、《缴获清单》 | 物品名、场景标题 |
| 活当 / 活当赎回 / 活当票 | 金蝉脱壳 / 秘密转运 / 转运凭单 | scene05；旗标仍叫 `emperor_redeemed` |
| 收当 / 抵押 / 抵押清单 / 抵押木匣 | 收购 / 担保 / 担保清单 / 押运木匣 | 正文 |
| 赎回（当物义） | 改写成转运；人质义的「赎回」保留 | 正文 |
| 营业 / 营业日 / 营业时间 | 行动日 / 当值时间（「现在不是行动时间」） | 原因文字 |
| 经营须知 | 军需官手册 | 规矩页、F1 帮助 |
| 开张 · 今日行动 / 结账 · 等待明日 | 拔营 · 今日行动 / 扎营 · 等待明日 | 日程按钮 |
| 夜 · 结账 / 第 N 日的账 | 夜 · 点名 / 第 N 日军需 | 日终面板 |
| 金库储备 / 生命与动力 | 各段的 `gauges`（远洋：军费 / 体力与士气） | 指标；键不变 |
| 柜台挂牌、街区暗访、后门密访、资源与援助、行军棋盘、据点周历、伙伴名册、金库与航海日志（营地牌） | 营令、市镇补给、密探联络、工程与援助、世界地图、营地日程、伙伴名册、军需账簿与航海日志 | 牌 uid 不变；napoleon 书里大多成了节点动作 |
| 幽灵当铺 / 深海账房先生 / 深海账房（插图） | 永不靠岸的幽灵舰队 / 深海利维坦的财政官 / 深海金库 | 结局 `ghost`、`dark` 的 id 不变 |
| 「带着当铺账本」「现在开当铺」 | 「带着帝国军需账簿」「流亡皇帝的司库」 | 标题引子、立绘说明 |
| 学徒、守店（小皮埃尔、星期五） | 勤务兵、守营 | 人物身份 |
| 黄铜天平（序曲标题、象征物、纹章） | 厄尔巴双面金怀表；纹章换成鹰徽加罗盘 | 序曲标题、`hub_title` 的纹章、`bg/title` |
| 航海旧账、书架上的账本 | 战役档案、回忆录书架 | 局外记录 |
| 玛丽·瓦伦丁、科尔索·老炮手（`ocean_rogue_data.gd` 里的旧名） | 玛丽·朗热、科尔索 | 只改 `name` |

### 12.2 要改字的文件（全部属于拿破仑线；旧版 1938 一个不碰）

1. `data/campaigns/ocean_pawn.json`：直接换成 `wm/ocean/out/ocean_pawn.json`。那份已经逐键证明除文字以外与基线字节一致，段落数也不变，所以 `vn_cast` 的段号照样对得上。
2. `data/hd/hub_ui.json`：ARCH §6 第 2 条列出的全部键。
3. `data/hd/vn_ui.json`：ARCH §6 第 3 条列出的全部键。
4. `data/campaigns/ocean_battle.json` 的 text 块：`chronicle_obituary`、`obituary_body`。
5. `data/campaigns/battle_ui.json`：`text.result_done` 里的「记进账簿」改成「记进战史」。
6. `data/campaigns/text/ocean_ui.json`：A0 从 `ocean_view.gd` 抽出来，C 按 `wm/ocean/ocean_scenes_rewrite.json` 的 `other_text` 改。
7. `scripts/cards/campaign/ocean_rogue_data.gd`：只改字符串（指标名、两个旧人名），id 不动。
8. `data/hd/art_list.json`（B 合入）：
   - `bg/bellerophon_hold`、`jamestown_shop`、`shop_back_room`、`granite_palace_exchange`、`atlantis_ruins`、`title`；
   - `cg/ending_ghost`、`ending_dark`、`ending_alliance`；
   - `chara/villefort`、`chara/pierre`、`unit/villefort`。
   以上都按 `wm/ocean/ocean_art_requests.json` 的 `update` 改 name 和 desc，id 不改。
9. 界面代码：
   - `hub_title.gd`：纹章不再画天平，改画鹰徽、罗盘和三枚分支徽章（A）；
   - `hub_panel.gd`、`hub_card_panel.gd`、`hub_pause_panel.gd`、`vn_panel.gd`、`vn_script.gd`、`modal_host.gd`、`card_game_root.gd` 里只有注释提到当铺字眼，顺手改掉。
10. **窗口标题**：`card_game_root._start` 在远洋或 napoleon 战役下调用 `DisplayServer.window_set_title(书名)`，回到旧版时还原工程名。
11. 测试里的文字断言（C 改，和改字放在同一个提交）：
    - `test_ui.gd:73` → `contains("远洋")`（单段书）；
    - `test_ui.gd:177` → 只留 `contains("同盟")`；
    - `test_hub.gd:254` → 「军需官手册」；
    - `test_vn.gd:370`、`:374` → 「序曲：贝勒罗丰号的双面怀表」「序曲·贝勒罗丰号的双面怀表」；
    - `test_vn.gd:190` 和 `test_hub.gd:60` 是测试自带的字符串，换成新文案里的句子，免得扫描时被误报。
12. 所有新内容文件（`napoleon/*.json`、`maps/*.json`、`vn_cast` 的新增部分、`art_requests`）由 C 保证干净。

### 12.3 防回潮测试（`scripts/tests/cards/OCEAN/test_content.gd`，C 写，A 把它加进测试列表）

- **词表**（19 个）：当铺、典当、当票、流当、估值铺、掌柜、挂牌、柜台、活当、收当、盘库、鉴定、营业、经营须知、当物、赎当、押当、典押、账房先生。
- **扫描范围**，必须 0 命中：
  - `data/campaigns/ocean_pawn.json`、`ocean_battle.json` 的 text、`battle_ui.json`；
  - `data/campaigns/napoleon/**`、`data/campaigns/text/*.json`；
  - `data/hd/hub_ui.json`、`vn_ui.json`、`vn_cast.json`、`map_ui.json`；
  - `data/hd/art_list.json` 里拿破仑线条目的 name 和 desc；
  - `ocean_rogue_data.gd` 的字符串字面量。
  docs、注释、旧版目录不扫。
- 再加三项检查：
  - 标题页没有「当」字；
  - 窗口标题等于书名；
  - 序曲 VN 的标题卡里没有「天平」。

---

## 13 本轮（第一卷）内容范围

### 13.1 可玩范围

| 段 | 章 | 场景 | 地图 | 战场模板 | 结局 |
|---|---|---|---|---|---|
| 主干 | 8 章全开（第二到第四幕各开一个战区） | 21 场（序章和第一幕写满，其余压缩） | 8 张；另一战区的节点挂 `volume:2` | 已画 9 张，加上 B 第一卷要画的 8 张 | 只有失败收场（主干本来就没有正常结局） |
| 鹰飞 | 第一章 · 百日 | 6 场，写满 | 1 张，第二到第六章画成预告节点 | 已画 6 张 | 卷终 3 种 |
| 远洋 | 4 章全开 | 14 场，换皮 | 4 张 | 已画 17 张 | 4 个固定结局 + 默认 bittersweet |
| 伊夫堡 | 第一、二章 | 11 场，写满 | 2 张，第三到第五章画成预告节点 | 已画 6 张（加上可选的 janina_lake） | 卷终 2 种 |

- 合计约 52 场剧情、15 张图、46 张战场模板，其中 38 张三个内容包已经画好并在 Python 模拟里验过，8 张由 B 第一卷新画。
- 事件约 100 张。

**B 第一卷要新画的 8 张**（地形要点见 `wm/conquest/.../book_conquest_patch.json` 的 `templates_needed`）：

| 模板 | 用途 | L | 规模 | 地形要点 | 战力目标 |
|---|---|---|---|---|---|
| `pyramids` | 精英 | 4 | elite | 沙地、沙丘、村庄、水井；马穆鲁克（pierce）冲方阵；desert 天时 | — |
| `acre` | Boss | 5 | major | 沙漠、城墙（挡视线）、壕沟；目标是撤离或撑住 | 150 |
| `austerlitz` | Boss | 7 | major | 普拉岑高地、冰面；冰裂事件把冰面变成河 | 172 |
| `saragossa` | Boss | 9 | major | 街道、房屋、屋顶、瓦砾；游击队 ambush | 200 |
| `borodino` | 锚点精英 | 9 | grand | 棱堡（胸墙）、村庄、河谷；俄军大炮群 | — |
| `berezina` | Boss | 10 | major | 两座桥、冰河；冰裂成河；snow 天时；目标是撤离 | 228 |
| `leipzig` | Boss | 11 | grand | 城门、村庄、河；四面来敌，含 rocket（康格里夫火箭） | 262 |
| `elba_cove` | Boss | 12 | major | 沙滩、码头、海；岸防炮；英国快艇 | 300（≤ 359） |

- 可绕的精英 ulm、somosierra、krasnoi、dresden、hanau、janina_lake 第一卷允许用 `fallback`（现有的 `elite_a`）。B 有余力就画。
- **只作数据、第一卷不开放**：
  - 主干阿尔卑斯、普鲁士、多瑙河三个战区；
  - 鹰飞第二到第六章；
  - 伊夫堡第三到第五章；
  - 名羁绊、留守、隐患离队；
  - 命令 escape、extract、protect；
  - 5 张有战区味道的通用遭遇战（`battle_pool_wanted`）。

### 13.2 内容规矩（C）

- 大仲马 1844、凡尔纳 1870 都是公有领域；人物、地名、日期只取原著和史实，**不借用任何现代改编**。本作自己的发明（主角、面包合同、法利亚活下来、司法宫之夜、鹰飞整条线）在 `design_notes` 里标明。
- 涉及真实人物的指控（例如洛总督投毒）沿用远洋现有的「本作虚构」写法。
- 远洋那四场不打仗的戏（C24）由地图上的随机槽、精英战和对手分遣队补足战斗量：一局约 10 场锚点战，再加 2–5 场地图战。

### 13.3 第二卷（下一轮，书的 `volume` 改成 2）

- 主干另外三个战区和它们的 Boss：marengo、eylau、wagram，以及可绕精英的正式图。
- 鹰飞第二到第六章，含 7 张模板。
- 伊夫堡第三到第五章：正文从提纲扩写，另画 8 张模板。
- 三种新命令。
- 名羁绊、留守、隐患离队。
- 战区味道的通用遭遇战。
- 第二卷的美术。

---

## 14 美术清单增量

`data/hd/art_list.json` 只由 B 写。A 和 C 把需求写进 `data/hd/art_requests/<包>.json`，由 B 合入。

| 来源 | 内容 | 数量 |
|---|---|---|
| 现有 | 129 条（bg 17、cg 4、chara 23、face 38、unit 24、tex 9、side 2、prop 12） | — |
| 改写（id 不变） | `wm/ocean/ocean_art_requests.json` 的 `update`：去天平、去当铺 | 12 |
| 三个内容包新增，去重后 | bg 122（含 9 张局部地图：toulon_1793、elba、portoferraio、biscay、st_helena、new_elba、marseille_1815、if_fortress、paris）、unit 91、face 86、chara 47（含年代变体，按 C16 拆成独立 id）、cg 8、prop 9、tex 4、side 1、icon 3（council、rival、depot） | 371 |
| B 自己的通用件（ARCH §4.6） | tex 23（雪、泥、冰、沙、甲板、海、浅水、暗礁、沙滩、洞穴、码头、跳板、舱口、石板街、屋内地面、瓦屋顶、牢石、牢房地面、墓穴地面、瓦砾……）、side 3、prop 15；新 kind `icon`（`art/hd/icon/{id}.png`，256×256 透明底）共 14 种节点圆章：story、battle、elite、boss、event、camp、supply、shop、branch、muster、post、council、rival、depot | 约 55 |
| B 补齐 | ARCH §5 主干敌军的 unit 和 face，没被内容包请求的那部分；按 §10 的「美术家族」合并后大约 20 套 | 约 40 |

- **撞名**：conquest 和 cristo 请求了 `chara/marie`、`chara/baptiste`、`chara/villefort`、`chara/pierre` 的变体，与现有条目重名。按 C16 改成 `marie_cantiniere`、`baptiste_1793`、`villefort_1793 / _1805 / _1815 / _1838`、`pierre_drummer`、`dantes_1815 / _prisoner`、`faria_prisoner`、`morel_1815`。
- **三张地理底图**（europe、world、med）由代码画，不进 P0。
- **优先级**：
  - P0 = 第一卷每场剧情的背景、第一卷的 8 张局部地图（巴黎属第二卷）、标题、主角和主要伙伴的立绘、14 个节点图标；
  - P1 = 第一卷的敌人小人和头像、事件背景；
  - P2、P3 = 第二卷。
  所有条目在出图之前都由 `hd_placeholder` 占位，游戏不会缺图。
- `tools/hd_art/check_art.py` 要认新 kind `icon`。

---

## 15 实现工作包与合并

### 15.1 A0（先合；A 做；规模小）

- 把 `ocean_view.gd` 里所有玩家看得见的中文抽进 `data/campaigns/text/ocean_ui.json`（键名按 ARCH §6 第 6 条），`ocean_view` 改成从这份文件读。
- 在 `0bf260eb` 上录两份 golden：
  - `golden/ocean_routes.json`，用 §6.1 的 `hash_v1`；
  - `golden/battle_templates.json`，按 §8.5。
- 把 `wm/geo/{europe,world,med}.json` 拷进 `data/campaigns/napoleon/maps/geo/`，附 `SOURCE.md` 注明 Natural Earth、公有领域。
- **验收**：现有 9 套全绿；显示的文字逐字不变。

### 15.2 A：战役引擎、分段、世界地图（逻辑 + 界面）

| 步 | 内容 |
|---|---|
| **A1 内核**（规模大） | `ocean_campaign.gd` 就地泛化（书、段、`volume`、`when`、`rules.*`、`signs`、节点门禁、空模板、`order_flag`、`kill_flags`、`mods_when`、`big_fate_extra` 与 `jump`）<br>`run/`：`run_book.gd`（书校验，含 §8.2 等级规则和 R6）、`run_conditions.gd`、`run_carry.gd`、`run_ocean_rules.gd`、`run_replay.gd`（含哈希不符时的重放接续）<br>`map/`：`map_rules.gd`（行军、雾、随机槽、对手、兵站、开拔、天数预算）、`map_query.gd`、`map_validate.gd`（R1–R12）<br>`ocean_rogue_rules.gd`：roster、tally、地图上的道具效果<br>`ocean_battle2.gd`：战斗键按节点、等级接线、名额和主角兵力按等级、`available_from`<br>`ocean_bridge.gd`、`card_engine.gd`：`game.new` 认 `napoleon` 和 `segment/stage/book`<br>`fixtures/mini_book.json`：2 章主干 + 3 个迷你分支 |
| **A2 界面**（规模大） | `scripts/cards/ui/map/`：`map_panel`、`map_canvas`（Natural Earth 底图、羊皮纸、雾、连线、对手、镜头窗、缩放）、`map_hand`、`map_node_card`、`map_projection`<br>`hub_title.gd`：新身份、纹章、篇章抽屉<br>VN 支持 `event:` 前缀和每场 `art` 覆盖（vn_data / vn_panel，先和修 VN 的代理确认）<br>`modal_host` 登记 `map / map_shop / map_camp / map_interlude`<br>`card_game_root` 只动三处：`_cmdline_opts`、`_start`（透传参数、窗口标题）、`_sync_hub`（开了地图就建 `map_panel`）<br>`map_policy.gd`、`run_helpers.gd`<br>`data/hd/map_ui.json` |

- **测试**：`test_run_book.gd`、`test_map.gd`、`test_run_replay.gd`、`test_map_ui.gd`；A 是 `tools/run_ocean_tests.sh` 唯一的写手。
- **验收**：
  1. 现有 9 套全绿，单段书的 `hash_v1` 序列等于 golden；
  2. 迷你书走通「主干 → 三个分支各自 → 固定结局 / 卷终」；三种可用性组合（只有远洋 / 远洋加伊夫堡 / 全开）都对；保底分支总在；
  3. 在每一段、每一张图上存档读档往返以后，状态哈希相等；v1 存档能迁移；改过数据之后，旧存档能靠重放接续；
  4. 命令日志重放（含检查点）哈希一致；
  5. 用调试入口能直接开任意段、任意章；
  6. 地图校验器能拒绝 R1–R12 的反例，并拒绝「muster 早于积累段锚点」的提前开拔；
  7. `map_ui` 截图：主画面、节点牌、手牌、雾、对手、世界图放大 2 倍；
  8. 拿破仑线下窗口标题是书名。

### 15.3 B：战斗内核、3D 战场、美术清单

| 步 | 内容 |
|---|---|
| **B1 规则**（规模大） | `battle_rules.gd` 按 §9.4 改：LEVELS、caps、power、can_stand、TERRAIN、天时、15 个标签、111 种敌军、size、grand 与 epic、pad 与 lv_min、mods、from_turn、result 新增项<br>`battle_policy.gd` 改用 `can_stand`<br>`BATTLE_V2.md` 补地形、等级、敌军、天时四节<br>测试：`test_battle_terrain.gd`（每种地形、天时、标签各一条以上单测）、`test_battle_levels.gd`（冒烟）、battle golden |
| **B2 内容与画面**（规模大） | 把三包已画的 38 张模板合进 `battle_templates.json`（只追加；旧 7 张字节不变），用真引擎重验什么都不做必输、只放主角必输<br>新画 §13.1 的 8 张<br>`bond_sets.napoleon`<br>`ref_rosters.json`、`tools/battle_sweep.gd` 全量扫描，输出 `docs/cards/balance/levels.md`<br>3D 场地、摆件、天时特效（§9.5）<br>`battle_ui.json` 的图例<br>合入 `art_list.json` 并补占位 |

- **先交给 A 的接口**（B1 第一步，写进 `BATTLE_V2.md`）：
  - `level_of_act(a)`、`row(L)`、`caps(scale, L)`、`power(tpl, L, setup)`、`can_stand(cls, terrain)`；
  - `new_battle(tpl, {level, weather, mods, …})`；
  - 视图里新增的 `level`、`weather`、`cells[].tier/los/stand/dark`。
- **验收**：
  1. `test_battle_v2.gd` 一字不改全绿，旧模板 golden 相等；
  2. 每种新地形、天时、标签都有单测；
  3. 一张 12×7、带虚空格的不规则模板通过校验并能打完，3D 截图里每格不小于 44 px；
  4. §8.5 的 A1–A6 全部通过；
  5. 美术清单校验通过，新条目都有占位。

### 15.4 C：内容

| 步 | 内容 |
|---|---|
| **C1 去当铺**（规模小） | §12.2 的第 1–7、11 条；`test_content.gd`；`docs/cards/OCEAN_CAMPAIGN.md` |
| **C2 新段数据**（规模中；草稿已经写好，主要是规整和合并） | 写 `tools/napoleon/merge_drafts.py`，把三包草稿转成 §6 的定稿形状：C6、C7、C9、C12、C14、C15、C16、C19、C27 的改名和转换；`recruit:companion` 展开；`rogue.trust` 统一；cristo 的 `failure_text` 并入 `endings`；theatre 抉择挂 `volume:2`；`volume_endings`<br>输出：`trunk.json`、`conquest.json`、`cristo.json`、`companions.json`、`events_common.json`、`ocean_events.json`、`maps/{europe,europe_late,world,med}.json`、`book.json` 的内容字段、`vn_cast.json` 的新增部分、`art_requests/C.json`<br>三包的 Python 校验器搬进 `tools/napoleon/`，作离线检查；**以 A 的 GDScript 校验器为准** |
| **C3 切换**（规模小） | `DEFAULT_BOOK = "napoleon"`；`test_ui` 和 `test_hub` 的开局改成显式选 `ocean_pawn` 书作回归；新增一套 napoleon 书的界面冒烟（标题 → 土伦 → 第一张图 → 第一场仗） |

- **验收**：
  1. 防回潮词表 0 命中；
  2. A 的书校验和地图校验全部通过；
  3. `map_policy` 自动游玩：三条分支各自至少一条路线打到固定结局或卷终；主干三种可用性组合都能复现；全程挂白旗不会因警戒失败（§7.4）；
  4. 每个新场景在 VN 里都有背景和立绘位，人物都登记了；
  5. 每条分支至少 2 个第一卷能打到的固定收场：远洋是 4 个固定结局加默认，鹰飞是 3 种卷终，伊夫堡是 2 种卷终；分岔场景的三个抉择都有可用性文字。

### 15.5 文件归属（防撞）

| 文件 | 唯一写手 | 其他包怎么配合 |
|---|---|---|
| `ocean_campaign.gd`、`ocean_rogue_rules.gd`、`ocean_battle2.gd`、`ocean_bridge.gd`、`ocean_view.gd`、`card_engine.gd`、`card_game_root.gd`、`modal_host.gd`、`hub_title.gd`、`vn_data.gd`、`scripts/cards/campaign/run|map/*`、`scripts/cards/ui/map/*`、`run_ocean_tests.sh`、`data/hd/map_ui.json`、`maps/geo/*` | A | B 只提供接口，C 只改 JSON |
| `battle_rules.gd`、`battle_templates.json`、`battle_ui.json`、`field/*`、`battle_board.gd`、`battle_panel.gd` 与 `battle_lineup_panel.gd` 的地形部分、`battle_policy.gd`、`art_list.json`、`ref_rosters.json`、`tools/battle_sweep.gd` | B | A 和 C 通过 `art_requests/*.json` 提需求 |
| `ocean_pawn.json`、`hub_ui.json`、`vn_ui.json`、`vn_cast.json`、`text/ocean_ui.json`、`ocean_battle.json` 的 text 块、`ocean_rogue_data.gd` 的字符串、`napoleon/*.json`（除了 `book.json` 的结构字段）、`maps/{europe,europe_late,world,med}.json`、`test_content.gd`、`tools/napoleon/*` | C | `book.json` 按键分工，合并时由 A 复核 |

修界面的代理也在改 `card_game_root.gd`、`modal_host.gd`、`hub_title.gd`、VN 和 battle 的各块面板。开工前先发消息，按小提交合并。

### 15.6 合并顺序与进度

```
A0 ──► B1 ──► A1 ──► C1 ──► A2 ──► B2 ──► C2 ──► C3 ──► 终验
       （B1、A1、C1 并行开工；A2、B2、C2 并行开工）
```

- 每次合并之后都跑全部 OCEAN 测试，再跑旧版冒烟（`tools/run_tests.sh` 里的旧版那一段）。
- **终验**：自动游玩三条分支各一局；给主创出截图和平衡表。
- **还有多久**：
  - 设计已经收口，三个内容包的数据草稿基本齐了（38 张战场、约 100 张事件、15 张第一卷地图都在草稿里）；
  - 剩下的主要是代码：三个大工程（A1、B1、A2）加 B2 的 8 张新图；
  - 总共 8 个合并步骤；
  - 主创第一次能从标题玩到地图，是在 A2 合入之后；三条分支全部能玩，是在 C3 合入之后。

---

## 16 待主创拍板（都给了默认；不回复就按默认做）

1. **工作名**：默认《鹰旗军需官》。备选是《一八一五：鹰、潮与伊夫堡》《皇帝的军需官》。
2. **第一卷范围**：默认远洋完整、鹰飞打到滑铁卢之夜、伊夫堡打到逃出伊夫堡、主干每幕一个战区。另一种做法是第一卷就把鹰飞做完整，代价是 B 多画 7 张图，第一卷晚一大步。
3. **第二到第四幕第一卷各开哪个战区**：默认东方（阿卡）、奥斯特里茨、西班牙（萨拉戈萨）。
4. **「随驾流放」跨段跳转**（鹰飞打输滑铁卢 → 转进远洋）：默认做。
5. **分岔点**：默认 1815 年 2 月的厄尔巴。如果要三条分支都亲历滑铁卢，就把分岔点挪到 6 月 18 日之后，伊夫堡的开局要改写成「回马赛找唐泰斯」。
6. **导出包名**：默认新增一个「鹰旗军需官」导出预设，开局默认 napoleon 书。旧版「德厚当」的预设和工程名不动。

---

## 17 自查（对照主创的要求逐条核）

| 主创的要求 | 本稿怎么满足 | 残余 |
|---|---|---|
| 不要再当铺；内核还在，表面换成另一款游戏 | §12 改名表和文件清单；纹章、标题、窗口标题、美术描述全换；19 词防回潮测试；营地主画面换成世界地图（§5） | 内部名 `ocean_pawn`（存档目录、环境变量）看不见，保留；导出包名见拍板第 6 条 |
| 战役难度随关卡提升 | §8：全局 L1–24；Boss 严格递增；相邻章战力 ≥ ×1.12；A1 单调、A2 不白给、A3 打得过 | 主干第二幕以后的 8 张 Boss 图还没画，战力目标已定；实际胜率要等 B 的扫描 |
| 地形要复杂 | §9：40 种地形，视线、顶层、黑暗、洞穴、事件改地形、击杀开门、路线时效，8 种天时，最大 12×7；第一卷已画的 38 张图用到了 38 种字符，B 新画的沙漠图再补上水井 | 墓穴、水井两种字符在第一卷用得少 |
| 每个战役都得有世界地图（拿破仑征服、海底两万里都要有） | 四段每一章都有一张图：主干 8、鹰飞 6、远洋 4、伊夫堡 5（第一卷开 15 张），底图是真实地理加局部手绘 | 局部图在画师出图之前是代码画的占位 |
| 开始跟随拿破仑，之后三个分支：继续征服 / 海底两万里 / 基督山伯爵 | §4：主干 8 章 → `elba_1815` → 三条分支；门槛由勋章、近卫誓言、法利亚的半封信、法老号决定；远洋保底 | 鹰飞和伊夫堡第一卷只开头一两章（收在卷终） |
| 积累 + 战役两段，中间是随机剧情，每条分支几个固定结局 | 每张图都分积累段和战役段；随机槽 ≥ 30%，三层事件池；远洋 4 个固定结局加默认；鹰飞 3 加默认、伊夫堡 3 加默认（第二卷），第一卷各有 3 种和 2 种卷终 | 鹰飞和伊夫堡的正式结局要第二卷才打得到 |
| 排兵布阵、回合制、只靠脑子、像明日方舟 | 战斗内核仍然没有随机数（天时和补兵进场时定），地形和标签只加约束不加运气 | — |
| 每一仗比上一仗难；输了触发大命运 | §8.2；大命运原样保留，另加段专属项（随驾流放、最后的方阵、伯爵赎人、紧急下潜、35 号牢房） | — |
| 主角可以上场，换更多士气和奖赏，但可能死 | 现有机制原样；主角兵力随 L 增长；`arrest` 让主角会被俘 | — |
| 伙伴只有一条命，戏在派谁上 | 28 人总表；名额按等级；宿命之地；`available_from`；跨段带过去的伙伴死了就是死了 | 留守和名羁绊推到第二卷（C17） |
| 手牌、几种币、大富翁式的小道具 | §7.3：行军手牌和骰子、四种币、驿站印、兵站地产和成套加成、过路费、对手、8 张道具的地图效果、营令三色旗的地图效果 | — |
| 明日方舟式的羁绊 | 一套 `napoleon`：19 条，全用现成效果 | 名羁绊第二卷 |
| 避免阶段单调交替 | R2、R5、R6；远洋四场纯文戏；军议、野营夜、插曲五种轮换；长仗后接轻节点 | — |
| 只用公有领域原著，不借现代改编 | §13.2 | — |
