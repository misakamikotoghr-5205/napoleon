# 3D 战场上的一个单位（我方或敌人）：有 art/hd/unit/<id>/ 的逐帧图就是一张竖直、绕 Y 轴朝向相机的 Sprite3D
# （脚底锚点 (192,336) 落在格子中心，朝左时水平翻转，按 meta.json 的帧率播放），没有就是 field_props 搭的兵人。
# 脚下一团软影子和一圈阵营色的圈（我方蓝、主角金、敌人红、精英金边红圈）；我方脚前有一个金色朝向箭头。
# 动画都是小补间：出场落下、移动滑过去、攻击前冲、挨打闪红、倒下沉没；逻辑不等动画（测试、无头都不受影响）。
# 没有 class_name，board preload 它。
extends Node3D

const HdArt = preload("res://scripts/cards/ui/hd/hd_art.gd")
const Sh = preload("res://scripts/cards/ui/battle/field/field_shaders.gd")
const Props = preload("res://scripts/cards/ui/battle/field/field_props.gd")
const Cam = preload("res://scripts/cards/ui/battle/field/field_cam.gd")

const SPRITE_H := 1.3        # 一帧 384 像素高对应的世界高度
const HEAD_FRAC := 0.7       # 画里头顶离脚底约占一帧高的多少（规则：人高 200–260 像素）
const RING_D := 0.74          # 阵营圈直径
const YAW := {"right": 0.0, "left": 180.0, "up": 90.0, "down": -90.0}

var key := ""
var side := "ally"
var art_id := ""
var facing := "right"
var dying := false
var doomed := false
var token_scale := 1.0
var head := 0.95              # 头顶（含帽子）离脚底的高度，叠加层把血条放在这上面
var sprite: Sprite3D = null
var figure: Node3D = null
var ring: MeshInstance3D = null
var shadow: MeshInstance3D = null
var arrow: MeshInstance3D = null
var _ring_spec: Dictionary = {}
var _frames: Dictionary = {}
var _anim := "idle"
var _loop := true
var _fps := 12
var _t := 0.0
var _flash: StandardMaterial3D = null
var _grey: StandardMaterial3D = null
var _move: Tween = null
var _fx: Tween = null
var _idle: Tween = null
var _colors: Callable
## setup 时的缩放和头顶高度：之后同一格敌人多了 / 少了只改整个节点的 scale（set_token_scale），不重建
var _scale0 := 1.0
var _head0 := 0.95
var _rescale: Tween = null


## info：side kind cls ekind accent elite heavy；props 是 field_props 实例；colors 是取配色的函数
func setup(p_key: String, info: Dictionary, art: String, props, colors: Callable, scale_k: float) -> void:
	key = p_key
	side = str(info.get("side", "ally"))
	art_id = art
	token_scale = scale_k
	_colors = colors
	name = "Unit_" + p_key.replace(":", "_")
	var idle := HdArt.unit_frames(art_id, "idle") if art_id != "" else []
	if not idle.is_empty():
		_frames["idle"] = idle
		for st in ["attack", "hit", "down", "dying"]:
			_frames[st] = HdArt.unit_frames(art_id, st)
		_fps = int(HdArt.unit_meta(art_id).get("fps", 12))
		sprite = Sprite3D.new()
		sprite.name = "Sprite"
		sprite.texture = idle[0]
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.shaded = false
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var us := HdArt.unit_size()
		var anchor := HdArt.unit_anchor()
		sprite.pixel_size = SPRITE_H / maxf(us.y, 1.0) * scale_k
		sprite.offset = Vector2(us.x * 0.5 - anchor.x, anchor.y - us.y * 0.5)
		# 竖直的纸片从斜上方看会被压扁（cos 俯角），竖向拉回来，屏幕上和画里的比例一样
		var stretch := 1.0 / cos(deg_to_rad(Cam.PITCH_DEG))
		sprite.scale = Vector3(1.0, stretch, 1.0)
		add_child(sprite)
		head = SPRITE_H * scale_k * HEAD_FRAC * stretch
	else:
		figure = props.figure(info)
		figure.scale = Vector3.ONE * scale_k
		add_child(figure)
		head = _figure_head(info) * scale_k
	var fs := 0.86 if str(info.get("cls", "")) in ["hussar"] or str(info.get("ekind", "")) in ["dragoon", "gun", "wagon"] else 0.62
	shadow = Sh.mark_node({"shape": Sh.DISC, "fill": colors.call("bt3d_shadow"), "radius": 0.25}, 1,
		Vector3(0, 0.006, 0), fs * scale_k, 0.5 * scale_k)
	add_child(shadow)
	_ring_spec = _ring_style(info)
	ring = Sh.mark_node(_ring_spec, 3, Vector3(0, 0.01, 0), RING_D * scale_k, RING_D * scale_k)
	add_child(ring)
	if side == "ally" and str(info.get("cls", "")) != "barricade":
		arrow = Sh.mark_node({"shape": Sh.ARROW, "fill": colors.call("bt3d_facing")}, 4, Vector3.ZERO, 0.16, 0.24)
		add_child(arrow)
	_scale0 = scale_k
	_head0 = head
	set_facing("left" if side == "enemy" else "right")
	set_process(sprite != null and _frames_count("idle") > 1)


