# M4 审计：第二天与两晚的 GameJev 支柱是否“看得见、有分量”

范围：只读审计，未修改游戏文件。快照时间 2026-10-10 11:29（world.gd / director.gd / ledger.gd 在审计期间被他人改动，以当前磁盘状态为准）。
复现：`run_playthrough.gd --until=ending`（fair / greedy 均 PLAYTHROUGH OK）；完整日志见 /tmp/m4review/{fair,greedy}.txt（由 /tmp/m4review/dump.gd 导出）。

## 一、各支柱在第二天 / 两晚的可见性

**支柱1 人格·关系·日程·承诺**
- 看得见：林嫂“等他的钱到了就来赎”、赵老三“秋收了就来赎”（对白）；林嫂、周妈、赵老三的台词随关系变化；孙少爷“（脸色沉下来）”表情。
- 看不见：承诺没有进入待办。待办只有哥哥家书与陈叔来访（prologue.json:28,70；d2_farewell.json:32）。林嫂、赵老三的赎期只在账簿日期里。
- 提案：待办加两条承诺。`{"op":"todo","who":"林嫂","text":"承诺：丈夫汇款到了来赎金簪（德字第一号）","due_day":32}`，赵老三同理（due 按“秋收”取一个固定日）。在 d2_linsao.json 与 d2_zhao.json 的 on_accept 里加入。

**支柱2 世界自己转**
- 看得见：第二天清晨的“（听卖菜的说）有船从上海带了一批药回来”（world.gd `_news`，经 director.gd:181 与 advance_to 播出）；行情牌 奈宁 95↓；街景（乌篷船 d2 s0、皮靴声 s2、赵老三领着后生 s4、马保长敲门 s4）。
- 看不见：孙老爷派人（只在 world.gd:613 的后台 day3 事件里，玩家看不到）；赵老三卖田给孙府（见下文 BUG-A）；林嫂去银楼付定钱（world.gd:433，只进 world_log）。
- 提案：见修复清单 P2-4、P2-5。

**支柱3 主角只影响直接打交道的人**
- 看得见：周妈与孙少爷的传话只因为主角做了这些事（卖米给周妈、拆穿伪契）。
- 看不见：这一点本身是对的，但 fair 路线下孙少爷向马保长告状（world.gd:441 `_learn("ma","sun_exposed")`）玩家完全看不到结果。

**支柱4 消息带来源标签、会失真**
- 看得见（最好的部分）：林嫂说“良民证的钱怕是要涨到五十蚨了（林嫂也是听别人讲的）”；周妈“县城里在抓懂医的人”；档案簿标签 亲眼/听说/推测 均正常。
- 看不见：ma_heard_sun 只被写入（world.gd:508），没有任何 cond 读取；d2_ma.json 的马保长对白完全不提孙少爷。

**支柱5 账本：活当、到期、破旧、维持费**
- 看得见：账簿 活当页（典当盒、到期、成色）；隐患页（破旧 → 林嫂赎当时口碑-3，ledger 与 world.add_risk 已接好）；待办倒计时“距缴费还有 5 天”；哥哥“只是林嫂那张当票，算了”（d2_farewell.json:8）。
- 看不见 / 没有分量：
  - 维持费从未进入应付（liability）。d2_ma.json:53 的 todo 没有 `amount` 键，因此 director.gd:218 的 add_liability 不会被调用，应付恒为空，倒计时也没有金额。
  - 礼拜六的维持费（第7天）不会被扣，也没有任何违约后果。
  - 对账（夜）的 day_summary（director.gd:593 起，605 行的 debts 列表）不列出应付、待办、隐患。
  - 赎当（ledger.redeem / world.redeem_contract）在 UI 中无入口，支柱5的“赎 vs 违约”在 v0.1 切片内不可达。

## 二、只在 world_log 里的事（玩家看不到）
- fair：小丁济生堂抓药；张护士买船票（仅街景“乌篷船”可见）；赵老三交 300 赎子（仅街景 d2 s4 可见）；林嫂银楼定钱；孙少爷告状。
- greedy：赵老三以 400 蚨把田卖给孙府（BUG-A：街景被 elif 遮住，玩家完全不知道）；孙老爷派人（后台 day3）。
- 夜里：night_tick 的巡夜/狗叫（world.gd:317 起，概率低，多数夜晚无感）。

