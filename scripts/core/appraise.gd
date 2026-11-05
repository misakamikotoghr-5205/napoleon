# 验货“找不同”的规则（不画图）：
#   · 图鉴页：这件东西对哪一页（data/pages.json 的 atlas；生成的货按 item_templates.json 的 appraise 拼一页），开没开（已有的知识页 / 鉴别录 / 哥哥的信）。
#   · 墨：每件三笔；有这一类的鉴别录再多一笔。圈一笔 = 一笔墨 + 两分钟（小镇里走钟）。
#   · 圈：把一笔拟合成圆（重心 + 平均半径）；部位中心在圈里（或圈心落在部位里）才算圈中；圈太大不算。
#   · 批注：只写看得见、摸得着的比较结果；不说对方心思，不说价。
extends RefCounted

const FlawRender = preload("res://scripts/core/flaw_render.gd")

const BASE_INK := 3
const MINUTES_PER_STROKE := 2
const IMG := 64.0
const MAX_RADIUS := IMG * 0.4      # 半径超过画面四成：圈了一大片，看不出指的是哪儿
const MIN_RADIUS := 2.0            # 比这还小：只是点了一下，不算一笔
const TOOLS := ["magnifier", "scale", "book", "hand", "nose"]
const TOOL_CN := {"magnifier": "放大镜", "scale": "秤", "book": "鉴别录", "hand": "手摸", "nose": "鼻闻"}
const TOOL_HINT := {"magnifier": "细处", "scale": "分量", "book": "批号", "hand": "看摸掂", "nose": "气味"}

static var _cache: Dictionary = {}

static func clear_cache() -> void:
	_cache.clear()

static func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j = JSON.parse_string(FileAccess.get_file_as_string(path))
	return j if typeof(j) == TYPE_DICTIONARY else {}

static func atlas() -> Dictionary:
	if not _cache.has("atlas"):
		var pages: Dictionary = _json("res://data/pages.json")
		_cache["atlas"] = pages.get("atlas", {})
		_cache["general"] = pages.get("atlas_general", [])
	return _cache["atlas"]

static func general_hints() -> Array:
	atlas()
	return _cache["general"]

static func templates() -> Dictionary:
	if not _cache.has("templates"):
		_cache["templates"] = _json("res://data/town/item_templates.json")
	return _cache["templates"]

# ---------------- 图鉴页 ----------------
# 返回 {key, title, sprite, weight, real[], ok[], tells[], unlocked, book}
static func ref_entry(world, item: Dictionary) -> Dictionary:
	var e: Dictionary = {}
	var key := str(item.get("ref", ""))
	var pages: Dictionary = atlas()
	if key != "" and pages.has(key):
		e = (pages[key] as Dictionary).duplicate(true)
	elif str(item.get("template_id", "")) != "":
		key = "gen:%s:%s" % [item.get("cat", ""), item.get("template_id", "")]
		e = _generated_entry(item)
	else:
		key = "cat:" + str(item.get("cat", ""))
		e = {"title": str(item.get("cat_cn", "")), "sprite": str(item.get("sprite", "")), "unlock": []}
	e["key"] = key
	e["unlocked"] = is_open(world, e.get("unlock", []))
	e["book"] = is_open(world, e.get("book", []))
	for k in ["real", "ok", "tells"]:
		if not e.has(k):
			e[k] = []
	return e

static func _generated_entry(item: Dictionary) -> Dictionary:
	var t: Dictionary = templates()
	var cat := str(item.get("cat", ""))
	var content: Dictionary = t.get("categories", {}).get(cat, {})
	var rules: Dictionary = t.get("appraise", {}).get("categories", {}).get(cat, {})
	var variant: Dictionary = {}
	for v in content.get("variants", []):
		if str(v.get("id", "")) == str(item.get("template_id", "")):
			variant = v
			break
	var sprite := str(variant.get("sprite", ""))
	if sprite == "":
		sprite = "proc:" + str(variant.get("id", cat))
	var ok: Array = [str(variant.get("worn_text", ""))]
	ok.append_array(rules.get("ok", []))
	return {
		"title": str(variant.get("name", item.get("name", ""))),
		"sprite": sprite,
		"real": [str(variant.get("real_text", "")), str(variant.get("material", ""))],
		"ok": ok,
		"tells": [str(variant.get("fake_text", ""))] + rules.get("tells", []),
		"unlock": rules.get("unlock", []),
		"book": rules.get("book", [])
	}

# 开页条件：always / page:<知识页> / unlock:<柜台解锁> / flag:<标记>；任意一条成立即开
static func is_open(world, conds: Array) -> bool:
	for c in conds:
		var s := str(c)
		if s == "always":
			return true
		if world == null:
			continue
		if s.begins_with("page:") and world.pages.has(s.substr(5)):
			return true
		if s.begins_with("unlock:") and world.unlocked.get(s.substr(7), false):
			return true
		if s.begins_with("flag:") and world.flags.get(s.substr(5), false):
			return true
	return false

static func ink_max(world, item: Dictionary) -> int:
	return BASE_INK + (1 if ref_entry(world, item)["book"] else 0)

