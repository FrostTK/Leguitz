shader_type spatial;
// Voxel models (trees, plants, rocks, the player). Vertex data comes from
// VoxelMesher: COLOR.rgb sRGB color, COLOR.a ambient occlusion,
// UV.x wind bending weight, UV.y 1 for foliage. Instances may carry
// INSTANCE_CUSTOM = (tint r, g, b, wind phase).

render_mode world_vertex_coords;

// Wind bending at weight 1, in world units.
uniform float sway_distance = 0.11;
// Per-instance tint and phase (props) or plain (the player).
uniform bool use_instance_data = true;
uniform float wet_darkening = 0.22;
// See-through hole around the player when something stands between the
// camera and them (trees...). Off for the player's own body.
uniform bool cut_out = true;
uniform float cut_radius = 2.4;

global uniform vec2 weather_wind;
global uniform float weather_wetness;
// The player's chest, in world space.
global uniform vec3 player_position;

varying float foliage;
varying vec3 tint;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	foliage = UV.y;
	tint = vec3(1.0);
	float phase = 0.0;
	if (use_instance_data) {
		tint = INSTANCE_CUSTOM.rgb;
		phase = INSTANCE_CUSTOM.a * 6.2832;
	}
	float weight = UV.x;
	if (weight > 0.0) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float strength = 0.35 + length(weather_wind);
		vec2 wind = weather_wind / max(length(weather_wind), 0.001);
		float t = TIME + phase;
		float wave = sin(t * 1.7 + origin.x * 0.31 + origin.z * 0.47) * 0.65
				+ sin(t * 2.9 + origin.x * 0.17) * 0.35;
		// A steady lean with the wind, plus the gusts.
		vec2 push = wind * (0.45 + 0.55 * wave) * strength;
		// Leaves flutter a little on their own.
		float flutter = sin(t * 7.0 + VERTEX.y * 9.0 + VERTEX.x * 5.0) * 0.15 * foliage;
		VERTEX.xz += (push + vec2(flutter)) * weight * sway_distance;
	}
}

// 4x4 ordered dither threshold (0..1) of a screen pixel.
float dither(vec2 fragcoord) {
	ivec2 p = ivec2(fragcoord) & ivec2(3);
	int index = p.x + p.y * 4;
	int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(bayer[index]) + 0.5) / 16.0;
}

void fragment() {
	if (cut_out && !IN_SHADOW_PASS) {
		// Orthographic view: view-space x/y distances are screen distances.
		vec3 player_view = (VIEW_MATRIX * vec4(player_position, 1.0)).xyz;
		float d = length(VERTEX.xy - player_view.xy) / cut_radius;
		if (d < 1.0 && VERTEX.z > player_view.z + 0.6) {
			if (dither(FRAGCOORD.xy) > smoothstep(0.6, 1.0, d)) {
				discard;
			}
		}
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb) * tint;
	albedo *= 1.0 - wet_darkening * weather_wetness * (1.0 - foliage * 0.5);
	ALBEDO = albedo;
	AO = COLOR.a;
	AO_LIGHT_AFFECT = 0.55;
	ROUGHNESS = mix(0.85, 0.45, weather_wetness * (1.0 - foliage));
	SPECULAR = 0.3;
	// Light shines through leaves (bright edges against the sun).
	BACKLIGHT = albedo * 0.55 * foliage;
}
