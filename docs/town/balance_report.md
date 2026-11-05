# T07 可复现数值实验

生成日期：2026-10-11；Godot 4.7-stable (official)；town pack SHA-256 `6ca302edac71c7c4d986309fe8b4d3cfb4239627a8771de8d5a4ec5014957bf0`。

实际运行脚本 SHA-256 `4b1288680515f9a81920b51650bfaedd62cce76fc5e74ea901d93da438794271`；归档原始JSON保留源文件指纹。本次只从归档重渲染报告。
结果JSON `/tmp/dehoudang_balance_integrated_full.json`，SHA-256 `49096e1cfbf1e0b1b3f605adea9efcd54fe1bcde389f6e4c2199b90974f09514`；包含逐局30日现金/费用、配对外生轨迹、成交/风险计数和源码指纹。
样本：3 难度 × 200 个配对种子 × 3 策略 × 30 日 = 1800 局 / 54000 模拟日。种子为 19380000 至 19380199。全量样本。

运行：`Godot_v4.7-stable_linux.x86_64 --headless --path . --script res://scripts/tests/balance_sim.gd -- --json=/tmp/dehoudang_balance.json`。`--quick` 使用 10 种子并默认写 `/tmp/dehoudang_balance_smoke.md`，不会覆盖全量报告；`--seeds=N`、`--report=PATH` 可改样本量/输出；`--from-json=PATH` 仅重渲染同一pack哈希的已归档结果，不重跑策略。

## 测量边界与策略

本实验调用 T01 的真实 TownSim、来访规划、当物生成、票据、账单与转账接口；开局无库存。T04 整合游戏另有五件开局库存（粳米、籼米、旧报纸、辞源、阿司匹林）、周妈 24 蚨旧当票、家庭米12/柴炭8/灯油8；实物家庭储备能覆盖部分早期账单。此处不把这些资产偷偷加入 T01 基线，故本表不是 T04 整合版存活率。所有买卖资金来自有限的 `s.cash`：陌生人的一次性入场预算来自其真实生成会话，不补充工资、不虚构每日营收、不用零预算买家买货。每日检查非负余额和总现金守恒，三策略同种子的天气、米价、药价与外生轮盘轨迹完全相同。

本政策遍历真实生成的全部验货 parts，仅从 authenticity/provenance 的 tell 和验货估值作判断，假设全部线索都检查成功（完美验货近似，未运行真实 Session 技能/情绪博弈）。公道：验货得到估值与真假/来源线索后拒收假货和赃物，按验货估值中点的 60% 收购/放款，按与 World.market_now / T04 货架标价相同的已验货自有库存市价的 95% 售货。贪心：按验货估值的 45% 收购/放款、同一自有库存市价的 102% 售货，也收赃并触发真实规则。顾客隐藏底价/最高价仅用于判断是否接受固定报价，绝不作为玩家报价输入；超出有限余额的买家不能成交。只守柜台：同公道价格，但不向茶馆在场邻居询问已送达的消息。两种出门策略目前只询问消息，没有未实现的外部转售渠道。

三策略每 15 分钟接一次柜台批次（来客到达后顺延至下一刻钟），严格在生成的等待耐心内接客；现场见证只来自真实已到达仍在等候的顾客和同行者，过期来访算错过。三策略先保当日饭、燃料和药，再还旧伙食欠款及其他到期账单（不抹旧债、不把还旧账误算为今天有饭），保留当日已公告伙食/燃料/药款两倍的流动资金（仅用当日信息），30 日长当贷款余额上限为开局资金的 20%，再以剩余资金成交，当日收款后再付款；不读取未来价格或天气。不覆盖同一 NPC 的活当票，不出售尚未解除质押的货。赎当仅在生成 redeem 来访、有效票据和有限顾客余额同时满足时发生，收本息后归还物品。

**经济生存**定义为 30 日内未连续 3 日当日伙食款欠付；这是明确的流动性指标，不是尚未纳入的 T04 故事/人物健康死亡判定。被标记失败的局仍运行到D30，现金、费用、毛利和风险均对全部局统计，不只取幸存局。断粮日=当日伙食欠付；欠账日=任何已到期款未清；病情风险日=药款超真实宽限未清。初始 `mother_sick=true` 是母亲背景设定，不将它误算为玩家每天生病。口碑为真实 `s.stats.koubei`，不人为按策略增减。

