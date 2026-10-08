shader_type spatial;
// A block held in first person (HeldView): a cube wearing the block's
// texture (ItemLibrary._cube), drawn as the view model (view_model.gdshaderinc).

render_mode cull_disabled;

#include "res://src/client/shaders/view_model.gdshaderinc"
#include "res://src/client/shaders/sky_light.gdshaderinc"

uniform sampler2D albedo_texture : source_color, filter_nearest;
// Glass: its clear pixels are cut out.
uniform bool scissor = false;
uniform float view_model_fov = 70.0;
// The sky light the player stands in (0..1): darker in a cave.
uniform float sky_light = 1.0;
// Reddens it (the player hurt).
uniform float hurt = 0.0;

void vertex() {
	POSITION = view_model_position(PROJECTION_MATRIX, MODELVIEW_MATRIX * vec4(VERTEX, 1.0),
			view_model_fov);
}

void fragment() {
	vec4 color = texture(albedo_texture, UV);
	if (scissor && color.a < 0.5) {
		discard;
	}
	ALBEDO = mix(color.rgb, vec3(0.75, 0.04, 0.03), hurt * 0.6);
	AO = sky_ambient(sky_light);
	AO_LIGHT_AFFECT = 0.0;
	ROUGHNESS = 0.9;
}
