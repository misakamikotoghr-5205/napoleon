# 3D 战场用的两份着色器（GL Compatibility 能跑）：地块顶面（贴图 + 每格明暗微差 + 格线 + 水面流动）和
# 地面记号（部署格、目标、射程、选中、悬停、路线点、敌人移动箭头、炮击准星、小人脚下的阵营圈和影子）。
# 记号全用有符号距离场 + fwidth 抗锯齿画，任何分辨率都是平滑的。颜色一律由调用方从配色键传 uniform 进来。
# 没有 class_name，preload。
extends RefCounted

## 记号形状（mark 着色器的 shape uniform）
const CELL := 0      # 圆角格：填充 + 边框（可虚线）+ 内发光
const DISC := 1      # 软边圆（影子、光斑）
const RING := 2      # 阵营圈：圆环 + 外发光 + 淡填充
const CROSS := 3     # 炮击准星
const LINE := 4      # 路径带：uv.x 是沿路长度（世界单位），uv.y 横向 0..1；dash>0 虚线，dash<0 圆点
const ARROW := 5     # 三角箭头：尖在 uv.x = 1

static var _top: Shader = null
static var _mark: Shader = null

const TOP_CODE := """
shader_type spatial;
render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 grid_col : source_color = vec4(0.0, 0.0, 0.0, 0.3);
uniform float grid_w = 0.012;
uniform float vary = 0.07;
uniform float flow = 0.0;
uniform float tex_scale = 1.0;
uniform vec4 shine : source_color = vec4(1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float cell_hash(vec2 c) {
	return fract(sin(dot(c, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 p = wpos.xz;
	vec2 uv = p * tex_scale;
	vec3 c;
	if (flow > 0.0) {
		vec3 a = texture(tex, uv + vec2(TIME * 0.035, TIME * 0.012) * flow).rgb;
		vec3 b = texture(tex, uv * 1.37 + vec2(-TIME * 0.022, TIME * 0.03) * flow).rgb;
		c = mix(a, b, 0.5);
		float sparkle = smoothstep(0.62, 0.9, b.g * a.r * 2.2);
		c = mix(c, shine.rgb, sparkle * 0.18 * shine.a);
	} else {
		c = texture(tex, uv).rgb;
	}
	c *= tint.rgb;
	vec2 cell = floor(p + 0.5);
	c *= 1.0 - vary * 0.5 + vary * cell_hash(cell);
	vec2 fb = fract(p + 0.5);
	vec2 d = min(fb, 1.0 - fb);
	vec2 aa = fwidth(p) * 1.2;
	float lx = 1.0 - smoothstep(grid_w, grid_w + aa.x, d.x);
	float lz = 1.0 - smoothstep(grid_w, grid_w + aa.y, d.y);
	float line = max(lx, lz);
	float inner = 1.0 - smoothstep(0.0, 0.09, min(d.x, d.y));
	c *= 1.0 - inner * 0.06;
	c = mix(c, grid_col.rgb, line * grid_col.a);
	ALBEDO = c;
	ROUGHNESS = flow > 0.0 ? 0.32 : 0.92;
	SPECULAR = flow > 0.0 ? 0.6 : 0.15;
}
"""

const MARK_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 fill : source_color = vec4(0.0);
uniform vec4 edge : source_color = vec4(1.0);
uniform int shape = 0;
uniform float edge_w = 0.05;
uniform float glow = 0.0;
uniform float dash = 0.0;
uniform float pulse = 0.0;
uniform float pulse_speed = 3.2;
uniform float radius = 0.08;
uniform float inset = 0.04;
uniform float width_ratio = 0.1;

