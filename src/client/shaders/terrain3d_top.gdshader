shader_type spatial;
// Top faces of the 3D terrain: the top of every voxel open to the air.
//
// The chunk mesh UVs are chunk pixels / 256, UV2 = (material code: ground
// id or WALL_CODE + wall kind, level of the top). `chunk_data` is an 18x18
// float texture (the chunk plus a 1-tile border, see
// ChunkMesher.surface_map): r = ground id, g = wall kind + 1 (0 = none),
// b = level of the visible top of the column. Tops at that level blend
// with their neighbors. Everything is computed per art pixel.

render_mode cull_disabled;

#include "res://src/client/shaders/terrain3d_common.gdshaderinc"
#include "res://src/client/shaders/see_through.gdshaderinc"

uniform sampler2D chunk_data : filter_nearest;
uniform vec2 chunk_origin_px = vec2(0.0);
uniform sampler2D wall_atlas : source_color, filter_nearest;
uniform sampler2D wall_normals : filter_nearest;
uniform sampler2D wall_emission : source_color, filter_nearest;
// Per ground id: blend priority, kind (0 land, 1 water, 2 lava, 3 ice), water color.
uniform int ground_priority[32];
uniform int ground_kind[32];
uniform vec4 water_colors[32] : source_color;
uniform float emission_strength = 2.2;

varying flat vec2 top_info;

const int WALL_CODE = 64;
const int KIND_WATER = 1;
const int KIND_LAVA = 2;
const int KIND_ICE = 3;

// Height rank of a column: level, plus half a level for a rock wall.
int top_rank(ivec4 column) {
	return column.b * 2 + (column.g != 0 ? 2 : 0);
}

