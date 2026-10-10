shader_type spatial;
// The see-through part of glass, first pass: what is drawn behind it (the
// ground, water, other glass) is multiplied by the glass's tint. Its next
// pass, glass_sheen.gdshader, lays the glass's sheen over it (see
// glass_common.gdshaderinc). Drawn after water (WorldView3D's render
// priorities): water behind glass shows through it. Godot's fog would turn
// the tint into the fog's color: the haze fades it out instead (Godot's
// exponential and height fog, `glass_fog`: density, height, height density,
// set by LightingController).

render_mode blend_mul, unshaded, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/client/shaders/glass_common.gdshaderinc"

global uniform vec3 glass_fog;

// How much fog lies between the eye and `vertex` (view space).
float haze_at(vec3 vertex, mat4 inv_view) {
	float amount = 1.0 - exp(min(0.0, -length(vertex) * glass_fog.x));
	if (abs(glass_fog.z) >= 0.0001) {
		float y = (inv_view * vec4(vertex, 1.0)).y;
		amount = max(amount, 1.0 - exp(min(0.0, (y - glass_fog.y) * glass_fog.z)));
	}
	return amount;
}

void fragment() {
	if (above_cut(VERTEX, INV_VIEW_MATRIX)
			|| hides_player(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, see_through_size, 0.0, FRAGCOORD.xy)) {
		discard;
	}
	ivec2 px = ivec2(floor(UV)) & ivec2(15);
	if (!is_clear(px)) {
		discard;
	}
	ALBEDO = mix(through_of(px), vec3(1.0), haze_at(VERTEX, INV_VIEW_MATRIX));
}
