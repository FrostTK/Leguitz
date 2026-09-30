// Shared terrain rendering logic (included by terrain and terrain_emission).
//
// Each chunk is drawn as one 256x256 px quad whose TEXTURE is an 18x18 float
// data texture (the chunk plus a 1-tile border), one texel per tile:
//   r = ground id, g = wall kind + 1 (0 = no wall), b = terrace level,
//   a = shape flags (cliff edges, ramp, shadow).
// Everything is computed per art pixel so the result stays crisp pixel art.

uniform sampler2D ground_atlas : source_color, filter_nearest;
uniform sampler2D ground_normals : filter_nearest;
uniform sampler2D wall_atlas : source_color, filter_nearest;
uniform sampler2D wall_normals : filter_nearest;
uniform sampler2D wall_emission : source_color, filter_nearest;
uniform sampler2D cliff_atlas : source_color, filter_nearest;
uniform sampler2D cliff_normals : filter_nearest;

// Per ground id: blend priority, kind (0 land, 1 water, 2 lava, 3 ice),
// cliff material (0 dirt, 1 stone, 2 sand, 3 snow) and water color.
uniform int ground_priority[32];
uniform int ground_kind[32];
uniform int cliff_material[32];
uniform vec4 water_colors[32];

uniform float wetness = 0.0;
uniform float rain = 0.0;
uniform vec2 wind = vec2(1.0, 0.25);

const int SHAPE_LOWER_N = 1;
const int SHAPE_LOWER_E = 2;
const int SHAPE_LOWER_S = 4;
const int SHAPE_LOWER_W = 8;
const int SHAPE_RAMP = 16;
const int SHAPE_SHADOW = 32;
const int KIND_WATER = 1;
const int KIND_LAVA = 2;
const int KIND_ICE = 3;
const int HASH_OFFSET = 16777216;

varying vec2 world_px;

struct TerrainPixel {
	vec4 color;
	vec3 normal;
	vec3 emission;
	float specular;
};

// Neighborhood index: (dy + 1) * 3 + (dx + 1); 4 is the tile itself.
int nb(int dx, int dy) {
	return (dy + 1) * 3 + (dx + 1);
}

uint hash2(ivec2 p) {
	uvec2 q = uvec2(p + ivec2(HASH_OFFSET));
	uint h = q.x * 374761393u + q.y * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return h ^ (h >> 16u);
}

