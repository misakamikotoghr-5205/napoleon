# 高清界面公用件的无头测试（scripts/cards/ui/hd/：hd_art 找图、hd_theme 样子、hd_placeholder 占位）：
# 清单能读、每项有 kind/id/priority；找不到的图回 null / []、不报错；战场地形都对得上地块贴图；强调色稳定；
# 面板框、按钮、字体、标签都造得出来；占位图能放进场景树、按大小重画；配色键都在 palette.dev.json；
# 这几份脚本守仓库规矩（没有 class_name、没有颜色字面量、字符串字面量只有 ASCII）。
extends SceneTree

const T = preload("res://scripts/tests/cards/lib/card_t.gd")
const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const HdTheme = preload("res://scripts/cards/ui/hd/hd_theme.gd")
const HdPlaceholder = preload("res://scripts/cards/ui/hd/hd_placeholder.gd")
const FieldTerrain = preload("res://scripts/cards/ui/battle/field/field_terrain.gd")
const R = preload("res://scripts/cards/campaign/battle/battle_rules.gd")
const KIT_DIR := "res://scripts/cards/ui/hd"
const PALETTE_DEV := "res://data/cards/theme/palette.dev.json"
const TEMPLATES := "res://data/campaigns/battle_templates.json"
const KINDS := ["bg", "cg", "chara", "face", "unit", "tex", "side", "prop"]
const MISSING := "zz_hd_kit_missing"
const LEGACY_TERRAIN_TEX := {"plain": "grass", "gate": "grass", "eagle": "grass", "road": "road", "high": "rock",
	"village": "village_ground", "woods": "forest_floor", "river": "water", "bridge": "", "ford": "ford",
	"marsh": "marsh", "earthwork": "earthwork_top"}

var t


func _initialize() -> void:
	t = T.new(self, "OCEAN_hd_kit")
	t.run_async(_body)


func _body() -> void:
	_test_list()
	_test_missing()
	_test_terrain()
	_test_void_mesh()
	_test_accent()
	_test_palette_keys()
	_test_theme()
	_test_house_rules()
	await _test_placeholders()


func _test_list() -> void:
	var d := HdArt.data()
	t.ok(d.has("kinds") and d.has("assets"), "art_list has kinds and assets")
	for k in KINDS:
		t.ok(d.get("kinds", {}).has(k), "art_list kinds has " + k)
	var assets := HdArt.assets()
	t.ok(assets.size() >= 100, "art_list lists the HD assets (%d)" % assets.size())
	var seen := {}
	for a in assets:
		var kind := str(a.get("kind", ""))
		var id := str(a.get("id", ""))
		t.ok(kind in KINDS, "asset %s has a known kind '%s'" % [id, kind])
		t.ok(id != "" and RegEx.create_from_string("^[a-z0-9_]+$").search(id) != null, "asset id '%s' is lowercase" % id)
		t.ok(str(a.get("priority", "")) in ["P0", "P1", "P2"], "asset %s:%s has a priority" % [kind, id])
		t.ok(not seen.has(kind + ":" + id), "asset %s:%s listed once" % [kind, id])
		seen[kind + ":" + id] = true
		t.eq(HdArt.entry(kind, id).get("id", ""), id, "entry(%s, %s)" % [kind, id])
	t.ok(HdArt.entry("bg", MISSING).is_empty(), "entry of an unknown id is empty")
	t.ok(HdArt.entry("face", "jamestown_shop").is_empty(), "entry is per kind")
	t.ok(HdArt.display_name("bg", "jamestown_shop") != "jamestown_shop", "display_name reads the entry name")
	t.eq(HdArt.display_name("bg", MISSING), MISSING, "display_name of an unknown id is the id")
	t.eq(HdArt.assets("tex").size() + HdArt.assets("side").size(), 11, "nine tile tops and two sides")


