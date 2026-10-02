// Shared helpers for the 3D terrain shaders.

uniform sampler2D ground_atlas : source_color, filter_nearest;
uniform sampler2D ground_normals : filter_nearest;

global uniform float weather_wetness;
global uniform float weather_rain;
global uniform vec2 weather_wind;

// See-through hole in the terrain around the player (half width and half
// height around the chest, world units on screen; see see_through.gdshaderinc).
uniform vec2 see_through_size = vec2(1.0, 1.6);

const int HASH_OFFSET = 16777216;
// How much light lava takes from the sun and the lights (it shines by itself).
const float LAVA_LIT = 0.2;

uint hash2(ivec2 p) {
	uvec2 q = uvec2(p + ivec2(HASH_OFFSET));
	uint h = q.x * 374761393u + q.y * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return h ^ (h >> 16u);
}

float hashf(ivec2 p) {
	return float(hash2(p) & 0xFFFFFFu) / 16777215.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	ivec2 ii = ivec2(i);
	float a = hashf(ii);
	float b = hashf(ii + ivec2(1, 0));
	float c = hashf(ii + ivec2(0, 1));
	float d = hashf(ii + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Texel of a ground in the ground atlas (4 variants chosen per tile; see
// also ChunkMesher.ground_variant).
ivec2 ground_atlas_pos(int ground, ivec2 world_tile, ivec2 tx) {
	int variant = int(hash2(world_tile) & 3u);
	return ivec2(variant * 16 + tx.x, ground * 16 + tx.y);
}

vec3 unpack_normal(vec4 texel) {
	return texel.rgb * 2.0 - 1.0;
}
