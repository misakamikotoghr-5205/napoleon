# 伊夫堡分支（基督山伯爵）设计稿 · CRISTO

> 2026-11-02，标签 cristo。依据 `wm/arch/ARCH.md`（A/B/C 契约）和 `wm/geo/`（地理底图与地名表）。只写草稿，不碰仓库。
> 原著：大仲马《基督山伯爵》（1844—1846，公有领域）。人物、地名、日期都出自原著或史实；本分支自己的发明（主角、面包合同、法利亚活下来、司法宫之夜）在文中标明。不借用任何现代改编。
> 所有 JSON 由 `tools/build_cristo.py` 生成并自检（本次 0 个错误）；本文由 `tools/build_doc.py` 从 JSON 渲染。

## 0 结论速览

1. **入口**：主干终章 `elba_1815` 的第三个抉择「奉命携密信去马赛」（`branch: "cristo"`，旗标 `m_letter_carried`）。可用条件照 ARCH §1.2：`faria_half_letter`（第一幕博洛尼亚的半封信）或 `t_pharaon_known`（土伦的莫雷尔粮船、费拉约港的法老号）。主干已经埋好的 `t_dantes_letter`（你在厄尔巴亲手把信交给了唐泰斯）、`t_morrel_credit`、`t_went_home` 只改开局，不挡门。
2. **主角的位置**：埃德蒙·德·维尔福**不坐牢**。他带着皇帝的第二封信（与唐泰斯身上的是同一封信的两份，收信人都是杰拉尔的父亲努瓦蒂埃），晚到了半天。之后十四年，他在墙外：靠军需官的老本行拿到伊夫堡驻军的**面包合同**，于是能进地牢的厨房、给 27 号送药、给地道送工具。主线张力是姓氏：揭发杰拉尔，就是亲手毁掉维尔福这个姓。
3. **五章**，Boss 等级 L14 / 16 / 18 / 21 / 24（严格递增；章内遭遇 ≤ Boss−2、精英与锚点战 ≤ Boss−1；第一章遭遇战 L12，沿用鹰飞草稿对 ARCH 两条规则冲突的读法）：
   马赛 1815 → 伊夫堡岁月 1816—1829 → 基督山 1829 → 地中海 1829—1838 → 巴黎 1838。
4. **每章一张图**：马赛和巴黎用局部画布图（`marseille_1815`、`paris_1838`），伊夫堡岁月用「左边要塞、右边海岸」的 `if_fortress` 画布图（一张图跨十三年，锚点上标年份），基督山和地中海用 `med` 地理图（加 frames 放大罗马城和基督山岛）。约阿尼纳、君士坦丁堡、突尼斯是远航连线（`voyage_days`）通到的远方节点。
5. **三个固定结局 + 一个默认结局**：慈悲「等待与希望」、清算「伯爵的清单」、保姓「维尔福这个姓」，默认「基督山伯爵」。终场 `c_trial` 的三个抉择分别打开它们；慈悲还要求瓦朗蒂娜得救（`m_valentine_saved`），清算还要求三个仇人都倒下且卷宗 ≥ 100。
6. **战斗**：6 张模板已经画完并用模拟器验过（什么都不做必输、只放主角必输、参考打法能赢），覆盖第一、二章的全部战斗节点和 2 张通用遭遇战；第三到五章 8 张模板给出规格（尺寸、地形、命令、敌人、战力目标），B2 来画。Boss 战力曲线：marseille_arrest L14 530 → if_corridors L16 631 → monte_cristo_cave L18 710（目标） → san_sebastiano L21 830（目标） → cristo_final L24 960（目标）（每步 ≥ ×1.12）。
7. **伙伴**：新增 8 人（卡德鲁斯、雅科波、贝尔图乔、海黛、阿里、马克西米利安、万帕、阿尔贝），沿用 6 个跨段的人（唐泰斯、法利亚、莫雷尔与远洋同 id 同数值；巴蒂斯特、科尔索、玛丽由主干带来）。唯一的架空岔口：第二章带着药（`m_faria_medicine`），法利亚就能活过第三次发作，和唐泰斯一起出逃，成为后三章的伙伴（一条命）。
8. **去当铺**：本分支所有玩家可见的文字对 ARCH §6 的词表 0 命中（自检）。

## 1 入口、可用性与携带

- 分岔场景、抉择 id、`requires` 原样沿用 ARCH §1.4 与鹰飞草稿（`book_cristo_patch.json` 只补伊夫堡的内容字段：`scene_battles`、`order_flags`、`reasons`、`offer_text`、`soft_hooks`、`battle_pool`、`debug_carry`）。
- 灰掉时的原因：「你和马赛没有交集：没拿到法利亚的半封信，也没见过莫雷尔或法老号」。
- 软挂钩（只改开局）：

| 主干旗标 | 伊夫堡分支里 |
|---|---|
| `t_dantes_letter` | 开场多一行旁白：唐泰斯身上那封信，是你在费拉约港亲手交给他的（人心 −3，唐泰斯信赖 +1） |
| `t_morrel_credit` | 莫雷尔记得土伦那年的担保：起手金币 +1 |
| `t_went_home` | 1814 年你回过马赛：第一章开局多揭开两个节点 |
| `faria_half_letter` | 第二章「拼上那半封信」可选（藏宝的位置） |

- 携带：用 ARCH §1.6 的通用规则。物品里 `elba_watch`、`faria_half` 随书携带；`emperor_letter` 由分岔抉择发出。
- 调试入口：`game.new {"campaign":"napoleon","segment":"cristo","stage":N}`，`debug_carry.cristo.stage_overrides` 给出第 2—5 章的标准旗标与名册（例如第 3 章：法利亚活着、唐泰斯出狱、雅科波入队）。

## 2 章节结构

| 章 | 标题 | 地图视图 | 锚点场景（战斗） | 精英（可绕） | 随机遭遇 | 天数上限 | 幕间 |
|---|---|---|---|---|---|---|---|
| marseille | 第一章 · 马赛 1815 | marseille_1815 | c_landfall → c_reserve → c_gerard → c_petition → c_white_june（marseille_arrest L14） | catalans_cove L13 | L12 | 18 | bond |
| if_years | 第二章 · 伊夫堡岁月 1816—1829 | if_fortress | c_if_contract → c_bread_34 → c_faria_27 → c_morgiou（morgiou_cove L15） → c_faria_dies → c_if_night（if_corridors L16） | janina_lake L15 | L14 | 22 | minigame:decode |
| montecristo | 第三章 · 基督山 1829 | med | c_tiboulen（tiboulen_swim L17） → c_livorno → c_montecristo（monte_cristo_cave L18） | — | L16 | 20 | camp_night |
| mediterranean | 第四章 · 地中海 1829—1838 | med | c_caderousse → c_morrel_rescue → c_carnival → c_san_sebastiano（san_sebastiano L21） | appian_way L20 | L19 | 22 | audience |
| paris_1838 | 第五章 · 巴黎 1838 | paris_1838 | c_champs_elysees → c_auteuil（auteuil_garden L22） → c_peers → c_danglars → c_trial（cristo_final L24） | paris_rooftops L23 | L22 | 22 | minigame:weigh |

**节奏**（ARCH §2.8）：每章「积累（剧情锚点之间自由走图）→ 集结 → 军议 → 精英（可绕）→ 野营 → Boss」；两场会战从不相邻；第一、二章各有一场带仗的锚点（第二章莫尔吉乌是剧情战，不能绕）。幕间插曲五章各不相同：营火夜话 → 破译（法利亚的衬衫书）→ 野营夜 → 伯爵召见 → 过秤（唐格拉尔的金库）。

**为什么是这五章**：任务书给的五段（马赛 / 伊夫堡 / 宝藏与出逃 / 地中海 / 巴黎复仇）里，出逃放在第二章末尾当 Boss：伊夫堡岁月的高潮就是那一夜，而宝藏是出逃之后的事。卡德鲁斯的客栈和莫雷尔获救（1829 年 6 月、9 月）挪到第四章开头，和九年后的罗马串成「伯爵布网」的一章。约阿尼纳（1822 年）按原著时间放进第二章，做成可选的远航节点：主角作为卖火药的承包商亲眼看见费尔南献城——这是第五章贵族院的证据来源。

## 3 世界地图

| 章 | 视图 | 节点 | 连线 | 随机槽 | 期望事件 | 最短天数 | 天数上限 |
|---|---|---|---|---|---|---|---|
| marseille | marseille_1815 | 23 | 29 | 8 | 4.0 | 10 | 18 |
| if_years | if_fortress | 25 | 33 | 8 | 4.1 | 15 | 22 |
| montecristo | med | 20 | 27 | 8 | 4.1 | 9 | 20 |
| mediterranean | med | 23 | 30 | 8 | 4.1 | 10 | 22 |
| paris_1838 | paris_1838 | 23 | 30 | 7 | 3.6 | 12 | 22 |

自检通过的规则：R1（每条通往 Boss 的路上都有营地和补给 / 商贩）、R2（战斗类节点不相邻，含带仗的锚点和可能出仗的随机槽）、R3（随机槽 ≥ 30%，期望事件 ≥ 3）、R4（精英可绕）、R5（集结 → 军议相邻；Boss 前一格是战役段营地）、R6（相邻章幕间不同）、R7（天数上限 ≥ 最短天数 + 3；按每天 3 MP、航程按天数算）。另查：锚点顺序 = `scene_ids`，Boss 是最后一场；所有节点从起点可达；随机槽与对手遭遇的等级 = 本章遭遇战等级。

设计要点：
- **马赛 1815**：旧港在中间，四个锚点（码头 → 雷瑟夫酒家 → 大库尔街 → 梅朗林荫道）分在港口两岸和城东，逼着玩家绕港一圈；渡口有路费，宪兵巡逻队在城东来回走。6 月战役段从勒潘尼耶集结，军议在圣洛朗教堂，可绕的精英是夜里坐船去加泰罗尼亚人的海湾抢运军费。
- **伊夫堡岁月**：一张图跨十三年（`years.marks` 让顶栏显示年份刻度）。左半边是要塞（典狱长办公室、地牢厨房、27 号），右半边是海岸（面包码头、莫雷尔家、面包房的地窖——在这里「工程」= 给地道送工具、莫尔吉乌、卡西斯）。去约阿尼纳要 6 天航程，来回 12 天，换来卖身契和海黛：这是天数预算里的真取舍。
- **基督山 1829**：从蒂布朗岛出发，沿利古里亚海岸到里窝那，再穿过托斯卡纳群岛到基督山岛；热那亚帮的三桅船在卡普拉亚和戈尔戈纳之间巡逻。
- **地中海 1829—1838**：加尔桥 → 马赛（9 月 5 日）→ 热那亚 / 里窝那 → 罗马；君士坦丁堡（买下海黛）在 7 天航程以外。罗马城里六个战役节点相距不到 0.06 度，所以加了 `rome_city` frame。
- **巴黎 1838**：西边香榭丽舍和奥特伊，北边唐格拉尔的银行和蒙莫朗西电报站，南边卢森堡宫，正中西岱岛是终场。

### 3.1 节点表

#### marseille（marseille_1815）

起点 `quay`，集结 `panier`，Boss `warehouse`，驿站印 2 枚，天数上限 18。对手：宪兵巡逻队（canebiere→grand_cours→belsunce→grand_cours，碰上：{"battle": {"template": "alley_ambush", "level": 12}, "toll": {"gold": 1}}）。