func _test_missing() -> void:
	t.ok(HdArt.bg(MISSING) == null, "missing bg is null")
	t.ok(HdArt.bg(MISSING, "night") == null, "missing bg variant is null")
	t.ok(HdArt.cg(MISSING) == null, "missing cg is null")
	t.ok(HdArt.chara(MISSING) == null, "missing chara is null")
	t.ok(HdArt.chara(MISSING, "angry") == null, "missing chara expression falls back and is still null")
	t.ok(HdArt.face(MISSING) == null, "missing face is null")
	t.eq(HdArt.unit_frames(MISSING, "idle"), [], "missing unit frames are []")
	t.ok(HdArt.tile_tex(MISSING) == null, "missing tile texture is null")
	t.ok(HdArt.prop(MISSING) == null, "missing prop is null")
	for bad in ["../project", "a/b", "Upper", "", "x.y"]:
		t.ok(HdArt.bg(bad) == null and HdArt.face(bad) == null, "unsafe id '%s' resolves to nothing" % bad)
	t.ok(not HdArt.has_art("bg", MISSING), "has_art is false for a missing bg")
	t.eq(HdArt.unit_meta(MISSING), {"fps": 12, "attack_hit_frame": 1}, "unit_meta defaults")
	t.eq(HdArt.unit_anchor(), Vector2(192, 336), "unit anchor from kinds.unit.anchor")
	t.eq(HdArt.unit_size(), Vector2(384, 384), "unit size from kinds.unit.size")
	# A second round hits the miss cache and is still quiet.
	t.ok(HdArt.bg(MISSING) == null and HdArt.face(MISSING) == null, "cached misses stay null")
	# Whatever art exists today must resolve to the right types (none is required yet).
	for a in HdArt.assets("bg"):
		var tex := HdArt.bg(str(a["id"]))
		t.ok(tex == null or tex is Texture2D, "bg %s is a texture or null" % a["id"])
	for a in HdArt.assets("unit"):
		for f in HdArt.unit_frames(str(a["id"]), "idle"):
			t.ok(f is Texture2D, "unit frame of %s is a texture" % a["id"])
	HdArt.clear_cache()
	t.ok(HdArt.face(MISSING) == null, "clear_cache keeps the resolver quiet")


func _test_terrain() -> void:
	var used := {"earthwork": true}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TEMPLATES))
	t.ok(typeof(parsed) == TYPE_DICTIONARY, "battle templates load")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for tid in parsed.get("templates", {}):
		var tpl: Dictionary = parsed["templates"][tid]
		for row in tpl.get("map", []):
			for ch in str(row):
				used[str(R.TERRAIN_CHARS.get(ch, "?"))] = true
		for ev in tpl.get("events", []):
			used[str(ev.get("terrain", "?"))] = true
	t.ok(not used.has("?"), "every template cell is a known terrain")
	var listed := {}
	for a in HdArt.assets("tex"):
		for part in str(a.get("terrain", "")).split(","):
			listed[part.strip_edges()] = true
	for terrain in used:
		t.ok(R.TERRAIN.has(terrain), "used template terrain has rules: " + str(terrain))
	# The original twelve mappings remain unchanged, including the bridge prop over water.
	for terrain in LEGACY_TERRAIN_TEX:
		t.eq(HdArt.terrain_tex(terrain), LEGACY_TERRAIN_TEX[terrain], "legacy texture mapping: " + str(terrain))
	# Inspect the actual field material for every rule terrain, not a growing exception list.
	for terrain in R.TERRAIN:
		var tex := HdArt.terrain_tex(terrain)
		if listed.has(terrain):
			t.ok(tex != "" and not HdArt.entry("tex", tex).is_empty(), "terrain %s maps to a tile texture" % terrain)
			t.ok(str(HdArt.entry("tex", tex).get("terrain", "")).contains(terrain), "%s lists terrain %s" % [tex, terrain])
		if terrain == "void":
			t.eq(FieldTerrain.tex_id(terrain), "", "void has no tile surface")
			continue
		var field_tex := FieldTerrain.tex_id(terrain)
		t.ok(not HdArt.entry("tex", field_tex).is_empty(), "renderer uses a registered tile for " + str(terrain))
		if terrain != "bridge":
			t.eq(tex, field_tex, "minimap and battlefield share the tile for " + str(terrain))
		var material := FieldTerrain.top_material(field_tex, 0.0, CardTheme.color)
		var image: Texture2D = material.get_shader_parameter(&"tex")
		t.ok(image != null and image.get_width() > 0 and image.get_height() > 0, "rendered tile material is visible: " + str(terrain))
		t.ok(is_finite(FieldTerrain.top_of(terrain)) and FieldTerrain.top_of(terrain) > FieldTerrain.BASE_Y,
			"rendered tile has a safe height: " + str(terrain))
	t.eq(HdArt.terrain_tex("sea"), HdArt.terrain_tex("river"), "sea retains a water placeholder")
	t.eq(HdArt.terrain_tex(MISSING), "", "unknown terrain -> empty")


