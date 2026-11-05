# 3D 战场上面的 2D 叠加层（按相机把 3D 点投到屏幕上再画，所以字和线在任何分辨率都清楚）：
# 格子坐标 A–I / 1–5、炮位标签、敌人的攻击线（白刃实线、远程虚线）、每个单位的血条（交火后会掉的那截标黄）
# 和兵力数字、兵种徽章、主角和伙伴的名字牌、技能就绪、方阵、濒死、本回合会倒下（骷髅）、敌人的精英 / 重装 /
# 猎官靶心 / 处决标记；同一格挤着几个敌人时叠成一张小卡；伤害按目标加总的「−合计 ×人数」、冲进鹰旗扣的军心、
# 下回合从红门出来的「+人数」、炮击准星的「下回合」和处决 / 斩首标记、被我方先手作废的敌情打叉。
# 只画，不接鼠标。数据都从 board 读。颜色走配色键 bt3d_*，文字走 battle_ui.json。没有 class_name。
extends Control

const Ui = preload("res://scripts/cards/ui/battle/battle_ui.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")

var board = null
var _boxes: Dictionary = {}
var k := 1.0   # 整体字号 / 尺寸系数（随格子在屏幕上的大小变）


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _c(key: String, a: float = 1.0) -> Color:
	var col := CardTheme.color(StringName(key))
	col.a *= a
	return col


func _draw() -> void:
	if board == null or int(board.cols) <= 0:
		return
	var cam = board.cam
	var mid := Vector3((board.cols - 1) * 0.5, 0.2, (board.rows - 1) * 0.5)
	k = clampf(cam.px_per_unit(mid) / 112.0, 0.78, 1.25)
	_draw_coords()
	_draw_reserved()
	var hits := {}
	var eagle := {}
	var lines: Array = []
	# 交火回放还在放：下一回合的敌情先不画（攻击线、伤害签），只画单位的血条和名字
	if not board.is_playing():
		_collect_intents(hits, eagle, lines)
	for ln in lines:
		_attack_line(ln[0], ln[1], bool(ln[2]))
	var stacks := {}
	for ou in board.ov_units:
		var nd = board.unit_node(str(ou["key"]))
		if nd != null and not nd.visible:
			continue
		if str(ou["side"]) == "enemy" and int(ou["n"]) > 1:
			var cell: Vector2i = ou["cell"]
			if not stacks.has(cell):
				stacks[cell] = []
			stacks[cell].append(ou)
			continue
		_unit_hud(ou, hits)
	for cell in stacks:
		_enemy_stack(cell, stacks[cell])
	for key in eagle:
		var row: Dictionary = eagle[key]
		var top: Vector3 = board.cell_top(key.x, key.y)
		var p: Vector2 = cam.project(top + Vector3(0, 1.22, 0))
		_pill_c(_sum_text(int(row["morale"]), int(row["n"])), p, "bt3d_pill_fatal", int(14 * k))
	_draw_waves()
	_draw_crosshair_labels()
	_draw_cancelled()


# ---------------- 坐标、炮位 ----------------

func _draw_coords() -> void:
	var cam = board.cam
	var f := HdTheme.font("num")
	var fs := int(roundf(12 * k))
	for c in range(board.cols):
		var p: Vector2 = cam.project(Vector3(c, board.BASE_Y, board.rows - 0.5))
		_text_c(char(65 + c), p + Vector2(0, 13 * k), fs, "bt3d_coord", f)
	for r in range(board.rows):
		var top: Vector3 = board.cell_top(0, r)
		var p2: Vector2 = cam.project(Vector3(-0.5, top.y, r))
		_text_c(str(r + 1), p2 + Vector2(-25 * k, 0), fs, "bt3d_coord", f)


func _draw_reserved() -> void:
	for cd in board.view.get("grid", {}).get("cells", []):
		if not bool(cd.get("reserved", false)):
			continue
		var q: PackedVector2Array = board.cell_quad(int(cd["col"]), int(cd["row"]))
		if q.size() < 4:
			continue
		var p := q[3].lerp(q[2], 0.08) + Vector2(4, -6) * k
		_pill(Ui.text("reserved"), p + Vector2(0, -16 * k), "bt3d_pill_reserved", int(11 * k), "bt3d_text")