vec4 over(vec4 top, vec4 under) {
	float a = top.a + under.a * (1.0 - top.a);
	vec3 rgb = (top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(rgb, a);
}

float band(float d, float w, float px) {
	return 1.0 - smoothstep(w - px, w + px, abs(d));
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv - 0.5;
	float px = max(fwidth(uv.x), fwidth(uv.y)) * 0.8;
	vec4 col = vec4(0.0);
	if (shape == 0) {
		vec2 q = abs(p) - vec2(0.5 - inset - radius);
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
		float inside = 1.0 - smoothstep(-px, px, d);
		float ring = band(d + edge_w * 0.5, edge_w * 0.5, px);
		if (dash > 0.0) {
			float t = abs(p.x) > abs(p.y) ? p.y : p.x;
			ring *= smoothstep(0.42, 0.48, fract(t * dash + 0.25)) * (1.0 - smoothstep(0.92, 0.98, fract(t * dash + 0.25)));
		}
		float g = glow > 0.0 ? (1.0 - smoothstep(0.0, glow, -d)) * inside : 0.0;
		col = vec4(fill.rgb, fill.a * inside);
		col = over(vec4(edge.rgb, edge.a * g * 0.55), col);
		col = over(vec4(edge.rgb, edge.a * ring), col);
	} else if (shape == 1) {
		float d = length(p) * 2.0;
		col = vec4(fill.rgb, fill.a * (1.0 - smoothstep(radius, 1.0, d)));
	} else if (shape == 2) {
		float d = length(p) * 2.0;
		float r = 1.0 - edge_w - 0.06;
		float ring = band(d - r, edge_w * 0.5, px * 2.0);
		float halo = (1.0 - smoothstep(r, 1.0, d)) * step(r, d) * glow;
		float inner = (1.0 - smoothstep(0.0, r, d)) * step(d, r);
		col = vec4(fill.rgb, fill.a * mix(0.35, 1.0, 1.0 - inner) * step(d, r));
		col = over(vec4(edge.rgb, edge.a * halo * 0.6), col);
		col = over(vec4(edge.rgb, edge.a * ring), col);
	} else if (shape == 3) {
		float d = length(p) * 2.0;
		float o = band(d - 0.78, 0.035, px * 2.0);
		float i = band(d - 0.34, 0.022, px * 2.0);
		float arm_x = band(p.y, 0.012, px) * step(0.42, abs(p.x) * 2.0) * step(abs(p.x) * 2.0, 0.97);
		float arm_y = band(p.x, 0.012, px) * step(0.42, abs(p.y) * 2.0) * step(abs(p.y) * 2.0, 0.97);
		float dot_c = 1.0 - smoothstep(0.05 - px * 2.0, 0.05 + px * 2.0, d);
		float a = max(max(o, i), max(max(arm_x, arm_y), dot_c));
		col = vec4(fill.rgb, fill.a * (1.0 - smoothstep(0.76, 0.8, d)));
		col = over(vec4(edge.rgb, edge.a * a), col);
	} else if (shape == 4) {
		float across = uv.y - 0.5;
		float pxy = fwidth(uv.y) * 0.8;
		float a;
		if (dash < 0.0) {
			float k = -dash;
			vec2 q = vec2((fract(uv.x * k) - 0.5), across * width_ratio * k);
			a = 1.0 - smoothstep(0.17 - fwidth(uv.x) * k, 0.17 + fwidth(uv.x) * k, length(q));
		} else {
			a = 1.0 - smoothstep(0.3 - pxy, 0.3 + pxy, abs(across));
			if (dash > 0.0) {
				float f = fract(uv.x * dash);
				float fpx = fwidth(uv.x) * dash;
				a *= smoothstep(0.0, fpx, f) * (1.0 - smoothstep(0.55 - fpx, 0.55 + fpx, f));
			}
			float halo = (1.0 - smoothstep(0.3, 0.5, abs(across))) * glow;
			col = vec4(edge.rgb, edge.a * halo * 0.35);
		}
		float tail = smoothstep(0.0, 0.25, uv.x);
		col = over(vec4(fill.rgb, fill.a * a * tail), col);
	} else if (shape == 5) {
		float half_w = 0.5 * (1.0 - uv.x);
		float d = max(-uv.x, abs(uv.y - 0.5) - half_w) ;
		float a = 1.0 - smoothstep(-px, px, d);
		col = vec4(fill.rgb, fill.a * a);
	}
	if (pulse > 0.0) {
		col.a *= 1.0 - pulse * (0.5 + 0.5 * sin(TIME * pulse_speed));
	}
	ALBEDO = col.rgb;
	ALPHA = col.a;
}
"""


static func top_shader() -> Shader:
	if _top == null:
		_top = Shader.new()
		_top.code = TOP_CODE
	return _top


static func mark_shader() -> Shader:
	if _mark == null:
		_mark = Shader.new()
		_mark.code = MARK_CODE
	return _mark


## 一份记号材质：spec 里写 fill / edge（Color）、shape、edge_w、glow、dash、pulse、radius、inset、width_ratio；
## prio 是透明物体之间的先后（大的后画、压在上面）
static func mark_material(spec: Dictionary, prio: int = 0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = mark_shader()
	for k in spec:
		m.set_shader_parameter(StringName(k), spec[k])
	m.render_priority = clampi(prio, -128, 127)
	return m


static var _quad: PlaneMesh = null


## 一块 1×1 朝上的平面（记号都用它，按需缩放）；uv (0,0) 在 -X -Z 角
static func quad() -> PlaneMesh:
	if _quad == null:
		_quad = PlaneMesh.new()
		_quad.size = Vector2(1.0, 1.0)
	return _quad


## 一块记号：平面 + 记号材质，放在 pos（世界坐标），sx/sz 是大小，yaw 是绕 Y 转的角度（度）
static func mark_node(spec: Dictionary, prio: int, pos: Vector3, sx: float, sz: float, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = quad()
	mi.material_override = mark_material(spec, prio)
	mi.position = pos
	mi.rotation_degrees = Vector3(0, yaw, 0)
	mi.scale = Vector3(sx, 1.0, sz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
