class_name LightTextures
extends RefCounted
## Shared textures for point lights.

const SIZE := 128

static var _radial: GradientTexture2D


## Soft round light, white in the center fading to transparent.
static func radial() -> GradientTexture2D:
	if _radial == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray(
			[Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)]
		)
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		_radial = GradientTexture2D.new()
		_radial.gradient = gradient
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = SIZE
		_radial.height = SIZE
	return _radial


## texture_scale giving a light of `radius_tiles` tiles.
static func scale_for(radius_tiles: float) -> float:
	return radius_tiles * GameConst.TILE_SIZE * 2.0 / SIZE
