# M3 审计：张护士（d1_zhang，收药品）

审计范围只读：data/sessions/d1_zhang.json、data/items/medicine.json、data/medbook.json、data/pages.json（med_rules）、data/cast.json（zhang）、scripts/core/{director,session,cond}.gd、scripts/ui/{inspect_panel,book_panel}.gd、scripts/ui/main.gd。
无头探针（在 /tmp/zprobe，未改游戏文件）：probe.gd（改价）、probe2.gd（还价，多 seed）、rects.gd（部位热区像素核对）。

## 节拍表（设计稿 vs 实现）

| # | 节拍 | 实现位置 | 结论 |
|---|---|---|---|
| 1 | 哥哥进库房取册子，放柜台右侧（narr） | d1_zhang.json pre[0] | OK |
| 2 | 哥哥台词“药是救命的…批号一定要对着册子看” | pre[1] | OK，文字一致 |
| 3 | unlock medbook，page med_rules 进档案簿 | pre[2-3]；world.gd:176 | OK。无 tutorial 高亮，玩家不知道去点哪（建议，非必须） |
| 4 | 鉴别录可翻页（规则页 / 6 味药 / 末页假批号） | book_panel.gd:223-241，共 8 页，_nav 翻页 | OK |
| 5 | 并排对照（册子与验货面板同屏） | main.gd:470-475；layout.json:16 | MISSING。见下“P1-3” |
| 6 | 点批号 / 封口 / 厂名；拖出一片药 | 部位热区 rect 均命中实心像素（rects.gd）；药片为“倒一片看”按钮，无拖动 | PARTIAL。点击可用，拖动未做（设计稿写“或”，可接受） |
| 7 | 张护士进门（narr）+ 两句台词 | d1_zhang.json intro[0-2] | OK，文字与设计稿一致 |
| 8 | 整批 260 / 底价 150；拆开按样出价 | 见下表；split:true；inspect_panel.gd:112-121 | OK（数值），但见“P1-4” |
| 9 | 额外：告诉她磺胺是假的 | extras[tell_fake] | OK（文字、+2、note、rumor、140/90）。有 P1-1 缺陷 |
| 10 | 额外：问还有没有别的药（吗啡） | extras[ask_more] | OK，设 zhang_morphine_hint |
| 11 | 离开前台词 | outro（director.gd:451 无论成交与否都会执行） | PARTIAL。见 P2-5 |

## 批号与假货判定

规则（medbook.rules）：厂码一致、日期早于民国二十七年二月、四位序号且不在假批号表。

| 药品 | 标签批号 | 厂码/厂名 | 日期/效期 | 序号 | 真相 | 市价 | 建议收购价 | 结论 |
|---|---|---|---|---|---|---|---|---|
| 奈宁片一瓶 | HC 26·10 0517 | HC=海昌 | 26·10，3 年 | 0517 不在表 | 正品 | 100 | 60 | 合规 OK |
| 红药水两瓶 | HM 26·12 2203 | HM=华美 | 26·12，1 年（至 27·12） | 2203 不在表 | 正品 | 24 | 14（24×60%=14.4） | 合规 OK |
| 磺胺粉一盒 | DT 26·08 0007 | DT=德泰 | 合规 | 在假批号表 | 假 | 0 | 0 | 假，与设计稿一致 |

- 三者 item 数据（batch 文本、market、suggest 74 = 60+14+0）与设计稿表一致。
- 能否纯靠鉴别录认假：能。批号可对末页假批号表，铁盒可对“厂标凹印”，粉末可对“纯白无味”，三条独立线索都在册子内。
- 但游戏中“批号”部位的 tell 只看是否点过（session.gd:196-204），不是看玩家是否对照过册子，见 P1-2。

## 价格（headless 实测）

| 状态 | ask | floor | suggest | 备注 |
|---|---|---|---|---|
| 初始（整批） | 260 | 150 | 182 | 建议价按未判假磺胺的 claimed 108 计（calc_buy_suggest），与设计稿“磺胺建议 0”不符，见 P1-4 |
| 拆掉磺胺（ask_w 130/40/90，r=170/260） | 170 | 98 | 74 | 合理，但底价 98 高于建议价 74 |
| 告诉她后（reprice 140/90），磺胺仍选中 | 140 | 90 | 74 | 与设计稿一致 |
| 先拆磺胺，再告诉她 | 140 | 90 | 74 | 错：应为 92 / 59，见 P1-1 |
| est | [75,160] | | | 只覆盖两件真药，未含磺胺；与其它 est 规则不一致，见 P2-8 |

还价（probe2，默认 seed 19380306，磺胺拆掉）：出 74 → plead（不走）；出 60 → leave。其它 seed：出 74 有时直接 leave（seed 3、5）、有时 counter。整批出 100 → plead，不走。即“低于底价她仍走”取决于 seed，不保证。