# ---------------- 圈 ----------------
# points：一笔的点（物品图坐标，0..64）。圈得像个圈才算：点够多、绕圆心转了大半圈、半径不太离散。
static func fit_circle(points: Array) -> Dictionary:
	var n := points.size()
	if n < 6:
		return {"ok": false, "why": "short"}
	var c := Vector2.ZERO
	for p in points:
		c += p
	c /= float(n)
	var rs := 0.0
	for p in points:
		rs += (p - c).length()
	var r := rs / float(n)
	if r < MIN_RADIUS:
		return {"ok": false, "why": "small", "center": c, "radius": r}
	var spread := 0.0
	for p in points:
		spread += absf((p - c).length() - r)
	spread /= float(n)
	var bins: Dictionary = {}
	for p in points:
		var a: float = (p - c).angle()
		bins[int(floor((a + PI) / TAU * 12.0)) % 12] = true
	if bins.size() < 8 or spread > r * 0.55:
		return {"ok": false, "why": "shape", "center": c, "radius": r}
	return {"ok": true, "center": c, "radius": r}

static func part_rect(p: Dictionary) -> Rect2:
	var r: Array = p.get("rect", [])
	if r.size() != 4:
		return Rect2()
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))

# 判圈：返回 {kind, pids, need}
#   hit：圈中了、工具也对（同一处、同一工具的几个部位一起揭开）
#   tool：圈中了一处，可这处要换工具才看得出
#   again：圈的地方刚才已经圈过
#   oversize：圈太大
#   miss：圈里没有可看的部位
static func hit_test(item: Dictionary, center: Vector2, radius: float, tool: String, revealed: Dictionary) -> Dictionary:
	if radius > MAX_RADIUS:
		return {"kind": "oversize", "pids": []}
	var cands: Array = []
	for p in item.get("parts", []):
		var rect := part_rect(p)
		if rect.size == Vector2.ZERO:
			continue
		var pc := rect.get_center()
		var pr := maxf(rect.size.x, rect.size.y) / 2.0
		var dist := pc.distance_to(center)
		var geometric := dist <= radius + 1.0 or rect.grow(1.0).has_point(center)
		if not geometric or radius > maxf(pr * 2.2, 7.0):
			continue
		var score := dist / maxf(pr, 3.0) + 0.25 * absf(log(maxf(radius, 0.5) / maxf(pr, 2.0)))
		cands.append({"p": p, "score": score, "c": pc})
	cands.sort_custom(func(a, b): return a["score"] < b["score"])
	var best = null
	for cd in cands:
		if str(cd["p"].get("tool", "magnifier")) == tool and not revealed.has(str(cd["p"]["id"])):
			best = cd
			break
	if best != null:
		var pids: Array = [str(best["p"]["id"])]
		for cd in cands:
			var pid := str(cd["p"]["id"])
			if pids.has(pid) or revealed.has(pid) or str(cd["p"].get("tool", "magnifier")) != tool:
				continue
			if (cd["c"] as Vector2).distance_to(best["c"]) <= 2.5:
				pids.append(pid)
		return {"kind": "hit", "pids": pids}
	for cd in cands:
		if not revealed.has(str(cd["p"]["id"])):
			return {"kind": "tool", "pids": [], "need": str(cd["p"].get("tool", "magnifier")), "pid": str(cd["p"]["id"])}
	if not cands.is_empty():
		return {"kind": "again", "pids": [], "pid": str(cands[0]["p"]["id"])}
	return {"kind": "miss", "pids": []}

# ---------------- 批注 ----------------
static func benign_of(item: Dictionary, pid: String) -> Dictionary:
	for f in item.get("flaws", []):
		if str(f.get("part", "")) == pid and FlawRender.is_benign(f):
			return f
	return {}

# 圈中一处后的批注（finding 是 session.inspect 揭开的那条）。differs：图上这一处和图鉴比，看得出不一样。
static func hit_note(item: Dictionary, pid: String, finding: String, differs: bool, has_ref: bool) -> Dictionary:
	var p: Dictionary = FlawRender.part_of(item, pid)
	var label := str(p.get("label", pid))
	var b: Dictionary = benign_of(item, pid)
	if not b.is_empty() and has_ref:
		var what := str(b.get("note", "这一处有些旧痕"))
		return {"tone": "benign", "text": "%s：和图鉴不一样——%s。图鉴上说，用旧了常有这样的痕迹，不一定是毛病。（%s）" % [label, what, finding]}
	if bool(p.get("tell", false)):
		var lead := "和图鉴不一样：" if differs and has_ref else ""
		return {"tone": "tell", "text": "%s：%s%s" % [label, lead, finding]}
	return {"tone": "plain", "text": "%s：%s" % [label, finding]}

static func miss_note(kind: String, has_ref: bool, differs: bool, need: String = "") -> String:
	match kind:
		"oversize":
			return "圈得太大了，看不出指的是哪一处。圈小些，圈准了。"
		"tool":
			if need == "magnifier":
				return "这一处太细，肉眼看不真切——换放大镜再圈。"
			return "这一处得用%s才看得出来。" % TOOL_CN.get(need, need)
		"again":
			return "这一处刚才已经圈过了。"
	if not has_ref:
		return "这里看不出什么毛病。（手边没有这一类的图鉴可对照。）"
	if differs:
		return "这里和图鉴有点出入，可说不上是什么毛病。"
	return "这里看不出和图鉴有什么不同。"
