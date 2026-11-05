# K18 边界回执（11）

分支 `grok/182-2-pet-cat`。只新增本说明和 `scripts/tests/cards/K18/test_pet_edges.gd`。未改 `test_pet.gd`、`suites/K18.txt`、产品代码。未切分支、未 commit、未 push、未改 PR。

测试名 `K18_pet_edges`（`T.new`）。`extends SceneTree`，用 `res://scripts/tests/cards/lib/card_t.gd`。开局与主测试相同：`CardEngine.new()`，`new_game` seed 7、`only_examples` false、`save_dir` 用 `t.user_dir()`。不复制主测试的留下、多看一眼、发霉、走丢。

## 钉住的两点

1. 猫没进店：连续两次 `Pet.on_night`。`H.peek(rules)` 没有 `pet` 键，`core.queue` 没有 `ev.1938.find_cat`，`state.hash` 前后不变（这条路径不写状态；走丢才会掷 `c.pet.wander` 并入队）。
2. `card.choose` 选 `shoo` 之后：`core.firsts` 没有 `pet`，`view` 没有 `pet` 键。`day.end {confirm:true}` 推进到下一天后，再发一次 `day.end {confirm:true}` 仍 `ok`。

## 跑法

```
/tmp/godot/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/dehoudang -s res://scripts/tests/cards/K18/test_pet_edges.gd
```

未加 `--import`。退出码 0。日志无 `SCRIPT ERROR` / `WARNING` / `FAIL:`。最后一行：

CARDS TEST PASS K18_pet_edges

## 建议加入 suites/K18.txt（由汇总的人加，本线不改清单）

```
K18_pet_edges|res://scripts/tests/cards/K18/test_pet_edges.gd|60|
```
