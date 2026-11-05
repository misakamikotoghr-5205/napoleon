# -*- coding: utf-8 -*-
# Battle templates of the cristo branch that are PLANNED (B builds them in B2): size, scale, level, weather, terrain,
# objective, enemy roster, wave plan in words, and the A5 power target (each chapter boss >= previous boss x 112/100).
PLANNED = {
    "janina_lake": {
        "name": "约阿尼纳湖·湖心岛", "date": "1822-01-22", "node": "elite", "chapter": "if_years", "scale": "elite", "size": [9, 5], "level": 15, "turn_limit": 9,
        "weather": "fog", "terrain": ["W 湖面（敌方小船只能停在湖格）", "k 码头", "# 修道院墙", "B 修道院房屋", "R 屋顶", "C 回廊", ", 湖滩", "- 浅水"],
        "objective": {"type": "extract", "cell": "B3", "turns": 3, "desc": "把总督的妻女和三桶火药搬上小船（B3 码头站满 3 个回合）。", "fallback": {"type": "hold", "cell": "B3", "turn": 9}},
        "enemies": ["nizam", "arnaut", "bey", "ottoman_gun", "gunboat(湖上炮船)"],
        "plan": "苏丹的军队从对岸坐船来，三条小船停在湖格上分别从 3 个跳板登岸；阿尔瑙特枪手（skirmisher）打一枪退一格；雾天来敌只提前 1 回合公开。费尔南（不上阵）开门放进来的一队从修道院的门（D 格）里冒出来。",
        "power_target": None},
    "tiboulen_swim": {
        "name": "蒂布朗岛·暴风雨的黎明", "date": "1829-03-01", "node": "anchor", "chapter": "montecristo", "scale": "elite", "size": [9, 5], "level": 17, "turn_limit": 9,
        "weather": "storm", "terrain": ["W 海", "* 暗礁", "- 浅水（能走不能站）", ", 礁岛的小滩", "^ 礁石", "p 少年阿梅莉号的跳板", "d 甲板", "t 桅盘"],
        "objective": {"type": "escape", "unit": "dantes", "cells": ["B2", "B3"], "turn": 9, "desc": "唐泰斯第 9 回合结束时站在少年阿梅莉号的甲板上。", "fallback": {"type": "hold", "cell": "B3", "turn": 9}},
        "enemies": ["revenue_cutter", "gunboat", "customs", "gendarme(boarder)", "wall_sentry(伊夫堡方向的岸上哨兵)"],
        "plan": "我方在左边的帆船甲板上（A–C 列），唐泰斯从右边的礁岛出发（骠骑兵，开场在 H3），每回合只能沿浅水走 1 格（步耗 2）。两条缉私快艇从上下两侧的海格开炮，海关的长艇从跳板接舷。暴风雨：桅盘上的我方单位每回合 −1。",
        "power_target": None},
    "monte_cristo_cave": {
        "name": "基督山岛·斯帕达的洞", "date": "1829-05-24", "node": "boss", "chapter": "montecristo", "scale": "grand", "size": [10, 6], "level": 18, "turn_limit": 13,
        "weather": "clear", "terrain": ["c 洞穴（敌炮不瞄，挨远程防 +2，挡视线）", "_ 虚空（悬崖外）", "^ 岩顶", ", 沙滩", "- 浅水", "W 海", "p 跳板", "; 炸开的碎石"],
        "objective": {"type": "extract", "cell": "C3", "turns": 4, "desc": "三只箱子：C3 洞口我方有人站满 4 个回合（每满一回合搬出一箱，第 4 回合起每回合金币 +1）。", "fallback": {"type": "hold", "cell": "C3", "turn": 13}},
        "enemies": ["rival_smuggler_boss", "smuggler(stealth)", "pirate(loot)", "pirate_captain", "customs", "revenue_cutter", "gunboat"],
        "plan": "不规则地图：左上是藏宝洞（3×2 洞穴格，我方的鹰旗是洞口内侧的两格，箱子被抢就扣军心），右边是海湾。热那亚帮从岛顶的山羊小路下来（G 在岩顶，路线经过碎石，步耗 2），海盗从两个跳板接舷（loot：每个走进鹰旗的海盗战后法郎 −15%），第 6 回合海关的炮艇进湾。洞穴挡视线：洞里的横队只能打洞口一条直线。",
        "power_target": 710},
    "appian_way": {
        "name": "亚壁古道", "date": "1838-02-21", "node": "elite", "chapter": "mediterranean", "scale": "elite", "size": [10, 5], "level": 20, "turn_limit": 9,
        "weather": "night", "terrain": ["= 古道", "B 墓碑与陵墓（我方可进驻）", "K 墓穴入口（伏兵出生格）", "w 柏树林", "^ 引水渠的残墙", "_ 虚空"],
        "objective": {"type": "no_leak", "desc": "伯爵的马车（A3 鹰旗）不被拦下。"},
        "enemies": ["bandit(ambush)", "bandit_marksman(post, stealth)", "papal_carabinier(arrest)", "papal_dragoon(hunter)"],
        "plan": "一条笔直的古道（第 3 行），两边是陵墓和柏树；第 2、4、6 回合有伏兵从墓穴入口里出来，离马车 4 步。夜里射程 −1，隐身的强盗枪手只在 2 格内才看得清。",
        "power_target": None},
    "san_sebastiano": {
        "name": "圣塞巴斯蒂安墓窟", "date": "1838-02-22", "node": "boss", "chapter": "mediterranean", "scale": "grand", "size": [11, 6], "level": 21, "turn_limit": 14,
        "weather": "night", "terrain": ["K 墓穴（黑暗：站在这里射程 −1）", "C 石廊", "# 墙（挡视线）", "D 门（出生格；事件可锁成墙）", "_ 虚空（塌方）", "B 壁龛（我方可进驻，防 +2）", "^ 圆厅的祭台（高地）"],
        "objective": {"type": "extract", "cell": "F3", "turns": 2, "then": "escape", "desc": "先在 F3 圆厅站满 2 个回合找到阿尔贝，再让他走到 A 列的出口（protect：阿尔贝不倒下）。", "fallback": {"type": "hold", "cell": "F3", "turn": 14}},
        "enemies": ["bandit(ambush, ransom)", "bandit_marksman(post, stealth)", "vampa(leader, ransom)", "assassin(stealth)", "sbirro(arrest)"],
        "plan": "三层墓窟用墙和虚空隔成三条石廊，中间一个圆厅。万帕的人从四扇门里出来（多门），伏兵从墓穴格里冒出来。军议选“伯爵的名片”时敌军心 −2；打死万帕不扣军心，而是“万帕投降”：剩下的强盗全体后退一格。完成命令以后才能招万帕。",
        "power_target": 830},
    "auteuil_garden": {
        "name": "奥特伊的花园之夜", "date": "1838-06-20", "node": "anchor", "chapter": "paris_1838", "scale": "elite", "size": [10, 5], "level": 22, "turn_limit": 9,
        "weather": "night", "terrain": ["w 花园的树丛", "B 宅子（我方可进驻）", "# 花园围墙", "; 翻过的泥土（那棵树下）", "S 方丹街", "G 墙上的小门"],
        "objective": {"type": "hold", "cell": "E3", "turn": 9, "desc": "第 9 回合结束时我方有人守在那棵梧桐树下（E3）：木匣不能被挖走。"},
        "enemies": ["convict(loot)", "benedetto(hunter, execute)", "police_agent(stealth, arrest)", "thug_marksman"],
        "plan": "贝内代托带着两个苦役场的同伙翻墙进来要挖木匣（他要证据去勒索杰拉尔），警察厅的便衣在街上等着抓人。墙挡视线；树丛里挨远程防 +2。贝尔图乔在场时攻 +2（羁绊“仇人的姓”）。",
        "power_target": None},
    "paris_rooftops": {
        "name": "西岱岛的屋顶", "date": "1838-10-14", "node": "elite", "chapter": "paris_1838", "scale": "elite", "size": [10, 5], "level": 23, "turn_limit": 9,
        "weather": "rain", "terrain": ["R 屋顶（只有猎兵类能上，射程 +1）", "B 房屋", "S 小巷", "_ 虚空（屋顶之间的缝）", "# 烟囱（挡视线）"],
        "objective": {"type": "no_leak", "desc": "没有一个刺客摸到附属监狱的天窗（A 列鹰旗）。"},
        "enemies": ["assassin(stealth)", "thug_marksman(post)", "municipal_guard(heavy)", "police_agent(arrest)"],
        "plan": "雨夜：小火器攻 −1。屋顶连成两条路（第 1、2 行），小巷在下面（第 4、5 行），中间隔着虚空。猎兵和万帕是主力；骠骑兵冲锋碰到虚空就停。",
        "power_target": None},
    "cristo_final": {
        "name": "司法宫之夜", "date": "1838-10-15", "node": "boss", "chapter": "paris_1838", "scale": "epic", "size": [12, 7], "level": 24, "turn_limit": 14,
        "weather": "night", "terrain": ["C 附属监狱的牢廊（黑暗）", "L 牢房（我方可进，防 +1）", "D 牢门（出生格）", "S 钟楼码头", "b 兑换桥", "~ 塞纳河", "B 司法宫的房屋", "R 屋顶", "# 墙", "_ 虚空"],
        "objective": {"type": "protect", "npc": {"id": "benedetto_witness", "name": "贝内代托（证人）", "hp": 12, "cell": "B4", "place": "cell"},
                      "desc": "证人贝内代托活到天亮（第 14 回合结束）。他关在 B4 的牢房里，不能移动；任何敌人走进他的牢房就算失败。",
                      "fallback": {"type": "hold", "cell": "B4", "turn": 14}},
        "enemies": ["convict(loot)", "assassin(stealth, hunter, execute)", "police_agent(arrest)", "municipal_guard(heavy)", "national_guard", "thug_marksman(post)", "mounted_gendarme"],
        "plan": "12×7 的不规则大图（右下角是河，虚空切掉左上角）。三拨人：①苦役场的同伙从河上的小船经码头上岸（想劫走他）；②杰拉尔派来的检察署的人从司法宫正门进来（想“依法”把他转走，arrest：主角在他们刀下倒下就直接被捕）；③不知替谁办事的刺客从屋顶下来（stealth + execute，想让他闭嘴）。第 7 回合起骑宪兵从兑换桥冲过来。军议三选一修正 Boss。",
        "power_target": 960},
}