func _test_void_mesh() -> void:
	var field := Node3D.new()
	var cells := [{"col": 0, "row": 0, "terrain": "void"}]
	FieldTerrain.build(field, cells, 1, 1, FieldTerrain.heights(cells, 1, 1), CardTheme.color)
	t.eq(field.get_child_count(), 0, "void produces neither a top nor side mesh")
	field.free()
	field = Node3D.new()
	cells = [{"col": 0, "row": 0, "terrain": "plain"}, {"col": 1, "row": 0, "terrain": "void"},
		{"col": 2, "row": 0, "terrain": "plain"}]
	FieldTerrain.build(field, cells, 3, 1, FieldTerrain.heights(cells, 3, 1), CardTheme.color)
	var top := field.get_node("Top_grass") as MeshInstance3D
	var side := field.get_node("Side_side_earth") as MeshInstance3D
	t.eq(top.mesh.surface_get_array_len(0), 12, "an irregular board draws only its two real top tiles")
	t.eq(side.mesh.surface_get_array_len(0), 48, "both real tiles have four sides, including the void boundary")
	var vertices: PackedVector3Array = side.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex in vertices:
		t.ok(is_equal_approx(vertex.y, FieldTerrain.GROUND) or is_equal_approx(vertex.y, FieldTerrain.BASE_Y),
			"void-facing sides extend down to the board base")
	field.free()


func _test_accent() -> void:
	var seen := {}
	for a in HdArt.assets():
		var id := str(a["id"])
		var i := HdArt.accent_index(id)
		t.ok(i >= 0 and i < HdArt.ACCENT_COUNT, "accent index of %s in range" % id)
		t.eq(HdArt.accent(id), HdArt.accent(id), "accent of %s is stable" % id)
		t.eq(HdArt.accent(id), HdTheme.color("hd_accent_%d" % i), "accent of %s comes from the ramp" % id)
		if id.begins_with("enemy_"):
			t.ok(i in [2, 11], "enemy %s gets a red accent" % id)
		if str(a["kind"]) == "chara":
			seen[i] = true
	t.ok(seen.size() >= 8, "story characters spread over the accent ramp (%d)" % seen.size())
	t.eq(HdArt.accent_index("villefort"), 0, "the hero is gold")
	t.eq(HdArt.accent_index(MISSING), HdArt.accent_index(MISSING), "unknown ids are stable too")


func _test_palette_keys() -> void:
	var colors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_DEV)).get("colors", {})
	var re := RegEx.create_from_string("(?<![&\\w])\"(hd_[a-z0-9_]+)\"")   # &"hd_…" is a meta name
	for path in _kit_files():
		for m in re.search_all(_strip_comments(FileAccess.get_file_as_string(path))):
			var key := m.get_string(1)
			if key.ends_with("_"):
				continue
			t.ok(colors.has(key), "%s: palette key %s exists" % [path.get_file(), key])
	for mood in HdPlaceholder.MOODS:
		for part in ["top", "mid", "bottom", "glow", "line"]:
			t.ok(colors.has("hd_mood_%s_%s" % [mood, part]), "palette has hd_mood_%s_%s" % [mood, part])
	for i in HdArt.ACCENT_COUNT:
		t.ok(colors.has("hd_accent_%d" % i), "palette has hd_accent_%d" % i)
	for a in HdArt.assets("tex") + HdArt.assets("side"):
		t.ok(colors.has("hd_tile_" + str(a["id"])) and colors.has("hd_tile_%s_dark" % a["id"]),
			"palette has tile colours for " + str(a["id"]))
	for spec in HdTheme.PANELS.values():
		_spec_keys(colors, spec)
	for b in HdTheme.BUTTONS.values():
		for state in ["normal", "hover", "pressed", "disabled"]:
			_spec_keys(colors, b[state])
		for k in b["ink"]:
			t.ok(colors.has(str(k)), "palette has button ink " + str(k))


func _spec_keys(colors: Dictionary, spec: Dictionary) -> void:
	for field in ["fill", "edge", "inner", "glow"]:
		if spec.has(field):
			var c: Array = spec[field]
			t.ok(colors.has(str(c[0])), "palette has %s" % c[0])
			if field == "fill" and c.size() >= 4:
				t.ok(colors.has(str(c[2])), "palette has %s" % c[2])


