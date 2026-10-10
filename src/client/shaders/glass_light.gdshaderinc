// Sunlight through tinted glass (GlassLight, asked by the owner: natural
// colored light). Tinted glass keeps the sun's white light out (it casts
// its shadow: terrain3d_faces' frame pass) and what lies behind it gets the
// sun's light through it in its color instead, as emission: albedo x the
// sun x the glass's color x the angle, so its texture stays. A fragment
// looks towards the sun through `glass_cells`, a 3D texture of the cells
// around the tinted glass near the player (a texel: R the face kind whose
// art masks the light, 0 nothing, 255 opaque; G the tint + 1; B the pane's
// plane, 1 across z, 2 across x, + 4 a window: framed), cell by cell (a
// DDA), only when its ray meets the tinted glass's box (glass_box_*). The
// art's opaque pixels (frames, lead) stop the light, as their shadows do;
// clear glass's border does not (glass goes on). Local units throughout
// (world_to_local, see_through.gdshaderinc); colors linear
// (glass_palette). Include after see_through.gdshaderinc.

global uniform float glass_light_on;
global uniform highp sampler3D glass_cells;
global uniform sampler2D glass_art;
global uniform sampler2D glass_palette;
global uniform vec3 glass_origin;
global uniform vec3 glass_size;
global uniform vec3 glass_box_min;
global uniform vec3 glass_box_max;
global uniform vec3 glass_to_sun;
global uniform vec3 glass_sun_world;
global uniform vec3 glass_sun_color;

const int GLASS_STEPS = 48;
const int GLASS_OPAQUE = 255;

// Whether the art pixel at `uv` (0 to 1 across the face, v down) of a face
// kind stops the light.
bool glass_stops(int kind, vec2 uv, bool framed) {
	ivec2 px = clamp(ivec2(floor(uv * 16.0)), ivec2(0), ivec2(15));
	if (!framed && (px.x == 0 || px.y == 0 || px.x == 15 || px.y == 15)) {
		return false;
	}
	return texelFetch(glass_art, ivec2(px.x, kind * 16 + px.y), 0).a >= 0.5;
}

// [entry, exit] of a ray (origin, 1 / direction) through a box; exit <
// entry: missed.
vec2 glass_span(vec3 origin, vec3 inv, vec3 low, vec3 high) {
	vec3 a = (low - origin) * inv;
	vec3 b = (high - origin) * inv;
	vec3 near = min(a, b);
	vec3 far = max(a, b);
	return vec2(max(max(near.x, near.y), near.z), min(min(far.x, far.y), far.z));
}

// Where a ray crosses a cell's face on `axis` (`f`: the point, from the
// cell's corner): the face's art coordinates (v down on the sides).
vec2 glass_face_uv(vec3 f, int axis) {
	if (axis == 1) {
		return f.xz;
	}
	return vec2(axis == 0 ? f.z : f.x, 1.0 - f.y);
}

