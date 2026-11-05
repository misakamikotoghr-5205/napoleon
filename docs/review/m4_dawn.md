# M4 审计：第二天清晨 · 哥哥教活当（2026-10-10，只读审计，未改游戏文件）

依据：/workspace/gamejev-docs/story_sub2_剧本提示词.md 第539–571行（清晨）、柜台界面布局（82–103）、数值与状态变量（799–815）、林嫂表（600）、farewell（661）。
实现：data/story/day2.json、d2_morning.json、pages.json、items/practice.json、director.gd、ledger.gd、ui/ticket_panel.gd、ui/main.gd、docs/INTERFACES.md §6/§11。
JSON 校验：上述数据文件全部通过 `json.tool`。

## 逐条 beat 表

| # | 设计稿 beat | 状态 | 证据 | 修复 |
|---|---|---|---|---|
| 1 | 哥哥：活当与买断不同，东西是人家的，到期带本钱利息来赎 | OK | d2_morning.json:5-9 | — |
| 2 | 当期三十天，月息三分；过期不赎归咱们 | OK | d2_morning.json:10-14；pages.json:19-22；ledger.gd:115,125 | — |
| 3 | 【实现】用铜手炉走一遍，不动用钱匣 | OK | d2_morning.json:23-37；director.gd:375-389 无 transfer/open_pawn；ticket_panel.gd:82 显示“不动用钱匣” | — |
| 4 | 步骤1 登记：当号自动编号、日期、当户、当物、成色（从鉴定结果选）、当本、到期 | PARTIAL | 字段齐：director.gd:391-397、ticket_panel.gd:79-80；成色不来自鉴定（见 Fix 3）；无“账簿登记”交互，票是脚本自动弹出（main.gd:335-337），账簿热点不开当票（布局表：账簿=登记/开当票/盖章） | 账簿热点可开当票；成色选项由已鉴定部位生成 |
| 5 | 步骤2 填当票：内容与账簿一致，一式两份，客人拿一份 | PARTIAL | 只画一张纸：ticket_panel.gd:25-32；按钮“客人拿走一份”（:67）但无第二份 | 画两联（客存/底存），盖章后可切换；交付时客存联 |
| 6 | 步骤3 盖章：拖动印章到当票上，有力度反馈 | PARTIAL | 是按钮不是拖拽：ticket_panel.gd:64,114-125（仅 tween 缩放）；无 sfx（stamp 未调用） | 印章可拖到纸上落点判定；落下时 `sfx stamp` + 震动 tween |
| 7 | 步骤4 交钱收物：钱从钱匣拨出，当物推进典当盒（练习：不动钱匣） | PARTIAL | 练习无钱流动：正确。但阶段文字写“钱从钱匣拨出”（ticket_panel.gd:111）且练习仍显示；物件进抽屉而非典当盒（director.gd:389）；stow 仅高亮典当盒（main.gd:339） | 练习时阶段文字改为“（练习）只推进典当盒，不动钱匣”；先移入 pawnbox 动画再 move 到 drawer |
| 8 | 哥哥：老规矩一律写“破旧”……满当了还能多卖几个钱 | OK | d2_morning.json:38-42 | — |
| 9 | 哥哥：爸从来不这么写……怎么写由你定 | OK | d2_morning.json:43-47 | — |
| 10 | 哥哥：我去济生堂……中午回来；哥哥离开 | OK | d2_morning.json:48-61（scene brother false，set brother_away） | — |
| 11 | 【实现】成色栏永远有“如实写”“照老规矩写破旧”两个选项 | OK | director.gd:396-397 两项恒有；ticket_panel.gd:87-91 前缀正确 | — |
| 12 | 【实现】成色选项来自鉴定结果 | WRONG | director.gd:396 `ticket_condition` 静态文本，与检查部位无关；练习只要求 ≥1 部位（inspect_panel.gd:226-228）；真实活当不要求任何鉴定（d2_linsao.json:20 min_inspect 0）→ 未验货就显示“足金，珠有小缺”（gold.json:19） | “如实写”文本由已检查部位的 text/tell 拼出；未鉴定前该项禁用；活当 session 增加 require |
| 13 | 【实现】写破旧：满当卖价 +15% | WRONG | director.gd:533-534 写入 item.market_bonus 即生效（world.gd:171 市价立刻 +15%，活当中就变）；满当不转卖：ledger.gd:157-161 只改 owner/pledged_to，location 仍 pawnbox，未进 stock，夜间卖货只看 stock（director.gd:669-675） | 加成在 tick_contracts 满当时施加，并 `move_item(iid,"stock","player")`（ledger.gd:157-161） |
| 14 | 【实现】写破旧：本心 -2 | OK | director.gd:532-533（仅 pawn 成交后执行） | — |
| 15 | 【实现】写破旧：当户发现时口碑 -3 | MISSING | 无待发记录：ledger.gd:116 只存 `ticket_old`；redeem()（ledger.gd:129）全局无调用者（grep 确认）；tick_contracts 不检查；仅 林嫂 对话设了 flag lin_ticket_old（d2_linsao.json:151-160） | 见 Fix 1 |
| 16 | 林嫂表：当票写破旧 → 她赎当时会发现（第32天） | MISSING | 第32天超出 v0.1 时间线（flow.json），无赎当 UI/逻辑；无“发现”触发 | 加 contract.pending_risks，或在 README 标 TODO 并保证到期前可触发 |
| 17 | 中午告别：若当天已写过“破旧”，哥哥说“……只是林嫂那张当票” | PARTIAL | d2_farewell.json:8 条件仅 `is('lin_ticket_old')`；赵老三（d2_zhao.json，上午）写破旧不触发；设计稿写的是“当天已写过破旧” | director.gd:530 旁加 `world.flags["day2_ticket_old"]=true`，d2_farewell.json:8 改判该 flag |
| 18 | 柜台布局：典当盒“拖进去入库”，不收“推回去” | PARTIAL | 点击代替拖动：main.gd:423-425；活当 stow 响应被忽略：director.gd:560-561；但垃圾箱仍高亮（main.gd:339）→ 点垃圾箱无效果 | 活当时不高亮垃圾箱；或 stow 真正 move |
| 19 | 数值：口碑公开、本心隐藏；破旧 -2 本心不记档案 | OK | world.gd:126-127（仅口碑写档案）；本心无档案 | — |
| 20 | INTERFACES §6：pawn 成交后 items→pawnbox，再由玩家点典当盒/垃圾箱 stow | PARTIAL | 物件在 open_pawn 就移入 pawnbox（ledger.gd:120），stow 的回应被丢弃（director.gd:561） | 二选一：去掉活当 stow，或让 open_pawn 不移动、由 stow 移动（同步改 INTERFACES §6） |

