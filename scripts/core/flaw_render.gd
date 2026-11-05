# 验货“找不同”的画：图鉴上的真品图，和手上这件（真品图 + 按部位画上的破绽 / 旧痕）。
# 全部是确定的：像素细节只由“破绽种子”决定（种子 = JevRng(世界种子, 物品 id, 序号)，或生成物品时存进物品定义），
# 不用 randf；同一种子画出来逐像素相同，存档读档后也一样。
# 破绽条目（物品定义 flaws[]）：{part, kind, rect?, seed?, benign?, fine?, note?}
#   rect 缺省取部位的 rect；fine=true（或部位工具是放大镜）表示细处——肉眼图上不画，只有放大镜镜片里看得见。
extends RefCounted

const R = preload("res://scripts/sim/jev_rng.gd")
const SIZE := 64

const FINE_KINDS := ["speck", "erase", "thin", "retrace", "base_metal", "stitch", "whiten"]
const BENIGN_KINDS := ["shine", "scuff", "repair", "chip", "watermark"]

static var _sprites: Dictionary = {}

static func clear_cache() -> void:
	_sprites.clear()

# ---------------- 底图 ----------------
static func load_sprite(path: String) -> Image:
	if path == "":
		return null
	if path.begins_with("proc:"):
		return proc_base(path.substr(5))
	if not _sprites.has(path):
		var img: Image = null
		var p := path if path.begins_with("res://") else "res://" + path
		if ResourceLoader.exists(p):
			var tx: Texture2D = load(p)
			if tx != null:
				img = tx.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			if img.get_width() != SIZE or img.get_height() != SIZE:
				img.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
		_sprites[path] = img
	var cached: Image = _sprites[path]
	return cached.duplicate() if cached != null else null

# 物品自己的样子（还没画破绽）：有特写图用特写图；生成的衣物、器物等没有画的，用程序画的底图
static func base_key(item: Dictionary) -> String:
	var sp := str(item.get("sprite", ""))
	if sp != "":
		return sp
	var tid := str(item.get("template_id", ""))
	return "proc:" + (tid if tid != "" else str(item.get("cat", "thing")))

static func base_image(item: Dictionary) -> Image:
	var img := load_sprite(base_key(item))
	if img == null:
		img = proc_base(str(item.get("cat", "thing")))
	return img

# 手上这件：底图 + 破绽 / 旧痕。fine=false 是肉眼看到的样子（细处的破绽看不出来）；fine=true 是放大镜里的样子
static func hand_image(item: Dictionary, base_seed: int, fine: bool) -> Image:
	var img := base_image(item)
	var flaws: Array = item.get("flaws", [])
	for i in flaws.size():
		var f: Dictionary = flaws[i]
		if is_fine(item, f) and not fine:
			continue
		apply(img, f, flaw_seed(item, f, i, base_seed), flaw_rect(item, f))
	return img

static func flaw_seed(item: Dictionary, f: Dictionary, idx: int, base_seed: int) -> int:
	if f.has("seed"):
		return int(f["seed"]) & 0x7fffffff
	var id := str(item.get("def_id", item.get("id", "")))
	return int(R.draw(base_seed, "flaw_render", [id, idx]) * 2147483647.0)

static func part_of(item: Dictionary, pid: String) -> Dictionary:
	for p in item.get("parts", []):
		if str(p.get("id", "")) == pid:
			return p
	return {}

static func flaw_rect(item: Dictionary, f: Dictionary) -> Rect2i:
	var r: Array = f.get("rect", [])
	if r.size() != 4:
		r = part_of(item, str(f.get("part", ""))).get("rect", [])
	if r.size() != 4:
		return Rect2i()
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])).intersection(Rect2i(0, 0, SIZE, SIZE))

static func is_fine(item: Dictionary, f: Dictionary) -> bool:
	if f.has("fine"):
		return bool(f["fine"])
	return str(part_of(item, str(f.get("part", ""))).get("tool", "")) == "magnifier"

static func is_benign(f: Dictionary) -> bool:
	return bool(f.get("benign", BENIGN_KINDS.has(str(f.get("kind", "")))))