func _test_theme() -> void:
	t.eq(HdTheme.color("gold"), HdTheme.color("hd_gold"), "color() adds the hd_ prefix")
	t.ok(is_equal_approx(HdTheme.alpha("hd_gold", 0.5).a, 0.5), "alpha() scales alpha")
	t.ok(HdTheme.color("hd_glass").a > 0.75 and HdTheme.color("hd_glass").a < 0.9, "glass is translucent")
	for kind in ["serif", "sans", "title", "sans_bold", "num"]:
		var f := HdTheme.font(kind)
		t.ok(f != null and f.get_height(20) > 0.0, "font %s builds" % kind)
		t.ok(HdTheme.font(kind) == f, "font %s is cached" % kind)
		t.ok(f.has_char(0x5F53) or _fallback_has(f, 0x5F53), "font %s covers CJK" % kind)
	t.ok(HdTheme.font("serif", 3) != HdTheme.font("serif"), "spaced font is its own variation")
	for kind in HdTheme.PANEL_KINDS:
		var sb := HdTheme.panel_box(kind)
		t.ok(sb is StyleBox, "panel_box %s builds" % kind)
		t.ok(sb != HdTheme.panel_box(kind), "panel_box %s is a fresh instance" % kind)
		t.ok(sb.get_minimum_size().x > 0.0, "panel_box %s has content margins" % kind)
	for kind in ["glass", "textbox", "card_selected"]:
		var hb = HdTheme.panel_box(kind)
		t.ok(hb.has_method("outer") and hb.outer() is StyleBoxFlat and hb.inner() is StyleBoxFlat,
			"panel_box %s has a double gold border" % kind)
	for kind in HdTheme.BUTTON_KINDS:
		var b := Button.new()
		HdTheme.apply_button(b, kind)
		for s in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
			t.ok(b.has_theme_stylebox_override(s), "button %s has %s" % [kind, s])
		t.ok(b.has_theme_font_override(&"font") and b.has_theme_color_override(&"font_hover_color"),
			"button %s has font and colours" % kind)
		t.eq(b.get_meta(&"hd_button", ""), kind, "button %s is tagged" % kind)
		b.free()
	var choice := Button.new()
	HdTheme.apply_button(choice, "choice")
	t.ok(choice.custom_minimum_size.x >= 520.0, "choice buttons are wide")
	choice.free()
	var l := HdTheme.make_label("1815", 22, "serif", "hd_gold_hi")
	t.eq(l.text, "1815", "make_label text")
	t.eq(l.get_theme_color(&"font_color"), HdTheme.color("hd_gold_hi"), "make_label colour")
	t.eq(l.get_theme_font_size(&"font_size"), 22, "make_label size")
	l.free()
	var c := Control.new()
	HdTheme.apply_hd_filter(c)
	t.eq(c.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "apply_hd_filter sets linear + mipmaps")
	c.free()


func _fallback_has(f: Font, code: int) -> bool:
	for fb in f.fallbacks:
		if fb.has_char(code) or _fallback_has(fb, code):
			return true
	var base = f.get("base_font")
	return base is Font and ((base as Font).has_char(code) or _fallback_has(base, code))


