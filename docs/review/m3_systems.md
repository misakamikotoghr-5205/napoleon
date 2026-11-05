# M3 系统审计：第一天六个支柱是否“看得见、有分量”

审计对象：当前工作树（审计期间 world.gd、session.gd 仍在被改，行号以审计时刻为准）。未改动游戏文件。
方法：阅读 mind/session/world/ledger/director/sidebar/book_panel/main 与 d1_*.json、cast.json；
跑 `run_playthrough.gd --until=day1_done`（PLAYTHROUGH OK）；另写 /tmp/m3probe 下的三个探针脚本
（世界轮盘、议价结果与概率、顾客分享流言）。概率只在探针里读，未出现在任何 UI 中。

## 一、逐支柱现状

### 1. 多维人格驱动议价（PersonaResidual）
- 玩家能看到的：只有台词分支。议价结果走 session.gd `_offer_buy` → `_line(kind)`（session.gd:399），台词来自 data/cast.json 的 `npcs.<id>.lines`，按种类固定（accept / counter / plead / leave），与人格无关。
- 人格确实在起作用（探针，种子 19380306）：
  - 小丁 ask50/floor25：报价 12 → leave 0.63；报价 22 → plead 0.55；报价 40 → accept 0.87。
  - 张护士 ask260/floor150：报价 75 → leave 0.58；135 → counter（“214，不能再少了。”）；208 → counter/accept。
  - 李敬之 ask30/floor15：报价 7 → leave 0.82；13 → counter（“24 吧，笔墨也贵。”）。
- 看不见的：traits/needs/emotions 全部不可见；表情标签几乎第一天不触发。mind.gd:185-198 的 expression 阈值：anger>0.45 需要三次以上压价（session.gd:353 每次只加 0.15）；小丁 fear 初值 0.45 不 >0.45；joy/affection 不够。结论：第一天四位顾客几乎不会出现“（脸色沉下来）”之类的表情线索。
- 台词不分人格：小丁的结巴、张护士的“不能再少了”、王山的“%d。”是人设台词，但 counter 的数字之外没有“强硬/软化”的差异，玩家只能靠结果猜。

### 2. 独立世界轮盘（米/药价、天气、巡逻、船）
- 玩家能看到的：
  - 右栏行情牌：sidebar.gd:196 `price_lbl.text = world.price_board()`（world.gd `price_board`，带 ↑/↓）。
  - 轮盘新闻：world.gd `_news` 写入 news 与档案簿“行情”（heard，挑担的）；director.gd:339-342 在推进时段时念成“（听挑担的说）…”。
  - 建议价随行情变：session.gd `calc_buy_suggest`（约 258 行）= 市价 × 行情 × 60%，符合设计稿 §“第一天收购建议价 = 市价 × 60%”。
  - 日结“市价约”（director.gd day_summary）。
- 探针实测：第一天清晨 `[轮盘] 米船没来，米价上涨 → 1.08`，行情牌应显示 73↑（68×1.08），小丁建议价 41→44。
- 看不见/有问题：
  - 天气冲突（bug）：第一天清晨轮盘输出“下起了细雨，青石板一片湿亮。”（探针实测），紧接着 data/story/day1.json:8 的 narr 写“清晨薄雾”。同一时刻两句话矛盾。
  - world.gd:301-302 `price_board` 写死 68 / 100，不读物品 market；米价与 rice_sunji 的 market 若改会对不上。
  - world.gd:253 注释说“内生（米价）读取已送达的压力”，代码里 logistics 纯随机，注释与实现不符（设计 R01 要求的压力反馈没有做）。
  - 行情牌只说“中白米”，小丁卖的是“粳米（乙等）”，建议玩家统一名称（设计稿写法是“乙等（中白米）”，可加括注）。

