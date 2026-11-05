# 德厚当 v0.4 小镇版 —— 接口合同（所有执行者必须遵守）

> 维护人：Claude（编排）。改本文件要在 PR 里单独说明并让主创点头。
> 设计依据：`docs/town/DESIGN_v04_town.md`（玩法）＋ `docs/town/research/*.md`（调研）。
> 主创已定：**画风 = A、B 混合**——小镇俯视可走动；**当铺内部俯视可走动**，交易切回现有柜台特写；**其他店进门切侧视特写**（320×180 背景＋立绘＋对白/菜单）。见 `docs/town/mockups/`。
> 标【原型默认】的数字都只是起步值，可以调，但要写在数据里，不许写死在代码里。

---

## 0. 总原则

1. **旧版不动、新版并存。** 现有线性版（序章→第二晚→德字第一九六号）和它的 63 项测试保持全绿。新增“小镇模式”是标题画面的默认入口；旧版用命令行 `--legacy` 进入（测试用）。改 `scripts/core/*` 只能做**向后兼容**的扩展（新增函数、可选参数、`if town != null` 分支）。
2. **确定性。** 模拟里禁止 `randf()/randi()/RandomNumberGenerator`，一律用 `JevRng.draw(seed, domain, key)`（见 §5.1）。纯视觉的随机（灰尘粒子）除外。
3. **玩家看不到的永远看不到**：概率、好感、人格标签、底价、未来随机结果、轮盘权重。开发者日志单独放（§9）。
4. **不准**：独立百货进货、无限涨租逼人犯罪、显示好感条、按好感解锁机构、一次决定反复重摇（详见 `docs/town/research/gamejev_design.md` §6）。
5. **测试红线**：`tools/run_tests.sh` 里任何 `SCRIPT ERROR / ERROR: / WARNING: / Parse Error` 都算失败。新代码不许产生 warning。
6. **新中文文字**：GB2312 简体字已在字体子集里，放心用；繁体/生僻字/书法标题字要跑 `python3 tools/build_fonts.py`（需要 fonttools 与源字体，见 `docs/town/research/repo_ui_art.md` §3）。新增的数据目录 `data/town/` 要加进 `scripts/tests/validate_data.gd::_glyphs()` 的检查范围。

---

## 1. 目录与归属（谁能改什么）

| 路径 | 内容 | 归属任务 |
|---|---|---|
| `scripts/sim/*.gd` | GameJev 生成器移植（纯逻辑，无界面） | T01 |
| `data/town/town_pack.json` | 压力、轮盘、建筑、NPC 日程、陌生人、开销、流言、规范、机构 | T01（建）→ T07（调数值） |
| `data/town/item_templates.json` | 随机当物模板 | T01 |
| `data/town/storylets.json` | 主线故事卡（日期窗口＋条件） | T04 |
| `scripts/tests/test_sim_*.gd` | 生成器无头测试 | T01 |
| `tools/art/town/*.py`、`art/town/**` | 小镇美术生成器与产出 | T02 |
| `art/portraits/<新人物>.png` | 新增立绘（不改旧的） | T02 |
| `data/town/maps/*.json` | 地图（瓦片、物件、门、碰撞、路点） | T02 |
| `art/town/manifest.json` | 美术清单（尺寸、锚点、帧） | T02 |
| `scripts/town/*.gd`、`scenes/Town*.tscn` | 小镇前端（地图渲染、走动、门、HUD、特写、昼夜） | T03 |
| `scripts/ui/main.gd` | 只允许 T03 加“小镇模式”入口与模式切换；其余保持 | T03 |
| `data/town/shops/*.json` | 各店特写配置与动作菜单 | T05 |
| `data/story/town_*.json`、`data/sessions/gen_*` 生成规则 | 小镇主线脚本、生成会话 | T04 |
| `scripts/core/*.gd` | 只做向后兼容扩展（存档、town 钩子） | T01（world/ledger 钩子）、T04（存档、director 拆分） |
| `scripts/tests/town_*.gd`、`tools/run_tests.sh` | 小镇测试；**每个任务只追加自己的行** | 各任务 |
| `docs/handoff/*` | 交接文件 | 编排（各任务只改自己卡片的“状态/回报”栏） |

两个任务同时改同一个文件 = 冲突。遇到必须跨界的改动，先在自己的任务卡“回报”栏写清楚，交给编排处理。

---

## 2. 画面规格（T02 产出、T03 消费；也是日后买素材/米画师定制的替换规格）

