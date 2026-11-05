# 小镇美术与地图：manifest 尺寸、瓦片 id、从 wake 走到每扇门、places 都有路点。
# godot --headless -s res://scripts/tests/test_town_assets.gd
extends SceneTree

var errs: Array = []
var _walkmaps: Dictionary = {}   # 地图路径 → {walk: {"x,y": bool}, seen: {"x,y": true}, w, h}

const TILE := 16
# doors[].building → manifest 里的建筑 id
const DOOR_BUILDING := {"market": "market_stall", "dock": "dock_shed"}

func _initialize() -> void:
	var manifest: Dictionary = _json("res://art/town/manifest.json")
	if manifest.is_empty():
		_fail("没有 manifest")
		return
	_check_tiles(manifest)
	_check_files(manifest)
	_check_map("res://data/town/maps/town.json", manifest)
	_check_map("res://data/town/maps/pawnshop.json", manifest)
	_check_town_doors(manifest)
	_check_pawnshop_a2(manifest)
	_check_pawnshop_spots(manifest)
	_check_portraits_transparent()
	if errs.is_empty():
		print("TOWN ASSETS OK")
		quit(0)
	else:
		for e in errs:
			printerr("FAIL: ", e)
		quit(1)

func _fail(msg: String) -> void:
	errs.append(msg)

func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("缺少 " + path)
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		_fail("JSON 失败 " + path)
		return {}
	var data = j.data
	if typeof(data) != TYPE_DICTIONARY:
		_fail("不是对象 " + path)
		return {}
	return data

func _image_size(path: String) -> Vector2i:
	# 走导入后的贴图，避免 Image.load 直接读 png 打出 WARNING（测试把 WARNING 当失败）。
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return Vector2i((res as Texture2D).get_width(), (res as Texture2D).get_height())
	_fail("读图失败 " + path)
	return Vector2i.ZERO

func _check_tiles(manifest: Dictionary) -> void:
	var tiles: Dictionary = manifest.get("tiles", {})
	for set_name in tiles:
		var spec: Dictionary = tiles[set_name]
		var path := "res://" + str(spec.get("image", ""))
		var sz := _image_size(path)
		if sz == Vector2i.ZERO:
			continue
		if sz.x != 256:
			_fail("%s 图集宽不是 256：%s" % [set_name, sz])
		var ids: Dictionary = spec.get("ids", {})
		for id in ids:
			var at: Array = ids[id].get("at", [])
			if at.size() != 2:
				_fail("瓦片坐标坏了 " + str(id))
				continue
			var px := int(at[0]) * 16
			var py := int(at[1]) * 16
			if px < 0 or py < 0 or px + 16 > sz.x or py + 16 > sz.y:
				_fail("瓦片越界 %s %s" % [id, at])

func _check_files(manifest: Dictionary) -> void:
	for id in manifest.get("buildings", {}):
		var b: Dictionary = manifest["buildings"][id]
		var sz := _image_size("res://" + str(b.get("image", "")))
		var want: Array = b.get("size", [])
		if want.size() == 2 and sz != Vector2i.ZERO and (sz.x != int(want[0]) or sz.y != int(want[1])):
			_fail("建筑尺寸不符 " + str(id))
	for id in manifest.get("chars", {}):
		var c: Dictionary = manifest["chars"][id]
		var sz2 := _image_size("res://" + str(c.get("image", "")))
		if sz2 != Vector2i.ZERO and sz2 != Vector2i(64, 128):
			_fail("行走图不是 64x128：" + str(id) + " " + str(sz2))
	for id in manifest.get("shops", {}):
		var s: Dictionary = manifest["shops"][id]
		var sz3 := _image_size("res://" + str(s.get("bg", "")))
		if sz3 != Vector2i.ZERO and sz3 != Vector2i(320, 180):
			_fail("店内背景不是 320x180：" + str(id) + " " + str(sz3))
	for id in ["ruhua", "wu", "postman", "stranger_refugee", "stranger_peddler", "stranger_fence", "stranger_collector"]:
		var psz := _image_size("res://art/portraits/%s.png" % id)
		if psz != Vector2i.ZERO and psz != Vector2i(48, 64):
			_fail("立绘不是 48x64：" + id)

