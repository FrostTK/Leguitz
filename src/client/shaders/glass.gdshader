shader_type spatial;
// The see-through part of glass (GlassFaces: ChunkMesher's GLASS meshes):
// the pixels of its art that are clear show what lies behind (the screen
// as drawn so far, like water.gdshader), through its tint and its style's
// (old glass greenish and wavy, leaded glass a little dimmer), with a soft
// sheen of the sky, brighter at a grazing angle and on a side's upper part,
// and the sun's glints (specular). Its opaque pixels (frames, lead,
// borders) are the face meshes' (terrain3d_faces.gdshader). UV: the face's
// pixels; UV2 = (face kind, edges + 16 for a top + 32 x (tint + 1) + 1024
// x style); COLOR.b the sky light.

render_mode cull_disabled;

#include "res://src/client/shaders/terrain3d_common.gdshaderinc"
#include "res://src/client/shaders/see_through.gdshaderinc"
#include "res://src/client/shaders/sky_light.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D face_atlas : source_color, filter_nearest;
uniform sampler2D wall_atlas : source_color, filter_nearest;
// The palette (Tints.COLORS), linear.
uniform vec3 tint_colors[16];
// How much a tint colors what is seen through it.
uniform float tint_strength = 0.72;
const int WALL_KIND_OFFSET = 4;
// Glass.Style.
const int OLD = 1;
const int LEADED = 2;
const int FRAMED = 3;
// How much of its own color tinted glass shows, lit.
const float STAINED = 0.3;

varying flat vec2 info;
varying flat float sky;

void vertex() {
	info = UV2;
	sky = COLOR.b;
}

// Whether a pixel lies on an edge of the face that goes on into the same
// glass (GlassFaces.edges): its border is not drawn there.
bool goes_on(int edges, ivec2 px) {
	return (px.y == 0 && (edges & 1) != 0) || (px.y == 15 && (edges & 2) != 0)
			|| (px.x == 0 && (edges & 4) != 0) || (px.x == 15 && (edges & 8) != 0);
}

void fragment() {
	if (above_cut(VERTEX, INV_VIEW_MATRIX)
			|| hides_player(VERTEX, VIEW_MATRIX, INV_VIEW_MATRIX, see_through_size, 0.0, FRAGCOORD.xy)) {
		discard;
	}
	int packed = int(info.y + 0.5);
	int style = packed / 1024;
	int rest = packed - style * 1024;
	int tint = rest / 32 - 1;
	int bits = rest - (rest / 32) * 32;
	bool top = (bits & 16) != 0;
	int edges = bits & 15;
	int kind = int(info.x + 0.5);
	ivec2 px = ivec2(floor(UV)) & ivec2(15);
	vec4 texel = top
			? texelFetch(wall_atlas, ivec2(px.x, (kind - WALL_KIND_OFFSET) * 16 + px.y), 0)
			: texelFetch(face_atlas, ivec2(px.x, kind * 16 + px.y), 0);
	bool border = style != FRAMED && goes_on(edges, px);
	if (texel.a >= 0.5 && !border) {
		discard;
	}
	// Old glass: blown, wavy; what lies behind wobbles by a pixel or two.
	vec2 offset = vec2(0.0);
	if (style == OLD) {
		vec2 wave = vec2(value_noise(vec2(px) * 0.35 + 3.1), value_noise(vec2(px.yx) * 0.35 + 7.7));
		offset = (wave - 0.5) * 3.0 / VIEWPORT_SIZE;
	}
	vec3 seen = textureLod(screen_texture, SCREEN_UV + offset, 0.0).rgb;
	vec3 tinted = tint >= 0 ? tint_colors[tint] : vec3(1.0);
	vec3 through = mix(vec3(1.0), tinted, tint >= 0 ? tint_strength : 0.0);
	if (style == OLD) {
		through *= vec3(0.86, 0.95, 0.86);
	} else if (style == LEADED) {
		through *= 0.92;
	}
	// The sky's sheen: brighter grazing, and on a side's upper part.
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float grazing = pow(1.0 - facing, 3.0);
	float upper = top ? 0.0 : 0.05 * (1.0 - float(px.y) / 15.0);
	float sheen = clamp(0.04 + 0.3 * grazing + upper, 0.0, 0.5);
	// Stained glass glows with its own color too where the light falls.
	float body = tint >= 0 ? max(sheen, STAINED) : sheen;
	EMISSION = seen * through * (1.0 - body);
	ALBEDO = (tint >= 0 ? tinted : vec3(0.7, 0.82, 0.9)) * body;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	AO = sky_ambient(sky);
	AO_LIGHT_AFFECT = 0.0;
}
