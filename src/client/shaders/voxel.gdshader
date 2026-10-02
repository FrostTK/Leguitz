shader_type spatial;
// Voxel models (trees, plants, rocks, the player). Vertex data comes from
// VoxelMesher: COLOR.rgb sRGB color, COLOR.a ambient occlusion,
// UV.x wind bending weight, UV.y 1 for foliage, 2 for glowing voxels (fire:
// they light themselves). Instances may carry
// INSTANCE_CUSTOM = (tint r, g, b, sky light level + wind phase): props
// (ChunkMesher) carry the sky light they stand in (0..15, the integer
// part; see sky_light.gdshaderinc), bodies are given theirs (sky_light).

render_mode world_vertex_coords;

#include "res://src/client/shaders/see_through.gdshaderinc"
#include "res://src/client/shaders/sky_light.gdshaderinc"

// Wind bending at weight 1, in world units.
uniform float sway_distance = 0.11;
// Per-instance tint and phase (props) or plain (the player).
uniform bool use_instance_data = true;
uniform float wet_darkening = 0.22;
// See-through hole around the player when something stands between the
// camera and them (trees...). Off for the player's own body.
uniform bool cut_out = true;
// Half width and half height of the hole (world units, on screen).
uniform vec2 cut_size = vec2(1.5, 2.1);
// How bright glowing voxels are.
uniform float glow_strength = 3.0;
// Dithers the model away (the player's body while the camera dives into
// its head): 0 = shown, 1 = gone. Its shadow stays.
uniform float fade = 0.0;
// Reddens the model (the player hurt): 0 = not at all, 1 = most.
uniform float hurt = 0.0;
// The sky light where the model stands (0..1) when no instance data
// carries it: the player's and the creatures' bodies, in a cave.
uniform float sky_light = 1.0;
// How much the voxels' ambient occlusion also dims direct light.
const float OCCLUSION_LIGHT = 0.55;

global uniform vec2 weather_wind;
global uniform float weather_wetness;

varying float foliage;
varying float glow;
varying vec3 tint;
varying float sky;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	glow = step(1.5, UV.y);
	foliage = UV.y * (1.0 - glow);
	tint = vec3(1.0);
	float phase = 0.0;
	sky = sky_light;
	if (use_instance_data) {
		tint = INSTANCE_CUSTOM.rgb;
		phase = fract(INSTANCE_CUSTOM.a) * 6.2832;
		sky = floor(INSTANCE_CUSTOM.a) / 15.0;
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

void fragment() {
	if (fade > 0.0 && !IN_SHADOW_PASS && see_through_dither(FRAGCOORD.xy) < fade) {
		discard;
	}
	if (cut_out && !IN_SHADOW_PASS
			&& (above_cut(VERTEX, INV_VIEW_MATRIX)
			|| hides_player(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, cut_size, 0.6, FRAGCOORD.xy))) {
		discard;
	}
	vec3 albedo = srgb_to_linear(COLOR.rgb) * tint;
	albedo = mix(albedo, vec3(0.75, 0.04, 0.03), hurt * 0.6);
	albedo *= 1.0 - wet_darkening * weather_wetness * (1.0 - foliage * 0.5);
	// The occlusion dims direct light a little (through the albedo) and the
	// ambient light fully, as much as the sky light lets it in (AO).
	float direct = mix(1.0, COLOR.a, OCCLUSION_LIGHT);
	albedo *= direct;
	ALBEDO = albedo;
	AO = sky_ambient(sky) * COLOR.a / direct;
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = mix(0.85, 0.45, weather_wetness * (1.0 - foliage));
	SPECULAR = 0.3;
	// Light shines through leaves (bright edges against the sun).
	BACKLIGHT = albedo * 0.55 * foliage;
	EMISSION = srgb_to_linear(COLOR.rgb) * glow * glow_strength;
}
