shader_type canvas_item;
// Lit terrain: grounds with transitions, water, cliffs and rock walls.

#include "res://src/client/shaders/terrain_common.gdshaderinc"

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
	COLOR = px.color;
	NORMAL_MAP = px.normal * 0.5 + 0.5;
}
