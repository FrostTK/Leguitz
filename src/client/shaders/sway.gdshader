shader_type canvas_item;
// Plants and trees bending in the wind. The sprite quad stays still; pixels
// are shifted sideways by whole art pixels, more towards the top, so the
// pixel art stays crisp.

uniform vec2 cell_px = vec2(32.0, 48.0);
uniform vec2 cells = vec2(16.0, 3.0);
uniform float wind_strength = 0.5;
uniform float sway_pixels = 1.6;

varying vec2 world_px;

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 grid = UV * cells;
	vec2 cell = floor(grid);
	vec2 local = floor((grid - cell) * cell_px);
	float height = clamp((cell_px.y - local.y) / cell_px.y, 0.0, 1.0);
	vec2 origin = floor(world_px - local);
	float phase = origin.x * 0.071 + origin.y * 0.113;
	float gust = sin(TIME * 0.35 + origin.x * 0.004) * 0.5 + 0.5;
	float wave = sin(TIME * 1.7 + phase) * 0.7 + sin(TIME * 2.9 + phase * 1.3) * 0.3;
	float offset = round(wave * sway_pixels * wind_strength * (0.6 + 0.8 * gust) * height * height);
	vec2 source = vec2(clamp(local.x - offset, 0.0, cell_px.x - 1.0), local.y);
	vec2 uv = (cell * cell_px + source + 0.5) / (cells * cell_px);
	COLOR = texture(TEXTURE, uv);
	NORMAL_MAP = texture(NORMAL_TEXTURE, uv).rgb;
}
