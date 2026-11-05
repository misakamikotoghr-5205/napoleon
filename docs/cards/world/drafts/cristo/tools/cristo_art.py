# -*- coding: utf-8 -*-
# Art requests (data/hd/art_list.json entry shape) and VN cast table for the cristo branch.
NO = "画面里不要有人物和文字。"


def bg(id, name, desc, used, pr="P0"):
    return {"kind": "bg", "id": id, "name": name, "priority": pr, "desc": desc + NO, "used_in": used}


ART = [
    # ---------------------------------------------------------------- chapter 1 backgrounds
    bg("marseille_quay_1815", "马赛旧港·圣让堡下的码头（1815）", "1815 年 2 月的清晨，马赛旧港北岸：圣让堡的方塔、石头码头、缆桩和渔网，港里一条三桅商船（船尾的名字看不清），桅顶挂着一面红白商行旗；远处是守护圣母山。冷蓝的晨光，海鸥。", ["c_landfall"]),
    bg("la_reserve_arbour", "雷瑟夫酒家·葡萄架下", "海边酒家的葡萄架下，长桌铺着白桌布，二十副刀叉、酒瓶、一束橙花；桌脚边的阴影里有一团揉皱的纸。背景是蓝色的海湾和加泰罗尼亚人村的白房子。正午强光。", ["c_reserve"]),
    bg("gerard_study", "大库尔街·检察官的书房", "1815 年一位年轻王家检察官的书房：深色护墙板，书架上的法典，桌上一支烛台、一封拆开的信、一叠卷宗；壁炉里有纸烧过的灰。窗外夜色里停着一辆没有纹章的马车。暖烛光对冷夜色。", ["c_gerard"]),
    bg("morrel_counting_room", "莫雷尔父子商行的账房", "船东商行的账房：高脚账桌、羽毛笔、成摞的提单和船的模型，墙上挂着一张地中海海图和法老号的版画；窗外港口里升着三色旗。午后暖光。", ["c_petition"]),
    bg("old_port_white_june", "旧港北岸·白帽徽的六月", "1815 年 6 月 25 日，马赛旧港北岸的货栈门口：石板街上散落着撕碎的三色旗和白帽徽，远处勒潘尼耶的坡上有烟，码头石阶下系着两条小船。黄昏，火光。", ["c_white_june"]),
    bg("catalans_village", "加泰罗尼亚人村", "马赛城外海边的小渔村：低矮的白房子、晾着的渔网、一扇半开的窗，窗台上放着一张没补完的网。午后。", ["ev_mercedes_window"], "P1"),
    bg("meilhan_attic", "梅朗林荫道的阁楼", "老城一座公寓的阁楼：斜屋顶、一张铁床，床头叠着一件水手服；冷灶台，窗外是梅朗林荫道的梧桐。冬天的灰光。", ["ev_old_dantes", "ev_old_dantes_end"], "P1"),
    bg("saint_laurent_sacristy", "圣洛朗教堂的圣器室", "港口边一座老教堂的圣器室：石墙、圣袍柜、一张长桌上摊着马赛老城的街巷图，几支蜡烛。夜。", ["ev_c1_council"], "P1"),
    # ---------------------------------------------------------------- chapter 2 backgrounds
    bg("if_governor_office", "伊夫堡·典狱长的办公室", "伊夫堡要塞里的办公室：粗石墙、拱窗外是海和马赛的远影，桌上一本很厚的登记簿、钥匙串和一盏油灯，墙角堆着面粉袋。阴天。", ["c_if_contract"]),
    bg("if_dungeon_kitchen", "伊夫堡·地牢的厨房", "要塞底层的厨房：黑铁大锅、成排的面包、空面包筐，筐底有一片碎瓦；一道石阶通向更深的地牢。昏暗，炉火光。", ["c_bread_34"]),
    bg("if_cell_27", "伊夫堡·27 号牢房", "一间石头牢房：高处一扇小铁窗，床板下压着一卷写满字的衬衫布，地上一块松动的石板，墙上用炭画着日晷和星图。月光。另做一张“night”变体：油灯，石板掀开，露出地道口。", ["c_faria_27", "c_faria_dies"]),
    bg("morgiou_cove_night", "莫尔吉乌小湾·夜", "马赛南边的石灰岩峡湾：白色悬崖夹着一道黑水，崖底两个海蚀洞，一条长艇靠在小码头上；崖顶有几盏提灯。夜，月光。", ["c_morgiou"]),
    bg("if_sea_gate_night", "伊夫堡·海门", "夜里的伊夫堡海门：湿漉漉的石阶通到海面，礁石下系着一条小艇，城墙上有火把，远处是马赛的灯。风很大。", ["c_if_night"]),
    bg("cassis_backroom", "卡西斯·酒馆后屋", "渔港酒馆的后屋：酒桶、渔具、一张粗木桌上摊着海图和几只锡杯，墙上挂着一盏防风灯。夜。", ["ev_c2_council", "ev_bertuccio_name"], "P1"),
    bg("janina_lake_island", "约阿尼纳·湖心岛", "1822 年冬，约阿尼纳湖心岛上的修道院：拜占庭式的穹顶、木回廊、成桶的火药；湖对岸的城堡在冒烟，湖面有雾。", ["ev_janina_1822"], "P1"),
    bg("accoules_church", "阿库尔教堂", "马赛老城的阿库尔教堂内部：高耸的钟楼脚下，空空的长椅，祭坛前散着白花。", ["ev_accoules"], "P2"),
    # ---------------------------------------------------------------- chapter 3-5 backgrounds
    bg("tiboulen_dawn", "蒂布朗岛·黎明", "马赛湾外一座光秃秃的小礁岛：黑色礁石、白浪，海面漂着一只麻袋和一顶帽子；远处一条三桅小帆船的帆。黎明前的灰蓝。", ["c_tiboulen"]),
    bg("livorno_barber", "里窝那的理发店", "托斯卡纳港口边的理发店：一面旧镜子、铜盆、剃刀和毛巾，窗外是桅杆林立的港口。上午。", ["c_livorno"]),
    bg("montecristo_treasure", "基督山岛·斯帕达的洞", "一座荒岛的山洞深处：火把照着三只打开的铁箱，金锭、金币、宝石和珍珠堆得冒尖；洞口外是蓝色的海湾和一条小帆船。", ["c_montecristo"]),
    bg("pont_du_gard_inn", "加尔桥客栈", "普罗旺斯大路边一家破旧的客栈：低矮的饭厅、一张桌上放着一颗钻石和两只酒杯；窗外远处是加尔桥的三层拱。黄昏。", ["c_caderousse"]),
    bg("morrel_house_1829", "梅朗林荫道·莫雷尔家（1829）", "船东家的书房：桌上一把手枪、一叠到期的期票和一只红丝钱袋；窗外港口里一条崭新的三桅船正在进港。早晨。", ["c_morrel_rescue"]),
    bg("rome_carnival", "罗马狂欢节", "1838 年罗马的科尔索大街：彩带、纸屑、面具、马车，阳台上挂着红布；远处人民广场的方尖碑。白天。", ["c_carnival"]),
    bg("san_sebastiano_catacomb", "圣塞巴斯蒂安墓窟", "古罗马的地下墓窟：一层叠一层的壁龛和骨头，火把，拱形的石廊伸向黑暗，地上有一张铺着羊皮的石桌。", ["c_san_sebastiano"]),
    bg("champs_elysees_salon", "香榭丽舍大街 30 号的客厅", "1838 年巴黎一座豪宅的东方式客厅：丝绸靠垫、波斯地毯、水烟袋、黄金镶边的屏风；窗外是香榭丽舍大街的林荫道。上午十点半。", ["c_champs_elysees"]),
    bg("auteuil_garden_night", "奥特伊的花园·夜", "巴黎西郊一座老宅的花园：一棵老梧桐，树下的泥土被翻过，石墙上有一扇小门；宅子的窗里透出晚宴的灯光。夜。", ["c_auteuil"]),
    bg("chamber_of_peers", "卢森堡宫·贵族院", "1838 年的贵族院议事厅：半圆形的红丝绒议席、讲坛、穹顶下的吊灯，议长桌上放着一张旧纸。", ["c_peers"]),
    bg("danglars_bank", "昂坦街·唐格拉尔银行", "七月王朝巴黎的银行大厅：镀金栏杆、柜窗、成排的账簿，墙上挂着一张西班牙公债的行情表。下午。", ["c_danglars"]),
    bg("palais_justice_assize", "司法宫·重罪法庭", "巴黎司法宫的重罪法庭：橡木法官席、被告席的栏杆、旁听席挤满的长椅（空着），高窗外是西岱岛的夜色。", ["c_trial"]),
    bg("telegraph_tower", "蒙莫朗西的电报站", "巴黎北郊山坡上的沙普电报塔：木制的信号臂，塔下一块种满草莓的小菜园。夏日午后。", ["ev_telegraph"], "P1"),
    bg("noirtier_room", "维尔福府·努瓦蒂埃的房间", "一间老式卧室：一张轮椅、一个装着药水的柜子、一本字母表和一本词典放在膝毯上；窗帘半拉。", ["ev_noirtier_eyes"], "P1"),
    bg("constantinople_market", "君士坦丁堡的奴隶市场", "君士坦丁堡一座内院：拱廊、地毯、铜盘，院子中央空着一块垫子。阳光从格子窗里漏下来。", ["ev_haydee_constantinople"], "P2"),
    # ---------------------------------------------------------------- maps
    {"kind": "bg", "id": "map_marseille_1815", "name": "地图·马赛 1815", "priority": "P0", "used_in": ["sheet:marseille"],
     "desc": "1815 年马赛城的俯视地图（羊皮纸风格，画面 1920×1080）：正中是东西向的旧港，港口西口北边是圣让堡、南边是圣尼古拉堡；北岸是勒潘尼耶的山坡和圣洛朗教堂，东边是卡讷比耶尔大街、大库尔街和梅朗林荫道；南边是守护圣母山；西南海边是加泰罗尼亚人村和一处小海湾；左边海上画出伊夫堡和弗里乌尔群岛的轮廓。只画地形、街区色块和海岸线，" + NO},
    {"kind": "bg", "id": "map_if_fortress", "name": "地图·伊夫堡与海岸", "priority": "P0", "used_in": ["sheet:if_years"], "arch_listed": True,
     "desc": "左半边是伊夫堡岛的剖面式俯视图（要塞的三座圆塔、院子、地牢的两层走廊、27 号和 34 号牢房之间的一条虚线地道、海门石阶），旁边是波梅格岛和拉托诺岛；右半边是马赛到卡西斯的海岸（面包码头、老城、索尔米乌和莫尔吉乌的峡湾、卡西斯港、拉西奥塔）。右上角留一块“远方”的小卷轴，画约阿尼纳湖。" + NO},
    {"kind": "bg", "id": "map_paris", "name": "地图·巴黎 1838", "priority": "P0", "used_in": ["sheet:paris_1838"], "arch_listed": True,
     "desc": "七月王朝巴黎的俯视地图：塞纳河从右向左穿过画面，正中是西岱岛（圣母院、司法宫）和圣路易岛；左上是香榭丽舍大街，最左边是布洛涅树林和奥特伊；右岸有杜伊勒里宫、王宫、昂坦街、蒙马特；左岸有卢森堡宫、拉丁区、圣日耳曼区；右边是马莱区、巴士底广场和拉雪兹神父公墓；右上角画远处蒙莫朗西山坡上的电报塔。" + NO},
    # ---------------------------------------------------------------- endings
    {"kind": "cg", "id": "ending_m_wait_hope", "name": "结局·等待与希望", "priority": "P0", "used_in": ["ending:m_wait_hope"],
     "desc": "基督山岛的海湾，黄昏：一条帆船正在出海，船尾站着一男一女的剪影；岸上一对年轻人在读一封信。不要有文字。"},
    {"kind": "cg", "id": "ending_m_full_ledger", "name": "结局·伯爵的清单", "priority": "P0", "used_in": ["ending:m_full_ledger"],
     "desc": "一张书桌上摊着一份名单，三个名字被划掉（名字本身不画清楚）；桌边的窗外是巴黎的雨夜，一个穿黑大衣的人背对画面。不要有文字。"},
    {"kind": "cg", "id": "ending_m_name", "name": "结局·维尔福这个姓", "priority": "P0", "used_in": ["ending:m_name"],
     "desc": "伊夫堡对岸的礁石，冬天的早晨：一个中年人独自站着，手里攥着一块金怀表；远处海上是伊夫堡。不要有文字。"},
    {"kind": "cg", "id": "ending_m_count", "name": "结局·基督山伯爵", "priority": "P1", "used_in": ["ending:m_count"],
     "desc": "马赛旧港边一家新开的船具补给栈的门面：招牌上只画着一只鹰和一座城堡；门口堆着缆绳和木桶。不要有文字。"},
]

