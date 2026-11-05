#!/usr/bin/env python3
# Writes wm/ocean/ocean_art_requests.json: the ocean branch's art needs, in data/hd/art_list.json "assets" shape,
# for B to merge (ARCH §8.4: art_list.json has one writer). update = existing ids whose name/desc must lose the
# pawnshop motif; add = new entries. Old text is kept under _old_* keys (not scanned, not shipped).
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from ocean_enemies import ENEMIES
ROOT = os.path.dirname(HERE)
REPO = "/home/user/dehoudang"
OUT = os.path.join(ROOT, "ocean_art_requests.json")

art = json.load(open(os.path.join(REPO, "data/hd/art_list.json"), encoding="utf-8"))
have = {(a["kind"], a["id"]): a for a in art["assets"]}

UPDATE = [
    ("bg", "bellerophon_hold", None, "1815 年英国 74 炮战列舰贝勒罗丰号的底舱，夜里。弧形船肋和木梁、成排的酒桶和板条箱、挂着的油灯。画面中下方一只包铁角的军需箱，箱盖上摊着一本账簿、一只表盘碎裂的金怀表。昏暗、潮湿、暖黄灯光。", "去掉天平；序曲的道具是军需箱和厄尔巴怀表"),
    ("bg", "jamestown_shop", "詹姆斯敦·海鸥号补给栈", "1817 年圣赫勒拿岛詹姆斯敦，一个法国人开的船具补给栈前堂：木地板、粗木案桌、一盏油灯；墙上挂着缆绳卷、滑轮组、提灯，地上摞着淡水桶、腌肉桶和饼干箱，门边一块写着“海鸥号”的小招牌（字由代码画也可以，图里只画空招牌）。窗外是陡坡街道和雨。油灯暖光，雨天冷光从窗户进来。不要画货架上一件件待售的旧物件。", "当铺前堂改成船具补给栈：卖的是航海补给，不是当进来的物件（id 不改，第一、二场都用）"),
    ("bg", "shop_back_room", "海鸥号补给栈·后间密室", "补给栈后间的密室：书桌上摊着军需账簿和圣赫勒拿岛地图，一只包铁的钱箱、蜡烛，一面书架后面露出通往海蚀洞的暗门。", "“估值铺后堂”改成“补给栈后间”"),
    ("bg", "granite_palace_exchange", "花岗岩宫·鲸骨交易所", "在花岗岩山体里凿出的大厅，鲸骨做成的拱门和交易台，岛上殖民者的交易所：秤、货箱、海图、贝壳货币和一摞鹰徽代用币。", "“柜台”改成“交易台”，加上鹰徽代用币"),
    ("bg", "atlantis_ruins", None, "海底的亚特兰蒂斯遗址：倒塌的柱廊、神庙台阶上一座波塞冬祭坛，祭坛上放着一块赤金色的八面体矿石（山铜），光从水面射下来。", "去掉巨大的山铜天平"),
    ("bg", "title", None, "标题主视觉：一面法军鹰旗压在一张展开的航海图上，图上一只黄铜罗盘，三条航路从罗盘向外分开（一条往北方的战场，一条往南方的大洋，一条往一座海上的城堡）；背景是黄昏的海和帆船。画面左侧三分之一留给游戏标题（标题字由代码画，图里不要有字）。", "天平和账簿换成鹰徽、罗盘和三条航路（ARCH §6、§7；标题页三本书共用，这一条要和 A 的纹章一起定）"),
    ("cg", "ending_alliance", None, "拿破仑、尼摩与唐泰斯在鹦鹉螺号的客厅里签约，桌上摊着一本厚厚的军需账簿和一张世界海图，舷窗外是深海。", "去掉居中的天平"),
    ("cg", "ending_ghost", "结局插图·幽灵舰队", "鹦鹉螺号与一艘挂黑帆的快船（闪电号）向南极冰盖驶去，极光。", "名字去掉“当铺”"),
    ("cg", "ending_dark", "结局插图·深海金库", "阴暗的深海金库里堆满金币、金砖和一摞摞借据，一盏冷光灯照着一张空椅子。", "“账房”“当票”改成“金库”“借据”"),
    ("chara", "villefort", None, "35 岁上下的法国男人，帝国老近卫军的军需官兼司库，随皇帝流亡。瘦高、深色短发、鬓角、眼神锐利。深蓝色旧军需官外套（银扣）、马甲、一条金怀表链，表链上挂一枚小小的鹰徽表坠。正经、精明、带点疲惫。", "“现在开当铺”改成“流亡皇帝的司库”；天平坠子换成鹰徽表坠"),
    ("unit", "villefort", None, "主角上阵的样子：在上面的人物描述基础上，戴双角帽、佩军刀，一手拿一卷调拨凭单。单人。", "“拿账簿”改成“拿调拨凭单与指挥刀”"),
    ("chara", "pierre", None, "二十出头的年轻勤务兵（1812 年别列津纳桥头被捡回来的鼓手），机灵、瘦小，旧军装改的便服、帽子，腰上还挂着一面旧军鼓的鼓槌。", "“12 岁的男孩学徒”和主干里的年纪对不上（主干：1813 年还不满 18 岁）；身份改成勤务兵"),
]

