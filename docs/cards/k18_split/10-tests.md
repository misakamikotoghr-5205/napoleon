# K18 主测试回执（10）

分支 `grok/182-2-pet-cat`。Godot 4.7-stable：`/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s`。未加 `--import`。两条都过，未改测试、代码或数据。未切分支、未 commit、未 push。

| # | 脚本 | 退出码 | 最后一行 | SCRIPT ERROR / Parse Error / FAIL: |
|---|---|---:|---|---|
| 1 | `res://scripts/tests/cards/K18/test_pet.gd` | 0 | `CARDS TEST PASS K18_pet` | 无 |
| 2 | `res://scripts/cards/core/validate_main.gd -- --mode=default --only=data/cards/era/1938/pet.json,data/cards/rules/pet.json,data/cards/tags/K18.json,data/cards/ui_keys/K18.json --name=K18_validate` | 0 | `CARDS TEST PASS K18_validate` | 无 |

校验日志在通过行之前还有 `CARDS VALID 1094 cards, 0 errors`。两条日志都没有 `DATA ERROR`。
