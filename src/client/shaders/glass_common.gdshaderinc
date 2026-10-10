// The see-through part of glass (GlassFaces: ChunkMesher's GLASS meshes),
// shared by its two passes. It never reads the screen (that copy is made
// before water and other glass are drawn: they did not show through it);
// it blends over what is drawn behind it instead: glass.gdshader multiplies
// it by the glass's tint (`through_of`), then glass_sheen.gdshader lays the
// glass's own sheen over it (`body_of`: how much of the glass shows, lit).
// Its opaque pixels (frames, lead, borders) are the face meshes'
// (terrain3d_faces.gdshader). UV: the face's pixels; UV2 = (face kind,
// edges + 16 for a top + 32 x (tint + 1) + 1024 x style); COLOR.b the sky
// light.

#include "res://src/client/shaders/terrain3d_common.gdshaderinc"
#include "res://src/client/shaders/see_through.gdshaderinc"

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

// What `info` packs: the style, the tint (-1 none), whether it is a top.
int style_of() {
	return int(info.y + 0.5) / 1024;
}

int tint_of() {
	return (int(info.y + 0.5) % 1024) / 32 - 1;
}

bool top_of() {
	return (int(info.y + 0.5) & 16) != 0;
}

// Whether the pixel `px` of the face is clear glass (else the face meshes
// draw it).
bool is_clear(ivec2 px) {
	int bits = int(info.y + 0.5) % 32;
	int kind = int(info.x + 0.5);
	vec4 texel = top_of()
			? texelFetch(wall_atlas, ivec2(px.x, (kind - WALL_KIND_OFFSET) * 16 + px.y), 0)
			: texelFetch(face_atlas, ivec2(px.x, kind * 16 + px.y), 0);
	bool border = style_of() != FRAMED && goes_on(bits & 15, px);
	return texel.a < 0.5 || border;
}

// Old glass is blown, wavy: ripples running across it.
float ripple(ivec2 px) {
	return value_noise(vec2(float(px.x) * 0.18, float(px.y) * 0.55) + 3.1);
}

// What lies behind is multiplied by this: the tint and the style's (old
// glass greenish and rippled, leaded glass a little dimmer).
vec3 through_of(ivec2 px) {
	int tint = tint_of();
	vec3 through = tint >= 0 ? mix(vec3(1.0), tint_colors[tint], tint_strength) : vec3(1.0);
	int style = style_of();
	if (style == OLD) {
		through *= vec3(0.86, 0.95, 0.86) * (0.9 + 0.2 * ripple(px));
	} else if (style == LEADED) {
		through *= 0.92;
	}
	return through;
}

// How much the glass itself shows over what lies behind: the sky's sheen,
// brighter grazing and on a side's upper part (old glass's ripples catch
// it); stained glass glows with its own color too where the light falls.
float body_of(ivec2 px, vec3 normal, vec3 view) {
	float facing = clamp(abs(dot(normalize(normal), normalize(view))), 0.0, 1.0);
	float grazing = pow(1.0 - facing, 3.0);
	float upper = top_of() ? 0.0 : 0.05 * (1.0 - float(px.y) / 15.0);
	float sheen = 0.04 + 0.3 * grazing + upper;
	if (style_of() == OLD) {
		sheen += 0.05 * ripple(px);
	}
	sheen = clamp(sheen, 0.0, 0.5);
	return tint_of() >= 0 ? max(sheen, STAINED) : sheen;
}