def bg(id, name, desc, used_in, prio="P2", variants=None):
    e = {"kind": "bg", "id": id, "name": name, "priority": prio, "desc": desc, "used_in": used_in}
    if variants:
        e["variants"] = variants
    return e

ADD = [
    bg("map_biscay", "地图·1815 年的西逃路线", "序曲一章的示意地图（不是严格投影）：右上角巴黎和马尔梅松，一条驿道经卢瓦尔河谷（图尔）、普瓦捷、尼奥尔斜下到左下；左下半幅是放大的夏朗德海岸（拉罗谢尔、罗什福尔、富拉、艾克斯岛、奥莱龙岛、鲁瓦扬、吉伦特河口）；左上角是英格兰西南角（普利茅斯、托贝湾），中间隔着比斯开湾和布列塔尼外海。旧航海图风格，羊皮纸色陆地、灰蓝的海，海岸线参考 wm/geo/europe.json；节点位置照 maps/world.json 的 prologue.xy 留空。不要地名和文字（地名由代码画）。", ["map:prologue"], "P1"),
    bg("map_st_helena", "地图·圣赫勒拿岛", "圣赫勒拿全岛的手绘局部图，北在上：西北角詹姆斯敦所在的深谷、中部的戴安娜峰、东边朗伍德高原和死木平原、南岸的悬崖与小海湾。旧航海图风格，等高线和阴影表现陡峭的火山岩，海面留白。不要地名和文字。", ["map:st_helena"], "P1"),
    bg("map_new_elba", "地图·新厄尔巴岛", "虚构的南太平洋火山岛手绘局部图，北在上：中央冒烟的火山，西岸花岗岩悬崖（花岗岩宫），西南浅滩上一艘搁浅的帆船残骸，南岸村子和礁湖，东岸一片骷髅形的黑色礁石。旧航海图风格，不要地名和文字。", ["map:new_elba"], "P1"),
    bg("malmaison_salon", "马尔梅松·客厅", "1815 年 6 月的马尔梅松城堡客厅：约瑟芬留下的帝政式家具、绿色丝绸墙、窗外的花园；桌上摊着收据和几只打开的钱箱。傍晚，没有人。", ["ev_o_malmaison"]),
    bg("tuileries_cabinet", "杜伊勒里宫·书房", "1815 年 3 月的杜伊勒里宫书房：地毯上还是波旁王室的百合花纹，书桌上堆满文件和请愿书，一盏烛台。夜里，没有人。", ["ev_o_int_hundred_days"]),
    bg("basque_roads_dusk", "艾克斯岛·巴斯克锚地", "1815 年 7 月黄昏，从艾克斯岛的石头码头望出去：远处锚地口停着一艘英国三层炮甲板战列舰，近处两艘法国护卫舰，海面平静。", ["ev_o_council_basque", "map:prologue"]),
    bg("charente_post_road", "夏朗德的驿道", "1815 年夏天法国西部的驿道：两排白杨、一座石头驿站和马厩、路边的里程碑，远处一座小城的教堂尖顶。", ["ev_o_besson_barrel", "ev_o_joseph_messenger", "ev_o_white_cockade"]),
    bg("northumberland_deck", "诺森伯兰号·下层甲板", "英国战列舰诺森伯兰号的下层炮甲板，夜里：一排炮门、吊床、几只行军箱，舷窗外是热带的海。", ["ev_o_int_northumberland"]),
    bg("jamestown_roads", "詹姆斯敦锚地", "从詹姆斯敦码头望出去的锚地：一艘东印度公司的大商船、几条小艇，岸上是城堡的石墙和梯子山的陡坡。白天，海风。", ["ev_o_indiaman_purser", "scene02"]),
    bg("st_helena_signal_station", "圣赫勒拿·信号站", "山顶的信号站小屋，一根挂着彩色信号旗的旗杆，屋里桌上摊着旗语本和一盏油灯，窗外是云和海。夜里。", ["ev_o_semaphore_book"]),
    bg("lightning_deck_night", "闪电号·后甲板", "一艘挂黑帆的快船（闪电号）的后甲板，夜里：舵轮、罗经柜、几只当座位的木桶，满天星，船尾的灯没点。", ["ev_o_int_lightning"]),
    bg("new_elba_lagoon", "新厄尔巴·礁湖", "清晨的礁湖：浅绿的水、露出水面的黑色礁石、一条独木舟，远处是火山岛和一条下了锚的捕鲸船。", ["ev_o_friday_canoe", "ev_o_nantucket_whalers"]),
    bg("nautilus_salon", "鹦鹉螺号·客厅", "潜艇鹦鹉螺号的客厅：管风琴、玻璃陈列柜里的贝壳和珊瑚、油画、两扇巨大的圆形舷窗开着，窗外是深蓝的海水和游鱼。1830 年代复古科幻。", ["ev_o_int_organ"]),
    bg("nautilus_platform_night", "鹦鹉螺号·平台", "浮出水面的鹦鹉螺号平台，夜里：铆钉钢板、探照灯罩、敞开的舱口；远处海平线上是一座黑色的岛和几点灯火。变体 __day：同一机位的白天，远处是喷水的鲸群。", ["ev_o_st_helena_view", "ev_o_sperm_whales", "ev_o_message_bottle", "ev_o_uncharted_island"], variants=["day"]),
    bg("ceylon_pearl_bank", "马纳尔湾的珍珠贝床", "锡兰马纳尔湾的海底：成片的珍珠贝、阳光从水面射下、一条采珠人的绳索垂下来，远处有鲨鱼的影子。", ["ev_o_pearl_bank"]),
    bg("coral_cemetery", "海底珊瑚墓地", "海底一片红珊瑚林，中间一块空地，立着一根珊瑚做的十字或石碑，潜水灯的光圈照着它。安静、庄重。", ["ev_o_coral_cemetery"]),
]
CHARA = [
    ("betsy", "贝琪·巴尔康姆", "十几岁的英国少女，荆棘园巴尔康姆家的女儿，活泼、敢说话。浅色细棉布长裙、草帽，挎一只柳条篮。按真实的人画（史实人物）。"),
    ("laffitte", "雅克·拉菲特", "50 岁上下的巴黎银行家，圆脸、精明、衣着考究：深色燕尾服、白领巾、怀表链。"),
    ("besson", "贝松船长", "30 岁上下的法国商船船长，晒得黝黑，海员外套、宽檐帽，嘴里叼着烟斗。"),
]

