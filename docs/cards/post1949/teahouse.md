# 茶馆

周妈那条线。人物牌变成茶客，消息最多，适合把档案碎片续完。小游戏是泡茶、记茶钱、听书，参数见 `minigames.md`。不靠随机坏结果推进。

数量都是【待调】。

## 牌组清单

| 类 | 数量【待调】 | 机制 |
|---|---|---|
| 茶客（person，intent story 或 buy） | 8 | 坐下、点一壶、聊一件事。买的是茶，不是当铺的货 |
| 说书人（event，opens 听书） | 3 | 听完可以留一张消息，或给档案补一块 |
| 消息（news，rumor / letter） | 10 | 茶馆的主货。`keepable`，`on_read` 补碎片 |
| 茶账通知（demand，kind money） | 3 | 记茶钱结不清时变成一张通知，期限按天 |
| 生活（life） | 3 | 茶叶、炭、房租。几天内处理，回家吃饭仍可免坏处（沿用 `life`） |
| 风险 | 0 张随机惩罚 | 政策事件另表 |

### 条子在这里叫「茶账 / 通知」

| 当铺字段 | 茶馆 |
|---|---|
| kind | money（茶账）或 info（谁托你带一句话） |
| tier | 0–1 |
| deadline_days | 整数 |
| 办法 | 付钱，或把一张留着的消息交出去 |
| 不同处 | 不升到查封。到期没办成只是茶客不再来（`person_state` away，天数写明），不抓人 |

## 样例骨架

### 1. `p.zhouma.branch.tea_host`（person）

| 字段 | 值 |
|---|---|
| person | zhouma |
| intent | story |
| weight | 0 |
| schedule | 茶馆开张的第一天，order 1 |
| choices | 一个：听她把铺面的事说完，`dossier` 补一块；不听则这张牌仍须处理（`must_resolve` true），没有第二套惩罚 |
| brief | 周妈是茶馆这边的东家。开张那天她把谁会来、账怎么记说一遍。 |

### 2. `nw.branch.teahouse_rumor`（news）

| 字段 | 值 |
|---|---|
| kind | rumor |
| source | 某位茶客的人物 id |
| keepable | true |
| expires_days | 5【待调】 |
| must_resolve | false |
| effects.on_read | `dossier` 一块碎片 |
| brief | 茶座上的一句传闻。看过就收进档案，也可以留着交给要消息的通知。 |

### 3. `ev.branch.storyteller`（event）

| 字段 | 值 |
|---|---|
| must_resolve | false |
| choices | `listen`：花一笔整数茶钱（`money` delta 为负，原因键 `branch.reason.story`），然后 `add_card` 一张消息；`pass`：不听，没有别的效果 |
| 不放格子 | 听书的「过不过」在小游戏的观察里，不在铜钱正面里 |
| brief | 说书人开场。听就要付茶钱，不听就过去。观察键只记听到哪一段，不判对错。 |

## 老面孔

周妈从「来报信的人」变成茶馆东家，人脉还在就仍占一个人脉位。档案簿里的船家、邮差、旧主顾可以换成茶客再出现一次：同一 `person` id，另一张 `p.<id>.branch.*`，brief 写明现在的身份。不把已经「走了」的人硬拉回来，除非那张政策或生活牌写明他回来了（`person_state` 改回 ok）。
