shader_type spatial;
// Water surfaces (sea, lakes, rivers, swamps, cave lakes). What lies under
// the water shows through, fading into the water's color with the
// thickness of water the eye looks through (anything under it does: fish
// near the surface will show better than deep ones), bent by the ripples
// by whole art pixels, with light dancing on it in the shallows. Ripples,
// sparkles and the foam of the shores are drawn on top; where the ground of
// a shore spreads over the water's edge, that ground is drawn.
//
// UV and UV2 as on the terrain tops (see terrain3d_top.gdshader).

render_mode cull_back;

#include "res://src/client/shaders/terrain3d_common.gdshaderinc"
#include "res://src/client/shaders/terrain3d_surface.gdshaderinc"
#include "res://src/client/shaders/see_through.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
// Per ground id: the water's own color (all of it shows over deep water),
// the tint of the light coming up through it, and how deep (levels) the
// eye sees into it.
uniform vec4 water_colors[64] : source_color;
uniform vec4 water_tints[64] : source_color;
uniform float water_clarity[64];
// How fast the depths fade out: at `clarity` levels, exp(-fade) is left.
uniform float fade = 1.5;
// The fade goes by steps (pixel-art bands), and the surface's own color
// shows even over the shallowest water.
uniform float fade_steps = 6.0;
uniform float surface_share = 0.25;
// Ripples bend what lies under the water by up to this many art pixels.
uniform float refraction_pixels = 1.2;
// Light dancing on what lies under shallow water (fades out this deep).
uniform float caustics_strength = 0.7;
uniform float caustics_depth = 5.0;

varying vec3 local_vertex;
varying flat vec2 top_info;

void vertex() {
	top_info = UV2;
	local_vertex = VERTEX;
}

// Local position (chunk units) of what the depth buffer shows at `uv`.
vec3 local_behind(vec2 uv, mat4 inv_projection, mat4 inv_view, mat4 inv_model) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	return (inv_model * (inv_view * vec4(view.xyz, 1.0))).xyz;
}

// Bright lines where two drifting noises meet: sunlight focused by the
// ripples (0, a glimmer or a line).
float caustics(vec2 p, float t) {
	float a = value_noise(p * 1.6 + vec2(t * 0.35, t * 0.2));
	float b = value_noise(p * 1.9 + vec2(-t * 0.25, t * 0.3) + 7.3);
	float line = 1.0 - abs(a - b) * 6.0;
	return line > 0.55 ? 1.0 : (line > 0.3 ? 0.4 : 0.0);
}