## 三、BUG 与设计偏差（按严重度）
- **BUG-A（街景遮蔽）**：world.gd:453 与 455 是 `if … elif`。当 zhao_son_free 为真时，“赵老三从孙府那边过来，烟杆没点”（卖地的亲眼所见）永远不会出现。greedy 路线（赵老三卖地、后生被放）下，卖地这件事对玩家不可见。修法：把 455 行的 `elif` 改为 `if`。
- **BUG-B（UX01 泄漏）**：data/night.json 的 desc 直接写了隐藏数值：第72行“每发一次，维持会怀疑 +1”；第92行“孙府好感 +5，孙少爷恨意 +20”；第102行“本心低于 40 时出现 … 本心 +2”。main.gd:587–593 把 desc 作为 tooltip 与正文都显示出来。
- **BUG-C（维持费不成为负债）**：见支柱5。d2_ma.json:53 缺 amount；director.gd:218 只在有 amount 时才建应付。
- **BUG-D（死代码）**：world.redeem_contract 无 UI 调用；ledger.redeem 也只在 world 内部。
- **偏差-E（ma_fee 金额无解释）**：fair 路线下马保长报“一百五”（director.gd:915–922，因 sun_young=exposed 加到 150），对白中没有任何理由。玩家会以为是随机涨价。
- **偏差-F（标签）**：周妈“对面墙上贴的告示”标为 heard（d2_zhouma.json outro）。告示是墙上的实物，玩家走到门口就能看见，宜标 seen，或加一条街景。
- **偏差-G（旗标矛盾）**：greedy 路线 zhao_son_unknown 与 zhao_son_free 同时为真（d2_zhao on_leave 与 world.gd 的放人逻辑互相覆盖）。
- **偏差-H（利息取整）**：ledger.gd:126 `ceil(days/30)`，第31天起按两个月计息（6%）。设计写“当期30天、月息三分”，宜说明过期按月计，或用 floor 加上满一月才计。
- **偏差-I（汇款来源）**：world.gd:625 丈夫汇款从“船行”账户（800 蚨）扣出，账上看不出是上海的丈夫寄来。提案：开一个 outside 账户“丈夫（上海）”，汇款分录的 reason 写明来源。后台路径，切片内影响小。
- **偏差-J（隐藏数值的可见副作用）**：counter_view.gd:108，怀疑≥5 时门口出现“影子”，没有任何文字解释（档案簿无对应条目）。建议配一条档案簿“门口好像有人影”（seen）。

## 四、“钱从哪里来”检查
- 通过：活当放款（player→当户）、赎当（当户→player）、赵老三 400（sunlaoye 真实账户，5000）、赎壮丁 300（zhao→保安队，来源可追溯到玩家的活当放款）、林嫂定钱（linsao→银楼，来自她的活当本）、张护士路费（来自玩家收购价）、伪契（player→sunyoung，需钱匣够）。
- 风险 1：船行汇款（偏差-I）。
- 风险 2：伙夫工钱每日从 sunlaoye 扣 4 蚨（world.gd 后台），是真实账户，但不在设计稿中，应标注为后台占位。
- 风险 3：brother_money 只是单向转入哥哥账户，没有去向；不构成凭空造钱，但玩家会以为钱“消失”。
- 守恒不变量（ledger.check_invariants）覆盖总量、负余额、重复出质、债务平衡；但不检查“每笔转入都有来源”。建议测试加一条：outside 账户的净流出必须对应一条有 reason 的分录（当前 reason 已写入，检查很容易）。

