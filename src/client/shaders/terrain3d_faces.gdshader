shader_type spatial;
// Vertical faces of the 3D terrain (sides of the voxels open to the air)
// and the undersides closing the rock. Mesh data:
//   UV   = (pixels along the face, pixels down from the top of the face)
//   UV2  = (face kind: 0-3 cliff materials, 4+ wall kinds; lip ground + 1)
//   COLOR.r = variant (0 or 1), COLOR.g = lip ground variant / 3

render_mode cull_disabled;

#include "res://src/client/shaders/terrain3d_common.gdshaderinc"
#include "res://src/client/shaders/see_through.gdshaderinc"

uniform sampler2D face_atlas : source_color, filter_nearest;
uniform sampler2D face_normals : filter_nearest;
uniform sampler2D face_emission : source_color, filter_nearest;
uniform float emission_strength = 2.2;

varying flat vec4 face_data;

void vertex() {
	face_data = vec4(UV2, COLOR.r, COLOR.g * 3.0);
}

void fragment() {
	if (!IN_SHADOW_PASS) {
		if (above_cut(VERTEX, INV_VIEW_MATRIX)
				|| hides_player(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, see_through_size, 0.0, FRAGCOORD.xy)) {
			discard;
		}
	}
	// Seen from behind (through the view cut): the section of the rock.
	bool section = !IN_SHADOW_PASS && !FRONT_FACING;
	int u = clamp(int(floor(UV.x)), 0, 15);
	int v = max(int(floor(UV.y)), 0);
	int kind = int(face_data.x + 0.5);
	int lip_ground = int(face_data.y + 0.5) - 1;
	int variant = int(face_data.z + 0.5);
	int lip_variant = int(face_data.w + 0.5);
	vec3 albedo;
	vec3 normal;
	vec3 emission = vec3(0.0);
	if (lip_ground >= 0 && v < 3) {
		// The plateau's own ground hangs over the top of the cliff.
		ivec2 at = ivec2(lip_variant * 16 + u, lip_ground * 16 + v + 13);
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
	if (section) {
		ALBEDO = vec3(0.0);
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
		EMISSION = SECTION_COLOR;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}