| 项目 | 规格 |
|---|---|
| 逻辑分辨率 | **320×180**，整数放大 ×4 到 1280×720（与现有柜台一致）。SubViewport 320×180 + SubViewportContainer `stretch_shrink=4` 或等效方案，像素对齐 |
| 调色板 | `data/palette.json` 的 32 色为主；小镇允许追加 ≤16 色（绿、水色、砖色），追加的写进 `art/town/manifest.json` 的 `palette_extra` |
| 光源 | 左上（小镇与室内统一）；1px 深色描边；人物与物件脚下有投影 |
| 地面瓦片 | 16×16，打成图集 `art/town/tiles/<set>.png`（宽 256），`manifest.tiles.<set>` 给出每个瓦片 id → 格子坐标、是否可走、是否水面 |
| 建筑 | 整张精灵 `art/town/buildings/<building_id>.png`，3/4 俯视；`manifest.buildings.<id>` 给 `size`、`door`（门在图内的矩形，16×24 左右）、`footprint`（碰撞矩形）、`roof_split_y`（这条线以上画在人物前面，实现走到屋檐后面），可选 `variants`: `{"locked": "..._locked.png", "night": "..._night.png"}` |
| 道具 | `art/town/props/<id>.png`，`manifest.props.<id>` 给 `anchor`（脚点）与 `footprint`。**`footprint` 是挡住主角脚的实心范围，要盖住贴图在地上的真实占地**：柜台、长凳、床、衣架、后门洞整块实心（不是脚下一小块），只在设计上要留的口子（柜台的腰门那一格）留空。写在 `tools/art/town/prop_meta.json`，`build_all.py` 抄进 manifest；`gen_maps.py` 里的 `_check_collision` 会验“柜台带除腰门外处处挡脚、所有站位站得下走得到” |
| 行走人物 | **16×32 一帧，4 方向 × 4 帧**，表 64×128：行 0 下、1 左、2 右、3 上；帧 0 站、1 迈左、2 站、3 迈右。文件 `art/town/chars/<npc_id>.png`；脚点 (8, 30) |
| 立绘 | 48×64（与现有一致），`art/portraits/<npc_id>.png`；新增：`ruhua`（主角）、`wu`（裕丰米行吴掌柜）、`postman`（邮电代办所）、陌生人原型若干（`stranger_refugee` 等） |
| 店内特写背景 | **320×180**，`art/town/shops/<building_id>_bg.png`（可选 `_dusk`/`_night`），掌柜立绘站位写在 `manifest.shops.<id>.keeper_at` |
| 当铺内部 | 俯视可走，瓦片集 `art/town/tiles/interior.png` + 家具道具；地图 `data/town/maps/pawnshop.json` |
| 界面 | 像素框体 `art/town/ui/*.png`（头像对话框、时钟面板、告示纸、按键提示），9-slice 边距写进 manifest |

`art/town/manifest.json` 结构：
```json
{ "version": 1, "tile": 16, "palette_extra": ["#..."],
  "tiles": {"town": {"image": "art/town/tiles/town.png", "ids": {"road_0": {"at": [0,0], "walk": true}, "water_0": {"at": [3,2], "walk": false, "water": true}}}},
  "buildings": {"pawnshop": {"image": "...", "size": [112,96], "door": [48,72,16,24], "footprint": [0,56,112,40], "roof_split_y": 40, "variants": {}}},
  "props": {"willow": {"image": "...", "anchor": [16,46], "footprint": [12,40,8,6]}},
  "chars": {"ruhua": {"image": "art/town/chars/ruhua.png", "frame": [16,32], "foot": [8,30]}},
  "shops": {"ricehall": {"bg": "art/town/shops/ricehall_bg.png", "keeper": "wu", "keeper_at": [150,40]}},
  "ui": {"dialog_frame": {"image": "...", "nine": [6,6,6,6]}} }
```

---

## 3. 地图格式 `data/town/maps/<map_id>.json`（T02 产出）