# ---------------- 单位 ----------------

func _unit_hud(ou: Dictionary, hits: Dictionary) -> void:
	var d: Dictionary = ou["data"]
	var enemy := str(ou["side"]) == "enemy"
	var node = board.unit_node(str(ou["key"]))
	# 交火回放里还没落下的新敌人：小人藏着，血条也先不画
	if node != null and not node.visible:
		return
	var foot: Vector3 = node.position if node != null else ou["foot"]
	var head: float = float(node.head) if node != null else float(ou["head"])
	var cam = board.cam
	var hp2: Vector2 = cam.project(foot + Vector3(0, head, 0))
	var w := clampf(cam.px_per_unit(foot) * 0.5, 34.0, 64.0)
	var bh := maxf(5.0, roundf(6.0 * k))
	var bar := Rect2(Vector2(roundf(hp2.x - w * 0.5 + 6 * k), roundf(hp2.y - 12 * k)), Vector2(roundf(w), bh))
	var uid := ("e%d" % int(d["uid"])) if enemy else str(d["uid"])
	var dying := not enemy and str(d.get("state", "ok")) == "dying"
	var cls := str(d.get("cls", ""))
	var fill := "bt3d_hp_enemy" if enemy else ("bt3d_hp_dying" if dying else "bt3d_hp_ally")
	var hp_now: int = board.shown_hp(str(ou["key"]), int(d["hp"]))
	_hp_bar(bar, hp_now, int(d["max_hp"]), int(board.ghost_hp.get(uid, -1)), fill)
	var bc := Vector2(bar.position.x - 9 * k, bar.get_center().y)
	var r := 8.5 * k
	if enemy:
		var tags: Array = d.get("battle_tags", [])
		var elite := bool(d.get("elite", false))
		_badge(bc, r, Ui.enemy_char(str(d["kind"])), "bt3d_badge_enemy", "bt3d_ring_elite" if elite else "bt3d_badge_enemy_rim",
			2.4 if elite or "heavy" in tags else 1.2)
		var nx := _num(str(maxi(0, hp_now)), Vector2(bar.end.x + 3 * k, bar.get_center().y), "bt3d_text")
		if "hunter" in tags:
			_bullseye(bc + Vector2(-r - 8 * k, 0), 6.5 * k, 1.0 if board.hero_on_field() else 0.35)
		if "execute" in tags:
			_skull(Vector2(nx + 8 * k, bar.get_center().y), 5.5 * k)
		return
	var kind := str(d.get("kind", ""))
	var rim := "bt3d_badge_ally_rim"
	if kind == "hero":
		rim = "bt3d_ring_hero"
	var badge_fill := "bt3d_badge_hero" if kind == "hero" else "bt3d_badge_ally"
	if dying:
		badge_fill = "bt3d_badge_dying"
	if cls == "barricade":
		_badge(bc, r * 0.9, Ui.cls_char(cls), "bt3d_badge_barricade", "bt3d_badge_ally_rim", 1.2)
	elif kind == "companion":
		_badge_accent(bc, r, Ui.cls_char(cls), badge_fill, HdArt.accent(uid))
	else:
		_badge(bc, r, Ui.cls_char(cls), badge_fill, rim, 1.6 if kind == "hero" else 1.2)
	var right := bar.end.x + 3 * k
	if cls == "barricade":
		pass
	elif dying:
		right = _pill(Ui.pick("unit_state", "dying"), Vector2(right, bar.get_center().y - 8 * k), "bt3d_pill_dying",
			int(11 * k), "bt3d_text") + 3 * k
	else:
		right = _num(str(maxi(0, hp_now)), Vector2(right, bar.get_center().y), "bt3d_text") + 3 * k
	if bool(d.get("square", false)):
		_square_icon(Vector2(right + 6 * k, bar.get_center().y), 5.5 * k)
		right += 14 * k
	if bool(d.get("skill_ready", false)):
		_diamond(bc + Vector2(r * 0.75, -r * 0.8), 4.2 * k, "bt3d_skill_ready")
	# 血条上面一层层往上摞：名字牌（主角、伙伴），再上面是这一回合挨打的合计和标记，不往左右伸、不压邻格
	var top_y := bar.position.y - 3 * k
	if kind == "hero" or kind == "companion":
		var nm := str(d.get("name", ""))
		top_y = _name_plate(nm, Vector2(bar.get_center().x - 4 * k, top_y), kind == "hero",
			HdArt.accent(uid) if kind == "companion" else _c("bt3d_ring_hero")) - 3 * k
	if board.doomed.has(uid) and not dying:
		_skull_badge(bc + Vector2(-r - 9 * k, 0), 7.0 * k)
		draw_rect(bar.grow(1.5), _c("bt3d_doomed"), false, 1.5, true)
	if hits.has(uid):
		var row: Dictionary = hits[uid]
		var txt := _sum_text(int(row["dmg"]), int(row["n"]))
		var fs := int(13 * k)
		var pw := HdTheme.font("sans_bold").get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, fs)).x + 12
		var px := maxf(bar.end.x + 14 * k - pw, bar.position.x - 6 * k)
		_pill(txt, Vector2(px, top_y - (maxi(9, fs) + 6)), "bt3d_pill_fatal" if board.doomed.has(uid) else "bt3d_pill_dmg", fs, "bt3d_text")
		var mx := Vector2(px - 9 * k, top_y - (maxi(9, fs) + 6) * 0.5)
		for m in ["decap", "hunter", "execute"]:
			if not m in row["marks"]:
				continue
			match m:
				"execute":
					_skull(mx, 6.0 * k)
					mx.x -= 15 * k
				"hunter":
					_bullseye(mx, 6.5 * k, 1.0)
					mx.x -= 16 * k
				"decap":
					var dt := Ui.text("mark_decap")
					var dw := HdTheme.font("sans_bold").get_string_size(dt, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, int(11 * k))).x + 12
					_pill(dt, Vector2(mx.x - dw + 6 * k, mx.y - 8 * k), "bt3d_pill_fatal", int(11 * k), "bt3d_text")
					mx.x -= dw + 4 * k