| id | 地名 | 类型 | 阶段 | 日期 | 内容 | 动作 |
|---|---|---|---|---|---|---|
| quay | 旧港码头·圣让堡下 | 剧情 | 积累 | 1815-02-28 | c_landfall |  |
| fort_post | 圣让堡哨口 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| lazaret | 阿朗克检疫站 | 随机槽 | 积累 |  | 池 marseille；event 6、supply 2、camp 2、shop 1 |  |
| estaque | 莱斯塔克的渔村 | 随机槽 | 积累 |  | 池 marseille；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L12 |  |
| saint_nicolas | 圣尼古拉堡下的渡口 | 随机槽 | 积累 |  | 池 marseille；event 6、supply 2、camp 2、shop 1 |  |
| rive_neuve | 新岸的船坞 | 营地 | 积累 |  |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest |
| catalans | 加泰罗尼亚人村 | 补给·密探 | 积累 |  |  | visit:backdoor、build_depot |
| reserve | 雷瑟夫酒家 | 剧情 | 积累 | 1815-02-28 | c_reserve |  |
| corniche | 海边的悬崖小路 | 随机槽 | 积累 |  | 池 marseille；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L12 |  |
| garde_post | 守护圣母山信号站 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| arsenal | 旧军械库 | 随机槽 | 积累 |  | 池 marseille；event 6、supply 2、camp 2、shop 1 |  |
| canebiere | 卡讷比耶尔大街 | 随机槽 | 积累 |  | 池 marseille；event 6、supply 2、camp 2、shop 1 |  |
| grand_cours | 大库尔街·杰拉尔的宅子 | 剧情 | 积累 | 1815-02-28 | c_gerard |  |
| belsunce | 贝尔桑斯林荫道的集市 | 补给 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| meilhan | 梅朗林荫道·莫雷尔商行 | 剧情 | 积累 | 1815-04-12 | c_petition |  |
| caderousse_shop | 卡德鲁斯的裁缝铺 | 商贩 | 积累 |  |  | activity:merchant、recruit:troop、recruit:companion |
| aix_road | 去艾克斯的大路 | 随机槽 | 积累 |  | 池 marseille；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L12 |  |
| old_dantes | 梅朗林荫道的阁楼 | 随机槽 | 积累 |  | 池 marseille；event 6、supply 2、camp 2、shop 1 |  |
| panier | 勒潘尼耶的地窖（集结） | 营地·集结 | 积累 | 1815-06-24 |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest、muster |
| saint_laurent | 圣洛朗教堂 | 事件·军议 | 战役 | 1815-06-24 | ev_c1_council |  |
| catalans_cove | 加泰罗尼亚人的海湾 | 精英 | 战役 | 1815-06-24 | catalans_cove L13 |  |
| cellar | 圣让堡的暗道 | 营地 | 战役 | 1815-06-24 |  | activity:rest、schedule:bond_story |
| warehouse | 旧港北岸·莫雷尔的货栈 | Boss | 战役 | 1815-06-25 | c_white_june |  |

#### if_years（if_fortress）

起点 `gov_office`，集结 `bread_wharf_1829`，Boss `sea_gate`，驿站印 2 枚，天数上限 22。对手：海关缉私快艇（sormiou→morgiou→calanques→morgiou，碰上：{"battle": {"template": "coast_road", "level": 14}, "toll": {"gold": 1}}）。

| id | 地名 | 类型 | 阶段 | 日期 | 内容 | 动作 |
|---|---|---|---|---|---|---|
| gov_office | 伊夫堡·典狱长的办公室 | 剧情 | 积累 | 1816-03-12 | c_if_contract |  |
| if_landing | 伊夫堡码头 | 补给·驿站 | 积累 |  |  | visit:town、build_depot |
| if_kitchen | 地牢的厨房 | 剧情 | 积累 | 1817-07-20 | c_bread_34 |  |
| if_yard | 要塞的院子 | 随机槽 | 积累 |  | 池 if_years；event 6、supply 2、camp 2、shop 1 |  |
| cell_27 | 27 号牢房 | 剧情 | 积累 | 1818-12-03 | c_faria_27 |  |
| pomegues | 波梅格岛的检疫站 | 营地 | 积累 |  |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest |
| ratonneau | 拉托诺岛 | 随机槽 | 积累 |  | 池 if_years；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L14 |  |
| bread_wharf | 马赛的面包码头 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| morrel_house | 梅朗林荫道·莫雷尔家 | 补给·密探 | 积累 |  |  | visit:backdoor |
| bakery | 面包房的地窖 | 补给·工程 | 积累 |  |  | build |
| old_town | 老城 | 随机槽 | 积累 |  | 池 if_years；event 6、supply 2、camp 2、shop 1 |  |
| cassis | 卡西斯的走私贩酒馆 | 商贩 | 积累 |  |  | activity:merchant、recruit:troop、recruit:companion |
| morgiou | 莫尔吉乌小湾 | 剧情 | 积累 | 1822-08-14 | c_morgiou |  |
| sormiou | 索尔米乌 | 随机槽 | 积累 |  | 池 if_years；event 6、supply 2、camp 2、shop 1 |  |
| calanques | 峡湾群 | 随机槽 | 积累 |  | 池 if_years；event 6、supply 2、camp 2、shop 1 |  |
| la_ciotat | 拉西奥塔 | 随机槽 | 积累 |  | 池 if_years；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L14 |  |
| if_chapel | 要塞的小教堂 | 随机槽 | 积累 |  | 池 if_years；event 6、supply 2、camp 2、shop 1 |  |
| pointe_rouge | 红角的渔村 | 随机槽 | 积累 |  | 池 if_years；event 6、supply 2、camp 2、shop 1 |  |
| janina | 远方·约阿尼纳（1822） | 事件 | 积累 | 1822-01-20 | ev_janina_1822 |  |
| janina_lake | 约阿尼纳湖·湖心岛 | 精英 | 积累 | 1822-01-22 | janina_lake L15 |  |
| cell_27_1829 | 27 号牢房（1829） | 剧情 | 积累 | 1829-02-14 | c_faria_dies |  |
| bread_wharf_1829 | 面包码头（1829，集结） | 营地·集结 | 积累 | 1829-02-26 |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest、muster |
| cassis_backroom | 卡西斯·酒馆后屋 | 事件·军议 | 战役 | 1829-02-27 | ev_c2_council |  |
| frioul_night | 弗里乌尔礁石后的小船 | 营地 | 战役 | 1829-02-28 |  | activity:rest、schedule:bond_story |
| sea_gate | 伊夫堡·海门 | Boss | 战役 | 1829-02-28 | c_if_night |  |

#### montecristo（med）

起点 `tiboulen`，集结 `pianosa`，Boss `montecristo_cave`，驿站印 2 枚，天数上限 20。对手：热那亚帮的三桅船（capraia→gorgona→capraia→corsica_cape，碰上：{"battle": {"template": "coast_road", "level": 16}, "toll": {"gold": 1}}）。

| id | 地名 | 类型 | 阶段 | 日期 | 内容 | 动作 |
|---|---|---|---|---|---|---|
| tiboulen | 蒂布朗岛 | 剧情 | 积累 | 1829-03-01 | c_tiboulen |  |
| planier | 普拉尼耶灯塔 | 随机槽 | 积累 |  | 池 montecristo；event 6、supply 2、camp 2、shop 1 |  |
| toulon_post | 土伦港外的锚地 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| hyeres | 耶尔群岛 | 随机槽 | 积累 |  | 池 montecristo；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L16 |  |
| nice | 尼斯 | 补给 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| genoa | 热那亚的船坞与银行 | 商贩 | 积累 |  |  | activity:merchant、recruit:troop、recruit:companion |
| corsica_cape | 科西嘉角 | 随机槽 | 积累 |  | 池 montecristo；event 6、supply 2、camp 2、shop 1 |  |
| capraia | 卡普拉亚岛 | 随机槽 | 积累 |  | 池 montecristo；event 6、supply 2、camp 2、shop 1 |  |
| gorgona | 戈尔戈纳岛 | 随机槽 | 积累 |  | 池 montecristo；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L16 |  |
| livorno | 里窝那·理发店 | 剧情 | 积累 | 1829-03-09 | c_livorno |  |
| livorno_post | 里窝那港务处 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| bastia | 巴斯蒂亚的走私贩 | 补给·密探 | 积累 |  |  | visit:backdoor、build_depot |
| ajaccio | 阿雅克肖 | 随机槽 | 积累 |  | 池 montecristo；event 6、supply 2、camp 2、shop 1 |  |
| piombino | 皮翁比诺 | 随机槽 | 积累 |  | 池 montecristo；event 6、supply 2、camp 2、shop 1 |  |
| portoferraio | 费拉约港（厄尔巴） | 补给 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| civitavecchia | 奇维塔韦基亚 | 随机槽 | 积累 |  | 池 montecristo；event 6、supply 2、camp 2、shop 1 |  |
| pianosa | 皮亚诺萨岛（集结） | 营地·集结 | 积累 | 1829-05-20 |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest、muster |
| amelie_deck | 少年阿梅莉号的甲板 | 事件·军议 | 战役 | 1829-05-22 | ev_c3_council |  |
| goat_beach | 基督山岛的山羊滩 | 营地 | 战役 | 1829-05-23 |  | activity:rest、schedule:bond_story |
| montecristo_cave | 基督山岛·第二个小湾往东 | Boss | 战役 | 1829-05-24 | c_montecristo |  |

#### mediterranean（med）

起点 `caderousse_inn`，集结 `hotel_londres`，Boss `san_sebastiano`，驿站印 2 枚，天数上限 22。对手：教皇宪兵的巡逻队（civitavecchia_post→tivoli→frascati→tivoli，碰上：{"battle": {"template": "coast_road", "level": 19}, "toll": {"gold": 1}}）。

| id | 地名 | 类型 | 阶段 | 日期 | 内容 | 动作 |
|---|---|---|---|---|---|---|
| caderousse_inn | 加尔桥客栈 | 剧情 | 积累 | 1829-06-03 | c_caderousse |  |
| pont_du_gard | 加尔桥 | 随机槽 | 积累 |  | 池 mediterranean；event 6、supply 2、camp 2、shop 1 |  |
| nimes | 尼姆 | 补给 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| arles | 阿尔勒 | 随机槽 | 积累 |  | 池 mediterranean；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L19 |  |
| marseille_1829 | 马赛·梅朗林荫道 | 剧情 | 积累 | 1829-09-05 | c_morrel_rescue |  |
| toulon_bagne | 土伦苦役场 | 随机槽 | 积累 |  | 池 mediterranean；event 6、supply 2、camp 2、shop 1 |  |
| genoa_1830 | 热那亚 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| livorno_1830 | 里窝那的账房 | 补给·工程 | 积累 |  |  | explore |
| florence | 佛罗伦萨 | 随机槽 | 积累 |  | 池 mediterranean；event 6、supply 2、camp 2、shop 1 |  |
| montecristo_grotto | 基督山岛·伯爵的地下宫殿 | 营地 | 积累 |  |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest |
| civitavecchia_post | 奇维塔韦基亚港 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| rome | 罗马·人民广场 | 剧情 | 积累 | 1838-02-20 | c_carnival |  |
| thomson_french | 罗马·汤姆森与弗伦奇银行 | 商贩 | 积累 |  |  | activity:merchant、recruit:troop、recruit:companion |
| tivoli | 蒂沃利 | 随机槽 | 积累 |  | 池 mediterranean；event 6、supply 2、camp 2、shop 1 |  |
| frascati | 弗拉斯卡蒂 | 随机槽 | 积累 |  | 池 mediterranean；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L19 |  |
| naples | 那不勒斯 | 随机槽 | 积累 |  | 池 mediterranean；event 6、supply 2、camp 2、shop 1 |  |
| tunis | 突尼斯 | 随机槽 | 积累 |  | 池 mediterranean；event 6、supply 2、camp 2、shop 1 |  |
| constantinople | 君士坦丁堡·奴隶市场 | 事件 | 积累 | 1834-04-01 | ev_haydee_constantinople |  |
| hotel_londres | 伦敦饭店（集结） | 营地·集结 | 积累 | 1838-02-21 |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest、muster |
| vampa_note | 万帕的信使 | 事件·军议 | 战役 | 1838-02-21 | ev_c4_council |  |
| appian_way | 亚壁古道 | 精英 | 战役 | 1838-02-21 | appian_way L20 |  |
| caracalla | 卡拉卡拉浴场的废墟 | 营地 | 战役 | 1838-02-22 |  | activity:rest、schedule:bond_story |
| san_sebastiano | 圣塞巴斯蒂安墓窟 | Boss | 战役 | 1838-02-22 | c_san_sebastiano |  |

#### paris_1838（paris_1838）

起点 `champs`，集结 `ile_saint_louis`，Boss `palais_justice`，驿站印 2 枚，天数上限 22。对手：警察厅的便衣（saint_germain→latin_quarter→marais→latin_quarter，碰上：{"battle": {"template": "alley_ambush", "level": 22}, "toll": {"gold": 1}}）。

