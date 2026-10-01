shader_type spatial;
// Cloud shadows: an invisible plane high above the land (it only casts
// shadows). Clear sky is discarded; clouds are dithered in the shadow map
// (the shadow filter smooths it) so their shadows stay light, with
// thinner edges.

render_mode unshaded, cull_disabled, shadows_disabled;

uniform float coverage = 0.35;
// Wind drift of the clouds, in tiles.
uniform vec2 drift = vec2(0.0);
// Horizontal stretch of the world Z axis (tiles are taller than wide in 3D).
uniform float z_stretch = 1.1547;
uniform float cloud_scale = 0.03;
// Darkness of the thickest cloud shadows (0..1).
uniform float max_opacity = 0.5;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0
);

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 tiles = vec2(world.x, world.z / z_stretch) - drift;
	vec2 p = tiles * cloud_scale;
	float n = noise(p) * 0.55 + noise(p * 2.1 + 5.3) * 0.3 + noise(p * 4.3 + 1.7) * 0.15;
	float edge = 1.0 - coverage * 0.8 - 0.15;
	float opacity = smoothstep(edge, edge + 0.12, n) * max_opacity;
	ivec2 cell = ivec2(FRAGCOORD.xy) & ivec2(3);
	if ((BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0 >= opacity) {
		discard;
	}
	ALBEDO = vec3(0.0);
}
