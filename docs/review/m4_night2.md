# M4 审计：第二晚（夜晚系统 + 电报机）

范围：spec story_sub2_剧本提示词.md 741–784；data/story/night2.json、data/night.json、data/codebook.json；scripts/core/director.gd（telegraph、_free_telegraph、night_menu、_night_*、_deliver_orders）；scripts/ui/telegraph_panel.gd；scripts/ui/main.gd。方法：静态阅读（未运行）。

## 1. 节拍表

| 节拍 | 结论 | 证据 | 
| --- | --- | --- |
| 对账 ★ 不耗灯油 | OK | director.gd:624-625，night.json:5-9 cost 0 |
| 整理库房 ★ 库存 +5% | OK | director.gd:677-685，world.gd:171 计入 market_now |
| 烧垃圾 ★ | OK | director.gd:629、862-906 |
| 夜卖 70–85%，有流水 | PARTIAL | 倍率 director.gd:700 OK；流水 :709 OK。见 F6：买家余额不足时静默失败但仍耗灯油（废品摊仅 300，deed_zhao 2000 / deed_sun_real 9000 卖不动） |
| 定货 80%，次日送达，有流水 | PARTIAL | 价格 :728 OK；付款流水 :730 OK；送达 :348-356 OK，但见 F9：第三天才送到，而 flow.json 在第二晚后直接进 ending，玩家永远看不到 |
| 药品定货需陈叔叔信任 | OK | :715 `chen_trust>=2 or chen_med_supply`；:719 锁定文案 |
| 换门旗 | PARTIAL | 选择 :745-761 OK；门旗只影响 counter_view 画面（counter_view.gd:99），顾客不读 door_flag，spec“决定明天的顾客类型”MISSING（F8） |
| 换招牌 | PARTIAL | :763-771 强制换，无“不换”项；world.sign_board 无任何读取者（F8） |
| 发电报 每次怀疑 +1 恰好一次 | OK | 自由发报 sent_steps director.gd:780；剧情发报各分支 night2.json:12,18,25,30,36 各一次；“不回”不计（:39） |
| 发电报 消耗灯油 | PARTIAL | 不回/取消也扣灯油（director.gd:652-654，_free_telegraph 无返回值）（F7） |
| 写日记 本心<40 显示 +2 | OK | :608、:647-649；内容仅 3 条模板（:782-790），spec 要求“由当天选择生成”，PARTIAL |
| 电报机玩法：选词拼句、发送、译码 | OK | telegraph_panel.gd:107-120 译码；:118 最多 4 词；:153-159 发送 |
| 强制教学：指示灯闪三下、点柜子 | PARTIAL | night2.json:8-9；柜子高亮 counter_view.gd:115 + main.gd:420 OK；指示灯持续闪烁（telegraph_panel.gd:163），非“闪三下” |
| 20 个初始词、codebook | OK | data/codebook.json 20 词，编码唯一；山/湖 locked |
| 回电“平安”：信任+2，明天挂蓝旗 | PARTIAL | 信任 +2 OK（night2.json:13）；chen_says_blue 无任何读取者（night2.json:14），蓝旗不生效（F2） |
| 回电“维持会/钱”：信任+2，解锁应对建议 | PARTIAL | +2 OK（:19）；chen_ma_advice 无读取者，“应对建议”未解锁（F3）。可见的只有档案簿消息（:22） |
| 回电“需要/药”（库存没药）：明日来，第三天济生堂代卖开放 | WRONG | 门控正确（:24 `stock_cat('medicine')==0`）；但 chen_med_supply（:26）立即让今晚的定货开放，spec 为第三天；无可见消息（F4） |
| 回电“有人/药”：标记 chen_knows_wangshan | PARTIAL | 标记 :32 写入，但无读取者，无档案簿条目，玩家看不到（F5） |
| 不回：信任-2 | OK | :38-40 |
| 未匹配回电：合理默认 | OK | 默认 +1 怀疑并回“收到”（:35-37）；“需要/药”门控不通过时也落到默认（telegraph() director.gd:822-828） |
| 自由发报“需要/药”不门控 | WRONG | director.gd:777 无 `when`，任何时候发“需要 药”都会置 chen_med_supply，绕过信任门槛（F1） |

## 2. 其它发现（已核实）

- 自由发报“危险”行（:776）无任何后果，仅可接受。
- tell_sun（director.gd:639-646）不在 spec 741–784 表内；night.json:92 的描述“孙府好感+5，恨意+20”与代码 `favor("sunyoung",-20)` 不完全一致，需设计确认。
- 夜卖“不收”（:703-705）也消耗灯油；建议在可卖判断前不计费。
- 定货标签硬编码 90 / 24（:714、:717），应从 db.items 读取，避免改价后错位。
- 送达的货物未写 cost（:352），与 :520 的买断口径不一致（当前 cost 无读取者，低优先级）。
- 本审计未跑 headless 验证；autoplayer 计划（scripts/tests/autoplayer.gd:297）默认只走一条路径，各回电分支未被断言覆盖。

## Fix list

- F1 director.gd:777（_free_telegraph 的“需要/药”行）：在“需要/药”行加 `"when": "stock_cat('medicine') == 0"`，且不要在无门控时置 chen_med_supply。
- F2 night2.json:14 后加 `{"op":"call","fn":"set_door_flag_next","args":{"id":"blue"}}`（director.call_hook 新增：world.door_flag_next=id，flags["door_flag_next"]=id，note“陈叔叔：明日挂蓝旗”，source heard, via chen）；并让顾客/画面（或至少一条档案簿消息）真正体现。
- F3 night2.json:20 后加 `{"op":"page","id":"ma_advice"}`，在 pages.json 新增该页（内容：陈叔叔对维持会的建议）。
- F4 night2.json:26：改为 `"set chen_med_supply_day = day+1"`，director.gd:715 的门控改为 `world.day >= chen_med_supply_day`；加 note“陈叔叔回电：明日 来。济生堂代卖从第三天起可以托进货。”。若设计坚持今晚可定，则需在 spec 修订并记录。
- F5 night2.json:32 后加 `{"op":"note","kind":"线索","text":"陈叔叔的回电里提到“有人”“药”，他似乎认得王山。","source":"inferred","via":"chen"}`。
- F6 director.gd:693-711：_night_sell 在出价前检查 `world.ledger.balance(buyer) >= p`，不足则 narr“后门的钱不够，收不下”并返回 false；night_menu 对返回 false 的动作不扣灯油。同时确认 deed 是否应卖给废品摊（设计问题）。
- F7 director.gd:773-780、:652：_free_telegraph 返回是否发出；仅发出时才扣灯油（“不回”不扣）。
- F8 director.gd:763-771：_sign_choice 增加“不换（保持当前招牌）”选项；并在 world.gd 或顾客选择处读取 sign_board / door_flag（否则在报告中标注为未实现）。
- F9 director.gd:348-356、:733-736：订单写入 "_orders" 后在夜里菜单/账本显示“在途：X，明早送到”；送达时 items[iid].cost 写入付款额。若 v0.1 不做第三天，则需在 ending 前给出一句“在途货物”提示，或在 README 标 TODO。
- F10 telegraph_panel.gd:163：加一个计数，前三次闪后常亮（符合“闪三下”）。
- F11 director.gd:714、717：标签价格从 db 读取（去掉硬编码 90 / 24 / “两瓶”口径检查）。
- F12 scripts/tests/autoplayer.gd 计划：补一条第二晚计划，覆盖 4 个回电分支 + 不回 + 自由发报两次，断言 suspicion 增量=发报次数、chen_* 标记、灯油扣减、夜卖流水条数。
