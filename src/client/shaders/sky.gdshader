shader_type sky;
// The sky seen in first person (LightingController sets it every frame):
// a gradient from the horizon (the fog's color, so the distance melts into
// it) to the top, warm glows towards the sun at its rise and set and a
// pink band opposite, the sun (a disk and stepped halos), the moon in its
// phase (lit side, dark seas, earthshine), stars turning with the night
// (twinkling, a faint milky way), and clouds: the same noise, scale and
// drift as their shadows on the ground (cloud_shadows.gdshader), on a
// layer high above, lit from the sun's side, in a few flat tones (pixel
// art: the sky is drawn at the art resolution). Cheap: no radiance is
// made from it (the ambient light is a color, reflections are off).

uniform vec3 top_color : source_color = vec3(0.3, 0.52, 0.86);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.8, 0.9);
uniform vec3 ground_color : source_color = vec3(0.3, 0.33, 0.36);
// Towards the sun and the moon as they show (under the horizon: set).
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
// 0..1: the sun low (rise, set), the night (stars), the storm.
uniform float twilight = 0.0;
uniform float night = 0.0;
uniform float storm = 0.0;
// The angle of the light on the moon: 0 new, PI full.
uniform float moon_light = 3.14159;
uniform float cloud_coverage = 0.35;
// Tiles: the clouds' drift and the noise's scale (as their shadows), and
// the height of their layer (local units).
uniform vec2 cloud_drift = vec2(0.0);
uniform float cloud_scale = 0.03;
uniform float cloud_height = 70.0;
// The star field's turn over the night (radians).
uniform float star_turn = 0.0;

const float SUN_RADIUS = 0.05;
const float MOON_RADIUS = 0.04;
// Colors below are written in sRGB (as a painter picks them): lin() makes
// them linear for the renderer.
const vec3 GLOW_ORANGE = vec3(1.0, 0.52, 0.2);
const vec3 GLOW_PINK = vec3(0.92, 0.46, 0.56);
const vec3 BELT = vec3(0.62, 0.48, 0.66);

vec3 lin(vec3 c) {
	return pow(c, vec3(2.2));
}

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

// The clouds' noise: the one of their shadows.
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

float clouds_at(vec2 p) {
	return noise(p) * 0.55 + noise(p * 2.1 + 5.3) * 0.3 + noise(p * 4.3 + 1.7) * 0.15;
}

// A rotation of `v` about the north-south axis (z): the sky turning.
vec3 turned(vec3 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec3(c * v.x - s * v.y, s * v.x + c * v.y, v.z);
}

// The stars (and the milky way) in a direction, 0..1 brightness and tint;
// `pixel`: a screen pixel's size there (radians): a star stays about a
// pixel wide, zoomed in or not.
vec3 stars(vec3 eye, float pixel) {
	vec3 dir = turned(eye, star_turn);
	// The milky way: a faint band, crowded with stars.
	float band = 1.0 - smoothstep(0.0, 0.3, abs(dot(dir, normalize(vec3(0.3, 0.45, 0.84)))));
	vec3 light = vec3(0.0);
	light += lin(vec3(0.3, 0.28, 0.42)) * band * (0.5 + 0.5 * noise(dir.xy * 9.0 + dir.z * 4.0));
	vec3 p = dir * 95.0;
	vec3 cell = floor(p);
	float h = hash3(cell);
	float density = 0.012 + band * 0.02;
	if (h < density) {
		vec3 center = cell + 0.5 + (vec3(hash3(cell + 7.1), hash3(cell + 3.7), hash3(cell + 1.3)) - 0.5) * 0.5;
		if (length(p - center) < clamp(pixel * 95.0 * 0.7, 0.12, 0.55)) {
			float bright = 0.45 + 0.55 * hash3(cell + 9.9);
			bright *= 0.7 + 0.3 * sin(TIME * (1.5 + h * 300.0) + h * 900.0);
			vec3 tint = mix(vec3(0.8, 0.88, 1.0), vec3(1.0, 0.9, 0.75), hash3(cell + 4.4));
			light += tint * bright * 1.6;
		}
	}
	return light;
}

// The moon (its phase lit, seas darker, the dark side faint), and its
// halo; `cover`: how much of the moon's disk it is (0 off it).
vec3 moon(vec3 eye, out float cover) {
	cover = 0.0;
	float d = acos(clamp(dot(eye, moon_dir), -1.0, 1.0));
	vec3 light = lin(vec3(0.55, 0.62, 0.8)) * 0.1 * exp(-d * 14.0);
	if (d < MOON_RADIUS) {
		vec3 right = normalize(cross(moon_dir, vec3(0.0, 1.0, 0.0)) + vec3(1e-4, 0.0, 0.0));
		vec3 up = cross(right, moon_dir);
		vec2 uv = vec2(dot(eye, right), dot(eye, up)) / MOON_RADIUS;
		float r2 = dot(uv, uv);
		if (r2 < 1.0) {
			cover = 1.0;
			vec3 n = vec3(uv, sqrt(1.0 - r2));
			vec3 lit_from = vec3(sin(moon_light), 0.0, -cos(moon_light));
			float lit = step(0.0, dot(n, lit_from));
			// Seas: darker patches, in whole pixels of a 9 x 9 face.
			vec2 spot = floor(uv * 4.5);
			float sea = step(0.62, hash(spot + 13.0)) * 0.25 + step(0.8, hash(spot * 1.7)) * 0.15;
			vec3 face = lin(vec3(0.94, 0.94, 0.9) * (1.0 - sea));
			// Lit, bright but under the glow's threshold (no blur over it).
			light = mix(face * 0.04, face * 0.9, lit);
		}
	}
	return light;
}

