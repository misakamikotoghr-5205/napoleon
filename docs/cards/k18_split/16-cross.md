# K18 交叉测试回执（16）

分支 `grok/182-2-pet-cat`。Godot 4.7-stable，`--headless --path /tmp/dehoudang -s`。未跑全量 strict。未改代码或数据。

| # | 脚本 | 退出码 | 最后非空行 |
|---|---|---:|---|
| 1 | `res://scripts/tests/cards/K16/test_guide_coverage.gd` | 0 | `CARDS TEST PASS K16_guide_coverage` |
| 2 | `res://scripts/tests/cards/W0/test_skeleton.gd` | 0 | `CARDS TEST PASS W0_skeleton` |
| 3 | `res://scripts/tests/cards/C02/test_hero.gd` | 0 | `CARDS TEST PASS C02_hero` |
| 4 | `res://scripts/cards/core/validate_main.gd -- --mode=default --name=cards_data_validate` | 0 | `CARDS TEST PASS cards_data_validate` |

四条日志均无 `SCRIPT ERROR`、`Parse Error`、`FAIL:`、`DATA ERROR`。

default 校验：`CARDS VALID 1094 cards, 0 errors`。同日志另有 207 条 `NOTE`（V11×1、V12 unknown art×190、V16 weight-zero×8、V36 wheel-segment×8），不计为 error，也不是全量 strict 的 207 条旧 V16/V36 基线。
