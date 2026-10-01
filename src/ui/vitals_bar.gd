class_name VitalsBar
extends Control
## The player's vitality over the hotbar's left half: a life crystal and a
## gauge framed in wood, a notch every two points. What a hurt took shows
## pale for a moment and melts away; nearly empty, the gauge throbs. The
## right half waits for hunger.

## Gauge and crystal sizes (UI units).
const HEIGHT := 9.0
const BAR_HEIGHT := 5.0
const CRYSTAL := ["#5e0e1a", "#a01e2c", "#d8404a", "#ff9a8a"]
const FILL := ["#7c1622", "#b82634", "#e2524e"]
const TRACK := Color("2a1410")
const TRAIL := Color("f2d6a6")
## How fast the pale trail of a hurt melts (points per second), after
## TRAIL_HOLD seconds.
const TRAIL_SPEED := 14.0
const TRAIL_HOLD := 0.35
## Throbs under this many points.
const LOW := 5

var health := Vitals.MAX_HEALTH

var _trail := float(Vitals.MAX_HEALTH)
var _hold := 0.0
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows `points`; a drop leaves a pale trail.
func set_health(points: int) -> void:
	if points < health:
		_trail = maxf(_trail, health)
		_hold = TRAIL_HOLD
	else:
		_trail = points
	health = points
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _hold > 0.0:
		_hold -= delta
	elif _trail > health:
		_trail = maxf(_trail - TRAIL_SPEED * delta, health)
	if _trail > health or health <= LOW:
		queue_redraw()


func _draw() -> void:
	var slots := Inventory.HOTBAR * ItemSlot.SIZE + (Inventory.HOTBAR - 1)
	var left := floorf((size.x - slots) * 0.5)
	var width := floorf(slots * 0.5) - 2.0
	var top := floorf((HEIGHT - BAR_HEIGHT) * 0.5)
	# The frame and the track, from the crystal's middle on.
	var bar := Rect2(left + 4.0, top, width - 4.0, BAR_HEIGHT)
	draw_rect(bar.grow(1.0), UiTheme.WOOD_DARK)
	draw_rect(bar, TRACK)
	var inner := bar.grow(-1.0)
	var per_point := inner.size.x / Vitals.MAX_HEALTH
	var filled := roundf(per_point * health)
	var trail := roundf(per_point * _trail)
	if trail > filled:
		draw_rect(Rect2(inner.position.x + filled, inner.position.y, trail - filled, 3.0), TRAIL)
	var throb := 1.0
	if health <= LOW and health > 0:
		throb = 0.75 + 0.25 * sin(_time * 7.0)
	for row in 3:
		var color := Color(FILL[row]) * throb
		color.a = 1.0
		draw_rect(Rect2(inner.position.x, inner.position.y + row, filled, 1.0), color)
	# A notch every two points.
	for point in range(2, Vitals.MAX_HEALTH, 2):
		var x := inner.position.x + roundf(per_point * point)
		draw_rect(Rect2(x, inner.position.y, 1.0, 3.0), Color(0, 0, 0, 0.25))
	_draw_crystal(Vector2(left, 0.0))


## The life crystal: a faceted red gem, lit from the top left.
func _draw_crystal(at: Vector2) -> void:
	var rows := [[3, 2], [2, 4], [1, 6], [0, 8], [0, 8], [1, 6], [2, 4], [3, 2], [4, 0]]
	for y in rows.size():
		var start: int = rows[y][0]
		var run: int = rows[y][1]
		for x in run:
			var shade := 2 if x < run / 2 else 1
			if y >= 5:
				shade -= 1
			if x == 0 or x == run - 1:
				shade = 0
			draw_rect(Rect2(at + Vector2(start + x, y), Vector2.ONE), Color(CRYSTAL[shade]))
	draw_rect(Rect2(at + Vector2(3, 2), Vector2.ONE), Color(CRYSTAL[3]))
	draw_rect(Rect2(at + Vector2(2, 3), Vector2.ONE), Color(CRYSTAL[3]))
