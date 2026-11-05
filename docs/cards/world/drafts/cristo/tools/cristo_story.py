# -*- coding: utf-8 -*-
# Cristo branch (伊夫堡) segment definition: chapters, characters, items, scenes, events, endings, rules.
# Shape: ocean_pawn.json v1 + ARCH §1.5 v2 fields (rules / on_enter.demands / choices[].requires|rogue / events / big_fate_extra / gauges).
# Source: Alexandre Dumas, Le Comte de Monte-Cristo (1844-46, public domain). No modern adaptation is used.
# Chapter 1 and 2 scenes are VN-ready; chapters 3-5 are outlines ("draft": "outline") with the final choice shapes.

def S(id, chapter, date, title, location, speaker, body, choices, appraisals=(), item_ids=(), draft=None, on_enter=None, note=None):
    s = {"id": id, "chapter": chapter, "date": date, "title": title, "location": location, "speaker": speaker,
         "body": list(body), "item_ids": list(item_ids), "appraisals": list(appraisals), "choices": list(choices)}
    if on_enter:
        s["on_enter"] = on_enter
    if draft:
        s["draft"] = draft
    if note:
        s["_note"] = note
    return s


def A(id, kind, label, observation):
    return {"id": id, "kind": kind, "label": label, "observation": observation}


def C(id, label, effects=None, flags=(), advance=True, **kw):
    c = {"id": id, "label": label, "effects": dict(effects or {}), "flags": list(flags)}
    c.update(kw)
    if advance:
        c["advance"] = True
    return c


CHAPTERS = [
    {"id": "marseille", "title": "第一章 · 马赛 1815", "currency": "franc", "currency_name": "法郎（厄尔巴带来的盘缠）", "treasury_start": 2000,
     "scene_ids": ["c_landfall", "c_reserve", "c_gerard", "c_petition", "c_white_june"]},
    {"id": "if_years", "title": "第二章 · 伊夫堡岁月 1816—1829", "currency": "franc", "currency_name": "法郎（伊夫堡面包合同）", "treasury_start": 1600,
     "scene_ids": ["c_if_contract", "c_bread_34", "c_faria_27", "c_morgiou", "c_faria_dies", "c_if_night"]},
    {"id": "montecristo", "title": "第三章 · 基督山 1829", "currency": "franc", "currency_name": "法郎（走私船的分成）", "treasury_start": 1800,
     "scene_ids": ["c_tiboulen", "c_livorno", "c_montecristo"]},
    {"id": "mediterranean", "title": "第四章 · 地中海 1829—1838", "currency": "franc", "currency_name": "法郎（罗马汤姆森与弗伦奇银行的信用）", "treasury_start": 9000,
     "scene_ids": ["c_caderousse", "c_morrel_rescue", "c_carnival", "c_san_sebastiano"]},
    {"id": "paris_1838", "title": "第五章 · 巴黎 1838", "currency": "franc", "currency_name": "法郎（基督山伯爵的无限信用）", "treasury_start": 24000,
     "scene_ids": ["c_champs_elysees", "c_auteuil", "c_peers", "c_danglars", "c_trial"]},
]

CHARACTERS = [
    {"id": "villefort", "name": "埃德蒙·德·维尔福", "role": "主角；前帝国军需官兼司库，奉皇帝之命携第二封信到马赛；王家代理检察官杰拉尔·德·维尔福的远房族弟"},
    {"id": "gerard", "name": "杰拉尔·德·维尔福", "role": "1815 年马赛的王家代理检察官，1838 年巴黎的王家检察官；为保住父亲和前程，把唐泰斯埋进伊夫堡"},
    {"id": "noirtier", "name": "努瓦蒂埃", "role": "杰拉尔的父亲，老吉伦特派、波拿巴党人；那封信的收信人。1838 年全身瘫痪，只能用眼睛说话"},
    {"id": "dantes", "name": "埃德蒙·唐泰斯／基督山伯爵", "role": "法老号大副，十九岁；伊夫堡 34 号；1838 年的基督山伯爵（与远洋段同一人）"},
    {"id": "mercedes", "name": "梅尔塞苔丝", "role": "加泰罗尼亚人村的姑娘，唐泰斯的未婚妻；后来嫁给费尔南，成了莫尔塞夫伯爵夫人"},
    {"id": "fernand", "name": "费尔南·蒙台哥／莫尔塞夫伯爵", "role": "加泰罗尼亚渔夫，梅尔塞苔丝的表哥；1822 年在约阿尼纳出卖了阿里总督；1838 年的贵族院议员"},
    {"id": "danglars", "name": "唐格拉尔", "role": "法老号押运员，用左手写了告密信；1838 年的银行家、男爵"},
    {"id": "caderousse", "name": "卡德鲁斯", "role": "唐泰斯家楼下的裁缝，嘴碎、贪杯、胆小；后来在加尔桥边开客栈"},
    {"id": "louis_dantes", "name": "老唐泰斯", "role": "唐泰斯的父亲，住在梅朗林荫道的阁楼上"},
    {"id": "morrel", "name": "莫雷尔先生", "role": "法老号的船东，年轻时自己跑过船；唐泰斯的恩人（与远洋段同一人；伙伴 id 为 morel）"},
    {"id": "faria", "name": "法利亚神甫", "role": "伊夫堡 27 号，“疯神甫”；1796 年在博洛尼亚给过一个法国军需官半封信（与远洋段同一人）"},
    {"id": "governor", "name": "伊夫堡典狱长", "role": "要塞的看守长；只关心面包的价钱和犯人的数目"},
    {"id": "commissaire", "name": "警长", "role": "马赛警察局的警长，带着宪兵来雷瑟夫酒家抓人"},
    {"id": "renee", "name": "勒内·德·圣梅朗", "role": "杰拉尔的未婚妻，保王党侯爵的女儿；心肠比她的姓软"},
    {"id": "jacopo", "name": "雅科波", "role": "走私船少年阿梅莉号的水手；后来是基督山伯爵的船长"},
    {"id": "bertuccio", "name": "贝尔图乔", "role": "科西嘉走私贩；哥哥 1815 年死在尼姆，他发誓向检察官杰拉尔·德·维尔福报仇；后来是伯爵的管家"},
    {"id": "ali_pasha", "name": "阿里·特佩莱纳总督", "role": "约阿尼纳的总督，“约阿尼纳之狮”；1822 年被出卖、被杀"},
    {"id": "haydee", "name": "海黛", "role": "阿里总督的女儿；四岁那年和母亲一起被卖为奴；1838 年在贵族院作证"},
    {"id": "ali", "name": "阿里", "role": "伯爵的努比亚仆人，不会说话，会套马索"},
    {"id": "vampa", "name": "路易吉·万帕", "role": "罗马城外的强盗头子，牧羊人出身，枪法极准；欠伯爵一份人情"},
    {"id": "albert", "name": "阿尔贝·德·莫尔塞夫", "role": "费尔南和梅尔塞苔丝的儿子，二十出头，被万帕绑进墓窟"},
    {"id": "maximilien", "name": "马克西米利安·莫雷尔", "role": "莫雷尔先生的儿子，北非骑兵上尉；爱着瓦朗蒂娜"},
    {"id": "valentine", "name": "瓦朗蒂娜·德·维尔福", "role": "杰拉尔的女儿，也就是你的族侄女；有人在她的杯子里下毒"},
    {"id": "heloise", "name": "埃洛伊丝·德·维尔福", "role": "杰拉尔的续弦；为了儿子爱德华的遗产，一个一个地毒死家里的人"},
    {"id": "benedetto", "name": "贝内代托／安德烈亚·卡瓦尔康蒂", "role": "1817 年埋在奥特伊花园里的私生子，被贝尔图乔挖出来救活；土伦苦役犯；杰拉尔的儿子"},
]

