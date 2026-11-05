# 拿破仑篇高清美术的找图器（剧情 VN 与明日方舟式战场共用）。没有 class_name，用的地方：
#   const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
# 清单是 data/hd/art_list.json（kinds 定路径和尺寸，assets 是每一项），只读一次。图放在 res://art/hd/ 下，
# 路径规则见 docs/cards/art/hd/HD_ART_RULES.md 第 3 节。规矩：有真图就用真图，没有就返回 null / []，
# 由 hd_placeholder.gd 画占位；找不到图不报错（先 ResourceLoader.exists 再 load），找到和找不到都缓存。
# 说明：docs/cards/HD_UI.md。
extends RefCounted

const LIST_PATH := "res://data/hd/art_list.json"
const ROOT := "res://art/hd/"
const DEFAULT_FPS := 12
const MAX_FRAMES := 64
const HIT_CAP := 96   # 缓存里最多留这么多张图（最近用过的在后）；单位帧另存在 _frames 里
const ACCENT_COUNT := 12   # 配色键 hd_accent_0 .. hd_accent_11
# 清单里没写 kinds 时的后备路径（和清单一致）
const FALLBACK_PATHS := {
	"bg": "art/hd/bg/{id}.jpg", "cg": "art/hd/cg/{id}.jpg", "chara": "art/hd/chara/{id}/{expr}.png",
	"face": "art/hd/face/{id}.png", "unit": "art/hd/unit/{id}/{state}_{nn}.png",
	"tex": "art/hd/tile/{id}.png", "side": "art/hd/tile/{id}.png", "prop": "art/hd/prop/{id}.glb",
}
const FALLBACK_ALT := {"bg": ["png"], "cg": ["png"]}
const FALLBACK_ANCHOR := Vector2(192, 336)
# New terrain reuses registered tile placeholders until its own art is listed.
# A dedicated art-list mapping always takes precedence; void has no surface.
const TERRAIN_FALLBACK := {
	"wall": "rock", "rubble": "rock", "snow": "rock", "ice": "ford", "mud": "marsh",
	"sand": "earthwork_top", "dune": "earthwork_top", "well": "village_ground",
	"deck": "earthwork_top", "quarterdeck": "earthwork_top", "rigging": "earthwork_top", "mast": "earthwork_top",
	"sea": "water", "shallows": "ford", "reef": "rock", "beach": "earthwork_top", "cave": "rock",
	"dock": "earthwork_top", "plank": "earthwork_top", "hatch": "earthwork_top", "street": "road",
	"building": "village_ground", "rooftop": "village_ground", "corridor": "road", "cell": "road",
	"door": "road", "catacomb": "rock",
}
# 这几类图游戏里会缩得很小（头像、小人、地块），导入时没生成 mipmap 的话这里补上，缩小了不闪不糊。
const MIPMAP_KINDS := ["chara", "face", "unit", "tex", "side"]
# 主要人物固定一种强调色（下标指 hd_accent_N），其余按 id 散列；敌人只在红色系里挑，部队只在蓝色系里挑。
const ACCENT_FIXED := {
	"villefort": 0, "napoleon": 10, "marie": 8, "dantes": 4, "nemo": 3, "gourgaud": 2, "faria": 9,
	"friday": 6, "morel": 1, "corso": 5, "montholon": 7, "hudson_lowe": 11,
}
const ACCENT_POOLS := {"enemy_": [2, 11], "troop_": [1, 7, 10]}

static var _loaded := false
static var _list: Dictionary = {}
static var _index: Dictionary = {}     # "kind:id" -> 清单条目
static var _terrain: Dictionary = {}   # 地形名 -> 地块贴图 id
static var _hits: Dictionary = {}      # res 路径 -> 资源（插入顺序 = 最近使用顺序）
static var _misses: Dictionary = {}    # res 路径 -> true
static var _frames: Dictionary = {}    # "id/state" -> Array[Texture2D]
static var _metas: Dictionary = {}     # id -> {fps, attack_hit_frame}
static var _id_re: RegEx = null


# ---------------- 清单 ----------------

## 整份清单（只读；不要改返回的字典）
static func data() -> Dictionary:
	_ensure()
	return _list


## 清单里的一项（kind 是 bg cg chara face unit tex side prop 之一）；没有就回 {}
static func entry(kind: String, id: String) -> Dictionary:
	_ensure()
	return _index.get(kind + ":" + id, {})


## 某一类的全部条目（按清单顺序）；kind 为空 = 全部
static func assets(kind: String = "") -> Array:
	_ensure()
	var out: Array = []
	for a in _list.get("assets", []):
		if typeof(a) == TYPE_DICTIONARY and (kind == "" or str(a.get("kind", "")) == kind):
			out.append(a)
	return out