```json
{ "id": "town", "size": [60, 34], "tile": 16, "tileset": "town",
  "layers": { "ground": ["<60 个瓦片 id 用空格分隔的一行>", "..."],   // 34 行
              "deco":   ["... 用 . 表示空 ..."] },
  "objects": [ {"kind": "building", "id": "pawnshop", "at": [8, 6]},          // 以瓦片为单位的左上角
               {"kind": "prop", "id": "willow", "at": [20, 20]} ],
  "doors":   [ {"building": "pawnshop", "at": [10, 11], "to_map": "pawnshop", "to_spawn": "front_door"},
               {"building": "ricehall", "at": [24, 11], "closeup": "ricehall"} ],   // 非当铺的门 → 特写
  "spawns":  {"wake": [12, 12], "from_pawnshop": [10, 12], "edge_east": [59, 18], "dock": [30, 30]},
  "waypoints": {"nodes": {"p_door": [10,12], "bridge_w": [40,18], "...": [0,0]},
                "edges": [["p_door", "bridge_w"]]},              // NPC 走路用的路网（瓦片坐标）
  "places": {"桥头街": ["street_a", "street_b"], "码头": ["dock"], "德厚当": ["p_door"]},  // 日程地点 → 路点
  "hints": [ {"at": [9, 10], "text": "告示墙", "once": true} ] }
```
当铺内部 `pawnshop.json` 额外要有：`"counter_spot"`（主角站这儿就是“在柜台后”）、`"customer_spot"`（客人等候点，可多个）、`"shelf"`（满当货架的格子范围）、`"bed"`、`"backdoor"`、`"lamp"`、`"telegraph"`、`"exit"`（回小镇）。

还要有 `"interact"`（像素坐标，前端按它出交互提示，见 §6.3）：`{"counter"|"bed"|"lamp"|"telegraph"|"backdoor": {"stand": [x,y] 主角站哪儿算在它旁边（脚点）, "radius": 横向多远以内出提示（纵向固定上下 14 像素，`TownMap.reach_dist`：柜台后的走道只有脚线 y 72–83 这么宽，走在哪一行都要有提示）, "anchor": [x,y] 提示指着的物件}, "shelf": {"rect": [x,y,w,h] 一整面墙, "anchor": …}}`。数字取自贴图（蜡烛、带铜键的电报箱都画在柜台上；床靠左墙、后门洞在最右一格，都不可走，所以站在它们旁边）。换了家具位置，要同时改这里和 `footprint`。

---

## 4. 时间

- 钟：分钟数 `minute`，一天从 **360（6:00）** 起；**1260（21:00）宵禁**；**1440（24:00）**强制入睡（昏睡，第二天体力差）。
- 时段（沿用 `World.SLOTS`）：清晨 360–539，上午 540–719，中午 720–899，下午 900–1079，傍晚 1080–1259，夜 1260+。
- 流速【原型默认】：1 游戏分钟 = 0.7 秒；对话、柜台交易、看账、菜单打开时**暂停**。
- T03 的 `TownGame` 是时钟的唯一主人；每次分钟变化调用 `town_sim.set_minute(m)`，并把 `world.day / world.slot` 同步过去。
- 一天结束：`睡觉` → 夜间（沿用现有夜间菜单，T04 改成在当铺里点油灯触发）→ `town_sim.end_day()` → 存档 → 下一天 `town_sim.start_day()`。

---

## 5. 生成器（T01）

### 5.1 随机数
直接用原型 `docs/town/prototype/jev_rng.gd`（已与 Python 版逐位一致）。键只含整数和字符串；JSON 读回的数字要 `int()`；遍历字典改状态时按键排序。

### 5.2 `data/town/town_pack.json`
以原型 `docs/town/prototype/town_pack.json` 为起点，字段说明见 `docs/town/research/gamejev_code.md` §5.3。在原型基础上**必须补上**：
- `buildings.<id>`: `name`、`kind`（`"walkable"` 只有 pawnshop / `"closeup"` / `"locked_visible"`）、`hours`（`[开, 关]` 分钟，可按星期覆盖）、`keeper`（NPC id）、`unlock`（条件）、`news`（开门时的镇上消息）、`map_object`（地图上的建筑 id）。本版建筑：`pawnshop` `teahouse` `ricehall` `pharmacy`（济生堂）`baogong`（保公所/维持会）`post`（邮电代办所）`market`（集市，五天一集，街上的摊）`police`（警察所，封条可见）`dock`（码头）`sunfu`（孙府，门可见不可进）。
- `npcs.<id>`：从 `data/cast.json` 迁移所有人物；`schedule` 用**地点名**（与地图 `places` 对应），支持 `default` / `weekday:N` / `weather:雨` / `day:N` 覆盖；`visit` 倾向；`links` 社交边（取自 `cast.json.edges`）。
- `living_costs`：按设计稿 §4 的九类账（伙食随米价、柴炭灯油随季节天气、药按生病、人情按请帖、摊派按维持会、房捐按月、良民证、突发、周转）。每条：`id label period base scale jitter payee building when`。
- `difficulty`：`太平年 / 常年 / 乱世` 三套轮盘节奏与开销系数。
- `spine`：主干日期（例：`{"day": 22, "id": "weixin_gov", "effects": [{"op":"unlock","building":"police"}]}`）。
- 效果 op 白名单：`weather, pressure_add, news, flag_today, flag_set, bill, rumor, spawn_visit, npc_feel, institution, unlock, item_drop, invitation`。

