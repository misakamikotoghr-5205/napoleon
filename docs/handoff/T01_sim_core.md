# T01 生成器核心：把 GameJev 移植成小镇模拟（纯逻辑）

- **执行者**：GPT
- **依赖**：无（可以马上开始）
- **分支**：`town/T01-sim-core`（从 `claude/festive-ride-vud32a` 切出）
- **状态**：已合并（GPT / 2026-10-11；Claude 已集成 PR #1）。T06 已评：不用改，建议改纯模拟 `pawn_rate`，见 [PR #1 评论](https://github.com/misakamikotoghr-5205/dehoudang/pull/1#issuecomment-6107811791)。

## 目标
把 GameJev 的随机世界生成器做成 `scripts/sim/` 里一套**无界面、可确定复现**的 GDScript 模块，驱动青溪镇每天的天气、米价、建筑事件、谁来当铺、带什么东西、流言、账单与解锁。前端（T03）和玩法（T04）都只通过 `TownSim` 接口用它。

## 必读
1. `docs/handoff/TOWN_INTERFACES.md`（§0、§1、§4、§5、§8、§9、§10 必读）
2. `docs/town/research/gamejev_code.md`（GameJev 源码解析与移植方案，§1、§2、§3、§5）
3. `docs/town/prototype/`：**已跑通的原型**（`jev_rng.gd` 与 Python 逐位一致；`town_sim.gd` 跑过 21 天、存读档一致、外生随机不受玩家影响）。在它基础上拆模块，不要从零写。
4. `docs/town/DESIGN_v04_town.md` §3（建筑与开门条件）、§4（生存压力的九类账）、§5（随机性）
5. `docs/town/research/gamejev_design.md` §1.2、§2.6、§4、§6（不能违反的规则）
6. 现有核心：`scripts/core/world.gd`、`ledger.gd`、`mind.gd`、`data/cast.json`、`data/items/*.json`

## 要做的事
- [x] `scripts/sim/jev_rng.gd`（照搬原型）
- [x] `town_pack.gd`（读取 + 校验：每个轮盘必须有正权重的 `quiet`；外生轮盘不得读内生压力；未知字段/未知 op 报错）
- [x] `town_cond.gd`（数据条件：`all/any/not/day_gte/weekday/season/weather/flag/stat_gte/pressure_gte/building/npc_rel_gte`；有 world 时 `flag/stat` 读 world）
- [x] `pressure_model.gd`、`world_wheel.gd`、`living_costs.gd`、`npc_life.gd`、`rumor_net.gd`、`institutions.gd`、`unlocks.gd`
- [x] `item_gen.gd`：按 `data/town/item_templates.json` 生成当物（品级、成色、真假、赃物、稀有度用伪随机保底）；产出的物品定义能直接被现有 `session.gd` 使用（字段对齐 `data/items/*.json`，含 `parts` 验货部位）。模板至少覆盖：米、衣物（长衫/棉袄/旗袍料）、首饰（银镯/金簪/玉坠）、器物（铜手炉/锡壶/座钟）、书画、药品、文书；每类 3–6 个变体。
- [x] `town_sim.gd`：实现合同 §5.3 的全部接口；`visits[].session` 生成合法的会话规格（buy/sell/pawn）；有 `storylet` 的来访指向现有会话 id。
- [x] `data/town/town_pack.json`：建筑 10 栋（合同 §5.2）、`cast.json` 全部人物的日程（地点名与 T02 地图 `places` 对齐：先用这些名字——`德厚当 桥头街 茶馆 米行 济生堂 保公所 邮电局 码头 孙府 集市 镇外 家`）、陌生人原型 ≥4 种、九类开销、三种难度、主干日期（维新政府成立日 → 警察所开门；或怀疑/动荡越线提前开门）。
- [x] `world.gd` / `ledger.gd` 向后兼容钩子（合同 §5.4）。
- [x] 测试 `scripts/tests/test_sim_*.gd`，并追加进 `tools/run_tests.sh`：
  - 同种子两次结果完全一致；不同种子不同
  - 第 10 天存档（JSON 往返）后续跑到第 30 天，与连续运行逐位一致
  - 玩家操作（收赃/举报/不付账）不改变任何外生轮盘的结果（天气、米价）
  - 每个轮盘都有 quiet；冷却生效；概率和为 1
  - 每类开销落在【数据给定区间】内，且“每笔都有来源与日期”
  - 解锁条件按时触发；流言跳数/过期/去重
  - 3 个难度 × 50 个种子跑 30 天：无脚本错误、钱守恒（`ledger.check_invariants()` 为空）、每天至少 1 位来客、不出现连续 7 天零来客

## 只能改这些文件
`scripts/sim/**`、`data/town/town_pack.json`、`data/town/item_templates.json`、`scripts/tests/test_sim_*.gd`、`tools/run_tests.sh`（只追加）、`scripts/core/world.gd` 与 `ledger.gd`（只做合同 §5.4 的兼容扩展）、`scripts/tests/validate_data.gd`（把 `data/town/` 加进缺字检查）。

## 验收标准
- `tools/run_tests.sh` 全绿（旧 63 项 + 新增）
- PR 描述贴一段 `dev_log` 的 14 天摘要（像 `gamejev_code.md` §5.6 那样）
- 所有数值都在 `town_pack.json` 里，代码里没有写死的平衡数字

## 回报（执行者填写）
- 分支 / PR：`town/T01-sim-core`；[PR #1](https://github.com/misakamikotoghr-5205/dehoudang/pull/1)，已于 2026-10-11 由 Claude 合并到 `claude/festive-ride-vud32a`。
- 测试结果（PR #1 原始数值验收）：Godot 4.7，`GODOT=/workspace/tools/godot47/Godot_v4.7-stable_linux.x86_64 GODOT_SILENCE_ROOT_WARNING=1 tools/run_tests.sh` 全绿（原 63 项并行全流程 + 7 个原校验/专项 + 5 个新增模拟测试）。规则 543、重放 298、生活/机构 2436 项检查；3 难度 × 50 种子 × 30 天共 4500 日真实 Ledger 验收、19177 次来访、22430 笔转账、216117 项检查；任何 SCRIPT ERROR/ERROR/WARNING 均判失败。最终完整日志 `/tmp/tmp.QEVZSyc1PC`。
- 遗留问题 / 需要编排决定的事：T02 为新增当物补充画面素材（当前生成规格使用已有图或空图标，不妨碍 Session 验货/成交）；T03 可直接调用合同中的完整 TownSim API。补充实际等待来访者/同行者目击与锁门前流言传播回归，避免收赃告发与机构提前开门的循环依赖；不产生全知侦查；纯模拟只有真实资金结算成功后才交付物品、开票和传播见闻，零/负报价或不足款无这些副作用。本任务没有改 UI 或其他任务路径。Claude 已集成 PR #1 与 T04 后端 PR #4；T07 在最新集成输入上另外验收数值，T06 评审仍按任务板跟进。
- 执行线路：1 交接定位、2 数据/条件、3 压力/轮盘、4 家用/机构/解锁、5 NPC/流言、6 当物、7 总调度、8 规则验收、9 重放/隔离、10 生活机制验收、11 多种子验收；12–16 继续执行 T04 运行时、故事卡、存档、T07 平衡、T04 试玩。平台最多 7 个代理同时运行，16 线分批并行。