ITEMS = [
    {"id": "elba_watch", "name": "厄尔巴双面金怀表", "chapter": "marseille", "description": "皇帝在厄尔巴用过的旧怀表，表盘后面有个夹层。（主干与远洋段同一件物品，id 冻结）"},
    {"id": "faria_half", "name": "法利亚的半封信", "chapter": "marseille", "description": "1796 年博洛尼亚，有斯帕达纹章的那一半。另一半在伊夫堡 27 号的神甫手里。（主干携带而来）"},
    {"id": "emperor_letter", "name": "皇帝的第二封信", "chapter": "marseille", "description": "封蜡里压着一枚小鹰徽。收信人：努瓦蒂埃先生，巴黎，科克埃龙街十三号。唐泰斯身上带的是同一封信的另一份。"},
    {"id": "denunciation", "name": "左手写的告密信", "chapter": "marseille", "description": "雷瑟夫酒家葡萄架下捡到的草稿：字往左歪，笔画僵硬。写字的人是唐格拉尔，投信的人是费尔南。"},
    {"id": "dossier_note", "name": "唐泰斯卷宗的编号", "chapter": "marseille", "description": "王家检察署的一个卷宗号。不得探视，严加看管。没有审判，没有刑期。"},
    {"id": "bread_contract", "name": "伊夫堡面包合同", "chapter": "if_years", "description": "每月一船：面粉、油、蜡烛、柴火、药。承包商可以进到地牢的厨房。"},
    {"id": "if_register_page", "name": "伊夫堡入狱登记簿的一页", "chapter": "if_years", "description": "34 号：唐泰斯。笔迹是杰拉尔的。页边有人用铅笔写了一个“忘”字。"},
    {"id": "spada_letter", "name": "斯帕达枢机的整封信", "chapter": "if_years", "description": "两半拼在一起，撕口严丝合缝：基督山岛，第二个小湾往东，第二十块岩石。"},
    {"id": "janina_firman", "name": "约阿尼纳的卖身契", "chapter": "if_years", "description": "1822 年，奴隶贩子埃尔-科比尔开给一个法国军官的收据：总督的妻子和女儿，作价四十万皮阿斯特。卖主签名：费尔南。"},
    {"id": "red_purse", "name": "红丝钱袋", "chapter": "mediterranean", "description": "莫雷尔老人当年给老唐泰斯付房租用过的钱袋。1829 年 9 月 5 日，它回来了：里面是一张付清的期票和一颗钻石。"},
    {"id": "auteuil_box", "name": "奥特伊的木匣", "chapter": "paris_1838", "description": "1817 年 9 月的夜里埋在奥特伊花园里的木匣。里面是一块绣着字母 H 和 N 的襁褓布。"},
]

M = "marseille"
IFY = "if_years"
MC = "montecristo"
MED = "mediterranean"
PA = "paris_1838"

SCENES = []

# ======================================================================== chapter 1 · Marseille 1815 (VN-ready)
SCENES.append(S("c_landfall", M, "1815-02-28", "第一章·第一场：法老号的旗", "马赛旧港·圣让堡下的码头", "morrel", [
    "1815 年 2 月 28 日清晨，马赛旧港。从费拉约港来的小渔船在圣让堡下靠了岸。",
    "你贴身带着皇帝的信。信封上写着：努瓦蒂埃先生，巴黎，科克埃龙街十三号。马赛有一个转交的地址。",
    "港里停着一条三桅船，船尾漆着“法老号”，桅顶挂着莫雷尔父子商行的旗。",
    "莫雷尔：“从厄尔巴来的？小心点。港务处今天在查每一条从岛上来的船。”",
    "莫雷尔：“法老号前天进的港。勒克莱尔船长死在海上，是大副唐泰斯把船带回来的。我要让他当船长。”",
    "莫雷尔：“今天中午他在雷瑟夫酒家订婚，新娘是加泰罗尼亚人村的梅尔塞苔丝。”",
    "码头另一头，两个宪兵在挨个问渔夫话。其中一个手里拿着一张名单。",
    "莫雷尔压低了声音：“昨晚有人往王家检察署送了一封信。我的押运员唐格拉尔，今早一直在笑。”",
], [
    C("go_reserve", "先去雷瑟夫酒家，赶在中午以前提醒唐泰斯", {"morale": 3}, ["m_rushed_reserve"], rogue={"recruit": ["morel"]}),
    C("deliver_first", "先把信送到转交地址：皇帝的事在前", {"treasury": 300}, ["m_letter_delivered"], rogue={"recruit": ["morel"], "coins": {"intel": 1}}),
    C("call_on_gerard", "去王家检察署拜访族兄杰拉尔，先探他的口风", {"heat": -10}, ["m_called_on_gerard"], requires_clues=["police_list"], rogue={"recruit": ["morel"]}),
], appraisals=[
    A("police_list", "spot", "看宪兵手里的名单", "名单上有三行：法老号大副唐泰斯；从厄尔巴来的第二个信使，姓名不详；还有一行被墨水划掉了。"),
    A("letter_seal", "weigh", "掂一掂贴身的那封信", "信比出发时重了一点：贝特朗元帅在封蜡里压了一枚小鹰徽。拆过的人一眼就看得出来。"),
], item_ids=["elba_watch", "emperor_letter"], on_enter={"demands": [
    {"id": "m_summons", "title": "检察署的传票：三天内到王家检察署报到", "due_in": 3, "cost": 0, "item": "",
     "on_expire": {"effects": {"heat": 15}, "flags": ["m_summons_ignored"]}, "on_fulfill": {"flags": ["m_reported"]}}]}))

SCENES.append(S("c_reserve", M, "1815-02-28", "第一章·第二场：雷瑟夫酒家的订婚宴", "雷瑟夫酒家·葡萄架下", "dantes", [
    "正午，雷瑟夫酒家。葡萄架下摆了二十副刀叉，海风把桌布吹得鼓起来。",
    "唐泰斯：“再过十四天我就是船长了。梅尔塞苔丝，再过一个钟头，你就是唐泰斯太太。”",
    "梅尔塞苔丝笑着，手却一直攥着餐巾。她的表哥费尔南坐在桌尾，一口酒也没喝。",
    "卡德鲁斯已经醉了：“唐格拉尔，你昨天在这张桌子上写的那张纸呢？丢啦？”",
    "唐格拉尔：“什么纸？你喝多了。”",
    "楼梯上响起靴子声。一个佩着白色绶带的警长走进来，身后是四个宪兵。",
    "警长：“以法律的名义！谁是埃德蒙·唐泰斯？”",
    "老唐泰斯站起来，碰翻了酒杯。唐泰斯：“是我。一定是弄错了。”",
    "警长的目光扫过整张桌子，在你身上停了一下：“还有一位从厄尔巴来的先生？”",
], [
    C("take_the_paper", "趁乱捡起葡萄架下那团纸，收进袖子", {"heat": 5}, ["m_denunciation"], requires_clues=["crumpled_paper"], items=["denunciation"]),
    C("vouch_for_him", "亮出军需官的委任状，要求陪他去检察署", {"morale": 4, "heat": 10}, ["m_escorted"], rogue={"coins": {"medal": 1}}),
    C("caderousse_home", "把醉倒的卡德鲁斯扶回家，听他把昨天的事说完", {"heat": -3}, ["m_caderousse_talked"], requires_clues=["left_hand"], rogue={"recruit": ["caderousse"]}),
    C("keep_quiet", "一言不发。你身上还有一封同样的信", {"heat": -8, "morale": -3}, ["m_silent_feast"]),
], appraisals=[
    A("crumpled_paper", "spot", "看葡萄架下那团纸", "桌脚边有一团揉皱的纸，被人踢进了葡萄架的阴影里。纸角上有半行字：“……从厄尔巴岛……一封给巴黎篡位党的信……”"),
    A("left_hand", "decode", "细看那半行字的笔迹", "字往左歪，笔画僵硬，是故意用左手写的。卡德鲁斯说，昨天坐在这个位置上的是唐格拉尔；把纸捡走又扔回来的，是费尔南。"),
]))

SCENES.append(S("c_gerard", M, "1815-02-28", "第一章·第三场：烛火", "大库尔街·王家代理检察官的书房", "gerard", [
    "当天夜里，大库尔街。杰拉尔·德·维尔福刚从圣梅朗侯爵家的订婚宴上回来，礼服还没换。",
    "桌上摊着从唐泰斯身上搜出来的那封信。信封上写着：努瓦蒂埃先生，巴黎，科克埃龙街十三号。",
    "杰拉尔：“努瓦蒂埃。你知道这是谁吗？是我父亲。”",
    "他把信凑到烛火上。火苗卷起来的时候，他的手很稳。",
    "杰拉尔：“那个水手什么都不知道。所以，他必须一直什么都不知道下去。”",
    "杰拉尔：“厄尔巴来了两个信使。一个在楼下，另一个——”他抬头看你，“——姓维尔福。”",
    "杰拉尔：“族弟，这个姓在国王那边值一个检察官，在皇帝那边值一个参议员。你要拿它去换一个水手吗？”",
    "窗外，一辆没有标记的马车停在门口。车夫在等一道命令：去伊夫堡。",
], [
    C("trade_your_letter", "把你的那封信也交给他，换他答应“关几个月就放”", {"heat": -25, "morale": -6}, ["m_bargain", "m_letter_burned"]),
    C("warn_him", "当面告诉他：烧信是重罪，你会去作证", {"heat": 20, "morale": 5}, ["m_threatened_gerard"]),
    C("memorize_the_file", "什么也不说，记下卷宗编号，告辞", {}, ["m_dossier_no"], requires_clues=["dossier_no"], items=["dossier_note"], rogue={"coins": {"intel": 2}}),
    C("show_denunciation", "把那张左手写的告密信摆到他面前", {"heat": 10, "morale": 2}, ["m_leverage"], requires_flags=["m_denunciation"]),
], appraisals=[
    A("dossier_no", "decode", "看桌上卷宗的封面", "封面写着：唐泰斯，狂热的波拿巴党人，参与厄尔巴复辟阴谋。不得探视，严加看管。下面是一个编号，你把它记住了。"),
    A("carriage", "spot", "看门口那辆马车", "车门上的纹章被泥糊住了，车夫是检察署的人。马车不去监狱，去港口：伊夫堡没有审判，只有登记簿。"),
], note="m_leverage：杰拉尔读完告密信，认出了唐格拉尔和费尔南。他没有放人，但从此怕你；第二章投标面包合同时他不再作梗。"))