## 清单里的名字（中文，给占位图和调试用）；没有这一项就回 id
static func display_name(kind: String, id: String) -> String:
	var e := entry(kind, id)
	return str(e.get("name", id)) if not e.is_empty() else id


# ---------------- 找图 ----------------

## 全屏背景 art/hd/bg/<id>[__variant].jpg|png；变体没有就退回本图；都没有回 null
static func bg(id: String, variant: String = "") -> Texture2D:
	if variant != "":
		var v := _tex("bg", {"id": id + "__" + variant})
		if v != null:
			return v
	return _tex("bg", {"id": id})


## 事件插图 art/hd/cg/<id>.jpg|png
static func cg(id: String) -> Texture2D:
	return _tex("cg", {"id": id})


## 剧情立绘 art/hd/chara/<id>/<expr>.png（1200×1800 透明底）；没有这个表情退回 normal；都没有回 null
static func chara(id: String, expr: String = "normal") -> Texture2D:
	var t := _tex("chara", {"id": id, "expr": expr})
	if t == null and expr != "normal":
		t = _tex("chara", {"id": id, "expr": "normal"})
	return t


## 头像 art/hd/face/<id>.png（512×512 透明底）；id 是人物 id、troop_<兵种> 或 enemy_<种类>
static func face(id: String) -> Texture2D:
	return _tex("face", {"id": id})


## 战场小人一个状态的逐帧图 <state>_01、_02……（从 01 起连续，断号即止）；没有回 []。返回的是副本。
static func unit_frames(id: String, state: String) -> Array:
	var key := id + "/" + state
	if not _frames.has(key):
		var out: Array = []
		for n in range(1, MAX_FRAMES + 1):
			var t := _tex("unit", {"id": id, "state": state, "nn": "%02d" % n})
			if t == null:
				break
			out.append(t)
		_frames[key] = out
	return (_frames[key] as Array).duplicate()


## 小人的播放参数：{"fps": 帧率（默认 12）, "attack_hit_frame": 攻击第几帧打中（从 1 数；默认攻击帧数的一半，
## 向上取整，至少 1）}。来自可选的 art/hd/unit/<id>/meta.json。
static func unit_meta(id: String) -> Dictionary:
	if _metas.has(id):
		return (_metas[id] as Dictionary).duplicate()
	var fps := DEFAULT_FPS
	var hit := 0
	var path := ROOT + "unit/" + id + "/meta.json"
	if _safe(id) and FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			fps = clampi(int(parsed.get("fps", DEFAULT_FPS)), 1, 60)
			hit = int(parsed.get("attack_hit_frame", 0))
	var n := unit_frames(id, "attack").size()
	if hit <= 0:
		hit = maxi(1, ceili(n / 2.0))
	if n > 0:
		hit = mini(hit, n)
	var meta := {"fps": fps, "attack_hit_frame": hit}
	_metas[id] = meta
	return meta.duplicate()


## 小人图里双脚中点的像素（清单 kinds.unit.anchor，默认 (192, 336)）
static func unit_anchor() -> Vector2:
	var a = _kind("unit").get("anchor", [])
	if typeof(a) == TYPE_ARRAY and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return FALLBACK_ANCHOR


## 小人图的像素尺寸（清单 kinds.unit.size，默认 384×384）
static func unit_size() -> Vector2:
	return _size("unit", Vector2(384, 384))


## 地块贴图 art/hd/tile/<id>.png：顶面 tex（512×512）或侧面 side_earth / side_rock（512×256）
static func tile_tex(id: String) -> Texture2D:
	var kind := "side" if entry("side", id).size() > 0 else "tex"
	return _tex(kind, {"id": id})


## 战斗地形的顶面：清单优先，新地形暂借已有占位；未知地形、虚空与桥面摆件没有独立顶面。
static func terrain_tex(terrain: String) -> String:
	_ensure()
	return str(_terrain.get(terrain, TERRAIN_FALLBACK.get(terrain, "")))


## 地图摆件 art/hd/prop/<id>.glb（1 单位 = 1 格，原点在底面中心）；没有回 null
static func prop(id: String) -> PackedScene:
	var res := _res("prop", {"id": id})
	return res as PackedScene


## 每个 id 固定的一种强调色（立绘轮廓光、头像圆环、名字牌）；来自配色键 hd_accent_0..11
static func accent(id: String) -> Color:
	return CardTheme.color(StringName("hd_accent_%d" % accent_index(id)))