CHARA = [  # id, name, priority, desc
    ("gerard", "杰拉尔·德·维尔福", "P0", "1815 年 27 岁、1838 年 50 岁的王家检察官：瘦高，苍白，嘴唇很薄，黑礼服、白领巾，眼睛冷静得过分。两套服装（1815 / 1838），同一张脸。和主角维尔福有家族相似（眉形、鼻梁），但更冷。"),
    ("noirtier", "努瓦蒂埃", "P1", "1815 年 60 岁的老吉伦特派、波拿巴党人：花白头发，蓝色旧外套，荣誉军团勋章；1838 年坐轮椅，全身瘫痪，只有眼睛有神。"),
    ("mercedes", "梅尔塞苔丝", "P0", "1815 年 17 岁的加泰罗尼亚渔家姑娘：黑发编成辫子，黑眼睛，红色头巾、白衬衫、深色裙子；1838 年是莫尔塞夫伯爵夫人，黑丝绒长裙，鬓角有白发。"),
    ("fernand", "费尔南·蒙台哥／莫尔塞夫伯爵", "P1", "1815 年 21 岁的加泰罗尼亚渔夫，黑而瘦，眼神阴沉；1838 年是将军、贵族院议员，军装上挂满勋章。"),
    ("danglars", "唐格拉尔", "P1", "1815 年 25 岁的商船押运员，圆脸，假笑，衣着整洁；1838 年是银行家男爵，发福，金表链。"),
    ("caderousse", "卡德鲁斯", "P0", "1815 年 30 多岁的马赛裁缝：红脸，粗壮，围着皮围裙，手里总有酒杯；1829 年起是潦倒的客栈老板。"),
    ("louis_dantes", "老唐泰斯", "P2", "60 多岁的退休水手：瘦，白发，旧毛线帽，很干净但很旧的衣服。"),
    ("governor", "伊夫堡典狱长", "P2", "50 岁的老军官：灰胡子，旧军装，腰上挂着一大串钥匙。"),
    ("commissaire", "警长", "P2", "40 岁的警察局警长：三角帽、白色绶带、手里拿着一纸逮捕令。"),
    ("renee", "勒内·德·圣梅朗", "P2", "1815 年 18 岁的保王党侯爵小姐：金发，白纱裙，神情温和。"),
    ("jacopo", "雅科波", "P0", "30 岁的走私船水手：瘦高，黝黑，红色水手帽，条纹衬衫，腰间别着刀；1838 年是伯爵游艇的船长，穿深蓝船长服。"),
    ("bertuccio", "贝尔图乔", "P0", "40 多岁的科西嘉人：黑发，浓眉，深色外套，刀柄缠黑布；1838 年是伯爵府的管家，衣着讲究，神情阴郁。"),
    ("ali_pasha", "阿里·特佩莱纳总督", "P2", "80 岁的约阿尼纳总督：长白胡子，红色土耳其帽，镶金的长袍，腰上插着手枪。"),
    ("haydee", "海黛", "P0", "1838 年 20 岁的希腊女子：黑发、大眼睛，希腊式绣花短上衣、丝绸长裤、头上戴着小金币串成的头饰；神情忧伤又骄傲。"),
    ("ali", "阿里（努比亚仆人）", "P1", "30 岁的努比亚人：高大，沉默，白色长袍和红腰带，肩上挂着一卷马索。"),
    ("vampa", "路易吉·万帕", "P0", "20 多岁的罗马强盗头子：英俊，黑发，牧羊人的羊皮背心、天鹅绒短裤、绑腿，帽子上插着花，肩上一支长枪。"),
    ("albert", "阿尔贝·德·莫尔塞夫", "P1", "20 出头的巴黎贵族青年：浅色头发，花花公子的燕尾服、手套和手杖；被绑以后衬衫凌乱。"),
    ("maximilien", "马克西米利安·莫雷尔", "P0", "1838 年 27 岁的北非骑兵上尉：黑发、胡子，深蓝骑兵上衣、红裤子、马刀。眉眼像他父亲莫雷尔。"),
    ("valentine", "瓦朗蒂娜·德·维尔福", "P0", "1838 年 19 岁：金栗色头发，白裙，脸色苍白，眼神温柔而坚定。脸上要有维尔福家的相似（眉形）。"),
    ("heloise", "埃洛伊丝·德·维尔福", "P2", "30 多岁的贵妇：精致，美丽，手里总拿着一只小药瓶或扇子。"),
    ("benedetto", "贝内代托／安德烈亚·卡瓦尔康蒂", "P0", "21 岁的年轻人：漂亮而轻浮，两套服装：意大利子爵的华服 / 土伦苦役犯的红衣绿帽和脚镣。"),
]
VARIANTS = [
    {"kind": "chara", "variant_of": "dantes", "variant": "1815", "priority": "P0", "desc": "19 岁的法老号大副：黑发、晒黑的脸，蓝色水手外套、红领巾，笑得很亮。和现有的 dantes（伯爵）是同一人年轻时。"},
    {"kind": "chara", "variant_of": "dantes", "variant": "prisoner", "priority": "P0", "desc": "伊夫堡 34 号的囚徒：长发、长胡子、破衬衫，眼神发狠。"},
    {"kind": "chara", "variant_of": "faria", "variant": "prisoner", "priority": "P1", "desc": "27 号的神甫：极瘦，破旧的黑袍，手里一支鱼骨做的笔。"},
    {"kind": "chara", "variant_of": "morel", "variant": "1815", "priority": "P1", "desc": "1815 年 50 岁左右的船东：灰发，深色呢外套，表链，和蔼而焦虑。"},
    {"kind": "chara", "variant_of": "villefort", "variant": "1815", "priority": "P0", "desc": "1815 年的主角：帝国军需官的蓝色旧外套（去掉了肩章），风尘仆仆，胸前的口袋里鼓着一封信；1838 年变体为黑色礼服和鹰徽怀表。"},
]
UNIT_COMP = ["caderousse", "jacopo", "bertuccio", "haydee", "ali", "maximilien", "vampa", "albert"]
UNIT_ENEMY = {
    "gendarme": "王家宪兵：深蓝制服、黄色皮带、高筒帽、带刺刀的火枪", "mounted_gendarme": "骑宪兵：同上，骑马，马刀",
    "prison_guard": "狱卒：灰色旧外套、钥匙串、短棍", "turnkey_chief": "典狱长：灰胡子老军官、腰上一大串钥匙、手枪",
    "customs": "海关缉私兵：绿色制服、圆帽、短火枪", "customs_officer": "海关稽查官：绿色制服带金边、手持望远镜",
    "smuggler": "走私贩：红帽、条纹衫、腰刀（隐身时只显示轮廓）", "rival_smuggler_boss": "热那亚帮船老大：黑胡子、宽腰带、两把手枪",
    "revenue_cutter": "缉私快艇：单桅小艇、船头一门回旋炮（船体网格）", "verdet": "绿衫志愿兵：绿色上衣、白帽徽、猎枪",
    "ng_grenadier": "倒向国王的国民自卫军掷弹兵：熊皮帽、白帽徽、刺刀", "national_guard": "国民自卫军：蓝制服、高筒帽、火枪",
    "if_soldier": "伊夫堡守军：旧式白色步兵制服、上了年纪", "if_veteran": "守军老军士：胡子花白、肩章、长刺刀",
    "wall_sentry": "墙头哨兵：斗篷、长枪，站姿", "fort_gun": "伊夫堡炮台：老式铸铁要塞炮（炮架网格）",
    "thug": "码头打手：短外套、木棍或刀", "thug_marksman": "黑枪手：帽檐压低、手枪或短火枪", "thug_boss": "打手头子：大块头、皮背心、铁棍",
    "bandit": "罗马强盗：羊皮背心、尖顶帽、短枪", "bandit_marksman": "强盗枪手：长枪、伏在地上", "vampa": "路易吉·万帕（敌方）：同伙伴立绘服装",
    "assassin": "刺客：黑斗篷、匕首", "benedetto": "贝内代托（敌方）：苦役犯红衣、匕首",
    "papal_carabinier": "教皇宪兵：深蓝制服、两角帽", "papal_dragoon": "教皇龙骑兵：骑马、头盔", "sbirro": "教廷密探：便衣、短刀",
    "arnaut": "阿尔瑙特枪手：白色百褶裙（fustanella）、长枪", "municipal_guard": "巴黎市政卫队：高筒帽、蓝制服、刺刀",
    "convict": "土伦苦役犯：红衣、绿帽、断掉的脚镣", "police_agent": "治安密探：灰大衣、圆帽、短棍",
}