| id | 地名 | 类型 | 阶段 | 日期 | 内容 | 动作 |
|---|---|---|---|---|---|---|
| champs | 香榭丽舍大街 30 号 | 剧情 | 积累 | 1838-05-21 | c_champs_elysees |  |
| bois | 布洛涅树林 | 随机槽 | 积累 |  | 池 paris_1838；event 6、supply 2、camp 2、shop 1 |  |
| auteuil | 奥特伊·方丹街 28 号 | 剧情 | 积累 | 1838-06-20 | c_auteuil |  |
| passy | 帕西 | 随机槽 | 积累 |  | 池 paris_1838；event 6、supply 2、camp 2、shop 1 |  |
| st_honore | 圣奥诺雷区·维尔福府后门 | 补给·密探 | 积累 |  |  | visit:backdoor |
| helder | 赫尔德街·莫尔塞夫府 | 补给 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| montmartre | 蒙马特 | 随机槽 | 积累 |  | 池 paris_1838；event 6、supply 2、camp 2、shop 1 |  |
| telegraph | 蒙莫朗西的电报站 | 事件 | 积累 | 1838-08-29 | ev_telegraph |  |
| tuileries_post | 杜伊勒里宫的驿站 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| palais_royal_post | 王宫的拱廊 | 补给·驿站 | 积累 |  |  | visit:town、trade:fair、trade:counterfeit、build_depot |
| palais_royal_shop | 王宫市场 | 商贩 | 积累 |  |  | activity:merchant、recruit:troop、recruit:companion |
| saint_germain | 圣日耳曼区 | 随机槽 | 积累 |  | 池 paris_1838；event 6、supply 2、camp 2、shop 1 |  |
| luxembourg | 卢森堡宫·贵族院 | 剧情 | 积累 | 1838-07-10 | c_peers |  |
| antin | 昂坦街·唐格拉尔银行 | 剧情 | 积累 | 1838-08-30 | c_danglars |  |
| latin_quarter | 拉丁区 | 随机槽 | 积累 |  | 池 paris_1838；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L22 |  |
| marais | 马莱区 | 随机槽 | 积累 |  | 池 paris_1838；event 5、supply 2、camp 2、shop 1、battle 2；战斗 L22 |  |
| pere_lachaise | 拉雪兹神父公墓 | 营地 | 积累 |  |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest |
| bastille | 巴士底广场 | 随机槽 | 积累 |  | 池 paris_1838；event 6、supply 2、camp 2、shop 1 |  |
| ile_saint_louis | 圣路易岛（集结） | 营地·集结 | 积累 | 1838-10-14 |  | schedule:recruit、schedule:train、schedule:bond_story、activity:rest、muster |
| notre_dame | 圣母院的钟楼 | 事件·军议 | 战役 | 1838-10-14 | ev_c5_council |  |
| rooftops | 西岱岛的屋顶 | 精英 | 战役 | 1838-10-14 | paris_rooftops L23 |  |
| quai_horloge | 钟楼码头的小酒馆 | 营地 | 战役 | 1838-10-15 |  | activity:rest、schedule:bond_story |
| palais_justice | 西岱岛·司法宫 | Boss | 战役 | 1838-10-15 | c_trial |  |

## 4 固定结局

| id | 标题 | 条件 | 第一句 |
|---|---|---|---|
| m_wait_hope | 等待与希望 | {"flags": ["m_mercy_choice", "m_valentine_saved"], "metric": {"morale": [">=", 50]}} | 1838 年 10 月，基督山岛。一条帆船载着伯爵和海黛驶出海湾。 |
| m_full_ledger | 伯爵的清单 | {"flags": ["m_vengeance_choice", "m_gerard_exposed", "m_morcerf_fallen", "m_danglars_ruined"], "metric": {"exploration": [">=", 100]}} | 莫尔塞夫伯爵在家里开了枪。唐格拉尔男爵带着五万法郎逃出巴黎，在罗马的墓窟里饿了五天。 |
| m_name | 维尔福这个姓 | {"flags": ["m_shield_gerard"]} | 贝内代托没有出庭。一条船把他送去了美洲，船票是你买的。 |
| m_count | 基督山伯爵 | "默认" | 复仇做完了一半。一些人倒下了，一些人逃掉了。 |

- 终场 `c_trial` 是 Boss 战（司法宫之夜）之后的三选一：守住证人让他说完（清算）、在他开口之前带他出国（保姓）、让伯爵停手（慈悲，需要 `m_valentine_saved`）。
- 慈悲要 `m_valentine_saved`：第五章「努瓦蒂埃的眼睛」事件里用法利亚的红药水（法利亚必须活着）或伯爵的假死药（唐泰斯必须活着）。
- 失败结局沿用 bankruptcy / loss / blockade 三个 id，文字由 `rules.failure_text` 给出（伊夫堡口吻：追缉 100 = 检察署的马车来接你，这一次登记簿上写的是你的名字）。
- 段专属大命运 `m_cell_35`：被宪兵逮捕（`arrest` 标签）时可选「关进伊夫堡 35 号」：一年后由莫雷尔担保放出，体力 −20、人心 −8、追缉 −40，地道 +15（你在里面认得路）。

## 5 伙伴、羁绊、一条命

| id | 名字 | 兵种与数值 | 技能 | 阵营 | 招募 | 宿命之地 | 留守 | 风险 / 备注 |
|---|---|---|---|---|---|---|---|---|
| caderousse | 卡德鲁斯 | line 14/4/1 阻2 费3 | 酒馆里的大嗓门（举旗：本行友军攻 +2，2 回合） | marseille | {"scene": "c_reserve", "choice": "caderousse_home", "or_event": "ev_caderousse_wine"} | auteuil_garden | 留守：每章情报 +1（他什么闲话都听得到）。 | 信赖 0 时，第四章的钻石事件里他会出卖你（追缉 +20，离队）。原著里他死在贝内代托手里（1838）。 |
| jacopo | 雅科波 | artillery 10/6/0 阻0 费6 | 船头回旋炮（标记：对射程内一个敌人 8 伤） | smugglers、far_sea | {"scene": "c_morgiou", "choice": ["share_fair", "buy_the_boat"]} | tiboulen_swim | 留守：航程连线少 1 天（最少 1 天）。 |  |
| bertuccio | 贝尔图乔 | engineer 14/4/2 阻1 费3 | 科西嘉人的门闩（筑垒：放拒马或筑胸墙） | smugglers、count | {"event": "ev_bertuccio_name", "choice": ["tell_truth", "lie"]} | auteuil_garden | 留守：兵站不会被对手烧掉。 |  |
| haydee | 海黛 | medic 9/0/1 阻0 费3 | 约阿尼纳的证词（举旗：本行友军攻 +2，2 回合） | orient、count | {"event": "ev_haydee_constantinople"} | cristo_final | 留守：每章卷宗 +10。 |  |
| ali | 阿里 | grenadier 20/5/3 阻3 费6 | 马索（刺刀冲锋：挡住的敌人各受 5 伤并被击退） | orient、count | {"scene": "c_carnival", "auto": true} | san_sebastiano | 留守：每章体力 +4。 |  |
| maximilien | 马克西米利安·莫雷尔 | hussar 12/6/1 阻1 费4 | 北非骑兵的冲锋（刺刀冲锋：挡住的敌人各受 5 伤并被击退） | marseille、paris | {"scene": "c_morrel_rescue", "choice": "recruit_maximilien", "or_shop": "paris_1838"} | cristo_final | 留守：每章人心 +2。 |  |
| vampa | 路易吉·万帕 | jager 9/5/0 阻0 费4 | 牧羊人的子弹（标记：对射程内一个敌人 8 伤） | smugglers、bandit | {"scene": "c_san_sebastiano", "choice": "vampa_debt"} | paris_rooftops | 留守：过路费一律免掉。 |  |
| albert | 阿尔贝·德·莫尔塞夫 | line 13/4/1 阻2 费4 | 子爵的决斗手套（举旗：本行友军攻 +2，2 回合） | paris | {"scene": "c_san_sebastiano", "choice": "albert_oath"} | cristo_final | 留守：巴黎每章经费 +300。 | 第五章贵族院（c_peers）以后，如果海黛也在名册里，两人不能同场（discord）。 |
| dantes | （跨段） | 沿用远洋 / 主干数值 |  | marseille、count、shadow | {"scene": "c_faria_dies", "choice": ["sack_plan", "medicine_last", "knife_in_sack"]} | if_corridors |  | 第二章出狱前一直在伊夫堡里：只能在 if_corridors 上阵（第 9 回合起）。远洋数值不动。 |
| faria | （跨段） | 沿用远洋 / 主干数值 |  | scholar、count | {"scene": "c_faria_dies", "choice": ["medicine_last"]} | monte_cristo_cave |  | 原著里死于第三次发作。只有带着药（m_faria_medicine）才能招到；宿命之地是基督山岛的藏宝洞。 |
| morel | （跨段） | 沿用远洋 / 主干数值 |  | marseille、far_sea | {"scene": "c_landfall"} | marseille_arrest |  | 伙伴 id 用远洋的 morel；人物表里是 morrel（莫雷尔先生，法老号船东）。 |
| baptiste | （跨段） | 沿用远洋 / 主干数值 |  |  | "主干携带" |  |  | 主干携带而来；伊夫堡段无专属情节。 |
| corso | （跨段） | 沿用远洋 / 主干数值 |  |  | "主干携带" |  |  | 主干携带而来；第二章卡西斯酒馆有他的个人事件（规划）。 |
| marie | （跨段） | 沿用远洋 / 主干数值 |  |  | "主干携带" |  |  | 主干携带而来。 |

名羁绊（成对，信赖 1—3；内核还没有，先当数据写着，同鹰飞草稿）：

| id | 名字 | 两人 | 各档 |
|---|---|---|---|
| master_pupil | 师徒 | dantes × faria | 1：同场时法利亚的筑垒每次多放 1 个拒马。；2：法利亚相邻时唐泰斯攻 +2。；3：法利亚命悬一线 +1 枚；唐泰斯的冲锋不会停在泥地和瓦砾上。 |
| wait_and_hope | 等待与希望 | dantes × haydee | 1：海黛在场时唐泰斯每回合回 2。；2：唐泰斯倒下时，海黛的举旗立刻充满。；3：解锁结局“等待与希望”的最后一段。 |
| enemy_name | 仇人的姓 | bertuccio × hero（不和） | 1：两人同场时贝尔图乔攻 +2；相邻时每回合军心 −1。；2：（说过实话 m_bertuccio_knows）不再扣军心。；3：（奥特伊之夜后）贝尔图乔替主角挡下第一次猎官攻击。 |
| old_neighbours | 老邻居 | caderousse × dantes（不和） | 1：两人同场时卡德鲁斯防 −1。；2：（m_caderousse_sworn）卡德鲁斯攻 +2，直到战斗结束。 |
| father_son | 莫雷尔父子 | morel × maximilien | 1：同一行时举旗持续 3 回合。；2：一方倒下，另一方本场命悬一线 +1 枚。 |
| two_children | 两个孩子 | albert × haydee（不和） | 1：第五章贵族院以后两人不能同场。；2：（m_mercedes_spared）discord 解除，同场时两人各攻 +1。 |

阵营（加进 `bond_set_napoleon`）：

| id | 名字 | 标签 | 档位 | 说明 |
|---|---|---|---|---|
| marseille_folk | 马赛老街坊 | marseille | [2, 3] | 1815 年就在马赛的人。2：所有伙伴命悬一线 +1 枚；成员周围 2 格内的单位每回合回 1 兵力。3：街巷类地形（街道、房屋）开场军令点 +1。 |
| smugglers | 走私帮 | smugglers | [2, 3] | 地中海的走私船和山里的强盗。2：战后法郎 +20%；3：再 +1 金币。 |
| counts_house | 伯爵府 | count | [2, 3] | 基督山伯爵的人。2：军令手牌补到 4 张；3：来敌提前 3 回合公开（包括隐身的敌人）。 |
| orient | 东方 | orient | [2] | 从约阿尼纳和君士坦丁堡来的人。2：成员技能每回合多充能 1。 |
| bandits | 强盗的信义 | bandit | [1] | 1：赎金（ransom）类敌人走进鹰旗时不扣金币。 |
| paris_society | 巴黎社交界 | paris | [2] | 2：战后法郎 +20%。 |

- **一条命的戏**：第二章 Boss 战里唐泰斯从第 9 回合起才能上（他从麻袋里出来），法利亚只有救下来才在；第三章宿命之地是基督山岛的藏宝洞（法利亚）、蒂布朗岛（雅科波）；第五章奥特伊之夜是卡德鲁斯和贝尔图乔的宿命之地（原著里卡德鲁斯死在贝内代托手里）；终场司法宫是海黛、马克西米利安、阿尔贝的宿命之地。该不该把海黛带上终场，是这条分支最难的一道题。
- **提议给 A 的小字段**：`bonds_by_segment`（同一人在不同段属于不同阵营）、`available_from`（第二章唐泰斯和法利亚在牢里：名册里有，只能在 `if_corridors` 第 9 回合起上阵）。A 不采纳时的退路写在 `companions_cristo.json` 的 `_doc` 里。

