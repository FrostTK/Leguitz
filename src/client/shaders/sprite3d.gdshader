shader_type spatial;
// Upright pixel-art sprites (trees, plants, props, characters): vertical
// quads standing on their base point and turned towards the camera around
// the vertical axis. One MultiMesh instance per sprite, whose transform
// only places the base point; INSTANCE_CUSTOM = (atlas cell x, atlas
// cell y, sway amount, 1 = casts no shadow). Alpha-scissored, so they cast
// real shadows (in the shadow pass they turn towards the light instead).

render_mode cull_disabled, world_vertex_coords;

uniform sampler2D atlas : source_color, filter_nearest;
uniform sampler2D atlas_normals : filter_nearest;
uniform vec2 cells = vec2(16.0, 3.0);
// Size of one sprite in art pixels.
uniform vec2 sprite_px = vec2(32.0, 48.0);
uniform float pixels_per_unit = 16.0;
// Height stretch of the 3D view (see Render3D.vertical_scale).
uniform float vertical_scale = 2.0;
// Horizontal sway at the top of a full-height sprite, in art pixels.
uniform float sway_pixels = 1.2;
// Light normal of the sprites: tilted up and towards the viewer, so they
// catch the overhead sun like the ground around them.
uniform float normal_lift = 0.75;

global uniform vec2 weather_wind;

varying vec3 light_normal;

void vertex() {
	// The quad's corner from its UV: x -0.5..0.5, height 0..1.
	vec2 corner = vec2(UV.x - 0.5, 1.0 - UV.y);
	UV = (INSTANCE_CUSTOM.xy + UV) / cells;
	vec3 base = MODEL_MATRIX[3].xyz;
	vec2 size = sprite_px / pixels_per_unit;
	size.y *= vertical_scale;
	float x = corner.x;
	if (INSTANCE_CUSTOM.z > 0.0) {
		float phase = base.x * 0.71 + base.z * 1.13;
		float strength = length(weather_wind);
		float wave = sin(TIME * 1.7 + phase) * 0.7 + sin(TIME * 2.9 + phase * 1.3) * 0.3;
		float gust = 0.6 + 0.8 * (sin(TIME * 0.35 + base.x * 0.05) * 0.5 + 0.5);
		float offset_px = wave * sway_pixels * strength * gust * corner.y * corner.y;
		x += offset_px / sprite_px.x * INSTANCE_CUSTOM.z;
	}
	// Horizontal direction towards the viewer (the camera, or the light in
	// the shadow pass).
	vec2 towards = normalize(INV_VIEW_MATRIX[2].xz + vec2(0.0, 1e-4));
	vec2 right = vec2(towards.y, -towards.x);
	vec2 ground = right * x * size.x;
	if (IN_SHADOW_PASS) {
		// Flat or tiny sprites cast no shadow; the others put their shadow
		// caster a bit behind themselves so they do not shadow themselves.
		if (INSTANCE_CUSTOM.w > 0.5) {
			size.y = 0.0;
			ground = vec2(0.0);
		}
		ground -= towards * size.x * 0.25;
	}
	VERTEX = base + vec3(ground.x, corner.y * size.y, ground.y);
	vec2 main_towards = normalize(MAIN_CAM_INV_VIEW_MATRIX[2].xz + vec2(0.0, 1e-4));
	light_normal = normalize(vec3(main_towards.x, normal_lift, main_towards.y) * vec3(0.66, 1.0, 0.66));
	NORMAL = light_normal;
	TANGENT = vec3(right.x, 0.0, right.y);
	BINORMAL = vec3(0.0, -1.0, 0.0);
}

void fragment() {
	vec4 color = texture(atlas, UV);
	if (color.a < 0.5) {
		discard;
	}
	ALBEDO = color.rgb;
	NORMAL_MAP = texture(atlas_normals, UV).rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