# ---------------- 比较 ----------------
static func region_differs(a: Image, b: Image, r: Rect2i, threshold: float = 0.12) -> bool:
	if a == null or b == null:
		return false
	var rr := r.intersection(Rect2i(0, 0, SIZE, SIZE))
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) + absf(ca.a - cb.a) > threshold:
				return true
	return false

static func same_pixels(a: Image, b: Image) -> bool:
	if a == null or b == null:
		return a == b
	return a.get_data() == b.get_data()

# ---------------- 确定的整数哈希 ----------------
static func _mix(v: int) -> int:
	var h := v & 0xffffffff
	h ^= h >> 16
	h = (h * 0x7feb352d) & 0xffffffff
	h ^= h >> 15
	h = (h * 0x6c8e9cf5) & 0xffffffff
	h ^= h >> 16
	return h

static func h01(s: int, a: int, b: int = 0, c: int = 0) -> float:
	var h := _mix(s ^ 0x5bd1e995)
	h = _mix(h ^ ((a * 73856093) & 0xffffffff))
	h = _mix(h ^ ((b * 19349663) & 0xffffffff))
	h = _mix(h ^ ((c * 83492791) & 0xffffffff))
	return float(h) / 4294967296.0

# ---------------- 破绽画法 ----------------
static func _lum(c: Color) -> float:
	return c.r * 0.3 + c.g * 0.59 + c.b * 0.11

static func _solid(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE and img.get_pixel(x, y).a > 0.5

static func _bg_color(img: Image, r: Rect2i) -> Color:
	# 区域里最常见的浅色（纸面 / 布面 / 瓶身），用来“擦掉”笔画
	var counts: Dictionary = {}
	var best := Color(0.85, 0.78, 0.6)
	var best_n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if c.a < 0.5 or _lum(c) < 0.45:
				continue
			var key := c.to_rgba32()
			counts[key] = int(counts.get(key, 0)) + 1
			if counts[key] > best_n:
				best_n = counts[key]
				best = c
	return best

static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)

static func _tint(img: Image, x: int, y: int, to: Color, k: float) -> void:
	if not _solid(img, x, y):
		return
	var c := img.get_pixel(x, y)
	img.set_pixel(x, y, Color(lerpf(c.r, to.r, k), lerpf(c.g, to.g, k), lerpf(c.b, to.b, k), c.a))

static func apply(img: Image, f: Dictionary, s: int, r: Rect2i) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var before := img.get_region(r)
	_apply_kind(img, f, s, r)
	if not is_benign(f) and before.get_data() == img.get_region(r).get_data():
		# 这块地方上没有能改的笔画 / 边：退一步，撒几粒看得出的杂点，保证破绽真的画上了
		_apply_kind(img, {"kind": "speck"}, s ^ 0x2545f491, r)