### 3. 主角只影响直接打交道的人
- 直接影响：favor()、议价 favor(-1/-3)、物件去向，全部可见（口碑条、钱匣、借据）。
- 间接影响（看不见）：
  - 口碑变动只写 world_log（world.gd `add()`，约 104 行），sidebar.gd:179-180 的口碑条涨跌没有原因。玩家看到 50→52，不知为何。
  - `fair_shop` 传播（world.gd `_on_learn` 约 448 行，周妈/林嫂 +1 口碑）是死代码：全部 data 中没有 plant `fair_shop`。
  - 张护士的 fake_hospital 经陈叔叔传给王山（探针与 playthrough 的 world_log 可见），玩家无感。这一条按设计稿“没听说也可能被后果影响”应保留隐藏，但口碑这类可见数值必须有原因。

### 4. 流言 / 碎片认识（亲眼 / 听说 / 推测）
- 可见：档案簿 消息页有 〔亲眼〕〔听说〕〔推测〕 标签（book_panel.gd:173）；第一天已有 推测“像是当兵的”（d1_wangshan extras）、听说“小丁的娘病了”（d1_xiaoding intro）、听说“有人往医院里掺假药”（d1_zhang tell_fake）。
- 顾客离场分享：director.gd:458 `world.share_rumors(s.npc_id)`，由 mind.decide 决定说不说。探针：张护士说了“县城教会医院被征用了”，王山、小丁、李敬之都没说。第一天的流言对玩家来说是概率事件，而不是剧本的确定节拍。
- 失真：FACTS 按跳数换说法（world.gd FACTS / rumor_text），第二跳加“（某某也是听别人讲的）”。这是真实的失真，但只有跳数，没有“谁转述、改了什么”。可接受。
- 小问题：world.gd `share_rumors` 对 origin 自己的说法也标“听说”（note(...,"heard", npc_id)），亲口说的“听她说”也合理，但应在 via 上写明是本人。

### 5. 账本：每一蚨都有来处
- 可见：账簿 钱匣 有分录编号、对方、今日收付（book_panel.gd:104-122，UX02 满足）；借据单列，不和现金混在一个数字里（iou_quinine 的 60 蚨借条在借据页）。
- 看不见：小丁拿“你给他的钱”去济生堂（world.gd `_offscreen_life`，day1 slot3，transfer 15 蚨）只写 world_log。玩家最有“每一蚨来处”体感的地方就在这里，却没有任何提示。

## 二、UX01 泄漏清单
1. 【真泄漏】session.gd:349 `hard_floor` 分支：`_line("counter") % base_floor`，直接把底价数字说出来。第二天赵老三（d2_zhao.json，hard_floor true，show_floor false）会在两次低价后听到“……XXX”，等于把隐藏底价告诉玩家。修法见 Fix 2。
2. 设计允许：第一天三位顾客（d1_xiaoding / d1_li / d1_zhang）show_floor=true，设计稿明文要求“客人要价和底价写在每位顾客下方”（story_sub2 第一天【实现】）。第二天起 show_floor 全部为 false（已核对 d2_*.json）。
3. 偏差待定：张护士 suggest 现在是 182（探针），设计表是 74。原因：calc_buy_suggest 对未判定的假磺胺按 claimed 180 × 0.6 = 108 计入。设计表写的是磺胺建议 0（假货市价 0）。这是代码有意为之（“按你以为的价值”），但与设计表不符，并且把假药的标签价抬到了 182。请 lead 决定：要么按设计 74，要么保留并改设计表。
4. 心里估价 est：inspect_panel.gd（单件时显示）与 sidebar 的 est_lbl（多件也显示）不一致。est 收窄会趋近真值（米：40–90 → 60–72，市价 68），属于玩家自己的判断，可接受；但多件时显示范围与单件规则不一致，建议统一。
5. 无概率、无人格数值、无本心/怀疑/好感数值出现在 UI 中（已 grep：ui 中无 probs、无 benxin/suspicion 显示；派系只给 亲近/一般/冷淡 的模糊印象，book_panel.gd:214）。
6. 表情线索 (mind.gd expression) 是允许的线索，不是泄漏。

## 三、Fix list（按优先级）