SCENES.append(S("c_petition", M, "1815-04-12", "第一章·第四场：莫雷尔的请愿书", "梅朗林荫道·莫雷尔父子商行的账房", "morrel", [
    "1815 年 4 月，马赛。皇帝回到了杜伊勒里宫，港口的百合花旗换成了三色旗。",
    "杰拉尔·德·维尔福却还坐在检察署里。他的父亲努瓦蒂埃，现在是皇帝身边的红人。",
    "莫雷尔：“现在是我们的天下了，唐泰斯总该放出来了吧？我去求过检察官三次。”",
    "莫雷尔：“他说，写一份请愿书，把唐泰斯替皇帝送信的功劳写得越大越好，他亲自转呈内政部。”",
    "桌上是莫雷尔照着检察官的口授写好的草稿：“……唐泰斯为皇帝的归来立下了大功……”",
    "你知道这份请愿书最后会落进谁的抽屉，也知道皇帝在巴黎能待多久。",
    "莫雷尔：“维尔福先生，你是军需官，见过公文。你说，这样写行不行？”",
], [
    C("rewrite_plain", "替他重写：只写唐泰斯是个好水手，与政治无关", {"morale": 3}, ["m_petition_clean"], requires_clues=["dictated_lines"]),
    C("carry_to_paris", "亲自把请愿书送去巴黎，交到努瓦蒂埃手里", {"treasury": -400, "vitality": -8}, ["m_noirtier_met"], requires_clues=["ministry_stamp"], rogue={"coins": {"medal": 2}}),
    C("let_it_go", "照检察官说的寄出去", {}, ["m_petition_dictated"], rogue={"coins": {"gold": 1}}),
], appraisals=[
    A("dictated_lines", "decode", "逐句读请愿书草稿", "每一句都在替唐泰斯认罪：“狂热”“为皇帝效力”“参与归来”。皇帝在位时这是功劳；国王回来那天，这就是判决书。"),
    A("ministry_stamp", "spot", "看检察官给的回执", "回执上盖的是检察署的私章，不是转呈内政部的公章。这份东西根本没打算离开马赛。"),
]))

SCENES.append(S("c_white_june", M, "1815-06-25", "第一章·终场：白帽徽的六月", "旧港北岸·莫雷尔商行的货栈", "morrel", [
    "1815 年 6 月 25 日。滑铁卢的消息到了马赛。",
    "一夜之间，城里的三色旗全不见了，白帽徽别在每一顶帽子上。",
    "勒潘尼耶的坡上有人在喊：“打死波拿巴分子！”埃及难民住的那条街起了火。",
    "莫雷尔：“他们要砸商行的货栈，说法老号给篡位者送过信。”",
    "宪兵手里拿着检察署的新名单。第一行：埃德蒙·德·维尔福，前帝国军需官。",
    "莫雷尔：“我不走。这是我父亲的货栈。”",
    "码头石阶下，加泰罗尼亚人的小船在等你。船头的人朝你招手。",
], [
    C("stay_in_marseille", "留在马赛，借莫雷尔商行的名义做军需买卖", {"treasury": 600, "heat": 10}, ["m_stay_marseille"]),
    C("ask_gerard", "去找杰拉尔：国王回来了，他需要一个不说话的族人", {"heat": -30, "morale": -8}, ["m_gerard_patron"]),
    C("sail_genoa", "上船去热那亚，等风头过去", {"vitality": -6, "heat": -15}, ["m_exile_genoa"], rogue={"coins": {"supply": 2}}),
], note="Boss 战 marseille_arrest（L14）。皇帝的命令（保护莫雷尔）完成时给旗标 m_morrel_kept。"))

# ======================================================================== chapter 2 · the If years (VN-ready, shorter)
SCENES.append(S("c_if_contract", IFY, "1816-03-12", "第二章·第一场：面包合同", "伊夫堡·典狱长的办公室", "governor", [
    "1816 年 3 月，伊夫堡。从马赛港坐小船过来要一个钟头，浪大的时候要两个钟头。",
    "典狱长：“驻军六十人，犯人四十一个。面包、油、蜡烛、柴火，每月一船。上一个承包商往面粉里掺石灰。”",
    "典狱长：“你是前帝国军需官？那更好。你们那种人懂得怎么让一千人吃上饭。”",
    "他翻开一本很厚的登记簿。34 号那一页写着：唐泰斯，极端危险的波拿巴分子，不得探视。",
    "典狱长：“检察署打过招呼，说有个姓维尔福的人会来投标。原来就是你。”",
    "院子里，一个狱卒端着空碗从地牢的楼梯上来：“34 号今天又没吃。27 号的疯神甫又说要拿一百万换自由。”",
], [
    C("honest_bid", "报一个公道价：面粉过秤，一斤不少", {"treasury": -300, "morale": 4, "heat": -5}, ["m_bread_contract"], requires_clues=["flour_ledger"], items=["bread_contract"]),
    C("gerard_name", "提杰拉尔的名字：检察署担保，价钱好说", {"treasury": 200, "heat": -15, "morale": -4}, ["m_bread_contract", "m_gerard_owed"], items=["bread_contract"]),
    C("tear_page", "趁典狱长转身，把 34 号那一页撕下来", {"heat": 12}, ["m_bread_contract", "m_register_page"], requires_clues=["register_34"], items=["bread_contract", "if_register_page"]),
], appraisals=[
    A("flour_ledger", "weigh", "过秤上一个承包商留下的面粉", "每袋少了三斤，多出来的是石灰。典狱长知道，只是没人给他更好的价钱。"),
    A("register_34", "decode", "读登记簿上 34 号那一页", "笔迹是杰拉尔的。入狱日期 1815 年 3 月 1 日，没有审判记录，没有刑期。页边有人用铅笔写了一个小小的“忘”字。"),
], on_enter={"demands": [
    {"id": "m_first_boat", "title": "第一船面包：五天内把面粉和蜡烛运上岛", "due_in": 5, "cost": 300, "item": "",
     "on_expire": {"effects": {"heat": 10, "morale": -5}, "flags": ["m_contract_late"]}, "on_fulfill": {"flags": ["m_contract_kept"]}}]}))

SCENES.append(S("c_bread_34", IFY, "1817-07-20", "第二章·第二场：34 号的面包", "伊夫堡·地牢的厨房", "dantes", [
    "1817 年夏天。每个月的面包船，你都亲自押。",
    "你在给 34 号的那条面包里塞了一张纸条，只有一行字：莫雷尔还在为你奔走。",
    "一个月以后，空面包筐里多了一片碎瓦，上面用指甲划着字。",
    "唐泰斯：“我犯了什么罪？谁告的我？我只想知道这个。”",
    "狱卒说，34 号有一阵子不吃不喝，想把自己饿死。最近又开始吃了，说墙里有声音。",
    "墙里的声音，是 27 号的神甫在挖地道。他算错了方向，挖到了 34 号。",
], [
    C("tell_names", "把三个名字写给他：唐格拉尔、费尔南、杰拉尔·德·维尔福", {"morale": -2}, ["m_names_told"]),
    C("tell_hope", "只写两个字：等待", {"morale": 4}, ["m_wait_told"]),
    C("tell_family", "写上你自己的名字：你也是维尔福家的人", {"morale": 2, "heat": 5}, ["m_confessed_name"], requires_clues=["scratch_marks"]),
], appraisals=[
    A("scratch_marks", "spot", "细看碎瓦上的划痕", "划痕旁边还有另一种字迹，工整的拉丁字母：Spes（希望）。不是唐泰斯写的。"),
]))

SCENES.append(S("c_faria_27", IFY, "1818-12-03", "第二章·第三场：27 号的神甫", "伊夫堡·27 号牢房", "faria", [
    "1818 年冬。典狱长准你进地牢给生病的犯人送药：承包商顺便管药，这一条是你自己写进合同的。",
    "27 号的神甫很瘦，眼睛很亮。床板下压着一卷写满了字的衬衫布。",
    "法利亚：“你是军需官？……1796 年，博洛尼亚，斯帕达府的书房。”",
    "法利亚：“我给过一个法国军需官半封信。如果你就是他，你身上该有带纹章的那一半。”",
    "法利亚：“我发作过两次。第三次发作，我会死。”",
    "法利亚：“唐泰斯是我的儿子，不是血缘上的。你能帮我们，就帮到底。”",
], [
    C("join_halves", "拼上那半封信，记下藏宝的位置", {"exploration": 20}, ["m_spada_known"], requires_flags=["faria_half_letter"], requires_clues=["two_halves"], items=["spada_letter"]),
    C("bring_medicine", "照他的方子去马赛配药，每月随面包一起送进来", {"treasury": -200}, ["m_faria_medicine"], requires_clues=["faria_pulse"]),
    C("bring_tools", "给地道送工具：一把凿子、一卷绳子", {"construction": 25, "heat": 8}, ["m_tunnel_tools"]),
], appraisals=[
    A("two_halves", "spot", "把两半封信拼在一起", "撕口对得严丝合缝。拼起来是 1498 年斯帕达枢机的遗言：基督山岛，第二个小湾往东，第二十块岩石。"),
    A("faria_pulse", "ring", "听他的脉", "脉搏一下快一下停。这病有药可缓：一种红色的药水，每次十二滴。他自己配过，药瓶快空了。"),
], note="三选一是本章最重的取舍：藏宝（第三章钱多）、药（法利亚活过第三次发作，成为第三章以后的伙伴）、工具（地道快，第二章 Boss 战多一回合布阵）。"))