static func _apply_kind(img: Image, f: Dictionary, s: int, r: Rect2i) -> void:
	var kind := str(f.get("kind", ""))
	var cx := r.position.x + r.size.x / 2.0
	var cy := r.position.y + r.size.y / 2.0
	match kind:
		"recolor":
			var to := Color(str(f.get("color", "#d8d4cc")))
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					_tint(img, x, y, to, 0.55)
		"yellow":
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(img, x, y) and _lum(img.get_pixel(x, y)) > 0.42:
						_tint(img, x, y, Color("#c29a3c"), 0.42 + 0.12 * h01(s, x, y))
		"whiten":
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(img, x, y) and _lum(img.get_pixel(x, y)) > 0.5 and h01(s, x, y) < 0.45:
						img.set_pixel(x, y, Color("#fbf9f2"))
		"speck":
			var n := maxi(5, floori(r.size.x * r.size.y / 9.0))
			for i in n:
				var x := r.position.x + int(h01(s, i, 1) * r.size.x)
				var y := r.position.y + int(h01(s, i, 2) * r.size.y)
				if _solid(img, x, y):
					img.set_pixel(x, y, Color("#efeae0") if h01(s, i, 3) < 0.6 else Color("#7d7a74"))
		"erase", "thin":
			var bg := _bg_color(img, r)
			var p := 0.75 if kind == "erase" else 0.5
			var any := false
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(img, x, y) and _lum(img.get_pixel(x, y)) < 0.42 and _inside_outline(img, x, y):
						if h01(s, x, y) < p:
							img.set_pixel(x, y, bg if kind == "erase" else img.get_pixel(x, y).lerp(bg, 0.65))
							any = true
			if not any:
				# 区域里没有笔画：画一道歪的假笔画（描出来的字）
				_line(img, Vector2i(r.position.x + 1, int(cy)), Vector2i(r.end.x - 2, int(cy) + 1), Color("#3a2a1e"), s, 0.85)
		"retrace":
			var dark: Array = []
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(img, x, y) and _lum(img.get_pixel(x, y)) < 0.4 and _inside_outline(img, x, y):
						dark.append(Vector2i(x, y))
			for v in dark:
				if h01(s, v.x, v.y) < 0.7 and _solid(img, v.x + 1, v.y + 1) and _lum(img.get_pixel(v.x + 1, v.y + 1)) > 0.4:
					img.set_pixel(v.x + 1, v.y + 1, Color("#2a1d14"))
			if dark.is_empty():
				_line(img, Vector2i(r.position.x + 1, r.position.y + 2), Vector2i(r.end.x - 2, r.end.y - 3), Color("#2a1d14"), s, 1.0)
		"shift":
			var src := img.duplicate()
			var dx := 1 if h01(s, 7) < 0.5 else -1
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(src, x - dx, y + 1) and _solid(img, x, y):
						img.set_pixel(x, y, src.get_pixel(x - dx, y + 1))
		"blur":
			var src2 := img.duplicate()
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if not _solid(src2, x, y):
						continue
					var acc := Color(0, 0, 0, 0)
					var k := 0
					for oy in range(-1, 2):
						for ox in range(-1, 2):
							if _solid(src2, x + ox, y + oy):
								acc += src2.get_pixel(x + ox, y + oy)
								k += 1
					img.set_pixel(x, y, Color(acc.r / k, acc.g / k, acc.b / k, 1.0))
		"seal":
			var hit := false
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if not _solid(img, x, y):
						continue
					var c := img.get_pixel(x, y)
					if c.r > c.g + 0.18 and c.r > c.b + 0.18:
						img.set_pixel(x, y, Color("#ee3b2c") if _lum(c) > 0.22 else Color("#b81d1d"))
						hit = true
			if not hit:
				var w := mini(5, r.size.x - 2)
				var h := mini(5, r.size.y - 2)
				var ox2 := r.position.x + floori((r.size.x - w) / 2.0)
				var oy2 := r.position.y + floori((r.size.y - h) / 2.0)
				for y in range(oy2, oy2 + h):
					for x in range(ox2, ox2 + w):
						if (x == ox2 or y == oy2 or x == ox2 + w - 1 or y == oy2 + h - 1 or (x - ox2 + y - oy2) % 3 == 0) and _solid(img, x, y):
							img.set_pixel(x, y, Color("#ee3b2c"))
		"stain", "watermark":
			var rx := r.size.x / 2.0
			var ry := r.size.y / 2.0
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry).length()
					var edge := 0.78 + 0.22 * h01(s, floori(x / 3.0), floori(y / 3.0))
					if kind == "stain" and d < edge:
						_tint(img, x, y, Color("#7a5528"), 0.32)
					elif kind == "watermark" and d < edge and d > edge - 0.28:
						_tint(img, x, y, Color("#8a6a40"), 0.3)
		"scrape":
			for i in 4:
				var y0 := r.position.y + int(h01(s, i, 4) * r.size.y)
				_line(img, Vector2i(r.position.x, y0), Vector2i(r.end.x - 1, y0 + int(r.size.y * 0.35) - int(h01(s, i, 5) * 4)), Color("#efe6cf"), s + i, 0.8, true)
			var bg2 := _bg_color(img, r)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(img, x, y) and _lum(img.get_pixel(x, y)) < 0.4 and _inside_outline(img, x, y) and h01(s, x, y, 9) < 0.5:
						img.set_pixel(x, y, bg2.lerp(Color("#9a8a70"), 0.35))
		"patch":
			var inset := Rect2i(r.position + Vector2i(2, 2), r.size - Vector2i(4, 4))
			var base := _bg_color(img, r)
			var pc := Color(base.r * 0.86 + 0.08, base.g * 0.9, base.b * 0.8, 1.0)
			for y in range(inset.position.y, inset.end.y):
				for x in range(inset.position.x, inset.end.x):
					if not _solid(img, x, y):
						continue
					var border := x == inset.position.x or y == inset.position.y or x == inset.end.x - 1 or y == inset.end.y - 1
					img.set_pixel(x, y, Color("#3a2a1e") if border and (x + y) % 2 == 0 else pc)
		"stitch", "repair":
			var col := Color("#f2ead0") if kind == "stitch" else Color("#5a3f2a")
			var y1 := int(cy) + int((h01(s, 1) - 0.5) * r.size.y * 0.5)
			for x in range(r.position.x + 1, r.end.x - 1):
				if (x + s) % 3 != 0:
					var yy := y1 + (1 if kind == "repair" and x % 4 == 0 else 0)
					if _solid(img, x, yy):
						img.set_pixel(x, yy, col)
			if kind == "repair":
				for x in range(r.position.x + 2, r.end.x - 2, 3):
					_tint(img, x, y1 - 1, Color("#5a3f2a"), 0.6)
					_tint(img, x, y1 + 1, Color("#5a3f2a"), 0.6)
		"base_metal":
			var metal := Color(str(f.get("color", "#a07f3a")))
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(img, x, y) and _edgy(img, x, y) and h01(s, x, y) < 0.75:
						img.set_pixel(x, y, metal)
		"notch", "chip":
			var big := kind == "notch"
			var best := Vector2i(-1, -1)
			var bd := 1e9
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if _solid(img, x, y) and _edgy(img, x, y):
						var dd := Vector2(x - cx, y - cy).length() + h01(s, x, y) * 2.0
						if dd < bd:
							bd = dd
							best = Vector2i(x, y)
			if best.x >= 0:
				var rad := 2.3 if big else 1.3
				for y in range(best.y - 3, best.y + 4):
					for x in range(best.x - 3, best.x + 4):
						var dist := Vector2(x - best.x, y - best.y).length()
						if dist <= rad and _solid(img, x, y):
							img.set_pixel(x, y, Color(0, 0, 0, 0))
						elif dist <= rad + 1.0 and _solid(img, x, y):
							img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.35))
		"shine":
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					var d2 := Vector2((x + 0.5 - cx) / (r.size.x / 2.0), (y + 0.5 - cy) / (r.size.y / 2.0)).length()
					if d2 < 0.95:
						_tint(img, x, y, Color("#fff4d6"), 0.32 * (1.0 - d2 * 0.6))
		"scuff":
			for i in 3:
				var x0 := r.position.x + int(h01(s, i, 11) * (r.size.x - 4))
				var y0 := r.position.y + int(h01(s, i, 12) * (r.size.y - 2))
				_line(img, Vector2i(x0, y0), Vector2i(x0 + 3 + int(h01(s, i, 13) * 4), y0 + 1), Color("#f3ead2"), s + i, 0.9, true)
		_:
			push_warning("未知的破绽画法：" + kind)