## 6 敌军（ENEMIES 形状，L1 基线）

| id | 名字 | 兵力 | 攻 | 防 | 速 | type | 射程 | 标签 | at 格 | 来源 | 说明 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| gendarme | 宪兵 | 7 | 3 | 2 | 1 | infantry | 0 | arrest |  | arch | 王家宪兵。主角在他的白刃下倒下就直接被捕（不掷铜钱），战役层转入大命运「被捕」。 |
| mounted_gendarme | 骑宪兵 | 9 | 4 | 1 | 2 | cavalry | 0 | arrest、hunter |  | arch | 骑马的宪兵：猎官，冲着主角来，而且会把他带走。 |
| prison_guard | 狱卒 | 8 | 3 | 1 | 1 | infantry | 0 |  |  | arch |  |
| turnkey_chief | 典狱长 | 11 | 3 | 2 | 1 | leader | 0 | officer |  | arch | 伊夫堡的看守长，腰上挂着整串钥匙。模板用 on_kill 锁门（if_corridors）。 |
| customs | 海关缉私兵 | 6 | 3 | 1 | 1 | infantry | 2 |  |  | arch |  |
| smuggler | 走私贩 | 6 | 3 | 0 | 2 | infantry | 0 | stealth |  | arch | 对手帮派的走私贩：离我方单位 2 格以外时看不清是谁。 |
| bandit | 罗马强盗 | 6 | 4 | 0 | 1 | infantry | 0 | ambush、ransom |  | arch |  |
| bandit_marksman | 强盗枪手 | 4 | 4 | 0 | 0 | infantry | 3 | post、stealth | high、rooftop、woods | arch |  |
| vampa | 路易吉·万帕 | 14 | 5 | 2 | 1 | leader | 0 | officer、ransom |  | arch | 第四章之前是敌人（亚壁古道伏击）；打退他以后可以招为伙伴（companions_cristo.json）。 |
| assassin | 刺客 | 8 | 7 | 1 | 2 | elite | 0 | hunter、execute、stealth |  | arch |  |
| benedetto | 贝内代托 | 13 | 6 | 1 | 2 | elite | 0 | hunter、execute |  | arch | 杰拉尔·德·维尔福的私生子，土伦苦役犯，后来的“安德烈亚·卡瓦尔康蒂子爵”。 |
| national_guard | 国民自卫军 | 7 | 3 | 1 | 1 | infantry | 0 |  |  | arch |  |
| royalist_bravo | 保王党刺客 | 6 | 4 | 0 | 1 | infantry | 0 | boarder |  | ocean | 1815 年的白色恐怖。远洋稿定义；这里用在马赛六月。 |
| royalist_marksman | 保王党枪手 | 5 | 4 | 0 | 1 | infantry | 2 | sniper、boarder |  | ocean |  |
| royalist_chief | 保王党头目 | 10 | 4 | 1 | 1 | leader | 0 | officer、boarder |  | ocean |  |
| gunboat | 炮艇 | 10 | 6 | 2 | 0 | gun | 99 | boat | sea | ocean |  |
| nizam | 奥斯曼步兵 | 6 | 3 | 0 | 1 | infantry | 0 |  |  | trunk |  |
| bey | 贝伊 | 11 | 4 | 2 | 1 | leader | 0 | officer |  | trunk |  |
| ottoman_gun | 奥斯曼炮 | 8 | 6 | 0 | 0 | gun | 99 |  |  | trunk |  |
| verdet | 绿衫志愿兵 | 6 | 3 | 0 | 1 | infantry | 0 |  |  | new | 1815 年夏天南方白色恐怖里的保王党志愿兵，穿阿图瓦伯爵的绿色（史实 verdets）。比保王党刺客弱一档，是马赛六月的大多数。 |
| ng_grenadier | 国民自卫军掷弹兵 | 12 | 4 | 2 | 1 | elite | 0 | heavy |  | new | 1815 年 6 月倒向国王的马赛国民自卫军掷弹兵连：重型，挡住他要 2 点阻挡。 |
| customs_officer | 海关稽查官 | 10 | 3 | 2 | 1 | leader | 0 | officer |  | new | 缉私队的头目。打死他，这一队后退一格、攻 −1。 |
| revenue_cutter | 缉私快艇 | 9 | 5 | 1 | 0 | gun | 99 | boat、short | sea | new | 海关的小快艇，船头一门回旋炮：只能停在海格，只打与自己列差 ≤4 的格子。比远洋的炮艇弱一档。 |
| if_soldier | 伊夫堡守军 | 7 | 3 | 1 | 1 | infantry | 0 |  |  | new | 要塞的驻军，大多是上了年纪的老兵。 |
| if_veteran | 守军老军士 | 12 | 4 | 2 | 1 | elite | 0 | heavy |  | new | 要塞驻军里的老军士：重型，挡住他要 2 点阻挡。 |
| wall_sentry | 墙头哨兵 | 4 | 4 | 0 | 0 | infantry | 3 | post、sniper | high | new | 站在城墙上的哨兵：定点不动，射程 3，先打主角和伙伴。打死以后那一格空出来，我方炮兵、猎兵可以接手。 |
| fort_gun | 伊夫堡炮台 | 10 | 6 | 1 | 0 | gun | 99 |  | high | new | 要塞的报警炮。逃狱那一夜它会开火。 |
| thug | 码头打手 | 7 | 4 | 0 | 1 | infantry | 0 |  |  | new | 通用遭遇战的街头打手：马赛的、罗马的、巴黎的都一样。补兵（pad）用它。 |
| thug_marksman | 黑枪手 | 4 | 4 | 0 | 0 | infantry | 3 | post、stealth、sniper | rooftop、high | new | 躲在屋顶或窗后的黑枪：定点、射程 3、先打主角和伙伴。 |
| thug_boss | 打手头子 | 11 | 4 | 1 | 1 | leader | 0 | officer |  | new |  |
| rival_smuggler_boss | 对头帮的船老大 | 12 | 5 | 1 | 1 | leader | 0 | officer、stealth |  | new | 热那亚帮的船老大，和雅科波的人抢同一条水道。 |
| papal_carabinier | 教皇宪兵 | 8 | 4 | 2 | 1 | infantry | 0 | arrest |  | new | 罗马的教皇宪兵（第四章）。 |
| papal_dragoon | 教皇龙骑兵 | 10 | 5 | 1 | 2 | cavalry | 0 | hunter |  | new |  |
| sbirro | 教廷密探 | 6 | 3 | 1 | 1 | infantry | 0 | stealth、arrest |  | new |  |
| arnaut | 阿尔瑙特枪手 | 6 | 4 | 0 | 1 | infantry | 2 | skirmisher |  | new | 约阿尼纳的阿尔巴尼亚雇佣兵（第四章）。 |
| municipal_guard | 巴黎市政卫队 | 12 | 4 | 3 | 1 | elite | 0 | heavy |  | new | 七月王朝的巴黎市政卫队（第五章）。 |
| convict | 土伦苦役犯 | 7 | 4 | 0 | 1 | infantry | 0 | loot |  | new | 贝内代托从土伦苦役场带出来的人（第五章）。 |
| police_agent | 治安密探 | 6 | 3 | 1 | 1 | infantry | 0 | stealth、arrest |  | new | 巴黎警察厅的便衣（第五章）。 |

内核要认识的标签全部来自 ARCH §5（arrest、stealth、ambush、ransom、post、boat、short、sniper、boarder、loot、heavy、hunter、officer、execute、skirmisher）；本分支没有发明新标签。

## 7 战斗

### 7.1 这条分支怎样还是「排兵布阵」

伊夫堡分支里没有大会战，但每一场仍然是 Battle v2 的部署塔防：我方从左边（鹰旗一侧）往格子里放人、定朝向、管阻挡，敌人沿固定路线一波一波压过来。复杂度来自地形，不来自兵多：
- **街巷与房屋**（`S` `B` `R`）：房屋我方能进、敌人不进、挡视线；屋顶只有猎兵类能上、射程 +1。于是马赛的街战是「抢房子、封街口、用屋顶打头目」。
- **牢廊与牢门**（`C` `L` `D`）：牢廊是暗的（射程 −1），牢门是出生格，打死典狱长就把门锁成墙（`on_kill`）。伊夫堡之夜因此有一个明确的中盘目标：先打典狱长。
- **海与浅水、洞穴**（`W` `-` `c` `p`）：敌人从跳板接舷，缉私快艇在海格上开炮（`short`：只打列差 ≤ 4），洞穴挡视线、敌炮不瞄准。走私湾的解法是「洞口当堡垒」。
- **虚空**（`_`）：塌掉的路基、悬崖外的海，射程跳过，冲锋到此停。
- **命令**：除了内核已有的 hold / no_leak，本稿提议三种（都带 `order_fallback` 退回已有类型）：`escape`（指定伙伴某回合站到出口）、`extract`（某格累计站满 N 回合：搬箱子、找人）、`protect`（指定伙伴或 NPC 不倒下）。

### 7.2 已画好的 6 张

验证方法：`tools/battle_sim.py` 是 `battle_rules.gd` 的简化 Python 版（加上 ARCH §3/§4 的等级表、地形表、步耗、视线、顶层、黑暗、天时和新标签），比真人弱：军令牌只自动打「征发、齐射、刺刀、号手、皇帝的命令」，没有佯攻 / 弹幕 / 后撤，没有方阵和撤退。「什么都不做」和「只放主角」两项按 ARCH A4 不打牌、不放技能（被动）；「只放主角」对每一个能站的格子、四个朝向都试一遍，取最好的结果。三项同时成立才算「可解且不白给」。

#### `catalans_cove` 加泰罗尼亚人的海湾（elite，9×5，L13，9 回合，敌军心 13，天时 night）
```
   ABCDEFGHI
 1 GBRB^w^.G
 2 SSSSSSSSG
 3 ^,v,,;,,G
 4 WW-EE-,WW
 5 WWWWWWWWW
```
- 命令：百日的军费：四箱金币要从 E3 的沙滩搬上 E4 的渔船。有 4 个回合结束时我方有人站在 E3（每满一回合上船一箱）。（退路：（内核没有 extract 时）第 9 回合结束时，我方有人守在 E3。）
- 路线：`village` A1→D4（6 格）；`road` I2→E4（6 格）；`cliff` I1→E4（7 格）；`beach` I3→E4（5 格）
- 来敌：T1 road：customs、verdet、verdet；T1 village：verdet、verdet、verdet；T2 @H5：revenue_cutter；T2 beach：customs、verdet；T2 village：verdet、gendarme；T3 road：mounted_gendarme、customs；T3 village：gendarme、verdet；T4 cliff：customs、verdet；T5 road：customs_officer、verdet；T5 beach：verdet、customs≥L14；T6 village：verdet、gendarme、mounted_gendarme≥L15
- 说明：1815 年 6 月 24 日夜里，滑铁卢的消息到了，加泰罗尼亚人村下面的小海湾。百日期间存在马赛的军费要赶在保王党动手以前运走，两条渔船等在湾里（D4、E4 是鹰旗：船被缴就完了），两头同时有人来：宪兵从村子那头下来（A1 教堂后的小路，经 A2–C2 石板巷、C3 晾网棚、D3 沙滩到 D4），海关从马赛那头来（I2 大路、I1 崖上小路在 H2 并进来，都经 E2、E3 到 E4；I3 沿沙滩经 G4 蹚 F4 浅水到 E4）。B1、D1 是渔民的石屋（我方可以进驻，防 +2，挡视线，敌人不进屋），C1 是屋顶（只有猎兵能上，射程 +1），E1、G1、A3 是礁石（高地），F1 是松林。C3 晾网棚是村庄（双方防 +2），F3 是礁石滩（瓦砾：步耗 2，防 +1），C4、F4 是浅水（能走不能站）。H5 海面上第 2 回合来一条缉私快艇（第 4 回合起每 2 回合一炮，只打与它列差 ≤4 的格子，也就是 D–I 列）。夜里我方小火器射程 −1。左右两头要分兵：村子那头的路短、人少，海关那头三条路都压到 E3。
- 参考打法（ch1 名册）：两头分兵：卡德鲁斯守 C3 晾网棚（村庄防 +2），科尔索上 C1 屋顶朝下打石板巷；莫雷尔守 E3（海关三条路的汇合口，也是搬箱子的格子），第 2 回合主角进 D1 石屋（不挨任何一条路，猎官够不着），横队进 D2 朝右打 E2–F2，D3 再放一队横队兼当抬人的。第 5 回合起 E1 上猎兵，G1 上炮朝下：同时打得到沙滩和 H5 的缉私快艇。
| 等级 | 什么都不做 | 只放主角（最好的一格） | 参考打法 | 敌数 | 猎官 | 精英 | 敌战力 |
|---|---|---|---|---|---|---|---|
| L13 | defeat t6 | defeat t7 (B1:right) | victory 军心 11 漏 3 倒下 morel 命令 完成 | 22 | 1 | 0 | 242 |

