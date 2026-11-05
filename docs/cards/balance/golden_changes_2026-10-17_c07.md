# 合同 §12.5 黄金种子变更记录（2026-10-17 · #178 C07 签文档位 + G06 策略单次求签修正）

保留原用例：例子集、seed 7、fair、30 天。

## 原因

1. `#178`（`a3843584`）为 `data/cards/_examples/fortune/lots.json` 补齐 `lot.g0.any`、`lot.g2.any`、`lot.g3.any`、`lot.g4.any` 四档泛泛签，使 `only_examples` 下 `fortune.lot` 能正常抽出 `grade == 3` 的签（`C07_real_engine` 通过），同时 `CardDB.hash()` 随例子集定义增加而更新。
2. 此前 `scripts/cards/sim/policy.gd` 在 `panel == "fortune"` 时未检查 `card.fortune.last.lot`，在 `#178` 之前因 `fortune.lot` 报 `unknown_def` 而只执行了 `fortune.cezi`；`#178` 合入后同一张算命摊牌被连续执行 `fortune.lot` 与 `fortune.cezi`（重复扣费、重复钉签），导致例子集 seed 7 / fair 在第 18 天短款触发大轮盘坠底、第 19 天入狱。
3. 修正 `scripts/cards/sim/policy.gd`：当 `fortune.last.lot != ""` 时不再对同一张 `uid` 叠加 `fortune.cezi`（与 `CardFortunePanel` 求过一次后锁定的界面行为一致）。修正后例子集 `seed 7 / fair` 稳定走完 30 天（`ok=true`，`steps=790`，10/20/30 检查点齐全）。

## 检查点

| 日 | 旧哈希（#178 前） | 新哈希（#178 + policy 修正后） |
|---:|---|---|
| 10 | `0a48e85df0ba3ca7f22e95d1e2b330187250e9b9b91315d2331029140b758219` | `107ecd81bb3e32110c19cf4e6380a2d1a9686fd4f8bcb5f3db80f6dfe7013776` |
| 20 | `ee8716ee70341eb3e683da1f7a811f6b64c9918b5d40fc48bfeb6ff7934e399f` | `53733601a8c96f8343e0a5f535374c3659b14c076767d6df50bde143d18f79ae` |
| 30 | `e694de8e729fb57ca449b179923d46858262cc04178d63f1e5f7c62b80032944` | `2c5931bddba9008b64b17674fc70ea37f2845c060a92a2c7a0ec8eeb4a4dacb9` |

Godot 4.7.1.stable.official.a13da4feb。标记 `golden-change`。
