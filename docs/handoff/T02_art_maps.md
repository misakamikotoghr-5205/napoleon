# T02 小镇美术管线与地图

- **执行者**：Grok
- **依赖**：无（可以马上开始）
- **分支**：`town/T02-art-maps`
- **状态**：已合并进集成分支（2026-10-11）；T02b 当铺内部已按 A2 返工（2026-10-11，待合并）

## 目标
把示意图阶段写的 Python 像素美术生成器整理成仓库正式管线，产出小镇、当铺内部、各店特写背景、全部行走人物和新立绘，并做出两张可走的地图数据。**所有产出严格按合同 §2 的规格和文件名**——日后买素材或找米画师定制时，只换图不改代码。

## 必读
1. `docs/handoff/TOWN_INTERFACES.md` §1、§2、§3
2. `docs/town/mockups/`（主创已选：A1 小镇 + A2 当铺内部 + B2 店内侧视特写的组合）
3. `docs/town/mockup_src/`：示意图用的生成器（`pix.py`、`gen_tiles_props.py`、`gen_buildings.py`、`gen_chars.py`、`compose_A1.py`、`compose_A2.py`、`compose_B2.py`、`gen_B2_portraits.py`）和 `assets/README.md`。**从这里改起，不要从零画。**
4. `docs/town/research/repo_ui_art.md` §2（现有 `tools/art/pixlib.py`、调色板、尺寸约定）
5. `docs/town/research/repo_story.md` §2（人物外貌、谁住哪栋楼）

## 要做的事
- [ ] `tools/art/town/` 下的生成器（可以 import `tools/art/pixlib.py`），一条命令 `python3 tools/art/town/build_all.py` 重建全部小镇美术，并检查调色板（32 色 + manifest 里登记的追加色）。
- [ ] 瓦片集：小镇（石板路 ≥4 变体、泥地、草、河水 2 帧、河岸、码头石阶、石拱桥件）、当铺室内（木地板、墙、高柜台、货架、库房门、楼梯、床、油灯、电报箱）。
- [ ] 建筑（3/4 俯视，屋顶与墙分开以便 Y 排序遮挡）：`pawnshop teahouse ricehall pharmacy baogong post police(含 locked 变体：封条＋挂锁) sunfu dock_shed market_stall`，可选 `_night` 亮窗变体。招牌字直接画进图。
- [ ] 道具：柳树、灯笼柱、晾衣竿、米袋、木桶、长凳、船、猫、鸡、鸭、告示墙。
- [ ] 行走人物 64×128（4 方向 × 4 帧）：`ruhua brother chen xiaoding zhang wangshan li linsao zhouma zhao sunyoung ma guanjia wu postman` + 陌生人 `stranger_refugee stranger_peddler stranger_fence stranger_collector` + `patrol`（保安队巡逻）。用调色板换色做出路人变体 ≥6 个（`passerby_0..5`）。
- [ ] 新立绘 48×64（与 `art/portraits/` 现有风格一致）：`ruhua wu postman stranger_*`。
- [ ] 店内特写背景 320×180：`teahouse ricehall pharmacy baogong post market`（B2 已有米行稿可直接用），每张写清掌柜站位。
- [ ] UI 像素件：头像对话框框体、时钟面板、告示纸、按键提示、体力图标。
- [ ] `art/town/manifest.json`（合同 §2 格式）。
- [ ] 地图 `data/town/maps/town.json`（约 60×34 格：桥头街沿河、石拱桥、码头、告示墙、集市空地；所有建筑的门；路网 waypoints；`places` 对齐这些地点名：`德厚当 桥头街 茶馆 米行 济生堂 保公所 邮电局 码头 孙府 集市 镇外 家`）和 `data/town/maps/pawnshop.json`（合同 §3 要求的全部点位）。
- [ ] 预览：`tools/art/town/preview.py` 把地图按 ×2 拼成整图 `docs/town/previews/town_map.png`、`pawnshop_map.png`，以及人物表、背景合集，方便评审。
- [ ] 测试 `scripts/tests/test_town_assets.gd`（追加进 `run_tests.sh`）：manifest 里每个文件存在且尺寸正确；地图每个瓦片 id 在 tileset 里；每扇门可达（从 `wake` 出发 BFS 能走到）；每个 `places` 地点有路点。

## 只能改这些文件
`tools/art/town/**`、`art/town/**`、`art/portraits/`（只新增文件）、`data/town/maps/**`、`docs/town/previews/**`、`scripts/tests/test_town_assets.gd`、`tools/run_tests.sh`（只追加）。

