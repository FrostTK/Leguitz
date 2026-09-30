shader_type canvas_item;
// Shadows of clouds drifting over the landscape (world-space, pixel-snapped).

render_mode unshaded;

uniform vec2 wind = vec2(1.0, 0.3);
uniform float coverage = 0.55;
uniform float strength = 0.22;
uniform float travel = 0.0;

varying vec2 world_px;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	vec2 p = floor(world_px) / 260.0 - wind * travel;
	float n = noise(p) * 0.55 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 - 1.3) * 0.15;
	float cloud = smoothstep(coverage, coverage + 0.1, n);
	COLOR = vec4(0.05, 0.07, 0.16, cloud * strength);
}
