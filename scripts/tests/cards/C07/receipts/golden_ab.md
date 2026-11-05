# C07 golden A/B 与 day20/day30 归因（合同 §12.5）

被测树：`f5d352691f11ff3e98b02cbb769b5940086207fa`，已含 tip `ba5076b51a2cb6ec2d0469b746b95910d0e814a3`（#185，只换“下一天”的字，不进状态哈希）。
Godot `4.7.1.stable.official.a13da4feb`。未改 `scripts/tests/cards/golden/golden.json`（归 G06）。
`--update-golden` 会拒绝缺少第 10/20/30 日检查点的用例，所以这次不能生成新黄金。
这组数字和只含 `feaffe2` 时相同。#185 没有改这条对局。

## 对照

同一提交，只从 `data/cards/_examples/fortune/lots.json` 删掉四条例子签
`lot.g0.any` / `lot.g2.any` / `lot.g3.any` / `lot.g4.any`。
seed 7，policy fair，days 30，max_steps 10000，`only_examples`。

| | 有四条签 | 无四条签 |
|---|---|---|
| db_hash | `f8cf06c907b50bda9c60da2870c3227342bf844e6948c41b0688f5d4a6cef616` | `8bf41d7bd046620925eed1055b152e0c51c273cc2a6442fc69674a2a8ce0bde5` |
| 检查点 | 只有 day10 `fff7ba7f8eaceff479f8f8cdc4138a63bb7eae92d42084e794fff4fcd5260e4d` | day10/20/30 与现有 `golden.json` 逐字相同 |
| 结束 | abs_day 19，phase `game_over`，reason `prison` | abs_day 30，phase `morning`，reason 空 |
| last_error | `not_allowed`（更早的失败指令，不是终局原因） | `not_allowed`（同样不是终局原因） |
| 重复运行 / replay | 都一致 | 都一致 |
| 步数 | 490 | 803 |

无签一侧的 db_hash 就是当前黄金所在的例子库哈希（含 #189 的 pet.json，不含这四条签）。

## 第一次行为分叉

第 20 步、第 4 日、`fortune.lot`。前一步两边都是 `day.begin` 成功。

- 有四条签：`ok=true`，签是 `lot.g3.any`，grade 3。之后第 6/8/10/14 日再次求签，成功的也是 `lot.g3.any` grade 3。
- 无四条签：`ok=false`，`err=unknown_def`。`CardFortune._verse` 按规矩里的好坏配出 grade，例子库里原来只有 grade 1，配出来的 grade 没有签文就失败，不钉未来的牌。

grade 3 来自 `rules/fortune.json` 的 `grades.good`。`lot.g3.any` 是这张签能写进例子库的原因。C07 的真引擎测试要求 seed 7 的例子局 `fortune.lot` 成功并落到例子池里的签，所以这四条签要留在 `_examples`。

## 为什么没有 day20 / day30

不是断言被删，也不是 days 被缩短。有签这一侧在第 19 日 `slot.roll` 成功后阶段变成 `game_over`，原因 `prison`，`stage_day` 19。检查点只在当天早上记，第 20 日和第 30 日的早上没有到达。第 17–18 日求签已是 `insufficient_money`，第 18 日有 `slot_reject` / `demand.delay` → `not_allowed`，这些是 `last_error`，不是把局停掉的那一步。

无签的同一棵树（含 tip #191 的武器吓唬）能走满 30 日，三个检查点等于现有黄金。所以不是 #191 改坏黄金。

## §12.5

这是行为变化，不是哈希算错：求签从失败变成成功，钉住后面的牌，fair / seed 7 在第 19 日进牢房。标签 `golden-change`。不悄悄改 `golden.json`。要换基线，新的一局仍得走到第 10/20/30 日，由审查方同意后再单独提交只改 `golden.json` 的 `--update-golden`。在走到第 30 日之前，生成工具会直接退出。
