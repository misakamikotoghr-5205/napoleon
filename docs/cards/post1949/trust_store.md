# 信托商店 / 旧货店

离当铺最近。鉴定和估价沿用当铺的看货（找不一样、听银元、称分量）。收的是寄卖和旧货，不是新开的当。不写新的隐藏数值，价钱仍走柜台三档，底数不进界面。

数量都是【待调】。

## 牌组清单

| 类 | 数量【待调】 | 和当铺机制的关系 |
|---|---|---|
| 寄卖人（person，intent pawn 或 sell） | 8 | 东西先上架，成交后再跟原主结。不新开当票，除非玩家仍持有旧当票 |
| 旧主顾（person，intent buy 或 redeem） | 6 | 赎回仍走 `redeem`。人是档案簿里已经认识的，换了身份 |
| 寄卖事件（event） | 4 | 货主改口、要提前取回。用格子收 `self` 或一笔钱，`check.need` 小 |
| 通知（demand 的新年代皮） | 4 | 见下表。类仍是 goods / money / info，档 0–1，期限按天 |
| 消息（news） | 4 | 旧货行情、谁家在找一件旧东西。`keepable`，看过可以补档案 |
| 生活（life） | 2 | 铺租、进货。几天内处理 |
| 风险 | 0 张随机惩罚 | 不设。查账走 `policy_events.md` 的日程事件 |

### 条子在这里叫「任务 / 通知」

| 当铺条子的字段 | 信托商店 |
|---|---|
| kind | 仍用 money / goods / info。不新加 kind |
| tier | 开局最高 1。升档只由政策事件里写明的那一条造成，不每天随机升 |
| deadline_days | 仍是整数天数 |
| 办法 | 交钱、交货、交差。不新造「告发」 |
| 不同处 | 发牌来源是日程 `weight: 0`，不是每周随机。面板仍是 `demand`，锚点仍用 `a.demand.board` |

## 样例骨架（不是正文）

### 1. `p.<原主>.branch.consign_coat`（person）

| 字段 | 值 |
|---|---|
| intent | sell |
| item.template | 一件旧衣，模板等 K11，类别走服装 |
| weight | 0，靠 schedule 或人脉条件 |
| minigame | 不固定。沿用该模板自己的看货，不在教学日之外强迫某一种 |
| effects.on_accept | 钱进账，原因键 `branch.reason.consign`；原主的档案可补一块「东西卖掉了」 |
| brief | 老主顾把一件衣服寄在店里卖。卖掉再跟他结，不是当。 |

### 2. `ev.branch.owner_takes_back`（event）

| 字段 | 值 |
|---|---|
| must_resolve | true |
| slots | 一个收 `self`（attr nerve），一个收 `money` |
| check.need | 1【待调】 |
| on_success | 东西归还原主，店里少一件货，没有别的扣罚 |
| on_fail | 只记一个 flag，下一张通知会来问。不封店 |
| brief | 货主要提前把寄卖的东西拿走。人在或不在、钱够不够，用格子说，不写场面。 |

### 3. `dm.branch.inventory_notice`（demand）

| 字段 | 值 |
|---|---|
| kind | goods |
| tier | 0 |
| deadline_days | 7【待调】 |
| resolve.goods | 从货架交一件指定类别 |
| weight | 0 |
| schedule | 按年份的某月某日，见 `policy_events.md` |
| brief | 上面要一份存货名单。交得出就交，交不出就等到期限那一天的政策事件，不另掷。 |

## 老面孔

档案簿里有碎片的人，按人换一张皮：原来来当的，现在可能来寄卖；原来来买画的，现在来问一件旧物还在不在。身份写在 `person` 字段和 brief 里，不新造人物 id，除非 K01 的名单里本来就有。周妈不在这家店当掌柜（她走茶馆）。