SCENES.append(S("c_morgiou", IFY, "1822-08-14", "第二章·第四场：莫尔吉乌的走私湾", "卡西斯海岸·莫尔吉乌小湾", "jacopo", [
    "1822 年 8 月。一份面包合同养不活一张关系网。你需要船，需要不问来历的钱。",
    "少年阿梅莉号的船老大在卡西斯的酒馆里有一张桌子。坐在他旁边的是个瘦高的水手，叫雅科波。",
    "雅科波：“今晚有一船英国布在莫尔吉乌卸货。海关知道，热那亚帮也知道。”",
    "雅科波：“你要是能让货安安稳稳进洞，以后你的面包船，我们的人替你划。”",
    "雅科波：“还有一件事。热那亚帮的船老大说，谁先进洞，货就归谁。”",
    "峡湾的水是黑的。崖顶上，海关的提灯一盏一盏亮起来。",
], [
    C("share_fair", "货按约平分，一个苏也不多拿", {"treasury": 400, "morale": 3}, ["m_jeune_amelie"], rogue={"recruit": ["jacopo"], "coins": {"supply": 2}}),
    C("buy_the_boat", "用你那一份买下一条小船，停在伊夫堡背面的礁石后", {"construction": 15}, ["m_jeune_amelie", "m_if_boat"], rogue={"recruit": ["jacopo"]}),
    C("inform_customs", "把热那亚帮的船报给海关，换一张缉私队的通行证", {"heat": -20, "morale": -5}, ["m_customs_pass"], rogue={"coins": {"intel": 2}}),
], note="锚点战 morgiou_cove（L15）。皇帝的命令（守住洞口）完成时给旗标 m_cargo_saved。"))

SCENES.append(S("c_faria_dies", IFY, "1829-02-14", "第二章·第五场：第三次发作", "伊夫堡·27 号牢房", "dantes", [
    "1829 年 2 月。十四年了。地道早就通了，34 号和 27 号每天夜里见面。",
    "唐泰斯：“他倒下了。第三次。半边身子已经不能动。”",
    "法利亚：“埃德蒙，宝藏是你的了。把我缝进麻袋里的，应该是你。”",
    "唐泰斯：“伊夫堡没有墓地。死人缝进麻袋，脚上绑一个铁球，从墙头扔进海里。”",
    "唐泰斯：“如果麻袋里的是活人——”",
    "你押运的面包船，明天夜里会停在海门下面。",
], [
    C("sack_plan", "照唐泰斯的计划：他钻进麻袋，你的船在礁石后面等", {}, ["m_sack_plan", "m_faria_dead"], rogue={"recruit": ["dantes"]}),
    C("medicine_last", "把最后一瓶药水灌下去：十二滴，再等一天", {"vitality": -5}, ["m_faria_lives"], requires_flags=["m_faria_medicine"], rogue={"recruit": ["dantes", "faria"]}),
    C("knife_in_sack", "把一把刀缝进麻袋的夹层", {}, ["m_sack_plan", "m_faria_dead", "m_knife_sewn"], requires_clues=["cannonball_weight"], rogue={"recruit": ["dantes"], "props": ["prop_smoke_bomb"]}),
], appraisals=[
    A("cannonball_weight", "weigh", "打听麻袋上绑的铁球", "三十六斤的铁球，绑在脚上。人一入水就会沉到底，除非手里有一把刀。"),
    A("burial_hour", "spot", "看抬尸工的排班", "抬麻袋的是两个看守，扔的位置是西边的墙头，不是海门。你的船得停在礁石后面等。"),
], note="medicine_last 是本书的架空岔口：法利亚活下来，和唐泰斯一起出逃，第三章起可以上阵（一条命）。"))

SCENES.append(S("c_if_night", IFY, "1829-02-28", "第二章·终场：伊夫堡的那一夜", "伊夫堡·海门", "dantes", [
    "1829 年 2 月 28 日夜。从雷瑟夫酒家那天算起，整整十四年。",
    "麻袋落水的声音还没传到墙头，警钟就响了：有个看守多看了一眼麻袋的形状。",
    "唐泰斯从水里爬上海门的石阶，手里攥着刀，浑身发抖。",
    "典狱长：“关海门！叫炮台开炮！”",
    "地牢的楼梯里全是脚步声。墙头上，哨兵在找月光下的人影。",
    "唐泰斯：“维尔福，十四年前你没能拦住那辆马车。今晚，别让他们关上这扇门。”",
], [
    C("to_tiboulen", "按原计划：让他游向蒂布朗岛，少年阿梅莉号明早经过", {"vitality": -5}, ["m_to_tiboulen"]),
    C("your_boat", "把他拉上你的小船，直接去热那亚", {"heat": 15}, ["m_on_your_boat"], requires_flags=["m_if_boat"]),
    C("stay_behind", "你留下来，用承包商的身份把警钟的事压下去", {"heat": -20, "morale": -4}, ["m_stayed_behind"]),
], note="Boss 战 if_corridors（L16）。皇帝的命令（唐泰斯第 13 回合结束时站在海门）完成时给旗标 m_escape_clean。"))

# ======================================================================== chapter 3 · Montecristo 1829 (outline)
SCENES.append(S("c_tiboulen", MC, "1829-03-01", "第三章·第一场：蒂布朗岛", "蒂布朗岛·礁石", "jacopo", [
    "黎明前，蒂布朗岛。唐泰斯趴在礁石上，海里漂着伊夫堡的麻袋和一顶看守的帽子。",
    "少年阿梅莉号的帆从南边过来。后面跟着两条海关的快艇。",
    "雅科波：“船上的人说他是个遇难的马耳他水手。快艇上的人可不信。”",
], [
    C("maltese_sailor", "让他冒充遇难的马耳他水手上船", {"morale": 3}, ["m_maltese"]),
    C("pay_the_crew", "给船老大加一笔钱：这个人上船，谁也别问", {"treasury": -300}, ["m_crew_paid"], rogue={"coins": {"supply": 2}}),
    C("decoy_boat", "你的小船朝西开，把快艇引走", {"heat": 10, "vitality": -4}, ["m_decoy"]),
], draft="outline", note="锚点战 tiboulen_swim（L17，规划模板：暗礁、浅水、海，暴风雨天时）。"))

SCENES.append(S("c_livorno", MC, "1829-03-09", "第三章·第二场：里窝那的理发店", "里窝那·港口边的理发店", "dantes", [
    "里窝那。理发师剃掉了十四年的胡子。唐泰斯盯着镜子里的人，很久没说话。",
    "唐泰斯：“这个人我不认识。很好。认识他的人，也不会认得了。”",
    "雅科波：“少年阿梅莉号下一趟去基督山岛，说是那里没人，最适合藏货。”",
], [
    C("name_sinbad", "替他起个新名字：水手辛巴达", {"morale": 4}, ["m_sinbad"]),
    C("open_account", "以你的名义在里窝那开一个账户，替他存第一笔钱", {"treasury": -200, "exploration": 10}, ["m_livorno_account"]),
    C("news_from_marseille", "把马赛这十四年的事一件一件告诉他", {"morale": -3}, ["m_news_told"]),
], draft="outline"))

SCENES.append(S("c_montecristo", MC, "1829-05-24", "第三章·终场：斯帕达的宝藏", "基督山岛·第二个小湾往东", "dantes", [
    "基督山岛。第二个小湾往东，第二十块岩石。唐泰斯用火药炸开了洞口。",
    "洞里是三只箱子：金锭、金币、宝石。斯帕达枢机的遗产，三百三十年没人碰过。",
    "海面上有三条船：热那亚帮、海关的缉私快艇，还有一条不挂旗的。",
], [
    C("take_all", "全部运走：从今天起，他是基督山伯爵", {"treasury": 3000}, ["m_treasure_taken"], rogue={"coins": {"gold": 4}}),
    C("leave_faria_share", "留下一箱，刻上法利亚的名字", {"treasury": 1800, "morale": 6}, ["m_treasure_taken", "m_faria_share"], rogue={"coins": {"gold": 2}}),
    C("your_cut", "按军需官的老规矩，先提一成做“运费”", {"treasury": 3600, "morale": -6}, ["m_treasure_taken", "m_your_cut"], rogue={"coins": {"gold": 5}}),
], draft="outline", note="Boss 战 monte_cristo_cave（L18，规划模板：洞穴、沙滩、浅水、虚空；目标 extract：把箱子搬上船）。"))