吃紧日：夜间现金 < 最近至多 7 日实际到期费用均值 × 3。每周吃紧频次按 30 日计数 × 7/30。周费用按到期日计入第 1–7、8–14、15–21、22–28 日四个完整周（含修缮、维持费、人情、月租）；29–30 日不混成完整周。P90 为 nearest-rank。利润栏只计已实现售货毛利和赎当利息，未扣家用与罚费；不把未售库存/活当本金当收入。全量错误为0才支持所有计入交易确实成交。

## 策略结果

|难度|策略|经济存活率（95% Wilson CI）|每周吃紧日|周费用均值 / P90|P90/均值|已实现交易毛利均值|断粮 / 欠账 / 病险日均值|口碑均值|热度≥0.3局比例（95% CI）|警察所D22前开门（95% CI）|
|---|---|---|---:|---|---:|---:|---|---:|---:|---:|
|太平年|fair|93.0% (88.6–95.8%)|0.65|69.54 / 109|1.567|358.21|0.64 / 0.92 / 0.23|50.0|0.0% (0.0–1.9%)|0.0% (0.0–1.9%)|
|太平年|greedy|96.5% (93.0–98.3%)|0.26|69.67 / 109|1.564|384.45|0.27 / 0.40 / 0.08|50.0|18.0% (13.3–23.9%)|9.0% (5.8–13.8%)|
|太平年|counter_only|92.5% (88.0–95.4%)|0.63|69.54 / 109|1.567|369.13|0.56 / 0.84 / 0.15|50.0|0.0% (0.0–1.9%)|0.0% (0.0–1.9%)|
|常年|fair|91.0% (86.2–94.2%)|1.03|85.57 / 136|1.589|333.03|0.98 / 1.41 / 0.40|50.0|0.0% (0.0–1.9%)|0.0% (0.0–1.9%)|
|常年|greedy|93.5% (89.2–96.2%)|0.47|85.70 / 136|1.587|379.43|0.53 / 0.72 / 0.20|50.0|17.0% (12.4–22.8%)|9.0% (5.8–13.8%)|
|常年|counter_only|89.0% (83.9–92.6%)|1.03|85.57 / 136|1.589|343.67|1.09 / 1.47 / 0.44|50.0|0.0% (0.0–1.9%)|0.0% (0.0–1.9%)|
|乱世|fair|83.5% (77.7–88.0%)|1.61|100.11 / 150|1.498|327.76|1.66 / 2.46 / 0.65|50.0|0.0% (0.0–1.9%)|0.0% (0.0–1.9%)|
|乱世|greedy|81.5% (75.5–86.3%)|1.07|100.25 / 150|1.496|369.51|1.58 / 2.00 / 0.80|50.0|18.0% (13.3–23.9%)|9.5% (6.2–14.4%)|
|乱世|counter_only|86.5% (81.1–90.6%)|1.53|100.11 / 150|1.498|335.70|1.49 / 2.19 / 0.60|50.0|0.0% (0.0–1.9%)|0.0% (0.0–1.9%)|

周费用分布池为每策略 800 个完整周，同一局的周并非独立，因此未把周数冒充独立生存样本。生存 CI 的独立样本单位是种子/局；本报告分位数为该固定种子样本的描述量，不承诺总体分位数置信区间。三策略使用相同种子，不能视为三倍独立环境样本。

## 现金曲线（P10 / P50 / P90，蚨）

|难度|策略|D1|D7|D14|D21|D28|D30|
|---|---|---|---|---|---|---|---|
|太平年|fair|246 / 322 / 367|65 / 241 / 350|25 / 198 / 364|27 / 190 / 375|0 / 117 / 352|0 / 130 / 351|
|太平年|greedy|305 / 342 / 382|155 / 271 / 364|93 / 275 / 435|39 / 308 / 512|28 / 266 / 479|49 / 267 / 503|
|太平年|counter_only|246 / 322 / 367|65 / 248 / 339|26 / 206 / 367|21 / 193 / 414|0 / 128 / 361|0 / 144 / 347|
|常年|fair|205 / 276 / 318|33 / 183 / 286|17 / 138 / 291|12 / 147 / 324|0 / 75 / 247|0 / 67 / 268|
|常年|greedy|266 / 296 / 331|110 / 212 / 300|51 / 196 / 347|18 / 228 / 449|0 / 183 / 410|11 / 166 / 411|
|常年|counter_only|205 / 276 / 318|35 / 183 / 285|11 / 147 / 304|14 / 154 / 346|0 / 61 / 265|0 / 71 / 259|
|乱世|fair|153 / 228 / 264|32 / 141 / 233|0 / 102 / 231|8 / 105 / 235|0 / 22 / 168|0 / 31 / 171|
|乱世|greedy|207 / 243 / 278|61 / 160 / 260|23 / 154 / 315|9 / 140 / 337|0 / 63 / 279|0 / 63 / 288|
|乱世|counter_only|153 / 228 / 264|27 / 139 / 235|10 / 103 / 230|12 / 103 / 242|0 / 25 / 175|0 / 40 / 168|

