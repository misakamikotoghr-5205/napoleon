# M3 审计：王山（买药品）支线

审计范围：data/sessions/d1_wangshan.json、data/items/medicine.json、data/cast.json(wangshan)、
scripts/core/director.gd（run_session 392、_offer 471、_accept 497）、scripts/core/session.gd（_setup_sell 82、_rescale_sell 97）。
对照：story_sub2_剧本提示词.md 第 444–475 行、人物表 211 行、势力 232 行、状态变量 823–825 行。
headless 检查：`godot --headless -s res://scripts/tests/validate_data.gd` → DATA OK（数据能加载，但不覆盖以下逻辑）。

## 逐拍对照

| 拍 | 结果 | 证据 |
| --- | --- | --- |
| 哥哥教学句 + 算盘 tutorial | OK | d1_wangshan.json pre:4-5 |
| 午后入场（先扫门外，再扫柜台） | OK | pre narr |
| 王山台词「有药吗…」 | OK | intro:2 |
| 只卖库存中的药 | 部分 | intro:18 用 `stock_cat('medicine')==0`，不是三种可卖药；见 Fix 3 |
| 三个观察（绑腿/纱布/口音） | OK | extras obs_wrap/obs_bandage/listen_accent；只记一次「像是当兵的」，source=inferred（SOURCE_CN 推测） |
| 出价 奈宁 80 | OK | buyer_prices.quinine 80/90 |
| 出价 磺胺 100（不知假） | OK | sulfa_fake 100/110 |
| 出价 红药水 每瓶 12 | 不符 | mercuro offer 12；medicine.json 该物品是「两瓶」，market 24。按「每瓶12」应为 24（见 Fix 4） |
| 问哪里人 | OK | extras ask_origin |
| 告诉磺胺是假的 → 势力 +5 | 部分 | extras tell_fake:49。无 tells/judged 门槛，未鉴定也能说；见 Fix 2 |
| 白送奈宁：本心+3 势力+8 怀疑+1 | 部分 | deals gift_quinine:65-70 三项正确 |
| 白送奈宁：钱 -60（成本） | 缺失 | gift_quinine 无 money 步骤。Fix 1 |
| 现钱卖出：怀疑+1，wangshan=sold | OK | on_accept:76-78，director _accept sell 分支 |
| 借条：现钱40 + 借条60，势力+5 | OK（有隐患） | iou_quinine:57-64。ledger.open_debt(cash_moves=false) 不凭空造钱；借条进档案簿（director debt 分支）。隐患见 Fix 6 |
| 假磺胺当真卖：钱+100，本心-6，flag | 有条件正确 | on_accept:79-82；但见 Fix 2 与「设计歧义」 |
| 拒卖 → refused | OK | deals refuse；on_leave 同样设置 |
| 没药 → nostock | OK | intro:18-22；但 post 仍播放（低优先级） |
| 王山走后哥哥低语 | OK | post:87-89 |
| 第5天王山带人回来 | 未实现 | sold_fake_to_wangshan 只被 day1_close 的哥哥台词读取，无第5天内容 |

## 可达性回答

1. 只有 sulfa_fake 在库存：可达。intro 的 stock_cat 通过，_setup_sell 把它加入 item_ids 并以 100 报价，可以现钱卖出并触发 sold_fake_to_wangshan。但玩家若先「告诉他是假的」，磺胺被 deselect，之后只剩「拒卖」一条路（单物品时 UI 不显示勾选框，director/inspect_panel:113，无法重选）。设计稿未说明此时他是否还买，建议写明。
2. 奈宁走借条：是。现钱 40 由 money 步骤从 wangshan(账户现钱200) 转给 player；60 只通过 debt(cash=false) 记为 outstanding 借条，不动现金；档案簿有一条「借条」。账本守恒成立。
3. 现钱卖出且磺胺未选中：怀疑 +1 只执行一次（on_accept 只跑一次）。正确。
4. 没有药（zhang_deal=false 或全部取消勾选）：走 nostock，不卡死。但 intro 的 gate 过宽（见 Fix 3）。

## 设计歧义（需要用户决定，不是纯 bug）