## 同一格好几个敌人：叠成一张小卡（每行：徽章 兵力条 兵力），放在这一格最高的头顶上面。
## 交火回放时跟着小人走：锚在这几个小人现在站的地方（平均），兵力是回放放到的那一步
func _enemy_stack(cell: Vector2i, list: Array) -> void:
	var cam = board.cam
	var top: Vector3 = board.cell_top(cell.x, cell.y)
	var head := 0.0
	var sum := Vector3.ZERO
	var live := 0
	for ou in list:
		var nd = board.unit_node(str(ou["key"]))
		if nd != null:
			sum += nd.position
			live += 1
			head = maxf(head, float(nd.head))
		else:
			head = maxf(head, float(ou["head"]))
	if live > 0:
		var mid := sum / float(live)
		top = Vector3(mid.x, top.y, mid.z)
	var anchor: Vector2 = cam.project(top + Vector3(0, head + 0.05, 0))
	var row_h := roundf(13.0 * k)
	var w := clampf(cam.px_per_unit(top) * 0.42, 30.0, 52.0)
	var card_w := w + 52 * k
	var card := Rect2(Vector2(anchor.x - card_w * 0.5, anchor.y - row_h * list.size() - 8 * k), Vector2(card_w, row_h * list.size() + 6 * k))
	card = _clear_allies(card)
	draw_style_box(_box("bt3d_stack_bg", 5, "bt3d_badge_enemy_rim"), card)
	var y := card.position.y + 3 * k + row_h * 0.5
	for ou in list:
		var d: Dictionary = ou["data"]
		var tags: Array = d.get("battle_tags", [])
		var elite := bool(d.get("elite", false))
		var bc := Vector2(card.position.x + 9 * k, y)
		_badge(bc, 5.5 * k, Ui.enemy_char(str(d["kind"])), "bt3d_badge_enemy", "bt3d_ring_elite" if elite else "bt3d_badge_enemy_rim",
			2.0 if elite or "heavy" in tags else 1.0, 0.85)
		var bar := Rect2(Vector2(bc.x + 9 * k, y - 2.5 * k), Vector2(w, maxf(4.0, 5.0 * k)))
		var hp_now: int = board.shown_hp(str(ou["key"]), int(d["hp"]))
		_hp_bar(bar, hp_now, int(d["max_hp"]), int(board.ghost_hp.get("e%d" % int(d["uid"]), -1)), "bt3d_hp_enemy")
		var nx := _num(str(maxi(0, hp_now)), Vector2(bar.end.x + 3 * k, y), "bt3d_text", int(11 * k))
		if "hunter" in tags:
			_bullseye(Vector2(card.position.x - 8 * k, y), 5.0 * k, 1.0 if board.hero_on_field() else 0.35)
		if "execute" in tags:
			_skull(Vector2(nx + 6 * k, y), 4.5 * k)
		y += row_h


