# The magnifier: a round glass that shows what is under it at twice the size (reads the screen behind it at
# screen-pixel centres, so pixels stay square even where the screen copy is filtered). Rim colour from
# CardTheme. No input; the game moves it.
# No class_name; preload it. Owner C15.
extends ColorRect

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec4 rim_color : source_color;
uniform float zoom = 2.0;
uniform float rim = 0.05;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	if (r > 1.0) {
		discard;
	}
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 suv = SCREEN_UV - d * span * (1.0 - 1.0 / zoom);
	// Sample the middle of one screen pixel: the screen copy is filtered linearly under some renderers
	// (Compatibility), and a 1 px jog must stay a hard 2 px step in the glass (acceptance fix2).
	suv = (floor(suv / SCREEN_PIXEL_SIZE) + 0.5) * SCREEN_PIXEL_SIZE;
	vec4 c = texture(screen_tex, suv);
	if (r > 1.0 - rim) {
		c = rim_color;
	}
	COLOR = vec4(c.rgb, 1.0);
}
"""

var radius: int = 72


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	color = Color.WHITE
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("rim_color", CardTheme.color(&"umber"))
	material = mat


func setup(r: int) -> void:
	radius = clampi(r, 32, 160)
	size = Vector2(radius * 2, radius * 2)
	(material as ShaderMaterial).set_shader_parameter("rim", 3.0 / float(radius))


## Centre the glass on p (in the parent's coords).
func follow(p: Vector2) -> void:
	position = Vector2(round(p.x) - float(radius), round(p.y) - float(radius))