#### `marseille_arrest` 旧港·六月的白帽徽（grand，10×6，L14，13 回合，敌军心 24，天时 clear）
```
   ABCDEFGHIJ
 1 WkBRBB^RBG
 2 EkSSSSSSSS
 3 WkB.v.BRSB
 4 EkSSSSSSSS
 5 WkBB^BRBSG
 6 WWWWWW#W^_
```
- 命令：莫雷尔先生的请求：他要亲手守自己的货栈。莫雷尔上场，并且打完都没有倒下。（退路：（内核没有 protect 时）没有一个暴徒走到码头的小船边。）
- 路线：`loge` J1→A2（10 格）；`cross_dn` J1→A4（12 格）；`quay` J5→A4（10 格）；`cross_up` J5→A2（12 格）；`church_n` E3→A2（5 格）；`church_s` E3→A4（5 格）
- 来敌：T1 loge：verdet、verdet、royalist_marksman；T1 quay：national_guard、national_guard；T2 @I6：fort_gun；T3 church_n：verdet[ambush]、verdet[ambush]、royalist_marksman[ambush]；T3 cross_up：mounted_gendarme；T4 loge：ng_grenadier、verdet、verdet；T5 quay：royalist_chief、national_guard、national_guard、royalist_marksman、royalist_marksman；T6 church_s：royalist_bravo[ambush,hunter]、verdet[ambush]；T7 cross_dn：mounted_gendarme、ng_grenadier；T8 loge：royalist_chief、ng_grenadier、verdet、royalist_marksman≥L15；T9 quay：ng_grenadier、national_guard、gendarme、gendarme；T10 church_n：verdet[ambush]、royalist_marksman[ambush]、verdet[ambush]≥L16；T11 cross_dn：ng_grenadier、royalist_marksman、verdet、verdet；T12 church_s：royalist_bravo[ambush]、royalist_bravo[ambush]、verdet[ambush]
- 说明：1815 年 6 月 25 日，滑铁卢的消息到了马赛，城里的保王党起事（史实：马赛这几天杀了不少波拿巴分子和埃及难民）。旧港北岸：左边 B 列是码头石阶，A2、A4 是等着把人送去加泰罗尼亚人村的小船（鹰旗）。两条大街从勒潘尼耶的坡上冲下来：第 2 行洛日街（J1 红门是刀剪街口，绕进 J2），第 4 行港口大道（J5 红门是大街口，经 I5 拐进来）；I 列的小巷把两条街连起来，所以每一路都能拐到另一条街上。E3 是圣洛朗教堂前的小广场（村庄），第 3、6、10 回合有暴徒从广场上冒出来（伏兵，出生格 E3），离小船只有 4 步。房屋 B 我方可以进驻（防 +2，挡视线），C3 是莫雷尔父子商行的货栈；屋顶 D1、H1、H3、G5 只有猎兵能上；G1 教堂台阶、E5 是高地（炮兵、猎兵）。I6 是圣让堡的炮台（第 2 回合起，第 4 回合开第一炮，打离它最近的我方地面单位），G6 是堡墙。来敌：绿衫志愿兵、保王党枪手（专打主角和伙伴）、倒向国王的国民自卫军和掷弹兵连（重型），两名骑宪兵（猎官、逮捕：主角在他们刀下倒下就直接被捕），第 6 回合广场上冒出一个盯着“另一个埃德蒙”的保王党刺客（猎官）。
- 参考打法（ch1 名册）：莫雷尔守自己的货栈 C3（房屋，防 +2，敌人进不来），朝上打洛日街；玛丽在 D3 广场边给他回血。主角在 C1 石屋里（C2 有人挡着，猎官就停在 D2 够不着他）。C2、C4 两个街口各一道阻挡，B2、B4 码头再一道。E5 高台上的炮朝上，同时打洛日街和教堂广场冒出来的伏兵；G1 教堂台阶再上一门炮朝下打港口大道。H3 屋顶的猎兵专打头目。圣让堡的炮只打离它最近的地面单位，所以别让人站在 G4–I4 太久。
| 等级 | 什么都不做 | 只放主角（最好的一格） | 参考打法 | 敌数 | 猎官 | 精英 | 敌战力 |
|---|---|---|---|---|---|---|---|
| L14 | defeat t10 | defeat t10 (J3:right) | victory 军心 15 漏 0 倒下 marie 命令 完成 | 38 | 3 | 5 | 530 |

#### `morgiou_cove` 莫尔吉乌的走私湾（elite，9×5，L15，9 回合，敌军心 14，天时 night）
```
   ABCDEFGHI
 1 ^^#G^^#G_
 2 Ekc,,;,,G
 3 EkWWpWWWW
 4 _kc,,;,.G
 5 __^^#^^^_
```
- 命令：雅科波的话：“货在洞里。”第 9 回合结束时，我方有人守在 C2 的洞口。
- 路线：`west_cliff` D1→A2（4 格）；`east_cliff` H1→A2（8 格）；`shore` I2→A2（8 格）；`south` I4→A3（9 格）；`rival_n` E3→A2（5 格）；`rival_s` E3→A3（6 格）
- 来敌：T1 west_cliff：customs、customs；T1 shore：gendarme、customs；T2 @H3：revenue_cutter；T3 rival_n：smuggler[boarder]、smuggler[boarder]；T3 south：customs、customs；T4 east_cliff：gendarme、customs[hunter]；T5 west_cliff：customs_officer、customs；T6 rival_s：rival_smuggler_boss[boarder]、smuggler[boarder]；T6 south：gendarme、customs、customs≥L17；T7 shore：customs、gendarme≥L16
- 说明：1822 年夏天，卡西斯路边的莫尔吉乌小湾（马赛南边的一道石灰岩峡湾）。少年阿梅莉号的长艇（A2、A3 是鹰旗）靠在 B 列的小码头上，货藏在 C2、C4 两个海蚀洞里。海关从三个方向下来：西崖小路（D1，4 步就到船边，最快）、东崖小路（H1）、北岸小路（I2）、南岸小路（I4）。第 3、6 回合，热那亚对头帮的船靠上峡湾中间 E3 的跳板（接舷：从跳板出发），往两岸冲。A1、B1、E1、F1 和 C5、D5、F5–H5 是崖顶（高地）；C1、G1、E5 是崖壁（墙，挡视线）。F2、F4 是碎石滩（步耗 2，防 +1）。海蚀洞：敌炮不瞄准洞里的人，洞里挨远程防 +2，但洞穴挡视线。H3 海面上是海关的缉私快艇（只打与它列差 ≤4 的格子，B 列打不到）。夜里我方小火器射程 −1。走私贩带“隐身”：离我方单位 2 格以外时只看得见一个问号。
- 参考打法（ch2 名册）：两个海蚀洞是天然的堡垒：C2、C4 各放一道阻挡（洞里挨远程防 +2，缉私快艇也不瞄洞里的人）。雅科波的回旋炮上 F1 崖顶朝下，一炮同时罩住 E3 跳板（对头帮上岸的地方）和南岸；E1 再放猎兵朝下打跳板。主角在 A1 崖角（谁的路都不挨着）。西崖小路最短（4 步），第一回合就要有人在 C2。
| 等级 | 什么都不做 | 只放主角（最好的一格） | 参考打法 | 敌数 | 猎官 | 精英 | 敌战力 |
|---|---|---|---|---|---|---|---|
| L15 | defeat t8 | defeat t9 (B4:right) | victory 军心 14 漏 0 倒下 caderousse 命令 未完成 | 18 | 1 | 0 | 282 |

#### `if_corridors` 伊夫堡的那一夜（grand，10×6，L16，13 回合，敌军心 24，天时 night）
```
   ABCDEFGHIJ
 1 __^^#^^#__
 2 _kCCCCCCD_
 3 EkL#D#L##_
 4 EkCCCCCCCD
 5 _,;..v..G_
 6 _WWW^^WW__
```
- 命令：法利亚的遗愿：第 13 回合结束时，唐泰斯站在 B 列的海门石阶上（B2、B3、B4 任一格）。（退路：（内核没有 escape 时）第 13 回合结束时，我方有人守在 B3 海门。）
- 路线：`guard` I2→A3（9 格）；`dungeon` J4→A4（9 格）；`yard` I5→A4（9 格）；`stair_up` E3→A3（6 格）；`stair_dn` E3→A4（5 格）
- 来敌：T1 guard：prison_guard、prison_guard；T1 dungeon：if_soldier、if_soldier、prison_guard[hunter]；T1 @F1：wall_sentry；T2 stair_up：prison_guard、prison_guard[hunter]；T2 @F6：fort_gun；T3 guard：turnkey_chief、prison_guard、if_soldier；T3 yard：if_soldier、if_veteran；T4 stair_dn：if_veteran、prison_guard；T5 dungeon：if_soldier、if_soldier、if_veteran[hunter]；T6 stair_up：if_veteran、prison_guard、prison_guard；T6 @D1：wall_sentry≥L17；T7 yard：if_soldier、if_soldier、if_veteran；T8 guard：if_soldier、prison_guard、if_soldier≥L18；T9 stair_dn：if_veteran、prison_guard、prison_guard[hunter]；T10 dungeon：if_soldier、if_soldier、if_soldier
- 地形事件：打死 turnkey_chief → E3 变成 wall
- 说明：1829 年 2 月的夜里，伊夫堡。法利亚神甫死了（或者，你的药让他撑过了第三次发作），唐泰斯缝进了运尸的麻袋——今夜的运尸工是你的人。可是警钟还是响了。左边 B 列是通往海门的石阶（码头），A3、A4 是靠在礁石下的小艇（鹰旗）。三条路从要塞里面压过来：第 2 行是卫兵室走廊（I2 门），第 4 行是地牢走廊（J4 是从下层牢房上来的楼梯门），第 5 行是院子（I5 是要塞正门，C5 是瓦砾，步耗 2）。E3 是正中间的地牢楼梯门：第 2、4、6、9 回合有人从这里钻出来，往上下两条走廊分头冲（离小艇只有 5–6 步）。**打死典狱长（第 3 回合从卫兵室出来），就拿到了他的钥匙：E3 那扇门立刻锁死（变成墙），之后从 E3 出发的波次不再出现。**走廊（C）是暗的：站在走廊里的射手射程 −1；今夜又是夜战，射程再 −1。C3、G3 是牢房（34 号和 27 号）：我方可以进去（防 +1），敌人不走；牢房夹在两条走廊之间，横队朝上能打卫兵室走廊、朝下能打地牢走廊。D3、F3、H3、I3 和 E1、H1 是墙（挡视线）。C1、D1、F1、G1 是城墙（高地）：F1 一开场就站着一名墙头哨兵（射程 3，先打主角和伙伴），第 17 级起 D1 也会来一名；打死以后那一格可以换我方的人上去。E6、F6 是海边礁岩：F6 第 2 回合起是要塞的报警炮（第 4 回合起每 2 回合一炮），E6 留给我方。B5 是石阶下的小滩。来敌：狱卒、守军、老军士（重型精英）、典狱长；第 1、2、5、9 回合各有一名认得你的人（猎官）。
- 参考打法（ch2_boss 名册）：两条走廊在 C 列各放一道阻挡（C2、C4），院子那一路在 C5 瓦砾上挡（贝尔图乔的筑垒顺手在 B5、D5 放拒马）。D1 城墙上的炮朝下，正好罩住 E3 地牢门和两条走廊；E6 礁岩上再一门朝上。G3 是 27 号牢房：横队进去朝下打地牢走廊和院子。主角在 C1 城墙上：C2 守住，猎官就停在 D2 打不着他。唐泰斯留到最后几回合再上 B2 海门（骠骑兵一上场就冲锋），撑到第 13 回合结束就完成法利亚的遗愿。更好的打法是第 4–6 回合集中火力打死典狱长：E3 的门一锁，第 6、9 回合那两波就不会来了。
| 等级 | 什么都不做 | 只放主角（最好的一格） | 参考打法 | 敌数 | 猎官 | 精英 | 敌战力 |
|---|---|---|---|---|---|---|---|
| L16 | defeat t9 | defeat t9 (C1:right) | victory 军心 5 漏 5 倒下 morel 命令 完成 | 33 | 4 | 6 | 631 |

