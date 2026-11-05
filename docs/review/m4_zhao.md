# M4 审计：顾客三 赵老三（活当红契）

审计范围：只读。对照 /workspace/gamejev-docs/story_sub2_剧本提示词.md 第 624–654 行、五、纸契文书、打折规矩、人物表、数值表 zhao_pawn。
未做 headless 实跑（见文末“未验证”）。

## 节拍表

| 节拍 | 判定 | 证据 | 说明 / 修法 |
| --- | --- | --- | --- |
| 入场叙述 + 2 句台词 | OK | data/sessions/d2_zhao.json `pre`、`intro` | 与原文一致 |
| 要价 300 / 底价 300，建议 600，市价 2000 | OK | d2_zhao.json `ask/floor/suggest`；deed.json `deed_zhao.market=2000, suggest=600` | 600 = 30%，正确 |
| 少一个不行（hard_floor） | OK | session.gd:369-375 `_offer_buy`，counter 文本 "%d。少一个不行。" | 只透露 300，与台词一致，不泄露额外隐藏信息 |
| 压到 300 以下 → 他走了 | PARTIAL | session.gd:371 `if rounds >= 3` 才 leave | 原文是“压到 300 以下他就走了”，现在要第 3 次低价才走。二选一：改成 `rounds >= 1`，或在设计稿注明是缓冲 |
| 压价后 本心 -3 | OK | d2_zhao.json `on_leave` 第 1 条 stat -3 | |
| 压价后 “儿子下落变成悬念” | WRONG | d2_zhao.json:46 `zhao_son_unknown=true`，全工程无读取；world.gd:410-425 中午无钱即孙府 400 收地，下午 425 自动赎人 | 悬念在引擎里被立即解掉了。见修法 F1 |
| 按 300 成交 → zhao_pawn=300 | OK | d2_zhao.json `on_accept` (300–399 分支) | 额外把 301–399 也记为 300，原文未定义，可接受 |
| 主动给 400–600 → 本心+3 口碑+3，generous | OK | d2_zhao.json `on_accept` (>=400 分支) | 无上限：给 1000 也是 generous 且不增加“现金压力”，原文“高于太多”未实现，轻微 |
| 400–600 可达性 | RISK | director.gd:493 `v > world.cash()` 拦截；按 600 - 第一天买入约 150 - 林嫂 150–160 + 周妈 0–70 估算，赵老三时点现金约 290–450 | 现金低于 400 时 generous 基本不可达；低于 300 时根本无法成交（见 F3）。需 headless 打印 d2_zhao 时点 cash 验证 |
| 拒收 → zhao_pawn=refused，本心 -2 | OK | d2_zhao.json `deals[refuse]`；sidebar.gd:292 有 deals 时隐藏通用“推回去” | 走的是 deal 而非 on_leave，数值正确 |
| 4 个结果行 | OK | d2_zhao.json `on_accept` / `deals` / `on_leave` | |
| 伏笔：东边是孙家地 | OK | d2_zhao.json `post` (source inferred)；deed.json `bounds` 设 `saw_zhao_bounds`，d2_sunyoung.json:33 `compare_zhao` 消费 | |
| 中人画押 “沈……” 彩蛋 | OK | deed.json:46-48 witness 部位文本 | 没有 flag，只在看时给信息，够用 |
| 检查部位 5 项（业主/四至/官印契尾/中人/纸张） | PARTIAL | deed.json deed_zhao 只有 owner/bounds/seal/witness 四项（seal 37、witness 46 之后直接结束） | 缺“纸张”。只有伪契 deed_fake 有 paper（deed.json:105）。见 F5 |
| 红契 ticket_condition | OK | deed.json `deed_zhao.ticket_condition = "红契一张，契尾齐全"` | 原文未给字面，合理 |
| 红契 30% / 白契 15% 折率 | PARTIAL | suggest=600 正确；但全工程没有白契定义，折率表无 15% 用例 | 白契不在第二天剧本里，低优先级。见 F6 |
| zhao_pawn 数值表 “赵家儿子、孙家收地” 后续 | MISSING | grep zhao_pawn：只有 d2_zhao.json 写入，无读取 | 第三天起没有任何分支读它。见 F8 |
| 中午孙府收地（伏笔：到期赎不回才孙府来买） | WRONG | world.gd:410-420：余额 <300 即当天中午 400 卖给孙府，不等到期 | 与“到期赎不回”不符，且拒收/压价路径也触发。见 F1、F9 |
| 下午赵老三赎子（余额≥300 才付 300） | OK | world.gd:425-430；loc_override 2_4 桥头街 | 只有玩家付了 300 或给到 400 以上（generous）才会赎人 |
| 街景：儿子被放 | OK | world.gd:453-454，第二天傍晚“一瘸一拐”的后生 | 玩家可见 |
| 街景：卖地 | PARTIAL | world.gd:455-456 “低着头，烟杆没点”，无契纸/卖地含义 | 玩家几乎看不出卖了地。见 F7 |
| 卖地 玩家可见记录 | MISSING | world.gd:35 world_log 注释“玩家看不到”；卖地只写 world_log（420）和 rumor（471，需要熟人来访才传出） | 玩家没有档案簿记录。见 F7 |
| 卖地交割安全性 | OK（现状） | world.gd:416 `_item_of("zhao","deed_zhao")` 不检查 pledged/location | 目前只有余额<300 才会走卖地，而那时契还在 npc:zhao 手上，安全；但脆弱，建议加 pledged_to=="" 检查 |

