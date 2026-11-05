#!/usr/bin/env python3
"""Adds the second-pass trunk content to data/campaigns/napoleon/trunk.json (idempotent):
11 council events (R5, boss_mod), 8 fixed map events, 7 pool events for the condensed acts,
and three small text fixes so slot/fixed events sit where the map puts them.
Run:  python3 -I tools/trunk_additions.py"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "data", "campaigns", "napoleon", "trunk.json")

def council(eid, date, location, speaker, title, body, a, b, c):
    """a/b/c = (label, extra dict). a -> cp_bonus 2, b -> enemy_morale -2, c -> prep_turn 1."""
    ch = []
    for (cid, label, extra), mod in zip((a, b, c), ({"cp_bonus": 2}, {"enemy_morale": -2}, {"prep_turn": 1})):
        d = {"id": cid, "label": label, "effects": {}, "flags": [], "rogue": {}, "boss_mod": mod}
        for k, v in extra.items():
            d[k] = v
        ch.append(d)
    return {"id": eid, "pool": "fixed", "council": True, "weight": 0, "once": True, "requires": {},
            "title": title, "location": location, "speaker": speaker, "date": date, "body": body,
            "appraisals": [], "choices": ch}

def event(eid, pool, title, location, speaker, body, choices, appraisals=(), weight=3, once=True, requires=None, date=None, note=None):
    e = {"id": eid, "pool": pool, "weight": weight, "once": once, "requires": requires or {}, "title": title,
         "location": location, "speaker": speaker}
    if date: e["date"] = date
    e["body"] = body
    e["appraisals"] = list(appraisals)
    e["choices"] = choices
    if note: e["_note"] = note
    return e

def ch(cid, label, effects=None, flags=None, rogue=None, **kw):
    d = {"id": cid, "label": label}
    d.update(kw)
    d["effects"] = effects or {}
    d["flags"] = flags or []
    d["rogue"] = rogue or {}
    return d

def ap(aid, kind, label, observation):
    return {"id": aid, "kind": kind, "label": label, "observation": observation}

COUNCILS = [
    council("ev_council_toulon", "1793-12-11", "奥利乌勒·围城司令部", "bonaparte", "杜戈米埃的军议", [
        "围城司令部里点着两支蜡烛。杜戈米埃将军、萨利切蒂特派员和几位师长围着桌上的地图。",
        "波拿巴：“别去碰城墙。先拿凯尔高地上的小直布罗陀，港里的英国舰队自己就待不住了。”",
        "杜戈米埃：“那就定在十七日夜里。军需官，你说说，我们还缺什么？”"],
        ("more_powder", "多拉两车干火药上山（开场军令点 +2）", {"effects": {"treasury": -100}}),
        ("false_target", "让科尔索去城下放风：主攻在马尔布斯克堡（敌军心 −2）", {"effects": {"heat": 2}}),
        ("guns_by_night", "趁天黑先把炮拖到坡下（多一回合布阵）", {"effects": {"vitality": -3}})),
    council("ev_council_italy", "1796-11-14", "维罗纳·司令部", "bonaparte", "维罗纳军议", [
        "1796 年 11 月，维罗纳。阿尔文齐的奥军第三次来解曼托瓦之围，这个冬天不会太平。",
        "波拿巴：“他们人多，我们腿快。阿迪杰河两岸的路，谁先走完谁赢。”",
        "马塞纳的师在里沃利，奥热罗的师在维罗纳。中间只有你的车队在跑。"],
        ("empty_verona", "把维罗纳仓库搬空，弹药全往前送（开场军令点 +2）", {"rogue": {"coins": {"supply": -1}}}),
        ("false_bridge", "在阿迪杰河上搭一座假桥，让奥军以为我们要撤（敌军心 −2）", {"effects": {"construction": 5}}),
        ("dike_march", "夜里沿河堤走，比奥军早半天到位（多一回合布阵）", {"effects": {"vitality": -4}})),
    council("ev_council_acre", "1799-03-18", "凯撒利亚·海边的营帐", "bonaparte", "凯撒利亚军议", [
        "1799 年 3 月，凯撒利亚。从亚历山大港走海路的攻城炮，在半路被西德尼·史密斯的船截走了。",
        "拉雷：“雅法回来的兵里已经有人发烧。再往北走，病会跟着我们走。”",
        "波拿巴：“阿卡是叙利亚的钥匙。维尔福，拿野战炮当攻城炮，弹药够打几天？”"],
        ("pool_shells", "把野战炮的炮弹全部集中给攻城队（开场军令点 +2）", {"rogue": {"coins": {"supply": -2}}}),
        ("plague_rumour", "让城里的人相信瘟疫已经进了城（敌军心 −2）", {"effects": {"heat": 4}}),
        ("dig_saps", "先挖坑道，挖到城墙脚下再打（多一回合布阵）", {"effects": {"vitality": -4, "construction": 10}})),
    council("ev_council_marengo", "1800-06-13", "沃盖拉·驿站", "bonaparte", "沃盖拉军议", [
        "1800 年 6 月 13 日，沃盖拉。梅拉斯的奥军缩回了亚历山德里亚，谁也不知道他明天往哪边走。",
        "波拿巴：“德塞，你带一个师往南，去诺维看住他。”",
        "德塞看了你一眼。他的师走了，平原上就只剩下一半的人。"],
        ("milan_wagons", "把米兰的弹药车全调上来（开场军令点 +2）", {"effects": {"treasury": -150}}),
        ("false_fires", "派骑兵在斯克里维亚河边点一排假营火（敌军心 −2）", {"rogue": {"coins": {"intel": -1}}}),
        ("keep_desaix_close", "替德塞备好回程的马，让他别走太远（多一回合布阵）", {"effects": {}, "flags": ["t_desaix_close"]})),
    council("ev_council_austerlitz", "1805-11-28", "布吕恩·皇帝的营帐", "napoleon", "布吕恩军议", [
        "1805 年 11 月 28 日，布吕恩。离家一千公里，冬天快来了，俄奥联军比我们多两万人。",
        "拿破仑：“我要把普拉岑高地让出来。让他们以为我怕了，让他们从高地上下来打我的右翼。”",
        "拿破仑：“维尔福，右翼要撑一整个上午。面包和弹药，放在他们够得着的地方。”"],
        ("santon_stores", "把面包和弹药都囤在桑顿山后面（开场军令点 +2）", {"rogue": {"coins": {"supply": -1}}}),
        ("feigned_fear", "陪萨瓦里去联军营里谈判，装出害怕的样子（敌军心 −2）", {"rogue": {"coins": {"intel": -1}}}),
        ("davout_forced", "给达武的第三军沿路备好面包，让他们连夜赶来（多一回合布阵）", {"effects": {"treasury": -200}})),
    council("ev_council_eylau", "1807-02-06", "奥斯特罗德·冻住的磨坊", "napoleon", "奥斯特罗德军议", [
        "1807 年 2 月，东普鲁士。雪下了十天，路面是冻住的泥。贝尼希森的俄军在前面退，退得很慢。",
        "拿破仑：“他想让我在冬天追他。好，那就追。”",
        "缪拉：“马快饿死了。陛下要骑兵去冲，得先让马吃饱。”"],
        ("warsaw_carts", "把华沙的粮车全部发往前线（开场军令点 +2）", {"effects": {"treasury": -200}}),
        ("cavalry_everywhere", "让缪拉的骑兵在雪里到处露面（敌军心 −2）", {"effects": {"vitality": -3}}),
        ("wait_for_ney", "等奈伊的军赶到再打（多一回合布阵）", {"effects": {"morale": -2}})),
    council("ev_council_saragossa", "1809-01-22", "阿拉贡·工兵指挥所", "lannes", "阿拉贡军议", [
        "1809 年 1 月，萨拉戈萨城外。城墙已经破了，可每一条街还在打。",
        "拉纳：“我不想把这座城一间一间炸平。可巴黎要的是一份捷报。”",
        "巴蒂斯特：“地道挖到圣恩格拉西亚修道院底下，要五天。火药要四十桶。”"],
        ("all_the_powder", "把工兵的炸药全部调来（开场军令点 +2）", {"rogue": {"coins": {"supply": -2}}}),
        ("surrender_leaflets", "往城里射劝降书，许诺保住平民（敌军心 −2）", {"effects": {"heat": -4}}),
        ("tunnel_first", "先把地道挖到修道院底下（多一回合布阵）", {"effects": {"vitality": -4, "construction": 10}})),
    council("ev_council_wagram", "1809-07-04", "凯泽埃伯斯多夫·皇帝的营帐", "napoleon", "埃伯斯多夫军议", [
        "1809 年 7 月 4 日，多瑙河。五月在阿斯佩恩，桥被冲断过一次。",
        "拿破仑：“这一次，六座桥，一百门炮。卡尔大公在对岸等着，我要他等错地方。”",
        "工兵报告：洛鲍岛上的浮舟够了，锚还缺一百二十只。"],
        ("hundred_guns", "一百门炮的弹药先运上洛鲍岛（开场军令点 +2）", {"effects": {"treasury": -200}}),
        ("feint_at_aspern", "在阿斯佩恩那边假装搭桥（敌军心 −2）", {"effects": {"construction": 5}}),
        ("cross_in_storm", "趁雷雨夜提前过河（多一回合布阵）", {"effects": {"vitality": -5}})),
    council("ev_council_retreat", "1812-10-25", "小雅罗斯拉韦茨·烧掉一半的教堂", "napoleon", "小雅罗斯拉韦茨军议", [
        "1812 年 10 月 25 日。一个月前，莫斯科烧了四天。现在城里只剩烟囱。",
        "库图佐夫堵住了南边的新路。往南，要再打一仗；往北，是来时那条烧光的老路。",
        "拿破仑：“维尔福，老路上还有什么？”",
        "维尔福：“斯摩棱斯克还有半个月的面粉，如果没被人吃掉的话。”"],
        ("horses_to_guns", "把剩下的马全部套上炮车（开场军令点 +2）", {"effects": {"vitality": -4}}),
        ("burn_the_baggage", "烧掉带不走的辎重，轻装走（敌军心 −2）", {"effects": {"treasury": -300, "morale": 2}}),
        ("eble_ahead", "让埃布莱带工具车先走，提前到别列津纳河（多一回合布阵）", {"effects": {}, "flags": ["t_eble_ahead"]})),
    council("ev_council_leipzig", "1813-10-15", "艾伦堡·邮驿站", "napoleon", "艾伦堡军议", [
        "1813 年 10 月，萨克森。普鲁士、俄国、奥地利、瑞典四路大军在往莱比锡收拢。",
        "拿破仑：“他们一共三十万，我们十九万。我要在他们会齐以前，先打掉一个。”",
        "玛丽：“萨克森兵在私下议论，说下个月就不给咱们打了。”"],
        ("torgau_ammo", "把托尔高要塞的弹药全部调来（开场军令点 +2）", {"rogue": {"coins": {"supply": -2}}}),
        ("pay_the_saxons", "去萨克森军团营地补发两个月的饷（敌军心 −2）", {"effects": {"treasury": -300}}),
        ("marmont_night", "让马尔蒙的军连夜进村，先挖好工事（多一回合布阵）", {"effects": {"vitality": -3, "construction": 10}})),
    council("ev_council_elba", "1815-02-24", "费拉约港·法尔科内堡", "drouot", "法尔科内堡军议", [
        "1815 年 2 月 24 日，法尔科内堡。从炮台上看得见整个港湾和港外的海。",
        "德鲁奥：“私掠船今夜会来，目标是码头仓库。他们以为近卫营在山上的营房里睡觉。”",
        "康布罗纳：“那就让他们以为对了。”"],
        ("bullets_to_quay", "把近卫营的子弹从星堡搬到码头（开场军令点 +2）", {"rogue": {"coins": {"supply": -1}}}),
        ("three_false_lights", "在港外点三盏假灯，把私掠船引向暗礁（敌军心 −2）", {"rogue": {"coins": {"intel": -1}}}),
        ("fishermen_watch", "让渔民提前出海放哨（多一回合布阵）", {"effects": {"treasury": -80}})),
]

FIXED = [
    event("ev_malta_silver", "fixed", "骑士团的银库", "马耳他·瓦莱塔·圣约翰大教堂", "bonaparte", [
        "1798 年 6 月，马耳他。圣约翰骑士团几乎没抵抗就开了城门。",
        "波拿巴：“骑士团的银器、教堂的烛台，全部熔成银锭，带去埃及发饷。”",
        "大教堂的侧廊里有一扇大门，通体刷着黑漆。看守的老修士站在门前，一句话也不说。"],
        [ch("melt_everything", "照命令全部熔掉", {"treasury": 600, "heat": 6}, ["t_malta_melted"], {"coins": {"gold": 1}}),
         ch("ledger_and_ship", "登记造册，原样装船运走", {"treasury": 300}, ["t_malta_listed"], {"coins": {"medal": 1}}),
         ch("leave_the_gate", "那扇黑门不在清单上，留给老修士", {"morale": 2, "heat": -4}, ["t_malta_gate"], {}, requires_clues=["black_gate"])],
        [ap("black_gate", "spot", "细看那扇刷了黑漆的门", "漆底下透出一点银光：整扇门是纯银的，有人连夜把它刷黑了。")],
        date="1798-06-12", note="银门涂黑躲过熔铸是马耳他流传的说法，这里当传说用，不当史实写。"),
    event("ev_st_bernard", "fixed", "山口上的修道院", "大圣伯纳德山口·济贫院", "baptiste", [
        "1800 年 5 月，大圣伯纳德山口，海拔两千四百米。后备军团要从这里把大炮拖进意大利。",
        "修道院的修士在路边摆了桌子，给每一个经过的兵一块面包、一块奶酪、一杯酒。四万人，一个也没漏。",
        "巴蒂斯特：“炮车过不去。炮管得卸下来，在雪里拖。”"],
        [ch("pay_the_monks", "按市价给修道院付现钱", {"treasury": -200, "morale": 4}, ["t_bernard_paid"], {}),
         ch("army_voucher", "开一张军需凭单，写明法兰西欠修道院的账", {"morale": 2}, ["t_bernard_voucher"], {"coins": {"medal": 1}}),
         ch("hollow_logs", "把炮管装进掏空的松树干，一百人拖一根", {"vitality": 4}, ["t_hollow_logs"], {"coins": {"supply": 2}}, requires_clues=["pine_trunk"])],
        [ap("pine_trunk", "weigh", "掂一掂修士们劈开的松树干", "树干掏空以后，正好能装下一根四磅炮的炮管，像雪橇一样在雪上滑。")],
        date="1800-05-20", note="史实里拿破仑确实欠下济贫院一笔账，几十年后才由法国政府偿付。"),
    event("ev_ulm_prisoners", "fixed", "两万七千个俘虏", "奥格斯堡·城外的草场", "villefort", [
        "1805 年 10 月，乌尔姆投降了。马克将军带着两万七千人放下了武器。",
        "他们从奥格斯堡城外走过，一眼望不到头。每个人都要吃饭。",
        "军需处的面包只够我们自己的兵吃到维也纳。"],
        [ch("feed_like_ours", "按我们自己的兵发口粮", {"treasury": -300, "morale": 2, "heat": -5}, ["t_ulm_fed"], {}),
         ch("half_ration", "发半份，赶快押去法国", {"heat": 3}, [], {"coins": {"supply": 2}}),
         ch("labour_gangs", "编成工程队，修路换饭吃", {"treasury": 200, "construction": 10}, ["t_ulm_labour"], {}, requires_clues=["prisoner_count"])],
        [ap("prisoner_count", "decode", "核对投降名册", "名册上有四千多个工兵和车夫：他们会修路，也会赶车。")],
        date="1805-10-22"),
    event("ev_frederick_sword", "fixed", "腓特烈大王的佩剑", "柏林·王宫的军械室", "napoleon", [
        "1806 年 10 月，柏林。皇帝在波茨坦的驻军教堂里，在腓特烈大王的墓前站了很久。",
        "拿破仑：“他的佩剑、腰带和勋章，送到荣军院去。”",
        "装箱的单子交到你手里。普鲁士的老侍从站在门口，帽子拿在手上。"],
        [ch("crate_with_honour", "照命令装箱，单独押运", {"morale": 2}, ["t_sword_taken"], {"coins": {"medal": 1}}),
         ch("mark_the_origin", "在清单上写明它从哪座教堂来、属于谁", {}, ["t_sword_marked", "t_return_mark"], {"coins": {"intel": 1}}, requires_clues=["old_servant"]),
         ch("leave_the_sash", "只带走佩剑，把腰带留给老侍从", {"heat": -5}, ["t_sash_left"], {})],
        [ap("old_servant", "spot", "留意门口的老侍从", "他胸前别着一枚旧勋章：七年战争时跟大王打过仗。他在等，不是在看。")],
        date="1806-10-27"),
    event("ev_dos_de_mayo", "fixed", "五月三日之后", "马德里·丽池宫的粮仓", "villefort", [
        "1808 年 12 月，马德里。五月二日的起义，五月三日的枪决，城里的人都还记得。",
        "皇帝进城了。丽池宫的粮仓里堆着够全城吃一个月的小麦，门口是排队买面包的人。",
        "军需处的命令只有一句：粮仓归大军。"],
        [ch("open_to_city", "开仓平价卖给城里", {"treasury": -200, "heat": -10}, ["t_madrid_bread"], {}),
         ch("sell_at_market", "按黑市价卖出去", {"treasury": 400, "heat": 10}, ["t_madrid_sold"], {"coins": {"gold": 1}}),
         ch("army_only", "照命令，全部装车给大军", {}, [], {"coins": {"supply": 3}})],
        date="1808-12-04"),
    event("ev_ratisbon_wound", "fixed", "皇帝的脚踝", "雷根斯堡城外", "napoleon", [
        "1809 年 4 月 23 日，雷根斯堡城外。一颗打到尽头的子弹落在皇帝的右脚踝上。",
        "拿破仑：“这么远都打得中，只能是蒂罗尔的猎手。”他咬着牙，脸色发白。",
        "城下的兵已经有人在喊：皇帝中弹了。"],
        [ch("ride_the_lines", "扶皇帝上马，从队伍前面骑过去", {"morale": 6, "vitality": -2}, ["t_ratisbon_ride"], {"coins": {"medal": 1}}),
         ch("keep_it_quiet", "封住消息，先包扎", {"heat": -2}, [], {"coins": {"intel": 1}}),
         ch("call_larrey", "去找拉雷", {"vitality": 4, "morale": 2}, ["t_larrey_ankle"], {}, requires={"alive": ["larrey"]})],
        date="1809-04-23", note="史实：拿破仑一生唯一一次在战场上负伤。"),
    event("ev_smolensk_granary", "fixed", "斯摩棱斯克的粮仓", "斯摩棱斯克·第聂伯河边", "villefort", [
        "1812 年 8 月，斯摩棱斯克。俄军走的时候放了火，整座城还在烧。",
        "河边有一座石头粮仓，屋顶已经着了，门还锁着。",
        "古尔戈：“里面的东西够两个师吃十天。再过一个钟头，什么都不剩了。”"],
        [ch("save_the_grain", "带人上去灭火，抢粮", {"vitality": -4}, ["t_smolensk_grain"], {"coins": {"supply": 5}}),
         ch("let_it_burn", "不值得拿人去换，继续往前走", {"morale": -2}, [], {}),
         ch("mark_for_return", "记下粮仓的位置，回来的路上用", {"construction": 10}, ["t_smolensk_depot"], {"coins": {"supply": 2}}, requires_clues=["stone_roof"])],
        [ap("stone_roof", "spot", "看清粮仓的结构", "屋顶是木头的，墙和地窖是石头的。地窖里的面粉烧不到。")],
        date="1812-08-18"),
    event("ev_six_days", "fixed", "六日战役", "香槟·蒙米赖", "napoleon", [
        "1814 年 2 月，香槟。联军打进了法国。皇帝带着几万个新兵，六天里打了四仗，赢了四仗。",
        "村里的农民把面包和葡萄酒送到路边，说：“打完这一仗，就回家吧。”",
        "拿破仑：“维尔福，还能打几天？”"],
        [ch("one_more_week", "“还有一个星期的子弹。”", {"morale": 4, "vitality": -4}, ["t_six_days"], {"coins": {"medal": 1}}),
         ch("pay_the_farmers", "替大军把农民的面包钱付了", {"treasury": -150, "heat": -8}, ["t_champagne_paid"], {}),
         ch("tell_the_truth", "“一天也不能了，陛下。”", {"morale": -2}, ["t_told_truth_1814"], {"coins": {"intel": 1}})],
        date="1814-02-11"),
]

POOL = [
    event("ev_scholars_crates", "orient", "学者的箱子", "沙漠里的行军路", "villefort", [
        "学者委员会的箱子装着仪器、标本和刚拓下来的碑文，一共四十只，要八头骆驼。",
        "骆驼不够驮水了。蒙日教授抱着一只箱子不撒手：“这里面是三千年。”"],
        [ch("water_first", "先驮水", {"vitality": 4}, [], {}),
         ch("crates_first", "先驮箱子，人少喝一口", {"vitality": -3, "morale": 1}, ["t_crates_saved"], {"coins": {"intel": 1}})]),
    event("ev_alps_mules", "alps", "骡夫罢工", "圣皮埃尔村", "villefort", [
        "山脚下的圣皮埃尔村，三百个骡夫坐在路边不走了：说好的工钱还没给。",
        "骡夫头子：“炮你们自己扛上去吧。”"],
        [ch("pay_in_cash", "当场付现钱", {"treasury": -150}, [], {"coins": {"supply": 2}}),
         ch("pay_double_later", "开凭单，到米兰付双倍", {"morale": -1}, ["t_mule_voucher"], {"coins": {"supply": 2}}),
         ch("conscript_mules", "征用骡子，骡夫押着走", {"heat": 8}, [], {"coins": {"supply": 3}})]),
    event("ev_bread_ovens", "north", "路上的面包炉", "行军路旁的村庄", "villefort", [
        "前一站的面包炉连夜烤了九千个面包，车队却晚到了半天，面包在路边放凉了。",
        "后面一个军的兵正在赶上来，前面一个军的兵正在饿着走。"],
        [ch("forward_corps", "先给前面的军", {"morale": 2}, [], {"coins": {"supply": 1}}),
         ch("rear_corps", "留给后面的军", {"vitality": 3}, [], {}),
         ch("split_and_bake", "对半分，再借村里的炉子烤一批", {"treasury": -80, "morale": 2, "vitality": 2}, ["t_village_ovens"], {})]),
    event("ev_poisoned_well", "iberia", "井", "卡斯蒂利亚的一个村子", "marie", [
        "村里的人全跑光了。井口边上放着一只水桶，桶底有一层白粉。",
        "玛丽：“兵已经渴了一天，看见井就要往下扑。”"],
        [ch("guard_the_well", "派人守井，等后面的水车", {"vitality": -3}, [], {}),
         ch("test_it", "先拿死驴子试一试", {}, ["t_well_tested"], {"coins": {"intel": 1}}, requires_clues=["white_powder"]),
         ch("burn_the_village", "照命令烧村子", {"heat": 15}, ["t_village_burned"], {"coins": {"supply": 2}})],
        [ap("white_powder", "spot", "细看桶底的白粉", "是石灰，不是砒霜。有人想吓住你们，不想毒死你们。")]),
    event("ev_danube_pontoons", "danube", "浮舟被冲走了", "多瑙河边", "baptiste", [
        "上游放下来一条着了火的驳船，撞断了三只浮舟的缆绳。",
        "巴蒂斯特：“剩下的锚不够了。要么去城里拆教堂的铁链，要么等新的从巴黎运来。”"],
        [ch("church_chains", "去拆教堂的铁链", {"heat": 6, "construction": 10}, [], {"coins": {"supply": 1}}),
         ch("wait_for_paris", "等巴黎的锚", {"vitality": -2}, [], {}),
         ch("boom_upstream", "在上游拦一道木栅", {"treasury": -120, "construction": 15}, ["t_danube_boom"], {})]),
    event("ev_horse_meat", "russia", "马", "斯摩棱斯克大道", "villefort", [
        "一夜之间冻死了四百匹马。路边的兵已经开始割马肉了。",
        "炮兵上尉：“马吃完了，炮就得扔在这里。”"],
        [ch("ration_the_horses", "按名册分马肉，每个连一匹", {"vitality": 6, "morale": -2}, [], {}),
         ch("save_for_guns", "先保拉炮的马，兵饿着", {"vitality": -4}, ["t_guns_kept"], {"coins": {"supply": 1}})]),
    event("ev_conscript_letter", "collapse", "新兵的信", "萨克森的宿营地", "pierre", [
        "一个十八岁的新兵托你寄一封信。信封上写着家乡的村名，信里只有一行字：“妈妈，我还活着。”",
        "小皮埃尔：“他不会写字，是我替他写的。他问能不能多写一句。”"],
        [ch("write_more", "让他多写一句", {"morale": 2}, [], {}),
         ch("post_free", "用军需处的驿马免费寄", {"treasury": -20, "morale": 3}, ["t_letters_free"], {})]),
]

FIXES = {
    ("events", "ev_morrel_grain", "location"): "萨纳里港·码头",
    ("events", "ev_morrel_grain", "body", 0): "萨纳里港，一条从马赛来的三桅商船刚靠岸，舱里是给围城军的小麦。",
    ("events", "ev_mysore_envoy", "pool"): "fixed",
    ("scenes", "elba_arrival", "body", 0): "1814 年 5 月 4 日，厄尔巴岛，费拉约港。皇帝从英国护卫舰“无畏号”上下来，岛上放了礼炮。跟来的人，有的和他同船，有的是后来自己找来的。",
}

def main():
    d = json.load(open(PATH, encoding="utf-8"))
    have = {e["id"] for e in d["events"]}
    for e in COUNCILS + FIXED + POOL:
        if e["id"] not in have:
            d["events"].append(e)
    for key, val in FIXES.items():
        coll = {x["id"]: x for x in d[key[0]]}[key[1]]
        if len(key) == 3:
            coll[key[2]] = val
        else:
            coll[key[2]][key[3]] = val
    for sc in d["scenes"]:
        if sc["chapter"] in ("orient_alps", "austerlitz_jena", "iberia_danube", "russia", "collapse"):
            sc["condensed"] = True
    if "cambronne" not in {c["id"] for c in d["characters"]}:
        d["characters"].append({"id": "cambronne", "name": "康布罗纳将军", "role": "厄尔巴近卫营营长；鹰飞段的伙伴（掷弹兵，宿命之地滑铁卢）"})
    notes = d["design_notes"]
    extra = "军议（pool=fixed、council=true）每章一场，三个抉择分别给 boss_mod：cp_bonus +2（开场军令点）、enemy_morale −2、prep_turn +1（第一波晚一回合到，回合上限同时 +1，守的回合数不变）。"
    if extra not in notes:
        notes.append(extra)
    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("trunk events:", len(d["events"]))

if __name__ == "__main__":
    main()