func _check_map(path: String, manifest: Dictionary) -> void:
	var m := _json(path)
	if m.is_empty():
		return
	var set_name := str(m.get("tileset", ""))
	var ids: Dictionary = manifest.get("tiles", {}).get(set_name, {}).get("ids", {})
	var ground: Array = m.get("layers", {}).get("ground", [])
	var size: Array = m.get("size", [0, 0])
	var w := int(size[0])
	var h := int(size[1])
	if ground.size() != h:
		_fail("%s 地面行数 %d != %d" % [path, ground.size(), h])
		return
	var walk := {}
	for y in h:
		var cells := str(ground[y]).split(" ")
		if cells.size() != w:
			_fail("%s 第 %d 行列数 %d != %d" % [path, y, cells.size(), w])
			return
		for x in w:
			var tid := cells[x]
			if tid == ".":
				walk["%d,%d" % [x, y]] = false
				continue
			if not ids.has(tid):
				_fail("%s 未知瓦片 %s @ %d,%d" % [path, tid, x, y])
				walk["%d,%d" % [x, y]] = false
			else:
				walk["%d,%d" % [x, y]] = bool(ids[tid].get("walk", false))
	var spawn: Array = m.get("spawns", {}).get("wake", [])
	if spawn.size() != 2:
		_fail(path + " 没有 wake")
		return
	var seen := {}
	var q: Array = [[int(spawn[0]), int(spawn[1])]]
	var head := 0
	while head < q.size():
		var cx: int = q[head][0]
		var cy: int = q[head][1]
		head += 1
		var key := "%d,%d" % [cx, cy]
		if seen.has(key):
			continue
		if cx < 0 or cy < 0 or cx >= w or cy >= h:
			continue
		if not walk.get(key, false):
			continue
		seen[key] = true
		q.append([cx + 1, cy])
		q.append([cx - 1, cy])
		q.append([cx, cy + 1])
		q.append([cx, cy - 1])
	for door in m.get("doors", []):
		var at: Array = door.get("at", [])
		var dk := "%d,%d" % [int(at[0]), int(at[1])]
		if not seen.has(dk):
			_fail("%s 门走不到 %s %s" % [path, door.get("building", ""), at])
	var nodes: Dictionary = m.get("waypoints", {}).get("nodes", {})
	for place in m.get("places", {}):
		for node_name in m["places"][place]:
			if not nodes.has(str(node_name)):
				_fail("%s 地点 %s 没有路点 %s" % [path, place, node_name])
	_walkmaps[path] = {"walk": walk, "seen": seen, "w": w, "h": h}
	_check_edges(path, m, walk, w, h)

# 路网每条边（两个路点格中心之间的直线）只能经过可走的格子：不许斜着穿柜台、墙、水。
func _check_edges(path: String, m: Dictionary, walk: Dictionary, w: int, h: int) -> void:
	var nodes: Dictionary = m.get("waypoints", {}).get("nodes", {})
	for edge in m.get("waypoints", {}).get("edges", []):
		var a := str(edge[0])
		var b := str(edge[1])
		if not nodes.has(a) or not nodes.has(b):
			_fail("%s 路网边 %s-%s 引用了不存在的路点" % [path, a, b])
			continue
		var pa := Vector2(float(nodes[a][0]) + 0.5, float(nodes[a][1]) + 0.5)
		var pb := Vector2(float(nodes[b][0]) + 0.5, float(nodes[b][1]) + 0.5)
		var steps := maxi(1, int(ceil(pa.distance_to(pb) * 20.0)))
		var bad := ""
		for i in range(steps + 1):
			var p := pa.lerp(pb, float(i) / float(steps))
			var cx := int(floor(p.x))
			var cy := int(floor(p.y))
			if cx < 0 or cy < 0 or cx >= w or cy >= h or not walk.get("%d,%d" % [cx, cy], false):
				bad = "%d,%d" % [cx, cy]
				break
		if bad != "":
			_fail("%s 路网边 %s-%s 穿过了不可走的格子 %s" % [path, a, b, bad])


