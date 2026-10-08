// First person: what is in hand (HeldView) is projected with a field of
// view of its own, whatever the player chose, and drawn in front of the
// world (it never cuts into a wall nor hides behind the rain).
// `view_position`: the vertex in view space; `fov`: degrees, vertical.

// Depth kept for the hand: the nearest part of Godot's reversed depth
// (1 at the near plane), so the world, farther, is always behind it.
const float VIEW_MODEL_DEPTH = 0.9;

vec4 view_model_position(mat4 projection, vec4 view_position, float fov) {
	mat4 own = projection;
	// Scaled, keeping the signs (the projection may flip its axes).
	float scale = 1.0 / (tan(radians(fov) * 0.5) * abs(projection[1][1]));
	own[0][0] *= scale;
	own[1][1] *= scale;
	vec4 clip = own * view_position;
	clip.z = clip.w * (VIEW_MODEL_DEPTH + clamp(clip.z / clip.w, 0.0, 1.0) * (1.0 - VIEW_MODEL_DEPTH));
	return clip;
}
