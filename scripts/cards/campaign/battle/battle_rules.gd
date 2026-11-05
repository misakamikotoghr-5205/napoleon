## 拿破仑篇·战斗规则 v2（2026-11-01，Claude）
## 明日方舟式的格子部署，但是回合制：每回合 ① 敌情 → ② 指挥（不限时、可撤销）→ ③ 交火 a–e。
## 纯逻辑：extends RefCounted，只有静态函数，不建节点，不用 class_name；别处用 preload。
## 状态是一个 Dictionary，只放整数 / 字符串 / 布尔 / 数组 / 字典，没有浮点；整数运算一律向下取整。
## 战斗中没有随机数。随机只有两处：进场时的模板浮动（波次构成、牌序）和战后的命悬一线铜钱，
## 都来自 state.seed 的 xorshift32，同一个状态永远给出同一个结果。
## 坐标：col / row 从 0 开始；界面标签 A1 = (0, 0)，列 A 是我方鹰旗一侧，行 1 在最上。
## 规则说明：docs/cards/BATTLE_V2.md；设计依据：docs/cards/NAPOLEON_DESIGN.md。
## 第五片（《鹰旗军需官》，WORLD_MAP_DESIGN §8–§10）：全局等级 L1–24、40 种地形（视线 / 顶层 / 黑暗 / 洞穴 / 事件改地形 / 击杀改地形）、
## 8 种天时、15 个新标签、111 种敌军、最大 12×7。旧调用（setup 只给 act）的状态和结算逐字节不变：
## 新键（level / weather / loot / ransom / killed_kinds）只出现在新接口开的仗里（setup 给了 level、weather 或 mods）。
## 新加的中文都在 data/campaigns/battle_text.json 和 battle_enemies.json 里，代码里不写中文字面量。
extends RefCounted

const Pairs := preload("res://scripts/cards/campaign/battle/battle_pairs.gd")

const TEMPLATES_PATH := "res://data/campaigns/battle_templates.json"
const ENEMIES_PATH := "res://data/campaigns/battle_enemies.json"
const TEXT_PATH := "res://data/campaigns/battle_text.json"
const HERO := "hero"
const MAX_LOG := 80
const CP_CAP := 20
const HAND_SIZE := 3
const MAX_LEVEL := 24

const DIRS := {"right": [1, 0], "left": [-1, 0], "up": [0, -1], "down": [0, 1]}
const LATERAL := {"right": [0, 1], "left": [0, -1], "up": [1, 0], "down": [-1, 0]}
const FACING_NAMES := {"right": "朝右", "left": "朝左", "up": "朝上", "down": "朝下"}

## 新接口要用到的中文（新规模、新地形、天时的名字和新日志句子）：先于下面依赖它的 static var 声明
static var _text_cache: Dictionary = {}

## 旧三档（字节不变）；SCALES = 这三档 + 大会战 / 决战（名字在 battle_text.json）
const BASE_SCALES := {
	"skirmish": {"name": "遭遇战", "cols": 7, "rows": 3, "field": [5, 5, 5, 5, 5, 5], "companions": [2, 2, 2, 2, 2, 2], "franc": 50, "medal": 1, "gold": 0},
	"elite": {"name": "精英战", "cols": 8, "rows": 4, "field": [6, 6, 6, 6, 6, 6], "companions": [3, 3, 3, 3, 3, 3], "franc": 90, "medal": 2, "gold": 0},
	"major": {"name": "会战", "cols": 9, "rows": 5, "field": [7, 7, 8, 8, 9, 9], "companions": [4, 4, 4, 5, 5, 5], "franc": 200, "medal": 3, "gold": 1},
}
## §8.1：大会战 10×6、决战 12×7。L ≤ 11 的名额数组是本稿补的（设计稿只给了 L ≥ 12），和 L12 的名额接得上
const EXTRA_SCALES := {
	"grand": {"cols": 10, "rows": 6, "field": [8, 8, 9, 9, 10, 10], "companions": [4, 4, 5, 5, 5, 5], "franc": 260, "medal": 4, "gold": 1},
	"epic": {"cols": 12, "rows": 7, "field": [9, 9, 10, 10, 11, 11], "companions": [5, 5, 5, 6, 6, 6], "franc": 320, "medal": 5, "gold": 2},
}
static var SCALES: Dictionary = _build_scales()
## 皇帝的命令、主角奖赏 +2 勋章这些「会战」待遇：会战、大会战、决战都算
const BOSS_SCALES := ["major", "grand", "epic"]
## §8.1 名额 caps(scale, L)：L ≤ 11 取 field / companions 数组的第 (L+1)/2 项；L ≥ 12 按这张表（[起始 L, 在场, 伙伴]，取最后一个够得着的）
const CAPS_HIGH := {
	"skirmish": [[12, 5, 2], [13, 6, 2]], "elite": [[12, 6, 3], [13, 7, 3]], "major": [[12, 9, 5]],
	"grand": [[12, 10, 5], [19, 11, 6]], "epic": [[12, 11, 6], [19, 12, 6]],
}
## 难度曲线（第 1–6 幕）：敌兵力倍率、敌军心倍率（里沃利 24 → 26/28/32/34/40）、敌攻加成。
## 只为兼容保留：它们正好是 LEVELS 的 L1/3/5/7/9/11 行，规则内核现在只看 LEVELS。
const ACT_HP_PCT := [100, 115, 130, 145, 160, 180]
const ACT_MORALE_PCT := [100, 109, 117, 134, 142, 167]
const ACT_ATK_BONUS := [0, 0, 1, 1, 2, 2]

## §8.1 等级表，下标 L−1。列见 LEVEL_KEYS；猎官 / 精英 / 回合几列是模板编写目标（lint_template 提醒），运行时不硬改
const LEVEL_KEYS := ["hp_pct", "morale_pct", "atk", "def", "boss_hunters", "boss_elites", "elite_hunters", "skirmish_hunters",
	"boss_turns", "elite_turns", "skirmish_turns", "stars"]
const LEVELS := [
	[100, 100, 0, 0, 0, 1, 0, 0, 11, 8, 6, 1], [108, 104, 0, 0, 0, 1, 0, 0, 11, 8, 6, 1],
	[115, 109, 0, 0, 1, 2, 0, 0, 11, 8, 6, 1], [122, 113, 0, 0, 1, 2, 0, 0, 11, 8, 6, 1],
	[130, 117, 1, 0, 1, 2, 0, 0, 11, 8, 6, 1], [137, 125, 1, 0, 1, 2, 0, 0, 11, 8, 6, 2],
	[145, 134, 1, 0, 2, 3, 0, 0, 12, 8, 6, 2], [152, 138, 1, 0, 2, 3, 0, 0, 12, 8, 6, 2],
	[160, 142, 2, 0, 2, 3, 1, 0, 12, 8, 6, 2], [170, 154, 2, 0, 2, 3, 1, 0, 12, 8, 6, 2],
	[180, 167, 2, 0, 3, 4, 1, 0, 12, 8, 6, 3], [188, 172, 2, 0, 3, 4, 1, 0, 12, 8, 6, 3],
	[196, 177, 3, 0, 3, 4, 1, 1, 13, 9, 7, 3], [204, 182, 3, 0, 3, 4, 1, 1, 13, 9, 7, 3],
	[212, 187, 3, 1, 4, 5, 1, 1, 13, 9, 7, 3], [220, 192, 3, 1, 4, 5, 1, 1, 13, 9, 7, 4],
	[228, 197, 4, 1, 4, 5, 2, 1, 13, 9, 7, 4], [236, 202, 4, 1, 4, 5, 2, 1, 13, 9, 7, 4],
	[244, 207, 4, 1, 5, 6, 2, 1, 14, 9, 7, 4], [252, 212, 4, 1, 5, 6, 2, 1, 14, 9, 7, 4],
	[260, 217, 5, 2, 5, 6, 2, 2, 14, 9, 7, 5], [270, 222, 5, 2, 5, 6, 2, 2, 14, 9, 7, 5],
	[280, 227, 5, 2, 6, 6, 2, 2, 14, 9, 7, 5], [290, 232, 5, 2, 6, 6, 2, 2, 14, 9, 7, 5],
]