1. 【bug，第一天】天气冲突。改 data/story/day1.json:8 的 narr 为无天气词：`"卸门板。清晨的桥头街湿漉漉的，人不多。对面墙上贴着新告示，字看不清，只看得见一个红印。"`，并把第一天 `_wheel` 的天气输出在 day==1 且 slot==0 时抑制（world.gd `_wheel`：`if w != "quiet" and w != weather and not (day == 1 and slot == 0):`）。

2. 【UX01 泄漏】session.gd:349：hard_floor 分支不要念底价数字。改为 `return {"result": "counter", "text": _line("counter_hard")}`，并在 data/cast.json 的 npcs.zhao.lines 增加 `"counter_hard": "……少一个，就是不够。"`（只说“不够”，不说数）。 

3. 【支柱1 可见】人格进入台词与表情：
   a. session.gd:353 lowball 的 anger 增量由 0.15 改为 0.3（emotional_reactivity 高的人一次低价就会脸色沉下来）。
   b. mind.gd:188 的阈值 `anger > 0.45` 改为 `anger > 0.3`。
   c. session.gd:370 counter 分支：若 `t.assertiveness >= 0.6` 用 `_line("counter_firm")`，否则 `_line("counter")`。cast.json 为张护士加 `"counter_firm": "%d，就这个数，我赶时间。"`，为李敬之加 `"counter_firm": "%d 吧，笔墨也贵，不能再少了。"`。小丁保持结巴的 counter。
   这样玩家在一次低价后就能看到张护士的强硬、李敬之的脸色，不需要看数值。

4. 【支柱3 可见】口碑带原因。world.gd `add()`：当 stat == "koubei" 且 why 非空时，调用 `note("街坊", why, "seen")`（直接动作）。world.gd `_on_learn` 里 fair_shop/li_reported 的 add 调用传 why 时改用 `note("街坊", why, "heard", npc_id)`。不要对 benxin/suspicion 做同样处理（那些是隐藏的）。

5. 【支柱2 可见】行情牌接真数据：world.gd:301-302 `price_board()` 改为读 `DB.get_db().items["rice_sunji"]["market"]` 与 `items["quinine"]["market"]` 再乘 rice_mod/med_mod；同时给 sidebar 行情牌加一行“（米船没来：河上设了卡）”式的最近新闻（取 news 最后一条，见 world.gd `_news`）。

6. 【支柱4 可见】让第一天有一条确定的“听说”节拍。注意：`rumor` 步骤只让 origin 本人知道（world.gd `_plant`），不会传给别人；要让李敬之听到，需要新增一个 `learn` 步骤（调用 world.gd `_learn(npc, key, via)`），再由现有 `share_rumors`（director.gd:458）在他离场时决定说不说。建议：d1_zhang.json 的 `tell_fake` 额外项之后加 `{"op":"learn","who":"chen","key":"fake_hospital","via":"zhang"}`（已有传播路径），并在 d1_li.json 的 intro 中由 `share_rumors` 的确定性版本（去掉随机，改为 `when` 条件）念出“县城教会医院被征用了”，tag 为 heard via zhang。

7. 【支柱5 可见】world.gd `_offscreen_life`（day==1 and slot==3 的小丁分支）在 transfer 后加：`world.note("消息", "（推测）小丁下午大概去济生堂抓药了，钱是刚从你这儿拿的。", "inferred", "xiaoding")`。

8. 【支柱4/3】激活 fair_shop 链：d1_xiaoding.json 的 on_accept 中，`price() >= 35 and price() <= 50` 那条 koubei 分支旁加 `{"op":"rumor","key":"fair_shop","origin":"xiaoding"}`。注意传播是概率的（world.gd `_propagate_rumors`，edge xiaoding–zhouma 0.5）；想要确定就在 `_on_learn` 里用 koubei 直接结算而不依赖概率。

9. 【决策，需 lead 确认】张护士 suggest 182 与设计表 74 的差异（见二-3）。

