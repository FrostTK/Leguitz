shader_type spatial;
// Upright pixel-art sprites (trees, plants, props, characters) drawn as
// vertical quads facing the camera side (+Z). One MultiMesh instance per
// sprite; INSTANCE_CUSTOM = (atlas cell x, atlas cell y, sway amount,
// 1 = casts no shadow). Alpha-scissored, so they cast real shadows.

render_mode cull_disabled;

uniform sampler2D atlas : source_color, filter_nearest;
uniform sampler2D atlas_normals : filter_nearest;
uniform vec2 cells = vec2(16.0, 3.0);
// Horizontal sway at the top of a full-height sprite, in art pixels.
uniform float sway_pixels = 1.2;
uniform float sprite_width_px = 32.0;
// Light normal of the sprites (world space): tilted up, so they catch the
// overhead sun like the ground around them.
uniform vec3 light_normal = vec3(0.0, 0.75, 0.66);

global uniform vec2 weather_wind;

void vertex() {
	float height = 1.0 - UV.y;
	UV = (INSTANCE_CUSTOM.xy + UV) / cells;
	float x = VERTEX.x;
	if (INSTANCE_CUSTOM.z > 0.0) {
		vec3 origin = MODEL_MATRIX[3].xyz;
		float phase = origin.x * 0.71 + origin.z * 1.13;
		float strength = length(weather_wind);
		float wave = sin(TIME * 1.7 + phase) * 0.7 + sin(TIME * 2.9 + phase * 1.3) * 0.3;
		float gust = 0.6 + 0.8 * (sin(TIME * 0.35 + origin.x * 0.05) * 0.5 + 0.5);
		float offset_px = wave * sway_pixels * strength * gust * height * height;
		x += offset_px / sprite_width_px * INSTANCE_CUSTOM.z;
	}
	VERTEX.x = x;
	if (IN_SHADOW_PASS) {
		if (INSTANCE_CUSTOM.w > 0.5) {
			// Flat or tiny: no shadow at all.
			VERTEX = vec3(0.0);
		} else {
			// Turn the shadow caster towards the light, so morning and
			// evening shadows keep the whole silhouette, and put it a bit
			// behind the sprite so the sprite does not shadow itself.
			float width = length(MODEL_MATRIX[0].xyz);
			float depth_scale = length(MODEL_MATRIX[2].xyz);
			vec2 towards = normalize(INV_VIEW_MATRIX[2].xz + vec2(0.0, 1e-4));
			vec2 right = vec2(towards.y, -towards.x);
			float back = (0.1 + 0.4 * abs(towards.x)) * 0.5;
			vec2 offset = (right * x - towards * back) * width;
			VERTEX.x = offset.x / width;
			VERTEX.z = offset.y / depth_scale;
		}
	}
}

void fragment() {
	vec4 color = texture(atlas, UV);
	if (color.a < 0.5) {
		discard;
	}
	ALBEDO = color.rgb;
	NORMAL = normalize((VIEW_MATRIX * vec4(light_normal, 0.0)).xyz);
	NORMAL_MAP = texture(atlas_normals, UV).rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
