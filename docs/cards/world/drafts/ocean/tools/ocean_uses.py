# Where each ocean template is used in the napoleon book, at which level, and a reference plan
# (how a reasonable player wins it). Levels follow ARCH §3.1: prologue L13, then the four chapter
# bosses climb 13 -> 16 -> 20 -> 24; inside a chapter battle <= boss-2, elite <= boss-1.

# scene_battles for book.json (segment "ocean"). template "" = this scene has no battle in the napoleon
# book (needs A to treat an empty template as "no battle"); "_fallback" is what to use if A does not.
SCENE_BATTLES = {
    "prologue": {"template": "bellerophon_deck", "level": 13},
    "scene01": {"template": "", "level": 0, "_fallback": {"template": "signal_hill", "level": 14}},
    "scene02": {"template": "jamestown_streets", "level": 14},
    "scene03": {"template": "", "level": 0, "_fallback": {"template": "beach_landing", "level": 14}},
    "scene04": {"template": "sea_cave", "level": 15},
    "scene05": {"template": "longwood_escape", "level": 16},
    "scene06": {"template": "shipwreck_beach", "level": 17},
    "scene07": {"template": "", "level": 0, "_fallback": {"template": "reef_crossing", "level": 18}},
    "scene08": {"template": "viper_boarding", "level": 19},
    "scene09": {"template": "skull_reef", "level": 20},
    "scene10": {"template": "", "level": 0, "_fallback": {"template": "nautilus_deck_raid", "level": 21}},
    "scene11": {"template": "vigo_seabed", "level": 22},
    "scene12": {"template": "atlantis", "level": 22},
    "finale": {"template": "thames_estuary", "level": 24},
}

CHAPTER_BOSS = {"prologue": 13, "st_helena": 16, "new_elba": 20, "nautilus": 24}
SCENE_CHAPTER = {"prologue": "prologue", "scene01": "st_helena", "scene02": "st_helena", "scene03": "st_helena",
                 "scene04": "st_helena", "scene05": "st_helena", "scene06": "new_elba", "scene07": "new_elba",
                 "scene08": "new_elba", "scene09": "new_elba", "scene10": "nautilus", "scene11": "nautilus",
                 "scene12": "nautilus", "finale": "nautilus"}

# fixed map battle nodes (maps/world.json) that are not story anchors
MAP_BATTLES = {
    "deadwood_camp": {"sheet": "st_helena", "node": "deadwood_raid", "type": "elite", "level": 15},
    "squid_platform": {"sheet": "nautilus", "node": "bahamas_squid", "type": "elite", "level": 23},
    "ice_shelf": {"sheet": "nautilus", "node": "ice_barrier", "type": "battle", "level": 21},
}

# battle_pool for book.json: random battle slots draw from the band that contains the slot's level
BATTLE_POOL = {
    "ocean": {
        "13-16": ["signal_hill", "beach_landing"],
        "17-20": ["beach_landing", "reef_crossing"],
        "21-24": ["reef_crossing", "nautilus_deck_raid"],
    }
}