10. 【文档】world.gd:253 注释改为与实现一致（去掉“读取已送达的压力”，或在 `_wheel` 里真的实现 R01 压力反馈）。

11. 【小】share_rumors 的 via 对 origin 本人的说法写明“（本人说的）”，避免被当成二手消息。

12. 【小】session.gd `_setup_sell` 里 `for p in it.get("parts", []): pass` 是死代码，删除。

## 四、验证
- 实测（当前工作树）：playthrough day1_done 通过（PLAYTHROUGH OK，钱匣 443，口碑 52，本心 54）。
- 探针脚本：/tmp/m3probe/probe.gd（轮盘）、haggle.gd（议价与概率）、share.gd（分享流言）。非游戏文件，可删。
- 修复后应复跑：run_playthrough --until=day1_done 与 --until=day2_done，检查 hard_floor 文本不含底价数字（grep 赵老三 counter 的输出）。

## Re-check (M3 after fixes)

证据：当前 scripts/core/world.gd、session.gd、director.gd、mind.gd、scripts/ui/sidebar.gd、data/cast.json、data/sessions/d1_zhang.json、d1_xiaoding.json、d2_zhao.json。headless：--until=day1_done 与各 plan 均 PLAYTHROUGH OK；同 seed 复跑 diff 0。

| Fix | 状态 | 证据 |
| --- | --- | --- |
| 1 天气冲突 | RESOLVED | world.gd `_wheel` 在 day1 slot0 强制 quiet；narr“清晨薄雾”与初始 weather=薄雾（world.gd:34）一致 |
| 2 hard_floor 泄底价 | STILL OPEN | session.gd:363 仍 `_line("counter") % base_floor`；cast.json zhao.counter 仍含 %d；无 counter_hard |
| 3a lowball anger 0.15→0.3 | STILL OPEN | session.gd:367 仍 0.15（与 3b 叠加后需两次低价才过阈值） |
| 3b mind 阈值 0.3 | RESOLVED | mind.gd:189、191 已为 > 0.3 |
| 3c counter_firm 人格台词 | STILL OPEN | cast.json 无 counter_firm；session.gd counter 分支未分流 |
| 4 口碑带原因 | RESOLVED | world.gd:126-128 口碑变动写档案簿“街坊的口碑…（原因）”，标签为推测（直接动作宜用亲眼，属小偏差） |
| 5 行情牌接真数据 | STILL OPEN | world.gd:301-302 仍写死 68 / 100；sidebar.gd:197 调用 price_board，无最近新闻行 |
| 6 确定性“听说”节拍 | STILL OPEN | KNOWN_OPS（director.gd:17-18）无 learn；d1_zhang.json:45 只有 rumor(origin 自己) |
| 7 小丁推测纸条 | STILL OPEN | world.gd:320-327 济生堂分支无 note(推测) |
| 8 fair_shop 激活 | STILL OPEN | 全部 data 无 plant fair_shop；world.gd:415、453 仍为死代码 |
| 9 suggest 182 vs 74 | OPEN（待决定） | session.gd:280 未判定假磺胺按 claimed×price_mod×0.6 计入；无记录的决定 |
| 10 world.gd:253 注释 | STILL OPEN | 注释仍写“内生（米价）读取已送达的压力” |
| 11 share 的 via 标注本人 | STILL OPEN | world.gd:510-513 无“本人”标记 |
| 12 _setup_sell 死代码 | STILL OPEN | session.gd:91-92 `for p in ...: pass` 仍在 |

UX01 泄漏：#1（hard_floor）仍然泄漏，见上表 2。其余 UI 检查（无概率、无人格数值）未变。

NEW：
- N1 [中] 3a/3b 只改了阈值没改增量：一次低价 anger 只加 0.15，阈值 0.3 需约两到三次低价才触发表情；建议 session.gd:367 改 0.3。
- N2 [低] 确定性：Li 钱匣 444/512 的差异本次未复现，同 seed 两次输出一致（见 m3_li.md F9）。

