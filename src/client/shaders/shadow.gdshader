shader_type canvas_item;
// Sun shadows. Each block gets a wide blank quad (80x48); every pixel of it
// looks up the point of the block's silhouette that the sun projects onto
// the ground there. Long and slanted in the morning and evening, short at
// noon.

render_mode unshaded;

uniform sampler2D block_atlas : filter_nearest;
uniform vec2 block_px = vec2(32.0, 48.0);
uniform vec2 shadow_px = vec2(80.0, 48.0);
uniform vec2 cells = vec2(16.0, 3.0);
// x: sideways shift per pixel of height, y: shadow length per pixel of height.
uniform vec2 sun = vec2(-0.6, 0.5);
uniform float strength = 0.3;
uniform vec4 tint : source_color = vec4(0.04, 0.06, 0.14, 1.0);

void fragment() {
	vec2 grid = UV * cells;
	vec2 cell = floor(grid);
	vec2 local = floor((grid - cell) * shadow_px) + 0.5;
	float ground_distance = shadow_px.y - local.y;
	float height = ground_distance / max(sun.y, 0.05);
	vec2 source = vec2(
		local.x - (shadow_px.x - block_px.x) * 0.5 - height * sun.x, block_px.y - height
	);
	float alpha = 0.0;
	if (source.x >= 0.0 && source.x < block_px.x && source.y >= 0.0 && source.y < block_px.y) {
		alpha = texelFetch(block_atlas, ivec2(cell * block_px + floor(source)), 0).a;
	}
	COLOR = vec4(tint.rgb, step(0.5, alpha) * strength);
}