PLANS = {
    "bellerophon_deck": "所有路线最后都挤进 B3、B4 两格。B3 放掷弹兵、B4 放战列，C3、C4 再各压一支战列做纵深；炮兵上艉楼 B2、B5，各管一条舷道；猎兵上后桅盘 D3（射程 +1，同时照顾舱口路和右舷）。"
                        "第 3 回合起三路同时到，C 列要先有人挡第一波，不能全缩在 B 列。第 4、9 回合舱口出来的刺客是猎官：主角站 A2 或 A5 艉楼，身边留一名伙伴。G1、C1 快艇开炮前一回合亮准星，被瞄的单位后撤或打佯动。",
    "jamestown_streets": "两条街在 B 列各放一支战列（B2、B4），小巷口 C3 放掷弹兵，同时守密令格；猎兵上屋顶 C1、F1，往下打两条街和 F3 小巷。房屋可以进驻（防 +2，挡视线），军医放进 B1 或 B3。"
                         "弓街探员和独眼杰克带逮捕：主角在他们的白刃下倒下直接被捕，要上就站进屋子里。第 4 回合的传令骑兵是猎官，速 2。雨天小火器攻 −1，又没有高地给炮兵，这一仗靠白刃和屋顶猎兵。",
    "sea_cave": "北路蹚一格浅水、南路蹚三格，挡人只能挡在沙滩、码头和洞里。北路在 F2 放掷弹兵，南路在 F3 放战列，码头 E3（密令格）压一支战列做最后一道。炮兵和猎兵上崖顶 D1、E1（F1 开场就被狙击手占着）。"
                "洞里的单位不挨敌炮、挨远程防 +2，但洞穴挡视线：军医和主角放进洞深处 B2、B3 最稳。I3 炮艇每 2 回合一炮，开炮前亮准星。",
    "deadwood_camp": "大路第 2 行、南路第 4 行，北坡 I1 下来在 H2 并进大路。帐篷 E3、G3 第 3、5 回合冒出伏兵，tent_e 正好从密令格 D3 过：D3 放掷弹兵（挡伏兵也守密令），B2、B4 各一支战列守两条路的尽头。"
                     "炮兵上 B3（石墙 C3 挡视线，但炮是曲射），D1、D5 再放一门炮或猎兵；猎兵上 A1、A5 打边路。H5 营炮第 4 回合开第一炮。",
    "longwood_escape": "四条路，两条斜插。花园土丘 D3、E3 是唯一能同时打到三条路的炮位，两门炮都放这里。A 列四面鹰旗前，B2、B4、B5 各放一支战列，掷弹兵放 C2（大路和斜插 cross 在 G2 并道）；B1、A6、B6 高地放猎兵打边路。"
                       "泥地步耗 2，敌人在 G2、F4、H5（第 7 回合后还有 D2、D4）会慢下来，在泥地后一格放阻挡最划算。猎官步枪手瞄主角：主角站 A1 高地，身边留一名伙伴护卫。",
    "shipwreck_beach": "三条滩，外加一条从北滩折进沉船的路。沉船甲板 E2 是密令格，也堵着折进来的 cross 路：E2 放掷弹兵。北滩 B1、南滩 B4 是树林，放战列（挨远程防 +2）；中路 C3 放战列，瓦砾 D3 让敌人慢一步。"
                       "炮兵上沙丘 C2，猎兵上 A2。水兵速 2，先挡北滩；海盗带掠夺，漏一个战后法郎 −15%。",
    "viper_boarding": "我方鹰旗是背后的三处登船口 A1、A3、A5。左右舷道（第 1、5 行）各在 B 列放战列、C 列放掷弹兵；前舱口 E3 出来的人只走第 3 行，D3 放战列挡住。主舱口 H3 出来的人先过密令格 G3：G3 放伙伴近战或骠骑兵，第 9 回合前一定要有人站在那里。"
                      "没有高地，炮兵上不了船，猎兵上 C2、C4 前桅盘。I2（第 21 级起还有 I4）卡隆炮只打 E 列以右：守 G3 的人要扛炮，开炮前一回合换人或打佯动。",
    "skull_reef": "所有路线在 F 列汇合，再分成第 2、3、5 行三股冲向鹰旗。F3（四条路经过）放掷弹兵，F4 放掷弹兵或伙伴近战，F2、F5 各一支战列，B 列再留两支纵深。炮兵上骷髅岩 E4（中央，能打三行）和 G2 或 G5（紧挨跳板，最狠也最危险）。"
                  "第 8 回合涨潮，B2、B5 沙滩没进浅水，别在那两格放人。罗伯茨舰长第 10 回合才从跳板梯下来：留一张佯动或一次刺刀冲锋给他。",
    "atlantis": "没有炮也没有远程，压力全在白刃。E2 是密令格，也是 north、mid 两路的必经格：掷弹兵守 E2，D2 碎石后面再放一支战列（敌人在碎石上慢一步）；low、south 两路在 G3 并道，F3 放掷弹兵或伙伴近战，B3 再放战列。"
                "大白鲨和章鱼触手带穿透：一支掷弹兵挡两条触手，战列只挡一条。炮兵上 E4 台阶最稳，F1 第 4 回合会塌。鲨鱼是猎官，主角最好不上。",
    "squid_platform": "五条路收成三股：第 2 行（n_aft）、第 3 行（n_bow、s_bow、ram）、第 4 行（s_aft）。第 3 行最重：B3、C3、D3 连放三支，掷弹兵在最前。触手带穿透，一支掷弹兵挡两条、战列挡一条，必须纵深。B2、B4 各一支战列。"
                      "炮兵上罗经罩 G2 或小艇舱盖 G4，离舷边近，触手刚爬上来就打。章鱼带处决：伙伴别站在章鱼的路上。",
    "thames_estuary": "左边 A–F 列是鹦鹉螺号，五个舱口 A2–A6 是鹰旗。真正的压力是从跳板 G2、G4、G6 直接上船的陆战队：每条跳板路在 F 列落地，F2、F4、F6 各放一支掷弹兵或战列，B 列再留纵深。"
                      "岸上走来的路要蹚浅水和泥滩，很长，交给炮兵：探照灯罩 D4 是中央炮位，艉舵塔 B1、B7 放炮或猎兵打第 2、6 行。K1、L1 屋顶狙击手、L7 岸防炮和第 11 回合来的明轮炮舰都会挑人打，开炮前看准星挪人。雾天来敌少公开一回合。",
    "signal_hill": "山脊大路（第 2 行）和坡下小路（第 3 行）各在 B 列放一支战列；传令骑兵从山顶 H1 绕到 G2 并进大路，D2 再放一支挡。D1 密令格在信号杆旁、不在路上，放一支地面单位就行，但它挨着大路，远程会打它。"
                   "炮兵上 C1（打第 1、2 行）或 C4（打第 3 行），猎兵上 G4，离敌人入口最近，射得最早。",
    "beach_landing": "三条登陆线都要先蹚两格浅水，上了沙滩才挡得住：北线在 E1，中线在 E3，南线在 E4 上岸后从 C4 拐上第 3 行。C3 是中线和南线的并道口：E3、C3 各放一支战列，北线 C1 放一支。炮兵上沙丘 E2（离海最近，G2 炮艇会打它）或 B4，猎兵上 B4。水兵速 2，蹚水一回合就上岸。",
    "reef_crossing": "北路和中路都要绕礁蹚水，在 D2、C2 合流后才分开：这两格是两路的咽喉，C2 又是密令格，掷弹兵守 C2、战列守 D2。南滩第 4 行最快，B4、C4 两支战列。炮兵上沙丘 A2（唯一高地，打第 2 行）。第 4 回合 E4 没进浅水，站在那里的人会退回部署栏。",
    "ice_shelf": "三条路平行穿过冰原，只有 C1、B4 两座冰塔是高地。雪天军令点每回合只有 2（主角在场 3），部署要省：B2、B3 各一支战列，C3（密令格）放掷弹兵；炮兵上 C1，能打第 2、3 行。第 3 回合 E1、第 5 回合 E4 裂成海，别在这两格放人。捕鲸叉手是狙击手，专打主角和伙伴。",
    "nautilus_deck_raid": "六条路里五条最后要过 D2→D3 进舱口 A3，只有 plank_e 从 E4 上来走 E3。D3 放掷弹兵、D2 放战列，C3 再留纵深；E3 一支战列挡 plank_e。炮兵上探照灯罩 C2（正对第 2 行）或舷窗罩 F3。I4 炮艇开炮前亮准星；雾天来敌少公开一回合。",
    "vigo_seabed": "货舱口 E3 冒出来的人（第 3 回合的史密斯、第 7 回合的一伙）先踩密令格 D3：D3 放掷弹兵，既守密令又堵舱口。第 2、4 两条主路各在 C 列放一支战列、B 列留纵深。"
                   "H1、H5 礁岩是前哨炮位，第 5 回合 H2、H4 冲成淤泥后前哨就被隔开——只放猎兵，撑到第 4 回合就撤。C3 倒扣的艉楼是安全炮位，能打第 2、3、4 行。鲨鱼速 2 是猎官，主角别下水。",
}
