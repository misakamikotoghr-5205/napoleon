# T03 小镇前端：走动、门、时钟、特写、柜台衔接

- **执行者**：Claude
- **依赖**：合同即可开工；T02 地图/美术到位前先用 `docs/town/mockup_src/assets` 和一张手写小地图占位，T02 合并后切换。
- **分支**：`town/T03-frontend`
- **状态**：已完成，待评审（Claude，2026-10-11；分支 `town/T03-frontend`，本地提交未推送）

## 目标
做出“小镇模式”的可玩外壳：标题→小镇；主角在小镇和当铺内部走动（星露谷手感）；进当铺能走到柜台后接客，交易切回现有柜台特写；进其他店切侧视特写；时钟、宵禁、睡觉、昼夜色调、HUD。

## 必读
1. `docs/handoff/TOWN_INTERFACES.md` §0、§2、§3、§4、§6、§8、§9、§10
2. `docs/town/research/repo_ui_art.md`（`main.gd` 结构、对白框、柜台视图、截图方法）
3. `docs/town/mockups/A1_town.png`、`A2_pawnshop_interior_topdown.png`、`B2_ricehall_sideview.png`

## 要做的事
- [ ] `scripts/town/town_game.gd`（合同 §6.2 全部接口）、`world_view.gd`（读地图 JSON 建 TileMapLayer、Y 排序、屋顶遮挡、相机限界、昼夜 CanvasModulate＋灯笼 PointLight2D）、`player.gd`（CharacterBody2D，四向走、跑、交互）、`walker.gd`（NPC 沿路网走到日程地点）、`shop_view.gd`、`hud.gd`。
- [ ] `main.gd`：标题“开张”进小镇模式；`--legacy` 走旧版；新增 `--town`、`--autoplay=town_*` 参数；模式切换时隐藏/显示现有柜台层。
- [ ] 柜台衔接：客人到 `customer_spot` → 主角在 `counter_spot` 按 E → 现有柜台特写跑会话 → 回当铺内部。
- [ ] 人物气泡（小镇里头顶）、头像对话框（特写里）、交互发光提示一次后淡出。
- [ ] 自动试玩 `town_fair`：每天守柜台、按需去米行买米、付账、睡觉；无界面跑 3 天无软锁。
- [ ] 截图脚本：小镇白天/黄昏/夜、当铺内部有客人、进米行特写、柜台交易中。
- [ ] 测试：`scripts/tests/town_ui_*.gd`（无头实例化 Main，走到门、进门、出门、接客、睡觉、换天）。

## 只能改这些文件
`scripts/town/**`、`scenes/Town*.tscn`、`scripts/ui/main.gd`（只加模式与入口）、`scripts/tests/town_ui_*.gd`、`scripts/tests/autoplayer.gd`（只加 town 策略）、`tools/run_tests.sh`（只追加）。

## 验收标准
- 旧 63 项 + 新增全绿；截图附在 PR；Windows 导出可玩（`export_presets.cfg` 已有）。

## 回报（执行者填写）
- 分支 / PR：`town/T03-frontend`（从 `claude/festive-ride-vud32a` 切出；未推送，等编排开 PR）
- 做了什么：`scripts/town/**`（TownGame 模式与钟、WorldView 320×180 ×4 + TileMapLayer + Y 排序 + 屋檐 + 昼夜 + 灯笼光、Player 物理走动、Walker/Crowd/Visitors、ShopView、HUD、告示/日结/家用簿/货架/暂停/设置弹窗、MusicCues、TownBot 自动试玩）；`main.gd` 只加 mode 切换、小镇入口（开张/继续/设置/退出、`--town`、`--autoplay=town_*`、`--skip-prologue`、`--clock`、`--fast`、`--days`）和返回标题的拆除；`autoplayer.gd` 加 `town_fair` 策略。
- 测试：`tools/run_tests.sh` 全绿（旧 78 项 + T03 九项：走动/商店/柜台/存档/生活/暂停菜单/音乐 7 个界面测试 + 2 个种子的 town_fair 自动试玩）。
- 截图：`screenshots/v04_*.png`（告示、白天街景、黄昏、当铺里有客人、米行特写、柜台交易、暂停菜单、设置、标题）。
- 数据/合同缺口（写在这里交编排）：
  1. `data/town/maps/town.json` 的 `doors[].at` 与建筑图上的门位置对不上（当铺差 2 格、码头棚差 2 格、茶馆差 1 格）。前端改用 manifest 里的 `door` 矩形算门的位置，`spawns.from_pawnshop` 不再用。
  2. `data/town/shops/*.json` 的 `pay_bills.payee`（“维持会”“保公所”）与 `town_pack.json` 里账单的 payee（“维持会公账”“保长”）不一致，按 payee 筛会筛不到账。前端改按 `building` 列出这家店名下全部到期的账。
  3. 柴炭、灯油只有导演能卖（`buy_fuel/buy_oil`，在米行），店铺配置里没有对应动作。前端在米行菜单里补了两项。
  4. `data/story/town_day3_zhao.json` 里 `str(flag('zhao_pawn')) == '300' or flag('zhao_pawn') == 'generous'`：flag 是数字 300 时 `or` 右边会报 “Invalid operands”（Expression 不短路），日志里出现 ERROR 且分支走错。`town_fair` 在现金不足 400 时拒收赵老三来避开它。
  5. `player_act("curfew_break")` 默认 `building` 是 `"street"`，而 `town_pack.json` 里宵禁规则的 building 是 `"桥头街"`，不传 building 就匹配不上规则；前端显式传了 `"桥头街"`。
  6. `art/portraits/` 里 T02 新增的立绘（wu、ruhua、postman、stranger_*）带不透明底色，旧立绘是透明底；店铺特写里前端按边缘泛洪抠掉了底色，柜台层（counter_view）里陌生人立绘仍带底色。
  7. 当铺内部（T02b 返工中）：前端全部按 JSON 的点位（`counter_spot/customer_spot/shelf/bed/exit/...`）和 manifest 的 footprint 走，不写死坐标；返工合并后若出口/柜台位置变化无需改代码。
- 遗留 / 没做：鼠标点击走路（可选项）；`appraise` 动作没有店铺用到，只做了占位提示；陌生人会话里的“同来的人”只有客人本人的走动图。
