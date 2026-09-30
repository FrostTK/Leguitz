shader_type canvas_item;
// Glowing parts of the terrain (lava, ore gems), added on top of the lit
// world in a separate canvas layer so darkness never dims them.

render_mode blend_add, unshaded;

#include "res://src/client/shaders/terrain_common.gdshaderinc"

uniform float emission_strength = 1.4;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 local = UV * 256.0;
	ivec2 tile = clamp(ivec2(floor(local)) / 16, ivec2(0), ivec2(15));
	// The 3x3 tiles around this one, from the chunk's data texture.
	ivec4 n[9];
	for (int i = 0; i < 9; i++) {
		ivec2 offset = ivec2(i % 3 - 1, i / 3 - 1);
		n[i] = ivec4(round(texelFetch(TEXTURE, tile + offset + ivec2(1), 0)));
	}
	TerrainPixel px = terrain_pixel(n, local, TIME);
	float pulse = 0.85 + 0.15 * sin(TIME * 2.0 + world_px.x * 0.05 + world_px.y * 0.03);
	COLOR = vec4(px.emission * emission_strength * pulse, 1.0);
}