// Terrace edges seen from above: a light rim where the ground drops away,
// a contact shadow at the foot of a higher terrace or wall. They outline
// the terraces whatever the camera angle.
float edge_shade(ivec4 n[9], ivec2 tx) {
	int here = top_rank(n[4]);
	float shade = 1.0;
	// North, west, east, south neighbors and the distance to that edge.
	int sides[4] = int[](1, 3, 5, 7);
	int dist[4] = int[](tx.y, tx.x, 15 - tx.x, 15 - tx.y);
	for (int k = 0; k < 4; k++) {
		int other = top_rank(n[sides[k]]);
		if (other > here) {
			shade *= dist[k] == 0 ? 0.72 : (dist[k] == 1 ? 0.88 : 1.0);
		} else if (other < here && dist[k] == 0) {
			shade *= 1.12;
		}
	}
	return shade;
}

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
	vec2 local = UV * 256.0;
	ivec2 lp = clamp(ivec2(floor(local)), ivec2(0), ivec2(255));
	ivec2 tile = lp / 16;
	ivec2 tx = lp - tile * 16;
	vec2 wp = chunk_origin_px + vec2(lp);
	ivec2 world_tile = ivec2(floor(wp / 16.0));
	ivec4 n[9];
	for (int i = 0; i < 9; i++) {
		ivec2 offset = ivec2(i % 3 - 1, i / 3 - 1);
		n[i] = ivec4(round(texelFetch(chunk_data, tile + offset + ivec2(1), 0)));
	}
	int face_code = int(top_info.x + 0.5);
	int face_level = int(round(top_info.y));
	if (n[4].b != face_level) {
		// A top under the visible surface of its column (a ledge under an
		// overhang): drawn plainly, as if all its neighbors were alike.
		int wall_kind = face_code >= WALL_CODE ? face_code - WALL_CODE + 1 : 0;
		ivec4 alone = ivec4(wall_kind > 0 ? 0 : face_code, wall_kind, face_level, 0);
		for (int i = 0; i < 9; i++) {
			n[i] = alone;
		}
	}
	ivec4 c = n[4];
	int ground = c.r;
	int wall = c.g;
	int level = c.b;
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
		// Ground with organic transitions: a higher-priority neighbor on
		// the same level spreads into this tile by a wobbly margin.
		vec2 f = (vec2(tx) + 0.5) / 16.0;
		float wobble = value_noise(wp * 0.3) * 0.6 + value_noise(wp * 0.11 + 17.0) * 0.4;
		float reach = 0.16 + 0.24 * wobble;
		int best = ground;
		int best_priority = ground_priority[ground];
		float best_depth = 0.0;
		float foam_margin = -1.0;
		bool water_here = ground_kind[ground] == KIND_WATER;
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				if (dx == 0 && dy == 0) {
					continue;
				}
				ivec4 other = n[(dy + 1) * 3 + (dx + 1)];
				float d;
				if (dx != 0 && dy != 0) {
					vec2 corner = vec2(dx > 0 ? 1.0 : 0.0, dy > 0 ? 1.0 : 0.0);
					d = distance(f, corner) * 1.1;
				} else if (dx != 0) {
					d = dx > 0 ? 1.0 - f.x : f.x;
				} else {
					d = dy > 0 ? 1.0 - f.y : f.y;
				}
				bool neighbor_land = other.g != 0 || ground_kind[other.r] != KIND_WATER;
				if (water_here && neighbor_land) {
					float margin = d - (other.g != 0 || other.b != level ? 0.0 : reach);
					foam_margin = foam_margin < 0.0 ? margin : min(foam_margin, margin);
				}
				if (other.g != 0 || other.b != level) {
					continue;
				}
				int priority = ground_priority[other.r];
				if (priority <= best_priority || d >= reach) {
					continue;
				}
				best = other.r;
				best_priority = priority;
				best_depth = reach - d;
			}
		}

		int kind = ground_kind[best];
		if (kind == KIND_WATER) {
			vec3 base = water_colors[best].rgb;
			vec2 p = wp / 16.0;
			vec2 drift = weather_wind * t * 0.08;
			float broad = value_noise(p * 0.35 + drift);
			albedo = base * (0.9 + 0.2 * broad);
			float warp = value_noise(p * 1.7 - drift * 1.5) * 3.0;
			float phase = p.x * 2.1 + p.y * 3.4 + warp - t * 1.3;
			float wave = sin(phase);
			if (wave > 0.93) {
				albedo = albedo * 1.45 + vec3(0.03, 0.05, 0.06);
			} else if (wave < -0.96) {
				albedo *= 0.86;
			}
			normal = normalize(vec3(0.0, cos(phase) * 0.35, 1.0));
			float sparkle = hashf(lp + world_tile * 16 + ivec2(int(floor(t * 3.0)) * 131, 7));
			if (sparkle > 0.998 - weather_rain * 0.02) {
				albedo = mix(albedo, vec3(1.0), 0.7);
			}
			float foam_width = 0.07 + 0.045 * sin(t * 1.7 + wp.x * 0.09 + wp.y * 0.13);
			if (foam_margin >= 0.0 && foam_margin < foam_width) {
				albedo = mix(albedo, vec3(0.85, 0.93, 1.0), 0.75);
			} else if (foam_margin >= 0.0 && foam_margin < foam_width + 0.1) {
				albedo = albedo * 1.2 + vec3(0.02, 0.04, 0.05);
			}
			// The orthographic view mirrors the sun on all the water at once:
			// seen from a low camera, a rougher surface keeps the glare soft.
			float grazing = 1.0 - smoothstep(0.35, 0.8, dot(NORMAL, VIEW));
			roughness = mix(0.15, 0.4, grazing);
			specular = 0.8;
		} else if (kind == KIND_LAVA) {
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
			albedo *= 1.0 - 0.3 * weather_wetness;
			roughness = mix(0.9, 0.35, weather_wetness);
			if (kind == KIND_ICE) {
				roughness = 0.25;
				specular = 0.7;
			}
			if (best != ground && best_depth < 0.075) {
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