# ======================================================================== chapter 4 · Mediterranean 1829-1838 (outline)
SCENES.append(S("c_caderousse", MED, "1829-06-03", "第四章·第一场：加尔桥客栈", "博凯尔大路·加尔桥客栈", "caderousse", [
    "1829 年 6 月，博凯尔到贝勒加德的大路边。卡德鲁斯开的客栈门可罗雀。",
    "一个意大利口音的神甫敲门，自称布索尼。他拿出一颗钻石：“唐泰斯死在牢里，临终托我把这个分给他的朋友。”",
    "卡德鲁斯的老婆盯着钻石，眼睛都直了。卡德鲁斯开始说话：唐格拉尔、费尔南、梅尔塞苔丝、老唐泰斯是怎么饿死的。",
], [
    C("let_him_give", "让“神甫”把钻石给他", {"exploration": 25}, ["m_diamond_given"]),
    C("buy_the_diamond", "你出面把钻石按市价买下，把钱给他", {"treasury": -1500, "exploration": 20, "morale": 3}, ["m_diamond_bought"]),
    C("warn_caderousse", "私下警告卡德鲁斯：这颗钻石会要了你的命", {"exploration": 15, "heat": 5}, ["m_caderousse_warned"]),
], draft="outline", note="原著里这颗钻石引出了珠宝商被杀、卡德鲁斯进土伦苦役场，他在那里认识了贝内代托。m_diamond_bought 让卡德鲁斯这条命多活几年（伙伴）。"))

SCENES.append(S("c_morrel_rescue", MED, "1829-09-05", "第四章·第二场：九月五日", "梅朗林荫道·莫雷尔家", "morrel", [
    "1829 年 9 月 5 日，马赛。莫雷尔父子商行今天到期的期票是二十八万七千五百法郎。",
    "莫雷尔把手枪放在桌上。他的女儿朱莉在楼下被一个英国人拦住，那人给了她一只红丝钱袋。",
    "港口上有人在喊：“法老号！法老号进港了！”可法老号早就沉了。",
], [
    C("purse_as_planned", "照伯爵的安排：钱袋、期票、钻石，一样不少", {"morale": 8, "treasury": -2000}, ["m_morrel_saved"], items=["red_purse"]),
    C("tell_morrel", "上楼告诉莫雷尔：救你的人是唐泰斯", {"morale": 4, "treasury": -2000}, ["m_morrel_saved", "m_morrel_knows"], items=["red_purse"]),
    C("recruit_maximilien", "替马克西米利安在北非骑兵团里谋一个位置", {"treasury": -2400}, ["m_morrel_saved", "m_max_spahi"], items=["red_purse"], rogue={"recruit": ["maximilien"]}),
], draft="outline"))

SCENES.append(S("c_carnival", MED, "1838-02-20", "第四章·第三场：罗马狂欢节", "罗马·伦敦饭店／人民广场", "albert", [
    "1838 年 2 月，罗马狂欢节。九年过去了。",
    "伦敦饭店住着两个巴黎来的年轻人：阿尔贝·德·莫尔塞夫和弗朗兹·德·埃皮奈。隔壁套房住着基督山伯爵。",
    "阿尔贝：“我父亲是贵族院议员，莫尔塞夫伯爵。你认识他吗，伯爵？”",
    "伯爵笑了：“我认识很多人。”",
], [
    C("watch_albert", "派人盯着阿尔贝：他今晚要去罗马城外看古迹", {"exploration": 15}, ["m_albert_watched"], rogue={"recruit": ["ali"]}),
    C("thomson_french", "去汤姆森与弗伦奇银行，替伯爵在巴黎开无限信用", {"treasury": 3000, "heat": 10}, ["m_unlimited_credit"], rogue={"recruit": ["ali"]}),
    C("haydee_story", "陪海黛去看狂欢节：她第一次笑", {"morale": 6}, ["m_haydee_laughed"], requires={"alive": ["haydee"]}, rogue={"recruit": ["ali"]}),
], draft="outline"))

SCENES.append(S("c_san_sebastiano", MED, "1838-02-22", "第四章·终场：圣塞巴斯蒂安墓窟", "亚壁古道·圣塞巴斯蒂安墓窟", "vampa", [
    "阿尔贝被绑了。万帕的人送来一张纸条：清晨六点以前四千皮阿斯特，否则子弹。",
    "墓窟在亚壁古道底下，一层叠一层的壁龛里都是骨头。",
    "万帕：“基督山伯爵的朋友？……那就不一样了。可我的人不认识你。”",
], [
    C("ransom_paid", "照价付赎金，一个皮阿斯特也不还", {"treasury": -1800}, ["m_albert_freed"]),
    C("vampa_debt", "让万帕记住：这一次是伯爵欠你的，不是你欠伯爵的", {"morale": 4}, ["m_albert_freed", "m_vampa_owes"], rogue={"recruit": ["vampa"]}),
    C("albert_oath", "把阿尔贝拉到一边：你父亲的事，你迟早会知道", {"exploration": 15}, ["m_albert_freed", "m_albert_warned"], rogue={"recruit": ["albert"]}),
], draft="outline", note="Boss 战 san_sebastiano（L21，规划模板：墓穴、黑暗、多入口伏兵；目标 extract：把阿尔贝带出墓窟）。"))

# ======================================================================== chapter 5 · Paris 1838 (outline)
SCENES.append(S("c_champs_elysees", PA, "1838-05-21", "第五章·第一场：十点半的早餐", "巴黎·香榭丽舍大街 30 号", "dantes", [
    "1838 年 5 月 21 日上午十点半，阿尔贝家的早餐。基督山伯爵准时到了，一分不差。",
    "客人里有唐格拉尔男爵的女婿候选人，有王家检察官的未来女婿，还有马克西米利安·莫雷尔。",
    "伯爵：“我在巴黎买了房子，香榭丽舍大街 30 号。还有一处在奥特伊，方丹街 28 号。”",
    "贝尔图乔听见“奥特伊”三个字，脸一下子白了。",
], [
    C("map_the_names", "当晚列出巴黎的名单：莫尔塞夫、唐格拉尔、维尔福", {"exploration": 15}, ["m_paris_list"]),
    C("visit_gerard", "以族人的身份去拜访王家检察官", {"heat": 15, "morale": 2}, ["m_paris_gerard"]),
    C("visit_noirtier", "去见努瓦蒂埃老人：他只能用眼睛说话", {"exploration": 20}, ["m_noirtier_eyes"], requires_flags=["m_noirtier_met"]),
], draft="outline"))

SCENES.append(S("c_auteuil", PA, "1838-06-20", "第五章·第二场：奥特伊的花园", "奥特伊·方丹街 28 号", "bertuccio", [
    "奥特伊的晚宴。伯爵请了唐格拉尔夫妇、维尔福夫妇。杰拉尔在花园的那棵树下站住了。",
    "伯爵：“这座房子里发生过一桩罪行。我的管家说，二十一年前，有人在这棵树下埋过一只木匣。”",
    "墙外的黑影里有人在听。那人二十一岁，从土伦苦役场来，自称安德烈亚·卡瓦尔康蒂子爵。",
], [
    C("dig_the_box", "当着杰拉尔的面，让贝尔图乔把木匣挖出来", {"exploration": 25, "heat": 10}, ["m_box_dug"], items=["auteuil_box"]),
    C("spare_gerard", "提前把木匣挖走，不让他在客人面前崩溃", {"morale": -4, "heat": -10}, ["m_box_hidden"], items=["auteuil_box"]),
    C("follow_andrea", "跟踪墙外的人：他和卡德鲁斯在一起", {"exploration": 15}, ["m_andrea_followed"]),
], draft="outline", note="锚点战 auteuil_garden（L22，规划模板：夜、树林、房屋、墙；贝内代托带着苦役犯翻墙）。"))

SCENES.append(S("c_peers", PA, "1838-07-10", "第五章·第三场：贵族院", "卢森堡宫·贵族院议事厅", "haydee", [
    "贵族院。有人在报上登了一条短讯：1822 年约阿尼纳城堡献城的法国军官，名叫费尔南。",
    "莫尔塞夫伯爵站在议席上：“诬蔑。我要求调查。”",
    "门开了。一个穿希腊衣裳的年轻女子走进来，手里拿着一张旧纸。",
    "海黛：“我是阿里·特佩莱纳总督的女儿。卖掉我和我母亲的人，就是他。”",
], [
    C("show_firman", "把约阿尼纳的卖身契递给议长", {"exploration": 30}, ["m_morcerf_fallen"], requires={"items": ["janina_firman"]}),
    C("haydee_alone", "让海黛自己作证", {"exploration": 20, "morale": 4}, ["m_morcerf_fallen"], requires={"alive": ["haydee"]}),
    C("mercedes_plea", "梅尔塞苔丝来求你：别让阿尔贝看见", {"morale": 6}, ["m_mercedes_spared"]),
], draft="outline"))