## 敌人叠成的小卡压住了后面我方单位的身子（高的叠卡伸到上一排）：往左或往右挪开（挪得少的那边），挪不开就不动
func _clear_allies(card: Rect2) -> Rect2:
	var cam = board.cam
	var bodies: Array = []
	for ou in board.ov_units:
		if str(ou["side"]) != "ally":
			continue
		var nd = board.unit_node(str(ou["key"]))
		var foot: Vector3 = nd.position if nd != null else ou["foot"]
		var head: float = float(nd.head) if nd != null else float(ou["head"])
		var hp: Vector2 = cam.project(foot + Vector3(0, head, 0))
		var fp: Vector2 = cam.project(foot)
		var half := 20.0 * k
		bodies.append(Rect2(Vector2(hp.x - half, hp.y - 14.0 * k), Vector2(half * 2.0, maxf(fp.y - hp.y, 8.0) + 14.0 * k)))
	var hit: Rect2 = Rect2()
	var any := false
	for b in bodies:
		if card.intersects(b):
			hit = b if not any else hit.merge(b)
			any = true
	if not any:
		return card
	var gap := 4.0 * k
	var to_left := card.end.x - hit.position.x + gap
	var to_right := hit.end.x - card.position.x + gap
	for dx in ([-to_left, to_right] if to_left <= to_right else [to_right, -to_left]):
		var moved := Rect2(card.position + Vector2(dx, 0), card.size)
		var clear := true
		for b in bodies:
			if moved.intersects(b):
				clear = false
				break
		if clear and moved.position.x >= 0.0 and moved.end.x <= size.x:
			return moved
	return card


func _hp_bar(r: Rect2, hp: int, max_hp: int, after: int, fill: String) -> void:
	draw_style_box(_box("bt3d_hp_bg", 2, "bt3d_hp_edge"), r.grow(1.0))
	var m := maxi(1, max_hp)
	var w := r.size.x * clampi(hp, 0, m) / m
	if w > 0.5:
		draw_rect(Rect2(r.position, Vector2(w, r.size.y)), _c(fill), true)
		draw_rect(Rect2(r.position, Vector2(w, maxf(1.0, r.size.y * 0.35))), _c("bt3d_hp_sheen"), true)
	if after >= 0 and after < hp:
		var w2 := r.size.x * clampi(after, 0, m) / m
		draw_rect(Rect2(r.position + Vector2(w2, 0), Vector2(w - w2, r.size.y)), _c("bt3d_hp_loss"), true)
	var ticks := mini(m, 40)
	if m > 1 and r.size.x / float(ticks) > 5.0:
		for i in range(1, ticks):
			var x := r.position.x + r.size.x * i / float(ticks)
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), _c("bt3d_hp_tick"), 1.0)


# ---------------- 敌情 ----------------