## 同一格的敌人多了 / 少了：换个大小，节点留着（走位、挨打飘字、倒下都还接得上）。animate 时 0.3 秒缩放过去
func set_token_scale(scale_k: float, animate: bool) -> void:
	if is_equal_approx(scale_k, token_scale):
		return
	token_scale = scale_k
	var ratio := scale_k / maxf(_scale0, 0.01)
	head = _head0 * ratio
	if _rescale != null and _rescale.is_valid():
		_rescale.kill()
	if not animate or not _anims_on():
		scale = Vector3.ONE * ratio
		return
	_rescale = create_tween()
	_rescale.tween_property(self, "scale", Vector3.ONE * ratio, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## 兵人头顶（含帽子）的高度：站着的兵约 0.64 个兵人单位，骑兵 0.74，炮和车 0.52，再乘兵人的放大
func _figure_head(info: Dictionary) -> float:
	var fs: float = Props.FIG_SCALE
	if str(info.get("cls", "")) == "barricade":
		return 0.4
	if str(info.get("cls", "")) == "hussar" or str(info.get("ekind", "")) == "dragoon":
		return 0.74 * fs
	if str(info.get("cls", "")) == "artillery" or str(info.get("ekind", "")) in ["gun", "wagon"]:
		return 0.52 * fs
	return 0.66 * fs


func _ring_style(info: Dictionary) -> Dictionary:
	var kind := str(info.get("kind", ""))
	var edge_key := "bt3d_ring_ally"
	var fill_key := "bt3d_ring_ally_fill"
	if side == "enemy":
		edge_key = "bt3d_ring_elite" if bool(info.get("elite", false)) else "bt3d_ring_enemy"
		fill_key = "bt3d_ring_enemy_fill"
	elif kind == "hero":
		edge_key = "bt3d_ring_hero"
	elif kind == "companion":
		edge_key = "bt3d_ring_companion"
	var w := 0.11 if bool(info.get("elite", false)) or bool(info.get("heavy", false)) else 0.075
	return {"shape": Sh.RING, "edge": _colors.call(edge_key), "fill": _colors.call(fill_key), "edge_w": w, "glow": 1.0}


func _frames_count(st: String) -> int:
	return (_frames.get(st, []) as Array).size()


# ---------------- 状态 ----------------

func set_facing(dir: String) -> void:
	facing = dir if YAW.has(dir) else "right"
	if figure != null:
		figure.rotation_degrees = Vector3(0, float(YAW[facing]), 0)
	if sprite != null and facing in ["left", "right"]:
		sprite.flip_h = facing == "left"
	if arrow != null:
		var d := _dir_vec(facing)
		arrow.position = Vector3(d.x * 0.44, 0.014, d.z * 0.44) * _scale0
		arrow.rotation_degrees = Vector3(0, float(YAW[facing]), 0)


func set_dying(on: bool) -> void:
	if on == dying:
		return
	dying = on
	if arrow != null:
		arrow.visible = not on
	if sprite != null:
		sprite.modulate = _colors.call("bt3d_dying_tint") if on else _colors.call("hd_white")
		_play("dying" if on else "idle", true)
	if figure != null:
		var body := figure.get_node_or_null("Body") as Node3D
		if body != null:
			body.rotation_degrees = Vector3(28.0 if on else 0.0, 0, -16.0 if on else 0.0)
			body.position = Vector3(0, -0.05 if on else 0.0, 0)
		_set_overlay(_grey_mat() if on else null)
	_update_ring()


func set_doomed(on: bool) -> void:
	if on == doomed:
		return
	doomed = on
	_update_ring()


func _update_ring() -> void:
	if ring == null:
		return
	var m := ring.material_override as ShaderMaterial
	if doomed:
		m.set_shader_parameter(&"edge", _colors.call("bt3d_doomed"))
		m.set_shader_parameter(&"fill", _colors.call("bt3d_doomed_fill"))
		m.set_shader_parameter(&"pulse", 0.55)
	elif dying:
		m.set_shader_parameter(&"edge", _colors.call("bt3d_ring_dying"))
		m.set_shader_parameter(&"fill", _colors.call("bt3d_ring_enemy_fill"))
		m.set_shader_parameter(&"pulse", 0.0)
	else:
		m.set_shader_parameter(&"edge", _ring_spec["edge"])
		m.set_shader_parameter(&"fill", _ring_spec["fill"])
		m.set_shader_parameter(&"pulse", 0.0)


# ---------------- 动画 ----------------

func _anims_on() -> bool:
	return is_inside_tree() and DisplayServer.get_name() != "headless"


## 出场：从上面落下来、由小变大
func appear() -> void:
	if not _anims_on():
		return
	var body := _visual()
	if body == null:
		return
	var s0 := body.scale
	body.scale = s0 * 0.4
	body.position.y = 0.5
	_fx = create_tween().set_parallel(true)
	_fx.tween_property(body, "scale", s0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fx.tween_property(body, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_start_idle()


func _visual() -> Node3D:
	return sprite if sprite != null else figure


## 待机：轻轻起伏（只在有画面的时候跑，无头模式不建补间）
func _start_idle() -> void:
	if not _anims_on() or _idle != null or figure == null:
		return
	var body := figure.get_node_or_null("Body") as Node3D
	if body == null:
		return
	var base := body.scale
	_idle = create_tween().set_loops()
	var dur := 1.4 + fmod(float(absi(key.hash()) % 100) * 0.007, 0.6)
	_idle.tween_property(body, "scale", Vector3(base.x * 1.0, base.y * 1.035, base.z * 1.0), dur).set_trans(Tween.TRANS_SINE)
	_idle.tween_property(body, "scale", base, dur).set_trans(Tween.TRANS_SINE)


func move_to(pos: Vector3, animate: bool) -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	if not animate or not _anims_on() or position.distance_to(pos) < 0.001:
		position = pos
		return
	_move = create_tween()
	_move.tween_property(self, "position", pos, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## 攻击：往 dir 方向前冲一下再回来（逐帧图播一遍 attack）
func play_attack(dir: Vector3) -> void:
	if not _anims_on():
		return
	_play("attack", false)
	var v := _visual()
	if v == null:
		return
	var d := Vector3(dir.x, 0, dir.z).normalized() * 0.2
	var t := create_tween()
	t.tween_property(v, "position", v.position + d, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(v, "position", Vector3(0, v.position.y, 0) if sprite == null else v.position, 0.2)


## 挨打：闪一下红、往后一抖
func play_hit() -> void:
	if not _anims_on():
		return
	_play("hit", false)
	if sprite != null:
		var t := create_tween()
		t.tween_property(sprite, "modulate", _colors.call("bt3d_flash"), 0.06)
		t.tween_property(sprite, "modulate", _colors.call("bt3d_dying_tint") if dying else _colors.call("hd_white"), 0.25)
		return
	if figure == null:
		return
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash.albedo_color = _colors.call("bt3d_flash")
	_set_overlay(_flash)
	var c: Color = _colors.call("bt3d_flash")
	_flash.albedo_color = c
	var t2 := create_tween()
	var faded := c
	faded.a = 0.0
	t2.tween_property(_flash, "albedo_color", faded, 0.32)
	t2.tween_callback(func() -> void: _set_overlay(_grey_mat() if dying else null))
	var shake := create_tween()
	shake.tween_property(figure, "position:x", -0.05, 0.05)
	shake.tween_property(figure, "position:x", 0.0, 0.12)


## 倒下：沉下去、缩小，然后把自己删掉
func play_down() -> void:
	if not _anims_on():
		queue_free()
		return
	_play("down", false)
	if ring != null:
		ring.visible = false
	if arrow != null:
		arrow.visible = false
	var t := create_tween().set_parallel(true)
	var v := _visual()
	if v != null:
		t.tween_property(v, "scale", v.scale * 0.15, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(v, "position:y", -0.2, 0.4)
	if shadow != null:
		t.tween_property(shadow, "scale", Vector3(0.01, 1, 0.01), 0.4)
	t.chain().tween_callback(queue_free)


func _set_overlay(m: Material) -> void:
	if figure == null:
		return
	for n in figure.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_overlay = m


func _grey_mat() -> StandardMaterial3D:
	if _grey == null:
		_grey = StandardMaterial3D.new()
		_grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_grey.albedo_color = _colors.call("bt3d_dying_overlay")
	return _grey


# ---------------- 逐帧 ----------------

func _play(st: String, loop: bool) -> void:
	if sprite == null:
		return
	if _frames_count(st) == 0:
		st = "dying" if dying and _frames_count("dying") > 0 else "idle"
		loop = true
	_anim = st
	_loop = loop
	_t = 0.0
	sprite.texture = (_frames[st] as Array)[0]
	set_process(true)


func _process(delta: float) -> void:
	if sprite == null:
		set_process(false)
		return
	var fr: Array = _frames.get(_anim, [])
	if fr.is_empty():
		set_process(false)
		return
	_t += delta
	var i := int(_t * _fps)
	if i >= fr.size():
		if _loop:
			i = i % fr.size()
		elif _anim == "down":
			i = fr.size() - 1
		else:
			_play("dying" if dying else "idle", true)
			return
	sprite.texture = fr[i]
	if _loop and fr.size() <= 1:
		set_process(false)


static func _dir_vec(dir: String) -> Vector3:
	match dir:
		"left": return Vector3(-1, 0, 0)
		"up": return Vector3(0, 0, -1)
		"down": return Vector3(0, 0, 1)
	return Vector3(1, 0, 0)