func _check_pawnshop_a2(manifest: Dictionary) -> void:
	# T02b：房间约 20×12，后墙至少 3 格，高柜台横贯，合同点位都在。
	var m := _json("res://data/town/maps/pawnshop.json")
	if m.is_empty():
		return
	var size: Array = m.get("size", [])
	if size.size() != 2 or int(size[0]) < 18 or int(size[0]) > 22 or int(size[1]) < 11 or int(size[1]) > 14:
		_fail("当铺尺寸应在 20×12 左右，现在 %s" % [size])
	for key in ["counter_spot", "customer_spot", "shelf", "bed", "backdoor", "lamp", "telegraph", "exit"]:
		if not m.has(key):
			_fail("当铺缺少点位 " + key)
	var spots: Array = m.get("customer_spot", [])
	if spots.size() < 2:
		_fail("customer_spot 至少两个")
	var cs: Array = m.get("counter_spot", [])
	if cs.size() == 2:
		for s in spots:
			if typeof(s) != TYPE_ARRAY or int(s[1]) <= int(cs[1]):
				_fail("客人等候点应在柜台南侧")
	var shelf: Array = m.get("shelf", [])
	if shelf.size() != 4 or int(shelf[2]) < 8:
		_fail("shelf 应是货架前的一整段格子")
	var ids: Dictionary = manifest.get("tiles", {}).get("interior", {}).get("ids", {})
	var ground: Array = m.get("layers", {}).get("ground", [])
	for y in range(mini(3, ground.size())):
		var cells := str(ground[y]).split(" ")
		for x in cells.size():
			var tid := cells[x]
			if not ids.has(tid) or bool(ids[tid].get("walk", false)):
				_fail("后墙不足三格高 @ %d,%d %s" % [x, y, tid])
				return
	var spanned := false
	for y in range(3, ground.size() - 1):
		var cells2 := str(ground[y]).split(" ")
		var run := 0
		var best := 0
		for tid2 in cells2:
			if str(tid2).begins_with("counter"):
				run += 1
				best = maxi(best, run)
			else:
				run = 0
		if best >= 10:
			spanned = true
	if not spanned:
		_fail("没有横贯房间的柜台")



# 门格要落在贴图里门所在的位置：建筑 at（格）+ manifest 的 door 矩形（像素）。
# 门格 = 门中心所在的列、门下沿所在的行；出当铺的落脚点是它正下方一格（门外的地面）。
func _check_town_doors(manifest: Dictionary) -> void:
	var path := "res://data/town/maps/town.json"
	var m := _json(path)
	if m.is_empty():
		return
	var placed := {}
	for o in m.get("objects", []):
		if str(o.get("kind", "")) == "building":
			placed[str(o["id"])] = o
	var blds: Dictionary = manifest.get("buildings", {})
	var pawn: Dictionary = {}
	for door in m.get("doors", []):
		var bid := str(door.get("building", ""))
		if bid == "pawnshop":
			pawn = door
		var oid: String = DOOR_BUILDING.get(bid, bid)
		if not placed.has(oid) or not blds.has(oid):
			_fail("门 %s 找不到对应的建筑贴图 %s" % [bid, oid])
			continue
		var at: Array = placed[oid]["at"]
		var d: Array = blds[oid].get("door", [])
		var cx := float(int(at[0]) * TILE) + float(d[0]) + float(d[2]) * 0.5
		var bottom := float(int(at[1]) * TILE) + float(d[1]) + float(d[3]) - 1.0
		var want := [int(floor(cx / TILE)), int(floor(bottom / TILE))]
		var got: Array = door.get("at", [])
		if got.size() != 2 or int(got[0]) != want[0] or int(got[1]) != want[1]:
			_fail("门 %s 的 at %s 不是贴图里门的位置 %s（建筑 at %s + door %s）" % [bid, got, want, at, d])
	var sp: Array = m.get("spawns", {}).get("from_pawnshop", [])
	if pawn.is_empty() or sp.size() != 2:
		_fail("town.json 缺少当铺门或 spawns.from_pawnshop")
		return
	var pa: Array = pawn["at"]
	if int(sp[0]) != int(pa[0]) or int(sp[1]) != int(pa[1]) + 1:
		_fail("from_pawnshop %s 应在当铺门格 %s 正下方一格" % [sp, pa])
	var key := "%d,%d" % [int(sp[0]), int(sp[1])]
	var wm: Dictionary = _walkmaps.get(path, {})
	if wm.is_empty() or not wm["walk"].get(key, false):
		_fail("from_pawnshop %s 不是可走的地面" % [sp])
	elif not wm["seen"].has(key):
		_fail("from_pawnshop %s 从 wake 走不到" % [sp])
	# 脚点（格中心，脚框 10×6）不压在任何建筑的碰撞矩形里
	var foot := Vector2(float(sp[0]) * TILE + TILE * 0.5, float(sp[1]) * TILE + TILE * 0.5)
	var foot_rect := Rect2(foot.x - 5.0, foot.y - 6.0, 10.0, 6.0)
	for oid2 in placed:
		var spec: Dictionary = blds.get(oid2, {})
		var fp: Array = spec.get("footprint", [])
		if fp.size() != 4:
			continue
		var o_at: Array = placed[oid2]["at"]
		var r := Rect2(float(int(o_at[0]) * TILE) + float(fp[0]), float(int(o_at[1]) * TILE) + float(fp[1]), float(fp[2]), float(fp[3]))
		if foot_rect.intersects(r):
			_fail("from_pawnshop %s 落在建筑 %s 的碰撞范围里" % [sp, oid2])


