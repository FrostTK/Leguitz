class_name DayNightTint
extends CanvasModulate
## Placeholder day/night tint driven by the world clock.
## Phase 2 replaces it with real lighting (sun direction, HDR, lights).

var clock: WorldClock

var _gradient := Gradient.new()


func _ready() -> void:
	# Offsets are fractions of the day (0 = midnight, 0.5 = noon).
	var night := Color(0.3, 0.35, 0.6)
	var dawn := Color(1.0, 0.78, 0.62)
	var day := Color(1.0, 1.0, 1.0)
	var dusk := Color(1.0, 0.68, 0.55)
	_gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.26, 0.32, 0.74, 0.8, 0.86, 1.0])
	_gradient.colors = PackedColorArray([night, night, dawn, day, day, dusk, night, night])


func _process(_delta: float) -> void:
	if clock != null:
		color = color_at(clock.day_fraction())


func color_at(day_fraction: float) -> Color:
	return _gradient.sample(day_fraction)