func _collect_intents(hits: Dictionary, eagle: Dictionary, lines: Array) -> void:
	for it in board.view.get("intents", []):
		if str(it.get("type", "")) != "enemy" or bool(it.get("cancelled", false)):
			continue
		var b := Vector2i(int(it["move_to"][0]), int(it["move_to"][1]))
		var atk: Dictionary = it.get("attack", {})
		var kind := str(atk.get("kind", ""))
		if kind == "eagle":
			var row: Dictionary = eagle.get(b, {"morale": 0, "n": 0})
			row["morale"] = int(row["morale"]) + int(atk.get("morale", 0))
			row["n"] = int(row["n"]) + 1
			eagle[b] = row
		elif kind == "gun" and str(atk.get("target", "")) != "":
			_add_hit(hits, str(atk["target"]), int(atk.get("dmg", 0)), [])
		elif kind == "melee" or kind == "ranged":
			var tgt := str(atk.get("target", ""))
			var tu: Dictionary = board.unit_data(tgt)
			if tu.is_empty():
				continue
			var from: Vector3 = board.cell_top(b.x, b.y) + Vector3(0, 0.5, 0)
			var tnode = board.unit_node("u:" + tgt)
			var to: Vector3 = (tnode.position if tnode != null else board.cell_top(int(tu["col"]), int(tu["row"]))) + Vector3(0, 0.45, 0)
			lines.append([from, to, kind == "ranged"])
			_add_hit(hits, tgt, int(atk.get("dmg", 0)), it.get("marks", []))


func _add_hit(hits: Dictionary, uid: String, dmg: int, marks: Array) -> void:
	var row: Dictionary = hits.get(uid, {"dmg": 0, "n": 0, "marks": []})
	row["dmg"] = int(row["dmg"]) + dmg
	row["n"] = int(row["n"]) + 1
	for m in marks:
		if not str(m) in row["marks"]:
			(row["marks"] as Array).append(str(m))
	hits[uid] = row


func _attack_line(a3: Vector3, b3: Vector3, ranged: bool) -> void:
	var cam = board.cam
	var a: Vector2 = cam.project(a3)
	var b: Vector2 = cam.project(b3)
	var len := a.distance_to(b)
	if len < 4.0:
		return
	var d := (b - a) / len
	var p0 := a + d * 6.0 * k
	var p1 := b - d * 12.0 * k
	var col := _c("bt3d_attack")
	var glow := _c("bt3d_attack", 0.28)
	if ranged:
		var x := 0.0
		var span := p0.distance_to(p1)
		while x < span:
			var q0 := p0 + d * x
			var q1 := p0 + d * minf(span, x + 7.0 * k)
			draw_line(q0, q1, glow, 5.0 * k, true)
			draw_line(q0, q1, col, 2.2 * k, true)
			x += 15.0 * k
	else:
		draw_line(p0, p1, glow, 6.0 * k, true)
		draw_line(p0, p1, col, 2.6 * k, true)
	var n := Vector2(-d.y, d.x)
	var s := 9.0 * k
	draw_colored_polygon(PackedVector2Array([p1 + d * s * 0.9, p1 - d * s * 0.4 + n * s * 0.6, p1 - d * s * 0.4 - n * s * 0.6]), col)


func _draw_waves() -> void:
	var t := int(board.view.get("turn", 0))
	var cam = board.cam
	var seen := {}
	for it in board.view.get("intents", []):
		if str(it.get("type", "")) != "wave" or int(it.get("turn", 0)) != t + 1:
			continue
		var wc := Vector2i(int(it["cell"][0]), int(it["cell"][1]))
		var n := (it.get("battle_units", []) as Array).size()
		var row := int(seen.get(wc, 0))
		seen[wc] = row + 1
		var p: Vector2 = cam.project(board.cell_top(wc.x, wc.y) + Vector3(0.62, 0.05, 0))
		_pill(Ui.text("plus", {"n": n}), p + Vector2(4 * k, -10 * k - row * 22 * k), "bt3d_pill_wave", int(14 * k), "bt3d_text")