# 当铺里的站位：客人等候点在柜台贴图的纵向范围之外（站在柜台前的地板上），可走、走得到；
# 所有站位（柜台后、客人位、灯、电报…）都在它们碰到的道具之前——道具按脚线（位置+anchor）排序，
# 脚线比人低的道具会盖住人（货架、库房门以前就这样把柜台后的人盖住）。
func _check_pawnshop_spots(manifest: Dictionary) -> void:
	var path := "res://data/town/maps/pawnshop.json"
	var m := _json(path)
	if m.is_empty():
		return
	var wm: Dictionary = _walkmaps.get(path, {})
	var props: Dictionary = manifest.get("props", {})
	var placed: Array = []
	for o in m.get("objects", []):
		if str(o.get("kind", "")) != "prop":
			continue
		var spec: Dictionary = props.get(str(o["id"]), {})
		if spec.is_empty():
			_fail("当铺里的道具不在 manifest：" + str(o["id"]))
			continue
		var sz := _image_size("res://" + str(spec.get("image", "")))
		var pos := Vector2(float(o["at"][0]) * TILE, float(o["at"][1]) * TILE)
		var anchor: Array = spec.get("anchor", [0, 0])
		placed.append({"id": str(o["id"]), "rect": Rect2(pos, Vector2(sz)), "foot_y": pos.y + float(anchor[1])})
	for s in m.get("customer_spot", []):
		var key := "%d,%d" % [int(s[0]), int(s[1])]
		if not wm.get("walk", {}).get(key, false):
			_fail("客人等候点 %s 不是可走的地面" % [s])
		elif not wm.get("seen", {}).has(key):
			_fail("客人等候点 %s 从 wake 走不到" % [s])
		var tile_top := float(int(s[1]) * TILE)
		for p in placed:
			if not str(p["id"]).begins_with("counter"):
				continue
			var r: Rect2 = p["rect"]
			if tile_top < r.end.y and tile_top + TILE > r.position.y:
				_fail("客人等候点 %s 在柜台 %s 的贴图范围里（纵向 %d–%d），要挪到柜台前的地板上" % [s, p["id"], int(r.position.y), int(r.end.y)])
	var standing: Array = []
	if m.has("counter_spot"):
		standing.append(["counter_spot", m["counter_spot"]])
	for i in m.get("customer_spot", []).size():
		standing.append(["customer_spot[%d]" % i, m["customer_spot"][i]])
	for key2 in ["wake", "front_door"]:
		if m.get("spawns", {}).has(key2):
			standing.append(["spawns." + key2, m["spawns"][key2]])
	for key3 in ["lamp", "telegraph"]:
		if m.has(key3):
			standing.append([key3, m[key3]])
	var gate_in = m.get("waypoints", {}).get("nodes", {}).get("gate_in", null)
	if gate_in != null:
		standing.append(["节点 gate_in", gate_in])
	for row in standing:
		var cell: Array = row[1]
		var foot := Vector2(float(cell[0]) * TILE + TILE * 0.5, float(cell[1]) * TILE + TILE * 0.5)
		var body := Rect2(foot.x - 6.0, foot.y - 28.0, 12.0, 28.0)
		for p2 in placed:
			if body.intersects(p2["rect"]) and not (float(p2["foot_y"]) < foot.y):
				_fail("站在 %s %s 的人会被 %s 盖住（道具脚线 y=%d，不在人脚线 y=%d 之上；改 prop_meta 的 anchor）" % [row[0], cell, p2["id"], int(p2["foot_y"]), int(foot.y)])


# T02 的立绘背景必须是透明的（旧立绘都是）：四个角 alpha == 0。
func _check_portraits_transparent() -> void:
	for id in ["ruhua", "wu", "postman", "stranger_refugee", "stranger_peddler", "stranger_fence", "stranger_collector"]:
		var path := "res://art/portraits/%s.png" % id
		if not ResourceLoader.exists(path):
			continue   # 缺图已在 _check_files 报过
		var tex = load(path)
		if not (tex is Texture2D):
			continue
		var img: Image = (tex as Texture2D).get_image()
		if img == null or img.is_empty():
			_fail("立绘读不出像素 " + id)
			continue
		var w := img.get_width()
		var h := img.get_height()
		for corner in [Vector2i(0, 0), Vector2i(w - 1, 0), Vector2i(0, h - 1), Vector2i(w - 1, h - 1)]:
			if img.get_pixelv(corner).a > 0.0:
				_fail("立绘 %s 的角 %s 不透明（背景应是透明的）" % [id, corner])