SCENES.append(S("c_danglars", PA, "1838-08-30", "第五章·第四场：电报", "蒙莫朗西电报站／唐格拉尔银行", "danglars", [
    "唐格拉尔男爵靠内部消息做西班牙公债。他的消息来自政府的电报线。",
    "伯爵在一座偏僻的电报站停下马车，和电报员谈了一刻钟。第二天，电报说堂卡洛斯回到了西班牙。",
    "唐格拉尔赔掉了七十万法郎。这只是开头。",
], [
    C("ruin_him", "照伯爵的计划，一步一步掏空唐格拉尔的银行", {"treasury": 4000, "heat": 15}, ["m_danglars_ruined"]),
    C("only_the_debt", "只追回当年该给法老号的那笔钱", {"treasury": 1200, "morale": 4}, ["m_danglars_paid"]),
    C("expose_the_letter", "把左手写的告密信登在报上", {"exploration": 20, "heat": 10}, ["m_danglars_ruined", "m_letter_published"], requires={"items": ["denunciation"]}),
], draft="outline"))

SCENES.append(S("c_trial", PA, "1838-10-15", "第五章·终场：司法宫的那一夜", "西岱岛·司法宫重罪法庭", "gerard", [
    "重罪法庭。被告安德烈亚·卡瓦尔康蒂，真名贝内代托，杀害卡德鲁斯。公诉人：王家检察官杰拉尔·德·维尔福。",
    "庭长：“被告，你的父亲是谁？”贝内代托笑了：“我会说的。不过不是今天。”",
    "当天夜里，有人要在他开口之前让他永远闭嘴：苦役场的同伙、检察署的人、还有不知道替谁办事的警察。",
    "杰拉尔：“族弟，明天他一开口，维尔福这个姓就完了。你、我、瓦朗蒂娜，都完了。”",
], [
    C("let_him_speak", "守住他，让他在法庭上说完：我的父亲是王家检察官杰拉尔·德·维尔福", {"exploration": 30}, ["m_gerard_exposed", "m_vengeance_choice"]),
    C("shield_gerard", "在他开口之前把他带出法国：这个姓，你来保", {"heat": -30, "morale": -10}, ["m_shield_gerard"]),
    C("mercy", "让伯爵停手：瓦朗蒂娜还活着，这就够了", {"morale": 10}, ["m_gerard_exposed", "m_mercy_choice"], requires_flags=["m_valentine_saved"]),
], draft="outline", note="Boss 战 cristo_final（L24，规划模板：epic 12×7，夜，街道、房屋、屋顶、牢廊、河；目标 protect：贝内代托活到天亮）。"))

# ======================================================================== events (random pools + fixed)
def E(id, pool, title, location, speaker, body, choices, appraisals=(), weight=3, once=True, requires=None, date=None, **kw):
    e = {"id": id, "pool": pool, "weight": weight, "once": once, "requires": dict(requires or {}), "title": title, "location": location,
         "speaker": speaker, "body": list(body), "appraisals": list(appraisals), "choices": list(choices)}
    if date:
        e["date"] = date
    e.update(kw)
    return e


def EC(id, label, effects=None, flags=(), **kw):
    c = {"id": id, "label": label, "effects": dict(effects or {}), "flags": list(flags), "rogue": kw.pop("rogue", {})}
    c.update(kw)
    return c


EVENTS = []
# ---------------------------------------------------------------- fixed: councils and the Janina voyage
EVENTS.append(E("ev_c1_council", "fixed", "圣洛朗教堂的密会", "勒潘尼耶·圣洛朗教堂的圣器室", "morrel", [
    "1815 年 6 月 24 日夜，圣洛朗教堂。滑铁卢的消息比报纸早到了一天。",
    "莫雷尔、几个老水手、两个埃及来的马穆鲁克老兵，挤在圣器室里。",
    "莫雷尔：“明天他们会从勒潘尼耶冲下来。码头只有一条退路。”",
    "你是军需官。你知道，打这种仗靠的不是人多，是谁先把东西放到该放的地方。",
], [
    EC("arm_the_quay", "把商行库里的旧火枪全搬到码头（开场军令点 +2）", {}, [], rogue={"coins": {"supply": -1}}, boss_mod={"cp_bonus": 2}),
    EC("rumour_amnesty", "让人在城里放话：国王会大赦（敌军心 −2）", {"heat": 5}, [], boss_mod={"enemy_morale": -2}),
    EC("boats_early", "提前一夜把小船调到石阶下（多一回合布阵）", {"vitality": -3}, ["m_boats_early"], boss_mod={"prep_turn": 1}),
], weight=0, council=True, date="1815-06-24"))

EVENTS.append(E("ev_c2_council", "fixed", "卡西斯的船老大们", "卡西斯·港口酒馆的后屋", "jacopo", [
    "1829 年 2 月 27 日夜，卡西斯。少年阿梅莉号、圣费朗号、两条科西嘉的三桅小帆船，船老大们都来了。",
    "雅科波：“伊夫堡的炮台夜里只有两个人，可墙头的哨兵是新换的。”",
    "雅科波：“你说一句话，我们照做。代价，事成以后再算。”",
], [
    EC("buy_the_bell", "买通敲警钟的看守，让他晚敲一刻钟（开场军令点 +2）", {"treasury": -300}, [], boss_mod={"cp_bonus": 2}),
    EC("fireworks_marseille", "让人在马赛港放一船烟花，把驻军的眼睛引过去（敌军心 −2）", {"heat": 8}, [], boss_mod={"enemy_morale": -2}),
    EC("swimmers_ready", "派两个水性好的人提前潜到海门下面（多一回合布阵）", {"vitality": -3}, [], boss_mod={"prep_turn": 1}),
], weight=0, council=True, date="1829-02-27"))

EVENTS.append(E("ev_janina_1822", "fixed", "湖上的总督", "约阿尼纳·湖心岛的修道院", "ali_pasha", [
    "1822 年 1 月，约阿尼纳。苏丹的大军围了城。阿里总督退到湖心岛上，身边是火药、财宝，和他的妻子瓦西丽姬、女儿海黛。",
    "很多拿破仑的旧部在他手下当差。你来卖火药，用的是马赛面包合同的船。",
    "一个法国军官在总督身边进进出出，人们叫他费尔南上校。他和苏丹的使者谈了一整夜。",
    "阿里总督：“法国人，你说，我该相信谁？”",
], [
    EC("record_the_betrayal", "记下费尔南和使者谈话的时辰与地点", {"exploration": 25}, ["m_janina_witness"]),
    EC("buy_haydee", "城破以后，倾尽所有从奴隶贩子手里买下母女二人", {"treasury": -1200, "morale": 6}, ["m_haydee_bought"], items=["janina_firman"]),
    EC("sell_and_leave", "把火药卖给苏丹的人，赶在城破以前离开", {"treasury": 900, "morale": -6}, ["m_janina_sold"], rogue={"coins": {"gold": 2}}),
], appraisals=[A("fernand_face", "spot", "看那个法国军官的脸", "加泰罗尼亚人的脸。七年前，雷瑟夫酒家的桌尾，一口酒也没喝的那个人。")],
    weight=0, date="1822-01-20", _note="可选的远航节点（马赛 ⇄ 约阿尼纳各 6 天）。买下海黛（m_haydee_bought）时给物品 janina_firman；第五章贵族院用。"))