### 5.3 `TownSim` 接口（`scripts/sim/town_sim.gd`，`class_name TownSim extends RefCounted`）
```gdscript
signal news(entry)                    # {day, minute, text, via, source:"seen"|"heard"|"inferred", conf}
func setup(pack: Dictionary, seed: int, world = null) -> void
    # world = scripts/core/world.gd 实例；为 null 时可纯模拟（测试用）。
    # 有 world 时：钱走 world.ledger；条件可读 world.flags/stats；笔记写 world.note()；
    # 每天把米价/药价/天气写回 world.rice_mod / world.med_mod / world.weather，让现有议价按当天行情走。
func start_day() -> Dictionary        # 早上流水线（顺序固定）：压力→外生轮盘→内生轮盘→建筑卡组→feeds→解锁→当天账单→来访计划
                                      # 返回 DayPlan: {day, weekday, weather, notice:{...}, bills:[...], unlocked_today:[...], visits:[...]}
func set_minute(m: int) -> Array      # 推进到 m，返回到期事件：
    # {"type":"visit_due","visit":{...}} / {"type":"npc_move","npc":id,"from":place,"to":place}
    # {"type":"slot_changed","slot":i} / {"type":"news","entry":{...}} / {"type":"bill_due","bill":{...}}
func end_day() -> Dictionary          # 合同/借据到期、压力衰减、没付的账 → 后果；返回当日小结（只含玩家可见内容）
func npc_location(npc_id: String, minute: int = -1) -> String     # 日程地点名
func npcs_at(place: String) -> Array
func building_state(b_id: String) -> String   # "locked" | "closed" | "open"
func bills() -> Array                 # [{id,label,amount,payee,building,due_day,status:"due"|"paid"|"overdue"|"waived"}]
func pay_bill(bill_id: String, amount: int, request_id: String) -> Dictionary   # 走 world.ledger.transfer，幂等
func visits_today() -> Array          # [{id, who, intent, minute, patience_min, companions:[ids], session:{...会话规格}, storylet:""}]
func visit_result(visit_id: String, outcome: Dictionary) -> void  # 柜台结果回写（成交/拒绝/没等到）
func visit_missed(visit_id: String) -> void                       # 玩家不在柜台、客人走了
func player_act(act: String, args: Dictionary) -> Dictionary      # 收赃、举报、送礼……走规范/影响规则
func hear(npc_id: String) -> Array    # 玩家和某人说话时听到的流言（只交付已送达的）
func notice() -> Dictionary           # 早上告示：{weather, prices:{rice:73,...}, headline, invitations:[...], market_day:bool}
func price(category: String) -> int   # 今天公开牌价（玩家可见）
func dev_log() -> Array               # 全知日志（含概率），只给开发面板
func to_dict() -> Dictionary
func from_dict(d: Dictionary) -> void # 存档读档必须与连续运行逐位一致
```
**会话规格**（`visits[].session`）与 `data/sessions/*.json` 同一结构（`mode` 为 `buy`/`sell`/`pawn`，含 `items`/`stock`、`ask`、`floor`、`est`、`lines` 等），由 `ItemGen` 按 `data/town/item_templates.json` 生成：品级、成色、真假、来路（赃物）、稀有度（伪随机保底，前期少后期多）。生成的会话 id 以 `gen_d<day>_<n>` 开头。主线来访用 `storylet` 字段指向现有 `data/sessions/<id>.json`。

### 5.4 与现有核心的钩子（T01 负责，向后兼容）
- `world.gd` 增加 `var town = null`。`town != null` 时：`advance_slot()` 不再跑旧的 `_wheel/_offscreen_life`；`plant_rumor/share_rumors` 转给 `town`。`town == null` 时行为完全不变（旧测试保证）。
- `ledger.gd` 增加 `renew(tid, day, fee)`（续当）与 `to_dict/from_dict`。

---

## 6. 小镇前端（T03）

### 6.1 节点结构
```
Main (Control, scripts/ui/main.gd)       ← 现有；新增 mode: "title" | "town" | "closeup" | "counter" | "night" | "legacy"
 ├─ TownGame (Node, scripts/town/town_game.gd)    ← 持有 World / Director / TownSim / 时钟；模式切换
 │   ├─ WorldView (SubViewportContainer ×4)       ← scripts/town/world_view.gd，加载 data/town/maps/<id>.json
 │   │    └─ SubViewport 320×180 → TileMapLayer(ground, deco) + YSort(建筑/道具/Player/Walkers) + Camera2D(限界)
 │   ├─ ShopView (Control)                        ← scripts/town/shop_view.gd，320×180 背景 ×4 + 立绘 + 动作菜单
 │   ├─ Hud (Control)                             ← 时钟面板、钱、体力（玩家自己的身体状态可见）、交互提示
 │   └─ Panels                                    ← 晨间告示、家用簿、万年历（复用 main.gd 已有的面板风格）
 └─ （现有）CounterView / DialogueBox / Sidebar / InspectPanel / TicketPanel …   ← 柜台交易仍走这些
```

