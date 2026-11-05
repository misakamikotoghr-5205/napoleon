#!/usr/bin/env python3
"""Writes data/campaigns/napoleon/conquest.json — the 鹰飞 (continue-conquest) segment.
Shape: ocean_pawn.json superset + ARCH §1.5 v2 keys (same as trunk.json).
Chapter 1 (百日) is written in full (VN 7–9 lines a scene); chapters 2–6 are condensed (4–6 lines, `condensed: true`).
Run:  python3 -I tools/build_conquest.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trunk_additions import council, event, ch, ap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "campaigns", "napoleon", "conquest.json")

def scene(sid, chapter, date, title, location, speaker, body, choices, appraisals=(), items=(), condensed=False, when=None):
    s = {"id": sid, "chapter": chapter, "date": date, "title": title, "location": location, "speaker": speaker, "body": body,
         "item_ids": list(items), "appraisals": list(appraisals), "choices": choices}
    if condensed: s["condensed"] = True
    if when: s["when"] = when
    return s

def adv(c):
    c["advance"] = True
    return c

CHAPTERS = [
    {"id": "hundred_days", "title": "第一章 · 百日 1815", "currency": "franc", "currency_name": "法郎（厄尔巴金库）", "treasury_start": 3000,
     "scene_ids": ["k_golfe_juan", "k_laffrey", "k_tuileries", "k_charleroi", "k_waterloo", "k_waterloo_night"]},
    {"id": "rhine", "title": "第二章 · 莱茵之秋 1815", "currency": "franc", "currency_name": "法郎（帝国国库）", "treasury_start": 4000,
     "scene_ids": ["k_brussels", "k_ultimatum", "k_rhine"]},
    {"id": "vienna", "title": "第三章 · 第三次维也纳 1816", "currency": "franc", "currency_name": "法郎（帝国国库）", "treasury_start": 4500,
     "scene_ids": ["k_bavaria", "k_vienna", "k_schoenbrunn"]},
    {"id": "iberia_channel", "title": "第四章 · 伊比利亚或海峡 1817", "currency": "franc", "currency_name": "法郎（帝国国库）", "treasury_start": 5000,
     "scene_ids": ["k_choice_1817", "k_torres_vedras", "k_dover"]},
    {"id": "niemen", "title": "第五章 · 第二次涅曼河 1818", "currency": "franc", "currency_name": "法郎（帝国国库）", "treasury_start": 5500,
     "scene_ids": ["k_warsaw", "k_niemen"]},
    {"id": "last_coalition", "title": "终章 · 最后的同盟 1819", "currency": "franc", "currency_name": "法郎（帝国国库）", "treasury_start": 6000,
     "scene_ids": ["k_paris_1819", "k_leipzig_1819", "k_final"]},
]

CHARACTERS = [
    {"id": "villefort", "name": "埃德蒙·德·维尔福", "role": "主角；近卫军军需司库，1815 年起兼管北方军团的钱袋"},
    {"id": "napoleon", "name": "拿破仑", "role": "法兰西皇帝；本分支里打赢了滑铁卢。不上阵，以命令、召见和会战限定的军令牌出现"},
    {"id": "drouot", "name": "德鲁奥将军", "role": "伙伴；近卫炮兵，“大军团的贤者”；厄尔巴起随驾"},
    {"id": "cambronne", "name": "康布罗纳将军", "role": "伙伴；老近卫军，宿命之地滑铁卢"},
    {"id": "ney", "name": "内伊元帅", "role": "伙伴；“勇士中的勇士”，答应过路易十八把皇帝关进铁笼带回来"},
    {"id": "davout", "name": "达武元帅", "role": "1815 年的战争部长"},
    {"id": "fouche", "name": "富歇", "role": "警务部长；跟每个人握手，替每个人记名字"},
    {"id": "grouchy", "name": "格鲁希元帅", "role": "右翼指挥官；滑铁卢那天他在哪里，决定了一切"},
    {"id": "gourgaud", "name": "古尔戈将军", "role": "伙伴；皇帝的传令官（远洋段同一人）"},
    {"id": "baptiste", "name": "巴蒂斯特中士", "role": "伙伴；工兵，土伦起跟着主角"},
    {"id": "corso", "name": "科尔索", "role": "伙伴；科西嘉猎兵"},
    {"id": "marie", "name": "玛丽·朗热", "role": "伙伴；随军女商贩兼军医"},
    {"id": "pierre", "name": "小皮埃尔", "role": "伙伴；别列津纳捡回来的鼓手，1819 年满十八岁"},
    {"id": "larrey", "name": "拉雷", "role": "伙伴；军医总监"},
    {"id": "talleyrand", "name": "塔列朗亲王", "role": "维也纳会议派来的特使；谁赢了他就替谁说话"},
    {"id": "max_joseph", "name": "马克西米利安国王", "role": "巴伐利亚国王"},
    {"id": "king_of_rome", "name": "罗马王", "role": "皇帝的儿子，五岁，住在美泉宫"},
    {"id": "morrel", "name": "莫雷尔先生", "role": "马赛莫雷尔父子商行的主人，法老号的船东（远洋、伊夫堡段同一人）"},
    {"id": "dantes", "name": "埃德蒙·唐泰斯", "role": "法老号大副；1815 年 2 月 28 日被捕，关在伊夫堡 34 号（远洋、伊夫堡段同一人）"},
    {"id": "faria", "name": "法利亚神甫", "role": "伊夫堡 27 号；1796 年在博洛尼亚给过主角半封信（全书同一人）"},
    {"id": "gerard_villefort", "name": "杰拉尔·德·维尔福", "role": "马赛王家检察官，主角的远房族人；他亲手埋掉了唐泰斯"},
    {"id": "goethe", "name": "歌德", "role": "魏玛的老诗人，1808 年在爱尔福特见过皇帝"},
]

ITEMS = [
    {"id": "elba_watch", "name": "厄尔巴双面金怀表", "chapter": "hundred_days", "description": "皇帝在厄尔巴用过的旧怀表，表盘后面有个夹层。（主干与远洋段同一件物品，id 冻结）"},
    {"id": "faria_half", "name": "法利亚的半封信", "chapter": "hundred_days", "description": "1796 年博洛尼亚，有斯帕达纹章的那一半。另一半在伊夫堡 27 号的神甫手里。"},
    {"id": "k_grouchy_order", "name": "给格鲁希的命令（副本）", "chapter": "hundred_days", "description": "弗勒吕斯军议之后抄下的命令副本，写明了时辰和路线。"},
    {"id": "k_petition", "name": "莫雷尔的请愿书", "chapter": "hundred_days", "description": "替伊夫堡 34 号写的请愿书，附议栏里签着杰拉尔·德·维尔福的名字。"},
    {"id": "k_tin_soldier", "name": "罗马王的锡兵", "chapter": "vienna", "description": "美泉宫里，皇帝放在儿子手里的那只锡兵。孩子又把它还给了你。"},
    {"id": "k_ledger_xi", "name": "第十一本账簿", "chapter": "last_coalition", "description": "从土伦算起的第十一本。最后一页还空着。"},
]

C = "hundred_days"
SCENES = [
    scene("k_golfe_juan", C, "1815-03-01", "第一章·第一场：十二只箱子", "儒安湾·海滩", "napoleon", [
        "1815 年 3 月 1 日下午，儒安湾。不屈号和六条小船靠了岸：一千一百个人，四门炮，厄尔巴金库的十二只箱子。",
        "海滩上的海关哨所里只有两个税务员。他们看着皇帝，不知道帽子该不该摘。",
        "康布罗纳：“去戛纳买马的人回来了，只买到十几匹，价钱翻了三倍。”",
        "拿破仑：“走山路。普罗旺斯的大路上全是保王党，阿尔卑斯山里只有农民。”",
        "德鲁奥：“山路走不了炮车。四门炮，只能带两门。”",
        "维尔福：“金库也一样。十二只箱子，骡子只够驮八只。”",
        "拿破仑：“维尔福，到巴黎以前，你就是整个帝国的财政部。”",
        "海风很冷。远处，昂蒂布炮台上升着百合花旗。"],
        [adv(ch("only_gold", "只驮八只装金币的箱子，银币就地发饷", {"morale": 6}, ["k_light_chests"],
                {"coins": {"gold": 2}, "recruit": ["drouot", "cambronne"]}, requires_clues=["chest_count"])),
         adv(ch("buy_mules", "多花钱买骡子，十二只全带走", {"treasury": -400}, ["k_all_chests"],
                {"coins": {"gold": 3}, "recruit": ["drouot", "cambronne"]})),
         adv(ch("pay_cannes", "先在戛纳付清马钱和面包钱，一个苏也不欠", {"treasury": -200, "heat": -8}, ["k_paid_cannes"],
                {"recruit": ["drouot", "cambronne"]}))],
        [ap("chest_count", "weigh", "逐只过秤十二只箱子", "八只装的是金币，四只装的是银币和厄尔巴铁矿的票据。银币重，值钱的那八只反而轻。"),
         ap("antibes_flag", "spot", "看昂蒂布炮台", "炮台的门开着，有人在往外看。不是要开炮，是在等消息。")],
        items=["elba_watch"]),
    scene("k_laffrey", C, "1815-03-07", "第一章·第二场：相遇的草地", "拉弗雷·湖和山之间", "napoleon", [
        "1815 年 3 月 7 日，格勒诺布尔南边的拉弗雷。湖和山之间有一片草地。",
        "第五战列步兵团挡在路上，七百条枪。他们的军官喊：“开火！”没有一个人开火。",
        "皇帝一个人往前走，解开了大衣。",
        "拿破仑：“第五团的兵们，你们认得我吗？你们当中谁要杀他的皇帝，就开枪吧。”",
        "队伍里有人喊了一声“皇帝万岁”，接着是七百个人。",
        "当天晚上，格勒诺布尔的城门打不开，市民干脆把城门拆了，抬到皇帝面前。",
        "维尔福：“陛下，这七百个兵，三个月没发饷了。”",
        "拿破仑：“那就今晚发。在格勒诺布尔，他们要看见的不是我，是钱。”"],
        [adv(ch("pay_all_ranks", "当晚按名册先发士兵，再发军官", {"treasury": -500, "morale": 10}, ["k_fifth_paid"],
                {"troops": ["line", "line", "grenadier"]}, requires_clues=["fifth_pay"])),
         adv(ch("pay_officers", "先发军官，稳住队伍", {"treasury": -300, "morale": 2}, ["k_officers_paid"], {"troops": ["line", "line"]})),
         adv(ch("promise_paris", "许诺到巴黎发双饷", {"morale": 4, "heat": 4}, ["k_paris_promise"], {"troops": ["line", "line"]}))],
        [ap("fifth_pay", "decode", "核对第五团的饷册", "士兵那一栏欠了三个月，军官那一栏是满的：王室只给军官发了钱。")]),
    scene("k_tuileries", C, "1815-03-20", "第一章·第三场：挂毯底下的蜜蜂", "巴黎·杜伊勒里宫", "napoleon", [
        "1815 年 3 月 20 日夜，巴黎，杜伊勒里宫。路易十八头一天晚上走的，走得很急。",
        "宫里的人把挂毯上的百合花撕下来，底下露出原来绣的蜜蜂。",
        "达武元帅当了战争部长。财政大臣莫利安带来一本账，翻开的那一页写着两个数：国库里还有多少，欠出去多少。",
        "富歇又当了警务部长。他笑着跟每个人握手，包括你。",
        "富歇：“维尔福？马赛有一位王家检察官也姓维尔福。是您家什么人？”",
        "拿破仑：“六月以前，我要三十万人。枪、鞋、面包、马，你要多少钱？”",
        "维尔福：“陛下，钱只有三个地方来：银行家，征发，还有王室来不及带走的东西。”",
        "窗外，杜伊勒里花园里的人越聚越多。有人在唱《马赛曲》。"],
        [adv(ch("bankers", "去找银行家借钱，用国有林地作担保", {"treasury": 1500, "heat": 5}, ["k_bankers"], {"coins": {"gold": 2}})),
         adv(ch("requisition_1815", "照 1793 年的办法征发：马、鞋、粮", {"treasury": 800, "heat": 18}, ["k_requisition_1815"], {"coins": {"supply": 5}})),
         adv(ch("royal_silver", "把王室留下的银器熔了发饷", {"treasury": 1000, "morale": 4}, ["k_royal_silver"], {"coins": {"gold": 1, "supply": 2}},
                requires_clues=["mollien_book"]))],
        [ap("mollien_book", "decode", "核对莫利安的账", "账上的钱有一半是还没收上来的税。真正能动的，只够三个月；可地窖的清单上还有一整页王室的银器。"),
         ap("fouche_smile", "spot", "留意富歇跟谁说话", "他跟每个人握手，可他的秘书一直在往本子上记名字，你的名字也在上面。")]),
    scene("k_charleroi", C, "1815-06-15", "第一章·第四场：桑布尔河上的桥", "沙勒罗瓦·桑布尔河桥", "napoleon", [
        "1815 年 6 月 15 日凌晨，北方军团越过边境。十二万人，分三路走进比利时。",
        "沙勒罗瓦的桑布尔河桥上堆着普军的路障。齐滕的后卫守在对岸的房子里。",
        "近卫工兵抡着斧头往前冲。巴蒂斯特：“路障我来拆。拆完以后，桥上得有人守着。”",
        "拿破仑：“今天是十五号。我要在十六号打普鲁士人，十七号打英国人，十八号进布鲁塞尔。”",
        "古尔戈从河边跑回来：“旺达姆的军迷了路，要晚到六个钟头。”",
        "维尔福：“也就是说，这六个钟头里，桥头只有我们。”",
        "河对岸，普军的号手吹起了反冲的号。"],
        [adv(ch("double_couriers", "从今天起，每道命令都派两个传令兵，走两条路", {}, ["k_double_couriers"], {"coins": {"intel": 2}},
                requires_clues=["vandamme_order"])),
         adv(ch("hold_and_wait", "守住桥，等旺达姆", {"morale": 4}, ["k_charleroi_held"], {"coins": {"medal": 1}})),
         adv(ch("push_on", "不等了，先过河", {"vitality": -4, "morale": 2}, ["k_charleroi_pushed"], {"coins": {"supply": 2}}))],
        [ap("vandamme_order", "decode", "核对旺达姆收到的命令", "命令是半夜发出的。送信的骑兵坠马摔断了腿，命令根本没有送到。")]),
    scene("k_waterloo", C, "1815-06-18", "第一章·决战：普朗斯努瓦", "滑铁卢·普朗斯努瓦教堂墓园", "napoleon", [
        "1815 年 6 月 18 日，滑铁卢。雨下了一夜，地里的泥没过脚踝。皇帝等地干，一直等到中午才开炮。",
        "下午一点，东边圣朗贝尔的树林里出现了蓝色军服。不是格鲁希，是比洛的普鲁士人。",
        "拿破仑：“维尔福，你去普朗斯努瓦。青年近卫军在那里，弹药车也得在那里。”",
        "普朗斯努瓦的教堂墓园围着一圈矮墙。洛鲍将军的兵在墙后面装子弹。",
        "康布罗纳：“近卫军不投降。要么守住，要么死在这里。”",
        "鼓手们在墓园里把鼓摆成一排。",
        "西边蒙圣让的山坡上，威灵顿的方阵还在。皇帝要在天黑以前击穿中央，前提是右翼不垮。",
        "维尔福：“撑到老近卫军冲上山坡。撑到天黑。”"],
        [adv(ch("guard_charge", "把预备弹药全调去中央，跟着近卫军冲", {"morale": 6}, ["k_guard_charged"], {"coins": {"medal": 2}})),
         adv(ch("hold_plancenoit", "守住普朗斯努瓦，把伤员抬进教堂", {"vitality": 6, "morale": 3}, ["k_plancenoit_held"], {"heal": 20},
                requires_clues=["church_wall"])),
         adv(ch("chase_bulow", "追比洛到拉斯讷河谷", {"vitality": -6}, ["k_bulow_chased"], {"coins": {"supply": 3}}))],
        [ap("church_wall", "spot", "看清墓园的矮墙", "墙只有齐胸高，可墙角的教堂是石头砌的，炮打不穿。"),
         ap("bulow_columns", "decode", "数林边的普军纵队", "两个军，后面还有一个。布吕歇尔把能带的人都带来了。")]),
    scene("k_waterloo_night", C, "1815-06-18", "第一章·终场：客栈里的账", "滑铁卢村·客栈", "napoleon", [
        "夜里十点，滑铁卢村。威灵顿昨夜睡过的那家客栈，今晚是皇帝的司令部。",
        "英国人往布鲁塞尔退了，普鲁士人往列日退了。蒙圣让的山坡上到处是没人收的伤兵，两边的都有。",
        "拉雷：“一万多个伤员。我只有六十把锯子。”",
        "拿破仑：“布鲁塞尔明天就是我们的。维也纳那些人，会坐下来谈的。”",
        "古尔戈把缴获的英军军旗堆在门口，有两面上还有血。",
        "你在账簿上写下今天的数字。写到伤亡那一栏，停了很久。",
        "这一仗赢了。历史书上从此多出一页，没有人读过的一页。"],
        [adv(ch("exchange_wounded", "打着白旗派人去英军那边：交换伤员，不论国籍", {"morale": 2, "heat": -8}, ["k_wounded_exchanged"], {"heal": 20})),
         adv(ch("pursue_tonight", "连夜追去布鲁塞尔", {"vitality": -8, "morale": 4}, ["k_pursuit"], {"coins": {"medal": 1, "supply": 2}})),
         adv(ch("parade_eagles", "把缴获的军旗送去巴黎游行", {"morale": 6, "heat": 4}, ["k_trophies"], {"coins": {"medal": 2}}))]),
    # ---------------- chapter 2 (condensed)
    scene("k_brussels", "rhine", "1815-06-20", "第二章·第一场：威灵顿的仓库", "布鲁塞尔·城门", "napoleon", [
        "1815 年 6 月 20 日，布鲁塞尔。城门外还有英军的后卫，在索瓦涅森林边上挖了壕沟。",
        "城里的人一半挂出三色旗，一半关着窗。",
        "拿破仑：“我今晚要在拉肯宫睡觉。维尔福，城里的仓库归你。”",
        "仓库里是威灵顿留下的东西：一万双靴子，两千桶饼干，还有一箱英国金币。"],
        [adv(ch("boots_to_guard", "靴子先发给近卫军", {"morale": 4}, ["k_boots_shared"], {"coins": {"supply": 2}})),
         adv(ch("gold_to_treasury", "金币充公", {"treasury": 800}, [], {"coins": {"gold": 2}})),
         adv(ch("biscuits_to_bakers", "把饼干平价卖回给布鲁塞尔的面包商", {"treasury": 300, "heat": -6}, ["k_brussels_fair"], {}))],
        condensed=True),
    scene("k_ultimatum", "rhine", "1815-07-20", "第二章·第二场：塔列朗", "梅斯·会议厅", "talleyrand", [
        "1815 年 7 月，梅斯。维也纳会议派来了特使：塔列朗亲王。一年前，他还在替路易十八说话。",
        "塔列朗：“奥地利和俄国的军队已经到了莱茵河。可两位皇帝都累了。陛下要什么？”",
        "拿破仑：“比利时，还有莱茵河左岸。”",
        "塔列朗看了你一眼：“军需官先生，法国的钱袋，还撑得起再打一年吗？”"],
        [adv(ch("offer_1814_borders", "劝皇帝接受 1814 年的边界，换一个和平", {"morale": -2, "heat": -10}, ["k_peace_offered"], {})),
         adv(ch("demand_rhine", "站在皇帝一边：要莱茵河", {"morale": 4}, ["k_rhine_demanded"], {"coins": {"medal": 1}})),
         adv(ch("show_the_ledger", "什么也不说，把账簿递给塔列朗看", {}, ["k_ledger_shown"], {"coins": {"intel": 2}}))],
        condensed=True),
    scene("k_rhine", "rhine", "1815-09-02", "第二章·决战：劳特河", "维桑堡防线", "napoleon", [
        "1815 年 9 月，阿尔萨斯。施瓦岑贝格的奥军和巴克莱的俄军在劳特河对岸，二十万人。会议没谈成。",
        "维桑堡防线是一百年前修的土墙，今年夏天巴蒂斯特带人重新挖了一遍。",
        "巴蒂斯特：“河上有三个渡口。渡口守住了，墙后面的人才能睡觉。”",
        "拿破仑：“这一仗打赢了，维也纳就没人再提什么会议了。”",
        "雨下了三天，劳特河涨水了。"],
        [adv(ch("burn_ferries", "烧掉对岸的渡船", {"construction": 10}, [], {"coins": {"supply": 2}})),
         adv(ch("pursue_across", "追过河去", {"vitality": -6}, ["k_rhine_pursuit"], {"coins": {"medal": 2}})),
         adv(ch("bury_both", "两边的阵亡者一起埋", {"heat": -6, "morale": 2}, ["k_rhine_graves"], {}))],
        condensed=True),
    # ---------------- chapter 3
    scene("k_bavaria", "vienna", "1816-04-10", "第三章·第一场：小国的算术", "慕尼黑·宁芬堡宫", "max_joseph", [
        "1816 年 4 月，慕尼黑。巴伐利亚国王三年前背弃了皇帝，现在又派人来问：大军过境，面包谁出。",
        "马克西米利安国王：“巴伐利亚是小国，陛下。小国只能站在赢的那一边。”",
        "拿破仑：“那就站过来。维尔福，你算一算。”",
        "多瑙河上游的冰化了。顺流往下三百公里，就是维也纳。"],
        [adv(ch("bavaria_shares", "巴伐利亚出粮，大军付一半的钱", {"treasury": -300, "heat": -6}, ["k_bavaria_ally"], {})),
         adv(ch("requisition_bavaria", "全部征发", {"heat": 12}, ["k_requisition_1816"], {"coins": {"supply": 5}})),
         adv(ch("bavarian_division", "请国王出一个师，抵过境的钱", {}, ["k_bavarian_division"], {"troops": ["line", "hussar"]}))],
        condensed=True),
    scene("k_vienna", "vienna", "1816-06-12", "第三章·决战：第三次", "维也纳·城墙缺口", "napoleon", [
        "1816 年 6 月，维也纳。这是第三次了：1805 年，1809 年，现在。",
        "城墙比上一次高，城里的人比上一次恨我们。卡尔大公在城墙后面，梅特涅在霍夫堡宫里烧文件。",
        "拿破仑：“城里有一个人，我必须见到。”",
        "你知道他说的是谁。美泉宫里，有一个五岁的男孩。",
        "屋顶上全是蒂罗尔的猎手。"],
        [adv(ch("spare_vienna", "下令不许抢城，违者枪决", {"heat": -10, "morale": -2}, ["k_vienna_spared"], {})),
         adv(ch("arsenal_only", "只拿军械库", {}, ["k_vienna_arsenal"], {"coins": {"supply": 5}})),
         adv(ch("sack_vienna", "让兵自己去拿", {"treasury": 1000, "heat": 20, "morale": 4}, ["k_vienna_sacked"], {"coins": {"gold": 2}}))],
        condensed=True),
    scene("k_schoenbrunn", "vienna", "1816-06-14", "第三章·终场：锡兵", "美泉宫·东翼", "king_of_rome", [
        "1816 年 6 月 14 日，美泉宫。皇后不在，她去了帕尔马。",
        "罗马王五岁，穿着一身奥地利军装。家庭教师说，他已经不太会说法语了。",
        "男孩看看皇帝，又看看你：“你是谁？”",
        "皇帝没有回答，从口袋里掏出一只锡兵，放进男孩手里。",
        "家庭教师：“他每天晚上都问，爸爸是不是在天上。”"],
        [adv(ch("son_to_paris", "带孩子回巴黎", {"morale": 6, "heat": 6}, ["k_son_paris"], {})),
         adv(ch("son_stays", "让孩子留在母亲身边", {"morale": -2, "heat": -6}, ["k_son_stays"], {})),
         adv(ch("son_letter", "替皇帝给孩子留一封信，等他长大再读", {"morale": 2}, ["k_son_letter"], {}, items=["k_tin_soldier"]))],
        condensed=True),
    # ---------------- chapter 4 (choose one of two)
    scene("k_choice_1817", "iberia_channel", "1817-03-01", "第四章·第一场：两条路，一只钱袋", "布洛涅·皇帝的木屋", "napoleon", [
        "1817 年 3 月，布洛涅。十二年前，大军团在这里等过一支没来的舰队。",
        "英国人还在打。威灵顿带着新的军队又在葡萄牙登陆了，英国的钱在付俄国人的饷。",
        "拿破仑：“要么去里斯本，把威灵顿赶下海；要么从这里过海，到伦敦去谈。”",
        "古尔戈：“平底船修好了两千条。还有一个美国人说，他的船不用帆，也不用桨。”",
        "维尔福：“陛下，两条路，钱只够走一条。”"],
        [adv(ch("to_iberia", "去伊比利亚，打威灵顿", {"morale": 2}, ["k_iberia"], {"coins": {"supply": 3}})),
         adv(ch("to_channel", "过海峡", {"morale": 4}, ["k_channel"], {"coins": {"gold": 1}}))],
        condensed=True),
    scene("k_torres_vedras", "iberia_channel", "1817-10-14", "第四章·决战：一百五十座炮台", "托雷斯韦德拉什防线", "gourgaud", [
        "1817 年 10 月，葡萄牙。托雷斯韦德拉什的防线从海边一直修到塔古斯河，一百五十座炮台。",
        "七年前，马塞纳在这些墙前面饿了一个冬天，一枪没打就退了。",
        "古尔戈：“威灵顿在等我们饿。”",
        "维尔福：“这一次，我们的面包从海上来。”"],
        [adv(ch("amnesty", "宣布大赦：放下枪的西班牙人和葡萄牙人一律回家", {"heat": -12}, ["k_spain_amnesty"], {})),
         adv(ch("hang_guerrillas", "抓到的游击队员一律绞死", {"heat": 15}, ["k_spain_hanged"], {"coins": {"supply": 3}})),
         adv(ch("parley_wellington", "派人去见威灵顿，谈交换俘虏", {}, ["k_wellington_parley"], {"coins": {"intel": 1}}))],
        condensed=True, when={"flags": ["k_iberia"]}),
    scene("k_dover", "iberia_channel", "1817-08-19", "第四章·决战：白崖", "多佛尔·海斯海滩", "napoleon", [
        "1817 年 8 月 19 日，海斯海滩。风停了一个晚上，两千条平底船过了海峡。",
        "多佛尔的白崖上全是炮台。崖下的海滩，只有退潮的时候能走。",
        "拿破仑：“三天。我只要三天的风。”",
        "科尔索趴在船舷上：“再过两个钟头，潮水就要涨了。”"],
        [adv(ch("london_parley", "拿下多佛尔以后，派人去伦敦谈", {"heat": -8}, ["k_london_parley"], {})),
         adv(ch("burn_chatham", "烧掉查塔姆的船坞", {"heat": 10}, ["k_chatham_burned"], {"coins": {"medal": 2}})),
         adv(ch("kent_notice", "在肯特张贴告示：英国人自己选政府", {"heat": 5}, ["k_kent_proclaim"], {"coins": {"intel": 2}}))],
        condensed=True, when={"flags": ["k_channel"]}),
    # ---------------- chapter 5
    scene("k_warsaw", "niemen", "1818-05-03", "第五章·第一场：面包放在夏天里", "华沙·王宫", "napoleon", [
        "1818 年 5 月，华沙。波兰人在王宫前面跳舞，喊着：“恢复波兰王国！”",
        "亚历山大沙皇在维尔纳集结了三十万人。这一次，他不退了。",
        "拿破仑：“维尔福，六年前你说过，二十天的面包不够。”",
        "维尔福：“这一次，面包放在仓库里，仓库放在路上，路放在夏天里。六月出兵，十月以前回来。”",
        "账簿的最后几页里，还夹着 1812 年维尔纳仓库的清单。"],
        [adv(ch("depots_first", "先在维斯瓦河一线修三座仓库", {"construction": 20}, ["k_depots_1818"], {"coins": {"supply": 3}})),
         adv(ch("polish_lancers", "招波兰枪骑兵", {"morale": 3}, ["k_polish_lancers"], {"troops": ["hussar", "hussar"]})),
         adv(ch("letter_to_tsar", "替皇帝给沙皇写信：在涅曼河上再见一面", {"heat": -4}, ["k_tsar_letter"], {}))],
        condensed=True),
    scene("k_niemen", "niemen", "1818-06-24", "第五章·决战：这一次河对岸什么都有", "科夫诺·涅曼河", "napoleon", [
        "1818 年 6 月 24 日，涅曼河。六年前的今天，大军在这里过河，河对岸什么都没有。",
        "今天，河对岸什么都有：多面堡，炮台，哥萨克，还有俄国近卫军。",
        "埃布莱的旧本子上抄着每一只锚的编号。巴蒂斯特照着本子，一只一只重新编。",
        "拿破仑：“这一次，我们要过去，也要回来。”"],
        [adv(ch("raft_parley", "过河以后，在河心搭一只木筏，请沙皇来谈", {"heat": -8}, ["k_niemen_parley"], {})),
         adv(ch("march_on_vilna", "直取维尔纳", {"vitality": -6}, ["k_vilna_taken"], {"coins": {"medal": 2}})),
         adv(ch("winter_quarters", "在河边修冬营，不再往前走", {"construction": 20}, ["k_winter_camp"], {"coins": {"supply": 2}}))],
        condensed=True),
    # ---------------- chapter 6
    scene("k_paris_1819", "last_coalition", "1819-08-15", "终章·第一场：五十岁", "巴黎·杜伊勒里宫花园", "napoleon", [
        "1819 年 8 月 15 日，巴黎。皇帝五十岁生日，杜伊勒里宫的花园里放了烟火。",
        "最后的同盟又签成了：英国出钱，俄国和普鲁士出人，十月在莱比锡会师。",
        "拿破仑：“二十六年了，维尔福。从土伦算起。”",
        "维尔福：“账簿换了十一本，陛下。”",
        "皇帝咳了几声，用手按着右边的肚子。拉雷说，他胃里长了东西。"],
        [adv(ch("last_levy", "最后一次征兵", {"heat": 10}, ["k_last_levy"], {"troops": ["line", "line", "grenadier"]})),
         adv(ch("veterans_only", "只召老兵，不征新兵", {"morale": 4}, ["k_veterans_only"], {"troops": ["grenadier", "jager"]})),
         adv(ch("rest_first", "先让皇帝休养一个月", {"vitality": 8}, ["k_emperor_rest"], {}))],
        items=["k_ledger_xi"], condensed=True),
    scene("k_leipzig_1819", "last_coalition", "1819-10-18", "终章·决战：第二次民族之战", "莱比锡·南郊的村子", "napoleon", [
        "1819 年 10 月 18 日，莱比锡。六年前的同一天，这里死了九万人。",
        "联军在南边的村子里摆开阵势：英国的火箭兵，普鲁士的近卫军，俄国的胸甲骑兵。",
        "拿破仑：“这是最后一仗了，维尔福。不管谁赢。”",
        "埃尔斯特河上，这一次有四座桥。每一座都是你让人修的。"],
        [adv(ch("one_stone", "在两次战役的阵亡者中间立一块碑", {"morale": 4, "heat": -4}, ["k_one_stone"], {})),
         adv(ch("spoils_to_veterans", "战利品全部分给老兵", {"treasury": -500, "morale": 6}, ["k_spoils_shared"], {})),
         adv(ch("spoils_to_treasury", "战利品充入国库", {"treasury": 1000}, [], {"coins": {"gold": 2}}))],
        condensed=True),
    scene("k_final", "last_coalition", "1819-10-19", "终章·终场：桌上的三样东西", "普罗布斯泰达·皇帝的帐篷", "napoleon", [
        "1819 年 10 月 19 日夜，普罗布斯泰达。帐篷外面，联军的使者在等回话。",
        "拿破仑：“维尔福，你跟了我二十六年。你说，现在该怎么办？”",
        "桌上摆着三样东西：一份和约，一顶新皇冠的图样，还有你自己的辞呈。",
        "和约要皇帝退回莱茵河，让儿子继位，各国各回各家。",
        "皇冠的图样上写着：欧罗巴皇帝。",
        "辞呈是你昨天夜里写的。马赛来的信上说，法老号又出海了。"],
        [adv(ch("final_peace", "把和约推到皇帝面前", {}, ["k_final_peace"], {})),
         adv(ch("final_crown", "把皇冠的图样推到皇帝面前", {}, ["k_final_crown"], {})),
         adv(ch("final_resign", "把辞呈放在两样东西中间", {}, ["k_final_resign"], {}))],
        condensed=True),
]

COUNCILS = [
    council("ev_council_fleurus", "1815-06-16", "弗勒吕斯·风车磨坊", "napoleon", "弗勒吕斯军议", [
        "1815 年 6 月 16 日上午，弗勒吕斯。从风车磨坊顶上看得见利尼和圣阿芒的教堂尖顶，普鲁士人在那里。",
        "西边十二公里是四臂村，威灵顿的人正从布鲁塞尔一批批赶来。",
        "拿破仑：“今天打普鲁士人。格鲁希，明天你带三万三千人去追他们，别让他们回来。”",
        "格鲁希点了点头。你看了一眼桌上的命令：上面没写时辰。"],
        ("reserve_guns", "把炮兵预备队全部留在皇帝身边（开场军令点 +2）", {"rogue": {"coins": {"supply": -1}}}),
        ("ney_at_dawn", "替内伊备好弹药车，让他天一亮就压上四臂村（敌军心 −2）", {"effects": {"vitality": -3}}),
        ("grouchy_hourly", "替皇帝补上时辰：格鲁希每两个钟头报一次信（多一回合布阵）",
         {"flags": ["k_grouchy_close"], "items": ["k_grouchy_order"]})),
    council("ev_council_rhine", "1815-08-30", "阿格诺·城防司令部", "napoleon", "阿格诺军议", [
        "1815 年 8 月底，阿格诺。劳特河对岸的营火一晚比一晚多。",
        "德鲁奥：“他们的炮比我们多。可他们的炮要过河，我们的炮已经在墙上了。”",
        "拿破仑：“维尔福，墙后面的人要吃三个星期。”"],
        ("strasbourg_arsenal", "把斯特拉斯堡的军火全调上防线（开场军令点 +2）", {"rogue": {"coins": {"supply": -2}}}),
        ("false_pontoons", "在劳特河上游放几只假浮桥（敌军心 −2）", {"effects": {"construction": 5}}),
        ("ferries_early", "提前一天把守渡口的人派上去（多一回合布阵）", {"effects": {"vitality": -3}})),
    council("ev_council_vienna", "1816-06-10", "普尔克斯多夫·驿站", "napoleon", "普尔克斯多夫军议", [
        "1816 年 6 月，维也纳森林边上的普尔克斯多夫。从这里看得见圣斯特凡大教堂的尖顶。",
        "拿破仑：“我不想在城里打巷战。可卡尔大公不会把城门打开的。”",
        "德鲁奥：“缺口只能开在一个地方。开在哪里，就看炮弹够不够。”"],
        ("danube_barges", "把多瑙河上的船全开到城下运炮弹（开场军令点 +2）", {"effects": {"treasury": -200}}),
        ("bavarian_parade", "让巴伐利亚的师在城外游行一圈（敌军心 −2）", {"effects": {"heat": 3}}),
        ("schoenbrunn_park", "夜里先占住美泉宫的园子（多一回合布阵）", {"effects": {"vitality": -3}})),
    council("ev_council_torres", "1817-10-10", "阿伦克尔·山上的风车", "gourgaud", "阿伦克尔军议", [
        "1817 年 10 月，阿伦克尔。山上的风车已经被英国人拆了翼。",
        "古尔戈：“防线有三道，最外面那一道最长，也最薄。”",
        "维尔福：“从海上运来的面包能撑二十天。二十天以后，就是我们在等他们饿了。”"],
        ("bread_from_sea", "海上运来的面包先发一半（开场军令点 +2）", {"rogue": {"coins": {"supply": -2}}}),
        ("second_trench", "在防线前面挖一道壕沟，挖给威灵顿看（敌军心 −2）", {"effects": {"construction": 10, "vitality": -2}}),
        ("wait_for_fleet", "等英国舰队出港以后再打（多一回合布阵）", {"effects": {"morale": -2}})),
    council("ev_council_channel", "1817-08-18", "灰鼻角·信号塔", "napoleon", "灰鼻角军议", [
        "1817 年 8 月 18 日，灰鼻角。天气好的时候，从这里看得见英国的白崖。",
        "拿破仑：“风一停，就走。”",
        "科尔索：“船是够了。可两千条平底船一起出港，要一整夜。”"],
        ("ammo_first", "先装弹药，再装人（开场军令点 +2）", {"rogue": {"coins": {"supply": -2}}}),
        ("steam_smoke", "让美国人的蒸汽船在港外冒烟（敌军心 −2）", {"effects": {"treasury": -150}}),
        ("wait_low_tide", "等退潮再上岸（多一回合布阵）", {"effects": {"vitality": -2}})),
    council("ev_council_niemen", "1818-06-22", "马里扬波尔·犹太车夫的客栈", "napoleon", "马里扬波尔军议", [
        "1818 年 6 月，马里扬波尔。六年前，这家客栈的老板替大军赶过车，到现在还没拿到钱。",
        "拿破仑：“俄国人在对岸修了多面堡。这一次，他们要我们在河里死。”",
        "巴蒂斯特：“三座浮桥一起搭，要四个钟头。”"],
        ("three_bridges", "照埃布莱的旧本子，三座浮桥一起搭（开场军令点 +2）", {"effects": {"construction": 10}}),
        ("lancers_on_bank", "让波兰枪骑兵沿着河岸来回跑（敌军心 −2）", {"effects": {"vitality": -2}}),
        ("wait_for_fog", "等对岸的雾散了再过（多一回合布阵）", {"effects": {"morale": -2}})),
    council("ev_council_final", "1819-10-16", "吕岑·六年前的新兵墓", "napoleon", "吕岑军议", [
        "1819 年 10 月，吕岑。六年前，那些十八岁的新兵就埋在这片地里。",
        "拿破仑：“最后一次了。我要所有人都在。”",
        "维尔福：“老近卫军还剩四千人。会算账的，还剩我一个。”"],
        ("four_bridges", "把四座桥上的弹药车都开过来（开场军令点 +2）", {"rogue": {"coins": {"supply": -2}}}),
        ("old_guard_parade", "让老近卫军在阵前列队（敌军心 −2）", {"effects": {"morale": 2}}),
        ("wait_for_grouchy", "等格鲁希的军到齐（多一回合布阵）", {"effects": {}})),
]

FIXED = [
    event("ev_ney_auxerre", "fixed", "铁笼", "欧塞尔·省长官邸", "ney", [
        "1815 年 3 月 17 日，欧塞尔。内伊元帅五天前在巴黎对路易十八说：他会把拿破仑关进铁笼带回来。",
        "今天他带着整个军到了欧塞尔，站在门口，脸红得像他的头发。",
        "内伊：“我……我的兵不肯打。”",
        "拿破仑：“我知道。进来吧，我的勇士中的勇士。”"],
        [ch("take_him_in", "替内伊的军补发饷银，让他带兵", {"treasury": -300, "morale": 4}, ["k_ney_joined"], {"recruit": ["ney"]}),
         ch("keep_distance", "让他跟着走，但先别给他兵", {"morale": -2}, ["k_ney_distrusted"], {}),
         ch("iron_cage", "提醒皇帝：那只铁笼子，他是真的订做了", {"heat": -2}, ["k_ney_cage_known"], {"coins": {"intel": 1}, "recruit": ["ney"]},
            requires_clues=["cage_receipt"])],
        [ap("cage_receipt", "decode", "看内伊副官口袋里的收据", "巴黎一家铁匠铺的收据：一只铁笼，钱已经付了。他说的不是气话。")],
        date="1815-03-17"),
    event("ev_morrel_petition", "fixed", "伊夫堡 34 号", "巴黎·战争部档案室", "villefort", [
        "1815 年 4 月，战争部的档案室。一摞从马赛转来的请愿书里，有一封写得特别工整。",
        "请愿人是莫雷尔父子商行的莫雷尔先生，请求释放法老号的大副埃德蒙·唐泰斯：“他从厄尔巴岛替皇帝带过一封信，因此被捕。”",
        "附议栏里签着一个名字：杰拉尔·德·维尔福，马赛王家检察官。",
        "你看了很久。在路易十八的法国，这封信是唐泰斯的罪证；在皇帝的法国，它是一张释放令。",
        "伊夫堡的犯人名册附在后面：34 号，唐泰斯。27 号，法利亚，意大利神甫，“疯子”。"],
        [ch("free_34", "签发释放令：伊夫堡 34 号，埃德蒙·唐泰斯", {"morale": 3}, ["k_dantes_freed"], {"recruit": ["dantes"]},
            items=["k_petition"], requires_clues=["gerard_hand"]),
         ch("free_34_and_27", "两个都放：34 号，还有 27 号", {"morale": 4, "heat": 3}, ["k_dantes_freed", "k_faria_freed"],
            {"recruit": ["dantes", "faria"]}, items=["k_petition"], requires_clues=["gerard_hand"], requires={"flags": ["faria_half_letter"]}),
         ch("send_it_back", "原样转回马赛，交给杰拉尔处理", {}, ["k_petition_returned"], {"coins": {"intel": 1}})],
        [ap("gerard_hand", "decode", "对一对附议栏的笔迹和日期", "附议的日期是 4 月，可正文里写的是 3 月才有的说法：这封请愿书是杰拉尔替莫雷尔起草的。他要的不是释放，是一份证据。")],
        date="1815-04-12", note="大仲马原著：百日王朝期间莫雷尔两次为唐泰斯请愿，维尔福替他起草，却把请愿书压下，后来成为唐泰斯“拿破仑党”的罪证。本分支让主角在巴黎截到这封信。"),
    event("ev_marie_louise_letter", "fixed", "维也纳来的信", "南锡·大公宫", "napoleon", [
        "1815 年 8 月，南锡。维也纳来的信使带来一封信，封蜡上是哈布斯堡的纹章。",
        "信是玛丽-路易丝皇后写的。她不回巴黎了，罗马王也不回。信的最后一行，提到了一位奈佩格伯爵。",
        "皇帝还没看到这封信。信在你手里。"],
        [ch("hand_it_over", "照原样交给皇帝", {"morale": -4}, ["k_letter_given"], {}),
         ch("after_the_battle", "压到劳特河一仗以后再交", {"morale": 2, "heat": 2}, ["k_letter_delayed"], {}),
         ch("with_a_note", "附上一张纸条：“陛下，美泉宫离这里只有八百公里。”", {"morale": 1}, ["k_letter_note"], {"coins": {"medal": 1}})],
        date="1815-08-11"),
    event("ev_melk_library", "fixed", "修道院的图书馆", "梅尔克·本笃会修道院", "villefort", [
        "1816 年 5 月，梅尔克。修道院建在多瑙河边的悬崖上，图书馆里有十万册书。",
        "皇帝的命令：挑出最好的手稿，装箱运往巴黎。",
        "管书的老修士拿出一本日课经给你看：“这是我们最旧的一本。巴黎会要它吗？”"],
        [ch("crate_manuscripts", "照命令装箱", {}, ["k_melk_crated"], {"coins": {"medal": 1}}),
         ch("register_and_leave", "登记造册，原样留在这里", {"heat": -8, "morale": 1}, ["k_melk_spared"], {}, requires={"flags": ["t_return_mark"]}),
         ch("maps_only", "只拿走多瑙河的水文图", {}, ["k_melk_maps"], {"coins": {"intel": 2}})],
        date="1816-05-20", note="register_and_leave 要求主干拿过 t_return_mark（坎波福米奥如实登记那幅画，或在柏林写明腓特烈佩剑的来处）。"),
    event("ev_arapiles_bones", "fixed", "阿拉皮莱斯的白骨", "萨拉曼卡城南的麦田", "gourgaud", [
        "1817 年 9 月，萨拉曼卡城南。五年前马尔蒙在这里输给了威灵顿。",
        "农民犁地的时候犁出了骨头，有法国人的，也有英国人的，分不清。",
        "古尔戈：“他们问，这些人要埋在哪里。”"],
        [ch("bury_together", "埋在一起，立一块不写国名的碑", {"morale": 2, "heat": -6}, ["k_arapiles_grave"], {}),
         ch("melt_the_lead", "把翻出来的铅弹熔了重铸", {}, [], {"coins": {"supply": 2}})],
        date="1817-09-02"),
    event("ev_fulton_nautilus", "fixed", "美国人的潜水船", "敦刻尔克·船坞", "villefort", [
        "1817 年 6 月，敦刻尔克。一个美国工程师带着一卷图纸找到军需处。他说，他是罗伯特·富尔顿的学生。",
        "十七年前，富尔顿给第一执政看过一条能潜到水下的船，取名“鹦鹉螺号”。第一执政说那是个疯子。",
        "工程师：“这一次我只要一笔钱，造十二条不用帆的拖船。有了它们，平底船不用等风。”"],
        [ch("fund_steam_tugs", "拨一笔钱造蒸汽拖船", {"treasury": -600}, ["k_steam_tugs"], {"coins": {"intel": 1}}),
         ch("buy_the_drawings", "只买下鹦鹉螺号的旧图纸", {"treasury": -100}, ["k_nautilus_plans"], {"coins": {"intel": 2}}),
         ch("send_him_home", "送他一张回美国的船票", {}, [], {})],
        date="1817-06-04", note="富尔顿 1800 年在法国造过潜艇“鹦鹉螺号”，1815 年去世；凡尔纳给尼摩的船起名正是借此。工程师是虚构的。"),
    event("ev_tilsit_raft", "fixed", "河心的木筏", "提尔西特·涅曼河", "napoleon", [
        "1818 年 6 月，提尔西特。十一年前，两位皇帝在河心的一只木筏上拥抱。",
        "木筏早就烂了，只剩几根桩子还插在河底。",
        "拿破仑：“那一天，他叫我兄弟。”"],
        [ch("rebuild_raft", "让工兵照原样再搭一只", {"construction": 10}, ["k_raft_rebuilt"], {}),
         ch("pull_the_stakes", "把桩子拔了，别让兵看着伤心", {"morale": 2}, [], {}),
         ch("leave_it", "什么也不做", {}, [], {"coins": {"intel": 1}})],
        date="1818-06-10"),
    event("ev_goethe_tea", "fixed", "歌德的花园小屋", "魏玛·伊尔姆河边", "goethe", [
        "1819 年 9 月，魏玛。七十岁的歌德在花园小屋里请你喝茶。十一年前，皇帝在爱尔福特见过他，说：“您是一个人。”",
        "歌德：“军需官先生，您的账簿上记的是钱，还是人？”",
        "窗外，大军的车队在伊尔姆河的桥上走了一整天。"],
        [ch("listen", "听他说完", {"morale": 2}, ["k_goethe_listened"], {}),
         ch("ask_for_words", "请他给大军写几句话", {"heat": -6}, ["k_goethe_proclamation"], {"coins": {"medal": 1}}),
         ch("pass_by", "谢过茶，赶路", {}, [], {"coins": {"supply": 2}})],
        date="1819-09-20"),
]

POOL = [
    event("ev_federes", "hundred_days", "联盟军的长矛", "巴黎·圣安托万区", "villefort", [
        "圣安托万区的工人组成了“联盟军”，三千人，排着队来领枪。",
        "军械库里的枪只够正规军。达武的意思是：给他们长矛。"],
        [ch("give_pikes", "发长矛", {"morale": 2}, [], {}),
         ch("give_muskets", "从正规军里匀一千条枪", {"morale": 4, "heat": 3}, ["k_federes_armed"], {"troops": ["line"]}),
         ch("send_home", "谢谢他们，请他们回家修路", {"construction": 10}, [], {})]),
    event("ev_vendee_rising", "hundred_days", "旺代又起来了", "巴黎·战争部", "fouche", [
        "旺代的保王党又起事了。富歇笑着说：“只要派两万人去，就能平下去。”",
        "两万人，正好是北方军团少的那个数。"],
        [ch("send_lamarque", "派拉马克带一万人去", {"heat": -10}, ["k_vendee_sent"], {}),
         ch("negotiate", "派人去谈：免他们的兵役", {"heat": -6}, ["k_vendee_parley"], {"coins": {"intel": 1}}, requires_clues=["fouche_letters"]),
         ch("ignore_it", "不管它，兵全往北走", {"heat": 12}, [], {"coins": {"medal": 1}})],
        [ap("fouche_letters", "decode", "看富歇送来的情报", "情报的消息源全是旺代那边的人：富歇两边都在写信。")],
        requires={"metric": {"heat": [">=", 25]}}),
    event("ev_post_horses", "hundred_days", "驿站的马", "巴黎北面的驿站", "villefort", [
        "大军缺马。法兰西每一座驿站的马厩里，都有六到十匹好马。",
        "驿站长：“马都征了，信谁来送？”"],
        [ch("take_half", "每座驿站征一半", {"heat": 5}, [], {"coins": {"supply": 2}, "troops": ["hussar"]}),
         ch("buy_from_farmers", "去乡下买", {"treasury": -300}, [], {"troops": ["hussar"]})]),
    event("ev_alsace_harvest", "rhine", "阿尔萨斯的葡萄", "阿尔萨斯的葡萄园", "marie", [
        "葡萄熟了，摘葡萄的人都被征去挖壕沟了。",
        "玛丽：“今年的酒要是酿不成，明年春天这里的人就要饿肚子。”"],
        [ch("lend_the_men", "每天放一半的人回去摘葡萄", {"heat": -8, "construction": -5}, ["k_harvest_saved"], {}),
         ch("buy_the_harvest", "军需处把葡萄全买下来，酿成军酒", {"treasury": -250, "morale": 3}, [], {"coins": {"supply": 2}})]),
    event("ev_tyrol_innkeeper", "vienna", "蒂罗尔的客栈", "因河边的客栈", "villefort", [
        "客栈老板是霍费尔的老部下。1810 年，霍费尔在曼托瓦被法国人枪决。",
        "老板：“你们要过山口，就得有人带路。带路的人，得有一个理由。”"],
        [ch("pay_well", "付三倍的向导钱", {"treasury": -150}, [], {"coins": {"intel": 1}}),
         ch("hofer_grave", "答应他：曼托瓦的霍费尔墓，大军会派人去修", {"heat": -6}, ["k_hofer_grave"], {"coins": {"intel": 1}})]),
    event("ev_smugglers_deal", "iberia_channel", "走私贩的情报", "海边的酒馆", "corso", [
        "海峡两边的走私贩二十年来什么都运：白兰地、丝绸、报纸，还有逃兵。",
        "科尔索：“他们说，皇家海军的巡逻表，十个金路易就能买到。”"],
        [ch("buy_the_tables", "买", {}, ["k_navy_tables"], {"coins": {"gold": -1, "intel": 3}}),
         ch("arrest_them", "抓起来，船充公", {"heat": 6}, [], {"coins": {"supply": 3}})],
        requires={"coins": {"gold": [">=", 1]}}),
    event("ev_carters_debt", "niemen", "六年前的车钱", "立陶宛的村子", "villefort", [
        "1812 年替大军赶车的犹太车夫们拿着发黄的凭单来了。凭单上是你的签名。",
        "领头的老人：“我们不要利息，只要本钱。”"],
        [ch("pay_the_debt", "照凭单付清", {"treasury": -400, "heat": -10}, ["k_carters_paid"], {"coins": {"supply": 3}}),
         ch("pay_half", "先付一半，打完仗再付", {"treasury": -200}, [], {"coins": {"supply": 1}})]),
    event("ev_guard_pensions", "last_coalition", "老兵的抚恤金", "巴黎·荣军院", "cambronne", [
        "荣军院的老兵排着队领抚恤金。有人没了腿，有人没了眼睛，有人是从埃及回来的。",
        "康布罗纳：“财政部说，打完这一仗才有钱。”"],
        [ch("pay_now", "先从军费里垫付", {"treasury": -300, "morale": 5}, ["k_pensions_paid"], {}),
         ch("promise_after", "打完再付", {"morale": -2}, [], {})]),
    event("ev_lodi_veteran", "conquest", "洛迪桥的老兵", "行军路边", "villefort", [
        "路边有个讨饭的老兵，一条袖子空着。他认出了你：“洛迪桥！您是那个军需文书！”",
        "他说，他是第一个冲上桥的那个营的。"],
        [ch("take_him_on", "收他进辎重队", {"morale": 3}, [], {"troops": ["drummer"]}),
         ch("give_coin", "给他一枚金币", {"morale": 1}, [], {"coins": {"gold": -1, "medal": 1}})],
        once=False, weight=2),
    event("ev_courier_lost", "conquest", "迷路的传令兵", "林间的岔路口", "gourgaud", [
        "一个传令兵在岔路口转了一夜，命令揣在怀里，没送到。",
        "古尔戈：“他说两条路的路牌都被人拔了。”"],
        [ch("double_the_couriers", "以后每道命令派两个人", {}, ["k_double_couriers"], {"coins": {"intel": 1}}),
         ch("punish", "按军法处置", {"morale": -2}, [], {"coins": {"medal": 1}})],
        once=True, weight=2),
]

ENDINGS = [
    {"id": "k_pax", "title": "鹰的和平", "body": [
        "1820 年春，巴黎。和约签在杜伊勒里宫，各国的旗帜挂在同一面墙上。皇帝退回莱茵河，罗马王成了拿破仑二世。",
        "你把第十一本账簿交给新的财政大臣。最后一页写着：二十七年，欠款还清。",
        "后来有人说，帝国最后一场胜利不在莱比锡，在一张桌子上。"]},
    {"id": "k_iron", "title": "铁的欧洲", "body": [
        "1820 年，皇帝在圣母院加冕为欧罗巴皇帝。从里斯本到维尔纳，每一座城的城门口都站着法国兵。",
        "你当上了帝国军需总监，管着整个欧洲的面包。每一个征发令都要你签字。",
        "你签了很多年。账簿越来越厚，名字越来越多，没有一个是你认得的。"]},
    {"id": "k_return", "title": "回到马赛", "body": [
        "1820 年夏，马赛老港。你辞了职，只带着一只木箱和那块厄尔巴的怀表。",
        "法老号进港了。船长是埃德蒙·唐泰斯，五年前从伊夫堡出来的人。他和梅尔塞苔丝的婚礼，推迟了五年，终于办了。",
        "这个世界上从来没有过一位基督山伯爵。你在婚宴上举起杯子，觉得这样也很好。"]},
    {"id": "k_dusk", "title": "鹰落", "body": [
        "1821 年 5 月，皇帝死在杜伊勒里宫，五十一岁。拉雷说，是胃里的东西。",
        "他赢了滑铁卢，赢了维也纳，赢了第二次民族之战，却没有赢下一张和约。",
        "葬礼那天，你走在老近卫军的后面，手里拿着第十一本账簿。最后一页还空着。"]},
    {"id": "bankruptcy", "title": "军费告罄", "body": [
        "国库空了。银行家关上了门，征发令贴出去没有人理。",
        "你被叫去议会作证。议员们问：钱都去哪里了？你把账簿摊开，一页一页念给他们听。"]},
    {"id": "loss", "title": "大军溃散", "body": [
        "兵走不动了。逃兵比行军的人多，车队一辆接一辆扔在路边。",
        "帝国没有输在战场上，输在了路上。"]},
    {"id": "blockade", "title": "全境起义", "body": [
        "从旺代到蒂罗尔，钟声一座城接一座城响起来。",
        "征来的每一袋面粉，最后都变成了对准你的一颗子弹。"]},
]

RULES = {
    "failures": [
        {"ending": "bankruptcy", "reason": "treasury", "when": {"metric": {"treasury": ["<=", 0]}}},
        {"ending": "loss", "reason": "vitality", "when": {"metric": {"vitality": ["<=", 0]}}},
        {"ending": "blockade", "reason": "heat", "when": {"metric": {"heat": [">=", 100]}}}],
    "endings": [
        {"id": "k_return", "when": {"flags": ["k_final_resign", "k_dantes_freed"]}},
        {"id": "k_pax", "when": {"flags": ["k_final_peace"], "metric": {"heat": ["<", 60]},
                                 "count_flags": {"of": ["k_wounded_exchanged", "k_peace_offered", "k_vienna_spared", "k_son_stays",
                                                        "k_spain_amnesty", "k_london_parley", "k_niemen_parley", "k_goethe_listened",
                                                        "k_carters_paid"], "min": 3}}},
        {"id": "k_iron", "when": {"flags": ["k_final_crown"]}}],
    "default_ending": "k_dusk",
    "exclusive_flags": [["k_iberia", "k_channel"], ["k_final_peace", "k_final_crown", "k_final_resign"],
                        ["k_son_paris", "k_son_stays", "k_son_letter"], ["k_vienna_spared", "k_vienna_sacked"]],
    "actions": {
        "_doc": "同 trunk.json：数值是起点；键名以 A 的实现为准。鹰飞的征发更狠（民愤 +15），工事与测绘在每章都开。",
        "visit_town": {"cost": 100, "effects": {"vitality": 4, "morale": 2}},
        "visit_backdoor": {"effects": {"heat": -8}, "coins": {"intel": 1}},
        "trade_fair": {"effects": {"treasury": 200}},
        "trade_counterfeit": {"effects": {"treasury": 500, "heat": 15}, "flags": ["k_requisition"]},
        "build": {"metric": "construction", "chapters": ["hundred_days", "rhine", "vienna", "iberia_channel", "niemen", "last_coalition"], "cost": 250, "gain": 20},
        "explore": {"metric": "exploration", "chapters": ["rhine", "vienna", "iberia_channel", "niemen"], "cost": 200, "gain": 20},
        "fund": {"chapters": []}}}

BIG_FATE_EXTRA = [
    {"id": "exile_with_emperor", "title": "随驾流放", "scenes": ["k_waterloo"], "when": {"not_flags": ["k_dantes_freed"]}, "jump": "ocean",
     "desc": "滑铁卢输了。皇帝要去罗什福尔找船。你把账簿塞进大衣，跟上去。（转入「远洋」分支，按书的携带规则带走伙伴和币）",
     "effects": {"morale": -6}},
    {"id": "last_square", "title": "最后的方阵", "scenes": ["k_waterloo", "k_leipzig_1819"],
     "desc": "老近卫军排成方阵掩护撤退。军心回到 40，但宿命在这一仗的伙伴必须上场断后。", "effects": {"morale": 10, "vitality": -10}}]

def main():
    d = {
        "id": "conquest", "version": 2, "title": "鹰飞 · 一八一五—一八一九",
        "source": "草稿（标签 conquest，2026-11-02，Claude）。鹰飞分支：在滑铁卢打赢以后继续征服的架空线。第一章写满，第二到第六章压成每章两到三场（condensed），够一局打到固定结局。形状同 trunk.json。由 tools/build_conquest.py 生成。",
        "brand": "鹰飞",
        "initial": {"treasury": 3000, "morale": 60, "heat": 20, "vitality": 70, "construction": 0, "exploration": 0},
        "gauges": {"treasury": "军费", "morale": "士气", "heat": "民愤", "vitality": "体力", "construction": "工事", "exploration": "测绘"},
        "chapters": CHAPTERS, "characters": CHARACTERS, "items": ITEMS, "rules": RULES, "big_fate_extra": BIG_FATE_EXTRA,
        "scenes": SCENES, "events": COUNCILS + FIXED + POOL, "endings": ENDINGS,
        "tuning": {"wealth_limit": 40000},
        "design_notes": [
            "三个固定结局 + 一个默认结局（ARCH §1.6 要求每个分支至少 2 个固定 + 1 个默认）：k_return（辞职且放过唐泰斯）> k_pax（选和约，民愤 < 60，且一路上至少做过 3 件留余地的事）> k_iron（选皇冠）> 默认 k_dusk。",
            "k_return 是跨分支的回报：只有在战争部截下莫雷尔的请愿书、放出伊夫堡 34 号，这条结局才开。放了 27 号法利亚要求主干拿到 faria_half_letter。",
            "随驾流放（big_fate_extra）只在滑铁卢战败时出现，跳到远洋段的 prologue；放过唐泰斯以后不提供（远洋的唐泰斯 1829 年才越狱，两条线不能同时成立）。",
            "第四章是章内二选一（k_iberia / k_channel），用 scenes[].when 跳过另一场，地图用 frames 切镜头（同主干第二到第四幕）。",
            "所有战斗等级都写绝对值（L12–L24），见 book_conquest_patch.json 与 CONQUEST.md §5。",
        ],
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("conquest: %d scenes, %d events, %d endings" % (len(SCENES), len(d["events"]), len(ENDINGS)))

if __name__ == "__main__":
    main()
