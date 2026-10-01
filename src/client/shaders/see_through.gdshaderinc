// See-through hole around the player: whatever stands between the camera
// and the player (trees, cliffs, walls) is dithered away inside a window
// around them, so the player always stays visible.

// The player's chest and feet (world space).
global uniform vec3 player_position;
global uniform vec3 player_feet;

// Only what is at least this far (world units) in front of the player's
// vertical plane counts as being in the way.
const float SEE_THROUGH_FRONT = 0.15;

// 4x4 ordered dither threshold (0..1) of a screen pixel.
float see_through_dither(vec2 fragcoord) {
	ivec2 p = ivec2(fragcoord) & ivec2(3);
	int index = p.x + p.y * 4;
	int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(bayer[index]) + 0.5) / 16.0;
}

// True when the fragment at `vertex` (view space) hides the player and
// must be dropped. `size` is the half width and half height of the hole
// around the chest (world units on screen, the view is orthographic).
// The hole only takes what is in front of the player's vertical plane and
// above their feet on screen: the ground in front of them is not in the
// way. `soft_bottom` fades that lower edge out over a height (0 = sharp).
bool hides_player(
		vec3 vertex, mat4 view, mat4 inv_view, vec2 size, float soft_bottom, vec2 fragcoord) {
	vec3 chest = (view * vec4(player_position, 1.0)).xyz;
	float d = length((vertex.xy - chest.xy) / size);
	if (d >= 1.0) {
		return false;
	}
	vec3 world = (inv_view * vec4(vertex, 1.0)).xyz;
	vec2 towards_camera = normalize(inv_view[2].xz);
	if (dot(world.xz - player_feet.xz, towards_camera) < SEE_THROUGH_FRONT) {
		return false;
	}
	float feet_y = (view * vec4(player_feet, 1.0)).y;
	float below = feet_y - vertex.y;
	float keep = soft_bottom > 0.0 ? smoothstep(0.0, soft_bottom, below) : step(0.0, below);
	keep = max(keep, smoothstep(0.6, 1.0, d));
	return see_through_dither(fragcoord) > keep;
}
