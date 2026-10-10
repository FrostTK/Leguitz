// The voxel models' shader (voxel.gdshader; voxel_view.gdshader with
// VIEW_MODEL defined: what is in hand in first person; voxel_painted.gdshader
// with PAINTED defined: the boats).
#include "res://src/client/shaders/see_through.gdshaderinc"
#include "res://src/client/shaders/sky_light.gdshaderinc"
#ifdef VIEW_MODEL
#include "res://src/client/shaders/view_model.gdshaderinc"
#endif

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
#ifdef VIEW_MODEL
// First person: what is in hand and the arm (HeldView), drawn with a field
// of view of their own and in front of the world (view_model.gdshaderinc).
uniform float view_model_fov = 70.0;
#endif
// How much the voxels' ambient occlusion also dims direct light.
const float OCCLUSION_LIGHT = 0.55;
#ifdef PAINTED
// A boat's paint (sRGB; alpha 0: bare wood) on its PAINT and STRIPE voxels
// (UV.y 3 and 4), shaded like the planks it covers (their brightness
// against PAINT_LUMA). Instance uniforms take room for every instance
// drawn with the shader: only the boats' (PAINTED) have them.
instance uniform vec4 paint_color = vec4(0.0);
instance uniform vec4 stripe_color = vec4(0.0);
const float PAINT_LUMA = 0.36;
#else
// Cloth dyed with a tint (ChunkProps: curtains, rugs): its PAINT voxels
// (UV.y 3) take the color given with the prop (INSTANCE_CUSTOM.rgb, sRGB)
// when INSTANCE_CUSTOM.a carries DYED (128), shaded as the undyed cloth is
// against DYE_LUMA.
const float DYE_LUMA = 0.78;
#endif

global uniform vec2 weather_wind;
global uniform float weather_wetness;
// The seasons (SeasonLook): deciduous leaves turn (season_autumn, 0 to 1)
// and fall (season_bare); snow lies on what faces the open sky where
// winters are not mild (season_snow); there the foliage takes the
// season's tint (season_grass, linear). Only props carry the bits saying
// whether they are deciduous and where winters bite (ChunkMesher).
global uniform float season_autumn;
global uniform float season_bare;
global uniform float season_snow;
global uniform vec3 season_grass;
// Autumn's leaves, from gold to red (sRGB), and snow.
const vec3 AUTUMN_GOLD = vec3(0.87, 0.66, 0.19);
const vec3 AUTUMN_ORANGE = vec3(0.82, 0.40, 0.11);
const vec3 AUTUMN_RED = vec3(0.62, 0.17, 0.09);
const vec3 SNOW = vec3(0.93, 0.95, 0.99);
// The open sky (sky light over a whole voxel) where snow lies.
const float SNOW_SKY = 0.9;

varying float foliage;
#ifdef PAINTED
varying float painted;
varying float striped;
#else
varying float dyed;
varying vec3 dye;
#endif
varying float glow;
varying vec3 tint;
varying float sky;
// Props: deciduous, where winters bite, a small plant the snow buries, a
// number of their own (0 to 1);
// the voxel a point lies in (local units x 16) and whether its face looks
// up.
varying float deciduous;
varying float wintry;
varying float buried;
varying float own;
varying vec3 voxel_at;
varying float upward;

