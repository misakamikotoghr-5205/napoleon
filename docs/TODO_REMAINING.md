# 德厚当：未完成事项与收尾记录（2026-10-17 更新）

集成分支：`claude/festive-ride-vud32a`。今天 W2 链（#166、#154、#157、#159、#158、#152、#149、#148）与 #178 已合入，本次继续完成以下收尾：

## 1. [已完成] #178（C07 签文档位）G06 黄金修复与全量门禁验证
- **根因**：`#178`（`a3843584`）为 `data/cards/_examples/fortune/lots.json` 补齐 `lot.g0.any`、`lot.g2.any`、`lot.g3.any`、`lot.g4.any` 后，`only_examples` 下 `fortune.lot` 从 `unknown_def` 变为成功返回 `grade == 3` 的签；而 `scripts/cards/sim/policy.gd` 在 `panel == "fortune"` 时未检查 `fortune.last.lot`，导致同一张算命摊牌先求签（`fortune.lot`）又测字（`fortune.cezi`），重复扣费与钉签，使例子集 `seed 7 / fair` 在第 18 天短款、第 19 天入狱。
- **修复**：`scripts/cards/sim/policy.gd` 在 `fortune.last.lot == ""` 时才提议 `fortune.cezi`（与 `CardFortunePanel` 求过一次后锁定的行为一致），例子集 `seed 7 / fair` 稳定走完 30 天（`ok=true, steps=790`），刷新 `scripts/tests/cards/golden/golden.json` 并在 `docs/cards/balance/golden_changes_2026-10-17_c07.md` 记录。`C07_*`（8 项）与 `G06_*`（8 项）全绿。

## 2. [已完成] 合入 W1 #37（C08 打烊确认、夜牌、日结）并补齐 W2 测试
- 合入 `origin/cursor/cards-c08-night-settle-d0d4`（#37：打烊确认、夜牌演出、日结对话框、Space/Enter/数字键推进与截图）。
- 补齐 C08 W2 清单：`C08_guide_k16`（`--steps=k16` 复测 K16 定稿步骤）与 `C08_real_engine`（真引擎例子集第 2 天不处理哥哥告别 → 打烊确认 `gold_leave` → 日结 `g02.settle.gold_left`）。`C08_*` 7 项测试全绿。
- 同步 #181（K14 `docs/cards/qa/findings.md` 状态记录）。

## 3. 无头门禁性能/计时预算与 G06 模糊测试覆盖（#146 审计修正）
- **审计结论（#146）**：`ccda2bcb` 曾通过放大计时阈值（C06/C09 50ms→500ms、C14 4ms→500ms/50ms、C16 1ms→15ms、C04 2s→4s）及对 G06 模糊测试抽样来避开并行负载抖动与超时；该做法被审计退回，放宽阈值通过不能视作原合同性能预算验收通过。
- **恢复严格合同预算与受控统计**：按合同 §12.4 / §7.10.7 恢复原预算常量，保留预热并按 #145 建议采用多次采样中位数（或受控串行复核）分离宿主调度噪声，不再放大预算常量：
  - `C06_month`（`scripts/tests/cards/C06/test_month.gd`）：保留 `_warm()` 预热，打开预算恢复为 `< 50ms`（5 次采样取中位数）。
  - `C09_month_open`（`scripts/tests/cards/C09/test_month_open.gd`）：保留 `_timed_open()` 预热，打开预算恢复为 `< 50ms`（5 次采样取中位数）。
  - `C14_physics`（`scripts/tests/cards/C14/test_physics.gd`）：`TIME_PROCESS` 与 `_refresh` 每帧预算均恢复为 `<= 4ms`（5 次采样取中位数）。
  - `C16_guide_overlay`（`scripts/tests/cards/C16/test_guide_overlay.gd`、`scripts/cards/ui/shell/card_guide.gd`）：70 步挑步骤预算恢复为 `<= 1ms`（5 次采样取中位数，并在 `_scan` / `_date_ok` / `_resolve` 中跳过无自动完成且无法胜出或无需日期/uid 展开的重复检查）。
  - `C04_pawn_sell`（`scripts/tests/cards/C04/test_pawn_sell.gd`）：`open()` 与 `rebuild` 预算恢复为 `< 2s`（3 次采样取中位数）。
- **恢复 G06 模糊测试逐步不变量覆盖**：`scripts/tests/cards/G06/test_no_deadlock.gd` 与 `fuzz_helpers.gd` 恢复每步 `preview`（含不抽样的 `state_hash` 只读校验）、`no_leaks`、`find_floats` 检查；每次 `day.end` 与 `escape` 均走 `Probe.end_step`；随机早上存读与 `terminal_recovery` 覆盖全部种子（仅保留引擎实例复用作为非抽样优化）。

## 4. 其余开着的 PR（按原状态保留）
- **#176**（C04 K16 指引复测）：作者注明先停，不要动（集成树上 `C04_guide_k16` 已在跑且通过）。
- **其他已合入等价物的旧复测 PR**：#174（C06）、#175（C11）、#177（C09）、#179（C02）对应测试均已在集成树上通过。
- **N01–N06 数据骨架**：#164（N02 告示/禁收令）、#165（N03 镇店之宝）、#169（N06 传承/进货/小动作/阵营/造假）、#170（N01 本事插嘴）、#171（N04 档案推理）、#172（N05 人物随年份）。还只是数据骨架，待后续机制实现。
- **草稿 / 旧集成**：#98（草稿）、#25（标了"不要合入"）。
