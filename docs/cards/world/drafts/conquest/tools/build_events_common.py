#!/usr/bin/env python3
"""Writes data/campaigns/napoleon/events_common.json: interlude events (ARCH §2.8 R6, pool "interlude:<type>")
for the trunk and 鹰飞 chapters, plus two book-wide random events.
`chapters` (optional, new) limits where an interlude may be drawn; without it the event can play anywhere.
`rogue.trust` = {"pick": 2, "gain": 1}: the player picks two living companions, each pair trust +1.
Run:  python3 -I tools/build_events_common.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from trunk_additions import event, ch, ap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "campaigns", "napoleon", "events_common.json")

def inter(eid, typ, chapters, title, location, speaker, body, choices, appraisals=(), requires=None):
    e = event(eid, "interlude:" + typ, title, location, speaker, body, choices, appraisals, weight=3, once=True, requires=requires)
    if chapters:
        e["chapters"] = chapters
    if eid in ("ib_fireside", "ic_rain_bivouac", "im_cipher_dispatch"):
        e["once"] = False
    return e

EVENTS = [
    # ---------- audience 皇帝召见
    inter("ia_carnot", "audience", ["italy"], "卡尔诺的办公室", "巴黎·卢森堡宫", "villefort", [
        "1796 年 2 月，巴黎，卢森堡宫。督政卡尔诺的桌上摊着意大利军团的军需报表，每一页都是红字。",
        "卡尔诺：“有人推荐你去意大利，说你在土伦数过火药桶。我只问一句：那支军团缺的是钱，还是将军？”"],
        [ch("needs_money", "“钱。将军有了，钱没有。”", {"treasury": 300}, [], {"coins": {"gold": 1}}),
         ch("needs_general", "“将军。有了对的将军，钱会自己来。”", {"morale": 3}, ["t_carnot_general"], {"coins": {"medal": 1}})]),
    inter("ia_berthier", "audience", ["iberia_danube"], "贝尔蒂埃的两个问题", "巴黎·战争部", "napoleon", [
        "1808 年春，战争部。参谋长贝尔蒂埃一边写字一边问话，从来不抬头。",
        "贝尔蒂埃：“第一，从巴约讷到马德里要几天？第二，路上的井，有几口是我们的？”"],
        [ch("days_answer", "“十九天。井，一口也不是。”", {"morale": -1}, ["t_berthier_truth"], {"coins": {"intel": 2}}),
         ch("optimist_answer", "“十二天。到处都有水。”", {"morale": 2, "heat": 3}, [], {"coins": {"medal": 1}})]),
    inter("ia_inconstant", "audience", ["hundred_days"], "不屈号的甲板", "地中海·不屈号", "napoleon", [
        "1815 年 2 月 27 日，海上。一条法国巡航舰从旁边驶过，船上的人隔着海喊：“皇帝身体好吗？”",
        "皇帝自己回答：“很好。”他转过身问你：“到了巴黎，第一笔钱花在哪里？”"],
        [ch("pay_the_army", "“发饷。”", {"morale": 3}, [], {"coins": {"gold": 1}}),
         ch("pay_the_debts", "“还债。先把厄尔巴欠的账还清。”", {"heat": -5}, ["k_elba_debts"], {"coins": {"medal": 1}})]),
    inter("ia_boulogne_1817", "audience", ["iberia_channel"], "皇帝的木屋", "布洛涅·海边的木屋", "napoleon", [
        "1817 年冬，布洛涅。木屋里只有一张桌子、一只火炉和一张英格兰地图。",
        "拿破仑：“维尔福，你恨英国人吗？”"],
        [ch("no_hate", "“我只恨他们的封锁。”", {"heat": -3}, [], {"coins": {"intel": 1}}),
         ch("yes_hate", "“他们烧过土伦的船。”", {"morale": 3}, [], {"coins": {"medal": 1}})]),
    # ---------- bond 营火夜话
    inter("ib_fireside", "bond", None, "营火夜话", "宿营地", "villefort", [
        "夜里，营火旁边只剩几个人。有人在补靴子，有人在擦枪，有人在说家乡的事。",
        "你把账簿合上，坐了过去。"],
        [ch("listen", "听他们说", {"morale": 2}, [], {"trust": {"pick": 2, "gain": 1}}),
         ch("tell_a_story", "讲土伦那一夜", {"morale": 3}, [], {"trust": {"pick": 2, "gain": 1}})]),
    inter("ib_baptiste_marie", "bond", None, "工兵和女商贩", "宿营地·玛丽的酒桶车", "marie", [
        "巴蒂斯特在修玛丽的酒桶车，修了一个晚上，车轮早就修好了，他还在修。",
        "玛丽：“维尔福，你是管账的。你说，一个工兵中士，养得起一辆酒桶车吗？”"],
        [ch("yes_he_can", "“养得起。我替他做保。”", {"morale": 4}, ["t_baptiste_marie"], {"trust": {"pair": ["baptiste", "marie"], "gain": 1}}),
         ch("ask_him", "“你该去问他。”", {"morale": 2}, [], {"trust": {"pair": ["baptiste", "marie"], "gain": 1}})],
        requires={"alive": ["baptiste", "marie"]}),
    inter("ib_lannes_murat", "bond", ["orient_alps", "austerlitz_jena", "iberia_danube"], "两个人的功劳", "司令部门外", "lannes", [
        "拉纳和缪拉在司令部门口吵起来了，为的是谁先冲进了哪个村子。",
        "拉纳：“维尔福，你的账簿上写的是谁？”"],
        [ch("write_both", "两个人的名字都写上", {"morale": 2}, [], {"trust": {"pair": ["lannes", "murat"], "gain": 1}}),
         ch("write_the_dead", "“写的是死在村口的那些人。”", {"morale": -1, "heat": -3}, ["t_ledger_dead"], {"coins": {"medal": 1}})],
        requires={"alive": ["lannes", "murat"]}),
    # ---------- camp night 野营夜
    inter("ic_rain_bivouac", "camp_night", None, "雨夜宿营", "路边的树林", "villefort", [
        "雨下了一整天。帐篷不够，大半的人睡在大车底下。",
        "天亮以前，你只能做一件事。"],
        [ch("dry_powder", "把火药搬进教堂，弹药不受潮", {}, [], {"coins": {"supply": 2}}),
         ch("hot_soup", "烧热汤，挨个发", {"vitality": 6, "treasury": -60}, [], {}),
         ch("tend_wounded", "陪军医看伤员", {"morale": 2}, [], {"heal": 20})]),
    inter("ic_snow_bivouac", "camp_night", ["russia", "niemen"], "雪夜", "雪地里的宿营地", "villefort", [
        "夜里零下二十度。有人把马鞍烧了取暖，有人把枪托烧了。",
        "到早上，总有几堆营火旁边的人没有再起来。"],
        [ch("keep_fires", "一整夜挨个营火去看，把睡着的人叫醒", {"vitality": 4, "morale": -1}, [], {}),
         ch("burn_wagons", "烧两辆空车", {"vitality": 6}, [], {"coins": {"supply": -1}}),
         ch("count_names", "把名字记下来", {"morale": 2}, ["t_snow_names"], {"coins": {"medal": 1}})]),
    inter("ic_harbour_night", "camp_night", ["rhine", "last_coalition"], "最后一夜的营地", "宿营地", "villefort", [
        "明天就要开拔。营里很静，只有马在嚼草料。",
        "小皮埃尔的鼓放在你的帐篷门口。"],
        [ch("write_letters", "替不识字的兵写家信", {"morale": 3}, [], {}),
         ch("inspect_wagons", "最后查一遍车队", {}, [], {"coins": {"supply": 2}}),
         ch("sleep", "睡一觉", {"vitality": 6}, [], {})]),
    # ---------- minigames 查验插曲
    inter("im_cipher_dispatch", "minigame:decode", None, "截获的密信", "司令部", "gourgaud", [
        "前哨截住了一个信使，身上缝着一封用数字写的信。",
        "古尔戈：“参谋部的人都去前线了。你会解这种东西吗？”"],
        [ch("read_it", "照解出来的内容报告", {}, [], {"coins": {"intel": 3}}, requires_clues=["number_key"]),
         ch("send_it_on", "原样送去参谋部", {}, [], {"coins": {"intel": 1}})],
        [ap("number_key", "decode", "破译数字", "每个数字是同一本祈祷书的页码和行数。信里说的是下一批援军的路线。")]),
    inter("im_tsar_letter", "minigame:decode", ["niemen"], "沙皇的回信", "华沙·王宫", "napoleon", [
        "亚历山大沙皇回信了。法文写得很漂亮，可最后一段是另一个人的笔迹。",
        "拿破仑：“维尔福，你看看，这一段是谁加的？”"],
        [ch("found_hand", "“是英国使馆的人加的。”", {"heat": -4}, ["k_tsar_forgery"], {"coins": {"intel": 2}}, requires_clues=["second_hand"]),
         ch("no_idea", "“看不出来，陛下。”", {}, [], {})],
        [ap("second_hand", "decode", "对比两段笔迹", "最后一段的 t 横得很长，是英国学校教出来的写法。")]),
    inter("iw_elba_iron", "minigame:weigh", ["elba"], "铁矿石", "里奥铁矿的码头", "drouot", [
        "里奥铁矿的船要装去热那亚。码头上堆着一千担矿石，每一担都要过秤。",
        "德鲁奥：“去年的账上，这个码头每年少三成。”"],
        [ch("weigh_all", "照实过秤，按实数收税", {"treasury": 200, "heat": 3}, [], {}, requires_clues=["ore_weight"]),
         ch("sample_only", "抽十担称一称", {"treasury": 80}, [], {})],
        [ap("ore_weight", "weigh", "过秤一担矿石", "秤砣被锉过，每担轻了二十斤。")]),
    # ---------- book-wide random events
    event("ev_deserter_pardon", "common", "逃兵的母亲", "路边的村子", "villefort", [
        "一个老妇人拦住车队，手里拿着儿子的军帽：“他回家看我，才算逃兵的。”"],
        [ch("pardon", "替他写一张归队证明", {"morale": 2, "heat": -2}, [], {}),
         ch("report", "照章上报", {}, [], {"coins": {"medal": 1}})], weight=2, once=False),
    event("ev_counterfeit_assignats", "common", "假钞", "集市", "corso", [
        "集市上流着一种新钞票，印得太好了，比真的还好。",
        "科尔索：“英国人印的。他们印假钞，比造船还勤快。”"],
        [ch("burn_them", "收上来烧掉", {"treasury": -100, "heat": -4}, [], {"coins": {"intel": 1}}),
         ch("spend_abroad", "带到边境外面去花", {"treasury": 200, "heat": 4}, ["t_spent_fakes"], {})], weight=2, once=True),
]

def main():
    d = {"version": 1,
         "_doc": "草稿（标签 conquest）：全书通用事件池（ARCH §2.6 第三层）与幕间插曲（§2.8 R6）。interlude:<类型> 只在 year_jump 阶段抽；chapters 限定能出现在哪几章（进入这一章时播）。形状同场景事件，禁止 branch/advance/ending。",
         "events": EVENTS}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("events_common:", len(EVENTS))

if __name__ == "__main__":
    main()