### 6.2 `TownGame` 对外接口（T04/T05/测试都靠它）
```gdscript
signal mode_changed(mode: String)
signal entered(map_or_shop: String)
func new_game(seed: int, difficulty: String = "常年") -> void
func load_game(path: String) -> bool
func save_game(path: String) -> void
func goto(target: String) -> void       # 测试/自动试玩：走到地点（路网寻路），或瞬移（--fast）
func interact(target_id: String) -> void
func open_shop(building_id: String) -> void
func start_counter(visit: Dictionary) -> void   # 进入柜台特写，调用 director 跑会话，结束回到当铺内部
func sleep() -> void
var minute: int
var map_id: String
var paused: bool
```

### 6.3 交互规则
- 当铺里，主角站在 `counter_spot` 且有客人在 `customer_spot` 等 → 按 E（或点击客人）开始交易 → 切现有柜台特写，`await director.run_session(spec)`（T04 在 director 里加这个可接受字典规格的入口）。站在柜台后不动半秒也会自动开始；**站在柜台前面、客人身边也可以直接按 E / 点客人招呼他**（试玩反馈：出门再进门后主角在门口，客人就在身边，不该还得绕去腰门）。当铺里等着的客人必须都有看得见、站定的身体：`Visitors.ensure_bodies()` 每个游戏分钟（`poll` 末尾）、每次进当铺、每次回到走动状态（`_set_mode("town")`：关店铺特写、办完柜台、睡醒）都检查，丢了（客人到的时候主角正看着店铺特写或在柜台页里、换图、读档……）就在等候点补回来；这是试玩里“出门再进门客人就接待不了”的根因（特写/柜台期间到的客人从来没有身体）。**以后做“去哪儿”之类直接从当铺跳进店铺特写的入口，不用额外做什么——特写期间到的客人回来时都在**；站定的客人 24 像素内按 E / 点他都能招呼（站到出门那一格时轮到“出门”）。
- **交互提示**（`TownGame._find_near`）：当铺里按“谁近谁先”选——客人优先，床/油灯/电报机/后门各有自己的站位和半径，货架（一整面墙）最后；站在两个交互点交界处会粘住上一个，不来回跳。提示条浮在被指的物件/客人头顶/门楣上方，带 ▼ 指着它，夹在屏幕里、不压主角、不压右上角 HUD（主角站到 HUD 底下时 HUD 变淡）；`overlay.set_prompt(text, anchor, avoid)`。
- **电报机**：规则只有一处，`TownGame.telegraph_state()`：没学会（序章里陈叔叔教了才算）→“还不会用”；宵禁（21:00）前 →“白天用电报太扎眼，等打烊以后”；头两夜（`free_night_from` 之前）→ 夜里的事是剧情定好的；之后 → 睡前在“夜里的事”里选“发电报”。当铺里的电报箱、柜台特写里点电报机、夜里选单里灰着的“发电报”都说这一套话。
- **按键**：E / 空格 / 回车 推进对白、关弹窗（告示、日结、家用簿、货架……）；**Esc 全局可用（标题除外）**：先关最上面能关的东西（账簿/档案/药典册子、放大镜验货、万年历、“只卖一件”、店里的子菜单），什么都没开就开暂停菜单（序章、柜台交易、店铺特写、夜里、街上对话都一样；存档在不空闲时灰着并说明原因）。对白**不**用 Esc 推进（legacy 版保持老样子，防卡死测试靠它）。暂停菜单开着时整棵场景树停住（`get_tree().paused`）：钟、打字机、行人、淡入淡出、自动试玩的计时器都冻结，只有弹窗层（`process_mode = ALWAYS`）还在动。弹窗层挂在 `Main` 最上面，所以柜台层显示时暂停菜单也压得住它。
- 客人等待 `patience_min` 分钟（隐藏值）没人接待就走：`town_sim.visit_missed()`。主线客人（`storylet` 非空）等到宵禁前。
- 小镇里靠近 NPC 按 E：头顶气泡寒暄一句；如果对方有流言，`town_sim.hear()` 交付并写进档案簿。
- 进非当铺的门：`ShopView` 按 `data/town/shops/<id>.json`（T05）显示菜单。
- 靠近可互动物件第一次时发光提示，随后淡出（docx 第 4 条）。
- 21:00 后在街上：巡逻遭遇风险（`player_act("curfew_break")`）；24:00 强制睡觉。

