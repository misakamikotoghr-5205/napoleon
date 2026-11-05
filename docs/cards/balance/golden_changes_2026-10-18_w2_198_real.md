# 合同 §12.5 黄金种子变更记录（2026-10-18 · #198 W2-5 新增真数据用例）

依据：合同 §12.5 与 G06 交接卡 W2 验收“W2 起加真数据用例”；GPT 代 Claude 审（#219，2026-10-18T09:27:36Z）要求保留 examples、补至少一个 `data: "real"` 的确定性用例。

## 变更

- **保留**原用例：examples / seed 7 / fair / 30 天（哈希即本 PR 前一提交 `00af7231` 的值，未再改）。
- **新增**用例：`data: "real"` / seed 7 / fair / 30 天，10/20/30 检查点。
- 未改 `test_golden.gd`、未加新框架：现有测试对每个用例按 `only_examples = (data == "examples")` 读真数据，两遍运行比对检查点哈希与终局哈希，并做完整指令回放（`CardReplay.record` → `CardReplay.replay`）。

## 准确输入

| 项 | 值 |
|---|---|
| 源提交 | `00af72314ce52be42dfcf7def9bc8c3d774414e3`（base `claude/festive-ride-vud32a` = `0d9176784f89b8d6a7959e669bda62b652df4c1e` + 本 PR W2-5） |
| `data/cards` 树 | `HEAD:data/cards` = `bb4e0c7acec700aa50b3cce3d6eee49ed69344e1` |
| `balance_overrides.json` SHA-256 | `c4e838759a859908e2a9f102d8150f9ba7d3643273a7c9ff079f720d774d84dc`（本 PR 最终覆盖，kind 95→85） |
| CardDB `db_hash`（real） | `7621dee4affcd399bf4df46f78910ec97ad1e3bdd268b4521bc8041d0c5e3bf2` |
| Godot | 4.7.1.stable.official.a13da4feb，headless |
| 运行结果 | `ok=true`，30 天，`steps=658`，`game_over_reason=""`（30 天截止，非局终） |

重算命令（只写临时文件，再把 `cases[0]` 追加到 golden.json，examples 用例原样保留；`--update-golden` 本身会整文件重写，所以没有直接写回仓库路径）：

```sh
GODOT_SILENCE_ROOT_WARNING=1 godot --headless --path . -s res://scripts/cards/sim/balance_main.gd -- \
  --data=real --seed_from=7 --seeds=1 --policies=fair --days=30 --stages=3 \
  --update-golden --golden-out=/tmp/dh-219/gen/golden_real.json --out=/tmp/dh-219/gen --date=2026-10-18
```

## 检查点

| 日 | 真数据哈希 |
|---:|---|
| 10 | `e3271bde6db02b3f73bccbd67de6050b722b3d0f9fbb271c7dd9532bbd485f0e` |
| 20 | `24e4b225c431857f78d8404198c55aea36864849e75456a41ce7c38bb5e9855d` |
| 30 | `c4904558df1bbc828565d08cc8b77de827e25725edb9f1c11c83749f98e24c2a` |

交叉核对：与本 PR 的 W2 after 批次（`w2_198/after/runs_1_20.json`，seed 7 / fair，三关连续）同日检查点三个哈希逐字一致，`db_hash` 也一致；说明 30 天截止与三关连续运行在前 30 天走的是同一条路径。

## 选 seed 7 / fair 的原因

与 examples 用例同种子同策略，便于对照；after 批次中 seed 7 / fair 三关走到 ending、10/20/30 检查点齐全、无执行失败；`steps=658` 远低于 `test_golden.gd` 的 `max_steps=10000`。

## 后续影响（请 Claude 知悉）

真数据用例会随任何 `data/cards/**` 或规则改动而变：按 §12.5，此后每次数据/规则 PR 合入由 Claude 跑 `--update-golden` 重算（注意 `--update-golden` 一次只写一种 `--data`，需分别生成 examples 与 real 两个用例后合并，或由 Claude 决定是否给 balance_main 加多用例写回）。同期开着的内容 PR（如 #220 K13 收口改了 K03 引用）合入后预计会让此真数据用例变红，需按 §12.5 流程重算。

标记 `golden-change`。