## 四个结果行

| 设计稿结果 | 实现 | 结论 |
|---|---|---|
| 没发现假货，整批收 → fake_sulfa_in_stock=true | on_accept 第 1 条（selected 时置位） | OK。但“发现了假货却整批收”没有任何标记或本心变化，设计稿未写，需确认 |
| 发现假货但不说，只收真药 → 本心-1，zhang_told=false | on_accept 第 2、3 条（tells>=1 且未告诉且未选磺胺） | OK（逻辑正确）。前提是 tells 按点击计，见 P1-2 |
| 发现假货并告诉她 → 本心+2，zhang_told=true | tell_fake：stat benxin +2、note 消息/听说/张护士、rumor fake_hospital（world.gd:376 有定义）、reprice | OK。reprice 在拆磺胺后会错价，见 P1-1 |
| 压价低于底价她仍走 → zhang_deal=false，王山 nostock | on_leave 置 zhang_deal=false（OK）；王山 intro 用 stock_cat('medicine')==0 判 nostock（d1_wangshan.json intro，间接成立，因 d1_li 无药品） | PARTIAL。zhang_deal 全工程无人读取；走人不是确定事件（见上） |

离开台词：outro 在 run_session 里无条件执行（director.gd:451），低价走人后她仍说“你小小年纪，眼力倒好”，语气不对。

## Fix list（按优先级）

P1-1 session.gd:272-278 reprice() 直接把 ask/floor 设为整批值，忽略当前选中项。实测：拆掉磺胺后 reprice(140,90) 得 ask=140，下次点选才变成 92。
  修法：reprice 里只写 base_ask/base_floor（和 suggestion 若 >=0），然后调用 _rescale_ask()（split 时）；不要直接写 ask/floor_v。

P1-2 tells 按“点过批号”计数（session.gd:196-204；medicine.json sulfa_fake.parts.batch.tell=true）。玩家只读了批号、没对册子，就能解锁“告诉她”并触发后续结果。
  修法：给 batch 加门槛，例如只有 book 的末页（假批号表）被看过（book_panel 写 world.flags.medbook_last_seen）后，batch 的 tell 才计入；或把 tell 改为单独的 part“对照假批号表”，用 book 工具且 text 含“已在假批号之列”。

P1-3 并排对照不可达。book 打开时 Rect2(40,16,880,508)（main.gd:122,473-475 的 else 分支）；验货面板 Rect2(20,14,920,512)，两者都是 STOP 的 overlay，册子会挡住柜台与验货面板。药材册子按钮在 layout.json:16 的 [270,132,36,16]（若柜台 3 倍缩放约为 x 810–918、y 396–444），被验货面板盖住，所以 main.gd:472-474 的“验货开着时打开册子”分支鼠标无法触发。玩家只能先合上验货面板，开册子，合上，再开验货；“并排”做不到。册子也只有文字，没有标签/封口/药片特写。
  修法：在 inspect_panel 里加一个“册”按钮，点击后把 book 放到右侧（如 x 560–940）并把验货面板左侧收窄或让左半区保持可点；同时把验货的 findings 与部位按钮留在 book 之外。美术方面补 art/items/book_*.png（见 P2-9）。截图核对：需在 DISPLAY=:5 下实拍 inspect + medbook 同屏。

P1-4 建议价与设计稿不符（需确认）：设计稿表中磺胺（假）建议收购价=0，合计 74。现代码（session.gd calc_buy_suggest）对未判假的磺胺按 claimed 180 计，初始显示建议 182，拆掉或判假后才是 74。结果：初始建议 182 高于底价 150，照建议价出价会成交，但等于替假药付钱；而按真相的 74 又远低于底价 98/150，照真相出价永远不成交（实测 74 → plead/counter/leave）。二者都需要你确认设计意图。
  修法：先定建议价口径（真相口径 = 设计稿，或认知口径 = 现代码）。若用真相口径，撤销 calc_buy_suggest 的 claimed 分支。底价与建议价的距离二选一：(a) 底价压到约建议价×1.1–1.2；(b) 保留数值，并在 UI 上说明“建议价不是她肯出的价”。

P2-5 outro 无条件执行（director.gd:451）。修法：d1_zhang.json outro 每条加 "when": "is('zhang_deal')"，另加一条 "when": "not is('zhang_deal')" 的离开台词（如“（她头也不回地出了门）”）。

P2-6 zhang_deal 无人读取。d1_wangshan.json intro 只看 stock_cat('medicine')==0。修法：改成 "cond": "stock_cat('medicine') == 0 or not is('zhang_deal')"，让设计稿的条件显式可读。

P2-7 低于底价不必然走人（session.gd:315-316，probe2 实测整批出 100 → plead）。修法：lowball（v < 0.6*floor）且 rounds>=2 时确定 leave；或在 d1_zhang 加 min 规则。