// A number (0 to 1) of a voxel's own.
float voxel_hash(vec3 cell) {
	vec3 p = mod(cell, 251.0);
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	glow = step(1.5, UV.y) - step(2.5, UV.y);
	foliage = UV.y * (1.0 - step(1.5, UV.y));
#ifdef PAINTED
	painted = step(2.5, UV.y) - step(3.5, UV.y);
	striped = step(3.5, UV.y);
#else
	dyed = 0.0;
	dye = vec3(1.0);
#endif
	tint = vec3(1.0);
	float phase = 0.0;
	sky = sky_light;
	deciduous = 0.0;
	wintry = 0.0;
	buried = 0.0;
	own = 0.0;
	if (use_instance_data) {
		// Its alpha: the sky light (0 to 15) + 16 if deciduous + 32 where
		// winters bite + 64 a small plant the snow buries + 128 dyed, and
		// its wind phase as the fraction.
		tint = INSTANCE_CUSTOM.rgb;
		float bits = floor(INSTANCE_CUSTOM.a);
		own = fract(INSTANCE_CUSTOM.a);
		phase = own * 6.2832;
		sky = mod(bits, 16.0) / 15.0;
		deciduous = mod(floor(bits / 16.0), 2.0);
		wintry = mod(floor(bits / 32.0), 2.0);
		buried = mod(floor(bits / 64.0), 2.0);
#ifndef PAINTED
		if (bits >= 128.0) {
			dye = INSTANCE_CUSTOM.rgb;
			dyed = step(2.5, UV.y) - step(3.5, UV.y);
			tint = vec3(1.0);
		}
#endif
	}
	// Before the wind bends it: in the world's local units, steady.
	vec3 local_normal = normalize((world_to_local * vec4(NORMAL, 0.0)).xyz);
	voxel_at = (world_to_local * vec4(VERTEX, 1.0)).xyz * 16.0 - local_normal * 0.5;
	upward = local_normal.y;
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
#ifdef VIEW_MODEL
	POSITION = view_model_position(PROJECTION_MATRIX, VIEW_MATRIX * vec4(VERTEX, 1.0),
			view_model_fov);
#endif
}

void fragment() {
	float grain = voxel_hash(floor(voxel_at));
	bool leaf = foliage > 0.5 && deciduous > 0.5;
	// Fallen leaves are gone, small plants under the snow too (and their
	// shadows).
	if ((leaf && grain < season_bare) || (buried > 0.5 && sky > SNOW_SKY
			&& grain < season_snow * 1.3 - 0.2)) {
		discard;
	}
	if (fade > 0.0 && !IN_SHADOW_PASS && see_through_dither(FRAGCOORD.xy) < fade) {
		discard;
	}
	if (cut_out && !IN_SHADOW_PASS
			&& (above_cut(VERTEX, INV_VIEW_MATRIX)
			|| hides_player(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, cut_size, 0.6, FRAGCOORD.xy))) {
		discard;
	}
	vec3 base = COLOR.rgb;
#ifdef PAINTED
	vec4 coat = paint_color * painted + stripe_color * striped;
	if (coat.a > 0.5) {
		float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		base = coat.rgb * clamp(luma / PAINT_LUMA, 0.6, 1.35);
	}
#else
	if (dyed > 0.5) {
		float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
		base = dye * clamp(luma / DYE_LUMA, 0.45, 1.25);
	}
#endif
	if (leaf && season_autumn > 0.0) {
		// Each tree its hue, each leaf its moment, its shade kept.
		float turn = smoothstep(grain * 0.5, grain * 0.5 + 0.5, season_autumn);
		float pick = fract(own * 3.7 + grain * 0.3);
		vec3 hue = pick < 0.45
				? mix(AUTUMN_GOLD, AUTUMN_ORANGE, pick / 0.45)
				: mix(AUTUMN_ORANGE, AUTUMN_RED, (pick - 0.45) / 0.55);
		float luma = dot(base, vec3(0.299, 0.587, 0.114));
		base = mix(base, hue * clamp(luma / 0.42, 0.55, 1.35), turn);
	}
	bool snowed = wintry > 0.5 && upward > 0.5 && sky > SNOW_SKY
			&& grain < season_snow * 1.15 - 0.1;
	if (snowed) {
		base = SNOW * (0.92 + 0.08 * grain);
	}
	vec3 albedo = srgb_to_linear(base) * tint;
	if (foliage > 0.5 && !snowed) {
		albedo *= mix(vec3(1.0), season_grass, wintry);
	}
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