## 核对项

- 练习盖章不动钱、不建合同：**通过**。director.gd:375-389 无 transfer；ledger.gd:113 的 next_ticket 不被练习消耗；练习票号为“德字第〇号（练习）”（director.gd:393）。
- 成色选项来自鉴定：**不通过**（见 12）。
- 写破旧效果的可追溯性：**部分**。contract 记了 ticket_old 与 condition（ledger.gd:115-117），但没有待发（pending）记录，口碑 -3 无法被触发（见 15）。市价加成挂在 item 上而非合同上，不能随合同状态结算（见 13）。
- 练习不记写破旧效果：正确（practice_condition 仅存 vars，director.gd:387，无下游读取）。
- 活当 items 多件时，票只用 iids[0]（director.gd:522-525），名称与加成只算第一件。

## Fix list（按优先级）

1. 写破旧 pending-risk：在 ledger.open_pawn（ledger.gd:104-121）当 ticket_old 时写入 `pending_risks:[{stat:"koubei",delta:-3,trigger:"redeem|discovery",fired:false}]`；redeem（ledger.gd:129）与新的 discovery 钩子触发时 world.add("koubei",-3,…) 并记档案；补一个测试断言。
2. 满当不可卖（ledger.gd:157-161）：forfeit 时 move_item 到 stock；并把 market_bonus（director.gd:533-534）移到 forfeit 时施加，不在活当中改市价。
3. 成色来自鉴定：director.gd:396 生成 true 选项文本时取已检查部位；未检查时该项禁用；活当 session 至少要求一项鉴定（否则 d2_linsao 可零鉴定成交）。
4. 中午告别条件（d2_farewell.json:8）改为当天任意破旧 flag（director.gd:530 设置）。
5. 盖章与交付 UI：ticket_panel.gd:64 改拖拽印章；:114-125 落章时发 sfx stamp；:25-32 画两联；:111 练习文案分支。
6. 活当 stow 不一致：director.gd:560-561 与 INTERFACES §6 统一；活当时 main.gd:339 去掉垃圾箱高亮。
7. 练习物件推进典当盒后再回抽屉（director.gd:388-389）。
8. 多件活当：director.gd:522-525 票面与加成遍历全部 iids。
9. 练习票面当本显示 0 蚨（director.gd:385）改为示例金额并注明“不动钱匣”。
10. 自动化：autoplayer 与 plans 没有断言“练习后钱匣总额与 journal 不变”，加一条测试。
