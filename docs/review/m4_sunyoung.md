# M4 审计：顾客四 孙少爷（伪契）

范围：spec 678–709 行；data/sessions/d2_sunyoung.json, d2_sunyoung_real.json；data/items/deed.json；data/night.json；scripts/core/{director,session,world,ledger,cond}.gd；data/story/d2_ma.json。只读审计，未改游戏文件。
headless 验证：`not str(x) in [...]` 优先级已实测（director.gd:610 解析为 `not (x in list)`，无误）。

## 节拍表

| # | 节拍 | 状态 | 证据 | 说明 / 修复 |
|---|---|---|---|---|
| 1 | 入场 narr + 两句台词 | OK | d2_sunyoung.json `pre`, `intro` | 与 spec 逐字一致 |
| 2 | 伪红契 市价 0；要价/底价 3000/1000 | OK | deed.json deed_fake.market=0; sunyoung json ask 3000 floor 1000 | — |
| 3 | 钱匣约 100–350，收不起 | PARTIAL | 无机制保证 | 属于开局经济曲线，未在测试中断言。建议 validate_data 或 playtest 断言该节点现金区间 |
| 4 | 检查结果：业主/四至/官印/契尾 | OK（多一条） | deed.json deed_fake parts owner/bounds/seal/tail，外加 paper（茶渍做旧，`tell:true`） | spec 列 4 条，数据 5 条都算破绽。若要严格对齐，删 paper 的 `tell` 或在 spec 注明 |
| 5 | 四至：赵老三契看过则自动高亮 | MISSING | grep `saw_zhao` 仅出现在 deed.json:34 与 sunyoung.json:33；inspect_panel.gd 无高亮逻辑 | 见 Fix 1 |
| 6 | 选择：委婉推辞 → declined | OK | sunyoung.json deals[decline] | 台词与 spec 一致 |
| 7 | 当面拆穿 → exposed，本心+1，掏真契 | OK | sunyoung.json extras[expose] (line 25-32)；`when: tells('deed_fake') >= 2` | tells 只数已细看的破绽（session.gd:220-229），符合“至少两处” |
| 8 | 收下 → scammed，伪契无法赎卖 | PARTIAL（ledger 不成立） | sunyoung.json on_accept (line 53-57)；director.gd:521-527 普通 `open_pawn`；ledger.gd:129 `redeem()` 无 fake/无法赎检查 | 现金损失真实（open_pawn 扣钱匣，ledger.gd:104-115）。但合同是普通“在当”，30 天后按 tick_contracts 变满当（ledger.gd:148-162），书上仍像可赎的当票。见 Fix 2 |
| 9 | 假装答应 → bluffed，摔门 | OK | sunyoung.json deals[bluff] | — |
| 10 | 事后派人告诉孙老爷（夜间） | OK | night.json:88 tell_sun；director.gd:610 门禁；director.gd:639-646 效果 | 门禁允许 declined/bluffed/scammed/exposed，spec 表是通用行，可接受 |
| 11 | tell_sun 效果：孙府好感+5，孙少爷恨意+20 | OK（映射） | director.gd:641-643 `add faction:孙府 +5`、`favor sunlaoye +5`、`favor sunyoung -20` | 恨意落在 Mind.relate resentment 上，不是独立数值。见 Fix 4 |
| 12 | 真地契跟进（拆穿后） | OK（有缺口） | director.gd:936-937 queued_sessions；d2_sunyoung_real.json | 现金不足时只剩 cannot_afford；sun_real_pawn 无人读取（仅 real.json:25,30） |
| 13 | 被拆穿台词 | OK | sunyoung.json extras[expose].steps[0] | — |
| 14 | 马保长费用 150（exposed） | PARTIAL | director.gd:907-914 逻辑正确（li_paper=reported 优先于 exposed，符合 spec 723 行）；d2_ma.json:9 台词不管有没有告状都说“一百五” | 费用只看 flag，不看“是否真的告状”。见 Fix 3 |
| 15 | 孙少爷被拆穿后找马保长告状 | PARTIAL | world.gd:376-383 用 mind.decide（softmax + 种子随机，mind.gd:138-153），非确定 | 告状概率不是 100%；ma_heard_sun（world.gd:449）全工程无人读取，马保长对白没有反应。见 Fix 3 |
| 16 | 状态变量 sun_young / sun_told_father | PARTIAL | sun_young 取值全部正确；sun_told_father 仅写入（director.gd:640），无人读取 | spec 表写“孙府态度”，目前只有好感数字。见 Fix 4 |
| 17 | 人物表：先给伪地契，鉴别后给真地契 | OK | 上面 #7、#12 | — |