# ---------------------------------------------------------------- chapter 1 pool
EVENTS.append(E("ev_mercedes_window", "marseille", "加泰罗尼亚人村的窗", "加泰罗尼亚人村·梅尔塞苔丝的家", "mercedes", [
    "加泰罗尼亚人村。梅尔塞苔丝坐在窗边补网，补了一整天，还是同一个洞。",
    "梅尔塞苔丝：“你是从厄尔巴来的。你告诉我，他还活着吗？”",
    "门口，费尔南提着一篮鱼，站住了。",
], [
    EC("tell_truth", "告诉她实话：伊夫堡，没有刑期", {"morale": -2}, ["m_mercedes_knows"]),
    EC("tell_hope", "告诉她：等着，他会回来", {"morale": 3}, ["m_mercedes_waits"]),
    EC("warn_fernand", "当着费尔南的面说：告密信是谁投的，我知道", {"heat": 8}, ["m_fernand_warned"], requires_flags=["m_denunciation"], rogue={"coins": {"intel": 1}}),
]))
EVENTS.append(E("ev_old_dantes", "marseille", "梅朗林荫道的阁楼", "梅朗林荫道·老唐泰斯的阁楼", "louis_dantes", [
    "阁楼上很冷。老唐泰斯把儿子的水手服叠好放在床头，一直没有收起来。",
    "老唐泰斯：“莫雷尔先生送过钱。我不要。我儿子回来以前，我不花他的钱。”",
    "楼下的卡德鲁斯说，老人已经好几天没生火了。",
], [
    EC("pay_the_rent", "替他付一年的房租和柴火钱，说是法老号欠的工钱", {"treasury": -250, "morale": 3}, ["m_old_dantes_fed"]),
    EC("bring_morrel", "把莫雷尔请上楼，一起劝他", {"morale": 2}, ["m_old_dantes_fed"], requires={"alive": ["morel"]}),
    EC("leave_quietly", "把钱放在门口就走", {"treasury": -100}, []),
]))
EVENTS.append(E("ev_danglars_cargo", "marseille", "唐格拉尔的账", "莫雷尔商行·货栈", "danglars", [
    "唐格拉尔现在管着法老号的货账。他看你的眼神，像在看一张不知道该记在哪一栏的发票。",
    "唐格拉尔：“军需官先生，咱们是同行。一船棉布，每包少记两斤，谁也看不出来。”",
], [
    EC("expose_him", "把他的账摊给莫雷尔看", {"morale": 3, "heat": 5}, ["m_danglars_marked"], requires_clues=["short_bales"], rogue={"coins": {"supply": 2}}),
    EC("take_the_cut", "收下他的回扣，也收下他的把柄", {"treasury": 300}, ["m_danglars_cut"], rogue={"coins": {"intel": 1}}),
    EC("ignore", "装作没听懂", {}, []),
], appraisals=[A("short_bales", "weigh", "过秤三包棉布", "每包少两斤。少的那几斤，记在了一家西班牙商号的账上。")]))
EVENTS.append(E("ev_caderousse_wine", "marseille", "卡德鲁斯的酒", "梅朗林荫道·卡德鲁斯的裁缝铺", "caderousse", [
    "卡德鲁斯在裁缝铺里喝酒，案板上摊着一件没缝完的外套。",
    "卡德鲁斯：“我什么都没干！我只是没拦着。拦着有什么用？唐格拉尔会把我也写进去。”",
], [
    EC("hire_him", "雇他：你缺一个熟悉马赛每条巷子的人（金币 −1）", {}, ["m_caderousse_hired"], requires={"not": {"alive": ["caderousse"]}}, rogue={"coins": {"gold": -1}, "recruit": ["caderousse"]}),
    EC("make_him_swear", "让他发誓：将来上法庭，他会作证", {"exploration": 10}, ["m_caderousse_sworn"]),
    EC("leave_him", "让他接着喝", {}, []),
]))
EVENTS.append(E("ev_renee_plea", "marseille", "圣梅朗家的小姐", "圣梅朗侯爵府·花园", "renee", [
    "勒内·德·圣梅朗派人请你去花园。她是杰拉尔的未婚妻，订婚宴那天穿的是白纱。",
    "勒内：“我求他从轻发落那个水手。他说好。可他看我的样子，像是在看一个不懂事的孩子。”",
    "勒内：“你是他的族人。你去说，他也许会听。”",
], [
    EC("ally_renee", "告诉她实情，请她每年去伊夫堡的教堂为 34 号捐一次灯油", {"morale": 3}, ["m_renee_ally"]),
    EC("ask_for_pass", "请她向侯爵要一张出入港口的通行证", {"heat": -10}, ["m_marquis_pass"]),
    EC("say_nothing", "什么也别让她知道：她会嫁给他", {}, []),
]))
# ---------------------------------------------------------------- chapter 2 pool
EVENTS.append(E("ev_inspector", "if_years", "监狱督察", "伊夫堡·地牢的走廊", "governor", [
    "巴黎来的监狱督察一间一间地问：伙食怎样？有什么要求？",
    "34 号说：“我只要求审判。”27 号说：“我愿意拿五百万换自由。”督察笑着在本子上写：疯子。",
    "督察转过身来问你：“你是承包商？这两个人，你怎么看？”",
], [
    EC("speak_for_34", "替 34 号说话：这人没有审判记录", {"heat": 10, "morale": 4}, ["m_inspector_told"]),
    EC("bribe_inspector", "塞给督察一袋金币，请他把 34 号的卷宗带回巴黎", {"treasury": -400}, ["m_file_to_paris"], requires={"items": ["dossier_note"]}),
    EC("agree_mad", "附和他：都是疯子", {"heat": -8}, []),
]))
EVENTS.append(E("ev_bertuccio_name", "if_years", "“你也姓维尔福？”", "卡西斯·走私贩的仓库", "bertuccio", [
    "一个科西嘉人在仓库里修船帆。他的刀插在桌子上，刀柄缠着黑布。",
    "贝尔图乔：“1815 年，我哥哥在尼姆被保王党杀了。我去找检察官讨公道，检察官说：你哥哥是波拿巴分子，死了活该。”",
    "贝尔图乔：“那个检察官叫杰拉尔·德·维尔福。你也姓维尔福？”",
], [
    EC("tell_truth", "告诉他实话：是，他是我族兄", {"morale": 2}, ["m_bertuccio_knows"], rogue={"recruit": ["bertuccio"]}),
    EC("lie", "说你只是同姓", {}, ["m_bertuccio_lied"], rogue={"recruit": ["bertuccio"]}),
    EC("walk_away", "转身就走", {"heat": 5}, []),
], _note="m_bertuccio_lied：第五章奥特伊之夜他会认出你和杰拉尔说话的样子，羁绊“仇人的姓”降一档。"))
EVENTS.append(E("ev_old_dantes_end", "if_years", "老唐泰斯的最后一个冬天", "梅朗林荫道·老唐泰斯的阁楼", "caderousse", [
    "1816 年冬。卡德鲁斯在楼梯口拦住你：“老头子九天没吃东西了。他说他要等儿子。”",
    "阁楼的门关着。里面很安静。",
], [
    EC("break_in", "撞开门，叫医生", {"treasury": -150, "vitality": -3}, ["m_old_dantes_saved"]),
    EC("too_late", "你来晚了。替他办一场像样的葬礼", {"treasury": -200, "morale": -4}, ["m_old_dantes_died"]),
], requires={"not_flags": ["m_old_dantes_fed"]}, weight=5))
EVENTS.append(E("ev_accoules", "if_years", "阿库尔教堂的婚礼", "马赛·阿库尔教堂", "mercedes", [
    "1817 年。梅尔塞苔丝嫁给了费尔南。费尔南穿着军装：他要去西班牙打仗，回来就是军官了。",
    "梅尔塞苔丝看见你，停了一下，什么也没说。",
], [
    EC("stand_witness", "站在教堂最后一排，看完婚礼", {"morale": -2, "exploration": 10}, ["m_wedding_seen"]),
    EC("tell_dantes", "把消息写进面包里，告诉 34 号", {"morale": -4}, ["m_dantes_knows_wedding"]),
    EC("leave", "转身离开", {}, []),
]))
# ---------------------------------------------------------------- segment-wide pool (any chapter)
EVENTS.append(E("ev_customs_cutter", "cristo", "缉私快艇", "海岸外", "jacopo", [
    "一条海关的缉私快艇靠了过来，船头的回旋炮对着你。",
    "雅科波：“他们要查货。查出来，船就扣了。”",
], [
    EC("pay_toll", "按规矩给钱（金币 −1）", {}, [], rogue={"coins": {"gold": -1}}),
    EC("show_pass", "亮出缉私队的通行证", {"heat": -5}, [], requires_flags=["m_customs_pass"]),
    EC("run_for_it", "扯满帆跑", {"heat": 12, "vitality": -4}, [], rogue={"coins": {"supply": 1}}),
], weight=4, once=False))
EVENTS.append(E("ev_widow_pension", "cristo", "老兵的寡妇", "港口边的小教堂", "villefort", [
    "一个穿黑衣的女人在教堂门口拦住你：“您是军需官？我丈夫在第五轻骑兵团。滑铁卢以后，抚恤金一个苏也没发。”",
    "她手里攥着一张早就作废的帝国军饷凭单。",
], [
    EC("pay_from_purse", "从自己的钱里垫上", {"treasury": -150, "morale": 4}, ["m_widow_paid"]),
    EC("write_to_ministry", "替她写信给陆军部，用你从前的官衔签名", {"heat": 8, "morale": 2}, []),
    EC("refuse", "说你已经不是军需官了", {"morale": -2}, []),
], weight=3))
EVENTS.append(E("ev_tail", "cristo", "尾巴", "老城的一条小巷", "villefort", [
    "第三次了。同一个戴灰帽子的人，跟在你后面二十步。",
    "他看起来不像警察，倒像是替什么人办事的。",
], [
    EC("turn_and_ask", "转过身去，直接问他是谁派来的", {"heat": 6}, [], rogue={"coins": {"intel": 1}}),
    EC("lose_him", "穿过鱼市甩掉他", {"vitality": -3, "heat": -4}, []),
    EC("feed_him", "故意让他看见一封假信", {"heat": -8}, ["m_false_trail"], requires_clues=["grey_hat"]),
], appraisals=[A("grey_hat", "spot", "看他的鞋", "鞋擦得锃亮，裤脚上是检察署门前那条街才有的红土。")], weight=3, once=False))
# ---------------------------------------------------------------- chapter 3-5 pools (short)
EVENTS.append(E("ev_genoa_banker", "montecristo", "热那亚的银行家", "热那亚·银行街", "villefort", [
    "热那亚的老银行家把一颗宝石对着窗户看了很久：“这种切工，两百年前就没人会了。来历？”",
], [
    EC("say_inheritance", "说是一位意大利枢机的遗产", {"treasury": 800, "heat": 6}, []),
    EC("sell_small", "只卖最小的那颗，免得惹人问", {"treasury": 300}, []),
    EC("open_credit", "不卖，拿它作抵押开一张信用状", {"exploration": 10}, ["m_genoa_credit"]),
], weight=3))
EVENTS.append(E("ev_haydee_constantinople", "fixed", "君士坦丁堡的奴隶市场", "君士坦丁堡·奴隶市场", "haydee", [
    "1830 年代，君士坦丁堡。奴隶贩子埃尔-科比尔的院子里，一个十二岁的希腊女孩抬起头看着伯爵。",
    "如果你在约阿尼纳买下过她，她就不在这里——她在马赛等你们。",
], [
    EC("count_buys", "伯爵出价：一颗翡翠", {"treasury": -1500}, ["m_haydee_count"], rogue={"recruit": ["haydee"]}, requires={"not_flags": ["m_haydee_bought"]}),
    EC("fetch_from_marseille", "派船去马赛接她", {"treasury": -300}, ["m_haydee_count"], rogue={"recruit": ["haydee"]}, requires_flags=["m_haydee_bought"]),
], weight=0))
EVENTS.append(E("ev_telegraph", "fixed", "电报员的花园", "蒙莫朗西附近的电报站", "dantes", [
    "电报员在塔下面种草莓。他一年挣一千二百法郎，梦想有一个更大的花园。",
], [
    EC("buy_the_garden", "给他买一个大花园：两万五千法郎", {"treasury": -2500, "exploration": 15}, ["m_false_dispatch"]),
    EC("leave_the_wire", "这一次不碰政府的线", {"morale": 2}, []),
], weight=0))
EVENTS.append(E("ev_noirtier_eyes", "paris_1838", "努瓦蒂埃的眼睛", "维尔福府·努瓦蒂埃的房间", "noirtier", [
    "老人一动不动，只有眼睛能说话：闭一下是“是”，眨几下是“不”。",
    "瓦朗蒂娜：“爷爷说，家里有人在下毒。他喝的药里有番木鳖碱，所以他没事。可我没有。”",
], [
    EC("antidote_faria", "法利亚的红药水：每次十二滴", {"morale": 6}, ["m_valentine_saved"], requires={"alive": ["faria"]}),
    EC("count_narcotic", "按伯爵的办法：给她一颗让人假死的药丸", {"heat": 10}, ["m_valentine_saved"], requires={"alive": ["dantes"]}),
    EC("warn_gerard", "去告诉杰拉尔：凶手在你家里", {"heat": 15, "morale": -3}, ["m_heloise_suspected"]),
], weight=8, _note="瓦朗蒂娜是你的族侄女。m_valentine_saved 打开终场的“慈悲”选项。"))