### 6.4 只守铺子：过路客人与门口吆喝（v0.4.2，`[shop-only]`）

设计见 `docs/town/DESIGN_walkin.md`。只在只守铺子版开（`data/town/walkin.json` 的 `enabled_shop_only`；`--shop-only=0` 的小镇版 `enabled_town=false`，门口、货架、夜里都不变）。

**模块**：`scripts/core/walkin.gd`（`RefCounted`，导演持有一份：`director.walkin()`）。不新增 World / Director 的属性（存档按形状校验），状态全在 `director.vars["town"]["walkin"]`：
```
{day, slots: [{at, minute, status: "pending"|"in"|"skipped"|"passed", called: ""|"pawn"|"buy", id}], calls, skipped, quiet: ""|"calls_only"|"early"|"boycott"}
```
**钩子**（都标 `# [shop-only]`）：
- `director.town_start_day()` 末尾调 `walkin().on_day_start()`：排今天的时刻表（`JevRng.draw(seed, "walkin_gap", [day, k])`）；同一天再调一次（读档续玩）不重排；读的是旧版本的白天存档时，已经过了钟点的几位记作 skipped。第 1 天（`calls_from_day` ≤ 天 < `from_day`）照排，`quiet="calls_only"`：表上的人到点不自己进门（记 `passed`），只有吆喝叫得来，且要等 `world.flags.town_first_open`（哥哥第一天的话交代完）；`calls_from_day` 以前 `quiet="early"`；断客日（`protect().st().boycott_day == day`）`quiet="boycott"`，不排。
- `town_game.advance_minute()` 在 `visitors.poll()` 之前调 `walkin().tick()`：到点的一位如果店里已经站着 `max_waiting` 位（`waiting_source` = `visitors.waiting()`，`bind()` 时接上；没接上就按导演的来访名单数）就记 skipped（吆喝叫来的人除外：照样进门），不然像保护费那样把一份完整的来访追加进 `world.town.s["visits"]`：`id = walkin_d<天>_<序号>`、`who = walkin:<原型>#d<天>_<序号>`、`walkin: true`、`called`、`archetype`、`session`（要当 / 要卖的走 `ItemGen.session`，要买的走 `buyer_session`），会话用 `world.town._register_session` 登记（账户、`world.npcs`、cast）。返回这一刻进门的来访 ID。
- `director.run_town_visit()`：sell 模式的来访开谈之前调 `walkin().before_counter(visit)`——过路买主要的那件不在架上了（卖了、被胡二拿走了）改挑一件他买得起的，挑不到就说一句走人（`result = "nostock"`）；黎明排的自然买主要的都不在了也说一句走人。`_accept` 的 sell 分支成交前再查一遍货还是自己的、没押给人的架上货，成交后 `world.note("账目", …)`。
- `director.night_menu()`：只守铺子不出现「夜卖」；动作说明用 `ShopOnly.night_desc(id)` 盖过 `night.json`（整理库房不写“+5%”）。`day_summary` 的库存、`_night_tidy` 的提问和那句话、`main._options_for("pick_item")` 只守铺子不写市价，写 `walkin().record_of(iid)`。