def build_art():
    out = list(ART)
    for id, name, pr, desc in CHARA:
        out.append({"kind": "chara", "id": id, "name": name, "priority": pr, "desc": desc})
        out.append({"kind": "face", "id": id, "name": name, "priority": pr, "desc": "同一人物的头像，和立绘用同一个模型。"})
    out += VARIANTS
    for c in UNIT_COMP:
        out.append({"kind": "unit", "id": c, "name": c, "priority": "P1", "desc": "战场小人：服装同立绘，五个状态（idle/attack/hit/down/dying）。"})
    for e, d in UNIT_ENEMY.items():
        out.append({"kind": "unit", "id": "enemy_" + e, "name": e, "priority": "P1" if e not in ("papal_carabinier", "papal_dragoon", "sbirro", "arnaut", "municipal_guard", "convict", "police_agent") else "P2",
                    "desc": "战场小人：" + d + "。五个状态。"})
    return out


VN_CHARS = {
    "villefort": {"aliases": ["埃德蒙·德·维尔福", "维尔福"], "art": "villefort"},
    "gerard": {"aliases": ["杰拉尔·德·维尔福", "杰拉尔"], "art": "gerard"},
    "noirtier": {"aliases": ["努瓦蒂埃"], "art": "noirtier"},
    "dantes": {"aliases": ["埃德蒙·唐泰斯", "唐泰斯", "伯爵", "基督山伯爵"], "art": "dantes"},
    "mercedes": {"aliases": ["梅尔塞苔丝"], "art": "mercedes"},
    "fernand": {"aliases": ["费尔南", "莫尔塞夫伯爵"], "art": "fernand"},
    "danglars": {"aliases": ["唐格拉尔"], "art": "danglars"},
    "caderousse": {"aliases": ["卡德鲁斯"], "art": "caderousse"},
    "louis_dantes": {"aliases": ["老唐泰斯"], "art": "louis_dantes"},
    "morrel": {"aliases": ["莫雷尔先生", "莫雷尔"], "art": "morel"},
    "faria": {"aliases": ["法利亚神甫", "法利亚"], "art": "faria"},
    "governor": {"aliases": ["典狱长"], "art": "governor"},
    "commissaire": {"aliases": ["警长"], "art": "commissaire"},
    "renee": {"aliases": ["勒内"], "art": "renee"},
    "jacopo": {"aliases": ["雅科波"], "art": "jacopo"},
    "bertuccio": {"aliases": ["贝尔图乔"], "art": "bertuccio"},
    "ali_pasha": {"aliases": ["阿里总督", "阿里·特佩莱纳"], "art": "ali_pasha"},
    "haydee": {"aliases": ["海黛"], "art": "haydee"},
    "ali": {"aliases": ["阿里"], "art": "ali"},
    "vampa": {"aliases": ["万帕", "路易吉·万帕"], "art": "vampa"},
    "albert": {"aliases": ["阿尔贝"], "art": "albert"},
    "maximilien": {"aliases": ["马克西米利安"], "art": "maximilien"},
    "valentine": {"aliases": ["瓦朗蒂娜"], "art": "valentine"},
    "heloise": {"aliases": ["埃洛伊丝"], "art": "heloise"},
    "benedetto": {"aliases": ["贝内代托", "安德烈亚"], "art": "benedetto"},
    "peppino": {"aliases": ["佩皮诺"], "art": "placeholder_only"},
    "renaud": {"aliases": ["庭长"], "art": "placeholder_only"},
}
VARIANT_BY_SCENE = {  # scene -> {char: variant}
    "c_landfall": {"dantes": "1815", "morrel": "1815", "villefort": "1815"}, "c_reserve": {"dantes": "1815", "villefort": "1815"},
    "c_gerard": {"villefort": "1815"}, "c_petition": {"morrel": "1815", "villefort": "1815"}, "c_white_june": {"morrel": "1815", "villefort": "1815"},
    "c_bread_34": {"dantes": "prisoner"}, "c_faria_27": {"faria": "prisoner"}, "c_faria_dies": {"dantes": "prisoner", "faria": "prisoner"},
    "c_if_night": {"dantes": "prisoner"}, "c_tiboulen": {"dantes": "prisoner"},
}