## 稀有当物到达与交易覆盖

稀有到达指当日真实生成的输入当物（包括拒收物），按生成 ID 去重；不是售出或赚到利润。首次到达分位数以30日内至少见过一次稀有物的局为条件样本；未见局的0不参与分位数，单列未见率和直方图。

|难度|策略|已见局首次稀有日 P10 / P50 / P90|30日未见率|每局稀有件均值|买入 / 放款 / 售出 / 赎回笔数均值|
|---|---|---|---:|---:|---|
|太平年|fair|1 / 2 / 5|0.0%|13.87|23.50 / 3.94 / 13.32 / 0.51|
|太平年|greedy|1 / 2 / 5|0.0%|15.17|15.58 / 4.68 / 9.97 / 0.55|
|太平年|counter_only|1 / 2 / 5|0.0%|14.14|24.12 / 3.95 / 13.64 / 0.51|
|常年|fair|1 / 2 / 5|0.0%|13.41|20.43 / 3.40 / 12.48 / 0.34|
|常年|greedy|1 / 2 / 5|0.0%|14.53|14.95 / 4.41 / 9.82 / 0.52|
|常年|counter_only|1 / 2 / 5|0.0%|13.40|20.93 / 3.47 / 12.73 / 0.38|
|乱世|fair|1 / 2 / 5|0.0%|15.03|19.61 / 3.04 / 13.03 / 0.32|
|乱世|greedy|1 / 2 / 4|0.0%|16.20|14.82 / 3.90 / 10.06 / 0.48|
|乱世|counter_only|1 / 2 / 5|0.0%|15.31|20.21 / 3.00 / 13.27 / 0.33|

## 完整逐周费用

|难度|策略|第1周均值/P90|第2周均值/P90|第3周均值/P90|第4周均值/P90|
|---|---|---|---|---|---|
|太平年|fair|59.15 / 67|55.52 / 63|55.52 / 64|107.97 / 117|
|太平年|greedy|59.15 / 67|55.80 / 63|55.59 / 64|108.16 / 117|
|太平年|counter_only|59.15 / 67|55.52 / 63|55.52 / 64|107.97 / 117|
|常年|fair|72.49 / 80|67.81 / 76|67.75 / 77|134.21 / 145|
|常年|greedy|72.49 / 80|67.99 / 77|68.00 / 77|134.30 / 145|
|常年|counter_only|72.49 / 80|67.81 / 76|67.75 / 77|134.21 / 145|
|乱世|fair|87.11 / 95|82.39 / 92|82.52 / 93|148.40 / 159|
|乱世|greedy|87.11 / 95|82.41 / 92|82.73 / 93|148.72 / 160|
|乱世|counter_only|87.11 / 95|82.39 / 92|82.52 / 93|148.40 / 159|

## 真实见证与稀有首到直方图

|难度|策略|每局实际收赃 / 产生目击流言的成交数|首次稀有D1–7 / D8–14 / D15–21 / D22–28 / D29–30 / 未见局数|
|---|---|---|---|
|太平年|fair|0.00 / 0.00|198 / 2 / 0 / 0 / 0 / 0|
|太平年|greedy|4.08 / 1.16|200 / 0 / 0 / 0 / 0 / 0|
|太平年|counter_only|0.00 / 0.00|197 / 3 / 0 / 0 / 0 / 0|
|常年|fair|0.00 / 0.00|197 / 2 / 1 / 0 / 0 / 0|
|常年|greedy|4.12 / 1.10|199 / 0 / 1 / 0 / 0 / 0|
|常年|counter_only|0.00 / 0.00|197 / 3 / 0 / 0 / 0 / 0|
|乱世|fair|0.00 / 0.00|198 / 2 / 0 / 0 / 0 / 0|
|乱世|greedy|4.18 / 1.10|199 / 1 / 0 / 0 / 0 / 0|
|乱世|counter_only|0.00 / 0.00|199 / 1 / 0 / 0 / 0 / 0|