void sky() {
	vec3 eye = EYEDIR;
	float up = max(eye.y, 0.0);
	// The gradient, and under the horizon the ground's color.
	vec3 color = mix(horizon_color, top_color, pow(up, 0.45));
	if (eye.y < 0.0) {
		color = mix(horizon_color, ground_color, smoothstep(0.0, 0.3, -eye.y));
	}
	// Rise and set: glows on the horizon, orange towards the sun, pink
	// around, and a pink band over the horizon opposite.
	vec2 flat_eye = normalize(eye.xz + vec2(1e-5));
	vec2 flat_sun = normalize(sun_dir.xz + vec2(1e-5));
	// Clamped: a hair under 0 opposite the sun, pow() makes NaN (white blots
	// once the glow spreads them).
	float toward = clamp(dot(flat_eye, flat_sun) * 0.5 + 0.5, 0.0, 1.0);
	float low = 1.0 - smoothstep(0.0, 0.5, abs(eye.y));
	vec3 glow = lin(mix(GLOW_PINK, GLOW_ORANGE, pow(toward, 4.0)));
	color = mix(color, glow, twilight * low * (0.25 + 0.75 * pow(toward, 2.5)) * (1.0 - storm * 0.7));
	float belt = smoothstep(0.02, 0.1, eye.y) * (1.0 - smoothstep(0.1, 0.3, eye.y));
	color = mix(color, lin(BELT), twilight * belt * pow(1.0 - toward, 3.0) * 0.6);
	// Stars, then the moon over them, then the sun.
	vec3 lights = vec3(0.0);
	if (night > 0.0 && eye.y > 0.0) {
		lights += stars(eye, length(fwidth(eye))) * night * smoothstep(0.0, 0.2, eye.y);
	}
	float moon_cover;
	vec3 moon_light_seen = moon(eye, moon_cover);
	float moon_up = smoothstep(-0.02, 0.04, moon_dir.y) * step(0.0, eye.y);
	lights = mix(lights, moon_light_seen, moon_cover * moon_up * night);
	lights += moon_light_seen * (1.0 - moon_cover) * moon_up * night;
	float d = acos(clamp(dot(eye, sun_dir), -1.0, 1.0));
	if (eye.y > -0.005) {
		// A disk and halos in steps, larger and redder when low.
		float halo = exp(-d * mix(7.0, 3.5, twilight));
		halo = floor(halo * 5.0) / 5.0;
		lights += sun_color * halo * 0.6 * (1.0 - storm * 0.8);
		if (d < SUN_RADIUS) {
			lights += sun_color * 5.0 * (1.0 - storm * 0.9);
		}
	}
	color += lights;
	// Clouds, high above, over everything but the horizon.
	if (eye.y > 0.01) {
		float t = (cloud_height - POSITION.y) / eye.y;
		vec2 hit = POSITION.xz + eye.xz * t;
		vec2 p = (hit - cloud_drift) * cloud_scale;
		float n = clouds_at(p);
		float edge = 1.0 - cloud_coverage * 0.8 - 0.15;
		float amount = smoothstep(edge, edge + 0.12, n);
		amount = floor(amount * 4.0 + 0.5) / 4.0;
		if (amount > 0.0) {
			// Lit where the cloud thins towards the light (sun, or moon).
			vec3 light_dir = night > 0.5 ? moon_dir : sun_dir;
			vec2 toward_light = normalize(light_dir.xz + vec2(1e-4)) * 0.05;
			float lit = clamp((n - clouds_at(p + toward_light)) * 9.0 + 0.55, 0.0, 1.0);
			lit = floor(lit * 3.0 + 0.5) / 3.0;
			vec3 day = lin(mix(vec3(0.97, 0.98, 1.0), vec3(1.0, 0.66, 0.55), twilight));
			vec3 dark = lin(mix(vec3(0.42, 0.44, 0.52), vec3(0.7, 0.72, 0.8), 1.0 - storm));
			dark = mix(dark, lin(vec3(0.62, 0.42, 0.52)), twilight);
			vec3 cloud = mix(dark, day, lit * (1.0 - storm * 0.6));
			// At night, barely lighter than the sky, lit by the moon.
			vec3 dim = lin(vec3(0.13, 0.15, 0.24) + vec3(0.08, 0.09, 0.12) * lit);
			cloud = mix(cloud, dim, night);
			float far = smoothstep(0.01, 0.12, eye.y);
			color = mix(color, cloud, amount * far * 0.95);
		}
	}
	COLOR = color;
}
