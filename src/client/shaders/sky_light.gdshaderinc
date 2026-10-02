// The sky light (LightField, 0 to 1 for levels 0 to 15) baked into the
// terrain's faces and the props by ChunkMesher, or given to a body: how much
// of the ambient light reaches them, from all of it under the open sky to
// none in a closed cave (black but for the lights: lanterns, torches, lava).
float sky_ambient(float level) {
	return smoothstep(0.0, 1.0, clamp(level, 0.0, 1.0));
}