## 数字调整（相对上游整合755c201未调数值）

|已有字段|上游|本次|作用|
|---|---:|---:|---|
|difficulty.太平年.initial_cash|360|390|增加有限开局周转；不是每日补贴|
|difficulty.常年.initial_cash|300|340|增加有限开局周转；不是每日补贴|
|difficulty.乱世.initial_cash|260|290|增加有限开局周转；不是每日补贴|
|living_costs.food.jitter|0.15|0.65|提高已公告日费用波动；伙食基础价仍为4|
|living_costs.rent.base|30|66.0|提前七天公告的月末费用；实际仍受min/max约束|
|living_costs.rent.max|36|66.0|容许已公告月末账单达到调整后的基础费用|
|communication.relay_probability|0.45|0.6|仍沿真实社交边、延迟、衰减与TTL传播|
|balance.items.stolen_rate|0.07|0.12|提高真实来源风险机会|
|visit_config.companion_probability|0.12|0.5|增加真实同行来访；见证仍受存在与耐心限制|
|norms.fence_goods.heat|0.25|1.2|经真实目击/延迟传播后提高机构重视程度|

## 实现限制与回报

T01 的真实生成交易尚不按公道/压价更新口碑，因此本表全部口碑样本均为50；未验证真实T04 Session的口碑目标，不合成口碑变化。真正的人物饥饿、疲劳、病情以及 T04 作者故事后果需要整合版游戏另测。无头政策没有模拟地图行走、完整 Session 耗时和玩家验货失误，仅用刻钟接客窗口处理来访过期，所报告的是明确策略下的经济边界。

生产数据只允许已有数字字段调整。脚本没有添加任何 pack 字段或改写 TownSim。现金守恒/非负/外生独立检查失败数：0。

## Python / GDScript 对照

附下列独立审计快照（2026-10-11）。它记录当时的公式模块 SHA-256，不冒称每次经济模拟重跑时也重跑 Python；当前四份源码是否仍匹配快照由脚本检查。


## 常年默认目标判定

|目标|实测|判定|
|---|---|---|
|公道经济存活 ≥90%|91.0%|达到|
|公道每周吃紧 ≥1 日|1.03|达到|
|P90 周费用 / 均值 ≤1.6|1.589|达到|
|贪心已实现交易毛利更高|差 46.40 蚨|达到|
|贪心越热度线明显更多（预定义差 ≥15 个百分点）|差 17.0 个百分点|达到|

## 首轮完整样本与本次对照

首轮同一200种子的原始结果 `/tmp/dehoudang_balance_full_original.json`，SHA-256 `44c5c26e20d27ddf2878f9b31ed44f3af00dc2f3493b990c6ec09bb571a1983a`；原始运行源码 `/tmp/dehoudang_balance_full_sources`，脚本SHA-256 `e78553a9250f8f71ffd520cf8041c038ad2101bff3353c94a53bbba9e76df7db`。首轮pack SHA-256 `6e5171a6cd54a3b82637135686b85dd2a6cbbe60a6e6fbb5a8c7c9289a19ac68`。
前50/100个种子用于探索候选，最终200种子包含这些样本。下列区间与达标判断描述所列固定种子，不能当作独立留出集验证。报价、验货、支付优先级及资金储备政策与首轮相同。最终输入另外保留上游755c201的社交链接与角色更新，因此首轮与本次差异不能全部归因于十项数字调整。

|常年fair|样本局数|经济存活|每周吃紧|周费均值/P90|P90/均值|交易毛利|
|---|---:|---:|---:|---|---:|---:|
|首轮|200|90.0%|0.868|78.0525 / 105|1.345248|332.655|
|本次|200|91.0%|1.030167|85.5662 / 136|1.589412|333.030|

上述判定只对明确的 T01 经济政策成立；健康/口碑及 T04 完整地图玩法仍需整合验证。脚本退出码检查现金与外生轨迹等不变量，目标未达会明确留在报告中，不把正常运行冒充平衡达标。