- 「把假磺胺当真的卖」(-6)：现实现为只要 selected('sulfa_fake') 且未告诉王山就 -6，不看玩家是否鉴定过。玩家从没查过磺胺也扣 -6。
  文档用词是「当真的卖」，可解释为「明知假仍当真卖」（只在 tells>=1 或 judged_fake 时 -6），也可解释为「不论知情与否都算」。建议二选一并写进设计稿。
- 「他不知道是假的」与玩家是否知道：报价 100 是针对王山（他不知）；玩家知情与否不影响王山价格，这点实现一致。
- 借条面额：设计稿「现钱 80，或现钱 40 + 60 蚨借条」合计 100，比现钱价多 20。实现照做。若是有意的（借条是未来的钱），请在稿里注明，否则按 80 拆。
- 状态值 `wangshan=gift` 在设计稿状态表(823)中没有，应补进表里。

## Fix list（按优先级）

1. [高] 白送奈宁缺少 -60 成本。d1_wangshan.json:65-70 的 gift_quinine 增加 `{"op":"money","from":"player","to":"济生堂柜","amount":60,"reason":"白送奈宁的成本"}`，并在 deal 上加 `"when":"stock_has('quinine') and cash() >= 60"`（否则 money 静默失败、money_ok=false，但白送照样发生）。目标账户由设计者定（济生堂柜或市场都可以，须是 outside_accounts 里的账户）。
2. [高] 告诉后可以重新勾选磺胺卖出，且无 -6。d1_wangshan.json:79 的条件 `selected('sulfa_fake') and not is('told_wangshan_fake')` 让告知过的假磺胺可以无代价卖出，相当于对已知情的买家卖假货却没有后果。修复：
   - on_accept 的条件去掉 `not is('told_wangshan_fake')`，改为 `selected('sulfa_fake')`（告知后仍卖，就是明知故卖，扣 -6）；或者在告知后禁止勾选（推荐：告知后 `set` 一个 `wangshan_refuse_fake` 标记，并在 _offer 前拒绝含假磺胺的报价）。
   - tell_fake:49 的 `when` 加上 `and tells('sulfa_fake') >= 1`，否则没鉴定也能告知并拿 +5（与 d1_zhang tell_fake 的写法保持一致）。
3. [中] intro 的 nostock 判定过宽。d1_wangshan.json:18 用 `stock_cat('medicine')==0`，库存里若有阿司匹林/碘酒/真磺胺，会进入柜台却无可卖项（只能拒卖）。改为 `"cond": "not (stock_has('quinine') or stock_has('sulfa_fake') or stock_has('mercuro'))"`。
4. [中] 红药水报价。medicine.json 的 mercuro 是「两瓶」，market 24。buyer_prices.mercuro(d1_wangshan.json:9) 改为 offer 24 / max 26，或按设计稿「每瓶12」把物品改成一瓶。
5. [中] 奈宁的两个 deal 忽略勾选状态。iou_quinine:57 与 gift_quinine:65 只检查 stock_has('quinine')，玩家取消勾选奈宁后仍会移交并收钱。两处 `when` 加 `and selected('quinine')`。
6. [中] 借条 due_day 缺失。iou_quinine:60 的 debt 没有 due_day，ledger.tick_debts 的条件 `due_day > 0` 使它永远不逾期，「借条能否兑现」（设计稿 824）无从推进。加 `"due_day": <day+30>` 或在设计稿里注明无期限。
7. [中] 「把假磺胺当真卖」的知情判定（见设计歧义）。在 Fix 2 之外，定下是否要区分「不知情卖出」（不扣本心但仍置 sold_fake_to_wangshan，哥哥台词照常）。
8. [低] 夜里电报「有人 / 药」（王山来过）未校验王山确实来过。night2.json:29 的 words 项加 `"when":"flag('wangshan') == 'sold' or flag('wangshan') == 'refused' or flag('wangshan') == 'gift'"`。
9. [低] nostock 路径仍播放 post 哥哥低语「那人腿上打着绑腿」。post 可加 `when: "var('result') != 'nostock'"`，或让哥哥说另一句。
10. [低] 第5天王山带人回来未实现。sold_fake_to_wangshan 目前只影响第一天打烊台词。记入 README 的 TODO，或在 day 5 内容里补。
11. [低] 状态表缺 `wangshan=gift`，设计稿 823 应补。

