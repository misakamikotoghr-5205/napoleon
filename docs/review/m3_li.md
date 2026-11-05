# M3 审计：李敬之（收废品）— 只读审计，未改游戏文件

范围：data/sessions/d1_li.json、data/items/scrap.json、data/cast.json(li)、data/story/day1.json、
scripts/core/director.gd、scripts/core/session.gd、scripts/ui/sidebar.gd、data/story/night1.json、d2_ma.json、day1_close.json。
设计依据：story_sub2_剧本提示词.md「顾客四：李敬之」「三、废品」「柜台界面布局」「人物表」「数值与状态变量」。

## 实测（headless，/tmp/li_probe/probe2.gd，seed 19380306，策略 fair + 固定小报/出价）

| 路径 | li_paper | li_fund | 其它 | 结论 |
|---|---|---|---|---|
| 小报·烧 + 出价40 | burned | high | 小报→trash；夜1 烧垃圾后 tabloid_burned=true（火光旁白执行） | OK |
| 小报·收典当盒 + 出价17 | kept | low | suspicion +2；小报→stock | OK |
| 小报·交维持会 + 出价30 | reported | normal | 维持会 +5；小报→npc:li | OK（见 F4） |
| 小报·还 + 出价25（未翻报纸） | unseen | normal | 小报未出现 | 见 F1 |

## 逐拍对照

| 设计拍 | 实现位置 | 状态 |
|---|---|---|
| 哥哥教称重+翻一翻，小秤高亮 | d1_li.json pre tutorial scale；day1.json unlock scale | PARTIAL：只高亮秤，「翻一翻」无高亮（F7） |
| 傍晚进门 + 两句台词 | d1_li.json pre narr、intro say×2 | OK（文字逐字一致） |
| 旧报纸 12斤/12；辞源 30；小报3张 | scrap.json market 12/30/0；session est [25,45] | OK |
| 要价 30 / 底价 15，底价可见 | session ask 30 floor 15 show_floor | OK（probe 实测） |
| 建议价 7+18=25 | scrap.json suggest 7 / 18；session suggest 25 | OK |
| 翻报纸弹出小报，李敬之愣一下装没看见，台词 | scrap.json flip event:"tabloid" → d1_li.json on_inspect.tabloid | PARTIAL：事件、愣住旁白、台词、选择均执行；但小报内容从不展示（F3） |
| 选择一 4 项（还/烧/收/交） | d1_li.json on_inspect.tabloid options | OK（标签、标记、属性变化与设计表一致；「悄悄」正确，设计稿原文误作「惄惄」） |
| 选择二 资助按钮 | session fund_button:true；sidebar.gd:148-150 = max(40, suggest*1.6)=40 | OK |
| 选择二 3 档 normal/low/high + 台词 | d1_li.json on_accept 三个 if | OK（18–39 normal，<18 low，≥40 high） |
| 高档：钱-、本心+3、好感+10、台词 | on_accept >=40 分支 | OK（favor_li 实测 +10） |
| 打烊哥哥台词：资助/举报 | day1_close.json:88-106 | OK |
| 第4天被抓 | world.gd:546-547 | OK（presence=false + rumor li_reported） |
| 马保长第二天：kept 时目光停在典当盒 | d2_ma.json:24；ma_fee 读 reported | OK（kept → stock，条件一致） |
| 夜1 烧垃圾 ★，火光旁白 | night.json burn（nights 1,2）；director.gd:876 burn_trash | OK 当玩家选择烧时；否则见 F2 |
| 人物表：18岁、县立中学学生、性格、外形、秘密 | cast.json li (age 18, identity, look, secret) | OK |

## 可达性问题

1. 不翻报纸的路径：小报永远不出现（设计要求的「翻一翻才发现」是唯一入口）。li_paper 变成 `unseen`（d1_li.json outro），这个值设计稿「状态变量」表里没有，d2_ma/day1_close 也不读它，所以下游不崩，但文档缺失。更严重的是：min_inspect=0，且 session.gd `_offer` 不要求翻过，玩家可以直接按 30 成交，跳过整段剧情。见 F1。
2. 选择一的位置：确实在出价之前、与价格无关（翻报纸即触发）。但因为 F1 的存在，它可以被跳过。
3. ≥40 可达：实测 Li 柜台时钱匣 444 蚨，出 40 ≥ 要价 30 会直接成交，资助按钮给 40。可达。
4. 小报「烧」：若玩家没选烧垃圾（夜1 max_actions=2，可以用 整理库房+其它 占满），_trash_risk（director.gd:776）有 35% 概率把小报「翻走」并 suspicion+2。设计 【实现】写的是「禁报当天夜里会被烧掉」，与此不符。见 F2。
5. 小报「收」：典当盒/stock 中，市价 0，会出现在日结「库存」行（显示「市价约 0 蚨」）。一致性 OK，展示略怪（F8）。

## 其它发现

- 确定性：同一 seed、同一 fair 策略，三次运行中 Li 柜台的钱匣两次为 444，一次为 512（且 li_fund 从 high 变为 normal）。原因未查明（mind.gd:151 有 seed，world.gd:232 有 seed；需要再查 Mind/Persona 中是否有未播种的随机）。这影响自动化测试的可复现性。
- session.gd 在审计期间被修改过（磁盘上）；本报告基于修改后的版本。

## Fix list

F1 [高 · 引擎] 未翻报纸即可成交 → 小报与 li_paper 永远未定。
  证据：session.gd `_offer` / director.gd:478 不检查翻报纸；d1_li.json min_inspect 0。
  修复：给 session 加可选字段 `require_inspect: [["newspapers","flip"]]`（或 `require_flag`），在 director.gd:478 `_offer` 中未满足时说「东西还没翻完」并返回；
  在 d1_li.json 加 `"require_inspect": [["newspapers","flip"]]`。备选（纯数据）：min_inspect 设为 2 只能保证「称重+任一部位」，不够。