## 35日边界诊断：30日达标不等于长期达标

独立审计在上游整合755c201之后另跑常年fair、同一200种子，各35日。两版开局340、伙食jitter0.65、其他政策/数字相同，仅月租base/max从36改为66；临时工程延长窗口，没有改生产脚本的30日默认。基线pack SHA-256为`43daae3da0b2a202473204ab76fd03f4060808649506982dd3b8e0770c3848a8`，候选为本报告当前`6ca302edac71c7c4d986309fe8b4d3cfb4239627a8771de8d5a4ec5014957bf0`。200对35日外生轨迹完全相同、现金D1–27相同，候选每局只在D28多一笔30蚨真实到期费；候选35日的前30日现金、费用、外生与30日候选逐种子完全一致。整合前的87.5%/84.5%是历史输入结果，不作为当前输入证据。

|配对常年fair，200局|D30经济存活|D35经济存活（95% Wilson CI）|5完整周均值/P90|P90/均值|D35现金P10/P50/P90|D31–35断粮/欠账/病险人日|
|---|---:|---|---|---:|---|---|
|匹配基线，租36|91.0%|88.0% (82.8–91.8%)|74.937 / 104|1.387832|11 / 111 / 313|58 / 73 / 39|
|最终候选，租66|91.0%|84.0% (78.3–88.4%)|80.937 / 134|1.655609|2 / 95 / 285|91 / 118 / 55|

D31–35基线新增6局失败、候选新增14局失败。配对比较中候选独有失败8局，基线独有失败0局：新增月租使35日经济存活率降低4个百分点。D35现金均值143.410→128.545，35日交易毛利394.150→392.210。候选35日存活未达90%，五周费用比也超过1.6；本次30日目标通过不能解释为35日、长期或T04真实健康玩法已经平衡。当天饭优先于D28租费，加上连续3日欠伙食的生存定义，确实会把一部分月末后果推到D31以后，这个风险没有隐去。

五周费用重新从每局35个原始`costs`按D1–7、8–14、15–21、22–28、29–35汇总，共1000个周；候选35日JSON的`weekly_costs`仍只存前四周，因此不能直接拿它充当五周统计。两局各自的周仍相关，独立样本单位是200个配对种子。

证据：基线`/tmp/line13_t07_new755_base340_j65_r36_35_results.json`，SHA-256 `3d06cea9a57a42446ae70c104ef3d9c0d68f28c66afb999c56139afcbf7d3fba`；候选`/tmp/line04_t07_integrated340_j65_r66_35_results.json`，SHA-256 `085164ef6c2b70ea582829c98336e76eef299565d4bd906f9d5bbffddf335635`；独立配对重算`/tmp/line04_t07_integrated340_j65_r66_35_paired.json`，SHA-256 `87a40fe12b6295e470d8577575670bde73c710e1b21485d3330e159b6b97c280`。另一路独立核对`/tmp/line13_t07_new755_matched35_paired_metrics.json`，SHA-256 `099e276f231e3ed8a86c8225e43502bf7ab6b2c33d3118fcdca70610a6a79801`。

复跑保留的隔离工程（脚本SHA分别为`a7495657d9e350fcd1009b2dcd261e606e1861ac96b639986859f6386b3b9d94`、`4505541413161b5373fc0c331f6bdd4c2fd636b67a07ce6bc30e19f641ee51f0`；临时只筛常年fair）：

```sh
Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/line13_t07_new755_base340_j65_r36_35_project_6adjebbx --script res://scripts/tests/balance_sim.gd -- --seeds=200 --report=/tmp/base35.md --json=/tmp/base35.json
Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/line04_t07_integrated340_j65_r66_35__5024opg --script res://scripts/tests/balance_sim.gd -- --seeds=200 --report=/tmp/candidate35.md --json=/tmp/candidate35.json
```

上述`--path`工程的临时源码/manifest保留在`/tmp`。移机复现须隔离复制相同输入/源码，设置`DAYS=35`且只筛常年fair，基线另将rent.base/max还原36；五周统计从`costs`重算。生产脚本没有未实现的`--days=35`参数。