void fragment() {
	if (above_cut(VERTEX, INV_VIEW_MATRIX)
			|| hides_player(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, see_through_size, 0.0, FRAGCOORD.xy)) {
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
	if (n[4].b != face_level) {
		// Water under the visible surface of its column (a cave lake under
		// the land): drawn plainly.
		ivec4 alone = ivec4(face_code, 0, face_level, 0);
		for (int i = 0; i < 9; i++) {
			n[i] = alone;
		}
	}
	vec3 blend = blend_ground(n, tx, wp);
	int best = int(blend.x + 0.5);
	float t = TIME;

	vec3 albedo;
	vec3 normal = vec3(0.0, 0.0, 1.0);
	vec3 emission = vec3(0.0);
	float roughness = 0.9;
	float specular = 0.3;

	if (ground_kind[best] != KIND_WATER) {
		// The ground of the shore spreading over the water's edge.
		ivec2 at = ground_atlas_pos(best, world_tile, tx);
		albedo = texelFetch(ground_atlas, at, 0).rgb;
		normal = unpack_normal(texelFetch(ground_normals, at, 0));
		albedo *= 1.0 - 0.3 * weather_wetness;
		roughness = mix(0.9, 0.35, weather_wetness);
		if (blend.y < 0.075) {
			albedo *= 0.8;
		}
	} else {
		// The surface: ripples, sparkles, foam along the shores. `cover`:
		// how much they hide what lies under.
		vec2 p = wp / 16.0;
		vec2 drift = weather_wind * t * 0.08;
		float broad = value_noise(p * 0.35 + drift);
		vec3 surface = water_colors[best].rgb * (0.9 + 0.2 * broad);
		float warp = value_noise(p * 1.7 - drift * 1.5) * 3.0;
		float phase = p.x * 2.1 + p.y * 3.4 + warp - t * 1.3;
		float wave = sin(phase);
		float cover = 0.0;
		if (wave > 0.93) {
			surface = surface * 1.45 + vec3(0.03, 0.05, 0.06);
			cover = 0.35;
		} else if (wave < -0.96) {
			surface *= 0.86;
		}
		normal = normalize(vec3(0.0, cos(phase) * 0.35, 1.0));
		float sparkle = hashf(lp + world_tile * 16 + ivec2(int(floor(t * 3.0)) * 131, 7));
		if (sparkle > 0.998 - weather_rain * 0.02) {
			surface = mix(surface, vec3(1.0), 0.7);
			cover = 0.8;
		}
		float foam_width = 0.07 + 0.045 * sin(t * 1.7 + wp.x * 0.09 + wp.y * 0.13);
		float foam = blend.z;
		if (foam >= 0.0 && foam < foam_width) {
			surface = mix(surface, vec3(0.85, 0.93, 1.0), 0.75);
			cover = 1.0;
		} else if (foam >= 0.0 && foam < foam_width + 0.1) {
			surface = surface * 1.2 + vec3(0.02, 0.04, 0.05);
			cover = max(cover, 0.3);
		}

		// What lies under, and how much water the eye looks through to it.
		mat4 inv_model = inverse(MODEL_MATRIX);
		vec3 behind = local_behind(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, inv_model);
		float thickness = distance(local_vertex, behind);
		// The ripples bend it by whole art pixels (hardly in the shallows).
		// Only what lies under the water bends, not what stands in front.
		vec2 bend = vec2(sin(phase * 1.3 + p.y), cos(phase * 0.8 + p.x));
		bend = round(bend * refraction_pixels * clamp(thickness, 0.0, 1.0)) / 16.0;
		vec2 uv = SCREEN_UV;
		if (bend != vec2(0.0)) {
			mat4 to_clip = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX;
			vec4 clip = to_clip * vec4(behind + vec3(bend.x, 0.0, bend.y), 1.0);
			vec2 bent_uv = clip.xy / clip.w * 0.5 + 0.5;
			vec3 bent = local_behind(bent_uv, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX, inv_model);
			bool inside = all(greaterThan(bent_uv, vec2(0.0))) && all(lessThan(bent_uv, vec2(1.0)));
			if (inside && bent.y < local_vertex.y - 0.05) {
				uv = bent_uv;
				behind = bent;
				thickness = distance(local_vertex, behind);
			}
		}
		vec3 seen = textureLod(screen_texture, uv, 0.0).rgb;
		// Light dancing on the shallows, per art pixel.
		float under = local_vertex.y - behind.y;
		vec2 spot = floor(behind.xz * 16.0) / 16.0;
		float shallow = clamp(1.0 - under / caustics_depth, 0.0, 1.0);
		seen *= 1.0 + caustics(spot, t) * caustics_strength * shallow;
		// The depths fade into the water's own color, by steps.
		float clear = exp(-fade * thickness / max(water_clarity[best], 0.1));
		clear = floor(clear * fade_steps + 0.5) / fade_steps;
		clear *= 1.0 - cover;
		albedo = surface * (surface_share + (1.0 - surface_share) * (1.0 - clear));
		emission = seen * water_tints[best].rgb * (1.0 - surface_share) * clear;
		// The orthographic view mirrors the sun on all the water at once:
		// seen from a low camera, a rougher surface keeps the glare soft.
		float grazing = 1.0 - smoothstep(0.35, 0.8, dot(NORMAL, VIEW));
		roughness = mix(0.15, 0.4, grazing);
		specular = 0.8;
	}

	ALBEDO = albedo * edge_shade(n, tx);
	NORMAL_MAP = normal * 0.5 + 0.5;
	EMISSION = emission;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