# 只改“画里面”的像素，不碰外轮廓（外轮廓一改，粗看就露馅了）
static func _inside_outline(img: Image, x: int, y: int) -> bool:
	return _solid(img, x - 1, y) and _solid(img, x + 1, y) and _solid(img, x, y - 1) and _solid(img, x, y + 1)

static func _edgy(img: Image, x: int, y: int) -> bool:
	return not (_solid(img, x - 1, y) and _solid(img, x + 1, y) and _solid(img, x, y - 1) and _solid(img, x, y + 1)) \
		or not (_solid(img, x - 2, y) and _solid(img, x + 2, y) and _solid(img, x, y - 2) and _solid(img, x, y + 2))

static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color, s: int, keep: float, tint: bool = false) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var t := float(i) / maxf(1.0, float(n))
		var x := int(round(lerpf(a.x, b.x, t)))
		var y := int(round(lerpf(a.y, b.y, t)))
		if h01(s, i, 77) > keep or not _solid(img, x, y):
			continue
		if tint:
			_tint(img, x, y, c, 0.6)
		else:
			img.set_pixel(x, y, c)

# ---------------- 没有特写图的生成物品：程序画一张底图 ----------------
# 只画大形（衣物、首饰、器物、书画），细节交给破绽画法。同一个 key 永远是同一张图。
static func proc_base(key: String) -> Image:
	var ck := "proc:" + key
	if _sprites.has(ck):
		return (_sprites[ck] as Image).duplicate()
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match key:
		"robe":
			_garment(img, Color("#2f4670"), Color("#1a2440"), true)
		"coat":
			_garment(img, Color("#3d5a86"), Color("#1d2b45"), false)
		"qipao":
			_bolt(img)
		"scarf":
			_scarf(img)
		"bangle":
			_ring(img, Vector2(32, 34), 22.0, 15.0, Color("#c9ccd0"), Color("#5d6168"))
		"jade":
			_jade(img)
		"tinpot":
			_pot(img)
		"clock":
			_clock(img)
		"bowl":
			_bowls(img)
		"landscape":
			_scroll(img, true)
		"calligraphy":
			_scroll(img, false)
		_:
			_box(img, Rect2i(10, 14, 44, 38), Color("#b49a72"), Color("#3a2a1e"))
	_sprites[ck] = img
	return img.duplicate()

