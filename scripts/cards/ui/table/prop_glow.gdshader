// Counter tool hover glow (reskin SPEC 10.2): brighten the prop and draw a one-texel outline around
// its opaque pixels (one scene pixel = 4 screen pixels). Owner C01.
// No colour values live here: glow_color is set from CardTheme (tool_glow) by card_stage.gd.
shader_type canvas_item;

uniform vec4 glow_color : source_color;
uniform float strength = 0.0;
uniform float bright = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb *= bright;
	if (strength > 0.0 && c.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		a = max(a, 0.6 * texture(TEXTURE, UV + px).a);
		a = max(a, 0.6 * texture(TEXTURE, UV - px).a);
		a = max(a, 0.6 * texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
		a = max(a, 0.6 * texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
		float g = a * strength * glow_color.a;
		c = vec4(mix(c.rgb, glow_color.rgb, g), max(c.a, g));
	}
	COLOR = c;
}