#### `alley_ambush` 小巷伏击（skirmish，8×4，基准 L12 + 补兵 thug 每 5 级，7 回合，敌军心 10，天时 clear）
```
   ABCDEFGH
 1 BRBB#BRB
 2 ESSSSSSG
 3 ESvSSSSG
 4 BBRBB#BB
```
- 命令：没有一个打手摸到马车边（A2、A3）。
- 路线：`upper` H2→A2（7 格）；`lower` H3→A3（7 格）；`door_n` E2→A2（4 格）；`door_s` F3→A3（5 格）
- 来敌：T1 upper：thug、thug；T1 lower：thug、thug_boss；T1 @G1：thug_marksman；T2 door_n：thug[ambush]、thug[ambush,hunter]；T3 door_s：thug[ambush]、thug[ambush]；T3 upper：gendarme、thug≥L17；T4 lower：thug、gendarme≥L17、thug[hunter]≥L21
- 说明：通用遭遇战（马赛、罗马、巴黎的老城都用它）：一条两边是房子的窄巷，马车（A2、A3 鹰旗）停在巷尾。上下两条路：第 2 行从 H2 的侧巷口来，第 3 行从 H3 正面来；C3 是小喷泉广场（村庄，双方防 +2）。第 2、4 回合有人从 E2、F3 的门洞里冲出来（伏兵），离马车只有 3–4 步。G1 窗后有一个黑枪（定点、射程 3、隐身）。屋顶 B1、G1……C4 只有猎兵能上；E1、F4 是拱门（墙，挡视线）。打手头子打死以后，他那一队后退一格、攻 −1。补兵：每一波按 (L−12)/5 补码头打手（L17 起每波 +1，L22 起 +2）；L17 起上路多一名宪兵，L21 起第 4 回合多一名猎官。
- 参考打法（generic 名册）：巷尾 B2、B3 各一道阻挡；房子 C1、D4 里各放一队横队（C1 朝下、D4 朝上都能同时打两条巷子），C4 屋顶上猎兵朝上。主角进 B4 房子（猎官打不进屋，只会被黑枪惦记）。
| 等级 | 什么都不做 | 只放主角（最好的一格） | 参考打法 | 敌数 | 猎官 | 精英 | 敌战力 |
|---|---|---|---|---|---|---|---|
| L12 | defeat t7 | defeat t7 (A1:right) | victory 军心 14 漏 0 倒下 无 命令 完成 | 11 | 1 | 0 | 114 |
| L14 | defeat t7 | defeat t7 (A1:right) | victory 军心 10 漏 1 倒下 morel 命令 未完成 | 11 | 1 | 0 | 139 |
| L16 | defeat t7 | defeat t7 (A1:right) | victory 军心 14 漏 0 倒下 无 命令 完成 | 11 | 1 | 0 | 153 |
| L19 | defeat t7 | defeat t7 (A1:right) | victory 军心 5 漏 3 倒下 morel 命令 未完成 | 19 | 1 | 0 | 335 |
| L22 | defeat t7 | defeat t7 (A1:right) | victory 军心 12 漏 0 倒下 caderousse 命令 完成 | 26 | 2 | 0 | 519 |

#### `coast_road` 海岸小路（skirmish，8×4，基准 L12 + 补兵 customs 每 5 级，7 回合，敌军心 10，天时 clear）
```
   ABCDEFGH
 1 ^ww.^wwG
 2 E======G
 3 _,,,_,..
 4 __WpWWW_
```
- 命令：第 7 回合结束时，我方有人守在 C2 的拐弯（骡队要从这里过）。
- 路线：`road` H2→A2（7 格）；`hill` H1→A2（8 格）；`cove` D4→A2（5 格）
- 来敌：T1 road：customs、customs、gendarme；T2 hill：mounted_gendarme；T2 cove：smuggler[boarder]、smuggler[boarder]、smuggler[boarder]；T3 road：customs、customs_officer；T4 cove：smuggler[boarder]、smuggler[boarder]≥L16；T4 hill：gendarme、mounted_gendarme≥L21
- 说明：通用遭遇战（普罗旺斯、托斯卡纳、科西嘉的海岸都用它）：一条贴着悬崖的海岸小路（第 2 行），骡队（A2 鹰旗）在左边。海关和宪兵从 H2 大路、H1 山上的小路来；走私贩从 D4 的跳板上岸（接舷），经 D3 沙滩爬上大路，离骡队只有 4 步。A1、E1 是岩石（高地），B1、C1、F1、G1 是灌木林（挨远程防 +2）；E3 是塌掉的路基（虚空：不属于战场，射程跳过），B3–D3 是下面的小沙滩。骑宪兵是猎官，也会逮捕主角。补兵：每一波按 (L−12)/5 补海关缉私兵（L17 起每波 +1，L22 起 +2）。
- 参考打法（generic 名册）：三条路最后都并到海岸路上：C2 拐弯和 B2 各一道阻挡，D3 小沙滩再挡一道（走私贩从这里爬上来）。灌木林 B1、C1、F1 里的横队朝下打路面（林子里挨远程防 +2），E1 岩石上放猎兵或炮。主角在 A1 岩石上。
| 等级 | 什么都不做 | 只放主角（最好的一格） | 参考打法 | 敌数 | 猎官 | 精英 | 敌战力 |
|---|---|---|---|---|---|---|---|
| L12 | defeat t6 | defeat t7 (A1:right) | victory 军心 12 漏 0 倒下 morel 命令 未完成 | 11 | 1 | 0 | 124 |
| L14 | defeat t6 | defeat t7 (A1:right) | victory 军心 13 漏 0 倒下 无 命令 完成 | 11 | 1 | 0 | 156 |
| L16 | defeat t6 | defeat t7 (A1:right) | victory 军心 8 漏 0 倒下 morel、caderousse 命令 未完成 | 12 | 1 | 0 | 190 |
| L19 | defeat t6 | defeat t6 (A1:right) | victory 军心 6 漏 1 倒下 morel、caderousse 命令 未完成 | 18 | 1 | 0 | 334 |
| L22 | defeat t6 | defeat t6 (A1:right) | victory 军心 1 漏 3 倒下 morel、caderousse 命令 未完成 | 25 | 2 | 0 | 618 |

### 7.3 规划中的 8 张（B2 画）

| id | 名字 | 章 | 节点 | 规模 | 尺寸 | 等级 | 回合 | 天时 | 命令 | 敌人 | 战力目标 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| janina_lake | 约阿尼纳湖·湖心岛 | if_years | elite | elite | 9×5 | L15 | 9 | fog | extract | nizam、arnaut、bey、ottoman_gun、gunboat(湖上炮船) | — |
| tiboulen_swim | 蒂布朗岛·暴风雨的黎明 | montecristo | anchor | elite | 9×5 | L17 | 9 | storm | escape | revenue_cutter、gunboat、customs、gendarme(boarder)、wall_sentry(伊夫堡方向的岸上哨兵) | — |
| monte_cristo_cave | 基督山岛·斯帕达的洞 | montecristo | boss | grand | 10×6 | L18 | 13 | clear | extract | rival_smuggler_boss、smuggler(stealth)、pirate(loot)、pirate_captain、customs、revenue_cutter、gunboat | 710 |
| appian_way | 亚壁古道 | mediterranean | elite | elite | 10×5 | L20 | 9 | night | no_leak | bandit(ambush)、bandit_marksman(post, stealth)、papal_carabinier(arrest)、papal_dragoon(hunter) | — |
| san_sebastiano | 圣塞巴斯蒂安墓窟 | mediterranean | boss | grand | 11×6 | L21 | 14 | night | extract | bandit(ambush, ransom)、bandit_marksman(post, stealth)、vampa(leader, ransom)、assassin(stealth)、sbirro(arrest) | 830 |
| auteuil_garden | 奥特伊的花园之夜 | paris_1838 | anchor | elite | 10×5 | L22 | 9 | night | hold | convict(loot)、benedetto(hunter, execute)、police_agent(stealth, arrest)、thug_marksman | — |
| paris_rooftops | 西岱岛的屋顶 | paris_1838 | elite | elite | 10×5 | L23 | 9 | rain | no_leak | assassin(stealth)、thug_marksman(post)、municipal_guard(heavy)、police_agent(arrest) | — |
| cristo_final | 司法宫之夜 | paris_1838 | boss | epic | 12×7 | L24 | 14 | night | protect | convict(loot)、assassin(stealth, hunter, execute)、police_agent(arrest)、municipal_guard(heavy)、national_guard、thug_marksman(post)、mounted_gendarme | 960 |

规格细节（地形字符、命令、波次思路）在 `battle_templates_cristo.json.planned`。战力目标按 A5（相邻章 Boss ≥ ×1.12）倒推。

## 8 剧情

### 8.1 第一章全文（VN 可直接用；背景与立绘位见 `vn_cast_cristo.json`）

**第一章·第一场：法老号的旗** `c_landfall` · 1815-02-28 · 马赛旧港·圣让堡下的码头 · 主讲 morrel
> 1815 年 2 月 28 日清晨，马赛旧港。从费拉约港来的小渔船在圣让堡下靠了岸。
> 你贴身带着皇帝的信。信封上写着：努瓦蒂埃先生，巴黎，科克埃龙街十三号。马赛有一个转交的地址。
> 港里停着一条三桅船，船尾漆着“法老号”，桅顶挂着莫雷尔父子商行的旗。
> 莫雷尔：“从厄尔巴来的？小心点。港务处今天在查每一条从岛上来的船。”
> 莫雷尔：“法老号前天进的港。勒克莱尔船长死在海上，是大副唐泰斯把船带回来的。我要让他当船长。”
> 莫雷尔：“今天中午他在雷瑟夫酒家订婚，新娘是加泰罗尼亚人村的梅尔塞苔丝。”
> 码头另一头，两个宪兵在挨个问渔夫话。其中一个手里拿着一张名单。
> 莫雷尔压低了声音：“昨晚有人往王家检察署送了一封信。我的押运员唐格拉尔，今早一直在笑。”
查验：看宪兵手里的名单（spot）：名单上有三行：法老号大副唐泰斯；从厄尔巴来的第二个信使，姓名不详；还有一行被墨水划掉了。；掂一掂贴身的那封信（weigh）：信比出发时重了一点：贝特朗元帅在封蜡里压了一枚小鹰徽。拆过的人一眼就看得出来。
抉择：
- `go_reserve` 先去雷瑟夫酒家，赶在中午以前提醒唐泰斯 → {"morale": 3} m_rushed_reserve {"recruit": ["morel"]}
- `deliver_first` 先把信送到转交地址：皇帝的事在前 → {"treasury": 300} m_letter_delivered {"recruit": ["morel"], "coins": {"intel": 1}}
- `call_on_gerard` 去王家检察署拜访族兄杰拉尔，先探他的口风（需查验 police_list） → {"heat": -10} m_called_on_gerard {"recruit": ["morel"]}

**第一章·第二场：雷瑟夫酒家的订婚宴** `c_reserve` · 1815-02-28 · 雷瑟夫酒家·葡萄架下 · 主讲 dantes
> 正午，雷瑟夫酒家。葡萄架下摆了二十副刀叉，海风把桌布吹得鼓起来。
> 唐泰斯：“再过十四天我就是船长了。梅尔塞苔丝，再过一个钟头，你就是唐泰斯太太。”
> 梅尔塞苔丝笑着，手却一直攥着餐巾。她的表哥费尔南坐在桌尾，一口酒也没喝。
> 卡德鲁斯已经醉了：“唐格拉尔，你昨天在这张桌子上写的那张纸呢？丢啦？”
> 唐格拉尔：“什么纸？你喝多了。”
> 楼梯上响起靴子声。一个佩着白色绶带的警长走进来，身后是四个宪兵。
> 警长：“以法律的名义！谁是埃德蒙·唐泰斯？”
> 老唐泰斯站起来，碰翻了酒杯。唐泰斯：“是我。一定是弄错了。”
> 警长的目光扫过整张桌子，在你身上停了一下：“还有一位从厄尔巴来的先生？”
查验：看葡萄架下那团纸（spot）：桌脚边有一团揉皱的纸，被人踢进了葡萄架的阴影里。纸角上有半行字：“……从厄尔巴岛……一封给巴黎篡位党的信……”；细看那半行字的笔迹（decode）：字往左歪，笔画僵硬，是故意用左手写的。卡德鲁斯说，昨天坐在这个位置上的是唐格拉尔；把纸捡走又扔回来的，是费尔南。
抉择：
- `take_the_paper` 趁乱捡起葡萄架下那团纸，收进袖子（需查验 crumpled_paper） → {"heat": 5} m_denunciation 
- `vouch_for_him` 亮出军需官的委任状，要求陪他去检察署 → {"morale": 4, "heat": 10} m_escorted {"coins": {"medal": 1}}
- `caderousse_home` 把醉倒的卡德鲁斯扶回家，听他把昨天的事说完（需查验 left_hand） → {"heat": -3} m_caderousse_talked {"recruit": ["caderousse"]}
- `keep_quiet` 一言不发。你身上还有一封同样的信 → {"heat": -8, "morale": -3} m_silent_feast 

