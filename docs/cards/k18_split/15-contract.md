# K18 合同回执（只核对，不改合同）

对照：`DESIGN_cards.md` §九.7 宠物一行、`CARDS_INTERFACES.md` K18 小节与 §7.10.10 `pet` 行、`ownership.json` 的 K18 路径、`docs/handoff_cards/K18_pet-cat.md`、GitHub issue #188。分支 `grok/182-2-pet-cat`，提交 `aa2c114`，基线 `7203d02`。不新开 issue。

## 已写上的合同点

- 机制 `pet`，发出者 **G03**。`CardIds.FIRSTS` 里 `&"pet": "G03"`。第一次：猫留在店里的当刻（留下，或找回来），不等第二天。步骤 `gd.pet`，教的人 `obj.brother_ledger`，阶段 `day`。
- 锚点 `a.pet`，主人 C02。备用 `a.contacts`。不是新区。牌位 `CardLayout.PET = Rect2(128, 566, 220, 40)`。`hero_bar.gd` 登记 `a.pet`。
- 随机域 `c.pet.wander`（G03，非正则）。没有 return 域。
- 旗标在 `rules.flags`：`pet_home` `pet_lost` `pet_refused` `pet_missed`。计数在 `rules.pet`：`look_left` `look_day` `had` `find_due` `nights`。
- 开放日：进店牌 `ev.1938.cat_arrive`，1938 第一关 `schedule.stage_day` **15**，`weight` 0，`once`。#188 写明第 12、16 天已占用。§九.7 这一行是「1938 第一关中段」。
- 机制数 **67**（含预留 `currency` `branch_pick`）。`FIRSTS` 注释与 `W0` 断言都是 67；发出者计数里 G03 由 18 改为 19。指引 `steps.json` 的 `cards` 67 步；`rule.contact` 的 `unlock_first` 加上 `pet`，规矩页仍 26，不新加页。K16 覆盖表有 `gd.pet` 一行。`gd.pet` 出处是 K18，其余步骤仍是 K16。

## 归属（ownership.json 的 K18）

`data/cards/era/1938/pet.json`、`data/cards/rules/pet.json`、`docs/handoff_cards/K18_pet-cat.md`。

## 跨线文件（本分支已改；handoff 与 #188）

- `scripts/cards/api/card_ids.gd`（机制、锚点 `a.pet`、随机域）
- `scripts/cards/api/card_layout.gd`（`PET`）
- `scripts/cards/rules/rules_install.gd`（`Pet.install`）、`scripts/cards/rules/pet.gd`
- `scripts/cards/economy/appraisal.gd`（`params_for` 返回前 `Pet.apply_look`）
- `scripts/cards/ui/card/hero_bar.gd`
- `data/cards/guide/steps.json`、`data/cards/guide/rule_pages.json` 的 `rule.contact`、`scripts/tests/cards/K16/table_71010.json`
- `scripts/tests/cards/W0/test_skeleton.gd`、`scripts/tests/cards/K16/test_guide_coverage.gd`（条数 66→67）

另改了合同登记：`docs/cards/CARDS_INTERFACES.md`、`docs/cards/ownership.json`。

## 与 #184 可能冲突的文件

#188：#184（K17）也把 66 改成 67，碰到 `card_ids.gd`、指引步骤和 W0/K16 条数。两条都从 `7203d02` 切出。#184 的文件列表与本分支都改了：

- `scripts/cards/api/card_ids.gd`（K17 在 `branch_pick` 后加 `office`；本分支加 `pet`，并把「共 66 个」改成 67）
- `data/cards/guide/steps.json`（同一句 brief「66 步」；末尾各加 `gd.office` / `gd.pet`）
- `data/cards/guide/rule_pages.json`（K17 改 `rule.gold`，本分支改 `rule.contact`）
- `scripts/tests/cards/K16/table_71010.json`
- `scripts/tests/cards/K16/test_guide_coverage.gd`（67 步、出处断言）
- `scripts/tests/cards/W0/test_skeleton.gd`（`FIRSTS.size()` 67，G03 计数 19）
- `scripts/cards/rules/rules_install.gd`（K17 在 `_dealt` 记 `office`；本分支 `Pet.install`）
- `docs/cards/CARDS_INTERFACES.md`、`docs/cards/ownership.json`（都在 K16 后插入本线）

本线不改 #184。

## 下一天

§九.7：「下一天」**指令仍是 `day.end`**，只换按钮文字。`CardIds.CMD_DAY_END` 仍是 `&"day.end"`；`aa2c114` 的 `card_ids.gd` 差异没有动这条。K18 合同写明不能挡住 `day.end`。猫牌是必须了断的事件，不理会走 `on_expire`。`gd.pet` 的 `done_when` 含 `cmd:day.end`，不是改指令名。
