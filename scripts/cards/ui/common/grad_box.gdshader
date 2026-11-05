// Gradient rounded box with border (reskin SPEC 4.2). Owner C01.
// No colour values live here: every colour is a uniform set from CardTheme by grad_box.gd.
// mode 0 = vertical (top -> mid -> bottom), mode 1 = radial around `center` (CSS farthest-corner).
// Top and bottom corners take separate radii, so radius_top_px = width / 2 draws an arch.
// open_sides (left, top, right, bottom) = 1 pushes that edge (and its border) off the box, for
// drawers and tabs that sit against the screen edge.
shader_type canvas_item;

uniform vec4 color_top : source_color;
uniform vec4 color_mid : source_color;
uniform vec4 color_bot : source_color;
uniform float mid_stop = 0.55;
uniform int mode = 0;
uniform vec2 center = vec2(0.5, 0.35);
uniform float radius_top_px = 6.0;
uniform float radius_bottom_px = 6.0;
uniform float border_px = 2.0;
uniform vec4 border_color : source_color;
uniform float inner_px = 0.0;
uniform vec4 inner_color : source_color;
uniform vec4 open_sides = vec4(0.0);
uniform vec2 size_px = vec2(64.0, 64.0);

float box_sdf(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

void fragment() {
	vec2 px = UV * size_px;
	float r_max = max(radius_top_px, radius_bottom_px);
	float ext = border_px + r_max + 1.0;
	vec2 lo = -vec2(open_sides.x, open_sides.y) * ext;
	vec2 hi = size_px + vec2(open_sides.z, open_sides.w) * ext;
	vec2 half_size = (hi - lo) * 0.5;
	vec2 p = px - (lo + hi) * 0.5;
	float r = p.y < 0.0 ? radius_top_px : radius_bottom_px;
	r = clamp(r, 0.0, min(half_size.x, half_size.y));
	float d = box_sdf(p, half_size, r);

	float t;
	if (mode == 1) {
		vec2 c = center * size_px;
		float far = max(max(length(c), length(c - vec2(size_px.x, 0.0))),
			max(length(c - vec2(0.0, size_px.y)), length(c - size_px)));
		t = clamp(length(px - c) / max(far, 1.0), 0.0, 1.0);
	} else {
		t = clamp(UV.y, 0.0, 1.0);
	}
	float s = clamp(mid_stop, 0.001, 0.999);
	vec4 fill = t < s ? mix(color_top, color_mid, t / s) : mix(color_mid, color_bot, (t - s) / (1.0 - s));

	vec4 col = fill;
	if (inner_px > 0.0) {
		float in_inner = 1.0 - smoothstep(-0.5, 0.5, d + border_px + inner_px);
		col = mix(mix(fill, vec4(inner_color.rgb, 1.0), inner_color.a), fill, in_inner);
	}
	if (border_px > 0.0) {
		float in_border = smoothstep(-0.5, 0.5, d + border_px);
		col = mix(col, border_color, in_border * border_color.a);
	}
	col.a *= 1.0 - smoothstep(-0.5, 0.5, d);
	COLOR = col;
}
