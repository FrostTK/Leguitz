// Painted plaster (Tints.painted; ChunkMesher.TINTED_CODE, TINTED_SIDE,
// ShapedFaces.TINTED_TOP): the light pixels of its texture take the tint,
// keeping their shading; dark ones (a timber frame's beams) keep their
// wood. Also the palette for a window's painted frame.

// The palette of tints (Tints.COLORS), linear.
uniform vec3 tint_colors[16];
// A painted top's material code: its own + TINTED_CODE x (tint + 1).
const int TINTED_CODE = 1024;
// Pixels darker than this (linear luma) are not painted; plaster's own
// luma, which the tint's color has.
const float PAINT_FROM = 0.25;
const float PLASTER_LUMA = 0.68;

vec3 painted(vec3 albedo, int tint) {
	float luma = dot(albedo, vec3(0.3, 0.59, 0.11));
	if (tint < 0 || luma < PAINT_FROM) {
		return albedo;
	}
	return tint_colors[min(tint, 15)] * clamp(luma / PLASTER_LUMA, 0.6, 1.2);
}