**接口**：
```gdscript
director.town_action("walkin_call", {kind: "pawn"|"buy", request_id?})
    # 成：{ok: true, kind, n, line, minutes}——把今天时刻表上下一位还没到的人提前到 call_delay 分钟后，并按 kind 定他的来意
    # 不成：{ok: false, error, line}，error ∈ unknown_call / walkin_off / too_late / boycott / quiet_day / not_open / shop_full / no_stock / no_buyer / no_walkers
    # shop_full 数的是店里站着的加上吆喝叫来、还在路上的；no_buyer：架上没一样是过路买主原型看得上、买得起的
    # 同一个 request_id 只算一回（导演外层去重）
walkin().call_check(kind) -> Dictionary      # 同上的形状，不动任何状态（界面、引导用）
walkin().menu_options() -> Array             # [{id: "pawn"|"buy"|"cancel", label, enabled, note}]；架上没货时 buy 灰着，note = “架上没货”；没一样过路的人看得上，note = “过路的看不上”
walkin().door_label() -> String              # “门口吆喝”
walkin().active() / st() / tick() / waiting_now() / schedule(day)
walkin().shelf_rows() -> Array               # 货架（只看）：[{iid, name, category, condition, record}]，record 是玩家自己账上的数（当初收价 / 满当的当本 / 店里旧存），不写市价
walkin().record_of(iid) -> String            # 同 shelf_rows 的 record（夜里对账、整理库房挑货用）
walkin().shelf_text("hint"|"empty")
Walkin.is_walkin(visit) / Walkin.line(key, subs) / Walkin.summary_missed_line(n) / Walkin.sold_toast(name, price)      # 静态
```
**前端**（`scripts/town/town_game.gd`）：
- `_door_call_on()`：只守铺子且过路客人开着。这时通街那扇门的提示是 `walkin().door_label()`，`_find_near` 给门口的 `act` 是 `open_door_call()`——**只有按 E**（或 `interact()`）才开小窗；往门里走（`_door_dwell` → `_try_door`）仍是 `_shop_only_door()` 的一句守铺的话。
- `open_door_call()`：开 `scripts/town/walkin_call_panel.gd`（`modal.gd` 的子类，`_open_modal(p, false)`：钟停，不随自动试玩的弹窗自己关）。小窗：吆喝收当（1）/ 吆喝卖货（2，灰着时写“架上没货”）/ 算了（E；E、Esc、回车、空格都是算了）。`panel.choose(id)` 关窗后发 `chose(kind)`。
- `door_call(kind) -> Dictionary`：调 `town_action("walkin_call")`；成了主角头顶冒一句吆喝（`overlay.speak`）并 `spend_minutes(minutes)`，不成弹一句提示、不花时间。自动试玩（`town_bot.gd`）也走小窗：店里空了 30 游戏分钟、一天的保险时间没过六成、`call_check` 说能吆喝，就 `goto("door")` → `open_door_call()` → `choose()`（`call_check("buy")` 成就吆喝卖货，不然吆喝收当）。
- `goto("door")`：走到通街那扇门的里侧（站这儿按 E 是门口的事）。
- 自动试玩加 `--verbose` 时，每天日结弹窗出来、换天之前打三行账：`DAYSTAT`（钱匣、保护费、柜台接待、卖出、过路客人、吆喝、架上剩几件）/ `DAYVISIT`（按来意数人）/ `DAYFLOW`（钱匣进出按事由），字段见 `docs/town/walkin_balance.md`。
- 柜台上卖货（sell 模式）：只守铺子时算盘先拨到客人自己报的价（`sidebar.open_session`），“只卖一件”的小面板不写市价（`main._pick_single_sell`）——架上买来的假货不在柜台上露底。
- 货架面板（`shelf_panel.gd`）只守铺子只看（`walkin().shelf_rows()`），没有「卖掉」；日结（`summary_panel.gd`）把没等到的过路客人合成一行；`who_label` 给 `walkin:` 写“过路客”兜底；立绘、行走图用原型的 `stranger_<原型>`（没有这张图的原型借 `stranger_refugee`，`CounterView.STRANGER_FALLBACK`）。名字一律从这一局的 `world.db` 取（`main.db` 是属性：有 `world.db` 就返回它；侧栏、柜台悬停、账簿、档案簿同），生成的客人才不露 ID；档案簿“人物”跳过 `walkin:` / `stranger:`，末尾合成一行“过路客人：接待过 N 位”。`town_action("sell")` 这个无头接口保留（T04 的自动试玩和验收还在用），只守铺子的界面不再调它。

**数据**：`data/town/walkin.json`（`_doc` 逐项说明）：`from_day`、`calls_from_day`、`open_minute`、`last_minute`、`gap_range`、`max_waiting`、`patience_range`、`call_minutes`、`call_delay`、`call_until`、`intents`（自己进门的来意权重）、`calls`（吆喝招来的来意权重）、`buyer_offer` / `buyer_max`、`archetypes`（每个原型的来意、权重、`budget`、口味 `taste`、柜台上的 `buyer.intro/use/look/nostock`）、`lines`（给玩家看的所有字）、`shelf`。随机只用 `JevRng.draw(seed, 域, [天, 序号, …])`，域：`walkin_gap / walkin_intent / walkin_arch / walkin_patience / walkin_call_delay / walkin_pick / walkin_buyer_offer / walkin_buyer_max / walkin_talk`，不碰天气、米价、外生轮盘。**不改 `town_pack.json`**（`pack_hash` 会让旧存档失效）。