## 关键问题

1. 四至自动高亮缺失。`compare_zhao` 只是一个手动按钮（sunyoung.json:33-36），并且它写入的 `sun_bounds_contradiction` 没有任何读取方。spec 要求的是“自动高亮”。
2. 伪契收下后可以赎。`open_pawn` 产生的是普通活当合同，`redeem()`（ledger.gd:129）对 fake 物品没有任何拦截。目前没有 UI 调用 redeem，所以实际上不能赎，但合同仍会在 `tick_contracts` 中走到满当，且在书上显示为“在当”，与“伪契无法赎卖”不一致。
3. 马保长 150 与告状不一致。费用是确定的，告状是概率的。玩家可能看到“孙少爷已经告过状”的 150 而事实上没有告状。
4. 真地契的 `sun_real_pawn` 与 `sun_told_father` 都是死标记，没有后续影响。

## Fix list

1. 自动高亮：在 session 打开 d2_sunyoung 时，若 `world.flags.saw_zhao_bounds`，把 deed_fake 的 `bounds` 部件标记为 highlight（例如在 session.gd 打开 session 时设 `it["_hl"]={"bounds":true}`），inspect_panel.gd:155 渲染为高亮色并追加一句 narr“（你想起赵老三那张契：西至青溪河…）”。删除或保留 compare_zhao 按钮，但它不能是唯一途径。
2. 伪契 scammed：在 director.gd `_accept` 的 pawn 分支中，若 `it.fake` 且 `s.npc_id` 的当票是 sun 伪契，则 `world.ledger.contracts[tid]["unredeemable"] = true`；在 ledger.gd:129 `redeem()` 开头返回 false 当 `unredeemable`；tick_contracts 满当时在书上记“伪契，市价 0，已核销”。或更直接：scammed 时直接以 market 0 的死当入库，把本金记为损失（expense 行）。
3. 马保长：要么把 ma_fee 的 exposed 条件改为 `flag('ma_heard_sun')`（与 world.gd:449 同步），要么让 world.gd:376-383 对 exposed 确定性触发（去掉 mind.decide，或在 exposed 时 complain 必然成立）。另在 d2_ma.json:9 之后加一个 `if flag('ma_heard_sun')` 对白，让告状真的被看见。
4. 状态变量：在 world.gd 或 d2_ma 读取 `sun_told_father`，例如马保长对白“孙府那边也有人来过话”，或在 sunlaoye 好感 ≥ 阈值时开放孙府后续事件；否则在 README 标为 TODO。tell_sun 的“恨意+20”应在 README 说明映射到 resentment。
5. 真地契：在 d2_ma 或 night2 读取 `sun_real_pawn`（true 时孙少爷在第二天送来利息/赎当提示），或在 README 标注为 TODO。
6. 次要：deed.json deed_fake 的 `paper` 部件是数据额外的破绽，与 spec 的四条不一致，决定保留或删除。tell_sun 扣 5 蚨进“市场”账户（director.gd:644）spec 未提，确认是否接受。

结论：拆穿、推辞、假装、收下的分支和 tell_sun 的门禁与数值基本正确。需要修的是四至自动高亮（MISSING）、伪契不可赎的账本约束（PARTIAL）、马保长费用与告状的一致性（PARTIAL）。