## 五、建议的第二天 / 两晚“可见分量”提案（设计忠实）
1. 街景：赵老三在 2_4 “领着后生从桥上走过”已有，补一条“从孙府那边过来，烟杆没点”（修 BUG-A）。
2. 张护士的船：乌篷船 d2 s0 已有；可在 d2 s0 的对白或档案簿加一条“听说张护士带弟弟坐早船走了”（heard，via 卖菜的）。
3. 档案簿 rumor：孙家收地经周妈传来，标签“听说”。在 world.gd `_offscreen_life` 中，当 zhao_sold_land 为真，调用 `_learn("zhouma","zhao_sold_land","zhao")`，并在 d2_zhouma 之外的时段（例如 2_3 下午）用 news 播出：“（听周妈说）赵老三把水田卖给孙家了，才四百。”
4. 林嫂银楼：world.gd:433 处加 `news.append({"text":"林嫂下午去银楼付了金锁的定钱，说孩子生下来就戴。","via":"周妈"})`，在夜里进入时播出。
5. 孙少爷告状：d2_ma.json 第 6 行（enter）之后加 `{"op":"if","cond":"is('ma_heard_sun')","then":[{"op":"say","who":"ma","text":"沈家丫头，孙少爷下午在我那儿说你当面拆穿了他的地契……我是听说的，不说别的。"}]}`，并在 world.gd:508 处 note 标签 heard（via sunyoung）。
6. 活当在夜里：对账（day_summary）加入 world.liabilities 与 world.risks（见 P1-2）。
7. 维持费：d2_ma.json:53 改为 `{"op":"todo","who":"马保长","text":"礼拜六：交维持费 {fee} 蚨","due_day":7,"countdown":true,"amount":"{fee}","pay_to":"维持会公账","what":"礼拜六维持费"}`。
8. 电报：night2 的陈叔叔来电可以按 chen.knows 选择 incoming（例如 knows 含 zhang_gone 则发“张走”）。目前写死。
9. 孙老爷派人：sunlaoye.knows 含 sunji_rice 时，在 2_5（夜）的 night_tick 加一条街景“对面茶馆门口，一个穿长衫的人站了一会儿，朝柜台看了两眼”（seen）。

## 六、修复清单（按优先级，附文件与精确改动）
P1-1 data/night.json 第72行：desc 改为“每发一次，维持会可能会注意到你（无线电会被侦测）”；第92行改为“事后派人告诉孙老爷：孙少爷拿伪契来当的事。”；第102行改为“心里有话的时候，可以写一篇日记。”（保留 director.gd 中 benxin>=40 的隐藏门控，只去掉数字）。
P1-2 scripts/core/director.gd:593–605 day_summary：debts 列表之后追加 world.liabilities（未付的，显示金额与期限）与 world.risks（未发的隐患文字）。
P1-3 data/story/d2_ma.json:53：加 `"amount":"{fee}","pay_to":"维持会公账","what":"礼拜六维持费"`（见提案7）。
P1-4 scripts/core/world.gd:455：`elif id == "zhao" and flags.get("zhao_sold_land", false) and slot >= 3:` 改为 `if …`（修 BUG-A）。
P2-1 data/story/d2_ma.json 第6行之后：插入 ma_heard_sun 的对白分支（提案5）；world.gd:508 的 note 标签配 heard。
P2-2 scripts/core/world.gd:433 附近与 FACTS（469 附近）：加 linsao_lock 的 news（提案4）。
P2-3 data/sessions/d2_linsao.json 与 d2_zhao.json 的 on_accept：加承诺型 todo（支柱1）。
P2-4 data/story/d2_ma.json 第9行之后：当 sun_young=='exposed' 时补一句理由（偏差-E）。
P2-5 scripts/core/world.gd `_offscreen_life` 中 sun 相关：孙老爷派人的街景（提案9）。
P2-6 scripts/tests/run_playthrough.gd：加断言 — day2 结束后 notebook 中 heard 标签至少 3 条且来源不同；greedy 路线下 street_log 含“烟杆没点”；night.json 所有 desc 不含“+ 数字”正则；liabilities 非空（维持费路径）。
P3-1 scripts/core/ledger.gd:126 利息取整，明确文档化或改为 floor。
P3-2 scripts/core/world.gd:625 汇款来源改为“丈夫（上海）”outside 账户。
P3-3 scripts/ui/counter_view.gd:108：怀疑≥5 时同时写一条档案簿“门口好像有人影”（seen）。
P3-4 scripts/core/world.gd 赵老三旗标：on_leave 与放人逻辑统一，去掉 zhao_son_unknown 与 zhao_son_free 同真的情况（d2_zhao.json on_leave）。
P3-5 周妈“告示”标签 heard → seen（d2_zhouma.json outro 的 note 项）。

## 七、结论
第二天的“世界自己转”与“消息失真”已经可见（清晨新闻、街景、林嫂/周妈的听说标签）。最弱的是支柱5：维持费没有进入应付，对账页看不到应付与隐患，赎当在切片内没有入口。另一个必须修的是 UX01 泄漏（night.json 的 desc 直接写隐藏数值）。BUG-A（街景 elif）使赵老三卖地在一条路线上完全不可见。P1 四条修完后，第二晚的对账即可体现维持费与破旧隐患。
