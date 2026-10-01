shader_type spatial;
// Cracks over a block being broken (see BlockCracks): a box a hair larger
// than the block, every side showing the current stage of the crack
// pattern (16 x 16 art pixels per stage, side by side in `cracks`).

render_mode unshaded, cull_back, shadows_disabled, depth_draw_never;

uniform sampler2D cracks : filter_nearest;
uniform int stage = 0;
// Size of the box mesh (a hair over 1).
uniform float box_size = 1.006;

varying vec3 box_position;
varying vec3 box_normal;

void vertex() {
	box_position = VERTEX / box_size + 0.5;
	box_normal = NORMAL;
}

void fragment() {
	vec3 n = abs(box_normal);
	vec2 uv = n.y > 0.5
			? box_position.xz
			: (n.x > 0.5 ? vec2(box_position.z, 1.0 - box_position.y)
					: vec2(box_position.x, 1.0 - box_position.y));
	ivec2 pixel = ivec2(clamp(floor(uv * 16.0), vec2(0.0), vec2(15.0)));
	vec4 crack = texelFetch(cracks, ivec2(pixel.x + stage * 16, pixel.y), 0);
	if (crack.a < 0.5) {
		discard;
	}
	ALBEDO = crack.rgb;
	ALPHA = crack.a;
}
