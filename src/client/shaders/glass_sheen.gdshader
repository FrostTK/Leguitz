shader_type spatial;
// The see-through part of glass, second pass (glass.gdshader's next pass):
// the glass's own sheen of the sky, lit, over what its first pass tinted,
// and the sun's glints (see glass_common.gdshaderinc).

render_mode blend_mix, cull_disabled;

#include "res://src/client/shaders/glass_common.gdshaderinc"
#include "res://src/client/shaders/sky_light.gdshaderinc"

// The glints: Godot's own specular (GGX) for this roughness and specular.
const float ROUGH = 0.08;
const float F0 = 0.16 * 0.9 * 0.9;

void fragment() {
	if (above_cut(VERTEX, INV_VIEW_MATRIX)
			|| hides_player(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, see_through_size, 0.0, FRAGCOORD.xy)) {
		discard;
	}
	ivec2 px = ivec2(floor(UV)) & ivec2(15);
	if (!is_clear(px)) {
		discard;
	}
	int tint = tint_of();
	ALBEDO = tint >= 0 ? tint_colors[tint] : vec3(0.7, 0.82, 0.9);
	ALPHA = body_of(px, NORMAL, VIEW);
	ROUGHNESS = ROUGH;
	SPECULAR = 0.9;
	AO = sky_ambient(sky);
	AO_LIGHT_AFFECT = 0.0;
}

void light() {
	float n_dot_l = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += n_dot_l * ATTENUATION * LIGHT_COLOR / PI;
	// The glints at full strength, as on an opaque surface: the blend would
	// scale them by ALPHA.
	vec3 half_way = normalize(VIEW + LIGHT);
	float n_dot_h = clamp(dot(NORMAL, half_way), 0.0, 1.0);
	float n_dot_v = clamp(dot(NORMAL, VIEW), 1e-4, 1.0);
	float a2 = pow(ROUGH, 4.0);
	float d = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
	float ggx = a2 / (PI * d * d);
	float vis = 0.5 / (n_dot_l * sqrt(n_dot_v * n_dot_v * (1.0 - a2) + a2)
			+ n_dot_v * sqrt(n_dot_l * n_dot_l * (1.0 - a2) + a2) + 1e-5);
	float fresnel = F0 + (1.0 - F0) * pow(1.0 - clamp(dot(LIGHT, half_way), 0.0, 1.0), 5.0);
	SPECULAR_LIGHT += n_dot_l * ggx * vis * fresnel * ATTENUATION * LIGHT_COLOR * SPECULAR_AMOUNT
			/ max(ALPHA, 0.01);
}