// The color of the sun's light reaching `local` (local units, `normal` its
// local normal) through tinted glass; black where none comes. The art is
// read where the glass has faces (GlassFaces): coming into glass and going
// out of it, not between two cells of the same glass in the same tint (one
// pane: its color counts once); a pane where the ray crosses its middle.
vec3 glass_light_at(vec3 local, vec3 normal) {
	vec3 dir = glass_to_sun;
	dir = sign(dir) * max(abs(dir), vec3(1e-5)) + vec3(1e-5) * (1.0 - abs(sign(dir)));
	vec3 inv = 1.0 / dir;
	vec3 start = local + normal * 0.02;
	vec2 box = glass_span(start, inv, glass_box_min, glass_box_max);
	if (box.y < max(box.x, 0.0)) {
		return vec3(0.0);
	}
	vec3 q = start - glass_origin;
	vec2 span = glass_span(q, inv, vec3(0.0), glass_size);
	if (span.y < max(span.x, 0.0)) {
		return vec3(0.0);
	}
	float t = max(span.x, 0.0) + 1e-4;
	ivec3 size = ivec3(glass_size + 0.5);
	ivec3 cell = ivec3(floor(q + dir * t));
	ivec3 step_by = ivec3(sign(dir));
	vec3 delta = abs(inv);
	vec3 next = (vec3(cell) + max(sign(dir), vec3(0.0)) - q) * inv;
	int axis = -1;
	vec3 light = vec3(1.0);
	bool tinted = false;
	// The cell the ray comes from: its kind, tint, shape, corner.
	int was_kind = 0;
	int was_tint = -1;
	int was_info = 0;
	ivec3 was_cell = cell;
	for (int i = 0; i < GLASS_STEPS; i++) {
		bool inside = all(greaterThanEqual(cell, ivec3(0))) && all(lessThan(cell, size));
		vec4 texel = inside ? texelFetch(glass_cells, cell, 0) : vec4(0.0);
		int kind = int(texel.r * 255.0 + 0.5);
		if (kind == GLASS_OPAQUE) {
			return vec3(0.0);
		}
		int tint = int(texel.g * 255.0 + 0.5) - 1;
		int info = int(texel.b * 255.0 + 0.5);
		bool same = kind > 0 && kind == was_kind && tint == was_tint && info == was_info;
		float leaves = min(next.x, min(next.y, next.z));
		if (axis >= 0 && !same) {
			vec3 here = q + dir * t;
			// Out of a glass cube: through its face.
			if (was_kind > 0 && (was_info & 3) == 0) {
				vec2 uv = glass_face_uv(here - vec3(was_cell), axis);
				if (glass_stops(was_kind, uv, (was_info & 4) != 0)) {
					return vec3(0.0);
				}
			}
			if (kind > 0) {
				int pane = info & 3;
				bool crosses = true;
				vec2 uv = glass_face_uv(here - vec3(cell), axis);
				if (pane != 0) {
					// A pane: where the ray crosses its middle plane.
					float from = pane == 1 ? q.z : q.x;
					float across = pane == 1 ? inv.z : inv.x;
					float plane = float(pane == 1 ? cell.z : cell.x) + 0.5;
					float at = (plane - from) * across;
					crosses = at >= t && at <= leaves;
					vec3 f = q + dir * at - vec3(cell);
					uv = vec2(pane == 1 ? f.x : f.z, 1.0 - f.y);
				}
				if (crosses) {
					if (glass_stops(kind, uv, (info & 4) != 0)) {
						return vec3(0.0);
					}
					if (tint >= 0) {
						light *= texelFetch(glass_palette, ivec2(tint, 0), 0).rgb;
						tinted = true;
					}
				}
			}
		}
		if (!inside && axis >= 0) {
			break;
		}
		was_kind = kind;
		was_tint = tint;
		was_info = info;
		was_cell = cell;
		if (next.x <= next.y && next.x <= next.z) {
			cell.x += step_by.x;
			t = next.x;
			next.x += delta.x;
			axis = 0;
		} else if (next.y <= next.z) {
			cell.y += step_by.y;
			t = next.y;
			next.y += delta.y;
			axis = 1;
		} else {
			cell.z += step_by.z;
			t = next.z;
			next.z += delta.z;
			axis = 2;
		}
	}
	return tinted ? light : vec3(0.0);
}


// The colored sunlight a fragment gets through tinted glass (to multiply
// by its albedo and add as emission); `vertex` and `normal` in view space.
vec3 glass_light(vec3 vertex, vec3 normal, mat4 inv_view) {
	vec3 world_normal = normalize(mat3(inv_view) * normal);
	float facing = dot(world_normal, glass_sun_world);
	if (facing <= 0.0) {
		return vec3(0.0);
	}
	vec3 world = (inv_view * vec4(vertex, 1.0)).xyz;
	vec3 local = (world_to_local * vec4(world, 1.0)).xyz;
	vec3 local_normal = normalize((world_to_local * vec4(world_normal, 0.0)).xyz);
	return glass_light_at(local, local_normal) * glass_sun_color * facing;
}