## 账本合规
- 孙老爷 5000（cast.json sunlaoye），支付 400 合规，不凭空造钱。赵老三账户 0，零钱闭环 OK。
- 赎人 300 从 zhao 转到 保安队（world.gd:426），保安队 0 账户入账合规。
- 红契 1 件，卖出后 owner 变 sunlaoye，无重复。

## Fix list
- F1 (WRONG, world.gd:410-420, 425-430)：卖地与赎人只应由“玩家付了 300 / generous”驱动。若 zhao_pawn == "refused" 或 zhao_son_unknown，则跳过中午卖地（条件加 `flags.get("zhao_pawn","") != "refused"`），下午不赎人，街景加一条悬念句（如“赵老三站在保安队门口，没有进去”）。
- F2 (PARTIAL, session.gd:371)：`rounds >= 3` 改为 `rounds >= 1`（与原文“他走了”一致），或在设计稿注明缓冲。
- F3 (RISK, director.gd:493)：赵老三场景下若现金 <300，不要用 `_offer` 的拦截文案当作失败，并且不应扣 本心 -3。加分支：提示“钱匣里不够三百”，给出可选“去孙府/借钱”或直接不计惩罚地结束。
- F4 (RISK, data/sessions/d2_zhao.json `on_accept`)：如果 headless 验证 generous 不可达，把阈值降到 350，或在设计稿注明现金门槛。
- F5 (PARTIAL, data/items/deed.json, deed_zhao.parts)：在 witness 之后加第 5 项 `{"id":"paper","label":"看纸张","text":"纸是旧的，边角发黄，印泥是陈的，是真契。","tool":"hand","rect":[6,4,44,56]}`，不带 tell。deed_sun_real 同样可补。
- F6 (PARTIAL, data/items/deed.json)：如需覆盖“白契 15%”，补一个 deed_white 定义（cat deed，suggest=市价的 15%）。低优先级。
- F7 (MISSING/PARTIAL, world.gd:416-420 与 455-456)：卖地成功后 `note("消息", "赵老三把一亩二分水田以 400 蚨卖给了孙府", "seen")` 写入档案簿；街景文本改为“孙府的人从他手里接过一卷红契”。
- F8 (MISSING, 全工程)：给 zhao_pawn 加消费方。至少：refused → 第三天孙府来问契（对应伏笔）；300/generous → 孙少爷或马保长对话里提到赵家。
- F9 (WRONG 伏笔, ledger.gd:160 满当)：删除“中午卖地”的捷径，改为“到期 + 宽限后满当，孙府来买”，由 ledger 的满当回调触发 sunlaoye 收购，保持到期语义。

## 未验证
- 没有跑 headless 或 GUI。现金估算是推算，需要 `scripts/tests/run_playthrough.gd` 在 d2_zhao 前打印 `world.cash()` 确认。
- 没有截图确认卖地/赎人街景的可读性。
