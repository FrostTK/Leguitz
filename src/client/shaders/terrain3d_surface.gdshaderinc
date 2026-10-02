// Shared by the terrain top and water shaders: the chunk's surface map and
// how grounds meet at their borders.
//
// `chunk_data` is an 18x18 float texture (the chunk plus a 1-tile border,
// see ChunkMesher.surface_map): r = ground id, g = wall kind + 1 (0 =
// none), b = level of the visible top of the column, a = the bed under
// its water if it is clear water (see bed_of), 0 otherwise.

uniform sampler2D chunk_data : filter_nearest;
uniform vec2 chunk_origin_px = vec2(0.0);
// Per ground id: blend priority, kind (0 land, 1 water, 2 lava, 3 ice).
uniform int ground_priority[64];
uniform int ground_kind[64];

const int WALL_CODE = 64;
const int KIND_WATER = 1;
const int KIND_LAVA = 2;
const int KIND_ICE = 3;

// The column at a tile of the chunk (-1..16: the border too).
ivec4 column_at(ivec2 tile) {
	return ivec4(round(texelFetch(chunk_data, tile + ivec2(1), 0)));
}

// The bed under a column's water, as a column of its own (ground, wall
// kind + 1, level); the column itself where there is no water.
ivec4 bed_of(ivec4 column) {
	if (column.a <= 0) {
		return column;
	}
	int rest = column.a / 256;
	return ivec4(rest % 64, column.a % 256, rest / 64 - 256, 0);
}

// Height rank of a column: level, plus half a level for a rock wall.
int top_rank(ivec4 column) {
	return column.b * 2 + (column.g != 0 ? 2 : 0);
}

// Terrace edges seen from above: a light rim where the ground drops away,
// a contact shadow at the foot of a higher terrace or wall. They outline
// the terraces whatever the camera angle.
float edge_shade(ivec4 n[9], ivec2 tx) {
	int here = top_rank(n[4]);
	float shade = 1.0;
	// North, west, east, south neighbors and the distance to that edge.
	int sides[4] = int[](1, 3, 5, 7);
	int dist[4] = int[](tx.y, tx.x, 15 - tx.x, 15 - tx.y);
	for (int k = 0; k < 4; k++) {
		int other = top_rank(n[sides[k]]);
		if (other > here) {
			shade *= dist[k] == 0 ? 0.72 : (dist[k] == 1 ? 0.88 : 1.0);
		} else if (other < here && dist[k] == 0) {
			shade *= 1.12;
		}
	}
	return shade;
}

// How grounds meet at art pixel `tx` of the middle column of `n` (the 3x3
// columns around it; `wp`: world pixel): a higher-priority neighbor on the
// same level spreads into the tile by a wobbly margin. Returns the ground
// drawn there, how far inside that margin (0 for the tile's own ground)
// and, on water, the distance to the nearest shore (-1: none).
vec3 blend_ground(ivec4 n[9], ivec2 tx, vec2 wp) {
	vec2 f = (vec2(tx) + 0.5) / 16.0;
	float wobble = value_noise(wp * 0.3) * 0.6 + value_noise(wp * 0.11 + 17.0) * 0.4;
	float reach = 0.16 + 0.24 * wobble;
	int ground = n[4].r;
	int level = n[4].b;
	int best = ground;
	int best_priority = ground_priority[ground];
	float best_depth = 0.0;
	float foam_margin = -1.0;
	bool water_here = ground_kind[ground] == KIND_WATER;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (dx == 0 && dy == 0) {
				continue;
			}
			ivec4 other = n[(dy + 1) * 3 + (dx + 1)];
			float d;
			if (dx != 0 && dy != 0) {
				vec2 corner = vec2(dx > 0 ? 1.0 : 0.0, dy > 0 ? 1.0 : 0.0);
				d = distance(f, corner) * 1.1;
			} else if (dx != 0) {
				d = dx > 0 ? 1.0 - f.x : f.x;
			} else {
				d = dy > 0 ? 1.0 - f.y : f.y;
			}
			bool neighbor_land = other.g != 0 || ground_kind[other.r] != KIND_WATER;
			if (water_here && neighbor_land) {
				float margin = d - (other.g != 0 || other.b != level ? 0.0 : reach);
				foam_margin = foam_margin < 0.0 ? margin : min(foam_margin, margin);
			}
			if (other.g != 0 || other.b != level) {
				continue;
			}
			int priority = ground_priority[other.r];
			if (priority <= best_priority || d >= reach) {
				continue;
			}
			best = other.r;
			best_priority = priority;
			best_depth = reach - d;
		}
	}
	return vec3(float(best), best_depth, foam_margin);
}