## 注意
- 这批图是**临时美术**（AI 生成，上 Steam 前要换成买来的/定制的），所以重点是**规格对、文件名对、风格统一**，不追求终稿精度。
- 不要用 AI 绘图模型；用代码画（和示意图一样）。
- 新 PNG 第一次要让 Godot 导入：`$GODOT --headless --import`，把生成的 `.import` 文件一起提交（仓库惯例）。

## 验收标准
- `python3 tools/art/town/build_all.py` 可重复运行，输出一致
- `tools/run_tests.sh` 全绿
- PR 里附预览图

## 回报（执行者填写）
- 分支 / PR：`town/T02-art-maps` → `claude/festive-ride-vud32a`
- 测试结果：`test_town_assets.gd` 通过（manifest 尺寸、瓦片 id、从 wake 走到每扇门、places 都有路点）。原有数据校验与 63 项分支/全流程在同一工作区全绿。`python3 tools/art/town/build_all.py` 可重建。本沙箱里 `tools/run_tests.sh` 的 import 步会被 Godot 编辑器 debug adapter 的一行 `ERROR: Malformed message`（`debug_adapter_protocol.cpp`）染红，与本任务资源无关；游戏脚本本身退出码为 0。
- 遗留问题：这批是临时码绘美术，上 Steam 前要换购入/定制图，文件名与 manifest 已按合同 §2。`docs/town/mockup_src/pix.py` 的 `REPO` 从写死的 `/home/user/dehoudang` 改成相对仓库根，否则生成器在别的机器上读不到调色板（越界一行，见 PR）。调色板追加色 16 个写在 `art/town/manifest.json` 的 `palette_extra`，生成后量化到 32+16。警察所默认图是开着的门，地图上若要封条用 `variants.locked`。

## 编排评审（Claude，2026-10-11）
- **合并**：已并入 `claude/festive-ride-vud32a`，全测试绿。
- **必须改（返工，开新分支 `town/T02b-pawnshop-interior`）**：`data/town/maps/pawnshop.json` 与室内瓦片/家具离示意图 A2 差太远——现在是一大片空地板、一个小柜子。当铺是玩家待得最久的地方，请按 `docs/town/mockups/A2_pawnshop_interior_topdown.png` 重做：
  1. **高柜台横贯房间**，把屋子分成前后两半：前半是客人区（门口、长凳、等候点 `customer_spot` ×2–3），后半是掌柜区（`counter_spot` 在柜台后正中）。
  2. **后墙一整排货架**（满当货，摆满小件当物的像素图），`shelf` 指向这排货架前的格子；侧面库房门、通后门的过道、楼梯（上楼睡觉）、油灯、电报箱（藏在账箱里）、挂历、算盘账簿摆在柜台上。
  3. 地板减少花纹噪点（现在格子太碎），墙要有高度（3/4 视角下后墙至少 3 格高）。
  4. 房间缩到 20×12 格左右（一屏能看全，现在 22×16 有一半是空的）。
  5. 保持合同 §3 要求的全部点位名不变，`test_town_assets.gd` 继续通过。
- **建议改**：小镇北边和南边大片空草地可以收窄或放点人家/田埂；石拱桥现在是一条平的石阶，可以画出拱。

## T02b 回报（Grok，2026-10-11）
- 分支 / PR：`town/T02b-pawnshop-interior` → `claude/festive-ride-vud32a`
- 改了什么：当铺收到 20×12。后墙三格高（梁 / 灰墙 / 护墙板）。后墙一整排满当货架，中间是「德厚当」匾和财神龛，`shelf` 指货架前那一横条。高柜台从左柜到右墙，腰门留在东侧，把屋子分成前厅和掌柜区；`counter_spot` 在柜台后正中，`customer_spot` 三个在柜台南侧。柜台上有「当」字斗方、账簿、算盘、油灯；电报藏在右侧账箱里（盖掀开，能看见电键）。左侧楼梯和床，右侧库房门帘、通后门的过道。地板不再撒碎花，只留门口到柜台的一条走道。合同点位名没改。预览 `docs/town/previews/pawnshop_map.png`。
- 测试结果：`test_town_assets.gd` 通过（含 20×12、后墙三格、柜台横贯、三个等候点在掌柜位南侧）。`tools/run_tests.sh` 里 63 项并行、T01 五项、T04 十四天玩法全部通过。import 步仍会多打一行与资源无关的 `ERROR: Malformed message`（`debug_adapter_protocol.cpp`，退出码 0），和 T02 同一沙箱现象，脚本因此把整次判红。
- 遗留：仍是临时码绘。小镇空草地和石拱桥按评审「建议改」，这次没动。油灯和账箱画在柜台精灵上，`lamp` / `telegraph` 仍是合同里的点位。