## 不需要改动

- 哥哥教学、入场、台词、三个观察、问来路：与设计稿一致。
- 现钱卖出、借条（不凭空造钱）、拒卖、哥哥低语：与设计稿一致。
- cast.json 的 wangshan 人设（cash 200、traits、lines）与人物表一致；无 needs 字段时 mind.gd:75 会取默认 0.25，可接受。

## Re-check (M3 after fixes)

证据：当前 data/sessions/d1_wangshan.json 与 scripts/core/director.gd、inspect_panel.gd。headless：d1_tell_wangshan_fake、d1_sell_fake_knowingly、d1_wangshan_refused、d1_loan_nostock_kept、d1_gift_quiet_xiaoding、d1_fair_swap 等 plan 与 --until=day1_done 全部 PLAYTHROUGH OK（代码路径已读，但上述 plan 未覆盖“告知后重新勾选磺胺”）。

| Fix | 状态 | 证据 |
| --- | --- | --- |
| 1 白送奈宁 -60 | ACCEPTED-AS-DECISION | gift_quinine(:65-72) 仅 move_item 到 npc:wangshan，无 money；note“进价约 60 蚨”seen |
| 2 告知后可卖假货无代价 | STILL OPEN | on_accept:82 仍有 `and not is('told_wangshan_fake')`；告知只 deselect（:53），单件外 inspect_panel.gd:113 多件时显示勾选框，可重新勾选卖出，-6 不扣 |
| 2b tells 门槛 | RESOLVED（等价） | found_fake_sulfa 只由 tell:true 部位置位（medicine.json:173/187/201），`is('found_fake_sulfa')` 即 tells>=1；建议仍改成 tells('sulfa_fake')>=1 与 d1_zhang 一致 |
| 3 nostock 判定 | RESOLVED | intro:18 改为三种可卖药的 not stock_has 组合 |
| 4 红药水报价 | RESOLVED | buyer_prices.mercuro offer 24 / max 26（:9），按“两瓶”item 即 2×12 |
| 5 奈宁 deal 忽略勾选 | RESOLVED | iou_quinine(:57) 与 gift_quinine(:65) `when` 均含 selected('quinine') |
| 6 借条 due_day | RESOLVED（待确认） | debt(:60) due_day 9，ledger.tick_debts(:215) 现可触发；9 非设计稿数值，建议与 director.gd:395 的 day+30 统一或请设计者定 |
| 7 知情判定 | STILL OPEN | 决定“只有明知才 -6”，但告知后仍可明知卖出而不扣，与决定冲突（同 2a） |
| 8 夜2“有人/药”校验 | STILL OPEN | night2.json:29 的 words 项仍无 when |
| 9 nostock 仍播哥哥低语 | RESOLVED | post 带 when `var('result') != 'nostock'` |
| 10 第5天王山带人 | RESOLVED（记为 TODO） | README_CN.md:46 已列为未实现；无第5天内容 |
| 11 设计稿状态表缺 wangshan=gift | STILL OPEN（设计稿） | story_sub2 第 823 行仍只列 sold/refused/nostock；本复核未改文档 |

决定核对：
- 白送=库存出库：ACCEPTED。
- 本心-6 仅明知卖出：NOT MET（见 2a/7）。修法：on_accept 的 -6 条件改为 `is('found_fake_sulfa')`（去掉 not told），或告知后 set `wangshan_refuse_fake` 并在含假磺胺时拒绝报价。
- 孙记 line 仅未换袋：ACCEPTED（day1_close.json:33）。
- 垃圾翻走仅违禁品：ACCEPTED（director.gd:787-797）。

NEW：
- N1 [中] 告知后重新勾选再卖，会同时触发 day1_close.json:81 的“（他很久没说话。）……爸要是在”而无 -6，两者不一致。随 2a 一并修。
- N2 [低] d1_wangshan 的借条到期第9天，到期后无后果（ledger 只改状态）。需在设计上定后续，否则只是档案簿里的一行。