static func accent_index(id: String) -> int:
	if ACCENT_FIXED.has(id):
		return int(ACCENT_FIXED[id])
	var h := _hash(id)
	for prefix in ACCENT_POOLS:
		if id.begins_with(prefix):
			var pool: Array = ACCENT_POOLS[prefix]
			return int(pool[h % pool.size()])
	return h % ACCENT_COUNT


## 有没有这张真图（不读图，只查路径）
static func has_art(kind: String, id: String, fields: Dictionary = {}) -> bool:
	var f := fields.duplicate()
	f["id"] = id
	if kind == "chara" and not f.has("expr"):
		f["expr"] = "normal"
	if kind == "unit" and not f.has("state"):
		f["state"] = "idle"
	if kind == "unit" and not f.has("nn"):
		f["nn"] = "01"
	return _find(kind, f) != ""


## 清空缓存（找到的和没找到的都清；美术中途加了图、测试换图时用）
static func clear_cache() -> void:
	_hits.clear()
	_misses.clear()
	_frames.clear()
	_metas.clear()


# ---------------- 内部 ----------------

static func _tex(kind: String, fields: Dictionary) -> Texture2D:
	return _res(kind, fields) as Texture2D


static func _res(kind: String, fields: Dictionary) -> Resource:
	var path := _find(kind, fields)
	if path == "":
		return null
	if _hits.has(path):
		var hit: Resource = _hits[path]
		_hits.erase(path)
		_hits[path] = hit
		return hit
	var res: Resource = load(path)
	if res == null:
		_misses[path] = true
		return null
	if res is Texture2D and kind in MIPMAP_KINDS:
		res = _mipmapped(res as Texture2D)
	_hits[path] = res
	while _hits.size() > HIT_CAP:
		_hits.erase(_hits.keys()[0])
	return res


## 第一个存在的候选路径（主扩展名，再试 alt_ext）；都不在回 ""。不在的路径记进 _misses，下次不再查。
static func _find(kind: String, fields: Dictionary) -> String:
	for v in fields.values():
		if not _safe(str(v)):
			return ""
	for path in _candidates(kind, fields):
		if _hits.has(path):
			return path
		if _misses.has(path):
			continue
		if ResourceLoader.exists(path):
			return path
		_misses[path] = true
	return ""


static func _candidates(kind: String, fields: Dictionary) -> PackedStringArray:
	var k := _kind(kind)
	var pattern := str(k.get("path", FALLBACK_PATHS.get(kind, "")))
	var out := PackedStringArray()
	if pattern == "":
		return out
	var base := pattern.format(fields)
	out.append("res://" + base)
	for alt in k.get("alt_ext", FALLBACK_ALT.get(kind, [])):
		out.append("res://" + base.get_basename() + "." + str(alt))
	return out


## 导入时没生成 mipmap 的图在这里补一份（只做一次，结果进缓存）。无头模式读不回图，原样返回。
static func _mipmapped(tex: Texture2D) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return tex
	var img := tex.get_image()
	if img == null or img.is_empty() or img.has_mipmaps():
		return tex
	if img.is_compressed() and img.decompress() != OK:
		return tex
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _kind(kind: String) -> Dictionary:
	_ensure()
	var k = _list.get("kinds", {}).get(kind, {})
	return k if typeof(k) == TYPE_DICTIONARY else {}


static func _size(kind: String, fallback: Vector2) -> Vector2:
	var s = _kind(kind).get("size", [])
	if typeof(s) == TYPE_ARRAY and s.size() >= 2:
		return Vector2(float(s[0]), float(s[1]))
	return fallback


## id、表情、状态只许小写字母、数字和下划线（挡住 ../ 之类的路径）
static func _safe(s: String) -> bool:
	if _id_re == null:
		_id_re = RegEx.create_from_string("^[a-z0-9_]+$")
	return _id_re.search(s) != null


## 稳定的散列（不依赖引擎版本的 String.hash）
static func _hash(s: String) -> int:
	var h := 5381
	for i in s.length():
		h = ((h * 33) + s.unicode_at(i)) & 0x7fffffff
	return h


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(LIST_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(LIST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_list = parsed
	for a in _list.get("assets", []):
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var kind := str(a.get("kind", ""))
		var id := str(a.get("id", ""))
		_index[kind + ":" + id] = a
		if kind == "tex":
			for t in _split(a.get("terrain", "")):
				if not _terrain.has(t):
					_terrain[t] = id


static func _split(v) -> PackedStringArray:
	var out := PackedStringArray()
	var parts: Array = v if typeof(v) == TYPE_ARRAY else str(v).split(",")
	for p in parts:
		var s := str(p).strip_edges()
		if s != "":
			out.append(s)
	return out