static func _box(img: Image, r: Rect2i, fill: Color, line: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var border := x == r.position.x or y == r.position.y or x == r.end.x - 1 or y == r.end.y - 1
			_put(img, x, y, line if border else fill)

static func _shade(img: Image, seed_v: int, k: float) -> void:
	# 布纹 / 纸纹：在实心像素上打一层很淡的确定噪点
	for y in SIZE:
		for x in SIZE:
			if _solid(img, x, y) and _lum(img.get_pixel(x, y)) > 0.12 and _inside_outline(img, x, y):
				var v := h01(seed_v, x, y)
				if v < 0.18:
					img.set_pixel(x, y, img.get_pixel(x, y).darkened(k))
				elif v > 0.9:
					img.set_pixel(x, y, img.get_pixel(x, y).lightened(k * 0.8))

static func _garment(img: Image, fill: Color, line: Color, long_robe: bool) -> void:
	# 平摊开的一件上衣：领口、两只袖子、衣身（长衫拖到底，棉袄短一截）
	var bottom := 60 if long_robe else 50
	for y in range(8, bottom):
		var half := 9 + mini(4, floori((y - 8) / 4.0))
		if not long_robe:
			half += 2
		for x in range(32 - half, 32 + half):
			_put(img, x, y, fill)
	for y in range(11, 25):
		for x in range(3, 61):
			var reach := absf(x - 32.0)
			if reach > 10.0 and y >= 11 + floori(reach / 9.0) and y < 22 + floori(reach / 7.0):
				_put(img, x, y, fill)
	_outline(img, line)
	for x in range(27, 37):
		_put(img, x, 8, Color("#e9dcb8"))
		_put(img, x, 9, Color("#e9dcb8"))
	for y in range(10, bottom - 2):
		_put(img, 32 + floori((y - 10) / 6.0), y, line)
	for y in range(14, bottom - 6, 7):
		_put(img, 34 + floori((y - 10) / 6.0), y, Color("#e9dcb8"))
		_put(img, 35 + floori((y - 10) / 6.0), y, Color("#e9dcb8"))
	if not long_robe:
		for y in range(26, bottom - 2, 5):
			for x in range(23, 41):
				if x % 2 == 0:
					_tint(img, x, y, line, 0.5)
	_shade(img, 31 if long_robe else 37, 0.12)

static func _bolt(img: Image) -> void:
	for i in 3:
		var r := Rect2i(6 + i * 2, 14 + i * 12, 52 - i * 4, 14)
		_box(img, r, Color("#e8c9a8") if i != 1 else Color("#dcb894"), Color("#5a3f2a"))
	# 织花：小朵的花
	for y in range(16, 54, 5):
		for x in range(10 + (y % 2) * 3, 54, 7):
			if _solid(img, x, y) and _inside_outline(img, x, y):
				_put(img, x, y, Color("#b0262a"))
				_put(img, x + 1, y, Color("#d46a5c"))
				_put(img, x, y + 1, Color("#d46a5c"))
				_put(img, x - 1, y, Color("#7a8a4a"))
	_shade(img, 41, 0.08)

static func _scarf(img: Image) -> void:
	for y in range(10, 54):
		for x in range(14, 50):
			var band := (x - 14) + floori((y - 10) / 2.0)
			if band % 18 < 14:
				_put(img, x, y, Color("#8f9399"))
	_outline(img, Color("#3c3f44"))
	for x in range(16, 48, 2):
		for y in range(54, 60):
			_put(img, x, y, Color("#6f7379"))
	_shade(img, 43, 0.14)

static func _ring(img: Image, c: Vector2, ro: float, ri: float, fill: Color, line: Color) -> void:
	for y in SIZE:
		for x in SIZE:
			var d := Vector2((x + 0.5 - c.x) / ro, (y + 0.5 - c.y) / (ro * 0.72)).length()
			var di := Vector2((x + 0.5 - c.x) / ri, (y + 0.5 - c.y) / (ri * 0.62)).length()
			if d <= 1.0 and di > 1.0:
				_put(img, x, y, fill)
	_outline(img, line)
	for a in range(0, 360, 20):
		var p := c + Vector2(cos(deg_to_rad(a)) * (ro + ri) / 2.0, sin(deg_to_rad(a)) * (ro + ri) / 2.0 * 0.68)
		_put(img, int(p.x), int(p.y), Color("#8d929a"))
	for x in range(int(c.x - ro), int(c.x + ro)):
		for y in range(int(c.y - ro), int(c.y)):
			if _solid(img, x, y) and h01(5, x, y) < 0.08:
				_put(img, x, y, Color("#f2f4f6"))

static func _jade(img: Image) -> void:
	for y in range(4, 22):
		_put(img, 32, y, Color("#8a2a24"))
		_put(img, 33, y, Color("#6a1f1a"))
	for y in SIZE:
		for x in SIZE:
			var d := Vector2((x + 0.5 - 32.0) / 16.0, (y + 0.5 - 40.0) / 19.0).length()
			if d <= 1.0:
				_put(img, x, y, Color("#e6ebdc"))
	_outline(img, Color("#6f7a66"))
	for y in range(23, 27):
		for x in range(31, 35):
			_put(img, x, y, Color(0, 0, 0, 0))
	for y in range(30, 56, 3):
		for x in range(22, 44):
			if _solid(img, x, y) and h01(9, x, y) < 0.25 and _inside_outline(img, x, y):
				_put(img, x, y, Color("#cfd8c2"))

static func _pot(img: Image) -> void:
	for y in SIZE:
		for x in SIZE:
			var d := Vector2((x + 0.5 - 30.0) / 18.0, (y + 0.5 - 38.0) / 14.0).length()
			if d <= 1.0:
				_put(img, x, y, Color("#a8acb0"))
	for y in range(20, 26):
		for x in range(22, 38):
			_put(img, x, y, Color("#9a9ea3"))
	for x in range(28, 33):
		_put(img, x, 18, Color("#7c8085"))
		_put(img, x, 19, Color("#7c8085"))
	for i in 12:
		_put(img, 47 + i, 34 - i, Color("#a8acb0"))
		_put(img, 47 + i, 35 - i, Color("#a8acb0"))
		_put(img, 48 + i, 35 - i, Color("#a8acb0"))
	for a in range(-80, 90, 6):
		var p := Vector2(12, 37) + Vector2(cos(deg_to_rad(a + 180)) * 7.0, sin(deg_to_rad(a + 180)) * 9.0)
		_put(img, int(p.x), int(p.y), Color("#7c8085"))
		_put(img, int(p.x) + 1, int(p.y), Color("#7c8085"))
	for x in range(18, 43):
		_put(img, x, 52, Color("#6c7075"))
		_put(img, x, 53, Color("#6c7075"))
	_outline(img, Color("#3c3f44"))
	for x in range(16, 44):
		if x % 3 == 0:
			_put(img, x, 33, Color("#c8ccd0"))
	_shade(img, 47, 0.1)

static func _clock(img: Image) -> void:
	_box(img, Rect2i(14, 6, 36, 54), Color("#7a4a26"), Color("#3a2414"))
	for y in range(6, 12):
		for x in range(14, 50):
			if absi(x - 32) < 18 - (12 - y):
				_put(img, x, y, Color("#8a5630"))
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x + 0.5 - 32.0, y + 0.5 - 24.0).length()
			if d <= 11.0:
				_put(img, x, y, Color("#efe4c8") if d < 10.0 else Color("#c9a24a"))
	for a in range(0, 360, 30):
		var p := Vector2(32, 24) + Vector2(cos(deg_to_rad(a)), sin(deg_to_rad(a))) * 8.0
		_put(img, int(p.x), int(p.y), Color("#3a2414"))
	for i in 7:
		_put(img, 32, 24 - i, Color("#1f1712"))
	for i in 5:
		_put(img, 32 + i, 24, Color("#1f1712"))
	_box(img, Rect2i(24, 38, 16, 16), Color("#2a1a10"), Color("#c9a24a"))
	for y in range(40, 51):
		_put(img, 32, y, Color("#c9a24a"))
	for y in range(49, 53):
		for x in range(30, 35):
			_put(img, x, y, Color("#e0bc5a"))
	_shade(img, 53, 0.1)

