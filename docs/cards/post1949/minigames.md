# 新小游戏（只给物理量和摆设）

沿用合同 §8.2 的规矩：参数里只有摆设和物理量，结果只交观察键和整数，不交对错，不交真假。分钟数是玩家花费的时间，进当天的分钟，不另算隐藏分。

信托商店不新做小游戏，沿用找不一样、听银元、称分量。下面三个只属于茶馆。

锚点和 `mg_tool` 的工具名是提议，实现时走 `[api]`。

## 泡茶 `tea_brew`

摆设：一把壶、一只杯、一炉炭、一罐茶叶。

| 参数 | 单位 | 说明 |
|---|---|---|
| kettle_ml | 毫升 | 壶的容量 |
| leaf_g | 克 | 投下的茶叶 |
| water_c | 摄氏度的整数 | 水开到多少 |
| pour_ms | 毫秒 | 这一次冲了多久 |
| cups | 整数 | 要几杯 |

观察键（提议，不判对错）：`obs.tea.steam`（汽大或汽小）、`obs.tea.color`（汤色深或浅）、`obs.tea.leaf`（叶子沉或浮）。fidelity 仍是 clear / partial / vague，由玩家有没有把炭和壶都点开决定，不由隐藏的标准答案决定。

工具名提议：`kettle`、`stove`、`jar`。锚点提议：`a.mg.tea.kettle`、`a.mg.tea.stove`。`mg_tool` 的 kind 提议为 `tea_brew`。

分钟：每冲一杯 1 分钟【待调】，炭要点着再加 1 分钟。上限 8 分钟。

## 记茶钱 `tea_tab`

摆设：一本账、一排茶客的杯子、一碟铜板或纸币。

| 参数 | 单位 | 说明 |
|---|---|---|
| seats | 整数 | 有几位茶客 |
| price_each | 整数钱 | 每位今天的茶钱，界面上写明 |
| paid | 整数数组 | 每位已经放下的钱 |
| ink | 整数 | 账上已经写下的笔数 |

观察键：`obs.tab.short`（某一座还少）、`obs.tab.even`（这一座对上了）、`obs.tab.smudge`（上一笔涂改过）。不出现「算错了所以扣钱」这种隐藏判定。钱的进出只在玩家按下「收下」或「赊着」时，按明写的整数走 `money`。

工具名提议：`brush`、`abacus`、`coin`。锚点提议：`a.mg.tab.book`、`a.mg.tab.seats`。

分钟：每位 1 分钟，上限 6 分钟。

## 听书 `story_listen`

摆设：一张醒木、一条长桌、说书人的折扇、听众的空位。

| 参数 | 单位 | 说明 |
|---|---|---|
| chapters | 整数 | 今天说几段 |
| heard | 整数 | 玩家坐到了第几段 |
| noise | 整数 0–2 | 堂里吵不吵（0 安静，2 听不清） |
| minutes_per_chapter | 整数 | 一段几分钟 |

观察键：`obs.story.line`（听到一句，键的正文由 A 写）、`obs.story.missed`（这一段没坐住）、`obs.story.fan`（扇子一合，这一段结束）。听完整段就得到那张消息牌的 `on_read`，没听完就没有碎片。没有「听错了受罚」。

工具名提议：`seat`、`fan`。锚点提议：`a.mg.story.stage`、`a.mg.story.seat`。

分钟：`chapters * minutes_per_chapter`，一段默认 2 分钟【待调】，上限 10 分钟。