## §9.1 地图字符（40 种，含预先筑好的胸墙 +）
const TERRAIN_CHARS := {
	".": "plain", "^": "high", "=": "road", "v": "village", "w": "woods", "~": "river",
	"b": "bridge", "f": "ford", "m": "marsh", "G": "gate", "E": "eagle", "+": "earthwork",
	"_": "void", "#": "wall", ";": "rubble", "s": "snow", "u": "mud", "i": "ice", "a": "sand", "n": "dune", "o": "well",
	"d": "deck", "q": "quarterdeck", "t": "rigging", "|": "mast", "W": "sea", "-": "shallows", "*": "reef", ",": "beach",
	"c": "cave", "k": "dock", "p": "plank", "H": "hatch", "S": "street", "B": "building", "R": "rooftop",
	"C": "corridor", "L": "cell", "D": "door", "K": "catacomb",
}
## §9.1 地形规则表（顺序就是下面 GROUND / HIGH / ENEMY_WALK 的顺序，旧地形在前）：
##   stand 我方站位 ground / high / top / none；walk 敌人沿路线能不能走（红门、牢门「途经」也算能走）；cost 步耗；
##   def 双方的防 +；rdef 挨远程时防 +；los 挡视线；tier 层（虚空 −1）；start 路线起点（红门、舱口、牢门）；
##   end 路线终点（鹰旗）；dark 黑暗；spawn 伏兵格（spawns 只能列这些格子）
const TERRAIN := {
	"plain": {"ch": ".", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"high": {"ch": "^", "stand": "high", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 2},
	"road": {"ch": "=", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"village": {"ch": "v", "stand": "ground", "walk": true, "cost": 1, "def": 2, "rdef": 0, "los": false, "tier": 1, "spawn": true},
	"woods": {"ch": "w", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 2, "los": false, "tier": 1, "spawn": true},
	"river": {"ch": "~", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 0},
	"bridge": {"ch": "b", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"ford": {"ch": "f", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"marsh": {"ch": "m", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 0},
	"gate": {"ch": "G", "stand": "none", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "start": true},
	"eagle": {"ch": "E", "stand": "none", "walk": false, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "end": true},
	"earthwork": {"ch": "+", "stand": "high", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 2},
	"void": {"ch": "_", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": -1},
	"wall": {"ch": "#", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": true, "tier": 3},
	"rubble": {"ch": ";", "stand": "ground", "walk": true, "cost": 2, "def": 1, "rdef": 0, "los": false, "tier": 1},
	"snow": {"ch": "s", "stand": "ground", "walk": true, "cost": 2, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"mud": {"ch": "u", "stand": "ground", "walk": true, "cost": 2, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"ice": {"ch": "i", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"sand": {"ch": "a", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"dune": {"ch": "n", "stand": "high", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 2},
	"well": {"ch": "o", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"deck": {"ch": "d", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"quarterdeck": {"ch": "q", "stand": "high", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 2},
	"rigging": {"ch": "t", "stand": "top", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 3},
	"mast": {"ch": "|", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": true, "tier": 3},
	"sea": {"ch": "W", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 0},
	"shallows": {"ch": "-", "stand": "none", "walk": true, "cost": 2, "def": 0, "rdef": 0, "los": false, "tier": 0},
	"reef": {"ch": "*", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 0},
	"beach": {"ch": ",", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"cave": {"ch": "c", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 2, "los": true, "tier": 1},
	"dock": {"ch": "k", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1},
	"plank": {"ch": "p", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "spawn": true},
	"hatch": {"ch": "H", "stand": "none", "walk": false, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "start": true},
	"street": {"ch": "S", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "spawn": true},
	"building": {"ch": "B", "stand": "ground", "walk": false, "cost": 0, "def": 2, "rdef": 0, "los": true, "tier": 1},
	"rooftop": {"ch": "R", "stand": "top", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 3},
	"corridor": {"ch": "C", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "dark": true},
	"cell": {"ch": "L", "stand": "ground", "walk": false, "cost": 0, "def": 1, "rdef": 0, "los": false, "tier": 1},
	"door": {"ch": "D", "stand": "none", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "start": true},
	"catacomb": {"ch": "K", "stand": "ground", "walk": true, "cost": 1, "def": 0, "rdef": 0, "los": false, "tier": 1, "dark": true, "spawn": true},
}
## 不认识的地形 id 按这一行算（谁都不能站、不能走）
const NO_TERRAIN := {"ch": "?", "stand": "none", "walk": false, "cost": 0, "def": 0, "rdef": 0, "los": false, "tier": 0}
## 旧 12 种地形的名字（字节不变）；TERRAIN_NAMES = 这 12 种 + battle_text.json 的 28 种
const BASE_TERRAIN_NAMES := {
	"plain": "平地", "high": "高地", "road": "道路", "village": "村庄", "woods": "树林", "river": "河",
	"bridge": "桥", "ford": "浅滩", "marsh": "沼泽", "gate": "红门", "eagle": "鹰旗", "earthwork": "胸墙",
}
static var TERRAIN_NAMES: Dictionary = _build_terrain_names()
## 由 TERRAIN 推出：GROUND / HIGH / TOP 是三种站位；ENEMY_WALK 是敌人能站的格子（能走的 + 起点 + 鹰旗）。旧地形的成员和顺序不变
static var GROUND: Array = _terrain_list("stand", "ground")
static var HIGH: Array = _terrain_list("stand", "high")
static var TOP: Array = _terrain_list("stand", "top")
static var ENEMY_WALK: Array = _enemy_walk_list()

## §9.3 天时（开战时定下，战斗中不变）
const WEATHERS := ["clear", "rain", "mud", "snow", "fog", "night", "desert", "storm"]
## 内核认识的标签：旧四个 + §10 的 15 个
const KNOWN_TAGS := ["hunter", "heavy", "officer", "execute", "pierce", "skirmisher", "ambush", "boarder", "post", "top", "stealth",
	"loot", "ransom", "arrest", "rally", "boat", "short", "rocket", "sniper"]
## mods（§6.6）每个键的取值范围
const MOD_RANGES := {"cp_bonus": [0, 4], "enemy_morale": [-4, 0], "prep_turn": [0, 1]}

## 我方兵种（第一幕部队数值；伙伴在 setup 里给自己的数值）。top：能上顶层（桅盘、屋顶）
const CLASSES := {
	"line": {"name": "战列步兵", "cost": 4, "hp": 14, "atk": 4, "def": 1, "block": 2, "place": "ground", "skill": ""},
	"grenadier": {"name": "掷弹兵", "cost": 6, "hp": 20, "atk": 4, "def": 3, "block": 3, "place": "ground", "skill": "bayonet_charge"},
	"jager": {"name": "猎兵", "cost": 3, "hp": 8, "atk": 4, "def": 0, "block": 0, "place": "high", "skill": "", "top": true},
	"hussar": {"name": "骠骑兵", "cost": 3, "hp": 10, "atk": 5, "def": 1, "block": 1, "place": "ground", "skill": ""},
	"artillery": {"name": "炮兵", "cost": 7, "hp": 8, "atk": 6, "def": 0, "block": 0, "place": "high", "skill": ""},
	"medic": {"name": "军医", "cost": 3, "hp": 10, "atk": 0, "def": 1, "block": 0, "place": "any", "skill": ""},
	"engineer": {"name": "工兵", "cost": 3, "hp": 14, "atk": 3, "def": 2, "block": 1, "place": "ground", "skill": "fortify"},
	"drummer": {"name": "鼓手", "cost": 3, "hp": 8, "atk": 1, "def": 0, "block": 1, "place": "ground", "skill": ""},
	"hero": {"name": "军需官", "cost": 0, "hp": 12, "atk": 2, "def": 1, "block": 1, "place": "any", "skill": "pay_chest"},
	"barricade": {"name": "拒马", "cost": 0, "hp": 8, "atk": 0, "def": 0, "block": 2, "place": "ground", "skill": ""},
}
const SKILLS := {
	"bayonet_charge": {"name": "刺刀冲锋", "charge": 3, "desc": "挡住的敌人全部击退 1 格，各受 5 伤。"},
	"fortify": {"name": "筑垒", "charge": 2, "desc": "相邻一格放拒马（阻挡 2，兵力 8），或把相邻平地筑成胸墙（高地）。"},
	"mark_target": {"name": "点名", "charge": 3, "desc": "对射程内一个敌人造成 8 点伤害。"},
	"raise_flag": {"name": "举旗", "charge": 3, "desc": "本行友军攻 +2，持续 2 回合。"},
	"pay_chest": {"name": "开箱发饷", "charge": 4, "desc": "军令点 +3，军心 +1。"},
}

## 第一幕奥军（字节不变）。type 决定击杀扣敌军心：步兵/弹药车 −1，骑兵/炮 −2，精英 −3，纵队长 −4。
## ENEMIES = 这 7 种 + battle_enemies.json 的另外 104 种（§10 定稿，名字是玩家看得见的字，所以放 JSON）
const BASE_ENEMIES := {
	"whitecoat": {"name": "白衣步兵", "hp": 6, "atk": 3, "def": 1, "spd": 1, "type": "infantry", "range": 0, "tags": []},
	"grenz": {"name": "格伦茨猎兵", "hp": 5, "atk": 3, "def": 0, "spd": 1, "type": "infantry", "range": 2, "tags": []},
	"dragoon": {"name": "龙骑兵", "hp": 10, "atk": 5, "def": 1, "spd": 2, "type": "cavalry", "range": 0, "tags": ["hunter"]},
	"hungarian": {"name": "匈牙利掷弹兵", "hp": 12, "atk": 4, "def": 2, "spd": 1, "type": "elite", "range": 0, "tags": ["heavy"]},
	"leader": {"name": "纵队长", "hp": 10, "atk": 3, "def": 2, "spd": 1, "type": "leader", "range": 0, "tags": ["officer"]},
	"wagon": {"name": "弹药车", "hp": 4, "atk": 0, "def": 0, "spd": 1, "type": "wagon", "range": 0, "tags": []},
	"gun": {"name": "奥军炮", "hp": 8, "atk": 6, "def": 1, "spd": 0, "type": "gun", "range": 99, "tags": []},
}
static var ENEMIES: Dictionary = _build_enemies()
const KILL_ENEMY_MORALE := {"infantry": 1, "wagon": 1, "cavalry": 2, "gun": 2, "elite": 3, "leader": 4}
const KILL_OUR_MORALE := {"elite": 1, "leader": 2}

const CARDS := {
	"volley": {"name": "齐射", "cost": 2, "desc": "选一行：该行我方远程单位本回合攻 +2。"},
	"bayonet": {"name": "刺刀冲锋", "cost": 1, "desc": "一个近战单位本回合攻击两次，阻挡 −1。"},
	"feint": {"name": "佯动", "cost": 1, "desc": "把一个敌方远程目标格或炮击准星挪 1 格。"},
	"bugler": {"name": "虚张声势的号手", "cost": 2, "desc": "选一行：该行敌人本回合速度 −1，本回合和下回合攻 −2。"},
	"barrage": {"name": "集中炮火", "cost": 2, "desc": "所有炮兵本回合无视装填，打同一格。"},
	"fallback": {"name": "后撤", "cost": 0, "desc": "撤回一个单位，全额返还军令点，没有冷却。"},
	"requisition": {"name": "征发", "cost": 0, "desc": "军令点 +2，本幕民愤 +1。"},
	"emperor": {"name": "皇帝的命令", "cost": 0, "desc": "会战限定，用后消耗：军心 +3，全体技能充能 +1。"},
}
const DEFAULT_DECK := ["volley", "bayonet", "feint", "bugler", "barrage", "fallback", "requisition", "emperor"]

## 羁绊：职业羁绊数场上所有单位，阵营羁绊只数伙伴和主角；职业 + 阵营合计最多 3 条同时生效
const BOND_ORDER := ["artillery_school", "square", "cavalry_reserve", "army_of_italy", "quartermasters_men", "camp_family"]
const BONDS := {
	"artillery_school": {"name": "炮兵学派", "kind": "class", "cls": "artillery", "tiers": [2, 3],
		"desc": "2：装填不再隔回合；3：穿透改为全额伤害，炮兵攻 +1。"},
	"square": {"name": "方阵", "kind": "class", "cls": "grenadier", "adjacent": true, "tiers": [2, 3],
		"desc": "掷弹兵必须相邻。2：彼此防 +1；3：各自阻挡 +1。"},
	"cavalry_reserve": {"name": "骑兵预备队", "kind": "class", "cls": "hussar", "tiers": [2, 3],
		"desc": "2：冲锋距离 +1；3：冲锋打死敌人时返还 2 军令点。"},
	"army_of_italy": {"name": "意大利军团", "kind": "faction", "tag": "italy", "tiers": [2, 3, 4],
		"desc": "2：开场军令点 +2（按出征名单算）；3：每回合军令点 +1；4：军心上限 +2，每击溃一个纵队全体充能 +1。"},
	"quartermasters_men": {"name": "军需官的人", "kind": "faction", "tag": "quartermaster", "hero": true, "tiers": [2, 3],
		"desc": "主角必须在场。主角+1 人：战后法郎 +20%；主角+2 人：本场第一个倒下的伙伴视为已经被抬下。"},
	"camp_family": {"name": "随军家眷", "kind": "faction", "tag": "family", "tiers": [2],
		"desc": "2：所有伙伴的命悬一线 +1 枚；她们周围 2 格内的单位每回合回 1 兵力。"},
}
## 羁绊效果：内核认识的效果种类。上面六条内置羁绊的效果就是它们自己的 id。
## 战役可以在 battle_templates.json 的 bond_sets 里另配一套羁绊（setup.bond_set 选用，或 setup.bonds 直接给），
## 每条写自己的 id / 名字 / 阵营标签 / 门槛，再指定一个 effect：
##   三条职业羁绊各自的效果（必须是对应兵种的职业羁绊）；
##   army_of_italy：2 开场军令点 +2（按出征名单算）；3 每回合军令点 +1；4 军心上限 +2，击溃纵队全体充能 +1；
##   quartermasters_men：主角必须在场；2 战后法郎 +20%；3 第一个倒下的伙伴视为已被抬下；
##   camp_family：2 所有伙伴命悬一线 +1 枚，成员（伙伴）2 格内的单位每回合回 1；
##   spoils：2 战后法郎 +20%；3 战后再 +1 金币；
##   intel：2 军令手牌补到 4 张；3 来敌提前 3 回合公开（平时 2 回合）；
##   workshop：2 成员技能每回合多充能 1；3 获胜勋章 +1。
## 同一效果有几条羁绊同时生效时取最高档。
const BOND_EFFECTS := ["artillery_school", "square", "cavalry_reserve", "army_of_italy", "quartermasters_men", "camp_family",
	"spoils", "intel", "workshop"]
const CLASS_EFFECTS := {"artillery_school": "artillery", "square": "grenadier", "cavalry_reserve": "hussar"}

const UNDOABLE := ["deploy", "move", "withdraw", "skill", "card", "aim", "formation", "carry", "redraw"]
## apply 的参数类型：类型不对一律 bad_args，不碰状态
const ARG_TYPES := {"unit": TYPE_STRING, "facing": TYPE_STRING, "mode": TYPE_STRING, "col": TYPE_INT, "row": TYPE_INT,
	"index": TYPE_INT, "enemy": TYPE_INT, "square": TYPE_BOOL}
## 牌的前提：名册里一个能用的单位都没有，整场都打不出 → 开场就放到一边，不进牌组
const CARD_NEEDS := {"volley": ["line", "jager", "artillery"], "bayonet": ["line", "grenadier", "hussar", "engineer", "drummer", "hero"],
	"barrage": ["artillery"]}

static var _tpl_cache: Dictionary = {}
static var _builtin_bond_defs: Array = []


# ================================================================ 公开接口

static func new_battle(template_id: String, setup: Dictionary) -> Dictionary:
	var su: Dictionary = _ints(setup)
	var tpl: Dictionary = {}
	if typeof(su.get("template")) == TYPE_DICTIONARY:
		tpl = (su["template"] as Dictionary).duplicate(true)
	else:
		var lib := load_templates()
		var tpls: Dictionary = lib.get("templates", {})
		if not tpls.has(template_id):
			return {"error": "unknown_template", "errors": lib.get("errors", [])}
		tpl = (tpls[template_id] as Dictionary).duplicate(true)
	# 新接口：setup 给了 level / weather / mods 的仗是「新式」的，状态里多 level、weather、loot、ransom、killed_kinds 五个键，
	# 结算多 killed_kinds、loot、ransom。只给 act 的旧调用一个键都不多（远洋 golden 连战斗状态一起算哈希）
	var serr := _setup_errors(su)
	if not serr.is_empty():
		return {"error": "bad_setup", "errors": serr}
	# Volume two selects the authored objective before prep-turn mods adjust its deadline.
	if int(su.get("volume", 1)) >= 2 and typeof(tpl.get("order_next")) == TYPE_DICTIONARY:
		tpl["order"] = selected_order(tpl, int(su["volume"]))
	var ext: bool = su.has("level") or su.has("weather") or su.has("mods")
	var mods: Dictionary = su.get("mods", {}) if typeof(su.get("mods")) == TYPE_DICTIONARY else {}
	if ext and not mods.is_empty():
		tpl = _apply_mods(tpl, mods)
	var errs := validate_template(tpl)
	if not errs.is_empty():
		return {"error": "bad_template", "errors": errs}
	var bres := _resolve_bonds(su)
	if not (bres["errors"] as Array).is_empty():
		return {"error": "bad_bonds", "errors": bres["errors"]}
	var scale: String = str(tpl["scale"])
	var sc: Dictionary = SCALES[scale]
	var act: int = clampi(int(su.get("act", 1)), 1, 6)
	var lv: int = level_of_act(act)
	if su.has("level"):
		lv = clampi(int(su["level"]), 1, MAX_LEVEL)
		if not su.has("act"):
			act = clampi((lv + 1) / 2, 1, 6)
	var seed_value: int = int(su.get("seed", 1)) & 0xFFFFFFFF
	var size: Array = _tpl_size(tpl)
	var cols: int = int(size[0])
	var rows: int = int(size[1])
	var cap: Dictionary = caps(scale, lv)
	var state := {
		"v": 2,
		"template": str(tpl.get("id", template_id)),
		"name": str(tpl.get("name", template_id)),
		"scale": scale,
		"act": act,
		"seed": seed_value,
		"rng": _seed_rng(seed_value, 0x1F123BB5),
		"cols": cols,
		"rows": rows,
		"terrain": _parse_map(tpl["map"]),
		"routes": {},
		"route_ids": [],
		"events": [],
		"waves": [],
		"turn": 0,
		"turn_limit": int(tpl["turn_limit"]),
		"phase": "command",
		"outcome": "",
		"victory_kind": "",
		"cp": 0,
		"morale": 10,
		"morale_start": 10,
		"enemy_morale": 1,
		"enemy_morale_max": 1,
		"field_cap": int(cap["field"]),
		"companion_cap": int(cap["companions"]),
		"units": {},
		"order": [],
		"enemies": [],
		"next_enemy": 1,
		"next_obj": 1,
		"hand": [],
		"deck": [],
		"discard": [],
		"deck_base": [],
		"exhausted": [],
		"set_aside": [],
		"redraw_turn": -1,
		"fx": {"volley": [], "bayonet": [], "barrage": [], "flags": []},
		"bonds": {},
		"bonds_seen": [],
		"hero": {"enabled": false, "used": false, "withdrawn": false, "dispatched": false, "rally_used": false, "fell_turn": -1, "guard": false, "larrey": false},
		"trust": {},
		"fallen": [],
		"deployed_ever": [],
		"routed": [],
		"kills": 0,
		"leaks": 0,
		"requisitions": 0,
		"qm_carry_used": false,
		"decap_turn": -1,
		"decap_used": false,
		"order_goal": {},
		"end": {},
		"log": [],
		"undo": [],
	}
	# 战役自配的羁绊整套存进状态（存档自带，不依赖读档时的数据文件）；没配就用内置六条，状态里不放
	if bool(bres["custom"]):
		state["bond_defs"] = bres["defs"]
	if ext:
		state["level"] = lv
		state["weather"] = _setup_weather(su, tpl)
		state["loot"] = 0
		state["ransom"] = 0
		state["killed_kinds"] = {}
	for rid in (tpl["routes"] as Dictionary).keys():
		var cells: Array = []
		for lbl in _route_labels(tpl["routes"][rid]):
			cells.append(_parse_label(str(lbl)))
		state["routes"][str(rid)] = cells
		state["route_ids"].append(str(rid))
	state["route_ids"].sort()
	for ev in tpl.get("events", []):
		var c: Array = _parse_label(str(ev["cell"]))
		if ev.has("on_kill"):
			# 击杀触发：打死这种敌人以后（e 步）这一格变地形，只触发一次
			state["events"].append({"turn": -1, "col": int(c[0]), "row": int(c[1]), "terrain": str(ev["terrain"]), "on_kill": str(ev["on_kill"]),
				"armed": false, "done": false})
		else:
			state["events"].append({"turn": int(ev["turn"]), "col": int(c[0]), "row": int(c[1]), "terrain": str(ev["terrain"])})
	# 模板浮动：每一波可以有备选构成，由种子挑一个（进场时定下，之后不再变）。
	# 等级门槛 lv_min（旧的 act_min = a 按 lv_min = 2a−1 算，所以只给 act 时和原来一模一样）；补兵模板按 pad 每波补兵
	var col_id := 0
	for w in tpl["waves"]:
		var options: Array = [w["units"]]
		for alt in w.get("alt", []):
			options.append(alt)
		var pick: Array = options[_rand(state, options.size())] if options.size() > 1 else options[0]
		var units: Array = _wave_specs(tpl, w, pick, lv)
		if units.is_empty():
			continue
		col_id += 1
		var at: Array = _parse_label(str(w["at"])) if w.has("at") else []
		state["waves"].append({"turn": int(w["turn"]), "route": str(w.get("route", "")), "at": at, "units": units, "column": col_id, "spawned": false,
			"first_fire": int(w.get("first_fire", int(w["turn"]) + 1))})
	var em: int = int(tpl["enemy_morale"]) * int(LEVELS[lv - 1][1]) / 100
	em += clampi(int(mods.get("enemy_morale", 0)), -4, 0)
	state["enemy_morale"] = maxi(1, em)
	state["enemy_morale_max"] = state["enemy_morale"]
	state["order_goal"] = (tpl.get("order", {}) as Dictionary).duplicate(true)
	if str(state["order_goal"].get("type", "")) in ["escape", "extract", "protect"]:
		state["order_progress"] = {"count": 0, "last_tick": 0, "failed": false, "escaped": false, "gold": 0}
	# 主角与名册
	var hero_src: Dictionary = su.get("protagonist", {}) if typeof(su.get("protagonist")) == TYPE_DICTIONARY else {}
	var hero := _mk_unit(hero_src, "hero", HERO)
	if not hero_src.has("name"):
		hero["name"] = "维尔福"
	if not hero_src.has("tags"):
		hero["tags"] = ["italy"]
	state["hero"]["enabled"] = bool(hero_src.get("enabled", false))
	state["units"][HERO] = hero
	state["order"].append(HERO)
	for pair in [["roster", "companion"], ["troops", "troop"]]:
		for src in su.get(pair[0], []):
			if typeof(src) != TYPE_DICTIONARY:
				continue
			var uid := str(src.get("id", ""))
			if uid == "":
				uid = "%s_%d" % [pair[1], state["order"].size()]
			while state["units"].has(uid):
				uid += "_b"
			state["units"][uid] = _mk_unit(src, pair[1], uid)
			state["order"].append(uid)
	Pairs.install(state, su)
	if str(state["order_goal"].get("type", "")) == "protect" and state["order_goal"].has("npc"):
		_spawn_order_npc(state, state["order_goal"]["npc"])
	# 军令牌组：进场时由种子洗一次；之后抽空了就按这个顺序收回弃牌，不再有随机。
	# 整场都打不出的牌（非会战的皇帝的命令、没带炮兵的集中炮火……）开场就放到一边，不占手牌位
	var deck: Array = []
	var src_cards = su.get("cards", [])
	if typeof(src_cards) == TYPE_ARRAY:
		for cid in src_cards:
			if CARDS.has(str(cid)):
				deck.append(str(cid))
	if deck.is_empty():
		deck = DEFAULT_DECK.duplicate()
	var have_cls := {}
	for uid in state["order"]:
		var cu: Dictionary = state["units"][uid]
		if cu["kind"] != "hero" or bool(state["hero"]["enabled"]):
			have_cls[cu["cls"]] = true
	var kept: Array = []
	for cid in deck:
		var usable := true
		if cid == "emperor" and not scale in BOSS_SCALES:
			usable = false
		elif CARD_NEEDS.has(cid):
			usable = false
			for need in CARD_NEEDS[cid]:
				if have_cls.has(need):
					usable = true
		if usable:
			kept.append(cid)
		else:
			state["set_aside"].append(cid)
	deck = kept
	for i in range(deck.size() - 1, 0, -1):
		var j := _rand(state, i + 1)
		var tmp = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
	state["deck"] = deck
	state["deck_base"] = deck.duplicate()
	var trust_src = su.get("bonds_trust", {})
	state["trust"] = (trust_src as Dictionary).duplicate(true) if typeof(trust_src) == TYPE_DICTIONARY else {}
	# 开场军令点：6 + 意大利军团（或效果相同的战役羁绊）2 档 +2（开场时还没人上场，按出征名单里的伙伴和主角算）
	# + 先机/粮秣（由战役层给 cp_bonus，最多 +7）
	var opening := 0
	for bd in _bond_defs(state):
		if str(bd["effect"]) != "army_of_italy":
			continue
		var italy := 0
		for uid in state["order"]:
			var u: Dictionary = state["units"][uid]
			if (u["kind"] == "companion" or (u["kind"] == "hero" and state["hero"]["enabled"])) and str(bd["tag"]) in u["tags"]:
				italy += 1
		if italy >= int(bd["tiers"][0]):
			opening = 2
	# + 军议的 Boss 修正 mods.cp_bonus（0–4）
	state["cp"] = mini(CP_CAP, 6 + opening + clampi(int(su.get("cp_bonus", 0)), 0, 7) + clampi(int(mods.get("cp_bonus", 0)), 0, 4))
	state["morale"] = clampi(int(su.get("morale", 10)), 1, 15)
	state["morale_start"] = state["morale"]
	if ext:
		_log(state, _txt("open", {"name": state["name"], "scale": sc["name"], "lv": lv, "weather": weather_name(str(state["weather"])),
			"turns": state["turn_limit"], "em": state["enemy_morale"]}))
	else:
		_log(state, "%s（%s，第 %d 幕）：%d 回合，敌军心 %d。" % [state["name"], sc["name"], act, state["turn_limit"], state["enemy_morale"]])
	_refresh_bonds(state)
	_begin_turn(state, 1)
	return state


static func apply(state: Dictionary, cmd: String, args: Dictionary = {}) -> Dictionary:
	if state.is_empty() or state.has("error") or not state.has("units"):
		return _fail("no_battle")
	_normalize_in_place(state)
	if state["phase"] != "command":
		return _fail("battle_over")
	var a: Dictionary = _ints(args)
	for k in a.keys():
		if typeof(a[k]) == TYPE_STRING_NAME:
			a[k] = str(a[k])
		if ARG_TYPES.has(k) and typeof(a[k]) != ARG_TYPES[k]:
			return _fail("bad_args")
	if cmd == "undo":
		var stack: Array = state["undo"]
		if stack.is_empty():
			return _fail("nothing_to_undo")
		var snap: Dictionary = stack.pop_back()
		_restore(state, snap, stack)
		return _ok()
	if cmd == "fight":
		_fight(state)
		return _ok()
	if cmd == "retreat":
		_log(state, "全军撤出战场。")
		_finish(state, "retreat", "")
		return _ok()
	if not cmd in UNDOABLE:
		return _fail("bad_cmd")
	var snap := _snapshot(state)
	var stack_before: Array = state["undo"]
	var res: Dictionary
	match cmd:
		"deploy": res = _cmd_deploy(state, a)
		"move": res = _cmd_move(state, a)
		"withdraw": res = _cmd_withdraw(state, a, false)
		"skill": res = _cmd_skill(state, a)
		"card": res = _cmd_card(state, a)
		"aim": res = _cmd_aim(state, a)
		"formation": res = _cmd_formation(state, a)
		"carry": res = _cmd_carry(state, a)
		"redraw": res = _cmd_redraw(state, a)
		_: res = _fail("bad_cmd")
	if not bool(res.get("ok", false)):
		_restore(state, snap, stack_before)
		return res
	stack_before.append(snap)
	state["undo"] = stack_before
	return res


## 本回合敌情：每个敌人的移动终点、攻击目标和标记；炮击准星；之后 2 回合的来敌
static func intents(state_in: Dictionary) -> Array:
	var out: Array = []
	if not _live(state_in):
		return out
	var state := _normalized(state_in)
	var t: int = int(state["turn"])
	var sim := _sim_copy(state)
	if int(sim["enemy_morale"]) > 0:
		_step_a(sim)
	var alive_after_a := {}
	# 敌军心在 a 步（或指挥阶段）就归零：敌人溃逃，所有意图作废
	if int(sim["enemy_morale"]) > 0:
		for e in sim["enemies"]:
			alive_after_a[int(e["uid"])] = true
	var rec := {"reached": {}}
	_step_b(sim, rec)
	for e in state["enemies"]:
		var uid: int = int(e["uid"])
		# 隐身（stealth）的敌人离我方所有单位都超过 2 格：兵种和名字隐去，只给伤害数
		var hidden := _hidden(state, e)
		var row := {"type": "enemy", "enemy": uid, "kind": "unknown" if hidden else e["kind"], "name": _ename(state, e), "at": [e["col"], e["row"]],
			"move_to": [e["col"], e["row"]], "blocked_by": "", "attack": {}, "marks": [], "cancelled": false}
		if hidden:
			row["hidden"] = true
		if not alive_after_a.has(uid):
			row["cancelled"] = true
			out.append(row)
			continue
		if rec["reached"].has(uid):
			row["move_to"] = rec["reached"][uid]
			row["attack"] = {"kind": "eagle", "target": "eagle", "morale": _eagle_loss(e)}
			out.append(row)
			continue
		var se: Dictionary = _enemy_by_uid(sim, uid)
		row["move_to"] = [se["col"], se["row"]]
		row["blocked_by"] = se["blocked_by"]
		var target := ""
		var kind := "none"
		if se["type"] == "gun":
			if not (se["aim"] as Array).is_empty():
				var tu = _unit_at(sim, int(se["aim"][0]), int(se["aim"][1]), true)
				row["attack"] = {"kind": "gun" if int(se["fire_turn"]) == t else "gun_aim", "cell": se["aim"].duplicate(),
					"fire_turn": se["fire_turn"], "target": tu["uid"] if tu != null and int(se["fire_turn"]) == t else ""}
				if tu != null and int(se["fire_turn"]) == t:
					tu = Pairs.target(sim, se, tu)
					row["attack"]["target"] = tu["uid"]
					row["attack"]["dmg"] = _dmg_to_unit(sim, se, tu, "gun")
				if "execute" in se["tags"]:
					row["marks"].append("execute")
				if "hunter" in se["tags"] and tu != null and tu["uid"] == HERO:
					row["marks"].append("hunter")
				if int(state["decap_turn"]) == int(se["fire_turn"]) and tu != null and tu["uid"] == HERO:
					row["marks"].append("decap")
			out.append(row)
			continue
		if int(se["range"]) > 0:
			kind = "ranged"
			if se["blocked_by"] != "":
				target = se["blocked_by"]
			else:
				target = _ranged_valid_target(sim, se)
		else:
			kind = "melee"
			if bool(se["hunting"]):
				target = HERO
			elif se["blocked_by"] != "":
				target = se["blocked_by"]
		if target != "" and _enemy_atk(sim, se) > 0:
			var tu2: Dictionary = Pairs.target(sim, se, sim["units"][target])
			row["attack"] = {"kind": kind, "target": tu2["uid"], "dmg": _dmg_to_unit(sim, se, tu2, kind)}
			if target == HERO and "hunter" in se["tags"]:
				row["marks"].append("hunter")
			if target == HERO and kind == "ranged" and int(state["decap_turn"]) == t:
				row["marks"].append("decap")
			if "execute" in se["tags"]:
				row["marks"].append("execute")
		out.append(row)
	var routed: bool = int(sim["enemy_morale"]) <= 0
	for e in state["enemies"]:
		if e["type"] == "gun" and not (e["aim"] as Array).is_empty() and not routed:
			var cm: Array = ["execute"] if "execute" in e["tags"] else []
			if int(state["decap_turn"]) == int(e["fire_turn"]):
				cm.append("decap")
			var ch := {"type": "crosshair", "enemy": e["uid"], "cell": e["aim"].duplicate(), "label": _label(int(e["aim"][0]), int(e["aim"][1])),
				"fire_turn": e["fire_turn"], "now": int(e["fire_turn"]) == t, "marks": cm}
			# 火箭：准星靠鹰旗一侧（列号 −1）那一格挨半伤
			if "rocket" in e["tags"] and int(e["aim"][0]) > 0:
				ch["splash"] = [int(e["aim"][0]) - 1, int(e["aim"][1])]
			out.append(ch)
	if int(state["decap_turn"]) >= t and not routed:
		out.append({"type": "decap", "turn": state["decap_turn"], "now": int(state["decap_turn"]) == t, "target": HERO})
	for w in state["waves"]:
		if bool(w["spawned"]) or int(w["turn"]) <= t or int(w["turn"]) > t + _horizon(state):
			continue
		var names: Array = []
		for spec in w["units"]:
			names.append(_spec_row(spec))
		var cell: Array = w["at"] if not (w["at"] as Array).is_empty() else state["routes"][w["route"]][0]
		out.append({"type": "wave", "turn": w["turn"], "units": names, "cell": cell.duplicate(), "label": _label(int(cell[0]), int(cell[1]))})
	return out


## 悬停预演：在深拷贝上结算本回合，返回结算后的兵力、位置、军心和倒下名单；不改动 state
static func preview(state_in: Dictionary) -> Dictionary:
	if not _live(state_in):
		return {"ok": false}
	var state := _normalized(state_in)
	var sim := _sim_copy(state)
	var log_from: int = (sim["log"] as Array).size()
	var before := {}
	for uid in sim["order"]:
		before[uid] = sim["units"][uid]["status"]
	var enemies_before: Array = []
	var hidden_hp := {}
	for e in sim["enemies"]:
		enemies_before.append(int(e["uid"]))
		if _hidden(state, e):
			hidden_hp[int(e["uid"])] = int(e["hp"])
	_fight(sim)
	var units := {}
	var fallen: Array = []
	for uid in sim["order"]:
		var u: Dictionary = sim["units"][uid]
		units[uid] = {"hp": u["hp"], "col": u["col"], "row": u["row"], "status": u["status"]}
		if before.has(uid) and before[uid] == "ok" and u["status"] != "ok" and u["status"] != "bar":
			fallen.append(uid)
	var enemies := {}
	for euid in enemies_before:
		var e: Dictionary = _enemy_by_uid(sim, euid)
		if hidden_hp.has(euid):
			# stealth（§10）：看不清的敌人预演只给伤害数，不给兵力
			enemies[str(euid)] = _hidden_after(e, int(hidden_hp[euid]))
		elif e.is_empty():
			enemies[str(euid)] = {"alive": false, "hp": 0}
		else:
			enemies[str(euid)] = {"alive": true, "hp": e["hp"], "col": e["col"], "row": e["row"]}
	var lines: Array = (sim["log"] as Array).slice(log_from) if (sim["log"] as Array).size() > log_from else []
	return {"ok": true, "turn": sim["turn"], "phase": sim["phase"], "outcome": sim["outcome"], "morale": sim["morale"],
		"enemy_morale": sim["enemy_morale"], "cp": sim["cp"], "units": units, "enemies": enemies, "fallen": fallen,
		"leaks": int(sim["leaks"]) - int(state["leaks"]), "kills": int(sim["kills"]) - int(state["kills"]), "log": lines}


## 指令预演：在深拷贝上先下一条指挥阶段的指令（不交火），返回下完之后的样子：单位落在哪（骠骑兵冲锋的落点）、
## 打到了哪几格（hit_cells，按挨打前的位置）、每个挨打敌人剩多少、击毙几个、双方军心、军令点、新增的日志。不改 state。
## 界面选骠骑兵朝向时用它画冲锋路线和战果，不用先放下去再撤销。
static func preview_cmd(state_in: Dictionary, cmd: String, args: Dictionary) -> Dictionary:
	if not _live(state_in) or not cmd in UNDOABLE:
		return {"ok": false, "err": "bad_cmd"}
	var state := _normalized(state_in)
	var sim := _sim_copy(state)
	var log_from: int = (sim["log"] as Array).size()
	var before := {}
	var hidden := {}
	for e in sim["enemies"]:
		before[int(e["uid"])] = [int(e["hp"]), int(e["col"]), int(e["row"])]
		if _hidden(state, e):
			hidden[int(e["uid"])] = true
	var res := apply(sim, cmd, args)
	if not bool(res.get("ok", false)):
		return {"ok": false, "err": str(res.get("err", ""))}
	var enemies := {}
	var hit_cells: Array = []
	for euid in before:
		var b0: Array = before[euid]
		var e: Dictionary = _enemy_by_uid(sim, euid)
		if not e.is_empty() and int(e["hp"]) >= int(b0[0]):
			continue
		if hidden.has(euid):
			enemies[str(euid)] = _hidden_after(e, int(b0[0]))
		else:
			enemies[str(euid)] = {"alive": false, "hp": 0} if e.is_empty() else {"alive": true, "hp": e["hp"], "col": e["col"], "row": e["row"]}
		if not [b0[1], b0[2]] in hit_cells:
			hit_cells.append([b0[1], b0[2]])
	var unit := {}
	var uid := str(args.get("unit", ""))
	if sim["units"].has(uid):
		var u: Dictionary = sim["units"][uid]
		unit = {"uid": uid, "col": u["col"], "row": u["row"], "status": u["status"], "charged": bool(u.get("charged", false))}
	var lines: Array = (sim["log"] as Array).slice(log_from) if (sim["log"] as Array).size() > log_from else []
	return {"ok": true, "kills": int(sim["kills"]) - int(state["kills"]), "enemy_morale": sim["enemy_morale"], "morale": sim["morale"],
		"cp": sim["cp"], "unit": unit, "enemies": enemies, "hit_cells": hit_cells, "log": lines, "outcome": sim["outcome"]}


## 战后结算：胜负、星级、奖赏、命悬一线（铜钱来自种子，同一状态永远同一结果）、伤痕、被俘、用过的羁绊
static func result(state_in: Dictionary) -> Dictionary:
	if state_in.is_empty() or not state_in.has("units") or state_in.get("phase", "") != "over":
		return {"outcome": "ongoing"}
	var state := _normalized(state_in)
	var outcome: String = state["outcome"]
	var end: Dictionary = state["end"]
	var victory := outcome == "victory"
	var hero_end: bool = bool(end.get("hero_on_field", false))
	var stars := 0
	var companions_fell := false
	for f in state["fallen"]:
		if f["unit"] != HERO:
			companions_fell = true
	if victory:
		stars = 1
		if int(state["morale"]) * 2 >= int(state["morale_start"]):
			stars = 2
			if bool(end.get("order_done", false)) and not companions_fell:
				stars = 3
	var sc: Dictionary = SCALES[state["scale"]]
	var rewards := {"franc": 0, "gold": 0, "medal": 0}
	if victory:
		var tier: int = stars + (1 if state["victory_kind"] == "rout" else 0)
		var franc: int = int(sc["franc"]) + int(sc["franc"]) * 25 * (tier - 1) / 100
		var medal: int = int(sc["medal"]) + tier - 1
		if bool(end.get("order_done", false)):
			medal += 1
		if hero_end:
			franc = franc * 3 / 2
			medal += 2 if state["scale"] in BOSS_SCALES else 1
		if int(end.get("qm_tier", 0)) >= 2:
			franc = franc * 120 / 100
		var gold: int = int(sc["gold"]) + int(state.get("order_progress", {}).get("gold", 0))
		if int(end.get("spoils_tier", 0)) >= 2:
			franc = franc * 120 / 100
		if int(end.get("spoils_tier", 0)) >= 3:
			gold += 1
		if int(end.get("workshop_tier", 0)) >= 3:
			medal += 1
		rewards = {"franc": franc, "gold": gold, "medal": medal}
	var fallen_out: Array = []
	var scars: Array = []
	var captured: Array = []
	var hero_st: Dictionary = state["hero"]
	if outcome == "defeat" and hero_end:
		captured.append(HERO)
	if int(hero_st["fell_turn"]) >= 0 and bool(hero_st.get("arrested", false)):
		# arrest：在宪兵、探员这类敌人的白刃下倒下，不掷铜钱，直接被俘（战役层转入大命运「被捕」）
		captured.append(HERO)
		fallen_out.append({"unit": HERO, "coins": 0, "coin_faces": [], "died": false, "rolled": false,
			"scar": false, "wounded": false, "captured": true, "carried": false, "execute": false, "arrested": true})
	elif int(hero_st["fell_turn"]) >= 0:
		var coins: int = mini(4, 2 + (1 if bool(hero_st["guard"]) else 0) + (1 if bool(hero_st["larrey"]) else 0) + Pairs.fate_bonus(state, HERO))
		var faces: Array = _coin_faces(int(state["seed"]), HERO, coins)
		fallen_out.append({"unit": HERO, "coins": coins, "coin_faces": faces, "died": not (1 in faces), "rolled": true,
			"scar": false, "wounded": 1 in faces, "captured": false, "carried": false, "execute": false})
	for f in state["fallen"]:
		var uid: String = f["unit"]
		var carried: bool = bool(f["carried"])
		var entry := {"unit": uid, "coins": 0, "coin_faces": [], "died": false, "rolled": false, "scar": false,
			"captured": false, "carried": carried, "execute": bool(f["execute"]),
			# 进场前就带伤（或在宿命之地按带伤算）：活下来伤痕也不会再加重
			"was_scarred": bool(state["units"][uid]["scarred"]), "fated": bool(f["fated"])}
		if outcome == "defeat" and not carried:
			entry["captured"] = true
			captured.append(uid)
			fallen_out.append(entry)
			continue
		var roll := false
		if bool(f["scarred"]):
			roll = true
		elif carried and int(f["survived"]) == 0:
			roll = false
		elif int(f["survived"]) >= 1 or outcome == "retreat":
			roll = true
		if roll:
			var coins2 := 3
			if bool(f["execute"]):
				coins2 -= 1
			if bool(f["fated"]):
				coins2 -= 2
			if carried:
				coins2 += 1
			if bool(f["larrey"]):
				coins2 += 1
			if bool(f["family"]):
				coins2 += 1
			if outcome != "victory" and not carried:
				coins2 -= 1
			coins2 = clampi(coins2 + Pairs.fate_bonus(state, uid), 1, 5)
			var faces2: Array = _coin_faces(int(state["seed"]), uid, coins2)
			entry["coins"] = coins2
			entry["coin_faces"] = faces2
			entry["rolled"] = true
			entry["died"] = not (1 in faces2)
		if not bool(entry["died"]):
			entry["scar"] = true
			scars.append(uid)
		fallen_out.append(entry)
	var dead := {}
	for row in fallen_out:
		if bool(row["died"]) or bool(row["captured"]):
			dead[row["unit"]] = true
	var trust_up: Array = []
	if victory and hero_end:
		for uid in state["deployed_ever"]:
			if state["units"].has(uid) and state["units"][uid]["kind"] == "companion" and not dead.has(uid):
				trust_up.append(uid)
	var out := {
		"outcome": outcome,
		"victory_kind": state["victory_kind"],
		"stars": stars,
		"turns": state["turn"],
		"morale": state["morale"],
		"enemy_morale": state["enemy_morale"],
		"rewards": rewards,
		"protagonist_on_field_at_end": hero_end,
		"protagonist_withdrew": bool(hero_st["withdrawn"]),
		"order_done": bool(end.get("order_done", false)),
		"fallen": fallen_out,
		"scars": scars,
		"captured": captured,
		"routed": (state["routed"] as Array).duplicate(),
		"bonds_used": (state["bonds_seen"] as Array).duplicate(),
		"trust_up": trust_up,
		"requisitions": state["requisitions"],
		"kills": state["kills"],
		"leaks": state["leaks"],
	}
	# 新式的仗（§6.6）：按兵种的击杀数（战役层的 kill_flags 看它）、抢走军需的海盗数、掳走人质的强盗数（奖赏扣减在战役层）
	if state.has("level"):
		out["level"] = state["level"]
		out["weather"] = str(state.get("weather", "clear"))
		out["killed_kinds"] = (state.get("killed_kinds", {}) as Dictionary).duplicate(true)
		out["loot"] = int(state.get("loot", 0))
		out["ransom"] = int(state.get("ransom", 0))
	return out


## 界面要画的一切
static func view(state_in: Dictionary) -> Dictionary:
	if state_in.is_empty() or not state_in.has("units"):
		return {"ok": false, "error": str(state_in.get("error", "no_battle"))}
	var state := _normalized(state_in)
	var cols: int = int(state["cols"])
	var rows: int = int(state["rows"])
	var t: int = int(state["turn"])
	var cells: Array = []
	for r in range(rows):
		for c in range(cols):
			var tr: String = state["terrain"][r * cols + c]
			var ti: Dictionary = _tinfo(tr)
			# tier 层（虚空 −1）；los 这一格挡视线；stand 我方站位 ground / high / top / none；dark 黑暗（牢廊、墓穴，夜战时每一格）
			cells.append({"col": c, "row": r, "label": _label(c, r), "terrain": tr, "name": TERRAIN_NAMES.get(tr, tr), "reserved": _reserved(state, c, r),
				"tier": int(ti["tier"]), "los": bool(ti["los"]), "stand": str(ti["stand"]), "dark": _dark(state, c, r)})
	var routes: Array = []
	for rid in state["route_ids"]:
		routes.append({"id": rid, "cells": (state["routes"][rid] as Array).duplicate(true)})
	var units: Array = []
	var bar: Array = []
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		var sk: String = u["skill"]
		var need: int = int(SKILLS[sk]["charge"]) if SKILLS.has(sk) else 0
		var on_field: bool = u["status"] == "ok" or u["status"] == "dying"
		if on_field:
			units.append({"uid": uid, "name": u["name"], "cls": u["cls"], "cls_name": CLASSES[u["cls"]]["name"], "kind": u["kind"],
				"state": u["status"], "col": u["col"], "row": u["row"], "label": _label(int(u["col"]), int(u["row"])),
				"facing": u["facing"], "hp": u["hp"], "max_hp": u["max_hp"], "atk": _unit_atk(state, u), "def": _unit_def(state, u),
				"block": _unit_block(state, u), "block_used": _block_used(state, uid), "charge": u["charge"], "charge_need": need,
				"skill": sk, "skill_name": SKILLS[sk]["name"] if SKILLS.has(sk) else "", "skill_ready": need > 0 and int(u["charge"]) >= need and u["status"] == "ok",
				"square": u["square"], "aim": (u["aim"] as Array).duplicate(), "reload": u["reload"], "scarred": u["scarred"], "fated": u["fated"],
				"pattern": _pattern_cells(state, u),
				# 界面按钮能不能按：撤下（本回合刚部署的不行）、抬下（相邻要有人；军医相邻免费）
				"can_withdraw": _live(state) and u["status"] == "ok" and u["kind"] not in ["barricade", "npc"] and int(u.get("deployed_turn", -1)) != t and Pairs.can_withdraw(state, str(uid)),
				"can_carry": _live(state) and u["status"] == "dying" and _carry_cost(state, u) >= 0 and _carry_cost(state, u) <= int(state["cp"]),
				# 抬不了时也给真实费用（没人相邻按 2 算）和原因：no_adjacent / no_cp / ""
				"carry_cost": (2 if _carry_cost(state, u) < 0 else _carry_cost(state, u)) if u["status"] == "dying" else 0,
				"carry_reason": _carry_reason(state, u)})
		if state.has("order_progress") and on_field:
			units[-1]["move_cells"] = _order_move_cells(state, u)
			units[-1]["can_move"] = not (units[-1]["move_cells"] as Array).is_empty()
		if u["kind"] in ["barricade", "npc"]:
			continue
		var why := _deploy_block_reason(state, u)
		bar.append({"uid": uid, "name": u["name"], "cls": u["cls"], "cls_name": CLASSES[u["cls"]]["name"], "kind": u["kind"],
			"cost": u["cost"], "status": u["status"], "cooldown": u["cooldown"], "hp": u["hp"], "max_hp": u["max_hp"],
			"deployable": why == "", "reason": why, "place": CLASSES[u["cls"]]["place"], "scarred": u["scarred"], "fated": u["fated"],
			"top": bool(CLASSES[u["cls"]].get("top", false)), "from_turn": int(u.get("from_turn", 0)),
			"can_dispatch": uid == HERO and _live(state) and u["status"] == "bar" and not bool(state["hero"]["dispatched"]) and not bool(state["hero"]["used"])})
		if _mobile_order_unit(state, u) and state["order_goal"].has("start_cell"):
			bar[-1]["start_cell"] = str(state["order_goal"]["start_cell"])
	var enemies: Array = []
	for e in state["enemies"]:
		if _hidden(state, e):
			# stealth：离我方所有单位都超过 2 格，兵种、名字、标签、兵力都隐去
			enemies.append({"uid": e["uid"], "kind": "unknown", "name": _ename(state, e), "type": "unknown", "col": e["col"], "row": e["row"],
				"label": _label(int(e["col"]), int(e["row"])), "hp": 0, "max_hp": 0, "atk": 0, "def": 0, "spd": 0, "tags": [],
				"blocked_by": e["blocked_by"], "elite": false, "column": e["column"], "hidden": true})
			continue
		enemies.append({"uid": e["uid"], "kind": e["kind"], "name": e["name"], "type": e["type"], "col": e["col"], "row": e["row"],
			"label": _label(int(e["col"]), int(e["row"])), "hp": e["hp"], "max_hp": e["max_hp"], "atk": _enemy_atk(state, e),
			"def": e["def"], "spd": e["spd"], "tags": (e["tags"] as Array).duplicate(), "blocked_by": e["blocked_by"],
			"elite": e["type"] == "elite" or e["type"] == "leader", "column": e["column"], "hidden": false})
	var hand: Array = []
	for i in range((state["hand"] as Array).size()):
		var h: Dictionary = state["hand"][i]
		var cd: Dictionary = CARDS[h["id"]]
		hand.append({"index": i, "id": h["id"], "name": cd["name"], "cost": cd["cost"], "desc": cd["desc"], "locked": h["lock"] != "",
			"locked_on": h["lock"], "playable": _live(state) and h["lock"] == "" and int(cd["cost"]) <= int(state["cp"]) and _card_feasible(state, h["id"])})
	var waves: Array = []
	for w in state["waves"]:
		if bool(w["spawned"]):
			continue
		var names: Array = []
		var details: Array = []
		for spec in w["units"]:
			var sr := _spec_row(spec)
			names.append(sr["name"])
			details.append(sr)
		var cell: Array = w["at"] if not (w["at"] as Array).is_empty() else state["routes"][w["route"]][0]
		waves.append({"turn": w["turn"], "units": names, "detail": details, "label": _label(int(cell[0]), int(cell[1])), "known": int(w["turn"]) <= t + _horizon(state)})
	var bonds: Array = []
	for bd in _bond_defs(state):
		var bid: String = bd["id"]
		var b: Dictionary = state["bonds"].get(bid, {"count": 0, "tier": 0, "active": false})
		var nxt := 0
		for th in bd["tiers"]:
			if int(th) > int(b["count"]):
				nxt = int(th)
				break
		bonds.append({"id": bid, "name": bd["name"], "kind": bd["kind"], "count": b["count"], "tier": b["tier"], "active": b["active"],
			"next": nxt, "desc": bd["desc"], "effect": bd["effect"], "tag": str(bd.get("tag", "")), "cls": str(bd.get("cls", ""))})
	bonds.append_array(Pairs.view(state))
	var lg: Array = state["log"]
	return {
		"ok": true,
		"template": state["template"], "name": state["name"], "scale": state["scale"], "scale_name": SCALES[state["scale"]]["name"],
		"act": state["act"], "turn": t, "turn_limit": state["turn_limit"], "phase": state["phase"], "outcome": state["outcome"],
		# §8.4 / §9.3：等级（旧调用按 2·幕−1 算）、星级、天时
		"level": _lv(state), "level_stars": int(LEVELS[_lv(state) - 1][11]),
		"weather": _weather(state), "weather_name": weather_name(_weather(state)), "weather_desc": weather_desc(_weather(state)),
		"grid": {"cols": cols, "rows": rows, "cells": cells, "routes": routes},
		"units": units, "deploy_bar": bar, "enemies": enemies, "intents": intents(state),
		"cp": state["cp"], "cp_cap": CP_CAP, "cp_next": _cp_gain(state),
		"morale": state["morale"], "morale_cap": _morale_cap(state), "morale_start": state["morale_start"],
		"enemy_morale": state["enemy_morale"], "enemy_morale_max": state["enemy_morale_max"],
		"field_count": _field_count(state, false), "field_cap": state["field_cap"],
		"companion_count": _field_count(state, true), "companion_cap": state["companion_cap"],
		"waves": waves, "hand": hand, "deck_count": (state["deck"] as Array).size(), "discard_count": (state["discard"] as Array).size(),
		"set_aside": (state["set_aside"] as Array).duplicate(), "can_redraw": _live(state) and int(state["redraw_turn"]) != t and not (state["hand"] as Array).is_empty(),
		"bonds": bonds, "order": order_view(state),
		"hero": (state["hero"] as Dictionary).duplicate(true), "decap_turn": state["decap_turn"],
		"can_undo": not (state["undo"] as Array).is_empty(),
		# 界面的战报要显示上一轮交火加本回合指挥阶段的全部内容，还要能展开整份日志
		"log": lg.slice(maxi(0, lg.size() - 40)),
	}


## 读取并校验 data/campaigns/battle_templates.json：{ok, templates, scene_map, errors}
static func load_templates(force: bool = false) -> Dictionary:
	if not _tpl_cache.is_empty() and not force:
		return _tpl_cache.duplicate(true)
	var out := {"ok": false, "templates": {}, "scene_map": {}, "bond_sets": {}, "errors": []}
	if not FileAccess.file_exists(TEMPLATES_PATH):
		out["errors"] = ["missing " + TEMPLATES_PATH]
		return out
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(TEMPLATES_PATH)) != OK or typeof(json.data) != TYPE_DICTIONARY:
		out["errors"] = ["bad json"]
		return out
	var data: Dictionary = _ints(json.data)
	var errors: Array = []
	var tpls: Dictionary = data.get("templates", {}) if typeof(data.get("templates")) == TYPE_DICTIONARY else {}
	if tpls.is_empty():
		errors.append("no templates")
	for tid in tpls.keys():
		if typeof(tpls[tid]) == TYPE_DICTIONARY:
			tpls[tid]["id"] = str(tid)
		for e in validate_template(tpls[tid]):
			errors.append("%s: %s" % [tid, e])
	var bond_sets: Dictionary = data.get("bond_sets", {}) if typeof(data.get("bond_sets")) == TYPE_DICTIONARY else {}
	for set_id in bond_sets.keys():
		for e in validate_bonds(bond_sets[set_id]):
			errors.append("bond_sets %s: %s" % [set_id, e])
	var scene_map: Dictionary = data.get("scene_map", {}) if typeof(data.get("scene_map")) == TYPE_DICTIONARY else {}
	for sid in scene_map.keys():
		var row = scene_map[sid]
		if typeof(row) != TYPE_DICTIONARY or not tpls.has(str(row.get("template", ""))):
			errors.append("scene_map %s: unknown template" % sid)
		elif int(row.get("act", 0)) < 1 or int(row.get("act", 0)) > 6:
			errors.append("scene_map %s: act out of 1..6" % sid)
	out = {"ok": errors.is_empty(), "templates": tpls, "scene_map": scene_map, "bond_sets": bond_sets, "errors": errors}
	_tpl_cache = out
	return out.duplicate(true)


## 校验一张模板：尺寸（scale 的默认或 size，5×3–12×7）、地形字符、路线连通（起于红门 / 舱口 / 牢门或伏兵格、止于鹰旗、
## 逐格相邻、中途可走、不经过虚空；写了 until 的路线只查 [首次使用, until + 路线长度] 这段时间）、波次（敌兵种、站 at 格的
## 炮和定点射手、at 格地形、等级门槛）、新键（level、base_level 与 pad、weather、spawns、kill_flags、objective）、目标。
## 没写 level / base_level 的模板（旧 7 张就是）只认第一幕奥军 7 种敌人：新名册里的敌人只给写了等级的新模板用（§8.2 第 5 条）。
static func validate_template(t) -> Array:
	var errs: Array = []
	if typeof(t) != TYPE_DICTIONARY:
		return ["template is not a dictionary"]
	var scale := str(t.get("scale", ""))
	if not SCALES.has(scale):
		return ["bad scale '%s'" % scale]
	var size: Array = _tpl_size(t)
	if size.is_empty():
		return ["size must be [cols, rows] within 5x3 .. 12x7"]
	var cols: int = int(size[0])
	var rows: int = int(size[1])
	var mp = t.get("map", [])
	if typeof(mp) != TYPE_ARRAY or (mp as Array).size() != rows:
		return ["map must have %d rows" % rows]
	for r in range(rows):
		var line := str(mp[r])
		if line.length() != cols:
			errs.append("map row %d must have %d cells" % [r + 1, cols])
			continue
		for ch in line:
			if not TERRAIN_CHARS.has(ch):
				errs.append("map row %d: unknown terrain '%s'" % [r + 1, ch])
	if not errs.is_empty():
		return errs
	var limit: int = int(t.get("turn_limit", 0))
	if limit < 1 or limit > 20:
		errs.append("turn_limit out of 1..20")
	if int(t.get("enemy_morale", 0)) < 1:
		errs.append("enemy_morale must be >= 1")
	var base := _parse_map(mp)
	if not "eagle" in base:
		errs.append("no eagle cell")
	if not ("gate" in base or "hatch" in base or "door" in base):
		errs.append("no gate cell")
	var roster: Dictionary = ENEMIES if (t.has("level") or t.has("base_level")) else BASE_ENEMIES
	errs.append_array(_check_new_keys(t, cols, rows, base, roster))
	var events: Array = t.get("events", []) if typeof(t.get("events", [])) == TYPE_ARRAY else []
	for ev in events:
		if typeof(ev) != TYPE_DICTIONARY or not _label_ok(str(ev.get("cell", "")), cols, rows) or not TERRAIN.has(str(ev.get("terrain", ""))):
			errs.append("bad event %s" % str(ev))
		elif ev.has("on_kill"):
			if not roster.has(str(ev["on_kill"])):
				errs.append("bad event %s: on_kill needs a known enemy" % str(ev))
		elif int(ev.get("turn", 0)) < 1 or int(ev.get("turn", 0)) > maxi(1, limit):
			errs.append("bad event %s" % str(ev))
	if not errs.is_empty():
		return errs
	var routes = t.get("routes", {})
	if typeof(routes) != TYPE_DICTIONARY or (routes as Dictionary).is_empty():
		return errs + ["no routes"]
	var waves = t.get("waves", [])
	if typeof(waves) != TYPE_ARRAY or (waves as Array).is_empty():
		errs.append("no waves")
		waves = []
	var spawns: Array = t.get("spawns", []) if typeof(t.get("spawns")) == TYPE_ARRAY else []
	var first_use := {}
	# 伏兵 / 登船路线：这条路线上的每一波、每个兵都带 ambush 或 boarder，起点才可以是伏兵格或跳板
	var sneaky := {}
	for w in waves:
		if typeof(w) == TYPE_DICTIONARY and w.has("route"):
			var rid := str(w["route"])
			first_use[rid] = mini(int(first_use.get(rid, 999)), int(w.get("turn", 999)))
			var all_tagged := true
			var options: Array = [w.get("units", [])]
			options.append_array(w.get("alt", []) if typeof(w.get("alt", [])) == TYPE_ARRAY else [])
			for opt in options:
				for spec in (opt if typeof(opt) == TYPE_ARRAY else []):
					var tg := _spec_all_tags(spec, roster)
					if not ("ambush" in tg or "boarder" in tg):
						all_tagged = false
			sneaky[rid] = bool(sneaky.get(rid, true)) and all_tagged
	var route_until := {}
	for rid in routes.keys():
		var until := _route_until(t, str(rid))
		if until >= 0:
			route_until[str(rid)] = until
		var lst := _route_labels(routes[rid])
		if lst.size() < 2:
			errs.append("route %s: needs at least 2 cells" % rid)
			continue
		var cells: Array = []
		var ok := true
		for lbl in lst:
			if not _label_ok(str(lbl), cols, rows):
				errs.append("route %s: bad cell %s" % [rid, lbl])
				ok = false
				break
			cells.append(_parse_label(str(lbl)))
		if not ok:
			continue
		var use_turn: int = int(first_use.get(str(rid), limit))
		var check_turns: Array = [use_turn, 999]
		if until >= 0:
			check_turns = []
			for tt in range(use_turn, mini(limit, until + cells.size()) + 1):
				check_turns.append(tt)
			if check_turns.is_empty():
				check_turns = [use_turn]
		for check in check_turns:
			var terr: Array = _terrain_at_turn(base, events, cols, rows, int(check))
			for i in range(cells.size()):
				var c: Array = cells[i]
				var tr: String = terr[int(c[1]) * cols + int(c[0])]
				var ti: Dictionary = _tinfo(tr)
				if tr == "void":
					errs.append("route %s: %s is void" % [rid, _label(int(c[0]), int(c[1]))])
				elif i == 0:
					var lbl0 := _label(int(c[0]), int(c[1]))
					var spawn_ok: bool = bool(sneaky.get(str(rid), false)) and ((lbl0 in spawns and bool(ti.get("spawn", false))) or tr == "plank")
					if not bool(ti.get("start", false)) and not spawn_ok:
						errs.append("route %s: must start at a gate (%s is %s)" % [rid, lbl0, tr])
				elif i == cells.size() - 1 and tr != "eagle":
					errs.append("route %s: must end at the eagle (%s is %s)" % [rid, _label(int(c[0]), int(c[1])), tr])
				elif i > 0 and i < cells.size() - 1 and not bool(ti["walk"]):
					errs.append("route %s: %s (%s) is not walkable" % [rid, _label(int(c[0]), int(c[1])), tr])
				if i > 0:
					var p: Array = cells[i - 1]
					if absi(int(p[0]) - int(c[0])) + absi(int(p[1]) - int(c[1])) != 1:
						errs.append("route %s: %s and %s are not adjacent" % [rid, _label(int(p[0]), int(p[1])), _label(int(c[0]), int(c[1]))])
			if not errs.is_empty():
				break
	for w in waves:
		if typeof(w) != TYPE_DICTIONARY:
			errs.append("wave is not a dictionary")
			continue
		var wt: int = int(w.get("turn", 0))
		if wt < 1 or wt > limit:
			errs.append("wave turn %d out of 1..%d" % [wt, limit])
		var has_route: bool = w.has("route")
		var has_at: bool = w.has("at")
		if has_route == has_at:
			errs.append("wave at turn %d needs exactly one of route / at" % wt)
			continue
		if has_route and not (routes as Dictionary).has(str(w["route"])):
			errs.append("wave at turn %d: unknown route %s" % [wt, w["route"]])
		if has_route and route_until.has(str(w["route"])) and wt > int(route_until[str(w["route"])]):
			errs.append("wave at turn %d: route %s is only used until turn %d" % [wt, w["route"], int(route_until[str(w["route"])])])
		var at_tr := ""
		if has_at and not _label_ok(str(w["at"]), cols, rows):
			errs.append("wave at turn %d: bad cell %s" % [wt, w["at"]])
			continue
		elif has_at:
			# at 格（炮、定点射手）：不在任何路线上（敌人不会走过去，也不会和我方单位抢格子：出现之前这一格不让部署）
			var ac: Array = _parse_label(str(w["at"]))
			at_tr = _terrain_at_turn(base, events, cols, rows, wt)[int(ac[1]) * cols + int(ac[0])]
			for rid2 in (routes as Dictionary).keys():
				if str(w["at"]) in _route_labels(routes[rid2]):
					errs.append("wave at turn %d: gun cell %s lies on route %s" % [wt, w["at"], rid2])
		if w.has("first_fire"):
			if not has_at:
				errs.append("wave at turn %d: first_fire is only for guns" % wt)
			elif int(w["first_fire"]) < wt + 1 or int(w["first_fire"]) > limit:
				errs.append("wave at turn %d: first_fire must be in %d..%d" % [wt, wt + 1, limit])
		for k in ["lv_min", "act_min"]:
			if w.has(k) and (typeof(w[k]) not in [TYPE_INT, TYPE_FLOAT] or int(w[k]) < 1 or int(w[k]) > MAX_LEVEL):
				errs.append("wave at turn %d: bad %s" % [wt, k])
		var options: Array = [w.get("units", [])]
		for alt in w.get("alt", []):
			options.append(alt)
		for opt in options:
			if typeof(opt) != TYPE_ARRAY or (opt as Array).is_empty():
				errs.append("wave at turn %d: empty unit list" % wt)
				continue
			for spec in opt:
				var kind := str(spec.get("kind", "")) if typeof(spec) == TYPE_DICTIONARY else str(spec)
				if not roster.has(kind):
					errs.append("wave at turn %d: unknown enemy %s%s" % [wt, kind, "" if roster.size() == ENEMIES.size() or not ENEMIES.has(kind) else " (new enemies need a template level)"])
					continue
				var tags := _spec_all_tags(spec, roster)
				for tg in tags:
					if not tg in KNOWN_TAGS:
						errs.append("wave at turn %d: unknown tag %s" % [wt, tg])
				var static_unit: bool = str(roster[kind]["type"]) == "gun" or "post" in tags
				if static_unit != has_at:
					errs.append("wave at turn %d: guns stand on 'at' cells, everyone else walks a route" % wt)
				elif has_at:
					var allowed: Array = roster[kind].get("at_terrain", ["high", "plain"])
					if "boat" in tags:
						allowed = ["sea"]
					elif "top" in tags:
						allowed = TOP
					if not at_tr in allowed:
						errs.append("wave at turn %d: gun cell %s must be %s, not %s" % [wt, w["at"], " or ".join(PackedStringArray(allowed)), at_tr])
				if typeof(spec) == TYPE_DICTIONARY:
					for k in ["lv_min", "act_min"]:
						if spec.has(k) and (typeof(spec[k]) not in [TYPE_INT, TYPE_FLOAT] or int(spec[k]) < 1 or int(spec[k]) > MAX_LEVEL):
							errs.append("wave at turn %d: %s has a bad %s" % [wt, kind, k])
	for key in ["order", "order_next"]:
		if t.has(key):
			errs.append_array(_validate_order(t[key], cols, rows, base, limit, key))
	return errs


## 新模板键的形状：level、base_level 与 pad、weather、spawns、kill_flags、objective、tutorial、route_until
static func _check_new_keys(t: Dictionary, cols: int, rows: int, base: Array, roster: Dictionary) -> Array:
	var errs: Array = []
	for k in ["level", "base_level"]:
		if t.has(k) and (typeof(t[k]) not in [TYPE_INT, TYPE_FLOAT] or int(t[k]) < 1 or int(t[k]) > MAX_LEVEL):
			errs.append("%s must be 1..%d" % [k, MAX_LEVEL])
	if t.has("pad"):
		var pad = t["pad"]
		if not t.has("base_level"):
			errs.append("pad needs base_level")
		if typeof(pad) != TYPE_DICTIONARY or not roster.has(str(pad.get("kind", ""))) or int(pad.get("every", 0)) < 1:
			errs.append("pad must be {kind: <enemy>, every: >= 1}")
		elif str(roster[str(pad["kind"])]["type"]) == "gun" or "post" in roster[str(pad["kind"])]["tags"]:
			errs.append("pad kind %s must walk a route" % pad["kind"])
	if t.has("weather"):
		var wl: Array = _weather_list(t["weather"])
		if wl.is_empty():
			errs.append("weather must be a non-empty list of %s" % ", ".join(PackedStringArray(WEATHERS)))
		for wid in wl:
			if not str(wid) in WEATHERS:
				errs.append("unknown weather %s" % wid)
	if t.has("spawns"):
		if typeof(t["spawns"]) != TYPE_ARRAY:
			errs.append("spawns must be a list of cells")
		else:
			for lbl in t["spawns"]:
				if not _label_ok(str(lbl), cols, rows):
					errs.append("spawns: bad cell %s" % lbl)
				else:
					var c: Array = _parse_label(str(lbl))
					var tr: String = base[int(c[1]) * cols + int(c[0])]
					if not bool(_tinfo(tr).get("spawn", false)):
						errs.append("spawns: %s is %s (village, woods, street, catacomb or plank only)" % [lbl, tr])
	if t.has("kill_flags"):
		if typeof(t["kill_flags"]) != TYPE_DICTIONARY:
			errs.append("kill_flags must be {enemy: flag}")
		else:
			for k in t["kill_flags"]:
				if not roster.has(str(k)) or typeof(t["kill_flags"][k]) != TYPE_STRING or str(t["kill_flags"][k]) == "":
					errs.append("kill_flags: bad entry %s" % k)
	if t.has("objective") and typeof(t["objective"]) != TYPE_DICTIONARY:
		errs.append("objective must be {type, desc}")
	if t.has("tutorial") and typeof(t["tutorial"]) != TYPE_BOOL:
		errs.append("tutorial must be true or false")
	if t.has("route_until"):
		if typeof(t["route_until"]) != TYPE_DICTIONARY:
			errs.append("route_until must be {route: turn}")
	return errs


# ================================================================ 指挥阶段的命令

static func _cmd_deploy(state: Dictionary, a: Dictionary) -> Dictionary:
	var uid := str(a.get("unit", ""))
	if not state["units"].has(uid):
		return _fail("no_unit")
	var u: Dictionary = state["units"][uid]
	var why := _deploy_block_reason(state, u)
	if why != "":
		return _fail(why)
	var col: int = int(a.get("col", -1))
	var row: int = int(a.get("row", -1))
	if not _in(state, col, row):
		return _fail("bad_cell")
	var facing := str(a.get("facing", "right"))
	if not DIRS.has(facing):
		return _fail("bad_facing")
	var start := str(state["order_goal"].get("start_cell", ""))
	if _mobile_order_unit(state, u) and start != "" and _parse_label(start) != [col, row]:
		return _fail("bad_cell")
	var perr := _place_err(state, u, col, row)
	if perr != "":
		return _fail(perr)
	state["cp"] = int(state["cp"]) - int(u["cost"])
	u["status"] = "ok"
	u["col"] = col
	u["row"] = row
	u["facing"] = facing
	u["acted"] = false
	u["charged"] = false
	u["aim"] = []
	u["deployed_turn"] = int(state["turn"])
	if not uid in state["deployed_ever"]:
		state["deployed_ever"].append(uid)
	_log(state, "部署%s到 %s（%s，%d 军令点）。" % [u["name"], _label(col, row), FACING_NAMES[facing], u["cost"]])
	if uid == HERO:
		state["hero"]["used"] = true
		_morale(state, 3, "主角亲临前线")
	_refresh_bonds(state)
	if u["cls"] == "hussar":
		_hussar_charge(state, u)
	return _ok()


static func _cmd_withdraw(state: Dictionary, a: Dictionary, full_refund: bool) -> Dictionary:
	var uid := str(a.get("unit", ""))
	if not state["units"].has(uid):
		return _fail("no_unit")
	var u: Dictionary = state["units"][uid]
	if u["kind"] in ["barricade", "npc"]:
		return _fail("no_unit")
	if u["status"] == "dying":
		return _fail("dying_use_carry")
	if u["status"] != "ok":
		return _fail("not_on_field")
	# 本回合刚部署的单位不能撤（后撤牌也不行）：部署错了用撤销。
	# 否则骠骑兵可以每回合“部署冲锋 → 撤下”，永远不站进敌方阶段。
	if int(u.get("deployed_turn", -1)) == int(state["turn"]):
		return _fail("just_deployed")
	if not Pairs.can_withdraw(state, uid):
		return _fail("bond_committed")
	var refund := 0
	if full_refund:
		refund = int(u["cost"])
	elif int(state["morale"]) > 3:
		refund = int(u["cost"]) / 2
	_remove_from_field(state, u)
	state["cp"] = mini(CP_CAP, int(state["cp"]) + refund)
	if uid == HERO:
		u["status"] = "out"
		state["hero"]["withdrawn"] = true
		_log(state, "主角撤下火线：本场不能再上。")
		_morale(state, -2, "主角中途撤下")
	else:
		u["status"] = "bar"
		u["cooldown"] = 0 if full_refund else (1 if u["cls"] == "hussar" else 2)
		_log(state, "撤下%s，返还 %d 军令点%s。" % [u["name"], refund, "" if full_refund else "，%d 回合后可再部署" % u["cooldown"]])
	_refresh_bonds(state)
	return _ok()


static func _cmd_skill(state: Dictionary, a: Dictionary) -> Dictionary:
	var uid := str(a.get("unit", ""))
	if not state["units"].has(uid):
		return _fail("no_unit")
	var u: Dictionary = state["units"][uid]
	# 主角不上场的技能“后方调度”：每场一次，军令点 +3；用了就不再亲临前线
	if uid == HERO and u["status"] == "bar":
		if bool(state["hero"]["dispatched"]) or bool(state["hero"]["used"]):
			return _fail("not_ready")
		state["hero"]["dispatched"] = true
		u["status"] = "out"
		state["cp"] = mini(CP_CAP, int(state["cp"]) + 3)
		_log(state, "主角在后方调度：军令点 +3（本场不再上阵）。")
		return _ok()
	if u["status"] != "ok":
		return _fail("not_on_field")
	var sk: String = u["skill"]
	if not SKILLS.has(sk):
		return _fail("no_skill")
	if int(u["charge"]) < int(SKILLS[sk]["charge"]):
		return _fail("not_ready")
	match sk:
		"bayonet_charge":
			var hit := 0
			for e in _blocked_by(state, uid):
				e["hp"] = int(e["hp"]) - 5
				hit += 1
				if int(e["hp"]) > 0:
					_knockback(state, e)
			if hit == 0:
				return _fail("no_target")
			_log(state, "%s刺刀冲锋：%d 个敌人各受 5 伤并被击退。" % [u["name"], hit])
			_sweep(state)
		"fortify":
			var c: int = int(a.get("col", -1))
			var r: int = int(a.get("row", -1))
			if not _in(state, c, r) or absi(c - int(u["col"])) + absi(r - int(u["row"])) != 1:
				return _fail("bad_cell")
			if _unit_at(state, c, r, false) != null or not _enemies_at(state, c, r).is_empty():
				return _fail("occupied")
			var tr: String = _terrain(state, c, r)
			if str(a.get("mode", "barricade")) == "earthwork":
				if tr != "plain" or _on_any_route(state, c, r):
					return _fail("terrain")
				state["terrain"][r * int(state["cols"]) + c] = "earthwork"
				_log(state, "%s在 %s 筑起胸墙（高地）。" % [u["name"], _label(c, r)])
			else:
				if not tr in GROUND:
					return _fail("terrain")
				if _reserved(state, c, r):
					return _fail("reserved")
				var bid := "barricade_%d" % int(state["next_obj"])
				state["next_obj"] = int(state["next_obj"]) + 1
				while state["units"].has(bid):
					bid = "barricade_%d" % int(state["next_obj"])
					state["next_obj"] = int(state["next_obj"]) + 1
				var bar := _mk_unit({"name": "拒马", "cls": "barricade"}, "barricade", bid)
				bar["status"] = "ok"
				bar["col"] = c
				bar["row"] = r
				bar["facing"] = u["facing"]
				state["units"][bid] = bar
				state["order"].append(bid)
				_log(state, "%s在 %s 放下一道拒马（阻挡 2，兵力 8）。" % [u["name"], _label(c, r)])
		"mark_target":
			var c2: int = int(a.get("col", -1))
			var r2: int = int(a.get("row", -1))
			if not [c2, r2] in _pattern_cells(state, u):
				return _fail("out_of_range")
			var cands := _enemies_at(state, c2, r2)
			if cands.is_empty():
				return _fail("no_target")
			var e2: Dictionary = _pick_jager_target(state, cands)
			var e2_name := _ename(state, e2)
			e2["hp"] = int(e2["hp"]) - 8
			_log(state, "%s点名射击%s：8 伤。" % [u["name"], e2_name])
			_sweep(state)
		"raise_flag":
			state["fx"]["flags"].append({"row": u["row"], "until": int(state["turn"]) + 1})
			_log(state, "%s举旗：第 %d 行友军攻 +2，持续 2 回合。" % [u["name"], int(u["row"]) + 1])
		"pay_chest":
			state["cp"] = mini(CP_CAP, int(state["cp"]) + 3)
			_log(state, "开箱发饷：军令点 +3。")
			_morale(state, 1, "开箱发饷")
	Pairs.after_skill(state, u, a, TERRAIN)
	u["charge"] = 0
	return _ok()


static func _cmd_card(state: Dictionary, a: Dictionary) -> Dictionary:
	var idx: int = int(a.get("index", -1))
	var hand: Array = state["hand"]
	if idx < 0 or idx >= hand.size():
		return _fail("bad_card")
	var h: Dictionary = hand[idx]
	if h["lock"] != "":
		return _fail("card_locked")
	var cid: String = h["id"]
	var cd: Dictionary = CARDS[cid]
	if int(cd["cost"]) > int(state["cp"]):
		return _fail("no_cp")
	state["cp"] = int(state["cp"]) - int(cd["cost"])
	var exhaust := false
	match cid:
		"volley":
			var r: int = int(a.get("row", -1))
			if r < 0 or r >= int(state["rows"]):
				return _fail("bad_row")
			state["fx"]["volley"].append(r)
			_log(state, "齐射：第 %d 行远程单位本回合攻 +2。" % (r + 1))
		"bayonet":
			var uid := str(a.get("unit", ""))
			var u = state["units"].get(uid)
			if u == null or u["status"] != "ok" or not _is_melee(u):
				return _fail("bad_unit")
			state["fx"]["bayonet"].append(uid)
			_log(state, "刺刀冲锋：%s本回合攻击两次，阻挡 −1。" % u["name"])
		"feint":
			var res := _feint(state, a)
			if not bool(res["ok"]):
				return res
		"bugler":
			var r2: int = int(a.get("row", -1))
			if r2 < 0 or r2 >= int(state["rows"]):
				return _fail("bad_row")
			var n := 0
			for e in state["enemies"]:
				if int(e["row"]) == r2 and e["type"] != "gun":
					e["slow_turn"] = int(state["turn"])
					e["weak_until"] = int(state["turn"]) + 1
					n += 1
			if n == 0:
				return _fail("no_target")
			_log(state, "虚张声势的号手：第 %d 行 %d 个敌人本回合速度 −1，两回合攻 −2。" % [r2 + 1, n])
			_lock_intents(state, false, r2)
		"barrage":
			var c3: int = int(a.get("col", -1))
			var r3: int = int(a.get("row", -1))
			if not _in(state, c3, r3):
				return _fail("bad_cell")
			if _count_cls(state, "artillery") == 0:
				return _fail("no_artillery")
			var in_range := 0
			for uid3 in state["order"]:
				var gu: Dictionary = state["units"][uid3]
				if gu["status"] == "ok" and gu["cls"] == "artillery" and [c3, r3] in _pattern_cells(state, gu):
					in_range += 1
			if in_range == 0:
				return _fail("out_of_range")
			state["fx"]["barrage"] = [c3, r3]
			_log(state, "集中炮火：射程够得着 %s 的 %d 门炮本回合都打这一格，无视装填。" % [_label(c3, r3), in_range])
		"fallback":
			var res2 := _cmd_withdraw(state, {"unit": a.get("unit", "")}, true)
			if not bool(res2["ok"]):
				return res2
		"requisition":
			state["cp"] = mini(CP_CAP, int(state["cp"]) + 2)
			state["requisitions"] = int(state["requisitions"]) + 1
			_log(state, "征发：军令点 +2（本幕民愤 +1）。")
		"emperor":
			if not state["scale"] in BOSS_SCALES:
				return _fail("major_only")
			exhaust = true
			for uid2 in state["order"]:
				var u2: Dictionary = state["units"][uid2]
				if u2["status"] == "ok":
					_add_charge(u2, 1)
			_log(state, "皇帝的命令到了：全体技能充能 +1。")
			_morale(state, 3, "皇帝的命令")
	hand.remove_at(idx)
	if exhaust:
		state["exhausted"].append(cid)
	else:
		state["discard"].append(cid)
	return _ok()


static func _feint(state: Dictionary, a: Dictionary) -> Dictionary:
	var c: int = int(a.get("col", -1))
	var r: int = int(a.get("row", -1))
	if not _in(state, c, r):
		return _fail("bad_cell")
	var want: int = int(a.get("enemy", -1))
	for e in state["enemies"]:
		if want >= 0 and int(e["uid"]) != want:
			continue
		var cur: Array = []
		if e["type"] == "gun" and not (e["aim"] as Array).is_empty():
			cur = e["aim"]
		elif e["type"] != "gun" and int(e["range"]) > 0 and e["lock_target"] != "":
			var tu: Dictionary = state["units"][e["lock_target"]]
			if tu["status"] == "ok":
				cur = [tu["col"], tu["row"]]
		if cur.is_empty() or absi(int(cur[0]) - c) + absi(int(cur[1]) - r) != 1:
			continue
		if e["type"] == "gun":
			e["aim"] = [c, r]
		else:
			var nu = _unit_at(state, c, r, true)
			e["lock_target"] = nu["uid"] if nu != null and nu["kind"] != "barricade" else ""
		e["feinted"] = true
		_log(state, "佯动：%s的目标挪到 %s。" % [e["name"], _label(c, r)])
		return _ok()
	return _fail("no_target")


static func _cmd_aim(state: Dictionary, a: Dictionary) -> Dictionary:
	var uid := str(a.get("unit", ""))
	var u = state["units"].get(uid)
	if u == null or u["status"] != "ok":
		return _fail("not_on_field")
	if u["cls"] != "artillery":
		return _fail("not_artillery")
	var c: int = int(a.get("col", -1))
	var r: int = int(a.get("row", -1))
	if not [c, r] in _pattern_cells(state, u):
		return _fail("out_of_pattern")
	u["aim"] = [c, r]
	_log(state, "%s瞄准 %s。" % [u["name"], _label(c, r)])
	return _ok()


static func _cmd_formation(state: Dictionary, a: Dictionary) -> Dictionary:
	var uid := str(a.get("unit", ""))
	var u = state["units"].get(uid)
	if u == null or u["status"] != "ok":
		return _fail("not_on_field")
	if u["kind"] == "npc" or (u["cls"] != "line" and u["cls"] != "grenadier"):
		return _fail("not_square_cls")
	var want: bool = bool(a.get("square", true))
	if want == bool(u["square"]):
		return _fail("no_change")
	var hand: Array = state["hand"]
	if want:
		var idx: int = int(a.get("index", -1))
		if idx < 0:
			for i in range(hand.size()):
				if hand[i]["lock"] == "":
					idx = i
					break
		if idx < 0 or idx >= hand.size() or hand[idx]["lock"] != "":
			return _fail("no_card")
		hand[idx]["lock"] = uid
		u["square"] = true
		_log(state, "%s结成方阵（扣下「%s」）：阻挡 +1，防 +2，不射击。" % [u["name"], CARDS[hand[idx]["id"]]["name"]])
	else:
		_release_square(state, u)
		_log(state, "%s解除方阵。" % u["name"])
	return _ok()


static func _cmd_carry(state: Dictionary, a: Dictionary) -> Dictionary:
	var uid := str(a.get("unit", ""))
	var u = state["units"].get(uid)
	if u == null or u["status"] != "dying":
		return _fail("not_dying")
	var cost := _carry_cost(state, u)
	if cost < 0:
		return _fail("no_adjacent")
	if int(state["cp"]) < cost:
		return _fail("no_cp")
	state["cp"] = int(state["cp"]) - cost
	_carry_off(state, u)
	_log(state, "把濒死的%s抬下战场（%d 军令点）。" % [u["name"], cost])
	return _ok()


## 抬下一个濒死伙伴要几个军令点：相邻有军医 0，相邻有别的我方单位 2，没人相邻 −1（抬不了）
static func _carry_cost(state: Dictionary, u: Dictionary) -> int:
	var helper := false
	for nb in _neighbors(int(u["col"]), int(u["row"])):
		var v = _unit_at(state, int(nb[0]), int(nb[1]), true)
		if v != null and v["kind"] != "barricade":
			if v["cls"] == "medic":
				return 0
			helper = true
	return 2 if helper else -1


## 界面用：濒死伙伴现在抬不下的原因（能抬是 ""）
static func _carry_reason(state: Dictionary, u: Dictionary) -> String:
	if u["status"] != "dying" or not _live(state):
		return ""
	var cost := _carry_cost(state, u)
	if cost < 0:
		return "no_adjacent"
	if cost > int(state["cp"]):
		return "no_cp"
	return ""


## 换牌：每回合一次，免费把一张没扣住的手牌放进弃牌堆，从牌组补一张
static func _cmd_redraw(state: Dictionary, a: Dictionary) -> Dictionary:
	if int(state["redraw_turn"]) == int(state["turn"]):
		return _fail("redraw_used")
	var idx: int = int(a.get("index", -1))
	var hand: Array = state["hand"]
	if idx < 0 or idx >= hand.size():
		return _fail("bad_card")
	if hand[idx]["lock"] != "":
		return _fail("card_locked")
	var cid: String = hand[idx]["id"]
	hand.remove_at(idx)
	state["discard"].append(cid)
	state["redraw_turn"] = int(state["turn"])
	_refill(state)
	_log(state, "换牌：放下「%s」，补一张。" % CARDS[cid]["name"])
	return _ok()


# ================================================================ 交火

static func _fight(state: Dictionary) -> void:
	_log(state, "—— 第 %d 回合交火 ——" % int(state["turn"]))
	state["undo"] = []
	# 敌军心一归零（指挥阶段的冲锋、点名，或 a / c 步的击杀）敌人当场溃逃：后面的敌方步骤不再进行
	var acted := false
	if int(state["enemy_morale"]) > 0:
		_step_a(state)
	if int(state["enemy_morale"]) > 0:
		acted = true
		_step_b(state)
		_step_c(state)
		if int(state["enemy_morale"]) > 0:
			_step_d(state)
	if not acted or int(state["enemy_morale"]) <= 0:
		_log(state, "敌军心归零，敌人溃逃。")
	_step_e(state, acted)


## a 我方远程先手：炮兵 → 猎兵 → 横队
static func _step_a(state: Dictionary) -> void:
	for cls in ["artillery", "jager", "line"]:
		for uid in state["order"]:
			var u: Dictionary = state["units"][uid]
			if u["kind"] == "npc" or u["status"] != "ok" or u["cls"] != cls or bool(u["charged"]) or _unit_atk(state, u) <= 0:
				continue
			match cls:
				"artillery": _fire_artillery(state, u)
				"jager": _fire_small_arms(state, u, true)
				"line":
					if not bool(u["square"]):
						_fire_small_arms(state, u, false)


static func _fire_artillery(state: Dictionary, u: Dictionary) -> void:
	var school := _bond_tier(state, "artillery_school")
	var barrage: Array = state["fx"]["barrage"]
	# 集中炮火只调动射程图样够得着那一格的炮
	if not barrage.is_empty() and not [int(barrage[0]), int(barrage[1])] in _pattern_cells(state, u):
		barrage = []
	if int(u["reload"]) > 0 and school < 2 and barrage.is_empty():
		return
	var cell: Array = []
	if not barrage.is_empty():
		cell = barrage
	elif not (u["aim"] as Array).is_empty():
		cell = u["aim"]
	else:
		var cands: Array = []
		for pc in _pattern_cells(state, u):
			cands.append_array(_enemies_at(state, int(pc[0]), int(pc[1])))
		if cands.is_empty():
			return
		var best: Dictionary = _pick_default(state, cands)
		cell = [best["col"], best["row"]]
	var atk := _ranged_atk(state, u)
	var f: Array = DIRS[u["facing"]]
	var hits := 0
	for e in _enemies_at(state, int(cell[0]), int(cell[1])):
		var dmg := maxi(1, atk - _enemy_def(state, e, true))
		e["hp"] = int(e["hp"]) - dmg
		hits += 1
	var pc2: Array = [int(cell[0]) + int(f[0]), int(cell[1]) + int(f[1])]
	if _in(state, int(pc2[0]), int(pc2[1])):
		for e in _enemies_at(state, int(pc2[0]), int(pc2[1])):
			var full := maxi(1, atk - _enemy_def(state, e, true))
			e["hp"] = int(e["hp"]) - (full if school >= 3 else full / 2)
			hits += 1
	u["reload"] = 0 if school >= 2 else 2
	u["acted"] = true
	_log(state, "%s炮击 %s，命中 %d 个敌人。" % [u["name"], _label(int(cell[0]), int(cell[1])), hits])
	_sweep(state)


static func _fire_small_arms(state: Dictionary, u: Dictionary, jager: bool) -> void:
	var cands: Array = []
	for pc in _pattern_cells(state, u):
		cands.append_array(_enemies_at(state, int(pc[0]), int(pc[1])))
	if cands.is_empty():
		return
	var e: Dictionary = _pick_jager_target(state, cands) if jager else _pick_default(state, cands)
	# 顶层射手打层 ≤ 1 的目标攻 +1；雨天小火器攻 −1（伤害仍至少 1）
	var atk := _ranged_atk(state, u) + _top_bonus(state, u, e) - (1 if _weather(state) == "rain" else 0)
	var dmg := maxi(1, atk - _enemy_def(state, e, true))
	e["hp"] = int(e["hp"]) - dmg
	u["acted"] = true
	_log(state, "%s射击%s：%d 伤。" % [u["name"], _ename(state, e), dmg])
	_sweep(state)


## b 敌人移动：离鹰旗近的先走；判定阻挡；走进鹰旗的扣军心并移除
static func _step_b(state: Dictionary, rec = null) -> void:
	_validate_blocks(state)
	for e in state["enemies"]:
		e["hunting"] = false
	var movers: Array = (state["enemies"] as Array).duplicate()
	movers.sort_custom(func(x, y): return _remaining(state, x) < _remaining(state, y) or (_remaining(state, x) == _remaining(state, y) and int(x["uid"]) < int(y["uid"])))
	var t: int = int(state["turn"])
	for e in movers:
		# 炮和定点射手（post）站在 at 格上，不走
		if _enemy_by_uid(state, int(e["uid"])).is_empty() or e["type"] == "gun" or e["route"] == "":
			continue
		if int(e["retreat_turn"]) == t:
			e["blocked_by"] = ""
			_knockback(state, e)
			continue
		if e["blocked_by"] != "":
			continue
		_move_enemy(state, e, rec)


## 敌人沿路线走：每进一格扣那一格的步耗（旧地形全是 1，所以和「每回合走 spd 格」一样）。
## 下一格步耗不够时停下，剩下的步数存进 mp 留到下回合（spd 1 的步兵过雪地两回合一格）；被挡住、被击退时清零。
## 下一格此刻走不了（门锁成墙、冰裂成河）就停在原地等。
static func _move_enemy(state: Dictionary, e: Dictionary, rec) -> void:
	var cells: Array = state["routes"][e["route"]]
	var t: int = int(state["turn"])
	var spd: int = maxi(0, int(e["spd"]) - (1 if int(e["slow_turn"]) == t else 0))
	var budget: int = spd + int(e.get("mp", 0))
	e.erase("mp")
	var hero = null
	if "hunter" in e["tags"] and state["units"][HERO]["status"] == "ok":
		hero = state["units"][HERO]
	while true:
		if _halts(state, e, cells, hero):
			return
		if int(e["step"]) >= cells.size() - 1:
			break
		var nx: Array = cells[int(e["step"]) + 1]
		var cost: int = _walk_cost(state, _terrain(state, int(nx[0]), int(nx[1])), e)
		if cost <= 0:
			break
		if budget < cost:
			if budget > 0:
				e["mp"] = budget
			break
		_advance(state, e, cells)
		budget -= cost
		if int(e["step"]) == cells.size() - 1:
			_reach_eagle(state, e, rec)
			return
	# 不会停在我方单位的格子上：步数刚好走到那一格时顺延，越过这一串（已经确认全满员的）单位，落在后面第一个空格
	while _unit_at(state, int(e["col"]), int(e["row"]), false) != null and int(e["step"]) < cells.size() - 1:
		_advance(state, e, cells)
		if int(e["step"]) == cells.size() - 1:
			_reach_eagle(state, e, rec)
			return
	_halts(state, e, cells, hero)


## 敌人这一步要不要停：猎官够着主角，或者被挡住。会写 hunting / blocked_by
static func _halts(state: Dictionary, e: Dictionary, cells: Array, hero) -> bool:
	if _unit_at(state, int(e["col"]), int(e["row"]), false) != null:
		return false
	# 猎官：够得着主角就停在他身边，下一步白刃打他
	if hero != null and _adjacent(int(e["col"]), int(e["row"]), int(hero["col"]), int(hero["row"])):
		e["hunting"] = true
		e.erase("mp")
		return true
	var g: Array = _gate(state, e, cells)
	if g[0] == "block":
		e["blocked_by"] = g[1]
		e.erase("mp")
		return true
	return false


## 敌人前方紧挨着的一串我方单位（沿路线，从下一格起连续有人的格子，濒死伙伴和拒马也算），到鹰旗或第一个空格为止
static func _chain(state: Dictionary, e: Dictionary, cells: Array) -> Array:
	var out: Array = []
	var i: int = int(e["step"]) + 1
	while i < cells.size() - 1:
		var u = _unit_at(state, int(cells[i][0]), int(cells[i][1]), false)
		if u == null:
			break
		out.append(u)
		i += 1
	return out


## 看前方：["free"] 下一格空着（或是鹰旗）；["block", uid] 被这个单位挡住；["pass"] 前面这一串单位全满员，穿过去。
## 这一串里第一个还有阻挡位的单位挡住它：它停在这一串的正前方，算被那个单位挡住（纵深阻挡），不会越过有空位的单位。
static func _gate(state: Dictionary, e: Dictionary, cells: Array) -> Array:
	var chain := _chain(state, e, cells)
	if chain.is_empty():
		return ["free", ""]
	# 重型占 2 个阻挡位；pierce（马穆鲁克、枪骑兵）要多 1 个空位才挡得住，占用照常
	var need := (2 if "heavy" in e["tags"] else 1) + (1 if "pierce" in e["tags"] else 0)
	for u in chain:
		if _block_free(state, u) >= need:
			return ["block", u["uid"]]
	return ["pass", ""]


## c 白刃：所有接敌的双方同时互打
static func _step_c(state: Dictionary) -> void:
	var hits: Array = []
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if u["kind"] == "npc" or u["status"] != "ok" or bool(u["acted"]) or bool(u["charged"]) or not _is_melee(u):
			continue
		var atk := _unit_atk(state, u)
		if atk <= 0:
			continue
		var target = null
		var mine := _blocked_by(state, uid)
		if not mine.is_empty():
			target = _lowest_hp(mine)
		else:
			var f: Array = DIRS[u["facing"]]
			var front := _enemies_at(state, int(u["col"]) + int(f[0]), int(u["row"]) + int(f[1]))
			if not front.is_empty():
				target = _lowest_hp(front)
		if target == null:
			continue
		var times := 2 if uid in state["fx"]["bayonet"] else 1
		for i in range(times):
			hits.append({"enemy": target, "dmg": maxi(1, atk - _enemy_def(state, target, false)), "by": u["name"]})
		u["acted"] = true
	for e in state["enemies"]:
		if e["type"] == "gun" or int(e["range"]) > 0:
			continue
		var tgt := ""
		if bool(e["hunting"]):
			tgt = HERO
		elif e["blocked_by"] != "":
			tgt = e["blocked_by"]
		if tgt == "" or _enemy_atk(state, e) <= 0:
			continue
		var tu: Dictionary = Pairs.target(state, e, state["units"][tgt])
		hits.append({"unit": tu["uid"], "dmg": _dmg_to_unit(state, e, tu, "melee"), "execute": "execute" in e["tags"], "by": e["name"],
			"arrest": "arrest" in e["tags"]})
	for h in hits:
		if h.has("enemy"):
			# 我方白刃也写进交火日志（和敌方 _hurt 同一个格式），玩家才看得出谁每回合砍掉多少
			h["enemy"]["hp"] = int(h["enemy"]["hp"]) - int(h["dmg"])
			_log(state, _hit_line(str(h["by"]), str(h["enemy"]["name"]), int(h["dmg"]), int(h["enemy"]["hp"])))
		else:
			_hurt(state, state["units"][h["unit"]], int(h["dmg"]), bool(h["execute"]), str(h["by"]), bool(h["arrest"]))
	_sweep(state)
	# skirmisher：接了白刃还活着，下一回合 b 步先后退 1 格并脱离阻挡（每 2 回合最多一次）
	var t: int = int(state["turn"])
	for e in state["enemies"]:
		if not "skirmisher" in e["tags"] or (e["blocked_by"] == "" and not bool(e["hunting"])):
			continue
		if e.has("skirm_turn") and t < int(e["skirm_turn"]) + 2:
			continue
		e["skirm_turn"] = t
		e["retreat_turn"] = t + 1
		_log(state, _txt("skirmish", {"name": e["name"]}))


## d 敌方远程和炮击落地；目标已经撤走就打空
static func _step_d(state: Dictionary) -> void:
	var t: int = int(state["turn"])
	var shooters: Array = (state["enemies"] as Array).duplicate()
	for e in shooters:
		if e["type"] == "gun":
			if int(e["fire_turn"]) == t and not (e["aim"] as Array).is_empty():
				var tu = _unit_at(state, int(e["aim"][0]), int(e["aim"][1]), true)
				if tu != null:
					tu = Pairs.target(state, e, tu)
					_hurt(state, tu, _dmg_to_unit(state, e, tu, "gun"), "execute" in e["tags"], e["name"])
				else:
					_log(state, "%s炮击 %s，打空了。" % [e["name"], _label(int(e["aim"][0]), int(e["aim"][1]))])
				# rocket：准星靠鹰旗一侧（列号 −1）那一格挨半伤
				if "rocket" in e["tags"] and int(e["aim"][0]) > 0:
					var sc: Array = [int(e["aim"][0]) - 1, int(e["aim"][1])]
					var su = _unit_at(state, int(sc[0]), int(sc[1]), true)
					_log(state, _txt("rocket", {"cell": _label(int(sc[0]), int(sc[1]))}))
					if su != null:
						su = Pairs.target(state, e, su)
						_hurt(state, su, maxi(1, _dmg_to_unit(state, e, su, "gun") / 2), "execute" in e["tags"], e["name"])
				e["aim"] = []
				# 风暴里敌炮艇（boat）每 3 回合一炮
				e["fire_turn"] = t + (3 if _weather(state) == "storm" and "boat" in e["tags"] else 2)
			continue
		if int(e["range"]) <= 0 or _enemy_atk(state, e) <= 0:
			continue
		var tgt := ""
		if e["blocked_by"] != "":
			tgt = e["blocked_by"]
		else:
			tgt = _ranged_valid_target(state, e)
			if tgt == "" and e["lock_target"] != "":
				_log(state, "%s的射击打空了。" % _ename(state, e))
		if tgt != "":
			var tu2: Dictionary = Pairs.target(state, e, state["units"][tgt])
			_hurt(state, tu2, _dmg_to_unit(state, e, tu2, "ranged"), "execute" in e["tags"], _ename(state, e))


## e 结算：溃散 / 濒死 / 主角倒下 → 军心 → 治疗、充能、冷却 → 胜负 → 新的一波
static func _step_e(state: Dictionary, enemy_acted: bool = true) -> void:
	var t: int = int(state["turn"])
	for f in state["fallen"]:
		if enemy_acted and state["units"][f["unit"]]["status"] == "dying" and int(f["turn"]) < t:
			f["survived"] = int(f["survived"]) + 1
	var changed := false
	for uid in state["order"].duplicate():
		var u: Dictionary = state["units"][uid]
		if u["status"] != "ok" or int(u["hp"]) > 0:
			continue
		changed = true
		match u["kind"]:
			"npc":
				_remove_from_field(state, u)
				u["status"] = "down"
				state["order_progress"]["failed"] = true
			"barricade":
				_remove_from_field(state, u)
				u["status"] = "routed"
				_log(state, "拒马被摧毁。")
			"troop":
				_remove_from_field(state, u)
				u["status"] = "routed"
				state["routed"].append(uid)
				_log(state, "%s溃散。" % u["name"])
				_morale(state, -1, "部队溃散")
			"hero":
				var guard := Pairs.save_hero(state)
				if guard != "":
					_fall_companion(state, state["units"][guard])
					continue
				state["hero"]["guard"] = _hero_guarded(state)
				state["hero"]["larrey"] = _larrey_on_field(state)
				_remove_from_field(state, u)
				u["status"] = "down"
				u["hp"] = 0
				state["hero"]["fell_turn"] = t
				_refresh_bonds(state)
				_log(state, "主角倒下，被抬离战场！")
				_morale(state, -5, "主角倒下")
			"companion":
				_fall_companion(state, u)
	if changed:
		_refresh_bonds(state)
	# 击杀触发的地形事件（牢门锁死、打开缺口……）：清点完阵亡再结算
	_on_kill_events(state)
	_heal(state)
	var pair_delta := Pairs.round_end(state)
	if pair_delta != 0:
		_morale(state, pair_delta, _txt("pair_morale"))
	_thirst(state, t)
	var quick: Array = _bond_members(state, "workshop") if _bond_tier(state, "workshop") >= 2 else []
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if u["status"] == "ok":
			_add_charge(u, 2 if uid in quick else 1)
			u["reload"] = maxi(0, int(u["reload"]) - 1)
		elif u["status"] == "bar" and int(u["cooldown"]) > 0:
			u["cooldown"] = int(u["cooldown"]) - 1
	_storm(state)
	_tick_order(state)
	if int(state["morale"]) <= 0:
		_finish(state, "defeat", "")
		return
	if int(state["enemy_morale"]) <= 0:
		_finish(state, "victory", "rout")
		return
	var future := false
	for w in state["waves"]:
		if not bool(w["spawned"]):
			future = true
	if not future and (state["enemies"] as Array).is_empty():
		# 场上清空、波次出完：一个都没漏是“来敌全歼”，有漏过去的只算“敌军攻势耗尽”
		_finish(state, "victory", "cleared" if int(state["leaks"]) == 0 else "spent")
		return
	if t >= int(state["turn_limit"]):
		_finish(state, "victory", "hold")
		return
	_begin_turn(state, t + 1)


static func _begin_turn(state: Dictionary, t: int) -> void:
	state["turn"] = t
	for ev in state["events"]:
		if int(ev["turn"]) == t:
			_set_terrain(state, int(ev["col"]), int(ev["row"]), str(ev["terrain"]), "")
	for w in state["waves"]:
		if not bool(w["spawned"]) and int(w["turn"]) == t:
			_spawn_wave(state, w)
	if t > 1:
		state["cp"] = mini(CP_CAP, int(state["cp"]) + _cp_gain(state))
	_refill(state)
	state["fx"]["volley"] = []
	state["fx"]["bayonet"] = []
	state["fx"]["barrage"] = []
	var flags: Array = []
	for fl in state["fx"]["flags"]:
		if int(fl["until"]) >= t:
			flags.append(fl)
	state["fx"]["flags"] = flags
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		u["acted"] = false
		u["charged"] = false
		u["aim"] = []
	for e in state["enemies"]:
		e["feinted"] = false
	_decapitation(state, t)
	_lock_intents(state, true)
	state["undo"] = []
	_log(state, "第 %d/%d 回合：军令点 %d，军心 %d，敌军心 %d。" % [t, int(state["turn_limit"]), int(state["cp"]), int(state["morale"]), int(state["enemy_morale"])])


static func _finish(state: Dictionary, outcome: String, kind: String) -> void:
	state["phase"] = "over"
	state["outcome"] = outcome
	state["victory_kind"] = kind
	state["undo"] = []
	var hero_on: bool = state["units"][HERO]["status"] == "ok"
	var done := false
	var og: Dictionary = state["order_goal"]
	if outcome == "victory" and not og.is_empty():
		if og.get("type", "") == "hold":
			var c: Array = _parse_label(str(og["cell"]))
			var u = _unit_at(state, int(c[0]), int(c[1]), true)
			done = u != null and u["kind"] != "barricade" and (int(state["turn"]) >= int(og["turn"]) or kind != "hold")
		elif og.get("type", "") == "no_leak":
			done = int(state["leaks"]) == 0
		else:
			done = _new_order_done(state, kind)
	state["end"] = {"hero_on_field": hero_on, "order_done": done, "qm_tier": _bond_tier(state, "quartermasters_men"),
		"spoils_tier": _bond_tier(state, "spoils"), "workshop_tier": _bond_tier(state, "workshop")}
	var names := {"victory": "胜利", "defeat": "战败", "retreat": "撤出"}
	var kinds := {"rout": "敌军溃逃", "cleared": "来敌全歼", "spent": "敌军攻势耗尽", "hold": "坚守到底", "": ""}
	_log(state, "战斗结束：%s%s。" % [names.get(outcome, outcome), ("（%s）" % kinds[kind]) if kind != "" else ""])


# ================================================================ 规则细节

## 来敌的全部标签：兵种自带的（龙骑兵的猎官、匈牙利掷弹兵的重型……）加上模板额外给的
static func _spec_tags(spec: Dictionary) -> Array:
	var tags: Array = (ENEMIES[spec["kind"]]["tags"] as Array).duplicate()
	for tg in spec["tags"]:
		if not tg in tags:
			tags.append(tg)
	return tags


## 一波敌人出场：兵力、攻、防按 LEVELS[L] 放大（攻、防的加成只加在原值大于 0 的敌人身上）。
## 起点此刻已经封死（牢门锁成墙……）的这一波就不来了。
static func _spawn_wave(state: Dictionary, w: Dictionary) -> void:
	w["spawned"] = true
	if (w["at"] as Array).is_empty():
		var c0: Array = state["routes"][w["route"]][0]
		var ti: Dictionary = _tinfo(_terrain(state, int(c0[0]), int(c0[1])))
		if not bool(ti.get("start", false)) and not (bool(ti["walk"]) and ti["stand"] == "ground"):
			_log(state, _txt("wave_sealed", {"cell": _label(int(c0[0]), int(c0[1]))}))
			return
	var lr: Array = LEVELS[_lv(state) - 1]
	var names: Array = []
	for spec in w["units"]:
		var base: Dictionary = ENEMIES[spec["kind"]]
		var hp: int = maxi(1, int(base["hp"]) * int(lr[0]) / 100)
		var tags: Array = (base["tags"] as Array).duplicate()
		for tg in spec["tags"]:
			if not tg in tags:
				tags.append(tg)
		var e := {
			"uid": int(state["next_enemy"]), "kind": spec["kind"], "name": base["name"], "type": base["type"],
			"hp": hp, "max_hp": hp, "atk": int(base["atk"]) + (int(lr[2]) if int(base["atk"]) > 0 else 0),
			"def": int(base["def"]) + (int(lr[3]) if int(base["def"]) > 0 else 0), "spd": base["spd"], "range": base["range"], "tags": tags,
			"route": w["route"], "step": 0, "col": 0, "row": 0, "column": w["column"],
			"blocked_by": "", "lock_target": "", "aim": [], "fire_turn": int(w["first_fire"]) if base["type"] == "gun" else -1, "hunting": false,
			"slow_turn": -1, "weak_until": -1, "retreat_turn": -1, "atk_down": 0, "feinted": false,
		}
		if (w["at"] as Array).is_empty():
			var c0: Array = state["routes"][w["route"]][0]
			e["col"] = c0[0]
			e["row"] = c0[1]
		else:
			e["col"] = w["at"][0]
			e["row"] = w["at"][1]
		state["next_enemy"] = int(state["next_enemy"]) + 1
		state["enemies"].append(e)
		names.append(_unknown_name() if "stealth" in tags else base["name"])
	_log(state, "敌军新的一波在 %s 出现：%s。" % [_label(int(state["enemies"][-1]["col"]), int(state["enemies"][-1]["row"])), "、".join(PackedStringArray(names))])


## 意图锁定：敌炮提前一回合定下准星；远程敌人按预测的落脚点锁定目标（之后目标撤走就打空）
## only_row >= 0（号手）：只重算那一行的远程敌人；被佯动挪过目标的敌人保留佯动后的目标
static func _lock_intents(state: Dictionary, aim_guns: bool, only_row: int = -1) -> void:
	var t: int = int(state["turn"])
	if aim_guns:
		# 敌炮每 2 回合一炮：fire_turn 是下一炮的回合，前一回合定下准星（模板可用 first_fire 指定第一炮）
		for e in state["enemies"]:
			if e["type"] != "gun" or not (e["aim"] as Array).is_empty() or int(e["fire_turn"]) > t + 1:
				continue
			var cell := _gun_pick(state, e)
			if not cell.is_empty():
				e["aim"] = cell
				e["fire_turn"] = t + 1
				_log(state, "%s的准星落在 %s（下回合开炮）。" % [e["name"], _label(int(cell[0]), int(cell[1]))])
	var any := false
	for e in state["enemies"]:
		if e["type"] != "gun" and int(e["range"]) > 0:
			any = true
	if not any:
		return
	var sim := _sim_copy(state)
	_step_a(sim)
	_step_b(sim)
	for e in state["enemies"]:
		if e["type"] == "gun" or int(e["range"]) <= 0:
			continue
		if only_row >= 0 and (int(e["row"]) != only_row or bool(e.get("feinted", false))):
			continue
		var se := _enemy_by_uid(sim, int(e["uid"]))
		e["lock_target"] = "" if se.is_empty() else _pick_ranged_target(sim, se)


## 斩首令（设计稿“主角与伙伴·风险”）：L ≥ 7（= 第 4 幕起）的精英战和会战，敌将每场一次；遭遇战没有。
## 主角在场的第一个回合（第 3 回合起）发令并亮在敌情里；下一回合所有敌方远程够得着就打主角，那一回合开炮的敌炮准星也落在他身上。
static func _decapitation(state: Dictionary, t: int) -> void:
	if bool(state["decap_used"]) or _lv(state) < 7 or state["scale"] == "skirmish" or t < 3:
		return
	if state["units"][HERO]["status"] != "ok" or t >= int(state["turn_limit"]):
		return
	state["decap_used"] = true
	state["decap_turn"] = t + 1
	_log(state, "敌将下了斩首令：第 %d 回合所有远程都打主角！" % (t + 1))


static func _decap_now(state: Dictionary, t: int) -> bool:
	return int(state["decap_turn"]) == t and state["units"][HERO]["status"] == "ok"


## 敌炮选准星：猎官炮和斩首令瞄主角；否则最近的地面单位（高地、顶层上的排在后面），同距打兵力低的。
## 洞穴里的单位不瞄；short（卡隆炮、缉私快艇）只瞄列差 ≤ 4 的格子
static func _gun_pick(state: Dictionary, e: Dictionary) -> Array:
	var hero: Dictionary = state["units"][HERO]
	if ("hunter" in e["tags"] or _decap_now(state, int(state["turn"]) + 1)) and hero["status"] == "ok" and _gun_can_aim(state, e, hero):
		return [hero["col"], hero["row"]]
	var best = null
	var best_key: Array = []
	for i in range((state["order"] as Array).size()):
		var u: Dictionary = state["units"][state["order"][i]]
		if u["status"] != "ok" or u["kind"] == "barricade" or not _gun_can_aim(state, e, u):
			continue
		var on_high := 1 if str(_tinfo(_terrain(state, int(u["col"]), int(u["row"])))["stand"]) in ["high", "top"] else 0
		var key := [on_high, absi(int(u["col"]) - int(e["col"])) + absi(int(u["row"]) - int(e["row"])), int(u["hp"]), i]
		if best == null or _key_less(key, best_key):
			best = u
			best_key = key
	return [] if best == null else [best["col"], best["row"]]


## 远程敌人锁定目标：够得着（射程按顶层 +1、黑暗 −1）、视线通；猎官和斩首令先打主角；
## 否则最近的、同距兵力低的。sniper 先挑主角和伙伴
static func _pick_ranged_target(state: Dictionary, e: Dictionary) -> String:
	var hero: Dictionary = state["units"][HERO]
	var rng: int = _erange(state, e)
	if ("hunter" in e["tags"] or _decap_now(state, int(state["turn"]))) and hero["status"] == "ok" and _dist(e, hero) <= rng and _los_to(state, e, hero):
		return HERO
	var sniper: bool = "sniper" in e["tags"]
	var best := ""
	var best_key: Array = []
	for i in range((state["order"] as Array).size()):
		var u: Dictionary = state["units"][state["order"][i]]
		if u["status"] != "ok" or u["kind"] == "barricade" or _dist(e, u) > rng or not _los_to(state, e, u):
			continue
		var key := [_dist(e, u), int(u["hp"]), i]
		if sniper:
			key = [0 if u["kind"] == "hero" or u["kind"] == "companion" else 1, _dist(e, u), int(u["hp"]), i]
		if best == "" or _key_less(key, best_key):
			best = u["uid"]
			best_key = key
	return best


static func _ranged_valid_target(state: Dictionary, e: Dictionary) -> String:
	var lt: String = e["lock_target"]
	if lt == "" or not state["units"].has(lt):
		return ""
	var u: Dictionary = state["units"][lt]
	if u["status"] != "ok" or _dist(e, u) > _erange(state, e) or not _los_to(state, e, u):
		return ""
	return lt


## 骠骑兵部署冲锋：前方 3 格（骑兵预备队 +1，泥泞天 −1）内有敌人才冲；遇到站不了的格子（虚空、墙、河……）就停，冲进泥地也停
static func _hussar_charge(state: Dictionary, u: Dictionary) -> void:
	var dist := 3 + (1 if _bond_tier(state, "cavalry_reserve") >= 2 else 0) - (1 if _weather(state) == "mud" else 0)
	var f: Array = DIRS[u["facing"]]
	var stop := 0
	var target: Array = []
	for k in range(1, dist + 1):
		var c: int = int(u["col"]) + int(f[0]) * k
		var r: int = int(u["row"]) + int(f[1]) * k
		if not _in(state, c, r):
			break
		if not _enemies_at(state, c, r).is_empty():
			target = [c, r]
			break
		if _place_err(state, u, c, r) != "":
			break
		stop = k
		if _terrain(state, c, r) == "mud" and not Pairs.charge_ignores_slow(state, u):
			break
	if target.is_empty():
		_log(state, "%s冲锋：%d 格内没有敌人。" % [u["name"], dist])
		return
	u["col"] = int(u["col"]) + int(f[0]) * stop
	u["row"] = int(u["row"]) + int(f[1]) * stop
	var atk := _unit_atk(state, u) * 2
	var kills_before: int = int(state["kills"])
	var n := 0
	for e in _enemies_at(state, int(target[0]), int(target[1])):
		e["hp"] = int(e["hp"]) - maxi(1, atk - _enemy_def(state, e, false))
		n += 1
		if int(e["hp"]) > 0:
			_knockback(state, e)
	u["charged"] = true
	_log(state, "%s冲锋到 %s，冲击 %s 的 %d 个敌人（攻×2）并击退 1 格。" % [u["name"], _label(int(u["col"]), int(u["row"])), _label(int(target[0]), int(target[1])), n])
	_sweep(state)
	if _bond_tier(state, "cavalry_reserve") >= 3 and int(state["kills"]) > kills_before:
		state["cp"] = mini(CP_CAP, int(state["cp"]) + 2)
		_log(state, "骑兵预备队：冲锋斩获，返还 2 军令点。")
	Pairs.after_charge(state, u, kills_before)


static func _fall_companion(state: Dictionary, u: Dictionary) -> void:
	Pairs.on_fall(state, u, SKILLS)
	var uid: String = u["uid"]
	_release_square(state, u)
	for e in _blocked_by(state, uid):
		e["blocked_by"] = ""
	u["hp"] = 0
	# 军需官的人（主角 + 2 人）看的是他倒下那一刻的档位，所以先记下来
	var qm_tier := _bond_tier(state, "quartermasters_men")
	u["status"] = "dying"
	# 濒死的伙伴不再计入羁绊：先重算，再看随军家眷、拉雷还算不算数
	_refresh_bonds(state)
	state["fallen"].append({"unit": uid, "turn": int(state["turn"]), "execute": bool(u.get("exec_down", false)),
		"scarred": bool(u["scarred"]) or bool(u["fated"]), "fated": bool(u["fated"]), "carried": false, "carry_turn": -1,
		"survived": 0, "larrey": _larrey_on_field(state), "family": _bond_tier(state, "camp_family") >= 2})
	_log(state, "%s倒下，濒死（留在原格，阻挡 0）。" % u["name"])
	_morale(state, -2, "伙伴倒下")
	if not bool(state["qm_carry_used"]) and qm_tier >= 3:
		state["qm_carry_used"] = true
		_carry_off(state, u)
		_log(state, "军需官的人：%s视为已经被抬下。" % u["name"])


static func _carry_off(state: Dictionary, u: Dictionary) -> void:
	_remove_from_field(state, u)
	u["status"] = "carried"
	for f in state["fallen"]:
		if f["unit"] == u["uid"] and not bool(f["carried"]):
			f["carried"] = true
			f["carry_turn"] = int(state["turn"])


static func _hurt(state: Dictionary, u: Dictionary, dmg: int, execute: bool, by: String, arrest: bool = false) -> void:
	if u["status"] != "ok" or dmg <= 0:
		return
	var before: int = int(u["hp"])
	u["hp"] = before - dmg
	if before > 0 and int(u["hp"]) <= 0 and execute and u["kind"] == "companion":
		u["exec_down"] = true
	_log(state, _hit_line(by, str(u["name"]), dmg, int(u["hp"])))
	# arrest：主角在宪兵、探员的白刃下倒下，不掷铜钱，直接被俘
	if arrest and u["uid"] == HERO and before > 0 and int(u["hp"]) <= 0 and not bool(state["hero"].get("arrested", false)):
		state["hero"]["arrested"] = true
		_log(state, _txt("arrest", {"by": by}))


## 一次白刃 / 射击落下的日志：「X打Y：N 伤（剩 M）。」敌打我、我打敌同一个格式
static func _hit_line(by: String, target: String, dmg: int, left: int) -> String:
	return "%s打%s：%d 伤（剩 %d）。" % [by, target, dmg, maxi(0, left)]


static func _heal(state: Dictionary) -> void:
	var healed := {}
	for uid in state["order"]:
		var m: Dictionary = state["units"][uid]
		if m["status"] != "ok" or m["cls"] != "medic":
			continue
		var best = null
		for vid in state["order"]:
			var v: Dictionary = state["units"][vid]
			if v["status"] != "ok" or v["kind"] == "barricade" or int(v["hp"]) >= int(v["max_hp"]) or _dist(m, v) > 2:
				continue
			if best == null or int(v["hp"]) < int(best["hp"]):
				best = v
		if best != null:
			# 雪天军医回复 −1
			var amt: int = 3 - (1 if _weather(state) == "snow" else 0)
			best["hp"] = mini(int(best["max_hp"]), int(best["hp"]) + amt)
			_log(state, "%s给%s回 %d 兵力。" % [m["name"], best["name"], amt])
	if _bond_tier(state, "camp_family") >= 2:
		var fam: Array = _bond_members(state, "camp_family")
		for uid in state["order"]:
			var fm: Dictionary = state["units"][uid]
			if fm["status"] != "ok" or not uid in fam or fm["kind"] != "companion":
				continue
			for vid in state["order"]:
				var v2: Dictionary = state["units"][vid]
				if v2["status"] == "ok" and v2["kind"] != "barricade" and not healed.has(vid) and _dist(fm, v2) <= 2 and int(v2["hp"]) < int(v2["max_hp"]):
					v2["hp"] = int(v2["hp"]) + 1
					healed[vid] = true


static func _sweep(state: Dictionary) -> void:
	while true:
		var dead = null
		for e in state["enemies"]:
			if int(e["hp"]) <= 0:
				dead = e
				break
		if dead == null:
			return
		_kill(state, dead)


## 敌人阵亡（how 是 "" 时是打死的；"drowned" / "fell" 是脚下的格子变了，落水或坠落，一样按击杀算）
static func _kill(state: Dictionary, e: Dictionary, how: String = "") -> void:
	var lst: Array = state["enemies"]
	for i in range(lst.size()):
		if int(lst[i]["uid"]) == int(e["uid"]):
			lst.remove_at(i)
			break
	state["kills"] = int(state["kills"]) + 1
	if state.has("killed_kinds"):
		state["killed_kinds"][e["kind"]] = int(state["killed_kinds"].get(e["kind"], 0)) + 1
	for ev in state["events"]:
		if str(ev.get("on_kill", "")) == str(e["kind"]) and not bool(ev["done"]):
			ev["armed"] = true
	var loss: int = int(KILL_ENEMY_MORALE.get(e["type"], 1))
	state["enemy_morale"] = maxi(0, int(state["enemy_morale"]) - loss)
	if how == "":
		_log(state, "击毙%s，敌军心 −%d（%d）。" % [e["name"], loss, int(state["enemy_morale"])])
	else:
		_log(state, _txt(how, {"name": e["name"], "loss": loss, "em": int(state["enemy_morale"])}))
	var gain: int = int(KILL_OUR_MORALE.get(e["type"], 0))
	if gain > 0:
		_morale(state, gain, "击杀精英" if e["type"] == "elite" else "击溃纵队")
	if e["type"] == "wagon":
		var n := 0
		for o in lst:
			if absi(int(o["col"]) - int(e["col"])) + absi(int(o["row"]) - int(e["row"])) <= 1:
				o["hp"] = int(o["hp"]) - 6
				n += 1
		_log(state, "弹药车爆炸：周围 %d 个敌人各受 6 伤。" % n)
	if e["type"] == "leader":
		for o in lst:
			if int(o["column"]) == int(e["column"]):
				o["retreat_turn"] = int(state["turn"]) + 1
				o["atk_down"] = int(o["atk_down"]) + 1
		_log(state, "纵队长阵亡：该纵队下回合后退 1 格，攻 −1。")
		if _bond_tier(state, "army_of_italy") >= 4:
			for uid in state["order"]:
				if state["units"][uid]["status"] == "ok":
					_add_charge(state["units"][uid], 1)


static func _reach_eagle(state: Dictionary, e: Dictionary, rec) -> void:
	var lst: Array = state["enemies"]
	for i in range(lst.size()):
		if int(lst[i]["uid"]) == int(e["uid"]):
			lst.remove_at(i)
			break
	state["leaks"] = int(state["leaks"]) + 1
	if rec != null:
		rec["reached"][int(e["uid"])] = [e["col"], e["row"]]
	_log(state, "%s冲进鹰旗！" % e["name"])
	# loot：抢走一批军需（战后法郎 −15%/个）；ransom：掳走一名人质（战后 −1 金币/个），都在战役层扣
	if "loot" in e["tags"]:
		state["loot"] = int(state.get("loot", 0)) + 1
		_log(state, _txt("loot", {"name": e["name"]}))
	if "ransom" in e["tags"]:
		state["ransom"] = int(state.get("ransom", 0)) + 1
		_log(state, _txt("ransom", {"name": e["name"]}))
	_morale(state, -_eagle_loss(e), "敌人走进鹰旗")


static func _eagle_loss(e: Dictionary) -> int:
	if e["type"] == "general":
		return 5
	return 3 if e["type"] == "elite" or e["type"] == "leader" else 2


## 军心增减：上限 15（意大利军团 4 档 +2）；主角在场时第一次掉到 3 以下，“站住！”拉回 3，主角兵力 −4（最低留 1）
static func _morale(state: Dictionary, delta: int, why: String) -> void:
	var m: int = int(state["morale"]) + delta
	m = mini(m, maxi(_morale_cap(state), int(state["morale"])))
	m = Pairs.morale(state, m)
	var hero: Dictionary = state["units"][HERO]
	if delta < 0 and m < 3 and hero["status"] == "ok" and not bool(state["hero"]["rally_used"]):
		state["hero"]["rally_used"] = true
		m = 3
		hero["hp"] = maxi(1, int(hero["hp"]) - 4)
		_log(state, "主角高喊“站住！”，军心稳在 3（主角兵力 −4）。")
	state["morale"] = maxi(0, m)
	_log(state, "%s：军心 %s%d（%d）。" % [why, "+" if delta >= 0 else "", delta, int(state["morale"])])


static func _morale_cap(state: Dictionary) -> int:
	return 15 + (2 if _bond_tier(state, "army_of_italy") >= 4 else 0)


## 来敌提前几回合公开：平时 2，情报效果 3 档 3；雾天、夜战各 −1
static func _horizon(state: Dictionary) -> int:
	var h := 3 if _bond_tier(state, "intel") >= 3 else 2
	if _weather(state) in ["fog", "night"]:
		h -= 1
	return h + Pairs.forecast(state)


## 每回合军令点：3（雪天 2）+ 主角在场 1 + 意大利军团 3 档 1
static func _cp_gain(state: Dictionary) -> int:
	var g := 3 - (1 if _weather(state) == "snow" else 0)
	if state["units"][HERO]["status"] == "ok":
		g += 1
	if _bond_tier(state, "army_of_italy") >= 3:
		g += 1
	return g


static func _refresh_bonds(state: Dictionary) -> void:
	var hero_on: bool = state["units"][HERO]["status"] == "ok"
	var raw := {}
	var defs: Array = _bond_defs(state)
	for bd in defs:
		var bid: String = bd["id"]
		var members: Array = []
		for uid in state["order"]:
			var u: Dictionary = state["units"][uid]
			if u["status"] != "ok" or u["kind"] in ["barricade", "npc"]:
				continue
			if bd["kind"] == "class":
				if u["cls"] == bd["cls"]:
					members.append(uid)
			elif (u["kind"] == "companion" or u["kind"] == "hero") and str(bd["tag"]) in u["tags"]:
				members.append(uid)
		if bool(bd.get("adjacent", false)):
			members = _largest_group(state, members)
		var count := members.size()
		if bool(bd.get("hero", false)):
			if hero_on:
				if not HERO in members:
					members.append(HERO)
				count = members.size()
			else:
				count = 0
				members = []
		var tier := 0
		for th in bd["tiers"]:
			if count >= int(th):
				tier = int(th)
		raw[bid] = {"count": count, "tier": tier, "active": false, "members": members}
	var cands: Array = []
	for i in range(defs.size()):
		if int(raw[defs[i]["id"]]["tier"]) > 0:
			cands.append([-int(raw[defs[i]["id"]]["tier"]), i])
	cands.sort()
	for k in range(mini(3, cands.size())):
		var bid2: String = defs[int(cands[k][1])]["id"]
		raw[bid2]["active"] = true
		if not bid2 in state["bonds_seen"]:
			state["bonds_seen"].append(bid2)
	state["bonds"] = raw
	Pairs.refresh(state)


## 某种效果此刻生效的最高档（内置羁绊的效果就是羁绊 id）
static func _bond_tier(state: Dictionary, effect: String) -> int:
	var best := 0
	for bd in _bond_defs(state):
		if str(bd["effect"]) != effect:
			continue
		var b: Dictionary = state["bonds"].get(bd["id"], {})
		if bool(b.get("active", false)):
			best = maxi(best, int(b.get("tier", 0)))
	return best


## 某种效果此刻生效的羁绊成员（几条同效果羁绊取并集）
static func _bond_members(state: Dictionary, effect: String) -> Array:
	var out: Array = []
	for bd in _bond_defs(state):
		if str(bd["effect"]) != effect:
			continue
		var b: Dictionary = state["bonds"].get(bd["id"], {})
		if bool(b.get("active", false)):
			for m in b.get("members", []):
				if not m in out:
					out.append(m)
	return out


static func _bond_defs(state: Dictionary) -> Array:
	if state.has("bond_defs"):
		return state["bond_defs"]
	if _builtin_bond_defs.is_empty():
		for bid in BOND_ORDER:
			var d: Dictionary = (BONDS[bid] as Dictionary).duplicate(true)
			d["id"] = bid
			d["effect"] = bid
			_builtin_bond_defs.append(d)
	return _builtin_bond_defs


## setup.bonds（整套定义）> setup.bond_set（battle_templates.json 的 bond_sets）> 内置六条
static func _resolve_bonds(su: Dictionary) -> Dictionary:
	var src = null
	if su.has("bonds"):
		src = su["bonds"]
	elif su.has("bond_set"):
		var sets: Dictionary = load_templates().get("bond_sets", {})
		if not sets.has(str(su["bond_set"])):
			return {"errors": ["unknown bond_set %s" % str(su["bond_set"])], "defs": [], "custom": false}
		src = sets[str(su["bond_set"])]
	else:
		return {"errors": [], "defs": [], "custom": false}
	var errs := validate_bonds(src)
	if not errs.is_empty():
		return {"errors": errs, "defs": [], "custom": false}
	var defs: Array = []
	for entry in src:
		if typeof(entry) == TYPE_STRING:
			var d: Dictionary = (BONDS[entry] as Dictionary).duplicate(true)
			d["id"] = str(entry)
			d["effect"] = str(entry)
			defs.append(d)
		else:
			var d2: Dictionary = {"id": str(entry["id"]), "name": str(entry.get("name", entry["id"])), "kind": str(entry["kind"]),
				"tiers": [], "desc": str(entry.get("desc", "")), "effect": str(entry["effect"])}
			for th in entry["tiers"]:
				d2["tiers"].append(int(th))
			if d2["kind"] == "class":
				d2["cls"] = str(entry["cls"])
			else:
				d2["tag"] = str(entry["tag"])
			if bool(entry.get("adjacent", false)):
				d2["adjacent"] = true
			if bool(entry.get("hero", false)):
				d2["hero"] = true
			defs.append(d2)
	return {"errors": [], "defs": defs, "custom": true}


## 校验一套羁绊：每条是内置羁绊的 id，或者 {id, name, kind: class|faction, cls|tag, tiers, effect, desc?, adjacent?, hero?}
static func validate_bonds(src) -> Array:
	if typeof(src) != TYPE_ARRAY or (src as Array).is_empty():
		return ["bond set must be a non-empty array"]
	var errs: Array = []
	var seen := {}
	for entry in src:
		var bid := ""
		if typeof(entry) == TYPE_STRING:
			bid = str(entry)
			if not BONDS.has(bid):
				errs.append("unknown builtin bond %s" % bid)
		elif typeof(entry) == TYPE_DICTIONARY:
			bid = str(entry.get("id", ""))
			var kind := str(entry.get("kind", ""))
			var effect := str(entry.get("effect", ""))
			if bid == "":
				errs.append("bond without id")
			if not kind in ["class", "faction"]:
				errs.append("%s: kind must be class or faction" % bid)
			if not effect in BOND_EFFECTS:
				errs.append("%s: unknown effect %s" % [bid, effect])
			elif CLASS_EFFECTS.has(effect) != (kind == "class"):
				errs.append("%s: effect %s needs kind %s" % [bid, effect, "class" if CLASS_EFFECTS.has(effect) else "faction"])
			elif kind == "class" and str(entry.get("cls", "")) != str(CLASS_EFFECTS[effect]):
				errs.append("%s: effect %s counts %s" % [bid, effect, CLASS_EFFECTS[effect]])
			if kind == "faction" and (typeof(entry.get("tag")) != TYPE_STRING or str(entry.get("tag")) == ""):
				errs.append("%s: faction bond needs a tag" % bid)
			var tiers = entry.get("tiers", [])
			if typeof(tiers) != TYPE_ARRAY or (tiers as Array).is_empty():
				errs.append("%s: tiers must be a non-empty array" % bid)
			else:
				var last := 0
				for th in tiers:
					if not typeof(th) in [TYPE_INT, TYPE_FLOAT] or int(th) <= last or float(th) != float(int(th)):
						errs.append("%s: tiers must be ascending integers >= 1" % bid)
						break
					last = int(th)
		else:
			errs.append("bond entry must be a builtin id or a dictionary")
			continue
		if seen.has(bid):
			errs.append("duplicate bond %s" % bid)
		seen[bid] = true
	return errs


static func _largest_group(state: Dictionary, members: Array) -> Array:
	var best: Array = []
	var seen := {}
	for m in members:
		if seen.has(m):
			continue
		var group: Array = []
		var queue: Array = [m]
		seen[m] = true
		while not queue.is_empty():
			var cur: String = queue.pop_front()
			group.append(cur)
			var cu: Dictionary = state["units"][cur]
			for o in members:
				if not seen.has(o):
					var ou: Dictionary = state["units"][o]
					if _adjacent(int(cu["col"]), int(cu["row"]), int(ou["col"]), int(ou["row"])):
						seen[o] = true
						queue.append(o)
		if group.size() > best.size():
			best = group
	return best if best.size() >= 2 else []


static func _refill(state: Dictionary) -> void:
	var hand: Array = state["hand"]
	var size: int = HAND_SIZE + (1 if _bond_tier(state, "intel") >= 2 else 0)
	while hand.size() < size:
		if (state["deck"] as Array).is_empty():
			if (state["discard"] as Array).is_empty():
				return
			var rest: Array = (state["discard"] as Array).duplicate()
			var nd: Array = []
			for cid in state["deck_base"]:
				var i: int = rest.find(cid)
				if i >= 0:
					nd.append(cid)
					rest.remove_at(i)
			nd.append_array(rest)
			state["deck"] = nd
			state["discard"] = []
		hand.append({"id": (state["deck"] as Array).pop_front(), "lock": ""})


static func _validate_blocks(state: Dictionary) -> void:
	for e in state["enemies"]:
		var bid: String = e["blocked_by"]
		if bid == "":
			continue
		var ok := false
		if state["units"].has(bid) and e["route"] != "":
			var u: Dictionary = state["units"][bid]
			var cells: Array = state["routes"][e["route"]]
			# 挡住它的单位必须还在它正前方那一串单位里（纵深阻挡时中间隔着别的我方单位）
			if u["status"] == "ok":
				for cu in _chain(state, e, cells):
					if cu["uid"] == bid:
						ok = true
		if not ok:
			e["blocked_by"] = ""
	for uid in state["order"]:
		var u2: Dictionary = state["units"][uid]
		if u2["status"] != "ok":
			continue
		var mine := _blocked_by(state, uid)
		var used := 0
		for e in mine:
			used += 2 if "heavy" in e["tags"] else 1
		var cap := _unit_block(state, u2)
		mine.sort_custom(func(x, y): return int(x["uid"]) > int(y["uid"]))
		for e in mine:
			if used <= cap:
				break
			e["blocked_by"] = ""
			used -= 2 if "heavy" in e["tags"] else 1


static func _remove_from_field(state: Dictionary, u: Dictionary) -> void:
	_release_square(state, u)
	for e in _blocked_by(state, u["uid"]):
		e["blocked_by"] = ""
	u["col"] = -1
	u["row"] = -1
	u["aim"] = []


static func _release_square(state: Dictionary, u: Dictionary) -> void:
	if not bool(u["square"]):
		return
	u["square"] = false
	for h in state["hand"]:
		if h["lock"] == u["uid"]:
			h["lock"] = ""


static func _knockback(state: Dictionary, e: Dictionary) -> void:
	if e["route"] == "" or int(e["step"]) <= 0:
		return
	var cells: Array = state["routes"][e["route"]]
	var prev: Array = cells[int(e["step"]) - 1]
	if _unit_at(state, int(prev[0]), int(prev[1]), false) != null:
		return
	e["step"] = int(e["step"]) - 1
	e["col"] = prev[0]
	e["row"] = prev[1]
	e["blocked_by"] = ""
	e.erase("mp")


static func _advance(state: Dictionary, e: Dictionary, cells: Array) -> void:
	e["step"] = int(e["step"]) + 1
	var c: Array = cells[int(e["step"])]
	e["col"] = c[0]
	e["row"] = c[1]
	_order_intrusion(state, int(c[0]), int(c[1]))


static func _hero_guarded(state: Dictionary) -> bool:
	var hero: Dictionary = state["units"][HERO]
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if u["kind"] == "companion" and u["status"] == "ok" and int(u["hp"]) > 0 and _trust(state, HERO, uid) >= 2 \
				and _adjacent(int(u["col"]), int(u["row"]), int(hero["col"]), int(hero["row"])):
			return true
	return false


static func _larrey_on_field(state: Dictionary) -> bool:
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if (u["id"] == "larrey" or "larrey" in u["tags"]) and u["status"] == "ok" and int(u["hp"]) > 0:
			return true
	return false


static func _trust(state: Dictionary, a: String, b: String) -> int:
	var tr: Dictionary = state["trust"]
	for k in ["%s|%s" % [a, b], "%s|%s" % [b, a]]:
		if tr.has(k):
			return int(tr[k])
	if typeof(tr.get(a)) == TYPE_DICTIONARY and (tr[a] as Dictionary).has(b):
		return int(tr[a][b])
	if typeof(tr.get(b)) == TYPE_DICTIONARY and (tr[b] as Dictionary).has(a):
		return int(tr[b][a])
	return 0


# ================================================================ 数值

static func _unit_atk(state: Dictionary, u: Dictionary) -> int:
	var a: int = int(u["atk"])
	var pair_bonus := Pairs.attack(state, u)
	if a <= 0:
		return maxi(0, pair_bonus)
	if int(state["morale"]) >= 12:
		a += 1
	for nb in _neighbors(int(u["col"]), int(u["row"])):
		var v = _unit_at(state, int(nb[0]), int(nb[1]), true)
		if v != null and v["cls"] == "drummer":
			a += 1
			break
	for fl in state["fx"]["flags"]:
		if int(fl["row"]) == int(u["row"]) and int(fl["until"]) >= int(state["turn"]):
			a += 2
			break
	if u["cls"] == "artillery" and _bond_tier(state, "artillery_school") >= 3:
		a += 1
	return a + pair_bonus


static func _ranged_atk(state: Dictionary, u: Dictionary) -> int:
	return _unit_atk(state, u) + (2 if int(u["row"]) in state["fx"]["volley"] else 0)


static func _unit_def(state: Dictionary, u: Dictionary) -> int:
	var d: int = int(u["def"])
	# 地形防 +（村庄 2、房屋 2、瓦砾 1、牢房 1）
	if int(u["col"]) >= 0:
		d += int(_tinfo(_terrain(state, int(u["col"]), int(u["row"])))["def"])
	if bool(u["square"]):
		d += 2
	if u["cls"] == "grenadier" and _bond_tier(state, "square") >= 2 and u["uid"] in _bond_members(state, "square"):
		d += 1
	return maxi(0, d + Pairs.defense(state, u))


static func _unit_block(state: Dictionary, u: Dictionary) -> int:
	if u["status"] != "ok":
		return 0
	var b: int = int(u["block"])
	if bool(u["square"]):
		b += 1
	if u["cls"] == "grenadier" and _bond_tier(state, "square") >= 3 and u["uid"] in _bond_members(state, "square"):
		b += 1
	if u["uid"] in state["fx"]["bayonet"]:
		b -= 1
	return maxi(0, b)


static func _block_used(state: Dictionary, uid: String) -> int:
	var used := 0
	for e in state["enemies"]:
		if e["blocked_by"] == uid:
			used += 2 if "heavy" in e["tags"] else 1
	return used


static func _block_free(state: Dictionary, u: Dictionary) -> int:
	return _unit_block(state, u) - _block_used(state, u["uid"])


static func _enemy_atk(state: Dictionary, e: Dictionary) -> int:
	var a: int = int(e["atk"])
	if a <= 0:
		return 0
	a -= int(e["atk_down"])
	if int(e["weak_until"]) >= int(state["turn"]):
		a -= 2
	if e["type"] != "leader":
		for o in state["enemies"]:
			if o["type"] == "leader" and int(o["column"]) == int(e["column"]) and int(o["hp"]) > 0:
				# rally（皇家海军舰长、普军将领）：同纵队攻 +2，取代纵队长原来的 +1
				a += 2 if "rally" in o["tags"] else 1
				break
	return maxi(0, a)


static func _enemy_def(state: Dictionary, e: Dictionary, ranged: bool) -> int:
	var d: int = int(e["def"])
	var ti := _tinfo(_terrain(state, int(e["col"]), int(e["row"])))
	d += int(ti["def"])
	# 挨远程：树林、洞穴防 +2
	if ranged:
		d += int(ti["rdef"])
	return d


## 敌人打我方：max(1, 攻 − 防)；树林里挨远程按防 +2 算；方阵挨骑兵减半、挨炮击 ×2
static func _dmg_to_unit(state: Dictionary, e: Dictionary, u: Dictionary, kind: String) -> int:
	var a := _enemy_atk(state, e)
	if a <= 0:
		return 0
	# 敌方小火器：顶层射手打层 ≤ 1 的目标攻 +1；雨天攻 −1（伤害仍至少 1）
	if kind == "ranged":
		a = maxi(0, a + _top_bonus(state, e, u) - (1 if _weather(state) == "rain" else 0))
	var d := _unit_def(state, u)
	if kind != "melee" and int(u["col"]) >= 0:
		d += int(_tinfo(_terrain(state, int(u["col"]), int(u["row"])))["rdef"])
	var dmg := maxi(1, a - d)
	if bool(u["square"]):
		if e["type"] == "cavalry":
			dmg = maxi(1, dmg / 2)
		if kind == "gun":
			dmg *= 2
	return dmg


static func _add_charge(u: Dictionary, n: int) -> void:
	var sk: String = u["skill"]
	if not SKILLS.has(sk):
		return
	u["charge"] = mini(int(SKILLS[sk]["charge"]), int(u["charge"]) + n)


static func _is_melee(u: Dictionary) -> bool:
	return u["kind"] != "npc" and u["cls"] in ["line", "grenadier", "hussar", "engineer", "drummer", "hero"]


# ================================================================ 小工具

static func _mk_unit(src: Dictionary, kind: String, uid: String) -> Dictionary:
	var cls := "hero" if kind == "hero" else str(src.get("cls", "line"))
	if kind == "barricade":
		cls = "barricade"
	if not CLASSES.has(cls) or (cls == "hero" and kind != "hero") or (cls == "barricade" and kind != "barricade"):
		cls = "line"
	var base: Dictionary = CLASSES[cls]
	var max_hp: int = maxi(1, int(src.get("max_hp", src.get("hp", base["hp"]))))
	var scarred: bool = bool(src.get("scarred", false))
	var fated: bool = bool(src.get("fated", false))
	if kind == "companion" and (scarred or fated):
		max_hp -= max_hp / 4
	var hp: int = clampi(int(src.get("hp", max_hp)), 1, max_hp)
	var skill := str(src.get("skill", ""))
	if skill == "" or not SKILLS.has(skill):
		skill = str(base["skill"])
	if kind == "hero":
		skill = "pay_chest"
	var tags: Array = []
	for tg in src.get("tags", []):
		tags.append(str(tg))
	var u := {
		"uid": uid, "id": str(src.get("id", uid)), "name": str(src.get("name", base["name"])), "cls": cls, "kind": kind,
		"status": "bar", "col": -1, "row": -1, "facing": "right",
		"hp": hp, "max_hp": max_hp, "atk": maxi(0, int(src.get("atk", base["atk"]))), "def": maxi(0, int(src.get("def", base["def"]))),
		"block": maxi(0, int(src.get("block", base["block"]))), "cost": 0 if kind == "hero" else maxi(0, int(src.get("cost", base["cost"]))),
		"skill": skill, "charge": 0, "tags": tags, "scarred": scarred, "fated": fated,
		"cooldown": 0, "square": false, "aim": [], "reload": 0, "acted": false, "charged": false, "exec_down": false,
		"deployed_turn": -1,
	}
	# 第 from_turn 回合之前不能部署（只在给了的时候写进状态）
	if kind != "hero" and int(src.get("from_turn", 0)) > 1:
		u["from_turn"] = int(src["from_turn"])
	return u


static func _deploy_block_reason(state: Dictionary, u: Dictionary) -> String:
	if not _live(state):
		return "battle_over"
	if u["kind"] in ["barricade", "npc"]:
		return "no_unit"
	if u["status"] != "bar":
		return "not_in_bar"
	if u["uid"] == HERO:
		if not bool(state["hero"]["enabled"]):
			return "hero_disabled"
		if bool(state["hero"]["used"]) or bool(state["hero"]["dispatched"]):
			return "hero_used"
	# 伊夫堡之夜（C28）：伙伴要到第 from_turn 回合才能部署
	if int(u.get("from_turn", 0)) > int(state["turn"]):
		return "not_yet"
	if int(u["cooldown"]) > 0:
		return "cooldown"
	if int(state["cp"]) < int(u["cost"]):
		return "no_cp"
	if _field_count(state, false) >= int(state["field_cap"]):
		return "field_full"
	if u["kind"] == "companion" and _field_count(state, true) >= int(state["companion_cap"]):
		return "companion_full"
	return ""


static func _place_err(state: Dictionary, u: Dictionary, c: int, r: int) -> String:
	if not can_stand(str(u["cls"]), _terrain(state, c, r)):
		return "terrain"
	var v = _unit_at(state, c, r, false)
	if v != null and v["uid"] != u["uid"]:
		return "occupied"
	if not _enemies_at(state, c, r).is_empty():
		return "enemy_here"
	if _reserved(state, c, r):
		return "reserved"
	return ""


## 之后会有敌炮出现的炮位（还没出的 at 波次）：不能部署、不能放拒马
## 伏兵格和跳板（能站人的路线起点）也一样：还没出的那一波从这里出来，出来之前不让部署
static func _reserved(state: Dictionary, c: int, r: int) -> bool:
	for w in state["waves"]:
		if bool(w["spawned"]):
			continue
		if not (w["at"] as Array).is_empty():
			if int(w["at"][0]) == c and int(w["at"][1]) == r:
				return true
		elif w["route"] != "":
			var c0: Array = state["routes"][w["route"]][0]
			if int(c0[0]) == c and int(c0[1]) == r and _tinfo(_terrain(state, c, r))["stand"] != "none":
				return true
	return false


static func _field_count(state: Dictionary, companions_only: bool) -> int:
	var n := 0
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if (u["status"] == "ok" or u["status"] == "dying") and u["kind"] not in ["barricade", "npc"]:
			if not companions_only or u["kind"] == "companion":
				n += 1
	return n


static func _count_cls(state: Dictionary, cls: String) -> int:
	var n := 0
	for uid in state["order"]:
		if state["units"][uid]["status"] == "ok" and state["units"][uid]["cls"] == cls:
			n += 1
	return n


static func _card_feasible(state: Dictionary, cid: String) -> bool:
	match cid:
		"volley":
			return _count_cls(state, "line") + _count_cls(state, "jager") + _count_cls(state, "artillery") > 0
		"bayonet":
			for uid in state["order"]:
				if state["units"][uid]["status"] == "ok" and _is_melee(state["units"][uid]):
					return true
			return false
		"feint":
			for e in state["enemies"]:
				if (e["type"] == "gun" and not (e["aim"] as Array).is_empty()) or (e["type"] != "gun" and e["lock_target"] != ""):
					return true
			return false
		"bugler":
			return not (state["enemies"] as Array).is_empty()
		"barrage":
			return _count_cls(state, "artillery") > 0
		"fallback":
			for uid in state["order"]:
				var fu: Dictionary = state["units"][uid]
				if fu["status"] == "ok" and fu["kind"] != "barricade" and int(fu.get("deployed_turn", -1)) != int(state["turn"]):
					return true
			return false
		"emperor":
			return state["scale"] in BOSS_SCALES
	return true


## 射程图样（按朝向旋转）：横队前方 1–2 格；猎兵同一行前方 1–3 格；炮兵前方第 2–5 格、本行与上下相邻行。
## 新地形（§9.2）：站在顶层（桅盘、屋顶）的横队 / 猎兵 +1 格；站在黑暗格上（牢廊、墓穴，夜战时每一格）远程 −1 格（最少 1）；
## 小火器的直线遇到第一个挡视线的格子（墙、桅杆、洞穴、房屋）截断，那一格本身还打得到；虚空格跳过（不挡视线）。炮是曲射，不看视线
static func _pattern_cells(state: Dictionary, u: Dictionary) -> Array:
	var out: Array = []
	if int(u["col"]) < 0:
		return out
	var f: Array = DIRS[u["facing"]]
	var l: Array = LATERAL[u["facing"]]
	var spec: Array = []
	var uc: int = int(u["col"])
	var ur: int = int(u["row"])
	var small: bool = u["cls"] == "line" or u["cls"] == "jager"
	var dark: int = 1 if _dark(state, uc, ur) else 0
	match u["cls"]:
		"line", "jager":
			var n: int = (2 if u["cls"] == "line" else 3) + (1 if int(_tinfo(_terrain(state, uc, ur))["tier"]) == 3 else 0) - dark
			for k in range(1, maxi(1, n) + 1):
				spec.append([k, 0])
		"artillery":
			for dx in range(2, 6 - dark):
				for dy in [-1, 0, 1]:
					spec.append([dx, dy])
		_: spec = [[1, 0]]
	for s in spec:
		var c: int = uc + int(f[0]) * int(s[0]) + int(l[0]) * int(s[1])
		var r: int = ur + int(f[1]) * int(s[0]) + int(l[1]) * int(s[1])
		if not _in(state, c, r):
			continue
		var tr := _terrain(state, c, r)
		if tr == "void":
			continue
		out.append([c, r])
		if small and bool(_tinfo(tr)["los"]):
			break
	return out


static func _pick_default(state: Dictionary, cands: Array) -> Dictionary:
	var best: Dictionary = {}
	for e in cands:
		if best.is_empty():
			best = e
			continue
		var ka := [_remaining(state, e), int(e["hp"]), int(e["uid"])]
		var kb := [_remaining(state, best), int(best["hp"]), int(best["uid"])]
		if _key_less(ka, kb):
			best = e
	return best


static func _pick_jager_target(state: Dictionary, cands: Array) -> Dictionary:
	var pref: Array = []
	for e in cands:
		if e["type"] == "elite" or e["type"] == "leader" or "officer" in e["tags"]:
			pref.append(e)
	return _pick_default(state, pref if not pref.is_empty() else cands)


static func _lowest_hp(lst: Array) -> Dictionary:
	var best: Dictionary = {}
	for e in lst:
		if best.is_empty() or int(e["hp"]) < int(best["hp"]) or (int(e["hp"]) == int(best["hp"]) and int(e["uid"]) < int(best["uid"])):
			best = e
	return best


static func _remaining(state: Dictionary, e: Dictionary) -> int:
	if e["route"] == "":
		var best := 999
		for r in range(int(state["rows"])):
			for c in range(int(state["cols"])):
				if _terrain(state, c, r) == "eagle":
					best = mini(best, absi(c - int(e["col"])) + absi(r - int(e["row"])))
		return best
	return (state["routes"][e["route"]] as Array).size() - 1 - int(e["step"])


static func _blocked_by(state: Dictionary, uid: String) -> Array:
	var out: Array = []
	for e in state["enemies"]:
		if e["blocked_by"] == uid:
			out.append(e)
	return out


static func _enemies_at(state: Dictionary, c: int, r: int) -> Array:
	var out: Array = []
	for e in state["enemies"]:
		if int(e["col"]) == c and int(e["row"]) == r and int(e["hp"]) > 0:
			out.append(e)
	return out


static func _enemy_by_uid(state: Dictionary, uid: int) -> Dictionary:
	for e in state["enemies"]:
		if int(e["uid"]) == uid:
			return e
	return {}


## 格子上的我方单位；ok_only 时只认状态正常的（濒死伙伴、拒马之外的在场单位）
static func _unit_at(state: Dictionary, c: int, r: int, ok_only: bool):
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if int(u["col"]) == c and int(u["row"]) == r and (u["status"] == "ok" or (not ok_only and u["status"] == "dying")):
			return u
	return null


static func _on_any_route(state: Dictionary, c: int, r: int) -> bool:
	for rid in state["route_ids"]:
		for cell in state["routes"][rid]:
			if int(cell[0]) == c and int(cell[1]) == r:
				return true
	return false


static func _terrain(state: Dictionary, c: int, r: int) -> String:
	if not _in(state, c, r):
		return ""
	return state["terrain"][r * int(state["cols"]) + c]


static func _in(state: Dictionary, c: int, r: int) -> bool:
	return c >= 0 and r >= 0 and c < int(state["cols"]) and r < int(state["rows"])


static func _neighbors(c: int, r: int) -> Array:
	return [[c + 1, r], [c - 1, r], [c, r + 1], [c, r - 1]]


static func _adjacent(c1: int, r1: int, c2: int, r2: int) -> bool:
	return absi(c1 - c2) + absi(r1 - r2) == 1


static func _dist(a: Dictionary, b: Dictionary) -> int:
	return absi(int(a["col"]) - int(b["col"])) + absi(int(a["row"]) - int(b["row"]))


static func _key_less(a: Array, b: Array) -> bool:
	for i in range(mini(a.size(), b.size())):
		if int(a[i]) != int(b[i]):
			return int(a[i]) < int(b[i])
	return false


static func _live(state: Dictionary) -> bool:
	return not state.is_empty() and state.has("units") and state.get("phase", "") == "command"


static func _label(c: int, r: int) -> String:
	if c < 0 or r < 0:
		return "--"
	return "%s%d" % [String.chr(65 + c), r + 1]


static func _label_ok(lbl: String, cols: int, rows: int) -> bool:
	if lbl.length() < 2:
		return false
	var c: int = lbl.unicode_at(0) - 65
	var tail := lbl.substr(1)
	if not tail.is_valid_int():
		return false
	var r: int = tail.to_int() - 1
	return c >= 0 and c < cols and r >= 0 and r < rows


static func _parse_label(lbl: String) -> Array:
	return [lbl.unicode_at(0) - 65, lbl.substr(1).to_int() - 1]


static func _parse_map(mp: Array) -> Array:
	var out: Array = []
	for line in mp:
		for ch in str(line):
			out.append(TERRAIN_CHARS.get(ch, "marsh"))
	return out


static func _terrain_at_turn(base: Array, events: Array, cols: int, _rows: int, turn: int) -> Array:
	var terr: Array = base.duplicate()
	var evs: Array = events.duplicate()
	evs.sort_custom(func(x, y): return int(x.get("turn", 0)) < int(y.get("turn", 0)))
	for ev in evs:
		if not ev.has("on_kill") and int(ev.get("turn", 0)) <= turn:
			var c: Array = _parse_label(str(ev["cell"]))
			terr[int(c[1]) * cols + int(c[0])] = str(ev["terrain"])
	return terr


static func _log(state: Dictionary, line: String) -> void:
	var lg: Array = state["log"]
	lg.append(line)
	if lg.size() > MAX_LOG:
		lg.remove_at(0)


static func _snapshot(state: Dictionary) -> Dictionary:
	var snap := {}
	for k in state.keys():
		if k != "undo":
			snap[k] = state[k].duplicate(true) if typeof(state[k]) in [TYPE_DICTIONARY, TYPE_ARRAY] else state[k]
	return snap


static func _restore(state: Dictionary, snap: Dictionary, stack: Array) -> void:
	state.clear()
	for k in snap.keys():
		state[k] = snap[k]
	state["undo"] = stack


static func _sim_copy(state: Dictionary) -> Dictionary:
	var sim := _snapshot(state)
	sim["undo"] = []
	return sim


## 读档：JSON 往返以后所有整数都变成了浮点（Godot 里 1 in [1.0] 是 false），这里整份转回 int。
## apply / intents / preview / result / view 发现整数字段变成浮点时也会自动做这一步，所以存档直接传回来也行。
static func load_state(data) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "bad_save"}
	var st: Dictionary = _ints(data)
	if not st.has("units") or int(st.get("v", 0)) != 2:
		return {"error": "bad_save"}
	return st


static func _needs_norm(state: Dictionary) -> bool:
	for k in ["v", "turn", "cp", "seed", "rng", "morale", "enemy_morale", "cols"]:
		if state.has(k) and typeof(state[k]) == TYPE_FLOAT:
			return true
	return false


static func _normalize_in_place(state: Dictionary) -> void:
	if not _needs_norm(state):
		return
	var n: Dictionary = _ints(state)
	state.clear()
	state.merge(n)


static func _normalized(state: Dictionary) -> Dictionary:
	return _ints(state) if _needs_norm(state) else state


## JSON 读进来的数字是浮点：整数值一律转回 int（状态里不许有浮点）
static func _ints(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(floor(v))
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(_ints(x))
			return arr
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for k in v.keys():
				out[k] = _ints(v[k])
			return out
	return v


## xorshift32（整数，&0xFFFFFFFF 保持 32 位）
static func _xs(x: int) -> int:
	x = x & 0xFFFFFFFF
	if x == 0:
		x = 0x6D2B79F5
	x = (x ^ (x << 13)) & 0xFFFFFFFF
	x = x ^ (x >> 17)
	x = (x ^ (x << 5)) & 0xFFFFFFFF
	return x


static func _seed_rng(seed_value: int, salt: int) -> int:
	var x: int = ((seed_value & 0xFFFFFFFF) * 2654435761 + salt) & 0xFFFFFFFF
	for i in range(4):
		x = _xs(x)
	return x


## 命悬一线的铜钱：每个人一条独立的整数流（种子 + 名字的 FNV-1a），
## 所以别人多一枚少一枚、谁先倒下都不影响他；自己多加一枚，前面几枚的正反也不变。
static func _coin_faces(seed_value: int, uid: String, n: int) -> Array:
	var x := _seed_rng(seed_value, 0x5BD1E995 ^ _str_hash(uid))
	var faces: Array = []
	for i in range(n):
		x = _xs(x)
		faces.append((x >> 7) & 1)
	return faces


static func _str_hash(text: String) -> int:
	var h := 2166136261
	for i in range(text.length()):
		h = ((h ^ text.unicode_at(i)) * 16777619) & 0xFFFFFFFF
	return h


static func _rand(state: Dictionary, n: int) -> int:
	state["rng"] = _xs(int(state["rng"]))
	return int(state["rng"]) % maxi(1, n)


static func _ok() -> Dictionary:
	return {"ok": true, "err": ""}


static func _fail(err: String) -> Dictionary:
	return {"ok": false, "err": err}


# ================================================================ 第五片：等级、规模、战力（公开接口，§8；给 A 的战役层和 B2 的扫描用）

## 第 a 幕的等级：L = 2a − 1（旧调用只给 act 时就按这个等级打）
static func level_of_act(a: int) -> int:
	return clampi(2 * a - 1, 1, MAX_LEVEL)


## 等级表的一行（§8.1）：{level, hp_pct, morale_pct, atk, def, boss_hunters, boss_elites, elite_hunters, skirmish_hunters,
## boss_turns, elite_turns, skirmish_turns, stars}
static func row(level: int) -> Dictionary:
	var lv: int = clampi(level, 1, MAX_LEVEL)
	var out := {"level": lv}
	for i in range(LEVEL_KEYS.size()):
		out[LEVEL_KEYS[i]] = int(LEVELS[lv - 1][i])
	return out


## 主角兵力（§8.1）：min(hp_max, 12 + (L − 1))；单段书 hp_max 20，napoleon 书 24。在 L = 2a − 1 处等于原来的 12 + 2(a − 1)
static func hero_hp(level: int, hp_max: int = 20) -> int:
	return mini(hp_max, 12 + clampi(level, 1, MAX_LEVEL) - 1)


## 在场 / 伙伴名额 {field, companions}（§8.1）：L ≤ 11 和原来按幕一样，L ≥ 12 按 CAPS_HIGH
static func caps(scale: String, level: int) -> Dictionary:
	var sc: Dictionary = SCALES.get(scale, SCALES["skirmish"])
	var lv: int = clampi(level, 1, MAX_LEVEL)
	if lv <= 11:
		var i: int = (lv + 1) / 2 - 1
		return {"field": int(sc["field"][i]), "companions": int(sc["companions"][i])}
	var out := {"field": 0, "companions": 0}
	for step in CAPS_HIGH.get(scale, CAPS_HIGH["skirmish"]):
		if lv >= int(step[0]):
			out = {"field": int(step[1]), "companions": int(step[2])}
	return out


## 敌方战力（§8.4、ARCH §3.4，纯函数）：Σ 本场所有会出现的敌人 hp(L) × (atk(L) + def(L) + 2·spd + (远程 2)) / 10，
## 炮按 hp × (atk + 4) / 10；每个敌人单独向下取整。只算每一波的主构成（不算 alt），lv_min / act_min 筛过，pad 补的兵也算；
## setup.mods.drop_waves 里的波次不算。tpl 是模板 id 或模板字典
static func power(tpl, level: int, setup: Dictionary = {}) -> int:
	var t: Dictionary = _tpl_dict(tpl)
	if t.is_empty() or typeof(t.get("waves")) != TYPE_ARRAY:
		return 0
	var lv: int = clampi(level, 1, MAX_LEVEL)
	var lr: Array = LEVELS[lv - 1]
	var drop: Array = []
	var mods = _ints(setup).get("mods", {})
	if typeof(mods) == TYPE_DICTIONARY and typeof(mods.get("drop_waves")) == TYPE_ARRAY:
		drop = mods["drop_waves"]
	var total := 0
	var waves: Array = t["waves"]
	for i in range(waves.size()):
		var w = waves[i]
		if i in drop or typeof(w) != TYPE_DICTIONARY:
			continue
		for spec in _wave_specs(t, w, w.get("units", []), lv):
			if not ENEMIES.has(str(spec["kind"])):
				continue
			var b: Dictionary = ENEMIES[str(spec["kind"])]
			var hp: int = maxi(1, int(b["hp"]) * int(lr[0]) / 100)
			var atk: int = int(b["atk"]) + (int(lr[2]) if int(b["atk"]) > 0 else 0)
			var df: int = int(b["def"]) + (int(lr[3]) if int(b["def"]) > 0 else 0)
			if str(b["type"]) == "gun":
				total += hp * (atk + 4) / 10
			else:
				total += hp * (atk + df + 2 * int(b["spd"]) + (2 if int(b["range"]) > 0 else 0)) / 10
	return total


## 推荐战力 = 敌方战力 × 110 / 100（§8.4；系数由 B2 的扫描校准）
static func recommended_power(tpl, level: int, setup: Dictionary = {}) -> int:
	return power(tpl, level, setup) * 110 / 100


## 我方战力（§8.4）：Σ max_hp × (atk + def + block) / 10，每个单位单独向下取整；units 是出征名单的单位字典
## （缺 max_hp 时用 hp，缺的数值按兵种基础值）。主角上阵时把他也放进来
static func party_power(units: Array) -> int:
	var total := 0
	for src in units:
		if typeof(src) != TYPE_DICTIONARY:
			continue
		var u: Dictionary = _ints(src)
		var base: Dictionary = CLASSES.get(str(u.get("cls", "line")), CLASSES["line"])
		var hp: int = int(u.get("max_hp", u.get("hp", base["hp"])))
		total += hp * (int(u.get("atk", base["atk"])) + int(u.get("def", base["def"])) + int(u.get("block", base["block"]))) / 10
	return total


## 模板的等级段目标提醒（§8.1 的猎官 / 精英 / 回合三列，按 lv_min 生效后的主构成计数）。不是错误，校验照样通过；
## 教学战（tutorial）不查。返回提醒文字的数组
static func lint_template(tpl, level: int = 0) -> Array:
	var t: Dictionary = _tpl_dict(tpl)
	if t.is_empty() or bool(t.get("tutorial", false)):
		return []
	var lv: int = level if level > 0 else int(t.get("level", t.get("base_level", 0)))
	if lv < 1:
		return []
	var r := row(lv)
	var scale := str(t.get("scale", ""))
	var kind := "boss" if scale in BOSS_SCALES else ("elite" if scale == "elite" else "skirmish")
	var hunters := 0
	var elites := 0
	for w in t.get("waves", []):
		if typeof(w) != TYPE_DICTIONARY:
			continue
		for spec in _wave_specs(t, w, w.get("units", []), lv):
			var tags := _spec_all_tags(spec, ENEMIES)
			if "hunter" in tags:
				hunters += 1
			if ENEMIES.has(str(spec["kind"])) and str(ENEMIES[str(spec["kind"])]["type"]) == "elite":
				elites += 1
	var out: Array = []
	var want_h: int = int(r["boss_hunters"]) if kind == "boss" else int(r["%s_hunters" % kind])
	if hunters < want_h:
		out.append("L%d %s: %d hunters, target %d" % [lv, kind, hunters, want_h])
	if kind == "boss" and elites < int(r["boss_elites"]):
		out.append("L%d boss: %d elites, target %d" % [lv, elites, int(r["boss_elites"])])
	var want_t: int = int(r["%s_turns" % kind])
	if int(t.get("turn_limit", 0)) < want_t:
		out.append("L%d %s: turn_limit %d, target %d" % [lv, kind, int(t.get("turn_limit", 0)), want_t])
	return out


# ================================================================ 第五片：地形与天时（公开接口，§9）

## 这个兵种能不能站在这种地形上：ground 给 place = ground / any，high 给 place = high / any，
## top（桅盘、屋顶）只给 CLASSES[cls].top 的兵种（猎兵，以及猎兵兵种的伙伴），none 谁都不行
static func can_stand(cls: String, terrain: String) -> bool:
	var st := str(_tinfo(terrain)["stand"])
	var c: Dictionary = CLASSES.get(cls, {})
	var place := str(c.get("place", "ground"))
	match st:
		"ground":
			return place == "ground" or place == "any"
		"high":
			return place == "high" or place == "any"
		"top":
			return bool(c.get("top", false))
	return false


## 敌人走进这一格的步耗；0 = 走不了。enemy 是敌兵种 id 或敌人字典；泥泞天（weather = "mud"）骑兵每格 +1
static func walk_cost(terrain: String, enemy = null, weather: String = "clear") -> int:
	var e: Dictionary = {}
	if typeof(enemy) == TYPE_DICTIONARY:
		e = enemy
	elif typeof(enemy) in [TYPE_STRING, TYPE_STRING_NAME] and ENEMIES.has(str(enemy)):
		e = ENEMIES[str(enemy)]
	return _walk_cost({"weather": weather}, terrain, e)


## 地形规则表的一行（复制一份）加名字：{ch, stand, walk, cost, def, rdef, los, tier, start?, end?, dark?, spawn?, name}
static func terrain_info(terrain: String) -> Dictionary:
	var d: Dictionary = _tinfo(terrain).duplicate(true)
	d["name"] = str(TERRAIN_NAMES.get(terrain, terrain))
	return d


static func weather_name(weather: String) -> String:
	return str(_text().get("weather_names", {}).get(weather, weather))


static func weather_desc(weather: String) -> String:
	return str(_text().get("weather_desc", {}).get(weather, ""))


## 从候选天时里确定地挑一个（候选可以是数组或单个字符串；空的给 clear）。战役层用 seed_for(种子, "weather|<战斗键>") 当 key_seed
static func pick_weather(cands, key_seed: int) -> String:
	var lst: Array = _weather_list(cands)
	if lst.is_empty():
		return "clear"
	return str(lst[_seed_rng(key_seed, 0x57EA7) % lst.size()])


## 敌兵种的定稿数值（L1 基线；复制一份）；不认识的给 {}
static func enemy_def(kind: String) -> Dictionary:
	return (ENEMIES[kind] as Dictionary).duplicate(true) if ENEMIES.has(kind) else {}


# ================================================================ 第五片：内部

static func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	return json.data


static func _text() -> Dictionary:
	if _text_cache.is_empty():
		var d = _read_json(TEXT_PATH)
		_text_cache = d if typeof(d) == TYPE_DICTIONARY else {"version": 0}
	return _text_cache


## 新日志句子（battle_text.json 的 log.<key>，{占位符} 用 args 填）
static func _txt(key: String, args: Dictionary = {}) -> String:
	var s := str(_text().get("log", {}).get(key, key))
	return s.format(args) if not args.is_empty() else s


static func _unknown_name() -> String:
	return str(_text().get("unknown_enemy", "?"))


static func _list_sep() -> String:
	return str(_text().get("list_sep", ", "))


static func _build_scales() -> Dictionary:
	var out: Dictionary = BASE_SCALES.duplicate(true)
	var names: Dictionary = _text().get("scale_names", {})
	for id in EXTRA_SCALES:
		var row: Dictionary = (EXTRA_SCALES[id] as Dictionary).duplicate(true)
		row["name"] = str(names.get(id, id))
		out[id] = row
	return out


static func _build_terrain_names() -> Dictionary:
	var out: Dictionary = BASE_TERRAIN_NAMES.duplicate()
	var names: Dictionary = _text().get("terrain_names", {})
	for id in TERRAIN:
		if not out.has(id):
			out[id] = str(names.get(id, id))
	return out


static func _terrain_list(key: String, value: String) -> Array:
	var out: Array = []
	for id in TERRAIN:
		if str(TERRAIN[id][key]) == value:
			out.append(id)
	return out


static func _enemy_walk_list() -> Array:
	var out: Array = []
	for id in TERRAIN:
		var ti: Dictionary = TERRAIN[id]
		if bool(ti["walk"]) or bool(ti.get("start", false)) or bool(ti.get("end", false)):
			out.append(id)
	return out


## BASE_ENEMIES（7 种，原样）+ battle_enemies.json 里另外的 104 种（读进来整份转成整数）
static func _build_enemies() -> Dictionary:
	var out: Dictionary = {}
	for k in BASE_ENEMIES:
		out[k] = BASE_ENEMIES[k]
	var d = _read_json(ENEMIES_PATH)
	if typeof(d) != TYPE_DICTIONARY or typeof(d.get("enemies")) != TYPE_DICTIONARY:
		return out
	var rows: Dictionary = _ints(d["enemies"])
	for k in rows:
		if out.has(k) or typeof(rows[k]) != TYPE_DICTIONARY:
			continue
		var r: Dictionary = rows[k]
		var tags: Array = []
		for tg in r.get("tags", []):
			tags.append(str(tg))
		r["tags"] = tags
		if r.has("at_terrain"):
			var at: Array = []
			for tr in r["at_terrain"]:
				at.append(str(tr))
			r["at_terrain"] = at
		out[str(k)] = r
	return out


static func _lv(state: Dictionary) -> int:
	return clampi(int(state.get("level", 2 * int(state["act"]) - 1)), 1, MAX_LEVEL)


static func _weather(state: Dictionary) -> String:
	return str(state.get("weather", "clear"))


static func _tinfo(terrain: String) -> Dictionary:
	return TERRAIN.get(terrain, NO_TERRAIN)


static func _dark(state: Dictionary, c: int, r: int) -> bool:
	return _weather(state) == "night" or bool(_tinfo(_terrain(state, c, r)).get("dark", false))


static func _walk_cost(state: Dictionary, terrain: String, e: Dictionary) -> int:
	if terrain == "eagle":
		return 1
	var ti := _tinfo(terrain)
	if not bool(ti["walk"]):
		return 0
	var cost: int = maxi(1, int(ti["cost"]))
	if _weather(state) == "mud" and str(e.get("type", "")) == "cavalry":
		cost += 1
	return cost


## 视线（§9.2）：整数 Bresenham，沿长轴逐格走，正好落在两格中间时取行号（陡线取列号）较小的一侧；
## 两端之间（不含两端）有一格挡视线就不通
static func _los(state: Dictionary, c0: int, r0: int, c1: int, r1: int) -> bool:
	var dc: int = absi(c1 - c0)
	var dr: int = absi(r1 - r0)
	var sc: int = 1 if c1 > c0 else -1
	var sr: int = 1 if r1 > r0 else -1
	if dc >= dr:
		for i in range(1, dc):
			var c: int = c0 + sc * i
			var num: int = dr * i
			var q: int = num / dc
			var rem: int = num % dc
			var r: int = r0 + sr * q
			if 2 * rem > dc:
				r = r0 + sr * (q + 1)
			elif 2 * rem == dc:
				r = mini(r0 + sr * q, r0 + sr * (q + 1))
			if bool(_tinfo(_terrain(state, c, r))["los"]):
				return false
	else:
		for i in range(1, dr):
			var r2: int = r0 + sr * i
			var num2: int = dc * i
			var q2: int = num2 / dr
			var rem2: int = num2 % dr
			var c2: int = c0 + sc * q2
			if 2 * rem2 > dr:
				c2 = c0 + sc * (q2 + 1)
			elif 2 * rem2 == dr:
				c2 = mini(c0 + sc * q2, c0 + sc * (q2 + 1))
			if bool(_tinfo(_terrain(state, c2, r2))["los"]):
				return false
	return true


static func _los_to(state: Dictionary, e: Dictionary, u: Dictionary) -> bool:
	return _los(state, int(e["col"]), int(e["row"]), int(u["col"]), int(u["row"]))


## 敌方小火器的射程：站在顶层 +1，黑暗（牢廊、墓穴、夜战）−1，最少 1
static func _erange(state: Dictionary, e: Dictionary) -> int:
	var rng: int = int(e["range"])
	if rng <= 0 or e["type"] == "gun":
		return rng
	var c: int = int(e["col"])
	var r: int = int(e["row"])
	if int(_tinfo(_terrain(state, c, r))["tier"]) == 3:
		rng += 1
	if _dark(state, c, r):
		rng -= 1
	return maxi(1, rng)


## 顶层射手（层 3）打层 ≤ 1 的目标：攻 +1
static func _top_bonus(state: Dictionary, shooter: Dictionary, target: Dictionary) -> int:
	if int(shooter["col"]) < 0 or int(target["col"]) < 0:
		return 0
	var ts: int = int(_tinfo(_terrain(state, int(shooter["col"]), int(shooter["row"])))["tier"])
	var tt: int = int(_tinfo(_terrain(state, int(target["col"]), int(target["row"])))["tier"])
	return 1 if ts == 3 and tt <= 1 else 0


## 敌炮能不能把准星放在这个单位身上：洞里的不瞄；short 只瞄列差 ≤ 4
static func _gun_can_aim(state: Dictionary, e: Dictionary, u: Dictionary) -> bool:
	if _terrain(state, int(u["col"]), int(u["row"])) == "cave":
		return false
	if "short" in e["tags"] and absi(int(u["col"]) - int(e["col"])) > 4:
		return false
	return true


## stealth：离我方所有在场单位（拒马不算）都超过 2 格
static func _hidden(state: Dictionary, e: Dictionary) -> bool:
	if not "stealth" in e["tags"]:
		return false
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if (u["status"] == "ok" or u["status"] == "dying") and u["kind"] != "barricade" and _dist(e, u) <= 2:
			return false
	return true


static func _ename(state: Dictionary, e: Dictionary) -> String:
	return _unknown_name() if _hidden(state, e) else str(e["name"])


## 预演里看不清的敌人（stealth）：只给伤害数和死活，不给兵力；e 是结算后的敌人（死了是 {}）
static func _hidden_after(e: Dictionary, hp_before: int) -> Dictionary:
	if e.is_empty():
		return {"alive": false, "hidden": true, "dmg": hp_before}
	return {"alive": true, "hidden": true, "dmg": maxi(0, hp_before - int(e["hp"])), "col": e["col"], "row": e["row"]}


## 来敌一行（敌情、波次条用）：{kind, name, tags}；还没出场的隐身敌人兵种、名字、标签都隐去
static func _spec_row(spec: Dictionary) -> Dictionary:
	var tags := _spec_tags(spec)
	if "stealth" in tags:
		return {"kind": "unknown", "name": _unknown_name(), "tags": []}
	return {"kind": spec["kind"], "name": ENEMIES[spec["kind"]]["name"], "tags": tags}


## 一个兵的全部标签（兵种自带 + 模板给的）；spec 是字符串或 {kind, tags}
static func _spec_all_tags(spec, roster: Dictionary) -> Array:
	var kind := str(spec.get("kind", "")) if typeof(spec) == TYPE_DICTIONARY else str(spec)
	var out: Array = []
	if roster.has(kind):
		for tg in roster[kind].get("tags", []):
			out.append(str(tg))
	if typeof(spec) == TYPE_DICTIONARY and typeof(spec.get("tags")) == TYPE_ARRAY:
		for tg in spec["tags"]:
			if not str(tg) in out:
				out.append(str(tg))
	return out


## 一波在等级 L 下真正出场的兵：[{kind, tags}]。波次和单兵都按 lv_min（以及旧的 act_min = a → lv_min = 2a−1）筛；
## 模板写了 base_level 和 pad 时，每一波走路线的兵补 max(0, (L − b) / every) 个 pad.kind。整波被筛空时返回 []
static func _wave_specs(t: Dictionary, w: Dictionary, pick: Array, lv: int) -> Array:
	if lv < int(w.get("lv_min", 1)) or lv < 2 * int(w.get("act_min", 1)) - 1:
		return []
	var units: Array = []
	for spec in pick:
		var kind := ""
		var tags: Array = []
		var need := 1
		if typeof(spec) == TYPE_DICTIONARY:
			kind = str(spec.get("kind", ""))
			tags = (spec.get("tags", []) as Array).duplicate()
			need = maxi(int(spec.get("lv_min", 1)), 2 * int(spec.get("act_min", 1)) - 1)
		else:
			kind = str(spec)
		if lv < need:
			continue
		units.append({"kind": kind, "tags": tags})
	if units.is_empty():
		return units
	var pad = t.get("pad")
	if w.has("route") and t.has("base_level") and typeof(pad) == TYPE_DICTIONARY and int(pad.get("every", 0)) > 0:
		var n: int = maxi(0, (lv - int(t["base_level"])) / int(pad["every"]))
		for i in range(n):
			units.append({"kind": str(pad["kind"]), "tags": []})
	return units


## setup 新键的形状：level、weather、mods、roster[].from_turn
static func _setup_errors(su: Dictionary) -> Array:
	var errs: Array = Pairs.validate_setup(su)
	if su.has("volume") and (typeof(su["volume"]) != TYPE_INT or int(su["volume"]) < 1):
		errs.append("volume must be a positive integer")
	if su.has("level") and typeof(su["level"]) != TYPE_INT:
		errs.append("level must be an integer")
	if su.has("weather") and (typeof(su["weather"]) != TYPE_STRING or not str(su["weather"]) in WEATHERS):
		errs.append("weather must be one of %s" % ", ".join(PackedStringArray(WEATHERS)))
	if su.has("mods"):
		var m = su["mods"]
		if typeof(m) != TYPE_DICTIONARY:
			errs.append("mods must be a dictionary")
		else:
			for k in m:
				if MOD_RANGES.has(k):
					if typeof(m[k]) != TYPE_INT or int(m[k]) < int(MOD_RANGES[k][0]) or int(m[k]) > int(MOD_RANGES[k][1]):
						errs.append("mods.%s must be %d..%d" % [k, int(MOD_RANGES[k][0]), int(MOD_RANGES[k][1])])
				elif k == "drop_waves":
					if typeof(m[k]) != TYPE_ARRAY:
						errs.append("mods.drop_waves must be a list of wave indexes")
					else:
						for i in m[k]:
							if typeof(i) != TYPE_INT:
								errs.append("mods.drop_waves must be a list of wave indexes")
				elif k == "terrain":
					if typeof(m[k]) != TYPE_ARRAY:
						errs.append("mods.terrain must be a list of {cell, terrain}")
					else:
						for row in m[k]:
							if typeof(row) != TYPE_DICTIONARY or not TERRAIN.has(str(row.get("terrain", ""))) or str(row.get("cell", "")).length() < 2:
								errs.append("mods.terrain: bad entry %s" % str(row))
				else:
					errs.append("unknown mods key %s" % k)
	for src in su.get("roster", []) if typeof(su.get("roster")) == TYPE_ARRAY else []:
		if typeof(src) == TYPE_DICTIONARY and src.has("from_turn") and typeof(src["from_turn"]) != TYPE_INT:
			errs.append("roster from_turn must be an integer")
	return errs


static func _setup_weather(su: Dictionary, tpl: Dictionary) -> String:
	if su.has("weather"):
		return str(su["weather"])
	var lst: Array = _weather_list(tpl.get("weather", []))
	return str(lst[0]) if not lst.is_empty() and str(lst[0]) in WEATHERS else "clear"


static func _weather_list(v) -> Array:
	if typeof(v) in [TYPE_STRING, TYPE_STRING_NAME]:
		return [str(v)] if str(v) != "" else []
	if typeof(v) == TYPE_ARRAY:
		var out: Array = []
		for x in v:
			out.append(str(x))
		return out
	return []


## mods（§6.6）作用在模板副本上，之后照常校验：terrain 改格子；drop_waves 去掉这些下标的波次；
## prep_turn = 1 是多一个准备回合（所有波次、炮的第一炮、地形事件、坚守目标的回合都晚 1，回合上限 +1）。cp_bonus、enemy_morale 在开场时算
static func _apply_mods(tpl: Dictionary, mods: Dictionary) -> Dictionary:
	var t: Dictionary = tpl.duplicate(true)
	if typeof(mods.get("terrain")) == TYPE_ARRAY and typeof(t.get("map")) == TYPE_ARRAY:
		var mp: Array = t["map"]
		for row in mods["terrain"]:
			var lbl := str(row["cell"])
			var c: int = lbl.unicode_at(0) - 65
			var r: int = lbl.substr(1).to_int() - 1
			if r >= 0 and r < mp.size() and c >= 0 and c < str(mp[r]).length():
				var line := str(mp[r])
				mp[r] = line.substr(0, c) + str(TERRAIN[str(row["terrain"])]["ch"]) + line.substr(c + 1)
	if typeof(mods.get("drop_waves")) == TYPE_ARRAY and typeof(t.get("waves")) == TYPE_ARRAY:
		var kept: Array = []
		for i in range((t["waves"] as Array).size()):
			if not i in mods["drop_waves"]:
				kept.append(t["waves"][i])
		t["waves"] = kept
	if int(mods.get("prep_turn", 0)) == 1:
		t["turn_limit"] = mini(20, int(t.get("turn_limit", 0)) + 1)
		for w in t.get("waves", []):
			if typeof(w) == TYPE_DICTIONARY:
				w["turn"] = int(w.get("turn", 0)) + 1
				if w.has("first_fire"):
					w["first_fire"] = int(w["first_fire"]) + 1
		for ev in t.get("events", []):
			if typeof(ev) == TYPE_DICTIONARY and ev.has("turn"):
				ev["turn"] = int(ev["turn"]) + 1
		if typeof(t.get("order")) == TYPE_DICTIONARY and t["order"].has("turn"):
			t["order"]["turn"] = int(t["order"]["turn"]) + 1
		for rid in t.get("routes", {}):
			if typeof(t["routes"][rid]) == TYPE_DICTIONARY and t["routes"][rid].has("until"):
				t["routes"][rid]["until"] = int(t["routes"][rid]["until"]) + 1
		if typeof(t.get("route_until")) == TYPE_DICTIONARY:
			for rid in t["route_until"]:
				t["route_until"][rid] = int(t["route_until"][rid]) + 1
	return t


## 模板的格子尺寸 [cols, rows]：写了 size 就用 size（5×3 到 12×7），没写用 scale 的默认；不合法给 []
static func _tpl_size(t: Dictionary) -> Array:
	var sc: Dictionary = SCALES.get(str(t.get("scale", "")), {})
	if not t.has("size"):
		return [int(sc["cols"]), int(sc["rows"])] if not sc.is_empty() else []
	var s = t["size"]
	if typeof(s) != TYPE_ARRAY or (s as Array).size() != 2:
		return []
	for v in s:
		if not typeof(v) in [TYPE_INT, TYPE_FLOAT] or float(v) != float(int(v)):
			return []
	var c: int = int(s[0])
	var r: int = int(s[1])
	if c < 5 or c > 12 or r < 3 or r > 7:
		return []
	return [c, r]


## 路线的格子标签：数组，或者 {cells: [...], until: 回合}
static func _route_labels(r) -> Array:
	if typeof(r) == TYPE_ARRAY:
		return r
	if typeof(r) == TYPE_DICTIONARY and typeof(r.get("cells")) == TYPE_ARRAY:
		return r["cells"]
	return []


## 路线时效 until（写在路线 {cells, until} 里，或者模板的 route_until {路线: 回合}）；没写给 −1
static func _route_until(t: Dictionary, rid: String) -> int:
	var r = t.get("routes", {}).get(rid)
	if typeof(r) == TYPE_DICTIONARY and r.has("until"):
		return int(r["until"])
	if typeof(t.get("route_until")) == TYPE_DICTIONARY and t["route_until"].has(rid):
		return int(t["route_until"][rid])
	return -1


static func _tpl_dict(tpl) -> Dictionary:
	if typeof(tpl) == TYPE_DICTIONARY:
		return _ints(tpl)
	var tpls: Dictionary = load_templates().get("templates", {})
	return tpls.get(str(tpl), {})


## 地形事件：改格子并写日志（line 为 "" 时用旧句子「X 变成了Y。」），然后处理格子上的单位（§9.2）
static func _set_terrain(state: Dictionary, c: int, r: int, terrain: String, line: String) -> void:
	state["terrain"][r * int(state["cols"]) + c] = terrain
	if line == "":
		_log(state, "%s 变成了%s。" % [_label(c, r), TERRAIN_NAMES.get(terrain, terrain)])
	else:
		_log(state, line)
	_displace(state, c, r)


## 格子变了以后脚下站不住的：我方单位退回部署栏（冷却 2 回合，不算倒下，不退军令点），拒马直接没了，濒死的伙伴抬下；
## 敌人脚下走不了了（落水、坠落）直接移除，按击杀扣敌军心。旧模板的事件只会把河变成浅滩，碰不到这些
static func _displace(state: Dictionary, c: int, r: int) -> void:
	var tr := _terrain(state, c, r)
	var tname := str(TERRAIN_NAMES.get(tr, tr))
	var changed := false
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if int(u["col"]) != c or int(u["row"]) != r or not (u["status"] == "ok" or u["status"] == "dying"):
			continue
		if can_stand(str(u["cls"]), tr):
			continue
		changed = true
		if u["status"] == "dying":
			_carry_off(state, u)
			_log(state, _txt("carried_off", {"cell": _label(c, r), "terrain": tname, "name": u["name"]}))
		elif u["kind"] == "barricade":
			_remove_from_field(state, u)
			u["status"] = "routed"
			_log(state, _txt("barricade_lost", {"cell": _label(c, r), "terrain": tname}))
		else:
			_remove_from_field(state, u)
			u["status"] = "bar"
			u["cooldown"] = 2
			_log(state, _txt("pushed_off", {"cell": _label(c, r), "terrain": tname, "name": u["name"], "n": 2}))
	if changed:
		_refresh_bonds(state)
	for e in (state["enemies"] as Array).duplicate():
		if int(e["col"]) != c or int(e["row"]) != r:
			continue
		var ok := false
		if e["route"] == "":
			var allowed: Array = ENEMIES[e["kind"]].get("at_terrain", ["high", "plain"]) if ENEMIES.has(e["kind"]) else ["high", "plain"]
			if "boat" in e["tags"]:
				allowed = ["sea"]
			elif "top" in e["tags"]:
				allowed = TOP
			ok = tr in allowed
		else:
			var ti := _tinfo(tr)
			ok = bool(ti["walk"]) or bool(ti.get("start", false)) or bool(ti.get("end", false))
		if not ok:
			_kill(state, e, "drowned" if int(_tinfo(tr)["tier"]) == 0 else "fell")


## e 步：打死了那种敌人的击杀事件，这时才改地形（每条只触发一次）
static func _on_kill_events(state: Dictionary) -> void:
	for ev in state["events"]:
		if not ev.has("on_kill") or bool(ev["done"]) or not bool(ev["armed"]):
			continue
		ev["done"] = true
		var who: String = str(ENEMIES[str(ev["on_kill"])]["name"]) if ENEMIES.has(str(ev["on_kill"])) else str(ev["on_kill"])
		var tr := str(ev["terrain"])
		_set_terrain(state, int(ev["col"]), int(ev["row"]), tr,
			_txt("on_kill", {"who": who, "cell": _label(int(ev["col"]), int(ev["row"])), "terrain": TERRAIN_NAMES.get(tr, tr)}))
	_sweep(state)


## 酷热（desert）：第 3、6、9……回合的 e 步，我方在场单位 1 格内（含本格）没有水井的兵力 −1，最低留 1
static func _thirst(state: Dictionary, t: int) -> void:
	if _weather(state) != "desert" or t % 3 != 0:
		return
	var names: Array = []
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if u["status"] != "ok" or u["kind"] == "barricade":
			continue
		var wet := _terrain(state, int(u["col"]), int(u["row"])) == "well"
		for nb in _neighbors(int(u["col"]), int(u["row"])):
			if _terrain(state, int(nb[0]), int(nb[1])) == "well":
				wet = true
		if not wet and int(u["hp"]) > 1:
			u["hp"] = int(u["hp"]) - 1
			names.append(u["name"])
	if not names.is_empty():
		_log(state, _txt("thirst", {"names": _list_sep().join(PackedStringArray(names))}))


## 风暴（storm）：每回合 e 步结束时，桅盘上的我方单位兵力 −1，最低留 1
static func _storm(state: Dictionary) -> void:
	if _weather(state) != "storm":
		return
	var names: Array = []
	for uid in state["order"]:
		var u: Dictionary = state["units"][uid]
		if u["status"] == "ok" and _terrain(state, int(u["col"]), int(u["row"])) == "rigging" and int(u["hp"]) > 1:
			u["hp"] = int(u["hp"]) - 1
			names.append(u["name"])
	if not names.is_empty():
		_log(state, _txt("storm", {"names": _list_sep().join(PackedStringArray(names))}))


## V1 retains the original fallback and byte-identical state; V2 opts in explicitly.
static func selected_order(tpl: Dictionary, volume: int = 1) -> Dictionary:
	var selected = tpl.get("order_next", tpl.get("order", {})) if volume >= 2 else tpl.get("order", {})
	return selected.duplicate(true) if typeof(selected) == TYPE_DICTIONARY else {}


static func _order_cell_error(label: String, cols: int, rows: int, terrain: Array) -> String:
	if not _label_ok(label, cols, rows):
		return "bad cell " + label
	var at := _parse_label(label)
	if str(_tinfo(str(terrain[int(at[1]) * cols + int(at[0])]))["stand"]) == "none":
		return "unoccupiable cell " + label
	return ""


static func _validate_order(od, cols: int, rows: int, terrain: Array, limit: int, context: String) -> Array:
	var errors: Array = []
	if typeof(od) != TYPE_DICTIONARY:
		return [context + ": must be a dictionary"]
	if od.is_empty():
		return errors
	var kind := str(od.get("type", ""))
	if kind not in ["hold", "no_leak", "escape", "extract", "protect"]:
		return [context + ": unknown type " + kind]
	var labels: Array = []
	if kind in ["hold", "extract"]:
		labels.append(str(od.get("cell", "")))
	if kind in ["hold", "escape"]:
		if typeof(od.get("turn")) not in [TYPE_INT, TYPE_FLOAT] or int(od.get("turn", 0)) < 1 or int(od.get("turn", 0)) > limit:
			errors.append(context + ": turn out of range")
	if kind == "escape":
		if typeof(od.get("unit")) != TYPE_STRING or str(od.get("unit", "")) == "":
			errors.append(context + ": missing unit")
		if typeof(od.get("cells")) != TYPE_ARRAY or od.get("cells", []).is_empty():
			errors.append(context + ": escape needs exit cells")
		else:
			labels.append_array(od["cells"])
		if od.has("start_cell"):
			labels.append(od["start_cell"])
	if kind == "extract":
		if typeof(od.get("turns")) not in [TYPE_INT, TYPE_FLOAT] or int(od.get("turns", 0)) < 1 or int(od.get("turns", 0)) > limit:
			errors.append(context + ": extraction turns out of range")
		if od.has("then"):
			errors.append(context + ": use an explicit escape NPC/path instead of then")
		for key in ["gold_after", "gold_each"]:
			if od.has(key) and (typeof(od[key]) not in [TYPE_INT, TYPE_FLOAT] or int(od[key]) < 1 or int(od[key]) > limit):
				errors.append(context + ": invalid " + key)
		if od.has("escape"):
			var escape = od["escape"]
			if typeof(escape) != TYPE_DICTIONARY or typeof(escape.get("npc")) != TYPE_DICTIONARY or typeof(escape.get("path")) != TYPE_ARRAY:
				errors.append(context + ": extraction escape requires npc and path")
			else:
				errors.append_array(_validate_order({"type": "protect", "npc": escape["npc"]}, cols, rows, terrain, limit, context + ".escape"))
				var path: Array = escape["path"]
				if path.size() < 2 or path.size() > limit or str(path[0]) != str(escape["npc"].get("cell", "")):
					errors.append(context + ": invalid escort path origin/length")
				labels.append_array(path)
				for index in range(1, path.size()):
					if not _label_ok(str(path[index - 1]), cols, rows) or not _label_ok(str(path[index]), cols, rows):
						continue
					var a := _parse_label(str(path[index - 1]))
					var b := _parse_label(str(path[index]))
					if a.size() != 2 or b.size() != 2 or not _adjacent(int(a[0]), int(a[1]), int(b[0]), int(b[1])):
						errors.append(context + ": escort path must use adjacent cells")
				if str(escape["npc"].get("cell", "")) == str(od.get("cell", "")):
					errors.append(context + ": escort spawn must leave the searcher's cell free")
	if kind == "protect":
		if od.has("npc") == od.has("unit"):
			errors.append(context + ": protect requires exactly one unit or npc")
		elif od.has("unit") and (typeof(od["unit"]) != TYPE_STRING or str(od["unit"]) == ""):
			errors.append(context + ": invalid protected unit")
		elif od.has("npc"):
			var npc = od["npc"]
			if typeof(npc) != TYPE_DICTIONARY:
				errors.append(context + ": npc must be a dictionary")
			else:
				for key in ["id", "name", "cell"]:
					if typeof(npc.get(key)) != TYPE_STRING or str(npc.get(key, "")) == "":
						errors.append(context + ": npc requires " + key)
				if str(npc.get("id", "")) == HERO:
					errors.append(context + ": npc cannot replace the hero")
				if typeof(npc.get("hp")) not in [TYPE_INT, TYPE_FLOAT] or int(npc.get("hp", 0)) < 1:
					errors.append(context + ": npc hp must be positive")
				labels.append(npc.get("cell", ""))
	for label in labels:
		var error := _order_cell_error(str(label), cols, rows, terrain)
		if error != "":
			errors.append(context + ": " + error)
	return errors


static func _mobile_order_unit(state: Dictionary, unit: Dictionary) -> bool:
	var goal: Dictionary = state.get("order_goal", {})
	return str(goal.get("type", "")) == "escape" and str(goal.get("unit", "")) == str(unit.get("uid", "")) and str(unit.get("kind", "")) in ["companion", "hero"]


static func _order_move_cells(state: Dictionary, unit: Dictionary) -> Array:
	var cells: Array = []
	if not _live(state) or not _mobile_order_unit(state, unit) or unit["status"] != "ok" or int(state["cp"]) < 1 or int(unit.get("moved_turn", -1)) == int(state["turn"]):
		return cells
	if not _blocked_by(state, str(unit["uid"])).is_empty():
		return cells
	for at in _neighbors(int(unit["col"]), int(unit["row"])):
		if _in(state, int(at[0]), int(at[1])) and _place_err(state, unit, int(at[0]), int(at[1])) == "":
			cells.append(at)
	return cells


static func _cmd_move(state: Dictionary, args: Dictionary) -> Dictionary:
	if args.size() != 3 or not args.has("unit") or not args.has("col") or not args.has("row"):
		return _fail("bad_args")
	var unit: Dictionary = state["units"].get(str(args["unit"]), {})
	if unit.is_empty() or not _mobile_order_unit(state, unit):
		return _fail("no_unit")
	if unit["status"] != "ok":
		return _fail("not_on_field")
	if int(state["cp"]) < 1:
		return _fail("no_cp")
	if not [args["col"], args["row"]] in _order_move_cells(state, unit):
		return _fail("bad_cell")
	_release_square(state, unit)
	unit["col"] = int(args["col"])
	unit["row"] = int(args["row"])
	unit["moved_turn"] = int(state["turn"])
	unit["aim"] = []
	state["cp"] = int(state["cp"]) - 1
	_refresh_bonds(state)
	_log(state, _txt("order_move", {"name": unit["name"], "cell": _label(int(unit["col"]), int(unit["row"]))}))
	return _ok()


static func _spawn_order_npc(state: Dictionary, spec: Dictionary) -> bool:
	var id := str(spec["id"])
	var cell := _parse_label(str(spec["cell"]))
	if state["units"].has(id):
		return false
	if _unit_at(state, int(cell[0]), int(cell[1]), false) != null or not _enemies_at(state, int(cell[0]), int(cell[1])).is_empty():
		return false
	var npc := _mk_unit({"id": id, "name": spec["name"], "hp": spec["hp"], "atk": 0, "def": 0, "block": 0, "cost": 0}, "npc", id)
	npc["skill"] = ""
	npc["status"] = "ok"
	npc["col"] = int(cell[0])
	npc["row"] = int(cell[1])
	state["units"][id] = npc
	state["order"].append(id)
	state["order_progress"]["npc"] = id
	state["order_progress"]["path_step"] = 0
	return true


static func _order_intrusion(state: Dictionary, col: int, row: int) -> void:
	var progress: Dictionary = state.get("order_progress", {})
	var id := str(progress.get("npc", ""))
	if id == "" or not state["units"].has(id):
		return
	var npc: Dictionary = state["units"][id]
	if npc["status"] == "ok" and int(npc["col"]) == col and int(npc["row"]) == row:
		npc["hp"] = 0
		progress["failed"] = true


## Counts only completed firefights. Command previews and repeated queries are read-only.
static func _tick_order(state: Dictionary) -> void:
	if not state.has("order_progress"):
		return
	var progress: Dictionary = state["order_progress"]
	var turn := int(state["turn"])
	if int(progress["last_tick"]) == turn:
		return
	progress["last_tick"] = turn
	var goal: Dictionary = state["order_goal"]
	if bool(progress["failed"]) or bool(progress["escaped"]):
		return
	var npc: Dictionary = state["units"].get(str(progress.get("npc", "")), {})
	if not npc.is_empty() and (npc["status"] != "ok" or int(npc["hp"]) <= 0):
		progress["failed"] = true
		return
	if str(goal["type"]) == "escape":
		if turn == int(goal["turn"]):
			progress["escaped"] = _at_order_exit(state, goal)
			if bool(progress["escaped"]):
				var escaped: Dictionary = state["units"][str(goal["unit"])]
				_remove_from_field(state, escaped)
				escaped["status"] = "escaped"
				_refresh_bonds(state)
			else:
				progress["failed"] = true
		return
	if str(goal["type"]) == "protect" and goal.has("unit"):
		var protected: Dictionary = state["units"].get(str(goal["unit"]), {})
		if not protected.is_empty() and protected["status"] in ["dying", "down", "carried", "routed"]:
			progress["failed"] = true
		return
	if str(goal["type"]) != "extract":
		return
	var at := _parse_label(str(goal["cell"]))
	var unit: Variant = _unit_at(state, int(at[0]), int(at[1]), true)
	if unit != null and unit["kind"] not in ["barricade", "npc"] and int(unit["hp"]) > 0:
		progress["count"] = int(progress["count"]) + 1
		if goal.has("gold_after") and int(progress["count"]) >= int(goal["gold_after"]):
			progress["gold"] = int(progress["gold"]) + int(goal.get("gold_each", 1))
	if not goal.has("escape") or int(progress["count"]) < int(goal["turns"]):
		return
	var escape: Dictionary = goal["escape"]
	if npc.is_empty():
		_spawn_order_npc(state, escape["npc"])
		return
	var path: Array = escape["path"]
	var step := int(progress["path_step"])
	if step + 1 >= path.size():
		progress["escaped"] = true
		return
	var next := _parse_label(str(path[step + 1]))
	if _place_err(state, npc, int(next[0]), int(next[1])) != "":
		return
	npc["col"] = int(next[0])
	npc["row"] = int(next[1])
	progress["path_step"] = step + 1
	progress["escaped"] = step + 1 == path.size() - 1
	if bool(progress["escaped"]):
		_remove_from_field(state, npc)
		npc["status"] = "escaped"


static func _at_order_exit(state: Dictionary, goal: Dictionary) -> bool:
	var unit: Dictionary = state["units"].get(str(goal.get("unit", "")), {})
	return not unit.is_empty() and unit["status"] == "ok" and int(unit["hp"]) > 0 and _label(int(unit["col"]), int(unit["row"])) in goal.get("cells", [])


static func _new_order_done(state: Dictionary, victory_kind: String) -> bool:
	var progress: Dictionary = state.get("order_progress", {})
	if progress.is_empty() or bool(progress.get("failed", false)):
		return false
	var goal: Dictionary = state["order_goal"]
	match str(goal["type"]):
		"escape":
			return bool(progress["escaped"]) or (int(state["turn"]) < int(goal["turn"]) and victory_kind != "hold" and _at_order_exit(state, goal))
		"extract":
			return int(progress["count"]) >= int(goal["turns"]) and (not goal.has("escape") or bool(progress["escaped"]))
		"protect":
			var id := str(goal.get("unit", goal.get("npc", {}).get("id", "")))
			var unit: Dictionary = state["units"].get(id, {})
			if unit.is_empty() or int(unit["hp"]) <= 0 or unit["status"] in ["dying", "down", "carried", "routed"]:
				return false
			if not goal.has("npc") and not id in state["deployed_ever"]:
				return false
			for fallen in state["fallen"]:
				if fallen["unit"] == id:
					return false
			return true
	return false


static func order_view(state: Dictionary) -> Dictionary:
	var goal: Dictionary = state["order_goal"].duplicate(true)
	if state.has("order_progress"):
		goal["progress"] = state["order_progress"].duplicate(true)
	return goal