static func _bowls(img: Image) -> void:
	for k in 2:
		var ox := 4 + k * 30
		var oy := 18 + k * 14
		for y in range(oy, oy + 16):
			var half := 14 - floori((y - oy) * (y - oy) / 26.0)
			for x in range(ox + 14 - half, ox + 14 + half):
				_put(img, x, y, Color("#f1f0ea"))
		for x in range(ox + 9, ox + 20):
			_put(img, x, oy + 16, Color("#d8d6cc"))
			_put(img, x, oy + 17, Color("#d8d6cc"))
		for x in range(ox + 1, ox + 28):
			if _solid(img, x, oy + 2):
				_put(img, x, oy + 2, Color("#2f5a9a"))
		for i in 4:
			var bx := ox + 6 + i * 5
			_put(img, bx, oy + 7, Color("#2f5a9a"))
			_put(img, bx + 1, oy + 8, Color("#2f5a9a"))
			_put(img, bx - 1, oy + 8, Color("#4a78b8"))
			_put(img, bx, oy + 9, Color("#2f5a9a"))
	_outline(img, Color("#5c5a54"))

static func _scroll(img: Image, landscape: bool) -> void:
	_box(img, Rect2i(14, 4, 36, 56), Color("#e6d8b0"), Color("#6a4a2a"))
	for x in range(10, 54):
		_put(img, x, 4, Color("#4a2e18"))
		_put(img, x, 5, Color("#4a2e18"))
		_put(img, x, 58, Color("#4a2e18"))
		_put(img, x, 59, Color("#4a2e18"))
	if landscape:
		for x in range(18, 46):
			var hgt := 14.0 + 9.0 * sin(x * 0.31) + 5.0 * sin(x * 0.77 + 1.0)
			for y in range(int(46 - hgt), 46):
				if _inside_outline(img, x, y):
					_put(img, x, y, Color("#5a5a50") if y < 46 - hgt + 3 else Color("#a8a690"))
		for x in range(18, 46):
			_put(img, x, 48, Color("#7a8a9a"))
	else:
		for col in 3:
			for row in 6:
				var x0 := 38 - col * 9
				var y0 := 10 + row * 7
				for i in 4:
					_put(img, x0 + i, y0 + (i % 2), Color("#1f1712"))
				_put(img, x0 + 1, y0 + 2, Color("#1f1712"))
				_put(img, x0 + 2, y0 + 3, Color("#1f1712"))
	for y in range(50, 55):
		for x in range(18, 23):
			_put(img, x, y, Color("#a8261e"))
	_shade(img, 59 if landscape else 61, 0.06)

static func _outline(img: Image, line: Color) -> void:
	var src := img.duplicate()
	for y in SIZE:
		for x in SIZE:
			if not _solid(src, x, y):
				continue
			if not (_solid(src, x - 1, y) and _solid(src, x + 1, y) and _solid(src, x, y - 1) and _solid(src, x, y + 1)):
				img.set_pixel(x, y, line)
