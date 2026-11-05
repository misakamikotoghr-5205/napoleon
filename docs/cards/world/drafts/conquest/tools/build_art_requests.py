#!/usr/bin/env python3
"""Writes data/hd/art_requests/C_conquest.json — art the trunk + 鹰飞 drafts need (entry shape of data/hd/art_list.json:
kind, id, name, priority, desc [, used_in, variants, role]). B merges these into art_list.json (ARCH §8.4).
Also writes data/hd/vn_cast_conquest.json: scene/event -> background id (+ cast), for vn_cast.json.
Run:  python3 -I tools/build_art_requests.py"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "hd", "art_requests", "C_conquest.json")
CAST = os.path.join(ROOT, "data", "hd", "vn_cast_conquest.json")
NAP = os.path.join(ROOT, "data", "campaigns", "napoleon")
EXISTING_CHARA = {"villefort", "marie", "montholon", "napoleon", "dantes", "gourgaud", "faria", "friday", "nemo", "morel", "corso",
                  "one_eyed_jack", "omeara", "baptiste", "roberts", "oconnell", "hudson_lowe", "pierre", "crawford", "howard",
                  "david_moses", "palmerston", "rothschild"}
NO_PERSON = "画面里不要有人物和文字。"

A = []
def add(kind, aid, name, pri, desc, used_in=None, **kw):
    e = {"kind": kind, "id": aid, "name": name, "priority": pri, "desc": desc}
    if used_in: e["used_in"] = used_in
    e.update(kw)
    A.append(e)

# ---------------------------------------------------------------- backgrounds per scene (VN)
BG = [
    # id, name, priority, desc, used_in
    ("ollioules_depot", "奥利乌勒炮兵库", "P0", "1793 年冬，普罗旺斯山谷里的临时炮兵库：石头谷仓，成排的火药桶，桶上有粉笔写的编号；门外泥地上有很深的车辙，远处是灰色的海和土伦港里的帆。雨天，冷光。", ["toulon_arrival"]),
    ("mulgrave_redoubt_night", "小直布罗陀棱堡·暴雨夜", "P0", "1793 年 12 月 17 日凌晨，凯尔高地上的英军棱堡：木桩胸墙、炮位、散落的英军红衣帽和刺刀，暴雨，防风灯的暖光，远处港湾里英国舰队的灯。", ["toulon_mulgrave"]),
    ("nice_hq_1796", "尼斯·意大利军团司令部", "P0", "1796 年春，尼斯一座旧宅改成的司令部：长桌上摊着阿尔卑斯和皮埃蒙特的地图，空钱柜敞着盖，墙上挂着三色旗；窗外是地中海和推车的随军商贩。", ["italy_nice"]),
    ("milan_serbelloni", "米兰·塞尔贝洛尼宫", "P0", "1796 年 5 月，米兰塞尔贝洛尼宫的大厅：镀金天花板，地上排着待装箱的油画和木箱，一张写满清单的桌子，窗外广场上人群和花。", ["italy_milan"]),
    ("rivoli_moonlight", "里沃利高原·月夜", "P0", "1797 年 1 月 14 日凌晨，里沃利高原：雪地反着月光，远山上一串营火像项链，近处是弹药车和炮，峡谷口的之字路往下蜿蜒。", ["italy_rivoli"]),
    ("passariano_villa", "帕塞里亚诺别墅", "P1", "1797 年秋，威尼托的帕塞里亚诺别墅：大理石厅里堆满运往巴黎的木箱，一只箱子开着露出画框一角；窗外是平原和远处的亚得里亚海。", ["italy_campo_formio"]),
    ("toulon_harbour_1798", "土伦港·三百艘船", "P1", "1798 年 5 月的土伦港：港里挤满战舰和运输船，码头上堆着大炮、骆驼鞍和学者的仪器箱，远处山上是五年前的炮台废墟。", ["orient_orders"]),
    ("acre_trenches", "阿卡城下的壕沟", "P1", "1799 年 5 月，阿卡城外：沙色城墙上有炮眼，壕沟和沙袋，海上停着英国船，近处有一顶写着隔离字样的白帐篷（字样别写出来）。烈日。", ["orient_acre"]),
    ("marengo_plain", "马伦哥平原·下午三点", "P1", "1800 年 6 月，波河平原：麦田、葡萄架、硝烟，地平线上一道尘土；路边摆着一排白兰地桶。", ["alps_marengo"]),
    ("boulogne_camp", "布洛涅营地", "P1", "1805 年夏，布洛涅海边的大军营地：成排的木屋，港里的平底船，远处海平线上隐约的英国白崖，一顶大帐篷里有地图桌。", ["boulogne_orders", "k_choice_1817"], ),
    ("pratzen_fog", "普拉岑高地·雾", "P1", "1805 年 12 月 2 日清晨，摩拉维亚：雾从洼地里升起，高地顶上露出阳光，远处结冰的池塘反光。", ["austerlitz_sun"]),
    ("eylau_churchyard", "埃劳墓地·暴雪", "P1", "1807 年 2 月，东普鲁士埃劳：雪中的小教堂和墓地，墓碑半埋在雪里，远处炮火的闪光。", ["eylau_snow"]),
    ("bayonne_marracq", "巴约讷·马拉克城堡", "P2", "1808 年春，巴约讷城外的马拉克城堡：方正的石头城堡、花园、门口停着西班牙王室的马车。", ["bayonne_orders"]),
    ("saragossa_ruins", "萨拉戈萨·修道院废墟", "P1", "1809 年 2 月，萨拉戈萨：被炸塌一半的修道院，街垒，屋顶上的沙袋，地道入口。", ["saragossa_siege"]),
    ("lobau_bridges", "洛鲍岛的浮桥", "P1", "1809 年 7 月，多瑙河洛鲍岛：暴雨夜，河上一排编了号的浮桥，木牌上的数字（只画数字的牌子轮廓，不写字）、锚链和工兵的灯。", ["wagram_lobau", "ev_danube_pontoons"]),
    ("niemen_pontoons", "涅曼河浮桥", "P1", "1812 年 6 月，涅曼河：三座浮桥伸向空无一人的对岸，岸上是望不到头的车队，晴天，对岸的村子冒着烟。", ["russia_niemen", "k_niemen", "ev_tilsit_raft"]),
    ("raevsky_redoubt", "博罗季诺·多面堡", "P1", "1812 年 9 月 7 日，博罗季诺：冒烟的土木多面堡、翻倒的炮、焦黑的田野，远处的村庄在烧。", ["russia_borodino"]),
    ("berezina_bridges", "别列津纳河的两座桥", "P0", "1812 年 11 月，别列津纳河：冰水里的两座木桥，河上漂着浮冰，岸边雪地里翻倒的大车和一面鼓。灰白天色。", ["russia_berezina"]),
    ("lutzen_conscripts", "吕岑·新兵营", "P2", "1813 年 5 月，萨克森的春天：田野里成排的帐篷，没有军靴的鞋子摆在一边，枪架。", ["collapse_lutzen"]),
    ("leipzig_elster", "莱比锡·埃尔斯特河桥", "P1", "1813 年 10 月，莱比锡城外：埃尔斯特河上唯一的石桥，桥上挤满车和人，远处城里的教堂尖顶和硝烟。", ["collapse_leipzig"]),
    ("fontainebleau_cour", "枫丹白露·白马庭院", "P0", "1814 年 4 月 20 日，枫丹白露宫白马庭院：马蹄形的大台阶，庭院里列队的老近卫军（远景、小，不出脸），一面鹰旗。阴天。", ["collapse_fontainebleau"]),
    ("portoferraio_quay", "费拉约港码头", "P0", "1814 年，厄尔巴岛费拉约港：小港湾、黄色和赭色的房子、山上的星形要塞，码头上卸着箱子，港里停着英国护卫舰。", ["elba_arrival", "ev_pharaon_elba"]),
    ("portoferraio_warehouse", "码头仓库·夜", "P0", "1815 年 2 月 24 日夜，费拉约港的码头仓库：十二只上锁的箱子，一条跳板通向双桅船，海上远处三盏灯。", ["elba_night"]),
    ("mulini_billiard", "穆利尼宫·台球桌上的地图", "P0", "1815 年 2 月，穆利尼宫的小厅：绿呢台球桌上摊着法国地图，旁边一封封好的信，窗外港里一条双桅船正在升帆。", ["elba_1815"]),
    ("golfe_juan_beach", "儒安湾海滩", "P0", "1815 年 3 月 1 日，儒安湾：多石的海滩、小船、一个小小的海关哨所，远处昂蒂布炮台上的白旗。冬天的阳光。", ["k_golfe_juan"]),
    ("laffrey_meadow", "拉弗雷·相遇的草地", "P0", "1815 年 3 月 7 日，阿尔卑斯山间的拉弗雷：湖、雪山、一片草地，路上一排列队的步兵（远景，小，不出脸）。", ["k_laffrey"]),
    ("tuileries_bees", "杜伊勒里宫·蜜蜂挂毯", "P0", "1815 年 3 月 20 日夜，杜伊勒里宫：撕掉一半百合花的挂毯，底下露出金色蜜蜂，烛台，窗外花园里的人群和火把。", ["k_tuileries"]),
    ("charleroi_bridge_dawn", "沙勒罗瓦·桑布尔河桥", "P0", "1815 年 6 月 15 日黎明，沙勒罗瓦：石桥上的路障、对岸临河的房子、河上的薄雾。", ["k_charleroi"]),
    ("plancenoit_churchyard", "普朗斯努瓦教堂墓园", "P0", "1815 年 6 月 18 日下午，普朗斯努瓦：泥泞的村街、齐胸高的墓园矮墙、石头教堂，硝烟，墙后摆成一排的鼓。", ["k_waterloo"]),
    ("waterloo_inn", "滑铁卢村·客栈", "P0", "1815 年 6 月 18 日夜，滑铁卢村的客栈：低矮木梁、烛光、桌上摊着账簿，门口堆着缴获的军旗（旗面不写字）。", ["k_waterloo_night"]),
    ("brussels_warehouse", "布鲁塞尔·威灵顿的仓库", "P1", "1815 年夏，布鲁塞尔的大仓库：成堆的靴子、饼干桶、一只开着的金币箱。", ["k_brussels"]),
    ("metz_hall", "梅斯·会议厅", "P1", "1815 年夏，梅斯市政厅的会议厅：长桌、两把相对的椅子、地图和墨水瓶。", ["k_ultimatum"]),
    ("lauter_lines", "维桑堡防线", "P1", "1815 年秋，阿尔萨斯劳特河边的旧土墙防线：涨水的小河、渡船、雨。", ["k_rhine"]),
    ("nymphenburg", "慕尼黑·宁芬堡宫", "P2", "1816 年春，宁芬堡宫的长廊和运河，冰正在化。", ["k_bavaria"]),
    ("vienna_breach", "维也纳·城墙缺口", "P1", "1816 年 6 月，维也纳城墙的缺口：碎石、远处圣斯特凡大教堂的尖顶，屋顶上的人影（小，不出脸）。", ["k_vienna"]),
    ("schoenbrunn_nursery", "美泉宫·东翼的儿童房", "P0", "1816 年 6 月，美泉宫东翼的儿童房：小床、木马、一排锡兵、窗外的花园。", ["k_schoenbrunn"]),
    ("torres_vedras_lines", "托雷斯韦德拉什防线", "P1", "1817 年秋，葡萄牙的山岭：一道道土墙和炮台沿山脊排开，山上拆了翼的风车。", ["k_torres_vedras"]),
    ("dover_cliffs", "多佛尔白崖", "P1", "1817 年 8 月，从海滩仰望多佛尔的白崖：崖顶炮台、退潮的海滩、靠岸的平底船。", ["k_dover"]),
    ("warsaw_castle", "华沙王宫广场", "P2", "1818 年 5 月，华沙王宫前的广场：红白两色的旗、跳舞的人群（远景）、宫殿钟楼。", ["k_warsaw"]),
    ("tuileries_fireworks", "杜伊勒里花园·烟火", "P2", "1819 年 8 月 15 日夜，杜伊勒里花园上空的烟火，宫殿的灯。", ["k_paris_1819"]),
    ("leipzig_villages", "莱比锡南郊", "P1", "1819 年 10 月，莱比锡南边的村子和平原，远处一块新立的石碑。秋天。", ["k_leipzig_1819"]),
    ("emperor_tent_night", "皇帝的帐篷·夜", "P0", "1819 年 10 月 19 日夜，普罗布斯泰达的帐篷：行军桌上并排放着一卷和约、一张皇冠的图样、一封信。烛光。", ["k_final"]),
    # generic event backgrounds
    ("hq_tent", "司令部营帐（军议）", "P0", "行军司令部的大帐篷：地图桌、蜡烛、折叠椅、帐外的哨兵影子。军议事件通用。", ["ev_council_*", "ev_muiron_letter"]),
    ("roadside_woods", "行军路旁的树林", "P1", "欧洲乡间道路边的树林、车辙、倒在路边的大车。随机事件通用。", ["ev_deserters", "ev_barbets_convoy", "ev_ulm_prisoners", "ev_ratisbon_wound", "ev_lodi_veteran", "ev_courier_lost"]),
    ("officers_mess", "军官食堂", "P2", "村舍改的军官食堂：长桌、牌、酒瓶、烛台。", ["ev_faro_table"]),
    ("bivouac_rain", "雨夜宿营", "P1", "雨夜的宿营地：大车下面睡着人（看不清脸）、冒烟的营火、油布。", ["ic_rain_bivouac", "ib_fireside", "ev_marie_cantine", "ev_conscript_letter"]),
    ("bivouac_snow", "雪夜宿营", "P1", "雪地里的营火、烧了一半的马鞍、远处的松林。", ["ic_snow_bivouac", "ev_horse_meat"]),
    ("spada_library", "博洛尼亚·斯帕达府书房", "P0", "18 世纪末的意大利贵族书房：高书架、装了一半的书箱、一本旧日课经放在桌上。", ["ev_faria_half_letter"]),
    ("monastery_library", "修道院图书馆", "P2", "巴洛克修道院的图书馆：彩绘穹顶、金色书架、窗外多瑙河。", ["ev_melk_library"]),
    ("valletta_cathedral", "瓦莱塔·圣约翰大教堂", "P2", "马耳他圣约翰大教堂的侧廊：金色雕饰、一扇刷成黑色的大门。", ["ev_malta_silver"]),
    ("st_bernard_hospice", "大圣伯纳德济贫院", "P1", "阿尔卑斯山口的石头修道院、积雪、路边摆着面包和酒的长桌、掏空的松树干。", ["ev_st_bernard", "ev_alps_mules"]),
    ("war_ministry_archive", "战争部档案室", "P0", "1815 年巴黎战争部的档案室：一排排文件格、桌上一摞请愿书、台灯。", ["ev_morrel_petition", "ev_vendee_rising"]),
    ("auxerre_prefecture", "欧塞尔省长官邸", "P2", "法国外省官邸的门厅：大理石楼梯、门外列队的骑兵（远景）。", ["ev_ney_auxerre"]),
    ("weimar_garden", "魏玛·歌德的花园小屋", "P2", "伊尔姆河边的小花园屋：茶具、书、窗外河上的桥。", ["ev_goethe_tea"]),
    ("depot_warehouse", "军需仓库", "P1", "石头仓库内部：面粉袋、木桶、一杆大秤、账桌。", ["ev_storks_scale", "ev_dos_de_mayo"]),
    ("village_street", "村街", "P1", "18—19 世纪欧洲乡村的街道：石头房子、教堂钟楼、井台、泥路。随机事件通用。", ["ev_pavia_revolt", "ev_capoliveri", "ev_six_days", "ev_bread_ovens", "ev_post_horses", "ev_carters_debt"]),
    ("harbour_quay", "地中海小港码头", "P1", "地中海小港：石头码头、渔船和三桅商船、成堆的粮袋。", ["ev_morrel_grain", "ev_smugglers_deal"]),
    ("palace_hall", "宫殿大厅", "P1", "巴洛克宫殿的大厅：镶木地板、大窗、空着的宝座、靠墙的木箱。", ["ev_frederick_sword", "ev_marie_louise_letter"]),
    ("cairo_courtyard", "开罗·司令部庭院", "P2", "1799 年开罗的马穆鲁克宅邸庭院：喷泉、木格窗、棕榈。", ["ev_mysore_envoy"]),
    ("mountain_hermitage", "山间小庵", "P2", "厄尔巴岛马尔恰纳山上的小教堂和石屋，栗树林，远处的海。", ["ev_walewska"]),
    ("smolensk_fire", "燃烧的斯摩棱斯克", "P2", "第聂伯河边燃烧的城市、石头粮仓、浓烟。", ["ev_smolensk_granary"]),
    ("desert_road", "沙漠行军路", "P2", "埃及沙漠里的行军路：骆驼、木箱、热浪。", ["ev_scholars_crates"]),
    ("village_well", "村口的井", "P2", "卡斯蒂利亚空无一人的村子，井口边一只水桶。", ["ev_poisoned_well"]),
    ("salamanca_field", "萨拉曼卡城南的麦田", "P2", "收割过的麦田、远处两座小山（阿拉皮莱斯）、犁沟里的白点。", ["ev_arapiles_bones"]),
    ("paris_faubourg", "巴黎圣安托万区", "P2", "1815 年巴黎东郊的工人街区：作坊、狭窄的街、三色旗。", ["ev_federes"]),
    ("vineyard", "阿尔萨斯的葡萄园", "P2", "秋天的葡萄园、山坡、远处的教堂和土墙防线。", ["ev_alsace_harvest"]),
    ("alpine_inn", "蒂罗尔的客栈", "P2", "因河边的木头客栈：壁炉、鹿角、窗外的雪山。", ["ev_tyrol_innkeeper"]),
    ("invalides", "荣军院", "P2", "巴黎荣军院的庭院：拱廊、金色穹顶。", ["ev_guard_pensions"]),
    ("dunkirk_dock", "敦刻尔克船坞", "P2", "1817 年的敦刻尔克船坞：船台上一条怪模样的船、图纸摊在木箱上。", ["ev_fulton_nautilus"]),
]
for aid, name, pri, desc, used in BG:
    add("bg", aid, name, pri, desc + NO_PERSON if "不出脸" not in desc else desc, used)

# ---------------------------------------------------------------- map backgrounds (local painted maps; ARCH lists the big ones)
add("bg", "map_toulon_1793", "土伦围城图 1793", "P0", "手绘风格的局部地图：土伦港、小锚地、凯尔高地上的小直布罗陀、奥利乌勒山谷、萨纳里和邦多勒小港、拉塞讷。18 世纪军事地图的配色（羊皮纸底、淡彩海面、晕渲山地），不写地名（地名由游戏叠加）。节点位置照 maps/europe.json 里 toulon 图的 xy（1920×1080）。", ["map:toulon"])
add("bg", "map_elba", "厄尔巴岛图", "P0", "手绘风格的厄尔巴岛全岛图：费拉约港在北岸，东边里奥铁矿，南边隆戈内港和卡波利韦里，西边马尔恰纳山。羊皮纸底，不写地名。节点 xy 见 elba 图。", ["map:elba"])
add("bg", "map_portoferraio", "费拉约港城图", "P0", "费拉约港城和港湾的俯视图：星堡、法尔科内堡、穆利尼宫、码头和仓库、港口外的海。羊皮纸底，不写地名。节点 xy 见 elba 图的 portoferraio_1815 镜头。", ["map:elba"])

# ---------------------------------------------------------------- cg (endings)
add("cg", "ending_k_pax", "结局·鹰的和平", "P1", "杜伊勒里宫的签约大厅：各国旗帜挂在同一面墙上，长桌上的和约，一个少年（拿破仑二世）站在窗边。暖光。", ["k_pax"])
add("cg", "ending_k_iron", "结局·铁的欧洲", "P1", "圣母院里的加冕：一顶新皇冠的特写，背景里密密麻麻的军旗，冷色调。", ["k_iron"])
add("cg", "ending_k_return", "结局·回到马赛", "P0", "马赛老港的婚宴：码头上的长桌、法老号的桅杆、一对新人（唐泰斯与梅尔塞苔丝）的背影，主角举杯（侧脸）。夏日夕阳。", ["k_return"])
add("cg", "ending_k_dusk", "结局·鹰落", "P1", "1821 年的葬礼行列：老近卫军抬着灵柩走过塞纳河的桥，雨，一本账簿夹在一个人的胳膊下。", ["k_dusk"])

# ---------------------------------------------------------------- characters
CH = [
    ("bonaparte", "拿破仑·波拿巴（1793—1799）", "P0", "24 到 30 岁的炮兵军官、后来的意大利军团司令：很瘦，长发披到领口，苍白，眼睛很亮；1793 年是蓝色炮兵上尉服，1796 年起是将军的蓝外套和三色腰带。和现有的 napoleon（皇帝）是同一人年轻时，脸要对得上。"),
    ("dugommier", "杜戈米埃将军", "P2", "55 岁上下的共和国将军，花白头发，旧式三角帽，雨中的大衣。"),
    ("saliceti", "萨利切蒂特派员", "P2", "40 岁上下的科西嘉人，督政府特派员的三色饰带，精明的笑。"),
    ("muiron", "米隆", "P1", "22 岁的副官：年轻、诚恳，蓝色副官服，手里一盏防风灯。"),
    ("lannes", "拉纳", "P1", "27 到 40 岁的勇将：粗犷、加斯科涅人的鼻子，帽子上有弹孔，掷弹兵出身的大个子。"),
    ("murat", "缪拉", "P1", "30 岁上下的骑兵统领：黑色卷发，华丽到夸张的骠骑兵服、羽毛，金鼻烟壶。"),
    ("desaix", "德塞", "P1", "31 岁的将军：长发随意束起，衣着朴素，面容端正，脸上有一道旧刀疤。"),
    ("larrey", "拉雷", "P1", "30 到 50 岁的军医：长发、和气，袖子卷着，胳膊上搭着绷带。"),
    ("rustam", "鲁斯塔姆", "P2", "20 岁上下的马穆鲁克护卫：缠头巾、宽袍、弯刀。"),
    ("eble", "埃布莱", "P1", "50 岁上下的舟桥兵将军：高瘦、灰发，手里一本小本子，裤腿湿到膝盖。"),
    ("drouot", "德鲁奥将军", "P0", "40 岁上下的近卫炮兵将军：严肃朴素，戴眼镜，腋下夹一本《圣经》。"),
    ("cambronne", "康布罗纳将军", "P0", "45 岁上下的老近卫军将军：熊皮帽、浓眉、伤疤、倔强的下巴。"),
    ("ney", "内伊元帅", "P0", "46 岁的元帅：红头发、红脸膛，元帅服，焦躁又真诚。"),
    ("davout", "达武元帅", "P2", "45 岁的元帅：光头、圆眼镜、冷静。"),
    ("fouche", "富歇", "P1", "56 岁的警务部长：瘦削苍白，薄嘴唇，永远在笑，手里一个小本子。"),
    ("grouchy", "格鲁希元帅", "P2", "49 岁的骑兵元帅：端正、迟疑的表情，手里一张没写时辰的命令。"),
    ("talleyrand", "塔列朗亲王", "P1", "61 岁的外交家：扑粉的头发、跛足、手杖，似笑非笑。"),
    ("max_joseph", "马克西米利安国王", "P2", "60 岁的巴伐利亚国王：圆脸、和气、精于计算。"),
    ("king_of_rome", "罗马王", "P0", "5 岁的男孩，金色卷发，穿一身小号的奥地利军装，手里一只锡兵。"),
    ("gerard_villefort", "杰拉尔·德·维尔福", "P1", "27 岁的王家检察官：黑衣、白领巾，苍白英俊，眼神冷。和主角同宗，眉眼要有一点像。（伊夫堡包也会用到：同一人物，以那边的描述为准）"),
    ("goethe", "歌德", "P2", "70 岁的诗人：高额头、深色外套、眼神温和而锐利。"),
    ("campbell", "坎贝尔上校", "P2", "40 岁上下的英国军官：红色军服、单片眼镜。"),
]
for aid, name, pri, desc in CH:
    if aid not in EXISTING_CHARA:
        add("chara", aid, name, pri, desc)
        add("face", aid, name, pri if pri != "P2" else "P1", "同一人物的头像，和立绘用同一个模型。")
# variants of existing characters (age)
add("chara", "villefort", "埃德蒙·德·维尔福（年龄变体）", "P0",
    "现有立绘的年龄变体，同一张脸：young（1793，17 岁，炮兵库书记，破旧蓝外套、墨水手指）；1805（29 岁，军需官制服、双角帽）；1815（39 岁，近卫军军需司库，鹰徽怀表——不要天平坠子）。",
    variants=["young", "1805", "1815"], variant_of="villefort")
add("chara", "marie", "玛丽·朗热（年龄变体）", "P1", "现有立绘的年轻变体 cantiniere（1796，28 岁上下的随军女商贩：三角头巾、围裙、腰间挂酒壶）。", variants=["cantiniere"], variant_of="marie")
add("chara", "pierre", "小皮埃尔（年龄变体）", "P0", "现有立绘的年幼变体 drummer（1812，10 岁上下的鼓手：大一号的军服、脖子上挂着鼓，冻红的脸）。", variants=["drummer"], variant_of="pierre")
add("chara", "baptiste", "巴蒂斯特（年龄变体）", "P2", "现有立绘的年轻变体 1793（25 岁的工兵下士）。", variants=["1793"], variant_of="baptiste")

# ---------------------------------------------------------------- battle units: companions new in this package
U = [("muiron", "line"), ("lannes", "grenadier"), ("murat", "hussar"), ("desaix", "line"), ("larrey", "medic"), ("rustam", "hussar"),
     ("eble", "engineer"), ("pierre", "drummer"), ("drouot", "artillery"), ("cambronne", "grenadier"), ("ney", "hussar"), ("baptiste", "engineer")]
for aid, cls in U:
    add("unit", aid, aid, "P1", "伙伴上阵的样子（兵种 %s）：按上面的人物描述，全身、单人。" % cls, role="companion")
# enemies new in this package (ARCH §5 ones are B's)
E = [("piedmontese", "皮埃蒙特步兵", "蓝色军服、黑色三角帽的皮埃蒙特-撒丁步兵。"),
     ("barbet", "巴尔贝山民", "滨海阿尔卑斯的山民游击队：粗布衣、宽檐帽、猎枪。"),
     ("tyrolean", "蒂罗尔射手", "绿色短外套、插羽毛的宽檐帽、长猎枪。"),
     ("chevauleger", "奥军轻骑兵", "绿色或白色轻骑兵服、头盔，马刀。"),
     ("dutch_belgian", "荷比步兵", "1815 年荷兰-比利时军：蓝色军服、高筒军帽。"),
     ("brunswicker", "布伦瑞克兵", "全身黑衣、帽子上一个银色骷髅徽（只画轮廓，不写字）。"),
     ("blucher", "布吕歇尔", "72 岁的普鲁士元帅：白色大胡子、骑兵大衣、挥着马刀。")]
for aid, name, desc in E:
    add("unit", "enemy_" + aid, name, "P1", desc + "单人、全身。", role="enemy")
    add("face", "enemy_" + aid, name, "P2", "同一兵种的头像。")
# map icons beyond ARCH's 11
add("icon", "council", "地图节点·军议", "P1", "圆章图标：两把交叉的羽毛笔压在地图上。256×256 透明底。")
add("icon", "rival", "地图·对手分遣队", "P1", "棋子样的圆章：一面小三角旗。256×256 透明底。")
add("icon", "depot", "地图·兵站", "P1", "圆章图标：一只木桶和一袋面粉。256×256 透明底。")

def cast_table():
    out = {}
    for seg in ("trunk", "conquest"):
        d = json.load(open(os.path.join(NAP, seg + ".json"), encoding="utf-8"))
        by_scene = {}
        for aid, name, pri, desc, used in BG:
            for u in used:
                by_scene[u] = aid
        for s in d["scenes"]:
            out[s["id"]] = {"bg": by_scene.get(s["id"], "camp_tent"), "speaker": s.get("speaker", "")}
        for e in d.get("events", []):
            bg = by_scene.get(e["id"])
            if not bg and e.get("council"): bg = "hq_tent"
            out["event:" + e["id"]] = {"bg": bg or "roadside_woods", "speaker": e.get("speaker", "")}
    ec = json.load(open(os.path.join(NAP, "events_common.json"), encoding="utf-8"))
    for e in ec["events"]:
        bg = "bivouac_rain" if e["pool"].startswith("interlude:bond") or e["pool"] == "interlude:camp_night" else "hq_tent"
        if e["id"] == "ic_snow_bivouac": bg = "bivouac_snow"
        out["event:" + e["id"]] = {"bg": bg, "speaker": e.get("speaker", "")}
    return out

def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    d = {"version": 1, "from": "C (标签 conquest)",
         "_doc": "主干与鹰飞草稿需要的美术（data/hd/art_list.json 的条目形状）。B 合并进 art_list.json；variant_of 表示给现有条目加变体，不是新 id。ARCH §4.6 已经列的地形、摆件、map_europe 等不在这里重复。",
         "assets": A}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=1)
        f.write("\n")
    with open(CAST, "w", encoding="utf-8") as f:
        json.dump({"version": 1, "_doc": "给 vn_cast.json 的演出表草稿：场景 / 事件 → 背景 id 与主讲人（立绘位由 VN 按主讲人和正文里的“名字：”自动排）。", "scenes": cast_table()},
                  f, ensure_ascii=False, indent=1)
        f.write("\n")
    import collections
    print("art requests:", len(A), dict(collections.Counter(a["kind"] for a in A)))

if __name__ == "__main__":
    main()