ENEMY_DESC = {
    "marine": "1810 年代英国皇家海军陆战队员：红上衣、白交叉背带、黑色圆筒军帽，持带刺刀的火枪。",
    "sailor": "英国水兵：条纹衬衫、宽口帆布裤、光脚或短靴，拿一把短弯刀。",
    "marine_sharpshooter": "蹲在桅盘上的陆战队射手，红上衣，长管火枪，身边缠着缆绳。",
    "boatswain": "英国水手长：蓝色短外套，脖子上挂一只银哨，手里一根短棍。",
    "pirate": "海盗：扎头巾、敞着衬衫，持短刀和手枪。",
    "pirate_captain": "海盗船长：长外套、三角帽、两把手枪。",
    "coast_gun": "石砌胸墙后面一门大口径岸防炮，两名炮手。",
    "carronade": "舰上的短粗卡隆炮，装在滑动炮架上，一名水兵炮手。",
    "gunboat": "一条装一门炮的划桨炮艇，四名水手（用船体网格，站在海格上）。",
    "raider_captain": "罗伯茨舰长（红胡子摩根）：红色大胡子、海盗打扮下面露出英国海军军官的衬衫领子，持军刀。",
    "royalist_bravo": "1815 年的保王党打手：便服、白帽徽、短棍或匕首。",
    "royalist_marksman": "保王党枪手：便服、白帽徽，持猎枪。",
    "chouan": "布列塔尼朱安党老兵：宽檐帽、山羊皮外套、胸前别着圣心徽，持长枪。",
    "royalist_chief": "保王党头目：深色外套、白色肩带、白帽徽，持军刀。",
    "bow_runner": "伦敦弓街来的便衣探员：灰外套、高顶礼帽，手里一根包铁的短棍和一副手铐。",
    "jack_runner": "独眼杰克：伪装成水手的弓街侦探，一只眼罩，水手外套下面露出探员的手铐。",
    "redcoat_grenadier": "英军掷弹兵连：红上衣、熊皮帽或高筒帽，白交叉背带，持带刺刀的火枪。",
    "mounted_orderly": "骑马的英军传令兵：红上衣、黑色圆帽，骑一匹海岛小马，持马刀。",
    "coast_sniper": "趴在崖顶或屋顶上的英军步枪兵：绿上衣，长管步枪。",
    "pirate_brute": "海盗打手：魁梧、赤膊、纹身，扛一把登船斧。",
    "diver": "1830 年代英国头盔潜水员：铜头盔、帆布潜水服、铅底靴，手里一根撬棍，头盔后面拖着气管。",
    "harpoon_diver": "拿鱼叉枪的潜水员：铜头盔、帆布潜水服。",
    "smith_agent": "史密斯：穿潜水服的海军部特务，头盔面窗里是一张平淡的脸，手里一把短刀。",
    "shark": "一条灰色的鲨鱼（游在海床上方，用游动代替走路）。",
    "great_shark": "一条巨大的白鲨。",
    "squid": "巨型章鱼（凡尔纳原著第二部第十八章那种）：红褐色、巨大的眼睛，几条触手举在空中。",
    "squid_arm": "一条从舷边伸上来的巨型章鱼触手（只画触手）。",
    "sealer": "1820–30 年代南极海域的捕海豹船员：厚毛皮外套、毛线帽，持一根带钩的棍子。",
    "harpooner": "捕鲸船的鱼叉手：油布外套，举着一支鱼叉。",
    "sealer_boss": "海豹船船长：熊皮大衣、长胡子，持手枪。",
    "navy_captain": "1830 年代皇家海军舰长：蓝色双排扣制服、金肩章、双角帽，持军刀。",
    "rocket_boat": "一条装康格里夫火箭架的小艇（用船体网格，站在海格上）。",
    "steam_sloop": "1830 年代皇家海军的明轮蒸汽炮舰：黑色船身、两侧大明轮、一根烟囱冒黑烟（用船体网格，站在海格上，比炮艇大一号）。",
}
PROPS = [
    ("galleon_wreck", "沉船残骸", "1702 年西班牙运宝船的一段船身：断裂的船肋、长满藤壶，沿 X 方向躺倒。", [1.0, 0.6, 1.0]),
    ("diving_bell", "潜水钟", "英国人放下来的铸铁潜水钟，挂着缆绳，底部敞开。", [0.8, 1.2, 0.8]),
    ("kelp", "海带", "一丛长长的海带，向上飘。", [0.4, 0.9, 0.4]),
    ("temple_column", "神庙石柱", "亚特兰蒂斯神庙的一根倒塌或半截的石柱，长满珊瑚。", [0.6, 1.2, 0.6]),
    ("searchlight_dome", "探照灯罩", "鹦鹉螺号平台上凸起的透镜灯罩，黄铜框、厚玻璃，里面亮着冷光。", [0.8, 0.6, 0.8]),
    ("signal_mast", "信号旗杆", "圣赫勒拿信号站的旗杆，横桁上挂着几面彩色信号旗。", [0.4, 1.4, 0.4]),
    ("ice_ridge", "压力冰脊", "两块浮冰挤出来的一道冰脊，青白色。", [1.0, 0.9, 0.6]),
    ("army_tent", "营帐", "英军驻军的白色帆布帐篷（死木平原营地，代替村庄格的房子）。", [0.9, 0.8, 0.9]),
    ("powder_magazine", "火药库", "石砌的小火药库，铁门，门口一盏马灯（死木平原营地的石墙格）。", [0.9, 0.9, 0.9]),
]
TEX = [
    ("tex", "seabed_sand", "海床细沙", "海底的细沙，偏青灰，夹贝壳碎片，表面有细小的波纹（不要有方向性的大波纹）。", "beach, sand（主题 seabed）"),
    ("tex", "seabed_silt", "海床淤泥", "海底的暗绿色淤泥，夹海草碎屑。", "shallows（主题 seabed）"),
    ("tex", "nautilus_plating", "鹦鹉螺号钢板", "铆钉钢板拼成的甲板，深灰带一点青铜色，铆钉排成整齐的网格。", "deck（主题 nautilus）"),
    ("tex", "ice_floe", "浮冰", "积了薄雪的浮冰顶面，青白色，夹细小的裂纹。", "ice（ice_shelf）"),
    ("side", "side_steel", "钢板侧面", "鹦鹉螺号船壳的侧面：铆钉钢板，下面没进黑色的海水。", ""),
]
THEMES = {
    "_doc": "同一个地形字符在不同战场上要换皮：模板加一个可选键 theme（B 定），field_terrain.gd 按主题换贴图和摆件，规则不变。",
    "seabed": {"templates": ["vigo_seabed", "atlantis"], "swap": {"beach": "tex:seabed_sand", "sand": "tex:seabed_sand", "shallows": "tex:seabed_silt", "wall": "prop:temple_column",
                                                                  "mast": "prop:galleon_wreck", "void": "海沟：不建地块，底座外圈画成往下沉的黑色"}, "fx": "水下：蓝绿雾、上方光柱、气泡粒子"},
    "nautilus": {"templates": ["nautilus_deck_raid", "squid_platform", "thames_estuary"], "swap": {"deck": "tex:nautilus_plating", "quarterdeck": "prop:searchlight_dome"}, "fx": ""},
    "garrison": {"templates": ["deadwood_camp"], "swap": {"village": "prop:army_tent", "wall": "prop:powder_magazine"}, "fx": "夜里营火"},
    "signal": {"templates": ["signal_hill"], "swap": {"mast": "prop:signal_mast"}, "fx": ""},
    "ice": {"templates": ["ice_shelf"], "swap": {"ice": "tex:ice_floe", "wall": "prop:ice_ridge"}, "fx": "雪粒子"},
}