审计源码 `res://scripts/sim/jev_rng.gd`：当前文件匹配独立核验快照。
审计源码 `res://scripts/sim/pressure_model.gd`：当前文件匹配独立核验快照。
审计源码 `res://scripts/sim/world_wheel.gd`：当前文件匹配独立核验快照。
审计源码 `res://scripts/sim/town_cond.gd`：当前文件匹配独立核验快照。
### Independent Python/GDScript reference audit (line 16)

Scope: a read-only, standalone Godot project copied four simulation modules to `/tmp/t07-python-reference.kp1aT5`; no repository files were edited. Runtime: Python 3.12.14 and Godot 4.7.stable.official.5b4e0cb0f. Sample generator seed is `20261011`.

The original GameJev Python archive and `gamejev_living/randomness.py` were not available under `/workspace`. The Python runner explicitly reconstructs the published formula in `docs/town/research/gamejev_code.md` sections 1.1–1.4, 2.2 and 5.4, including the documented town adaptations. Historical vectors obtain their complete seeds from `docs/town/prototype/test.gd` and `scripts/tests/test_sim_rules.gd`. This validates the documented formula and exported historical vectors; it does not claim a direct execution comparison against the unavailable original archive.

Inputs containing non-integer floats are transferred as IEEE-754 little-endian hex and restored before either formula runs. Outputs compare IEEE-754 bytes, avoiding Godot decimal JSON parsing differences. Semantic keys independently undergo a normal Godot JSON stringify/parse round-trip. Totals accumulate in source order; a separate Python 3.12 built-in compensated-sum comparison is retained below.

| Test family | Cases | Fully exact cases |
|---|---:|---:|
| rng | 1000 | 1000 |
| replay | 1000 | 1000 |
| choices | 1000 | 1000 |
| pressure | 200 | 200 |
| wheel | 200 | 200 |
| rng_roundtrip | 1000 | 1000 |

All main comparisons are exact: pressure has 2600/2600 scalar checks and wheel has 7362/7362 scalar checks (including identifiers, cooldown updates, effects and preview purity). Wheel floating fields separately comprise 1,600 raw weights, 1,600 normalized probabilities and 200 draws. Maximum main absolute error is zero. Wheel preview preserves the entire input state, and spin logs, chosen effects and cooldown dates match the Python reference.

RNG cases cover Chinese, emoji, accented text, U+2028/U+2029, quotes, backslashes, common JSON control escapes, negative and large seeds, bools, nested arrays and integer keys. Choice cases include zero weights, `u=0`, `u=0.9`, random draws and the largest double below 1. Pressure cases cover exogenous mean reversion/noise (including difficulty noise 0/.7/1/1.8), endogenous half-life decay, [0,1] clamping, positive/negative influence and repeated daily-cap spending. Wheel cases cover exogenous/endogenous modes; cooldown blocked, exact-boundary and eligible cases; four seasons including zero seasonal weights; building locks; pressure minimum and bias clamps; difficulty tempo 0/.4/1/1.8; and all/any/not, day, weekday, season, weather, flag, stats, pressure, building and NPC relation conditions. Inputs are valid semantic cases; malformed-input rejection is outside this reference audit.

| Historical vector seed | Method/domain | Key | Python and GDScript value | Result |
|---|---|---|---|---|
| `42` | `wheel:climate` | `[1]` | `0.068580277501886444` | exact |
| `42` | `wheel:logistics` | `[3]` | `0.16148672144953713` | exact |
| `19380306` | `wheel:town_weather` | `[12]` | `0.28813905203852808` | exact |
| `19380306` | `message_relay` | `["event:7", "zhouma", "linsao", 1]` | `0.23250702028586301` | exact |
| `19380306` | `visit` | `[3, "xiaoding"]` | `0.99766566318890681` | exact |
| `19380306` | `轮盘:米价` | `[5, "德厚当"]` | `0.95322003511406195` | exact |
| `42` | `replay_draw` | `["A", 0]` | `0.6700750373336426` | exact |
| `19380306` | `replay_draw` | `["德厚当", 9]` | `0.73660400636362544` | exact |

The historical weighted selection `[quiet:8, clear:3, rain:2, gale:.5]` at `u=.9` returns `rain` in both implementations.

Observed wheel coverage:

| Gate/category | Count |
|---|---:|
| mode:exogenous | 100 |
| difficulty:清闲 | 50 |
| season:0 | 66 |
| choice:quiet | 146 |
| cooldown:eligible | 1118 |
| building:pass | 201 |
| when:block | 419 |
| season_weight:positive | 1268 |
| cooldown:block | 282 |
| when:pass | 381 |
| mode:endogenous | 100 |
| difficulty:常年 | 50 |
| building:block | 399 |
| pressure_min:pass | 949 |
| bias:positive | 1333 |
| pressure_min:block | 451 |
| bias:clamped_zero | 67 |
| difficulty:多事 | 50 |
| difficulty:停转 | 50 |
| choice:event | 54 |
| season:1 | 66 |
| season_weight:zero | 132 |
| season:2 | 34 |
| season:3 | 34 |

Comparison boundaries:

- Replacing explicit source-order accumulation with Python 3.12 built-in `sum(float)` changes 68 displayed probabilities across 16/200 wheel cases, with maximum absolute error `2.2204460492503131e-16`. Raw weights, draws and all 200 selected outcomes remain exact. These are compensated-sum rounding differences; the formula reference retains the source-order behavior.
- Godot 4.7 JSON parses `0.9999999999999999` as `1.0` and changes several other input doubles by small amounts. The encoded float input transfer deliberately verifies formulas on identical binary inputs; this observation is not hidden by a tolerance.
- Godot strings replace NUL U+0000 with U+FFFD before canonicalization. `JevRng.canon` matches Python for the other 31 tested U+0001–U+001F controls. Godot's ordinary JSON stringify emits invalid standard JSON for many low controls; U+000B becomes an unsupported `` escape and fails Godot's own parse. Production-style Unicode and common escape keys pass all 1,000 round-trips. Details are in `edge.gd` / `edges.json`.

Exact source fingerprints (the standalone copies are byte-identical):

| Source | SHA-256 | Copy equal |
|---|---|---|
| `scripts/sim/jev_rng.gd` | `09760b7fd54b72dc37f7a63b20a84599641baad65df9a56252be09848e06e1ff` | True |
| `scripts/sim/pressure_model.gd` | `1c731f4ccef0960ced27d3ef649ac3fc27c7d96523d40f2ee071e4b2ecdfe2e0` | True |
| `scripts/sim/world_wheel.gd` | `acdbb2af52bda233323b133f4d431194aeb37febdc8b91920244c50496c5819d` | True |
| `scripts/sim/town_cond.gd` | `8e0578ad11e57adc7d8d59edc6addd230a92d8f77d21f0cf1275ee4a58d4a36f` | True |

Artifact fingerprints:

| Standalone artifact | SHA-256 |
|---|---|
| `reference.py` | `5662600632444f161ccb604f02bbfd8f3731fd063a7d66b07f71af9080efd956` |
| `test.gd` | `8b2613afb06df29346e948759c84ae75849ee4c5918c01b0e84a110e9caa1b2f` |
| `inputs.json` | `56193ff970b52e24986a5ce0359eac689dcb617fc2bcc304268dc7aa9ccdd108` |
| `expected.json` | `8fd847f0958c31cadaed37e269f56d9bb8b058ab7e7affd4aa59b0ed2dc9820f` |
| `actual.json` | `1065258ee66ca3c73c2cb4b77a040d2fe6c2115235717e4f1fd844c0b33d486c` |
| `comparison.json` | `09fb8175f5eb618143a3c4df476977f7c08344225dc7fcb97719cf8b7bf43a7f` |
| `comparison_python312_sum.json` | `2d855d44ecd54bea5c3eebf4f5a828beeb3fc5a946b23228296d00e236aba3db` |

Reproduce the main audit with the retained standalone files:

```bash
python3 /tmp/t07-python-reference.kp1aT5/reference.py
/workspace/tools/godot47/Godot_v4.7-stable_linux.x86_64 --headless --path /tmp/t07-python-reference.kp1aT5 --script res://test.gd
python3 /tmp/t07-python-reference.kp1aT5/reference.py compare
```

For the documented native-sum rounding comparison, `python3 /tmp/t07-python-reference.kp1aT5/reference.py compare native-sum` intentionally returns exit status 1 with the differing probability bytes. To rerun control/decimal boundaries, use the same Godot command with `--script res://edge.gd`. `/tmp/t07-python-reference.kp1aT5/write_audit.py` regenerates this audit section from the retained outputs and hashes. Raw results are `comparison.json`, `comparison_python312_sum.json`, `godot.log`, `edges.json` and `edge.log`.