func _test_placeholders() -> void:
	var host := Control.new()
	host.size = Vector2(1280, 720)
	root.add_child(host)
	var nodes: Array = []
	for mood in HdPlaceholder.MOODS:
		var bgc := HdPlaceholder.bg_control("probe_" + mood, "1815", "1817", mood)
		host.add_child(bgc)
		nodes.append(bgc)
		t.ok(HdPlaceholder.is_placeholder(bgc), "bg_control %s is a placeholder" % mood)
	for a in HdArt.assets("bg"):
		var id := str(a["id"])
		var n := HdPlaceholder.make_bg(id)
		host.add_child(n)
		nodes.append(n)
		t.eq(HdPlaceholder.is_placeholder(n), HdArt.bg(id) == null, "make_bg %s uses the real art when present" % id)
		t.ok(HdPlaceholder.mood_for(id) in HdPlaceholder.MOODS, "bg %s has a mood" % id)
	for a in HdArt.assets("cg"):
		var n := HdPlaceholder.make_cg(str(a["id"]))
		host.add_child(n)
		nodes.append(n)
	for a in HdArt.assets("chara"):
		var id := str(a["id"])
		for expr in ["normal", "smile", "angry", "sad", "surprise"]:
			var n := HdPlaceholder.make_chara(id, "", expr)
			n.size = Vector2(300, 450)
			host.add_child(n)
			nodes.append(n)
			t.eq(HdPlaceholder.is_placeholder(n), HdArt.chara(id, expr) == null, "make_chara %s %s" % [id, expr])
	for a in HdArt.assets("face"):
		var n := HdPlaceholder.make_face(str(a["id"]))
		n.size = Vector2(96, 96)
		host.add_child(n)
		nodes.append(n)
	# Odd and tiny sizes must draw without engine errors (degenerate polygons are skipped).
	for sz in [Vector2(1, 1), Vector2(6, 4), Vector2(12, 18), Vector2(24, 36), Vector2(40, 22), Vector2(90, 30)]:
		for n in [HdPlaceholder.bg_control("dusk_probe", "1815", "", "dusk"),
				HdPlaceholder.chara_control("napoleon", "1815", "smile"), HdPlaceholder.face_control("gourgaud", ""),
				HdPlaceholder.chara_control("gourgaud", "", "angry"), HdPlaceholder.chara_control("marie", "", "sad")]:
			n.set_anchors_preset(Control.PRESET_TOP_LEFT)
			n.size = sz
			host.add_child(n)
			nodes.append(n)
	var tiny := HdPlaceholder.chara_control("marie", "", "angry")
	host.add_child(tiny)
	nodes.append(tiny)
	HdPlaceholder.set_chara_expr(tiny, "marie", "sad")
	t.eq(tiny.get("expr"), "sad", "set_chara_expr changes a placeholder's expression")
	tiny.set("show_name", false)
	t.eq(tiny.get("show_name"), false, "a chara placeholder can hide its name")
	var faded: Control = nodes[0]
	faded.set("title_alpha", 0.0)
	t.eq(faded.get("title_alpha"), 0.0, "a bg placeholder can fade its title out")
	t.eq(HdPlaceholder.mood_for("zz_new_night_harbour"), "night", "unknown bg ids guess a mood from their words")
	t.eq(HdPlaceholder.mood_for("zz_new_night_harbour"), HdPlaceholder.mood_for("zz_new_night_harbour"), "mood is stable")
	await t.frames(3)
	for n in nodes:
		t.ok(n.is_inside_tree() and n.mouse_filter == Control.MOUSE_FILTER_IGNORE, "placeholder in tree, ignores mouse")
		t.ok(n.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "placeholder uses linear + mipmaps")
	t.eq(nodes[0].size, Vector2(1280, 720), "bg placeholder fills its parent")
	host.size = Vector2(1920, 1080)
	await t.frames(2)
	t.eq(nodes[0].size, Vector2(1920, 1080), "bg placeholder follows its parent's size")
	for a in HdArt.assets("tex") + HdArt.assets("side"):
		var tex := HdPlaceholder.make_tile_tex(str(a["id"]))
		t.ok(tex is Texture2D and tex.get_width() > 0, "tile texture for %s" % a["id"])
	t.ok(HdPlaceholder.tile_texture("grass") == HdPlaceholder.tile_texture("grass"), "tile placeholder is cached")
	t.eq(HdPlaceholder.tile_texture("side_earth").get_height(), HdPlaceholder.TILE_NOISE >> 1, "side textures are 2:1")
	host.queue_free()
	await t.frames(2)


## 仓库规矩：没有 class_name；颜色只走配色键（不写 Color(…)/Color8/Color.html）；字符串字面量只有 ASCII
func _test_house_rules() -> void:
	var files := _kit_files()
	t.ok(files.size() >= 7, "the HD kit scripts are there (%d)" % files.size())
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		var code := _strip_comments(src)
		t.ok(RegEx.create_from_string("(?m)^class_name\\s").search(code) == null, path + ": no class_name")
		t.ok(not RegEx.create_from_string("Color\\s*\\(|Color8\\s*\\(|Color\\.html|Color\\.from_").search(code),
			path + ": no colour literals")
		for lit in _strings(src):
			var ascii := true
			for i in lit.length():
				if lit.unicode_at(i) > 127:
					ascii = false
			t.ok(ascii, "%s: ASCII string literal '%s'" % [path.get_file(), lit])


func _kit_files() -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(KIT_DIR):
		if f.ends_with(".gd"):
			out.append(KIT_DIR + "/" + f)
	out.sort()
	return out


## 去掉注释（# 到行尾，字符串里的 # 不算）
func _strip_comments(src: String) -> String:
	var out := ""
	var in_str := false
	var i := 0
	while i < src.length():
		var c := src.unicode_at(i)
		if in_str and c == 92:
			out += src.substr(i, 2)
			i += 2
			continue
		if c == 34:
			in_str = not in_str
		if c == 35 and not in_str:
			while i < src.length() and src.unicode_at(i) != 10:
				i += 1
			continue
		out += src.substr(i, 1)
		i += 1
	return out


## 双引号字符串字面量（注释里的不算）
func _strings(src: String) -> PackedStringArray:
	var out := PackedStringArray()
	var code := _strip_comments(src)
	var re := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
	for m in re.search_all(code):
		out.append(m.get_string(1))
	return out