def main():
    upd = []
    for kind, id, name, desc, why in UPDATE:
        old = have.get((kind, id))
        if not old:
            raise SystemExit("missing %s/%s in art_list" % (kind, id))
        e = {"kind": kind, "id": id, "desc": desc, "_why": why, "_old_desc": old.get("desc", "")}
        if name:
            e["name"] = name
            e["_old_name"] = old.get("name", "")
        upd.append(e)
    add = list(ADD)
    for id, name, desc in CHARA:
        add.append({"kind": "chara", "id": id, "name": name, "priority": "P3", "desc": desc, "used_in": ["ocean events"]})
        add.append({"kind": "face", "id": id, "name": name, "priority": "P3", "desc": "同一人物的头像，和立绘用同一个模型。"})
    for eid, en in ENEMIES.items():
        if ("unit", "enemy_" + eid) in have:
            continue
        desc = ENEMY_DESC.get(eid)
        if not desc:
            continue
        pr = "P1" if en.get("src") == "arch" or eid in ("diver", "shark", "squid_arm", "redcoat_grenadier") else "P2"
        u = {"kind": "unit", "id": "enemy_" + eid, "name": en["name"], "priority": pr, "desc": desc + "单人。" if en["type"] not in ("gun",) else desc, "role": "enemy"}
        if en.get("move") == "boat" or "boat" in en["tags"]:
            u["note"] = "站在海格上：画船，不画脚；锚点放在吃水线。"
        add.append(u)
        add.append({"kind": "face", "id": "enemy_" + eid, "name": en["name"] + "（敌人头像）", "priority": "P2", "desc": "敌人信息栏的头像。" + desc})
    for id, name, desc, size in PROPS:
        add.append({"kind": "prop", "id": id, "name": name, "priority": "P2", "desc": desc, "max_size": size})
    for kind, id, name, desc, terr in TEX:
        e = {"kind": kind, "id": id, "name": name, "priority": "P2", "desc": desc}
        if terr:
            e["terrain"] = terr
        add.append(e)
    clash = [(a["kind"], a["id"]) for a in add if (a["kind"], a["id"]) in have]
    if clash:
        raise SystemExit("ids already in art_list: %s" % clash)
    doc = {
        "_doc": "远洋分支的美术需求（ARCH §8.4：art_list.json 只由 B 写，A、C 的需求放 data/hd/art_requests/<包>.json）。update：已有条目只改 name/desc（id 不改，_old_* 是原文，合并时丢掉）；add：新条目，形状同 art_list.json 的 assets。"
                "ARCH §4.6 已经替 B 列了通用地形贴图、摆件、地图节点圆章和 map_world 底图，这里只列远洋专用、那张清单里没有的。themes 是给 B 的提议：同一地形在海底和潜艇甲板上换皮。",
        "package": "C-ocean",
        "update": upd,
        "add": add,
        "themes": THEMES,
        "depends_on_B": ["bg/map_world（ARCH §4.6）", "tex 与 prop：deck_planks、quarterdeck_planks、sea、shallows、reef、beach、cave_floor、dock_planks、plank、hatch、sand、dune_top、snow、mud、ice、cobbles、building_floor、roof_tiles、rubble、mast、rigging_top、ship_rail、ship_cannon、reef_rocks、palm、well、ice_cracks（ARCH §4.6）", "icon/*（11 种节点圆章）"],
    }
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=1)
    print("wrote", OUT, "update", len(upd), "add", len(add))


if __name__ == "__main__":
    main()