**第一章·第三场：烛火** `c_gerard` · 1815-02-28 · 大库尔街·王家代理检察官的书房 · 主讲 gerard
> 当天夜里，大库尔街。杰拉尔·德·维尔福刚从圣梅朗侯爵家的订婚宴上回来，礼服还没换。
> 桌上摊着从唐泰斯身上搜出来的那封信。信封上写着：努瓦蒂埃先生，巴黎，科克埃龙街十三号。
> 杰拉尔：“努瓦蒂埃。你知道这是谁吗？是我父亲。”
> 他把信凑到烛火上。火苗卷起来的时候，他的手很稳。
> 杰拉尔：“那个水手什么都不知道。所以，他必须一直什么都不知道下去。”
> 杰拉尔：“厄尔巴来了两个信使。一个在楼下，另一个——”他抬头看你，“——姓维尔福。”
> 杰拉尔：“族弟，这个姓在国王那边值一个检察官，在皇帝那边值一个参议员。你要拿它去换一个水手吗？”
> 窗外，一辆没有标记的马车停在门口。车夫在等一道命令：去伊夫堡。
查验：看桌上卷宗的封面（decode）：封面写着：唐泰斯，狂热的波拿巴党人，参与厄尔巴复辟阴谋。不得探视，严加看管。下面是一个编号，你把它记住了。；看门口那辆马车（spot）：车门上的纹章被泥糊住了，车夫是检察署的人。马车不去监狱，去港口：伊夫堡没有审判，只有登记簿。
抉择：
- `trade_your_letter` 把你的那封信也交给他，换他答应“关几个月就放” → {"heat": -25, "morale": -6} m_bargain、m_letter_burned 
- `warn_him` 当面告诉他：烧信是重罪，你会去作证 → {"heat": 20, "morale": 5} m_threatened_gerard 
- `memorize_the_file` 什么也不说，记下卷宗编号，告辞（需查验 dossier_no） → {} m_dossier_no {"coins": {"intel": 2}}
- `show_denunciation` 把那张左手写的告密信摆到他面前（需旗标 m_denunciation） → {"heat": 10, "morale": 2} m_leverage 

**第一章·第四场：莫雷尔的请愿书** `c_petition` · 1815-04-12 · 梅朗林荫道·莫雷尔父子商行的账房 · 主讲 morrel
> 1815 年 4 月，马赛。皇帝回到了杜伊勒里宫，港口的百合花旗换成了三色旗。
> 杰拉尔·德·维尔福却还坐在检察署里。他的父亲努瓦蒂埃，现在是皇帝身边的红人。
> 莫雷尔：“现在是我们的天下了，唐泰斯总该放出来了吧？我去求过检察官三次。”
> 莫雷尔：“他说，写一份请愿书，把唐泰斯替皇帝送信的功劳写得越大越好，他亲自转呈内政部。”
> 桌上是莫雷尔照着检察官的口授写好的草稿：“……唐泰斯为皇帝的归来立下了大功……”
> 你知道这份请愿书最后会落进谁的抽屉，也知道皇帝在巴黎能待多久。
> 莫雷尔：“维尔福先生，你是军需官，见过公文。你说，这样写行不行？”
查验：逐句读请愿书草稿（decode）：每一句都在替唐泰斯认罪：“狂热”“为皇帝效力”“参与归来”。皇帝在位时这是功劳；国王回来那天，这就是判决书。；看检察官给的回执（spot）：回执上盖的是检察署的私章，不是转呈内政部的公章。这份东西根本没打算离开马赛。
抉择：
- `rewrite_plain` 替他重写：只写唐泰斯是个好水手，与政治无关（需查验 dictated_lines） → {"morale": 3} m_petition_clean 
- `carry_to_paris` 亲自把请愿书送去巴黎，交到努瓦蒂埃手里（需查验 ministry_stamp） → {"treasury": -400, "vitality": -8} m_noirtier_met {"coins": {"medal": 2}}
- `let_it_go` 照检察官说的寄出去 → {} m_petition_dictated {"coins": {"gold": 1}}

**第一章·终场：白帽徽的六月** `c_white_june` · 1815-06-25 · 旧港北岸·莫雷尔商行的货栈 · 主讲 morrel
> 1815 年 6 月 25 日。滑铁卢的消息到了马赛。
> 一夜之间，城里的三色旗全不见了，白帽徽别在每一顶帽子上。
> 勒潘尼耶的坡上有人在喊：“打死波拿巴分子！”埃及难民住的那条街起了火。
> 莫雷尔：“他们要砸商行的货栈，说法老号给篡位者送过信。”
> 宪兵手里拿着检察署的新名单。第一行：埃德蒙·德·维尔福，前帝国军需官。
> 莫雷尔：“我不走。这是我父亲的货栈。”
> 码头石阶下，加泰罗尼亚人的小船在等你。船头的人朝你招手。
抉择：
- `stay_in_marseille` 留在马赛，借莫雷尔商行的名义做军需买卖 → {"treasury": 600, "heat": 10} m_stay_marseille 
- `ask_gerard` 去找杰拉尔：国王回来了，他需要一个不说话的族人 → {"heat": -30, "morale": -8} m_gerard_patron 
- `sail_genoa` 上船去热那亚，等风头过去 → {"vitality": -6, "heat": -15} m_exile_genoa {"coins": {"supply": 2}}

### 8.2 第二到五章（第二章可直接用，第三到五章是提纲，抉择形状已定）

- **第二章·第一场：面包合同** `c_if_contract`（1816-03-12，伊夫堡·典狱长的办公室）：1816 年 3 月，伊夫堡。从马赛港坐小船过来要一个钟头，浪大的时候要两个钟头。典狱长：“驻军六十人，犯人四十一个。面包、油、蜡烛、柴火，每月一船。上一个承包商往面粉里掺石灰。” 抉择：报一个公道价：面粉过秤，一斤不少 / 提杰拉尔的名字：检察署担保，价钱好说 / 趁典狱长转身，把 34 号那一页撕下来。
- **第二章·第二场：34 号的面包** `c_bread_34`（1817-07-20，伊夫堡·地牢的厨房）：1817 年夏天。每个月的面包船，你都亲自押。你在给 34 号的那条面包里塞了一张纸条，只有一行字：莫雷尔还在为你奔走。 抉择：把三个名字写给他：唐格拉尔、费尔南、杰拉尔·德·维尔福 / 只写两个字：等待 / 写上你自己的名字：你也是维尔福家的人。
- **第二章·第三场：27 号的神甫** `c_faria_27`（1818-12-03，伊夫堡·27 号牢房）：1818 年冬。典狱长准你进地牢给生病的犯人送药：承包商顺便管药，这一条是你自己写进合同的。27 号的神甫很瘦，眼睛很亮。床板下压着一卷写满了字的衬衫布。 抉择：拼上那半封信，记下藏宝的位置 / 照他的方子去马赛配药，每月随面包一起送进来 / 给地道送工具：一把凿子、一卷绳子。
- **第二章·第四场：莫尔吉乌的走私湾** `c_morgiou`（1822-08-14，卡西斯海岸·莫尔吉乌小湾）：1822 年 8 月。一份面包合同养不活一张关系网。你需要船，需要不问来历的钱。少年阿梅莉号的船老大在卡西斯的酒馆里有一张桌子。坐在他旁边的是个瘦高的水手，叫雅科波。 抉择：货按约平分，一个苏也不多拿 / 用你那一份买下一条小船，停在伊夫堡背面的礁石后 / 把热那亚帮的船报给海关，换一张缉私队的通行证。
- **第二章·第五场：第三次发作** `c_faria_dies`（1829-02-14，伊夫堡·27 号牢房）：1829 年 2 月。十四年了。地道早就通了，34 号和 27 号每天夜里见面。唐泰斯：“他倒下了。第三次。半边身子已经不能动。” 抉择：照唐泰斯的计划：他钻进麻袋，你的船在礁石后面等 / 把最后一瓶药水灌下去：十二滴，再等一天 / 把一把刀缝进麻袋的夹层。
- **第二章·终场：伊夫堡的那一夜** `c_if_night`（1829-02-28，伊夫堡·海门）：1829 年 2 月 28 日夜。从雷瑟夫酒家那天算起，整整十四年。麻袋落水的声音还没传到墙头，警钟就响了：有个看守多看了一眼麻袋的形状。 抉择：按原计划：让他游向蒂布朗岛，少年阿梅莉号明早经过 / 把他拉上你的小船，直接去热那亚 / 你留下来，用承包商的身份把警钟的事压下去。
- **第三章·第一场：蒂布朗岛** `c_tiboulen`（1829-03-01，蒂布朗岛·礁石）：黎明前，蒂布朗岛。唐泰斯趴在礁石上，海里漂着伊夫堡的麻袋和一顶看守的帽子。少年阿梅莉号的帆从南边过来。后面跟着两条海关的快艇。 抉择：让他冒充遇难的马耳他水手上船 / 给船老大加一笔钱：这个人上船，谁也别问 / 你的小船朝西开，把快艇引走。
- **第三章·第二场：里窝那的理发店** `c_livorno`（1829-03-09，里窝那·港口边的理发店）：里窝那。理发师剃掉了十四年的胡子。唐泰斯盯着镜子里的人，很久没说话。唐泰斯：“这个人我不认识。很好。认识他的人，也不会认得了。” 抉择：替他起个新名字：水手辛巴达 / 以你的名义在里窝那开一个账户，替他存第一笔钱 / 把马赛这十四年的事一件一件告诉他。
- **第三章·终场：斯帕达的宝藏** `c_montecristo`（1829-05-24，基督山岛·第二个小湾往东）：基督山岛。第二个小湾往东，第二十块岩石。唐泰斯用火药炸开了洞口。洞里是三只箱子：金锭、金币、宝石。斯帕达枢机的遗产，三百三十年没人碰过。 抉择：全部运走：从今天起，他是基督山伯爵 / 留下一箱，刻上法利亚的名字 / 按军需官的老规矩，先提一成做“运费”。
- **第四章·第一场：加尔桥客栈** `c_caderousse`（1829-06-03，博凯尔大路·加尔桥客栈）：1829 年 6 月，博凯尔到贝勒加德的大路边。卡德鲁斯开的客栈门可罗雀。一个意大利口音的神甫敲门，自称布索尼。他拿出一颗钻石：“唐泰斯死在牢里，临终托我把这个分给他的朋友。” 抉择：让“神甫”把钻石给他 / 你出面把钻石按市价买下，把钱给他 / 私下警告卡德鲁斯：这颗钻石会要了你的命。
- **第四章·第二场：九月五日** `c_morrel_rescue`（1829-09-05，梅朗林荫道·莫雷尔家）：1829 年 9 月 5 日，马赛。莫雷尔父子商行今天到期的期票是二十八万七千五百法郎。莫雷尔把手枪放在桌上。他的女儿朱莉在楼下被一个英国人拦住，那人给了她一只红丝钱袋。 抉择：照伯爵的安排：钱袋、期票、钻石，一样不少 / 上楼告诉莫雷尔：救你的人是唐泰斯 / 替马克西米利安在北非骑兵团里谋一个位置。
- **第四章·第三场：罗马狂欢节** `c_carnival`（1838-02-20，罗马·伦敦饭店／人民广场）：1838 年 2 月，罗马狂欢节。九年过去了。伦敦饭店住着两个巴黎来的年轻人：阿尔贝·德·莫尔塞夫和弗朗兹·德·埃皮奈。隔壁套房住着基督山伯爵。 抉择：派人盯着阿尔贝：他今晚要去罗马城外看古迹 / 去汤姆森与弗伦奇银行，替伯爵在巴黎开无限信用 / 陪海黛去看狂欢节：她第一次笑。
- **第四章·终场：圣塞巴斯蒂安墓窟** `c_san_sebastiano`（1838-02-22，亚壁古道·圣塞巴斯蒂安墓窟）：阿尔贝被绑了。万帕的人送来一张纸条：清晨六点以前四千皮阿斯特，否则子弹。墓窟在亚壁古道底下，一层叠一层的壁龛里都是骨头。 抉择：照价付赎金，一个皮阿斯特也不还 / 让万帕记住：这一次是伯爵欠你的，不是你欠伯爵的 / 把阿尔贝拉到一边：你父亲的事，你迟早会知道。
- **第五章·第一场：十点半的早餐** `c_champs_elysees`（1838-05-21，巴黎·香榭丽舍大街 30 号）：1838 年 5 月 21 日上午十点半，阿尔贝家的早餐。基督山伯爵准时到了，一分不差。客人里有唐格拉尔男爵的女婿候选人，有王家检察官的未来女婿，还有马克西米利安·莫雷尔。 抉择：当晚列出巴黎的名单：莫尔塞夫、唐格拉尔、维尔福 / 以族人的身份去拜访王家检察官 / 去见努瓦蒂埃老人：他只能用眼睛说话。
- **第五章·第二场：奥特伊的花园** `c_auteuil`（1838-06-20，奥特伊·方丹街 28 号）：奥特伊的晚宴。伯爵请了唐格拉尔夫妇、维尔福夫妇。杰拉尔在花园的那棵树下站住了。伯爵：“这座房子里发生过一桩罪行。我的管家说，二十一年前，有人在这棵树下埋过一只木匣。” 抉择：当着杰拉尔的面，让贝尔图乔把木匣挖出来 / 提前把木匣挖走，不让他在客人面前崩溃 / 跟踪墙外的人：他和卡德鲁斯在一起。
- **第五章·第三场：贵族院** `c_peers`（1838-07-10，卢森堡宫·贵族院议事厅）：贵族院。有人在报上登了一条短讯：1822 年约阿尼纳城堡献城的法国军官，名叫费尔南。莫尔塞夫伯爵站在议席上：“诬蔑。我要求调查。” 抉择：把约阿尼纳的卖身契递给议长 / 让海黛自己作证 / 梅尔塞苔丝来求你：别让阿尔贝看见。
- **第五章·第四场：电报** `c_danglars`（1838-08-30，蒙莫朗西电报站／唐格拉尔银行）：唐格拉尔男爵靠内部消息做西班牙公债。他的消息来自政府的电报线。伯爵在一座偏僻的电报站停下马车，和电报员谈了一刻钟。第二天，电报说堂卡洛斯回到了西班牙。 抉择：照伯爵的计划，一步一步掏空唐格拉尔的银行 / 只追回当年该给法老号的那笔钱 / 把左手写的告密信登在报上。
- **第五章·终场：司法宫的那一夜** `c_trial`（1838-10-15，西岱岛·司法宫重罪法庭）：重罪法庭。被告安德烈亚·卡瓦尔康蒂，真名贝内代托，杀害卡德鲁斯。公诉人：王家检察官杰拉尔·德·维尔福。庭长：“被告，你的父亲是谁？”贝内代托笑了：“我会说的。不过不是今天。” 抉择：守住他，让他在法庭上说完：我的父亲是王家检察官杰拉尔·德·维尔福 / 在他开口之前把他带出法国：这个姓，你来保 / 让伯爵停手：瓦朗蒂娜还活着，这就够了。