P2-8 est 不一致：d1_zhang.json est [75,160] 只含两件真药，而 medicine.json sulfa_fake.est=[140,200] 且 market 0。假货的 est 不该是 140–200。修法：lot est 改为 [214,350]（未验货时的真实估计范围），sulfa_fake.est 改为 [0,60]（或直接 [0,0]）。

P2-9 鉴别录的 sprite（medbook.json pages[*].sprite = art/items/book_*.png）全部不存在（art/items 下无 book_*）。设计稿要求“工笔图 + 标签/封口/药片特写”。修法：补图，或删掉字段并在 book_panel 里显式标“（插图待补）”。

P2-10 验货面板点击“拿鉴别录才能看”的部位时（inspect_panel.gd:216-219 走 closeup 路径）没有任何反馈，inspect() 返回的提示文字未显示。修法：返回值非空时 toast 出来。

P3-11 没有 tutorial 高亮 medbook（pre 只有 unlock + page）。修法：可选，加一条 {"op":"tutorial","target":"medbook","who":"brother","text":"册子在柜台右边，翻到批号对一对。"}。

P3-12 设计稿没写“发现假货却整批收”的后果。修法：与设计稿确认，建议加一条 benxin -1 或 zhang_told=false 标记，以便和 day1_close.json:52 的“那盒磺胺……你再对一遍册子”对齐。

P3-13 拆掉磺胺的开关只在验货面板里（inspect_panel.gd:112-121），不在算盘侧。玩家要拆单件，必须先打开验货。修法：在 sidebar 的要价区加一个选中物列表。

## Re-check (M3 after fixes)

复核方法：静态读当前文件；无头探针 /tmp/recheck/probe.gd、probe3.gd；plans d1_zhang_walkaway、d1_low_keep_iou_burned、d1_fair_swap 均 PLAYTHROUGH OK、exit 0。

- P1-1 reprice 覆盖选中 — ACCEPTED-AS-DECISION（reprice = 当前挑选的价）。session.gd:306-318 写 ask/floor 为新值；但见 N1。
- P1-2 tells 按点击计 — STILL OPEN。session.gd:220-229 未变；探针：解锁 medbook 后仅 inspect batch 即 tells_found=1，未对照册子也计数。
- P1-3 并排对照 — PARTIAL。inspect_panel.gd:127-132 新增“翻《沈记药材鉴别录》对照”按钮；main.gd:474-475 验货开着时册子移到 x560。两者皆 STOP overlay（验货 x20–940，册子 x560–1260），右栏可能被挡，需 DISPLAY=:5 实拍确认。
- P1-4 建议价口径 — STILL OPEN（待设计师定）。初始 suggest=182（磺胺按 claimed 180 计），判假后 74（与设计稿一致）；底价 150 未动。
- P2-5 outro 无条件 — STILL OPEN。d1_zhang.json:70-72 仍只有一条 outro；director.gd:457 无条件执行。
- P2-6 zhang_deal 无人读取 — STILL OPEN。d1_wangshan.json:18 仍只用 stock_has，未引用 zhang_deal。
- P2-7 低于底价必走 — STILL OPEN。session.gd _offer_buy 未加确定 leave 规则（代码未变，未重跑概率探针）。
- P2-8 est 不一致 — PARTIAL。d1_zhang.json est 改为 [120,380]（不是建议的 [214,350]）；medicine.json sulfa_fake.est 仍 [150,200]。
- P2-9 鉴别录插图缺失 — STILL OPEN。art/items 下无 book_*.png。
- P2-10 closeup 无反馈 — STILL OPEN。inspect_panel.gd:169-170 仅在有 pending event 时关闭，“还用不上”文字不显示。
- P3-11 无 tutorial 高亮 medbook — STILL OPEN。d1_zhang.json pre 无 tutorial 步骤。
- P3-12 “发现假货却整批收”无后果 — STILL OPEN（需设计确认）。d1_zhang.json on_accept 无标记或本心变化。
- P3-13 拆单件只能在验货面板 — STILL OPEN。sidebar.gd 无单件勾选，拆分仅 inspect_panel.gd:112-121。

NEW defects:
- N1 [High] 告诉她后重新勾选磺胺（已判 fake）→ ask 140→214、floor 90→138（probe3：unselect → reprice(140,90) → set_judged fake → reselect）。原因：reprice 反推 base_ask=140/r，_rescale_ask 又按磺胺 ask_w=90 分摊。随后 offer(150) 被 accept、price=150，等于替假磺胺付钱。修法：judged=="fake" 的物品 ask_w 视为 0（_selected_ratio 与 _rescale_ask 跳过），或 reprice 时记录“当前选择的基数”，reselect 只做增量。
- N2 [Low] reprice 后 suggestion 与 ask 口径不同步（suggest 74 为真相口径，ask 214 为认知口径），与 P1-4 同源，待设计统一。
