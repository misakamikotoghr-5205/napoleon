# T04 玩法与主线接入

- **执行者**：GPT
- **依赖**：T01（必须），T03（界面部分）
- **分支**：`town/T04-gameplay`
- **状态**：后端已合并（GPT / 2026-10-11；Claude 已集成 PR #4；T03 前端已随后合并）。T06 已评：不用改，见 [PR #4 评论](https://github.com/misakamikotoghr-5205/dehoudang/pull/4#issuecomment-6107811957)。

## 目标
把现有剧情拆进小镇（主创已定：保留主线），并补上让小镇“活”起来的玩法：卖满当货、活当续当、家用账、摊派议价、请帖人情、存档。

## 必读
1. `docs/handoff/TOWN_INTERFACES.md` 全文
2. `docs/town/DESIGN_v04_town.md` §2、§4、§5.4、§6、§7
3. `docs/town/research/repo_story.md`（人物、分支、伏笔，§5.3 列了第 3 天以后可直接用的伏笔）
4. `docs/town/research/repo_core.md` §2（剧情脚本格式）、§4.3（director 拆分方案）
5. `docs/town/research/gamejev_design.md` §1.4（活当规则：提前卖了义务不消失）、§4（压力规则）

## 要做的事
- [x] **director 拆分**（向后兼容）：抽出 `script_vm.gd` 与 op/hook 注册表；新增 `run_session(spec: Dictionary)` 接受运行时生成的会话规格。旧测试必须全绿。
- [x] **主线故事卡** `data/town/storylets.json`：序章原样保留（夜里在当铺）；第一天小丁/张护士/王山/李敬之、第二天林嫂/周妈/赵老三/孙少爷/马保长/哥哥告别 → 改成有时间窗口的来访；第一晚、第二晚的后门与电报 → 夜里在当铺触发；“德字第一九六号”在第二晚照旧，但**游戏继续**。第 3–14 天用现有伏笔排日程：第 4 天哥哥第一封信（邮电局开门）、第 5 天王山回来、第 7 天维持费与铺租、第 9 天王山借条到期、林嫂当期等。
- [x] **卖货**：当铺满当货架（标价、客人逛、单件买，价格以当天牌价为锚、人与人只差一点）；茶馆“找买主”；集市日估衣摊收货；卖给店家（米行收米、济生堂收药）。不许出现进货菜单。
- [x] **活当**：当期内可冒险先卖，合同和还原物义务保留；客人来赎时要买回或赔偿并有口碑后果；客人可请求续当（付息或拿新东西顶）。
- [x] **家用账**：伙食从家里米缸扣（米缸见底要去米行买或在茶馆吃）、柴炭灯油、摊派、房捐、良民证、人情（请帖提前 3–7 天，去或送礼或不去）、生病买药；体力（玩家自己的，可见）受饥寒与熬夜影响。
- [x] **摊派议价**：保公所里用现有议价系统跟马保长谈维持费。
- [x] **存档**：合同 §8；`world/ledger/director` 加 `to_dict/from_dict`。
- [x] 自动试玩策略 `town_fair / town_greedy / town_random`，无头跑完 14 天；分支计划至少 10 条（例：第一天全拒绝、全收赃、把林嫂的金簪提前卖掉、拖欠维持费……）断言不同结局。

## 只能改这些文件
`scripts/core/director.gd`（拆分）、新增 `scripts/core/script_vm.gd`、`scripts/core/save.gd`、`data/town/storylets.json`、`data/story/town_*.json`、`scripts/tests/town_play_*.gd`、`scripts/tests/plans_town.json`、`tools/run_tests.sh`（只追加）。动 `scripts/town/*` 前在回报栏说明，交编排协调。

## 验收标准
- 无头 14 天全流程（3 策略 × 5 种子）通过、账本不变量为空、全测试绿
- PR 写清：14 天里主线与生成器分别贡献了哪些事件

## 回报（执行者填写）
- 分支 / PR：`town/T04-gameplay`；[PR #4](https://github.com/misakamikotoghr-5205/dehoudang/pull/4)，与 [T01 #1](https://github.com/misakamikotoghr-5205/dehoudang/pull/1) 已由 Claude 合并到 `claude/festive-ride-vud32a`。
- 测试结果：Godot 4.7，在 Claude 最新集成提交 `755c201` 上加入 T07 最终数值后，`tools/run_tests.sh` 全绿（原 63 项并行 + 7 原专项 + 5 T01 模拟测试 + T04 全套 + T07 三难度/三策略烟测），T02 美术地图与 T05 六店配置的独立检查亦通过。T04 789 项检查、33 份运行报告：3 策略 × 5 种子 × 14 天，18 条分支计划，实际 594 次生成 Session、536 张作者故事卡；第 10 天中途 JSON 读档后续跑至第 14 天，全量快照逐位一致。包括版本/损坏档拒绝原子性、时间窗口、请求冲突/部分付款幂等、提前送礼与晚生成账单、防家用二次收费、混合原物满当后买回/赔偿。任何 SCRIPT ERROR/ERROR/WARNING 判失败。最终日志 `/tmp/tmp.lSdQnDRfYc`；资产/商店日志 `/tmp/dehoudang-integrated-assets.log`、`/tmp/dehoudang-integrated-shops.log`。PR #4 原始数值验收为 635 次生成会话与 535 张故事卡，旧日志仍保留。
- 遗留问题：T03 正在接入小镇前端，本任务交付真实后端流程与接口，走动/门/地图/店内界面联调依赖 T03；T07 最终数值与后端组合回归已通过，其纯经济存活统计和更长周期风险见 T07 报告。
- 范围协调：任务正文要求 world/director/ledger 存档；本任务为 world.gd 追加兼容的 to_dict/from_dict（目录合同允许兼容扩展），不改 scripts/town/* 或 main.gd。T03 尚未在集成分支交付，小镇画面与店内交互的联调由其前端接入本任务的可调用后端。

- 交付接口：Director `setup_town(seed, difficulty)`、`town_start_day()`、`town_visits()`、`run_town_visit(visit)`、`town_night()`、`town_finish_day()`、`town_action(act, args)`；TownSave `snapshot/restore/write/read`，由 T03 的单一日钟驱动，不自行切回旧版轮盘。
- 事件归属：42 张故事卡、27 个新增脚本负责原两天主线和第三至十四天后果（另含林嫂第三十二天）；T01 负责天气价格、额外来访/当物、流言、建筑事件与持久账单。原序章和旧主线文件未修改。