### 8.3 随机事件、军议、幕间

| id | 池 | 标题 | 权重 | 抉择 |
|---|---|---|---|---|
| ev_c1_council | fixed | 圣洛朗教堂的密会 | 0 | 把商行库里的旧火枪全搬到码头（开场军令点 +2）、让人在城里放话：国王会大赦（敌军心 −2）、提前一夜把小船调到石阶下（多一回合布阵） |
| ev_c2_council | fixed | 卡西斯的船老大们 | 0 | 买通敲警钟的看守，让他晚敲一刻钟（开场军令点 +2）、让人在马赛港放一船烟花，把驻军的眼睛引过去（敌军心 −2）、派两个水性好的人提前潜到海门下面（多一回合布阵） |
| ev_janina_1822 | fixed | 湖上的总督 | 0 | 记下费尔南和使者谈话的时辰与地点、城破以后，倾尽所有从奴隶贩子手里买下母女二人、把火药卖给苏丹的人，赶在城破以前离开 |
| ev_mercedes_window | marseille | 加泰罗尼亚人村的窗 | 3 | 告诉她实话：伊夫堡，没有刑期、告诉她：等着，他会回来、当着费尔南的面说：告密信是谁投的，我知道 |
| ev_old_dantes | marseille | 梅朗林荫道的阁楼 | 3 | 替他付一年的房租和柴火钱，说是法老号欠的工钱、把莫雷尔请上楼，一起劝他、把钱放在门口就走 |
| ev_danglars_cargo | marseille | 唐格拉尔的账 | 3 | 把他的账摊给莫雷尔看、收下他的回扣，也收下他的把柄、装作没听懂 |
| ev_caderousse_wine | marseille | 卡德鲁斯的酒 | 3 | 雇他：你缺一个熟悉马赛每条巷子的人（金币 −1）、让他发誓：将来上法庭，他会作证、让他接着喝 |
| ev_renee_plea | marseille | 圣梅朗家的小姐 | 3 | 告诉她实情，请她每年去伊夫堡的教堂为 34 号捐一次灯油、请她向侯爵要一张出入港口的通行证、什么也别让她知道：她会嫁给他 |
| ev_inspector | if_years | 监狱督察 | 3 | 替 34 号说话：这人没有审判记录、塞给督察一袋金币，请他把 34 号的卷宗带回巴黎、附和他：都是疯子 |
| ev_bertuccio_name | if_years | “你也姓维尔福？” | 3 | 告诉他实话：是，他是我族兄、说你只是同姓、转身就走 |
| ev_old_dantes_end | if_years | 老唐泰斯的最后一个冬天 | 5 | 撞开门，叫医生、你来晚了。替他办一场像样的葬礼 |
| ev_accoules | if_years | 阿库尔教堂的婚礼 | 3 | 站在教堂最后一排，看完婚礼、把消息写进面包里，告诉 34 号、转身离开 |
| ev_customs_cutter | cristo | 缉私快艇 | 4 | 按规矩给钱（金币 −1）、亮出缉私队的通行证、扯满帆跑 |
| ev_widow_pension | cristo | 老兵的寡妇 | 3 | 从自己的钱里垫上、替她写信给陆军部，用你从前的官衔签名、说你已经不是军需官了 |
| ev_tail | cristo | 尾巴 | 3 | 转过身去，直接问他是谁派来的、穿过鱼市甩掉他、故意让他看见一封假信 |
| ev_genoa_banker | montecristo | 热那亚的银行家 | 3 | 说是一位意大利枢机的遗产、只卖最小的那颗，免得惹人问、不卖，拿它作抵押开一张信用状 |
| ev_haydee_constantinople | fixed | 君士坦丁堡的奴隶市场 | 0 | 伯爵出价：一颗翡翠、派船去马赛接她 |
| ev_telegraph | fixed | 电报员的花园 | 0 | 给他买一个大花园：两万五千法郎、这一次不碰政府的线 |
| ev_noirtier_eyes | paris_1838 | 努瓦蒂埃的眼睛 | 8 | 法利亚的红药水：每次十二滴、按伯爵的办法：给她一颗让人假死的药丸、去告诉杰拉尔：凶手在你家里 |
| ev_c3_council | fixed | 少年阿梅莉号的甲板 | 0 | 先把两桶火药悄悄搬上岸（开场军令点 +2）、让船老大在卡普拉亚放话：我们去撒丁岛（敌军心 −2）、天黑以前就靠岸（多一回合布阵） |
| ev_c4_council | fixed | 万帕的信使 | 0 | 让佩皮诺带路，走墓窟的后门（开场军令点 +2）、把伯爵的名片交给佩皮诺先送进去（敌军心 −2）、不等天亮，现在就走（多一回合布阵） |
| ev_c5_council | fixed | 圣母院的钟楼 | 0 | 买通附属监狱的两个看守（开场军令点 +2）、把开庭的消息透给报馆：明早全巴黎都会在门口（敌军心 −2）、天一黑就把人调过钟楼码头（多一回合布阵） |
| ev_i_marseille | interlude:bond | 加泰罗尼亚人的小船上 | 0 | 挑两位伙伴，信赖各 +1 |
| ev_i_if_years | interlude:minigame:decode | 法利亚的衬衫书 | 0 | 破译密码表（查验小游戏·破译）、收好衬衫，以后再看 |
| ev_i_montecristo | interlude:camp_night | 基督山岛的第一夜 | 0 | 让大家睡一整夜（体力 +8）、连夜清点箱子（经费 +400）、陪他坐到天亮（人心 +4） |
| ev_i_mediterranean | interlude:audience | 伯爵召见 | 0 | “维尔福这个姓，你打算怎么办？”——“它不是我选的。”、“如果有人求你放过他？”——“看他求的是什么。”、“账要算到哪一笔为止？”——“算到最后一笔。” |
| ev_i_paris | interlude:minigame:weigh | 唐格拉尔的金库 | 0 | 逐只过秤（查验小游戏·过秤）、不必了，账簿上已经写着 |

- 随机池：章池（`marseille`、`if_years`）和段池（`cristo`，任何一章都能抽到）。`fixed` 是挂在固定节点上的（军议、约阿尼纳、君士坦丁堡、电报站），`interlude:*` 是章与章之间的幕间。
- 事件里没有 `branch`、`ending`、`advance`（自检）。

## 9 美术

共 124 项（bg 34、cg 4、chara 26、face 21、unit 39）。新背景 31 张（每个场景一张，事件共用几张）、地图背景 3 张（`map_marseille_1815` 新增；`map_if_fortress`、`map_paris` 是 ARCH 已列的 id，这里补画面说明）、结局 CG 4 张、新立绘与头像各 21 人、旧立绘的年代变体 5 个（年轻的唐泰斯、囚徒唐泰斯、囚徒法利亚、1815 年的莫雷尔与主角）、战场小人 8 个伙伴 + 31 个敌人。

## 10 待拍板 / 风险

1. **主角不坐牢**是本稿最大的选择。替代方案：让主角也进伊夫堡（35 号，和唐泰斯隔一堵墙），第二章变成「牢中岁月」局部图（ARCH §9.6 的提议）。本稿把它保留成大命运 `m_cell_35`：输了第一章的仗会进去一年。
2. **法利亚活下来**偏离原著。它只在玩家主动选了药才发生，而且把「宝藏」换成了「人」（第二章三选一），代价清楚。
3. **主干最后一场 L12 与分支第一章遭遇战 L12** 的读法与鹰飞草稿一致；A 若坚持 ARCH 原文（分支第一场 ≥ L13），本分支所有等级整体 +1（第一章 Boss L15），模板不用改（通用遭遇战有补兵）。
4. **三种新命令**（escape / extract / protect）需要 B 在内核里加；没加之前退回 hold / no_leak，战斗照样能打。
5. **第三到五章的模板**还没画；第一、二章 + 通用遭遇战已经够一个完整的「马赛 → 出逃」试玩切片。
6. 第五章的贵族院、电报、审判是原著最出名的桥段，本稿只给了提纲；正文要等主创确认语气（原著的复仇很冷，本作的主角是旁观者也是同谋）。

## 11 文件

统计：{"scenes": 23, "events": 27, "random_events": 14, "characters": 25, "items": 11, "endings": 4, "companions_new": 8, "templates_built": 6, "templates_planned": 8, "enemies": 38, "art_assets": 124, "flags_set": 108}

- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/data/campaigns/napoleon/cristo.json`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/data/campaigns/napoleon/maps/med.json`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/data/campaigns/napoleon/companions_cristo.json`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/data/campaigns/battle_templates_cristo.json`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/data/campaigns/napoleon/book_cristo_patch.json`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/data/hd/art_requests/C_cristo.json`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/data/hd/vn_cast_cristo.json`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/maps/preview_marseille.png`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/maps/preview_if_years.png`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/maps/preview_montecristo.png`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/maps/preview_mediterranean.png`
- `/tmp/claude-0/-home-user/f413af39-a419-5ad7-b290-de5bfd493b6e/scratchpad/wm/cristo/maps/preview_paris_1838.png`

工具（可重跑）：`tools/build_cristo.py`（生成 + 自检 + 模拟 + 预览图）、`tools/build_doc.py`（本文）、`tools/battle_sim.py` / `battle_lib.py`（模拟器与校验器）、`tools/cristo_*.py`（数据源）。
