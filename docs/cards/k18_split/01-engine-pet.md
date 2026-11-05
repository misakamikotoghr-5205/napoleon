# K18 引擎回执（01 · pet.gd）

分支 `grok/182-2-pet-cat`。只读核对引擎，**没有改 `scripts/cards/rules/pet.gd`**。未切分支、未 commit、未 push。

## 看了什么

- `scripts/cards/rules/pet.gd` 全文（挂钩、`apply_look`、`on_night`、走丢入队、发霉、视图）。
- 对照：`data/cards/rules/pet.json`、`data/cards/era/1938/pet.json`（`ev.1938.cat_arrive` 的 `effects.on_done`、`ev.1938.find_cat`）、`docs/handoff_cards/K18_pet-cat.md`、`DESIGN_cards.md` §九.7、`scripts/tests/cards/K18/test_pet.gd`。
- 调用链：`rules_install.gd` 的 `Pet.install`；`choices.gd` 先跑选项效果再 `card_resolved`；`appraisal.gd` 的 `params_for` 返回前调 `apply_look`；`core_install.gd` 的 `add_card` 入队；`CardMeters.add`；`CardViewModel.FORBIDDEN_KEYS`；`CardIds.RNG_DOMAINS` 里已有 `c.pet.wander`。

## 核对

- 不新增区、命名空间、`class_name`、DSL op。文件 `extends RefCounted`，没有 `class_name`。走丢只用已有的 `flag` / `flag_clear`，入队跑进店牌上已有的 `add_card`。
- 猫自己的状态只在 `rules.flags`（`pet_home` / `pet_lost`；`pet_refused` / `pet_missed` 由牌效果写）和 `rules.pet`（`look_left` `look_day` `had` `find_due` `nights`）。本心走已有的 `rules.meters`，第一次留下走已有的 `core.firsts`。
- 没留过猫不写 `rules.pet`、不掷 `c.pet.wander`。`home()` 要有 `pet_home` 且没有 `pet_lost`。赶走、不理会都进不了 `home()`，`_resolved` 直接返回。`on_night` 在 `had` 为假时返回。`_wander_roll` 只在住满并且 `nights >= min_nights` 时调用（`and` 短路）。
- 多看一眼只在猫在店、当天还有 `look_left` 时，给 `spot` 的 `ink` 或 `coin_ring` 的 `tries` 加 1，并减掉这一眼。称分量等其它种类不加、不消耗。早上按 `look_day` 每天只补一次。
- 在店的夜里走 `home` 分支后返回，不扣米货成色。只有 `had` 且 `pet_lost` 才减货架上 `cat == "rice"` 的 `condition_permille`（`mold_permille`，下限 0）。
- 住满 `min_nights` 之后才用已登记的域 `c.pet.wander`，键 `[abs_day]`，判定是 `int(draw * wander_den) < wander_num`。
- 走丢时 `_queue_find` 复制进店牌 `effects.on_done` 再 `ctx.run`，把 `ev.1938.find_cat` 排进队列。牌不在手牌、留牌区或队列里，才按 `retry_days` 再排。引擎不写 `pet_home`，不会自己回家。
- `settle` 钩子在店时把 `conscience_night` 收成整数后 `CardMeters.add`。视图只有 `pet.show` / `pet.home` / `pet.lost`，没有 `conscience` / `quality` / `pct`。
- 不登记 `end_rows`、不改 `day.end`、不开关不掉的面板。猫牌仍是普通必须了断事件，不理会走 `on_expire`。

## 改没改

没改。现有实现和上面这些约束一致，没有确定的逻辑 bug。未重跑 `--import`。

未改代码，按任务不必重测；为确认核对，跑了一次现有 `test_pet.gd`，最后一行：

`CARDS TEST PASS K18_pet`
