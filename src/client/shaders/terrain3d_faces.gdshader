shader_type spatial;
// Vertical faces of the 3D terrain: cliffs between terrace levels and the
// sides of rock walls. Mesh data:
//   UV   = (pixels along the face, pixels down from the top of the face)
//   UV2  = (face kind: 0-3 cliff materials, 4+ wall kinds; lip ground + 1)
//   COLOR.r = variant (0 or 1)

render_mode cull_disabled;

#include "res://src/client/shaders/terrain3d_common.gdshaderinc"

uniform sampler2D face_atlas : source_color, filter_nearest;
uniform sampler2D face_normals : filter_nearest;
uniform sampler2D face_emission : source_color, filter_nearest;
uniform float emission_strength = 2.2;

varying flat vec3 face_data;
varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	face_data = vec3(UV2, COLOR.r);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	int u = clamp(int(floor(UV.x)), 0, 15);
	int v = max(int(floor(UV.y)), 0);
	int kind = int(face_data.x + 0.5);
	int lip_ground = int(face_data.y + 0.5) - 1;
	int variant = int(face_data.z + 0.5);
	vec3 albedo;
	vec3 normal;
	vec3 emission = vec3(0.0);
	if (lip_ground >= 0 && v < 3) {
		// The plateau's own ground hangs over the top of the cliff.
		// The tile behind the face (the plateau), for its ground variant.
		vec3 inside = world_pos - normalize(world_normal) * 0.05;
		ivec2 world_tile = ivec2(int(floor(inside.x)), int(floor(inside.z / Z_STRETCH)));
		ivec2 at = ground_atlas_pos(lip_ground, world_tile, ivec2(u, v + 13));
		albedo = texelFetch(ground_atlas, at, 0).rgb;
		normal = unpack_normal(texelFetch(ground_normals, at, 0));
		if (v == 2) {
			albedo *= 0.8;
		}
	} else {
		ivec2 at = ivec2(variant * 16 + u, kind * 16 + (v & 15));
		albedo = texelFetch(face_atlas, at, 0).rgb;
		normal = unpack_normal(texelFetch(face_normals, at, 0));
		emission = texelFetch(face_emission, at, 0).rgb;
		if (lip_ground >= 0 && v == 3) {
			albedo *= 0.55;
		}
	}
	albedo *= 1.0 - 0.25 * weather_wetness;
	ALBEDO = albedo;
	NORMAL_MAP = normal * 0.5 + 0.5;
	EMISSION = emission * emission_strength;
	ROUGHNESS = mix(0.95, 0.4, weather_wetness);
}