**告诉玩家**（规矩写在世界里）：`data/story/town_protect_intro.json` 里哥哥第一天多两句；`data/town/shop_only.json` 新增 `rule_text`（守铺时盖过 `rules.json` 的规矩页正文，`rules.gd` 的 `page()` 用）和 `step_text`（守铺时盖过 `onboarding.json` 的引导话，`guide.gd` 的 `_step_text()` 用）；`rules.json` 的 `help_shop_only` 管 F1；引导步骤 `walkin_call`（`onboarding.json`）用新的运行时标志 `walkin_call`（眼下吆喝有人应）和条件 `quiet_min`（店里空了多少游戏分钟），第 2 天起亮一次、指着门口。给玩家看的字里不许有耐心、机率、他最多肯出到多少这些隐藏的数（`rules.gd` 的 `FORBIDDEN`，`town_ui_rules` 也查 `rule_text` / `step_text` / `help_shop_only`）。

**测试**：`scripts/tests/test_walkin.gd`（真导演无头：时刻表确定、断客日 / 第 1 天 / 出门版没有、站满不进门、读档不重复、吆喝、买主挑货与改挑、外生隔离、货架只看、不夜卖）；`scripts/tests/town_ui_walkin.gd`（真 Main：门口提示、走进门口不开小窗、E 开 / E·Esc 关、吆喝花钟点、被叫的人进门站定能招呼、柜台上谈成货离架钱进匣有提示、货架面板只看、一整天自己进门不超员、日结合成一行、断客没人应、没货灰着、哥哥的话、规矩页和说明、引导）。

---

## 7. 店铺特写配置 `data/town/shops/<building_id>.json`（T05）

```json
{ "id": "ricehall", "bg": "art/town/shops/ricehall_bg.png", "keeper": "wu",
  "greeting": [{"when": "true", "text": "沈姑娘来啦。今儿粳米 {price_rice} 一斗。"}],
  "actions": [
    {"id": "buy_rice", "label": "买米", "kind": "buy", "category": "rice", "units": [1, 2, 5]},
    {"id": "credit", "label": "赊一斗", "kind": "script", "script": "town_rice_credit", "when": "stat('koubei') >= 45"},
    {"id": "ask_boat", "label": "问米船的事", "kind": "talk", "topic": "rice_boat"},
    {"id": "sell_rice", "label": "卖米给米行", "kind": "sell_to_shop", "categories": ["rice"]},
    {"id": "pay", "label": "付账", "kind": "pay_bills", "payee": "米行"},
    {"id": "leave", "label": "回头再说", "kind": "leave"} ] }
```
`kind` 白名单：`buy`（买生活用品，进家用库存）、`sell_to_shop`（把库房的东西卖给店家，走现有 session 的 sell 反向）、`pay_bills`、`talk`（流言/话题）、`script`（跑 director 脚本）、`appraise`（付费请人鉴定）、`letters`（取信）、`negotiate`（摊派议价，复用议价）、`leave`。

---

## 8. 存档

`user://town_save.json`：`{version, pack_hash, seed, day, minute, map_id, player_pos, town_sim, world, ledger, director_vars}`。只在睡觉后（新一天开始）自动存。读档后与连续运行一致（测试要验）。pack 的 hash 不一致就拒绝读档并提示。

---

## 9. 可见性白名单

玩家可见的数据只能从这些函数来：`notice() / bills() / price() / hear() / player_feed / ledger 的客观账 / world.notebook`。界面代码**不许**读 `dev_log()`、`npcs[*].persona`、`rel`、`visits[*].patience_min`、`session.floor`（真实底价）。开发面板用 `--dev` 打开，正式包不显示。

---

## 10. 测试与验收

```bash
# 准备 Godot 4.7（Linux 无头）
curl -L -o g.zip https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip && unzip g.zip
export GODOT=$PWD/Godot_v4.7-stable_linux.x86_64
tools/run_tests.sh                     # 全部测试（旧 63 项 + 新增）
# 截图（需要 Xvfb）
xvfb-run -a -s "-screen 0 1280x720x24" $GODOT --rendering-driver opengl3 --audio-driver Dummy --path . -- --town --autoplay=town_fair --shots=/绝对路径 --quit
```
每个任务必须：
1. 新增测试写进 `tools/run_tests.sh`（只追加），全部测试绿。
2. PR 描述写清：做了什么、怎么验证、截图（有界面的任务）、已知问题。
3. 不留空壳：只返回字符串/计数器的“系统”不算完成（主创原则）。

## 11. Git 流程

- 集成分支：`claude/festive-ride-vud32a`（以后合进 `main`）。
- 每个任务开分支 `town/T0X-<短名>`，从集成分支最新提交切出；完成后 PR 回集成分支。
- 提交信息写中文或英文都行，第一行说清改了什么。不要提交 `.godot/`、导出包、密钥。
- 做完在自己的任务卡“回报”栏写：分支名、PR 链接、测试结果、遗留问题。
