# 合同 §12.5 黄金种子变更候选（2026-10-16 · #189 宠物猫）

保留原用例：例子集、seed 7、fair、30 天。

## 原因

新增 `data/cards/rules/pet.json`。`CardDB.hash()` 含全部 rules（`only_examples` 仍加载真 rules），`CardState` 把 `db_hash` 写入状态，故 10/20/30 检查点哈希随 `db_hash` 变。

例子集无 `ev.1938.cat_arrive`；day1 不写 `rules.pet`。同 seed/policy 下把状态里的 `db_hash` 置空后，tip（无 pet.json）与本分支在 10/20/30 的 blanked 哈希完全一致；把 tip 的 `db_hash` 写回本分支终局状态，哈希等于 tip/旧 golden 第 30 日。

## DB hash

| 树 | `CardDB.hash()`（only_examples） |
|---|---|
| tip 等价（无 `rules/pet.json`） | `1f8b729e2a7d960275b973a0ff26bbd1cbc807473709c5c9f58ecfd665b24712` |
| #189 HEAD（有 pet.json） | `8bf41d7bd046620925eed1055b152e0c51c273cc2a6442fc69674a2a8ce0bde5` |

## 检查点

| 日 | 旧哈希 | 新哈希 | blanked（两侧相同） |
|---:|---|---|---|
| 10 | `c10c2ac3…a7efc2` | `0a48e85d…758219` | `fbeffa83…3948b1` |
| 20 | `2b1b784a…05a542` | `ee8716ee…4e399f` | `be773f96…4520f7` |
| 30 | `b045fce2…6858a9` | `e694de8e…032944` | `1aa39a0e…45e065` |

（完整 64 位见本 PR 评论回执。）

Godot 4.7.1.stable.official.a13da4feb。标记 `golden-change`；本提交只改 `golden.json` + 本说明。
