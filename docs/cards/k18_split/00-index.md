# K18 拆分汇总（16 个子代理）

分支 `grok/182-2-pet-cat`。基线提交 `aa2c114`。16 条都已结束。产品代码（`pet.gd`、安装、鉴定、`card_ids`、两张事件、规矩数、标签、指引、英雄条）没有人改。汇总只加了边角测试进套件、本目录回执、三张视口截图，并把截图脚本的写出路径从沙箱绝对路径改成 `res://`（产品行为不变）。截图脚本不进 `suites/K18.txt`。

| # | 做什么 | 回执 | 结果 |
|---|---|---|---|
| 01 | 核对 `pet.gd` | [01-engine-pet.md](01-engine-pet.md) | 未改。`CARDS TEST PASS K18_pet` |
| 02 | 核对规则安装 | 无文件 | 未改。`Pet.install` 在 `rules_install.gd` 第 36 行。只登记视图段和 `day_start` / `card_resolved` / `settle`。没有新指令。视图顶层键 `pet` 不与现有键冲突。安装顺序未动 |
| 03 | 核对鉴定 | 无文件 | 未改。`params_for` 只在返回前走 `Pet.apply_look`。猫不在店时同一本字典原样返回 |
| 04 | 核对机制表 | 无文件 | 未改。`FIRSTS` 67，`pet` 发出者 G03（19）。`a.pet` 不在 `CARD_ANCHORS`。随机域只有 `c.pet.wander` |
| 05 | 核对两张事件 | 无文件 | 未改。进店牌 `on_done` 才引用找猫。没有假排程 |
| 06 | 核对规矩数 | 无文件（特意不写） | 未改。`looks_per_day` 1、`conscience_night` 1、`mold_permille` 50、`wander_num` 1、`wander_den` 12、`min_nights` 3、`retry_days` 3，都是整数 |
| 07 | 核对标签和界面键 | 无文件 | 未改。标签只有 `cat`。界面键九条，都是 `k18.` |
| 08 | 核对指引 | 无文件 | 未改。`gd.pet` 与 `rule.contact` 对得上。规矩页仍 26。步骤 67。只有 `gd.pet` 的出处是 K18 |
| 09 | 核对牌位 | 无文件 | 未改。`CardLayout.PET` 不压英雄条、人脉、下一天。牌位 `mouse_filter` 忽略。猫没出现时不登记空锚点 |
| 10 | 重跑主测试 | [10-tests.md](10-tests.md) | `K18_pet`、`K18_validate` 都过。default 校验 0 errors |
| 11 | 边角测试 | [11-edges.md](11-edges.md) | 新增 `test_pet_edges.gd`。汇总复核退出码 0，最后一行 `CARDS TEST PASS K18_pet_edges`，无 `SCRIPT ERROR` / `Parse Error` / `FAIL:` / `DATA ERROR`。套件已加一行：`K18_pet_edges\|…\|60\|` |
| 12 | 猫在店截图 | [12-shot-home.md](12-shot-home.md) | `shots/home/pet_home.png` 18772 字节，1280×720。牌位「【稿】店里的猫在」。`CARDS TEST PASS K18_shot_home` |
| 13 | 猫走丢截图 | [13-shot-lost.md](13-shot-lost.md) | `shots/lost/pet_lost.png` 19071 字节，1280×720。牌位「【稿】猫走了，得去找」。`CARDS TEST PASS K18_shot_lost` |
| 14 | 找猫牌截图 | [14-shot-find.md](14-shot-find.md) | `shots/find/find_cat.png` 12097 字节，1280×720。单独 `CardWidget`（开局是 `month_open`，不用手牌扇）。`CARDS TEST PASS K18_shot_find`。框和字没有对齐，是这张截图的排法，不是店里牌位 |
| 15 | 合同回执 | [15-contract.md](15-contract.md) | 不改合同。`day.end` 没动。和 #184 的冲突文件已列出。本线不改 #184 |
| 16 | 交叉测试 | [16-cross.md](16-cross.md) | `K16_guide_coverage`、`W0_skeleton`、`C02_hero`、default 校验都过。日志里 207 条是 `NOTE`，不是 strict 的 207 条旧错误 |

三张图都是 xvfb 真视口读出来的，不是手绘。无头假纹理读不出像素。通过行之前可有一条驱动不支持垂直同步的警告。