func _draw_crosshair_labels() -> void:
	for it in board.view.get("intents", []):
		if str(it.get("type", "")) != "crosshair":
			continue
		var q: PackedVector2Array = board.cell_quad(int(it["cell"][0]), int(it["cell"][1]))
		if q.size() < 4:
			continue
		if not bool(it.get("now", false)):
			var nt := Ui.text("mark_next")
			var fs := int(11 * k)
			var w := HdTheme.font("sans_bold").get_string_size(nt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12 * k
			_pill(nt, q[2] + Vector2(-w - 4 * k, -20 * k), "bt3d_pill_dark", fs, "bt3d_gun_text")
		var y := q[0].y + 8 * k
		var x := q[0].x + 6 * k
		for m in it.get("marks", []):
			if str(m) == "execute":
				_skull(Vector2(x + 7 * k, y + 7 * k), 6.0 * k)
				y += 16 * k
			elif str(m) == "decap":
				_pill(Ui.text("mark_decap"), Vector2(x, y), "bt3d_pill_fatal", int(11 * k), "bt3d_text")
				y += 20 * k


## 被我方先手打死（或敌军已经溃逃）的敌人：意图作废，画一个灰叉
func _draw_cancelled() -> void:
	for it in board.view.get("intents", []):
		if str(it.get("type", "")) != "enemy" or not bool(it.get("cancelled", false)):
			continue
		var node = board.unit_node("e:%d" % int(it.get("enemy", -1)))
		if node == null:
			continue
		var p: Vector2 = board.cam.project(node.position + Vector3(0, float(node.head) * 0.5, 0))
		var s := 9.0 * k
		draw_line(p + Vector2(-s, -s), p + Vector2(s, s), _c("bt3d_cancelled_x"), 3.0 * k, true)
		draw_line(p + Vector2(s, -s), p + Vector2(-s, s), _c("bt3d_cancelled_x"), 3.0 * k, true)


func _sum_text(n: int, cnt: int) -> String:
	return Ui.text("minus", {"n": n}) if cnt <= 1 else Ui.text("minus_many", {"n": n, "k": cnt})


# ---------------- 小图形 ----------------

func _box(bg: String, radius: int, edge: String = "") -> StyleBoxFlat:
	var key := bg + "|" + edge + "|" + str(radius)
	if not _boxes.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = _c(bg)
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		sb.corner_detail = 6
		if edge != "":
			sb.border_color = _c(edge)
			sb.set_border_width_all(1)
		_boxes[key] = sb
	return _boxes[key]


func _badge(c: Vector2, r: float, glyph: String, fill: String, rim: String, rim_w: float, text_scale: float = 1.0) -> void:
	draw_circle(c + Vector2(0, 1.0), r + 1.5, _c("bt3d_badge_shadow"), true, -1.0, true)
	draw_circle(c, r, _c(fill), true, -1.0, true)
	draw_arc(c, r, 0.0, TAU, 28, _c(rim), rim_w, true)
	_glyph(c, glyph, int(maxf(8.0, r * 1.25 * text_scale)))


func _badge_accent(c: Vector2, r: float, glyph: String, fill: String, accent: Color) -> void:
	draw_circle(c + Vector2(0, 1.0), r + 1.5, _c("bt3d_badge_shadow"), true, -1.0, true)
	draw_circle(c, r, _c(fill), true, -1.0, true)
	draw_arc(c, r, 0.0, TAU, 28, accent, 2.0, true)
	_glyph(c, glyph, int(maxf(8.0, r * 1.25)))


func _glyph(c: Vector2, glyph: String, fs: int) -> void:
	var f := HdTheme.font("sans_bold")
	var ts := f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(c.x - ts.x * 0.5, c.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	draw_string(f, pos, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _c("bt3d_text"))


## 数字（左对齐在 p.x，竖直居中在 p.y），描一圈深色边；返回右端 x
func _num(s: String, p: Vector2, key: String, fs: int = -1) -> float:
	var f := HdTheme.font("num")
	var size := fs if fs > 0 else int(roundf(12 * k))
	var ts := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pos := Vector2(roundf(p.x), roundf(p.y + (f.get_ascent(size) - f.get_descent(size)) * 0.5))
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(3, int(4 * k)), _c("bt3d_text_outline"))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _c(key))
	return p.x + ts.x


