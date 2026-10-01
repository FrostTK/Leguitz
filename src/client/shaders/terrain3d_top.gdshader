shader_type spatial;
// Top faces of the 3D terrain: the top of every voxel open to the air, or
// under clear water (lake beds; the water is drawn by water.gdshader).
//
// The chunk mesh UVs are chunk pixels / 256, UV2 = (material code: ground
// id or WALL_CODE + wall kind, level of the top). Tops at the visible level
// of their column blend with their neighbors (see
// terrain3d_surface.gdshaderinc), and so do beds with the beds around;
// other tops (ledges under an overhang) are drawn plainly. Everything is
// computed per art pixel.

render_mode cull_disabled;

#include "res://src/client/shaders/terrain3d_common.gdshaderinc"
#include "res://src/client/shaders/terrain3d_surface.gdshaderinc"
#include "res://src/client/shaders/see_through.gdshaderinc"

uniform sampler2D wall_atlas : source_color, filter_nearest;
uniform sampler2D wall_normals : filter_nearest;
uniform sampler2D wall_emission : source_color, filter_nearest;
uniform float emission_strength = 2.2;

varying flat vec2 top_info;

void vertex() {
	top_info = UV2;
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
	if (section && section_on < 0.5) {
		discard;
	}
	vec2 local = UV * 256.0;
	ivec2 lp = clamp(ivec2(floor(local)), ivec2(0), ivec2(255));
	ivec2 tile = lp / 16;
	ivec2 tx = lp - tile * 16;
	vec2 wp = chunk_origin_px + vec2(lp);
	ivec2 world_tile = ivec2(floor(wp / 16.0));
	ivec4 n[9];
	for (int i = 0; i < 9; i++) {
		n[i] = column_at(tile + ivec2(i % 3 - 1, i / 3 - 1));
	}
	int face_code = int(top_info.x + 0.5);
	int face_level = int(round(top_info.y));
	bool bed = false;
	if (n[4].b != face_level) {
		if (n[4].a > 0 && bed_of(n[4]).b == face_level) {
			// The bed under the water: it blends with the beds and banks around.
			bed = true;
			for (int i = 0; i < 9; i++) {
				n[i] = bed_of(n[i]);
			}
		} else {
			// A top under the visible surface of its column (a ledge under an
			// overhang): drawn plainly, as if all its neighbors were alike.
			int wall_kind = face_code >= WALL_CODE ? face_code - WALL_CODE + 1 : 0;
			ivec4 alone = ivec4(wall_kind > 0 ? 0 : face_code, wall_kind, face_level, 0);
			for (int i = 0; i < 9; i++) {
				n[i] = alone;
			}
		}
	}
	ivec4 c = n[4];
	int wall = c.g;
	float t = TIME;

	vec3 albedo;
	vec3 normal = vec3(0.0, 0.0, 1.0);
	vec3 emission = vec3(0.0);
	float roughness = 0.9;
	float specular = 0.3;

	if (wall > 0) {
		// Top of a rock wall, with lit rims where it drops.
		int variant = int(hash2(world_tile + ivec2(3, 11)) & 1u);
		ivec2 at = ivec2(variant * 16 + tx.x, (wall - 1) * 16 + tx.y);
		albedo = texelFetch(wall_atlas, at, 0).rgb;
		normal = unpack_normal(texelFetch(wall_normals, at, 0));
		emission = texelFetch(wall_emission, at, 0).rgb;
		if (n[1].g == 0 && tx.y == 0) {
			albedo *= 1.3;
		}
		if (n[7].g == 0 && tx.y == 15) {
			albedo *= 1.15;
		}
		if (n[3].g == 0 && tx.x == 0) {
			albedo *= 1.15;
		}
		if (n[5].g == 0 && tx.x == 15) {
			albedo *= 0.8;
		}
	} else {
		vec3 blend = blend_ground(n, tx, wp);
		int best = int(blend.x + 0.5);
		int kind = ground_kind[best];
		if (kind == KIND_LAVA) {
			vec2 p = wp / 16.0;
			float lt = t * 0.35;
			float heat = value_noise(p * 1.8 + vec2(lt, lt * 0.6)) * 0.6
					+ value_noise(p * 3.7 - vec2(lt * 0.8, lt)) * 0.4;
			albedo = vec3(0.86, 0.28, 0.08);
			if (heat > 0.62) {
				albedo = vec3(1.0, 0.78, 0.25);
			} else if (heat > 0.48) {
				albedo = vec3(0.98, 0.5, 0.12);
			} else if (heat < 0.3) {
				albedo = vec3(0.55, 0.16, 0.06);
			}
			emission = albedo * (0.9 + 0.5 * heat);
		} else {
			ivec2 at = ground_atlas_pos(best, world_tile, tx);
			albedo = texelFetch(ground_atlas, at, 0).rgb;
			normal = unpack_normal(texelFetch(ground_normals, at, 0));
			// Rain wets the ground (beds are wet anyway).
			float wet = bed ? 0.0 : weather_wetness;
			albedo *= 1.0 - 0.3 * wet;
			roughness = mix(0.9, 0.35, wet);
			if (kind == KIND_ICE) {
				roughness = 0.25;
				specular = 0.7;
			}
			if (best != c.r && blend.y < 0.075) {
				albedo *= 0.8;
			}
		}
	}

	if (wall == 0) {
		albedo *= edge_shade(n, tx);
	}
	ALBEDO = albedo;
	NORMAL_MAP = normal * 0.5 + 0.5;
	EMISSION = emission * emission_strength;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	if (section) {
		ALBEDO = vec3(0.0);
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
		EMISSION = SECTION_COLOR;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
}