F2 [高 · 数据/引擎] 禁报可被「不烧」绕过，与 【实现】「当天夜里会被烧掉」矛盾。
  证据：night1.json 无自动烧；director.gd:639 `_trash_risk()` 35% 翻走。
  修复（推荐）：night1.json 在 `narr 你吹灭了灯` 之前加
  `{"op":"if","cond":"trash_has('tabloid')","then":[{"op":"call","fn":"burn_trash"}]}`（burn_trash 已输出火光旁白，并会设 tabloid_burned）。
  或者在设计稿改成「可能被翻走」并在 README 注明偏离。

F3 [中 · 数据] 油印小报内容从不展示（「上面写着县城据点的消息」只存在于 scrap.json 的 tabloid.parts.read，而 read 不可达：inspect_panel 只列 session.item_ids，main.gd:325；小报不在 item_ids 中）。
  修复：d1_li.json on_inspect.tabloid 第 27 行 item 之后加
  `{"op":"narr","text":"夹在报纸中间的三张油印小报，上面写着县城据点的消息：哪天换防，哪条路设了卡。"}`；
  并把 tabloid 的 part 说明作为 narr 来源。设计稿「翻报纸时弹出油印小报」的「弹出」可在 UI 层补一张小报立绘（art/items/tabloid.png 已存在）。

F4 [中 · 数据] 「交维持会」和「还」之后小报落到 npc:li（实测 loc=npc:li）。「交给维持会」却留在李敬之手里，语义不通。
  修复：d1_li.json:45-52 reported 的 steps 中加 `{"op":"move_item","def":"tabloid","to":"lost","note":"交给维持会"}`（或 npc:ma，若要账上可追溯）。

F5 [低 · 文档] li_paper 的 `unseen` 值未在设计稿「状态变量」表（约 826 行）与 INTERFACES 中列出。
  修复：设计稿补一行「unseen：未翻报纸」，或在 INTERFACES §5 说明。

F6 [低 · 数据] found_manuscript 标记（scrap.json:71）无任何读取者（grep 为空），「扇页里的文稿草稿」无后续。
  修复：加一个消费者（如 day2 或夜间 note「李敬之的草稿《春水》」），或删除 flag。

F7 [低 · 数据] 「翻一翻」没有教学高亮。
  修复（可选）：可在 pre 中加 tutorial 指向 counter_item，文本「翻一翻，夹在里面的东西才看得见」；若不加，pre 文字已提示，可接受。

F8 [低 · 展示] 日结库存列出市价 0 的禁报（kept 路径）。
  修复：day_summary（director.gd 日结）跳过 market<=0 且 contraband 的条目，或标注「不计价」。

F9 [调查] 确定性问题（见上「其它发现」）。修复前无法给出稳定的 Li 价格结果；建议在自动化测试里固定 Mind 的随机源并加一条重复运行对比。

— 完 —

## Re-check (M3 after fixes)

证据：当前 data/sessions/d1_li.json、data/story/night1.json、data/items/scrap.json、scripts/core/session.gd、director.gd。headless：d1_persuade_gift_reported_high、d1_low_keep_iou_burned、night1_burn_tabloid、--until=day1_done 均 PLAYTHROUGH OK；同 seed(19380306) 的 day1_done 连跑两次输出 diff 为 0。

| Fix | 状态 | 证据 |
| --- | --- | --- |
| F1 不翻报纸可成交 | RESOLVED | d1_li.json `require: ["newspapers.weigh","newspapers.flip"]`；director.gd `_offer` 先调 needs_more_inspection（session.gd:322-324），未满足直接拒绝 |
| F2 禁报不烧被绕过 | RESOLVED（残留为决定） | night1.json:11-13 `trash_has('tabloid')` → burn_trash 自动烧；残留：director.gd:797 的 35% 翻走只针对违禁品，属已决定接受 |
| F3 小报内容不展示 | RESOLVED | d1_li.json on_inspect.tabloid 中 item 后已有 narr“夹在报纸中间的三张油印小报…” |
| F4 交维持会仍在李敬之手里 | RESOLVED | d1_li.json:53 reported 的 move_item 改为 npc:ma |
| F5 unseen 未入设计稿/接口 | STILL OPEN | story_sub2 状态表与 INTERFACES 均无 unseen（grep 无命中） |
| F6 found_manuscript 无读取者 | STILL OPEN | scrap.json:71 仍设 flag，全库无 reader |
| F7 “翻一翻”无高亮 | STILL OPEN（可选） | d1_li.json pre 只有 scale 的 tutorial |
| F8 日结列出市价 0 禁报 | STILL OPEN | director.gd:574 day_summary 仍逐件输出“市价约 %d 蚨”，未跳过禁报 |
| F9 同 seed 结果不稳 | NOT REPRODUCED | --seed=19380306 连跑两次 diff 0，钱匣 522；原 444/512 未复现，未证明所有 seed |

决定核对：
- 禁报翻走仅违禁品（director.gd:787-797）：ACCEPTED。
- F2 残留：night1 的自动烧发生在 _trash_risk 之后，若小报已被翻走则不会出现火光旁白；可接受。

NEW：
- N1 [低] F2 修复后，夜1 烧掉路径的“你看见了县城的名字”只在烧掉时出现；翻走路径没有任何玩家可见反馈（只有 suspicion +2 与 world_log）。建议档案簿或夜间旁白给一句“垃圾箱里的纸不见了”。
- N2 [低] F8 与 N1 都是展示层问题，修 F8 时可顺便在 day_summary 对禁报标注“不计价”。