func _text_c(s: String, p: Vector2, fs: int, key: String, f: Font) -> void:
	var ts := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(roundf(p.x - ts.x * 0.5), roundf(p.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5))
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, _c("bt3d_text_outline"))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _c(key))


## 药丸标签（左上角在 pos）；返回右端 x
func _pill(s: String, pos: Vector2, bg: String, fs: int, ink: String) -> float:
	var f := HdTheme.font("sans_bold")
	var size := maxi(9, fs)
	var ts := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var h := size + 6.0
	var r := Rect2(Vector2(roundf(pos.x), roundf(pos.y)), Vector2(ceilf(ts.x + 12), h))
	draw_style_box(_box(bg, int(h * 0.5), "bt3d_pill_edge"), r)
	draw_string(f, Vector2(r.position.x + 6, r.position.y + (h + f.get_ascent(size) - f.get_descent(size)) * 0.5), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, _c(ink))
	return r.end.x


## 药丸标签（中心在 p）
func _pill_c(s: String, p: Vector2, bg: String, fs: int) -> void:
	var f := HdTheme.font("sans_bold")
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, fs)).x + 12
	_pill(s, p - Vector2(w * 0.5, (fs + 6) * 0.5), bg, fs, "bt3d_text")


## 名字牌（底边中点在 bottom_center）；返回牌子上沿的 y
func _name_plate(s: String, bottom_center: Vector2, hero: bool, accent: Color) -> float:
	if s == "":
		return bottom_center.y
	var f := HdTheme.font("sans_bold")
	var fs := int(roundf(12 * k))
	var ts := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var h := fs + 6.0
	var r := Rect2(Vector2(roundf(bottom_center.x - ts.x * 0.5 - 7), roundf(bottom_center.y - h)), Vector2(ceilf(ts.x + 14), h))
	draw_style_box(_box("bt3d_name_bg", 3), r)
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), accent, true)
	draw_string(f, Vector2(r.position.x + 7, r.position.y + (h + f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - 1), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _c("bt3d_name_hero" if hero else "bt3d_text"))
	return r.position.y


func _skull(c: Vector2, r: float) -> void:
	draw_circle(c, r, _c("bt3d_skull"), true, -1.0, true)
	draw_rect(Rect2(c + Vector2(-r * 0.55, r * 0.45), Vector2(r * 1.1, r * 0.65)), _c("bt3d_skull"), true)
	draw_circle(c + Vector2(-r * 0.38, -r * 0.02), r * 0.28, _c("bt3d_skull_eye"), true, -1.0, true)
	draw_circle(c + Vector2(r * 0.38, -r * 0.02), r * 0.28, _c("bt3d_skull_eye"), true, -1.0, true)


func _skull_badge(c: Vector2, r: float) -> void:
	draw_circle(c, r + 1.5, _c("bt3d_doomed"), true, -1.0, true)
	_skull(c + Vector2(0, -r * 0.08), r * 0.68)


func _bullseye(c: Vector2, r: float, a: float) -> void:
	draw_circle(c, r, _c("bt3d_skull", a), true, -1.0, true)
	draw_circle(c, r * 0.66, _c("bt3d_gun", a), true, -1.0, true)
	draw_circle(c, r * 0.3, _c("bt3d_skull", a), true, -1.0, true)


func _diamond(c: Vector2, r: float, key: String) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, _c(key))
	var ring := pts.duplicate()
	ring.append(pts[0])
	draw_polyline(ring, _c("bt3d_text_outline"), 1.0, true)


func _square_icon(c: Vector2, r: float) -> void:
	draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), _c("bt3d_square"), false, 1.6, true)
	draw_rect(Rect2(c - Vector2(r, r) * 0.5, Vector2(r, r)), _c("bt3d_square"), true)