# ======================================================================== endings and rules
ENDINGS = [
    {"id": "m_wait_hope", "title": "等待与希望", "body": [
        "1838 年 10 月，基督山岛。一条帆船载着伯爵和海黛驶出海湾。",
        "瓦朗蒂娜和马克西米利安在岸上读伯爵留下的信：“人类的全部智慧就包含在这两个词里：等待和希望。”",
        "杰拉尔·德·维尔福疯了，在花园里一遍一遍地挖坑。爱德华活了下来。你成了维尔福家的家长。",
        "你把皇帝的怀表放在瓦朗蒂娜的手里。表盘后面的夹层里，是一张二十三年前没送到的信的收据。"]},
    {"id": "m_full_ledger", "title": "伯爵的清单", "body": [
        "莫尔塞夫伯爵在家里开了枪。唐格拉尔男爵带着五万法郎逃出巴黎，在罗马的墓窟里饿了五天。",
        "王家检察官杰拉尔·德·维尔福在法庭上听完了儿子的证词，回到家，看见了妻子和小儿子的尸体。",
        "清单上的三个名字，一个不剩。伯爵对你说：“够了吗？”你没有回答。",
        "维尔福这个姓，从此只在法庭的卷宗里出现。"]},
    {"id": "m_name", "title": "维尔福这个姓", "body": [
        "贝内代托没有出庭。一条船把他送去了美洲，船票是你买的。",
        "杰拉尔保住了检察官的位子，在你面前却再也抬不起头。伯爵没有道别，第二天就离开了巴黎。",
        "梅尔塞苔丝去了马赛，住在老唐泰斯的阁楼里。她问你：“他还会回来吗？”",
        "你成了巴黎最受人尊敬的维尔福。每年 2 月 28 日，你都去伊夫堡的礁石边站一会儿。"]},
    {"id": "m_count", "title": "基督山伯爵", "body": [
        "复仇做完了一半。一些人倒下了，一些人逃掉了。",
        "伯爵把香榭丽舍大街的房子留给了莫雷尔一家，把奥特伊的花园烧成了平地。",
        "你回到马赛，在旧港边开了一家船具补给栈。招牌上没有名字，只画着一只鹰和一座城堡。"]},
]

RULES = {
    "_doc": "伊夫堡段的规则（ARCH §1.5）。数值是起点；键名以 A 的实现为准。指标在本段的叫法见 gauges。",
    "failures": [
        {"ending": "bankruptcy", "reason": "treasury", "when": {"metric": {"treasury": ["<=", 0]}}},
        {"ending": "loss", "reason": "vitality", "when": {"metric": {"vitality": ["<=", 0]}}},
        {"ending": "blockade", "reason": "heat", "when": {"metric": {"heat": [">=", 100]}}},
    ],
    "failure_text": {
        "bankruptcy": {"title": "钱袋空了", "body": ["面包合同被别人拿走了。马赛的码头上，再也没有人肯赊账给一个姓维尔福的波拿巴分子。"]},
        "loss": {"title": "倒在半路", "body": ["你病倒在一间没有窗的屋子里。外面的事，再也与你无关。"]},
        "blockade": {"title": "检察署的马车", "body": ["一辆没有标记的马车停在门口。车夫在等一道命令：去伊夫堡。这一次，登记簿上写的是你的名字。"]},
    },
    "endings": [
        {"id": "m_name", "when": {"flags": ["m_shield_gerard"]}},
        {"id": "m_wait_hope", "when": {"flags": ["m_mercy_choice", "m_valentine_saved"], "metric": {"morale": [">=", 50]}}},
        {"id": "m_full_ledger", "when": {"flags": ["m_vengeance_choice", "m_gerard_exposed", "m_morcerf_fallen", "m_danglars_ruined"], "metric": {"exploration": [">=", 100]}}},
    ],
    "default_ending": "m_count",
    "exclusive_flags": [["m_bargain", "m_threatened_gerard"], ["m_mercy_choice", "m_vengeance_choice", "m_shield_gerard"],
                        ["m_stay_marseille", "m_gerard_patron", "m_exile_genoa"], ["m_faria_lives", "m_faria_dead"]],
    "actions": {
        "_doc": "本段：工事 = 地道（只在第二章开）；测绘 = 卷宗（第四、五章开，复仇要靠证据）。征发在马赛更贵：追缉 +15。",
        "visit_town": {"cost": 100, "effects": {"vitality": 4, "morale": 2}},
        "visit_backdoor": {"effects": {"heat": -8}, "coins": {"intel": 1}},
        "trade_fair": {"effects": {"treasury": 200}},
        "trade_counterfeit": {"effects": {"treasury": 500, "heat": 15}, "flags": ["m_smuggled"]},
        "build": {"metric": "construction", "chapters": ["if_years"], "cost": 250, "gain": 20},
        "explore": {"metric": "exploration", "chapters": ["mediterranean", "paris_1838"], "cost": 300, "gain": 15},
        "fund": {"chapters": []},
    },
}

BIG_FATE_EXTRA = [
    {"id": "m_cell_35", "label": "关进伊夫堡 35 号", "when": {"not_flags": ["m_prisoner_35"]},
     "desc": "你被宪兵带走（逮捕）。一年以后，莫雷尔替你担保，你才从 35 号出来——隔壁就是 34 号。",
     "effects": {"vitality": -20, "morale": -8, "heat": -40, "construction": 15}, "flags": ["m_prisoner_35"]},
]

GAUGES = {"treasury": "经费", "morale": "人心", "heat": "追缉", "vitality": "体力", "construction": "地道", "exploration": "卷宗"}

DESIGN_NOTES = [
    "伊夫堡分支的主角不坐牢（除非大命运），他在墙外：军需官的老本行让他拿到伊夫堡的面包合同，于是能进地牢的厨房。",
    "主线张力是姓氏：揭发杰拉尔，就是亲手毁掉维尔福这个姓。三个固定结局分别是慈悲、清算、保姓。",
    "法利亚的药是唯一的架空岔口：救下他，他就和唐泰斯一起出逃，成为第三章起的伙伴（一条命）。",
    "唐泰斯、法利亚、莫雷尔与远洋段同 id、同战斗数值；性格一致（唐泰斯先是热血的水手，出狱后冷而准；法利亚博学而温和）。",
    "人物与情节全部取自大仲马原著（1844—1846，公有领域）；本分支自己的部分（主角、面包合同、法利亚活下来、司法宫之夜）都标了出来。",
]