float hashf(ivec2 p) {
	return float(hash2(p) & 0xFFFFFFu) / 16777215.0;
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	ivec2 ii = ivec2(i);
	float a = hashf(ii);
	float b = hashf(ii + ivec2(1, 0));
	float c = hashf(ii + ivec2(0, 1));
	float d = hashf(ii + ivec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

ivec2 ground_atlas_pos(int ground, ivec2 world_tile, ivec2 tx) {
	int variant = int(hash2(world_tile) & 3u);
	return ivec2(variant * 16 + tx.x, ground * 16 + tx.y);
}

vec3 unpack_normal(vec4 texel) {
	return texel.rgb * 2.0 - 1.0;
}

vec3 water_color(int ground, vec2 wp, float t, float foam_margin, out vec3 normal) {
	vec3 base = water_colors[ground].rgb;
	vec2 p = wp / 16.0;
	vec2 drift = wind * t * 0.08;
	// Broad, slow color variation.
	float broad = value_noise(p * 0.35 + drift);
	vec3 color = base * (0.9 + 0.2 * broad);
	// Thin wave lines drifting with the wind.
	float warp = value_noise(p * 1.7 - drift * 1.5) * 3.0;
	float wave = sin(p.x * 2.1 + p.y * 3.4 + warp - t * 1.3);
	if (wave > 0.93) {
		color = color * 1.45 + vec3(0.03, 0.05, 0.06);
	} else if (wave < -0.96) {
		color *= 0.86;
	}
	normal = normalize(vec3(0.0, cos(p.x * 2.1 + p.y * 3.4 + warp - t * 1.3) * 0.35, 1.0));
	ivec2 texel = ivec2(floor(wp));
	float sparkle = hashf(texel + ivec2(int(floor(t * 3.0)) * 131, 7));
	if (sparkle > 0.998 - rain * 0.02) {
		color = mix(color, vec3(1.0), 0.7);
	}
	float foam_width = 0.07 + 0.045 * sin(t * 1.7 + wp.x * 0.09 + wp.y * 0.13);
	if (foam_margin >= 0.0 && foam_margin < foam_width) {
		color = mix(color, vec3(0.85, 0.93, 1.0), 0.75);
	} else if (foam_margin >= 0.0 && foam_margin < foam_width + 0.1) {
		color = color * 1.2 + vec3(0.02, 0.04, 0.05);
	}
	return color;
}


vec3 lava_color(vec2 wp, float time, out vec3 emission) {
	vec2 p = wp / 16.0;
	float t = time * 0.35;
	float n = value_noise(p * 1.8 + vec2(t, t * 0.6)) * 0.6 + value_noise(p * 3.7 - vec2(t * 0.8, t)) * 0.4;
	vec3 color = vec3(0.86, 0.28, 0.08);
	if (n > 0.62) {
		color = vec3(1.0, 0.78, 0.25);
	} else if (n > 0.48) {
		color = vec3(0.98, 0.5, 0.12);
	} else if (n < 0.3) {
		color = vec3(0.55, 0.16, 0.06);
	}
	emission = color * (0.9 + 0.5 * n);
	return color;
}

// A pixel of a cliff face. `v` is the distance below the cliff's lip, in
// tiles (0..1); `with_lip` draws the plateau's ground on the top rows.
TerrainPixel cliff_face_pixel(int ground, ivec2 world_tile, ivec2 tx, float v, bool with_lip) {
	TerrainPixel px;
	px.emission = vec3(0.0);
	px.specular = 0.0;
	int row = clamp(int(floor(v * 16.0)), 0, 15);
	ivec2 texel = ivec2(tx.x, row);
	if (with_lip && row < 3) {
		ivec2 lip = ground_atlas_pos(ground, world_tile, texel);
		px.color = texelFetch(ground_atlas, lip, 0);
		px.normal = unpack_normal(texelFetch(ground_normals, lip, 0));
		if (row == 2) {
			px.color.rgb *= 0.85;
		}
		return px;
	}
	int material = cliff_material[ground];
	int variant = int(hash2(world_tile + ivec2(5, 2)) & 1u);
	ivec2 at = ivec2((material * 2 + variant) * 16 + texel.x, texel.y);
	px.color = texelFetch(cliff_atlas, at, 0);
	px.normal = unpack_normal(texelFetch(cliff_normals, at, 0));
	if (with_lip && row == 3) {
		px.color.rgb *= 0.6;
	}
	return px;
}

// Main entry: the terrain pixel at `local` (0..256 px inside the chunk).
// `n` holds the 3x3 tiles around it (see read_neighborhood), `t` the time.
TerrainPixel terrain_pixel(ivec4 n[9], vec2 local, float t) {
	TerrainPixel px;
	px.normal = vec3(0.0, 0.0, 1.0);
	px.emission = vec3(0.0);
	px.specular = 0.0;

	ivec2 lp = clamp(ivec2(floor(local)), ivec2(0), ivec2(255));
	ivec2 tile = lp / 16;
	ivec2 tx = lp - tile * 16;
	vec2 wp = floor(world_px);
	ivec2 world_tile = ivec2(floor(wp / 16.0));
	ivec4 c = n[4];
	int ground = c.r;
	int wall = c.g;
	int level = c.b;
	int shape = c.a;
	ivec4 north = n[1];

	if (wall > 0) {
		ivec4 south = n[7];
		ivec4 east = n[5];
		ivec4 west = n[3];
		bool face = south.g == 0;
		int variant = int(hash2(world_tile + ivec2(3, 11)) & 1u);
		int column = (face ? 2 : 0) + variant;
		// A single-row wall shows a thin top above its face.
		if (face && north.g == 0 && tx.y < 3) {
			column = variant;
		}
		ivec2 at = ivec2(column * 16 + tx.x, (wall - 1) * 16 + tx.y);
		px.color = texelFetch(wall_atlas, at, 0);
		px.normal = unpack_normal(texelFetch(wall_normals, at, 0));
		px.emission = texelFetch(wall_emission, at, 0).rgb;
		bool top_part = !face || (north.g == 0 && tx.y < 3);
		if (top_part) {
			if (north.g == 0 && tx.y == 0) {
				px.color.rgb *= 1.25;
			}
			if (west.g == 0 && tx.x == 0) {
				px.color.rgb *= 1.15;
			}
			if (east.g == 0 && tx.x == 15) {
				px.color.rgb *= 0.7;
			}
		} else {
			if (north.g != 0 && tx.y == 0) {
				px.color.rgb *= 0.6;
			}
			if ((west.g == 0 && tx.x == 0) || (east.g == 0 && tx.x == 15)) {
				px.color.rgb *= 0.75;
			}
			if (face && north.g == 0 && tx.y == 3) {
				px.color.rgb *= 0.6;
			}
		}
		return px;
	}

	vec2 f = (vec2(tx) + 0.5) / 16.0;
	bool lower_e = (shape & SHAPE_LOWER_E) != 0;
	bool lower_w = (shape & SHAPE_LOWER_W) != 0;
	bool ramp = (shape & SHAPE_RAMP) != 0;

	if ((shape & SHAPE_LOWER_S) != 0) {
		if (ramp) {
			// Walkable slope: the plateau's ground, darkening downhill.
			ivec2 at = ground_atlas_pos(ground, world_tile, tx);
			px.color = texelFetch(ground_atlas, at, 0);
			px.normal = normalize(vec3(0.0, -0.45, 1.0));
			px.color.rgb *= mix(1.0, 0.72, f.y);
			if (tx.y == 5 || tx.y == 10) {
				px.color.rgb *= 0.85;
			}
			return px;
		}
		// Diagonal cliffs: an outer corner keeps its plateau top above the
		// diagonal so staircase contours read as one slanted cliff.
		float v = f.y;
		bool top_area = false;
		if (lower_e && !lower_w && (shape & SHAPE_LOWER_N) == 0) {
			v = f.x + f.y - 1.0;
			top_area = v < 0.0;
		} else if (lower_w && !lower_e && (shape & SHAPE_LOWER_N) == 0) {
			v = (1.0 - f.x) + f.y - 1.0;
			top_area = v < 0.0;
		}
		if (top_area) {
			ivec2 at = ground_atlas_pos(ground, world_tile, tx);
			px.color = texelFetch(ground_atlas, at, 0);
			px.normal = unpack_normal(texelFetch(ground_normals, at, 0));
			return px;
		}
		px = cliff_face_pixel(ground, world_tile, tx, v, north.b <= level && (north.a & SHAPE_LOWER_S) == 0);
		if ((lower_e && tx.x == 15) || (lower_w && tx.x == 0)) {
			px.color.rgb *= 0.8;
		}
		return px;
	}

	// Inner corner under a diagonal cliff: the face continues into the
	// upper triangle of this lower tile.
	if (wall == 0 && north.b > level && north.g == 0) {
		bool west_high = n[3].b > level && n[3].g == 0;
		bool east_high = n[5].b > level && n[5].g == 0;
		float v = -1.0;
		if (west_high && !east_high) {
			v = f.x + f.y;
		} else if (east_high && !west_high) {
			v = (1.0 - f.x) + f.y;
		}
		if (v >= 0.0 && v < 1.0) {
			int plateau = west_high ? n[3].r : n[5].r;
			return cliff_face_pixel(plateau, world_tile, tx, v, true);
		}
	}

	// Plain ground, with organic transitions: a higher-priority neighbor
	// spreads into this tile by a wobbly margin (same terrace level only).
	float wobble = value_noise(wp * 0.3) * 0.6 + value_noise(wp * 0.11 + 17.0) * 0.4;
	float reach = 0.16 + 0.24 * wobble;
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
			ivec4 other = n[nb(dx, dy)];
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
				float margin = d - (other.g != 0 ? 0.0 : reach);
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

	int kind = ground_kind[best];
	if (kind == KIND_WATER) {
		vec3 normal;
		px.color = vec4(water_color(best, wp, t, foam_margin, normal), 1.0);
		px.normal = normal;
		px.specular = 0.9;
	} else if (kind == KIND_LAVA) {
		vec3 emission;
		px.color = vec4(lava_color(wp, t, emission), 1.0);
		px.emission = emission;
	} else {
		ivec2 at = ground_atlas_pos(best, world_tile, tx);
		px.color = texelFetch(ground_atlas, at, 0);
		px.normal = unpack_normal(texelFetch(ground_normals, at, 0));
		px.color.rgb *= 1.0 - 0.18 * wetness;
		px.specular = kind == KIND_ICE ? 0.6 : 0.25 * wetness;
		if (best != ground && best_depth < 0.075) {
			px.color.rgb *= 0.8;
		}
	}

	// Soft rims on the upper side of a drop (the drop itself is not
	// visible from above except on south faces).
	if ((shape & SHAPE_RAMP) == 0) {
		if ((shape & SHAPE_LOWER_N) != 0 && tx.y == 0) {
			px.color.rgb *= 0.78;
		}
		if ((shape & SHAPE_LOWER_E) != 0 && tx.x == 15) {
			px.color.rgb *= 0.72;
		}
		if ((shape & SHAPE_LOWER_W) != 0 && tx.x == 0) {
			px.color.rgb *= 0.85;
		}
	}
	// Shadow at the foot of cliffs and walls.
	if ((shape & SHAPE_SHADOW) != 0 || north.g != 0) {
		float depth = float(tx.y);
		if (depth < 6.0) {
			px.color.rgb *= mix(0.62, 1.0, depth / 6.0);
		}
	}
	// Soft contact shade beside walls.
	if (n[3].g != 0 && tx.x < 2) {
		px.color.rgb *= 0.85;
	}
	if (n[5].g != 0 && tx.x > 13) {
		px.color.rgb *= 0.8;
	}
	return px;
}
